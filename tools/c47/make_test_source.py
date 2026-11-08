"""T-211: a stand-in "downloaded" C-47 to prove the import path (tools/c47/build_c47.py --source=...) without the real
file: our intact stand-in's airframe (no cabin, no props as separate nodes), turned nose +X, Z-up, in centimetres, as
a Sketchfab export might come. Headless Blender:

    tools/c47/blender.sh -P tools/c47/make_test_source.py -- <out.glb>
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "ours", "world", "c47_intact", "model.glb"))
for o in list(bpy.data.objects):
    if o.type != "MESH" or not o.name.endswith("_LOD0") or o.name.startswith("Interior"):
        bpy.data.objects.remove(o, do_unlink=True)
root = bpy.data.objects.new("SketchfabRoot", None)
bpy.context.scene.collection.objects.link(root)
for o in list(bpy.data.objects):
    if o is not root:
        o.parent = root
root.rotation_euler = (0.0, 0.0, math.radians(-90.0))   # the nose along +X
root.scale = (100.0, 100.0, 100.0)                       # centimetres
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True)
print("[c47] test source ->", out)
