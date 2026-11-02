#!/usr/bin/env python3
"""Werk Thalbach's zone ambience beds (UPDATE 09 §5, docs/MAPS_3_4_REBUILD.md §5.2, DECISIONS T-146).

Eight looping beds, one per Act I zone, synthesized from scratch with gen_audio.py's DSP core (noise, filters,
oscillators, the noise-IR reverb): no samples, no recordings, no third-party audio. License: Owned (original,
procedurally synthesized), like everything gen_audio.py makes.

  ambient_map04a_siedlung  dawn wind between the housing blocks, far air-raid sirens winding up and down
  ambient_map04a_bahnhof   a locomotive's steam idle hiss and pulse, rails ticking as they cool, light wind
  ambient_map04a_kantine   a valve radio's mains hum and static from the stage, the PA's click, room tone
  ambient_map04a_church    open-square wind, the stopped tower clock's slow tick, a loose gutter
  ambient_map04a_montage   iron dripping and pinging in a big hall, a far press thumping, hall reverb
  ambient_map04a_tunnel    the wind tunnel's low rumble and moving air in the horn
  ambient_map04a_pits      the Nachtglas impeller's hum and fizz over the open test stands
  ambient_map04a_hangar    a huge room's tone, the four intakes' violet hum, the netting's flap far above

Mono, 20 s loops (crossfaded), 44.1 kHz 16-bit, written to gravelight/audio/sfx/ambience/map04a_*.wav and merged into
data/gravelight/audio.json (gen_audio.write_manifest keeps every other key as it is).
Run from the repo root:  python gravelight/tools_src/gen_audio_map04a.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
_argv = sys.argv[:]
sys.argv = sys.argv[:1]          # gen_audio reads its key filter from argv[1]: none (write every key registered here)
import gen_audio as A            # noqa: E402
import numpy as np               # noqa: E402
sys.argv = _argv

LOOP = 20.0
XF = 2.5
TOTAL = LOOP + XF


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def siren(r, sec: float):
    """A far air-raid siren: a slow glide up, a wavering hold, a long fall, low-passed by distance."""
    n = A.N(sec)
    t = A.tax(n) / sec
    f = 170 + 430 * np.clip(np.minimum(t / 0.3, (1.0 - t) / 0.45), 0, 1) ** 0.8 + 18 * np.sin(2 * np.pi * 0.35 * A.tax(n))
    x = np.sin(2 * np.pi * A.phase_of(f, n)) + 0.35 * np.sin(4 * np.pi * A.phase_of(f, n))
    x = A.lp(x, 1400, 2) * A.adsr(n, 0.8, 0.0, 1.0, 2.0)
    return A.nrm(x)


def ping(r, f: float, sec: float = 0.9):
    n = A.N(sec)
    x = A.reson(A.white(r, sec) * A.expenv(n, 0.004), f, 40) + 0.4 * A.reson(A.white(r, sec) * A.expenv(n, 0.004), f * 2.71, 30)
    return A.nrm(x) * A.expenv(n, 0.25)


def thump(r, sec: float = 1.2):
    return A.nrm(A.kick(r, 0.8, 70, 30, 0.3, sec))


def gen():
    out = []
    # A Siedlung
    r = A.rng_for("amb_map04a_siedlung")
    x = mono(A.wind_bed(r, TOTAL, 0.8))
    for t0 in (1.5, 11.0):
        A.place(x, 0.12 * siren(r, 8.5), t0)
    out.append(("ambient_map04a_siedlung", "map04a_siedlung_bed", x, 2.2, 0.25))
    # B Bahnhof
    r = A.rng_for("amb_map04a_bahnhof")
    x = 0.35 * mono(A.wind_bed(r, TOTAL, 0.6))
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * 0.8 * A.tax(A.N(TOTAL))) ** 2
    x += 0.35 * A.nrm(A.bp(A.white(r, TOTAL), 1800, 7000)) * pulse * (0.7 + 0.3 * A.smooth_rand(r, TOTAL, 0.3, 0, 1))
    for _ in range(14):
        A.place(x, 0.12 * ping(r, r.uniform(2500, 5200), 0.4), r.uniform(0.2, TOTAL - 0.5))
    out.append(("ambient_map04a_bahnhof", "map04a_bahnhof_bed", x, 1.6, 0.2))
    # C Kantine
    r = A.rng_for("amb_map04a_kantine")
    n = A.N(TOTAL)
    hum = sum(np.sin(2 * np.pi * f * A.tax(n)) / k for k, f in enumerate((50.0, 100.0, 150.0, 250.0), 1))
    x = 0.18 * A.nrm(hum) + 0.25 * A.nrm(A.bp(A.white(r, TOTAL), 1200, 5000)) * (0.4 + 0.6 * A.smooth_rand(r, TOTAL, 1.4, 0, 1))
    x += 0.2 * A.nrm(A.lp(A.pink(r, TOTAL), 500))
    x += 0.15 * A.crackle(r, TOTAL, 9, 1.0, 900, 6000)
    for t0 in (4.0, 14.5):
        A.place(x, 0.5 * A.nrm(A.hp(A.white(r, 0.02), 1500)) * A.expenv(A.N(0.02), 0.003), t0)
    out.append(("ambient_map04a_kantine", "map04a_kantine_bed", x, 1.2, 0.25))
    # D Kirchplatz
    r = A.rng_for("amb_map04a_church")
    x = mono(A.wind_bed(r, TOTAL, 1.0))
    t = 0.7
    while t < TOTAL - 0.5:
        A.place(x, 0.08 * ping(r, 950 if int(t) % 4 else 720, 0.5), t)
        t += 2.0
    out.append(("ambient_map04a_church", "map04a_church_bed", x, 2.6, 0.3))
    # E Montage
    r = A.rng_for("amb_map04a_montage")
    x = 0.4 * A.nrm(A.lp(A.pink(r, TOTAL), 380)) * (0.8 + 0.2 * A.smooth_rand(r, TOTAL, 0.2, 0, 1))
    for _ in range(18):
        A.place(x, 0.16 * ping(r, r.uniform(1800, 4200), 1.2), r.uniform(0.2, TOTAL - 1.3))
    for t0 in np.arange(1.0, TOTAL - 1.3, 5.5):
        A.place(x, 0.3 * thump(r), t0 + r.uniform(-0.3, 0.3))
    out.append(("ambient_map04a_montage", "map04a_montage_bed", x, 3.2, 0.35))
    # F Windkanal
    r = A.rng_for("amb_map04a_tunnel")
    x = 0.55 * A.nrm(A.lp(A.brown(r, TOTAL), 120)) + 0.3 * A.nrm(A.bp(A.pink(r, TOTAL), 200, 900)) * (0.6 + 0.4 * A.smooth_rand(r, TOTAL, 0.25, 0, 1))
    out.append(("ambient_map04a_tunnel", "map04a_tunnel_bed", x, 2.4, 0.3))
    # G Prüfstand
    r = A.rng_for("amb_map04a_pits")
    n = A.N(TOTAL)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 0.21 * A.tax(n))
    imp = (np.sin(2 * np.pi * 55.0 * A.tax(n)) + 0.6 * np.sin(2 * np.pi * 110.3 * A.tax(n)) + 0.3 * np.sin(2 * np.pi * 277.0 * A.tax(n))) * trem
    x = 0.35 * A.nrm(imp) + 0.12 * A.nrm(A.bp(A.white(r, TOTAL), 3000, 9000)) * trem + 0.4 * mono(A.wind_bed(r, TOTAL, 0.6))
    out.append(("ambient_map04a_pits", "map04a_pits_bed", x, 1.8, 0.2))
    # H Halle
    r = A.rng_for("amb_map04a_hangar")
    n = A.N(TOTAL)
    x = 0.5 * A.nrm(A.lp(A.pink(r, TOTAL), 260)) * (0.8 + 0.2 * A.smooth_rand(r, TOTAL, 0.1, 0, 1))
    x += 0.16 * A.nrm(np.sin(2 * np.pi * 73.4 * A.tax(n)) + 0.5 * np.sin(2 * np.pi * 146.8 * A.tax(n)) + 0.3 * np.sin(2 * np.pi * 220.0 * A.tax(n)))
    for _ in range(6):
        A.place(x, 0.08 * A.nrm(A.bp(A.white(r, 0.4), 200, 1200)) * A.adsr(A.N(0.4), 0.05, 0.1, 0.5, 0.2), r.uniform(0.2, TOTAL - 0.5))
    out.append(("ambient_map04a_hangar", "map04a_hangar_bed", x, 5.0, 0.45))
    for key, rel, sig, decay, wet in out:
        rr = A.rng_for(key + "_rev")
        y = mono(A.reverb(A.to_stereo(sig), rr, decay, wet, 3000, 0.03, stereo=True))[:A.N(TOTAL)]
        A.emit(key, "sfx/ambience/" + rel, A.loopify(y, XF), -6.0, loop=True, bus="Ambience", volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)


def main():
    gen()
    A.write_manifest()
    print("gen_audio_map04a: wrote %d beds (%.1f s), merged into data/gravelight/audio.json" % (len(A.STATS), sum(d for _, d in A.STATS)))


if __name__ == "__main__":
    main()
