"""The Lodestone (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 8): the Groom Lake gravity caster Sgt. Marchetti's
yard built from the Nevada stone's salvage: a lead-glass lens (the Sphere) in a brass gyro cradle (the Cradle: three
nested rings on pivots) hung under the end of a brass yoke (the Yoke) carried two-handed like a lantern on a pole, the
relay coil (the Coil) wound round the yoke behind the front grip, the fork down to the cradle's pivots, a wooden rear grip (Grip_R) and a front
grip (Grip_L); the Corona (Escape Velocity only) is a violet ring of Nachtglas light round the lens.

    blender -b --factory-startup -P tools_src/blender/wonder/lodestone.py -- --out assets/ours/wonder/lodestone [--turntable png] [--fast]

Frame and markers (game frame, metres): grip hand (0, -0.045, 0.055) leaning 15 deg; LeftHand (0, -0.045, -0.2) on
the front grip (axis y); the lens hangs in its cradle UNDER the end of the yoke's bar (the bar runs out over it to the
bead), so the sight line along the bar's top is clear (test_sight_clearance): SightPoint (0, 0.0538, -0.024) in the
rear notch on the bar, FrontSight (0, 0.0528, -0.44) on the bead at the bar's tip; Muzzle (0, -0.11, -0.41) at the
lens's front; the Sphere and the Cradle turn about (0, -0.11, -0.34); the Coil sits at (0, 0.02, -0.16) (its rings
stay under the sight line). Lodestone.pose_parts spins the Sphere, opens the Cradle (z) on a lift and lights the Coil
on the fling charge; WonderLook._tick_lodestone drives the glass's energy.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wonder_lib as W  # noqa: E402
from mathutils import Vector  # noqa: E402

A = W.args()
m = W.Model("lodestone", tex=A["tex"] or 2048)

YY = 0.02            # the yoke's axis height
HEAD = (0.0, -0.11, -0.34)   # the lens's centre: hung under the bar's end

# ------------------------------------------------------------------ the yoke (Yoke): the brass bar out over the lens, the fork down to the cradle, the sights on the bar's top
m.box("Yoke", "brass", (0.026, 0.026, 0.56), (0, YY, -0.18), bevel=0.0025, name="bar")
m.lathe("Yoke", "brass", [(0.0, -0.004), (0.014, -0.004), (0.014, 0.004), (0.0, 0.004)], center=(0, YY, -0.462), axis="z", segs=20, name="bar_cap")
# the rear notch: a block on the bar's top with two ears (SightPoint between them); the bead on a post at the bar's tip
m.box("Yoke", "brass", (0.03, 0.012, 0.008), (0, 0.041, -0.02), bevel=0.0008, name="notch_base")
for sx in (-1.0, 1.0):
    m.box("Yoke", "brass", (0.011, 0.012, 0.008), (sx * 0.0095, 0.049, -0.02), bevel=0.0006, name="notch_ear")
m.box("Yoke", "brass", (0.008, 0.014, 0.008), (0, 0.04, -0.44), bevel=0.0008, name="beadpost")
m.lathe("Yoke", "brass", [(0.0, -0.0035), (0.0035, -0.0025), (0.004, 0.0), (0.0035, 0.0025), (0.0, 0.0035)], center=(0, 0.05, -0.44), axis="y", segs=12, name="bead")
# the fork: two brass arms from the bar down and out to the cradle's outer pivots
for sx in (-1.0, 1.0):
    m.sweep("Yoke", "brass", [(sx * 0.012, YY + 0.006, -0.34), (sx * 0.07, -0.03, -0.34), (sx * 0.118, HEAD[1], -0.34)], 0.006, segs=10, smooth_per=4, name="fork")
    m.lathe("Yoke", "brass", [(0.0, -0.006), (0.009, -0.006), (0.009, 0.006), (0.0, 0.006)], center=(sx * 0.121, HEAD[1], -0.34), axis="x", segs=14, name="pivot_knob")
# a stencilled yard tag on the bar: the only writing on it
m.text("Yoke", "brass", "GL-SALV. 1945", 0.0055, lambda tx, ty, tz: (-0.0135 - tz, YY + 0.004 + ty, -0.05 + tx), depth=0.0005, name="stamp")

# ------------------------------------------------------------------ the cradle (Cradle): three nested brass rings on pivots
m.torus("Cradle", "brass", 0.105, 0.0055, HEAD, axis="z", segs=48, rsegs=10, name="ring_outer")
m.torus("Cradle", "brass", 0.09, 0.005, HEAD, axis="x", segs=44, rsegs=10, name="ring_mid")
m.torus("Cradle", "brass", 0.077, 0.0045, HEAD, axis="y", segs=40, rsegs=10, name="ring_inner")
for ang in (0.0, 90.0, 180.0, 270.0):
    a = math.radians(ang)
    p = Vector(HEAD) + Vector((math.cos(a) * 0.097, math.sin(a) * 0.097, 0.0))
    m.lathe("Cradle", "brass", [(0.0, -0.005), (0.007, -0.005), (0.007, 0.005), (0.0, 0.005)], center=tuple(p), axis="z", segs=12, name="ring_pin")

# ------------------------------------------------------------------ the lens (Sphere): lead glass, a Nachtglas seed inside
m.lathe("Sphere", "glass", [(0.0, -0.062)] + [(0.062 * math.sin(math.pi * k / 16), -0.062 * math.cos(math.pi * k / 16)) for k in range(1, 16)] + [(0.0, 0.062)],
        center=HEAD, axis="z", segs=40, name="lens")
m.lathe("Sphere", "emitter", [(0.0, -0.018)] + [(0.018 * math.sin(math.pi * k / 8), -0.018 * math.cos(math.pi * k / 8)) for k in range(1, 8)] + [(0.0, 0.018)],
        center=(HEAD[0] + 0.012, HEAD[1] + 0.008, HEAD[2] - 0.01), axis="z", segs=16, name="seed")
# the lens's two brass caps where the inner ring's pivots hold it
for sy in (-1.0, 1.0):
    m.lathe("Sphere", "brass", [(0.0, -0.005), (0.012, -0.005), (0.014, -0.002), (0.014, 0.002), (0.012, 0.005), (0.0, 0.005)],
            center=(HEAD[0], HEAD[1] + sy * 0.064, HEAD[2]), axis="y", segs=16, name="lens_cap")

# ------------------------------------------------------------------ the relay coil (Coil): copper on a ceramic former round the yoke
m.lathe("Coil", "porcelain", [(0.0145, -0.05), (0.026, -0.05), (0.026, -0.045), (0.021, -0.045), (0.021, 0.045), (0.026, 0.045), (0.026, 0.05), (0.0145, 0.05)],
        center=(0, YY, -0.16), axis="z", segs=28, cap0=False, cap1=False, name="former")
m.helix("Coil", "copper", 0.0235, 0.0016, -0.044, 0.044, 22, center=(0, YY, -0.16), per_turn=12, segs=6, name="winding")
m.cyl("Coil", "coil_glow", 0.0215, 0.0215, 0.086, (0, YY, -0.16), segs=20, name="coilglow")
for z in (-0.212, -0.108):
    m.lathe("Coil", "brass", [(0.014, -0.003), (0.027, -0.003), (0.028, 0.0), (0.027, 0.003), (0.014, 0.003)], center=(0, YY, z), axis="z", segs=28, cap0=False, cap1=False, name="coilring")
# the coil's two leads along the bar's flanks and down the fork to the cradle's pivots
m.sweep("Coil", "copper", [(0.014, YY + 0.02, -0.2), (0.016, YY - 0.004, -0.3), (0.06, -0.03, -0.335), (0.11, HEAD[1] + 0.012, -0.335)], 0.0012, segs=6, smooth_per=4, name="lead_a")
m.sweep("Coil", "copper", [(-0.014, YY + 0.02, -0.12), (-0.016, YY - 0.004, -0.3), (-0.06, -0.03, -0.335), (-0.11, HEAD[1] + 0.012, -0.335)], 0.0012, segs=6, smooth_per=4, name="lead_b")

# ------------------------------------------------------------------ the grips: rear (Grip_R, leaning 15 deg) and front (Grip_L, vertical)
m.lathe("Grip_R", "wood", [(0.0, -0.055), (0.017, -0.055), (0.021, -0.04), (0.019, 0.0), (0.021, 0.04), (0.017, 0.055), (0.0, 0.055)],
        center=(0, -0.045, 0.055), axis=(0.0, math.cos(math.radians(15)), math.sin(math.radians(15))), segs=20, name="grip_r")
m.lathe("Grip_R", "brass", [(0.0, -0.004), (0.023, -0.004), (0.023, 0.004), (0.0, 0.004)], center=(0, -0.102, 0.07), axis=(0.0, math.cos(math.radians(15)), math.sin(math.radians(15))), segs=20, name="grip_r_cap")
m.lathe("Grip_L", "wood", [(0.0, -0.05), (0.015, -0.05), (0.019, -0.035), (0.017, 0.0), (0.019, 0.035), (0.015, 0.05), (0.0, 0.05)],
        center=(0, -0.045, -0.2), axis="y", segs=20, name="grip_l")
m.lathe("Grip_L", "brass", [(0.0, -0.004), (0.02, -0.004), (0.02, 0.004), (0.0, 0.004)], center=(0, -0.098, -0.2), axis="y", segs=20, name="grip_l_cap")
# the trigger and guard under the yoke, behind the front grip
m.prism("Body", "bronze", [(-0.0035, 0.0), (-0.0095, -0.007), (-0.0128, -0.0165), (-0.0112, -0.0245), (-0.0078, -0.0215),
                            (-0.0058, -0.012), (-0.0012, -0.002)], -0.0028, 0.0028, bevel=0.0007, name="trigger")
m.sweep("Body", "brass", [(0, 0.0, -0.05), (0, -0.012, -0.052), (0, -0.028, -0.04), (0, -0.034, -0.012), (0, -0.026, 0.016),
                          (0, -0.01, 0.03)], 0.0022, segs=10, smooth_per=6, name="guard")

# ------------------------------------------------------------------ the Corona (Escape Velocity): a ring of violet light round the lens
m.torus("Corona", "halo", 0.07, 0.004, HEAD, axis="z", segs=48, rsegs=8, name="corona")

m.finish(A["out"] or os.path.join(W.HERE, "..", "..", "..", "assets", "ours", "wonder", "lodestone"), turntable=A["turntable"], fast=A["fast"],
         extra_report={"markers": {"Muzzle": [0, -0.11, -0.41], "SightPoint": [0, 0.0538, -0.024], "FrontSight": [0, 0.0528, -0.44],
                                   "LeftHand": [0, -0.045, -0.2], "grip_r": [0, -0.045, 0.055], "Sphere": list(HEAD), "Cradle": list(HEAD),
                                   "Coil": [0, YY, -0.16]}})
