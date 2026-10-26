"""Siren Gramophone (UPDATE_05 section 2, T-090): the crate-only tactical (docs/gravelight/WEAPONS.md section 6). "Reinholt's
orderlies wound it, set it in the yard, and stepped back. The subjects always came."

    blender -b --factory-startup -P tools_src/blender/wonder/gramophone.py -- --out assets/ours/wonder/gramophone [--turntable png] [--fast]

A portable wind-up gramophone of the 1930s: a black leatherette case with brass corner caps, a front latch and a
leather carry strap, the lid standing open on its hinges (a paper notice inside: "BITTE NICHT UEBERDREHEN", don't
overwind), a dark wood deck, the turntable with its felt, the Record (black shellac, a printed label: "KOMM MIT,
KLEINER SOLDAT" - "Come Along, Little Soldier"), the Tonearm (brass, with a nickel soundbox and needle), a brass
siren horn rising off the back corner, a speed lever and brake, the Crank on the right side.

Frame: the thrown object's own frame (gravelight/weapons/gramophone.gd): origin at the centre of its 0.30 x 0.18 x
0.30 m collision box, +Y up. Moving parts: Record (spins about y at its centre (0, 0, 0.012)), Crank (turns about x at
(0.145, -0.03, 0.05)), Tonearm (swings about y at (0.105, 0.04, 0.105) and drops onto the record when the needle
goes down), Lid (static here; a node so a future open/close can move it).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wonder_lib as W  # noqa: E402
from mathutils import Vector  # noqa: E402

A = W.args()
m = W.Model("gramophone", tex=A["tex"] or 1024)
TOP = 0.045                         # deck top
RC = Vector((0.0, 0.0, 0.012))      # record centre (x, z); y set per layer
W._FAMILY_PARAMS["shellac"] = dict(W._FAMILY_PARAMS.get("shellac", {}), center=(0.0, TOP + 0.017, 0.012))

# ------------------------------------------------------------------ the case
m.box("Body", "leather_black", (0.28, 0.12, 0.28), (0, TOP - 0.06, 0), bevel=0.006, segs=3, name="case")
m.box("Body", "wood_dark", (0.262, 0.006, 0.262), (0, TOP + 0.001, 0), bevel=0.0015, name="deck")
for sx in (-1, 1):
    for sy in (-1, 1):
        for sz in (-1, 1):
            c = Vector((sx * 0.137, TOP - 0.06 + sy * 0.057, sz * 0.137))
            m.box("Body", "brass", (0.018, 0.018, 0.018), tuple(c), bevel=0.004, segs=3, name="corner")
m.box("Body", "brass", (0.03, 0.022, 0.005), (0, TOP - 0.008, -0.1415), bevel=0.0012, name="latch")
m.cyl("Body", "brass", 0.004, 0.004, 0.006, (0, TOP - 0.008, -0.145), axis="z", segs=12, name="latch_key")
for sz in (-1.0, 1.0):
    m.box("Body", "brass", (0.006, 0.016, 0.016), (-0.142, TOP - 0.04, sz * 0.05), bevel=0.0015, name="strap_loop")
m.sweep("Body", "leather", [(-0.146, TOP - 0.04, -0.05), (-0.162, TOP - 0.03, -0.035), (-0.165, TOP - 0.026, 0.0), (-0.162, TOP - 0.03, 0.035),
                            (-0.146, TOP - 0.04, 0.05)], 0.0, radii=[(0.012, 0.003)] * 5, segs=8, smooth_per=5, ref=(0, 1, 0), name="strap")
for sx in (-1.0, 1.0):
    for sz in (-1.0, 1.0):
        m.cyl("Body", "rubber", 0.009, 0.01, 0.008, (sx * 0.115, TOP - 0.124, sz * 0.115), axis="y", segs=14, name="foot")

# ------------------------------------------------------------------ the lid, open on its hinges, with the notice
HZ = 0.14
ang = math.radians(100.0)


def lid_xf(p):
    """A point in the closed lid's frame (lying on the deck: x, y above the hinge line, z toward the front) to the open lid."""
    x, y, z = p
    dz = z - HZ
    c, s = math.cos(ang), math.sin(ang)
    return Vector((x, TOP + y * c - dz * s, HZ + y * s + dz * c))


lid = m.box("Lid", "leather_black", (0.28, 0.024, 0.28), (0, 0.012, 0.0), bevel=0.005, segs=3, name="lid")
m.deform(lid, lambda v: lid_xf((v.x, v.y, v.z)))
for sx in (-1, 1):
    for sz in (-1, 1):
        cc = m.box("Lid", "brass", (0.018, 0.018, 0.018), (sx * 0.137, 0.012, sz * 0.137), bevel=0.004, segs=3, name="lid_corner")
        m.deform(cc, lambda v: lid_xf((v.x, v.y, v.z)))
ins = m.box("Lid", "felt", (0.25, 0.002, 0.25), (0, -0.0005, 0.0), bevel=0.0, name="lid_lining")
m.deform(ins, lambda v: lid_xf((v.x, v.y, v.z)))
note = m.box("Lid", "paper", (0.12, 0.001, 0.07), (0, -0.002, 0.04), bevel=0.0, name="notice")
m.deform(note, lambda v: lid_xf((v.x, v.y, v.z)))
m.text("Lid", "ink_black", "BITTE NICHT", 0.011, lambda tx, ty, tz: tuple(lid_xf((-tx, -0.0026 - tz, 0.04 - 0.012 - ty))), depth=0.0002, name="note_t1")
m.text("Lid", "ink_black", "UEBERDREHEN", 0.011, lambda tx, ty, tz: tuple(lid_xf((-tx, -0.0026 - tz, 0.04 + 0.008 - ty))), depth=0.0002, name="note_t2")
for sx in (-0.09, 0.09):
    m.cyl("Body", "brass", 0.0045, 0.0045, 0.04, (sx, TOP + 0.002, HZ + 0.001), axis="x", segs=12, name="hinge")

# ------------------------------------------------------------------ turntable, the Record
m.lathe("Body", "steel", [(0.0, 0.0), (0.108, 0.0), (0.111, 0.003), (0.111, 0.009), (0.0, 0.009)], center=(RC.x, TOP + 0.003, RC.z), axis="y", segs=48, name="platter")
m.cyl("Body", "felt", 0.106, 0.106, 0.0015, (RC.x, TOP + 0.0127, RC.z), axis="y", segs=48, bevel=0.0, name="platter_felt")
m.lathe("Record", "shellac", [(0.0035, -0.001), (0.1, -0.001), (0.1015, 0.0), (0.1, 0.001), (0.0035, 0.001)], center=(RC.x, TOP + 0.0145, RC.z), axis="y",
        segs=64, cap0=False, cap1=False, name="record")
m.cyl("Record", "paper", 0.037, 0.037, 0.0004, (RC.x, TOP + 0.0157, RC.z), axis="y", segs=40, bevel=0.0, name="label")


def label(dy):
    def f(tx, ty, tz):
        return (RC.x + tx, TOP + 0.016 + tz, RC.z + dy - ty)
    return f


m.text("Record", "ink_black", "KOMM MIT,", 0.0068, label(-0.012), depth=0.0002, name="label_t1")
m.text("Record", "ink_black", "KLEINER SOLDAT", 0.0055, label(0.0), depth=0.0002, name="label_t2")
m.text("Record", "ink_black", "78", 0.007, label(0.016), depth=0.0002, name="label_t3")
m.cyl("Body", "brass", 0.0032, 0.0028, 0.014, (RC.x, TOP + 0.02, RC.z), axis="y", segs=12, name="spindle")

# ------------------------------------------------------------------ tonearm, soundbox, the siren horn
TA = Vector((0.105, TOP, 0.105))
m.lathe("Body", "brass", [(0.0, 0.0), (0.016, 0.0), (0.016, 0.006), (0.011, 0.009), (0.0085, 0.02), (0.0, 0.02)], center=tuple(TA), axis="y", segs=24, name="arm_base")
arm_pts = [TA + Vector((0.0, 0.019, 0.0)), TA + Vector((0.0, 0.032, -0.012)), TA + Vector((-0.03, 0.036, -0.06)), TA + Vector((-0.07, 0.032, -0.105)),
           TA + Vector((-0.086, 0.026, -0.124))]
m.sweep("Tonearm", "brass", arm_pts, 0.0, radii=[0.0075, 0.007, 0.0062, 0.0055, 0.005], segs=14, smooth_per=6, name="arm")
SB = TA + Vector((-0.092, 0.022, -0.13))
m.lathe("Tonearm", "chrome", [(0.0, -0.006), (0.024, -0.006), (0.026, -0.003), (0.026, 0.003), (0.024, 0.006), (0.0, 0.006)], center=tuple(SB),
        axis=(0.6, 0.0, -0.8), segs=32, name="soundbox")
m.cyl("Tonearm", "steel", 0.0011, 0.0006, 0.014, tuple(SB + Vector((0.0, -0.016, 0.0))), axis="y", segs=8, name="needle")
HB = Vector((0.115, TOP + 0.03, 0.12))
hdir = Vector((0.15, 0.75, 0.55)).normalized()
m.lathe("Body", "brass", [(0.009, 0.0), (0.012, 0.02), (0.016, 0.045), (0.024, 0.075), (0.038, 0.105), (0.06, 0.13), (0.078, 0.142), (0.082, 0.146),
                          (0.079, 0.148), (0.074, 0.143), (0.056, 0.13), (0.035, 0.105), (0.021, 0.075), (0.013, 0.045), (0.009, 0.02), (0.0065, 0.0)],
        center=tuple(HB), axis=tuple(hdir), segs=40, cap0=False, cap1=False, name="horn")
m.sweep("Body", "brass", [TA + Vector((0.0, 0.012, 0.004)), TA + Vector((0.008, 0.024, 0.012)), HB + Vector((0.0, 0.002, 0.0))], 0.008, segs=14, smooth_per=4, name="horn_neck")

# ------------------------------------------------------------------ speed lever, brake, the Crank (right side)
m.box("Body", "brass", (0.006, 0.004, 0.03), (-0.11, TOP + 0.006, -0.1), rot=(0, 30, 0), bevel=0.0008, name="speed_lever")
m.cyl("Body", "brass", 0.0045, 0.0045, 0.006, (-0.118, TOP + 0.008, -0.088), axis="y", segs=12, name="lever_knob")
m.box("Body", "steel", (0.004, 0.006, 0.022), (0.118, TOP + 0.006, -0.085), bevel=0.0008, name="brake")
CK = Vector((0.145, TOP - 0.075, 0.05))
m.lathe("Body", "brass", [(0.0, -0.002), (0.012, -0.002), (0.012, 0.004), (0.0, 0.004)], center=tuple(CK + Vector((-0.004, 0, 0))), axis="x", segs=20, name="crank_escutcheon")
m.cyl("Crank", "chrome", 0.0045, 0.0045, 0.02, tuple(CK + Vector((0.008, 0, 0))), axis="x", segs=12, name="crank_shaft")
m.sweep("Crank", "chrome", [CK + Vector((0.018, 0.0, 0.0)), CK + Vector((0.024, 0.0, 0.0)), CK + Vector((0.026, 0.0, -0.02)), CK + Vector((0.026, 0.0, -0.06)),
                            CK + Vector((0.03, 0.0, -0.065))], 0.0, radii=[(0.0042, 0.003)] * 5, segs=8, smooth_per=4, ref=(0, 1, 0), name="crank_arm")
m.lathe("Crank", "wood_handle", [(0.0, -0.002), (0.006, -0.002), (0.0075, 0.006), (0.0065, 0.014), (0.0078, 0.022), (0.0, 0.0235)],
        center=tuple(CK + Vector((0.03, 0.0, -0.065))), axis="x", segs=16, name="crank_knob")

m.finish(A["out"] or os.path.join(W.HERE, "..", "..", "..", "assets", "ours", "wonder", "gramophone"), turntable=A["turntable"], fast=A["fast"],
         extra_report={"markers": {"Record": [RC.x, TOP + 0.0145, RC.z], "Crank": list(CK), "Tonearm": list(TA), "Lid": [0, TOP, HZ]}})
