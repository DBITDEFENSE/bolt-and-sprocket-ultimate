"""Type 100 submachine gun (T-248, 2026-11-14): the Japanese 8 mm SMG, 1940 pattern, modelled in-house.

    blender -b --factory-startup -P tools_src/blender/guns/type100.py -- --out assets/ours/weapons/type100 [--turntable png] [--fast]

No free model of the Type 100 exists (FREE_ASSET_LIST, T-087), so it is built here on the wonder weapons' toolkit
(tools_src/blender/wonder/wonder_lib.py: lathes, bevelled boxes and prisms, sweeps, rivets; one smart-UV atlas; Cycles
bakes of AO and curvature driving per-material procedural paint; 2K albedo / normal / ORM; GLB with external PNGs).

What makes the silhouette (real proportions, ~0.88 m overall, 0.23 m barrel):
  - a round receiver tube with a knurled end cap, half-sunk in a one-piece wooden rifle stock (straight wrist, no
    pistol grip, steel buttplate);
  - the PERFORATED barrel jacket: eight rows of four oblong slots cut through it (booleans, real holes), the barrel
    visible inside, a front band carrying the front sight post between two protective ears;
  - the muzzle compensator with two side ports each side;
  - the BAYONET LUG bar under the jacket;
  - the tangent rear sight on the receiver (graduated leaf, notch plate, side wings);
  - the 30-round curved box magazine inserted from the LEFT, horizontal, curving slightly forward and down, in a
    housing on the receiver's left side;
  - the cocking handle in a slot on the right, the ejection port ahead of it; trigger and a strap trigger guard;
    sling swivels on the left (front band, butt); stock screws.

Frame (game frame, metres): barrel along -Z, +Y up, origin at the right hand on the stock's wrist just behind the
trigger guard. Bore axis y = BY. Parts: Body, Mag, Bolt (the cocking handle), Trigger. Markers for model_fit.json are
printed at the end (FIT ...) and written by the parent into data (see the module constants below).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "wonder"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import wonder_lib as W  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

W.REPORTS = os.path.join(HERE, "reports")

# blued steel (the gun), a slightly greyer blue for the stamped magazine, a mid reddish-brown shellacked stock
W.family("blued", W.r_metal, base=(0.045, 0.05, 0.058), tarnish=(0.03, 0.032, 0.037), polish=(0.3, 0.31, 0.33),
         patina=(0.14, 0.075, 0.04), rough=0.42, rough_tarnish=0.55, tarnish_amt=0.5, patina_cav=0.22, patina_patch=0.02,
         rough_patina=0.85, scratch_amt=0.22, polish_amt=0.55)
W.family("blued_mag", W.r_metal, base=(0.05, 0.053, 0.06), tarnish=(0.034, 0.036, 0.04), polish=(0.32, 0.32, 0.34),
         patina=(0.16, 0.08, 0.04), rough=0.46, rough_tarnish=0.56, tarnish_amt=0.55, patina_cav=0.28, patina_patch=0.03,
         rough_patina=0.88, scratch_amt=0.25, polish_amt=0.6)
W.family("wood_jp", W.r_wood, dark=(0.058, 0.026, 0.012), light=(0.155, 0.072, 0.031), worn=(0.26, 0.145, 0.075), rough=0.4)

A = W.args()
m = W.Model("type100", tex=A["tex"] or 2048)

BY = 0.035              # bore axis height
R_RCV = 0.0165          # receiver tube radius
Z_RCV_F = -0.168        # receiver front (jacket starts)
Z_JK_F = -0.3605        # jacket front face
Z_MZ = -0.396           # muzzle
SIGHT_Y = 0.0655        # sight line (notch / post tip)
Z_REAR = -0.074         # rear notch plate
Z_FRONT = -0.350        # front post
MAG_Z = -0.140          # magazine centre along the bore
MAG_Y = BY - 0.003


def weld(ob, dist=1e-6):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


def _cutter_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    m.coll.objects.link(ob)
    return ob


def cutter_box(size, center, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ Matrix.LocRotScale(None, W._euler(rot), Vector(size)), verts=bm.verts)
    return _cutter_obj("cut_box", bm)


def cutter_slot(angle_deg, z, length, width, r0=0.006, r1=0.024, cy=BY, segs=6):
    """A stadium-shaped (oblong) punch through a tube round the bore: `length` along z, `width` across, pointing out
    along the radial direction at `angle_deg` (0 = +x, 90 = up)."""
    bm = bmesh.new()
    a = math.radians(angle_deg)
    rad = Vector((math.cos(a), math.sin(a), 0.0))
    tan = Vector((-math.sin(a), math.cos(a), 0.0))
    hw = width * 0.5
    hl = length * 0.5 - hw
    outline = []
    for k in range(segs + 1):                      # front cap
        t = math.pi * k / segs
        outline.append((-hl - hw * math.sin(t), hw * math.cos(t)))
    for k in range(segs + 1):                      # rear cap
        t = math.pi * k / segs
        outline.append((hl + hw * math.sin(t), -hw * math.cos(t)))
    c = Vector((0.0, cy, z))
    lo = [bm.verts.new(c + rad * r0 + Vector((0, 0, u)) + tan * v) for (u, v) in outline]
    hi = [bm.verts.new(c + rad * r1 + Vector((0, 0, u)) + tan * v) for (u, v) in outline]
    bm.faces.new(lo)
    bm.faces.new(list(reversed(hi)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
    return _cutter_obj("cut_slot", bm)


def cut(ob, cutters, angle=35.0):
    """Boolean-subtracts the cutters from `ob` (EXACT), keeping its bevel / weighted-normal modifiers on top."""
    saved = []
    for md in ob.modifiers:
        d = {}
        for attr in ("width", "segments", "limit_method", "angle_limit", "miter_outer", "harden_normals", "keep_sharp", "weight"):
            if hasattr(md, attr):
                d[attr] = getattr(md, attr)
        saved.append((md.name, md.type, d))
    ob.modifiers.clear()
    coll = bpy.data.collections.new("cutters_" + ob.name)
    m.coll.children.link(coll)
    for c in cutters:
        for uc in list(c.users_collection):
            uc.objects.unlink(c)
        coll.objects.link(c)
    b = ob.modifiers.new("cut", "BOOLEAN")
    b.operation = "DIFFERENCE"
    b.solver = "EXACT"
    b.operand_type = "COLLECTION"
    b.collection = coll
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    for c in cutters:
        bpy.data.objects.remove(c)
    bpy.data.collections.remove(coll)
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(angle))
    for (nm, tp, d) in saved:
        md = ob.modifiers.new(nm, tp)
        for k, v in d.items():
            setattr(md, k, v)
    return ob


# ------------------------------------------------------------------ receiver
rcv = m.lathe("Body", "blued", [(0.0, 0.080), (0.0158, 0.080), (0.0165, 0.078), (R_RCV, -0.150), (0.0176, -0.1515),
                                (0.0176, -0.166), (0.0152, Z_RCV_F), (0.0, Z_RCV_F)], center=(0, BY, 0), segs=40, name="receiver")
# right side: the cocking-handle slot and, ahead of it, the ejection port
cut(rcv, [cutter_box((0.02, 0.0055, 0.094), (0.0165, BY, 0.020)),
          cutter_box((0.02, 0.0115, 0.034), (0.0165, BY + 0.0025, -0.076))])
# the bolt's face showing in the port and the slot (the receiver is solid: a steel body inside the cut)
m.box("Body", "steel", (0.006, 0.0105, 0.033), (0.0102, BY + 0.0025, -0.076), bevel=0.0006, name="boltface")
endcap = m.lathe("Body", "blued", [(0.0, 0.1045), (0.0115, 0.1045), (0.0158, 0.102), (0.0172, 0.098), (0.0172, 0.084),
                                   (0.0166, 0.0815), (0.0166, 0.078), (0.0, 0.078)], center=(0, BY, 0), segs=48, name="endcap")


def _knurl(v):
    d = Vector((v.x, v.y - BY, 0.0))
    r = d.length
    if r > 0.0168 and 0.0845 < v.z < 0.0975:
        a = math.atan2(d.y, d.x)
        k = 1.0 + 0.045 * (0.5 + 0.5 * math.cos(a * 24))
        return Vector((d.x * k, BY + d.y * k, v.z))
    return v


m.deform(endcap, _knurl)

# ------------------------------------------------------------------ barrel, perforated jacket, front band, compensator
m.cyl("Body", "blued", 0.0074, 0.0074, 0.205, (0, BY, -0.262), segs=24, name="barrel")
jacket = weld(m.tube("Body", "blued", 0.0128, 0.0145, Z_RCV_F + 0.002 - (Z_JK_F + 0.006), (0, BY, (Z_RCV_F + 0.002 + Z_JK_F + 0.006) * 0.5),
                     segs=48, bevel=0.0004, name="jacket"))
slots = []
for k in range(8):
    ang = 22.5 + 45.0 * k
    for i in range(4):
        slots.append(cutter_slot(ang, -0.200 - 0.040 * i, 0.026, 0.0066))
cut(jacket, slots)
band = weld(m.lathe("Body", "blued", [(0.0074, Z_JK_F), (0.0163, Z_JK_F), (0.0165, Z_JK_F + 0.002), (0.0165, -0.3415),
                                     (0.0145, -0.3405), (0.0128, -0.3405), (0.0128, -0.3555), (0.0074, -0.3555), (0.0074, Z_JK_F)],
                    center=(0, BY, 0), segs=40, cap0=False, cap1=False, name="band"))
comp = m.lathe("Body", "blued", [(0.0, -0.381), (0.0042, -0.384), (0.0042, Z_MZ), (0.0098, Z_MZ), (0.0108, Z_MZ + 0.002),
                                 (0.0108, -0.3595), (0.0, -0.3595)], center=(0, BY, 0), segs=32, name="compensator")
cut(comp, [cutter_box((0.04, 0.0048, 0.0062), (0, BY, -0.3895)), cutter_box((0.04, 0.0048, 0.0062), (0, BY, -0.3755))])
# collar where the jacket meets the receiver
m.tube("Body", "blued", 0.0140, 0.0172, 0.008, (0, BY, Z_RCV_F - 0.003), segs=40, name="jacket_collar")

# ------------------------------------------------------------------ bayonet lug bar under the jacket
m.box("Body", "blued", (0.0075, 0.009, 0.112), (0, BY - 0.0145 - 0.0038, -0.300), bevel=0.0009, name="bayonet_bar")
m.box("Body", "blued", (0.0052, 0.0068, 0.012), (0, BY - 0.0145 - 0.0105, -0.351), bevel=0.0008, name="bayonet_lug")
m.box("Body", "steel", (0.0084, 0.0034, 0.010), (0, BY - 0.0145 - 0.0012, -0.247), bevel=0.0006, name="bayonet_bar_clamp")

# ------------------------------------------------------------------ front sight: post between two ears on the band
m.box("Body", "blued", (0.0095, 0.0085, 0.017), (0, 0.0541, Z_FRONT), bevel=0.0009, name="fs_base")
m.box("Body", "blued", (0.0021, SIGHT_Y - 0.0583, 0.0038), (0, (SIGHT_Y + 0.0583) * 0.5, Z_FRONT), bevel=0.0003, name="fs_post")
for s in (-1.0, 1.0):
    m.box("Body", "blued", (0.0017, 0.0145, 0.012), (s * 0.0064, 0.0612, Z_FRONT), rot=(0, 0, -s * 7.0), bevel=0.0005, name="fs_ear")

# ------------------------------------------------------------------ tangent rear sight on the receiver
m.box("Body", "blued", (0.0135, 0.0065, 0.046), (0, BY + R_RCV + 0.0018, -0.094), bevel=0.0009, name="rs_base")
for s in (-1.0, 1.0):
    m.box("Body", "blued", (0.0018, 0.0095, 0.03), (s * 0.0071, 0.0588, -0.092), bevel=0.0005, name="rs_wing")
m.box("Body", "blued", (0.009, 0.0022, 0.034), (0, 0.0574, -0.097), rot=(5.0, 0, 0), bevel=0.0004, name="rs_leaf")
for i in range(6):     # graduations on the leaf
    m.box("Body", "steel", (0.0065, 0.0004, 0.0006), (0, 0.0587 - 0.0003 * i, -0.106 + 0.0045 * i), rot=(5.0, 0, 0), bevel=0.0, name="rs_mark")
m.box("Body", "blued", (0.0105, 0.0055, 0.0042), (0, 0.0599, Z_REAR - 0.002), bevel=0.0004, name="rs_slider")
for s in (-1.0, 1.0):  # the notch: two shoulders, the gap 3.4 mm, shoulders 2 mm over the line
    m.box("Body", "blued", (0.0034, 0.0094, 0.0028), (s * 0.0034, 0.0628, Z_REAR), bevel=0.0003, name="rs_shoulder")
m.box("Body", "blued", (0.0102, 0.0048, 0.0028), (0, 0.0601, Z_REAR), bevel=0.0003, name="rs_notch_floor")   # top 0.0625

# ------------------------------------------------------------------ magazine housing (left side)
m.box("Body", "blued", (0.026, 0.029, 0.047), (-0.0215, MAG_Y + 0.0005, MAG_Z), bevel=0.0012, name="mag_housing")
m.box("Body", "blued", (0.004, 0.032, 0.05), (-0.0355, MAG_Y + 0.0005, MAG_Z), bevel=0.0010, name="mag_housing_lip")
m.box("Body", "steel", (0.008, 0.006, 0.006), (-0.026, MAG_Y + 0.006, MAG_Z + 0.0275), bevel=0.0008, name="mag_catch")
m.rivets("Body", "blued", [((-0.0205, MAG_Y + 0.0152, MAG_Z + s * 0.016), (0, 1, 0)) for s in (-1.0, 1.0)], r=0.0016, name="mag_housing_rivets")

# ------------------------------------------------------------------ the magazine: 30 rounds, curved, out to the left
bm = bmesh.new()
N = 16
rings = []
for i in range(N + 1):
    t = i / N
    x = -0.012 - 0.192 * t
    zc = MAG_Z - 0.028 * t ** 1.6
    yc = MAG_Y - 0.011 * t
    hz = 0.0172 - 0.0018 * t
    hy = 0.0102
    rings.append([bm.verts.new((x, yc + sy * hy, zc + sz * hz)) for (sy, sz) in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
for i in range(N):
    a, b = rings[i], rings[i + 1]
    for k in range(4):
        k1 = (k + 1) % 4
        bm.faces.new([a[k], a[k1], b[k1], b[k]])
bm.faces.new(rings[0])
bm.faces.new(list(reversed(rings[-1])))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
m._obj("mag_body", bm, "Mag", "blued_mag", bevel=0.0018, bevel_segs=2, angle=30.0)
# pressed ribs along both flat sides, the floorplate and its tab
for sy in (-1.0, 1.0):
    pts = []
    for i in range(N + 1):
        t = i / N
        if t < 0.18 or t > 0.94:
            continue
        pts.append(Vector((-0.012 - 0.192 * t, MAG_Y - 0.011 * t + sy * 0.0104, MAG_Z - 0.028 * t ** 1.6)))
    m.sweep("Mag", "blued_mag", pts, (0.0016, 0.0009) if sy > 0 else (0.0016, 0.0009), segs=8, name="mag_rib")
end = Vector((-0.204, MAG_Y - 0.011, MAG_Z - 0.028))
m.box("Mag", "blued_mag", (0.0055, 0.0245, 0.040), (end.x - 0.0018, end.y, end.z), rot=(0, -8.0, 0), bevel=0.0012, name="mag_floor")
m.box("Mag", "blued_mag", (0.003, 0.012, 0.010), (end.x - 0.004, end.y, end.z + 0.019), bevel=0.0006, name="mag_floor_tab")
# the top round showing at the feed lips (inside the housing: only seen with the mag out)
m.cyl("Mag", "brass", 0.0045, 0.0045, 0.03, (-0.012, MAG_Y, MAG_Z), segs=12, name="mag_round")

# ------------------------------------------------------------------ cocking handle (the Bolt part)
HX, HZ = 0.0, 0.062
m.cyl("Bolt", "steel", 0.0027, 0.0027, 0.019, (0.019, BY, HZ), axis="x", segs=14, name="handle_stem")
m.lathe("Bolt", "blued", [(0.0, -0.0062), (0.0042, -0.0058), (0.0063, -0.003), (0.0066, 0.0), (0.0063, 0.003), (0.0042, 0.0058), (0.0, 0.0062)],
        center=(0.0315, BY, HZ), axis="x", segs=24, name="handle_knob")

# ------------------------------------------------------------------ the stock: one piece, straight wrist
STOCK_TOP = [(-0.166, 0.028), (0.078, 0.028), (0.107, 0.026), (0.134, 0.0195), (0.21, 0.0178), (0.30, 0.0158), (0.462, 0.0122)]
STOCK_BOT = [(-0.166, 0.013), (-0.163, 0.003), (-0.152, -0.0025), (-0.120, -0.0045), (-0.060, -0.0062), (-0.006, -0.0090),
             (0.004, -0.0150), (0.014, -0.0245), (0.030, -0.0290), (0.060, -0.0315), (0.120, -0.0400), (0.25, -0.0630),
             (0.40, -0.0900), (0.462, -0.1035)]


def _pl(pts, z):
    if z <= pts[0][0]:
        return pts[0][1]
    for (z0, y0), (z1, y1) in zip(pts, pts[1:]):
        if z <= z1:
            return y0 + (y1 - y0) * (z - z0) / (z1 - z0)
    return pts[-1][1]


def _stock_width(z):
    if z < -0.155:
        return 0.0150 + (0.0172 - 0.0150) * (z + 0.166) / 0.011
    if z < -0.01:
        return 0.0172
    if z < 0.06:
        return 0.0172 + (0.0146 - 0.0172) * (z + 0.01) / 0.07
    if z < 0.16:
        return 0.0146
    return 0.0146 + (0.0196 - 0.0146) * min(1.0, (z - 0.16) / 0.30)


# a loft of rounded (superelliptic) sections between the top and bottom lines: a carved stock, not a plank
stations = sorted(set([round(-0.166 + 0.004 * i, 4) for i in range(5)] + [round(-0.15 + 0.012 * i, 4) for i in range(13)]
                      + [round(-0.006 + 0.004 * i, 4) for i in range(10)] + [round(0.04 + 0.02 * i, 4) for i in range(21)] + [0.462]))
SEC = 24
bm = bmesh.new()
rings = []
for z in stations:
    yt, yb = _pl(STOCK_TOP, z), _pl(STOCK_BOT, z)
    yc, h = (yt + yb) * 0.5, (yt - yb) * 0.5
    w = _stock_width(z)
    ring = []
    for k in range(SEC):
        a = math.tau * k / SEC
        c, s_ = math.cos(a), math.sin(a)
        ex_x = 2.0 / (4.0 if z < 0.08 else 3.2)
        ex_y = 2.0 / (3.0 if s_ < 0 else 5.0)      # rounder underneath, flatter on top
        ring.append(bm.verts.new((w * math.copysign(abs(c) ** ex_x, c), yc + h * math.copysign(abs(s_) ** ex_y, s_), z)))
    rings.append(ring)
for i in range(len(rings) - 1):
    a, b = rings[i], rings[i + 1]
    for k in range(SEC):
        k1 = (k + 1) % SEC
        bm.faces.new([a[k], a[k1], b[k1], b[k]])
bm.faces.new(list(reversed(rings[0])))
bm.faces.new(rings[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
last_ring = [tuple(v.co) for v in rings[-1]]
stock = m._obj("stock", bm, "Body", "wood_jp", bevel=0.0015, bevel_segs=2, angle=50.0)
# buttplate and its two screws
bm = bmesh.new()
pr = []
for zz, k_ in ((0.4612, 1.012), (0.4684, 1.012)):
    pr.append([bm.verts.new((c_[0] * k_, c_[1], zz)) for c_ in last_ring])
for k in range(SEC):
    k1 = (k + 1) % SEC
    bm.faces.new([pr[0][k], pr[0][k1], pr[1][k1], pr[1][k]])
bm.faces.new(list(reversed(pr[0])))
bm.faces.new(pr[1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
m._obj("buttplate", bm, "Body", "blued", bevel=0.0012, bevel_segs=2, angle=40.0)
m.rivets("Body", "steel", [((0, -0.004, 0.4684), (0, 0, 1)), ((0, -0.080, 0.4684), (0, 0, 1))], r=0.0032, flat=0.3, name="butt_screws")
# stock cross screws (escutcheons both sides) by the receiver front and behind the end cap
items = []
for s in (-1.0, 1.0):
    items.append(((s * 0.0173, 0.006, -0.124), (s, 0, 0)))
    items.append(((s * 0.0149, 0.008, 0.118), (s, 0, 0)))
m.rivets("Body", "steel", items, r=0.0034, flat=0.28, name="stock_screws")

# ------------------------------------------------------------------ trigger guard, trigger, tangs
m.box("Body", "blued", (0.0105, 0.003, 0.118), (0, -0.0062, -0.050), rot=(-1.5, 0, 0), bevel=0.0009, name="tang")
m.sweep("Body", "blued", [(0, -0.006, -0.088), (0, -0.019, -0.086), (0, -0.029, -0.073), (0, -0.0325, -0.050), (0, -0.030, -0.025),
                          (0, -0.021, -0.010), (0, -0.010, -0.005)], (0.0042, 0.0017), segs=10, smooth_per=4, name="trigger_guard")
m.rivets("Body", "steel", [((0, -0.0078, -0.103), (0, -1, 0)), ((0, -0.0080, 0.005), (0, -1, 0))], r=0.0026, flat=0.3, name="tang_screws")
m.sweep("Trigger", "blued", [(0, 0.004, -0.047), (0, -0.006, -0.0485), (0, -0.0155, -0.045), (0, -0.0215, -0.0385)], (0.0024, 0.0013),
        segs=8, smooth_per=4, name="trigger")

# ------------------------------------------------------------------ sling swivels (left side): front band, butt
m.torus("Body", "steel", 0.0068, 0.0013, (-0.0215, BY - 0.012, Z_FRONT + 0.001), axis="x", segs=24, rsegs=8, name="swivel_front")
m.box("Body", "blued", (0.006, 0.006, 0.008), (-0.0168, BY - 0.0085, Z_FRONT + 0.001), bevel=0.0008, name="swivel_front_stud")
m.torus("Body", "steel", 0.0085, 0.0014, (-0.0186, -0.064, 0.33), axis="x", segs=24, rsegs=8, name="swivel_butt")
m.box("Body", "blued", (0.0026, 0.010, 0.02), (-0.0163, -0.056, 0.33), bevel=0.0008, name="swivel_butt_plate")
m.rivets("Body", "steel", [((-0.0177, -0.056, 0.324), (-1, 0, 0)), ((-0.0177, -0.056, 0.336), (-1, 0, 0))], r=0.0015, name="swivel_butt_screws")

FIT = {
    "grip_native": [0, 0, 0], "length": round(0.4684 - Z_MZ, 4), "muzzle": [0, BY, Z_MZ],
    "sight_rear": [0, round(SIGHT_Y, 4), Z_REAR], "sight_front": [0, round(SIGHT_Y, 4), Z_FRONT], "sights_on": "root",
    "left_hand": [0, 0.012, -0.235], "lh_axis": "z", "lh_radius": 0.017,
    "grip_r": [0, -0.004, 0.028], "grip_lean": 28, "grip_r_radius": 0.019,
    "pivots": {"Mag": [-0.03, MAG_Y, MAG_Z], "Bolt": [0.025, BY, HZ], "Trigger": [0, 0.0, -0.047]},
    "port": [0.0185, round(BY + 0.0025, 4), -0.076], "bore": 0.0042, "no_bore": True,
    "mag_dir": [-0.9889, -0.1483, 0.0],
    "shader": {"wear": 0.2, "grime": 0.3, "scratches": 0.2},
}
print("FIT", FIT)
rep = m.finish(A["out"] or os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), "assets", "ours", "weapons", "type100"),
               turntable=A["turntable"], fast=A["fast"], extra_report={"fit": FIT})
