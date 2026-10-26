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
        k.add(cuff_band(body, side, 0.93, 0.05, "cloth2", pad=0.016, thick=0.006, bones=("LowerArm", "Hand")))   # T-099: arm only (no wrist-to-thigh ring)
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
        k.add(cuff_band(body, side, 0.92, 0.05, "knit", pad=0.014, thick=0.006, bones=("LowerArm", "Hand")))   # T-099: arm only
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
        k.add(cuff_band(body, side, 1.13, 0.04, "white", pad=0.012, thick=0.005, bones=("UpperArm", "LowerArm")))   # T-099: arm only
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


# ================================================================== the named people (T-092, UPDATE_05 section 4)
#
# One kit per person (data/gravelight/art/people.json "kit"), from the same garment tools plus: dome headgear and
# hair (make_face.dome: a cap of an ellipsoid with a smooth edge, not the head's quad grid), sashes (straps laid
# over a garment's surface), an open-fronted coat, fingerless gloves and mittens. Colours are per person (the
# part key's colour comes from the person's palette in PeopleBodies), so "cloth" is Dutch's olive drab and Alix's
# navy. A piece can carry `ao` (per-vertex 0..1 darkening, COLOR_0.g): camouflage brush strokes, grease stains.
# The Cousins (docs/HOMAGE_BOSSES.md section 1.2): modest period clothes, buttoned, long-sleeved, high-necked, below
# the knee or ankle-length, and a dark stitched seam where a doll's parts would join.

import make_face as MF  # noqa: E402


_RAY_CACHE = {}


def surface_ray(piece, x, y, front=True):
    """Where a ray from the front (or back) at (x, y) first meets the piece: position, normal, nearest vertex."""
    import mathutils
    key = id(piece)
    if key not in _RAY_CACHE or _RAY_CACHE[key][0] is not piece:
        tris = []
        for fc in piece.f:
            for k in range(1, len(fc) - 1):
                tris.append((fc[0], fc[k], fc[k + 1]))
        _RAY_CACHE[key] = (piece, mathutils.bvhtree.BVHTree.FromPolygons([tuple(p) for p in piece.v], tris))
    bvh = _RAY_CACHE[key][1]
    z0 = -2.0 if front else 2.0
    hit = bvh.ray_cast((x, y, z0), (0.0, 0.0, 1.0 if front else -1.0), 4.0)
    if hit[0] is None:
        return surface_hit(piece, x, y, front)
    p = np.array(hit[0])
    j = int(np.argmin(((piece.v - p) ** 2).sum(axis=1)))
    nrm = np.array(hit[1])
    if (nrm[2] > 0) == front:
        nrm = -nrm
    return p, nrm, j


def pstud(piece_src, keyname, x, y, size, front=True, tilt=0.0):
    """stud() placed by a ray onto the garment (the people's kits: the snap to the nearest vertex drifts on a
    coarse shell)."""
    p, nrm, j = surface_ray(piece_src, x, y, front)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    zdir = np.array([0.0, 0.0, -1.0 if front else 1.0])
    c = p + zdir * (hz - 0.0015)
    v, f = MB.box(np.zeros(3), np.array([hx, hy, hz]))
    if tilt:
        v = v @ C.rot_z(tilt).T
    v = v + c
    bi = np.repeat(piece_src.bi[j:j + 1], len(v), axis=0)
    bw = np.repeat(piece_src.bw[j:j + 1], len(v), axis=0)
    return Piece(keyname, v, f, bi, bw)


def rigid(v, f, keyname, bone="Head", bone2=None, w2=0.0):
    v = np.asarray(v, dtype=np.float64)
    bi = np.zeros((len(v), 4), dtype=np.int32)
    bw = np.zeros((len(v), 4))
    bi[:, 0] = BI[bone]
    bw[:, 0] = 1.0 - w2
    if bone2 is not None and w2 > 0:
        bi[:, 1] = BI[bone2]
        bw[:, 1] = w2
    return Piece(keyname, v, f, bi, bw)


def hscale(P):
    return (getattr(P, "face", None) or {}).get("head", (1.0, 1.0, 1.0))


def mottle(v, scale=9.0, depth=0.35, seed=1.0, sharp=0.15):
    """Soft blotches (camouflage brush strokes, grease) as an AO multiplier 1 - depth * blotch."""
    x, y, z = v[:, 0] * scale, v[:, 1] * scale, v[:, 2] * scale
    n = (np.sin(x * 1.3 + seed) * np.sin(y * 0.9 + seed * 2.1) + np.sin(y * 1.7 + z * 1.1 + seed * 0.7) * 0.6
         + np.sin(z * 2.3 + x * 0.6 + seed * 1.3) * 0.4)
    return 1.0 - depth * C.smoothstep(0.35 - sharp, 0.35 + sharp, n)


def with_ao(piece, ao):
    if piece is not None:
        piece.ao = np.asarray(ao, dtype=np.float64)
    return piece


def cut_front(piece, half_width, y_max=9.0):
    """Removes the faces of a piece whose centre is on the front (z < 0) within |x| < half_width (an open coat)."""
    if piece is None:
        return None
    keep = []
    for fc in piece.f:
        c = piece.v[fc].mean(axis=0)
        if c[2] < 0.0 and abs(c[0]) < half_width and c[1] < y_max:
            continue
        keep.append(fc)
    piece.f = keep
    return piece


def sash(piece, a, b, width, keyname, front=True, thick=0.004, n=14):
    """A strap laid on a garment's front (or back) surface from a = (x, y) to b."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    d = b - a
    perp = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-6) * width * 0.5
    sgn = -1.0 if front else 1.0
    verts, bis, bws = [], [], []
    for i in range(n + 1):
        t = i / n
        c = a + d * t
        for side in (-1.0, 1.0):
            q = c + perp * side
            p, _nrm, j = surface_ray(piece, q[0], q[1], front)
            verts.append(p + np.array([0, 0, sgn * thick]))
            verts.append(p + np.array([0, 0, sgn * 0.0005]))
            bis.extend([piece.bi[j], piece.bi[j]])
            bws.extend([piece.bw[j], piece.bw[j]])
    verts = np.array(verts)
    faces = []
    for i in range(n):
        o0, o1 = i * 4, (i + 1) * 4
        faces.append(([o0 + 0, o0 + 2, o1 + 2, o1 + 0], sgn))     # outer face
        faces.append(([o0 + 1, o1 + 1, o1 + 3, o0 + 3], -sgn))    # inner face
        faces.append(([o0 + 0, o1 + 0, o1 + 1, o0 + 1], 0.0))     # edges
        faces.append(([o0 + 2, o0 + 3, o1 + 3, o1 + 2], 0.0))
    out = []
    for fc, want in faces:
        if want == 0.0:
            out.append(fc)
            continue
        pts = verts[fc]
        nn = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        out.append(fc if nn[2] * want >= 0 else fc[::-1])
    return Piece(keyname, verts, out, np.array(bis), np.array(bws))


def rim_band(center, radii, edge_fn, height_deg, n_az=40):
    """A double-sided band from an edge (elevation per azimuth) up `height_deg` (a turned-up cap rim, a cap band)."""
    rx, ry, rz = radii
    rows = []
    for i in range(3):
        row = []
        for j in range(n_az):
            a = 360.0 * j / n_az - 180.0
            e = math.radians(edge_fn(a) + height_deg * i / 2.0)
            ar = math.radians(a)
            row.append(center + np.array([math.sin(ar) * math.cos(e) * rx, math.sin(e) * ry, -math.cos(ar) * math.cos(e) * rz]))
        rows.append(row)
    verts = np.array([p for r in rows for p in r])
    faces = []
    for i in range(2):
        for j in range(n_az):
            a0 = i * n_az + j
            a1 = i * n_az + (j + 1) % n_az
            faces.append([a0, a1, a1 + n_az, a0 + n_az])
    out = []
    for fc in faces:
        p = verts[fc]
        nn = np.cross(p[1] - p[0], p[2] - p[0])
        cen = p.mean(axis=0) - center
        cen[1] = 0
        out.append(fc if np.dot(nn, cen) >= 0 else fc[::-1])
    n = len(verts)
    inner = center + (verts - center) * 0.965
    verts = np.vstack([verts, inner])
    out += [list(reversed([i + n for i in fc])) for fc in out]
    return verts, out


def head_piece(P, kind, keyname="hat"):
    """Headgear as Head-bone pieces: helmet / beret / knit / flatcap / peaked / kerchief / sidecap."""
    hs = hscale(P)
    c0 = MB.HEAD_C
    out = []

    def dm(center, radii, edge, hat=True, **kw):
        sr = (radii[0] * hs[0], radii[1] * hs[1], radii[2] * hs[2])
        if hat:
            # T-099: the hair under it is trimmed to fit (make_face.hair reads P.hat)
            P.hat = {"center": c0 + np.array(center), "radii": sr, "edge": edge, "thick": float(kw.get("thick", 0.004)), "kind": kind}
        return MF.dome(c0 + np.array(center), sr, edge, **kw)

    def sc(radii):
        return (radii[0] * hs[0], radii[1] * hs[1], radii[2] * hs[2])

    if kind == "helmet":
        edge = lambda a: -6.0 - 4.0 * C.smoothstep(60.0, 150.0, abs(a))
        v, f = dm((0, 0.05, 0.008), (0.119, 0.1, 0.131), edge, thick=0.007, n_el=11)
        out.append(rigid(v, f, keyname))
        v, f = rim_band(c0 + np.array([0, 0.05, 0.008]), sc((0.127, 0.1, 0.139)), lambda a: edge(a) - 3.0, 4.0)
        out.append(rigid(v, f, keyname))
        # netting: cords over the shell
        for a0 in range(-180, 180, 30):
            pts = []
            for i in range(9):
                e = math.radians(-4.0 + 86.0 * i / 8.0)
                a = math.radians(a0 + 12.0 * math.sin(i * 0.9))
                pts.append(c0 + np.array([0, 0.05, 0.008]) + np.array([math.sin(a) * math.cos(e) * 0.1225 * hs[0], math.sin(e) * 0.1035 * hs[1], -math.cos(a) * math.cos(e) * 0.1345 * hs[2]]))
            tv, tf = MB.tube(np.array(pts), np.full(len(pts), 0.0024), sides=4, cap_end=False)
            out.append(rigid(tv, tf, "accent"))
        for sx in (-1.0, 1.0):
            bv, bf = MB.box(c0 + np.array([sx * 0.104 * hs[0], -0.012, 0.004]), np.array([0.004, 0.035, 0.008]))
            out.append(rigid(bv, bf, "leather"))
    elif kind == "beret":
        v, f = dm((0.0, 0.086, 0.004), (0.114, 0.044, 0.118), lambda a: -50.0, hat=False, thick=0.008, n_el=8)
        pivot = c0 + np.array([0, 0.086, 0])
        v = (v - pivot) @ C.rot_z(-0.32).T + pivot + np.array([0.012, 0.0, 0.0])
        out.append(rigid(v, f, keyname))
        bv, bf = MB.box(c0 + np.array([-0.055, 0.074, -0.09]), np.array([0.011, 0.013, 0.004]))
        out.append(rigid(bv, bf, "metal"))
    elif kind == "knit":
        edge = lambda a: 16.0 - 20.0 * C.smoothstep(50.0, 140.0, abs(a))
        v, f = dm((0, 0.012, 0.006), (0.093, 0.122, 0.108), edge, thick=0.008, n_el=10)
        out.append(rigid(v, f, keyname))
        v, f = rim_band(c0 + np.array([0, 0.012, 0.006]), sc((0.1, 0.122, 0.115)), lambda a: edge(a) - 1.0, 15.0)
        out.append(rigid(v, f, keyname))
    elif kind in ("flatcap", "peaked"):
        if kind == "flatcap":
            v, f = dm((0, 0.04, -0.006), (0.104, 0.07, 0.122), lambda a: -10.0 if abs(a) > 60 else -16.0, thick=0.006, n_el=9, flare=0.06)
        else:
            v, f = dm((0, 0.066, 0.004), (0.104, 0.05, 0.108), lambda a: -62.0, thick=0.006, n_el=9)
        out.append(rigid(v, f, keyname))
        y0 = 0.035 if kind == "flatcap" else 0.038
        pv = []
        for i in range(9):
            t = -1.0 + 2.0 * i / 8
            x = t * 0.075 * hs[0]
            z_in = -0.1 * hs[2] * math.sqrt(max(0.0, 1.0 - (x / (0.106 * hs[0])) ** 2))
            depth = 0.055 * (1.0 - 0.55 * t * t)
            for dz, dy in ((0.0, 0.0), (-depth, -0.014)):
                for th in (0.0, -0.004):
                    pv.append(c0 + np.array([x, y0 + dy + th, z_in + dz]))
        pv = np.array(pv)
        pf = []
        for i in range(8):
            a, b = i * 4, (i + 1) * 4
            pf.append([a + 0, b + 0, b + 2, a + 2])   # top
            pf.append([a + 1, a + 3, b + 3, b + 1])   # underside
            pf.append([a + 2, b + 2, b + 3, a + 3])   # front edge
        out.append(rigid(pv, pf, "leather" if kind == "peaked" else keyname))
        if kind == "peaked":
            bv, bf = MB.box(c0 + np.array([0, 0.064, -0.108 * hs[2]]), np.array([0.012, 0.01, 0.003]))
            out.append(rigid(bv, bf, "brass"))
            v, f = rim_band(c0 + np.array([0, 0.066, 0.004]), sc((0.107, 0.05, 0.111)), lambda a: -62.0, 24.0)
            out.append(rigid(v, f, "leather"))
    elif kind == "kerchief":
        def edge(a):
            return 30.0 + (-58.0 - 30.0) * C.smoothstep(52.0, 85.0, abs(a))
        v, f = dm((0, 0.004, 0.006), (0.094, 0.124, 0.112), edge, thick=0.005, n_el=12, flare=0.05)
        out.append(rigid(v, f, keyname))
        kv, kf = MB.uv_sphere(c0 + np.array([0.0, -0.118, -0.03]), 0.016, 8, 5)
        out.append(rigid(kv, kf, keyname))
    elif kind == "sidecap":
        v, f = dm((0.008, 0.083, 0.004), (0.06, 0.056, 0.122), lambda a: -22.0, hat=False, thick=0.005, n_el=8)
        pivot = c0 + np.array([0, 0.083, 0])
        v = (v - pivot) @ C.rot_z(-0.12).T + pivot
        out.append(rigid(v, f, keyname))
    return out



def P_coat(y_lo, y_hi=1.545):
    """A coat's body: the trunk and the hip sides (thigh-dominant skin above the hem), not the arms."""
    return lambda b: np.isin(b.dom, list(TORSO | THIGHS)) & (b.v[:, 1] > y_lo) & (b.v[:, 1] < y_hi) & (b.region == 0) & (np.abs(b.v[:, 0]) < 0.24)

def P_palm():
    """The palm and the back of the hand, not the fingers (fingerless gloves)."""
    def f(b):
        wy = RIG.head["LeftHand"][1]
        return (b.region == 2) & (b.v[:, 1] > wy - 0.088)
    return f


def P_not_front_strip(pred, half_width, y_hi=1.47):
    return lambda b: pred(b) & ~((np.abs(b.v[:, 0]) < half_width) & (b.v[:, 2] < 0.0) & (b.v[:, 1] < y_hi))


def shoulders_push(amount):
    """Wider, squarer shoulders (a coat two sizes too big)."""
    def f(v, src, nrm):
        out = v.copy()
        k = C.smoothstep(1.28, 1.44, src[:, 1]) * C.smoothstep(0.09, 0.16, np.abs(src[:, 0]))
        out[:, 0] += np.sign(src[:, 0]) * amount * k
        out[:, 1] += 0.4 * amount * k
        return out
    return f


def buttons(k, piece, x, y0, n, step, keyname="dark", size=0.015):
    for i in range(n):
        k.add(pstud(piece, keyname, x, y0 - i * step, (size, size, 0.006)))


def stitches(k, body, ys_neck=(), wrist_y=None):
    """The Cousins' doll seams: a thin dark band at the neck and/or wrists."""
    for y in ys_neck:
        k.add(band(body, neck_pts(body), y, 0.005, "stitch", pad=0.0006, thick=0.0016))
    if wrist_y is not None:
        for side in ("Left", "Right"):
            k.add(cuff_band(body, side, wrist_y, 0.006, "stitch", pad=0.0015, thick=0.002, bones=("LowerArm", "Hand")))


def kit_dutch(body, P):
    k = Kit("dutch")
    jacket = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.92)), thick_by_y(0.021, 0.016), "cloth")
    k.add(band(body, neck_pts(body), 1.522, 0.062, "cloth", pad=0.014, thick=0.009))
    add_shell(k, body, P_legs(0.28, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.34), 0.013, "canvas", rim=0.006, push=boot_push())     # canvas leggings
    add_shell(k, body, P_boots(0.13), 0.019, "leather", rim=0.006, push=boot_push(0.014))
    add_shell(k, body, P_hands(), 0.0045, "glove", rim=0.0)
    for sx, side in ((-1, "Left"), (1, "Right")):
        k.add(cuff_band(body, side, 0.92, 0.035, "glove", pad=0.012, thick=0.006, bones=("LowerArm", "Hand")))           # glove gauntlets
        k.add(pstud(jacket, "cloth", sx * 0.075, 1.33, (0.075, 0.05, 0.007)))                # breast pocket flaps
    buttons(k, jacket, 0.012, 1.42, 4, 0.1)
    k.add(pstud(jacket, "cloth2", 0.0, 1.465, (0.075, 0.07, 0.004)))                         # the wool shirt at the collar
    k.add(band(body, trunk(jacket), 0.99, 0.055, "canvas", pad=0.003, thick=0.011))       # the BAR belt
    for i in range(6):
        k.add(pstud(jacket, "canvas", -0.14 + 0.056 * i, 0.99, (0.048, 0.075, 0.042)))     # magazine pouches
    k.add(pstud(jacket, "metal", 0.0, 0.99, (0.05, 0.04, 0.012)))
    for sx in (-1.0, 1.0):
        k.add(sash(jacket, (sx * 0.115, 1.45), (sx * 0.12, 1.03), 0.034, "canvas"))      # suspenders front
        k.add(sash(jacket, (sx * 0.09, 1.45), (sx * 0.11, 1.03), 0.034, "canvas", front=False))
    k.add(pstud(jacket, "canvas", 0.17, 0.94, (0.07, 0.12, 0.07)))                          # canteen
    k.add(pstud(jacket, "canvas", 0.0, 1.27, (0.27, 0.3, 0.1), front=False))                 # the pack
    for p in head_piece(P, "helmet", "helmet"):
        k.add(p)
    return k


def kit_peg(body, P):
    k = Kit("peg")
    smock = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.935)), thick_by_y(0.022, 0.017), "cloth")
    with_ao(smock, mottle(smock.v, 8.0, 0.38, 1.0) * mottle(smock.v, 13.0, 0.2, 4.0))
    sk = skirt(body, trunk(smock), 0.9, 0.7, "cloth", flare=0.12, ease=0.004, rings=5)
    k.add(with_ao(sk, mottle(sk.v, 8.0, 0.38, 1.0)))
    k.add(band(body, neck_pts(body), 1.522, 0.062, "cloth", pad=0.016, thick=0.01))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.945, 0.04, "cloth3", pad=0.012, thick=0.007, bones=("LowerArm", "Hand")))         # knitted smock cuffs
    add_shell(k, body, P_legs(0.22, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.21), 0.013, "canvas", push=boot_push())                    # anklets
    add_shell(k, body, P_boots(0.11), 0.017, "leather", push=boot_push(0.013))
    add_shell(k, body, P_hands(), 0.0045, "glove", rim=0.0)
    k.add(sash(smock, (0.11, 1.45), (-0.16, 1.0), 0.03, "leather"))                       # the cross strap
    k.add(sash(smock, (0.1, 1.45), (-0.16, 1.0), 0.03, "leather", front=False))
    for i in range(2):
        k.add(pstud(smock, "canvas", -0.15, 0.9 + 0.1 * i, (0.1, 0.11, 0.075)))            # satchel charges
    k.add(pstud(smock, "leather", 0.15, 0.93, (0.06, 0.12, 0.05)))                          # holster
    k.add(cuff_band(body, "Left", 0.905, 0.016, "leather", pad=0.016, thick=0.004, bones=("LowerArm", "Hand")))       # wristwatch
    for p in head_piece(P, "beret", "hat"):
        k.add(p)
    return k


def kit_deacon(body, P):
    k = Kit("deacon")
    cov = add_shell(k, body, P_or(P_coat(0.85), P_arms(0.92), P_legs(0.28, 1.0)), lambda p: np.where(np.abs(p[:, 0]) > 0.2, 0.012, 0.013), "cloth")
    with_ao(cov, mottle(cov.v, 7.0, 0.45, 2.3, 0.08))                                     # grease stains
    k.add(band(body, neck_pts(body), 1.512, 0.052, "cloth", pad=0.012, thick=0.008))
    k.add(pstud(cov, "white", 0.0, 1.43, (0.07, 0.07, 0.004)))                              # the undershirt at the open collar
    k.add(pstud(cov, "cloth2", 0.0, 1.2, (0.022, 0.38, 0.006)))                             # the placket
    for sx in (-1, 1):
        k.add(pstud(cov, "cloth2", sx * 0.075, 1.3, (0.085, 0.1, 0.008)))
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.93, 0.04, "cloth", pad=0.013, thick=0.006, bones=("LowerArm", "Hand")))   # rolled cuffs
    k.add(band(body, trunk(cov), 0.99, 0.05, "leather", pad=0.002, thick=0.008))
    k.add(pstud(cov, "metal", 0.15, 0.9, (0.026, 0.25, 0.012)))                             # the wrench
    k.add(pstud(cov, "metal", 0.15, 0.77, (0.07, 0.045, 0.014)))
    k.add(pstud(cov, "leather", -0.15, 0.93, (0.09, 0.09, 0.06)))                            # tool pouch
    k.add(pstud(cov, "accent", -0.07, 0.88, (0.07, 0.12, 0.02), front=False))              # the rag
    add_shell(k, body, P_boots(0.3), 0.016, "leather", rim=0.008, push=boot_push())
    for p in head_piece(P, "knit", "knit"):
        k.add(p)
    return k


def kit_wren(body, P):
    k = Kit("wren")
    smock = add_shell(k, body, P_or(P_coat(0.8), P_arms(0.935)), thick_by_y(0.025, 0.02), "cloth")
    with_ao(smock, mottle(smock.v, 6.0, 0.12, 3.0))
    sk = skirt(body, trunk(smock), 0.9, 0.66, "cloth", flare=0.14, ease=0.005, rings=5)
    k.add(with_ao(sk, mottle(sk.v, 6.0, 0.12, 3.0)))
    k.add(band(body, trunk(smock), 1.02, 0.03, "cloth3", pad=0.002, thick=0.006))         # the drawstring
    k.add(band(body, neck_pts(body), 1.512, 0.087, "cloth", pad=0.032, thick=0.018))      # the hood, down
    k.add(band(body, neck_pts(body), 1.535, 0.06, "accent", pad=0.02, thick=0.016))       # the scarf
    k.add(pstud(smock, "accent", -0.06, 1.36, (0.06, 0.22, 0.014), tilt=0.12))             # its tail
    k.add(cuff_band(body, "Left", 1.3, 0.032, "white", pad=0.02, thick=0.004, bones=("UpperArm",)))      # the AK armband
    k.add(cuff_band(body, "Left", 1.268, 0.032, "armband", pad=0.02, thick=0.004, bones=("UpperArm",)))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.935, 0.04, "knit", pad=0.012, thick=0.007, bones=("LowerArm", "Hand")))           # sweater cuffs
    add_shell(k, body, P_palm(), 0.004, "glove", rim=0.0)                                   # fingerless gloves
    add_shell(k, body, P_legs(0.22, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.29), 0.015, "leather", rim=0.008, push=boot_push())
    k.add(band(body, trunk(smock), 0.97, 0.035, "leather", pad=0.001, thick=0.006))
    k.add(pstud(smock, "patch", -0.15, 0.91, (0.08, 0.11, 0.025)))                           # the stained notebook
    k.add(sash(smock, (-0.1, 1.45), (0.16, 1.02), 0.026, "leather"))                       # the rifle sling
    k.add(sash(smock, (-0.1, 1.45), (0.16, 1.02), 0.026, "leather", front=False))
    for p in head_piece(P, "knit", "knit"):
        k.add(p)
    return k


def kit_jakub(body, P):
    k = Kit("jakub")
    shirt = add_shell(k, body, P_coat(0.86), 0.008, "cloth3")
    coat = add_shell(k, body, P_not_front_strip(P_or(P_coat(0.84), P_arms(0.905)), 0.05), thick_by_y(0.03, 0.025), "cloth", push=shoulders_push(0.022))
    sk = skirt(body, trunk(coat), 0.88, 0.42, "cloth", flare=0.3, ease=0.012)
    k.add(cut_front(sk, 0.075))
    k.add(band(body, neck_pts(body), 1.532, 0.107, "cloth", pad=0.03, thick=0.016))      # the collar turned up
    for sx in (-1.0, 1.0):
        buttons(k, coat, sx * 0.105, 1.36, 3, 0.11, "metal", 0.017)
    k.add(band(body, trunk(shirt), 0.985, 0.04, "leather", pad=0.002, thick=0.006))
    k.add(pstud(shirt, "metal", 0.03, 0.94, (0.012, 0.09, 0.012)))                           # the empty lamp hook
    add_shell(k, body, P_legs(0.16, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.22), 0.015, "leather", rim=0.008, push=boot_push())
    for p in head_piece(P, "flatcap", "hat"):
        k.add(p)
    return k


def kit_rother(body, P):
    k = Kit("rother")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.024, 0.019), "cloth")
    with_ao(coat, mottle(coat.v, 6.0, 0.15, 5.0))
    k.add(skirt(body, trunk(coat), 0.9, 0.66, "cloth", flare=0.18, ease=0.006, rings=5))
    buttons(k, coat, 0.012, 1.36, 4, 0.1)
    k.add(band(body, neck_pts(body), 1.53, 0.07, "knit", pad=0.022, thick=0.018))        # the scarf
    k.add(pstud(coat, "knit", 0.05, 1.37, (0.06, 0.18, 0.016), tilt=-0.1))
    add_shell(k, body, P_legs(0.24, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.3), 0.016, "leather", rim=0.008, push=boot_push())
    for p in head_piece(P, "flatcap", "hat"):
        k.add(p)
    return k


def kit_kubiak(body, P):
    k = Kit("kubiak")
    jacket = add_shell(k, body, P_or(P_coat(0.88), P_arms(0.91)), thick_by_y(0.017, 0.013), "cloth")
    k.add(band(body, neck_pts(body), 1.512, 0.057, "cloth3", pad=0.012, thick=0.008))
    k.add(pstud(jacket, "cloth3", 0.0, 1.42, (0.06, 0.07, 0.004)))                           # the shirt at the collar
    buttons(k, jacket, 0.012, 1.32, 3, 0.1)
    for sx in (-1, 1):
        k.add(pstud(jacket, "cloth2", sx * 0.09, 1.04, (0.09, 0.07, 0.006)))
    add_shell(k, body, P_legs(0.15, 0.98), 0.009, "cloth2")
    add_shell(k, body, P_boots(0.2), 0.013, "leather", push=boot_push())
    k.add(band(body, trunk(jacket), 0.97, 0.03, "leather", pad=0.001, thick=0.005))
    return k


def kit_pohl(body, P):
    k = Kit("pohl")
    coat = add_shell(k, body, P_or(P_coat(0.85), P_arms(0.905)), thick_by_y(0.02, 0.016), "cloth")
    k.add(skirt(body, trunk(coat), 0.9, 0.3, "cloth", flare=0.34, ease=0.006))
    buttons(k, coat, 0.0, 1.38, 5, 0.09)
    k.add(band(body, neck_pts(body), 1.542, 0.072, "knit", pad=0.02, thick=0.016))         # a wool scarf
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "cloth2", rim=0.0)                         # stockings
    add_shell(k, body, P_boots(0.11), 0.009, "leather", push=boot_push(0.009))
    for p in head_piece(P, "kerchief", "hat"):
        k.add(p)
    return k


def kit_trudi(body, P):
    k = Kit("trudi")
    blouse = add_shell(k, body, P_or(P_coat(0.92), P_arms(0.92)), thick_by_y(0.008, 0.008), "cloth")
    bodice = add_shell(k, body, P_torso(0.95, 1.4), 0.015, "cloth2", cover=False)
    k.add(band(body, neck_pts(body), 1.522, 0.052, "cloth", pad=0.012, thick=0.008))
    sk = skirt(body, trunk(blouse), 0.98, 0.1, "cloth3", flare=0.32, ease=0.012)
    k.add(sk)
    pan = shell(BodyLike(sk), lambda b: (b.v[:, 2] < -0.02) & (np.abs(b.v[:, 0]) < 0.16) & (b.v[:, 1] > 0.3), 0.004, "white", 0.0)[0]
    k.add(pan)
    k.add(band(body, trunk(bodice), 0.98, 0.03, "white", pad=0.004, thick=0.005))          # apron strings
    for i in range(4):
        k.add(pstud(bodice, "dark", 0.0, 1.32 - i * 0.07, (0.012, 0.012, 0.005)))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    add_shell(k, body, P_boots(0.11), 0.009, "leather", push=boot_push(0.009))
    return k


def kit_sobotta(body, P):
    k = Kit("sobotta")
    tunic = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.018, 0.014), "cloth")
    k.add(skirt(body, trunk(tunic), 0.92, 0.76, "cloth", flare=0.1, ease=0.003, rings=4))
    k.add(band(body, neck_pts(body), 1.522, 0.067, "cloth2", pad=0.016, thick=0.01))
    buttons(k, tunic, 0.0, 1.4, 4, 0.1, "metal")
    for sx in (-1, 1):
        k.add(pstud(tunic, "dark", sx * 0.045, 1.475, (0.028, 0.038, 0.007), tilt=sx * 0.3))   # plain collar tabs
        k.add(pstud(tunic, "cloth", sx * 0.08, 1.32, (0.08, 0.05, 0.008)))
        k.add(pstud(tunic, "cloth", sx * 0.09, 0.93, (0.09, 0.05, 0.008)))
    k.add(band(body, trunk(tunic), 0.99, 0.05, "leather", pad=0.002, thick=0.008))
    k.add(pstud(tunic, "metal", 0.0, 0.99, (0.05, 0.042, 0.012)))
    add_shell(k, body, P_legs(0.36, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.43), 0.015, "leather", rim=0.008, push=boot_push())      # jackboots
    for p in head_piece(P, "sidecap", "hat"):
        k.add(p)
    return k


def kit_wiesner(body, P):
    k = Kit("wiesner")
    jacket = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.019, 0.015), "cloth")
    k.add(skirt(body, trunk(jacket), 0.92, 0.76, "cloth", flare=0.12, ease=0.004, rings=4))
    for sx in (-1.0, 1.0):
        buttons(k, jacket, sx * 0.06, 1.38, 4, 0.1, "brass", 0.016)                       # double-breasted
    k.add(band(body, neck_pts(body), 1.53, 0.065, "knit", pad=0.02, thick=0.016))
    add_shell(k, body, P_legs(0.24, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.3), 0.015, "leather", rim=0.008, push=boot_push())
    for p in head_piece(P, "peaked", "hat"):
        k.add(p)
    return k


def kit_brandt(body, P):
    k = Kit("brandt")
    coat = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.905)), thick_by_y(0.017, 0.014), "cloth")
    k.add(skirt(body, trunk(coat), 0.92, 0.66, "cloth", flare=0.3, ease=0.016, rings=5))
    k.add(skirt(body, trunk(coat), 0.9, 0.16, "cloth2", flare=0.26, ease=0.006))
    buttons(k, coat, 0.0, 1.36, 4, 0.09)
    k.add(band(body, neck_pts(body), 1.522, 0.047, "white", pad=0.012, thick=0.008))
    k.add(band(body, neck_pts(body), 1.535, 0.055, "knit", pad=0.02, thick=0.015))
    k.add(pstud(coat, "knit", -0.045, 1.38, (0.055, 0.17, 0.014), tilt=0.12))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    add_shell(k, body, P_boots(0.12), 0.009, "leather", push=boot_push(0.009))
    return k


def kit_kroll(body, P):
    k = Kit("kroll")
    jacket = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.91)), thick_by_y(0.016, 0.013), "cloth")
    k.add(skirt(body, trunk(jacket), 0.94, 0.28, "cloth2", flare=0.26, ease=0.006))
    buttons(k, jacket, 0.0, 1.4, 5, 0.09, "brass", 0.014)
    k.add(band(body, neck_pts(body), 1.522, 0.057, "cloth", pad=0.014, thick=0.008))
    k.add(sash(jacket, (0.1, 1.45), (-0.16, 0.99), 0.032, "leather"))                     # the post satchel's strap
    k.add(sash(jacket, (0.1, 1.45), (-0.16, 0.99), 0.032, "leather", front=False))
    k.add(pstud(jacket, "leather", -0.15, 0.9, (0.18, 0.16, 0.07)))                         # the satchel
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    add_shell(k, body, P_boots(0.24), 0.013, "leather", rim=0.006, push=boot_push())
    for p in head_piece(P, "kerchief", "hat"):
        k.add(p)
    return k


def kit_cousin_hammer(body, P):
    k = Kit("cousin_hammer")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.925)), thick_by_y(0.032, 0.027), "cloth", push=shoulders_push(0.024))
    k.add(skirt(body, trunk(coat), 0.88, 0.42, "cloth", flare=0.36, ease=0.014))
    k.add(skirt(body, trunk(coat), 0.9, 0.08, "cloth2", flare=0.3, ease=0.006))              # the long wool skirt
    buttons(k, coat, 0.0, 1.46, 5, 0.1, "metal", 0.018)                                      # buttoned to the throat
    k.add(band(body, neck_pts(body), 1.537, 0.082, "cloth", pad=0.022, thick=0.014))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.97, 0.09, "cloth3", pad=0.03, thick=0.012, bones=("LowerArm", "Hand")))           # sleeves turned back twice
    add_shell(k, body, P_hands(), 0.011, "knit", rim=0.0)                                   # red mittens
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.885, 0.035, "white", pad=0.016, thick=0.008, bones=("LowerArm", "Hand")))         # their grey cuffs
    add_shell(k, body, P_boots(0.2), 0.013, "leather", rim=0.006, push=boot_push())
    stitches(k, body, ys_neck=(1.585,))
    return k


def kit_cousin_reach(body, P):
    k = Kit("cousin_reach")
    gown = add_shell(k, body, P_or(P_coat(0.85), P_arms(1.15)), thick_by_y(0.009, 0.009), "cloth")
    k.add(skirt(body, trunk(gown), 0.95, 0.05, "cloth", flare=0.24, ease=0.008))               # to the ankle
    k.add(band(body, neck_pts(body), 1.542, 0.082, "cloth", pad=0.012, thick=0.008))         # the high collar
    card = add_shell(k, body, P_or(P_torso(0.9, 1.49), P_arms(1.17)), thick_by_y(0.021, 0.018), "knit", cover=False)
    k.add(band(body, trunk(card), 0.91, 0.04, "knit", pad=0.004, thick=0.008))
    buttons(k, card, 0.0, 1.38, 5, 0.1, "metal", 0.015)
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 1.17, 0.02, "cloth2", pad=0.016, thick=0.004, bones=("UpperArm", "LowerArm")))   # the torn sleeve edge
    stitches(k, body, ys_neck=(1.585,), wrist_y=0.9)
    return k


def kit_cousin_alix(body, P):
    k = Kit("cousin_alix")
    dress = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.92)), thick_by_y(0.012, 0.012), "cloth")
    k.add(skirt(body, trunk(dress), 0.97, 0.36, "cloth", flare=0.3, ease=0.016))            # below the knee
    k.add(band(body, neck_pts(body), 1.527, 0.047, "white", pad=0.014, thick=0.008))       # the white collar
    for sx in (-1.0, 1.0):
        k.add(pstud(dress, "white", sx * 0.045, 1.465, (0.075, 0.03, 0.005), tilt=sx * 0.35))
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.935, 0.03, "white", pad=0.014, thick=0.006, bones=("LowerArm", "Hand")))
    # the wide red ribbon bow at the breastbone (it hides the root of the third arm)
    for sx in (-1.0, 1.0):
        k.add(pstud(dress, "accent", sx * 0.045, 1.3, (0.075, 0.06, 0.02), tilt=sx * 0.45))
        k.add(pstud(dress, "accent", sx * 0.022, 1.235, (0.024, 0.085, 0.012), tilt=sx * 0.25))
    k.add(pstud(dress, "accent", 0.0, 1.3, (0.03, 0.032, 0.026)))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "cloth3", rim=0.0)                          # dark stockings
    add_shell(k, body, P_boots(0.1), 0.009, "leather", push=boot_push(0.009))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.075, 0.012, "leather", pad=0.01, thick=0.004, bones=("LowerLeg", "Foot")))   # shoe straps
    stitches(k, body, ys_neck=(1.585,))
    return k


PEOPLE_KITS = {
    "dutch": kit_dutch, "peg": kit_peg, "deacon": kit_deacon, "wren": kit_wren, "jakub": kit_jakub,
    "rother": kit_rother, "kubiak": kit_kubiak, "pohl": kit_pohl, "trudi": kit_trudi, "sobotta": kit_sobotta,
    "wiesner": kit_wiesner, "brandt": kit_brandt, "kroll": kit_kroll,
    "cousin_hammer": kit_cousin_hammer, "cousin_reach": kit_cousin_reach, "cousin_alix": kit_cousin_alix,
}
