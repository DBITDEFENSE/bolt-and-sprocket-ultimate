"""GRAVELIGHT ONE's cabin and cockpit, ours in both versions (UPDATE 12 section 5.2 items 4-5, DECISIONS T-211).

In gen_map00's WRECK frame (the nose toward -Z, the cabin floor's top at WRECK_FLOOR 0.2, the walls' inner faces at
x +-1.15, the roof's underside at 2.35, the cockpit bulkhead z -4.9..-4.65 with its doorway x -0.5..0.5 choked to
1.15, the aft bulkhead at z 5.3), so nothing drawn stands where the map's hull colliders don't, and the openings
(gen_map00 WRECK_OPENINGS) are left open. The paratroop seats fold up against the walls (a folded seat is 0.1 m off
the wall: nothing in the walkway the colliders don't have); the crash throws a few loose. The navigator's table and
the radio sit forward on the port wall. The cockpit: two seats (Selwyn's exactly as LandscapeProps.pinned_cockpit
drew it: TrappedPilot's seated pose sits on it at gen_map00 WRECK_PILOT_SEAT), the instrument panel with its dials,
the glareshield, the columns and yokes, the throttle quadrant, the rudder pedals, the side consoles; crashed: the
panel driven down across Selwyn's knees and the nose frame crushed in on his side, his column bent, the co-pilot's
seat torn loose, and the co-pilot himself, who died, laid on the floor beside Selwyn under a parachute's silk,
only his boots showing: covered, never gore (the respect rules, UPDATE 11 section 8).
"""
import math

from mathutils import Matrix, Vector

import c47_lib as L

FLOOR = 0.2
WALL = 1.15
ROOF = 2.35
BULK_Z = -4.9
AFT_Z = 5.3
NOSE_WALL = -6.9
OPENINGS = [(1, 2.2, 4.0, FLOOR, ROOF), (1, -4.3, -2.45, FLOOR, ROOF), (1, -6.5, -5.1, 1.4, 2.25), (-1, -6.5, -5.1, 1.4, 2.25)]
PILOT_SEAT = Vector((-0.35, FLOOR, -5.75))
CELLS = {}   # set by build_c47 (the decal atlas' cells) through set_cells()


def set_cells(c):
    CELLS.update(c)


def _open_at(side, y, z):
    for o in OPENINGS:
        if o[0] == side and o[1] - 0.02 <= z <= o[2] + 0.02 and o[3] - 0.02 <= y <= o[4] + 0.02:
            return True
    return False


# the lining's section: up the wall, the shoulder, the roof (starboard half; mirrored)
LINING = [(WALL, FLOOR), (WALL, 0.7), (WALL, 1.2), (WALL, 1.6), (1.08, 1.92), (0.9, 2.17), (0.55, 2.31), (0.0, ROOF)]


def lining(g, crashed):
    """The bare skin's inside (zinc-chromate green-grey) from the cockpit's front to the aft bulkhead, in 0.25 m
    bays, the openings left out; the frames (ribs) every 0.5 m and the stringers over it."""
    z = NOSE_WALL
    bay = 0.25
    while z < AFT_Z - 1e-6:
        z1 = min(z + bay, AFT_Z)
        zc = (z + z1) * 0.5
        for side in (-1, 1):
            for (a, b) in zip(LINING, LINING[1:]):
                ya, yb = a[1], b[1]
                if _open_at(side, (ya + yb) * 0.5, zc):
                    continue
                pts = [(side * a[0], ya, z), (side * b[0], yb, z), (side * b[0], yb, z1), (side * a[0], ya, z1)]
                if side < 0:
                    pts = list(reversed(pts))
                L.quad(g, pts, "c47_int", color=(0, 0.25, 0, 1))
        z = z1
    # the frames: a flanged rib following the section every 0.5 m (broken at the openings)
    zf = -4.4
    while zf < AFT_Z - 0.1:
        for side in (-1, 1):
            pts = []
            for (x, y) in LINING[1:]:
                if _open_at(side, y, zf):
                    if len(pts) > 1:
                        L.tube(g, pts, 0.028, "c47_int", 4, color=(0, 0.35, 0, 1))
                    pts = []
                    continue
                pts.append((side * (x - 0.04), y if y < ROOF else ROOF - 0.04, zf))
            if len(pts) > 1:
                L.tube(g, pts, 0.028, "c47_int", 4, color=(0, 0.35, 0, 1))
        zf += 0.5
    # stringers along the walls and the roof
    for side in (-1, 1):
        for y in (0.75, 1.25, 1.85):
            x = WALL - 0.03 if y < 1.7 else 1.0
            segs = []
            zz = NOSE_WALL + 2.1
            cur = None
            while zz <= AFT_Z:
                if not _open_at(side, y, zz):
                    cur = cur or zz
                else:
                    if cur is not None and zz - cur > 0.3:
                        segs.append((cur, zz - 0.05))
                    cur = None
                zz += 0.05
            if cur is not None:
                segs.append((cur, AFT_Z - 0.05))
            for (za, zb) in segs:
                L.box(g, (side * x - 0.015, y - 0.015, za), (side * x + 0.015, y + 0.015, zb), "c47_metal", color=(0, 0.4, 0, 1))
    for x in (-0.35, 0.35):
        L.box(g, (x - 0.015, ROOF - 0.035, NOSE_WALL + 2.1), (x + 0.015, ROOF - 0.005, AFT_Z - 0.05), "c47_metal", color=(0, 0.4, 0, 1))


def floor(g, crashed):
    L.box(g, (-WALL, FLOOR - 0.04, NOSE_WALL), (WALL, FLOOR, AFT_Z), "lib_floorboards", color=(0, 0.45, 0, 1))
    # the aluminium strips and tie-down rings
    for x in (-0.62, 0.0, 0.62):
        L.box(g, (x - 0.03, FLOOR, BULK_Z + 0.3), (x + 0.03, FLOOR + 0.006, AFT_Z - 0.1), "c47_metal", color=(0, 0.5, 0, 1))
    for z in (-3.6, -2.2, -0.8, 0.6, 2.0, 3.4, 4.8):
        for x in (-0.62, 0.62):
            L.cyl(g, (x, FLOOR + 0.012, z), 0.04, 0.02, "mats_steel", segs=8, color=(0, 0.3, 0, 1))
    _stencil(g, "max_load", (0.0, FLOOR + 0.004, 4.6), (0, 1, 0), (0, 0, -1), (0.9, 0.07))


def _stencil(g, cell, center, normal, up, size, m="c47_decal"):
    if cell not in CELLS:
        return
    n = Vector(normal).normalized()
    u = Vector(up)
    u = (u - n * u.dot(n)).normalized()
    r = u.cross(n).normalized()
    c = Vector(center) + n * 0.004
    w, h = size
    u0, v0, u1, v1 = CELLS[cell]
    pts = [c - r * w * 0.5 - u * h * 0.5, c + r * w * 0.5 - u * h * 0.5, c + r * w * 0.5 + u * h * 0.5, c - r * w * 0.5 + u * h * 0.5]
    uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
    L.quad(g, pts, m, uvs)


def bucket_seats(g, crashed, rnd):
    """Paratroop bucket seats in benches of four along both walls; folded up against the wall (crashed: the most
    of them, three benches' worth thrown loose); deployed in the intact aircraft."""
    runs = {-1: [(-3.25, 3.3)], 1: [(-2.3, 2.05), (4.1, 5.15)]} if crashed else {-1: [(-3.25, 3.3)], 1: [(-4.3, 5.15)]}
    pitch = 0.46
    loose = 0
    for side, rr in runs.items():
        for (za, zb) in rr:
            z = za
            k = 0
            while z + 0.42 <= zb:
                torn = crashed and loose < 4 and rnd.random() < 0.18
                if torn:
                    loose += 1
                    # thrown loose: on the floor near the wall, tipped
                    c = Vector((side * rnd.uniform(0.45, 0.75), FLOOR + 0.12, z + 0.2))
                    L.obox(g, c, (0.4, 0.06, 0.38), "c47_metal", (rnd.uniform(-20, 20), rnd.uniform(0, 180), rnd.uniform(40, 75) * side), color=(0.1, 0.4, 0, 1))
                    L.obox(g, c + Vector((0, 0.15, 0)), (0.42, 0.04, 0.3), "lib_canvas", (rnd.uniform(-30, 30), rnd.uniform(0, 180), rnd.uniform(40, 80)), color=(0, 0.4, 0, 1))
                elif crashed or side == 0:
                    # folded up: the pan against the wall, its webbing back behind it
                    L.obox(g, (side * (WALL - 0.07), 0.66, z + 0.21), (0.04, 0.4, 0.4), "c47_metal", (0, 0, side * 4.0), color=(0, 0.3, 0, 1))
                    L.obox(g, (side * (WALL - 0.03), 0.95, z + 0.21), (0.02, 0.55, 0.38), "lib_canvas", color=(0, 0.35, 0, 1))
                else:
                    # deployed: the bucket, the front rail, the leg, the webbing back
                    L.obox(g, (side * (WALL - 0.21), 0.58, z + 0.21), (0.38, 0.05, 0.4), "c47_metal", (0, 0, -side * 6.0))
                    L.obox(g, (side * (WALL - 0.21), 0.545, z + 0.21), (0.3, 0.03, 0.3), "mats_steel", (0, 0, -side * 6.0))
                    L.strut(g, (side * (WALL - 0.39), 0.56, z + 0.21), (side * (WALL - 0.3), FLOOR, z + 0.21), 0.025, "mats_steel")
                    L.obox(g, (side * (WALL - 0.03), 0.95, z + 0.21), (0.02, 0.55, 0.38), "lib_canvas")
                z += pitch
                k += 1
            # the bench's rail along the wall
            L.box(g, (side * (WALL - 0.05) - 0.015, 0.47, za), (side * (WALL - 0.05) + 0.015, 0.5, zb), "mats_steel", color=(0, 0.3, 0, 1))


def static_line(g, crashed, rnd):
    x, y = 0.6, 2.2
    for z in (-4.3, -2.0, 0.3, 2.6, 4.9):
        L.box(g, (x - 0.03, y, z - 0.04), (x + 0.03, ROOF, z + 0.04), "mats_steel")
    if not crashed:
        L.tube(g, [(x, y, -4.4), (x, y, 5.1)], 0.008, "mats_steel", 5)
    else:
        # snapped at a bracket: the aft run hangs down to the floor
        L.tube(g, [(x, y, -4.4), (x, y, 1.0)], 0.008, "mats_steel", 5)
        L.tube(g, [(x, y, 2.6), (x - 0.05, 1.6, 2.15), (x - 0.15, 0.8, 1.8), (x - 0.25, FLOOR + 0.02, 1.6), (x - 0.4, FLOOR + 0.01, 1.1)], 0.008, "mats_steel", 5)
        L.tube(g, [(x, y, 2.6), (x, y, 5.1)], 0.008, "mats_steel", 5)
    _stencil(g, "static_line", (WALL - 0.002, 1.95, -1.0), (-1, 0, 0), (0, 1, 0), (1.1, 0.085))


def cargo(g, crashed, rnd):
    """The supply crates by the port cargo door, lashed (crashed: one strap gone, the top crate slid), their
    stencils; a strap across the floor; the first-aid box and the oxygen bottle on the walls."""
    base = Vector((-0.8, FLOOR, 4.75))
    for k, (dx, dz, s, yaw) in enumerate(((0.0, 0.0, 0.62, 2.0), (0.05, 0.0, 0.5, -4.0))):
        y0 = FLOOR + (0.0 if k == 0 else 0.62)
        c = base + Vector((dx, 0, dz))
        if crashed and k == 1:
            c += Vector((0.12, 0, -0.18))
            yaw = 17.0
        L.obox(g, (c.x, y0 + s * 0.5, c.z), (s, s, s), "lib_floorboards", (0, yaw, 0), color=(0.0, 0.5, 0, 1))
        _stencil(g, "crate_a" if k == 0 else "crate_b", (c.x + s * 0.5 + 0.002, y0 + s * 0.55, c.z), (1, 0, 0), (0, 1, 0), (s * 0.9, 0.07))
    # the lashing straps over them, to the floor rings
    L.box(g, (-1.12, FLOOR, 4.95), (-0.48, 1.13, 5.0), "lib_canvas")
    if not crashed:
        L.box(g, (-1.12, FLOOR, 4.55), (-0.48, 1.13, 4.6), "lib_canvas")
    else:
        L.tube(g, [(-0.5, 1.0, 4.55), (-0.35, 0.6, 4.4), (-0.3, FLOOR + 0.02, 4.1)], 0.02, "lib_canvas", 4)
    # a cargo strap across the floor further forward
    L.box(g, (-0.62, FLOOR + 0.002, -0.62), (0.62, FLOOR + 0.008, -0.56), "lib_canvas")
    _stencil(g, "door", (-WALL + 0.004, 1.45, 4.5), (1, 0, 0), (0, 1, 0), (1.0, 0.08))
    # the first-aid box and the oxygen bottle
    L.box(g, (WALL - 0.12, 1.3, -1.45), (WALL, 1.6, -1.1), "c47_od", color=(0, 0.3, 0, 1))
    _stencil(g, "first_aid", (WALL - 0.122, 1.45, -1.275), (-1, 0, 0), (0, 1, 0), (0.33, 0.04))
    L.cyl(g, (-WALL + 0.12, 1.1, -0.35), 0.1, 0.7, "c47_yellow", segs=10, color=(0, 0.3, 0, 1))
    _stencil(g, "oxygen", (-WALL + 0.225, 1.15, -0.35), (1, 0, 0), (0, 1, 0), (0.2, 0.035))
    _stencil(g, "no_smoking", (0.0, 2.02, BULK_Z + 0.252), (0, 0, 1), (0, 1, 0), (0.7, 0.06))
    _stencil(g, "exit", (-WALL + 0.004, 1.85, -1.8), (1, 0, 0), (0, 1, 0), (0.85, 0.07))


def nav_and_radio(g, crashed):
    """Forward on the port wall: the radio operator's rack against the bulkhead, the navigator's table aft of it with
    its chart, lamp and fold-down stool."""
    L.box(g, (-WALL, FLOOR, BULK_Z + 0.26), (-0.72, 1.55, BULK_Z + 0.72), "c47_black", color=(0.05, 0.5, 0, 1))
    for k in range(4):
        y = 0.45 + k * 0.28
        L.box(g, (-0.73, y, BULK_Z + 0.3), (-0.71, y + 0.22, BULK_Z + 0.68), "c47_od", color=(0, 0.4, 0, 1))
        for d in range(3):
            L.cyl(g, (-0.705, y + 0.11, BULK_Z + 0.38 + d * 0.12), 0.025, 0.02, "mats_steel", axis="x", segs=8)
    _stencil(g, "radio", (-0.705, 1.47, BULK_Z + 0.49), (1, 0, 0), (0, 1, 0), (0.42, 0.04))
    tz0, tz1 = BULK_Z + 0.85, BULK_Z + 1.7
    L.box(g, (-WALL, 0.74, tz0), (-0.7, 0.78, tz1), "lib_floorboards", color=(0, 0.4, 0, 1))
    L.strut(g, (-0.74, 0.74, tz0 + 0.1), (-1.1, FLOOR, tz0 + 0.1), 0.03, "mats_steel")
    L.strut(g, (-0.74, 0.74, tz1 - 0.1), (-1.1, FLOOR, tz1 - 0.1), 0.03, "mats_steel")
    L.obox(g, (-0.92, 0.785, (tz0 + tz1) * 0.5), (0.36, 0.004, 0.5), "mats_paper", (0, 8, 0))
    L.tube(g, [(-1.12, 1.3, tz0 + 0.2), (-0.95, 1.35, tz0 + 0.25), (-0.92, 1.2, tz0 + 0.3)], 0.012, "mats_steel", 5)
    L.cyl(g, (-0.92, 1.17, tz0 + 0.3), 0.06, 0.08, "c47_od", segs=8, r2=0.03)
    if crashed:
        # charts and a logbook thrown on the floor
        for k in range(4):
            L.obox(g, (-0.4 + k * 0.17, FLOOR + 0.004 + k * 0.001, BULK_Z + 1.1 + k * 0.3), (0.3, 0.003, 0.22), "mats_paper", (0, 20 + 37 * k, 0))


def bulkheads(g, crashed):
    """The cockpit bulkhead (doorway x -0.5..0.5 to 2.05; crashed: choked with wreckage to 1.15 over the collider)
    and the aft bulkhead with its door."""
    bz0, bz1 = BULK_Z, BULK_Z + 0.25
    L.box(g, (-WALL, FLOOR, bz0), (-0.5, ROOF, bz1), "c47_int", color=(0, 0.35, 0, 1))
    L.box(g, (0.5, FLOOR, bz0), (WALL, ROOF, bz1), "c47_int", color=(0, 0.35, 0, 1))
    L.box(g, (-0.5, 2.05, bz0), (0.5, ROOF, bz1), "c47_int", color=(0, 0.35, 0, 1))
    for x in (-0.53, 0.53):
        L.box(g, (x - 0.03, FLOOR, bz1 - 0.01), (x + 0.03, 2.08, bz1 + 0.02), "c47_metal")
    if crashed:
        # the choke (the collider CockpitChoke: x -0.5..0.5, z -5.25..-4.65, to 1.15): the door torn off its hinges
        # and jammed, the radio rack fallen across, a seat frame, crumpled skin
        L.obox(g, (-0.05, 0.62, bz1 - 0.08), (0.95, 0.85, 0.05), "c47_int", (-22, 8, 11), color=(0.2, 0.6, 0, 1))
        L.obox(g, (0.2, 0.78, bz0 - 0.15), (0.48, 0.55, 0.32), "c47_black", (12, -20, 33), color=(0.1, 0.5, 0, 1))
        L.obox(g, (-0.25, 0.98, bz0 - 0.05), (0.7, 0.07, 0.42), "c47_metal", (0, 0, -16), color=(0.3, 0.6, 0, 1))
        L.obox(g, (-0.2, 0.42, bz0 - 0.2), (0.6, 0.45, 0.3), "c47_int", (25, 30, -10), color=(0.3, 0.6, 0, 1))
        for k in range(5):
            L.tube(g, [(-0.4 + k * 0.2, 0.3, bz0 - 0.3), (-0.35 + k * 0.18, 0.75 + 0.06 * k, bz0 - 0.1), (-0.3 + k * 0.17, 1.1, bz0 + 0.05)], 0.012,
                   "lib_canvas" if k % 2 else "mats_steel", 4)
    else:
        L.box(g, (-0.5, FLOOR, bz1 - 0.04), (-0.46, 2.05, bz1), "c47_int")
    L.box(g, (-WALL, FLOOR, AFT_Z - 0.05), (WALL, ROOF, AFT_Z), "c47_int", color=(0, 0.35, 0, 1))
    L.box(g, (-0.35, FLOOR + 0.05, AFT_Z - 0.07), (0.35, 1.85, AFT_Z - 0.05), "c47_od", color=(0.05, 0.4, 0, 1))
    L.cyl(g, (0.25, 1.0, AFT_Z - 0.09), 0.03, 0.06, "mats_steel", axis="z", segs=8)


def cabin_windows(g, crashed, rnd):
    """The windows from inside: the frames, glass (intact) or frosted / broken out (crashed)."""
    zs = {-1: [-3.7, -2.75, -1.8, -0.85, 0.1, 1.05, 2.0, 2.95], 1: [-3.7, -2.75, -1.8, -0.85, 0.1, 1.05, 2.0, 2.95, 4.6]}
    for side, zl in zs.items():
        for z in zl:
            if _open_at(side, 1.45, z):
                continue
            x = side * (WALL - 0.005)
            L.box(g, (x - 0.02, 1.2, z - 0.24), (x + 0.02, 1.7, z + 0.24), "c47_metal", color=(0, 0.3, 0, 1))
            inner = side * (WALL - 0.03)
            broken = crashed and rnd.random() < 0.3
            pts = [(inner, 1.26, z - 0.19), (inner, 1.26, z + 0.19), (inner, 1.64, z + 0.19), (inner, 1.64, z - 0.19)]
            if side > 0:
                pts = list(reversed(pts))
            L.quad(g, pts, "c47_black" if broken else "c47_glass")
            if crashed and not broken and "frost" in CELLS:
                u0, v0, u1, v1 = CELLS["frost"]
                fp = [(inner - side * 0.006, p[1], p[2]) for p in pts]
                L.quad(g, fp, "c47_frost", [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)])


def cockpit(g, crashed, rnd):
    """The flight deck between the nose wall (z -6.9) and the bulkhead (z -4.9)."""
    c = PILOT_SEAT
    # Selwyn's seat, exactly as LandscapeProps.pinned_cockpit drew it (TrappedPilot's seated pose sits on it)
    L.box(g, c + Vector((-0.27, 0.38, -0.24)), c + Vector((0.27, 0.46, 0.26)), "c47_metal", color=(0.15, 0.6, 0, 1))
    L.obox(g, c + Vector((0, 0.82, 0.3)), (0.54, 0.78, 0.07), "c47_od", (-10, 0, 0), color=(0.1, 0.5, 0, 1))
    L.obox(g, c + Vector((0, 0.95, 0.26)), (0.42, 0.4, 0.04), "lib_leather", (-10, 0, 0))
    for lx in (-0.22, 0.22):
        L.box(g, c + Vector((lx - 0.03, 0.0, -0.2)), c + Vector((lx + 0.03, 0.38, 0.2)), "mats_steel")
    co = Vector((0.4, FLOOR, -5.75))
    if not crashed:
        L.box(g, co + Vector((-0.27, 0.38, -0.24)), co + Vector((0.27, 0.46, 0.26)), "c47_metal")
        L.obox(g, co + Vector((0, 0.82, 0.3)), (0.54, 0.78, 0.07), "c47_od", (-10, 0, 0))
        L.obox(g, co + Vector((0, 0.95, 0.26)), (0.42, 0.4, 0.04), "lib_leather", (-10, 0, 0))
        for lx in (-0.22, 0.22):
            L.box(g, co + Vector((lx - 0.03, 0.0, -0.2)), co + Vector((lx + 0.03, 0.38, 0.2)), "mats_steel")
    else:
        # the co-pilot's seat torn off its rails, on its side against the bulkhead
        L.obox(g, (0.85, 0.45, -5.1), (0.52, 0.08, 0.5), "c47_metal", (0, 25, 72), color=(0.2, 0.6, 0, 1))
        L.obox(g, (0.95, 0.72, -5.05), (0.5, 0.7, 0.07), "c47_od", (15, 25, 70), color=(0.2, 0.6, 0, 1))
    # the panel: upright (intact) or driven down and back across Selwyn's knees (crashed)
    if not crashed:
        pm = Matrix.Translation((0.0, 1.05, -6.68)) @ L.rot_matrix((-8, 0, 0))
    else:
        pm = Matrix.Translation(c + Vector((0.2, 0.78, -0.62))) @ L.rot_matrix((-38, 6, -7))
    L.obox_m(g, pm, (1.6 if not crashed else 1.5, 0.5, 0.1), "c47_black", color=(0.2 if crashed else 0, 0.5, 0, 1))
    for k in range(12):
        col, row = k % 6, k // 6
        loc = Vector((-0.62 + col * 0.25, 0.09 - row * 0.2, 0.052))
        u0, v0, u1, v1 = CELLS.get("dial_%d" % k, [0, 0, 1, 1])
        pts = [pm @ (loc + Vector(o)) for o in ((-0.08, -0.08, 0), (0.08, -0.08, 0), (0.08, 0.08, 0), (-0.08, 0.08, 0))]
        L.quad(g, pts, "c47_decal", [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)])
    # the glareshield over it (intact) / folded down onto it (crashed)
    if not crashed:
        L.obox(g, (0.0, 1.33, -6.62), (1.7, 0.05, 0.32), "c47_black")
    else:
        L.obox(g, c + Vector((0.25, 1.02, -0.78)), (1.5, 0.05, 0.3), "c47_black", (-55, 6, -9), color=(0.3, 0.6, 0, 1))
    # wiring hanging out of the panel's back
    for k in range(4 if crashed else 0):
        L.tube(g, [c + Vector((-0.2 + k * 0.15, 0.6, -0.55)), c + Vector((-0.18 + k * 0.15, 0.4, -0.45)), c + Vector((-0.1 + k * 0.17, 0.12, -0.3))], 0.007,
               "lib_canvas" if k % 2 else "c47_rubber", 4)
    # the columns and the yokes (the C-47's open wheel)
    for sx, bent in ((-0.35, crashed), (0.4, False)):
        base = Vector((sx, FLOOR, -6.25))
        if bent:
            top = c + Vector((0.05, 0.85, -0.45))
            L.tube(g, [base, base + Vector((0.02, 0.35, 0.05)), top], 0.03, "mats_steel", 6)
        elif crashed and sx > 0:
            top = base + Vector((0.15, 0.55, 0.25))   # the co-pilot's column snapped, its wheel on the floor
            L.tube(g, [base, top], 0.03, "mats_steel", 6)
            L.lathe(g, [(0.17, -0.015), (0.19, 0.0), (0.17, 0.015)], "c47_black", (0.6, FLOOR + 0.03, -5.7), 14, (90, 0, 0), caps=(False, False))
            continue
        else:
            top = base + Vector((0.0, 0.85, -0.05))
            L.tube(g, [base, top], 0.03, "mats_steel", 6)
        L.lathe(g, [(0.17, -0.015), (0.19, 0.0), (0.17, 0.015)], "c47_black", top + Vector((0, 0.05, 0.05)), 14, (-10, 0, 0), caps=(False, False))
        L.box(g, top + Vector((-0.17, 0.03, 0.03)), top + Vector((0.17, 0.07, 0.07)), "c47_black")
    # the throttle quadrant: the pedestal between the seats, six levers with their knobs
    L.box(g, (-0.08, FLOOR, -6.45), (0.12, 0.82, -5.95), "c47_black", color=(0.1 if crashed else 0, 0.4, 0, 1))
    _stencil(g, "trim", (0.02, 0.83, -6.2), (0, 1, 0), (0, 0, -1), (0.19, 0.05))
    for k in range(6):
        lx = -0.06 + k * 0.034
        ang = -25 + (k % 2) * 12 + (35 if crashed and k < 2 else 0)
        L.obox(g, (lx, 0.95, -6.22), (0.012, 0.28, 0.012), "mats_steel", (ang, 0, 0))
        L.sphere(g, (lx, 1.08, -6.22 - math.sin(math.radians(ang)) * 0.14), 0.035, "c47_black" if k < 2 else ("mats_red_paint" if k > 3 else "c47_yellow"), 6, 3)
    # the rudder pedals and the side consoles, the trim wheel, the overhead strip, the windscreen's inner frame
    for sx in (-0.35, 0.4):
        for dx in (-0.12, 0.12):
            L.obox(g, (sx + dx, FLOOR + 0.18, -6.62), (0.09, 0.22, 0.04), "mats_steel", (-30, 0, 0))
    for side in (-1, 1):
        L.box(g, (side * WALL - side * 0.22, 0.65, -6.8), (side * WALL, 0.72, -5.2), "c47_black")
    L.cyl(g, (-0.13, 0.55, -5.9), 0.13, 0.04, "c47_black", axis="x", segs=14)
    L.box(g, (-0.4, ROOF - 0.08, -6.6), (0.4, ROOF, -5.5), "c47_black")
    _stencil(g, "placard", (0.0, ROOF - 0.082, -6.0), (0, -1, 0), (0, 0, -1), (0.5, 0.12))
    # the nose wall's inside under the windscreen
    L.box(g, (-WALL, FLOOR, NOSE_WALL - 0.02), (WALL, 1.1, NOSE_WALL), "c47_int", color=(0.1 if crashed else 0, 0.4, 0, 1))
    if crashed:
        _crushed_frame(g, rnd)
        _copilot(g, rnd)


def _crushed_frame(g, rnd):
    """The nose structure driven in on Selwyn's side: the windscreen frame's port post folded down across the panel,
    the side wall buckled in at his knees, a frame member over his legs. His eye line out of the windscreen
    (gen_map00 WRECK_SCREEN) stays clear: nothing over 1.2 m in front of him but the thin posts."""
    c = PILOT_SEAT
    L.tube(g, [(-1.0, 2.2, -6.9), (-0.85, 1.55, -6.5), c + Vector((-0.2, 0.95, -0.55)), c + Vector((0.35, 0.85, -0.35))], 0.035, "c47_metal", 6,
           color=(0.4, 0.6, 0, 1))
    L.tube(g, [(-WALL, 0.7, -6.6), c + Vector((-0.35, 0.72, -0.4)), c + Vector((0.1, 0.66, -0.35))], 0.03, "c47_metal", 6, color=(0.4, 0.6, 0, 1))
    for k in range(3):
        L.obox(g, (-1.0 + 0.05 * k, 0.55 + 0.25 * k, -6.25 + 0.12 * k), (0.12, 0.45, 0.7), "c47_int", (rnd.uniform(-20, 20), rnd.uniform(-15, 15), 25 + 10 * k),
               color=(0.5, 0.6, 0, 1))
    L.obox(g, c + Vector((-0.05, 0.6, -0.3)), (0.7, 0.06, 0.12), "c47_int", (10, 4, -12), color=(0.4, 0.6, 0, 1))


def _copilot(g, rnd):
    """The co-pilot, who died in the crash: laid on the floor beside Selwyn's seat, covered by a parachute's silk from
    his head to his shins (a drape over the body's shape), his flying boots showing toward the pedals. Never close,
    never gore."""
    # the body's shape under the silk, lying along z (head aft by the bulkhead, feet forward)
    x0 = 0.55

    def body_h(x, z):
        h = 0.0
        dx = x - x0
        # head (z -5.12), shoulders and chest (-5.35..-5.85), hips (-6.05), legs to the knees (-6.45)
        parts = [(-5.12, 0.11, 0.11, 0.18), (-5.55, 0.22, 0.28, 0.22), (-5.9, 0.2, 0.2, 0.18), (-6.1, 0.18, 0.15, 0.16), (-6.38, 0.16, 0.18, 0.12)]
        for (zc, rx, rz, hh) in parts:
            d = (dx / rx) ** 2 + ((z - zc) / rz) ** 2
            if d < 1.0:
                h = max(h, hh * math.sqrt(1.0 - d))
        return h
    import bmesh
    tmp = bmesh.new()
    nx, nz = 9, 15
    xs = [x0 - 0.42 + 0.84 * i / (nx - 1) for i in range(nx)]
    zs = [-6.55 + 1.55 * j / (nz - 1) for j in range(nz)]
    vs = {}
    for i, x in enumerate(xs):
        for j, z in enumerate(zs):
            h = 0.0
            for (ox, oz) in ((0, 0), (0.06, 0), (-0.06, 0), (0, 0.06), (0, -0.06)):
                h = max(h, body_h(x + ox, z + oz))
            edge = min(i, nx - 1 - i)
            h = max(h * (1.0 if edge > 1 else 0.6), 0.0) + 0.012 + (0.01 * math.sin(i * 1.7 + j * 0.9))
            vs[(i, j)] = tmp.verts.new((x, FLOOR + h, z))
    for i in range(nx - 1):
        for j in range(nz - 1):
            tmp.faces.new((vs[(i, j)], vs[(i, j + 1)], vs[(i + 1, j + 1)], vs[(i + 1, j)]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    for f in tmp.faces:
        if f.normal.y < 0:
            f.normal_flip()
    g.add(tmp, "linen_chute", True, color=(0, 0.25, 0, 1))
    # the flying boots past the silk's edge, toes up
    for dx in (-0.09, 0.09):
        L.obox(g, (x0 + dx, FLOOR + 0.07, -6.62), (0.11, 0.14, 0.2), "lib_leather", (8, 0, dx * 40), color=(0, 0.4, 0, 1))
        L.obox(g, (x0 + dx, FLOOR + 0.16, -6.7), (0.1, 0.12, 0.08), "lib_leather", (-10, 0, 0), color=(0, 0.4, 0, 1))
    # his leather helmet, set on the silk over his chest by whoever covered him
    L.sphere(g, (x0 + 0.05, FLOOR + 0.3, -5.6), (0.18, 0.1, 0.2), "lib_leather", 8, 4)


def debris(g, rnd):
    """The crash's mess in the cabin: the parachute pack, a helmet, a canteen, broken glass, snow blown in at the
    openings, a blanket."""
    L.obox(g, (0.35, FLOOR + 0.1, -1.6), (0.38, 0.2, 0.42), "mats_olive_drab", (0, 28, 0), color=(0, 0.4, 0, 1))
    _stencil(g, "chute", (0.35, FLOOR + 0.205, -1.6), (0, 1, 0), (0, 0, -1), (0.34, 0.035))
    L.sphere(g, (-0.5, FLOOR + 0.09, 0.9), (0.27, 0.16, 0.3), "mats_olive_drab", 10, 5)
    L.cyl(g, (0.45, FLOOR + 0.06, 2.6), 0.07, 0.18, "c47_od", axis="x", segs=10)
    L.obox(g, (-0.3, FLOOR + 0.02, -0.4), (0.9, 0.03, 0.6), "lib_wool", (0, 37, 4), color=(0, 0.5, 0, 1))
    for k in range(16):
        L.obox(g, (rnd.uniform(-0.8, 0.8), FLOOR + 0.004, rnd.uniform(-4.4, 5.0)), (rnd.uniform(0.02, 0.07), 0.004, rnd.uniform(0.02, 0.06)),
               "c47_glass", (0, rnd.uniform(0, 180), 0))
    # snow blown in at the torn hole and the split, in drifts against the floor's far side
    for (z0, z1) in ((-4.3, -2.45), (2.2, 4.0)):
        for k in range(7):
            z = rnd.uniform(z0 + 0.1, z1 - 0.1)
            L.sphere(g, (rnd.uniform(0.3, 1.0), FLOOR, z), (rnd.uniform(0.35, 0.8), rnd.uniform(0.05, 0.12), rnd.uniform(0.3, 0.7)), "mats_snow", 8, 4,
                     color=(0, 0.1, 1, 1))


def interior(crashed):
    g = L.GMesh("Interior")
    rnd = L.rng(1912 if crashed else 1944)
    lining(g, crashed)
    floor(g, crashed)
    bulkheads(g, crashed)
    bucket_seats(g, crashed, rnd)
    static_line(g, crashed, rnd)
    cargo(g, crashed, rnd)
    nav_and_radio(g, crashed)
    cabin_windows(g, crashed, rnd)
    cockpit(g, crashed, rnd)
    if crashed:
        debris(g, rnd)
    return g
