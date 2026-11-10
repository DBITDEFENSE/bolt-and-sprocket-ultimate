#!/usr/bin/env python3
"""GRAVELIGHT T-231 (docs/BOSS_REWORK.md section 3): the boss battles' sounds, synthesized from scratch.

No recordings and no samples: everything is gen_audio.py's DSP core (oscillators, filtered noise, the formant voice,
the noise-IR reverb, the bell partials). No real person's voice is imitated: the "giggle" is a music-box tinkle with a
wordless vowel shape, the roars are formant growls. License: Owned (our own work). Keys merged into
data/gravelight/audio.json (a key already there is replaced).

Shared (every boss, through BossFx / DreadFx):
  boss_dread_bed          the presence bed: a sub drone with a slow throb and a faint metallic shimmer, 24 s loop
  boss_pulse              a slow double thud like a heart heard through water, 1 s loop (DreadFx pitches it by level)
  boss_stomp_1..3         a heavy footfall: sub thump, grit, a little debris
  boss_hit_porcelain_1..3 a glazed shell chipping
  boss_hit_iron_1..3      a round on plate: a clang, a ring
  boss_hit_flesh_1..3     a wet thud
  boss_hit_glass_1..2     glass cracking under a hit
  boss_hit_cloth_1..2     a dull thump through cloth
  boss_weakpoint_hit_1..2 a violet glass crack with a chime (the Marke / a weak point taking it)
  boss_telegraph_rise     a 0.8 s rising whine under a wind-up
  boss_death_toll         a low bell and a long exhale of wind
  boss_roar_low_1..3      a chest-deep roar (formant growl, no words)
  boss_breath_1..3        a slow wet breath in and out
  boss_bone_crack_1..2    joints cracking
Per boss:
  boss_doll_giggle_1..3   a music-box tinkle with a detuned wordless "hee" over it, stopped short (the Cousins)
  boss_doll_crack         porcelain splitting (a death, a big hit)
  boss_hum_wrong          a lullaby hummed a quarter-tone flat, loop (the Cousins' hum when enraged)
  paul_roar_1..2          PAUL's roar: deeper, with the plates' grind in it
  paul_bottle_break_1..2  a stout bottle bursting and the hiss of the stout
  paul_plate_grind        riveted plates grinding as he grows
  slender_lantern_hum     the violet lantern's hum, loop
  slender_keys_still      the key ring's jingle that stops dead (the Lash tell)
  slender_whisper_1..3    a wordless whisper, close, patient
  kielholer_chain_drag    an anchor chain dragged through water, loop
  kielholer_water_rise_1..2 a big body surfacing: water falling off brass
  kielholer_helmet_knock  a knuckle on a diving helmet's glass
  foreman_drill_spin      the pneumatic drill spinning up and running, loop
  foreman_chain_whip      the ore chain whipping round
  kran_rail_screech_1..2  the crane trolley's wheels on the rail
  kran_casing_drop        a bomb casing's whistle and impact
  bordwart_cable_sing     the taut cable singing before the lash
  bordwart_impeller_loop  the impeller spinning up, loop
  pilot_rig_whine         the jump rig's turbine whine, loop
  pilot_rig_misfire       the rig misfiring: a cough, a bang, a dying whine
  manager_servo_1..2      an executive machine's servos
  manager_stamp           a ledger stamp slammed down
  manager_field_hum       the violet field's hum, loop

Run from the repo root:   python gravelight/tools_src/gen_audio_bosses.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy, scipy and ffmpeg on PATH.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile

_argv = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import numpy as np                           # noqa: E402

N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, adsr, place, fit = A.expenv, A.attack, A.adsr, A.place, A.fit
smooth_rand, reverb, echo = A.smooth_rand, A.reverb, A.echo
sine, saw, square = A.sine, A.saw, A.square
SR = A.SR
STATS: list[tuple[str, float]] = []


def r_(name: str, i: int = 0):
    return A.rng_for("boss_%s_%d" % (name, i))


# ─────────────────────────────────────────────────────────────── emit (OGG, like the horror pack)

def emit_ogg(key: str, rel: str, x, peak_db: float = -1.0, loop: bool = False, **meta):
    entry = A.KEYS.setdefault(key, {"files": []})
    for k, v in meta.items():
        entry[k] = v
    if loop:
        entry["loop"] = True
    entry["files"].append("res://gravelight/audio/" + rel + ".ogg")
    x = np.nan_to_num(np.asarray(x, dtype=float))
    x = x - np.mean(x, axis=0)
    x = nrm(x, 10 ** (peak_db / 20.0))
    if not loop:
        x = A.fade(x, 0.002, 0.04)
    out = os.path.join(A.GL, "audio", rel + ".ogg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "x.wav")
        A.write_wav(wav, x, False)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    STATS.append((rel, len(x) / SR))


def write_manifest():
    """Merges this script's keys into data/gravelight/audio.json as text (the horror pack's way)."""
    import json
    import re
    path = A.AUDIO_JSON
    text = open(path, encoding="utf-8").read()
    for key in A.KEYS:
        text = re.sub(r'\n    "%s": \{.*?\n    \},?' % re.escape(key), "", text, flags=re.S)
    blocks = []
    for key in sorted(A.KEYS):
        body = json.dumps(A.KEYS[key], indent=2, ensure_ascii=False)
        body = "\n".join(("    " + ln) if i else ln for i, ln in enumerate(body.splitlines()))
        blocks.append('    "%s": %s,' % (key, body))
    anchor = '  "sounds": {\n'
    assert anchor in text
    text = text.replace(anchor, anchor + "\n".join(blocks) + "\n", 1)
    json.loads(text)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


# ─────────────────────────────────────────────────────────────── building blocks

def sub_thump(r, f0=70.0, f1=38.0, sec=0.9, tau=0.22):
    """A pitch-dropping sine thump with a click of grit on top."""
    n = N(sec)
    t = tax(n)
    f = f1 + (f0 - f1) * np.exp(-t / 0.06)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * expenv(n, tau)
    grit = lp(white(r, sec), 1800) * expenv(n, 0.03) * 0.5
    return sat(body + grit, 1.6)


def metal_ring(r, f: float, sec: float, decay: float, partials=(1.0, 2.76, 5.4, 8.9), bright=0.6):
    n = N(sec)
    out = np.zeros(n)
    for i, p in enumerate(partials):
        out += np.sin(2 * np.pi * f * p * tax(n) + r.uniform(0, 6.28)) * expenv(n, decay / (1.0 + i * 0.9)) * (bright ** i)
    return out


def growl(r, sec: float, f0: float, contour, vowels=("o", "a", "o"), rasp=0.6, drive=2.4):
    """A formant growl: the voice generator pushed low with rasp and saturation."""
    f = A.pitch_curve(r, sec, f0, contour, wobble=0.08)
    v = A.voice(r, sec, f, list(vowels), shift=0.78, breath=0.2, rasp=rasp)
    v = sat(v, drive)
    return lp(v, 2600)


def wind(r, sec: float, f_lo=180.0, f_hi=900.0, rate=0.3):
    n = N(sec)
    c = smooth_rand(r, sec, rate, 0.0, 1.0)
    x = pink(r, sec)
    out = np.zeros(n)
    for i in range(3):
        fc = f_lo * (f_hi / f_lo) ** ((c + i * 0.3) % 1.0)
        out += reson(x, np.mean(fc) * (1 + 0.4 * i), 5.0) * 0.5
    return out * (0.5 + 0.5 * c)


# ─────────────────────────────────────────────────────────────── shared

def gen_dread_bed():
    r = r_("bed")
    sec = 24.0
    n = N(sec)
    t = tax(n)
    # a sub drone on two detuned sines with a slow throb
    f = 41.2
    drone = (np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * (f * 1.003) * t + 1.0) + 0.3 * np.sin(2 * np.pi * (f * 2.01) * t))
    throb = 0.6 + 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t))
    drone *= throb
    # a metallic shimmer far behind: ringing partials excited by soft crackle
    shim = np.zeros(n)
    for k in range(5):
        shim += reson(A.crackle(r, sec, 1.5, 0.3, 600, 3000), 420.0 * (1.37 ** k), 40.0) * (0.5 ** k)
    shim = hp(shim, 500) * 0.18 * smooth_rand(r, sec, 0.25, 0.3, 1.0)
    # air moving
    air = lp(brown(r, sec), 140) * 0.35
    x = drone * 0.7 + shim + air
    x = reverb(x, r, decay=3.5, wet=0.3, damp=1800)
    x = A.loopify(x, 1.5)
    emit_ogg("boss_dread_bed", "bosses/boss_dread_bed", x, peak_db=-6.0, loop=True, bus="Ambience", volume_db=-4.0)


def gen_pulse():
    r = r_("pulse")
    sec = 1.0
    n = N(sec)
    x = np.zeros(n)
    place(x, sub_thump(r, 62, 34, 0.5, 0.16), 0.0, 1.0)
    place(x, sub_thump(r, 52, 30, 0.5, 0.14), 0.22, 0.7)
    x = lp(x, 240)
    x = reverb(x, r, decay=1.2, wet=0.35, damp=800)
    x = A.loopify(fit(x, sec), 0.08)
    emit_ogg("boss_pulse", "bosses/boss_pulse", x, peak_db=-4.0, loop=True, bus="SFX", volume_db=-6.0)


def gen_stomps():
    for i in range(3):
        r = r_("stomp", i)
        sec = 1.1
        n = N(sec)
        x = sub_thump(r, 85 + i * 6, 40, sec, 0.3) * 1.0
        # debris and grit after the impact
        deb = A.crackle(r, sec, 60.0, 1.0, 900, 5000) * expenv(n, 0.25) * 0.4
        x = x + deb + lp(white(r, sec), 400) * expenv(n, 0.05) * 0.8
        x = reverb(x, r, decay=1.0, wet=0.2, damp=1500)
        emit_ogg("boss_stomp", "bosses/boss_stomp_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-2.0, pitch=[0.92, 1.08])


def gen_hits():
    for i in range(3):
        r = r_("porc", i)
        sec = 0.6
        n = N(sec)
        x = np.zeros(n)
        for k in range(6):
            f = r.uniform(2400, 6800)
            place(x, metal_ring(r, f, 0.25, 0.05, (1.0, 1.9, 3.3), 0.5) * r.uniform(0.3, 1.0), r.uniform(0.0, 0.08))
        x += hp(white(r, sec), 3000) * expenv(n, 0.015) * 0.8
        emit_ogg("boss_hit_porcelain", "bosses/boss_hit_porcelain_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-4.0, pitch=[0.95, 1.08])
    for i in range(3):
        r = r_("iron", i)
        sec = 0.9
        n = N(sec)
        x = metal_ring(r, r.uniform(380, 560), sec, 0.35, (1.0, 2.1, 3.4, 5.6, 7.9), 0.62)
        x += lp(white(r, sec), 2500) * expenv(n, 0.012) * 1.2
        x = sat(x, 1.4)
        emit_ogg("boss_hit_iron", "bosses/boss_hit_iron_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-5.0, pitch=[0.9, 1.1])
    for i in range(3):
        r = r_("flesh", i)
        sec = 0.5
        n = N(sec)
        x = lp(white(r, sec), 900) * expenv(n, 0.05) + sub_thump(r, 120, 70, sec, 0.08) * 0.6
        x += lp(A.crackle(r, sec, 30, 1.0, 300, 1400), 1500) * expenv(n, 0.12) * 0.4
        emit_ogg("boss_hit_flesh", "bosses/boss_hit_flesh_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-5.0, pitch=[0.9, 1.1])
    for i in range(2):
        r = r_("glass", i)
        sec = 0.7
        n = N(sec)
        x = np.zeros(n)
        for k in range(9):
            place(x, metal_ring(r, r.uniform(3200, 9000), 0.3, 0.06, (1.0, 1.6, 2.7), 0.45) * r.uniform(0.2, 1.0), r.uniform(0.0, 0.15))
        x += hp(white(r, sec), 5000) * expenv(n, 0.02)
        emit_ogg("boss_hit_glass", "bosses/boss_hit_glass_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-5.0, pitch=[0.95, 1.1])
    for i in range(2):
        r = r_("cloth", i)
        sec = 0.4
        n = N(sec)
        x = lp(white(r, sec), 600) * expenv(n, 0.06) + sub_thump(r, 90, 60, sec, 0.06) * 0.4
        emit_ogg("boss_hit_cloth", "bosses/boss_hit_cloth_%d" % (i + 1), x, peak_db=-4.0, bus="SFX", volume_db=-6.0, pitch=[0.9, 1.1])
    for i in range(2):
        r = r_("weak", i)
        sec = 1.2
        n = N(sec)
        x = np.zeros(n)
        for k in range(7):
            place(x, metal_ring(r, r.uniform(2600, 7000), 0.4, 0.08, (1.0, 1.5, 2.4), 0.5) * r.uniform(0.3, 1.0), r.uniform(0.0, 0.1))
        place(x, A.bell(r, 1174.7 * (1.0 if i == 0 else 1.5), 1.0, decay=0.9, strike=0.5, bright=0.8) * 0.6, 0.02)
        x = x + hp(white(r, sec), 4000) * expenv(n, 0.02)
        x = reverb(x, r, decay=1.4, wet=0.3, damp=4000)
        emit_ogg("boss_weakpoint_hit", "bosses/boss_weakpoint_hit_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-3.0)


def gen_telegraph_rise():
    r = r_("tele")
    sec = 0.8
    n = N(sec)
    t = tax(n)
    f = 180.0 * (3.2 ** (t / sec))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sin(ph) * 0.6 + saw(f) * 0.25) * attack(n, 0.12) * (0.4 + 0.6 * t / sec)
    x = lp(x, 2200) + reson(white(r, sec), np.mean(f) * 1.5, 8.0) * 0.2 * (t / sec)
    x = x * np.concatenate([np.ones(n - N(0.06)), np.linspace(1, 0, N(0.06))])
    emit_ogg("boss_telegraph_rise", "bosses/boss_telegraph_rise", x, peak_db=-6.0, bus="SFX", volume_db=-6.0)


def gen_death_toll():
    r = r_("toll")
    sec = 6.0
    n = N(sec)
    x = A.bell(r, 98.0, sec, decay=4.5, strike=0.7, bright=0.5) * 0.9
    x += wind(r, sec, 120, 600, 0.2) * np.concatenate([np.linspace(0, 1, N(1.5)), np.linspace(1, 0, n - N(1.5))]) * 0.5
    x = reverb(x, r, decay=4.0, wet=0.4, damp=1600)
    emit_ogg("boss_death_toll", "bosses/boss_death_toll", x, peak_db=-2.0, bus="SFX", volume_db=-2.0)


def gen_roars_breaths_bones():
    for i in range(3):
        r = r_("roar", i)
        sec = 2.0 + 0.3 * i
        x = growl(r, sec, 95.0 - 10 * i, [(0.0, 0.8), (0.3, 1.1), (0.7, 1.0), (1.0, 0.7)], ("o", "a", "o"), rasp=0.7, drive=2.6)
        x = x * adsr(len(x), 0.15, 0.3, 0.8, 0.5)
        x = reverb(x, r, decay=1.6, wet=0.25, damp=2000)
        emit_ogg("boss_roar_low", "bosses/boss_roar_low_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-2.0, pitch=[0.92, 1.06])
    for i in range(3):
        r = r_("breath", i)
        sec = 2.6
        n = N(sec)
        t = tax(n)
        env_in = np.exp(-((t - 0.7) ** 2) / 0.18)
        env_out = np.exp(-((t - 1.8) ** 2) / 0.3)
        x = bp(white(r, sec), 300, 1800) * env_in * 0.6 + bp(white(r, sec), 180, 900) * env_out * 0.9
        x += lp(A.crackle(r, sec, 25, 1.0, 200, 1200), 1200) * env_out * 0.25   # wet
        x = A.formant(x, "o", shift=0.9)
        emit_ogg("boss_breath", "bosses/boss_breath_%d" % (i + 1), x, peak_db=-6.0, bus="SFX", volume_db=-6.0, pitch=[0.9, 1.1])
    for i in range(2):
        r = r_("bone", i)
        sec = 0.6
        n = N(sec)
        x = np.zeros(n)
        for k in range(4 + i * 2):
            place(x, lp(white(r, 0.05), 3000) * expenv(N(0.05), 0.008) * r.uniform(0.5, 1.0), r.uniform(0.0, 0.4))
        x += lp(A.crackle(r, sec, 80, 1.0, 400, 2500), 2500) * expenv(n, 0.2) * 0.5
        emit_ogg("boss_bone_crack", "bosses/boss_bone_crack_%d" % (i + 1), x, peak_db=-4.0, bus="SFX", volume_db=-6.0)


# ─────────────────────────────────────────────────────────────── the Cousins

def gen_doll():
    for i in range(3):
        r = r_("giggle", i)
        sec = 1.6
        n = N(sec)
        x = np.zeros(n)
        notes = [1318.5, 1567.98, 1760.0, 2093.0]
        for k in range(4 + i):
            place(x, A.music_box(r, notes[(k + i) % 4], 0.6) * 0.5, 0.08 * k)
        # a wordless "hee" shape, detuned, no voice imitated: a formant on a thin pulse
        f = A.pitch_curve(r, 0.9, 520.0 + 40 * i, [(0.0, 1.0), (0.3, 1.15), (0.6, 1.1), (1.0, 0.95)], wobble=0.12)
        v = A.voice(r, 0.9, f, ["i", "e"], shift=1.25, breath=0.4, rasp=0.1)
        v = v * np.concatenate([np.ones(N(0.78)), np.zeros(N(0.9) - N(0.78))])   # stopped short
        place(x, v * 0.45, 0.15)
        x = reverb(x, r, decay=0.9, wet=0.2, damp=5000)
        x = fit(x, 1.1 + 0.1 * i)
        emit_ogg("boss_doll_giggle", "bosses/boss_doll_giggle_%d" % (i + 1), x, peak_db=-6.0, bus="SFX", volume_db=-6.0, pitch=[0.96, 1.05])
    r = r_("dollcrack")
    sec = 1.4
    n = N(sec)
    x = np.zeros(n)
    for k in range(14):
        place(x, metal_ring(r, r.uniform(1800, 7000), 0.3, 0.05, (1.0, 1.9, 3.1), 0.5) * r.uniform(0.3, 1.0), r.uniform(0.0, 0.5) ** 1.5)
    x += lp(A.crackle(r, sec, 50, 1.0, 1000, 6000), 7000) * expenv(n, 0.35)
    x = reverb(x, r, decay=1.0, wet=0.25, damp=4000)
    emit_ogg("boss_doll_crack", "bosses/boss_doll_crack", x, peak_db=-2.0, bus="SFX", volume_db=-3.0)
    # the hum, flat: a lullaby line hummed through closed lips a quarter-tone under
    r = r_("hum")
    sec = 6.0
    melody = [(0.0, 1.0), (0.17, 1.122), (0.34, 1.26), (0.5, 1.122), (0.67, 1.0), (0.84, 0.89), (1.0, 1.0)]
    f = A.pitch_curve(r, sec, 196.0 * 2 ** (-0.5 / 12), melody, wobble=0.04)
    v = A.voice(r, sec, f, ["m", "m"], shift=1.0, breath=0.3, rasp=0.05) if "m" in getattr(A, "VOWELS", {"m": 1}) else A.voice(r, sec, f, ["o", "u"], shift=1.0, breath=0.3, rasp=0.05)
    v = lp(v, 1400)
    v = reverb(v, r, decay=1.2, wet=0.2, damp=3000)
    v = A.loopify(v, 0.4)
    emit_ogg("boss_hum_wrong", "bosses/boss_hum_wrong", v, peak_db=-8.0, loop=True, bus="SFX", volume_db=-8.0)


# ─────────────────────────────────────────────────────────────── PAUL

def gen_paul():
    for i in range(2):
        r = r_("paulroar", i)
        sec = 2.4
        x = growl(r, sec, 72.0 - 6 * i, [(0.0, 0.85), (0.25, 1.15), (0.7, 1.05), (1.0, 0.8)], ("o", "a", "a"), rasp=0.8, drive=3.0)
        grind = reson(A.crackle(r, sec, 400, 1.0, 300, 2500), 210.0, 6.0) * 0.3 * adsr(N(sec), 0.3, 0.5, 0.6, 0.6)
        x = (x * adsr(len(x), 0.12, 0.3, 0.85, 0.6) + grind)
        x = reverb(x, r, decay=2.0, wet=0.3, damp=1800)
        emit_ogg("paul_roar", "bosses/paul_roar_%d" % (i + 1), x, peak_db=-1.5, bus="SFX", volume_db=-1.0)
    for i in range(2):
        r = r_("bottle", i)
        sec = 1.3
        n = N(sec)
        x = np.zeros(n)
        for k in range(10):
            place(x, metal_ring(r, r.uniform(2200, 8000), 0.3, 0.06, (1.0, 1.7, 2.9), 0.45) * r.uniform(0.3, 1.0), r.uniform(0.0, 0.12))
        hiss = hp(white(r, sec), 2500) * np.concatenate([np.zeros(N(0.05)), expenv(n - N(0.05), 0.5)]) * 0.5
        x = x + hiss
        emit_ogg("paul_bottle_break", "bosses/paul_bottle_break_%d" % (i + 1), x, peak_db=-3.0, bus="SFX", volume_db=-4.0)
    r = r_("plate")
    sec = 1.6
    n = N(sec)
    x = A.scrape(r, sec, 400, 2200, 30.0) * adsr(n, 0.2, 0.3, 0.7, 0.5)
    x += metal_ring(r, 160.0, sec, 0.5, (1.0, 2.3, 3.9), 0.5) * 0.5
    x = sat(x, 1.5)
    emit_ogg("paul_plate_grind", "bosses/paul_plate_grind", x, peak_db=-4.0, bus="SFX", volume_db=-5.0)


# ─────────────────────────────────────────────────────────────── THE SLENDER

def gen_slender():
    r = r_("lantern")
    sec = 8.0
    n = N(sec)
    t = tax(n)
    x = (np.sin(2 * np.pi * 110.0 * t) * 0.5 + np.sin(2 * np.pi * 220.4 * t) * 0.3 + np.sin(2 * np.pi * 330.0 * t) * 0.12) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.7 * t))
    x += bp(white(r, sec), 2000, 6000) * 0.08 * smooth_rand(r, sec, 2.0, 0.3, 1.0)
    x = A.loopify(x, 0.5)
    emit_ogg("slender_lantern_hum", "bosses/slender_lantern_hum", x, peak_db=-10.0, loop=True, bus="SFX", volume_db=-10.0)
    r = r_("keys")
    sec = 1.4
    n = N(sec)
    x = np.zeros(n)
    for k in range(9):
        place(x, metal_ring(r, r.uniform(3000, 7500), 0.2, 0.04, (1.0, 2.2, 3.7), 0.5) * r.uniform(0.3, 1.0), r.uniform(0.0, 0.55))
    # ...then nothing: the stop is the tell (a hard gate at 0.6 s)
    x = x * np.concatenate([np.ones(N(0.6)), np.zeros(n - N(0.6))])
    emit_ogg("slender_keys_still", "bosses/slender_keys_still", x, peak_db=-5.0, bus="SFX", volume_db=-6.0)
    for i in range(3):
        r = r_("slwhisper", i)
        sec = 1.8
        n = N(sec)
        x = bp(white(r, sec), 800, 4500)
        env_ = smooth_rand(r, sec, 6.0, 0.0, 1.0) ** 2 * adsr(n, 0.2, 0.3, 0.7, 0.4)
        x = A.formant(x * env_, ["e", "o", "a"][i], shift=1.0)
        x = lp(x, 5000) * 0.8
        emit_ogg("slender_whisper", "bosses/slender_whisper_%d" % (i + 1), x, peak_db=-8.0, bus="SFX", volume_db=-8.0)


# ─────────────────────────────────────────────────────────────── DER KIELHOLER

def gen_kielholer():
    r = r_("chaindrag")
    sec = 6.0
    n = N(sec)
    x = np.zeros(n)
    k = 0
    tpos = 0.0
    while tpos < sec:
        place_at = tpos
        place(x, metal_ring(r, r.uniform(500, 1400), 0.25, 0.05, (1.0, 1.9, 3.4), 0.5) * r.uniform(0.3, 1.0), place_at)
        tpos += r.uniform(0.05, 0.16)
        k += 1
    water = lp(brown(r, sec), 500) * 0.6 + bp(white(r, sec), 400, 2500) * 0.25 * smooth_rand(r, sec, 3.0, 0.2, 1.0)
    x = lp(x, 3500) * 0.7 + water
    x = A.loopify(x, 0.6)
    emit_ogg("kielholer_chain_drag", "bosses/kielholer_chain_drag", x, peak_db=-6.0, loop=True, bus="SFX", volume_db=-6.0)
    for i in range(2):
        r = r_("rise", i)
        sec = 2.6
        n = N(sec)
        t = tax(n)
        surge = lp(brown(r, sec), 300) * np.exp(-((t - 0.6) ** 2) / 0.2) * 1.2
        fall = bp(white(r, sec), 600, 4000) * np.concatenate([np.zeros(N(0.5)), expenv(n - N(0.5), 0.8)]) * 0.5
        brass = metal_ring(r, 240.0, sec, 0.6, (1.0, 2.4, 4.1), 0.5) * np.concatenate([np.zeros(N(0.7)), np.ones(n - N(0.7))]) * 0.25
        x = surge + fall + brass + A.crackle(r, sec, 40, 1.0, 300, 2500) * expenv(n, 1.0) * 0.2
        emit_ogg("kielholer_water_rise", "bosses/kielholer_water_rise_%d" % (i + 1), x, peak_db=-2.0, bus="SFX", volume_db=-3.0)
    r = r_("knock")
    sec = 0.8
    n = N(sec)
    x = np.zeros(n)
    for k in range(2):
        place(x, metal_ring(r, 1900.0, 0.4, 0.07, (1.0, 2.5, 4.4), 0.4) + lp(white(r, 0.4), 3000) * expenv(N(0.4), 0.01), 0.22 * k)
    emit_ogg("kielholer_helmet_knock", "bosses/kielholer_helmet_knock", x, peak_db=-5.0, bus="SFX", volume_db=-6.0)


# ─────────────────────────────────────────────────────────────── THE FOREMAN

def gen_foreman():
    r = r_("drill")
    sec = 4.0
    n = N(sec)
    t = tax(n)
    f = 38.0 + 40.0 * np.minimum(1.0, t / 1.2)
    ph = 2 * np.pi * np.cumsum(f) / SR
    pulses = (np.sin(ph) > 0.7).astype(float)          # the pneumatic hammer
    x = lp(pulses, 900) * 0.8
    x = x * (0.6 + 0.4 * np.minimum(1.0, t / 1.2))
    x += reson(white(r, sec), 2600, 12.0) * 0.35 * np.minimum(1.0, t / 1.0)   # the air whine
    x += lp(brown(r, sec), 200) * 0.3
    x = sat(x, 1.4)
    x = A.loopify(x[N(1.3):], 0.3)
    emit_ogg("foreman_drill_spin", "bosses/foreman_drill_spin", x, peak_db=-4.0, loop=True, bus="SFX", volume_db=-5.0)
    r = r_("chainwhip")
    sec = 1.2
    n = N(sec)
    x = np.zeros(n)
    tpos = 0.0
    while tpos < 0.7:
        place(x, metal_ring(r, r.uniform(700, 1800), 0.2, 0.04, (1.0, 2.0, 3.6), 0.5) * r.uniform(0.3, 1.0), tpos)
        tpos += r.uniform(0.02, 0.07) * (1.0 + tpos)
    x += A.sweep_noise(r, sec, 300, 3500, 3.0) * adsr(n, 0.1, 0.3, 0.3, 0.3) * 0.5
    emit_ogg("foreman_chain_whip", "bosses/foreman_chain_whip", x, peak_db=-3.0, bus="SFX", volume_db=-4.0)


# ─────────────────────────────────────────────────────────────── FERNFLUG

def gen_fernflug():
    for i in range(2):
        r = r_("rail", i)
        sec = 2.2
        n = N(sec)
        x = reson(white(r, sec), 1800 + 400 * i, 30.0) * smooth_rand(r, sec, 4.0, 0.2, 1.0) * adsr(n, 0.2, 0.3, 0.7, 0.6)
        x += reson(white(r, sec), 3900, 40.0) * 0.4 * smooth_rand(r, sec, 7.0, 0.0, 1.0)
        x += lp(brown(r, sec), 150) * 0.5
        x = sat(x, 1.3)
        emit_ogg("kran_rail_screech", "bosses/kran_rail_screech_%d" % (i + 1), x, peak_db=-5.0, bus="SFX", volume_db=-5.0)
    r = r_("casing")
    sec = 2.4
    n = N(sec)
    t = tax(n)
    f = 1800.0 * (0.45 ** (t / 1.4))
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * attack(n, 0.3) * np.concatenate([np.ones(N(1.4)), np.zeros(n - N(1.4))]) * 0.5
    impact = np.zeros(n)
    place(impact, sub_thump(r, 90, 40, 1.0, 0.3) + metal_ring(r, 320, 1.0, 0.5, (1.0, 2.2, 3.9), 0.5) * 0.6, 1.4)
    x = whistle + impact
    emit_ogg("kran_casing_drop", "bosses/kran_casing_drop", x, peak_db=-2.0, bus="SFX", volume_db=-2.0)
    r = r_("cable")
    sec = 1.6
    n = N(sec)
    t = tax(n)
    f = 140.0 * (1.9 ** (t / sec))
    x = fit(A.strings(r, 140.0, sec, 0.2, 0.4, 2600) * 0.6, sec)
    x = x * adsr(n, 0.3, 0.2, 0.9, 0.3) + reson(white(r, sec), 900, 20) * 0.2 * (t / sec)
    emit_ogg("bordwart_cable_sing", "bosses/bordwart_cable_sing", x, peak_db=-5.0, bus="SFX", volume_db=-5.0)
    r = r_("impeller")
    sec = 6.0
    n = N(sec)
    t = tax(n)
    f = 55.0
    x = np.zeros(n)
    for h in range(1, 9):
        x += np.sin(2 * np.pi * f * h * t + r.uniform(0, 6.28)) * (0.6 ** h)
    blades = reson(white(r, sec), 880, 25.0) * 0.3 * (0.7 + 0.3 * np.sin(2 * np.pi * 11.0 * t))
    x = x * 0.6 + blades + lp(brown(r, sec), 120) * 0.3
    x = A.loopify(x, 0.5)
    emit_ogg("bordwart_impeller_loop", "bosses/bordwart_impeller_loop", x, peak_db=-6.0, loop=True, bus="SFX", volume_db=-6.0)
    r = r_("rig")
    sec = 4.0
    n = N(sec)
    t = tax(n)
    f = 420.0
    x = np.sin(2 * np.pi * f * t) * 0.3 + np.sin(2 * np.pi * f * 2.02 * t) * 0.2 + reson(white(r, sec), 3200, 18.0) * 0.4
    x = x * (0.85 + 0.15 * smooth_rand(r, sec, 1.5, 0.0, 1.0))
    x = A.loopify(x, 0.4)
    emit_ogg("pilot_rig_whine", "bosses/pilot_rig_whine", x, peak_db=-7.0, loop=True, bus="SFX", volume_db=-7.0)
    r = r_("misfire")
    sec = 2.2
    n = N(sec)
    t = tax(n)
    f = 420.0 * (0.25 ** np.maximum(0.0, (t - 0.6) / 1.4))
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 * np.concatenate([np.ones(N(0.6)), expenv(n - N(0.6), 0.6)])
    cough = np.zeros(n)
    for k in range(3):
        place(cough, lp(white(r, 0.08), 1500) * expenv(N(0.08), 0.015), 0.15 + 0.14 * k)
    bang = np.zeros(n)
    place(bang, sub_thump(r, 160, 60, 0.8, 0.2) + lp(white(r, 0.8), 3000) * expenv(N(0.8), 0.03), 0.6)
    x = whine + cough * 0.8 + bang
    emit_ogg("pilot_rig_misfire", "bosses/pilot_rig_misfire", x, peak_db=-2.0, bus="SFX", volume_db=-3.0)
    for i in range(2):
        r = r_("servo", i)
        sec = 0.9
        n = N(sec)
        t = tax(n)
        f = (900.0 + 300 * i) * (1.0 + 0.4 * np.sin(np.pi * t / sec))
        x = (square(f) * 0.15 + np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.35) * adsr(n, 0.05, 0.1, 0.8, 0.15)
        x = lp(x, 4000) + reson(white(r, sec), 2200, 10.0) * 0.15
        emit_ogg("manager_servo", "bosses/manager_servo_%d" % (i + 1), x, peak_db=-8.0, bus="SFX", volume_db=-8.0)
    r = r_("stamp")
    sec = 1.0
    n = N(sec)
    x = sub_thump(r, 180, 70, sec, 0.08) + lp(white(r, sec), 1200) * expenv(n, 0.02) * 1.2
    x += metal_ring(r, 520.0, sec, 0.15, (1.0, 2.7), 0.4) * 0.3
    x = reverb(x, r, decay=1.2, wet=0.3, damp=2500)
    emit_ogg("manager_stamp", "bosses/manager_stamp", x, peak_db=-2.0, bus="SFX", volume_db=-2.0)
    r = r_("field")
    sec = 6.0
    n = N(sec)
    t = tax(n)
    x = np.sin(2 * np.pi * 61.7 * t) * 0.4 + np.sin(2 * np.pi * 123.9 * t) * 0.25 + np.sin(2 * np.pi * 3700.0 * t) * 0.03 * (0.5 + 0.5 * np.sin(2 * np.pi * 2.0 * t))
    x += bp(white(r, sec), 5000, 9000) * 0.05 * smooth_rand(r, sec, 3.0, 0.0, 1.0)
    x = A.loopify(x, 0.5)
    emit_ogg("manager_field_hum", "bosses/manager_field_hum", x, peak_db=-9.0, loop=True, bus="SFX", volume_db=-9.0)


def main():
    gen_dread_bed()
    gen_pulse()
    gen_stomps()
    gen_hits()
    gen_telegraph_rise()
    gen_death_toll()
    gen_roars_breaths_bones()
    gen_doll()
    gen_paul()
    gen_slender()
    gen_kielholer()
    gen_foreman()
    gen_fernflug()
    write_manifest()
    total = sum(s for _, s in STATS)
    print(f"gen_audio_bosses: wrote {len(STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
