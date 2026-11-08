#!/usr/bin/env python3
"""UPDATE 12 section 1 (T-207): files the style frames.

tools/look/style_frames.sh renders the u12_look camera set twice (before = --look=off, after = the grade) into
<frames>/_before/<name>.png and <frames>/_after/<name>.png. This turns them into the committed pair
<frames>/<name>_before.<ext> / <name>_after.<ext>: 1280x720 at most, PNG when that stays under the size cap,
else JPEG (quality 88), and writes <frames>/sheet.jpg, every pair side by side (before left, after right), for the
blind look review. Pure file work: no Godot here.

    python -I tools/look/style_frames.py docs/look/frames [--cap-kb 400] [--keep-raw]
"""
import argparse
import os
import shutil
import sys

from PIL import Image, ImageDraw


def file_pair(frames: str, label: str, cap_kb: int) -> dict:
    """Moves <frames>/_<label>/*.png to <frames>/<name>_<label>.<ext>; returns {name: path}."""
    out = {}
    src = os.path.join(frames, "_" + label)
    if not os.path.isdir(src):
        return out
    for fn in sorted(os.listdir(src)):
        if not fn.lower().endswith(".png"):
            continue
        name = os.path.splitext(fn)[0]
        img = Image.open(os.path.join(src, fn)).convert("RGB")
        if img.width > 1280:
            img = img.resize((1280, round(img.height * 1280 / img.width)), Image.LANCZOS)
        for old in (f"{name}_{label}.png", f"{name}_{label}.jpg"):
            p = os.path.join(frames, old)
            if os.path.exists(p):
                os.remove(p)
        png = os.path.join(frames, f"{name}_{label}.png")
        img.save(png, optimize=True)
        if os.path.getsize(png) > cap_kb * 1024:
            os.remove(png)
            jpg = os.path.join(frames, f"{name}_{label}.jpg")
            img.save(jpg, quality=88, optimize=True, progressive=True)
            out[name] = jpg
        else:
            out[name] = png
    return out


def sheet(frames: str, before: dict, after: dict) -> str:
    names = [n for n in sorted(set(before) | set(after))]
    if not names:
        return ""
    w, h = 640, 360
    pad, head = 6, 22
    cell_h = h + head + pad
    canvas = Image.new("RGB", (2 * w + 3 * pad, len(names) * cell_h + pad), (14, 14, 16))
    draw = ImageDraw.Draw(canvas)
    for i, n in enumerate(names):
        y = pad + i * cell_h
        for col, (label, table) in enumerate((("before", before), ("after", after))):
            x = pad + col * (w + pad)
            draw.text((x + 2, y + 3), f"{n}  {label}", fill=(220, 214, 196))
            p = table.get(n)
            if p and os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS)
                canvas.paste(im, (x, y + head))
            else:
                draw.rectangle((x, y + head, x + w, y + head + h), outline=(80, 80, 80))
                draw.text((x + 10, y + head + 10), "(no frame)", fill=(160, 160, 160))
    out = os.path.join(frames, "sheet.jpg")
    canvas.save(out, quality=72, optimize=True, progressive=True)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("frames")
    ap.add_argument("--cap-kb", type=int, default=400)
    ap.add_argument("--keep-raw", action="store_true", help="keep the _before / _after folders")
    a = ap.parse_args()
    before = file_pair(a.frames, "before", a.cap_kb)
    after = file_pair(a.frames, "after", a.cap_kb)
    # a partial render (one label, or --only a few cams) keeps the earlier frames of everything else for the sheet
    for label, table in (("before", before), ("after", after)):
        for fn in os.listdir(a.frames):
            if fn.endswith(f"_{label}.png") or fn.endswith(f"_{label}.jpg"):
                table.setdefault(fn.rsplit("_", 1)[0], os.path.join(a.frames, fn))
    s = sheet(a.frames, before, after)
    if not a.keep_raw:
        for label in ("before", "after"):
            shutil.rmtree(os.path.join(a.frames, "_" + label), ignore_errors=True)
    for n in sorted(set(before) | set(after)):
        parts = []
        for label, table in (("before", before), ("after", after)):
            p = table.get(n)
            parts.append(f"{label} {os.path.getsize(p) // 1024} KB" if p and os.path.exists(p) else f"{label} -")
        print(f"[frames] {n}: " + ", ".join(parts))
    if s:
        print(f"[frames] sheet: {s} ({os.path.getsize(s) // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
