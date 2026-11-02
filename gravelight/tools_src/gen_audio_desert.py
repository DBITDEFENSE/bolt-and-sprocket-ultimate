#!/usr/bin/env python3
"""Map 4 Act III (Groom Lake): the zone ambience beds and one-shots (UPDATE 09 §5.4, DECISIONS T-148).

Synthesized from scratch with gen_audio.py's DSP core (noise, filters, envelopes, the noise-IR reverb): the desert
wind over the salt, the wreck's fire, the motor pool's diesel, the hangar's room tone and creaking boards, the
wind in the radar lattice with the relay's clicks, the lab's hum and vents, the silo shaft's drone. No samples or
recordings. License: Owned. Keys merge into data/gravelight/audio.json like gen_audio.py does (existing per-key
tuning kept); data/gravelight/ambience/map04c.json maps the zones to them (ZoneAmbience).
Run from the repo root:   python gravelight/tools_src/gen_audio_desert.py [key_prefix,...]
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
smooth_rand, reverb, emit, loopify = A.smooth_rand, A.reverb, A.emit, A.loopify
SR = A.SR

BED = dict(bus="Ambience", volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)
LOOP = 32.0
XF = 3.0


def stereo(l, r_):
    return np.stack([l, r_], axis=1)


def desert_wind(r, sec, strength=1.0, hiss=0.35):
    """Dry wind over open salt: a low rolling body, gusts, a fine high hiss of grit (no winter howl)."""
    out = np.zeros((N(sec), 2))
    for c in range(2):
        gust = 0.4 + 0.6 * (0.5 + 0.5 * smooth_rand(r, sec, 0.09)) ** 1.6
        body = lp(pink(r, sec), 520, 2) * gust
        mid = A.sweep_noise(r, sec, 260, 700, 6, 8, curve=300 + 260 * gust) * gust ** 1.3
        grit = hp(white(r, sec), 4200, 2) * np.clip(gust - 0.45, 0, 1) ** 1.2
        out[:, c] = 0.75 * nrm(body) + 0.35 * mid + hiss * nrm(grit)
    out[:, 1] = 0.7 * out[:, 1] + 0.3 * out[:, 0]
    return out * strength


def fire_roar(r, sec):
    """A big fuel fire close by: a breathing low roar, the flutter of flames, crackle and pops."""
    t = tax(N(sec))
    breathe = 0.65 + 0.35 * (0.5 + 0.5 * smooth_rand(r, sec, 0.35))
    roar = lp(brown(r, sec), 260, 2) * breathe
    flutter = bp(pink(r, sec), 300, 1400, 2) * (0.5 + 0.5 * np.abs(smooth_rand(r, sec, 6.0)))
    crk = A.crackle(r, sec, 26.0, 1.0, 900, 7000)
    pops = A.crackle(r, sec, 1.5, 1.0, 200, 2500)
    m = 0.9 * nrm(roar) + 0.35 * nrm(flutter) + 0.4 * crk + 0.5 * pops
    return stereo(m, np.roll(m, N(0.013)) * 0.95)


def metal_creak(r, sec, f0=95.0):
    """A long stressed-metal groan: a gliding resonance on rough friction noise."""
    n = N(sec)
    t = tax(n)
    f = f0 * (1.0 + 0.25 * np.sin(np.linspace(0, np.pi, n)) + 0.05 * smooth_rand(r, sec, 3.0))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = sum(np.sin(h * ph) / h for h in range(1, 7))
    fric = bp(white(r, sec), 400, 3000, 2) * (0.5 + 0.5 * np.abs(smooth_rand(r, sec, 25.0)))
    env = np.interp(t / sec, [0, 0.15, 0.8, 1.0], [0, 1, 0.7, 0])
    return nrm((0.6 * nrm(tone) * (0.4 + 0.6 * np.abs(fric)) + 0.25 * nrm(fric)) * env)


def wood_creak(r, sec):
    """A board creaking under its own weight: a short stick-slip train with a woody body."""
    n = N(sec)
    x = np.zeros(n)
    rate = np.interp(np.arange(n) / n, [0, 0.5, 1.0], [40, 110, 30])
    tt = 0.0
    while tt < sec - 0.01:
        i = int(tt * SR)
        x[i] = r.uniform(0.6, 1.0)
        tt += 1.0 / rate[min(i, n - 1)]
    body = reson(x, r.uniform(380, 620), 12) + 0.5 * reson(x, r.uniform(900, 1400), 9)
    env = np.interp(tax(n) / sec, [0, 0.1, 0.85, 1.0], [0, 1, 0.8, 0])
    return nrm(body * env)


def diesel(r, sec, rpm=900.0):
    """A single-cylinder-heavy diesel at idle: firing pulses, valve tick, exhaust bark, a little rattle."""
    n = N(sec)
    t = tax(n)
    fire_hz = rpm / 60.0 / 2.0 * 4.0                       # four cylinders, four-stroke
    wob = 1.0 + 0.01 * smooth_rand(r, sec, 0.4)
    ph = 2 * np.pi * np.cumsum(np.full(n, fire_hz) * wob) / SR
    pulse = np.maximum(np.sin(ph), 0) ** 6
    knock = lp(pulse * (0.7 + 0.3 * white(r, sec)), 900, 2)
    bark = lp(pulse, 180, 2)
    tick = hp(np.maximum(np.sin(ph * 2.0 + 0.6), 0) ** 30, 3000, 2) * 0.3
    rattle = bp(white(r, sec), 1500, 5000, 2) * (0.3 + 0.7 * pulse)
    m = 0.9 * nrm(bark) + 0.55 * nrm(knock) + 0.15 * nrm(tick) + 0.12 * nrm(rattle)
    return stereo(m, np.roll(m, N(0.007)))


def hum(r, sec, mains=60.0, vent=0.5):
    """Lab hum: the mains and its harmonics through a transformer, a ventilation hiss, a faint glassy shimmer."""
    t = tax(N(sec))
    h = sum(np.sin(2 * np.pi * mains * k * t + r.uniform(0, 6.28)) / (k ** 1.2) for k in (1, 2, 3, 4, 6))
    h = h * (0.85 + 0.15 * smooth_rand(r, sec, 0.2))
    v = lp(pink(r, sec), 2200, 2) * vent
    shimmer = sum(np.sin(2 * np.pi * f * t) for f in (1318.5, 1975.5, 2637.0)) * 0.04 * (0.5 + 0.5 * smooth_rand(r, sec, 0.05))
    m = 0.8 * nrm(h) + 0.4 * nrm(v) + shimmer
    return stereo(m, m * 0.96)


def gen_beds():
    total = LOOP + XF
    # B: the lake bed: the open wind over the salt
    r = A.rng_for("m4c_lakebed")
    x = desert_wind(r, total, 1.0, 0.45)
    emit("ambient_map04c_lakebed", "sfx/ambience/map04c_lakebed", loopify(x, XF), -3.0, loop=True, **BED)
    # A: the wreck: the fire close, the wind behind it, the hull ticking as it cools
    r = A.rng_for("m4c_wreck")
    x = 0.85 * fire_roar(r, total) + 0.4 * desert_wind(r, total, 1.0, 0.2)
    for k in range(3):
        cr = metal_creak(r, r.uniform(1.6, 2.8), r.uniform(70, 130)) * 0.35
        A.place(x, A.to_stereo(cr), r.uniform(1.0, total - 4.0))
    emit("ambient_map04c_wreck", "sfx/ambience/map04c_wreck", loopify(x, XF), -3.0, loop=True, **BED)
    # D: the motor pool: the diesel behind its shed wall, the wind over the fence
    r = A.rng_for("m4c_motorpool")
    x = 0.8 * lp(diesel(r, total), 2500, 2) + 0.35 * desert_wind(r, total, 1.0, 0.25)
    emit("ambient_map04c_motorpool", "sfx/ambience/map04c_motorpool", loopify(x, XF), -3.0, loop=True, **BED)
    # C: the hangar: a big wooden room, the wind through the boards, the truss creaks, a radio's far hiss
    r = A.rng_for("m4c_hangar")
    w = desert_wind(r, total, 1.0, 0.1)
    x = 0.45 * lp(w, 900, 2) + 0.12 * A.to_stereo(nrm(bp(white(r, total), 900, 4000, 2)) * 0.2)
    for k in range(4):
        A.place(x, A.to_stereo(wood_creak(r, r.uniform(0.6, 1.3)) * 0.5), r.uniform(0.5, total - 2.0))
    x = reverb(x, r, decay=1.8, wet=0.35, damp=3500, predelay=0.03)
    emit("ambient_map04c_hangar", "sfx/ambience/map04c_hangar", loopify(x, XF), -4.0, loop=True, **BED)
    # E: the radar rise: the wind singing in the lattice, the relay's clicks
    r = A.rng_for("m4c_radar")
    w = desert_wind(r, total, 1.0, 0.3)
    sing = np.zeros(N(total))
    for f in (410.0, 615.0, 880.0):
        sing += reson(pink(r, total), f, 40) * (0.5 + 0.5 * smooth_rand(r, total, 0.15, 0, 1))
    clicks = A.crackle(r, total, 0.7, 1.0, 1500, 6000)
    x = 0.7 * w + A.to_stereo(0.25 * nrm(sing) + 0.3 * clicks)
    emit("ambient_map04c_radar", "sfx/ambience/map04c_radar", loopify(x, XF), -3.0, loop=True, **BED)
    # F: the lab: the hum, the vents, the stone's shimmer
    r = A.rng_for("m4c_lab")
    x = reverb(hum(r, total), r, decay=1.2, wet=0.25, damp=4000)
    emit("ambient_map04c_lab", "sfx/ambience/map04c_lab", loopify(x, XF), -5.0, loop=True, **BED)
    # G: the silo: the shaft's drone (a low resonance of the concrete tube), the wind across its mouth overhead
    r = A.rng_for("m4c_silo")
    drone = reson(brown(r, total), 41.0, 6) + 0.6 * reson(brown(r, total), 82.0, 9)
    mouth = A.sweep_noise(r, total, 180, 420, 10, 8, curve=240 + 120 * (0.5 + 0.5 * smooth_rand(r, total, 0.1)))
    x = A.to_stereo(0.8 * nrm(drone) + 0.35 * nrm(mouth))
    x = reverb(x, r, decay=3.5, wet=0.5, damp=1800, predelay=0.05)
    emit("ambient_map04c_silo", "sfx/ambience/map04c_silo", loopify(x, XF), -4.0, loop=True, **BED)


def gen_oneshots():
    for i in A.variants(3):                  # the wreck's hull groaning as it cools
        r = A.rng_for(f"m4c_creak{i}")
        x = metal_creak(r, r.uniform(1.4, 2.4), r.uniform(80, 140))
        emit("amb_m4c_metal_creak", f"sfx/ambience/m4c_metal_creak_{i:02d}", reverb(A.to_stereo(x), r, 1.0, 0.25), -6.0,
             bus="Ambience", volume_db=-4.0, pitch=[0.9, 1.1], max_voices=2)
    for i in A.variants(3):                  # the hangar's trusses
        r = A.rng_for(f"m4c_wood{i}")
        x = wood_creak(r, r.uniform(0.7, 1.4))
        emit("amb_m4c_wood_creak", f"sfx/ambience/m4c_wood_creak_{i:02d}", reverb(A.to_stereo(x), r, 1.6, 0.35), -6.0,
             bus="Ambience", volume_db=-4.0, pitch=[0.9, 1.1], max_voices=2)
    for i in A.variants(3):                  # the radar relay clicking over
        r = A.rng_for(f"m4c_relay{i}")
        n = N(0.25)
        t = tax(n)
        x = hp(white(r, 0.25), 2500, 2) * np.exp(-t / 0.004) + 0.4 * np.sin(2 * np.pi * r.uniform(1800, 2600) * t) * np.exp(-t / 0.02)
        emit("amb_m4c_relay_click", f"sfx/ambience/m4c_relay_click_{i:02d}", A.to_stereo(nrm(x)), -8.0,
             bus="Ambience", volume_db=-6.0, pitch=[0.95, 1.05], max_voices=2)
    for i in A.variants(3):                  # a loose sheet of tin on the motor pool's roof, banging in a gust
        r = A.rng_for(f"m4c_tin{i}")
        sec = 1.2
        n = N(sec)
        t = tax(n)
        x = np.zeros(n)
        for k in range(r.integers(2, 4)):
            t0 = 0.08 + 0.22 * k + r.uniform(0, 0.05)
            hit = bp(white(r, sec), 300, 5000, 2) * np.exp(-np.maximum(t - t0, 0) / 0.09) * (t >= t0)
            ring = sum(np.sin(2 * np.pi * f * t) for f in (r.uniform(180, 260), r.uniform(520, 700), r.uniform(1300, 1700))) * \
                np.exp(-np.maximum(t - t0, 0) / 0.3) * (t >= t0) * 0.3
            x += (hit + ring) * r.uniform(0.6, 1.0)
        emit("amb_m4c_tin_bang", f"sfx/ambience/m4c_tin_bang_{i:02d}", reverb(A.to_stereo(nrm(x)), r, 1.0, 0.2), -5.0,
             bus="Ambience", volume_db=-5.0, pitch=[0.9, 1.1], max_voices=1)


def main():
    gen_beds()
    gen_oneshots()
    A.write_manifest()
    total = sum(d for _, d in A.STATS)
    print(f"gen_audio_desert: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
