#!/usr/bin/env python3
"""Mouth cues for the voice lines (UPDATE 12 section 4, T-210). Run it as tools/mocap.sh lipsync:

    tools/mocap.sh lipsync              every line an in-engine cutscene speaks (the cutscene data, shots.json, the
                                        endings' scripts), from its ElevenLabs take
    tools/mocap.sh lipsync --all        every line with a take (the in-match lines too, with the faster phonetic recognizer)
    tools/mocap.sh lipsync --ids=A,B    just these
    options: --force (redo lines whose cue file is newer than the take), --amplitude (skip Rhubarb), --jobs=N

Rhubarb Lip Sync (Daniel S. Wolf, MIT; https://github.com/DanielSWolf/rhubarb-lip-sync) is fetched at run time into
the git-ignored tools/dl_rhubarb/ (the release zip is ~85 MB, so it is not committed) and run on the take's .ogg:
English lines with their text as the dialog (PocketSphinx), other languages with the phonetic recognizer. The
result goes to data/gravelight/vo/lipsync/<ID>.json: {"id", "duration" (the take's length), "source", "cues":
[[start, shape], ...]} with shapes A-H and X; gravelight/world/lipsync.gd reads it. If Rhubarb cannot be fetched or
fails on a line, that line's cues come from the take's loudness (X / B / C / D) and "source" says "amplitude".
"""
import argparse
import concurrent.futures
import glob
import io
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "data", "gravelight", "vo", "lipsync")
DL = os.path.join(ROOT, "tools", "dl_rhubarb")
VERSION = "1.14.0"
URL = "https://github.com/DanielSWolf/rhubarb-lip-sync/releases/download/v{v}/Rhubarb-Lip-Sync-{v}-{os}.zip"
SQUAD = ("DUT", "PEG", "DEA", "WRN")
SCRIPTS = ["gravelight/world/requiem_ending.gd", "gravelight/world/endings/*.gd", "gravelight/world/map04/london_window.gd"]


def log(msg):
    print("[lipsync] " + msg, flush=True)


# ------------------------------------------------------------------ the data

def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def vo_data():
    lines = load(os.path.join(ROOT, "data", "gravelight", "vo", "lines.json"))
    lines = lines.get("lines", lines)
    man = load(os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json")).get("files", {})
    return lines, man


def cutscene_ids(lines):
    """Every line an in-engine cutscene can speak."""
    ids = set()

    def shot_ids(shots):
        for s in shots:
            for k in ("vo", "vo2"):
                if s.get(k):
                    ids.add(s[k])
            for e in s.get("lines", []):
                ids.add(e[1])
            for e in s.get("squad_lines", []):
                for c in SQUAD:
                    ids.add("%s_%s" % (c, e[2]))
    for p in ("campaign.json", "cutscenes_lazarus.json"):
        d = load(os.path.join(ROOT, "data", "gravelight", p))
        for cut in d.get("cutscenes", {}).values():
            shot_ids(cut.get("shots", []))
    for sc in load(os.path.join(ROOT, "data", "gravelight", "mocap", "shots.json"))["scenes"]:
        for sh in sc["shots"]:
            for e in sh.get("lines", []):
                lid = e[1]
                if lid.startswith("<"):
                    for c in SQUAD:
                        ids.add(c + lid.split(">", 1)[1])
                else:
                    ids.add(lid)
    for pat in SCRIPTS:
        for f in glob.glob(os.path.join(ROOT, pat)):
            with open(f, "r", encoding="utf-8") as fh:
                src = fh.read()
            for m in re.finditer(r'"([A-Z]{2,4}_[A-Z0-9_]+?_\d\d)"', src):
                ids.add(m.group(1))
            for m in re.finditer(r'"%s(_[A-Z0-9_]+?_\d\d)"', src):
                for c in SQUAD:
                    ids.add(c + m.group(1))
    return sorted(i for i in ids if i in lines)


def audio_of(lid, man):
    row = man.get(lid, {})
    p = str(row.get("path", ""))
    if p.startswith("res://"):
        p = os.path.join(ROOT, p[len("res://"):])
    if p and os.path.exists(p):
        return p
    spk = lid.split("_", 1)[0].lower()
    for ext in ("ogg", "wav"):
        q = os.path.join(ROOT, "gravelight", "audio", "vo", spk, "%s.%s" % (lid, ext))
        if os.path.exists(q):
            return q
    return ""


def dialog_text(row):
    t = str(row.get("speech") or row.get("text") or "")
    t = re.sub(r"\[[^\]]*\]", " ", t)
    t = re.sub(r"\([^)]*\)", " ", t)
    t = t.replace("{", "").replace("}", "").replace("*", "")
    return re.sub(r"\s+", " ", t).strip()


def is_english(row):
    lang = str(row.get("lang", "")).lower()
    if lang and lang not in ("en", "en-gb", "en-us"):
        return False
    sp = str(row.get("speech", ""))
    return not re.search(r"[Ѐ-ӿ]", sp) and not re.search(r"[äöüß]", sp)


# ------------------------------------------------------------------ Rhubarb

def rhubarb_exe(fetch=True):
    names = ["rhubarb.exe", "rhubarb"]
    for n in names:
        for p in glob.glob(os.path.join(DL, "*", n)) + glob.glob(os.path.join(DL, n)):
            if os.path.isfile(p):
                return p
    w = shutil.which("rhubarb")
    if w:
        return w
    if not fetch:
        return ""
    osname = {"Windows": "Windows", "Linux": "Linux", "Darwin": "macOS"}.get(platform.system(), "")
    if not osname:
        return ""
    url = URL.format(v=VERSION, os=osname)
    log("fetching Rhubarb %s for %s from %s" % (VERSION, osname, url))
    try:
        os.makedirs(DL, exist_ok=True)
        with urllib.request.urlopen(url, timeout=120) as r:
            data = r.read()
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            z.extractall(DL)
        open(os.path.join(DL, ".gdignore"), "w").close()   # its test sounds and models are not the game's
    except Exception as e:  # offline, blocked, moved: the amplitude fallback takes over
        log("could not fetch Rhubarb (%s); the cues will come from the takes' loudness" % e)
        return ""
    exe = rhubarb_exe(fetch=False)
    if exe and not exe.endswith(".exe"):
        os.chmod(exe, 0o755)
    return exe


def run_rhubarb(exe, audio, text, english):
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "out.json")
        args = [exe, "-q", "-f", "json", "--extendedShapes", "GHX", "-o", out]
        if english and text:
            dp = os.path.join(td, "dialog.txt")
            with open(dp, "w", encoding="utf-8") as f:
                f.write(text)
            args += ["-r", "pocketSphinx", "-d", dp]
        else:
            args += ["-r", "phonetic"]
        args.append(audio)
        r = subprocess.run(args, capture_output=True, text=True, timeout=300)
        if r.returncode != 0 or not os.path.exists(out):
            raise RuntimeError((r.stderr or r.stdout or "rhubarb failed")[-300:])
        d = load(out)
    cues = [[round(float(c["start"]), 3), str(c["value"])] for c in d.get("mouthCues", [])]
    return cues, float(d.get("metadata", {}).get("duration", 0.0))


# ------------------------------------------------------------------ the loudness fallback

def audio_length(path):
    import soundfile as sf
    info = sf.info(path)
    return info.frames / float(info.samplerate)


def amplitude_cues(path):
    """Cues from loudness: a 20 ms RMS every 10 ms, scaled to the take's loud end, X / B / C / D by level."""
    import numpy as np
    import soundfile as sf
    x, sr = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    hop, win = int(sr * 0.01), int(sr * 0.02)
    n = max(1, (len(x) - win) // hop + 1)
    rms = np.array([np.sqrt(np.mean(x[i * hop:i * hop + win] ** 2)) for i in range(n)])
    ref = float(np.percentile(rms, 95)) or 1.0
    lv = rms / ref
    shapes = np.where(lv < 0.12, "X", np.where(lv < 0.35, "B", np.where(lv < 0.7, "C", "D")))
    cues = []
    for i, s in enumerate(shapes):
        t = round(i * 0.01, 3)
        if not cues or cues[-1][1] != s:
            cues.append([t, str(s)])
    merged = []   # no shape shorter than 50 ms: a flicker joins the one before
    for c in cues:
        if merged and c[0] - merged[-1][0] < 0.05:
            if len(merged) > 1 and merged[-2][1] == c[1]:
                merged.pop()
            else:
                merged[-1][1] = c[1]
            continue
        merged.append(c)
    return merged or [[0.0, "X"]], len(x) / float(sr)


# ------------------------------------------------------------------ one line

def make(lid, row, audio, exe, force=False, fast=False):
    out = os.path.join(OUT, lid + ".json")
    if not force and os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(audio):
        return "kept"
    length = audio_length(audio)
    src = "amplitude"
    try:
        if not exe:
            raise RuntimeError("no rhubarb")
        eng = is_english(row) and not fast
        cues, _ = run_rhubarb(exe, audio, dialog_text(row), eng)
        src = "rhubarb %s %s" % (VERSION, "pocketSphinx" if eng else "phonetic")
    except Exception as e:
        if exe:
            log("%s: Rhubarb failed (%s); loudness instead" % (lid, str(e).strip()[:120]))
        cues, _ = amplitude_cues(audio)
    cues = [c for c in cues if c[0] < length] or [[0.0, "X"]]
    d = {"id": lid, "duration": round(length, 3), "source": src, "cues": cues}
    os.makedirs(OUT, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, separators=(",", ":"))
    return src


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--ids", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--amplitude", action="store_true")
    ap.add_argument("--jobs", type=int, default=max(1, min(8, (os.cpu_count() or 2) - 1)))
    a = ap.parse_args(argv)
    lines, man = vo_data()
    if a.ids:
        ids = [i for i in a.ids.split(",") if i]
    elif a.all:
        ids = sorted(i for i in man if i in lines)
    else:
        ids = cutscene_ids(lines)
    exe = "" if a.amplitude else rhubarb_exe()
    # the cutscene lines get PocketSphinx with their text (closer, several seconds a line); the in-match lines of
    # --all the phonetic recognizer (about a second a line: 2,500 lines in minutes, not hours)
    close = set(cutscene_ids(lines))
    todo, no_audio = [], []
    for lid in ids:
        au = audio_of(lid, man)
        (todo if au else no_audio).append((lid, au))
    log("%d lines (%d with a take, %d without); Rhubarb: %s" % (len(ids), len(todo), len(no_audio), exe or "none (loudness fallback)"))
    counts = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = {ex.submit(make, lid, lines.get(lid, {}), au, exe, a.force, lid not in close): lid for lid, au in todo}
        for i, f in enumerate(concurrent.futures.as_completed(futs)):
            try:
                r = f.result()
            except Exception as e:
                r = "failed"
                log("%s failed: %s" % (futs[f], e))
            k = r.split(" ")[0] if r != "kept" else "kept"
            counts[k] = counts.get(k, 0) + 1
            if (i + 1) % 200 == 0:
                log("%d / %d" % (i + 1, len(todo)))
    log("done: %s; no take yet: %s" % (counts, ", ".join(l for l, _ in no_audio[:20]) + (" ..." if len(no_audio) > 20 else "")))
    return 0 if "failed" not in counts else 1


if __name__ == "__main__":
    sys.exit(main())
