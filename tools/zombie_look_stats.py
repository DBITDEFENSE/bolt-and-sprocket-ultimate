#!/usr/bin/env python3
"""T-269: how much colour a rendered crowd of zombies carries.

For every <scene>.png with a <scene>_bg.png beside it (gravelight/tools_src/shots_zombie_look.gd), the crowd's
pixels are the ones that differ from the empty view; over them this prints

  sat_mean / sat_median   HSV saturation (0..1) of the crowd as drawn, after the map's light and grade
  sat_p90                 the saturation the most coloured tenth reaches
  coloured                share of the crowd's pixels with saturation >= 0.25 and value >= 0.08 (read as a colour)
  hue_bins                how many of twelve 30-degree hue bins hold at least 4 % of the coloured pixels
  hue_spread              circular standard deviation of the coloured pixels' hue, degrees (0 = one hue)
  value_mean              mean HSV value (brightness) of the crowd
  ab_spread               colour variety: the standard deviation of the crowd's pixels in the CIELAB a*b* plane (a
                          crowd in one colour under a coloured lamp is saturated but has a small spread)

and writes stats.json into the directory. Usage:
  python -I tools/zombie_look_stats.py docs/captures/t269/before/map00_crossroads [more dirs...]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter


def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0)
    gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0)
    bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0
    return h * 360.0, s, mx


def lab_ab(rgb):
    """CIELAB a*, b* of sRGB pixels (D65)."""
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    x = (lin @ np.array([0.4124, 0.3576, 0.1805])) / 0.95047
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    z = (lin @ np.array([0.0193, 0.1192, 0.9505])) / 1.08883
    f = lambda t: np.where(t > 0.008856, np.cbrt(t), 7.787 * t + 16.0 / 116.0)
    return 500.0 * (f(x) - f(y)), 200.0 * (f(y) - f(z))


def measure(shot, bg):
    ia = Image.open(shot).convert("RGB")
    ib = Image.open(bg).convert("RGB")
    if ia.size != ib.size:
        return None
    a = np.asarray(ia).astype(np.float64) / 255.0
    # the film grain is new every frame: the mask comes from blurred copies (and is eroded by the blur's radius, so
    # the statistics are of the figures' inside, not of their edges against the room); the colour from the sharp one
    fa = np.asarray(ia.filter(ImageFilter.GaussianBlur(3))).astype(np.float64) / 255.0
    fb = np.asarray(ib.filter(ImageFilter.GaussianBlur(3))).astype(np.float64) / 255.0
    raw = (np.abs(fa - fb).max(-1) > 0.06).astype(np.uint8) * 255
    mask = np.asarray(Image.fromarray(raw).filter(ImageFilter.MinFilter(5))) > 0
    Image.fromarray((mask * 255).astype(np.uint8)).save(shot[:-4] + "_mask.png")
    n = int(mask.sum())
    if n < 500:
        return {"pixels": n}
    h, s, v = hsv(a[mask])
    col = (s >= 0.25) & (v >= 0.08)
    out = {
        "pixels": n,
        "share_of_frame": round(n / mask.size, 4),
        "sat_mean": round(float(s.mean()), 4),
        "sat_median": round(float(np.median(s)), 4),
        "sat_p90": round(float(np.percentile(s, 90)), 4),
        "coloured": round(float(col.mean()), 4),
        "value_mean": round(float(v.mean()), 4),
    }
    # colour variety: how far the crowd's pixels spread in the a*b* plane. A lamp that tints the whole crowd orange
    # raises the saturation of a grey crowd too, but moves every pixel the same way: it does not raise this.
    la, lb = lab_ab(a[mask])
    out["ab_spread"] = round(float(math.sqrt(la.var() + lb.var())), 2)
    if col.sum() >= 50:
        hc = h[col]
        hist = np.histogram(hc, bins=12, range=(0, 360))[0] / float(len(hc))
        out["hue_bins"] = int((hist >= 0.04).sum())
        out["hue_hist"] = [round(float(x), 3) for x in hist]
        ang = np.deg2rad(hc)
        r = math.hypot(float(np.cos(ang).mean()), float(np.sin(ang).mean()))
        out["hue_spread"] = round(math.degrees(math.sqrt(max(0.0, -2.0 * math.log(max(r, 1e-9))))), 1)
    else:
        out["hue_bins"] = 0
        out["hue_spread"] = 0.0
    return out


def main():
    dirs = sys.argv[1:]
    if not dirs:
        print(__doc__)
        return 2
    for d in dirs:
        res = {}
        for f in sorted(os.listdir(d)):
            if not f.endswith("_bg.png"):
                continue
            shot = os.path.join(d, f[:-7] + ".png")
            if os.path.exists(shot):
                m = measure(shot, os.path.join(d, f))
                if m is not None:
                    res[f[:-7]] = m
        with open(os.path.join(d, "stats.json"), "w", encoding="utf-8") as fh:
            json.dump(res, fh, indent=1)
        print(d)
        for k, m in res.items():
            if "sat_mean" not in m:
                print("  %-16s (crowd not found: %d pixels differ)" % (k, m["pixels"]))
                continue
            print("  %-16s sat mean %.3f median %.3f p90 %.3f | coloured %4.1f %% | hue bins %2d spread %5.1f deg | ab spread %5.2f | value %.3f | %d px"
                  % (k, m["sat_mean"], m["sat_median"], m["sat_p90"], 100 * m["coloured"], m["hue_bins"], m["hue_spread"], m["ab_spread"], m["value_mean"], m["pixels"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
