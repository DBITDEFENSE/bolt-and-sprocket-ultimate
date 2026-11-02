#!/usr/bin/env python3
"""Ambience loudness check (UPDATE 10 section 2.2 item 6, DECISIONS T-154): every ZoneAmbience bed of a map, as it
plays (its file's integrated loudness, BS.1770 via vo_loudness.py, + the zone's "db" + the key's volume_db), and the
map-wide ambient bed under it (audio.json music.ambient at the top of music.ambient_db), against the player's
footsteps (the footstep_* keys: each file's loudest 400 ms, BS.1770 momentary loudness, + its volume_db, averaged). The rule: no bed, and no bed plus the
storm under it, louder than `limit` dB relative to the footsteps (default -8: every bed sits at least 8 dB under a
footstep). One-shots are listed for reference (they are short events, not beds).

    <python with numpy+scipy> -I gravelight/tools_src/amb_loudness.py [map02] [--limit=-8]
Exit code: the number of beds over the limit. Decodes the OGGs with ffmpeg to raw PCM (nothing is executed).
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import numpy as np        # noqa: E402
import vo_loudness        # noqa: E402

SR = 44100


def res_path(res: str) -> str:
    return os.path.join(ROOT, res.replace("res://", "").replace("/", os.sep))


def decode(path: str) -> np.ndarray:
    out = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(out, dtype="<i2").astype(float) / 32768.0


def momentary_max(x: np.ndarray, fs: float) -> float:
    """The loudest 400 ms of a sound (BS.1770 momentary loudness), the level a footstep is heard at."""
    y = vo_loudness.k_weight(x, fs)
    w = int(0.4 * fs)
    if len(y) < w:
        y = np.concatenate([y, np.zeros(w - len(y))])
    c = np.concatenate([[0.0], np.cumsum(y * y)])
    ms = (c[w:] - c[:-w]) / w
    return -0.691 + 10 * math.log10(max(float(ms.max()), 1e-12))


def key_lufs(sounds: dict, key: str, peak: bool = False) -> float:
    e = sounds.get(key)
    if not e:
        return float("nan")
    vals = []
    for f in e.get("files", []):
        p = res_path(f)
        if os.path.exists(p):
            v = momentary_max(decode(p), SR) if peak else vo_loudness.integrated_lufs(decode(p), SR)
            if math.isfinite(v):
                vals.append(v)
    if not vals:
        return float("nan")
    # average in power, then the key's own trim
    return 10 * math.log10(sum(10 ** (v / 10) for v in vals) / len(vals)) + float(e.get("volume_db", 0.0))


def psum(*db: float) -> float:
    return 10 * math.log10(sum(10 ** (d / 10) for d in db))


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    limit = -8.0
    for a in sys.argv[1:]:
        if a.startswith("--limit="):
            limit = float(a.split("=", 1)[1])
    map_key = args[0] if args else "map02"
    audio = json.load(open(os.path.join(ROOT, "data", "gravelight", "audio.json"), encoding="utf-8"))
    sounds = audio["sounds"]
    amb = json.load(open(os.path.join(ROOT, "data", "gravelight", "ambience", map_key + ".json"), encoding="utf-8"))
    steps = [k for k in sounds if k.startswith("footstep_")]
    step = psum(*[key_lufs(sounds, k, True) for k in steps]) - 10 * math.log10(len(steps))
    music = audio.get("music", {})
    amb_map = music.get("ambient", {})
    storm_key = next((v for k, v in amb_map.items() if k.startswith(map_key)), "")
    storm = key_lufs(sounds, storm_key) + float(music.get("ambient_db", [-6.0, -2.0])[-1]) if storm_key else float("-inf")
    print(f"footsteps ({len(steps)} keys, loudest 400 ms): {step:6.1f} LUFS   limit: beds <= footsteps {limit:+.1f} dB")
    if storm_key:
        print(f"map bed {storm_key}: {storm:6.1f} LUFS  ({storm - step:+5.1f} dB vs footsteps)")
    over = 0
    for zone, z in amb.get("zones", {}).items():
        bed = key_lufs(sounds, str(z.get("bed", ""))) + float(z.get("db", 0.0))
        both = psum(bed, storm) if storm_key else bed
        ok = bed - step <= limit and both - step <= limit
        over += 0 if ok else 1
        print(f"  {zone:12s} {z.get('bed', ''):26s} {bed:6.1f} LUFS ({bed - step:+5.1f})  with the map bed {both:6.1f} ({both - step:+5.1f})  {'ok' if ok else 'OVER'}")
        for o in z.get("oneshots", []):
            v = key_lufs(sounds, str(o.get("key", ""))) + float(o.get("db", 0.0))
            print(f"      one-shot {o.get('key', ''):22s} {v:6.1f} LUFS ({v - step:+5.1f})")
    print(f"RESULT: {'PASS' if over == 0 else 'FAIL'} ({over} beds over)")
    return over


if __name__ == "__main__":
    sys.exit(main())
