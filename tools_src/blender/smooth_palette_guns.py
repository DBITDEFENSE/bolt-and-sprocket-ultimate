"""Smooth-shade the OpenGameArt "Ultimate Low Poly Guns" models (2026-11-12, the owner: the M1911 and MP40 looked like
"missing textures").

The pack ships every gun flat-shaded: each triangle has its own normal, so curved parts (grips, barrels, drums,
slides' rounded tops) render as facets, and the weapon shader's edge wear (which keys off the normal's screen
derivative) lit every one of those facets as bright steel. This keeps the geometry and the part nodes exactly
(names, origins, transforms: the holder animates Slide / Mag / Bolt ... by name) and only:
  1. welds the vertices the flat export split (UVs are per loop, so the palette mapping survives),
  2. shades smooth with sharp edges from the angle (real corners stay crisp: 35 degrees),
  3. adds a narrow angle-limited bevel with hardened normals, so the corners catch a highlight line,
  4. weights the normals by face area (flat sides stay flat next to the bevels).
The palette texture keeps its external file (the exporter embeds it; the JSON is pointed back at the PNG after).

Usage: blender -b --factory-startup -P tools_src/blender/smooth_palette_guns.py -- <in.glb> <out.glb> [bevel_m] [segments]
"""
import math
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
bevel_w = float(argv[2]) if len(argv) > 2 else 0.0007
segments = int(argv[3]) if len(argv) > 3 else 1   # one segment: the highlight line at about half the triangles of two

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

before = after = 0
for ob in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    me = ob.data
    before += sum(len(p.vertices) - 2 for p in me.polygons)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(35.0))
    # the bevel's width is in the object's own units; the pack's guns are near real size (scale ~1)
    s = max(ob.matrix_world.to_scale())
    bev = ob.modifiers.new("Bevel", "BEVEL")
    bev.width = bevel_w / max(s, 1e-6)
    bev.segments = segments
    bev.limit_method = "ANGLE"
    bev.angle_limit = math.radians(40.0)
    bev.harden_normals = True
    bev.use_clamp_overlap = True
    wn = ob.modifiers.new("Weighted", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.weight = 50
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    after += sum(len(p.vertices) - 2 for p in ob.data.polygons)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_apply=False,
                          export_normals=True, export_texcoords=True, export_materials="EXPORT",
                          export_image_format="AUTO", export_animations=False)
print(f"SMOOTH_GUN {src} -> {dst} tris {before} -> {after}")
