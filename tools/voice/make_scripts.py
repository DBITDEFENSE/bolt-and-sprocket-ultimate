#!/usr/bin/env python3
"""Per-actor voice scripts, generated from the game data (UPDATE 06 B2/B3, T-101). Never hand-edit the output.

  tools/voice.sh scripts                    every actor: voice_scripts/<actor>/<actor>_script.pdf + _checklist.csv,
                                            RECORDING_GUIDE.pdf/.txt, VOICE_RELEASE.txt, COUNTS.txt, script_index.json
  tools/voice.sh scripts --since=REF        pickup scripts: only lines added or reworded since REF, where REF is a git
                                            ref / commit, a date (YYYY-MM-DD: the script index as committed then), a
                                            path to an older script_index.json, or "recorded" (per actor: lines added
                                            since that actor's last import + lines reworded after they recorded them)
  tools/voice.sh scripts --actor=paul       one actor only

Lines come from data/gravelight/vo/lines.json (banter / tag exchanges per part), data/gravelight/bosses/*.json and
every Bolt & Sprocket line table the game voices (voicelib.BS_LINE_SOURCES); UI, banner, hint, sign and memo text
is skipped. Who reads what comes from data/voice/cast.json. Order inside a script: by character, then quiet and calm
lines first and shouting last (it tires the voice), so the same emotion stays together.
Needs reportlab (tools/venv). Output is deterministic (same data -> same bytes).
"""
from __future__ import annotations

import argparse
import datetime as dt
import html
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402

FONT_DIR = os.path.join(V.ROOT, "assets", "third_party", "google_fonts", "ibm-plex-mono")

GUIDE_TXT = """VOICE RECORDING GUIDE (Terms & Conditions / Claude Zombies / Bolt & Sprocket)

Thank you! Here is everything on one page.

FORMAT
- WAV, mono, 48 kHz (44.1 kHz is fine), 24-bit or 16-bit.
- If your phone can only do M4A, that's okay. Please avoid MP3.

HOW
- PC: Audacity (free). Set the Project Rate (bottom left) to 48000, press Record, then File > Export > Export as WAV.
- iPhone: an app that exports WAV (Voice Memos M4A is acceptable).
- Android: a recorder app set to WAV.

WHERE
- A quiet room with soft stuff around you. A closet full of clothes is perfect.
- Phone or mic a hand's width from your mouth, slightly off to the side.
- No fans or AC running. Phone on Do Not Disturb.

THE METHOD
1. Do a 10-second test first and listen back.
2. Say the LINE ID out loud (it's on your script, e.g. "D-U-T reload zero one").
3. Pause. Read the line.
4. Pause. Read it again a different way.
5. Pause for 2 seconds. Next line.
- One long file per session is fine. Name it <yourname>_session<N>.wav (paul_session1.wav).
- Fluffed a line? Just say the ID again and redo it. The best take is picked automatically; nothing needs editing.

ACTING TIPS
- Read the [bracket] notes and the acting note under each line. Don't say the brackets out loud.
- Bold words are the ones to stress.
- Don't be afraid to go big. It's a game: bigger is better than flat.
- Take water breaks. Shouting lines are at the end of your script: record them last.

SENDING
- Send the files to Devin (a shared Google Drive folder, a USB stick, or any file-transfer link is fine).

CONSENT
- By sending recordings you agree your voice can be used in this game.
- Please also read VOICE_RELEASE.txt and reply "I agree" with the date.
- No AI voice cloning of you, ever, unless you separately opt in.
"""

RELEASE_TXT = """VOICE RELEASE (version 1) - Terms & Conditions (Claude Zombies / Bolt & Sprocket)

Please read this, then reply "I agree" with today's date.

1. My recordings may be used, edited, and processed with effects (for example a radio or robot sound) in this game
   and in its trailers and promotional videos.
2. No AI voice cloning of me: nobody may train or make an AI copy of my voice unless I separately and explicitly
   opt in, in writing.
3. I can ask to be removed before the game is released, and my recordings will be taken out.
4. My raw recordings stay private: they are not published, only the finished lines in the game.

Reply with:  I agree - <your name> - <date>
(Optional, only if you want it: "I also opt in to AI voice cloning of my voice for this game.")
"""

INBOX_README = """voice_inbox/ - recordings from the cast (UPDATE 06 B4, T-101). EVERYTHING IN HERE EXCEPT THIS FILE IS
GIT-IGNORED AND NEVER PUSHED: raw recordings are personal data.

Layout (one folder per actor id from data/voice/cast.json, lowercase):
  voice_inbox/<actor>/consent.txt          REQUIRED before anything of theirs ships into the game. Their "I agree"
                                           to voice_scripts/VOICE_RELEASE.txt with the date, e.g.:
                                               I agree.
                                               name: Paul
                                               date: 2026-10-30
                                               ai_voice_cloning: no
                                           Only "ai_voice_cloning: yes" allows tools/voice/elevenlabs.py to clone.
                                           To remove someone: write "withdrawn" in it (or delete it) and re-run import.
  voice_inbox/<actor>/<actor>_session1.wav any audio (wav, m4a, flac, ogg, mp3...); any number of files.

Then:  tools/voice.sh import            (or: tools/voice.sh import --actor=paul)
       tools/voice.sh review            (opens the review page)

Google Drive: if friends upload to a shared Drive folder, sync it here with Google Drive for desktop (point a folder
at voice_inbox/<actor>/) or download the folder and unzip it into voice_inbox/<actor>/. Not required.
"""


def _fonts():
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    if "Plex" in pdfmetrics.getRegisteredFontNames():
        return
    pdfmetrics.registerFont(TTFont("Plex", os.path.join(FONT_DIR, "IBMPlexMono-Regular.ttf")))
    pdfmetrics.registerFont(TTFont("PlexB", os.path.join(FONT_DIR, "IBMPlexMono-Bold.ttf")))
    pdfmetrics.registerFont(TTFont("PlexS", os.path.join(FONT_DIR, "IBMPlexMono-SemiBold.ttf")))
    pdfmetrics.registerFontFamily("Plex", normal="Plex", bold="PlexB", italic="Plex", boldItalic="PlexB")


def _styles():
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib import colors
    base = ParagraphStyle("base", fontName="Plex", fontSize=9.5, leading=12.5)
    return {
        "title": ParagraphStyle("title", parent=base, fontName="PlexB", fontSize=18, leading=22, spaceAfter=6),
        "h1": ParagraphStyle("h1", parent=base, fontName="PlexB", fontSize=14, leading=17, spaceBefore=8, spaceAfter=4),
        "h2": ParagraphStyle("h2", parent=base, fontName="PlexB", fontSize=10.5, leading=13, spaceBefore=8, spaceAfter=2,
                             textColor=colors.HexColor("#7a1f12"), keepWithNext=1),
        "h3": ParagraphStyle("h3", parent=base, fontName="PlexS", fontSize=8.5, leading=11, spaceBefore=4,
                             textColor=colors.HexColor("#555555"), keepWithNext=1),
        "body": base,
        "small": ParagraphStyle("small", parent=base, fontSize=8, leading=10.5, textColor=colors.HexColor("#444444")),
        "id": ParagraphStyle("id", parent=base, fontName="PlexB", fontSize=8.5, leading=11, spaceBefore=5),
        "line": ParagraphStyle("line", parent=base, fontSize=10.5, leading=14, leftIndent=10),
        "note": ParagraphStyle("note", parent=base, fontSize=7.8, leading=10, leftIndent=10, textColor=colors.HexColor("#555555")),
        "cue": ParagraphStyle("cue", parent=base, fontSize=8.8, leading=11.5, leftIndent=10, textColor=colors.HexColor("#9a9a9a")),
    }


def markup(text: str) -> str:
    """Script text -> reportlab markup: {stress} bold, [directions] grey, *markers* grey, %VARS% blue."""
    t = html.escape(text, quote=False)
    t = re.sub(r"\{([^}]*)\}", r"<b>\1</b>", t)
    t = re.sub(r"\[([^\]]*)\]", r'<font color="#8a6d3b">[\1]</font>', t)
    t = re.sub(r"\*([^*]+)\*", r'<font color="#8a6d3b">*\1*</font>', t)
    t = re.sub(r"%([A-Z_]+)%", r'<font color="#1f5fa8">‹\1›</font>', t)
    return t


def acting_note(ln: V.Line) -> str:
    bits = [V.DELIVERY_NOTE.get(ln.delivery, "")]
    d = V.directions(ln.text)
    if d:
        bits.append("Direction: " + "; ".join(d) + ".")
    if ln.vocal_only:
        bits.append("No words: just the sound described.")
    if "(" in V.spoken_text(ln.text) and ln.char in ("HAM", "RCH", "ALX", "CSN", "WRN", "JAK", "DUT"):
        bits.append("The (brackets) are the subtitle's translation: don't read them.")
    return " ".join(b for b in bits if b)


def _cue_name(spk: str, cast: dict, game: str) -> str:
    return V.SPEAKER_NAMES_GL.get(spk) or V.character_label(cast, game, spk)


def _story(actor: str, lines: list[V.Line], cast: dict, title_extra: str, date: str) -> list:
    from reportlab.platypus import Paragraph, Spacer, KeepTogether, PageBreak
    st = _styles()
    name = V.actor_name(cast, actor)
    story = [Paragraph("TERMS &amp; CONDITIONS — voice script", st["small"]),
             Paragraph(html.escape("%s%s" % (name, title_extra)), st["title"])]
    chars: dict = {}
    for ln in lines:
        chars.setdefault((ln.game, ln.char), []).append(ln)
    summary = ", ".join("%s (%d)" % (V.character_label(cast, g, c), len(v)) for (g, c), v in chars.items())
    story += [Paragraph("%d lines · %s · generated from the game data %s" % (len(lines), html.escape(summary), date), st["small"]),
              Spacer(1, 6),
              Paragraph("<b>How to record:</b> say the <b>ID</b> (the bold code, read it like the grey 'say:' hint), pause, "
                        "read the line, pause, read it again a different way, pause 2 seconds, next. Brackets are directions: "
                        "don't read them. <b>Bold</b> words are stressed. Grey lines are the other characters (cues), "
                        "not yours. Shouting lines come last. Full guide: RECORDING_GUIDE.pdf.", st["body"]),
              Spacer(1, 4)]
    if not lines:
        story.append(Paragraph("No lines yet: this character is not in the game yet. A script will be generated when it is.", st["h2"]))
    for (game, char), cl in chars.items():
        c = cast.get("characters", {}).get(game, {}).get(char, {})
        story.append(PageBreak())
        story.append(Paragraph(html.escape(V.character_label(cast, game, char)) + " <font size=9 color='#777777'>(%s · %s · %d lines)</font>"
                               % (html.escape(char), "Claude Zombies" if game == "gl" else "Bolt &amp; Sprocket", len(cl)), st["h1"]))
        if c.get("who"):
            story.append(Paragraph(html.escape(str(c["who"])), st["small"]))
        if c.get("voice_notes"):
            story.append(Paragraph("<b>Voice notes:</b> " + html.escape(str(c["voice_notes"])), st["small"]))
        cur_del, cur_sec = None, None
        for ln in V.recording_order(cl):
            if ln.delivery != cur_del:
                cur_del, cur_sec = ln.delivery, None
                head = {"shout": "SHOUTING — record these last", "hurt": "HURT"}.get(ln.delivery, ln.delivery.upper())
                story.append(Paragraph(head + " <font size=8 color='#777777'>· " + html.escape(V.DELIVERY_NOTE.get(ln.delivery, "")) + "</font>", st["h2"]))
            if ln.section != cur_sec:
                cur_sec = ln.section
                story.append(Paragraph(html.escape(ln.section), st["h3"]))
            block = [Paragraph("%s <font name='Plex' size=7.5 color='#888888'>say: %s</font>" % (html.escape(ln.file_id), html.escape(V.say_id(ln.file_id))), st["id"])]
            if ln.cues:
                for spk, txt, mine in ln.cues:
                    who = html.escape(_cue_name(spk, cast, game))
                    if mine:
                        block.append(Paragraph("<b>%s:</b> %s" % (who.upper(), markup(txt)), st["line"]))
                    else:
                        block.append(Paragraph("%s: %s" % (who, html.escape(V.spoken_text(txt))), st["cue"]))
            else:
                block.append(Paragraph(markup(ln.text), st["line"]))
            note = acting_note(ln)
            if ln.context:
                note += " · " + ln.context[0].upper() + ln.context[1:] + "."
            block.append(Paragraph(html.escape(note), st["note"]))
            story.append(KeepTogether(block))
    return story


def _page(canvas, doc):
    canvas.saveState()
    canvas.setFont("Plex", 7)
    canvas.setFillGray(0.45)
    canvas.drawString(36, 22, doc.title)
    canvas.drawRightString(doc.pagesize[0] - 36, 22, "page %d" % doc.page)
    canvas.restoreState()


def build_pdf(path: str, story: list, title: str) -> None:
    from reportlab import rl_config
    from reportlab.lib.pagesizes import letter
    from reportlab.platypus import SimpleDocTemplate
    rl_config.invariant = 1
    os.makedirs(os.path.dirname(path), exist_ok=True)
    doc = SimpleDocTemplate(path, pagesize=letter, leftMargin=36, rightMargin=36, topMargin=36, bottomMargin=36,
                            title=title, author="Terms & Conditions voice pipeline", subject="voice script",
                            creator="tools/voice/make_scripts.py")
    doc.build(story, onFirstPage=_page, onLaterPages=_page)


def text_pdf(path: str, text: str, title: str, size: float = 9.0) -> None:
    from reportlab.platypus import Paragraph, Spacer
    from reportlab.lib.styles import ParagraphStyle
    st = ParagraphStyle("t", fontName="Plex", fontSize=size, leading=size * 1.32)
    hd = ParagraphStyle("h", fontName="PlexB", fontSize=size + 0.6, leading=size * 1.5, spaceBefore=3)
    story = []
    for para in text.strip().split("\n"):
        if not para.strip():
            story.append(Spacer(1, 3))
        elif para.isupper() or para == text.strip().split("\n")[0]:
            story.append(Paragraph(html.escape(para), hd))
        else:
            story.append(Paragraph(html.escape(para).replace("  ", "&nbsp;&nbsp;"), st))
    build_pdf(path, story, title)


def checklist(path: str, lines: list[V.Line], cast: dict) -> None:
    rows = [["line_id", "character", "text", "recorded"]]
    for ln in V.recording_order(lines):
        rows.append([ln.file_id, V.character_label(cast, ln.game, ln.char), V.spoken_text(ln.text), ""])
    V.write_csv(path, rows)


# ───────────────────────────────────────────────────────────── --since

def _git(*args: str) -> str:
    try:
        return subprocess.run(["git", *args], cwd=V.ROOT, capture_output=True, text=True, encoding="utf-8",
                              timeout=60).stdout
    except Exception:  # noqa: BLE001
        return ""


def index_at(ref: str) -> dict | None:
    """The script index as it was at REF (git ref, date, or a json path)."""
    import json
    if os.path.exists(ref):
        return V.load_json(ref)
    rel = "voice_scripts/script_index.json"
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", ref):
        commit = _git("log", "-1", "--format=%H", "--before=%sT23:59:59" % ref, "--", rel).strip()
        if not commit:
            return {}
        ref = commit
    out = _git("show", "%s:%s" % (ref, rel))
    if not out.strip():
        return None
    return json.loads(out)


def pickup_filter(actor: str, lines: list[V.Line], since: str) -> list[V.Line]:
    if since == "recorded":
        sess = V.load_json(V.SESSIONS_PATH).get(actor, {})
        base = index_at(sess["commit"]) if sess.get("commit") else None
        man = {**V.load_manifest("gl").get("files", {}), **V.load_manifest("bs").get("files", {})}
        out = []
        for ln in lines:
            row = man.get(ln.file_id, {})
            if row.get("source") == "human" and row.get("actor") == actor:
                if row.get("script_sha") != ln.script_sha:
                    out.append(ln)            # reworded after they recorded it
            elif base is not None and ln.file_id not in base:
                out.append(ln)                # added since their last session
        return out
    base = index_at(since)
    if base is None:
        raise SystemExit("--since=%s: no voice_scripts/script_index.json there" % since)
    return [ln for ln in lines if base.get(ln.file_id) != ln.script_sha]


# ───────────────────────────────────────────────────────────── main

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", default="", help="pickup mode: git ref / YYYY-MM-DD / index path / 'recorded'")
    ap.add_argument("--actor", default="", help="only this actor id")
    ap.add_argument("--out", default=V.SCRIPTS_DIR)
    ap.add_argument("--no-pdf", action="store_true", help="checklists and counts only (fast)")
    a = ap.parse_args(argv)
    _fonts()
    cast = V.load_cast()
    lines = V.collect_all()
    by_actor = V.lines_by_actor(lines, cast)
    # every cast slot gets a script, also characters with no lines yet (PAUL, THE SLENDER)
    for game, chars in cast.get("characters", {}).items():
        for code in chars:
            for act in V.actors_for(cast, game, code):
                by_actor.setdefault(act, [])
    import json
    date = "(script version %s)" % V.sha16(json.dumps(V.script_index(lines), sort_keys=True))[:8]
    os.makedirs(a.out, exist_ok=True)
    if not a.since and not a.actor:
        with open(os.path.join(a.out, "RECORDING_GUIDE.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(GUIDE_TXT)
        with open(os.path.join(a.out, "VOICE_RELEASE.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(RELEASE_TXT)
        if not a.no_pdf:
            text_pdf(os.path.join(a.out, "RECORDING_GUIDE.pdf"), GUIDE_TXT, "Voice recording guide", 8.6)
        V.save_json(os.path.join(a.out, "script_index.json"), V.script_index(lines))
    counts = []
    for actor in sorted(by_actor):
        if a.actor and actor != a.actor:
            continue
        al = by_actor[actor]
        adir = os.path.join(a.out, actor)
        if a.since:
            al = pickup_filter(actor, al, a.since)
            if not al:
                continue
            tag = re.sub(r"[^A-Za-z0-9-]+", "_", a.since)[:24]
            checklist(os.path.join(adir, "%s_pickup_%s_checklist.csv" % (actor, tag)), al, cast)
            if not a.no_pdf:
                build_pdf(os.path.join(adir, "%s_pickup_%s.pdf" % (actor, tag)),
                          _story(actor, al, cast, " — pickup lines (since %s)" % a.since, date),
                          "%s pickup script" % V.actor_name(cast, actor))
            print("pickup %-22s %4d lines" % (actor, len(al)))
            continue
        checklist(os.path.join(adir, "%s_checklist.csv" % actor), al, cast)
        if not a.no_pdf:
            build_pdf(os.path.join(adir, "%s_script.pdf" % actor), _story(actor, al, cast, "", date),
                      "%s voice script" % V.actor_name(cast, actor))
        per = {}
        for ln in al:
            per[(ln.game, ln.char)] = per.get((ln.game, ln.char), 0) + 1
        counts.append((actor, len(al), per))
    if not a.since and not a.actor:
        rows = ["Line counts per actor (voice_scripts/ %s; %d spoken lines in all)" % (date, len(lines)), ""]
        for actor, n, per in counts:
            chars = ", ".join("%s %d" % (V.character_label(cast, g, c), k) for (g, c), k in per.items()) or "no lines yet"
            rows.append("%-22s %5d   %s" % (actor, n, chars))
        with open(os.path.join(a.out, "COUNTS.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(rows) + "\n")
        print("\n".join(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
