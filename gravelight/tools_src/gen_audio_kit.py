#!/usr/bin/env python3
"""M1911 attachment sounds (UPDATE_04 section 6, DECISIONS T-068), synthesized from scratch with numpy (no samples).

Writes 16-bit mono 44.1 kHz WAVs to gravelight/audio/sfx/placeholder/<key>_<n>.wav, which AudioDirector finds by
key without a bank entry (its placeholder fallback):
  kit_mag                 magazine seated and the catch clicking (Extended / Drum)
  kit_barrel              a barrel part threaded on: thread rasp, then a seating clank (Match / Compensator / can)
  kit_sight               drift-punch taps knocking a sight into its dovetail
  kit_grip                a stock latching onto the heel / grip screws snugged
  kit_ammo                a box of cartridges rattled and poured
  fire_m1911_suppressed   the OSS can: a muffled thump, the slide's clack louder than the shot
  kit_comp_blast          the compensator's sharp side blast, layered under the shot
  kit_drum_wind           the drum's winding key ratcheting in the reload
  bench_open              stepping up to the bench: a vise handle spun and a tool tray slid

Run from the repo root:  python gravelight/tools_src/gen_audio_kit.py   (needs numpy). Deterministic.
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "gravelight", "audio", "sfx", "placeholder")


def rng(name, i):
    return np.random.default_rng(sum(map(ord, name)) * 7919 + i)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a, d):
    """Attack a s, exponential decay with time constant d s."""
    x = np.arange(n) / SR
    e = np.exp(-x / max(d, 1e-4))
    att = np.clip(x / max(a, 1e-4), 0, 1)
    return e * att


def lp(x, k):
    """One-pole low-pass, k in 0..1 (smaller = darker)."""
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc)
        y[i] = acc
    return y


def hp(x, k):
    return x - lp(x, k)


def click(r, dur, tone, ring, bright=0.5):
    n = int(SR * dur)
    noise = r.standard_normal(n) * env(n, 0.0003, 0.004)
    body = np.sin(2 * np.pi * tone * t(dur)[:n]) * env(n, 0.0005, ring)
    body2 = np.sin(2 * np.pi * tone * 2.37 * t(dur)[:n]) * env(n, 0.0005, ring * 0.6) * 0.5
    return hp(noise, 0.3) * bright + body * 0.6 + body2


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def norm(x, peak=0.7):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name)


def kit_mag(i):
    r = rng("kit_mag", i)
    b = np.zeros(int(SR * 0.5))
    place(b, lp(r.standard_normal(int(SR * 0.12)), 0.08) * env(int(SR * 0.12), 0.02, 0.05) * 0.3, 0.0)   # slide in
    place(b, click(r, 0.12, 1900 + 150 * i, 0.03), 0.13)       # seats
    place(b, click(r, 0.08, 3100, 0.012, 0.8) * 0.6, 0.2)       # catch
    return norm(b)


def kit_barrel(i):
    r = rng("kit_barrel", i)
    b = np.zeros(int(SR * 0.9))
    for k in range(7):   # thread rasp, a quarter turn each
        n = int(SR * 0.05)
        g = hp(r.standard_normal(n), 0.5) * env(n, 0.004, 0.02) * (0.25 + 0.03 * k)
        place(b, g, 0.05 + k * 0.075 + r.uniform(-0.005, 0.005))
    place(b, click(r, 0.25, 820 + 60 * i, 0.09, 0.4), 0.62)     # seats with a ring
    return norm(b)


def kit_sight(i):
    r = rng("kit_sight", i)
    b = np.zeros(int(SR * 0.7))
    for k in range(3):   # brass punch on the dovetail
        place(b, click(r, 0.12, 2600 + 120 * k, 0.025, 0.6) * (0.7 + 0.15 * k), 0.04 + k * 0.17)
    return norm(b)


def kit_grip(i):
    r = rng("kit_grip", i)
    b = np.zeros(int(SR * 0.6))
    n = int(SR * 0.09)
    place(b, lp(r.standard_normal(n), 0.15) * env(n, 0.01, 0.03) * 0.5, 0.0)    # wood on steel
    place(b, click(r, 0.15, 520, 0.05, 0.7), 0.1)                               # latch
    place(b, click(r, 0.1, 1450, 0.02, 0.8) * 0.7, 0.24)                        # lock
    return norm(b)


def kit_ammo(i):
    r = rng("kit_ammo", i)
    b = np.zeros(int(SR * 0.9))
    for k in range(18):   # loose rounds, brass on brass
        place(b, click(r, 0.06, r.uniform(3200, 5200), r.uniform(0.006, 0.02), 0.5) * r.uniform(0.2, 0.6), 0.03 + r.uniform(0, 0.7))
    return norm(b)


def fire_suppressed(i):
    r = rng("fire_sup", i)
    n = int(SR * 0.45)
    thump = lp(r.standard_normal(n), 0.06) * env(n, 0.001, 0.035)
    puff = hp(r.standard_normal(n), 0.4) * env(n, 0.0005, 0.012) * 0.25
    low = np.sin(2 * np.pi * (90 + 8 * i) * t(0.45)[:n]) * env(n, 0.001, 0.05) * 0.6
    b = thump * 1.4 + puff + low
    place(b, click(r, 0.12, 2300 + 100 * i, 0.03, 0.9) * 0.9, 0.035)   # the slide, louder than the shot
    place(b, click(r, 0.08, 1700, 0.02, 0.7) * 0.6, 0.07)
    return norm(b, 0.6)


def comp_blast(i):
    r = rng("comp", i)
    n = int(SR * 0.35)
    crack = hp(r.standard_normal(n), 0.55) * env(n, 0.0002, 0.018)
    hiss = hp(r.standard_normal(n), 0.3) * env(n, 0.002, 0.06) * 0.35
    return norm(crack + hiss, 0.55)


def drum_wind(i):
    r = rng("drum", i)
    b = np.zeros(int(SR * 1.1))
    for k in range(9):   # the key ratchets round
        place(b, click(r, 0.05, 2900 + 40 * (k % 3), 0.01, 0.9) * (0.5 + 0.05 * k), 0.05 + k * 0.1)
    place(b, click(r, 0.2, 700, 0.06, 0.5), 0.98)   # spring set
    return norm(b)


def bench_open(i):
    r = rng("bench", i)
    b = np.zeros(int(SR * 0.9))
    n = int(SR * 0.4)
    place(b, lp(r.standard_normal(n), 0.05) * env(n, 0.05, 0.12) * 0.4, 0.0)   # tray slides
    for k in range(4):   # vise handle spun, its ends knocking
        place(b, click(r, 0.1, 1200 + 90 * k, 0.03, 0.5) * 0.6, 0.35 + k * 0.09)
    return norm(b)


def main():
    for name, fn, count in [("kit_mag", kit_mag, 2), ("kit_barrel", kit_barrel, 2), ("kit_sight", kit_sight, 2),
                            ("kit_grip", kit_grip, 2), ("kit_ammo", kit_ammo, 2), ("fire_m1911_suppressed", fire_suppressed, 3),
                            ("kit_comp_blast", comp_blast, 2), ("kit_drum_wind", drum_wind, 1), ("bench_open", bench_open, 1)]:
        for i in range(1, count + 1):
            write("%s_%d" % (name, i), fn(i))


if __name__ == "__main__":
    main()
