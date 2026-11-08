#!/usr/bin/env python3
"""The archive-reel treatment (UPDATE 12 s3, DECISIONS T-209). Standard library only (ffmpeg / ffprobe on PATH, or
FFMPEG / FFPROBE in the environment); safe under `python -I`. Run from anywhere: paths are the repo's.

    python -I tools/cinema/archive_reel.py build   [--scene S] [--force] [--raw DIR] [--out DIR]
    python -I tools/cinema/archive_reel.py reel    --scene S [--out DIR] [--raw DIR] [--size WxH] [--web-size WxH]
    python -I tools/cinema/archive_reel.py shot    IN.mp4 OUT_DIR --scene S --n N [--bake] [--size WxH]
    python -I tools/cinema/archive_reel.py report  [--raw DIR] [--out DIR]
    python -I tools/cinema/archive_reel.py prompts [--check]

The owner's generated clips land in assets/user_supplied/cutscenes/<scene>/shot_NN.mp4 (also .mov / .webm / .mkv;
`shot_NN_gore.mp4` is an optional Gore-full variant). Data: data/gravelight/cinema_reels.json (the reel shots, their
spans of the in-engine timeline in data/gravelight/cutscenes_lazarus.json, the prompts, the native card lines, the
treatment values).

build    every raw clip -> assets/cutscene_reels/<scene>/shot_NN.ogv (1080p) + shot_NN_720.ogv (the web variant):
         conformed to its span (stretched up to max_stretch, then the last frame held with a slow push), graded to
         black-and-white or sepia by a luma histogram match to the scene's reference frame (its reference_shot clip,
         else a built-in archival target), cropped to the reel aspect with a slight vignette, pillarboxed. Video only:
         in the game the lines, beds and subtitles are the engine's, and the film damage (grain, scratches, dust,
         gate weave, flicker) is drawn live by the same CinemaFilm shader the in-engine stand-ins use, so a clip and a
         stand-in match and the web .ogv stays small. Incremental: build.json in each scene folder records the input
         hashes; SOURCE.txt and LICENSE.txt are copied from the clip folder (the licence gate). Run by
         tools/build_web.sh / tools/build_windows.sh before the export, so a dropped clip ships with no code change.
reel     the finished film of one scene: every shot (its clip with the damage baked in, else a still
         `standin_NN.png|jpg` with a slow push, else film leader), the title cards (Russian or German in Old Standard
         TT with the English in Special Elite), the baked VO lines, the sfx and the ambience beds mixed in, at the
         definition's own times -> build/reels/<scene>_reel.ogv (1080p) + <scene>_reel_720.ogv (Theora + Vorbis).
shot     one clip through the treatment (debugging); --bake adds the film damage.
report   the dry run: per scene, which shots have a clip, which are built and current, what is still a stand-in (in
         priority order), lines with no take (silence in the reel: the slot a later ElevenLabs bake fills).
prompts  writes docs/cutscenes/SHOT_PROMPTS.md from the data (--check: exit 1 when it is stale).

Deterministic: every random choice comes from random.Random(seed) with the seed from sha1("<scene>/shot_NN"), the
weave and flicker are integer-hash expressions of the frame number, the noise filter has a fixed seed, ffmpeg runs
single-threaded with -fflags +bitexact, -flags +bitexact, -map_metadata -1 and the ogg muxer's fixed serials, so the
same input renders to the same bytes (tools/cinema/test_archive_reel.py checks it on testsrc clips).
"""
import argparse
import hashlib
import json
import math
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REELS_JSON = os.path.join(ROOT, "data", "gravelight", "cinema_reels.json")
CUTS_JSON = os.path.join(ROOT, "data", "gravelight", "cutscenes_lazarus.json")
LINES_JSON = os.path.join(ROOT, "data", "gravelight", "vo", "lines.json")
AUDIO_JSON = os.path.join(ROOT, "data", "gravelight", "audio.json")
PROMPTS_MD = os.path.join(ROOT, "docs", "cutscenes", "SHOT_PROMPTS.md")
VO_DIR = os.path.join(ROOT, "gravelight", "audio", "vo")
FONTS = {
    "native": os.path.join(ROOT, "assets", "third_party", "google_fonts", "old-standard-tt", "OldStandard-Bold.ttf"),
    "native_it": os.path.join(ROOT, "assets", "third_party", "google_fonts", "old-standard-tt", "OldStandard-Italic.ttf"),
    "english": os.path.join(ROOT, "assets", "third_party", "google_fonts", "special-elite", "SpecialElite-Regular.ttf"),
}
RAW_EXT = (".mp4", ".mov", ".webm", ".mkv", ".m4v")
STILL_EXT = (".png", ".jpg", ".jpeg")
LEADER = "0x0c0b0a"
TOOL_VERSION = "1"   # bump to rebuild every clip when the treatment changes


# ================================================================== data

def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def reels():
    return load_json(REELS_JSON)


def res_path(res):
    if res.startswith("res://"):
        return os.path.join(ROOT, *res[len("res://"):].split("/"))
    return res


def raw_root(args=None):
    return os.path.abspath(args.raw) if args is not None and getattr(args, "raw", None) else res_path(reels()["raw_root"])


def out_root(args=None):
    return os.path.abspath(args.out) if args is not None and getattr(args, "out", None) else res_path(reels()["built_root"])


def treatment():
    t = dict(reels()["treatment"])
    # UPDATE 12 C2: the art bible's cinema_reel look (data/look/cinema_reel.json, written by s1) tunes the same knobs
    look = os.path.join(ROOT, "data", "look", "cinema_reel.json")
    if os.path.exists(look):
        lk = load_json(look)
        post = lk.get("post", {}) or {}
        for k in ("grain", "vignette"):
            if isinstance(post.get(k), (int, float)):
                t[k] = float(post[k]) if k == "vignette" else float(post[k]) * 1.5
        adj = lk.get("adjust", {}) or {}
        if isinstance(adj.get("contrast"), (int, float)):
            t["contrast"] = float(adj["contrast"])
    return t


def shot_name(n):
    return "shot_%02d" % int(n)


def seed_of(scene, n):
    return int(hashlib.sha1(("%s/%s" % (scene, shot_name(n))).encode("utf-8")).hexdigest()[:8], 16)


def sha1_file(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_raw(scene_dir, n, suffix=""):
    for ext in RAW_EXT:
        p = os.path.join(scene_dir, shot_name(n) + suffix + ext)
        if os.path.exists(p):
            return p
    return None


def find_still(scene_dir, n):
    for ext in STILL_EXT:
        p = os.path.join(scene_dir, "standin_%02d%s" % (int(n), ext))
        if os.path.exists(p):
            return p
    return None


def even(x):
    x = int(round(x))
    return x - (x % 2)


def picture_width(t, h):
    return even(h * float(t["aspect"]))


# ================================================================== ffmpeg

def ffmpeg():
    return os.environ.get("FFMPEG") or shutil.which("ffmpeg") or "ffmpeg"


def ffprobe():
    return os.environ.get("FFPROBE") or shutil.which("ffprobe") or "ffprobe"


_FF_MAJOR = None
_ENC = None
WIN_PATH = re.compile(r"^([A-Za-z]):[\\/]")


def win_to_wsl(p):
    m = WIN_PATH.match(p)
    if not m:
        return p
    return "/mnt/%s/%s" % (m.group(1).lower(), p[3:].replace("\\", "/"))


def _theora_ok(prefix):
    """Encodes a tiny testsrc clip with `prefix` (an ffmpeg command) and decodes it with the local ffmpeg: True when
    the stream decodes cleanly. The Windows 64-bit ffmpeg builds' libtheora encoder writes streams every decoder
    rejects ("error in unpack_block_qpis"; ffmpeg trac #8040 / #8775), so on Windows the tool falls back to WSL's."""
    tmpd = tempfile.mkdtemp(prefix="theora_check_")
    try:
        out = os.path.join(tmpd, "t.ogv")
        wsl = prefix[0].lower().startswith("wsl")
        enc = subprocess.run(prefix + ["-v", "error", "-nostdin", "-y", "-f", "lavfi", "-i",
                                       "testsrc2=s=160x96:r=24:d=1", "-c:v", "libtheora", "-q:v", "6",
                                       win_to_wsl(out) if wsl else out], capture_output=True, text=True)
        if enc.returncode != 0 or not os.path.exists(out):
            return False
        dec = subprocess.run([ffmpeg(), "-v", "error", "-nostdin", "-i", out, "-f", "null", "-"], capture_output=True, text=True)
        return dec.returncode == 0 and dec.stderr.strip() == ""
    except OSError:
        return False
    finally:
        shutil.rmtree(tmpd, ignore_errors=True)


def encoder():
    """The ffmpeg command that renders and encodes (a list prefix), or None when no working Theora encoder exists.
    REEL_FFMPEG overrides it (e.g. "wsl -d Ubuntu-24.04 -e ffmpeg"); else the local ffmpeg when its Theora decodes;
    else on Windows the first WSL distro whose ffmpeg does."""
    global _ENC
    if _ENC is not None:
        return _ENC or None
    env = os.environ.get("REEL_FFMPEG", "").strip()
    cands = [env.split()] if env else [[ffmpeg()]]
    if not env and os.name == "nt" and shutil.which("wsl"):
        try:
            raw = subprocess.run(["wsl", "-l", "-q"], capture_output=True).stdout
            names = [n.strip() for n in raw.decode("utf-16-le", errors="ignore").replace("\x00", "").splitlines()]
            for n in names:
                if n and not n.lower().startswith("docker"):
                    cands.append(["wsl", "-d", n, "-e", "ffmpeg"])
        except OSError:
            pass
    for c in cands:
        if _theora_ok(c):
            _ENC = c
            return c
    _ENC = []
    return None


def encoder_name():
    e = encoder()
    return " ".join(e) if e else "none"


def ff_major():
    global _FF_MAJOR
    if _FF_MAJOR is None:
        e = encoder()
        if not e:
            _FF_MAJOR = 0
            return 0
        try:
            out = subprocess.run(e + ["-hide_banner", "-version"], capture_output=True, text=True).stdout
            m = re.search(r"version n?(\d+)", out)
            _FF_MAJOR = int(m.group(1)) if m else 6
        except OSError:
            _FF_MAJOR = 0
    return _FF_MAJOR


def have_ffmpeg():
    return ff_major() > 0


def duration_of(path):
    out = subprocess.run([ffprobe(), "-v", "error", "-show_entries", "format=duration", "-of",
                          "default=noprint_wrappers=1:nokey=1", path], capture_output=True, text=True)
    try:
        return float(out.stdout.strip())
    except ValueError:
        return 0.0


def run_ff(args, cwd, graph=None):
    """ffmpeg with the determinism flags; `graph` is a filter_complex written to a script file in cwd."""
    enc = encoder()
    if not enc:
        raise RuntimeError("no working Theora encoder (see encoder())")
    wsl = enc[0].lower().startswith("wsl")
    if wsl:
        args = [win_to_wsl(a) for a in args]
    cmd = enc + ["-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-filter_threads", "1",
                 "-filter_complex_threads", "1"]
    if graph is not None:
        gp = os.path.join(cwd, "graph.txt")
        with open(gp, "w", encoding="utf-8", newline="\n") as f:
            f.write(graph)
        cmd_graph = ["-/filter_complex", "graph.txt"] if ff_major() >= 7 else ["-filter_complex_script", "graph.txt"]
    else:
        cmd_graph = []
    # inputs first (args up to the first "--out"), then the graph, then the outputs
    i = args.index("--out") if "--out" in args else len(args)
    full = cmd + args[:i] + cmd_graph + args[i + 1:]
    r = subprocess.run(full, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("ffmpeg failed (%d): %s\n%s" % (r.returncode, " ".join(full), r.stderr[-3000:]))
    return r


def out_flags(audio):
    f = ["-map_metadata", "-1", "-map_chapters", "-1", "-fflags", "+bitexact", "-flags:v", "+bitexact", "-threads", "1"]
    if audio:
        f += ["-flags:a", "+bitexact"]
    return f


def theora(q=None, bitrate=None):
    a = ["-c:v", "libtheora", "-g", "48", "-pix_fmt", "yuv420p"]
    if bitrate:
        a += ["-b:v", str(bitrate)]
    else:
        a += ["-q:v", str(q if q is not None else 7)]
    return a


# ================================================================== the grade: luma histogram match

def luma_hist(path, frames=12, still=False):
    """A 256-bin luma histogram from up to `frames` frames spread over the clip (or the one still)."""
    if still:
        vf = "scale=320:180:flags=bilinear,format=gray"
        cmd = [ffmpeg(), "-v", "error", "-nostdin", "-i", path, "-vf", vf, "-frames:v", "1", "-f", "rawvideo", "-"]
    else:
        d = max(0.1, duration_of(path))
        rate = max(0.05, frames / d)
        vf = "fps=%.6f,scale=320:180:flags=bilinear,format=gray" % rate
        cmd = [ffmpeg(), "-v", "error", "-nostdin", "-threads", "1", "-i", path, "-vf", vf, "-frames:v", str(frames),
               "-f", "rawvideo", "-"]
    data = subprocess.run(cmd, capture_output=True).stdout
    if not data:
        return None
    return [data.count(bytes([i])) for i in range(256)]


def target_hist():
    """The built-in archival target (no reference clip yet): full-range but soft, most of the picture in the mids,
    real blacks thin, the top rolled off."""
    h = []
    for v in range(256):
        x = v / 255.0
        w = math.exp(-((x - 0.46) / 0.24) ** 2) + 0.35 * math.exp(-((x - 0.14) / 0.08) ** 2) + 0.12
        if x > 0.9:
            w *= max(0.0, (1.0 - x) / 0.1)
        h.append(w)
    return h


def cdf(h):
    s = float(sum(h)) or 1.0
    out, acc = [], 0.0
    for v in h:
        acc += v
        out.append(acc / s)
    return out


def match_lut(src, ref, t):
    """256 output levels (0..1): the source CDF mapped onto the reference CDF, blended with identity by
    match_strength, then the archival curve (contrast round the middle, lifted blacks, a gain under white)."""
    cs, cr = cdf(src), cdf(ref)
    k = float(t.get("match_strength", 0.85))
    lut = []
    j = 0
    for v in range(256):
        while j < 255 and cr[j] < cs[v]:
            j += 1
        m = (1.0 - k) * (v / 255.0) + k * (j / 255.0)
        c = (m - 0.5) * float(t.get("contrast", 1.1)) + 0.5
        c = min(1.0, max(0.0, c))
        lo, hi = float(t.get("lift", 0.05)), float(t.get("gain", 0.93))
        lut.append(lo + (hi - lo) * c)
    for i in range(1, 256):   # monotone (the CDF walk already is; rounding stays honest)
        if lut[i] < lut[i - 1]:
            lut[i] = lut[i - 1]
    return lut


def write_cube(lut, path):
    with open(path, "w", encoding="ascii", newline="\n") as f:
        f.write("TITLE \"archive_reel\"\nLUT_1D_SIZE 256\n")
        for v in lut:
            f.write("%.6f %.6f %.6f\n" % (v, v, v))


def reference_hist(scene, raw_dir):
    """The scene's reference frame: the middle frame of its reference_shot clip when that clip exists (every shot
    matches it, so the scene grades as one); else the built-in target. Returns (hist, tag for the build record)."""
    sc = reels()["scenes"][scene]
    p = find_raw(os.path.join(raw_dir, scene), int(sc.get("reference_shot", 1)))
    if p is not None:
        tmpd = tempfile.mkdtemp(prefix="reelref_")
        try:
            png = os.path.join(tmpd, "ref.png")
            d = duration_of(p)
            subprocess.run([ffmpeg(), "-v", "error", "-nostdin", "-y", "-ss", "%.3f" % (d * 0.5), "-i", p, "-frames:v", "1",
                            png], capture_output=True)
            h = luma_hist(png, still=True) if os.path.exists(png) else None
        finally:
            shutil.rmtree(tmpd, ignore_errors=True)
        if h is not None:
            return h, "ref:" + sha1_file(p)[:12]
    return target_hist(), "ref:builtin"


# ================================================================== the film damage (deterministic per shot)

def damage(seed, dur, t, w, h, fps):
    """drawbox filters for dust and scratches from random.Random(seed): the same shot always gets the same marks."""
    r = random.Random(seed)
    frames = max(1, int(round(dur * fps)))
    s = h / 1080.0
    out = []
    for _ in range(int(dur * 6.0 * float(t.get("dust", 0.5)))):
        f = r.randrange(frames)
        ln = r.choice((1, 1, 1, 2))
        size = max(1, int(round(r.choice((2, 3, 3, 4, 5, 6, 9)) * s)))
        x, y = r.randrange(w), r.randrange(h)
        col = "black@0.72" if r.random() < 0.72 else "white@0.55"
        out.append("drawbox=x=%d:y=%d:w=%d:h=%d:color=%s:t=fill:enable='between(n,%d,%d)'" % (x, y, size, size, col, f, f + ln - 1))
    for _ in range(int(dur * 0.9 * float(t.get("scratches", 0.35)))):
        f = r.randrange(frames)
        ln = r.randrange(5, 28)
        x = r.randrange(int(w * 0.04), int(w * 0.96))
        y0 = r.randrange(0, h // 3) if r.random() < 0.4 else 0
        col = "white@%.2f" % r.choice((0.22, 0.3, 0.38)) if r.random() < 0.8 else "black@0.35"
        out.append("drawbox=x=%d:y=%d:w=%d:h=%d:color=%s:t=fill:enable='between(n,%d,%d)'"
                   % (x, y0, max(1, int(round(r.choice((1, 1, 2)) * s))), h - y0, col, f, f + ln - 1))
    return out


def weave_flicker(seed, t, pw, h):
    """Gate weave (a pad and a per-frame crop) and flicker (eq brightness per frame), integer hashes of n."""
    s1, s2, s3, s4, s5, s6 = [(seed >> (i * 5)) % 9973 for i in range(6)]
    a = max(1, int(round(float(t.get("weave", 1.4)) * h / 1080.0)))
    p = 2 * a + 1
    xe = "%d+mod(n*7919+%d,%d)-%d+mod(trunc(n/12)*104729+%d,3)-1" % (p, s1, 2 * a + 1, a, s2)
    ye = "%d+mod(n*6271+%d,%d)-%d+mod(trunc(n/9)*130363+%d,3)-1" % (p, s3, 2 * a + 1, a, s4)
    fl = float(t.get("flicker", 0.045))
    be = "%.4f*(mod(n*7919+%d,9)-4)/4+%.4f*(mod(trunc(n/4)*104729+%d,5)-2)/2" % (fl * 0.6, s5, fl * 0.4, s6)
    return ["pad=w=iw+%d:h=ih+%d:x=%d:y=%d:color=black" % (2 * p, 2 * p, p, p),
            "crop=w=%d:h=%d:x='%s':y='%s'" % (pw, h, xe, ye),
            "eq=brightness='%s':eval=frame" % be]


def grain(seed, t):
    return "noise=c0s=%d:c0f=t:all_seed=%d" % (max(1, int(round(float(t.get("grain", 0.075)) * 240))), seed % 2147483647)


def tone_filters(tone, t):
    if tone == "sepia":
        r, g, b = t.get("tones", {}).get("sepia", [1.07, 0.98, 0.82])
        return ["format=rgb24", "colorchannelmixer=rr=%.4f:rg=0:rb=0:gr=0:gg=%.4f:gb=0:br=0:bg=0:bb=%.4f" % (r, g, b)]
    return []


def vignette(t):
    return "vignette=angle=%.4f" % (0.28 + float(t.get("vignette", 0.42)) * 0.55)


def conform(src_dur, span, t, w, h, fps):
    """Filters that make a clip exactly `span` seconds: trim when longer; else slow it (up to max_stretch) and hold
    the last frame with a slow push in (zoompan) for whatever is left."""
    out = []
    if src_dur <= 0.0:
        src_dur = span
    if src_dur >= span - 1e-3:
        out.append("trim=duration=%.4f" % span)
        out.append("setpts=PTS-STARTPTS")
        return out, 1.0, 0.0
    k = min(span / src_dur, float(t.get("max_stretch", 1.5)))
    out.append("setpts=%.6f*(PTS-STARTPTS)" % k)
    out.append("fps=%d" % fps)
    held = span - src_dur * k
    if held > 1.0 / fps:
        t0 = src_dur * k
        push = float(t.get("push", 0.05))
        out.append("tpad=stop_mode=clone:stop_duration=%.4f" % (held + 0.2))
        z = "if(gte(in_time,%.4f),1+%.5f*(in_time-%.4f)/%.4f,1)" % (t0, push, t0, max(0.1, held))
        out.append("zoompan=z='%s':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=%dx%d:fps=%d" % (z, w, h, fps))
    out.append("trim=duration=%.4f" % span)
    out.append("setpts=PTS-STARTPTS")
    return out, k, max(0.0, held)


def clip_chain(inp, label, src_dur, span, seed, lut_file, tone, t, w, h, fps, bake, still=False):
    """The whole treatment of one clip as one filter-graph chain from [inp] to [label] (W x H, yuv420p)."""
    pw = picture_width(t, h)
    f = []
    if still:
        push = float(t.get("push", 0.05)) * 1.6
        f.append("scale=%d:%d:force_original_aspect_ratio=increase:flags=bicubic" % (w, h))
        f.append("crop=%d:%d" % (w, h))
        f.append("loop=loop=-1:size=1:start=0")
        f.append("fps=%d" % fps)
        f.append("zoompan=z='1+%.5f*in_time/%.4f':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=%dx%d:fps=%d" % (push, span, w, h, fps))
        f.append("trim=duration=%.4f" % span)
        f.append("setpts=PTS-STARTPTS")
    else:
        f.append("fps=%d" % fps)
        f.append("scale=%d:%d:force_original_aspect_ratio=increase:flags=bicubic" % (w, h))
        f.append("crop=%d:%d" % (w, h))
        f.append("setsar=1")
        cf, _, _ = conform(src_dur, span, t, w, h, fps)
        f += cf
    f += ["format=gray", "format=rgb24", "lut1d=file=%s" % lut_file, "format=gray", "crop=%d:%d" % (pw, h)]
    if bake:
        f += weave_flicker(seed, t, pw, h)
        f.append(grain(seed, t))
    f += tone_filters(tone, t)
    if bake:
        f += damage(seed, span, t, pw, h, fps)
    f.append(vignette(t))
    f.append("pad=%d:%d:%d:0:black" % (w, h, (w - pw) // 2))
    f.append("format=yuv420p")
    f.append("setsar=1")
    return "[%s]%s[%s]" % (inp, ",".join(f), label)


# ================================================================== title cards

def card_texts(scene, shot_index, cut_shot):
    """(native lines, English lines) of a card shot: the native lines from cinema_reels.json, the English exactly the
    in-engine card's (title, subtitle, time)."""
    card = cut_shot.get("card", {}) or {}
    en = [str(card.get(k, "")) for k in ("title", "subtitle", "time")]
    en = [re.sub(r"\s+", " ", e).strip() for e in en if str(e).strip()]
    native = list(((reels()["scenes"][scene].get("cards", {}) or {}).get(str(shot_index), {}) or {}).get("native", []))
    return native, [e for e in en if e not in native]   # (a German title that reads the same in English is said once)


def card_chain(label, scene, shot_index, cut_shot, span, seed, t, w, h, fps, workdir, bake, tone):
    """A card on film leader: the native lines (title large, the rest italic), a rule, the English lines under it;
    in at the card's `at`, out after its `hold`, the film damage over all of it."""
    pw = picture_width(t, h)
    native, en = card_texts(scene, shot_index, cut_shot)
    card = cut_shot.get("card", {}) or {}
    a0 = float(card.get("at", 0.5))
    a1 = min(span - 0.1, a0 + float(card.get("hold", 4.0)))
    alpha = "if(lt(t,%.3f),0,if(lt(t,%.3f),(t-%.3f)/0.6,if(lt(t,%.3f),1,if(lt(t,%.3f),(%.3f-t)/0.7,0))))" % (
        a0, a0 + 0.6, a0, a1 - 0.7, a1, a1)
    s = h / 1080.0
    rows = []   # (text, font key, size, y, colour)
    y = 0.30 * h if len(native) > 1 else 0.40 * h
    for i, line in enumerate(native):
        size = int((86 if i == 0 else 38) * s)
        if i == 0 and len(line) > 22:
            size = int(size * 22 / len(line))
        rows.append((line, "native" if i == 0 else "native_it", size, y, "0xe8e0cc"))
        y += size * (1.35 if i == 0 else 1.45)
    y += 26 * s
    rule_y = y
    y += 30 * s
    for i, line in enumerate(en):
        size = int((30 if i == 0 else 25) * s)
        rows.append((line, "english", size, y, "0xa89f8c"))
        y += size * 1.5
    f = ["fps=%d" % fps, "format=gray"]
    if bake:
        f += weave_flicker(seed, t, pw, h)
    f.append("format=rgb24")
    for i, (text, fk, size, yy, col) in enumerate(rows):
        tf = "card_%d_%d.txt" % (shot_index, i)
        with open(os.path.join(workdir, tf), "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        f.append("drawtext=fontfile=%s:textfile=%s:fontsize=%d:fontcolor=%s:x=(w-text_w)/2:y=%d:alpha='%s'" % (
            os.path.basename(FONTS[fk]), tf, max(8, size), col, int(yy), alpha))
    f.append("drawbox=x=%d:y=%d:w=%d:h=%d:color=0x8a7f6a@0.8:t=fill:enable='between(t,%.3f,%.3f)'" % (
        int(pw * 0.38), int(rule_y), int(pw * 0.24), max(1, int(2 * s)), a0 + 0.3, a1 - 0.3))
    f.append("format=gray")
    if bake:
        f.append(grain(seed, t))
    f += tone_filters(tone, t)
    if bake:
        f += damage(seed, span, t, pw, h, fps)
    f += [vignette(t), "pad=%d:%d:%d:0:black" % (w, h, (w - pw) // 2), "format=yuv420p", "setsar=1"]
    return f


# ================================================================== one clip (the build step)

def treat_shot(src, out_base, scene, n, t, w, h, web_h, fps, lut_file, workdir, bake=False, span=None):
    """src -> out_base.ogv (W x H) and out_base_720.ogv (web), video only."""
    sc = reels()["scenes"][scene]
    shot = next(s for s in sc["shots"] if int(s["n"]) == int(n))
    span = float(span if span is not None else (shot["span"][1] - shot["span"][0]))
    d = duration_of(src)
    seed = seed_of(scene, n)
    ww = even(web_h * w / h)
    g = clip_chain("0:v", "v", d, span, seed, os.path.basename(lut_file), sc.get("tone", "bw"), t, w, h, fps, bake)
    g += ";[v]split=2[v1][v2];[v2]scale=%d:%d:flags=bicubic,format=yuv420p[vw]" % (ww, web_h)
    args = ["-threads", "1", "-i", src, "--out",
            "-map", "[v1]", "-an"] + theora(t.get("theora_q", 7)) + out_flags(False) + [out_base + ".ogv",
            "-map", "[vw]", "-an"] + theora(t.get("theora_q", 7)) + out_flags(False) + [out_base + "_720.ogv"]
    run_ff(args, workdir, g)


def prepare_workdir(lut=None):
    wd = tempfile.mkdtemp(prefix="archive_reel_")
    for p in FONTS.values():
        shutil.copy(p, os.path.join(wd, os.path.basename(p)))
    if lut is not None:
        write_cube(lut, os.path.join(wd, "lut.cube"))
    return wd


def scene_lut(scene, raw_dir, src, t):
    ref, tag = reference_hist(scene, raw_dir)
    hs = luma_hist(src) or ref
    return match_lut(hs, ref, t), tag


def build(args):
    if not have_ffmpeg():
        print("archive_reel: no working Theora encoder (ffmpeg on PATH, REEL_FFMPEG, or WSL's ffmpeg on Windows): nothing built; the reels keep their stand-ins")
        return 0
    t = treatment()
    w, h = parse_size(getattr(args, "size", None), (int(t["width"]), int(t["height"])))
    web_h = parse_size(getattr(args, "web_size", None), (0, int(t["web_height"])))[1]
    fps = int(t["fps"])
    rr, orr = raw_root(args), out_root(args)
    built = skipped = 0
    for scene, sc in reels()["scenes"].items():
        if args.scene and scene != args.scene:
            continue
        sdir = os.path.join(rr, scene)
        odir = os.path.join(orr, scene)
        record_path = os.path.join(odir, "build.json")
        record = load_json(record_path) if os.path.exists(record_path) else {}
        ref_tag = reference_hist(scene, rr)[1] if os.path.isdir(sdir) else "ref:builtin"
        changed = False
        for shot in sc["shots"]:
            for suffix in ("", "_gore"):
                src = find_raw(sdir, shot["n"], suffix) if os.path.isdir(sdir) else None
                if src is None:
                    continue
                key = shot_name(shot["n"]) + suffix
                stamp = hashlib.sha1(json.dumps([TOOL_VERSION, encoder_name(), sha1_file(src), ref_tag, t, w, h, web_h, shot["span"]],
                                                sort_keys=True).encode("utf-8")).hexdigest()
                outs = [os.path.join(odir, key + ".ogv"), os.path.join(odir, key + "_720.ogv")]
                if not args.force and record.get(key) == stamp and all(os.path.exists(o) for o in outs):
                    skipped += 1
                    continue
                os.makedirs(odir, exist_ok=True)
                lut, _ = scene_lut(scene, rr, src, t)
                wd = prepare_workdir(lut)
                try:
                    treat_shot(src, os.path.join(odir, key), scene, shot["n"], t, w, h, web_h, fps, os.path.join(wd, "lut.cube"), wd)
                finally:
                    shutil.rmtree(wd, ignore_errors=True)
                record[key] = stamp
                changed = True
                built += 1
                print("archive_reel: %s/%s built (%s)" % (scene, key, os.path.basename(src)))
        if changed or (os.path.isdir(odir) and os.path.isdir(sdir)):
            os.makedirs(odir, exist_ok=True)
            for paper in ("SOURCE.txt", "LICENSE.txt"):
                p = os.path.join(sdir, paper)
                if os.path.exists(p):
                    shutil.copy(p, os.path.join(odir, paper))
            with open(record_path, "w", encoding="utf-8", newline="\n") as f:
                json.dump(record, f, indent=1, sort_keys=True)
                f.write("\n")
    print("archive_reel: %d built, %d current" % (built, skipped))
    return 0


# ================================================================== the finished reel

def cut_def(scene):
    return load_json(CUTS_JSON)["cutscenes"][scene]


def segments(scene):
    """The reel's timeline in order: [(t0, t1, kind, ref)] covering 0..seconds; kind "shot" (ref = reel shot),
    "card" (ref = the in-engine card shot index), "leader" (black film)."""
    d = cut_def(scene)
    secs = float(d["seconds"])
    shots = d["shots"]
    starts = [float(s["t"]) for s in shots] + [secs]
    marks = []
    for s in reels()["scenes"][scene]["shots"]:
        marks.append((float(s["span"][0]), float(s["span"][1]), "shot", s))
    for i, s in enumerate(shots):
        if s.get("black"):
            marks.append((starts[i], starts[i + 1], "card" if isinstance(s.get("card"), dict) else "leader", i))
    marks.sort(key=lambda m: m[0])
    out = []
    t = 0.0
    for m in marks:
        if m[0] > t + 1e-3:
            out.append((t, m[0], "leader", None))
        if m[1] <= t + 1e-3:
            continue
        out.append((max(t, m[0]), m[1], m[2], m[3]))
        t = m[1]
    if t < secs - 1e-3:
        out.append((t, secs, "leader", None))
    return out


def sound_file(key, audio):
    e = (audio.get("sounds", {}) or {}).get(key)
    if not e:
        return None, 0.0
    for f in e.get("files", []):
        p = res_path(str(f))
        if os.path.exists(p):
            return p, float(e.get("volume_db", 0.0))
    return None, 0.0


def vo_file(line_id, lines):
    rec = lines.get(line_id)
    if not rec:
        return None
    for ext in ("ogg", "wav"):
        p = os.path.join(VO_DIR, str(rec["speaker"]).lower(), "%s.%s" % (line_id, ext))
        if os.path.exists(p):
            return p
    return None


def audio_events(scene):
    """[(t, path, db, kind, length or None)] and the line ids with no take."""
    d = cut_def(scene)
    secs = float(d["seconds"])
    lines = load_json(LINES_JSON)
    audio = load_json(AUDIO_JSON)
    ev, missing = [], []
    for s in d["shots"]:
        st = float(s["t"])
        ls = list(s.get("lines", []))
        for k, kt in (("vo", "vo_at"), ("vo2", "vo2_at")):
            if s.get(k):
                ls.append([float(s.get(kt, 0.5 if k == "vo" else 3.0)), s[k]])
        for lt, lid in ls:
            p = vo_file(str(lid), lines)
            if p:
                ev.append((st + float(lt), p, 0.0, "vo", None))
            else:
                missing.append(str(lid))
        for e in list(s.get("sfx", [])) + list(s.get("sfx_opt", [])):
            p, vdb = sound_file(str(e[1]), audio)
            if p:
                ev.append((st + float(e[0]), p, vdb + (float(e[2]) if len(e) > 2 else 0.0), "sfx", None))
        sg = s.get("stinger")
        if isinstance(sg, list) and len(sg) >= 2:
            p, vdb = sound_file(str(sg[1]), audio)
            if p:
                ev.append((st + float(sg[0]), p, vdb + (float(sg[2]) if len(sg) > 2 else -3.0), "sfx", None))
    for b in list(d.get("beds", [])) + list(d.get("beds_opt", [])):
        p, vdb = sound_file(str(b[1]), audio)
        if p:
            t0 = float(b[0])
            t1 = float(b[3]) if len(b) > 3 else secs
            ev.append((t0, p, vdb + (float(b[2]) if len(b) > 2 else -12.0), "bed", max(0.5, t1 - t0)))
    for nt, nid in reels()["scenes"][scene].get("narration", []):
        p = vo_file(str(nid), lines)
        if p:
            ev.append((float(nt), p, 0.0, "vo", None))
        else:
            missing.append(str(nid))
    ev.sort(key=lambda e: (e[0], e[1]))
    return ev, missing


def parse_size(s, fallback):
    if not s:
        return fallback
    m = re.match(r"^(\d+)x(\d+)$", s)
    return (int(m.group(1)), int(m.group(2))) if m else fallback


def make_reel(args):
    if not have_ffmpeg():
        print("archive_reel: no working Theora encoder (ffmpeg on PATH, REEL_FFMPEG, or WSL's ffmpeg on Windows)")
        return 1
    scene = args.scene
    t = treatment()
    w, h = parse_size(args.size, (int(t["width"]), int(t["height"])))
    web_w, web_h = parse_size(args.web_size, (even(int(t["web_height"]) * w / h), int(t["web_height"])))
    fps = int(t["fps"])
    sc = reels()["scenes"][scene]
    d = cut_def(scene)
    secs = float(d["seconds"])
    rr = raw_root(args)
    sdir = os.path.join(rr, scene)
    out_dir = os.path.abspath(args.out) if args.out else os.path.join(ROOT, "build", "reels")
    os.makedirs(out_dir, exist_ok=True)
    ref, _ = reference_hist(scene, rr)
    wd = prepare_workdir()
    try:
        inputs, chains, labels = [], [], []
        pw = picture_width(t, h)
        for i, (t0, t1, kind, ref_obj) in enumerate(segments(scene)):
            span = t1 - t0
            label = "s%d" % i
            if kind == "shot":
                n = int(ref_obj["n"])
                src = find_raw(sdir, n, "_gore") if (args.gore and find_raw(sdir, n, "_gore")) else find_raw(sdir, n)
                still = None if src else find_still(sdir, n)
                if src or still:
                    p = src or still
                    lutf = "lut_%d.cube" % i
                    write_cube(match_lut(luma_hist(p, still=bool(still)) or ref, ref, t), os.path.join(wd, lutf))
                    inputs += ["-threads", "1", "-i", p]
                    chains.append(clip_chain("%d:v" % _input_count(inputs, -1), label, duration_of(p) if src else span,
                                             span, seed_of(scene, n), lutf, sc.get("tone", "bw"), t, w, h, fps, True,
                                             still=bool(still)))
                    labels.append(label)
                    continue
                seed = seed_of(scene, n)
            else:
                seed = seed_of(scene, 900 + (ref_obj if isinstance(ref_obj, int) else i))
            inputs += ["-f", "lavfi", "-i", "color=c=%s:s=%dx%d:r=%d:d=%.4f" % (LEADER, pw, h, fps, span)]
            idx = _input_count(inputs, -1)
            if kind == "card":
                f = card_chain(label, scene, ref_obj, d["shots"][ref_obj], span, seed, t, w, h, fps, wd, True, sc.get("tone", "bw"))
            else:
                f = ["fps=%d" % fps, "format=gray"] + weave_flicker(seed, t, pw, h) + [grain(seed, t)] + tone_filters(sc.get("tone", "bw"), t) \
                    + damage(seed, span, t, pw, h, fps) + [vignette(t), "pad=%d:%d:%d:0:black" % (w, h, (w - pw) // 2), "format=yuv420p", "setsar=1"]
            chains.append("[%d:v]%s[%s]" % (idx, ",".join(f), label))
            labels.append(label)
        ev, missing = audio_events(scene)
        alabels = []
        for k, (at, p, db, kind, length) in enumerate(ev):
            inputs += ["-i", p]
            idx = _input_count(inputs, -1)
            ms = int(round(at * 1000))
            f = ["aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo"]
            if kind == "bed":
                f += ["aloop=loop=-1:size=2000000000", "atrim=end=%.4f" % length, "asetpts=PTS-STARTPTS",
                      "afade=t=in:st=0:d=2", "afade=t=out:st=%.4f:d=1.5" % max(0.0, length - 1.5)]
            f += ["volume=%.2fdB" % db, "adelay=delays=%d:all=1" % ms]
            chains.append("[%d:a]%s[a%d]" % (idx, ",".join(f), k))
            alabels.append("[a%d]" % k)
        if not alabels:
            inputs += ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"]
            alabels.append("[%d:a]" % _input_count(inputs, -1))
        g = ";".join(chains)
        g += ";" + "".join("[%s]" % l for l in labels) + "concat=n=%d:v=1:a=0[vc]" % len(labels)
        g += ";[vc]split=2[v1][v2];[v2]scale=%d:%d:flags=bicubic,format=yuv420p[vw]" % (web_w, web_h)
        g += ";" + "".join(alabels) + "amix=inputs=%d:normalize=0:dropout_transition=0:duration=longest,atrim=end=%.4f,apad=whole_dur=%.4f,alimiter=limit=0.95,asplit=2[ao1][ao2]" % (len(alabels), secs, secs)
        base = os.path.join(out_dir, scene + "_reel")
        args_ff = inputs + ["--out",
                            "-map", "[v1]", "-map", "[ao1]"] + theora(bitrate=t.get("reel_bitrate", "8M") if w >= 1280 else None) + \
                  ["-c:a", "libvorbis", "-q:a", str(t.get("vorbis_q", 4)), "-t", "%.4f" % secs] + out_flags(True) + [base + ".ogv",
                   "-map", "[vw]", "-map", "[ao2]"] + theora(bitrate=t.get("reel_bitrate_web", "3M") if web_w >= 1280 else None) + \
                  ["-c:a", "libvorbis", "-q:a", str(t.get("vorbis_q", 4)), "-t", "%.4f" % secs] + out_flags(True) + [base + "_720.ogv"]
        run_ff(args_ff, wd, g)
        print("archive_reel: %s -> %s.ogv + _720.ogv (%.1f s, %d segments, %d sounds%s)" % (
            scene, os.path.relpath(base, ROOT) if base.startswith(ROOT) else base, secs, len(labels), len(ev),
            ", no take yet: " + ", ".join(missing) if missing else ""))
    finally:
        shutil.rmtree(wd, ignore_errors=True)
    return 0


def _input_count(inputs, offset=0):
    """The index of the last input (offset -1) or the number of inputs so far."""
    n = sum(1 for a in inputs if a == "-i")
    return n + offset


def one_shot(args):
    t = treatment()
    w, h = parse_size(args.size, (int(t["width"]), int(t["height"])))
    web_h = parse_size(args.web_size, (0, int(t["web_height"])))[1]
    lut, _ = scene_lut(args.scene, raw_root(args), args.input, t)
    wd = prepare_workdir(lut)
    try:
        os.makedirs(args.out_dir, exist_ok=True)
        treat_shot(os.path.abspath(args.input), os.path.join(os.path.abspath(args.out_dir), shot_name(args.n)), args.scene, args.n,
                   t, w, h, web_h, int(t["fps"]), os.path.join(wd, "lut.cube"), wd, bake=args.bake)
    finally:
        shutil.rmtree(wd, ignore_errors=True)
    print("archive_reel: %s -> %s" % (args.input, os.path.join(args.out_dir, shot_name(args.n) + ".ogv")))
    return 0


# ================================================================== the dry run

def report(args):
    rr, orr = raw_root(args), out_root(args)
    total = have = 0
    for scene, sc in reels()["scenes"].items():
        sdir, odir = os.path.join(rr, scene), os.path.join(orr, scene)
        rows = []
        for s in sorted(sc["shots"], key=lambda x: int(x["priority"])):
            total += 1
            raw = find_raw(sdir, s["n"]) if os.path.isdir(sdir) else None
            built = os.path.exists(os.path.join(odir, shot_name(s["n"]) + ".ogv"))
            have += 1 if built else 0
            state = "built" if built else ("clip waiting for build" if raw else "STAND-IN (in-engine)")
            rows.append("  p%-2d %s  %4.1f s  %s" % (int(s["priority"]), shot_name(s["n"]), s["span"][1] - s["span"][0], state))
        _, missing = audio_events(scene)
        print("%s (%d reel shots): %d built" % (scene, len(sc["shots"]), sum(1 for r in rows if r.endswith("built"))))
        print("\n".join(rows))
        if missing:
            print("  lines with no take (silence in the reel; a later ElevenLabs bake fills them): " + ", ".join(missing))
        papers = [p for p in ("SOURCE.txt", "LICENSE.txt") if not os.path.exists(os.path.join(sdir, p))]
        if papers:
            print("  clip folder lacks " + ", ".join(papers))
    print("reels: %d of %d shots built; the rest play as in-engine stand-ins through the film treatment" % (have, total))
    return 0


# ================================================================== SHOT_PROMPTS.md

def full_prompt(sh, data=None):
    data = data or reels()
    return "%s. %s %s" % (data["style_block"], sh["prompt"].strip(), data["closing"])


def render_prompts():
    data = reels()
    cuts = load_json(CUTS_JSON)["cutscenes"]
    out = ["# SHOT_PROMPTS: the archive-reel shots (UPDATE 12 §3, DECISIONS T-209)", "",
           "Generated by `python -I tools/cinema/archive_reel.py prompts` from `data/gravelight/cinema_reels.json`; edit "
           "the JSON, not this file (`--check` fails when it is stale).", "",
           "**How to use it.** Generate the shots in the order below (priority 1 first) with Higgsfield in the Claude app. "
           "Paste each prompt as it is: it starts with the style block every shot shares. Ask for the duration given "
           "(any length from 4 to 10 s works: the treatment trims a longer clip and slows or holds a shorter one to fit "
           "its span). Save each clip as `assets/user_supplied/cutscenes/<scene>/shot_NN.mp4` (the file name in the "
           "table); `assets/user_supplied/cutscenes/README.md` says the rest. Until a clip exists the game plays that "
           "span in-engine through the same film treatment, so any subset works.", "",
           "**Rules for every clip (UPDATE 12 §3, UPDATE 11 §8 respect review).** No on-screen violence (the camera is "
           "elsewhere when anyone is hurt; nobody is struck, shot or bleeding in frame). No real people, and no faces "
           "made to resemble anyone real. No text in frame: no signs, lettering, numbers, insignia, emblems or logos "
           "(our title cards and subtitles carry every word). No political or Nazi symbol of any kind: the armbands are "
           "plain cloth, the caps carry nothing readable, the German plant has no eagles, flags or runes. Faith with "
           "respect: the church, the lamp and the priest are shot the way a church is shot; no icons close up. The "
           "priest is never harmed, never a villain and never a zombie on screen. Soldiers on both sides are people; "
           "the risen are walking men, never monsters. A clip that breaks a rule is not used.", "",
           "Style block (the start of every prompt): *%s*" % data["style_block"], "",
           "Each reel shot replaces a span of the in-engine cutscene (`data/gravelight/cutscenes_lazarus.json`); "
           "**replaces** lists those in-engine shot ids (`<scene>:<index>`, the index in that file's `shots`). The "
           "black card shots stay ours: their cards are drawn by the game and by the reel tool in Russian or German "
           "with the English under it.", ""]
    for scene, sc in data["scenes"].items():
        d = cuts[scene]
        n = len(sc["shots"])
        out.append("## %s (`%s`, %s): %d shots, %.0f s" % (sc["title"], scene, sc["year"], n, float(d["seconds"])))
        out.append("")
        out.append("Tone: %s. Folder: `assets/user_supplied/cutscenes/%s/`. Reference frame for the grade: shot %02d "
                   "(generate it first)." % ("sepia" if sc.get("tone") == "sepia" else "black-and-white", scene, int(sc.get("reference_shot", 1))))
        out.append("")
        out.append("| priority | file | span (s) | duration | replaces | must show |")
        out.append("|---|---|---|---|---|---|")
        order = sorted(sc["shots"], key=lambda x: int(x["priority"]))
        for s in order:
            rep = ", ".join("`%s:%02d`" % (scene, int(i)) for i in s["replaces"])
            gore = " *(Gore-safe; an optional `%s_gore.mp4` is used only with Gore full)*" % shot_name(s["n"]) if s.get("gore_gated") else ""
            out.append("| %d | `%s.mp4` | %.1f–%.1f | %d s | %s | %s%s |" % (
                int(s["priority"]), shot_name(s["n"]), s["span"][0], s["span"][1], int(s["seconds"]), rep,
                s["must_show"].replace("|", "/"), gore))
        out.append("")
        for s in order:
            out.append("### %s · %s (priority %d, %d s)" % (scene, shot_name(s["n"]), int(s["priority"]), int(s["seconds"])))
            out.append("")
            out.append("```text")
            out.append(full_prompt(s, data))
            out.append("```")
            out.append("")
        cards = sc.get("cards", {})
        if cards:
            out.append("Cards in this scene (ours, never generated):")
            out.append("")
            for k in sorted(cards.keys(), key=int):
                native, en = card_texts(scene, int(k), d["shots"][int(k)])
                out.append("- `%s:%02d`: %s — *%s*" % (scene, int(k), " / ".join(native), " / ".join(en)))
            out.append("")
    total = sum(len(sc["shots"]) for sc in data["scenes"].values())
    out.append("%d shots in all." % total)
    return "\n".join(out) + "\n"


def prompts(args):
    text = render_prompts()
    old = open(PROMPTS_MD, "r", encoding="utf-8").read() if os.path.exists(PROMPTS_MD) else ""
    if args.check:
        if old != text:
            print("STALE: docs/cutscenes/SHOT_PROMPTS.md (run: python -I tools/cinema/archive_reel.py prompts)")
            return 1
        print("SHOT_PROMPTS.md current")
        return 0
    os.makedirs(os.path.dirname(PROMPTS_MD), exist_ok=True)
    with open(PROMPTS_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote docs/cutscenes/SHOT_PROMPTS.md" + (" (no change)" if old == text else ""))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--scene")
    b.add_argument("--force", action="store_true")
    b.add_argument("--raw")
    b.add_argument("--out")
    b.add_argument("--size")
    b.add_argument("--web-size", dest="web_size")
    r = sub.add_parser("reel")
    r.add_argument("--scene", required=True)
    r.add_argument("--raw")
    r.add_argument("--out")
    r.add_argument("--size")
    r.add_argument("--web-size", dest="web_size")
    r.add_argument("--gore", action="store_true", help="use shot_NN_gore clips where they exist")
    s = sub.add_parser("shot")
    s.add_argument("input")
    s.add_argument("out_dir")
    s.add_argument("--scene", required=True)
    s.add_argument("--n", type=int, required=True)
    s.add_argument("--bake", action="store_true")
    s.add_argument("--raw")
    s.add_argument("--size")
    s.add_argument("--web-size", dest="web_size")
    p = sub.add_parser("report")
    p.add_argument("--raw")
    p.add_argument("--out")
    q = sub.add_parser("prompts")
    q.add_argument("--check", action="store_true")
    a = ap.parse_args(argv)
    return {"build": build, "reel": make_reel, "shot": one_shot, "report": report, "prompts": prompts}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
