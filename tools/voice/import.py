#!/usr/bin/env python3
"""Imports the cast's recordings into the game (UPDATE 06 B5, T-101). Safe to rerun: only new work is done.

  tools/voice.sh import                   every actor folder in voice_inbox/
  tools/voice.sh import --actor=paul      one actor (comma list allowed)
  tools/voice.sh import --dry-run         analyse and refresh the review page, change nothing in the game
  tools/voice.sh import --model=small     a smaller Whisper model (also GRAVELIGHT_WHISPER_MODEL)

What it does: pipeline.py's docstring. Afterwards: tools/voice.sh review (the review page), then reimport the
project in Godot once so it sees new .ogg files (`"$GODOT" --headless --editor --quit-after 900 --path .`).
Nothing of an actor ships without voice_inbox/<actor>/consent.txt.
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipeline as P  # noqa: E402
import review  # noqa: E402
import voicelib as V  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--actor", default="", help="only these actor ids (comma list)")
    ap.add_argument("--dry-run", action="store_true", help="analyse only; the game is not touched")
    ap.add_argument("--model", default="", help="Whisper model (default: large-v3 if cached on this PC, else medium)")
    a = ap.parse_args(argv)
    if not os.path.isdir(V.INBOX_DIR):
        os.makedirs(V.INBOX_DIR, exist_ok=True)
    actors = [x.strip() for x in a.actor.split(",") if x.strip()] or None
    res = P.run(actors=actors, dry=a.dry_run, model=a.model or None)
    page = review.build()
    print("\n%d takes, %d shipped, %d back to TTS, %d unmatched pieces%s" % (
        len(res.takes), len(res.shipped), len(res.reverted), len(res.unmatched),
        "" if not res.blocked else "; blocked: " + ", ".join("%s (%s)" % kv for kv in res.blocked.items())))
    print("review page:", page)
    if res.shipped or res.reverted:
        print("Godot: reimport once so the new audio is picked up (tools/voice.sh reimport)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
