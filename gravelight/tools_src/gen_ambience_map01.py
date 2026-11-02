#!/usr/bin/env python3
"""Kaltenbrunn's per-zone ambience (UPDATE 10 section 5, DECISIONS T-161): the ZoneAmbience beds, the zone one-shots
and the living-world one-shots (data/gravelight/ambience/map01.json, data/gravelight/map01_ambience.json).

Everything is synthesized with gen_audio's DSP (our own work, no third-party audio): wind, machinery hum, creaks,
drips, the siren, the avalanche's rumble, the cable creak, falling dust, chain clanks. Output is OGG Vorbis (ffmpeg,
libvorbis q4) under gravelight/audio/sfx/ambience/map01/; the keys are merged into data/gravelight/audio.json
(existing tuning for a key is kept; only "files" is refreshed). Reuses gen_ambience_map02's building blocks.

    <python with numpy+scipy> -I gravelight/tools_src/gen_ambience_map01.py      (needs ffmpeg on PATH)

Deterministic (every file has its own RNG from gen_audio's seed and its name).
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_ambience_map02 as g2   # noqa: E402  (also brings gen_audio as g2.ga)
import numpy as np                # noqa: E402

ga = g2.ga
g2.OUT_REL = "sfx/ambience/map01"
N = ga.N
SR = ga.SR
T = g2.TOTAL
KEYS = g2.KEYS


def siren(r) -> np.ndarray:
    """A mine siren winding up and down: 20 s, two rising-falling sweeps per cycle, harmonics, a rough drive, a tail."""
    sec = 20.0
    t = ga.tax(N(sec))
    cyc = 6.5
    f = 360 + 300 * (0.5 - 0.5 * np.cos(2 * np.pi * t / cyc)) ** 1.3
    f *= 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.55 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.18 * np.sin(5 * ph)
    y = np.tanh(2.4 * y)
    y = ga.reson(y, 900, 2) * 0.5 + y * 0.6
    env = ga.adsr(N(sec), 1.8, 0, 1, 3.0)
    return ga.reverb(ga.lp(y * env, 5200), r, 3.2, 0.35, 3500, 0.05)[:N(sec)]


def avalanche(r) -> np.ndarray:
    """A far slab letting go: a low rumble that swells over ~5 s, a hiss of sliding snow, the slow fade."""
    sec = 11.0
    n = N(sec)
    t = ga.tax(n)
    swell = np.clip(t / 4.0, 0, 1) ** 1.5 * np.exp(-np.clip(t - 5.0, 0, None) / 2.6)
    rumble = ga.lp(ga.brown(r, sec), 95, 2) * swell
    slide = ga.bp(ga.pink(r, sec), 250, 1400) * swell * 0.5 * (0.7 + 0.3 * ga.smooth_rand(r, sec, 2.5, 0, 1))
    crack = ga.crackle(r, sec, 14, 1.0, 120, 600) * swell * 0.4
    y = ga.nrm(rumble) * 0.9 + ga.nrm(slide) * 0.35 + ga.nrm(crack) * 0.2
    return ga.reverb(y, r, 4.0, 0.4, 1800, 0.08)[:n]


def dust_fall(r) -> np.ndarray:
    """Grit and pebbles pattering off a ceiling after a blast, a faint rumble under it."""
    sec = 3.2
    n = N(sec)
    env = ga.expenv(n, 0.9)
    y = ga.crackle(r, sec, 70, 1.0, 1200, 8000) * env * 0.5 + ga.lp(ga.brown(r, sec), 140, 2) * env * 0.6
    for k in range(int(r.integers(4, 8))):
        ga.place(y, ga.mech_click(r, r.uniform(900, 2400), 0.05, 0.003) * r.uniform(0.2, 0.6), r.uniform(0.1, 2.4))
    return ga.reverb(y, r, 1.4, 0.3, 3500, 0.02)[:n]


def chain_clank(r) -> np.ndarray:
    """A hoist chain swinging against a hook block: a run of metal taps that die away."""
    sec = 2.0
    out = np.zeros(N(sec))
    t = 0.0
    g = 1.0
    while t < sec - 0.4:
        ga.place(out, ga.reson(ga.mech_click(r, r.uniform(1400, 2600), 0.03, 0.002), r.uniform(900, 1800), 25) * g, t)
        ga.place(out, ga.reson(ga.thunk(r, 700, 0.01, 0.04), 1900, 30) * g * 0.5, t)
        t += r.uniform(0.07, 0.22)
        g *= 0.8
    return ga.reverb(out, r, 1.1, 0.3, 4000, 0.01)[:N(sec)]


def cable_creak(r, i: int) -> np.ndarray:
    return ga.reverb(g2.creak(r, 260 + 70 * i, 1.8, metal=True), r, 1.5, 0.3, 3000, 0.02)[:N(1.8)]


def build() -> None:
    wind = lambda r, k: ga.wind_bed(r, T, k)   # noqa: E731
    # A Minehead: the open yard, wind over the headframe's steel, a wire singing, a loose sheet of tin
    r = ga.rng_for("m1_minehead")
    x = wind(r, 1.1) * 0.9
    for k in range(5):
        g2.place_st(x, ga.pan(g2.creak(r, r.uniform(300, 520), r.uniform(0.7, 1.3), metal=True) * 0.05, r.uniform(-0.7, 0.7)), r.uniform(1, T - 2))
    g2.bed("ambient_map01_minehead", "minehead_bed", x)
    # B Rail yard: wind between the wagons, couplings groaning, ice ticking on the rails
    r = ga.rng_for("m1_railyard")
    x = wind(r, 0.9) * 0.8
    for k in range(int(T * 0.5)):
        g2.place_st(x, ga.pan(g2.tick(r, r.uniform(2200, 3800)) * r.uniform(0.03, 0.08), r.uniform(-0.8, 0.8)), r.uniform(0, T - 0.1))
    for k in range(3):
        g2.place_st(x, ga.pan(g2.groan(r, r.uniform(2.5, 4.0)) * 0.12, r.uniform(-0.6, 0.6)), r.uniform(2, T - 5))
    g2.bed("ambient_map01_railyard", "railyard_bed", x)
    # C Admin: a transformer's hum, the radio's carrier hiss, a wall clock, paper
    r = ga.rng_for("m1_admin")
    h = g2.hum(r, T, 50.0, [(1, 1.0), (2, 0.5), (3, 0.3), (6, 0.1)])
    hiss = ga.bp(ga.pink(r, T), 1500, 6000) * 0.5
    x = g2.stereo(0.09 * h + 0.025 * ga.nrm(hiss))
    k = 0.3
    while k < T - 0.3:
        g2.place_st(x, ga.pan(g2.tick(r, 3000) * 0.07, 0.4), k)
        k += 1.0
    x = ga.reverb(x, r, 0.8, 0.25, 4000, 0.01, stereo=True)[:N(T)]
    g2.bed("ambient_map01_admin", "admin_bed", x)
    # D Barracks: the stove ticking, wind behind the boards, bunk frames creaking
    r = ga.rng_for("m1_barracks")
    stove = ga.crackle(r, T, 6, 1.0, 500, 4000) * 0.35 + ga.lp(ga.brown(r, T), 180, 2) * 0.12
    x = g2.stereo(ga.nrm(stove) * 0.1) + wind(r, 0.5) * 0.25
    for k in range(4):
        g2.place_st(x, ga.pan(g2.creak(r, r.uniform(220, 380), r.uniform(0.6, 1.2)) * 0.06, r.uniform(-0.7, 0.7)), r.uniform(1, T - 2))
    x = ga.reverb(x, r, 1.0, 0.25, 3500, 0.012, stereo=True)[:N(T)]
    g2.bed("ambient_map01_barracks", "barracks_bed", x)
    # E Lift and M Stairs: the winch house's slow hum, a draught down the shaft, drips in the sump
    r = ga.rng_for("m1_lift")
    x = g2.stereo(0.1 * g2.hum(r, T, 42.0, [(1, 1.0), (2, 0.6), (4, 0.2)]) + 0.1 * ga.nrm(ga.lp(ga.brown(r, T), 160, 2)))
    x += wind(r, 0.35) * 0.18
    tc = 0.6
    while tc < T - 0.3:
        g2.place_st(x, ga.pan(g2.drip(r) * 0.16, r.uniform(-0.7, 0.7)), tc)
        tc += r.uniform(2.0, 3.6)
    x = ga.reverb(x, r, 2.0, 0.4, 3000, 0.02, stereo=True)[:N(T)]
    g2.bed("ambient_map01_lift", "lift_bed", x)
    r = ga.rng_for("m1_stairs")
    x = wind(r, 0.4) * 0.3 + g2.stereo(0.06 * ga.nrm(ga.lp(ga.brown(r, T), 130, 2)))
    for k in range(int(T * 0.3)):
        g2.place_st(x, ga.pan(g2.drip(r) * r.uniform(0.1, 0.25), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    x = ga.reverb(x, r, 2.4, 0.45, 2800, 0.03, stereo=True)[:N(T)]
    g2.bed("ambient_map01_stairs", "stairs_bed", x)
    # F Chapel: a huge quiet room, slow drips with a long tail, salt ticking as it settles
    r = ga.rng_for("m1_chapel")
    room = ga.bp(ga.pink(r, T), 50, 320) * (0.8 + 0.2 * ga.smooth_rand(r, T, 0.08, 0, 1))
    x = g2.stereo(0.2 * ga.nrm(room))
    ev = np.zeros((N(T), 2))
    for k in range(int(T * 0.35)):
        g2.place_st(ev, ga.pan(g2.drip(r) * r.uniform(0.15, 0.4), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    for k in range(int(T * 0.5)):
        g2.place_st(ev, ga.pan(g2.tick(r, r.uniform(3000, 5200)) * r.uniform(0.02, 0.06), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    x += ga.reverb(ev, r, 5.5, 0.65, 3200, 0.07, stereo=True)[:N(T)]
    g2.bed("ambient_map01_chapel", "chapel_bed", x)
    # G Generator hall: the turbines turning over, a rhythmic thump, the bearings, a relay chattering now and then
    r = ga.rng_for("m1_generator")
    pump = np.zeros(N(T))
    for k in range(int(T / 0.6)):
        ga.place(pump, ga.thunk(r, r.uniform(60, 78), 0.08, 0.3) * r.uniform(0.7, 1.0), k * 0.6)
    x = g2.stereo(0.13 * g2.hum(r, T, 50.0, [(1, 1.0), (2, 0.7), (3, 0.4), (4, 0.3), (6, 0.15)]) + 0.2 * ga.lp(pump, 300))
    x += g2.stereo(0.04 * ga.bp(ga.pink(r, T), 1800, 5000))
    x = ga.reverb(x, r, 1.9, 0.35, 3500, 0.02, stereo=True)[:N(T)]
    g2.bed("ambient_map01_generator", "generator_bed", x)
    # H Lab: lamp ballast buzz, a cold-room compressor, bubbling in the tanks
    r = ga.rng_for("m1_lab")
    buzz = g2.hum(r, T, 100.0, [(1, 1.0), (2, 0.4), (3, 0.5), (5, 0.2)])
    comp = g2.hum(r, T, 38.0, [(1, 1.0), (2, 0.5)]) * (0.6 + 0.4 * np.sin(2 * np.pi * ga.tax(N(T)) / 7.0) ** 2)
    bub = ga.crackle(r, T, 28, 1.0, 300, 1800) * 0.3
    x = g2.stereo(0.06 * buzz + 0.09 * comp + 0.12 * ga.nrm(bub))
    x = ga.reverb(x, r, 1.4, 0.3, 4200, 0.015, stereo=True)[:N(T)]
    g2.bed("ambient_map01_lab", "lab_bed", x)
    # I Vault: a deep drone, a thin high whine at the edge of hearing, stone ticking
    r = ga.rng_for("m1_core")
    x = g2.stereo(0.16 * g2.hum(r, T, 34.0, [(1, 1.0), (2, 0.5), (3, 0.3)]) + 0.04 * g2.hum(r, T, 1180.0, [(1, 1.0), (2, 0.2)]))
    x += g2.stereo(0.08 * ga.nrm(ga.lp(ga.brown(r, T), 90, 2)))
    for k in range(int(T * 0.3)):
        g2.place_st(x, ga.pan(g2.tick(r, r.uniform(1200, 2400)) * r.uniform(0.03, 0.08), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    x = ga.reverb(x, r, 3.8, 0.5, 2600, 0.04, stereo=True)[:N(T)]
    g2.bed("ambient_map01_core", "core_bed", x)
    # one-shots
    s = lambda name: ga.rng_for(name)   # noqa: E731
    g2.shots("amb_m1_siren", "siren", [siren(s("m1_siren"))], max_voices=1, attenuation="loud", volume_db=0.0)
    g2.shots("amb_m1_avalanche", "avalanche", [avalanche(s(f"m1_av{i}")) for i in range(1, 3)], max_voices=2)
    g2.shots("amb_m1_dust", "dust", [dust_fall(s(f"m1_dust{i}")) for i in range(1, 4)], max_voices=2)
    g2.shots("amb_m1_chain_clank", "chain_clank", [chain_clank(s(f"m1_chain{i}")) for i in range(1, 4)], max_voices=2, attenuation="world")
    g2.shots("amb_m1_cable_creak", "cable_creak", [cable_creak(s(f"m1_cc{i}"), i) for i in range(1, 4)], max_voices=1)
    g2.shots("amb_m1_gust_tin", "gust_tin", [ga.reverb(g2.creak(s(f"m1_tin{i}"), 540 + 60 * i, 1.0, metal=True), s(f"m1_tinr{i}"), 0.9, 0.3, 4000, 0.01)[:N(1.0)] for i in range(1, 3)], max_voices=1)


def merge_manifest() -> None:
    with open(ga.AUDIO_JSON, "r", encoding="utf-8") as f:
        d = json.load(f)
    sounds = d.setdefault("sounds", {})
    for k, v in KEYS.items():
        if k in sounds:
            sounds[k]["files"] = v["files"]
        else:
            sounds[k] = v
    d["sounds"] = {k: sounds[k] for k in sorted(sounds)}
    text = json.dumps(d, indent=2, ensure_ascii=False)   # the file's current format (2-space, arrays exploded)
    with open(ga.AUDIO_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")


def write_zone_config() -> None:
    def z(bed, db, shots):
        return {"bed": bed, "db": db, "oneshots": shots}
    cfg = {
        "_doc": "Kaltenbrunn's per-zone ambience (UPDATE 10 section 5, DECISIONS T-161; ZoneAmbience, gravelight/world/zone_ambience.gd). Beds and one-shots are AudioDirector keys in audio.json, synthesized by gravelight/tools_src/gen_ambience_map01.py (our own work); audio.json music.ambient map01_kaltenbrunn = ambient_map01 plays under all of them. The living-world one-shots (siren, avalanche, cable creak, dust, chains) are fired by MapAmbience from map01_ambience.json, not from here.",
        "crossfade_s": 1.5,
        "zones": {
            "A_MINEHEAD": z("ambient_map01_minehead", -6.0, [
                {"key": "amb_wind_gust", "every_s": [14, 30], "db": -9.0},
                {"key": "amb_m1_gust_tin", "every_s": [20, 45], "db": -14.0, "spatial": True}]),
            "B_RAILYARD": z("ambient_map01_railyard", -6.0, [
                {"key": "amb_wind_gust", "every_s": [12, 26], "db": -8.0},
                {"key": "amb_m1_gust_tin", "every_s": [16, 34], "db": -12.0, "spatial": True}]),
            "C_ADMIN": z("ambient_map01_admin", -9.0, [
                {"key": "amb_shutter_bang", "every_s": [30, 60], "db": -20.0, "spatial": True}]),
            "D_BARRACKS": z("ambient_map01_barracks", -8.0, [
                {"key": "door_creak", "every_s": [25, 55], "db": -20.0, "spatial": True},
                {"key": "amb_wind_gust", "every_s": [18, 40], "db": -16.0}]),
            "E_LIFT": z("ambient_map01_lift", -7.0, [
                {"key": "cellar_drip", "every_s": [5, 12], "db": -10.0, "spatial": True}]),
            "M_STAIRS": z("ambient_map01_stairs", -8.0, [
                {"key": "cellar_drip", "every_s": [4, 9], "db": -9.0, "spatial": True}]),
            "F_CHAPEL": z("ambient_map01_chapel", -6.0, [
                {"key": "cellar_drip", "every_s": [3, 8], "db": -6.0, "spatial": True}]),
            "G_GENERATOR": z("ambient_map01_generator", -6.0, [
                {"key": "cellar_drip", "every_s": [10, 22], "db": -14.0, "spatial": True}]),
            "H_LAB": z("ambient_map01_lab", -8.0, [
                {"key": "cellar_drip", "every_s": [12, 26], "db": -16.0, "spatial": True}]),
            "I_CORE": z("ambient_map01_core", -6.0, [
                {"key": "cellar_drip", "every_s": [6, 14], "db": -10.0, "spatial": True}]),
        },
    }
    path = os.path.join(ga.ROOT, "data", "gravelight", "ambience", "map01.json")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cfg, f, indent=1)
        f.write("\n")


def main() -> None:
    build()
    merge_manifest()
    write_zone_config()
    print(f"gen_ambience_map01: {len(KEYS)} keys -> data/gravelight/audio.json, zones -> data/gravelight/ambience/map01.json")


if __name__ == "__main__":
    main()
