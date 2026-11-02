#!/usr/bin/env python3
"""Totenhafen's per-zone ambience (UPDATE 09 section 5, DECISIONS T-145): the ZoneAmbience beds and one-shots.

Builds a looping bed per zone (data/gravelight/ambience/map02.json) plus a map-wide storm bed (audio.json
music.ambient map02_totenhafen) and the one-shots, from two CC0 recordings filed under assets/third_party/opengameart/
(the surf: "Beach Ocean Waves" by jasinski; the dock water: "Sea and River Wave Sounds" by RandomMind) layered with
parts synthesized with gen_audio.py's DSP (wind, machinery hum, creaks, drips, gulls, the teletype). Output is OGG
Vorbis (ffmpeg, libvorbis q4) under gravelight/audio/sfx/ambience/map02/; the keys are merged into
data/gravelight/audio.json (existing tuning for a key is kept; only "files" is refreshed).

    <python with numpy+scipy> -I gravelight/tools_src/gen_ambience_map02.py
        (reads assets/third_party/opengameart/beach-ocean-waves/*.flac and
         assets/third_party/opengameart/sea-and-river-wave-sounds/*.ogg; needs ffmpeg on PATH)

Deterministic (every file has its own RNG from gen_audio's seed and its name). The recordings are untrusted input:
ffmpeg only decodes them to raw PCM in a temp folder, nothing in them is executed.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0]]          # gen_audio reads argv[1] as a key filter at import
sys.path.insert(0, HERE)
import gen_audio as ga            # noqa: E402  (the DSP core: noise, filters, reverb, loopify, write_wav)
import numpy as np                # noqa: E402

ROOT = ga.ROOT
OUT_REL = "sfx/ambience/map02"
SURF_DIR = os.path.join(ROOT, "assets", "third_party", "opengameart", "beach-ocean-waves")
RIVER_DIR = os.path.join(ROOT, "assets", "third_party", "opengameart", "sea-and-river-wave-sounds")
SR = ga.SR
LOOP = 40.0
XF = 3.0
TOTAL = LOOP + XF
KEYS: dict[str, dict] = {}
N = ga.N


def decode(path: str) -> np.ndarray:
    """Any audio file -> float stereo at 44.1 kHz through ffmpeg (raw s16le to stdout)."""
    out = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(out, dtype="<i2").astype(float).reshape(-1, 2) / 32768.0


def write_ogg(rel: str, x: np.ndarray, peak_db: float) -> str:
    x = np.nan_to_num(np.asarray(x, dtype=float))
    x = x - np.mean(x, axis=0)
    x = ga.nrm(x, 10 ** (peak_db / 20.0))
    dst = os.path.join(ga.GL, "audio", rel + ".ogg")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "x.wav")
        ga.write_wav(wav, x)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    return "res://gravelight/audio/" + rel + ".ogg"


def bed(key: str, name: str, x: np.ndarray, **meta) -> None:
    res = write_ogg(f"{OUT_REL}/{name}", ga.loopify(x, XF), -5.0)
    KEYS[key] = dict({"files": [res], "bus": "Ambience", "volume_db": 0.0, "pitch": [1.0, 1.0], "max_voices": 2, "loop": True}, **meta)
    print(f"  bed {key}: {LOOP:.0f} s")


def shots(key: str, name: str, xs: list, **meta) -> None:
    files = []
    for i, x in enumerate(xs, 1):
        files.append(write_ogg(f"{OUT_REL}/{name}_{i:02d}", ga.fade(np.asarray(x, dtype=float), 0.002, 0.05), -3.0))
    KEYS[key] = dict({"files": files, "bus": "Ambience", "volume_db": 0.0, "max_voices": 3, "attenuation": "quiet"}, **meta)
    print(f"  one-shot {key}: {len(xs)} variants")


def stereo(x: np.ndarray) -> np.ndarray:
    return ga.to_stereo(x) if x.ndim == 1 else x


def place_st(dst: np.ndarray, src: np.ndarray, t0: float, gain: float = 1.0) -> None:
    ga.place_wrap(dst, stereo(src), t0, gain)


# ═════════════════════════════════════════════════════════════════ building blocks

def surf_layer(r, waves: list, sec: float, every: tuple, gain: float, lp_hz: float) -> np.ndarray:
    """Recorded wave crashes laid end to end at random spacing and pans, low-passed for distance."""
    out = np.zeros((N(sec), 2))
    t = r.uniform(0, every[0])
    while t < sec:
        w = waves[int(r.integers(len(waves)))]
        rate = r.uniform(0.85, 1.05)
        ww = ga.varispeed(w, np.full(int(len(w) / rate), rate))
        p = r.uniform(-0.7, 0.7)
        ww = ww * np.array([1.0 - max(0.0, p), 1.0 + min(0.0, p)])
        place_st(out, ww, t, r.uniform(0.6, 1.0))
        t += r.uniform(every[0], every[1])
    return ga.lp(out, lp_hz, 2) * gain


def river_loop(river: np.ndarray, r, sec: float, start: float) -> np.ndarray:
    s0 = int(start * SR) % max(1, len(river) - N(sec))
    seg = river[s0:s0 + N(sec)]
    if len(seg) < N(sec):
        seg = np.concatenate([seg, np.zeros((N(sec) - len(seg), 2))])
    return seg


def creak(r, f: float = 600.0, sec: float = 0.9, metal: bool = False) -> np.ndarray:
    """Stick-slip creak (gen_audio's shutter creak): impulses at a gliding rate through resonances."""
    rate = 30 + 40 * ga.smooth_rand(r, sec, 3, 0, 1)
    stick = np.zeros(N(sec))
    idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
    stick[idx] = r.uniform(0.4, 1.0, len(idx))
    if metal:
        y = ga.reson(stick, f, 22) + 0.7 * ga.reson(stick, f * 2.76, 30) + 0.4 * ga.reson(stick, f * 5.4, 40)
    else:
        y = ga.reson(stick, f, 7) + 0.6 * ga.reson(stick, f * 2.3, 9)
    return ga.lp(y, 4000) * ga.adsr(N(sec), 0.12, 0, 1, 0.35)


def drip(r) -> np.ndarray:
    d = 0.06
    f0 = r.uniform(900, 1800)
    return np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f0 * 2.3, N(d))) / SR) * ga.expenv(N(d), 0.012)


def hum(r, sec: float, base: float, harm: list) -> np.ndarray:
    t = ga.tax(N(sec))
    y = sum(a * np.sin(2 * np.pi * base * h * t + r.uniform(0, 6)) for h, a in harm)
    return y * (0.85 + 0.15 * ga.smooth_rand(r, sec, 0.2, 0, 1))


def tick(r, f: float = 2500.0) -> np.ndarray:
    return ga.mech_click(r, f, 0.05, 0.003)


def gull(r) -> np.ndarray:
    """A herring gull's 'kyow': a harmonic chirp that leaps up and sags, nasal formants, repeated 2-4 times."""
    calls = int(r.integers(2, 5))
    out = np.zeros(N(0.4 * calls + 0.6))
    for k in range(calls):
        d = r.uniform(0.22, 0.34)
        n = N(d)
        x = np.linspace(0, 1, n)
        f = 1100 + 1500 * np.sin(np.pi * np.clip(x * 1.3, 0, 1)) ** 0.7 - 500 * x
        f *= 1 + 0.02 * np.sin(2 * np.pi * 28 * x * d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        y = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.2 * np.sin(4 * ph)
        y = ga.reson(y, 2600, 3) + 0.5 * ga.reson(y, 4200, 4) + 0.3 * y
        y *= ga.adsr(n, 0.02, 0.05, 0.8, 0.12)
        ga.place(out, y, 0.05 + k * r.uniform(0.32, 0.42))
    return ga.reverb(ga.hp(out, 600), r, 1.4, 0.25, 6000, 0.02)[:len(out)]


def teletype(r, sec: float) -> np.ndarray:
    """A burst of typing: a mechanical clatter at ~10 characters a second, the carriage clunk at the end."""
    out = np.zeros(N(sec + 0.5))
    t = 0.05
    while t < sec:
        c = ga.mech_click(r, r.uniform(1800, 3200), 0.05, 0.004) + 0.5 * ga.thunk(r, r.uniform(160, 260), 0.012, 0.05)
        ga.place(out, c * r.uniform(0.6, 1.0), t)
        t += r.uniform(0.07, 0.12) + (0.25 if r.random() < 0.08 else 0.0)
    ga.place(out, ga.thunk(r, 120, 0.05, 0.25) + 0.6 * ga.mech_click(r, 900, 0.25, 0.02), sec)
    return ga.reverb(out, r, 0.5, 0.15, 5000, 0.006)[:len(out)]


def weld(r, sec: float) -> np.ndarray:
    """An arc welder's frying crackle: dense band-passed crackle with a 100 Hz buzz under it."""
    cr = ga.crackle(r, sec, 260, 1.0, 1500, 9000) + 0.6 * ga.crackle(r, sec, 60, 1.0, 600, 4000)
    buzz = ga.bp(ga.square(100.0, sec), 100, 900) * 0.15
    env = ga.adsr(N(sec), 0.03, 0.1, 0.85, 0.15) * (0.75 + 0.25 * ga.smooth_rand(r, sec, 4, 0, 1))
    return (cr + buzz) * env


def paper_flap(r) -> np.ndarray:
    sec = r.uniform(0.5, 0.9)
    y = ga.bp(ga.white(r, sec), 900, 6000)
    flaps = (0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(9, 14) * ga.tax(N(sec)))) ** 3
    return y * flaps * ga.adsr(N(sec), 0.05, 0.1, 0.7, 0.2)


def groan(r, sec: float) -> np.ndarray:
    """The steel curtain moving in its tracks: a slow metallic stick-slip groan, low and long."""
    y = creak(r, r.uniform(120, 180), sec, metal=True)
    rumble = ga.lp(ga.brown(r, sec), 90, 2) * ga.adsr(N(sec), 0.4, 0, 1, 0.8)
    return ga.reverb(ga.nrm(y) * 0.7 + 0.5 * ga.nrm(rumble), r, 3.5, 0.5, 2500, 0.04)[:N(sec)]


def thunder(r, sec: float) -> np.ndarray:
    roll = ga.lp(ga.brown(r, sec), 160, 2) * ga.expenv(N(sec), sec * 0.35) * (0.5 + 0.5 * ga.smooth_rand(r, sec, 3, 0, 1))
    crack = ga.lp(ga.white(r, sec), 2200, 2) * ga.expenv(N(sec), 0.12) * 0.4
    return ga.reverb(roll + crack, r, 3.0, 0.4, 1800, 0.05)[:N(sec)]


# ═════════════════════════════════════════════════════════════════ the beds

def build(waves: list, river: np.ndarray) -> None:
    T = TOTAL
    # map-wide: the storm beyond the concrete, the sea booming on the cliff (quiet, under every zone bed)
    r = ga.rng_for("m2_storm")
    x = ga.wind_bed(r, T, 0.5) + surf_layer(r, waves, T, (3.0, 6.0), 0.9, 500)
    x += stereo(ga.nrm(ga.lp(ga.brown(r, T), 110, 2))) * 0.35
    place_st(x, thunder(r, 6.0), r.uniform(5, 30), 0.5)
    bed("ambient_map02_storm", "storm_bed", ga.lp(x, 2400, 2))
    # A Quay: surf on the shingle and the stage steps, the wind, the halyard slapping the hut's pole, rope creak
    r = ga.rng_for("m2_quay")
    x = ga.wind_bed(r, T, 1.0) * 0.8 + surf_layer(r, waves, T, (2.2, 4.5), 1.4, 6000)
    hal = np.zeros(N(T))
    t = r.uniform(0.3, 1.5)
    while t < T - 0.5:
        for k in range(int(r.integers(2, 5))):
            ga.place(hal, ga.mech_click(r, r.uniform(1700, 2600), 0.08, 0.01) + 0.4 * ga.thunk(r, 300, 0.02, 0.08), t + k * r.uniform(0.15, 0.3), r.uniform(0.4, 1.0))
        t += r.uniform(2.5, 6.0)
    x += ga.pan(ga.reverb(hal, r, 0.8, 0.2, 6000, 0.01)[:N(T)] * 0.12, 0.3)
    for k in range(4):
        place_st(x, ga.pan(creak(r, r.uniform(380, 520), r.uniform(0.6, 1.0)) * 0.05, r.uniform(-0.6, 0.6)), r.uniform(1, T - 2))
    bed("ambient_map02_quay", "quay_bed", x)
    # B Cannery: the line's machinery hum and belt rattle, the stove ticking and crackling, a tap dripping
    r = ga.rng_for("m2_cannery")
    t = ga.tax(N(T))
    m = hum(r, T, 50.0, [(1, 1.0), (2, 0.55), (3, 0.3), (4, 0.25), (6, 0.12)]) * (0.75 + 0.25 * np.sin(2 * np.pi * t / 5.0) ** 2)
    belt = np.zeros(N(T))
    for k in range(int(T * 3.4)):
        ga.place(belt, tick(r, r.uniform(1200, 1800)) * r.uniform(0.3, 0.6), k / 3.4 + r.uniform(0, 0.02))
    stove = ga.crackle(r, T, 5, 1.0, 500, 4000) * 0.35 + ga.lp(ga.brown(r, T), 200, 2) * 0.1
    x = stereo(0.1 * m + 0.05 * ga.lp(belt, 3500)) + ga.pan(ga.nrm(stove) * 0.08, -0.5)
    tc = 0.4
    while tc < T - 0.2:
        place_st(x, ga.pan(drip(r) * 0.18, 0.6), tc)
        tc += r.uniform(1.6, 2.3)
    x = ga.reverb(x, r, 1.6, 0.3, 4000, 0.02, stereo=True)[:N(T)]
    bed("ambient_map02_cannery", "cannery_bed", x)
    # C Workshop: compressed-air hiss, cooling pipes ticking, a welder's arc frying now and then, room tone
    r = ga.rng_for("m2_workshop")
    hiss = ga.bp(ga.pink(r, T), 2500, 7000) * (0.6 + 0.4 * ga.smooth_rand(r, T, 0.15, 0, 1))
    x = stereo(0.06 * ga.nrm(hiss) + 0.12 * ga.nrm(ga.lp(ga.brown(r, T), 140, 2)))
    for k in range(int(T * 1.2)):
        place_st(x, ga.pan(tick(r, r.uniform(2200, 4200)) * r.uniform(0.04, 0.12), r.uniform(-0.8, 0.8)), r.uniform(0, T - 0.1))
    tw = r.uniform(3, 8)
    while tw < T - 4:
        place_st(x, ga.pan(weld(r, r.uniform(1.0, 2.6)) * 0.09, r.uniform(-0.5, 0.5)), tw)
        tw += r.uniform(9, 16)
    x = ga.reverb(x, r, 1.8, 0.35, 4500, 0.02, stereo=True)[:N(T)]
    bed("ambient_map02_workshop", "workshop_bed", x)
    # D Pen Hall: the pens' huge room tone, the docks' water slapping the piers, drips with a long tail, the
    # curtain groaning far off, the storm through the mouth
    r = ga.rng_for("m2_penhall")
    room = ga.bp(ga.pink(r, T), 60, 420) * (0.8 + 0.2 * ga.smooth_rand(r, T, 0.08, 0, 1))
    water = ga.bp(river_loop(river, r, T, 7.0), 120, 2200) * 1.2
    x = stereo(0.25 * ga.nrm(room)) + 0.5 * water + surf_layer(r, waves, T, (4.0, 7.0), 0.5, 900)
    ev = np.zeros((N(T), 2))
    for k in range(int(T * 0.7)):
        place_st(ev, ga.pan(drip(r) * r.uniform(0.1, 0.35), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    place_st(ev, groan(r, 4.5) * 0.35, r.uniform(8, 28))
    x += ga.reverb(ev, r, 4.5, 0.6, 3000, 0.06, stereo=True)[:N(T)]
    bed("ambient_map02_penhall", "penhall_bed", x)
    # E U-boat: the battle lanterns' transformer hum, the hull creaking against the fenders, pipes ticking, the
    # dock's water muffled through the steel
    r = ga.rng_for("m2_uboat")
    h = hum(r, T, 100.0, [(1, 1.0), (2, 0.4), (3, 0.25), (5, 0.1)])
    x = stereo(0.07 * h) + 0.3 * ga.lp(river_loop(river, r, T, 40.0), 350, 2)
    for k in range(7):
        place_st(x, ga.pan(creak(r, r.uniform(160, 300), r.uniform(0.8, 1.6), metal=True) * 0.07, r.uniform(-0.7, 0.7)), r.uniform(1, T - 2))
    for k in range(int(T * 0.8)):
        place_st(x, ga.pan(tick(r, r.uniform(1500, 3000)) * r.uniform(0.03, 0.08), r.uniform(-0.8, 0.8)), r.uniform(0, T - 0.1))
    x = ga.reverb(x, r, 0.7, 0.3, 3500, 0.008, stereo=True)[:N(T)]
    bed("ambient_map02_uboat", "uboat_bed", x)
    # F Lower pens: the tide pumps idling (a slow thump and a motor), water lapping at the deck, drips
    r = ga.rng_for("m2_pens")
    pump = np.zeros(N(T))
    for k in range(int(T / 0.85)):
        ga.place(pump, ga.thunk(r, r.uniform(55, 70), 0.09, 0.4) * r.uniform(0.7, 1.0), k * 0.85)
    motor = hum(r, T, 47.0, [(1, 1.0), (2, 0.6), (4, 0.2)])
    lap = ga.bp(river_loop(river, r, T, 70.0), 150, 3000)
    x = stereo(0.25 * ga.lp(pump, 300) + 0.06 * motor) + 0.75 * lap
    for k in range(int(T * 0.5)):
        place_st(x, ga.pan(drip(r) * r.uniform(0.1, 0.3), r.uniform(-0.9, 0.9)), r.uniform(0, T - 0.1))
    x = ga.reverb(x, r, 2.4, 0.45, 3000, 0.03, stereo=True)[:N(T)]
    bed("ambient_map02_pens", "pens_bed", x)
    # G Signal tower: wind at height whistling in the window frames, the rack's valve hum, rain on the glass
    r = ga.rng_for("m2_tower")
    x = ga.wind_bed(r, T, 1.2)
    rain = ga.crackle(r, T, 90, 1.0, 2500, 9000) * 0.18
    x += stereo(0.03 * hum(r, T, 60.0, [(1, 1.0), (2, 0.5), (3, 0.2)]) + rain)
    bed("ambient_map02_tower", "tower_bed", x)
    # one-shots
    shots("amb_m2_gull", "gull", [gull(ga.rng_for(f"m2_gull{i}")) for i in range(1, 5)], max_voices=2)
    shots("amb_m2_wave", "wave", [ga.lp(w, 7000) for w in waves], max_voices=2)
    shots("amb_m2_groan", "curtain_groan", [groan(ga.rng_for(f"m2_groan{i}"), 4.0 + i) for i in range(1, 3)], max_voices=1)
    shots("amb_m2_hull_creak", "hull_creak", [ga.reverb(creak(ga.rng_for(f"m2_hc{i}"), 140 + 40 * i, 1.4, metal=True), ga.rng_for(f"m2_hcr{i}"), 0.8, 0.3, 3000, 0.01)[:N(1.4)] for i in range(1, 4)], max_voices=1)
    shots("amb_m2_weld", "weld", [weld(ga.rng_for(f"m2_weld{i}"), 1.4 + 0.6 * i) for i in range(1, 3)], max_voices=1)
    shots("amb_m2_teletype", "teletype", [teletype(ga.rng_for(f"m2_tty{i}"), 2.0 + i) for i in range(1, 3)], max_voices=1)
    shots("amb_m2_paper", "paper_flap", [paper_flap(ga.rng_for(f"m2_paper{i}")) for i in range(1, 3)], max_voices=1)
    shots("amb_m2_thunder", "thunder", [thunder(ga.rng_for(f"m2_thunder{i}"), 6.0) for i in range(1, 3)], max_voices=1)


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
    amb = d.setdefault("music", {}).setdefault("ambient", {})
    amb["map02_totenhafen"] = "ambient_map02_storm"
    text = json.dumps(d, indent=1)   # gen_audio.write_manifest's format, so the two tools produce the same file
    text = re.sub(r"\[\s+([-\d.,\s]+|\d+,\s+\"[a-z0-9_]+\")\s+\]",
                  lambda m: "[" + ", ".join(v.strip() for v in m.group(1).split(",")) + "]", text)
    with open(ga.AUDIO_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")


def main() -> None:
    waves = [decode(os.path.join(SURF_DIR, n)) for n in sorted(os.listdir(SURF_DIR)) if n.endswith(".flac")]
    rivers = [n for n in sorted(os.listdir(RIVER_DIR)) if n.endswith((".ogg", ".mp3", ".wav"))]
    if not waves or not rivers:
        sys.exit("gen_ambience_map02: the CC0 recordings are missing under assets/third_party/opengameart/")
    river = decode(os.path.join(RIVER_DIR, rivers[0]))
    print(f"gen_ambience_map02: {len(waves)} wave crashes, {len(river) / SR:.0f} s of dock water")
    build(waves, river)
    merge_manifest()
    print(f"gen_ambience_map02: {len(KEYS)} keys -> data/gravelight/audio.json")


if __name__ == "__main__":
    main()
