# CLAUDE.md — TERMS & CONDITIONS (GRAVELIGHT + Bolt & Sprocket), Godot 4.7.2

## First thing in every session
1. **Read `PROGRESS.md`.** If it has a `RESUME HERE:` line, continue exactly from it. Keep that line current after every commit (a fresh session must be able to continue from it alone).
2. **In a cloud session (Linux, no screen): run `tools/cloud_setup.sh` first** (`--quick` for a short test pass, `--no-tests` to only set up). It installs Godot 4.7.2 (Linux), Blender 5.1.2, ffmpeg, Python packages, pulls Git LFS files, imports the project headless and runs the tests. It is idempotent.
3. Read `docs/DECISIONS.md` for the decisions behind the area you touch (T-0NN paragraphs), and `morning/MORNING_REPORT.md` for the last run.

## Where the work orders live
- The owner writes work orders as Markdown files. Copies of every one so far are in `docs/work_orders/` (ULTIMATE_PROMPT v1/v2/v3, OVERNIGHT_RUN, UPDATE_02..06, FREE_ASSET_LIST, ASSET_SHOPPING_LIST). The originals are on the owner's PC in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\` (never modify that folder).
- In a cloud session the next work order is pasted into the chat. Its rules stack on top of the earlier ones: "All rules from ULTIMATE_PROMPT.md, v2, v3, OVERNIGHT_RUN.md and Updates 02..NN still apply."
- Work unattended per `docs/work_orders/OVERNIGHT_RUN.md`: never stop to ask; pick the sensible option and log it in `docs/DECISIONS.md`; branch per section, `master` always launches, commit often; finish with `morning/MORNING_REPORT.md` (short, phone-readable) and `morning/NEEDS_DEVIN.md` for anything only the owner can do.

## Commands (run from the repo root; `tools/env.sh` picks the Godot/Blender/Python paths per OS)
- Tool paths: `. tools/env.sh` sets `GODOT`, `GODOT_W`, `BLENDER`, `PYTHON`. Override per machine in `tools/local_paths.env` (git-ignored; `cloud_setup.sh` writes it on Linux).
- Import / class cache: `"$GODOT" --headless --audio-driver Dummy --editor --quit-after 900 --path .`
- Script check: `"$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/check_scripts.gd`
- Unit tests (GUT 9.6, vendored in `addons/gut`): `"$GODOT" --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json [-gselect=test_name]`
- Smoke tests: `tools/run_smokes.sh [log_dir] [name_filter]` (one RESULT line each; exit code = failures). Give a log dir under `.smoke_logs/`.
- Assets: `python -I tools/assets_manifest.py [--check]` after adding anything under `assets/` (the GUT licence gate needs `LICENSE.txt` + `SOURCE.txt` in every asset folder); `docs/ART_BIBLE.md`, `docs/CHARACTER_PIPELINE.md`, `docs/WEAPON_MODELS.md`.

## What does NOT work in a cloud session
- `Play.bat` and the dev launcher's windowed buttons (Windows, needs a screen).
- Windows paths (`C:\...`, `.exe` tools). Use `tools/env.sh`; never hard-code a home path.
- The Kokoro neural TTS venv from the PC (`tools/venv`, `tools/tts`): reinstall on Linux with `tools/cloud_setup.sh --tts` if voice lines must be regenerated. The Windows OneCore voices (`gen_vo.py` fallback) never work on Linux.
- The local-LLM bot (Ollama, `bot_local_ai`): there is no Ollama in the cloud; leave it off (tests set their own settings).
- On-screen rendering. Screenshots, clips, minimap bakes, `ads_check` with shots and the FPS bench need a GPU window: in the cloud they only run under a virtual display (`xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --rendering-driver opengl3 ...`, software rendering), which is slow. Treat them as **optional**; prefer the headless forms (`ads_check.sh --headless --no-shots`, unit tests, smokes).

## Rules that always apply (details in docs/work_orders and DECISIONS)
- Licensing: CC0, our own work, or CC-BY with credit; never NC, editorial, NoAI, rips or anything from a commercial game. No real-world brand names in game text.
- Jakub is a person and a hero, never a joke, never a zombie. The Cousins are never sexualized.
- Gameplay timings, hitboxes, navmesh and prompts don't change in an art pass.
- On the owner's PC: rendered Godot windows only with the owner's OK (they pop up on screen); keep them off-screen (`--position -4000,-4000`) and silent (`--audio-driver Dummy`). Never kill Godot processes you didn't start.
- Secrets: never commit keys or tokens; read them from environment variables (e.g. `ELEVENLABS_API_KEY`).
- Commits end with the `Co-Authored-By:` line the session gives.
