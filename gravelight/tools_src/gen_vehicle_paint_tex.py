#!/usr/bin/env python3
"""T-253 (UPDATE 19): the two tiling textures the vehicle paint shaders sample (our own work, numbers only: filtered
noise, no photographs). Run from the repo root:

    python -I gravelight/tools_src/gen_vehicle_paint_tex.py

Writes assets/ours/world/vehicle_paint/
    paint_mask.png    512, RGBA: R broad grime blotches, G chipping speckle, B rain streaks (run along V),
                      A fine grain
    paint_normal.png  512, tangent normal (OpenGL, +Y up): rolled / cast steel's orange peel, pits, a few scratches
Both tile (the noise is shaped in the frequency domain, so it is periodic). Deterministic (seeded).
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join("assets", "ours", "world", "vehicle_paint")
rng = np.random.default_rng(253)


def band(lo, hi, beta=1.0, aniso=(1.0, 1.0)):
    """Periodic noise with energy between `lo` and `hi` cycles per tile, falling as 1/f^beta; `aniso` stretches."""
    fy = np.fft.fftfreq(N)[:, None] * N * aniso[1]
    fx = np.fft.fftfreq(N)[None, :] * N * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where((f >= lo) & (f <= hi), 1.0 / np.maximum(f, 1.0) ** beta, 0.0)
    spec = amp * np.exp(2j * np.pi * rng.random((N, N)))
    x = np.real(np.fft.ifft2(spec))
    lo_v, hi_v = np.percentile(x, [0.5, 99.5])
    return np.clip((x - lo_v) / max(hi_v - lo_v, 1e-9), 0.0, 1.0)


def contrast(x, lo, hi):
    return np.clip((x - lo) / (hi - lo), 0.0, 1.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    grime = contrast(0.65 * band(1, 12, 1.4) + 0.35 * band(8, 60, 1.0), 0.25, 0.8)
    # chips: islands (a low band gates a high one), hard-edged when the shader thresholds it
    chips = contrast(band(3, 20, 1.0) * 0.55 + band(24, 180, 0.6) * 0.45, 0.3, 0.75)
    streak = contrast(band(1, 200, 0.9, aniso=(1.0, 14.0)) * 0.7 + band(2, 30, 1.0) * 0.3, 0.3, 0.8)
    grain = band(70, 250, 0.2)
    mask = np.stack([grime, chips, streak, grain], axis=-1)
    Image.fromarray((mask * 255.0 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "paint_mask.png"), optimize=True)

    h = 0.55 * band(24, 200, 0.9) + 0.25 * band(6, 40, 1.2)
    pits = contrast(band(30, 120, 0.3), 0.72, 0.9)
    h = h - 0.35 * pits
    # a few long scratches: thin lines at random angles, wrapped
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(22):
        a = rng.uniform(0, np.pi)
        x0, y0 = rng.uniform(0, N, 2)
        ln = rng.uniform(40, 260)
        dx = ((xx - x0 + N / 2) % N) - N / 2
        dy = ((yy - y0 + N / 2) % N) - N / 2
        along = dx * np.cos(a) + dy * np.sin(a)
        across = -dx * np.sin(a) + dy * np.cos(a)
        h -= 0.10 * np.exp(-(across / 0.9) ** 2) * (np.abs(along) < ln)
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    k = 15.0
    nx, ny, nz = -gx * k, gy * k, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], axis=-1) * 0.5 + 0.5
    Image.fromarray((nrm * 255.0 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, "paint_normal.png"), optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
