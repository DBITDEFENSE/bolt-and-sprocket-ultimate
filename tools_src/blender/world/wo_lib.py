"""Shared helpers for the world-object generators (UPDATE_05 section 5, DECISIONS T-094; docs/ART_BIBLE.md).

Every generator in this folder builds one or more of GRAVELIGHT's lore-specific world objects (the Helvetia tonic
cabinets, the Requisition Crate, the ammunition crate, the barricade planks, the door ironmongery, the wall-gun
mount, the Armorer's Bench, the Crucible, the field radio, the cellar lever, the exfil beacon) headless in Blender
and writes assets/ours/world/<object>/model.glb with its LICENSE.txt and SOURCE.txt ("Ours").

Conventions (the GLB contract the game's WorldArt loader reads, gravelight/world/world_art.gd):
- Geometry is written in GODOT's frame (metres, +Y up, the object's front toward -Z, origin = the floor centre of
  the footprint, the same frame as the old InteractableArt builders) and converted to Blender's Z-up just before
  the mesh is made, so the glTF exporter's +Y-up conversion hands Godot back exactly these numbers.
- A Part is one mesh object (one node in the GLB). Its origin is its pivot, so a part the game animates (a lid, a
  wheel, a tin mascot's arm) is rotated about the node origin. Parts are flat children of the scene root.
- An anchor is an empty (a plain Node3D in Godot) that marks where the game hangs something of its own (a label,
  a perk cap, a light).
- Material slots are NAMED for the game's materials, never textured here: `lib_<key>` = MaterialLibrary key (the
  CC0 PBR set, in UV mode), `lib_<key>__<rrggbb>` = the same tinted, `mats_<key>` = a procedural Mats key,
  `enamel_<rrggbb>` / `glass_<rrggbb>` / `paint_<rrggbb>` / `neon_<rrggbb>` = Mats' colour keys, and a few the game
  drives at runtime (`neon`, `backlight`, `lamp_glass`, `chalk`). Each slot also carries a plain base colour so the
  GLB reads sensibly in any viewer.
- UVs are box-mapped in metres (1 UV unit = 1 m) per face, so a library material's tile size is right on any part.
- Edges are bevelled (chamfered) where the brief calls for it; edges sharper than ~35 degrees are marked sharp so a
  smooth-shaded lathe keeps its creases.
"""
import datetime
import math
import os
import sys
import zlib

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_ROOT = os.path.join(ROOT, "assets", "ours", "world")

# Godot (x, y, z) -> Blender (x, -z, y)
G2B = Matrix.Rotation(math.radians(90.0), 4, "X")

SHARP_DEG = 35.0


# ================================================================== materials

# name -> (rgb, metallic, roughness) for the fallback base colour; prefixes are parsed in mat()
PALETTE = {
    "lib_planks": ((0.36, 0.27, 0.18), 0.0, 0.85),
    "lib_floorboards": ((0.30, 0.20, 0.12), 0.0, 0.8),
    "lib_iron": ((0.20, 0.18, 0.17), 0.85, 0.6),
    "lib_leather": ((0.26, 0.15, 0.08), 0.0, 0.6),
    "lib_canvas": ((0.48, 0.47, 0.40), 0.0, 0.95),
    "lib_burlap": ((0.52, 0.45, 0.33), 0.0, 0.95),
    "lib_wool": ((0.30, 0.29, 0.28), 0.0, 0.95),
    "lib_fieldstone": ((0.42, 0.41, 0.38), 0.0, 0.9),
    "lib_plaster_worn": ((0.55, 0.50, 0.43), 0.0, 0.9),
    "mats_brass": ((0.62, 0.48, 0.22), 1.0, 0.35),
    "mats_chrome": ((0.74, 0.74, 0.76), 1.0, 0.14),
    "mats_chrome_worn": ((0.45, 0.44, 0.43), 1.0, 0.3),
    "mats_copper": ((0.62, 0.34, 0.18), 1.0, 0.35),
    "mats_steel": ((0.45, 0.46, 0.48), 1.0, 0.35),
    "mats_black_paint": ((0.06, 0.06, 0.06), 0.0, 0.5),
    "mats_red_paint": ((0.45, 0.06, 0.04), 0.0, 0.5),
    "mats_yellow_paint": ((0.75, 0.6, 0.12), 0.0, 0.5),
    "mats_walnut": ((0.20, 0.10, 0.05), 0.0, 0.3),
    "mats_cream": ((0.80, 0.74, 0.58), 0.0, 0.3),
    "mats_furniture": ((0.30, 0.19, 0.11), 0.0, 0.6),
    "mats_beam": ((0.22, 0.15, 0.09), 0.0, 0.8),
    "mats_char": ((0.05, 0.045, 0.04), 0.0, 0.9),
    "mats_window_dark": ((0.02, 0.02, 0.025), 0.0, 0.2),
    "mats_nameplate": ((0.05, 0.045, 0.04), 0.0, 0.45),
    "mats_frosted": ((0.82, 0.86, 0.9), 0.0, 0.45),
    "mats_glass": ((0.7, 0.75, 0.8), 0.0, 0.05),
    "mats_tin": ((0.55, 0.56, 0.55), 0.8, 0.4),
    "mats_rubber": ((0.04, 0.04, 0.04), 0.0, 0.7),
    "mats_bakelite": ((0.09, 0.05, 0.03), 0.0, 0.22),
    "mats_enamel_white": ((0.86, 0.86, 0.82), 0.0, 0.25),
    "mats_enamel_green": ((0.12, 0.3, 0.18), 0.0, 0.3),
    "mats_cardboard": ((0.48, 0.38, 0.25), 0.0, 0.9),
    "mats_sandbag": ((0.5, 0.44, 0.32), 0.0, 0.95),
    "mats_tarp": ((0.3, 0.32, 0.22), 0.0, 0.9),
    "mats_machine_green": ((0.18, 0.26, 0.2), 0.3, 0.5),
    "mats_machine_grey": ((0.3, 0.31, 0.32), 0.4, 0.5),
    "mats_loco_black": ((0.06, 0.06, 0.065), 0.6, 0.45),
    "mats_concrete": ((0.45, 0.44, 0.42), 0.0, 0.9),
    "mats_gauge_face": ((0.85, 0.8, 0.66), 0.0, 0.4),
    "mats_nachtglas": ((0.08, 0.03, 0.12), 0.0, 0.1),
    "mats_nachtglas_vein": ((0.55, 0.2, 1.0), 0.0, 0.2),
    "mats_bulb_warm": ((1.0, 0.8, 0.55), 0.0, 0.2),
    "mats_brick": ((0.42, 0.2, 0.14), 0.0, 0.9),
    "mats_cellar_stone": ((0.35, 0.33, 0.3), 0.0, 0.9),
    "mats_paper": ((0.85, 0.8, 0.68), 0.0, 0.9),
    "mats_olive_drab": ((0.27, 0.29, 0.18), 0.0, 0.8),
    "neon": ((0.9, 0.9, 0.9), 0.0, 0.2),
    "backlight": ((0.3, 0.3, 0.3), 0.0, 0.5),
    "lamp_glass": ((1.0, 0.75, 0.4), 0.0, 0.1),
    "chalk": ((0.85, 0.85, 0.8), 0.0, 0.95),
}


def _hex(s):
    s = s.strip("#")[:6]
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def hexs(rgb):
    return "%02x%02x%02x" % tuple(max(0, min(255, int(round(c * 255.0)))) for c in rgb)


def mat(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    base = name.split("@")[0]
    if base in PALETTE:
        rgb, metal, rough = PALETTE[base]
    elif "__" in base:
        rgb, metal, rough = _hex(base.split("__")[1]), 0.0, 0.8
    elif "_" in base and len(base.rsplit("_", 1)[1]) == 6 and all(c in "0123456789abcdef" for c in base.rsplit("_", 1)[1]):
        rgb = _hex(base.rsplit("_", 1)[1])
        metal, rough = 0.0, (0.05 if base.startswith("glass") else 0.35)
    elif base.startswith("lib_"):
        rgb, metal, rough = PALETTE.get(base, ((0.4, 0.35, 0.3), 0.0, 0.8))
    else:
        rgb, metal, rough = (0.5, 0.5, 0.5), 0.0, 0.7
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def enamel(rgb):
    return "enamel_" + (rgb if isinstance(rgb, str) else hexs(rgb))


def glass(rgb):
    return "glass_" + (rgb if isinstance(rgb, str) else hexs(rgb))


def paint(rgb):
    return "paint_" + (rgb if isinstance(rgb, str) else hexs(rgb))


# ================================================================== scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def rot_matrix(rot_deg):
    """Godot's euler (degrees, applied Z then X then Y: Node3D.rotation_degrees) as a 4x4."""
    if rot_deg is None:
        return Matrix.Identity(4)
    e = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), "ZXY")
    return e.to_matrix().to_4x4()


def V(p):
    return Vector((float(p[0]), float(p[1]), float(p[2])))


def _hash01(*vals):
    return (zlib.crc32(repr(vals).encode()) % 100000) / 100000.0


class Part:
    """One mesh node. Primitives are added in Godot's frame; build() converts and links it."""

    def __init__(self, name, pivot=(0.0, 0.0, 0.0), shadows=True):
        self.name = name
        self.pivot = V(pivot)
        self.bm = bmesh.new()
        self.uvr = self.bm.faces.layers.int.new("uvr")
        self.mats = []
        self.shadows = shadows

    def mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add(self, tmp, m, smooth=False, uvrot=False):
        idx = self.mi(m)
        lay = tmp.faces.layers.int.get("uvr") or tmp.faces.layers.int.new("uvr")
        for f in tmp.faces:
            f.material_index = idx
            f.smooth = smooth
            f[lay] = 1 if uvrot else 0
        me = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        self.uvr = self.bm.faces.layers.int.get("uvr")

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def build(self, uv_seed=None):
        bm = self.bm
        bm.normal_update()
        uvl = bm.loops.layers.uv.new("UVMap")
        seed = uv_seed if uv_seed is not None else self.name
        ou = _hash01(seed, "u") * 4.0
        ov = _hash01(seed, "v") * 4.0
        uvr = bm.faces.layers.int.get("uvr")
        for f in bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda k: abs(n[k]))
            rot = uvr is not None and f[uvr] == 1
            for lp in f.loops:
                p = lp.vert.co
                if ax == 0:
                    u, v = (-p.z if n.x > 0 else p.z), p.y
                elif ax == 1:
                    u, v = p.x, (p.z if n.y > 0 else -p.z)
                else:
                    u, v = (p.x if n.z > 0 else -p.x), p.y
                if rot:
                    u, v = v, u
                lp[uvl].uv = (u + ou, v + ov)
        # sharp edges by angle
        for e in bm.edges:
            if len(e.link_faces) == 2:
                a = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)
                e.smooth = math.degrees(a) < SHARP_DEG
            else:
                e.smooth = False
        bm.transform(G2B)
        bmesh.ops.translate(bm, vec=-(G2B @ self.pivot), verts=bm.verts)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        ob = bpy.data.objects.new(self.name, me)
        ob.location = G2B @ self.pivot
        bpy.context.scene.collection.objects.link(ob)
        return ob


def anchor(name, pos):
    ob = bpy.data.objects.new(name, None)
    ob.location = G2B @ V(pos)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ================================================================== primitives (Godot frame)

def _bevel(tmp, w, segs=1, min_angle=30.0):
    if w <= 0.0:
        return
    edges = []
    for e in tmp.edges:
        if len(e.link_faces) == 2 and math.degrees(e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)) > min_angle:
            edges.append(e)
    if edges:
        bmesh.ops.bevel(tmp, geom=edges, offset=w, offset_type="OFFSET", segments=segs, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


def box(part, a, b, m, bevel=0.008, uvrot=False, segs=1):
    a, b = V(a), V(b)
    lo = Vector((min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)))
    hi = Vector((max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)))
    return obox(part, (lo + hi) * 0.5, hi - lo, m, None, bevel, uvrot, segs)


def obox(part, c, size, m, rot=None, bevel=0.008, uvrot=False, segs=1):
    s = V(size)
    s = Vector((max(s.x, 0.0005), max(s.y, 0.0005), max(s.z, 0.0005)))
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=s, verts=tmp.verts)
    tmp.normal_update()
    _bevel(tmp, min(bevel, 0.45 * min(s.x, s.y, s.z)), segs)
    xf = Matrix.Translation(V(c)) @ rot_matrix(rot)
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, False, uvrot)


_AXIS = {"y": None, "x": (0.0, 0.0, 90.0), "z": (90.0, 0.0, 0.0)}


def _axis_rot(axis, rot):
    if rot is not None:
        return rot
    return _AXIS.get(axis)


def cyl(part, c, r, h, m, axis="y", rot=None, segs=20, r2=None, bevel=0.0, caps=True, smooth=True):
    """A cylinder (or a cone with r2) along local Y, centred on c."""
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=segs, radius1=r, radius2=(r if r2 is None else r2),
                          depth=h, matrix=Matrix.Rotation(math.radians(-90.0), 4, "X"))
    tmp.normal_update()
    _bevel(tmp, min(bevel, 0.4 * min(r, h)), 1, 40.0)
    xf = Matrix.Translation(V(c)) @ rot_matrix(_axis_rot(axis, rot))
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, smooth)


def lathe(part, prof, m, c=(0, 0, 0), segs=24, sx=1.0, sz=1.0, rot=None, smooth=True, cap_lo=True, cap_hi=True, arc=360.0):
    """Revolves the profile [(radius, y), ...] (bottom to top) about local Y. sx/sz squash it to an ellipse."""
    tmp = bmesh.new()
    rings = []
    full = abs(arc - 360.0) < 0.01
    nseg = segs if full else segs + 1
    for (r, y) in prof:
        if r <= 1e-5:
            rings.append([tmp.verts.new((0.0, y, 0.0))])
            continue
        ring = []
        for k in range(nseg):
            a = math.radians(arc) * k / segs
            ring.append(tmp.verts.new((math.sin(a) * r * sx, y, -math.cos(a) * r * sz)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        n = segs
        for k in range(n):
            k1 = (k + 1) % nseg if full else k + 1
            if len(r0) == 1 and len(r1) == 1:
                continue
            if len(r0) == 1:
                tmp.faces.new((r0[0], r1[k1], r1[k]))
            elif len(r1) == 1:
                tmp.faces.new((r0[k], r0[k1], r1[0]))
            else:
                tmp.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    if full and cap_lo and len(rings[0]) > 2:
        tmp.faces.new(list(reversed(rings[0])))
    if full and cap_hi and len(rings[-1]) > 2:
        tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    xf = Matrix.Translation(V(c)) @ rot_matrix(rot)
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, smooth)


def sphere(part, c, size, m, segs=16, rings=8, rot=None, smooth=True):
    s = V(size) if not isinstance(size, (int, float)) else Vector((size, size, size))
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=rings, radius=0.5)
    bmesh.ops.scale(tmp, vec=s, verts=tmp.verts)
    xf = Matrix.Translation(V(c)) @ rot_matrix(rot)
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, smooth)


def dot(part, c, r, m, segs=6):
    sphere(part, c, 2.0 * r, m, segs, max(3, segs // 2))


def torus(part, c, R, r, m, axis="y", rot=None, segs=24, rsegs=8, smooth=True, arc=360.0):
    """A ring lying in the plane perpendicular to local Y (axis "z": facing the viewer, like a porthole rim)."""
    tmp = bmesh.new()
    full = abs(arc - 360.0) < 0.01
    nseg = segs if full else segs + 1
    rings = []
    for k in range(nseg):
        a = math.radians(arc) * k / segs
        cx, cz = math.cos(a), math.sin(a)
        ring = []
        for j in range(rsegs):
            b = math.tau * j / rsegs
            rr = R + r * math.cos(b)
            ring.append(tmp.verts.new((cx * rr, r * math.sin(b), cz * rr)))
        rings.append(ring)
    for k in range(segs):
        k1 = (k + 1) % nseg if full else k + 1
        for j in range(rsegs):
            j1 = (j + 1) % rsegs
            tmp.faces.new((rings[k][j], rings[k1][j], rings[k1][j1], rings[k][j1]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    xf = Matrix.Translation(V(c)) @ rot_matrix(_axis_rot(axis, rot))
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, smooth)


def tube(part, pts, r, m, segs=8, caps=True, smooth=True):
    """A round tube swept through the points (pipes, cables, neon, rope, wire)."""
    P = [V(p) for p in pts]
    if len(P) < 2:
        return
    tmp = bmesh.new()
    rings = []
    prev_n = None
    for i, p in enumerate(P):
        if i == 0:
            t = (P[1] - P[0]).normalized()
        elif i == len(P) - 1:
            t = (P[-1] - P[-2]).normalized()
        else:
            t = ((P[i] - P[i - 1]).normalized() + (P[i + 1] - P[i]).normalized())
            t = t.normalized() if t.length > 1e-6 else (P[i + 1] - P[i]).normalized()
        if prev_n is None:
            up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            n1 = t.cross(up).normalized()
        else:
            n1 = (prev_n - t * prev_n.dot(t))
            n1 = n1.normalized() if n1.length > 1e-6 else t.cross(Vector((0, 1, 0))).normalized()
        prev_n = n1
        n2 = t.cross(n1).normalized()
        ring = []
        for k in range(segs):
            a = math.tau * k / segs
            ring.append(tmp.verts.new(p + (n1 * math.cos(a) + n2 * math.sin(a)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            k1 = (k + 1) % segs
            tmp.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    if caps:
        tmp.faces.new(list(reversed(rings[0])))
        tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    part.add(tmp, m, smooth)


def strut(part, a, b, t, m, round_=True, segs=8):
    """A bar from a to b (round, or square with side t)."""
    a, b = V(a), V(b)
    if round_:
        tube(part, [a, b], t * 0.5, m, segs, True, True)
        return
    d = b - a
    length = d.length
    if length < 1e-5:
        return
    q = Vector((0, 1, 0)).rotation_difference(d.normalized())
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=(t, length, t), verts=tmp.verts)
    tmp.normal_update()
    _bevel(tmp, min(0.004, t * 0.3))
    xf = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, False)


def rivets(part, a, b, n, r=0.014, m="mats_steel"):
    a, b = V(a), V(b)
    for i in range(n):
        t = 0.5 if n == 1 else i / (n - 1)
        dot(part, a.lerp(b, t), r, m, 4)


def prism(part, pts2d, z0, z1, m, rot=None, c=(0, 0, 0), bevel=0.0):
    """An extruded flat shape: pts2d [(x, y), ...] counter-clockwise in the XY plane, from z0 to z1 (cut-outs, tin signs,
    chevrons, starbursts, lightning bolts)."""
    tmp = bmesh.new()
    lo = [tmp.verts.new((x, y, z0)) for (x, y) in pts2d]
    hi = [tmp.verts.new((x, y, z1)) for (x, y) in pts2d]
    tmp.faces.new(list(reversed(lo)))
    tmp.faces.new(hi)
    n = len(pts2d)
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    tmp.normal_update()
    _bevel(tmp, bevel)
    xf = Matrix.Translation(V(c)) @ rot_matrix(rot)
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    part.add(tmp, m, False)


def jit(i, k, amp):
    """Deterministic jitter in [-amp, amp] (the old builders' _j)."""
    return (math.fmod(abs(math.sin(i * 12.9898 + k * 78.233) * 43758.5453), 1.0) - 0.5) * 2.0 * amp


# ================================================================== export and paperwork

def export(folder, title, desc, script_name):
    out_dir = os.path.join(OUT_ROOT, folder)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "model.glb")
    tris = 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            ob.data.calc_loop_triangles()
            tris += len(ob.data.loop_triangles)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=False,
        export_skins=False,
        export_morph=False,
        use_selection=False,
    )
    _paperwork(out_dir, title, desc, script_name)
    print("[world] %s: %d tris -> %s" % (folder, tris, os.path.relpath(path, ROOT)))
    return tris


def _paperwork(out_dir, title, desc, script_name):
    lic = (
        "Ours (original work)\n\n"
        "This model was made for GRAVELIGHT by the project itself: it is generated by a Blender script in this\n"
        "repository (tools_src/blender/world/%s), from primitives only, with no third-party mesh, texture or\n"
        "reference scan. It may be used, changed and shipped with the game like the rest of the project's own code.\n"
    ) % script_name
    src = (
        "Title: %s\n"
        "Author: GRAVELIGHT (generated by tools_src/blender/world/%s)\n"
        "Source: tools_src/blender/world/%s (headless Blender 5.1: blender -b -P <script>)\n"
        "License: Ours (original work)\n"
        "Credit line: none required (original work)\n"
        "Format: GLB, metres, +Y up, front -Z; material slots named for MaterialLibrary / Mats keys (gravelight/world/world_art.gd)\n"
        "Downloaded: generated %s by Claude (T-094, UPDATE_05 section 5)\n"
        "Files used: model.glb\n"
        "Notes: %s\n"
    ) % (title, script_name, script_name, datetime.date.today().isoformat(), desc)
    with open(os.path.join(out_dir, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lic)
    with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(src)


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
