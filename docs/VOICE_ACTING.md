# Voice acting with the cast (UPDATE 06 Part B, T-101)

The owner and friends record the voices; the game swaps the computer voices for their takes line by line, and
keeps the computer voice for anything not recorded yet. Everything below runs from the repo root through
`tools/voice.sh` (Windows Git Bash or Linux; Python from `tools/venv`, ffmpeg from PATH).

## The loop

1. **Cast** — fill `data/voice/cast.json`: `actors` (id → name) and `characters.<gl|bs>.<code>.actor`. `"[ACTOR]"`
   is an unfilled slot; it still gets a script as `slot_<code>`. One actor can voice several characters (same id).
   The Cousins are `cousin_1..3`, The Cousins together (`CSN`) are all three, PAUL is `paul`, THE SLENDER is `devin`.
2. **Scripts** — `tools/voice.sh scripts` writes `voice_scripts/<actor>/<actor>_script.pdf` and
   `_checklist.csv` (line ID, character, text, recorded), `RECORDING_GUIDE.pdf/.txt`, `VOICE_RELEASE.txt`,
   `COUNTS.txt`, `script_index.json`. The output is committed (deterministic text/PDF, no personal data); rerun after
   editing the cast or the lines. Later sessions: `tools/voice.sh scripts --since=recorded` (per actor: lines added
   since their last import plus lines reworded after they recorded them), or `--since=<git ref | YYYY-MM-DD | index
   path>` → `<actor>_pickup_<ref>.pdf/.csv`.
3. **Send** each friend their PDF + `RECORDING_GUIDE.txt` + `VOICE_RELEASE.txt`; they reply "I agree" with a date.
4. **Inbox** — put their files in `voice_inbox/<actor>/` (any wav/m4a/mp3/flac/ogg; git-ignored, never pushed) and
   write `voice_inbox/<actor>/consent.txt` (template in `voice_inbox/README.txt`). **No consent.txt, nothing ships.**
5. **Import** — `tools/voice.sh import` (or `--actor=paul`, `--dry-run`). Then `tools/voice.sh reimport` (Godot
   headless import) so the game sees the new .ogg files.
6. **Review** — `tools/voice.sh review` serves `voice_review/index.html` on http://127.0.0.1:8765: coverage per
   actor and character, uncertain matches, unmatched speech, every line with the take playing now, the TTS, every
   alternate take and its match %. "use" / "use computer voice" / "auto", then **Save** writes
   `data/voice/selections.json`; run import again to apply.

## What the importer does (`tools/voice/pipeline.py`)

| Step | How |
|---|---|
| Normalize | ffmpeg → 48 kHz mono 24-bit WAV in `voice_work/<actor>/norm/<hash>.wav` (originals untouched) |
| Transcribe | faster-whisper, word timestamps, out of process (`transcribe_worker.py`). Python: `GRAVELIGHT_WHISPER_PY` (env or `tools/local_paths.env`), else `~/whisper-env` (the owner's existing install: faster-whisper 1.2.1 + CUDA on the RTX 5090), else `tools/venv`. Model: `GRAVELIGHT_WHISPER_MODEL`, else `large-v3` when it is already in the Hugging Face cache (it is on the PC), else `medium`. Cached per input hash + model. |
| Match | Spoken IDs found fuzzily (`voicelib.canon_id`: letters, digits, number words, character names → "W-R-N down zero one" = `WRN_DOWN_01`; every ID in the game is checked to be unambiguous when spoken). The speech after an ID is cut into takes at pauses ≥ 0.65 s (pieces merged while that improves the match). A file with no IDs falls back to matching each piece of speech against the actor's script text (≥ 0.55; flagged for review). |
| Score | 0.6 text match + 0.15 clipping + 0.1 noise floor + 0.15 length sanity; best take selected (a later read wins a near tie); every take kept with a preview in `voice_work/takes/`. |
| Clean up | ffmpeg `highpass 80 Hz, afftdn nr=8 (gentle), adeclick, acompressor 2.4:1`; trim with 80 ms pads; loudness to `voice_cast.json` (-17.5 LUFS integrated, moved by the line's delivery exactly like the TTS: shouts +2.5, quiet -3) and a -1.5 dBTP true-peak ceiling. |
| Effects | `data/voice/fx.json` per character: Operator 1930s tannoy (band-pass, saturation, crackle bed, wow/flutter), Fasbender field radio, Reinholt PA / phonograph (cylinders, samples), Liesl phonograph, the Cousins a subtle room, CSN a trio (every consenting cousin's take layered; one take alone is doubled), B&S robots a light ring-mod + comb (no pitch shift unless a chain sets `pitch_semitones`), the PA / Darkmatter a robot PA; the squad, Jakub, Bolt clean. The DSP is the TTS bake's own (`gen_vo.py` helpers run at 48 kHz). |
| Output | OGG Vorbis q5 at the path the game already plays: Gravelight `gravelight/audio/vo/<spk>/<id>.ogg` (exchange parts `<id>_p<n>`), B&S `audio/vo/<id>.ogg`. The manifest row (`data/gravelight/vo/audio_manifest.json`, `data/bs/vo/audio_manifest.json`) gets `source: human`, `actor`, `take`, `hash` (of the OGG), `script_sha` (the text recorded), `fx`, `lufs`, `duration`, `consent_date`; the TTS row is kept under `tts` and the TTS file in `gravelight/audio/vo_tts/` (a `.gdignore`'d folder). |
| Back to TTS | When consent is withdrawn/missing, the review page picks the computer voice, or the take is gone: the TTS file and row come back (B&S: the file is removed, runtime TTS speaks again). |

Rerun-safe: a line is only re-rendered when its take, its effect/loudness settings or its text change.

**Subtitles and lip flap** need no extra data: the game already times both from the audio's length (`GLVO._next_part`
emits the stream length to `GLBus.vo_line_started`, which `FaceDriver` uses for the lip flap). B&S now keeps a
subtitle, a cutscene beat and a `LinePlayer` line up for at least the recorded take's length
(`VOManager.recorded_length`). The Cousins' boss lines (not in lines.json) play a recorded take when there is one
(`GLVO.play_external`; a `%DEAD_COUSIN_NAME%` line has one take per fallen cousin, `<id>_<HAM|RCH|ALX>`).

**`gen_vo.py` and human takes:** the TTS bake keeps a human / AI row while the line's text is unchanged (also under
`--force`); if the text changes it rebakes the TTS over it and says so (the pickup script then lists the line).

## Voice test in the game

`GLVO.voice_test = true` (the dev launcher's "Map 0 — voice test (round 1–3)") prints every line as it starts with
its source (`human <actor>` / `tts` / `none`) and, after round 3, writes `logs/voice_test.txt`.

## ElevenLabs (optional, off)

`tools/voice.sh elevenlabs stock|sts|clone`. Off unless `ELEVENLABS_API_KEY` is set in the environment (never in a
file). `stock`: a stock voice for a gap line nobody recorded (never over a human take) → `source: ai_stock`. `sts`:
the voice changer on a recorded take, only when `cast.json` gives that character a `voice_changer` voice id →
`ai_sts`. `clone`: refused unless the actor's consent.txt says `ai_voice_cloning: yes`. Every AI line is marked
(`source ai_*`, `"ai": true`) in the manifest and on the review page. Commercial use needs a paid plan.

## Tests

`tools/voice.sh test` (pytest, `tests/voice/`): ID parsing and the unambiguity of every ID, fuzzy matching, the
consent gate, the cast covering every speaker, the B&S line tables matching `core/vo_manager.gd`, manifest updates,
the TTS fallback and restore, take selection, the ElevenLabs refusals, the scripts and `--since`, and the end-to-end
run on `tests/voice/fixtures/` (a synthetic session built by `tools/voice.sh synthetic` from the game's TTS lines with
the IDs spoken by Kokoro: 5 lines × 2 reads, plus a file with no IDs). The committed Whisper transcripts make it run
anywhere; `test_real_whisper` reruns Whisper when one is installed (`GRAVELIGHT_SKIP_WHISPER=1` skips it).
GUT: `gravelight/tests/unit/test_vo_human.gd`.
