"""First-person arms for GRAVELIGHT (UPDATE_05 section 2 "Arms", T-089): one GLB per character with hands,
a forearm (cuff + sleeve) and a sleeve tube, sculpted here from data so they can be regenerated.

    blender -b -P tools_src/blender/arms/make_arms.py -- --out assets/ours/arms [--char dutch] [--calib]

Frames match gravelight/weapons/weapon_models.gd (the procedural arms these replace), so WeaponHolder's two-bone
IK, sway and reload choreography are untouched:
  hand     origin = centre of the gripped part, grip axis = +Y (index finger at the top), palm on +X for the right
           hand (-X for the left), fingers wrap around the front (-Z), the thumb around the back (+Z). The wrist
           is at WeaponModels.hand_wrist(). One mesh per side x pose x grip radius:
             HandR_fist_s|m|l, HandR_trigger_s|m|l (index finger straight on the trigger),
             HandL_fist_s|m|l, HandL_open_s|m|l (a looser cup for a handguard); s/m/l = 14 / 19 / 27 mm radius.
  forearm  origin = wrist, +Y up the forearm: the glove gauntlet / bare wrist, the sleeve cuff, 0.14 m of sleeve.
  sleeve   a unit tube (height 1 along Y, centred) WeaponHolder stretches between wrist, elbow and shoulder.
Blender is Z-up; the glTF exporter maps Blender (x, y, z) to glTF (x, z, -y), so every Godot-frame point
(gx, gy, gz) is placed at Blender (gx, -gz, gy) by B().

Hands are metaballs (palm slab, finger segments, thumb, wrist stub) converted to a mesh, decimated and smoothed;
faces take the material of the nearest tagged ball (glove, palm, skin, strap), so fingerless gloves and bare
hands come from the same sculpt. Every mesh is ours (LICENSE.txt / SOURCE.txt next to the GLBs).
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

# ---------------------------------------------------------------- the characters (docs/gravelight/CHARACTERS.md)
CHARACTERS = {
    "dutch": {   # US Ranger: brown leather gloves, OD field jacket
        "glove": "leather", "glove_col": (0.19, 0.13, 0.085), "palm_col": (0.16, 0.11, 0.07),
        "strap_col": (0.11, 0.072, 0.045), "skin_col": (0.62, 0.47, 0.38),
        "cuff": "gauntlet", "cuff_col": (0.17, 0.12, 0.08), "sleeve_col": (0.3, 0.31, 0.2), "sleeve_rough": 0.95},
    "peg": {     # SOE: brown gloves, Denison smock cuffs with a knitted wrist
        "glove": "leather", "glove_col": (0.3, 0.19, 0.11), "palm_col": (0.26, 0.16, 0.09),
        "strap_col": (0.2, 0.12, 0.07), "skin_col": (0.78, 0.6, 0.5),
        "cuff": "smock", "cuff_col": (0.25, 0.2, 0.12), "sleeve_col": (0.4, 0.34, 0.2), "sleeve_rough": 0.95},
    "deacon": {  # 761st tanker: bare hands, HBT coverall sleeves
        "glove": "bare", "glove_col": (0.36, 0.22, 0.14), "palm_col": (0.5, 0.34, 0.25),
        "strap_col": (0.3, 0.3, 0.28), "skin_col": (0.36, 0.22, 0.14),
        "cuff": "coverall", "cuff_col": (0.28, 0.29, 0.2), "sleeve_col": (0.31, 0.32, 0.22), "sleeve_rough": 0.95},
    "wren": {    # AK guide: fingerless wool gloves, grey wool sweater
        "glove": "fingerless", "glove_col": (0.2, 0.18, 0.16), "palm_col": (0.17, 0.15, 0.13),
        "strap_col": (0.14, 0.12, 0.1), "skin_col": (0.78, 0.6, 0.5),
        "cuff": "sweater", "cuff_col": (0.2, 0.19, 0.18), "sleeve_col": (0.24, 0.23, 0.22), "sleeve_rough": 1.0},
    "bolt": {    # mechanic: synthetic work gloves (tan palms), blue coverall
        "glove": "mechanic", "glove_col": (0.13, 0.13, 0.14), "palm_col": (0.55, 0.42, 0.26),
        "strap_col": (0.8, 0.45, 0.12), "skin_col": (0.7, 0.52, 0.4),
        "cuff": "mechanic", "cuff_col": (0.14, 0.2, 0.36), "sleeve_col": (0.15, 0.22, 0.4), "sleeve_rough": 0.9},
    "vendelin": {  # V-1: brass hands, dark wool coat
        "glove": "brass", "glove_col": (0.78, 0.6, 0.25), "palm_col": (0.62, 0.46, 0.2),
        "strap_col": (0.5, 0.36, 0.17), "skin_col": (0.78, 0.6, 0.25),
        "cuff": "coat", "cuff_col": (0.12, 0.11, 0.12), "sleeve_col": (0.14, 0.13, 0.14), "sleeve_rough": 0.9},
}
RADII = {"s": 0.014, "m": 0.019, "l": 0.027}
# Godot's hand_mesh: how much smaller the visible metaball surface is than the ball radius (calibrated: --calib)
SURF = 0.5


def B(gx, gy, gz):
    """Godot-frame point -> Blender coordinates (Y-up glTF export)."""
    return Vector((gx, -gz, gy))


def hp(theta_deg, radius, y, side):
    t = math.radians(theta_deg)
    return (side * radius * math.cos(t), y, radius * math.sin(t))


def hand_wrist(left, r):
    s = -1.0 if left else 1.0
    p = hp(62.0, r + 0.02, -0.03, s)
    return (p[0], p[1], p[2] + 0.035)


# ---------------------------------------------------------------- materials
_mats = {}


def material(name, col, rough=0.75, metal=0.0):
    key = (name, col, rough, metal)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    _mats[key] = m
    return m


# ---------------------------------------------------------------- hand sculpt
class Sculpt:
    def __init__(self):
        self.balls = []   # (godot point, radius, tag)

    def ball(self, p, r, tag):
        self.balls.append((p, r, tag))

    def seg(self, a, b, ra, rb, tag, step=0.004):
        n = max(1, int(math.dist(a, b) / step))
        for i in range(n + 1):
            t = i / n
            p = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
            self.ball(p, ra + (rb - ra) * t, tag)


def sculpt_hand(left, r, pose):
    """The procedural hand (WeaponModels.hand_mesh) as balls: palm slab, fingers, thumb, wrist. pose: fist |
    trigger (index finger straight ahead) | open (fingers half-curled)."""
    s = -1.0 if left else 1.0
    sc = Sculpt()
    rp = r + 0.011
    palm_ang = 35.0
    knuckle_ang = palm_ang - math.degrees(0.03 / rp)
    fy = [0.029, 0.0095, -0.0095, -0.028]
    # palm slab: balls in the middle of the shell (r + 0.0018 .. r + 0.0215) over the knuckle -> wrist arc
    t0 = knuckle_ang - 7.0
    t1 = palm_ang + 42.0
    for i in range(7):
        th = t0 + (t1 - t0) * i / 6.0
        for j in range(6):
            y = -0.041 + (0.038 + 0.041) * j / 5.0
            # the slab is thinner at the knuckle edge, fuller toward the heel; knuckle bumps on the back
            rad_mid = r + 0.0112
            rb = 0.0115 if i > 0 else 0.0105
            sc.ball(hp(th, rad_mid, y, s), rb, "palm" if th > palm_ang + 8 else "back")
    for f in range(4):   # knuckle bumps
        sc.ball(hp(knuckle_ang + 3.0, r + 0.0205, fy[f], s), 0.0068, "back")
    # heel of the palm
    sc.seg(hp(palm_ang + 30.0, rp, 0.02, s), hp(palm_ang + 25.0, rp, -0.03, s), 0.0125, 0.0115, "palm")
    # fingers: three tapered segments each, wrapping around the front
    lens = [0.025, 0.018, 0.015]
    fk = [0.97, 1.05, 0.98, 0.8]
    for f in range(4):
        fr = 0.0089 if f < 3 else 0.0077
        rad = r + fr + 0.001
        ang = knuckle_ang
        p0 = hp(ang, rad, fy[f], s)
        r_a = fr
        tag_base = "finger"
        if pose == "trigger" and f == 0:
            # index finger straight ahead on the trigger: knuckle -> forward (-Z), a slight curl at the tip
            d = -0.0
            tip = (p0[0] - s * 0.004, p0[1] - 0.004, p0[2] - 0.062)
            mid = (p0[0] - s * 0.001, p0[1] - 0.001, p0[2] - 0.03)
            sc.seg(p0, mid, fr, fr * 0.92, "finger")
            sc.seg(mid, tip, fr * 0.92, fr * 0.78, "fingertip")
            continue
        curl = 1.0 if pose != "open" else 0.62
        for k in range(3):
            l = lens[k] * fk[f]
            ang -= math.degrees(l / rad) * (1.0 if k < 2 else 0.9) * curl
            p1 = hp(ang, rad - 0.0015 * k, fy[f] - 0.002 * k, s)
            if pose == "open":
                # an open hand carries the fingers out from the grip a little
                p1 = (p1[0] * 1.0, p1[1], p1[2] - 0.004 * k)
            r_b = fr * (0.93 - 0.06 * k)
            sc.seg(p0, p1, r_a + 0.0004, r_b, "finger" if k < 2 else "fingertip")
            p0 = p1
            r_a = r_b
    # thumb: from inside the palm around the back of the grip
    t_0 = hp(palm_ang + 5.0, rp - 0.004, -0.01, s)
    t_1 = hp(palm_ang + 55.0, r + 0.012, 0.03, s)
    sc.seg(t_0, t_1, 0.0118, 0.0102, "palm")
    tr = r + 0.0095
    a1 = palm_ang + 55.0 + math.degrees(0.028 / tr)
    t_2 = hp(min(a1, 175.0), tr, 0.04, s)
    sc.seg(t_1, t_2, 0.0098, 0.009, "finger")
    t_3 = hp(min(a1 + math.degrees(0.022 / tr), 205.0), tr - 0.001, 0.043, s)
    sc.seg(t_2, t_3, 0.0088, 0.008, "fingertip")
    # wrist stub to the forearm
    w0 = hp(palm_ang + 15.0, rp, -0.012, s)
    w1 = hand_wrist(left, r)
    sc.seg(w0, w1, 0.0168, 0.0165, "wrist")
    return sc


def build_hand(name, left, r, pose, cfg, resolution=0.0024, target_tris=2600):
    sc = sculpt_hand(left, r, pose)
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    for p, rad, tag in sc.balls:
        el = mb.elements.new()
        el.type = "BALL"
        el.co = B(*p)
        el.radius = rad / SURF
        el.stiffness = 2.0
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    me = ob.data
    me.name = name
    # decimate to a viewmodel budget, smooth
    if len(me.polygons) > target_tris:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.ratio = target_tris / len(me.polygons)
        bpy.ops.object.modifier_apply(modifier="dec")
        me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    # materials by the nearest tagged ball
    glove = cfg["glove"]
    mats = {
        "glove": material("glove", cfg["glove_col"], 0.7 if glove in ("leather", "brass") else 0.9, 1.0 if glove == "brass" else 0.0),
        "palm": material("palm", cfg["palm_col"], 0.75, 1.0 if glove == "brass" else 0.0),
        "skin": material("skin", cfg["skin_col"], 0.62, 1.0 if glove == "brass" else 0.0),
        "strap": material("strap", cfg["strap_col"], 0.6, 0.0),
    }
    order = ["glove", "palm", "skin", "strap"]
    for k in order:
        me.materials.append(mats[k])
    centres = [(B(*p), tag) for p, rad, tag in sc.balls]
    wrist_b = B(*hand_wrist(left, r))
    for poly in me.polygons:
        c = poly.center
        best = None
        best_d = 1e9
        for pb, tag in centres:
            d = (pb - c).length_squared
            if d < best_d:
                best_d = d
                best = tag
        tag = best
        if glove == "bare":
            slot = "skin" if tag != "wrist" else "skin"
        elif glove == "fingerless":
            slot = "skin" if tag == "fingertip" else ("palm" if tag == "palm" else "glove")
        elif glove == "mechanic":
            slot = "palm" if tag in ("palm",) else "glove"
        elif glove == "brass":
            slot = "glove" if tag in ("back", "finger", "fingertip", "wrist") else "palm"
        else:
            slot = "palm" if tag == "palm" else "glove"
        # a strap round the wrist on gloves (not bare hands): the band just above the wrist stub
        if glove in ("leather", "mechanic") and (c - wrist_b).length < 0.011:
            slot = "strap"
        poly.material_index = order.index(slot)
    return ob


# ---------------------------------------------------------------- forearm and sleeve
def tube(bm, r0, r1, z0, z1, segs=16):
    """A cone frustum along Blender +Z (glTF +Y) from z0 (radius r0) to z1 (radius r1)."""
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r0, radius2=r1, depth=z1 - z0)
    for v in res["verts"]:
        v.co.z += (z0 + z1) * 0.5
    return res["verts"]


def torus(bm, major, minor, z, segs=16, rings=8):
    verts = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for j in range(rings):
            b = 2 * math.pi * j / rings
            x = (major + minor * math.cos(b)) * math.cos(a)
            y = (major + minor * math.cos(b)) * math.sin(a)
            ring.append(bm.verts.new((x, y, z + minor * math.sin(b))))
        verts.append(ring)
    for i in range(segs):
        for j in range(rings):
            a0 = verts[i][j]
            a1 = verts[i][(j + 1) % rings]
            b0 = verts[(i + 1) % segs][j]
            b1 = verts[(i + 1) % segs][(j + 1) % rings]
            bm.faces.new((a0, b0, b1, a1))


def build_forearm(name, cfg):
    """Origin = wrist, +Y (Blender +Z) up the forearm: the wrist piece, the sleeve cuff and 0.14 m of sleeve."""
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    glove = cfg["glove"]
    cuff = cfg["cuff"]
    FOREARM_BARE = 0.14
    mat_wrist = material("glove", cfg["glove_col"], 0.7 if glove in ("leather", "brass") else 0.9, 1.0 if glove == "brass" else 0.0)
    if glove == "bare":
        mat_wrist = material("skin", cfg["skin_col"], 0.62)
    mat_cuff = material("cuff", cfg["cuff_col"], 0.9)
    mat_sleeve = material("sleeve", cfg["sleeve_col"], cfg["sleeve_rough"])
    mat_button = material("button", (0.55, 0.42, 0.2) if cuff == "coat" else (0.25, 0.22, 0.18), 0.4, 0.8 if cuff == "coat" else 0.0)
    me.materials.append(mat_wrist)
    me.materials.append(mat_cuff)
    me.materials.append(mat_sleeve)
    me.materials.append(mat_button)
    pieces = []   # (first face, last face, material index)

    def piece(mi, fn):
        f0 = len(bm.faces)
        fn()
        pieces.append((f0, len(bm.faces), mi))

    def ball(r, at):
        res = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=r)
        for v in res["verts"]:
            v.co += Vector(at)

    # the wrist: a glove gauntlet (leather / brass), a knit wrist (mechanic / fingerless), or bare skin
    if glove in ("leather", "brass"):
        piece(0, lambda: tube(bm, 0.0205, 0.025, -0.009, 0.041))
        piece(0, lambda: torus(bm, 0.0258, 0.0037, 0.038))
    elif glove in ("mechanic", "fingerless"):
        piece(0, lambda: tube(bm, 0.0195, 0.022, -0.009, 0.03))
        for z in (0.012, 0.02, 0.028):   # knit ribs
            piece(0, lambda z=z: torus(bm, 0.0215, 0.0016, z, 16, 6))
    else:   # bare wrist, the forearm skin up to the rolled sleeve
        piece(0, lambda: tube(bm, 0.019, 0.0235, -0.009, 0.06))
    # the cuff where the sleeve meets the wrist
    if cuff == "gauntlet":
        piece(2, lambda: tube(bm, 0.0265, 0.0372, 0.03, FOREARM_BARE))
        piece(1, lambda: torus(bm, 0.0288, 0.0048, 0.05))
    elif cuff == "smock":
        # Denison smock: a knitted wrist band then the loose smock sleeve
        piece(1, lambda: tube(bm, 0.0245, 0.0265, 0.028, 0.058))
        for z in (0.034, 0.042, 0.05):
            piece(1, lambda z=z: torus(bm, 0.0262, 0.0016, z, 16, 6))
        piece(2, lambda: tube(bm, 0.03, 0.04, 0.056, FOREARM_BARE))
    elif cuff == "coverall":
        # HBT coverall: a rolled double cuff, one button
        piece(2, lambda: tube(bm, 0.028, 0.036, 0.056, FOREARM_BARE))
        piece(1, lambda: torus(bm, 0.0305, 0.0062, 0.062))
        piece(3, lambda: ball(0.0045, (0.0, -0.028, 0.072)))
    elif cuff == "sweater":
        # ribbed wool: a tight cuff of rings then the sleeve
        piece(1, lambda: tube(bm, 0.0235, 0.0265, 0.028, 0.07))
        for i in range(6):
            piece(1, lambda i=i: torus(bm, 0.0255 + i * 0.0004, 0.0018, 0.033 + i * 0.0065, 16, 6))
        piece(2, lambda: tube(bm, 0.029, 0.038, 0.068, FOREARM_BARE))
    elif cuff == "mechanic":
        # blue coverall sleeve with an elastic cuff over the glove's knit wrist
        piece(1, lambda: tube(bm, 0.0255, 0.029, 0.03, 0.05))
        piece(2, lambda: tube(bm, 0.03, 0.039, 0.05, FOREARM_BARE))
    else:   # coat: a heavy wool cuff with a brass button, then the coat sleeve
        piece(1, lambda: tube(bm, 0.027, 0.03, 0.03, 0.075))
        piece(2, lambda: tube(bm, 0.031, 0.04, 0.073, FOREARM_BARE))
        piece(3, lambda: ball(0.004, (0.0, -0.03, 0.062)))
    bm.to_mesh(me)
    bm.free()
    for f0, f1, mi in pieces:
        for k in range(f0, f1):
            me.polygons[k].material_index = mi
    for poly in me.polygons:
        poly.use_smooth = True
    return ob


def build_sleeve(name, cfg):
    """A unit sleeve tube (height 1 along +Y, centred) with soft folds; WeaponHolder scales it to each limb."""
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    segs = 14
    rows = 9
    rings = []
    for j in range(rows + 1):
        z = -0.5 + j / rows
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            # folds: a few soft bulges round the tube, stronger toward the elbow end
            fold = 1.0 + 0.045 * math.sin(a * 3.0 + j * 1.7) * (0.4 + 0.6 * abs(z + 0.5))
            r = 0.04 * fold
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for j in range(rows):
        for i in range(segs):
            bm.faces.new((rings[j][i], rings[j + 1][i], rings[j + 1][(i + 1) % segs], rings[j][(i + 1) % segs]))
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material("sleeve", cfg["sleeve_col"], cfg["sleeve_rough"]))
    for poly in me.polygons:
        poly.use_smooth = True
    return ob


# ---------------------------------------------------------------- main
def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_normals=True, export_texcoords=False,
                              export_animations=False, export_skins=False)


def calibrate():
    """Prints the visible radius of one ball of radius 0.01 (sets SURF)."""
    mb = bpy.data.metaballs.new("c")
    mb.resolution = 0.001
    mb.threshold = 0.6
    ob = bpy.data.objects.new("c", mb)
    bpy.context.scene.collection.objects.link(ob)
    el = mb.elements.new()
    el.type = "BALL"
    el.radius = 0.01
    el.stiffness = 2.0
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    xs = [v.co.x for v in ob.data.vertices]
    print("[make_arms] calib: ball radius 0.01 -> visible %.4f (SURF %.3f)" % (max(xs), max(xs) / 0.01))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--char", default="")
    ap.add_argument("--calib", action="store_true")
    args = ap.parse_args(argv)
    if args.calib:
        clear_scene()
        calibrate()
        return
    chars = [args.char] if args.char else list(CHARACTERS.keys())
    for ch in chars:
        cfg = CHARACTERS[ch]
        clear_scene()
        tris = 0
        for left in (False, True):
            poses = ("fist", "open") if left else ("fist", "trigger")
            for pose in poses:
                for key, r in RADII.items():
                    ob = build_hand("Hand%s_%s_%s" % ("L" if left else "R", pose, key), left, r, pose, cfg)
                    tris += len(ob.data.polygons)
        build_forearm("Forearm", cfg)
        build_sleeve("Sleeve", cfg)
        path = os.path.join(args.out, ch + ".glb")
        export(path)
        print("[make_arms] %s: %d hand faces, wrote %s" % (ch, tris, path))


if __name__ == "__main__":
    main()
