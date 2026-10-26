"""The shared skin texture set of the GRAVELIGHT bodies (T-091): albedo, normal, ORM on the canonical body's UVs
(every body copies or transfers that layout, build_all.py), painted procedurally and baked with Cycles (CPU).

    blender -b --factory-startup -P tools_src/blender/characters/make_textures.py -- [--living] [--size=1024]

Zombie set (assets/ours/characters/zombie_base/tex_zombie_skin_*.png):
- albedo around linear 0.5 (the infection shader multiplies it by 2 x the kit's skin tone): pale mottled skin,
  blue-violet veins thickest at the neck, temples, forearms and hands, frostbite at the fingers, toes, nose, ears,
  lips and cheeks, bruised sunken sockets, lividity pooled in the feet and the backs of the legs; alpha = where the
  Nachtglas starts (eyes, mouth, hands), which the shader reads to open the cracks there first;
- normal (OpenGL +Y, tangent space): raised veins, wrinkles, pores, the ribs on thin builds' canonical torso;
- ORM: baked ambient occlusion, roughness (frostbitten / wet patches glossier), metallic 0.
Living set (human_base/tex_human_skin_*.png, ``--living``): warm even skin, faint veins only at the wrists and
temples, no frostbite, rosy lips and cheeks, no lividity; alpha 0.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common as C  # noqa: E402
import make_body as MB  # noqa: E402


def masks(P, B):
    """Per-vertex masks (Godot frame, rest): frost, origin, socket, lividity, vein density."""
    v = B.v
    n = len(v)
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    reg = B.region
    dom = MB.dominant_bone(B.bi, B.bw)
    names = np.array(MB.RIG.bones)[dom]
    hl = v - MB.HEAD_C
    head = reg == 1
    hands = reg == 2
    wrist_y = MB.RIG.head["LeftHand"][1]
    frost = np.zeros(n)
    origin = np.zeros(n)
    socket = np.zeros(n)
    livid = np.zeros(n)
    veins = np.full(n, 0.12)
    # fingers and toes
    frost += hands * C.smoothstep(wrist_y - 0.06, wrist_y - 0.15, y)
    feet = np.char.endswith(names.astype(str), "Foot")
    frost += feet * C.smoothstep(-0.07, -0.15, z)
    # face extremities
    fr = head & (hl[:, 2] < -0.03)
    frost += fr * 0.9 * C.gauss(hl[:, 0] ** 2 + (hl[:, 1] + 0.03) ** 2, 0.016)          # nose
    frost += head * 0.8 * C.smoothstep(0.075, 0.09, np.abs(hl[:, 0])) * C.smoothstep(0.04, 0.0, np.abs(hl[:, 1]))   # ears
    frost += fr * 0.7 * C.gauss(hl[:, 0] ** 2 / 2.0 + (hl[:, 1] + 0.061) ** 2, 0.012)   # lips
    for sx in (-1.0, 1.0):
        frost += fr * 0.35 * C.gauss((hl[:, 0] - sx * 0.05) ** 2 + (hl[:, 1] + 0.02) ** 2, 0.02)   # cheeks
        socket += fr * C.gauss(((hl[:, 0] - sx * 0.031) / 1.2) ** 2 + (hl[:, 1] - 0.008) ** 2, 0.026)
        origin += fr * C.gauss((hl[:, 0] - sx * 0.031) ** 2 + (hl[:, 1] - 0.01) ** 2, 0.04)
    origin += fr * C.gauss(hl[:, 0] ** 2 + (hl[:, 1] + 0.06) ** 2, 0.03)
    origin += hands * 0.9 + (~hands) * C.smoothstep(wrist_y + 0.15, wrist_y, y) * (np.abs(x) > 0.15) * 0.6
    # lividity: blood pooled low and at the back of the legs
    livid += (reg == 0) * C.smoothstep(0.5, 0.05, y) * (0.5 + 0.5 * C.smoothstep(-0.02, 0.05, z))
    # veins: neck, temples, forearms, hands, chest
    veins += np.isin(names, ["Neck"]) * 0.5
    veins += head * C.smoothstep(0.05, 0.075, np.abs(hl[:, 0])) * C.smoothstep(-0.01, 0.04, hl[:, 1]) * 0.6
    veins += np.isin(names, ["LeftLowerArm", "RightLowerArm"]) * 0.5 + hands * 0.4
    veins += np.isin(names, ["Chest"]) * 0.15
    clip = lambda a: np.clip(a, 0.0, 1.0)
    return clip(frost), clip(origin), clip(socket), clip(livid), clip(veins)


def node(nt, kind, loc=(0, 0), **kw):
    nd = nt.nodes.new(kind)
    nd.location = loc
    for k, val in kw.items():
        setattr(nd, k, val)
    return nd


def build_material(living):
    mat = bpy.data.materials.new("bake")
    mat.use_nodes = True
    nt = mat.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = node(nt, "ShaderNodeOutputMaterial", (1400, 0))
    tex = node(nt, "ShaderNodeTexCoord", (-1400, 0))
    mask_a = node(nt, "ShaderNodeAttribute", (-1400, -400), attribute_name="MaskA")
    mask_b = node(nt, "ShaderNodeAttribute", (-1400, -600), attribute_name="MaskB")
    sep_a = node(nt, "ShaderNodeSeparateColor", (-1200, -400))
    sep_b = node(nt, "ShaderNodeSeparateColor", (-1200, -600))
    nt.links.new(mask_a.outputs["Color"], sep_a.inputs[0])
    nt.links.new(mask_b.outputs["Color"], sep_b.inputs[0])
    frost, origin, socket = sep_a.outputs[0], sep_a.outputs[1], sep_a.outputs[2]
    livid, veinden = sep_b.outputs[0], sep_b.outputs[1]
    # mottling
    mot = node(nt, "ShaderNodeTexNoise", (-1100, 300))
    mot.inputs["Scale"].default_value = 9.0
    mot.inputs["Detail"].default_value = 6.0
    nt.links.new(tex.outputs["Object"], mot.inputs["Vector"])
    fine = node(nt, "ShaderNodeTexNoise", (-1100, 100))
    fine.inputs["Scale"].default_value = 90.0
    fine.inputs["Detail"].default_value = 2.0
    nt.links.new(tex.outputs["Object"], fine.inputs["Vector"])
    # veins: voronoi distance-to-edge, warped
    warp = node(nt, "ShaderNodeTexNoise", (-1300, 600))
    warp.inputs["Scale"].default_value = 6.0
    warp_mix = node(nt, "ShaderNodeVectorMath", (-1100, 600), operation="MULTIPLY_ADD")
    warp_mix.inputs[1].default_value = (0.04, 0.04, 0.04)
    nt.links.new(warp.outputs["Color"], warp_mix.inputs[0])
    nt.links.new(tex.outputs["Object"], warp_mix.inputs[2])
    vor = node(nt, "ShaderNodeTexVoronoi", (-900, 600), feature="DISTANCE_TO_EDGE")
    vor.inputs["Scale"].default_value = 11.0
    nt.links.new(warp_mix.outputs[0], vor.inputs["Vector"])
    vein_line = node(nt, "ShaderNodeMapRange", (-700, 600))
    vein_line.inputs["From Min"].default_value = 0.0
    vein_line.inputs["From Max"].default_value = 0.022
    vein_line.inputs["To Min"].default_value = 1.0
    vein_line.inputs["To Max"].default_value = 0.0
    nt.links.new(vor.outputs["Distance"], vein_line.inputs["Value"])
    vein_amt = node(nt, "ShaderNodeMath", (-500, 600), operation="MULTIPLY")
    nt.links.new(vein_line.outputs[0], vein_amt.inputs[0])
    nt.links.new(veinden, vein_amt.inputs[1])
    if living:
        vein_amt2 = node(nt, "ShaderNodeMath", (-350, 600), operation="MULTIPLY")
        vein_amt2.inputs[1].default_value = 0.25
        nt.links.new(vein_amt.outputs[0], vein_amt2.inputs[0])
        vein_amt = vein_amt2
    # colour stack (linear, around 0.5)
    base_col = (0.56, 0.5, 0.47) if living else (0.5, 0.5, 0.52)
    ramp = node(nt, "ShaderNodeValToRGB", (-800, 300))
    ramp.color_ramp.elements[0].color = tuple(c * (0.9 if living else 0.78) for c in base_col) + (1,)
    ramp.color_ramp.elements[1].color = tuple(min(1.0, c * 1.14) for c in base_col) + (1,)
    nt.links.new(mot.outputs["Fac"], ramp.inputs[0])
    cur = ramp.outputs[0]

    def mix(col_b, fac, loc, blend="MIX"):
        m = node(nt, "ShaderNodeMix", loc, data_type="RGBA", blend_type=blend)
        nt.links.new(fac, m.inputs["Factor"])
        nt.links.new(cur, m.inputs[6])
        if isinstance(col_b, tuple):
            m.inputs[7].default_value = col_b + (1,)
        else:
            nt.links.new(col_b, m.inputs[7])
        return m.outputs[2]

    cur = mix((0.24, 0.22, 0.42) if not living else (0.42, 0.36, 0.4), vein_amt.outputs[0], (-200, 500))
    if not living:
        # frostbite blotches: mask x noise
        fb = node(nt, "ShaderNodeMath", (-500, 100), operation="MULTIPLY")
        nt.links.new(frost, fb.inputs[0])
        fbn = node(nt, "ShaderNodeMapRange", (-700, 100))
        nt.links.new(mot.outputs["Fac"], fbn.inputs["Value"])
        fbn.inputs["From Min"].default_value = 0.3
        fbn.inputs["From Max"].default_value = 0.6
        fbn.inputs["To Min"].default_value = 0.55
        fbn.inputs["To Max"].default_value = 1.0
        nt.links.new(fbn.outputs[0], fb.inputs[1])
        cur = mix((0.14, 0.1, 0.17), fb.outputs[0], (-100, 300))
        cur = mix((0.07, 0.04, 0.09), socket, (0, 200))
        lv = node(nt, "ShaderNodeMath", (-300, 0), operation="MULTIPLY")
        lv.inputs[1].default_value = 0.6
        nt.links.new(livid, lv.inputs[0])
        cur = mix((0.34, 0.2, 0.3), lv.outputs[0], (100, 100))
    else:
        rosy = node(nt, "ShaderNodeMath", (-300, 0), operation="MULTIPLY")
        rosy.inputs[1].default_value = 0.5
        nt.links.new(frost, rosy.inputs[0])
        cur = mix((0.6, 0.38, 0.36), rosy.outputs[0], (100, 100))
    # pores speckle
    pf = node(nt, "ShaderNodeMapRange", (-700, -100))
    nt.links.new(fine.outputs["Fac"], pf.inputs["Value"])
    pf.inputs["From Min"].default_value = 0.35
    pf.inputs["From Max"].default_value = 0.65
    pf.inputs["To Min"].default_value = 0.0
    pf.inputs["To Max"].default_value = 0.12
    cur = mix((0.25, 0.22, 0.22), pf.outputs[0], (200, 0))
    albedo = cur
    # bump: veins raised, wrinkles, pores
    bump_h = node(nt, "ShaderNodeMath", (600, -300), operation="ADD")
    nt.links.new(vein_amt.outputs[0], bump_h.inputs[0])
    nt.links.new(fine.outputs["Fac"], bump_h.inputs[1])
    bump = node(nt, "ShaderNodeBump", (800, -300))
    bump.inputs["Strength"].default_value = 0.4 if not living else 0.2
    bump.inputs["Distance"].default_value = 0.006
    nt.links.new(bump_h.outputs[0], bump.inputs["Height"])
    # roughness: frostbite and veins a touch glossier (waxy)
    rough = node(nt, "ShaderNodeMapRange", (600, -500))
    nt.links.new(frost, rough.inputs["Value"])
    rough.inputs["To Min"].default_value = 0.62 if not living else 0.5
    rough.inputs["To Max"].default_value = 0.42 if not living else 0.45
    bsdf = node(nt, "ShaderNodeBsdfPrincipled", (1000, 0))
    nt.links.new(albedo, bsdf.inputs["Base Color"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
    emit = node(nt, "ShaderNodeEmission", (1000, -400))
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat, nt, bsdf, emit, out, {"albedo": albedo, "origin": origin, "rough": rough.outputs[0]}


def bake(ob, nt, img, kind, emit_src=None, emit=None, out=None, bsdf=None):
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    for nd in nt.nodes:
        nd.select = False
    tn.select = True
    nt.nodes.active = tn
    if kind == "EMIT":
        nt.links.new(emit_src, emit.inputs["Color"])
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
        bpy.ops.object.bake(type="EMIT", margin=8)
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    elif kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
    elif kind == "AO":
        bpy.ops.object.bake(type="AO", margin=8)
    nt.nodes.remove(tn)


def new_image(name, size, srgb):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    return img


def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def save_png(arr, path, srgb):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def main_from(living, size=1024):
    C.reset_scene()
    P = MB.Params("medium", False, living)
    B = MB.build(P)
    objs = MB.body_objects(P, B)
    body = objs["Body"]
    MB.unwrap(body, B)
    fr, og, so, lv, vd = masks(P, B)
    me = body.data
    for name, cols in (("MaskA", np.stack([fr, og, so, np.ones_like(fr)], 1)), ("MaskB", np.stack([lv, vd, np.zeros_like(fr), np.ones_like(fr)], 1))):
        attr = me.color_attributes.new(name=name, type="FLOAT_COLOR", domain="POINT")
        attr.data.foreach_set("color", cols.astype(np.float32).ravel())
    for o in objs.values():
        if o is not body:
            o.hide_render = True
    mat, nt, bsdf, emit, out, srcs = build_material(living)
    body.data.materials.clear()
    body.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = False
    C.select_only(body)
    d = os.path.join(MB.REPO, "assets", "ours", "characters", "human_base" if living else "zombie_base")
    os.makedirs(d, exist_ok=True)
    names = MB.CFG["textures"]["living" if living else "zombie"]
    # albedo (+ origin mask into alpha)
    img_a = new_image("alb", size, True)
    bake(body, nt, img_a, "EMIT", srcs["albedo"], emit, out, bsdf)
    img_o = new_image("org", size, False)
    bake(body, nt, img_o, "EMIT", srcs["origin"], emit, out, bsdf)
    img_r = new_image("rough", size, False)
    bake(body, nt, img_r, "EMIT", srcs["rough"], emit, out, bsdf)
    img_n = new_image("nrm", size, False)
    sc.cycles.samples = 4
    bake(body, nt, img_n, "NORMAL")
    img_ao = new_image("ao", size, False)
    sc.cycles.samples = 48
    # AO from the body only (kits are separate meshes; their own AO is per vertex)
    bake(body, nt, img_ao, "AO")
    a = pixels(img_a).copy()
    a[..., 3] = 0.0 if living else pixels(img_o)[..., 0]
    save_png(a, os.path.join(d, names["albedo"]), True)
    nrm = pixels(img_n).copy()
    nrm[..., 3] = 1.0
    save_png(nrm, os.path.join(d, names["normal"]), False)
    orm = np.zeros_like(nrm)
    orm[..., 0] = np.clip(0.35 + 0.65 * pixels(img_ao)[..., 0], 0, 1)
    orm[..., 1] = pixels(img_r)[..., 0]
    orm[..., 2] = 0.0
    orm[..., 3] = 1.0
    save_png(orm, os.path.join(d, names["orm"]), False)
    print("[make_textures] %s set -> %s" % ("living" if living else "zombie", d))


if __name__ == "__main__":
    av = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main_from("--living" in av, int(next((s.split("=")[1] for s in av if s.startswith("--size=")), 1024)))
