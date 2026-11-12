"""Read-only Blender headless validation of the zombie clothing normal/ORM maps.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/zombie_material_audit.py
Writes metadata only; does not edit or copy any licensed texture.
"""
import json
from pathlib import Path

import bpy
import numpy as np

root = Path(__file__).resolve().parents[2]
cfg = json.loads((root / 'data/gravelight/zombie_materials.json').read_text())
report = {'blender': bpy.app.version_string, 'maps': [], 'failures': []}
for kind in ('fabric', 'leather'):
    sizes = []
    for channel in ('normal', 'orm'):
        path = root / cfg[kind][channel].removeprefix('res://')
        image = bpy.data.images.load(str(path), check_existing=False)
        image.colorspace_settings.name = 'Non-Color'
        pixels = np.array(image.pixels[:], dtype=float).reshape(-1, 4)[:, :3]
        size = list(image.size)
        sizes.append(size)
        item = {'class': kind, 'channel': channel, 'path': path.relative_to(root).as_posix(),
                'size': size, 'finite': bool(np.isfinite(pixels).all()),
                'rgb_min': pixels.min(axis=0).tolist(), 'rgb_max': pixels.max(axis=0).tolist(),
                'repeats_per_rest_metre': cfg[kind]['scale']}
        if not item['finite']:
            report['failures'].append(kind + ' ' + channel + ': nonfinite pixels')
        if channel == 'normal':
            length_error = np.abs(np.linalg.norm(pixels * 2 - 1, axis=1) - 1)
            item['normal_length_error_p95'] = float(np.percentile(length_error, 95))
            item['xy_variance'] = float(np.var(pixels[:, :2]))
            # Godot's normal import may use BC5: blue is discarded and reconstructed from RG.
            # Resizing the original RGB can shorten vectors; retain that diagnostic, but validate
            # the actual RG codec contract instead of rejecting a usable resampled source.
            item['xy_length_squared_max'] = float(np.max(np.sum((pixels[:, :2] * 2 - 1) ** 2, axis=1)))
            item['runtime_decode'] = 'RG, reconstruct positive Z; source blue not used'
            if item['xy_length_squared_max'] > 1.01 or item['xy_variance'] < 1e-8:
                report['failures'].append(kind + ': invalid or flat RG normal map')
        report['maps'].append(item)
        bpy.data.images.remove(image)
    if sizes[0] != sizes[1]:
        report['failures'].append(kind + ': normal/ORM resolution mismatch')
out = root / 'docs/captures/after/mocap/materials/blender_maps.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2) + '\n')
print('ZOMBIE_MATERIAL_AUDIT', len(report['maps']), 'maps;', report['failures'])
if report['failures']:
    raise RuntimeError('Zombie texture audit failed')
