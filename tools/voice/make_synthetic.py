#!/usr/bin/env python3
"""Builds the end-to-end test recording (UPDATE 06 B5.10, T-101): a fake "friend's session" made from lines the game
already has as TTS, read the way the recording guide asks (line ID, pause, read, pause, a second read, 2 s pause),
plus a second file with no IDs said (the text-matching fallback). The spoken IDs are synthesized with the Kokoro
voices the TTS bake uses (tools/setup_tts.sh), so this needs the PC's neural TTS once; the result is committed in
tests/voice/fixtures/ with its Whisper transcript, and the tests run from those.

  tools/voice.sh synthetic            rebuild tests/voice/fixtures/ (session audio + transcripts)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402
import pipeline as P  # noqa: E402

FIX = os.path.join(V.ROOT, "tests", "voice", "fixtures")
# (line id, second read gain) for the ID'd session; an exchange part and a Polish line included on purpose
SESSION = [("DUT_RELOAD_01", 0.8), ("DUT_AMMO_LOW_01", 1.0), ("BNT_DUT_PEG_01_p0", 0.9), ("DUT_BOARD_02", 0.85),
           ("DUT_SPAWN_01", 1.0)]
NO_IDS = ["DUT_ROUND_END_01", "DUT_BUY_SHOTGUN_01"]


def tts_audio(fid: str) -> np.ndarray:
    m = V.load_manifest("gl")["files"][fid]
    return P.read_wav_any(V.res_to_disk(m["path"]))


def spoken_ids(ids: list[str], tmp: str) -> dict[str, np.ndarray]:
    sys.path.insert(0, os.path.join(V.ROOT, "gravelight", "tools_src"))
    import gen_vo
    env = gen_vo.neural_env()
    if env is None:
        raise SystemExit("needs the Kokoro TTS (tools/setup_tts.sh) to say the IDs")
    py, model = env
    cast = V.load_json(V.GL_VOICE_CAST)
    c = cast["cast"]["DUT"]
    jobs = []
    for fid in ids:
        say = V.say_id(fid).replace(" · ", ". ").replace("-", " ") + "."
        jobs.append({"id": fid, "wav": os.path.join(tmp, fid + ".id.wav"), "speaker": "DUT", "text": say,
                     "voice": c["voice"], "speed": 0.95, "lexicon": "us", "accent": "", "native_polish": False,
                     "native_german": False, "exclaim": False})
    jp, rp = os.path.join(tmp, "j.json"), os.path.join(tmp, "r.json")
    with open(jp, "w", encoding="utf-8") as f:
        json.dump({"model": model, "cast": cast, "jobs": jobs}, f)
    subprocess.run([py, "-I", os.path.join(V.ROOT, "gravelight", "tools_src", "gen_vo_neural.py"), jp, rp], check=True)
    return {j["id"]: P.read_wav_any(j["wav"]) for j in jobs}


def silence(s: float) -> np.ndarray:
    return np.zeros(int(P.SR * s))


def room_noise(x: np.ndarray, rng) -> np.ndarray:
    return x + rng.standard_normal(len(x)) * 10 ** (-62 / 20)


def main() -> int:
    os.makedirs(FIX, exist_ok=True)
    rng = np.random.default_rng(1101)
    with tempfile.TemporaryDirectory() as tmp:
        ids = spoken_ids([f for f, _ in SESSION], tmp)
        parts = [silence(0.8)]
        truth = []
        t = 0.8
        for fid, g in SESSION:
            line = tts_audio(fid)
            for seg in (ids[fid], silence(0.9), line, silence(1.1), line * g, silence(2.0)):
                parts.append(seg)
            truth.append({"file_id": fid, "id_at": round(t, 2)})
            t += sum(len(p) for p in (ids[fid], silence(0.9), line, silence(1.1), line, silence(2.0))) / P.SR
        x = room_noise(np.concatenate(parts), rng)
        P.write_wav(os.path.join(tmp, "s1.wav"), x * 0.9)
        P.encode_ogg(os.path.join(tmp, "s1.wav"), os.path.join(FIX, "testactor_session1.ogg"), 4.0)
        parts = [silence(0.6)]
        for fid in NO_IDS:
            parts += [tts_audio(fid), silence(1.6)]
        P.write_wav(os.path.join(tmp, "s2.wav"), room_noise(np.concatenate(parts), rng) * 0.9)
        P.encode_ogg(os.path.join(tmp, "s2.wav"), os.path.join(FIX, "testactor_noids.ogg"), 4.0)
    # transcripts (real Whisper), keyed by the input's hash like the pipeline's cache
    trs = {}
    work = tempfile.mkdtemp()
    for name in ("testactor_session1.ogg", "testactor_noids.ogg"):
        wav, h = P.normalize(os.path.join(FIX, name), work)
        trs[name] = P.transcribe([(wav, h)], work)[h]
    V.save_json(os.path.join(FIX, "transcripts.json"), trs)
    V.save_json(os.path.join(FIX, "truth.json"), {"session": truth, "no_ids": NO_IDS}, sort=False)
    print("fixtures written to", FIX)
    return 0


if __name__ == "__main__":
    sys.exit(main())
