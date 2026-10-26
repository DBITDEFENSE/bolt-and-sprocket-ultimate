"""The voice import pipeline (UPDATE 06 B5, T-101): recordings in voice_inbox/<actor>/ -> takes matched to line IDs
-> the best take cleaned up, put through the character's effect and written where the game plays it.

Steps (tools/voice/import.py runs them; every step is cached, so a rerun only does new work):
  1. normalize   ffmpeg: any input (wav, m4a, mp3, flac, stereo, 44.1 kHz) -> 48 kHz mono WAV in voice_work/<actor>/norm/
                 (named by the input's hash; the originals are never touched)
  2. transcribe  local Whisper (faster-whisper) with word timestamps, out of process (transcribe_worker.py) in
                 whichever Python has it: GRAVELIGHT_WHISPER_PY, then the owner's ~/whisper-env, then tools/venv
  3. match       spoken line IDs found in the transcript (fuzzy: "W-R-N down zero one" -> WRN_DOWN_01); the speech
                 after each ID is cut into takes at the pauses. No IDs in a file: each piece of speech is matched
                 against the actor's script text instead (thresholded; uncertain matches are flagged for review)
  4. score       each take: text match, clipping, noise floor, length sanity; every take is kept, the best is
                 'selected' unless data/voice/selections.json (the review page) picked another (or "tts")
  5. clean up    trim (80 ms pads), 80 Hz high-pass, gentle FFT de-noise, de-click, light compressor (ffmpeg), then
                 loudness to voice_cast.json's target (-17.5 LUFS, moved by the line's delivery like the TTS) and a
                 true-peak ceiling (-1.5 dBTP)
  6. effects     per character from data/voice/fx.json (Operator tannoy, Fasbender's field radio, phonograph
                 cylinders, the Cousins' room and trio, light robot treatments for B&S robots)
  7. output      OGG Vorbis at the path the game already plays (Gravelight gravelight/audio/vo/<spk>/<id>.ogg, the
                 TTS file kept in gravelight/audio/vo_tts/ to fall back to; B&S audio/vo/<id>.ogg) and the manifest row:
                 source human, actor, take, hash, duration (subtitles and lip flap use the audio's length)
Consent gate: nothing of an actor ships without voice_inbox/<actor>/consent.txt (voicelib.read_consent); a
withdrawn or missing consent puts their lines back to TTS on the next run.
"""
from __future__ import annotations

import contextlib
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field, asdict

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402

SR = 48000
AUDIO_EXT = (".wav", ".m4a", ".mp3", ".flac", ".ogg", ".aac", ".opus", ".aiff", ".aif", ".wma", ".webm", ".mp4", ".caf")
FRAME = 0.01                 # energy frame (s)
TAKE_GAP = 0.65              # a pause this long between reads splits takes
WORD_BREAK = 0.32            # a pause this long before a word lets an ID call start there
PAD = 0.08                   # trim pads
UNCERTAIN_TEXT = 0.72        # a take matching its script less than this is flagged
FALLBACK_MIN = 0.55          # no-ID mode: below this a piece is left unmatched
CLEANUP = ("highpass=f=80:poles=2,afftdn=nr=8:nf=-48:tn=1,adeclick=w=55:o=75,"
           "acompressor=threshold=-22dB:ratio=2.4:attack=8:release=160:makeup=1.6:knee=4")


# ───────────────────────────────────────────────────────────── tools

def ffmpeg() -> str:
    p = shutil.which("ffmpeg")
    if not p:
        raise SystemExit("ffmpeg not found on PATH (Windows: winget install Gyan.FFmpeg; Linux: apt install ffmpeg)")
    return p


def run_ffmpeg(args: list[str]) -> None:
    cp = subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", *args], capture_output=True, text=True)
    if cp.returncode != 0:
        raise RuntimeError("ffmpeg failed: %s" % cp.stderr[-800:])


def read_wav(path: str) -> np.ndarray:
    import soundfile as sf
    x, r = sf.read(path, dtype="float64", always_2d=False)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if r != SR:
        from scipy import signal
        x = signal.resample_poly(x, SR, r)
    return x


read_wav_any = read_wav     # soundfile reads wav / flac / ogg; normalize() handles everything else via ffmpeg


def write_wav(path: str, x: np.ndarray) -> None:
    import soundfile as sf
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, np.clip(x, -1.0, 1.0).astype(np.float32), SR, subtype="FLOAT")


def encode_ogg(wav: str, out: str, quality: float = 5.0) -> None:
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".part.ogg"
    run_ffmpeg(["-i", wav, "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", str(quality),
                "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", tmp])
    os.replace(tmp, out)


def _local_paths() -> dict:
    p = os.path.join(V.ROOT, "tools", "local_paths.env")
    out = {}
    if os.path.exists(p):
        for ln in open(p, encoding="utf-8"):
            if "=" in ln and not ln.lstrip().startswith("#"):
                k, v = ln.strip().split("=", 1)
                out[k.strip()] = v.strip().strip('"')
    return out


def _has_fw(py: str) -> bool:
    try:
        return subprocess.run([py, "-c", "import faster_whisper"], capture_output=True, timeout=120).returncode == 0
    except Exception:  # noqa: BLE001
        return False


def whisper_python() -> str | None:
    """A Python that can import faster_whisper: GRAVELIGHT_WHISPER_PY (env or tools/local_paths.env), the owner's
    existing ~/whisper-env, then tools/venv (cloud_setup.sh installs it there on Linux)."""
    cands = [os.environ.get("GRAVELIGHT_WHISPER_PY", ""), _local_paths().get("GRAVELIGHT_WHISPER_PY", "")]
    home = os.path.expanduser("~")
    for env in ("whisper-env", ".whisper-env", "whisper_env"):
        cands += [os.path.join(home, env, "Scripts", "python.exe"), os.path.join(home, env, "bin", "python")]
    cands.append(V.venv_python())
    for c in cands:
        if c and os.path.exists(c) and _has_fw(c):
            return c
    return None


def whisper_model() -> str:
    m = os.environ.get("GRAVELIGHT_WHISPER_MODEL", "") or _local_paths().get("GRAVELIGHT_WHISPER_MODEL", "")
    if m:
        return m
    hub = os.environ.get("HF_HUB_CACHE") or os.path.join(os.environ.get("HF_HOME", os.path.join(os.path.expanduser("~"), ".cache", "huggingface")), "hub")
    if os.path.isdir(os.path.join(hub, "models--Systran--faster-whisper-large-v3")):
        return "large-v3"            # already on this PC: no download, better than medium
    return "medium"


# ───────────────────────────────────────────────────────────── 1-2 normalize + transcribe

def normalize(src: str, work: str) -> tuple[str, str]:
    h = V.file_sha(src)[:16]
    out = os.path.join(work, "norm", h + ".wav")
    if not os.path.exists(out):
        os.makedirs(os.path.dirname(out), exist_ok=True)
        run_ffmpeg(["-i", src, "-vn", "-ac", "1", "-ar", str(SR), "-c:a", "pcm_s24le", out + ".part.wav"])
        os.replace(out + ".part.wav", out)
    return out, h


def transcribe(wavs: list[tuple[str, str]], work: str, model: str | None = None, prompt: str = "") -> dict[str, dict]:
    """wavs: [(norm wav, hash)] -> {hash: transcript}; cached per hash + model."""
    model = model or whisper_model()
    out: dict[str, dict] = {}
    jobs = []
    for wav, h in wavs:
        p = os.path.join(work, "transcripts", "%s.%s.json" % (h, model))
        if os.path.exists(p):
            out[h] = V.load_json(p)
        else:
            jobs.append({"wav": wav, "out": p, "h": h})
    if jobs:
        py = whisper_python()
        if py is None:
            raise SystemExit("no faster-whisper found: set GRAVELIGHT_WHISPER_PY to a Python that has it, or "
                             "tools/venv/<bin|Scripts>/python -m pip install faster-whisper")
        os.makedirs(os.path.join(work, "transcripts"), exist_ok=True)
        with tempfile.TemporaryDirectory() as td:
            jp = os.path.join(td, "jobs.json")
            with open(jp, "w", encoding="utf-8") as f:
                json.dump({"model": model, "device": os.environ.get("GRAVELIGHT_WHISPER_DEVICE", "auto"),
                           "prompt": prompt, "jobs": [{"wav": j["wav"], "out": j["out"]} for j in jobs]}, f)
            print("transcribing %d file(s) with Whisper %s ..." % (len(jobs), model), flush=True)
            cp = subprocess.run([py, "-I", os.path.join(V.HERE, "transcribe_worker.py"), jp], text=True)
            if cp.returncode != 0:
                raise SystemExit("whisper failed (exit %d)" % cp.returncode)
        for j in jobs:
            out[j["h"]] = V.load_json(j["out"])
    return out


# ───────────────────────────────────────────────────────────── 3 match

@dataclass
class Take:
    take: str            # "<file stem>@<start>"
    file_id: str
    actor: str
    src: str             # the original file (relative to the repo)
    norm: str            # normalized wav (absolute)
    start: float
    end: float
    transcript: str
    text_score: float
    id_score: float      # 0 = matched by text (no ID said)
    clip: float = 0.0
    floor_db: float = -90.0
    len_ratio: float = 1.0
    score: float = 0.0
    uncertain: bool = False
    why: str = ""
    preview: str = ""    # voice_work-relative preview ogg

    def to_json(self) -> dict:
        d = asdict(self)
        d["norm"] = os.path.relpath(self.norm, V.ROOT).replace(os.sep, "/")
        return d


def frame_db(x: np.ndarray) -> np.ndarray:
    n = int(SR * FRAME)
    m = len(x) // n
    if m == 0:
        return np.array([-120.0])
    fr = x[: m * n].reshape(m, n)
    return 10.0 * np.log10(np.mean(fr * fr, axis=1) + 1e-12)


def speech_regions(fdb: np.ndarray, floor: float, min_gap: float) -> list[tuple[float, float]]:
    """(start, end) seconds of speech: frames above floor + 12 dB (and above -50 dBFS), gaps shorter than min_gap
    bridged, blips under 60 ms dropped."""
    thr = max(floor + 12.0, -50.0)
    on = fdb > thr
    regs = []
    i = 0
    n = len(on)
    while i < n:
        if on[i]:
            j = i
            while j < n and on[j]:
                j += 1
            regs.append([i * FRAME, j * FRAME])
            i = j
        else:
            i += 1
    merged: list[list[float]] = []
    for r in regs:
        if merged and r[0] - merged[-1][1] < min_gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    return [(a, b) for a, b in merged if b - a >= 0.06]


def _words_in(words: list[dict], a: float, b: float) -> list[dict]:
    """Words overlapping [a, b] (Whisper's word times can be a few hundred ms early or late)."""
    return [w for w in words if w["e"] > a - 0.15 and w["s"] < b + 0.15 and
            min(w["e"], b + 0.15) - max(w["s"], a - 0.15) >= 0.4 * max(0.01, w["e"] - w["s"])]


def _clamp(s: float, e: float, ws: list[dict]) -> tuple[float, float]:
    """A take that starts long before its first word (the tail of the spoken ID, a long breath) or runs long after
    its last word starts 0.3 s before / ends 0.45 s after them."""
    if not ws:
        return s, e
    if ws[0]["s"] - s > 0.5:
        s = ws[0]["s"] - 0.3
    if e - ws[-1]["e"] > 0.8:
        e = ws[-1]["e"] + 0.45
    return s, e


def _text(ws: list[dict]) -> str:
    return " ".join(w["w"] for w in ws).strip()


def split_takes(words: list[dict], regions: list[tuple[float, float]], a: float, b: float, script: str) -> list[tuple[float, float, str, float]]:
    """The reads of one line between a and b: speech pieces split at pauses >= TAKE_GAP, neighbouring pieces merged
    while that improves the match with the script (a read with a pause inside stays one take)."""
    pieces = []
    for (s, e) in regions:
        s2, e2 = max(s, a), min(e, b)
        if e2 - s2 >= 0.08:
            pieces.append([s2, e2])
    # pauses inside a region shorter than TAKE_GAP were already bridged by speech_regions(min_gap=TAKE_GAP)
    takes = []
    i = 0
    while i < len(pieces):
        s, e = pieces[i]
        txt = _text(_words_in(words, s, e))
        sc = V.text_similarity(txt, script) if script else 0.0
        j = i + 1
        while j < len(pieces) and pieces[j][0] - e < 2.0:
            t2 = _text(_words_in(words, s, pieces[j][1]))
            s2 = V.text_similarity(t2, script) if script else 0.0
            if s2 > sc + 0.03:
                e, txt, sc = pieces[j][1], t2, s2
                j += 1
            else:
                break
        s, e = _clamp(s, e, _words_in(words, s, e))
        takes.append((s, e, txt, sc))
        i = j
    return takes


def analyse_file(actor: str, src: str, norm: str, tr: dict, lines: dict[str, V.Line]) -> tuple[list[Take], list[dict]]:
    """One recording -> takes (with line ids) and unmatched speech."""
    x = read_wav(norm)
    fdb = frame_db(x)
    floor = float(np.percentile(fdb, 8))
    regions = speech_regions(fdb, floor, TAKE_GAP)
    words = [w for w in tr.get("words", []) if w.get("w")]
    stem = os.path.splitext(os.path.basename(src))[0]
    rel = os.path.relpath(src, V.ROOT).replace(os.sep, "/")
    breaks = [True] + [words[i]["s"] - words[i - 1]["e"] >= WORD_BREAK for i in range(1, len(words))]
    hits = V.find_id_calls([w["w"] for w in words], list(lines.keys()), breaks=breaks)
    takes: list[Take] = []
    unmatched: list[dict] = []
    dur = len(x) / SR
    if hits:
        for k, h in enumerate(hits):
            a = words[h.end_word - 1]["e"] + 0.05
            b = words[hits[k + 1].start_word]["s"] - 0.05 if k + 1 < len(hits) else dur
            ln = lines[h.file_id]
            script = V.match_text(ln.text)
            for (s, e, txt, sc) in split_takes(words, regions, a, b, script):
                if ln.vocal_only:
                    sc = 1.0 if not txt else 0.8           # a hum / giggle: no words to compare
                takes.append(Take("%s@%.2f" % (stem, s), h.file_id, actor, rel, norm, s, e, txt, sc, round(h.score, 3)))
    else:
        # no IDs said: match each piece of speech against the actor's lines
        scripts = {fid: V.match_text(ln.text) for fid, ln in lines.items() if not ln.vocal_only}
        pieces = [(s, e, _text(_words_in(words, s, e))) for s, e in regions]
        i = 0
        while i < len(pieces):
            s, e, txt = pieces[i]
            if not txt:
                i += 1
                continue
            best, bsc = None, 0.0
            for fid, sc_txt in scripts.items():
                r = V.text_similarity(txt, sc_txt)
                if r > bsc:
                    best, bsc = fid, r
            j = i + 1
            while best and j < len(pieces) and pieces[j][0] - e < 1.5:
                t2 = _text(_words_in(words, s, pieces[j][1]))
                r2 = V.text_similarity(t2, scripts[best])
                if r2 > bsc + 0.03:
                    e, txt, bsc = pieces[j][1], t2, r2
                    j += 1
                else:
                    break
            if best and bsc >= FALLBACK_MIN:
                takes.append(Take("%s@%.2f" % (stem, s), best, actor, rel, norm, s, e, txt, bsc, 0.0))
            else:
                unmatched.append({"src": rel, "start": round(s, 2), "end": round(e, 2), "transcript": txt,
                                  "best": best or "", "score": round(bsc, 3)})
            i = j
    for t in takes:
        _quality(t, x, fdb, lines[t.file_id])
    return takes, unmatched


def _quality(t: Take, x: np.ndarray, fdb: np.ndarray, ln: V.Line) -> None:
    seg = x[int(t.start * SR): int(t.end * SR)]
    t.clip = float(np.mean(np.abs(seg) >= 0.995)) if len(seg) else 0.0
    a, b = int(max(0.0, t.start - 1.0) / FRAME), int((t.end + 1.0) / FRAME)
    around = fdb[a:b] if b > a else fdb
    t.floor_db = float(np.percentile(around, 5)) if len(around) else -90.0
    nwords = max(1, len(V.norm_words(V.match_text(ln.text))))
    expect = max(0.7, nwords * 0.36)
    t.len_ratio = round((t.end - t.start) / expect, 3)
    lr = t.len_ratio
    len_sc = 1.0 if 0.55 <= lr <= 1.9 else max(0.0, 1.0 - (0.55 - lr if lr < 0.55 else lr - 1.9))
    noise_sc = float(np.clip((-35.0 - t.floor_db) / 25.0, 0.0, 1.0))
    clip_sc = 1.0 - min(1.0, t.clip * 300.0)
    t.score = round(0.6 * t.text_score + 0.15 * clip_sc + 0.1 * noise_sc + 0.15 * len_sc, 4)
    why = []
    if t.text_score < UNCERTAIN_TEXT and not ln.vocal_only:
        why.append("text match %.0f%%" % (t.text_score * 100))
    if t.id_score == 0.0:
        why.append("no ID said (matched by text)")
    elif t.id_score < 0.9:
        why.append("ID heard as %.0f%%" % (t.id_score * 100))
    if t.clip > 0.001:
        why.append("clipping")
    t.uncertain = bool(why) and (t.text_score < UNCERTAIN_TEXT or t.id_score < 0.9)
    t.why = "; ".join(why)


def choose(takes: list[Take], selections: dict) -> dict[str, Take | None]:
    """file_id -> the selected take (None = the review page chose TTS)."""
    by: dict[str, list[Take]] = {}
    for t in takes:
        by.setdefault(t.file_id, []).append(t)
    out: dict[str, Take | None] = {}
    for fid, ts in by.items():
        sel = selections.get(fid)
        pick = sel.get("take") if isinstance(sel, dict) else sel
        if pick == "tts":
            out[fid] = None
            continue
        chosen = next((t for t in ts if t.take == pick), None) if pick else None
        if chosen is None:
            # best score; a later read wins a near tie (people get better as they go)
            top = max(t.score for t in ts)
            chosen = max((t for t in ts if t.score >= top - 0.02), key=lambda t: (t.src, t.start))
        out[fid] = chosen
    return out


# ───────────────────────────────────────────────────────────── 5-6 clean up + effects

@contextlib.contextmanager
def _genvo():
    sys.path.insert(0, os.path.join(V.ROOT, "gravelight", "tools_src"))
    import gen_vo as G   # the TTS bake's DSP helpers (filters, reverb, crackle, wow...), run at 48 kHz here
    old = G.SR
    G.SR = SR
    try:
        yield G
    finally:
        G.SR = old


def loudness_target(ln: V.Line) -> tuple[float, float]:
    vc = V.load_json(V.GL_VOICE_CAST)
    loud = vc.get("loudness", {})
    target = float(loud.get("target_lufs", -18.0))
    peak = float(loud.get("true_peak_db", -1.0))
    emo = vc.get("emotions", {}).get(ln.delivery, {})
    return target + float(emo.get("lufs", 0.0)), peak


def fx_for(fx: dict, ln: V.Line) -> tuple[str, dict]:
    ent = fx.get("characters", {}).get(ln.game, {}).get(ln.char, "clean")
    name = ent
    if isinstance(ent, dict):
        name = ent.get("chain", "clean")
        best = -1
        for pre, ch in (ent.get("by_category", {}) or {}).items():
            if ln.category.startswith(pre) and len(pre) > best:
                name, best = ch, len(pre)
    return str(name), dict(fx.get("chains", {}).get(name, {"kind": "clean"}))


def trim(x: np.ndarray) -> np.ndarray:
    fdb = frame_db(x)
    if len(fdb) < 3:
        return x
    floor = float(np.percentile(fdb, 10))
    thr = max(floor + 12.0, float(np.max(fdb)) - 45.0)
    on = np.nonzero(fdb > thr)[0]
    if len(on) == 0:
        return x
    a = max(0, int((on[0] * FRAME - PAD) * SR))
    b = min(len(x), int(((on[-1] + 1) * FRAME + PAD) * SR))
    y = x[a:b].copy()
    f = min(len(y) // 4, int(0.01 * SR))
    if f > 0:
        y[:f] *= np.linspace(0, 1, f)
        y[-f:] *= np.linspace(1, 0, f)
    return y


def tail_trim(x: np.ndarray, below_db: float = -58.0) -> np.ndarray:
    """Cuts an effect's reverb tail where it has decayed below `below_db` under the peak (20 ms fade)."""
    fdb = frame_db(x)
    on = np.nonzero(fdb > float(np.max(fdb)) + below_db)[0]
    if len(on) == 0:
        return x
    end = min(len(x), int((on[-1] + 1) * FRAME * SR))
    y = x[:end].copy()
    f = min(len(y) // 4, int(0.02 * SR))
    if f > 0:
        y[-f:] *= np.linspace(1, 0, f)
    return y


def cleanup(seg: np.ndarray, tmpdir: str) -> np.ndarray:
    a = os.path.join(tmpdir, "c_in.wav")
    b = os.path.join(tmpdir, "c_out.wav")
    write_wav(a, seg)
    run_ffmpeg(["-i", a, "-af", CLEANUP, "-ar", str(SR), "-ac", "1", "-c:a", "pcm_f32le", b])
    return read_wav(b)


def lufs(x: np.ndarray) -> float:
    sys.path.insert(0, os.path.join(V.ROOT, "gravelight", "tools_src"))
    import vo_loudness
    v = float(vo_loudness.integrated_lufs(x, SR))
    if not np.isfinite(v):
        rms = np.sqrt(np.mean(x * x) + 1e-12)
        v = 20 * np.log10(rms) - 0.7
    return v


def to_loudness(x: np.ndarray, target: float, peak_db: float) -> np.ndarray:
    with _genvo() as G:
        cur = lufs(x)
        y = x * (10.0 ** ((target - cur) / 20.0))
        return G.peak_limit(y, peak_db)


def _ring(x, hz, mix):
    t = np.arange(len(x)) / SR
    return x * (1.0 - mix) + x * np.sin(2 * np.pi * hz * t) * mix


def _comb(x, ms, mix):
    d = int(SR * ms / 1000.0)
    y = x.copy()
    y[d:] += x[:-d] * mix
    return y


def _pitch(G, x, semis):
    if not semis:
        return x
    f = 2.0 ** (semis / 12.0)
    from scipy import signal
    y = G.stretch(x, f)                          # longer by f, same pitch
    return signal.resample(y, int(len(y) / f))   # back to length: pitch up by f


def apply_fx(x: np.ndarray, chain: dict, seed: str, layers: list[np.ndarray] | None = None) -> np.ndarray:
    kind = chain.get("kind", "clean")
    if kind == "clean":
        return x
    with _genvo() as G:
        r = G.rng_for(seed)
        if kind == "radio_1930s":
            lo, hi = chain.get("band", [320, 3600])
            y = G.bandpass(x, lo, hi, 3)
            y = G.saturate(y, float(chain.get("drive", 2.2)))
            y = G.boost(y, 1800, 3200, 2.5)
            y = G.compress(y, -16.0, 3.0)
            y = G.reverb(y, float(chain.get("room_s", 0.6)), r, float(chain.get("room_mix", 0.22)), 18.0, 3500.0)
            y = G.wow(y, r, 0.7, float(chain.get("wow_depth", 0.0012)))
            y = G.flutter(y, r, 0.9, float(chain.get("flutter_depth", 0.04)))
            y = G.hiss(y, r, float(chain.get("hiss_db", -38)), 1200.0)
            y = G.crackle(y, r, float(chain.get("crackle_per_s", 5.0)), float(chain.get("crackle_db", -27)))
            return G.hum(y, 50.0, -48.0)
        if kind == "field_radio":
            lo, hi = chain.get("band", [420, 3000])
            y = G.bandpass(x, lo, hi, 4)
            y = G.saturate(y, float(chain.get("drive", 1.7)))
            y = G.lowpass(y, 2700, 2)
            y = G.compress(y, -18.0, 3.0)
            y = G.hiss(y, r, float(chain.get("hiss_db", -32)), 900.0, "white")
            y = G.crackle(y, r, float(chain.get("crackle_per_s", 3.0)), -28.0, 3000.0)
            y = G.flutter(y, r, 3.0, 0.06)
            if chain.get("static_bursts", True):
                y = G.static_burst(y, r, True, True, 160.0, -20.0)
            return y
        if kind == "phonograph":
            lo, hi = chain.get("band", [300, 4300])
            y = G.bandpass(x, lo, hi, 2)
            y = G.saturate(y, 1.3)
            y = G.wow(y, r, 0.55, float(chain.get("wow_depth", 0.0045)))
            y = G.wow(y, r, 6.5, 0.0008)
            y = G.lowpass(y, 4200, 2)
            y = G.compress(y, -18.0, 2.5)
            y = G.reverb(y, 0.25, r, 0.10, 8.0, 3000.0)
            y = G.hiss(y, r, float(chain.get("hiss_db", -29)), 1800.0, "white")
            y = G.crackle(y, r, float(chain.get("crackle_per_s", 11.0)), -22.0, 4500.0)
            return G.flutter(y, r, 1.3, 0.04)
        if kind == "pa":
            lo, hi = chain.get("band", [240, 5000])
            y = G.bandpass(x, lo, hi, 2)
            y = G.saturate(y, 1.4)
            y = G.compress(y, -18.0, 3.0)
            y = G.reverb(y, float(chain.get("room_s", 1.4)), r, float(chain.get("room_mix", 0.38)), 25.0, 3200.0)
            y = G.hum(y, 50.0, -44.0)
            return G.hiss(y, r, -42.0, 2000.0)
        if kind == "room":
            return G.reverb(x, float(chain.get("room_s", 1.1)), r, float(chain.get("room_mix", 0.16)),
                            float(chain.get("predelay_ms", 22)), float(chain.get("damp_hz", 3200)))
        if kind == "trio":
            voices = [x] + list(layers or [])
            if len(voices) == 1:
                # one voice: double it (two delayed, slightly detuned copies)
                dms = chain.get("double_ms", [17, 31])
                det = chain.get("detune_cents", [-9, 7])
                for k, (ms, c) in enumerate(zip(dms, det)):
                    v = _pitch(G, x, float(c) / 100.0) if c else x
                    d = int(SR * float(ms) / 1000.0)
                    voices.append(np.concatenate([np.zeros(d), v * 0.7]))
            n = max(len(v) for v in voices)
            y = np.zeros(n)
            for v in voices:
                y[: len(v)] += v
            y /= np.sqrt(len(voices))
            return G.reverb(y, float(chain.get("room_s", 1.2)), r, float(chain.get("room_mix", 0.2)), 22.0, 3200.0)
        if kind in ("robot", "robot_pa"):
            y = _pitch(G, x, float(chain.get("pitch_semitones", 0)))
            lo, hi = chain.get("band", [90, 9000])
            y = G.bandpass(y, lo, hi, 2)
            y = _ring(y, float(chain.get("ring_hz", 55)), float(chain.get("ring_mix", 0.16)))
            if chain.get("comb_ms"):
                y = _comb(y, float(chain["comb_ms"]), float(chain.get("comb_mix", 0.22)))
            if kind == "robot_pa":
                y = G.saturate(y, 1.3)
                y = G.reverb(y, float(chain.get("room_s", 0.9)), r, float(chain.get("room_mix", 0.25)), 20.0, 3500.0)
            return y
    return x


def render(t: Take, ln: V.Line, fx: dict, tmpdir: str, layers: list[np.ndarray] | None = None) -> tuple[np.ndarray, str, float]:
    """A selected take -> the finished line (cleanup, loudness, effect, true-peak). Returns (audio, fx name, LUFS)."""
    x = read_wav(t.norm)
    seg = x[max(0, int((t.start - 0.2) * SR)): min(len(x), int((t.end + 0.25) * SR))]
    y = trim(cleanup(seg, tmpdir))
    target, peak = loudness_target(ln)
    y = to_loudness(y, target, peak)
    name, chain = fx_for(fx, ln)
    if chain.get("kind", "clean") != "clean":
        y = tail_trim(apply_fx(y, chain, ln.file_id, layers))
        y = to_loudness(y, target, peak)
    return y, name, lufs(y)


def preview(t: Take, work: str, tmpdir: str) -> str:
    """A light preview of any take for the review page (trimmed, loudness-matched, no effect)."""
    rel = os.path.join("takes", t.file_id, V.slug(t.take) + ".ogg")
    out = os.path.join(work, rel)
    if not os.path.exists(out):
        x = read_wav(t.norm)
        seg = trim(x[max(0, int((t.start - 0.1) * SR)): int((t.end + 0.15) * SR)])
        y = to_loudness(seg, -18.0, -1.5)
        w = os.path.join(tmpdir, "pv.wav")
        write_wav(w, y)
        encode_ogg(w, out, 3.0)
    return os.path.relpath(out, V.ROOT).replace(os.sep, "/")


# ───────────────────────────────────────────────────────────── 7 ship (manifests)

def fx_signature(fx: dict, ln: V.Line) -> str:
    name, chain = fx_for(fx, ln)
    return V.sha16(json.dumps([name, chain, loudness_target(ln), CLEANUP], sort_keys=True))[:10]


def backup_tts(row: dict, ln: V.Line) -> dict:
    """Keeps the TTS file (gravelight/audio/vo_tts/<spk>/<id>.ogg; a .gdignore'd folder) before a human take
    replaces it, and returns the TTS row to restore later."""
    src = V.res_to_disk(ln.res_path)
    os.makedirs(V.tts_backup_dir(), exist_ok=True)
    gdi = os.path.join(V.tts_backup_dir(), ".gdignore")
    if not os.path.exists(gdi):
        open(gdi, "w").close()
    dst = os.path.join(V.tts_backup_dir(), ln.res_path.split("/")[-2], os.path.basename(src))
    if os.path.exists(src) and not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    keep = {k: v for k, v in row.items() if k != "tts"}
    keep["source"] = "tts"
    return keep


def restore_tts(game: str, files: dict, fid: str, ln_res: str) -> str:
    """Puts a line back to the computer voice. Returns what happened."""
    row = files.get(fid, {})
    disk = V.res_to_disk(row.get("path", ln_res)) if row.get("path") else V.res_to_disk(ln_res)
    if game == "bs":
        if os.path.exists(disk):
            os.remove(disk)
        files[fid] = {"line": row.get("line", fid), "speaker": row.get("speaker", ""), "source": "tts", "engine": "runtime_tts"}
        return "removed (runtime TTS)"
    tts = row.get("tts")
    bak = os.path.join(V.tts_backup_dir(), ln_res.split("/")[-2], ln_res.split("/")[-1])
    if tts and os.path.exists(bak):
        shutil.copy2(bak, disk)
        os.remove(bak)
        files[fid] = dict(tts, source="tts")
        return "TTS restored"
    if tts:
        files[fid] = dict(tts, source="tts", hash="stale-rebake")   # gen_vo.py rebuilds it (hash mismatch)
        return "TTS backup missing: run gravelight/tools_src/gen_vo.py to rebake"
    # a line that never had TTS (e.g. a Cousins boss line): no audio again
    if os.path.exists(disk):
        os.remove(disk)
    files.pop(fid, None)
    return "removed (no TTS for this line: subtitle only)"


def ensure_tts_rows(gl_files: dict, bs_files: dict, lines: list[V.Line]) -> None:
    for row in gl_files.values():
        row.setdefault("source", "tts")
    for ln in lines:
        if ln.game == "bs" and ln.file_id not in bs_files:
            bs_files[ln.file_id] = {"line": ln.line_id, "speaker": ln.char, "source": "tts", "engine": "runtime_tts"}
    ids = {ln.file_id for ln in lines if ln.game == "bs"}
    for fid in list(bs_files):
        if fid not in ids and bs_files[fid].get("source") == "tts":
            bs_files.pop(fid)


@dataclass
class RunResult:
    takes: list = field(default_factory=list)
    unmatched: list = field(default_factory=list)
    shipped: list = field(default_factory=list)
    reverted: list = field(default_factory=list)
    blocked: dict = field(default_factory=dict)       # actor -> why (no consent)
    files: dict = field(default_factory=dict)         # actor -> [input files]


def git_head() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=V.ROOT, capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:  # noqa: BLE001
        return ""


def run(actors: list[str] | None = None, inbox: str | None = None, work: str | None = None, dry: bool = False,
        model: str | None = None, transcripts: dict | None = None, ship: bool = True, log=print) -> RunResult:
    """The whole import. actors: only these (default: every folder in the inbox). transcripts: {input sha16: transcript}
    to skip Whisper (tests). ship=False analyses without touching the game."""
    inbox = inbox or V.INBOX_DIR
    work = work or V.WORK_DIR
    cast = V.load_cast()
    fx = V.load_json(V.FX_PATH)
    selections = V.load_json(V.SELECTIONS_PATH)
    all_lines = V.collect_all()
    by_actor = V.lines_by_actor(all_lines, cast)
    line_by_id = {ln.file_id: ln for ln in all_lines}
    res = RunResult()
    for d in (inbox, work):
        V.gdignore(d)
    folders = sorted(d for d in os.listdir(inbox) if os.path.isdir(os.path.join(inbox, d))) if os.path.isdir(inbox) else []
    if actors:
        folders = [f for f in folders if f in actors]
    consents: dict[str, V.Consent] = {}
    chosen: dict[str, Take] = {}
    for actor in folders:
        consents[actor] = V.read_consent(actor, inbox)
        srcs = sorted(p for p in glob.glob(os.path.join(inbox, actor, "**", "*"), recursive=True)
                      if os.path.isfile(p) and p.lower().endswith(AUDIO_EXT))
        res.files[actor] = [os.path.relpath(p, V.ROOT).replace(os.sep, "/") for p in srcs]
        if not srcs:
            continue
        mine = {ln.file_id: ln for ln in by_actor.get(actor, [])}
        if not mine:
            log("%s: no lines in data/voice/cast.json for this actor id: skipped" % actor)
            res.blocked[actor] = "not in the cast sheet"
            continue
        awork = os.path.join(work, actor)
        normed = [(src, *normalize(src, awork)) for src in srcs]
        if transcripts is not None:
            trs = {h: transcripts[h] for _, _, h in normed if h in transcripts}
            missing = [(w, h) for _, w, h in normed if h not in trs]
            if missing:
                trs.update(transcribe(missing, awork, model))
        else:
            trs = transcribe([(w, h) for _, w, h in normed], awork, model,
                             prompt="Line IDs are read aloud before each line, like D-U-T reload zero one.")
        takes = []
        for src, wav, h in normed:
            t, um = analyse_file(actor, src, wav, trs[h], mine)
            takes += t
            res.unmatched += [dict(u, actor=actor) for u in um]
        with tempfile.TemporaryDirectory() as td:
            for t in takes:
                t.preview = preview(t, work, td)
        res.takes += takes
        pick = choose(takes, selections)
        log("%s: %d file(s), %d takes for %d lines (%d uncertain), consent: %s" % (
            actor, len(srcs), len(takes), len(pick), sum(1 for t in takes if t.uncertain),
            consents[actor].date if consents[actor].ok else "MISSING (" + consents[actor].why + ")"))
        if not consents[actor].ok:
            res.blocked[actor] = consents[actor].why
            continue
        for fid, t in pick.items():
            if t is None:
                continue
            # the Cousins' trio lines collect one take per cousin (layered below); everything else has one actor
            chosen[fid + "#" + actor if line_by_id[fid].char == "CSN" else fid] = t
    if dry or not ship:
        _write_review_data(res, work, all_lines, cast, consents)
        return res

    gl_m, bs_m = V.load_manifest("gl"), V.load_manifest("bs")
    gl_files, bs_files = gl_m.setdefault("files", {}), bs_m.setdefault("files", {})
    ensure_tts_rows(gl_files, bs_files, all_lines)
    # CSN trio lines: every consenting cousin's take is layered into one file
    trio: dict[str, list[Take]] = {}
    for key in [k for k in chosen if "#" in k]:
        trio.setdefault(key.split("#")[0], []).append(chosen.pop(key))
    with tempfile.TemporaryDirectory() as td:
        for fid, t in list(chosen.items()) + [(f, ts[0]) for f, ts in trio.items()]:
            ln = line_by_id[fid]
            files = gl_files if ln.game == "gl" else bs_files
            cur = files.get(fid, {})
            others = trio.get(fid, [])[1:]
            take_id = "+".join(x.take for x in trio.get(fid, [t]))
            actor_id = "+".join(x.actor for x in trio.get(fid, [t]))
            sig = fx_signature(fx, ln)
            disk = V.res_to_disk(ln.res_path)
            if (cur.get("source") == "human" and cur.get("take") == take_id and cur.get("fx_sig") == sig
                    and cur.get("script_sha") == ln.script_sha and os.path.exists(disk)):
                continue
            layers = None
            if others:
                layers = [render(o, ln, {"characters": {}}, td)[0] for o in others]
            y, fxname, lv = render(t, ln, fx, td, layers)
            w = os.path.join(td, "final.wav")
            write_wav(w, y)
            if ln.game == "gl" and cur and cur.get("source", "tts") != "human":
                tts_row = backup_tts(cur, ln)
            else:
                tts_row = cur.get("tts")
            encode_ogg(w, disk)
            row = V.human_row(ln, actor_id, take_id, V.file_sha(disk), len(y) / SR, lv, fxname,
                              ",".join(consents[x.actor].date for x in trio.get(fid, [t])))
            row["fx_sig"] = sig
            if tts_row:
                row["tts"] = tts_row
            files[fid] = row
            res.shipped.append(fid)
            log("  shipped %-28s %-14s take %s (%.2f s, %s)" % (fid, actor_id, take_id, len(y) / SR, fxname))
    # back to TTS: consent gone, the review page chose TTS, or the take vanished from the inbox
    live = set(chosen) | set(trio)
    for game, files in (("gl", gl_files), ("bs", bs_files)):
        for fid, row in list(files.items()):
            if row.get("source") != "human":
                continue
            actors_of = row.get("actor", "").split("+")
            if actors and not any(a in actors for a in actors_of):
                continue
            sel = selections.get(fid)
            pick = sel.get("take") if isinstance(sel, dict) else sel
            gone = any(a in consents and not consents[a].ok for a in actors_of) or pick == "tts" or \
                (fid not in live and all(a in consents for a in actors_of))
            if not any(a in consents for a in actors_of) and os.path.isdir(inbox) and not any(os.path.isdir(os.path.join(inbox, a)) for a in actors_of):
                gone = True     # the actor's folder is gone: consent can't be shown any more
            if gone:
                ln_res = row.get("path", "")
                what = restore_tts(game, files, fid, ln_res)
                res.reverted.append(fid)
                log("  back to TTS %-24s %s" % (fid, what))
    V.save_manifest("gl", gl_m)
    V.save_manifest("bs", bs_m)
    if res.shipped:
        sess = V.load_json(V.SESSIONS_PATH)
        head = git_head()
        for f in res.shipped:
            for one in str((gl_files.get(f) or bs_files.get(f) or {}).get("actor", "")).split("+"):
                if one:
                    sess[one] = {"date": V.today(), "commit": head}
        V.save_json(V.SESSIONS_PATH, sess)
    _write_review_data(res, work, all_lines, cast, consents)
    return res


def _write_review_data(res: RunResult, work: str, lines: list[V.Line], cast: dict, consents: dict) -> None:
    gl, bs = V.load_manifest("gl").get("files", {}), V.load_manifest("bs").get("files", {})
    data = {"generated": V.today(), "takes": [t.to_json() for t in res.takes], "unmatched": res.unmatched,
            "blocked": res.blocked, "files": res.files,
            "consent": {a: {"ok": c.ok, "date": c.date, "ai_cloning": c.ai_cloning, "why": c.why} for a, c in consents.items()},
            "selections": V.load_json(V.SELECTIONS_PATH)}
    os.makedirs(work, exist_ok=True)
    V.save_json(os.path.join(work, "review_data.json"), data, sort=False)
