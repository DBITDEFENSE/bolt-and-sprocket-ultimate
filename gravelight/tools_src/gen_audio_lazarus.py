#!/usr/bin/env python3
"""GRAVELIGHT UPDATE 11 'LAZARUS' (DECISIONS T-194): the new sounds of the four LAZARUS cutscenes, the ones the shot
lists (docs/CUTSCENES_LAZARUS.md) mark with *. Synthesized from scratch with gen_audio.py's DSP core, like T-052's war
sounds: no samples, no recordings. License: Owned (our own work).

  amb_thaw        1930's bed: the thaw itself (dripping, rooks, a dog far off, wet air)          loop
  truck_1930      the brigade's truck: a four-cylinder on a loose body, coming up the road, stopping
  bell_crack      the bell hitting the ground: a toll that ends in a split, then nothing
  timber_fall     the bell tower going down: timbers groaning, breaking, the fall
  rain_field      rain on canvas and mud (East Prussia, October 1944)                          loop
  shell_soft      the special rounds: a thud and a soft, wrong burst, no explosion
  mill_bed        Staubmühle II: a ball mill turning, a fan, a Geiger-like tick (the resonance)   loop
  rocket_salvo    six whumps and a tearing (the canisters going east)
  c47_engines     two radials in sync, from inside the cabin                                      loop
  prop_windmill   the engines dead: the props windmilling in the airstream                       loop

The chant bed and the Russian whispers are the horror pass's (T-192); the cutscenes play them when they exist.
Run from the repo root:   python gravelight/tools_src/gen_audio_lazarus.py [key_prefix,...]
then reimport:             godot --headless --editor --quit-after 300 --path .
"""
from __future__ import annotations

import os
import sys

_argv = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import numpy as np                           # noqa: E402

A.ONLY = [a for a in _argv[0].split(",") if a] if _argv else []
N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, adsr, place, fit = A.expenv, A.attack, A.adsr, A.place, A.fit
smooth_rand, reverb, echo, emit = A.smooth_rand, A.reverb, A.echo, A.emit
SR = A.SR

FAR = dict(bus="SFX", attenuation="loud")
BED = dict(bus="Ambience", volume_db=0.0, pitch=[1.0, 1.0], max_voices=2)


def drip(r):
    sec = 0.25
    t = tax(N(sec))
    f = r.uniform(900, 2400) * (1.0 + 0.5 * np.exp(-t / 0.01))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / r.uniform(0.02, 0.05)) * r.uniform(0.3, 1.0)


def caw(r, f0, sec):
    pc = A.pitch_curve(r, sec, f0, [(0.0, 0.92), (0.25, 1.05), (1.0, 0.82)], wobble=0.03, vib_depth=0.01)
    v = A.voice(r, sec, pc, ["ae", "a", "ah"], shift=1.25, breath=0.35, rasp=0.9, fry=0.45, drive=2.6)
    return v * adsr(N(sec), 0.015, 0.05, 0.85, 0.06)


def engines(r, sec, base, count, harm=9, detune=0.004, rough=0.3):
    t = tax(N(sec))
    out = np.zeros(N(sec))
    for k in range(count):
        f = base * (1.0 + r.uniform(-detune, detune))
        wob = 1.0 + 0.003 * smooth_rand(r, sec, 0.4)
        ph = 2 * np.pi * np.cumsum(np.full(N(sec), f) * wob) / SR
        for h in range(1, harm + 1):
            out += np.sin(h * ph + r.uniform(0, 6.28)) / (h ** 0.85) * (1.0 if h % 2 else 0.75)
    out = nrm(out) + rough * nrm(lp(brown(r, sec), 200, 2))
    return out


def gen_1930():
    r = A.rng_for("amb_thaw")
    sec, xf = 22.0, 2.0
    n = N(sec + xf)
    air = nrm(lp(pink(r, sec + xf), 1400, 2)) * (0.22 + 0.1 * smooth_rand(r, sec + xf, 0.2, 0, 1))
    x = air.copy()
    for k in range(int((sec + xf) * 4.5)):   # the thaw dripping off every eave
        place(x, drip(r) * 0.35, r.uniform(0.0, sec + xf - 0.3))
    for k in range(5):                        # rooks
        at = r.uniform(0.5, sec + xf - 2.0)
        for j in range(int(r.integers(1, 4))):
            d = r.uniform(0.22, 0.38)
            place(x, lp(caw(r, r.uniform(430, 560), d), 3000) * 0.28, at)
            at += d + r.uniform(0.1, 0.3)
    for k in range(2):                        # a dog far off
        d = 0.18
        pc = A.pitch_curve(r, d, r.uniform(330, 400), [(0.0, 1.0), (0.3, 1.12), (1.0, 0.72)], wobble=0.02)
        b = A.voice(r, d, pc, ["a", "o"], shift=0.95, breath=0.3, rasp=0.55, fry=0.2, drive=2.2) * adsr(N(d), 0.008, 0.05, 0.8, 0.05)
        place(x, lp(b, 1600) * 0.16, r.uniform(2.0, sec))
    x = reverb(x, r, 1.6, 0.3, 4000, 0.02)[:n]
    emit("amb_thaw", "sfx/cinema/amb_thaw", A.loopify(x, xf), -6.0, loop=True, **BED)
    # the truck: a four-cylinder engine on a loose body, coming up the road, then cut
    r = A.rng_for("truck_1930")
    sec = 9.0
    t = tax(N(sec))
    rpm = np.interp(t, [0, 6.8, 7.4, 9.0], [1.0, 0.9, 0.55, 0.0])
    e = engines(r, sec, 21.0, 1, 10, 0.0, 0.5) * np.clip(rpm * 1.4, 0, 1)
    rattle = np.zeros(N(sec))
    for k in range(70):
        tk = r.uniform(0.0, 7.2)
        place(rattle, A.mech_click(r, r.uniform(500, 1400), 0.05, 0.004) * r.uniform(0.2, 0.6), tk)
    y = lp(e, 1800) + 0.35 * rattle
    y *= np.interp(t, [0, 5.0, 7.0, 7.5, 9.0], [0.35, 0.9, 1.0, 0.4, 0.0])
    emit("truck_1930", "sfx/cinema/truck_1930", fit(reverb(y, r, 1.2, 0.2, 3000), sec), -3.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    # the bell hitting the ground: one dead note that ends in a split
    r = A.rng_for("bell_crack")
    sec = 3.0
    b = A.bell(r, 196.0, sec, decay=0.5, strike=0.9, bright=0.8)
    t = tax(N(sec))
    b *= np.where(t < 0.18, 1.0, np.exp(-(t - 0.18) / 0.09))
    split = bp(white(r, sec), 900, 4200) * np.exp(-np.maximum(0, t - 0.16) / 0.05) * (t > 0.16) * 0.8
    thud = A.kick(r, 1.0, 90, 40, 0.15, sec) * 0.8
    emit("bell_crack", "sfx/cinema/bell_crack", fit(reverb(b + split + thud, r, 1.4, 0.25, 3000), sec), -1.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    # the tower going down: groans, breaks, the long fall, the dust
    r = A.rng_for("timber_fall")
    sec = 7.0
    x = np.zeros(N(sec))
    for k in range(5):
        place(x, A.wood_crack(r, 0.7, 9) * r.uniform(0.5, 1.0), 0.2 + k * r.uniform(0.25, 0.5))
    groan = reson(lp(brown(r, 2.5), 300, 2), 70, 6) * adsr(N(2.5), 0.4, 0.3, 0.7, 0.8)
    place(x, nrm(groan) * 0.6, 0.0)
    for k in range(8):
        place(x, A.thunk(r, r.uniform(80, 160), 0.08, 0.4) * r.uniform(0.5, 1.0), 2.4 + k * r.uniform(0.12, 0.3))
    rumble = nrm(lp(brown(r, 4.0), 120, 2)) * adsr(N(4.0), 0.1, 0.5, 0.5, 2.5)
    place(x, rumble * 0.9, 2.6)
    emit("timber_fall", "sfx/cinema/timber_fall", fit(reverb(x, r, 2.6, 0.45, 1800, 0.03), sec), -1.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)


def gen_1944():
    r = A.rng_for("rain_field")
    sec, xf = 16.0, 2.0
    n = N(sec + xf)
    hiss = nrm(bp(pink(r, sec + xf), 400, 7000)) * 0.4
    patter = np.zeros(n)
    for k in range(int((sec + xf) * 60)):
        sz = r.uniform(0.004, 0.012)
        hit = bp(white(r, 0.05), 1500, 6000) * expenv(N(0.05), sz)
        place(patter, hit * r.uniform(0.05, 0.25), r.uniform(0, sec + xf - 0.06))
    canvas = reson(patter, 380, 3) * 0.4
    x = hiss + patter + canvas + 0.2 * nrm(lp(brown(r, sec + xf), 150, 2))
    emit("rain_field", "sfx/cinema/rain_field", A.loopify(x, xf), -6.0, loop=True, **BED)
    for i in A.variants(3):   # the special rounds: a thud in the mud and a soft cough of dust, nothing more
        r = A.rng_for(f"shell_soft{i}")
        sec = 3.0
        t = tax(N(sec))
        thud = A.kick(r, 1.0, r.uniform(70, 95), 38, 0.18, sec)
        cough = bp(white(r, sec), 200, 1400) * attack(N(sec), 0.05) * np.exp(-t / 0.5) * 0.45
        x = thud + cough
        emit("shell_soft", f"sfx/cinema/shell_soft_{i:02d}", fit(reverb(lp(x, 2400), r, 2.4, 0.5, 1600, 0.04), sec), -3.0, volume_db=0.0,
             pitch=[0.94, 1.06], max_voices=3, **FAR)


def gen_staub():
    r = A.rng_for("mill_bed")
    sec, xf = 16.0, 2.0
    n = N(sec + xf)
    t = tax(n)
    tumble = nrm(lp(brown(r, sec + xf), 260, 2)) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 0.45 * t)))
    balls = np.zeros(n)
    for k in range(int((sec + xf) * 14)):
        place(balls, A.thunk(r, r.uniform(140, 320), 0.02, 0.08) * r.uniform(0.1, 0.35), r.uniform(0, sec + xf - 0.1))
    fan = sum(np.sin(2 * np.pi * 100.0 * h * t + h) / h for h in range(1, 6)) * 0.12
    ticks = np.zeros(n)
    for k in range(int((sec + xf) * 9)):
        place(ticks, A.mech_click(r, r.uniform(2500, 3600), 0.02, 0.0015) * 0.3, r.uniform(0, sec + xf - 0.05))
    x = tumble * 0.6 + lp(balls, 2500) + fan + ticks
    emit("mill_bed", "sfx/cinema/mill_bed", A.loopify(reverb(x, r, 1.4, 0.3, 3000), xf), -6.0, loop=True, **BED)
    r = A.rng_for("rocket_salvo")
    sec = 7.0
    x = np.zeros(N(sec))
    for k in range(6):
        w = A.kick(r, 1.0, 120, 45, 0.25, 1.4) + 0.6 * bp(white(r, 1.4), 300, 3000) * expenv(N(1.4), 0.3)
        tear = A.sweep_noise(r, 2.5, 1800, 500, 6, 10) * expenv(N(2.5), 0.9) * 0.5
        at = 0.1 + 0.42 * k
        place(x, w, at)
        place(x, tear, at + 0.05)
    emit("rocket_salvo", "sfx/cinema/rocket_salvo", fit(reverb(lp(x, 5000), r, 2.4, 0.4, 2400, 0.03), sec), -1.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)


def gen_c47():
    r = A.rng_for("c47_engines")
    sec, xf = 12.0, 2.0
    x = engines(r, sec + xf, 32.0, 2, 10, 0.002, 0.35)   # two radials, synchronised: no beat
    x = lp(x, 900, 2) + 0.25 * nrm(bp(pink(r, sec + xf), 300, 2500))   # the airframe's rush
    emit("c47_engines", "sfx/cinema/c47_engines", A.loopify(x, xf), -5.0, loop=True, **BED)
    r = A.rng_for("prop_windmill")
    sec, xf = 8.0, 2.0
    t = tax(N(sec + xf))
    whoosh = nrm(bp(pink(r, sec + xf), 200, 1600)) * (0.45 + 0.55 * np.abs(np.sin(2 * np.pi * 1.6 * t)) ** 3)
    air = nrm(hp(pink(r, sec + xf), 600)) * 0.35
    emit("prop_windmill", "sfx/cinema/prop_windmill", A.loopify(whoosh * 0.7 + air, xf), -6.0, loop=True, **BED)


def main():
    gen_1930()
    gen_1944()
    gen_staub()
    gen_c47()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_lazarus: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
