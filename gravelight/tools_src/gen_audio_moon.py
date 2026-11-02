#!/usr/bin/env python3
"""GRAVELIGHT: Mondlicht's sounds (UPDATE 09 section 5.5, DECISIONS T-149).

Synthesizes Act IV's room-by-room ambience from scratch with gen_audio.py's DSP core (no samples, no recordings;
license: Owned): one seamless bed per zone for data/gravelight/ambience/map04d.json (ZoneAmbience) and the
one-shots the zones and the airlocks play.

  ambient_map04d_reception   the landing dome's air handling: a soft broadband draught and a mains hum
  ambient_map04d_concourse   the relay's hum, soft: four partials beating slowly, a breath of air
  ambient_map04d_yard        vacuum: nothing outside, only the suit (breath in, breath out, the fan, the valve)
  ambient_map04d_store       the conveyor: the motor, the rollers' rumble and tick
  ambient_map04d_hall        the retention hall: a choir-like hum (formant drones on the relay's chord)
  ambient_map04d_account     the Account: a single steady note and its shadow an octave under
  amb_m4d_airlock            the airlock's cycle: the house chime, the pumps' hiss, the seal's clunk
  amb_m4d_chime              Darkmatter's chime (three bell notes, tuned to the substrate: FINEPRINT_LORE 1.5)
  amb_m4d_vent               a vent's tick and puff
  amb_m4d_parcel             a parcel bumping over the rollers
  amb_m4d_valve              the suit's regulator: a click and a short hiss (the only one-shot in vacuum)
  amb_m4d_swell              the hall's hum swelling for a moment

Keys are merged into data/gravelight/audio.json like gen_audio.py does (existing per-key tuning is kept).
Run from the repo root:   python -I gravelight/tools_src/gen_audio_moon.py [key_prefix,...]
then reimport:             godot --headless --audio-driver Dummy --import --path .
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
lp, hp, bp, reson, nrm = A.lp, A.hp, A.bp, A.reson, A.nrm
expenv, attack, adsr, place = A.expenv, A.attack, A.adsr, A.place
smooth_rand, reverb, emit, loopify, periodic = A.smooth_rand, A.reverb, A.emit, A.loopify, A.periodic
SR = A.SR

BED = dict(bus="Ambience", attenuation="quiet", max_voices=1)
ONE = dict(bus="Ambience", attenuation="quiet")


def tone(f, sec, ph=0.0):
    return np.sin(2 * np.pi * f * tax(N(sec)) + ph)


def gen_reception():
    r = A.rng_for("m4d_reception")
    sec, xf = 16.0, 1.5
    air = lp(hp(pink(r, sec + xf), 90), 1100) * (0.85 + 0.15 * smooth_rand(r, sec + xf, 0.3))
    flutter = bp(white(r, sec + xf), 300, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 6.5 * tax(N(sec + xf)))) * 0.12
    mains = (tone(periodic(60.0, sec), sec + xf) * 0.08 + tone(periodic(120.0, sec), sec + xf) * 0.05
             + tone(periodic(180.0, sec), sec + xf) * 0.02)
    x = loopify(nrm(air) * 0.7 + flutter + mains, xf)
    emit("ambient_map04d_reception", "sfx/ambience/map04d_reception_bed", x, -6.0, loop=True, volume_db=-2.0, **BED)


def gen_concourse():
    r = A.rng_for("m4d_concourse")
    sec, xf = 16.0, 1.5
    n = N(sec + xf)
    x = np.zeros(n)
    for f, g in [(55.0, 0.5), (110.4, 0.35), (164.6, 0.22), (220.9, 0.12)]:
        fp = periodic(f, sec)
        x += tone(fp, sec + xf, r.uniform(0, 6.28)) * g * (0.75 + 0.25 * smooth_rand(r, sec + xf, 0.15, 0, 1))
    x += lp(pink(r, sec + xf), 600) * 0.12
    x = loopify(reverb(x, r, 1.6, 0.25, 3000), xf)
    emit("ambient_map04d_concourse", "sfx/ambience/map04d_concourse_bed", x, -6.0, loop=True, volume_db=-3.0, **BED)


def _breath(r, inhale: bool, sec: float):
    n = N(sec)
    t = tax(n) / sec
    env = np.sin(np.pi * np.clip(t, 0, 1)) ** (1.5 if inhale else 1.2)
    lo, hi = (500, 2400) if inhale else (300, 1600)
    b = bp(white(r, sec), lo, hi) * env
    return reson(b, 900 if inhale else 650, 3.0) * 0.6 + b * 0.4


def gen_yard():
    # the suit only: a fan's low whirr, two breaths in 8 s, the regulator's click at each inhale
    r = A.rng_for("m4d_yard")
    sec = 8.0
    n = N(sec)
    x = np.zeros(n)
    fan = tone(periodic(178.0, sec), sec) * 0.015 + lp(pink(r, sec), 400) * 0.03
    x += fan
    for k in range(2):
        t0 = k * 4.0
        place(x, _breath(r, True, 1.6) * 0.5, t0 + 0.2)
        place(x, _breath(r, False, 1.9) * 0.42, t0 + 1.95)
        place(x, A.mech_click(r, 2400, 0.04, 0.003) * 0.12, t0 + 0.15)
    x = A.lp(x, 3500)
    emit("ambient_map04d_yard", "sfx/ambience/map04d_yard_suit", x, -8.0, loop=True, volume_db=-4.0, **BED)


def gen_store():
    r = A.rng_for("m4d_store")
    sec, xf = 12.0, 1.0
    n = N(sec + xf)
    motor = (tone(periodic(100.0, sec), sec + xf) * 0.12 + tone(periodic(200.0, sec), sec + xf) * 0.06
             + tone(periodic(300.0, sec), sec + xf) * 0.025)
    rumble = lp(brown(r, sec + xf), 260) * 0.5
    ticks = np.zeros(n)
    t = 0.0
    while t < sec + xf - 0.1:
        place(ticks, A.mech_click(r, r.uniform(1400, 2200), 0.03, 0.002) * r.uniform(0.04, 0.09), t)
        t += 0.25 + r.uniform(-0.02, 0.02)
    x = loopify(reverb(motor + nrm(rumble) * 0.35 + ticks, r, 1.0, 0.2, 4000), xf)
    emit("ambient_map04d_store", "sfx/ambience/map04d_store_bed", x, -6.0, loop=True, volume_db=-3.0, **BED)


def gen_hall():
    r = A.rng_for("m4d_hall")
    sec, xf = 16.0, 2.0
    n = N(sec + xf)
    x = np.zeros(n)
    for f, vow, g in [(periodic(110.0, sec), "u", 0.5), (periodic(164.8, sec), "o", 0.32), (periodic(220.0, sec), "ah", 0.22)]:
        v = A.voice(r, sec + xf, np.full(n, f), [vow], breath=0.15, rasp=0.05, drive=1.1)
        v = v * (0.7 + 0.3 * smooth_rand(r, sec + xf, 0.12, 0, 1))
        x += nrm(v) * g
    x += tone(periodic(55.0, sec), sec + xf) * 0.18
    x = loopify(reverb(lp(x, 2600), r, 3.2, 0.42, 2500, 0.03), xf)
    emit("ambient_map04d_hall", "sfx/ambience/map04d_hall_bed", x, -6.0, loop=True, volume_db=-2.0, **BED)


def gen_account():
    r = A.rng_for("m4d_account")
    sec = 12.0
    f = periodic(196.0, sec)
    trem = 0.85 + 0.15 * np.sin(2 * np.pi * periodic(0.25, sec) * tax(N(sec)))
    x = tone(f, sec) * 0.5 * trem + tone(f * 2.0, sec) * 0.06 + tone(f * 0.5, sec) * 0.22
    x += lp(pink(r, sec), 300) * 0.02
    emit("ambient_map04d_account", "sfx/ambience/map04d_account_note", x, -8.0, loop=True, volume_db=-4.0, **BED)


def _chime(r):
    x = np.zeros(N(2.6))
    for k, note in enumerate(["E6", "C6", "A5"]):
        place(x, A.bell(r, A.hz(note), 2.2, decay=1.4, strike=0.3, bright=0.6) * 0.45, 0.22 * k)
    return x


def gen_airlock():
    for i in A.variants(2):
        r = A.rng_for(f"m4d_airlock{i}")
        sec = 3.8
        x = np.zeros(N(sec))
        place(x, _chime(r)[: N(1.6)] * 0.5, 0.0)
        hiss = hp(bp(white(r, 2.4), 1800, 9000), 1200) * adsr(N(2.4), 0.25, 0.4, 0.75, 0.8)
        place(x, hiss * 0.55, 0.65)
        place(x, A.thunk(r, r.uniform(85, 110), 0.06, 0.35) * 0.7, 3.2)
        place(x, A.mech_click(r, 1800, 0.06, 0.004) * 0.3, 3.22)
        emit("amb_m4d_airlock", f"sfx/world/m4d_airlock_{i:02d}", reverb(x, r, 1.2, 0.25, 5000), -3.0, volume_db=-3.0,
             pitch=[0.97, 1.03], max_voices=2, bus="SFX", attenuation="world")


def gen_chime():
    r = A.rng_for("m4d_chime")
    emit("amb_m4d_chime", "sfx/ambience/m4d_chime", reverb(_chime(r), r, 2.0, 0.35, 5000), -6.0, volume_db=-8.0,
         pitch=[0.99, 1.01], max_voices=1, **ONE)


def gen_small():
    for i in A.variants(3):
        r = A.rng_for(f"m4d_vent{i}")
        x = np.zeros(N(0.9))
        place(x, A.mech_click(r, r.uniform(2500, 4200), 0.05, 0.003) * 0.6, 0.0)
        place(x, bp(white(r, 0.6), 600, 3000) * expenv(N(0.6), 0.15) * 0.4, 0.04)
        emit("amb_m4d_vent", f"sfx/ambience/m4d_vent_{i:02d}", reverb(x, r, 0.8, 0.2, 5000), -8.0, volume_db=-10.0,
             pitch=[0.94, 1.06], max_voices=2, **ONE)
    for i in A.variants(3):
        r = A.rng_for(f"m4d_parcel{i}")
        x = np.zeros(N(0.7))
        for k in range(3):
            place(x, A.thunk(r, r.uniform(140, 220), 0.025, 0.12) * (0.6 - 0.15 * k), 0.09 * k)
        emit("amb_m4d_parcel", f"sfx/ambience/m4d_parcel_{i:02d}", reverb(x, r, 0.8, 0.2, 4000), -8.0, volume_db=-9.0,
             pitch=[0.92, 1.08], max_voices=2, **ONE)
    for i in A.variants(2):
        r = A.rng_for(f"m4d_valve{i}")
        x = np.zeros(N(0.8))
        place(x, A.mech_click(r, 2200, 0.04, 0.003) * 0.5, 0.0)
        place(x, bp(white(r, 0.5), 1500, 6000) * adsr(N(0.5), 0.02, 0.1, 0.5, 0.25) * 0.3, 0.05)
        emit("amb_m4d_valve", f"sfx/ambience/m4d_valve_{i:02d}", A.lp(x, 4000), -10.0, volume_db=-12.0,
             pitch=[0.95, 1.05], max_voices=1, **ONE)
    r = A.rng_for("m4d_swell")
    sec = 5.0
    sw = (tone(110.0, sec) * 0.5 + tone(165.0, sec) * 0.3 + tone(220.0, sec) * 0.2) * np.sin(np.pi * tax(N(sec)) / sec) ** 2
    emit("amb_m4d_swell", "sfx/ambience/m4d_swell", reverb(sw, r, 2.5, 0.4, 2500), -8.0, volume_db=-8.0,
         pitch=[0.98, 1.02], max_voices=1, **ONE)


def main():
    gen_reception()
    gen_concourse()
    gen_yard()
    gen_store()
    gen_hall()
    gen_account()
    gen_airlock()
    gen_chime()
    gen_small()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_moon: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
