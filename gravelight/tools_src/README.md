# tools_src

Headless tool scripts for building project content. They aren't part of the game build.

## gen_sfx.gd: procedural placeholder audio
Synthesizes every M1 placeholder sound from scratch (no samples) and writes 16-bit mono 44.1 kHz WAVs. The seed is fixed, so the output is reproducible. Every file is normalized to -3 dBFS, with short edge fades.

```
godot --headless --path . --script res://gravelight/tools_src/gen_sfx.gd
```
Then open the editor, or run `godot --headless --editor --quit-after 300 --path .`, to import the new WAVs.

| Generator | Output | How it's built |
|---|---|---|
| `_gen_weapons` | `audio/sfx/placeholder/gun_*`, `reload_*`, `bolt_cycle`, `knife_*`, `grenade_*` | Gunshots: crack (high-passed noise) + pitch-drop body + falling low-pass blast + saturation + room reverb. The rifle adds a slap-back echo. Mechanics: band-passed noise clicks with metallic rings, and filtered-noise scrapes. The grenade adds a sub drop and scattered debris clicks. |
| `_gen_feedback` | `hitmarker`, `headshot`, `buy`, `deny`, `scrip_tick`, `door_open`, `player_hurt`, `heartbeat` | Ticks, an inharmonic two-tone register ding, a beating low buzz, a stick-slip door scrape + thunk, impact + breath, and a lub-dub (loops at 1.6 s). |
| `_gen_barricades` | `board_break`, `board_place`, `board_slam` | Wood crack clusters, hammer knocks, and a heavy slam with rattle. |
| `_gen_zombies` | `zombie_{groan,attack,death,sprint}_{1..3}` | A pitch-wobbled saw + rasp noise through 3 formant band-passes, amplitude "fry", and saturation. The 3 variants per type use different pitch, length, and vowel. |
| `_gen_music` | `audio/music/placeholder/round_start`, `round_end`, `game_over`, `ambient_wind` | "Brass" from detuned saws with an envelope-tracked low-pass. Synthesized timpani and an inharmonic bell. The wind is gusting band-passed noise + a whistle, crossfaded into a seamless 20 s loop. |

The DSP helpers (state-variable filter, one-pole high-pass, Schroeder reverb, envelopes, oscillators, crossfade looping) are at the top of the script.

## M1 tools
| File | What it does |
|---|---|
| `gen_map00.gd` | Generates `maps/map00_crossroads/map00.tscn`: geometry, lights, baked navmesh, gameplay nodes. The source of truth for the greybox map. |
| `gen_weapons_json.py` | One-time snapshot that created `data/weapons.json` from WEAPONS.md. Edit the JSON directly now. |
| `check_scripts.gd` | Compiles every script and lists failures. |
| `smoke_map00.tscn` | Headless round-loop test: navmesh connectivity, zombie behavior, round progression. |
| `smoke_interact.tscn` | Headless scripted gameplay QA through simulated input (buy, door, repair, shoot, reload, knife, grenade, game over). |
| `perf_map00.tscn` | Windowed perf check with 24 active zombies. |
| `shots_map00.tscn` | Windowed screenshot capture to `user://shots/`. |
| `gun_gallery.tscn` | Side-view render of every WeaponModels model → `user://shots/guns_*.png`. |
| `vm_shots.tscn` | Viewmodel contact sheets (hip / ADS / reload stages) → `user://shots/vm_sheet_*.png`. No Player in the tree, so the mouse is never captured. Options after `--`: `--out=<dir>` (write the sheets there instead), `--only=mp40,mg42` (just these weapon ids), `--rows=<n>` (rows per sheet), `--tw=<px>` (tile width), `--inspect=hand_r\|hand_l\|muzzle` (close-up camera on that part instead of the full view). |
| `gen_audio.py` | M6 audio pass: synthesizes every SFX, ambience bed and music cue from scratch (numpy + scipy, deterministic per-file seeds) into `audio/sfx/*` and `audio/music/`, and merges the key → files table into `data/audio.json` (existing per-key tuning is kept). `python tools_src/gen_audio.py` for everything, `python tools_src/gen_audio.py zombie_` for one key prefix; then reimport (`godot --headless --editor --quit-after 300 --path .`). |
| `crate_shots.tscn` | Crate cycling / offered / Herr Tamtam + chalk wall-buys → `user://shots/crate_*.png`. |

Run windowed render tools silently and off-screen: `--audio-driver Dummy --position -4000,-4000 --resolution 1280x720`.
