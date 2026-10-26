"""Builds the GRAVELIGHT character set (T-091): six base bodies (thin / medium / heavy x male / female), each with
its face parts, two hair cuts, the nine outfit kits fitted to it and scripted LODs, into one GLB per body; then the
shared skin texture set (make_textures.py).

    blender -b --factory-startup -P tools_src/blender/characters/build_all.py -- [--living] [--only=m_medium,f_thin]
            [--no-textures] [--preview=<dir>] [--stats=<json>]

Zombies go to assets/ours/characters/zombie_base/, living people (--living) to assets/ours/characters/human_base/.
All six bodies share one UV layout (same skin-modifier graph and head / hand topology; the medium male is unwrapped
and the others copy its UVs before their budget decimation), so one texture set fits every body.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import mathutils  # noqa: E402
import numpy as np  # noqa: E402

import common as C  # noqa: E402
import make_body as MB  # noqa: E402
import make_kits as MK  # noqa: E402

BUILDS = ["thin", "medium", "heavy"]


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"living": False, "only": "", "textures": True, "preview": "", "stats": ""}
    for s in a:
        if s == "--living":
            out["living"] = True
        elif s == "--no-textures":
            out["textures"] = False
        elif s.startswith("--") and "=" in s:
            k, v = s[2:].split("=", 1)
            out[k] = v
    return out


def out_dir(living):
    return os.path.join(MB.REPO, "assets", "ours", "characters", "human_base" if living else "zombie_base")


def kit_object(name, kit):
    v, f, keys, bi, bw = kit.arrays()
    ob = MB.object_from(name, v, f, bi, bw, MB.part_colors(keys))
    return ob


def nearest_index(src_v, pts):
    kd = mathutils.kdtree.KDTree(len(src_v))
    for i, p in enumerate(src_v):
        kd.insert(tuple(p), i)
    kd.balance()
    return np.array([kd.find(tuple(p))[1] for p in pts], dtype=np.int64)


class Canon:
    """The canonical body's UV layout: rest verts, faces, regions and per-face corner UVs."""

    def __init__(self, B, loop_uvs):
        self.v = B.v
        self.f = B.f
        self.region = B.region
        self.face_uv = []
        k = 0
        for f in B.f:
            self.face_uv.append(loop_uvs[k:k + len(f)])
            k += len(f)
        self.face_region = np.array([int(B.region[f[0]]) for f in B.f])
        tri_f = [f for f, r in zip(B.f, self.face_region) if r == 0]
        self.trunk_ids = [i for i, r in enumerate(self.face_region) if r == 0]
        self.bvh = mathutils.bvhtree.BVHTree.FromPolygons([tuple(p) for p in B.v], tri_f)


def transfer_uvs(canon, P, B):
    """UVs for a body whose skin-modifier topology differs from the canonical one: every trunk face casts its
    corners outward from its bone's axis onto the canonical surface and maps the hits through the UVs of the
    canonical face its centre lands on (one island per face, no seam tearing); the head and the hands have the
    same topology in every body and copy their corner UVs."""
    segs = {s[0]: s for s in MB.bone_segments(P, apose=False)}
    dom = MB.dominant_bone(B.bi, B.bw)
    out = []
    face_region = [int(B.region[f[0]]) for f in B.f]
    other_canon = [i for i, r in enumerate(canon.face_region) if r != 0]
    other_k = 0
    for fi, f in enumerate(B.f):
        if face_region[fi] != 0:
            out.extend(canon.face_uv[other_canon[other_k]])
            other_k += 1
            continue
        pts = B.v[f]
        c = pts.mean(axis=0)
        bones = [MB.RIG.bones[int(dom[i])] for i in f]
        bname = max(set(bones), key=bones.count)
        seg = segs.get(bname)
        if seg is None:
            axis = np.array([0.0, c[1], 0.0])
        else:
            a, b = seg[1], seg[2]
            ab = b - a
            t = np.clip(np.dot(c - a, ab) / max(np.dot(ab, ab), 1e-9), 0, 1)
            axis = a + t * ab

        def cast(q):
            d = q - axis
            ln = np.linalg.norm(d)
            if ln < 1e-6:
                hit = canon.bvh.find_nearest(tuple(q))
                return hit[0], hit[2]
            hit = canon.bvh.ray_cast(tuple(axis), tuple(d / ln), 0.6)
            if hit[0] is None:
                hit2 = canon.bvh.find_nearest(tuple(q))
                return hit2[0], hit2[2]
            return hit[0], hit[2]

        cloc, cfi = cast(c)
        cf_global = canon.trunk_ids[cfi]
        cf = canon.f[cf_global]
        uv = canon.face_uv[cf_global]
        p0, p1, p2 = canon.v[cf[0]], canon.v[cf[1]], canon.v[cf[2]]
        M = np.stack([p1 - p0, p2 - p0], axis=1)
        for q in pts:
            h, _ = cast(q)
            h = np.array(h)
            ab_, _r, _rk, _s = np.linalg.lstsq(M, h - p0, rcond=None)
            out.append(uv[0] + ab_[0] * (uv[1] - uv[0]) + ab_[1] * (uv[2] - uv[0]))
    return np.array(out)


def build_one(sex, build, living, canonical_uv, a):
    C.reset_scene()
    P = MB.Params(build, sex == "f", living)
    B = MB.build(P)
    objs = MB.body_objects(P, B)
    body = objs["Body"]
    loops = len(body.data.loops)
    if canonical_uv is None:
        MB.unwrap(body, B)
        canonical_uv = Canon(B, C.get_loop_uvs(body))
    else:
        C.set_loop_uvs(body, transfer_uvs(canonical_uv, P, B))
    # kits from the full-resolution body
    kits = MK.build_kits(P, B)
    # budget: the body to body_tris, every kit to kit_tris
    MB.decimate_to(body, int(MB.CFG["body"]["body_tris"]))
    final_v = C.get_verts(body)
    near = nearest_index(B.v, final_v)
    order = MB.CFG["kit_order"]
    mask = np.zeros(len(final_v), dtype=np.int64)
    for i, name in enumerate(order):
        cov = np.zeros(len(B.v), dtype=bool)
        cov[list(kits[name].covered)] = True
        mask |= np.where(cov[near], 1 << i, 0)
    col = MB.body_colors(len(final_v), None, mask)
    C.set_color_attr(body, col)
    stats = {"Body": C.tri_count(body)}
    for name in order:
        ob = kit_object("Kit_" + name, kits[name])
        stats["Kit_" + name + "_raw"] = C.tri_count(ob)
        MB.decimate_to(ob, int(MB.CFG["budget"]["kit_tris"]))
        objs["Kit_" + name] = ob
    path = os.path.join(out_dir(living), (MB.CFG["living_file"] if living else MB.CFG["zombie_file"]) % (sex, build))
    s2 = MB.finish_and_export(P, objs, path)
    stats.update(s2)
    if a["preview"]:
        import preview
        for name in order:
            for o in bpy.data.objects:
                if o.type == "MESH":
                    o.hide_render = not (o.name in ("Body", "Parts", "Kit_" + name) or (o.name == ("Hair_f" if P.female else "Hair_m")))
            preview.render(a["preview"], "%s_%s_%s" % (sex, build, name), [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render], views=("front", "threeq"))
    print("[build_all] %s_%s%s -> %s %s" % (sex, build, " (living)" if living else "", path, stats))
    return canonical_uv, stats


def main():
    a = args()
    only = [s for s in a["only"].split(",") if s]
    all_stats = {}
    canonical = None
    # the canonical medium male first: it owns the UV layout
    order = [("m", "medium")] + [(s, b) for s in ("m", "f") for b in BUILDS if (s, b) != ("m", "medium")]
    for sex, build in order:
        tag = "%s_%s" % (sex, build)
        if only and tag not in only and canonical is not None:
            continue
        canonical, st = build_one(sex, build, a["living"], canonical, a)
        all_stats[tag] = st
    if a["textures"]:
        import make_textures
        make_textures.main_from(a["living"])
    if a["stats"]:
        with open(a["stats"], "w", encoding="utf-8") as f:
            json.dump(all_stats, f, indent=1)


if __name__ == "__main__":
    main()
