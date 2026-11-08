"""GRAVELIGHT ONE: one source mesh -> the intact C-47 (the in-flight cutscene) and the crashed one (Map 0's set).
UPDATE 12 section 5, DECISIONS T-211. Headless Blender 5.1:

    tools/c47/blender.sh -P tools/c47/build_c47.py -- [--source=<model.glb>|--standin] [--id=<asset id>]
        [--out=<dir>] [--decals=<atlas.png>] [--preview=<dir>] [--no-impostor] [--write-colliders]

(tools/c47/build.sh picks the source and the output folder: the real model from assets/user_supplied/u12/c47/<model>/
when one is there, else the stand-in, c47_airframe.py, our own low-poly C-47.)

The SAME steps run on either source (the crash is geometry, not hand-placed art):
  1. normalize   an imported GLB is joined, turned nose -Z / up +Y, scaled to the 29.0 m span, its cabin fitted to
                 the map's hull section (gen_map00 WRECK_RING) and its interior faces cleared; the stand-in is built
                 that way already.
  2. paint       the vertex colour: scorch round the fuel fire's points, soot streaks off them, snow allowance;
                 our markings projected onto the skin (KQ913, GRAVELIGHT ONE, the RAF roundels and fin flash).
  3. intact      the props become their own nodes (pivot = the hub) for the cutscene's spin; our cabin and cockpit
                 (c47_interior.py, intact); anchors for the exhaust glow and the formation / navigation lights.
  4. crashed     the planes in data/gravelight/c47_wreck.json cut the skin into pieces (the starboard wing sheared
                 at the root, the port engine torn off its mount, the port wing's outer panel, the tail behind the
                 split, the starboard tailplane); every cut edge is torn (jittered); the props' blades bend back; the
                 nose is crushed down into the field; the cabin's openings and the glazing are punched out exactly
                 over gen_map00's WRECK_OPENINGS; the forward fuselage rolls 8 deg onto its starboard side as the map
                 has it; each loose piece goes to its pose and is dropped onto the snow; snow drifts on the windward
                 (port) side, the gouge behind; our cabin and cockpit, crashed (the covered co-pilot, Selwyn's
                 pinned seat exactly where TrappedPilot sits).
  5. LODs        LOD0 / LOD1 (35 %) / LOD2 (12 %) per exterior piece, the interior LOD0 only; an 8-view impostor
                 atlas (Cycles, CPU) for the far view.
  6. export      <out>/intact.glb (or model.glb in the stand-in's assets/ours/world/c47_intact/), crashed GLB, the
                 impostor PNG, stats.json; --write-colliders also writes data/gravelight/c47_colliders.json (the
                 oriented boxes gen_map00 builds the wreck's colliders from, T-188: collision matches the art).
Frames: the airframe is built in gen_map00's WRECK frame (rolled); the crashed GLB is in the SITE frame (the wreck's
position and yaw, no roll: the ground is y = 0) so loose pieces lie flat.
"""
import json
import math
import os
import re
import sys
import time

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import c47_lib as L  # noqa: E402
import c47_airframe as AF  # noqa: E402
import c47_interior as INT  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LAYOUT = os.path.join(ROOT, "data", "gravelight", "c47_wreck.json")
COLLIDERS = os.path.join(ROOT, "data", "gravelight", "c47_colliders.json")


def log(*a):
    print("[c47]", *a, flush=True)


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"source": "standin", "id": "standin", "out": None, "decals": os.path.join(HERE, "_gen", "decals.png"),
           "preview": None, "impostor": True, "write_colliders": False, "only": ""}
    for s in a:
        if s.startswith("--source="):
            out["source"] = s.split("=", 1)[1]
        elif s == "--standin":
            out["source"] = "standin"
        elif s.startswith("--id="):
            out["id"] = s.split("=", 1)[1]
        elif s.startswith("--out="):
            out["out"] = s.split("=", 1)[1]
        elif s.startswith("--decals="):
            out["decals"] = s.split("=", 1)[1]
        elif s.startswith("--preview="):
            out["preview"] = s.split("=", 1)[1]
        elif s == "--no-impostor":
            out["impostor"] = False
        elif s == "--write-colliders":
            out["write_colliders"] = True
        elif s.startswith("--only="):
            out["only"] = s.split("=", 1)[1]
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ================================================================== 1. the source

def import_source(path):
    """Imports a GLB / glTF / OBJ / FBX and returns it as one GMesh in Godot's frame, normalized (see the doc)."""
    ext = os.path.splitext(path)[1].lower()
    before = set(bpy.data.objects)
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit("[c47] unsupported source format: " + path)
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    if not objs:
        raise SystemExit("[c47] no mesh in " + path)
    g = L.GMesh("C47_Source")
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        eo = o.evaluated_get(dg)
        me = eo.to_mesh()
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(L.B2G @ o.matrix_world)
        # material names survive; the glass is found by name or alpha
        names = [re.sub(r"\.\d{3}$", "", ms.material.name) if ms.material else "c47_od" for ms in o.material_slots] or ["c47_od"]
        if tmp.loops.layers.uv.active is not None and tmp.loops.layers.uv.get("UVMap") is None:
            tmp.loops.layers.uv.active.name = "UVMap" if False else tmp.loops.layers.uv.active.name
        groups = {}
        for f in tmp.faces:
            groups.setdefault(min(f.material_index, len(names) - 1), []).append(f.index)
        for mi_, idxs in groups.items():
            t2 = tmp.copy()
            keep = set(idxs)
            t2.faces.ensure_lookup_table()
            bmesh.ops.delete(t2, geom=[f for f in t2.faces if f.index not in keep], context="FACES")
            uvl = t2.loops.layers.uv.active
            if uvl is not None and uvl.name != "UVMap":
                # rename the first UV layer so GMesh keeps it
                u2 = t2.loops.layers.uv.new("UVMap")
                for f in t2.faces:
                    for lp in f.loops:
                        lp[u2].uv = lp[uvl].uv
            nm = names[mi_]
            mat = bpy.data.materials.get(nm)
            if mat is not None and _is_glass(mat):
                nm = "c47_glass"
            g.add(t2, nm, True, keepuv=True)
        eo.to_mesh_clear()
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    normalize(g)
    return g


def _is_glass(mat):
    n = mat.name.lower()
    if any(k in n for k in ("glass", "window", "canopy", "windshield", "windscreen", "transp")):
        return True
    try:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        return bsdf is not None and bsdf.inputs["Alpha"].default_value < 0.9
    except Exception:
        return False


def normalize(g):
    """Turns an arbitrary C-47 mesh into the wreck frame: span along X (29.0 m), the nose toward -Z, up +Y, the cabin
    fitted to the map's section, the cockpit's front wall at z -7.2. Logged numbers let the next session check it."""
    bm = g.bm
    vs = [v.co.copy() for v in bm.verts]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    ext = hi - lo
    log("source bbox", tuple(round(c, 3) for c in ext))
    # the span is the longest horizontal extent (glTF is +Y up already); swap X and Z when the span is along Z
    if ext.z > ext.x:
        g.transform(Matrix.Rotation(math.radians(90.0), 4, "Y"))
    vs = [v.co.copy() for v in bm.verts]
    span = max(v.x for v in vs) - min(v.x for v in vs)
    s = 29.0 / max(span, 1e-6)
    g.transform(Matrix.Scale(s, 4))
    vs = [v.co.copy() for v in bm.verts]
    cx = (max(v.x for v in vs) + min(v.x for v in vs)) * 0.5
    g.transform(Matrix.Translation((-cx, 0, 0)))
    # the nose: the wing (the widest slice) sits in the front half of the length
    vs = [v.co.copy() for v in bm.verts]
    z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
    bins = [0.0] * 40
    for v in vs:
        k = min(39, int((v.z - z0) / max(z1 - z0, 1e-6) * 40))
        bins[k] = max(bins[k], abs(v.x))
    wing_bin = max(range(40), key=lambda k: bins[k])
    if wing_bin > 20:   # the wing is in the back half: the nose is toward +Z, turn it round
        g.transform(Matrix.Rotation(math.radians(180.0), 4, "Y"))
    # the cabin's section: the fuselage only (|x| < 2 m) between 30 % and 55 % of the length
    vs = [v.co.copy() for v in bm.verts]
    z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
    za, zb = z0 + (z1 - z0) * 0.3, z0 + (z1 - z0) * 0.55
    cab = [v for v in vs if za <= v.z <= zb and abs(v.x) < 2.0]
    # (the wing's root lies in this slice too: take the fuselage's widest half-width above the wing)
    # the roof's shoulder (|x| 0.45..0.75: clear of the astrodome, the D/F loop and the aerial on the centre line)
    # against the ring's there (y 2.66), the keel (|x| < 0.4) against -0.22, the widest point against 1.44
    shoulder = max(v.y for v in cab if 0.45 < abs(v.x) < 0.75)
    keel = min(v.y for v in cab if abs(v.x) < 0.4)
    top = shoulder
    half = max(abs(v.x) for v in cab if v.y > keel + (top - keel) * 0.45)
    sx = AF.RING_W / max(half, 1e-6)
    sy = (2.66 - AF.RING_YB) / max(top - keel, 1e-6)
    log("fit: half-width %.3f -> %.3f (x%.3f), height %.3f -> %.3f (x%.3f)" % (half, AF.RING_W, sx, top - keel, AF.RING_YT - AF.RING_YB, sy))
    for v in bm.verts:
        # the fuselage widens to the ring; past 2.5 m out (the wings, the tailplane) everything only shifts with it
        ax = abs(v.co.x)
        k = 1.0 - L.smoothstep(1.6, 2.6, ax)
        dx = (sx - 1.0) * (ax if ax < 1.6 else 1.6 + (ax - 1.6) * k)
        v.co.x += math.copysign(dx, v.co.x)
        v.co.y = keel + (v.co.y - keel) * sy
    g.transform(Matrix.Translation((0, AF.RING_YB - keel, 0)))
    # the cockpit's front wall: the windscreen's base is ~1.6 m behind the nose's tip on a DC-3
    vs = [v.co.copy() for v in bm.verts]
    nose = min(v.z for v in vs)
    g.transform(Matrix.Translation((0, 0, AF.STATIONS[0][0] - nose)))
    # clear the source's own interior (our cabin and cockpit go there)
    inner = []
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(c.x) < 1.2 and 0.1 < c.y < 2.4 and -7.0 < c.z < 6.1:
            inner.append(f)
    bmesh.ops.delete(bm, geom=inner, context="FACES")
    log("normalized: %d faces, %d interior faces cleared" % (len(bm.faces), len(inner)))


# ================================================================== 2. paint (vertex colour)

def paint(g, lay):
    """R scorch, G soot, B snow allowance. The fuel fire burned at the starboard wing root and into the cabin through
    the torn hole, along the port wing's root and round the port engine's mount; its smoke stained the skin aft."""
    blobs = lay["scorch"]
    for f in g.bm.faces:
        for lp in f.loops:
            p = lp.vert.co
            sc = 0.0
            so = 0.0
            for b in blobs:
                c = Vector(b["at"])
                d = (p - c).length / float(b["r"])
                sc = max(sc, float(b.get("k", 1.0)) * math.exp(-d * d * 1.6))
                # soot streaks aft and up from each fire point
                rel = p - c
                if rel.z > 0.0 and rel.y > -0.6:
                    lat = math.hypot(rel.x * 0.8, (rel.y - rel.z * 0.18))
                    so = max(so, 0.85 * math.exp(-(lat / (0.6 + rel.z * 0.12)) ** 2) * math.exp(-rel.z / 6.0) * float(b.get("k", 1.0)))
            n = L.vnoise(p, 0.55, 3)
            sc = L.smoothstep(0.25, 0.85, sc * (0.65 + 0.7 * n))
            dirt = 0.18 + 0.25 * L.vnoise(p, 2.5, 5)
            col = lp[g.col]
            lp[g.col] = (sc, min(1.0, max(so * (0.6 + 0.6 * n), dirt)), col[2], 1.0)


# ================================================================== 3. intact

def split_props(g, info):
    """The two propellers' faces (blades, hub, spinner) as their own GMesh each, the rest stays."""
    out = {}
    for side in ("L", "R"):
        hub = Vector(info["hub_" + side])
        sel = set()
        for f in g.bm.faces:
            c = f.calc_center_median()
            r = math.hypot(c.x - hub.x, c.y - hub.y)
            if abs(c.z - hub.z) < 0.16 and r < AF.PROP_R + 0.1 and (r > 0.76 or c.z < hub.z + 0.08):
                sel.add(f.index)
        p = g.copy("Prop_" + side)
        p.bm.faces.ensure_lookup_table()
        p.keep_faces(lambda f, sel=sel: f.index in sel)
        g.bm.faces.ensure_lookup_table()
        g.keep_faces(lambda f, sel=sel: f.index not in sel)
        out[side] = p
        g.bm.faces.ensure_lookup_table()
    return out


def build_intact(src, info, coll):
    g = src.copy("Airframe")
    props = split_props(g, info)
    objs = []
    objs.append(g.to_object("Airframe_LOD0", coll))
    for side, p in props.items():
        hub = Vector(info["hub_" + side])
        objs.append(p.to_object("Prop_%s_LOD0" % side, coll, hub))
    it = INT.interior(crashed=False)
    objs.append(it.to_object("Interior_INT", coll))
    for k in ("exhaust_L", "exhaust_R", "light_L", "light_R", "light_tail", "light_top", "light_belly"):
        objs.append(L.empty("Anchor_" + k, info[k], coll))
    objs.append(L.empty("Anchor_cockpit_eye", (-0.35, 1.5, -5.75), coll))
    return objs


# ================================================================== 4. crashed

PIECES = ["fuselage", "tail", "stab_s", "wing_s", "engine_p", "wing_p_out"]


def bisect(g, co, no, faces=None):
    bm = g.bm
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces) if faces is None else \
        list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + list(faces)
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=Vector(co), plane_no=Vector(no))


def classify(g, lay, info):
    cut = lay["cuts"]
    bz = float(cut["break_z"])
    sx = float(cut["wing_s_x"])
    px = float(cut["wing_p_out_x"])
    hub_l = Vector(info["hub_L"])
    fw = float(cut["engine_p_firewall_z"])
    # the cuts' planes, so every piece separates on clean edges
    bisect(g, (0, 0, bz), (0, 0, 1))
    bisect(g, (sx, 0, 0), (1, 0, 0), [f for f in g.bm.faces if f.calc_center_median().z < bz])
    bisect(g, (px, 0, 0), (1, 0, 0), [f for f in g.bm.faces if f.calc_center_median().z < bz])
    bisect(g, (0, 0, fw), (0, 0, 1), [f for f in g.bm.faces if abs(f.calc_center_median().x - hub_l.x) < 1.0])
    bisect(g, (0.95, 0, 0), (1, 0, 0), [f for f in g.bm.faces if f.calc_center_median().z > 8.0])
    counts = {}
    for f in g.bm.faces:
        c = f.calc_center_median()
        pid = 0
        rprop = math.hypot(c.x - hub_l.x, c.y - hub_l.y)
        if c.z > bz:
            w = AF.station_at(c.z)[0]
            pid = 2 if (c.z > 8.2 and c.x > max(0.95, w + 0.03) and abs(c.y - AF.STAB_Y) < 0.4) else 1
        elif c.x > sx:
            pid = 3
        elif (abs(c.z - hub_l.z) < 0.35 and rprop < AF.PROP_R + 0.15) or (abs(c.x - hub_l.x) < 0.95 and abs(c.y - hub_l.y) < 0.95 and c.z < fw):
            pid = 4
        elif c.x < px:
            pid = 5
        f[g.piece] = pid
        counts[PIECES[pid]] = counts.get(PIECES[pid], 0) + 1
    log("pieces", counts)


def tear_edges(g, lay):
    """Jitters the vertices on every cut plane so the breaks read torn, not sawn (both sides share them)."""
    cut = lay["cuts"]
    planes = [(2, float(cut["break_z"]), 0.2), (0, float(cut["wing_s_x"]), 0.14), (0, float(cut["wing_p_out_x"]), 0.16),
              (2, float(cut["engine_p_firewall_z"]), 0.1)]
    for v in g.bm.verts:
        for ax, val, amp in planes:
            if abs(v.co[ax] - val) < 2e-4:
                n = L.vnoise(v.co * 1.0, 0.35, 11 + ax) - 0.5
                n2 = L.vnoise(v.co * 1.0, 0.11, 17 + ax) - 0.5
                v.co[ax] += (n * 1.4 + n2 * 0.6) * amp


def split(g):
    out = {}
    for pid, name in enumerate(PIECES):
        p = g.copy(name)
        p.keep_faces(lambda f, pid=pid, p=p: f[p.piece] == pid)
        out[name] = p
    return out


def bend_blades(p, hub, axis, deg, seed):
    """Bends every blade of the prop round `hub` back (along +axis) from 0.45 m out, more toward the tip."""
    hub = Vector(hub)
    ax = Vector(axis).normalized()
    for v in p.bm.verts:
        d = v.co - hub
        along = d.dot(ax)
        radial = d - ax * along
        r = radial.length
        if r < 0.45 or abs(along) > 0.3:
            continue
        rd = radial.normalized()
        t = ax.cross(rd).normalized()
        k = L.smoothstep(0.45, AF.PROP_R, r)
        ang = math.radians(deg) * k * (0.75 + 0.5 * L.hash01(round(math.atan2(rd.y, rd.x), 1), seed))
        pivot = hub + rd * 0.45
        m = Matrix.Rotation(-ang, 4, t)
        v.co = pivot + (m.to_3x3() @ (v.co - pivot))


def crush_nose(p, lay):
    c = lay["crush"]
    z0, z1 = float(c["from_z"]), float(c["tip_z"])
    for v in p.bm.verts:
        if v.co.z >= z0:
            continue
        k = L.smoothstep(z0, z1, v.co.z)
        n = Vector((L.vnoise(v.co, 0.3, 21), L.vnoise(v.co, 0.3, 22), L.vnoise(v.co, 0.3, 23))) - Vector((0.5, 0.5, 0.5))
        low = 1.0 if v.co.y < float(c["sill_y"]) else 0.45
        v.co.z += float(c["push_back"]) * k
        v.co.y -= float(c["push_down"]) * (k ** 1.3) * low
        v.co.x *= 1.0 + float(c["bulge"]) * k * (1.0 if v.co.y < 1.2 else 0.3)
        v.co += n * float(c["crumple"]) * k


def punch_openings(p, lay, rng):
    """The hull's openings, exactly over gen_map00 WRECK_OPENINGS (and the windscreen): the faces inside go; the
    torn ones' edges move OUT only (the art's hole is never smaller than the collider's)."""
    ops = lay["openings"]
    bm = p.bm
    for o in ops:
        side, z0, z1, y0, y1 = int(o[0]), float(o[1]), float(o[2]), float(o[3]), float(o[4])
        torn = bool(o[5]) if len(o) > 5 else False
        if side == 0:
            continue
        sel = [f for f in bm.faces if (f.calc_center_median().x * side) > 0.85 and f.calc_center_median().z < 6.2]
        for co, no in (((0, 0, z0), (0, 0, 1)), ((0, 0, z1), (0, 0, 1)), ((0, y0, 0), (0, 1, 0)), ((0, y1, 0), (0, 1, 0))):
            bisect(p, co, no, [f for f in bm.faces if (f.calc_center_median().x * side) > 0.85 and f.calc_center_median().z < 6.2])
        if torn:
            e = 0.45
            near = [f for f in bm.faces if f.calc_center_median().x * side > 0.85 and z0 - e < f.calc_center_median().z < z1 + e and
                    y0 - e < f.calc_center_median().y < y1 + e and f.calc_center_median().z < 6.2]
            bmesh.ops.subdivide_edges(bm, edges=list({ed for f in near for ed in f.edges}), cuts=3, use_grid_fill=True)

        def inside(c, torn=torn, side=side, z0=z0, z1=z1, y0=y0, y1=y1):
            if c.x * side <= 0.85:
                return False
            if not torn:
                return z0 - 1e-3 < c.z < z1 + 1e-3 and y0 - 1e-3 < c.y < y1 + 1e-3
            n = lambda s_: 0.24 * L.vnoise(c, 0.22, s_) ** 1.5
            return z0 - n(61) < c.z < z1 + n(62) and y0 - n(63) < c.y < y1 + min(0.18, n(64))
        dead = [f for f in bm.faces if inside(f.calc_center_median())]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        if torn:
            _petals(p, side, z0, z1, y0, y1, rng)
    # the windscreen and the cockpit's side windows: all glazing goes (shattered); a few shards are added by the caller
    glass = p.mi("c47_glass")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == glass and f.calc_center_median().z < -4.9], context="FACES")
    # the windscreen's opening (the collider's hole over the nose) even when the source had no glass there
    w = lay["windscreen"]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.calc_center_median().x) < float(w["half_x"]) and
                               float(w["z0"]) < f.calc_center_median().z < float(w["z1"]) and f.calc_center_median().y > float(w["y0"])],
                     context="FACES")
    # the crack over the roof from the split behind the wing (light through it; the roof's collider is whole)
    cr = lay["roof_crack"]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > float(cr["y0"]) and
                               abs(f.calc_center_median().z - float(cr["z"]) - 0.12 * math.sin(f.calc_center_median().x * 3.0)) < float(cr["w"]) and
                               f.calc_center_median().x > float(cr["x0"])], context="FACES")


def _petals(p, side, z0, z1, y0, y1, rng):
    """Torn skin peeled back round a hole: bent triangles of painted skin at its edges (outside the doorway's line,
    so nothing hangs where you walk in)."""
    for k in range(14):
        t = rng.random()
        edge = rng.randrange(3)   # the fore jamb, the aft jamb, the top
        if edge == 0:
            z, y = z0 - 0.02, y0 + 0.3 + t * (y1 - y0 - 0.4)
            along = Vector((0, 1, 0))
            out = Vector((side * 0.6, 0, -0.8)).normalized()
        elif edge == 1:
            z, y = z1 + 0.02, y0 + 0.3 + t * (y1 - y0 - 0.4)
            along = Vector((0, 1, 0))
            out = Vector((side * 0.6, 0, 0.8)).normalized()
        else:
            z, y = z0 + 0.2 + t * (z1 - z0 - 0.4), y1 + 0.03
            along = Vector((0, 0, 1))
            out = Vector((side * 0.7, 0.7, 0)).normalized()
        w = AF.station_at(z)[0]
        base = Vector((side * (w - 0.01), y, z))
        ln = rng.uniform(0.12, 0.28)
        tip = base + out * rng.uniform(0.15, 0.32) + along * rng.uniform(-0.08, 0.08)
        a = base - along * ln * 0.5
        b = base + along * ln * 0.5
        L.quad(p, [a, b, tip], "c47_od", color=(rng.uniform(0.3, 0.9), 0.7, 0.3, 1.0))
        L.quad(p, [b, a, tip], "c47_int", color=(0.4, 0.6, 0.0, 1.0))


def dents(p, lay):
    """The skin's dents and the buckling: low-frequency inward pushes over the sides and the belly (more toward the
    nose and the split), a wrinkle band round the fuselage at the split behind the wing. Inward only, and never more
    than 0.12 m: the cabin's lining (0.29 m inside the skin) never shows them."""
    sp = lay["openings"][0]
    zs = (float(sp[1]) + float(sp[2])) * 0.5
    for v in p.bm.verts:
        c = v.co
        if c.z > 6.2 or abs(c.x) > 1.6 or c.z < -9.5:
            continue
        w, yb, yt = AF.station_at(c.z)
        yc = (yb + yt) * 0.5
        inward = Vector((-c.x, yc - c.y, 0.0))
        if inward.length < 1e-4:
            continue
        inward.normalize()
        k = 0.035 + 0.05 * L.smoothstep(-4.0, -8.5, c.z) + 0.04 * math.exp(-((c.z - zs) / 0.5) ** 2)
        d = L.vnoise(c, 0.9, 71) * 0.7 + L.vnoise(c, 0.35, 72) * 0.3
        d = max(0.0, d - 0.35) * 2.0
        wr = 0.06 * math.exp(-((c.z - zs - 0.6 * math.sin(c.y * 2.0)) / 0.12) ** 2)   # the wrinkle band
        v.co += inward * min(0.12, d * k + wr)


def engine_mount(g, info, lay, rng):
    """The port engine's mount left on the firewall when the engine tore away: the welded tubes, bent and broken."""
    hub = Vector(info["hub_L"])
    fw = float(lay["cuts"]["engine_p_firewall_z"])
    for k in range(6):
        a = math.tau * k / 6 + 0.3
        p0 = Vector((hub.x + math.cos(a) * 0.5, hub.y + math.sin(a) * 0.5, fw + 0.02))
        ln = rng.uniform(0.25, 0.65)
        p1 = Vector((hub.x + math.cos(a + 0.5) * 0.32, hub.y + math.sin(a + 0.5) * 0.32, fw - ln))
        p1 += Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.15, 0.05), 0))
        L.tube(g, [p0, p0.lerp(p1, 0.5) + Vector((0, rng.uniform(-0.05, 0.05), 0)), p1], 0.028, "c47_exhaust", 6, color=(0.7, 0.8, 0.0, 1))
    L.cyl(g, (hub.x, hub.y, fw - 0.01), 0.62, 0.03, "c47_metal", axis="z", segs=16, color=(0.85, 0.8, 0.0, 1))   # the firewall


def pose_matrix(pz):
    piv = Vector(pz["pivot"])
    return Matrix.Translation(Vector(pz["pos"])) @ L.rot_matrix(pz["rot"]) @ Matrix.Translation(-piv)


def drop(p, sink):
    lo = min(v.co.y for v in p.bm.verts)
    m = Matrix.Translation((0, -lo - sink, 0))
    p.transform(m)
    return m


POSED = {}   # piece -> its full transform (the pose, then the drop onto the snow)


def posed(name):
    return POSED[name]


def droop_outer(p, lay, roll):
    """The port wing's outer panel, broken at the joint, drooping until its tip is in the snow (after the roll)."""
    hx = float(lay["cuts"]["wing_p_out_x"])
    hinge_y = AF.WING_Y + math.tan(math.radians(AF.DIHEDRAL)) * (abs(hx) - 3.9)
    target = float(lay["pieces"]["wing_p_out"]["tip_y"])
    best = 0.0
    for deg in [x * 0.5 for x in range(0, 120)]:
        m = roll @ L.axis_angle((0, 0, 1), deg, (hx, hinge_y, 0))
        lo = min((m @ v.co).y for v in p.bm.verts)
        best = deg
        if lo <= target:
            break
    p.transform(L.axis_angle((0, 0, 1), best, (hx, hinge_y, 0)))
    log("port outer panel droops %.1f deg" % best)
    return best


def shards(g, lay, rng):
    """A few glass shards left in the windscreen's frame and the side windows' (the glazing is out)."""
    w = lay["windscreen"]
    for k in range(9):
        x = rng.uniform(-0.95, 0.95)
        y = rng.uniform(float(w["y0"]) + 0.02, 1.3)
        z = float(w["z0"]) + 0.12 + (y - float(w["y0"])) * 0.4
        L.quad(g, [(x, y, z), (x + rng.uniform(0.05, 0.14), y + rng.uniform(-0.02, 0.03), z), (x + rng.uniform(0.0, 0.08), y + rng.uniform(0.06, 0.16), z - 0.04)],
               "c47_glass")
    # the windscreen's frame, bent: the centre post and the two side posts
    for fx in (-1.0, 0.0, 1.0):
        L.tube(g, [(fx * 0.98, float(w["y0"]), float(w["z0"]) + 0.05), (fx * 0.9 + rng.uniform(-0.06, 0.06), 2.2, -7.3), (fx * 0.6, 2.62, -7.2)],
               0.025, "c47_black", 5)


def stringers(g, lay, rng):
    """Torn skin shows the structure: the stringers' ends sticking out of every break, bent; frames at the split."""
    bz = float(lay["cuts"]["break_z"])
    rn = AF._ring_norm()
    ring = AF._fuselage_ring(bz, rn)
    for i, p in enumerate(ring):
        if i % 2:
            continue
        inward = Vector((-p.x, 1.265 - p.y, 0.0)).normalized() * 0.03
        a = p + inward
        b = a + Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), rng.uniform(0.12, 0.38)))
        L.strut(g, a + Vector((0, 0, -0.15)), b, 0.022, "c47_metal")
    for o in lay["openings"]:
        if len(o) < 6 or not o[5]:
            continue
        side, z0, z1, y0, y1 = int(o[0]), float(o[1]), float(o[2]), float(o[3]), float(o[4])
        for y in [y1 - 0.08, y1 + 0.12, 1.2, 0.7]:
            for zz, dirn in ((z0, 1), (z1, -1)):
                w = AF.station_at(zz)[0]
                x = side * (w - 0.06)
                L.strut(g, (x, y, zz - dirn * 0.12), (x + side * rng.uniform(-0.04, 0.08), y + rng.uniform(-0.06, 0.06), zz + dirn * rng.uniform(0.08, 0.26)), 0.02, "c47_metal")
        # the frames (ribs) left standing at each side of the hole, their tops bent in
        for zz in (z0 - 0.05, z1 + 0.05):
            w = AF.station_at(zz)[0]
            L.tube(g, [(side * (w - 0.08), y0 + 0.02, zz), (side * (w - 0.1), y1 - 0.2, zz), (side * (w - 0.3), y1 + 0.1, zz + rng.uniform(-0.1, 0.1))], 0.03, "c47_metal", 5)


def snow_and_ground(lay, pieces_site):
    """Snow drifted against the windward (port) side and under the port wing; the gouge the plane cut, behind it."""
    g = L.GMesh("Ground")
    rng = L.rng(1944)
    wing = pieces_site["fuselage"]
    tree = L.bvh(wing)
    for dr in lay["drifts"]:
        _drift(g, tree, dr)
    _gouge(g, lay, rng)
    _plow(g, lay, rng)
    return g


def _drift(g, tree, dr):
    """A heightfield of drifted snow banked against the port flank (windward) and filling under the port wing up to
    its underside (the wing's collider reaches the snow: the drift is what you see there), smoothed, falling off to
    the field at its edges."""
    x0, x1, z0, z1, step = dr["x0"], dr["x1"], dr["z0"], dr["z1"], dr["step"]
    nx = int((x1 - x0) / step) + 1
    nz = int((z1 - z0) / step) + 1
    fx = float(dr.get("flank_x", -1.4))
    H = [[0.0] * nz for _ in range(nx)]
    U = [[None] * nz for _ in range(nx)]
    for i in range(nx):
        for j in range(nz):
            x = x0 + i * step
            z = z0 + j * step
            hit = tree.ray_cast(Vector((x, -0.5, z)), Vector((0, 1, 0)), 6.0)
            under = hit[0].y - 0.05 if hit[0] is not None else None
            U[i][j] = under
            h = float(dr["flank_h"]) * L.smoothstep(fx - 2.4, fx, x) * (0.7 + 0.6 * L.vnoise((x, 0, z), 1.3, 41))
            if under is not None:
                h = max(h, min(under, float(dr["max_h"])) * (0.85 + 0.15 * L.vnoise((x, 1, z), 0.9, 42)))
            H[i][j] = h
    for _ in range(3):   # smooth (the wing's edges would leave cliffs)
        H2 = [row[:] for row in H]
        for i in range(1, nx - 1):
            for j in range(1, nz - 1):
                H2[i][j] = (H[i][j] * 4 + H[i - 1][j] + H[i + 1][j] + H[i][j - 1] + H[i][j + 1]) / 8.0
        H = H2
    tmp = bmesh.new()
    grid = {}
    for i in range(nx):
        for j in range(nz):
            x = x0 + i * step
            z = z0 + j * step
            edge_m = min(i, nx - 1 - i, j, nz - 1 - j) * step
            h = H[i][j] * L.smoothstep(0.0, 1.1, edge_m)
            if U[i][j] is not None:
                h = min(h, U[i][j])
            grid[(i, j)] = tmp.verts.new((x, h - 0.03, z))
    for i in range(nx - 1):
        for j in range(nz - 1):
            tmp.faces.new((grid[(i, j)], grid[(i, j + 1)], grid[(i + 1, j + 1)], grid[(i + 1, j)]))
    flat = [f for f in tmp.faces if all(v.co.y < 0.0 for v in f.verts)]
    bmesh.ops.delete(tmp, geom=flat, context="FACES")
    bmesh.ops.delete(tmp, geom=[v for v in tmp.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    for f in tmp.faces:
        if f.normal.y < 0:
            f.normal_flip()
    g.add(tmp, "mats_snow", True, color=(0, 0.1, 1, 1))


def _plow(g, lay, rng):
    """The snow the nose ploughed up ahead of itself (low: under Selwyn's line of fire over the nose)."""
    pl = lay.get("plow")
    if not pl:
        return
    c = Vector(pl["at"])
    L.sphere(g, c, pl["size"], "mats_snow", 14, 7, color=(0, 0.1, 1, 1))
    for k in range(9):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.6, 1.0)
        o = Vector((math.cos(a) * pl["size"][0] * 0.5 * r, 0.0, math.sin(a) * pl["size"][2] * 0.5 * r))
        L.sphere(g, c + o, (rng.uniform(0.5, 1.2), rng.uniform(0.15, pl["size"][1] * 0.8), rng.uniform(0.5, 1.1)), "mats_snow", 8, 4, color=(0, 0.1, 1, 1))


def _gouge(g, lay, rng):
    """The gouge: a furrow of churned snow and frozen earth from behind the starboard wing to the tail."""
    # the gouge: a furrow of churned snow and frozen earth from behind the starboard wing to the tail, berms each side
    pts = [Vector(p) for p in lay["gouge"]["path"]]
    wdt = float(lay["gouge"]["width"])
    left, right, lb, rb = [], [], [], []
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        sd = Vector((d.z, 0, -d.x))
        w = wdt * (0.6 + 0.4 * L.vnoise(p, 4.0, 51))
        left.append(p + sd * w * 0.5 + Vector((0, 0.012, 0)))
        right.append(p - sd * w * 0.5 + Vector((0, 0.012, 0)))
        lb.append(p + sd * (w * 0.5 + 0.45) + Vector((0, 0.16 + 0.1 * L.vnoise(p, 2.0, 52), 0)))
        rb.append(p - sd * (w * 0.5 + 0.45) + Vector((0, 0.16 + 0.1 * L.vnoise(p, 2.0, 53), 0)))
    L.loft(g, [[a, b] for a, b in zip(right, left)], None, "mats_dirt", closed=False, smooth=True, color=(0.3, 0.6, 0.4, 1))
    outer_l = [p + Vector((0, -0.03, 0)) + (p - q) * 0.9 for p, q in zip(lb, left)]
    outer_r = [p + Vector((0, -0.03, 0)) + (p - q) * 0.9 for p, q in zip(rb, right)]
    L.loft(g, [[a, b, c] for a, b, c in zip(left, lb, outer_l)], None, "mats_snow", closed=False, smooth=True, color=(0, 0.05, 1, 1))
    L.loft(g, [[c, b, a] for a, b, c in zip(right, rb, outer_r)], None, "mats_snow", closed=False, smooth=True, color=(0, 0.05, 1, 1))
    # churned clods in the furrow
    for k in range(40):
        t = rng.random() * (len(pts) - 1)
        i = int(t)
        p = pts[i].lerp(pts[min(i + 1, len(pts) - 1)], t - i)
        L.sphere(g, p + Vector((rng.uniform(-1.2, 1.2), 0.03, rng.uniform(-0.5, 0.5))), (rng.uniform(0.15, 0.5), rng.uniform(0.04, 0.09), rng.uniform(0.15, 0.4)),
                 "mats_snow" if k % 3 else "mats_dirt", 6, 3, color=(0, 0.2, 1, 1))


def obb_of(p, basis, pad=0.0, name="", clip_ground=True):
    """The piece's box in `basis` (a 3x3 whose columns are the box's axes, site frame): [name, centre, size, basis]."""
    inv = basis.inverted()
    loc = [inv @ v.co for v in p.bm.verts]
    lo = Vector((min(v.x for v in loc), min(v.y for v in loc), min(v.z for v in loc))) - Vector((pad, pad, pad))
    hi = Vector((max(v.x for v in loc), max(v.y for v in loc), max(v.z for v in loc))) + Vector((pad, pad, pad))
    c = basis @ ((lo + hi) * 0.5)
    return {"name": name, "center": [round(c.x, 3), round(c.y, 3), round(c.z, 3)], "size": [round(s, 3) for s in (hi - lo)],
            "basis": [[round(basis[r][k], 5) for k in range(3)] for r in range(3)]}


def build_crashed(src, info, lay, coll, write_colliders):
    rng = L.rng(23121944)
    g = src.copy("Crash")
    classify(g, lay, info)
    tear_edges(g, lay)
    pcs = split(g)
    roll = Matrix.Rotation(math.radians(float(lay["site"]["roll_deg"])), 4, "Z")
    # the props bend back where they hit the snow
    hl, hr = Vector(info["hub_L"]), Vector(info["hub_R"])
    bend_blades(pcs["engine_p"], hl, (0, 0, 1), float(lay["props"]["bend_deg"]), 1)
    bend_blades(pcs["wing_s"], hr, (0, 0, 1), float(lay["props"]["bend_deg"]) * 0.8, 2)
    # the forward fuselage: the nose crushed, the openings and the glazing out, the torn structure, rolled
    fus = pcs["fuselage"]
    punch_openings(fus, lay, rng)
    dents(fus, lay)
    crush_nose(fus, lay)
    engine_mount(fus, info, lay, rng)
    shards(fus, lay, rng)
    stringers(fus, lay, rng)
    site = {}
    for name in ("fuselage",):
        pcs[name].transform(roll)
        site[name] = pcs[name]
    poses = lay["pieces"]
    cols = []
    local = {n: pcs[n].copy(n + "_local") for n in ("tail", "stab_s", "wing_s", "engine_p", "wing_p_out")}
    for name in ("tail", "stab_s", "wing_s", "engine_p", "wing_p_out"):
        p = pcs[name]
        pm = pose_matrix(poses[name])
        p.transform(pm)
        POSED[name] = drop(p, float(poses[name].get("sink", 0.1))) @ pm
        site[name] = p
    # the tail's fin bent over to port at its root (the tail broke up)
    fb = poses["tail"].get("fin_bend_deg", 0.0)
    if fb:
        tail = site["tail"]
        tm = posed("tail")
        root = tm @ Vector((0.0, 2.55, 9.0))
        ax = (tm.to_3x3() @ Vector((0, 0, 1))).normalized()
        upv = (tm.to_3x3() @ Vector((0, 1, 0))).normalized()
        faces = []
        for f in tail.bm.faces:
            if (f.calc_center_median() - root).dot(upv) > 0.12:
                faces.append(f)
        POSED["fin_bend"] = L.axis_angle(ax, fb, root)
        tail.transform(POSED["fin_bend"], faces)
    # the snow and the gouge
    ground = snow_and_ground(lay, site)
    # LODs and objects
    objs = []
    for name, p in site.items():
        objs.append(p.to_object("%s_LOD0" % name, coll))
    objs.append(ground.to_object("ground_ALL", coll))
    interior = INT.interior(crashed=True)
    interior.transform(roll)
    objs.append(interior.to_object("Interior_INT", coll))
    # colliders: oriented boxes per loose piece (site frame) and the port wing's outer panel (rolled with the hull)
    if write_colliders:
        cols = colliders(site, local, lay)
        with open(COLLIDERS, "w", encoding="utf-8", newline="\n") as f:
            json.dump({"_doc": "Generated by tools/c47/build_c47.py --write-colliders from the stand-in (T-211): the crashed C-47's "
                               "loose pieces as oriented boxes in the SITE frame (the wreck's position and yaw, no roll; y = 0 the snow). "
                               "gen_map00 builds GRAVELIGHT ONE's debris colliders from these (T-188: collision matches the art). "
                               "The hull's colliders stay gen_map00's own (WRECK_*).", "boxes": cols}, f, indent=1)
        log("colliders -> %s (%d boxes)" % (os.path.relpath(COLLIDERS, ROOT), len(cols)))
    return objs, site


def _local_box(p, pred, m, name):
    """The box round the faces pred() keeps, in the piece's own (pre-pose, wreck-frame) axes, carried by m into the
    site frame."""
    q = p.copy(name)
    q.keep_faces(pred)
    if not len(q.bm.verts):
        return None
    vs = [v.co for v in q.bm.verts]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = m @ ((lo + hi) * 0.5)
    b = m.to_3x3().normalized()
    size = hi - lo
    return {"name": name, "center": [round(c.x, 3), round(c.y, 3), round(c.z, 3)], "size": [round(x, 3) for x in size],
            "basis": [[round(b[r][k], 5) for k in range(3)] for r in range(3)]}


def _pca_box(local, posed_piece, pred, name, flat_top=None):
    """The faces pred() keeps (judged in the piece's own frame), boxed along their principal axes as they lie.
    flat_top: a slab lying in the snow: a level box from below the snow to that height (the navmesh walks over it:
    agent_max_climb 0.25, so no unreachable island on top)."""
    local.bm.faces.ensure_lookup_table()
    keep = {f.index for f in local.bm.faces if pred(f)}
    q = posed_piece.copy(name)
    q.bm.faces.ensure_lookup_table()
    q.keep_faces(lambda f: f.index in keep)
    if len(q.bm.verts) < 4:
        return None
    if flat_top is None:
        return obb_of(q, _pca_basis(q), 0.0, name)
    if flat_top == "max":
        # a tilted plate (the port tailplane): a level box from the snow to its top edge, so its slope is never a
        # ramp up onto the wreck (the space under it is the drift's)
        flat_top = max(v.co.y for v in q.bm.verts)
    pb = _pca_basis(q)
    a = Vector((pb[0][0], 0.0, pb[2][0])).normalized()
    up = Vector((0, 1, 0))
    c = a.cross(up).normalized()
    basis = Matrix((a, up, c)).transposed()
    box = obb_of(q, basis, 0.0, name)
    lo = -0.3
    box["center"][1] = round((lo + flat_top) * 0.5, 3)
    box["size"][1] = round(flat_top - lo, 3)
    return box


def colliders(site, local, lay):
    """Oriented boxes per loose piece's parts, fitted in the piece's own axes (so a wing is a slab, not the box round
    its nacelle and bent blades), then posed; the blades are left out (thin), the outer port panel along its PCA."""
    out = []

    def cen(f):
        return f.calc_center_median()

    def blade(c, hub):
        return abs(c.z - hub.z) < 0.3 and math.hypot(c.x - hub.x, c.y - hub.y) > 0.4

    def nac(c):
        return abs(c.x - AF.ENGINE_X) < 0.82 and c.y > -0.5 and -4.8 < c.z < 1.7
    hl = Vector((-AF.ENGINE_X, AF.ENGINE_Y, AF.PROP_Z))
    hr = Vector((AF.ENGINE_X, AF.ENGINE_Y, AF.PROP_Z))
    t = posed("tail")
    for (za, zb, nm) in ((6.0, 8.4, "C47Col_tail"), (8.4, 11.0, "C47Col_tail_end")):
        out.append(_local_box(local["tail"], lambda f, za=za, zb=zb: abs(cen(f).x) <= AF.station_at(cen(f).z)[0] + 0.05 and cen(f).y < 2.76 and
                              za <= cen(f).z < zb, t, nm))
    out.append(_pca_box(local["tail"], site["tail"], lambda f: cen(f).x < -AF.station_at(cen(f).z)[0] - 0.05 and cen(f).y < 2.6, "C47Col_stab_p", "max"))
    out.append(_local_box(local["tail"], lambda f: cen(f).y >= 2.76 and abs(cen(f).x) < 0.4, POSED.get("fin_bend", Matrix.Identity(4)) @ t, "C47Col_fin"))
    out.append(_local_box(local["stab_s"], lambda f: True, posed("stab_s"), "C47Col_stab_s"))
    w = posed("wing_s")
    lw = local["wing_s"]
    bl = {lw.mi("c47_black"), lw.mi("c47_yellow")}
    out.append(_pca_box(lw, site["wing_s"], lambda f: not nac(cen(f)) and f.material_index not in bl, "C47Col_wing_s", 0.24))
    # the nacelle in two (the cowl and the tapering rear): two tops at different heights, neither big enough to leave
    # an unreachable navmesh island (region_min_size 8 m2)
    out.append(_local_box(lw, lambda f: nac(cen(f)) and f.material_index not in bl and cen(f).z < -2.2, w, "C47Col_nacelle_s"))
    out.append(_local_box(lw, lambda f: nac(cen(f)) and f.material_index not in bl and cen(f).z >= -2.2, w, "C47Col_nacelle_s_aft"))
    le = local["engine_p"]
    bl2 = {le.mi("c47_black"), le.mi("c47_yellow")}
    out.append(_local_box(le, lambda f: f.material_index not in bl2, posed("engine_p"), "C47Col_engine_p"))
    out.append(_pca_box(local["wing_p_out"], site["wing_p_out"], lambda f: True, "C47Col_wing_p_out", 0.24))
    return [o for o in out if o is not None]


def _pca_basis(p):
    """An orthonormal basis along the piece's principal axes (its longest direction first)."""
    import numpy as np
    pts = np.array([[v.co.x, v.co.y, v.co.z] for v in p.bm.verts])
    c = pts.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov((pts - c).T))
    order = np.argsort(w)[::-1]
    a = Vector(vecs[:, order[0]]).normalized()
    b2 = Vector(vecs[:, order[1]]).normalized()
    c3 = a.cross(b2).normalized()
    b2 = c3.cross(a).normalized()
    m = Matrix((a, b2, c3)).transposed()
    return m


# ================================================================== 5. LODs, impostor

def make_lods(objs, coll, ratios=(0.35, 0.12)):
    out = []
    for o in list(objs):
        if not o.name.endswith("_LOD0"):
            continue
        base = o.name[:-5]
        for k, r in enumerate(ratios, start=1):
            c = o.copy()
            c.data = o.data.copy()
            c.name = "%s_LOD%d" % (base, k)
            coll.objects.link(c)
            mod = c.modifiers.new("dec", "DECIMATE")
            mod.ratio = r
            mod.use_collapse_triangulate = True
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(c.evaluated_get(dg))
            c.modifiers.clear()
            old = c.data
            c.data = me
            bpy.data.meshes.remove(old)
            out.append(c)
    return out


DOUBLE_SLOTS = ("c47_od", "c47_ng", "c47_metal", "c47_black", "c47_yellow", "c47_exhaust", "c47_char", "c47_int")


def double_side(objs):
    """The skin's back as its own (flipped) faces: the game's c47_skin is one-sided (cull_back; see its header), and a
    torn edge or the open end of the broken tail must show the skin's back, not the sky through it."""
    added = 0
    for o in objs:
        if o.type != "MESH" or not ("_LOD" in o.name):
            continue
        slots = {i for i, ms in enumerate(o.material_slots) if ms.material is not None and ms.material.name.split(".")[0] in DOUBLE_SLOTS}
        if not slots:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        src = [f for f in bm.faces if f.material_index in slots]
        res = bmesh.ops.duplicate(bm, geom=src)
        new_faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=new_faces)
        added += len(new_faces)
        bm.to_mesh(o.data)
        bm.free()
    log("double-sided skin: %d faces added" % added)


def render_impostor(objs, out_png, frames=8, fw=512, fh=256):
    """An 8-view atlas (yaw 0, 45, ... deg about the site's +Y) of the given objects, transparent background."""
    import numpy as np
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 12
    try:
        scn.cycles.use_denoising = False
    except Exception:
        pass
    scn.render.film_transparent = True
    scn.render.resolution_x = fw
    scn.render.resolution_y = fh
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("imp") if scn.world is None else scn.world
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.38, 0.45, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sun = bpy.data.objects.new("imp_sun", bpy.data.lights.new("imp_sun", "SUN"))
    sun.data.energy = 2.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scn.collection.objects.link(sun)
    hidden = []
    for o in scn.objects:
        if o.type == "MESH" and o not in objs:
            hidden.append((o, o.hide_render))
            o.hide_render = True
    # bounds (Blender frame)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (lo + hi) * 0.5
    rad = max((hi - lo).x, (hi - lo).y) * 0.5
    cam = bpy.data.objects.new("imp_cam", bpy.data.cameras.new("imp_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = rad * 2.05
    scn.collection.objects.link(cam)
    scn.camera = cam
    atlas = np.zeros((fh * 2, fw * (frames // 2), 4), dtype=np.float32)
    tmpdir = os.path.dirname(out_png)
    for k in range(frames):
        yaw = math.tau * k / frames   # Godot yaw of the viewer about +Y (Blender +Z), 0 = looking from +Z(Godot) = -Y(Blender)
        d = Vector((math.sin(yaw), -math.cos(yaw), 0.0))   # from the centre toward the camera, in Blender's XY
        cam.location = ctr + d * (rad * 3.0) + Vector((0, 0, (hi.z - lo.z) * 0.15))
        cam.rotation_euler = (-(ctr - cam.location)).to_track_quat("Z", "Y").to_euler()
        f = os.path.join(tmpdir, "_imp_%d.png" % k)
        scn.render.filepath = f
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(f)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(fh, fw, 4)
        row = k // (frames // 2)
        col = k % (frames // 2)
        atlas[(1 - row) * fh:(2 - row) * fh, col * fw:(col + 1) * fw, :] = px
        bpy.data.images.remove(im)
        os.remove(f)
    img = bpy.data.images.new("impostor", fw * (frames // 2), fh * 2, alpha=True)
    img.pixels = atlas.ravel()
    img.filepath_raw = out_png
    img.file_format = "PNG"
    img.save()
    for o, h in hidden:
        o.hide_render = h
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.objects.remove(sun, do_unlink=True)
    log("impostor -> %s (%d views, %.1f m wide)" % (out_png, frames, rad * 2.05))
    return {"frames": frames, "cols": frames // 2, "rows": 2, "width_m": round(rad * 2.05, 3),
            "center": [round(ctr.x, 3), round(ctr.z, 3), round(-ctr.y, 3)]}


# ================================================================== 6. export and preview

def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children:
            c.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True, export_texcoords=True,
                              export_normals=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_cameras=False, export_lights=False, export_animations=False, export_extras=False,
                              export_skins=False, export_morph=False, use_selection=True, export_image_format="AUTO")
    tris = 0
    for o in objs:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
    log("%s: %d objects, %d tris" % (os.path.relpath(path, ROOT), len(objs), tris))
    return tris


def preview(objs, out_dir, tag, views):
    """Cycles renders (CPU) of the given objects for a look without the game (silent, no window)."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 24
    scn.render.film_transparent = False
    scn.render.resolution_x = 960
    scn.render.resolution_y = 540
    scn.render.image_settings.file_format = "JPEG"
    world = bpy.data.worlds.new("pv") if scn.world is None else scn.world
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    sun = bpy.data.objects.new("pv_sun", bpy.data.lights.new("pv_sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    scn.collection.objects.link(sun)
    ground = None
    if tag.startswith("crashed"):
        bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0))
        ground = bpy.context.active_object
        ground.data.materials.append(L.material("mats_snow"))
    shown = set(objs)
    hidden = []
    for o in scn.objects:
        if o.type == "MESH" and o not in shown and o is not ground:
            hidden.append((o, o.hide_render))
            o.hide_render = True
    cam = bpy.data.objects.new("pv_cam", bpy.data.cameras.new("pv_cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    os.makedirs(out_dir, exist_ok=True)
    lamps = []
    for k, lp in enumerate(((0.0, 1.9, 2.5), (0.0, 1.9, -1.5), (0.0, 1.9, -5.6))):
        la = bpy.data.objects.new("pv_lamp%d" % k, bpy.data.lights.new("pv_lamp%d" % k, "POINT"))
        la.data.energy = 60.0
        la.data.color = (1.0, 0.75, 0.5)
        p3 = Vector(lp)
        if tag.startswith("crashed"):
            p3 = Matrix.Rotation(math.radians(-8.0), 4, "Z") @ p3
        la.location = L.G2B @ p3
        scn.collection.objects.link(la)
        lamps.append(la)
    for (name, eye, tgt, lens) in views:
        e = L.G2B @ Vector(eye)
        t = L.G2B @ Vector(tgt)
        cam.location = e
        cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        cam.data.clip_start = 0.02
        scn.render.filepath = os.path.join(out_dir, "%s_%s.jpg" % (tag, name))
        bpy.ops.render.render(write_still=True)
        log("preview", scn.render.filepath)
    for o, h in hidden:
        o.hide_render = h
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.objects.remove(sun, do_unlink=True)
    for la in lamps:
        bpy.data.objects.remove(la, do_unlink=True)
    if ground is not None:
        bpy.data.objects.remove(ground, do_unlink=True)


def paperwork(out_dir, title, desc):
    lic = ("Ours (original work)\n\nGRAVELIGHT ONE's stand-in C-47 was made for GRAVELIGHT by the project itself: it is generated by\n"
           "tools/c47/build_c47.py and tools/c47/c47_airframe.py from primitives and published dimensions only, with no\n"
           "third-party mesh, texture or scan (the markings atlas is drawn by tools/c47/make_decals.py with the bundled OFL\n"
           "fonts). It may be used, changed and shipped with the game like the rest of the project's own code.\n")
    src = ("Title: %s\nAuthor: GRAVELIGHT (generated by tools/c47/build_c47.py)\nSource: tools/c47/build_c47.py (headless Blender 5.1: tools/c47/build.sh)\n"
           "License: Ours (original work)\nCredit line: none required (original work)\n"
           "Format: GLB, metres, +Y up, the nose toward -Z; material slots c47_* (gravelight/world/c47/c47_art.gd) and mats_* / lib_*\n"
           "Downloaded: generated %s by Claude (T-211, UPDATE 12 section 5)\nFiles used: model.glb%s\nNotes: %s\n") % (
        title, time.strftime("%Y-%m-%d"), ", impostor.png" if os.path.exists(os.path.join(out_dir, "impostor.png")) else "", desc)
    with open(os.path.join(out_dir, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lic)
    with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(src)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def main():
    a = args()
    reset()
    with open(LAYOUT, encoding="utf-8") as f:
        lay = json.load(f)
    L.DECAL_IMAGE = a["decals"] if os.path.exists(a["decals"]) else None
    with open(os.path.splitext(a["decals"])[0] + ".json", encoding="utf-8") as f:
        cells = json.load(f)["cells"]
    INT.set_cells(cells)
    t0 = time.time()
    standin = a["source"] == "standin"
    if standin:
        src, info = AF.airframe(cells)
    else:
        src = import_source(a["source"])
        # the hubs etc. of the real model are taken where the stand-in has them (the normalize step put the airframe
        # in the same frame); the projected markings go on its skin the same way
        _, info = AF.airframe(cells)
        tree = L.bvh(src)
        AF.markings(src, tree, cells)
    paint(src, lay)
    log("source: %d faces, %d tris (%.1f s)" % (len(src.bm.faces), src.tris(), time.time() - t0))
    if standin:
        out_intact = a["out"] or os.path.join(ROOT, "assets", "ours", "world", "c47_intact")
        out_crash = os.path.join(os.path.dirname(out_intact), "c47_crashed") if not a["out"] else a["out"]
        f_intact = os.path.join(out_intact, "model.glb")
        f_crash = os.path.join(out_crash, "model.glb")
    else:
        out_intact = out_crash = a["out"]
        f_intact = os.path.join(out_intact, "intact.glb")
        f_crash = os.path.join(out_crash, "crashed.glb")
    stats = {"source": a["source"], "id": a["id"]}
    if a["only"] in ("", "intact"):
        coll = bpy.data.collections.new("intact")
        bpy.context.scene.collection.children.link(coll)
        objs = build_intact(src, info, coll)
        objs += make_lods(objs, coll)
        double_side(objs)
        stats["intact_tris"] = export(f_intact, objs)
        if a["preview"]:
            preview([o for o in objs if o.name.endswith("_LOD0") or o.name.endswith("_INT")], a["preview"], "intact", [
                ("front34", (-14.0, 4.0, -18.0), (0.0, 1.2, 0.0), 30), ("side", (24.0, 3.0, 2.0), (0.0, 1.6, 1.0), 30),
                ("top", (6.0, 26.0, 8.0), (0.0, 0.0, 1.0), 30), ("cabin", (0.0, 1.65, 4.8), (0.0, 1.1, -4.6), 18),
                ("cockpit", (0.05, 1.9, -4.6), (-0.2, 0.9, -6.6), 16)])
        if standin:
            paperwork(out_intact, "GRAVELIGHT ONE, intact (stand-in C-47)", "The in-flight C-47 for the GRAVELIGHT ONE cutscene: the airframe, "
                      "the props as Prop_L / Prop_R (pivot = hub), our cabin and cockpit, anchors for the exhaust glow and the lights.")
        clear_scene()
    if a["only"] in ("", "crashed"):
        coll = bpy.data.collections.new("crashed")
        bpy.context.scene.collection.children.link(coll)
        objs, site = build_crashed(src, info, lay, coll, a["write_colliders"])
        lods = make_lods(objs, coll)
        allobjs = objs + lods
        double_side(allobjs)
        imp = None
        if a["impostor"]:
            imp = render_impostor([o for o in allobjs if o.name.endswith("_LOD1") or o.name == "ground_ALL"],
                                  os.path.join(out_crash, "impostor.png"))
        stats["crashed_tris"] = export(f_crash, allobjs)
        stats["crashed_lod_tris"] = {}
        for k in ("LOD0", "LOD1", "LOD2"):
            n = 0
            for o in allobjs:
                if o.name.endswith(k) or o.name.endswith("_ALL") or (k == "LOD0" and o.name.endswith("_INT")):
                    o.data.calc_loop_triangles()
                    n += len(o.data.loop_triangles)
            stats["crashed_lod_tris"][k] = n
        stats["impostor"] = imp
        if a["preview"]:
            sv = [("site_nw", (-14.0, 3.5, -20.0), (0.0, 1.0, 2.0), 24), ("site_se", (14.0, 4.0, 14.0), (-1.0, 1.0, 2.0), 22),
                  ("site_top", (2.0, 34.0, 4.0), (0.0, 0.0, 2.0), 24), ("site_port", (-18.0, 3.0, 2.0), (0.0, 1.0, 2.0), 24),
                  ("cabin", (0.25, 1.62, 4.6), (0.1, 1.05, -4.6), 18), ("cockpit", (0.05, 1.82, -4.55), (-0.2, 0.75, -6.5), 16)]
            # cabin / cockpit views are in the wreck frame: roll them into the site frame
            roll = Matrix.Rotation(math.radians(float(lay["site"]["roll_deg"])), 4, "Z")
            sv = [(n, tuple(roll @ Vector(e)) if n in ("cabin", "cockpit") else e, tuple(roll @ Vector(t)) if n in ("cabin", "cockpit") else t, l)
                  for (n, e, t, l) in sv]
            preview([o for o in allobjs if o.name.endswith("_LOD0") or o.name.endswith("_INT") or o.name.endswith("_ALL")], a["preview"], "crashed", sv)
        if standin:
            paperwork(out_crash, "GRAVELIGHT ONE, crashed (stand-in C-47)", "Map 0's crashed C-47 in the wreck's site frame (gen_map00 places it): "
                      "pieces with LOD0-2, the interior, the snow drifts and the gouge, impostor.png (8 views) for the far view.")
    if a["only"] != "intact":   # the crashed build's numbers (the impostor's size: C47Art reads them)
        os.makedirs(out_crash, exist_ok=True)
        with open(os.path.join(out_crash, "stats.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(stats, f, indent=1)
    log("done in %.1f s" % (time.time() - t0))


main()
