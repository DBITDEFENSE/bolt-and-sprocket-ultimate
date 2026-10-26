"""Builds Map 0's nature models in headless Blender (UPDATE_05 section 5, DECISIONS T-093). Ours, all from code.

    "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup -P tools_src/blender/nature/make_trees.py -- [out.glb]

Writes assets/ours/env/nature/nature.glb (default) with these nodes, all unit-sized (a tree is 1.0 tall: the map
scales each instance to its height; a bush and a rock are about 1 m across), +Y up, pivot on the ground at the
trunk / centre:

  Spruce_LOD0   ~1950 tris  tapered trunk + 24 whorls of drooping two-plane frond cards (tex_spruce_frond)
  Spruce_LOD1    ~150 tris  10 whorls of single cards, a 6-sided trunk (past ~40 m; the impostor cards take over far out)
  Birch_LOD0     ~650 tris  a leaning white trunk, 9 tube branches, crossed bare-twig cards (tex_birch_twigs)
  Birch_LOD1     ~170 tris
  Bush_A, Bush_B ~40 tris   bare winter bushes: crossed twig cards fanning up from the root
  Rock_A..Rock_C ~320 tris  noise-displaced boulders (the map draws them with the library's "rock" material)

Materials are named, not textured (the game sets its own shader by name): "bark", "needles", "birch_bark", "twigs",
"rock". Foliage normals point up and out of the crown (soft, card-free lighting); UVs: cards 0..1 with v = 1 on the
upper edge (the snow painted at the texture's top lies on top), trunks wrap u twice and run v up the trunk.
Deterministic (seeded); ART_BIBLE section 5 budget: LOD0 <= 4000, LOD1 <= 1200 tris.
"""
import math
import os
import random
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(ROOT, "assets", "ours", "env", "nature", "nature.glb")


def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_norm(a):
    ln = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]) or 1.0
    return (a[0] / ln, a[1] / ln, a[2] / ln)


def rotate_about(v, axis, ang):
    """Rodrigues: v rotated about the unit axis by ang radians."""
    c, s = math.cos(ang), math.sin(ang)
    d = v[0] * axis[0] + v[1] * axis[1] + v[2] * axis[2]
    cr = v_cross(axis, v)
    return (v[0] * c + cr[0] * s + axis[0] * d * (1 - c), v[1] * c + cr[1] * s + axis[1] * d * (1 - c), v[2] * c + cr[2] * s + axis[2] * d * (1 - c))


class Builder:
    """Collects a mesh in Godot's frame (+Y up) as faces with per-corner UVs and normals and a material slot."""

    def __init__(self, mats):
        self.mats = mats
        self.verts = []
        self.faces = []   # (indices, uvs, normals, mat)

    def face(self, pts, uvs, nrms, mat):
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append((list(range(base, base + len(pts))), uvs, nrms, self.mats.index(mat)))

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.faces)

    def tube(self, path, radii, sides, mat, v_scale=10.0, u_rep=2.0):
        """A tapered tube along `path` (list of points) with `radii`; ring frames from the path's tangent."""
        rings = []
        up_hint = (1.0, 0.0, 0.0)
        for i, p in enumerate(path):
            t = v_norm(v_sub(path[min(i + 1, len(path) - 1)], path[max(i - 1, 0)]))
            a = v_norm(v_cross(t, up_hint if abs(t[0]) < 0.9 else (0.0, 0.0, 1.0)))
            b = v_cross(t, a)
            ring = []
            for k in range(sides + 1):
                ang = 2 * math.pi * k / sides
                n = v_add(v_mul(a, math.cos(ang)), v_mul(b, math.sin(ang)))
                ring.append((v_add(p, v_mul(n, radii[i])), n))
            rings.append(ring)
        vlen = 0.0
        vs = [0.0]
        for i in range(1, len(path)):
            vlen += math.dist(path[i], path[i - 1])
            vs.append(vlen)
        for i in range(len(rings) - 1):
            for k in range(sides):
                p00, n00 = rings[i][k]
                p01, n01 = rings[i][k + 1]
                p10, n10 = rings[i + 1][k]
                p11, n11 = rings[i + 1][k + 1]
                u0, u1 = u_rep * k / sides, u_rep * (k + 1) / sides
                v0, v1 = vs[i] * v_scale, vs[i + 1] * v_scale
                # counter-clockwise seen from outside (Blender's front faces)
                self.face([p00, p01, p11, p10], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], [n00, n01, n11, n10], mat)

    def card(self, root, axis, side, length, width, droop, mat, segs=2, nrm=None):
        """A strip from `root` along `axis` (unit) `length` long and `width` across `side` (unit), bending down by
        `droop` (fraction of its length at the tip). u runs along it, v = 1 on the +side edge."""
        pts = []
        for s in range(segs + 1):
            t = s / segs
            c = v_add(root, v_mul(axis, length * t))
            c = v_add(c, (0.0, -droop * length * t * t, 0.0))
            pts.append((v_add(c, v_mul(side, -width * 0.5)), v_add(c, v_mul(side, width * 0.5)), t))
        for s in range(segs):
            a0, a1, t0 = pts[s]
            b0, b1, t1 = pts[s + 1]
            n = nrm or (0.0, 1.0, 0.0)
            # two-sided card: the material is drawn without culling, one face is enough
            self.face([a0, b0, b1, a1], [(t0, 0.0), (t1, 0.0), (t1, 1.0), (t0, 1.0)], [n, n, n, n], mat)


def spruce(lod, seed):
    rng = random.Random(seed)
    b = Builder(["bark", "needles"])
    sides = 8 if lod == 0 else 6
    ys = [-0.02, 0.12, 0.35, 0.6, 0.85, 1.0] if lod == 0 else [-0.02, 0.5, 1.0]
    b.tube([(0.0, y, 0.0) for y in ys], [0.024 * (1.0 - y) + 0.003 for y in ys], sides, "bark", 10.0, 2.0)
    whorls = 24 if lod == 0 else 10
    per = 9 if lod == 0 else 6
    for w in range(whorls):
        t = w / (whorls - 1)
        y = 0.1 + 0.84 * t + rng.uniform(-0.01, 0.01)
        length = (0.25 * (1.0 - t) ** 0.85 + 0.035) * rng.uniform(0.85, 1.1)
        if lod == 1:
            length *= 1.12
        off = rng.uniform(0, 2 * math.pi)
        for k in range(per):
            a = off + 2 * math.pi * k / per + rng.uniform(-0.2, 0.2)
            radial = (math.cos(a), 0.0, math.sin(a))
            pitch = math.radians(10.0 + 20.0 * (1.0 - t) + rng.uniform(-4, 4))
            axis = v_norm((radial[0] * math.cos(pitch), -math.sin(pitch), radial[2] * math.cos(pitch)))
            flat_side = v_norm(v_cross((0.0, 1.0, 0.0), radial))
            nrm = v_norm(v_add((0.0, 0.75, 0.0), v_mul(radial, 0.55)))
            root = (radial[0] * 0.01, y, radial[2] * 0.01)
            width = length * (0.78 if lod == 0 else 0.85)
            droop = 0.18 + 0.12 * (1.0 - t)
            if lod == 0:
                for roll in (0.55, -0.55):
                    side = rotate_about(flat_side, axis, roll)
                    if side[1] < 0:   # keep v = 1 on the upper edge
                        side = v_mul(side, -1.0)
                    b.card(root, axis, side, length, width, droop, "needles", 2, nrm)
            else:
                b.card(root, axis, flat_side if flat_side[1] >= 0 else v_mul(flat_side, -1.0), length, width, droop, "needles", 1, nrm)
    # the leader: two crossed upright cards at the tip
    for a in (0.0, math.pi * 0.5):
        side = (math.cos(a), 0.0, math.sin(a))
        b.card((0.0, 0.9, 0.0), (0.0, 1.0, 0.0), side, 0.12, 0.07, 0.0, "needles", 1, (0.0, 1.0, 0.0))
    return b


def birch(lod, seed):
    rng = random.Random(seed)
    b = Builder(["birch_bark", "twigs"])
    n = 10 if lod == 0 else 4
    lean = (rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04))
    path = []
    for i in range(n + 1):
        y = -0.02 + 1.02 * i / n
        wob = 0.012 * math.sin(y * 9.0 + seed)
        path.append((lean[0] * y * y + wob, y, lean[1] * y * y + wob * 0.5))
    b.tube(path, [0.019 * (1.0 - 0.75 * p[1]) + 0.002 for p in path], 8 if lod == 0 else 5, "birch_bark", 2.5, 1.0)
    prim = 9 if lod == 0 else 6
    for k in range(prim):
        t = k / (prim - 1)
        y = 0.38 + 0.5 * t
        az = k * 2.39996 + rng.uniform(-0.3, 0.3)
        elev = math.radians(rng.uniform(42, 62))
        length = (0.28 - 0.12 * t) * rng.uniform(0.85, 1.1)
        d = (math.cos(az) * math.cos(elev), math.sin(elev), math.sin(az) * math.cos(elev))
        base = path[min(n, int(y * n))]
        base = (base[0], y, base[2])
        segs = 3 if lod == 0 else 1
        bp = [v_add(base, v_add(v_mul(d, length * s / segs), (0.0, 0.03 * (s / segs) ** 2, 0.0))) for s in range(segs + 1)]
        b.tube(bp, [0.006 * (1.0 - 0.7 * s / segs) + 0.0012 for s in range(segs + 1)], 5 if lod == 0 else 3, "birch_bark", 2.5, 1.0)
        # twig sprays along the outer half, crossed
        sprays = 3 if lod == 0 else 1
        for s in range(sprays):
            f = 0.45 + 0.55 * s / max(1, sprays - 1) if sprays > 1 else 0.7
            root = v_add(base, v_mul(d, length * f))
            ax = v_norm(v_add(d, (rng.uniform(-0.3, 0.3), 0.15, rng.uniform(-0.3, 0.3))))
            side0 = v_norm(v_cross((0.0, 1.0, 0.0), ax))
            size = rng.uniform(0.14, 0.2) * (1.0 - 0.3 * t)
            nrm = v_norm(v_add((0.0, 0.6, 0.0), v_mul(d, 0.6)))
            for roll in ((0.0, math.pi * 0.5) if lod == 0 else (0.0,)):
                side = rotate_about(side0, ax, roll)
                b.card(root, ax, side, size, size * 0.85, 0.05, "twigs", 1, nrm)
    # the crown: sprays round the top of the trunk, reaching up and out
    crown = 6 if lod == 0 else 3
    for k in range(crown):
        az = 2 * math.pi * k / crown + rng.uniform(-0.3, 0.3)
        ax = v_norm((math.cos(az) * 0.5, 1.0, math.sin(az) * 0.5))
        side = v_norm(v_cross((0.0, 1.0, 0.0), (math.cos(az), 0.0, math.sin(az))))
        b.card(path[-2], ax, side, 0.2, 0.17, 0.0, "twigs", 1, (0.0, 1.0, 0.0))
    return b


def bush(seed):
    rng = random.Random(seed)
    b = Builder(["twigs"])
    for k in range(9):
        az = 2 * math.pi * k / 9 + rng.uniform(-0.3, 0.3)
        tilt = math.radians(rng.uniform(18, 55))
        ax = v_norm((math.cos(az) * math.sin(tilt), math.cos(tilt), math.sin(az) * math.sin(tilt)))
        side0 = v_norm(v_cross((0.0, 1.0, 0.0), (math.cos(az), 0.0, math.sin(az))))
        size = rng.uniform(0.55, 0.85)
        for roll in (0.0, math.pi * 0.5):
            b.card((0.0, 0.0, 0.0), ax, rotate_about(side0, ax, roll), size, size * 0.8, 0.0, "twigs", 1, v_norm(v_add(ax, (0.0, 0.5, 0.0))))
    return b


def rock(seed):
    """A boulder: an icosphere's vertices pushed out by low-frequency noise, flattened, sunk a little."""
    rng = random.Random(seed)
    b = Builder(["rock"])
    t = (1.0 + math.sqrt(5.0)) / 2.0
    vs = [v_norm(p) for p in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    fs = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
          (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(2):
        cache = {}
        nf = []

        def mid(i, j):
            key = (min(i, j), max(i, j))
            if key not in cache:
                vs.append(v_norm(v_mul(v_add(vs[i], vs[j]), 0.5)))
                cache[key] = len(vs) - 1
            return cache[key]
        for (a, c, d) in fs:
            ab, cd, da = mid(a, c), mid(c, d), mid(d, a)
            nf += [(a, ab, da), (c, cd, ab), (d, da, cd), (ab, cd, da)]
        fs = nf
    lobes = [(v_norm((rng.uniform(-1, 1), rng.uniform(-0.3, 1), rng.uniform(-1, 1))), rng.uniform(0.12, 0.3)) for _ in range(6)]
    pos = []
    for p in vs:
        r = 0.5
        for (dirv, amp) in lobes:
            r += amp * max(0.0, p[0] * dirv[0] + p[1] * dirv[1] + p[2] * dirv[2]) ** 3
        r += rng.uniform(-0.02, 0.02)
        pos.append((p[0] * r, p[1] * r * 0.62 + 0.12, p[2] * r * 0.85))
    for (a, c, d) in fs:
        # Godot-frame winding as the icosphere lists it is outward-facing CCW; normals from the sphere direction
        b.face([pos[a], pos[d], pos[c]], [(0, 0), (0, 1), (1, 1)], [vs[a], vs[d], vs[c]], "rock")
    return b


def to_blender(p):
    """Godot frame (+Y up, -Z forward) -> Blender (+Z up); the glTF exporter turns it back."""
    return (p[0], -p[2], p[1])


def make_object(name, builder):
    mesh = bpy.data.meshes.new(name)
    verts = [to_blender(p) for p in builder.verts]
    faces = [f[0] for f in builder.faces]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for m in builder.mats:
        mat = bpy.data.materials.get(m) or bpy.data.materials.new(m)
        mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name="UVMap")
    loop_normals = []
    for poly, f in zip(mesh.polygons, builder.faces):
        poly.material_index = f[3]
        for k, li in enumerate(poly.loop_indices):
            uv.data[li].uv = f[1][k]
        # (loops are in face order)
    for f in builder.faces:
        for n in f[2]:
            loop_normals.append(to_blender(v_norm(n)))
    mesh.normals_split_custom_set(loop_normals)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    print("[make_trees] %-12s %5d tris" % (name, builder.tris()))
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_object("Spruce_LOD0", spruce(0, 11))
    make_object("Spruce_LOD1", spruce(1, 11))
    make_object("Birch_LOD0", birch(0, 23))
    make_object("Birch_LOD1", birch(1, 23))
    make_object("Bush_A", bush(31))
    make_object("Bush_B", bush(37))
    for i, s in enumerate((41, 43, 47)):
        make_object("Rock_" + "ABC"[i], rock(s))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True, export_normals=True,
                              export_materials="EXPORT", use_selection=False)
    print("[make_trees] wrote", OUT)


main()
