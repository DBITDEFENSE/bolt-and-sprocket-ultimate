#!/usr/bin/env python3
"""GRAVELIGHT: the Crossroads Inn's small sounds (Update 02 section 8, DECISIONS T-053).

Synthesizes the inn's room-by-room detail from scratch with gen_audio.py's DSP core: the fireplace crackle (a
seamless loop), the wind howling through a broken window (a seamless loop), the stable's timbers creaking, a horse
in the stalls (heard early, never seen), a bottle or glass breaking, an old door creaking on its hinges, a shot
knocking a hanging lantern. No samples or recordings. License: Owned.

Keys are merged into data/gravelight/audio.json like gen_audio.py does (existing per-key tuning is kept).
Run from the repo root:   python gravelight/tools_src/gen_audio_inn.py [key_prefix,...]
then reimport:             godot --headless --editor --quit-after 300 --path .
"""
from __future__ import annotations

import os
import sys

_argv = sys.argv[1:]
sys.argv = sys.argv[:1]                      # gen_audio reads its own ONLY filter from argv at import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import numpy as np                           # noqa: E402

A.ONLY = [a for a in _argv[0].split(",") if a] if _argv else []
N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, adsr, place, fit = A.expenv, A.attack, A.adsr, A.place, A.fit
smooth_rand, reverb, emit = A.smooth_rand, A.reverb, A.emit
SR = A.SR

ROOM = dict(bus="Ambience", attenuation="quiet")


def stick_slip(r, sec, rate_lo, rate_hi, modes, rough=1.0):
    """Wood or iron under load: stick-slip pulses at a wandering rate, rung through a few resonances."""
    rate = rate_lo + (rate_hi - rate_lo) * smooth_rand(r, sec, 2.5, 0, 1)
    stick = np.zeros(N(sec))
    idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
    stick[idx] = r.uniform(0.3, 1.0, len(idx)) * rough
    out = np.zeros(N(sec))
    for f, q, g in modes:
        out += g * reson(stick, f * r.uniform(0.93, 1.07), q)
    return out


def gen_fire():
    # the hearth: a soft roar of the draught up the chimney, wood ticking and popping, now and then a sap crack
    r = A.rng_for("fire_crackle")
    sec, xf = 12.0, 1.5
    total = sec + xf
    roar = lp(brown(r, total), 260, 2) * (0.7 + 0.3 * smooth_rand(r, total, 0.4, 0, 1))
    hiss = bp(pink(r, total), 1800, 6000) * (0.15 + 0.1 * smooth_rand(r, total, 1.1, 0, 1))
    ticks = A.crackle(r, total, 34, 1.0, 900, 7000)
    pops = np.zeros(N(total))
    for k in range(int(total * 0.9)):
        d = 0.05
        p = bp(white(r, d), 600, 4000) * expenv(N(d), r.uniform(0.004, 0.012))
        place(pops, nrm(p) * r.uniform(0.3, 1.0), r.uniform(0, total - d))
    for k in range(3):                     # a sap pocket bursting
        d = 0.15
        c = A.wood_crack(r, d, 4) * 0.6
        place(pops, c, r.uniform(0.5, total - 0.5))
    x = 0.55 * nrm(roar) + 0.5 * hiss + 0.35 * ticks + 0.5 * pops
    x = reverb(x, r, 0.6, 0.15, 5000, 0.008)
    emit("fire_crackle", "sfx/world/fire_crackle", A.loopify(x, xf), -6.0, loop=True, volume_db=-4.0, pitch=[1.0, 1.0],
         max_voices=2, **ROOM)


def gen_wind_howl():
    # wind through a broken pane and the gaps in the boards: a hollow, whistling moan that rises and falls
    r = A.rng_for("wind_howl")
    sec, xf = 14.0, 2.0
    total = sec + xf
    w = A.wind_bed(r, total, 1.0)[:, 0]
    gust = 0.3 + 0.7 * (0.5 + 0.5 * smooth_rand(r, total, 0.18)) ** 1.6
    moan_c = 380 + 260 * gust
    moan = A.sweep_noise(r, total, 300, 800, 16, 10, curve=moan_c) * gust ** 1.2
    whistle = A.sweep_noise(r, total, 1400, 2400, 22, 8, curve=1500 + 700 * gust) * np.clip(gust - 0.5, 0, 1) * 1.5
    x = 0.5 * nrm(hp(w, 180)) + 0.6 * moan + 0.18 * whistle
    emit("wind_howl", "sfx/ambience/wind_howl", A.loopify(x, xf), -6.0, loop=True, volume_db=-6.0, pitch=[1.0, 1.0],
         max_voices=4, bus="Ambience", attenuation="quiet")


def gen_stable():
    # the stable's old frame in the cold: long groaning creaks of beam on beam, a tick of nails, a dry rafter pop
    for i in A.variants(4):
        r = A.rng_for(f"stable_creak{i}")
        sec = r.uniform(1.2, 2.2)
        c = stick_slip(r, sec, 9, 28, [(r.uniform(160, 240), 6, 1.0), (r.uniform(420, 560), 9, 0.7), (r.uniform(900, 1200), 12, 0.35)])
        c = lp(c, 2600) * adsr(N(sec), 0.25, 0.0, 1.0, 0.4)
        x = np.zeros(N(sec + 0.6))
        place(x, c, 0.0)
        if r.random() < 0.6:
            place(x, A.mech_click(r, r.uniform(1800, 2600), 0.04, 0.004) * 0.3, r.uniform(0.1, sec))
        emit("stable_creak", f"sfx/ambience/stable_creak_{i:02d}", reverb(x, r, 1.6, 0.3, 3000, 0.02), -6.0, volume_db=-4.0,
             pitch=[0.9, 1.1], max_voices=2, bus="Ambience", attenuation="world")


def gen_horse():
    # a horse in the stalls: a whinny (a high voiced call that breaks and falls, with nasal buzz) and a snort
    for i in A.variants(2):
        r = A.rng_for(f"horse{i}")
        sec = 1.6
        f0 = r.uniform(520, 640)
        pc = A.pitch_curve(r, sec, f0, [(0.0, 0.8), (0.12, 1.25), (0.35, 1.1), (0.6, 0.85), (1.0, 0.55)], wobble=0.09)
        call = A.voice(r, sec, pc, ["i", "e", "a"], shift=1.6, breath=0.35, rasp=0.5, fry=0.25, drive=1.6)
        trill = 1.0 + 0.35 * np.sin(2 * np.pi * r.uniform(11, 15) * tax(N(sec)))   # the whinny's flutter
        call = call * trill * adsr(N(sec), 0.04, 0.2, 0.75, 0.35)
        snort = bp(white(r, 0.35), 300, 2500) * expenv(N(0.35), 0.08)
        x = np.zeros(N(sec + 1.4))
        place(x, call, 0.0)
        place(x, nrm(snort) * 0.5, sec + 0.3)
        emit("horse_whinny", f"sfx/ambience/horse_whinny_{i:02d}", reverb(lp(x, 5000), r, 1.4, 0.32, 3000, 0.02), -4.0,
             volume_db=-3.0, pitch=[0.95, 1.05], max_voices=1, bus="SFX", attenuation="world")


def gen_glass():
    # a bottle or a glass bursting: a bright crack, a ringing body, then the shards tinkling down
    for i in A.variants(4):
        r = A.rng_for(f"glass_break{i}")
        sec = 1.1
        x = np.zeros(N(sec))
        crack = hp(white(r, 0.03), 2500) * expenv(N(0.03), 0.004)
        place(x, nrm(crack), 0.0)
        t = tax(N(0.5))
        ring = np.zeros(N(0.5))
        for f in r.uniform(2400, 7000, 6):
            ring += np.sin(2 * np.pi * f * t + r.uniform(0, 6.28)) * np.exp(-t / r.uniform(0.04, 0.12))
        place(x, nrm(ring) * 0.5, 0.002)
        for k in range(r.integers(10, 20)):     # shards landing
            d = 0.03
            s = np.zeros(N(d))
            tt = tax(N(d))
            for f in r.uniform(3000, 9000, 3):
                s += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.008)
            place(x, nrm(s) * r.uniform(0.1, 0.45), 0.08 + r.uniform(0, 0.7) ** 1.5)
        place(x, A.thunk(r, 300, 0.01, 0.06) * 0.3, 0.0)
        emit("glass_break", f"sfx/world/glass_break_{i:02d}", reverb(x, r, 0.7, 0.18, 6000, 0.006), -2.0, volume_db=-2.0,
             pitch=[0.9, 1.12], max_voices=3, bus="SFX", attenuation="world")


def gen_door():
    # an old door on dry hinges: a rising, falling squeal of iron on iron, with the wood's knock at the end
    for i in A.variants(3):
        r = A.rng_for(f"door_creak{i}")
        sec = r.uniform(0.8, 1.4)
        c = stick_slip(r, sec, 40, 120, [(r.uniform(700, 900), 14, 1.0), (r.uniform(1500, 1900), 18, 0.6), (r.uniform(2600, 3200), 20, 0.3)])
        c = lp(c, 5000) * adsr(N(sec), 0.08, 0.0, 1.0, 0.25)
        x = np.zeros(N(sec + 0.4))
        place(x, c, 0.0)
        place(x, A.thunk(r, r.uniform(110, 150), 0.03, 0.2) * 0.25, sec - 0.05)
        emit("door_creak", f"sfx/world/door_creak_{i:02d}", reverb(x, r, 1.0, 0.22, 3500, 0.012), -4.0, volume_db=-3.0,
             pitch=[0.92, 1.08], max_voices=2, bus="SFX", attenuation="world")


def gen_lamp():
    # a bullet clipping a hanging lantern: a tinny knock and the chain's rattle
    for i in A.variants(3):
        r = A.rng_for(f"lamp_knock{i}")
        sec = 0.7
        x = np.zeros(N(sec))
        t = tax(N(0.3))
        knock = np.zeros(N(0.3))
        for f in r.uniform(900, 3200, 4):
            knock += np.sin(2 * np.pi * f * t) * np.exp(-t / r.uniform(0.02, 0.07))
        place(x, nrm(knock) * 0.8, 0.0)
        for k in range(r.integers(4, 8)):
            place(x, A.mech_click(r, r.uniform(2500, 5000), 0.03, 0.003) * r.uniform(0.15, 0.4), 0.03 + k * r.uniform(0.03, 0.07))
        emit("lamp_knock", f"sfx/world/lamp_knock_{i:02d}", reverb(x, r, 0.6, 0.15, 6000, 0.006), -4.0, volume_db=-4.0,
             pitch=[0.92, 1.08], max_voices=2, bus="SFX", attenuation="world")


def main():
    gen_fire()
    gen_wind_howl()
    gen_stable()
    gen_horse()
    gen_glass()
    gen_door()
    gen_lamp()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_inn: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
