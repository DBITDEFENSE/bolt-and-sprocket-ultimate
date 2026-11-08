#!/usr/bin/env python3
"""GRAVELIGHT: Map 0's living world, the sound of it (Update 02 section 7, DECISIONS T-052).

Synthesizes the distant war and the ambient life around the Crossroads Inn from scratch, with gen_audio.py's DSP
core (noise, oscillators, filters, envelopes, the noise-IR reverb, bells, the formant voice): bomber streams,
fighter passes and their guns, a plane going down and its crash, artillery far and near, a far machine gun, flare
pops, crows and their wings, a far dog, the inn sign's creak, the hayloft door banging, the church bell at
midnight, wind gusts, ammunition cooking off in the wreck. No samples or recordings. License: Owned.

Keys are merged into data/gravelight/audio.json like gen_audio.py does (existing per-key tuning is kept).
Run from the repo root:   python gravelight/tools_src/gen_audio_war.py [key_prefix,...]
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
smooth_rand, reverb, echo, emit = A.smooth_rand, A.reverb, A.echo, A.emit
SR = A.SR

FAR = dict(bus="SFX", attenuation="loud")


def distant(x, r, cutoff=900.0, decay=3.0, wet=0.55, echoes=True):
    """Pushes a sound kilometres away: the highs gone, a long valley reverb, an echo off the hills."""
    y = lp(x, cutoff, 2)
    y = reverb(y, r, decay=decay, wet=wet, damp=1800, predelay=0.04, bright=0.05)
    if echoes:
        y = echo(y, r.uniform(0.6, 1.1), 0.22, 700, 2)
    return y


def engines(r, sec, base, count, harm=9, detune=0.03, rough=0.25):
    """Unsynchronised piston engines: harmonic stacks a little apart, so they beat (the bomber's 'wow-wow')."""
    t = tax(N(sec))
    out = np.zeros(N(sec))
    for k in range(count):
        f = base * (1.0 + r.uniform(-detune, detune))
        wob = 1.0 + 0.004 * smooth_rand(r, sec, 0.5)
        ph = 2 * np.pi * np.cumsum(np.full(N(sec), f) * wob) / SR
        for h in range(1, harm + 1):
            out += np.sin(h * ph + r.uniform(0, 6.28)) / (h ** 0.9) * (1.0 if h % 2 else 0.7)
    out = nrm(out)
    out += rough * nrm(lp(brown(r, sec), 220, 2))
    return out


def gen_planes():
    # the bomber stream: many four-engined aircraft high up, beating against each other
    r = A.rng_for("war_bomber")
    sec, xf = 14.0, 2.0
    x = engines(r, sec + xf, 31.0, 14, 8, 0.035, 0.4)
    x = lp(x, 650, 2) * (0.85 + 0.15 * smooth_rand(r, sec + xf, 0.3, 0, 1))
    x = reverb(x, r, 2.5, 0.35, 1200, 0.05, bright=0.05)[:N(sec + xf)]
    emit("war_bomber_drone", "sfx/war/bomber_drone", A.loopify(x, xf), -3.0, loop=True, volume_db=0.0, pitch=[1.0, 1.0],
         max_voices=3, **FAR)
    # a fighter pass: one engine, higher, the pitch falling as it goes by, the air tearing
    for i in A.variants(2):
        r = A.rng_for(f"war_fighter_pass{i}")
        sec = 7.0
        n = N(sec)
        t = tax(n)
        u = t / sec
        pitch = 1.14 - 0.3 / (1 + np.exp(-(u - 0.48) * 14))
        f = 52.0 * pitch * (1.0 + 0.003 * smooth_rand(r, sec, 3))
        ph = 2 * np.pi * np.cumsum(f) / SR
        y = sum(np.sin(h * ph) / h ** 0.8 for h in range(1, 12))
        y = nrm(y) + 0.5 * A.sweep_noise(r, sec, 900, 400, 3, 10, curve=900 * pitch)
        env = np.exp(-((u - 0.48) / 0.2) ** 2) * 0.9 + 0.1 * np.exp(-((u - 0.48) / 0.45) ** 2)
        y = lp(y * env, 2500, 2)
        y = reverb(y, r, 2.2, 0.35, 2000, 0.03)
        emit("war_fighter_pass", f"sfx/war/fighter_pass_{i:02d}", fit(y, sec), -2.0, volume_db=0.0, pitch=[0.95, 1.05], max_voices=2, **FAR)
    # aircraft guns: a short ripping burst, far off
    for i in A.variants(3):
        r = A.rng_for(f"war_fighter_mg{i}")
        sec = 2.4
        x = np.zeros(N(sec))
        shots = r.integers(9, 16)
        for k in range(shots):
            s = A.gunshot(r, A.GUNS["m1919"], "m1919")
            place(x, s * r.uniform(0.6, 1.0), 0.05 + k / 14.0 + r.uniform(-0.006, 0.006))
        emit("war_fighter_mg", f"sfx/war/fighter_mg_{i:02d}", fit(distant(x, r, 2200, 2.2, 0.45), sec), -2.0, volume_db=0.0,
             pitch=[0.96, 1.04], max_voices=2, **FAR)
    # a plane going down: the engine screaming up in the dive, misfiring, the wind's whistle rising
    r = A.rng_for("war_plane_down")
    sec = 9.0
    n = N(sec)
    t = tax(n)
    u = t / sec
    f = 45.0 * (1.0 + 0.6 * u ** 1.5)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = nrm(sum(np.sin(h * ph) / h for h in range(1, 10)))
    miss = (smooth_rand(r, sec, 9, 0, 1) > 0.35).astype(float)
    y *= 0.4 + 0.6 * lp(miss, 40, 1)
    whistle = A.sweep_noise(r, sec, 700, 2400, 14, 10, curve=700 + 1700 * u ** 2)
    y = y + 0.6 * whistle * u
    y *= np.clip(u * 1.4, 0.15, 1.0) * np.clip((sec - t) / 0.3, 0, 1)
    emit("war_plane_down", "sfx/war/plane_down", fit(distant(lp(y, 3000), r, 2600, 2.0, 0.35, False), sec), -2.0,
         volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    r = A.rng_for("war_crash_boom")
    x = A.explosion(r, True)
    x2 = np.concatenate([x, np.zeros(N(4.0))])
    place(x2, A.explosion(A.rng_for("war_crash_boom2"), False) * 0.45, 1.3)
    place(x2, A.explosion(A.rng_for("war_crash_boom3"), False) * 0.3, 2.4)
    emit("war_crash_boom", "sfx/war/crash_boom", fit(distant(x2, r, 700, 4.0, 0.7), 8.0), -1.0, volume_db=0.0, pitch=[0.97, 1.03],
         max_voices=1, **FAR)


def gen_war():
    for i in A.variants(4):
        r = A.rng_for(f"war_art_far{i}")
        x = A.explosion(r, True) * 0.9 + 0.4 * nrm(lp(brown(r, 3.6), 90, 2)) * expenv(N(3.6), 1.2)
        emit("war_artillery_boom", f"sfx/war/artillery_far_{i:02d}", fit(distant(x, r, 380, 4.2, 0.75), 7.0), -2.0,
             volume_db=0.0, pitch=[0.9, 1.08], max_voices=4, **FAR)
    for i in A.variants(3):
        r = A.rng_for(f"war_art_near{i}")
        x = A.explosion(r, True)
        x = x + 0.6 * nrm(lp(brown(r, 3.6), 70, 2)) * expenv(N(3.6), 1.6) * attack(N(3.6), 0.05)
        emit("war_artillery_near", f"sfx/war/artillery_near_{i:02d}", fit(distant(x, r, 1300, 3.5, 0.55), 7.0), -1.0,
             volume_db=0.0, pitch=[0.92, 1.05], max_voices=3, **FAR)
    for i in A.variants(3):
        r = A.rng_for(f"war_mg_far{i}")
        sec = 4.5
        x = np.zeros(N(sec))
        at = r.uniform(0.05, 0.3)
        for b in range(r.integers(1, 3)):
            shots = r.integers(5, 15)
            for k in range(shots):
                place(x, A.gunshot(r, A.GUNS["mg42"], "mg42") * r.uniform(0.6, 1.0), at + k / 19.0 + r.uniform(-0.004, 0.004))
            at += shots / 19.0 + r.uniform(0.4, 1.0)
        emit("war_mg_distant", f"sfx/war/mg_far_{i:02d}", fit(distant(x, r, 1400, 3.0, 0.6), sec), -2.0, volume_db=0.0,
             pitch=[0.95, 1.05], max_voices=2, **FAR)
    for i in A.variants(2):
        r = A.rng_for(f"war_flare{i}")
        sec = 3.0
        n = N(sec)
        t = tax(n)
        pop = A.kick(r, 0.8, 140, 60, 0.08, sec) + 0.5 * hp(white(r, sec), 2000) * expenv(n, 0.01)
        hiss = bp(white(r, sec), 1800, 5200) * attack(n, 0.08) * np.exp(-t / 1.4) * 0.35
        emit("war_flare_pop", f"sfx/war/flare_pop_{i:02d}", fit(distant(pop + hiss, r, 3500, 2.4, 0.5), sec), -3.0, volume_db=0.0,
             pitch=[0.95, 1.05], max_voices=2, **FAR)


def caw(r, f0, sec):
    pc = A.pitch_curve(r, sec, f0, [(0.0, 0.92), (0.25, 1.05), (1.0, 0.82)], wobble=0.03, vib_depth=0.01)
    v = A.voice(r, sec, pc, ["ae", "a", "ah"], shift=1.25, breath=0.35, rasp=0.9, fry=0.45, drive=2.6)
    return v * adsr(N(sec), 0.015, 0.05, 0.85, 0.06)


def gen_life():
    for i in A.variants(4):
        r = A.rng_for(f"amb_crow{i}")
        sec = 2.2
        x = np.zeros(N(sec))
        at = 0.02
        for k in range(r.integers(1, 4)):
            d = r.uniform(0.22, 0.4)
            place(x, caw(r, r.uniform(520, 700), d), at, r.uniform(0.7, 1.0))
            at += d + r.uniform(0.08, 0.25)
        emit("amb_crow_caw", f"sfx/ambience/crow_caw_{i:02d}", fit(reverb(lp(x, 4500), r, 1.8, 0.35, 3000), sec), -4.0, bus="SFX",
             volume_db=0.0, pitch=[0.94, 1.06], max_voices=3, attenuation="loud")
    r = A.rng_for("amb_crow_flap")
    sec = 2.4
    x = np.zeros(N(sec))
    for b in range(9):                       # a flock lifting off: overlapping wingbeats
        rate = r.uniform(6.5, 9.0)
        start = r.uniform(0.0, 0.5)
        for k in range(int((sec - start - 0.3) * rate)):
            beat = bp(white(r, 0.07), 300, 2400) * expenv(N(0.07), 0.02)
            place(x, beat * r.uniform(0.4, 1.0) * np.exp(-k * 0.06), start + k / rate)
    emit("amb_crow_flap", "sfx/ambience/crow_flap", fit(reverb(x, r, 1.2, 0.25, 4000), sec), -3.0, bus="SFX", volume_db=0.0,
         pitch=[0.95, 1.05], max_voices=1, attenuation="loud")
    for i in A.variants(3):
        r = A.rng_for(f"amb_dog{i}")
        sec = 1.8
        d = r.uniform(0.16, 0.22)
        pc = A.pitch_curve(r, d, r.uniform(330, 420), [(0.0, 1.0), (0.3, 1.15), (1.0, 0.7)], wobble=0.02)
        b = A.voice(r, d, pc, ["a", "o"], shift=0.95, breath=0.3, rasp=0.55, fry=0.2, drive=2.2) * adsr(N(d), 0.008, 0.05, 0.8, 0.05)
        x = np.zeros(N(sec))
        place(x, b, 0.02)
        emit("amb_dog_bark", f"sfx/ambience/dog_far_{i:02d}", fit(distant(x, r, 1500, 2.4, 0.55), sec), -4.0, volume_db=0.0,
             pitch=[0.96, 1.04], max_voices=1, **FAR)
    for i in A.variants(3):                  # the inn sign's iron hooks: stick-slip creaks through metal resonances
        r = A.rng_for(f"amb_sign{i}")
        cd = r.uniform(0.7, 1.3)
        rate = 26 + 34 * smooth_rand(r, cd, 3, 0, 1)
        stick = np.zeros(N(cd))
        idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
        stick[idx] = r.uniform(0.4, 1.0, len(idx))
        creak = reson(stick, r.uniform(620, 900), 9) + 0.7 * reson(stick, r.uniform(1300, 1700), 12) + 0.3 * reson(stick, 2600, 14)
        creak = lp(creak, 4000) * adsr(N(cd), 0.12, 0.0, 1.0, 0.25)
        emit("amb_sign_creak", f"sfx/ambience/sign_creak_{i:02d}", reverb(creak, r, 1.4, 0.25, 3500), -5.0, bus="SFX", volume_db=0.0,
             pitch=[0.92, 1.08], max_voices=1, attenuation="world")
    for i in A.variants(3):                  # the hayloft door slamming on its frame, the hinge rattling
        r = A.rng_for(f"amb_shutter{i}")
        sec = 1.2
        x = np.zeros(N(sec))
        place(x, A.thunk(r, r.uniform(120, 170), 0.05, 0.3), 0.0, 1.0)
        place(x, A.wood_crack(r, 0.25, 3) * 0.35, 0.0)
        for k in range(r.integers(2, 5)):
            place(x, A.mech_click(r, r.uniform(1800, 3000), 0.05, 0.006) * 0.25 * np.exp(-k * 0.4), 0.05 + k * r.uniform(0.04, 0.08))
        emit("amb_shutter_bang", f"sfx/ambience/shutter_bang_{i:02d}", fit(reverb(x, r, 1.6, 0.35, 3000), sec), -2.0, bus="SFX",
             volume_db=0.0, pitch=[0.93, 1.07], max_voices=2, attenuation="world")
    r = A.rng_for("amb_bell_far")
    b = A.bell(r, 174.6, 7.0, decay=3.6, strike=0.35, bright=0.7)
    emit("amb_church_bell_far", "sfx/ambience/church_bell_far", fit(distant(b, r, 1600, 3.2, 0.6), 8.0), -3.0, volume_db=0.0,
         pitch=[1.0, 1.0], max_voices=3, **FAR)
    for i in A.variants(3):
        r = A.rng_for(f"amb_gust{i}")
        sec = 6.0
        w = A.wind_bed(r, sec, 1.0)
        env = np.interp(tax(N(sec)) / sec, [0, 0.3, 0.55, 1.0], [0.0, 1.0, 0.7, 0.0])
        emit("amb_wind_gust", f"sfx/ambience/wind_gust_{i:02d}", w * env[:, None], -4.0, bus="Ambience", volume_db=0.0,
             pitch=[0.92, 1.08], max_voices=2)
    for i in A.variants(4):                  # ammunition cooking off in the burning hold
        r = A.rng_for(f"amb_cook{i}")
        sec = 0.6
        n = N(sec)
        t = tax(n)
        crack = nrm(hp(white(r, sec), 1500) * np.exp(-t / 0.004))
        body = A.kick(r, 0.6, r.uniform(180, 260), 90, 0.04, sec) * 0.6
        ping = np.sin(2 * np.pi * r.uniform(2400, 3600) * t) * np.exp(-t / 0.05) * 0.2
        x = sat((crack + body + ping) * 1.5, 1.0)
        emit("amb_cookoff", f"sfx/ambience/cookoff_{i:02d}", fit(reverb(x, r, 1.4, 0.3, 4000, 0.02), sec), -2.0, bus="SFX",
             volume_db=-2.0, pitch=[0.9, 1.1], max_voices=4, attenuation="world")


def gen_wreck_c47():
    """UPDATE 12 section 5 (T-211): GRAVELIGHT ONE's hull groaning as it cools and settles in the snow: slow stick-slip
    through the big panels' low resonances (a groan), and the cooling metal's ticks and pings."""
    for i in A.variants(4):
        r = A.rng_for(f"wreck_c47_creak{i}")
        cd = r.uniform(1.4, 2.6)
        rate = 9 + 22 * smooth_rand(r, cd, 4, 0, 1)
        stick = np.zeros(N(cd))
        idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
        stick[idx] = r.uniform(0.3, 1.0, len(idx))
        groan = reson(stick, r.uniform(150, 230), 7) + 0.8 * reson(stick, r.uniform(310, 460), 9) + 0.45 * reson(stick, r.uniform(780, 1100), 12)
        groan = lp(groan, 2600) * adsr(N(cd), 0.25, 0.0, 1.0, 0.45)
        x = np.zeros(N(cd + 0.8))
        place(x, groan, 0.0)
        for k in range(r.integers(2, 6)):   # the cooling skin's ticks after it
            place(x, A.mech_click(r, r.uniform(2200, 4200), 0.06, 0.005) * r.uniform(0.15, 0.4), cd * r.uniform(0.3, 1.0) + k * r.uniform(0.08, 0.2))
        emit("wreck_c47_creak", f"sfx/ambience/c47_creak_{i:02d}", reverb(x, r, 1.8, 0.3, 3000), -4.0, bus="SFX", volume_db=-2.0,
             pitch=[0.9, 1.08], max_voices=2, attenuation="world")


def main():
    gen_planes()
    gen_war()
    gen_life()
    gen_wreck_c47()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_war: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
