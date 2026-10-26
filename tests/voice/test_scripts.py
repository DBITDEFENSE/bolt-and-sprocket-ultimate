"""make_scripts.py (T-101): a script and checklist for every cast slot, the guide and release, and the --since pickup
mode picking only lines added or reworded."""
import csv
import os

import make_scripts as M
import pipeline as P
import voicelib as V


def test_every_slot_gets_a_checklist(tmp_path):
    assert M.main(["--out", str(tmp_path), "--no-pdf"]) == 0
    cast = V.load_cast()
    for game, chars in cast["characters"].items():
        for code in chars:
            for actor in V.actors_for(cast, game, code):
                p = tmp_path / actor / ("%s_checklist.csv" % actor)
                assert p.exists(), p
    rows = list(csv.reader(open(tmp_path / "slot_dut" / "slot_dut_checklist.csv", encoding="utf-8-sig")))
    assert rows[0] == ["line_id", "character", "text", "recorded"]
    assert len(rows) - 1 == len([ln for ln in V.collect_all() if ln.char == "DUT"])
    assert (tmp_path / "RECORDING_GUIDE.txt").exists() and (tmp_path / "VOICE_RELEASE.txt").exists()
    txt = (tmp_path / "VOICE_RELEASE.txt").read_text(encoding="utf-8")
    assert "No AI voice cloning" in txt and "removed" in txt


def test_pdf_builds(tmp_path):
    assert M.main(["--out", str(tmp_path), "--actor", "cousin_1"]) == 0
    assert (tmp_path / "cousin_1" / "cousin_1_script.pdf").stat().st_size > 5000


def test_since_pickup(tmp_path):
    lines = V.collect_all()
    idx = V.script_index(lines)
    idx.pop("DUT_RELOAD_01")                      # "added since"
    idx["DUT_RELOAD_02"] = "0000000000000000"      # "reworded since"
    old = tmp_path / "old_index.json"
    V.save_json(str(old), idx)
    mine = [ln for ln in lines if ln.char == "DUT"]
    got = {ln.file_id for ln in M.pickup_filter("slot_dut", mine, str(old))}
    assert got == {"DUT_RELOAD_01", "DUT_RELOAD_02"}


def test_bs_line_back_to_runtime_tts(sandbox):
    ln = next(ln for ln in V.collect_all() if ln.file_id == "cs.lrSignal.01")
    disk = V.res_to_disk(ln.res_path)
    os.makedirs(os.path.dirname(disk), exist_ok=True)
    open(disk, "wb").write(b"take")
    files = {"cs.lrSignal.01": V.human_row(ln, "testactor", "t@1", "cd" * 20, 1.0, -17.5, "robot_light", "2026-10-26")}
    assert P.restore_tts("bs", files, "cs.lrSignal.01", ln.res_path).startswith("removed")
    assert files["cs.lrSignal.01"]["source"] == "tts" and not os.path.exists(disk)
