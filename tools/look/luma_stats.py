#!/usr/bin/env python
"""Frame luminance, so "less dark" is a number (T-221).

    python -I tools/look/luma_stats.py <dir> [<dir_after>] [--crop=0.12]

For every PNG/JPG in <dir> (paired by file name with <dir_after> when given): the mean and the 10th / 50th / 90th
percentile of display luma (Rec. 601, 0-255) and the share of pixels under 12 (near black). The HUD sits in the frame
edges, so a border of `crop` (fraction of each side, default 0.12) is cut off first. Prints a table and the averages.
"""
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("Pillow is required: pip install pillow", file=sys.stderr)
    sys.exit(2)


def stats(path: str, crop: float) -> dict:
    im = Image.open(path).convert("L")
    w, h = im.size
    cx, cy = int(w * crop), int(h * crop)
    im = im.crop((cx, cy, w - cx, h - cy))
    hist = im.histogram()
    n = sum(hist)
    mean = sum(i * c for i, c in enumerate(hist)) / max(1, n)

    def pct(p: float) -> int:
        target = n * p
        acc = 0
        for i, c in enumerate(hist):
            acc += c
            if acc >= target:
                return i
        return 255

    dark = sum(hist[:12]) / max(1, n)
    return {"mean": mean, "p10": pct(0.10), "p50": pct(0.50), "p90": pct(0.90), "dark": dark}


def main(argv: list) -> int:
    crop = 0.12
    dirs = []
    for a in argv:
        if a.startswith("--crop="):
            crop = float(a[7:])
        else:
            dirs.append(a)
    if not dirs:
        print(__doc__)
        return 1
    a_dir = dirs[0]
    b_dir = dirs[1] if len(dirs) > 1 else None
    names = sorted(f for f in os.listdir(a_dir) if f.lower().endswith((".png", ".jpg")))
    rows = []
    for nm in names:
        sa = stats(os.path.join(a_dir, nm), crop)
        sb = stats(os.path.join(b_dir, nm), crop) if b_dir and os.path.exists(os.path.join(b_dir, nm)) else None
        rows.append((nm, sa, sb))
    if b_dir:
        print("%-28s %18s %18s %16s" % ("frame", "mean before>after", "p10 before>after", "black% b>a"))
        for nm, sa, sb in rows:
            if sb is None:
                continue
            print("%-28s %8.1f > %-7.1f %8d > %-7d %6.1f > %-6.1f" % (nm[:28], sa["mean"], sb["mean"], sa["p10"], sb["p10"], sa["dark"] * 100, sb["dark"] * 100))
        both = [(sa, sb) for _, sa, sb in rows if sb is not None]
        if both:
            k = len(both)
            print("%-28s %8.1f > %-7.1f %8.1f > %-7.1f %6.1f > %-6.1f" % ("AVERAGE (%d frames)" % k,
                  sum(a["mean"] for a, _ in both) / k, sum(b["mean"] for _, b in both) / k,
                  sum(a["p10"] for a, _ in both) / k, sum(b["p10"] for _, b in both) / k,
                  sum(a["dark"] for a, _ in both) / k * 100, sum(b["dark"] for _, b in both) / k * 100))
    else:
        print("%-28s %7s %5s %5s %5s %7s" % ("frame", "mean", "p10", "p50", "p90", "black%"))
        for nm, sa, _ in rows:
            print("%-28s %7.1f %5d %5d %5d %6.1f" % (nm[:28], sa["mean"], sa["p10"], sa["p50"], sa["p90"], sa["dark"] * 100))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
