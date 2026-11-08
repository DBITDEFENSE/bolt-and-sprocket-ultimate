#!/usr/bin/env python3
"""GRAVELIGHT ONE's markings and stencils as one RGBA atlas (UPDATE 12 section 5.2 item 3, DECISIONS T-211).

    python -I tools/c47/make_decals.py <out.png>

Our own drawing (Pillow), with the project's bundled OFL fonts (Stardos Stencil, Special Elite: assets/third_party/
google_fonts). An RAF Dakota from Brindisi flying special duties in the olive drab over neutral grey it was delivered
in: the C1 roundel (fuselage), the B roundel (upper wing), the fin flash, the FICTIONAL serial KQ913 (the RAF never
used Q in a serial, so it can't be a real aircraft's), the individual letter G, "GRAVELIGHT ONE" small under the
cockpit, the cabin's stencils, the instrument faces, frost for the windows. No real unit codes, no Axis symbols.
The cells (in 0..1 UV, x0 y0 x1 y1, origin top-left) are written next to the PNG as <out>.json for the Blender script.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets", "third_party", "google_fonts")
STENCIL = os.path.join(FONTS, "stardos-stencil", "StardosStencil-Bold.ttf")
TYPE = os.path.join(FONTS, "special-elite", "SpecialElite-Regular.ttf")
W, H = 2048, 2048

# RAF colours as they weathered on a Dakota in Italy (dull, not toy-bright)
RAF_BLUE = (38, 52, 84, 255)
RAF_RED = (128, 38, 30, 255)
WHITE = (196, 192, 178, 255)
YELLOW = (178, 148, 52, 255)
SKY = (156, 168, 146, 255)
STENCIL_C = (200, 194, 172, 255)
BLACK = (20, 20, 18, 255)

CELLS = {}


def cell(name, x0, y0, x1, y1):
    CELLS[name] = [x0 / W, y0 / H, x1 / W, y1 / H]
    return (x0, y0, x1, y1)


def font(path, size):
    return ImageFont.truetype(path, size)


def rough_edge(im, box, amount=2):
    """Slight paint wear: knocks random pixels' alpha down inside the box."""
    rnd = random.Random(box[0] * 7 + box[1])
    px = im.load()
    for _ in range(int((box[2] - box[0]) * (box[3] - box[1]) * 0.02)):
        x = rnd.randrange(box[0], box[2])
        y = rnd.randrange(box[1], box[3])
        r, g, b, a = px[x, y]
        if a > 0:
            px[x, y] = (r, g, b, max(0, a - rnd.randrange(60, 200)))


def text_in(d, box, txt, fnt, fill, anchor="mm"):
    cx = (box[0] + box[2]) // 2
    cy = (box[1] + box[3]) // 2
    d.text((cx, cy), txt, font=fnt, fill=fill, anchor=anchor)


def main(out):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    random.seed(23121944)

    # --- the C1 roundel (yellow ring, blue, white, red: 3:2:... proportions of the 1942-45 C1, simplified)
    b = cell("roundel_c1", 0, 0, 512, 512)
    c = (256, 256)
    for r, col in ((250, YELLOW), (232, RAF_BLUE), (122, WHITE), (98, RAF_RED)):
        d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=col)
    rough_edge(im, b)
    # --- the B roundel (blue and red only: upper wing surfaces)
    b = cell("roundel_b", 512, 0, 1024, 512)
    c = (768, 256)
    for r, col in ((250, RAF_BLUE), (100, RAF_RED)):
        d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=col)
    rough_edge(im, b)
    # --- the fin flash (red, white, blue: red leading)
    b = cell("fin_flash", 1024, 0, 1280, 512)
    d.rectangle((1024, 0, 1024 + 110, 512), fill=RAF_RED)
    d.rectangle((1024 + 110, 0, 1024 + 146, 512), fill=WHITE)
    d.rectangle((1024 + 146, 0, 1280, 512), fill=RAF_BLUE)
    rough_edge(im, b)
    # --- the fictional serial (black, the RAF's 8 in style) and the individual letter
    b = cell("serial", 1280, 0, 2048, 256)
    text_in(d, b, "KQ913", font(STENCIL, 210), BLACK)
    b = cell("letter_g", 1280, 256, 1536, 512)
    text_in(d, b, "G", font(STENCIL, 230), SKY)
    # --- GRAVELIGHT ONE, small, stencilled under the cockpit
    b = cell("name", 1536, 256, 2048, 384)
    text_in(d, b, "GRAVELIGHT ONE", font(STENCIL, 52), STENCIL_C)
    b = cell("no_step", 1536, 384, 2048, 512)
    text_in(d, b, "NO STEP", font(STENCIL, 72), BLACK)
    # --- cabin stencils (cream/black on transparent)
    rows = [("no_smoking", "NO SMOKING"), ("static_line", "STATIC LINE  -  HOOK UP HERE"), ("exit", "EMERGENCY EXIT  PULL"),
            ("first_aid", "FIRST AID KIT"), ("max_load", "MAX FLOOR LOAD 200 LB PER SQ FT"), ("fuel", "100 OCTANE  -  FUEL"),
            ("crate_a", "SUPPLIES  /  HANDLE WITH CARE"), ("crate_b", "RATIONS  10-IN-1"), ("radio", "R.T. SET  -  DO NOT TOUCH"),
            ("oxygen", "OXYGEN"), ("chute", "PARACHUTE  -  PACK NO. 7"), ("door", "CARGO DOOR  -  KEEP CLEAR")]
    y = 512
    for k, (key, txt) in enumerate(rows):
        b = cell(key, 0, y, 1024, y + 80)
        col = BLACK if k % 3 == 1 else STENCIL_C
        text_in(d, b, txt, font(STENCIL, 52), col)
        y += 80
    # --- instrument faces: 12 dials in a 4x3 block (1024..2048 x 512..1280)
    tf = font(TYPE, 22)
    for i in range(12):
        gx = 1024 + (i % 4) * 256
        gy = 512 + (i // 4) * 256
        b = cell("dial_%d" % i, gx, gy, gx + 256, gy + 256)
        cx, cy = gx + 128, gy + 128
        d.ellipse((cx - 124, cy - 124, cx + 124, cy + 124), fill=(30, 30, 28, 255))
        d.ellipse((cx - 112, cy - 112, cx + 112, cy + 112), fill=(12, 12, 12, 255))
        for t in range(0, 360, 30 if i % 2 == 0 else 20):
            a = math.radians(t)
            r0 = 92 if t % 90 else 82
            d.line((cx + math.sin(a) * r0, cy - math.cos(a) * r0, cx + math.sin(a) * 106, cy - math.cos(a) * 106),
                   fill=(210, 205, 185, 255), width=4 if t % 90 == 0 else 2)
        lab = ["ALT", "A/S", "RPM", "MAN.", "OIL", "FUEL", "CLIMB", "T&B", "HDG", "CYL", "PRESS", "VAC"][i]
        d.text((cx, cy + 44), lab, font=tf, fill=(200, 196, 176, 255), anchor="mm")
        a = math.radians(random.uniform(-150, 150))
        d.line((cx, cy, cx + math.sin(a) * 88, cy - math.cos(a) * 88), fill=(225, 220, 200, 255), width=5)
        d.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=(60, 60, 58, 255))
    # --- frost for the windows (white, noisy alpha, denser at the edges)
    b = cell("frost", 0, 1536, 512, 2048)
    fr = Image.new("L", (512, 512), 0)
    fp = fr.load()
    rnd = random.Random(7)
    for yy in range(512):
        for xx in range(512):
            e = min(xx, yy, 511 - xx, 511 - yy) / 256.0
            base = max(0.0, 0.85 - e * 1.4)
            fp[xx, yy] = int(255 * min(1.0, base + rnd.random() * 0.25))
    fr = fr.filter(ImageFilter.GaussianBlur(2.0))
    frost = Image.new("RGBA", (512, 512), (226, 232, 240, 0))
    frost.putalpha(fr)
    im.alpha_composite(frost, (0, 1536))
    # --- the panel lamp lenses and placards (small)
    b = cell("placard", 512, 1536, 1024, 1664)
    d.rectangle(b, fill=(26, 26, 24, 255))
    text_in(d, b, "C-47   SER. KQ913   R.A.F.", font(TYPE, 34), (190, 186, 166, 255))
    b = cell("trim", 512, 1664, 1024, 1792)
    d.rectangle(b, fill=(26, 26, 24, 255))
    text_in(d, b, "THROTTLE   PROP   MIXTURE", font(TYPE, 34), (190, 186, 166, 255))
    # --- the solid white texel (decal quads that only need a colour use it)
    cell("white", 2032, 2032, 2048, 2048)
    d.rectangle((2032, 2032, 2048, 2048), fill=(255, 255, 255, 255))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    im.save(out)
    with open(os.path.splitext(out)[0] + ".json", "w", encoding="utf-8", newline="\n") as f:
        json.dump({"size": [W, H], "cells": CELLS}, f, indent=1, sort_keys=True)
    print("[c47] decals -> %s (%d cells)" % (out, len(CELLS)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "c47", "_gen", "decals.png"))
