"""Barricade planks (UPDATE_05 section 5, DECISIONS T-094).

    blender -b -P tools_src/blender/world/barricade_planks.py

Writes assets/ours/world/barricade_planks/model.glb: six rough-sawn planks (Plank0..Plank5), one per board slot of a
window, each with its own splintered end, knots, a crack or a missing corner, and hand-driven nails (round heads,
one or two bent over) on the room side. Each plank is centred on its node origin, 1.85 m long (a 1.6 m window plus
the overlap Barricade gives it), 0.16 x 0.045 m, the room side (+Z) toward the player; Barricade scales X to other
window widths and keeps its own tear / rebuild tweens.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

LEN, H, T = 1.85, 0.16, 0.045


def splinter_end(p, x_end, side, seed):
    """A ragged end: the plank's last few cm as a jagged prism (teeth along the cut)."""
    n = 5
    pts = []
    for k in range(n + 1):
        y = -H * 0.5 + H * k / n
        pts.append((x_end + side * (0.01 + abs(W.jit(seed, k, 0.035))), y))
    pts = [(x_end, -H * 0.5)] + pts + [(x_end, H * 0.5)]
    if side < 0:
        pts.reverse()
    W.prism(p, pts, -T * 0.5, T * 0.5, "lib_planks", bevel=0.0)


def nail(p, at, bent=False):
    W.cyl(p, (at[0], at[1], T * 0.5 + 0.004), 0.009, 0.008, "lib_iron", axis="z", segs=8)
    if bent:
        W.tube(p, [(at[0], at[1], T * 0.5 + 0.006), (at[0], at[1], T * 0.5 + 0.03), (at[0] + 0.035, at[1] + 0.006, T * 0.5 + 0.04)], 0.003, "lib_iron", 4)


def plank(i):
    p = W.Part("Plank%d" % i)
    cut_l = [0.05, 0.11, 0.0, 0.08, 0.02, 0.13][i]
    cut_r = [0.0, 0.03, 0.09, 0.0, 0.12, 0.04][i]
    x0, x1 = -LEN * 0.5 + cut_l, LEN * 0.5 - cut_r
    W.box(p, (x0, -H * 0.5 + W.jit(i, 1, 0.006), -T * 0.5), (x1, H * 0.5 + W.jit(i, 2, 0.006), T * 0.5), "lib_planks", 0.006, segs=1)
    if cut_l > 0.0:
        splinter_end(p, x0, -1.0, i * 7 + 1)
    if cut_r > 0.0:
        splinter_end(p, x1, 1.0, i * 7 + 3)
    # a knot, a crack (a dark split along the grain), a missing corner on two of them
    kx = -0.45 + i * 0.17
    W.cyl(p, (kx, 0.02 * (1 if i % 2 else -1), T * 0.5 + 0.0005), 0.022, 0.002, "mats_char@local", axis="z", segs=10)
    cx = 0.3 - i * 0.12
    W.box(p, (cx - 0.18, -0.004 + W.jit(i, 9, 0.03), T * 0.5 - 0.004), (cx + 0.18, 0.002 + W.jit(i, 9, 0.03), T * 0.5 + 0.0008), "mats_char@local", 0.0)
    if i in (1, 4):
        W.obox(p, (x1 - 0.06, H * 0.5 - 0.01, 0.0), (0.09, 0.05, T + 0.004), "mats_char@local", (0, 0, 35), 0.0)
    # nails: two at each end into the frame, a bent one somewhere along
    for e in (-1.0, 1.0):
        ex = (x0 + 0.08) if e < 0 else (x1 - 0.08)
        for k in range(2):
            nail(p, (ex + W.jit(i, k + (3 if e > 0 else 0), 0.012), -0.045 + k * 0.09 + W.jit(i, k + 5, 0.006)))
    nail(p, (0.25 * (1 if i % 2 else -1) + W.jit(i, 11, 0.1), 0.03), bent=True)
    if i % 3 == 0:
        nail(p, (-0.1 + W.jit(i, 12, 0.1), -0.04), bent=True)
    p.build(uv_seed="plank%d" % i)


if __name__ == "__main__":
    W.reset()
    for i in range(6):
        plank(i)
    W.export("barricade_planks", "Barricade planks", "six board variants, one per window slot", "barricade_planks.py")
