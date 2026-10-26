"""End to end (UPDATE 06 B5.10, T-101): a synthetic "friend's session" built from the game's own TTS lines with the
IDs spoken (tools/voice/make_synthetic.py) goes through the whole importer in a sandbox: matched by spoken ID, the
best take picked, cleaned up, loudness-normalized, written as OGG where the game plays it, the manifest updated
(source human), the TTS kept as fallback, the consent gate and the revert to TTS. A second file with no IDs checks
the text-matching fallback. Uses the committed Whisper transcripts; test_real_whisper reruns Whisper when present."""
import json
import os
import shutil

import pytest

import voicelib as V
import pipeline as P
from conftest import FIX

SESSION = ["DUT_RELOAD_01", "DUT_AMMO_LOW_01", "BNT_DUT_PEG_01_p0", "DUT_BOARD_02", "DUT_SPAWN_01"]
NO_IDS = ["DUT_ROUND_END_01", "DUT_BUY_SHOTGUN_01"]


def _transcripts(work):
    """The committed transcripts keyed by the normalized input's hash (what the pipeline's cache uses)."""
    trs = V.load_json(os.path.join(FIX, "transcripts.json"))
    out = {}
    for name, tr in trs.items():
        _, h = P.normalize(os.path.join(FIX, name), str(work))
        out[h] = tr
    return out


def _setup(sandbox):
    for f in ("testactor_session1.ogg", "testactor_noids.ogg"):
        shutil.copy(os.path.join(FIX, f), sandbox.inbox / "testactor" / f)
    for fid in SESSION + NO_IDS:
        sandbox.copy_tts(fid)
    return _transcripts(sandbox.work / "testactor")


def test_no_consent_ships_nothing(sandbox):
    trs = _setup(sandbox)
    before = sandbox.gl_man.read_text(encoding="utf-8")
    res = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), transcripts=trs, log=lambda *a: None)
    assert res.takes, "it still analyses (for the review page)"
    assert not res.shipped and "testactor" in res.blocked
    after = json.loads(sandbox.gl_man.read_text(encoding="utf-8"))
    assert not [r for r in after["files"].values() if r.get("source") == "human"]
    assert json.loads(before)["files"]["DUT_RELOAD_01"]["hash"] == after["files"]["DUT_RELOAD_01"]["hash"]


def test_pipeline_end_to_end(sandbox):
    trs = _setup(sandbox)
    sandbox.consent()
    res = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), transcripts=trs, log=lambda *a: None)
    by = {}
    for t in res.takes:
        by.setdefault(t.file_id, []).append(t)
    # every ID'd line found, with both reads as takes
    for fid in SESSION:
        assert fid in by, fid
        assert len(by[fid]) == 2, (fid, [(t.take, t.transcript) for t in by[fid]])
        assert max(t.text_score for t in by[fid]) > 0.75, fid
    # the no-ID file fell back to matching the script text
    for fid in NO_IDS:
        assert fid in by and by[fid][0].id_score == 0.0
    assert set(res.shipped) == set(SESSION + NO_IDS)
    m = V.load_json(str(sandbox.gl_man))["files"]
    for fid in SESSION + NO_IDS:
        row = m[fid]
        assert row["source"] == "human" and row["actor"] == "testactor" and row["take"] and len(row["hash"]) == 16
        assert row["tts"]["source"] == "tts", "the TTS row is kept to fall back to"
        disk = V.res_to_disk(row["path"])
        assert os.path.exists(disk) and V.file_sha(disk)[:16] == row["hash"]
        x = P.read_wav(disk)
        assert abs(len(x) / P.SR - row["duration"]) < 0.05, "duration = the audio's length (subtitles, lip flap)"
        target, peak = P.loudness_target(next(ln for ln in V.collect_all() if ln.file_id == fid))
        assert abs(P.lufs(x) - target) < 1.5, fid
        assert os.path.exists(os.path.join(V.tts_backup_dir(), row["path"].split("/")[-2], fid + ".ogg"))
    # the rest is untouched TTS
    assert m["DUT_RELOAD_02"]["source"] == "tts"
    # a rerun does nothing new
    res2 = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), transcripts=trs, log=lambda *a: None)
    assert res2.shipped == [] and res2.reverted == []
    # the review page picks the computer voice for one line: it goes back to TTS
    V.save_json(V.SELECTIONS_PATH, {"DUT_SPAWN_01": {"take": "tts"}})
    res3 = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), transcripts=trs, log=lambda *a: None)
    assert res3.reverted == ["DUT_SPAWN_01"]
    assert V.load_json(str(sandbox.gl_man))["files"]["DUT_SPAWN_01"]["source"] == "tts"
    # consent withdrawn: everything of theirs goes back to TTS
    sandbox.consent(text="I agree 2026-10-26 ... consent withdrawn\n")
    res4 = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), transcripts=trs, log=lambda *a: None)
    assert set(res4.reverted) == set(SESSION + NO_IDS) - {"DUT_SPAWN_01"}
    m = V.load_json(str(sandbox.gl_man))["files"]
    assert not [f for f, r in m.items() if r.get("source") == "human"]


def test_real_whisper(sandbox):
    if os.environ.get("GRAVELIGHT_SKIP_WHISPER") or P.whisper_python() is None:
        pytest.skip("no faster-whisper on this machine")
    shutil.copy(os.path.join(FIX, "testactor_session1.ogg"), sandbox.inbox / "testactor" / "s.ogg")
    sandbox.consent()
    res = P.run(inbox=str(sandbox.inbox), work=str(sandbox.work), ship=False, log=lambda *a: None,
                model=os.environ.get("GRAVELIGHT_WHISPER_MODEL") or None)
    assert {t.file_id for t in res.takes} >= set(SESSION)
