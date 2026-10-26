"""The story machines (UPDATE_05 section 5, DECISIONS T-094): the Crucible, the Armorer's Bench, the field radio, the
power lever's cabinet and the exfil beacon.

    blender -b -P tools_src/blender/world/story_machines.py [-- crucible bench radio lever beacon]

Writes assets/ours/world/{crucible,armorers_bench,field_radio,power_lever,exfil_beacon}/model.glb. Each keeps the
frame, collider and the script-owned pieces of the procedural builder it replaces (InteractableArt.crucible_body,
ArmorersBench.bench_art, InteractableArt.field_radio, InteractableArt.power_switch_body / power_lever,
ExfilPoint.build_greybox): the Crucible's glowing mouth, embers, offer float and brass plate; the bench's vise
pistol, lamp light and sign label; the radio's lit dial window and glow; the lever's AUS / EIN lamps; the beacon's
lamp glass, light, ground ring and board labels are still drawn by the scripts at the same places.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402


def crystal(p, base, n, size, seed, axis=(0.0, 1.0, 0.0), m="mats_nachtglas_crystal"):
    """A cluster of six-sided Nachtglas points growing from `base` around `axis`."""
    ax = W.V(axis).normalized()
    for k in range(n):
        a = W.jit(seed, k, 0.6)
        b = W.jit(seed + 5, k, 0.6)
        d = (ax + W.V((a, 0.0, b))).normalized()
        L = size * (0.55 + abs(W.jit(seed + 9, k, 0.45)))
        r = L * 0.16
        tip = W.V(base) + d * L
        mid = W.V(base) + d * (L * 0.72)
        W.tube(p, [W.V(base), mid], r, m, 6, caps=True, smooth=False)
        W.tube(p, [mid, mid + d * 0.0001], r, m, 6, caps=False, smooth=False)
        W.cyl(p, tuple((mid + tip) * 0.5), r, (tip - mid).length, m, r2=0.002, segs=6, smooth=False,
              rot=tuple(math.degrees(v) for v in W.Vector((0, 1, 0)).rotation_difference(d).to_euler("ZXY")))


# ================================================================== the Crucible

def crucible():
    W.reset()
    p = W.Part("Body")
    # plinth: dressed stone steps
    W.box(p, (-1.3, 0, -1.1), (1.3, 0.16, 1.05), "lib_fieldstone", 0.02, segs=2)
    W.box(p, (-1.12, 0.16, -0.92), (1.12, 0.26, 0.92), "mats_cellar_stone", 0.015)
    # the brick hearth with an iron-bound top edge
    W.box(p, (-1.02, 0.26, -0.8), (1.02, 0.98, 0.88), "mats_brick_cellar", 0.01)
    for sx in (-1.0, 1.0):
        W.box(p, (sx * 1.02 - 0.05, 0.26, -0.83), (sx * 1.02 + 0.03, 0.98, -0.75), "lib_iron", 0.006)
    W.box(p, (-1.06, 0.95, -0.84), (1.06, 1.02, 0.92), "lib_iron", 0.008)
    W.rivets(p, (-0.98, 0.985, -0.85), (0.98, 0.985, -0.85), 12, 0.016, "mats_brass")
    # the firebox: an elliptic riveted iron drum on the hearth, domed, with Nachtglas grown through its seams
    rx, rz = 0.98, 0.76
    W.lathe(p, [(1.0, 1.0), (1.0, 1.75), (0.92, 1.95), (0.72, 2.12), (0.42, 2.24), (0.3, 2.27)], "mats_loco_black", c=(0, 0, 0.05),
            segs=28, sx=rx, sz=rz, cap_lo=False, cap_hi=False)
    for by in (1.08, 1.42, 1.74):
        W.torus(p, (0, by, 0.05), 1.0, 0.025, "lib_iron", rot=None, segs=28, rsegs=4)
    for by in (1.08, 1.74):
        for k in range(12):
            a = math.pi + math.pi * (k + 0.5) / 12.0
            W.dot(p, (math.cos(a) * rx * 1.03, by, 0.05 + math.sin(a) * rz * 1.03), 0.018, "mats_brass", 4)
    for (a, b) in [((-0.5, 1.9, -0.6), (-0.2, 2.18, -0.32)), ((0.45, 1.78, -0.66), (0.28, 2.14, -0.36)),
                   ((-0.86, 1.6, -0.32), (-0.68, 1.98, -0.08)), ((0.86, 1.58, -0.3), (0.66, 2.02, 0.0))]:
        mid = ((a[0] + b[0]) * 0.5 + 0.04, (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5 - 0.02)
        W.tube(p, [a, mid, b], 0.022, "mats_nachtglas_vein", 5)
    # the hood and the flue up into the alcove's shaft (it passes the vault's soffit)
    W.lathe(p, [(0.34, 2.24), (0.3, 2.5), (0.24, 2.8), (0.24, 3.3)], "mats_loco_black", c=(0, 0, 0.1), segs=18, cap_lo=False, cap_hi=False)
    for fy in (2.45, 2.75):
        W.torus(p, (0, fy, 0.1), 0.28 if fy < 2.6 else 0.25, 0.018, "lib_iron", segs=18, rsegs=4)
    # the mouth: a cast surround, a voussoir arch of iron, the grate in front of the fire, the feed door's frame
    for sx in (-1.0, 1.0):
        W.box(p, (sx * 0.52, 0.6, -0.86), (sx * 0.68, 1.52, -0.72), "lib_iron", 0.01)
    W.box(p, (-0.68, 0.58, -0.88), (0.68, 0.74, -0.72), "lib_iron", 0.01)
    for k in range(9):
        a = math.pi * k / 8.0
        W.obox(p, (math.cos(a) * 0.6, 1.47 + math.sin(a) * 0.32, -0.8), (0.17, 0.14, 0.14), "lib_iron", (0, 0, math.degrees(a) - 90.0), 0.012)
    W.obox(p, (0, 1.82, -0.84), (0.16, 0.2, 0.12), "mats_brass", None, 0.015)
    for gx in range(6):
        W.strut(p, (-0.42 + gx * 0.168, 0.76, -0.88), (-0.42 + gx * 0.168, 1.42, -0.88), 0.028, "lib_iron", True, 6)
    W.strut(p, (-0.5, 1.08, -0.9), (0.5, 1.08, -0.9), 0.024, "lib_iron", True, 6)
    # the feed door below the mouth (its brass plate is the script's lore plaque)
    W.box(p, (0.36, 0.3, -0.82), (0.88, 0.56, -0.8), "lib_iron", 0.006)
    for hy in (0.34, 0.52):
        W.cyl(p, (0.9, hy, -0.82), 0.014, 0.05, "lib_iron", segs=8)
    # Nachtglas buttresses and crystal clusters at the four corners
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            base = (sx * 1.08, 0.26, sz * 0.82)
            tip = (sx * 0.9, 1.7, sz * 0.66)
            W.strut(p, base, tip, 0.12, "mats_nachtglas_dim", False)
            crystal(p, (sx * 1.18, 0.16, sz * 0.96), 4, 0.42, 71 + int(sx * 3 + sz))
            crystal(p, tip, 3, 0.3, 91 + int(sx * 3 + sz), (tip[0] - base[0], tip[1] - base[1], tip[2] - base[2]))
    # bellows on the +X flank, piped into the drum
    bl = (1.3, 0.6, 0.42)
    W.box(p, (bl[0] - 0.2, bl[1] - 0.03, bl[2] - 0.35), (bl[0] + 0.2, bl[1] + 0.03, bl[2] + 0.35), "mats_furniture", 0.008)
    for i in range(5):
        hw = 0.17 - abs(i - 2.0) * 0.02
        W.box(p, (bl[0] - hw, bl[1] + 0.05 + i * 0.05, bl[2] - 0.3), (bl[0] + hw, bl[1] + 0.09 + i * 0.05, bl[2] + 0.3), "lib_leather", 0.008)
    W.box(p, (bl[0] - 0.2, bl[1] + 0.35, bl[2] - 0.35), (bl[0] + 0.2, bl[1] + 0.4, bl[2] + 0.35), "mats_furniture", 0.008)
    W.tube(p, [(bl[0] - 0.1, bl[1] + 0.12, bl[2] - 0.3), (1.05, 0.95, 0.0), (0.95, 1.2, -0.1)], 0.04, "mats_copper", 8)
    W.strut(p, (bl[0], bl[1] + 0.4, bl[2]), (bl[0], bl[1] + 0.9, bl[2]), 0.02, "lib_iron", True, 6)
    # the sight glass on the -X front: violet suspension in a brass cage
    sg = (-0.82, 1.15, -0.72)
    W.cyl(p, sg, 0.055, 0.6, "mats_nachtglas_liquid", segs=12)
    for cy in (-0.32, 0.32):
        W.cyl(p, (sg[0], sg[1] + cy, sg[2]), 0.085, 0.05, "mats_brass", segs=14, bevel=0.008)
    for k in range(3):
        a = math.tau * k / 3.0
        W.strut(p, (sg[0] + math.cos(a) * 0.075, sg[1] - 0.3, sg[2] + math.sin(a) * 0.075),
                (sg[0] + math.cos(a) * 0.075, sg[1] + 0.3, sg[2] + math.sin(a) * 0.075), 0.012, "mats_brass", True, 5)
    # the pressure gauge on the +X front
    gp = (0.84, 1.28, -0.68)
    W.cyl(p, gp, 0.13, 0.06, "mats_brass", rot=(90, -35, 0), segs=20, bevel=0.01)
    W.cyl(p, (gp[0] - 0.018, gp[1], gp[2] - 0.026), 0.11, 0.01, "mats_gauge_face", rot=(90, -35, 0), segs=20)
    W.obox(p, (gp[0] - 0.03, gp[1] + 0.03, gp[2] - 0.036), (0.012, 0.09, 0.006), "mats_red_paint", (0, -35, -30), 0.0)
    # the wrought-iron arch carrying the nameplate (the label is the script's)
    for sx in (-1.0, 1.0):
        W.strut(p, (sx * 1.22, 0.16, -1.05), (sx * 1.22, 2.55, -1.05), 0.09, "lib_iron", False)
        W.cyl(p, (sx * 1.22, 0.26, -1.05), 0.12, 0.2, "lib_iron", r2=0.05, segs=8)
        W.dot(p, (sx * 1.22, 2.6, -1.05), 0.06, "mats_brass", 8)
    pts = []
    for k in range(13):
        t = k / 12.0
        pts.append((-1.22 + 2.44 * t, 2.55 + math.sin(t * math.pi) * 0.4, -1.05))
    W.tube(p, pts, 0.04, "lib_iron", 6)
    for k in range(5):   # scrollwork between the arch and the plate
        x = -0.9 + k * 0.45
        W.torus(p, (x, 2.86 + math.sin((x + 1.22) / 2.44 * math.pi) * 0.1 - 0.08, -1.05), 0.06, 0.01, "lib_iron", axis="z", segs=12, rsegs=4, arc=300.0)
    W.box(p, (-0.66, 2.48, -1.09), (0.66, 2.76, -1.03), "mats_nameplate", 0.006)
    W.box(p, (-0.69, 2.45, -1.07), (0.69, 2.79, -1.02), "mats_brass", 0.008)
    # a quench trough and tongs at the -X side
    W.box(p, (-1.32, 0.0, -0.4), (-1.12, 0.36, 0.5), "lib_iron", 0.01)
    W.box(p, (-1.3, 0.3, -0.38), (-1.14, 0.33, 0.48), W.paint("1a1c22"), 0.0)
    W.tube(p, [(-1.25, 0.3, 0.3), (-1.05, 1.4, 0.55)], 0.018, "lib_iron", 6)
    W.tube(p, [(-1.2, 0.3, 0.1), (-1.0, 1.25, 0.35)], 0.016, "lib_iron", 6)
    p.build()
    return W.export("crucible", "The Crucible", "the Nachtglas forge: brick hearth, iron firebox, crystal buttresses, flue, arch", "story_machines.py")


# ================================================================== the Armorer's Bench

def bench():
    W.reset()
    TOP = 0.9
    p = W.Part("Body")
    # oak top (thick, with a front apron), legs with stretchers, a lower shelf
    W.box(p, (-0.75, TOP - 0.06, -0.72), (0.75, TOP, -0.02), "lib_planks", 0.008)
    W.box(p, (-0.72, TOP - 0.16, -0.7), (0.72, TOP - 0.06, -0.66), "lib_planks", 0.006)
    for lx in (-0.68, 0.68):
        for lz in (-0.66, -0.08):
            W.box(p, (lx - 0.035, 0, lz - 0.035), (lx + 0.035, TOP - 0.06, lz + 0.035), "lib_planks", 0.006, uvrot=True)
        W.box(p, (lx - 0.025, 0.12, -0.64), (lx + 0.025, 0.17, -0.1), "lib_planks", 0.004)
    W.box(p, (-0.7, 0.18, -0.64), (0.7, 0.21, -0.06), "lib_planks", 0.004)
    W.box(p, (-0.36 - 0.18, 0.21, -0.48), (-0.36 + 0.18, 0.39, -0.22), "mats_cardboard", 0.006)
    W.box(p, (0.21, 0.21, -0.48), (0.43, 0.33, -0.18), "mats_olive_drab", 0.008)
    # the parts board on the wall: a pegboard of tools, the sign board
    W.box(p, (-0.74, TOP, -0.035), (0.74, TOP + 0.85, -0.005), "lib_planks", 0.006)
    for k in range(9):
        for j in range(5):
            W.cyl(p, (-0.64 + k * 0.16, TOP + 0.1 + j * 0.15, -0.036), 0.006, 0.002, "mats_char", axis="z", segs=6)
    for k in range(6):
        W.obox(p, (-0.6 + k * 0.08, TOP + 0.5, -0.045), (0.012, 0.26, 0.006), "mats_steel", None, 0.0)          # files and drifts
    W.obox(p, (0.05, TOP + 0.55, -0.045), (0.05, 0.24, 0.008), "mats_steel", (0, 0, 18), 0.002)               # a wrench
    W.obox(p, (0.22, TOP + 0.6, -0.05), (0.03, 0.22, 0.025), "mats_furniture", None, 0.004)                   # hammer
    W.obox(p, (0.22, TOP + 0.71, -0.05), (0.09, 0.03, 0.03), "lib_iron", None, 0.004)
    W.obox(p, (0.45, TOP + 0.45, -0.045), (0.16, 0.012, 0.006), "mats_brass", None, 0.0)                     # cleaning rod
    W.torus(p, (0.58, TOP + 0.62, -0.04), 0.07, 0.008, "mats_steel", axis="z", segs=16, rsegs=4)            # spring wire
    for k in range(4):   # parts trays on a shelf: springs, pins, a bolt, a magazine
        W.box(p, (-0.66 + k * 0.17, TOP + 0.3, -0.12), (-0.52 + k * 0.17, TOP + 0.34, -0.03), "lib_iron", 0.003)
    W.box(p, (-0.68, TOP + 0.28, -0.13), (0.0, TOP + 0.3, -0.02), "lib_planks", 0.003)
    W.obox(p, (0.0, TOP + 0.78, -0.03), (0.62, 0.11, 0.012), W.paint("2c2a26"), None, 0.003)                  # the sign board
    # the vise at the left end: base, jaws with leather pads, the screw and tommy bar
    W.box(p, (-0.66, TOP, -0.58), (-0.36, TOP + 0.06, -0.3), "mats_machine_green", 0.01)
    W.box(p, (-0.64, TOP + 0.06, -0.47), (-0.38, TOP + 0.2, -0.445), "mats_machine_green", 0.006)
    W.box(p, (-0.64, TOP + 0.06, -0.415), (-0.38, TOP + 0.2, -0.39), "mats_machine_green", 0.006)
    W.box(p, (-0.63, TOP + 0.185, -0.452), (-0.39, TOP + 0.2, -0.445), "lib_leather", 0.0)
    W.box(p, (-0.63, TOP + 0.185, -0.415), (-0.39, TOP + 0.2, -0.408), "lib_leather", 0.0)
    W.cyl(p, (-0.51, TOP + 0.12, -0.285), 0.022, 0.21, "mats_steel", axis="z", segs=10)
    W.cyl(p, (-0.51, TOP + 0.12, -0.19), 0.012, 0.18, "mats_steel", axis="x", segs=8)
    for sx in (-0.6, -0.42):
        W.dot(p, (sx, TOP + 0.12, -0.19), 0.016, "mats_steel", 6)
    # on the top: files, punches, a screwdriver, a rag, an oil can, a box of .45, the parts tray, a field manual
    for k in range(4):
        W.obox(p, (-0.18 + k * 0.03, TOP + 0.006, -0.6), (0.008, 0.008, 0.12), "mats_brass" if k % 2 == 0 else "mats_steel", (0, 10 - k * 6, 0), 0.0)
    W.obox(p, (0.05, TOP + 0.012, -0.55), (0.025, 0.025, 0.1), "mats_red_paint", (0, -35, 0), 0.004)
    W.obox(p, (-0.12, TOP + 0.01, -0.28), (0.2, 0.02, 0.16), "lib_wool", (0, 22, 0), 0.006)
    W.lathe(p, [(0.0, 0.0), (0.045, 0.0), (0.045, 0.1), (0.02, 0.13), (0.008, 0.14)], "mats_red_paint", c=(0.58, TOP, -0.18), segs=12)
    W.tube(p, [(0.58, TOP + 0.13, -0.18), (0.63, TOP + 0.16, -0.22), (0.68, TOP + 0.17, -0.25)], 0.004, "mats_brass", 4)
    W.obox(p, (0.18, TOP + 0.035, -0.22), (0.11, 0.07, 0.08), "mats_cardboard", (0, -8, 0), 0.004)
    W.obox(p, (0.18, TOP + 0.072, -0.22), (0.112, 0.004, 0.082), W.paint("7a2a1e"), (0, -8, 0), 0.0)
    W.box(p, (0.28, TOP, -0.62), (0.52, TOP + 0.02, -0.46), "lib_iron", 0.003)
    for k in range(5):
        W.dot(p, (0.31 + k * 0.045, TOP + 0.03, -0.54 + (k % 2) * 0.03), 0.008, "mats_brass", 4)
    W.obox(p, (-0.2, TOP + 0.012, -0.45), (0.15, 0.022, 0.2), W.paint("4a4a32"), (0, 14, 0), 0.003)
    # the gooseneck lamp on the right (the light is the script's)
    W.cyl(p, (0.58, TOP + 0.015, -0.08), 0.07, 0.03, "lib_iron", segs=14, bevel=0.006)
    W.tube(p, [(0.58, TOP + 0.03, -0.08), (0.56, TOP + 0.25, -0.14), (0.5, TOP + 0.45, -0.28), (0.42, TOP + 0.47, -0.38)], 0.012, "lib_iron", 6)
    W.lathe(p, [(0.02, 0.0), (0.04, -0.02), (0.085, -0.09), (0.088, -0.1)], "mats_enamel_green", c=(0.38, TOP + 0.48, -0.42), segs=16, cap_lo=False, cap_hi=False)
    W.dot(p, (0.38, TOP + 0.41, -0.42), 0.03, "mats_bulb_warm", 8)
    p.build()
    return W.export("armorers_bench", "The Armorer's Bench", "gunsmith's bench: vise, parts board, gooseneck lamp", "story_machines.py")


# ================================================================== the field radio

def radio():
    W.reset()
    p = W.Part("Body")
    # the steel case with stiffening ribs and carrying-frame corners
    W.box(p, (-0.23, 0.03, -0.15), (0.23, 0.32, 0.15), "mats_machine_grey", 0.012)
    W.box(p, (-0.24, 0.0, -0.16), (0.24, 0.03, 0.16), "lib_iron", 0.006)
    for x in (-0.12, 0.0, 0.12):
        W.box(p, (x - 0.01, 0.04, 0.15), (x + 0.01, 0.31, 0.158), "mats_machine_grey", 0.003)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            W.box(p, (sx * 0.235 - 0.012, 0.0, sz * 0.155 - 0.012), (sx * 0.235 + 0.012, 0.33, sz * 0.155 + 0.012), "lib_iron", 0.004)
        W.box(p, (sx * 0.25 - 0.02, 0.12, -0.08), (sx * 0.25 + 0.02, 0.22, 0.08), "mats_black_paint", 0.006)   # handles' bosses
        W.tube(p, [(sx * 0.27, 0.13, -0.06), (sx * 0.3, 0.17, -0.03), (sx * 0.3, 0.17, 0.03), (sx * 0.27, 0.13, 0.06)], 0.008, "lib_iron", 5)
    # the open lid behind it with the frequency card on its inside
    W.obox(p, (0, 0.46, 0.2), (0.46, 0.3, 0.025), "mats_machine_grey", (-15, 0, 0), 0.008)
    W.obox(p, (0, 0.46, 0.184), (0.36, 0.22, 0.004), "mats_paper", (-15, 0, 0), 0.0)
    for k in range(5):
        W.obox(p, (0, 0.53 - k * 0.035, 0.181), (0.3 - (k % 2) * 0.08, 0.006, 0.002), "mats_black_paint", (-15, 0, 0), 0.0)
    # the front panel: dials, a meter, switches, the dial window's frame (the lit window is the script's)
    W.box(p, (-0.21, 0.03, -0.158), (0.21, 0.3, -0.15), "mats_black_paint", 0.003)
    W.box(p, (-0.17, 0.165, -0.165), (-0.03, 0.235, -0.158), "mats_chrome", 0.003)
    for (c, r) in (((0.12, 0.2, -0.16), 0.045), ((0.12, 0.08, -0.16), 0.035), ((-0.02, 0.07, -0.16), 0.03)):
        W.cyl(p, (c[0], c[1], c[2] - 0.012), r, 0.024, "mats_bakelite", axis="z", segs=16, bevel=0.004)
        W.cyl(p, (c[0], c[1], c[2] - 0.026), r * 0.6, 0.006, "mats_bakelite", axis="z", segs=12)
        W.obox(p, (c[0], c[1] + r * 0.45, c[2] - 0.03), (0.006, r * 0.6, 0.004), "mats_enamel_white", None, 0.0)
    W.cyl(p, (-0.14, 0.09, -0.162), 0.04, 0.01, "mats_gauge_face", axis="z", segs=16)
    W.torus(p, (-0.14, 0.09, -0.166), 0.04, 0.006, "mats_chrome", axis="z", segs=16, rsegs=4)
    for k in range(2):
        W.cyl(p, (-0.16 + k * 0.06, 0.27, -0.162), 0.012, 0.015, "mats_steel", axis="z", segs=8)
        W.obox(p, (-0.16 + k * 0.06, 0.277, -0.175), (0.006, 0.02, 0.006), "mats_steel", (25, 0, 0), 0.0)
    # the headset on top, the Morse key beside, the whip antenna in its base
    W.torus(p, (-0.08, 0.34, 0.0), 0.09, 0.01, "lib_leather", rot=(90, 30, 0), segs=16, rsegs=4)
    for e in (-1.0, 1.0):
        W.cyl(p, (-0.08 + e * 0.07, 0.345, e * 0.04), 0.035, 0.03, "mats_bakelite", segs=14, bevel=0.006)
    W.tube(p, [(-0.15, 0.33, 0.04), (-0.2, 0.3, 0.1), (-0.25, 0.1, 0.1), (-0.3, 0.02, 0.0)], 0.005, "mats_rubber", 4)
    W.box(p, (0.3, 0.0, -0.05), (0.42, 0.02, 0.05), "mats_bakelite", 0.004)
    W.obox(p, (0.36, 0.035, 0.0), (0.09, 0.008, 0.015), "mats_brass", (0, 0, -6), 0.002)
    W.cyl(p, (0.32, 0.05, 0.0), 0.012, 0.012, "mats_bakelite", segs=8)
    W.cyl(p, (0.18, 0.34, 0.1), 0.02, 0.04, "mats_brass", segs=10)
    W.tube(p, [(0.18, 0.36, 0.1), (0.18, 0.7, 0.11), (0.18, 1.1, 0.14)], 0.006, "mats_steel", 5)
    # the canvas carrying strap draped over the case
    W.tube(p, [(-0.24, 0.2, -0.1), (-0.27, 0.33, -0.05), (-0.1, 0.36, 0.12), (0.1, 0.35, 0.13), (0.26, 0.3, 0.05), (0.25, 0.15, -0.08)], 0.012, "lib_canvas", 5)
    p.build()
    return W.export("field_radio", "The requisitioned field set", "the Ledger-era radio behind the bar: case, dials, headset, key, whip", "story_machines.py")


# ================================================================== the power lever

def lever():
    W.reset()
    p = W.Part("Body")
    W.box(p, (-0.64, 0, -0.22), (0.64, 0.1, 0.24), "mats_black_paint", 0.01)
    W.box(p, (-0.6, 0.1, -0.2), (0.6, 1.6, 0.2), "mats_machine_grey", 0.015)
    W.box(p, (-0.62, 1.56, -0.22), (0.62, 1.64, 0.22), "lib_iron", 0.01)
    # the front door: raised rims, hinges, louvres, a warning plate
    W.box(p, (-0.54, 0.18, -0.215), (0.54, 1.5, -0.2), "mats_machine_green", 0.006)
    for ry in (0.2, 1.48):
        W.box(p, (-0.56, ry - 0.02, -0.23), (0.56, ry + 0.02, -0.2), "lib_iron", 0.004)
    for rx in (-0.56, 0.56):
        W.box(p, (rx - 0.02, 0.18, -0.23), (rx + 0.02, 1.5, -0.2), "lib_iron", 0.004)
    W.rivets(p, (-0.52, 1.48, -0.232), (0.52, 1.48, -0.232), 10, 0.01)
    W.rivets(p, (-0.52, 0.2, -0.232), (0.52, 0.2, -0.232), 10, 0.01)
    for hy in (0.4, 1.25):
        W.cyl(p, (-0.58, hy, -0.23), 0.025, 0.14, "mats_steel", segs=10)
    for lv in range(6):
        W.obox(p, (-0.26, 0.31 + lv * 0.05, -0.222), (0.32, 0.02, 0.012), "mats_black_paint", (-25, 0, 0), 0.0)
    W.box(p, (-0.46, 1.32, -0.225), (-0.18, 1.42, -0.215), "mats_yellow_paint", 0.002)
    W.prism(p, [(-0.03, 0.0), (0.0, 0.05), (0.01, 0.02), (0.035, 0.03), (0.0, -0.04), (0.005, -0.005)], -0.004, 0.0, "mats_black_paint",
            c=(-0.32, 1.37, -0.226))
    # copper bus bars and porcelain fuses behind a window
    W.box(p, (0.0, 0.28, -0.226), (0.46, 0.62, -0.216), "mats_window_dark", 0.0)
    for fx in range(3):
        x = 0.08 + fx * 0.15
        W.strut(p, (x, 0.3, -0.232), (x, 0.6, -0.232), 0.03, "mats_copper", False)
        W.lathe(p, [(0.0, -0.06), (0.03, -0.06), (0.035, -0.04), (0.035, 0.04), (0.03, 0.06), (0.0, 0.06)], "mats_enamel_white", c=(x, 0.45, -0.24), segs=12)
    W.box(p, (-0.02, 0.26, -0.232), (0.48, 0.64, -0.224), "mats_chrome", 0.003)
    # two gauges, the lamp housings (the lamps are the script's)
    for gx in (-0.32, 0.32):
        W.cyl(p, (gx, 1.18, -0.24), 0.14, 0.05, "mats_brass", axis="z", segs=20, bevel=0.01)
        W.cyl(p, (gx, 1.18, -0.262), 0.12, 0.01, "mats_gauge_face", axis="z", segs=20)
        W.obox(p, (gx - 0.03, 1.2, -0.27), (0.01, 0.1, 0.004), "mats_black_paint", (0, 0, 50), 0.0)
    for lx in (-0.14, 0.14):
        W.cyl(p, (lx, 0.88, -0.23), 0.07, 0.05, "lib_iron", axis="z", segs=14, bevel=0.006)
    # the name board on top
    for sx in (-0.5, 0.5):
        W.strut(p, (sx, 1.64, 0.0), (sx, 1.78, -0.12), 0.04, "lib_iron", False)
    W.box(p, (-0.66, 1.66, -0.22), (0.66, 1.86, -0.17), "mats_nameplate", 0.006)
    W.box(p, (-0.69, 1.63, -0.2), (0.69, 1.89, -0.16), "mats_brass", 0.008)
    # conduits up into the dark, insulators on the crown
    for cx in (-0.4, -0.1, 0.2):
        W.cyl(p, (cx, 2.4, 0.12), 0.05, 1.6, "mats_rubber", segs=10)
        W.lathe(p, [(0.0, -0.06), (0.07, -0.06), (0.05, -0.02), (0.07, 0.0), (0.05, 0.03), (0.07, 0.05), (0.0, 0.06)], "mats_enamel_white", c=(cx, 1.7, 0.12), segs=12)
    # the lever quadrant on the right flank
    q = (0.66, 1.0, -0.02)
    W.box(p, (0.6, 0.6, -0.12), (0.66, 1.4, 0.08), "lib_iron", 0.006)
    pts = []
    for k in range(9):
        a = -0.5 + 1.65 * k / 8.0
        pts.append((q[0] + 0.03, q[1] + 0.44 * math.cos(a), q[2] + 0.44 * math.sin(a)))
    W.tube(p, pts, 0.015, "lib_iron", 5)
    for k in (0, 8):
        W.dot(p, pts[k], 0.022, "mats_red_paint" if k == 0 else "mats_machine_green", 6)
    W.cyl(p, (q[0] + 0.03, q[1], q[2]), 0.08, 0.08, "lib_iron", axis="x", segs=16, bevel=0.01)
    p.build()
    # the throw lever (pivot at the quadrant's hub; at rest leaning up and back, as InteractableArt.power_lever)
    lp = (0.69, 1.0, -0.02)
    lv = W.Part("Lever", lp)
    a = -0.5
    up = (0.0, math.cos(a), math.sin(a))
    W.cyl(lv, (lp[0] + 0.05, lp[1], lp[2]), 0.05, 0.12, "mats_steel", axis="x", segs=14, bevel=0.008)
    W.strut(lv, (lp[0] + 0.08, lp[1], lp[2]), (lp[0] + 0.08, lp[1] + up[1] * 0.55, lp[2] + up[2] * 0.55), 0.045, "mats_steel", False)
    W.cyl(lv, (lp[0] + 0.08, lp[1] + up[1] * 0.66, lp[2] + up[2] * 0.66), 0.04, 0.2, "mats_red_paint", axis="x", segs=14, bevel=0.01)
    W.cyl(lv, (lp[0] + 0.08, lp[1] + up[1] * 0.66, lp[2] + up[2] * 0.66), 0.043, 0.02, "mats_steel", axis="x", segs=14)
    lv.build()
    return W.export("power_lever", "The power lever", "the main breaker cabinet and its throw lever (Map 0's cellar lever, Map 1's Hauptschalter)", "story_machines.py")


# ================================================================== the exfil beacon

def beacon():
    W.reset()
    p = W.Part("Body")
    # a squared timber post set in a stone footing, iron-strapped, with a bracket arm and a railway signal lantern
    W.box(p, (-0.2, 0, -0.2), (0.2, 0.12, 0.2), "lib_fieldstone", 0.02)
    W.box(p, (-0.08, 0.1, -0.08), (0.08, 2.6, 0.08), "lib_planks", 0.012, uvrot=True)
    W.cyl(p, (0, 2.62, 0), 0.1, 0.04, "lib_iron", r2=0.02, segs=4)
    for sy in (0.6, 1.4, 2.2):
        W.box(p, (-0.088, sy - 0.03, -0.088), (0.088, sy + 0.03, 0.088), "lib_iron", 0.004)
    W.box(p, (-0.05, 2.41, -0.04), (0.82, 2.49, 0.04), "lib_planks", 0.008)
    W.tube(p, [(0.08, 2.1, 0.0), (0.3, 2.3, 0.0), (0.5, 2.43, 0.0)], 0.014, "lib_iron", 5)
    # the lantern: hood, chimney, cage round the glass (the glass and light are the script's), a hook
    lc = (0.7, 2.25, 0.0)
    W.strut(p, (0.7, 2.41, 0.0), (0.7, 2.36, 0.0), 0.02, "lib_iron", True, 6)
    W.lathe(p, [(0.0, 0.0), (0.2, 0.0), (0.16, 0.05), (0.08, 0.1), (0.05, 0.14)], "mats_black_paint", c=(lc[0], lc[1] + 0.09, lc[2]), segs=16, cap_lo=False)
    W.cyl(p, (lc[0], lc[1] + 0.27, lc[2]), 0.035, 0.08, "lib_iron", segs=10)
    W.cyl(p, (lc[0], lc[1] - 0.15, lc[2]), 0.13, 0.05, "mats_black_paint", segs=16, bevel=0.01)
    for k in range(6):
        a = math.tau * k / 6.0
        W.strut(p, (lc[0] + math.cos(a) * 0.14, lc[1] - 0.13, lc[2] + math.sin(a) * 0.14),
                (lc[0] + math.cos(a) * 0.14, lc[1] + 0.09, lc[2] + math.sin(a) * 0.14), 0.008, "lib_iron", True, 4)
    # the painted board (the labels are the script's), on two iron brackets
    W.box(p, (-0.65, 1.54, -0.125), (0.65, 1.96, -0.075), "lib_planks", 0.01)
    W.box(p, (-0.62, 1.57, -0.128), (0.62, 1.93, -0.124), W.paint("d1c7a8"), 0.0)
    for sx in (-0.4, 0.4):
        W.box(p, (sx - 0.02, 1.6, -0.08), (sx + 0.02, 1.9, -0.06), "lib_iron", 0.003)
    p.build()
    return W.export("exfil_beacon", "The exfil beacon", "a signal lantern on a post with its painted board", "story_machines.py")


ALL = {"crucible": crucible, "bench": bench, "radio": radio, "lever": lever, "beacon": beacon}

if __name__ == "__main__":
    want = W.args() or list(ALL.keys())
    for k in want:
        ALL[k]()
