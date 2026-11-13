#!/usr/bin/env python3
"""GRAVELIGHT: der Kranich in flight, the sound of it (UPDATE 09 section 5.3, DECISIONS T-147).

Synthesizes Act II's ambience from scratch with gen_audio.py's DSP core (no samples, no recordings; license: Owned):
  ambient_map04b            the whole wing's drone: four Nachtglas impellers beating against each other, the airframe's
                            rumble (the act's base bed, audio.json music.ambient "map04b_kranich")
  ambient_map04b_<zone>     a loop per room for data/gravelight/ambience/map04b.json (ZoneAmbience): bay (wind rising
                            at the breach, the doors' rattle), body (muffled cabin, the tape deck's hiss), wing (the slipstream
                            over the skin, ribs ticking), engine (the impeller's violet whine up close), blister (wind on
                            perspex, flak far off), cockpit (gyro whine, instrument ticks, hiss)
  kranich_creak             the airframe flexing (metal stick-slip through hull resonances), 4 variants
  kranich_rattle            a loose panel / the rib rattle, 3 variants
  kranich_bordfunk          the Bordfunk's crackle and squelch between headings, 3 variants
  kranich_wind_gust         a gust across a breach or a blister, 2 variants
  kranich_flak              a flak burst far off through the hull, 3 variants
  (T-220, the plane pass; KranichAir mixes them by how exposed the listener is)
  kranich_wind_roar         out on the wing: the slipstream's roar, buffeting at the body, howling in the rigging
  kranich_engine_outside    the four impellers heard from outside: the throat's roar, the exhaust's rumble, the beat
  kranich_groan             the airframe's long groan in a turbulence event (deep, flexing, a rivet tick), 3 variants
Keys merge into data/gravelight/audio.json like gen_audio.py does (existing per-key tuning is kept).
Run from the repo root:   python gravelight/tools_src/gen_audio_kranich.py [key_prefix,...]
then reimport:             godot --headless --import --path .
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
place, fit, smooth_rand, reverb, emit = A.place, A.fit, A.smooth_rand, A.reverb, A.emit
SR = A.SR

LOOP = 24.0
XF = 2.0
BED = dict(bus="Ambience", volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)


def impellers(r, sec, base=46.0, count=4, harm=7, whine=0.0):
    """Four turbine-ish impellers a hair apart (they beat), a breathing low rumble, an optional high whine."""
    n = N(sec)
    out = np.zeros(n)
    for k in range(count):
        f = base * (1.0 + r.uniform(-0.012, 0.012))
        wob = 1.0 + 0.003 * smooth_rand(r, sec, 0.3)
        ph = 2 * np.pi * np.cumsum(np.full(n, f) * wob) / SR
        for h in range(1, harm + 1):
            out += np.sin(h * ph + r.uniform(0, 6.28)) / (h ** 1.1)
    out = nrm(out)
    rum = nrm(lp(brown(r, sec), 140, 2)) * (0.7 + 0.3 * (0.5 + 0.5 * smooth_rand(r, sec, 0.2)))
    y = 0.65 * out + 0.55 * rum
    if whine > 0.0:
        t = tax(n)
        wf = 880.0 * (1.0 + 0.004 * smooth_rand(r, sec, 0.25))
        wph = 2 * np.pi * np.cumsum(wf * np.ones(n)) / SR
        y += whine * (np.sin(wph) * 0.6 + np.sin(wph * 1.503) * 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.37 * t))
    return y


def stereo(r, mono, spread=0.18):
    """A cheap decorrelated stereo pair from a mono bed."""
    d = int(SR * 0.013)
    a = mono
    b = np.roll(mono, d) * (1.0 - spread) + lp(white(r, len(mono) / SR), 3000) * spread * 0.05
    return np.stack([a, b], axis=1)


def slipstream(r, sec, bright=1.0):
    """Air tearing past the skin: broadband noise with a gliding body and gusts."""
    g = 0.55 + 0.45 * (0.5 + 0.5 * smooth_rand(r, sec, 0.15))
    body = bp(pink(r, sec), 180, 1400, 2) * g
    hiss = hp(white(r, sec), 2500 * bright, 2) * (g ** 2) * 0.25
    return nrm(body) + hiss


def creak(r, sec=1.2):
    """Metal stick-slip: a pulse train with a wandering rate through two hull resonances."""
    n = N(sec)
    t = tax(n)
    rate = 18.0 + 40.0 * (0.5 + 0.5 * smooth_rand(r, sec, 2.0))
    ph = np.cumsum(rate / SR)
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float)
    pulses *= 0.5 + 0.5 * r.uniform(0, 1, n)
    env = np.interp(t / sec, [0, 0.1, 0.7, 1.0], [0.0, 1.0, 0.8, 0.0])
    x = reson(pulses * env, r.uniform(380, 620), 18) + 0.6 * reson(pulses * env, r.uniform(1100, 1700), 22)
    return reverb(nrm(x), r, 0.9, 0.3, 3500, 0.01)


def rattle(r, sec=0.9):
    n = N(sec)
    x = np.zeros(n)
    k = int(r.integers(5, 11))
    for i in range(k):
        c = A.mech_click(r, r.uniform(1400, 3200), 0.04, 0.003) * (0.4 + 0.6 * r.uniform())
        place(x, c, 0.03 + i * r.uniform(0.03, 0.07))
    return reverb(x, r, 0.6, 0.2, 4000, 0.005)


def bordfunk(r, sec=1.6):
    """Squelch, crackle and a carrier whistle: the radio deck between its recorded headings."""
    n = N(sec)
    t = tax(n)
    crk = A.crackle(r, sec, 40.0, 1.0, 900, 6000)
    hiss = bp(white(r, sec), 500, 3800, 2) * 0.3
    tone = np.sin(2 * np.pi * r.uniform(1200, 1700) * t) * 0.08 * (0.5 + 0.5 * np.sin(2 * np.pi * 3.3 * t))
    env = np.interp(t / sec, [0, 0.03, 0.85, 1.0], [0.0, 1.0, 0.9, 0.0])
    sq = np.zeros(n)
    place(sq, nrm(bp(white(r, 0.08), 1500, 5000)) * 0.6, 0.0)
    place(sq, nrm(bp(white(r, 0.06), 1500, 5000)) * 0.5, sec - 0.08)
    return (crk * 0.6 + hiss + tone) * env + sq


def flak(r, sec=2.5):
    """A burst far off, heard through the hull: a low thump, a rumble, no crack."""
    k = A.kick(r, 0.9, 85.0, 35.0, 0.35, sec)
    nz = lp(brown(r, sec), 300, 2) * np.exp(-tax(N(sec)) / 0.5) * 0.6
    return reverb(lp(nrm(k + nz), 600, 2), r, 2.2, 0.45, 900, 0.03)


def gen_beds():
    # the whole wing's drone (the act's base bed)
    r = A.rng_for("kr_drone")
    x = impellers(r, LOOP + XF) + 0.35 * nrm(lp(slipstream(r, LOOP + XF), 500, 2))
    emit("ambient_map04b", "sfx/ambience/kranich_drone", A.loopify(stereo(r, nrm(x)), XF), -3.0, loop=True, **BED)
    # the bay: wind rising at the breach (gusty whistle), the doors' rattle, the drone underneath
    r = A.rng_for("kr_bay")
    sec = LOOP + XF
    w = A.wind_bed(r, sec, 1.0)
    whistle = A.sweep_noise(r, sec, 900, 2400, 12, 8, curve=1200 + 900 * (0.5 + 0.5 * smooth_rand(r, sec, 0.2))) * 0.25
    low = lp(impellers(r, sec, 44.0, 2, 4), 200, 2) * 0.4
    m = w * 0.8 + np.stack([whistle + low, whistle * 0.8 + low], axis=1)
    emit("ambient_map04b_bay", "sfx/ambience/kranich_bay", A.loopify(m, XF), -4.0, loop=True, **BED)
    # the centre body: muffled cabin, a tape deck's hiss, a soft hum
    r = A.rng_for("kr_body")
    x = lp(impellers(r, sec, 47.0, 4, 5), 260, 2) * 0.8 + hp(white(r, sec), 4000, 2) * 0.02
    x += np.sin(2 * np.pi * 100.0 * tax(N(sec))) * 0.03
    emit("ambient_map04b_body", "sfx/ambience/kranich_body", A.loopify(stereo(r, nrm(x)), XF), -6.0, loop=True, **BED)
    # the wings: the slipstream over the skin, ribs ticking
    r = A.rng_for("kr_wing")
    x = slipstream(r, sec, 0.8) * 0.9 + lp(impellers(r, sec, 45.0, 2, 4), 220, 2) * 0.35
    ticks = np.zeros(N(sec))
    tt = 0.3
    while tt < sec - 0.3:
        place(ticks, A.mech_click(r, r.uniform(1800, 3200), 0.03, 0.003) * r.uniform(0.15, 0.4), tt)
        tt += r.uniform(0.35, 1.6)
    emit("ambient_map04b_wing", "sfx/ambience/kranich_wing", A.loopify(stereo(r, nrm(x) + ticks), XF), -4.0, loop=True, **BED)
    # the engine room: the impeller's violet whine up close
    r = A.rng_for("kr_engine")
    x = impellers(r, sec, 49.0, 4, 8, whine=0.35)
    emit("ambient_map04b_engine", "sfx/ambience/kranich_engine", A.loopify(stereo(r, nrm(x)), XF), -3.0, loop=True, **BED)
    # the blisters: wind on perspex, the drone thin
    r = A.rng_for("kr_blister")
    w2 = A.wind_bed(r, sec, 1.0)
    hi = hp(slipstream(r, sec, 1.4), 900, 2) * 0.4
    emit("ambient_map04b_blister", "sfx/ambience/kranich_blister", A.loopify(w2 * 0.9 + np.stack([hi, hi * 0.9], axis=1), XF), -4.0, loop=True, **BED)
    # the flight deck: a gyro's whine, instrument ticks, hiss
    r = A.rng_for("kr_cockpit")
    t = tax(N(sec))
    gyro = np.sin(2 * np.pi * 1320.0 * t * (1.0 + 0.001 * np.sin(2 * np.pi * 0.2 * t))) * 0.03
    x = lp(impellers(r, sec, 46.0, 4, 5), 300, 2) * 0.6 + gyro + hp(white(r, sec), 5000, 2) * 0.015
    ticks2 = np.zeros(N(sec))
    tt = 0.25
    while tt < sec - 0.2:
        place(ticks2, A.mech_click(r, 2600, 0.02, 0.002) * 0.12, tt)
        tt += 1.0
    emit("ambient_map04b_cockpit", "sfx/ambience/kranich_cockpit", A.loopify(stereo(r, nrm(x) + ticks2), XF), -6.0, loop=True, **BED)


def gen_oneshots():
    for i in A.variants(4):
        r = A.rng_for(f"kr_creak{i}")
        sec = r.uniform(0.9, 1.6)
        emit("kranich_creak", f"sfx/ambience/kranich_creak_{i:02d}", fit(creak(r, sec), sec + 0.9), -3.0, bus="Ambience",
             volume_db=0.0, pitch=[0.9, 1.1], max_voices=2)
    for i in A.variants(3):
        r = A.rng_for(f"kr_rattle{i}")
        emit("kranich_rattle", f"sfx/ambience/kranich_rattle_{i:02d}", fit(rattle(r), 1.2), -4.0, bus="Ambience",
             volume_db=0.0, pitch=[0.92, 1.08], max_voices=2)
    for i in A.variants(3):
        r = A.rng_for(f"kr_funk{i}")
        sec = r.uniform(1.2, 2.2)
        emit("kranich_bordfunk", f"sfx/ambience/kranich_bordfunk_{i:02d}", bordfunk(r, sec), -4.0, bus="Ambience",
             volume_db=0.0, pitch=[0.97, 1.03], max_voices=1)
    for i in A.variants(2):
        r = A.rng_for(f"kr_gust{i}")
        sec = 5.0
        w = A.wind_bed(r, sec, 1.0)
        env = np.interp(tax(N(sec)) / sec, [0, 0.25, 0.6, 1.0], [0.0, 1.0, 0.6, 0.0])
        emit("kranich_wind_gust", f"sfx/ambience/kranich_gust_{i:02d}", w * env[:, None], -3.0, bus="Ambience",
             volume_db=0.0, pitch=[0.92, 1.08], max_voices=2)
    for i in A.variants(3):
        r = A.rng_for(f"kr_flak{i}")
        emit("kranich_flak", f"sfx/ambience/kranich_flak_{i:02d}", flak(r), -2.0, bus="SFX", volume_db=0.0,
             pitch=[0.9, 1.1], max_voices=3, attenuation="loud")


def groan(r, sec=2.8):
    """The whole airframe flexing: a slow, deep stick-slip glide through the spar's low resonances, a tick at the end."""
    n = N(sec)
    t = tax(n)
    rate = 7.0 + 16.0 * (0.5 + 0.5 * smooth_rand(r, sec, 1.1))
    ph = np.cumsum(rate / SR)
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float) * (0.5 + 0.5 * r.uniform(0, 1, n))
    env = np.interp(t / sec, [0, 0.18, 0.55, 0.85, 1.0], [0.0, 1.0, 0.75, 0.35, 0.0])
    f0 = r.uniform(85, 140)
    body = reson(pulses * env, f0, 9) + 0.7 * reson(pulses * env, f0 * 2.7, 14) + 0.35 * reson(pulses * env, r.uniform(520, 760), 20)
    rumble = lp(brown(r, sec), 120, 2) * env * 0.5
    x = nrm(body) + nrm(rumble) * 0.4
    place(x, A.mech_click(r, r.uniform(2200, 3400), 0.03, 0.003) * 0.25, sec * r.uniform(0.75, 0.9))
    return reverb(nrm(x), r, 1.6, 0.35, 2200, 0.02)


def gen_plane():
    """T-220: the exterior loops and the turbulence groan."""
    sec = LOOP + XF
    # the wind on the wing: a big low roar (the slipstream over 90 m of wing), buffeting, the rigging's howl
    r = A.rng_for("kr_roar")
    roar = lp(pink(r, sec), 700, 2) * (0.7 + 0.3 * (0.5 + 0.5 * smooth_rand(r, sec, 0.35)))
    buffet = lp(brown(r, sec), 90, 2) * (0.5 + 0.5 * np.clip(smooth_rand(r, sec, 1.8), 0.0, 1.0))
    howl = A.sweep_noise(r, sec, 500, 1500, 10, 7, curve=900 + 400 * (0.5 + 0.5 * smooth_rand(r, sec, 0.25))) * 0.18
    m = A.wind_bed(r, sec, 1.0) * 0.7 + np.stack([nrm(roar) * 0.8 + nrm(buffet) * 0.5 + howl, nrm(roar) * 0.75 + nrm(buffet) * 0.55 + howl * 0.9], axis=1)
    emit("kranich_wind_roar", "sfx/ambience/kranich_wind_roar", A.loopify(m, XF), -2.0, loop=True, **BED)
    # the engines from outside: the impellers' harmonics hard, the exhaust's rumble, the four beating
    r = A.rng_for("kr_eng_out")
    imp = impellers(r, sec, 47.0, 4, 9, whine=0.18)
    exh = lp(brown(r, sec), 220, 2) * 0.9 + bp(pink(r, sec), 120, 900, 2) * 0.5
    x = 0.7 * nrm(imp) + 0.6 * nrm(exh)
    emit("kranich_engine_outside", "sfx/ambience/kranich_engine_outside", A.loopify(stereo(r, nrm(x), 0.3), XF), -3.0, loop=True, **BED)
    for i in A.variants(3):
        r = A.rng_for(f"kr_groan{i}")
        sec2 = r.uniform(2.2, 3.4)
        emit("kranich_groan", f"sfx/ambience/kranich_groan_{i:02d}", fit(groan(r, sec2), sec2 + 1.4), -2.0, bus="Ambience",
             volume_db=0.0, pitch=[0.9, 1.08], max_voices=1)


def main():
    gen_beds()
    gen_oneshots()
    gen_plane()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_kranich: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
