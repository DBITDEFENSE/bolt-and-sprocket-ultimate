#!/usr/bin/env python3
"""T-285: the trailer cutter. An edit is a list of segments; each is cut from a source clip (trim, speed, a grade),
scaled to 1920x1080 at 24 fps, optionally faded or flashed, and the segments are joined; the score
(tools/trailer/trailer_audio.py) is synthesized from the edit's cue list and muxed. Outputs H.264 + AAC at 1080p and
720p. Needs ffmpeg on PATH and numpy/scipy/PIL (the repo's tools/venv).

Segment keys: src (path) | card (png path), start, dur, speed (1.0), fade_in, fade_out (s, from/to black),
grade ("teaser" | "game" | none), zoom (end scale for a slow push, 1.0 none), flash (white frames at the head),
overlay (png over the footage), letterbox (2.35:1 bars).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess

FPS = 24
W, H = 1920, 1080

GRADES = {
    # the teaser: cold, crushed, a little desaturated, fine grain, a vignette (Higgsfield clips come in at 480p)
    "teaser": "eq=contrast=1.08:saturation=0.82:gamma=0.94,colorbalance=bs=0.05:ms=0.02:hs=-0.02,"
              "unsharp=5:5:0.6:5:5:0,noise=alls=7:allf=t,vignette=PI/4.6",
    # gameplay: the game's own picture with a light lift and punch
    "game": "eq=contrast=1.06:saturation=1.05:gamma=1.04,unsharp=5:5:0.5:5:5:0,vignette=PI/5.5",
}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("ffmpeg failed: %s\n%s" % (" ".join(cmd[:12]), r.stderr[-2000:]))
    return r


def probe_dur(path: str) -> float:
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path])
    return float(r.stdout.strip())


def render_segment(seg: dict, out: str):
    dur = float(seg["dur"])
    vf = []
    if "card" in seg:
        inp = ["-loop", "1", "-framerate", str(FPS), "-t", "%.3f" % dur, "-i", seg["card"]]
        vf.append("scale=%d:%d,format=yuv420p" % (W, H))
    else:
        speed = float(seg.get("speed", 1.0))
        src_len = dur * speed
        inp = ["-ss", "%.3f" % float(seg.get("start", 0.0)), "-t", "%.3f" % (src_len + 0.2), "-i", seg["src"]]
        vf.append("setpts=(PTS-STARTPTS)/%.4f" % speed)
        if speed < 0.999 and seg.get("blend", True):
            vf.append("minterpolate=fps=%d:mi_mode=blend" % FPS)
        vf.append("fps=%d" % FPS)
        vf.append("scale=%d:%d:flags=lanczos,setsar=1" % (W, H))
        z = float(seg.get("zoom", 1.0))
        if abs(z - 1.0) > 1e-3:
            n = int(round(dur * FPS))
            vf.append("zoompan=z='1+(%f-1)*on/%d':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=%dx%d:fps=%d" % (z, max(1, n), W, H, FPS))
        g = seg.get("grade")
        if g:
            vf.append(GRADES[g])
        vf.append("format=yuv420p")
    if seg.get("overlay"):
        pass   # applied below with a second input
    if seg.get("letterbox"):
        bar = int(round((H - W / 2.35) / 2))
        vf.append("drawbox=x=0:y=0:w=iw:h=%d:color=black:t=fill,drawbox=x=0:y=ih-%d:w=iw:h=%d:color=black:t=fill" % (bar, bar, bar))
    fi = float(seg.get("fade_in", 0.0))
    fo = float(seg.get("fade_out", 0.0))
    if fi > 0:
        vf.append("fade=t=in:st=0:d=%.3f" % fi)
    if fo > 0:
        vf.append("fade=t=out:st=%.3f:d=%.3f" % (max(0.0, dur - fo), fo))
    fl = int(seg.get("flash", 0))
    if fl > 0:
        vf.append("fade=t=in:st=0:d=%.3f:color=white" % (fl / FPS))
    chain = ",".join(vf)
    cmd = ["ffmpeg", "-y", "-v", "error"] + inp
    if seg.get("overlay"):
        cmd += ["-loop", "1", "-framerate", str(FPS), "-t", "%.3f" % dur, "-i", seg["overlay"]]
        ofi = float(seg.get("overlay_fade", 0.25))
        flt = "[0:v]%s[v0];[1:v]format=rgba,fade=t=in:st=0:d=%.2f:alpha=1,fade=t=out:st=%.2f:d=%.2f:alpha=1[ov];[v0][ov]overlay=0:0:format=auto,format=yuv420p[v]" % (
            chain, ofi, max(0.0, dur - ofi), ofi)
        cmd += ["-filter_complex", flt, "-map", "[v]"]
    else:
        cmd += ["-vf", chain]
    cmd += ["-frames:v", str(int(round(dur * FPS))), "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "14",
            "-pix_fmt", "yuv420p", "-r", str(FPS), out]
    run(cmd)


def build(edit: list, audio_wav: str, out_1080: str, out_720: str, work: str):
    os.makedirs(work, exist_ok=True)
    parts = []
    for i, seg in enumerate(edit):
        p = os.path.join(work, "seg_%03d.mp4" % i)
        render_segment(seg, p)
        parts.append(p)
    lst = os.path.join(work, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write("file '%s'\n" % p.replace("\\", "/"))
    silent = os.path.join(work, "joined.mp4")
    run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", silent])
    run(["ffmpeg", "-y", "-v", "error", "-i", silent, "-i", audio_wav, "-map", "0:v", "-map", "1:a", "-c:v", "libx264",
         "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-profile:v", "high", "-c:a", "aac", "-b:a", "256k",
         "-shortest", "-movflags", "+faststart", out_1080])
    run(["ffmpeg", "-y", "-v", "error", "-i", out_1080, "-vf", "scale=1280:720:flags=lanczos", "-c:v", "libx264",
         "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out_720])
    return probe_dur(out_1080)


def total(edit: list) -> float:
    return sum(float(s["dur"]) for s in edit)


def starts(edit: list) -> list:
    t = 0.0
    out = []
    for s in edit:
        out.append(t)
        t += float(s["dur"])
    return out


def sheet(video: str, out_png: str, every: float = 2.0, cols: int = 6):
    run(["ffmpeg", "-y", "-v", "error", "-i", video, "-vf", "fps=1/%g,scale=320:-2,tile=%dx%d" % (every, cols, 8),
         "-frames:v", "1", out_png])
