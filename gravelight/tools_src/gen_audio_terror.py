#!/usr/bin/env python3
"""GRAVELIGHT T-284: the zombies' new voice layers, synthesized from scratch (no recordings, no samples).

gen_audio.py's DSP core (its glottal source and formant bank), the way the Ganger's groans were made. License: Ours
(original work). Played by Zombie / ZombieTerror (data/gravelight/zombie_terror.json):

  zombie_scream_1..4       first sight: a ragged inhale, then a tearing shriek that cracks and falls away
  zombie_growl_low_1..5    a low wet growl laid under a near body's groan (vocal fry an octave down)
  zombie_breath_close_1..5 the nearest body breathing at you: a rattling inhale and a wet, bubbling exhale
  zombie_wet_1..5          mouth sounds: smacks, a slurp, teeth clicking, a choke
  zombie_twitch_1..4       a joint cracking in a spasm (knuckle pops and a gristle creak)
  zombie_gurgle_1..4       a near death: blood in the throat, a drowning gurgle and a last hiss
  horde_swell_1..2         a horde closing in: a low swell of many throats under a sub-bass rise (2D)

The keys go into data/gravelight/audio.json as ONE block at the END of "sounds" (sorted), so a three-way merge with
another branch's audio.json never meets it; a key already there is replaced.

Run from the repo root:   python gravelight/tools_src/gen_audio_terror.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy and scipy.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import numpy as np                           # noqa: E402

N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, nrm, sat = A.lp, A.hp, A.bp, A.nrm, A.sat
expenv, attack, adsr, place, fit, zeros = A.expenv, A.attack, A.adsr, A.place, A.fit, A.zeros
reverb, crackle, voice, pitch_curve = A.reverb, A.crackle, A.voice, A.pitch_curve
smooth_rand = A.smooth_rand
SR = A.SR
ZS = dict(bus="SFX", attenuation="zombie", pitch=[0.93, 1.07], vol_jitter_db=2.0)
NEAR = dict(bus="SFX", attenuation="quiet", pitch=[0.92, 1.08], vol_jitter_db=2.0)


def bubbles(r, sec: float, rate: float, lo: float = 220.0, hi: float = 950.0, blen=(0.02, 0.05)):
    """Wet blips: short rising sine chirps under a hann window, at random times."""
    out = zeros(sec)
    for _ in range(int(sec * rate)):
        bl = r.uniform(*blen)
        f = r.uniform(lo, hi)
        n = N(bl)
        ch = np.sin(2 * np.pi * np.cumsum(np.linspace(f, f * r.uniform(1.4, 2.2), n)) / SR) * np.sin(np.pi * np.linspace(0, 1, n))
        place(out, ch, r.uniform(0.0, max(0.001, sec - bl)), r.uniform(0.25, 1.0))
    return out


def gen_scream():
    for i in A.variants(4):
        r = A.rng_for("terror_scream%d" % i)
        dur = r.uniform(0.9, 1.35)
        base = r.uniform(330, 470)
        f0 = pitch_curve(r, dur, base, [(0, 0.7), (0.12, 1.15), (0.45, 1.05), (0.7, 0.9), (1, 0.55)], 0.1, 11, 0.05, 0.05)
        seq = [["ae", "a", "ah"], ["e", "ae", "a"], ["a", "ae", "ah", "o"], ["ae", "ah", "a"]][i % 4]
        x = voice(r, dur, f0, seq, shift=r.uniform(1.05, 1.2), breath=0.6, rasp=1.2, fry=0.3, drive=5.0)
        x *= adsr(len(x), 0.02, 0.15, 0.85, dur * 0.35)
        # the voice cracks: a few short dropouts of the harmonic part, a hiss carries through
        n = len(x)
        gate = np.ones(n)
        for _ in range(int(r.integers(1, 4))):
            at = int(r.uniform(0.3, 0.8) * n)
            w = int(r.uniform(0.02, 0.05) * SR)
            gate[at:at + w] *= 0.25
        gate = lp(gate, 90)
        hiss = nrm(bp(white(r, dur), 2500, 9000)) * adsr(n, 0.02, 0.2, 0.7, dur * 0.4) * 0.22
        x = x * gate + hiss
        inh = nrm(bp(white(r, 0.32), 700, 4500)) * adsr(N(0.32), 0.25, 0, 1, 0.05) * 0.3
        rattle = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * tax(N(0.32))))) * inh
        out = zeros(dur + 0.4)
        place(out, inh + 0.5 * rattle, 0.0)
        place(out, x, 0.26)
        out = reverb(out, r, 0.7, 0.16, 6000, 0.01, bright=0.3)
        A.emit("zombie_scream", "sfx/terror/zombie_scream_%02d" % i, fit(out, dur + 0.4), -0.5, volume_db=0.0,
               max_voices=2, bus="SFX", attenuation="world", pitch=[0.94, 1.06], vol_jitter_db=1.5)


def gen_growl():
    for i in A.variants(5):
        r = A.rng_for("terror_growl%d" % i)
        dur = r.uniform(1.6, 2.5)
        base = r.uniform(48, 66)
        f0 = pitch_curve(r, dur, base, [(0, 0.9), (0.4, 1.06), (1, 0.85)], 0.08, 4, 0.03, 0.03)
        x = voice(r, dur, f0, ["u", "o", "u"], shift=r.uniform(0.7, 0.8), breath=0.35, rasp=0.8, fry=0.85, drive=2.6)
        x *= adsr(len(x), 0.2, 0.3, 0.85, 0.5)
        wet = lp(bubbles(r, dur, 9, 120, 420, (0.03, 0.07)), 900) * 0.3
        x = lp(x + wet, 2200)
        A.emit("zombie_growl_low", "sfx/terror/zombie_growl_low_%02d" % i, fit(reverb(x, r, 0.3, 0.06, 2500), dur), -1.0,
               volume_db=-2.0, max_voices=4, **ZS)


def gen_breath():
    for i in A.variants(5):
        r = A.rng_for("terror_breath%d" % i)
        dur = r.uniform(1.3, 2.0)
        n = N(dur)
        t = tax(n)
        ins = r.uniform(0.35, 0.55)
        # the inhale: a rattle in the throat (pulsed noise at ~30 Hz) through a narrow "u"
        rat_rate = r.uniform(24, 36)
        pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rat_rate * t + r.uniform(0, 6)))
        inh_env = np.where(t < ins, np.sin(np.pi * np.clip(t / ins, 0, 1)) ** 0.7, 0.0)
        inh = A.formant(white(r, dur) * (0.4 + 0.6 * lp(pulse, 120)), "u", 1.2) * inh_env
        # the exhale: a wet groaning breath with bubbles
        ex_env = np.where(t >= ins, np.sin(np.pi * np.clip((t - ins) / (dur - ins), 0, 1)) ** 0.8, 0.0)
        exh = A.formant(white(r, dur), "o", 0.9) * ex_env
        gro = voice(r, dur, pitch_curve(r, dur, r.uniform(70, 95), [(0, 1), (1, 0.8)], 0.05, 5, 0.02, 0.02), ["o", "u"],
                    shift=0.8, breath=0.6, rasp=0.5, fry=0.7, drive=1.6) * ex_env * 0.35
        bub = lp(bubbles(r, dur, 26, 300, 1100), 2400) * ex_env * 0.45
        x = nrm(inh) * 0.8 + nrm(exh) * 0.6 + gro + bub
        A.emit("zombie_breath_close", "sfx/terror/zombie_breath_close_%02d" % i, fit(reverb(x, r, 0.2, 0.05, 5000), dur),
               -1.0, volume_db=0.0, max_voices=2, **NEAR)


def gen_wet():
    for i in A.variants(5):
        r = A.rng_for("terror_wet%d" % i)
        dur = r.uniform(0.35, 0.7)
        n = N(dur)
        x = zeros(dur)
        kind = i % 4
        if kind in (0, 1):      # smacks: lips parting on blood, a click and a squelch
            for _ in range(int(r.integers(2, 5))):
                at = r.uniform(0.0, dur - 0.08)
                sm = nrm(bp(white(r, 0.06), 600, 3500)) * expenv(N(0.06), 0.012)
                place(x, sm, at, r.uniform(0.5, 1.0))
            x += lp(bubbles(r, dur, 30, 300, 1400, (0.015, 0.035)), 3000) * 0.6
        elif kind == 2:         # a slurp: a narrow noise band sweeping up with bubbles
            sw = A.sweep_noise(r, dur, 500, 1800, 6.0, 10) * np.sin(np.pi * np.linspace(0, 1, n))
            x = nrm(sw) * 0.7 + lp(bubbles(r, dur, 40, 250, 900), 2500) * 0.6
        else:                   # teeth clicking, then a choke
            for _ in range(int(r.integers(3, 6))):
                at = r.uniform(0.0, dur * 0.6)
                cl = nrm(hp(white(r, 0.012), 2500)) * expenv(N(0.012), 0.002)
                place(x, cl, at, r.uniform(0.4, 0.9))
            ch = voice(r, 0.2, r.uniform(110, 150), ["ah", "u"], shift=0.95, breath=0.6, rasp=0.9, fry=0.6, drive=2.5)
            place(x, ch * adsr(len(ch), 0.01, 0.05, 0.8, 0.08) * 0.6, dur * 0.6)
        A.emit("zombie_wet", "sfx/terror/zombie_wet_%02d" % i, fit(reverb(x, r, 0.15, 0.05, 6000), dur), -2.0,
               volume_db=0.0, max_voices=3, **NEAR)


def gen_twitch():
    for i in A.variants(4):
        r = A.rng_for("terror_twitch%d" % i)
        dur = 0.35
        x = zeros(dur)
        for _ in range(int(r.integers(2, 5))):      # knuckle pops: sharp, dry, a tiny resonant body
            at = r.uniform(0.0, 0.18)
            pop = nrm(hp(white(r, 0.02), 1200)) * expenv(N(0.02), 0.0025)
            body = A.reson(pop, r.uniform(900, 1700), 8) * 0.5
            place(x, pop + body, at, r.uniform(0.5, 1.0))
        creak = A.sweep_noise(r, 0.16, r.uniform(300, 500), r.uniform(900, 1400), 9.0, 6) * expenv(N(0.16), 0.06)
        place(x, nrm(creak) * 0.35, r.uniform(0.05, 0.15))
        A.emit("zombie_twitch", "sfx/terror/zombie_twitch_%02d" % i, fit(x, dur), -3.0, volume_db=0.0, max_voices=2, **NEAR)


def gen_gurgle():
    for i in A.variants(4):
        r = A.rng_for("terror_gurgle%d" % i)
        dur = r.uniform(1.0, 1.5)
        n = N(dur)
        t = tax(n)
        f0 = pitch_curve(r, dur, r.uniform(95, 130), [(0, 1.0), (0.5, 0.85), (1, 0.55)], 0.06, 4, 0.02, 0.04)
        v = voice(r, dur, f0, ["o", "u", "o"], shift=0.85, breath=0.5, rasp=0.7, fry=0.8, drive=2.0)
        # drowning: the voice gated fast and irregularly by liquid in the throat
        rate = 9 + 7 * smooth_rand(r, dur, 5, 0, 1)
        gate = lp(0.3 + 0.7 * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(rate) / SR))), 70)
        bub = lp(bubbles(r, dur, 34, 200, 800, (0.025, 0.06)), 1800)
        x = v * gate * adsr(n, 0.03, 0.2, 0.8, dur * 0.35) * 0.7 + bub * np.exp(-t / (dur * 0.7)) * 0.7
        hiss = nrm(bp(white(r, 0.5), 400, 3000)) * adsr(N(0.5), 0.05, 0, 1, 0.4) * 0.22
        out = zeros(dur + 0.45)
        place(out, x, 0.0)
        place(out, hiss, dur * 0.85)
        A.emit("zombie_gurgle", "sfx/terror/zombie_gurgle_%02d" % i, fit(reverb(out, r, 0.35, 0.08, 4000), dur + 0.45),
               -1.0, volume_db=0.0, max_voices=3, **ZS)


def gen_swell():
    for i in A.variants(2):
        r = A.rng_for("terror_swell%d" % i)
        dur = 6.0
        n = N(dur)
        t = tax(n)
        env = np.clip(t / 3.2, 0, 1) ** 1.6 * np.clip((dur - t) / 1.6, 0, 1)
        # many throats: a dozen detuned low groans, each its own vowel drift
        mass = zeros(dur)
        for k in range(12):
            rk = A.rng_for("terror_swell%d_%d" % (i, k))
            f0 = pitch_curve(rk, dur, rk.uniform(60, 120), [(0, 0.9), (0.6, 1.05), (1, 0.95)], 0.08, rk.uniform(3, 6), 0.03, 0.02)
            vk = voice(rk, dur, f0, [["o", "u", "a"], ["u", "o", "u"], ["a", "o", "u"]][k % 3], shift=rk.uniform(0.75, 0.95),
                       breath=0.4, rasp=0.6, fry=0.6, drive=1.8)
            mass += vk * rk.uniform(0.4, 1.0)
        mass = lp(nrm(mass), 1800)
        sub = np.sin(2 * np.pi * np.cumsum(32 + 12 * np.clip(t / dur, 0, 1)) / SR) * 0.6
        x = (mass * 0.8 + sub) * env
        x = reverb(x, r, 2.6, 0.45, 2000, 0.03, bright=0.1)
        A.emit("horde_swell", "sfx/terror/horde_swell_%02d" % i, fit(x, dur), -1.5, volume_db=0.0, max_voices=1,
               bus="SFX", pitch=[0.96, 1.04], vol_jitter_db=1.0)


def write_manifest():
    path = A.AUDIO_JSON
    text = open(path, encoding="utf-8", newline="").read()
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
    os.makedirs(os.path.join(A.GL, "audio", "sfx", "terror"), exist_ok=True)
    gen_scream()
    gen_growl()
    gen_breath()
    gen_wet()
    gen_twitch()
    gen_gurgle()
    gen_swell()
    write_manifest()
    total = sum(s for _, s in A.STATS)
    print(f"gen_audio_terror: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
