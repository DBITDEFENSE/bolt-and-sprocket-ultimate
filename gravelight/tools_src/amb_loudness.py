#!/usr/bin/env python3
"""Ambience loudness check (UPDATE 10 section 2.2 item 6, DECISIONS T-154): every ZoneAmbience bed of a map, as it
plays (its file's integrated loudness, BS.1770 via vo_loudness.py, + the zone's "db" + the key's volume_db), and the
map-wide ambient bed under it (audio.json music.ambient at the top of music.ambient_db), against the player's
footsteps (the footstep_* keys: each file's loudest 400 ms, BS.1770 momentary loudness, + its volume_db, averaged). The rule: no bed, and no bed plus the
storm under it, louder than `limit` dB relative to the footsteps (default -8: every bed sits at least 8 dB under a
footstep). One-shots are listed for reference (they are short events, not beds).

    <python with numpy+scipy> -I gravelight/tools_src/amb_loudness.py [all | map00 map02 map04b ...] [--limit=-8] [--vo-margin=6] [--apply]
U10 s6 (T-162): every map and act (default all: map00, map01, map02, map04a-d), and the VO (mean baked-line loudness + rules.json
 audio.squad_volume_db) must sit at least --vo-margin dB over every bed. Exit code: the number of beds over the limit. Decodes the OGGs with ffmpeg to raw PCM (nothing is executed).
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


def vo_level(rules_audio: dict) -> float:
    """The squad / story VO as it plays: the mean integrated loudness of the baked lines (audio_manifest.json, measured
    by gen_vo.py) + the VO volume trim (rules.json audio.squad_volume_db)."""
    man = json.load(open(os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json"), encoding="utf-8")).get("files", {})
    v = [float(r["lufs"]) for r in man.values() if "lufs" in r]
    mean = 10 * math.log10(sum(10 ** (x / 10) for x in v) / len(v)) if v else -17.0
    return mean + float(rules_audio.get("squad_volume_db", 0.0))


def check_map(map_key: str, sounds: dict, audio: dict, step: float, vo: float, limit: float, vo_margin: float, quiet: bool = False) -> tuple[int, list]:
    """One map: every zone bed (and the map-wide bed under it) against the footsteps and the VO. Returns (beds over,
    rows). A map with no ambience file (map00) has only the map-wide bed."""
    path = os.path.join(ROOT, "data", "gravelight", "ambience", map_key + ".json")
    amb = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {"zones": {}}
    music = audio.get("music", {})
    amb_map = music.get("ambient", {})
    full_id = next((k for k in amb_map if k.startswith(map_key)), "")
    storm_key = amb_map.get(full_id, "")
    trim = float((music.get("ambient_trim_db", {}) or {}).get(full_id, 0.0))   # T-162: the per-map trim of the map-wide bed
    storm = key_lufs(sounds, storm_key) + float(music.get("ambient_db", [-6.0, -2.0])[-1]) + trim if storm_key else float("-inf")
    rows: list = []
    over = 0
    if storm_key:
        ok = storm - step <= limit and vo - storm >= vo_margin
        over += 0 if ok else 1
        rows.append((map_key, "(map bed)", storm_key, storm, storm - step, vo - storm, storm, ok))
    for zone, z in amb.get("zones", {}).items():
        bed = key_lufs(sounds, str(z.get("bed", ""))) + float(z.get("db", 0.0))
        both = psum(bed, storm) if storm_key else bed
        ok = bed - step <= limit and both - step <= limit and vo - both >= vo_margin
        over += 0 if ok else 1
        rows.append((map_key, zone, str(z.get("bed", "")), bed, bed - step, vo - both, both, ok))
    return over, rows


def apply_trims(keys: list, sounds: dict, audio: dict, step: float, limit: float, margin: float) -> None:
    """--apply: per map, one uniform offset (dB, <= 0) so the loudest bed (the map-wide bed, or a zone bed with the map
    bed under it) lands `margin` dB inside the limit; the offset goes on the map-wide bed (audio.json
    music.ambient_trim_db, read by AudioDirector._ambient_db) and on every zone bed's "db" (data/gravelight/ambience/<map>.json),
    so the zone balance is kept. Idempotent: it measures with the trims already in the files."""
    import re
    music = audio.get("music", {})
    amb_map = music.get("ambient", {})
    trims = dict(music.get("ambient_trim_db", {}) or {})
    for k in keys:
        full_id = next((x for x in amb_map if x.startswith(k)), "")
        over, rows = check_map(k, sounds, audio, step, 0.0, limit, -99.0)
        worst = max(max(r[4], r[6] - step) for r in rows) if rows else limit
        d = min(0.0, (limit - margin) - worst)
        if d > -0.05:
            continue
        print(f"  trim {k}: {d:+.1f} dB (loudest {worst:+.1f} vs steps)")
        if full_id:
            trims[full_id] = round(float(trims.get(full_id, 0.0)) + d, 1)
        zp = os.path.join(ROOT, "data", "gravelight", "ambience", k + ".json")
        if os.path.exists(zp):
            txt = open(zp, encoding="utf-8", newline="").read()
            txt = re.sub(r'("bed":\s*"[^"]+",\s*"db":\s*)(-?[\d.]+)', lambda m: m.group(1) + ("%g" % round(float(m.group(2)) + d, 1)), txt)
            open(zp, "w", encoding="utf-8", newline="").write(txt)
    ap = os.path.join(ROOT, "data", "gravelight", "audio.json")
    txt = open(ap, encoding="utf-8", newline="").read()
    body = ", ".join('"%s": %g' % (k, v) for k, v in sorted(trims.items()))
    if '"ambient_trim_db"' in txt:
        txt = re.sub(r'"ambient_trim_db":\s*\{[^}]*\}', '"ambient_trim_db": {%s}' % body, txt)
    else:
        ins = chr(10) + '    "ambient_trim_db": {%s},' % body
        txt = re.sub(r'("ambient_db":\s*\[[^\]]*\],)', lambda m: m.group(1) + ins, txt, count=1)
    open(ap, "w", encoding="utf-8", newline="").write(txt)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    limit = -8.0
    vo_margin = 6.0
    for a in sys.argv[1:]:
        if a.startswith("--limit="):
            limit = float(a.split("=", 1)[1])
        elif a.startswith("--vo-margin="):
            vo_margin = float(a.split("=", 1)[1])
    apply = "--apply" in sys.argv
    keys = args or ["all"]
    if keys == ["all"]:
        keys = ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]
    audio = json.load(open(os.path.join(ROOT, "data", "gravelight", "audio.json"), encoding="utf-8"))
    sounds = audio["sounds"]
    rules = json.load(open(os.path.join(ROOT, "data", "gravelight", "vo", "rules.json"), encoding="utf-8")).get("audio", {})
    steps = [k for k in sounds if k.startswith("footstep_")]
    step = psum(*[key_lufs(sounds, k, True) for k in steps]) - 10 * math.log10(len(steps))
    vo = vo_level(rules)
    print(f"footsteps ({len(steps)} keys, loudest 400 ms): {step:6.1f} LUFS   VO (mean of the baked lines + trim): {vo:6.1f} LUFS")
    print(f"rule: every bed (alone and with the map bed under it) <= footsteps {limit:+.1f} dB, and VO >= bed {vo_margin:+.1f} dB")
    if apply:
        apply_trims(keys, sounds, audio, step, limit, 1.0)
        audio = json.load(open(os.path.join(ROOT, "data", "gravelight", "audio.json"), encoding="utf-8"))
    total = 0
    for k in keys:
        over, rows = check_map(k, sounds, audio, step, vo, limit, vo_margin)
        total += over
        print(f"== {k}")
        for (_m, zone, key, lufs, rel, vo_rel, both, ok) in rows:
            print(f"  {zone:14s} {key:26s} {lufs:6.1f} LUFS ({rel:+5.1f} vs steps)  with map bed {both:6.1f}  VO over it {vo_rel:+5.1f}  {'ok' if ok else 'OVER'}")
    print(f"RESULT: {'PASS' if total == 0 else 'FAIL'} ({total} beds over)")
    return total


if __name__ == "__main__":
    sys.exit(main())
