#!/usr/bin/env python3
"""GRAVELIGHT voice bake: every VO line in data/gravelight/vo/lines.json becomes an audio file.

Pipeline per line (per part for banter / tag exchanges):
  1. the subtitle text is cleaned for speech: [stage directions] become effect cues (static, whisper, distant...),
     (parentheticals) and *markers* are dropped, {splice} words become the Operator's pitch-jumped fragments
  2. Windows' offline OneCore voices (Microsoft David / Mark / Zira) synthesize it to WAV through
     gen_vo_tts.ps1 with per-speaker SSML prosody (rate, pitch). File output only, never the speakers.
  3. numpy/scipy post-processing gives each of the eight speakers a distinct timbre: a phase-vocoder
     "size" shift (pitch and formants together), EQ, and the channel the script asks for: the Operator's
     1940s tannoy (band-pass, brass saturation, hall, tape hiss, crackle, flutter) with a cleaner "corporate"
     timbre for the op.slip.* lines, Fasbender's hand-over-the-mic radio with static, Reinholt's PA hijacks or
     wax-cylinder phonograph, Liesl's child pitch on the phonograph, and the squad dry with per-character EQ
  4. ffmpeg encodes to Ogg Vorbis, mono, ~64 kbps, at res://gravelight/audio/vo/<speaker>/<id>.ogg; if the
     encode fails the processed WAV is written there instead (VOManager accepts either)

Deterministic (every effect draws from an RNG seeded by the file id) and incremental: a file is only rebuilt
when the hash of its text, voice profile and tool version changes (data/gravelight/vo/audio_manifest.json).

Run from the repo root:
  python gravelight/tools_src/gen_vo.py                 everything (new / changed lines only)
  python gravelight/tools_src/gen_vo.py --only=OPR      one speaker, or an id prefix (--only=BNT_DUT)
  python gravelight/tools_src/gen_vo.py --force         rebuild regardless of the manifest
  python gravelight/tools_src/gen_vo.py --dry-run       list what would be built
Then reimport once so Godot sees the new files:  godot --headless --editor --quit-after 300 --path .
Requires numpy + scipy and ffmpeg on PATH. Windows only (OneCore voices).
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zlib
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from scipy import signal
from scipy.io import wavfile

TOOL_VERSION = "1"            # bump to rebuild everything (the hash includes it)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LINES = os.path.join(ROOT, "data", "gravelight", "vo", "lines.json")
MANIFEST = os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json")
OUT_DIR = os.path.join(ROOT, "gravelight", "audio", "vo")
RES_PREFIX = "res://gravelight/audio/vo/"
PS1 = os.path.join(HERE, "gen_vo_tts.ps1")
SR = 24000                    # processing / output rate (the voices come out at 16 kHz)
SEED = 19390901

# ───────────────────────────────────────────────────────────── voice profiles
# voice: OneCore voice (display-name substring). rate/pitch: SSML prosody. size: phase-vocoder pitch+formant
# factor (>1 smaller / younger, <1 bigger / older). chain: the post-processing channel. gain_db: trim.
PROFILES: dict[str, dict] = {
    # The Operator: a sampled 1930s announcer on the mine's tannoy. Bright, brassy, a little too quick.
    "OPR":      dict(voice="Mark",  rate="+8%",  pitch="+6%",  size=1.00, chain="tannoy",    gain_db=0.0),
    # op.slip.*: the Ledger's corporate voice leaking through: cleaner, slower, closer.
    "OPR_SLIP": dict(voice="Mark",  rate="-6%",  pitch="-5%",  size=0.98, chain="corporate", gain_db=-1.0),
    # Dr. Emil Fasbender, mid-40s, nervous and rapid, always with his hand over the mic. Radio.
    "FAS":      dict(voice="David", rate="+6%",  pitch="-2%",  size=0.97, chain="radio",     gain_db=0.0),
    # Dr. Augusta Reinholt, early 50s, cultured, controlled, slow. Cylinders (warm) or PA hijacks (cold).
    "REI":      dict(voice="Zira",  rate="-10%", pitch="-12%", size=0.94, chain="pa",        gain_db=0.0),
    # Liesl, seven, on her mother's wax cylinders.
    "LSL":      dict(voice="Zira",  rate="+4%",  pitch="+28%", size=1.22, chain="phono",     gain_db=-1.0),
    # Sgt. Dutch Kowalczyk: low, gravelly, unhurried.
    "DUT":      dict(voice="David", rate="-8%",  pitch="-14%", size=0.93, chain="dutch",     gain_db=0.0),
    # Lt. Peg Ashworth: clipped, precise, never raises her voice.
    "PEG":      dict(voice="Zira",  rate="-2%",  pitch="-4%",  size=1.00, chain="peg",       gain_db=0.0),
    # Cpl. Deacon Brooks: warm tenor, soft-spoken, a preacher's rhythm.
    "DEA":      dict(voice="Mark",  rate="-7%",  pitch="-7%",  size=0.97, chain="deacon",    gain_db=0.0),
    # Wren Nowak: economical, accented, never a wasted word.
    "WRN":      dict(voice="Zira",  rate="-4%",  pitch="+6%",  size=1.07, chain="wren",      gain_db=0.0),
    # Jakub Ostrowski (U02 section 6.2): a Polish miner in his forties. Mark, slower and lower than Deacon, a slightly
    # larger "size" (older, chestier), dry and close with a little grit: calm, wry, unhurried.
    "JAK":      dict(voice="Mark",  rate="-13%", pitch="-11%", size=0.95, chain="jakub",     gain_db=0.0),
}
# Reinholt's cylinders and diary samples are phonograph recordings; everything else of hers is the PA.
REI_PHONO_CATEGORIES = ("CYL", "SAMPLE", "HEART_END", "END")

ONLY: str = ""
FORCE: bool = False
DRY: bool = False
for a in sys.argv[1:]:
    if a.startswith("--only="):
        ONLY = a[len("--only="):]
    elif a == "--force":
        FORCE = True
    elif a == "--dry-run":
        DRY = True
    elif a in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)


# ───────────────────────────────────────────────────────────── text → speech text + cues

CUE_WORDS = {
    "static": "static", "crackle": "crackle", "whisper": "whisper", "distant": "distant", "far away": "distant",
    "faint": "distant", "slowed": "slowed", "cheerful": "cheerful", "radio": "radio", "telephone": "radio",
    "phone": "radio", "quiet": "quiet", "soft": "quiet", "tired": "quiet", "shout": "loud", "loud": "loud",
    "sing": "sing", "giggle": "", "cough": "", "child": "", "close to the horn": "close",
}


def xml_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def speech_parts(text: str) -> tuple[list[tuple[str, str]], set[str]]:
    """Returns [(kind, text)] with kind in {"say", "splice", "emph"} and the set of effect cues.
    Direction tags [like this] become cues; (parentheticals) and musical notes are dropped."""
    cues: set[str] = set()
    for m in re.finditer(r"\[([^\]]*)\]", text):
        tag = m.group(1).lower()
        for word, cue in CUE_WORDS.items():
            if word in tag and cue:
                cues.add(cue)
    t = re.sub(r"\[[^\]]*\]", " ", text)
    t = re.sub(r"\([^)]*\)", " ", t)          # stage notes and subtitle glosses
    t = t.replace("♪", " ")
    t = t.replace("—", ", ").replace("–", ", ")
    t = re.sub(r"\s+", " ", t).strip()
    parts: list[tuple[str, str]] = []
    for m in re.finditer(r"\{([^}]*)\}|\*([^*]+)\*|([^{}*]+)", t):
        if m.group(1) is not None:
            parts.append(("splice", m.group(1).strip()))
        elif m.group(2) is not None:
            parts.append(("emph", m.group(2).strip()))
        else:
            parts.append(("say", m.group(3)))
    parts = [(k, s) for k, s in parts if s.strip()]
    return parts, cues


def plain_text(parts: list[tuple[str, str]]) -> str:
    return re.sub(r"\s+", " ", " ".join(s for _, s in parts)).strip()


def build_ssml(parts: list[tuple[str, str]], prof: dict, cues: set[str], splice: bool) -> str:
    rate = prof["rate"]
    pitch = prof["pitch"]
    vol = ""
    if "whisper" in cues:
        vol = ' volume="x-soft"'
    elif "quiet" in cues or "distant" in cues:
        vol = ' volume="soft"'
    elif "loud" in cues:
        vol = ' volume="loud"'
    if "cheerful" in cues:
        pitch = _bump(pitch, 4)
    if "slowed" in cues:
        rate = _bump(rate, -18)
    body = ""
    for kind, s in parts:
        esc = xml_escape(s)
        if kind == "splice" and splice:
            # The Ledger splicing: a hair of air, then the fragment at a different pitch and pace.
            body += '<break time="70ms"/><prosody pitch="%s" rate="%s">%s</prosody><break time="40ms"/>' % (
                _bump(pitch, 18), _bump(rate, -12), esc)
        elif kind == "emph":
            body += "<emphasis level=\"strong\">%s</emphasis>" % esc
        else:
            body += esc
    return ('<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
            '<prosody rate="%s" pitch="%s"%s>%s</prosody></speak>' % (rate, pitch, vol, body))


def _bump(pct: str, delta: int) -> str:
    v = int(pct.replace("%", "").replace("+", "")) + delta
    return "%+d%%" % v


# ───────────────────────────────────────────────────────────── DSP

def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng((zlib.crc32(name.encode()) << 16) ^ SEED)


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def butter(x: np.ndarray, kind: str, freq, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, freq, btype=kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    return butter(x, "bandpass", [lo, hi], order)


def lowpass(x, f, order=2):
    return butter(x, "lowpass", f, order)


def highpass(x, f, order=2):
    return butter(x, "highpass", f, order)


def boost(x, lo, hi, gain_db, order=2):
    """Simple band boost / cut: add (or subtract) a band-passed copy."""
    g = db(gain_db) - 1.0
    return x + g * bandpass(x, lo, hi, order)


def saturate(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def envelope(x, ms=20.0):
    n = max(1, int(SR * ms / 1000.0))
    k = np.ones(n) / n
    return np.sqrt(np.convolve(x * x, k, mode="same") + 1e-12)


def reverb(x, seconds, r, mix, predelay_ms=12.0, damp_hz=4000.0):
    n = int(SR * seconds)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / (SR * seconds / 4.5))
    ir = lowpass(ir, damp_hz)
    ir[: int(SR * 0.004)] = 0.0
    ir /= np.sqrt(np.sum(ir * ir)) + 1e-9
    ir *= 0.35
    wet = signal.fftconvolve(x, ir)[: len(x) + n]
    pre = int(SR * predelay_ms / 1000.0)
    out = np.zeros(len(x) + n + pre)
    out[: len(x)] += x
    out[pre: pre + len(wet)] += wet * mix
    return out


def pink(n, r):
    X = np.fft.rfft(r.standard_normal(n))
    f = np.arange(len(X), dtype=float)
    f[0] = 1.0
    X /= np.sqrt(f)
    y = np.fft.irfft(X, n)
    return y / (np.max(np.abs(y)) + 1e-12)


def hiss(x, r, level_db, hp=1500.0, kind="pink"):
    n = len(x)
    bed = pink(n, r) if kind == "pink" else r.uniform(-1, 1, n)
    bed = highpass(bed, hp)
    bed /= np.max(np.abs(bed)) + 1e-9
    return x + bed * db(level_db)


def crackle(x, r, per_second, level_db, lp=6000.0):
    n = len(x)
    out = np.zeros(n)
    count = int(per_second * n / SR)
    for i in r.integers(0, n, size=max(0, count)):
        w = int(r.integers(8, 40))
        seg = r.standard_normal(w) * np.exp(-np.arange(w) / (w / 3.0))
        out[i: i + w] += seg[: n - i]
    out = lowpass(out, lp)
    return x + out * db(level_db)


def flutter(x, r, hz, depth):
    t = np.arange(len(x)) / SR
    return x * (1.0 - depth + depth * 0.5 * (1.0 + np.sin(2 * np.pi * hz * t + r.uniform(0, 6.28))))


def wow(x, r, hz, depth):
    """Slow pitch wobble (wax cylinder off-centre): a modulated fractional delay."""
    n = len(x)
    t = np.arange(n)
    d = depth * SR / (2 * np.pi * hz) * np.sin(2 * np.pi * hz * t / SR + r.uniform(0, 6.28))
    src = np.clip(t - d, 0, n - 1)
    return np.interp(src, t, x)


def hum(x, hz, level_db):
    t = np.arange(len(x)) / SR
    return x + (np.sin(2 * np.pi * hz * t) + 0.4 * np.sin(2 * np.pi * 2 * hz * t)) * db(level_db)


def static_burst(x, r, at_start=True, at_end=True, ms=140.0, level_db=-16.0):
    n = int(SR * ms / 1000.0)
    out = x.copy()
    for start in ([0] if at_start else []) + ([len(x) - n] if at_end else []):
        burst = bandpass(r.uniform(-1, 1, n), 900, 3500)
        env = np.hanning(n)
        seg = burst * env * db(level_db)
        out[start: start + n] += seg[: len(out) - start]
    return out


def click(x, r, level_db=-20.0):
    n = int(SR * 0.006)
    c = lowpass(r.standard_normal(n) * np.exp(-np.arange(n) / (n / 3.0)), 5000)
    out = np.concatenate([np.zeros(int(SR * 0.03)), x])
    out[:n] += c * db(level_db)
    return out


def breath(x, r, level_db):
    env = envelope(x, 30.0)
    noise = highpass(r.standard_normal(len(x)), 1200)
    return x + noise * env * db(level_db) * 4.0


def compress(x, thresh_db=-18.0, ratio=3.0, ms=25.0):
    env = envelope(x, ms)
    env_db = 20 * np.log10(env + 1e-9)
    over = np.maximum(0.0, env_db - thresh_db)
    gain = db(-over * (1.0 - 1.0 / ratio))
    return x * gain


def stretch(x, factor, n_fft=1024, hop=256):
    """Phase-vocoder time stretch (factor > 1 is longer)."""
    if abs(factor - 1.0) < 1e-3 or len(x) < n_fft * 2:
        return x.copy()
    _, _, Z = signal.stft(x, fs=SR, nperseg=n_fft, noverlap=n_fft - hop, padded=True)
    n_frames = Z.shape[1]
    out_frames = max(2, int(n_frames * factor))
    adv = 2 * np.pi * hop * np.arange(Z.shape[0]) / n_fft
    mag = np.abs(Z)
    ph = np.angle(Z)
    out = np.zeros((Z.shape[0], out_frames), dtype=complex)
    acc = ph[:, 0].copy()
    for i in range(out_frames):
        pos = i / factor
        k = min(int(pos), n_frames - 2)
        frac = pos - k
        m = mag[:, k] * (1 - frac) + mag[:, k + 1] * frac
        dphi = ph[:, k + 1] - ph[:, k] - adv
        dphi -= 2 * np.pi * np.round(dphi / (2 * np.pi))
        acc = acc + adv + dphi
        out[:, i] = m * np.exp(1j * acc)
    _, y = signal.istft(out, fs=SR, nperseg=n_fft, noverlap=n_fft - hop)
    return y


def shift_size(x, factor):
    """Pitch and formants together by `factor`, same duration: stretch by factor, then play back faster."""
    if abs(factor - 1.0) < 1e-3:
        return x
    y = stretch(x, factor)
    up, down = 1000, int(round(1000 * factor))
    y = signal.resample_poly(y, up, down)
    return y


def trim(x, thresh_db=-48.0, pad_ms=50.0):
    env = envelope(x, 10.0)
    idx = np.where(env > db(thresh_db))[0]
    if len(idx) == 0:
        return x
    pad = int(SR * pad_ms / 1000.0)
    a = max(0, idx[0] - pad)
    b = min(len(x), idx[-1] + pad)
    return x[a:b]


def fade(x, ms=12.0):
    n = min(len(x) // 2, int(SR * ms / 1000.0))
    if n > 0:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def normalize(x, rms_db=-19.0, peak_db=-1.5):
    env = envelope(x, 50.0)
    active = x[env > db(-40.0)]
    rms = np.sqrt(np.mean(active * active)) if len(active) > 0 else np.sqrt(np.mean(x * x) + 1e-12)
    x = x * (db(rms_db) / (rms + 1e-9))
    x = np.tanh(x * 1.1) / np.tanh(1.1)
    peak = np.max(np.abs(x)) + 1e-9
    if peak > db(peak_db):
        x = x * db(peak_db) / peak
    return x


# ───────────────────────────────────────────────────────────── channels

def chain_tannoy(x, r, cues):
    x = bandpass(x, 320, 3600, 3)
    x = saturate(x, 2.4)
    x = boost(x, 1800, 3200, 3.0)
    x = bandpass(x, 260, 4300, 1)
    x = compress(x, -16.0, 3.5)
    x = reverb(x, 0.7, r, 0.30, 18.0, 3500.0)
    x = flutter(x, r, 0.9, 0.05)
    x = hiss(x, r, -36.0 if "static" not in cues else -24.0, 1200.0)
    x = crackle(x, r, 5.0 if "crackle" not in cues else 16.0, -26.0)
    x = hum(x, 50.0, -46.0)
    x = click(x, r, -22.0)
    return x


def chain_corporate(x, r, cues):
    x = bandpass(x, 140, 7500, 2)
    x = compress(x, -20.0, 4.0, 15.0)
    x = boost(x, 2500, 5000, 2.0)
    x = reverb(x, 0.22, r, 0.12, 6.0, 6000.0)
    x = hiss(x, r, -48.0, 3000.0)
    return x


def chain_radio(x, r, cues):
    x = bandpass(x, 420, 3000, 4)
    x = saturate(x, 1.8)
    x = lowpass(x, 2700, 2)        # the hand over the mic
    x = compress(x, -18.0, 3.0)
    x = hiss(x, r, -30.0, 900.0, "white")
    x = crackle(x, r, 3.0, -28.0, 3000.0)
    x = hum(x, 50.0, -44.0)
    x = flutter(x, r, 3.0, 0.08)
    x = static_burst(x, r, True, True, 160.0, -14.0 if "static" in cues else -20.0)
    return x


def chain_pa(x, r, cues):
    x = bandpass(x, 240, 5000, 2)
    x = saturate(x, 1.4)
    x = compress(x, -18.0, 3.0)
    x = reverb(x, 1.4, r, 0.42, 25.0, 3200.0)
    x = hum(x, 50.0, -42.0)
    x = hiss(x, r, -40.0, 2000.0)
    return x


def chain_phono(x, r, cues):
    x = bandpass(x, 300, 4300, 2)
    x = saturate(x, 1.3)
    x = wow(x, r, 0.55, 0.0045)
    x = wow(x, r, 6.5, 0.0008)
    x = lowpass(x, 4200, 2)
    x = compress(x, -18.0, 2.5)
    x = reverb(x, 0.25, r, 0.10, 8.0, 3000.0)
    x = hiss(x, r, -28.0, 1800.0, "white")
    x = crackle(x, r, 11.0, -22.0, 4500.0)
    x = flutter(x, r, 1.3, 0.04)
    return x


def chain_dutch(x, r, cues):
    x = highpass(x, 70, 1)
    x = boost(x, 90, 260, 3.5)
    x = saturate(x, 1.6)
    x = lowpass(x, 7000, 1)
    x = boost(x, 1500, 2500, -1.0)
    return x


def chain_peg(x, r, cues):
    x = highpass(x, 150, 2)
    x = boost(x, 2200, 4200, 3.0)
    x = compress(x, -20.0, 2.0)
    return x


def chain_deacon(x, r, cues):
    x = highpass(x, 90, 1)
    x = boost(x, 200, 600, 2.5)
    x = boost(x, 3000, 5000, -1.5)
    x = reverb(x, 0.18, r, 0.06, 5.0, 5000.0)
    return x


def chain_wren(x, r, cues):
    x = highpass(x, 170, 2)
    x = boost(x, 800, 1500, -2.0)
    x = boost(x, 3200, 5200, 2.0)
    return x


def chain_jakub(x, r, cues):
    x = highpass(x, 85, 1)
    x = boost(x, 350, 800, 2.5)       # chest
    x = boost(x, 2600, 4200, -2.0)    # no shine: tired, older
    x = saturate(x, 1.35)             # a little grit
    x = lowpass(x, 6200, 1)
    x = compress(x, -22.0, 2.2)
    return x


CHAINS = {"jakub": chain_jakub, "tannoy": chain_tannoy, "corporate": chain_corporate, "radio": chain_radio, "pa": chain_pa,
          "phono": chain_phono, "dutch": chain_dutch, "peg": chain_peg, "deacon": chain_deacon, "wren": chain_wren}


def apply_cues(x, r, cues, chain):
    if "whisper" in cues:
        x = highpass(x, 500, 2)
        x = breath(x, r, -26.0)
        x = x * db(-4.0)
    if "distant" in cues:
        x = lowpass(x, 2400, 2)
        x = reverb(x, 1.0, r, 0.5, 20.0, 2500.0)
        x = x * db(-5.0)
    if "slowed" in cues:
        x = shift_size(x, 0.88)
    if "radio" in cues and chain not in ("radio", "tannoy"):
        x = chain_radio(x, r, cues)
    if "static" in cues and chain == "tannoy":
        x = static_burst(x, r, True, True, 220.0, -12.0)
    return x


def process(wav_path: str, prof: dict, cues: set[str], file_id: str) -> np.ndarray:
    sr_in, data = wavfile.read(wav_path)
    if data.ndim > 1:
        data = data[:, 0]
    x = data.astype(np.float64) / 32768.0
    if sr_in != SR:
        from math import gcd
        g = gcd(SR, sr_in)
        x = signal.resample_poly(x, SR // g, sr_in // g)
    r = rng_for(file_id)
    x = trim(x)
    x = shift_size(x, float(prof["size"]))
    x = CHAINS[prof["chain"]](x, r, cues)
    x = apply_cues(x, r, cues, prof["chain"])
    x = normalize(x)
    x = x * db(float(prof.get("gain_db", 0.0)))
    return fade(x)


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


# ───────────────────────────────────────────────────────────── jobs

def profile_for(speaker: str, line_id: str, category: str) -> dict | None:
    if speaker == "OPR" and line_id.startswith("op.slip"):
        return PROFILES["OPR_SLIP"]
    prof = PROFILES.get(speaker)
    if prof is None:
        return None
    if speaker == "REI" and any(category.startswith(c) for c in REI_PHONO_CATEGORIES):
        prof = dict(prof, chain="phono")
    return prof


def part_hash(text: str, prof: dict, cues: set[str], splice: bool) -> str:
    key = "|".join([TOOL_VERSION, prof["voice"], prof["rate"], prof["pitch"], str(prof["size"]), prof["chain"],
                    str(prof.get("gain_db", 0.0)), ",".join(sorted(cues)), str(splice), text])
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:16]


def res_path(speaker: str, file_id: str, ext: str) -> str:
    return "%s%s/%s.%s" % (RES_PREFIX, speaker.lower(), file_id, ext)


def disk_path(speaker: str, file_id: str, ext: str) -> str:
    return os.path.join(OUT_DIR, speaker.lower(), "%s.%s" % (file_id, ext))


def encode(tmp_wav: str, speaker: str, file_id: str) -> tuple[str, str]:
    """ffmpeg → ogg; falls back to the WAV. Returns (res path, format)."""
    ogg = disk_path(speaker, file_id, "ogg")
    wav = disk_path(speaker, file_id, "wav")
    os.makedirs(os.path.dirname(ogg), exist_ok=True)
    ff = shutil.which("ffmpeg")
    if ff:
        try:
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", tmp_wav, "-c:a", "libvorbis", "-b:a", "64k",
                            "-ac", "1", ogg], check=True, capture_output=True, timeout=120)
            if os.path.exists(wav):
                os.remove(wav)
                for f in (wav + ".import",):
                    if os.path.exists(f):
                        os.remove(f)
            return res_path(speaker, file_id, "ogg"), "ogg"
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    shutil.copyfile(tmp_wav, wav)
    if os.path.exists(ogg):
        os.remove(ogg)
    return res_path(speaker, file_id, "wav"), "wav"


def main() -> int:
    with open(LINES, encoding="utf-8") as f:
        lines: dict = json.load(f)
    manifest: dict = {"_doc": "", "tool_version": TOOL_VERSION, "files": {}, "missing": {}}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            old = json.load(f)
        manifest["files"] = old.get("files", {})
        manifest["missing"] = old.get("missing", {})
    files: dict = manifest["files"]
    missing: dict = manifest["missing"]

    # Every (file id) this lines.json wants.
    wanted: dict[str, dict] = {}
    for line_id, rec in sorted(lines.items()):
        speaker = str(rec.get("speaker", ""))
        category = str(rec.get("category", ""))
        if ONLY and not (line_id.startswith(ONLY) or speaker == ONLY or speaker.lower() == ONLY.lower()):
            continue
        parts_src: list[tuple[str, str]] = []
        if rec.get("exchange"):
            parts_src = [(str(p[0]), str(p[1])) for p in rec["exchange"]]
        else:
            # "tts": a phonetic respelling for the English voices (Jakub's Polish); the subtitle keeps "text"
            parts_src = [(speaker, str(rec.get("tts") or rec.get("text", "")))]
        multi = len(parts_src) > 1 or bool(rec.get("exchange"))
        for i, (spk, text) in enumerate(parts_src):
            file_id = "%s_p%d" % (line_id, i) if multi else line_id
            prof = profile_for(spk, line_id, category)
            if prof is None:
                missing[file_id] = "no voice profile for speaker %s" % spk
                continue
            parts, cues = speech_parts(text)
            say = plain_text(parts)
            if not re.search(r"[A-Za-z0-9]", say):
                missing[file_id] = "no speech: stage direction only (%s)" % text[:40]
                continue
            splice = spk == "OPR"
            wanted[file_id] = dict(line=line_id, speaker=spk, text=say, hash=part_hash(say, prof, cues, splice),
                                   ssml=build_ssml(parts, prof, cues, splice), voice=prof["voice"], prof=prof,
                                   cues=cues)
            missing.pop(file_id, None)

    # Drop manifest rows (and files) for lines that no longer exist (files only when not filtering).
    all_ids: set[str] = set()
    for line_id, rec in lines.items():
        if rec.get("exchange"):
            all_ids.update("%s_p%d" % (line_id, i) for i in range(len(rec["exchange"])))
        else:
            all_ids.add(line_id)
    for fid in list(missing.keys()):
        if fid not in all_ids:
            missing.pop(fid)
    if not ONLY:
        for fid in list(files.keys()):
            if fid not in all_ids:
                p = files[fid].get("path", "")
                if p.startswith(RES_PREFIX):
                    for ext in ("ogg", "wav"):
                        dp = disk_path(files[fid]["speaker"], fid, ext)
                        for fpath in (dp, dp + ".import"):
                            if os.path.exists(fpath):
                                os.remove(fpath)
                files.pop(fid)

    todo = []
    for fid, job in wanted.items():
        cur = files.get(fid)
        on_disk = cur is not None and os.path.exists(os.path.join(ROOT, cur["path"][len("res://"):].replace("/", os.sep)))
        if not FORCE and cur is not None and cur.get("hash") == job["hash"] and on_disk:
            continue
        todo.append(fid)
    print("lines %d, files wanted %d, to build %d, skipped (up to date) %d, no speech %d" % (
        len(lines), len(wanted), len(todo), len(wanted) - len(todo), len(missing)))
    if DRY:
        for fid in todo:
            print("  ", fid, "->", wanted[fid]["text"][:70])
        return 0
    if not todo:
        _write_manifest(manifest)
        return 0

    tmp = tempfile.mkdtemp(prefix="glvo_")
    jobs = [{"id": fid, "voice": wanted[fid]["voice"], "ssml": wanted[fid]["ssml"],
             "wav": os.path.join(tmp, fid + ".raw.wav")} for fid in todo]
    jobs_path = os.path.join(tmp, "jobs.json")
    result_path = os.path.join(tmp, "result.json")
    with open(jobs_path, "w", encoding="utf-8") as f:
        json.dump(jobs, f, ensure_ascii=False)
    print("synthesizing %d parts with Windows OneCore voices (file output only)..." % len(jobs))
    ps = shutil.which("powershell") or "powershell"
    cp = subprocess.run([ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", PS1,
                         "-Jobs", jobs_path, "-Result", result_path], capture_output=True, text=True, timeout=3600)
    if cp.returncode != 0 or not os.path.exists(result_path):
        print("TTS driver failed:", cp.stdout[-2000:], cp.stderr[-2000:])
        return 1
    with open(result_path, encoding="utf-8") as f:
        res = json.load(f)
    failed: dict = res.get("failed", {}) or {}
    for fid, why in failed.items():
        missing[fid] = "tts failed: %s" % why
    ok_ids = [j["id"] for j in jobs if j["id"] not in failed]
    print("synthesized %d, failed %d (engine %s)" % (len(ok_ids), len(failed), res.get("engine")))

    def build(fid: str) -> tuple[str, dict | None, str]:
        job = wanted[fid]
        raw = os.path.join(tmp, fid + ".raw.wav")
        try:
            y = process(raw, job["prof"], job["cues"], fid)
            proc = os.path.join(tmp, fid + ".proc.wav")
            write_wav(proc, y)
            path, fmt = encode(proc, job["speaker"], fid)
            return fid, {"line": job["line"], "speaker": job["speaker"], "hash": job["hash"], "path": path,
                         "format": fmt, "duration": round(len(y) / SR, 3), "voice": job["voice"],
                         "chain": job["prof"]["chain"]}, ""
        except Exception as e:  # noqa: BLE001
            return fid, None, "%s: %s" % (type(e).__name__, e)

    done = 0
    with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) - 1)) as ex:
        for fid, row, err in ex.map(build, ok_ids):
            if row is None:
                missing[fid] = "processing failed: " + err
                print("  FAIL", fid, err)
            else:
                files[fid] = row
                missing.pop(fid, None)
            done += 1
            if done % 50 == 0:
                print("  %d / %d" % (done, len(ok_ids)))
    shutil.rmtree(tmp, ignore_errors=True)
    _write_manifest(manifest)
    total = sum(r.get("duration", 0.0) for r in files.values())
    print("done: %d audio files (%.1f min of speech), %d without audio" % (len(files), total / 60.0, len(missing)))
    return 0


def _write_manifest(manifest: dict) -> None:
    manifest["_doc"] = ("Built by gravelight/tools_src/gen_vo.py. files: audio file per line (or per exchange part "
                        "<id>_p<n>) with the text/profile hash that produced it; missing: ids with no audio and why. "
                        "Windows OneCore TTS (Microsoft David / Mark / Zira), processed; see docs/ASSETS.md.")
    manifest["tool_version"] = TOOL_VERSION
    manifest["files"] = dict(sorted(manifest["files"].items()))
    manifest["missing"] = dict(sorted(manifest["missing"].items()))
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
