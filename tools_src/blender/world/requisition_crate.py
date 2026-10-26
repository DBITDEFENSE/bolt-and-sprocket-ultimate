"""The Lost Requisition Crate (the mystery box; UPDATE_05 section 5, DECISIONS T-094).

    blender -b -P tools_src/blender/world/requisition_crate.py

Writes assets/ours/world/requisition_crate/model.glb: a heavy period field chest on skids. Planked oak over a dark
core, riveted iron corner brackets and straps, rope handles through iron eyes, a hasp under a broken wax seal,
the Ledger's tally stencil and the requisition bars, the Helvetia works plate, a chalk sigil scratched on the
front; a planked, strapped lid on rear strap hinges whose underside has grown violet Nachtglas veins.

Same frame and pivots as the procedural CrateArt it replaces (MysteryCrate reads it): origin = floor centre, front
-Z, body 1.4 x 0.6 x 0.7 inside the unchanged collider.
  Body   the chest (pivot at the origin: it sinks when Herr Tamtam drums)
  Lid    pivot = the hinge pins (0, TOP + 0.1, HD); built below and in front of them so it swings up clear of a wall
  Spot   always there: the chalk footprint, the iron stake and the lantern's cage (the glass and light are the script's)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

HW, HD, TOP = 0.7, 0.35, 0.6


def body():
    p = W.Part("Body")
    J = W.jit
    for sz in (-0.26, 0.26):
        W.box(p, (-HW - 0.03, 0.0, sz - 0.05), (HW + 0.03, 0.065, sz + 0.05), "lib_planks", 0.012)
    W.box(p, (-HW + 0.01, 0.06, -HD + 0.01), (HW - 0.01, 0.11, HD - 0.01), "lib_planks", 0.004)
    for s in (-1.0, 1.0):
        W.box(p, (-HW + 0.02, 0.1, s * (HD - 0.02)), (HW - 0.02, TOP, s * (HD - 0.06)), "mats_char@local", 0.0)
        W.box(p, (s * (HW - 0.02), 0.1, -HD + 0.02), (s * (HW - 0.06), TOP, HD - 0.02), "mats_char@local", 0.0)
    # four rows of planks on every face, each a hair proud or shy of its neighbours
    for i in range(4):
        y0 = 0.1 + i * 0.125
        y1 = y0 + 0.118
        for s in (-1.0, 1.0):
            d = 0.04 + J(i, int(s) + 2, 0.005)
            W.box(p, (-HW + 0.02 + J(i, 5, 0.006), y0, s * (HD - d)), (HW - 0.02 + J(i, 6, 0.006), y1, s * HD), "lib_planks", 0.01)
            d2 = 0.04 + J(i, int(s) + 7, 0.005)
            W.box(p, (s * (HW - d2), y0, -HD + 0.02), (s * HW, y1, HD - 0.02), "lib_planks", 0.01)
    # iron corner brackets, rivets
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            W.box(p, (sx * (HW + 0.012), 0.07, sz * HD - sz * 0.09), (sx * HW, TOP + 0.005, sz * (HD + 0.012)), "lib_iron", 0.004)
            W.box(p, (sx * HW - sx * 0.09, 0.07, sz * (HD + 0.012)), (sx * (HW + 0.012), TOP + 0.005, sz * HD), "lib_iron", 0.004)
            for ry in (0.14, 0.33, 0.52):
                W.dot(p, (sx * (HW + 0.014), ry, sz * (HD - 0.05)), 0.011, "mats_steel@local", 4)
                W.dot(p, (sx * (HW - 0.05), ry, sz * (HD + 0.014)), 0.011, "mats_steel@local", 4)
    W.box(p, (-HW - 0.012, 0.075, -HD - 0.012), (HW + 0.012, 0.125, HD + 0.012), "lib_iron", 0.004)
    for sx in (-0.4, 0.4):
        for sz in (-1.0, 1.0):
            W.box(p, (sx - 0.03, 0.06, sz * HD), (sx + 0.03, TOP + 0.005, sz * (HD + 0.012)), "lib_iron", 0.003)
            for ry in (0.2, 0.44):
                W.dot(p, (sx, ry, sz * (HD + 0.014)), 0.01, "mats_steel@local", 4)
    # rope handles through iron eyes
    for sx in (-1.0, 1.0):
        ex = sx * (HW + 0.012)
        for ez in (-0.18, 0.18):
            W.torus(p, (ex + sx * 0.012, 0.4, ez), 0.025, 0.007, "lib_iron", rot=(0, 0, 90), segs=10, rsegs=4)
        W.tube(p, [(ex, 0.4, -0.18), (ex + sx * 0.07, 0.345, -0.1), (ex + sx * 0.095, 0.325, 0.0), (ex + sx * 0.07, 0.345, 0.1), (ex, 0.4, 0.18)],
               0.017, "lib_burlap", 6)
    # the hasp's staple and the broken wax seal with its ribbons
    W.box(p, (-0.045, 0.44, -HD - 0.018), (0.045, 0.5, -HD - 0.004), "lib_iron", 0.003)
    W.torus(p, (0, 0.47, -HD - 0.02), 0.016, 0.005, "mats_steel@local", axis="z", segs=10, rsegs=4)
    W.lathe(p, [(0.0, 0.0), (0.045, 0.0), (0.05, 0.006), (0.044, 0.016), (0.0, 0.018)], "mats_red_paint@local", c=(0, 0.545, -HD - 0.02), rot=(-90, 0, 0), segs=14)
    W.obox(p, (0.02, 0.5, -HD - 0.03), (0.03, 0.1, 0.004), W.paint("6e1410"), (0, 0, 18), 0.0)
    W.obox(p, (-0.02, 0.5, -HD - 0.03), (0.03, 0.1, 0.004), W.paint("6e1410"), (0, 0, -18), 0.0)
    # the brass works plate, screws
    W.box(p, (-0.62, 0.35, -HD - 0.052), (-0.2, 0.44, -HD - 0.044), "mats_brass@local", 0.003)
    for px in (-0.605, -0.215):
        for py in (0.362, 0.428):
            W.dot(p, (px, py, -HD - 0.053), 0.006, "mats_steel@local", 4)
    # stencil bars either side of the lot number, the Ledger's tally (the ǂ every machine's Scrip slot carries)
    for sx in (-1.0, 1.0):
        for k in range(3):
            W.obox(p, (sx * (0.48 + k * 0.05), 0.16, -HD - 0.045), (0.03, 0.1 - k * 0.02, 0.003), "mats_black_paint@local", (0, 0, sx * 20.0), 0.0)
    tc = (0.43, 0.43, -HD - 0.046)
    for dx in (-0.025, 0.025):
        W.obox(p, (tc[0] + dx, tc[1], tc[2]), (0.016, 0.13, 0.003), "mats_black_paint@local", (0, 0, -8), 0.0)
    for dy in (-0.022, 0.022):
        W.obox(p, (tc[0], tc[1] + dy, tc[2]), (0.11, 0.014, 0.003), "mats_black_paint@local", None, 0.0)
    # a chalk sigil scratched beside the hasp: a ring, a crossbar, three ticks
    sc = (0.62, 0.24, -HD - 0.046)
    W.torus(p, sc, 0.06, 0.006, "chalk", axis="z", segs=18, rsegs=4)
    W.obox(p, sc, (0.16, 0.007, 0.003), "chalk", (0, 0, -12), 0.0)
    for k in range(3):
        W.obox(p, (sc[0] - 0.04 + k * 0.04, sc[1], sc[2]), (0.006, 0.05, 0.003), "chalk", (0, 0, 8 - k * 8), 0.0)
    # the straw and the cradle inside are the script's (they glow); just a dark floor here
    p.build()


def lid():
    piv = (0.0, TOP + 0.1, HD)
    p = W.Part("Lid", piv)
    oy = TOP + 0.1 - 0.1   # the lid's own frame sits 0.1 below the hinge pins
    z0 = HD - 2.0 * HD

    def L(x, y, z):
        return (x, oy + y, z)
    W.box(p, L(-HW - 0.02, 0.0, z0 - 0.02), L(HW + 0.02, 0.035, HD + 0.01), "lib_planks", 0.006)
    for i in range(5):
        pz = z0 + i * 0.14
        W.box(p, L(-HW - 0.02, 0.03, pz + 0.004), L(HW + 0.02, 0.085 + W.jit(i, 11, 0.006), pz + 0.136), "lib_planks", 0.01)
    for sx in (-0.4, 0.4):
        W.box(p, L(sx - 0.03, 0.08, z0 - 0.034), L(sx + 0.03, 0.1, HD + 0.01), "lib_iron", 0.003)
        W.box(p, L(sx - 0.03, -0.02, z0 - 0.034), L(sx + 0.03, 0.1, z0 - 0.02), "lib_iron", 0.003)
        for rz in (-0.25, 0.0, 0.25):
            W.dot(p, L(sx, 0.102, rz), 0.01, "mats_steel@local", 4)
    for hx in (-0.45, 0.45):
        W.cyl(p, (hx, TOP + 0.1, HD), 0.024, 0.16, "lib_iron", axis="x", segs=12)
        W.box(p, L(hx - 0.04, 0.085, HD - 0.2), L(hx + 0.04, 0.1, HD), "lib_iron", 0.003)
        W.dot(p, L(hx, 0.102, HD - 0.17), 0.01, "mats_steel@local", 4)
    # the hasp hanging over the staple
    W.box(p, L(-0.04, -0.12, z0 - 0.05), L(0.04, 0.09, z0 - 0.036), "lib_iron", 0.004)
    W.box(p, L(-0.04, 0.085, z0 - 0.05), L(0.04, 0.1, z0 + 0.12), "lib_iron", 0.003)
    # the works plate on top
    W.box(p, L(-0.23, 0.095, HD - 0.5), L(0.23, 0.106, HD - 0.26), "mats_brass@local", 0.002)
    for px in (-0.215, 0.215):
        for pz in (HD - 0.485, HD - 0.275):
            W.dot(p, L(px, 0.107, pz), 0.006, "mats_steel@local", 4)
    # the underside: a dark lining with violet veins grown into the grain
    W.box(p, L(-HW + 0.06, -0.006, z0 + 0.06), L(HW - 0.06, 0.0, HD - 0.06), "mats_char@local", 0.0)
    for (a, b, n) in [((-0.08, -0.25), (-0.55, 0.15), 7), ((0.05, -0.27), (0.5, 0.1), 7), ((-0.3, -0.07), (-0.48, -0.2), 3), ((0.28, -0.09), (0.6, -0.15), 4)]:
        pts = []
        for k in range(n + 1):
            t = k / float(n)
            x = a[0] + (b[0] - a[0]) * t + (W.jit(k, n, 0.03) if 0 < k < n else 0.0)
            z = a[1] + (b[1] - a[1]) * t + (W.jit(k + 3, n, 0.03) if 0 < k < n else 0.0)
            pts.append(L(x, -0.0085, z))
        W.tube(p, pts, 0.006, "mats_nachtglas_vein@local", 4)
    p.build()


def spot():
    p = W.Part("Spot")
    w, d = HW + 0.06, HD + 0.06
    for (a, b) in [((-w, -d), (w, -d + 0.02)), ((-w, d - 0.02), (w, d)), ((-w, -d), (-w + 0.02, d)), ((w - 0.02, -d), (w, d))]:
        W.box(p, (a[0], 0.002, a[1]), (b[0], 0.006, b[1]), "chalk", 0.0)
    for r in (45, -45):
        W.obox(p, (0, 0.004, -d - 0.08), (0.09, 0.004, 0.012), "chalk", (0, r, 0), 0.0)
    sx, sz = -(HW + 0.14), -0.1
    W.cyl(p, (sx, 0.04, sz), 0.07, 0.08, "lib_iron", r2=0.02, segs=10)
    W.strut(p, (sx, 0.0, sz), (sx, 1.38, sz), 0.03, "lib_iron", True, 6)
    W.tube(p, [(sx, 1.38, sz), (sx + 0.07, 1.42, sz), (sx + 0.13, 1.37, sz), (sx + 0.14, 1.3, sz)], 0.014, "lib_iron", 6)
    lc = (sx + 0.14, 1.09, sz)
    W.torus(p, (lc[0], lc[1] + 0.19, lc[2]), 0.035, 0.007, "lib_iron", axis="z", segs=10, rsegs=4)
    W.cyl(p, (lc[0], lc[1] + 0.14, lc[2]), 0.05, 0.03, "lib_iron", segs=12)
    W.cyl(p, (lc[0], lc[1] + 0.12, lc[2]), 0.07, 0.05, "lib_iron", r2=0.035, segs=12)
    W.cyl(p, (lc[0], lc[1] - 0.11, lc[2]), 0.055, 0.04, "lib_iron", segs=12)
    for k in range(4):
        a = math.tau * k / 4.0 + math.pi / 4.0
        W.strut(p, (lc[0] + math.cos(a) * 0.052, lc[1] - 0.09, lc[2] + math.sin(a) * 0.052),
                (lc[0] + math.cos(a) * 0.052, lc[1] + 0.1, lc[2] + math.sin(a) * 0.052), 0.008, "lib_iron", True, 4)
    p.build()


if __name__ == "__main__":
    W.reset()
    body()
    lid()
    spot()
    W.export("requisition_crate", "The Lost Requisition Crate", "the mystery box: chest, lid on its hinges, the spot's chalk and lantern stake",
             "requisition_crate.py")
