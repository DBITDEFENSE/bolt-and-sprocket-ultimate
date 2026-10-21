# M3 contracts: the full Bolt & Sprocket arsenal, plus Acts 1–2

Read this and `docs/M1_CONTRACTS.md` (its rules, the existing systems and the damageable contract all still apply) before writing M3 code.

**M3 scope** (brief section 13):
- all 16 weapons with V1–V5 levels, mods and Signature Mods
- Rustvane Canyon complete: the Rustvane Sentinel, The Content Creator, the GLAMBOT defection, the Tether-Hook
- the shield reveal
- Nova Plaza complete: The Algorithm
- the Omega Forge, built and testable from the dev console (in the story it unlocks in M4)

## Hard rules (unchanged from M1, plus two)
- Godot 4.7.2 (`tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe`), static-typed GDScript, tabs.
- **Silence:**
  - Never play audio. Never capture the mouse. Never launch the game normally.
  - Headless runs: `--headless`.
  - Rendered screenshot runs: `--audio-driver Dummy --position -4000,-4000`, windowed, with every audio bus muted in the tool.
  - The user works and takes meetings on this PC.
- **Data and text:**
  - Every tuning number lives in `data/bs/...` JSON.
  - Every player-facing line comes from `data/bs/story/*.json` by ID. New lines go in your own data file, with `bs.*` IDs.
  - Original text is canon. If you change or cut a line, log it in your report so the lead can add it to `docs/STORY_CHANGES.md`. Never drop a joke silently.
- **Parity:** the original (`reference/bs_web/index.html`) is the baseline. Grep for function names and read only targeted chunks; never read the whole file. `docs/BS_WEAPONS.md`, `BS_ENEMIES.md`, `BS_LEVELS.md` and `BS_PORT_INVENTORY.md` say what changes.
- **Originality:** nothing from commercial games. Assets must be original or CC0, listed in your report for `docs/ASSETS.md`. Prefer procedural or greybox art like M1's.
- **No git.** The lead commits.
- **Stay in your lane.** Never edit another builder's files. If you need a hook from someone else's file, put a small adapter in your own files and say so in your report. The lead integrates.
- **Before reporting done:**
  - compile check passes (`--headless --path . --script res://tools_src/check_scripts.gd`)
  - `./run_tests.sh` is green
  - your smoke tool passes
  - after adding a `class_name`, rebuild the class cache (`--headless --editor --quit-after 300 --path .`)

## What already exists (beyond M1_CONTRACTS)
- **Weapons:**
  - `WeaponManager.attach_to(bolt)` and the archetype framework, in `bs/weapons/`
  - 4 finished guns: omni_blaster, void_ripper, sprocket_zap, boom_box. The other 12 are archetype placeholders.
  - `data/bs/weapons.json`: 16 guns, progression, mods, lines
  - weapon wheel and reticle
- **Enemies:** `EnemyBase`, `EnemySpawner.spawn(id, pos, parent, opts)`, scrap_mutt, tinker_turret, vulture_drone, lien_crawler, bolt_crate; `BossBase`, REPO-TRON + CraneHook; `data/bs/enemies.json`, `bosses.json` (lines under "lines"), `statuses.json`.
- **Levels:**
  - `BSLevel` (`bs/bs_level.gd`) is the base of every planet.
  - `LevelDirector` and the world objects live in `bs/world/`.
  - Scrapheap Junction is fully data-driven from `data/bs/levels/scrapheap.json` (zones, probes, quests, encounters, collectibles, beats, boss) plus `scrapheap_lines.json`.
  - `tools_src/smoke_scrapheap.gd` is the model for a planet smoke test.
- **Systems:** Sprocket and Super Protocol (`bs/sprocket/`), cutscene player, shop v2, HUD, pause and settings, dev console (`core/dev_console.gd`).
- **VO:** `VOManager.LINE_SOURCES` voices `data/bs/story/lines_index`, `bs/ui_lines`, `bs/bosses` ("lines"), `bs/weapons` ("lines") and `bs/levels/scrapheap_lines` ("lines"). New line files are added there by the lead, so name yours in your report.

## Builders and file ownership

| Builder | Owns (create or edit only these) |
|---|---|
| **A: Arsenal and Forge** | `bs/weapons/**`, `data/bs/weapons.json`, `ui/bs/weapon_wheel*`, `ui/bs/reticle*`, **new** `bs/forge/**`, `data/bs/forge.json`, `ui/bs/forge*`, `tests/unit/test_bs_weapons*.gd`, `tests/unit/test_bs_forge*.gd`, `tools_src/smoke_arsenal.*` |
| **B: Rustvane Canyon** | `bs/planets/rustvane/**`, `data/bs/levels/rustvane*.json`, **new** `bs/world/rustvane/**`, **new** `bs/gadgets/**` (the Tether-Hook and the gadget framework), `data/bs/gadgets.json`, `tests/unit/test_bs_rustvane*.gd`, `tools_src/smoke_rustvane.*` |
| **C: Nova Plaza** | `bs/planets/nova_plaza/**`, `data/bs/levels/nova_plaza*.json`, **new** `bs/world/nova/**`, `tests/unit/test_bs_nova*.gd`, `tools_src/smoke_nova.*` |
| **D: Enemies and Bosses** | `bs/enemies/**` (not test_dummy.gd), `bs/bosses/**`, `data/bs/enemies.json`, `data/bs/bosses.json`, `data/bs/statuses.json`, `tests/unit/test_bs_enemies*.gd`, `tests/unit/test_bs_bosses*.gd`, `tools_src/smoke_bosses.*` |
| **Lead** | everything else: `bs/bs_level.gd`, `bs/world/*.gd` (the shared M1 objects), `bs/sprocket/**`, `bs/shop/**`, `bs/cutscene/**`, `ui/**` (except A's files), `core/**`, the hub, travel between planets, VO line sources, docs |

## Interfaces between builders
- **Planets (B, C) spawn enemies only through `EnemySpawner.spawn(id, pos, parent, opts)`.**
  - Enemy and boss IDs come from `docs/BS_ENEMIES.md`, Rustvane and Nova sections; use those exact IDs.
  - Until D lands an enemy, the spawner returns null for unknown IDs. Your level must tolerate that, and your smoke test may stub the enemy with `TestDummy`.
  - Boss arenas: B and C build the arena geometry and call `BossBase` subclasses through `EnemySpawner.spawn(&"<boss_id>", pos, parent, {"arena": <Node3D>})`. Write down the arena contract (center, size, anchor nodes) in a comment block at the top of your arena builder; D reads it.
- **Bosses (D)** extend `BossBase` the way `RepoTron` does. A boss needing arena props takes them from `opts["arena"]` children by name, documented at the top of the boss script. Bosses:
  - `rustvane_sentinel`
  - `content_creator` (the Sunset Stage, after the Sentinel; see BS_LEVELS section 3.10)
  - `the_algorithm` (Nova Plaza)
- **Story beats** (the GLAMBOT defection and the shield reveal) belong to the planet that contains them (B). Use `EventBus.story_beat` and the cutscene player (`level.cutscenes.play(id)`). Cutscene scripts are data: put them in your levels JSON under `cutscenes`. If the cutscene player lacks a feature, use what exists and list the gap in your report.
- **The Tether-Hook (B)** is the first gadget, so B also writes the small gadget framework in `bs/gadgets/`:
  - `Gadget` base class
  - `GadgetManager.attach_to(bolt)`
  - BS state `BS.flags["gadget.<id>"]` marks ownership
  - input action `gadget`
  - grapple points: group `"tether_points"` (Area3D or Marker3D)

  Nova Plaza and later planets reuse it.
- **Weapons and the Forge (A):**
  - **Progression:** V1–V5 per weapon from XP (original rules plus `docs/BS_WEAPONS.md`), mods, Signature Mods at V5.
  - **Omega Forge:** a station node (`bs/forge/omega_forge.gd`) and a UI. A level places it with `OmegaForge.new()`. In the story it unlocks in M4.
  - **Dev console:** expose static helpers `ForgeDebug.give_all()`, `ForgeDebug.set_level(id, lvl)` and `ForgeDebug.open_forge()`. The lead wires the console commands.
  - **Shop:** the shop sells your weapons via `data/bs/shop.json` (lead-owned). Name every weapon's shop entry in your report.
  - **Super Sprocket damage multiplier:** apply `Sprocket.damage_mult_for(weapon_id)` (already exists) inside your damage path. This was an M1 gap.

## Reporting
When done, report:
- what you built and how to test it (commands)
- your smoke-test result line
- new data files and line files (for `LINE_SOURCES`)
- new `bs.*` lines
- assets, for ASSETS.md
- story changes, for STORY_CHANGES.md
- integration needs (hooks in lead-owned files)
- known gaps
