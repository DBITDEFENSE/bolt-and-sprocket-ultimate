"""The optional ElevenLabs tool (T-101): off without the key, never clones without an explicit opt-in, never replaces
a recorded take with a stock voice, and marks what it makes as AI. No network: the HTTP call is faked."""
import numpy as np
import pytest

import elevenlabs as E
import voicelib as V


def fake_pcm(*_a, **_k):
    t = np.arange(44100) / 44100.0
    return (np.sin(2 * np.pi * 180 * t) * 0.3 * 32767).astype("<i2").tobytes()


def test_off_without_key(sandbox, monkeypatch):
    monkeypatch.delenv("ELEVENLABS_API_KEY", raising=False)
    with pytest.raises(E.Refused, match="off"):
        E.stock("DUT_RELOAD_02", "voice123", call=fake_pcm)


def test_clone_needs_opt_in(sandbox, monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "test-key")
    monkeypatch.setattr(V, "INBOX_DIR", str(sandbox.inbox))
    sandbox.consent()
    with pytest.raises(E.Refused, match="REFUSED"):
        E.clone("testactor", call=fake_pcm)


def test_sts_needs_the_cast_sheet_to_ask(sandbox, monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "test-key")
    with pytest.raises(E.Refused, match="voice_changer"):
        E.sts("DUT_RELOAD_02", call=fake_pcm)


def test_stock_is_marked_ai(sandbox, monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", "test-key")
    sandbox.copy_tts("DUT_RELOAD_02")
    row = E.stock("DUT_RELOAD_02", "voice123", call=fake_pcm)
    assert row["source"] == "ai_stock" and row["ai"] is True and row["tts"]["source"] == "tts"
    m = V.load_json(str(sandbox.gl_man))["files"]["DUT_RELOAD_02"]
    assert m["source"] == "ai_stock"
    # and it never overwrites a human take
    m2 = V.load_json(str(sandbox.gl_man))
    m2["files"]["DUT_RELOAD_02"]["source"] = "human"
    V.save_json(str(sandbox.gl_man), m2)
    with pytest.raises(E.Refused, match="recorded take"):
        E.stock("DUT_RELOAD_02", "voice123", call=fake_pcm)
