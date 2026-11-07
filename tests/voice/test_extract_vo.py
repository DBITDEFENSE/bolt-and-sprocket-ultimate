"""extract_vo.py (T-191): the `<speech>X</speech> Y` row form and the `Speech` column become {"text": Y, "speech": X}
(contract C3), and lines.json never carries Cyrillic in a subtitle (the game only shows `text`)."""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "gravelight", "tools_src"))

import extract_vo as X  # noqa: E402

CYRILLIC = re.compile(r"[Ѐ-ӿ]")


def _fresh():
    X.lines.clear()


def test_split_speech():
    assert X.split_speech("plain") == ("plain", "")
    text, speech = X.split_speech("[whispers] <speech>Мокрая.</speech> It's wet.")
    assert text == "[whispers] It's wet." and speech == "Мокрая."
    text, speech = X.split_speech("<speech>Achtung. Masken auf.</speech> Attention. Masks on.")
    assert text == "Attention. Masks on." and speech == "Achtung. Masken auf."


def test_table_row_with_speech_tag():
    _fresh()
    X.parse_tables("\n".join([
        "| ID | Speaker | Line |",
        "|---|---|---|",
        '| `VOL_LZS_07` | VOL | "[whispers] <speech>Мокрая.</speech> It\'s wet." |',
        '| `SEL_GL1_04` | SEL | "[intercom] Light ahead, bearing oh-four-oh." |',
    ]))
    assert X.lines["VOL_LZS_07"] == {"speaker": "VOL", "category": "LZS", "text": "[whispers] It's wet.", "speech": "Мокрая."}
    assert "speech" not in X.lines["SEL_GL1_04"]
    assert X.lines["SEL_GL1_04"]["text"] == "[intercom] Light ahead, bearing oh-four-oh."


def test_table_with_speech_column():
    _fresh()
    X.parse_tables("\n".join([
        "| ID | Speaker | Speech | Line |",
        "|---|---|---|---|",
        '| `RTN_CLOSE_01` | RTN | "Мама." | "Mama." |',
    ]))
    assert X.lines["RTN_CLOSE_01"]["text"] == "Mama."
    assert X.lines["RTN_CLOSE_01"]["speech"] == "Мама."
    assert X.lines["RTN_CLOSE_01"]["category"] == "CLOSE"


def test_inline_and_bullet_forms_take_the_tag_too():
    _fresh()
    X.parse_bullets('- `SVR_M0_99`: "[radio] <speech>Приём.</speech> Over."')
    X.parse_inline('(`BRG_LZS_99`: "<speech>Граждане!</speech> Citizens!")')
    assert X.lines["SVR_M0_99"]["text"] == "[radio] Over." and X.lines["SVR_M0_99"]["speech"] == "Приём."
    assert X.lines["BRG_LZS_99"]["text"] == "Citizens!" and X.lines["BRG_LZS_99"]["speech"] == "Граждане!"


def test_lines_json_subtitles_never_show_cyrillic():
    lines = json.load(open(os.path.join(ROOT, "data", "gravelight", "vo", "lines.json"), encoding="utf-8"))
    bad = [k for k, v in lines.items() if CYRILLIC.search(v.get("text", ""))]
    assert bad == [], "Cyrillic in a subtitle: %s" % bad[:5]
    for k, v in lines.items():
        if "speech" in v:
            assert v["speech"].strip() and v["text"].strip(), k
            assert "<speech>" not in v["text"] and "<speech>" not in v["speech"], k
    # the T-191 speakers are in, with the spoken form
    for k in ["SER_LZS_01", "VOL_LZS_11", "BRG_LZS_08", "SVR_M0_12", "SVR_M1_12", "RTN_CLOSE_16", "REI_STB_06", "PA_STB_06"]:
        assert k in lines and lines[k].get("speech"), k
    for k in ["SEL_GL1_08", "DUT_GL1_02", "PEG_GL1_02", "DEA_GL1_02", "WRN_GL1_02"]:
        assert k in lines and "speech" not in lines[k], k
