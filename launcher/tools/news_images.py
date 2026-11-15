"""Cuts the launcher's news pictures from the repo's capture folders: 960x540 (16:9) progressive JPEG, quality 82.

Run from the repo root:  python -I launcher/tools/news_images.py
Writes launcher/assets/news/<name>.jpg and prints name, bytes, source, crop. Add a row to PICTURES to add one.
Every source was looked at first: dark or muddy frames, debug HUDs and the untextured capture dummies are left out.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'launcher', 'assets', 'news')
C = 'docs/captures/'
# name: (source, crop box in source pixels or None). The result is centre-cropped to 16:9 after the box.
PICTURES = {
    'gore_wall.jpg': (C + 'gore_rework/after/pile_09_wall.jpg', None),
    'fix_perk_wall.jpg': (C + 'u19_fixes/after/spot_vault_east.jpg', None),
    'fix_perk_road.jpg': (C + 'u19_fixes/after/spot_carters_road.jpg', None),
    'fix_cellar_before.jpg': (C + 'u19_fixes/pairs/lager_door_unlit.jpg', (0, 22, 960, 562)),
    'fix_cellar_after.jpg': (C + 'u19_fixes/pairs/lager_door_unlit.jpg', (966, 22, 1926, 562)),
    'u19_snow.jpg': (C + 'u19_textures/after/m00_snow.jpg', None),
    'u19_taproom.jpg': (C + 'u19_textures/after/m00_taproom.jpg', None),
    'u19_chapel.jpg': (C + 'u19_textures/after/m01_chapel_lit.jpg', None),
    'u19_lagering_vault.jpg': (C + 'u19_cellar/after/26_lager_tuns_work.jpg', None),
    'u19_sherman.jpg': (C + 'u19_models/turntable/tank_eye_3m.jpg', None),
    'u19_crate_column.jpg': (C + 'u19_box_crucible/after/map00_crate_well_idle.jpg', None),
    'u19_crucible.jpg': (C + 'u19_box_crucible/after/map00_crucible_forge_front.jpg', None),
    'u18_type100.jpg': (C + 'u18_guns/type100_blender_front34.png', None),
    # the air raid frame carries the capture's minimap and a debug line on the left: cut to the yard
    'u18_air_raid.jpg': (C + 'u18_sherman/inn/inn_raid.png', (560, 180, 1698, 820)),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, (src, box) in PICTURES.items():
        im = Image.open(os.path.join(ROOT, src)).convert('RGB')
        if box:
            im = im.crop(box)
        w, h = im.size
        if w * 9 > h * 16:
            nw = h * 16 // 9
            im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        elif w * 9 < h * 16:
            nh = w * 9 // 16
            im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        im = im.resize((960, 540), Image.LANCZOS)
        path = os.path.join(OUT, name)
        im.save(path, quality=82, optimize=True, progressive=True)
        size = os.path.getsize(path)
        total += size
        print(f'{name}\t{size}\t{src}\t{box or ""}')
    print('total', total)


if __name__ == '__main__':
    sys.exit(main())
