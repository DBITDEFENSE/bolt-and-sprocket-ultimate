"""The nine Helvetia Automaten AG tonic cabinets (UPDATE_05 section 5, DECISIONS T-094; docs/JINGLES.md, PERKS_LORE.md).

    blender -b -P tools_src/blender/world/perk_cabinets.py [-- <perk_id> ...]

Writes assets/ours/world/perk_<perk_id>/model.glb for each tonic. Each cabinet keeps its gameplay footprint
(PerkMachine._shape_footprint) and the label positions of InteractableArt.perk_layout (copied in LAYOUT below: keep
the two in step), and is built from the lore: its unique shell, its own bottle (three on the window shelf and the one
the hatch dispenses), its mascot and its idle-motion part.

GLB nodes the game reads (PerkMachine._build_cabinet):
  Body       everything static (the shell, trim, window furniture, hatch, slot, Ledger dial, price plate, bottles)
  Neon       the tubes round the sign board and the lamp globe ("neon" slot: lit / dark with the power)
  Backlight  the panel behind the bottles ("backlight" slot: the brand colour powered, faint violet dark)
  Dispense   the bottle that drops into the hatch on a purchase (hidden at rest; pivot = its base)
  idle parts per shape (pivot = the joint): Arm (Ironhide's Fassl), Bellows + Dome (Second Wind), Paws (Trigger
             Tonic's Flitzi), PompL / PompR / FlashL / FlashR (Twin Barrel's Pomp), Belt + RollerL / RollerR
             (Marathon's treadmill), Head + EyePlate (Hawkeye), Sign + Gear (Packmule), Wheel + Burst (Blastproof),
             Arc + Needle + Coil (Overclock)
  anchors    CapAnchor (the PerkCap medallion's centre on the sign board), LampAnchor, SteamAnchor (Ironhide)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wo_lib as W  # noqa: E402

FP = {
    "barrel": (1.2, 1.9, 1.2), "cabinet": (0.8, 2.3, 0.6), "crate": (1.0, 2.0, 0.65), "twin": (1.2, 2.1, 0.6),
    "teardrop": (1.0, 2.4, 0.9), "periscope": (0.9, 1.8, 0.65), "wagon": (1.7, 1.7, 0.85), "safe": (1.1, 1.9, 0.95),
    "coil": (0.8, 2.3, 0.6),
}

PERKS = {
    # id: (shape, brand colour, glass colour, bottle kind)
    "ironhide_stout": ("barrel", "9e2a1e", "3a1a0c", "stout"),
    "second_wind": ("cabinet", "9cc3e0", "b8d8ee", "schnapps"),
    "trigger_tonic": ("crate", "b8c41e", "a8c020", "soda"),
    "twin_barrel": ("twin", "d18a1f", "b86a14", "twin"),
    "marathon_malt": ("teardrop", "8fc4f0", "8fc4f0", "streamline"),
    "hawkeye_brandy": ("periscope", "22553a", "1e4a2c", "decanter"),
    "packmule_porter": ("wagon", "6b5a2e", "4a3010", "swingtop"),
    "blastproof_bock": ("safe", "e0661a", "8a3a10", "bock"),
    "overclock_cordial": ("coil", "2fa8a0", "2fa8a0", "cordial"),
}


def layout(shape, fp):
    fz = -fp[2] * 0.5
    L = {
        "barrel": {"sign": (0, 2.2, -0.42), "sign_size": (1.3, 0.36), "win": (0, 1.28, -0.63), "win_size": (0.46, 0.4),
                   "lamp": (0.38, 1.98, -0.05), "price": (0, 0.44, -0.62), "hatch": (0, 0.74, -0.62), "slot": (0.32, 1.02, -0.58)},
        "cabinet": {"sign": (0, 2.62, -0.2), "sign_size": (1.15, 0.3), "win": (0, 1.36, fz - 0.02), "win_size": (0.5, 0.56),
                    "lamp": (0, 2.36, 0.0), "price": (0, 0.42, fz - 0.02), "hatch": (0, 0.8, fz - 0.02), "slot": (0.28, 1.0, fz - 0.01)},
        "crate": {"sign": (0, 2.22, fz + 0.1), "sign_size": (1.45, 0.34), "win": (0, 1.4, fz - 0.02), "win_size": (0.56, 0.5),
                  "lamp": (-0.38, 2.05, 0.05), "price": (0, 0.5, fz - 0.02), "hatch": (0, 0.88, fz - 0.02), "slot": (0.36, 1.12, fz - 0.01)},
        "twin": {"sign": (0, 2.36, -0.1), "sign_size": (1.35, 0.32), "win": (0, 1.3, -0.28), "win_size": (0.4, 0.46),
                 "lamp": (0, 2.08, 0.05), "price": (0, 0.46, -0.3), "hatch": (0, 0.84, -0.27), "slot": (-0.14, 1.66, -0.27),
                 "dial": (0.12, 1.67, -0.28)},
        "teardrop": {"sign": (0, 2.66, -0.12), "sign_size": (1.45, 0.32), "win": (0, 1.42, -0.47), "win_size": (0.42, 0.5),
                     "lamp": (0, 2.44, 0.0), "price": (0, 0.36, -0.44), "hatch": (0, 0.86, -0.47), "slot": (0.26, 1.06, -0.45)},
        "periscope": {"sign": (0, 2.02, fz + 0.12), "sign_size": (1.05, 0.3), "win": (0, 1.24, fz - 0.03), "win_size": (0.5, 0.42),
                      "lamp": (0.32, 1.9, 0.12), "price": (0, 0.42, fz - 0.03), "hatch": (0, 0.78, fz - 0.03), "slot": (0.33, 0.98, fz - 0.03)},
        "wagon": {"sign": (0, 2.0, fz + 0.12), "sign_size": (1.3, 0.32), "win": (-0.3, 0.98, fz - 0.02), "win_size": (0.56, 0.4),
                  "lamp": (0.75, 1.62, -0.25), "price": (0.38, 0.5, fz - 0.02), "hatch": (0.38, 0.86, fz - 0.02), "slot": (0.38, 1.1, fz - 0.01)},
        "safe": {"sign": (0, 2.18, fz + 0.12), "sign_size": (1.3, 0.34), "win": (-0.05, 1.32, fz - 0.06), "win_size": (0.4, 0.4),
                 "lamp": (0.4, 1.98, 0.1), "price": (0, 0.36, fz - 0.06), "hatch": (-0.05, 0.74, fz - 0.06), "slot": (0.36, 1.32, fz - 0.06),
                 "round": True},
        "coil": {"sign": (0, 2.16, fz + 0.06), "sign_size": (1.1, 0.3), "win": (0, 1.14, fz - 0.02), "win_size": (0.44, 0.44),
                 "lamp": (0, 2.46, 0.05), "price": (0, 0.38, fz - 0.02), "hatch": (0, 0.7, fz - 0.02), "slot": (0.27, 0.95, fz - 0.01),
                 "dial": (-0.27, 0.98, fz - 0.03), "round": True},
    }
    return L[shape]


def cap_center(lay):
    sc, ss = lay["sign"], lay["sign_size"]
    r = cap_radius(lay)
    return (sc[0] - ss[0] * 0.5 + r + 0.05, sc[1], sc[2] - 0.006)


def cap_radius(lay):
    return min(0.115, lay["sign_size"][1] * 0.5 - 0.03)


def dial_pos(lay):
    if "dial" in lay:
        return lay["dial"]
    s = lay["slot"]
    return (s[0], s[1] + 0.2, s[2] - 0.005)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


# ================================================================== the bottles

# profile (radius, y) in units of the bottle's height; extras drawn per kind
BOTTLES = {
    "stout": [(0, 0), (0.19, 0), (0.205, 0.04), (0.205, 0.5), (0.17, 0.62), (0.08, 0.72), (0.07, 0.88), (0.082, 0.9), (0.082, 0.95), (0, 0.95)],
    "schnapps": [(0, 0), (0.12, 0), (0.135, 0.03), (0.135, 0.55), (0.1, 0.65), (0.045, 0.72), (0.04, 0.94), (0, 0.94)],
    "soda": [(0, 0), (0.15, 0), (0.165, 0.08), (0.12, 0.28), (0.165, 0.46), (0.15, 0.58), (0.07, 0.75), (0.058, 0.9), (0.07, 0.93), (0, 0.93)],
    "twin": [(0, 0), (0.085, 0), (0.095, 0.05), (0.095, 0.56), (0.05, 0.7), (0.038, 0.93), (0.048, 0.95), (0, 0.95)],
    "streamline": [(0, 0), (0.11, 0), (0.16, 0.14), (0.17, 0.34), (0.13, 0.6), (0.07, 0.78), (0.045, 0.9), (0, 0.9)],
    "decanter": [(0, 0), (0.14, 0), (0.22, 0.12), (0.24, 0.3), (0.2, 0.48), (0.08, 0.6), (0.058, 0.74), (0.09, 0.78), (0, 0.78)],
    "swingtop": [(0, 0), (0.19, 0), (0.2, 0.05), (0.2, 0.58), (0.16, 0.68), (0.09, 0.78), (0.085, 0.88), (0, 0.88)],
    "bock": [(0, 0), (0.12, 0), (0.22, 0.12), (0.24, 0.28), (0.2, 0.42), (0.06, 0.52), (0.05, 0.86), (0.065, 0.88), (0, 0.9)],
    "cordial": [(0, 0), (0.16, 0), (0.17, 0.05), (0.17, 0.45), (0.12, 0.55), (0.05, 0.6), (0.045, 0.83), (0.06, 0.86), (0, 0.86)],
}


def bottle(p, base, h, kind, brand, glass_hex, segs=12):
    """One tonic bottle standing at `base` (its foot centre), `h` tall."""
    prof = [(r * h, y * h) for (r, y) in BOTTLES[kind]]
    gl = W.glass(glass_hex)
    if kind == "twin":
        for sx in (-0.095, 0.095):
            W.lathe(p, prof, gl, c=add(base, (sx * h, 0, 0)), segs=segs)
            W.cyl(p, add(base, (sx * h, 0.97 * h, 0)), 0.045 * h, 0.05 * h, "mats_brass", segs=8)
        W.box(p, add(base, (-0.19 * h, 0.3 * h, -0.02 * h)), add(base, (0.19 * h, 0.42 * h, 0.02 * h)), "mats_brass", 0.002)
        W.box(p, add(base, (-0.17 * h, 0.15 * h, -0.105 * h)), add(base, (0.17 * h, 0.28 * h, -0.095 * h)), W.paint("2a1608"), 0.0)
        return
    W.lathe(p, prof, gl, c=base, segs=segs)
    top = max(y for (_, y) in prof)
    # the label band (paper with the brand's print) round the body
    body_r = max(r for (r, y) in prof if y < top * 0.6)
    W.cyl(p, add(base, (0, top * 0.28, 0)), body_r * 1.02, top * 0.2, "mats_paper", segs=segs, caps=False)
    W.cyl(p, add(base, (0, top * 0.28, 0)), body_r * 1.025, top * 0.05, W.paint(brand), segs=segs, caps=False)
    if kind in ("stout", "soda"):
        W.cyl(p, add(base, (0, top + 0.012 * h, 0)), 0.09 * h, 0.05 * h, W.paint(brand), segs=10)      # crown cap
    elif kind == "schnapps":
        W.cyl(p, add(base, (0, top + 0.03 * h, 0)), 0.042 * h, 0.08 * h, "mats_cardboard", segs=8)    # cork
    elif kind == "streamline":
        W.cyl(p, add(base, (0, top + 0.02 * h, 0)), 0.055 * h, 0.06 * h, "mats_chrome", segs=10)
    elif kind == "decanter":
        W.dot(p, add(base, (0, top + 0.07 * h, 0)), 0.08 * h, gl, 10)                                  # the stopper
    elif kind == "swingtop":
        W.dot(p, add(base, (0, top + 0.035 * h, 0)), 0.07 * h, "mats_cream", 8)
        W.tube(p, [add(base, (-0.09 * h, top - 0.06 * h, 0)), add(base, (-0.08 * h, top + 0.06 * h, 0)),
                   add(base, (0.08 * h, top + 0.06 * h, 0)), add(base, (0.09 * h, top - 0.06 * h, 0))], 0.008 * h, "mats_steel", 4)
    elif kind == "bock":
        W.cyl(p, add(base, (0, top - 0.04 * h, 0)), 0.075 * h, 0.12 * h, "mats_red_paint", segs=10)    # wax dip
    elif kind == "cordial":
        W.cyl(p, add(base, (0, top + 0.02 * h, 0)), 0.06 * h, 0.05 * h, "mats_copper", segs=8)
        pts = []
        for k in range(25):
            a = k * 0.62
            pts.append(add(base, (math.cos(a) * 0.178 * h, (0.08 + k * 0.014) * h, math.sin(a) * 0.178 * h)))
        W.tube(p, pts, 0.008 * h, "mats_copper", 4, caps=False)


# ================================================================== shared furniture

def bottle_window(body, back, lay, perk):
    shape, brand, gl, kind = PERKS[perk]
    c, sz = lay["win"], lay["win_size"]
    w, h = sz
    rnd = lay.get("round", False)
    rows = 2 if h > 0.45 else 1
    for r in range(rows):
        sy = c[1] - h * 0.5 + 0.03 + r * (h / rows)
        W.box(body, (c[0] - w * 0.46, sy - 0.015, c[2] + 0.03), (c[0] + w * 0.46, sy, c[2] + 0.12), "mats_chrome", 0.003)
        bh = min(0.17, h / rows - 0.1)
        for i in range(3):
            bx = c[0] - w * 0.3 + i * (w * 0.6 / 2.0)
            bottle(body, (bx, sy, c[2] + 0.07), bh, kind, brand, gl, 8)
    # the backlit panel behind the shelf (the script lights it)
    if rnd:
        W.cyl(back, (c[0], c[1], c[2] + 0.13), w * 0.52, 0.02, "backlight", axis="z", segs=24, smooth=False)
        W.torus(body, (c[0], c[1], c[2] - 0.01), w * 0.56, 0.035, "mats_chrome_worn", axis="z", segs=28, rsegs=8)
        for k in range(10):
            a = math.tau * k / 10.0
            W.dot(body, (c[0] + math.cos(a) * w * 0.56, c[1] + math.sin(a) * w * 0.56, c[2] - 0.045), 0.016, "mats_steel", 4)
        for gx in range(5):
            x = c[0] - w * 0.36 + gx * (w * 0.72 / 4.0)
            hh = math.sqrt(max(0.0, (w * 0.5) ** 2 - (x - c[0]) ** 2))
            W.strut(body, (x, c[1] - hh, c[2] - 0.005), (x, c[1] + hh, c[2] - 0.005), 0.008, "mats_chrome")
    else:
        W.box(back, (c[0] - w * 0.49, c[1] - h * 0.49, c[2] + 0.12), (c[0] + w * 0.49, c[1] + h * 0.49, c[2] + 0.14), "backlight", 0.0)
        t = 0.04
        for (a, b) in [((c[0] - w * 0.5 - t, c[1] - h * 0.5 - t), (c[0] + w * 0.5 + t, c[1] - h * 0.5)),
                       ((c[0] - w * 0.5 - t, c[1] + h * 0.5), (c[0] + w * 0.5 + t, c[1] + h * 0.5 + t)),
                       ((c[0] - w * 0.5 - t, c[1] - h * 0.5), (c[0] - w * 0.5, c[1] + h * 0.5)),
                       ((c[0] + w * 0.5, c[1] - h * 0.5), (c[0] + w * 0.5 + t, c[1] + h * 0.5))]:
            W.box(body, (a[0], a[1], c[2] - 0.035), (b[0], b[1], c[2] + 0.025), "mats_chrome", 0.008)
        bars = int(w / 0.075)
        for i in range(bars):
            x = c[0] - w * 0.5 + (i + 0.5) * (w / bars)
            W.strut(body, (x, c[1] - h * 0.5, c[2] - 0.012), (x, c[1] + h * 0.5, c[2] - 0.012), 0.007, "mats_chrome", True, 6)
        W.strut(body, (c[0] - w * 0.5, c[1], c[2] - 0.016), (c[0] + w * 0.5, c[1], c[2] - 0.016), 0.009, "mats_chrome", True, 6)


def hatch(body, c, w=0.34):
    W.box(body, (c[0] - w * 0.5, c[1] - 0.1, c[2] - 0.02), (c[0] + w * 0.5, c[1] + 0.1, c[2] + 0.03), "mats_chrome", 0.01)
    W.box(body, (c[0] - w * 0.5 + 0.03, c[1] - 0.07, c[2] - 0.026), (c[0] + w * 0.5 - 0.03, c[1] + 0.07, c[2] - 0.015), "mats_window_dark", 0.0)
    W.obox(body, (c[0], c[1] - 0.075, c[2] - 0.05), (w - 0.04, 0.02, 0.07), "mats_chrome", (-12, 0, 0), 0.004)
    W.obox(body, (c[0], c[1] + 0.085, c[2] - 0.03), (w * 0.5, 0.012, 0.02), "mats_brass", None, 0.003)


def scrip_slot(body, c):
    W.box(body, (c[0] - 0.055, c[1] - 0.09, c[2] - 0.01), (c[0] + 0.055, c[1] + 0.09, c[2] + 0.02), "mats_chrome", 0.006)
    W.box(body, (c[0] - 0.006, c[1] + 0.02, c[2] - 0.016), (c[0] + 0.006, c[1] + 0.07, c[2] - 0.008), "mats_window_dark", 0.0)
    W.obox(body, (c[0], c[1] - 0.035, c[2] - 0.016), (0.012, 0.075, 0.01), "mats_brass", None, 0.002)
    W.obox(body, (c[0], c[1] - 0.02, c[2] - 0.018), (0.05, 0.01, 0.01), "mats_brass", None, 0.002)
    W.obox(body, (c[0], c[1] - 0.05, c[2] - 0.018), (0.05, 0.01, 0.01), "mats_brass", None, 0.002)


def ledger_dial(body, c):
    W.cyl(body, c, 0.08, 0.03, "mats_brass", axis="z", segs=20, bevel=0.006)
    W.cyl(body, add(c, (0, 0, -0.016)), 0.064, 0.004, "mats_gauge_face", axis="z", segs=20, smooth=False)
    W.obox(body, add(c, (0.014, 0.012, -0.022)), (0.008, 0.05, 0.004), "mats_black_paint", (0, 0, -35), 0.0)
    W.dot(body, add(c, (0, 0, -0.022)), 0.008, "mats_black_paint", 6)


def price_plate(body, c):
    W.box(body, (c[0] - 0.3, c[1] - 0.07, c[2] + 0.005), (c[0] + 0.3, c[1] + 0.07, c[2] + 0.025), "mats_nameplate", 0.004)
    W.box(body, (c[0] - 0.31, c[1] - 0.08, c[2] + 0.02), (c[0] + 0.31, c[1] + 0.08, c[2] + 0.03), "mats_brass", 0.004)
    for sx in (-0.29, 0.29):
        for sy in (-0.06, 0.06):
            W.dot(body, (c[0] + sx, c[1] + sy, c[2] + 0.002), 0.006, "mats_steel", 6)


def sign_board(body, neon, lay, brand_dark):
    sc, ss = lay["sign"], lay["sign_size"]
    W.box(body, (sc[0] - ss[0] * 0.5, sc[1] - ss[1] * 0.5, sc[2] + 0.012), (sc[0] + ss[0] * 0.5, sc[1] + ss[1] * 0.5, sc[2] + 0.05), W.enamel(brand_dark), 0.008)
    W.box(body, (sc[0] - ss[0] * 0.5 - 0.02, sc[1] - ss[1] * 0.5 - 0.02, sc[2] + 0.04), (sc[0] + ss[0] * 0.5 + 0.02, sc[1] + ss[1] * 0.5 + 0.02, sc[2] + 0.07), "mats_chrome", 0.01)
    # the tubes round the board, bent at the corners
    hx, hy = ss[0] * 0.5 - 0.04, ss[1] * 0.5 - 0.04
    pts = []
    for (x, y) in [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy), (-hx, -hy)]:
        pts.append((sc[0] + x, sc[1] + y, sc[2]))
    W.tube(neon, pts, 0.011, "neon", 6, caps=False)
    # tube clips
    for (x, y) in [(-hx, 0), (hx, 0), (0, -hy), (0, hy)]:
        W.box(body, (sc[0] + x - 0.012, sc[1] + y - 0.012, sc[2]), (sc[0] + x + 0.012, sc[1] + y + 0.012, sc[2] + 0.014), "mats_chrome", 0.0)
    # the PerkCap medallion's bezel (the glyph itself is the script's: PerkCap drawn into a texture)
    cc = cap_center(lay)
    r = cap_radius(lay)
    W.torus(body, add(cc, (0, 0, 0.006)), r + 0.012, 0.012, "mats_chrome", axis="z", segs=28, rsegs=6)
    W.cyl(body, add(cc, (0, 0, 0.014)), r + 0.006, 0.014, W.enamel(brand_dark), axis="z", segs=28)
    W.anchor("CapAnchor", add(cc, (0, 0, -0.004)))


def lamp(body, neon, lay):
    lp = lay["lamp"]
    W.cyl(body, add(lp, (0, -0.07, 0)), 0.06, 0.06, "mats_brass", segs=14, bevel=0.006)
    W.torus(body, lp, 0.085, 0.012, "mats_brass", segs=18, rsegs=6)
    for a in (0.0, 120.0, 240.0):
        d = (math.cos(math.radians(a)) * 0.08, 0, math.sin(math.radians(a)) * 0.08)
        W.strut(body, add(lp, (d[0], -0.05, d[2])), add(lp, (d[0] * 0.4, 0.11, d[2] * 0.4)), 0.012, "mats_brass", True, 6)
    W.sphere(neon, add(lp, (0, 0.05, 0)), (0.13, 0.15, 0.13), "neon", 14, 8)
    W.anchor("LampAnchor", add(lp, (0, 0.05, 0)))


def plinth(body, w, d, h=0.1):
    W.box(body, (-w * 0.5, 0, -d * 0.5), (w * 0.5, h, d * 0.5), "mats_black_paint", 0.01)
    W.box(body, (-w * 0.32, h * 0.25, -d * 0.5 - 0.01), (w * 0.32, h * 0.8, -d * 0.5), "mats_brass", 0.003)


def dispense(lay, perk):
    shape, brand, gl, kind = PERKS[perk]
    hc = lay["hatch"]
    base = (hc[0], hc[1] - 0.068, hc[2] - 0.045)
    p = W.Part("Dispense", base)
    bottle(p, base, 0.15, kind, brand, gl, 12)
    p.build()


def common(perk, fp, lay, body, neon, back):
    shape, brand, gl, kind = PERKS[perk]
    dark = W.hexs(tuple(c * 0.22 for c in W._hex(brand)))
    sign_board(body, neon, lay, dark)
    bottle_window(body, back, lay, perk)
    hatch(body, lay["hatch"])
    scrip_slot(body, lay["slot"])
    ledger_dial(body, dial_pos(lay))
    price_plate(body, lay["price"])
    lamp(body, neon, lay)


# ================================================================== the nine shells

def ironhide(p, fp, lay, en):
    """A barrel stood on end: iron-red enamel staves with a bulge, black hoops with brass rivets, a steam valve, and
    Fassl the tin barrel on the lid flexing his arm (the Arm part)."""
    r = fp[0] * 0.5
    W.lathe(p, [(r + 0.02, 0.0), (r + 0.02, 0.1), (r * 0.86, 0.1)], "mats_black_paint", segs=32, smooth=False, cap_hi=False)
    prof = [(r * 0.86, 0.1), (r * 0.94, 0.4), (r * 0.985, 0.7), (r, 0.98), (r * 0.985, 1.26), (r * 0.94, 1.56), (r * 0.86, 1.86)]
    W.lathe(p, prof, en, segs=32, cap_lo=False)
    rad_at = lambda y: r * (0.86 + 0.14 * math.sin(math.pi * max(0.0, min(1.0, (y - 0.1) / 1.76))))  # noqa: E731
    # stave seams: dark grooves down the bulge (the front is left clear for the panel)
    for k in range(18):
        a = math.tau * k / 18.0
        if abs(math.atan2(math.sin(a - math.pi * 1.5), math.cos(a - math.pi * 1.5))) < 0.5:
            continue
        pts = [(math.cos(a) * (rad_at(y) + 0.002), y, math.sin(a) * (rad_at(y) + 0.002)) for y in (0.14, 0.5, 0.98, 1.46, 1.82)]
        W.tube(p, pts, 0.005, "mats_black_paint", 4, caps=False)
    for hy in (0.2, 0.55, 1.41, 1.76):
        hr = rad_at(hy) + 0.01
        W.torus(p, (0, hy, 0), hr, 0.022, "lib_iron", segs=28, rsegs=4)
        for k in range(12):
            a = math.pi + math.pi * (k + 0.5) / 12.0
            W.dot(p, (math.cos(a) * (hr + 0.02), hy, math.sin(a) * (hr + 0.02)), 0.012, "mats_brass", 4)
    # the head: oak boards inside the chime, a bung
    W.cyl(p, (0, 1.87, 0), r * 0.84, 0.04, "lib_planks", segs=32, smooth=False)
    W.torus(p, (0, 1.885, 0), r * 0.87, 0.03, "lib_iron", segs=32, rsegs=6)
    W.cyl(p, (0.18, 1.905, 0.15), 0.07, 0.05, "mats_brass", segs=14, bevel=0.01)
    # the front panel (window, hatch and slot sit on it), brass edged
    W.box(p, (-0.32, 0.32, -0.62), (0.32, 1.5, -0.5), en, 0.015)
    for side in (-1.0, 1.0):
        W.box(p, (side * 0.32 - 0.015, 0.32, -0.632), (side * 0.32 + 0.015, 1.5, -0.5), "mats_brass", 0.004)
    W.box(p, (-0.335, 1.49, -0.632), (0.335, 1.515, -0.5), "mats_brass", 0.004)
    W.box(p, (-0.335, 0.305, -0.632), (0.335, 0.33, -0.5), "mats_brass", 0.004)
    # the steam valve on the right flank, with its red handwheel (puffs every ~8 s: SteamAnchor)
    W.cyl(p, (0.64, 1.6, 0.0), 0.035, 0.16, "mats_brass", axis="x", segs=12)
    W.cyl(p, (0.72, 1.66, 0.0), 0.03, 0.14, "mats_brass", segs=12)
    W.torus(p, (0.72, 1.75, 0.0), 0.06, 0.012, "mats_red_paint", segs=16, rsegs=5)
    W.strut(p, (0.66, 1.75, 0), (0.78, 1.75, 0), 0.012, "mats_red_paint", True, 5)
    W.strut(p, (0.72, 1.75, -0.06), (0.72, 1.75, 0.06), 0.012, "mats_red_paint", True, 5)
    W.cyl(p, (0.72, 1.6, 0.0), 0.022, 0.05, "mats_brass", axis="x", segs=10)
    W.anchor("SteamAnchor", (0.76, 1.6, 0.0))
    # sign posts
    for sx in (-0.5, 0.5):
        W.strut(p, (sx, 1.86, -0.3), (sx, 2.05, -0.37), 0.04, "lib_iron", False)
    # Fassl, the riveted tin barrel, on the lid: body, hoops, a stubby left arm, a hobnail boot on his barrel-end
    m = (-0.3, 1.9, 0.1)
    W.lathe(p, [(0.08, 0.02), (0.1, 0.12), (0.1, 0.2), (0.08, 0.28)], en, c=m, segs=16)
    for my in (0.06, 0.24):
        W.torus(p, add(m, (0, my, 0)), 0.1, 0.01, "lib_iron", segs=16, rsegs=4)
    W.box(p, add(m, (-0.06, 0.0, -0.05)), add(m, (0.06, 0.035, 0.08)), "mats_black_paint", 0.01)
    for k in range(4):
        W.dot(p, add(m, (-0.04 + k * 0.027, 0.0, 0.07)), 0.007, "mats_steel", 4)
    W.tube(p, [add(m, (-0.09, 0.17, 0)), add(m, (-0.15, 0.12, 0)), add(m, (-0.16, 0.06, 0))], 0.02, "lib_iron", 6)
    W.dot(p, add(m, (-0.16, 0.05, 0)), 0.026, "lib_iron", 8)
    # the face: two rivet eyes and a painted grin
    for ex in (-0.03, 0.03):
        W.dot(p, add(m, (ex, 0.2, -0.098)), 0.012, "mats_cream", 6)
    W.obox(p, add(m, (0.0, 0.155, -0.1)), (0.08, 0.012, 0.006), "mats_cream", None, 0.0)
    # the flexing arm (pivot at the shoulder): upper arm out, forearm up, a fist and a bulging bicep
    sh = add(m, (0.09, 0.17, 0))
    a = W.Part("Arm", sh)
    W.tube(a, [sh, add(sh, (0.1, 0.03, 0)), add(sh, (0.11, 0.15, 0))], 0.022, "lib_iron", 6)
    W.dot(a, add(sh, (0.07, 0.045, 0)), 0.032, "lib_iron", 8)
    W.dot(a, add(sh, (0.112, 0.17, 0)), 0.03, "lib_iron", 8)
    a.build()


def second_wind(p, fp, lay, en):
    """A slender apothecary cabinet: pale-blue enamel, cream cornice, white-cross side panels, a glass dome with the
    bottle that turns (Dome), a bellows on the left flank that breathes (Bellows), the swallow painted over the
    factory angel."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    plinth(p, fp[0] + 0.06, fp[2] + 0.06, 0.12)
    W.box(p, (-hw, 0.12, -hd), (hw, 1.9, hd), en, 0.02)
    # cornice: two steps and a cove; the skirting
    W.box(p, (-hw - 0.03, 1.9, -hd - 0.03), (hw + 0.03, 1.95, hd + 0.03), "mats_cream", 0.012)
    W.box(p, (-hw - 0.045, 1.95, -hd - 0.045), (hw + 0.045, 1.985, hd + 0.045), "mats_cream", 0.01)
    W.box(p, (-hw - 0.02, 0.12, -hd - 0.02), (hw + 0.02, 0.21, hd + 0.02), "mats_cream", 0.01)
    for sx in (-1.0, 1.0):
        W.box(p, (sx * hw - 0.022, 0.21, -hd - 0.022), (sx * hw + 0.022, 1.9, -hd + 0.03), "mats_chrome", 0.006)
        px = sx * (hw + 0.004)
        W.box(p, (px - 0.004, 1.06, -0.065), (px + 0.004, 1.54, 0.065), "mats_enamel_white", 0.002)
        W.box(p, (px - 0.004, 1.235, -0.21), (px + 0.004, 1.365, 0.21), "mats_enamel_white", 0.002)
        # recessed panel mouldings on the flanks
        W.box(p, (px - 0.006, 0.32, -0.24), (px + 0.006, 0.92, -0.22), "mats_cream", 0.0)
        W.box(p, (px - 0.006, 0.32, 0.22), (px + 0.006, 0.92, 0.24), "mats_cream", 0.0)
    # the bellows boards are fixed to the flank; the pleats breathe (Bellows: scaled in Y about its foot)
    W.box(p, (-hw - 0.06, 0.58, -0.18), (-hw, 0.6, 0.18), "mats_furniture", 0.004)
    W.strut(p, (-hw - 0.03, 0.6, 0.18), (-hw - 0.03, 0.82, 0.22), 0.012, "mats_brass", True, 5)
    b = W.Part("Bellows", (-hw - 0.03, 0.6, 0.0))
    for i in range(5):
        bw = 0.16 - abs(i - 2.0) * 0.02
        W.box(b, (-hw - 0.05, 0.62 + i * 0.032, -bw), (-hw - 0.004, 0.644 + i * 0.032, bw), "lib_leather", 0.006)
    W.box(b, (-hw - 0.06, 0.78, -0.18), (-hw, 0.8, 0.18), "mats_furniture", 0.004)
    b.build()
    # the swallow, hand-painted over the factory angel (whose trumpet still shows faintly under it)
    sw = (0, 1.76, -hd - 0.004)
    W.obox(p, add(sw, (0.0, 0.0, 0.002)), (0.24, 0.1, 0.002), W.paint("a7b3bc"), None, 0.0)
    W.obox(p, add(sw, (0.09, 0.03, 0.001)), (0.1, 0.012, 0.002), W.paint("b8c2c8"), (0, 0, 30), 0.0)
    W.prism(p, [(-0.16, 0.05), (-0.02, 0.0), (-0.02, 0.025)], 0.0, 0.003, W.paint("1d2740"), c=(0, 1.76, -hd - 0.008))
    W.prism(p, [(0.02, 0.0), (0.16, 0.05), (0.02, 0.025)], 0.0, 0.003, W.paint("1d2740"), c=(0, 1.76, -hd - 0.008))
    W.prism(p, [(-0.025, -0.03), (0.025, -0.03), (0.03, 0.02), (0.0, 0.035), (-0.03, 0.02)], 0.0, 0.003, W.paint("1d2740"), c=(0, 1.76, -hd - 0.008))
    W.prism(p, [(-0.025, -0.03), (0.0, -0.08), (0.025, -0.03)], 0.0, 0.003, W.paint("1d2740"), c=(0, 1.76, -hd - 0.008))
    W.prism(p, [(-0.012, -0.012), (0.012, -0.012), (0.0, 0.012)], 0.0, 0.002, "mats_red_paint", c=(0, 1.745, -hd - 0.012))
    W.box(p, (-0.3, 1.0, -hd - 0.012), (0.3, 1.7, -hd - 0.004), "mats_frosted", 0.0)
    # the dome: a chrome collar, the glass, a brass finial
    W.cyl(p, (0, 2.0, 0), 0.3, 0.05, "mats_chrome", segs=28, bevel=0.01)
    W.torus(p, (0, 2.025, 0), 0.29, 0.015, "mats_brass", segs=28, rsegs=5)
    W.lathe(p, [(0.27, 2.02), (0.27, 2.08), (0.25, 2.18), (0.19, 2.27), (0.1, 2.32), (0.0, 2.335)], "mats_glass", segs=24, cap_lo=False)
    W.dot(p, (0, 2.35, 0), 0.025, "mats_brass", 8)
    # crest posts carry the sign
    for sx in (-0.45, 0.45):
        W.strut(p, (sx, 1.98, -0.1), (sx, 2.5, -0.16), 0.03, "mats_chrome", True, 8)
    # the turning bottle inside the dome (pivot on the turntable)
    d = W.Part("Dome", (0, 2.03, 0))
    W.cyl(d, (0, 2.04, 0), 0.07, 0.02, "mats_chrome", segs=16)
    bottle(d, (0, 2.05, 0), 0.24, "schnapps", "9cc3e0", "b8d8ee", 14)
    d.build()


def trigger(p, fp, lay, en):
    """An upright ammunition crate on angle-iron legs: lime-gold planks, black box-joint battens and chevrons, a
    sunburst round the window, a big chrome lever that does nothing, and Flitzi the frantic tin hare on the lid
    whose paws blur on a cam (Paws)."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            x0, z0 = sx * (hw - 0.03), sz * (hd - 0.03)
            W.box(p, (x0 - 0.03, 0, z0 - 0.004), (x0 + 0.03, 0.34, z0 + 0.004), "lib_iron", 0.002)
            W.box(p, (x0 - 0.004, 0, z0 - 0.03), (x0 + 0.004, 0.34, z0 + 0.03), "lib_iron", 0.002)
            W.box(p, (x0 - 0.05, 0, z0 - 0.05), (x0 + 0.05, 0.012, z0 + 0.05), "lib_iron", 0.002)
    W.box(p, (-hw + 0.02, 0.32, -hd + 0.02), (hw - 0.02, 2.0, hd - 0.02), en, 0.0)
    # the planks of the four faces, each a hair proud or shy of the next
    n = 9
    for i in range(n):
        y0 = 0.36 + i * (1.58 / n)
        y1 = y0 + 1.58 / n - 0.008
        d = 0.03 + W.jit(i, 1, 0.004)
        W.box(p, (-hw + 0.04, y0, -hd), (hw - 0.04, y1, -hd + d), en, 0.006)
        W.box(p, (-hw + 0.04, y0, hd - d), (hw - 0.04, y1, hd), en, 0.006)
        for sx in (-1.0, 1.0):
            W.box(p, (sx * hw - (d if sx > 0 else 0), y0, -hd + 0.04), (sx * hw + (0 if sx > 0 else d), y1, hd - 0.04), en, 0.006)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            W.box(p, (sx * hw - 0.045, 0.3, sz * hd - 0.045), (sx * hw + 0.045, 2.0, sz * hd + 0.045), "mats_black_paint", 0.008)
        W.tube(p, [(sx * (hw + 0.02), 1.62, -0.16), (sx * (hw + 0.08), 1.56, -0.06), (sx * (hw + 0.08), 1.56, 0.06), (sx * (hw + 0.02), 1.62, 0.16)],
               0.016, "lib_burlap", 6)
    W.box(p, (-hw - 0.03, 1.96, -hd - 0.03), (hw + 0.03, 2.04, hd + 0.03), "mats_black_paint", 0.012)
    W.box(p, (-hw - 0.01, 0.3, -hd - 0.02), (hw + 0.01, 0.36, hd + 0.02), "mats_black_paint", 0.008)
    # black chevrons under the hatch, the stencil band over the window
    for i in range(3):
        cy = 0.52 + i * 0.1
        W.prism(p, [(-0.36, -0.02), (0.0, 0.11), (0.36, -0.02), (0.36, 0.03), (0.0, 0.16), (-0.36, 0.03)], 0.0, 0.004,
                "mats_black_paint", c=(0, cy - 0.05, -hd - 0.006))
    W.box(p, (-hw + 0.08, 1.78, -hd - 0.006), (hw - 0.08, 1.88, -hd - 0.001), "mats_black_paint", 0.0)
    # sunburst rays round the window
    wc = (0, lay["win"][1], -hd - 0.008)
    for k in range(13):
        a = math.pi * k / 12.0
        dx, dy = math.cos(a), math.sin(a)
        W.prism(p, [(-0.012, 0.0), (0.012, 0.0), (0.004, 0.17), (-0.004, 0.17)], 0.0, 0.004, "mats_black_paint",
                rot=(0, 0, math.degrees(a) - 90.0), c=(wc[0] + dx * 0.33, wc[1] + 0.03 + dy * 0.33, wc[2]))
    # the big chrome lever on the right flank (it does nothing)
    W.cyl(p, (hw + 0.05, 1.3, 0.0), 0.08, 0.08, "mats_chrome", axis="x", segs=20, bevel=0.01)
    W.strut(p, (hw + 0.1, 1.3, 0.0), (hw + 0.12, 1.72, -0.16), 0.035, "mats_chrome", True, 10)
    W.dot(p, (hw + 0.12, 1.75, -0.17), 0.055, "mats_red_paint", 12)
    # sign posts
    for sx in (-0.44, 0.44):
        W.strut(p, (sx, 2.04, -hd + 0.14), (sx, 2.07, -hd + 0.14), 0.04, "mats_black_paint", False)
    # Flitzi on the lid's left: a tin cut-out hare, pinwheel eyes, an ammo belt over each shoulder
    m = (-0.3, 2.04, 0.12)
    W.prism(p, [(-0.07, 0.0), (0.07, 0.0), (0.08, 0.14), (0.05, 0.2), (-0.05, 0.2), (-0.08, 0.14)], -0.012, 0.012, W.paint("a89a7c"), c=m, bevel=0.003)
    W.prism(p, [(-0.05, 0.19), (0.05, 0.19), (0.06, 0.27), (0.0, 0.3), (-0.06, 0.27)], -0.012, 0.012, W.paint("a89a7c"), c=m, bevel=0.003)
    for ex in (-1.0, 1.0):
        W.prism(p, [(ex * 0.02, 0.28), (ex * 0.05, 0.28), (ex * 0.06, 0.44), (ex * 0.035, 0.45)], -0.008, 0.008, W.paint("a89a7c"), c=m, bevel=0.002)
        W.torus(p, add(m, (ex * 0.025, 0.24, -0.014)), 0.016, 0.005, "mats_black_paint", axis="z", segs=10, rsegs=4)
        W.dot(p, add(m, (ex * 0.025, 0.24, -0.016)), 0.006, "mats_black_paint", 4)
        W.strut(p, add(m, (ex * 0.06, 0.18, -0.016)), add(m, (-ex * 0.04, 0.02, -0.016)), 0.018, "mats_brass", False)
    p_ = W.Part("Paws", add(m, (0, 0.15, -0.02)))
    for ex in (-1.0, 1.0):
        W.strut(p_, add(m, (ex * 0.05, 0.15, -0.02)), add(m, (ex * 0.12, 0.11, -0.06)), 0.022, W.paint("a89a7c"), True, 6)
        W.obox(p_, add(m, (ex * 0.13, 0.1, -0.07)), (0.03, 0.07, 0.02), "lib_iron", (0, 0, ex * 15), 0.003)   # a spent magazine in each paw
    p_.build()


def twin_barrel(p, fp, lay, en):
    """Two amber towers like a side-by-side stood on its butt, a brass bridge with the window, walnut flanks, and
    Feldwebel Pomp the tin sergeant between the muzzles firing his pistols in turns (PompL/PompR, FlashL/FlashR)."""
    plinth(p, fp[0] + 0.04, fp[2] + 0.04, 0.1)
    W.box(p, (-0.32, 0.1, -0.05), (0.32, 2.0, 0.26), "mats_walnut", 0.01)
    for sx in (-0.32, 0.32):
        W.lathe(p, [(0.27, 0.1), (0.28, 0.14), (0.28, 1.96), (0.27, 2.0)], en, c=(sx, 0, 0), segs=28, cap_lo=False, cap_hi=False)
        for by in (0.25, 0.75, 1.55, 1.9):
            W.torus(p, (sx, by, 0), 0.285, 0.016, "mats_brass", segs=20, rsegs=4)
        # the muzzle crown and its dark bore
        W.lathe(p, [(0.28, 2.0), (0.3, 2.02), (0.3, 2.08), (0.21, 2.08), (0.2, 2.04)], "mats_chrome", c=(sx, 0, 0), segs=28, cap_lo=False, cap_hi=False)
        W.cyl(p, (sx, 2.06, 0), 0.2, 0.04, "mats_window_dark", segs=24, smooth=False)
        W.box(p, (sx + (0.22 if sx > 0 else -0.3), 0.35, -0.16), (sx + (0.3 if sx > 0 else -0.22), 1.75, 0.16), "mats_walnut", 0.012)
        for ry in (0.45, 1.65):
            W.dot(p, (sx + (0.305 if sx > 0 else -0.305), ry, 0.0), 0.012, "mats_brass", 6)
    # the brass bridge carrying the window, the dark panel under it, the "Bitters" plate
    W.box(p, (-0.28, 0.98, -0.26), (0.28, 1.58, 0.1), "mats_brass", 0.012)
    W.box(p, (-0.26, 1.0, -0.285), (0.26, 1.56, -0.25), W.enamel("2a1608"), 0.004)
    W.box(p, (-0.22, 0.66, -0.26), (0.22, 0.98, 0.0), W.enamel("2a1608"), 0.008)
    W.box(p, (-0.14, 1.58, -0.26), (0.14, 1.78, -0.2), "mats_chrome", 0.008)
    for sx in (-0.5, 0.5):
        W.strut(p, (sx, 2.08, -0.02), (sx, 2.2, -0.06), 0.03, "mats_brass", True, 8)
    # Feldwebel Pomp: chest out, medals, the handlebar moustache
    m = (0, 2.02, 0.1)
    W.box(p, add(m, (-0.05, 0.0, -0.035)), add(m, (0.05, 0.15, 0.035)), W.paint("3b4a2a"), 0.012)
    for k in range(3):
        W.dot(p, add(m, (-0.025 + k * 0.022, 0.1, -0.04)), 0.008, "mats_brass", 4)
    W.dot(p, add(m, (0, 0.2, 0)), 0.048, W.paint("c9a27a"), 10)
    W.prism(p, [(-0.09, 0.0), (-0.06, -0.012), (0.0, 0.004), (0.06, -0.012), (0.09, 0.0), (0.06, 0.012), (0.0, 0.016), (-0.06, 0.012)],
            -0.006, 0.006, "mats_black_paint", c=add(m, (0, 0.18, -0.045)))
    W.cyl(p, add(m, (0, 0.255, 0)), 0.05, 0.05, W.paint("3b4a2a"), segs=12)
    W.box(p, add(m, (-0.05, 0.23, -0.07)), add(m, (0.05, 0.24, -0.02)), "mats_black_paint", 0.002)
    for s, nm in ((-1.0, "L"), (1.0, "R")):
        sh = add(m, (s * 0.05, 0.12, 0))
        arm = W.Part("Pomp" + nm, sh)
        W.tube(arm, [sh, add(sh, (s * 0.07, 0.03, -0.05)), add(sh, (s * 0.09, 0.03, -0.09))], 0.016, W.paint("3b4a2a"), 6)
        W.obox(arm, add(sh, (s * 0.095, 0.035, -0.11)), (0.022, 0.035, 0.07), "lib_iron", None, 0.003)
        arm.build()
        f = W.Part("Flash" + nm, add(sh, (s * 0.095, 0.045, -0.16)))
        W.sphere(f, add(sh, (s * 0.095, 0.045, -0.16)), (0.05, 0.05, 0.07), "neon_ffd27a", 8, 4)
        f.build()


def marathon(p, fp, lay, en):
    """An Art Deco teardrop stood upright like a racing locomotive's nose: sky blue over white, chrome speed-lines,
    a flat front for the window, and the winged boot over a treadmill that rolls (Belt, RollerL/RollerR)."""
    sx, sz = 1.0, (fp[2] * 0.92) / fp[0]
    W.lathe(p, [(0.43, 0.0), (0.45, 0.02), (0.45, 0.1), (0.43, 0.12)], "mats_chrome", segs=32, cap_hi=False, sx=sx, sz=sz)
    lo = [(0.41, 0.12), (0.46, 0.4), (0.49, 0.7), (0.5, 0.92)]
    hi = [(0.5, 0.92), (0.49, 1.25), (0.45, 1.6), (0.37, 1.9), (0.26, 2.12), (0.14, 2.26), (0.04, 2.33), (0.0, 2.335)]
    W.lathe(p, lo, "mats_enamel_white", segs=32, sx=sx, sz=sz, cap_hi=False)
    W.lathe(p, hi, en, segs=32, sx=sx, sz=sz, cap_lo=False)
    W.torus(p, (0, 0.92, 0), 0.505, 0.012, "mats_chrome", segs=40, rsegs=5, rot=None)
    # chrome speed-lines following the profile, three each side
    prof = lo + hi[1:]
    for side in (-1.0, 1.0):
        for k in range(3):
            pts = []
            for (r, y) in prof:
                if y < 0.3 or y > 2.1:
                    continue
                a = math.radians(90 + side * (90 - 14 - k * 10))
                pts.append((math.sin(a) * r * sx * 1.012, y, -math.cos(a) * r * sz * 1.012))
            W.tube(p, pts, 0.01, "mats_chrome", 5)
    # the flat front for the window
    W.box(p, (-0.27, 0.66, -0.46), (0.27, 1.76, -0.36), en, 0.02)
    for x in (-0.27, 0.27):
        W.box(p, (x - 0.014, 0.66, -0.47), (x + 0.014, 1.76, -0.36), "mats_chrome", 0.005)
    # the treadmill under the boot: housing, rollers, the belt of slats (rolls), the winged boot mid-stride
    b = (0, 1.86, -0.37)
    W.box(p, add(b, (-0.17, -0.04, -0.04)), add(b, (0.17, -0.025, 0.06)), "mats_chrome", 0.004)
    for s in (-1.0, 1.0):
        W.box(p, add(b, (s * 0.17 - 0.012, -0.05, -0.04)), add(b, (s * 0.17 + 0.012, 0.02, 0.06)), "mats_chrome", 0.003)
    for nm, s in (("RollerL", -1.0), ("RollerR", 1.0)):
        rp = add(b, (s * 0.135, -0.005, 0.01))
        rl = W.Part(nm, rp)
        W.cyl(rl, rp, 0.022, 0.1, "mats_steel", axis="z", segs=10)
        rl.build()
    belt = W.Part("Belt", add(b, (0, 0.018, 0.01)))
    for k in range(13):
        x = -0.15 + k * 0.025
        W.box(belt, add(b, (x - 0.01, 0.014, -0.035)), add(b, (x + 0.01, 0.022, 0.055)), "mats_rubber", 0.002)
    belt.build()
    W.obox(p, add(b, (0.0, 0.1, -0.02)), (0.06, 0.13, 0.05), W.paint("2e1d12"), (0, 0, -10), 0.01)
    W.obox(p, add(b, (0.035, 0.045, -0.02)), (0.12, 0.045, 0.055), W.paint("2e1d12"), None, 0.01)
    for k in range(4):
        W.dot(p, add(b, (-0.01 + k * 0.025, 0.02, -0.02)), 0.006, "mats_steel", 4)
    for wk in range(4):
        W.prism(p, [(0.0, 0.0), (-0.12 + wk * 0.012, 0.012), (-0.11 + wk * 0.012, 0.03)], -0.005, 0.005, "mats_enamel_white",
                rot=(0, 0, 18 + wk * 12), c=add(b, (-0.03, 0.13, -0.02)))
    # crown and sign posts
    W.cyl(p, (0, 2.33, 0), 0.09, 0.04, "mats_chrome", segs=16, bevel=0.008)
    for x in (-0.55, 0.55):
        W.strut(p, (x * 0.5, 2.2, -0.05), (x, 2.52, -0.08), 0.025, "mats_chrome", True, 8)


def hawkeye(p, fp, lay, en):
    """Forest-green enamel and polished walnut, brass trim, a medallion of the monocled hawk whose painted eyes
    slide (EyePlate), and the periscope whose lens turns to watch the nearest player (Head)."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    plinth(p, fp[0] + 0.06, fp[2] + 0.06, 0.1)
    W.box(p, (-hw, 0.1, -hd), (hw, 1.8, hd), en, 0.02)
    W.box(p, (-hw + 0.06, 0.18, -hd - 0.02), (hw - 0.06, 1.66, -hd + 0.01), "mats_walnut", 0.01)
    # raised walnut panels with brass beads
    for (y0, y1) in ((0.2, 0.62), (1.5, 1.64)):
        W.box(p, (-hw + 0.09, y0, -hd - 0.03), (hw - 0.09, y1, -hd - 0.015), "mats_walnut", 0.008)
    W.box(p, (-hw - 0.025, 1.76, -hd - 0.025), (hw + 0.025, 1.84, hd + 0.025), "mats_brass", 0.012)
    W.box(p, (-hw - 0.02, 0.1, -hd - 0.02), (hw + 0.02, 0.16, hd + 0.02), "mats_brass", 0.008)
    for sx in (-1.0, 1.0):
        W.box(p, (sx * hw - 0.016, 0.1, -hd - 0.016), (sx * hw + 0.016, 1.8, -hd + 0.016), "mats_brass", 0.004)
    # the hawk medallion: brass oval, the bird in a hunting jacket with a monocle; its eyes are the EyePlate
    mc = (0, 1.57, -hd - 0.035)
    W.torus(p, mc, 0.08, 0.012, "mats_brass", axis="z", segs=24, rsegs=5)
    W.cyl(p, add(mc, (0, 0, 0.006)), 0.075, 0.008, W.paint("3a2a1a"), axis="z", segs=24)
    W.prism(p, [(-0.04, -0.06), (0.04, -0.06), (0.05, 0.0), (0.03, 0.04), (-0.02, 0.05), (-0.05, 0.01)], 0.0, 0.004, W.paint("6a4a2a"), c=add(mc, (0, 0, -0.004)))
    W.prism(p, [(0.03, 0.02), (0.07, 0.0), (0.03, -0.005)], 0.0, 0.004, "mats_yellow_paint", c=add(mc, (0, 0, -0.008)))
    W.torus(p, add(mc, (0.012, 0.02, -0.01)), 0.018, 0.004, "mats_brass", axis="z", segs=12, rsegs=4)
    e = W.Part("EyePlate", add(mc, (0, 0.02, -0.012)))
    for ex in (-0.012, 0.012):
        W.dot(e, add(mc, (ex, 0.02, -0.012)), 0.006, "mats_black_paint", 6)
    e.build()
    # the periscope mast (the head turns)
    W.cyl(p, (0, 1.86, 0.12), 0.1, 0.05, "mats_brass", segs=18, bevel=0.01)
    W.cyl(p, (0, 2.15, 0.12), 0.05, 0.6, "mats_brass", segs=14)
    W.torus(p, (0, 2.1, 0.12), 0.06, 0.012, "mats_black_paint", segs=14, rsegs=4)
    W.torus(p, (0, 1.95, 0.12), 0.06, 0.012, "mats_black_paint", segs=14, rsegs=4)
    for sx in (-0.42, 0.42):
        W.strut(p, (sx, 1.84, -hd + 0.2), (sx, 1.92, -hd + 0.16), 0.03, "mats_brass", True, 8)
    h = W.Part("Head", (0, 2.5, 0.12))
    W.box(h, (-0.09, 2.42, -0.04), (0.09, 2.59, 0.22), en, 0.02)
    W.box(h, (-0.1, 2.58, -0.05), (0.1, 2.61, 0.23), "mats_brass", 0.006)
    W.cyl(h, (0, 2.5, -0.06), 0.065, 0.05, "mats_brass", axis="z", segs=18, bevel=0.006)
    W.cyl(h, (0, 2.5, -0.085), 0.05, 0.01, "mats_glass", axis="z", segs=18)
    W.cyl(h, (0, 2.5, 0.235), 0.04, 0.03, "mats_brass", axis="z", segs=14)
    h.build()


def packmule(p, fp, lay, en):
    """The widest machine: a quartermaster's wagon of a cabinet, brown and olive drab with stencils and brass
    buckles, cart wheels, a luggage rack whose load rattles (Gear), spare rifles bolted to its flank, and the tin
    "Porter" sign swinging from its gallows (Sign)."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    W.box(p, (-hw, 0.14, -hd), (hw, 1.3, hd), en, 0.02)
    W.box(p, (-hw - 0.02, 0.1, -hd - 0.02), (hw + 0.02, 0.2, hd + 0.02), "mats_olive_drab", 0.01)
    W.box(p, (-hw - 0.02, 1.26, -hd - 0.02), (hw + 0.02, 1.32, hd + 0.02), "mats_olive_drab", 0.01)
    # planked sides in olive drab, the stencil band
    for i in range(5):
        y0 = 0.24 + i * 0.2
        W.box(p, (-hw - 0.006, y0, -hd + 0.06), (-hw + 0.01, y0 + 0.19, hd - 0.06), "mats_olive_drab", 0.006)
        W.box(p, (hw - 0.01, y0, -hd + 0.06), (hw + 0.006, y0 + 0.19, hd - 0.06), "mats_olive_drab", 0.006)
    W.box(p, (-hw + 0.08, 0.3, -hd - 0.012), (-0.02, 1.2, -hd + 0.01), "mats_olive_drab", 0.008)
    W.box(p, (0.1, 1.2, -hd - 0.012), (hw - 0.1, 1.24, -hd - 0.004), "mats_black_paint", 0.0)
    for sx in (-0.68, 0.0, 0.68):
        W.box(p, (sx - 0.03, 0.2, -hd - 0.014), (sx + 0.03, 1.3, -hd - 0.002), "lib_leather", 0.003)
        W.box(p, (sx - 0.042, 0.79, -hd - 0.024), (sx + 0.042, 0.87, -hd - 0.012), "mats_brass", 0.004)
        W.box(p, (sx - 0.03, 0.81, -hd - 0.026), (sx + 0.03, 0.85, -hd - 0.022), "mats_window_dark", 0.0)
    # cart wheels at the ends: iron tyre, felloe, hub, eight spokes
    for s in (-1.0, 1.0):
        wc = (s * (hw + 0.005), 0.36, 0)
        W.torus(p, wc, 0.33, 0.035, "lib_iron", rot=(0, 0, 90), segs=32, rsegs=6)
        W.torus(p, wc, 0.29, 0.025, "mats_furniture", rot=(0, 0, 90), segs=32, rsegs=5)
        W.cyl(p, wc, 0.07, 0.1, "mats_furniture", axis="x", segs=14, bevel=0.01)
        W.cyl(p, wc, 0.03, 0.13, "lib_iron", axis="x", segs=10)
        for k in range(8):
            a = math.tau * k / 8.0
            W.strut(p, wc, add(wc, (0, math.sin(a) * 0.28, math.cos(a) * 0.28)), 0.026, "mats_furniture", True, 5)
    # the luggage rack
    for x in (-hw + 0.05, hw - 0.05):
        for z in (-hd + 0.05, hd - 0.05):
            W.strut(p, (x, 1.3, z), (x, 1.5, z), 0.03, "lib_iron", True, 6)
    for z in (-hd + 0.05, hd - 0.05):
        W.strut(p, (-hw + 0.05, 1.5, z), (hw - 0.05, 1.5, z), 0.025, "lib_iron", True, 6)
    # its load (Gear: it rattles): a crate, a canvas bundle, a small crate, straps
    g = W.Part("Gear", (0, 1.32, 0))
    W.box(g, (-0.78, 1.32, -0.3), (-0.2, 1.7, 0.32), "lib_planks", 0.015)
    for x in (-0.76, -0.22):
        W.box(g, (x - 0.02, 1.32, -0.31), (x + 0.02, 1.7, 0.33), "lib_iron", 0.004)
    W.lathe(g, [(0.0, -0.25), (0.13, -0.25), (0.15, -0.2), (0.15, 0.2), (0.13, 0.25), (0.0, 0.25)], "lib_canvas", c=(0.11, 1.46, 0.02), rot=(90, 0, 0), segs=14)
    W.box(g, (0.4, 1.32, -0.2), (0.78, 1.52, 0.3), "lib_planks", 0.012)
    for x in (-0.6, -0.36, 0.1):
        W.box(g, (x - 0.025, 1.32, -0.33), (x + 0.025, 1.72, 0.35), "lib_leather", 0.004)
    g.build()
    # spare rifles bolted along the right flank
    for i in range(2):
        rz = -0.2 + i * 0.3
        a2 = (hw + 0.04, 0.3, rz)
        W.obox(p, add(a2, (0, 0.22, 0.01)), (0.035, 0.45, 0.08), "mats_walnut", None, 0.01)
        W.strut(p, add(a2, (0, 0.45, 0.02)), add(a2, (0, 1.15, 0.0)), 0.02, "lib_iron", True, 8)
        W.box(p, add(a2, (-0.03, 0.55, -0.05)), add(a2, (0.0, 0.6, 0.05)), "mats_brass", 0.004)
        W.box(p, add(a2, (-0.03, 0.95, -0.05)), add(a2, (0.0, 1.0, 0.05)), "mats_brass", 0.004)
    for sx in (-0.5, 0.5):
        W.strut(p, (sx, 1.7, -hd + 0.2), (sx, 1.86, -hd + 0.18), 0.03, "lib_iron", True, 6)
    # the gallows for the swinging tin sign, and the sign itself (pivot at its hooks)
    W.strut(p, (-hw + 0.02, 1.3, -hd + 0.02), (-hw - 0.3, 1.3, -hd + 0.02), 0.03, "lib_iron", False)
    W.strut(p, (-hw + 0.02, 1.1, -hd + 0.02), (-hw - 0.12, 1.3, -hd + 0.02), 0.02, "lib_iron", False)
    sp = (-hw - 0.22, 1.29, -hd + 0.02)
    sg = W.Part("Sign", sp)
    for s in (-0.1, 0.1):
        W.strut(sg, add(sp, (s, 0, 0)), add(sp, (s, -0.12, 0)), 0.008, "mats_steel", True, 4)
    W.box(sg, add(sp, (-0.17, -0.25, -0.004)), add(sp, (0.17, -0.11, 0.004)), "mats_black_paint", 0.003)
    W.box(sg, add(sp, (-0.16, -0.24, -0.006)), add(sp, (0.16, -0.12, 0.006)), W.enamel("c7b37a"), 0.003)
    sg.build()


def blastproof(p, fp, lay, en):
    """A riveted blast locker: black body in an orange-and-black hazard frame, a heavy enamel door with hinge
    knuckles and scorch, a porthole, the wheel handle that gives a quarter turn now and then (Wheel), and the
    cartoon starburst behind "Bock" that flashes (Burst)."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    plinth(p, fp[0] + 0.06, fp[2] + 0.06, 0.08)
    W.box(p, (-hw, 0.08, -hd + 0.06), (hw, 1.9, hd), "mats_black_paint", 0.025)
    W.box(p, (-hw - 0.012, 0.08, -hd + 0.04), (hw + 0.012, 1.9, -hd + 0.1), "stripes_e0661a", 0.008)
    W.box(p, (-hw + 0.1, 0.18, -hd - 0.02), (hw - 0.1, 1.78, -hd + 0.06), en, 0.03, segs=2)
    W.rivets(p, (-hw + 0.14, 1.74, -hd - 0.024), (hw - 0.14, 1.74, -hd - 0.024), 9, 0.014)
    W.rivets(p, (-hw + 0.14, 0.22, -hd - 0.024), (hw - 0.14, 0.22, -hd - 0.024), 9, 0.014)
    W.rivets(p, (-hw + 0.14, 0.3, -hd - 0.024), (-hw + 0.14, 1.66, -hd - 0.024), 7, 0.014)
    W.rivets(p, (hw - 0.14, 0.3, -hd - 0.024), (hw - 0.14, 1.66, -hd - 0.024), 7, 0.014)
    for hy in (0.45, 1.5):
        W.cyl(p, (-hw + 0.08, hy, -hd - 0.03), 0.04, 0.22, "mats_chrome_worn", segs=14, bevel=0.008)
    # the door's dogs (locking bars) and the scorch rising from the bottom
    for dy in (0.5, 1.4):
        W.box(p, (hw - 0.2, dy - 0.025, -hd - 0.05), (hw - 0.04, dy + 0.025, -hd - 0.02), "mats_chrome_worn", 0.006)
    W.box(p, (-hw + 0.12, 0.2, -hd - 0.023), (hw - 0.3, 0.5, -hd - 0.021), "mats_char", 0.0)
    W.box(p, (-hw + 0.2, 0.5, -hd - 0.023), (hw - 0.45, 0.7, -hd - 0.021), "mats_char", 0.0)
    # the wheel hub (the wheel turns)
    W.cyl(p, (0.24, 0.98, -hd - 0.05), 0.05, 0.06, "mats_chrome_worn", axis="z", segs=16, bevel=0.008)
    wp = (0.24, 0.98, -hd - 0.09)
    wh = W.Part("Wheel", wp)
    W.torus(wh, wp, 0.17, 0.022, "mats_chrome_worn", axis="z", segs=28, rsegs=6)
    for k in range(3):
        W.obox(wh, wp, (0.32, 0.026, 0.026), "mats_chrome_worn", (0, 0, k * 60.0), 0.004)
    for k in range(6):
        a = math.tau * k / 6.0
        W.dot(wh, add(wp, (math.cos(a) * 0.17, math.sin(a) * 0.17, -0.01)), 0.024, "mats_red_paint", 8)
    wh.build()
    # the starburst behind "Bock" (right end of the sign; the script flashes it)
    sb = (0.47, lay["sign"][1] - 0.01, lay["sign"][2] + 0.008)
    pts = []
    for k in range(16):
        a = math.tau * k / 16.0
        r = 0.16 if k % 2 == 0 else 0.08
        pts.append((math.cos(a) * r, math.sin(a) * r * 0.85))
    bu = W.Part("Burst", sb)
    W.prism(bu, pts, 0.0, 0.006, "lamp_glass", c=sb)
    bu.build()
    for sx in (-0.48, 0.48):
        W.strut(p, (sx, 1.9, -hd + 0.2), (sx, 2.04, -hd + 0.18), 0.04, "lib_iron", False)
    # Kaboomer's horns on the roof: two curled brass horns either side of a lit fuse
    for s in (-1.0, 1.0):
        W.tube(p, [(s * 0.12, 1.9, 0.15), (s * 0.2, 2.0, 0.15), (s * 0.26, 1.98, 0.1), (s * 0.24, 1.92, 0.06)], 0.025, "mats_brass", 6)
    W.tube(p, [(0, 1.9, 0.15), (0.02, 1.98, 0.14), (0.05, 2.03, 0.16)], 0.008, "mats_black_paint", 4)


def overclock(p, fp, lay, en):
    """A tall teal cabinet with copper bands and cable loops like suspenders, a porthole under the LEER/HALB/VOLL
    gauge (Needle), and an induction coil on a ceramic collar for a crown (Coil glows, Arc snaps); Funki, the tin
    bin, holds a lightning bolt overhead. The maker's own copper and tin: no Darkmatter trim (JINGLES.md 10)."""
    hw, hd = fp[0] * 0.5, fp[2] * 0.5
    plinth(p, fp[0] + 0.06, fp[2] + 0.06, 0.12)
    W.box(p, (-hw, 0.12, -hd), (hw, 2.0, hd), en, 0.02)
    for by in (0.3, 0.92, 1.46, 1.94):
        W.box(p, (-hw - 0.012, by - 0.02, -hd - 0.012), (hw + 0.012, by + 0.02, hd + 0.012), "mats_copper", 0.006)
    for sx in (-1.0, 1.0):
        W.box(p, (sx * hw - 0.02, 0.2, -hd - 0.02), (sx * hw + 0.02, 1.96, -hd + 0.03), "mats_copper", 0.006)
        x = sx * (hw + 0.045)
        for zs in (-1.0, 1.0):
            z0, z1 = zs * 0.12, zs * 0.22
            W.tube(p, [(x, 1.97, z0), (x + sx * 0.07, 1.55, z1), (x + sx * 0.05, 1.05, z0 * 0.6), (x, 0.55, 0.0)], 0.016, "mats_copper", 6)
            W.dot(p, (x, 1.97, z0), 0.026, "mats_brass", 8)
        W.dot(p, (x, 0.55, 0.0), 0.03, "mats_brass", 8)
    # the gauge above the porthole
    gc = (0, 1.62, -hd - 0.025)
    W.cyl(p, gc, 0.2, 0.03, "mats_gauge_face", axis="z", segs=28, smooth=False)
    W.torus(p, add(gc, (0, 0, -0.006)), 0.2, 0.02, "mats_copper", axis="z", segs=32, rsegs=6)
    W.box(p, (-0.24, 1.38, -hd - 0.03), (0.24, 1.44, -hd - 0.005), "mats_copper", 0.006)
    for a in (-60.0, -30.0, 0.0, 30.0, 60.0):
        ang = math.radians(90.0 - a)
        big = a in (-60.0, 0.0, 60.0)
        W.obox(p, (gc[0] + math.cos(ang) * 0.165, gc[1] + math.sin(ang) * 0.165, gc[2] - 0.018),
               (0.012 if big else 0.007, 0.045 if big else 0.025, 0.004), "mats_black_paint", (0, 0, -a), 0.0)
    W.dot(p, add(gc, (0, 0, -0.022)), 0.022, "mats_brass", 8)
    n = W.Part("Needle", (0, 1.62, -hd - 0.05))
    np_ = (0, 1.62, -hd - 0.05)
    W.obox(n, add(np_, (0, 0.075, 0)), (0.012, 0.15, 0.005), "mats_red_paint", None, 0.0)
    W.obox(n, add(np_, (0, -0.03, 0)), (0.02, 0.05, 0.005), "mats_brass", None, 0.0)
    W.dot(n, np_, 0.014, "mats_brass", 6)
    n.build()
    # crown: roof plate, ceramic collar, the coil and its rod (the brass ball is the lamp globe: Neon)
    cz = 0.05
    W.box(p, (-0.24, 2.0, cz - 0.24), (0.24, 2.025, cz + 0.24), "mats_copper", 0.006)
    W.lathe(p, [(0.19, 2.02), (0.19, 2.06), (0.17, 2.09), (0.14, 2.1)], "mats_enamel_white", c=(0, 0, cz), segs=24)
    W.cyl(p, (0, 2.11, cz), 0.14, 0.05, "mats_copper", segs=24)
    pts = []
    for k in range(9 * 12 + 1):
        a = math.tau * k / 12.0
        pts.append((math.cos(a) * 0.16, 2.135 + k * (0.034 / 12.0), cz + math.sin(a) * 0.16))
    W.tube(p, pts, 0.012, "mats_copper", 4, caps=True)
    W.cyl(p, (0, 2.28, cz), 0.026, 0.34, "mats_copper", segs=10)
    # the glow inside the coil (the script pulses it violet)
    cg = W.Part("Coil", (0, 2.28, cz))
    W.cyl(cg, (0, 2.28, cz), 0.13, 0.3, "lamp_glass", segs=16, caps=False)
    cg.build()
    for i in range(3):
        W.cyl(p, (0.3, 2.05, -0.16 + i * 0.13), 0.018, 0.1, "mats_brass", segs=8)
        W.dot(p, (0.3, 2.11, -0.16 + i * 0.13), 0.026, "mats_red_paint", 8)
    for sx in (-0.44, 0.44):
        W.strut(p, (sx, 1.98, -hd + 0.16), (sx, 2.08, -hd + 0.12), 0.03, "mats_copper", True, 6)
    # Funki: hinged-lid hat, round eyes, one antenna, a lightning bolt held overhead
    m = (-0.3, 2.02, 0.13)
    W.lathe(p, [(0.07, 0.0), (0.07, 0.2)], "mats_tin", c=m, segs=14)
    W.cyl(p, add(m, (0, 0.21, 0)), 0.08, 0.025, "mats_chrome_worn", segs=14)
    for ex in (-0.035, 0.035):
        W.dot(p, add(m, (ex, 0.14, -0.07)), 0.02, "mats_cream", 8)
        W.dot(p, add(m, (ex, 0.14, -0.086)), 0.009, "mats_black_paint", 4)
    W.strut(p, add(m, (0, 0.23, 0)), add(m, (0.03, 0.34, 0)), 0.006, "lib_iron", True, 4)
    W.dot(p, add(m, (0.03, 0.345, 0)), 0.012, "mats_red_paint", 6)
    W.strut(p, add(m, (0.07, 0.12, 0)), add(m, (0.12, 0.27, 0)), 0.015, "lib_iron", True, 5)
    W.strut(p, add(m, (-0.07, 0.12, 0)), add(m, (-0.11, 0.05, 0)), 0.015, "lib_iron", True, 5)
    W.prism(p, [(0.0, 0.0), (0.05, 0.0), (0.02, 0.07), (0.06, 0.07), (-0.01, 0.2), (0.01, 0.1), (-0.03, 0.1)], -0.006, 0.006,
            "mats_yellow_paint", c=add(m, (0.1, 0.27, 0)))
    # the arc (shown for a flash every few seconds) from the coil's top turn to the ball
    arc = W.Part("Arc", (0, 2.43, cz))
    for pts2 in ([(0.16, -0.02, 0.0), (0.11, 0.03, 0.03), (0.13, 0.07, -0.02), (0.07, 0.1, 0.02), (0.09, 0.14, -0.01), (0.04, 0.17, 0.0)],
                 [(-0.15, -0.02, 0.03), (-0.1, 0.05, -0.02), (-0.11, 0.1, 0.02), (-0.05, 0.16, 0.0)]):
        W.tube(arc, [add((0, 2.43, cz), q) for q in pts2], 0.009, "neon_c07dff", 4)
    arc.build()


SHELLS = {"ironhide_stout": ironhide, "second_wind": second_wind, "trigger_tonic": trigger, "twin_barrel": twin_barrel,
          "marathon_malt": marathon, "hawkeye_brandy": hawkeye, "packmule_porter": packmule,
          "blastproof_bock": blastproof, "overclock_cordial": overclock}


def build(perk):
    shape, brand, gl, kind = PERKS[perk]
    fp = FP[shape]
    lay = layout(shape, fp)
    W.reset()
    body = W.Part("Body")
    neon = W.Part("Neon")
    back = W.Part("Backlight")
    SHELLS[perk](body, fp, lay, W.enamel(brand))
    common(perk, fp, lay, body, neon, back)
    body.build()
    neon.build()
    back.build()
    dispense(lay, perk)
    return W.export("perk_" + perk, "Helvetia tonic cabinet: %s" % perk,
                    "shape %s, bottle %s; footprint %s m (PerkMachine._shape_footprint)" % (shape, kind, fp), "perk_cabinets.py")


if __name__ == "__main__":
    want = W.args() or list(PERKS.keys())
    total = {}
    for pk in want:
        total[pk] = build(pk)
    print("[world] cabinets:", total)
