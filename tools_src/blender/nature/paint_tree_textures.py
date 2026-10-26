#!/usr/bin/env python
"""Paints the card and bark textures for Map 0's scripted trees (UPDATE_05 section 5, DECISIONS T-093). Ours, no input
files: every stroke comes from a seeded RNG, so a re-run gives the same PNGs.

    python -I tools_src/blender/nature/paint_tree_textures.py [out_dir]

Writes into assets/ours/env/nature/textures/ (default):
  tex_spruce_frond.png  512x512 RGBA  one snow-laden spruce frond: the twig enters at the left edge's middle
                                      (u 0, v 0.5) and runs to the right; side twigs and needles, snow lying on the
                                      upper side (image top) of the twigs; alpha-scissor cut-out
  tex_birch_twigs.png   512x512 RGBA  a bare winter birch spray, same frame (enters at the left middle)
  tex_birch_bark.png    512x512 RGB   white birch bark with dark lenticels and black patches, tiles in both axes
Painted at 2x and downsampled for anti-aliasing; transparent pixels carry the nearest colour (no dark fringes when
mipmapped). Values stay inside ART_BIBLE's 0.04..0.90 albedo range.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "ours", "env", "nature", "textures")
S = 1024   # paint size; saved at 512


def bleed(img: Image.Image) -> Image.Image:
    """Spreads opaque colour into the transparent pixels (alpha untouched), so mip levels don't darken the edges."""
    rgb = img.convert("RGB")
    a = img.getchannel("A")
    base = rgb.copy()
    mask = a.point(lambda v: 255 if v > 8 else 0)
    for r in (2, 4, 8, 16, 32):
        blurred = base.filter(ImageFilter.BoxBlur(r))
        holes = mask.point(lambda v: 255 - v)
        base = Image.composite(base, blurred, mask)
        mask = Image.composite(mask, mask.filter(ImageFilter.MaxFilter(5)), mask)
    out = Image.composite(rgb, base, a.point(lambda v: 255 if v > 8 else 0))
    out.putalpha(a)
    return out


def col(r, g, b, a=255):
    return (int(r * 255), int(g * 255), int(b * 255), a)


def spruce_frond(rng: random.Random) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = S * 0.5
    twigs = []   # (x0, y0, x1, y1, width)
    twigs.append((0, cy, S * 0.97, cy + rng.uniform(-10, 10), 14))
    x = S * 0.04
    while x < S * 0.9:
        t = x / S
        length = (1.0 - t) * S * 0.36 + 30
        for side in (-1, 1):
            ang = math.radians(rng.uniform(32, 48)) * side
            ex = x + math.cos(ang) * length
            ey = cy + math.sin(ang) * length * 0.9
            twigs.append((x, cy, ex, ey, 6))
        x += rng.uniform(46, 62)
    # needles along every twig: short dark-green strokes angled forward, densest near the stem
    for (x0, y0, x1, y1, w) in twigs:
        n = int(math.hypot(x1 - x0, y1 - y0) / 2.5)
        for k in range(n):
            t = k / max(1, n - 1)
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t
            base = math.atan2(y1 - y0, x1 - x0)
            for side in (-1, 1):
                a = base + side * math.radians(rng.uniform(40, 75))
                ln = rng.uniform(30, 52) * (1.0 - 0.4 * t)
                g = rng.uniform(0.75, 1.15)
                c = col(0.05 * g, 0.11 * g, 0.075 * g)
                d.line((px, py, px + math.cos(a) * ln, py + math.sin(a) * ln), fill=c, width=4)
    for (x0, y0, x1, y1, w) in twigs:
        d.line((x0, y0, x1, y1), fill=col(0.16, 0.11, 0.07), width=w)
    # snow lying on the upper side (the image's top = the card's up side) of the twigs: soft lumps
    snow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(snow)
    for (x0, y0, x1, y1, w) in twigs:
        n = int(math.hypot(x1 - x0, y1 - y0) / 18)
        for k in range(n):
            if rng.random() < 0.6:
                continue
            t = (k + rng.random()) / max(1, n)
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t - rng.uniform(6, 16)
            r = rng.uniform(6, 13) * (1.0 - 0.4 * t)
            v = rng.uniform(0.78, 0.88)
            sd.ellipse((px - r * 1.4, py - r * 0.8, px + r * 1.4, py + r * 0.8), fill=col(v * 0.96, v * 0.98, v))
    snow = snow.filter(ImageFilter.GaussianBlur(2.0))
    img.alpha_composite(snow)
    return img


def birch_twigs(rng: random.Random) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def branch(x, y, ang, length, w, depth):
        ex = x + math.cos(ang) * length
        ey = y + math.sin(ang) * length
        shade = rng.uniform(0.8, 1.1)
        d.line((x, y, ex, ey), fill=col(0.20 * shade, 0.12 * shade, 0.09 * shade), width=max(3, int(w)))
        if depth <= 0 or length < 18:
            return
        k = rng.randint(2, 4)
        for i in range(k):
            t = rng.uniform(0.35, 1.0)
            bx = x + (ex - x) * t
            by = y + (ey - y) * t
            branch(bx, by, ang + rng.uniform(-0.7, 0.7), length * rng.uniform(0.45, 0.7), w * 0.65, depth - 1)

    branch(0, S * 0.5, rng.uniform(-0.08, 0.08), S * 0.6, 14, 6)
    for k in range(5):
        branch(S * rng.uniform(0.08, 0.4), S * 0.5, rng.uniform(-0.9, 0.9), S * rng.uniform(0.3, 0.45), 8, 5)
    # a little snow on the upper twigs
    for _ in range(40):
        x = rng.uniform(S * 0.1, S * 0.9)
        y = rng.uniform(S * 0.25, S * 0.75)
        if img.getpixel((int(x), int(y)))[3] > 0:
            r = rng.uniform(3, 7)
            d.ellipse((x - r * 1.5, y - r - 4, x + r * 1.5, y - 2), fill=col(0.82, 0.84, 0.88))
    return img


def birch_bark(rng: random.Random) -> Image.Image:
    n = S // 2
    img = Image.new("RGB", (n, n), col(0.74, 0.73, 0.69)[:3])
    d = ImageDraw.Draw(img)
    # faint vertical tone streaks
    for _ in range(140):
        x = rng.uniform(0, n)
        v = rng.uniform(0.66, 0.80)
        d.line((x, 0, x + rng.uniform(-6, 6), n), fill=col(v, v * 0.99, v * 0.94)[:3], width=rng.randint(2, 8))
    # horizontal lenticels: short dark dashes, wrapped so the texture tiles
    for _ in range(170):
        x = rng.uniform(0, n)
        y = rng.uniform(0, n)
        ln = rng.uniform(8, 40)
        v = rng.uniform(0.14, 0.3)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.line((x + ox, y + oy, x + ln + ox, y + oy + rng.uniform(-1, 1)), fill=col(v, v * 0.9, v * 0.85)[:3], width=rng.randint(2, 4))
    # black patches (the scars where branches broke off)
    for _ in range(5):
        x = rng.uniform(0, n)
        y = rng.uniform(0, n)
        w = rng.uniform(10, 30)
        h = rng.uniform(5, 12)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.ellipse((x - w + ox, y - h + oy, x + w + ox, y + h + oy), fill=col(0.06, 0.055, 0.05)[:3])
    return img.filter(ImageFilter.GaussianBlur(0.8))


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(1944)
    fr = bleed(spruce_frond(rng)).resize((512, 512), Image.LANCZOS)
    fr.save(os.path.join(OUT, "tex_spruce_frond.png"))
    tw = bleed(birch_twigs(rng)).resize((512, 512), Image.LANCZOS)
    tw.save(os.path.join(OUT, "tex_birch_twigs.png"))
    birch_bark(rng).save(os.path.join(OUT, "tex_birch_bark.png"))
    print("textures ->", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
