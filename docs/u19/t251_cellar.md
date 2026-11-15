# T-251 (UPDATE 19): Map 0's cellar +75 %, the lever and the Crucible two doors deeper, perk machines dealt over the map

Branch `claude/u19-cellar`. Worker note for the lead to paste into `docs/DECISIONS.md`.

## What the owner asked (2026-11-14)

"expand the cellar in the first map by 75% make the crucible and power two addtional doors down, spread perks randomly
around the map". The first map is Map 0, the Crossroads Inn (`map00_crossroads`). This is a layout and gameplay change:
the navmesh, the zones and the doors change on purpose.

## What was built

### 1. The cellar: two rooms in a chain past the Helvetia vault

Frame: +X east, +Z south, floor y -3.2 (`CELLAR_Y`), ceiling -0.2, walls 0.3 m on the lines given.

```
                 x 24        28              36          42.2  44
   z 10  +--------+ stair hall
         |  ramp  |
   z 19  +--------+----------------+
         |  THE HELVETIA VAULT     |  z 22.6 +---------+
         |  (zone CELLAR, 144 m2)  ==arch==   the bay  |   (zone CELLAR, 43.4 m2)
         |  wash copper in the old |  z 29.6 +---------+
         |  alcove (x 29.5, north) |
   z 31  +--[Door_Lager 750]-------+--+--------------------+
         |  x 25..27        |         |  Crucible   lever  |   north wall: Crucible x 37.5,
         |  THE LAGERING VAULT        |  (x 37.5)  (x 40.5)|   lever x 40.5, bench in the NE corner
         |  zone LAGERKELLER          |                    |
         |  [tun][tun][tun]   [Door_Dynamo 1000]  [ set ]  |   THE DYNAMO ROOM
         |  x 28.1..32.0      z 34.4..36.4  x 37.8..40.2   |   zone MASCHINENRAUM
   z 37  +--------------------+  x 34 |                    |
                                      |  sump (SW)         |
   z 39                               +--------------------+
                                     x 34                 x 44
```

| | The Lagering Vault | The Dynamo Room |
|---|---|---|
| Generator constants | `LAG_*` | `DYN_*` |
| Extent (wall lines) | x 24..34, z 31..37 | x 34..44, z 31..39 |
| Area | 60 m2 | 80 m2 |
| Zone id / name | `LAGERKELLER` / "The Lagering Vault" | `MASCHINENRAUM` / "The Dynamo Room" |
| Door | `Door_Lager` (`door_lager`), **750**, 2.0 m, in the vault's south wall at x 25..27 | `Door_Dynamo` (`door_dynamo`), **1000**, 2.0 m, in the wall on x 34 at z 34.4..36.4 |
| The loop's island | three tuns on cradles, x 28.13..31.97, z 33.3..34.7 (corridors 2.15 m north and south, 1.75 / 1.9 m at the ends) | the generator set on its plinth, x 37.8..40.2, z 34.7..35.9 (corridors 1.95 m north of it to the Crucible's front, 2.95 m south, 3.65 m west and east) |
| Zombie entry | `Spawn_LagerDrain` (ground, round 4+) at (32.9, 32.1), the floor drain | `Spawn_DynamoSump` (ground, round 4+) at (35.2, 37.9), the sump |
| Always lit | `LagerLamp` (oil lantern inside the door) | `DynamoLamp` |
| Lever's lights | 3 `LagerBulb` (zone LAGERKELLER) | 3 `DynamoBulb` (zone MASCHINENRAUM) + the Crucible room's own |
| Perk spot | `lager` (25.6, 35.0), opposite the door | `dynamo` (42.3, 37.0), south wall east of the set |

Area: the cellar was the vault 12 x 12 = 144 m2 plus the bay 6.2 x 7 = 43.4 m2 = 187.4 m2. The two rooms add 140 m2:
**+74.7 %**. Their roofs are the yard's east edge and the field's snow (the ground slabs are cut over them like the
bay's); nothing above ground moved.

Fiction (no real brand): the Lagering Vault is the inn's own lager cellar, older than the fit-out, brick, with the
three tuns; the Dynamo Room is the Helvetia installers' plant room, whitewashed, with the generator set whose
cable you follow on the soffit from the vault's fuse box, through both doors, to the fuse board by the lever.

Door prices: the map's doors run 750 (upstairs, the gate), 1000 (stable), 1250 (yard, front, Old Cellar), 1500
(cellar). The two new ones are 750 and 1000, so the power costs 3250 from the taproom instead of 1500.

### 2. The Crucible and the lever are in the Dynamo Room

- `Kellerschalter` (power_switch.gd, `config_table` map00) at (40.5, -2.9, 31.35), yaw 180. `zone_order` is now
  MASCHINENRAUM, LAGERKELLER, CELLAR, OLD_CELLAR, TAPROOM, UPSTAIRS, STABLE (the sweep starts at the lever).
- `Crucible` (`needs_power` true) at (37.5, -3.2, 31.95), yaw 180, its `NavBlock_Crucible` under it.
- Both keep the measure they had on the vault's north wall, taken from the room's north-east corner (Crucible 6.5 m,
  lever 3.5 m west of it; the wall 0.8 m behind the Crucible's centre; the bench and the two crates in the corner),
  so `crucible_rooms.json` "map00" (every position in the Crucible's own frame) fits unchanged. Only its `zone`
  (the room lights' sweep zone) and `note` changed.
- **For T-254 (the Crucible's look):** the alcove is on the north wall, x 35.95..39.05, z 31.15..32.75 (the footprint
  box is x 36.5..38.5). The approach in front is kept clear: x 36.3..38.7, z 32.75..34.6 (the feed ring is at z 33.35,
  the generator's plinth starts at z 34.7 and x 37.8). West of the alcove two oil drums stand in the corner
  (x 34.15..35.5, z 31.15..31.85); the fuse board is at x 39.2, the lever at x 40.5. Room height 3.0 m. The generator
  draws `_crucible_setting(g, cx, zf)` (brick facing, two iron columns, the lintel, the soot disc, the grate and ring):
  that is the shell; the dresser's pieces come on top as before.
- The power-on burst points are the drain and the sump (they were the vault's two corners).
- The vault's old alcove holds the inn's wash copper under the flue whose chimney stack still stands in the snow
  (`_wash_copper`, collider `CellarCopperCol`): brick body, copper rim and lid, fire door, stovepipe, tub, scuttle.
  The fuse box stays as the vault's sub-board. The wine rack moved from the south wall (the door is there) to the
  west wall.

Nothing softlocks with the lever three doors deep (checked): the radio quest and the objectives do not need the power
before a door (the objectives tab now walks the three doors, then the lever); the exfil beacon opens STABLE and needs
no power; the Sherman's `shelter_zones` gained the two rooms; the squad's power plan buys the nearest closed door on
the path to the switch (generic, `BotEconomy.door_toward`); the agent's plan names the two new doors before the lever.

### 3. Perk machines are dealt onto perk spots each match

- **17 perk spots** (`gen_map00.gd` `PERK_SPOTS`, a `PerkSpot` node each), at most 3 in a zone:

| Spot | Zone | Position (x, y, z) | Faces | Flags |
|---|---|---|---|---|
| taproom_nook | TAPROOM | 2.25, 0, 2.0 | south | start |
| guest_room | UPSTAIRS | 18.0, 3.8, 3.3 | east | near |
| guest_hall | UPSTAIRS | 18.6, 3.8, 7.9 | north | near |
| attic | UPSTAIRS | 16.0, 7.1, 8.0 | north | near |
| stable | STABLE | 14.25, 0, 32.0 | north | near |
| hayloft | STABLE | 12.5, 3.5, 32.0 | north | near |
| yard_east | YARD | 32.0, 0, 46.5 | west | outdoor |
| yard_west | YARD | 4.25, 0, 39.5 | east | outdoor |
| behind_stable | GROUNDS | 27.5, 0, 32.5 | east | outdoor |
| carters_road | GROUNDS | 15.0, 0, 50.0 | south | outdoor |
| vault_east | CELLAR | 34.0, -3.2, 21.4 | west | near |
| vault_south | CELLAR | 31.75, -3.2, 29.0 | north | near |
| bay | CELLAR | 40.25, -3.2, 25.95 | west | near |
| old_vault_north | OLD_CELLAR | 15.0, -3.2, 2.0 | south | near |
| old_vault_south | OLD_CELLAR | 19.0, -3.2, 13.75 | north | near |
| lager | LAGERKELLER | 25.6, -3.2, 35.0 | north | |
| dynamo | MASCHINENRAUM | 42.3, -3.2, 37.0 | north | |

- Every spot keeps 1.0 m clear behind the machine (the fine print on its back is read from there) and 1.2 m in
  front, and was found and is re-checked by the generator itself: `_audit_perk_spots` tests the widest-by-deepest
  footprint (1.7 x 1.2 m), the walk in front and the walk behind against every collider, every drawn mesh and every
  library prop, wants a wall behind, floor on the navmesh in front, and keeps a distance from doors, windows and the
  walk their zombies take to the boards, wall-buys, crates, ammo boxes, the bench, the spawns, the lever and the
  Crucible, the ladders, the zip line, the horse and its rail, the exfil beacon, the Sherman's route and shelter points,
  the story props, the opening's patrons, the survivors, the extra people and every bot training loop. A blocked spot
  stops the scene being saved. `GL_PERK_SURVEY=1` lists every place that passes (how the 17 were chosen).
- **Navigation:** every spot bakes one `NavBlock_PerkSpot_<id>` box (1.7 x 1.2 m, group `bake_only`: no collision at
  runtime), so the navmesh is the same whichever machine stands there. What stops you is the machine's own body, or
  the filler's.
- **Filler:** a spot without a machine shows a Helvetia shipping crate nailed shut on its skids (boards, battens,
  steel bands, a blank tag; snow on it outdoors, a crowbar and packing straw indoors), 0.95 x 1.85 x 0.7 m, solid.
- **The deal** (`PerkShuffle.assign`, pure, seeded; rules in `data/gravelight/perk_layout.json`):
  - at most **2 machines in a zone** (`max_per_zone`), so the twelve always cover at least six zones;
  - **outdoor spots** take only the shapes that are weather kit (`outdoor_shapes`: barrel, wagon, safe, crate,
    periscope, glider, twin, teardrop); Second Wind's cabinet, Overclock's bare coil, the Ledger's brass register and
    Magpie's bandit stay indoors;
  - **the start room's spot** takes only tonics up to 2000 Scrip, and never Second Wind (it pours without the power
    solo: it would be a free self-revive at the spawn);
  - **Second Wind** only stands on a spot one bought door from the taproom (`near`), so a solo player always has it
    close;
  - the most restricted tonics are placed first, with backtracking; rules are dropped (the zone cap, then the rest)
    rather than leave a machine out.
- **The seed** is the match seed (`QuestManager.match_seed`), which every peer already shares (Net sends it with the
  match start and again to a rejoining client), so the layout needs no data of its own on the wire. The host is still
  the authority: its seed rides in the state snapshot (`"pl"`), and a re-deal is mirrored (`Net.mirror`), so a client
  that started from another seed follows the host. A match that is started again from the same seed (a rejoin, a
  pinned seed) gets the same layout; there is no mid-match save on this game to restore beyond that (the campaign
  carries players between maps, and Map 0 is its first).
- **Fixed seed:** `perk_layout.json` `fixed_seed`; `--perk-seed=<n>` on the command line; `PerkLayout.forced_seed`
  (tests and smokes; `PerkLayout.seed_where(scene, predicate)` finds a seed with a machine where a smoke's story
  needs it). **Dev console:** `perks list`, `perks shuffle [seed]` (deal again now, host), `perks seed <n>` (the next
  match).
- **Finding them:** the machines are still the nodes `Gameplay/Perk_<id>`, moved as a whole, so the pause map, the
  minimap, the pings and the marks read their live positions; `MapState.refresh_live_pois` rewrites the perk POIs'
  position and floor for the match (on the match's own copy of the map data) and forgets their discovery; the
  loadout tab's "where" reads the match's rows. The scene (and the baked `mapdata.json`) holds the seed-0 deal.
- **Bots:** they already found machines through the `perk_machines` group and live positions; no data held a row
  coordinate (a test keeps it so). New: the agent's plan buys the closed door on the way to a planned tonic the deal
  stood behind one (`AgentPlan.errand_for`), and names `door_lager` and `door_dynamo` before the lever. Companions'
  "GET YOURSELF A TONIC" picks the nearest reachable powered machine as before.
- **Lore:** `docs/gravelight/PERKS_LORE.md` section 4 no longer says where each Map 0 cabinet stands (the patrol had
  the vault cleared the night the plane came down; the cabinets went wherever a hand truck would go);
  `machine_lore.json` rebuilt from it.

## Calls I made

1. **Rooms south and south-east of the vault** (under the stable's east end, the yard's east edge and the field):
   free ground, nothing above changes, and the door in the vault's south wall is straight ahead from the stair foot.
2. **75 % counted on the cellar's floor by wall lines** (the vault and the bay; the stair hall is not counted).
3. **Prices 750 and 1000**: inside the map's range, and the owner asked for the lever to be deeper, not dearer than
   it has to be. 3250 to the power.
4. **Ground spawns from round 4** in both rooms (the coal chute is round 6): with the lever three doors deep, a room
   with one doorway must not be a safe camp.
5. **No bot training loop in the two rooms**: their corridors are 2.15 m (the map's loops run in 3 m or more) and
   each has one door. Bots go in for the lever, the Crucible and the tonics.
6. **The lead's design kept** (fixed spots, a seeded deal by the host, fillers, a nav box per spot) with these
   refinements: one bake-only box of the widest footprint per spot instead of per-machine boxes (nothing invisible
   round a narrow cabinet); the match seed instead of a new replicated value (plus the snapshot and the mirror for a
   host that deals differently); 17 spots; one spot only in the taproom (it is the start room and full).
7. **Second Wind is never in the taproom and always one door away**; the taproom's spot takes the cheap tonics only.
8. **The back-panel walk is kept on every spot** (the Fine Print is read from behind the machine), which is why spots
   need 3.4 m of depth and why some rooms have one.
9. **The scene is saved with the seed-0 deal**, so tools that load it without a match (the POI refresh, tests that
   read the .tscn) still find twelve `Perk_<id>` nodes on valid spots.
10. **The vault keeps its bench, bulbs, coal corner and bay**; three spots are in zone CELLAR (the vault's east and
    south walls, the bay's far wall).
11. **Bots (three flaws the new layout exposed, fixed at the root):**
    - *A zone whose bought door is shut is not reachable* (`BotBrain.shut_door_of`, used by `_reachable_now`). Map 0's
      navmesh reaches the Old Cellar through the bolted hatch's climb link (T-229) without crossing a bought door, so
      the Old Cellar's ammo box counted as reachable with Door_OldCellar shut. `smoke_bots` caught it: a dry bot
      standing in the taproom over that box (3 m on the flat, a floor below) chose it and stood there 137 s. It was
      there before this work (the gewehr43 chalk and that box), and with tonics dealt into the Old Cellar it would
      have bitten more often. `BotEconomy.door_toward` falls back to the door that opens the goal's zone.
    - *An errand at hand goes ahead* (`economy.json` `self_led_at_hand_m` 12): a self-led bot (the squad alone, the
      agent) only did far errands when the trip home fitted the break; the lever is now 37 m from the taproom, so the
      agent opened the Dynamo Room and walked out again.
    - *A door opening drops the stand-point and power-plan caches too* (`BotBrain.forget_reach`): the agent held "no
      stand point at the lever" for 4 s after buying the last door.
12. **`smoke_marks` and `smoke_jakub` pin a deal** (`PerkLayout.seed_where`) instead of opening every door: their
    stories need a machine behind the doors they open.

## Files

- Generator and scene: `gravelight/tools_src/gen_map00.gd` (`LAG_*`, `DYN_*`, `PERK_SPOTS`, `build_deep_cellar`,
  `build_deep_cellar_gameplay`, `build_perk_gameplay`, `_dress_deep_cellar`, `_wash_copper`, `_crucible_setting(g, cx,
  zf)`, `_audit_perk_spots`, `_survey_perk_spots`, `WINDOWS` as a constant, the root-script guard),
  `gravelight/maps/map00_crossroads/map00.tscn` (regenerated).
- New runtime: `gravelight/world/perk_shuffle.gd` (pure deal), `perk_layout.gd` (per match), `perk_spot.gd` (the
  spot and its crate), `data/gravelight/perk_layout.json` (rules).
- Hooks: `maps/map_root.gd` (attach after `match_started`), `net/net_match.gd` (snapshot key `pl`),
  `ui/dev_console.gd` (`perks`), `core/map/map_state.gd` (`refresh_live_pois`), `ui/pause_menu.gd` (the loadout's
  "where").
- Bots: `bots/bot_brain.gd`, `bots/bot_economy.gd`, `bots/agent_plan.gd`, `data/gravelight/ai/player_bot.json`,
  `data/gravelight/ai/economy.json`.
- Data: `data/maps/bake_config.json` (zone names), `data/maps/map00_crossroads/*` (rebaked under WSL: 9 zones,
  41 POIs, the cellar and ground floor images), `data/gravelight/map00.json` (shelter zones), `vo_rooms.json`,
  `objectives.json`, `crucible_rooms.json` (map00 `zone`, `note` only), `machine_lore.json` (rebuilt),
  `capture_cams.json` (set `u19_cellar`).
- Docs: `docs/gravelight/PERKS_LORE.md` section 4, `docs/gravelight/MAPS.md`, this note.
- Tests: new `gravelight/tests/unit/test_perk_layout.gd`; rewritten `test_map00_cellar_bay.gd`; updated
  `test_map00_art.gd` (navmesh fingerprints), `test_map00_fences.gd`, `test_mapdata.gd`, `test_objective_log.gd`,
  `test_perk_caps.gd`.
- Smokes and tools: `smoke_map00_cellar_bay.gd` (rewritten), `smoke_map00.gd`, `smoke_map00_loop.gd`,
  `smoke_coop.gd`, `smoke_bots.gd`, `smoke_jakub.gd`, `smoke_marks.gd`, `play_ledger.gd`, `play_marks.gd`,
  `tools_src/shots_cellar.gd`.

## Verification (headless, on the machine shared by four workers)

- **check_scripts:** 941 scripts, 0 failed.
- **Generator:** a clean run (21 to 32 s): navmesh 1268 polygons (breach open 1319), 634 collision boxes, WALLBUY_AUDIT
  7 clear, PERKSPOT_AUDIT 17 clear, 8026 static meshes batched. The bake is deterministic: two regenerations gave the
  same navmesh fingerprints (`test_map00_art`: Navigation `8b4164…`, NavigationBreachOpen `e70b4b…`).
- **GUT, full suite:** first run on the new map 2344 tests, 2338 passing, 5 failing, 1 risky (the baseline's risky
  "did not assert"). The five were expectations of the old layout (navmesh fingerprints, the bake-only count, "the
  perk machines are in the cellar", the objectives' text, the loadout's "where") and were updated. Second full run
  after every change: 2344 tests, 2342 passing, 1 failing, 1 risky; the one was `test_machine_lore` (my rebuild of
  `machine_lore.json` from the markdown had dropped rows the markdown lacks; the JSON is now edited in place) and
  passes on its own (4/4). New and rewritten files: `test_perk_layout` 9/9, `test_map00_cellar_bay` 12/12.
- **Two seeds, two layouts; one seed, one layout:** `test_perk_layout` (40 seeds give more than 35 layouts; seed 4471
  twice and with the spot and perk lists reversed gives the same deal; 400 seeds keep every rule; every spot is used
  by some seed; Second Wind stands on more than four different spots) and `smoke_map00_cellar_bay` live (seed 251,
  then 252: 10 of 12 machines elsewhere; 251 again: 12 of 12 back; the map's perk POIs follow, 12 of 12).
- **Co-op:** `smoke_coop` (a host and a client process): the host deals from a pinned seed (4242) that is not the match
  seed, deals again (5151, mirrored) once the match has begun, and at the end both peers report the same place for
  every machine and the same crates. PASS.
- **Smokes** (`tools/run_smokes.sh`, one at a time):

| Smoke | Result |
|---|---|
| smoke_map00 | PASS (3 runs) |
| smoke_map00_alive | PASS (2 runs) |
| smoke_map00_cellar_bay (rewritten: 53 checks) | PASS (3 runs) |
| smoke_map00_loop (the relief-squad guard of 369b2834 kept) | PASS (2 runs) |
| smoke_sherman | PASS, PASS, then FAIL once ("the 75 mm fires on them (0 shells)", "nothing on the players"), PASS again: 3 of 4, the tank's gun inside its window under load, nothing of the cellar's |
| smoke_companion_perks | PASS (2 runs) |
| smoke_coop | PASS (2 runs) |
| smoke_bots | FAIL once, then PASS twice. The failure: "P4 never refilled its upgraded gun at an ammo box": the dry bot stood in the taproom over the Old Cellar's ammo box (call 11); fixed, then green twice (the second in 438 s) |
| smoke_bots_shop, smoke_bots_shop_m0, smoke_bots_u10 | PASS (2 runs each) |
| smoke_jakub (pins a deal) | PASS (2 runs) |
| smoke_horse, smoke_ladders | PASS |
| smoke_marks | FAIL (1 of its checks): "an empty spot: collect, go". This is the failure the last morning report lists as there before this work (a part dropped at the player's feet under the click); the perk and door phases pass with the pinned deal |

- **ai_soak, three bots alone (`--scenario=bots3 --seed=251 --max-round=14`):** reached round 15 in 24.7 game minutes,
  650 kills, 0 downs, the radio egg completed. Doors bought: upstairs (round 1), stable (1), **door_cellar (round 2,
  t 102 s), door_lager (round 3, t 152 s), door_dynamo (round 3, t 204 s)**, old cellar (3). **Power: round 3.**
  **Crucible: 8 forges** (the first in round 5 at t 410 s; 52,500 Scrip). **Tonics at dealt machines: 7 tier brews**
  from round 8 (Second Wind in the Old Cellar x3, Ironhide in the Old Cellar x2, Marathon in the upstairs hall x2).
- **ai_soak, the agent (`--scenario=botmode`, solo):** before the cache fix of call 11 the lever was thrown in 1 run
  of 5 (power_round 0, 0, 0, 0, 4). After them, three runs: door_cellar, door_lager, door_dynamo bought in rounds 2 to 4 in
  all three; **power in round 4 in two** (the third wiped in round 5); Second Wind bought at its dealt machine in both
  (in one of them the agent bought the Old Cellar's door first, on the way to it), Ironhide in one. The agent still
  wipes between rounds 5 and 8, as its plan's notes say it did.
- **Facing check** (`tools/tests/test_interactable_facing.gd -- --maps=map00 --report-only`): PASS, 0 failing. The two
  new doors, the Crucible, the lever and the twelve machines on their seed-0 spots are OK (the one UNSURE row is the
  guest-bed crate, as before).
- **Minimap:** `data/maps/map00_crossroads` rebaked under WSL Xvfb (`tools/wsl_godot.sh --path .
  res://tools_src/bake_minimap.tscn -- --map=map00_crossroads`): RESULT PASS, 4 floors, 9 zones, 41 POIs. The cellar
  floor image shows both rooms; every perk spot is a small solid square on its floor (the bake draws the footprint
  boxes, whichever machine a match stands there).

## Renders (WSL Xvfb, software GL, looked at)

`docs/captures/u19_cellar/` (capture set `u19_cellar` in `capture_cams.json`, deal pinned with `--perk-seed=251`):

- `vault_before_vs_after/` (7 JPGs, before on the left): the same seven cameras of the existing `u05` set (the vault
  from the north, north-east, south-west, south, east and west, and the bay) on the scene before T-251 and after it,
  under the set's work light. Before: the three machine rows, the Crucible in the alcove and the lever on the north
  wall. After: the wash copper in the alcove, the fuse box alone, Door_Lager in the south wall, Blastproof Bock on the
  east-wall spot, Ledger Lager on the south-wall spot, the wine rack on the west wall, a shipping crate on the bay's
  far wall. (The first pair, `cellar_vault_n`, has the match's title card over it: it is the first frame of each run.)
- `after/` (48 JPGs): the Lagering Vault and the Dynamo Room unlit (their lanterns only), lit by the lever, and under
  a work light; the lever and the Crucible in the Dynamo Room; the tuns; the generator set; the vault's alcove; and
  every perk spot with what seed 251 stands on it: machines on vault_east, vault_south, lager, dynamo, old_vault_north,
  old_vault_south, guest_room, attic, stable, hayloft, yard_east and carters_road, crates on bay, taproom_nook,
  guest_hall, yard_west and behind_stable.
- What they show, honestly: the shapes and the dressing read (the work-light frames); the real-light frames are much
  darker than the game, because WSL renders with the Compatibility renderer (no SDFGI, 8 lights per mesh), so the
  lever's bulbs barely light the walls there, in the old vault as much as in the new rooms. The bulbs are the vault's
  own (energy 1.5, range 6.5 m, three per room). **The lit look on the real renderer is not verified** (no GPU
  window on this PC without the owner's OK).

## At merge

- `gen_map00.gd` and `map00.tscn` are this branch's. If another branch's hunk lands in `build_environment` /
  `build_landscape`, regenerate once (`godot --headless --path . --script res://gravelight/tools_src/gen_map00.gd`):
  the navmesh fingerprints in `test_map00_art` must not move (the bake is deterministic), and the generator now
  refuses to save when a perk spot is blocked or MapRoot did not load.
- **Run the import before the generator** on a fresh checkout: three new `class_name`s (`PerkShuffle`, `PerkLayout`,
  `PerkSpot`). Without the class cache `map_root.gd` does not compile and the scene would be saved without its root
  script (it happened once here; the generator now stops instead).
- `data/gravelight/crucible_rooms.json`: two lines in the `map00` row (`zone` MASCHINENRAUM, `note`). T-254 edits the
  same row: keep its pieces, keep this zone.
- `data/gravelight/capture_cams.json`: the `u19_cellar` set is inserted before `u18_text` (not at the end), to stay out
  of the other workers' hunks.
- `docs/gravelight/PERKS_LORE.md` is behind `machine_lore.json` (the JSON holds `chalk.bar`, `chalk.frag` and Map 1's
  Skyhook, the markdown does not): do not rebuild the JSON with `tools/build_perk_lore.py` until the markdown has
  them. Both were edited by hand here.
- New data keys: `perk_layout.json` (new file); `economy.json` `self_led_at_hand_m`; NetMatch state key `pl`.
- After the merge, if T-252 changes the minimap's look: the Map 0 floor images here were baked under WSL (software
  GL). They match the stylised bake; a GPU rebake (`tools/bake_minimap.sh map00_crossroads`) is optional.

## Open items

1. The lit look of the two rooms on the Forward+ renderer (above).
2. The agent (player-bot mode) on Map 0 is as weak as before (wipes in rounds 5 to 8); with the power three doors deep
   and 3250 Scrip away it gets the lever in round 4 instead of 3. Its plan's order was kept; retuning it is its own job.
3. `smoke_marks` "an empty spot" still fails as on master. `smoke_sherman` failed once in four runs under load.
4. No bot training loop in the two new rooms (call 5). If the owner wants bots to hold them, the corridors want
   widening to 3 m first.
5. Other maps keep their fixed machines: a map joins the deal by getting `PerkSpot` nodes and a row in
   `perk_layout.json`.
6. The filler crate is procedural (about 60 boxes baked into a handful of meshes per free spot, 5 per match). If
   T-253's model pass wants a modelled crate, `PerkSpot._build_filler` is the one place.
7. The guest room's spot stands 1.5 m from that room's swing door (a leaf left ajar that swings when walked into); its
   tip reaches the corner of the machine's approach. The audit does not see the swing doors (they are built at load).
   Moving the spot 0.5 m north would clear it and costs a regeneration and new navmesh fingerprints.
