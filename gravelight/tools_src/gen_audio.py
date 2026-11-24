#!/usr/bin/env python3
"""GRAVELIGHT offline audio synthesizer (M6 audio pass).

Every sound here is synthesized from scratch with numpy/scipy: noise, oscillators, filters, envelopes,
formant banks, additive bells and an algorithmic (noise-IR) reverb. No samples, recordings or third-party
audio are used, and every melody is an original composition written for GRAVELIGHT (see the note
sequences in the music section). License: Owned (original, procedurally synthesized).

Output: 16-bit PCM WAV at 44.1 kHz.
  audio/sfx/weapons/   gunfire per weapon (3 variants), reload foley, wonder weapons, melee, lethal
  audio/sfx/zombies/   Ganger vocals (groan/sprint/attack/death), specials, bosses, impacts, steps
  audio/sfx/world/     barricades, doors, buy/deny, crate, perks, power-ups, explosions, bells, traps, power
  audio/sfx/player/    footsteps by surface, hurt, heartbeat, down, revive
  audio/sfx/ui/        menu clicks, rank up
  audio/sfx/ambience/  looping beds for Map 0 and Map 1
  audio/music/         round stingers (tiered), special-round stinger, game over, score layer, menu loop

Also merges the key -> files table into data/audio.json (existing tuning for a key is kept; only its
"files" list is refreshed, new keys get the defaults written here).

Run from the repo root:   python tools_src/gen_audio.py            (everything)
                           python tools_src/gen_audio.py zombie_    (only keys starting with a prefix)
Deterministic: every file draws from its own RNG seeded by (SEED, file name), so output is stable
regardless of generation order. Requires numpy + scipy (dev-only; pip install --user numpy scipy).
"""
from __future__ import annotations

import json
import os
import re
import struct
import sys
import zlib

import numpy as np
from scipy import signal

SR = 44100
SEED = 19450508
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # project root
GL = os.path.join(ROOT, "gravelight")                                                   # res://gravelight
AUDIO_JSON = os.path.join(ROOT, "data", "gravelight", "audio.json")

KEYS: dict[str, dict] = {}      # key -> {"files": [...], meta}
STATS: list[tuple[str, float]] = []
# key prefixes to (re)write, comma separated; empty = everything. Every key is still registered in the manifest.
ONLY: list[str] = [a for a in sys.argv[1].split(",") if a] if len(sys.argv) > 1 else []


# ═════════════════════════════════════════════════════════════════ DSP core

def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng((zlib.crc32(name.encode()) << 16) ^ SEED)


def N(sec: float) -> int:
    return max(1, int(round(sec * SR)))


def tax(n: int) -> np.ndarray:
    return np.arange(n) / SR


def zeros(sec: float, stereo: bool = False) -> np.ndarray:
    return np.zeros((N(sec), 2)) if stereo else np.zeros(N(sec))


def white(r, sec: float) -> np.ndarray:
    return r.uniform(-1.0, 1.0, N(sec))


def pink(r, sec: float) -> np.ndarray:
    n = N(sec)
    X = np.fft.rfft(r.standard_normal(n))
    f = np.arange(len(X), dtype=float)
    f[0] = 1.0
    X /= np.sqrt(f)
    y = np.fft.irfft(X, n)
    return y / (np.max(np.abs(y)) + 1e-12)


def brown(r, sec: float) -> np.ndarray:
    y = np.cumsum(r.standard_normal(N(sec)))
    y = hp(y, 18.0)
    return y / (np.max(np.abs(y)) + 1e-12)


def _sos(kind: str, freq, order: int):
    if isinstance(freq, (list, tuple)):
        freq = [min(max(10.0, f), SR * 0.49) for f in freq]
    else:
        freq = min(max(10.0, freq), SR * 0.49)
    return signal.butter(order, freq, btype=kind, fs=SR, output="sos")


def lp(x, f, order: int = 2):
    return signal.sosfilt(_sos("lowpass", f, order), x, axis=0)


def hp(x, f, order: int = 2):
    return signal.sosfilt(_sos("highpass", f, order), x, axis=0)


def bp(x, lo, hi, order: int = 2):
    lo = max(20.0, lo)
    hi = min(SR * 0.48, max(hi, lo * 1.05))
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x, axis=0)


def reson(x, f, q):
    """Resonant peak (2-pole) at f with quality q."""
    f = min(max(20.0, f), SR * 0.45)
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x, axis=0)


def nrm(x, peak: float = 1.0):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-12 else x


def sat(x, drive: float = 1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def expenv(n: int, tau: float) -> np.ndarray:
    return np.exp(-tax(n) / max(1e-5, tau))


def attack(n: int, a: float) -> np.ndarray:
    e = np.ones(n)
    k = min(n, N(a))
    e[:k] = np.linspace(0.0, 1.0, k) ** 1.5 if k > 1 else 1.0
    return e


def adsr(n: int, a: float, d: float, s: float, rel: float) -> np.ndarray:
    e = np.full(n, float(s))
    ka, kd, kr = N(a), N(d), N(rel)
    ka = min(ka, n)
    e[:ka] = np.linspace(0.0, 1.0, ka)
    kd2 = min(n, ka + kd)
    if kd2 > ka:
        e[ka:kd2] = np.linspace(1.0, s, kd2 - ka)
    kr = min(kr, n)
    e[n - kr:] *= np.linspace(1.0, 0.0, kr)
    return e


def fade(x, fin: float = 0.002, fout: float = 0.02):
    x = x.copy()
    a, b = min(len(x), N(fin)), min(len(x), N(fout))
    ramp_in = np.linspace(0.0, 1.0, a)
    ramp_out = np.linspace(1.0, 0.0, b) ** 2
    if x.ndim == 2:
        ramp_in, ramp_out = ramp_in[:, None], ramp_out[:, None]
    x[:a] *= ramp_in
    x[len(x) - b:] *= ramp_out
    return x


def place(dst, src, t0: float, gain: float = 1.0):
    i = int(round(t0 * SR))
    if i >= len(dst) or i + len(src) <= 0:
        return dst
    s0 = max(0, -i)
    i = max(0, i)
    n = min(len(src) - s0, len(dst) - i)
    seg = gain * src[s0:s0 + n]
    k = min(len(seg), N(0.004))                 # de-click wherever a source ends or is truncated
    if k > 1:
        ramp = np.linspace(1.0, 0.0, k)
        seg[-k:] *= ramp[:, None] if seg.ndim == 2 else ramp
    if dst.ndim == 2 and seg.ndim == 1:
        dst[i:i + n] += seg[:, None]
    else:
        dst[i:i + n] += seg
    return dst


def fit(x, sec: float):
    n = N(sec)
    if len(x) >= n:
        return x[:n]
    pad = np.zeros((n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad])


def smooth_rand(r, sec: float, rate: float, lo: float = -1.0, hi: float = 1.0) -> np.ndarray:
    """Smooth random curve: random points at `rate` Hz, cosine-interpolated."""
    n = N(sec)
    k = int(sec * rate) + 3
    pts = r.uniform(lo, hi, k)
    pos = np.arange(n) / SR * rate
    i = np.floor(pos).astype(int)
    fr = pos - i
    w = (1 - np.cos(np.pi * fr)) * 0.5
    return pts[i] * (1 - w) + pts[i + 1] * w


def phase_of(freq, n: int | None = None) -> np.ndarray:
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    return np.cumsum(freq) / SR


def sine(freq, sec: float | None = None, ph0: float = 0.0):
    n = N(sec) if sec is not None else len(freq)
    return np.sin(2 * np.pi * (phase_of(freq, n) + ph0))


def saw(freq, sec: float | None = None, ph0: float = 0.0):
    """Band-limited (polyBLEP) sawtooth."""
    n = N(sec) if sec is not None else len(freq)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    ph = (np.cumsum(f) / SR + ph0) % 1.0
    dt = np.clip(f / SR, 1e-6, 0.5)
    y = 2.0 * ph - 1.0
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] -= t + t - t * t - 1.0
    m = ph > 1.0 - dt
    t = (ph[m] - 1.0) / dt[m]
    y[m] -= t * t + t + t + 1.0
    return y


def square(freq, sec: float | None = None):
    return 0.5 * (saw(freq, sec) - saw(freq, sec, 0.5))


def smooth(x, sec: float):
    """Moving-average smoothing with edge padding (no start-up transient)."""
    k = max(1, N(sec))
    xp = np.concatenate([np.full(k, x[0]), x, np.full(k, x[-1])])
    return np.convolve(xp, np.ones(k) / k, mode="same")[k:-k]


def periodic(f: float, loop: float) -> float:
    """Rounds a frequency to a whole number of cycles per loop, so tonal loops have no seam."""
    return max(1.0, round(f * loop)) / loop


def place_wrap(dst, src, t0: float, gain: float = 1.0):
    """place() that wraps anything running past the end back to the start (for seamless loops)."""
    place(dst, src, t0, gain)
    place(dst, src, t0 - len(dst) / SR, gain)
    return dst


def pan(x, p: float):
    """Constant-power pan, p in [-1, 1]."""
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def to_stereo(x):
    return x if x.ndim == 2 else np.stack([x, x], axis=1)


def varispeed(x, rate):
    """Plays x back at a time-varying rate (array per output sample); stops at the end of x."""
    pos = np.cumsum(rate)
    pos = pos[pos < len(x) - 1]
    idx = np.arange(len(x))
    if x.ndim == 2:
        return np.stack([np.interp(pos, idx, x[:, c]) for c in range(2)], axis=1)
    return np.interp(pos, idx, x)


def make_ir(r, decay: float, damp: float, predelay: float, early: int = 6, bright: float = 0.35):
    n = N(predelay + decay * 1.15)
    t = tax(n)
    nz = r.standard_normal(n)
    lo = lp(nz, damp, 1) * np.exp(-6.9 * t / decay)
    hi = nz * np.exp(-6.9 * t / (decay * 0.35))
    ir = lo / (np.std(lo) + 1e-9) + bright * hi / (np.std(hi) + 1e-9)
    ir[:N(predelay)] = 0.0
    ir *= np.clip((t - predelay) / 0.004, 0.0, 1.0)
    for _ in range(early):
        k = N(predelay + r.uniform(0.002, 0.045))
        if k < n:
            ir[k] += r.choice([-1.0, 1.0]) * r.uniform(2.0, 6.0)
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb(x, r, decay: float = 1.0, wet: float = 0.25, damp: float = 5000.0, predelay: float = 0.012,
           stereo: bool = False, bright: float = 0.35):
    if stereo or x.ndim == 2:
        xs = to_stereo(x)
        outs = []
        for c in range(2):
            ir = make_ir(r, decay, damp, predelay, bright=bright)
            y = signal.fftconvolve(xs[:, c], ir)
            d = np.concatenate([xs[:, c], np.zeros(len(y) - len(xs))])
            outs.append(d + wet * y)
        return np.stack(outs, axis=1)
    ir = make_ir(r, decay, damp, predelay, bright=bright)
    y = signal.fftconvolve(x, ir)
    d = np.concatenate([x, np.zeros(len(y) - len(x))])
    return d + wet * y


def echo(x, delay: float, gain: float, lp_hz: float = 2500.0, taps: int = 2):
    out = np.concatenate([x, np.zeros(N(delay * taps + 0.01))])
    src = x
    for k in range(1, taps + 1):
        src = lp(src, lp_hz)
        place(out, src, delay * k, gain ** k)
    return out


def sweep_noise(r, sec: float, f0: float, f1: float, q: float = 4.0, bands: int = 14, curve=None):
    """Noise through a band whose centre glides from f0 to f1 (or follows `curve`, in Hz)."""
    n = N(sec)
    nz = r.uniform(-1.0, 1.0, n)
    if curve is None:
        curve = np.geomspace(f0, f1, n)
    lc = np.log(np.maximum(curve, 30.0))
    lo_f, hi_f = np.min(curve) * 0.8, np.max(curve) * 1.25
    centres = np.geomspace(max(40.0, lo_f), min(18000.0, hi_f), bands)
    out = np.zeros(n)
    width = (np.log(centres[-1]) - np.log(centres[0])) / max(1, bands - 1)
    for c in centres:
        bw = c / q
        band = bp(nz, c - bw * 0.5, c + bw * 0.5, 1)
        w = np.exp(-0.5 * ((lc - np.log(c)) / (width * 0.9)) ** 2)
        out += band * w
    return out / (np.max(np.abs(out)) + 1e-12)


def crackle(r, sec: float, rate: float, amp: float = 1.0, lo: float = 800.0, hi: float = 9000.0):
    """Sparse clicks (vinyl / fire / snow grain)."""
    n = N(sec)
    x = np.zeros(n)
    count = r.poisson(rate * sec)
    pos = r.integers(0, n, count)
    x[pos] = r.choice([-1.0, 1.0], count) * r.lognormal(0.0, 0.7, count)
    x = bp(x, lo, hi, 2)
    return amp * x / (np.max(np.abs(x)) + 1e-12)


def loopify(x, xfade: float):
    """Equal-power crossfade of the last `xfade` seconds onto the start, so the file loops seamlessly."""
    k = N(xfade)
    body = x[:-k].copy()
    tail = x[-k:]
    a = np.linspace(0.0, np.pi / 2, k)
    fi, fo = np.sin(a), np.cos(a)
    if x.ndim == 2:
        fi, fo = fi[:, None], fo[:, None]
    body[:k] = body[:k] * fi + tail * fo
    return body


def period(x, lo: float = 140.0, hi: float = 4800.0, low_keep: float = 0.45):
    """Band-limit like an old recording, then add back a little low-end weight."""
    return bp(x, lo, hi, 2) + low_keep * lp(x, 120.0, 2)


# ═════════════════════════════════════════════════════════════════ notes + instruments

NOTE_RE = re.compile(r"^([A-G])([#b]?)(-?\d)$")
SEMI = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name: str) -> float:
    m = NOTE_RE.match(name)
    s = SEMI[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    midi = 12 * (int(m.group(3)) + 1) + s
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def vib(r, n: int, rate: float = 5.2, depth: float = 0.004, delay: float = 0.25):
    t = tax(n)
    onset = np.clip((t - delay) / 0.4, 0.0, 1.0)
    return 1.0 + depth * onset * np.sin(2 * np.pi * rate * t + r.uniform(0, 6.28)) + 0.0015 * smooth_rand(r, n / SR, 3.0)


def strings(r, f: float, sec: float, a: float = 0.35, rel: float = 0.8, cutoff: float = 1800.0, voices: int = 3,
            detune: float = 0.006):
    n = N(sec + rel)
    y = np.zeros(n)
    for k in range(voices):
        fr = f * (1 + detune * (k - (voices - 1) / 2)) * vib(r, n, 5.0 + 0.4 * k, 0.0035)
        y += saw(fr, None, r.uniform())
    y = lp(y, cutoff, 2) + 0.2 * lp(y, cutoff * 2.2, 1)
    env = adsr(n, a, 0.2, 0.85, rel)
    return y * env / voices


def organ(r, f: float, sec: float, a: float = 0.06, rel: float = 0.5, bright: float = 1.0):
    n = N(sec + rel)
    bars = [(0.5, 0.35), (1, 1.0), (2, 0.55), (3, 0.3 * bright), (4, 0.25 * bright), (6, 0.12 * bright), (8, 0.08 * bright)]
    y = np.zeros(n)
    t = tax(n)
    trem = 1.0 + 0.06 * np.sin(2 * np.pi * 5.6 * t)
    for mult, amp in bars:
        y += amp * sine(f * mult * (1 + 0.0007 * r.standard_normal()), (n / SR), r.uniform())
    return y * trem * adsr(n, a, 0.1, 0.9, rel) / 2.4


def bell(r, f: float, sec: float, decay: float = 3.0, strike: float = 0.6, bright: float = 1.0, gate: float | None = None):
    """Church-bell partial series (hum, prime, tierce, quint, nominal, ...) with beating doublets."""
    n = N(sec)
    t = tax(n)
    parts = [(0.5, 0.55, 1.0), (1.0, 1.0, 0.75), (1.183, 0.6, 0.55), (1.506, 0.35, 0.45), (2.0, 0.65 * bright, 0.4),
             (2.514, 0.25 * bright, 0.28), (2.662, 0.22 * bright, 0.25), (3.011, 0.2 * bright, 0.2),
             (4.166, 0.12 * bright, 0.14), (5.433, 0.08 * bright, 0.1), (6.79, 0.05 * bright, 0.07)]
    y = np.zeros(n)
    for ratio, amp, dm in parts:
        fr = f * ratio
        if fr > SR * 0.45:
            continue
        beat = r.uniform(0.2, 1.4)
        y += amp * (np.sin(2 * np.pi * fr * t + r.uniform(0, 6.28)) + 0.4 * np.sin(2 * np.pi * (fr + beat) * t)) \
            * np.exp(-t / (decay * dm))
    y *= attack(n, 0.002) * np.clip((sec - t) / min(0.25, sec * 0.3), 0.0, 1.0)
    if strike > 0:
        k = white(r, 0.03)
        y[:len(k)] += strike * hp(k, 1500) * expenv(len(k), 0.005)
    if gate is not None:
        y *= np.where(t < gate, 1.0, np.exp(-(t - gate) / 0.06))
    return y / 2.5


def music_box(r, f: float, sec: float = 1.6, decay: float | None = None):
    n = N(sec)
    t = tax(n)
    d = decay if decay is not None else float(np.clip(1.6 * (600.0 / f) ** 0.5, 0.35, 2.0))
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / d)
    y += 0.10 * np.sin(2 * np.pi * 2.0 * f * t) * np.exp(-t / (d * 0.5))
    y += 0.16 * np.sin(2 * np.pi * 5.404 * f * t) * np.exp(-t / 0.05)
    y += 0.05 * np.sin(2 * np.pi * 8.93 * f * t) * np.exp(-t / 0.02)
    clk = hp(white(r, 0.004), 3000) * 0.15
    y[:len(clk)] += clk
    return y * attack(n, 0.0008)


def piano(r, f: float, sec: float, decay: float = 1.2, vel: float = 1.0):
    n = N(sec)
    t = tax(n)
    y = np.zeros(n)
    for h in range(1, 10):
        fh = f * h * np.sqrt(1 + 0.0004 * h * h)
        if fh > SR * 0.45:
            break
        y += (vel ** (h * 0.3)) / h ** 1.1 * np.sin(2 * np.pi * fh * t + r.uniform(0, 6.28)) * np.exp(-t / (decay / (1 + 0.35 * h)))
    hammer = lp(white(r, 0.02), 2500) * expenv(N(0.02), 0.004) * 0.1
    y[:len(hammer)] += hammer
    return y * attack(n, 0.001) * 0.6


def violin(r, f: float, sec: float, a: float = 0.08, rel: float = 0.15):
    n = N(sec + rel)
    fr = f * vib(r, n, 5.6, 0.006, 0.18)
    y = saw(fr, None, r.uniform())
    bow = bp(white(r, n / SR), 2000, 6000) * 0.04
    y = y + bow
    body = reson(y, 290, 3) * 0.6 + reson(y, 2800, 2.5) * 0.5 + reson(y, 1100, 2) * 0.3 + lp(y, 5500) * 0.25
    return body * adsr(n, a, 0.1, 0.9, rel)


def snare(r, vel: float = 1.0, tone: float = 185.0, sec: float = 0.3, snap: float = 0.8, muffle: float = 9000.0):
    n = N(sec)
    t = tax(n)
    head = (np.sin(2 * np.pi * tone * t) + 0.5 * np.sin(2 * np.pi * tone * 1.72 * t)) * np.exp(-t / 0.035)
    wires = bp(white(r, sec), 1800, muffle) * np.exp(-t / 0.075) * snap
    return vel * (0.7 * head + wires) * attack(n, 0.0006)


def tin_drum(r, vel: float = 1.0):
    """Herr Tamtam's toy tin drum: thin metal head, tinny rattle."""
    n = N(0.22)
    t = tax(n)
    head = (np.sin(2 * np.pi * 420 * t) + 0.6 * np.sin(2 * np.pi * 655 * t) + 0.35 * np.sin(2 * np.pi * 1090 * t)) * np.exp(-t / 0.028)
    tin = bp(white(r, 0.22), 3000, 9500) * np.exp(-t / 0.04)
    tin = reson(tin, 4300, 8) * 0.6 + tin
    return vel * (0.6 * head + 0.5 * tin / (np.max(np.abs(tin)) + 1e-9)) * attack(n, 0.0004)


def kick(r, vel: float = 1.0, f0: float = 110.0, f1: float = 42.0, tau: float = 0.25, sec: float = 0.9):
    n = N(sec)
    t = tax(n)
    f = f1 + (f0 - f1) * np.exp(-t / 0.03)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau)
    y += 0.2 * lp(white(r, sec), 900) * np.exp(-t / 0.015)
    return vel * y * attack(n, 0.001)


# ═════════════════════════════════════════════════════════════════ voice (formant) synthesis

VOWELS = {
    "a": [(780, 90, 1.0), (1150, 100, 0.55), (2600, 140, 0.22), (3400, 160, 0.1)],
    "o": [(480, 70, 1.0), (820, 80, 0.45), (2600, 130, 0.1), (3300, 150, 0.05)],
    "u": [(330, 60, 1.0), (720, 70, 0.25), (2450, 150, 0.05), (3200, 160, 0.03)],
    "e": [(460, 70, 1.0), (1800, 90, 0.35), (2550, 130, 0.22), (3400, 160, 0.1)],
    "i": [(290, 60, 1.0), (2150, 100, 0.3), (2950, 120, 0.22), (3700, 160, 0.1)],
    "ae": [(680, 90, 1.0), (1650, 110, 0.5), (2450, 140, 0.25), (3500, 170, 0.1)],
    "m": [(260, 60, 1.0), (1000, 200, 0.06), (2300, 200, 0.04)],
    "ah": [(700, 110, 1.0), (1200, 130, 0.5), (2500, 180, 0.3), (3500, 200, 0.18)],
}


def formant(x, vowel: str, shift: float = 1.0, bw_mult: float = 1.0):
    y = np.zeros_like(x)
    for f, bw, amp in VOWELS[vowel]:
        fc = f * shift
        y += amp * reson(x, fc, fc / (bw * bw_mult))
    return y


def voice(r, sec: float, f0, vowels: list[str], shift: float = 1.0, breath: float = 0.25, rasp: float = 0.3,
          fry: float = 0.0, drive: float = 1.5, morph=None, bw_mult: float = 1.3):
    """Glottal source (saw + pulsed noise + subharmonic fry) through a morphing formant bank."""
    n = N(sec)
    f0 = np.full(n, float(f0)) if np.isscalar(f0) else fit(np.asarray(f0, dtype=float), sec)
    ph = np.cumsum(f0) / SR
    src = saw(f0, None, r.uniform())
    src = lp(src, 3500, 1)
    pulse = (0.5 + 0.5 * np.sin(2 * np.pi * ph)) ** 3
    nz = white(r, sec)
    src = src + rasp * nz * pulse * 2.0 + breath * hp(nz, 400)
    if fry > 0:
        sub = 0.5 + 0.5 * np.sign(np.sin(np.pi * ph))          # f0/2 amplitude flip: growl / vocal fry
        src = src * (1.0 - fry + fry * sub)
    if morph is None:
        morph = np.linspace(0.0, 1.0, n)
    morph = np.clip(fit(np.asarray(morph, dtype=float), sec), 0.0, 1.0) * (len(vowels) - 1)
    out = np.zeros(n)
    for k, v in enumerate(vowels):
        w = np.clip(1.0 - np.abs(morph - k), 0.0, 1.0)
        if np.max(w) <= 0:
            continue
        out += formant(src, v, shift, bw_mult) * w
    out = hp(out, 70)
    return sat(nrm(out) * drive, 1.0)


def pitch_curve(r, sec: float, base: float, contour: list[tuple[float, float]], wobble: float = 0.05,
                vib_rate: float = 6.0, vib_depth: float = 0.02, jitter: float = 0.01):
    """contour: [(time_frac, mult), ...]; adds smooth drift, vibrato and jitter."""
    n = N(sec)
    tf = np.linspace(0.0, 1.0, n)
    xs = [c[0] for c in contour]
    ys = [c[1] for c in contour]
    c = np.interp(tf, xs, ys)
    drift = 1.0 + wobble * smooth_rand(r, sec, 3.5)
    vibr = 1.0 + vib_depth * np.sin(2 * np.pi * vib_rate * tax(n) + r.uniform(0, 6.28))
    jit = 1.0 + jitter * lp(r.standard_normal(n), 40) * 4
    return base * c * drift * vibr * jit


# ═════════════════════════════════════════════════════════════════ output

def write_wav(path: str, x, loop: bool = False):
    x = np.asarray(x, dtype=float)
    ch = 2 if x.ndim == 2 else 1
    r = np.random.default_rng(zlib.crc32(path.encode()))
    dither = (r.uniform(-0.5, 0.5, x.shape) + r.uniform(-0.5, 0.5, x.shape)) / 32768.0
    pcm = np.clip(np.round((x + dither) * 32767.0), -32768, 32767).astype("<i2")
    data = pcm.tobytes()
    frames = len(x)
    fmt = struct.pack("<HHIIHH", 1, ch, SR, SR * 2 * ch, 2 * ch, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if len(data) % 2:
        chunks += b"\x00"
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def emit(key: str, rel: str, x, peak_db: float = -1.0, loop: bool = False, **meta):
    """Normalises, writes audio/<rel>.wav and registers it under `key` in the manifest."""
    entry = KEYS.setdefault(key, {"files": []})
    for k, v in meta.items():
        entry[k] = v
    if loop:
        entry["loop"] = True
    res = "res://gravelight/audio/" + rel + ".wav"
    entry["files"].append(res)
    if ONLY and not any(key.startswith(o) for o in ONLY):
        return
    x = np.nan_to_num(np.asarray(x, dtype=float))
    x = x - np.mean(x, axis=0)
    x = nrm(x, 10 ** (peak_db / 20.0))
    if not loop:
        x = fade(x, 0.0005, 0.01)
    write_wav(os.path.join(GL, "audio", rel + ".wav"), x, loop)
    STATS.append((rel, len(x) / SR))


def alias(key: str, of: str, **meta):
    """A legacy/class key that plays another key's files (keeps old callers working)."""
    entry = KEYS.setdefault(key, {"files": []})
    entry["files"] = list(KEYS[of]["files"])
    base = {k: v for k, v in KEYS[of].items() if k != "files"}
    base.update(meta)
    for k, v in base.items():
        entry[k] = v


def variants(count: int):
    return range(1, count + 1)


# ═════════════════════════════════════════════════════════════════ WEAPONS

# Per-weapon gunshot character. crack = supersonic snap band, thump = muzzle pressure, mech = action noise,
# rumble/tail = environment. Values picked by ear-from-numbers: bigger cartridges -> lower thump, longer tail.
GUNS = {
    #            crack_f bw  ctau   thump0 thump1 ttau  tgain rumble rtau  mech_f mgain mdel  decay wet  dur  drive
    "m1911":     (2100, 2.4, 0.011, 170, 72, 0.045, 0.75, 0.22, 0.12, 3300, 0.30, 0.028, 0.70, 0.17, 0.75, 2.2),
    "kar98k":    (3600, 3.0, 0.019, 125, 46, 0.090, 0.95, 0.45, 0.34, 0.00, 0.00, 0.000, 1.70, 0.30, 1.90, 2.6),
    "springfield": (4100, 3.0, 0.017, 130, 48, 0.085, 0.90, 0.42, 0.32, 0.00, 0.00, 0.000, 1.60, 0.29, 1.80, 2.6),
    "m1_garand": (3100, 2.8, 0.018, 130, 50, 0.080, 0.90, 0.40, 0.30, 2700, 0.28, 0.040, 1.35, 0.26, 1.50, 2.5),
    "gewehr43":  (3350, 2.8, 0.017, 135, 52, 0.075, 0.85, 0.38, 0.28, 3000, 0.30, 0.036, 1.30, 0.26, 1.45, 2.5),
    "m1_carbine": (3800, 2.6, 0.012, 175, 66, 0.050, 0.62, 0.26, 0.16, 3500, 0.26, 0.030, 0.90, 0.20, 1.00, 2.2),
    "mp40":      (2600, 2.4, 0.009, 185, 80, 0.035, 0.60, 0.20, 0.10, 2200, 0.38, 0.014, 0.60, 0.14, 0.48, 2.1),
    "thompson":  (2000, 2.3, 0.011, 150, 64, 0.045, 0.78, 0.24, 0.12, 1900, 0.42, 0.016, 0.65, 0.15, 0.52, 2.3),
    "type100":   (2900, 2.4, 0.008, 205, 92, 0.030, 0.48, 0.18, 0.09, 2500, 0.34, 0.012, 0.55, 0.13, 0.42, 2.0),
    "ppsh41":    (3400, 2.5, 0.006, 195, 86, 0.026, 0.52, 0.18, 0.08, 2650, 0.28, 0.010, 0.50, 0.12, 0.36, 2.1),
    "stg44":     (3100, 2.7, 0.012, 140, 58, 0.055, 0.78, 0.30, 0.18, 2400, 0.32, 0.020, 0.90, 0.20, 0.72, 2.4),
    "bar":       (3000, 2.8, 0.016, 120, 50, 0.070, 0.92, 0.40, 0.25, 1700, 0.45, 0.022, 1.10, 0.24, 0.90, 2.6),
    "mg42":      (3600, 2.8, 0.007, 130, 60, 0.030, 0.72, 0.28, 0.12, 2000, 0.30, 0.008, 0.70, 0.15, 0.40, 2.5),
    "m1919":     (3000, 2.7, 0.012, 125, 52, 0.050, 0.86, 0.34, 0.18, 1500, 0.48, 0.015, 0.90, 0.20, 0.62, 2.5),
    "trench_gun": (1500, 4.0, 0.030, 110, 42, 0.120, 1.00, 0.55, 0.40, 0.00, 0.00, 0.000, 1.50, 0.30, 1.60, 2.8),
    "sawed_off": (1300, 4.2, 0.035, 100, 40, 0.140, 1.10, 0.62, 0.45, 0.00, 0.00, 0.000, 1.40, 0.30, 1.60, 3.0),
    "ptrs41":    (2400, 3.2, 0.030, 80, 32, 0.200, 1.20, 0.70, 0.60, 1300, 0.30, 0.050, 2.40, 0.35, 2.60, 3.0),
    # T-248: the four new guns (full-power 7.92 / 7.62R / .303 rifle rounds, and the Sten's 9 mm)
    "fg42":      (3500, 2.9, 0.016, 128, 48, 0.070, 0.90, 0.40, 0.26, 2300, 0.34, 0.018, 1.10, 0.24, 0.90, 2.6),
    "mosin_nagant": (3400, 3.0, 0.020, 120, 44, 0.095, 1.00, 0.48, 0.36, 0.00, 0.00, 0.000, 1.75, 0.31, 1.95, 2.7),
    "bren":      (3100, 2.8, 0.015, 122, 50, 0.065, 0.90, 0.38, 0.22, 1800, 0.42, 0.020, 1.00, 0.22, 0.80, 2.5),
    "sten":      (2500, 2.3, 0.010, 180, 76, 0.038, 0.62, 0.21, 0.10, 2000, 0.46, 0.015, 0.62, 0.14, 0.50, 2.1),
}
SHOTGUNS = {"trench_gun", "sawed_off"}


def gunshot(r, p, wid: str):
    (cf, cbw, ctau, th0, th1, ttau, tgain, rg, rtau, mf, mg, mdel, decay, wet, dur, drive) = p
    v = r.uniform(0.93, 1.07)
    n = N(dur)
    t = tax(n)
    nz = white(r, dur)
    click = nrm(hp(nz, 3000, 2) * np.exp(-t / 0.0012))
    if wid in SHOTGUNS:          # pellet column / wad: several transients smeared over a few ms
        for k in range(4):
            place(click, nrm(hp(white(r, 0.004), 2500)) * expenv(N(0.004), 0.0008), r.uniform(0.0005, 0.004), 0.6)
    crack = nrm(bp(nz, cf * v / cbw, cf * v * cbw, 2) * np.exp(-t / ctau))
    body = nrm(lp(white(r, dur), 1600 * v, 2) * np.exp(-t / (ctau * 2.6)))
    f = th1 * v + (th0 * v - th1 * v) * np.exp(-t / 0.018)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / ttau) * (1 - np.exp(-t / 0.0007))
    rumble = nrm(lp(white(r, dur), 320, 2) * np.exp(-t / rtau) * attack(n, 0.006))
    x = 0.9 * click + 0.95 * crack + 0.55 * body + tgain * thump + rg * rumble
    if mg > 0:                    # action cycling: two metal clacks (bolt back, bolt home)
        m = np.zeros(n)
        for k, (dt, fm) in enumerate([(mdel, mf), (mdel * 2.2, mf * 0.78)]):
            hit = white(r, 0.03) * expenv(N(0.03), 0.003)
            hit = reson(hit, fm * v, 18) + 0.6 * reson(hit, fm * 1.61 * v, 22) + 0.3 * hp(hit, 5000)
            place(m, nrm(hit), dt, 1.0 if k == 0 else 0.7)
        x += mg * m
    x = sat(x * drive * 0.6, 1.0)
    x = reverb(x, r, decay=decay, wet=wet, damp=4200, predelay=0.018, bright=0.2)
    if decay > 1.2:                # outdoor slap-back from a distant tree line / building
        x = echo(x, r.uniform(0.17, 0.26), 0.16, 1800, 2)
    return fit(x, dur)


def launcher(r):
    dur = 2.4
    n = N(dur)
    t = tax(n)
    ign = nrm(bp(white(r, dur), 1200, 6000) * np.exp(-t / 0.02))
    f = 40 + 55 * np.exp(-t / 0.03)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    whoosh = sweep_noise(r, 1.2, 3600, 500, q=3.0) * adsr(N(1.2), 0.02, 0.2, 0.6, 0.8)
    roar = nrm(lp(brown(r, 1.2), 500)) * (1 + 0.5 * np.sin(2 * np.pi * 31 * tax(N(1.2)))) * adsr(N(1.2), 0.04, 0.3, 0.5, 0.7)
    blast = nrm(lp(white(r, dur), 2200) * np.exp(-t / 0.14))
    x = 0.8 * ign + 1.0 * thump + 0.6 * blast
    place(x, 0.7 * whoosh + 0.5 * roar, 0.01)
    x = sat(x * 1.4, 1.0)
    return fit(reverb(x, r, 1.9, 0.32, 3500, 0.02), dur)


def flame(r):
    dur = 0.62
    n = N(dur)
    turb = 0.55 + 0.45 * smooth_rand(r, dur, 22.0, 0, 1)
    roar = nrm(lp(brown(r, dur), 900, 2)) * turb
    hiss = nrm(bp(white(r, dur), 1400, 5200)) * (0.6 + 0.4 * smooth_rand(r, dur, 35, 0, 1))
    pops = crackle(r, dur, 40, 1.0, 600, 5000)
    x = 0.9 * roar + 0.35 * hiss + 0.35 * pops
    return x * adsr(n, 0.05, 0.1, 0.9, 0.18)


def ashlight_fire(r):
    dur = 1.6
    n = N(dur)
    t = tax(n)
    v = r.uniform(0.95, 1.05)
    f = 480 * v + 2300 * v * np.exp(-t / 0.07)
    mod = np.sin(2 * np.pi * np.cumsum(f * 1.414) / SR) * (2.0 * np.exp(-t / 0.15))
    chirp = np.sin(2 * np.pi * np.cumsum(f) / SR + mod) * np.exp(-t / 0.22)
    shim = np.zeros(n)
    for fr, d in [(1870, 0.9), (2913, 0.7), (4471, 0.5), (6120, 0.35)]:
        shim += np.sin(2 * np.pi * fr * v * t + r.uniform(0, 6)) * np.exp(-t / d)
    shim *= 1 + 0.5 * np.sin(2 * np.pi * 11 * t)
    wh = sweep_noise(r, 0.45, 4500, 700, 3) * adsr(N(0.45), 0.005, 0.1, 0.5, 0.3)
    th = np.sin(2 * np.pi * np.cumsum(50 + 70 * np.exp(-t / 0.02)) / SR) * np.exp(-t / 0.08)
    x = 0.9 * chirp + 0.25 * shim / 4 + 0.6 * th
    place(x, wh, 0.0, 0.5)
    return reverb(sat(x, 1.4), r, 1.5, 0.32, 7000, 0.015, bright=0.5)[:n]


def ashlight_charge(r):
    dur = 1.2
    n = N(dur)
    t = tax(n)
    f = 300 * 2 ** (t / dur * 2.5)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / dur) ** 1.5
    x += 0.4 * sweep_noise(r, dur, 500, 6000, 6) * (t / dur) ** 2
    x += 0.2 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR) * (t / dur)
    return fade(x, 0.01, 0.03)


def ashlight_splash(r):
    dur = 0.9
    n = N(dur)
    t = tax(n)
    sizzle = nrm(bp(white(r, dur), 2500, 9000)) * (0.5 + 0.5 * smooth_rand(r, dur, 60, 0, 1)) * np.exp(-t / 0.3)
    glass = np.zeros(n)
    for k in range(7):
        g = reson(white(r, 0.08) * expenv(N(0.08), 0.004), r.uniform(3000, 8000), 40)
        place(glass, nrm(g) * expenv(N(0.08), 0.05), r.uniform(0, 0.12), r.uniform(0.3, 0.8))
    thud = kick(r, 0.8, 140, 55, 0.08, dur)
    return 0.6 * sizzle + 0.4 * glass + 0.7 * thud


def mech_click(r, f: float, sec: float = 0.05, tau: float = 0.004, q: float = 16):
    hit = white(r, sec) * expenv(N(sec), tau * 0.6)
    y = reson(hit, f, q) + 0.6 * reson(hit, f * 1.73, q * 1.2) + 0.35 * reson(hit, f * 2.6, q) + 0.25 * hp(hit, 4000)
    return nrm(y) * expenv(N(sec), tau * 3)


def scrape(r, sec: float, lo: float = 900, hi: float = 4500, rough: float = 40.0):
    nz = bp(white(r, sec), lo, hi)
    am = 0.4 + 0.6 * np.abs(smooth_rand(r, sec, rough))
    return nrm(nz * am) * adsr(N(sec), sec * 0.2, 0.0, 1.0, sec * 0.5)


def thunk(r, f: float = 220, tau: float = 0.03, sec: float = 0.12):
    n = N(sec)
    t = tax(n)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / tau) + 0.5 * nrm(lp(white(r, sec), f * 6)) * np.exp(-t / (tau * 0.5))
    return y


def foley(name: str, r):
    v = r.uniform(0.95, 1.05)
    if name == "mag_out":
        x = zeros(0.35)
        place(x, mech_click(r, 2600 * v), 0.0, 0.8)           # release button
        place(x, scrape(r, 0.12, 1200, 5000), 0.03, 0.35)       # mag sliding out
        place(x, mech_click(r, 1700 * v, 0.06), 0.14, 0.6)     # mag clears the well
        place(x, thunk(r, 300, 0.02), 0.15, 0.3)
        return x
    if name == "mag_in":
        x = zeros(0.4)
        place(x, scrape(r, 0.1, 900, 4000), 0.0, 0.3)
        place(x, thunk(r, 260 * v, 0.03), 0.1, 0.9)
        place(x, mech_click(r, 2100 * v, 0.07), 0.1, 1.0)      # seat
        place(x, mech_click(r, 3400 * v), 0.13, 0.6)           # latch
        return x
    if name == "bolt_back":
        x = zeros(0.3)
        place(x, mech_click(r, 1900 * v), 0.0, 0.8)            # handle lift
        place(x, scrape(r, 0.13, 1500, 6000, 70), 0.025, 0.55)
        place(x, mech_click(r, 1400 * v, 0.06), 0.15, 1.0)     # stop
        return x
    if name == "bolt_fwd":
        x = zeros(0.3)
        place(x, scrape(r, 0.11, 1300, 5500, 70), 0.0, 0.5)
        place(x, mech_click(r, 1600 * v, 0.06), 0.11, 1.0)
        place(x, mech_click(r, 2400 * v), 0.17, 0.7)           # handle down
        return x
    if name == "bolt_cycle":
        x = zeros(0.6)
        place(x, foley("bolt_back", r), 0.0)
        place(x, foley("bolt_fwd", r), 0.24)
        return x
    if name == "clip_ping":                      # en-bloc clip ejecting: a bright spring-steel ring
        dur = 0.9
        n = N(dur)
        t = tax(n)
        y = np.zeros(n)
        for fr, a, d in [(2870, 1.0, 0.32), (4950, 0.6, 0.22), (7310, 0.35, 0.14), (9840, 0.15, 0.08)]:
            y += a * np.sin(2 * np.pi * fr * v * t + r.uniform(0, 6)) * np.exp(-t / d)
        y *= attack(n, 0.0005) * np.clip((dur - t) / 0.15, 0, 1)
        x = zeros(dur + 0.01)
        place(x, mech_click(r, 2200), 0.0, 0.7)
        place(x, y, 0.004, 0.9)
        place(x, mech_click(r, 3600, 0.04), r.uniform(0.35, 0.5), 0.25)   # clip lands
        return x
    if name == "stripper_clip":                  # rounds stripped down into the magazine
        x = zeros(0.6)
        place(x, mech_click(r, 2000), 0.0, 0.8)
        for k in range(5):
            place(x, mech_click(r, r.uniform(2300, 3000), 0.03), 0.07 + k * 0.05, 0.5)
        place(x, scrape(r, 0.25, 1500, 5000, 90), 0.06, 0.3)
        place(x, mech_click(r, 3300, 0.05), 0.38, 0.7)         # clip flicked away
        return x
    if name == "shell_insert":
        x = zeros(0.25)
        place(x, scrape(r, 0.06, 700, 3000), 0.0, 0.4)
        place(x, thunk(r, 420 * v, 0.018), 0.05, 0.7)
        place(x, mech_click(r, 2600 * v, 0.04), 0.055, 0.6)
        return x
    if name == "pump":
        x = zeros(0.5)
        place(x, scrape(r, 0.08, 600, 3500), 0.0, 0.5)
        place(x, mech_click(r, 1200 * v, 0.07, 0.006), 0.07, 1.0)
        place(x, thunk(r, 180, 0.03), 0.07, 0.6)
        place(x, scrape(r, 0.08, 600, 3500), 0.18, 0.5)
        place(x, mech_click(r, 1500 * v, 0.07, 0.006), 0.26, 1.0)
        place(x, thunk(r, 200, 0.03), 0.26, 0.5)
        return x
    if name == "cover_open":
        x = zeros(0.45)
        place(x, mech_click(r, 1800 * v), 0.0, 0.8)
        creak = bp(saw(np.full(N(0.18), 70.0) * (1 + 0.3 * smooth_rand(r, 0.18, 30))), 900, 3500)
        place(x, nrm(creak) * adsr(N(0.18), 0.03, 0, 1, 0.08), 0.03, 0.35)
        place(x, mech_click(r, 1200 * v, 0.07, 0.006), 0.22, 0.9)
        return x
    if name == "cover_close":
        x = zeros(0.35)
        place(x, thunk(r, 240, 0.03), 0.0, 0.7)
        place(x, mech_click(r, 1400 * v, 0.07, 0.007), 0.0, 1.0)
        place(x, mech_click(r, 3000 * v), 0.04, 0.6)
        return x
    if name == "belt":
        x = zeros(0.55)
        for k in range(14):
            place(x, mech_click(r, r.uniform(2800, 5200), 0.03, 0.002), r.uniform(0.0, 0.42), r.uniform(0.2, 0.6))
        place(x, scrape(r, 0.4, 2000, 7000, 120), 0.0, 0.25)
        return x
    if name == "drum_in":
        x = zeros(0.5)
        place(x, scrape(r, 0.12, 700, 3500), 0.0, 0.4)
        place(x, thunk(r, 150 * v, 0.05, 0.2), 0.12, 1.0)
        place(x, mech_click(r, 1100 * v, 0.08, 0.008), 0.12, 0.9)
        for k in range(5):
            place(x, mech_click(r, r.uniform(3000, 5000), 0.02), 0.16 + k * 0.03, 0.2)
        return x
    if name == "rocket_load":
        x = zeros(0.8)
        place(x, scrape(r, 0.4, 400, 2500, 25), 0.0, 0.6)
        place(x, thunk(r, 120, 0.06, 0.25), 0.4, 1.0)
        place(x, mech_click(r, 900, 0.1, 0.01), 0.41, 0.8)
        place(x, mech_click(r, 2500), 0.55, 0.6)
        return x
    if name == "raise":                          # weapon swap: cloth + sling swivel + a light tick
        x = zeros(0.4)
        cloth = nrm(bp(white(r, 0.25), 300, 3000)) * adsr(N(0.25), 0.08, 0, 1, 0.12) * (0.6 + 0.4 * smooth_rand(r, 0.25, 25, 0, 1))
        place(x, cloth, 0.0, 0.5)
        place(x, mech_click(r, 3200 * v, 0.04), 0.2, 0.5)
        place(x, mech_click(r, 4100 * v, 0.03), 0.24, 0.3)
        return x
    if name == "dry":
        x = zeros(0.2)
        place(x, mech_click(r, 2700 * v, 0.06, 0.005), 0.0, 1.0)
        place(x, mech_click(r, 5200 * v, 0.03), 0.002, 0.4)
        return x
    raise KeyError(name)


def gen_weapons():
    for wid, p in GUNS.items():
        for i in variants(3):
            r = rng_for(f"fire_{wid}_{i}")
            emit(f"fire_{wid}", f"sfx/weapons/fire_{wid}_{i:02d}", gunshot(r, p, wid), -0.5,
                 bus="SFX", volume_db=-1.0, pitch=[0.97, 1.03], max_voices=6, attenuation="weapon", vol_jitter_db=0.8)
    for i in variants(3):
        emit("fire_panzerschreck", f"sfx/weapons/fire_panzerschreck_{i:02d}", launcher(rng_for(f"pz{i}")), -0.5,
             bus="SFX", volume_db=0.0, pitch=[0.96, 1.04], max_voices=3, attenuation="loud")
        emit("fire_flamethrower", f"sfx/weapons/fire_flamethrower_{i:02d}", flame(rng_for(f"fl{i}")), -1.0,
             bus="SFX", volume_db=-4.0, pitch=[0.9, 1.1], max_voices=3, attenuation="weapon")
        emit("fire_ashlight", f"sfx/weapons/fire_ashlight_{i:02d}", ashlight_fire(rng_for(f"ash{i}")), -1.0,
             bus="SFX", volume_db=-1.0, pitch=[0.96, 1.04], max_voices=4, attenuation="weapon")
    emit("ashlight_charge", "sfx/weapons/ashlight_charge_01", ashlight_charge(rng_for("ashc")), -3.0,
         bus="SFX", volume_db=-6.0, pitch=[1.0, 1.0], max_voices=2)
    for i in variants(2):
        emit("ashlight_splash", f"sfx/weapons/ashlight_splash_{i:02d}", ashlight_splash(rng_for(f"ashs{i}")), -2.0,
             bus="SFX", volume_db=-3.0, max_voices=4, attenuation="world")
    # reload / handling foley
    counts = {"mag_out": 3, "mag_in": 3, "bolt_back": 2, "bolt_fwd": 2, "bolt_cycle": 3, "clip_ping": 3,
              "stripper_clip": 2, "shell_insert": 4, "pump": 3, "cover_open": 2, "cover_close": 2, "belt": 2,
              "drum_in": 2, "rocket_load": 2, "raise": 3, "dry": 3}
    for name, cnt in counts.items():
        key = "gun_dry" if name == "dry" else ("weapon_raise" if name == "raise" else f"reload_{name}")
        for i in variants(cnt):
            r = rng_for(f"{name}{i}")
            x = foley(name, r)
            x = reverb(x, r, 0.25, 0.08, 6000, 0.004)
            emit(key, f"sfx/weapons/foley/{name}_{i:02d}", x, -1.0, bus="SFX", volume_db=-4.0,
                 pitch=[0.97, 1.03], max_voices=3, attenuation="quiet", vol_jitter_db=1.0)
    # the "last bullet" tell (Update 02 §1): a light, hollow follower click as the final round leaves the magazine
    for i in variants(2):
        r = rng_for(f"last_round{i}")
        x = zeros(0.18)
        place(x, mech_click(r, r.uniform(3300, 3700), 0.05, 0.004, 22), 0.0, 0.9)
        place(x, mech_click(r, r.uniform(1750, 1950), 0.08, 0.008, 30), 0.004, 0.5)
        x = reverb(x, r, 0.2, 0.06, 7000, 0.003)
        emit("last_round_click", f"sfx/weapons/foley/last_round_{i:02d}", x, -2.0, bus="SFX", volume_db=-6.0,
             pitch=[0.98, 1.02], max_voices=2, attenuation="quiet")
    gen_melee_lethal()
    gen_wonders()


def gen_melee_lethal():
    for i in variants(4):
        r = rng_for(f"swing{i}")
        dur = 0.35
        curve = 500 + 2600 * np.sin(np.pi * np.clip(tax(N(dur)) / 0.26, 0, 1)) ** 2
        x = sweep_noise(r, dur, 500, 3000, 3.5, curve=curve) * np.sin(np.pi * np.clip(tax(N(dur)) / 0.3, 0, 1)) ** 1.5
        emit("knife_swing", f"sfx/weapons/knife_swing_{i:02d}", x, -2.0, bus="SFX", volume_db=-3.0, max_voices=2, attenuation="quiet")
    for i in variants(4):
        r = rng_for(f"khit{i}")
        x = zeros(0.4)
        place(x, kick(r, 1.0, 160, 70, 0.05, 0.3), 0.0, 0.9)
        squelch = nrm(lp(white(r, 0.15), 1800)) * expenv(N(0.15), 0.04) * (0.5 + 0.5 * smooth_rand(r, 0.15, 90, 0, 1))
        place(x, squelch, 0.0, 0.7)
        place(x, scrape(r, 0.08, 2500, 8000, 200), 0.005, 0.35)
        emit("knife_hit", f"sfx/weapons/knife_hit_{i:02d}", x, -1.0, bus="SFX", volume_db=-2.0, max_voices=3, attenuation="world")
    for i in variants(2):
        r = rng_for(f"pin{i}")
        x = zeros(0.6)
        place(x, foley("clip_ping", r)[:N(0.3)] * np.linspace(1, 0.2, N(0.3)), 0.0, 0.4)
        place(x, mech_click(r, 3800), 0.0, 0.8)
        place(x, mech_click(r, 2300, 0.06), 0.22, 0.7)          # spoon flick
        emit("grenade_pin", f"sfx/weapons/grenade_pin_{i:02d}", x, -2.0, bus="SFX", volume_db=-3.0, max_voices=2, attenuation="quiet")
    for i in variants(3):
        r = rng_for(f"hm{i}")
        x = zeros(0.12)
        place(x, mech_click(r, r.uniform(3800, 4400), 0.05, 0.003), 0.0)
        # T-128: a little body under the tick (a muffled knock), so a hit reads as landing, not just a click
        place(x, kick(r, 1.0, r.uniform(240, 280), 150, 0.014, 0.08), 0.0, 0.45)
        emit("hitmarker", f"sfx/weapons/hitmarker_{i:02d}", x, -3.0, bus="SFX", volume_db=-2.0, max_voices=3, pitch=[0.98, 1.02])
    for i in variants(3):
        # T-136: the bank's till: the counter bell's ding, the drawer's click and a few coins settling in the tray
        r = rng_for(f"till{i}")
        dur = 0.75
        x = zeros(dur)
        place(x, bell(r, r.uniform(2350, 2550), 0.7, decay=5.0, strike=0.5, bright=0.8), 0.0, 0.5)
        place(x, mech_click(r, r.uniform(1600, 1900), 0.05, 0.004), 0.12, 0.6)
        for k in range(4):
            place(x, mech_click(r, r.uniform(5200, 7000), 0.03, 0.002), 0.18 + k * r.uniform(0.04, 0.07), r.uniform(0.25, 0.45))
        emit("bank_till", f"sfx/ui/bank_till_{i:02d}", x, -3.0, bus="SFX", volume_db=-4.0, max_voices=2, pitch=[0.98, 1.02])
    for i in variants(3):
        # T-128: the kill confirm: a deep, short thock (felt more than heard), a bright double tick on top and a
        # breath of air after, distinct from the hit's tick and the headshot's crack
        r = rng_for(f"kc{i}")
        dur = 0.32
        x = zeros(dur)
        place(x, kick(r, 1.0, r.uniform(150, 175), 62, 0.055, 0.22), 0.0, 1.0)
        place(x, mech_click(r, r.uniform(3000, 3400), 0.06, 0.004), 0.0, 0.7)
        place(x, mech_click(r, r.uniform(4600, 5200), 0.04, 0.003), 0.028, 0.45)
        t = tax(N(0.2))
        air = nrm(bp(white(r, 0.2), 1400, 5200)) * np.exp(-t / 0.05)
        place(x, air, 0.01, 0.18)
        emit("kill_confirm", f"sfx/weapons/kill_confirm_{i:02d}", x, -2.0, bus="SFX", volume_db=-1.0, max_voices=2, pitch=[0.97, 1.03])
    for i in variants(3):
        r = rng_for(f"hs{i}")
        dur = 0.5
        n = N(dur)
        t = tax(n)
        crack = nrm(hp(white(r, dur), 2500) * np.exp(-t / 0.006))
        tink = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, a, d in [(2650, 1, 0.12), (4120, 0.6, 0.08), (6800, 0.3, 0.05)])
        bone = kick(r, 0.6, 300, 120, 0.03, dur)
        emit("headshot", f"sfx/weapons/headshot_{i:02d}", 0.7 * crack + 0.6 * tink + 0.6 * bone, -1.5,
             bus="SFX", volume_db=-1.0, max_voices=2, pitch=[0.98, 1.02])
    r = rng_for("nglayer")
    dur = 0.5
    t = tax(N(dur))
    glass = sum(np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * np.exp(-t / d) for f, d in [(1320, 0.3), (1987, 0.25), (3150, 0.18), (4490, 0.12)])
    glass *= 1 + 0.4 * np.sin(2 * np.pi * 17 * t)
    emit("nachtglas_layer", "sfx/weapons/nachtglas_layer_01", reverb(glass * attack(N(dur), 0.004), r, 0.8, 0.3, 8000)[:N(0.8)], -3.0,
         bus="SFX", volume_db=-8.0, pitch=[0.95, 1.05], max_voices=3)
    for i in variants(2):
        r = rng_for(f"ovh{i}")
        dur = 1.0
        hiss = nrm(bp(white(r, dur), 2500, 9000)) * adsr(N(dur), 0.01, 0.2, 0.6, 0.6)
        x = hiss + 0.5 * mech_click(r, 2000, dur)
        emit("weapon_overheat", f"sfx/weapons/overheat_{i:02d}", x, -3.0, bus="SFX", volume_db=-5.0, max_voices=1)


def shimmer(r, f: float, sec: float, decay: float = 0.6, count: int = 9):
    """Metallic shimmer: high inharmonic partials with fast beating, the 'zing' on top of a struck bell."""
    n = N(sec)
    t = tax(n)
    y = np.zeros(n)
    for k in range(count):
        fr = f * (2.76 + 1.37 * k + r.uniform(-0.08, 0.08))
        if fr > SR * 0.45:
            break
        beat = r.uniform(3.0, 11.0)
        y += (0.8 / (1 + 0.35 * k)) * np.sin(2 * np.pi * fr * t + r.uniform(0, 6.28)) \
            * (0.6 + 0.4 * np.sin(2 * np.pi * beat * t)) * np.exp(-t / (decay / (1 + 0.25 * k)))
    return y * attack(n, 0.001)


def toll_layers(r, f: float, sec: float, ring_out: float, body: float = 1.0, sub: float = 1.0, shim: float = 0.5,
                strike: float = 1.0):
    """Update 02 Totenglocke voice: low body (a long-decay bell an octave down + a sub thump), the bell itself,
    a metallic shimmer and a ring-out tail of `ring_out` seconds."""
    x = zeros(sec)
    place(x, bell(r, f * 0.5, sec, decay=ring_out * 1.2, strike=0.0, bright=0.5), 0.0, 0.9 * body)
    place(x, bell(r, f, sec, decay=ring_out, strike=1.4 * strike, bright=1.1), 0.0, 1.0)
    place(x, shimmer(r, f, min(sec, 2.5), decay=0.7), 0.0, shim)
    place(x, kick(r, 1.0, 85, 34, 0.45, min(sec, 1.6)), 0.0, 0.9 * sub)
    place(x, nrm(lp(white(r, 0.6), 500)) * expenv(N(0.6), 0.12), 0.0, 0.35 * sub)
    return sat(x, 1.25)


def gen_totenglocke_v2():
    """Update 02 (T-048): the rebuilt Totenglocke. Quick toll, Great Toll, wall echo, wind-up hum (loop), the
    winding reload, Mitternacht's midnight chime, the shatter, a bronze shard pickup and the Bell Dome."""
    for i in variants(3):
        r = rng_for(f"tgtoll{i}")
        x = toll_layers(r, hz("A2") * r.uniform(0.985, 1.015), 4.2, 3.0)
        emit("totenglocke_toll", f"sfx/weapons/totenglocke_toll_{i:02d}", reverb(x, r, 2.4, 0.3, 3500, 0.02)[:N(4.2)], -0.5,
             bus="SFX", volume_db=0.0, pitch=[0.98, 1.02], max_voices=3, attenuation="loud")
    for i in variants(2):
        r = rng_for(f"tggreat{i}")
        dur = 6.0
        x = toll_layers(r, hz("F2") * r.uniform(0.99, 1.01), dur, 3.6, body=1.3, sub=1.6, shim=0.8, strike=1.5)
        place(x, kick(r, 1.0, 60, 24, 0.9, 2.5), 0.0, 1.0)                                       # the pressure wave
        place(x, nrm(bp(white(r, 1.4), 120, 2400)) * expenv(N(1.4), 0.35), 0.0, 0.45)           # air shoved aside
        place(x, bell(r, hz("F3") * 1.003, dur, decay=2.4, strike=0.6), 0.012, 0.45)              # a doubled strike
        emit("totenglocke_great", f"sfx/weapons/totenglocke_great_{i:02d}", reverb(sat(x, 1.4), r, 3.2, 0.4, 3000, 0.03)[:N(dur)],
             -0.3, bus="SFX", volume_db=1.0, pitch=[0.99, 1.01], max_voices=2, attenuation="loud")
    r = rng_for("tgecho")
    x = toll_layers(r, hz("F2"), 4.0, 2.4, body=1.0, sub=0.4, shim=0.2, strike=0.6)
    x = lp(x, 1400) + 0.15 * x
    emit("totenglocke_echo", "sfx/weapons/totenglocke_echo_01", reverb(x, r, 3.5, 0.9, 1800, 0.05)[:N(4.0)], -6.0,
         bus="SFX", volume_db=-4.0, max_voices=2, attenuation="loud")
    # the wind-up hum: steady bell partials with slow beating, whole cycles per loop (pitch rises in code)
    loop = 2.0
    t = tax(N(loop))
    f0 = hz("A3")
    y = np.zeros(N(loop))
    for ratio, amp in [(0.5, 0.8), (1.0, 1.0), (1.183, 0.45), (1.506, 0.35), (2.0, 0.4), (2.662, 0.18), (3.011, 0.12)]:
        fr = periodic(f0 * ratio, loop)
        fb = periodic(f0 * ratio + 1.5, loop)
        y += amp * (np.sin(2 * np.pi * fr * t) + 0.5 * np.sin(2 * np.pi * fb * t))
    y += 0.25 * np.sin(2 * np.pi * periodic(55.0, loop) * t)
    emit("totenglocke_hum", "sfx/weapons/totenglocke_hum_01", y * 0.3, -6.0, loop=True, bus="SFX", volume_db=-4.0, max_voices=2)
    # the winding reload: a ratchet that runs six turns, a spring tightening under it, and the pawl home
    r = rng_for("tgwind")
    dur = 2.6
    x = zeros(dur)
    clicks = 30
    for k in range(clicks):
        u = k / clicks
        tt = 0.25 + 1.95 * (u * u * (3 - 2 * u)) ** 1.0
        place(x, mech_click(r, 1500 + 500 * u + 80 * (k % 3), 0.05, 0.003), tt, 0.45 + 0.25 * (k % 2))
    spring = nrm(bp(white(r, 2.2), 600, 2400)) * np.linspace(0.05, 0.3, N(2.2)) * (0.6 + 0.4 * np.abs(smooth_rand(r, 2.2, 22)))
    place(x, spring, 0.25, 0.4)
    place(x, mech_click(r, 900, 0.08, 0.006), 2.35, 1.0)
    place(x, thunk(r, 180, 0.05, 0.2), 2.36, 0.7)
    place(x, bell(r, hz("A4"), 0.9, decay=0.5, strike=0.2, bright=1.2), 2.37, 0.18)              # the bell answers
    emit("totenglocke_wind", "sfx/weapons/totenglocke_wind_01", reverb(x, r, 0.35, 0.1), -2.0, bus="SFX", volume_db=-3.0, max_voices=1)
    # Mitternacht: a midnight clock chime layered on every toll
    for i in variants(2):
        r = rng_for(f"tgmid{i}")
        dur = 4.5
        x = zeros(dur)
        place(x, bell(r, hz("E4") * r.uniform(0.995, 1.005), dur, decay=2.2, strike=0.5, bright=1.4), 0.0, 1.0)
        place(x, bell(r, hz("B4"), dur - 0.1, decay=1.8, strike=0.3, bright=1.2), 0.09, 0.55)
        place(x, shimmer(r, hz("E5"), 2.0, decay=0.9), 0.0, 0.35)
        emit("totenglocke_midnight", f"sfx/weapons/totenglocke_midnight_{i:02d}", reverb(x, r, 2.8, 0.45, 6000, 0.03)[:N(dur)], -1.0,
             bus="SFX", volume_db=-2.0, pitch=[0.99, 1.01], max_voices=3, attenuation="loud")
    # shatter: bronze and frozen flesh coming apart
    for i in variants(3):
        r = rng_for(f"tgshat{i}")
        dur = 0.9
        x = zeros(dur)
        for k in range(14):
            place(x, mech_click(r, r.uniform(2500, 7000), 0.04, 0.002, q=10), r.uniform(0.0, 0.18), r.uniform(0.3, 0.8))
        place(x, nrm(hp(white(r, 0.5), 1500)) * expenv(N(0.5), 0.06), 0.0, 0.6)
        place(x, thunk(r, 140, 0.05, 0.3), 0.0, 0.8)
        place(x, shimmer(r, 900, 0.8, decay=0.25), 0.01, 0.3)
        emit("totenglocke_shatter", f"sfx/weapons/totenglocke_shatter_{i:02d}", reverb(x, r, 0.6, 0.2, 7000), -1.0,
             bus="SFX", volume_db=-2.0, pitch=[0.9, 1.1], max_voices=4, attenuation="world")
    r = rng_for("tgshard")
    x = zeros(0.9)
    place(x, bell(r, hz("A5"), 0.8, decay=0.4, strike=0.2, bright=1.3), 0.0, 0.8)
    place(x, bell(r, hz("E6"), 0.7, decay=0.3, strike=0.1, bright=1.0), 0.06, 0.5)
    emit("totenglocke_shard", "sfx/weapons/totenglocke_shard_01", reverb(x, r, 0.5, 0.2, 8000), -3.0, bus="SFX", volume_db=-3.0, max_voices=2)
    # the Bell Dome: a plant (a struck ground plate) and a low, beating resonance bed (loop)
    r = rng_for("tgdomeplant")
    x = toll_layers(r, hz("D2"), 3.0, 2.0, body=1.2, sub=1.2, shim=0.3, strike=0.8)
    emit("totenglocke_dome_plant", "sfx/weapons/totenglocke_dome_plant_01", reverb(x, r, 2.0, 0.35, 2500)[:N(3.0)], -1.0,
         bus="SFX", volume_db=0.0, max_voices=2, attenuation="loud")
    loop = 3.0
    t = tax(N(loop))
    y = np.zeros(N(loop))
    for fr, amp in [(hz("D2"), 1.0), (hz("D3"), 0.5), (hz("A3"), 0.3), (hz("D4") * 1.183, 0.15)]:
        y += amp * (np.sin(2 * np.pi * periodic(fr, loop) * t) + 0.7 * np.sin(2 * np.pi * periodic(fr + 1.0, loop) * t))
    y *= 0.8 + 0.2 * np.sin(2 * np.pi * periodic(2.0, loop) * t)
    emit("totenglocke_dome", "sfx/weapons/totenglocke_dome_01", y * 0.3, -5.0, loop=True, bus="SFX", volume_db=-3.0, max_voices=2,
         attenuation="world")


def gen_wonders():
    # Totenglocke: crank ratchet + the RING (a huge bell plus a shock front)
    r = rng_for("tgcrank")
    x = zeros(1.3)
    for k in range(12):
        place(x, mech_click(r, 1600 + 60 * (k % 3), 0.05, 0.004), k * 0.09, 0.6 + 0.3 * (k % 2))
    emit("totenglocke_crank", "sfx/weapons/totenglocke_crank_01", reverb(x, r, 0.4, 0.1), -2.0, bus="SFX", volume_db=-4.0, max_voices=1)
    for i in variants(2):
        r = rng_for(f"tgring{i}")
        dur = 6.5
        b = bell(r, hz("A2") * r.uniform(0.98, 1.02), dur, decay=3.2, strike=1.2)
        shock = kick(r, 1.0, 90, 30, 0.5, dur) + 0.4 * nrm(lp(white(r, dur), 600)) * expenv(N(dur), 0.3)
        x = sat(1.0 * b + 0.8 * shock, 1.3)
        emit("totenglocke_ring", f"sfx/weapons/totenglocke_ring_{i:02d}", reverb(x, r, 3.0, 0.35, 3000, 0.03)[:N(dur)], -0.5,
             bus="SFX", volume_db=0.0, pitch=[0.99, 1.01], max_voices=2, attenuation="loud")
    gen_totenglocke_v2()
    # Siren Gramophone: wind-up, needle drop, and the scratchy 78 rpm record loop
    r = rng_for("gwind")
    x = zeros(1.6)
    for k in range(16):
        place(x, mech_click(r, 2300 + 200 * np.sin(k), 0.04, 0.003), k * 0.085 + r.uniform(0, 0.01), 0.5)
    place(x, scrape(r, 1.4, 600, 2500, 12), 0.0, 0.2)
    emit("gramophone_windup", "sfx/weapons/gramophone_windup_01", x, -2.0, bus="SFX", volume_db=-4.0, max_voices=1, attenuation="world")
    r = rng_for("gneedle")
    x = zeros(0.8)
    place(x, mech_click(r, 1800, 0.05), 0.0, 0.6)
    place(x, crackle(r, 0.8, 80, 1.0, 1500, 7000) * expenv(N(0.8), 0.4), 0.02, 0.6)
    place(x, thunk(r, 120, 0.05, 0.2), 0.0, 0.5)
    emit("gramophone_needle", "sfx/weapons/gramophone_needle_01", x, -2.0, bus="SFX", volume_db=-3.0, max_voices=1, attenuation="world")
    emit("gramophone_record", "sfx/weapons/gramophone_record_01", gramophone_record(rng_for("grec")), -2.0, loop=True,
         bus="SFX", volume_db=-2.0, pitch=[1.0, 1.0], max_voices=2, attenuation="world")


# The toy march used by the gramophone record and (in fragments) by the crate and Herr Tamtam.
# Original melody, D major, 96 BPM: (note, beats). "-" = rest.
TOY_MARCH = [("A4", 0.5), ("D5", 0.5), ("D5", 0.5), ("F#5", 0.5), ("E5", 1.0), ("C#5", 1.0),
             ("B4", 0.5), ("D5", 0.5), ("G5", 0.5), ("F#5", 0.5), ("E5", 1.5), ("-", 0.5),
             ("A4", 0.5), ("C#5", 0.5), ("E5", 0.5), ("G5", 0.5), ("F#5", 0.75), ("E5", 0.25), ("D5", 0.5), ("B4", 0.5),
             ("A4", 0.5), ("B4", 0.5), ("C#5", 0.5), ("E5", 0.5), ("D5", 1.5), ("-", 0.5)]


def gramophone_record(r):
    beat = 60.0 / 96.0
    total = sum(b for _, b in TOY_MARCH) * beat
    x = zeros(total + 1.0)
    t = 0.0
    for name, b in TOY_MARCH:
        if name != "-":
            place(x, music_box(r, hz(name), 1.2), t, 0.8)
            place(x, piano(r, hz(name) / 2, 0.6, 0.5), t, 0.25)
        t += b * beat
    for k in range(int(total / beat)):          # child-sized snare on every beat, roll into bar 4 and 8
        place(x, snare(r, 0.35 if k % 2 else 0.5, 240, 0.2, 0.6, 7000), k * beat, 1.0)
        if k % 8 == 7:
            place(x, snare(r, 0.25, 240, 0.15, 0.6, 7000), k * beat + beat * 0.5, 1.0)
    x = x[:N(total)]
    nrows = len(x)
    wob = 1.0 + 0.0087 * np.sin(2 * np.pi * (78 / 60) * tax(nrows))           # +-15 cents, 78 rpm
    y = varispeed(np.concatenate([x, x[:N(0.2)]]), wob)[:nrows]
    y = period(y, 300, 3500, 0.2)
    y = sat(nrm(y) * 1.3, 1.0) + 0.12 * crackle(r, len(y) / SR, 25, 1.0, 1000, 8000) + 0.02 * bp(white(r, len(y) / SR), 2000, 6000)
    return fit(y, total)


# ═════════════════════════════════════════════════════════════════ ZOMBIES

def ganger_groan(r, i):
    dur = r.uniform(1.3, 2.4)
    base = r.uniform(82, 128)
    f0 = pitch_curve(r, dur, base, [(0, 0.9), (0.3, 1.08), (0.7, 0.98), (1, 0.8)], 0.06, r.uniform(4, 7), 0.02, 0.015)
    seq = [["o", "a", "u"], ["u", "o", "a", "o"], ["a", "o", "u"], ["e", "a", "o"], ["o", "ae", "u"], ["u", "a", "u"]][i % 6]
    x = voice(r, dur, f0, seq, shift=r.uniform(0.82, 0.95), breath=0.25, rasp=0.45, fry=r.uniform(0.3, 0.6), drive=2.0)
    x *= adsr(len(x), r.uniform(0.1, 0.25), 0.3, 0.8, r.uniform(0.3, 0.6))
    return reverb(x, r, 0.35, 0.08, 4000)


def ganger_sprint(r, i):
    dur = r.uniform(0.9, 1.4)
    base = r.uniform(140, 210)
    f0 = pitch_curve(r, dur, base, [(0, 0.85), (0.2, 1.1), (0.6, 1.0), (1, 0.75)], 0.08, 7.5, 0.035, 0.02)
    x = voice(r, dur, f0, ["ah", "e", "a"] if i % 2 else ["a", "ae", "o"], shift=r.uniform(0.9, 1.0), breath=0.4,
              rasp=0.7, fry=0.45, drive=3.0)
    x *= adsr(len(x), 0.04, 0.2, 0.85, 0.25)
    pant = np.zeros(len(x))                     # ragged inhale before the snarl
    inh = nrm(bp(white(r, 0.25), 800, 4000)) * adsr(N(0.25), 0.15, 0, 1, 0.08) * 0.25
    out = zeros(dur + 0.3)
    place(out, inh, 0.0)
    place(out, x, 0.2)
    return reverb(out, r, 0.35, 0.08, 4500)


def ganger_attack(r, i):
    dur = r.uniform(0.5, 0.85)
    base = r.uniform(260, 420)
    f0 = pitch_curve(r, dur, base, [(0, 0.8), (0.15, 1.15), (0.5, 1.05), (1, 0.7)], 0.07, 9, 0.04, 0.03)
    x = voice(r, dur, f0, ["ae", "a", "ah"], shift=r.uniform(1.0, 1.12), breath=0.5, rasp=0.9, fry=0.35, drive=4.0)
    x *= adsr(len(x), 0.015, 0.1, 0.8, 0.2)
    return reverb(x, r, 0.4, 0.1, 5000)


def ganger_death(r, i):
    dur = r.uniform(1.2, 1.9)
    base = r.uniform(120, 170)
    f0 = pitch_curve(r, dur, base, [(0, 1.1), (0.25, 1.0), (1, 0.42)], 0.07, 5, 0.02, 0.04)
    x = voice(r, dur, f0, ["a", "o", "u"], shift=r.uniform(0.85, 0.95), breath=0.3, rasp=0.6, fry=0.6, drive=2.4)
    n = len(x)
    t = tax(n)
    gate = 0.35 + 0.65 * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(14 + 10 * smooth_rand(r, dur, 6)) / SR)))
    gate = lp(gate, 60)
    x = x * np.where(t > dur * 0.35, gate, 1.0)
    bub = np.zeros(n)                           # wet gurgle blips
    for k in range(int(dur * 14)):
        bl = 0.03
        fr = r.uniform(250, 900)
        chirp = np.sin(2 * np.pi * np.cumsum(np.linspace(fr, fr * 1.8, N(bl))) / SR) * np.sin(np.pi * np.linspace(0, 1, N(bl)))
        place(bub, chirp, r.uniform(dur * 0.3, dur * 0.95), r.uniform(0.2, 0.6))
    x = x * adsr(n, 0.03, 0.2, 0.85, dur * 0.4) + 0.35 * lp(bub, 1800)
    exhale = nrm(bp(white(r, 0.6), 300, 2500)) * adsr(N(0.6), 0.05, 0, 1, 0.5) * 0.25
    out = zeros(dur + 0.5)
    place(out, x, 0.0)
    place(out, exhale, dur * 0.85)
    return reverb(out, r, 0.4, 0.08, 4000)


def zombie_spawn(r):
    dur = 1.4
    x = zeros(dur)
    rubble = crackle(r, 1.0, 60, 1.0, 200, 3000) * adsr(N(1.0), 0.1, 0.2, 0.7, 0.5)
    place(x, rubble, 0.0, 0.6)
    place(x, nrm(lp(brown(r, 1.0), 300)) * adsr(N(1.0), 0.2, 0.2, 0.8, 0.5), 0.0, 0.7)
    for k in range(4):
        place(x, thunk(r, r.uniform(90, 160), 0.04, 0.2), r.uniform(0.05, 0.7), r.uniform(0.3, 0.7))
    place(x, nrm(ganger_groan(r, 1))[:N(0.8)] * np.linspace(1, 0, N(0.8)), 0.45, 0.4)
    return reverb(x, r, 0.5, 0.1, 3000)


def zombie_step(r):
    x = zeros(0.4)
    place(x, nrm(lp(white(r, 0.22), 900)) * adsr(N(0.22), 0.03, 0, 1, 0.12), 0.0, 0.5)      # drag
    place(x, thunk(r, r.uniform(70, 100), 0.035, 0.2), 0.16, 0.8)                         # foot down
    place(x, crackle(r, 0.15, 120, 1.0, 500, 4000) * expenv(N(0.15), 0.05), 0.16, 0.3)
    return x


def flesh_hit(r):
    x = zeros(0.35)
    place(x, kick(r, 1.0, 130, 60, 0.04, 0.25), 0.0, 0.8)
    sq = nrm(lp(white(r, 0.2), 2200)) * expenv(N(0.2), 0.035) * (0.4 + 0.6 * smooth_rand(r, 0.2, 120, 0, 1))
    place(x, sq, 0.0, 0.8)
    return x


def gib(r):
    x = zeros(0.8)
    place(x, flesh_hit(r), 0.0, 1.0)
    for k in range(8):
        place(x, flesh_hit(r) * 0.4, r.uniform(0.05, 0.5), r.uniform(0.2, 0.5))
    place(x, thunk(r, 90, 0.08, 0.3), 0.0, 0.7)
    return reverb(x, r, 0.3, 0.1)


# ---- the gore rework (docs/gore/gore_rework_2026-11.md): wet, close, small sounds

def gore_splat(r):
    """Blood thrown onto a wall or the boards: a wet slap and the patter of what came with it."""
    x = zeros(0.5)
    place(x, nrm(lp(white(r, 0.07), 3400)) * expenv(N(0.07), 0.013), 0.0, 0.9)                  # the slap
    place(x, kick(r, 0.6, 150, 70, 0.03, 0.12), 0.0, 0.35)
    for k in range(int(r.integers(5, 10))):                                                       # droplets after it
        d = nrm(bp(white(r, 0.03), r.uniform(900, 2600), r.uniform(3200, 5200))) * expenv(N(0.03), r.uniform(0.004, 0.009))
        place(x, d, r.uniform(0.02, 0.26), r.uniform(0.1, 0.35))
    sq = nrm(lp(white(r, 0.18), 1800)) * expenv(N(0.18), 0.05) * (0.3 + 0.7 * smooth_rand(r, 0.18, 90, 0, 1))
    place(x, sq, 0.01, 0.35)                                                                      # it clings
    return x


def gore_spurt(r):
    """An opened artery: four or five weakening pulses of hiss with a wet patter under each."""
    x = zeros(2.6)
    t = 0.0
    for k in range(5):
        g = 1.0 - k * 0.17
        n = r.uniform(0.2, 0.27)
        hiss = nrm(bp(white(r, n), 1400, 5200)) * adsr(N(n), 0.02, 0.05, 0.6, 0.12) * (0.6 + 0.4 * smooth_rand(r, n, 60, 0, 1))
        place(x, hiss, t, 0.5 * g)
        for j in range(int(r.integers(3, 7))):
            d = nrm(lp(white(r, 0.04), r.uniform(1500, 3200))) * expenv(N(0.04), 0.008)
            place(x, d, t + r.uniform(0.12, 0.42), r.uniform(0.12, 0.3) * g)
        t += r.uniform(0.4, 0.48)
    return lp(x, 6500)


def gore_bone(r):
    """Bone giving way under it all: a dry double crack in a wet body."""
    x = zeros(0.4)
    for k, t0 in enumerate((0.0, r.uniform(0.035, 0.07))):
        c = nrm(bp(white(r, 0.02), r.uniform(1800, 2600), r.uniform(6000, 8000))) * expenv(N(0.02), 0.003)
        place(x, c, t0, 1.0 - 0.3 * k)
        place(x, thunk(r, r.uniform(240, 380), 0.012, 0.06), t0, 0.5)
    place(x, flesh_hit(r) * 0.5, 0.01, 0.6)
    return x


def gore_drip(r):
    """Blood finding the floor under a body: a few slow, thick drops."""
    x = zeros(2.2)
    t = r.uniform(0.05, 0.2)
    for k in range(int(r.integers(4, 7))):
        f = r.uniform(260, 420)
        n = N(0.09)
        tone = np.sin(2 * np.pi * (f * (1.0 + 2.2 * np.exp(-tax(n) / 0.012))) * tax(n)) * expenv(n, 0.02)
        place(x, tone, t, r.uniform(0.25, 0.5))
        place(x, nrm(lp(white(r, 0.03), 2400)) * expenv(N(0.03), 0.006), t, r.uniform(0.2, 0.4))
        t += r.uniform(0.18, 0.5)
    return lp(x, 4200)


def gen_gore():
    for i in variants(4):
        emit("gore_splat", f"sfx/zombies/gore_splat_{i:02d}", gore_splat(rng_for(f"goresplat{i}")), -3.0, volume_db=-9.0, max_voices=3,
             bus="SFX", attenuation="quiet", pitch=[0.86, 1.12], vol_jitter_db=2.0)
    for i in variants(3):
        emit("gore_spurt", f"sfx/zombies/gore_spurt_{i:02d}", gore_spurt(rng_for(f"gorespurt{i}")), -3.0, volume_db=-8.0, max_voices=2,
             bus="SFX", attenuation="quiet", pitch=[0.92, 1.08], vol_jitter_db=1.5)
        emit("gore_bone", f"sfx/zombies/gore_bone_{i:02d}", gore_bone(rng_for(f"gorebone{i}")), -2.0, volume_db=-5.0, max_voices=2,
             bus="SFX", attenuation="zombie", pitch=[0.9, 1.1], vol_jitter_db=1.5)
        emit("gore_drip", f"sfx/zombies/gore_drip_{i:02d}", gore_drip(rng_for(f"goredrip{i}")), -6.0, volume_db=-14.0, max_voices=2,
             bus="SFX", attenuation="quiet", pitch=[0.88, 1.1], vol_jitter_db=2.0)


def gen_zombies():
    gen_gore()
    zs = dict(bus="SFX", attenuation="zombie", pitch=[0.94, 1.06], vol_jitter_db=2.0)
    for i in variants(8):
        emit("zombie_groan", f"sfx/zombies/ganger_groan_{i:02d}", ganger_groan(rng_for(f"groan{i}"), i), -1.0, volume_db=-4.0, max_voices=6, **zs)
    for i in variants(6):
        emit("zombie_sprint", f"sfx/zombies/ganger_sprint_{i:02d}", ganger_sprint(rng_for(f"sprint{i}"), i), -1.0, volume_db=-3.0, max_voices=5, **zs)
        emit("zombie_attack", f"sfx/zombies/ganger_attack_{i:02d}", ganger_attack(rng_for(f"atk{i}"), i), -1.0, volume_db=-2.0, max_voices=4, **zs)
        emit("zombie_death", f"sfx/zombies/ganger_death_{i:02d}", ganger_death(rng_for(f"death{i}"), i), -1.0, volume_db=-3.0, max_voices=5, **zs)
    for i in variants(4):
        emit("zombie_spawn", f"sfx/zombies/ganger_spawn_{i:02d}", zombie_spawn(rng_for(f"spawn{i}")), -2.0, volume_db=-8.0, max_voices=3, **zs)
    for i in variants(6):
        emit("zombie_step", f"sfx/zombies/ganger_step_{i:02d}", zombie_step(rng_for(f"zstep{i}")), -2.0, volume_db=-10.0, max_voices=6,
             bus="SFX", attenuation="quiet", pitch=[0.9, 1.1], vol_jitter_db=3.0)
    for i in variants(5):
        emit("impact_flesh", f"sfx/zombies/impact_flesh_{i:02d}", flesh_hit(rng_for(f"flesh{i}")), -1.5, volume_db=-6.0, max_voices=4,
             bus="SFX", attenuation="world", pitch=[0.9, 1.1])
    for i in variants(3):
        emit("zombie_gib", f"sfx/zombies/gib_{i:02d}", gib(rng_for(f"gib{i}")), -1.5, volume_db=-4.0, max_voices=3, **zs)
    # Glasshide: low voice + crystal grinding
    for i in variants(4):
        r = rng_for(f"glass{i}")
        dur = r.uniform(1.6, 2.4)
        f0 = pitch_curve(r, dur, r.uniform(58, 75), [(0, 0.9), (0.5, 1.05), (1, 0.85)], 0.05, 4, 0.015)
        v = voice(r, dur, f0, ["o", "u", "o"], 0.75, 0.2, 0.4, 0.6, 2.2)
        grind = np.zeros(N(dur))
        nz = white(r, dur)
        for f in r.uniform(2500, 9000, 8):
            grind += reson(nz, f, 60)
        grind = nrm(grind) * (0.3 + 0.7 * np.abs(smooth_rand(r, dur, 25))) * adsr(N(dur), 0.2, 0, 1, 0.4)
        x = v * adsr(N(dur), 0.15, 0.2, 0.85, 0.4) + 0.35 * grind
        emit("glasshide_grind", f"sfx/zombies/glasshide_grind_{i:02d}", reverb(x, r, 0.5, 0.12, 6000), -1.0, volume_db=-4.0, max_voices=3, **zs)
    for i in variants(2):
        r = rng_for(f"shatter{i}")
        dur = 1.5
        x = zeros(dur)
        for k in range(26):
            g = reson(white(r, 0.12) * expenv(N(0.12), 0.003), r.uniform(2500, 11000), r.uniform(30, 90))
            place(x, nrm(g) * expenv(N(0.12), r.uniform(0.03, 0.1)), r.uniform(0, 0.5) ** 1.5, r.uniform(0.2, 1.0))
        place(x, kick(r, 0.8, 200, 70, 0.08, 0.5), 0.0)
        emit("glasshide_shatter", f"sfx/zombies/glasshide_shatter_{i:02d}", reverb(x, r, 0.9, 0.2, 9000), -1.0, volume_db=-1.0, max_voices=2,
             bus="SFX", attenuation="world", pitch=[0.95, 1.05])
    # Bellringer: wheezing breath + lantern chain rattle
    for i in variants(4):
        r = rng_for(f"wheeze{i}")
        x = zeros(2.0)
        for k, (st, ln) in enumerate([(0.0, 0.7), (0.85, 0.9)]):
            f0 = pitch_curve(r, ln, r.uniform(200, 260) * (1.1 if k == 0 else 1.0), [(0, 1), (1, 0.9)], 0.06, 8, 0.03)
            v = voice(r, ln, f0, ["i", "e"] if k == 0 else ["e", "u"], 1.1, breath=1.2, rasp=0.3, drive=1.2)
            place(x, v * adsr(N(ln), 0.15, 0, 1, 0.3), st, 0.6 if k == 0 else 1.0)
        emit("bellringer_wheeze", f"sfx/zombies/bellringer_wheeze_{i:02d}", reverb(x, r, 0.5, 0.1), -1.5, volume_db=-5.0, max_voices=3, **zs)
    for i in variants(4):
        r = rng_for(f"lantern{i}")
        x = zeros(0.6)
        for k in range(7):
            place(x, mech_click(r, r.uniform(3000, 6500), 0.12, 0.012), r.uniform(0, 0.25), r.uniform(0.3, 0.9))
        place(x, mech_click(r, 900, 0.15, 0.02), 0.0, 0.4)
        emit("bellringer_lantern", f"sfx/zombies/bellringer_lantern_{i:02d}", x, -3.0, volume_db=-10.0, max_voices=4,
             bus="SFX", attenuation="quiet", pitch=[0.92, 1.08])
    # Foreman: roar, pneumatic drill, ore chain, heavy steps
    for i in variants(3):
        r = rng_for(f"froar{i}")
        dur = r.uniform(1.8, 2.4)
        f0 = pitch_curve(r, dur, r.uniform(52, 66), [(0, 0.8), (0.2, 1.1), (0.7, 1.0), (1, 0.7)], 0.05, 5, 0.02)
        x = voice(r, dur, f0, ["a", "ah", "o"], 0.66, 0.4, 0.8, 0.7, 4.0) * adsr(N(dur), 0.08, 0.2, 0.9, 0.5)
        x += 0.4 * nrm(lp(brown(r, dur), 200)) * adsr(N(dur), 0.1, 0, 1, 0.5)
        emit("foreman_roar", f"sfx/zombies/foreman_roar_{i:02d}", reverb(x, r, 1.4, 0.25, 3000), -0.5, volume_db=0.0, max_voices=2,
             bus="SFX", attenuation="loud", pitch=[0.97, 1.03])
    for i in variants(2):
        r = rng_for(f"drill{i}")
        dur = 2.0
        x = zeros(dur)
        rate = 24.0
        for k in range(int(dur * rate)):
            place_wrap(x, mech_click(r, r.uniform(700, 900), 0.04, 0.005) + 0.6 * thunk(r, 110, 0.012, 0.04), k / rate, r.uniform(0.7, 1.0))
        hiss = loopify(nrm(bp(white(r, dur + 0.2), 1500, 7000)), 0.2)
        x += 0.25 * hiss * (0.7 + 0.3 * np.sin(2 * np.pi * rate * tax(N(dur))))
        emit("foreman_drill", f"sfx/zombies/foreman_drill_{i:02d}", x, -2.0, loop=True, volume_db=-3.0, max_voices=1,
             bus="SFX", attenuation="loud", pitch=[1.0, 1.0])
    for i in variants(3):
        r = rng_for(f"chain{i}")
        x = zeros(0.9)
        for k in range(9):
            place(x, mech_click(r, r.uniform(1500, 3200), 0.1, 0.01), k * 0.08 + r.uniform(0, 0.03), r.uniform(0.3, 0.8))
        place(x, scrape(r, 0.8, 300, 2000, 25), 0.0, 0.4)
        emit("foreman_chain", f"sfx/zombies/foreman_chain_{i:02d}", x, -2.0, volume_db=-6.0, max_voices=2, bus="SFX", attenuation="world")
    for i in variants(3):
        r = rng_for(f"fstep{i}")
        x = zeros(0.8)
        place(x, kick(r, 1.0, 80, 30, 0.2, 0.7), 0.0)
        place(x, crackle(r, 0.5, 80, 1.0, 200, 2500) * expenv(N(0.5), 0.15), 0.0, 0.4)
        emit("foreman_step", f"sfx/zombies/foreman_step_{i:02d}", reverb(x, r, 0.8, 0.2, 2500), -1.0, volume_db=-3.0, max_voices=2,
             bus="SFX", attenuation="loud", pitch=[0.95, 1.05])
    # Screamer: tell-tale humming + the scream
    for i in variants(2):
        r = rng_for(f"shum{i}")
        dur = 3.2
        notes = [("E4", 0.8), ("G4", 0.8), ("F#4", 0.6), ("D4", 1.0)] if i == 1 else [("D4", 0.9), ("A3", 0.6), ("C4", 0.7), ("B3", 1.0)]
        f = np.concatenate([np.full(N(d), hz(nm)) for nm, d in notes])
        f = smooth(fit(f, dur), 0.06) * (1 + 0.008 * np.sin(2 * np.pi * 5.0 * tax(N(dur))))
        x = voice(r, dur, f, ["m", "m"], 1.15, breath=0.15, rasp=0.05, drive=1.0) * adsr(N(dur), 0.3, 0, 1, 0.6)
        emit("screamer_hum", f"sfx/zombies/screamer_hum_{i:02d}", reverb(x, r, 1.2, 0.3), -2.0, volume_db=-6.0, max_voices=1,
             bus="SFX", attenuation="world", pitch=[1.0, 1.0])
    for i in variants(2):
        r = rng_for(f"scream{i}")
        dur = 2.6
        f0 = pitch_curve(r, dur, r.uniform(620, 760), [(0, 0.7), (0.1, 1.1), (0.6, 1.0), (1, 0.6)], 0.06, 7, 0.05, 0.04)
        x = voice(r, dur, f0, ["a", "ae", "i"], 1.25, 0.8, 1.0, 0.3, 5.0) * adsr(N(dur), 0.05, 0.2, 0.9, 0.7)
        emit("screamer_scream", f"sfx/zombies/screamer_scream_{i:02d}", reverb(x, r, 1.6, 0.3, 6000), -0.5, volume_db=0.0, max_voices=1,
             bus="SFX", attenuation="loud", pitch=[1.0, 1.0])


# ═════════════════════════════════════════════════════════════════ PLAYER / FOOTSTEPS

def footstep(r, surface: str):
    if surface == "snow":
        dur = 0.32
        x = zeros(dur)
        grains = np.zeros(N(0.2))
        cnt = r.integers(60, 110)
        pos = (r.beta(1.5, 3.0, cnt) * len(grains)).astype(int)
        grains[pos] = r.uniform(-1, 1, cnt)
        g = bp(grains, 900, 7000)
        g = nrm(g) * adsr(len(g), 0.02, 0.0, 1.0, 0.1)
        place(x, g, 0.0, 0.8)
        place(x, thunk(r, 80, 0.03, 0.12), 0.01, 0.4)
        return lp(x, 6500)
    if surface == "wood":
        x = zeros(0.4)
        place(x, thunk(r, r.uniform(95, 125), 0.035, 0.2), 0.0, 0.9)
        knock = white(r, 0.08) * expenv(N(0.08), 0.004)
        knock = reson(knock, r.uniform(200, 240), 6) + 0.7 * reson(knock, r.uniform(450, 520), 8) + 0.4 * reson(knock, 1100, 10)
        place(x, nrm(knock) * expenv(N(0.08), 0.03), 0.0, 0.6)
        if r.random() < 0.35:
            cr = bp(saw(np.full(N(0.2), r.uniform(40, 70)) * (1 + 0.4 * smooth_rand(r, 0.2, 20))), 700, 2500)
            place(x, nrm(cr) * adsr(N(0.2), 0.05, 0, 1, 0.1), 0.06, 0.15)
        return x
    if surface == "stone":
        x = zeros(0.3)
        place(x, mech_click(r, r.uniform(1800, 2400), 0.04, 0.003) * 0.4, 0.0)
        place(x, thunk(r, 70, 0.025, 0.12), 0.0, 0.7)
        place(x, scrape(r, 0.1, 1500, 6000, 150) * 0.3, 0.005)
        return x
    if surface == "hay":
        # straw and chaff: a soft dry crunch of many fine grains over a muffled thump (Update 02 §1)
        x = zeros(0.36)
        grains = np.zeros(N(0.24))
        cnt = r.integers(140, 220)
        pos = (r.beta(1.3, 2.6, cnt) * len(grains)).astype(int)
        grains[pos] = r.uniform(-1, 1, cnt)
        g = bp(grains, 1800, 9000) + 0.5 * bp(white(r, 0.24), 2500, 7000) * expenv(N(0.24), 0.05)
        g = nrm(g) * adsr(len(g), 0.015, 0.0, 1.0, 0.12)
        place(x, g, 0.0, 0.7)
        place(x, thunk(r, 65, 0.03, 0.1), 0.005, 0.45)
        return lp(x, 8000)
    if surface == "metal":
        dur = 0.6
        n = N(dur)
        t = tax(n)
        ring = sum(a * np.sin(2 * np.pi * f * r.uniform(0.97, 1.03) * t) * np.exp(-t / d)
                   for f, a, d in [(420, 0.6, 0.18), (1130, 0.5, 0.15), (2370, 0.35, 0.1), (3900, 0.2, 0.06)])
        x = zeros(dur)
        place(x, ring * attack(n, 0.001), 0.0, 0.5)
        place(x, thunk(r, 90, 0.03, 0.15), 0.0, 0.8)
        place(x, mech_click(r, 1500, 0.05), 0.0, 0.5)
        return x
    raise KeyError(surface)


def gen_player():
    for surface in ["snow", "wood", "stone", "metal", "hay"]:
        for i in variants(5):
            r = rng_for(f"step_{surface}{i}")
            x = reverb(footstep(r, surface), r, 0.3 if surface != "metal" else 0.6, 0.06, 5000)
            emit(f"footstep_{surface}", f"sfx/player/footstep_{surface}_{i:02d}", x, -1.5, bus="SFX", volume_db=-12.0,
                 pitch=[0.94, 1.06], vol_jitter_db=2.0, max_voices=3, attenuation="quiet")
    for i in variants(4):
        r = rng_for(f"hurt{i}")
        x = zeros(0.6)
        place(x, kick(r, 1.0, 120, 50, 0.08, 0.5), 0.0)
        place(x, nrm(lp(white(r, 0.12), 1500)) * expenv(N(0.12), 0.03), 0.0, 0.6)
        cloth = nrm(bp(white(r, 0.2), 400, 3000)) * adsr(N(0.2), 0.01, 0, 1, 0.15)
        place(x, cloth, 0.01, 0.3)
        emit("player_hurt", f"sfx/player/hurt_{i:02d}", reverb(x, r, 0.2, 0.05), -1.0, bus="SFX", volume_db=-2.0, max_voices=2)
    r = rng_for("heartbeat")
    period_s = 60.0 / 72.0
    x = zeros(period_s * 2)
    for k in range(2):
        place(x, kick(r, 1.0, 70, 48, 0.07, 0.3), k * period_s)
        place(x, kick(r, 0.6, 80, 55, 0.06, 0.3), k * period_s + 0.27)
    emit("heartbeat", "sfx/player/heartbeat_01", lp(x, 400), -2.0, loop=True, bus="SFX", volume_db=-4.0, pitch=[1.0, 1.0], max_voices=1)
    r = rng_for("down")
    dur = 2.4
    n = N(dur)
    t = tax(n)
    x = zeros(dur)
    place(x, kick(r, 1.0, 90, 35, 0.3, 1.0), 0.0)
    place(x, 0.15 * np.sin(2 * np.pi * 4200 * t) * np.exp(-t / 0.9) * attack(n, 0.05), 0.0)
    place(x, nrm(lp(pink(r, dur), 300)) * np.exp(-t / 0.8), 0.0, 0.4)
    emit("player_down", "sfx/player/down_01", reverb(x, r, 1.5, 0.3, 2000), -1.0, bus="SFX", volume_db=-2.0, max_voices=1, pitch=[1.0, 1.0])
    r = rng_for("revive")
    dur = 2.0
    n = N(dur)
    swell = nrm(bp(pink(r, dur), 300, 3000)) * np.linspace(0, 1, n) ** 2 * np.exp(-np.maximum(0, tax(n) - 1.4) / 0.15)
    chord = sum(organ(r, hz(nm), 1.0, 0.3, 0.6) for nm in ["D4", "F#4", "A4"])
    x = zeros(dur + 0.5)
    place(x, swell, 0.0, 0.5)
    place(x, chord, 1.0, 0.4)
    emit("player_revive", "sfx/player/revive_01", reverb(x, r, 1.2, 0.3), -2.0, bus="SFX", volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0])
    r = rng_for("perkslost")
    x = zeros(1.2)
    for k in range(18):
        g = reson(white(r, 0.1) * expenv(N(0.1), 0.003), r.uniform(2000, 7000), 50)
        place(x, nrm(g) * expenv(N(0.1), 0.06), r.uniform(0, 0.3), r.uniform(0.2, 0.7))
    place(x, sum(organ(r, hz(nm), 0.6, 0.02, 0.5) for nm in ["D3", "Ab3"]), 0.1, 0.3)
    emit("perks_lost", "sfx/player/perks_lost_01", reverb(x, r, 1.0, 0.25), -2.0, bus="SFX", volume_db=-4.0, max_voices=1)


# ═════════════════════════════════════════════════════════════════ WORLD

def wood_crack(r, sec: float = 0.7, n_splinters: int = 9):
    x = zeros(sec)
    main = white(r, 0.12) * expenv(N(0.12), 0.012)
    main = reson(main, 180, 4) + 0.8 * reson(main, 420, 5) + 0.6 * reson(main, 950, 6) + 0.6 * bp(main, 1200, 5000)
    place(x, nrm(main), 0.0, 1.0)
    for k in range(n_splinters):
        s = bp(white(r, 0.01), 1200, 6000) * expenv(N(0.01), 0.002)
        place(x, nrm(s), r.uniform(0.0, 0.25) ** 1.3, r.uniform(0.2, 0.7))
    place(x, thunk(r, 85, 0.06, 0.3), 0.0, 0.6)
    return x


def gen_world():
    ws = dict(bus="SFX", attenuation="world")
    for i in variants(5):
        r = rng_for(f"bbreak{i}")
        x = wood_crack(r, 0.9, r.integers(7, 14))
        if r.random() < 0.6:                    # nail screech
            nd = 0.18
            f = np.linspace(r.uniform(2200, 2800), r.uniform(1700, 2100), N(nd))
            sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * smooth_rand(r, nd, 80, 0, 1)) * adsr(N(nd), 0.02, 0, 1, 0.06)
            place(x, sq, 0.02, 0.2)
        emit("board_break", f"sfx/world/board_break_{i:02d}", reverb(x, r, 0.5, 0.12, 5000), -1.0, volume_db=-2.0, max_voices=4,
             pitch=[0.93, 1.07], vol_jitter_db=1.5, **ws)
    for i in variants(4):
        r = rng_for(f"bplace{i}")
        x = zeros(0.75)
        place(x, wood_crack(r, 0.3, 0) * 0.5, 0.0)
        for k, tt in enumerate([0.2, 0.38] + ([0.52] if i % 2 else [])):
            hit = white(r, 0.06) * expenv(N(0.06), 0.002)
            hit = 0.6 * reson(hit, 620, 8) + 0.5 * reson(hit, 1250, 10) + 0.5 * reson(hit, 3400, 20) + 0.3 * hp(hit, 4000)
            place(x, nrm(hit) * expenv(N(0.06), 0.02), tt, 0.8)
        emit("board_place", f"sfx/world/board_place_{i:02d}", reverb(x, r, 0.4, 0.1), -1.0, volume_db=-2.0, max_voices=3, **ws)
    for i in variants(3):
        r = rng_for(f"bslam{i}")
        x = zeros(0.9)
        place(x, kick(r, 1.0, 100, 45, 0.15, 0.8), 0.0)
        place(x, wood_crack(r, 0.5, 4) * 0.6, 0.0)
        for k in range(5):
            place(x, mech_click(r, r.uniform(800, 1800), 0.06, 0.006) * 0.3, 0.05 + 0.04 * k)
        emit("board_slam", f"sfx/world/board_slam_{i:02d}", reverb(x, r, 0.6, 0.15), -1.0, volume_db=-2.0, max_voices=3, **ws)
    for i in variants(3):
        r = rng_for(f"door{i}")
        dur = 1.8
        x = zeros(dur)
        place(x, mech_click(r, 1300, 0.12, 0.012), 0.0, 0.9)        # latch / bar
        place(x, mech_click(r, 2900, 0.06), 0.02, 0.5)
        cd = 1.1
        rate = 45 + 35 * smooth_rand(r, cd, 3, 0, 1)
        stick = np.zeros(N(cd))
        ph = np.cumsum(rate) / SR
        idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
        stick[idx] = r.uniform(0.5, 1.0, len(idx))
        creak = reson(stick, 420 * (1 + 0.1 * i), 6) + 0.8 * reson(stick, 980, 8) + 0.5 * reson(stick, 1750, 10)
        place(x, nrm(creak) * adsr(N(cd), 0.1, 0, 1, 0.3), 0.12, 0.6)
        place(x, kick(r, 0.9, 90, 40, 0.15, 0.6), 1.25, 0.9)
        place(x, crackle(r, 0.6, 50, 1, 200, 3000) * expenv(N(0.6), 0.2), 1.25, 0.3)
        emit("door_open", f"sfx/world/door_open_{i:02d}", reverb(x, r, 0.9, 0.2, 4000), -1.0, volume_db=-2.0, max_voices=2, **ws)
    for i in variants(3):                     # "ledger stamp": stamp thunk + register bell + coins
        r = rng_for(f"buy{i}")
        dur = 1.1
        x = zeros(dur)
        place(x, kick(r, 0.8, 200, 90, 0.04, 0.2), 0.0)
        place(x, nrm(lp(white(r, 0.05), 2000)) * expenv(N(0.05), 0.01), 0.0, 0.5)
        place(x, bell(r, hz("E6") * (1 + 0.01 * i), 0.9, 0.35, 0.2, 0.8), 0.07, 0.5)
        for k in range(8):
            c = mech_click(r, r.uniform(4200, 7800), 0.05, 0.006)
            place(x, c, 0.1 + r.uniform(0, 0.3), r.uniform(0.15, 0.4))
        emit("buy", f"sfx/world/buy_{i:02d}", reverb(x, r, 0.4, 0.12), -1.0, volume_db=-3.0, max_voices=2, pitch=[0.99, 1.01], **ws)
    for i in variants(2):
        r = rng_for(f"deny{i}")
        dur = 0.38
        n = N(dur)
        buzz = square(np.full(n, 98.0 * (1 + 0.03 * i))) + square(np.full(n, 103.5 * (1 + 0.03 * i)))
        x = lp(buzz, 1600) * adsr(n, 0.005, 0.05, 0.8, 0.06)
        emit("deny", f"sfx/world/deny_{i:02d}", x, -3.0, volume_db=-6.0, max_voices=2, pitch=[1.0, 1.0], **ws)
    for i in variants(4):
        r = rng_for(f"tick{i}")
        x = zeros(0.08)
        place(x, mech_click(r, r.uniform(3000, 3800), 0.05, 0.002), 0.0)
        emit("scrip_tick", f"sfx/world/scrip_tick_{i:02d}", x, -3.0, volume_db=-4.0, max_voices=3, pitch=[0.97, 1.03], **ws)
    gen_crate()
    gen_perks()
    gen_powerups()
    gen_explosions()
    gen_bells_traps_power()


# Crate jingle: Herr Tamtam's tin-drum march under a music-box tune. Original, D major, 120 BPM.
CRATE_TUNE = [("D5", 0.5), ("F#5", 0.5), ("A5", 0.5), ("F#5", 0.5), ("G5", 0.5), ("E5", 0.5), ("C#5", 0.5), ("E5", 0.5),
              ("F#5", 0.5), ("D5", 0.5), ("B4", 0.5), ("D5", 0.5), ("E5", 0.5), ("A4", 0.5), ("C#5", 0.5), ("E5", 0.5), ("D5", 1.0)]
TAMTAM = [0.0, 0.5, 1.0, 1.25, 1.5]      # "tam - tam, ta-ta-tam" per 2-beat cell


def gen_crate():
    ws = dict(bus="SFX", attenuation="world", pitch=[1.0, 1.0])
    r = rng_for("crate_jingle")
    beat = 0.5
    x = zeros(5.2)
    t = 0.0
    for name, b in CRATE_TUNE:
        place(x, music_box(r, hz(name), 1.4), t, 0.8)
        t += b * beat
    for cell in range(4):
        for k, off in enumerate(TAMTAM):
            place(x, tin_drum(r, 0.8 if k in (0, 4) else 0.5), cell * 1.0 + off * beat, 0.5)
    for k in range(5):                       # little roll into the final hit
        place(x, tin_drum(r, 0.3 + 0.08 * k), 3.8 + k * 0.035, 0.4)
    place(x, tin_drum(r, 1.0), 4.0, 0.6)
    x = reverb(lp(x, 9000), r, 0.6, 0.18, 7000)
    emit("crate_jingle", "sfx/world/crate_jingle_01", fit(x, 5.2), -2.0, volume_db=-4.0, max_voices=1, **ws)
    r = rng_for("crate_drummer")              # Herr Tamtam's 4-bar cadence (crate leaving), minor fragment
    x = zeros(4.4)
    for bar in range(4):
        for k, off in enumerate(TAMTAM):
            place(x, tin_drum(r, 0.9 if k in (0, 4) else 0.55), bar * 0.9 + off * 0.45, 0.7)
    for k, nm in enumerate(["A5", "F5", "E5", "D5", "C#5", "D5"]):
        place(x, music_box(r, hz(nm), 1.4), 0.2 + k * 0.55, 0.5)
    emit("crate_drummer", "sfx/world/crate_drummer_01", reverb(x, r, 0.7, 0.2, 7000)[:N(4.4)], -2.0, volume_db=-2.0, max_voices=1, **ws)
    r = rng_for("crate_open")
    x = zeros(1.2)
    place(x, mech_click(r, 1100, 0.1, 0.01), 0.0, 0.8)
    cd = 0.7
    rate = 35 + 25 * smooth_rand(r, cd, 4, 0, 1)
    stick = np.zeros(N(cd))
    idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
    stick[idx] = r.uniform(0.4, 1.0, len(idx))
    creak = reson(stick, 560, 6) + 0.7 * reson(stick, 1300, 8)
    place(x, nrm(creak) * adsr(N(cd), 0.05, 0, 1, 0.2), 0.08, 0.5)
    place(x, kick(r, 0.6, 140, 70, 0.06, 0.3), 0.8, 0.6)
    emit("crate_open", "sfx/world/crate_open_01", reverb(x, r, 0.5, 0.15), -2.0, volume_db=-3.0, max_voices=1, **ws)
    r = rng_for("crate_result")
    x = zeros(1.6)
    for k, nm in enumerate(["D5", "F#5", "A5", "D6"]):
        place(x, music_box(r, hz(nm), 1.4), k * 0.05, 0.6)
        place(x, piano(r, hz(nm) / 2, 1.2, 0.8), k * 0.05, 0.25)
    place(x, tin_drum(r, 1.0), 0.0, 0.5)
    emit("crate_result", "sfx/world/crate_result_01", reverb(x, r, 0.8, 0.2), -2.0, volume_db=-4.0, max_voices=1, **ws)
    r = rng_for("crate_move")
    x = zeros(2.6)
    for k, nm in enumerate(["A5", "G5", "F5", "E5", "D5", "C#5", "Bb4", "A4"]):
        place(x, music_box(r, hz(nm) * (1 - 0.01 * k), 1.0), k * 0.18, 0.5)
    place(x, sweep_noise(r, 2.0, 2500, 300, 3) * adsr(N(2.0), 0.3, 0, 1, 0.8), 0.2, 0.3)
    emit("crate_move", "sfx/world/crate_move_01", reverb(x, r, 1.0, 0.25), -2.0, volume_db=-4.0, max_voices=1, **ws)


PERK_ROOTS = {"ironhide_stout": "Bb2", "second_wind": "F3", "trigger_tonic": "Eb3", "twin_barrel": "D3",
              "marathon_malt": "G2", "hawkeye_brandy": "C3", "packmule_porter": "A2", "blastproof_bock": "F2",
              "overclock_cordial": "F#2",   # the cracked reed's note: this Plan never resolves
              "skyhook_sekt": "A2", "magpie_mead": "G2", "ledger_lager": "F2",   # T-105, T-141
              "rocket_man": "C3"}   # T-276


def gen_perks():
    for pid, root in PERK_ROOTS.items():
        r = rng_for(f"hum_{pid}")
        dur = 4.0
        n = N(dur)
        t = tax(n)
        mains = sum(a * np.sin(2 * np.pi * 50 * h * t + r.uniform(0, 6)) for h, a in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15), (6, 0.08)])
        neon = loopify(nrm(bp(white(r, dur + 0.3), 1800, 4500)), 0.3) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 50 * t))) * 0.12
        f = periodic(hz(root), dur)
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.25 * t))
        x = 0.35 * mains + neon + 0.45 * tone
        if pid == "overclock_cordial":
            # a capacitor whine wandering above the mains, and two spark-gap snaps per loop
            whine = np.sin(2 * np.pi * phase_of(2600.0 * (1 + 0.01 * smooth_rand(r, dur, 0.7)), n)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t))
            x = x + 0.06 * whine
            for t0 in (0.9, 2.7):
                place(x, nrm(hp(white(r, 0.03), 2500)) * expenv(N(0.03), 0.004), t0, 0.35)
            x = loopify(x, 0.2)
        emit(f"perk_hum_{pid}", f"sfx/world/perks/hum_{pid}", x, -6.0, loop=True, bus="SFX", volume_db=-10.0,
             pitch=[1.0, 1.0], max_voices=1, attenuation="hum")
    for i in variants(2):
        r = rng_for(f"dispense{i}")
        x = zeros(1.8)
        place(x, kick(r, 0.8, 160, 60, 0.06, 0.3), 0.0)                   # coin-mech clunk
        place(x, mech_click(r, 1400, 0.08, 0.008), 0.0, 0.7)
        for k in range(10):                                                # chute rattle
            place(x, mech_click(r, r.uniform(900, 2200), 0.05, 0.004), 0.25 + k * 0.045 + r.uniform(0, 0.02), 0.4)
        clink = sum(np.sin(2 * np.pi * f * tax(N(0.6))) * np.exp(-tax(N(0.6)) / d) for f, d in [(2350, 0.25), (3720, 0.18), (5210, 0.1)])
        place(x, clink * attack(N(0.6), 0.0005), 0.78, 0.5)                # glass clink
        pop = nrm(hp(white(r, 0.03), 800)) * expenv(N(0.03), 0.004)
        place(x, pop, 1.25, 0.8)                                           # cap pop
        place(x, nrm(bp(white(r, 0.35), 3000, 9000)) * expenv(N(0.35), 0.12), 1.26, 0.2)  # fizz
        emit("perk_dispense", f"sfx/world/perks/dispense_{i:02d}", reverb(x, r, 0.5, 0.15), -1.0, bus="SFX", volume_db=-3.0,
             max_voices=1, attenuation="world")


def zap(r, sec: float = 0.6, big: float = 1.0):
    """A fat electric ZAP: a crack, a dropping buzz with harmonics, a downward noise sweep, a crackle tail."""
    n = N(sec)
    t = tax(n)
    x = zeros(sec)
    place(x, nrm(hp(white(r, 0.02), 1500)) * expenv(N(0.02), 0.003), 0.0, 0.9)
    f = 160.0 * np.exp(-t / 0.1) + 55.0 * big
    ph = phase_of(f, n)
    buzz = sum(a * np.sin(2 * np.pi * h * ph) for h, a in [(1, 1.0), (2, 0.6), (3, 0.45), (5, 0.3), (7, 0.2), (11, 0.1)])
    x += buzz * expenv(n, 0.07 + 0.05 * big) * 0.9
    place(x, sweep_noise(r, 0.32, 5000, 260, 3) * expenv(N(0.32), 0.08), 0.0, 0.7)
    place(x, crackle(r, sec - 0.05, 260, 1.0, 1500, 9000) * expenv(N(sec - 0.05), 0.11 * big), 0.02, 0.55)
    return reverb(sat(x, 2.2), r, 0.6, 0.2, 7000)


def bee_boop(r):
    """The tiny two-tone robotic bee-boop: a tube-and-telephone square wave, very pleased with itself."""
    x = zeros(0.3)
    for f, t0, d in [(hz("C6"), 0.0, 0.09), (hz("G5"), 0.12, 0.14)]:
        tone = lp(square(f * (1 + 0.004 * np.sin(2 * np.pi * 30 * tax(N(d)))), d), 3200, 2) * adsr(N(d), 0.004, 0.02, 0.8, 0.03)
        place(x, tone, t0, 0.8)
    return bp(x, 400, 3600, 1)


def novachord(r, f: float, sec: float, rel: float = 0.12, bright: float = 1.3):
    """The 1939 electric-organ lead: organ bars plus a filtered saw, doubled an octave down by a 'clarinet'."""
    n = N(sec + rel)
    lead = organ(r, f, sec, 0.02, rel, bright)
    sw = lp(saw(f * 1.003, sec + rel) + saw(f * 0.997, sec + rel), 2600, 2) * adsr(n, 0.015, 0.1, 0.8, rel)
    cl = sum(a * sine(f * 0.5 * h * (1 + 0.0004 * h), sec + rel) for h, a in [(1, 1.0), (3, 0.35), (5, 0.15)]) * adsr(n, 0.03, 0.1, 0.85, rel)
    return (0.7 * lead + 0.2 * sw + 0.25 * cl) * vib(r, n, 5.4, 0.003, 0.15)


def cracked_fsharp(r, f: float, sec: float = 1.5):
    """The harmonium's cracked F-sharp reed: a beating detune, an inharmonic partial, a 9 Hz flutter and a rattle."""
    n = N(sec)
    t = tax(n)
    y = organ(r, f, sec - 0.5, 0.03, 0.5, 1.4) + 0.6 * organ(r, f * 1.013, sec - 0.5, 0.03, 0.5, 1.0)
    y += 0.25 * sine(f * 1.47, sec) * adsr(n, 0.05, 0.3, 0.5, 0.5)
    y *= 1.0 + 0.22 * np.sin(2 * np.pi * 9.0 * t)
    rattle = bp(white(r, sec), 1800, 4200, 2) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 27.0 * t))) * adsr(n, 0.05, 0.2, 0.6, 0.6)
    return y * adsr(n, 0.02, 0.0, 1.0, 0.45) + 0.12 * rattle


def overclock_jingle(r, resolved: bool):
    """\"Overclock Cordial\" incipit: electric novelty swing at 152 BPM in B-flat, four bars of the organ incipit
    (JINGLES.md section 10): I Bb D F Bb, II Eb G Bb G, III F A C F, IV Bb F Bb F#. Novachord lead doubled by
    clarinet, walking bass, brushed snare, spark-gap snaps, a theremin swoop between the phrases. The last note
    is the cracked F-sharp and there is no final chord, unless `resolved` (after The Fine Print Ch. 5): then a
    B-flat major chord with Sprocket's off-key bass under it, and the bee-boop."""
    beat = 60.0 / 152.0
    bars = [["Bb4", "D5", "F5", "Bb5"], ["Eb5", "G5", "Bb5", "G5"], ["F5", "A5", "C6", "F5"], ["Bb5", "F5", "Bb5", None]]
    bass = [["Bb2", "D3", "F3", "D3"], ["Eb3", "G3", "Bb3", "G3"], ["F3", "A3", "C4", "A3"], ["Bb2", "F3", "Bb2", None]]
    total = beat * 16 + 1.8 + (1.6 if resolved else 0.0)
    x = zeros(total)
    for b, bar in enumerate(bars):
        for k, note in enumerate(bar):
            t0 = (b * 4 + k) * beat
            if note is None:
                place(x, cracked_fsharp(r, hz("F#5")), t0, 0.55)
                continue
            swing = 0.04 if k % 2 == 1 else 0.0
            place(x, novachord(r, hz(note), beat * 0.86), t0 + swing, 0.5)
            bn = bass[b][k]
            bl = sine(hz(bn), beat * 0.9) + 0.4 * sine(hz(bn) * 2, beat * 0.9)
            place(x, bl * adsr(N(beat * 0.9), 0.005, 0.12, 0.5, 0.08), t0, 0.4)
            if k in (1, 3):
                place(x, snare(r, 0.45, 190, 0.22, 0.5, 5000), t0 + 0.01, 0.35)
            else:
                place(x, kick(r, 0.5, 120, 48, 0.05, 0.25), t0, 0.35)
            if b < 3:
                place(x, nrm(hp(white(r, 0.012), 3000)) * expenv(N(0.012), 0.002), t0 + beat * 0.66, 0.2)   # spark-gap snap
    # theremin swoop between the phrases (end of bar II into bar III)
    ts = beat * 7.4
    n = N(beat * 1.2)
    curve = hz("F5") * (hz("Bb5") / hz("F5")) ** (np.linspace(0, 1, n) ** 0.7)
    th = sine(curve * (1 + 0.012 * np.sin(2 * np.pi * 6.5 * tax(n)))) * adsr(n, 0.15, 0.1, 0.9, 0.25)
    place(x, th, ts, 0.22)
    if resolved:
        t1 = beat * 16 + 1.1
        for nm in ["Bb4", "D5", "F5", "Bb5"]:
            place(x, novachord(r, hz(nm), 1.1, 0.4), t1, 0.4)
        wrong = hz("Bb2") * 1.03   # he hummed the bass line wrong; I left it in
        place(x, (sine(wrong, 1.4) + 0.3 * sine(wrong * 2, 1.4)) * adsr(N(1.4), 0.01, 0.2, 0.6, 0.4), t1, 0.45)
        place(x, bee_boop(r), t1 + 1.25, 0.5)
    return reverb(x, r, 1.1, 0.22, 7500)


def gen_overclock():
    """Overclock Cordial (T-034): the reload burst, the idle arc, the cap-off, and the machine's jingle."""
    for i in variants(2):
        r = rng_for(f"oc_burst{i}")
        emit("perk_overclock_burst", f"sfx/world/perks/overclock_burst_{i:02d}", zap(r, 0.65, 1.0 + 0.15 * i), -1.0,
             bus="SFX", volume_db=-2.0, max_voices=3, pitch=[0.94, 1.06], attenuation="loud")
    r = rng_for("oc_arc")
    x = zeros(0.16)
    place(x, nrm(hp(white(r, 0.012), 2500)) * expenv(N(0.012), 0.0025), 0.0, 1.0)
    place(x, sweep_noise(r, 0.12, 6000, 900, 4) * expenv(N(0.12), 0.03), 0.004, 0.5)
    place(x, crackle(r, 0.14, 300, 1.0, 2000, 9000) * expenv(N(0.14), 0.04), 0.01, 0.4)
    emit("perk_overclock_arc", "sfx/world/perks/overclock_arc_01", reverb(x, r, 0.4, 0.12), -2.0, bus="SFX", volume_db=-6.0,
         max_voices=2, pitch=[0.9, 1.1], attenuation="quiet")
    r = rng_for("oc_capoff")
    x = zeros(1.9)
    n = N(0.7)
    whine = np.sin(2 * np.pi * phase_of(np.geomspace(900.0, 4200.0, n), n)) * adsr(n, 0.05, 0.0, 1.0, 0.05) * (0.7 + 0.3 * np.sin(2 * np.pi * 40 * tax(n)))
    place(x, whine, 0.0, 0.35)                                   # capacitor whine rising on dispense
    place(x, zap(r, 0.55, 1.1), 0.72, 0.9)                        # the fat ZAP on cap-off
    place(x, bee_boop(r), 1.45, 0.6)                              # bee-boop (added on Helvetia Works)
    emit("perk_overclock_capoff", "sfx/world/perks/overclock_capoff_01", x, -1.0, bus="SFX", volume_db=-3.0,
         max_voices=1, pitch=[1.0, 1.0], attenuation="world")
    r = rng_for("oc_jingle")
    emit("jingle_overclock_cordial", "jingles/overclock_cordial_01", overclock_jingle(r, False), -2.0, bus="Jingles",
         volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0], attenuation="world")
    r = rng_for("oc_jingle_resolved")
    emit("jingle_overclock_cordial_resolved", "jingles/overclock_cordial_resolved_01", overclock_jingle(r, True), -2.0,
         bus="Jingles", volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0], attenuation="world")


POWERUP_CHORDS = {"resupply": ["C5", "E5", "G5", "C6"], "deaths_door": ["D4", "F4", "Ab4", "D5"],
                  "double_scrip": ["G5", "B5", "D6", "G6"], "blackout": ["C4", "Eb4", "Gb4", "A4"],
                  "fortify": ["F4", "A4", "C5", "F5"], "clearance": ["A4", "C#5", "E5", "A5"],
                  "tonic_bottle": ["Bb4", "D5", "F5", "Bb5"]}


def gen_powerups():
    ps = dict(bus="SFX", pitch=[1.0, 1.0], max_voices=2)
    r = rng_for("pu_spawn")
    x = zeros(1.8)
    for k, nm in enumerate(["A4", "D5", "E5", "A5", "D6"]):
        place(x, bell(r, hz(nm), 1.4, 0.5, 0.1, 0.6), k * 0.08, 0.35)
    place(x, sweep_noise(r, 0.9, 400, 5000, 4) * adsr(N(0.9), 0.4, 0, 1, 0.3), 0.0, 0.3)
    emit("powerup_spawn", "sfx/world/powerups/spawn_01", reverb(x, r, 1.2, 0.3, 8000), -2.0, volume_db=-3.0, attenuation="world", **ps)
    for pid, chord in POWERUP_CHORDS.items():
        r = rng_for(f"pu_{pid}")
        x = zeros(2.2)
        place(x, sweep_noise(r, 0.5, 600, 6000, 4) * adsr(N(0.5), 0.3, 0, 1, 0.1), 0.0, 0.35)
        for k, nm in enumerate(chord):
            place(x, organ(r, hz(nm), 0.9, 0.02, 0.7, 0.8), 0.45, 0.3)
            place(x, bell(r, hz(nm) * 2, 1.4, 0.6, 0.1, 0.5), 0.45 + k * 0.04, 0.2)
        if pid == "double_scrip":
            for k in range(10):
                place(x, mech_click(r, r.uniform(4500, 8000), 0.05, 0.006), 0.5 + r.uniform(0, 0.4), 0.3)
        if pid == "blackout":
            place(x, kick(r, 1.0, 80, 30, 0.5, 1.4), 0.45, 0.8)
        if pid == "deaths_door":
            place(x, bell(r, hz("D3"), 1.7, 1.5, 0.4), 0.45, 0.5)
        if pid == "fortify":
            for k in range(3):
                place(x, mech_click(r, 1250, 0.06, 0.004), 0.5 + k * 0.12, 0.6)
        if pid == "tonic_bottle":   # T-078: a cork pop and a glass chink under the chord
            place(x, kick(r, 1.0, 900, 300, 0.02, 0.05), 0.42, 0.6)
            place(x, bell(r, 3400, 0.5, 0.25, 0.05, 0.4), 0.5, 0.35)
        emit(f"powerup_grab_{pid}", f"sfx/world/powerups/grab_{pid}", reverb(x, r, 1.2, 0.25), -1.5, volume_db=-2.0, **ps)
    r = rng_for("pu_expire")
    x = zeros(1.4)
    for k, nm in enumerate(["D6", "A5", "F5", "D5"]):
        place(x, bell(r, hz(nm), 1.0, 0.4, 0.1, 0.5), k * 0.1, 0.35)
    place(x, sweep_noise(r, 0.8, 5000, 400, 4) * adsr(N(0.8), 0.05, 0, 1, 0.6), 0.0, 0.25)
    emit("powerup_expire", "sfx/world/powerups/expire_01", reverb(x, r, 1.0, 0.25), -2.0, volume_db=-6.0, attenuation="world", **ps)
    r = rng_for("pu_end")
    x = zeros(1.2)
    place(x, mech_click(r, 1800, 0.08), 0.0, 0.6)
    place(x, mech_click(r, 1500, 0.08), 0.3, 0.6)
    place(x, sum(organ(r, hz(nm), 0.5, 0.02, 0.4) for nm in ["A3", "D4"]), 0.55, 0.4)
    emit("powerup_timed_end", "sfx/world/powerups/timed_end_01", reverb(x, r, 0.8, 0.2), -2.0, volume_db=-4.0, **ps)


def explosion(r, big: bool):
    dur = 3.6 if big else 2.8
    n = N(dur)
    t = tax(n)
    crack = nrm(hp(white(r, dur), 2000) * np.exp(-t / 0.004))
    cutoff = 300 + 5800 * np.exp(-t / (0.12 if not big else 0.18))
    nz = white(r, dur)
    body = np.zeros(n)
    blk = 1024
    zi = None
    for s in range(0, n, blk):            # time-varying lowpass, block-wise with carried state
        sos = _sos("lowpass", float(cutoff[s]), 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        body[s:s + blk], zi = signal.sosfilt(sos, nz[s:s + blk], zi=zi)
    body = nrm(body) * np.exp(-t / (0.45 if not big else 0.7)) * attack(n, 0.002)
    f = (36 if big else 42) + (75 if big else 65) * np.exp(-t / 0.06)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (0.45 if big else 0.32)) * attack(n, 0.001)
    debris = crackle(r, dur, 40, 1, 300, 4500) * np.clip((t - 0.15) / 0.2, 0, 1) * np.exp(-t / 0.7)
    rumble = nrm(lp(brown(r, dur), 180, 2)) * np.exp(-t / (1.0 if big else 0.7)) * attack(n, 0.02)
    x = 0.8 * crack + 1.3 * body + 0.8 * boom + 0.35 * debris + 0.5 * rumble
    x = sat(x * 1.8, 1.0)
    x = reverb(x, r, 2.4 if big else 1.8, 0.3, 2500, 0.03, bright=0.1)
    return fit(echo(x, r.uniform(0.3, 0.45), 0.18, 1200, 2), dur)


def gen_explosions():
    for i in variants(4):
        emit("grenade_explode", f"sfx/world/explosion_{i:02d}", explosion(rng_for(f"expl{i}"), False), -0.3,
             bus="SFX", volume_db=0.0, pitch=[0.94, 1.06], max_voices=4, attenuation="loud")
    for i in variants(2):
        emit("explosion_large", f"sfx/world/explosion_large_{i:02d}", explosion(rng_for(f"explL{i}"), True), -0.3,
             bus="SFX", volume_db=0.0, pitch=[0.96, 1.04], max_voices=2, attenuation="loud")


def gen_bells_traps_power():
    ws = dict(bus="SFX", attenuation="world")
    r = rng_for("chapel")
    emit("bell_toll", "sfx/world/bell_chapel_toll_01", reverb(bell(r, hz("D3"), 7.0, 3.5, 0.9), r, 3.2, 0.4, 3000, 0.04)[:N(7.5)],
         -1.0, bus="SFX", volume_db=0.0, pitch=[1.0, 1.0], max_voices=2, attenuation="loud")
    for k, nm in enumerate(["F5", "A5", "C6", "D6"], start=1):        # the 4 hidden quest bells
        r = rng_for(f"qbell{k}")
        emit(f"quest_bell_{k}", f"sfx/world/bell_quest_{k}", reverb(bell(r, hz(nm), 3.5, 1.4, 0.4), r, 1.2, 0.3)[:N(4.0)], -1.5,
             bus="SFX", volume_db=-2.0, pitch=[1.0, 1.0], max_voices=2, attenuation="loud")
    r = rng_for("cartbell")
    x = zeros(1.6)
    for k in range(3):
        place(x, bell(r, hz("B5"), 1.0, 0.4, 0.5, 1.2), k * 0.22, 0.6)
    emit("cart_bell", "sfx/world/cart_bell_01", reverb(x, r, 0.8, 0.2), -1.5, volume_db=-2.0, max_voices=2, pitch=[1.0, 1.0], **ws)
    r = rng_for("liftbell")
    emit("lift_arrive", "sfx/world/lift_arrive_01", reverb(bell(r, hz("G5"), 1.8, 0.7, 0.4), r, 1.0, 0.25)[:N(2.2)], -2.0,
         volume_db=-3.0, max_voices=1, pitch=[1.0, 1.0], **ws)
    r = rng_for("winch")
    dur = 3.0
    n = N(dur)
    t = tax(n)
    motor = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(55, 1), (110, 0.6), (165, 0.3), (330, 0.1)]) * (1 + 0.1 * np.sin(2 * np.pi * 7 * t))
    rattle = loopify(crackle(r, dur + 0.3, 30, 1, 800, 5000), 0.3)
    cable = loopify(nrm(bp(white(r, dur + 0.3), 2000, 6000)), 0.3) * 0.15
    emit("lift_winch", "sfx/world/lift_winch_01", 0.4 * motor + 0.3 * rattle + cable,
         -3.0, loop=True, volume_db=-6.0, max_voices=1, pitch=[1.0, 1.0], **ws)
    r = rng_for("wirebuzz")
    dur = 1.5
    n = N(dur)
    t = tax(n)
    buzz = lp(square(np.full(n, 100.0)) + 0.5 * saw(np.full(n, 200.3)), 3000)
    arcs = crackle(r, dur, 60, 1, 2000, 12000)
    emit("wire_buzz", "sfx/world/traps/wire_buzz_01", (0.5 * buzz * (0.7 + 0.3 * smooth_rand(r, dur, 20, 0, 1)) + 0.5 * arcs) * adsr(n, 0.02, 0, 1, 0.1),
         -2.0, volume_db=-3.0, max_voices=2, pitch=[0.98, 1.02], **ws)
    for i in variants(3):
        r = rng_for(f"zap{i}")
        dur = 0.6
        n = N(dur)
        t = tax(n)
        x = nrm(hp(white(r, dur), 1500)) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(60 + 400 * r.random(n)) / SR))) * np.exp(-t / 0.15)
        x += 0.6 * lp(square(np.full(n, 120.0)), 2500) * np.exp(-t / 0.2)
        emit("wire_zap", f"sfx/world/traps/wire_zap_{i:02d}", x, -1.5, volume_db=-3.0, max_voices=3, pitch=[0.95, 1.05], **ws)
    r = rng_for("cart")
    dur = 0.36 * 8
    x = loopify(nrm(lp(brown(r, dur + 0.4), 250)), 0.4) * 0.8
    for k in range(8):
        place_wrap(x, mech_click(r, 900, 0.1, 0.01) * 0.6 + thunk(r, 120, 0.03, 0.1) * 0.5, k * 0.36, 1.0)
        place_wrap(x, mech_click(r, 950, 0.1, 0.01) * 0.4, k * 0.36 + 0.09, 1.0)
    emit("ore_cart_rumble", "sfx/world/traps/ore_cart_rumble_01", x, -2.0, loop=True,
         bus="SFX", volume_db=-2.0, max_voices=2, pitch=[1.0, 1.0], attenuation="loud")
    r = rng_for("chandelier")
    x = zeros(2.5)
    place(x, wood_crack(r, 0.8, 10), 0.0, 0.8)
    for k in range(40):
        g = reson(white(r, 0.15) * expenv(N(0.15), 0.003), r.uniform(2000, 10000), r.uniform(30, 90))
        place(x, nrm(g) * expenv(N(0.15), r.uniform(0.04, 0.12)), r.uniform(0.0, 0.7), r.uniform(0.1, 0.6))
    place(x, kick(r, 1.0, 90, 35, 0.3, 1.0), 0.0, 0.8)
    emit("chandelier_crash", "sfx/world/traps/chandelier_crash_01", reverb(x, r, 1.6, 0.3), -1.0, bus="SFX", volume_db=0.0,
         max_voices=1, attenuation="loud", pitch=[1.0, 1.0])
    # Power-on: lever slam, then turbine spin-up (30 -> 120 Hz) with a whine, settling into hum.
    r = rng_for("poweron")
    dur = 8.0
    n = N(dur)
    t = tax(n)
    x = zeros(dur)
    place(x, kick(r, 1.0, 120, 40, 0.2, 0.8), 0.0)
    place(x, mech_click(r, 900, 0.3, 0.03), 0.0, 0.8)
    s0 = 1.2
    ts = np.clip(t - s0, 0, None)
    rise = np.clip(ts / 4.0, 0, 1) ** 0.7
    f = 30 + 90 * rise
    spin = sum(a * np.sin(2 * np.pi * np.cumsum(f * h) / SR) for h, a in [(1, 1.0), (2, 0.5), (3, 0.25)])
    whine = 0.15 * np.sin(2 * np.pi * np.cumsum(400 + 1200 * rise) / SR)
    air = nrm(bp(white(r, dur), 300, 3000)) * 0.2
    env = np.where(t < s0, 0.0, np.clip(ts / 1.5, 0, 1)) * np.where(t > dur - 1.5, (dur - t) / 1.5, 1.0)
    x += (0.6 * spin + whine + air) * env
    emit("power_on", "sfx/world/power_on_01", reverb(x, r, 2.0, 0.3, 3000), -1.0, bus="SFX", volume_db=-1.0, max_voices=1,
         pitch=[1.0, 1.0])
    # radio static + tuning sweep
    r = rng_for("static")
    dur = 3.0
    st = nrm(bp(white(r, dur + 0.3), 400, 5000)) * (0.7 + 0.3 * smooth_rand(r, dur + 0.3, 8, 0, 1)) + 0.3 * crackle(r, dur + 0.3, 30)
    emit("radio_static", "sfx/world/radio_static_01", loopify(st, 0.3), -4.0, loop=True, volume_db=-8.0, max_voices=2, pitch=[1.0, 1.0], **ws)
    r = rng_for("tune")
    dur = 1.0
    n = N(dur)
    t = tax(n)
    whistle = np.sin(2 * np.pi * np.cumsum(600 + 1800 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.8 * t))) / SR) * 0.3
    emit("radio_tune", "sfx/world/radio_tune_01", (whistle + nrm(bp(white(r, dur), 500, 4000)) * 0.4) * adsr(n, 0.05, 0, 1, 0.2), -3.0,
         volume_db=-6.0, max_voices=1, pitch=[0.95, 1.05], **ws)
    # pylon: hum loop + attunement chord (D / F / A -> D minor)
    r = rng_for("pylon")
    dur = 4.0
    t = tax(N(dur))
    hum = sum(np.sin(2 * np.pi * periodic(f, dur) * t) * a for f, a in [(73.42, 1.0), (146.83, 0.4), (220.0, 0.15), (293.66, 0.1)]) * (1 + 0.15 * np.sin(2 * np.pi * 0.5 * t))
    hum += 0.08 * loopify(nrm(bp(white(r, dur + 0.3), 3000, 8000)), 0.3) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.75 * t))
    emit("pylon_hum", "sfx/world/pylon_hum_01", hum, -5.0, loop=True, volume_db=-8.0, max_voices=3, pitch=[1.0, 1.0], **ws)
    for nm in ["D", "F", "A"]:
        r = rng_for(f"attune{nm}")
        x = zeros(4.5)
        f = hz(nm + "4")
        place(x, strings(r, f, 2.5, 0.05, 1.5, 3000) + 0.6 * bell(r, f * 2, 4.0, 1.5, 0.2) + 0.4 * organ(r, f / 2, 2.5, 0.05, 1.5), 0.0)
        emit(f"pylon_attune_{nm.lower()}", f"sfx/world/pylon_attune_{nm.lower()}", reverb(x, r, 2.0, 0.35)[:N(5.0)], -1.5,
             bus="SFX", volume_db=-2.0, max_voices=1, pitch=[1.0, 1.0], attenuation="loud")
    # crucible forge roar
    for i in variants(2):
        r = rng_for(f"forge{i}")
        dur = 2.6
        x = fit(nrm(lp(brown(r, dur), 700)) * adsr(N(dur), 0.3, 0.3, 0.7, 0.8), dur) + 0.3 * crackle(r, dur, 25, 1, 600, 5000)
        x += 0.5 * kick(r, 0.8, 90, 35, 0.4, dur)
        emit("crucible_roar", f"sfx/world/crucible_roar_{i:02d}", reverb(x, r, 1.4, 0.3), -1.0, bus="SFX", volume_db=-2.0, max_voices=1,
             attenuation="loud")
    # T-175: the Crucible room's bed: the machine's own hum (a low furnace drone on A1 with a slow beat between two
    # detuned partials, a faint glassy shimmer for the Nachtglas, a soft fire breath), looped; and the steam valves'
    # hiss when a weapon goes in or comes out
    r = rng_for("crucible_hum")
    dur = 6.0
    t = tax(N(dur))
    drone = sum(np.sin(2 * np.pi * periodic(f, dur) * t) * a for f, a in [(55.0, 1.0), (55.0 * 1.005, 0.6), (110.0, 0.35), (165.0, 0.12)])
    drone *= 1.0 + 0.12 * np.sin(2 * np.pi * periodic(0.5, dur) * t)
    glass = sum(np.sin(2 * np.pi * periodic(f, dur) * t) * a for f, a in [(880.0, 0.03), (1318.5, 0.02)]) * (0.5 + 0.5 * np.sin(2 * np.pi * periodic(1 / 3, dur) * t))
    breath = 0.18 * loopify(nrm(lp(brown(r, dur + 0.3), 300)), 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * periodic(0.25, dur) * t))
    emit("crucible_hum", "sfx/world/crucible_hum_01", drone + glass + breath, -6.0, loop=True, bus="SFX", volume_db=-8.0, max_voices=2,
         pitch=[1.0, 1.0], attenuation="world")
    for i in variants(2):
        r = rng_for(f"crucible_hiss{i}")
        dur = 1.6 + 0.3 * i
        x = nrm(bp(white(r, dur), 1800, 9000)) * adsr(N(dur), 0.02, 0.2, 0.6, 0.9) * (0.8 + 0.2 * smooth_rand(r, dur, 12, 0, 1))
        x += 0.25 * nrm(lp(brown(r, dur), 400)) * adsr(N(dur), 0.05, 0.3, 0.4, 0.8)
        emit("crucible_hiss", f"sfx/world/crucible_hiss_{i:02d}", reverb(x, r, 0.8, 0.2), -3.0, bus="SFX", volume_db=-6.0, max_voices=2,
             pitch=[0.92, 1.08], attenuation="world")
    # small pickups
    r = rng_for("paper")
    x = zeros(0.6)
    for k in range(6):
        cr = nrm(bp(white(r, 0.08), 1500, 8000)) * adsr(N(0.08), 0.01, 0, 1, 0.05)
        place(x, cr, r.uniform(0, 0.4), r.uniform(0.3, 0.8))
    emit("intel_pickup", "sfx/world/intel_pickup_01", x, -3.0, bus="SFX", volume_db=-4.0, max_voices=1, pitch=[0.95, 1.05])
    r = rng_for("itempick")
    x = zeros(1.0)
    place(x, mech_click(r, 2000, 0.08), 0.0, 0.6)
    place(x, bell(r, hz("A5"), 0.9, 0.35, 0.1), 0.02, 0.4)
    emit("item_pickup", "sfx/world/item_pickup_01", reverb(x, r, 0.6, 0.2), -2.0, bus="SFX", volume_db=-3.0, max_voices=1)
    for i in variants(2):
        r = rng_for(f"buildpart{i}")
        x = zeros(0.6)
        place(x, thunk(r, 180, 0.04, 0.2), 0.0, 0.8)
        place(x, mech_click(r, 1300, 0.1, 0.008), 0.0, 0.8)
        place(x, mech_click(r, 2600, 0.05), 0.12, 0.5)
        emit("build_part", f"sfx/world/build_part_{i:02d}", reverb(x, r, 0.5, 0.15), -2.0, bus="SFX", volume_db=-3.0, max_voices=2,
             attenuation="world")
    # UI
    for name, f, d in [("ui_click", 2600, 0.04), ("ui_back", 1500, 0.06)]:
        r = rng_for(name)
        x = zeros(0.12)
        place(x, mech_click(r, f, d, 0.003), 0.0)
        emit(name, f"sfx/ui/{name[3:]}_01", x, -4.0, bus="SFX", volume_db=-8.0, max_voices=2, pitch=[0.98, 1.02])
    r = rng_for("ui_confirm")
    x = zeros(0.5)
    place(x, mech_click(r, 2200, 0.05, 0.003), 0.0)
    place(x, music_box(r, hz("A5"), 0.5), 0.02, 0.4)
    emit("ui_confirm", "sfx/ui/confirm_01", x, -4.0, bus="SFX", volume_db=-8.0, max_voices=2, pitch=[1.0, 1.0])
    r = rng_for("rankup")
    x = zeros(2.5)
    for k, nm in enumerate(["D5", "F#5", "A5", "D6"]):
        place(x, bell(r, hz(nm), 2.0, 0.8, 0.15), k * 0.12, 0.4)
    place(x, sum(organ(r, hz(nm), 1.2, 0.05, 0.8) for nm in ["D3", "A3", "F#4"]), 0.36, 0.4)
    emit("ui_rank_up", "sfx/ui/rank_up_01", reverb(x, r, 1.2, 0.3)[:N(3.0)], -2.0, bus="SFX", volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0])
    r = rng_for("challenge")
    x = zeros(1.6)
    for k, nm in enumerate(["A5", "E6"]):
        place(x, bell(r, hz(nm), 1.4, 0.6, 0.15), k * 0.1, 0.5)
    emit("ui_challenge", "sfx/ui/challenge_01", reverb(x, r, 1.0, 0.25)[:N(2.0)], -2.0, bus="SFX", volume_db=-5.0, max_voices=1, pitch=[1.0, 1.0])


# ═════════════════════════════════════════════════════════════════ AMBIENCE

def wind_bed(r, sec: float, strength: float = 1.0):
    """Stereo winter wind: pink noise through slowly gliding resonant bands, gust envelope."""
    out = np.zeros((N(sec), 2))
    for c in range(2):
        gust = 0.35 + 0.65 * (0.5 + 0.5 * smooth_rand(r, sec, 0.12)) ** 1.5
        gust2 = 0.5 + 0.5 * smooth_rand(r, sec, 0.7, 0, 1)
        base = lp(pink(r, sec), 900, 2) * (0.6 + 0.4 * gust)
        howl_c = 320 + 380 * gust * gust2
        howl = sweep_noise(r, sec, 300, 800, 9, 10, curve=howl_c) * gust ** 1.4
        whistle_c = 1300 + 1200 * gust
        whistle = sweep_noise(r, sec, 1200, 2600, 14, 8, curve=whistle_c) * np.clip(gust - 0.55, 0, 1) * 1.8
        out[:, c] = 0.7 * nrm(base) + 0.45 * howl + 0.12 * whistle
    out[:, 1] = 0.75 * out[:, 1] + 0.25 * out[:, 0]
    return out * strength


def gen_ambience():
    loop_len = 64.0
    xf = 3.0
    total = loop_len + xf
    # Map 0: Crossroads Inn — winter wind, the burning C-47 (distant roar + crackle), the odd shutter creak.
    r = rng_for("amb_map00")
    x = wind_bed(r, total)
    roar = nrm(lp(brown(r, total), 260, 2)) * (0.7 + 0.3 * smooth_rand(r, total, 0.4, 0, 1))
    fire = 0.6 * crackle(r, total, 7, 1.0, 500, 4500) + 0.25 * crackle(r, total, 40, 1.0, 1500, 7000)
    x += pan(0.18 * roar + 0.22 * fire, 0.45)
    for k in range(6):                      # shutter / signpost creak, far away
        cd = r.uniform(0.6, 1.1)
        rate = 30 + 30 * smooth_rand(r, cd, 3, 0, 1)
        stick = np.zeros(N(cd))
        idx = np.nonzero(np.diff(np.floor(np.cumsum(rate) / SR)) > 0)[0]
        stick[idx] = r.uniform(0.4, 1.0, len(idx))
        creak = lp(reson(stick, r.uniform(500, 800), 7) + 0.6 * reson(stick, 1400, 9), 2500)
        place(x, pan(nrm(creak) * adsr(N(cd), 0.1, 0, 1, 0.3) * 0.08, r.uniform(-0.8, 0.8)), r.uniform(2, total - 3))
    x = reverb(x, r, 2.5, 0.2, 2500, 0.03, stereo=True)[:N(total)]
    emit("ambient_map00", "sfx/ambience/map00_crossroads_bed", loopify(x, xf), -4.0, loop=True, bus="Ambience",
         volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)
    # Map 1: Kaltenbrunn — mine drone, drips, machinery hum, far clanks, faint Nachtglas tritone.
    r = rng_for("amb_map01")
    t = tax(N(total))
    drone = (np.sin(2 * np.pi * 41.2 * t) + 0.6 * np.sin(2 * np.pi * 41.45 * t) + 0.4 * np.sin(2 * np.pi * 82.4 * t)) * (0.8 + 0.2 * smooth_rand(r, total, 0.1, 0, 1))
    rumble = nrm(lp(brown(r, total), 120, 2))
    mach = sum(a * np.sin(2 * np.pi * 50 * h * t + r.uniform(0, 6)) for h, a in [(1, 1.0), (2, 0.5), (3, 0.35), (4, 0.2), (6, 0.1)])
    mach *= 0.6 + 0.4 * np.sin(2 * np.pi * t / 8.0) ** 2
    trit = (np.sin(2 * np.pi * 146.83 * t) + np.sin(2 * np.pi * 207.65 * t)) * (0.5 + 0.5 * smooth_rand(r, total, 0.05, 0, 1)) ** 2
    bed = 0.12 * drone + 0.22 * rumble + 0.05 * mach + 0.03 * trit
    x = to_stereo(bed) * 1.0
    for c in range(2):                          # cave air: slow-breathing mid-band noise
        air = nrm(bp(pink(r, total), 150, 1400)) * (0.6 + 0.4 * smooth_rand(r, total, 0.08, 0, 1))
        x[:, c] += 0.12 * air
    events = np.zeros((N(total), 2))
    for k in range(int(total * 0.8)):           # drips
        d = 0.05
        f0 = r.uniform(900, 1700)
        chirp = np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f0 * 2.2, N(d))) / SR) * expenv(N(d), 0.012)
        place(events, pan(chirp * r.uniform(0.08, 0.35), r.uniform(-0.9, 0.9)), r.uniform(0, total - 0.1))
    tc = r.uniform(0.5, 2.0)
    while tc < total - 1.0:                     # far machinery clanks
        clank = mech_click(r, r.uniform(500, 900), 0.3, 0.03) + 0.5 * thunk(r, 90, 0.08, 0.3)
        place(events, pan(clank * r.uniform(0.06, 0.15), r.uniform(-0.6, 0.6)), tc)
        tc += r.uniform(2.0, 5.0)
    events = lp(reverb(events, r, 3.6, 0.55, 3000, 0.05, stereo=True), 5000)[:N(total)]
    x = x + events
    emit("ambient_map01", "sfx/ambience/map01_kaltenbrunn_bed", loopify(x, xf), -4.0, loop=True, bus="Ambience",
         volume_db=0.0, pitch=[1.0, 1.0], max_voices=1)
    # Map 0's Old Cellar (Update 02 section 6.1): single drips into a puddle under a stone vault (DripPoint plays one
    # per drop): a rising plip, a tiny low "bloop" body, a short wet room tail.
    for i in variants(4):
        r = rng_for(f"cellar_drip{i}")
        d = 0.06
        f0 = r.uniform(1000, 1600)
        plip = np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f0 * r.uniform(1.9, 2.6), N(d))) / SR) * expenv(N(d), 0.014)
        body = np.sin(2 * np.pi * np.cumsum(np.linspace(r.uniform(260, 380), 520, N(0.05))) / SR) * expenv(N(0.05), 0.012) * 0.35
        x = zeros(0.9)
        place(x, plip, 0.005)
        place(x, body, 0.008)
        place(x, nrm(hp(white(r, 0.012), 3000)) * expenv(N(0.012), 0.002) * 0.15, 0.0)
        x = lp(reverb(x, r, 0.9, 0.35, 4000, 0.02), 7000)[:N(0.9)]
        emit("cellar_drip", f"sfx/world/cellar_drip_{i:02d}", x, -3.0, bus="Ambience", volume_db=-6.0, max_voices=3,
             attenuation="quiet", pitch=[0.92, 1.1])


# ═════════════════════════════════════════════════════════════════ MUSIC (all original)

def brass_cluster(r, notes: list[str], sec: float, swell: float):
    n = N(sec)
    y = np.zeros(n)
    for nm in notes:
        f = hz(nm)
        fr = f * vib(r, n, 4.5, 0.002, 0.5)
        y += saw(fr, None, r.uniform()) + 0.6 * saw(fr * 1.003, None, r.uniform())
    env = np.clip(tax(n) / swell, 0, 1) ** 2
    cutoff_open = 250 + 1500 * env
    out = np.zeros(n)
    blk = 1024
    zi = None
    for s in range(0, n, blk):
        sos = _sos("lowpass", float(cutoff_open[s]), 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[s:s + blk], zi = signal.sosfilt(sos, y[s:s + blk], zi=zi)
    return out * env / len(notes)


def choir_grunt(r):
    dur = 0.6
    f0 = pitch_curve(r, dur, hz("D3"), [(0, 1.02), (1, 0.95)], 0.01, 5, 0.005)
    y = np.zeros(N(dur))
    for k, m in enumerate([1.0, 1.5, 2.0, 0.5]):
        y += voice(r, dur, f0 * m * r.uniform(0.995, 1.005), ["ah", "o"], 1.0, 0.4, 0.2, 0.0, 1.5)
    return y * adsr(N(dur), 0.01, 0.1, 0.7, 0.3) / 3.0


def round_start(r, tier: int):
    """'The march resumes.' tier: 1 sparse, 2 default, 10 + choir grunt, 20 + double-time snare, 30 + reversed scream."""
    dur = 4.6
    db = 2.4                                       # downbeat (data: music.stinger_downbeat.round_start)
    x = zeros(dur, stereo=True)
    step = 0.16 if tier < 20 else 0.08            # slightly too slow field-drum roll
    tt = 0.15
    while tt < db - 0.05:
        vel = 0.15 + 0.6 * (tt / db) ** 1.6
        place(x, pan(snare(r, vel * r.uniform(0.85, 1.0), 175, 0.25, 0.9, 5500), -0.2), tt)
        tt += step * r.uniform(0.95, 1.06)
    place(x, pan(snare(r, 1.0, 165, 0.4, 1.0, 5000), -0.2), db)
    if tier == 1:
        place(x, wind_bed(r, dur, 0.25), 0.0)
        place(x, pan(kick(r, 0.8, 90, 40, 0.4, 1.5), 0.0), db)
    else:
        sub = np.sin(2 * np.pi * hz("D2") * tax(N(dur))) * np.clip(tax(N(dur)) / 1.5, 0, 1) * np.clip((dur - tax(N(dur))) / 1.0, 0, 1)
        place(x, to_stereo(0.35 * sub), 0.0)
        swell = brass_cluster(r, ["D2", "A2", "C3", "Eb3"], db, db)
        place(x, pan(swell * 0.9, 0.15), 0.0)
        hit = brass_cluster(r, ["D2", "D3", "Eb3", "A3"], dur - db, 0.05) * np.exp(-tax(N(dur - db)) / 1.0)
        place(x, pan(hit, -0.1), db, 1.1)
        place(x, pan(kick(r, 1.0, 80, 35, 0.6, 2.0), 0.0), db)
        place(x, to_stereo(bell(r, hz("D3"), 2.0, 1.5, 0.0) * 0.2), db)       # bell fundamental, felt not struck
    if tier >= 10:
        place(x, pan(choir_grunt(r), 0.1), db - 0.02, 0.9)
    if tier >= 30:
        sc = ganger_attack(r, 3)
        sc = nrm(sc[::-1]) * np.linspace(0, 1, len(sc)) ** 2
        place(x, pan(sc * 0.5, 0.3), db - len(sc) / SR)
    x = period(x, 90, 6000, 0.6)
    return fit(reverb(x, r, 2.0, 0.28, 3500, 0.02, stereo=True), dur)


# Round-end "needle lifts" waltz: original 4-bar phrase, A minor, 3/4, 132 BPM. (note, beats)
WALTZ = [("E5", 2), ("C5", 1), ("B4", 1), ("A4", 1), ("G#4", 1), ("A4", 1), ("C5", 1), ("F5", 1), ("E5", 3)]
WALTZ_BASS = [("A2", ["C4", "E4"]), ("E2", ["B3", "D4", "G#4"]), ("D2", ["F4", "A4"]), ("A2", ["C4", "E4"])]


def waltz_phrase(r, hum: bool = False):
    beat = 60.0 / 132.0
    total = 12 * beat
    x = zeros(total + 1.5)
    t = 0.0
    for nm, b in WALTZ:
        if hum:
            n = N(b * beat + 0.1)
            f0 = hz(nm) * vib(r, n, 5.0, 0.01, 0.1)
            v = voice(r, n / SR, f0, ["m", "m"], 1.25, 0.12, 0.05, 0, 1.0) * adsr(n, 0.05, 0, 1, 0.08)
            place(x, v, t, 0.6)
        else:
            place(x, violin(r, hz(nm), b * beat * 0.95), t, 0.5)
        t += b * beat
    if not hum:
        for bar, (bass, chord) in enumerate(WALTZ_BASS):
            t0 = bar * 3 * beat
            place(x, piano(r, hz(bass), 1.2, 1.0), t0, 0.5)
            for k in (1, 2):
                for nm in chord:
                    place(x, piano(r, hz(nm), 0.6, 0.5, 0.7), t0 + k * beat, 0.22)
    return x


def round_end(r, variant: str):
    dur = 6.6
    x = waltz_phrase(r, hum=(variant == "late"))
    n = len(x)
    t = tax(n)
    slow_from = 2.8
    rate = np.where(t < slow_from, 1.0, np.maximum(0.2, 1.0 - 0.8 * (np.clip(t - slow_from, 0, None) / 2.6) ** 1.3))
    y = varispeed(x, rate)
    y = fit(y, dur)
    y *= np.clip((dur - 0.6 - tax(N(dur))) / 1.6, 0, 1)
    y = period(y, 250, 4000, 0.15)
    y = sat(nrm(y) * 1.2, 1.0)
    out = to_stereo(y) * 0.8
    crack_bed = crackle(r, dur, 22, 1.0, 1200, 8000) * 0.12 + 0.015 * bp(white(r, dur), 2000, 7000)
    out += to_stereo(crack_bed * np.clip(tax(N(dur)) / 0.3, 0, 1))
    if variant == "special":
        place(out, to_stereo(bell(r, hz("D3"), 5.0, 2.8, 0.7) * 0.5), 1.0)
    return fit(reverb(out, r, 1.4, 0.2, 4000, 0.02, stereo=True), dur)


def special_stinger(r):
    dur = 8.5
    x = zeros(dur, stereo=True)
    for k in range(3):
        b = bell(r, hz("D3"), 2.4, 3.0, 0.9, gate=0.75)          # decay gated short: air sucked out
        place(x, to_stereo(b), 0.1 + 2.1 * k, 0.8)
    fog = wind_bed(r, dur, 1.0)
    fog *= (np.linspace(0, 1, N(dur)) ** 2)[:, None] * 0.5
    place(x, fog, 0.0)
    ts = tax(N(3.0))
    sub = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-ts / 1.2) + 26) / SR) * np.clip(ts / 0.3, 0, 1) * np.exp(-ts / 1.8)
    place(x, to_stereo(sub * 0.9 + 0.3 * nrm(lp(brown(r, 3.0), 150)) * np.exp(-ts / 1.5)), 4.3)
    return fit(reverb(x, r, 2.6, 0.3, 3000, 0.03, stereo=True), dur)


def game_over(r):
    """Low organ + strings in D minor, three tolls, and a music box quoting the toy march, out of tune."""
    dur = 17.0
    x = zeros(dur, stereo=True)
    chords = [(0.0, 4.2, ["D2", "A2", "D3", "F3", "A3"]), (4.0, 3.8, ["Bb1", "F2", "D3", "F3", "A3"]),
              (7.6, 3.6, ["G1", "D2", "Bb2", "E3", "G3"]), (11.0, 5.0, ["A1", "E2", "C#3", "G3", "Bb3"])]
    for st, ln, notes in chords:
        for k, nm in enumerate(notes):
            o = organ(r, hz(nm), ln, 0.6, 1.4, 0.6)
            s = strings(r, hz(nm) * 2 if k > 1 else hz(nm), ln, 0.9, 1.4, 1400)
            place(x, pan(0.45 * o + 0.35 * s, -0.5 + k * 0.25), st)
    for k, tt in enumerate([0.0, 5.5, 11.0]):
        place(x, to_stereo(bell(r, hz("D3"), 6.0, 3.2, 0.7) * 0.55), tt)
    mb = [("A5", 7.8), ("F5", 8.4), ("E5", 9.0), ("D5", 9.9), ("C#5", 11.2), ("E5", 12.1), ("D5", 13.4)]
    for nm, tt in mb:
        place(x, pan(music_box(r, hz(nm) * (1 + 0.012 * r.standard_normal()), 2.0), 0.35), tt, 0.35)
    x *= np.clip((dur - tax(N(dur))) / 3.0, 0, 1)[:, None]
    return fit(reverb(x, r, 3.2, 0.35, 3500, 0.03, stereo=True), dur)


def score_layer(r):
    """Looping dread layer (Music bus), volume follows round intensity. 32 s, D minor, slow inner motion."""
    loop = 32.0
    xf = 3.0
    total = loop + xf
    x = zeros(total + 2, stereo=True)
    lines = [(["D2"], [0.0], [total]), (["A2"], [0.0], [total]),
             (["F3", "E3", "F3", "G3"], [0.0, 8.0, 16.0, 24.0], [8.6, 8.6, 8.6, 11.6]),
             (["A3", "Bb3", "A3", "C#4"], [0.0, 8.0, 16.0, 24.0], [8.6, 8.6, 8.6, 11.6])]
    for li, (notes, starts, lens) in enumerate(lines):
        for nm, st, ln in zip(notes, starts, lens):
            s = strings(r, hz(nm), ln, 2.0, 2.0, 900 if li < 2 else 1300, 3, 0.008)
            place(x, pan(s, -0.6 + 0.4 * li), st, 0.5 if li < 2 else 0.3)
    for k in range(int(total / 2.0)):            # distant low drum pulse
        place(x, to_stereo(kick(r, 0.5 if k % 4 else 0.8, 70, 38, 0.35, 1.2)), k * 2.0, 0.6)
    x = reverb(x[:N(total)], r, 3.0, 0.35, 2500, 0.03, stereo=True)[:N(total)]
    return loopify(x, xf)


def menu_theme(r):
    """Main menu loop: organ pad + music box, original melody in D minor, 40 s."""
    loop = 40.0
    xf = 3.0
    total = loop + xf
    x = zeros(total + 3, stereo=True)
    prog = [["D3", "A3", "F4"], ["Bb2", "F3", "D4"], ["G2", "D3", "Bb3"], ["A2", "E3", "C#4"]]
    for k in range(int(total / 5.0) + 1):
        ch = prog[k % 4]
        for j, nm in enumerate(ch):
            place(x, pan(organ(r, hz(nm), 5.4, 1.2, 1.5, 0.5) * 0.35 + strings(r, hz(nm), 5.4, 1.5, 1.5, 1100) * 0.25, -0.4 + 0.4 * j), k * 5.0)
    mel = [("D5", 0), ("E5", 0.6), ("F5", 1.2), ("A5", 2.4), ("G5", 3.6), ("F5", 4.2), ("E5", 5.0), ("D5", 6.2),
           ("C#5", 7.4), ("E5", 8.6), ("A4", 9.8), ("D5", 12.0), ("F5", 12.6), ("E5", 13.2), ("D5", 13.8), ("Bb4", 15.0),
           ("A4", 16.2), ("G4", 17.4), ("A4", 18.6), ("D5", 20.0)]
    for rep in range(2):
        for nm, tt in mel:
            place(x, pan(music_box(r, hz(nm) * (1 + 0.004 * r.standard_normal()), 2.0), 0.3), rep * 20.0 + tt + 0.2, 0.3)
    x = reverb(x[:N(total)], r, 2.8, 0.35, 4000, 0.03, stereo=True)[:N(total)]
    x += to_stereo(0.04 * crackle(r, total, 10, 1.0, 1500, 7000))
    return loopify(x, xf)


def gen_music():
    ms = dict(bus="Music", pitch=[1.0, 1.0], max_voices=1, vol_jitter_db=0.0)
    for tier, suffix in [(1, "_r01"), (2, ""), (10, "_r10"), (20, "_r20"), (30, "_r30")]:
        emit(f"stinger_round_start{suffix}", f"music/stinger_round_start{suffix}", round_start(rng_for(f"rs{tier}"), tier), -1.0,
             volume_db=-2.0, **ms)
    for variant, suffix in [("normal", ""), ("special", "_special"), ("late", "_late")]:
        emit(f"stinger_round_end{suffix}", f"music/stinger_round_end{suffix}", round_end(rng_for(f"re{variant}"), variant), -1.0,
             volume_db=-3.0, **ms)
    emit("stinger_special", "music/stinger_special_round", special_stinger(rng_for("special")), -1.0, volume_db=-1.0, **ms)
    emit("stinger_game_over", "music/stinger_game_over", game_over(rng_for("gameover")), -1.0, volume_db=0.0, **ms)
    emit("score_dread", "music/score_dread_loop", score_layer(rng_for("score")), -3.0, loop=True, volume_db=0.0, **ms)
    emit("music_menu", "music/menu_theme_loop", menu_theme(rng_for("menu")), -2.0, loop=True, volume_db=-4.0, **ms)


# ═════════════════════════════════════════════════════════════════ legacy keys + manifest

def legacy_aliases():
    """Old keys called by existing code keep working, now pointing at the new files."""
    alias("gun_pistol", "fire_m1911")
    alias("gun_rifle", "fire_m1_garand")
    alias("gun_bolt", "fire_kar98k")
    alias("gun_smg", "fire_mp40")
    alias("gun_assault", "fire_stg44")
    alias("gun_lmg", "fire_bar")
    alias("gun_shotgun", "fire_trench_gun")
    alias("gun_sniper", "fire_springfield")
    alias("gun_launcher", "fire_panzerschreck")
    alias("reload_start", "reload_mag_out")
    alias("reload_end", "reload_mag_in")
    alias("bolt_cycle", "reload_bolt_cycle")
    alias("round_start", "stinger_round_start")
    alias("round_end", "stinger_round_end")
    alias("game_over", "stinger_game_over")
    alias("ambient_wind", "ambient_map00")


DEFAULT_DOC = {
    "_doc": ("AudioDirector sound bank. sounds.<key>.files are res:// WAVs; one is picked at random per play. "
             "volume_db is added to the caller's volume, vol_jitter_db is +- random dB, pitch is a [min,max] range "
             "multiplied with the caller's pitch jitter. bus: Master/Music/SFX/VO/Jingles/Ambience. max_voices: "
             "simultaneous plays of this key (the oldest is stolen). attenuation: profile in 'attenuation' used by "
             "play_3d. loop: the stream loops. Generated by tools_src/gen_audio.py (re-running only refreshes "
             "'files' of existing keys, hand tuning is kept)."),
    "pool_3d": 48,
    "pool_2d": 24,
    "defaults": {"volume_db": 0.0, "vol_jitter_db": 1.0, "pitch": [0.97, 1.03], "bus": "SFX", "max_voices": 6,
                 "attenuation": "world", "loop": False},
    "attenuation": {
        "weapon": {"unit_size": 10.0, "max_distance": 120.0, "filter_hz": 8000.0, "filter_db": -18.0},
        "zombie": {"unit_size": 4.0, "max_distance": 42.0, "filter_hz": 5000.0, "filter_db": -24.0},
        "world": {"unit_size": 5.0, "max_distance": 45.0, "filter_hz": 7000.0, "filter_db": -20.0},
        "loud": {"unit_size": 14.0, "max_distance": 150.0, "filter_hz": 9000.0, "filter_db": -16.0},
        "quiet": {"unit_size": 2.5, "max_distance": 18.0, "filter_hz": 4500.0, "filter_db": -24.0},
        "hum": {"unit_size": 1.2, "max_distance": 9.0, "filter_hz": 3000.0, "filter_db": -24.0},
    },
    "music": {
        "round_start_tiers": [[1, "stinger_round_start_r01"], [2, "stinger_round_start"], [10, "stinger_round_start_r10"],
                              [20, "stinger_round_start_r20"], [30, "stinger_round_start_r30"]],
        "round_end_tiers": [[1, "stinger_round_end"], [25, "stinger_round_end_late"]],
        "special_start": "stinger_special",
        "special_end": "stinger_round_end_special",
        "game_over": "stinger_game_over",
        "stinger_downbeat": {"stinger_round_start": 2.4, "stinger_round_start_r01": 2.4, "stinger_round_start_r10": 2.4,
                             "stinger_round_start_r20": 2.4, "stinger_round_start_r30": 2.4},
        "duck_db": -7.0,
        "ambient": {"map00_crossroads": "ambient_map00", "map01_kaltenbrunn": "ambient_map01", "default": "ambient_map00"},
        "ambient_db": [-6.0, -2.0],
        "score": "score_dread",
        "score_db": [-30.0, -13.0],
        "score_from_round": 2,
    },
    "perk_hum": {"prefix": "perk_hum_", "volume_db": -8.0, "check_seconds": 1.5},
    "events": {
        "enemy_spawned": "zombie_spawn",
        "powerup_spawned": "powerup_spawn",
        "powerup_collected_prefix": "powerup_grab_",
        "powerup_expired": "powerup_timed_end",
        "perk_bought": "perk_dispense",
        "crate_opened": "crate_jingle",
        "crate_result": "crate_result",
        "crate_drummer": "crate_drummer",
        "crate_moved": "crate_move",
        "power_activated": "power_on",
        "player_downed": "player_down",
        "player_revived": "player_revive",
        "perks_lost": "perks_lost",
        "boss_spawned": {"foreman": "foreman_roar", "screamer": "screamer_scream"},
        # no "weapon_upgraded": the Crucible plays crucible_roar itself when it starts forging
    },
}


def write_manifest():
    data = {}
    if os.path.exists(AUDIO_JSON):
        with open(AUDIO_JSON, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    for k, v in DEFAULT_DOC.items():
        data.setdefault(k, v)
    sounds = data.setdefault("sounds", {})
    for key in sorted(KEYS):
        gen = KEYS[key]
        if key in sounds:
            sounds[key]["files"] = gen["files"]
        else:
            sounds[key] = gen
    data["sounds"] = {k: sounds[k] for k in sorted(sounds)}
    text = json.dumps(data, indent=1)
    # keep short scalar arrays (pitch ranges, tier pairs, dB ranges) on one line
    text = re.sub(r"\[\s+([-\d.,\s]+|\d+,\s+\"[a-z0-9_]+\")\s+\]",
                  lambda m: "[" + ", ".join(v.strip() for v in m.group(1).split(",")) + "]", text)
    with open(AUDIO_JSON, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text + "\n")



# ════════════════════════════════════════════════════ Map 4 perks (UPDATE 07, T-105)

def skyhook_jingle(r):
    """\"Skyhook Sekt\" incipit (JINGLES.md section 14): a Viennese waltz in A at 96 BPM, four bars of the organ
    incipit (I A C# E A, II D F# A F#, III E G# B E, IV A E C# A) on strings with a clarinet-ish organ doubling,
    a glockenspiel (music box) on the up-beats, a soft kick on the one, a cork pop and a fizz at the start."""
    beat = 60.0 / 96.0
    bars = [["A4", "C#5", "E5", "A5"], ["D5", "F#5", "A5", "F#5"], ["E5", "G#5", "B5", "E5"], ["A5", "E5", "C#5", "A4"]]
    bass = ["A2", "D3", "E3", "A2"]
    total = beat * 12 + 2.4
    x = zeros(total)
    place(x, nrm(hp(white(r, 0.03), 1800)) * expenv(N(0.03), 0.006), 0.0, 0.5)          # the cork
    place(x, bp(white(r, 0.9), 3000, 9000) * adsr(N(0.9), 0.05, 0.1, 0.4, 0.5), 0.05, 0.12)   # the fizz
    for b, bar in enumerate(bars):
        t_bar = 0.35 + b * 3 * beat
        bn = bass[b]
        place(x, (sine(hz(bn), beat * 2.6) + 0.35 * sine(hz(bn) * 2, beat * 2.6)) * adsr(N(beat * 2.6), 0.01, 0.2, 0.5, 0.3), t_bar, 0.4)
        place(x, kick(r, 0.35, 95, 45, 0.08, 0.3), t_bar, 0.3)
        for k in range(3):
            if k > 0:
                place(x, music_box(r, hz(bar[k]) * 2, 0.9), t_bar + k * beat, 0.22)           # the glockenspiel on 2 and 3
            note = bar[min(k, 3)] if k < 3 else bar[3]
            place(x, strings(r, hz(note), beat * 0.95, 0.08, 0.5), t_bar + k * beat, 0.42)
            place(x, organ(r, hz(note), beat * 0.9, 0.05, 0.3, 0.8), t_bar + k * beat, 0.18)
        place(x, strings(r, hz(bar[3]), beat * 1.4, 0.05, 0.6), t_bar + 2 * beat, 0.25)       # the fourth note sings over the bar line
    place(x, bell(r, hz("A5"), 1.6, 2.5, 0.4, 0.8), 0.35 + 12 * beat, 0.3)                      # the tag's upbeat (the organ ghost)
    return reverb(x, r, 1.3, 0.28, 6500)


def magpie_jingle(r):
    """\"Magpie Mead\" incipit (JINGLES.md section 15): Western swing in G at 140 BPM, four bars of the incipit
    (I G B D G, II C E G E, III D F# A D, IV G D B G) on a plucky lead with a walking bass, a brushed snare on 2
    and 4, a fiddle-ish string swell into bar III, the lever's clunk and the reels' ticks under the first bar,
    and a bell when the reels stop."""
    beat = 60.0 / 140.0
    bars = [["G4", "B4", "D5", "G5"], ["C5", "E5", "G5", "E5"], ["D5", "F#5", "A5", "D5"], ["G5", "D5", "B4", "G4"]]
    bass = [["G2", "B2", "D3", "B2"], ["C3", "E3", "G3", "E3"], ["D3", "F#3", "A3", "F#3"], ["G2", "D3", "G2", "D3"]]
    total = beat * 16 + 2.0
    x = zeros(total)
    place(x, nrm(lp(white(r, 0.05), 900)) * expenv(N(0.05), 0.012), 0.0, 0.7)                 # the lever's clunk
    for k in range(10):
        place(x, nrm(hp(white(r, 0.008), 2500)) * expenv(N(0.008), 0.002), 0.08 + k * 0.07, 0.18)   # the reels
    for b, bar in enumerate(bars):
        for k, note in enumerate(bar):
            t0 = 0.3 + (b * 4 + k) * beat
            swing = 0.05 if k % 2 == 1 else 0.0
            place(x, piano(r, hz(note), beat * 0.8, 0.5, 0.9), t0 + swing, 0.45)             # the plucky lead
            place(x, music_box(r, hz(note) * 2, 0.5), t0 + swing, 0.08)
            bn = bass[b][k]
            place(x, (sine(hz(bn), beat * 0.9) + 0.3 * sine(hz(bn) * 2, beat * 0.9)) * adsr(N(beat * 0.9), 0.005, 0.1, 0.5, 0.1), t0, 0.42)
            if k in (1, 3):
                place(x, snare(r, 0.4, 200, 0.2, 0.3, 4500), t0 + 0.01, 0.3)
            else:
                place(x, kick(r, 0.45, 115, 46, 0.06, 0.25), t0, 0.3)
    place(x, strings(r, hz("D5"), beat * 3.0, 0.5, 0.6, 2600, 2), 0.3 + beat * 6, 0.22)      # the fiddle swell into bar III
    place(x, bell(r, hz("G6"), 1.2, 2.0, 0.5, 1.0), 0.3 + beat * 16, 0.3)                      # the reels stop: the bell
    place(x, organ(r, hz("G3"), 1.8, 0.4, 0.8, 0.5), 0.3 + beat * 15, 0.12)                    # the held G the engineer left in
    return reverb(x, r, 0.9, 0.2, 7000)


def ledger_jingle(r):
    """\"Ledger Lager\" incipit (JINGLES.md section 16): a brass-band foxtrot in F at 112 BPM in 2/4, four bars of the
    incipit (I F A C F, II Bb D F D, III C E G C, IV F C A F) on cornets, the tuba on the beats and a muted trombone on
    the off-beats, a brush snare, the drawer's bell on the downbeat and again on the tag; band-limited like a tin horn."""
    eighth = 60.0 / 112.0 / 2.0
    bars = [["F4", "A4", "C5", "F5"], ["Bb4", "D5", "F5", "D5"], ["C5", "E5", "G5", "C6"], ["F5", "C5", "A4", "F4"]]
    tuba = [["F2", "C3"], ["Bb1", "F2"], ["C2", "G2"], ["F2", "C2"]]
    total = eighth * 16 + 2.6
    x = zeros(total)
    place(x, bell(r, hz("C7"), 1.3, 1.6, 0.8, 1.4), 0.0, 0.3)                                    # the drawer's bell on the downbeat
    place(x, nrm(lp(white(r, 0.05), 700)) * expenv(N(0.05), 0.012), 0.0, 0.35)                   # the drawer slides out
    for b, bar in enumerate(bars):
        for k, note in enumerate(bar):
            t0 = 0.3 + (b * 4 + k) * eighth
            place(x, brass_cluster(r, [note], eighth * 1.7, 0.05), t0, 0.28)                      # the cornet lead
            if k % 2 == 0:
                tn = tuba[b][k // 2]
                place(x, (sine(hz(tn), eighth * 1.8) + 0.4 * sine(hz(tn) * 2, eighth * 1.8)) * adsr(N(eighth * 1.8), 0.01, 0.1, 0.6, 0.1), t0, 0.5)   # the tuba
                place(x, kick(r, 0.4, 100, 50, 0.05, 0.22), t0, 0.2)
            else:
                place(x, brass_cluster(r, [bar[0], bar[2]], eighth * 1.2, 0.04), t0, 0.14)         # the trombone off-beat
                place(x, snare(r, 0.35, 220, 0.16, 0.2, 5000), t0 + 0.005, 0.22)                  # the brush
    place(x, bell(r, hz("C7"), 1.6, 1.8, 0.8, 1.4), 0.3 + eighth * 16, 0.3)                       # the tag's bell
    place(x, brass_cluster(r, ["F3", "A3", "C4"], 1.6, 0.15), 0.3 + eighth * 16, 0.2)             # the last chord
    place(x, sine(hz("F2"), 0.7) * adsr(N(0.7), 0.01, 0.1, 0.5, 0.2), 0.3 + eighth * 17, 0.35)    # the organ ghost: the tuba's off-beat
    return reverb(bp(x, 300, 5000) * 1.4, r, 0.8, 0.18, 6000)


def gen_ledger():
    """Ledger Lager (UPDATE 09, T-141): the drawer's bell, the tally drum's click, the jingle."""
    r = rng_for("ll_drawer")
    x = zeros(1.6)
    place(x, nrm(lp(white(r, 0.06), 600)) * expenv(N(0.06), 0.015), 0.0, 0.5)                    # the drawer slides
    place(x, mech_click(r, 1700, 0.06, 0.005), 0.05, 0.6)                                           # the catch
    place(x, bell(r, hz("C7"), 1.2, 1.4, 0.9, 1.5), 0.08, 0.5)                                      # ka-ching: a real register bell
    place(x, bell(r, hz("G6"), 1.0, 1.2, 0.5, 1.3), 0.11, 0.3)
    emit("perk_ledger_drawer", "sfx/world/perks/ledger_drawer_01", reverb(x, r, 0.6, 0.15), -2.0, bus="SFX", volume_db=-4.0, max_voices=2,
         pitch=[0.98, 1.02], attenuation="world")
    r = rng_for("ll_tally")
    x = zeros(0.25)
    for k in range(3):
        place(x, mech_click(r, r.uniform(2400, 3200), 0.03, 0.003), k * 0.035, 0.5)                 # the drum turning over a digit
    emit("perk_ledger_tally", "sfx/world/perks/ledger_tally_01", x, -5.0, bus="SFX", volume_db=-9.0, max_voices=2, pitch=[0.96, 1.04],
         attenuation="quiet")
    r = rng_for("ll_jingle")
    emit("jingle_ledger_lager", "jingles/ledger_lager_01", ledger_jingle(r), -2.0, bus="Jingles", volume_db=-4.0, max_voices=1,
         pitch=[1.0, 1.0], attenuation="world")


def rocket_man_jingle(r):
    """\"Rocket Man\" (T-276, the V2 site's tonic): three ticks of a countdown on a woodblock, a muffled ignition
    thump, then a cornet fanfare climbing in C at 132 BPM (C4 E4 G4 C5, G4 C5 E5 G5, a held C6) over a timpani roll,
    while a band of noise rises under it like an engine leaving the table; ends on the woodblock's last tick."""
    beat = 60.0 / 132.0
    total = 0.9 + beat * 9 + 2.4
    x = zeros(total)
    for k in range(3):                                                                              # the countdown
        place(x, mech_click(r, 1500 - k * 120, 0.08, 0.012, 8), k * 0.3, 0.55)
    place(x, kick(r, 0.9, 80, 32, 0.35, 1.0), 0.9, 0.6)                                             # ignition
    whoosh = bp(white(r, beat * 9 + 1.5), 300, 2600)
    n = len(whoosh)
    env = np.linspace(0.0, 1.0, n) ** 1.6 * np.exp(-np.linspace(0.0, 1.0, n) * 0.4)
    place(x, nrm(whoosh) * env, 0.9, 0.16)                                                          # the engine climbing away
    notes = ["C4", "E4", "G4", "C5", "G4", "C5", "E5", "G5"]
    for k, note in enumerate(notes):
        place(x, brass_cluster(r, [note], beat * 1.1, 0.04), 1.0 + k * beat, 0.3)                   # the cornet
    place(x, brass_cluster(r, ["C5", "E5", "G5", "C6"], beat * 2.6, 0.12), 1.0 + 8 * beat, 0.32)     # the held chord
    for k in range(int(beat * 9 / 0.07)):                                                           # the timpani roll
        place(x, kick(r, 0.25 + 0.2 * (k / (beat * 9 / 0.07)), 98, 60, 0.12, 0.3), 1.0 + k * 0.07, 0.18)
    place(x, mech_click(r, 1100, 0.1, 0.02, 8), 1.0 + 9 * beat + 0.9, 0.5)                           # the last tick
    return reverb(lp(x, 7000), r, 0.9, 0.2)


def gen_rocket_man():
    """Rocket Man (T-276): the jingle (the machine's hum is in PERK_ROOTS)."""
    r = rng_for("rm_jingle")
    emit("jingle_rocket_man", "jingles/rocket_man_01", rocket_man_jingle(r), -2.0, bus="Jingles", volume_db=-4.0, max_voices=1,
         pitch=[1.0, 1.0], attenuation="world")


def gen_lodestone():
    """The Lodestone (T-105): the lift's cracked-bell ring over a sub-bass wind-up, the slam's thud-and-crack, the
    fling's rising whoosh, the fling wind-up hum, the reload's quarter turn."""
    r = rng_for("ls_lift")
    x = zeros(1.6)
    n = N(0.5)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(38.0, 70.0, n), n)) * adsr(n, 0.05, 0.1, 0.8, 0.2), 0.0, 0.6)   # the sub-bass wind-up
    place(x, bell(r, hz("F#4"), 1.3, 2.2, 0.7, 0.6), 0.35, 0.55)                                                    # the lead glass rings (a tone under the bell)
    place(x, bell(r, hz("F#4") * 1.012, 1.1, 1.8, 0.4, 0.5), 0.37, 0.3)                                              # the crack: a detuned partial
    emit("lodestone_lift", "sfx/weapons/lodestone_lift_01", reverb(x, r, 1.0, 0.25), -1.0, bus="SFX", volume_db=-2.0, max_voices=2, pitch=[0.97, 1.03], attenuation="loud")
    r = rng_for("ls_slam")
    x = zeros(1.2)
    place(x, kick(r, 1.0, 150, 36, 0.14, 0.7), 0.0, 1.0)
    place(x, nrm(lp(white(r, 0.3), 500)) * expenv(N(0.3), 0.06), 0.0, 0.7)
    place(x, crackle(r, 0.25, 400, 1.0, 1500, 6000) * expenv(N(0.25), 0.05), 0.02, 0.5)                                # the crack
    emit("lodestone_slam", "sfx/weapons/lodestone_slam_01", reverb(x, r, 0.8, 0.2), -0.5, bus="SFX", volume_db=0.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("ls_fling")
    x = zeros(1.4)
    place(x, sweep_noise(r, 1.1, 300, 4200, 3) * adsr(N(1.1), 0.1, 0.1, 0.8, 0.4), 0.0, 0.7)                            # the rising whoosh, Dopplering off
    n = N(0.9)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(90.0, 400.0, n), n)) * adsr(n, 0.02, 0.1, 0.6, 0.3), 0.0, 0.3)
    emit("lodestone_fling", "sfx/weapons/lodestone_fling_01", reverb(x, r, 0.9, 0.2), -1.0, bus="SFX", volume_db=-1.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("ls_hum")
    x = zeros(0.8)
    n = N(0.7)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(55.0, 180.0, n), n)) * adsr(n, 0.05, 0.0, 1.0, 0.1), 0.0, 0.6)   # the wind-up hum (the relay's note)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(110.0, 360.0, n), n)) * adsr(n, 0.05, 0.0, 1.0, 0.1), 0.0, 0.25)
    emit("lodestone_hum", "sfx/weapons/lodestone_hum_01", x, -3.0, bus="SFX", volume_db=-6.0, max_voices=1, pitch=[1.0, 1.0], attenuation="quiet")
    r = rng_for("ls_turn")
    x = zeros(0.5)
    for k in range(4):
        place(x, nrm(hp(white(r, 0.01), 2500)) * expenv(N(0.01), 0.003), k * 0.07, 0.4)                                # the ratchet of the quarter turn
    place(x, bell(r, hz("F#5"), 0.4, 1.5, 0.3, 0.6), 0.28, 0.3)
    emit("lodestone_turn", "sfx/weapons/lodestone_turn_01", x, -4.0, bus="SFX", volume_db=-6.0, max_voices=1, pitch=[0.98, 1.02], attenuation="quiet")


def gen_undertow():
    """THE UNDERTOW (UPDATE 10, T-153): the harpoon's pneumatic slam and the chain paying out, the reel's ratcheting
    winch, one pump stroke of the diver's pump (the reload plays it three times), the whirlpool's sucking roar,
    and a body splash (the whirl's drownings, the tide's lost drops)."""
    r = rng_for("ut_fire")
    x = zeros(1.4)
    place(x, kick(r, 1.0, 160, 45, 0.1, 0.5), 0.0, 0.8)                                                            # the pneumatic slam
    place(x, nrm(bp(white(r, 0.25), 300, 3500)) * expenv(N(0.25), 0.05), 0.0, 0.7)                                   # the air dump
    for k in range(9):
        place(x, nrm(hp(white(r, 0.012), 2200)) * expenv(N(0.012), 0.004), 0.05 + k * 0.045, 0.35 * (1.0 - k / 10.0))   # the chain paying out
    place(x, bell(r, hz("C#3"), 0.9, 1.5, 0.5, 0.4), 0.02, 0.25)                                                    # the cylinder's ring
    emit("undertow_fire", "sfx/weapons/undertow_fire_01", reverb(x, r, 0.8, 0.2), -1.0, bus="SFX", volume_db=-1.0, max_voices=2, pitch=[0.96, 1.04], attenuation="loud")
    r = rng_for("ut_reel")
    x = zeros(1.4)
    for k in range(22):
        place(x, nrm(bp(white(r, 0.015), 900, 5000)) * expenv(N(0.015), 0.005), k * 0.055, 0.45)                       # the ratchet clicks
    n = N(1.2)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(70.0, 120.0, n), n)) * adsr(n, 0.05, 0.1, 0.7, 0.3), 0.0, 0.35)   # the winch's growl
    emit("undertow_reel", "sfx/weapons/undertow_reel_01", reverb(x, r, 0.5, 0.15), -3.0, bus="SFX", volume_db=-4.0, max_voices=2, pitch=[0.97, 1.03], attenuation="world")
    r = rng_for("ut_pump")
    x = zeros(0.45)
    place(x, sweep_noise(r, 0.3, 500, 2600, 3) * adsr(N(0.3), 0.04, 0.05, 0.7, 0.15), 0.0, 0.55)                    # the air drawn in
    place(x, nrm(hp(white(r, 0.02), 1500)) * expenv(N(0.02), 0.006), 0.28, 0.6)                                     # the valve's click
    emit("undertow_pump", "sfx/weapons/undertow_pump_01", x, -4.0, bus="SFX", volume_db=-5.0, max_voices=2, pitch=[0.95, 1.05], attenuation="quiet")
    r = rng_for("ut_whirl")
    x = zeros(3.5)
    n = N(3.4)
    place(x, nrm(lp(pink(r, 3.4), 700)) * adsr(n, 0.3, 0.3, 0.8, 1.2), 0.0, 0.8)                                      # the water's roar
    place(x, sweep_noise(r, 3.4, 1500, 300, 3) * adsr(n, 0.2, 0.3, 0.6, 1.0), 0.0, 0.45)                              # the suck, falling
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(48.0, 34.0, n), n)) * adsr(n, 0.4, 0.2, 0.7, 1.0), 0.0, 0.4)    # the deep drone
    emit("undertow_whirl", "sfx/weapons/undertow_whirl_01", reverb(x, r, 1.2, 0.3), -1.5, bus="SFX", volume_db=-2.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("water_splash")
    x = zeros(1.0)
    place(x, nrm(bp(white(r, 0.5), 400, 6000)) * expenv(N(0.5), 0.09), 0.0, 0.8)
    place(x, kick(r, 0.6, 120, 50, 0.06, 0.3), 0.0, 0.4)
    for k in range(6):
        place(x, nrm(bp(white(r, 0.03), 1500, 7000)) * expenv(N(0.03), 0.01), 0.12 + k * 0.06 + r.uniform(0, 0.03), 0.25)   # the drops falling back
    emit("water_splash", "sfx/world/water_splash_01", reverb(x, r, 0.6, 0.2), -2.0, bus="SFX", volume_db=-3.0, max_voices=4, pitch=[0.9, 1.1], attenuation="world")


def gen_totenhafen():
    """Totenhafen's UPDATE 10 systems (T-153): the drowned surfacing and the diver-helmet's roar, DER KIELHOLER's
    anchor-chain sweep, the Crane Drop's crash, the searchlight's carbon arc striking, the cipher machine's rotor
    click, the teletype printing, the diesels catching, U-1047's horn and the hull's groan."""
    r = rng_for("kl_surface")
    x = zeros(1.6)
    place(x, nrm(lp(white(r, 0.9), 900)) * adsr(N(0.9), 0.15, 0.1, 0.6, 0.4), 0.0, 0.6)                              # the water parting
    for k in range(5):
        place(x, nrm(bp(white(r, 0.05), 300, 2500)) * expenv(N(0.05), 0.02), 0.2 + k * 0.12, 0.3)                     # the gurgle
    n = N(0.8)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(90.0, 70.0, n), n)) * adsr(n, 0.1, 0.1, 0.6, 0.3) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * tax(n))), 0.5, 0.45)   # a drowned breath
    emit("kielholer_surface", "sfx/zombies/kielholer_surface_01", reverb(x, r, 0.9, 0.3), -2.0, bus="SFX", volume_db=-2.0, max_voices=3, pitch=[0.9, 1.1], attenuation="world")
    r = rng_for("kl_roar")
    x = zeros(2.0)
    n = N(1.6)
    vib = 1.0 + 0.03 * np.sin(2 * np.pi * 5.5 * tax(n))
    place(x, nrm(saw(np.geomspace(85.0, 60.0, n) * vib) * adsr(n, 0.08, 0.2, 0.8, 0.6)), 0.0, 0.5)                     # the roar inside the helmet
    place(x, nrm(bp(pink(r, 1.6), 200, 1400)) * adsr(n, 0.05, 0.2, 0.7, 0.6), 0.0, 0.4)
    place(x, bell(r, hz("D2"), 1.6, 1.2, 0.3, 0.3), 0.0, 0.25)                                                       # the brass bowl ringing with it
    emit("kielholer_roar", "sfx/zombies/kielholer_roar_01", reverb(x, r, 1.4, 0.35), -1.0, bus="SFX", volume_db=0.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("chain_sweep")
    x = zeros(1.6)
    place(x, sweep_noise(r, 0.9, 200, 2000, 3) * adsr(N(0.9), 0.3, 0.1, 0.8, 0.2), 0.0, 0.5)                          # the swing overhead
    for k in range(14):
        place(x, nrm(hp(white(r, 0.014), 1800)) * expenv(N(0.014), 0.006), 0.6 + k * 0.03, 0.5)                       # the links rattling out
    place(x, kick(r, 0.9, 130, 40, 0.1, 0.5), 1.0, 0.7)                                                              # the anchor hitting home
    emit("chain_sweep", "sfx/zombies/chain_sweep_01", reverb(x, r, 0.9, 0.25), -1.0, bus="SFX", volume_db=-1.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("crane_crash")
    x = zeros(2.6)
    place(x, kick(r, 1.0, 120, 32, 0.2, 0.9), 0.0, 1.0)                                                              # the pallet lands
    place(x, crackle(r, 0.8, 300, 1.0, 600, 7000) * expenv(N(0.8), 0.18), 0.0, 0.7)                                    # the crates splintering
    place(x, nrm(lp(white(r, 1.6), 400)) * expenv(N(1.6), 0.5), 0.05, 0.5)                                            # the dust rolling
    for k in range(5):
        place(x, bell(r, hz("A3") * (1.0 + 0.13 * k), 0.6, 2.5, 0.6, 0.6), 0.1 + k * 0.17, 0.12)                       # loose tins
    emit("crane_crash", "sfx/world/crane_crash_01", reverb(x, r, 1.3, 0.3), -0.5, bus="SFX", volume_db=0.0, max_voices=1, pitch=[0.96, 1.04], attenuation="loud")
    r = rng_for("searchlight_on")
    x = zeros(1.4)
    place(x, nrm(hp(white(r, 0.03), 1500)) * expenv(N(0.03), 0.01), 0.0, 0.7)                                        # the shutter's clack
    place(x, kick(r, 0.5, 90, 50, 0.05, 0.2), 0.0, 0.4)
    place(x, crackle(r, 1.2, 60, 0.5, 2000, 9000) * adsr(N(1.2), 0.1, 0.2, 0.6, 0.4), 0.08, 0.35)                      # the carbon arc's sputter
    n = N(1.2)
    place(x, sine(100.0, 1.2) * adsr(n, 0.1, 0.0, 1.0, 0.4), 0.08, 0.25)                                              # the mains hum
    emit("searchlight_on", "sfx/world/searchlight_on_01", reverb(x, r, 0.7, 0.2), -2.0, bus="SFX", volume_db=-3.0, max_voices=1, pitch=[0.98, 1.02], attenuation="world")
    r = rng_for("cipher_wheel")
    x = zeros(0.35)
    place(x, nrm(bp(white(r, 0.012), 1200, 6000)) * expenv(N(0.012), 0.004), 0.0, 0.7)                                # the detent
    place(x, bell(r, hz("E6"), 0.25, 6.0, 0.6, 0.5), 0.004, 0.12)
    place(x, nrm(lp(white(r, 0.04), 1500)) * expenv(N(0.04), 0.012), 0.02, 0.3)
    emit("cipher_wheel", "sfx/world/cipher_wheel_01", x, -4.0, bus="SFX", volume_db=-6.0, max_voices=3, pitch=[0.94, 1.06], attenuation="quiet")
    r = rng_for("teletype_print")
    x = zeros(2.6)
    for k in range(34):
        t0 = 0.05 + k * 0.07 + (0.12 if k % 6 == 5 else 0.0) * (k // 6)
        if t0 < 2.4:
            place(x, nrm(bp(white(r, 0.02), 800, 5000)) * expenv(N(0.02), 0.006), t0, 0.55 * r.uniform(0.7, 1.0))       # the type bars
    for k in range(3):
        place(x, bell(r, hz("A5"), 0.4, 4.0, 0.7, 0.8), 0.6 + k * 0.8, 0.15)                                         # the carriage bell
    emit("teletype_print", "sfx/world/teletype_print_01", reverb(x, r, 0.4, 0.15), -3.0, bus="SFX", volume_db=-4.0, max_voices=1, pitch=[0.98, 1.02], attenuation="world")
    r = rng_for("diesel_start")
    x = zeros(4.0)
    for k in range(10):
        place(x, kick(r, 0.5 + 0.05 * k, 70, 40, 0.08, 0.3), 0.05 + k * max(0.09, 0.32 - 0.025 * k), 0.4)             # the cranking, catching faster
    n = N(2.4)
    tt = tax(n)
    putt = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 9.0 * tt))
    place(x, nrm(lp(white(r, 2.4), 300)) * putt * adsr(n, 0.2, 0.2, 0.9, 0.4), 1.5, 0.6)                              # the diesel running
    place(x, saw(np.full(n, 54.0)) * adsr(n, 0.3, 0.2, 0.7, 0.4), 1.5, 0.25)
    emit("diesel_start", "sfx/world/diesel_start_01", reverb(x, r, 1.4, 0.35), -1.0, bus="SFX", volume_db=-1.0, max_voices=1, pitch=[0.98, 1.02], attenuation="loud")
    r = rng_for("boat_horn")
    x = zeros(3.6)
    n = N(2.6)
    tone = saw(np.full(n, 98.0)) * 0.6 + saw(np.full(n, 98.0 * 1.5)) * 0.4
    place(x, nrm(lp(tone, 1200)) * adsr(n, 0.15, 0.2, 0.85, 0.6), 0.0, 0.8)                                            # the horn's fifth
    emit("boat_horn", "sfx/world/boat_horn_01", reverb(x, r, 2.0, 0.4), -1.0, bus="SFX", volume_db=-1.0, max_voices=1, pitch=[1.0, 1.0], attenuation="loud")
    r = rng_for("hull_groan")
    x = zeros(3.0)
    n = N(2.6)
    place(x, nrm(lp(saw(np.geomspace(42.0, 58.0, n) * (1.0 + 0.04 * np.sin(2 * np.pi * 0.9 * tax(n)))), 400)) * adsr(n, 0.5, 0.2, 0.7, 0.9), 0.0, 0.6)   # the steel groaning
    for k in range(4):
        place(x, nrm(hp(white(r, 0.02), 1000)) * expenv(N(0.02), 0.008), 0.4 + k * 0.55 + r.uniform(0, 0.1), 0.35)      # rivets ticking
    emit("hull_groan", "sfx/world/hull_groan_01", reverb(x, r, 1.8, 0.4), -2.0, bus="SFX", volume_db=-2.0, max_voices=1, pitch=[0.92, 1.05], attenuation="loud")


def gen_map4_perks():
    """Skyhook Sekt and Magpie Mead (UPDATE 07, T-105): the hop, the stomp, the jingles; the Magpie drop and pick."""
    r = rng_for("sk_hop")
    x = zeros(0.5)
    n = N(0.35)
    place(x, np.sin(2 * np.pi * phase_of(np.geomspace(420.0, 1300.0, n), n)) * adsr(n, 0.01, 0.05, 0.6, 0.15), 0.0, 0.35)   # the fizz rising
    place(x, bp(white(r, 0.3), 2500, 7000) * expenv(N(0.3), 0.08), 0.0, 0.25)
    emit("perk_skyhook_hop", "sfx/world/perks/skyhook_hop_01", x, -3.0, bus="SFX", volume_db=-6.0, max_voices=2, pitch=[0.95, 1.05], attenuation="quiet")
    r = rng_for("sk_stomp")
    x = zeros(0.9)
    place(x, kick(r, 1.0, 140, 38, 0.12, 0.6), 0.0, 1.0)
    place(x, nrm(lp(white(r, 0.25), 600)) * expenv(N(0.25), 0.05), 0.0, 0.6)
    place(x, music_box(r, hz("A5"), 0.5), 0.02, 0.25)
    emit("perk_skyhook_stomp", "sfx/world/perks/skyhook_stomp_01", reverb(x, r, 0.6, 0.2), -1.0, bus="SFX", volume_db=-2.0, max_voices=2, pitch=[0.95, 1.05], attenuation="loud")
    r = rng_for("mm_drop")
    x = zeros(0.6)
    place(x, music_box(r, hz("E6"), 0.5), 0.0, 0.5)
    place(x, music_box(r, hz("G6"), 0.45), 0.08, 0.4)
    emit("perk_magpie_drop", "sfx/world/perks/magpie_drop_01", x, -4.0, bus="SFX", volume_db=-6.0, max_voices=3, pitch=[0.96, 1.04], attenuation="quiet")
    r = rng_for("mm_pick")
    x = zeros(0.5)
    place(x, nrm(hp(white(r, 0.02), 2000)) * expenv(N(0.02), 0.004), 0.0, 0.5)
    place(x, music_box(r, hz("C6"), 0.4), 0.02, 0.4)
    place(x, music_box(r, hz("G6"), 0.35), 0.1, 0.3)
    emit("perk_magpie_pick", "sfx/world/perks/magpie_pick_01", x, -3.0, bus="SFX", volume_db=-5.0, max_voices=3, pitch=[0.96, 1.04], attenuation="quiet")
    r = rng_for("sk_jingle")
    emit("jingle_skyhook_sekt", "jingles/skyhook_sekt_01", skyhook_jingle(r), -2.0, bus="Jingles", volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0], attenuation="world")
    r = rng_for("mm_jingle")
    emit("jingle_magpie_mead", "jingles/magpie_mead_01", magpie_jingle(r), -2.0, bus="Jingles", volume_db=-4.0, max_voices=1, pitch=[1.0, 1.0], attenuation="world")
    # U08 (T-129): the tier IV sting: a rising bell arpeggio (C E G C) over a short brass swell, rung after the
    # tonic's own jingle when a tonic becomes permanent
    r = rng_for("perk_t4")
    x = zeros(2.6)
    place(x, brass_cluster(r, ["C4", "G4", "C5", "E5"], 1.6, 0.35) * np.linspace(1.0, 0.0, N(1.6)) ** 1.5, 0.15, 0.45)
    for k, nm in enumerate(["C5", "E5", "G5", "C6"]):
        place(x, bell(r, hz(nm), 1.6, decay=1.4, strike=0.4, bright=1.2), 0.11 * k, 0.55 if k < 3 else 0.8)
    emit("perk_tier4_sting", "jingles/perk_tier4_sting_01", reverb(x, r, 1.4, 0.3), -2.0, bus="Jingles", volume_db=-3.0,
         max_voices=1, pitch=[1.0, 1.0], attenuation="world")


def main():
    gen_weapons()
    gen_zombies()
    gen_player()
    gen_world()
    gen_overclock()
    gen_map4_perks()
    gen_ledger()
    gen_rocket_man()
    gen_lodestone()
    gen_undertow()
    gen_totenhafen()
    gen_ambience()
    gen_music()
    legacy_aliases()
    write_manifest()
    total = sum(d for _, d in STATS)
    print(f"gen_audio: wrote {len(STATS)} files ({total:.1f} s of audio), {len(KEYS)} keys -> data/gravelight/audio.json")


if __name__ == "__main__":
    main()
