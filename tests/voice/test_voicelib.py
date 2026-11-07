"""Unit tests for the voice pipeline's pure parts (T-101): ID parsing, fuzzy matching, the consent gate, the cast and
the line collection, the manifest helpers and the TTS fallback."""
import os
import re
import shutil

import voicelib as V
import pipeline as P

ROOT = V.ROOT


# ───────────────────────────── ID parsing

def test_canon_id_spoken_forms():
    k = V.canon_id("WRN_DOWN_01")
    for spoken in ["W-R-N down zero one", "WRN down 01", "W. R. N. Down, zero one.", "Wren down one", "w r n down oh one"]:
        assert V.canon_id(spoken) == k, spoken
    assert V.canon_id("BNT_DUT_PEG_01_p1") == V.canon_id("B.N.T. D.U.T. P.E.G. 01 part one")
    assert V.canon_id("cs.lrSignal.01") == V.canon_id("C S L R signal zero one")
    assert V.canon_id("DUT_DOWN_01") != V.canon_id("DUT_DOWN_10")


def test_every_line_id_is_unambiguous_when_spoken():
    seen = {}
    for ln in V.collect_all():
        k = V.canon_id(ln.file_id)
        assert k not in seen, "%s and %s sound the same" % (ln.file_id, seen[k])
        seen[k] = ln.file_id
        # the script's "say:" hint reads back to the same ID
        assert V.canon_id(V.say_id(ln.file_id).replace("·", " ")) == k, ln.file_id


def test_find_id_calls_in_a_transcript():
    words = "um test test D-U-T reload zero one Reloading! Reloading! D.U.T. ammo low 01 Running light here.".split()
    hits = V.find_id_calls(words, ["DUT_RELOAD_01", "DUT_RELOAD_02", "DUT_AMMO_LOW_01", "DUT_AMMO_NONE_01"])
    assert [h.file_id for h in hits] == ["DUT_RELOAD_01", "DUT_AMMO_LOW_01"]
    assert words[hits[0].end_word] == "Reloading!"


def test_find_id_calls_fuzzy_and_rejects_text():
    hits = V.find_id_calls("Dutch reload oh too".split(), ["DUT_RELOAD_01", "DUT_RELOAD_02"])
    assert [h.file_id for h in hits] == ["DUT_RELOAD_02"]
    # ordinary script text never looks like an ID
    assert V.find_id_calls("Changing mags, cover me!".split(), ["DUT_RELOAD_01", "DUT_RELOAD_02"]) == []


# ───────────────────────────── fuzzy text matching

def test_text_similarity():
    assert V.text_similarity("Running light here.", "Running light here.") == 1.0
    assert V.text_similarity("Kaltenbrun smells like the mill with the lights off", V.match_text(
        "Kaltenbrunn. Smells like the mill with the lights off. Let's get to work.")) > 0.75
    assert V.text_similarity("Running light here", "Changing mags, cover me!") < 0.4


def test_spoken_text_strips_directions():
    assert V.spoken_text("[cheerful] Round {one}! The *doors* are open") == "Round one! The doors are open"
    assert V.match_text("Fang! (Catch!)") == "fang"


# ───────────────────────────── consent gate

def test_consent(tmp_path):
    d = tmp_path / "paul"
    d.mkdir()
    assert not V.read_consent("paul", str(tmp_path)).ok
    (d / "consent.txt").write_text("I agree\nname: Paul\n", encoding="utf-8")
    assert not V.read_consent("paul", str(tmp_path)).ok, "needs a date"
    (d / "consent.txt").write_text("I agree.\nname: Paul\ndate: 2026-10-30\nai_voice_cloning: no\n", encoding="utf-8")
    c = V.read_consent("paul", str(tmp_path))
    assert c.ok and c.date == "2026-10-30" and not c.ai_cloning
    (d / "consent.txt").write_text("I agree. 2026-10-30\nai_voice_cloning: yes\n", encoding="utf-8")
    assert V.read_consent("paul", str(tmp_path)).ai_cloning
    (d / "consent.txt").write_text("I agree 2026-10-30. Update 2026-11-02: consent withdrawn, remove me.\n", encoding="utf-8")
    assert not V.read_consent("paul", str(tmp_path)).ok


# ───────────────────────────── cast + lines

def test_cast_has_every_slot():
    cast = V.load_cast()
    gl = cast["characters"]["gl"]
    for code in ["DUT", "PEG", "DEA", "WRN", "OPR", "JAK", "FAS", "REI", "LSL", "WIE", "BRA", "KRO", "SOB", "ROT", "KUB",
                 "TRU", "POH", "HAM", "RCH", "ALX", "CSN", "PAUL", "SLENDER"]:
        assert code in gl, code
    sp = V.load_json(V.BS_SPEAKERS)["speakers"]
    for who in sp:
        assert who in cast["characters"]["bs"], who
    chars = {(ln.game, ln.char) for ln in V.collect_all()}
    for game, code in chars:
        assert code in cast["characters"][game], "%s:%s speaks but has no cast slot" % (game, code)


def test_bs_line_sources_match_the_game():
    src = open(os.path.join(ROOT, "core", "vo_manager.gd"), encoding="utf-8").read()
    m = re.search(r"LINE_SOURCES: Array = (\[.*?\])\n", src, re.S)
    game = re.findall(r'\["([^"]+)", "([^"]*)"\]', m.group(1))
    assert [list(x) for x in game] == V.BS_LINE_SOURCES


def test_lines_skip_screen_text_and_cover_every_speaker():
    lines = V.collect_all()
    assert len(lines) > 2000
    assert not [ln for ln in lines if ln.game == "bs" and ln.char in V.BS_NOT_SPOKEN]
    ids = {ln.file_id for ln in lines}
    assert "BNT_DUT_PEG_01_p0" in ids and "BNT_DUT_PEG_01" not in ids, "exchanges are recorded per part"
    assert "HAM_ENRAGE_01_RCH" in ids and "HAM_ENRAGE_01_ALX" in ids, "named lines get one take per fallen cousin"
    assert "CSN_CLAP_01" not in ids, "clapping is a sound, not a voice"
    assert "CSN_HUM_01" in ids, "a hum is a vocal performance"
    for ln in lines:
        assert ln.res_path.startswith("res://"), ln.file_id
        assert ln.delivery in V.DELIVERY_ORDER


def test_recording_order_puts_shouting_last():
    lines = [ln for ln in V.collect_all() if ln.char == "DUT"]
    order = [ln.delivery for ln in V.recording_order(lines)]
    assert order.index("shout") > max(i for i, d in enumerate(order) if d in ("calm", "quiet"))


# ───────────────────────────── manifest + TTS fallback

def test_untouched_lines_stay_tts(sandbox):
    gl = V.load_manifest("gl")
    bs = {}
    P.ensure_tts_rows(gl["files"], bs, V.collect_all())
    # no recorded take is in the game; a baked ElevenLabs take (T-193 / T-201) is the only other source
    assert all(r["source"] in ("tts", "ai_eleven") for r in gl["files"].values())
    assert bs["cs.lrSignal.01"]["source"] == "tts"


def test_restore_tts_from_backup(sandbox):
    fid = "DUT_RELOAD_01"
    tts_file = sandbox.copy_tts(fid)
    ln = next(ln for ln in V.collect_all() if ln.file_id == fid)
    m = V.load_manifest("gl")
    row = m["files"][fid]
    tts_row = P.backup_tts(row, ln)
    bak = os.path.join(V.tts_backup_dir(), "dut", fid + ".ogg")
    assert os.path.exists(bak) and os.path.exists(os.path.join(V.tts_backup_dir(), ".gdignore"))
    orig = open(tts_file, "rb").read()
    open(tts_file, "wb").write(b"human take")
    m["files"][fid] = dict(V.human_row(ln, "testactor", "t@1.0", "ab" * 20, 1.0, -17.5, "clean", "2026-10-26"), tts=tts_row)
    what = P.restore_tts("gl", m["files"], fid, ln.res_path)
    assert what == "TTS restored"
    assert open(tts_file, "rb").read() == orig
    assert m["files"][fid]["source"] == "tts" and m["files"][fid]["hash"] == row["hash"]


def test_selection_choice(sandbox):
    mk = lambda tk, sc, st: P.Take(tk, "DUT_RELOAD_01", "a", "s", "n", st, st + 1, "", sc, 1.0, score=sc)  # noqa: E731
    ts = [mk("x@1", 0.80, 1.0), mk("x@5", 0.95, 5.0), mk("x@9", 0.94, 9.0)]
    assert P.choose(ts, {})["DUT_RELOAD_01"].take == "x@9", "a later read wins a near tie"
    assert P.choose(ts, {"DUT_RELOAD_01": {"take": "x@1"}})["DUT_RELOAD_01"].take == "x@1"
    assert P.choose(ts, {"DUT_RELOAD_01": "tts"})["DUT_RELOAD_01"] is None
