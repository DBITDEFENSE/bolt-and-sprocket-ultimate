"""Shared toolkit for GRAVELIGHT's wonder-weapon models (UPDATE_05 section 2, T-090).

Every model script in this folder (ashlight.py, totenglocke.py, elmsfeuer.py, gramophone.py) does

    import wonder_lib as W
    m = W.Model("ashlight", tex=2048)
    m.lathe("Body", "brass", [(r, z), ...], ...)      # real modelling: lathes, bevelled boxes and prisms,
    m.box(...); m.prism(...); m.sweep(...)              # swept wires and coils, rivets, raised lettering
    m.finish(out_dir)                                   # UVs, bakes, PBR set, GLB, report, turntable

and is run headless:  blender -b --factory-startup -P tools_src/blender/wonder/<id>.py -- --out assets/ours/wonder/<id>

Frame: everything is authored in the GAME's frame (Godot: barrel along -Z, +Y up, origin at the right-hand grip,
metres). Blender is Z-up, so at export every object gets the rotation (x, y, z) -> (x, -z, y) applied, and the glTF
exporter's own Z-up -> Y-up conversion brings the vertices back to exactly the coordinates written here.

Pipeline in finish():
  1. modifiers applied (bevels, weighted normals), parts joined per animation part name ("Body", "Mag", "Crank"...);
  2. UVs: smart-projected per object, islands averaged to one texel density and packed into ONE atlas for every
     baked surface of the weapon;
  3. bakes (Cycles, CPU): ambient occlusion and curvature (a Bevel-node edge mask) first, then the procedural
     "paint" (per-family node recipes below: brass, bronze, copper, painted steel, wood, leather, porcelain...,
     each driven by the baked AO / curvature for edge wear, cavity grime and patina, plus object-space noise) into
     albedo, roughness and metallic, and the paint's bump into a tangent-space normal map (OpenGL +Y, Godot's);
  4. ORM packed (R occlusion, G roughness, B metallic: glTF's packing), PNGs written to <out>/textures/;
  5. surfaces that are not baked keep their own named material ("glass", "fluid", "glow", "arc", "runes", "halo",
     "orb"...): the game replaces those by name (gravelight/weapons/wonder_look.gd);
  6. GLB written with external textures (textures/<id>_albedo.png, _normal.png, _orm.png), a JSON report (nodes,
     tris, bounds, materials) next to this script in reports/<id>.json, and optionally an 8-angle EEVEE turntable.
"""
import json
import math
import os
import random
import shutil
import struct
import sys
import tempfile
import time

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPORTS = os.path.join(HERE, "reports")

# ---------------------------------------------------------------------------------------------- arguments


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"out": None, "turntable": None, "tex": None, "fast": False, "samples": None}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--out":
            out["out"] = a[i + 1]; i += 1
        elif k == "--turntable":
            out["turntable"] = a[i + 1]; i += 1
        elif k == "--tex":
            out["tex"] = int(a[i + 1]); i += 1
        elif k == "--fast":
            out["fast"] = True
        i += 1
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0


# ---------------------------------------------------------------------------------------------- geometry helpers


def V(*a):
    if len(a) == 1:
        return Vector(a[0])
    return Vector(a)


def axis_frame(axis):
    """(u, v, w) unit vectors: w along the axis, u/v span the cross-section (right-handed)."""
    if axis == "z":
        return Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    if axis == "x":
        return Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
    if axis == "y":
        return Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))
    w = Vector(axis).normalized()
    u = w.cross(Vector((0, 1, 0)) if abs(w.y) < 0.95 else Vector((1, 0, 0))).normalized()
    v = w.cross(u).normalized()
    return u, v, w


def catmull(points, per=6, closed=False):
    """Smooth a control polyline (Catmull-Rom), `per` samples per span."""
    pts = [Vector(p) for p in points]
    if len(pts) < 3:
        return pts
    out = []
    n = len(pts)
    spans = n if closed else n - 1
    for i in range(spans):
        p0 = pts[(i - 1) % n] if (closed or i > 0) else pts[0]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else pts[-1]
        for k in range(per):
            t = k / per
            t2 = t * t
            t3 = t2 * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(pts[-1])
    return out


class Part:
    def __init__(self, obj, part, family):
        self.obj = obj
        self.part = part
        self.family = family


# ---------------------------------------------------------------------------------------------- the model

# families that are baked into the atlas; anything else is a named special material the game replaces
SPECIAL = {"glass", "fluid", "glow", "arc", "runes", "halo", "orb", "coil_glow", "emitter", "lamp"}


class Model:
    def __init__(self, wid, tex=2048):
        reset()
        self.id = wid
        self.tex = tex
        self.parts = []
        self.rng = random.Random(hash(wid) & 0xFFFF)
        self.coll = bpy.context.scene.collection
        self.family_params = _FAMILY_PARAMS

    # ---------------------------------------------------------------- object creation

    def _obj(self, name, bm, part, family, bevel=0.0, bevel_segs=2, smooth=True, angle=35.0, wn=True, harden=False):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        self.coll.objects.link(ob)
        if bevel > 0.0:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = bevel_segs
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle)
            mod.miter_outer = "MITER_ARC"
            mod.harden_normals = harden
        for p in me.polygons:
            p.use_smooth = smooth
        if smooth:
            # sharp edges past `angle` keep their crease; the rest shade smooth
            me.set_sharp_from_angle(angle=math.radians(angle))
        if wn and smooth:
            w = ob.modifiers.new("WN", "WEIGHTED_NORMAL")
            w.keep_sharp = True
            w.weight = 50
        part_obj = Part(ob, part, family)
        self.parts.append(part_obj)
        return ob

    def lathe(self, part, family, profile, center=(0, 0, 0), axis="z", segs=32, cap0=True, cap1=True, bevel=0.0,
              angle=35.0, name=None, a0=0.0, arc=None, smooth=True):
        """Surface of revolution. profile: [(r, t)] along the axis (t in metres from `center`). r == 0 ends close
        to a point. arc (radians) < 2 pi gives an open sector."""
        bm = bmesh.new()
        u, v, w = axis_frame(axis)
        c = Vector(center)
        full = arc is None or arc >= math.tau - 1e-6
        nseg = segs if full else max(2, int(segs * arc / math.tau))
        rings = []
        for (r, t) in profile:
            ring = []
            if r <= 1e-6:
                ring = [bm.verts.new(c + w * t)]
            else:
                count = nseg if full else nseg + 1
                for k in range(count):
                    a = a0 + (arc if not full else math.tau) * k / (nseg if not full else nseg)
                    ring.append(bm.verts.new(c + w * t + (u * math.cos(a) + v * math.sin(a)) * r))
            rings.append(ring)
        for i in range(len(rings) - 1):
            r0, r1 = rings[i], rings[i + 1]
            if len(r0) == 1 and len(r1) == 1:
                continue
            n = max(len(r0), len(r1))
            spans = n if full else n - 1
            for k in range(spans):
                k1 = (k + 1) % n
                if len(r0) == 1:
                    f = [r0[0], r1[k1], r1[k]]
                elif len(r1) == 1:
                    f = [r0[k], r0[k1], r1[0]]
                else:
                    f = [r0[k], r0[k1], r1[k1], r1[k]]
                try:
                    bm.faces.new(f)
                except ValueError:
                    pass
        if full:
            if cap0 and len(rings[0]) > 2:
                bm.faces.new(list(reversed(rings[0])))
            if cap1 and len(rings[-1]) > 2:
                bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or part, bm, part, family, bevel=bevel, angle=angle, smooth=smooth)

    def cyl(self, part, family, r0, r1, length, center, axis="z", segs=24, bevel=0.0006, name=None, cap0=True, cap1=True, smooth=True):
        """Cylinder / cone: r0 at the -axis end (the front for axis z), r1 at the +axis end."""
        h = length * 0.5
        prof = [(0.0, -h), (r0, -h), (r1, h), (0.0, h)]
        if not cap0:
            prof = prof[1:]
        if not cap1:
            prof = prof[:-1]
        return self.lathe(part, family, prof, center, axis, segs, bevel=bevel, name=name, smooth=smooth)

    def tube(self, part, family, r_in, r_out, length, center, axis="z", segs=24, bevel=0.0005, name=None):
        """A hollow tube (collar, ring, sleeve): annulus faces at both ends."""
        h = length * 0.5
        prof = [(r_in, -h), (r_out, -h), (r_out, h), (r_in, h), (r_in, -h)]
        return self.lathe(part, family, prof, center, axis, segs, cap0=False, cap1=False, bevel=bevel, name=name)

    def torus(self, part, family, R, r, center, axis="z", segs=32, rsegs=10, name=None, arc=None):
        bm = bmesh.new()
        u, v, w = axis_frame(axis)
        c = Vector(center)
        full = arc is None
        n = segs if full else segs + 1
        rings = []
        for k in range(n):
            a = (arc if not full else math.tau) * k / segs
            d = u * math.cos(a) + v * math.sin(a)
            ring = []
            for j in range(rsegs):
                b = math.tau * j / rsegs
                ring.append(bm.verts.new(c + d * (R + r * math.cos(b)) + w * (r * math.sin(b))))
            rings.append(ring)
        spans = n if full else n - 1
        for k in range(spans):
            a, b = rings[k], rings[(k + 1) % n]
            for j in range(rsegs):
                j1 = (j + 1) % rsegs
                bm.faces.new([a[j], b[j], b[j1], a[j1]])
        if not full:
            bm.faces.new(list(reversed(rings[0])))
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or part, bm, part, family)

    def box(self, part, family, size, center, rot=(0, 0, 0), bevel=0.0012, segs=2, name=None, smooth=True):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        m = Matrix.Translation(Vector(center)) @ Matrix.LocRotScale(None, _euler(rot), Vector(size))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        return self._obj(name or part, bm, part, family, bevel=bevel, bevel_segs=segs, smooth=smooth)

    def prism(self, part, family, pts, x0, x1, bevel=0.0015, segs=2, name=None, plane="zy", xf=None):
        """A 2-D outline extruded across the gun. plane "zy": pts are (z, y), extruded along x from x0 to x1
        (stocks, grips, plates, brackets). plane "xz": pts are (x, z) extruded along y; "xy": (x, y) along z."""
        bm = bmesh.new()

        def P(a, b, s):
            if plane == "zy":
                return Vector((s, b, a))
            if plane == "xz":
                return Vector((a, s, b))
            return Vector((a, b, s))
        lo = [bm.verts.new(P(p[0], p[1], x0)) for p in pts]
        hi = [bm.verts.new(P(p[0], p[1], x1)) for p in pts]
        bm.faces.new(lo)
        bm.faces.new(list(reversed(hi)))
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        if xf is not None:
            bmesh.ops.transform(bm, matrix=xf, verts=bm.verts)
        return self._obj(name or part, bm, part, family, bevel=bevel, bevel_segs=segs)

    def sweep(self, part, family, points, radius, segs=8, smooth_per=0, closed=False, cap=True, name=None, radii=None, twist=0.0,
              ref=None, angle=60.0, smooth=True):
        """A tube swept along a polyline (wires, cables, coils, the crank's bent arm, a leather wrap strip).
        radius: a float or an (a, b) ellipse (a along the frame normal, b along the binormal); radii: one of those per
        sample (a loft: grips, horns). ref: the vector the first frame normal leans toward (default: up/right).
        smooth_per > 0 runs the points through Catmull-Rom first."""
        pts = catmull(points, smooth_per, closed) if smooth_per > 0 else [Vector(p) for p in points]
        n = len(pts)
        if radii is not None and len(radii) != n:
            # control-point radii stretched over the smoothed samples (linear in the sample index)
            src = list(radii)
            out = []
            for i in range(n):
                f = i / max(1, n - 1) * (len(src) - 1)
                k = min(len(src) - 2, int(f))
                t = f - k
                a, b = src[k], src[k + 1]
                if isinstance(a, (tuple, list)):
                    out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
                else:
                    out.append(a + (b - a) * t)
            radii = out
        bm = bmesh.new()
        # parallel-transport frames
        tangents = []
        for i in range(n):
            if closed:
                t = (pts[(i + 1) % n] - pts[(i - 1) % n])
            else:
                t = (pts[min(n - 1, i + 1)] - pts[max(0, i - 1)])
            tangents.append(t.normalized() if t.length > 1e-9 else Vector((0, 0, 1)))
        if ref is not None:
            nrm = Vector(ref) - tangents[0] * Vector(ref).dot(tangents[0])
            nrm.normalize()
        else:
            r0 = Vector((0, 1, 0)) if abs(tangents[0].y) < 0.9 else Vector((1, 0, 0))
            nrm = tangents[0].cross(r0).normalized()
        rings = []
        for i in range(n):
            t = tangents[i]
            nrm = (nrm - t * nrm.dot(t))
            if nrm.length < 1e-6:
                nrm = t.cross(Vector((1, 0, 0))).normalized()
            nrm.normalize()
            bin_ = t.cross(nrm).normalized()
            rr = radii[i] if radii is not None else radius
            ra, rb = (rr, rr) if not isinstance(rr, (tuple, list)) else (rr[0], rr[1])
            ring = []
            for k in range(segs):
                a = math.tau * k / segs + twist * i
                ring.append(bm.verts.new(pts[i] + nrm * (math.cos(a) * ra) + bin_ * (math.sin(a) * rb)))
            rings.append(ring)
        spans = n if closed else n - 1
        for i in range(spans):
            a, b = rings[i], rings[(i + 1) % n]
            for k in range(segs):
                k1 = (k + 1) % segs
                bm.faces.new([a[k], a[k1], b[k1], b[k]])
        if cap and not closed:
            bm.faces.new(list(reversed(rings[0])))
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or part, bm, part, family, angle=angle, smooth=smooth)

    def helix(self, part, family, R, wire_r, t0, t1, turns, center=(0, 0, 0), axis="z", per_turn=24, segs=6, name=None, phase=0.0):
        u, v, w = axis_frame(axis)
        c = Vector(center)
        n = max(2, int(turns * per_turn))
        pts = []
        for i in range(n + 1):
            f = i / n
            a = phase + math.tau * turns * f
            pts.append(c + w * (t0 + (t1 - t0) * f) + (u * math.cos(a) + v * math.sin(a)) * R)
        return self.sweep(part, family, pts, wire_r, segs=segs, name=name)

    def dome(self, r, center, normal, bm, rings=3, segs=8, flat=0.55):
        """Adds a rivet / bolt head (a squashed hemisphere) to `bm`."""
        nn = Vector(normal).normalized()
        u = nn.cross(Vector((0, 1, 0)) if abs(nn.y) < 0.9 else Vector((1, 0, 0))).normalized()
        v = nn.cross(u)
        c = Vector(center)
        verts = []
        for i in range(rings):
            phi = (math.pi * 0.5) * i / rings
            ring = []
            for k in range(segs):
                a = math.tau * k / segs
                ring.append(bm.verts.new(c + (u * math.cos(a) + v * math.sin(a)) * r * math.cos(phi) + nn * r * flat * math.sin(phi)))
            verts.append(ring)
        top = bm.verts.new(c + nn * r * flat)
        for i in range(rings - 1):
            for k in range(segs):
                k1 = (k + 1) % segs
                bm.faces.new([verts[i][k], verts[i][k1], verts[i + 1][k1], verts[i + 1][k]])
        for k in range(segs):
            bm.faces.new([verts[-1][k], verts[-1][(k + 1) % segs], top])
        bm.faces.new(list(reversed(verts[0])))

    def rivets(self, part, family, items, r=0.0018, segs=8, name=None, flat=0.55):
        """items: [(center, normal)]: one object of rivet heads."""
        bm = bmesh.new()
        for c, nn in items:
            self.dome(r, c, nn, bm, segs=segs, flat=flat)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or part, bm, part, family, wn=False, angle=80.0)

    def bolt_heads(self, part, family, items, r=0.003, h=0.002, name=None):
        """Hex bolt heads: items [(center, normal)]."""
        bm = bmesh.new()
        for c, nn in items:
            nn = Vector(nn).normalized()
            u = nn.cross(Vector((0, 1, 0)) if abs(nn.y) < 0.9 else Vector((1, 0, 0))).normalized()
            v = nn.cross(u)
            lo, hi = [], []
            for k in range(6):
                a = math.tau * k / 6 + 0.26
                d = (u * math.cos(a) + v * math.sin(a)) * r
                lo.append(bm.verts.new(Vector(c) + d))
                hi.append(bm.verts.new(Vector(c) + d * 0.92 + nn * h))
            bm.faces.new(list(reversed(lo)))
            bm.faces.new(hi)
            for k in range(6):
                k1 = (k + 1) % 6
                bm.faces.new([lo[k], lo[k1], hi[k1], hi[k]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or part, bm, part, family, angle=40.0, wn=False)

    def text(self, part, family, body, size, mapper, depth=0.0004, name=None, align="CENTER", font_bold=False, spacing=1.0):
        """Raised lettering: a text object turned into a mesh, then every vertex (tx, ty, tz) of the flat text
        (tx along the line, ty up, tz out of the surface, in metres) is placed by mapper(tx, ty, tz) -> game-frame
        point. Used for cast inscriptions, stencils and plates."""
        cu = bpy.data.curves.new(name or (part + "_txt"), "FONT")
        cu.body = body
        cu.size = size
        cu.extrude = depth * 0.5
        cu.align_x = align
        cu.align_y = "CENTER"
        cu.space_character = spacing
        cu.resolution_u = 3
        ob = bpy.data.objects.new((name or part) + "_tmp", cu)
        self.coll.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
        bpy.data.objects.remove(ob)
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        for vv in bm.verts:
            vv.co = Vector(mapper(vv.co.x, vv.co.y, vv.co.z + depth * 0.5))
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or (part + "_txt"), bm, part, family, smooth=False, wn=False)

    def strokes(self, part, family, polylines, width, mapper, depth=0.0006, name=None):
        """Flat strokes (runes, scratched marks): each polyline in (s, t) surface coordinates becomes a strip of
        quads `width` wide, lifted `depth`, placed by mapper(s, t, h) -> game-frame point."""
        bm = bmesh.new()
        for pl in polylines:
            prev = None
            for i in range(len(pl) - 1):
                a, b = Vector((pl[i][0], pl[i][1])), Vector((pl[i + 1][0], pl[i + 1][1]))
                d = (b - a)
                if d.length < 1e-7:
                    continue
                nn = Vector((-d.y, d.x)).normalized() * width * 0.5
                ex = d.normalized() * width * 0.5
                q = [a - nn - ex, b - nn + ex, b + nn + ex, a + nn - ex]
                lo = [bm.verts.new(mapper(p.x, p.y, 0.0)) for p in q]
                hi = [bm.verts.new(mapper(p.x, p.y, depth)) for p in q]
                bm.faces.new(hi)
                for k in range(4):
                    k1 = (k + 1) % 4
                    bm.faces.new([lo[k], lo[k1], hi[k1], hi[k]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._obj(name or (part + "_strokes"), bm, part, family, smooth=False, wn=False)

    def instance(self, src, part=None, matrix=None, name=None):
        """A copy of an existing object's (unapplied) mesh, transformed."""
        me = src.data.copy()
        ob = bpy.data.objects.new(name or (src.name + "_c"), me)
        for mod in src.modifiers:
            nm = ob.modifiers.new(mod.name, mod.type)
            for attr in ("width", "segments", "limit_method", "angle_limit", "miter_outer", "harden_normals", "keep_sharp", "weight"):
                if hasattr(mod, attr):
                    setattr(nm, attr, getattr(mod, attr))
        self.coll.objects.link(ob)
        if matrix is not None:
            me.transform(matrix)
        fam = next(p.family for p in self.parts if p.obj == src)
        self.parts.append(Part(ob, part or next(p.part for p in self.parts if p.obj == src), fam))
        return ob

    def deform(self, ob, fn):
        """Move every vertex of `ob` by fn(Vector) -> Vector (bends, tapers, hammered dents)."""
        for vv in ob.data.vertices:
            vv.co = Vector(fn(vv.co.copy()))
        ob.data.update()

    # ---------------------------------------------------------------- finishing

    def finish(self, out_dir, turntable=None, fast=False, extra_report=None, joins=None):
        t_start = time.time()
        out_dir = os.path.abspath(out_dir)
        tex = self.tex if not fast else 512
        os.makedirs(out_dir, exist_ok=True)
        self._apply_modifiers()
        self._join_parts()
        baked = [p for p in self.parts if p.family not in SPECIAL]
        special = [p for p in self.parts if p.family in SPECIAL]
        self._uv(baked, special)
        mats = self._bake(baked, tex, out_dir, fast)
        self._final_materials(baked, special, mats)
        self._orient()
        report = self._report()
        if extra_report:
            report.update(extra_report)
        glb = os.path.join(out_dir, "model.glb")
        self._export(glb, out_dir)
        report["glb_bytes"] = os.path.getsize(glb)
        report["textures"] = sorted(os.listdir(os.path.join(out_dir, "textures")))
        report["texture_size"] = tex
        report["build_seconds"] = round(time.time() - t_start, 1)
        os.makedirs(REPORTS, exist_ok=True)
        with open(os.path.join(REPORTS, self.id + ".json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(report, f, indent=1)
            f.write("\n")
        print("[wonder] %s: %d tris, %d nodes, %.1fs" % (self.id, report["tris"], len(report["nodes"]), report["build_seconds"]))
        if turntable:
            hide = getattr(self, "crucible_parts", [])
            self.turntable(turntable, hide=hide)
            if hide:
                self.turntable(turntable.replace(".png", "_crucible.png"))
        return report

    def _apply_modifiers(self):
        dg = bpy.context.evaluated_depsgraph_get()
        for p in self.parts:
            ob = p.obj
            if not ob.modifiers:
                continue
            ev = ob.evaluated_get(dg)
            me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
            old = ob.data
            ob.modifiers.clear()
            ob.data = me
            if old.users == 0:
                bpy.data.meshes.remove(old)

    def _join_parts(self):
        """One object per (part, baked?) and per special family: the GLB node names are the part names; special
        surfaces join their part's mesh as extra material slots (one node per part)."""
        # give every object its family material slot first so joins keep them apart
        fam_mats = {}
        for p in self.parts:
            m = fam_mats.get(p.family)
            if m is None:
                m = bpy.data.materials.new("fam_" + p.family)
                fam_mats[p.family] = m
            p.obj.data.materials.clear()
            p.obj.data.materials.append(m)
        groups = {}
        for p in self.parts:
            groups.setdefault(p.part, []).append(p)
        new_parts = []
        for part, ps in groups.items():
            objs = [p.obj for p in ps]
            # bake families and special families stay separate objects until after the bake (UVs differ)
            by_kind = {}
            for p in ps:
                key = p.family if p.family in SPECIAL else "_bake"
                by_kind.setdefault(key, []).append(p)
            for key, lst in by_kind.items():
                obs = [p.obj for p in lst]
                if len(obs) > 1:
                    with bpy.context.temp_override(active_object=obs[0], selected_editable_objects=obs, object=obs[0]):
                        bpy.ops.object.join()
                ob = obs[0]
                ob.name = part if key == "_bake" else part + "__" + key
                fam = key if key != "_bake" else "_bake"
                np_ = Part(ob, part, fam)
                new_parts.append(np_)
        self.parts = new_parts
        self.fam_mats = fam_mats

    def _uv(self, baked, special):
        bpy.ops.object.select_all(action="DESELECT")
        for grp in (baked, special):
            obs = [p.obj for p in grp]
            if not obs:
                continue
            for o in obs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obs[0]
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
            bpy.ops.uv.select_all(action="SELECT")
            bpy.ops.uv.average_islands_scale()
            bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, margin_method="FRACTION", margin=0.004)
            bpy.ops.object.mode_set(mode="OBJECT")
            for o in obs:
                o.select_set(False)

    # ---------------------------------------------------------------- baking

    def _img(self, name, size, color=True, alpha=False):
        im = bpy.data.images.get(name)
        if im is not None:
            bpy.data.images.remove(im)
        im = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=not color)
        im.colorspace_settings.name = "sRGB" if color else "Non-Color"
        return im

    def _bake(self, baked, tex, out_dir, fast):
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.use_denoising = False
        sc.render.bake.margin = 8 if tex >= 1024 else 4
        sc.render.bake.margin_type = "EXTEND"
        sc.render.bake.use_clear = True
        world = bpy.data.worlds.new("bake_world")
        sc.world = world
        world.use_nodes = True
        world.light_settings.distance = 0.03
        obs = [p.obj for p in baked]
        hidden = [p.obj for p in self.parts if p.family in SPECIAL]
        for o in hidden:
            o.hide_render = True       # glass and glow never shadow the baked AO
        # recover each baked object's per-face family: the joined objects carry the fam_ material slots
        imgs = {k: self._img("%s_%s" % (self.id, k), tex, color=(k == "albedo")) for k in ("ao", "curv", "albedo", "rough", "metal", "normal")}
        bake_mats = {}
        for fam, m in self.fam_mats.items():
            if fam in SPECIAL:
                continue
            bake_mats[fam] = PaintMaterial(m, fam, imgs, self.family_params.get(fam, {}))
        samples_ao = 8 if fast else 48
        samples_curv = 4 if fast else 16
        sel = obs

        def run(kind, btype, samples, pass_filter=None):
            sc.cycles.samples = samples
            for pm in bake_mats.values():
                pm.wire(kind)
            bpy.ops.object.select_all(action="DESELECT")
            for o in sel:
                o.select_set(True)
            bpy.context.view_layer.objects.active = sel[0]
            t = time.time()
            kw = {"type": btype}
            if btype == "NORMAL":
                kw.update(normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z")
            bpy.ops.object.bake(**kw)
            print("[wonder]   bake %-7s %5.1fs" % (kind, time.time() - t))

        run("ao", "AO", samples_ao)
        run("curv", "EMIT", samples_curv)
        run("albedo", "EMIT", 1)
        run("rough", "EMIT", 1)
        run("metal", "EMIT", 1)
        run("normal", "NORMAL", 1)
        for o in hidden:
            o.hide_render = False
        tex_dir = os.path.join(out_dir, "textures")
        if os.path.isdir(tex_dir):
            shutil.rmtree(tex_dir)
        os.makedirs(tex_dir)
        import numpy as np
        n = tex * tex

        def arr(im):
            a = np.empty(n * 4, dtype=np.float32)
            im.pixels.foreach_get(a)
            return a.reshape(n, 4)
        ao = arr(imgs["ao"])
        ro = arr(imgs["rough"])
        me = arr(imgs["metal"])
        orm = np.ones((n, 4), dtype=np.float32)
        # soften the AO so it reads as ambient, not as dirt (the paint already darkens the cavities)
        orm[:, 0] = np.clip(0.35 + 0.65 * ao[:, 0], 0.0, 1.0)
        orm[:, 1] = np.clip(ro[:, 0], 0.04, 1.0)
        orm[:, 2] = np.clip(me[:, 0], 0.0, 1.0)
        orm_img = self._img("%s_orm" % self.id, tex, color=False)
        orm_img.pixels.foreach_set(orm.ravel())
        paths = {}
        for key, im in (("albedo", imgs["albedo"]), ("normal", imgs["normal"]), ("orm", orm_img)):
            path = os.path.join(tex_dir, "%s_%s.png" % (self.id, key))
            im.filepath_raw = path
            im.file_format = "PNG"
            sc.render.image_settings.color_mode = "RGB"
            sc.render.image_settings.compression = 90
            if key == "albedo":
                im.save()
            else:
                # 8-bit linear PNGs for the data maps (save_render would view-transform them)
                im8 = bpy.data.images.new(im.name + "_8", tex, tex, alpha=False, float_buffer=False)
                im8.colorspace_settings.name = "Non-Color"
                px = np.empty(n * 4, dtype=np.float32)
                im.pixels.foreach_get(px)
                im8.pixels.foreach_set(px)
                im8.filepath_raw = path
                im8.file_format = "PNG"
                im8.save()
                bpy.data.images.remove(im8)
            paths[key] = path
        return paths

    def _final_materials(self, baked, special, paths):
        atlas = bpy.data.materials.new(self.id + "_atlas")
        atlas.use_nodes = True
        nt = atlas.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        ia = nt.nodes.new("ShaderNodeTexImage")
        ia.image = bpy.data.images.load(paths["albedo"])
        ia.image.name = self.id + "_albedo"
        io = nt.nodes.new("ShaderNodeTexImage")
        io.image = bpy.data.images.load(paths["orm"])
        io.image.colorspace_settings.name = "Non-Color"
        io.image.name = self.id + "_orm"
        inn = nt.nodes.new("ShaderNodeTexImage")
        inn.image = bpy.data.images.load(paths["normal"])
        inn.image.colorspace_settings.name = "Non-Color"
        inn.image.name = self.id + "_normal"
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ia.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(io.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nt.links.new(inn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        # glTF occlusion: the exporter reads a "glTF Material Output" group's Occlusion socket
        grp = bpy.data.node_groups.get("glTF Material Output")
        if grp is None:
            grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
            grp.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        gn = nt.nodes.new("ShaderNodeGroup")
        gn.node_tree = grp
        nt.links.new(sep.outputs["Red"], gn.inputs["Occlusion"])
        self.atlas = atlas
        for p in baked:
            p.obj.data.materials.clear()
            p.obj.data.materials.append(atlas)
        spec_mats = {}
        for p in special:
            if p.family in spec_mats:
                p.obj.data.materials.clear()
                p.obj.data.materials.append(spec_mats[p.family])
                continue
            m = bpy.data.materials.new(p.family)
            spec_mats[p.family] = m
            m.use_nodes = True
            b = m.node_tree.nodes.get("Principled BSDF")
            col = SPECIAL_LOOK.get(p.family, ((0.5, 0.5, 0.5), 0.0, 0.3, 0.0))
            b.inputs["Base Color"].default_value = (*col[0], 1.0)
            b.inputs["Metallic"].default_value = col[1]
            b.inputs["Roughness"].default_value = col[2]
            if col[3] > 0:
                b.inputs["Emission Color"].default_value = (*col[0], 1.0)
                b.inputs["Emission Strength"].default_value = col[3]
            if p.family == "glass":
                b.inputs["Alpha"].default_value = 0.15
                m.surface_render_method = "BLENDED"
            p.obj.data.materials.clear()
            p.obj.data.materials.append(m)
        # now the special objects join their part's baked object as extra slots (one GLB node per part)
        by_part = {}
        for p in baked + special:
            by_part.setdefault(p.part, []).append(p)
        final = []
        for part, ps in by_part.items():
            obs = [p.obj for p in sorted(ps, key=lambda q: 0 if q.family not in SPECIAL else 1)]
            if len(obs) > 1:
                with bpy.context.temp_override(active_object=obs[0], selected_editable_objects=obs, object=obs[0]):
                    bpy.ops.object.join()
            obs[0].name = part
            obs[0].data.name = part
            final.append(Part(obs[0], part, "_mixed"))
        self.parts = final

    def _orient(self):
        """Game frame (authored) -> Blender Z-up, so the glTF exporter's Y-up conversion lands back on it."""
        bpy.ops.object.select_all(action="DESELECT")
        for p in self.parts:
            p.obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
            p.obj.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0].obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    def _report(self):
        nodes = []
        total = 0
        for p in sorted(self.parts, key=lambda q: q.part):
            me = p.obj.data
            me.calc_loop_triangles()
            tris = len(me.loop_triangles)
            total += tris
            mn = [1e9] * 3
            mx = [-1e9] * 3
            for vv in me.vertices:
                g = (vv.co.x, vv.co.z, -vv.co.y)       # back to the game frame
                for k in range(3):
                    mn[k] = min(mn[k], g[k]); mx[k] = max(mx[k], g[k])
            nodes.append({"name": p.part, "tris": tris, "bbox_min": [round(x, 4) for x in mn], "bbox_max": [round(x, 4) for x in mx],
                          "materials": [m.name for m in me.materials]})
        mn = [min(n["bbox_min"][k] for n in nodes) for k in range(3)]
        mx = [max(n["bbox_max"][k] for n in nodes) for k in range(3)]
        return {"id": self.id, "tris": total, "nodes": nodes, "bbox_min": mn, "bbox_max": mx,
                "size": [round(mx[k] - mn[k], 4) for k in range(3)], "blender": bpy.app.version_string,
                "frame": "game frame: -Z forward, +Y up, origin at the right-hand grip, metres"}

    def _export(self, out_glb, out_dir):
        tmp = tempfile.mkdtemp(prefix="wglb_")
        gltf = os.path.join(tmp, "model.gltf")
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.export_scene.gltf(filepath=gltf, export_format="GLTF_SEPARATE", export_texture_dir="textures",
                                  export_image_format="AUTO", export_apply=True, export_yup=True, export_animations=False,
                                  export_skins=False, export_morph=False, export_materials="EXPORT", export_extras=False,
                                  use_selection=False, export_texcoords=True, export_normals=True, export_tangents=False,
                                  export_cameras=False, export_lights=False)
        with open(gltf, "r", encoding="utf-8") as f:
            js = json.load(f)
        bins = js.get("buffers", [])
        with open(os.path.join(tmp, bins[0]["uri"]), "rb") as f:
            bin_data = f.read()
        # point the images at our own PNGs (already in <out>/textures)
        for im in js.get("images", []):
            uri = im.get("uri", "")
            base = os.path.splitext(os.path.basename(uri))[0]
            name = None
            for key in ("albedo", "normal", "orm"):
                if base.endswith(key):
                    name = "%s_%s.png" % (self.id, key)
            if name is None:
                raise SystemExit("unexpected image " + uri)
            im["uri"] = "textures/" + name
            im["mimeType"] = "image/png"
        js["buffers"] = [{"byteLength": len(bin_data)}]
        js.setdefault("asset", {})["generator"] = "GRAVELIGHT wonder_lib.py (Blender %s)" % bpy.app.version_string
        jtxt = json.dumps(js, separators=(",", ":")).encode("utf-8")
        jtxt += b" " * ((4 - len(jtxt) % 4) % 4)
        bin_pad = bin_data + b"\0" * ((4 - len(bin_data) % 4) % 4)
        total = 12 + 8 + len(jtxt) + 8 + len(bin_pad)
        with open(out_glb, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(jtxt), 0x4E4F534A))
            f.write(jtxt)
            f.write(struct.pack("<II", len(bin_pad), 0x004E4942))
            f.write(bin_pad)
        shutil.rmtree(tmp, ignore_errors=True)

    # ---------------------------------------------------------------- turntable (EEVEE, off-screen)

    def turntable(self, path, size=512, hide=None, show_special=True):
        """Eight angles around the model in a 4 x 2 sheet. The model is in Blender's frame (after _orient).
        hide: part names left out (the Crucible-only parts on the base sheet)."""
        import numpy as np
        for p in self.parts:
            p.obj.hide_render = bool(hide) and p.part in hide
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.resolution_x = size
        sc.render.resolution_y = size
        sc.render.film_transparent = False
        sc.view_settings.view_transform = "AgX"
        w = bpy.data.worlds.new("tt_world")
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = (0.10, 0.11, 0.13, 1.0)
        bg.inputs["Strength"].default_value = 0.6
        sc.world = w
        for o in list(bpy.data.objects):
            if o.type in ("LIGHT", "CAMERA"):
                bpy.data.objects.remove(o)
        obs = [p.obj for p in self.parts if not p.obj.hide_render]
        mn = Vector((1e9, 1e9, 1e9))
        mx = Vector((-1e9, -1e9, -1e9))
        for o in obs:
            for vv in o.data.vertices:
                mn = Vector((min(mn[k], vv.co[k]) for k in range(3)))
                mx = Vector((max(mx[k], vv.co[k]) for k in range(3)))
        ctr = (mn + mx) * 0.5
        rad = (mx - mn).length * 0.5
        piv = bpy.data.objects.new("tt_pivot", None)
        self.coll.objects.link(piv)
        piv.location = ctr
        bpy.context.view_layer.update()
        for o in obs:
            o.parent = piv
            o.matrix_parent_inverse = piv.matrix_world.inverted()
        cam_d = bpy.data.cameras.new("tt_cam")
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = rad * 2.15
        cam = bpy.data.objects.new("tt_cam", cam_d)
        self.coll.objects.link(cam)
        dist = rad * 4.0
        cam.location = ctr + Vector((0.0, -dist * 0.94, dist * 0.34))
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_d.clip_start = 0.01
        sc.camera = cam
        for (nm, loc, en, col) in (("key", (1.0, -1.2, 1.4), 22.0, (1.0, 0.85, 0.7)), ("fill", (-1.4, -0.6, 0.4), 7.0, (0.6, 0.7, 1.0)),
                                   ("rim", (0.0, 1.5, 1.0), 16.0, (0.9, 0.8, 1.0))):
            ld = bpy.data.lights.new(nm, "AREA")
            ld.energy = en * rad * rad * 40.0
            ld.size = rad * 1.5
            ld.color = col
            lo = bpy.data.objects.new(nm, ld)
            self.coll.objects.link(lo)
            lo.location = ctr + Vector(loc) * rad * 3.0
            lo.rotation_euler = (ctr - lo.location).to_track_quat("-Z", "Y").to_euler()
        tmp = tempfile.mkdtemp(prefix="wtt_")
        tiles = []
        for i in range(8):
            piv.rotation_euler = (0.0, 0.0, math.tau * i / 8.0 + math.radians(90))
            f = os.path.join(tmp, "tt_%d.png" % i)
            sc.render.filepath = f
            bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(f)
            a = np.empty(size * size * 4, dtype=np.float32)
            im.pixels.foreach_get(a)
            tiles.append(a.reshape(size, size, 4))
            bpy.data.images.remove(im)
        sheet = np.zeros((size * 2, size * 4, 4), dtype=np.float32)
        for i, t in enumerate(tiles):
            r, c = i // 4, i % 4
            sheet[(1 - r) * size:(2 - r) * size, c * size:(c + 1) * size] = t
        out = bpy.data.images.new("tt_sheet", size * 4, size * 2, alpha=False)
        out.colorspace_settings.name = "Non-Color"   # the tiles are display-referred already
        out.pixels.foreach_set(sheet.ravel())
        out.filepath_raw = path
        out.file_format = "PNG"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save()
        shutil.rmtree(tmp, ignore_errors=True)
        piv.rotation_euler = (0.0, 0.0, 0.0)        # back to the authored pose before letting go
        bpy.context.view_layer.update()
        for o in obs:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        print("[wonder] turntable ->", path)


def _euler(rot):
    from mathutils import Euler
    return Euler((math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ")


# The look of the named special materials in the GLB (the game swaps them for its own shaders; these are what a
# plain glTF viewer and the turntable show): (colour, metallic, roughness, emission strength)
SPECIAL_LOOK = {
    "glass": ((0.2, 0.22, 0.24), 0.0, 0.05, 0.0),
    "fluid": ((0.45, 0.12, 0.9), 0.0, 0.1, 1.5),
    "glow": ((0.55, 0.2, 1.0), 0.0, 0.3, 1.5),
    "coil_glow": ((0.35, 0.1, 0.7), 0.0, 0.3, 0.6),
    "emitter": ((0.62, 0.3, 1.0), 0.0, 0.1, 2.5),
    "arc": ((0.7, 0.5, 1.0), 0.0, 0.3, 6.0),
    "runes": ((0.55, 0.2, 1.0), 0.0, 0.4, 4.0),
    "halo": ((0.6, 0.3, 1.0), 0.0, 0.2, 5.0),
    "orb": ((0.8, 0.6, 1.0), 0.0, 0.1, 8.0),
    "lamp": ((1.0, 0.7, 0.4), 0.0, 0.3, 3.0),
}


# ---------------------------------------------------------------------------------------------- paint recipes


class NB:
    """Tiny node-building helper for the paint recipes."""

    def __init__(self, nt):
        self.nt = nt
        self.x = 0

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        n.location = (self.x, 0)
        self.x += 30
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def val(self, v):
        n = self.node("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    def rgb(self, c):
        n = self.node("ShaderNodeRGB")
        n.outputs[0].default_value = (c[0], c[1], c[2], 1.0)
        return n.outputs[0]

    def _in(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v if len(v) == len(sock.default_value) else (*v, 1.0)
        else:
            self.link(v, sock)

    def math(self, op, a, b=0.0, c=0.0, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        if len(n.inputs) > 2:
            self._in(n.inputs[2], c)
        return n.outputs[0]

    def add(self, a, b):
        return self.math("ADD", a, b)

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)

    def sstep(self, a, lo, hi):
        n = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self._in(n.inputs["Value"], a)
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs["Result"]

    @staticmethod
    def _sock(coll, ident):
        for s in coll:
            if s.identifier == ident:
                return s
        raise KeyError(ident)

    def mix(self, f, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", clamp_factor=True)
        self._in(self._sock(n.inputs, "Factor_Float"), f)
        self._in(self._sock(n.inputs, "A_Color"), a)
        self._in(self._sock(n.inputs, "B_Color"), b)
        return self._sock(n.outputs, "Result_Color")

    def lerp(self, f, a, b):
        n = self.node("ShaderNodeMix", data_type="FLOAT", clamp_factor=True)
        self._in(self._sock(n.inputs, "Factor_Float"), f)
        self._in(self._sock(n.inputs, "A_Float"), a)
        self._in(self._sock(n.inputs, "B_Float"), b)
        return self._sock(n.outputs, "Result_Float")

    def vscale(self, vec, s):
        n = self.node("ShaderNodeVectorMath", operation="MULTIPLY")
        self._in(n.inputs[0], vec)
        n.inputs[1].default_value = s if isinstance(s, tuple) else (s, s, s)
        return n.outputs["Vector"]

    def noise(self, vec, scale, detail=4.0, rough=0.55, distort=0.0, out="Fac"):
        n = self.node("ShaderNodeTexNoise")
        self._in(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distort
        return n.outputs[out]

    def voronoi(self, vec, scale, out="Distance", feature="F1"):
        n = self.node("ShaderNodeTexVoronoi", feature=feature)
        self._in(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        return n.outputs[out]

    def wave(self, vec, scale, distort=4.0, detail=3.0, direction="Z", kind="BANDS", profile="SIN"):
        n = self.node("ShaderNodeTexWave", wave_type=kind, wave_profile=profile)
        if kind == "BANDS":
            n.bands_direction = direction
        else:
            n.rings_direction = direction
        self._in(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = distort
        n.inputs["Detail"].default_value = detail
        return n.outputs["Fac"]

    def sep(self, vec):
        n = self.node("ShaderNodeSeparateXYZ")
        self._in(n.inputs[0], vec)
        return n.outputs["X"], n.outputs["Y"], n.outputs["Z"]


class PaintMaterial:
    """One family's procedural paint, re-wired for each bake pass (ao / curv / albedo / rough / metal / normal)."""

    def __init__(self, mat, family, imgs, params):
        self.mat = mat
        self.family = family
        self.imgs = imgs
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        self.nt = nt
        nb = NB(nt)
        self.nb = nb
        self.out = nb.node("ShaderNodeOutputMaterial")
        self.emit = nb.node("ShaderNodeEmission")
        self.bsdf = nb.node("ShaderNodeBsdfPrincipled")
        self.target = nb.node("ShaderNodeTexImage")
        tc = nb.node("ShaderNodeTexCoord")
        self.P = tc.outputs["Object"]
        self.N = tc.outputs["Normal"]
        uv = nb.node("ShaderNodeUVMap")
        ao_t = nb.node("ShaderNodeTexImage")
        ao_t.image = imgs["ao"]
        nb.link(uv.outputs["UV"], ao_t.inputs["Vector"])
        cv_t = nb.node("ShaderNodeTexImage")
        cv_t.image = imgs["curv"]
        nb.link(uv.outputs["UV"], cv_t.inputs["Vector"])
        self.ao = ao_t.outputs["Color"]
        self.curv = cv_t.outputs["Color"]
        # curvature source: how far a bevelled normal leans from the true one (edges, both convex and concave)
        bev = nb.node("ShaderNodeBevel", samples=8)
        bev.inputs["Radius"].default_value = params.get("bevel_r", 0.0016)
        geo = nb.node("ShaderNodeNewGeometry")
        dot = nb.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        nb.link(bev.outputs["Normal"], dot.inputs[0])
        nb.link(geo.outputs["Normal"], dot.inputs[1])
        self.curv_src = nb.math("MULTIPLY", nb.math("SUBTRACT", 1.0, dot.outputs["Value"]), 9.0, clamp=True)
        col, rough, metal, height = RECIPES[family](nb, self, params)
        rough = nb.val(rough) if isinstance(rough, (int, float)) else rough
        metal = nb.val(metal) if isinstance(metal, (int, float)) else metal
        self.col, self.rough, self.metal, self.height = col, rough, metal, height
        self.bump = nb.node("ShaderNodeBump")
        self.bump.inputs["Distance"].default_value = params.get("bump_dist", 0.0006)
        self.bump.inputs["Strength"].default_value = params.get("bump", 1.0)
        nb._in(self.bump.inputs["Height"], height)
        nt.nodes.active = self.target

    def wire(self, kind):
        nb = self.nb
        nt = self.nt
        for l in list(self.out.inputs["Surface"].links):
            nt.links.remove(l)
        for l in list(self.emit.inputs["Color"].links):
            nt.links.remove(l)
        if kind == "normal":
            self.target.image = self.imgs["normal"]
            nb.link(self.bump.outputs["Normal"], self.bsdf.inputs["Normal"])
            nb.link(self.bsdf.outputs["BSDF"], self.out.inputs["Surface"])
        elif kind == "ao":
            self.target.image = self.imgs["ao"]
            nb.link(self.bsdf.outputs["BSDF"], self.out.inputs["Surface"])
        else:
            src = {"curv": self.curv_src, "albedo": self.col, "rough": self.rough, "metal": self.metal}[kind]
            self.target.image = self.imgs[kind]
            nb.link(src, self.emit.inputs["Color"])
            nb.link(self.emit.outputs["Emission"], self.out.inputs["Surface"])
        nt.nodes.active = self.target


# ---- the recipes: (nb, pm, params) -> (colour, roughness, metallic, height). pm.P = object coords (metres, game
# frame), pm.ao / pm.curv = the baked maps; everything is in metres, so noise scales are "per metre".


def _masks(nb, pm, p):
    aof = nb.math("MULTIPLY", pm.ao, 1.0)
    cav = nb.math("SUBTRACT", 1.0, nb.sstep(aof, p.get("cav_lo", 0.45), p.get("cav_hi", 0.92)))
    n_edge = nb.noise(pm.P, p.get("edge_noise", 90.0), 3.0, 0.6)
    edge_raw = nb.mul(pm.curv, nb.add(0.45, nb.mul(n_edge, 1.1)))
    edge = nb.mul(nb.sstep(edge_raw, p.get("edge_lo", 0.25), p.get("edge_hi", 0.6)), nb.sstep(aof, 0.55, 0.85))
    return aof, cav, edge


def _scratches(nb, pm, scale=1.0, along=(1.0, 1.0, 0.08)):
    P2 = nb.vscale(pm.P, (along[0] * 260 * scale, along[1] * 260 * scale, along[2] * 260 * scale))
    s = nb.noise(P2, 1.0, 2.0, 0.5)
    return nb.sstep(s, 0.68, 0.74)


def r_metal(nb, pm, p):
    """Shared metal recipe (brass, bronze, copper, steel, iron): base + tarnish mottling, cavity patina (verdigris /
    rust / soot, non-metal), polished edges, fine scratches, hammered or cast bump."""
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p["base"])
    tarn = nb.rgb(p["tarnish"])
    pol = nb.rgb(p["polish"])
    pat = nb.rgb(p["patina"])
    mott = nb.sstep(nb.noise(pm.P, p.get("mottle_scale", 18.0), 5.0, 0.62), 0.38, 0.72)
    col = nb.mix(nb.mul(mott, p.get("tarnish_amt", 0.7)), base, tarn)
    patch = nb.sstep(nb.noise(pm.P, p.get("patina_scale", 35.0), 6.0, 0.7), 0.52, 0.7)
    pat_f = nb.math("MAXIMUM", nb.mul(cav, p.get("patina_cav", 1.0)), nb.mul(patch, p.get("patina_patch", 0.0)))
    pat_f = nb.mul(pat_f, nb.sstep(nb.noise(pm.P, 140.0, 3.0, 0.6), 0.3, 0.6))
    col = nb.mix(nb.mul(edge, p.get("polish_amt", 0.9)), col, pol)
    scr = _scratches(nb, pm, p.get("scratch_scale", 1.0))
    col = nb.mix(nb.mul(scr, p.get("scratch_amt", 0.25)), col, pol)
    col = nb.mix(pat_f, col, pat)
    rough = nb.lerp(mott, p.get("rough", 0.32), p.get("rough_tarnish", 0.5))
    rough = nb.lerp(nb.mul(edge, 0.9), rough, p.get("rough_polish", 0.18))
    rough = nb.lerp(pat_f, rough, p.get("rough_patina", 0.85))
    rough = nb.add(rough, nb.mul(nb.math("SUBTRACT", nb.noise(pm.P, 400.0, 2.0, 0.5), 0.5), 0.08))
    metal = nb.lerp(pat_f, p.get("metal", 1.0), 0.0)
    h = nb.mul(nb.noise(pm.P, p.get("bump_scale", 220.0), 4.0, 0.6), p.get("bump_amt", 0.4))
    if p.get("hammered"):
        h = nb.add(h, nb.mul(nb.voronoi(pm.P, p.get("hammer_scale", 70.0)), 0.8))
    h = nb.add(h, nb.mul(scr, -0.25))
    h = nb.add(h, nb.mul(pat_f, 0.35))
    return col, rough, metal, h


def r_paint(nb, pm, p):
    """Paint over metal (field grey, navy grey, black enamel): chips at the edges and in noise patches showing the
    bare metal, rust blooming around the chips and in the cavities, dust in the cavities."""
    ao, cav, edge = _masks(nb, pm, p)
    paint = nb.rgb(p["paint"])
    paint2 = nb.rgb(p.get("paint_var", p["paint"]))
    metal_c = nb.rgb(p.get("bare", (0.42, 0.41, 0.4)))
    rust = nb.rgb(p.get("rust", (0.28, 0.13, 0.06)))
    dust = nb.rgb(p.get("dust", (0.3, 0.28, 0.25)))
    var = nb.noise(pm.P, 9.0, 4.0, 0.6)
    col = nb.mix(var, paint, paint2)
    chips_n = nb.noise(pm.P, p.get("chip_scale", 60.0), 5.0, 0.7)
    chip = nb.math("MAXIMUM", nb.sstep(nb.add(nb.mul(edge, 0.8), nb.mul(chips_n, 0.5)), 0.62, 0.68),
                   nb.sstep(chips_n, p.get("chip_patch", 0.78), p.get("chip_patch", 0.78) + 0.02))
    chip = nb.mul(chip, p.get("chip_amt", 1.0))
    rust_ring = nb.mul(nb.sstep(nb.add(nb.mul(edge, 0.8), nb.mul(chips_n, 0.5)), 0.5, 0.62), nb.math("SUBTRACT", 1.0, chip))
    rust_f = nb.math("MAXIMUM", nb.mul(rust_ring, p.get("rust_amt", 0.5)), nb.mul(cav, p.get("rust_cav", 0.5)))
    col = nb.mix(rust_f, col, rust)
    col = nb.mix(chip, col, metal_c)
    col = nb.mix(nb.mul(cav, 0.5), col, dust)
    rough = nb.lerp(chip, p.get("rough", 0.6), 0.38)
    rough = nb.lerp(rust_f, rough, 0.9)
    metal = nb.lerp(chip, 0.0, 0.9)
    h = nb.add(nb.mul(nb.noise(pm.P, 300.0, 3.0, 0.6), 0.25), nb.mul(chip, -0.6))
    h = nb.add(h, nb.mul(nb.noise(pm.P, 40.0, 3.0, 0.5), 0.2))
    return col, rough, metal, h


def r_wood(nb, pm, p):
    """Hardwood: grain bands along the long axis (`grain` direction), pores, darker end grain and cavities, hand-
    polished high spots and lighter worn edges."""
    ao, cav, edge = _masks(nb, pm, p)
    dark = nb.rgb(p.get("dark", (0.16, 0.085, 0.045)))
    light = nb.rgb(p.get("light", (0.36, 0.2, 0.1)))
    worn = nb.rgb(p.get("worn", (0.46, 0.3, 0.17)))
    ax = p.get("grain", "Z")
    stretch = {"Z": (1.0, 1.0, 0.08), "Y": (1.0, 0.08, 1.0), "X": (0.08, 1.0, 1.0)}[ax]
    Pw = nb.vscale(pm.P, stretch)
    rings = nb.wave(Pw, p.get("ring_scale", 30.0), distort=p.get("ring_distort", 6.0), detail=4.0, direction={"Z": "X", "Y": "X", "X": "Y"}[ax], kind="RINGS")
    fib = nb.noise(nb.vscale(pm.P, (stretch[0] * 600, stretch[1] * 600, stretch[2] * 600)), 1.0, 3.0, 0.6)
    g = nb.add(nb.mul(rings, 0.75), nb.mul(fib, 0.35))
    col = nb.mix(nb.add(0.3, nb.mul(nb.sstep(g, 0.15, 0.95), 0.45)), dark, light)
    col = nb.mix(nb.mul(edge, 0.7), col, worn)
    col = nb.mix(nb.mul(cav, 0.6), col, nb.rgb((0.07, 0.045, 0.03)))
    rough = nb.lerp(nb.sstep(fib, 0.4, 0.7), p.get("rough", 0.5), p.get("rough", 0.5) + 0.2)
    rough = nb.lerp(edge, rough, 0.35)
    h = nb.add(nb.mul(fib, 0.5), nb.mul(rings, 0.15))
    h = nb.add(h, nb.mul(nb.noise(pm.P, 60.0, 3.0, 0.5), 0.15))
    return col, rough, 0.0, h


def r_leather(nb, pm, p):
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.2, 0.115, 0.07)))
    dark = nb.rgb(p.get("dark", (0.1, 0.06, 0.04)))
    worn = nb.rgb(p.get("worn", (0.32, 0.2, 0.12)))
    peb = nb.voronoi(pm.P, p.get("pebble", 900.0))
    blot = nb.noise(pm.P, 30.0, 5.0, 0.65)
    col = nb.mix(nb.sstep(blot, 0.35, 0.75), base, dark)
    col = nb.mix(nb.mul(edge, 0.85), col, worn)
    col = nb.mix(nb.mul(cav, 0.7), col, nb.rgb((0.05, 0.035, 0.025)))
    rough = nb.lerp(edge, p.get("rough", 0.62), 0.38)
    h = nb.add(nb.mul(peb, 0.6), nb.mul(blot, 0.2))
    return col, rough, 0.0, h


def r_ceramic(nb, pm, p):
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.82, 0.8, 0.74)))
    grime = nb.rgb((0.3, 0.27, 0.22))
    craze = nb.sstep(nb.voronoi(pm.P, 160.0, out="Distance", feature="DISTANCE_TO_EDGE"), 0.0, 0.03)
    col = nb.mix(nb.mul(cav, 0.8), base, grime)
    col = nb.mix(nb.mul(nb.math("SUBTRACT", 1.0, craze), 0.25), col, grime)
    rough = nb.lerp(cav, p.get("rough", 0.14), 0.6)
    h = nb.mul(nb.math("SUBTRACT", 1.0, craze), -0.2)
    return col, rough, 0.0, h


def r_rubber(nb, pm, p):
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.05, 0.05, 0.05)))
    worn = nb.rgb(p.get("worn", (0.12, 0.11, 0.1)))
    col = nb.mix(nb.mul(edge, 0.8), base, worn)
    col = nb.mix(nb.mul(cav, 0.5), col, nb.rgb((0.18, 0.16, 0.13)))
    rough = p.get("rough", 0.75)
    h = nb.mul(nb.noise(pm.P, 500.0, 3.0, 0.6), 0.3)
    return col, rough, 0.0, h


def r_cloth(nb, pm, p):
    """Rope, canvas, felt, cloth tape: woven bump, fuzz, dirt."""
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.5, 0.42, 0.3)))
    dark = nb.rgb(p.get("dark", (0.3, 0.24, 0.16)))
    weave = nb.wave(pm.P, p.get("weave", 900.0), distort=1.0, detail=1.0, direction=p.get("weave_dir", "Z"))
    blot = nb.noise(pm.P, 40.0, 5.0, 0.6)
    col = nb.mix(nb.add(nb.mul(blot, 0.6), nb.mul(cav, 0.6)), base, dark)
    rough = p.get("rough", 0.95)
    h = nb.add(nb.mul(weave, 0.6), nb.mul(nb.noise(pm.P, 1200.0, 2.0, 0.6), 0.3))
    return col, rough, 0.0, h


def r_shellac(nb, pm, p):
    """A gramophone record: concentric grooves (rings about the record axis), dust in the grooves."""
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.04, 0.04, 0.045)))
    c = p.get("center", (0.0, 0.0, 0.0))
    off = nb.node("ShaderNodeVectorMath", operation="SUBTRACT")
    nb._in(off.inputs[0], pm.P)
    off.inputs[1].default_value = c
    grooves = nb.wave(off.outputs["Vector"], p.get("grooves", 900.0), distort=0.0, detail=0.0, direction="SPHERICAL", kind="RINGS")
    col = nb.mix(nb.mul(nb.noise(pm.P, 200.0, 2.0, 0.5), 0.3), base, nb.rgb((0.09, 0.09, 0.1)))
    rough = nb.lerp(grooves, 0.22, 0.4)
    h = nb.mul(grooves, 0.5)
    return col, rough, 0.0, h


def r_paper(nb, pm, p):
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.62, 0.55, 0.42)))
    stain = nb.rgb(p.get("stain", (0.4, 0.32, 0.2)))
    blot = nb.noise(pm.P, 60.0, 6.0, 0.7)
    col = nb.mix(nb.add(nb.mul(nb.sstep(blot, 0.55, 0.8), 0.6), nb.mul(edge, 0.4)), base, stain)
    return col, 0.85, 0.0, nb.mul(nb.noise(pm.P, 800.0, 2.0, 0.6), 0.2)


def r_ink(nb, pm, p):
    """Painted / printed marks (stencils, label print): a flat colour, a little worn."""
    ao, cav, edge = _masks(nb, pm, p)
    base = nb.rgb(p.get("base", (0.7, 0.68, 0.62)))
    under = nb.rgb(p.get("under", (0.3, 0.3, 0.3)))
    wear = nb.sstep(nb.noise(pm.P, 220.0, 4.0, 0.7), p.get("wear_lo", 0.6), p.get("wear_lo", 0.6) + 0.08)
    col = nb.mix(nb.math("MAXIMUM", wear, nb.mul(edge, 0.6)), base, under)
    return col, p.get("rough", 0.7), 0.0, nb.mul(wear, -0.2)


RECIPES = {}


def family(name, recipe, **params):
    """Registers a material family (a recipe + its parameters) for every model."""
    RECIPES[name] = recipe
    _FAMILY_PARAMS[name] = params


_FAMILY_PARAMS = {}

# metals: base, tarnish (the mottled darker colour), polish (rubbed-bright edges), patina (in the cavities)
family("brass", r_metal, base=(0.6, 0.43, 0.2), tarnish=(0.36, 0.25, 0.11), polish=(0.85, 0.68, 0.38), patina=(0.12, 0.09, 0.05),
       rough=0.3, rough_tarnish=0.52, tarnish_amt=0.6, patina_cav=0.9, rough_patina=0.8)
family("bronze", r_metal, base=(0.42, 0.27, 0.13), tarnish=(0.24, 0.15, 0.07), polish=(0.78, 0.55, 0.3), patina=(0.2, 0.34, 0.29),
       rough=0.36, rough_tarnish=0.55, tarnish_amt=0.75, patina_cav=1.0, patina_patch=0.55, patina_scale=28.0, rough_patina=0.88)
family("bronze_cast", r_metal, base=(0.42, 0.27, 0.13), tarnish=(0.22, 0.14, 0.07), polish=(0.8, 0.57, 0.3), patina=(0.19, 0.33, 0.28),
       rough=0.4, rough_tarnish=0.6, tarnish_amt=0.8, patina_cav=1.0, patina_patch=0.5, hammered=True, hammer_scale=55.0, rough_patina=0.9)
family("copper", r_metal, base=(0.62, 0.32, 0.18), tarnish=(0.3, 0.15, 0.08), polish=(0.85, 0.5, 0.32), patina=(0.18, 0.3, 0.26),
       rough=0.3, rough_tarnish=0.5, tarnish_amt=0.65, patina_cav=0.6, rough_patina=0.85)
family("steel", r_metal, base=(0.2, 0.2, 0.21), tarnish=(0.12, 0.12, 0.13), polish=(0.55, 0.55, 0.56), patina=(0.24, 0.12, 0.06),
       rough=0.38, rough_tarnish=0.5, tarnish_amt=0.5, patina_cav=0.6, patina_patch=0.12, rough_patina=0.9)
family("iron", r_metal, base=(0.13, 0.12, 0.115), tarnish=(0.08, 0.075, 0.07), polish=(0.42, 0.41, 0.4), patina=(0.26, 0.12, 0.05),
       rough=0.55, rough_tarnish=0.7, tarnish_amt=0.6, patina_cav=0.9, patina_patch=0.3, patina_scale=24.0, rough_patina=0.92, metal=0.85)
family("chrome", r_metal, base=(0.55, 0.55, 0.56), tarnish=(0.4, 0.4, 0.4), polish=(0.75, 0.75, 0.76), patina=(0.2, 0.18, 0.15),
       rough=0.16, rough_tarnish=0.3, tarnish_amt=0.4, patina_cav=0.5, rough_patina=0.8)
family("paint_fieldgrey", r_paint, paint=(0.085, 0.092, 0.082), paint_var=(0.07, 0.076, 0.068), rough=0.62, chip_amt=1.0, rust_amt=0.6)
family("paint_navy", r_paint, paint=(0.075, 0.088, 0.105), paint_var=(0.062, 0.073, 0.088), rough=0.55, chip_amt=0.8, rust_amt=0.45)
family("paint_black", r_paint, paint=(0.045, 0.045, 0.05), paint_var=(0.06, 0.058, 0.055), rough=0.45, chip_amt=0.5, rust_amt=0.25,
       bare=(0.5, 0.45, 0.35))
family("paint_oxide", r_paint, paint=(0.3, 0.12, 0.08), paint_var=(0.26, 0.11, 0.08), rough=0.6, chip_amt=0.8, rust_amt=0.3)
family("wood", r_wood, dark=(0.15, 0.08, 0.042), light=(0.33, 0.185, 0.095), worn=(0.42, 0.27, 0.15), rough=0.48)
family("wood_dark", r_wood, dark=(0.08, 0.045, 0.028), light=(0.2, 0.11, 0.06), worn=(0.3, 0.19, 0.11), rough=0.42)
family("wood_pale", r_wood, dark=(0.15, 0.095, 0.052), light=(0.3, 0.2, 0.11), worn=(0.36, 0.26, 0.15), rough=0.6, grain="Z")
family("wood_handle", r_wood, dark=(0.1, 0.055, 0.03), light=(0.24, 0.13, 0.07), worn=(0.4, 0.26, 0.15), rough=0.32, grain="Y")
family("leather", r_leather, base=(0.11, 0.062, 0.036), dark=(0.06, 0.036, 0.024), worn=(0.2, 0.125, 0.075))
family("leather_black", r_leather, base=(0.034, 0.032, 0.03), dark=(0.026, 0.025, 0.024), worn=(0.085, 0.075, 0.065), rough=0.6, pebble=1400.0, bump=0.35)
family("porcelain", r_ceramic)
family("salt", r_ceramic, base=(0.74, 0.73, 0.69), rough=0.85)
family("rubber", r_rubber)
family("rope", r_cloth, base=(0.5, 0.41, 0.27), dark=(0.28, 0.22, 0.14), weave=500.0, rough=0.97)
family("felt", r_cloth, base=(0.2, 0.14, 0.13), dark=(0.12, 0.085, 0.08), weave=1500.0, rough=1.0, bump=0.25)
family("cloth_tape", r_cloth, base=(0.25, 0.23, 0.19), dark=(0.14, 0.13, 0.11), weave=1100.0, rough=0.95)
family("shellac", r_shellac, grooves=140.0)
family("paper", r_paper)
family("paint_white", r_ink, base=(0.72, 0.7, 0.64), under=(0.22, 0.235, 0.215))
family("ink_black", r_ink, base=(0.06, 0.055, 0.05), under=(0.6, 0.53, 0.4), wear_lo=0.72, rough=0.6)
family("enamel_cream", r_ink, base=(0.78, 0.74, 0.62), under=(0.2, 0.2, 0.2), wear_lo=0.75, rough=0.3)


def use_family_params(model):
    model.family_params = _FAMILY_PARAMS

