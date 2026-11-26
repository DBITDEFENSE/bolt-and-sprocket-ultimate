#!/usr/bin/env python3
"""T-285: the two trailers' sound, synthesized from scratch with the game's own DSP core
(gravelight/tools_src/gen_audio.py: oscillators, formant voices, noise-IR reverb) plus a few of the game's own
in-house sound files (the T-280 blast layers, the Sherman's gun and engine, the horse, the boss roars; every one made
by the repo's gen_audio_*.py scripts). No recordings, no samples from outside the project. Licence: our own work.

Used by tools/trailer/make_trailers.py: teaser(cues, dur) and gameplay(cues, dur) return a stereo float array at
44.1 kHz; the cue list is the edit's own (time, kind, args) so the hits land on the cuts.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile

_argv = sys.argv[1:]
sys.argv = sys.argv[:1]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "gravelight", "tools_src"))
import gen_audio as A                        # noqa: E402
import numpy as np                           # noqa: E402

sys.argv = sys.argv[:1] + _argv
SR = A.SR
AUD = os.path.join(ROOT, "gravelight", "audio")


# ------------------------------------------------------------------ helpers

def stereo(x, p: float = 0.0):
    """Mono -> stereo with a constant-power pan (-1 left .. 1 right)."""
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def put(dst, src, t0: float, gain: float = 1.0, p: float = 0.0):
    """Mix src (mono or stereo) into the stereo dst at t0 s."""
    if src.ndim == 1:
        src = stereo(src, p)
    i = int(round(t0 * SR))
    if i >= len(dst):
        return
    if i < 0:
        src = src[-i:]
        i = 0
    n = min(len(src), len(dst) - i)
    dst[i:i + n] += src[:n] * gain


def load(rel: str):
    """One of the game's own sound files (wav / ogg) as mono float at 44.1 kHz (ffmpeg decodes)."""
    path = os.path.join(AUD, rel)
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).astype(np.float64)


def env_curve(n: int, pts):
    """A piecewise-linear envelope over n samples from [(t_frac, value), ...]."""
    xs = np.array([p[0] for p in pts]) * (n - 1)
    ys = np.array([p[1] for p in pts])
    return np.interp(np.arange(n), xs, ys)


def limit(x, ceiling: float = 0.89):
    """A soft limiter: tanh above the knee, so the loudest hits never clip."""
    peak = np.max(np.abs(x)) + 1e-9
    y = x / peak * 1.25
    y = np.tanh(y) / np.tanh(1.25)
    return y * ceiling


# ------------------------------------------------------------------ sound bricks (all synthesized)

def wind(r, sec: float, amt: float = 1.0):
    n = A.N(sec)
    b = A.brown(r, sec)
    g = 0.55 + 0.45 * A.smooth_rand(r, sec, 0.18, 0.0, 1.0)
    w = A.bp(b, 120, 900, 2) * g
    hi = A.bp(A.pink(r, sec), 1800, 5200, 2) * (0.15 + 0.25 * A.smooth_rand(r, sec, 0.3, 0.0, 1.0))
    return A.nrm(w + hi) * amt


def drone(r, sec: float, f: float = 36.7):
    """A low string-and-sub drone with a slow breath."""
    y = A.strings(r, f, sec, a=3.0, rel=2.0, cutoff=500, voices=4, detune=0.01)[:A.N(sec)]
    y += 0.7 * A.strings(r, f * 2, sec, a=4.0, rel=2.0, cutoff=700, voices=3, detune=0.008)[:A.N(sec)]
    y += 0.6 * A.sine(f / 2, sec) * A.attack(A.N(sec), 2.0)
    y *= 0.7 + 0.3 * A.smooth_rand(r, sec, 0.12, 0.0, 1.0)
    return A.nrm(y)


def cluster(r, sec: float, root: float = 146.8, a: float = 1.5):
    """A dissonant high string cluster (semitones over a minor second), for the build."""
    y = np.zeros(A.N(sec))
    for k, st in enumerate([0, 1, 3, 6, 7, 13]):
        f = root * 2 ** (st / 12)
        s = A.strings(r, f, sec, a=a, rel=0.3, cutoff=3200, voices=3, detune=0.012)[:A.N(sec)]
        y += s * (0.9 if k < 3 else 0.6)
    return A.nrm(A.reverb(y, r, decay=2.6, wet=0.45, damp=5000))


def heartbeat(r, gain: float = 1.0):
    x = A.zeros(0.9)
    A.place(x, A.kick(r, 1.0, 70, 38, 0.12, 0.4), 0.0, 1.0)
    A.place(x, A.kick(r, 0.7, 64, 36, 0.10, 0.35), 0.26, 0.7)
    return A.lp(x, 260) * gain


def boom(r, sec: float = 6.0, f: float = 32.0):
    """The trailer hit: a sub drop, a low brass-like stack and a long dark tail."""
    n = A.N(sec)
    t = A.tax(n)
    sub = np.sin(2 * np.pi * np.cumsum(f + 40 * np.exp(-t / 0.08)) / SR) * np.exp(-t / 1.6)
    stack = np.zeros(n)
    for k, m in enumerate([1, 1.5, 2, 3, 4.02]):
        stack += A.saw(f * 2 * m * (1 + 0.004 * k), sec) * (0.5 / (k + 1))
    stack = A.lp(stack, 900, 2) * np.exp(-t / 1.1) * A.attack(n, 0.01)
    crack = A.lp(A.white(r, sec), 2500) * np.exp(-t / 0.05)
    x = 1.0 * sub + 0.55 * stack + 0.35 * crack
    x = A.sat(x * 1.6, 1.0)
    return A.nrm(A.reverb(x, r, decay=4.0, wet=0.35, damp=1800, predelay=0.02))


def whoosh(r, sec: float = 1.2, up: bool = True):
    return A.nrm(A.sweep_noise(r, sec, 300 if up else 4000, 4000 if up else 300, 3.0) * A.adsr(A.N(sec), sec * 0.8 if up else 0.02, 0.0, 1.0, 0.1 if up else sec * 0.8))


def riser(r, sec: float):
    n = A.N(sec)
    t = A.tax(n)
    f = 110 * 2 ** (3 * t / sec)
    tone = np.zeros(n)
    for k in range(3):
        tone += A.saw(f * (1 + 0.01 * k), None, r.uniform()) * 0.3
    k = t / sec
    tone = A.lp(tone, 1200, 1) * (1 - k) + A.lp(tone, 6000, 1) * k
    nz = A.sweep_noise(r, sec, 200, 7000, 2.5)
    x = (tone + 0.8 * A.nrm(nz)) * (t / sec) ** 2.2
    return A.nrm(A.reverb(x, r, 1.6, 0.3, 6000))


def radio_crackle(r, sec: float = 2.4):
    st = A.crackle(r, sec, 220, 1.0, 900, 6000) + 0.5 * A.bp(A.white(r, sec), 700, 3500, 2)
    tune = np.sin(2 * np.pi * np.cumsum(900 + 500 * A.smooth_rand(r, sec, 1.2)) / SR) * 0.12
    x = (st + tune) * A.adsr(A.N(sec), 0.02, 0.1, 0.8, 0.4) * (0.6 + 0.4 * (A.smooth_rand(r, sec, 3.0, 0, 1) > 0.4))
    return A.nrm(A.bp(x, 400, 4500, 2))


def creak(r, sec: float = 1.6, f: float = 160.0):
    n = A.N(sec)
    f0 = f * (1 + 0.25 * A.smooth_rand(r, sec, 1.4))
    pulse = (np.sin(2 * np.pi * np.cumsum(f0) / SR) > 0.97).astype(float)
    x = A.reson(pulse + 0.02 * A.white(r, sec), f * 3.1, 14) + 0.6 * A.reson(pulse, f * 5.3, 18)
    x *= A.adsr(n, 0.2, 0.1, 0.8, 0.5)
    return A.nrm(A.reverb(x, r, 1.0, 0.2, 3500))


def breath_out(r, sec: float = 1.6):
    x = A.bp(A.white(r, sec), 300, 2200, 2) * A.adsr(A.N(sec), 0.12, 0.2, 0.7, 0.9)
    return A.nrm(A.reverb(x, r, 0.6, 0.15, 3000))


def groan_swell(r, sec: float, count: int = 18):
    """The horde: many Ganger groans (the game's own voice model), spread, rising."""
    x = np.zeros((A.N(sec), 2))
    for i in range(count):
        g = A.ganger_groan(r, i)
        t0 = r.uniform(0, max(0.1, sec - 2.0)) * (0.4 + 0.6 * (i / count))
        put(x, A.nrm(g) * r.uniform(0.3, 0.8) * (0.3 + 0.7 * i / count), t0, 1.0, r.uniform(-0.8, 0.8))
    x *= env_curve(len(x), [(0, 0.2), (0.6, 0.7), (1, 1.0)])[:, None]
    return x


def scream(r, sec: float = 1.3):
    """The final sting: a high torn formant scream over a string screech, cut dead."""
    n = A.N(sec)
    f0 = A.pitch_curve(r, sec, 520, [(0, 0.75), (0.12, 1.15), (0.6, 1.05), (1, 0.9)], 0.06, 9, 0.05, 0.03)
    v = A.voice(r, sec, f0, ["ae", "a", "ah"], shift=1.1, breath=0.6, rasp=1.0, fry=0.3, drive=5.0)[:n]
    s = np.zeros(n)
    t = A.tax(n)
    for k in range(4):
        f = 1200 * 2 ** (k / 12) * (1 + 0.4 * t / sec)
        s += A.saw(f, None) * 0.2
    s = A.hp(s, 900) * A.attack(n, 0.02)
    x = A.nrm(v) + 0.5 * A.nrm(s)
    x *= A.adsr(n, 0.01, 0.1, 0.9, 0.08)
    return A.nrm(A.reverb(x, r, 1.2, 0.25, 6000))


def tick(r):
    x = A.white(r, 0.03) * A.expenv(A.N(0.03), 0.003)
    return A.nrm(A.reson(x, 3200, 25) + 0.4 * A.reson(x, 5100, 30))


# ------------------------------------------------------------------ the teaser

def teaser(cues, dur: float):
    """cues: [(t, kind, arg)] from the edit. Kinds: drone_in, wind, radio, creak, breath, heart(rate start..end),
    groans(len), riser(len), boom, hit, cut_silence(len), title, sting, whisper, bell, tick."""
    r = A.rng_for("t285_teaser")
    mix = np.zeros((A.N(dur), 2))
    music = np.zeros((A.N(dur), 2))
    for (t, kind, arg) in cues:
        if kind == "wind":
            length = float(arg)
            put(mix, A.nrm(wind(r, length)), t, 0.32, -0.2)
            put(mix, A.nrm(wind(r, length)), t, 0.26, 0.3)
        elif kind == "drone":
            length = float(arg)
            d = drone(r, length)
            d *= env_curve(len(d), [(0, 0.0), (0.15, 0.6), (0.85, 1.0), (1, 0.9)])
            put(music, d, t, 0.42)
        elif kind == "cluster":
            length = float(arg)
            c = cluster(r, length, a=length * 0.7)
            c *= env_curve(len(c), [(0, 0.0), (1, 1.0)]) ** 1.5
            put(music, stereo(c, -0.3), t, 0.18)
            put(music, stereo(np.roll(c, 900), 0.3), t, 0.18)
        elif kind == "radio":
            put(mix, radio_crackle(r, float(arg or 2.4)), t, 0.28, 0.35)
        elif kind == "creak":
            put(mix, creak(r, 1.8, float(arg or 160.0)), t, 0.32, -0.3)
        elif kind == "breath":
            put(mix, breath_out(r, 1.8), t, 0.25)
        elif kind == "heart":
            a0, a1, length = arg            # bpm start, bpm end, seconds
            tt = 0.0
            while tt < length:
                bpm = a0 + (a1 - a0) * tt / length
                put(music, heartbeat(r), t + tt, 0.55 + 0.35 * tt / length)
                tt += 60.0 / bpm
        elif kind == "groans":
            put(mix, groan_swell(r, float(arg), 22), t, 0.5)
        elif kind == "riser":
            put(music, riser(r, float(arg)), t, 0.35)
        elif kind == "boom":
            put(music, boom(r, 7.0), t, 0.95)
        elif kind == "hit":
            put(music, boom(r, 2.5, 40.0), t, 0.6)
            put(mix, whoosh(r, 0.5, False), t, 0.15)
        elif kind == "whoosh":
            put(mix, whoosh(r, float(arg or 1.0), True), t - float(arg or 1.0), 0.18)
        elif kind == "whisper":
            put(mix, load("sfx/horror/whisper_%02d.ogg" % int(arg or 1)), t, 0.35, 0.4)
        elif kind == "bell":
            put(mix, load("sfx/horror/bell_far_01.ogg"), t, 0.4)
        elif kind == "sting":
            put(mix, scream(r, 1.2), t, 0.9)
            put(music, boom(r, 1.6, 44.0), t, 0.7)
        elif kind == "tick":
            put(mix, tick(r), t, 0.25, 0.2)
        elif kind == "silence":
            a, b = A.N(t), A.N(t + float(arg))
            ramp = A.N(0.03)
            for buf in (mix, music):
                buf[a:a + ramp] *= np.linspace(1, 0, ramp)[:, None]
                buf[a + ramp:b] = 0.0
    out = mix + music
    return limit(out, 0.89)


# ------------------------------------------------------------------ the gameplay trailer

D_MINOR = [73.42, 82.41, 87.31, 98.0, 110.0, 116.54, 130.81]


def snare_roll(r, sec: float, crescendo: bool = True):
    x = np.zeros(A.N(sec + 0.3))
    t = 0.0
    k = 0
    while t < sec:
        v = (0.25 + 0.75 * t / sec) if crescendo else 0.7
        A.place(x, A.snare(r, v, 190, 0.18, 0.6, 7000), t, 1.0)
        t += 0.06 if k % 2 else 0.065
        k += 1
    return x


def tom(r, f: float = 90.0, vel: float = 1.0):
    k = A.kick(r, vel, f * 1.6, f, 0.22, 0.6)
    A.place(k, 0.15 * A.lp(A.white(r, 0.3), 1500) * A.expenv(A.N(0.3), 0.04), 0.0)
    return k


def ostinato(r, sec: float, bpm: float, root: float = 73.42, pattern=(0, 0, 3, 0, 5, 0, 3, 7), bright: float = 1.0):
    """Driving low strings: sixteenths on a minor figure."""
    step = 60.0 / bpm / 4.0
    x = np.zeros(A.N(sec + 0.5))
    semis = [0, 2, 3, 5, 7, 8, 10, 12]
    t = 0.0
    i = 0
    while t < sec:
        st = pattern[i % len(pattern)]
        f = root * 2 ** (st / 12)
        nlen = step * 0.9
        y = np.zeros(A.N(nlen + 0.05))
        for k in range(3):
            y += A.saw(f * (1 + 0.006 * (k - 1)), nlen + 0.05, r.uniform()) / 3
        y = A.lp(y, 900 * bright + 300, 2) * A.adsr(len(y), 0.004, 0.05, 0.6, 0.04)
        A.place(x, y, t, 1.0 if i % 4 == 0 else 0.7)
        t += step
        i += 1
    return A.nrm(x)


def brass_stab(r, f: float, sec: float = 0.9):
    n = A.N(sec)
    y = np.zeros(n)
    for m in (1, 1.5, 2, 3):
        y += A.saw(f * m, sec, r.uniform()) / m
    y = A.lp(y, 1600, 2) * A.adsr(n, 0.02, 0.15, 0.5, 0.4)
    return A.nrm(A.reverb(y, r, 1.6, 0.3, 4000))


def gameplay(cues, dur: float, bpm: float = 120.0):
    """cues: [(t, kind, arg)] kinds: music_a(len), music_b(len), roll(len), stop, boom, hit, stab(semitone), whoosh(len),
    gun(<file prefix>, n, gap), blast(size), tank_gun, engine(len), horse(len), rocket(len), roar, scream, groans(len),
    tick_bed(len), title, silence(len)."""
    r = A.rng_for("t285_gameplay")
    mix = np.zeros((A.N(dur), 2))
    music = np.zeros((A.N(dur), 2))
    beat = 60.0 / bpm
    for (t, kind, arg) in cues:
        if kind in ("music_a", "music_b"):
            length = float(arg)
            ost = ostinato(r, length, bpm, 73.42, (0, 0, 3, 0, 5, 0, 3, 7) if kind == "music_a" else (0, 12, 10, 12, 7, 8, 7, 3), 0.8 if kind == "music_a" else 1.4)
            ost = ost[:A.N(length)]
            put(music, stereo(ost, -0.2), t, 0.33)
            put(music, stereo(np.roll(ost, 600), 0.25), t, 0.28)
            d = drone(r, length, 36.7)
            put(music, d, t, 0.3)
            nb = int(length / beat)
            for b in range(nb):
                tb = t + b * beat
                put(music, A.kick(r, 1.0, 120, 42, 0.22, 0.6), tb, 0.65 if kind == "music_b" or b % 2 == 0 else 0.0)
                if b % 2 == 1:
                    put(music, A.snare(r, 0.9, 185, 0.3, 0.8, 9000), tb, 0.45, 0.1)
                if kind == "music_b" and b % 4 == 3:
                    put(music, tom(r, 80), tb + beat * 0.5, 0.45, -0.3)
                    put(music, tom(r, 65), tb + beat * 0.75, 0.45, 0.3)
            if kind == "music_b":
                for b in range(0, nb, 8):
                    put(music, brass_stab(r, 146.8 if (b // 8) % 2 == 0 else 130.8, beat * 3.5), t + b * beat, 0.35)
        elif kind == "tick_bed":
            length = float(arg)
            tt = 0.0
            while tt < length:
                put(music, tick(r), t + tt, 0.22, 0.2)
                tt += beat / 2
            d = drone(r, length, 36.7)
            d *= env_curve(len(d), [(0, 0), (0.3, 0.7), (1, 1)])
            put(music, d, t, 0.45)
        elif kind == "roll":
            put(music, snare_roll(r, float(arg)), t, 0.4)
            put(music, riser(r, float(arg)), t, 0.3)
        elif kind == "boom":
            put(music, boom(r, 6.0), t, 0.95)
        elif kind == "hit":
            put(music, boom(r, 2.2, 40.0), t, 0.65)
        elif kind == "stab":
            put(music, brass_stab(r, 146.8 * 2 ** (int(arg) / 12), 0.8), t, 0.5)
        elif kind == "whoosh":
            put(mix, whoosh(r, float(arg or 0.6), True), t - float(arg or 0.6), 0.16)
        elif kind == "gun":
            pref, count, gap = arg
            for i in range(int(count)):
                g = load("sfx/weapons/%s_%02d.wav" % (pref, (i % 3) + 1))
                put(mix, g, t + i * float(gap), 0.42, r.uniform(-0.15, 0.15))
        elif kind == "blast":
            size = str(arg or "big")
            put(mix, load("sfx/blast/blast_crack_0%d.wav" % r.integers(1, 4)), t, 0.8)
            if size != "small":
                put(mix, load("sfx/blast/blast_debris_0%d.wav" % r.integers(1, 4)), t + 0.1, 0.5)
                put(music, boom(r, 3.0, 30.0), t, 0.5)
        elif kind == "tank_gun":
            put(mix, load("sherman/sherman_gun_1.ogg"), t, 0.85)
        elif kind == "engine":
            e = load("sherman/sherman_engine.ogg")
            length = float(arg)
            reps = int(np.ceil(length * SR / len(e))) + 1
            e = np.tile(e, reps)[:A.N(length)] * env_curve(A.N(length), [(0, 0), (0.1, 1), (0.9, 1), (1, 0)])
            put(mix, e, t, 0.35)
        elif kind == "horse":
            length = float(arg)
            tt = 0.0
            while tt < length:
                for k, d in enumerate((0.0, 0.07, 0.19, 0.26)):
                    put(mix, A.lp(A.kick(r, 0.6, 140, 70, 0.04, 0.12) + 0.3 * A.fit(A.thunk(r, 180, 0.02, 0.1), 0.12), 2500), t + tt + d, 0.35)
                tt += 0.42
            put(mix, load("horse/horse_blow_1.ogg"), t + 0.3, 0.4)
        elif kind == "rocket":
            length = float(arg)
            n = A.N(length)
            roar = A.lp(A.brown(r, length), 700) + 0.4 * A.bp(A.white(r, length), 800, 5000)
            roar = A.nrm(A.sat(roar * 2.0, 1.0)) * env_curve(n, [(0, 0), (0.08, 1.0), (0.7, 0.9), (1, 0.3)])
            put(mix, roar, t, 0.7)
            put(music, boom(r, 4.0, 28.0), t, 0.6)
        elif kind == "roar":
            put(mix, load("bosses/boss_roar_low_%d.ogg" % int(arg or 1)), t, 0.7)
        elif kind == "horse_scream":
            put(mix, load("horse/horse_boss_scream_1.ogg"), t, 0.6)
        elif kind == "groans":
            put(mix, groan_swell(r, float(arg), 14), t, 0.4)
        elif kind == "zip":
            length = float(arg)
            z = A.bp(A.white(r, length), 1500, 6000, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 37 * A.tax(A.N(length))))
            z *= env_curve(len(z), [(0, 0), (0.1, 0.8), (0.9, 1.0), (1, 0)])
            put(mix, A.nrm(z), t, 0.25)
        elif kind == "sting":
            put(mix, scream(r, 1.0), t, 0.7)
        elif kind == "silence":
            a, b = A.N(t), A.N(t + float(arg))
            ramp = A.N(0.02)
            for buf in (mix, music):
                buf[a:a + ramp] *= np.linspace(1, 0, ramp)[:, None]
                buf[a + ramp:b] = 0.0
    return limit(mix + music * 0.9, 0.89)


def write_wav(path: str, x):
    import wave
    y = np.clip(x, -1, 1)
    pcm = (y * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
