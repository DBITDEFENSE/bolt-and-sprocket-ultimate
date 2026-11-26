#!/usr/bin/env python
"""Painted, weathered steel hull plating for Totenhafen's boats (T-287). Our own procedural work, CC0.

    python -I tools/make_uboat_plating.py            ->  assets/ours/textures/<set>/textures/<set>_{albedo,normal,orm}.png

Why: the hulls wore Poly Haven's rusty_painted_metal, a photograph of a corrugated container wall (vertical ribs in
the normal map, vertical rust runs in the albedo); lit from the right side after T-282 it read as strong vertical
stripes. A hull is plated in strakes that run fore and aft, so the seams are horizontal.

Four sets, all deterministic (seeded) and tileable:
  uboat_plating        2048 x 2048, one tile = 5.8 m along the hull (u) x 5.0 m of girth (v, deck edge -> boot-top,
                       normalised per section by DetailMap02.type_vii, so the strakes taper toward the ends as real
                       shell plating does). Four strakes, staggered butts, rivet rows, rust weeping from the seams, the
                       rivets and the casing's free-flooding slots (every 1.45 m from z 4.0, so a 5.8 m tile holds
                       four), a salt-and-scum waterline band over the boot-top, the worn deck edge.
  uboat_plating_wreck  1024 x 1024, the same layout on the dead U-boat: the paint mostly gone, rust, salt crust.
  steel_plating        1024 x 1024, 2.9 m x 2.5 m: grey painted plates with seams, rivets and rust runs and no
                       waterline (the triplanar m2_hull: the tower fairing, the casing, fittings, the patrol boat).
  red_lead_plating     1024 x 1024, 2.9 m x 2.5 m: red lead with seams, rivets, fouling, salt and rust (below the
                       boot-top, UV-mapped on the U-boats and triplanar on the patrol boat).

Image space: x = u (along the hull), y = v (down the girth, row 0 at the top / the deck edge). Normal maps are
OpenGL +Y (Godot's); ORM = R occlusion, G roughness, B metallic. Needs numpy and Pillow.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "ours", "textures")


# ------------------------------------------------------------------ helpers

def blur(a, sx, sy=None):
    """Periodic gaussian blur (sigma in pixels per axis) through the FFT: keeps the tile seamless."""
    if sy is None:
        sy = sx
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi ** 2) * ((fx * sx) ** 2 + (fy * sy) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def norm01(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def fnoise(rng, h, w, octaves, aspect=1.0):
    """Tileable fractal noise 0..1: octaves = [(sigma_px, weight), ...]; aspect stretches it along y (> 1 = runs)."""
    acc = np.zeros((h, w))
    for s, wt in octaves:
        acc += blur(rng.standard_normal((h, w)), s, s * aspect) * wt * s
    return norm01(acc)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1.0 - t) + b * t


def col(*rgb):
    return np.array(rgb, dtype=np.float64) / 255.0


def save_rgb(path, a):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)


def stamp(canvas, y0, x0, kernel, mode="add"):
    """Adds (or max-combines) `kernel` into `canvas` with its top-left at (y0, x0), wrapping round both edges."""
    h, w = canvas.shape
    kh, kw = kernel.shape
    ri = (np.arange(kh) + y0) % h
    ci = (np.arange(kw) + x0) % w
    if mode == "max":
        canvas[np.ix_(ri, ci)] = np.maximum(canvas[np.ix_(ri, ci)], kernel)
    else:
        canvas[np.ix_(ri, ci)] += kernel


# ------------------------------------------------------------------ the layout

class Layout:
    """Strakes (horizontal seams at v metres), butts per strake (u metres), frames (u pitch) on a W x H tile of
    TU x TV metres. Distances are in pixels."""

    def __init__(self, w, h, tu, tv, seams, butts, frame):
        self.w, self.h, self.tu, self.tv = w, h, tu, tv
        self.pu, self.pv = w / tu, h / tv          # pixels per metre along u and v
        self.seams, self.butts, self.frame = seams, butts, frame
        u = (np.arange(w) + 0.5) / self.pu
        v = (np.arange(h) + 0.5) / self.pv
        self.U, self.V = np.meshgrid(u, v)
        # the strake of each pixel and its top / bottom seam
        k = np.searchsorted(np.array(seams), v, side="right") - 1
        k = np.clip(k, 0, len(seams) - 1)
        top = np.array(seams)[k]
        bot = np.array(seams + [seams[0] + tv])[k + 1]
        self.k = np.repeat(k[:, None], w, axis=1)
        self.ys = np.repeat(((v - top) / (bot - top))[:, None], w, axis=1)   # 0..1 down the strake
        dv = np.minimum(np.abs(v - top), np.abs(bot - v))
        self.d_seam = np.repeat((dv * self.pv)[:, None], w, axis=1)
        # butts: distance to the nearest butt of the pixel's own strake (wrapping in u)
        self.d_butt = np.full((h, w), 1e9)
        self.plate = np.zeros((h, w), dtype=np.int64)
        for ki, bl in enumerate(butts):
            m = self.k == ki
            for bu in bl:
                du = np.abs(((self.U - bu + tu * 0.5) % tu) - tu * 0.5) * self.pu
                self.d_butt = np.where(m, np.minimum(self.d_butt, du), self.d_butt)
            # plate index inside the strake: how many butts lie left of u (mod the tile)
            cnt = np.zeros((h, w), dtype=np.int64)
            for bu in bl:
                cnt += (self.U >= bu).astype(np.int64)
            self.plate = np.where(m, ki * 16 + (cnt % max(len(bl), 1)), self.plate)
        self.d_any = np.minimum(self.d_seam, self.d_butt)

    def rivets(self):
        """Rivet centres (u, v) in metres: a double row along each seam, a double column at each butt, single columns
        at the frames."""
        out = []
        pitch = 0.085
        for s in self.seams:
            for off in (-0.045, 0.045):
                n = int(round(self.tu / pitch))
                for i in range(n):
                    out.append(((i + (0.5 if off > 0 else 0.0)) * self.tu / n, (s + off) % self.tv))
        bnds = self.seams + [self.seams[0] + self.tv]
        for ki, bl in enumerate(self.butts):
            v0, v1 = bnds[ki] + 0.09, bnds[ki + 1] - 0.09
            n = max(2, int((v1 - v0) / pitch))
            for bu in bl:
                for off in (-0.045, 0.045):
                    for i in range(n + 1):
                        out.append(((bu + off) % self.tu, v0 + (v1 - v0) * i / n))
            nf = int(round(self.tu / self.frame))
            for j in range(nf):
                fu = (j + 0.5) * self.tu / nf
                if any(abs(((fu - bu + self.tu * 0.5) % self.tu) - self.tu * 0.5) < 0.25 for bu in bl):
                    continue
                m = max(2, int((v1 - v0) / 0.13))
                for i in range(m + 1):
                    out.append((fu, v0 + (v1 - v0) * i / m))
        return out


def rivet_maps(lay, radius_m=0.011):
    """Height dome and a mask of the rivet heads, plus each head's centre in pixels."""
    rx, ry = radius_m * lay.pu, radius_m * lay.pv
    kw, kh = int(np.ceil(rx * 2.6)) | 1, int(np.ceil(ry * 2.6)) | 1
    yy, xx = np.mgrid[0:kh, 0:kw]
    dx = (xx - kw // 2) / rx
    dy = (yy - kh // 2) / ry
    d2 = dx * dx + dy * dy
    dome = np.sqrt(np.clip(1.0 - d2, 0.0, 1.0))
    halo = np.exp(-d2 * 0.9) * (d2 > 0.8)   # the ring of dirt round a head
    hmap = np.zeros((lay.h, lay.w))
    rmask = np.zeros((lay.h, lay.w))
    ring = np.zeros((lay.h, lay.w))
    centres = []
    for (u, v) in lay.rivets():
        cx, cy = u * lay.pu, v * lay.pv
        x0, y0 = int(round(cx)) - kw // 2, int(round(cy)) - kh // 2
        stamp(hmap, y0, x0, dome, "max")
        stamp(rmask, y0, x0, (d2 < 1.0).astype(float), "max")
        stamp(ring, y0, x0, halo, "max")
        centres.append((cx, cy))
    return hmap, rmask, ring, centres


def streaks(rng, h, w, sources, pu, pv):
    """Rust runs: each source (x px, y px, length m, width m, strength) weeps downward (+y), wobbling, widening and
    fading; returns 0..1."""
    acc = np.zeros((h, w))
    for (x, y, length, width, strength) in sources:
        lp = max(4, int(length * pv))
        w0 = max(0.8, width * pu)
        maxw = int(np.ceil(w0 * 3.2)) + 3
        t = (np.arange(lp) / lp)[:, None]
        ph = rng.uniform(0, 6.28, 3)
        wob = (np.sin(t * 7.0 + ph[0]) * 0.9 + np.sin(t * 17.0 + ph[1]) * 0.45) * w0 * 0.5
        dx = np.arange(-maxw, maxw + 1)[None, :] - wob
        hw = w0 * (0.55 + 1.4 * t)
        along = (1.0 - t) ** 1.25 * (0.65 + 0.35 * np.sin(t * 23.0 + ph[2]) ** 2) * np.minimum(1.0, 0.35 + t / 0.05)
        k = np.exp(-(dx / hw) ** 2) * along * strength
        stamp(acc, int(y), int(x) - maxw, k)
    return np.clip(acc, 0.0, 1.0)


def height_to_normal(hgt, strength):
    """OpenGL (+Y green) normal map from a height field (periodic differences)."""
    dx = (np.roll(hgt, -1, axis=1) - np.roll(hgt, 1, axis=1)) * 0.5
    dy = (np.roll(hgt, -1, axis=0) - np.roll(hgt, 1, axis=0)) * 0.5   # d/d(row): rows run down
    n = np.stack([-dx * strength, dy * strength, np.ones_like(hgt)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


# ------------------------------------------------------------------ one set

STYLES = {
    # paint, primer under chips, rust light / dark, salt, scum; how much of each
    "grey": dict(paint=col(86, 91, 96), primer=col(104, 74, 62), bare=col(74, 74, 76), rust_l=col(112, 78, 58),
                 rust_d=col(62, 44, 34), salt=col(176, 175, 168), scum=col(50, 54, 46),
                 chips=0.10, rivet_rust=0.07, seam_rust=1.0, paint_cover=1.0, salt_amt=0.35, pitting=0.25),
    "wreck": dict(paint=col(84, 88, 92), primer=col(96, 70, 58), bare=col(70, 68, 66), rust_l=col(100, 74, 58),
                  rust_d=col(50, 38, 32), salt=col(170, 168, 158), scum=col(46, 50, 42),
                  chips=0.25, rivet_rust=0.3, seam_rust=2.0, paint_cover=0.55, salt_amt=1.0, pitting=0.9),
    "red": dict(paint=col(98, 66, 56), primer=col(96, 66, 56), bare=col(70, 68, 66), rust_l=col(112, 76, 54),
                rust_d=col(58, 40, 30), salt=col(160, 156, 146), scum=col(54, 56, 46),
                chips=0.06, rivet_rust=0.05, seam_rust=0.7, paint_cover=1.0, salt_amt=0.45, pitting=0.25),
}


def make_set(name, w, h, tu, tv, seams, butts, style, seed, slots=False, waterline=False, deck_edge=False,
             fouling=False):
    rng = np.random.default_rng(seed)
    st = STYLES[style]
    lay = Layout(w, h, tu, tv, seams, butts, frame=0.725)
    pu, pv = lay.pu, lay.pv
    px_m = (pu + pv) * 0.5

    # ---- shape: lapped strakes, seam grooves, plates dished between the frames, rivet heads
    lap = blur((lay.k % 2).astype(float), 0.9)
    groove = np.exp(-(lay.d_seam / 1.3) ** 2) * 0.9 + np.exp(-(lay.d_butt / 1.2) ** 2) * 0.7
    xf = (lay.U / lay.frame) % 1.0
    plate_amp = np.vectorize(lambda p: 0.6 + 0.8 * ((p * 2654435761) % 1000) / 1000.0)(lay.plate)
    dish = np.sin(np.pi * xf) * np.sin(np.pi * np.clip(lay.ys, 0, 1)) * plate_amp
    r_h, r_mask, r_ring, r_cent = rivet_maps(lay)
    hgt = lap * 1.6 - groove - dish * 5.0 + r_h * 1.35

    # ---- masks
    big = fnoise(rng, h, w, [(px_m * 0.45, 1.0), (px_m * 0.15, 0.5)])
    mid = fnoise(rng, h, w, [(px_m * 0.06, 1.0), (px_m * 0.02, 0.6)])
    fine = fnoise(rng, h, w, [(2.0, 1.0), (0.8, 0.6)])
    runs = fnoise(rng, h, w, [(px_m * 0.01, 1.0), (px_m * 0.004, 0.5)], aspect=9.0)   # vertical weeping grain
    near_seam = np.exp(-lay.d_any / (0.05 * px_m))

    # rust runs: from the seams (lap joints hold water), from some rivets, from the butts' feet, from the slots
    src = []
    for s in seams:
        # in clusters (where a lap seam lets water in), not evenly along it: an even comb read as stripes
        for _ in range(int(tu * 0.9 * st["seam_rust"])):
            uc = rng.uniform(0, tu)
            for _ in range(int(rng.integers(1, 4))):
                u = uc + rng.normal(0, 0.08)
                src.append((u * pu, ((s + 0.02) % tv) * pv, rng.uniform(0.12, 0.55) * (1.0 + st["seam_rust"] * 0.3),
                            rng.uniform(0.012, 0.04), rng.uniform(0.2, 0.6)))
    for (cx, cy) in r_cent:
        if rng.random() < st["rivet_rust"]:
            src.append((cx, cy + 0.01 * pv, rng.uniform(0.12, 0.6) * (1.0 + st["seam_rust"] * 0.3),
                        rng.uniform(0.004, 0.012), rng.uniform(0.35, 0.9)))
    bnds = seams + [seams[0] + tv]
    for ki, bl in enumerate(butts):
        for bu in bl:
            if rng.random() < 0.6:
                src.append((bu * pu, (bnds[ki + 1] % tv) * pv - 0.1 * pv, rng.uniform(0.3, 0.8), 0.02, 0.45))
    if slots:
        # the casing's free-flooding slots: z = 4.0 + 1.45 k, 0.7 m long, their foot at v ~0.5 on this tile (U-1047 midships)
        for k in range(4):
            u0 = (4.0 + 1.45 * k) % tu
            for _ in range(int(rng.integers(1, 4))):
                src.append(((u0 + rng.uniform(0.08, 0.62)) * pu, (0.5 + rng.uniform(-0.02, 0.03)) * pv,
                            rng.uniform(0.4, 1.8), rng.uniform(0.02, 0.05), rng.uniform(0.35, 0.8)))
    rust_runs = streaks(rng, h, w, src, pu, pv) * (0.55 + 0.45 * runs)
    rust_runs = np.clip(rust_runs * 1.2, 0, 1)

    # rust blooms along the seams and round the rivet heads
    near_h = np.exp(-lay.d_seam / (0.04 * px_m))   # the lap seams hold the water; the butts much less
    bloom = smooth(0.76, 0.98, mid * 0.6 + near_h * 0.45 * st["seam_rust"] ** 0.5 + near_seam * 0.1 + big * 0.25)
    bloom = np.maximum(bloom, r_ring * smooth(0.4, 0.8, mid) * 0.8)
    # paint chips: on the edges, the seams and the rivets first
    chip_bias = near_seam * 0.25 + r_ring * 0.3
    chips = smooth(1.0 - st["chips"], 1.0 - st["chips"] + 0.04, fine * 0.55 + mid * 0.35 + chip_bias * 0.6)
    # where the paint is gone altogether (the wreck)
    bare = smooth(st["paint_cover"] - 0.05, st["paint_cover"] + 0.05, 1.0 - (big * 0.75 + mid * 0.25)) \
        if st["paint_cover"] < 1.0 else np.zeros((h, w))

    # ---- albedo
    tone = np.vectorize(lambda p: ((p * 40503) % 997) / 997.0 - 0.5)(lay.plate)   # a little plate-to-plate drift
    # touch-up patches (a slightly different grey over a rectangle-ish blob), a slow wash of grime and fading, grain
    patch = smooth(0.6, 0.7, fnoise(rng, h, w, [(px_m * 0.14, 1.0), (px_m * 0.05, 0.4)]))
    wash = fnoise(rng, h, w, [(px_m * 0.12, 1.0), (px_m * 0.04, 0.5)], aspect=3.0)
    paint = st["paint"][None, None, :] * (1.0 + tone[..., None] * 0.08 + (big[..., None] - 0.5) * 0.12
                                          + (patch[..., None] - 0.5) * 0.05 - (wash[..., None] - 0.5) * 0.12
                                          + (fine[..., None] - 0.5) * 0.05)
    a = paint * (1.0 + r_mask[..., None] * 0.10 * (fine[..., None] > 0.4))   # paint worn thin on the heads
    rust_col = mix(st["rust_d"][None, None, :], st["rust_l"][None, None, :], smooth(0.2, 0.8, mid * 0.7 + fine * 0.3))
    a = mix(a, mix(st["primer"][None, None, :], st["bare"][None, None, :], smooth(0.5, 0.7, fine)), chips * 0.9)
    a = mix(a, rust_col, np.clip(bare, 0, 1))
    a = mix(a, rust_col * 0.95, np.clip(bloom * 0.85, 0, 1))
    a = mix(a, rust_col * (0.85 + 0.3 * runs[..., None]), np.clip(rust_runs, 0, 1) * 0.9)

    rough = 0.6 + (fine - 0.5) * 0.10 + (big - 0.5) * 0.08
    metal = np.zeros((h, w))
    rough = np.where(chips > 0.5, 0.48, rough)
    metal = np.where((chips > 0.5) & (fine > 0.6), 0.6, metal)
    rust_amt = np.clip(np.maximum.reduce([bare, bloom * 0.85, rust_runs * 0.9]), 0, 1)
    rough = rough * (1 - rust_amt) + 0.9 * rust_amt
    metal = metal * (1 - rust_amt)
    hgt = hgt + (fine - 0.5) * rust_amt * 1.2 * st["pitting"] - chips * 0.25 + bare * (mid - 0.5) * 0.8

    # salt: white blotches and efflorescence weeping from the seams
    salt = smooth(0.78, 0.92, mid * 0.5 + big * 0.5) * st["salt_amt"] * 0.5
    salt = np.maximum(salt, rust_runs * 0.0)
    salt_runs = streaks(rng, h, w, [(rng.uniform(0, w), ((s + 0.03) % tv) * pv, rng.uniform(0.2, 0.7), 0.01, 0.4)
                                    for s in seams for _ in range(int(tu * 2 * st["salt_amt"]))], pu, pv)
    salt = np.maximum(salt, salt_runs * 0.6)

    scum = np.zeros((h, w))
    if waterline:
        # tide marks: wavy horizontal lines of salt in the metre over the boot-top, crust between them, and the
        # dark wet scum right on it
        vb = tv   # the boot-top is the tile's bottom edge
        wave = blur(rng.standard_normal((h, w)), px_m * 0.25, 2)[0:1, :]
        wave = (wave - wave.mean()) / (wave.std() + 1e-9)
        brk = fnoise(rng, h, w, [(px_m * 0.2, 1.0), (px_m * 0.05, 0.5)])
        for i, (dv, wd, amt) in enumerate([(0.82, 0.015, 0.35), (0.5, 0.03, 0.3), (0.26, 0.04, 0.45)]):
            vc = (vb - dv + wave * 0.02 * (1 + i * 0.5)) * pv
            line = np.exp(-((lay.V * pv - vc) / (wd * pv)) ** 2) * amt
            salt = np.maximum(salt, line * smooth(0.35, 0.7, brk * 0.6 + mid * 0.25 + fine * 0.15))
        band = smooth(vb - 1.05, vb - 0.15, lay.V)
        salt = np.maximum(salt, band * smooth(0.6, 0.85, mid * 0.5 + big * 0.5) * 0.4)
        scum = smooth(vb - 0.22 - 0.03 * (big - 0.5), vb - 0.05, lay.V) * (0.75 + 0.25 * fine)
    if fouling:
        # below the boot-top: slime and weed stain in patches, barnacle crust in a few
        foul = smooth(0.5, 0.85, big * 0.7 + mid * 0.3)
        a = mix(a, st["scum"][None, None, :] * (0.9 + 0.3 * fine[..., None]), foul * 0.6)
        crust = smooth(0.8, 0.9, mid * 0.6 + big * 0.4) * smooth(0.45, 0.6, fine)
        hgt = hgt + crust * (fine - 0.3) * 1.5
        rough = np.maximum(rough, foul * 0.85)
        salt = salt * (1 - foul)
    if deck_edge:
        edge = smooth(0.14 * pv, 0.0, lay.V * pv)   # the top 14 cm: worn, rust in the paint
        a = mix(a, rust_col * 0.8, edge * smooth(0.35, 0.6, mid) * 0.8)
        a = a * (1.0 - edge[..., None] * 0.18)
    a = mix(a, st["salt"][None, None, :] * (0.92 + 0.12 * fine[..., None]), np.clip(salt, 0, 1) * 0.85)
    rough = np.maximum(rough, np.clip(salt, 0, 1) * 0.92)
    a = mix(a, st["scum"][None, None, :] * (0.85 + 0.3 * fine[..., None]), np.clip(scum, 0, 1))
    rough = rough * (1 - scum) + 0.36 * scum

    # ---- occlusion from the shape (grooves, rivet feet) and grime in the seams
    cav = np.clip(blur(hgt, 3.0) - hgt, 0, None)
    ao = 1.0 - np.clip(cav * 0.22, 0, 0.4)
    ao = ao * (1.0 - r_ring * 0.15)
    a = a * (0.78 + 0.22 * ao[..., None]) * (1.0 - 0.10 * np.exp(-(lay.d_any / 2.0) ** 2))[..., None]
    rough = np.clip(rough + (1 - ao) * 0.1, 0.36, 1.0)

    nrm = height_to_normal(hgt, strength=1.1)
    orm = np.stack([ao, rough, metal], axis=-1)
    d = os.path.join(OUT, name, "textures")
    save_rgb(os.path.join(d, name + "_albedo.png"), np.clip(a, 0, 1))
    save_rgb(os.path.join(d, name + "_normal.png"), nrm)
    save_rgb(os.path.join(d, name + "_orm.png"), orm)
    # report the albedo's average saturation / value (docs/ART_BIBLE.md section 7: saturation under 0.30)
    mx, mn = a.max(axis=-1), a.min(axis=-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    print("%-20s %dx%d  %.1f x %.1f m  sat %.3f  val %.3f  rough %.2f" % (name, w, h, tu, tv, sat.mean(), mx.mean(), rough.mean()))


def main():
    only = sys.argv[1:]
    sets = [
        ("uboat_plating", dict(w=2048, h=2048, tu=5.8, tv=5.0, seams=[0.0, 1.25, 2.5, 3.75],
                               butts=[[0.4, 3.3], [1.85, 4.75], [0.95, 3.85], [2.6, 5.5]], style="grey", seed=287,
                               slots=True, waterline=True, deck_edge=True)),
        ("uboat_plating_wreck", dict(w=1024, h=1024, tu=5.8, tv=5.0, seams=[0.0, 1.25, 2.5, 3.75],
                                     butts=[[0.4, 3.3], [1.85, 4.75], [0.95, 3.85], [2.6, 5.5]], style="wreck",
                                     seed=2871, slots=True, waterline=True, deck_edge=True)),
        ("steel_plating", dict(w=1024, h=1024, tu=2.9, tv=2.5, seams=[0.0, 1.25], butts=[[0.4], [1.85]],
                               style="grey", seed=2872)),
        ("red_lead_plating", dict(w=1024, h=1024, tu=2.9, tv=2.5, seams=[0.0, 1.25], butts=[[0.4], [1.85]],
                                  style="red", seed=2873, fouling=True)),
    ]
    for name, kw in sets:
        if only and name not in only:
            continue
        make_set(name, **kw)


if __name__ == "__main__":
    main()
