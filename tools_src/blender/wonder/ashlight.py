"""Ashlight (UPDATE_05 section 2, T-090): Fasbender's "resonance projector" prototype, built by hand in the Lab Wing.

    blender -b --factory-startup -P tools_src/blender/wonder/ashlight.py -- --out assets/ours/wonder/ashlight [--turntable png] [--fast]

A brass-and-glass pistol (docs/gravelight/WEAPONS.md section 7): a riveted brass spine with a knurled wind key at the
back, a glass chamber on top holding the removable Nachtglas capsule (the Mag: it slides out of the back of the
chamber on the "capsule" reload), copper coils wound in two banks over the barrel with the violet core glowing
between the turns, a flared bronze emitter bell with three electrodes around a violet crystal, a copper sight rod
with a brass bead on the bell, a small resonance gauge on the left (the Needle reads the charge), copper leads from
the chamber to the coils, a wooden grip under a leather wrap with a brass pommel and lanyard ring, a round-bar trigger
guard, and "ABT. II  Nr. 3" raised on the left side plate. The Crucible version (Ashlight Corona) is the same mesh
with the Halo part shown (a bronze ring with a violet filament on four spokes around the coils) and the fluid
brighter (gravelight/weapons/wonder_look.gd).

Frame and markers (game frame, metres; model_fit.json "ashlight" uses the same numbers): grip hand centre
(0, -0.04, 0.05) leaning back 18 deg; support hand cups it ((-0.006, -0.042, 0.052), axis y); SightPoint (0, 0.0985,
0.026) in the rear bridge notch; FrontSight (0, 0.0985, -0.292) on the bead; Muzzle (0, 0.035, -0.31); the capsule
(Mag) centre (0, 0.0745, -0.028).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wonder_lib as W  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

A = W.args()
m = W.Model("ashlight", tex=A["tex"] or 2048)

SY = 0.035          # spine / barrel axis height
CY = 0.0745         # chamber axis height
SIGHT_Y = 0.0985

# ------------------------------------------------------------------ spine, wind key, barrel
m.lathe("Body", "brass", [(0.0, -0.128), (0.0145, -0.128), (0.0165, -0.1245), (0.0165, -0.118), (0.019, -0.1145),
                          (0.019, -0.1), (0.0207, -0.098), (0.0207, -0.091), (0.019, -0.089), (0.019, 0.019),
                          (0.0207, 0.021), (0.0207, 0.029), (0.019, 0.031), (0.019, 0.04), (0.0162, 0.0455), (0.0, 0.0455)],
        center=(0, SY, 0), segs=40, name="spine")
knob = m.lathe("Body", "brass", [(0.0, 0.045), (0.0052, 0.045), (0.0052, 0.0515), (0.0108, 0.0525), (0.0118, 0.0555),
                                 (0.0118, 0.0615), (0.0102, 0.0648), (0.0, 0.0652)], center=(0, SY, 0), segs=48, name="windkey")


def _knurl(v):
    d = Vector((v.x, v.y - SY, 0.0))
    r = d.length
    if r > 0.0105 and 0.0535 < v.z < 0.0635:
        a = math.atan2(d.y, d.x)
        k = 1.0 + 0.07 * (0.5 + 0.5 * math.cos(a * 24))
        return Vector((d.x * k, SY + d.y * k, v.z))
    return v


m.deform(knob, _knurl)
m.lathe("Body", "brass", [(0.0, -0.262), (0.0086, -0.262), (0.0086, -0.128), (0.0, -0.128)], center=(0, SY, 0), segs=24, name="barrel")
m.cyl("Body", "coil_glow", 0.0103, 0.0103, 0.118, (0, SY, -0.1925), segs=20, name="coreglow")
for (z0, z1, ph) in ((-0.1365, -0.1885, 0.0), (-0.1965, -0.2485, 1.3)):
    m.helix("Body", "copper", 0.0119, 0.00125, z0, z1, 15, center=(0, SY, 0), per_turn=10, segs=5, phase=ph, name="coil")
for z in (-0.1325, -0.1925, -0.2525):
    m.lathe("Body", "bronze", [(0.0084, z - 0.0025), (0.013, z - 0.0025), (0.0148, z - 0.0012), (0.0148, z + 0.0012),
                               (0.013, z + 0.0025), (0.0084, z + 0.0025)], center=(0, SY, 0), segs=32, cap0=False, cap1=False, name="coilring")

# ------------------------------------------------------------------ emitter bell, crystal, electrodes, sight rod
m.lathe("Body", "bronze", [(0.0146, -0.2545), (0.016, -0.262), (0.0202, -0.2752), (0.0272, -0.2902), (0.0318, -0.2978),
                           (0.0332, -0.3008), (0.0318, -0.3036), (0.0292, -0.3004), (0.0222, -0.2905), (0.015, -0.2782),
                           (0.0104, -0.2685), (0.0, -0.2685)], center=(0, SY, 0), segs=40, cap0=False, cap1=False, name="bell")
m.lathe("Body", "emitter", [(0.0, -0.2685), (0.0062, -0.2742), (0.0048, -0.2842), (0.0, -0.2925)], center=(0, SY, 0), segs=6, name="crystal", smooth=False)
for ang in (30.0, 150.0, 270.0):
    a = math.radians(ang)
    d = Vector((math.cos(a), math.sin(a), 0.0))
    p0 = Vector((0, SY, -0.2935)) + d * 0.0268
    p1 = Vector((0, SY, -0.2865)) + d * 0.0088
    m.sweep("Body", "copper", [p0, p0.lerp(p1, 0.5) + Vector((0, 0, -0.002)), p1], 0.00095, segs=6, smooth_per=4, name="electrode")
    m.lathe("Body", "copper", [(0.0, -0.0018), (0.0017, -0.0012), (0.0017, 0.0012), (0.0, 0.0018)], center=tuple(p1), axis=tuple(d), segs=10, name="electrode_tip")
# the sight rod: a copper antenna rising off the bell's lip with a porcelain stand-off and a brass bead
m.sweep("Body", "copper", [(0, SY + 0.0305, -0.2955), (0, SY + 0.044, -0.2935), (0, 0.0952, -0.292)], 0.0011, segs=8, smooth_per=4, name="sightrod")
m.lathe("Body", "porcelain", [(0.0, -0.004), (0.0026, -0.0036), (0.0031, -0.0012), (0.0024, 0.0), (0.0031, 0.0012), (0.0026, 0.0036), (0.0, 0.004)],
        center=(0, SY + 0.043, -0.2938), axis="y", segs=14, name="standoff")
m.lathe("Body", "brass", [(0.0, -0.0022), (0.0016, -0.0018), (0.0022, -0.0006), (0.0022, 0.0006), (0.0016, 0.0018), (0.0, 0.0022)],
        center=(0, 0.097, -0.292), axis="y", segs=14, name="bead")

# ------------------------------------------------------------------ chamber: glass sleeve, collars, cage, saddles
m.tube("Body", "glass", 0.0178, 0.0192, 0.1, (0, CY, -0.028), segs=36, name="chamber")
m.lathe("Body", "brass", [(0.0166, 0.022), (0.0216, 0.022), (0.0222, 0.0235), (0.0222, 0.0305), (0.0216, 0.032), (0.0166, 0.032)],
        center=(0, CY, 0), segs=36, cap0=False, cap1=False, name="collar_r")
m.lathe("Body", "brass", [(0.0, -0.089), (0.0216, -0.089), (0.0222, -0.0875), (0.0222, -0.0795), (0.0216, -0.078), (0.0166, -0.078),
                          (0.0166, -0.082), (0.0, -0.082)], center=(0, CY, 0), segs=36, cap0=False, cap1=False, name="collar_f")
for sx in (-1.0, 1.0):
    for z in (0.027, -0.0835):
        m.box("Body", "brass", (0.006, 0.012, 0.008), (sx * 0.011, 0.056, z), rot=(0, 0, sx * 35), bevel=0.0008, name="saddle")
rv = []
for ang in (38.0, 142.0):
    a = math.radians(ang)
    d = Vector((math.cos(a), math.sin(a), 0.0))
    c = Vector((0, CY, -0.0285)) + d * 0.0208
    rot = (0, 0, ang - 90.0)
    m.box("Body", "brass", (0.0032, 0.0024, 0.103), tuple(c), rot=rot, bevel=0.0005, name="cagebar")
    for z in (0.027, -0.0835):
        rv.append((tuple(Vector((0, CY, z)) + d * 0.0222), tuple(d)))
for k in range(8):
    a = math.tau * k / 8 + 0.2
    d = Vector((math.cos(a), math.sin(a), 0.0))
    if d.y > -0.5:
        rv.append((tuple(Vector((0, SY, -0.0945)) + d * 0.0207), tuple(d)))

# ------------------------------------------------------------------ rear sight bridge (the capsule slides out under it)
for sx in (-1.0, 1.0):
    m.box("Body", "brass", (0.0045, 0.043, 0.006), (sx * 0.0222, 0.0715, 0.03), bevel=0.0008, name="bridge_post")
m.box("Body", "brass", (0.049, 0.0062, 0.0062), (0, 0.0944, 0.03), bevel=0.0008, name="bridge_bar")
for sx in (-1.0, 1.0):
    m.box("Body", "brass", (0.0068, 0.004, 0.0062), (sx * 0.0055, SIGHT_Y + 0.0005, 0.03), bevel=0.0004, name="bridge_ear")

# ------------------------------------------------------------------ capsule (the Mag): glass vial, brass caps, pull ring, fluid
m.lathe("Mag", "glass", [(0.0, -0.068), (0.0118, -0.068), (0.0124, -0.066), (0.0124, 0.012), (0.0118, 0.014), (0.0, 0.014)],
        center=(0, CY, 0), segs=28, name="vial")
m.cyl("Mag", "fluid", 0.0108, 0.0108, 0.078, (0, CY, -0.027), segs=24, name="fluid")
m.lathe("Mag", "brass", [(0.0, -0.0765), (0.0098, -0.0765), (0.0128, -0.0745), (0.0136, -0.071), (0.0136, -0.0655), (0.0122, -0.064),
                         (0.0, -0.064)], center=(0, CY, 0), segs=28, name="cap_f")
m.lathe("Mag", "brass", [(0.0, 0.0115), (0.0122, 0.0115), (0.0136, 0.013), (0.0136, 0.019), (0.0124, 0.0215), (0.0058, 0.023),
                         (0.0058, 0.026), (0.0, 0.026)], center=(0, CY, 0), segs=28, name="cap_r")
m.torus("Mag", "brass", 0.0062, 0.0013, (0, CY, 0.0322), axis="x", segs=20, rsegs=8, name="pullring")

# ------------------------------------------------------------------ frame, side plates, trigger, guard
m.prism("Body", "brass", [(0.052, 0.021), (-0.062, 0.021), (-0.066, 0.012), (-0.056, 0.002), (0.028, -0.001), (0.058, 0.008), (0.06, 0.018)],
        -0.0132, 0.0132, bevel=0.002, name="frame")
for sx in (-1.0, 1.0):
    x0, x1 = (0.0132, 0.0148) if sx > 0 else (-0.0148, -0.0132)
    m.prism("Body", "brass", [(0.046, 0.026), (-0.05, 0.026), (-0.054, 0.022), (-0.054, 0.008), (-0.048, 0.004), (0.042, 0.004), (0.048, 0.01)],
            x0, x1, bevel=0.0007, name="sideplate")
    for z in (0.04, 0.02, 0.0, -0.02, -0.045):
        for y in (0.0075, 0.0225):
            if z in (0.0, -0.02) and y == 0.0225 and sx < 0:
                continue          # the stamped lettering sits there
            rv.append(((sx * 0.0148, y, z), (sx, 0.0, 0.0)))
m.text("Body", "brass", "ABT. II  Nr. 3", 0.0052, lambda tx, ty, tz: (-0.0148 - tz, 0.0205 + ty, -0.01 + tx), depth=0.0005, name="stamp")
m.prism("Body", "bronze", [(-0.0035, 0.0), (-0.0095, -0.007), (-0.0128, -0.0165), (-0.0112, -0.0245), (-0.0078, -0.0215),
                            (-0.0058, -0.012), (-0.0012, -0.002)], -0.0028, 0.0028, bevel=0.0007, name="trigger")
m.sweep("Body", "brass", [(0, 0.0, -0.05), (0, -0.012, -0.052), (0, -0.028, -0.04), (0, -0.034, -0.012), (0, -0.026, 0.016),
                          (0, -0.01, 0.03)], 0.0022, segs=10, smooth_per=6, name="guard")

# ------------------------------------------------------------------ resonance gauge (left side), its needle
GZ, GYc, GX = -0.058, 0.03, -0.0205
m.lathe("Body", "brass", [(0.0, 0.0012), (0.0108, 0.0012), (0.0112, -0.0008), (0.0104, -0.0032), (0.0088, -0.0032), (0.0088, -0.0018),
                          (0.0, -0.0018)], center=(GX, GYc, GZ), axis="x", segs=32, name="gauge_bezel")
m.cyl("Body", "enamel_cream", 0.0089, 0.0089, 0.0006, (GX - 0.0021, GYc, GZ), axis="x", segs=32, bevel=0.0, name="gauge_face")
ticks = []
for k in range(9):
    a = math.radians(-120 + 240 * k / 8)
    r0, r1 = (0.0058 if k % 2 == 0 else 0.0066), 0.0079
    ticks.append([(math.sin(a) * r0, math.cos(a) * r0), (math.sin(a) * r1, math.cos(a) * r1)])
arc_pts = [(math.sin(math.radians(a)) * 0.0081, math.cos(math.radians(a)) * 0.0081) for a in range(-120, 121, 10)]
ticks.append(arc_pts)
# face coordinates: s toward the gun's front (-z), t up
m.strokes("Body", "ink_black", ticks, 0.00045, lambda s, t, h: (GX - 0.0024 - h, GYc + t, GZ - s), depth=0.0002, name="gauge_ticks")
m.box("Needle", "ink_black", (0.0004, 0.0072, 0.0009), (GX - 0.0029, GYc + 0.0032, GZ), bevel=0.0, name="needle")
m.cyl("Needle", "brass", 0.0011, 0.0011, 0.0012, (GX - 0.003, GYc, GZ), axis="x", segs=12, bevel=0.0, name="needle_hub")
m.cyl("Body", "glass", 0.0089, 0.0089, 0.0005, (GX - 0.0042, GYc, GZ), axis="x", segs=32, bevel=0.0, name="gauge_glass")

# ------------------------------------------------------------------ copper leads chamber -> coils (with porcelain beads)
for sx in (-1.0, 1.0):
    pts = [(sx * 0.0158, CY - 0.012, -0.0885), (sx * 0.02, 0.058, -0.104), (sx * 0.0182, 0.049, -0.12), (sx * 0.0142, 0.0405, -0.1352)]
    m.sweep("Body", "copper", pts, 0.0011, segs=8, smooth_per=6, name="lead")
    mid = Vector((sx * 0.0198, 0.0555, -0.1085))
    m.lathe("Body", "porcelain", [(0.0, -0.0032), (0.0019, -0.0028), (0.0024, -0.001), (0.0018, 0.0), (0.0024, 0.001), (0.0019, 0.0028), (0.0, 0.0032)],
            center=tuple(mid), axis=(0.0, -0.45, -0.89), segs=12, name="bead_ins")

# ------------------------------------------------------------------ grip: wooden core, leather wrap, ferrule, pommel, lanyard ring
LEAN = math.radians(18.0)
T = Vector((0.0, 0.006, 0.0335))
D = Vector((0.0, -math.cos(LEAN), math.sin(LEAN)))
FWD = Vector((0.0, -math.sin(LEAN), -math.cos(LEAN)))        # perpendicular to D, toward the muzzle
L = 0.1
prof = [(0.0, 0.0192, 0.0148), (0.012, 0.0204, 0.0152), (0.03, 0.0212, 0.0156), (0.05, 0.0214, 0.0158), (0.07, 0.0208, 0.0156),
        (0.088, 0.0198, 0.015), (0.1, 0.019, 0.0145)]
m.sweep("Body", "wood_handle", [T + D * p[0] for p in prof], 0.0, radii=[(p[1], p[2]) for p in prof], segs=20, ref=FWD, name="grip_core")
bands = 11
for i in range(bands):
    t = 0.015 + i * (0.074 / (bands - 1))
    k = next(j for j in range(len(prof) - 1) if prof[j + 1][0] >= t)
    f = (t - prof[k][0]) / (prof[k + 1][0] - prof[k][0])
    a = prof[k][1] + (prof[k + 1][1] - prof[k][1]) * f + 0.0009
    b = prof[k][2] + (prof[k + 1][2] - prof[k][2]) * f + 0.0009
    tilt = math.radians(9.0)
    loop = []
    for j in range(28):
        th = math.tau * j / 28
        side = Vector((1.0, 0.0, 0.0))
        p = T + D * (t + math.sin(th) * math.tan(tilt) * b) + FWD * (math.cos(th) * a) + side * (math.sin(th) * b)
        loop.append(p)
    m.sweep("Body", "leather", loop, 0.0, radii=[(0.0039, 0.0011)] * len(loop), segs=8, closed=True, ref=D, name="wrap")
ferr = [(0.0, 0.0205, 0.0158), (0.0085, 0.0208, 0.016)]
m.sweep("Body", "brass", [T + D * (p[0] - 0.001) for p in ferr], 0.0, radii=[(p[1], p[2]) for p in ferr], segs=24, ref=FWD, name="ferrule")
B = T + D * L
pom = m.lathe("Body", "brass", [(0.0, -0.002), (0.0192, -0.002), (0.0198, 0.001), (0.0182, 0.0052), (0.012, 0.008), (0.0, 0.0088)],
              center=tuple(B), axis=tuple(D), segs=28, name="pommel")
m.deform(pom, lambda v: Vector((v.x * 0.77, v.y, v.z)))
m.torus("Body", "brass", 0.0062, 0.0012, tuple(B + D * 0.0145), axis=(1.0, 0.0, 0.0), segs=20, rsegs=8, name="lanyard")
m.cyl("Body", "brass", 0.0018, 0.0018, 0.004, tuple(B + D * 0.0095), axis=tuple(D), segs=10, name="lanyard_eye")

m.rivets("Body", "brass", rv, r=0.0016, name="rivets")

# ------------------------------------------------------------------ the Corona halo (Crucible; hidden on the base gun)
HZ = -0.1925
m.torus("Halo", "bronze", 0.042, 0.0021, (0, SY, HZ), axis="z", segs=48, rsegs=8, name="halo_ring")
m.torus("Halo", "halo", 0.0365, 0.0013, (0, SY, HZ - 0.001), axis="z", segs=48, rsegs=6, name="halo_glow")
for k in range(4):
    a = math.radians(45 + 90 * k)
    d = Vector((math.cos(a), math.sin(a), 0.0))
    p0 = Vector((0, SY, HZ)) + d * 0.0148
    p1 = Vector((0, SY, HZ)) + d * 0.0402
    m.sweep("Halo", "copper", [p0, p1], 0.0012, segs=6, name="halo_spoke")
    m.lathe("Halo", "glow", [(0.0, -0.0028), (0.0022, -0.0016), (0.0022, 0.0016), (0.0, 0.0028)], center=tuple(p0.lerp(p1, 0.55)), axis=tuple(d),
            segs=8, name="halo_bead")

m.crucible_parts = ["Halo"]
m.finish(A["out"] or os.path.join(W.HERE, "..", "..", "..", "assets", "ours", "wonder", "ashlight"), turntable=A["turntable"], fast=A["fast"],
         extra_report={"markers": {"Muzzle": [0, SY, -0.31], "SightPoint": [0, SIGHT_Y, 0.026], "FrontSight": [0, SIGHT_Y, -0.292],
                                   "LeftHand": [-0.006, -0.042, 0.052], "grip_r": [0, -0.04, 0.05], "Mag": [0, CY, -0.028],
                                   "Needle": [GX, GYc, GZ], "Halo": [0, SY, HZ]}})
