# TERMS & CONDITIONS

One Godot 4 game with three connected stories:
- **Bolt & Sprocket**, remade from the web game
- **CLAUDE ZOMBIES** (code name GRAVELIGHT), WW2 zombies
- **THE FINE PRINT**, the origin story that bridges them

Theme: *nobody reads the fine print.*

- Start here: `docs/GDD.md`, `docs/CANON.md`, `docs/ROADMAP.md`.
- Run the unit tests (headless, silent): `./run_tests.sh`
- Re-extract the original data: `node tools/extract_bs.mjs && node tools/port_story.mjs` (first run `npm install` in `tools/`)
- The original web game lives at `C:\Users\Devin\PROJECTS\bolt-and-sprocket\` and is **read-only**. The project works from the copies in `reference/bs_web/`.

## CLAUDE ZOMBIES

The zombies mode's player-facing name is **CLAUDE ZOMBIES** (code name GRAVELIGHT; `Game.GAME_MODE_NAME`). The folder `gravelight/`, class names and save keys keep the old name. "Operation Gravelight" is still the squad's mission in the story. Its wordmark: `gravelight/ui/wordmark/claude_zombies.svg`/`.png` (rebuild: `python tools/gen_wordmark_svg.py`, then `"$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/render_wordmark.gd`). See `docs/DECISIONS.md` T-140.
