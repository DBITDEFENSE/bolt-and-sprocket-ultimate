#!/usr/bin/env python3
"""ElevenLabs, optional and OFF by default (UPDATE 06 B6, T-101). Nothing here runs unless the owner sets the key in
the environment: ELEVENLABS_API_KEY (never written to any file, never committed, never printed).

  tools/voice.sh elevenlabs stock --line=OPR_ROUND_START_02 --voice=<voice id>   a stock voice for a gap line nobody
                                                                                 recorded (source ai_stock)
  tools/voice.sh elevenlabs sts --line=DUT_DOWN_01                                voice changer on the recorded take,
                                                                                 only when cast.json asks for it
                                                                                 (character "voice_changer": voice id)
  tools/voice.sh elevenlabs clone --actor=paul                                    a clone of a cast member's voice:
                                                                                 REFUSED unless their consent.txt
                                                                                 says "ai_voice_cloning: yes"
Every AI line is marked in the manifest (source ai_stock / ai_sts / ai_clone) and on the review page. A recorded
(human) take is never replaced by a stock voice. Commercial use needs a paid ElevenLabs plan (see NEEDS_DEVIN).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import urllib.request
import uuid

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402
import pipeline as P  # noqa: E402

API = "https://api.elevenlabs.io/v1"
TTS_MODEL = "eleven_multilingual_v2"
STS_MODEL = "eleven_multilingual_sts_v2"
PCM_RATE = 44100


class Refused(Exception):
    pass


def api_key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        raise Refused("ElevenLabs is off: set ELEVENLABS_API_KEY in the environment to use it (never in a file)")
    return k


def _multipart(fields: dict, files: list[tuple[str, str, bytes]]) -> tuple[bytes, str]:
    b = uuid.uuid4().hex
    out = []
    for k, v in fields.items():
        out.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (b, k, v)).encode())
    for name, fname, data in files:
        out.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: "
                    "application/octet-stream\r\n\r\n" % (b, name, fname)).encode() + data + b"\r\n")
    out.append(("--%s--\r\n" % b).encode())
    return b"".join(out), "multipart/form-data; boundary=" + b


def http(method: str, url: str, key: str, body: bytes, ctype: str) -> bytes:
    req = urllib.request.Request(url, data=body, method=method, headers={"xi-api-key": key, "Content-Type": ctype})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def _pcm(data: bytes) -> np.ndarray:
    x = np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768.0
    from scipy import signal
    return signal.resample_poly(x, P.SR, PCM_RATE)


def _line(fid: str) -> V.Line:
    for ln in V.collect_all():
        if ln.file_id == fid:
            return ln
    raise Refused("unknown line id %s" % fid)


def _ship(ln: V.Line, x: np.ndarray, source: str, actor: str, take: str) -> dict:
    fx = V.load_json(V.FX_PATH)
    target, peak = P.loudness_target(ln)
    y = P.to_loudness(P.trim(x), target, peak)
    name, chain = P.fx_for(fx, ln)
    if chain.get("kind", "clean") != "clean":
        y = P.to_loudness(P.tail_trim(P.apply_fx(y, chain, ln.file_id)), target, peak)
    m = V.load_manifest(ln.game)
    files = m.setdefault("files", {})
    cur = files.get(ln.file_id, {})
    with tempfile.TemporaryDirectory() as td:
        w = os.path.join(td, "x.wav")
        P.write_wav(w, y)
        tts_row = P.backup_tts(cur, ln) if (ln.game == "gl" and cur and cur.get("source", "tts") == "tts") else cur.get("tts")
        disk = V.res_to_disk(ln.res_path)
        P.encode_ogg(w, disk)
    row = V.human_row(ln, actor, take, V.file_sha(disk), len(y) / P.SR, P.lufs(y), name, "", source=source)
    row["ai"] = True
    if tts_row:
        row["tts"] = tts_row
    files[ln.file_id] = row
    V.save_manifest(ln.game, m)
    return row


def stock(fid: str, voice: str, force: bool = False, call=http) -> dict:
    ln = _line(fid)
    cur = V.load_manifest(ln.game).get("files", {}).get(fid, {})
    if cur.get("source") == "human" and not force:
        raise Refused("%s has a recorded take by %s: a stock voice never replaces a real one" % (fid, cur.get("actor")))
    key = api_key()
    body = json.dumps({"text": V.spoken_text(ln.text), "model_id": TTS_MODEL}).encode()
    data = call("POST", "%s/text-to-speech/%s?output_format=pcm_%d" % (API, voice, PCM_RATE), key, body, "application/json")
    return _ship(ln, _pcm(data), "ai_stock", "elevenlabs:" + voice, "stock")


def sts(fid: str, call=http) -> dict:
    ln = _line(fid)
    cast = V.load_cast()
    voice = cast.get("characters", {}).get(ln.game, {}).get(ln.char, {}).get("voice_changer", "")
    if not voice:
        raise Refused("cast.json does not ask for a voice changer on %s (set characters.%s.%s.voice_changer)" % (ln.char, ln.game, ln.char))
    cur = V.load_manifest(ln.game).get("files", {}).get(fid, {})
    if cur.get("source") != "human":
        raise Refused("%s has no recorded take to change" % fid)
    actor = cur.get("actor", "")
    if not V.read_consent(actor).ok:
        raise Refused("%s has no consent on file" % actor)
    key = api_key()
    audio = open(V.res_to_disk(cur["path"]), "rb").read()
    body, ctype = _multipart({"model_id": STS_MODEL}, [("audio", fid + ".ogg", audio)])
    data = call("POST", "%s/speech-to-speech/%s?output_format=pcm_%d" % (API, voice, PCM_RATE), key, body, ctype)
    return _ship(ln, _pcm(data), "ai_sts", actor, cur.get("take", "") + ">sts:" + voice)


def clone(actor: str, call=http) -> str:
    c = V.read_consent(actor)
    if not c.ok or not c.ai_cloning:
        raise Refused("REFUSED: %s has not opted in to AI voice cloning (voice_inbox/%s/consent.txt must say "
                      "'ai_voice_cloning: yes')" % (actor, actor))
    key = api_key()
    samples = []
    for fid, row in {**V.load_manifest("gl").get("files", {}), **V.load_manifest("bs").get("files", {})}.items():
        if row.get("source") == "human" and row.get("actor") == actor and len(samples) < 20:
            samples.append(("files", fid + ".ogg", open(V.res_to_disk(row["path"]), "rb").read()))
    if not samples:
        raise Refused("no recorded takes of %s to clone from" % actor)
    body, ctype = _multipart({"name": "tc-%s" % actor, "description": "Terms & Conditions cast clone (consent %s)" % c.date}, samples)
    return json.loads(call("POST", API + "/voices/add", key, body, ctype)).get("voice_id", "")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["stock", "sts", "clone"])
    ap.add_argument("--line", default="")
    ap.add_argument("--voice", default="")
    ap.add_argument("--actor", default="")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    try:
        if a.mode == "stock":
            print(stock(a.line, a.voice, a.force))
        elif a.mode == "sts":
            print(sts(a.line))
        else:
            print("cloned voice id:", clone(a.actor))
    except Refused as e:
        print(e)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
