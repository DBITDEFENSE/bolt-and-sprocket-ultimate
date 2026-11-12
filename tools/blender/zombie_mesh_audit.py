"""Blender --background --factory-startup --python this.py -- --root <checkout> --out <json>.
Read-only import/geometry audit of the six existing zombie bodies. Never exports or sculpts.
"""
import argparse
import json
from pathlib import Path
import sys
import bpy

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
report = {'blender': bpy.app.version_string, 'models': [], 'errors': [], 'uv_findings': []}
paths = sorted((args.root / 'assets/ours/characters/zombie_base').glob('*.glb'))
if not paths:
    raise RuntimeError('No zombie GLBs found')
for path in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    row = {'file': path.name, 'skeletons': [], 'meshes': []}
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            row['skeletons'].append({'name': obj.name, 'bones': [b.name for b in obj.data.bones]})
        elif obj.type == 'MESH' and any(m.type == 'ARMATURE' for m in obj.modifiers):
            mesh = obj.data
            mesh.calc_loop_triangles()
            unweighted = sum(not any(g.weight > 0 for g in v.groups) for v in mesh.vertices)
            row['meshes'].append({'name': obj.name, 'vertices': len(mesh.vertices),
                'triangles': len(mesh.loop_triangles), 'uv_layers': len(mesh.uv_layers),
                'unweighted_vertices': unweighted,
                'degenerate_triangles': sum(t.area < 1e-12 for t in mesh.loop_triangles)})
            if unweighted:
                report['errors'].append(f'{path.name}/{obj.name}: unweighted={unweighted}')
            if not mesh.uv_layers:
                report['uv_findings'].append(f'{path.name}/{obj.name}: no UVs; verify shader coordinates before atlas migration')
    report['models'].append(row)
args.out.parent.mkdir(parents=True, exist_ok=True)
args.out.write_text(json.dumps(report, indent=2), encoding='utf-8')
print('ZOMBIE_MESH_AUDIT', len(paths), 'models;', len(report['errors']), 'weight errors;', len(report['uv_findings']), 'UV findings')
if report['errors']:
    raise RuntimeError('Mesh audit failed; see report')
