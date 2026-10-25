"""Blender (headless) decimate for a prop GLB (UPDATE_05 section 1, T-088; docs/ART_BIBLE.md section 5).

    blender -b -P tools_src/blender/decimate_gltf.py -- <in.glb> <out_dir> <target_tris>

Imports the GLB, collapses every mesh with a Decimate modifier so the whole prop lands at about target_tris
(UVs kept, so the photogrammetry textures still fit; normals recomputed), then exports a *separate* glTF
(out_dir/model.gltf + model.bin + the images) which tools/decimate_props.py packs back into model.glb with
external PNG textures. Nothing else about the file changes: units, +Y up, origin, material slots.
"""
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) < 3:
    print("usage: blender -b -P decimate_gltf.py -- in.glb out_dir target_tris")
    sys.exit(2)
src, out_dir, target = argv[0], argv[1], int(argv[2])
os.makedirs(out_dir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
total = 0
for o in meshes:
    o.data.calc_loop_triangles()
    total += len(o.data.loop_triangles)
ratio = 1.0 if total <= target else max(0.01, float(target) / float(total))
print("[decimate] %s: %d tris -> target %d (ratio %.3f) over %d meshes" % (os.path.basename(src), total, target, ratio, len(meshes)))

if ratio < 1.0:
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new(name="Decimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.data.calc_loop_triangles()

after = sum(len(o.data.loop_triangles) for o in meshes)
print("[decimate] now %d tris" % after)

bpy.ops.export_scene.gltf(
    filepath=os.path.join(out_dir, "model.gltf"),
    export_format="GLTF_SEPARATE",
    export_texture_dir="textures",
    export_image_format="AUTO",
    export_apply=True,
    export_yup=True,
    export_animations=False,
    export_skins=False,
    export_morph=False,
    export_cameras=False,
    export_lights=False,
    export_extras=False,
)
print("[decimate] wrote %s" % os.path.join(out_dir, "model.gltf"))
