# UPDATE 10 contracts (the lead's interface spec between the parallel sections)

Work order: `docs/work_orders/UPDATE_10.md`. Every worker reads this first. UPDATE 09's contracts (`docs/U09_CONTRACTS.md`)
still hold: the Marke (`marke`, never `mark`), GAME_MODE_NAME, the Net/Lobbies API, WebProfile and the budgets (≤ 2500
draw calls, ≤ 400k triangles in view, ≤ 6 shadowed lights per zone, `zone` meta on every light), ZoneAmbience, the
capture path (WSL + Xvfb only; never a rendered window on this PC), branch and merge rules (one branch per task,
`u10-<sec>-<slug>`, rebase on master, report files/tests/commands/undone).

Map names in code: map00 = Crossroads Inn (the owner's "Map 1"), map01 = Kaltenbrunn ("Map 2"), map02 = Totenhafen
("Map 3"), map04a–d = Fernflug ("Map 4"). Use the code ids in data and tests; the owner's numbering only in prose.

## C1. Two ambience systems, one file name convention
- **MapAmbience** (`gravelight/world/landscape/map_ambience.gd`, data `data/gravelight/map00_ambience.json`) is the
  *living world*: timed and reactive presentation events (bombers, fighters, a plane down, searchlights, artillery,
  flares, crows, the bell, the farm light...). Presentation only; it never touches gameplay. UPDATE 10 gives every map
  its own file with the same schema plus new event kinds: `data/gravelight/map01_ambience.json`,
  `map02_ambience.json`, `map04a_ambience.json` … `map04d_ambience.json`. MapRoot loads `<map_id>_ambience.json` when
  it exists (map04b–d use the act's id). New event kinds are added to `map_ambience.gd` as data-driven blocks that
  default to off when the key is absent, so Map 0 is unchanged: `gulls` (crows with a sea voice), `lighthouse`
  (a beam every N s, dark from `off_round`), `bell_tower` (a bell swinging in wind + one toll on a flag),
  `raid` (a bombing raid at `round`: sirens, flak, bomb walk, screen shake, dust bursts from a list of ceiling
  points, lamp sway impulse, a list of `collapse` nodes to trigger), `ships` (a burning freighter card, a destroyer
  searchlight, star shells), `low_pass` (a plane type at a round: Mosquitoes, a test jet, B-29s), `train`
  (arrival at a round with sparks), `windows_out` (lit windows going dark one by one from a round), `wildlife`
  (jackrabbits / coyotes that bolt), `tumbleweeds`, `heat_shimmer`, `milky_way`, `avalanche`, `cable_car`,
  `siren` (a round), `snow_harder` (a round), `dust_fall` (underground dust when the surface is shelled),
  `drips`, `chains` (swinging blocks/chains with a wind impulse), `icicles` (fall during a raid), `conveyor_jolt`
  (on power), `radio_chatter` (German U-boat traffic, subtitled, keys in lines.json), `meteors` (Act IV),
  `terminator` (Act IV, see C6), `earth_violet` (Act IV). The §2 living-world worker writes the Totenhafen kinds and
  the shared kinds; each Fernflug act worker adds only the kinds its act needs, in its own `_ev_<kind>` functions,
  appended at the end of `map_ambience.gd` under a clearly marked `# ---- U10 <act> ----` block (the lead merges;
  keep hunks separate).
- **ZoneAmbience** (U09, `data/gravelight/ambience/<map>.json`) stays the *audio beds* per zone. Don't move beds into
  the living-world file.

## C2. Totenhafen systems (§2; the systems worker owns these; the living-world worker and the bots worker consume them)
- **Tide v2** (`gravelight/maps/map02_totenhafen/tide_controller.gd`, data `map02.json "tide"`): stages
  `{"stages": [{"y": -3.3, "name": "half"}, {"y": -2.2, "name": "high"}, {"y": -1.0, "name": "spring"}]}`,
  `spring_every_rounds` 9 (the spring tide floods `spring_flood_boxes`: the north apron and the dock edges; the piers
  stay dry islands), `pump_crank` `{seconds: 30, spawn_mult: 2.0, shortens_by_s: 40}` (the Pumpenschalter's
  hold-to-crank holdout, usable while a flood is up and the power is on), `float_powerups` true (dropped power-ups in
  flooded boxes drift with `drift_mps` and are lost at the dock edge unless grabbed), `cables` (a list of positions
  with `radius_m` and `stun_s`: sparking cables in flooded water stun zombies and deal `player_dps` to players),
  `storm` `{spray_intensity_by_stage, lightning_interval_by_stage}`. Signals on `GLBus`: `tide_stage(stage: StringName)`,
  `tide_flood_begin`, `tide_flood_end`, `spring_tide(round: int)`. Flags: `GameState` flag `flooded` while any flood
  box is wet. The Kielholer spawn table keys off `flooded`.
- **Ballast v2** (`ballast_coffin.gd`, `ballast_hook.gd`, new `ballast_dump.gd` at the sea stairs): a carrier's
  WeaponHolder is limited to melee and the pistol slot (`WeaponHolder.set_carry_limit(true)`); bots carry through a
  new `carry` bot task (`bot_tasks.gd`). Two destinations: the crane hook (`ballast_loaded` counter; the Operator
  `OPR_BALLAST_LOAD_*`, +`economy.json ballast_load_bonus` Scrip) and the dump (`ballast_dumped` counter; the Operator
  `OPR_BALLAST_DUMP_*`; the next round gets `+1 glasshide` via `RoundManager.extra_spawn(&"glasshide", 1)`). Squad
  lines `DUT/PEG/DEA/WRN_BALLAST_LOAD_01`, `_DUMP_01`. The power needs `ballast_loaded ≥ 1`; the egg needs
  `ballast_dumped ≥ 3`. Coffins respawn on their pallets from a pool of `coffin_spots` so both are reachable.
- **Kielholer** (enemy ids `kielholer`, `kielholer_diver`; `enemies.json`): a grabber that rises at pier edges
  (`spawn_table` entries with `requires_flag: "flooded"` and a `surface` spawn kind at water points), grabs a player
  within 2 m and pulls toward the edge at 1.2 m/s (break free: melee, or 60 damage to the arm hitbox `arm_grab` from
  anyone); the diver variant has a helmet hitbox `helmet_glass` (break → a violet glow weak point ×2.0, after C1 of
  U09: it is a Marke in the helmet). Both use the ZombieBody rig with kits `drowned`, `drowned_diver`.
- **Searchlight** (`gravelight/world/map02/searchlight.gd`, a `Searchlight` interactable in the signal tower, needs
  power): a manned station (`PlayerStation` base: the player is locked to the station, weapons holstered, a Leave
  prompt); the beam (a SpotLight3D + a cone Area3D) slows zombies ×0.6 and marks them `+25% damage taken`
  (`Zombie.set_lit(true/false)`); bots man it through a pause-map mark order `MAN_SEARCHLIGHT` (`bot_mark_orders.gd`).
  During the finale the tower light tracks the boat automatically.
- **Crane Drop** trap (`traps.json crane_drop`, `gravelight/world/trap_crane.gd`): a lever in the crane office;
  the loading crane swings and drops a pallet of crates on the east apron (kill box 6 × 4 m, 60 s cooldown, dust and
  crash sfx, the pallet debris persists 20 s).
- **The boat** (`gravelight/world/map02/uboat_sail.gd`): the finale holdout on the deck + tower as a moving platform:
  the whole U-1047 group (hull, deck colliders, the navmesh region on the deck) translates along a spline out of the
  pen while the scenery scrolls (the pen mouth, the breakwater, the burning town cards); zombies board from
  `board_points` (water + pen walls) with the climb-link system; Kielholer drag at the hull (a periodic list
  shake + boarders); the searchlight tracks; after `sail_seconds` she dives: the exfil cutscene. Host-authoritative:
  the platform's offset is replicated as a single float (`_rpc_world` "sail_t"), everything else follows.
- **Diesels** (the egg's three holdouts): parts `inj_injector` (workshop lathe, a 30 s machining holdout during a
  flood), `inj_battery` (lower pens, a 30 s holdout with the lights out: `GameState.flag "lights_out"` while it runs),
  `inj_sequence` (the engine room, a 45 s holdout while Kielholer pull at the hull); then `curtain_open`, `sail`.
- **Economy**: `rounds.json` per-map overrides `map02: {spawn_interval_mult: 0.75, max_active_add: 4}` and two new quay
  spawn points; the soak before/after goes in T-15x and ECONOMY.md.

## C3. "Letzte Fahrt", the Totenhafen main egg (design in docs/U10_TOTENHAFEN_DESIGN.md; data
`data/gravelight/quests/map02_letzte_fahrt.json`, `docs/gravelight/EASTER_EGGS.md` §10)
Step ids (fixed; the bots worker writes `bot_task` for each unless marked player-only):
`s0_power` → parallel threads: `s1_ballast` (dump 3, load 1), `s2_cipher` (three radios' code groups, seeded; the
rotor machine in the signal tower), `s3_log` (the boat's log, four pages, two seeded spots each), `s4_parts`
(the Undertow's three parts, optional thread: the egg needs the Undertow for the boss) → `s5_diesels` (three
holdouts) → `s6_boss` (DER KIELHOLER rises from dock 2; drops the ignition key) → `s7_key` (turn the key in the
tower; the cliff bell tolls once) → `s8_curtain` (the pen curtain opens; flood the dock) → `s9_sail` (the moving
holdout, `sail_seconds` 150) → `s10_ending` (she dives; the cutscene; rewards). Player-only: none (every step has a
bot task; the cipher's rotor puzzle has a bot solver with a `think_seconds` delay). Rewards: the calling card
`CARD_LETZTE_FAHRT`, Archive entries `INT_M2_LOG_1..4`, `INT_M2_HALE_TELEGRAM`, the usual egg Scrip and a tier gift.
Quest flags the other sections read: `egg_lf_started` (the bell), `boat_key`, `curtain_open`, `sailing`, `dived`.

## C4. THE UNDERTOW (wonder weapon id `undertow`, upgrade `undertow_maelstrom`; `weapons.json`, `docs/gravelight/WEAPONS.md` §11)
A pressurised Nachtglas harpoon gun: a chained harpoon that skewers up to `pierce` 5 zombies in a line and reels
them in over `reel_s` 1.2 s (they arrive stunned at 2 m); fired into flooded water it opens a whirlpool
(`whirl_radius` 4 m, 6 s) that drags the dead under (instant kills on non-bosses, bosses take `whirl_dps`). MAELSTROM:
the whirlpool opens on land too (a violet vortex), harpoons chain to the next target within 6 m. Parts
`undertow_pump` (lower pens, 2 spots), `undertow_head` (workshop, 2 spots), `undertow_shard` (only from a dumped
coffin: the dump interaction leaves a shard pickup on the sea stairs after the third dump). Bench in the crane
office (`workbench.gd`, `recipe undertow`). First-pickup VO `DUT/PEG/DEA/WRN_WONDER_UNDERTOW_01`. The §2 systems worker
builds it; the Haiku/asset worker makes the model by Blender script if no CC0 harpoon gun fits.

## C5. Bosses (§4 and the Kielholer; `bosses/map01.json` for PAUL, `bosses/map02.json` for the Kielholer and the
Slender; all on `HomageBoss`)
- `der_kielholer`: data per C3; `bots_alone` scaling and a fail-safe (if not dead after `failsafe_seconds` 420 he
  dives and the key floats up at the dock edge).
- `paul` at Kaltenbrunn round 15 per `docs/HOMAGE_BOSSES.md` §5 (the likeness fields stay default; the code never
  prints a placeholder token like `%PAUL_LASTNAME%`: `HomageBoss.display_name()` falls back to "PAUL").
- `the_slender` at Totenhafen round 25 standalone (round 45 campaign) per §6 of that doc, moved from Morgenrot:
  the **Hafenwächter**; his Watch system runs on the pen hall's catwalks and the quay; he locks the Pen Hall doors
  and the pump stair as he walks (a locked door re-opens for free when he leaves the zone or dies); his lantern beam
  is the danger; a Morgenrot hook stays (`bosses/map03.json` placeholder entry pointing at the same script). The
  `Homage Bosses` setting toggles all three off. Both get a smoke, a title card, VO, a POW card and an Archive entry.

## C6. Fernflug set-pieces (§3; one worker per act; ids fixed so the bots worker and the launcher can reference them)
- Act I: `air_raid` (act round 8; `map04a.json "raid"`: sirens, flak towers, a bomb walk, `collapse: "Hall2Roof"`
  which swaps the route: `Door_E_south` blocked by rubble (a `RubbleBlock` on the navmesh), `Breach_E_apron` opened
  (a new NavigationLink); fires and smoke after), `rivet_line` (`traps.json rivet_line`: the gantry runs the hall's
  length, 25 s, kills under it), `wind_tunnel` (`WindTunnel` node: a lever starts the fan 20 s: zombies in the
  tunnel volume are pushed back at 6 m/s and shredded at the screen, players are pushed at 3 m/s; a shortcut because
  the fan's draft opens the test-section hatch while it runs).
- Act II: `wing_walk` (`WingWalk` node: a breach in C opens `wing_rails`: a tether-rail path on the port wing's upper
  skin with a navmesh region, `clip_points` the player holds to clip in (a 1 s hold), `turbulence` events shake
  unclipped players off: a down in solo, never a death; the reward chest at the wingtip: a random Undertow-class part
  or a perk-tier discount token `discount_token`), `turbulence_tilt` (the floor tilts ±8° for 6 s, telegraphed by the
  Bordfunk 3 s ahead: loose props and zombies slide downhill with `slide_mps`; players too, reduced), `decompression`
  (a breach event: a 4 s suction volume that pulls unanchored zombies out and drops `ammo_out` ammo boxes from the
  bay). All on the act's flight clock (`map04b.json "flight"`), host-authoritative.
- Act III: `dust_storm` (every 5th act round: fog to 15 m, `stalker` enemies hunt by sound: sprinting raises their
  `hear_radius`; `map04c.json "dust"`), `wreck_collapse` (sections of the wreck fall at act rounds 23/26: a list of
  `collapse` groups; the fuel fire spreads along the wing: a growing damage zone), `radar_ping` (the dish turns when
  powered and pings the minimap with every zombie for 10 s every 60 s: `GLBus.radar_ping(seconds)`; the minimap shows
  them).
- Act IV: `terminator` (`MondlichtController`: a day/night line crawls across the base over the act: zones in
  shadow get `cold` (the suit heater strain: a slow air drain) and dark, zones in sun are `glare` (a bright veil
  unless the visor is down: a toggle key), `map04d.json "terminator"`), `earthrise` (the Earth's violet spreads with
  rounds and *reverses* as the cancel steps complete: `earth_sky.gd` reads the quest's step count), `low_g` (jump
  pads `JumpPad`, glides, zombies leaping from above (`jumpjockey` already), flinging zombies into space with the
  Lodestone: a Lodestone hit on a zombie in the yard above `fling_speed` sends it up and out: a kill with a long
  scream), `meteor_shower` (a round event: impacts across the yard for 40 s, kills in the open, shelter in the
  modules; telegraphed by the relay's warning).
- Every act also: `<act>_ambience.json`, a power-on spectacle, a loop that survives round 30+ (documented in MAPS.md
  / MAP4_FERNFLUG.md), a named companion scene (Jette in I/II, Dee in III, the Operator's voice in IV reads as the
  "companion" only if a real person is impossible: prefer a new person per act per T-135's pattern), 4+ story props,
  a trap with a show, the side eggs verified findable, the transitions as events (the loading screen shows the act's
  card with a lore line and preloads during the exfil cutscene).

## C7. Bots (§7; the bots worker)
Routes and plans per new zone/set-piece (`data/gravelight/ai/routes_map02.json`, `routes_map04*.json`), `bot_task`
for every Letzte Fahrt step (C3) and the Fernflug set-pieces (C6: the wing walk as a `risky` optional task, the
searchlight via mark orders, the wind tunnel as a trap use, the dust storm as "stay close, don't sprint"), the
Kaltenbrunn egg to 3/5 (U08 §4 blockers in PROGRESS.md), and Q-19 (bots alone through Act II). Soak scenarios:
`tools/ai_soak.sh --scenario=totenhafen|fernflug|kaltenbrunn ...` (the usage comment is fixed; the flag is
`--scenario=`).

## C8. Online (§8)
Every new system: the host decides, peers follow the presentation (`Net.mirror`, `_rpc_world`, `_rpc_fx`). The
floods, the boat's `sail_t`, the searchlight's aim, the terminator's line, the dust storm's fog and the meteor
impacts are all one host-owned value or event each. `smoke_webrtc` gains two scenario flags: `--map=map02 --through=
flood,sail` and `--map=map04b --through=turbulence,wingwalk`.

## C9. Decision numbers
T-151 the Bar; T-152 Totenhafen design (the lead); T-153 Totenhafen systems; T-154 Totenhafen living world;
T-155 Act I; T-156 Act II; T-157 Act III; T-158 Act IV; T-159 PAUL; T-160 THE SLENDER (incl. the canon move);
T-161 Kaltenbrunn living world; T-162 polish; T-163 bots; T-164 online check; T-165 the blind review.
