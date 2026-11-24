#!/usr/bin/env python3
"""T-265: the medians of tools/tick_perf.sh runs as a table.
    python -I tools/tick_perf_table.py <dir> [<dir> ...] [--scripts N]
One row per scenario and directory: runs, the frame's wall time (mean, p99, worst, frames over 16.7 ms of the
window), the scripts' time per physics tick and per process frame, their sum. `--scripts N` adds the N dearest
scripts of each scenario (the median of their means). Everything is the median over the runs; the worst frame is
also given as the smallest worst of the runs (what the game does at its best: the rest is the machine)."""
import glob
import os
import re
import statistics
import sys


def parse(path):
    out = {"scripts": {}}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\[hitch\] frame wall ms: mean ([\d.]+) p50 ([\d.]+) p95 ([\d.]+) p99 ([\d.]+) worst ([\d.]+) \| over 8 ms (\d+), over 16.7 ms (\d+)", line)
            if m:
                out.update(wall=float(m[1]), p50=float(m[2]), p99=float(m[4]), worst=float(m[5]), over=int(m[7]))
            m = re.match(r"\[hitch\] scripts per physics tick ms: mean ([\d.]+) p50 [\d.]+ p95 [\d.]+ p99 ([\d.]+) worst ([\d.]+) \| over 4 ms \d+, over 8 ms \d+, over 16.7 ms (\d+)", line)
            if m:
                out.update(tick=float(m[1]), tick_p99=float(m[2]), tick_worst=float(m[3]), tick_over=int(m[4]))
            m = re.match(r"\[hitch\] scripts per process frame ms: mean ([\d.]+) p50 [\d.]+ p95 [\d.]+ p99 ([\d.]+) worst ([\d.]+)", line)
            if m:
                out.update(proc=float(m[1]), proc_worst=float(m[3]))
            m = re.match(r"\[hitch\]   (\S+\.gd (?:phys|proc))\s+mean ([\d.]+)", line)
            if m:
                out["scripts"][m[1]] = float(m[2])
            m = re.match(r"\[hitch\] map \S+ .* frames (\d+)", line)
            if m:
                out["frames"] = int(m[1])
    return out if "wall" in out and "tick" in out else None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    top = 0
    for i, a in enumerate(sys.argv):
        if a == "--scripts" and i + 1 < len(sys.argv):
            top = int(sys.argv[i + 1])
            args = [x for x in args if x != sys.argv[i + 1]]
    med = statistics.median
    print("%-22s %-10s %4s %7s %7s %7s %7s %6s | %7s %7s %7s %9s" % ("dir", "scenario", "runs", "wall", "p99", "worst", "best-w", ">16.7", "tick", "proc", "scripts", "tickworst"))
    for d in args:
        groups = {}
        for p in sorted(glob.glob(os.path.join(d, "*.log"))):
            m = re.match(r"(.+)_(\d+)\.log$", os.path.basename(p))
            r = parse(p)
            if m and r:
                groups.setdefault(m[1], []).append(r)
        for sc, rs in groups.items():
            print("%-22s %-10s %4d %7.2f %7.2f %7.2f %7.2f %6.0f | %7.2f %7.2f %7.2f %9.2f" % (
                os.path.basename(os.path.normpath(d)), sc, len(rs), med([r["wall"] for r in rs]), med([r["p99"] for r in rs]),
                med([r["worst"] for r in rs]), min(r["worst"] for r in rs), med([r["over"] for r in rs]),
                med([r["tick"] for r in rs]), med([r["proc"] for r in rs]), med([r["tick"] + r["proc"] for r in rs]),
                med([r["tick_worst"] for r in rs])))
            if top > 0:
                names = {}
                for r in rs:
                    for k, v in r["scripts"].items():
                        names.setdefault(k, []).append(v)
                rows = sorted(((med(v), k) for k, v in names.items()), reverse=True)[:top]
                for v, k in rows:
                    print("    %-40s %.3f" % (k, v))


if __name__ == "__main__":
    main()
