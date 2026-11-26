#!/usr/bin/env python3
"""GRAVELIGHT T-280: the layers of an explosion's sound, synthesized from scratch (no recordings, no samples).

gen_audio.py's DSP core, the way the war and Sherman packs were made. License: Ours (original work). They play on top
of the boom each caller already plays (grenade_explode, explosion_large, war_artillery_near, ...), from BlastFx:

  blast_crack_1..3       the near crack of the detonation: a hard broadband snap and the slap of the blast wave
  blast_rumble_far_1..3  far off: the highs gone, a long rolling rumble off the hills (BlastFx delays it by d / 343 s)
  blast_debris_1..3      what comes down after: clods and grit pattering, a few stones knocking, a hiss of dirt
  blast_pop_1..2         a small blast (a switchboard, a fuse box): a sharp electric pop with a sizzle

The keys go into data/gravelight/audio.json as ONE block at the END of "sounds" (sorted), so a three-way merge with
another branch's audio.json never meets it; a key already there is replaced.

Run from the repo root:   python gravelight/tools_src/gen_audio_blast.py
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
expenv, attack, place, fit = A.expenv, A.attack, A.place, A.fit
reverb, echo, emit, crackle = A.reverb, A.echo, A.emit, A.crackle
SR = A.SR
LOUD = dict(bus="SFX", attenuation="loud")


def gen_crack():
    for i in A.variants(3):
        r = A.rng_for("blast_crack%d" % i)
        sec = 1.4
        n = N(sec)
        t = tax(n)
        snap = nrm(hp(white(r, sec), 1500, 2)) * np.exp(-t / 0.0035)
        slap = nrm(bp(white(r, sec), 250, 3000, 2)) * np.exp(-t / 0.03) * attack(n, 0.0008)
        f = 55 + 140 * np.exp(-t / 0.018)
        thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
        x = 1.0 * snap + 0.8 * slap + 0.9 * thump
        x = sat(x * 2.2, 1.0)
        x = reverb(x, r, 0.9, 0.22, 4000, 0.008, bright=0.25)
        emit("blast_crack", "sfx/blast/blast_crack_%02d" % i, fit(x, sec), -0.5, volume_db=0.0, pitch=[0.9, 1.1],
             max_voices=4, **LOUD)


def gen_rumble():
    for i in A.variants(3):
        r = A.rng_for("blast_rumble%d" % i)
        sec = 5.5
        n = N(sec)
        t = tax(n)
        body = nrm(lp(brown(r, sec), 110, 2)) * (np.exp(-t / 1.4) * attack(n, 0.06))
        roll = nrm(lp(brown(r, sec), 60, 2)) * A.smooth_rand(r, sec, 2.2, 0.5, 1.0) * np.exp(-t / 2.0) * attack(n, 0.15)
        f = 34 + 26 * np.exp(-t / 0.12)
        boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.5) * attack(n, 0.01)
        x = 0.9 * body + 0.7 * roll + 0.6 * boom
        x = lp(x, 420, 2)
        x = reverb(x, r, 4.0, 0.6, 900, 0.05, bright=0.03)
        x = echo(x, r.uniform(0.7, 1.2), 0.3, 500, 3)
        emit("blast_rumble_far", "sfx/blast/blast_rumble_far_%02d" % i, fit(x, sec), -1.0, volume_db=0.0,
             pitch=[0.88, 1.06], max_voices=3, **LOUD)


def gen_debris():
    for i in A.variants(3):
        r = A.rng_for("blast_debris%d" % i)
        sec = 2.6
        n = N(sec)
        t = tax(n)
        # falling: density rises fast, then thins out over two seconds
        env = np.clip(t / 0.12, 0, 1) * np.exp(-t / 0.75)
        grit = crackle(r, sec, 380, 1.0, 1500, 9000) * env
        clods = crackle(r, sec, 70, 1.0, 180, 1800) * env
        x = 0.55 * grit + 0.9 * clods
        for _ in range(int(r.integers(4, 8))):     # a few stones knocking on something hard
            at = r.uniform(0.05, 1.4)
            k = A.kick(r, r.uniform(0.3, 0.7), r.uniform(500, 900), r.uniform(240, 400), r.uniform(0.012, 0.03), 0.2)
            place(x, k, at)
        hiss = nrm(bp(white(r, sec), 2500, 8000)) * env * 0.18
        x = x + hiss
        x = reverb(x, r, 0.8, 0.2, 5000, 0.01, bright=0.2)
        emit("blast_debris", "sfx/blast/blast_debris_%02d" % i, fit(x, sec), -2.0, volume_db=0.0, pitch=[0.9, 1.1],
             max_voices=3, bus="SFX", attenuation="world")


def gen_pop():
    for i in A.variants(2):
        r = A.rng_for("blast_pop%d" % i)
        sec = 1.2
        n = N(sec)
        t = tax(n)
        pop = nrm(hp(white(r, sec), 900, 2)) * np.exp(-t / 0.006)
        thump = A.kick(r, 0.7, 260, 90, 0.05, sec)
        buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * np.exp(-t / 0.05) * 0.25
        sizzle = crackle(r, sec, 220, 1.0, 2500, 10000) * np.exp(-t / 0.35) * attack(n, 0.02) * 0.6
        x = sat((pop + 0.8 * thump + buzz + sizzle) * 1.6, 1.0)
        x = reverb(x, r, 0.7, 0.2, 5000, 0.006, bright=0.2)
        emit("blast_pop", "sfx/blast/blast_pop_%02d" % i, fit(x, sec), -1.0, volume_db=0.0, pitch=[0.92, 1.08],
             max_voices=2, bus="SFX", attenuation="world")


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
    os.makedirs(os.path.join(A.GL, "audio", "sfx", "blast"), exist_ok=True)
    gen_crack()
    gen_rumble()
    gen_debris()
    gen_pop()
    write_manifest()
    total = sum(s for _, s in A.STATS)
    print(f"gen_audio_blast: wrote {len(A.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
