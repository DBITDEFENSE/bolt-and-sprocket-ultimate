"""Quick headless previews of a character (Workbench, no GPU window): front, side, three-quarter and a face
close-up into one PNG per view, for checking shapes while iterating on make_body / make_kits (T-091)."""
import math
import os

import bpy
import numpy as np

import common as C


def _cam(name, loc_g, target_g, ortho=None, lens=50.0):
    cam = bpy.data.cameras.new(name)
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    else:
        cam.lens = lens
    ob = bpy.data.objects.new(name, cam)
    C.link(ob)
    loc = C.g2b(np.array(loc_g))
    tgt = C.g2b(np.array(target_g))
    ob.location = tuple(loc)
    d = tgt - loc
    rot = d / np.linalg.norm(d)
    # track: point -Z of the camera at the target, +Y up
    from mathutils import Vector
    ob.rotation_euler = Vector(tuple(rot)).to_track_quat("-Z", "Y").to_euler()
    return ob


def render(out_dir, tag, objs, views=("front", "side", "threeq", "face", "back"), colour_by="single"):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = {"vcol": "VERTEX", "material": "MATERIAL"}.get(colour_by, "SINGLE")
    sc.display.shading.single_color = (0.62, 0.6, 0.58)
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "BOTH"
    sc.display.shading.show_shadows = False
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (0.18, 0.18, 0.2)
    sc.render.resolution_x = 900
    sc.render.resolution_y = 1100
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w") if bpy.context.scene.world is None else bpy.context.scene.world
    sc.world = world
    hide = [o for o in bpy.data.objects if o.type == "MESH" and o not in objs]
    for o in hide:
        o.hide_render = True
    setups = {
        "front": ((0, 1.0, -4.0), (0, 0.95, 0), 2.1),
        "back": ((0, 1.0, 4.0), (0, 0.95, 0), 2.1),
        "side": ((4.0, 1.0, 0), (0, 0.95, 0), 2.1),
        "threeq": ((-2.6, 1.3, -3.0), (0, 0.95, 0), 2.1),
        "face": ((0.12, 1.72, -0.75), (0, 1.69, 0), None),
    }
    paths = []
    for v in views:
        loc, tgt, ortho = setups[v]
        cam = _cam("cam_" + v, loc, tgt, ortho, lens=60.0)
        sc.camera = cam
        if v == "face":
            sc.render.resolution_x, sc.render.resolution_y = 900, 900
        else:
            sc.render.resolution_x, sc.render.resolution_y = 700, 1000
        p = os.path.join(out_dir, "%s_%s.png" % (tag, v))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    for o in hide:
        o.hide_render = False
    print("[preview] " + ", ".join(paths))
    return paths
