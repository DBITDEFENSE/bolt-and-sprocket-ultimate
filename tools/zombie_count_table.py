#!/usr/bin/env python3
"""T-281: tools/zombie_count_bench.sh runs as a table, one row per map, zombie count and side (A / B).
    python -I tools/zombie_count_table.py <dir> [<dir> ...] [--parts] [--prof]
Columns (medians over the repeats, ms a frame, no renderer): the frame's wall time mean, the 1 % worst (the mean of
the slowest hundredth of the frames), the worst frame (also the smallest worst of the repeats), then where it went:
the zombies' physics tick and process step, the bots' brains, the physics + navigation servers' step (the gap after
the physics scripts), animation / skeletons / audio (the gap after the process scripts), everything else; and the
zombies' own share per zombie. `--prof` adds the zombie section profiler's lines (a diagnosis build only)."""
import glob
import os
import re
import statistics
import sys


def parse(path):
    out = {"scripts": {}, "prof": {}}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\[hitch\] frame wall ms: mean ([\d.]+) p50 ([\d.]+) p95 ([\d.]+) p99 ([\d.]+) worst ([\d.]+) \| over 8 ms (\d+), over 16.7 ms (\d+)", line)
            if m:
                out.update(wall=float(m[1]), p50=float(m[2]), p99=float(m[4]), worst=float(m[5]), over=int(m[7]))
            m = re.match(r"\[hitch\] 1% low: the slowest \d+ frames average ([\d.]+) ms", line)
            if m:
                out["low"] = float(m[1])
            m = re.match(r"\[hitch\] scripts per physics tick ms: mean ([\d.]+)", line)
            if m:
                out["tick"] = float(m[1])
            m = re.match(r"\[hitch\] scripts per process frame ms: mean ([\d.]+)", line)
            if m:
                out["proc"] = float(m[1])
            m = re.match(r"\[hitch\] outside the scripts ms: after the physics scripts \(physics, navigation servers\) mean ([\d.]+) p50 ([\d.]+) .* after the process scripts \(animation, skeletons, audio, draw, the tool\) mean ([\d.]+) p50 ([\d.]+)", line)
            if m:
                out.update(gphys=float(m[1]), gproc=float(m[3]), gphys50=float(m[2]), gproc50=float(m[4]))
            m = re.match(r"\[hitch\]   (\S+\.gd (?:phys|proc))\s+mean ([\d.]+) p50 ([\d.]+)", line)
            if m:
                out["scripts"][m[1]] = float(m[2])
                out.setdefault("scripts50", {})[m[1]] = float(m[3])
            m = re.match(r"\[t281\] zombies (\d+) .* deaths in the window (\d+)", line)
            if m:
                out.update(zombies=int(m[1]), deaths=int(m[2]))
            m = re.match(r"\[hitch\] prof (z\.\S+)\s+([\d.]+) ms/tick, (\d+) calls", line)
            if m:
                out["prof"][m[1]] = (float(m[2]), int(m[3]))
            m = re.match(r"\[hitch\] noise floor .* p99 ([\d.]+)", line)
            if m:
                out["noise"] = float(m[1])
    return out if "wall" in out and "gphys" in out else None


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    prof = "--prof" in sys.argv
    p50 = "--p50" in sys.argv   # the medians of the frames instead of their means (a busy machine's spikes left out)
    med = statistics.median
    print("%-10s %-4s %3s %4s %2s | %6s %7s %7s %7s | %6s %6s %6s %6s %6s %6s | %8s %5s" % (
        "dir", "map", "z", "up", "s", "mean", "1%wst", "max", "bestmx", "z.phy", "z.prc", "bots", "srvP", "srvA", "rest", "ms/zomb", "runs"))
    for d in dirs:
        groups = {}
        for p in sorted(glob.glob(os.path.join(d, "*.log"))):
            m = re.match(r"(m\d)_z(\d+)_([AB])_(\d+)\.log$", os.path.basename(p))
            r = parse(p)
            if m and r:
                groups.setdefault((m[1], int(m[2]), m[3]), []).append(r)
        for key in sorted(groups):
            rs = groups[key]
            def g(k, sub=None):
                if sub:
                    return med([r["scripts50" if p50 else "scripts"].get(sub, 0.0) for r in rs])
                if p50 and k in ("wall", "gphys", "gproc"):
                    k = {"wall": "p50", "gphys": "gphys50", "gproc": "gproc50"}[k]
                return med([r.get(k, 0.0) for r in rs])
            zph = g(None, "zombie.gd phys")
            zpr = g(None, "zombie.gd proc")
            bots = g(None, "bot_brain.gd phys")
            rest = med([r["tick"] + r["proc"] - r["scripts"].get("zombie.gd phys", 0) - r["scripts"].get("zombie.gd proc", 0) - r["scripts"].get("bot_brain.gd phys", 0) for r in rs])
            up = g("zombies")
            print("%-10s %-4s %3d %4.0f %2s | %6.2f %7.2f %7.2f %7.2f | %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f | %8.3f %5d" % (
                os.path.basename(os.path.normpath(d))[:10], key[0], key[1], up, key[2], g("wall"), g("low"), g("worst"), min(r["worst"] for r in rs),
                zph, zpr, bots, g("gphys"), g("gproc"), rest, (zph + zpr) / max(1.0, up), len(rs)))
            if prof:
                names = {}
                for r in rs:
                    for k, v in r["prof"].items():
                        names.setdefault(k, []).append(v)
                rows = sorted(((med([x[0] for x in v]), med([x[1] for x in v]), k) for k, v in names.items()), reverse=True)
                print("      " + ", ".join("%s %.3f" % (k, v) for v, n, k in rows[:16]))


if __name__ == "__main__":
    main()
