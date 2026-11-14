#!/usr/bin/env python3
"""GRAVELIGHT T-249: the Sherman event's sounds, synthesized from scratch (the tank, the dive bomber, the burning dead).

No recordings and no samples: gen_audio.py's DSP core with gen_audio_bosses.py's building blocks, the way the horse
and boss packs were made. License: Owned (our own work). The keys go into data/gravelight/audio.json as ONE block at
the END of "sounds" (sorted), so a three-way merge with another branch's audio.json never meets it; a key already
there is replaced. The air-raid siren, the bomb whistle, the big explosions, the bombers' drone, the shell's burst and
the machine gun are the bank's own (a1_siren, a1_bomb_whistle, explosion_large, war_bomber_drone, war_artillery_near,
fire_m1919, fire_crackle).

  sherman_engine          the tank's engine, idling to a working rumble (loop)
  sherman_tracks          the tracks: link clank and the squeal of the idler (loop)
  sherman_gun_1..2        the 75 mm: the blast, the slam of the breech, the valley's answer
  sherman_clang_1..3      a fist or a shoulder against the hull: a dull knock on armour
  sherman_cookoff         the ammunition cooking off in a burning hull: crackling, pops, a roar of flame
  stuka_engine            a single-engined aircraft high up, droning (loop)
  stuka_dive              the dive: the engine screaming up, the siren's wail rising with the speed, the pull-out
  firezed_burn            a burning body: roar and crackle (loop)
  firezed_hiss            the fuse: a hiss swelling to a flare
  firezed_burst_1..2      the burst: a soft heavy whoomph with fire in it

Run from the repo root:   python gravelight/tools_src/gen_audio_sherman.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy, scipy and ffmpeg on PATH.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import gen_audio_bosses as B                 # noqa: E402
import numpy as np                           # noqa: E402

N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, place = A.expenv, A.attack, A.place
smooth_rand, reverb, echo = A.smooth_rand, A.reverb, A.echo
SR = A.SR
emit_ogg = B.emit_ogg


def r_(name: str, i: int = 0):
    return A.rng_for("sherman_%s_%d" % (name, i))


def engine_tone(r, sec: float, rpm_curve, cyl: int = 8, rough: float = 0.25):
    """A piston engine: the firing frequency's harmonics with per-stroke jitter, through a box resonance."""
    n = N(sec)
    f = rpm_curve / 60.0 * cyl / 2.0                     # firing frequency
    ph = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for h, g in [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.2), (6, 0.12), (0.5, 0.45)]:
        out += np.sin(ph * h + r.uniform(0, 6.28)) * g
    jitter = smooth_rand(r, sec, 9.0, 1.0 - rough, 1.0 + rough)
    out *= jitter
    pulses = np.maximum(0.0, np.sin(ph)) ** 6           # the exhaust's puffs
    out += lp(white(r, sec), 900) * pulses * 1.4
    return sat(out, 1.5)


def gen_tank():
    # the engine: a big petrol V8 at a working idle with a slow surge, loopable
    r = r_("engine")
    sec = 6.0
    rpm = 900 + 140 * np.sin(2 * np.pi * tax(N(sec)) / sec) + smooth_rand(r, sec, 0.8, -40, 40)
    x = engine_tone(r, sec, rpm)
    x = lp(x, 1400) + 0.25 * bp(pink(r, sec), 60, 240)
    x += 0.08 * hp(white(r, sec), 3000) * smooth_rand(r, sec, 3.0, 0.2, 1.0)   # fan and valve chatter
    x = A.loopify(x, 0.5)
    emit_ogg("sherman_engine", "sherman/sherman_engine", x, peak_db=-6.0, loop=True, bus="SFX", volume_db=-4.0, attenuation="loud")
    # the tracks: a clank per link over the sprocket, the idler's squeal, a gravelly crunch
    r = r_("tracks")
    sec = 4.0
    n = N(sec)
    x = np.zeros(n)
    t = 0.0
    while t < sec - 0.2:
        k = B.metal_ring(r, r.uniform(380, 620), 0.18, 0.025, (1.0, 2.3, 4.1), 0.5) * 0.6
        k += lp(white(r, 0.18), 1500) * expenv(N(0.18), 0.02)
        place(x, k, t, r.uniform(0.6, 1.0))
        t += r.uniform(0.085, 0.11)
    squeal = A.sweep_noise(r, sec, 1800, 2400, q=18.0) * smooth_rand(r, sec, 0.7, 0.0, 1.0) ** 2 * 0.35
    crunch = bp(brown(r, sec), 80, 700) * 0.6
    x = x + squeal + crunch
    x = A.loopify(x, 0.3)
    emit_ogg("sherman_tracks", "sherman/sherman_tracks", x, peak_db=-7.0, loop=True, bus="SFX", volume_db=-5.0, attenuation="loud")
    # the 75 mm: a deep blast with a hard crack, the breech, the echo off the hills
    for i in range(2):
        r = r_("gun", i)
        sec = 3.2
        n = N(sec)
        x = B.sub_thump(r, 95 + 8 * i, 30, sec, 0.35) * 1.6
        x += hp(white(r, sec), 900) * expenv(n, 0.018) * 1.2
        x += lp(white(r, sec), 2200) * expenv(n, 0.12) * 0.7
        breech = B.metal_ring(r, 260 + 30 * i, 0.4, 0.06, (1.0, 2.6, 4.3), 0.5) * 0.3
        place(x, breech, 0.42, 1.0)
        x = echo(x, 0.55, 0.35, 1600.0, 3)
        x = reverb(x, r, decay=2.6, wet=0.32, damp=2200)
        emit_ogg("sherman_gun", "sherman/sherman_gun_%d" % (i + 1), x, peak_db=-0.5, bus="SFX", volume_db=2.0, pitch=[0.96, 1.04], max_voices=2, attenuation="loud")
    # a blow on the armour
    for i in range(3):
        r = r_("clang", i)
        sec = 0.6
        n = N(sec)
        x = B.metal_ring(r, r.uniform(140, 210), sec, 0.12, (1.0, 2.1, 3.7, 5.3), 0.45) * 0.7
        x += lp(white(r, sec), 1200) * expenv(n, 0.015) * 0.8
        x = reverb(x, r, decay=0.6, wet=0.15, damp=4000)
        emit_ogg("sherman_clang", "sherman/sherman_clang_%d" % (i + 1), x, peak_db=-4.0, bus="SFX", volume_db=-4.0, pitch=[0.9, 1.1], max_voices=4, attenuation="world")
    # the ammunition cooking off: a roar of flame, crackle, rounds popping
    r = r_("cookoff")
    sec = 6.0
    n = N(sec)
    roar = bp(pink(r, sec), 90, 900) * smooth_rand(r, sec, 2.5, 0.4, 1.0) * 0.8
    crack = A.crackle(r, sec, 70.0, 1.0, 900, 7000) * 0.6
    x = roar + crack
    for k in range(9):
        pop = B.sub_thump(r, 160, 60, 0.5, 0.06) * 0.5 + hp(white(r, 0.5), 1500) * expenv(N(0.5), 0.01) * 0.6
        place(x, pop, r.uniform(0.2, sec - 0.6), r.uniform(0.3, 0.9))
    x *= np.minimum(1.0, np.linspace(0, 6, n)) * np.minimum(1.0, np.linspace(4, 0, n) + 0.3)
    x = reverb(x, r, decay=1.6, wet=0.25, damp=3000)
    emit_ogg("sherman_cookoff", "sherman/sherman_cookoff", x, peak_db=-2.0, bus="SFX", volume_db=0.0, attenuation="loud")


def gen_stuka():
    # high up: a single radial... (the dive bomber's inverted V12) droning, with the beat of distance
    r = r_("stuka_engine")
    sec = 6.0
    rpm = 2200 + smooth_rand(r, sec, 0.4, -60, 60)
    x = engine_tone(r, sec, rpm, cyl=12, rough=0.12)
    x = lp(x, 900) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.6 * tax(N(sec))))
    x += 0.2 * bp(pink(r, sec), 120, 500)
    x = A.loopify(x, 0.5)
    emit_ogg("stuka_engine", "sherman/stuka_engine", x, peak_db=-6.0, loop=True, bus="SFX", volume_db=0.0, attenuation="loud")
    # the dive: 7.5 s of the siren rising with the speed over the screaming engine, then the pull-out
    r = r_("stuka_dive")
    sec = 9.0
    n = N(sec)
    t = tax(n)
    dive = np.clip(t / 6.8, 0, 1)
    siren_f = 330 + 620 * dive ** 1.4
    siren_f = np.where(t > 6.8, siren_f[N(6.79)] - 260 * np.clip((t - 6.8) / 2.0, 0, 1), siren_f)
    ph = 2 * np.pi * np.cumsum(siren_f) / SR
    siren = (np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.22 * np.sin(3 * ph)) * (0.25 + 0.75 * dive)
    siren *= 1.0 + 0.06 * np.sin(2 * np.pi * 6.0 * t)                       # the rotor's flutter
    siren = sat(siren, 1.8)
    rpm = 2300 + 900 * dive
    eng = engine_tone(r, sec, rpm, cyl=12, rough=0.1) * (0.4 + 0.6 * dive)
    air = A.sweep_noise(r, sec, 400, 2600, q=2.5) * dive ** 2 * 0.6        # the wind over the wings
    x = siren * 0.9 + lp(eng, 1600) * 0.6 + air
    x *= np.minimum(1.0, t / 0.8) * np.where(t > 7.6, np.clip(1.0 - (t - 7.6) / 1.4, 0, 1), 1.0)
    x = reverb(x, r, decay=1.8, wet=0.2, damp=5000)
    emit_ogg("stuka_dive", "sherman/stuka_dive", x, peak_db=-0.5, bus="SFX", volume_db=3.0, attenuation="loud")


def gen_fire_zombie():
    r = r_("burn")
    sec = 4.0
    x = bp(pink(r, sec), 120, 1400) * smooth_rand(r, sec, 3.0, 0.5, 1.0) * 0.7
    x += A.crackle(r, sec, 45.0, 1.0, 1200, 8000) * 0.45
    x = A.loopify(x, 0.3)
    emit_ogg("firezed_burn", "sherman/firezed_burn", x, peak_db=-8.0, loop=True, bus="SFX", volume_db=-6.0, attenuation="zombie")
    r = r_("hiss")
    sec = 0.9
    n = N(sec)
    x = A.sweep_noise(r, sec, 1500, 5200, q=3.0) * np.linspace(0.2, 1.0, n) ** 2
    x += bp(pink(r, sec), 200, 900) * np.linspace(0.0, 1.0, n) ** 3 * 0.8
    emit_ogg("firezed_hiss", "sherman/firezed_hiss", x, peak_db=-3.0, bus="SFX", volume_db=-2.0, attenuation="world")
    for i in range(2):
        r = r_("burst", i)
        sec = 2.2
        n = N(sec)
        x = B.sub_thump(r, 85 + 10 * i, 36, sec, 0.25) * 1.3
        whoomph = bp(pink(r, sec), 100, 1600) * attack(n, 0.03) * expenv(n, 0.35)
        x += whoomph * 1.1
        x += A.crackle(r, sec, 60.0, 1.0, 1000, 7000) * expenv(n, 0.6) * 0.4
        x = reverb(x, r, decay=1.3, wet=0.22, damp=3500)
        emit_ogg("firezed_burst", "sherman/firezed_burst_%d" % (i + 1), x, peak_db=-1.0, bus="SFX", volume_db=0.0, pitch=[0.94, 1.06], max_voices=4, attenuation="loud")


def write_manifest():
    path = A.AUDIO_JSON
    text = open(path, encoding="utf-8").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")
    for key in A.KEYS:
        text = re.sub(r',?\n    "%s": \{.*?\n    \}' % re.escape(key), "", text, flags=re.S)
    blocks = []
    for key in sorted(A.KEYS):
        body = json.dumps(A.KEYS[key], indent=2, ensure_ascii=False)
        body = "\n".join(("    " + ln) if i else ln for i, ln in enumerate(body.splitlines()))
        blocks.append('    "%s": %s' % (key, body))
    tail = "\n  }\n}"
    at = text.rstrip().rfind(tail)
    assert at > 0 and text.rstrip().endswith(tail)
    text = text[:at] + ",\n" + ",\n".join(blocks) + tail + "\n"
    json.loads(text)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text.replace("\n", nl))


def main():
    gen_tank()
    gen_stuka()
    gen_fire_zombie()
    write_manifest()
    total = sum(s for _, s in B.STATS)
    print(f"gen_audio_sherman: wrote {len(B.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
