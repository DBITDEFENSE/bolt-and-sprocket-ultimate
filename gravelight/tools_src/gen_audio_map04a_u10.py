#!/usr/bin/env python3
"""Werk Thalbach's UPDATE 10 one-shots and loops (docs/work_orders/UPDATE_10.md §3 Act I, DECISIONS T-155).

Synthesized from scratch with gen_audio.py's DSP core (noise, filters, oscillators, the noise-IR reverb): no samples,
no recordings, no third-party audio. License: Owned (original, procedurally synthesized), like everything
gen_audio.py makes.

  a1_siren          an air-raid siren winding up, wavering and falling (the raid; far, so low-passed)
  a1_bomb_whistle   a falling bomb's whistle, the pitch dropping as it comes down (the raid's telegraph)
  a1_collapse       a roof bay coming down: a crack, groaning steel, a long crash of sheet and brick, settling
  a1_rivet_hammer   the rivet line's pneumatic hammers (loop): fast hammer strikes on steel, the air line's hiss
  a1_fan_spinup     the wind tunnel's fan turning over and spinning up, the air beginning to roar
  a1_train_whistle  a steam locomotive's whistle, two blasts, far down the valley
  a1_train_steam    a locomotive arriving: brakes squealing, the steam let off, couplings banging
  a1_jet_pass       a test jet's low pass: a rising turbine whine, the tearing roar overhead, the long tail
  a1_sheet_rattle   loose corrugated sheet rattling in a gust
  a1_pa_crackle     the works' PA horn coming alive: a click, mains hum, a crackle

Mono, 44.1 kHz 16-bit, written to gravelight/audio/sfx/map04a/*.wav and merged into data/gravelight/audio.json
(gen_audio.write_manifest keeps every other key as it is).
Run from the repo root:  python gravelight/tools_src/gen_audio_map04a_u10.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
_argv = sys.argv[:]
sys.argv = sys.argv[:1]
import gen_audio as A            # noqa: E402
import numpy as np               # noqa: E402
sys.argv = _argv

FAR = dict(bus="SFX", attenuation="loud")


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def rev(x, key, decay=1.6, wet=0.3, damp=3500.0):
    r = A.rng_for(key + "_rev")
    return mono(A.reverb(A.to_stereo(x), r, decay, wet, damp, 0.02, stereo=True))


def siren():
    sec = 11.0
    n = A.N(sec)
    t = A.tax(n)
    u = t / sec
    rise = np.clip(u / 0.28, 0, 1) ** 0.7
    fall = np.clip((1.0 - u) / 0.38, 0, 1) ** 0.9
    f = 150 + 470 * np.minimum(rise, fall) + 14 * np.sin(2 * np.pi * 0.4 * t)
    ph = A.phase_of(f, n)
    x = np.sin(2 * np.pi * ph) + 0.45 * np.sin(4 * np.pi * ph) + 0.2 * np.sin(6 * np.pi * ph)
    x = A.lp(x, 1700, 2) * A.adsr(n, 0.6, 0.0, 1.0, 1.4)
    return rev(A.nrm(x), "a1_siren", 3.0, 0.45, 2200)


def bomb_whistle():
    sec = 2.6
    n = A.N(sec)
    u = A.tax(n) / sec
    f = 1700 - 1150 * u ** 1.3
    x = np.sin(2 * np.pi * A.phase_of(f, n)) * 0.7
    r = A.rng_for("a1_bomb_whistle")
    x += 0.3 * A.nrm(A.bp(A.white(r, sec), 900, 2600)) * (0.4 + 0.6 * u)
    x *= A.attack(n, 0.4) * (0.35 + 0.65 * u)
    return rev(A.nrm(x), "a1_bomb_whistle", 1.0, 0.2)


def collapse():
    sec = 6.5
    r = A.rng_for("a1_collapse")
    x = A.zeros(sec)
    A.place(x, A.nrm(A.kick(r, 1.0, 90, 28, 0.5, 2.0)), 0.0)
    crack = A.nrm(A.bp(A.white(r, 0.25), 1500, 7000)) * A.expenv(A.N(0.25), 0.04)
    A.place(x, 0.8 * crack, 0.0)
    # groaning steel (a slow detuned pair falling in pitch)
    n = A.N(2.5)
    u = A.tax(n) / 2.5
    g = np.sin(2 * np.pi * A.phase_of(180 - 90 * u, n)) + np.sin(2 * np.pi * A.phase_of(187 - 95 * u, n))
    A.place(x, 0.35 * A.nrm(A.lp(g, 900)) * A.adsr(n, 0.2, 0.0, 1.0, 0.8), 0.15)
    # the long crash: sheet metal, brick, glass, three waves
    for t0, amp in ((0.5, 1.0), (1.4, 0.8), (2.6, 0.55)):
        d = 2.2
        w = A.nrm(A.bp(A.pink(r, d), 200, 6000)) * A.expenv(A.N(d), 0.6)
        A.place(x, amp * w, t0)
        for _ in range(10):
            A.place(x, 0.25 * amp * A.nrm(A.reson(A.white(r, 0.3) * A.expenv(A.N(0.3), 0.01), r.uniform(1500, 5200), 30)), t0 + r.uniform(0, 1.6))
    A.place(x, 0.5 * A.nrm(A.lp(A.brown(r, 4.0), 140)) * A.expenv(A.N(4.0), 1.4), 0.3)
    return rev(A.nrm(x), "a1_collapse", 2.6, 0.35, 3000)


def rivet_hammer():
    loop = 2.0
    r = A.rng_for("a1_rivet_hammer")
    x = A.zeros(loop + 0.4)
    period = 0.055
    t = 0.0
    while t < loop:
        hit = A.nrm(A.reson(A.white(r, 0.05) * A.expenv(A.N(0.05), 0.004), r.uniform(2400, 3400), 18))
        hit += 0.6 * A.nrm(A.kick(r, 0.5, 220, 120, 0.02, 0.05))
        A.place(x, 0.55 * hit, t)
        t += period * r.uniform(0.9, 1.1)
    x += 0.12 * A.nrm(A.bp(A.white(r, loop + 0.4), 3000, 9000))
    x = rev(A.nrm(x), "a1_rivet_hammer", 1.4, 0.3)
    return A.loopify(x[:A.N(loop + 0.4)], 0.4)


def fan_spinup():
    sec = 6.0
    n = A.N(sec)
    u = A.tax(n) / sec
    r = A.rng_for("a1_fan_spinup")
    bf = 1.5 + 13.0 * np.clip(u / 0.7, 0, 1) ** 1.5      # blade pass rate (Hz)
    ph = A.phase_of(bf * 8.0, n)
    thump = (0.5 + 0.5 * np.sin(2 * np.pi * A.phase_of(bf, n))) ** 4
    pk = A.pink(r, sec)
    roar = A.nrm((1.0 - u) * A.lp(pk, 400) + u * A.lp(pk, 1800)) * (0.2 + 0.8 * u)
    whine = 0.15 * np.sin(2 * np.pi * ph) * u
    x = 0.6 * roar + 0.4 * A.nrm(A.lp(A.white(r, sec), 300)) * thump + whine
    x *= A.adsr(n, 0.5, 0.0, 1.0, 0.8)
    return rev(A.nrm(x), "a1_fan_spinup", 2.2, 0.4)


def train_whistle():
    sec = 4.4
    x = A.zeros(sec)
    for t0, d in ((0.0, 1.3), (1.7, 2.2)):
        n = A.N(d)
        f0 = 440.0
        y = sum(np.sin(2 * np.pi * A.phase_of(f0 * k * (1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * A.tax(n))), n)) / k for k in (1, 1.26, 1.5, 2.0))
        r = A.rng_for("a1_train_whistle%d" % int(t0))
        y = A.nrm(y) + 0.25 * A.nrm(A.bp(A.white(r, d), 1500, 5000))
        A.place(x, A.lp(y, 3000) * A.adsr(n, 0.08, 0.0, 1.0, 0.35), t0)
    return rev(A.nrm(x), "a1_train_whistle", 3.4, 0.55, 2500)


def train_steam():
    sec = 7.0
    r = A.rng_for("a1_train_steam")
    n = A.N(sec)
    u = A.tax(n) / sec
    x = A.zeros(sec)
    # brakes: a squeal falling and fading
    sq = np.sin(2 * np.pi * A.phase_of(2400 - 600 * u, n)) * np.clip(1.0 - u / 0.45, 0, 1)
    x += 0.25 * sq
    # the chuff slowing to a stop
    t = 0.0
    gap = 0.35
    while t < 3.2:
        A.place(x, 0.4 * A.nrm(A.bp(A.white(r, 0.25), 300, 2500)) * A.expenv(A.N(0.25), 0.08), t)
        t += gap
        gap *= 1.18
    # the steam let off, couplings banging down the train
    hiss = A.nrm(A.bp(A.white(r, 3.0), 2000, 9000)) * A.adsr(A.N(3.0), 0.15, 0.0, 1.0, 1.2)
    A.place(x, 0.55 * hiss, 3.4)
    for k in range(4):
        A.place(x, 0.45 * A.nrm(A.reson(A.white(r, 0.2) * A.expenv(A.N(0.2), 0.01), 600 + 80 * k, 12)), 2.6 + 0.28 * k)
    return rev(A.nrm(x), "a1_train_steam", 2.4, 0.4)


def jet_pass():
    sec = 8.0
    r = A.rng_for("a1_jet_pass")
    n = A.N(sec)
    u = A.tax(n) / sec
    near = np.exp(-((u - 0.45) / 0.12) ** 2)
    whine_f = 1800 * (1.15 - 0.35 / (1 + np.exp(-(u - 0.45) * 16)))
    whine = np.sin(2 * np.pi * A.phase_of(whine_f, n)) * (0.2 + 0.8 * near) * 0.3
    pk = A.pink(r, sec)
    roar = A.nrm((1.0 - near) * A.lp(pk, 600) + near * A.lp(pk, 3600)) * (0.15 + 0.85 * near)
    tail = A.nrm(A.lp(A.brown(r, sec), 200)) * np.clip((u - 0.4) / 0.2, 0, 1) * np.exp(-(u - 0.4) * 2.5) * 0.6
    x = roar + whine + tail
    return rev(A.nrm(x), "a1_jet_pass", 3.0, 0.45, 2600)


def sheet_rattle():
    sec = 1.6
    r = A.rng_for("a1_sheet_rattle")
    x = A.zeros(sec)
    t = 0.0
    while t < 1.3:
        A.place(x, r.uniform(0.3, 1.0) * A.nrm(A.reson(A.white(r, 0.08) * A.expenv(A.N(0.08), 0.012), r.uniform(700, 1400), 8)), t)
        t += r.uniform(0.03, 0.12)
    x += 0.2 * A.nrm(A.bp(A.white(r, sec), 400, 3000)) * A.adsr(A.N(sec), 0.1, 0.0, 1.0, 0.5)
    return rev(A.nrm(x), "a1_sheet_rattle", 0.9, 0.25)


def pa_crackle():
    sec = 1.8
    r = A.rng_for("a1_pa_crackle")
    n = A.N(sec)
    x = A.zeros(sec)
    A.place(x, A.nrm(A.reson(A.white(r, 0.03) * A.expenv(A.N(0.03), 0.003), 1800, 10)), 0.0)
    hum = sum(np.sin(2 * np.pi * f * A.tax(n)) / k for k, f in enumerate((50.0, 100.0, 150.0), 1))
    x += 0.3 * A.nrm(hum) * A.adsr(n, 0.05, 0.0, 1.0, 0.6)
    x += 0.35 * A.crackle(r, sec, 22, 1.0, 1500, 7000)
    x = A.bp(x, 300, 4000)
    return rev(A.nrm(x), "a1_pa_crackle", 1.6, 0.4)


def gen():
    A.emit("a1_siren", "sfx/map04a/a1_siren", siren(), -2.0, volume_db=0.0, pitch=[0.97, 1.03], max_voices=4, **FAR)
    A.emit("a1_bomb_whistle", "sfx/map04a/a1_bomb_whistle", bomb_whistle(), -3.0, volume_db=0.0, pitch=[0.92, 1.08], max_voices=3, **FAR)
    A.emit("a1_collapse", "sfx/map04a/a1_collapse", collapse(), -1.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    A.emit("a1_rivet_hammer", "sfx/map04a/a1_rivet_hammer", rivet_hammer(), -4.0, loop=True, bus="SFX", volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)
    A.emit("a1_fan_spinup", "sfx/map04a/a1_fan_spinup", fan_spinup(), -2.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    A.emit("a1_train_whistle", "sfx/map04a/a1_train_whistle", train_whistle(), -3.0, volume_db=0.0, pitch=[0.98, 1.02], max_voices=1, **FAR)
    A.emit("a1_train_steam", "sfx/map04a/a1_train_steam", train_steam(), -3.0, volume_db=0.0, pitch=[1.0, 1.0], max_voices=1, **FAR)
    A.emit("a1_jet_pass", "sfx/map04a/a1_jet_pass", jet_pass(), -1.5, volume_db=0.0, pitch=[0.97, 1.03], max_voices=1, **FAR)
    A.emit("a1_sheet_rattle", "sfx/map04a/a1_sheet_rattle", sheet_rattle(), -6.0, bus="SFX", volume_db=0.0, pitch=[0.9, 1.1], max_voices=3)
    A.emit("a1_pa_crackle", "sfx/map04a/a1_pa_crackle", pa_crackle(), -5.0, bus="SFX", volume_db=0.0, pitch=[1.0, 1.0], max_voices=2)


def main():
    gen()
    A.write_manifest()
    print("gen_audio_map04a_u10: wrote %d sounds (%.1f s), merged into data/gravelight/audio.json" % (len(A.STATS), sum(d for _, d in A.STATS)))


if __name__ == "__main__":
    main()
