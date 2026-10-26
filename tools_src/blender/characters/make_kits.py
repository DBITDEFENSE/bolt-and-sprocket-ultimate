"""Outfit kits as real clothing meshes for the GRAVELIGHT bodies (T-091, ZOMBIE_ANIM_SPEC §6, v2 §7.6).

Called by build_all.py with a built body (make_body.Body, rest pose, Godot frame). Every garment is made from the
body itself, the way a character artist starts clothes: the body faces of a region (by dominant bone and height)
are copied and pushed out along the normals by the cloth's thickness (a coat thicker than a shirt), with a hem rim
so the open edges have a lip; coat and dress skirts are lofted rings that hug the hips and flare to clear both
legs; belts, collars and cuffs are bands that follow the cross-section underneath; buttons, pouches, pockets,
straps and tabs are small boxes placed on the garment's surface. Every vertex takes its weights from the body
vertex it came from (skirts blend the hips into both thighs by height and side), and its material key goes into
COLOR_0.r (characters.json part_keys) so ZombieBody colours it per kit.

Each kit also returns the body vertices it hides (inside its shells, two vertex rings in from the edge): the GLB
stores that as a bitmask per body vertex and the merge drops those skin triangles, so a horde does not draw the
skin under the coats.

Insignia: none of the real ones. Soldiers wear plain collar tabs and shoulder straps; the Projekt Wiederkehr mark
(docs/ART_FACTIONS.md) only appears on the armband gear piece.
"""
import math

import numpy as np

import common as C
import make_body as MB

RIG = MB.RIG
BI = RIG.index
TORSO = {BI["Hips"], BI["Spine"], BI["Chest"]}
ARMS = {BI[s + b] for s in ("Left", "Right") for b in ("UpperArm", "LowerArm")}
HANDS = {BI["LeftHand"], BI["RightHand"]}
THIGHS = {BI["LeftUpperLeg"], BI["RightUpperLeg"]}
SHINS = {BI["LeftLowerLeg"], BI["RightLowerLeg"]}
FEET = {BI["LeftFoot"], BI["RightFoot"]}
NECK = {BI["Neck"]}


# ================================================================== mesh utilities

def vertex_normals(v, faces):
    n = np.zeros_like(v)
    for f in faces:
        p0 = v[f[0]]
        for k in range(1, len(f) - 1):
            c = np.cross(v[f[k]] - p0, v[f[k + 1]] - p0)
            for i in (f[0], f[k], f[k + 1]):
                n[i] += c
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    ln[ln < 1e-12] = 1.0
    return n / ln


def edge_count(faces):
    cnt = {}
    for f in faces:
        for a, b in zip(f, f[1:] + f[:1]):
            k = (a, b) if a < b else (b, a)
            cnt[k] = cnt.get(k, 0) + 1
    return cnt


def erode(selected, faces, rings):
    """Vertex set minus `rings` rings in from the boundary of the faces it spans."""
    sel = set(selected)
    for _ in range(rings):
        fs = [f for f in faces if all(i in sel for i in f)]
        bnd = set()
        for (a, b), c in edge_count(fs).items():
            if c == 1:
                bnd.add(a)
                bnd.add(b)
        # vertices of faces partially outside are boundary too
        for f in faces:
            ins = [i in sel for i in f]
            if any(ins) and not all(ins):
                bnd.update(i for i in f if i in sel)
        sel -= bnd
    return sel


class Piece:
    """One single-key garment piece: verts, faces, weights (N,4)."""

    def __init__(self, keyname, v, f, bi, bw):
        self.key = keyname
        self.v = np.asarray(v, dtype=np.float64)
        self.f = [list(x) for x in f]
        self.bi = np.asarray(bi, dtype=np.int32)
        self.bw = np.asarray(bw, dtype=np.float64)


class Kit:
    def __init__(self, name):
        self.name = name
        self.pieces = []
        self.covered = set()

    def add(self, piece):
        if piece is not None and len(piece.f) > 0:
            self.pieces.append(piece)

    def arrays(self):
        vs, fs, ks, bis, bws = [], [], [], [], []
        off = 0
        for p in self.pieces:
            vs.append(p.v)
            fs.extend([[i + off for i in f] for f in p.f])
            ks.extend([MB.key(p.key)] * len(p.v))
            bis.append(p.bi)
            bws.append(p.bw)
            off += len(p.v)
        return np.concatenate(vs), fs, np.array(ks), np.concatenate(bis), np.concatenate(bws)


class BodyView:
    """The body arrays plus the derived data the garments need (normals, dominant bones)."""

    def __init__(self, B):
        self.v = B.v
        self.f = B.f
        self.bi = B.bi
        self.bw = B.bw
        self.n = vertex_normals(B.v, B.f)
        self.dom = MB.dominant_bone(B.bi, B.bw)
        self.region = B.region


# ================================================================== garment builders

def shell(body, pred, thick, keyname, rim=0.006, push=None):
    """Body faces whose vertices all satisfy pred, offset along the normals by thick(v) (+ a rim lip)."""
    ok = pred(body)
    faces = [f for f in body.f if all(ok[i] for i in f)]
    if not faces:
        return None, set()
    used = sorted({i for f in faces for i in f})
    remap = {o: k for k, o in enumerate(used)}
    src = np.array(used)
    t = thick(body.v[src]) if callable(thick) else np.full(len(src), thick)
    v = body.v[src] + body.n[src] * t[:, None]
    if push is not None:
        v = push(v, body.v[src], body.n[src])
    f = [[remap[i] for i in fc] for fc in faces]
    bi = body.bi[src].copy()
    bw = body.bw[src].copy()
    # hem lip: boundary edges get a strip folding back toward the body
    if rim > 0:
        cnt = edge_count(f)
        bnd = [e for e, c in cnt.items() if c == 1]
        # orientation: use the face's own edge order
        dirs = {}
        for fc in f:
            for a, b in zip(fc, fc[1:] + fc[:1]):
                k = (a, b) if a < b else (b, a)
                if cnt[k] == 1:
                    dirs[k] = (a, b)
        extra_v = {}
        nv = list(v)
        nbi = list(bi)
        nbw = list(bw)
        nrm = body.n[src]
        for k in bnd:
            for i in k:
                if i not in extra_v:
                    extra_v[i] = len(nv)
                    nv.append(v[i] - nrm[i] * min(rim, float(t[i]) * 0.8))
                    nbi.append(bi[i])
                    nbw.append(bw[i])
        for k in bnd:
            a, b = dirs[k]
            f.append([b, a, extra_v[a], extra_v[b]])
        v = np.array(nv)
        bi = np.array(nbi)
        bw = np.array(nbw)
    covered = erode([i for i in range(len(body.v)) if ok[i]], body.f, 2)
    return Piece(keyname, v, f, bi, bw), covered


def trunk(src):
    """Trunk-only points of a body / piece (no arms hanging beside it): dominant bone on the torso, |x| < 0.2."""
    dom = MB.dominant_bone(src.bi, src.bw)
    m = np.isin(dom, list(TORSO)) & (np.abs(src.v[:, 0]) < 0.2)
    return src.v[m]


def neck_pts(body):
    m = np.isin(body.dom, list(NECK)) | (np.isin(body.dom, [BI["Chest"]]) & (np.abs(body.v[:, 0]) < 0.075))
    return body.v[m & (body.region == 0)]


def ring_profile(points, center_xz, y, half, nb=24, pad=0.0):
    """Radius per angle bin of `points` within y +- half around center (x, z); empty bins interpolated."""
    m = np.abs(points[:, 1] - y) < half
    p = points[m]
    r = np.zeros(nb)
    if len(p):
        dx = p[:, 0] - center_xz[0]
        dz = p[:, 2] - center_xz[1]
        ang = (np.arctan2(dz, dx) % (2 * math.pi)) / (2 * math.pi) * nb
        rad = np.hypot(dx, dz)
        for b in range(nb):
            sel = (ang >= b) & (ang < b + 1)
            if sel.any():
                r[b] = rad[sel].max()
    # fill gaps by neighbours, then smooth
    for _ in range(nb):
        z = r == 0
        if not z.any():
            break
        r[z] = np.maximum(np.roll(r, 1), np.roll(r, -1))[z]
    r = (np.roll(r, 1) + 2 * r + np.roll(r, -1)) / 4.0
    return r + pad


def loft(rings_xyz, closed=True, cap=False):
    """Quads between consecutive rings (each ring: (nb,3)); outward faces when rings go top -> bottom CCW."""
    nb = rings_xyz[0].shape[0]
    v = np.concatenate(rings_xyz)
    f = []
    for r in range(len(rings_xyz) - 1):
        for k in range(nb if closed else nb - 1):
            a = r * nb + k
            b = r * nb + (k + 1) % nb
            f.append([a, a + nb, b + nb, b])
    return v, f


def ring_points(center_xz, y, radii):
    nb = len(radii)
    ang = (np.arange(nb) + 0.5) / nb * 2 * math.pi
    return np.stack([center_xz[0] + np.cos(ang) * radii, np.full(nb, y), center_xz[1] + np.sin(ang) * radii], axis=1)


def double_side(v, f, bi, bw, inset_n=None, inset=0.005):
    """Adds the inside of a single-sided piece (reversed faces, pushed inward along the given normals)."""
    n = len(v)
    vin = v - (inset_n * inset if inset_n is not None else 0.0)
    f2 = [list(reversed([i + n for i in fc])) for fc in f]
    return np.concatenate([v, vin]), f + f2, np.concatenate([bi, bi]), np.concatenate([bw, bw])


def skirt_weights(v, y_top, y_hem):
    """Hips at the waist, sliding into the thigh on each side (and a little into the shins below the knee)."""
    n = len(v)
    h = np.clip((y_top - v[:, 1]) / max(y_top - y_hem, 1e-3), 0.0, 1.0)
    leg = 0.85 * h ** 1.1
    left = C.smoothstep(0.05, -0.05, v[:, 0])
    shin = leg * 0.45 * C.smoothstep(0.52, 0.25, v[:, 1])
    raw = np.zeros((n, len(RIG.bones)))
    raw[:, BI["Hips"]] = 1.0 - leg
    raw[:, BI["LeftUpperLeg"]] = (leg - shin) * left
    raw[:, BI["RightUpperLeg"]] = (leg - shin) * (1 - left)
    raw[:, BI["LeftLowerLeg"]] = shin * left
    raw[:, BI["RightLowerLeg"]] = shin * (1 - left)
    return C.top_k_weights(raw, prune=0.02)


def skirt(body, base_points, y_top, y_hem, keyname, flare=0.18, ease=0.012, nb=28, rings=9, ragged=0.0, front_gap=0.0):
    """A lofted skirt from y_top (hugging base_points there) down to y_hem, clearing both legs."""
    c = (0.0, 0.01)
    legs = body.v[(np.isin(body.dom, list(THIGHS | SHINS)))]
    rs = []
    for i in range(rings):
        t = i / (rings - 1)
        y = y_top + (y_hem - y_top) * t
        top = ring_profile(base_points, c, y_top, 0.025, nb, ease)
        envelope = ring_profile(legs, c, y, 0.03, nb, 0.03 + 0.03 * t)
        r = np.maximum(top * (1.0 + flare * t), envelope)
        r = (np.roll(r, 1) + 2 * r + np.roll(r, -1)) / 4.0
        yy = np.full(nb, y)
        if ragged > 0 and i == rings - 1:
            rng = np.random.default_rng(91)
            yy = yy + rng.uniform(-ragged, ragged, nb)
        pts = ring_points(c, 0.0, r)
        pts[:, 1] = yy
        rs.append(pts)
    v, f = loft(rs)
    # faces wind outward: our ring goes CCW seen from above (+x toward +z); flip if needed
    f = [list(reversed(x)) for x in f]
    bi, bw = skirt_weights(v, y_top, y_hem)
    nrm = v - np.array([c[0], 0, c[1]])
    nrm[:, 1] = 0
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-6)
    v, f, bi, bw = double_side(v, f, bi, bw, nrm, 0.006)
    return Piece(keyname, v, f, bi, bw)


def band(body, points, y, height, keyname, pad=0.006, thick=0.008, nb=24, bones=None):
    """A belt / collar / cuff: a rectangular section swept around the cross-section of `points` at y."""
    c = (0.0, 0.01)
    r = ring_profile(points, c, y, max(height * 0.5, 0.015), nb, pad)
    outer_t = ring_points(c, y + height / 2, r + thick)
    outer_b = ring_points(c, y - height / 2, r + thick)
    inner_t = ring_points(c, y + height / 2, r)
    inner_b = ring_points(c, y - height / 2, r)
    v, f = loft([inner_t, outer_t, outer_b, inner_b, inner_t])
    f = [list(reversed(x)) for x in f]
    n = len(v)
    raw = np.zeros((n, len(RIG.bones)))
    if bones is None:
        # nearest trunk / neck vertex's weights (never an arm hanging beside the belt)
        m = np.isin(body.dom, list(TORSO | NECK)) & (body.region == 0)
        bi, bw = copy_weights(body, v, body.v[m], body.bi[m], body.bw[m])
    else:
        for b, w in bones.items():
            raw[:, BI[b]] = w
        bi, bw = C.top_k_weights(raw)
    return Piece(keyname, v, f, bi, bw)


def cuff_band(body, side, y, height, keyname, pad=0.004, thick=0.006, nb=12, bones=("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg")):
    """A band around one limb at height y (centre from that limb's vertices)."""
    sel = np.isin(body.dom, [BI[side + b] for b in bones if side + b in BI])
    pts = body.v[sel & (np.abs(body.v[:, 1] - y) < 0.02)]
    if len(pts) == 0:
        return None
    cx, cz = pts[:, 0].mean(), pts[:, 2].mean()
    r = ring_profile(pts, (cx, cz), y, 0.02, nb, pad)
    rings = [ring_points((cx, cz), y + height / 2, r), ring_points((cx, cz), y + height / 2, r + thick),
             ring_points((cx, cz), y - height / 2, r + thick), ring_points((cx, cz), y - height / 2, r)]
    v, f = loft(rings + [rings[0]])
    f = [list(reversed(x)) for x in f]
    lm = sel | (np.isin(body.dom, [BI[side + b] for b in ("Hand", "Foot") if side + b in BI]))
    bi, bw = copy_weights(body, v, body.v[lm], body.bi[lm], body.bw[lm])
    return Piece(keyname, v, f, bi, bw)


def copy_weights(body, pts, src_v=None, src_bi=None, src_bw=None):
    sv = body.v if src_v is None else src_v
    sbi = body.bi if src_bi is None else src_bi
    sbw = body.bw if src_bw is None else src_bw
    out_i = np.zeros((len(pts), 4), dtype=np.int32)
    out_w = np.zeros((len(pts), 4))
    for k, p in enumerate(pts):
        j = int(np.argmin(((sv - p) ** 2).sum(axis=1)))
        out_i[k] = sbi[j]
        out_w[k] = sbw[j]
    return out_i, out_w


def surface_hit(piece, x, y, front=True):
    """The piece's outermost vertex near (x, y) on the front (or back): position, normal-ish, index."""
    v = piece.v
    d = (v[:, 0] - x) ** 2 + (v[:, 1] - y) ** 2
    cand = np.argsort(d)[:40]
    j = cand[np.argmin(v[cand, 2])] if front else cand[np.argmax(v[cand, 2])]
    p = v[j].copy()
    nrm = np.array([0.0, 0.0, -1.0 if front else 1.0])
    return p, nrm, j


def stud(piece_src, keyname, x, y, size, front=True, depth=0.004, tilt=0.0):
    """A small box (button, tab, pocket, pouch) sitting on piece_src's surface at (x, y)."""
    p, nrm, j = surface_hit(piece_src, x, y, front)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    c = p + nrm * (hz - 0.001)
    v, f = MB.box(np.zeros(3), np.array([hx, hy, hz]))
    if tilt:
        v = v @ C.rot_z(tilt).T
    v = v + c
    bi = np.repeat(piece_src.bi[j:j + 1], len(v), axis=0)
    bw = np.repeat(piece_src.bw[j:j + 1], len(v), axis=0)
    return Piece(keyname, v, f, bi, bw)


def stud_top(piece_src, keyname, x, size):
    """A small box lying on top of the piece (a shoulder strap) at x."""
    v = piece_src.v
    near = np.where((np.abs(v[:, 0] - x) < 0.02) & (np.abs(v[:, 2]) < 0.04))[0]
    if len(near) == 0:
        return None
    j = near[np.argmax(v[near, 1])]
    c = v[j] + np.array([0.0, size[1] / 2 - 0.001, 0.0])
    bv, bf = MB.box(c, np.array(size) / 2)
    bi = np.repeat(piece_src.bi[j:j + 1], len(bv), axis=0)
    bw = np.repeat(piece_src.bw[j:j + 1], len(bv), axis=0)
    return Piece(keyname, bv, bf, bi, bw)


# ================================================================== region predicates

def P_torso(y_lo, y_hi=1.545):
    return lambda b: np.isin(b.dom, list(TORSO)) & (b.v[:, 1] > y_lo) & (b.v[:, 1] < y_hi) & (b.region == 0)


def P_arms(y_lo):
    return lambda b: np.isin(b.dom, list(ARMS)) & (b.v[:, 1] > y_lo) & (b.region == 0)


def P_or(*ps):
    return lambda b: np.logical_or.reduce([p(b) for p in ps])


def P_legs(y_lo, y_hi=1.04):
    return lambda b: (np.isin(b.dom, list(THIGHS | SHINS)) | (np.isin(b.dom, [BI["Hips"]]))) & (b.v[:, 1] > y_lo) & (b.v[:, 1] < y_hi) & (b.region == 0)


def P_boots(y_hi):
    return lambda b: np.isin(b.dom, list(SHINS | FEET)) & (b.v[:, 1] < y_hi) & (b.region == 0)


def P_hands():
    return lambda b: (b.region == 2) | (np.isin(b.dom, list(HANDS)) & (b.v[:, 1] < 0.9))


def boot_push(sole=0.011):
    def f(v, src, nrm):
        out = v.copy()
        low = src[:, 1] < 0.035
        out[low, 1] = np.minimum(out[low, 1], src[low, 1] - sole * C.smoothstep(0.035, 0.0, src[low, 1]))
        out[:, 1] = np.maximum(out[:, 1], 0.0)
        # a blunt boot toe
        toe = src[:, 2] < -0.12
        out[toe, 2] -= 0.008
        return out
    return f


def flare_push(y0, y1, amount):
    """Wider toward y1 (bell-bottoms, a sailor's trousers)."""
    def f(v, src, nrm):
        k = C.smoothstep(y0, y1, src[:, 1])
        return v + nrm * (amount * k)[:, None]
    return f


# ================================================================== the kits

def thick_by_y(t_torso, t_arm, t_neck=None):
    return lambda p: np.where(np.abs(p[:, 0]) > 0.2, t_arm, t_torso)


def add_shell(kit, body, pred, thick, key, rim=0.006, push=None, cover=True):
    piece, cov = shell(body, pred, thick, key, rim, push)
    kit.add(piece)
    if cover:
        kit.covered |= cov
    return piece


def kit_soldier(body, P):
    k = Kit("soldier")
    coat = add_shell(k, body, P_or(P_torso(0.86), P_arms(0.9)), thick_by_y(0.022, 0.016), "cloth")
    add_shell(k, body, P_legs(0.30, 0.95), 0.009, "cloth2")
    boots = add_shell(k, body, P_boots(0.39), 0.013, "leather", rim=0.008, push=boot_push())
    k.add(skirt(body, trunk(coat), 0.90, 0.40, "cloth", flare=0.22, ease=0.004))
    k.add(band(body, trunk(coat), 1.0, 0.05, "leather", pad=0.002, thick=0.007))
    for sx in (-1, 1):
        k.add(stud(coat, "leather", sx * 0.095, 1.0, (0.07, 0.07, 0.045)))        # ammunition pouches
        k.add(stud(coat, "dark", sx * 0.045, 1.475, (0.03, 0.04, 0.008), tilt=sx * 0.3))  # plain collar tabs
        for i in range(5):
            k.add(stud(coat, "metal", sx * 0.065, 1.38 - i * 0.085, (0.016, 0.016, 0.007)))
    k.add(stud(coat, "metal", 0.0, 1.0, (0.05, 0.04, 0.012)))     # buckle
    k.add(band(body, neck_pts(body), 1.49, 0.06, "cloth2", pad=0.016, thick=0.012))   # collar
    for sx, side in ((-1, "Left"), (1, "Right")):
        k.add(cuff_band(body, side, 0.93, 0.05, "cloth2", pad=0.016, thick=0.006))
    return k


def kit_villager(body, P):
    k = Kit("villager")
    if P.female:
        blouse = add_shell(k, body, P_or(P_torso(0.92), P_arms(0.92)), thick_by_y(0.008, 0.007), "cloth")
        k.add(band(body, neck_pts(body), 1.49, 0.045, "cloth", pad=0.012, thick=0.008))   # collar hides the neckline
        k.add(skirt(body, trunk(blouse), 0.98, 0.12, "cloth2", flare=0.32, ease=0.008))
        add_shell(k, body, P_boots(0.14), 0.007, "dark", push=boot_push(0.008))
        shawl = add_shell(k, body, lambda b: P_torso(1.22, 1.51)(b) | (P_arms(1.2)(b) & (b.v[:, 1] > 1.28)), 0.02, "knit", cover=False)
        add_shell(k, body, P_legs(0.12, 0.6), 0.003, "dark", rim=0.0)   # wool stockings
        for i in range(4):
            k.add(stud(blouse, "dark", 0.0, 1.2 - i * 0.06, (0.012, 0.012, 0.006)))
    else:
        jacket = add_shell(k, body, P_or(P_torso(0.9), P_arms(0.9)), thick_by_y(0.015, 0.011), "cloth")
        k.add(band(body, neck_pts(body), 1.49, 0.045, "cloth2", pad=0.012, thick=0.008))   # collar hides the neckline
        add_shell(k, body, P_legs(0.13, 0.98), 0.008, "cloth2")
        add_shell(k, body, P_boots(0.2), 0.011, "leather", push=boot_push())
        k.add(band(body, trunk(jacket), 0.96, 0.03, "leather", pad=0.001, thick=0.005))
        for i in range(3):
            k.add(stud(jacket, "dark", 0.012, 1.3 - i * 0.1, (0.014, 0.014, 0.006)))
        k.add(stud(jacket, "cloth2", -0.07, 1.33, (0.08, 0.06, 0.006)))     # breast pocket
        for sx in (-1, 1):
            k.add(stud(jacket, "cloth2", sx * 0.09, 1.04, (0.09, 0.07, 0.006)))
        k.add(cuff_band(body, "Left", 0.48, 0.07, "patch", pad=0.009, thick=0.003, bones=("UpperLeg", "LowerLeg")))   # a knee patch
    return k


def kit_miner(body, P):
    k = Kit("miner")
    jacket = add_shell(k, body, P_or(P_torso(0.88), P_arms(0.92)), thick_by_y(0.016, 0.012), "cloth")
    k.add(band(body, neck_pts(body), 1.49, 0.045, "cloth", pad=0.012, thick=0.008))   # collar hides the neckline
    add_shell(k, body, P_legs(0.30, 0.98), 0.009, "cloth2")
    add_shell(k, body, P_boots(0.34), 0.013, "leather", push=boot_push())
    k.add(band(body, trunk(jacket), 0.98, 0.045, "leather", pad=0.001, thick=0.007))
    k.add(stud(jacket, "metal", 0.0, 0.98, (0.05, 0.04, 0.012)))
    for sx in (-1, 1):
        k.add(stud(jacket, "leather", sx * 0.075, 1.25, (0.03, 0.32, 0.006)))    # braces
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.62, 0.03, "rope", pad=0.01, thick=0.006, bones=("UpperLeg", "LowerLeg")))   # trouser ties
    return k


def kit_labstaff(body, P):
    k = Kit("labstaff")
    coat = add_shell(k, body, P_or(P_torso(0.86), P_arms(0.9)), thick_by_y(0.016, 0.012), "cloth")
    k.add(skirt(body, trunk(coat), 0.9, 0.36, "cloth", flare=0.18, ease=0.003))
    add_shell(k, body, P_legs(0.13, 0.95), 0.007, "cloth2")
    add_shell(k, body, P_boots(0.13), 0.009, "dark", push=boot_push(0.009))
    add_shell(k, body, P_hands(), 0.004, "glove", rim=0.0)
    k.add(band(body, neck_pts(body), 1.48, 0.05, "cloth", pad=0.016, thick=0.01))
    k.add(stud(coat, "dark", 0.09, 1.3, (0.05, 0.08, 0.006)))       # breast pocket with a pen line
    k.add(stud(coat, "patch", -0.09, 1.34, (0.05, 0.03, 0.005)))     # a plain name tag
    for i in range(5):
        k.add(stud(coat, "white", -0.012, 1.4 - i * 0.1, (0.014, 0.014, 0.006)))
    for sx in (-1, 1):
        k.add(stud(coat, "cloth", sx * 0.1, 0.8, (0.1, 0.11, 0.006)))   # hip pockets on the coat skirt
    return k


def kit_technician(body, P):
    k = Kit("technician")
    cov = add_shell(k, body, P_or(P_torso(0.85), P_arms(0.9), P_legs(0.28, 1.0)), lambda p: np.where(np.abs(p[:, 0]) > 0.2, 0.011, 0.012), "cloth")
    k.add(band(body, neck_pts(body), 1.49, 0.045, "cloth", pad=0.012, thick=0.008))   # collar hides the neckline
    add_shell(k, body, P_boots(0.38), 0.014, "rubber", rim=0.008, push=boot_push())
    add_shell(k, body, P_hands(), 0.004, "rubber", rim=0.0)
    k.add(band(body, trunk(cov), 0.99, 0.055, "leather", pad=0.002, thick=0.008))
    for sx in (-1, 1):
        k.add(stud(cov, "cloth2", sx * 0.075, 1.3, (0.09, 0.1, 0.008)))   # chest pockets
        k.add(stud(cov, "leather", sx * 0.12, 0.96, (0.06, 0.08, 0.035)))  # tool pouches
    k.add(stud(cov, "metal", 0.03, 0.96, (0.02, 0.12, 0.012)))     # a spanner in the belt
    k.add(stud(cov, "cloth2", 0.0, 1.2, (0.025, 0.36, 0.006)))     # the zip placket
    return k


def kit_sailor(body, P):
    k = Kit("sailor")
    jacket = add_shell(k, body, P_or(P_torso(0.86), P_arms(0.9)), thick_by_y(0.018, 0.012), "navy")
    k.add(skirt(body, trunk(jacket), 0.9, 0.76, "navy", flare=0.08, ease=0.003, rings=4))
    add_shell(k, body, P_legs(0.06, 0.95), 0.009, "navy", push=flare_push(0.45, 0.08, 0.025))
    add_shell(k, body, P_boots(0.07), 0.008, "dark", push=boot_push(0.009))
    for sx in (-1, 1):
        for i in range(3):
            k.add(stud(jacket, "brass", sx * 0.065, 1.33 - i * 0.11, (0.016, 0.016, 0.007)))
    k.add(band(body, neck_pts(body), 1.48, 0.07, "navy", pad=0.02, thick=0.012))
    return k


def kit_dockworker(body, P):
    k = Kit("dockworker")
    jumper = add_shell(k, body, P_or(P_torso(0.9), P_arms(0.9)), thick_by_y(0.016, 0.013), "knit")
    add_shell(k, body, P_legs(0.3, 0.98), 0.009, "cloth2")
    add_shell(k, body, P_boots(0.4), 0.015, "rubber", rim=0.008, push=boot_push())
    k.add(band(body, neck_pts(body), 1.55, 0.09, "knit", pad=0.014, thick=0.014))   # roll neck
    k.add(band(body, trunk(jumper), 0.94, 0.05, "knit", pad=0.002, thick=0.008))    # ribbed hem
    for sx, side in ((-1, "Left"), (1, "Right")):
        k.add(cuff_band(body, side, 0.92, 0.05, "knit", pad=0.014, thick=0.006))
    return k


def kit_bellringer(body, P):
    k = Kit("bellringer")
    tunic = add_shell(k, body, P_torso(0.86, 1.47), 0.012, "cloth")
    k.add(band(body, neck_pts(body), 1.49, 0.045, "cloth", pad=0.012, thick=0.008))   # collar hides the neckline
    k.add(skirt(body, trunk(tunic), 0.9, 0.62, "cloth", flare=0.15, ease=0.003, rings=5, ragged=0.04))
    for i in range(3):
        k.add(band(body, trunk(tunic), 1.1 + 0.12 * i, 0.018, "dark", pad=0.002, thick=0.005))   # the binding straps
    k.add(band(body, trunk(tunic), 0.96, 0.03, "rope", pad=0.003, thick=0.008))
    return k


def kit_nurse(body, P):
    k = Kit("nurse")
    dress = add_shell(k, body, P_or(P_torso(0.9), P_arms(1.12)), thick_by_y(0.009, 0.009), "cloth")
    sk = skirt(body, trunk(dress), 0.97, 0.3, "cloth", flare=0.25, ease=0.006)
    k.add(sk)
    add_shell(k, body, P_legs(0.1, 0.6), 0.003, "dark", rim=0.0)   # stockings
    add_shell(k, body, P_boots(0.11), 0.008, "dark", push=boot_push(0.009))
    # the white apron: bib on the dress, panel on the skirt's front
    bib = shell(BodyLike(dress), lambda b: (b.v[:, 2] < -0.03) & (np.abs(b.v[:, 0]) < 0.11) & (b.v[:, 1] > 1.0) & (b.v[:, 1] < 1.4), 0.004, "white", 0.0)[0]
    k.add(bib)
    pan = shell(BodyLike(sk), lambda b: (b.v[:, 2] < -0.02) & (np.abs(b.v[:, 0]) < 0.17) & (b.v[:, 1] > 0.42), 0.004, "white", 0.0)[0]
    k.add(pan)
    k.add(band(body, neck_pts(body), 1.49, 0.04, "white", pad=0.012, thick=0.008))
    k.add(band(body, trunk(dress), 1.0, 0.04, "white", pad=0.004, thick=0.005))    # apron strings
    for sx, side in ((-1, "Left"), (1, "Right")):
        k.add(cuff_band(body, side, 1.13, 0.04, "white", pad=0.012, thick=0.005))
    return k


class BodyLike:
    """Wraps a Piece so shell() can overlay it (aprons over the dress)."""

    def __init__(self, piece):
        self.v = piece.v
        self.f = piece.f
        self.bi = piece.bi
        self.bw = piece.bw
        self.n = vertex_normals(piece.v, piece.f)
        self.dom = MB.dominant_bone(piece.bi, piece.bw)
        self.region = np.zeros(len(piece.v), dtype=np.int64)


KITS = {
    "soldier": kit_soldier,
    "villager": kit_villager,
    "miner": kit_miner,
    "labstaff": kit_labstaff,
    "technician": kit_technician,
    "sailor": kit_sailor,
    "dockworker": kit_dockworker,
    "bellringer": kit_bellringer,
    "nurse": kit_nurse,
}


def build_kits(P, B, names=None):
    body = BodyView(B)
    out = {}
    for name in (names or MB.CFG["kit_order"]):
        out[name] = KITS[name](body, P)
    return out
