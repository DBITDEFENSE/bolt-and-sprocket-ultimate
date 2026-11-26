#!/usr/bin/env python3
"""GRAVELIGHT T-280: the explosion's textures, drawn from noise (no photographs, no samples). License: Ours.

  assets/ours/vfx/blast/blast_puff.png    256 x 256, a 2 x 2 atlas of billowing puffs (cauliflower smoke):
                                         R = how the puff is lit from above (a normal from the density's slope),
                                         G = heat (the dense, turbulent middle that glows while the puff is fire),
                                         B = fine detail noise, A = density.
  assets/ours/vfx/blast/blast_scorch.png 256 x 256, the soot mark a blast leaves: a black heart, burnt spokes thrown
                                         outward, a ragged rim of scorched earth.

Run from the repo root:   python -I gravelight/tools_src/gen_blast_textures.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy and Pillow.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ours", "vfx", "blast")


def value_noise(rng, n, cells):
    """Smooth value noise of `cells` lattice cells over an n x n image (tileable)."""
    g = rng.random((cells, cells))
    x = np.linspace(0, cells, n, endpoint=False)
    xi = x.astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    x0, x1 = xi % cells, (xi + 1) % cells
    a = g[np.ix_(x0, x0)]
    b = g[np.ix_(x0, x1)]
    c = g[np.ix_(x1, x0)]
    d = g[np.ix_(x1, x1)]
    fy = xf[:, None]
    fx = xf[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, n, base=4, octaves=5):
    out = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(rng, n, base * 2 ** o) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def blur(a, k=3):
    for _ in range(k):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


def puff(rng, n=128):
    """One billowing puff: overlapping round lobes, their edges eaten by noise, lit from above."""
    y, x = np.mgrid[0:n, 0:n]
    u = (x + 0.5) / n * 2 - 1
    v = (y + 0.5) / n * 2 - 1
    dens = np.zeros((n, n))
    lobes = [(0.0, 0.02, 0.6)]
    for _ in range(9):
        a = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(0.2, 0.5)
        lobes.append((np.cos(a) * r, np.sin(a) * r * 0.9 - 0.03, rng.uniform(0.28, 0.45)))
    for cx, cy, rad in lobes:
        d2 = ((u - cx) ** 2 + (v - cy) ** 2) / (rad * rad)
        dens = dens + np.exp(-d2 * 1.6) * 0.5            # soft round lobes that add up into billows
    big = fbm(rng, n, 4, 5)
    fine = fbm(rng, n, 16, 3)
    dens = dens * (0.35 + 1.3 * big) * (0.9 + 0.2 * fine)
    r = np.sqrt(u * u + v * v)
    dens *= smoothstep(1.0, 0.5, r)           # nothing reaches the cell's edge
    alpha = 1.0 - np.exp(-dens * 2.6)         # thin at the fringe, dense in the billows
    # lit from above-left: a normal from the slope of the blurred density
    h = blur(alpha, 10)
    gy, gx = np.gradient(h)
    nx, ny, nz = -gx * 5.0, -gy * 5.0, np.ones_like(h) * 0.25
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    lx, ly, lz = -0.45, -0.75, 0.5
    ll = np.sqrt(lx * lx + ly * ly + lz * lz)
    lit = np.clip((nx * lx + ny * ly + nz * lz) / (ln * ll), 0, 1)
    lit = (0.3 + 0.7 * lit) * (0.72 + 0.5 * (big - 0.5) + 0.1 * (fine - 0.5))
    heat = np.clip(alpha ** 1.6 * (0.55 + 0.9 * (fbm(rng, n, 8, 4) - 0.35)), 0, 1)
    heat *= smoothstep(0.95, 0.3, r)
    return np.stack([lit, heat, fine, alpha], -1)


def scorch(rng, n=256):
    y, x = np.mgrid[0:n, 0:n]
    u = (x + 0.5) / n * 2 - 1
    v = (y + 0.5) / n * 2 - 1
    r = np.sqrt(u * u + v * v)
    a = np.arctan2(v, u)
    spokes = np.zeros((n, n))
    for _ in range(26):
        s = rng.uniform(-np.pi, np.pi)
        w = rng.uniform(40, 160)
        reach = rng.uniform(0.6, 1.0)
        spokes = np.maximum(spokes, np.cos(a - s).clip(0) ** w * smoothstep(reach, reach * 0.4, r))
    noise = fbm(rng, n, 6, 5)
    fine = fbm(rng, n, 24, 3)
    edge = 0.5 + 0.22 * (noise - 0.5) * 2 + spokes * 0.42
    k = np.clip(1 - r / np.maximum(0.05, edge), 0, 1)
    heart = smoothstep(0.42, 0.0, r + (noise - 0.5) * 0.25)
    alpha = np.clip(k ** 0.6 * (0.7 + 0.3 * fine) + heart * 0.3, 0, 0.96)
    alpha *= smoothstep(1.0, 0.85, r)
    # colour: black at the heart, a burnt brown towards the rim, a few grey ash flecks
    col = np.stack([0.025 + 0.06 * (1 - heart) * k, 0.02 + 0.04 * (1 - heart) * k, 0.015 + 0.025 * (1 - heart) * k], -1)
    ash = smoothstep(0.78, 0.86, fine) * smoothstep(0.2, 0.6, r) * 0.18
    col = col + ash[..., None]
    return np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)


def save(path, arr):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(2801)
    cells = [puff(rng) for _ in range(4)]
    atlas = np.concatenate([np.concatenate(cells[:2], 1), np.concatenate(cells[2:], 1)], 0)
    save(os.path.join(OUT, "blast_puff.png"), atlas)
    save(os.path.join(OUT, "blast_scorch.png"), scorch(np.random.default_rng(2802)))


if __name__ == "__main__":
    main()
