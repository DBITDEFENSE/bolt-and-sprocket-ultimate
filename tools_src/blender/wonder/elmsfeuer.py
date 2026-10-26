"""Sankt-Elmsfeuer (UPDATE_05 section 2, T-090): Totenhafen's wonder weapon (docs/gravelight/WEAPONS.md section 7.1):
the U-boat pens' arc lamp, rebuilt as a carbine by U-1047's electrician.

    blender -b --factory-startup -P tools_src/blender/wonder/elmsfeuer.py -- --out assets/ours/wonder/elmsfeuer [--turntable png] [--fast]

A navy-grey magneto breech (ship's paint, chipped to steel) with two stacked horseshoe magnets on each side and a hand
crank on the right (the Crank: the "crank" reload winds it), a ship's ammeter on the left (the Dial: its needle reads
the charge), a brass engine-room tag "U-1047  E-RAUM", rubber cables taped with cloth running from the magneto to the
coil, a copper induction coil glowing violet inside a glass sleeve held by brass collars and tie rods over the brass
bore, a discharge gap of three copper rings and a two-pronged electrode at the muzzle with the violet Arc jumping
between them, porcelain insulators for sights (a notch plate between two at the breech, one tipped with a copper blade
on the front collar), a wooden forend, a pistol grip and a short buttstock with a brass butt plate.
Kugelblitz (the Crucible version) shows the Orb (ball lightning held in front of the electrodes), a bluer arc and a
brighter coil (WonderLook materials); same mesh.

Markers (game frame, metres): grip hand (0, -0.045, 0.058) leaning 16 deg; LeftHand (0, -0.004, -0.28) along the
forend (axis z); SightPoint (0, 0.1068, -0.002); FrontSight (0, 0.1068, -0.4); Muzzle (0, 0.05, -0.54); Crank pivot
(0.035, 0.05, -0.12) about x with its knob at +(0.025, 0.045, 0); Dial pivot (-0.0335, 0.06, -0.08) about x; Arc pivot
(0, 0.05, -0.48); Orb (0, 0.05, -0.556).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wonder_lib as W  # noqa: E402
from mathutils import Vector  # noqa: E402

A = W.args()
m = W.Model("elmsfeuer", tex=A["tex"] or 2048)
BY = 0.05           # bore axis
SIGHT_Y = 0.1068
CR = Vector((0.035, 0.05, -0.12))
DIAL = Vector((-0.0335, 0.06, -0.08))

# ------------------------------------------------------------------ magneto breech
m.box("Body", "paint_navy", (0.056, 0.076, 0.205), (0, 0.05, -0.1), bevel=0.006, segs=3, name="breech")
m.box("Body", "brass", (0.06, 0.008, 0.21), (0, 0.091, -0.1), bevel=0.0015, name="top_rail")
m.box("Body", "paint_navy", (0.046, 0.012, 0.02), (0, 0.005, -0.02), bevel=0.002, name="breech_foot")
# the armature end bell on the breech's rear face (what the eye sees at the hip), screwed down, with a brass
# commutator cap and the brush holders
m.lathe("Body", "brass", [(0.0, 0.0085), (0.012, 0.0085), (0.0205, 0.006), (0.0235, 0.002), (0.0235, -0.0026), (0.0, -0.0026)], center=(0, 0.05, 0.0),
        segs=36, name="end_bell")
m.lathe("Body", "copper", [(0.0, 0.015), (0.0062, 0.015), (0.0068, 0.012), (0.0068, 0.008), (0.0, 0.008)], center=(0, 0.05, 0.0), segs=20, name="commutator")
m.bolt_heads("Body", "steel", [((math.cos(a) * 0.0185, 0.05 + math.sin(a) * 0.0185, 0.0062), (0, 0, 1)) for a in [math.radians(45 + 90 * k) for k in range(4)]],
             r=0.0024, h=0.0016, name="end_screws")
for sx in (-1.0, 1.0):
    m.box("Body", "porcelain", (0.006, 0.008, 0.007), (sx * 0.011, 0.05, 0.012), bevel=0.001, name="brush_holder")
for sx in (-1.0, 1.0):
    for k, (yt, yb) in enumerate(((0.078, 0.028), (0.072, 0.034))):
        x = sx * (0.031 + k * 0.006)
        path = [(x, yt, -0.02), (x, yt, -0.12), (x, yt - 0.006, -0.142), (x, (yt + yb) * 0.5, -0.152), (x, yb + 0.006, -0.142),
                (x, yb, -0.12), (x, yb, -0.02)]
        m.sweep("Body", "paint_oxide", path, 0.0, radii=[(0.0048, 0.0042)] * 7, segs=8, smooth_per=4, ref=(1, 0, 0), name="magnet")
    for z in (-0.012, -0.188):
        for y in (0.022, 0.078):
            m.bolt_heads("Body", "steel", [((sx * 0.028, y, z), (sx, 0, 0))], r=0.0035, h=0.0022, name="breech_bolt")
# the engine-room tag (left, behind the dial)
TAG = Vector((-0.029, 0.04, -0.035))
m.box("Body", "brass", (0.0016, 0.026, 0.052), tuple(TAG), bevel=0.0005, name="tag")
m.text("Body", "ink_black", "U-1047", 0.0085, lambda tx, ty, tz: (TAG.x - 0.0008 - tz, TAG.y + 0.005 + ty, TAG.z + tx), depth=0.0003, name="tag_t1")
m.text("Body", "ink_black", "E-RAUM", 0.0068, lambda tx, ty, tz: (TAG.x - 0.0008 - tz, TAG.y - 0.0065 + ty, TAG.z + tx), depth=0.0003, name="tag_t2")
m.rivets("Body", "brass", [((TAG.x - 0.0008, TAG.y + dy, TAG.z + dz), (-1, 0, 0)) for dy in (-0.0105, 0.0105) for dz in (-0.022, 0.022)], r=0.0015, name="tag_rivets")

# ------------------------------------------------------------------ the ammeter (left) and its needle (the Dial)
m.lathe("Body", "brass", [(0.0, 0.0015), (0.0175, 0.0015), (0.0182, -0.001), (0.017, -0.0045), (0.0148, -0.0045), (0.0148, -0.0025), (0.0, -0.0025)],
        center=tuple(DIAL + Vector((0.004, 0, 0))), axis="x", segs=36, name="dial_bezel")
m.cyl("Body", "enamel_cream", 0.0149, 0.0149, 0.0006, tuple(DIAL + Vector((0.0016, 0, 0))), axis="x", segs=36, bevel=0.0, name="dial_face")
ticks = []
for k in range(11):
    a = math.radians(-100 + 200 * k / 10)
    r0 = 0.0095 if k % 5 == 0 else 0.0112
    ticks.append([(math.sin(a) * r0, math.cos(a) * r0), (math.sin(a) * 0.0132, math.cos(a) * 0.0132)])
ticks.append([(math.sin(math.radians(a)) * 0.0135, math.cos(math.radians(a)) * 0.0135) for a in range(-100, 101, 10)])
m.strokes("Body", "ink_black", ticks, 0.0006, lambda s, t, h: (DIAL.x + 0.0012 - h, DIAL.y + t, DIAL.z - s), depth=0.0002, name="dial_ticks")
m.text("Body", "ink_black", "AMP", 0.0038, lambda tx, ty, tz: (DIAL.x + 0.0012 - tz, DIAL.y - 0.0055 + ty, DIAL.z + tx), depth=0.0002, name="dial_amp")
m.strokes("Body", "paint_oxide", [[(math.sin(math.radians(a)) * 0.0128, math.cos(math.radians(a)) * 0.0128) for a in range(60, 101, 5)]], 0.0016,
          lambda s, t, h: (DIAL.x + 0.0011 - h, DIAL.y + t, DIAL.z - s), depth=0.00015, name="dial_red")
m.box("Dial", "ink_black", (0.0005, 0.012, 0.0011), tuple(DIAL + Vector((-0.0004, 0.005, 0))), bevel=0.0, name="needle")
m.cyl("Dial", "brass", 0.0017, 0.0017, 0.0014, tuple(DIAL + Vector((-0.0005, 0, 0))), axis="x", segs=12, bevel=0.0, name="needle_hub")
m.cyl("Body", "glass", 0.0149, 0.0149, 0.0006, tuple(DIAL + Vector((-0.0022, 0, 0))), axis="x", segs=36, bevel=0.0, name="dial_glass")

# ------------------------------------------------------------------ the magneto crank (right)
m.cyl("Body", "brass", 0.009, 0.009, 0.006, tuple(CR + Vector((-0.004, 0, 0))), axis="x", segs=20, name="crank_bush")
m.cyl("Crank", "steel", 0.0042, 0.0042, 0.016, tuple(CR + Vector((0.004, 0, 0))), axis="x", segs=14, name="crank_axle")
m.sweep("Crank", "steel", [CR + Vector((0.011, 0.0, 0.0)), CR + Vector((0.013, 0.024, 0.003)), CR + Vector((0.013, 0.045, 0.0))], 0.0,
        radii=[(0.0042, 0.0034), (0.0036, 0.003), (0.0034, 0.003)], segs=8, smooth_per=4, ref=(1, 0, 0), name="crank_arm")
m.cyl("Crank", "steel", 0.0042, 0.0042, 0.006, tuple(CR + Vector((0.012, 0.0, 0.0))), axis="x", segs=14, name="crank_boss")
m.lathe("Crank", "wood_handle", [(0.0, -0.011), (0.0055, -0.011), (0.0068, -0.006), (0.006, 0.0), (0.0068, 0.006), (0.0058, 0.011), (0.0, 0.0115)],
        center=tuple(CR + Vector((0.026, 0.045, 0.0))), axis="x", segs=18, name="crank_knob")

# ------------------------------------------------------------------ bore, coil sleeve, collars, tie rods
m.lathe("Body", "brass", [(0.0, -0.5), (0.0105, -0.5), (0.0105, -0.2), (0.0, -0.2)], center=(0, BY, 0), segs=24, name="bore")
m.cyl("Body", "coil_glow", 0.0152, 0.0152, 0.17, (0, BY, -0.3), segs=20, name="coil_core")
m.helix("Body", "copper", 0.0178, 0.0017, -0.216, -0.384, 26, center=(0, BY, 0), per_turn=12, segs=5, name="coil")
m.tube("Body", "glass", 0.0262, 0.0285, 0.186, (0, BY, -0.3), segs=36, name="sleeve")
for z in (-0.204, -0.396):
    m.lathe("Body", "brass", [(0.0098, z - 0.007), (0.031, z - 0.007), (0.0335, z - 0.005), (0.0335, z + 0.005), (0.031, z + 0.007), (0.0098, z + 0.007)],
            center=(0, BY, 0), segs=36, cap0=False, cap1=False, name="collar")
    m.rivets("Body", "brass", [((math.cos(a) * 0.0336, BY + math.sin(a) * 0.0336, z), (math.cos(a), math.sin(a), 0)) for a in
                               [math.tau * k / 8 + 0.39 for k in range(8)]], r=0.0016, name="collar_rivets")
for ang in (45.0, 135.0, 270.0):
    a = math.radians(ang)
    m.cyl("Body", "brass", 0.0021, 0.0021, 0.19, (math.cos(a) * 0.031, BY + math.sin(a) * 0.031, -0.3), segs=10, name="tie_rod")

# ------------------------------------------------------------------ the discharge gap, electrodes, the Arc
for z in (-0.418, -0.442, -0.466):
    m.torus("Body", "copper", 0.0185, 0.0028, (0, BY, z), axis="z", segs=32, rsegs=8, name="gap_ring")
    for ang in (90.0, 210.0, 330.0):
        a = math.radians(ang)
        m.sweep("Body", "copper", [(math.cos(a) * 0.0105, BY + math.sin(a) * 0.0105, z), (math.cos(a) * 0.0165, BY + math.sin(a) * 0.0165, z)], 0.0014, segs=6, name="ring_spoke")
m.lathe("Body", "porcelain", [(0.0108, -0.402), (0.016, -0.402), (0.0175, -0.406), (0.0158, -0.41), (0.0172, -0.414), (0.0108, -0.414)], center=(0, BY, 0),
        segs=24, cap0=False, cap1=False, name="gap_insulator")
for sx in (-1.0, 1.0):
    p0 = Vector((sx * 0.0085, BY, -0.488))
    m.sweep("Body", "copper", [Vector((sx * 0.006, BY, -0.478)), p0, Vector((sx * 0.0135, BY + 0.002, -0.515)), Vector((sx * 0.0145, BY + 0.003, -0.532))],
            0.0026, segs=10, smooth_per=4, name="prong")
    m.lathe("Body", "copper", [(0.0, -0.0045), (0.0032, -0.0038), (0.0045, 0.0), (0.0032, 0.0038), (0.0, 0.0045)], center=(sx * 0.0145, BY + 0.003, -0.535),
            axis="z", segs=14, name="prong_tip")
m.lathe("Body", "brass", [(0.0, -0.476), (0.0128, -0.476), (0.0128, -0.5), (0.0, -0.5)], center=(0, BY, 0), segs=24, name="electrode_base")
rng = m.rng
for branch in range(3):
    pts = []
    side = 1.0 if branch % 2 == 0 else -1.0
    for k in range(14):
        f = k / 13.0
        z = -0.416 - f * 0.118
        r = 0.0045 + 0.012 * math.sin(f * math.pi) + (rng.random() - 0.5) * 0.004
        a = math.radians(90 + branch * 120) + (rng.random() - 0.5) * 1.2 + f * side * 2.2
        if f > 0.8:
            r = 0.0145 + (rng.random() - 0.5) * 0.003
            a = math.radians(0 if side > 0 else 180) + (rng.random() - 0.5) * 0.4
        pts.append((math.cos(a) * r, BY + math.sin(a) * r, z))
    m.sweep("Arc", "arc", pts, 0.0011, segs=5, name="arc")

# ------------------------------------------------------------------ sights: insulators
for sx in (-1.0, 1.0):
    m.lathe("Body", "porcelain", [(0.0, 0.0), (0.0062, 0.0), (0.0068, 0.003), (0.0052, 0.006), (0.0064, 0.009), (0.005, 0.012), (0.0058, 0.0145),
                                  (0.0036, 0.0175), (0.0, 0.0178)], center=(sx * 0.0135, 0.0948, -0.004), axis="y", segs=16, name="rear_insulator")
    m.cyl("Body", "copper", 0.0022, 0.0022, 0.004, (sx * 0.0135, 0.1146, -0.004), axis="y", segs=10, name="rear_cap")
for sx in (-1.0, 1.0):
    m.box("Body", "brass", (0.006, 0.0105, 0.003), (sx * 0.0047, 0.1024, -0.0005), bevel=0.0003, name="notch_ear")
m.box("Body", "brass", (0.022, 0.006, 0.003), (0, 0.0985, -0.0005), bevel=0.0003, name="notch_plate")
m.lathe("Body", "porcelain", [(0.0, 0.0), (0.0058, 0.0), (0.0062, 0.003), (0.0048, 0.0055), (0.0058, 0.0085), (0.0042, 0.0115), (0.0, 0.0118)],
        center=(0, BY + 0.0335, -0.4), axis="y", segs=16, name="front_insulator")
m.box("Body", "copper", (0.0026, 0.012, 0.004), (0, SIGHT_Y - 0.006, -0.4), bevel=0.0002, name="front_blade")

# ------------------------------------------------------------------ cables from the magneto to the rear collar (cloth-taped)
for sx, yy in ((1.0, 0.075), (1.0, 0.03)):
    path = [(0.028, yy, -0.19), (0.04, yy + 0.004, -0.205), (0.036, yy * 0.6 + 0.03, -0.22), (0.03, BY + (yy - 0.05) * 0.4, -0.21)]
    m.sweep("Body", "rubber", path, 0.0028, segs=8, smooth_per=6, name="cable")
    for f in (0.15, 0.85):
        c = Vector(path[0]).lerp(Vector(path[-1]), f)
        loop = [c + Vector((0.0, math.cos(a) * 0.0042, math.sin(a) * 0.0042)) for a in [math.tau * j / 12 for j in range(12)]]
        m.sweep("Body", "cloth_tape", loop, 0.0, radii=[(0.003, 0.0009)] * 12, segs=6, closed=True, ref=(1, 0, 0), name="tape")

# ------------------------------------------------------------------ trigger, guard, grip, stock, forend
m.prism("Body", "brass", [(-0.004, 0.012), (-0.01, 0.0), (-0.013, -0.012), (-0.011, -0.02), (-0.008, -0.017), (-0.006, -0.007), (-0.0005, 0.008)],
        -0.003, 0.003, bevel=0.0006, name="trigger")
m.sweep("Body", "brass", [(0, 0.008, -0.045), (0, -0.01, -0.044), (0, -0.026, -0.03), (0, -0.03, 0.0), (0, -0.022, 0.025), (0, -0.006, 0.035)],
        0.0022, segs=10, smooth_per=6, name="guard")
# the stock: a short wooden wrist behind the grip, then a skeleton of ship's conduit (two tubes, clamped) to a
# rubber-padded butt (kept low and short so it stays under the sight line in the hand)
m.prism("Body", "wood", [(0.0, 0.072), (0.06, 0.068), (0.098, 0.058), (0.104, 0.03), (0.1, -0.008), (0.088, -0.014), (0.07, 0.008), (0.0, 0.012)],
        -0.0178, 0.0178, bevel=0.0065, segs=4, name="wrist")
for top, pts in ((True, [(0, 0.05, 0.096), (0, 0.044, 0.16), (0, 0.03, 0.255)]), (False, [(0, 0.004, 0.098), (0, -0.02, 0.17), (0, -0.05, 0.255)])):
    m.sweep("Body", "steel", pts, 0.0062, segs=12, smooth_per=4, name="conduit")
    m.lathe("Body", "brass", [(0.0062, -0.006), (0.0085, -0.006), (0.0085, 0.006), (0.0062, 0.006)], center=pts[0], axis="z", segs=16, cap0=False, cap1=False, name="conduit_ferrule")
m.box("Body", "steel", (0.02, 0.016, 0.008), (0, 0.006, 0.17), bevel=0.0012, name="conduit_clamp")
m.sweep("Body", "steel", [(0, 0.04, 0.17), (0, -0.018, 0.17)], 0.0035, segs=8, name="conduit_strut")
m.box("Body", "paint_navy", (0.034, 0.108, 0.012), (0, -0.01, 0.262), bevel=0.004, segs=3, name="butt")
m.box("Body", "rubber", (0.036, 0.112, 0.012), (0, -0.01, 0.274), bevel=0.0045, segs=3, name="butt_pad")
m.bolt_heads("Body", "steel", [((0, y, 0.256), (0, 0, -1)) for y in (0.03, -0.05)], r=0.004, h=0.0025, name="butt_bolts")
LEAN = math.radians(16.0)
T = Vector((0.0, 0.006, 0.042))
D = Vector((0.0, -math.cos(LEAN), math.sin(LEAN)))
FWD = Vector((0.0, -math.sin(LEAN), -math.cos(LEAN)))
prof = [(0.0, 0.0205, 0.0175), (0.025, 0.0215, 0.0178), (0.05, 0.022, 0.018), (0.075, 0.0215, 0.0178), (0.1, 0.02, 0.0168), (0.108, 0.018, 0.016)]
m.sweep("Body", "wood", [T + D * p[0] for p in prof], 0.0, radii=[(p[1], p[2]) for p in prof], segs=20, ref=FWD, name="grip")
m.lathe("Body", "steel", [(0.0, -0.002), (0.0165, -0.002), (0.017, 0.002), (0.012, 0.005), (0.0, 0.0058)], center=tuple(T + D * 0.108), axis=tuple(D), segs=20, name="grip_cap")
m.prism("Body", "wood", [(-0.198, 0.022), (-0.362, 0.022), (-0.37, 0.012), (-0.366, -0.008), (-0.35, -0.016), (-0.21, -0.016), (-0.198, -0.005)],
        -0.0185, 0.0185, bevel=0.0075, segs=4, name="forend")
m.box("Body", "steel", (0.04, 0.008, 0.012), (0, 0.016, -0.19), bevel=0.001, name="forend_band")

# ------------------------------------------------------------------ Kugelblitz: the Orb (Crucible only)
m.lathe("Orb", "orb", [(0.0, -0.0145), (0.0075, -0.0125), (0.0125, -0.0072), (0.0145, 0.0), (0.0125, 0.0072), (0.0075, 0.0125), (0.0, 0.0145)],
        center=(0, BY, -0.556), segs=20, name="orb")
for k in range(4):
    a = math.tau * k / 4 + 0.4
    pts = [(math.cos(a) * 0.004, BY + math.sin(a) * 0.004, -0.556), (math.cos(a + 0.6) * 0.012, BY + math.sin(a + 0.6) * 0.012, -0.548),
           (math.cos(a + 1.0) * 0.02, BY + math.sin(a + 1.0) * 0.02, -0.54)]
    m.sweep("Orb", "arc", pts, 0.0009, segs=5, smooth_per=3, name="orb_tendril")

m.crucible_parts = ["Orb"]
m.finish(A["out"] or os.path.join(W.HERE, "..", "..", "..", "assets", "ours", "wonder", "elmsfeuer"), turntable=A["turntable"], fast=A["fast"],
         extra_report={"markers": {"Muzzle": [0, BY, -0.54], "SightPoint": [0, SIGHT_Y, -0.002], "FrontSight": [0, SIGHT_Y, -0.4],
                                   "LeftHand": [0, -0.004, -0.28], "grip_r": [0, -0.045, 0.058], "Crank": list(CR), "Dial": list(DIAL),
                                   "Arc": [0, BY, -0.48], "Orb": [0, BY, -0.556]}})
