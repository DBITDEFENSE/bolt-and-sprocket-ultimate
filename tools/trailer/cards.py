#!/usr/bin/env python3
"""T-285: the trailers' title cards and text overlays (PIL), in the game's own type: Stardos Stencil Bold (the
wordmark's lettering) and Special Elite (the cards' typewriter face), both OFL fonts already in
assets/third_party/google_fonts. Cards are 1920x1080 PNGs, transparent where an overlay sits on footage."""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets", "third_party", "google_fonts")
STENCIL = os.path.join(FONTS, "stardos-stencil", "StardosStencil-Bold.ttf")
TYPE = os.path.join(FONTS, "special-elite", "SpecialElite-Regular.ttf")
W, H = 1920, 1080
BONE = (232, 226, 212)
BLOOD = (168, 18, 13)
EMBER = (255, 140, 60)


def _spaced(draw, xy_center, text, font, fill, spacing: int):
    """Draw letter-spaced text centred on xy_center."""
    widths = [draw.textlength(c, font=font) for c in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = xy_center[0] - total / 2
    asc, desc = font.getmetrics()
    y = xy_center[1] - (asc + desc) / 2
    for c, w in zip(text, widths):
        draw.text((x, y), c, font=font, fill=fill)
        x += w + spacing


def title(path: str, word: str = "GRAVELIGHT", sub: str = "TERMS & CONDITIONS", line: str = "", glow=BLOOD, bg=(0, 0, 0, 255)):
    """The title card: the word large in the stencil face with a dark-red glow, a thin rule, a small line under it."""
    img = Image.new("RGBA", (W, H), bg)
    glow_l = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_l)
    big = ImageFont.truetype(STENCIL, 210)
    _spaced(gd, (W / 2, H / 2 - 40), word, big, glow + (255,), 26)
    glow_l = glow_l.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(glow_l)
    img.alpha_composite(glow_l)
    d = ImageDraw.Draw(img)
    _spaced(d, (W / 2, H / 2 - 40), word, big, BONE + (255,), 26)
    d.line([(W / 2 - 520, H / 2 + 92), (W / 2 + 520, H / 2 + 92)], fill=glow + (255,), width=3)
    small = ImageFont.truetype(TYPE, 46)
    if sub:
        _spaced(d, (W / 2, H / 2 + 150), sub, small, BONE + (230,), 14)
    if line:
        tiny = ImageFont.truetype(TYPE, 34)
        _spaced(d, (W / 2, H / 2 + 225), line, tiny, (180, 172, 160, 220), 6)
    img.save(path)


def text_card(path: str, text: str, size: int = 64, color=BONE, bg=(0, 0, 0, 255), y: float = 0.5, spacing: int = 8, face: str = "type"):
    """A line (or two, split on |) of card text on black (or transparent with bg alpha 0)."""
    img = Image.new("RGBA", (W, H), bg)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(TYPE if face == "type" else STENCIL, size)
    lines = text.split("|")
    for i, ln in enumerate(lines):
        yy = H * y + (i - (len(lines) - 1) / 2) * size * 1.35
        if bg[3] == 0:   # over footage: a soft dark shadow under the letters
            sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            _spaced(ImageDraw.Draw(sh), (W / 2 + 3, yy + 3), ln, f, (0, 0, 0, 220), spacing)
            img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
        _spaced(d, (W / 2, yy), ln, f, color + (255,), spacing)
    img.save(path)


if __name__ == "__main__":
    out = os.path.join(ROOT, "build", "trailers", "cards")
    os.makedirs(out, exist_ok=True)
    title(os.path.join(out, "test_title.png"), line="SILESIA, WINTER 1944")
    text_card(os.path.join(out, "test_text.png"), "THE DEAD ARE KEEPING COUNT.")
    print(out)
