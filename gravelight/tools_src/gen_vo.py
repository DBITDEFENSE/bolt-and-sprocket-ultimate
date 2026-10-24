#!/usr/bin/env python3
"""GRAVELIGHT voice bake: every VO line in data/gravelight/vo/lines.json becomes an audio file.

Pipeline per line (per part for banter / tag exchanges):
  1. the subtitle text is cleaned for speech: [stage directions] become effect cues (static, whisper, distant...),
     (parentheticals) and *markers* are dropped, {splice} words become the Operator's pitch-jumped fragments
  2. synthesis, two engines:
     * the squad and Jakub (DUT PEG DEA WRN JAK, data/gravelight/vo/voice_cast.json; T-073): Kokoro-82M, an offline
       neural TTS (Apache-2.0), through gen_vo_neural.py in the project-local venv (tools/venv, models in
       tools/tts/kokoro; one-time setup: tools/setup_tts.sh). One cast voice per character (a blend of Kokoro
       styles), misaki US/GB lexicons, Polish words in Polish phonemes, a light Polish first-language accent for
       Wren and Jakub, and a delivery per category (calm / brisk / raised / shout / hurt / quiet / mine)
     * everyone else (the Operator, Fasbender, Reinholt, Liesl), and the squad when the neural engine isn't set
       up (or --engine=onecore): Windows' offline OneCore voices (Microsoft David / Mark / Zira) through
       gen_vo_tts.ps1 with per-speaker SSML prosody (rate, pitch)
     File output only, never the speakers.
  3. numpy/scipy post-processing. OneCore lines: each of the speakers gets a distinct timbre from a phase-vocoder
     "size" shift (pitch and formants together), EQ, and the channel the script asks for: the Operator's
     1940s tannoy (band-pass, brass saturation, hall, tape hiss, crackle, flutter) with a cleaner "corporate"
     timbre for the op.slip.* lines, Fasbender's hand-over-the-mic radio with static, Reinholt's PA hijacks or
     wax-cylinder phonograph, Liesl's child pitch on the phonograph. Neural lines: per-character EQ and warmth,
     the delivery's presence / air / drive / tremor, a gentle compressor, an inhale before longer lines and in
     the longer pauses, a small room (a mine cavern for the Kaltenbrunn arrival lines), then loudness
     normalisation to a LUFS target (BS.1770, vo_loudness.py; the delivery moves it: shouts hotter, quiet lines
     softer) and a true-peak limit. No pitch shifting on neural lines (no phase-vocoder artefacts).
  4. ffmpeg encodes to Ogg Vorbis, mono, ~64 kbps, at res://gravelight/audio/vo/<speaker>/<id>.ogg; if the
     encode fails the processed WAV is written there instead (VOManager accepts either)

Deterministic (every effect draws from an RNG seeded by the file id) and incremental: a file is only rebuilt
when the hash of its text, voice profile / cast entry and tool version changes (data/gravelight/vo/audio_manifest.json).

Run from the repo root:
  python gravelight/tools_src/gen_vo.py                 everything (new / changed lines only)
  python gravelight/tools_src/gen_vo.py --only=OPR      one speaker, or an id prefix (--only=BNT_DUT); a comma list
                                                        (--only=DUT,PEG); --only=SQUAD is DUT,PEG,DEA,WRN,JAK
  python gravelight/tools_src/gen_vo.py --force         rebuild regardless of the manifest
  python gravelight/tools_src/gen_vo.py --dry-run       list what would be built
  python gravelight/tools_src/gen_vo.py --engine=onecore   squad on the old OneCore voices (the fallback)
  python gravelight/tools_src/gen_vo.py --engine=neural    fail instead of falling back when Kokoro is missing
Then reimport once so Godot sees the new files:  godot --headless --editor --quit-after 300 --path .
Loudness / sanity report of what's baked: python gravelight/tools_src/vo_loudness.py
Requires numpy + scipy and ffmpeg on PATH. Windows only (OneCore voices; the neural venv is Windows too).
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
from scipy import ndimage, signal
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

# ───────────────────────────────────────────────────────────── neural cast (T-073)
CAST_PATH = os.path.join(ROOT, "data", "gravelight", "vo", "voice_cast.json")
NEURAL_PY = os.path.join(HERE, "gen_vo_neural.py")
NEURAL_TOOL_VERSION = "1"     # bump to rebuild every neural line (the hash includes it)
SQUAD = ("DUT", "PEG", "DEA", "WRN", "JAK")
with open(CAST_PATH, encoding="utf-8") as _f:
    CAST: dict = json.load(_f)


def _tts_roots() -> list[str]:
    """Where tools/venv and tools/tts may live: $GL_TTS_ROOT, this checkout, then the main checkout (a git
    worktree shares the main checkout's git-ignored downloads)."""
    roots = []
    if os.environ.get("GL_TTS_ROOT"):
        roots.append(os.environ["GL_TTS_ROOT"])
    roots.append(ROOT)
    try:
        cp = subprocess.run(["git", "-C", ROOT, "rev-parse", "--git-common-dir"], capture_output=True, text=True,
                            timeout=20)
        common = cp.stdout.strip()
        if cp.returncode == 0 and common:
            if not os.path.isabs(common):
                common = os.path.join(ROOT, common)
            roots.append(os.path.dirname(os.path.abspath(common)))
    except (OSError, subprocess.SubprocessError):
        pass
    return roots


def neural_env() -> tuple[str, str] | None:
    """(venv python, Kokoro model dir) when the neural engine is set up, else None."""
    for r in _tts_roots():
        py = os.path.join(r, "tools", "venv", "Scripts", "python.exe")
        if not os.path.exists(py):
            py = os.path.join(r, "tools", "venv", "bin", "python")
        model = os.path.join(r, "tools", "tts", "kokoro")
        if os.path.exists(py) and os.path.exists(os.path.join(model, "kokoro-v1.0.onnx")) \
                and os.path.exists(os.path.join(model, "voices-v1.0.bin")):
            return py, model
    return None


ONLY: list[str] = []
FORCE: bool = False
DRY: bool = False
ENGINE: str = "auto"          # auto | neural | onecore
for a in sys.argv[1:]:
    if a.startswith("--only="):
        ONLY = [x.strip() for x in a[len("--only="):].split(",") if x.strip()]
        if any(x.upper() == "SQUAD" for x in ONLY):
            ONLY = [x for x in ONLY if x.upper() != "SQUAD"] + list(SQUAD)
    elif a.startswith("--engine="):
        ENGINE = a[len("--engine="):]
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


# ───────────────────────────────────────────────────────────── neural post-processing (T-073)

NEUTRAL = {"speed": 1.0, "lufs": 0.0, "presence_db": 0.0, "air_db": 0.0, "drive": 1.0, "tremor": 0.0}


def emotion_for(category: str, text: str, speaker: str) -> tuple[str, dict]:
    """The delivery of a line: (name, params scaled by the speaker's emotion_scale)."""
    cats: dict = CAST.get("categories", {})
    best = ""
    for prefix in cats:
        if not prefix.startswith("_") and category.startswith(prefix) and len(prefix) > len(best):
            best = prefix
    name = str(cats[best]) if best else "calm"
    if name in ("calm", "brisk") and "!" in text:
        name = "raised"
    emo = dict(CAST["emotions"][name])
    scale = float(CAST["cast"][speaker].get("emotion_scale", 1.0))
    for k, n in NEUTRAL.items():
        emo[k] = n + scale * (float(emo.get(k, n)) - n)
    # Only a speaker who really lets go turns the last full stop into "!" (Peg sounds bored in a crisis).
    emo["exclaim"] = bool(emo.get("exclaim", False)) and scale >= 0.6
    return name, emo


def shelf_high(x, f, gain_db):
    """Gentle high shelf: add (or remove) a high-passed copy."""
    if abs(gain_db) < 0.05:
        return x
    return x + (db(gain_db) - 1.0) * highpass(x, f, 1)


def smooth_compress(x, thresh_db, ratio, ms=12.0, release_ms=60.0):
    """Feed-forward RMS compressor with a smoothed gain (no pumping on a single line)."""
    env = envelope(x, ms)
    env_db = 20 * np.log10(env + 1e-9)
    over = np.maximum(0.0, env_db - thresh_db)
    g_db = -over * (1.0 - 1.0 / ratio)
    a = np.exp(-1.0 / (SR * release_ms / 1000.0))
    g_db = signal.lfilter([1 - a], [1, -a], g_db)
    g_db = signal.lfilter([1 - a], [1, -a], g_db[::-1])[::-1]   # zero-phase: the gain leads, never lags
    return x * (10.0 ** (g_db / 20.0))


def tremor(x, r, depth, hz=5.6):
    """A hurt voice's shake: a slow amplitude wobble plus a hair of pitch wobble, irregular from line to line."""
    if depth <= 0.0:
        return x
    t = np.arange(len(x)) / SR
    drift = np.cumsum(r.standard_normal(len(x))) / np.sqrt(SR) * 0.6
    am = 1.0 - depth * 0.5 * (1.0 + np.sin(2 * np.pi * hz * t + drift + r.uniform(0, 6.28)))
    return wow(x * am, r, hz * 0.9, 0.0012 * depth / 0.07)


def inhale(r, length_s, level):
    """A soft synthesized in-breath: band-limited pink noise under an asymmetric swell."""
    n = int(SR * length_s)
    if n < 32:
        return np.zeros(0)
    b = pink(n, r)
    b = bandpass(b, 450, 2600, 2) + 0.5 * bandpass(b, 1100, 1700, 2)
    env = np.concatenate([np.linspace(0, 1, int(n * 0.65)) ** 1.6, np.linspace(1, 0, n - int(n * 0.65)) ** 0.8])
    b = b * env
    b /= np.sqrt(np.mean(b * b)) + 1e-9
    return b * level


def speech_rms(x):
    env = envelope(x, 50.0)
    active = x[env > np.max(env) * db(-30.0)]
    return float(np.sqrt(np.mean(active * active))) if len(active) else float(np.sqrt(np.mean(x * x)) + 1e-9)


def add_breaths(x, r, breath_db, breath_s=(0.26, 0.36)):
    """An inhale before a line of 1.2 s or more, and in some sentence pauses of 350 ms or more."""
    if breath_db is None or len(x) < SR * 1.2:
        return x
    lvl = speech_rms(x) * db(float(breath_db))
    pre = inhale(r, r.uniform(float(breath_s[0]), float(breath_s[1])), lvl)
    gap = np.zeros(int(SR * r.uniform(0.05, 0.09)))
    # Inner pauses: windows where the 20 ms envelope stays 35 dB under the line's peak.
    env = envelope(x, 20.0)
    quiet = env < np.max(env) * db(-35.0)
    out = x.copy()
    i = int(SR * 0.3)
    while i < len(x) - int(SR * 0.3):
        if quiet[i]:
            j = i
            while j < len(x) and quiet[j]:
                j += 1
            if (j - i) >= SR * 0.35 and j < len(x) - int(SR * 0.25) and r.uniform() < 0.6:
                blen = min(0.24, (j - i) / SR * 0.6)
                br = inhale(r, blen, lvl * db(-3.0))
                end = j - int(SR * 0.04)
                st = max(i, end - len(br))
                out[st:st + len(br)] += br[: end - st]
            i = j
        i += int(SR * 0.01)
    return np.concatenate([pre, gap, out])


def peak_limit(x, ceiling_db):
    """Soft true-peak ceiling: a 1.5 ms look-ahead gain ride on the 4x-oversampled peak, then a hard guard."""
    ceil = db(ceiling_db)
    up = np.abs(signal.resample_poly(x, 4, 1))[: len(x) * 4]
    pk = up.reshape(-1, 4).max(axis=1) if len(up) >= len(x) * 4 else np.abs(x)
    w = max(1, int(SR * 0.0015))
    pk = ndimage.maximum_filter1d(pk, 2 * w + 1)
    g = np.minimum(1.0, ceil / (pk + 1e-9))
    a = np.exp(-1.0 / (SR * 0.03))
    g = np.minimum(g, signal.lfilter([1 - a], [1, -a], g))
    y = x * g
    tp = np.max(np.abs(signal.resample_poly(y, 4, 1))) + 1e-9
    if tp > ceil:
        y *= ceil / tp
    return y


def process_neural(wav_path: str, speaker: str, emo_name: str, emo: dict, cues: set[str], category: str,
                   file_id: str) -> np.ndarray:
    import vo_loudness
    sr_in, data = wavfile.read(wav_path)
    x = data.astype(np.float64)
    if data.dtype == np.int16:
        x /= 32768.0
    if x.ndim > 1:
        x = x[:, 0]
    if sr_in != SR:
        from math import gcd
        g = gcd(SR, sr_in)
        x = signal.resample_poly(x, SR // g, sr_in // g)
    c = CAST["cast"][speaker]
    r = rng_for("neural:" + file_id)
    x = trim(x, -50.0, 40.0)
    x = x * db(-20.0 - vo_loudness.integrated_lufs(x, SR)) if len(x) > SR * 0.05 else x
    # Character: high-pass, EQ bands, warmth.
    x = highpass(x, float(c.get("hp_hz", 80)), 2)
    for lo, hi, gdb in c.get("eq", []):
        x = boost(x, float(lo), float(hi), float(gdb))
    w = float(c.get("warmth", 1.0)) * float(emo["drive"])
    if w > 1.01:
        # tanh warmth at the speech's level (-20 LUFS peaks near -6 dBFS): gentle harmonics, no audible fuzz
        x = saturate(x * 2.0, w) / 2.0
    # Delivery.
    x = boost(x, 2000, 4500, float(emo["presence_db"]))
    x = shelf_high(x, 5000, float(emo["air_db"]))
    x = tremor(x, r, float(emo["tremor"]))
    x = smooth_compress(x, -26.0, 2.4)
    x = add_breaths(x, r, emo.get("breath_db"), emo.get("breath_s") or (0.26, 0.36))
    # Space: a small room around the speaker; whisper / distant cues as in the old chain.
    room = emo.get("room") or [0.3, 0.06]
    x = reverb(x, float(room[0]), r, float(room[1]), 8.0 if room[0] < 0.6 else 22.0, 4500.0 if room[0] < 0.6 else 3200.0)
    x = apply_cues(x, r, cues, "squad")
    x = trim(x, -60.0, 60.0)
    # Loudness: the target, moved by the delivery and the speaker's trim, then the true-peak ceiling.
    lo = CAST.get("loudness", {})
    target = float(lo.get("target_lufs", -17.5)) + float(emo["lufs"]) + float(c.get("lufs_offset", 0.0))
    cur = vo_loudness.integrated_lufs(x, SR)
    if np.isfinite(cur):
        x = x * db(target - cur)
    x = peak_limit(x, float(lo.get("true_peak_db", -1.5)))
    return fade(x, 8.0)


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


def neural_hash(speaker: str, text: str, emo_name: str, emo: dict, cues: set[str]) -> str:
    c = CAST["cast"][speaker]
    acc = CAST.get("accents", {}).get(str(c.get("accent", "")), {})
    pol = CAST.get("polish", {})
    words = set(re.findall(r"[^\W\d_]+", text.lower()))
    pl_hit = bool(re.search(r"[ąćęłńóśźż]", text.lower())) or bool(
        words & {w.lower() for w in pol.get("words", []) + pol.get("weak_words", [])})
    ger = CAST.get("german", {})
    de_hit = bool(c.get("native_german")) and bool(words & {w.lower() for w in ger.get("words", [])})
    key = "|".join(["neural", NEURAL_TOOL_VERSION, json.dumps(c, sort_keys=True, ensure_ascii=False),
                    json.dumps(acc, sort_keys=True, ensure_ascii=False), emo_name, json.dumps(emo, sort_keys=True),
                    json.dumps(CAST.get("loudness", {}), sort_keys=True), ",".join(sorted(cues)),
                    json.dumps(pol, sort_keys=True, ensure_ascii=False) if pl_hit else "", text]
                   + ([json.dumps(ger, sort_keys=True, ensure_ascii=False)] if de_hit else []))
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:16]


def _wants(only: list[str], line_id: str, rec_speaker: str, part_speaker: str) -> bool:
    if not only:
        return True
    for o in only:
        if line_id.startswith(o) or o.upper() in (rec_speaker.upper(), part_speaker.upper()):
            return True
    return False


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

    nenv = None if ENGINE == "onecore" else neural_env()
    if ENGINE == "neural" and nenv is None:
        print("--engine=neural but the Kokoro venv / model is missing: run tools/setup_tts.sh")
        return 1
    if nenv is None and ENGINE != "onecore":
        print("note: neural voices not set up (tools/setup_tts.sh); the squad falls back to OneCore")
    neural_speakers = set(CAST.get("cast", {}).keys()) if nenv is not None else set()

    # Every (file id) this lines.json wants.
    wanted: dict[str, dict] = {}
    for line_id, rec in sorted(lines.items()):
        speaker = str(rec.get("speaker", ""))
        category = str(rec.get("category", ""))
        parts_src: list[tuple[str, str, str]] = []
        if rec.get("exchange"):
            parts_src = [(str(p[0]), str(p[1]), str(p[1])) for p in rec["exchange"]]
        else:
            # "tts": a phonetic respelling for the OneCore voices (Jakub's Polish); the subtitle keeps "text". The
            # neural engine reads "text" itself (it has real Polish phonemes).
            parts_src = [(speaker, str(rec.get("tts") or rec.get("text", "")), str(rec.get("text", "")))]
        multi = len(parts_src) > 1 or bool(rec.get("exchange"))
        for i, (spk, text, raw_text) in enumerate(parts_src):
            if not _wants(ONLY, line_id, speaker, spk):
                continue
            file_id = "%s_p%d" % (line_id, i) if multi else line_id
            if spk in neural_speakers:
                parts, cues = speech_parts(raw_text)
                say = plain_text(parts)
                if not re.search(r"[A-Za-z0-9]", say):
                    missing[file_id] = "no speech: stage direction only (%s)" % raw_text[:40]
                    continue
                emo_name, emo = emotion_for(category, say, spk)
                c = CAST["cast"][spk]
                wanted[file_id] = dict(line=line_id, speaker=spk, text=say, engine="kokoro",
                                       hash=neural_hash(spk, say, emo_name, emo, cues), voice=str(c["voice"]),
                                       emo_name=emo_name, emo=emo, cues=cues, category=category,
                                       njob={"speaker": spk, "text": say, "voice": str(c["voice"]),
                                             "speed": round(float(c.get("speed", 1.0)) * float(emo["speed"]), 4),
                                             "lexicon": str(c.get("lexicon", "us")),
                                             "accent": str(c.get("accent", "")),
                                             "native_polish": bool(c.get("native_polish", False)),
                                             "native_german": bool(c.get("native_german", False)),
                                             "exclaim": bool(emo.get("exclaim", False))})
                missing.pop(file_id, None)
                continue
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
                                   cues=cues, engine="onecore")
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
    n_neural = sum(1 for fid in todo if wanted[fid]["engine"] == "kokoro")
    print("lines %d, files wanted %d, to build %d (neural %d, onecore %d), skipped (up to date) %d, no speech %d" % (
        len(lines), len(wanted), len(todo), n_neural, len(todo) - n_neural, len(wanted) - len(todo), len(missing)))
    if DRY:
        for fid in todo:
            w = wanted[fid]
            tag = "kokoro:" + w["emo_name"] if w["engine"] == "kokoro" else "onecore"
            print("  ", fid, "[%s]" % tag, "->", w["text"][:70])
        return 0
    if not todo:
        _write_manifest(manifest)
        return 0

    tmp = tempfile.mkdtemp(prefix="glvo_")
    ok_ids: list[str] = []
    phonemes: dict[str, str] = {}
    one_ids = [fid for fid in todo if wanted[fid]["engine"] == "onecore"]
    neu_ids = [fid for fid in todo if wanted[fid]["engine"] == "kokoro"]
    if one_ids:
        jobs = [{"id": fid, "voice": wanted[fid]["voice"], "ssml": wanted[fid]["ssml"],
                 "wav": os.path.join(tmp, fid + ".raw.wav")} for fid in one_ids]
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
        ok1 = [j["id"] for j in jobs if j["id"] not in failed]
        ok_ids += ok1
        print("synthesized %d, failed %d (engine %s)" % (len(ok1), len(failed), res.get("engine")))
    if neu_ids:
        assert nenv is not None
        py, model = nenv
        # A few processes (each loads the model once; onnxruntime runs its own threads inside each).
        nproc = max(1, min(4, (os.cpu_count() or 4) // 4, len(neu_ids) // 40 + 1))
        chunks = [neu_ids[k::nproc] for k in range(nproc)]
        procs = []
        print("synthesizing %d parts with Kokoro (%d processes, offline, file output only)..." % (len(neu_ids), nproc))
        env = dict(os.environ)
        env["OMP_NUM_THREADS"] = str(max(1, (os.cpu_count() or 4) // nproc))
        for k, ch in enumerate(chunks):
            jp = os.path.join(tmp, "neural_jobs_%d.json" % k)
            rp = os.path.join(tmp, "neural_result_%d.json" % k)
            with open(jp, "w", encoding="utf-8") as f:
                json.dump({"model": model, "cast": CAST, "jobs": [dict(wanted[fid]["njob"], id=fid,
                           wav=os.path.join(tmp, fid + ".raw.wav")) for fid in ch]}, f, ensure_ascii=False)
            procs.append((subprocess.Popen([py, "-I", NEURAL_PY, jp, rp], env=env, stdout=subprocess.PIPE,
                                           stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace"),
                          rp, ch))
        for pr, rp, ch in procs:
            out, _ = pr.communicate(timeout=7200)
            if pr.returncode != 0 or not os.path.exists(rp):
                print("neural driver failed:", (out or "")[-2000:])
                for fid in ch:
                    missing[fid] = "neural tts failed (driver exit %s)" % pr.returncode
                continue
            with open(rp, encoding="utf-8") as f:
                res = json.load(f)
            failed = res.get("failed", {}) or {}
            for fid, why in failed.items():
                missing[fid] = "neural tts failed: %s" % why
            ok_ids += [fid for fid in ch if fid not in failed]
            phonemes.update(res.get("phonemes", {}))
        print("neural: synthesized %d of %d" % (len([f for f in neu_ids if f in set(ok_ids)]), len(neu_ids)))

    def build(fid: str) -> tuple[str, dict | None, str]:
        job = wanted[fid]
        raw = os.path.join(tmp, fid + ".raw.wav")
        try:
            if job["engine"] == "kokoro":
                y = process_neural(raw, job["speaker"], job["emo_name"], job["emo"], job["cues"], job["category"], fid)
            else:
                y = process(raw, job["prof"], job["cues"], fid)
            proc = os.path.join(tmp, fid + ".proc.wav")
            write_wav(proc, y)
            path, fmt = encode(proc, job["speaker"], fid)
            row = {"line": job["line"], "speaker": job["speaker"], "hash": job["hash"], "path": path,
                   "format": fmt, "duration": round(len(y) / SR, 3), "voice": job["voice"], "engine": job["engine"]}
            if job["engine"] == "kokoro":
                import vo_loudness
                row["delivery"] = job["emo_name"]
                row["lufs"] = round(vo_loudness.integrated_lufs(y, SR), 2)
                if fid in phonemes:
                    row["phonemes"] = phonemes[fid]
            else:
                row["chain"] = job["prof"]["chain"]
            return fid, row, ""
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
            if done % 100 == 0:
                print("  %d / %d" % (done, len(ok_ids)))
    shutil.rmtree(tmp, ignore_errors=True)
    _write_manifest(manifest)
    total = sum(r.get("duration", 0.0) for r in files.values())
    print("done: %d audio files (%.1f min of speech), %d without audio" % (len(files), total / 60.0, len(missing)))
    return 0


def _write_manifest(manifest: dict) -> None:
    manifest["_doc"] = ("Built by gravelight/tools_src/gen_vo.py. files: audio file per line (or per exchange part "
                        "<id>_p<n>) with the text/profile hash that produced it; engine kokoro (the squad and Jakub: "
                        "Kokoro-82M neural TTS, offline, cast in data/gravelight/vo/voice_cast.json, with the "
                        "delivery, the measured LUFS and the phonemes it read) or onecore (Windows OneCore TTS, "
                        "Microsoft David / Mark / Zira, processed); missing: ids with no audio and why. "
                        "See docs/ASSETS.md.")
    manifest["tool_version"] = TOOL_VERSION
    manifest["neural_tool_version"] = NEURAL_TOOL_VERSION
    manifest["files"] = dict(sorted(manifest["files"].items()))
    manifest["missing"] = dict(sorted(manifest["missing"].items()))
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
