# UPDATE 06 — CLOUD-READY REPO + VOICE ACTING WITH MY FRIENDS

A work order for the existing project (`C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate`). All rules from `ULTIMATE_PROMPT.md`, v2, v3, `OVERNIGHT_RUN.md`, and Updates 02–05A (all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) still apply. Work unattended: branch per part, `master` always launches, commit often, keep the `PROGRESS.md` resume line current, and write a morning report.

**Run Part A from Claude Code on my PC** (it needs my GitHub login). Part B can run on the PC or in a cloud session afterwards.

**If Update 05A/05 is mid-run:** finish or checkpoint it first (commit, update `PROGRESS.md`), then do this.

---

## PART A — Make the project run in Claude Code cloud sessions

**Goal:** I can open claude.ai/code, pick this repo, and a cloud session (a Linux box with no screen) can build, test, convert assets, and keep working on the game, using my cloud-session credits instead of my plan's usage.

1. **Secrets check before anything leaves the PC.** Scan the whole repo and its git history for API keys, tokens, passwords, `.env` files, and personal files. Use a scanner such as `gitleaks` if available, plus a grep for common key patterns.
   - Anything found: remove it, add it to `.gitignore`, and if it's in history, rewrite that history only for that file.
   - **Stop and list it in the morning report if a real secret was ever committed**, because it must be rotated.
   - Also make sure nothing from my Downloads folder or personal documents is in the repo.
2. **Git LFS:** track `*.glb *.gltf *.fbx *.blend *.png *.jpg *.wav *.ogg *.mp3 *.zip *.unitypackage *.psd` under `assets/`, `audio/`, and `gravelight/**/audio/`. Migrate the existing large files into LFS (`git lfs migrate import` on those patterns). Keep `.godot/`, `.wt/`, `logs/`, `.smoke_logs/`, `tools/venv`, `tools/tts` models, `tools_src/_downloads/`, and `morning/screenshots/**` out of git (`.gitignore`). Report the repo size before and after.
3. **Private GitHub repo:** use the GitHub CLI.
   - If `gh` isn't installed: `winget install GitHub.cli`.
   - If it isn't logged in: write the one-line step for me in `morning/NEEDS_DEVIN.md` (`gh auth login`) and **continue with the rest of Part A**.
   - Once logged in: `gh repo create bolt-and-sprocket-ultimate --private --source . --push`. Never make it public. Push every branch and tag.
4. **Cloud bootstrap:** write `tools/cloud_setup.sh`, an idempotent script that sets up a Linux cloud box:
   - downloads the **same Godot 4 version** the project uses (Linux x86_64 binary, plus export templates only if needed), and Blender (Linux build) for asset conversion;
   - installs GUT if it's not vendored, plus `ffmpeg`, Python 3, and the pip packages Part B needs;
   - imports the project headless (`godot --headless --import`);
   - runs the GUT suite and the headless smokes.

   Then write a `CLAUDE.md` at the repo root (or extend the existing one) that tells any future session:
   - "In a cloud session, run `tools/cloud_setup.sh` first."
   - **What does NOT work in the cloud:** `Play.bat`, Windows paths, the Kokoro TTS venv (unless reinstalled on Linux), the local-LLM bot (Ollama), and on-screen rendering. Screenshots must use a virtual display (Xvfb + software rendering), which is slow, so mark them optional.
   - Where the work orders live, and the `PROGRESS.md` resume rule.
5. **Make paths portable:** any tool that hard-codes `C:\Users\Devin\...` must read paths from a config file or environment variable, with the Windows paths as the default. All tests and smokes must pass on Linux as well as Windows: run the suite inside WSL or a Linux container if one is available, otherwise fix the obvious path and case-sensitivity issues by inspection, and list anything unverified.
6. **Acceptance:** the repo is on GitHub (private), LFS works (a fresh clone gets real files, not pointer stubs), `tools/cloud_setup.sh` and `CLAUDE.md` are committed, and `NEEDS_DEVIN.md` says exactly how I start a cloud session: claude.ai/code → connect GitHub → pick the repo → paste the next work order.

---

## PART B — Voice acting recorded by me and my friends

**Goal:** my friends and I record the voices. The game swaps the computer voices for our real takes, line by line, with the computer voice kept as a fallback for anything not recorded yet.

### B1. The cast sheet
Create `data/voice/cast.json`, mapping each character to an actor. Start with these placeholders and **ask me to fill them in via the morning report**; don't wait:
- **Gravelight:** DUT, PEG, DEA, WRN, OPR, JAK, FAS, REI, LSL, the inn survivors and patrons (WIE, BRA, KRO, SOB, ROT, KUB, TRU, POH), and the Cousins (HAM, RCH, ALX, CSN; to be voiced by my cousins). PAUL (to be voiced by my friend Paul) and THE SLENDER (to be voiced by me, Devin) when those bosses exist.
- **Bolt & Sprocket:** every speaker in `data/bs/story/speakers.json`.

One actor can voice several characters.

### B2. Per-actor scripts (generated, never hand-written)
`tools/voice/make_scripts.py` reads every spoken line from the game data:
- Gravelight: `data/gravelight/vo/lines.json` (including banter exchanges) and `data/gravelight/bosses/*.json`;
- Bolt & Sprocket: `data/bs/story/lines_index.json` and every other `data/bs/**` file with `who`/`text` lines.

It skips UI, banner, hint, sign, and memo text, just like `VOICE_SCRIPT_ALL_LINES.pdf` (already made, in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`). For **each actor**, it produces:
- **`voice_scripts/<actor>/<actor>_script.pdf`**: only that actor's lines, grouped by character and category. Each line shows its **ID**, the text, an acting note (derived from the line's category and `voice_cast.json` emotion data, plus any `[bracket]` directions), and short context ("plays when you go down"). Stressed `{words}` are bold. Banter and scenes show the other speakers' lines in grey as cues.
- **`voice_scripts/<actor>/<actor>_checklist.csv`**: line ID, character, text, recorded (blank). Lets them track progress.
- Lines are ordered to be recordable: same emotion together, shouting last (it tires the voice).
- **Only new or changed lines on later runs:** a `--since` mode produces a pickup script with just the lines added or reworded since the last recording session.

### B3. The one-page recording guide (to text my friends)
`voice_scripts/RECORDING_GUIDE.pdf` and a short `RECORDING_GUIDE.txt` version for texting. Plain words, one page:
- **Format: WAV, mono, 48 kHz (44.1 is fine), 24-bit or 16-bit.** If their phone can only do M4A, that's okay; avoid MP3.
- **How:**
  - PC: Audacity (free): set the project rate to 48000, record, then File → Export → WAV.
  - iPhone: an app that exports WAV (Voice Memos M4A is acceptable).
  - Android: a recorder app set to WAV.
- **Where:** a quiet room with soft stuff around (a closet full of clothes is perfect), the phone or mic a hand's width from the mouth and slightly off to the side, no fans or AC, phone on Do Not Disturb.
- **The method:** say the **line ID**, pause, read the line, pause, read it again a different way, pause for 2 seconds, next line. One long file per session is fine; name it `<name>_session<N>.wav`. Do a 10-second test first and listen back.
- **Acting tips:** read the bracket notes, don't be afraid to go big, take water breaks, record shouting lines last.
- **Where to send files:** see B4.
- **Consent:** by sending recordings, they agree their voice can be used in this game. Also include a short `VOICE_RELEASE.txt` that each person replies "I agree" to:
  - their recordings may be used, edited, and processed with effects for the game and its trailers;
  - **no AI voice cloning of them** unless they separately opt in;
  - they can ask to be removed before release.

### B4. The inbox
- Recordings go in **`voice_inbox/<actor>/`** in the project. Raw audio is git-ignored and never pushed (it's personal data). If a Google Drive shared folder is easier for my friends, document how to sync it into `voice_inbox/`, but don't require it.
- Keep a `voice_inbox/<actor>/consent.txt` per actor with the date they agreed. **The importer refuses to ship an actor's lines into the game without that file.**

### B5. The import pipeline (`tools/voice/import.py`; reruns safely)
1. **Normalize the input:** ffmpeg converts anything (M4A, MP3, stereo, 44.1 kHz) to 48 kHz mono WAV in a working folder. Never modify the originals.
2. **Transcribe:** local Whisper (faster-whisper; reuse my existing Whisper setup on this PC if one exists, otherwise install it in `tools/venv`) with word timestamps. Use `medium` or larger on the PC, and a smaller model in the cloud if needed.
3. **Split and match:**
   - Find each spoken **line ID** in the transcript (fuzzy: "W-R-N down zero one" → `WRN_DOWN_01`), then cut out the takes that follow it. Silence detection marks take boundaries.
   - If the actor didn't say IDs, fall back to fuzzy-matching the take's transcript against that actor's script text (thresholded), and flag uncertain matches for review.
4. **Pick the best take:** score each take on text match, clipping, noise floor, and length sanity. Keep every take, and choose the best as `selected`.
5. **Clean up:** trim silence (with ~80 ms pads), high-pass around 80 Hz, gentle de-noise (RNNoise or ffmpeg `afftdn`, never so strong it sounds underwater), de-click, a light compressor, and **loudness to −18 LUFS** (match the existing `voice_cast.json` loudness target if it differs), peak at −1 dBTP.
6. **Character effects** in `data/voice/fx.json`, per character:
   - **The Operator:** 1930s radio (band-pass, slight saturation, a crackle bed, tiny wow/flutter).
   - **Fasbender's radio lines:** a field-radio filter.
   - **Reinholt's and Liesl's recordings:** a phonograph-cylinder filter.
   - **The Cousins:** subtle, eerie room reverb; the CSN trio lines get layered and doubled.
   - **Bolt & Sprocket robots** (Sprocket, Blartz, GLAMBOT, the PA, etc.): light robot treatments that keep the actor's performance (no full pitch-shift unless the cast sheet asks for it).
   - The squad, Jakub, and Bolt: clean.
7. **Output:** OGG Vorbis per line at the path the game already uses, plus `data/gravelight/vo/audio_manifest.json` (and the B&S equivalent) updated per line with `source: "human"`, the actor, the take id, and a hash. Lines without a human take keep the computer voice: `source: "tts"`.
8. **Lip flap and subtitles:** update any per-line duration and timing data the game uses so subtitles and lip flap match the new audio length.
9. **Review page:** generate `voice_review/index.html`, a local page (open it in a browser on the PC) listing every line with a player for the selected take, alternate takes, the transcript-vs-script match %, and buttons to pick a different take. It writes choices back to `data/voice/selections.json`, and the importer respects them on rerun. It also shows **coverage per actor and character** (recorded / total) and a list of lines with uncertain matches.
10. **Tests:** GUT/pytest for ID parsing, fuzzy matching, the consent gate, manifest updates, and the fallback to TTS for missing lines. One end-to-end test uses a short synthetic recording built from the existing TTS lines (including spoken IDs) so the pipeline can be verified before any friend sends anything.

### B6. ElevenLabs (optional; off by default)
- An optional `tools/voice/elevenlabs.py`, with the key read from an environment variable (`ELEVENLABS_API_KEY`) and **never written to any file or committed**.
- Uses:
  1. **Stock voices for small roles or gap lines** nobody recorded (marked `source: "ai_stock"`).
  2. **Voice changer (speech-to-speech)** on a friend's take when the cast sheet asks for it (e.g. making someone sound older).
  3. **Cloning a friend's voice ONLY if their `consent.txt` explicitly says they opt in to AI cloning.** The tool refuses otherwise.
- Every AI-generated line is clearly marked in the manifest and on the review page so we always know which lines are real.
- Don't buy or sign up for anything. If I want this, `NEEDS_DEVIN.md` explains which plan allows commercial use and how to set the key.

### B7. Acceptance for Part B
- Per-actor script PDFs and checklists exist for every cast slot, plus the recording guide and release text.
- The end-to-end test passes on the synthetic recording.
- The review page opens and shows coverage.
- The game plays human takes where present and falls back to TTS elsewhere, with no missing-audio errors in the smokes.
- **The morning report contains:** the cast-sheet placeholders for me to fill in, the exact text to send my friends (guide + release), and the line counts per actor.

---

## FINISH
- Run all GUT tests and smokes.
- Add `Play.bat` buttons: "Voice review page", "Map 0 — voice test (round 1–3)".
- Morning report: Part A status (repo URL, LFS size, anything secret that needs rotating, how to start a cloud session), Part B status (each step works / partly / not started), and what I need to do next.
