"""GRAVELIGHT ONE's Blender pipeline: shared mesh helpers (UPDATE 12 section 5, DECISIONS T-211).

Everything here works on bmesh data in GODOT's frame (metres, +Y up, the nose toward -Z, +X starboard) and converts
to Blender (x, -z, y) only when an object is made, so the GLB hands Godot back exactly these numbers (the glTF
exporter's +Y-up conversion undoes G2B).

A GMesh is one bmesh plus its material slot names. Faces carry:
  "piece"   int   which crash piece a face belongs to (0 = the forward fuselage; set by build_c47.classify)
  "keepuv"  int   1 = the face's UVs are authored (decals, an imported source): to_object() leaves them alone;
                  0 = box-mapped in metres (the stand-in's primitives, like tools_src/blender/world/wo_lib.py)
and every loop a colour "Col" (RGBA): R scorch 0..1, G soot / dirt 0..1, B snow allowance 0..1, A 1. The game's
c47_skin.gdshader reads it (gravelight/world/c47/).
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

G2B = Matrix.Rotation(math.radians(90.0), 4, "X")
B2G = G2B.inverted()
SHARP_DEG = 38.0


def V(p):
    return Vector((float(p[0]), float(p[1]), float(p[2])))


def rot_matrix(rot_deg):
    """Godot's euler (degrees; Node3D.rotation_degrees, YXZ) as a 4x4 in Godot's frame."""
    if rot_deg is None:
        return Matrix.Identity(4)
    e = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), "ZXY")
    return e.to_matrix().to_4x4()


def axis_angle(axis, deg, pivot=(0, 0, 0)):
    p = V(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, V(axis).normalized()) @ Matrix.Translation(-p)


def smoothstep(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def hash01(*vals):
    h = 2166136261
    for c in repr(vals).encode():
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
    return (h % 100000) / 100000.0


def vnoise(p, scale=1.0, seed=0):
    """Cheap smooth 3D value noise in 0..1 (deterministic)."""
    x, y, z = p[0] / scale, p[1] / scale, p[2] / scale
    ix, iy, iz = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - ix, y - iy, z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)

    def h(a, b, c):
        return hash01(a, b, c, seed)
    x00 = h(ix, iy, iz) * (1 - fx) + h(ix + 1, iy, iz) * fx
    x10 = h(ix, iy + 1, iz) * (1 - fx) + h(ix + 1, iy + 1, iz) * fx
    x01 = h(ix, iy, iz + 1) * (1 - fx) + h(ix + 1, iy, iz + 1) * fx
    x11 = h(ix, iy + 1, iz + 1) * (1 - fx) + h(ix + 1, iy + 1, iz + 1) * fx
    return (x00 * (1 - fy) + x10 * fy) * (1 - fz) + (x01 * (1 - fy) + x11 * fy) * fz


# ================================================================== materials (named slots; the game maps them)

# slot -> (base colour, metallic, roughness, alpha) for any glTF viewer; the game replaces c47_* with its own shader
SLOTS = {
    "c47_od": ((0.25, 0.26, 0.17), 0.0, 0.75, 1.0),        # olive drab (ANA 613), weathered
    "c47_ng": ((0.36, 0.37, 0.37), 0.0, 0.7, 1.0),         # neutral grey (ANA 603)
    "c47_metal": ((0.55, 0.56, 0.57), 1.0, 0.45, 1.0),     # bare aluminium: torn skin, stringers, frames' edges
    "c47_int": ((0.32, 0.36, 0.27), 0.0, 0.7, 1.0),        # the cabin's zinc-chromate green-grey
    "c47_black": ((0.04, 0.04, 0.04), 0.0, 0.55, 1.0),     # prop blades, anti-glare panel, the panel
    "c47_yellow": ((0.6, 0.48, 0.12), 0.0, 0.5, 1.0),      # prop tips
    "c47_exhaust": ((0.22, 0.14, 0.1), 0.8, 0.6, 1.0),     # exhaust stacks, the engine's cylinders
    "c47_rubber": ((0.03, 0.03, 0.03), 0.0, 0.85, 1.0),
    "c47_glass": ((0.12, 0.14, 0.16), 0.0, 0.05, 0.35),
    "c47_decal": ((1.0, 1.0, 1.0), 0.0, 0.7, 1.0),         # the markings atlas (alpha clip)
    "c47_frost": ((0.86, 0.9, 0.95), 0.0, 0.6, 0.6),       # the windows' frost (atlas, alpha)
    "c47_light_red": ((1.0, 0.1, 0.05), 0.0, 0.3, 1.0),    # navigation lights (the game makes them glow)
    "c47_light_green": ((0.1, 1.0, 0.3), 0.0, 0.3, 1.0),
    "c47_light_white": ((1.0, 0.95, 0.85), 0.0, 0.3, 1.0),
    "c47_char": ((0.04, 0.035, 0.03), 0.0, 0.95, 1.0),
    "mats_snow": ((0.82, 0.84, 0.9), 0.0, 0.85, 1.0),
    "mats_dirt": ((0.18, 0.15, 0.12), 0.0, 0.95, 1.0),
    "mats_rubber": ((0.04, 0.04, 0.04), 0.0, 0.7, 1.0),
    "mats_char": ((0.05, 0.045, 0.04), 0.0, 0.9, 1.0),
    "mats_paper": ((0.85, 0.8, 0.68), 0.0, 0.9, 1.0),
    "mats_olive_drab": ((0.27, 0.29, 0.18), 0.0, 0.8, 1.0),
    "mats_tarp": ((0.3, 0.32, 0.22), 0.0, 0.9, 1.0),
    "mats_steel": ((0.45, 0.46, 0.48), 1.0, 0.35, 1.0),
    "mats_brass": ((0.62, 0.48, 0.22), 1.0, 0.35, 1.0),
    "mats_gauge_face": ((0.85, 0.8, 0.66), 0.0, 0.4, 1.0),
    "lib_canvas": ((0.48, 0.47, 0.40), 0.0, 0.95, 1.0),
    "lib_leather": ((0.26, 0.15, 0.08), 0.0, 0.6, 1.0),
    "lib_floorboards": ((0.30, 0.20, 0.12), 0.0, 0.8, 1.0),
    "lib_wool": ((0.30, 0.29, 0.28), 0.0, 0.95, 1.0),
    "lib_iron": ((0.20, 0.18, 0.17), 0.85, 0.6, 1.0),
    "linen_chute": ((0.78, 0.76, 0.68), 0.0, 0.9, 1.0),    # the parachute silk over the co-pilot
}

DECAL_IMAGE = None   # set by build_c47 to the atlas path


def material(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    rgb, metal, rough, alpha = SLOTS.get(name, ((0.5, 0.5, 0.5), 0.0, 0.7, 1.0))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    if name in ("c47_decal", "c47_frost") and DECAL_IMAGE:
        img = bpy.data.images.get("c47_decals") or bpy.data.images.load(DECAL_IMAGE)
        img.name = "c47_decals"
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.blend_method = "CLIP" if name == "c47_decal" else "BLEND"
        except Exception:
            pass
        try:
            m.surface_render_method = "DITHERED" if name == "c47_decal" else "BLENDED"
        except Exception:
            pass
    elif name in ("c47_od", "c47_ng", "c47_int", "c47_metal"):
        # the vertex colour in a viewer / the previews: R scorch -> char, G soot darkens (the game's shader does more)
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["A"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        mix.inputs["B"].default_value = (0.03, 0.025, 0.02, 1.0)
        nt.links.new(sep.outputs["Red"], mix.inputs["Factor"])
        dark = nt.nodes.new("ShaderNodeMix")
        dark.data_type = "RGBA"
        dark.blend_type = "MULTIPLY"
        dark.inputs["B"].default_value = (0.45, 0.42, 0.4, 1.0)
        nt.links.new(sep.outputs["Green"], dark.inputs["Factor"])
        nt.links.new(mix.outputs["Result"], dark.inputs["A"])
        nt.links.new(dark.outputs["Result"], bsdf.inputs["Base Color"])
    elif name.startswith("c47_light"):
        bsdf.inputs["Emission Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], alpha)
    return m


# ================================================================== the mesh container

class GMesh:
    def __init__(self, name="mesh"):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self._layers()

    def _layers(self):
        bm = self.bm
        self.piece = bm.faces.layers.int.get("piece") or bm.faces.layers.int.new("piece")
        self.keepuv = bm.faces.layers.int.get("keepuv") or bm.faces.layers.int.new("keepuv")
        self.uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
        self.col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")

    def mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def copy(self, name=None):
        g = GMesh(name or self.name)
        g.bm.free()
        g.bm = self.bm.copy()
        g.mats = list(self.mats)
        g._layers()
        return g

    def add(self, tmp, m, smooth=False, piece=0, color=(0.0, 0.0, 1.0, 1.0), keepuv=False):
        """Merges a temporary bmesh (Godot frame) in with material m. Keeps tmp's UVs when keepuv."""
        idx = self.mi(m)
        lay_uv = tmp.loops.layers.uv.get("UVMap")
        for f in tmp.faces:
            f.material_index = idx
            f.smooth = smooth
        me = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(me)
        tmp.free()
        n0 = len(self.bm.faces)
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        self._layers()
        self.bm.faces.ensure_lookup_table()
        for i in range(n0, len(self.bm.faces)):
            f = self.bm.faces[i]
            f[self.piece] = piece
            f[self.keepuv] = 1 if (keepuv and lay_uv is not None) else 0
            for lp in f.loops:
                lp[self.col] = color

    def merge(self, other):
        """Appends another GMesh (its material slots remapped)."""
        remap = [self.mi(m) for m in other.mats]
        me = bpy.data.meshes.new("_tmp")
        other.bm.to_mesh(me)
        n0 = len(self.bm.faces)
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        self._layers()
        self.bm.faces.ensure_lookup_table()
        for i in range(n0, len(self.bm.faces)):
            f = self.bm.faces[i]
            f.material_index = remap[f.material_index] if f.material_index < len(remap) else 0

    def transform(self, mat, faces=None):
        verts = self.bm.verts if faces is None else list({v for f in faces for v in f.verts})
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def keep_faces(self, pred):
        """Deletes every face pred(face) is False for (and the loose geometry left behind)."""
        dead = [f for f in self.bm.faces if not pred(f)]
        bmesh.ops.delete(self.bm, geom=dead, context="FACES")
        loose = [v for v in self.bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(self.bm, geom=loose, context="VERTS")

    def to_object(self, name, collection=None, pivot=(0, 0, 0)):
        bm = self.bm.copy()
        uvl = bm.loops.layers.uv.get("UVMap")
        kl = bm.faces.layers.int.get("keepuv")
        bm.normal_update()
        ou = hash01(name, "u") * 4.0
        ov = hash01(name, "v") * 4.0
        for f in bm.faces:
            if kl is not None and f[kl] == 1:
                continue
            n = f.normal
            ax = max(range(3), key=lambda k: abs(n[k]))
            for lp in f.loops:
                p = lp.vert.co
                if ax == 0:
                    u, v = (-p.z if n.x > 0 else p.z), p.y
                elif ax == 1:
                    u, v = p.x, (p.z if n.y > 0 else -p.z)
                else:
                    u, v = (p.x if n.z > 0 else -p.x), p.y
                lp[uvl].uv = (u + ou, v + ov)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = math.degrees(e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)) < SHARP_DEG
            else:
                e.smooth = False
        pv = V(pivot)
        bmesh.ops.translate(bm, vec=-pv, verts=bm.verts)
        bm.transform(G2B)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(material(m))
        # the exporter writes the active colour attribute as COLOR_0
        if "Col" in me.color_attributes:
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = me.color_attributes.find("Col")
        ob = bpy.data.objects.new(name, me)
        ob.location = G2B @ pv
        (collection or bpy.context.scene.collection).objects.link(ob)
        return ob


def empty(name, pos, collection=None, parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.location = G2B @ V(pos)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if parent is not None:
        ob.parent = parent
        ob.location = G2B @ V(pos) - parent.location
    return ob


# ================================================================== primitives (Godot frame, into a GMesh)

def _bevel(tmp, w, segs=1, min_angle=30.0):
    if w <= 0.0:
        return
    edges = [e for e in tmp.edges if len(e.link_faces) == 2 and
             math.degrees(e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)) > min_angle]
    if edges:
        bmesh.ops.bevel(tmp, geom=edges, offset=w, offset_type="OFFSET", segments=segs, profile=0.5, affect="EDGES",
                        clamp_overlap=True)


def obox(g, c, size, m, rot=None, bevel=0.0, **kw):
    s = V(size)
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector((max(s.x, 1e-4), max(s.y, 1e-4), max(s.z, 1e-4))), verts=tmp.verts)
    tmp.normal_update()
    _bevel(tmp, min(bevel, 0.45 * min(s.x, s.y, s.z)))
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(V(c)) @ rot_matrix(rot), verts=tmp.verts)
    g.add(tmp, m, **kw)


def obox_m(g, xf, size, m, **kw):
    """A box of `size` placed by the 4x4 `xf` (Godot frame)."""
    s = V(size)
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector((max(s.x, 1e-4), max(s.y, 1e-4), max(s.z, 1e-4))), verts=tmp.verts)
    bmesh.ops.transform(tmp, matrix=xf, verts=tmp.verts)
    g.add(tmp, m, **kw)


def box(g, a, b, m, bevel=0.0, **kw):
    a, b = V(a), V(b)
    lo = Vector((min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)))
    hi = Vector((max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)))
    obox(g, (lo + hi) * 0.5, hi - lo, m, None, bevel, **kw)


_AXIS = {"y": None, "x": (0.0, 0.0, 90.0), "z": (90.0, 0.0, 0.0)}


def cyl(g, c, r, h, m, axis="y", rot=None, segs=16, r2=None, caps=True, smooth=True, **kw):
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=segs, radius1=r, radius2=(r if r2 is None else r2),
                          depth=h, matrix=Matrix.Rotation(math.radians(-90.0), 4, "X"))
    rr = rot if rot is not None else _AXIS.get(axis)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(V(c)) @ rot_matrix(rr), verts=tmp.verts)
    g.add(tmp, m, smooth, **kw)


def sphere(g, c, size, m, segs=12, rings=6, rot=None, smooth=True, **kw):
    s = V(size) if not isinstance(size, (int, float)) else Vector((size, size, size))
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=rings, radius=0.5)
    bmesh.ops.scale(tmp, vec=s, verts=tmp.verts)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(V(c)) @ rot_matrix(rot), verts=tmp.verts)
    g.add(tmp, m, smooth, **kw)


def tube(g, pts, r, m, segs=6, caps=True, smooth=True, **kw):
    P = [V(p) for p in pts]
    if len(P) < 2:
        return
    tmp = bmesh.new()
    rings = []
    prev = None
    for i, p in enumerate(P):
        if i == 0:
            t = (P[1] - P[0]).normalized()
        elif i == len(P) - 1:
            t = (P[-1] - P[-2]).normalized()
        else:
            t = ((P[i] - P[i - 1]).normalized() + (P[i + 1] - P[i]).normalized())
            t = t.normalized() if t.length > 1e-6 else (P[i + 1] - P[i]).normalized()
        if prev is None:
            up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            n1 = t.cross(up).normalized()
        else:
            n1 = prev - t * prev.dot(t)
            n1 = n1.normalized() if n1.length > 1e-6 else t.cross(Vector((0, 1, 0))).normalized()
        prev = n1
        n2 = t.cross(n1).normalized()
        rings.append([tmp.verts.new(p + (n1 * math.cos(math.tau * k / segs) + n2 * math.sin(math.tau * k / segs)) * r)
                      for k in range(segs)])
    for i in range(len(rings) - 1):
        for k in range(segs):
            k1 = (k + 1) % segs
            tmp.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    if caps:
        tmp.faces.new(list(reversed(rings[0])))
        tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    g.add(tmp, m, smooth, **kw)


def strut(g, a, b, t, m, **kw):
    tube(g, [a, b], t * 0.5, m, 6, True, False, **kw)


def lathe(g, prof, m, c=(0, 0, 0), segs=20, rot=None, smooth=True, sx=1.0, sy=1.0, caps=(True, True), **kw):
    """Revolves [(radius, z), ...] about the local Z axis (front to back); sx/sy squash the section."""
    tmp = bmesh.new()
    rings = []
    for (r, z) in prof:
        if r <= 1e-5:
            rings.append([tmp.verts.new((0.0, 0.0, z))])
            continue
        rings.append([tmp.verts.new((math.cos(math.tau * k / segs) * r * sx, math.sin(math.tau * k / segs) * r * sy, z))
                      for k in range(segs)])
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(segs):
            k1 = (k + 1) % segs
            if len(r0) == 1 and len(r1) == 1:
                continue
            if len(r0) == 1:
                tmp.faces.new((r0[0], r1[k1], r1[k]))
            elif len(r1) == 1:
                tmp.faces.new((r0[k], r0[k1], r1[0]))
            else:
                tmp.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    if caps[0] and len(rings[0]) > 2:
        tmp.faces.new(list(reversed(rings[0])))
    if caps[1] and len(rings[-1]) > 2:
        tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(V(c)) @ rot_matrix(rot), verts=tmp.verts)
    g.add(tmp, m, smooth, **kw)


def quad(g, pts, m, uvs=None, **kw):
    """One quad (or polygon) through the points; uvs (same count) make it keep its UVs (decals)."""
    tmp = bmesh.new()
    vs = [tmp.verts.new(V(p)) for p in pts]
    f = tmp.faces.new(vs)
    if uvs is not None:
        lay = tmp.loops.layers.uv.new("UVMap")
        for lp, uv in zip(f.loops, uvs):
            lp[lay].uv = uv
    g.add(tmp, m, keepuv=uvs is not None, **kw)


def loft(g, rings, m_of_face=None, m="c47_od", closed=True, smooth=True, cap_start=False, cap_end=False, **kw):
    """Skins a list of rings (each a list of Vector, the same count) into quads. m_of_face(centre, normal) picks the
    material per face (paint split, glazing)."""
    tmp = bmesh.new()
    vr = [[tmp.verts.new(V(p)) for p in ring] for ring in rings]
    n = len(rings[0])
    faces = []
    for i in range(len(vr) - 1):
        for k in range(n if closed else n - 1):
            k1 = (k + 1) % n
            a, b, c, d = vr[i][k], vr[i][k1], vr[i + 1][k1], vr[i + 1][k]
            if a.co == b.co and c.co == d.co:
                continue
            try:
                faces.append(tmp.faces.new((a, b, c, d)))
            except ValueError:
                pass
    if cap_start:
        try:
            tmp.faces.new(list(reversed(vr[0])))
        except ValueError:
            pass
    if cap_end:
        try:
            tmp.faces.new(vr[-1])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts, dist=1e-5)
    if m_of_face is None:
        g.add(tmp, m, smooth, **kw)
        return
    # split by material: one add per material
    tmp.normal_update()
    groups = {}
    for f in tmp.faces:
        groups.setdefault(m_of_face(f.calc_center_median(), f.normal), []).append(f.index)
    for mname, idxs in groups.items():
        t2 = tmp.copy()
        keep = set(idxs)
        t2.faces.ensure_lookup_table()
        bmesh.ops.delete(t2, geom=[f for f in t2.faces if f.index not in keep], context="FACES")
        g.add(t2, mname, smooth, **kw)
    tmp.free()


def catmull(pts, n_out, closed=True):
    """Resamples a closed polyline (Vector2 list) to n_out points evenly by arc length through a Catmull-Rom spline."""
    P = list(pts)
    dense = []
    N = len(P)
    for i in range(N if closed else N - 1):
        p0, p1, p2, p3 = P[(i - 1) % N], P[i], P[(i + 1) % N], P[(i + 2) % N]
        for s in range(16):
            t = s / 16.0
            t2, t3 = t * t, t * t * t
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    L = [0.0]
    for i in range(1, len(dense) + (1 if closed else 0)):
        L.append(L[-1] + (dense[i % len(dense)] - dense[i - 1]).length)
    total = L[-1]
    out = []
    j = 0
    for k in range(n_out):
        s = total * k / n_out
        while j < len(L) - 2 and L[j + 1] < s:
            j += 1
        a, b = dense[j % len(dense)], dense[(j + 1) % len(dense)]
        seg = max(L[j + 1] - L[j], 1e-9)
        out.append(a.lerp(b, (s - L[j]) / seg))
    return out


def bvh(g):
    return BVHTree.FromBMesh(g.bm)


def project_decal(g, tree, center, normal, up, size, cell, m="c47_decal", grid=5, offset=0.007, **kw):
    """A decal quad (grid x grid) laid on the surface of the mesh in `tree` around `center`, facing `normal`, with
    the atlas cell [u0, v0, u1, v1] (top-left origin) mapped across `size` (w, h)."""
    n = V(normal).normalized()
    upv = V(up)
    upv = (upv - n * upv.dot(n)).normalized()
    right = upv.cross(n).normalized()
    hit = tree.ray_cast(V(center) + n * 1.5, -n, 3.0)
    if hit[0] is None:
        return False
    base = hit[0]
    w, h = size
    u0, v0, u1, v1 = cell
    tmp = bmesh.new()
    lay = tmp.loops.layers.uv.new("UVMap")
    vs = {}
    for i in range(grid + 1):
        for j in range(grid + 1):
            s, t = i / grid, j / grid
            p = base + right * (s - 0.5) * w + upv * (t - 0.5) * h
            hh = tree.ray_cast(p + n * 0.8, -n, 1.6)
            if hh[0] is not None:
                p = hh[0] + hh[1].normalized() * offset
            else:
                p = p + n * offset
            vs[(i, j)] = (tmp.verts.new(p), (u0 + (u1 - u0) * s, 1.0 - (v0 + (v1 - v0) * (1.0 - t))))
    for i in range(grid):
        for j in range(grid):
            a, b, c, d = vs[(i, j)], vs[(i + 1, j)], vs[(i + 1, j + 1)], vs[(i, j + 1)]
            f = tmp.faces.new((a[0], b[0], c[0], d[0]))
            for lp, src in zip(f.loops, (a, b, c, d)):
                lp[lay].uv = src[1]
    tmp.normal_update()
    # face the same way as `normal`
    for f in tmp.faces:
        if f.normal.dot(n) < 0:
            f.normal_flip()
    g.add(tmp, m, True, keepuv=True, **kw)
    return True


def rng(seed):
    return random.Random(seed)
