# UPDATE 09 contracts (the lead's interface spec between the parallel sections)

Work order: `docs/work_orders/UPDATE_09.md`. Every worker reads this before touching code. If a contract here can't
be met, the worker logs why in its report and keeps the names below so the other sections still link up.

Naming rule for the whole update: the Darkmatter chip under the skin is the **Marke** (plural Marken; player-facing
"the mark"). In code, data, signals and tests it is always `marke`, never `mark`: `mark` already means the
pause-map pings and bot orders (`docs/gravelight/MARKS.md`, `bot_mark_orders.gd`, `mark_ping.gd`).

## C1. The Marke (§1 owns it; §3, §4, §7 use it)

**Canon in one paragraph (binding for every writer).** Nachtglas is Darkmatter's DARK-GLASS™ retention substrate
(CANON §2). Raw substrate retains whatever dies near it (the 1938 Pilch retention, the Erwachen of 20 December 1944
in the mine). From 1942 Projekt Wiederkehr (Abteilung III, Venner) cut the substrate into chips the size of a grain of
rice, the **Marken**, implanted under the skin of the right hand (between thumb and forefinger) or the forehead
(above the right brow), and sold to soldiers, guards, staff and volunteers as a loyalty and identity tag:
"die Marke, die dich hält" (the mark that keeps you): pay, rations and Scrip tallied against it; the Ledger counts the
marked. Vendelin's cabinets read it; the Operator calls a marked person "a valued customer". It is Darkmatter's
subscription token in the flesh. A marked person who dies does not stay dead: the Marke keeps the body running on its
last impulse, which is hunger: "NOBODY CANCELS". The marks stay active only while the relay signal reaches them: the
Ledger's carrier on Earth, Darkmatter's Regional Retention Relay RR-7 on the Moon above it. That is why cutting the
relay in the Fernflug finale stops the dead (MAP4_FERNFLUG §6 already says the hum stops and the first retained
miner's hand stops; the Marken go dark the same second). Unmarked people who die near raw substrate can still rise
(the mine's Erwachen, the sealed galleries); far from the mine, everything that rises was marked. Deacon, a preacher's
son, names it ("the mark in the right hand or in the forehead"). Peg's sealed orders say "retrieve the tokens"; Wren
keeps finding them on the dead; Jakub refused the mark (the labourers were never offered it, and the few who were,
refused; that is why he is alive and was never one of them). **Respect rule:** the Marke is never a camp tattoo or a
number; it is a violet glint under the skin, offered, never forced on the labourers; forced labourers were not marked.

**Gameplay hook (host-authoritative, data in `data/gravelight/enemies.json` key `marke`):**
```json
"marke": {"damage_mult": 1.5, "scrip_bonus": 25, "hand_chance": 0.6, "hitbox_m": 0.07,
          "glow_min": 0.25, "glow_max": 1.0, "_doc": "..."}
```
- Each zombie picks `marke_site` (`&"hand"` or `&"forehead"`) when it spawns, from its `net_id` (deterministic so
  puppets match the host). Bosses and Darkmatter constructs (Backorder) have no Marke; Suited keep it on the hand.
- `ZombieBody` adds a hitbox named `"marke"`, limb `&"marke"`, a `hitbox_m` cube on bone `RightHand` (hand) or on the
  front of `Head` (forehead), plus a small emissive violet mesh / decal at the same spot driven by the infection
  shader's pulse (`glow_min..glow_max` with the map hum, brighter with `gl_round_k`).
- `Zombie.take_damage(amount, &"marke", ...)`: sets `_marke_hit = true`, multiplies `amount` by `damage_mult`, and then
  continues as a hit on the host limb (`&"arms"` for the hand, `&"head"` for the forehead) for armour, wounds, death
  clips and the headshot path. A kill with `_marke_hit` emits `GLBus.marke_kill(by_player: int, enemy_id: int)` right
  after the normal kill reward and pays `scrip_bonus` through `Economy.award` (so Double Scrip and §3's earn
  multiplier apply). `GameState.stats[&"marke_kills"]` counts them. The hitmarker gets a violet tint on a Marke hit.
- Classic Rules keeps the weak point (it is part of the zombie) but pays no Marke bonus.
- Unit tests: `gravelight/tests/unit/test_marke.gd` (site pick is deterministic; damage mult; bonus paid once;
  Classic Rules pays none). `smoke_marks` is unrelated and must keep passing.

## C2. GAME_MODE_NAME (§6 owns it; every UI uses it)
- `core/game.gd`: `const GAME_MODE_NAME: String = "CLAUDE ZOMBIES"` and `const GAME_MODE_NAME_TITLE: String =
  "Claude Zombies"` (sentence case for prose). `Game.GAME_TITLE` (TERMS & CONDITIONS) stays the umbrella title.
- Every player-facing string that said GRAVELIGHT / Gravelight for the game mode goes through those two constants
  (menus, hub door, mode select, loading, lobby, HUD, credits, Archive, achievements, trophies, window title, web
  page title, build file names). "Operation Gravelight" inside the story stays. Code folders, class names, autoload
  names (`GLSettings`, `GLBus`...), save keys and data file names do not change.
- Wordmark: `gravelight/ui/wordmark/claude_zombies.svg` (original lettering) and
  `gravelight/ui/wordmark/claude_zombies.png` (2048 wide, transparent), plus `MenuKit.wordmark(height_px) -> Control`.
- The web page title and `vercel.json` site title read "CLAUDE ZOMBIES"; the Windows zip is `ClaudeZombies_<ver>.zip`.

## C3. Net transport + lobbies (§2a/2b own it; §7 restyles the lobby screens on this API)
- `Net` keeps every existing function and RPC. New:
  - `enum Transport {ENET, WEBRTC}`; `Net.transport`.
  - `Net.host_online(lobby: Dictionary) -> Error` and `Net.join_online(lobby: Dictionary) -> Error`: WebRTC through a
    `NetSignaling` (abstract, `gravelight/net/signaling.gd`): `SupabaseSignaling` (Realtime broadcast channel per lobby
    for offer / answer / ICE) and `MockSignaling` (a tiny local WebSocket relay, `gravelight/net/mock_signal_server.gd`,
    started by the smoke, so two headless desktop instances connect without Supabase).
  - `host_game` / `join_game` (ENet, direct IP) stay for LAN and dev.
  - Reconnect: a client keeps a `session_token`; a peer that comes back within `rejoin_grace_s` (60) gets its old pid
    and its player back; a dropped pid's slot becomes a bot when the lobby's `fill_bots` is on.
  - Host leaving ends the match for everyone with the message "The host left the match." (no host migration).
- `LobbyService` (`gravelight/net/lobby_service.gd`, an autoload `Lobbies`): `create(map_id: String, is_public: bool,
  display_name: String) -> String` (the 6-letter join code), `list() -> Array[Dictionary]`, `join(code: String)`,
  `quick_match(map_id := "")`, `heartbeat()` (every `lobby_heartbeat_s`), `set_ready`, `set_character`, `leave()`,
  `start()` (host). Signals: `lobbies_changed(list)`, `joined(lobby)`, `left(reason)`, `failed(reason)`,
  `match_starting(scene, seed)`. A lobby row: `{code, map_id, is_public, host_name, players: [{name, character, ready,
  pid}], fill_bots, created_at, heartbeat_at}`.
- Config `data/gravelight/online.json` (anon key only; it is public by design):
  `supabase_url`, `supabase_anon_key`, `supabase_publishable_key`, `stun` (list of urls), `turn` ({urls, username,
  credential}; empty = off), `lobby_heartbeat_s` 20, `lobby_expire_s` 120, `join_code_len` 6, `rejoin_grace_s` 60,
  `connect_timeout_s` 15, `max_players` 4.
- Supabase: `supabase/migrations/0001_lobbies.sql`: table `lobbies` (code pk, map_id, is_public, host_name, players
  jsonb, fill_bots, status, created_at, heartbeat_at, host_token), RLS on, policies: anyone may select public lobbies
  or a lobby by exact code, anyone may insert (rate-limited by a trigger: max 5 rows per minute per host_token, and
  at most 1 open lobby per host_token), updates only with the matching `host_token` (passed via an RPC function
  `lobby_update(code, host_token, patch)` so the token is never readable), a `pg_cron` or an RPC `lobby_sweep()` that
  deletes rows whose heartbeat is older than `lobby_expire_s`. Signaling is Realtime **broadcast** on channel
  `lobby:<code>` (no table, no persistence). No service-role key anywhere in the repo.
- Host-only systems that must work online: companions (Jakub, MapCompanion: puppets on clients, Talk cards through
  `Net.mirror`), the Bell Dome's effects, the bank (counter open online: the host's balance for the host; a client's
  balance is its own profile, synced through an RPC pair `_rpc_bank_req` / `_rpc_bank_state`).

## C4. The web build and the graphics profiles (§2c/2d own it; §5 and §7 must fit inside it)
- `GLSettings.is_web() -> bool` (`OS.has_feature("web")`), `GLSettings.is_compat() -> bool` (the Compatibility
  renderer). A preset `"web"` joins `PRESETS` (T-133), applied automatically on the web; `GLSettings.auto_detect_preset()`
  runs on first launch (no saved preset) from `RenderingServer.get_video_adapter_name()` + the renderer and picks
  low / medium / high.
- `WebProfile` (`gravelight/world/web_profile.gd`): `apply(map_root)`: no SDFGI / SSIL / SSR / volumetric fog
  (depth fog instead), shadow distance capped (40 m), MSAA off, at most 4 shadowed lights per zone, zombie animation
  LOD distances halved, particle amounts halved, texture import caps (1024 on web).
- Export presets live in `export_presets.cfg` (committed): "Windows Desktop" and "Web" (Compatibility, single-threaded
  `web_nothreads` so no COOP/COEP is needed; threads only if measured to matter). `tools/build_web.sh` exports to
  `build/web/`, splits the maps into `build/web/packs/map00.pck ... map04d.pck`, writes `vercel.json`, and prints the
  sizes. `MapPacks.ensure(map_id)` (autoload) fetches + mounts a pack on demand (desktop: no-op). Target < 150 MB to
  the menu.
- Budgets every map zone must respect (the §5 builders measure them with `perf_map*.tscn` / `--breakdown`): ≤ 2500
  draw calls in view, ≤ 6 shadowed lights per zone, ≤ 400k triangles in view on desktop and ≤ 200k on web.

## C5. Relief squads (§4 owns it)
- Data `data/gravelight/squads.json`: global `{from_round 4, chance_per_round 0.35, max_active 1, cooldown_rounds 3,
  size [3, 6], stay_seconds [60, 150], survivor_chance 0.25, scrip_share 0.25}` and per map a list of factions with
  `{id, display, kit, weapons, barks_prefix, edge_spawns}`.
- `ReliefSquad` (`gravelight/world/relief_squad.gd`) spawns `Soldier` actors (`gravelight/bots/soldier.gd`, a
  CharacterBody3D with a PeopleBodies kit and `SoldierBrain`: follow the squad leader, hold near the players, shoot,
  retreat when hurt, no economy, no eggs). Their kills pay the nearest player `scrip_share` of the kill value through
  `Economy.award`. A soldier that dies becomes a zombie through `ZombieDirector.rise_at(position, kit)` (the Marke at
  work: Deacon/Wren bark on the first one). Soldiers count against `rounds.json max_active` through
  `ZombieDirector.actor_budget` and the director spawns `-1` zombie per living soldier so rounds stay as hard.
- Never while `GameState.has_flag(&"boss_fight")`, `&"holdout"` or `&"cutscene"` (the worker wires these flags where
  bosses, holdouts and cutscenes start and end if they don't exist yet). Signals: `GLBus.squad_arrived(squad_id,
  faction)`, `squad_lost(squad_id)`, `squad_survivor(squad_id, soldier)`. Loot: an ammo crate, a dropped weapon
  (`WeaponParcel`), grenades.
- Barks: line ids `SQD_<FACTION>_<CAT>_NN` in `data/gravelight/vo/lines.json`, speaker `SQD`, placeholder TTS.

## C6. The bank on every map + Ledger Lager (§3 owns it)
- `bank.json` gains branches `map02`, `map04a`, `map04b`, `map04c`, `map04d` and a `tellers` table keyed by map
  (`{id, speaker, display, name}`; Lassmann stays on map00 and map01). Each branch is a `BankBranch` placed by the map
  generator (`gen_map02.gd`, `gen_map04*.gd`) with its sign, counter, safe and teller, a minimap POI `bank`, VO
  categories `BANK_GREET_<MAP>`, and `bot_economy.gd` knows a branch exists on the map.
- Perk id `ledger_lager` (perks.json, perk_lore.json, machine_lore.json per map, JINGLES.md, VO
  `PERK_FIRST_LEDGER_<CHAR>`). Effect keys: `scrip_earn_mult` 1.2 (tier I), `bank_interest_bonus` 0.02 (II),
  `purchase_discount` 0.10 and `marke_tip` (III), `golden_parachute_pct` 0.05 + `golden_parachute_cap` + 
  `no_scrip_loss_on_down` (IV, permanent). `Economy.award` and `Economy.grant` apply `scrip_earn_mult` for that player;
  `Economy.bank_move` never does; refunds (`Economy.refund` if one exists, else the crate's return path) never do.
  `BankLedger` adds `bank_interest_bonus` to the base rate for players holding tier II. `Economy.spend` applies
  `purchase_discount` (rounded down) and emits the discounted cost. `marke_tip` pays through the C1 bonus path.
- Machine placement on every map through the maps' perk tables (`map0X.json` perks), shape `keg`, colour amber-violet.

## C7. Menus (§7 owns it; §2b's lobby screens get restyled, not rewritten)
- The 3D menu scene is `gravelight/ui/menu_scene.gd` (`MenuScene`, replaces `MenuBackdrop`'s content; the class name
  `MenuBackdrop` may stay as a thin wrapper). It is built from real assets: the inn exterior from `gen_map00`'s pieces
  (exported once to `gravelight/ui/menu_inn.tscn` by a generator step, not the whole map), `ZombieBody` kits for the
  zombies, `PeopleBodies` for the squad. Budget: ≤ 1200 draw calls, loads in < 3 s on desktop; a `web` variant (fewer
  zombies, no volumetrics, no shadowed omnis).
- Progress hooks: `ProfileSave` flags `fernflug_beaten` (the violet light on the Moon).
- Screens: `MainMenu` → Play (Solo / Online / Campaign), Muster, Archive, Extras (Dossiers, Service Record,
  Challenges, Credits, Test Range), Settings, Quit. Online opens `menu_lobby.gd` (C3).

## C8. Captures without a window on the owner's screen
Rendered runs on the owner's PC pop up on screen (memory + CLAUDE.md). The only allowed rendered path in this update
is **WSL + Xvfb with the Linux Godot in software GL**: `tools/wsl_capture.sh <milestone> [only]` wraps
`wsl.exe -e bash -lc 'cd /mnt/c/... && xvfb-run -a -s "-screen 0 1920x1080x24" tools/dl_godot/Godot_v4.7.2-stable_linux.x86_64
--rendering-driver opengl3 --audio-driver Dummy ...'`. Slow (software rendering) but invisible. Never run the Windows
binary with a window.

## C9. Branch and merge rules
One branch per task, named `u09-<section>-<slug>` (e.g. `u09-2a-webrtc`), from `master`. Rebase on master before
reporting done. A worker's report lists: files, tests added, the exact commands it ran and their last lines, what is
not done. The lead merges after re-running the unit suite and the touched smokes.
