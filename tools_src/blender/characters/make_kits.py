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


# ================================================================== T-134: finishing detail
# Small garment features laid on the people's kits by ray (pstud / sash): pocket bags with flaps and buttons, buckle
# frames with a prong and the strap's end, belt keepers, raised seams and welts, collar points, cuffs, plain
# insignia-free patches, boot soles, eyelets and laces; and vertex-colour grime (.g AO) at hems and soles. All of it
# skins to the garment it sits on (the nearest vertex's weights), so the rig, the hitboxes and the animation stay.

def ao_of(piece):
    return getattr(piece, "ao", None) if getattr(piece, "ao", None) is not None else np.ones(len(piece.v))


def grime(piece, y_hem, rise=0.14, depth=0.3, seed=3.0):
    """Darker toward a hem (mud, dust, wear), broken up by a blotchy noise."""
    if piece is None:
        return None
    t = 1.0 - C.smoothstep(y_hem, y_hem + rise, piece.v[:, 1])
    blot = 0.75 + 0.25 * mottle(piece.v, 26.0, 1.0, seed, 0.3)
    return with_ao(piece, ao_of(piece) * (1.0 - depth * t * blot))


def scuff(piece, depth=0.12, seed=5.0):
    """Leather grain / scuffing: a fine blotchy darkening over the whole piece."""
    if piece is None:
        return None
    return with_ao(piece, ao_of(piece) * mottle(piece.v, 34.0, depth, seed, 0.25) * mottle(piece.v, 61.0, depth * 0.6, seed + 2.0, 0.2))


def pocket(k, piece, x, y, w, h, key, button="dark", front=True, tilt=0.0, bag=True):
    """A patch pocket: the bag, a flap over its top standing proud of the bag, a button on the flap."""
    if bag:
        k.add(pstud(piece, key, x, y - h * 0.16, (w * 0.92, h * 0.84, 0.0055), front, tilt))
    k.add(pstud(piece, key, x, y + h * 0.3, (w, h * 0.36, 0.0085), front, tilt))
    if button:
        k.add(pstud(piece, button, x, y + h * 0.2, (0.0105, 0.0105, 0.0115), front))


def buckle(k, piece, x, y, w=0.05, h=0.042, key="metal", depth=0.017, tongue="leather", front=True):
    """An open frame buckle (four bars and a prong) with the strap's end through it. Plain: no badge, no emblem."""
    b = 0.0065
    for dx, dy, sw, sh in ((0.0, h / 2 - b / 2, w, b), (0.0, -h / 2 + b / 2, w, b), (-w / 2 + b / 2, 0.0, b, h), (w / 2 - b / 2, 0.0, b, h)):
        k.add(pstud(piece, key, x + dx, y + dy, (sw, sh, depth), front))
    k.add(pstud(piece, key, x - w * 0.08, y, (0.0035, h * 0.84, depth + 0.002), front))
    if tongue:
        k.add(pstud(piece, tongue, x + (w * 0.9 if front else -w * 0.9), y, (w * 0.75, h * 0.6, depth - 0.004), front))


def keepers(k, piece, y, h, xs, key, depth=0.016, front=True):
    """Belt loops / strap keepers: short upright bands over a belt."""
    for x in xs:
        k.add(pstud(piece, key, x, y, (0.011, h + 0.012, depth), front))


def welt(k, piece, a, b, key, front=True, width=0.0065, thick=0.0024):
    """A raised seam or welt laid along a garment (a = (x, y) to b)."""
    k.add(sash(piece, a, b, width, key, front, thick=thick, n=10))


def collar_points(k, piece, key, y=1.468, dx=0.047, w=0.058, h=0.036, tilt=0.55, depth=0.011):
    for sx in (-1.0, 1.0):
        k.add(pstud(piece, key, sx * dx, y, (w, h, depth), tilt=sx * tilt))


def cuffs(k, body, y, key, pad, h=0.032, thick=0.005):
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, y, h, key, pad=pad, thick=thick, bones=("LowerArm", "Hand")))


def back_seams(k, piece, key, y_top=1.47, y_hem=0.9, yoke=1.38):
    """The centre back seam and the yoke across the shoulder blades."""
    welt(k, piece, (0.0, y_top), (0.0, y_hem), key, front=False)
    welt(k, piece, (-0.16, yoke), (0.16, yoke), key, front=False)


def leg_x(body, side, y):
    sel = np.isin(body.dom, [BI[side + "LowerLeg"], BI[side + "Foot"]]) & (np.abs(body.v[:, 1] - y) < 0.025) & (body.region == 0)
    p = body.v[sel]
    return float(p[:, 0].mean()) if len(p) else None


def boots_finish(k, body, boots, top, laced=True, sole="rubber", sole_pad=0.017, rows=None, lace="dark", eyelet="metal"):
    """Soles (a welt band round each foot), eyelets and crossed laces up the front, grime and scuffing."""
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.011, 0.02, sole, pad=sole_pad, thick=0.0045, nb=24, bones=("LowerLeg", "Foot")))
        if not laced or boots is None:
            continue
        x = leg_x(body, side, 0.14)
        if x is None:
            continue
        ys = list(rows) if rows is not None else [float(y) for y in np.arange(0.105, top - 0.018, 0.023)]
        for i, y in enumerate(ys):
            for dx in (-0.0125, 0.0125):
                k.add(pstud(boots, eyelet, x + dx, y, (0.0055, 0.0055, 0.0075)))
            k.add(pstud(boots, lace, x, y + 0.0055, (0.029, 0.0042, 0.0065), tilt=0.38 if i % 2 else -0.38))
        if ys:
            k.add(pstud(boots, lace, x + 0.009, ys[-1] - 0.012, (0.0045, 0.028, 0.0068), tilt=0.15))   # the tied ends
    scuff(boots, 0.14)
    grime(boots, 0.0, 0.08, 0.35, 7.0)


def trousers_finish(k, piece, hem, depth=0.28):
    grime(piece, hem, 0.2, depth, 2.0)


def kit_dutch(body, P):
    k = Kit("dutch")
    jacket = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.92)), thick_by_y(0.021, 0.016), "cloth")
    k.add(band(body, neck_pts(body), 1.522, 0.062, "cloth", pad=0.014, thick=0.009))
    collar_points(k, jacket, "cloth")
    legs = add_shell(k, body, P_legs(0.28, 0.98), 0.01, "cloth2")
    leggings = add_shell(k, body, P_boots(0.34), 0.013, "canvas", rim=0.006, push=boot_push())     # canvas leggings
    boots = add_shell(k, body, P_boots(0.13), 0.019, "leather", rim=0.006, push=boot_push(0.014))
    add_shell(k, body, P_hands(), 0.0045, "glove", rim=0.0)
    for sx, side in ((-1, "Left"), (1, "Right")):
        k.add(cuff_band(body, side, 0.92, 0.035, "glove", pad=0.012, thick=0.006, bones=("LowerArm", "Hand")))           # glove gauntlets
        pocket(k, jacket, sx * 0.075, 1.33, 0.075, 0.1, "cloth", "dark")                       # breast pockets
        pocket(k, jacket, sx * 0.1, 1.1, 0.085, 0.1, "cloth", "dark")                          # skirt pockets above the belt
    buttons(k, jacket, 0.012, 1.42, 4, 0.1)
    welt(k, jacket, (0.022, 1.46), (0.022, 1.03), "cloth")                                     # the button placket
    back_seams(k, jacket, "cloth", y_hem=1.03)
    k.add(pstud(jacket, "cloth2", 0.0, 1.465, (0.075, 0.07, 0.004)))                         # the wool shirt at the collar
    k.add(pstud(jacket, "cloth2", -0.19, 1.34, (0.045, 0.055, 0.007)))                       # a plain shoulder patch (no insignia)
    k.add(band(body, trunk(jacket), 0.99, 0.055, "canvas", pad=0.003, thick=0.011))       # the BAR belt
    for i in range(6):
        px = -0.14 + 0.056 * i
        if abs(px) < 0.03:
            continue
        k.add(pstud(jacket, "canvas", px, 0.99, (0.048, 0.075, 0.042)))                   # magazine pouches
        k.add(pstud(jacket, "canvas", px, 1.018, (0.05, 0.03, 0.046)))                     # their flaps
        k.add(pstud(jacket, "metal", px, 1.01, (0.008, 0.008, 0.049)))                     # the lift-the-dot snaps
    buckle(k, jacket, 0.0, 0.99, 0.052, 0.046, "metal", 0.02, tongue="")
    for sx in (-1.0, 1.0):
        k.add(sash(jacket, (sx * 0.115, 1.45), (sx * 0.12, 1.03), 0.034, "canvas"))      # suspenders front
        k.add(sash(jacket, (sx * 0.09, 1.45), (sx * 0.11, 1.03), 0.034, "canvas", front=False))
        k.add(pstud(jacket, "metal", sx * 0.12, 1.04, (0.026, 0.016, 0.02)))              # their hooks into the belt
        k.add(pstud(jacket, "metal", sx * 0.117, 1.25, (0.03, 0.012, 0.012)))             # the adjuster slides
    k.add(pstud(jacket, "canvas", 0.17, 0.94, (0.07, 0.12, 0.07)))                          # canteen
    k.add(pstud(jacket, "canvas", 0.17, 0.985, (0.074, 0.032, 0.074)))                      # its cover flap
    k.add(pstud(jacket, "metal", 0.17, 0.98, (0.009, 0.009, 0.077)))
    k.add(pstud(jacket, "canvas", -0.17, 0.95, (0.06, 0.08, 0.045)))                        # the first-aid pouch
    k.add(pstud(jacket, "canvas", 0.0, 1.27, (0.27, 0.3, 0.1), front=False))                 # the pack
    k.add(pstud(jacket, "canvas", 0.0, 1.39, (0.28, 0.08, 0.108), front=False))              # its flap
    for sx in (-1.0, 1.0):
        k.add(pstud(jacket, "canvas", sx * 0.08, 1.2, (0.03, 0.17, 0.104), front=False))     # its straps
        k.add(pstud(jacket, "metal", sx * 0.08, 1.31, (0.032, 0.024, 0.108), front=False))   # and buckles
    for side in ("Left", "Right"):
        x = leg_x(body, side, 0.22)
        if x is not None:
            for y in (0.17, 0.22, 0.27, 0.32):
                k.add(pstud(leggings, "metal", x + (0.03 if side == "Right" else -0.03), y, (0.006, 0.006, 0.006)))   # legging hooks
    boots_finish(k, body, boots, 0.13, rows=(0.1,))
    trousers_finish(k, legs, 0.34)
    grime(leggings, 0.12, 0.18, 0.3, 4.0)
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
    collar_points(k, smock, "cloth", dx=0.05)
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.945, 0.04, "cloth3", pad=0.012, thick=0.007, bones=("LowerArm", "Hand")))         # knitted smock cuffs
    for sx in (-1.0, 1.0):
        pocket(k, smock, sx * 0.08, 1.31, 0.08, 0.1, "cloth", "dark", tilt=sx * 0.12)          # slanted chest pockets
    welt(k, smock, (0.0, 1.47), (0.0, 1.12), "metal", width=0.008)                          # the front zip
    k.add(pstud(smock, "metal", 0.0, 1.455, (0.01, 0.022, 0.01)))                           # its pull
    back_seams(k, smock, "cloth", y_hem=0.92)
    legs = add_shell(k, body, P_legs(0.22, 0.98), 0.01, "cloth2")
    add_shell(k, body, P_boots(0.21), 0.013, "canvas", push=boot_push())                    # anklets
    boots = add_shell(k, body, P_boots(0.11), 0.017, "leather", push=boot_push(0.013))
    add_shell(k, body, P_hands(), 0.0045, "glove", rim=0.0)
    k.add(sash(smock, (0.11, 1.45), (-0.16, 1.0), 0.03, "leather"))                       # the cross strap
    k.add(sash(smock, (0.1, 1.45), (-0.16, 1.0), 0.03, "leather", front=False))
    buckle(k, smock, 0.04, 1.27, 0.038, 0.034, "metal", 0.016, tongue="", )                 # its buckle
    for i in range(2):
        y = 0.9 + 0.1 * i
        k.add(pstud(smock, "canvas", -0.15, y, (0.1, 0.11, 0.075)))                          # satchel charges
        k.add(pstud(smock, "canvas", -0.15, y + 0.035, (0.104, 0.04, 0.079)))               # their flaps
        k.add(pstud(smock, "leather", -0.15, y, (0.018, 0.112, 0.081)))                      # the strap round each
    k.add(pstud(smock, "leather", 0.15, 0.93, (0.06, 0.12, 0.05)))                          # holster
    k.add(pstud(smock, "leather", 0.15, 0.975, (0.064, 0.04, 0.054)))                       # its flap
    k.add(pstud(smock, "metal", 0.15, 0.965, (0.009, 0.009, 0.057)))
    k.add(cuff_band(body, "Left", 0.905, 0.016, "leather", pad=0.016, thick=0.004, bones=("LowerArm", "Hand")))       # wristwatch
    boots_finish(k, body, boots, 0.11, rows=(0.085,))
    trousers_finish(k, legs, 0.22)
    for p in head_piece(P, "beret", "hat"):
        k.add(p)
    return k


def kit_deacon(body, P):
    k = Kit("deacon")
    cov = add_shell(k, body, P_or(P_coat(0.85), P_arms(0.92), P_legs(0.28, 1.0)), lambda p: np.where(np.abs(p[:, 0]) > 0.2, 0.012, 0.013), "cloth")
    with_ao(cov, mottle(cov.v, 7.0, 0.45, 2.3, 0.08))                                     # grease stains
    grime(cov, 0.3, 0.2, 0.3, 6.0)
    k.add(band(body, neck_pts(body), 1.512, 0.052, "cloth", pad=0.012, thick=0.008))
    collar_points(k, cov, "cloth", y=1.46, dx=0.05)
    k.add(pstud(cov, "white", 0.0, 1.43, (0.07, 0.07, 0.004)))                              # the undershirt at the open collar
    k.add(pstud(cov, "cloth2", 0.0, 1.2, (0.022, 0.38, 0.006)))                             # the placket
    for i in range(4):
        k.add(pstud(cov, "metal", 0.0, 1.36 - i * 0.085, (0.012, 0.012, 0.009)))             # its snaps
    for sx in (-1, 1):
        k.add(pstud(cov, "cloth2", sx * 0.075, 1.3, (0.085, 0.1, 0.008)))
        k.add(pstud(cov, "cloth2", sx * 0.075, 1.34, (0.088, 0.035, 0.011)))                  # pocket flaps
        k.add(pstud(cov, "metal", sx * 0.075, 1.335, (0.01, 0.01, 0.013)))
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.93, 0.04, "cloth", pad=0.013, thick=0.006, bones=("LowerArm", "Hand")))   # rolled cuffs
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.955, 0.012, "cloth", pad=0.019, thick=0.004, bones=("LowerArm", "Hand")))
        k.add(pstud(cov, "cloth2", sx * 0.095, 0.52, (0.09, 0.11, 0.006)))                   # knee patches
        k.add(pstud(cov, "cloth", sx * 0.12, 0.8, (0.07, 0.09, 0.006)))                       # thigh pockets
    welt(k, cov, (-0.1, 0.92), (-0.1, 0.32), "cloth")                                          # leg seams
    welt(k, cov, (0.1, 0.92), (0.1, 0.32), "cloth")
    back_seams(k, cov, "cloth", y_hem=1.0)
    k.add(band(body, trunk(cov), 0.99, 0.05, "leather", pad=0.002, thick=0.008))
    buckle(k, cov, 0.0, 0.99, 0.05, 0.044, "metal", 0.017)
    keepers(k, cov, 0.99, 0.05, (-0.09, 0.09), "leather")
    k.add(pstud(cov, "metal", 0.15, 0.9, (0.026, 0.25, 0.012)))                             # the wrench
    k.add(pstud(cov, "metal", 0.15, 0.77, (0.07, 0.045, 0.014)))
    k.add(pstud(cov, "leather", -0.15, 0.93, (0.09, 0.09, 0.06)))                            # tool pouch
    k.add(pstud(cov, "leather", -0.15, 0.965, (0.094, 0.035, 0.064)))                        # its flap
    k.add(pstud(cov, "metal", -0.15, 0.955, (0.01, 0.01, 0.067)))
    k.add(pstud(cov, "metal", -0.13, 0.99, (0.006, 0.07, 0.068)))                            # a screwdriver in it
    k.add(pstud(cov, "accent", -0.07, 0.88, (0.07, 0.12, 0.02), front=False))              # the rag
    boots = add_shell(k, body, P_boots(0.3), 0.016, "leather", rim=0.008, push=boot_push())
    boots_finish(k, body, boots, 0.3)
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
    k.add(pstud(smock, "cloth3", 0.03, 0.97, (0.006, 0.08, 0.012), tilt=0.1))               # its ends
    k.add(pstud(smock, "cloth3", 0.045, 0.975, (0.006, 0.07, 0.012), tilt=-0.15))
    k.add(band(body, neck_pts(body), 1.512, 0.087, "cloth", pad=0.032, thick=0.018))      # the hood, down
    k.add(band(body, neck_pts(body), 1.535, 0.06, "accent", pad=0.02, thick=0.016))       # the scarf
    k.add(pstud(smock, "accent", -0.06, 1.36, (0.06, 0.22, 0.014), tilt=0.12))             # its tail
    k.add(pstud(smock, "accent", -0.068, 1.245, (0.064, 0.012, 0.016), tilt=0.12))         # its fringe
    k.add(cuff_band(body, "Left", 1.3, 0.032, "white", pad=0.02, thick=0.004, bones=("UpperArm",)))      # the AK armband
    k.add(cuff_band(body, "Left", 1.268, 0.032, "armband", pad=0.02, thick=0.004, bones=("UpperArm",)))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.935, 0.04, "knit", pad=0.012, thick=0.007, bones=("LowerArm", "Hand")))           # sweater cuffs
    for sx in (-1.0, 1.0):
        pocket(k, smock, sx * 0.09, 1.08, 0.1, 0.11, "cloth", "dark")                          # the smock's big pockets
    pocket(k, smock, 0.075, 1.32, 0.07, 0.085, "cloth", "dark")
    back_seams(k, smock, "cloth", y_hem=0.94)
    add_shell(k, body, P_palm(), 0.004, "glove", rim=0.0)                                   # fingerless gloves
    legs = add_shell(k, body, P_legs(0.22, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.29), 0.015, "leather", rim=0.008, push=boot_push())
    k.add(band(body, trunk(smock), 0.97, 0.035, "leather", pad=0.001, thick=0.006))
    buckle(k, smock, 0.0, 0.97, 0.04, 0.034, "metal", 0.014)
    k.add(pstud(smock, "patch", -0.15, 0.91, (0.08, 0.11, 0.025)))                           # the stained notebook
    k.add(pstud(smock, "leather", -0.15, 0.91, (0.012, 0.113, 0.027)))                       # its strap
    k.add(sash(smock, (-0.1, 1.45), (0.16, 1.02), 0.026, "leather"))                       # the rifle sling
    k.add(sash(smock, (-0.1, 1.45), (0.16, 1.02), 0.026, "leather", front=False))
    k.add(pstud(smock, "metal", 0.03, 1.24, (0.03, 0.02, 0.012), tilt=-0.6))                # the sling's slide
    boots_finish(k, body, boots, 0.29)
    trousers_finish(k, legs, 0.29)
    for p in head_piece(P, "knit", "knit"):
        k.add(p)
    return k


def kit_jakub(body, P):
    k = Kit("jakub")
    shirt = add_shell(k, body, P_coat(0.86), 0.008, "cloth3")
    coat = add_shell(k, body, P_not_front_strip(P_or(P_coat(0.84), P_arms(0.905)), 0.05), thick_by_y(0.03, 0.025), "cloth", push=shoulders_push(0.022))
    with_ao(coat, mottle(coat.v, 9.0, 0.18, 8.0))                                          # coal dust
    sk = skirt(body, trunk(coat), 0.88, 0.42, "cloth", flare=0.3, ease=0.012)
    k.add(grime(cut_front(sk, 0.075), 0.42, 0.18, 0.3, 8.0))
    k.add(band(body, neck_pts(body), 1.532, 0.107, "cloth", pad=0.03, thick=0.016))      # the collar turned up
    for sx in (-1.0, 1.0):
        buttons(k, coat, sx * 0.105, 1.36, 3, 0.11, "metal", 0.017)
        pocket(k, coat, sx * 0.12, 0.93, 0.09, 0.1, "cloth", "", bag=False)                    # the coat's pocket flaps
        welt(k, coat, (sx * 0.075, 1.46), (sx * 0.08, 0.86), "cloth")                        # the front edges
    for i in range(4):
        k.add(pstud(shirt, "dark", 0.0, 1.43 - i * 0.09, (0.009, 0.009, 0.006)))              # the shirt's buttons
    back_seams(k, coat, "cloth", y_hem=0.9)
    cuffs(k, body, 0.915, "cloth", 0.026, 0.036, 0.005)                                        # the coat's turned-back cuffs
    k.add(band(body, trunk(shirt), 0.985, 0.04, "leather", pad=0.002, thick=0.006))
    buckle(k, shirt, 0.0, 0.985, 0.042, 0.036, "metal", 0.014)
    k.add(pstud(shirt, "metal", 0.03, 0.94, (0.012, 0.09, 0.012)))                           # the empty lamp hook
    legs = add_shell(k, body, P_legs(0.16, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.22), 0.015, "leather", rim=0.008, push=boot_push())
    boots_finish(k, body, boots, 0.22)
    trousers_finish(k, legs, 0.22, 0.38)
    for p in head_piece(P, "flatcap", "hat"):
        k.add(p)
    return k


def kit_rother(body, P):
    k = Kit("rother")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.024, 0.019), "cloth")
    with_ao(coat, mottle(coat.v, 6.0, 0.15, 5.0))
    sk = skirt(body, trunk(coat), 0.9, 0.66, "cloth", flare=0.18, ease=0.006, rings=5)
    k.add(grime(sk, 0.66, 0.1, 0.18))
    buttons(k, coat, 0.012, 1.36, 4, 0.1)
    welt(k, coat, (0.026, 1.45), (0.026, 0.9), "cloth")
    for sx in (-1.0, 1.0):
        pocket(k, coat, sx * 0.12, 0.96, 0.1, 0.09, "cloth", "", bag=False)                   # hip pocket flaps
    pocket(k, coat, -0.08, 1.33, 0.07, 0.05, "cloth", "", bag=False)                          # the breast pocket's welt
    k.add(pstud(coat, "white", -0.08, 1.35, (0.03, 0.02, 0.012), tilt=0.2))                    # a handkerchief corner
    cuffs(k, body, 0.925, "cloth", 0.026, 0.035, 0.005)
    back_seams(k, coat, "cloth", y_hem=0.9)
    k.add(band(body, neck_pts(body), 1.53, 0.07, "knit", pad=0.022, thick=0.018))        # the scarf
    k.add(pstud(coat, "knit", 0.05, 1.37, (0.06, 0.18, 0.016), tilt=-0.1))
    k.add(pstud(coat, "knit", 0.058, 1.275, (0.064, 0.012, 0.018), tilt=-0.1))             # its fringe
    legs = add_shell(k, body, P_legs(0.24, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.3), 0.016, "leather", rim=0.008, push=boot_push())
    boots_finish(k, body, boots, 0.3)
    trousers_finish(k, legs, 0.3)
    for p in head_piece(P, "flatcap", "hat"):
        k.add(p)
    return k


def kit_kubiak(body, P):
    k = Kit("kubiak")
    jacket = add_shell(k, body, P_or(P_coat(0.88), P_arms(0.91)), thick_by_y(0.017, 0.013), "cloth")
    k.add(band(body, neck_pts(body), 1.512, 0.057, "cloth3", pad=0.012, thick=0.008))
    collar_points(k, jacket, "cloth3", y=1.462)
    k.add(pstud(jacket, "cloth3", 0.0, 1.42, (0.06, 0.07, 0.004)))                           # the shirt at the collar
    buttons(k, jacket, 0.012, 1.32, 3, 0.1)
    welt(k, jacket, (0.026, 1.4), (0.026, 0.92), "cloth")
    for sx in (-1, 1):
        k.add(pstud(jacket, "cloth2", sx * 0.09, 1.04, (0.09, 0.07, 0.006)))
        k.add(pstud(jacket, "cloth2", sx * 0.09, 1.07, (0.094, 0.028, 0.009)))                  # pocket flaps
        k.add(pstud(jacket, "dark", sx * 0.09, 1.066, (0.01, 0.01, 0.011)))
    pocket(k, jacket, -0.08, 1.31, 0.07, 0.08, "cloth", "dark")
    k.add(pstud(jacket, "metal", -0.065, 1.33, (0.006, 0.05, 0.012)))                          # a pencil stub
    cuffs(k, body, 0.92, "cloth", 0.02, 0.028, 0.004)
    back_seams(k, jacket, "cloth", y_hem=0.93)
    legs = add_shell(k, body, P_legs(0.15, 0.98), 0.009, "cloth2")
    boots = add_shell(k, body, P_boots(0.2), 0.013, "leather", push=boot_push())
    k.add(band(body, trunk(jacket), 0.97, 0.03, "leather", pad=0.001, thick=0.005))
    buckle(k, jacket, 0.0, 0.97, 0.036, 0.03, "metal", 0.013)
    keepers(k, jacket, 0.97, 0.03, (-0.1, 0.1), "cloth2", 0.012)
    boots_finish(k, body, boots, 0.2)
    trousers_finish(k, legs, 0.2)
    return k


def kit_pohl(body, P):
    k = Kit("pohl")
    coat = add_shell(k, body, P_or(P_coat(0.85), P_arms(0.905)), thick_by_y(0.02, 0.016), "cloth")
    sk = skirt(body, trunk(coat), 0.9, 0.3, "cloth", flare=0.34, ease=0.006)
    k.add(grime(sk, 0.3, 0.12, 0.2))
    buttons(k, coat, 0.0, 1.38, 5, 0.09)
    welt(k, coat, (0.016, 1.44), (0.016, 0.9), "cloth")
    for sx in (-1.0, 1.0):
        pocket(k, coat, sx * 0.12, 0.95, 0.09, 0.08, "cloth", "", bag=False)
    cuffs(k, body, 0.92, "cloth", 0.024, 0.04, 0.005)
    back_seams(k, coat, "cloth", y_hem=0.9)
    k.add(band(body, neck_pts(body), 1.542, 0.072, "knit", pad=0.02, thick=0.016))         # a wool scarf
    k.add(pstud(coat, "knit", -0.04, 1.4, (0.05, 0.14, 0.014), tilt=0.1))                   # its end
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "cloth2", rim=0.0)                         # stockings
    shoes = add_shell(k, body, P_boots(0.11), 0.009, "leather", push=boot_push(0.009))
    boots_finish(k, body, shoes, 0.11, sole="dark", sole_pad=0.011, rows=(0.075,))
    for p in head_piece(P, "kerchief", "hat"):
        k.add(p)
    return k


def kit_trudi(body, P):
    k = Kit("trudi")
    blouse = add_shell(k, body, P_or(P_coat(0.92), P_arms(0.92)), thick_by_y(0.008, 0.008), "cloth")
    bodice = add_shell(k, body, P_torso(0.95, 1.4), 0.015, "cloth2", cover=False)
    k.add(band(body, neck_pts(body), 1.522, 0.052, "cloth", pad=0.012, thick=0.008))
    collar_points(k, blouse, "cloth", y=1.47, dx=0.042, w=0.05, h=0.03, tilt=0.4, depth=0.007)
    cuffs(k, body, 0.93, "cloth", 0.012, 0.03, 0.004)                                        # the blouse's cuffs
    k.add(band(body, trunk(bodice), 1.395, 0.012, "cloth2", pad=0.004, thick=0.004))       # the bodice's top edge
    sk = skirt(body, trunk(blouse), 0.98, 0.1, "cloth3", flare=0.32, ease=0.012)
    k.add(grime(sk, 0.1, 0.12, 0.2))
    pan = shell(BodyLike(sk), lambda b: (b.v[:, 2] < -0.02) & (np.abs(b.v[:, 0]) < 0.16) & (b.v[:, 1] > 0.3), 0.004, "white", 0.0)[0]
    k.add(pan)
    if pan is not None and len(pan.f):
        k.add(pstud(pan, "white", 0.06, 0.78, (0.09, 0.09, 0.006)))                         # the apron's pocket
    k.add(band(body, trunk(bodice), 0.98, 0.03, "white", pad=0.004, thick=0.005))          # apron strings
    k.add(pstud(bodice, "white", 0.0, 0.94, (0.03, 0.06, 0.012), front=False))             # the bow at the back
    for i in range(4):
        k.add(pstud(bodice, "dark", 0.0, 1.32 - i * 0.07, (0.012, 0.012, 0.005)))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    shoes = add_shell(k, body, P_boots(0.11), 0.009, "leather", push=boot_push(0.009))
    boots_finish(k, body, shoes, 0.11, sole="dark", sole_pad=0.011, rows=(0.075,))
    return k


def kit_sobotta(body, P):
    k = Kit("sobotta")
    tunic = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.018, 0.014), "cloth")
    k.add(skirt(body, trunk(tunic), 0.92, 0.76, "cloth", flare=0.1, ease=0.003, rings=4))
    k.add(band(body, neck_pts(body), 1.522, 0.067, "cloth2", pad=0.016, thick=0.01))
    buttons(k, tunic, 0.0, 1.4, 4, 0.1, "metal")
    welt(k, tunic, (0.014, 1.45), (0.014, 0.82), "cloth")
    for sx in (-1, 1):
        k.add(pstud(tunic, "dark", sx * 0.045, 1.475, (0.028, 0.038, 0.007), tilt=sx * 0.3))   # plain collar tabs
        k.add(pstud(tunic, "cloth", sx * 0.08, 1.32, (0.08, 0.05, 0.008)))
        k.add(pstud(tunic, "metal", sx * 0.08, 1.315, (0.011, 0.011, 0.011)))                  # pocket buttons
        k.add(pstud(tunic, "cloth", sx * 0.08, 1.26, (0.074, 0.08, 0.005)))                    # the pleated bags
        k.add(pstud(tunic, "cloth", sx * 0.09, 0.93, (0.09, 0.05, 0.008)))
        k.add(pstud(tunic, "metal", sx * 0.09, 0.925, (0.011, 0.011, 0.011)))
        k.add(pstud(tunic, "cloth", sx * 0.155, 1.47, (0.05, 0.03, 0.008), tilt=sx * 0.2))      # plain shoulder straps
        k.add(pstud(tunic, "metal", sx * 0.135, 1.47, (0.009, 0.009, 0.01)))
    cuffs(k, body, 0.915, "cloth", 0.018, 0.03, 0.005)
    back_seams(k, tunic, "cloth", y_hem=0.92)
    k.add(band(body, trunk(tunic), 0.99, 0.05, "leather", pad=0.002, thick=0.008))
    buckle(k, tunic, 0.0, 0.99, 0.05, 0.042, "metal", 0.018, tongue="")                     # a plain frame buckle, no emblem
    for sx in (-1.0, 1.0):
        k.add(pstud(tunic, "metal", sx * 0.13, 1.02, (0.012, 0.03, 0.014)))                    # belt hooks
    legs = add_shell(k, body, P_legs(0.36, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.43), 0.015, "leather", rim=0.008, push=boot_push())      # jackboots
    boots_finish(k, body, boots, 0.43, laced=False)
    trousers_finish(k, legs, 0.43, 0.15)
    for p in head_piece(P, "sidecap", "hat"):
        k.add(p)
    return k


def kit_wiesner(body, P):
    k = Kit("wiesner")
    jacket = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.019, 0.015), "cloth")
    k.add(skirt(body, trunk(jacket), 0.92, 0.76, "cloth", flare=0.12, ease=0.004, rings=4))
    for sx in (-1.0, 1.0):
        buttons(k, jacket, sx * 0.06, 1.38, 4, 0.1, "brass", 0.016)                       # double-breasted
        pocket(k, jacket, sx * 0.12, 0.96, 0.09, 0.07, "cloth", "brass", bag=False)
    welt(k, jacket, (0.08, 1.44), (0.08, 0.84), "cloth")                                      # the overlap's edge
    collar_points(k, jacket, "cloth", y=1.47, dx=0.06, w=0.07, h=0.045, tilt=0.6)          # the reefer's lapels
    cuffs(k, body, 0.92, "cloth", 0.02, 0.035, 0.005)
    for sx in (-1.0, 1.0):
        for i in range(2):
            k.add(pstud(jacket, "brass", sx * 0.2, 0.935 + 0.02 * i, (0.009, 0.009, 0.01)))    # cuff buttons
    back_seams(k, jacket, "cloth", y_hem=0.9)
    k.add(band(body, neck_pts(body), 1.53, 0.065, "knit", pad=0.02, thick=0.016))
    legs = add_shell(k, body, P_legs(0.24, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.3), 0.015, "leather", rim=0.008, push=boot_push())
    boots_finish(k, body, boots, 0.3)
    trousers_finish(k, legs, 0.3)
    for p in head_piece(P, "peaked", "hat"):
        k.add(p)
    return k


def kit_brandt(body, P):
    k = Kit("brandt")
    coat = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.905)), thick_by_y(0.017, 0.014), "cloth")
    k.add(grime(skirt(body, trunk(coat), 0.92, 0.66, "cloth", flare=0.3, ease=0.016, rings=5), 0.66, 0.1, 0.15))
    k.add(grime(skirt(body, trunk(coat), 0.9, 0.16, "cloth2", flare=0.26, ease=0.006), 0.16, 0.14, 0.25))
    buttons(k, coat, 0.0, 1.36, 4, 0.09)
    welt(k, coat, (0.016, 1.42), (0.016, 0.92), "cloth")
    for sx in (-1.0, 1.0):
        pocket(k, coat, sx * 0.12, 0.96, 0.09, 0.08, "cloth", "", bag=False)
    cuffs(k, body, 0.915, "cloth", 0.02, 0.04, 0.005)
    back_seams(k, coat, "cloth", y_hem=0.92)
    k.add(band(body, neck_pts(body), 1.522, 0.047, "white", pad=0.012, thick=0.008))
    k.add(band(body, neck_pts(body), 1.535, 0.055, "knit", pad=0.02, thick=0.015))
    k.add(pstud(coat, "knit", -0.045, 1.38, (0.055, 0.17, 0.014), tilt=0.12))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    shoes = add_shell(k, body, P_boots(0.12), 0.009, "leather", push=boot_push(0.009))
    boots_finish(k, body, shoes, 0.12, sole="dark", sole_pad=0.011, rows=(0.075, 0.095))
    return k


def kit_kroll(body, P):
    k = Kit("kroll")
    jacket = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.91)), thick_by_y(0.016, 0.013), "cloth")
    k.add(grime(skirt(body, trunk(jacket), 0.94, 0.28, "cloth2", flare=0.26, ease=0.006), 0.28, 0.14, 0.25))
    buttons(k, jacket, 0.0, 1.4, 5, 0.09, "brass", 0.014)
    welt(k, jacket, (0.014, 1.45), (0.014, 0.9), "cloth")
    k.add(band(body, neck_pts(body), 1.522, 0.057, "cloth", pad=0.014, thick=0.008))
    collar_points(k, jacket, "cloth", y=1.465, dx=0.045, w=0.05, h=0.034)
    for sx in (-1.0, 1.0):
        pocket(k, jacket, sx * 0.08, 1.31, 0.07, 0.08, "cloth", "brass")
    cuffs(k, body, 0.92, "cloth", 0.02, 0.03, 0.005)
    back_seams(k, jacket, "cloth", y_hem=0.92)
    k.add(sash(jacket, (0.1, 1.45), (-0.16, 0.99), 0.032, "leather"))                     # the post satchel's strap
    k.add(sash(jacket, (0.1, 1.45), (-0.16, 0.99), 0.032, "leather", front=False))
    buckle(k, jacket, 0.02, 1.25, 0.04, 0.036, "brass", 0.015, tongue="")
    k.add(pstud(jacket, "leather", -0.15, 0.9, (0.18, 0.16, 0.07)))                         # the satchel
    k.add(pstud(jacket, "leather", -0.15, 0.94, (0.185, 0.09, 0.074)))                      # its flap
    for dx in (-0.05, 0.05):
        k.add(pstud(jacket, "leather", -0.15 + dx, 0.91, (0.016, 0.07, 0.077)))             # its straps
        k.add(pstud(jacket, "brass", -0.15 + dx, 0.895, (0.022, 0.018, 0.079)))             # and buckles
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "dark", rim=0.0)
    boots = add_shell(k, body, P_boots(0.24), 0.013, "leather", rim=0.006, push=boot_push())
    boots_finish(k, body, boots, 0.24)
    for p in head_piece(P, "kerchief", "hat"):
        k.add(p)
    return k


def kit_cousin_hammer(body, P):
    k = Kit("cousin_hammer")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.925)), thick_by_y(0.032, 0.027), "cloth", push=shoulders_push(0.024))
    k.add(skirt(body, trunk(coat), 0.88, 0.42, "cloth", flare=0.36, ease=0.014))
    k.add(grime(skirt(body, trunk(coat), 0.9, 0.08, "cloth2", flare=0.3, ease=0.006), 0.08, 0.14, 0.3))   # the long wool skirt
    buttons(k, coat, 0.0, 1.46, 5, 0.1, "metal", 0.018)                                      # buttoned to the throat
    welt(k, coat, (0.02, 1.5), (0.02, 0.86), "cloth")
    for sx in (-1.0, 1.0):
        pocket(k, coat, sx * 0.14, 0.95, 0.1, 0.09, "cloth", "", bag=False)                    # the coat's pocket flaps
    back_seams(k, coat, "cloth", y_hem=0.9)
    k.add(band(body, neck_pts(body), 1.537, 0.082, "cloth", pad=0.022, thick=0.014))
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.97, 0.09, "cloth3", pad=0.03, thick=0.012, bones=("LowerArm", "Hand")))           # sleeves turned back twice
    add_shell(k, body, P_hands(), 0.011, "knit", rim=0.0)                                   # red mittens
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.885, 0.035, "white", pad=0.016, thick=0.008, bones=("LowerArm", "Hand")))         # their grey cuffs
    boots = add_shell(k, body, P_boots(0.2), 0.013, "leather", rim=0.006, push=boot_push())
    boots_finish(k, body, boots, 0.2)
    stitches(k, body, ys_neck=(1.585,))
    return k


def kit_cousin_reach(body, P):
    k = Kit("cousin_reach")
    gown = add_shell(k, body, P_or(P_coat(0.85), P_arms(1.15)), thick_by_y(0.009, 0.009), "cloth")
    k.add(grime(skirt(body, trunk(gown), 0.95, 0.05, "cloth", flare=0.24, ease=0.008), 0.05, 0.16, 0.35))   # to the ankle
    k.add(band(body, neck_pts(body), 1.542, 0.082, "cloth", pad=0.012, thick=0.008))         # the high collar
    for i in range(4):
        k.add(pstud(gown, "white", 0.0, 1.565 - i * 0.02, (0.007, 0.007, 0.012)))              # the collar's little buttons
    card = add_shell(k, body, P_or(P_torso(0.9, 1.49), P_arms(1.17)), thick_by_y(0.021, 0.018), "knit", cover=False)
    k.add(band(body, trunk(card), 0.91, 0.04, "knit", pad=0.004, thick=0.008))
    buttons(k, card, 0.0, 1.38, 5, 0.1, "metal", 0.015)
    for sx in (-1.0, 1.0):
        k.add(pstud(card, "knit", sx * 0.11, 1.0, (0.08, 0.08, 0.006)))                        # the cardigan's pockets
        welt(k, card, (sx * 0.02, 1.47), (sx * 0.02, 0.92), "knit", width=0.012)              # its button bands
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 1.17, 0.02, "cloth2", pad=0.016, thick=0.004, bones=("UpperArm", "LowerArm")))   # the torn sleeve edge
    stitches(k, body, ys_neck=(1.585,), wrist_y=0.9)
    return k


def kit_cousin_alix(body, P):
    k = Kit("cousin_alix")
    dress = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.92)), thick_by_y(0.012, 0.012), "cloth")
    sk = skirt(body, trunk(dress), 0.97, 0.36, "cloth", flare=0.3, ease=0.016)            # below the knee
    k.add(grime(sk, 0.36, 0.1, 0.2))
    k.add(band(body, neck_pts(body), 1.527, 0.047, "white", pad=0.014, thick=0.008))       # the white collar
    for sx in (-1.0, 1.0):
        k.add(pstud(dress, "white", sx * 0.045, 1.465, (0.075, 0.03, 0.005), tilt=sx * 0.35))
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.935, 0.03, "white", pad=0.014, thick=0.006, bones=("LowerArm", "Hand")))
    k.add(band(body, trunk(dress), 0.97, 0.014, "cloth", pad=0.004, thick=0.004))          # the waist seam
    back_seams(k, dress, "cloth", y_hem=0.97)
    # the wide red ribbon bow at the breastbone (it hides the root of the third arm)
    for sx in (-1.0, 1.0):
        k.add(pstud(dress, "accent", sx * 0.045, 1.3, (0.075, 0.06, 0.02), tilt=sx * 0.45))
        k.add(pstud(dress, "accent", sx * 0.022, 1.235, (0.024, 0.085, 0.012), tilt=sx * 0.25))
    k.add(pstud(dress, "accent", 0.0, 1.3, (0.03, 0.032, 0.026)))
    add_shell(k, body, P_legs(0.08, 0.6), 0.003, "cloth3", rim=0.0)                          # dark stockings
    shoes = add_shell(k, body, P_boots(0.1), 0.009, "leather", push=boot_push(0.009))
    boots_finish(k, body, shoes, 0.1, laced=False, sole="dark", sole_pad=0.011)
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.075, 0.012, "leather", pad=0.01, thick=0.004, bones=("LowerLeg", "Foot")))   # shoe straps
        x = leg_x(body, side, 0.08)
        if x is not None and shoes is not None:
            k.add(pstud(shoes, "metal", x + (0.03 if side == "Right" else -0.03), 0.075, (0.009, 0.009, 0.008)))   # their buttons
    stitches(k, body, ys_neck=(1.585,))
    return k


def kit_selwyn(body, P):
    """T-126: Flt Lt Harry Selwyn, GRAVELIGHT ONE's pilot: a sheepskin flying jacket (leather out, the fleece at the
    collar, cuffs and hem), RAF blue-grey battledress trousers, flying boots, a leather flying helmet."""
    k = Kit("selwyn")
    jacket = add_shell(k, body, P_or(P_coat(0.9), P_arms(0.92)), thick_by_y(0.026, 0.02), "cloth")
    scuff(jacket, 0.1, 9.0)                                                                  # worn sheepskin
    k.add(band(body, neck_pts(body), 1.5, 0.11, "knit", pad=0.03, thick=0.026))            # the big fleece collar
    k.add(band(body, trunk(jacket), 0.95, 0.06, "knit", pad=0.006, thick=0.016))           # the fleece at the hem
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.92, 0.05, "knit", pad=0.016, thick=0.012, bones=("LowerArm", "Hand")))
    k.add(sash(jacket, (0.03, 1.47), (0.05, 0.96), 0.012, "metal"))                          # the zip
    k.add(pstud(jacket, "metal", 0.03, 1.4, (0.01, 0.024, 0.012)))                          # its pull
    for sx in (-1.0, 1.0):
        welt(k, jacket, (sx * 0.17, 1.42), (sx * 0.15, 0.98), "cloth", width=0.008)          # the panel seams
        k.add(pstud(jacket, "cloth", sx * 0.095, 1.1, (0.06, 0.1, 0.006), tilt=sx * 0.3))     # slanted hand-warmer pockets
        k.add(pstud(jacket, "knit", sx * 0.107, 1.1, (0.01, 0.095, 0.008), tilt=sx * 0.3))    # their fleece edge
    back_seams(k, jacket, "cloth", y_hem=1.0)
    k.add(band(body, trunk(jacket), 1.03, 0.04, "leather", pad=0.004, thick=0.008))         # a belt over the jacket
    buckle(k, jacket, 0.06, 1.03, 0.042, 0.038, "metal", 0.016)
    legs = add_shell(k, body, P_legs(0.3, 0.98), 0.011, "cloth2")
    for sx in (-1.0, 1.0):
        k.add(pstud(legs, "cloth2", sx * 0.11, 0.62, (0.08, 0.1, 0.008)))                     # the map pocket on each thigh
        k.add(pstud(legs, "cloth2", sx * 0.11, 0.665, (0.084, 0.03, 0.011)))
        k.add(pstud(legs, "dark", sx * 0.11, 0.66, (0.01, 0.01, 0.013)))
    boots = add_shell(k, body, P_boots(0.36), 0.02, "leather", rim=0.008, push=boot_push(0.015))     # suede flying boots
    boots_finish(k, body, boots, 0.36, laced=False)
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.3, 0.022, "leather", pad=0.024, thick=0.005, bones=("LowerLeg", "Foot")))    # the strap at the top
        x = leg_x(body, side, 0.3)
        if x is not None:
            buckle(k, boots, x + (0.035 if side == "Right" else -0.035), 0.3, 0.024, 0.024, "metal", 0.012, tongue="")
        k.add(cuff_band(body, side, 0.33, 0.04, "knit", pad=0.024, thick=0.008, bones=("LowerLeg",)))   # the fleece lining at the top
    trousers_finish(k, legs, 0.36)
    k.add(band(body, neck_pts(body), 1.535, 0.05, "white", pad=0.012, thick=0.008))         # the silk scarf
    for p in head_piece(P, "knit", "hat"):                                                   # the leather helmet (close, over the ears)
        k.add(p)
    return k


def kit_teller(body, P):
    """T-136: Erwin Lassmann, the Darlehenskasse's junior clerk: a white shirt with sleeve garters, a dark waistcoat
    with a watch chain, a narrow tie, dark trousers, polished black shoes."""
    k = Kit("teller")
    shirt = add_shell(k, body, P_or(P_coat(0.86), P_arms(0.925)), thick_by_y(0.012, 0.01), "white")
    vest = add_shell(k, body, P_coat(0.88), thick_by_y(0.02, 0.016), "cloth", push=shoulders_push(0.004))
    k.add(skirt(body, trunk(vest), 0.94, 0.88, "cloth", flare=0.04, ease=0.002, rings=3))
    k.add(band(body, neck_pts(body), 1.525, 0.05, "white", pad=0.012, thick=0.008))         # the stiff collar
    k.add(sash(shirt, (0.0, 1.5), (0.0, 1.2), 0.03, "cloth2"))                               # the tie
    k.add(pstud(shirt, "cloth2", 0.0, 1.495, (0.03, 0.02, 0.012)))                           # its knot
    buttons(k, vest, 0.03, 1.36, 5, 0.075, "dark", 0.012)
    for sx in (-1.0, 1.0):
        pocket(k, vest, sx * 0.1, 1.06, 0.07, 0.04, "cloth", "", bag=False)
    k.add(sash(vest, (-0.1, 1.07), (0.03, 1.12), 0.006, "brass"))                            # the watch chain
    for side in ("Left", "Right"):
        k.add(cuff_band(body, side, 0.83, 0.03, "cloth2", pad=0.01, thick=0.006, bones=("UpperArm", "LowerArm")))   # sleeve garters
    back_seams(k, vest, "cloth", y_hem=0.95)
    k.add(band(body, trunk(shirt), 0.99, 0.035, "leather", pad=0.003, thick=0.006))
    legs = add_shell(k, body, P_legs(0.1, 0.98), 0.009, "cloth2")
    shoes = add_shell(k, body, P_boots(0.1), 0.012, "leather", push=boot_push(0.01))
    boots_finish(k, body, shoes, 0.1, sole="dark", sole_pad=0.011, rows=(0.075,))
    trousers_finish(k, legs, 0.1)
    return k


def kit_ammer(body, P):
    """T-135: Fw. August "Gustl" Ammer, Kaltenbrunn's quartermaster: a long grey storeman's dust coat over a plain
    field-grey tunic (no insignia, no badges, no symbols of any kind), a leather belt with a plain buckle and a
    pencil in the breast pocket, a plain side cap."""
    k = Kit("ammer")
    tunic = add_shell(k, body, P_coat(0.86), 0.009, "cloth3")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.024, 0.02), "cloth", push=shoulders_push(0.016))
    with_ao(coat, mottle(coat.v, 7.0, 0.14, 6.0))                                           # store dust
    sk = skirt(body, trunk(coat), 0.9, 0.52, "cloth", flare=0.2, ease=0.008, rings=5)
    k.add(grime(sk, 0.4, 0.16, 0.3, 8.0))
    k.add(band(body, neck_pts(body), 1.53, 0.06, "cloth", pad=0.02, thick=0.012))
    collar_points(k, coat, "cloth", y=1.48, dx=0.07, w=0.075, h=0.05, tilt=0.5)
    for sx in (-1.0, 1.0):
        buttons(k, coat, sx * 0.07, 1.36, 4, 0.12, "dark", 0.017)
        pocket(k, coat, sx * 0.13, 0.94, 0.11, 0.12, "cloth", "dark", bag=True)                 # deep tally pockets
        welt(k, coat, (sx * 0.06, 1.46), (sx * 0.07, 0.86), "cloth")
    pocket(k, tunic, 0.09, 1.33, 0.07, 0.07, "cloth3", "dark")                                 # the breast pocket
    k.add(pstud(tunic, "wood", 0.1, 1.39, (0.006, 0.06, 0.006)))                               # the pencil in it
    for i in range(4):
        k.add(pstud(tunic, "dark", 0.0, 1.43 - i * 0.09, (0.01, 0.01, 0.006)))
    back_seams(k, coat, "cloth", y_hem=0.9)
    cuffs(k, body, 0.915, "cloth", 0.024, 0.034, 0.005)
    k.add(band(body, trunk(coat), 1.0, 0.045, "leather", pad=0.004, thick=0.008))
    buckle(k, coat, 0.0, 1.0, 0.046, 0.04, "metal", 0.016)
    k.add(pstud(coat, "leather", -0.16, 0.95, (0.07, 0.09, 0.05)))                            # the keys' pouch
    legs = add_shell(k, body, P_legs(0.24, 0.98), 0.01, "cloth2")
    boots = add_shell(k, body, P_boots(0.3), 0.015, "leather", rim=0.008, push=boot_push())
    boots_finish(k, body, boots, 0.3)
    trousers_finish(k, legs, 0.3)
    for p in head_piece(P, "sidecap", "hat"):
        k.add(p)
    return k


def kit_petersen(body, P):
    """T-135: Hinnerk Petersen, Totenhafen's old harbour pilot: a navy double-breasted pea coat with plain horn
    buttons over a knitted roll-neck, a peaked pilot's cap (no badge), sea boots."""
    k = Kit("petersen")
    coat = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.91)), thick_by_y(0.024, 0.018), "cloth")
    with_ao(coat, mottle(coat.v, 6.0, 0.12, 5.0))                                           # salt bloom
    k.add(skirt(body, trunk(coat), 0.9, 0.72, "cloth", flare=0.14, ease=0.006, rings=4))
    k.add(band(body, neck_pts(body), 1.535, 0.085, "knit", pad=0.022, thick=0.02))         # the roll-neck
    for sx in (-1.0, 1.0):
        buttons(k, coat, sx * 0.075, 1.38, 3, 0.12, "brass", 0.019)                         # double-breasted, horn
        pocket(k, coat, sx * 0.13, 0.98, 0.1, 0.08, "cloth", "", bag=False, tilt=sx * 0.18)  # slash hand pockets
    welt(k, coat, (0.09, 1.45), (0.09, 0.86), "cloth")
    collar_points(k, coat, "cloth", y=1.49, dx=0.07, w=0.085, h=0.055, tilt=0.65)           # the broad lapels
    cuffs(k, body, 0.92, "cloth", 0.02, 0.035, 0.005)
    back_seams(k, coat, "cloth", y_hem=0.9)
    legs = add_shell(k, body, P_legs(0.34, 0.98), 0.011, "cloth2")
    boots = add_shell(k, body, P_boots(0.36), 0.017, "leather", rim=0.01, push=boot_push())   # sea boots
    boots_finish(k, body, boots, 0.36)
    trousers_finish(k, legs, 0.36)
    for p in head_piece(P, "peaked", "hat"):
        k.add(p)
    return k


def kit_jette(body, P):
    """T-135: Henriette "Jette" Maurer, Fernflug's wind-tunnel technician and glider pilot: one-piece work coveralls
    with the sleeves rolled, a webbing belt, a spanner in the thigh pocket, a knotted kerchief over her hair."""
    k = Kit("jette")
    suit = add_shell(k, body, P_or(P_coat(0.84), P_arms(0.86)), thick_by_y(0.016, 0.013), "cloth")
    with_ao(suit, mottle(suit.v, 9.0, 0.2, 7.0))                                            # oil and dust
    k.add(skirt(body, trunk(suit), 0.92, 0.84, "cloth", flare=0.06, ease=0.003, rings=3))
    legs = add_shell(k, body, P_legs(0.2, 0.98), 0.012, "cloth")
    k.add(band(body, neck_pts(body), 1.52, 0.05, "cloth", pad=0.016, thick=0.01))
    collar_points(k, suit, "cloth", dx=0.05)
    welt(k, suit, (0.0, 1.46), (0.0, 0.92), "metal", width=0.007)                           # the front buttons' fly
    for i in range(5):
        k.add(pstud(suit, "dark", 0.0, 1.42 - i * 0.1, (0.01, 0.01, 0.006)))
    for sx in (-1.0, 1.0):
        pocket(k, suit, sx * 0.09, 1.31, 0.08, 0.09, "cloth", "dark")                          # chest pockets
        k.add(cuff_band(body, "Left" if sx < 0 else "Right", 0.86, 0.05, "cloth", pad=0.016, thick=0.01, bones=("LowerArm", "Hand")))   # rolled sleeves
    pocket(k, legs, 0.12, 0.62, 0.09, 0.12, "cloth", "", bag=True)                             # the thigh pocket
    k.add(pstud(legs, "metal", 0.12, 0.7, (0.012, 0.09, 0.008)))                               # the spanner in it
    back_seams(k, suit, "cloth", y_hem=0.92)
    k.add(band(body, trunk(suit), 1.0, 0.04, "canvas", pad=0.004, thick=0.007))             # webbing belt
    buckle(k, suit, 0.0, 1.0, 0.04, 0.036, "metal", 0.014)
    boots = add_shell(k, body, P_boots(0.18), 0.015, "leather", push=boot_push(0.012))
    boots_finish(k, body, boots, 0.18)
    trousers_finish(k, legs, 0.18)
    for p in head_piece(P, "kerchief", "hat"):
        k.add(p)
    return k


PEOPLE_KITS = {
    "dutch": kit_dutch, "peg": kit_peg, "deacon": kit_deacon, "wren": kit_wren, "jakub": kit_jakub,
    "rother": kit_rother, "kubiak": kit_kubiak, "pohl": kit_pohl, "trudi": kit_trudi, "sobotta": kit_sobotta,
    "wiesner": kit_wiesner, "brandt": kit_brandt, "kroll": kit_kroll,
    "cousin_hammer": kit_cousin_hammer, "cousin_reach": kit_cousin_reach, "cousin_alix": kit_cousin_alix,
    "selwyn": kit_selwyn,
    "ammer": kit_ammer, "petersen": kit_petersen, "jette": kit_jette,   # T-135: the map companions
    "teller": kit_teller,   # T-136: the bank teller
}
