#!/usr/bin/env python3
"""T-237: the table of a tools/bot_perf.sh batch. Reads .smoke_logs/t237/<tag>/<map>_<cfg>_<run>.log and prints,
per map and side (bots = now, old = T-237's optimisations off, nobots = the player alone), the median over the
runs of the frame-time distribution, the scripts' time per tick, the brains' own time and the noise floor.

    python -I tools/bot_perf_table.py .smoke_logs/t237/<tag> [--md] [--prof]

--prof prints instead, per map, every profiled section of the bots' tick (BotProf): its ms per tick, how many of its
calls took over 2 ms (summed over the runs) and its worst call, before | after.
"""
import glob
import os
import re
import statistics
import sys


def nums(line):
    return [float(x) for x in re.findall(r"(?<![\w.])-?\d+(?:\.\d+)?", line)]


def read(path):
    out = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("[hitch] frame wall ms:"):
            v = nums(line.split(":", 1)[1])
            # mean p50 p95 p99 worst | over 8, 16.7, 20, 33 (each "over N ms M": N then M)
            out.update(f_mean=v[0], f_p50=v[1], f_p95=v[2], f_p99=v[3], f_worst=v[4], o8=v[6], o167=v[8], o20=v[10], o33=v[12])
        elif line.startswith("[hitch] scripts per physics tick ms:"):
            v = nums(line.split(":", 1)[1])
            out.update(t_mean=v[0], t_p50=v[1], t_p95=v[2], t_p99=v[3], t_worst=v[4], t_o8=v[8])
        elif line.startswith("[hitch] scripts per process frame ms:"):
            v = nums(line.split(":", 1)[1])
            out.update(p_mean=v[0])
        elif line.startswith("[hitch] noise floor"):
            v = nums(line.split("ms:", 1)[1])
            out.update(noise=v[0])
        elif line.startswith("[hitch]   bot_brain.gd phys"):
            v = nums(line.split("phys", 1)[1])
            out.update(b_mean=v[0], b_p95=v[2], b_p99=v[3])
        elif line.startswith("[hitch]   zombie.gd phys"):
            v = nums(line.split("phys", 1)[1])
            out.update(z_mean=v[0], z_p99=v[3])
        elif line.startswith("[hitch] map "):
            m = re.search(r"frames (\d+)", line)
            out["frames"] = float(m.group(1)) if m else 0.0
    return out


def read_prof(path):
    """section -> (ms per tick, calls over 2 ms, worst ms) from the [hitch] prof lines."""
    out = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\[hitch\] prof (\S+)\s+([\d.]+) ms/tick, (\d+) calls, ([\d.]+) ms each, worst ([\d.]+) ms, over 2 ms (\d+)", line)
        if m:
            out[m.group(1)] = (float(m.group(2)), int(m.group(6)), float(m.group(5)), int(m.group(3)))
    return out


def prof_table(d, md):
    """--prof: per map, every BotProf section: ms per tick and calls over 2 ms, before | after (medians over the runs)."""
    data = {}
    for path in sorted(glob.glob(os.path.join(d, "*.log"))):
        m = re.match(r"(.+)_(bots|old)_(\d+)\.log$", os.path.basename(path))
        if m:
            data.setdefault((m.group(1), m.group(2)), []).append(read_prof(path))
    for mp in sorted({k[0] for k in data}):
        secs = {}
        for side in ("old", "bots"):
            for r in data.get((mp, side), []):
                for k in r:
                    secs.setdefault(k, None)
        rows = []
        for k in secs:
            line = [k]
            for side in ("old", "bots"):
                rs = data.get((mp, side), [])
                ms = [r[k][0] if k in r else 0.0 for r in rs] or [0.0]
                ov = [r[k][1] if k in r else 0 for r in rs] or [0]
                wo = [r[k][2] if k in r else 0.0 for r in rs] or [0.0]
                line += [statistics.median(ms), sum(ov), max(wo)]
            rows.append(line)
        rows.sort(key=lambda r: -r[1])
        print()
        print("%s: section, before (ms/tick, calls over 2 ms in all runs, worst ms) | after" % mp)
        for r in rows:
            if md:
                print("| %s | %.3f | %d | %.1f | %.3f | %d | %.1f |" % tuple(r))
            else:
                print("  %-20s %7.3f %4d %6.1f   | %7.3f %4d %6.1f" % tuple(r))


def main():
    d = sys.argv[1]
    md = "--md" in sys.argv
    if "--prof" in sys.argv:
        prof_table(d, md)
        return
    rows = {}
    for path in sorted(glob.glob(os.path.join(d, "*.log"))):
        m = re.match(r"(.+)_(bots|old|nobots)_(\d+)\.log$", os.path.basename(path))
        if not m:
            continue
        r = read(path)
        if "f_mean" in r:
            rows.setdefault((m.group(1), m.group(2)), []).append(r)
    cols = [("frame mean", "f_mean"), ("p50", "f_p50"), ("p95", "f_p95"), ("p99", "f_p99"), ("worst", "f_worst"), (">16.7", "o167"), (">20", "o20"),
            (">33", "o33"), ("tick scripts", "t_mean"), ("tick p99", "t_p99"), ("brains", "b_mean"), ("brains p99", "b_p99"), ("zombies", "z_mean"),
            ("process", "p_mean"), ("noise", "noise")]
    head = ["map", "side", "runs", "frames"] + [c[0] for c in cols]
    table = []
    order = {"old": 0, "bots": 1, "nobots": 2}
    for (mp, cfg) in sorted(rows, key=lambda k: (k[0], order[k[1]])):
        rs = rows[(mp, cfg)]
        line = [mp.split("_")[0], {"old": "bots, before", "bots": "bots, after", "nobots": "no bots"}[cfg], str(len(rs)), "%d" % statistics.median(r.get("frames", 0) for r in rs)]
        for _, k in cols:
            vals = [r[k] for r in rs if k in r]
            if not vals:
                line.append("-")
            elif k.startswith("o") or k == "t_o8":
                line.append("%d" % round(statistics.median(vals)))
            elif k == "noise":
                line.append("%.3f" % statistics.median(vals))
            else:
                line.append("%.2f" % statistics.median(vals))
        table.append(line)
    if md:
        print("| " + " | ".join(head) + " |")
        print("|" + "---|" * len(head))
        for line in table:
            print("| " + " | ".join(line) + " |")
    else:
        w = [max(len(head[i]), max((len(t[i]) for t in table), default=0)) for i in range(len(head))]
        print("  ".join(head[i].ljust(w[i]) for i in range(len(head))))
        for line in table:
            print("  ".join(line[i].ljust(w[i]) for i in range(len(head))))


if __name__ == "__main__":
    main()
