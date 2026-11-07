#!/usr/bin/env python3
"""GRAVELIGHT UPDATE 11 section 6 (DECISIONS T-192): the horror pass's sounds, synthesized from scratch.

No recordings and no samples: everything here is gen_audio.py's DSP core (oscillators, the formant voice, the
noise-IR reverb, the church-bell partials). License: Owned (our own work). Keys merged into data/gravelight/audio.json.

  horror_chant_bed        a chant-like drone, NOT a recording of any real chant: a low ison (the held drone of
                          Orthodox chant practice) on D2 sung on "o" by four detuned bass voices, a faint second
                          ison a fifth above, a slow breathing swell; then worn down: tape wow, saturation, a 10-bit
                          crush, the highs gone, a long church reverb. 48 s loop (OGG). Ambience bus.
  horror_chant_frag_1..5  short fragments of a modal line (D-E-F-G-A, stepwise, a plagal fall to the final) over the
                          ison, three to four voices on wordless vowels, distorted the same way, far away. OGG.
  horror_bell_far_1..3    a big church bell (hum ~65-80 Hz) heard kilometres off across the snow. OGG.
  horror_whisper_1..6     breathy, wordless, speech-shaped whispers (a fallback for the Returned's close lines when
                          lines.json has no RTN_CLOSE take): shaped noise through moving formants. WAV.
  player_breath_hurt_1..4 the squad's ragged breathing when hurt: a shaky in-breath, a catch, a long out-breath. WAV.
  horror_flies_loop       flies over the dead: a few wing-buzz voices drifting in pitch. Loop WAV.

Run from the repo root:   python gravelight/tools_src/gen_audio_horror.py
then reimport:             godot --headless --editor --quit-after 300 --path .
Needs numpy, scipy and ffmpeg on PATH (the OGG files).
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
SR = A.SR
D2 = 73.42
STATS: list[tuple[str, float]] = []


def worn(x, r, crush_bits: int = 10, wow: float = 0.0035, drive: float = 2.2, cutoff: float = 2600.0):
    """Wear a clean voice down: tape wow and flutter, saturation, a bit crush, the highs gone."""
    n = len(x)
    rate = 1.0 + wow * smooth_rand(r, n / SR, 0.35) + wow * 0.3 * np.sin(2 * np.pi * 6.1 * tax(n))
    y = A.varispeed(x, rate)
    y = fit(y, n / SR)
    y = sat(nrm(y) * drive, 1.0)
    q = 2 ** (crush_bits - 1)
    y = np.round(y * q) / q
    y = lp(y, cutoff, 2)
    y = hp(y, 45, 2)
    return y


def church(x, r, decay: float = 4.5, wet: float = 0.55):
    return reverb(x, r, decay=decay, wet=wet, damp=2400, predelay=0.03, bright=0.12)


def bass_voice(r, sec: float, f, vowel_seq, breath: float = 0.12, drive: float = 1.3):
    pc = A.pitch_curve(r, sec, f, [(0.0, 1.0), (1.0, 1.0)], wobble=0.004, vib_rate=4.6, vib_depth=0.004, jitter=0.004)
    return A.voice(r, sec, pc, vowel_seq, shift=0.82, breath=breath, rasp=0.08, fry=0.06, drive=drive, bw_mult=1.4)


def emit_ogg(key: str, rel: str, x, peak_db: float = -1.0, loop: bool = False, **meta):
    """Writes audio/<rel>.ogg (via a temporary WAV and ffmpeg) and registers it under `key`."""
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
        x = A.fade(x, 0.002, 0.05)
    out = os.path.join(A.GL, "audio", rel + ".ogg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "x.wav")
        A.write_wav(wav, x, False)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    STATS.append((rel, len(x) / SR))


def emit_wav(key: str, rel: str, x, peak_db: float = -1.0, loop: bool = False, **meta):
    emit_ogg(key, rel, x, peak_db, loop, **meta)   # every horror sound ships as OGG (small; AudioDirector loops it)


def write_manifest():
    """Merges this script's keys into data/gravelight/audio.json as text, keeping the file's own formatting (the
    shared gen_audio.write_manifest reflows the whole file): a key already there is replaced, a new one goes at the
    top of "sounds"."""
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
    json.loads(text)   # still valid
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


# ─────────────────────────────────────────────────────────────── the chant bed

def gen_chant_bed():
    r = A.rng_for("horror_chant_bed")
    sec = 48.0
    n = N(sec)
    y = np.zeros(n)
    for v in range(4):
        f = D2 * (1.0 + r.uniform(-0.004, 0.004))
        y += bass_voice(r, sec, f, ["o", "u", "o", "ah", "o"], drive=1.2) * r.uniform(0.7, 1.0)
    fifth = np.zeros(n)
    for v in range(2):
        fifth += bass_voice(r, sec, D2 * 1.5 * (1.0 + r.uniform(-0.003, 0.003)), ["o", "o", "u", "o"], drive=1.1)
    y = nrm(y) + 0.25 * nrm(fifth)
    swell = 0.72 + 0.28 * (0.5 + 0.5 * np.sin(2 * np.pi * tax(n) / (sec / 3.0) - np.pi / 2))   # three slow breaths a loop
    y *= swell
    y = worn(y, r, crush_bits=10, wow=0.004, drive=2.4, cutoff=2200.0)
    y = fit(church(y, r, 5.0, 0.6), sec)
    y = y + 0.04 * lp(pink(r, sec), 400)          # the hiss of an old disc under it
    y = A.loopify(y, 3.0)
    emit_ogg("horror_chant_bed", "sfx/horror/chant_bed", y, -6.0, loop=True, bus="Ambience", volume_db=0.0,
             pitch=[1.0, 1.0], max_voices=1)


# ─────────────────────────────────────────────────────────────── the fragments

MODE = {"D": 1.0, "E": 9 / 8, "F": 6 / 5, "G": 4 / 3, "A": 3 / 2}
PHRASES = [
    [("A", 1.4), ("G", 0.9), ("A", 0.9), ("F", 1.2), ("E", 1.0), ("D", 2.6)],
    [("D", 1.0), ("E", 0.8), ("F", 1.6), ("E", 0.8), ("D", 2.4)],
    [("F", 1.2), ("G", 1.0), ("A", 2.0), ("G", 0.9), ("F", 0.9), ("E", 2.2)],
    [("A", 2.2), ("A", 0.8), ("G", 1.0), ("F", 1.0), ("G", 0.8), ("E", 1.2), ("D", 2.8)],
    [("E", 1.0), ("F", 1.0), ("E", 1.0), ("D", 3.2)],
]
SYL = [["ah", "o"], ["o", "e"], ["i", "ah"], ["o", "u"], ["e", "o"], ["ah", "ah"]]


def melody_curve(phrase, base):
    """[(time_frac, mult)] for pitch_curve: a short glide into each note."""
    total = sum(d for _, d in phrase)
    pts = []
    t = 0.0
    for note, d in phrase:
        m = MODE[note]
        pts.append((t / total, m))
        pts.append(((t + d * 0.85) / total, m))
        t += d
    return pts, total


def gen_fragments():
    for i in range(1, 6):
        r = A.rng_for("horror_chant_frag_%d" % i)
        phrase = PHRASES[(i - 1) % len(PHRASES)]
        base = D2 * 2.0                              # the line an octave over the ison
        contour, total = melody_curve(phrase, base)
        sec = total + 2.5
        n = N(sec)
        line = np.zeros(n)
        voices = 3 + (i % 2)
        for v in range(voices):
            pc = A.pitch_curve(r, sec, base * (1.0 + r.uniform(-0.006, 0.006)), contour + [(1.0, contour[-1][1])],
                               wobble=0.006, vib_rate=r.uniform(4.2, 5.4), vib_depth=0.006, jitter=0.006)
            vow = SYL[(i + v) % len(SYL)] * 3
            line += A.voice(r, sec, pc, vow, shift=0.9, breath=0.18, rasp=0.06, drive=1.3, bw_mult=1.3) * r.uniform(0.6, 1.0)
        ison = bass_voice(r, sec, D2, ["o", "o"], drive=1.1)
        y = nrm(line) + 0.45 * nrm(ison)
        env = np.clip(tax(n) / 0.9, 0, 1) * np.clip((sec - tax(n)) / 1.8, 0, 1)
        y *= env
        y = worn(y, r, crush_bits=9, wow=0.006, drive=2.6, cutoff=1900.0)
        y = church(y, r, 5.5, 0.65)
        y = echo(y, r.uniform(0.9, 1.3), 0.18, 900, 2)
        emit_ogg("horror_chant_frag", "sfx/horror/chant_frag_%02d" % i, y, -3.0, bus="Ambience", volume_db=0.0,
                 pitch=[0.98, 1.02], max_voices=1)


# ─────────────────────────────────────────────────────────────── far bells

def distant(x, r, cutoff=900.0, decay=3.2, wet=0.6):
    y = lp(x, cutoff, 2)
    y = reverb(y, r, decay=decay, wet=wet, damp=1600, predelay=0.05, bright=0.05)
    return echo(y, r.uniform(0.7, 1.2), 0.2, 600, 2)


def gen_bells():
    for i, f in enumerate([138.6, 155.6, 130.8], start=1):
        r = A.rng_for("horror_bell_far_%d" % i)
        sec = 11.0
        b = A.bell(r, f, sec - 1.0, decay=4.2, strike=0.3, bright=0.6)
        if i == 2:
            b2 = A.bell(r, f, sec - 4.5, decay=4.0, strike=0.3, bright=0.6)
            b = np.concatenate([b, np.zeros(N(1.0))])
            place(b, b2, 3.4, 0.8)                    # two strokes, the second fainter
        y = fit(distant(b, r, 1100, 3.6, 0.65), sec)
        emit_ogg("horror_bell_far", "sfx/horror/bell_far_%02d" % i, y, -3.0, bus="SFX", volume_db=0.0,
                 pitch=[0.98, 1.02], max_voices=2, attenuation="loud")


# ─────────────────────────────────────────────────────────────── whispers, breath, flies

def whisper(r, sec: float):
    n = N(sec)
    nz = white(r, sec)
    # speech-shaped: syllable bursts (3-6 a second) with consonant hiss at the onsets
    rate = r.uniform(3.2, 5.2)
    syl = np.clip(np.sin(2 * np.pi * rate * tax(n) + r.uniform(0, 6.28)) * 0.5 + 0.5 + 0.35 * smooth_rand(r, sec, 2.0), 0, 1) ** 1.6
    voiced = np.zeros(n)
    vowels = ["ah", "o", "e", "i", "u"]
    seq = [vowels[r.integers(0, len(vowels))] for _ in range(int(sec * rate) + 2)]
    morph = np.linspace(0.0, 1.0, n)
    morph_m = np.clip(morph * (len(seq) - 1), 0, len(seq) - 1)
    for k, v in enumerate(seq):
        w = np.clip(1.0 - np.abs(morph_m - k), 0.0, 1.0)
        if np.max(w) <= 0:
            continue
        voiced += A.formant(hp(nz, 300), v, 1.1, 1.8) * w
    hiss = bp(nz, 3500, 8000) * (np.abs(np.diff(syl, prepend=0)) * 40).clip(0, 1)
    y = nrm(voiced) * syl + 0.35 * hiss
    y *= np.clip(tax(n) / 0.12, 0, 1) * np.clip((sec - tax(n)) / 0.3, 0, 1)
    return reverb(lp(y, 6500), r, 0.6, 0.15, 5000)


def gen_whispers():
    for i in range(1, 7):
        r = A.rng_for("horror_whisper_%d" % i)
        y = whisper(r, r.uniform(1.4, 2.4))
        emit_wav("horror_whisper", "sfx/horror/whisper_%02d" % i, y, -6.0, bus="SFX", volume_db=-6.0,
                 pitch=[0.9, 1.05], max_voices=2, attenuation="quiet")


def breath(r, sec: float):
    n = N(sec)
    nz = white(r, sec)
    t = tax(n)
    # in (0.5-0.7 s, shaky), a catch, out (1.0-1.4 s), a pause
    tin = r.uniform(0.45, 0.7)
    tcatch = tin + r.uniform(0.08, 0.16)
    tout = tcatch + r.uniform(0.9, 1.3)
    shake = 1.0 + 0.35 * np.sin(2 * np.pi * r.uniform(9, 14) * t) * (t < tin)
    e = np.where(t < tin, (t / tin) ** 0.7 * shake, 0.0)
    e += np.where((t >= tcatch) & (t < tout), np.clip(np.sin(np.pi * (t - tcatch) / (tout - tcatch)), 0.0, 1.0) ** 0.8 * 0.85, 0.0)
    inh = A.formant(bp(nz, 500, 5000), "ah", 1.15, 2.2) * (t < tcatch)
    exh = A.formant(bp(nz, 300, 3500), "o", 1.0, 2.0) * (t >= tcatch)
    voiced = A.voice(r, sec, 110.0, ["ah", "o"], shift=1.0, breath=0.6, rasp=0.5, drive=1.2) * 0.12
    y = (nrm(inh) * 0.8 + nrm(exh) + voiced * (t >= tcatch)) * e
    return reverb(lp(y, 6000), r, 0.35, 0.08, 6000)


def gen_breath():
    for i in range(1, 5):
        r = A.rng_for("player_breath_hurt_%d" % i)
        y = breath(r, r.uniform(2.2, 2.8))
        emit_wav("player_breath_hurt", "sfx/player/breath_hurt_%02d" % i, y, -4.0, bus="SFX", volume_db=-9.0,
                 pitch=[0.95, 1.05], max_voices=1)


def gen_flies():
    r = A.rng_for("horror_flies_loop")
    sec = 6.0
    n = N(sec)
    y = np.zeros(n)
    for v in range(5):
        f = r.uniform(170, 240) * (1.0 + 0.08 * smooth_rand(r, sec, r.uniform(0.6, 1.8)))
        buzz = A.saw(f, sec, r.uniform())
        amp = (0.4 + 0.6 * np.clip(smooth_rand(r, sec, r.uniform(0.4, 1.2), 0.0, 1.0), 0, 1)) ** 2
        y += bp(buzz, 180, 2400) * amp
    y = A.loopify(reverb(y, r, 0.5, 0.15, 4000), 0.6)
    emit_wav("horror_flies_loop", "sfx/horror/flies_loop", y, -8.0, loop=True, bus="SFX", volume_db=-8.0,
             pitch=[1.0, 1.0], max_voices=4, attenuation="quiet")


def main():
    only = [a for a in _argv[0].split(",") if a] if _argv else []
    for name, fn in [("chant_bed", gen_chant_bed), ("frag", gen_fragments), ("bell", gen_bells), ("whisper", gen_whispers),
                     ("breath", gen_breath), ("flies", gen_flies)]:
        if only and name not in only:
            continue
        fn()
        print("gen_audio_horror: %s done" % name)
    write_manifest()
    total = sum(d for _, d in STATS)
    print(f"gen_audio_horror: wrote {len(STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
