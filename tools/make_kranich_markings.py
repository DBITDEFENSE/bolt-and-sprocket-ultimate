#!/usr/bin/env python
"""Der Kranich's upper-skin stencils (T-220): one 1024x1024 RGBA atlas of eight 1024x128 cells, white paint in the
alpha (the hull shader tints it and wears it), our own lettering in the OFL Stardos Stencil font already in the repo.

    python -I tools/make_kranich_markings.py   ->  assets/ours/textures/kranich_markings/kranich_markings.png

Cells (data/gravelight/map04b_plane.json hull.markings name them by index): 0 the fictional unit code, 1 NICHT
BETRETEN (no step), 2 NOTAUSSTIEG (emergency exit), 3 HEISS (hot, by the nozzles), 4 WARTUNG (maintenance),
5 the airframe number, 6 TREIBSTOFF (fuel), 7 a walkway arrow. No emblem of any kind (docs/ART_FACTIONS.md).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FONT = os.path.join(ROOT, "assets", "third_party", "google_fonts", "stardos-stencil", "StardosStencil-Bold.ttf")
OUT = os.path.join(ROOT, "assets", "ours", "textures", "kranich_markings", "kranich_markings.png")
CELLS = ["KR + 01", "NICHT BETRETEN", "NOTAUSSTIEG", "HEISS", "WARTUNG", "01", "TREIBSTOFF", None]
W, H = 1024, 128


def main() -> None:
    img = Image.new("RGBA", (W, H * len(CELLS)), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for i, text in enumerate(CELLS):
        y0 = i * H
        if text is None:
            # a walkway arrow: a shaft and a head, pointing along +u
            d.rectangle([140, y0 + 52, 760, y0 + 76], fill=(255, 255, 255, 255))
            d.polygon([(740, y0 + 24), (900, y0 + 64), (740, y0 + 104)], fill=(255, 255, 255, 255))
            continue
        size = 112
        while size > 20:
            f = ImageFont.truetype(FONT, size)
            bb = d.textbbox((0, 0), text, font=f)
            if bb[2] - bb[0] <= W - 48 and bb[3] - bb[1] <= H - 18:
                break
            size -= 4
        bb = d.textbbox((0, 0), text, font=f)
        x = (W - (bb[2] - bb[0])) // 2 - bb[0]
        y = y0 + (H - (bb[3] - bb[1])) // 2 - bb[1]
        d.text((x, y), text, font=f, fill=(255, 255, 255, 255))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
