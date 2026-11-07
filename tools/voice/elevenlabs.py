#!/usr/bin/env python3
"""ElevenLabs: the default voice bake for every voice in the game (UPDATE 11 section 7, T-193; the first, optional
version was UPDATE 06 B6, T-101). Docs: docs/VOICES.md (casting, model, how to bake), docs/VOICE_ACTING.md.

  tools/voice.sh elevenlabs plan [--only=GROUP] [--no-write]
        characters still to bake per priority group (spoken text after tag handling, minus cached takes and lines a
        human take covers), the account's quota, and the plan size it needs -> morning/NEEDS_DEVIN.md
  tools/voice.sh elevenlabs bake [--only=GROUP] [--limit-chars=N] [--ids=A,B] [--dry-run]
        bakes in priority order (GROUPS below) into the files the game already plays; every take cached, so nothing is
        paid for twice; stops cleanly on quota / auth / rate limits and resumes on the next run
  tools/voice.sh elevenlabs voices [--library] [--search=..] [--accent=..] [--gender=..] [--age=..] [--language=..]
        the account's voices (or the shared Voice Library) with accent / age / gender labels
  tools/voice.sh elevenlabs assign --char=gl:DUT --voice=<voice id> [--name=..] [--why=..]
        puts a library voice on a character (cast.json characters.<game>.<code>.eleven)
  tools/voice.sh elevenlabs design --char=gl:SER [--prompt=..] [--text=..]      Voice Design previews (saved, listed)
  tools/voice.sh elevenlabs design --char=gl:SER --pick=N                       creates the picked voice, stores its id
  tools/voice.sh elevenlabs sfx --name=risen_groan_01 --prompt=.. [--seconds=4] [--loop] [--out=path.ogg]
        a sound effect (text-to-sound-effects), cached like the voices
  tools/voice.sh elevenlabs check [--out=DIR]     the tiny live check (<= 3 lines, < 300 characters, a scratch dir)
  tools/voice.sh elevenlabs stock|sts|clone ...   T-101: one gap line / voice changer / a consented clone

GROUPS (bake order, --only takes the number or the name): 1 cutscenes (*_LZS_*, *_FTD_*, *_STB_*, *_GL1_*, SER VOL
SVR RTN BRG NAR), 2 squad, 3 operator, 4 npcs, 5 bosses, 6 barks, 7 fineprint, 8 bs.

The key: ELEVENLABS_API_KEY from the environment, else the git-ignored .env.local of this checkout or of the main
checkout (npx @elevenlabs/cli onboard writes it). It is only ever put in os.environ: never written, logged or printed,
and every API error is scrubbed (no headers) before it is shown. Without a key everything here says how to set it up
and the bake falls back to Kokoro / OneCore (gravelight/tools_src/gen_vo.py) or the B&S runtime TTS.
A recorded human take always wins; every take made here is marked source ai_eleven, "ai": true (manifest + review
page). No clone of a real person without their consent.txt saying "ai_voice_cloning: yes".
"""
from __future__ import annotations

import argparse
import base64
import datetime as _dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402
import pipeline as P  # noqa: E402

# ───────────────────────────────────────────────────────────── settings

# Eleven v4: the current best ElevenLabs model for expressive dialogue (audio tags: [whispers] [shouting] [crying]
# [exhausted] [breathing heavily]...), 90+ languages with language_code honoured, one model for the English, German,
# Russian and Polish lines. It takes only stability and similarity_boost (no style / speed / SSML).
TTS_MODEL = "eleven_v4"
STS_MODEL = "eleven_multilingual_sts_v2"
SFX_MODEL = "eleven_text_to_sound_v3"
DESIGN_MODEL = "eleven_ttv_v3"
FORMAT_PCM = "pcm_44100"          # raw 16-bit mono 44.1 kHz (Pro+ plans); refused -> FORMAT_MP3, decoded by ffmpeg
FORMAT_MP3 = "mp3_44100_128"
PCM_RATE = 44100
SOURCE = "ai_eleven"
DEFAULT_SETTINGS = {"stability": 0.5, "similarity_boost": 0.75}
CREDITS_PER_CHAR = 1.0            # v4 bills one credit per character sent (checked against x-character-count)
KEY_VAR = "ELEVENLABS_API_KEY"
SETUP_HINT = ("ElevenLabs is off: no %s. Setup, once: run `npx @elevenlabs/cli onboard` in the repo root (it stores "
              "the key in the git-ignored .env.local), or set %s in the environment." % (KEY_VAR, KEY_VAR))
GROUPS = {1: "cutscenes", 2: "squad", 3: "operator", 4: "npcs", 5: "bosses", 6: "barks", 7: "fineprint", 8: "bs"}
GROUP_TITLES = {1: "the new cutscenes", 2: "the squad", 3: "the Operator", 4: "the map NPCs", 5: "the bosses",
                6: "barks", 7: "The Fine Print", 8: "Bolt & Sprocket"}
# Plans by monthly credits (elevenlabs.io/pricing; check the page before buying)
PLANS = [("Free", 10_000), ("Starter", 30_000), ("Creator", 100_000), ("Pro", 500_000), ("Scale", 2_000_000),
         ("Business", 11_000_000)]
BATCH = 20                        # lines per credits-log batch (and per manifest save)
RETRIES = 4
NEEDS_HEADING = "## UPDATE 11: ElevenLabs"

CUTSCENE_RE = re.compile(r"^[A-Z0-9]{2,4}_(LZS|FTD|STB|GL1|EPI53)_")
CUTSCENE_SPEAKERS = {"SER", "VOL", "SVR", "RTN", "BRG", "NAR"}
SQUAD = {"DUT", "PEG", "DEA", "WRN", "JAK"}
BOSSES = {"HAM", "RCH", "ALX", "CSN", "PAU", "SLN", "KLH"}
# gameplay-trigger categories (a bark plays from a game event, not a scene); longest-prefix match not needed
BARK_PREFIXES = ("RELOAD", "AMMO_", "BOARD", "REVIVE", "DOWN", "TEAM_DOWN", "HEADSHOT", "STREAK", "SPAWN",
                 "ROUND_START", "ROUND_END", "BUY_", "CRATE_", "PERK_", "DENY_", "MARK_", "MARKE_KILL", "PING_",
                 "CMD_", "PWR_", "POWERUP_", "BONUS_", "SPRINTER_", "WINDOW_OPEN", "COVER", "CRAWLER", "SCREAMER",
                 "GLASSHIDE", "FOREMAN", "BELL", "EXHAUST", "CHATTER", "EE_ACK", "EE_CANT", "EE_WAIT", "EE_DONE",
                 "EE_PROGRESS", "EE_RESUME", "EE_INTERRUPTED", "EE_HANDOFF", "EE_PLAYER_ONLY", "EE_COMMIT",
                 "EE_REFUSE", "GUNSMITH", "GUN_", "ECO_", "LATE_KIT", "TALLY", "DOOR", "TRAP", "CRUCIBLE",
                 "BOSS_INCOMING", "KILL", "BARK", "PEOPLE_DOWN", "PEOPLE_PING", "PEOPLE_ROUND", "SURV_", "COMP_",
                 "FIGHT_KILL", "MARK", "GRUMBLE")
GL_CAST_ALIAS = {}                # speaker code -> cast code (none needed: PAU / SLN have their own entries)

# Tag handling: gen_vo.py turns [directions] into effect cues; v4 takes delivery tags. Effect words are stripped from
# the text and applied after synthesis (the same DSP as the TTS bake); delivery words become v4 tags; a short tag
# nobody maps (one to three plain words) passes through as a v4 tag; a long stage direction is dropped.
EFFECT_WORDS = {"radio": "radio", "telephone": "radio", "phone": "radio", "intercom": "radio", "static": "static",
                "crackle": "static", "hiss": "", "distant": "distant", "far away": "distant", "slowed": "slowed",
                "tannoy": "", "megaphone": "", "close to the horn": "", "keys": "", "clicks": "", "chk": "",
                "muffled": "distant", "through the door": "distant", "echo": "", "overlapping": "", "distorted": "",
                "channel": "", "tape": "", "cylinder": "", "phonograph": "", "pa": ""}
DELIVERY_WORDS = [("whisper", "whispers"), ("shout", "shouting"), ("yell", "shouting"), ("bellow", "shouting"),
                  ("roar", "shouting"), ("scream", "screams"), ("shriek", "screams"), ("laugh", "laughs"),
                  ("chuckl", "chuckles"), ("giggl", "giggles"), ("sigh", "sighs"), ("sob", "crying"),
                  ("cry", "crying"), ("crying", "crying"), ("tearful", "crying"), ("exhaust", "exhausted"),
                  ("tired", "exhausted"), ("weary", "exhausted"), ("breathless", "breathing heavily"),
                  ("panting", "breathing heavily"), ("breath", "breathing heavily"), ("gasp", "gasps"),
                  ("cough", "coughs"), ("hum", "hums"), ("sing", "sings"), ("pray", "quietly"),
                  ("quiet", "quietly"), ("soft", "quietly"), ("hushed", "quietly"), ("murmur", "quietly"),
                  ("low voice", "quietly"), ("faint", "quietly"), ("terrified", "terrified"), ("scared", "scared"),
                  ("afraid", "scared"), ("nervous", "nervous"), ("frighten", "scared"), ("cheerful", "cheerfully"),
                  ("bright", "cheerfully"), ("flat", "flatly"), ("deadpan", "deadpan"), ("sarcas", "sarcastic"),
                  ("angry", "angry"), ("furious", "angry"), ("pain", "pained"), ("hurt", "pained"),
                  ("wounded", "pained"), ("calm", "calmly"), ("excited", "excited")]
STRONG_TAGS = {"whispers", "shouting", "screams", "laughs", "chuckles", "giggles", "sighs", "crying", "gasps",
               "coughs", "breathing heavily", "sings", "hums"}
EFFECT_WORDS.update({"crackling": "static", "squeal": "", "tape squeal": "", "feedback": ""})
PAUSE_WORDS = ("pause", "beat", "silence")
DELIVERY_ADJ = {"weak", "defeated", "delighted", "warm", "cold", "triumphant", "half-sung", "curious", "sad", "grim",
                "bitter", "proud", "relieved", "resigned", "desperate", "pleading", "urgent", "firm", "tender", "wistful",
                "haunted", "dazed", "numb", "hoarse", "shaky", "trembling", "awed", "reverent", "solemn", "mocking",
                "amused", "dry", "smug", "bored", "panicked", "frantic", "hesitant", "uncertain", "certain", "slower",
                "faster", "low", "private", "grave", "hollow", "broken", "breaking", "ragged", "strained", "kind",
                "stern", "fond", "wry", "teasing", "mischievous", "sleepy", "drowsy", "dreamy", "distracted", "very",
                "almost", "barely", "little"}
EN_WORDS = {"the", "a", "an", "is", "it", "you", "i", "we", "to", "of", "and", "in", "that", "this", "are", "was",
            "me", "my", "your", "here", "there", "what", "not", "no", "yes", "be", "on", "for", "with", "they", "he",
            "she", "get", "come", "go", "don't", "it's", "i'm", "all", "do", "have", "can"}
DELIVERY_TAG = {"shout": "shouting", "hurt": "pained", "quiet": "quietly", "mine": "whispers"}
POST_CUES = {"radio", "distant", "static", "slowed"}


class Refused(Exception):
    pass


class ApiStop(Exception):
    """The batch must stop (quota, auth, rate limit after retries, plan refuses something)."""
    def __init__(self, reason: str, status: int | None, code: str, message: str):
        super().__init__("%s (HTTP %s %s): %s" % (reason, status, code, message))
        self.reason, self.status, self.code, self.message = reason, status, code, message


class ApiLineError(Exception):
    """One line failed (bad text, 422); the batch goes on."""


# ───────────────────────────────────────────────────────────── paths

def main_checkout() -> str:
    """The main checkout's root (a git worktree shares its git-ignored files: the key, the take cache)."""
    try:
        cp = subprocess.run(["git", "-C", V.ROOT, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            capture_output=True, text=True, timeout=20)
        if cp.returncode == 0 and cp.stdout.strip():
            return os.path.dirname(os.path.abspath(cp.stdout.strip()))
    except (OSError, subprocess.SubprocessError):
        pass
    return V._main_checkout() or V.ROOT


def cache_dir() -> str:
    d = os.environ.get("GL_VOICE_CACHE") or os.path.join(main_checkout(), ".voice_cache", "eleven")
    os.makedirs(d, exist_ok=True)
    gd = os.path.join(os.path.dirname(d) if os.path.basename(d) == "eleven" else d, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    return d


def log_path() -> str:
    return os.environ.get("GL_ELEVEN_LOG") or os.path.join(V.ROOT, "logs", "elevenlabs.log")


def state_path() -> str:
    return os.path.join(cache_dir(), "bake_state.json")


NEEDS_PATH = os.path.join(V.ROOT, "morning", "NEEDS_DEVIN.md")


# ───────────────────────────────────────────────────────────── the key (never written, logged or printed)

def env_files() -> list[str]:
    """Where a .env.local may hold the key: this checkout, then the main checkout. GL_ELEVEN_KEYFILES=0 turns the
    files off (the tests do, so they never see the owner's key unless they ask)."""
    if os.environ.get("GL_ELEVEN_KEYFILES", "1") == "0":
        return []
    out = []
    for base in (V.ROOT, main_checkout()):
        p = os.path.join(base, ".env.local")
        if p not in out:
            out.append(p)
    return out


def _key_from_file(path: str) -> str:
    try:
        from dotenv import dotenv_values      # python-dotenv: parses, never prints values
        return str(dotenv_values(path).get(KEY_VAR) or "").strip()
    except ImportError:
        pass
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            m = re.match(r"^\s*(?:export\s+)?%s\s*=\s*(.*?)\s*$" % KEY_VAR, raw)
            if m:
                return m.group(1).strip().strip("'\"")
    return ""


def load_key() -> str:
    """The key: the environment first, else a .env.local (then put into os.environ only). '' when there is none."""
    k = os.environ.get(KEY_VAR, "").strip()
    if k:
        return k
    for p in env_files():
        if os.path.isfile(p):
            v = _key_from_file(p)
            if v:
                os.environ[KEY_VAR] = v
                return v
    return ""


def api_key() -> str:
    k = load_key()
    if not k:
        raise Refused(SETUP_HINT)
    return k


def have_key() -> bool:
    return bool(load_key())


def scrub(s) -> str:
    """Text safe to print or log: the key's value, anything key-shaped and any api-key header removed."""
    s = str(s)
    k = os.environ.get(KEY_VAR, "")
    if k and len(k) >= 8:
        s = s.replace(k, "[key]")
    s = re.sub(r"sk_[A-Za-z0-9]{16,}", "sk_[redacted]", s)
    s = re.sub(r"(xi-api-key|authorization)(['\"]?\s*[:=]\s*['\"]?)[^'\",\s}]+", r"\1\2[redacted]", s, flags=re.I)
    return s


def make_client(key: str | None = None):
    from elevenlabs import ElevenLabs
    return ElevenLabs(api_key=key or api_key(), timeout=180)


# ───────────────────────────────────────────────────────────── API errors

def describe(exc: Exception) -> tuple[int | None, str, str]:
    """(status, code, message) of an SDK error, without its headers."""
    status = getattr(exc, "status_code", None)
    body = getattr(exc, "body", None)
    code, msg = "", ""
    if isinstance(body, dict):
        det = body.get("detail", body)
        if isinstance(det, dict):
            code = str(det.get("status") or det.get("code") or det.get("type") or "")
            msg = str(det.get("message") or det.get("msg") or "")
        elif isinstance(det, list) and det:
            msg = "; ".join(str(d.get("msg", d)) if isinstance(d, dict) else str(d) for d in det[:3])
        else:
            msg = str(det)
    elif body is not None:
        msg = str(body)
    elif status is None:
        msg = "%s: %s" % (type(exc).__name__, exc)
    return status, scrub(code)[:80], scrub(msg)[:400]


def classify(status: int | None, code: str, msg: str) -> str:
    """quota | auth | rate | format | line | fatal"""
    low = (code + " " + msg).lower()
    if "output_format" in low or "output format" in low or "pcm_" in low:
        return "format"
    if "quota" in low or "credits" in low or "character_limit" in low or status == 402:
        return "quota"
    if status == 401:
        return "auth"
    if status == 429 or "too_many" in low or "busy" in low or (status is not None and status >= 500) or status is None:
        return "rate"
    if status in (400, 422):
        return "line"
    return "fatal"


# ───────────────────────────────────────────────────────────── text: what is said, the tags, the language

def _map_tag(tag: str) -> tuple[list[str], set[str], bool]:
    """One [direction] -> (v4 tags, post-processing cues, pause?)."""
    tags: list[str] = []
    cues: set[str] = set()
    pause = False
    for piece in re.split(r"[,;/]| then | and ", tag.lower()):
        p = piece.strip()
        if not p:
            continue
        n = len(p.split())
        hit = [t for w, t in DELIVERY_WORDS if re.search(r"\b" + re.escape(w), p)]
        if n > 4:                                # a long stage direction: only an unmistakable vocal word counts
            hit = [t for t in hit if t in STRONG_TAGS]
        fx = [c for w, c in EFFECT_WORDS.items() if re.search(r"\b" + re.escape(w) + r"\b", p)]
        if re.match(r"(to|at|into|toward|towards|over|under|from|in|on) ", p) and not hit:
            continue                             # blocking ("to Dutch", "at the window"), not a delivery
        for c in fx:
            if c:
                cues.add(c)
        if any(re.search(r"\b" + w + r"\b", p) for w in PAUSE_WORDS):
            pause = True
        if hit:
            for t in hit[:1]:
                if t not in tags:
                    tags.append(t)
        elif not fx and not pause and n <= 2 and all(w in DELIVERY_ADJ or (w.endswith("ly") and len(w) > 4)
                                                     for w in p.split()):
            tags.append(p)                       # a delivery word nobody maps ([weak], [slowly]): v4 reads it as is
        # anything else ([if present], [recovery], [orchestra swell], [click]) is a game or sound cue: not sent
    return tags, cues, pause


def prepare_text(text: str, speech: str = "", delivery: str = "", delivery_tags: bool = True) -> tuple[str, list[str]]:
    """The text sent to v4 and the effect cues applied afterwards. `speech` (what is said) wins over the subtitle;
    the subtitle's [directions] still count. (parentheticals) are glosses or stage notes and are not said; {splice}
    braces, *markers* and trade marks go; a direction-free shout / hurt / quiet line gets the matching v4 tag."""
    cues: set[str] = set()
    lead: list[str] = []
    src = speech.strip() or text
    if speech.strip():
        for m in re.finditer(r"\[([^\]]*)\]", text):
            tg, cs, _ = _map_tag(m.group(1))
            cues |= cs
            lead += [t for t in tg if t not in lead]

    def sub(m):
        tg, cs, pause = _map_tag(m.group(1))
        cues.update(cs)
        out = " ".join("[%s]" % t for t in tg)
        return (" " + out + " " if out else " ") + ("... " if pause else "")

    t = re.sub(r"\[([^\]]*)\]", sub, src)
    t = re.sub(r"\([^)]*\)", " ", t)
    t = t.replace("{", "").replace("}", "").replace("*", "").replace("™", "").replace("®", "").replace("♪", " ")
    t = re.sub(r"(\.\.\.\s*){2,}", "... ", t)
    t = re.sub(r"\s+([,!?;:]|\.(?!\.))", r"\1", t)
    t = re.sub(r"\s{2,}", " ", t).strip()
    if len(t) >= 2 and t[0] == '"' and t[-1] == '"':
        t = t[1:-1].strip()
    has_tag = bool(lead) or bool(re.search(r"\[[^\]]+\]", t))
    if lead:
        t = " ".join("[%s]" % x for x in lead) + " " + t
    if delivery_tags and not has_tag and delivery in DELIVERY_TAG and re.search(r"\w", t):
        t = "[%s] %s" % (DELIVERY_TAG[delivery], t)
    t = re.sub(r"^(\.\.\.\s*)+", "", t).strip()
    return t, sorted(cues)


def words_of(text: str) -> str:
    return re.sub(r"\[[^\]]*\]", " ", text)


def detect_lang(s: str) -> str:
    s = words_of(s)
    if re.search(r"[Ѐ-ӿ]", s):
        return "ru"
    if re.search(r"[ąćęłńśźżĄĆĘŁŃŚŹŻ]", s):
        return "pl"
    w = re.findall(r"[^\W\d_]+", s.lower())
    de = {"der", "die", "das", "und", "ist", "nicht", "wir", "sie", "ich", "bitte", "kommen", "ende", "hier", "zu",
          "ein", "eine", "mit", "auf", "im", "den", "dem", "bleibt", "melden", "wiederhole", "achtung"}
    if re.search(r"[äöüß]", s.lower()) or (w and sum(1 for x in w if x in de) >= max(2, len(w) // 6)):
        return "de"
    return ""


def line_lang(ln: V.Line, entry: dict, spoken: str) -> str:
    if ln.lang:
        return ln.lang
    if ln.speech:
        return detect_lang(ln.speech) or str(entry.get("language") or "en")
    base = str(entry.get("language") or "en")
    if base == "en":
        # a whole line in another language (Jakub's "Precz! Precz ode mnie!"): that language; a few foreign words
        # inside English stay English (the voice's accent carries them)
        other = detect_lang(spoken)
        w = re.findall(r"[^\W\d_']+(?:'[a-z]+)?", words_of(spoken).lower())
        if other == "ru" or (other and w and sum(1 for x in w if x in EN_WORDS) / len(w) < 0.12):
            return other
    return base


# ───────────────────────────────────────────────────────────── casting: a line -> its voice

def cast_entry(cast: dict, game: str, char: str, fid: str = "", depth: int = 0) -> tuple[dict | None, str, str]:
    """(the character's eleven block merged with any per-id-prefix block, game, code), following "same_as"."""
    chars = cast.get("characters", {}).get(game, {})
    code = GL_CAST_ALIAS.get(char, char) if game == "gl" else char
    e = chars.get(code)
    if e is None:
        return None, game, code
    if e.get("same_as") and depth < 3:
        g, c = str(e["same_as"]).split(":", 1)
        return cast_entry(cast, g, c, fid, depth + 1)
    el = dict(e.get("eleven") or {})
    if el.get("same_as_voice") and depth < 3:          # a cameo that shares another game's voice (Bolt in Map 4)
        g, c = str(el["same_as_voice"]).split(":", 1)
        return cast_entry(cast, g, c, fid, depth + 1)
    best = -1
    for pre, sub in (e.get("eleven_by_prefix") or {}).items():
        if fid.startswith(pre + "_") and len(pre) > best:
            merged = dict(e.get("eleven") or {})
            merged.update(sub)
            el, best = merged, len(pre)
    el.setdefault("actor", e.get("actor", ""))
    return el, game, code


def voice_for(cast: dict, ln: V.Line) -> tuple[dict | None, str]:
    """(eleven block with a voice_id, "") or (None / block, why there is no voice)."""
    if ln.game == "gl" and ln.char in V.GL_CONTAINERS:
        return None, "a container, not a voice (its exchange parts have their own speakers)"
    el, g, c = cast_entry(cast, ln.game, ln.char, ln.file_id)
    if el is None:
        return None, "no cast entry %s:%s in data/voice/cast.json" % (ln.game, ln.char)
    if el.get("none"):
        return el, "not voiced: %s" % el["none"]
    if not el.get("voice_id"):
        return el, "not cast yet: give characters.%s.%s.eleven a voice_id (T-201)" % (g, c)
    if el.get("source") == "clone":
        actor = str(el.get("consent_actor") or el.get("actor") or "")
        cs = V.read_consent(actor) if actor and not V.is_placeholder(actor) else None
        if not cs or not cs.ok or not cs.ai_cloning:
            return el, "REFUSED: a clone of %s without voice_inbox/%s/consent.txt saying 'ai_voice_cloning: yes'" % (
                actor or "a real person", actor or "<actor>")
    return el, ""


def settings_of(el: dict) -> dict:
    return {"stability": round(float(el.get("stability", DEFAULT_SETTINGS["stability"])), 3),
            "similarity_boost": round(float(el.get("similarity_boost", DEFAULT_SETTINGS["similarity_boost"])), 3)}


def group_of(ln: V.Line) -> int:
    if ln.game == "fp":
        return 7
    if ln.game == "bs":
        return 8
    if CUTSCENE_RE.match(ln.line_id) or ln.char in CUTSCENE_SPEAKERS:
        return 1
    if ln.char == "OPR":
        return 3
    if ln.char in BOSSES:
        return 5
    if ln.category.startswith(BARK_PREFIXES):
        return 6
    if ln.char in SQUAD:
        return 2
    return 4


def parse_group(s: str) -> int:
    s = str(s).strip().lower()
    if s.isdigit() and int(s) in GROUPS:
        return int(s)
    for n, name in GROUPS.items():
        if s in (name, name.rstrip("s")):
            return n
    raise Refused("unknown group %r: one of %s" % (s, ", ".join("%d %s" % kv for kv in GROUPS.items())))


def cache_key(text: str, voice_id: str, model: str, settings: dict, lang: str) -> str:
    blob = json.dumps({"text": text, "voice": voice_id, "model": model, "settings": settings, "lang": lang},
                      sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


@dataclass
class Job:
    ln: V.Line
    group: int
    text: str
    cues: list
    lang: str
    voice_id: str = ""
    voice_name: str = ""
    settings: dict = field(default_factory=dict)
    key: str = ""
    reason: str = ""          # why it can't be baked (no voice yet, refused, no speech)
    status: str = ""          # todo | cached | done | human | uncast | skip

    @property
    def chars(self) -> int:
        return len(self.text)


def collect(games=("gl", "fp", "bs")) -> list[V.Line]:
    out: list[V.Line] = []
    if "gl" in games:
        out += V.collect_gl()
    if "fp" in games:
        out += V.collect_fp()
    if "bs" in games:
        out += V.collect_bs()
    return out


def build_jobs(cast: dict | None = None, lines: list[V.Line] | None = None, games=("gl", "fp", "bs")) -> list[Job]:
    cast = cast if cast is not None else V.load_cast()
    lines = lines if lines is not None else collect(games)
    jobs = []
    for i, ln in enumerate(lines):
        el, why = voice_for(cast, ln)
        el = el or {}
        text, cues = prepare_text(ln.text, ln.speech, ln.delivery, bool(el.get("delivery_tags", True)))
        if not re.search(r"\w", words_of(text)) and not re.search(r"\[[^\]]+\]", text):
            why = why or "no speech (a stage direction only)"
        lang = line_lang(ln, el, text)
        st = settings_of(el)
        vid = str(el.get("voice_id") or "") if not why else ""
        j = Job(ln, group_of(ln), text, cues, lang, vid, str(el.get("voice_name") or ""), st,
                cache_key(text, vid, TTS_MODEL, st, lang) if vid else "", why)
        j._order = i  # type: ignore[attr-defined]
        jobs.append(j)
    jobs.sort(key=lambda j: (j.group, j._order))  # type: ignore[attr-defined]
    return jobs


# ───────────────────────────────────────────────────────────── the take cache

class TakeCache:
    """Raw API audio by sha256(spoken text, voice id, model, settings, language) in a git-ignored folder shared by
    every worktree (<main checkout>/.voice_cache/eleven/<k[:2]>/<k>.<pcm|mp3> + .json). A hit never calls the API."""

    def __init__(self, folder: str | None = None):
        self.dir = folder or cache_dir()

    def _base(self, key: str) -> str:
        return os.path.join(self.dir, key[:2], key)

    def get(self, key: str) -> tuple[bytes, dict] | None:
        b = self._base(key)
        if not os.path.exists(b + ".json"):
            return None
        meta = V.load_json(b + ".json")
        p = b + "." + ("mp3" if str(meta.get("format", "")).startswith("mp3") else "pcm")
        if not os.path.exists(p):
            return None
        with open(p, "rb") as f:
            return f.read(), meta

    def put(self, key: str, data: bytes, meta: dict) -> None:
        b = self._base(key)
        os.makedirs(os.path.dirname(b), exist_ok=True)
        p = b + "." + ("mp3" if str(meta.get("format", "")).startswith("mp3") else "pcm")
        with open(p + ".part", "wb") as f:
            f.write(data)
        os.replace(p + ".part", p)
        V.save_json(b + ".json", meta)

    def has(self, key: str) -> bool:
        return self.get(key) is not None


# ───────────────────────────────────────────────────────────── synthesis

def _sleep(s: float) -> None:
    time.sleep(s)


def synth(client, job: Job, fmt: str, sleep=_sleep) -> tuple[bytes, str, int]:
    """One TTS call with retries. Returns (audio bytes, format, characters billed). Raises ApiStop / ApiLineError;
    a refused output format comes back as ApiStop('format') so the caller can switch to mp3."""
    from elevenlabs import VoiceSettings
    last = None
    for attempt in range(RETRIES + 1):
        try:
            with client.text_to_speech.with_raw_response.convert(
                    voice_id=job.voice_id, text=job.text, model_id=TTS_MODEL, language_code=job.lang or None,
                    voice_settings=VoiceSettings(**job.settings), output_format=fmt) as resp:
                data = b"".join(resp.data)
                hdr = getattr(resp, "headers", {}) or {}
            try:
                n = int(hdr.get("x-character-count") or 0) or job.chars
            except (TypeError, ValueError):
                n = job.chars
            if not data:
                raise ApiLineError("empty audio")
            return data, fmt, n
        except (ApiLineError, ApiStop):
            raise
        except Exception as e:  # noqa: BLE001 - the SDK raises ApiError / httpx errors
            status, code, msg = describe(e)
            kind = classify(status, code, msg)
            last = (status, code, msg)
            if kind == "rate" and attempt < RETRIES:
                sleep(2.0 * (2 ** attempt))
                continue
            if kind == "line":
                raise ApiLineError("HTTP %s %s: %s" % (status, code, msg))
            raise ApiStop(kind if kind != "rate" else "rate limit after %d retries" % RETRIES, status, code, msg)
    status, code, msg = last or (None, "", "")
    raise ApiStop("rate", status, code, msg)


def decode(data: bytes, fmt: str) -> np.ndarray:
    """API audio -> float mono at the pipeline's rate (48 kHz)."""
    from scipy import signal
    if fmt.startswith("pcm_"):
        rate = int(fmt.split("_")[1])
        x = np.frombuffer(data[: len(data) // 2 * 2], dtype="<i2").astype(np.float64) / 32768.0
        from math import gcd
        g = gcd(P.SR, rate)
        return signal.resample_poly(x, P.SR // g, rate // g)
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "in.mp3")
        dst = os.path.join(td, "out.wav")
        with open(src, "wb") as f:
            f.write(data)
        P.run_ffmpeg(["-i", src, "-ac", "1", "-ar", str(P.SR), "-c:a", "pcm_f32le", dst])
        return P.read_wav(dst)


def fx_line(ln: V.Line, cast: dict) -> V.Line:
    """The line whose effect chain applies: a Fine Print speaker shared with Gravelight / B&S takes that one's."""
    if ln.game != "fp":
        return ln
    e = cast.get("characters", {}).get("fp", {}).get(ln.char, {})
    if e.get("same_as"):
        g, c = str(e["same_as"]).split(":", 1)
        return V.Line(ln.file_id, ln.line_id, g, c, ln.text, ln.category, ln.delivery, ln.context, ln.res_path)
    return ln


def render(job: Job, x: np.ndarray, fx: dict, cast: dict) -> tuple[np.ndarray, str, str]:
    """The finished line, as for a recorded take: trim, loudness by delivery, the character's effect (fx.json), the
    line's effect cues ([radio], [distant]...: gen_vo.py's DSP), true-peak ceiling. Returns (audio, fx name, fx sig)."""
    ln = fx_line(job.ln, cast)
    target, peak = P.loudness_target(job.ln)
    y = P.to_loudness(P.trim(x), target, peak)
    name, chain = P.fx_for(fx, ln)
    kind = chain.get("kind", "clean")
    if kind != "clean":
        y = P.to_loudness(P.tail_trim(P.apply_fx(y, chain, job.ln.file_id)), target, peak)
    cues = set(job.cues) & POST_CUES
    if cues:
        with P._genvo() as G:
            gch = {"radio_1930s": "tannoy", "field_radio": "radio"}.get(kind, "squad")
            y = P.to_loudness(P.tail_trim(G.apply_cues(y, G.rng_for(job.ln.file_id), cues, gch)), target, peak)
    sig = V.sha16(json.dumps([name, chain, sorted(cues), P.loudness_target(job.ln), "eleven-1"], sort_keys=True))[:10]
    return y, name, sig


def fx_sig(job: Job, fx: dict, cast: dict) -> str:
    name, chain = P.fx_for(fx, fx_line(job.ln, cast))
    cues = set(job.cues) & POST_CUES
    return V.sha16(json.dumps([name, chain, sorted(cues), P.loudness_target(job.ln), "eleven-1"], sort_keys=True))[:10]


class Shipper:
    """Writes takes where the game plays them and keeps the manifests (saved per batch)."""

    def __init__(self):
        self.m: dict[str, dict] = {}

    def manifest(self, game: str) -> dict:
        g = "gl" if game == "gl" else "bs"
        if g not in self.m:
            self.m[g] = V.load_manifest(g)
            self.m[g].setdefault("files", {})
        return self.m[g]

    def row(self, ln: V.Line) -> dict:
        return self.manifest(ln.game).get("files", {}).get(ln.file_id, {}) or {}

    def ship(self, job: Job, y: np.ndarray, fxname: str, sig: str, chars: int) -> dict:
        ln = job.ln
        files = self.manifest(ln.game)["files"]
        cur = files.get(ln.file_id, {}) or {}
        disk = V.res_to_disk(ln.res_path)
        if ln.game == "gl" and cur and cur.get("source", "tts") == "tts":
            tts_row = P.backup_tts(cur, ln)
        else:
            tts_row = cur.get("tts")
        with tempfile.TemporaryDirectory() as td:
            w = os.path.join(td, "x.wav")
            P.write_wav(w, y)
            P.encode_ogg(w, disk)
        row = V.human_row(ln, "elevenlabs:" + (job.voice_name or job.voice_id), job.key[:12], V.file_sha(disk),
                          len(y) / P.SR, P.lufs(y), fxname, "", source=SOURCE)
        row.update({"ai": True, "engine": "elevenlabs", "model": TTS_MODEL, "voice_id": job.voice_id,
                    "voice_name": job.voice_name, "language": job.lang, "settings": job.settings,
                    "eleven_hash": job.key, "fx_sig": sig, "chars": chars})
        if tts_row:
            row["tts"] = tts_row
        files[ln.file_id] = row
        return row

    def flush(self) -> None:
        for g, m in self.m.items():
            V.save_manifest(g, m)


def status_of(job: Job, shipper: Shipper, cache: TakeCache, fx: dict, cast: dict) -> str:
    if job.reason:
        return "uncast" if job.reason.startswith(("not cast", "no cast")) else "skip"
    row = shipper.row(job.ln)
    if row.get("source") == "human" and row.get("script_sha") == job.ln.script_sha:
        return "human"
    if (row.get("source") == SOURCE and row.get("eleven_hash") == job.key and row.get("fx_sig") == fx_sig(job, fx, cast)
            and os.path.exists(V.res_to_disk(job.ln.res_path))):
        return "done"
    return "cached" if cache.has(job.key) else "todo"


# ───────────────────────────────────────────────────────────── subscription, log, state

def subscription(client) -> dict:
    """tier, character_count, character_limit, next reset (no secrets)."""
    s = client.user.subscription.get()
    reset = getattr(s, "next_character_count_reset_unix", None)
    return {"tier": str(getattr(s, "tier", "") or ""), "character_count": int(getattr(s, "character_count", 0) or 0),
            "character_limit": int(getattr(s, "character_limit", 0) or 0),
            "next_reset": _dt.datetime.fromtimestamp(int(reset), _dt.timezone.utc).strftime("%Y-%m-%d") if reset else "",
            "status": str(getattr(s, "status", "") or "")}


def log(event: dict) -> None:
    p = log_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    event = dict(event, time=_dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    with open(p, "a", encoding="utf-8") as f:
        f.write(scrub(json.dumps(event, ensure_ascii=False)) + "\n")


def save_state(st: dict) -> None:
    V.save_json(state_path(), st)


def load_state() -> dict:
    return V.load_json(state_path())


# ───────────────────────────────────────────────────────────── plan

def plan_size(chars: float) -> str:
    credits = chars * CREDITS_PER_CHAR
    for name, cap in PLANS:
        if credits <= cap:
            return "%s (%s credits / month) in one month" % (name, format(cap, ","))
    name, cap = PLANS[-2]
    months = int(-(-credits // cap))
    return "%s (%s / month) for %d months, or Business" % (name, format(cap, ","), months)


def plan(only: list[int] | None = None, client=None, write: bool = True, out=print) -> dict:
    cast = V.load_cast()
    fx = V.load_json(V.FX_PATH)
    jobs = [j for j in build_jobs(cast) if not only or j.group in only]
    cache = TakeCache()
    sh = Shipper()
    res = {"groups": {}, "uncast_chars": {}}
    for j in jobs:
        j.status = status_of(j, sh, cache, fx, cast)
        g = res["groups"].setdefault(j.group, {"lines": 0, "chars": 0, "to_pay": 0, "cached": 0, "done": 0,
                                               "human": 0, "uncast": 0, "skip": 0})
        g["lines"] += 1
        g["chars"] += j.chars
        if j.status != "todo":
            g[j.status] += 1
        if j.status in ("todo", "uncast"):
            g["to_pay"] += j.chars
        if j.status == "uncast":
            res["uncast_chars"].setdefault(j.ln.game + ":" + j.ln.char, 0)
            res["uncast_chars"][j.ln.game + ":" + j.ln.char] += j.chars
    total = sum(g["to_pay"] for g in res["groups"].values())
    res["total_to_pay"] = total
    sub = None
    if client is None and have_key():
        try:
            client = make_client()
        except Exception as e:  # noqa: BLE001
            out("could not make the ElevenLabs client: %s" % scrub(e))
    if client is not None:
        try:
            sub = subscription(client)
        except Exception as e:  # noqa: BLE001
            st, code, msg = describe(e)
            out("subscription read failed: HTTP %s %s %s" % (st, code, msg))
    res["subscription"] = sub
    out("ElevenLabs bake plan (model %s, %.1f credit / character)" % (TTS_MODEL, CREDITS_PER_CHAR))
    out("%-3s %-11s %6s %9s %9s %7s %6s %6s %7s" % ("#", "group", "lines", "chars", "to pay", "cached", "done", "human", "uncast"))
    for n in sorted(res["groups"]):
        g = res["groups"][n]
        out("%-3d %-11s %6d %9d %9d %7d %6d %6d %7d" % (n, GROUPS[n], g["lines"], g["chars"], g["to_pay"], g["cached"],
                                                        g["done"], g["human"], g["uncast"]))
    out("total still to pay: %d characters (~%d credits) -> plan: %s" % (total, total * CREDITS_PER_CHAR, plan_size(total)))
    if sub:
        left = sub["character_limit"] - sub["character_count"]
        out("account: tier %s, used %d of %d this period (%d left), next reset %s" % (
            sub["tier"], sub["character_count"], sub["character_limit"], left, sub["next_reset"] or "?"))
    else:
        out(SETUP_HINT if not have_key() else "account: (subscription not read)")
    if write:
        write_needs(res)
    return res


def write_needs(res: dict, path: str | None = None) -> None:
    """The estimate into morning/NEEDS_DEVIN.md under '## UPDATE 11: ElevenLabs' (only the marked block is rewritten;
    anything else under the heading is left for the lead)."""
    path = path or NEEDS_PATH
    sub = res.get("subscription")
    lines = ["<!-- eleven-plan:start (tools/voice.sh elevenlabs plan rewrites this block) -->",
             "- **Estimate %s** (`tools/voice.sh elevenlabs plan`, model `%s`, 1 credit per character): **%s characters** "
             "still to bake, so **%s**." % (V.today(), TTS_MODEL, format(res["total_to_pay"], ","), plan_size(res["total_to_pay"])),
             "- Per group, in bake order: " + "; ".join(
                 "%d %s %s" % (n, GROUP_TITLES[n], format(g["to_pay"], ",")) for n, g in sorted(res["groups"].items())) + "."]
    if sub:
        lines.append("- Your account now: **%s** tier, %s of %s characters used this period, next reset %s. %s" % (
            sub["tier"], format(sub["character_count"], ","), format(sub["character_limit"], ","), sub["next_reset"] or "?",
            "Enough for the whole bake." if sub["character_limit"] - sub["character_count"] >= res["total_to_pay"]
            else "Not enough for the whole bake: upgrade (the bake stops cleanly at the quota and resumes next month)."))
        if sub["tier"].lower() in ("free", ""):
            lines.append("- The Free tier has no commercial licence and needs attribution: a paid plan (Starter or up) is "
                         "needed before the voices ship in a release.")
    else:
        lines.append("- Account not read: " + SETUP_HINT)
    lines.append("<!-- eleven-plan:end -->")
    block = "\n".join(lines)
    txt = open(path, encoding="utf-8").read() if os.path.exists(path) else "# NEEDS DEVIN\n"
    if NEEDS_HEADING not in txt:
        m = re.search(r"^## ", txt, re.M)
        sec = NEEDS_HEADING + "\n" + block + "\n\n"
        txt = txt[:m.start()] + sec + txt[m.start():] if m else txt.rstrip("\n") + "\n\n" + sec
    elif "<!-- eleven-plan:start" in txt:
        txt = re.sub(r"<!-- eleven-plan:start.*?<!-- eleven-plan:end -->", lambda _m: block, txt, flags=re.S)
    else:
        txt = txt.replace(NEEDS_HEADING + "\n", NEEDS_HEADING + "\n" + block + "\n", 1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(scrub(txt))


# ───────────────────────────────────────────────────────────── bake

def bake(only: list[int] | None = None, limit_chars: int | None = None, ids: list[str] | None = None,
         dry: bool = False, games=("gl", "fp", "bs"), client=None, cache: TakeCache | None = None,
         sleep=_sleep, out=print) -> dict:
    """Bakes every castable line in priority order. Returns a summary; the stop reason (if any) is in 'stopped'."""
    cast = V.load_cast()
    fx = V.load_json(V.FX_PATH)
    jobs = [j for j in build_jobs(cast, games=games) if (not only or j.group in only)
            and (not ids or any(j.ln.file_id == i or j.ln.file_id.startswith(i) for i in ids))]
    cache = cache or TakeCache()
    sh = Shipper()
    for j in jobs:
        j.status = status_of(j, sh, cache, fx, cast)
    work = [j for j in jobs if j.status in ("todo", "cached")]
    paid = sum(j.chars for j in work if j.status == "todo")
    summary = {"baked": 0, "from_cache": 0, "chars": 0, "failed": {}, "stopped": "", "skipped": {}}
    for j in jobs:
        if j.status not in ("todo", "cached"):
            summary["skipped"][j.status] = summary["skipped"].get(j.status, 0) + 1
    prev = load_state()
    if prev.get("stopped"):
        out("resuming: the last bake stopped at %s (%s, %s)" % (prev.get("next", "?"), prev.get("stopped"), prev.get("time", "")))
    out("bake: %d lines to make (%d from the cache, %d characters to pay), skipped %s" % (
        len(work), len(work) - sum(1 for j in work if j.status == "todo"), paid, summary["skipped"] or "none"))
    if dry:
        for j in work:
            out("  %d %-28s %-6s %-3s %s" % (j.group, j.ln.file_id, j.status, j.lang, j.text[:80]))
        return summary
    if not work:
        save_state({})
        return summary
    if any(j.status == "todo" for j in work) and client is None:
        client = make_client()          # raises Refused(SETUP_HINT) without a key
    fmt = prev.get("format") or FORMAT_PCM
    sub0 = None
    if client is not None:
        try:
            sub0 = subscription(client)
        except Exception as e:  # noqa: BLE001
            out("subscription read failed: %s" % " ".join(str(x) for x in describe(e)))
    left = (sub0["character_limit"] - sub0["character_count"]) if sub0 else None
    batch_chars, batch_n, batch_group = 0, 0, work[0].group
    sub_b = sub0

    def end_batch(stopped: str = "") -> None:
        nonlocal batch_chars, batch_n, sub_b
        sh.flush()
        sub_a = None
        if client is not None and batch_chars:
            try:
                sub_a = subscription(client)
            except Exception:  # noqa: BLE001
                sub_a = None
        if batch_n or stopped:
            log({"event": "batch", "group": GROUPS[batch_group], "lines": batch_n, "chars_billed": batch_chars,
                 "account_used_before": sub_b["character_count"] if sub_b else None,
                 "account_used_after": sub_a["character_count"] if sub_a else None,
                 "credits_delta": (sub_a["character_count"] - sub_b["character_count"]) if (sub_a and sub_b) else None,
                 "model": TTS_MODEL, "stopped": stopped})
        sub_b = sub_a or sub_b
        batch_chars, batch_n = 0, 0

    stopped = ""
    for j in work:
        if j.group != batch_group:
            end_batch()
            batch_group = j.group
        hit = cache.get(j.key)
        chars = 0
        if hit is None:
            if limit_chars is not None and summary["chars"] + j.chars > limit_chars:
                stopped = "limit"
            elif left is not None and summary["chars"] + j.chars > left:
                stopped = "quota (the account has %d characters left)" % (left - summary["chars"])
            if stopped:
                save_state({"stopped": stopped, "next": j.ln.file_id, "group": GROUPS[j.group], "format": fmt,
                            "time": V.today()})
                break
            try:
                try:
                    data, used_fmt, chars = synth(client, j, fmt, sleep)
                except ApiStop as e:
                    if e.reason != "format" or fmt == FORMAT_MP3:
                        raise
                    out("  %s refused on this plan (%s): switching to %s" % (fmt, e.message[:80], FORMAT_MP3))
                    fmt = FORMAT_MP3
                    data, used_fmt, chars = synth(client, j, fmt, sleep)
            except ApiLineError as e:
                summary["failed"][j.ln.file_id] = scrub(e)
                out("  FAIL %s %s" % (j.ln.file_id, scrub(e)))
                continue
            except ApiStop as e:
                stopped = e.reason
                save_state({"stopped": e.reason, "next": j.ln.file_id, "group": GROUPS[j.group], "format": fmt,
                            "status": e.status, "code": e.code, "time": V.today()})
                out("  STOP at %s: %s" % (j.ln.file_id, scrub(e)))
                break
            cache.put(j.key, data, {"format": used_fmt, "model": TTS_MODEL, "voice_id": j.voice_id, "lang": j.lang,
                                    "settings": j.settings, "text": j.text, "chars": chars, "line": j.ln.file_id,
                                    "created": V.today()})
            summary["baked"] += 1
            summary["chars"] += chars
            batch_chars += chars
        else:
            data, meta = hit
            used_fmt = str(meta.get("format", FORMAT_PCM))
            summary["from_cache"] += 1
        try:
            y, fxname, sig = render(j, decode(data, used_fmt), fx, cast)
            sh.ship(j, y, fxname, sig, chars or int((hit or (b"", {}))[1].get("chars", j.chars)))
        except Exception as e:  # noqa: BLE001 - one bad file must not stop the bake
            summary["failed"][j.ln.file_id] = scrub("%s: %s" % (type(e).__name__, e))
            out("  FAIL %s %s" % (j.ln.file_id, summary["failed"][j.ln.file_id]))
            continue
        batch_n += 1
        if batch_n >= BATCH:
            end_batch()
    end_batch(stopped)
    summary["stopped"] = stopped
    if not stopped:
        save_state({"format": fmt} if fmt != FORMAT_PCM else {})
    out("bake: %d new takes (%d characters), %d from the cache, %d failed%s" % (
        summary["baked"], summary["chars"], summary["from_cache"], len(summary["failed"]),
        (", stopped: " + stopped + " (run again to resume)") if stopped else ""))
    return summary


# ───────────────────────────────────────────────────────────── voices, assign, design

def _labels(v) -> str:
    lab = getattr(v, "labels", None) or {}
    parts = [str(lab.get(k)) for k in ("accent", "age", "gender", "descriptive", "description", "use_case", "language")
             if lab.get(k)]
    return ", ".join(parts)


def voices(library: bool = False, client=None, out=print, **filters) -> list[dict]:
    client = client or make_client()
    rows = []
    if library:
        kw = {k: v for k, v in filters.items() if v}
        r = client.voices.get_shared(page_size=int(kw.pop("page_size", 40)), **kw)
        for v in r.voices:
            rows.append({"voice_id": v.voice_id, "name": v.name, "owner": v.public_owner_id,
                         "labels": ", ".join(str(x) for x in (v.accent, v.age, v.gender, v.descriptive, v.use_case, v.language) if x),
                         "free_users_allowed": getattr(v, "free_users_allowed", None)})
    else:
        r = client.voices.search(page_size=100, search=filters.get("search") or None)
        for v in r.voices:
            rows.append({"voice_id": v.voice_id, "name": v.name, "category": str(v.category or ""), "labels": _labels(v)})
    for x in rows:
        out("%-22s %-28s %s" % (x["voice_id"], (x["name"] or "")[:28], x["labels"]))
    return rows


def _set_eleven(game: str, code: str, upd: dict, path: str | None = None) -> dict:
    path = path or V.CAST_PATH
    cast = V.load_json(path)
    chars = cast.setdefault("characters", {}).setdefault(game, {})
    if code not in chars:
        raise Refused("no cast entry %s:%s in data/voice/cast.json" % (game, code))
    el = chars[code].setdefault("eleven", {})
    el.update(upd)
    V.save_json(path, cast, sort=False)
    return el


def assign(char: str, voice_id: str, name: str = "", why: str = "", source: str = "library", owner: str = "",
           client=None) -> dict:
    game, code = char.split(":", 1)
    if source == "clone":
        raise Refused("a clone is made by `clone --actor=` (consent-gated), not assigned")
    if owner:
        client = client or make_client()
        v = client.voices.share(public_user_id=owner, voice_id=voice_id, new_name=name or code)
        voice_id = getattr(v, "voice_id", voice_id) or voice_id
    upd = {"voice_id": voice_id, "voice_name": name, "source": source}
    if why:
        upd["why"] = why
    return _set_eleven(game, code, upd)


def design(char: str, prompt: str = "", text: str = "", pick: int | None = None, name: str = "", client=None,
           out=print) -> dict:
    """Voice Design. Without --pick: makes the previews for the character's design_prompt (or --prompt), saves them
    to the cache's design/ folder and lists them. With --pick=N: creates that voice and stores its id in cast.json."""
    game, code = char.split(":", 1)
    cast = V.load_cast()
    e = cast.get("characters", {}).get(game, {}).get(code)
    if e is None:
        raise Refused("no cast entry %s" % char)
    el = e.get("eleven", {}) or {}
    if el.get("source") == "clone":
        raise Refused("REFUSED: %s is set to a clone; Voice Design makes a new voice instead (set source design)" % char)
    prompt = prompt or str(el.get("design_prompt", ""))
    if not prompt:
        raise Refused("no prompt: pass --prompt or set characters.%s.%s.eleven.design_prompt" % (game, code))
    ddir = os.path.join(cache_dir(), "design", "%s_%s" % (game, code))
    meta_p = os.path.join(ddir, "previews.json")
    client = client or make_client()
    if pick is None:
        kw = {"voice_description": prompt, "model_id": DESIGN_MODEL}
        if text:
            kw["text"] = text
        else:
            kw["auto_generate_text"] = True
        r = client.text_to_voice.design(**kw)
        os.makedirs(ddir, exist_ok=True)
        rows = []
        for i, pv in enumerate(r.previews, 1):
            p = os.path.join(ddir, "preview_%d.mp3" % i)
            with open(p, "wb") as f:
                f.write(base64.b64decode(pv.audio_base_64))
            rows.append({"n": i, "generated_voice_id": pv.generated_voice_id, "file": p})
            out("  preview %d: %s" % (i, p))
        V.save_json(meta_p, {"prompt": prompt, "text": getattr(r, "text", text), "previews": rows})
        out("listen, then: tools/voice.sh elevenlabs design --char=%s --pick=N" % char)
        return {"previews": rows}
    meta = V.load_json(meta_p)
    pv = next((p for p in meta.get("previews", []) if int(p["n"]) == int(pick)), None)
    if not pv:
        raise Refused("no preview %s for %s: run design without --pick first" % (pick, char))
    v = client.text_to_voice.create(voice_name=name or "TC %s" % str(e.get("name", code))[:40],
                                    voice_description=meta.get("prompt", prompt), generated_voice_id=pv["generated_voice_id"])
    upd = {"voice_id": v.voice_id, "voice_name": name or str(e.get("name", code)), "source": "design",
           "design_prompt": meta.get("prompt", prompt)}
    out("created voice %s for %s" % (v.voice_id, char))
    return _set_eleven(game, code, upd)


# ───────────────────────────────────────────────────────────── sound effects (for the horror pass; none baked now)

def sfx(name: str, prompt: str, seconds: float | None = None, loop: bool = False, influence: float = 0.4,
        out_path: str = "", client=None, cache: TakeCache | None = None, out=print) -> str:
    """A sound effect from a prompt, cached by sha256(prompt, model, seconds, loop, influence). Writes an .ogg (48 kHz
    mono, the game's format) to out_path, or to the cache's sfx/ folder."""
    cache = cache or TakeCache()
    key = hashlib.sha256(json.dumps({"sfx": prompt, "model": SFX_MODEL, "s": seconds, "loop": loop, "pi": influence},
                                    sort_keys=True).encode("utf-8")).hexdigest()
    hit = cache.get(key)
    if hit is None:
        client = client or make_client()
        try:
            kw = {"text": prompt, "model_id": SFX_MODEL, "loop": loop, "prompt_influence": influence,
                  "output_format": FORMAT_MP3}
            if seconds:
                kw["duration_seconds"] = float(seconds)
            data = b"".join(client.text_to_sound_effects.convert(**kw))
        except Exception as e:  # noqa: BLE001
            st, code, msg = describe(e)
            raise Refused("sound effect refused: HTTP %s %s %s" % (st, code, msg))
        cache.put(key, data, {"format": FORMAT_MP3, "model": SFX_MODEL, "prompt": prompt, "name": name,
                              "created": V.today()})
        log({"event": "sfx", "name": name, "model": SFX_MODEL, "seconds": seconds})
    else:
        data = hit[0]
    x = decode(data, FORMAT_MP3)
    dst = out_path or os.path.join(cache.dir, "sfx", V.slug(name) + ".ogg")
    with tempfile.TemporaryDirectory() as td:
        w = os.path.join(td, "s.wav")
        P.write_wav(w, x)
        P.encode_ogg(w, dst)
    out("sfx %s -> %s" % (name, dst))
    return dst


# ───────────────────────────────────────────────────────────── the tiny live check

CHECK_VOICES = {"en": "JBFqnCBsd6RMkjVDRZzb", "ru": "onwK4e9ZLuTAKqWW03F9", "de": "onwK4e9ZLuTAKqWW03F9"}  # premade


def check(out_dir: str = "", client=None, out=print) -> dict:
    """<= 3 real TTS calls, < 300 characters: one English squad line, one Russian line from the new speakers (else a
    German one), rendered through the whole chain into a scratch folder (never the game). Then the subscription."""
    cast = V.load_cast()
    client = client or make_client()
    lines = V.collect_gl()
    sub0 = subscription(client)
    jobs = build_jobs(cast, lines)
    pick: list[Job] = []

    def first(pred):
        for j in sorted(jobs, key=lambda j: j.chars):
            if pred(j) and 12 <= j.chars <= 120 and j not in pick:
                return j
        return None
    a = first(lambda j: j.ln.char in SQUAD and j.lang == "en" and j.group == 2)
    b = first(lambda j: j.lang == "ru") or first(lambda j: j.lang == "de")
    pick = [x for x in (a, b) if x]
    total = 0
    res = {"lines": [], "subscription_before": sub0}
    fx = V.load_json(V.FX_PATH)
    out_dir = out_dir or os.path.join(cache_dir(), "check")
    os.makedirs(out_dir, exist_ok=True)
    cache = TakeCache()
    for j in pick:
        if not j.voice_id:
            j.voice_id = CHECK_VOICES.get(j.lang, CHECK_VOICES["en"])
            j.voice_name = "premade:" + j.voice_id[:6]
            j.reason = ""
            j.key = cache_key(j.text, j.voice_id, TTS_MODEL, j.settings, j.lang)
        if total + j.chars >= 300:
            break
        hit = cache.get(j.key)
        if hit is None:
            try:
                data, fmt, n = synth(client, j, FORMAT_PCM)
            except ApiStop as e:
                if e.reason != "format":
                    raise
                out("  pcm_44100 refused on this plan: %s; using %s" % (e.message[:80], FORMAT_MP3))
                data, fmt, n = synth(client, j, FORMAT_MP3)
            cache.put(j.key, data, {"format": fmt, "model": TTS_MODEL, "voice_id": j.voice_id, "lang": j.lang,
                                    "settings": j.settings, "text": j.text, "chars": n, "line": j.ln.file_id,
                                    "created": V.today()})
        else:
            data, meta = hit
            fmt, n = str(meta.get("format")), 0
        total += j.chars
        y, fxname, _ = render(j, decode(data, fmt), fx, cast)
        p = os.path.join(out_dir, j.ln.file_id + ".ogg")
        with tempfile.TemporaryDirectory() as td:
            w = os.path.join(td, "c.wav")
            P.write_wav(w, y)
            P.encode_ogg(w, p)
        res["lines"].append({"id": j.ln.file_id, "lang": j.lang, "text": j.text, "chars_sent": j.chars, "billed": n,
                             "format": fmt, "seconds": round(len(y) / P.SR, 2), "file": p})
        out("  %s [%s] %d chars (billed %s, %s) -> %s" % (j.ln.file_id, j.lang, j.chars, n, fmt, p))
    sub1 = subscription(client)
    res["subscription_after"] = sub1
    res["credits_used"] = sub1["character_count"] - sub0["character_count"]
    log({"event": "check", "lines": len(res["lines"]), "chars_sent": total, "credits_delta": res["credits_used"],
         "model": TTS_MODEL})
    out("check: %d lines, %d characters sent, account %d -> %d (%d credits), tier %s, limit %d, reset %s" % (
        len(res["lines"]), total, sub0["character_count"], sub1["character_count"], res["credits_used"], sub1["tier"],
        sub1["character_limit"], sub1["next_reset"]))
    return res


# ───────────────────────────────────────────────────────────── T-101: stock / sts / clone (now on the SDK)

def _line(fid: str) -> V.Line:
    for ln in V.collect_all() + V.collect_fp():
        if ln.file_id == fid:
            return ln
    raise Refused("unknown line id %s" % fid)


def stock(fid: str, voice: str, force: bool = False, client=None, cache: TakeCache | None = None) -> dict:
    """One gap line in a given voice (never over a recorded take)."""
    ln = _line(fid)
    sh = Shipper()
    cur = sh.row(ln)
    if cur.get("source") == "human" and not force:
        raise Refused("%s has a recorded take by %s: a stock voice never replaces a real one" % (fid, cur.get("actor")))
    api_key()
    j = build_jobs({"characters": {}}, [ln])[0]
    j.voice_id, j.voice_name, j.reason = voice, voice, ""
    j.key = cache_key(j.text, voice, TTS_MODEL, j.settings, j.lang)
    cache = cache or TakeCache()
    hit = cache.get(j.key)
    if hit is None:
        client = client or make_client()
        data, fmt, n = synth(client, j, FORMAT_PCM)
        cache.put(j.key, data, {"format": fmt, "model": TTS_MODEL, "voice_id": voice, "lang": j.lang,
                                "settings": j.settings, "text": j.text, "chars": n, "line": fid, "created": V.today()})
    else:
        data, fmt, n = hit[0], str(hit[1].get("format")), 0
    cast = V.load_cast()
    fx = V.load_json(V.FX_PATH)
    y, fxname, sig = render(j, decode(data, fmt), fx, cast)
    row = sh.ship(j, y, fxname, sig, n)
    row["source"] = "ai_stock"
    sh.flush()
    return row


def sts(fid: str, client=None) -> dict:
    ln = _line(fid)
    cast = V.load_cast()
    voice = cast.get("characters", {}).get(ln.game, {}).get(ln.char, {}).get("voice_changer", "")
    if not voice:
        raise Refused("cast.json does not ask for a voice changer on %s (set characters.%s.%s.voice_changer)" % (ln.char, ln.game, ln.char))
    sh = Shipper()
    cur = sh.row(ln)
    if cur.get("source") != "human":
        raise Refused("%s has no recorded take to change" % fid)
    actor = cur.get("actor", "")
    if not V.read_consent(actor).ok:
        raise Refused("%s has no consent on file" % actor)
    client = client or make_client()
    with open(V.res_to_disk(cur["path"]), "rb") as f:
        audio = f.read()
    try:
        data = b"".join(client.speech_to_speech.convert(voice_id=voice, audio=audio, model_id=STS_MODEL,
                                                        output_format=FORMAT_MP3))
    except Exception as e:  # noqa: BLE001
        raise Refused("voice changer refused: HTTP %s %s %s" % describe(e))
    j = build_jobs({"characters": {}}, [ln])[0]
    j.voice_id, j.voice_name, j.key, j.reason = voice, voice, V.sha16(audio) + voice, ""
    fx = V.load_json(V.FX_PATH)
    y, fxname, sig = render(j, decode(data, FORMAT_MP3), fx, cast)
    row = sh.ship(j, y, fxname, sig, 0)
    row.update({"source": "ai_sts", "actor": actor, "take": cur.get("take", "") + ">sts:" + voice})
    sh.flush()
    return row


def clone(actor: str, client=None) -> str:
    c = V.read_consent(actor)
    if not c.ok or not c.ai_cloning:
        raise Refused("REFUSED: %s has not opted in to AI voice cloning (voice_inbox/%s/consent.txt must say "
                      "'ai_voice_cloning: yes')" % (actor, actor))
    samples = []
    for fid, row in {**V.load_manifest("gl").get("files", {}), **V.load_manifest("bs").get("files", {})}.items():
        if row.get("source") == "human" and row.get("actor") == actor and len(samples) < 20:
            samples.append(open(V.res_to_disk(row["path"]), "rb").read())
    if not samples:
        raise Refused("no recorded takes of %s to clone from" % actor)
    client = client or make_client()
    v = client.voices.ivc.create(name="tc-%s" % actor, files=samples,
                                 description="Terms & Conditions cast clone (consent %s)" % c.date)
    return getattr(v, "voice_id", "")


# ───────────────────────────────────────────────────────────── CLI

def main(argv: list[str] | None = None) -> int:
    for st in (sys.stdout, sys.stderr):
        try:
            st.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["plan", "bake", "voices", "assign", "design", "sfx", "check", "stock", "sts", "clone"])
    ap.add_argument("--only", default="", help="priority groups, comma list (numbers or names)")
    ap.add_argument("--limit-chars", type=int, default=None)
    ap.add_argument("--ids", default="", help="line ids or id prefixes, comma list")
    ap.add_argument("--game", default="", help="gl, fp, bs (comma list); default all")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-write", action="store_true")
    ap.add_argument("--library", action="store_true")
    for k in ("search", "accent", "gender", "age", "language", "char", "voice", "name", "why", "owner", "prompt",
              "text", "line", "actor", "out"):
        ap.add_argument("--" + k, default="")
    ap.add_argument("--pick", type=int, default=None)
    ap.add_argument("--seconds", type=float, default=None)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args(argv)
    only = [parse_group(x) for x in a.only.split(",") if x.strip()] if a.only else None
    games = tuple(x.strip() for x in a.game.split(",") if x.strip()) or ("gl", "fp", "bs")
    try:
        if a.mode == "plan":
            plan(only, write=not a.no_write)
        elif a.mode == "bake":
            if not have_key() and not a.dry_run:
                print(SETUP_HINT)
                print("nothing baked: the game keeps its Kokoro / OneCore / runtime TTS voices")
                return 0
            r = bake(only, a.limit_chars, [x for x in a.ids.split(",") if x] or None, a.dry_run, games)
            return 3 if r.get("stopped") and not r["stopped"].startswith("limit") else 0
        elif a.mode == "voices":
            voices(a.library, search=a.search, accent=a.accent, gender=a.gender, age=a.age, language=a.language)
        elif a.mode == "assign":
            print(assign(a.char, a.voice, a.name, a.why, owner=a.owner))
        elif a.mode == "design":
            print(design(a.char, a.prompt, a.text, a.pick, a.name))
        elif a.mode == "sfx":
            sfx(a.name or "sfx", a.prompt, a.seconds, a.loop, out_path=a.out)
        elif a.mode == "check":
            check(a.out)
        elif a.mode == "stock":
            print(stock(a.line, a.voice, a.force))
        elif a.mode == "sts":
            print(sts(a.line))
        else:
            print("cloned voice id:", clone(a.actor))
    except Refused as e:
        print(scrub(e))
        return 2
    except ApiStop as e:
        print(scrub(e))
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
