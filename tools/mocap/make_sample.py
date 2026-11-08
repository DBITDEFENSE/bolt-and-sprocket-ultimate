#!/usr/bin/env python3
"""The mocap pipeline's test clip (T-210): a synthetic BVH, our own work (generated, no capture data).

    python -I tools/mocap/make_sample.py [out.bvh]     (default tests/data/mocap/sample_walk.bvh)

A Mixamo-named skeleton in centimetres, T-pose rest, +Y up, facing +Z (the way phone-mocap apps write BVH), 30 fps,
5 s: standing with the arms down, a clap at 0.7 s (the slate the filming guide asks for, so the shot starts 1.0 s
after it, at 1.7 s), then a walk forward at about 1.2 m/s from 1.5 s. The legs swing on sine curves while the hips
glide at a steady speed, so the planted foot slides the way raw phone captures do, and every rotation carries a
little seeded noise (jitter): the two things the foot lock and the smoothing must fix.
"""
import math
import os
import random
import sys

FPS = 30
SECONDS = 5.0

# name, parent, offset (cm), channels
JOINTS = [
    ("Hips", None, (0, 95, 0)),
    ("Spine", "Hips", (0, 5, 0)), ("Spine1", "Spine", (0, 10, 0)), ("Spine2", "Spine1", (0, 11, 0)),
    ("Neck", "Spine2", (0, 30, 0)), ("Head", "Neck", (0, 8, 0)),
    ("LeftShoulder", "Spine2", (3, 20, 0)), ("LeftArm", "LeftShoulder", (14, 5, 0)),
    ("LeftForeArm", "LeftArm", (28, 0, 0)), ("LeftHand", "LeftForeArm", (27, 0, 0)),
    ("RightShoulder", "Spine2", (-3, 20, 0)), ("RightArm", "RightShoulder", (-14, 5, 0)),
    ("RightForeArm", "RightArm", (-28, 0, 0)), ("RightHand", "RightForeArm", (-27, 0, 0)),
    ("LeftUpLeg", "Hips", (10, -4, 0)), ("LeftLeg", "LeftUpLeg", (0, -44, 0)), ("LeftFoot", "LeftLeg", (0, -40, 0)),
    ("LeftToeBase", "LeftFoot", (0, -6, 14)),
    ("RightUpLeg", "Hips", (-10, -4, 0)), ("RightLeg", "RightUpLeg", (0, -44, 0)), ("RightFoot", "RightLeg", (0, -40, 0)),
    ("RightToeBase", "RightFoot", (0, -6, 14)),
]
ENDS = {"Head": (0, 20, 0), "LeftHand": (10, 0, 0), "RightHand": (-10, 0, 0), "LeftToeBase": (0, 0, 4), "RightToeBase": (0, 0, 4)}


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def pose(t):
    """{joint: (z, x, y) degrees}, hips position (cm)."""
    r = {n: [0.0, 0.0, 0.0] for n, _, _ in JOINTS}
    clap = smoothstep(0.3, 0.7, t) * (1.0 - smoothstep(0.7, 1.2, t))
    walk = smoothstep(1.5, 2.0, t)
    ph = 2 * math.pi * 0.9 * max(0.0, t - 1.5)
    # arms: down at the sides, forward and in for the clap, a gentle swing on the walk
    r["LeftArm"] = [-80 + 60 * clap, 15 * walk * math.sin(ph), -108 * clap]
    r["RightArm"] = [80 - 60 * clap, -15 * walk * math.sin(ph), 108 * clap]
    r["LeftForeArm"] = [0, 0, -10 * walk]
    r["RightForeArm"] = [0, 0, 10 * walk]
    # legs: the stance half sweeps the thigh back at an even rate (the foot nearly still on the ground, a little
    # slower than the hips: the slide), the swing half brings it forward with the knee bent; the foot kept flat
    for side, off in (("Left", 0.0), ("Right", 0.5)):
        u = ((ph / (2 * math.pi)) + off) % 1.0
        if u < 0.5:
            fwd = 22.0 * (1.0 - 4.0 * u)
            kn = 5.0
        else:
            s = (u - 0.5) * 2.0
            fwd = -22.0 + 44.0 * (0.5 - 0.5 * math.cos(math.pi * s))
            kn = 5.0 + 50.0 * math.sin(math.pi * s)
        th = -fwd * walk
        kn *= walk
        r[side + "UpLeg"] = [0, th, 0]
        r[side + "Leg"] = [0, kn, 0]
        r[side + "Foot"] = [0, -(th + kn), 0]
    r["Spine"] = [0, 3 * walk, 4 * walk * math.sin(ph)]
    r["Neck"] = [0, -2 * walk, 0]
    hips = (0.0, 95 - 2.0 * walk * abs(math.sin(ph)), 0.0)
    return r, hips


def write(path, seed=7):
    rnd = random.Random(seed)
    kids = {}
    for n, p, _ in JOINTS:
        kids.setdefault(p, []).append(n)
    off = {n: o for n, _, o in JOINTS}
    lines = ["HIERARCHY"]

    def emit(n, depth):
        ind = "\t" * depth
        lines.append("%s%s %s" % (ind, "ROOT" if depth == 0 else "JOINT", n))
        lines.append(ind + "{")
        lines.append("%s\tOFFSET %.4f %.4f %.4f" % ((ind,) + tuple(off[n])))
        if depth == 0:
            lines.append(ind + "\tCHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation")
        else:
            lines.append(ind + "\tCHANNELS 3 Zrotation Xrotation Yrotation")
        for c in kids.get(n, []):
            emit(c, depth + 1)
        if n in ENDS:
            lines.append(ind + "\tEnd Site")
            lines.append(ind + "\t{")
            lines.append("%s\t\tOFFSET %.4f %.4f %.4f" % ((ind,) + tuple(ENDS[n])))
            lines.append(ind + "\t}")
        lines.append(ind + "}")
    emit("Hips", 0)
    order = []

    def walk_order(n):
        order.append(n)
        for c in kids.get(n, []):
            walk_order(c)
    walk_order("Hips")
    frames = int(SECONDS * FPS)
    dist = 0.0
    lines += ["MOTION", "Frames: %d" % frames, "Frame Time: %.7f" % (1.0 / FPS)]
    for f in range(frames):
        r, hp = pose(f / FPS)
        dist += 120.0 * smoothstep(1.5, 2.0, f / FPS) / FPS   # 1.2 m/s, eased in
        vals = [hp[0] + rnd.gauss(0, 0.3), hp[1] + rnd.gauss(0, 0.3), dist + rnd.gauss(0, 0.3)]
        for n in order:
            z, x, y = r[n]
            vals += [z + rnd.gauss(0, 0.8), x + rnd.gauss(0, 0.8), y + rnd.gauss(0, 0.8)]
        lines.append(" ".join("%.4f" % v for v in vals))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests", "data", "mocap", "sample_walk.bvh")
    print(write(out))
