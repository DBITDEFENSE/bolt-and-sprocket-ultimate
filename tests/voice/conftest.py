"""pytest setup for the voice pipeline tests (T-101): tools/voice on the path and a sandbox that points every file the
pipeline writes (manifests, selections, sessions, the game's audio, the inbox and work folders) at a temp folder,
so the tests never touch the real game files."""
import json
import os
import shutil
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools", "voice"))

import voicelib as V  # noqa: E402

FIX = os.path.join(ROOT, "tests", "voice", "fixtures")


@pytest.fixture(autouse=True)
def no_live_elevenlabs(tmp_path, monkeypatch):
    """U11 T-193: no test ever sees the owner's ElevenLabs key or the real take cache / log unless it asks for them
    (test_eleven_key does, to scan for it): the key is taken out of the environment, the .env.local files are off,
    the cache and the credits log go to the test's tmp folder."""
    monkeypatch.delenv("ELEVENLABS_API_KEY", raising=False)
    monkeypatch.setenv("GL_ELEVEN_KEYFILES", "0")
    monkeypatch.setenv("GL_VOICE_CACHE", str(tmp_path / "eleven_cache"))
    monkeypatch.setenv("GL_ELEVEN_LOG", str(tmp_path / "logs" / "elevenlabs.log"))


@pytest.fixture
def sandbox(tmp_path, monkeypatch):
    """A copy of the manifests + cast in tmp; game audio lands in tmp/out; inbox tmp/inbox; work tmp/work.
    The cast gets a test actor 'testactor' voicing Dutch."""
    data = tmp_path / "data"
    data.mkdir()
    gl_man = data / "gl_manifest.json"
    bs_man = data / "bs_manifest.json"
    shutil.copy(V.GL_MANIFEST, gl_man)
    # T-201 bake: the real manifest now holds AI takes. The tests start from the TTS state, so swap each AI row
    # back to the TTS row it keeps under "tts" (in the sandbox copy only).
    _m = V.load_json(str(gl_man))
    for _k, _row in list(_m["files"].items()):
        if _row.get("source") == "ai_eleven" and isinstance(_row.get("tts"), dict):
            _m["files"][_k] = _row["tts"]
    gl_man.write_text(json.dumps(_m, ensure_ascii=False), encoding="utf-8")
    cast =V.load_json(V.CAST_PATH)
    cast["actors"]["testactor"] = {"name": "Test Actor"}
    cast["characters"]["gl"]["DUT"]["actor"] = "testactor"
    cast_p = data / "cast.json"
    cast_p.write_text(json.dumps(cast), encoding="utf-8")
    out = tmp_path / "out"
    out.mkdir()
    monkeypatch.setattr(V, "GL_MANIFEST", str(gl_man))
    monkeypatch.setattr(V, "BS_MANIFEST", str(bs_man))
    monkeypatch.setattr(V, "CAST_PATH", str(cast_p))
    monkeypatch.setattr(V, "SELECTIONS_PATH", str(data / "selections.json"))
    monkeypatch.setattr(V, "SESSIONS_PATH", str(data / "sessions.json"))
    monkeypatch.setattr(V, "OUT_ROOT", str(out))
    # U11: the synthetic session was recorded from older script text; pin those ids to it (fixtures/recorded_lines.json)
    lines = V.load_json(V.GL_LINES)
    lines.update(V.load_json(os.path.join(FIX, "recorded_lines.json"))["lines"])
    gl_lines = data / "lines.json"
    gl_lines.write_text(json.dumps(lines, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(V, "GL_LINES", str(gl_lines))
    inbox = tmp_path / "inbox"
    (inbox / "testactor").mkdir(parents=True)
    work = tmp_path / "work"

    class S:
        pass
    s = S()
    s.tmp, s.data, s.out, s.inbox, s.work, s.gl_man, s.bs_man = tmp_path, data, out, inbox, work, gl_man, bs_man

    def copy_tts(fid):
        """Puts the real TTS file of a Dutch line into the sandbox's game folder (what an import replaces)."""
        row = V.load_json(V.GL_MANIFEST)["files"][fid]
        rel = row["path"][len("res://"):]
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(os.path.join(ROOT, rel), dst)
        return dst
    s.copy_tts = copy_tts

    def consent(actor="testactor", text=None):
        p = inbox / actor / "consent.txt"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text if text is not None else "I agree.\nname: Test\ndate: 2026-10-26\nai_voice_cloning: no\n", encoding="utf-8")
    s.consent = consent
    return s
