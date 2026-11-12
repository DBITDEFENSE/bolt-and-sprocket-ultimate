#!/usr/bin/env python3
"""GRAVELIGHT T-240: the horses' sounds, synthesized from scratch (the living horse in the Inn's yard and the undead
ones of rounds 20 and 30).

No recordings and no samples: everything is gen_audio.py's DSP core (oscillators, filtered noise, the formant voice,
the noise-IR reverb) with gen_audio_bosses.py's building blocks, the way the boss pack was made. License: Owned (our
own work). The keys go into data/gravelight/audio.json as ONE block at the END of "sounds" (every key starts
"horse_", in sorted order), so a three-way merge with another branch's audio.json (tools/json_merge3.py) never meets
it; a key already there is replaced.

The living horse (gravelight/world/horse/horse.gd):
  horse_hoof_snow_1..4     a hoof into trodden snow: a soft thud and the crunch
  horse_hoof_wood_1..3     a shod hoof on boards: a hollow knock
  horse_hoof_stone_1..3    a shod hoof on stone: the clop
  horse_snort_1..3         a snort: the nostrils fluttering
  horse_blow_1..2          a long soft blow through the nose (a horse at rest)
  horse_neigh_1..2         a whinny: high, shuddering, falling to a nicker (horse_whinny is the ambience's far one)
  horse_tack_1..2          leather creaking, a buckle
The undead horse (gravelight/enemies/homage/horse_boss.gd):
  horse_boss_hoof_1..3     a heavy unshod hoof: the thud, grit, a dry knock of bone
  horse_boss_scream_1..3   the scream that is almost a whinny: the same shape gone wrong (a second voice under it, a
                           rattle in the throat)
  horse_boss_breath_1..3   a rattling breath out through a bare jaw
  horse_boss_snort_1..2    a low wet snort
  horse_boss_drag          trace chains and a broken shaft dragged over the ground, loop
  horse_boss_gallop_far    a gallop far off down the road, coming nearer (the round's announcement)
  horse_boss_crash_1..2    a ton of horse into a wall or a gate: the blow, wood splitting
  horse_boss_whip_1..2     the carter's whip: the whistle and the crack
  horse_boss_death         the last scream running down into a long rattle, and the fall

Run from the repo root:   python gravelight/tools_src/gen_audio_horse.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy, scipy and ffmpeg on PATH.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import gen_audio_bosses as B                 # noqa: E402  (its building blocks and its OGG emitter; nothing runs on import)
import numpy as np                           # noqa: E402

N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, adsr, place, fit = A.expenv, A.attack, A.adsr, A.place, A.fit
smooth_rand, reverb, echo = A.smooth_rand, A.reverb, A.echo
SR = A.SR
emit_ogg = B.emit_ogg


def r_(name: str, i: int = 0):
    return A.rng_for("horse_%s_%d" % (name, i))


# ─────────────────────────────────────────────────────────────── building blocks

def knock(r, f: float, sec: float, tau: float, q: float = 9.0, click: float = 0.5):
    """A short resonant knock: a noise burst through two resonances and a click on top."""
    n = N(sec)
    burst = white(r, sec) * expenv(n, 0.004)
    x = reson(burst, f, q) + 0.5 * reson(burst, f * 2.3, q * 0.8)
    x = x * expenv(n, tau) + lp(white(r, sec), 5000) * expenv(n, 0.002) * click
    return x


def flutter(r, sec: float, rate: float, depth: float = 0.9, jitter: float = 0.25):
    """The envelope of a flutter (nostrils, lips, a rattle in the throat): pulses at about `rate` Hz."""
    n = N(sec)
    f = rate * (1.0 + jitter * smooth_rand(r, sec, 8.0))
    ph = np.cumsum(f) / SR
    return 1.0 - depth * (0.5 + 0.5 * np.sin(2 * np.pi * ph)) ** 2


def whinny(r, sec: float, base: float, wrong: float = 0.0):
    """A horse's call: high and shuddering, falling to a nicker. `wrong` 0..1 bends it toward the dead one's scream:
    a second voice under it, fry in the source, the fall never arriving."""
    n = N(sec)
    contour = [(0.0, 1.5), (0.1, 2.1), (0.3, 1.9), (0.62, 1.2), (0.85, 0.7), (1.0, 0.42 + 0.5 * wrong)]
    f = A.pitch_curve(r, sec, base, contour, wobble=0.04 + 0.08 * wrong, vib_rate=11.0 + 3.0 * wrong, vib_depth=0.07 + 0.05 * wrong)
    v = A.voice(r, sec, f, ["i", "e", "ae", "a"], shift=1.15, breath=0.45, rasp=0.5 + 0.5 * wrong, fry=0.15 + 0.6 * wrong, drive=1.8 + wrong)
    shudder = 1.0 - 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * (10.5 + 2.0 * wrong) * tax(n) + r.uniform(0, 6.28))) * np.linspace(0.4, 1.0, n)
    v = v * shudder
    if wrong > 0.0:
        f2 = f * (0.5 ** (6.0 / 12.0)) * (1.0 + 0.02 * smooth_rand(r, sec, 2.0))     # a tritone under it
        v2 = A.voice(r, sec, f2, ["a", "o", "a"], shift=0.82, breath=0.3, rasp=1.0, fry=0.8, drive=2.6)
        v = v + wrong * 0.7 * v2 * flutter(r, sec, 22.0, 0.7)
        v = v + wrong * 0.25 * hp(white(r, sec), 2500) * shudder
    env = adsr(n, 0.04, 0.2, 0.85, 0.3)
    return lp(v * env, 6500)


def breath_noise(r, sec: float, lo: float, hi: float, rate: float = 0.0):
    n = N(sec)
    x = bp(pink(r, sec), lo, hi) * adsr(n, sec * 0.25, sec * 0.2, 0.7, sec * 0.4)
    if rate > 0.0:
        x = x * flutter(r, sec, rate)
    return x


# ─────────────────────────────────────────────────────────────── the living horse

def gen_hooves():
    for i in range(4):
        r = r_("snow", i)
        sec = 0.38
        n = N(sec)
        x = B.sub_thump(r, 70 + 5 * i, 42, sec, 0.07) * 0.7
        x += bp(A.crackle(r, sec, 260.0, 1.0, 900, 5200), 700, 5000) * expenv(n, 0.06) * 0.9      # the crunch
        x += bp(white(r, sec), 1500, 6000) * expenv(n, 0.035) * 0.35
        emit_ogg("horse_hoof_snow", "horse/horse_hoof_snow_%d" % (i + 1), x, peak_db=-4.0, bus="SFX", volume_db=-6.0, pitch=[0.92, 1.08], max_voices=6, attenuation="zombie")
    for i in range(3):
        r = r_("wood", i)
        sec = 0.35
        x = knock(r, 150.0 + 18 * i, sec, 0.07, 7.0, 0.4) + knock(r, 410.0 + 30 * i, sec, 0.03, 10.0, 0.2) * 0.6
        x += B.sub_thump(r, 90, 50, sec, 0.05) * 0.5
        x = reverb(x, r, decay=0.5, wet=0.18, damp=2500)
        emit_ogg("horse_hoof_wood", "horse/horse_hoof_wood_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-5.0, pitch=[0.93, 1.07], max_voices=6, attenuation="zombie")
    for i in range(3):
        r = r_("stone", i)
        sec = 0.3
        x = knock(r, 820.0 + 90 * i, sec, 0.028, 12.0, 0.9) + knock(r, 1650.0 + 120 * i, sec, 0.012, 14.0, 0.5) * 0.7
        x += B.sub_thump(r, 110, 60, sec, 0.035) * 0.35
        x = reverb(x, r, decay=0.7, wet=0.2, damp=5000)
        emit_ogg("horse_hoof_stone", "horse/horse_hoof_stone_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-5.0, pitch=[0.93, 1.07], max_voices=6, attenuation="zombie")


def gen_breaths():
    for i in range(3):
        r = r_("snort", i)
        sec = 0.55 + 0.08 * i
        n = N(sec)
        x = bp(white(r, sec), 280, 2600) * flutter(r, sec, 26.0 + 3 * i, 0.95) * expenv(n, 0.22) * attack(n, 0.01)
        x += reson(pink(r, sec), 190.0, 3.0) * expenv(n, 0.12) * 0.6
        emit_ogg("horse_snort", "horse/horse_snort_%d" % (i + 1), x, peak_db=-5.0, bus="SFX", volume_db=-5.0, pitch=[0.93, 1.07], attenuation="zombie")
    for i in range(2):
        r = r_("blow", i)
        sec = 1.3 + 0.2 * i
        x = breath_noise(r, sec, 180, 1700) + 0.5 * breath_noise(r, sec, 600, 3200, 14.0)
        emit_ogg("horse_blow", "horse/horse_blow_%d" % (i + 1), x, peak_db=-9.0, bus="SFX", volume_db=-9.0, pitch=[0.94, 1.06], attenuation="quiet")
    for i in range(2):
        r = r_("whinny", i)
        sec = 1.7 + 0.25 * i
        x = whinny(r, sec, 560.0 + 50 * i)
        # the nicker it ends in: low pulses
        nk = N(0.5)
        nick = reson(white(r, 0.5), 210.0, 4.0) * flutter(r, 0.5, 17.0, 0.95) * expenv(nk, 0.25)
        place(x, nick, sec - 0.5, 0.5)
        x = reverb(x, r, decay=0.9, wet=0.15, damp=4000)
        emit_ogg("horse_neigh", "horse/horse_neigh_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-4.0, pitch=[0.96, 1.04], attenuation="zombie")
    for i in range(2):
        r = r_("tack", i)
        sec = 0.9
        n = N(sec)
        creak = reson(A.scrape(r, sec, 300, 1400, 28.0), 520.0 + 90 * i, 6.0) * adsr(n, 0.05, 0.2, 0.5, 0.3) * 0.7
        x = creak
        for k in range(2 + i):
            place(x, B.metal_ring(r, 2300.0 + 500 * k, 0.25, 0.05, (1.0, 2.4, 4.1), 0.5) * 0.35, 0.2 + 0.22 * k)
        emit_ogg("horse_tack", "horse/horse_tack_%d" % (i + 1), x, peak_db=-8.0, bus="SFX", volume_db=-8.0, pitch=[0.92, 1.08], attenuation="quiet")


# ─────────────────────────────────────────────────────────────── the undead horse

def boss_hoof(r, i: int, sec: float = 0.8):
    n = N(sec)
    x = B.sub_thump(r, 95 + 6 * i, 38, sec, 0.2)
    x += A.crackle(r, sec, 90.0, 1.0, 700, 4500) * expenv(n, 0.12) * 0.45
    x += knock(r, 900.0 + 110 * i, sec, 0.02, 10.0, 0.6) * 0.5        # bone on the ground
    return x


def gen_boss_hooves():
    for i in range(3):
        r = r_("bhoof", i)
        x = reverb(boss_hoof(r, i), r, decay=0.9, wet=0.2, damp=1800)
        emit_ogg("horse_boss_hoof", "horse/horse_boss_hoof_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-3.0, pitch=[0.9, 1.08], max_voices=6)
    # far off, coming nearer: the gallop's four beats and its silence, three seconds of road, then close
    r = r_("far")
    sec = 6.5
    n = N(sec)
    x = np.zeros(n)
    stride = 0.5
    t0 = 0.2
    k = 0
    while t0 < sec - 0.6:
        near = min(1.0, (t0 / sec) ** 1.6)
        for off, g in ((0.0, 0.8), (0.07, 0.9), (0.2, 1.0), (0.27, 0.85)):
            h = boss_hoof(r, k % 3, 0.5)
            h = lp(h, 500.0 + 3500.0 * near)
            place(x, h, t0 + off, g * (0.12 + 0.88 * near))
        t0 += stride * (1.0 - 0.12 * near)
        k += 1
    chain = np.zeros(n)
    for j in range(40):
        tt = r.uniform(0.5, sec - 0.4)
        place(chain, B.metal_ring(r, r.uniform(1800, 3600), 0.2, 0.04, (1.0, 2.7), 0.5), tt, 0.08 * (tt / sec) ** 2)
    x = x + chain
    x = reverb(x, r, decay=2.4, wet=0.45, damp=1600)
    emit_ogg("horse_boss_gallop_far", "horse/horse_boss_gallop_far", x, peak_db=-3.0, bus="SFX", volume_db=0.0, attenuation="world")


def gen_boss_voice():
    for i in range(3):
        r = r_("scream", i)
        sec = 2.0 + 0.3 * i
        x = whinny(r, sec, 520.0 - 40 * i, 0.75 + 0.1 * i)
        # the rattle it ends in
        rt = 0.7
        rat = bp(white(r, rt), 300, 2400) * flutter(r, rt, 21.0, 0.97) * expenv(N(rt), 0.4)
        place(x, rat, sec - rt, 0.45)
        x = sat(x, 1.6)
        x = reverb(x, r, decay=2.2, wet=0.32, damp=3500)
        emit_ogg("horse_boss_scream", "horse/horse_boss_scream_%d" % (i + 1), x, peak_db=-1.5, bus="SFX", volume_db=-1.0, pitch=[0.95, 1.05], attenuation="world")
    for i in range(3):
        r = r_("bbreath", i)
        sec = 1.5 + 0.15 * i
        x = breath_noise(r, sec, 140, 1500, 16.0 + 2 * i) + 0.4 * A.crackle(r, sec, 40.0, 1.0, 500, 3000) * adsr(N(sec), 0.3, 0.3, 0.6, 0.5)
        x += reson(brown(r, sec), 95.0, 4.0) * adsr(N(sec), 0.3, 0.3, 0.6, 0.5) * 0.5
        emit_ogg("horse_boss_breath", "horse/horse_boss_breath_%d" % (i + 1), x, peak_db=-7.0, bus="SFX", volume_db=-7.0, pitch=[0.9, 1.08])
    for i in range(2):
        r = r_("bsnort", i)
        sec = 0.75
        n = N(sec)
        x = bp(white(r, sec), 160, 1800) * flutter(r, sec, 19.0 + 3 * i, 0.97) * expenv(n, 0.3) * attack(n, 0.01)
        x += reson(pink(r, sec), 120.0, 3.0) * expenv(n, 0.2) * 0.8
        x = sat(x, 1.4)
        emit_ogg("horse_boss_snort", "horse/horse_boss_snort_%d" % (i + 1), x, peak_db=-4.0, bus="SFX", volume_db=-4.0, pitch=[0.92, 1.06])
    # the death: the scream runs down into a long rattle; the body goes over
    r = r_("death")
    sec = 4.2
    x = np.zeros(N(sec))
    sc = whinny(r, 2.4, 470.0, 1.0)
    sc = A.varispeed(sc, np.linspace(1.0, 0.55, len(sc)))
    place(x, sc, 0.0, 1.0)
    rat = bp(white(r, 2.2), 220, 1800) * flutter(r, 2.2, 15.0, 0.97) * expenv(N(2.2), 0.9)
    place(x, rat, 1.9, 0.5)
    place(x, B.sub_thump(r, 70, 30, 1.0, 0.35) + A.crackle(r, 1.0, 70.0, 1.0, 600, 4000) * expenv(N(1.0), 0.2) * 0.4, 2.6, 1.0)
    x = reverb(x, r, decay=2.6, wet=0.3, damp=3000)
    emit_ogg("horse_boss_death", "horse/horse_boss_death", x, peak_db=-1.5, bus="SFX", volume_db=0.0, attenuation="world")


def gen_boss_things():
    # the traces and the shaft dragged over the ground
    r = r_("drag")
    sec = 4.0
    n = N(sec)
    scrape = bp(A.scrape(r, sec, 250, 2200, 30.0), 200, 2600) * (0.6 + 0.4 * smooth_rand(r, sec, 4.0, 0.0, 1.0))
    links = np.zeros(n)
    for j in range(46):
        tt = r.uniform(0.0, sec - 0.25)
        place(links, B.metal_ring(r, r.uniform(1500, 4200), 0.22, 0.035, (1.0, 2.76, 5.1), 0.55), tt, r.uniform(0.15, 0.5))
    knocks = np.zeros(n)
    for j in range(7):
        place(knocks, knock(r, r.uniform(170, 260), 0.3, 0.05, 6.0, 0.3), r.uniform(0.0, sec - 0.35), 0.5)
    x = scrape * 0.6 + links + knocks
    x = A.loopify(x, 0.4)
    emit_ogg("horse_boss_drag", "horse/horse_boss_drag", x, peak_db=-8.0, loop=True, bus="SFX", volume_db=-6.0)
    for i in range(2):
        r = r_("crash", i)
        sec = 1.6
        n = N(sec)
        x = B.sub_thump(r, 120 + 20 * i, 34, sec, 0.3) * 1.2
        x += lp(white(r, sec), 2500) * expenv(n, 0.05)
        split = A.crackle(r, sec, 110.0, 1.0, 500, 6000) * expenv(n, 0.3) * 0.7        # wood going
        for k in range(4):
            place(split, knock(r, r.uniform(240, 600), 0.25, 0.04, 8.0, 0.8), 0.05 + 0.12 * k + r.uniform(0, 0.05), 0.7)
        x = x + split
        x = reverb(x, r, decay=1.4, wet=0.25, damp=2500)
        emit_ogg("horse_boss_crash", "horse/horse_boss_crash_%d" % (i + 1), x, peak_db=-1.5, bus="SFX", volume_db=-1.0, pitch=[0.92, 1.06])
    for i in range(2):
        r = r_("whip", i)
        sec = 0.9
        n = N(sec)
        x = np.zeros(n)
        wl = 0.42
        whistle = A.sweep_noise(r, wl, 500.0, 5200.0, q=5.0) * np.linspace(0.1, 1.0, N(wl)) ** 2
        place(x, whistle, 0.0, 0.5)
        crack = hp(white(r, 0.2), 1800) * expenv(N(0.2), 0.012) + lp(white(r, 0.2), 900) * expenv(N(0.2), 0.03) * 0.5
        place(x, crack, wl, 1.4)
        x = echo(x, 0.11, 0.25, 3000.0, 2)
        x = reverb(x, r, decay=0.9, wet=0.2, damp=6000)
        emit_ogg("horse_boss_whip", "horse/horse_boss_whip_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-2.0, pitch=[0.95, 1.05])


# ─────────────────────────────────────────────────────────────── the manifest: one block at the end of "sounds"

def write_manifest():
    path = A.AUDIO_JSON
    text = open(path, encoding="utf-8").read()
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
    gen_hooves()
    gen_breaths()
    gen_boss_hooves()
    gen_boss_voice()
    gen_boss_things()
    write_manifest()
    total = sum(s for _, s in B.STATS)
    print(f"gen_audio_horse: wrote {len(B.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
