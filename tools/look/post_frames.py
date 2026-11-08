#!/usr/bin/env python3
"""UPDATE 12 section 2 (DECISIONS T-208): files the post-stack captures.

tools/look/post_frames.sh renders the u12_look and u12_post camera sets (and the readability frames) twice into
<dir>/_before/*.png (--look=off: the U11 game) and <dir>/_after/*.png (the grade, the post stack, the material pass,
the darker nights). This writes <dir>/<name>_before.jpg / <name>_after.jpg (1280 px wide, JPEG, at most 400 KB each)
and <dir>/sheet.jpg (every pair side by side, before left), and prints each frame's mean luma and the share of
saturated pixels (the bible's value and accent checks). Pure file work: no Godot here.

    python -I tools/look/post_frames.py docs/look/post [--cap-kb 400] [--keep-raw]
"""
import argparse
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageStat


def save_jpg(img: Image.Image, path: str, cap_kb: int) -> None:
    for q in (86, 80, 74, 68, 60, 52):
        img.save(path, quality=q, optimize=True, progressive=True)
        if os.path.getsize(path) <= cap_kb * 1024:
            return


def stats(img: Image.Image) -> str:
    small = img.resize((320, round(img.height * 320 / img.width)))
    luma = ImageStat.Stat(small.convert("L")).mean[0]
    hsv = small.convert("HSV")
    px = list(hsv.getdata())
    sat = sum(1 for h, s, v in px if s > 128 and v > 40) / max(1, len(px))
    violet = sum(1 for h, s, v in px if s > 128 and v > 40 and 175 <= h <= 205) / max(1, len(px))
    return f"mean luma {luma:5.1f}, saturated {sat * 100:4.1f}%, violet {violet * 100:4.1f}%"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir")
    ap.add_argument("--cap-kb", type=int, default=400)
    ap.add_argument("--keep-raw", action="store_true")
    a = ap.parse_args()
    pairs = {}
    for label in ("before", "after"):
        src = os.path.join(a.dir, "_" + label)
        if not os.path.isdir(src):
            continue
        for fn in sorted(os.listdir(src)):
            if not fn.lower().endswith(".png"):
                continue
            name = os.path.splitext(fn)[0]
            img = Image.open(os.path.join(src, fn)).convert("RGB")
            if img.width > 1280:
                img = img.resize((1280, round(img.height * 1280 / img.width)), Image.LANCZOS)
            out = os.path.join(a.dir, f"{name}_{label}.jpg")
            save_jpg(img, out, a.cap_kb)
            pairs.setdefault(name, {})[label] = out
            print(f"{name:22s} {label:6s} {stats(img)}  {os.path.getsize(out) // 1024} KB")
    if not pairs:
        print("no frames")
        return 1
    w, h, pad, head = 640, 268, 6, 22
    names = sorted(pairs)
    canvas = Image.new("RGB", (2 * w + 3 * pad, len(names) * (h + head + pad) + pad), (14, 14, 16))
    draw = ImageDraw.Draw(canvas)
    for i, n in enumerate(names):
        y = pad + i * (h + head + pad)
        for col, label in enumerate(("before", "after")):
            x = pad + col * (w + pad)
            draw.text((x + 2, y + 3), f"{n}  {label}", fill=(220, 214, 196))
            p = pairs[n].get(label)
            if p:
                im = Image.open(p).convert("RGB")
                im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
                canvas.paste(im.crop((0, 0, w, min(h, im.height))), (x, y + head))
    save_jpg(canvas, os.path.join(a.dir, "sheet.jpg"), 2048)
    if not a.keep_raw:
        for label in ("before", "after"):
            shutil.rmtree(os.path.join(a.dir, "_" + label), ignore_errors=True)
    print(f"{len(names)} pairs, sheet.jpg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
