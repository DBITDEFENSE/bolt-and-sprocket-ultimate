#!/usr/bin/env python3
"""Neural synthesis back end for the GRAVELIGHT voice bake (T-073). Driven by gen_vo.py; not meant to be run by hand.

Runs inside the project-local venv (tools/venv: kokoro-onnx, onnxruntime, misaki, espeakng-loader) with the
Kokoro-82M model in tools/tts/kokoro/ (see tools/setup_tts.sh). Offline, CPU only, file output only: nothing here
ever opens an audio device.

Text to phonemes:
  * English words: misaki's gold/silver lexicons (US or GB, the dictionaries Kokoro was trained on), with
    eSpeak NG as the fallback for words they don't know. spaCy is not needed: a small tokenizer stands in for it
    (misaki only uses it for part-of-speech tags; untagged words take the lexicon's default reading).
  * Polish words (data/gravelight/vo/voice_cast.json "polish"): eSpeak NG's Polish voice, mapped onto Kokoro's
    symbol set. A native speaker (Wren, Jakub) keeps the Polish sounds; anyone else gets them anglicised (Dutch's
    kitchen Polish, "confidently and wrong").
  * German words (voice_cast.json "german": the Map 0 patrons' names) for a native German speaker (the
    civilians, "native_german"): eSpeak NG's German voice, with a uvular r. Anyone else reads them as English.
  * A speaker's "accent" rules (voice_cast.json "accents") rewrite the English phonemes: a light first-language
    colour (th-stopping, a tapped r, word-final devoicing, Polish vowel qualities), never a comic respelling.

Usage: python gen_vo_neural.py jobs.json result.json
  jobs.json:   {"model": dir, "cast": {voice_cast.json}, "jobs": [{"id", "wav", "speaker", "text", "voice",
                "speed", "lexicon": "us"|"gb", "accent": name|"", "native_polish": bool, "native_german": bool,
                "exclaim": bool}]}
  result.json: {"ok": [id...], "failed": {id: reason}, "phonemes": {id: str}, "engine": "kokoro"}
"""
from __future__ import annotations

import json
import os
import re
import sys
import types

NEURAL_VERSION = "1"

# misaki.en imports spaCy at module level but only needs it for tagging; we tokenize ourselves.
sys.modules.setdefault("spacy", types.ModuleType("spacy"))

import espeakng_loader  # noqa: E402
import numpy as np  # noqa: E402
from phonemizer.backend.espeak.wrapper import EspeakWrapper  # noqa: E402

EspeakWrapper.set_library(espeakng_loader.get_library_path())
EspeakWrapper.set_data_path(espeakng_loader.get_data_path())

from kokoro_onnx import Kokoro  # noqa: E402
from misaki import en as men  # noqa: E402
from misaki import espeak as mes  # noqa: E402
from scipy.io import wavfile  # noqa: E402

WORD_RE = re.compile(r"[A-Za-zÀ-žĄ-ż]+(?:['’][A-Za-z]+)*|\d+(?:[.,]\d+)*|\.\.\.|…|[.,!?;:—\-\"“”()]")
PUNCT_TAG = {".": ".", "!": ".", "?": ".", ",": ",", ";": ":", ":": ":", "—": ":", "-": ":", "...": ":", "…": ":",
             '"': "``", "“": "``", "”": "''", "(": "-LRB-", ")": "-RRB-"}
POLISH_LETTERS = re.compile(r"[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]")


class LiteG2P(men.G2P):
    """misaki's English G2P with a regex tokenizer in place of spaCy."""

    def __init__(self, british: bool):  # noqa: D107 (deliberately skips G2P.__init__, which loads spaCy)
        self.british = british
        self.lexicon = men.Lexicon(british)
        self.fallback = mes.EspeakFallback(british)
        self.unk = ""

    def tokenize(self, text, tokens, features):
        out = []
        for m in WORD_RE.finditer(text):
            t = m.group(0)
            ws = " " if m.end() < len(text) and text[m.end()] == " " else ""
            if t in PUNCT_TAG:
                tag = PUNCT_TAG[t]
            elif t[0].isdigit():
                tag = "CD"
            elif t == "I":
                tag = "PRP"
            elif t.lower() in ("a", "an", "the"):
                tag = "DT"
            elif t.lower() == "to":
                tag = "TO"
            elif t.lower() in ("am", "is", "are", "was", "were"):
                tag = "VBP"
            else:
                # No part-of-speech guess: "XX" makes misaki take each word's default reading (an "NN" tag
                # would spell some short words out as initials: "am" -> "A.M.").
                tag = "XX"
            out.append(men.MToken(text=t, tag=tag, whitespace=ws))
        return out


# eSpeak's Polish output → Kokoro symbols (native), and → English sounds (anglicised).
PL_NATIVE = [("d^ʑ", "ʥ"), ("t^ɕ", "ʨ"), ("dʑ", "ʥ"), ("tɕ", "ʨ"), ("d^ʒ", "ʤ"), ("t^ʃ", "ʧ"), ("d^z", "ʣ"),
             ("t^s", "ʦ"), ("ʑ", "ʒ"), ("ʐ", "ʒ"), ("^", ""), ("-", "")]
PL_ANGLICISED = PL_NATIVE + [("ʥ", "ʤ"), ("ʨ", "ʧ"), ("ɕ", "ʃ"), ("ʂ", "ʃ"), ("ɨ", "ɪ"), ("r", "ɹ"), ("ɲʲ", "nj"),
                             ("ɲ", "nj"), ("x", "h"), ("v", "w"), ("ʣ", "dz"), ("ʦ", "ts"), ("ɔ̃", "ɔn"), ("ɛ̃", "ɛn"),
                             ("̃", ""), ("ʲ", "")]
# misaki's eSpeak German output → Kokoro symbols: a uvular r, the vocalised r as a near-open schwa.
DE_NATIVE = [("^", ""), ("-", ""), ("r", "ʁ"), ("ɾ", "ʁ"), ("ɜ", "ɐ")]


class Phonemizer:
    def __init__(self, cast: dict):
        self.cast = cast
        self.g2p = {"us": LiteG2P(False), "gb": LiteG2P(True)}
        self.pl = mes.EspeakG2P("pl")
        self.de = None                              # eSpeak German, loaded on the first German word
        self.de_words = {w.lower() for w in cast.get("german", {}).get("words", [])}
        self.de_over = {k.lower(): v for k, v in cast.get("german", {}).get("overrides", {}).items()
                        if not k.startswith("_")}
        pol = cast.get("polish", {})
        self.pl_strong = {w.lower() for w in pol.get("words", [])}
        self.pl_weak = {w.lower() for w in pol.get("weak_words", [])}
        self.accents = cast.get("accents", {})
        self.pl_over = {k.lower(): v for k, v in pol.get("overrides", {}).items() if not k.startswith("_")}

    def _is_polish(self, words: list[str], i: int) -> bool:
        w = words[i].lower()
        if POLISH_LETTERS.search(w) or w in self.pl_strong:
            return True
        if w in self.pl_weak:
            # "na", "tu", "za"... are Polish only next to a sure Polish word ("Na dole", "Za tobą").
            for j in (i - 1, i + 1):
                if 0 <= j < len(words):
                    o = words[j].lower()
                    if POLISH_LETTERS.search(o) or o in self.pl_strong:
                        return True
        return False

    def segments(self, text: str, native_german: bool = False) -> list[tuple[str, str]]:
        """[(lang, text)] runs: consecutive Polish words (with their punctuation) become one "pl" run, a native German
        speaker's German words one "de" run."""
        toks = [m for m in re.finditer(r"\S+", text)]
        words = [re.sub(r"[^\wÀ-žĄ-ż']", "", m.group(0)) for m in toks]
        langs = ["de" if native_german and words[i].lower() in self.de_words
                 else "pl" if words[i] and self._is_polish(words, i) else "en" for i in range(len(toks))]
        runs: list[tuple[str, str]] = []
        for m, lang in zip(toks, langs):
            if runs and runs[-1][0] == lang:
                runs[-1] = (lang, runs[-1][1] + " " + m.group(0))
            else:
                runs.append((lang, m.group(0)))
        return runs

    def accent(self, ps: str, name: str) -> str:
        rules = self.accents.get(name, {})
        if not rules:
            return ps
        words = re.split(r"(\s+|[.,!?;:—…\"“”()])", ps)
        out = []
        fd = rules.get("final_devoicing", "")       # "", "phrase" (before a pause) or "all"
        pairs = {"z": "s", "d": "t", "v": "f", "b": "p", "ɡ": "k", "ʤ": "ʧ", "ʒ": "ʃ"}
        devoice = {a: b for a, b in pairs.items() if a in rules.get("devoice", "zdvbɡʤʒ")}
        for k, w in enumerate(words):
            if not w or w.isspace() or re.fullmatch(r"[.,!?;:—…\"“”()]", w):
                out.append(w)
                continue
            for a, b in rules.get("map", []):
                w = w.replace(a, b)
            if fd:
                nxt = next((x for x in words[k + 1:] if x and not x.isspace()), "")
                at_pause = nxt == "" or re.fullmatch(r"[.,!?;:—…]", nxt) is not None
                if (fd == "all" or at_pause) and w[-1:] in devoice:
                    w = w[:-1] + devoice[w[-1]]
            out.append(w)
        return "".join(out)

    def __call__(self, text: str, lexicon: str, accent: str, native_polish: bool, native_german: bool = False) -> str:
        text = re.sub(r"(?<=\w)-(?=\w)", " ", text)            # "jen-koo-yeh", "bolt-action": no dash pauses
        text = re.sub(r"\.\s*(\.\.\.|…)", "...", text)         # "Góra. ...I know": one ellipsis
        parts = []
        for lang, run in self.segments(text, native_german):
            if lang == "de":
                if self.de is None:
                    self.de = mes.EspeakG2P("de")
                out = []
                for wm in re.finditer(r"([^\s.,!?;:…]+)([.,!?;:…]*)", run):
                    word, punct = wm.group(1), wm.group(2)
                    wp = self.de_over.get(word.lower()) or self.de(word)
                    for a, b in DE_NATIVE:
                        wp = wp.replace(a, b)
                    out.append(wp.strip() + punct)
                ps = " ".join(out)
            elif lang == "pl":
                # Word by word (Polish stress is per word), so a word eSpeak gets wrong can be overridden.
                out = []
                for wm in re.finditer(r"([^\s.,!?;:…]+)([.,!?;:…]*)", run):
                    word, punct = wm.group(1), wm.group(2)
                    wp = self.pl_over.get(word.lower()) or self.pl(word)
                    out.append(wp.strip() + punct)
                ps = " ".join(out)
                for a, b in (PL_NATIVE if native_polish else PL_ANGLICISED):
                    ps = ps.replace(a, b)
            else:
                ps, _ = self.g2p[lexicon](run)
                ps = self.accent(ps, accent)
            parts.append(ps.strip())
        ps = " ".join(p for p in parts if p)
        ps = re.sub(r"\s+([.,!?;:…])", r"\1", ps)
        ps = re.sub(r"([.,!?;:…])(?=[^\s.,!?;:…])", r"\1 ", ps)
        return re.sub(r"\s+", " ", ps).strip()


def voice_style(k: Kokoro, spec: str) -> np.ndarray:
    """"am_onyx:0.5,am_fenrir:0.5" → a weighted blend of Kokoro style vectors (weights normalised)."""
    acc = None
    total = 0.0
    for part in spec.split(","):
        name, _, w = part.strip().partition(":")
        wt = float(w) if w else 1.0
        v = k.voices[name].astype(np.float64) * wt
        acc = v if acc is None else acc + v
        total += wt
    return (acc / total).astype(np.float32)


def main() -> int:
    jobs_path, result_path = sys.argv[1], sys.argv[2]
    with open(jobs_path, encoding="utf-8") as f:
        spec = json.load(f)
    model_dir = spec["model"]
    k = Kokoro(os.path.join(model_dir, "kokoro-v1.0.onnx"), os.path.join(model_dir, "voices-v1.0.bin"))
    ph = Phonemizer(spec.get("cast", {}))
    styles: dict[str, np.ndarray] = {}
    ok: list[str] = []
    failed: dict[str, str] = {}
    phon: dict[str, str] = {}
    for n, job in enumerate(spec["jobs"]):
        try:
            ps = ph(job["text"], job.get("lexicon", "us"), job.get("accent", ""), bool(job.get("native_polish")),
                    bool(job.get("native_german")))
            if job.get("exclaim"):
                # A shouted line: its last full stop becomes "!", which gives Kokoro's rising, forceful read.
                ps = re.sub(r"\.$", "!", ps)
            if not re.search(r"[^\s.,!?;:…—]", ps):
                raise ValueError("no phonemes")
            v = job["voice"]
            if v not in styles:
                styles[v] = voice_style(k, v)
            audio, sr = k.create(ps, voice=styles[v], speed=float(job.get("speed", 1.0)), is_phonemes=True)
            if len(audio) < sr * 0.15:
                raise ValueError("audio too short (%d samples)" % len(audio))
            os.makedirs(os.path.dirname(job["wav"]), exist_ok=True)
            wavfile.write(job["wav"], sr, np.asarray(audio, dtype=np.float32))
            ok.append(job["id"])
            phon[job["id"]] = ps
        except Exception as e:  # noqa: BLE001
            failed[job["id"]] = "%s: %s" % (type(e).__name__, e)
            print("FAILED", job["id"], failed[job["id"]], flush=True)
        if (n + 1) % 50 == 0:
            print("  neural %d / %d" % (n + 1, len(spec["jobs"])), flush=True)
    with open(result_path, "w", encoding="utf-8") as f:
        json.dump({"ok": ok, "failed": failed, "phonemes": phon, "engine": "kokoro", "version": NEURAL_VERSION}, f,
                  ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
