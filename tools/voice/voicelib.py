"""Shared pieces of the voice-acting pipeline (UPDATE 06 Part B, T-101).

Everything the script generator (make_scripts.py), the importer (import.py / pipeline.py), the review page
(review.py) and the tests need: where things live, the cast sheet, every spoken line in the game data (Gravelight
and Bolt & Sprocket) with its recording ID, its acting note and the path the game plays it from, spoken-ID parsing,
fuzzy text matching, the consent gate and the manifest helpers.

Pure Python (stdlib only) so the tests and the script generator run anywhere; the audio parts live in pipeline.py.
Portable: every path is relative to the repo root (this file's ../..); nothing is hard-coded to one machine.
"""
from __future__ import annotations

import csv
import datetime as _dt
import difflib
import hashlib
import io
import json
import os
import re
import sys
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

DATA_VOICE = os.path.join(ROOT, "data", "voice")
CAST_PATH = os.path.join(DATA_VOICE, "cast.json")
FX_PATH = os.path.join(DATA_VOICE, "fx.json")
SELECTIONS_PATH = os.path.join(DATA_VOICE, "selections.json")
SESSIONS_PATH = os.path.join(DATA_VOICE, "sessions.json")
GL_LINES = os.path.join(ROOT, "data", "gravelight", "vo", "lines.json")
GL_MANIFEST = os.path.join(ROOT, "data", "gravelight", "vo", "audio_manifest.json")
GL_VOICE_CAST = os.path.join(ROOT, "data", "gravelight", "vo", "voice_cast.json")
GL_BOSSES = os.path.join(ROOT, "data", "gravelight", "bosses")
GL_LIKENESS = os.path.join(GL_BOSSES, "likeness.json")
BS_DATA = os.path.join(ROOT, "data", "bs")
BS_SPEAKERS = os.path.join(BS_DATA, "story", "speakers.json")
BS_MANIFEST = os.path.join(ROOT, "data", "bs", "vo", "audio_manifest.json")
SCRIPTS_DIR = os.path.join(ROOT, "voice_scripts")
INBOX_DIR = os.path.join(ROOT, "voice_inbox")
WORK_DIR = os.path.join(ROOT, "voice_work")
REVIEW_DIR = os.path.join(ROOT, "voice_review")
GL_AUDIO_RES = "res://gravelight/audio/vo/"
BS_AUDIO_RES = "res://audio/vo/"

# Bolt & Sprocket line tables, exactly as core/vo_manager.gd LINE_SOURCES lists them ([table, key]; "" = the table
# itself). A test checks this matches the game's list.
BS_LINE_SOURCES = [["bs/story/lines_index", ""], ["bs/ui_lines", ""], ["bs/bosses", "lines"],
                   ["bs/weapons", "lines"], ["bs/levels/scrapheap_lines", "lines"], ["bs/levels/rustvane_lines", "lines"],
                   ["bs/levels/nova_plaza_lines", "lines"], ["bs/levels/verdant_lines", "lines"], ["bs/gadgets", "lines"],
                   ["bs/forge", "lines"], ["bs/enemies", "lines"]]
# B&S "who" values that are not voices (on-screen text): skipped, like VOICE_SCRIPT_ALL_LINES.pdf does.
BS_NOT_SPOKEN = {"ui", "banner", "hint", "sign", "memo", "fx", "zonga_feed", "loop_riot"}
# B&S "who" aliases: Loop Riot's quip kinds are Sprocket talking (her overclock); "squatter" is the Squatter.
BS_WHO_ALIAS = {"bail": "sprocket", "fall": "sprocket", "bank": "sprocket", "loop": "sprocket", "final": "sprocket",
                "lead": "sprocket", "start": "sprocket", "squatter": "squat"}
# Gravelight speakers that are containers, not voices (banter / tag exchanges list their real speakers).
GL_CONTAINERS = {"BNT", "TAG"}
# The Cousins' boss-file speakers -> cast codes.
COUSIN_CODES = {"hammer": "HAM", "reach": "RCH", "alix": "ALX", "cousins": "CSN"}
COUSIN_SLOTS = {"HAM": "cousin_1", "RCH": "cousin_2", "ALX": "cousin_3"}
DEAD_NAME = "%DEAD_COUSIN_NAME%"

# Words that make a stage-direction-only line still a vocal performance (a giggle, a hum) rather than a sound.
VOCAL_DIRECTIONS = ("hum", "whisper", "giggle", "laugh", "scream", "sob", "gasp", "sigh", "groan", "breath",
                    "cry", "moan", "sing", "wail", "shriek", "chuckle")

DELIVERY_ORDER = ["quiet", "calm", "mine", "brisk", "raised", "hurt", "shout"]
DELIVERY_NOTE = {
    "calm": "Relaxed and conversational.",
    "brisk": "Quick and clear: you're busy, on the move.",
    "raised": "Louder and urgent, but not a full shout.",
    "shout": "Shout it: full voice, over gunfire. (These are last in the script so your voice lasts.)",
    "hurt": "Wounded: breathy, pained, short of air.",
    "quiet": "Low and close, almost to yourself.",
    "mine": "Hushed and awed, deep underground.",
}

# Short "plays when" context per category prefix (longest prefix wins). From VO_SCRIPT.md section 2.
CONTEXT = {
    "SPAWN": "the match starts", "ROUND_START": "a round starts", "ROUND_END": "a round ends",
    "RELOAD": "you reload", "AMMO_LOW": "you're nearly out of ammo", "AMMO_NONE": "your gun is empty",
    "BOARD": "you board up a window", "REVIVED": "someone picks you up", "REVIVE": "you pick a teammate up",
    "DOWN": "you go down", "TEAM_DOWN": "a teammate goes down", "BUY_AMMO": "you buy ammo",
    "BUY_": "you buy a gun off the wall", "CRATE_GOOD": "the mystery crate gives you something good",
    "CRATE_BAD": "the mystery crate gives you junk", "CRATE_DRUMMER": "the crate's drummer toy appears",
    "CRATE_WONDER": "the crate gives you a wonder weapon", "CRATE_MOVE": "the crate moves",
    "PERK_": "you drink a perk tonic", "DENY_NO_POWER": "a machine has no power", "DENY_CAP": "you can't hold more perks",
    "DENY_NO_SCRIP": "you can't afford something", "DOOR": "you open a door", "ZONE_": "you enter a new area",
    "POWER": "the power comes on", "PWR_": "you grab a power-up", "HEADSHOT": "you land a headshot",
    "STREAK": "you're on a kill streak", "INTEL": "you find a document", "TRAP": "you set off a trap",
    "BELL": "a special round is coming", "FOREMAN": "the Foreman boss appears", "SCREAMER": "a Screamer appears",
    "GLASSHIDE": "you kill a Glasshide", "CHATTER": "it's quiet for a while", "EXHAUST": "very late rounds (50+)",
    "MATCH_START": "the match starts", "SPECIAL_WARN": "a special round is coming", "GAME_OVER": "everyone is dead",
    "DOWNED": "a player goes down", "SECOND_WIND": "a player gets back up on their own",
    "MARK_": "you mark something on the map", "CMD_": "you're given an order", "PING_": "you ping something",
    "EE_": "an easter-egg step happens", "QUEST_": "an easter-egg step happens", "CRUCIBLE": "you use the Crucible upgrade machine",
    "SELFAWARE": "the Operator slips up (rare)", "COUSINS": "the Cousins come (round 10)", "BOSS_": "a boss appears",
    "M0_": "you're on Map 0 (the Crossroads Inn)", "M1_": "you're on Map 1 (Kaltenbrunn)", "INN_": "round 1 starts at the Crossroads Inn",
    "SURV_": "the survivors upstairs at the inn react", "CYL": "a wax cylinder is played", "REC": "a recording is played",
    "BNT": "there's a lull between rounds (banter)", "SPRINTER_BEHIND": "a runner is behind someone", "WINDOW_OPEN": "a window breaks open",
    "BONUS_": "a teammate bot gets a bonus perk", "CAGE": "you talk to Jakub in his cage", "POL": "Jakub teaches a little Polish",
    "ALARM": "Jakub raises the alarm", "BREAKOUT": "Jakub breaks out", "CALL": "Jakub calls out",
}

SPEAKER_NAMES_GL = {
    "DUT": "Dutch", "PEG": "Peg", "DEA": "Deacon", "WRN": "Wren", "JAK": "Jakub", "OPR": "The Operator",
    "FAS": "Fasbender", "REI": "Reinholt", "LSL": "Liesl",
}


# ───────────────────────────────────────────────────────────── json / text helpers

def load_json(path: str, default=None):
    if not os.path.exists(path):
        return {} if default is None else default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def gdignore(folder: str) -> None:
    """Keeps Godot from importing a tool folder (raw recordings, takes, the review page)."""
    os.makedirs(folder, exist_ok=True)
    p = os.path.join(folder, ".gdignore")
    if not os.path.exists(p):
        open(p, "w").close()


def save_json(path: str, data, sort: bool = True) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, ensure_ascii=False, sort_keys=sort)
        f.write("\n")
    os.replace(tmp, path)


def sha16(s: str | bytes) -> str:
    if isinstance(s, str):
        s = s.encode("utf-8")
    return hashlib.sha1(s).hexdigest()[:16]


def file_sha(path: str) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def today() -> str:
    return _dt.date.today().isoformat()


def is_placeholder(s) -> bool:
    s = str(s or "").strip()
    return s == "" or (s.startswith("[") and s.endswith("]"))


# Where res:// paths land on disk. Tests point it at a temporary folder so they never touch the game's files.
OUT_ROOT = ROOT


def res_to_disk(res: str) -> str:
    assert res.startswith("res://"), res
    return os.path.join(OUT_ROOT, *res[len("res://"):].split("/"))


def tts_backup_dir() -> str:
    return os.path.join(OUT_ROOT, "gravelight", "audio", "vo_tts")


def directions(text: str) -> list[str]:
    return [d.strip() for d in re.findall(r"\[([^\]]*)\]", text) if d.strip()]


def spoken_text(text: str) -> str:
    """What the actor actually says: no [directions], no {stress} braces or *markers*, (translations) kept."""
    t = re.sub(r"\[[^\]]*\]", " ", text)
    t = t.replace("{", "").replace("}", "").replace("*", "")
    t = t.replace("™", "").replace("®", "")
    t = re.sub(r"\s{2,}", " ", t).strip()
    if len(t) >= 2 and t[0] == '"' and t[-1] == '"':
        t = t[1:-1].strip()
    return t


def match_text(text: str) -> str:
    """The words a transcript is compared against: spoken_text minus (translations) and punctuation."""
    t = spoken_text(text)
    t = re.sub(r"\([^)]*\)", " ", t)
    return " ".join(norm_words(t))


_NUM_WORDS = {"zero": 0, "oh": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
              "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
              "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
              "won": 1, "to": 2, "too": 2, "for": 4, "ate": 8, "nought": 0, "naught": 0}
_DIGIT_WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


def norm_words(text: str) -> list[str]:
    t = text.lower().replace("’", "'").replace("‘", "'")
    t = re.sub(r"[^\w' ]+", " ", t, flags=re.UNICODE)
    return [w.strip("'") for w in t.split() if w.strip("'")]


def text_similarity(a: str, b: str) -> float:
    """0..1: how well a transcript matches a script line (word-level, forgiving of small slips)."""
    wa, wb = norm_words(a), norm_words(b)
    if not wa or not wb:
        return 0.0
    word = difflib.SequenceMatcher(None, wa, wb, autojunk=False).ratio()
    char = difflib.SequenceMatcher(None, " ".join(wa), " ".join(wb), autojunk=False).ratio()
    return round(max(word, 0.35 * word + 0.65 * char), 4)


# ───────────────────────────────────────────────────────────── spoken line IDs

# What people say instead of an ID's code: a character's name, "part" for the exchange part suffix.
ID_WORD_ALIASES = {
    "dutch": "dut", "peg": "peg", "deacon": "dea", "wren": "wrn", "jakub": "jak", "yakub": "jak", "jacob": "jak",
    "operator": "opr", "fasbender": "fas", "reinholt": "rei", "liesl": "lsl", "liesel": "lsl", "banter": "bnt",
    "part": "p", "pee": "p", "pea": "p", "underscore": "", "dash": "", "hyphen": "", "dot": "", "point": "",
    "line": "", "id": "", "number": "", "take": "", "hammer": "ham", "reach": "rch", "cousins": "csn",
    "cousin": "csn", "alex": "alx", "alix": "alx", "see": "c", "sea": "c", "es": "s", "ess": "s", "ex": "x",
    "are": "r", "you": "u", "why": "y", "queue": "q", "bee": "b", "dee": "d", "gee": "g", "jay": "j", "kay": "k",
    "el": "l", "em": "m", "en": "n", "tea": "t", "tee": "t", "vee": "v", "double": "",
}


def canon_id(s: str) -> str:
    """A line ID or a transcribed ID call reduced to a comparable form: lowercase letters and digit runs (no
    leading zeros), number words turned to digits, separators gone. 'W-R-N down zero one' == 'WRN_DOWN_01'."""
    s = s.replace("_", " ").replace(".", " ").replace("-", " ").replace("#", " ")
    s = re.sub(r"([a-z])([A-Z])", r"\1 \2", s)          # camelCase -> words
    s = re.sub(r"([A-Za-z])(\d)", r"\1 \2", s)
    s = re.sub(r"(\d)([A-Za-z])", r"\1 \2", s)
    toks = [t for t in re.split(r"[^A-Za-z0-9]+", s.lower()) if t]
    out: list[str] = []
    digits = ""
    for t in toks:
        t = ID_WORD_ALIASES.get(t, t)
        if t == "":
            continue
        if t.isdigit():
            digits += t
            continue
        if t in _NUM_WORDS and (digits or len(out) > 0):
            digits += str(_NUM_WORDS[t])
            continue
        if digits:
            out.append(str(int(digits)) if digits.strip("0") else "0")
            digits = ""
        out.append(t)
    if digits:
        out.append(str(int(digits)) if digits.strip("0") else "0")
    return "".join(out)


SPELLED_CODES = {"BNT", "TAG", "CSN", "DUT", "PEG", "DEA", "WRN", "JAK", "OPR", "FAS", "REI", "LSL", "WIE", "BRA",
                 "KRO", "SOB", "ROT", "KUB", "TRU", "POH", "HAM", "RCH", "ALX", "EE"}


def say_id(file_id: str) -> str:
    """How to read an ID aloud, for the script: 'DUT_RELOAD_01' -> 'D-U-T · reload · zero one'."""
    s = re.sub(r"([a-z])([A-Z])", r"\1 \2", file_id)
    parts = [p for p in re.split(r"[_.\s]+", s) if p]
    out = []
    for i, p in enumerate(parts):
        if p.isdigit():
            out.append(" ".join(_DIGIT_WORDS[int(c)] for c in p))
        elif re.fullmatch(r"p\d+", p) and i == len(parts) - 1:
            out.append("part " + " ".join(_DIGIT_WORDS[int(c)] for c in p[1:]))
        elif p.isalpha() and p not in SPELLED_CODES and len(ID_WORD_ALIASES.get(p.lower(), "xx")) == 1:
            out.append(p.lower())                # a code that is also a letter's name (DEE = "Dee" = d)
        elif (p.isupper() and len(p) <= 4 and (i == 0 or not p.isalpha() or p in SPELLED_CODES
                                                or not re.search(r"[AEIOUY]", p))) or                 (p.isalpha() and len(p) <= 2 and not re.search(r"[AEIOUYaeiouy]", p)):
            out.append("-".join(p.upper()))
        else:
            out.append(p.lower())
    return " · ".join(out)


@dataclass
class IdHit:
    file_id: str
    score: float
    start_word: int
    end_word: int   # exclusive


def find_id_calls(words: list[str], candidates: list[str], min_score: float = 0.84, max_words: int = 16,
                  breaks: list[bool] | None = None) -> list[IdHit]:
    """Finds spoken line IDs in a transcript (a list of words). candidates: the IDs this actor may say.
    breaks[i] = a pause (>= ~0.4 s) before word i: an ID call starts after a pause (or at the start).
    Returns non-overlapping hits in order."""
    canon = {c: canon_id(c) for c in candidates}
    by_first: dict[str, list[str]] = {}
    for c, k in canon.items():
        if k:
            by_first.setdefault(k[0], []).append(c)
    hits: list[IdHit] = []
    i = 0
    n = len(words)
    while i < n:
        if breaks is not None and i > 0 and not breaks[i]:
            i += 1
            continue
        best: IdHit | None = None
        for j in range(i, min(n, i + max_words)):
            if breaks is not None and j > i and breaks[j] and best is not None and best.score >= 0.97:
                break
            acc = canon_id(" ".join(words[i:j + 1]))
            if len(acc) < 3:
                continue
            pool = by_first.get(acc[0], [])
            for c in pool:
                k = canon[c]
                if abs(len(k) - len(acc)) > max(3, len(k) // 3):
                    continue
                sm = difflib.SequenceMatcher(None, acc, k, autojunk=False)
                if sm.real_quick_ratio() < min_score or sm.quick_ratio() < min_score:
                    continue
                r = sm.ratio()
                # digits must agree exactly (DOWN_01 vs DOWN_10 differ by one char but are different lines)
                if re.findall(r"\d+", acc) != re.findall(r"\d+", k):
                    r -= 0.2
                if r >= min_score and (best is None or r > best.score + 1e-9):
                    best = IdHit(c, r, i, j + 1)
        if best is not None:
            hits.append(best)
            i = best.end_word
        else:
            i += 1
    return hits


# ───────────────────────────────────────────────────────────── consent

@dataclass
class Consent:
    ok: bool
    date: str = ""
    name: str = ""
    ai_cloning: bool = False
    why: str = ""


def read_consent(actor: str, inbox: str | None = None) -> Consent:
    """voice_inbox/<actor>/consent.txt: the actor's "I agree" to VOICE_RELEASE.txt, with the date. Without it the
    importer ships nothing of theirs. AI cloning only when the file says so explicitly ("ai_voice_cloning: yes")."""
    p = os.path.join(inbox or INBOX_DIR, actor, "consent.txt")
    if not os.path.exists(p):
        return Consent(False, why="no %s" % os.path.relpath(p, ROOT).replace(os.sep, "/"))
    with open(p, encoding="utf-8", errors="replace") as f:
        txt = f.read()
    low = txt.lower()
    m = re.search(r"(\d{4}-\d{2}-\d{2})", txt) or re.search(r"(\d{1,2}[/.]\d{1,2}[/.]\d{2,4})", txt)
    if not m:
        return Consent(False, why="consent.txt has no date (write e.g. date: 2026-10-30)")
    if "agree" not in low:
        return Consent(False, why='consent.txt does not say "I agree"')
    if re.search(r"\b(withdraw|withdrawn|revoke|revoked|remove me)\b", low):
        return Consent(False, date=m.group(1), why="consent withdrawn")
    nm = re.search(r"^\s*name\s*[:=]\s*(.+)$", txt, re.I | re.M)
    ai = re.search(r"^\s*ai[_ ]voice[_ ]cloning\s*[:=]\s*(yes|y|true|opt in|i opt in)\s*$", txt, re.I | re.M) is not None
    return Consent(True, date=m.group(1), name=(nm.group(1).strip() if nm else actor), ai_cloning=ai)


CONSENT_TEMPLATE = """I agree.
I have read VOICE_RELEASE.txt (version 1) and my recordings may be used as it says.
name: {name}
date: {date}
ai_voice_cloning: no
"""


# ───────────────────────────────────────────────────────────── the cast sheet

def load_cast(path: str | None = None) -> dict:
    return load_json(path or CAST_PATH)


def actors_for(cast: dict, game: str, char: str) -> list[str]:
    """The actor ids voicing a character; an unfilled slot ("[...]" or empty) is its own placeholder actor
    'slot_<code>' so every cast slot still gets a script."""
    c = cast.get("characters", {}).get(game, {}).get(char, {})
    a = c.get("actor", "")
    vals = a if isinstance(a, list) else [a]
    out = []
    for v in vals:
        if is_placeholder(v):
            out.append(slot_actor(game, char))
        else:
            out.append(slug(str(v)))
    return out or [slot_actor(game, char)]


def slot_actor(game: str, char: str) -> str:
    return ("slot_" if game == "gl" else "slot_bs_") + slug(char)


def slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_") or "unknown"


def actor_name(cast: dict, actor: str) -> str:
    a = cast.get("actors", {}).get(actor, {})
    n = a.get("name", "")
    if n and not is_placeholder(n):
        return str(n)
    if actor.startswith("slot_"):
        for game, chars in cast.get("characters", {}).items():
            for code in chars:
                if slot_actor(game, code) == actor:
                    return "Unassigned: " + character_label(cast, game, code)
        return "Unassigned (%s)" % actor
    return actor.replace("_", " ").title()


def character_label(cast: dict, game: str, char: str) -> str:
    c = cast.get("characters", {}).get(game, {}).get(char, {})
    return str(c.get("name", char))


# ───────────────────────────────────────────────────────────── every spoken line

@dataclass
class Line:
    file_id: str                 # the recording ID = the audio file name the game plays
    line_id: str                 # the game's line id (= file_id unless an exchange part or a name variant)
    game: str                    # "gl" | "bs"
    char: str                    # cast code: DUT, HAM, sprocket...
    text: str                    # the line as written (directions, {stress})
    category: str
    delivery: str
    context: str
    res_path: str                # where the game plays it from
    section: str = ""            # grouping heading in the script
    cues: list = field(default_factory=list)    # [[speaker, text, is_this_line], ...] for conversations
    order: int = 0
    vocal_only: bool = False     # a hum / giggle with no words
    speech: str = ""             # T-154 / U11 C3: what is said when it differs from the subtitle (German, Russian...)
    lang: str = ""               # a line's spoken language when the source names one (lines.json "lang", FP [de])

    @property
    def script_sha(self) -> str:
        return sha16(self.text)

    @property
    def speaker_dir(self) -> str:
        return self.res_path.split("/")[-2] if self.game == "gl" else ""


def gl_delivery(category: str, text: str, vcast: dict) -> str:
    cats = vcast.get("categories", {})
    best, blen = "calm", -1
    for pre, emo in cats.items():
        if pre.startswith("_"):
            continue
        if category.startswith(pre) and len(pre) > blen:
            best, blen = emo, len(pre)
    say = spoken_text(text)
    if best in ("calm", "brisk") and say.rstrip().endswith("!"):
        best = "raised"
    low = " ".join(directions(text)).lower()
    if "scream" in low or "shout" in low:
        best = "shout"
    elif "whisper" in low or "quiet" in low or "faint" in low:
        best = "quiet" if best not in ("shout", "hurt") else best
    elif "hurt" in low or "weak" in low:
        best = "hurt"
    return best


def bs_delivery(text: str) -> str:
    say = spoken_text(text)
    words = re.findall(r"[A-Za-z]{2,}", say)
    caps = sum(1 for w in words if w.isupper() and len(w) >= 3)
    low = " ".join(directions(text) + re.findall(r"\*([^*]+)\*", text)).lower()
    if "scream" in low or "shout" in low or (words and caps / len(words) > 0.6 and len(words) >= 3):
        return "shout"
    if "whisper" in low or "quiet" in low:
        return "quiet"
    if say.count("!") >= 2 or caps >= 2:
        return "raised"
    if say.endswith("!"):
        return "brisk"
    return "calm"


def context_for(category: str, condition: str = "") -> str:
    best, blen = "", -1
    for pre, ctx in CONTEXT.items():
        if (category.startswith(pre) or ("_" + pre) in ("_" + category)) and len(pre) > blen:
            best, blen = ctx, len(pre)
    out = ("plays when " + best) if best else ""
    if condition:
        out = (out + "; " if out else "") + condition
    return out


def _vocal_direction(text: str) -> bool:
    low = " ".join(directions(text)).lower()
    return any(w in low for w in VOCAL_DIRECTIONS)


def collect_gl(vcast: dict | None = None) -> list[Line]:
    vcast = vcast if vcast is not None else load_json(GL_VOICE_CAST)
    lines = load_json(GL_LINES)
    out: list[Line] = []
    for lid, rec in lines.items():
        spk = str(rec.get("speaker", ""))
        cat = str(rec.get("category", ""))
        cond = str(rec.get("condition", ""))
        ex = rec.get("exchange")
        if ex:
            parts = [[str(p[0]), str(p[1])] for p in ex]
            for i, (ps, pt) in enumerate(parts):
                say = spoken_text(pt)
                vocal = not re.search(r"[A-Za-z0-9]", say)
                if vocal and not _vocal_direction(pt):
                    continue
                fid = "%s_p%d" % (lid, i)
                cues = [[s, t, k == i] for k, (s, t) in enumerate(parts)]
                sec = "Conversation: " + " & ".join(dict.fromkeys(SPEAKER_NAMES_GL.get(s, s) for s, _ in parts))
                out.append(Line(fid, lid, "gl", ps, pt, cat, gl_delivery(cat, pt, vcast), context_for(spk if spk in GL_CONTAINERS else cat, cond),
                                GL_AUDIO_RES + "%s/%s.ogg" % (ps.lower(), fid), sec, cues, i, vocal))
            continue
        if spk in GL_CONTAINERS:
            continue
        say = spoken_text(rec.get("text", ""))
        vocal = not re.search(r"[A-Za-z0-9]", say)
        if vocal and not _vocal_direction(rec.get("text", "")):
            continue
        out.append(Line(lid, lid, "gl", spk, str(rec.get("text", "")), cat, gl_delivery(cat, str(rec.get("text", "")), vcast),
                        context_for(cat, cond), GL_AUDIO_RES + "%s/%s.ogg" % (spk.lower(), lid), cat.replace("_", " "),
                        vocal_only=vocal, speech=str(rec.get("speech", "") or ""),
                        lang=str(rec.get("lang", "") or rec.get("speech_lang", "") or "")))
    # Boss files: the Cousins (and the Operator's lines for their round)
    names = cousin_names()
    for fn in sorted(os.listdir(GL_BOSSES)) if os.path.isdir(GL_BOSSES) else []:
        if not fn.endswith(".json") or fn == "likeness.json":
            continue
        d = load_json(os.path.join(GL_BOSSES, fn))
        for lid, rec in (d.get("lines", {}) or {}).items():
            if lid.startswith("_") or not isinstance(rec, dict) or lid in lines:
                continue
            spk_raw = str(rec.get("speaker", ""))
            code = COUSIN_CODES.get(spk_raw, spk_raw.upper())
            text = str(rec.get("text", ""))
            say = spoken_text(text)
            vocal = not re.search(r"[A-Za-z0-9]", say)
            if vocal and not _vocal_direction(text):
                continue
            cat = re.sub(r"_\d+$", "", lid)
            cat = cat[len(code) + 1:] if cat.startswith(code + "_") else cat
            sec = "Boss: " + fn[:-5].title()
            ctx = "the Cousins' round (Crossroads Inn, round 10)" if fn == "cousins.json" else ""
            if DEAD_NAME in text:
                # one take per cousin who can have fallen (the game plays <id>_<CODE>.ogg for that cousin)
                for other, slot in COUSIN_SLOTS.items():
                    if other == code:
                        continue
                    nm = names.get(slot, other)
                    t2 = text.replace(DEAD_NAME, nm)
                    fid = "%s_%s" % (lid, other)
                    out.append(Line(fid, lid, "gl", code, t2, cat, gl_delivery(cat, t2, vcast),
                                    ctx + ("; " if ctx else "") + "when %s has fallen" % nm,
                                    GL_AUDIO_RES + "%s/%s.ogg" % (code.lower(), fid), sec))
                continue
            out.append(Line(lid, lid, "gl", code, text, cat, gl_delivery(cat, text, vcast) if code != "CSN" else "quiet",
                            ctx, GL_AUDIO_RES + "%s/%s.ogg" % (code.lower(), lid), sec, vocal_only=vocal))
    return out


def cousin_names() -> dict:
    lk = load_json(GL_LIKENESS)
    out = {}
    for slot, b in (lk.get("bosses", {}) or {}).items():
        n = str(b.get("real_name", ""))
        if is_placeholder(n):
            n = str(b.get("real_name_default", "")) or slot
        out[slot] = n
    return out


def _bs_table(name: str):
    p = os.path.join(ROOT, "data", *name.split("/")) + ".json"
    return load_json(p) if os.path.exists(p) else None


def bs_section(lid: str) -> str:
    if lid.startswith("cs.ad"):
        return "Weapon commercials"
    if lid.startswith("cs."):
        return "Cutscene: " + lid.split(".")[1]
    if lid.startswith("bs.boss."):
        return "Boss: " + lid.split(".")[2]
    if lid.startswith("lr."):
        return "Loop Riot"
    if lid.startswith("bs."):
        return lid.split(".")[1].replace("_", " ").title()
    return lid.split(".")[0]


def collect_bs() -> list[Line]:
    out: list[Line] = []
    seen: set[str] = set()
    for tname, key in BS_LINE_SOURCES:
        t = _bs_table(tname)
        if isinstance(t, dict) and key:
            t = t.get(key, {})
        if not isinstance(t, dict):
            continue
        for lid, rec in t.items():
            if lid.startswith("_") or not isinstance(rec, dict) or lid in seen:
                continue
            who = str(rec.get("who", ""))
            text = rec.get("text", "")
            if not isinstance(text, str) or who in BS_NOT_SPOKEN or who == "":
                continue
            who = BS_WHO_ALIAS.get(who, who)
            say = spoken_text(text)
            if not re.search(r"[A-Za-z]", say):
                continue
            seen.add(lid)
            kind = str(rec.get("kind", ""))
            cat = ".".join(lid.split(".")[:2])
            ctx = {"bark": "a gameplay bark", "dialogue": "dialogue"}.get(kind, "")
            out.append(Line(lid, lid, "bs", who, text, cat, bs_delivery(text), ctx, BS_AUDIO_RES + lid + ".ogg",
                            bs_section(lid)))
    return out


def collect_all() -> list[Line]:
    return collect_gl() + collect_bs()


# ───────────────────────────────────────────────────────────── The Fine Print (script only, U11 T-193)
# The Fine Print exists as a script (docs/fineprint/script_ch1..5.md, 2778 ids) and is not built yet. Its lines are
# read from the script for the ElevenLabs plan / bake (tools/voice/eleven.py); they are not in collect_all(),
# so the recording scripts, the importer and the review page are unchanged. Its speaker ids are B&S VOManager ids,
# so a take goes where B&S plays recorded lines (res://audio/vo/<id>.ogg, the B&S manifest).
FP_DIR = os.path.join(ROOT, "docs", "fineprint")
# speaker labels in the script that are on-screen text, never voiced
FP_NOT_SPOKEN = {"text", "sys"}
# script labels -> speaker ids (the rest are slugged: "CUSTOMS MAN" -> customs_man)
FP_LABELS = {"the board": "darkmatter", "operator": "operator", "wren": "wren", "dutch": "dutch", "peg": "peg",
             "deacon": "deacon", "fasbender": "fasbender", "reinholt": "reinholt", "jakub": "jakub"}
# a speaker-less table's speaker, from words in the heading above it (first hit wins)
FP_HEADING_SPEAKERS = [("operator", "operator"), ("the pa", "dm_pa"), ("dm_pa", "dm_pa"), ("exit survey", "exit_survey"),
                       ("exit_survey", "exit_survey"), ("glambot", "glambot"), ("blartz", "blartz"),
                       ("underwriter", "underwriter"), ("repossessor", "repossessor"), ("sprocket", "sprocket"),
                       ("bolt", "bolt"), ("vendelin", "vendelin"), ("sable", "sable"), ("warden", "churn_warden"),
                       ("courtesy", "courtesy"), ("upsell", "upsell_drone"), ("associate", "associate")]
# a speaker-less table's speaker from its pool (scene) name, before the heading is tried
FP_SCENE_SPEAKERS = [("op_", "operator"), ("operator", "operator"), ("uw_", "underwriter"), ("fas_", "fasbender"),
                     ("omega_blartz", "blartz"), ("board", "darkmatter"), ("repo", "repossessor")]
# table columns that hold the spoken line (first match); tables with none of these are not voiced (rewards, titles)
FP_TEXT_COLUMNS = ("line", "clause", "question")
FP_LANG_TAGS = {"de": "de", "pl": "pl", "en": "en", "gsw": "en", "sil": "en"}   # the text is English (script_ch2 §0)


def fp_speaker(label: str) -> str:
    """A script label -> speaker id ("VENDELIN (V.O.)" -> vendelin, "BRÜCK" -> bruck). An Archive document label
    ("FINAL REPORT (transcript).", "JOSEPHINE (equipment card).") -> "text" (on-screen, not voiced)."""
    raw = label.strip()
    if raw.endswith(".") or re.search(r"\((?!v\.o\.\))[^)]*\)", raw, re.I):
        return "text"
    s = re.sub(r"\(v\.o\.\)", "", raw.strip(":").strip(), flags=re.I).strip().strip(":").strip().lower()
    import unicodedata
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    return FP_LABELS.get(s, slug(s))


def _fp_heading_speaker(heading: str, known: set[str]) -> str:
    low = heading.lower()
    for tok in re.findall(r"`([a-z_]+)`", low):
        if tok in known:
            return tok
    for word, spk in FP_HEADING_SPEAKERS:
        if word in low:
            return spk
    return ""


def collect_fp(folder: str | None = None) -> list[Line]:
    """Every voiced Fine Print line in the script: '- `fp.c1.x.01` **SPEAKER** `[de]`: text' bullets and the bark /
    clause tables (`| ID | Speaker | Line |`, or `| ID | Trigger | Line |` under a heading naming the speaker)."""
    folder = folder or FP_DIR
    out: list[Line] = []
    seen: set[str] = set()
    bullet = re.compile(r"^- `((?:fp|gl)\.[a-z0-9_.]+\.\d+)` \*\*([^*]+?)\*\*\s*(?:`\[([a-z]+)\]`)?\s*:?\s*(.*)$")
    files = sorted(glob_files(folder, "script_ch*.md"))
    known: set[str] = set()
    for p in files:
        for ln in open(p, encoding="utf-8").read().splitlines():
            m = bullet.match(ln)
            if m:
                known.add(fp_speaker(m.group(2)))
    for p in files:
        rows = open(p, encoding="utf-8").read().splitlines()
        heading = ""
        header: list[str] = []
        for i, raw in enumerate(rows):
            if raw.startswith("#"):
                heading, header = raw, []
                continue
            m = bullet.match(raw)
            if m:
                fid, label, tag, text = m.group(1), m.group(2), m.group(3) or "", m.group(4)
                spk = fp_speaker(label)
                if spk in FP_NOT_SPOKEN or fid in seen:
                    continue
                if not re.search(r"[A-Za-z]", spoken_text(re.sub(r"\*\[[^\]]*\]\*", " ", text))):
                    continue
                seen.add(fid)
                out.append(_fp_line(fid, spk, text, FP_LANG_TAGS.get(tag, ""), heading))
                continue
            if raw.startswith("|"):
                cells = [c.strip() for c in raw.strip().strip("|").split("|")]
                if i + 1 < len(rows) and re.match(r"^\|[\s:|-]+\|\s*$", rows[i + 1]):
                    header = [c.lower() for c in cells]
                    continue
                if not header or not re.match(r"^`((?:fp|gl)\.[a-z0-9_.]+\.\d+)`$", cells[0] if cells else ""):
                    continue
                fid = cells[0].strip("`")
                col = next((k for k, h in enumerate(header) for w in FP_TEXT_COLUMNS if h.startswith(w)), -1)
                if col < 0 or col >= len(cells) or fid in seen:
                    continue
                spk = ""
                if "speaker" in header and header.index("speaker") < len(cells):
                    spk = fp_speaker(cells[header.index("speaker")].strip("`*"))
                if not spk:
                    scene = fid.split(".")[2] if fid.count(".") >= 3 else ""
                    spk = "operator" if fid.startswith("gl.all.operator") else (next(
                        (v for k, v in FP_SCENE_SPEAKERS if scene.startswith(k)), "")
                        or next((seg for seg in fid.split(".")[1:-1] if seg in known), "")
                        or _fp_heading_speaker(heading, known))
                if not spk or spk in FP_NOT_SPOKEN:
                    spk = "unassigned"
                text = cells[col]
                if "beam text" in heading.lower() or not re.search(r"[A-Za-z]", spoken_text(text)):
                    continue
                seen.add(fid)
                out.append(_fp_line(fid, spk, text, "", heading))
    return out


def _fp_line(fid: str, spk: str, text: str, lang: str, heading: str) -> Line:
    text = re.sub(r"\*\[([^\]]*)\]\*", r"[\1]", text).strip()     # *[italic direction]* -> [direction]
    sec = re.sub(r"^#+\s*", "", heading).strip() or fid.split(".")[1]
    return Line(fid, fid, "fp", spk, text, ".".join(fid.split(".")[:3]), bs_delivery(text), "", BS_AUDIO_RES + fid + ".ogg",
                "The Fine Print: " + sec, lang=lang)


def glob_files(folder: str, pattern: str) -> list[str]:
    import glob as _g
    return _g.glob(os.path.join(folder, pattern))


def lines_by_actor(lines: list[Line], cast: dict) -> dict[str, list[Line]]:
    out: dict[str, list[Line]] = {}
    for ln in lines:
        for a in actors_for(cast, ln.game, ln.char):
            out.setdefault(a, []).append(ln)
    return out


def recording_order(lines: list[Line]) -> list[Line]:
    """Same emotion together, shouting last (it tires the voice); stable by character, section and id inside."""
    def key(ln: Line):
        conv = ln.section.startswith("Conversation")
        return (DELIVERY_ORDER.index(ln.delivery) if ln.delivery in DELIVERY_ORDER else 1, ln.char, conv, ln.section, ln.file_id)
    return sorted(lines, key=key)


def script_index(lines: list[Line]) -> dict:
    return {ln.file_id: ln.script_sha for ln in lines}


# ───────────────────────────────────────────────────────────── manifests

def load_manifest(game: str) -> dict:
    if game == "gl":
        return load_json(GL_MANIFEST, {"files": {}, "missing": {}})
    m = load_json(BS_MANIFEST, {})
    m.setdefault("files", {})
    return m


def save_manifest(game: str, m: dict) -> None:
    if game == "gl":
        m["files"] = dict(sorted(m.get("files", {}).items()))
        m["missing"] = dict(sorted(m.get("missing", {}).items()))
        save_json(GL_MANIFEST, m, sort=False)
    else:
        m["_doc"] = ("Bolt & Sprocket voice manifest (T-101, tools/voice/import.py): every voiced line id. source tts = "
                     "the game's runtime text-to-speech (core/vo_manager.gd, no file); human = a recorded take at path "
                     "(res://audio/vo/<id>.ogg) with the actor, the take id and the file hash; ai_* = ElevenLabs "
                     "(tools/voice/eleven.py, always marked).")
        m["files"] = dict(sorted(m.get("files", {}).items()))
        save_json(BS_MANIFEST, m, sort=False)


def human_row(ln: Line, actor: str, take: str, path_hash: str, duration: float, lufs: float, fx: str,
              consent_date: str, source: str = "human") -> dict:
    return {"line": ln.line_id, "speaker": ln.char, "path": ln.res_path, "format": "ogg", "duration": round(duration, 3),
            "source": source, "actor": actor, "take": take, "hash": path_hash[:16], "script_sha": ln.script_sha,
            "fx": fx, "lufs": round(lufs, 2), "consent_date": consent_date, "imported": today()}


def write_csv(path: str, rows: list[list[str]]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    for r in rows:
        w.writerow(r)
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        f.write(buf.getvalue())


def venv_python() -> str:
    """tools/venv's interpreter (Windows Scripts/python.exe, Linux bin/python); a worktree falls back to the main
    checkout's tools/venv; else the running interpreter."""
    for base in (ROOT, _main_checkout()):
        if not base:
            continue
        for rel in (("tools", "venv", "Scripts", "python.exe"), ("tools", "venv", "bin", "python")):
            p = os.path.join(base, *rel)
            if os.path.exists(p):
                return p
    return sys.executable


def _main_checkout() -> str:
    # .wt/<branch> worktrees: the main checkout is two levels up and has its own .git directory
    p = os.path.dirname(os.path.dirname(ROOT))
    return p if os.path.isdir(os.path.join(p, ".git")) else ""
