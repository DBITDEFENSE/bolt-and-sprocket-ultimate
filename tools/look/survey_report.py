#!/usr/bin/env python
"""T-222: read a light survey (gravelight/tools_src/light_survey.gd) and list the dark spots.

    python -I tools/look/survey_report.py <survey.json> [--key=on|off] [--dark=0.15] [--cams=<set_prefix>] [--n=4]
    python -I tools/look/survey_report.py --compare <before.json> <after.json> [--key=on]

Per zone: the samples, the share under the dark threshold (direct light at eye height, the ambient term not added),
the median and 10th percentile; then the darkest clusters (samples within 6 m merged), corridors first. --cams prints
capture_cams.json-style cameras for the darkest clusters of every zone (n per zone, corridors looking down their
length, others towards the most open side). --compare prints the per-zone numbers side by side.
"""
import json
import math
import sys


def pct(v, q):
    if not v:
        return 0.0
    s = sorted(v)
    return s[min(len(s) - 1, int(q * (len(s) - 1)))]


def zones(rows, key):
    z = {}
    for r in rows:
        z.setdefault(r["zone"], []).append(r)
    return z


def clusters(rows, key, dark):
    pts = sorted([r for r in rows if r.get(key, r["off"]) < dark], key=lambda r: r.get(key, r["off"]))
    out = []
    for r in pts:
        p = r["p"]
        for c in out:
            q = c["p"]
            if math.dist((p[0], p[2]), (q[0], q[2])) < 6.0 and abs(p[1] - q[1]) < 2.0:
                c["n"] += 1
                c["corridor"] = c["corridor"] or r["corridor"]
                break
        else:
            out.append(dict(r, n=1))
    return out


def main(argv):
    key, dark, cams, n = "on", 0.15, None, 4
    pos = []
    for a in argv:
        if a.startswith("--key="):
            key = a[6:]
        elif a.startswith("--dark="):
            dark = float(a[7:])
        elif a.startswith("--cams="):
            cams = a[7:]
        elif a.startswith("--n="):
            n = int(a[4:])
        else:
            pos.append(a)
    if pos[0] == "--compare":
        a, b = json.load(open(pos[1])), json.load(open(pos[2]))
        za, zb = zones(a["rows"], key), zones(b["rows"], key)
        print("%-16s %6s | %-24s | %-24s" % ("zone", "n", "before: dark%  p10  med", "after: dark%  p10  med"))
        for z in sorted(za):
            va = [r.get(key, r["off"]) for r in za[z]]
            vb = [r.get(key, r["off"]) for r in zb.get(z, [])]
            fa = 100.0 * sum(1 for v in va if v < dark) / max(1, len(va))
            fb = 100.0 * sum(1 for v in vb if v < dark) / max(1, len(vb))
            print("%-16s %6d | %5.1f%% %6.3f %6.3f     | %5.1f%% %6.3f %6.3f" % (z, len(va), fa, pct(va, 0.1), pct(va, 0.5), fb, pct(vb, 0.1), pct(vb, 0.5)))
        return 0
    d = json.load(open(pos[0]))
    rows = d["rows"]
    print("%s  ambient %.3f  key=%s dark<%.2f" % (d["map"], d["ambient"], key, dark))
    zs = zones(rows, key)
    for z in sorted(zs):
        v = [r.get(key, r["off"]) for r in zs[z]]
        corr = [r.get(key, r["off"]) for r in zs[z] if r["corridor"]]
        print("%-16s n=%4d dark=%5.1f%%  p10=%.3f med=%.3f  corridors n=%d dark=%.1f%%" % (z, len(v), 100.0 * sum(1 for x in v if x < dark) / len(v),
              pct(v, 0.1), pct(v, 0.5), len(corr), 100.0 * sum(1 for x in corr if x < dark) / max(1, len(corr))))
    cl = clusters(rows, key, dark)
    print("\ndarkest clusters (corridors marked *):")
    for c in sorted(cl, key=lambda c: (-c["n"]))[:40]:
        print("  %s %-14s n=%3d  e=%.3f  pos=(%.1f, %.1f, %.1f) ceil=%s yaw=%s" % ("*" if c["corridor"] else " ", c["zone"], c["n"], c.get(key, c["off"]),
              c["p"][0], c["p"][1], c["p"][2], c["ceil"], c["yaw"]))
    if cams:
        out = []
        byz = {}
        for c in sorted(cl, key=lambda c: (not c["corridor"], -c["n"])):
            byz.setdefault(c["zone"], []).append(c)
        for z in sorted(byz):
            for i, c in enumerate(byz[z][:n]):
                out.append({"name": "%s_%s%d" % (z.split("_")[0], "corr" if c["corridor"] else "dark", i), "pos": [round(c["p"][0], 2), round(c["p"][1], 2), round(c["p"][2], 2)],
                            "yaw": c["yaw"], "pitch": -4.0, "note": "T-222 survey: %s %s, %d dark samples, direct %.3f" % (z, "corridor" if c["corridor"] else "dark spot", c["n"], c.get(key, c["off"]))})
        print(json.dumps(out, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
