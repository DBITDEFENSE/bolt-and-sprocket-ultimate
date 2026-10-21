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
| `check_scripts.gd` | Compiles every script under `res://gravelight/*` and `res://tests` and lists failures. `godot --headless --path . --script res://gravelight/tools_src/check_scripts.gd` |
| `smoke_map00.tscn` | Headless round-loop test: navmesh connectivity, zombie behavior, round progression. |
| `smoke_interact.tscn` | Headless scripted gameplay QA through simulated input (buy, door, repair, shoot, reload, knife, grenade, game over). |
| `perf_map00.tscn` | Windowed perf check with 24 active zombies. |
| `shots_map00.tscn` | Windowed screenshot capture to `user://shots/`. |
| `gun_gallery.tscn` | Side-view render of every WeaponModels model → `user://shots/guns_*.png`. |
| `vm_shots.tscn` | Viewmodel contact sheets (hip / ADS / reload stages) → `user://shots/vm_sheet_*.png`. No Player in the tree, so the mouse is never captured. Options after `--`: `--out=<dir>` (write the sheets there instead), `--only=mp40,mg42` (just these weapon ids), `--rows=<n>` (rows per sheet), `--tw=<px>` (tile width), `--inspect=hand_r\|hand_l\|muzzle` (close-up camera on that part instead of the full view). |
| `gen_audio.py` | M6 audio pass: synthesizes every SFX, ambience bed, music cue and machine jingle from scratch (numpy + scipy, deterministic per-file seeds) into `gravelight/audio/sfx/*`, `gravelight/audio/music/` and `gravelight/audio/jingles/`, and merges the key → files table into `data/gravelight/audio.json` (existing per-key tuning is kept). `python gravelight/tools_src/gen_audio.py` for everything, `python gravelight/tools_src/gen_audio.py zombie_,perk_overclock` for one or more key prefixes; then reimport (`godot --headless --editor --quit-after 300 --path .`). Overclock Cordial's burst / arc / cap-off and its jingle (`gen_overclock`, T-034) are the pattern for a machine jingle: the key `jingle_<perk_id>` on the Jingles bus is what `PerkMachine._play_jingle` looks for. |
| `crate_shots.tscn` | Crate cycling / offered / Herr Tamtam + chalk wall-buys → `user://shots/crate_*.png` (`--out=<dir>`): the row (closed, cycling, Herr Tamtam, an empty spot with its cold lantern), the offer, and close-ups. |
| `smoke_bots.tscn` | Headless AI-teammates test (T-031): Map 0 with 3 bots; checks setup and scaling, that the bots fight through 3 rounds, buy a wall gun and open a door with their own Scrip (each gets 1200 at round 2), revive a bot and the human, the human's bleed-out / spectate / respawn, and game over when everyone is down. `-- --rounds=N --skill=veteran`. |
| `shots_bots.tscn` | Windowed screenshots of the bots fighting beside the player (a free camera and the human's eyes) → `user://shots/bots_*.png` (`--out=<dir>`). |
| `model_shots.tscn` | Close-ups of one WeaponModels model from six angles (over the sights, both sides, top, rear quarter, muzzle) → `<out>/model_<id>_<view>.png`. `--id=m1911 [--up] [--lit] [--out=<dir>]`. |
| `shots_crate_map.tscn` | The Requisition Crate in context on Map 0 (each spot closed, the Hearth spot cycling, an emptied spot) → `<out>/cm_NN_<name>.png`. |
| `shots_machines.tscn` | Every restyled interactable in a dim studio, unpowered then powered → `<out>/mach_<name>_<off\|on>.png`, the nine perk machines alone and in a row, Overclock's crown and gauge close-ups, and its static burst (`mach_overclock_burst.png`). `-- --out=<dir> [--only=perk,crucible]`. |
| `smoke_story_props.tscn` | Headless QA for the Map 0 fixed story items (LORE.md §13.1, `data/gravelight/story_props.json`): the six StoryProps spawn, none is in the random intel pool, each sits on its surface / wall (raycasts), the real Player reads the guest book through simulated input, and reading files each item in the Archive once. |
| `shots_story_props.tscn` | A close-up and a room view of every story item (power on) → `<out>/story_NN_<id>_<close\|room>.png`. No Player input, the mouse is never captured. `-- --out=<dir>`. |
| `extract_vo.py` | Regenerates `data/gravelight/vo/lines.json` from `docs/gravelight/VO_SCRIPT.md` and `CHARACTERS.md` (tables, `- \`ID\`: "..."` bullets, `**BNT_*_NN**` exchanges, §5 `gl.all.*.perk_*` rows) and keeps `rules.json` complete. Merge semantics: doc ids win, ids that only exist in lines.json (the `op.slip.*` slips, lines other passes added directly) are kept, existing rule keys are never overwritten. `python gravelight/tools_src/extract_vo.py`. |
| `gen_vo.py` (+ `gen_vo_tts.ps1`) | Bakes voice audio for every line (T-035): Windows OneCore TTS (David / Mark / Zira, **file output only, never the speakers**) with per-speaker SSML prosody, then numpy/scipy post-processing (pitch/formant "size" shift, EQ, tannoy / corporate / radio / PA / phonograph / dry-squad channels, `[static]`-style cues), ffmpeg → `audio/vo/<speaker>/<id>.ogg` (`.wav` fallback; exchange parts are `<id>_p<n>` under the part's speaker). Incremental by text+profile hash in `data/gravelight/vo/audio_manifest.json`. `python gravelight/tools_src/gen_vo.py [--only=OPR | --only=BNT_DUT] [--force] [--dry-run]`, then reimport (`godot --headless --editor --quit-after 300 --path .`). |
| `smoke_vo.tscn` | Headless VO smoke (T-035): Map 0 with 3 bots, chance rolls forced, rounds 1-3; logs every category each speaker fired, asserts the Operator's match/round announcements, the squad's SPAWN / ROUND_START / ROUND_END / DOOR / BUY / HEADSHOT / DOWN / TEAM_DOWN / REVIVE / REVIVED and a banter exchange, and that audio streams started (2D and positional) on the Dummy driver. `godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_vo.tscn`. |
| `smoke_campaign.tscn` | Headless campaign-chain test (T-033): solo + 3 bots on Map 0, loot handed out, round 10 → the exfil beacon lights (stable doors open free) → vote → fast-forwarded cutscene → Map 1 at round 11 with every player's weapons / ammo / upgraded state / Scrip / perks / grenades verified, bots alive and following; round 30 missed (retry at 33) → vote → the "campaign continues" screen while Map 2's scene is missing (or Map 2 at round 31 once it exists). |
| `shots_campaign.tscn` | Silent off-screen frames of the campaign exfil → `<out>/campaign_NN_<name>.png`: the lit beacon with the squad, the HUD prompt, and three cutscene frames (the great doors, dawn at the crossroads, the KALTENBRUNN title card). `-- --out=<dir>`. |
| `extract_intel.py` | Regenerates `data/gravelight/intel.json` (LORE.md §13; §13.1 and §13.2 rows get `"placement": "fixed"`, `<br>` becomes a newline) and `dossiers.json` (CHARACTERS.md). `python gravelight/tools_src/extract_intel.py`. |
| `gen_map02.gd` | Generates `maps/map02_totenhafen/map02.tscn` (T-036): the Totenhafen U-boat pen from MAPS.md Map 2: shell, per-zone navmesh, art dressing, the tide water plane, every gameplay node. `godot --headless --path . --script res://gravelight/tools_src/gen_map02.gd`. |
| `smoke_map02.tscn` | Headless Map 2 smoke: per-zone navigation and door gating, spawn points on the mesh and the map02.json counts, 6 perks / 5 crates / 4 story items, the Pumpenschalter, the powered Signal Tower door, the Crucible in the boat, both traps, the tide (rise, spawn switch, wading, fall), then rounds 31-34 with 3 bots. `--audio-driver Dummy`. |
| `perf_map02.tscn` | Windowed perf on Map 2: power on, 24 zombies in six areas (one at high tide) → FPS per area and `<out>/map02_<area>.png`. |
| `shots_map02.tscn` | Windowed screenshots of every Map 2 zone, power off then on (one at high tide) → `<out>/m2_NN_<name>_<off\|on>.png` (`--out=<dir> --only=a,b`). |

Run windowed render tools silently and off-screen: `--audio-driver Dummy --position -4000,-4000 --resolution 1280x720`.
