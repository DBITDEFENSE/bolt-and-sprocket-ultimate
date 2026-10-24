#!/usr/bin/env python3
"""Loudness and sanity measurements for the GRAVELIGHT voice bake (T-073).

Used by gen_vo.py (loudness-normalises every squad line to a LUFS target) and runnable on its own as a report:

  python gravelight/tools_src/vo_loudness.py                  every baked file in the manifest
  python gravelight/tools_src/vo_loudness.py --only=DUT,WRN   some speakers
  python gravelight/tools_src/vo_loudness.py --engine=kokoro  only the neural (or onecore) files
  python gravelight/tools_src/vo_loudness.py --json=out.json  also write the per-file numbers

Per file it measures integrated loudness (ITU-R BS.1770-4: K-weighting, 400 ms blocks, absolute -70 LUFS and
relative -10 LU gates), the 4x-oversampled true peak, clipped samples, duration, leading / trailing silence and a
"cut-off" flag (speech energy in the last 30 ms: a truncated synthesis ends mid-word). Per speaker it prints the
mean, spread (standard deviation and min..max) of loudness and the duration range. Decodes .ogg through ffmpeg.
Needs numpy + scipy. Measures files only; never plays anything.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MANIFEST = os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json")


# ───────────────────────────────────────────────────────────── BS.1770 K-weighting

def _biquad_high_shelf(fs: float, g_db: float = 3.999843853973347, q: float = 0.7071752369554196,
                       fc: float = 1681.974450955533) -> tuple[np.ndarray, np.ndarray]:
    # The stage-1 "head" shelf for any rate (BS.1770 only lists 48 kHz coefficients; this is the analytic form
    # that reproduces them exactly, after B. De Man / libebur128).
    K = np.tan(np.pi * fc / fs)
    Vh = 10 ** (g_db / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / q + K * K
    b = np.array([(Vh + Vb * K / q + K * K) / a0, 2.0 * (K * K - Vh) / a0, (Vh - Vb * K / q + K * K) / a0])
    a = np.array([1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / q + K * K) / a0])
    return b, a


def _biquad_high_pass(fs: float, q: float = 0.5003270373238773,
                      fc: float = 38.13547087602444) -> tuple[np.ndarray, np.ndarray]:
    K = np.tan(np.pi * fc / fs)
    d = 1.0 + K / q + K * K
    return np.array([1.0, -2.0, 1.0]), np.array([1.0, 2.0 * (K * K - 1.0) / d, (1.0 - K / q + K * K) / d])


def k_weight(x: np.ndarray, fs: float) -> np.ndarray:
    b, a = _biquad_high_shelf(fs)
    y = signal.lfilter(b, a, x)
    b, a = _biquad_high_pass(fs)
    return signal.lfilter(b, a, y)


def integrated_lufs(x: np.ndarray, fs: float) -> float:
    """Integrated loudness of a mono signal in LUFS (-inf for silence)."""
    if len(x) == 0:
        return float("-inf")
    y = k_weight(np.asarray(x, dtype=np.float64), fs)
    block = int(round(0.4 * fs))
    hop = int(round(0.1 * fs))
    if len(y) < block:
        # A very short line: one block over the whole thing (the gates still apply).
        ms = np.array([np.mean(y * y)])
    else:
        n = 1 + (len(y) - block) // hop
        c = np.concatenate([[0.0], np.cumsum(y * y)])
        starts = np.arange(n) * hop
        ms = (c[starts + block] - c[starts]) / block
    lk = -0.691 + 10 * np.log10(ms + 1e-20)
    keep = ms[lk > -70.0]
    if len(keep) == 0:
        return float("-inf")
    rel = -0.691 + 10 * np.log10(np.mean(keep)) - 10.0
    keep2 = ms[(lk > -70.0) & (lk > rel)]
    if len(keep2) == 0:
        keep2 = keep
    return float(-0.691 + 10 * np.log10(np.mean(keep2)))


def true_peak_db(x: np.ndarray) -> float:
    if len(x) == 0:
        return float("-inf")
    up = signal.resample_poly(x, 4, 1)
    return float(20 * np.log10(np.max(np.abs(up)) + 1e-12))


def silence_ms(x: np.ndarray, fs: float, thresh_db: float = -45.0) -> tuple[float, float]:
    """(leading, trailing) silence in ms below `thresh_db` relative to the file's peak (10 ms windows)."""
    if len(x) == 0:
        return 0.0, 0.0
    w = max(1, int(fs * 0.01))
    n = len(x) // w
    if n == 0:
        return 0.0, 0.0
    rms = np.sqrt(np.mean(x[: n * w].reshape(n, w) ** 2, axis=1) + 1e-20)
    ref = np.max(np.abs(x)) + 1e-12
    on = np.where(20 * np.log10(rms / ref) > thresh_db)[0]
    if len(on) == 0:
        return n * 10.0, 0.0
    return on[0] * 10.0, (n - 1 - on[-1]) * 10.0


def cut_off(x: np.ndarray, fs: float) -> bool:
    """True when the last 30 ms still carries speech-level energy (within 20 dB of the line's loud parts)."""
    n = int(fs * 0.03)
    if len(x) < n * 4:
        return False
    tail = np.sqrt(np.mean(x[-n:] ** 2) + 1e-20)
    body = np.percentile(np.abs(x), 95) + 1e-12
    return bool(20 * np.log10(tail / body) > -20.0)


def measure(x: np.ndarray, fs: float) -> dict:
    lead, trail = silence_ms(x, fs)
    return {"lufs": round(integrated_lufs(x, fs), 2), "true_peak_db": round(true_peak_db(x), 2),
            "clipped": int(np.sum(np.abs(x) >= 0.999)), "duration": round(len(x) / fs, 3),
            "lead_ms": lead, "trail_ms": trail, "cut_off": cut_off(x, fs)}


# ───────────────────────────────────────────────────────────── file IO

def read_audio(path: str) -> tuple[np.ndarray, int]:
    """Mono float audio from a .wav, or an .ogg via ffmpeg."""
    if path.lower().endswith(".wav"):
        fs, d = wavfile.read(path)
    else:
        ff = shutil.which("ffmpeg")
        if not ff:
            raise RuntimeError("ffmpeg not on PATH (needed to decode .ogg)")
        cp = subprocess.run([ff, "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", "24000", "-"],
                            capture_output=True, check=True, timeout=60)
        d = np.frombuffer(cp.stdout, dtype=np.int16)
        fs = 24000
    if d.ndim > 1:
        d = d[:, 0]
    if d.dtype == np.int16:
        x = d.astype(np.float64) / 32768.0
    else:
        x = d.astype(np.float64)
    return x, int(fs)


def report(only: list[str], json_out: str = "", engine: str = "") -> int:
    with open(MANIFEST, encoding="utf-8") as f:
        man = json.load(f)
    rows: dict[str, dict] = {}
    from concurrent.futures import ThreadPoolExecutor

    items = [(fid, r) for fid, r in man["files"].items() if (not only or r["speaker"] in only)
             and (not engine or r.get("engine", "onecore") == engine)]

    def one(item):
        fid, r = item
        p = os.path.join(ROOT, r["path"][len("res://"):].replace("/", os.sep))
        x, fs = read_audio(p)
        m = measure(x, fs)
        m["speaker"] = r["speaker"]
        m["engine"] = r.get("engine", "onecore")
        return fid, m

    with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) - 2)) as ex:
        for fid, m in ex.map(one, items):
            rows[fid] = m
    by: dict[str, list[dict]] = {}
    for m in rows.values():
        by.setdefault(m["speaker"], []).append(m)
    print("%-5s %5s %8s %6s %15s %8s %6s %6s %13s" % ("spk", "files", "LUFS", "sd", "min..max", "peak", "clip", "cut",
                                                      "dur s"))
    allv = []
    for spk in sorted(by):
        ms = by[spk]
        lv = np.array([m["lufs"] for m in ms if np.isfinite(m["lufs"])])
        allv.extend(lv.tolist())
        d = np.array([m["duration"] for m in ms])
        print("%-5s %5d %8.2f %6.2f %7.1f..%-7.1f %8.2f %6d %6d %5.2f..%-6.2f" % (
            spk, len(ms), lv.mean(), lv.std(), lv.min(), lv.max(), max(m["true_peak_db"] for m in ms),
            sum(1 for m in ms if m["clipped"] > 0), sum(1 for m in ms if m["cut_off"]), d.min(), d.max()))
    if allv:
        a = np.array(allv)
        print("all   %5d %8.2f %6.2f %7.1f..%-7.1f" % (len(a), a.mean(), a.std(), a.min(), a.max()))
    if json_out:
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=1)
    return 0


if __name__ == "__main__":
    only: list[str] = []
    jout = ""
    eng = ""
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = [s.strip().upper() for s in a[len("--only="):].split(",") if s.strip()]
        elif a.startswith("--engine="):
            eng = a[len("--engine="):]
        elif a.startswith("--json="):
            jout = a[len("--json="):]
        elif a in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
    sys.exit(report(only, jout, eng))
