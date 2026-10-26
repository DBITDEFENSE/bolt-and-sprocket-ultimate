"""Builds the named people (T-092, UPDATE_05 section 4): the squad, Jakub, the Map 0 patrons and survivors, the
Cousins. One GLB per person: assets/ours/characters/people/char_person_<id>.glb with

    Armature  the ZombieRig skeleton (rig.json; the same 19 bones every MZ clip, IK and pose layer drives)
    Body      the living body built from make_body.Params(build, female, living=True) + the person's face knobs,
              the skin the kit covers already removed, UVs transferred from the canonical medium male (so the
              shared living skin textures fit), decimated to people.json budget.body_tris with the head and hands
              spared; COLOR_0 = the skin paint multiplier (lips, cheeks, stubble, doll paint); shape keys
    Parts     eyes (white, iris, pupil), lids and lash lines, brows, teeth, the mouth cavity, a moustache;
              COLOR_0.r = part key; shape keys
    Hair      the hair style (no shape keys)
    Kit       the person's clothes and headgear (make_kits.kit_<kit>), COLOR_0.r = part key, .g = AO / stains

The shape keys are people.json "shapes" (blink, jaw_open, fear, determined, pain, smile), see make_face.

    blender -b --factory-startup -P tools_src/blender/characters/build_people.py -- [--only=dutch,peg]
            [--preview=<dir>] [--faces=<dir>] [--stats=<json>]

tools/build_people.sh runs it and imports the GLBs. docs/CHARACTER_PIPELINE.md section 9.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402

import build_all as BA  # noqa: E402
import common as C  # noqa: E402
import make_body as MB  # noqa: E402
import make_face as MF  # noqa: E402
import make_kits as MK  # noqa: E402

PEOPLE = json.load(open(os.path.join(MB.REPO, "data", "gravelight", "art", "people.json"), encoding="utf-8"))
OUT_DIR = os.path.join(MB.REPO, "assets", "ours", "characters", "people")

# approximate colours for the Workbench previews only (the game colours come from PeopleBodies / KEY_LOOK)
PREVIEW_LOOK = {
    "dark": (0.05, 0.03, 0.04), "teeth": (0.75, 0.72, 0.62), "leather": (0.2, 0.13, 0.08), "metal": (0.4, 0.4, 0.42),
    "helmet": (0.27, 0.3, 0.25), "white": (0.86, 0.84, 0.8), "patch": (0.85, 0.83, 0.75), "glove": (0.1, 0.14, 0.1),
    "hair": (0.1, 0.08, 0.07), "hat": (0.15, 0.13, 0.11), "knit": (0.3, 0.28, 0.24), "armband": (0.6, 0.08, 0.08),
    "brass": (0.6, 0.5, 0.25), "rope": (0.5, 0.42, 0.28), "rubber": (0.14, 0.14, 0.15), "cloth": (0.36, 0.3, 0.24),
    "cloth2": (0.3, 0.3, 0.32), "cloth3": (0.25, 0.25, 0.25), "canvas": (0.38, 0.35, 0.24), "accent": (0.4, 0.15, 0.12),
    "eye_white": (0.8, 0.77, 0.72), "iris": (0.16, 0.12, 0.09), "lip": (0.4, 0.28, 0.3), "brow": (0.1, 0.08, 0.07),
    "stitch": (0.15, 0.08, 0.1), "navy": (0.12, 0.14, 0.22),
}


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"only": "", "preview": "", "faces": "", "stats": ""}
    for s in a:
        if s.startswith("--") and "=" in s:
            k, v = s[2:].split("=", 1)
            out[k] = v
    return out


def person_params(person):
    P = MB.Params(person.get("build", "medium"), bool(person.get("female", False)), True)
    ov = person.get("overrides", {})
    P.w *= float(ov.get("w", 1.0))
    P.sh *= float(ov.get("sh", 1.0))
    P.limb *= float(ov.get("limb", 1.0))
    if "belly" in ov:
        P.belly = float(ov["belly"])
    if "sink" in ov:
        P.sink = float(ov["sink"])
    P.face = dict(person.get("face", {}))
    P.face.setdefault("mouth_close", 1.0)
    if "head" in P.face:
        P.face["head"] = tuple(float(x) for x in P.face["head"])
    return P


def canonical():
    """The canonical living medium male's UV layout (the layout the shared living skin textures were baked on)."""
    C.reset_scene()
    P = MB.Params("medium", False, True)
    B = MB.build(P)
    body = MB.object_from("Body", B.v, B.f, B.bi, B.bw)
    MB.unwrap(body, B)
    return BA.Canon(B, C.get_loop_uvs(body))


def delete_faces(ob, face_ids):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    kill = [bm.faces[i] for i in sorted(set(face_ids))]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def decimate_protected(ob, target, protect_mask):
    """Collapse-decimates toward `target` triangles, sparing the vertices in protect_mask (the face, the hands)."""
    n = C.tri_count(ob)
    if n <= target:
        return n
    g = ob.vertex_groups.new(name="_dec")
    free = np.where(~protect_mask)[0]
    g.add([int(i) for i in free], 1.0, "REPLACE")
    ratio = float(target) / float(n)
    dec = ob.modifiers.new("Dec", "DECIMATE")
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    dec.use_symmetry = True
    dec.symmetry_axis = "X"
    dec.vertex_group = "_dec"
    dec.vertex_group_factor = 1.0
    C.apply_modifiers(ob)
    ob.vertex_groups.remove(ob.vertex_groups["_dec"])
    return C.tri_count(ob)


def add_shapes(ob, base_v, shapes):
    """Shape keys from per-vertex offsets (Godot frame)."""
    ob.shape_key_add(name="Basis", from_mix=False)
    for name in PEOPLE["shapes"]:
        off = shapes.get(name)
        sk = ob.shape_key_add(name=name, from_mix=False)
        co = C.g2b(base_v + (off if off is not None else 0.0)).astype(np.float32).ravel()
        sk.data.foreach_set("co", co)
        sk.value = 0.0


def kit_arrays(kit):
    vs, fs, ks, bis, bws, aos = [], [], [], [], [], []
    off = 0
    for p in kit.pieces:
        vs.append(p.v)
        fs.extend([[i + off for i in f] for f in p.f])
        ks.extend([MB.key(p.key)] * len(p.v))
        bis.append(p.bi)
        bws.append(p.bw)
        aos.append(getattr(p, "ao", np.ones(len(p.v))))
        off += len(p.v)
    return np.concatenate(vs), fs, np.array(ks), np.concatenate(bis), np.concatenate(bws), np.concatenate(aos)


def preview_colours(ob, person, is_body):
    """A second colour attribute with the person's approximate colours, for the Workbench previews."""
    me = ob.data
    src = me.color_attributes.get("Col")
    n = len(me.vertices)
    raw = np.zeros(n * 4, dtype=np.float32)
    src.data.foreach_get("color", raw)
    raw = raw.reshape(n, 4)
    out = np.ones((n, 4))
    pal = person.get("palette", {})
    tone = np.array(person.get("tone", [0.62, 0.5, 0.44]))
    if is_body:
        out[:, :3] = np.clip(tone * 1.1 * raw[:, :3], 0, 1)
    else:
        keys = MB.KEYS
        for i in range(n):
            kname = keys[int(round(raw[i, 0] * 255))]
            if kname == "lid":
                c = tone * 0.95
            else:
                c = np.array(pal.get(kname, PREVIEW_LOOK.get(kname, (1, 0, 1))))
            out[i, :3] = np.clip(c * raw[i, 1] * 1.6, 0, 1)
    attr = me.color_attributes.new(name="Preview", type="FLOAT_COLOR", domain="POINT")
    attr.data.foreach_set("color", out.astype(np.float32).ravel())
    me.color_attributes.active_color = attr


def restore_colours(ob):
    me = ob.data
    if "Preview" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Preview"])
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = me.color_attributes.find("Col")


def build_person(pid, person, canon, a):
    C.reset_scene()
    budget = PEOPLE["budget"]
    P = person_params(person)
    B = MB.build(P)
    body = MB.object_from("Body", B.v, B.f, B.bi, B.bw)
    C.set_loop_uvs(body, BA.transfer_uvs(canon, P, B))
    bv = MK.BodyView(B)
    kit = MK.PEOPLE_KITS[person.get("kit", pid)](bv, P)
    raw_body = C.tri_count(body)
    cov = np.zeros(len(B.v), dtype=bool)
    cov[list(kit.covered)] = True
    dead = [fi for fi, f in enumerate(B.f) if all(cov[i] for i in f)]
    delete_faces(body, dead)
    # decimate, sparing the head and the hands
    v_now = C.get_verts(body)
    protect = MF.head_mask(v_now) | (v_now[:, 1] < 0.95) & (np.abs(v_now[:, 0]) > 0.17) & (v_now[:, 1] > 0.6)
    decimate_protected(body, int(budget["body_tris"]), protect)
    v_body = C.get_verts(body)
    C.set_color_attr(body, MF.paint(v_body, person, P))
    shapes = MF.body_shapes(v_body - MF.HEAD_C)
    hm = MF.head_mask(v_body).astype(np.float64)[:, None]
    for k in shapes:
        shapes[k] = shapes[k] * hm
    objs = {"Body": body}
    # face parts
    S = MF.HeadSurface(B)
    pb = MF.face_parts(P, B, S, person)
    pv, pf, pk, pbi, pbw, pshapes = pb.arrays()
    parts = MB.object_from("Parts", pv, pf, pbi, pbw, MB.part_colors(pk))
    objs["Parts"] = parts
    # hair
    hacc = MF.hair(P, B, person)
    if hacc.v:
        hv, hf, hk, hbi, hbw = hacc.arrays()
        objs["Hair"] = MB.object_from("Hair", hv, hf, hbi, hbw, MB.part_colors(hk))
    # the kit
    kv, kf, kk, kbi, kbw, kao = kit_arrays(kit)
    kob = MB.object_from("Kit", kv, kf, kbi, kbw, MB.part_colors(kk, kao))
    stats = {"body_raw": raw_body, "body_culled_faces": len(dead), "kit_raw": C.tri_count(kob)}
    if not os.environ.get("PEOPLE_NODEC"):
        MB.decimate_to(kob, int(budget["kit_tris"]))
    objs["Kit"] = kob
    add_shapes(body, v_body, shapes)
    add_shapes(parts, pv, pshapes)
    for n, o in objs.items():
        stats[n] = C.tri_count(o)
    stats["total"] = sum(stats[n] for n in objs)
    if a["preview"] or a["faces"]:
        for n, o in objs.items():
            preview_colours(o, person, n == "Body")
        import preview
        mesh_objs = list(objs.values())
        if a["preview"]:
            preview.render(a["preview"], pid, mesh_objs, views=("front", "threeq", "face", "back"), colour_by="vcol")
        if a["faces"]:
            for sname in ["neutral"] + PEOPLE["shapes"]:
                for o in (body, parts):
                    for kb in o.data.shape_keys.key_blocks:
                        kb.value = 1.0 if kb.name == sname else 0.0
                preview.render(a["faces"], "%s_%s" % (pid, sname), mesh_objs, views=("face",), colour_by="vcol")
            for o in (body, parts):
                for kb in o.data.shape_keys.key_blocks:
                    kb.value = 0.0
        for o in objs.values():
            restore_colours(o)
    arm = C.build_armature(MB.RIG)
    for o in objs.values():
        C.bind(o, arm)
    path = os.path.join(OUT_DIR, PEOPLE["file"] % pid)
    C.export_glb(path, list(objs.values()), arm)
    print("[build_people] %s -> %s %s" % (pid, path, stats))
    return stats


def main():
    a = args()
    only = [s for s in a["only"].split(",") if s]
    canon = canonical()
    all_stats = {}
    for pid, person in PEOPLE["people"].items():
        if only and pid not in only:
            continue
        all_stats[pid] = build_person(pid, person, canon, a)
    if a["stats"]:
        with open(a["stats"], "w", encoding="utf-8") as f:
            json.dump(all_stats, f, indent=1)


if __name__ == "__main__":
    main()
