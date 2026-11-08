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
    X.lang_lines.clear()


def test_language_tag_keeps_the_other_language_out_of_the_line():
    """T-204: `<ru>X</ru> Y` -> the line says and shows Y; X goes to the language store, not to `speech`."""
    _fresh()
    X.parse_tables("\n".join([
        "| ID | Speaker | Line |",
        "|---|---|---|",
        '| `VOL_LZS_07` | VOL | "[whispers] <ru>Мокрая.</ru> It\'s wet." |',
        '| `REI_STB_99` | REI | "<speech>Achtung.</speech> Attention." |',
    ]))
    assert X.lines["VOL_LZS_07"] == {"speaker": "VOL", "category": "LZS", "text": "[whispers] It's wet."}
    assert X.lang_lines == {"ru": {"VOL_LZS_07": "Мокрая."}}
    assert X.lines["REI_STB_99"]["speech"] == "Achtung."          # German is still spoken in German
    assert X.split_langs("plain <nn> text") == ("plain <nn> text", {})


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
    # the German lines keep their spoken form; the Russian-speaking cast speaks English (T-204), the Russian is kept
    # in the language store with its take
    for k in ["REI_STB_06", "PA_STB_06", "RADIO_UBOAT_01"]:
        assert k in lines and lines[k].get("speech"), k
    ru = json.load(open(os.path.join(ROOT, "data", "gravelight", "vo", "lang", "ru.json"), encoding="utf-8"))
    assert ru["language"] == "ru" and len(ru["lines"]) >= 85
    for k in ["SER_LZS_01", "VOL_LZS_11", "BRG_LZS_08", "SVR_M0_12", "SVR_M1_12", "RTN_CLOSE_16", "SER_DIARY_MAP04D_01"]:
        assert k in lines and "speech" not in lines[k] and not CYRILLIC.search(lines[k]["text"]), k
        assert CYRILLIC.search(ru["lines"][k]["speech"]), k
    for k, v in ru["lines"].items():
        assert "speech" not in lines.get(k, {}), k
        path = v["audio"]["path"]
        assert path.startswith("res://gravelight/audio/vo_lang/ru/") and v["audio"]["language"] == "ru", k
        assert os.path.exists(os.path.join(ROOT, path[len("res://"):])), k
    for k in ["SEL_GL1_08", "DUT_GL1_02", "PEG_GL1_02", "DEA_GL1_02", "WRN_GL1_02"]:
        assert k in lines and "speech" not in lines[k], k
