#!/usr/bin/env python
"""T-266: how much two folders of same-named shots differ, pair by pair (before / after a render change).

    python -I tools/perf/shot_diff.py <before dir> <after dir> [--sheet=<out.jpg>]

Per pair: the mean absolute difference (0-255), the share of pixels that differ by more than 24 / 255 after a small
blur (grain and single snowflakes drop out; a missing wall, lamp pool or shadow does not), and the box those pixels
sit in. Two shots of a living map are never equal (snow, searchlights, sway, film grain): read the numbers as
"where to look", then look. --sheet writes before | after | difference rows side by side.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def main(argv):
    dirs = [a for a in argv if not a.startswith("--")]
    sheet = next((a[8:] for a in argv if a.startswith("--sheet=")), "")
    before, after = dirs[0], dirs[1]
    rows = []
    for name in sorted(os.listdir(before)):
        if not name.lower().endswith((".png", ".jpg")) or not os.path.exists(os.path.join(after, name)):
            continue
        a = Image.open(os.path.join(before, name)).convert("RGB")
        b = Image.open(os.path.join(after, name)).convert("RGB")
        if a.size != b.size:
            b = b.resize(a.size)
        d = ImageChops.difference(a.filter(ImageFilter.GaussianBlur(2)), b.filter(ImageFilter.GaussianBlur(2))).convert("L")
        hist = d.histogram()
        n = a.size[0] * a.size[1]
        mean = sum(i * h for i, h in enumerate(hist)) / n
        over = sum(hist[25:]) / n * 100.0
        box = d.point(lambda v: 255 if v > 24 else 0).getbbox()
        print("%-34s mean %.2f, over 24: %.2f %% of the picture, in %s" % (name, mean, over, box))
        rows.append((name, a, b, d))
    if sheet and rows:
        w, h = rows[0][1].size
        s = 0.5
        tw, th = int(w * s), int(h * s)
        out = Image.new("RGB", (tw * 3, (th + 14) * len(rows)), (16, 16, 16))
        dr = ImageDraw.Draw(out)
        for i, (name, a, b, d) in enumerate(rows):
            y = i * (th + 14)
            out.paste(a.resize((tw, th)), (0, y + 14))
            out.paste(b.resize((tw, th)), (tw, y + 14))
            out.paste(d.point(lambda v: min(255, v * 4)).convert("RGB").resize((tw, th)), (tw * 2, y + 14))
            dr.text((4, y + 1), "%s: before | after | difference x4" % name, fill=(220, 220, 220))
        os.makedirs(os.path.dirname(os.path.abspath(sheet)), exist_ok=True)
        out.save(sheet, quality=82)
        print("sheet:", sheet)


if __name__ == "__main__":
    main(sys.argv[1:])
