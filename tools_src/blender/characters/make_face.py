"""Faces for the named people (T-092, UPDATE_05 section 4; docs/CHARACTER_PIPELINE.md section 9).

The zombie bodies' face parts (make_body.face_parts) are a glow in a socket and a slit. A living person whose face
has to read at bot distance gets, on top of the same sculpted head:

- eyeballs sized and placed from the actual socket (ray-cast onto the head), a dark iris and a pupil;
- upper and lower **eyelids** (spherical patches just outside the eyeball, edge at an elevation angle) and a dark
  lash line, so the eye is an almond, not a ball;
- **brows**: thick ribbons on the brow ridge in the hair colour (the strongest emotion read at distance);
- teeth and the mouth cavity (as make_body), an optional moustache;
- hair styles (crop, bun, braid, bob, two buns) as their own object;
- skin paint per person (vertex colour multiplier on the Body: lips, cheeks, stubble, a red nose, freckles, grease,
  the Cousins' painted doll cheeks and lips);
- the **shape keys** (people.json "shapes": blink, jaw_open, fear, determined, pain, smile). They are computed, not
  sculpted: every shape is a displacement field over head-local position (the Body after decimation, the Parts as
  generated) plus exact re-generation of the lids and brows at the shape's edge angles / offsets.

Everything is in Godot's frame (make_body / common), head-local = position - make_body.HEAD_C, the face toward -Z.
"""
import math

import mathutils
import numpy as np

import common as C
import make_body as MB

HEAD_C = MB.HEAD_C
SHAPES = ["blink", "jaw_open", "fear", "determined", "pain", "smile"]

# lid edge angles (degrees of elevation from the eye's forward axis) per shape: [upper, lower]
LID_OPEN = (17.0, -33.0)
LID = {
    "blink": (-31.0, -34.0),
    "fear": (40.0, -46.0),
    "determined": (3.0, -20.0),
    "pain": (-12.0, -10.0),
    "smile": (10.0, -16.0),
    "jaw_open": LID_OPEN,
}
# brow offsets per shape: (inner up, outer up, inner toward the centre) in metres
BROW = {
    "fear": (0.0125, 0.007, -0.001),
    "determined": (-0.009, -0.002, 0.005),
    "pain": (0.011, -0.004, 0.0065),
    "smile": (0.002, 0.002, 0.0),
}


# ================================================================== head surface queries

class HeadSurface:
    """Ray-casts against the sculpted head (Body region 1) in head-local coordinates."""

    def __init__(self, B):
        hv = B.v - HEAD_C
        faces = [f for f in B.f if int(B.region[f[0]]) == 1]
        self.bvh = mathutils.bvhtree.BVHTree.FromPolygons([tuple(p) for p in hv], faces)

    def front_z(self, x, y):
        """z of the face surface at (x, y) seen from the front (local -Z)."""
        hit = self.bvh.ray_cast((x, y, -0.4), (0.0, 0.0, 1.0), 1.0)
        if hit[0] is None:
            return -0.08, np.array([0.0, 0.0, -1.0])
        return float(hit[0][2]), np.array(hit[1])


# ================================================================== part builders (head-local, then shifted)

class PartsBuilder:
    """Like make_body.PartsAcc but keeps, per vertex, how each shape moves it (offsets per shape name)."""

    def __init__(self):
        self.acc = MB.PartsAcc()
        self.shape = {s: [] for s in SHAPES}

    def add(self, verts, faces, keyname, bone, bone2=None, w2=0.0, shapes=None):
        verts = np.asarray(verts, dtype=np.float64)
        self.acc.add(verts, faces, keyname, bone, bone2, w2)
        for s in SHAPES:
            off = None if shapes is None else shapes.get(s)
            self.shape[s].append(np.zeros_like(verts) if off is None else np.asarray(off))

    def arrays(self):
        v, f, k, bi, bw = self.acc.arrays()
        return v, f, k, bi, bw, {s: np.concatenate(self.shape[s]) for s in SHAPES}


def sphere_patch(c, r, e0, e1, a0, a1, ne, na):
    """Points on a sphere around c by (elevation e from the forward axis -Z, azimuth a), degrees; quads facing out."""
    verts = []
    for i in range(ne + 1):
        e = math.radians(e0 + (e1 - e0) * i / ne)
        for j in range(na + 1):
            a = math.radians(a0 + (a1 - a0) * j / na)
            verts.append(c + r * np.array([math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)]))
    faces = []
    for i in range(ne):
        for j in range(na):
            q = [i * (na + 1) + j, i * (na + 1) + j + 1, (i + 1) * (na + 1) + j + 1, (i + 1) * (na + 1) + j]
            p = [verts[k] for k in q]
            n = np.cross(p[1] - p[0], p[2] - p[0])
            if np.dot(n, (p[0] + p[2]) * 0.5 - c) < 0:
                q = q[::-1]
            faces.append(q)
    return np.array(verts), faces


def cap(c, r, axis_e, axis_a, ang, n_ring=3, n_seg=12):
    """A small spherical cap (iris / pupil) on a sphere around c, centred on direction (elevation, azimuth)."""
    e, a = math.radians(axis_e), math.radians(axis_a)
    ax = np.array([math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)])
    ref = np.array([0.0, 1.0, 0.0]) if abs(ax[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(ax, ref)
    u /= np.linalg.norm(u)
    w = np.cross(ax, u)
    verts = [c + ax * r]
    for i in range(1, n_ring + 1):
        t = math.radians(ang) * i / n_ring
        for j in range(n_seg):
            ph = 2 * math.pi * j / n_seg
            d = ax * math.cos(t) + (u * math.cos(ph) + w * math.sin(ph)) * math.sin(t)
            verts.append(c + d * r)
    faces = []
    for j in range(n_seg):
        faces.append([0, 1 + (j + 1) % n_seg, 1 + j])
    for i in range(n_ring - 1):
        for j in range(n_seg):
            a0 = 1 + i * n_seg + j
            a1 = 1 + i * n_seg + (j + 1) % n_seg
            faces.append([a0, a1, a1 + n_seg, a0 + n_seg])
    # outward winding
    v = np.array(verts)
    out = []
    for fc in faces:
        p = v[fc]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        out.append(fc if np.dot(n, p[0] - c) > 0 else fc[::-1])
    return v, out


def lid(c, r, edge, upper, na=12, ne=5):
    """One lid: the upper covers elevations [edge, 86], the lower [-86, edge]; the open edge is at index ne."""
    top = 86.0 if upper else -86.0
    v, f = sphere_patch(c, r, top, edge, -105.0, 105.0, ne, na)
    return v, f


# ================================================================== the face

def eye_layout(P, S):
    """Eye centres (head-local) and radius from the socket the head sculpt made."""
    hs = (P.face or {}).get("head", (1.0, 1.0, 1.0)) if getattr(P, "face", None) else (1.0, 1.0, 1.0)
    r = 0.0152
    out = []
    for sx in (-1.0, 1.0):
        x = sx * 0.031 * hs[0]
        y = 0.009
        z_s, _n = S.front_z(x, y)
        # the eyeball's front sits 1.6 mm proud of the socket floor
        out.append((sx, np.array([x, y, z_s - 0.0019 + r])))
    return out, r


def face_parts(P, B, S, person):
    """The people's face parts as a PartsBuilder (head-local + HEAD_C applied at the end)."""
    pb = PartsBuilder()
    eyes, r = eye_layout(P, S)
    doll = float(person.get("paint", {}).get("doll", 0.0))
    iris_ang = 31.0 if doll > 0 else 27.0
    for sx, c in eyes:
        cg = c + HEAD_C
        v, f = MB.uv_sphere(cg, r, 14, 9)
        pb.add(v, f, "eye_white", "Head")
        v, f = cap(cg, r + 0.0004, 0.0, 0.0, iris_ang)
        pb.add(v, f, "iris", "Head")
        v, f = cap(cg, r + 0.0007, 0.0, 0.0, 11.0 if doll <= 0 else 13.0, 2, 10)
        pb.add(v, f, "dark", "Head")
        # lids: rebuilt at each shape's edge angles, the offsets are the difference
        rl = r + 0.0011
        for upper in (True, False):
            k = 0 if upper else 1
            base_v, lf = lid(cg, rl, LID_OPEN[k], upper)
            shapes = {}
            for s, edges in LID.items():
                sv, _ = lid(cg, rl, edges[k], upper)
                shapes[s] = sv - base_v
            pb.add(base_v, lf, "lid", "Head", shapes=shapes)
            # the lash line: a thin dark band riding the lid's edge
            lv, lff = lash(cg, rl + 0.0003, LID_OPEN[k], upper)
            lshapes = {}
            for s, edges in LID.items():
                sv, _ = lash(cg, rl + 0.0003, edges[k], upper)
                lshapes[s] = sv - lv
            pb.add(lv, lff, "brow", "Head", shapes=lshapes)
    # brows
    for sx in (-1.0, 1.0):
        bv, bf, bs = brow(P, S, sx, person)
        pb.add(bv, bf, "brow", "Head", shapes=bs)
    # mouth cavity (dark), upper teeth on the head, lower teeth on the jaw (as make_body), moving with the jaw shapes
    for verts, faces, keyname, bone, bone2, w2 in (
            MB.box(HEAD_C + np.array([0, -0.064, -0.052]), np.array([0.019, 0.012, 0.012])) + ("dark", "Head", "Jaw", 0.5),
            MB.box(HEAD_C + np.array([0, -0.0566, -0.061]), np.array([0.0135, 0.0042, 0.0035])) + ("teeth", "Head", None, 0.0),
            MB.box(HEAD_C + np.array([0, -0.0664, -0.059]), np.array([0.012, 0.0038, 0.0035])) + ("teeth", "Jaw", None, 0.0)):
        jw = 1.0 if bone == "Jaw" else (w2 if bone2 == "Jaw" else 0.0)
        pb.add(verts, faces, keyname, bone, bone2, w2, shapes=mouth_shapes(verts - HEAD_C, np.full(len(verts), jw)))
    mo = person.get("moustache", "")
    if mo:
        mv, mf = moustache(S, mo)
        pb.add(mv, mf, "hair", "Head", shapes=body_shapes(mv - HEAD_C, None))
    return pb


def lash(c, r, edge, upper, na=12):
    """A thin strip at the lid edge (2 degrees wide)."""
    d = 3.0 if upper else -3.0
    return sphere_patch(c, r, edge + d, edge - (0.5 if upper else -0.5), -100.0, 100.0, 1, na)


def brow(P, S, sx, person):
    """A brow ribbon on the brow ridge; returns verts (absolute), faces, shape offsets."""
    female = P.female
    n = 9
    thick_in = 0.0092 if not female else 0.0064
    thick_out = 0.005 if not female else 0.0034
    rows = []   # per s: (front_top, front_bot, back_top, back_bot)
    params = []
    for i in range(n + 1):
        s = i / n
        x = sx * (0.011 + 0.043 * s)
        yc = 0.0305 + 0.0055 * math.sin(math.pi * min(1.0, s * 1.1)) - 0.004 * s * s
        h = thick_in + (thick_out - thick_in) * s
        ring = []
        for dy in (h * 0.5, -h * 0.5):
            z, nrm = S.front_z(x, yc + dy)
            p = np.array([x, yc + dy, z])
            ring.append(p + np.array([0, 0, -0.0016]))
            ring.append(p + np.array([0, 0, 0.0006]))
        rows.append(ring)   # [top_front, top_back, bot_front, bot_back]
        params.append(s)
    verts = []
    for ring in rows:
        verts.extend(ring)
    verts = np.array(verts)
    faces = []
    for i in range(n):
        a = i * 4
        b = (i + 1) * 4
        faces.append([a + 0, b + 0, b + 2, a + 2])      # front
        faces.append([a + 1, b + 1, b + 0, a + 0])      # top
        faces.append([a + 2, b + 2, b + 3, a + 3])      # bottom
    # end caps
    faces.append([0, 2, 3, 1])
    e = n * 4
    faces.append([e + 0, e + 1, e + 3, e + 2])
    # outward winding check against the brow's own centre (front faces must face -Z)
    out = []
    for fc in faces:
        p = verts[fc]
        nn = np.cross(p[1] - p[0], p[2] - p[0])
        cen = p.mean(axis=0)
        ref = cen - np.array([cen[0], np.mean(verts[:, 1]), np.mean(verts[:, 2]) + 0.003])
        out.append(fc if np.dot(nn, ref) >= 0 else fc[::-1])
    s_arr = np.repeat(np.array(params), 4)
    shapes = {}
    for sname in SHAPES:
        off = np.zeros_like(verts)
        b = BROW.get(sname)
        if b is not None:
            up = b[0] * (1.0 - s_arr) + b[1] * s_arr
            off[:, 1] = up
            off[:, 2] = np.abs(up) * 0.25           # the forehead recedes as the brow climbs
            off[:, 0] = -sx * b[2] * (1.0 - s_arr) ** 1.5
        shapes[sname] = off
    return verts + HEAD_C, out, shapes


def moustache(S, kind):
    z, _ = S.front_z(0.0, -0.05)
    if kind == "walrus":
        half, drop = 0.03, 0.012
    else:
        half, drop = 0.021, 0.004
    n = 10
    verts = []
    for i in range(n + 1):
        t = -1.0 + 2.0 * i / n
        x = t * half
        y = -0.0485 - drop * t * t
        zs, _ = S.front_z(x, y)
        h = 0.0065 * (1.0 - 0.45 * t * t)
        for dy, dz in ((h * 0.5, 0.0004), (h * 0.5, -0.0045), (-h * 0.5, -0.004), (-h * 0.5, 0.0004)):
            verts.append(np.array([x, y + dy, zs + dz]))
    verts = np.array(verts)
    faces = []
    for i in range(n):
        a, b = i * 4, (i + 1) * 4
        for k in range(4):
            faces.append([a + k, a + (k + 1) % 4, b + (k + 1) % 4, b + k])
    faces.append([3, 2, 1, 0])
    e = n * 4
    faces.append([e, e + 1, e + 2, e + 3])
    return verts + HEAD_C, faces


# ================================================================== shape fields

def jaw_mask(loc):
    """How much a head-local point rides the jaw (the lower lip, chin and jaw in front of the ears)."""
    y, z = loc[:, 1], loc[:, 2]
    return C.smoothstep(-0.0585, -0.0645, y) * C.smoothstep(0.03, -0.01, z) * C.smoothstep(-0.15, -0.115, y)


def rot_jaw(loc, w, angle):
    """Rotates points about the jaw hinge (below the ear) by angle * w (radians; negative opens)."""
    h = np.array([0.0, -0.022, 0.012])
    d = loc - h
    out = np.zeros_like(loc)
    for i in range(len(loc)):
        a = angle * w[i]
        if abs(a) < 1e-9:
            continue
        ca, sa = math.cos(a), math.sin(a)
        y = d[i, 1] * ca - d[i, 2] * sa
        zz = d[i, 1] * sa + d[i, 2] * ca
        out[i] = np.array([d[i, 0], y, zz]) - d[i]
    return out


JAW_OPEN = -0.34


def mouth_fields(loc, front):
    """Small moves around the mouth used by the composite expressions: corner (each side), upper lip, lower lip."""
    x, y = loc[:, 0], loc[:, 1]
    out = {}
    for name, sx in (("corner_l", -1.0), ("corner_r", 1.0)):
        out[name] = front * C.gauss((x - sx * 0.022) ** 2 + (y + 0.061) ** 2, 0.011)
    out["upper_lip"] = front * C.gauss(x ** 2 * 0.6 + (y + 0.0565) ** 2, 0.008)
    out["lower_lip"] = front * C.gauss(x ** 2 * 0.6 + (y + 0.066) ** 2, 0.008)
    out["cheek_l"] = front * C.gauss((x + 0.038) ** 2 + (y + 0.03) ** 2, 0.016)
    out["cheek_r"] = front * C.gauss((x - 0.038) ** 2 + (y + 0.03) ** 2, 0.016)
    out["forehead"] = front * C.gauss((y - 0.06) ** 2 + x ** 2 * 0.3, 0.025)
    out["brow_inner"] = front * C.gauss((y - 0.032) ** 2 + x ** 2, 0.014)
    return out


def body_shapes(loc, jaw_w=None):
    """Shape offsets for skin (or anything riding the skin) at head-local points."""
    n = len(loc)
    front = C.smoothstep(-0.02, -0.06, loc[:, 2]) * C.smoothstep(0.16, 0.1, np.linalg.norm(loc, axis=1))
    jw = jaw_mask(loc) if jaw_w is None else jaw_w
    mf = mouth_fields(loc, front)
    sx_side = np.sign(loc[:, 0])
    jaw = rot_jaw(loc, jw, JAW_OPEN)
    S = {}
    S["blink"] = np.zeros((n, 3))
    S["jaw_open"] = jaw
    corners = mf["corner_l"] + mf["corner_r"]

    def corner_move(dx_out, dy, dz):
        o = np.zeros((n, 3))
        o[:, 0] = sx_side * dx_out * corners
        o[:, 1] = dy * corners
        o[:, 2] = dz * corners
        return o

    fear = 0.45 * jaw + corner_move(0.004, -0.004, 0.0)
    fear[:, 1] += 0.004 * mf["forehead"] + 0.007 * mf["brow_inner"]
    S["fear"] = fear
    det = corner_move(-0.0015, -0.0025, 0.0)
    det[:, 1] += 0.0018 * mf["lower_lip"] - 0.0045 * mf["brow_inner"]
    det[:, 2] -= 0.0015 * mf["lower_lip"]
    S["determined"] = det
    pain = 0.35 * jaw + corner_move(0.006, 0.0015, 0.003)
    pain[:, 1] += 0.003 * mf["upper_lip"] + 0.004 * mf["brow_inner"] + 0.003 * (mf["cheek_l"] + mf["cheek_r"])
    S["pain"] = pain
    smile = corner_move(0.003, 0.0068, 0.0035)
    smile[:, 1] += 0.0032 * (mf["cheek_l"] + mf["cheek_r"])
    smile[:, 2] -= 0.0012 * (mf["cheek_l"] + mf["cheek_r"])
    S["smile"] = smile
    return S


def mouth_shapes(loc, jaw_w):
    """Teeth and the mouth cavity: they ride the jaw rotation in jaw_open and the expressions' part of it."""
    jaw = rot_jaw(loc, jaw_w, JAW_OPEN)
    z = np.zeros_like(loc)
    return {"blink": z, "jaw_open": jaw, "fear": 0.45 * jaw, "determined": z.copy(), "pain": 0.35 * jaw, "smile": z.copy()}


def head_mask(v):
    loc = v - HEAD_C
    return (np.linalg.norm(loc, axis=1) < 0.17) & (loc[:, 1] > -0.16)


# ================================================================== skin paint

def paint(v, person, P):
    """Vertex colour multiplier per Body vertex (rgb, a = 1)."""
    n = len(v)
    col = np.ones((n, 4))
    loc = v - HEAD_C
    on_head = head_mask(v)
    x, y, z = loc[:, 0], loc[:, 1], loc[:, 2]
    front = C.smoothstep(-0.02, -0.06, z) * on_head
    pt = person.get("paint", {})
    rng = np.random.default_rng(abs(hash(person.get("kit", "x"))) % (2 ** 31))
    noise = rng.uniform(0.0, 1.0, n)

    def mix(mask, rgb):
        m = np.clip(mask, 0.0, 1.0)[:, None]
        col[:, :3] = col[:, :3] * (1.0 - m) + col[:, :3] * np.asarray(rgb)[None, :] * m

    # depth everywhere: the sockets a little darker, the lips a little redder
    for sx in (-1.0, 1.0):
        mix(front * 0.35 * C.gauss((x - sx * 0.031) ** 2 + (y - 0.006) ** 2 * 1.4, 0.016), (0.82, 0.74, 0.74))
    lips = front * C.gauss(x ** 2 * 0.55 + (y + 0.061) ** 2 * 1.6, 0.0085) * C.smoothstep(0.03, 0.02, np.abs(x))
    mix(lips * (0.45 + float(pt.get("lips", 0.2))), (0.72, 0.45, 0.45))
    if pt.get("cheeks"):
        for sx in (-1.0, 1.0):
            mix(front * float(pt["cheeks"]) * C.gauss((x - sx * 0.042) ** 2 + (y + 0.025) ** 2, 0.017), (1.04, 0.8, 0.78))
    if pt.get("nose_red"):
        mix(front * float(pt["nose_red"]) * C.gauss(x ** 2 + (y + 0.03) ** 2 + (z + 0.11) ** 2, 0.014), (1.05, 0.72, 0.7))
    if pt.get("hollow"):
        for sx in (-1.0, 1.0):
            mix(front * float(pt["hollow"]) * C.gauss((x - sx * 0.045) ** 2 + (y + 0.045) ** 2, 0.016), (0.8, 0.76, 0.76))
    if pt.get("stubble"):
        sc = pt.get("stubble_col", [0.55, 0.5, 0.5])
        beard = on_head * C.smoothstep(-0.04, -0.055, y) * C.smoothstep(0.045, 0.0, z) * C.smoothstep(-0.16, -0.12, y)
        beard = np.maximum(beard, front * C.smoothstep(-0.035, -0.048, y) * C.smoothstep(0.03, 0.045, np.abs(x)))
        beard = np.maximum(beard, front * C.gauss(x ** 2 * 0.3 + (y + 0.048) ** 2, 0.006))   # upper lip
        beard = beard * (1.0 - 0.9 * C.gauss(x ** 2 * 0.55 + (y + 0.061) ** 2 * 1.6, 0.007))  # not on the lips
        mix(beard * float(pt["stubble"]) * (0.75 + 0.25 * noise), sc)
    if pt.get("freckles"):
        dots = (noise > 0.82).astype(np.float64)
        for sx in (-1.0, 1.0):
            mix(front * dots * float(pt["freckles"]) * C.gauss((x - sx * 0.032) ** 2 + (y + 0.018) ** 2, 0.022), (0.8, 0.62, 0.52))
    if pt.get("grease"):
        smear = front * C.gauss((x - 0.03) ** 2 + (y - 0.045) ** 2, 0.02) + front * C.gauss((x + 0.045) ** 2 + (y + 0.035) ** 2, 0.014)
        mix(np.clip(smear, 0, 1) * float(pt["grease"]) * (0.6 + 0.4 * noise), (0.6, 0.58, 0.56))
    if pt.get("doll"):
        # painted doll features: hard-edged rosy circles on the cheeks, a small painted bow of a mouth
        for sx in (-1.0, 1.0):
            d = np.sqrt((x - sx * 0.04) ** 2 + (y + 0.028) ** 2)
            mix(front * C.smoothstep(0.0125, 0.0105, d), (1.0, 0.62, 0.64))
        bow = front * C.smoothstep(0.0072, 0.0058, np.sqrt((x / 1.9) ** 2 + (y + 0.061) ** 2))
        mix(bow, (0.82, 0.32, 0.36))
    return col


# ================================================================== hair

def hair_cap(B, female, thick):
    """The make_body hair surface (inside the hairline it floats `thick` above the skin), without the bun."""
    loc = B.head_loc
    hv = B.v[B.region == 1]
    head_ids = np.where(B.region == 1)[0]
    first = int(head_ids[0])
    hf = [[i - first for i in f] for f in B.f if int(B.region[f[0]]) == 1]
    nrm = loc / np.linalg.norm(loc, axis=1, keepdims=True)
    m = C.smoothstep(-0.007, 0.007, loc[:, 1] - MB.hairline(female, loc))
    keep_v = m > 0.02
    faces = [f for f in hf if any(keep_v[i] for i in f)]
    used = sorted({i for f in faces for i in f})
    remap = {o: k for k, o in enumerate(used)}
    off = thick * m[used] - 0.005 * (1.0 - m[used])
    v = hv[used] + nrm[used] * off[:, None]
    return v, [[remap[i] for i in fc] for fc in faces]


def dome(center, radii, edge_fn, n_az=40, n_el=10, thick=0.004, flare=0.0, top=88.0, pole=True):
    """A cap of an ellipsoid around `center` from the top down to an edge elevation that varies by azimuth
    (edge_fn(azimuth_deg) -> elevation_deg; azimuth 0 = the face, -Z); double-sided with a rim. Elevation from
    the horizontal plane (+90 = the crown). flare widens the bottom (bobs, hems)."""
    rx, ry, rz = radii
    outer, inner = [], []
    for i in range(n_el + 1):
        for j in range(n_az):
            a = 360.0 * j / n_az - 180.0
            e1 = edge_fn(a)
            e = math.radians(top + (e1 - top) * i / n_el)
            ar = math.radians(a)
            k = 1.0 + flare * max(0.0, (math.radians(top) - e) / math.radians(top + 60.0)) ** 2
            d = np.array([math.sin(ar) * math.cos(e) * rx * k, math.sin(e) * ry, -math.cos(ar) * math.cos(e) * rz * k])
            outer.append(center + d)
            dn = d / np.linalg.norm(d)
            inner.append(center + d - dn * thick)
    nv = (n_el + 1) * n_az
    verts = np.array(outer + inner)
    faces = []
    for i in range(n_el):
        for j in range(n_az):
            a0 = i * n_az + j
            a1 = i * n_az + (j + 1) % n_az
            faces.append([a0, a1, a1 + n_az, a0 + n_az])
            faces.append([nv + a0, nv + a0 + n_az, nv + a1 + n_az, nv + a1])
    # rim
    last = n_el * n_az
    for j in range(n_az):
        a0 = last + j
        a1 = last + (j + 1) % n_az
        faces.append([a0, nv + a0, nv + a1, a1])
    # the crown pole: a fan on both layers (a band, pole=False, gets a rim at its top edge instead)
    po = pi_ = -1
    if pole:
        verts = np.vstack([verts, center + np.array([0, ry, 0]), center + np.array([0, ry - thick, 0])])
        po, pi_ = len(verts) - 2, len(verts) - 1
        for j in range(n_az):
            faces.append([po, (j + 1) % n_az, j])
            faces.append([pi_, nv + j, nv + (j + 1) % n_az])
    else:
        for j in range(n_az):
            faces.append([j, (j + 1) % n_az, nv + (j + 1) % n_az, nv + j])
    # outward winding (outer layer away from centre, inner toward it)
    out = []
    for fc in faces:
        p = verts[fc]
        nn = np.cross(p[1] - p[0], p[2] - p[0])
        if np.linalg.norm(nn) < 1e-14:
            out.append(fc)
            continue
        cen = p.mean(axis=0)
        is_inner = all(nv <= i < 2 * nv or i == pi_ for i in fc) and pi_ != -2
        want = (cen - center)
        if is_inner:
            want = -want
        out.append(fc if np.dot(nn, want) >= 0 else fc[::-1])
    return verts, out


def hair(P, B, person):
    """The person's hair object as a PartsBuilder-free accumulator (no shapes): crop / bun / braid / bob / buns2."""
    style = person.get("hair", "crop")
    acc = MB.PartsAcc()
    hs = (P.face or {}).get("head", (1.0, 1.0, 1.0))
    if style == "none":
        return acc
    if style in ("crop", "bun", "braid", "buns2"):
        female = style != "crop"
        v, f = hair_cap(B, female, 0.0065 if not female else 0.0095)
        acc.add(v, f, "hair", "Head")
    if style == "bun":
        bv, bf = MB.uv_sphere(HEAD_C + np.array([0, -0.035, 0.098 * hs[2]]), 0.036, 10, 6)
        acc.add(bv, bf, "hair", "Head", "Neck", 0.15)
    elif style == "buns2":
        for sx in (-1.0, 1.0):
            bv, bf = MB.uv_sphere(HEAD_C + np.array([sx * 0.066 * hs[0], 0.035 * hs[1], 0.078 * hs[2]]), 0.04, 10, 7)
            acc.add(bv, bf, "hair", "Head")
    elif style == "braid":
        bv, bf = MB.uv_sphere(HEAD_C + np.array([0, -0.06, 0.094 * hs[2]]), 0.03, 10, 6)
        acc.add(bv, bf, "hair", "Head", "Neck", 0.3)
        # the braid hangs down the back over the coat collar to the shoulder blades
        n = 9
        for i in range(n):
            t = i / (n - 1)
            y = 1.62 - 0.36 * t
            zz = 0.118 + 0.03 * math.sin(t * math.pi * 0.8) + 0.015 * t
            r = 0.026 - 0.008 * t
            sv, sf = MB.uv_sphere(np.array([0.004 * math.sin(i * 1.7), y, zz]), r, 8, 5)
            sv = np.array([0.004 * math.sin(i * 1.7), y, zz]) + (sv - np.array([0.004 * math.sin(i * 1.7), y, zz])) * np.array([1.0, 1.35, 0.9])
            if y > 1.55:
                acc.add(sv, sf, "hair", "Head", "Neck", 0.5)
            elif y > 1.45:
                acc.add(sv, sf, "hair", "Neck", "Chest", 0.5)
            else:
                acc.add(sv, sf, "hair", "Chest")
        tv, tf = MB.uv_sphere(np.array([0.0, 1.235, 0.15]), 0.016, 8, 4)
        acc.add(tv, tf, "knit", "Chest")   # the tie (her mitten wool)
    elif style == "bob":
        def edge(a):
            aa = abs(a)
            if aa < 48.0:
                return 26.0           # straight bangs above the brows
            if aa < 80.0:
                return 26.0 + (-48.0 - 26.0) * C.smoothstep(48.0, 80.0, aa)
            return -48.0
        v, f = dome(HEAD_C + np.array([0.0, 0.004, 0.006]), (0.095 * hs[0], 0.126 * hs[1], 0.112 * hs[2]), edge, 44, 12, 0.006, flare=0.14)
        # straight bangs: flatten the front fringe onto the forehead plane
        loc = v - HEAD_C
        frontm = (loc[:, 2] < -0.07) & (loc[:, 1] < 0.08)
        v[frontm, 2] = np.maximum(v[frontm, 2], HEAD_C[2] - 0.106 * hs[2])
        acc.add(v, f, "hair", "Head")
    return acc
