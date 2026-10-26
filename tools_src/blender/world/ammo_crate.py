"""The ammunition crate (the ammo box; UPDATE_05 section 5, DECISIONS T-094).

    blender -b -P tools_src/blender/world/ammo_crate.py

Writes assets/ours/world/ammo_crate/model.glb: a small-arms crate of planks painted olive drab (worn to the wood at
the edges), end cleats, rope handles, a yellow lot band, its lid propped open on strap hinges against the wall
behind it so the cartons inside show: a row of printed cartons, one opened with the rounds standing nose-up,
bandoliers of stripper clips, a steel ammo can carrying the hurricane lantern (the glass and the flickering light
are AmmoBox's, at AmmoBoxArt.lantern_pos()), a few rounds spilled on the floor in front.

Frame as AmmoBoxArt: origin = floor centre, front -Z, the box 1.0 x 0.56 deep inside AmmoBox's unchanged collider
(1.0 x 0.62 x 0.56); the open lid stands over the back edge, within 2 cm of the footprint.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

HW, HD, BOT, TOP, LID = 0.5, 0.28, 0.06, 0.56, 0.62
OD = "mats_olive_drab"


def round_upright(p, at, h=0.07):
    W.cyl(p, (at[0], at[1] + h * 0.35, at[2]), 0.0065, h * 0.7, "mats_brass", segs=6, smooth=True)
    W.cyl(p, (at[0], at[1] + h * 0.82, at[2]), 0.0065, h * 0.3, "mats_copper", r2=0.002, segs=6)


def round_lying(p, at, yaw):
    W.cyl(p, at, 0.0065, 0.052, "mats_brass", rot=(0, yaw, 90), segs=6)
    a = math.radians(yaw)
    tip = (at[0] + math.cos(a) * 0.035, at[1], at[2] - math.sin(a) * 0.035)
    W.cyl(p, tip, 0.0065, 0.018, "mats_copper", r2=0.002, rot=(0, yaw, -90), segs=6)


def carton(p, c, w, d, h, band, yaw=0.0, opened=False):
    W.obox(p, (c[0], c[1] + h * 0.5, c[2]), (w, h, d), "mats_cardboard", (0, yaw, 0), 0.004)
    W.obox(p, (c[0], c[1] + h * 0.55, c[2]), (w + 0.002, h * 0.25, d + 0.002), W.paint(band), (0, yaw, 0), 0.0)
    if opened:
        W.obox(p, (c[0], c[1] + h + 0.025, c[2] + d * 0.5 + 0.02), (w, 0.004, 0.06), "mats_cardboard", (-60, yaw, 0), 0.0)
        for ix in range(5):
            for iz in range(3):
                if (ix, iz) in ((3, 1), (1, 2)):
                    continue
                round_upright(p, (c[0] - w * 0.4 + ix * w * 0.2, c[1] + h - 0.045, c[2] - d * 0.33 + iz * d * 0.33))


def build():
    p = W.Part("Body")
    J = W.jit
    for sz in (-0.17, 0.17):
        W.box(p, (-HW - 0.02, 0.0, sz - 0.045), (HW + 0.02, BOT, sz + 0.045), "lib_planks", 0.01)
    # the floor and the inside of the box, bare wood
    W.box(p, (-HW + 0.02, BOT, -HD + 0.02), (HW - 0.02, BOT + 0.03, HD - 0.02), "lib_planks", 0.0)
    # three planks a face, painted outside, bare where the paint wore off the edges
    for i in range(3):
        y0 = BOT + i * (TOP - BOT) / 3.0 + 0.003
        y1 = BOT + (i + 1) * (TOP - BOT) / 3.0 - 0.003
        for s in (-1.0, 1.0):
            d = 0.025 + J(i, int(s) + 2, 0.004)
            W.box(p, (-HW + 0.03, y0, s * (HD - d)), (HW - 0.03, y1, s * HD), OD, 0.008)
            W.box(p, (-HW + 0.03, y0 + 0.004, s * (HD - d) - s * 0.001), (HW - 0.03, y1 - 0.004, s * (HD - d) + s * 0.0005), "lib_planks", 0.0)
            W.box(p, (s * (HW - 0.03), y0, -HD + 0.01), (s * HW, y1, HD - 0.01), OD, 0.008)
    # the top rim, worn to the wood
    for s in (-1.0, 1.0):
        W.box(p, (-HW + 0.01, TOP - 0.012, s * (HD - 0.03)), (HW - 0.01, TOP, s * HD), "lib_planks", 0.003)
    # end cleats, rope handles through iron eyes
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            W.box(p, (sx * (HW - 0.065), BOT, sz * (HD + 0.012)), (sx * (HW + 0.005), TOP, sz * (HD - 0.03)), OD, 0.006)
        W.box(p, (sx * HW, TOP - 0.07, -HD + 0.02), (sx * (HW + 0.02), TOP - 0.01, HD - 0.02), OD, 0.006)
        W.box(p, (sx * HW, BOT + 0.01, -HD + 0.02), (sx * (HW + 0.02), BOT + 0.07, HD - 0.02), OD, 0.006)
        ex = sx * (HW + 0.022)
        for ez in (-0.12, 0.12):
            W.torus(p, (ex, 0.36, ez), 0.018, 0.005, "lib_iron", rot=(0, 0, 90), segs=8, rsegs=4)
        W.tube(p, [(ex, 0.36, -0.12), (ex + sx * 0.05, 0.31, -0.06), (ex + sx * 0.065, 0.295, 0.0), (ex + sx * 0.05, 0.31, 0.06), (ex, 0.36, 0.12)],
               0.013, "lib_burlap", 6)
    # the yellow lot band, nail heads along the cleats
    W.box(p, (-0.3, 0.115, -HD - 0.006), (0.3, 0.14, -HD + 0.004), "mats_yellow_paint", 0.0)
    for sx in (-1.0, 1.0):
        for ny in (0.12, 0.29, 0.46):
            W.dot(p, (sx * (HW - 0.033), ny, -HD - 0.013), 0.006, "mats_steel", 4)
    # the lid, propped open on its strap hinges against the wall: painted outside (toward the wall), bare inside
    hz = HD + 0.012
    W.box(p, (-HW - 0.012, TOP, hz - 0.035), (HW + 0.012, TOP + 0.58, hz - 0.012), OD, 0.006)
    W.box(p, (-HW + 0.01, TOP + 0.02, hz - 0.036), (HW - 0.01, TOP + 0.56, hz - 0.034), "lib_planks", 0.0)
    for bx in (-0.33, 0.33):
        W.box(p, (bx - 0.04, TOP + 0.01, hz - 0.048), (bx + 0.04, TOP + 0.57, hz - 0.035), "lib_planks", 0.004)
    for hx in (-0.3, 0.3):
        W.cyl(p, (hx, TOP + 0.004, hz), 0.012, 0.09, "lib_iron", axis="x", segs=8)
        W.box(p, (hx - 0.025, TOP - 0.1, hz - 0.004), (hx + 0.025, TOP, hz + 0.002), "lib_iron", 0.002)
        W.box(p, (hx - 0.025, TOP, hz - 0.012), (hx + 0.025, TOP + 0.1, hz - 0.006), "lib_iron", 0.002)
    # the hasps hang open on the front
    for hx in (-0.3, 0.3):
        W.obox(p, (hx, TOP - 0.06, -HD - 0.018), (0.044, 0.1, 0.008), "lib_iron", (0, 0, 8), 0.002)
        W.dot(p, (hx, TOP - 0.02, -HD - 0.022), 0.008, "mats_steel", 4)
    # inside: printed cartons in a row along the front, one opened, the bandoliers over them
    carton(p, (-0.32, BOT + 0.03, -0.12), 0.2, 0.15, 0.26, "8a2a1e", 4.0)
    carton(p, (-0.1, BOT + 0.03, -0.12), 0.2, 0.15, 0.26, "8a2a1e", -3.0, True)
    carton(p, (-0.25, BOT + 0.03, 0.08), 0.24, 0.16, 0.3, "2a4a6a", -6.0)
    carton(p, (0.05, BOT + 0.03, 0.08), 0.18, 0.16, 0.22, "8a2a1e", 8.0)
    W.tube(p, [(-0.44, 0.52, -0.2), (-0.3, 0.44, -0.2), (-0.15, 0.47, -0.18), (0.0, 0.44, -0.16), (0.12, 0.5, -0.2)], 0.022, "lib_canvas", 6)
    for k in range(5):
        W.obox(p, (-0.4 + k * 0.11, 0.5 - (0.04 if k % 2 else 0.0), -0.215), (0.05, 0.035, 0.012), "mats_brass", (0, 0, 10 - k * 5), 0.002)
    # the steel ammo can at the back right that carries the lantern
    ac = (0.33, BOT + 0.03, 0.13)
    W.box(p, (ac[0] - 0.13, ac[1], ac[2] - 0.12), (ac[0] + 0.13, LID - 0.012, ac[2] + 0.12), "mats_olive_drab", 0.01)
    W.box(p, (ac[0] - 0.135, LID - 0.014, ac[2] - 0.125), (ac[0] + 0.135, LID, ac[2] + 0.125), "mats_steel", 0.004)
    W.box(p, (ac[0] - 0.05, 0.38, ac[2] - 0.122), (ac[0] + 0.05, 0.42, ac[2] - 0.12), "mats_yellow_paint", 0.0)
    # the hurricane lantern's frame (AmmoBoxArt's): fount, collar, cap, side tubes, guard wires, bail
    lc = (0.33, LID + 0.115, 0.13)
    W.cyl(p, (lc[0], LID + 0.022, lc[2]), 0.06, 0.044, "mats_red_paint", segs=14, bevel=0.006)
    W.cyl(p, (lc[0], LID + 0.047, lc[2]), 0.045, 0.008, "lib_iron", segs=12)
    W.cyl(p, (lc[0], lc[1] + 0.085, lc[2]), 0.048, 0.012, "lib_iron", segs=12)
    W.cyl(p, (lc[0], lc[1] + 0.115, lc[2]), 0.06, 0.05, "mats_red_paint", r2=0.02, segs=12)
    W.cyl(p, (lc[0], lc[1] + 0.15, lc[2]), 0.016, 0.02, "lib_iron", segs=8)
    for sx in (-0.058, 0.058):
        W.strut(p, (lc[0] + sx, LID + 0.04, lc[2]), (lc[0] + sx, lc[1] + 0.11, lc[2]), 0.01, "lib_iron", True, 5)
    for k in range(4):
        a = math.tau * k / 4.0 + 0.4
        W.strut(p, (lc[0] + math.cos(a) * 0.05, lc[1] - 0.06, lc[2] + math.sin(a) * 0.05),
                (lc[0] + math.cos(a) * 0.05, lc[1] + 0.075, lc[2] + math.sin(a) * 0.05), 0.004, "lib_iron", True, 4)
    W.torus(p, (lc[0], lc[1] + 0.19, lc[2]), 0.04, 0.005, "lib_iron", axis="z", segs=12, rsegs=4)
    # spilled in front: a few rounds and a stripper clip on the floor
    for (at, yaw) in (((0.12, 0.007, -HD - 0.12), 35.0), ((-0.22, 0.007, -HD - 0.2), -80.0), ((0.3, 0.007, -HD - 0.08), 150.0)):
        round_lying(p, at, yaw)
    for k in range(5):
        W.cyl(p, (-0.05 + k * 0.013, 0.007, -HD - 0.25), 0.0062, 0.052, "mats_brass", axis="z", segs=6)
    W.box(p, (-0.058, 0.0, -HD - 0.28), (0.01, 0.014, -HD - 0.272), "mats_steel", 0.0)
    p.build()


if __name__ == "__main__":
    W.reset()
    build()
    W.export("ammo_crate", "Ammunition crate", "the ammo box: olive-drab plank crate, lid propped open, cartons, the lantern's can",
             "ammo_crate.py")
