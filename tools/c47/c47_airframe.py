"""GRAVELIGHT ONE's stand-in airframe: a low-poly C-47 / Dakota built from known dimensions (UPDATE 12 section 5,
DECISIONS T-211). Our own work (CC0-compatible, "Ours"): no third-party mesh or reference scan, only the published
figures (span 29.0 m, length 19.4-19.6 m, height 5.2 m, wing area 91.7 m2, 3.5 m propellers) and the DC-3 planform.

The frame is the WRECK frame of gravelight/tools_src/gen_map00.gd (Godot axes, the nose toward -Z, +X starboard),
so the stand-in's cabin fits the map's hull colliders exactly: the fuselage's cross-section is gen_map00's
WRECK_RING (half-width 1.44, keel -0.22, roof 2.75; the cabin floor 0.2), the cockpit's front wall at z -7.2, the
aft bulkhead at z 5.3. That makes the section ~10 % fuller than the real aircraft's 2.6 m; span and length are true.

airframe() returns (GMesh, info): every face of the exterior in one mesh (the same shape an imported GLB has after
build_c47.normalize_source joins it), and info = the hubs, the exhausts, the lights, the station table.
"""
import math

from mathutils import Matrix, Vector

import c47_lib as L

# gen_map00 WRECK_RING (port over the top and back under), with two points added under the keel
RING = [(1.3, -0.1), (1.42, 0.6), (1.44, 1.3), (1.38, 1.95), (1.12, 2.42), (0.6, 2.68), (0.0, 2.75), (-0.6, 2.68),
        (-1.12, 2.42), (-1.38, 1.95), (-1.44, 1.3), (-1.42, 0.6), (-1.3, -0.1), (-0.75, -0.2), (0.0, -0.22), (0.75, -0.2)]
RING_W = 1.44
RING_YB = -0.22
RING_YT = 2.75
RING_N = 32

# fuselage stations: (z, half-width, keel y, roof y)
STATIONS = [
    (-9.05, 0.04, 0.66, 0.82), (-9.0, 0.3, 0.46, 1.04), (-8.88, 0.58, 0.26, 1.28), (-8.65, 0.86, 0.08, 1.52),
    (-8.35, 1.08, -0.06, 1.76), (-8.0, 1.24, -0.14, 2.0), (-7.65, 1.36, -0.2, 2.4), (-7.2, 1.44, -0.22, 2.72),
    (-6.5, 1.44, -0.22, 2.75), (-5.1, 1.44, -0.22, 2.75), (-4.3, 1.44, -0.22, 2.75), (-3.4, 1.44, -0.22, 2.75),
    (-2.45, 1.44, -0.22, 2.75), (-1.2, 1.44, -0.22, 2.75), (0.0, 1.44, -0.22, 2.75), (1.1, 1.44, -0.22, 2.75),
    (2.2, 1.44, -0.22, 2.75), (3.1, 1.44, -0.22, 2.75), (4.0, 1.44, -0.22, 2.75), (5.3, 1.43, -0.18, 2.75),
    (6.3, 1.39, -0.08, 2.74), (7.0, 1.31, 0.1, 2.72), (7.8, 1.18, 0.32, 2.69), (8.5, 1.05, 0.52, 2.65),
    (9.1, 0.89, 0.75, 2.6), (9.6, 0.73, 0.95, 2.56), (10.0, 0.56, 1.18, 2.5), (10.3, 0.39, 1.45, 2.44),
    (10.5, 0.21, 1.7, 2.36), (10.6, 0.05, 1.95, 2.26),
]

ENGINE_X = 3.55
ENGINE_Y = 0.62
PROP_Z = -4.52
PROP_R = 1.75
WING_Y = 0.18
DIHEDRAL = 5.0
STAB_Y = 1.9

# the wing's span stations (starboard; mirrored): (x, leading edge z, chord, thickness / chord)
WING = [(1.25, -2.45, 4.45, 0.15), (3.9, -2.25, 4.25, 0.145), (6.5, -1.55, 3.5, 0.13), (10.0, -0.6, 2.7, 0.12),
        (13.6, 0.35, 2.0, 0.11), (14.3, 0.72, 1.55, 0.1), (14.5, 1.2, 0.8, 0.07)]
STAB = [(0.4, 8.45, 2.5, 0.1), (2.5, 8.95, 1.95, 0.09), (4.0, 9.6, 1.25, 0.08), (4.25, 10.0, 0.7, 0.06)]
# the fin: (y, leading edge z, chord, thickness / chord)
FIN = [(2.4, 7.1, 3.62, 0.09), (2.9, 8.55, 2.2, 0.1), (3.6, 9.15, 1.65, 0.1), (4.4, 9.5, 1.35, 0.1), (4.95, 9.8, 1.05, 0.1),
       (5.12, 10.12, 0.6, 0.08)]

# a cambered airfoil (x along the chord from the leading edge, y in chord units): upper surface LE -> TE then lower TE -> LE
_AF_U = [(0.0, 0.0), (0.02, 0.035), (0.06, 0.06), (0.15, 0.085), (0.3, 0.095), (0.45, 0.088), (0.6, 0.07), (0.78, 0.042), (1.0, 0.004)]
_AF_L = [(1.0, -0.004), (0.78, -0.02), (0.6, -0.033), (0.45, -0.045), (0.3, -0.052), (0.15, -0.05), (0.06, -0.038), (0.02, -0.022)]
AIRFOIL = _AF_U + _AF_L


def station_at(z):
    """(half-width, keel, roof) at z, linearly between the stations (clamped)."""
    S = STATIONS
    if z <= S[0][0]:
        return S[0][1:]
    for a, b in zip(S, S[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / max(b[0] - a[0], 1e-6)
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return S[-1][1:]


def _ring_norm():
    pts = [Vector((x / RING_W, (y - (RING_YB + RING_YT) * 0.5) / ((RING_YT - RING_YB) * 0.5))) for (x, y) in RING]
    return L.catmull(pts, RING_N, True)


def _fuselage_ring(z, rn):
    w, yb, yt = station_at(z)
    yc = (yb + yt) * 0.5
    hh = (yt - yb) * 0.5
    return [Vector((p.x * w, yc + p.y * hh, z)) for p in rn]


def _paint(c, n, seed=0):
    """Olive drab over neutral grey: the demarcation wanders along the lower sides."""
    wob = (L.vnoise((c.x * 0.3, c.y, c.z * 0.4), 1.6, seed) - 0.5) * 0.25
    return "c47_ng" if n.y < -0.38 + wob else "c47_od"


def fuselage(g):
    rn = _ring_norm()
    zs = sorted({s[0] for s in STATIONS} | {round(-7.2 + 0.5 * k, 3) for k in range(28) if -7.2 + 0.5 * k < 6.3})
    rings = [_fuselage_ring(z, rn) for z in zs]

    def mof(c, n):
        if -8.12 <= c.z <= -7.2 and c.y > 1.5 and abs(c.x) < 0.95:
            return "c47_glass"                      # the windscreen
        if -6.5 <= c.z <= -5.1 and 1.4 <= c.y <= 2.25 and abs(c.x) > 0.9:
            return "c47_glass"                      # the cockpit's side windows
        if -8.72 <= c.z <= -7.9 and 1.0 < c.y < 1.62 and abs(c.x) < 0.75:
            return "c47_black"                      # the anti-glare panel
        return _paint(c, n)
    tmp = L.GMesh("fus")
    L.loft(tmp, rings, mof, closed=True, smooth=True)
    # cut the openings' outlines into the skin so the crash pass (and the glazing) has edges to follow
    bm = tmp.bm
    import bmesh
    for co, no in (((0, 0, -6.5), (0, 0, 1)), ((0, 0, -5.1), (0, 0, 1)), ((0, 1.4, 0), (0, 1, 0)), ((0, 2.25, 0), (0, 1, 0)),
                   ((0, 1.12, 0), (0, 1, 0)), ((0, 1.5, 0), (0, 1, 0)), ((1.0, 0, 0), (1, 0, 0)), ((-1.0, 0, 0), (1, 0, 0)), ((0.95, 0, 0), (1, 0, 0)), ((-0.95, 0, 0), (1, 0, 0)), ((0, 0, -8.12), (0, 0, 1)),
                   ((0, 0.2, 0), (0, 1, 0)), ((0, 2.35, 0), (0, 1, 0)), ((0.9, 0, 0), (1, 0, 0)), ((-0.9, 0, 0), (1, 0, 0))):
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=Vector(co), plane_no=Vector(no))
    g.merge(tmp)


def _airfoil_ring(le, chord, tc, place):
    """A wing section: place(u, v) -> Vector puts chord fraction u and thickness v (metres) in space."""
    return [place(u * chord, v * chord * (tc / 0.12)) for (u, v) in AIRFOIL]


def wings(g):
    for side in (1, -1):
        rings = []
        for (x, le, ch, tc) in WING:
            dy = math.tan(math.radians(DIHEDRAL)) * max(0.0, x - 3.9)
            rings.append(_airfoil_ring(le, ch, tc, lambda u, v, x=x, le=le, dy=dy: Vector((side * x, WING_Y + dy + v, le + u))))
        L.loft(g, rings, lambda c, n: "c47_ng" if n.y < -0.2 else "c47_od", closed=True, smooth=True, cap_end=True)
        # the navigation light in the tip
        tip = WING[-2]
        dyt = math.tan(math.radians(DIHEDRAL)) * (tip[0] - 3.9)
        L.sphere(g, (side * 14.42, WING_Y + dyt, tip[1] + 0.1), (0.12, 0.08, 0.16), "c47_light_green" if side > 0 else "c47_light_red", 8, 4)


def stabilizers(g):
    for side in (1, -1):
        rings = []
        for (x, le, ch, tc) in STAB:
            rings.append(_airfoil_ring(le, ch, tc, lambda u, v, x=x, le=le: Vector((side * x, STAB_Y + v * 0.6, le + u))))
        L.loft(g, rings, lambda c, n: "c47_ng" if n.y < -0.2 else "c47_od", closed=True, smooth=True, cap_end=True)
    rings = []
    for (y, le, ch, tc) in FIN:
        rings.append(_airfoil_ring(le, ch, tc, lambda u, v, y=y, le=le: Vector((v * 0.55, y, le + u))))
    L.loft(g, rings, None, "c47_od", closed=True, smooth=True, cap_end=True)
    L.sphere(g, (0.0, 2.3, 10.62), (0.08, 0.08, 0.1), "c47_light_white", 6, 3)


def nacelles(g, info):
    prof = [(0.0, -4.27), (0.42, -4.27), (0.58, -4.3), (0.68, -4.26), (0.73, -4.1), (0.74, -3.7), (0.72, -3.2), (0.7, -3.05),
            (0.66, -2.95), (0.63, -2.2), (0.6, -1.2), (0.52, -0.3), (0.4, 0.6), (0.24, 1.3), (0.06, 1.62)]
    for side in (1, -1):
        cx = side * ENGINE_X
        L.lathe(g, prof, "c47_od", (cx, ENGINE_Y, 0.0), 22, caps=(False, False))
        # the radial behind the cowl's mouth: two rows of seven cylinders round the crankcase, the nose case, the hub
        L.cyl(g, (cx, ENGINE_Y, -4.2), 0.6, 0.08, "c47_exhaust", axis="z", segs=20)
        for k in range(14):
            a = math.tau * k / 14 + (0.22 if k % 2 else 0.0)
            r = 0.42
            zz = -4.28 if k % 2 == 0 else -4.22
            L.obox(g, (cx + math.cos(a) * r, ENGINE_Y + math.sin(a) * r, zz), (0.13, 0.1, 0.16), "c47_exhaust",
                   (0, 0, math.degrees(a)))
        L.cyl(g, (cx, ENGINE_Y, -4.38), 0.24, 0.22, "c47_ng", axis="z", r2=0.15, segs=14)
        L.sphere(g, (cx, ENGINE_Y, -4.53), (0.3, 0.3, 0.24), "c47_metal", 12, 6)
        # the propeller: three blades, black with yellow tips, at a cruise pitch
        for b in range(3):
            a = math.tau * b / 3 + math.radians(20 * side)
            d = Vector((math.cos(a), math.sin(a), 0.0))
            for (r0, r1, ch0, ch1, m) in ((0.14, PROP_R - 0.13, 0.2, 0.24, "c47_black"), (PROP_R - 0.13, PROP_R, 0.22, 0.12, "c47_yellow")):
                mid = (r0 + r1) * 0.5
                c = Vector((cx, ENGINE_Y, PROP_Z)) + d * mid
                xf = (Matrix.Translation(c) @ Matrix.Rotation(a - math.pi * 0.5, 4, "Z") @ Matrix.Rotation(math.radians(28.0 * side), 4, "Y"))
                L.obox_m(g, xf, ((ch0 + ch1) * 0.5, r1 - r0, 0.04), m)
        # the retracted wheel half out of the nacelle (a belly landing put it in the snow first)
        L.cyl(g, (cx, 0.32, -1.75), 0.6, 0.34, "c47_rubber", axis="x", segs=18)
        L.cyl(g, (cx, 0.32, -1.75), 0.3, 0.36, "c47_ng", axis="x", segs=12)
        # the exhaust stack on the outboard side, under the wing
        ex0 = Vector((cx + side * 0.56, ENGINE_Y - 0.38, -3.0))
        ex1 = Vector((cx + side * 0.66, ENGINE_Y - 0.48, -2.25))
        L.tube(g, [ex0, ex1], 0.075, "c47_exhaust", 8)
        info["exhaust_%s" % ("R" if side > 0 else "L")] = [ex1.x, ex1.y, ex1.z]
        info["hub_%s" % ("R" if side > 0 else "L")] = [cx, ENGINE_Y, PROP_Z]


def details(g, info):
    # the astrodome, the D/F loop's teardrop, the aerial mast, the pitot tubes, the tail wheel
    L.sphere(g, (0.0, 2.72, -4.3), (0.5, 0.36, 0.5), "c47_glass", 12, 6)
    L.sphere(g, (0.0, 2.78, -3.3), (0.2, 0.16, 0.62), "c47_black", 10, 5)
    L.obox(g, (0.0, 2.92, -5.75), (0.05, 0.42, 0.28), "c47_od", (12, 0, 0))
    for sx in (-0.35, 0.35):
        L.tube(g, [(sx, 0.78, -8.5), (sx, 0.74, -9.15)], 0.018, "c47_metal", 6)
    L.cyl(g, (0.0, 1.0, 9.85), 0.26, 0.14, "c47_rubber", axis="x", segs=14)
    L.tube(g, [(0.0, 3.12, -5.72), (0.0, 4.95, 9.95)], 0.004, "c47_black", 4, caps=False)   # the aerial wire to the fin
    # the formation / recognition lights on top and under the fuselage
    L.sphere(g, (0.0, 2.77, 2.2), (0.1, 0.06, 0.1), "c47_light_white", 6, 3)
    L.sphere(g, (0.0, -0.23, 1.0), (0.1, 0.06, 0.1), "c47_light_white", 6, 3)
    info["light_top"] = [0.0, 2.8, 2.2]
    info["light_belly"] = [0.0, -0.26, 1.0]
    info["light_tail"] = [0.0, 2.3, 10.7]
    info["light_L"] = [-14.45, WING_Y + math.tan(math.radians(DIHEDRAL)) * (14.3 - 3.9), 0.82]
    info["light_R"] = [14.45, WING_Y + math.tan(math.radians(DIHEDRAL)) * (14.3 - 3.9), 0.82]


def window_frames(g):
    """The cockpit's side windows' frames (the sliding pane's post) and the windscreen's posts (the intact aircraft;
    the crash pass bends its own)."""
    for side in (-1, 1):
        x = side * 1.45
        L.box(g, (x - 0.03, 1.4, -5.84), (x + 0.03, 2.25, -5.76), "c47_od")
    for fx in (-0.48, 0.0, 0.48):
        L.tube(g, [(fx, 1.55, -8.08), (fx * 1.15, 2.62, -7.25)], 0.03, "c47_od", 5)


def windows(g, tree, intact=True):
    """The cabin's square windows (port and starboard) and the port cargo door's outline: laid on the skin."""
    zs_p = [-3.7, -2.75, -1.8, -0.85, 0.1, 1.05, 2.0, 2.95]
    zs_s = [-3.7, -2.75, -1.8, -0.85, 0.1, 1.05, 2.0, 2.95, 4.6]
    for side, zs in ((-1, zs_p), (1, zs_s)):
        for z in zs:
            n = (side, 0.0, 0.0)
            L.project_decal(g, tree, (side * 1.44, 1.45, z), n, (0, 1, 0), (0.5, 0.48), [0.9922, 0.9922, 1.0, 1.0], "c47_metal", 2, 0.006)
            L.project_decal(g, tree, (side * 1.44, 1.45, z), n, (0, 1, 0), (0.4, 0.38), [0.9922, 0.9922, 1.0, 1.0], "c47_glass", 2, 0.012)
    # the port cargo door (a double door, its outline and handle) aft of the wing
    for (y, z, w, h) in ((2.12, 4.5, 1.95, 0.03), (0.38, 4.5, 1.95, 0.03), (1.25, 3.53, 0.03, 1.77), (1.25, 5.47, 0.03, 1.77), (1.25, 4.62, 0.03, 1.77)):
        L.project_decal(g, tree, (-1.44, y, z), (-1, 0, 0), (0, 1, 0), (w, h), [0.9922, 0.9922, 1.0, 1.0], "c47_black", 2, 0.008)
    L.project_decal(g, tree, (-1.44, 1.2, 4.38), (-1, 0, 0), (0, 1, 0), (0.12, 0.04), [0.9922, 0.9922, 1.0, 1.0], "c47_metal", 1, 0.02)


def markings(g, tree, cells):
    """RAF markings over the olive drab: the C1 roundels on the fuselage, the B roundels on the upper wings, the
    fin flash, the fictional serial KQ913, the letter G, GRAVELIGHT ONE small under the cockpit, NO STEP."""
    for side in (-1, 1):
        n = (side, 0, 0)
        L.project_decal(g, tree, (side * 1.42, 1.35, 6.75), n, (0, 1, 0), (1.3, 1.3), cells["roundel_c1"])
        L.project_decal(g, tree, (side * 1.1, 1.55, 8.15), n, (0, 1, 0), (1.35, 0.45), cells["serial"])
        L.project_decal(g, tree, (side * 1.44, 1.3, 2.75), n, (0, 1, 0), (0.62, 0.62), cells["letter_g"])
        L.project_decal(g, tree, (side * 1.44, 1.06, -6.0), n, (0, 1, 0), (1.2, 0.3), cells["name"])
        L.project_decal(g, tree, (side * 0.12, 3.35, 9.95), n, (0, 1, 0), (0.85, 1.05), cells["fin_flash"])
        wx = side * 10.6
        dy = math.tan(math.radians(DIHEDRAL)) * (wx * side - 3.9)
        L.project_decal(g, tree, (wx, WING_Y + dy + 0.4, 0.75), (0, 1, 0), (0, 0, -1), (1.55, 1.55), cells["roundel_b"])
        L.project_decal(g, tree, (side * 2.4, WING_Y + 0.45, 1.25), (0, 1, 0), (0, 0, -1), (1.1, 0.27), cells["no_step"])


def airframe(cells):
    g = L.GMesh("C47_Source")
    info = {"stations": STATIONS}
    fuselage(g)
    wings(g)
    stabilizers(g)
    nacelles(g, info)
    details(g, info)
    tree = L.bvh(g)
    windows(g, tree)
    window_frames(g)
    markings(g, tree, cells)
    return g, info
