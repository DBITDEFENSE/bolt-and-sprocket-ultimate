"""Extracts every ID'd VO line from docs/gravelight/VO_SCRIPT.md and docs/gravelight/CHARACTERS.md into
data/gravelight/vo/lines.json, and keeps data/gravelight/vo/rules.json complete (VO_SCRIPT section 1).

Merge semantics (T-035): the docs are the source for every id they define (text, condition, exchange parts),
but lines that exist only in lines.json (the op.slip.* corporate slips with their slip_tier / min_round,
lines other tools or agents add directly) are kept, and rules.json keys that exist already are never
overwritten; only missing keys get the defaults below. So re-running is always safe.

Foreign-language lines (T-154 / UPDATE 11 contract C3, T-191): a row's text may start with `<speech>X</speech> Y`,
where X is what is said (German, Russian in Cyrillic, Church Slavonic...) and Y the English subtitle; the line becomes
{"text": "Y", "speech": "X"}. A table may instead carry a `Speech` column. The game only ever shows `text`
(gravelight/ui/subtitles.gd shows the VOManager's text; test_vo_speech checks no `text` holds Cyrillic). A line whose
doc row has no speech keeps a `speech` another tool wrote into lines.json (the merge below).

Other-language versions (T-204): `<ru>X</ru> Y` keeps X, the line in another language, out of the game's own line: Y is
then both what is said and the subtitle (the Russian-speaking cast speaks English with a Russian accent), and X goes to
the language store data/gravelight/vo/lang/<code>.json ({"lines": {id: {"speech": X, "audio": ...}}}) that a future
language option reads (VOManager.voice_language plays gravelight/audio/vo_lang/<code>/<speaker>/<id>.ogg). Fields the
store already holds (the take's audio row) are kept; ids the docs no longer tag are kept too.

Re-run after editing either doc:   python gravelight/tools_src/extract_vo.py
Then bake audio for the new lines:  python gravelight/tools_src/gen_vo.py
"""
import collections
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DOCS = ("docs/gravelight/VO_SCRIPT.md", "docs/gravelight/CHARACTERS.md")
LINES_PATH = os.path.join(ROOT, "data", "gravelight", "vo", "lines.json")
RULES_PATH = os.path.join(ROOT, "data", "gravelight", "vo", "rules.json")
LANG_DIR = os.path.join(ROOT, "data", "gravelight", "vo", "lang")
LANG_CODES = ("ru", "de", "pl", "fr", "it", "es", "uk")   # the language tags extract_vo knows (<ru>...</ru>)
ID_RE = r"[A-Z]{2,3}_[A-Z0-9_]+"   # 2-letter speakers since UPDATE 07 (PA, the Bordfunk)
lines = {}
lang_lines = {}   # code -> {id: the line in that language} (T-204)


def category_of(line_id):
    parts = line_id.split("_")
    body = parts[1:]
    if body and re.fullmatch(r"\d+", body[-1]):
        body = body[:-1]
    if len(body) > 1 and re.fullmatch(r"SQ\d+", body[0]):
        body = body[1:]   # a bake tag (DUT_SQ3_SPRINTER_BEHIND_01 is category SPRINTER_BEHIND), not a category word
    return "_".join(body)


def clean(text):
    text = text.strip()
    text = re.sub(r"\*+", "", text)          # markdown emphasis
    return text.strip()


SPEECH_RE = re.compile(r"<speech>(.*?)</speech>", re.DOTALL)


def split_speech(text):
    """'[whispers] <speech>Мокрая.</speech> It\'s wet.' -> ('[whispers] It\'s wet.', 'Мокрая.'); no tag -> (text, '').
    Audio tags before the tag stay on the subtitle (the bake applies them to the spoken form, gen_vo.py)."""
    m = SPEECH_RE.search(text)
    if not m:
        return text, ""
    rest = (text[:m.start()] + " " + text[m.end():]).strip()
    return re.sub(r"\s{2,}", " ", rest), m.group(1).strip()


LANG_RE = re.compile(r"<(%s)>(.*?)</\1>" % "|".join(LANG_CODES), re.DOTALL)


def split_langs(text):
    """'[whispers] <ru>Мокрая.</ru> It\'s wet.' -> ('[whispers] It\'s wet.', {'ru': 'Мокрая.'}); no tag -> (text, {})."""
    found = {m.group(1): m.group(2).strip() for m in LANG_RE.finditer(text)}
    if not found:
        return text, found
    return re.sub(r"\s{2,}", " ", LANG_RE.sub(" ", text)).strip(), found


def add(line_id, text, condition="", source="", speech=""):
    if line_id in lines:
        return
    text, other = split_langs(text)
    for code, said in other.items():
        lang_lines.setdefault(code, {})[line_id] = said
    text, tagged = split_speech(text)
    speech = (speech or "").strip().strip('"') or tagged
    lines[line_id] = {"speaker": line_id.split("_")[0], "category": category_of(line_id),
                      "text": clean(text)}
    if speech:
        lines[line_id]["speech"] = speech
    if condition:
        lines[line_id]["condition"] = condition.strip()


def parse_tables(md):
    header = None
    for raw in md.splitlines():
        row = raw.strip()
        if not row.startswith("|"):
            header = None
            continue
        cells = [c.strip() for c in row.strip("|").split("|")]
        if cells and cells[0] in ("ID",):
            header = cells
            continue
        if header is None or set(row) <= set("|-: "):
            continue
        cid = cells[0].strip("` *")
        if not re.fullmatch(ID_RE, cid):
            continue
        rec = dict(zip(header, cells))
        text = rec.get("Line") or rec.get("Text") or ""
        text = text.strip().strip('"')
        cond = rec.get("Condition") or rec.get("Trigger") or rec.get("Unlock") or ""
        if text:
            add(cid, text, cond, speech=rec.get("Speech") or "")


def parse_bullets(md):
    pat = re.compile(r'^- `(' + ID_RE + r')`:\s*"(.*)"(.*)$')
    for raw in md.splitlines():
        row = raw.strip()
        tail_at = row.find(" `[")
        tail = row[tail_at:] if tail_at >= 0 else ""
        m = pat.match(row[:tail_at] if tail_at >= 0 else row)
        if not m:
            continue
        line_id, text, rest = m.groups()
        tail = rest + tail
        tr = re.search(r'\[(?:Polish|German)[^"\]]*"([^"]+)"', tail)
        if tr:
            text = text + " (" + tr.group(1) + ")"
        add(line_id, text)
        say = re.search(r'\[say:\s*"([^"]+)"', tail)   # a phonetic respelling for the TTS bake (Jakub's Polish)
        if say and line_id in lines:
            lines[line_id]["tts"] = say.group(1)


def parse_exchanges(md):
    """**BNT_DUT_PEG_01** / **`TAG_KB4471_01`** followed by '- SPK: "text"' lines."""
    cur = None
    for raw in md.splitlines():
        row = raw.strip()
        m = re.fullmatch(r"\*\*`?(" + ID_RE + r")`?\*\*", row)
        if m:
            cur = m.group(1)
            lines[cur] = {"speaker": cur.split("_")[0], "category": category_of(cur), "text": "", "exchange": []}
            continue
        if cur is None:
            continue
        m2 = re.match(r'^- ([A-Z]{3}): "(.*)"', row)
        if m2:
            lines[cur]["exchange"].append([m2.group(1), clean(m2.group(2))])
            lines[cur]["text"] = lines[cur]["exchange"][0][1]
        elif row and not row.startswith("-"):
            cur = None


def parse_inline(md):
    """Lines defined in running prose, e.g. (`OPR_M0_WRONG_01`: "[distant] {Wrong} number!")."""
    for m in re.finditer(r'`(' + ID_RE + r')`:\s*"([^"]+)"', md):
        add(m.group(1), m.group(2))


GL_SPEAKERS = {"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN"}


def parse_gl_tables(md):
    """CHARACTERS.md section 5 rows, | `gl.all.dutch.perk_overclock.01` (optional note) | "Line" |, become the
    VOManager's `{SPK}_PERK_{TOKEN}_{NN}` ids (PERK_TOKENS). An id another pass already defined is kept."""
    pat = re.compile(r"`gl\.all\.([a-z]+)\.perk_([a-z]+)\.(\d+)`(.*)")
    for raw in md.splitlines():
        row = raw.strip()
        if not row.startswith("|"):
            continue
        cells = [c.strip() for c in row.strip("|").split("|")]
        if len(cells) < 2:
            continue
        m = pat.match(cells[0])
        if not m or m.group(1) not in GL_SPEAKERS:
            continue
        line_id = "%s_PERK_%s_%s" % (GL_SPEAKERS[m.group(1)], m.group(2).upper(), m.group(3))
        if line_id in lines:
            print("extract_vo: %s is already defined, keeping that line" % line_id)
            continue
        add(line_id, cells[1].strip('"'), m.group(4).strip().strip("()"))



def write_lang_stores():
    """data/gravelight/vo/lang/<code>.json: the docs' other-language text per id, merged into what the store holds
    (an audio row written by the bake is kept)."""
    for code, said in sorted(lang_lines.items()):
        path = os.path.join(LANG_DIR, code + ".json")
        store = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        store.setdefault("_doc", "T-204: the %s version of lines the game plays in English (the docs' <%s> tags, built by "
                                 "gravelight/tools_src/extract_vo.py). speech = what is said in %s, subtitle = the English "
                                 "line, audio = its baked take (VOManager.voice_language = \"%s\" plays it)." % (
                                     code, code, code, code))
        store["language"] = code
        rows = store.setdefault("lines", {})
        for lid, text in said.items():
            row = rows.setdefault(lid, {})
            row["speech"] = text
            if lid in lines:
                row["subtitle"] = lines[lid]["text"]
        store["lines"] = {k: rows[k] for k in sorted(rows)}
        os.makedirs(LANG_DIR, exist_ok=True)
        json.dump(store, open(path, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
        print("language store %s: %d lines" % (code, len(rows)))


def main():
    global lines
    for doc in DOCS:
        md = open(os.path.join(ROOT, doc), encoding="utf-8").read()
        parse_tables(md)
        parse_bullets(md)
        parse_exchanges(md)
        parse_inline(md)
    for doc in DOCS:
        parse_gl_tables(open(os.path.join(ROOT, doc), encoding="utf-8").read())

    for v in lines.values():
        v["text"] = re.sub(r"^\([^)]*\)\s*", "", v["text"])   # leading stage notes like "(follows 01 after 6 s)"
    lines = {k: v for k, v in lines.items() if v["text"]}

    # ---- merge with the existing lines.json: doc ids win, everything else is kept
    existing = {}
    if os.path.exists(LINES_PATH):
        existing = json.load(open(LINES_PATH, encoding="utf-8"))
    kept = 0
    for k, v in existing.items():
        if k not in lines:
            lines[k] = v
            kept += 1
        else:
            # keep hand-added fields (once_per_match, min_round...) the docs don't carry
            moved = any(k in d for d in lang_lines.values())
            for field, val in v.items():
                if field not in ("speaker", "category", "text", "condition", "exchange", "tts"):
                    if field == "speech" and moved:
                        continue          # T-204: the other language lives in the language store now
                    lines[k].setdefault(field, val)

    rules_defaults = {
        "_doc": "VO playback rules (docs/VO_SCRIPT.md §1). priority: 4 CRITICAL, 3 ANNOUNCE, 2 EVENT, 1 CHATTER, 0 AMBIENT.",
        "story_speakers": ["OPR", "FAS", "REI", "LSL", "CUT", "NPC"],
        "player_speakers": ["DUT", "PEG", "DEA", "WRN", "JAK", "BNT", "TAG"],
        "speaker_default_priority": {"OPR": 2, "FAS": 4, "REI": 4, "LSL": 4, "CUT": 4, "NPC": 2,
                                     "DUT": 1, "PEG": 1, "DEA": 1, "WRN": 1, "JAK": 1, "BNT": 0, "TAG": 4},
        # category prefix -> priority (longest prefix wins); applies to any speaker
        "category_priority": {"PWR_EXPIRE": 2, "PWR_GRAB": 1, "PWR": 3, "POWER_ON": 3, "PYLON": 3, "VAULT": 3,
                              "SPECIAL": 3, "GAME_OVER": 3, "BOSS": 3, "MATCH_START": 2, "ROUND_START": 2,
                              "ROUND_END": 2, "CRATE_MOVE": 2, "CRUCIBLE": 2, "TRAP": 2, "SECOND_WIND": 3,
                              "QUEST": 4, "M0": 4, "M1": 4, "IDLE_SELFAWARE": 0, "SELFAWARE": 0, "EXHAUST": 1},
        # category prefix -> [cooldown seconds, chance 0..1]
        "category_cooldown": {
            "ROUND_START": [0, 0.35], "ROUND_END": [0, 0.35], "PWR_GRAB": [6, 0.6], "PWR_EXPIRE": [0, 0.3],
            "PWR": [0, 1.0], "CRATE_GOOD": [20, 0.7], "CRATE_BAD": [20, 0.7], "CRATE_WONDER": [20, 1.0],
            "CRATE_MOVE": [0, 1.0], "CRATE_DRUMMER": [20, 0.7], "HEADSHOT": [25, 0.2], "STREAK": [40, 0.5],
            "LOW_AMMO": [30, 0.7], "NO_AMMO": [30, 0.7], "KILL": [15, 0.1], "BUY": [10, 0.8], "PERK": [0, 1.0],
            "IDLE_SELFAWARE": [240, 0.5], "SELFAWARE": [240, 1.0], "HINT": [120, 0.4], "BNT": [180, 0.3], "DOWNED": [0, 1.0],
            "REVIVE": [5, 0.8], "REVIVED": [5, 0.8], "DENY": [8, 0.8], "DOOR": [20, 0.4], "MATCH_START": [0, 1.0],
            "SPAWN": [0, 0.6], "GAME_OVER": [0, 1.0], "POWER_ON": [0, 1.0], "INTEL": [10, 1.0],
            "TEAM_DOWN": [8, 0.8], "BOSS": [0, 0.6], "FOREMAN": [0, 0.6], "SCREAMER": [0, 0.6], "GLASSHIDE": [30, 0.3],
            "CRAWLER": [30, 0.15], "TRAP": [12, 0.3], "POWER": [0, 1.0], "BELL": [0, 0.4], "CRUCIBLE": [10, 0.8], "BUILD": [0, 1.0],
            "EE": [0, 1.0], "CRUCIBLE_FIRST": [0, 1.0], "CRUCIBLE_START": [0, 0.7], "CRUCIBLE_READY": [0, 0.7],
            "CRUCIBLE_EXPIRE": [0, 1.0], "SPECIAL_END": [0, 1.0], "PYLON": [0, 1.0], "VAULT": [0, 1.0],
            "AMMO_LOW": [30, 0.7], "AMMO_NONE": [30, 0.7]},
        "round_start_always": [1, 5, 10, 15, 20, 25, 30, 50],
        "queue_expiry": {"0": 4.0, "1": 4.0, "2": 4.0, "3": 20.0, "4": -1.0},
        "player_chatter_gap": 3.5,
        "ambient_gap": 45.0,
        "chars_per_second_inv": 0.065,
        "min_duration": 1.5,
        "exchange_gap": 0.4,
        # T-035 voice pass: squad / Operator overrides, round-break banter and playback.
        "player_category_cooldown": {"_doc": "Overrides of category_cooldown for the squad (DUT/PEG/DEA/WRN) only: [cooldown s, chance].",
                                     "ROUND_START": [0, 0.2], "ROUND_END": [0, 0.2], "TRAP": [20, 0.3], "DOWNED": [0, 1.0], "SPAWN": [0, 0.6]},
        "player_category_priority": {"_doc": "Squad categories above tier 1 (CHATTER): they skip the chatter gap and queue behind a story line instead of being dropped.",
                                     "DOWN": 2, "TEAM_DOWN": 2, "REVIVE": 2, "REVIVED": 2},
        "squad_second_channel": ["TEAM_DOWN", "REVIVE"],
        "down_sequence": {"_doc": "DOWN at once (player channel); TEAM_DOWN on the second squad channel team_down_delay_s later, speaker chosen when it starts (never the downed one or the reviver), dropped after team_down_window_s; the reviver's REVIVE queues behind it; REVIVE is said at revive completion instead if the reviver's line is older than revive_fallback_s; REVIVED on the player channel when the revive lands.",
                          "team_down_delay_s": 1.0, "team_down_window_s": 8.0, "revive_fallback_s": 12.0},
        "story_category_cooldown": {"_doc": "Overrides for the Operator: TRAP 20%, DOWNED 50%.", "TRAP": [10, 0.2], "DOWNED": [0, 0.5]},
        "banter": {"_doc": "Round-break banter (CHARACTERS.md Banter): rolled once per round end after delay_s, between two standing survivors within max_distance_m (0 = any); cooldown_s between exchanges; each exchange once per match.",
                   "chance": 0.3, "cooldown_s": 180.0, "delay_s": 2.5, "max_distance_m": 15.0, "min_round": 2},
        "audio": {"_doc": "Playback: squad lines from other players/bots are positional (unit_size/max_distance in metres); local player and story voices are 2D. duck_db applies to Music/Jingles/ambience while a story line plays.",
                  "squad_unit_size": 5.0, "squad_max_distance": 40.0, "squad_volume_db": 0.0, "story_volume_db": 0.0,
                  "duck_music_db": -6.0, "duck_jingles_db": -9.0, "duck_ambience_db": -5.0},
    }

    rules = {}
    if os.path.exists(RULES_PATH):
        rules = json.load(open(RULES_PATH, encoding="utf-8"))
    added_rules = 0
    for k, v in rules_defaults.items():
        if k not in rules:
            rules[k] = v
            added_rules += 1
        elif isinstance(v, dict) and isinstance(rules[k], dict):
            for kk, vv in v.items():
                if kk not in rules[k]:
                    rules[k][kk] = vv
                    added_rules += 1

    # keep the existing file's order (new ids go at the end), so a re-run's diff shows only what changed
    ordered = {k: lines[k] for k in existing if k in lines}
    for k, v in lines.items():
        ordered.setdefault(k, v)
    lines = ordered
    os.makedirs(os.path.dirname(LINES_PATH), exist_ok=True)
    json.dump(lines, open(LINES_PATH, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
    json.dump(rules, open(RULES_PATH, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
    write_lang_stores()
    counts = collections.Counter(v["speaker"] for v in lines.values())
    print("total", len(lines), "(kept %d ids that only exist in lines.json; %d rule keys added)" % (kept, added_rules))
    for k, v in sorted(counts.items()):
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
