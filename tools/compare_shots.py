#!/usr/bin/env python
"""Stitch same-camera before/after pairs side by side (UPDATE_05 section 1, T-088).

    python -I tools/compare_shots.py [before_label] [after_label] [--set=u05] [--root=morning/screenshots] [--out=<dir>]

Pairs morning/screenshots/<set>/<before>/NN_<name>.png with <set>/<after>/NN_<name>.png by file name and writes
<set>/pairs/NN_<name>__<before>_vs_<after>.png (the two frames at half size with a caption bar), plus a
contact sheet <set>/pairs/sheet__<before>_vs_<after>.png. Missing partners are listed, not faked.
"""
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("Pillow is required: pip install pillow", file=sys.stderr)
    sys.exit(2)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main(argv):
    before, after, set_name, root, out = "before", "after", "u05", os.path.join(ROOT, "morning", "screenshots"), None
    pos = []
    for a in argv:
        if a.startswith("--set="):
            set_name = a[6:]
        elif a.startswith("--root="):
            root = a[7:]
        elif a.startswith("--out="):
            out = a[6:]
        else:
            pos.append(a)
    if pos:
        before = pos[0]
    if len(pos) > 1:
        after = pos[1]
    bdir = os.path.join(root, set_name, before)
    adir = os.path.join(root, set_name, after)
    out = out or os.path.join(root, set_name, "pairs")
    if not os.path.isdir(bdir) or not os.path.isdir(adir):
        print("missing folder: %s or %s" % (bdir, adir))
        return 1
    os.makedirs(out, exist_ok=True)
    names_b = {f for f in os.listdir(bdir) if f.lower().endswith(".png")}
    names_a = {f for f in os.listdir(adir) if f.lower().endswith(".png")}
    pairs = sorted(names_b & names_a)
    tiles = []
    for name in pairs:
        im_b = Image.open(os.path.join(bdir, name)).convert("RGB")
        im_a = Image.open(os.path.join(adir, name)).convert("RGB")
        w, h = im_b.size
        if im_a.size != (w, h):
            im_a = im_a.resize((w, h), Image.LANCZOS)
        half = (w // 2, h // 2)
        b2 = im_b.resize(half, Image.LANCZOS)
        a2 = im_a.resize(half, Image.LANCZOS)
        bar = 24
        pair = Image.new("RGB", (half[0] * 2 + 4, half[1] + bar), (16, 16, 16))
        pair.paste(b2, (0, bar))
        pair.paste(a2, (half[0] + 4, bar))
        d = ImageDraw.Draw(pair)
        d.text((6, 6), "%s  |  %s" % (name[:-4], before), fill=(230, 230, 230))
        d.text((half[0] + 10, 6), after, fill=(230, 230, 230))
        p = os.path.join(out, "%s__%s_vs_%s.png" % (name[:-4], before, after))
        pair.save(p, optimize=True)
        tiles.append(pair)
    if tiles:
        cols = 2
        tw, th = tiles[0].size
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tw, rows * th), (10, 10, 10))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
        sheet.thumbnail((2400, 100000), Image.LANCZOS)
        sheet.save(os.path.join(out, "sheet__%s_vs_%s.png" % (before, after)), optimize=True)
    print("%d pairs -> %s" % (len(pairs), out))
    for n in sorted(names_b - names_a):
        print("  only in %s: %s" % (before, n))
    for n in sorted(names_a - names_b):
        print("  only in %s: %s" % (after, n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
