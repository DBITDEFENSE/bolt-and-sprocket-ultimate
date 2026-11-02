"""Copy the rendered map previews into the game (UPDATE 09 section 7, DECISIONS T-144).

The u09_menu_previews capture set (data/gravelight/capture_cams.json, tools_src/capture.gd mode "maps") saves one
establishing frame per map as morning/screenshots/u09_menu_previews/<label>/<map_id>.png. This scales each to
960 x 540 (16:9, centre-cropped if the render was another aspect) and writes gravelight/ui/map_previews/<map_id>.png,
which MapCards and the loading screen read.

Usage: python -I tools/menu_previews.py [label]      (label defaults to "raw")
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 960, 540
## A gentle gamma lift for the renders too dark to read at card size (the software-GL render of the Kranich's
## red-lit bomb bay, the Thalbach yard at night). 1.0 = as rendered.
GAMMA = {"map04a_thalbach": 1.35, "map04b_kranich": 1.9}


def main() -> int:
    label = sys.argv[1] if len(sys.argv) > 1 else "raw"
    src = os.path.join(ROOT, "morning", "screenshots", "u09_menu_previews", label)
    dst = os.path.join(ROOT, "gravelight", "ui", "map_previews")
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or not f.startswith("map"):
            continue
        im = Image.open(os.path.join(src, f)).convert("RGB")
        aspect = im.width / im.height
        if aspect > W / H:   # too wide: crop the sides
            nw = int(im.height * W / H)
            x0 = (im.width - nw) // 2
            im = im.crop((x0, 0, x0 + nw, im.height))
        elif aspect < W / H:
            nh = int(im.width * H / W)
            y0 = (im.height - nh) // 2
            im = im.crop((0, y0, im.width, y0 + nh))
        im = im.resize((W, H), Image.LANCZOS)
        g = GAMMA.get(f[:-4], 1.0)
        if g != 1.0:
            lut = [min(255, int(round(255.0 * (i / 255.0) ** (1.0 / g)))) for i in range(256)]
            im = im.point(lut * 3)
        im.save(os.path.join(dst, f), optimize=True)
        n += 1
        print("menu_previews:", f)
    print("menu_previews: %d previews written to %s" % (n, dst))
    return 0 if n > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
