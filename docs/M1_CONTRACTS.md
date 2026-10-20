# M1 contracts (Bolt vertical slice)

Read this before writing M1 code. It covers what exists, the interfaces between parts, and who owns which files. If a contract is missing something you need, add it in your own files and say so in your report; never edit another builder's files.

## Hard rules
- Godot 4.7.2. GDScript with static typing everywhere. Tabs for indentation.
- **Silence:** never launch anything that opens a window, and never play audio. The user is playing a fullscreen game on this PC. Every Godot run is `--headless`.
- **Godot binary:** `tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe`.
- **Commands:**
  - Compile check: `--headless --path . --script res://tools_src/check_scripts.gd`
  - Tests: `./run_tests.sh` (GUT, headless)
  - After adding a `class_name`: rebuild the cache with `--headless --editor --quit-after 300 --path .`
- **Data:** every tuning number lives in data JSON under `data/bs/` (seeded from the original's tables in `data/bs_source/`, with source line numbers noted). Logic reads them through `Data.table("bs/<file>")`.
- **Text:** every player-facing line comes from `data/bs/story/*.json` by line ID (`VOManager.play(id)` shows the subtitle and speaks it). New lines go in your own data file with `bs.*` IDs and are listed in your report.
- **Parity:** original behaviour from `reference/bs_web/index.html` (read targeted chunks only, by grepping function names) is the baseline. The redesign docs (`docs/BS_WEAPONS.md`, `docs/BS_ENEMIES.md`, `docs/BS_LEVELS.md`) say what changes.
- **Originality:** nothing from commercial games.
- **No git:** the lead commits.

## What exists (don't rewrite; extend through your own files)

| Path | What |
|---|---|
| `core/game.gd` (Game) | `GAME_TITLE`, `Game.hitstop(t)`, `Game.slowmo(t)`, `Game.wheel_open` (world time ×0.15 while true) |
| `core/event_bus.gd` (EventBus) | Signals: bolts_changed, gold_bolt_found, memo_found, player_damaged, player_died, enemy_hit, enemy_killed, combo_changed, weapon_changed, weapon_leveled, super_meter_changed, boss_started, boss_health, boss_defeated, story_beat, quest_progress, quest_done, interact_prompt, hint, banner, bark, subtitle, vo_line_started/finished, unlock_granted |
| `core/data.gd` (Data) | `Data.table("bs/tuning")`, … |
| `core/settings.gd` (Settings) | `Settings.get_value(key, fallback)`; keys in `data/settings_defaults.json` |
| `core/save_profile.gd` (SaveProfile) | One profile; B&S state under `doc["bs"]` |
| `core/vo_manager.gd` (VOManager) | `play(line_id)` emits `EventBus.subtitle` and speaks it (silent headless); `line(id)`, `has_line(id)` |
| `core/aim_assist.gd` (AimAssist) | `player`, `enabled_mode`, `narrow`, `update(view_dir)`, `pick_target(dir, cone, range, for_melee)`, `bend(dir, from)`, `friction()` |
| `core/combat.gd` (Combat) | `Combat.Hit` (amount, type, source, weapon_id, point, dir, knock, launch, is_melee, is_slam, weak_point, status) and `Combat.in_radius(tree, center, r, group)` |
| `core/status_effects.gd` (StatusEffects) | Child node named "Status" with `apply(id, s)`, `has(id)`, `clear(id)`, `time_left(id)` |
| `core/input_setup.gd` + `data/input_defaults.json` | Actions: move_*, look_*, jump, melee, dash, crouch, sprint, walk, fire, aim, interact, weapon_prev/next, weapon_wheel, weapon_1..8, super_sprocket, gadget, pause, console, ui_advance |
| `bs/bs_state.gd` (BS) | bolts, max_hp, weapons dict, weapon_order, current_weapon, mallet_tier, flags, super_meter/super_owned, god_mode, `ui_block` (>0 blocks player input), `add_bolts`, `spend`, `give_weapon`, `owns`, `flag`/`set_flag`, `add_super`, `save_to_profile` |
| `bs/player/bolt.gd` (Bolt) | CharacterBody3D, group "player". `motor: BoltMotor`, `camera: BoltCamera`, `melee: BoltMelee`, `hp`/`max_hp`, `take_damage(hit)`, `heal`, `respawn_at`, `aim_origin()`, `aim_dir()`, `is_aiming()`, `get_center()`, `kill_y`, `water_zones: Array[AABB]`, `scripted` input, `input_enabled`. Collision layer 2, mask world (1) + solid props (6) |
| `bs/player/bolt_camera.gd` (BoltCamera) | `yaw`, `pitch`, `cam: Camera3D`, `view_dir()`, `shake(a)`, `punch_in(a)`, `add_recoil(rad)`, `snap_to(bolt)` |
| `bs/player/bolt_melee.gd` (BoltMelee) | Mallet: `combo_hit(n)`, `combo_hits`, `throw_active`, `throw_pos`. Signals `swung`, `hit_landed`, `thrown` |
| `bs/player/bolt_motor.gd` (BoltMotor) | Movement (parity-tested; don't change its rules). Signals: jumped(kind), dashed, slam_started, slam_landed, slide_started, landed |
| `bs/enemies/test_dummy.gd` (TestDummy) | Reference implementation of the damageable contract |

## Physics layers
| Layer | Bit | Used by |
|---|---|---|
| 1 | 1 | world (static geometry; the camera and LOS use it) |
| 2 | 2 | player |
| 3 | 4 | enemies (bodies) |
| 4 | 8 | enemy hitboxes / weak points (Area3D) |
| 5 | 16 | interactables / triggers |
| 6 | 32 | solid props (crates, breakables) |
| 7 | 64 | projectiles |
| 8 | 128 | pickups |

## Damageable contract
In groups "damageable" and "enemies" (props add "props"; bosses add "bosses"). It implements:
- `take_damage(hit: Combat.Hit) -> bool` (true = killed)
- `get_center() -> Vector3`
- `is_alive() -> bool`
- a `radius: float` property
- a "Status" child (StatusEffects)

On death it emits `EventBus.enemy_killed(self, hit.weapon_id)` and drops bolts as pickups (`bs/world/pickup.gd`, group "pickups", `collect(bolt)`).

## The level runner (owned by the UI/systems builder)
`bs/bs_level.gd` (class `BSLevel`, extends Node3D) is the base of every B&S planet scene. Its `_ready`:
1. builds the geometry (a subclass override, `build()`)
2. spawns Bolt at `spawn_point`, the BoltCamera, Sprocket, the HUD and the dev console
3. sets `AimAssist.player` / `enabled_mode`
4. sets `Bolt.kill_y` and `water_zones`
5. calls `on_level_ready()`

Planet scripts (the level builder) extend BSLevel. Enemies are spawned by the level through `EnemySpawner.spawn(id: StringName, pos: Vector3) -> Node3D` (owned by the enemy builder).

## File ownership
| Builder | Owns |
|---|---|
| Lead (done) | `core/*`, `bs/player/*`, `bs/bs_state.gd`, `data/bs/tuning.json`, `data/input_defaults.json`, `tests/unit/test_core.gd`, `test_bolt_parity.gd`, `test_bolt_course.gd` |
| **Weapons** | `bs/weapons/**`, `data/bs/weapons.json`, `ui/bs/weapon_wheel*`, `ui/bs/reticle*`, `tests/unit/test_bs_weapons*.gd` |
| **Enemies** | `bs/enemies/**` (not test_dummy.gd), `bs/bosses/**`, `data/bs/enemies.json`, `data/bs/bosses.json`, `data/bs/statuses.json`, `bs/world/pickup.gd`, `tests/unit/test_bs_enemies*.gd` |
| **Level** | `bs/planets/**`, `bs/world/**` (except pickup.gd), `data/bs/levels/**`, `tests/unit/test_bs_level*.gd`, `tools_src/smoke_scrapheap.*` |
| **UI / systems** | `bs/bs_level.gd`, `bs/sprocket/**`, `bs/shop/**`, `bs/cutscene/**`, `ui/bs/**` (except the weapons-owned files), `ui/main_menu.*`, `core/dev_console.gd`, `data/bs/shop.json`, `tests/unit/test_bs_ui*.gd` |
