#!/usr/bin/env python3
"""T-281: the before / after table of tools/zombie_count_bench.sh runs made with --flip=t281 (an A/B inside each run,
one second a side). One row per map and zombie count; every number is the median over the repeats of that run's
own value (ms a frame, no renderer).
    python -I tools/zombie_flip_table.py <dir> [<dir> ...] [--parts]
`--parts` adds the zombies' scripts and the two gaps (p50)."""
import glob
import os
import re
import statistics
import sys

KEYS = ["frame", "scripts per physics tick", "scripts per process frame", "zombie.gd phys", "zombie.gd proc",
        "bot_brain.gd phys", "after physics scripts", "after process scripts"]


def parse(path):
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\[flip\]   (.+?)\s+on ([\d./ ]+) \((\d+)\) \| off ([\d./ ]+) \((\d+)\)", line)
            if m and m[1].strip() in KEYS:
                on = [float(x) for x in m[2].split("/")]
                off = [float(x) for x in m[4].split("/")]
                out[m[1].strip()] = (on, off)
            m = re.match(r"\[t281\] zombies (\d+)", line)
            if m:
                out["up"] = int(m[1])
    return out if "frame" in out else None


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")]
    parts = "--parts" in sys.argv
    med = statistics.median
    print("| Map | Zombies (up) | Before: mean / 1 % worst / max | After: mean / 1 % worst / max | Mean change | Runs |")
    print("|---|---|---|---|---|---|")
    rows = []
    for d in dirs:
        groups = {}
        for p in sorted(glob.glob(os.path.join(d, "*.log"))):
            m = re.match(r"(m\d)_z(\d+)_[AB]_(\d+)\.log$", os.path.basename(p))
            r = parse(p)
            if m and r:
                groups.setdefault((m[1], int(m[2])), []).append(r)
        for key in sorted(groups):
            rs = groups[key]
            def col(k, side, i):
                return med([r[k][1 if side == "off" else 0][i] for r in rs if k in r])
            b = (col("frame", "off", 0), col("frame", "off", 4), col("frame", "off", 5))
            a = (col("frame", "on", 0), col("frame", "on", 4), col("frame", "on", 5))
            up = med([r.get("up", key[1]) for r in rs])
            print("| %s | %d (%.0f) | %.2f / %.2f / %.2f | %.2f / %.2f / %.2f | %+.1f %% | %d |" % (
                {"m0": "Map 0", "m1": "Kaltenbrunn", "m2": "Totenhafen"}.get(key[0], key[0]), key[1], up,
                b[0], b[1], b[2], a[0], a[1], a[2], 100.0 * (a[0] - b[0]) / max(0.01, b[0]), len(rs)))
            if parts:
                rows.append((key, rs))
    if parts:
        print()
        print("| Map | Zombies | p50 before -> after: frame | zombie.gd phys | zombie.gd proc | bots | after physics scripts | after process scripts |")
        print("|---|---|---|---|---|---|---|---|")
        for key, rs in rows:
            cells = []
            for k in ["frame", "zombie.gd phys", "zombie.gd proc", "bot_brain.gd phys", "after physics scripts", "after process scripts"]:
                bo = med([r[k][1][1] for r in rs if k in r])
                af = med([r[k][0][1] for r in rs if k in r])
                cells.append("%.2f -> %.2f" % (bo, af))
            print("| %s | %d | %s |" % (key[0], key[1], " | ".join(cells)))


if __name__ == "__main__":
    main()
