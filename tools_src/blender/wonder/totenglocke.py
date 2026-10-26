"""Totenglocke (UPDATE_05 section 2, T-090): the handheld bell cannon Opitz sketched and never built (INT_M1_23), put
together by the squad at the Generator Hall workbench from the three Map 1 parts (docs/gravelight/WEAPONS.md section 8).

    blender -b --factory-startup -P tools_src/blender/wonder/totenglocke.py -- --out assets/ours/wonder/totenglocke [--turntable png] [--fast]

Each part shows where it came from:
  the BELL   a small bronze locomotive bell from the Rail Yard: a real bell profile (crown, shoulder, waist, sound bow,
             lip) laid mouth-forward, cast bead lines, "ZECHE KALTENBRUNN" and "GRUBENBAHN 1911" raised on the waist
             and sound bow, hung on its cast-iron yoke whose broken-off locomotive foot still has its bolt holes;
  the FRAME  welded from barracks bunk-bed tubing (field-grey paint chipped to steel): one bent tube runs from the
             grip back along the left side, up, across over the bell crown (carrying the rear sight) and back down the
             right; brass bed finials on its ends, spring hooks along the rails, a riveted quartermaster's tag
             "KAS. II  BETT 14" painted on the left, a bed slat for the spine, a spring strap braced under the bell;
  the CRANK  a turret-clock winding crank from the Salt Chapel tower: square socket hub, bent wrought arm, turned
             wooden knob worn dark by hands, a hank of bell rope tied round the arm, salt crusted at the hub; it winds a
             ratchet wheel (the Pawl clicks over its twelve teeth) and a mainspring barrel.
Opitz's additions: a striker Hammer on the left (it cocks back as you wind and strikes the sound bow on the toll), a
torsion spring at its pivot, a brass bead on a clamp at the lip and a notch plate on the crossbar for the sights.
Mitternacht (the Crucible version) is the same mesh: the Runes part (violet runes cast round the sound bow, emissive)
shows, and the metal takes a midnight-blue patina (model_fit "wonder.upgraded.shader").

Frame and markers (game frame, metres): grip hand (0, -0.045, 0.055) leaning 15 deg; LeftHand (0, -0.045, -0.2) on
the front grip (axis y); SightPoint (0, 0.228, -0.205) in the notch; FrontSight (0, 0.228, -0.452) on the bead;
Muzzle (0, 0.065, -0.47) at the mouth; Crank pivot (0.072, 0.02, -0.05) turning about x, its knob at +(0.03, 0.11, 0)
(Totenglocke.reload_hand's handle); Hammer pivot (-0.106, 0.075, -0.212) turning about y; Pawl pivot
(0.052, 0.062, -0.022) about x; the Bell group sits at the origin (Totenglocke.pose_parts shakes it).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wonder_lib as W  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

A = W.args()
m = W.Model("totenglocke", tex=A["tex"] or 2048)

BY = 0.065          # bell axis height
SIGHT_Y = 0.228
CR = Vector((0.072, 0.02, -0.05))      # crank pivot

# ------------------------------------------------------------------ the bell (outer and inner surface in one lathe)
OUT = [(0.0, -0.2), (0.046, -0.2), (0.062, -0.203), (0.07, -0.209), (0.074, -0.218), (0.0765, -0.229), (0.0775, -0.232),
       (0.0765, -0.235), (0.079, -0.25), (0.083, -0.27), (0.0845, -0.273), (0.083, -0.276), (0.087, -0.3), (0.093, -0.33),
       (0.101, -0.36), (0.112, -0.388), (0.1225, -0.408), (0.125, -0.411), (0.1235, -0.414), (0.134, -0.432), (0.142, -0.447),
       (0.147, -0.458), (0.148, -0.463), (0.146, -0.467)]
INN = [(0.141, -0.466), (0.133, -0.458), (0.12, -0.44), (0.104, -0.41), (0.09, -0.375), (0.079, -0.335), (0.07, -0.295),
       (0.064, -0.255), (0.058, -0.228), (0.048, -0.214), (0.0, -0.212)]


def bell_r(z):
    """Outer radius of the bell at depth z (for placing lettering, runes, the hammer)."""
    for i in range(len(OUT) - 1):
        r0, z0 = OUT[i]
        r1, z1 = OUT[i + 1]
        if z1 <= z <= z0:
            f = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * f
    return OUT[-1][0]


m.lathe("Bell", "bronze_cast", OUT + INN, center=(0, BY, 0), segs=64, cap0=False, cap1=False, name="bell")
# the canon (crown boss) and the trunnion bosses the yoke pins go through
m.lathe("Bell", "bronze_cast", [(0.0, -0.188), (0.026, -0.188), (0.03, -0.192), (0.034, -0.2), (0.0, -0.2)], center=(0, BY, 0), segs=24, name="canon")
for sx in (-1.0, 1.0):
    m.cyl("Bell", "bronze_cast", 0.013, 0.013, 0.014, (sx * 0.08, BY, -0.236), axis="x", segs=20, name="trunnion_boss")


def on_bell(a_center, z_band, lift=0.0):
    def f(tx, ty, tz):
        z = z_band + ty
        r = bell_r(z) + tz + lift
        a = a_center + tx / r
        return (math.cos(a) * r, BY + math.sin(a) * r, z)
    return f


m.text("Bell", "bronze_cast", "ZECHE KALTENBRUNN", 0.0105, on_bell(math.radians(150), -0.316), depth=0.0009, name="inscr1")
m.text("Bell", "bronze_cast", "GRUBENBAHN  1911", 0.0085, on_bell(math.radians(205), -0.392), depth=0.0008, name="inscr2")

# ------------------------------------------------------------------ Mitternacht's runes (Crucible only): cast round the sound bow
RUNES = [
    [[(0, 0), (0, 1)], [(0, 1), (0.5, 0.6)], [(0, 0.6), (0.5, 0.2)]],
    [[(0, 0), (0, 1)], [(0, 0.5), (0.5, 1)], [(0, 0.5), (0.5, 0)]],
    [[(0, 0), (0.25, 1)], [(0.25, 1), (0.5, 0)], [(0.1, 0.45), (0.4, 0.45)]],
    [[(0, 1), (0.5, 0)], [(0, 0), (0.5, 1)]],
    [[(0.25, 0), (0.25, 1)], [(0, 0.75), (0.25, 1)], [(0.5, 0.75), (0.25, 1)]],
    [[(0, 0), (0, 1)], [(0.5, 0), (0.5, 1)], [(0, 1), (0.5, 0)]],
]
rune_lines = []
n_r = 14
for k in range(n_r):
    g = RUNES[k % len(RUNES)]
    a = math.tau * k / n_r
    for st in g:
        rune_lines.append([((a, p[0] - 0.25), p[1] - 0.5) for p in st])
RUNE_Z = -0.432


def rune_map(s, t, h):
    a, du = s
    z = RUNE_Z + t * 0.016
    r = bell_r(z) + 0.0006 + h
    aa = a + du * 0.016 / r
    return Vector((math.cos(aa) * r, BY + math.sin(aa) * r, z))


# strokes() works in flat (s, t); runes need (angle, offset): build the strips by hand with the same helper shape
import bmesh  # noqa: E402
bm = bmesh.new()
for pl in rune_lines:
    (a0, u0), t0 = pl[0]
    (a1, u1), t1 = pl[1]
    pa, pb = Vector((u0, t0)), Vector((u1, t1))
    d = pb - pa
    nn = Vector((-d.y, d.x)).normalized() * 0.07
    ex = d.normalized() * 0.07
    q = [pa - nn - ex, pb - nn + ex, pb + nn + ex, pa + nn - ex]
    lo = [bm.verts.new(rune_map((a0, p.x), p.y, 0.0)) for p in q]
    hi = [bm.verts.new(rune_map((a0, p.x), p.y, 0.0007)) for p in q]
    bm.faces.new(hi)
    for k in range(4):
        bm.faces.new([lo[k], lo[(k + 1) % 4], hi[(k + 1) % 4], hi[k]])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
m._obj("runes", bm, "Runes", "runes", smooth=False, wn=False)
# a cast band the runes sit in (shown with them)
m.lathe("Runes", "bronze_cast", [(bell_r(RUNE_Z + 0.011) + 0.0009, RUNE_Z + 0.011), (bell_r(RUNE_Z + 0.011) + 0.0016, RUNE_Z + 0.0105),
                                  (bell_r(RUNE_Z - 0.011) + 0.0016, RUNE_Z - 0.0105), (bell_r(RUNE_Z - 0.011) + 0.0009, RUNE_Z - 0.011)],
        center=(0, BY, 0), segs=64, cap0=False, cap1=False, name="rune_band")

# ------------------------------------------------------------------ the yoke (cast iron, torn off a locomotive)
m.prism("Body", "iron", [(-0.182, 0.036), (-0.262, 0.036), (-0.262, 0.05), (-0.182, 0.05)], -0.1, 0.1, bevel=0.003, name="yoke_base")
for sx in (-1.0, 1.0):
    x0, x1 = (0.084, 0.098) if sx > 0 else (-0.098, -0.084)
    m.prism("Body", "iron", [(-0.21, 0.046), (-0.262, 0.046), (-0.252, 0.074), (-0.244, 0.082), (-0.228, 0.082), (-0.218, 0.07)], x0, x1, bevel=0.002, name="yoke_arm")
    m.cyl("Body", "steel", 0.0062, 0.0062, 0.034, (sx * 0.093, BY, -0.236), axis="x", segs=16, name="trunnion_pin")
    m.bolt_heads("Body", "steel", [((sx * 0.1, BY, -0.236), (sx, 0, 0))], r=0.0085, h=0.004, name="pin_nut")
# the broken foot: a flange sticking out under the yoke with two empty bolt holes and a jagged edge
foot = m.prism("Body", "iron", [(-0.19, 0.036), (-0.255, 0.036), (-0.262, 0.03), (-0.25, 0.024), (-0.236, 0.029), (-0.222, 0.022),
                               (-0.205, 0.028), (-0.188, 0.024)], -0.128, -0.098, bevel=0.0015, name="foot")
for z in (-0.205, -0.24):
    m.cyl("Body", "paint_black", 0.0045, 0.0045, 0.0125, (-0.113, 0.03, z), axis="y", segs=12, bevel=0.0, name="bolt_hole")
m.bolt_heads("Body", "steel", [((x, 0.05, z), (0, 1, 0)) for x in (-0.06, 0.06) for z in (-0.195, -0.25)], r=0.0068, h=0.004, name="yoke_bolts")

# ------------------------------------------------------------------ the frame: one bent bunk-bed tube
fr = [(-0.03, 0.004, 0.07), (-0.045, 0.002, 0.02), (-0.07, 0.0, -0.06), (-0.1, 0.0, -0.15), (-0.11, 0.004, -0.19), (-0.112, 0.03, -0.205),
      (-0.112, 0.12, -0.205), (-0.112, 0.18, -0.205), (-0.104, 0.2, -0.205), (-0.08, 0.205, -0.205), (0.0, 0.205, -0.205),
      (0.08, 0.205, -0.205), (0.104, 0.2, -0.205), (0.112, 0.18, -0.205), (0.112, 0.12, -0.205), (0.112, 0.03, -0.205),
      (0.11, 0.004, -0.19), (0.1, 0.0, -0.15), (0.07, 0.0, -0.06), (0.045, 0.002, 0.02), (0.03, 0.004, 0.07)]
m.sweep("Body", "paint_fieldgrey", fr, 0.0105, segs=14, smooth_per=5, name="frame_tube")
for sx in (-1.0, 1.0):
    m.lathe("Body", "brass", [(0.0, 0.0), (0.0112, 0.0), (0.0128, 0.006), (0.0118, 0.012), (0.0072, 0.0165), (0.0, 0.0175)],
            center=(sx * 0.03, 0.004, 0.072), axis=(0.0, 0.0, 1.0), segs=20, name="finial")
    for z in (-0.02, -0.1):
        f = (z - 0.02) / (-0.06 - 0.02) if z > -0.06 else (z + 0.06) / (-0.15 + 0.06)
        x = (0.045 + (0.07 - 0.045) * f) if z > -0.06 else (0.07 + (0.1 - 0.07) * f)
        m.sweep("Body", "steel", [(sx * x, -0.006, z), (sx * (x + 0.006), -0.014, z), (sx * (x + 0.012), -0.01, z - 0.002), (sx * (x + 0.011), -0.004, z - 0.003)],
                0.0016, segs=6, smooth_per=4, name="spring_hook")
# the bed-spring strap braced under the bell
m.box("Body", "paint_fieldgrey", (0.21, 0.004, 0.02), (0, -0.002, -0.17), bevel=0.0008, name="brace")
m.rivets("Body", "steel", [((x, 0.0, -0.17), (0, 1, 0)) for x in (-0.09, -0.03, 0.03, 0.09)], r=0.003, name="brace_rivets")
# the rear sight: a notch plate welded to the crossbar
for sx in (-1.0, 1.0):
    m.box("Body", "steel", (0.009, 0.019, 0.004), (sx * 0.0067, 0.2215, -0.2085), bevel=0.0005, name="notch_ear")
m.box("Body", "steel", (0.034, 0.009, 0.004), (0, 0.2155, -0.2085), bevel=0.0005, name="notch_plate")
# the quartermaster's tag riveted to the left rail
TAG = Vector((-0.093, 0.016, -0.11))
m.box("Body", "steel", (0.003, 0.03, 0.07), tuple(TAG), rot=(0, -12, 0), bevel=0.0007, name="qm_tag")
tag_n = Vector((-math.cos(math.radians(12)), 0.0, -math.sin(math.radians(12))))
tag_r = Vector((-math.sin(math.radians(12)), 0.0, math.cos(math.radians(12))))     # reading direction (toward the grip)
m.text("Body", "paint_white", "KAS. II", 0.0085, lambda tx, ty, tz: tuple(TAG + tag_n * (0.0016 + tz) - tag_r * tx + Vector((0, ty + 0.006, 0))), depth=0.0003, name="qm_txt1")
m.text("Body", "paint_white", "BETT 14", 0.0085, lambda tx, ty, tz: tuple(TAG + tag_n * (0.0016 + tz) - tag_r * tx + Vector((0, ty - 0.007, 0))), depth=0.0003, name="qm_txt2")
m.rivets("Body", "steel", [(tuple(TAG + tag_n * 0.0016 + tag_r * dz + Vector((0, 0.0, 0))), tuple(tag_n)) for dz in (-0.029, 0.029)], r=0.0022, name="tag_rivets")

# ------------------------------------------------------------------ the spine (a bed slat), straps, grips
m.prism("Body", "wood_pale", [(0.112, 0.03), (0.08, 0.036), (-0.21, 0.036), (-0.215, 0.031), (-0.215, 0.004), (-0.21, 0.0), (0.06, -0.006),
                              (0.112, 0.0)], -0.021, 0.021, bevel=0.0025, name="slat")
for z in (0.065, -0.02):
    m.box("Body", "steel", (0.052, 0.046, 0.012), (0, 0.015, z), bevel=0.001, name="strap")
    m.bolt_heads("Body", "steel", [((sx * 0.026, 0.015, z), (sx, 0, 0)) for sx in (-1.0, 1.0)], r=0.0045, h=0.003, name="strap_bolt")
m.rivets("Body", "steel", [((0, 0.0365, z), (0, 1, 0)) for z in (0.09, 0.03, -0.06, -0.12, -0.17)], r=0.0024, name="slat_screws")
# rear pistol grip
LEAN = math.radians(15.0)
T = Vector((0.0, 0.0, 0.04))
D = Vector((0.0, -math.cos(LEAN), math.sin(LEAN)))
FWD = Vector((0.0, -math.sin(LEAN), -math.cos(LEAN)))
prof = [(0.0, 0.021, 0.016), (0.02, 0.0225, 0.0168), (0.045, 0.023, 0.017), (0.07, 0.0225, 0.0168), (0.095, 0.021, 0.016), (0.105, 0.019, 0.015)]
m.sweep("Body", "wood_dark", [T + D * p[0] for p in prof], 0.0, radii=[(p[1], p[2]) for p in prof], segs=20, ref=FWD, name="grip")
m.lathe("Body", "brass", [(0.0, -0.002), (0.017, -0.002), (0.0178, 0.003), (0.012, 0.0075), (0.0, 0.0085)], center=tuple(T + D * 0.105), axis=tuple(D),
        segs=20, name="grip_cap")
# front grip (vertical, turned)
m.lathe("Body", "wood_handle", [(0.0, 0.0), (0.017, 0.0), (0.019, -0.01), (0.0195, -0.04), (0.0185, -0.075), (0.0205, -0.088), (0.0205, -0.094),
                                (0.0, -0.096)], center=(0, -0.004, -0.2), axis="y", segs=24, name="fgrip")
m.lathe("Body", "brass", [(0.0172, 0.004), (0.0205, 0.004), (0.0205, -0.006), (0.0172, -0.006)], center=(0, -0.004, -0.2), axis="y", segs=24, cap0=False, cap1=False, name="ferrule")

# ------------------------------------------------------------------ ratchet, mainspring barrel, the crank (Salt Chapel)
m.box("Body", "iron", (0.02, 0.04, 0.05), (0.03, 0.018, -0.05), bevel=0.002, name="axle_block")
teeth = 12
wheel = []
for k in range(teeth * 2):
    a = math.tau * k / (teeth * 2)
    r = 0.0285 if k % 2 == 0 else 0.022
    wheel.append((CR.z + math.cos(a) * r, CR.y + math.sin(a) * r))
m.prism("Body", "steel", wheel, 0.045, 0.055, bevel=0.0006, name="ratchet")
m.cyl("Body", "steel", 0.0075, 0.0075, 0.04, (0.06, CR.y, CR.z), axis="x", segs=16, name="axle")
# the pawl
PV = Vector((0.05, 0.062, -0.022))
m.prism("Pawl", "steel", [(PV.z + 0.004, PV.y + 0.004), (PV.z - 0.004, PV.y + 0.004), (CR.z + 0.004, CR.y + 0.0302), (CR.z + 0.009, CR.y + 0.031),
                          (PV.z + 0.004, PV.y - 0.004)], 0.044, 0.05, bevel=0.0006, name="pawl")
m.cyl("Body", "steel", 0.0032, 0.0032, 0.016, (0.042, PV.y, PV.z), axis="x", segs=12, name="pawl_pin")
m.helix("Body", "steel", 0.006, 0.0008, 0.036, 0.046, 3, center=(0, PV.y, PV.z), axis="x", per_turn=14, segs=5, name="pawl_spring")
# crank: square socket hub, bent wrought arm, turned wooden knob, rope, salt
hub = CR + Vector((0.004, 0, 0))
m.box("Crank", "iron", (0.014, 0.022, 0.022), tuple(hub), bevel=0.0018, name="hub")
arm = [hub + Vector((0.005, 0.006, 0.0)), CR + Vector((0.008, 0.035, 0.008)), CR + Vector((0.008, 0.07, -0.006)), CR + Vector((0.008, 0.11, 0.0))]
m.sweep("Crank", "iron", arm, 0.0, radii=[(0.0055, 0.0042), (0.0048, 0.0038), (0.0044, 0.0036), (0.0042, 0.0036)], segs=10, smooth_per=6,
        ref=(1, 0, 0), name="arm")
m.lathe("Crank", "iron", [(0.0, -0.004), (0.0062, -0.004), (0.0062, 0.004), (0.0, 0.004)], center=tuple(CR + Vector((0.008, 0.11, 0.0))), axis="x",
        segs=16, name="knob_boss")
m.cyl("Crank", "steel", 0.0028, 0.0028, 0.036, tuple(CR + Vector((0.028, 0.11, 0.0))), axis="x", segs=10, name="knob_pin")
m.lathe("Crank", "wood_handle", [(0.0, -0.016), (0.0075, -0.016), (0.0095, -0.011), (0.0085, -0.003), (0.0098, 0.006), (0.011, 0.012), (0.0095, 0.0165),
                                 (0.0, 0.0175)], center=tuple(CR + Vector((0.032, 0.11, 0.0))), axis="x", segs=20, name="knob")
for i in range(5):
    y = 0.045 + i * 0.0045
    loop = []
    for j in range(16):
        a = math.tau * j / 16
        loop.append(CR + Vector((0.008 + math.cos(a) * 0.0068, y + math.sin(a) * 0.0011 * (1 if j % 2 else -1) + (j / 16) * 0.004, math.sin(a) * 0.0068)))
    m.sweep("Crank", "rope", loop, 0.0021, segs=6, closed=True, name="rope_wrap")
tail = [CR + Vector((0.014, 0.05, 0.004)), CR + Vector((0.022, 0.038, 0.012)), CR + Vector((0.026, 0.022, 0.016)), CR + Vector((0.027, 0.012, 0.014))]
m.sweep("Crank", "rope", tail, 0.0, radii=[0.0022, 0.0021, 0.002, 0.0016], segs=6, smooth_per=4, name="rope_tail")
for j in range(5):
    a = math.tau * j / 5
    end = CR + Vector((0.027, 0.012, 0.014))
    m.sweep("Crank", "rope", [end, end + Vector((math.cos(a) * 0.003, -0.008 - 0.002 * (j % 2), math.sin(a) * 0.003))], 0.0006, segs=4, name="rope_fray")
rng = m.rng
salt = []
for k in range(14):
    p = hub + Vector((0.0075, (rng.random() - 0.5) * 0.02, (rng.random() - 0.5) * 0.02))
    s = 0.0012 + rng.random() * 0.0016
    m.box("Crank", "salt", (s, s, s), tuple(p), rot=(rng.random() * 90, rng.random() * 90, rng.random() * 90), bevel=0.0, name="salt")

# ------------------------------------------------------------------ the striker hammer (left side) and its torsion spring
HP = Vector((-0.106, 0.075, -0.212))
HEAD = Vector((-0.142, 0.075, -0.392))
m.box("Body", "steel", (0.012, 0.016, 0.022), (-0.108, 0.075, -0.205), bevel=0.0012, name="hammer_bracket")
m.sweep("Hammer", "steel", [HP, HP.lerp(HEAD, 0.5) + Vector((-0.012, 0.0, 0.0)), HEAD + Vector((0.004, 0, 0.012))], 0.0, radii=[(0.0055, 0.0035), (0.005, 0.0032), (0.0045, 0.003)],
        segs=8, smooth_per=5, ref=(0, 1, 0), name="hammer_arm")
m.lathe("Hammer", "steel", [(0.0, -0.022), (0.0105, -0.022), (0.0125, -0.018), (0.0125, 0.012), (0.011, 0.0175), (0.0, 0.0185)], center=tuple(HEAD + Vector((0.0, 0.0, 0.0))),
        axis=(1.0, 0.0, 0.0), segs=20, name="hammer_head")
m.cyl("Hammer", "steel", 0.0042, 0.0042, 0.03, tuple(HP), axis="y", segs=12, name="hammer_pivot")
m.helix("Body", "steel", 0.0085, 0.0011, -0.013, 0.013, 4, center=tuple(HP), axis="y", per_turn=14, segs=5, name="torsion")

# ------------------------------------------------------------------ the front sight: a clamp on the lip carrying a brass bead
m.box("Bell", "steel", (0.016, 0.008, 0.016), (0, BY + 0.149, -0.455), bevel=0.0008, name="bead_clamp")
m.cyl("Bell", "steel", 0.0016, 0.0016, 0.012, (0, BY + 0.157, -0.452), axis="y", segs=10, name="bead_post")
m.lathe("Bell", "brass", [(0.0, -0.0026), (0.0019, -0.0021), (0.0026, -0.0007), (0.0026, 0.0007), (0.0019, 0.0021), (0.0, 0.0026)], center=(0, 0.2262, -0.452),
        axis="y", segs=14, name="bead")
m.bolt_heads("Bell", "steel", [((sx * 0.0085, BY + 0.149, -0.455), (sx, 0, 0)) for sx in (-1.0, 1.0)], r=0.0028, h=0.002, name="clamp_screws")

m.crucible_parts = ["Runes"]
m.finish(A["out"] or os.path.join(W.HERE, "..", "..", "..", "assets", "ours", "wonder", "totenglocke"), turntable=A["turntable"], fast=A["fast"],
         extra_report={"markers": {"Muzzle": [0, BY, -0.47], "SightPoint": [0, SIGHT_Y, -0.205], "FrontSight": [0, SIGHT_Y, -0.452],
                                   "LeftHand": [0, -0.045, -0.2], "grip_r": [0, -0.045, 0.055], "Crank": list(CR), "Hammer": list(HP), "Pawl": list(PV)}})
