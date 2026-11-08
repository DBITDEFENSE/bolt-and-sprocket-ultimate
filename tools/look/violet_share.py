#!/usr/bin/env python3
"""UPDATE 12 (DECISIONS T-214): how much of a frame is Nachtglas violet (docs/ART_BIBLE.md: at most 5% in a normal
frame, 25% in the Core and on Mondlicht).

A pixel counts as violet when its hue is 240..300 degrees, it is not near-black (value > 0.12) and it is visibly
coloured: `strict` saturation > 0.5 (the bible's measure, section 6: the accent itself: a tube, a strip, its hot pool), `tinted` saturation > 0.2
(a wall or floor washed violet by a fill light, the fog or the ambient: the "flood" the blind review saw).

    python -I tools/look/violet_share.py docs/look/post/map04d_concourse_after.jpg [more.jpg ...]
"""
import colorsys
import sys

from PIL import Image


def share(path: str) -> tuple:
    img = Image.open(path).convert("RGB")
    img = img.resize((320, max(1, round(img.height * 320 / img.width))))
    px = list(img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata())
    strict = tinted = 0
    for r, g, b in px:
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if v <= 0.12 or not (240.0 <= h * 360.0 <= 300.0):
            continue
        if s > 0.2:
            tinted += 1
            if s > 0.5:
                strict += 1
    n = max(1, len(px))
    return strict / n, tinted / n


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for p in sys.argv[1:]:
        st, ti = share(p)
        print(f"{p}: violet {st * 100:5.1f}% (strict, s > 0.5: the bible's measure), {ti * 100:5.1f}% tinted (s > 0.2)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
