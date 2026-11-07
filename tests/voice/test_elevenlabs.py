"""The ElevenLabs bake (U11 T-193; the T-101 tool before it): off without the key, the take cache (a hit never calls
the API), quota stop and resume, rate limits, the output-format fallback, human takes win, the `speech` field is what
is sent, the language codes, the tag handling, the cast coverage, the consent gate on clones, every AI take marked.
No network: the SDK client is a fake (FakeClient) with the SDK's own ApiError."""
import contextlib
import json
import os
import shutil
import subprocess
import types

import numpy as np
import pytest

import eleven as E
import voicelib as V
from elevenlabs.core.api_error import ApiError

FAKE_KEY = "test-key-not-real"


def pcm_bytes(seconds=0.6, hz=180):
    t = np.arange(int(44100 * seconds)) / 44100.0
    env = np.minimum(1.0, np.minimum(t, t[-1] - t) * 20)
    return (np.sin(2 * np.pi * hz * t) * env * 0.3 * 32767).astype("<i2").tobytes()


@pytest.fixture(scope="session")
def mp3_bytes(tmp_path_factory):
    if not shutil.which("ffmpeg"):
        pytest.skip("ffmpeg not on PATH")
    d = tmp_path_factory.mktemp("mp3")
    w, m = d / "s.raw", d / "s.mp3"
    w.write_bytes(pcm_bytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "44100", "-ac", "1", "-i", str(w),
                    "-c:a", "libmp3lame", "-b:a", "128k", str(m)], check=True)
    return m.read_bytes()


def api_error(status, code, msg):
    # the SDK's error carries the response headers; a real one never has the request key, but scrubbing is tested
    return ApiError(status_code=status, headers={"xi-api-key": FAKE_KEY, "request-id": "r1"},
                    body={"detail": {"status": code, "message": msg}})


class FakeClient:
    """Stands in for elevenlabs.ElevenLabs: text_to_speech.with_raw_response.convert (a context manager like the
    SDK's), user.subscription.get, text_to_sound_effects.convert. fail(n, err): the n-th TTS call (1-based) and every
    later one raise err; refuse_pcm: pcm_* output formats are refused like on a plan without them."""

    def __init__(self, used=1000, limit=100000, mp3=b""):
        self.calls, self.sfx_calls = [], []
        self.used, self.limit = used, limit
        self.fail_from, self.err, self.refuse_pcm, self.mp3 = None, None, False, mp3
        owner = self

        class TTS:
            @property
            def with_raw_response(self):
                return self

            @contextlib.contextmanager
            def convert(self, voice_id, *, text, model_id=None, language_code=None, voice_settings=None,
                        output_format=None, **_):
                owner.calls.append({"voice_id": voice_id, "text": text, "model_id": model_id, "lang": language_code,
                                    "settings": voice_settings.model_dump(exclude_none=True) if voice_settings else None,
                                    "format": output_format})
                if owner.fail_from is not None and len(owner.calls) >= owner.fail_from:
                    raise owner.err
                if owner.refuse_pcm and str(output_format).startswith("pcm"):
                    raise api_error(403, "output_format_not_allowed", "pcm_44100 needs a Pro plan")
                owner.used += len(text)
                data = owner.mp3 if str(output_format).startswith("mp3") else pcm_bytes()
                yield types.SimpleNamespace(data=iter([data]), headers={"x-character-count": str(len(text))})

        class Sub:
            def get(self):
                return types.SimpleNamespace(tier="creator", character_count=owner.used, character_limit=owner.limit,
                                             next_character_count_reset_unix=1767225600, status="active")

        class SFX:
            def convert(self, **kw):
                owner.sfx_calls.append(kw)
                return iter([owner.mp3])

        self.text_to_speech = TTS()
        self.user = types.SimpleNamespace(subscription=Sub())
        self.text_to_sound_effects = SFX()

    def fail(self, n, err):
        self.fail_from, self.err = n, err


def cast_voice(sandbox, game, code, voice_id="voice_test_01", **kw):
    cast = V.load_json(str(sandbox.data / "cast.json"))
    el = cast["characters"][game][code].setdefault("eleven", {})
    el.update({"voice_id": voice_id, "voice_name": "Test " + code, "source": "library"}, **kw)
    V.save_json(str(sandbox.data / "cast.json"), cast, sort=False)


def gl_jobs(ids):
    return [ln for ln in V.collect_gl() if ln.file_id in ids]


@pytest.fixture
def eleven(sandbox, monkeypatch, tmp_path):
    monkeypatch.setenv("ELEVENLABS_API_KEY", FAKE_KEY)
    monkeypatch.setattr(E, "NEEDS_PATH", str(tmp_path / "NEEDS_DEVIN.md"))
    cast_voice(sandbox, "gl", "DUT")
    return sandbox


def dut_ids(n):
    """n of Dutch's short barks (one priority group, so the bake order is the lines.json order)."""
    ids = [ln.file_id for ln in V.collect_gl() if ln.char == "DUT" and E.group_of(ln) == 6
           and not ln.file_id.endswith(("_p0", "_p1"))][:n]
    assert len(ids) == n
    return ids


# ───────────────────────────── the key

def test_off_without_key(sandbox, capsys):
    with pytest.raises(E.Refused, match="npx @elevenlabs/cli onboard"):
        E.api_key()
    assert E.main(["bake"]) == 0
    assert E.main(["bake", "--require-key"]) == 2
    assert "ElevenLabs is off" in capsys.readouterr().out


def test_key_from_env_file_goes_only_to_the_environment(tmp_path, monkeypatch, capsys):
    p = tmp_path / ".env.local"
    p.write_text("# made by the CLI\nOTHER=1\nELEVENLABS_API_KEY=\"%s\"\n" % FAKE_KEY, encoding="utf-8")
    monkeypatch.setattr(E, "env_files", lambda: [str(p)])
    monkeypatch.delenv("OTHER", raising=False)
    assert E.load_key() == FAKE_KEY and os.environ["ELEVENLABS_API_KEY"] == FAKE_KEY
    assert "OTHER" not in os.environ, "only the key is taken from the file"
    assert FAKE_KEY not in capsys.readouterr().out


def test_errors_are_scrubbed(monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", FAKE_KEY)
    e = api_error(401, "invalid_api_key", "bad key %s sk_%s" % (FAKE_KEY, "a" * 48))
    st, code, msg = E.describe(e)
    assert st == 401 and code == "invalid_api_key"
    assert FAKE_KEY not in msg and "a" * 48 not in msg and "request-id" not in msg
    assert E.classify(st, code, msg) == "auth"
    assert "[redacted]" in E.scrub("xi-api-key: abc123") and FAKE_KEY not in E.scrub("k=" + FAKE_KEY)


# ───────────────────────────── text, language, groups

def test_tags_and_speech_text():
    t, cues = E.prepare_text("[whisper] Noted.")
    assert t == "[whispers] Noted." and cues == []
    t, cues = E.prepare_text("[radio] To all boats. (Harbour command.)", "An alle Boote.")
    assert t == "An alle Boote." and cues == ["radio"]
    t, cues = E.prepare_text("[crackling, distant, only partially formed] Hel... hello... Wel-{come}.")
    assert "crackl" not in t and "{" not in t and set(cues) == {"static", "distant"}
    assert E.prepare_text("Get down!", delivery="shout")[0] == "[shouting] Get down!"
    assert E.prepare_text("[to Dutch, gently] Easy.")[0] == "[gently] Easy."
    assert E.prepare_text("There. [a soft tink of a wrench handle]")[0] == "There."
    assert E.prepare_text("[if present] [orchestra swell] Welcome!")[0] == "Welcome!"
    assert E.prepare_text("Wait. [pause] No.")[0] == "Wait. ... No."


def test_language_codes():
    jobs = {j.ln.file_id: j for j in E.build_jobs(V.load_cast(), V.collect_gl())}
    assert jobs["PA_M4B_HEADING_01"].lang == "de" and "Heading" not in jobs["PA_M4B_HEADING_01"].text
    assert jobs["RADIO_UBOAT_01"].lang == "de"
    assert jobs["JAK_BREAKOUT_01"].lang == "pl"
    assert jobs["DUT_RELOAD_01"].lang == "en"
    cast = V.load_cast()
    ser = V.Line("SER_LZS_01", "SER_LZS_01", "gl", "SER", "Lord, have mercy.", "LZS", "calm", "", "res://x/ser.ogg",
                 speech="Господи, помилуй.")
    j = E.build_jobs(cast, [ser])[0]
    assert j.lang == "ru" and j.text == "Господи, помилуй." and j.group == 1
    assert E.detect_lang("Der Hafen ist gesperrt.") == "de" and E.detect_lang("Get down") == ""


def test_priority_groups():
    by = {ln.file_id: ln for ln in V.collect_gl()}
    assert E.group_of(by["OPR_ROUND_START_01"]) == 3
    assert E.group_of(by["DUT_RELOAD_01"]) == 6
    assert E.group_of(by["HAM_ENRAGE_01_RCH"]) == 5
    assert E.group_of(by["BNT_DUT_PEG_01_p0"]) == 2
    assert E.group_of(V.Line("VOL_FTD_03", "VOL_FTD_03", "gl", "VOL", "x", "FTD", "calm", "", "r")) == 1
    assert E.group_of(V.Line("DUT_GL1_03", "DUT_GL1_03", "gl", "DUT", "x", "GL1", "calm", "", "r")) == 1
    assert E.group_of(V.collect_fp()[0]) == 7 and E.group_of(V.collect_bs()[0]) == 8
    assert E.parse_group("barks") == 6 and E.parse_group("2") == 2


def test_every_line_has_a_voice_or_a_reason():
    """Every line id in the three games maps to a cast entry with an ElevenLabs voice, or says why it has none."""
    cast = V.load_cast()
    lines = V.collect_gl() + V.collect_fp() + V.collect_bs()
    assert len(lines) > 5000
    bad = []
    for ln in lines:
        el, why = E.voice_for(cast, ln)
        if el is None or why.startswith("no cast entry") or not (el.get("voice_id") or why):
            bad.append("%s:%s %s" % (ln.game, ln.char, ln.file_id))
    assert not bad, bad[:20]
    for game, chars in cast["characters"].items():
        for code, e in chars.items():
            if e.get("same_as"):
                g, c = e["same_as"].split(":")
                assert c in cast["characters"][g], (code, e["same_as"])
                continue
            el = e.get("eleven")
            assert el is not None and el.get("why"), "%s:%s has no casting reason" % (game, code)
            assert el.get("source") in ("library", "design"), "%s:%s source %s" % (game, code, el.get("source"))
    # the U11 speakers are cast in their language
    for code in ("SER", "VOL", "SVR", "RTN", "BRG"):
        assert cast["characters"]["gl"][code]["eleven"]["language"] == "ru"


def test_no_clone_without_consent(sandbox, monkeypatch):
    monkeypatch.setattr(V, "INBOX_DIR", str(sandbox.inbox))
    cast = V.load_cast()
    assert cast["characters"]["gl"]["PAU"]["eleven"]["source"] in ("design", "library")  # never a clone (T-201: library)
    assert cast["characters"]["gl"]["SLN"]["eleven"]["source"] in ("design", "library")
    cast["characters"]["gl"]["PAU"]["eleven"].update({"voice_id": "clone123", "source": "clone"})
    ln = next(x for x in V.collect_gl() if x.char == "PAU")
    el, why = E.voice_for(cast, ln)
    assert why.startswith("REFUSED")
    sandbox.consent("paul", "I agree.\nname: Paul\ndate: 2026-11-07\nai_voice_cloning: yes\n")
    el, why = E.voice_for(cast, ln)
    assert why == "" and el["voice_id"] == "clone123"
    with pytest.raises(E.Refused, match="REFUSED"):
        E.clone("testactor", client=FakeClient())


# ───────────────────────────── bake: cache, quota, resume, formats, human takes

def test_bake_marks_ai_and_cache_hit_makes_no_call(eleven):
    ids = dut_ids(2)
    eleven.copy_tts(ids[0])
    c = FakeClient()
    r = E.bake(ids=ids, games=("gl",), client=c, sleep=lambda s: None, out=lambda *a: None)
    assert r["baked"] == 2 and len(c.calls) == 2 and not r["stopped"]
    call = c.calls[0]
    assert call["model_id"] == E.TTS_MODEL == "eleven_v4" and call["lang"] == "en" and call["voice_id"] == "voice_test_01"
    assert set(call["settings"]) == {"stability", "similarity_boost"}
    m = V.load_json(str(eleven.gl_man))["files"]
    row = m[ids[0]]
    assert row["source"] == "ai_eleven" and row["ai"] is True and row["model"] == "eleven_v4"
    assert row["tts"]["source"] == "tts", "the TTS row is kept to fall back to"
    assert os.path.exists(V.res_to_disk(row["path"]))
    log = open(os.environ["GL_ELEVEN_LOG"], encoding="utf-8").read()
    assert '"chars_billed"' in log and FAKE_KEY not in log
    # rerun: everything is done, no call
    c2 = FakeClient()
    r2 = E.bake(ids=ids, games=("gl",), client=c2, out=lambda *a: None)
    assert c2.calls == [] and r2["baked"] == 0
    # the game file is gone (a fresh checkout): it comes back from the cache, still without a call
    os.remove(V.res_to_disk(row["path"]))
    r3 = E.bake(ids=ids, games=("gl",), client=c2, out=lambda *a: None)
    assert c2.calls == [] and r3["from_cache"] == 1 and os.path.exists(V.res_to_disk(row["path"]))


def test_quota_stop_and_resume(eleven):
    ids = dut_ids(5)
    c = FakeClient()
    c.fail(3, api_error(401, "quota_exceeded", "This request exceeds your quota of 10000."))
    msgs = []
    r = E.bake(ids=ids, games=("gl",), client=c, sleep=lambda s: None, out=msgs.append)
    assert r["stopped"] == "quota" and r["baked"] == 2
    st = E.load_state()
    assert st["stopped"] == "quota" and st["next"] == ids[2]
    rows = V.load_json(str(eleven.gl_man))["files"]
    assert [i for i in ids if rows[i].get("source") == "ai_eleven"] == ids[:2]
    assert '"stopped": "quota"' in open(os.environ["GL_ELEVEN_LOG"], encoding="utf-8").read()
    # next month: resumes where it stopped, pays only for the rest
    c2 = FakeClient()
    msgs2 = []
    r2 = E.bake(ids=ids, games=("gl",), client=c2, out=msgs2.append)
    assert any("resuming" in m for m in msgs2)
    assert len(c2.calls) == 3 and r2["baked"] == 3 and not r2["stopped"] and E.load_state() == {}


def test_quota_known_ahead_stops_before_calling(eleven):
    ids = dut_ids(3)
    c = FakeClient(used=99998, limit=100000)
    r = E.bake(ids=ids, games=("gl",), client=c, out=lambda *a: None)
    assert r["stopped"].startswith("quota") and c.calls == []


def test_rate_limit_retries_then_stops(eleven):
    ids = dut_ids(2)
    c = FakeClient()
    c.fail(1, api_error(429, "too_many_concurrent_requests", "slow down"))
    slept = []
    r = E.bake(ids=ids, games=("gl",), client=c, sleep=slept.append, out=lambda *a: None)
    assert r["stopped"].startswith("rate") and len(slept) == E.RETRIES and len(c.calls) == E.RETRIES + 1


def test_limit_chars(eleven):
    ids = dut_ids(4)
    c = FakeClient()
    r = E.bake(ids=ids, limit_chars=25, games=("gl",), client=c, out=lambda *a: None)
    assert r["stopped"] == "limit" and sum(len(x["text"]) for x in c.calls) <= 25


def test_pcm_refused_falls_back_to_mp3(eleven, mp3_bytes):
    ids = dut_ids(2)
    c = FakeClient(mp3=mp3_bytes)
    c.refuse_pcm = True
    r = E.bake(ids=ids, games=("gl",), client=c, out=lambda *a: None)
    assert r["baked"] == 2 and [x["format"] for x in c.calls] == ["pcm_44100", "mp3_44100_192", "mp3_44100_192"]
    assert E.load_state() == {"format": "mp3_44100_192"}, "the next run starts with the format the plan takes"


def test_human_take_wins(eleven):
    ids = dut_ids(2)
    m = V.load_json(str(eleven.gl_man))
    ln = next(x for x in V.collect_gl() if x.file_id == ids[0])
    m["files"][ids[0]] = V.human_row(ln, "testactor", "s1@1.00", "abc", 1.0, -18.0, "clean", "2026-11-07")
    V.save_json(str(eleven.gl_man), m, sort=False)
    c = FakeClient()
    r = E.bake(ids=ids, games=("gl",), client=c, out=lambda *a: None)
    assert r["skipped"].get("human") == 1 and len(c.calls) == 1
    rows = V.load_json(str(eleven.gl_man))["files"]
    assert rows[ids[0]]["source"] == "human" and rows[ids[1]]["source"] == "ai_eleven"
    plan = E.plan(client=FakeClient(), write=False, out=lambda *a: None)
    assert plan["groups"][6]["human"] >= 1


def test_speech_field_is_what_is_sent(eleven):
    cast_voice(eleven, "gl", "UBR", "voice_ubr")
    c = FakeClient()
    E.bake(ids=["RADIO_UBOAT_01"], games=("gl",), client=c, out=lambda *a: None)
    lines = V.load_json(V.GL_LINES)
    assert c.calls[0]["text"] == lines["RADIO_UBOAT_01"]["speech"] and c.calls[0]["lang"] == "de"
    assert lines["RADIO_UBOAT_01"]["text"].startswith("[radio] To all boats"), "the subtitle stays English"


def test_plan_writes_needs_devin(eleven, tmp_path):
    p = tmp_path / "NEEDS_DEVIN.md"
    p.write_text("# NEEDS DEVIN\n\n## UPDATE 10\n- old\n", encoding="utf-8")
    r = E.plan(client=FakeClient(), out=lambda *a: None)
    assert r["total_to_pay"] > 0 and r["subscription"]["tier"] == "creator"
    txt = p.read_text(encoding="utf-8")
    assert txt.index(E.NEEDS_HEADING) < txt.index("## UPDATE 10") and "characters" in txt
    p.write_text(txt.replace("<!-- eleven-plan:end -->", "<!-- eleven-plan:end -->\n- the lead's note"), encoding="utf-8")
    E.plan(client=FakeClient(), out=lambda *a: None)
    txt2 = p.read_text(encoding="utf-8")
    assert txt2.count(E.NEEDS_HEADING) == 1 and txt2.count("eleven-plan:start") == 1 and "the lead's note" in txt2


def test_sfx_cached(eleven, mp3_bytes, tmp_path):
    c = FakeClient(mp3=mp3_bytes)
    out = tmp_path / "groan.ogg"
    E.sfx("risen_groan_01", "a low wet groan of a risen soldier, close, horror", 3.0, client=c, out_path=str(out),
          out=lambda *a: None)
    E.sfx("risen_groan_01", "a low wet groan of a risen soldier, close, horror", 3.0, client=c, out_path=str(out),
          out=lambda *a: None)
    assert len(c.sfx_calls) == 1 and c.sfx_calls[0]["model_id"] == E.SFX_MODEL and out.exists()


# ───────────────────────────── T-101 tools on the SDK

def test_stock_is_marked_ai_and_never_over_a_human(sandbox, monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", FAKE_KEY)
    sandbox.copy_tts("DUT_RELOAD_02")
    row = E.stock("DUT_RELOAD_02", "voice123", client=FakeClient())
    assert row["source"] == "ai_stock" and row["ai"] is True and row["tts"]["source"] == "tts"
    m2 = V.load_json(str(sandbox.gl_man))
    assert m2["files"]["DUT_RELOAD_02"]["source"] == "ai_stock"
    m2["files"]["DUT_RELOAD_02"]["source"] = "human"
    V.save_json(str(sandbox.gl_man), m2)
    with pytest.raises(E.Refused, match="recorded take"):
        E.stock("DUT_RELOAD_02", "voice123", client=FakeClient())


def test_sts_needs_the_cast_sheet_to_ask(sandbox, monkeypatch):
    monkeypatch.setenv("ELEVENLABS_API_KEY", FAKE_KEY)
    with pytest.raises(E.Refused, match="voice_changer"):
        E.sts("DUT_RELOAD_02", client=FakeClient())


def test_review_page_marks_ai(eleven, tmp_path, monkeypatch):
    import review
    ids = dut_ids(1)
    E.bake(ids=ids, games=("gl",), client=FakeClient(), out=lambda *a: None)
    monkeypatch.setattr(V, "REVIEW_DIR", str(tmp_path / "rv"))
    monkeypatch.setattr(V, "WORK_DIR", str(tmp_path / "wk"))
    data = review.gather()
    r = next(x for x in data["rows"] if x["id"] == ids[0])
    assert r["source"] == "ai_eleven"
    assert data["cov_char"]["gl:DUT"]["ai"] >= 1
