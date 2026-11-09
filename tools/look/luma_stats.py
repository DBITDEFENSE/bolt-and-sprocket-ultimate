#!/usr/bin/env python
"""T-222: "too dark" as a number. Per-frame display luma (Rec. 709 on the sRGB values, 0-255, the ART_BIBLE section 3
measure) of capture frames, on the frame without its HUD margins (the centre 84% x 76%).

    python -I tools/look/luma_stats.py <dir> [--json=<out>] [--sort]
    python -I tools/look/luma_stats.py --compare <before_dir|json> <after_dir|json> [--md]

Prints mean, p5 (the bible's "floor"), p10, median, p95 and the share of pixels under 12 (crushed black) per frame;
--compare pairs frames by file name (any .png / .jpg) and prints before -> after.
"""
import json
import os
import sys

from PIL import Image
import numpy as np


def stats(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    im = im.crop((int(w * 0.08), int(h * 0.10), int(w * 0.92), int(h * 0.86)))
    a = np.asarray(im, dtype=np.float32)
    y = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    f = y.ravel()
    return {"mean": round(float(f.mean()), 1), "p5": round(float(np.percentile(f, 5)), 1), "p10": round(float(np.percentile(f, 10)), 1),
            "p50": round(float(np.percentile(f, 50)), 1), "p95": round(float(np.percentile(f, 95)), 1),
            "black": round(100.0 * float((f < 12.0).mean()), 1)}


def collect(src):
    if src.endswith(".json"):
        return json.load(open(src))
    out = {}
    for n in sorted(os.listdir(src)):
        if n.lower().endswith((".png", ".jpg")):
            out[os.path.splitext(n)[0]] = stats(os.path.join(src, n))
    return out


def main(argv):
    if argv and argv[0] == "--compare":
        a, b = collect(argv[1]), collect(argv[2])
        md = "--md" in argv
        if md:
            print("| frame | mean | p10 | black % |\n|---|---|---|---|")
        for k in sorted(set(a) & set(b)):
            x, y = a[k], b[k]
            if md:
                print("| %s | %.0f -> %.0f | %.0f -> %.0f | %.0f -> %.0f |" % (k, x["mean"], y["mean"], x["p10"], y["p10"], x["black"], y["black"]))
            else:
                print("%-34s mean %5.1f -> %5.1f   p10 %5.1f -> %5.1f   black %4.1f%% -> %4.1f%%" % (k, x["mean"], y["mean"], x["p10"], y["p10"], x["black"], y["black"]))
        return 0
    s = collect(argv[0])
    js = [x for x in argv[1:] if x.startswith("--json=")]
    if js:
        json.dump(s, open(js[0][7:], "w"), indent=1)
    items = sorted(s.items(), key=lambda kv: kv[1]["mean"]) if "--sort" in argv else s.items()
    for k, v in items:
        print("%-34s mean %5.1f  p5 %5.1f  p10 %5.1f  p50 %5.1f  p95 %5.1f  black %4.1f%%" % (k, v["mean"], v["p5"], v["p10"], v["p50"], v["p95"], v["black"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
