"""Parametric skinned humanoid base body for GRAVELIGHT (T-091, docs/CHARACTER_PIPELINE.md).

    blender -b --factory-startup -P tools_src/blender/characters/make_body.py -- [--sex=m|f] [--build=thin|medium|heavy]
            [--living] [--out=<file.glb>] [--preview=<dir>]

One script, three builds x two sexes, zombie or living (``--living``: no frostbite, no sunken sockets, plain eyes
without the Nachtglas glow, warmer skin texture set). The body is modelled the way a box-modeller would block it:
a skin-modifier skeleton (torso, arms in an A-pose, legs, feet) with per-node elliptical radii, Catmull-Clark
subdivided, then sculpted by smooth displacement fields (pecs / breasts, belly, buttocks, collarbones, knees); the
head is its own quad-sphere sculpted the same way (skull, brow, eye sockets, nose, cheekbones, sunken cheeks, lips,
chin, ears) with a jaw region on the Jaw bone; hands are a palm with four curled fingers and a thumb.

Weights are computed, not painted: every rig bone is a segment with a radius (rig.json, tools/export_rig.gd), a
vertex's raw weight for a bone is (radius / distance)^p with left / right side masks, the top four are kept and
pruned. They are computed in the A-pose (arms clear of the torso) and the mesh is then taken back to the rig's rest
pose (arms hanging straight down, identity rest rotations) by inverting the same linear-blend skinning Godot does,
so the shoulders deform the way they were weighted. Every vertex's dominant bone is also what ZombieBody uses to
cut the dismemberment pieces (gravelight/enemies/zombie_body.gd ``piece_mesh``).

Run on its own it exports one body GLB (Armature + Body + Parts + Hair_m / Hair_f + Body_LOD1 / Body_LOD2); the
zombie set (bodies + the nine outfit kits + textures) is built by build_all.py, which calls this module.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common as C  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CFG = json.load(open(os.path.join(REPO, "data", "gravelight", "art", "characters.json"), encoding="utf-8"))
KEYS = CFG["part_keys"]
RIG = C.Rig()


def key(name):
    return KEYS.index(name)


# ================================================================== parameters

class Params:
    """Everything that makes one body differ from another. Builds and sex scale come from anim.json "builds"
    (exported into rig.json) so the Godot side and this script agree."""

    def __init__(self, build="medium", female=False, living=False):
        self.build = build
        self.female = female
        self.living = living
        b = RIG.builds[build]
        self.w = float(b["w"])
        self.sh = float(b["shoulder"])
        self.hip = 1.0
        if female:
            f = RIG.builds["female"]
            self.w *= float(f["w"])
            self.sh *= float(f["shoulder"])
            self.hip = float(f["hip"])
        self.belly = {"thin": 0.0, "medium": 0.35, "heavy": 1.0}[build]
        self.lean = {"thin": 1.0, "medium": 0.4, "heavy": 0.0}[build]   # ribs / sunken belly (zombies)
        self.limb = 1.0 + (self.w - 1.0) * 0.8                           # limbs scale a bit less than the trunk
        self.a_pose = math.radians(float(CFG["body"]["a_pose_deg"]))
        self.subsurf = int(CFG["body"]["subsurf"])
        self.head_res = int(CFG["body"]["head_res"])
        self.sink = 1.0 if not living else float(CFG["body"]["living_sink"])

    def tag(self):
        return "%s_%s" % ("f" if self.female else "m", self.build)


# ================================================================== the skin-modifier skeleton (A-pose)

def shoulder(sx):
    return RIG.head["LeftUpperArm" if sx < 0 else "RightUpperArm"].copy()


def arm_dir(P, sx):
    return np.array([sx * math.sin(P.a_pose), -math.cos(P.a_pose), 0.0])


def arm_rot(P, sx):
    """Rest -> A-pose rotation of an arm about its shoulder (Godot Z axis)."""
    return C.rot_z(sx * P.a_pose)


def skin_graph(P):
    nodes, rad, edges = [], [], []

    def add(p, rx, rz=None):
        nodes.append(np.array(p, dtype=np.float64))
        rad.append((rx, rx if rz is None else rz))
        return len(nodes) - 1

    def chain(ids):
        for a, b in zip(ids, ids[1:]):
            edges.append((a, b))

    w, sh, hp, lw = P.w, P.sh, P.hip, P.limb
    waist = 0.93 if P.female else 1.0
    t = [
        add((0, 0.925, 0.012), 0.150 * w * hp, 0.104 * w),
        add((0, 1.065, 0.0), 0.130 * w * waist + 0.012 * P.belly, 0.092 * w + 0.01 * P.belly),
        add((0, 1.205, -0.004), 0.142 * w, 0.100 * w),
        add((0, 1.335, -0.006), 0.152 * w * sh, 0.104 * w),
        add((0, 1.44, 0.006), 0.128 * w * sh, 0.084 * w),
        add((0, 1.522, 0.012), 0.058 * w, 0.056 * w),
        add((0, 1.625, 0.016), 0.056, 0.056),
    ]
    chain(t)
    for sx in (-1.0, 1.0):
        S = shoulder(sx)
        S[0] = sx * (0.2 * (0.9 + 0.1 * sh))
        d = arm_dir(P, sx)
        A = 1.18 * lw
        a = [
            add(S + d * 0.0 + np.array([0, 0.004, 0]), 0.056 * A * sh, 0.054 * A),
            add(S + d * 0.07, 0.052 * A, 0.050 * A),
            add(S + d * 0.16, 0.046 * A, 0.045 * A),
            add(S + d * 0.255, 0.039 * A, 0.039 * A),
            add(S + d * 0.30, 0.036 * A, 0.037 * A),
            add(S + d * 0.355, 0.041 * A, 0.039 * A),
            add(S + d * 0.455, 0.033 * A, 0.033 * A),
            add(S + d * 0.60, 0.024 * A, 0.024 * A),
        ]
        edges.append((t[4], a[0]))
        chain(a)
        x = sx * 0.1
        L = 1.06 * lw
        # skin radii on the legs come out (depth, width): the skin frame turns on that chain
        leg = [
            add((sx * 0.09, 0.84, 0.008), 0.086 * L, 0.084 * L * hp),
            add((x, 0.70, 0.0), 0.076 * L, 0.072 * L),
            add((x, 0.565, -0.004), 0.059 * L, 0.056 * L),
            add((x, 0.47, -0.01), 0.050 * L, 0.048 * L),
            add((x, 0.37, 0.012), 0.056 * L, 0.050 * L),
            add((x, 0.23, 0.004), 0.040 * L, 0.038 * L),
            add((x, 0.095, 0.0), 0.031 * L, 0.030 * L),
            add((x, 0.045, -0.075), 0.038 * L, 0.03 * L),
            add((x, 0.03, -0.16), 0.034 * L, 0.024 * L),
        ]
        edges.append((t[0], leg[0]))
        chain(leg)
        heel = add((x, 0.04, 0.035), 0.028 * lw, 0.028 * lw)
        edges.append((leg[6], heel))
    return nodes, rad, edges


def skin_mesh(P):
    nodes, rad, edges = skin_graph(P)
    me = bpy.data.meshes.new("skin_src")
    me.from_pydata([tuple(v) for v in C.g2b(np.array(nodes))], edges, [])
    me.update()
    ob = bpy.data.objects.new("skin_src", me)
    C.link(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_x_symmetry = True
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.35
    for i, (rx, rz) in enumerate(rad):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (rx, rz)
        sv.use_root = i == 0
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = P.subsurf
    sub.render_levels = P.subsurf
    verts, faces = C.mesh_arrays(ob, evaluated=True)
    bpy.data.objects.remove(ob)
    return verts, faces


# ================================================================== sculpt fields (Godot frame, A-pose torso)

def sculpt_torso(P, v):
    out = v.copy()
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    front = C.smoothstep(0.0, -0.06, z)
    back = C.smoothstep(0.0, 0.06, z)
    trunk = (np.abs(x) < 0.24) & (y > 0.78) & (y < 1.55)
    # pecs / breasts
    for sx in (-1.0, 1.0):
        d2 = (x - sx * 0.07) ** 2 + (y - 1.33) ** 2
        if P.female:
            out[:, 2] -= trunk * front * 0.040 * C.gauss(d2 + 0.6 * (y - 1.30).clip(0) ** 2, 0.06)
        else:
            out[:, 2] -= trunk * front * 0.012 * C.gauss(d2, 0.06)
        # collarbones: a small ridge under the shoulder line
        d2c = ((x - sx * 0.075) / 1.8) ** 2 + (y - 1.435) ** 2
        out[:, 2] -= trunk * front * 0.006 * C.gauss(d2c, 0.018)
        # buttocks
        d2b = (x - sx * 0.065) ** 2 + (y - 0.875) ** 2
        out[:, 2] += trunk * back * (0.026 if P.female else 0.018) * C.gauss(d2b, 0.07) * P.hip
        # shoulder blades
        d2s = (x - sx * 0.08) ** 2 + (y - 1.36) ** 2
        out[:, 2] += trunk * back * 0.008 * C.gauss(d2s, 0.06)
    # belly: heavy builds push forward and a little sideways; thin zombies sink in under the ribs
    d2 = x ** 2 * 0.5 + (y - 1.08) ** 2
    out[:, 2] -= trunk * front * 0.052 * P.belly * C.gauss(d2, 0.11)
    out[:, 0] += trunk * np.sign(x) * 0.012 * P.belly * C.gauss((y - 1.06) ** 2, 0.08)
    if not P.living:
        out[:, 2] += trunk * front * 0.012 * P.lean * C.gauss(x ** 2 * 0.6 + (y - 1.13) ** 2, 0.06)
    # trapezius: the shoulder line slopes from the neck down to the deltoids
    ax_ = np.abs(x)
    top = C.smoothstep(1.39, 1.45, y) * (np.abs(z) < 0.09)
    out[:, 1] += top * 0.030 * C.gauss((ax_ - 0.075) ** 2, 0.045) * C.smoothstep(0.03, 0.055, ax_)
    # spine groove
    out[:, 2] -= trunk * back * 0.006 * C.gauss(x ** 2, 0.02) * C.smoothstep(0.95, 1.05, y) * C.smoothstep(1.5, 1.4, y)
    # knee caps / shins
    for sx in (-1.0, 1.0):
        d2k = (x - sx * 0.1) ** 2 + (y - 0.47) ** 2 * 1.5
        out[:, 2] -= (z < -0.02) * 0.01 * C.gauss(d2k, 0.03)
    return out


# ================================================================== weights

def bone_segments(P, apose=True):
    """[bone, a, b, radius, side] for the skinned trunk / limbs (side -1 left, 1 right, 0 both)."""
    w, lw = P.w, P.limb
    segs = [
        ["Hips", np.array([0, 0.80, 0.01]), np.array([0, 0.99, 0.01]), 0.150 * w, 0],
        ["Spine", np.array([0, 1.0, 0.0]), np.array([0, 1.21, 0.0]), 0.135 * w, 0],
        ["Chest", np.array([0, 1.21, 0.0]), np.array([0, 1.49, 0.0]), 0.145 * w, 0],
        ["Neck", np.array([0, 1.51, 0.01]), np.array([0, 1.66, 0.01]), 0.05, 0],
    ]
    for sx, side in ((-1.0, "Left"), (1.0, "Right")):
        hip = RIG.head[side + "UpperLeg"]
        knee = RIG.head[side + "LowerLeg"]
        ankle = RIG.head[side + "Foot"]
        segs.append([side + "UpperLeg", hip, knee, 0.068 * lw, sx])
        segs.append([side + "LowerLeg", knee, ankle, 0.044 * lw, sx])
        segs.append([side + "Foot", ankle + np.array([0, -0.01, 0.0]), ankle + np.array([0, -0.045, -0.15]), 0.034 * lw, sx])
        S = shoulder(sx)
        d = arm_dir(P, sx) if apose else np.array([0, -1.0, 0])
        segs.append([side + "UpperArm", S, S + d * 0.30, 0.048 * lw, sx])
        segs.append([side + "LowerArm", S + d * 0.30, S + d * 0.59, 0.036 * lw, sx])
        segs.append([side + "Hand", S + d * 0.59, S + d * 0.78, 0.03, sx])
    return segs


def distance_weights(P, v, segs, power=6.0):
    raw = np.zeros((v.shape[0], len(RIG.bones)))
    for name, a, b, r, side in segs:
        d, _t = C.seg_dist(v, a, b)
        nd = np.maximum(d / r, 0.05)
        wgt = nd ** (-power)
        if side < 0:
            wgt = wgt * C.smoothstep(0.03, -0.01, v[:, 0])
        elif side > 0:
            wgt = wgt * C.smoothstep(-0.03, 0.01, v[:, 0])
        raw[:, RIG.index[name]] += wgt
    return C.top_k_weights(raw)


def unpose(P, v_a, bi, bw):
    """A-pose -> rest: inverts the blended skinning matrix per vertex (only the arm chains move)."""
    n = v_a.shape[0]
    A = np.zeros((n, 3, 3))
    tvec = np.zeros((n, 3))
    mats = {}
    for b in RIG.bones:
        mats[b] = (np.eye(3), np.zeros(3))
    for sx, side in ((-1.0, "Left"), (1.0, "Right")):
        R = arm_rot(P, sx)
        S = shoulder(sx)
        for b in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            mats[b] = (R, S - R @ S)
    rot = np.stack([mats[b][0] for b in RIG.bones])
    tr = np.stack([mats[b][1] for b in RIG.bones])
    for k in range(bi.shape[1]):
        wk = bw[:, k][:, None, None]
        A += wk * rot[bi[:, k]]
        tvec += bw[:, k][:, None] * tr[bi[:, k]]
    return np.linalg.solve(A, (v_a - tvec)[:, :, None])[:, :, 0]


# ================================================================== head

def quad_sphere(n):
    """Unit quad-sphere: (verts, quads) with shared edges."""
    verts = []
    index = {}
    faces = []

    def vid(p):
        k = tuple(np.round(p, 6))
        if k not in index:
            index[k] = len(verts)
            verts.append(p)
        return index[k]

    axes = [(np.array([1, 0, 0]), np.array([0, 1, 0]), np.array([0, 0, 1])),
            (np.array([-1, 0, 0]), np.array([0, 1, 0]), np.array([0, 0, -1])),
            (np.array([0, 1, 0]), np.array([0, 0, 1]), np.array([1, 0, 0])),
            (np.array([0, -1, 0]), np.array([0, 0, -1]), np.array([1, 0, 0])),
            (np.array([0, 0, 1]), np.array([1, 0, 0]), np.array([0, 1, 0])),
            (np.array([0, 0, -1]), np.array([0, 1, 0]), np.array([1, 0, 0]))]
    for nrm, u, w in axes:
        grid = np.zeros((n + 1, n + 1), dtype=np.int64)
        for i in range(n + 1):
            for j in range(n + 1):
                a = math.tan((-1.0 + 2.0 * i / n) * math.pi / 4.0)   # equal-angle cube map: even quads
                b = math.tan((-1.0 + 2.0 * j / n) * math.pi / 4.0)
                p = nrm + u * a + w * b
                grid[i, j] = vid(p / np.linalg.norm(p))
        for i in range(n):
            for j in range(n):
                q = [grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]]
                c = np.mean([verts[k] for k in q], axis=0)
                e1 = verts[q[1]] - verts[q[0]]
                e2 = verts[q[2]] - verts[q[0]]
                if np.dot(np.cross(e1, e2), c) < 0:
                    q = q[::-1]
                faces.append(q)
    return np.array(verts), faces


HEAD_C = np.array([0.0, 1.705, -0.004])


def head_shape(P, u):
    """Sculpts unit directions u into the head (local to HEAD_C). Front is -Z."""
    sink = P.sink
    ax, ay, az = 0.081, 0.114, 0.099
    p = u * np.array([ax, ay, az])
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    front = C.smoothstep(0.0, -0.05, z)
    # cranium a touch wider at the back-top, the face narrower toward the jaw
    p[:, 0] *= 1.0 + 0.06 * C.smoothstep(-0.02, 0.06, y) * C.smoothstep(-0.04, 0.05, z)
    jaw = C.smoothstep(-0.015, -0.105, y)
    p[:, 0] *= 1.0 - 0.20 * jaw * (0.6 + 0.4 * front)
    # back of the skull tucks in toward the neck
    p[:, 2] = np.where(z > 0, z * (1.0 - 0.42 * C.smoothstep(-0.03, -0.115, y)), p[:, 2])
    # the face plane: flatter front, forward jaw / chin
    p[:, 2] = np.where(z < 0, p[:, 2] * (1.0 - 0.10 * C.smoothstep(0.06, 0.0, np.abs(y))), p[:, 2])
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    fr = C.smoothstep(-0.02, -0.07, z)
    # chin
    p[:, 2] -= fr * 0.010 * C.gauss(x ** 2 + (y + 0.10) ** 2, 0.025)
    # brow ridge
    p[:, 2] -= fr * 0.009 * C.gauss((y - 0.032) ** 2, 0.011) * C.gauss(x ** 2, 0.05)
    for sx in (-1.0, 1.0):
        # eye sockets: deep for the dead, shallow for the living
        d2 = ((x - sx * 0.031) / 1.25) ** 2 + (y - 0.010) ** 2
        p[:, 2] += fr * (0.010 + 0.012 * sink) * C.gauss(d2, 0.020)
        # cheekbones forward, cheeks hollow below them
        p[:, 2] -= fr * 0.006 * C.gauss((x - sx * 0.047) ** 2 + (y + 0.012) ** 2, 0.016)
        p[:, 2] += fr * (0.003 + 0.009 * sink) * C.gauss((x - sx * 0.044) ** 2 + (y + 0.048) ** 2, 0.02)
        # temples
        p[:, 0] -= sx * 0.004 * sink * C.gauss((y - 0.03) ** 2 + (z + 0.04) ** 2, 0.025) * (np.sign(x) == sx)
        # ears
        e2 = (y + 0.004) ** 2 / 1.6 + (z - 0.008) ** 2
        p[:, 0] += sx * (np.sign(x) == sx) * 0.016 * C.gauss(e2, 0.017)
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    # nose: bridge to tip
    prof = C.smoothstep(0.022, -0.002, y) * C.smoothstep(-0.05, -0.028, y)
    width = 0.009 + 0.011 * C.smoothstep(0.0, -0.035, y)
    p[:, 2] -= fr * 0.026 * prof * np.exp(-(x ** 2) / (width ** 2))
    # nostrils / philtrum groove
    p[:, 2] += fr * 0.003 * C.gauss(x ** 2 + (y + 0.046) ** 2, 0.006)
    # mouth: lips forward, the slit in between (slack for the dead: the jaw bone opens it further)
    p[:, 2] -= fr * 0.006 * C.gauss((y + 0.060) ** 2, 0.010) * C.gauss(x ** 2, 0.024)
    p[:, 2] += fr * (0.006 + 0.004 * sink) * C.gauss((y + 0.061) ** 2, 0.0035) * C.gauss(x ** 2, 0.022)
    return p


def head_mesh(P):
    u, faces = quad_sphere(P.head_res)
    loc = head_shape(P, u)
    # the mouth: a slit cut between the lips (the dead hang slack; the Jaw bone opens it further)
    keep = []
    for f in faces:
        c = loc[f].mean(axis=0)
        slit = (c[0] / 0.021) ** 2 + ((c[1] + 0.061) / (0.0045 + 0.002 * P.sink)) ** 2 < 1.0 and c[2] < -0.04
        if not slit:
            keep.append(f)
    faces = keep
    v = loc + HEAD_C
    # weights: Head; the jaw (below the mouth line, in front of the ears) on Jaw; the neck stub on Neck
    y = loc[:, 1]
    z = loc[:, 2]
    jaw = C.smoothstep(-0.052, -0.068, y) * C.smoothstep(0.035, -0.005, z)
    neck = C.smoothstep(-0.085, -0.112, y) * (1.0 - jaw)
    head = np.clip(1.0 - jaw - neck, 0.0, 1.0)
    raw = np.zeros((v.shape[0], len(RIG.bones)))
    raw[:, RIG.index["Head"]] = head
    raw[:, RIG.index["Jaw"]] = jaw
    raw[:, RIG.index["Neck"]] = neck
    bi, bw = C.top_k_weights(raw)
    return v, faces, bi, bw, loc


# ================================================================== hands

def tube(path, radii, sides=6, cap_end=True):
    """A tube along points (Godot frame) with per-point radii; returns verts, quads (+ an end cap fan)."""
    path = np.asarray(path, dtype=np.float64)
    verts, faces = [], []
    n = len(path)
    for i in range(n):
        t = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
        t /= np.linalg.norm(t)
        ref = np.array([1.0, 0, 0]) if abs(t[0]) < 0.9 else np.array([0, 0, 1.0])
        b1 = np.cross(t, ref)
        b1 /= np.linalg.norm(b1)
        b2 = np.cross(t, b1)
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(path[i] + radii[i] * (math.cos(a) * b1 + math.sin(a) * b2))
    for i in range(n - 1):
        for k in range(sides):
            a0 = i * sides + k
            a1 = i * sides + (k + 1) % sides
            faces.append([a0, a1, a1 + sides, a0 + sides])
    if cap_end:
        tip = len(verts)
        verts.append(path[-1] + (path[-1] - path[-2]) / np.linalg.norm(path[-1] - path[-2]) * radii[-1] * 0.8)
        base = (n - 1) * sides
        for k in range(sides):
            faces.append([base + k, base + (k + 1) % sides, tip])
    return np.array(verts), faces


def rounded_box(c, half, n=(2, 3, 2), round_k=0.55):
    """A subdivided box blended toward an ellipsoid (a soft palm)."""
    u, faces = quad_sphere(2)
    # quad_sphere(2) is a cube-ish sphere; push back toward the cube by round_k
    cube = u / np.max(np.abs(u), axis=1, keepdims=True)
    p = cube * (1.0 - round_k) + u * round_k
    return c + p * half, faces


def hand_mesh(P, sx):
    """One hand at the rig's rest wrist, palm toward the body (+x for the left hand), fingers down and curled."""
    wrist = RIG.head["LeftHand" if sx < 0 else "RightHand"].copy()
    lw = P.limb * (0.94 if P.female else 1.0)
    inward = -sx   # palm normal along +x for the left hand
    palm_c = wrist + np.array([inward * 0.004, -0.048, -0.004])
    pv, pf = rounded_box(palm_c, np.array([0.014, 0.045, 0.038]) * lw)
    verts = [pv]
    faces = [pf]
    off = len(pv)
    claw = 0.55 if not P.living else 0.3
    for k, (zf, ln) in enumerate(((-0.027, 0.074), (-0.009, 0.082), (0.009, 0.078), (0.026, 0.064))):
        base = wrist + np.array([inward * 0.002, -0.088, zf]) * np.array([1, lw, lw])
        pts = [base]
        ang = 0.0
        seg = ln * lw / 3.0
        d = np.array([0.0, -1.0, 0.0])
        for j in range(3):
            ang += claw * (0.35 + 0.25 * j)
            d = np.array([inward * math.sin(ang), -math.cos(ang), 0.0])
            pts.append(pts[-1] + d * seg)
        r = np.array([0.0105, 0.0095, 0.0085, 0.0075]) * lw
        tv, tf = tube(pts, r, sides=6)
        verts.append(tv)
        faces.append([[i + off for i in f] for f in tf])
        off += len(tv)
    # thumb: from the palm's front edge, forward and down, curling across the palm
    tb = wrist + np.array([inward * 0.006, -0.03, -0.03]) * np.array([1, lw, lw])
    pts = [tb, tb + np.array([inward * 0.008, -0.022, -0.016]) * lw, tb + np.array([inward * 0.016, -0.044, -0.022]) * lw,
           tb + np.array([inward * 0.022, -0.062, -0.02]) * lw]
    tv, tf = tube(pts, np.array([0.013, 0.011, 0.0095, 0.0085]) * lw, sides=6)
    verts.append(tv)
    faces.append([[i + off for i in f] for f in tf])
    v = np.concatenate(verts)
    fl = [f for group in faces for f in group]
    # weights: Hand, the top of the palm blends into the forearm
    raw = np.zeros((v.shape[0], len(RIG.bones)))
    side = "Left" if sx < 0 else "Right"
    blend = C.smoothstep(wrist[1] - 0.02, wrist[1] + 0.01, v[:, 1])
    raw[:, RIG.index[side + "Hand"]] = 1.0 - 0.5 * blend
    raw[:, RIG.index[side + "LowerArm"]] = 0.5 * blend
    bi, bw = C.top_k_weights(raw)
    return v, fl, bi, bw


# ================================================================== eyes, teeth, mouth (the kit surface's "parts")

def uv_sphere(c, r, seg=8, rings=5):
    verts = []
    faces = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            verts.append(c + r * np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)]))
    for i in range(rings):
        for j in range(seg):
            a = i * seg + j
            b = i * seg + (j + 1) % seg
            faces.append([a, a + seg, b + seg, b])
    return np.array(verts), faces


def box(c, half):
    s = np.array([[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], dtype=np.float64)
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [0, 4, 7, 3]]
    return c + s * half, f


class PartsAcc:
    """Accumulates small parts: verts, faces, per-vertex key and a single bone (+ optional second bone blend)."""

    def __init__(self):
        self.v, self.f, self.k, self.bi, self.bw = [], [], [], [], []
        self.n = 0

    def add(self, verts, faces, keyname, bone, bone2=None, w2=0.0):
        verts = np.asarray(verts)
        self.v.append(verts)
        self.f.extend([[i + self.n for i in f] for f in faces])
        self.k.extend([key(keyname)] * len(verts))
        b = np.zeros((len(verts), 4), dtype=np.int32)
        w = np.zeros((len(verts), 4))
        b[:, 0] = RIG.index[bone]
        w[:, 0] = 1.0 - w2
        if bone2 is not None and w2 > 0.0:
            b[:, 1] = RIG.index[bone2]
            w[:, 1] = w2
        self.bi.append(b)
        self.bw.append(w)
        self.n += len(verts)

    def arrays(self):
        return np.concatenate(self.v), self.f, np.array(self.k), np.concatenate(self.bi), np.concatenate(self.bw)


def face_parts(P, head_loc_fn=None):
    acc = PartsAcc()
    for sx in (-1.0, 1.0):
        # the eyeball sits in the socket; the dead show only the violet glow, the living a white with an iris
        c = HEAD_C + np.array([sx * 0.031, 0.009, -0.066 + 0.006 * P.sink])
        if P.living:
            v, f = uv_sphere(c, 0.0125)
            acc.add(v, f, "eye_white", "Head")
            v, f = uv_sphere(c + np.array([0, 0, -0.0105]), 0.0055, 6, 3)
            acc.add(v, f, "iris", "Head")
        else:
            v, f = uv_sphere(c, 0.0118)
            v = c + (v - c) * np.array([1.0, 0.85, 0.55])   # a flattened glowing lens deep in the socket
            acc.add(v, f, "eye", "Head")
    # mouth cavity (dark), upper teeth on the head, lower teeth on the jaw
    v, f = box(HEAD_C + np.array([0, -0.064, -0.054]), np.array([0.02, 0.012, 0.012]))
    acc.add(v, f, "dark", "Head", "Jaw", 0.5)
    v, f = box(HEAD_C + np.array([0, -0.0565, -0.069]), np.array([0.0145, 0.0042, 0.0035]))
    acc.add(v, f, "teeth", "Head")
    v, f = box(HEAD_C + np.array([0, -0.0665, -0.067]), np.array([0.013, 0.0038, 0.0035]))
    acc.add(v, f, "teeth", "Jaw")
    return acc


def hairline(female, loc):
    """Height (head-local y) above which the hair grows, around the head: low at the nape, high at the brow."""
    x, z = loc[:, 0], loc[:, 2]
    ff = C.smoothstep(0.03, -0.075, z)
    back = -0.088 if female else -0.052
    brow = 0.050 if female else 0.058
    hl = back + (brow - back) * ff
    side = C.smoothstep(0.05, 0.07, np.abs(x)) * C.smoothstep(-0.05, -0.02, z) * C.smoothstep(0.05, 0.02, z)
    return np.maximum(hl, (0.022 if not female else 0.0) * side + hl * (1 - side))


def hair_meshes(P, head_v, head_faces, head_loc):
    """Hair_m: a short cropped cap; Hair_f: hair drawn back into a low bun. Built from the head surface: inside
    the hairline it floats `thick` above the skin, outside it sinks under it, so the visible edge is the smooth
    hairline curve rather than the quad grid."""
    out = {}
    nrm = head_loc / np.linalg.norm(head_loc, axis=1, keepdims=True)
    for name, female, thick in (("Hair_m", False, 0.0065), ("Hair_f", True, 0.010)):
        m = C.smoothstep(-0.007, 0.007, head_loc[:, 1] - hairline(female, head_loc))
        keep_v = m > 0.02
        faces = [f for f in head_faces if any(keep_v[i] for i in f)]
        used = sorted({i for f in faces for i in f})
        remap = {o: n for n, o in enumerate(used)}
        off = thick * m[used] - 0.005 * (1.0 - m[used])
        v = head_v[used] + nrm[used] * off[:, None]
        f = [[remap[i] for i in fc] for fc in faces]
        acc = PartsAcc()
        acc.add(v, f, "hair", "Head")
        if female:
            bv, bf = uv_sphere(HEAD_C + np.array([0, -0.045, 0.098]), 0.038, 8, 5)
            acc.add(bv, bf, "hair", "Head", "Neck", 0.15)
        out[name] = acc
    return out


# ================================================================== the whole body

class Body:
    """Arrays of one built body (Godot frame, rest pose) before they become Blender objects."""

    def __init__(self):
        self.v = None
        self.f = None
        self.bi = None
        self.bw = None
        self.region = None      # per vertex: 0 trunk/limbs, 1 head, 2 hands
        self.parts = None
        self.hair = {}
        self.head_loc = None


def build(P):
    v_a, f_skin = skin_mesh(P)
    v_a = sculpt_torso(P, v_a)
    segs = bone_segments(P, apose=True)
    bi, bw = distance_weights(P, v_a, segs)
    v_rest = unpose(P, v_a, bi, bw)
    hv, hf, hbi, hbw, hloc = head_mesh(P)
    pieces = [(v_rest, f_skin, bi, bw, 0), (hv, hf, hbi, hbw, 1)]
    for sx in (-1.0, 1.0):
        v, f, b, w = hand_mesh(P, sx)
        pieces.append((v, f, b, w, 2))
    B = Body()
    vs, fs, bis, bws, regs = [], [], [], [], []
    off = 0
    for v, f, b, w, r in pieces:
        vs.append(v)
        fs.extend([[i + off for i in fc] for fc in f])
        bis.append(b)
        bws.append(w)
        regs.append(np.full(len(v), r))
        off += len(v)
    B.v = np.concatenate(vs)
    B.f = fs
    B.bi = np.concatenate(bis)
    B.bw = np.concatenate(bws)
    B.region = np.concatenate(regs)
    B.head_loc = hloc
    B.parts = face_parts(P)
    B.hair = hair_meshes(P, hv, hf, hloc)
    return B


def dominant_bone(bi, bw):
    return bi[np.arange(len(bi)), np.argmax(bw, axis=1)]


# ================================================================== Blender objects + export

def object_from(name, v, f, bi, bw, colors=None):
    ob = C.mesh_from_arrays(name, v, f)
    C.shade_smooth(ob)
    C.set_weights(ob, RIG, bi, bw)
    if colors is not None:
        C.set_color_attr(ob, colors)
    return ob


def part_colors(keys, ao=None):
    n = len(keys)
    col = np.zeros((n, 4))
    col[:, 0] = np.asarray(keys) / 255.0
    col[:, 1] = 1.0 if ao is None else ao
    col[:, 2] = 0.0
    col[:, 3] = 1.0
    return col


def body_colors(n, ao=None, mask=None):
    col = np.zeros((n, 4))
    col[:, 0] = key("skin") / 255.0
    col[:, 1] = 1.0 if ao is None else ao
    m = np.zeros(n, dtype=np.int64) if mask is None else mask.astype(np.int64)
    col[:, 2] = (m & 0xFF) / 255.0
    col[:, 3] = np.where((m & 0x100) != 0, 0.0, 1.0)
    return col


def unwrap(body_ob, B):
    """The canonical UV layout: smart project, then the head x2.2 and the hands x1.4 the texel density of the
    rest (faces matter most), re-packed."""
    C.smart_uv(body_ob)
    face_reg = np.array([int(B.region[f[0]]) for f in B.f])
    C.scale_face_uvs(body_ob, face_reg == 1, 2.2)
    C.scale_face_uvs(body_ob, face_reg == 2, 1.4)


def decimate_to(ob, target):
    """Collapse-decimates in place to about `target` triangles (UVs, weights and colours interpolate)."""
    n = C.tri_count(ob)
    if n <= target:
        return n
    dec = ob.modifiers.new("Dec", "DECIMATE")
    dec.ratio = float(target) / float(n)
    dec.use_collapse_triangulate = True
    dec.use_symmetry = True
    dec.symmetry_axis = "X"
    C.apply_modifiers(ob)
    return C.tri_count(ob)


def make_lod(src, ratio, name):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = name
    ob.data.name = name
    C.link(ob)
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    dec = ob.modifiers.new("Dec", "DECIMATE")
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    C.apply_modifiers(ob)
    return ob


def body_objects(P, B, mask=None, ao=None):
    """Body / Parts / Hair_* / LODs as Blender objects (not yet bound)."""
    objs = {}
    body = object_from("Body", B.v, B.f, B.bi, B.bw, body_colors(len(B.v), ao, mask))
    objs["Body"] = body
    pv, pf, pk, pbi, pbw = B.parts.arrays()
    objs["Parts"] = object_from("Parts", pv, pf, pbi, pbw, part_colors(pk))
    for name, acc in B.hair.items():
        hv, hf, hk, hbi, hbw = acc.arrays()
        objs[name] = object_from(name, hv, hf, hbi, hbw, part_colors(hk))
    return objs


def finish_and_export(P, objs, path, lods=True):
    arm = C.build_armature(RIG)
    if lods:
        objs["Body_LOD1"] = make_lod(objs["Body"], float(CFG["lod"]["lod1_ratio"]), "Body_LOD1")
        objs["Body_LOD2"] = make_lod(objs["Body"], float(CFG["lod"]["lod2_ratio"]), "Body_LOD2")
    for ob in objs.values():
        C.bind(ob, arm)
    C.export_glb(path, list(objs.values()), arm)
    stats = {n: C.tri_count(o) for n, o in objs.items()}
    return stats


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"sex": "m", "build": "medium", "living": False, "out": "", "preview": ""}
    for s in a:
        if s == "--living":
            out["living"] = True
        elif s.startswith("--") and "=" in s:
            k, v = s[2:].split("=", 1)
            out[k] = v
    return out


def main():
    a = args()
    C.reset_scene()
    P = Params(a["build"], a["sex"] == "f", a["living"])
    B = build(P)
    objs = body_objects(P, B)
    unwrap(objs["Body"], B)
    decimate_to(objs["Body"], int(CFG["body"]["body_tris"]))
    path = a["out"] or os.path.join(REPO, "assets", "ours", "characters", "human_base" if P.living else "zombie_base",
                                   (CFG["living_file"] if P.living else CFG["zombie_file"]) % (P.tag().split("_")[0], P.build))
    stats = finish_and_export(P, objs, path)
    print("[make_body] %s -> %s tris %s" % (P.tag(), path, stats))
    if a["preview"]:
        import preview
        preview.render(a["preview"], P.tag(), [o for n, o in objs.items() if "LOD" not in n])


if __name__ == "__main__":
    main()
