#!/usr/bin/env python3
"""T-285: cut the two trailers from the recorded / re-rendered shots and score them.
  tools/venv python tools/trailer/make_trailers.py teaser|gameplay|both
Inputs:  build/trailers/hf/<shot>.mp4 (the teaser's Higgsfield clips; the in-engine source stands in where one is
         missing), build/trailers/src/<run>/<shot>.mp4 (in-engine recordings, tools/trailer/record.sh).
Outputs: build/trailers/teaser_1080p.mp4, teaser_720p.mp4, gameplay_1080p.mp4, gameplay_720p.mp4, the scores as
         WAV, the cards, contact sheets."""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cards                                  # noqa: E402
import edit as E                              # noqa: E402
import trailer_audio as TA                    # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
B = os.path.join(ROOT, "build", "trailers")
HF = os.path.join(B, "hf")
SRC = os.path.join(B, "src")
CARDS = os.path.join(B, "cards")


def hf(shot: str) -> str:
    """The teaser clip for a shot: the accepted Higgsfield re-render (a redo wins: <shot>_v2.mp4), else the source."""
    for name in (shot + "_v3.mp4", shot + "_v2.mp4", shot + ".mp4"):
        p = os.path.join(HF, name)
        if os.path.exists(p):
            return p
    return os.path.join(SRC, "teaser_m0", shot + ".mp4")


def src(run: str, shot: str) -> str:
    return os.path.join(SRC, run, shot + ".mp4")


def make_cards():
    os.makedirs(CARDS, exist_ok=True)
    c = {}
    c["silesia"] = os.path.join(CARDS, "t_silesia.png")
    cards.text_card(c["silesia"], "SILESIA. WINTER, 1944.", 58)
    c["count"] = os.path.join(CARDS, "t_count.png")
    cards.text_card(c["count"], "THE DEAD ARE KEEPING COUNT.", 58)
    c["treeline"] = os.path.join(CARDS, "t_treeline.png")
    cards.text_card(c["treeline"], "SOMETHING AT THE TREELINE|HAS LEARNED YOUR NAME.", 58, bg=(0, 0, 0, 0), y=0.82)
    c["title"] = os.path.join(CARDS, "title.png")
    cards.title(c["title"], line="")
    c["fence"] = os.path.join(CARDS, "t_fence.png")
    cards.text_card(c["fence"], "THE FENCE WILL NOT HOLD.", 50, color=(168, 18, 13))
    # gameplay
    for key, txt in [("g_hold", "HOLD THE INN"), ("g_arsenal", "BRING EVERYTHING"), ("g_steel", "TAKE THE STEEL"),
                     ("g_launch", "WATCH THE SKY"), ("g_ride", "RIDE"), ("g_squad", "NEVER ALONE"),
                     ("g_fronts", "FOUR FRONTS. ONE NIGHT THAT NEVER ENDS.")]:
        c[key] = os.path.join(CARDS, key + ".png")
        cards.text_card(c[key], txt, 92 if len(txt) < 20 else 64, bg=(0, 0, 0, 0), y=0.80, spacing=14, face="stencil")
    c["g_title"] = os.path.join(CARDS, "g_title.png")
    cards.title(c["g_title"], line="SOLO OR CO-OP  |  FOUR MAPS  |  ROUND AFTER ROUND".replace("|", "·"))
    c["g_tag"] = os.path.join(CARDS, "g_tag.png")
    cards.text_card(c["g_tag"], "EVERY ROUND IS A SIGNATURE.", 58)
    return c


# ------------------------------------------------------------------ the teaser

def teaser_edit(c):
    T = "teaser"
    seg = [
        {"card": c["silesia"], "dur": 3.0, "fade_in": 0.8, "fade_out": 0.8},
        {"src": hf("t01_crossroads"), "start": 0.2, "dur": 4.8, "fade_in": 1.2, "grade": T, "letterbox": True},
        {"src": hf("t02_inn_front"), "start": 0.2, "dur": 4.6, "grade": T, "letterbox": True},
        {"src": hf("t03_taproom"), "start": 0.4, "dur": 5.0, "grade": T, "letterbox": True},
        {"src": hf("t04_radio"), "start": 0.3, "dur": 3.5, "grade": T, "letterbox": True},
        {"src": hf("t07_breath"), "start": 0.5, "dur": 3.8, "grade": T, "letterbox": True},
        {"src": hf("t06_gate_open"), "start": 0.3, "dur": 3.5, "grade": T, "letterbox": True},
        {"src": hf("t05_window_torn"), "start": 0.3, "dur": 4.3, "grade": T, "letterbox": True, "fade_out": 0.4},
        {"card": c["count"], "dur": 2.8, "fade_in": 0.5, "fade_out": 0.6},
        {"src": hf("t09_treeline"), "start": 0.3, "dur": 4.6, "grade": T, "letterbox": True, "overlay": c["treeline"], "overlay_fade": 0.6},
        {"src": hf("t08_searchlight"), "start": 1.8, "dur": 3.0, "grade": T, "letterbox": True},
        # the build: faster and faster
        {"src": hf("t11_horde_field"), "start": 0.8, "dur": 2.6, "grade": T, "letterbox": True},
        {"src": hf("t10_eye"), "start": 0.6, "dur": 1.6, "grade": T, "letterbox": True},
        {"src": hf("t12_boards"), "start": 1.5, "dur": 1.5, "grade": T, "letterbox": True},
        {"src": hf("t11_horde_field"), "start": 3.6, "dur": 1.1, "grade": T, "letterbox": True},
        {"src": hf("t13_lunge"), "start": 1.6, "dur": 0.8, "grade": T, "letterbox": True},
        {"src": hf("t10_eye"), "start": 3.4, "dur": 0.7, "grade": T, "letterbox": True},
        {"src": hf("t12_boards"), "start": 3.2, "dur": 0.6, "grade": T, "letterbox": True},
        {"src": hf("t11_horde_field"), "start": 4.4, "dur": 0.5, "grade": T, "letterbox": True},
        {"src": hf("t13_lunge"), "start": 2.4, "dur": 1.4, "grade": T, "letterbox": True},
        {"card": None, "dur": 1.4},                                     # the hard cut to black
        {"card": c["title"], "dur": 6.5, "fade_in": 0.05, "fade_out": 1.2},
        {"card": None, "dur": 1.8},
        {"src": hf("t10_eye"), "start": 4.0, "dur": 0.9, "grade": T, "letterbox": True, "flash": 2},   # the last sting
        {"card": c["fence"], "dur": 2.6, "fade_in": 0.3, "fade_out": 1.0},
    ]
    return seg


def teaser_cues(seg):
    st = E.starts(seg)
    dur = E.total(seg)
    i_build = 11
    i_black = 20
    i_title = 21
    i_sting = 23
    cues = [
        (0.0, "wind", st[i_black]),
        (0.5, "drone", st[i_black] - 0.5),
        (st[1] + 2.0, "bell", None),
        (st[3] + 0.8, "creak", 120.0),
        (st[4] + 0.2, "radio", 3.0),
        (st[5] + 0.6, "breath", None),
        (st[6] + 0.3, "creak", 200.0),
        (st[7] + 1.5, "whisper", 2),
        (st[8], "hit", None),
        (st[8] + 0.6, "heart", (52, 120, st[i_black] - st[8] - 0.6)),
        (st[9] + 0.5, "whisper", 4),
        (st[10], "cluster", st[i_black] - st[10]),
        (st[i_build] - 0.2, "groans", st[i_black] - st[i_build] + 0.2),
        (st[i_build] + 2.6, "riser", st[i_black] - st[i_build] - 2.6),
    ]
    for k in range(i_build, i_black):
        cues.append((st[k], "tick", None))
    for k in (12, 15, 19):
        cues.append((st[k], "hit", None))
    cues += [
        (st[i_black], "silence", 1.4),
        (st[i_title], "boom", None),
        (st[i_title] + 0.1, "wind", 7.0),
        (st[i_sting] + 0.02, "sting", None),
        (st[i_sting] + 0.9, "silence", 0.5),
        (st[i_sting] + 1.3, "wind", dur - st[i_sting] - 1.3),
    ]
    return cues, dur


def build_teaser():
    c = make_cards()
    seg = teaser_edit(c)
    for s in seg:
        if "card" in s and s["card"] is None:
            s["card"] = os.path.join(CARDS, "black.png")
    cards.text_card(os.path.join(CARDS, "black.png"), " ", 10)
    cues, dur = teaser_cues(seg)
    wav = os.path.join(B, "teaser_score.wav")
    TA.write_wav(wav, TA.teaser(cues, dur))
    length = E.build(seg, wav, os.path.join(B, "teaser_1080p.mp4"), os.path.join(B, "teaser_720p.mp4"), os.path.join(B, "work_teaser"))
    json.dump({"segments": seg, "cues": [list(map(str, q)) for q in cues]}, open(os.path.join(B, "teaser_edit.json"), "w"), indent=1)
    E.sheet(os.path.join(B, "teaser_1080p.mp4"), os.path.join(B, "teaser_sheet.jpg"), 1.5)
    print("teaser: %.2f s" % length)


# ------------------------------------------------------------------ the gameplay trailer (filled once recorded)

def gameplay_edit(c):
    import gameplay_edl
    return gameplay_edl.edit(c, src)


def build_gameplay():
    import gameplay_edl
    c = make_cards()
    cards.text_card(os.path.join(CARDS, "black.png"), " ", 10)
    seg = gameplay_edl.edit(c, src)
    for s in seg:
        if "card" in s and s["card"] is None:
            s["card"] = os.path.join(CARDS, "black.png")
    cues, dur = gameplay_edl.cues(seg)
    wav = os.path.join(B, "gameplay_score.wav")
    TA.write_wav(wav, TA.gameplay(cues, dur, gameplay_edl.BPM))
    length = E.build(seg, wav, os.path.join(B, "gameplay_1080p.mp4"), os.path.join(B, "gameplay_720p.mp4"), os.path.join(B, "work_gameplay"))
    json.dump({"segments": seg, "cues": [list(map(str, q)) for q in cues]}, open(os.path.join(B, "gameplay_edit.json"), "w"), indent=1)
    E.sheet(os.path.join(B, "gameplay_1080p.mp4"), os.path.join(B, "gameplay_sheet.jpg"), 1.5)
    print("gameplay: %.2f s" % length)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "both"
    if what in ("teaser", "both"):
        build_teaser()
    if what in ("gameplay", "both"):
        build_gameplay()
