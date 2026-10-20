"""Extracts every ID'd VO line from docs/VO_SCRIPT.md and docs/CHARACTERS.md into data/vo/lines.json,
and writes the playback rules (VO_SCRIPT §1) to data/vo/rules.json.
Re-run after editing either doc:  python tools_src/extract_vo.py"""
import json, re, collections, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ID_RE = r"[A-Z]{3}_[A-Z0-9_]+"
lines = {}


def category_of(line_id):
    parts = line_id.split("_")
    body = parts[1:]
    if body and re.fullmatch(r"\d+", body[-1]):
        body = body[:-1]
    return "_".join(body)


def clean(text):
    text = text.strip()
    text = re.sub(r"\*+", "", text)          # markdown emphasis
    return text.strip()


def add(line_id, text, condition="", source=""):
    if line_id in lines:
        return
    lines[line_id] = {"speaker": line_id.split("_")[0], "category": category_of(line_id),
                      "text": clean(text)}
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
        cond = rec.get("Condition") or rec.get("Trigger") or rec.get("Unlock") or ""
        if text:
            add(cid, text, cond)


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


for doc in ("docs/VO_SCRIPT.md", "docs/CHARACTERS.md"):
    md = open(os.path.join(ROOT, doc), encoding="utf-8").read()
    parse_tables(md)
    parse_bullets(md)
    parse_exchanges(md)
    parse_inline(md)

# drop exchange headers with no parsed lines
for v in lines.values():
    v["text"] = re.sub(r"^\([^)]*\)\s*", "", v["text"])   # leading stage notes like "(follows 01 after 6 s)"
lines = {k: v for k, v in lines.items() if v["text"]}

rules = {
    "_doc": "VO playback rules (docs/VO_SCRIPT.md §1). priority: 4 CRITICAL, 3 ANNOUNCE, 2 EVENT, 1 CHATTER, 0 AMBIENT.",
    "story_speakers": ["OPR", "FAS", "REI", "LSL", "CUT", "NPC"],
    "player_speakers": ["DUT", "PEG", "DEA", "WRN", "BNT", "TAG"],
    "speaker_default_priority": {"OPR": 2, "FAS": 4, "REI": 4, "LSL": 4, "CUT": 4, "NPC": 2,
                                 "DUT": 1, "PEG": 1, "DEA": 1, "WRN": 1, "BNT": 0, "TAG": 4},
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
        "SPAWN": [0, 0.6], "GAME_OVER": [0, 1.0], "POWER_ON": [0, 1.0], "INTEL": [10, 1.0]},
    "round_start_always": [1, 5, 10, 15, 20, 25, 30, 50],
    "queue_expiry": {"0": 4.0, "1": 4.0, "2": 4.0, "3": 20.0, "4": -1.0},
    "player_chatter_gap": 3.5,
    "ambient_gap": 45.0,
    "chars_per_second_inv": 0.065,
    "min_duration": 1.5,
    "exchange_gap": 0.4,
}

os.makedirs(os.path.join(ROOT, "data/vo"), exist_ok=True)
json.dump(lines, open(os.path.join(ROOT, "data/vo/lines.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
json.dump(rules, open(os.path.join(ROOT, "data/vo/rules.json"), "w", encoding="utf-8"), indent=2)
counts = collections.Counter(v["speaker"] for v in lines.values())
print("total", len(lines))
for k, v in sorted(counts.items()):
    print(f"  {k}: {v}")
