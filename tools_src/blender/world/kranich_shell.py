"""Der Kranich's inner shell (UPDATE 09 section 5.3, DECISIONS T-147): the flying wing's structure around Act II's rooms.

    blender -b -P tools_src/blender/world/kranich_shell.py            (tools/build_kranich_shell.sh runs it)

Writes one GLB per room, assets/ours/world/kranich_<room>/model.glb (+ LICENSE.txt / SOURCE.txt, "Ours"):
  bay (A Bombenschacht), body (B Mittelrumpf), wing_l / wing_r (C Fluegel), nacelle (D Triebwerk + the port
  walkway), kanzel (E Kanzel + the starboard walkway), cockpit (F).
Every piece is in the MAP's frame (gen_map04b.gd: +Z the nose, aft at z = 0, +X starboard, the deck at y = 0), so the
game places each GLB at the origin. The shell is VISUAL ONLY and sits on or outside the generator's collision walls
(gen_map04b keeps every collider; it only hides the flat wall meshes): a frame's inner flange lies on the wall's room
face, the skin 0.6 m behind it where the outside is not walkable ("deep"), or on the face itself where another room is
on the other side ("flat": the bulkhead plate, stiffeners 5 cm proud). Doors, windows, the core window, the breach
panels, the blisters and the flight deck's glass are openings in the shell exactly over the generator's openings.

What a room is made of (the Kranich brief, docs/MAPS_3_4_REBUILD.md section 3):
  frames   curved ribs every 1.5 m (4/3 m in the wings, so every third one stands on a collider stub), an I-section:
           a web with lightening holes (octagons) and an inner flange, vertical up the walls, then an elliptic arch
  skin     the panels between the frames, UVs in metres along (frame axis, profile arc) so kranich_skin.gdshader
           draws the rivet rows on the frame lines, the stringer rows and the sheet seams
  stringers  Z-section stiffeners along the frame axis every ~0.55 m of profile, broken at the openings
  ends     the bulkheads at each end of a room (door coamings, the four blister rings, the flight-deck glazing)
  floor    the bay doors and catwalk grating over the open bay (and its breach), the floor plates elsewhere
Material slots (gravelight/world/map04/kranich_shell.gd maps them): kskin (the riveted skin), kframe (frames,
stringers, coamings: painted steel, no rivets), kgrate (catwalk grating, alpha), kglass (perspex), kdark (the
sub-floor), lib_deck_plate (diamond plate, MaterialLibrary), mats_rubber.
"""
import datetime
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

T = 0.3             # the generator's wall thickness
DEEP = 0.6          # skin behind the wall's room face where the outside is free
ARC_DEPTH = 0.32    # frame depth along the arch
FLANGE = 0.09       # inner flange width (along the frame axis)
WEB = 0.008         # web half thickness
HOLE_SEGS = 8


def V3(x, y, z):
    return Vector((float(x), float(y), float(z)))


# ================================================================== mesh builder (Godot frame)

class MB:
    """Collects quads/tris in Godot's frame with explicit facing and per-corner UVs; to_object() converts to Blender."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.uvs = []
        self.mats = []
        self.fmat = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def poly(self, pts, uvs, m, facing=None):
        pts = [Vector(p) for p in pts]
        uvs = list(uvs)
        if facing is not None and len(pts) >= 3:
            n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if n.length < 1e-9 and len(pts) > 3:
                n = (pts[2] - pts[0]).cross(pts[3] - pts[0])
            if n.dot(Vector(facing)) < 0.0:
                pts.reverse()
                uvs.reverse()
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(base, base + len(pts))))
        self.uvs.append(uvs)
        self.fmat.append(self._mi(m))

    def quad2(self, pts, uvs, m, facing, both=False, thick=0.0):
        """A quad; both=True adds the back face (offset by thick along -facing)."""
        self.poly(pts, uvs, m, facing)
        if both:
            f = Vector(facing).normalized() * thick
            self.poly([Vector(p) - f for p in pts], uvs, m, -Vector(facing))

    def box(self, lo, hi, m, skip=()):
        lo = Vector(lo)
        hi = Vector(hi)
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        faces = {
            "+x": ([V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1), V3(x1, y0, z1)], (1, 0, 0)),
            "-x": ([V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0)], (-1, 0, 0)),
            "+y": ([V3(x0, y1, z0), V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0)], (0, 1, 0)),
            "-y": ([V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)], (0, -1, 0)),
            "+z": ([V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1)], (0, 0, 1)),
            "-z": ([V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0), V3(x1, y0, z0)], (0, 0, -1)),
        }
        for k, (pts, n) in faces.items():
            if k in skip:
                continue
            self.poly(pts, [boxuv(p, n) for p in pts], m, n)

    def obox(self, c, ax, half, m):
        """Oriented box: centre c, axes ax = (u, v, w) unit vectors, half sizes (hu, hv, hw)."""
        c = Vector(c)
        u, v, w = (Vector(a).normalized() for a in ax)
        hu, hv, hw = half
        corners = {}
        for i in (-1, 1):
            for j in (-1, 1):
                for k in (-1, 1):
                    corners[(i, j, k)] = c + u * hu * i + v * hv * j + w * hw * k
        for axis, vec in ((0, u), (1, v), (2, w)):
            for s in (-1, 1):
                pts = []
                for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis] = s
                    others = [q for q in range(3) if q != axis]
                    key[others[0]] = a
                    key[others[1]] = b
                    pts.append(corners[tuple(key)])
                n = vec * s
                self.poly(pts, [boxuv(p, n) for p in pts], m, n)

    def tube(self, a, b, r, m, segs=6):
        a = Vector(a)
        b = Vector(b)
        d = (b - a)
        if d.length < 1e-6:
            return
        d.normalize()
        up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        u = d.cross(up).normalized()
        v = d.cross(u).normalized()
        L = (b - a).length
        for i in range(segs):
            t0 = 2 * math.pi * i / segs
            t1 = 2 * math.pi * (i + 1) / segs
            n0 = u * math.cos(t0) + v * math.sin(t0)
            n1 = u * math.cos(t1) + v * math.sin(t1)
            pts = [a + n0 * r, b + n0 * r, b + n1 * r, a + n1 * r]
            uvs = [(0, t0 * r), (L, t0 * r), (L, t1 * r), (0, t1 * r)]
            self.poly(pts, uvs, m, (n0 + n1) * 0.5)

    def plate_hole(self, corners, center, radius, m, normal, uvf, both=True, segs=HOLE_SEGS):
        """A flat convex quad (corners in order) with a round hole (a lightening hole / porthole): quads between the
        hole's polygon and the quad's boundary, the boundary point found by casting from the centre."""
        corners = [Vector(c) for c in corners]
        center = Vector(center)
        normal = Vector(normal).normalized()
        e1 = (corners[1] - corners[0]).normalized()
        e2 = normal.cross(e1).normalized()
        poly2 = [((c - center).dot(e1), (c - center).dot(e2)) for c in corners]
        inner = []
        outer = []
        for i in range(segs):
            th = 2 * math.pi * (i + 0.5) / segs
            dx, dy = math.cos(th), math.sin(th)
            inner.append(center + e1 * dx * radius + e2 * dy * radius)
            tbest = 1e9
            for k in range(len(poly2)):
                ax, ay = poly2[k]
                bx, by = poly2[(k + 1) % len(poly2)]
                ex, ey = bx - ax, by - ay
                den = dx * ey - dy * ex
                if abs(den) < 1e-9:
                    continue
                t = (ax * ey - ay * ex) / den
                s = (ax * dy - ay * dx) / den
                if t > 0 and -1e-6 <= s <= 1 + 1e-6:
                    tbest = min(tbest, t)
            outer.append(center + e1 * dx * tbest + e2 * dy * tbest)
        # the quad's corners: a fan from each corner to the two outer points around it
        for i in range(segs):
            j = (i + 1) % segs
            pts = [inner[i], outer[i], outer[j], inner[j]]
            self.quad2(pts, [uvf(p) for p in pts], m, normal, both, WEB * 2)
        for c in corners:
            # the outer ring point pair that brackets this corner
            ang = math.atan2((c - center).dot(e2), (c - center).dot(e1))
            k = int(math.floor((ang / (2 * math.pi)) * segs - 0.5)) % segs
            k2 = (k + 1) % segs
            pts = [outer[k], c, outer[k2]]
            self.quad2(pts, [uvf(p) for p in pts], m, normal, both, WEB * 2)

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)

    def to_object(self):
        """Links the mesh; perspex faces (kglass) go to their own object '<name>_Glass' (the game turns its shadows off)."""
        if not self.faces:
            return None
        if "kglass" in self.mats and len(self.mats) > 1:
            gi = self.mats.index("kglass")
            a, b = MB(self.name), MB(self.name + "_Glass")
            for fi, f in enumerate(self.faces):
                dst = b if self.fmat[fi] == gi else a
                dst.poly([self.verts[k] for k in f], self.uvs[fi], self.mats[self.fmat[fi]])
            a.to_object()
            return b.to_object()
        if self.mats == ["kglass"] and not self.name.endswith("_Glass"):
            self.name += "_Glass"
        g2b = W.G2B
        bverts = [tuple((g2b @ Vector((v.x, v.y, v.z, 1.0))).to_3d()) for v in self.verts]
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(bverts, [], self.faces)
        me.update()
        uvl = me.uv_layers.new(name="UVMap")
        li = 0
        for fi, poly in enumerate(me.polygons):
            poly.material_index = self.fmat[fi]
            poly.use_smooth = False
            for k, loop_index in enumerate(poly.loop_indices):
                uvl.data[loop_index].uv = self.uvs[fi][k]
                li += 1
        for m in self.mats:
            me.materials.append(W.mat(m))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def boxuv(p, n):
    n = Vector(n)
    ax = max(range(3), key=lambda k: abs(n[k]))
    if ax == 0:
        return ((-p.z if n.x > 0 else p.z), p.y)
    if ax == 1:
        return (p.x, (p.z if n.y > 0 else -p.z))
    return ((p.x if n.z > 0 else -p.x), p.y)


# ================================================================== a room section

class Section:
    """A vaulted room: frames along `axis` ('z' or 'x') between a0..a1, lateral centre c (x for axis z, z for axis x).
    sides[s] (s = -1 / +1): {"face": room face (lateral coord), "ranges": [(a_lo, a_hi, mode)], mode deep|flat|open,
    "open_top": y of the header over an open range, "openings": [(a_lo, a_hi, y_lo, y_hi, kind)]}."""

    def __init__(self, name, axis, a0, a1, c, wall_top, crown, pitch, sides, stations=None):
        self.name = name
        self.axis = axis
        self.a0, self.a1 = a0, a1
        self.c = c
        self.wall_top = wall_top
        self.crown = crown
        self.pitch = pitch
        self.sides = sides
        if stations is None:
            n = int(math.floor((a1 - a0) / pitch + 1e-6))
            first = a0 + ((a1 - a0) - n * pitch) * 0.5
            stations = [first + i * pitch for i in range(n + 1)]
        self.stations = [s for s in stations if a0 + 0.05 < s < a1 - 0.05]
        self.glass_arc = []   # [(a_lo, a_hi, phi_min)]: skin bays glazed over the arch (the flight deck's brow)

    # coordinate helpers
    def P(self, a, l, y):
        return V3(l, y, a) if self.axis == "z" else V3(a, y, l)

    def A(self):
        return V3(0, 0, 1) if self.axis == "z" else V3(1, 0, 0)

    def L(self):
        return V3(1, 0, 0) if self.axis == "z" else V3(0, 0, 1)

    def mode(self, s, a):
        for (lo, hi, md) in self.sides[s]["ranges"]:
            if lo - 1e-6 <= a <= hi + 1e-6:
                return md
        return "deep"

    def face(self, s):
        return self.sides[s]["face"]

    def skin_l(self, s):
        return self.face(s) + s * DEEP

    def arc_pt(self, s, phi, inner=False):
        half = abs(self.skin_l(s) - self.c)
        top = self.crown
        if inner:
            half = abs(self.face(s) - self.c)
            top = self.crown - ARC_DEPTH
        return (self.c + s * half * math.cos(phi), self.wall_top + (top - self.wall_top) * math.sin(phi))

    def openings(self, s):
        return self.sides[s].get("openings", [])

    def build(self, skin, frames):
        self._skin(skin)
        self._frames(frames)
        self._stringers(frames)

    # ---------------------------------------------------------------- skin
    def _bounds(self, s):
        b = set([self.a0, self.a1] + self.stations)
        for (lo, hi, _y0, _y1, _k) in self.openings(s):
            b.add(lo)
            b.add(hi)
        for (lo, hi, _md) in self.sides[s]["ranges"]:
            b.add(max(self.a0, min(self.a1, lo)))
            b.add(max(self.a0, min(self.a1, hi)))
        for (lo, hi, _p) in self.glass_arc:
            b.add(lo)
            b.add(hi)
        return sorted(x for x in b if self.a0 - 1e-6 <= x <= self.a1 + 1e-6)

    def _ylevels(self, s):
        ys = {0.0, self.wall_top, 0.9, 1.8}
        for (_lo, _hi, y0, y1, _k) in self.openings(s):
            ys.add(max(0.0, min(self.wall_top, y0)))
            ys.add(max(0.0, min(self.wall_top, y1)))
        ot = self.sides[s].get("open_top")
        if ot is not None:
            ys.add(min(self.wall_top, ot))
        return sorted(y for y in ys if 0.0 <= y <= self.wall_top)

    def _in_opening(self, s, a, y):
        for (lo, hi, y0, y1, _k) in self.openings(s):
            if lo + 1e-4 < a < hi - 1e-4 and y0 + 1e-4 < y < y1 - 1e-4:
                return True
        return False

    def _skin(self, mb):
        A = self.A()
        for s in (-1, 1):
            inward = self.L() * (-s)
            bounds = self._bounds(s)
            ys = self._ylevels(s)
            for i in range(len(bounds) - 1):
                a_lo, a_hi = bounds[i], bounds[i + 1]
                if a_hi - a_lo < 1e-4:
                    continue
                am = (a_lo + a_hi) * 0.5
                md = self.mode(s, am)
                l = self.skin_l(s) if md == "deep" else self.face(s)
                # the vertical part
                for j in range(len(ys) - 1):
                    y0, y1 = ys[j], ys[j + 1]
                    ym = (y0 + y1) * 0.5
                    if self._in_opening(s, am, ym):
                        continue
                    if md == "open" and ym < self.sides[s].get("open_top", 0.0):
                        continue
                    pts = [self.P(a_lo, l, y0), self.P(a_hi, l, y0), self.P(a_hi, l, y1), self.P(a_lo, l, y1)]
                    uvs = [(a_lo, y0), (a_hi, y0), (a_hi, y1), (a_lo, y1)]
                    mb.poly(pts, uvs, "kskin", inward)
                if md in ("flat", "open"):
                    # the ledge from the bulkhead's top to the arch's foot (seen from below)
                    pts = [self.P(a_lo, self.face(s), self.wall_top), self.P(a_hi, self.face(s), self.wall_top),
                           self.P(a_hi, self.skin_l(s), self.wall_top), self.P(a_lo, self.skin_l(s), self.wall_top)]
                    mb.poly(pts, [(a_lo, 0), (a_hi, 0), (a_hi, DEEP), (a_lo, DEEP)], "kframe", V3(0, -1, 0))
                # the arch
                n = 12
                tacc = self.wall_top
                prev = self.arc_pt(s, 0.0)
                for k in range(n):
                    p0 = self.arc_pt(s, math.pi * 0.5 * k / n)
                    p1 = self.arc_pt(s, math.pi * 0.5 * (k + 1) / n)
                    seg = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
                    pts = [self.P(a_lo, p0[0], p0[1]), self.P(a_hi, p0[0], p0[1]), self.P(a_hi, p1[0], p1[1]), self.P(a_lo, p1[0], p1[1])]
                    uvs = [(a_lo, tacc), (a_hi, tacc), (a_hi, tacc + seg), (a_lo, tacc + seg)]
                    # facing: toward the room's inside (down-inward)
                    mid = (Vector(pts[0]) + Vector(pts[2])) * 0.5
                    ctr = self.P(am, self.c, self.wall_top * 0.5)
                    glazed = any(lo - 1e-4 <= am <= hi + 1e-4 and math.pi * 0.5 * k / n >= phi for (lo, hi, phi) in self.glass_arc)
                    mb.poly(pts, uvs, "kglass" if glazed else "kskin", ctr - mid)
                    tacc += seg
                    prev = p1
            # cap the skin's end edges where a deep range meets a flat one (a short return plate)
            for (lo, hi, md) in self.sides[s]["ranges"]:
                if md == "deep":
                    continue
                for a in (lo, hi):
                    if self.a0 + 1e-3 < a < self.a1 - 1e-3:
                        top = self.wall_top if md == "flat" else self.wall_top
                        bot = 0.0 if md == "flat" else self.sides[s].get("open_top", 0.0)
                        pts = [self.P(a, self.face(s), bot), self.P(a, self.skin_l(s), bot), self.P(a, self.skin_l(s), top), self.P(a, self.face(s), top)]
                        dirn = A * (1 if a == lo else -1)
                        mb.quad2(pts, [(0, bot), (DEEP, bot), (DEEP, top), (0, top)], "kframe", -dirn, both=True, thick=0.01)

    # ---------------------------------------------------------------- frames
    def _uvf(self, a):
        def f(p):
            q = Vector(p)
            l = q.x if self.axis == "z" else q.z
            return (l, q.y)
        return f

    def _frames(self, mb):
        A = self.A()
        for a in self.stations:
            for s in (-1, 1):
                md = self.mode(s, a)
                blocked = any(lo - 0.12 < a < hi + 0.12 and y0 < self.wall_top - 0.05 for (lo, hi, y0, y1, _k) in self.openings(s))
                if md == "deep" and not blocked:
                    self._web_vertical(mb, a, s)
                elif md == "flat" and not blocked:
                    # a stiffener on the bulkhead, 5 cm proud
                    f = self.face(s)
                    lo = self.P(a - 0.04, f, 0.0)
                    hi = self.P(a + 0.04, f - s * 0.05, self.wall_top)
                    mb.box(_mn(lo, hi), _mx(lo, hi), "kframe")
                self._web_arc(mb, a, s)
            # floor beam cap: a flush strip across the deck (the frame's bottom chord)
        return None

    def _web_vertical(self, mb, a, s):
        f = self.face(s)
        sk = self.skin_l(s)
        A = self.A()
        uvf = self._uvf(a)
        d = abs(sk - f)
        y = 0.0
        cell = d
        k = 0
        while y + cell <= self.wall_top + 1e-6:
            y1 = y + cell
            corners = [self.P(a, f, y), self.P(a, sk, y), self.P(a, sk, y1), self.P(a, f, y1)]
            if k % 2 == 1 and y > 0.2:
                ctr = self.P(a, (f + sk) * 0.5, (y + y1) * 0.5)
                mb.plate_hole(corners, ctr, cell * 0.3, "kframe", A, uvf)
            else:
                mb.quad2(corners, [uvf(p) for p in corners], "kframe", A, True, WEB * 2)
            y = y1
            k += 1
        if y < self.wall_top - 1e-4:
            corners = [self.P(a, f, y), self.P(a, sk, y), self.P(a, sk, self.wall_top), self.P(a, f, self.wall_top)]
            mb.quad2(corners, [uvf(p) for p in corners], "kframe", A, True, WEB * 2)
        # the inner flange on the room face
        lo = self.P(a - FLANGE * 0.5, f, 0.0)
        hi = self.P(a + FLANGE * 0.5, f + s * 0.012, self.wall_top)
        mb.box(_mn(lo, hi), _mx(lo, hi), "kframe")

    def _web_arc(self, mb, a, s):
        A = self.A()
        uvf = self._uvf(a)
        n = 12
        for k in range(n):
            ph0 = math.pi * 0.5 * k / n
            ph1 = math.pi * 0.5 * (k + 1) / n
            o0, o1 = self.arc_pt(s, ph0), self.arc_pt(s, ph1)
            i0, i1 = self.arc_pt(s, ph0, True), self.arc_pt(s, ph1, True)
            corners = [self.P(a, i0[0], i0[1]), self.P(a, o0[0], o0[1]), self.P(a, o1[0], o1[1]), self.P(a, i1[0], i1[1])]
            if k % 2 == 1:
                ctr = (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
                r = min((corners[1] - corners[0]).length, (corners[3] - corners[0]).length) * 0.3
                mb.plate_hole(corners, ctr, r, "kframe", A, uvf)
            else:
                mb.quad2(corners, [uvf(p) for p in corners], "kframe", A, True, WEB * 2)
            # inner flange strip (facing the room)
            q0 = self.P(a - FLANGE * 0.5, i0[0], i0[1])
            q1 = self.P(a + FLANGE * 0.5, i0[0], i0[1])
            q2 = self.P(a + FLANGE * 0.5, i1[0], i1[1])
            q3 = self.P(a - FLANGE * 0.5, i1[0], i1[1])
            ctr2 = self.P(a, self.c, self.wall_top * 0.5)
            mid = (q0 + q2) * 0.5
            mb.poly([q0, q1, q2, q3], [boxuv(p, ctr2 - mid) for p in (q0, q1, q2, q3)], "kframe", ctr2 - mid)

    # ---------------------------------------------------------------- stringers
    def _stringers(self, mb):
        for s in (-1, 1):
            # vertical part: every 0.55 m (deep ranges only; the bulkheads have their stiffeners)
            ys = []
            y = 0.45
            while y < self.wall_top - 0.15:
                ys.append(y)
                y += 0.55
            for yy in ys:
                self._stringer_run(mb, s, lambda a, yy=yy: (self.skin_l(s), yy), deep_only=True, y_check=yy)
            # the arch: at phi steps
            for k in range(1, 8):
                ph = math.pi * 0.5 * k / 8
                self._stringer_run(mb, s, lambda a, ph=ph: self.arc_pt(s, ph), deep_only=False, y_check=None)

    def _stringer_run(self, mb, s, at, deep_only, y_check):
        # split the run [a0, a1] at openings (vertical part) and non-deep ranges
        cuts = [(self.a0, self.a1)]
        bad = []
        if deep_only:
            for (lo, hi, md) in self.sides[s]["ranges"]:
                if md != "deep":
                    bad.append((lo, hi))
            for (lo, hi, y0, y1, _k) in self.openings(s):
                if y_check is not None and y0 - 0.06 <= y_check <= y1 + 0.06:
                    bad.append((lo - 0.05, hi + 0.05))
        for (lo, hi) in bad:
            nxt = []
            for (c0, c1) in cuts:
                if hi <= c0 or lo >= c1:
                    nxt.append((c0, c1))
                    continue
                if lo > c0:
                    nxt.append((c0, lo))
                if hi < c1:
                    nxt.append((hi, c1))
            cuts = nxt
        for (c0, c1) in cuts:
            if c1 - c0 < 0.2:
                continue
            l, y = at(0.0)
            # a 4 x 3 cm stiffener just inside the skin
            inward = -s * 0.03
            p0 = self.P(c0, l + inward, y - 0.02)
            p1 = self.P(c1, l, y + 0.02)
            mb.box(_mn(p0, p1), _mx(p0, p1), "kframe", skip=())


def _mn(a, b):
    return V3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))


def _mx(a, b):
    return V3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z))


# ================================================================== end walls (bulkheads)

def end_wall(mb, axis, a, facing_sign, outline, holes, y_top, mat="kskin", ylevels=None):
    """A bulkhead in the plane axis = a (z or x), facing +/- along the axis. outline(y) -> (l_lo, l_hi) for
    0 <= y <= y_top; holes = [(y0, y1, fn(y) -> (h_lo, h_hi))]. Bands between y levels, each band split by holes."""
    ys = set(ylevels or [])
    ys.update([0.0, y_top])
    k = 0.0
    while k < y_top:
        ys.add(k)
        k += 0.25
    for (y0, y1, _f) in holes:
        ys.add(y0)
        ys.add(y1)
        steps = 10
        for i in range(steps + 1):
            ys.add(y0 + (y1 - y0) * i / steps)
    ys = sorted(y for y in ys if 0.0 <= y <= y_top)
    facing = V3(0, 0, facing_sign) if axis == "z" else V3(facing_sign, 0, 0)

    def P(l, y):
        return V3(l, y, a) if axis == "z" else V3(a, y, l)

    for i in range(len(ys) - 1):
        y0, y1 = ys[i], ys[i + 1]
        ym = (y0 + y1) * 0.5
        lo0, hi0 = outline(y0)
        lo1, hi1 = outline(y1)
        # holes active in this band (by its middle)
        segs0 = [(lo0, hi0)]
        segs1 = [(lo1, hi1)]
        for (hy0, hy1, fn) in holes:
            if hy0 - 1e-6 <= ym <= hy1 + 1e-6:
                h0 = fn(min(max(y0, hy0), hy1))
                h1 = fn(min(max(y1, hy0), hy1))
                segs0 = _cut(segs0, h0)
                segs1 = _cut(segs1, h1)
        for (s0, s1) in zip(segs0, segs1):
            pts = [P(s0[0], y0), P(s0[1], y0), P(s1[1], y1), P(s1[0], y1)]
            uvs = [(s0[0], y0), (s0[1], y0), (s1[1], y1), (s1[0], y1)]
            if abs(s0[1] - s0[0]) < 1e-4 and abs(s1[1] - s1[0]) < 1e-4:
                continue
            mb.poly(pts, uvs, mat, facing)


def _cut(segs, h):
    out = []
    for (a, b) in segs:
        if h[1] <= a or h[0] >= b:
            out.append((a, b))
            continue
        if h[0] > a:
            out.append((a, h[0]))
        else:
            out.append((a, a))
        if h[1] < b:
            out.append((h[1], b))
        else:
            out.append((b, b))
    return out


def rect_hole(l0, l1):
    return lambda y: (l0, l1)


def circle_hole(lc, yc, r):
    def f(y):
        dy = max(-r, min(r, y - yc))
        w = math.sqrt(max(0.0, r * r - dy * dy))
        return (lc - w, lc + w)
    return f


def arch_hole(sec):
    """The section's own profile as a hole (a walkway's arch seen from the next room)."""
    def f(y):
        return section_outline(sec)(y)
    return f


def section_outline(sec, end_a=None):
    """outline(y) of a section's cross-section: the side lines (skin if deep at that end, face if flat), the arch."""
    def side_l(s):
        a = sec.a0 if end_a is None else end_a
        return sec.skin_l(s) if sec.mode(s, a) == "deep" else sec.face(s)

    def f(y):
        res = []
        for s in (-1, 1):
            if y <= sec.wall_top:
                res.append(side_l(s) if y < sec.wall_top - 1e-6 else sec.skin_l(s))
            else:
                half = abs(sec.skin_l(s) - sec.c)
                k = (y - sec.wall_top) / max(1e-6, sec.crown - sec.wall_top)
                k = min(1.0, max(0.0, k))
                res.append(sec.c + s * half * math.sqrt(max(0.0, 1.0 - k * k)))
        return (min(res), max(res))
    return f


def coaming(mb, axis, a_face, a_back, l0, l1, y0, y1, mat="kframe"):
    """The lining of a rectangular opening through a wall: 4 plates from a_face to a_back (along the wall normal)."""
    def P(n, l, y):
        return V3(l, y, n) if axis == "z" else V3(n, y, l)
    n0, n1 = min(a_face, a_back), max(a_face, a_back)
    lc, yc = (l0 + l1) * 0.5, (y0 + y1) * 0.5
    sides = [
        ([P(n0, l0, y0), P(n1, l0, y0), P(n1, l1, y0), P(n0, l1, y0)], P(0, lc, yc) - P(0, lc, y0)),
        ([P(n0, l0, y1), P(n1, l0, y1), P(n1, l1, y1), P(n0, l1, y1)], P(0, lc, yc) - P(0, lc, y1)),
        ([P(n0, l0, y0), P(n1, l0, y0), P(n1, l0, y1), P(n0, l0, y1)], P(0, lc, yc) - P(0, l0, yc)),
        ([P(n0, l1, y0), P(n1, l1, y0), P(n1, l1, y1), P(n0, l1, y1)], P(0, lc, yc) - P(0, l1, yc)),
    ]
    for pts, n in sides:
        mb.poly(pts, [boxuv(p, n) for p in pts], mat, n)


def wall_coaming_side(mb, sec, s, lo, hi, y0, y1):
    """Lining for an opening in a section's side wall (from the room face to the skin, or through the bulkhead)."""
    f = sec.face(s)
    md = sec.mode(s, (lo + hi) * 0.5)
    back = sec.skin_l(s) if md == "deep" else f + s * T
    if sec.axis == "z":
        # side walls are x = const planes; the opening spans z lo..hi
        _coaming_x(mb, f, back, lo, hi, y0, y1)
    else:
        _coaming_z(mb, f, back, lo, hi, y0, y1)


def _coaming_x(mb, x0, x1, z0, z1, y0, y1, mat="kframe"):
    xa, xb = min(x0, x1), max(x0, x1)
    zc, yc = (z0 + z1) * 0.5, (y0 + y1) * 0.5
    mb.poly([V3(xa, y0, z0), V3(xb, y0, z0), V3(xb, y0, z1), V3(xa, y0, z1)], [(0, 0)] * 4, mat, (0, 1, 0))
    mb.poly([V3(xa, y1, z0), V3(xb, y1, z0), V3(xb, y1, z1), V3(xa, y1, z1)], [(0, 0)] * 4, mat, (0, -1, 0))
    for z, n in ((z0, 1), (z1, -1)):
        pts = [V3(xa, y0, z), V3(xb, y0, z), V3(xb, y1, z), V3(xa, y1, z)]
        mb.poly(pts, [boxuv(p, (0, 0, n)) for p in pts], mat, (0, 0, n))


def _coaming_z(mb, z0, z1, x0, x1, y0, y1, mat="kframe"):
    za, zb = min(z0, z1), max(z0, z1)
    mb.poly([V3(x0, y0, za), V3(x1, y0, za), V3(x1, y0, zb), V3(x0, y0, zb)], [(0, 0)] * 4, mat, (0, 1, 0))
    mb.poly([V3(x0, y1, za), V3(x1, y1, za), V3(x1, y1, zb), V3(x0, y1, zb)], [(0, 0)] * 4, mat, (0, -1, 0))
    for x, n in ((x0, 1), (x1, -1)):
        pts = [V3(x, y0, za), V3(x, y0, zb), V3(x, y1, zb), V3(x, y1, za)]
        mb.poly(pts, [boxuv(p, (n, 0, 0)) for p in pts], mat, (n, 0, 0))


def door_frame(mb, axis, a, facing_sign, lc, w=2.0, h=2.4, depth=0.12):
    """A riveted coaming round a hatch in a bulkhead: a flat ring 0.14 wide, `depth` proud on the facing side."""
    def P(l, y, n):
        return V3(l, y, a + facing_sign * n) if axis == "z" else V3(a + facing_sign * n, y, l)
    l0, l1 = lc - w * 0.5, lc + w * 0.5
    b = 0.14
    for (pl0, pl1, py0, py1) in ((l0 - b, l0, 0.0, h + b), (l1, l1 + b, 0.0, h + b), (l0, l1, h, h + b)):
        lo = P(pl0, py0, 0.0)
        hi = P(pl1, py1, depth)
        mb.box(_mn(lo, hi), _mx(lo, hi), "kframe")


# ================================================================== floors

def floor_rect(mb, x0, x1, z0, z1, mat, y=0.0, holes=()):
    """A floor quad (facing up) with rectangular holes (split into strips)."""
    xs = sorted({x0, x1} | {h[0] for h in holes} | {h[1] for h in holes})
    zs = sorted({z0, z1} | {h[2] for h in holes} | {h[3] for h in holes})
    xs = [x for x in xs if x0 - 1e-6 <= x <= x1 + 1e-6]
    zs = [z for z in zs if z0 - 1e-6 <= z <= z1 + 1e-6]
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            xm = (xs[i] + xs[i + 1]) * 0.5
            zm = (zs[j] + zs[j + 1]) * 0.5
            if any(h[0] < xm < h[1] and h[2] < zm < h[3] for h in holes):
                continue
            pts = [V3(xs[i], y, zs[j]), V3(xs[i + 1], y, zs[j]), V3(xs[i + 1], y, zs[j + 1]), V3(xs[i], y, zs[j + 1])]
            mb.poly(pts, [(p.x, p.z) for p in pts], mat, (0, 1, 0))


def floor_beams(mb, axis, stations, l0, l1, y=0.0, mat="kframe"):
    """Flush strips across the floor at the frame stations (the frames' bottom chords)."""
    for a in stations:
        if axis == "z":
            mb.box(V3(l0, y - 0.01, a - 0.05), V3(l1, y + 0.012, a + 0.05), mat, skip=("-y",))
        else:
            mb.box(V3(a - 0.05, y - 0.01, l0), V3(a + 0.05, y + 0.012, l1), mat, skip=("-y",))


def grating_floor(mb, x0, x1, z0, z1, y=0.0, sub_y=-0.45, beam_axis="z", beam_pitch=1.5):
    """Catwalk grating over a dark sub-floor with its beams (the bay's sides, the blister gallery)."""
    floor_rect(mb, x0, x1, z0, z1, "kgrate", y)
    floor_rect(mb, x0, x1, z0, z1, "kdark", sub_y)
    if beam_axis == "z":
        z = z0 + beam_pitch * 0.5
        while z < z1:
            mb.box(V3(x0, sub_y, z - 0.04), V3(x1, y - 0.03, z + 0.04), "kframe")
            z += beam_pitch
    else:
        x = x0 + beam_pitch * 0.5
        while x < x1:
            mb.box(V3(x - 0.04, sub_y, z0), V3(x + 0.04, y - 0.03, z1), "kframe")
            x += beam_pitch
    # the stringers the grating sits on, along the run
    for xx in (x0 + 0.05, x1 - 0.05):
        mb.box(V3(xx - 0.05, sub_y, z0), V3(xx + 0.05, y - 0.03, z1), "kframe")


# ================================================================== the rooms

def room_bay():
    skin, fr, fl = MB("Skin"), MB("Frames"), MB("Floor")
    sides = {
        -1: {"face": -9.0 + T * 0.5, "ranges": [], "openings": [(11.2, 12.8, 0.9, 2.2, "window"), (2.75, 3.25, 1.4, 1.9, "port"), (20.75, 21.25, 1.4, 1.9, "port")]},
        1: {"face": 9.0 - T * 0.5, "ranges": [], "openings": [(11.2, 12.8, 0.9, 2.2, "window"), (2.75, 3.25, 1.4, 1.9, "port"), (20.75, 21.25, 1.4, 1.9, "port")]},
    }
    # flip: the side's face is its room face (x = -8.85 for the port side, +8.85 starboard)
    sides[-1]["face"] = -8.85
    sides[1]["face"] = 8.85
    sec = Section("bay", "z", T * 0.5, 24.0 - T * 0.5, 0.0, 2.8, 5.15, 1.5, sides)
    sec.build(skin, fr)
    for s in (-1, 1):
        for (lo, hi, y0, y1, k) in sides[s]["openings"]:
            wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
            if k == "port":
                porthole(fr, skin, V3(s * (8.85 + DEEP), (y0 + y1) * 0.5, (lo + hi) * 0.5), V3(-s, 0, 0))
    # aft bulkhead (the ramp's frame, z = 0.15) and the forward one (z = 23.85, the hatch into the centre body)
    end_wall(skin, "z", T * 0.5, 1, section_outline(sec, sec.a0), [], sec.crown)
    end_wall(skin, "z", 24.0 - T * 0.5, -1, section_outline(sec, sec.a1), [(0.0, 2.4, rect_hole(-1.0, 1.0))], sec.crown, ylevels=[2.4])
    door_frame(fr, "z", 24.0 - T * 0.5, -1, 0.0)
    coaming(fr, "z", 24.0 - T * 0.5, 24.0 + T * 0.5, -1.0, 1.0, 0.0, 2.4)
    # the floor: two bay-door leaves down the middle (a breach torn in the port leaf, aft), grating catwalks each side
    breach = (-2.6, 0.4, 1.6, 4.6)
    floor_rect(fl, -3.6, 3.6, T * 0.5, 24.0 - T * 0.5, "kskin", 0.0, holes=[breach])
    grating_floor(fl, -8.85, -3.6, T * 0.5, 24.0 - T * 0.5)
    grating_floor(fl, 3.6, 8.85, T * 0.5, 24.0 - T * 0.5)
    # the door seam and the hinge lines (raised strips), the breach's torn edges and the grating laid over it
    fl.box(V3(-0.03, -0.01, 0.4), V3(0.03, 0.015, 23.6), "kframe", skip=("-y",))
    for x in (-3.6, 3.6):
        fl.box(V3(x - 0.07, -0.01, 0.2), V3(x + 0.07, 0.03, 23.8), "kframe", skip=("-y",))
    floor_rect(fl, breach[0], breach[1], breach[2], breach[3], "kgrate", 0.0)
    torn_edges(fl, breach)
    exports = [("kranich_bay", "Der Kranich: aft bomb bay shell", "frames, riveted skin, stringers, the ramp and hatch bulkheads, the bay doors with a breach, catwalk grating", [skin, fr, fl])]
    return exports


def torn_edges(mb, r):
    """Jagged flaps of the bay door bent down round a breach (x0, x1, z0, z1)."""
    x0, x1, z0, z1 = r
    k = 0
    for side in range(4):
        n = 5
        for i in range(n):
            t0 = i / n
            t1 = (i + 1) / n
            if side == 0:
                a, b = V3(x0 + (x1 - x0) * t0, 0, z0), V3(x0 + (x1 - x0) * t1, 0, z0)
                out = V3(0, 0, 1)
            elif side == 1:
                a, b = V3(x0 + (x1 - x0) * t0, 0, z1), V3(x0 + (x1 - x0) * t1, 0, z1)
                out = V3(0, 0, -1)
            elif side == 2:
                a, b = V3(x0, 0, z0 + (z1 - z0) * t0), V3(x0, 0, z0 + (z1 - z0) * t1)
                out = V3(1, 0, 0)
            else:
                a, b = V3(x1, 0, z0 + (z1 - z0) * t0), V3(x1, 0, z0 + (z1 - z0) * t1)
                out = V3(-1, 0, 0)
            k += 1
            dl = 0.25 + 0.35 * abs(math.sin(k * 2.3))
            drop = 0.15 + 0.4 * abs(math.sin(k * 1.7))
            tip = (a + b) * 0.5 + out * dl - V3(0, drop, 0)
            mb.poly([a - V3(0, 0.005, 0), b - V3(0, 0.005, 0), tip], [(0, 0), (1, 0), (0.5, 1)], "kskin", V3(0, 1, 0) + out * 0.3)
            mb.poly([a - V3(0, 0.012, 0), b - V3(0, 0.012, 0), tip - V3(0, 0.007, 0)], [(0, 0), (1, 0), (0.5, 1)], "kframe", V3(0, -1, 0))


def porthole(fr, skin, c, inward):
    """A round porthole ring at the skin (the skin has a square hole behind it) with its glass."""
    inward = Vector(inward).normalized()
    up = V3(0, 1, 0)
    side = inward.cross(up).normalized()
    segs = 12
    ro, ri = 0.38, 0.2
    for i in range(segs):
        t0 = 2 * math.pi * i / segs
        t1 = 2 * math.pi * (i + 1) / segs
        o0 = c + (side * math.cos(t0) + up * math.sin(t0)) * ro + inward * 0.02
        o1 = c + (side * math.cos(t1) + up * math.sin(t1)) * ro + inward * 0.02
        i0 = c + (side * math.cos(t0) + up * math.sin(t0)) * ri + inward * 0.05
        i1 = c + (side * math.cos(t1) + up * math.sin(t1)) * ri + inward * 0.05
        fr.poly([o0, o1, i1, i0], [(0, 0), (1, 0), (1, 1), (0, 1)], "kframe", inward)
        g0 = c + (side * math.cos(t0) + up * math.sin(t0)) * ri
        g1 = c + (side * math.cos(t1) + up * math.sin(t1)) * ri
        fr.poly([i0, i1, g1, g0], [(0, 0), (1, 0), (1, 1), (0, 1)], "kframe", -(side * math.cos((t0 + t1) / 2) + up * math.sin((t0 + t1) / 2)))
        skin.poly([c, g0, g1], [(0.5, 0.5), (0, 0), (1, 0)], "kglass", inward)


def room_body():
    skin, fr, fl = MB("Skin"), MB("Frames"), MB("Floor")
    rng = [(28.0, 46.0, "flat")]
    op = [(47.2, 48.8, 0.9, 2.2, "window"), (25.25, 25.75, 1.3, 1.8, "port"), (52.25, 52.75, 1.3, 1.8, "port")]
    sides = {-1: {"face": -8.85, "ranges": rng, "openings": op + [(35.0, 37.0, 0.0, 2.4, "door")]},
             1: {"face": 8.85, "ranges": rng, "openings": op + [(35.0, 37.0, 0.0, 2.4, "door")]}}
    sec = Section("body", "z", 24.0 + T * 0.5, 54.0 - T * 0.5, 0.0, 2.6, 4.05, 1.5, sides)
    sec.build(skin, fr)
    for s in (-1, 1):
        for (lo, hi, y0, y1, k) in sides[s]["openings"]:
            wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
            if k == "port":
                porthole(fr, skin, V3(s * (8.85 + DEEP), (y0 + y1) * 0.5, (lo + hi) * 0.5), V3(-s, 0, 0))
            if k == "door":
                door_frame(fr, "x", s * 8.85, -s, (lo + hi) * 0.5)
    # the wing roots: the spar carry-through as a heavy frame over each door range
    for s in (-1, 1):
        for z in (28.0, 46.0):
            fr.box(_mn(V3(s * 8.85, 0, z - 0.12), V3(s * 8.62, 2.6, z + 0.12)), _mx(V3(s * 8.85, 0, z - 0.12), V3(s * 8.62, 2.6, z + 0.12)), "kframe")
    end_wall(skin, "z", 24.0 + T * 0.5, 1, section_outline(sec, sec.a0), [(0.0, 2.4, rect_hole(-1.0, 1.0))], sec.crown, ylevels=[2.4])
    door_frame(fr, "z", 24.0 + T * 0.5, 1, 0.0)
    end_wall(skin, "z", 54.0 - T * 0.5, -1, section_outline(sec, sec.a1), [], sec.crown)
    # the floor: riveted plates with a diamond-plate runner down the middle
    floor_rect(fl, -8.85, 8.85, 24.15, 53.85, "kskin", 0.0, holes=[(-1.2, 1.2, 24.15, 53.85)])
    floor_rect(fl, -1.2, 1.2, 24.15, 53.85, "lib_deck_plate", 0.004)
    floor_beams(fl, "z", sec.stations, -8.85, 8.85)
    return [("kranich_body", "Der Kranich: centre body shell", "frames, riveted skin, the wing-root carry-through, portholes, bulkheads, floor plates", [skin, fr, fl])]


def room_wing(sign):
    tag = "l" if sign < 0 else "r"
    skin, fr, fl = MB("Skin"), MB("Frames"), MB("Floor")
    x_in = sign * (9.0 + T * 0.5)
    x_out = sign * (52.0 - T * 0.5)
    a0, a1 = min(x_in, x_out), max(x_in, x_out)
    # every third rib stands on a collider stub (gen_map04b: stubs at 9 + 4k)
    stations = []
    k = 1
    while True:
        x = 9.0 + k * 4.0 / 3.0
        if x >= 51.9:
            break
        stations.append(sign * x)
        k += 1
    stations.sort()
    rear = [(sign * 30.0 - 0.8, sign * 30.0 + 0.8, 0.9, 2.2, "window")]
    rear = [(min(a, b), max(a, b), y0, y1, kk) for (a, b, y0, y1, kk) in rear]
    front = []
    for bx in (20.0, 40.0):
        front.append((sign * bx - 1.0, sign * bx + 1.0, 0.2, 1.9, "breach"))
    front = [(min(a, b), max(a, b), y0, y1, kk) for (a, b, y0, y1, kk) in front]
    sides = {-1: {"face": 28.0 + T * 0.5, "ranges": [], "openings": rear}, 1: {"face": 46.0 - T * 0.5, "ranges": [], "openings": front}}
    sec = Section("wing_" + tag, "x", a0, a1, 37.0, 2.1, 2.85, 4.0 / 3.0, sides, stations=stations)
    sec.build(skin, fr)
    for s in (-1, 1):
        for (lo, hi, y0, y1, kk) in sides[s]["openings"]:
            wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
    # the bulkheads at both ends (the body's side, the engine room's / the blisters' side), each with its hatch
    for (xa, fs) in ((x_in, sign), (x_out, -sign)):
        end_wall(skin, "x", xa, fs, section_outline(sec, xa), [(0.0, 2.4, rect_hole(35.0, 37.0))], sec.crown, ylevels=[2.4])
        door_frame(fr, "x", xa, fs, 36.0)
    # the collider stubs (gen_map04b Rib*_a/_b: 0.4 thick, z 28.3..31 and 43..45.7) as box-section rib roots
    x = 9.0 + 4.0
    while x < 50.0:
        rx = sign * x
        for (z0, z1) in ((28.3, 31.0), (43.0, 45.7)):
            fr.box(V3(rx - 0.2, 0.0, z0), V3(rx + 0.2, 2.1, z1), "kframe")
            # lightening-hole rosettes painted dark on the stub's faces (the stub is a solid collider)
            for zz in ((z0 + z1) * 0.5,):
                for fx in (-1, 1):
                    c = V3(rx + fx * 0.205, 1.25, zz)
                    for i in range(8):
                        t0 = 2 * math.pi * i / 8
                        t1 = 2 * math.pi * (i + 1) / 8
                        p0 = c + V3(0, math.sin(t0) * 0.42, math.cos(t0) * 0.42)
                        p1 = c + V3(0, math.sin(t1) * 0.42, math.cos(t1) * 0.42)
                        fr.poly([c, p0, p1], [(0, 0), (1, 0), (0, 1)], "kdark", V3(fx, 0, 0))
        x += 4.0
    # the spars overhead: the main spar's I-beam at z 37 and two lighter ones over the stub ends
    for (zc, depth, wd) in ((37.0, 0.42, 0.22), (31.2, 0.25, 0.14), (42.8, 0.25, 0.14)):
        ytop = 2.85 if zc == 37.0 else 2.6
        fr.box(V3(a0, ytop - depth, zc - 0.012), V3(a1, ytop, zc + 0.012), "kframe")
        fr.box(V3(a0, ytop - depth - 0.02, zc - wd * 0.5), V3(a1, ytop - depth, zc + wd * 0.5), "kframe")
    # the floor: the lower skin (riveted) with a plank walkway on the spar line
    floor_rect(fl, a0, a1, 28.15, 45.85, "kskin", 0.0, holes=[(a0, a1, 35.6, 38.4)])
    floor_rect(fl, a0, a1, 35.6, 38.4, "lib_deck_plate", 0.006)
    floor_beams(fl, "x", stations, 28.15, 45.85)
    return [("kranich_wing_" + tag, "Der Kranich: %s wing crawlway shell" % ("port" if sign < 0 else "starboard"),
             "chordwise ribs every 4/3 m with lightening holes, the spars overhead, the spar webs with the hatch and the breach openings, the lower skin floor", [skin, fr, fl])]


def room_engine(sign):
    """D Triebwerk (port, sign -1) or E Kanzel (starboard, +1): a 26 m room and its walkway to the flight deck."""
    tag = "nacelle" if sign < 0 else "kanzel"
    skin, fr, fl = MB("Skin"), MB("Frames"), MB("Floor")
    xo = sign * 78.0          # outboard wall
    xi = sign * 52.0          # inboard wall (the wing on the other side)
    face_o = xo - sign * T * 0.5
    face_i = xi + sign * T * 0.5
    # the outboard side: deep; openings: the core window and the hatch (port only)
    s_out = sign
    s_in = -sign
    out_ops = []
    if sign < 0:
        out_ops = [(29.2, 30.8, 0.9, 2.2, "window"), (34.0, 42.0, 0.8, 3.2, "core"), (26.5, 27.0, 1.4, 1.9, "port"), (49.0, 49.5, 1.4, 1.9, "port")]
    else:
        out_ops = [(29.5, 30.0, 1.4, 1.9, "port"), (41.5, 42.0, 1.4, 1.9, "port"), (49.0, 49.5, 1.4, 1.9, "port")]
    sides = {
        s_out: {"face": face_o, "ranges": [], "openings": out_ops},
        s_in: {"face": face_i, "ranges": [(28.0, 46.0, "flat"), (50.0, 58.0, "open")], "open_top": 2.95,
               "openings": [(35.0, 37.0, 0.0, 2.4, "door")]},
    }
    sec = Section(tag, "z", 24.0 + T * 0.5, 58.0 - T * 0.5, sign * 65.0, 3.0, 5.4, 1.5, sides)
    sec.build(skin, fr)
    for s in (-1, 1):
        for (lo, hi, y0, y1, k) in sides[s]["openings"]:
            if k == "core":
                wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
                continue
            wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
            if k == "port":
                porthole(fr, skin, V3(face_o + s * DEEP, (y0 + y1) * 0.5, (lo + hi) * 0.5), V3(-s, 0, 0))
            if k == "door":
                door_frame(fr, "x", face_i, -s_in, (lo + hi) * 0.5)
    # the south bulkhead (z 24.15): plain on the port side; on the starboard side the four blisters
    holes = []
    if sign > 0:
        for bx in (56.0, 62.0, 68.0, 74.0):
            holes.append((1.5 - 1.25, 1.5 + 1.25, circle_hole(bx, 1.5, 1.25)))
    end_wall(skin, "z", 24.0 + T * 0.5, 1, section_outline(sec, sec.a0), holes, sec.crown)
    if sign > 0:
        for bx in (56.0, 62.0, 68.0, 74.0):
            blister(fr, skin, V3(bx, 1.5, 24.15))
    # the north bulkhead (z 57.85) over the room part only (the walkway's own side covers the rest)
    def north_outline(y):
        lo, hi = section_outline(sec, sec.a1)(y)
        if y < 2.95:
            # the walkway opening's edge: the room's inboard face
            if sign < 0:
                hi = min(hi, face_i)
            else:
                lo = max(lo, face_i)
        return (lo, hi)
    end_wall(skin, "z", 58.0 - T * 0.5, -1, north_outline, [], sec.crown, ylevels=[2.95])
    # the walkway (x from the room to the flight deck's wall, z 50..58), its arch, the bulkhead with the hatch
    wa = sign * (52.0)
    wb = sign * (22.0 + T * 0.5)
    w0, w1 = min(wa, wb), max(wa, wb)
    wsides = {-1: {"face": 50.0 + T * 0.5, "ranges": [], "openings": []}, 1: {"face": 58.0 - T * 0.5, "ranges": [], "openings": []}}
    # walkway frames on the room's rivet pitch (x = 0.5 mod 1.5, like the room's z stations), see kranich_shell.gd
    wst = []
    xs = -50.5 if sign < 0 else 23.0
    while (xs < -22.3) if sign < 0 else (xs < 51.9):
        wst.append(xs)
        xs += 1.5
    wsec = Section(tag + "_walk", "x", w0, w1, 54.0, 2.0, 2.75, 1.5, wsides, stations=wst)
    wsec.build(skin, fr)
    end_wall(skin, "x", wb, sign, section_outline(wsec, wb), [(0.0, 2.4, rect_hole(55.0, 57.0))], wsec.crown, ylevels=[2.4])
    door_frame(fr, "x", wb, sign, 56.0)
    # the walkway's mouth seen from the room: a plate round its arch up to the room's arch
    def mouth_outline(y):
        return (49.4, 58.6)
    end_wall(skin, "x", wa, sign, mouth_outline, [(0.0, wsec.crown, arch_hole(wsec))], 4.6)
    # floors: the engine room on bolted diamond plates (the boss arena), the blister gallery on grating
    if sign < 0:
        floor_rect(fl, -77.85, -52.15, 24.15, 57.85, "lib_deck_plate", 0.0)
        for zz in range(26, 58, 3):
            fl.box(V3(-77.85, -0.01, zz - 0.03), V3(-52.15, 0.008, zz + 0.03), "kframe", skip=("-y",))
        for xx in range(-76, -52, 3):
            fl.box(V3(xx - 0.03, -0.01, 24.15), V3(xx + 0.03, 0.008, 57.85), "kframe", skip=("-y",))
        floor_rect(fl, w0, w1, 50.15, 57.85, "lib_deck_plate", 0.0)
    else:
        grating_floor(fl, 52.15, 77.85, 24.15, 57.85, beam_axis="x", beam_pitch=1.5)
        grating_floor(fl, w0, w1, 50.15, 57.85, beam_axis="x", beam_pitch=1.5)
    name = "Der Kranich: port engine room shell" if sign < 0 else "Der Kranich: gun blister gallery shell"
    desc = "frames, riveted skin, the core window's lining, the walkway's arch and hatch" if sign < 0 else "frames, riveted skin, four perspex blisters with their rings and frames, the walkway's arch and hatch, grating"
    return [("kranich_" + tag, name, desc, [skin, fr, fl])]


def blister(fr, skin, c):
    """A perspex dome bulging aft (-Z) from the bulkhead at c (centre of the 1.25 m ring), framed with a ring and four
    meridian bars."""
    r = 1.25
    rings = 6
    segs = 16
    pts = {}
    for i in range(rings + 1):
        ph = (math.pi * 0.5) * i / rings      # 0 at the ring, pi/2 at the apex
        for j in range(segs):
            th = 2 * math.pi * j / segs
            rr = r * math.cos(ph)
            pts[(i, j)] = c + V3(math.cos(th) * rr, math.sin(th) * rr, -math.sin(ph) * r * 0.9)
    for i in range(rings):
        for j in range(segs):
            j2 = (j + 1) % segs
            q = [pts[(i, j)], pts[(i, j2)], pts[(i + 1, j2)], pts[(i + 1, j)]]
            ctr = (q[0] + q[2]) * 0.5
            skin.poly(q, [(j / segs, i / rings), ((j + 1) / segs, i / rings), ((j + 1) / segs, (i + 1) / rings), (j / segs, (i + 1) / rings)], "kglass", c + V3(0, 0, 0.5) - ctr)
    # the ring (a flat collar on the bulkhead) and the bars
    for j in range(segs):
        th0 = 2 * math.pi * j / segs
        th1 = 2 * math.pi * (j + 1) / segs
        o0 = c + V3(math.cos(th0) * (r + 0.16), math.sin(th0) * (r + 0.16), 0.03)
        o1 = c + V3(math.cos(th1) * (r + 0.16), math.sin(th1) * (r + 0.16), 0.03)
        i0 = c + V3(math.cos(th0) * r, math.sin(th0) * r, 0.03)
        i1 = c + V3(math.cos(th1) * r, math.sin(th1) * r, 0.03)
        fr.poly([o0, o1, i1, i0], [(0, 0), (1, 0), (1, 1), (0, 1)], "kframe", V3(0, 0, 1))
    for j in range(0, segs, 4):
        for i in range(rings):
            a = pts[(i, j)]
            b = pts[(i + 1, j)]
            fr.tube(a + V3(0, 0, 0.0), b, 0.03, "kframe", 5)
    for i in (2, 4):
        for j in range(segs):
            fr.tube(pts[(i, j)], pts[(i, (j + 1) % segs)], 0.025, "kframe", 5)


def room_cockpit():
    skin, fr, fl = MB("Skin"), MB("Frames"), MB("Floor")
    rng = [(54.0, 58.0, "flat")]
    sides = {-1: {"face": -22.0 + T * 0.5, "ranges": rng, "openings": [(55.0, 57.0, 0.0, 2.4, "door"), (63.75, 64.25, 1.4, 1.9, "port")]},
             1: {"face": 22.0 - T * 0.5, "ranges": rng, "openings": [(55.0, 57.0, 0.0, 2.4, "door"), (63.75, 64.25, 1.4, 1.9, "port")]}}
    sec = Section("cockpit", "z", 54.0 + T * 0.5, 74.0 - T * 0.5, 0.0, 3.0, 5.7, 1.5, sides)
    # the brow: the last bays of the arch are glazed (the stars over the flight deck)
    sec.glass_arc = [(70.0, 74.0 - T * 0.5, 0.6)]
    sec.build(skin, fr)
    for s in (-1, 1):
        for (lo, hi, y0, y1, k) in sides[s]["openings"]:
            wall_coaming_side(fr, sec, s, lo, hi, y0, y1)
            if k == "door":
                door_frame(fr, "x", s * (22.0 - T * 0.5), -s, 56.0)
            if k == "port":
                porthole(fr, skin, V3(s * (21.85 + DEEP), (y0 + y1) * 0.5, (lo + hi) * 0.5), V3(-s, 0, 0))
    end_wall(skin, "z", 54.0 + T * 0.5, 1, section_outline(sec, sec.a0), [], sec.crown)
    # the front: the whole width glazed between a sill and the brow (mullions every ~2.6 m, two transoms)
    zf = 74.0 - T * 0.5 + 0.02
    gl0, gl1, gy0, gy1 = -20.5, 20.5, 0.55, 3.9
    end_wall(skin, "z", zf, -1, section_outline(sec, sec.a1), [(gy0, gy1, rect_hole(gl0, gl1))], sec.crown, ylevels=[gy0, gy1])
    zg = zf + 0.08
    skin.poly([V3(gl0, gy0, zg), V3(gl1, gy0, zg), V3(gl1, gy1, zg), V3(gl0, gy1, zg)], [(gl0, gy0), (gl1, gy0), (gl1, gy1), (gl0, gy1)], "kglass", V3(0, 0, -1))
    n = 16
    for i in range(n + 1):
        x = gl0 + (gl1 - gl0) * i / n
        fr.box(V3(x - 0.06, gy0, zf - 0.02), V3(x + 0.06, gy1, zg + 0.04), "kframe")
    for y in (gy0, 2.0, 3.1, gy1):
        fr.box(V3(gl0, y - 0.05, zf - 0.02), V3(gl1, y + 0.05, zg + 0.04), "kframe")
    # the glazed brow's bars
    for z in (70.75, 71.5, 72.25, 73.0):
        for s in (-1, 1):
            for k in range(12):
                ph0 = math.pi * 0.5 * k / 12
                ph1 = math.pi * 0.5 * (k + 1) / 12
                if ph0 < 0.6:
                    continue
                p0 = sec.arc_pt(s, ph0)
                p1 = sec.arc_pt(s, ph1)
                fr.tube(V3(p0[0], p0[1] - 0.03, z), V3(p1[0], p1[1] - 0.03, z), 0.03, "kframe", 4)
    # floor: plates with rubber mats at the seats
    floor_rect(fl, -21.85, 21.85, 54.15, 73.85, "lib_deck_plate", 0.0)
    floor_beams(fl, "z", sec.stations, -21.85, 21.85)
    fl.box(V3(-3.4, 0.0, 68.6), V3(3.4, 0.015, 71.6), "mats_rubber", skip=("-y",))
    return [("kranich_cockpit", "Der Kranich: flight deck shell", "frames, riveted skin, the glazed front and brow with mullions, portholes, floor plates", [skin, fr, fl])]


# ================================================================== export

def export_room(folder, title, desc, mbs):
    W.reset()
    tris = 0
    for mb in mbs:
        tris += mb.tris()
        mb.to_object()
    out_dir = os.path.join(W.OUT_ROOT, folder)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "model.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_texcoords=True, export_normals=True, export_materials="EXPORT", export_cameras=False,
                              export_lights=False, export_animations=False, export_extras=False, export_skins=False,
                              export_morph=False, use_selection=False)
    lic = ("Ours (original work)\n\nThis model was made for GRAVELIGHT by the project itself: it is generated by a Blender script in this\n"
           "repository (tools_src/blender/world/kranich_shell.py), from primitives only, with no third-party mesh, texture or\n"
           "reference scan. It may be used, changed and shipped with the game like the rest of the project's own code.\n")
    src = ("Title: %s\nAuthor: GRAVELIGHT (generated by tools_src/blender/world/kranich_shell.py)\n"
           "Source: tools_src/blender/world/kranich_shell.py (headless Blender 5.1: blender -b -P <script>; tools/build_kranich_shell.sh)\n"
           "License: Ours (original work)\nCredit line: none required (original work)\n"
           "Format: GLB, metres, +Y up, in Map 4 Act II's frame (placed at the origin); material slots kskin / kframe / kgrate / kglass / kdark mapped by gravelight/world/map04/kranich_shell.gd\n"
           "Downloaded: generated %s by Claude (T-147, UPDATE 09 section 5.3)\nFiles used: model.glb\nNotes: %s (%d triangles)\n") % (
        title, datetime.date.today().isoformat(), desc, tris)
    with open(os.path.join(out_dir, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lic)
    with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print("[kranich] %s: %d tris -> %s" % (folder, tris, os.path.relpath(path, W.ROOT)))
    return tris


if __name__ == "__main__":
    total = 0
    rooms = []
    rooms += room_bay()
    rooms += room_body()
    rooms += room_wing(-1.0)
    rooms += room_wing(1.0)
    rooms += room_engine(-1.0)
    rooms += room_engine(1.0)
    rooms += room_cockpit()
    for (folder, title, desc, mbs) in rooms:
        total += export_room(folder, title, desc, mbs)
    print("[kranich] total %d tris" % total)
