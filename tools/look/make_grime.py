#!/usr/bin/env python3
"""UPDATE 12 section 2 (DECISIONS T-208): the shared wear layer's texture.

Writes assets/materials/textures/look_grime.png: a 512x512 tileable RGBA grime map that the material pass
(gravelight/world/look/look_materials.gd) puts on every world StandardMaterial3D as a multiply detail layer, so
assets from different artists sit together. RGB is the dirt colour (a brown-grey that darkens what it covers), alpha
the grime amount (blotches, streaks running down, fine speckle), 0 where the surface stays clean. Deterministic
(seeded), periodic (FFT-filtered noise wraps at the edges), our own work.

    python -I tools/look/make_grime.py [out.png] [--size 512] [--seed 1944]
"""
import argparse
import os

import numpy as np
from PIL import Image


def band_noise(rng: np.random.Generator, size: int, lo: float, hi: float, aniso: float = 1.0) -> np.ndarray:
    """Periodic noise with frequencies between lo and hi cycles per tile (aniso > 1 stretches it vertically)."""
    white = rng.standard_normal((size, size))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None] * size
    fx = np.fft.fftfreq(size)[None, :] * size / aniso
    r = np.sqrt(fx * fx + fy * fy)
    mask = np.exp(-((np.log(np.maximum(r, 1e-6)) - np.log(np.sqrt(lo * hi))) ** 2) / (2 * (np.log(hi / lo) / 2.5) ** 2))
    mask[0, 0] = 0.0
    out = np.real(np.fft.ifft2(f * mask))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def smooth01(x: np.ndarray, a: float, b: float) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make(size: int, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    blotch = band_noise(rng, size, 2.0, 6.0)
    mid = band_noise(rng, size, 8.0, 24.0)
    streak = band_noise(rng, size, 4.0, 24.0, aniso=6.0)   # long vertical runs (water stains)
    speck = band_noise(rng, size, 60.0, 160.0)
    a = smooth01(blotch * 0.7 + mid * 0.45, -0.6, 2.2) * 0.42
    a += smooth01(streak, 0.6, 2.4) * 0.16
    a += smooth01(speck, 1.4, 2.8) * 0.12
    a = np.clip(a, 0.0, 0.6)
    tone = 0.5 + 0.5 * np.tanh(mid * 0.6)
    # dirt: a soot brown-grey, warmer where it is thick (#5a4c3e .. #6e6458), multiplied over the albedo
    r = 0.36 + 0.07 * tone
    g = 0.31 + 0.07 * tone
    b = 0.25 + 0.08 * tone
    rgba = np.stack([r, g, b, a], axis=-1)
    return Image.fromarray(np.clip(rgba * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", nargs="?", default="assets/materials/textures/look_grime.png")
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--seed", type=int, default=1944)
    a = ap.parse_args()
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    img = make(a.size, a.seed)
    img.save(a.out, optimize=True)
    arr = np.asarray(img).astype(float) / 255.0
    print(f"{a.out}: {a.size}x{a.size}, mean grime {arr[..., 3].mean():.3f}, max {arr[..., 3].max():.3f}, "
          f"{os.path.getsize(a.out) // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
