# T-255 (UPDATE 19 fixes): the taproom's perk spot, Käthe's drawing, the cellar before the lever

Branch `claude/u19-fixes` (from master 4a527f4f). Worker note for the lead to paste into `docs/DECISIONS.md`.

## What the owner reported (2026-11-15, after playing UPDATE 19 on Map 0)

"just a couple of glitches this perk location is a bad spot, also while the lights and powr are off the room in the
cellar is too dark", with two screenshots: (1) the taproom's north-west nook, a nailed crate standing free on the
floor in front of the clock wall, a blue-lit patch on the floor behind it; (2) "Käthe's Drawing" hanging off its wall
near a corner upstairs.

## 1. The perk spot

**Cause.** T-251 stood every `PerkSpot` 1.0 m clear of the wall behind it (the fine print on a machine's back is read
from there). The taproom's spot was at (2.25, 0, 2.0): its crate stood 1.25 m out from the north wall and 2.1 m from
the west wall, in the middle of the walk that runs from the service walk's mouth down to the Old Cellar door. The
same metre stood behind all 17 spots; in the Forward+ frames the guest room's cabinet stood in the middle of the room
and the vault's stood out on the floor (the machine rows that used to explain the gap are gone).

**Fix.** A spot can be **flush** (`PERK_SPOTS` flag `"flush": 1 / -1`, `PerkSpot.flush`):

- the spot's back edge is 0.1 m from the wall's face (`PERK_FLUSH_GAP`: clear of the wainscot's rail); whatever stands
  there is moved back to that line (`PerkSpot.stand_offset` / `stand_transform`: a 0.6 m cabinet stands 0.3 m further
  back than the 1.2 m barrel, the crate 0.25 m), so every cabinet's back is on the wall;
- the machine's fine print hangs on its side instead of its back (`PerkMachine.set_panel_side`; +X or -X as the flag
  says), and the generator keeps 0.9 m of walk beside it there (`PERK_SIDE`) instead of the walk behind;
- the bake box of a spot is unchanged (1.7 x 1.2 m, bake-only), so the navmesh still does not depend on the deal;
- the bots' approach point stays where it is for a cabinet on the spot's origin (`PerkMachine.set_stand_back`:
  `interact_offset`, which `BotBrain._front_of` reads, is measured from the spot's front line; the use box the player
  aims at stays on the cabinet's face). Without it a 0.6 m cabinet stood 0.3 m back had its approach point 0.03 to
  0.16 m off the navmesh's edge, and `smoke_bots_shop_m0` caught a companion standing a step short of Second Wind on
  the stable's spot for 500 s (see Verification).

16 of the 17 spots are flush now. Positions (x, y, z), facing unchanged unless said:

| Spot | Before (T-251) | After | Fine print |
|---|---|---|---|
| taproom_nook | 2.25, 0, 2.0 | **1.1, 0, 0.85**: the north-west corner itself, back on the north wall, 0.1 m from the west wall | east side |
| guest_room | 18.0, 3.8, 3.3 | 16.85, 3.8, 2.8 (on the wall to the middle room) | north side |
| guest_hall | 18.6, 3.8, 7.9 | 20.6, 3.8, 9.03 (south wall, east of the landscape painting) | east side |
| attic | 16.0, 7.1, 8.0 | 16.0, 7.1, 9.15 | east side |
| stable | 14.25, 0, 32.0 | 14.6, 0, 33.15 (0.35 m east: 2.7 m from the window's boards) | west side |
| hayloft | 12.5, 3.5, 32.0 | 12.5, 3.5, 33.15 | east side |
| yard_east | 32.0, 0, 46.5 | 33.2, 0, 46.0 (on the east fence, between the trough and the south fence) | south side |
| yard_west | 4.25, 0, 39.5 | unchanged: the fence's snow bank lies where a cabinet would stand, and north of it the gap's window is too near; it keeps the walk behind it | back |
| behind_stable | 27.5, 0, 32.5 | 26.35, 0, 31.9 (on the stable's east wall) | south side |
| carters_road | 15.0, 0, 50.0 | 15.0, 0, 48.9 (on the yard's south fence) | west side |
| vault_east | 34.0, -3.2, 21.4 | 35.15, -3.2, 20.9 (east wall, beside the bench) | south side |
| vault_south | 31.75, -3.2, 29.0 | 31.75, -3.2, 30.15 | east side |
| bay | 40.25, -3.2, 25.95 | 41.35, -3.2, 25.95 | north side |
| old_vault_north | 15.0, -3.2, 2.0 | 15.0, -3.2, 0.85 | east side |
| old_vault_south | 19.0, -3.2, 13.75, facing north (a metre out from the south wall's wine rack) | **23.15, -3.2, 12.5, facing west**: on the vault's east wall south of the racks (the south wall has no free stretch: rack, ammo box, tunnel mouth). The id is kept so pinned seeds deal as before | south side |
| lager | 25.6, -3.2, 35.0 | 25.95, -3.2, 36.15 | west side |
| dynamo | 42.3, -3.2, 37.0 | 42.3, -3.2, 38.15 | west side |

The rules of the deal, the zones, the flags (start / near / outdoor) and the count are unchanged (17 spots, at most 3
in a zone, one in the taproom), so a seed deals the same tonics onto the same spot ids as before.

**The guest room's swing door** (T-251's open item 7): the spot's walk is 0.6 m clear of the leaf's swing now (the
leaf's tip came to its corner), and the audit knows the three guest-room doors: `_spot_grid_build` adds the box each
leaf sweeps (`ROOM_DOORS`, shared with `build_reactive`), so a spot in a swing stops the scene being saved.

**The generator's aids.** `GL_PERK_SURVEY=flush` lists every flush place per region; `GL_PERK_PROBE="x,y,z,yaw,flush;..."`
prints what is wrong with exact places (note: the survey runs on the navmesh baked with the current spots, so a
place whose front is inside a current spot's bake box reports "not on the navmesh" until the spot has moved).
`PERKSPOT_AUDIT` prints `flush` or `walk` per spot.

**The blue patch on the floor** in the owner's screenshot was not an opening: see section 4.

## 2. Käthe's Drawing

**Cause.** T-241 (2026-11-12, "no space in hallway") moved the guest rooms' hall wall from z 6 to z 5 and the beds
with it. `data/gravelight/story_props.json` holds plain coordinates and was not touched: the drawing (INT_M0_11)
stayed at z 6.15, the old wall's face, so it hung in the hall's air **1.00 m in front of the wall**, 1.35 m from the
north-west corner (from the stair head it read as a sheet standing across the corner).

**Fix.** Position (1.5, 5.15, 6.15) -> **(1.5, 5.22, 5.15)**, yaw 180 unchanged: flat on the hall's north wall straight
ahead at the top of the stairs, its centre 1.42 m over the floor (the sheet's foot clear of the wainscot's rail at
1.13 m), 1.35 m from the corner, 2 m from the sconce on the west wall and 3.5 m from Room 1's door.

**The check, and what else it found.** New `gravelight/tools_src/story_prop_mount.gd` and
`tools/tests/test_story_prop_mounts.gd` (headless, from the scene file's box colliders, like the T-219 facing tool):
every story item and every `PaperDecor` sheet must have its wall within 3.5 cm behind it (both edges of the sheet) or
its table within 4 cm under it (the page's four corners). On Map 0 (16 items) it found, besides the drawing:

- **INT_M0_12, the unsent letter in Room 3**: the same T-241 move left it on the bed's foot edge, half of the page
  over the floor. (22.3, 4.28, 4.7) -> (22.3, 4.28, 3.8): where it lay on the blanket before the bed moved.
- Käthe's two frequency slips by the wireless report "inside BackShelf": they are pinned on the back-bar's drawn back
  board, inside the open shelving's shot-through collider. Listed as open furniture (`OPEN_FURNITURE`), not a fault.

The other 13 are on their surfaces. `test_story_props.test_map_0_items_are_on_their_surfaces` pins Map 0.

**Other maps (not fixed, not verified: listed for the lead).** The same tool reports 21 items on Maps 1, 2, 4a, 4c
and 4d. Many will be surfaces without a box collider (a hull, a drawn desk), which the tool cannot tell from air, so
each wants a look before anything is moved: `.smoke_logs` is not committed, so run
`godot --headless --path . --script res://tools/tests/test_story_prop_mounts.gd -- --report-only`. Map 1: the three
STAUB memos (0.30 to 0.45 m off a wall). Map 2: INT_M2_04 (0.20 m), the Hale telegram, the payslip and the ration
book (0.8 m over a collider). Map 4a: the window letter (0.10 m), the load sheet and the lab subjects sheet (0.05 m).
Map 4c: the manifest (no wall), the program log, the diary page, the culture log and Hale's order. Map 4d: the relay,
the crew tags, the smile and the relay card (no box wall: the capsule's hull?), Pilch's item, Haas's tag (0.11 m).
Map 4b: all five clean.

## 3. The cellar before the lever

**Cause.** Each new room had one oil lantern just inside its door: energy 0.9, range 6 m (the generator's numbers;
`_lamp` makes that 1.35 and 7.5 m in the scene), flickering by 35 %, for rooms 10 m long. The far corners were 9 to
11 m from it, past its reach. The bay's lantern (0.7, 4.5 m, the same flicker) hangs at the arch and its far wall is
5.4 m away. The Helvetia vault has 1.8 over 9.5 m in its middle plus the stair's lamp; the Old Cellar's vault two of
1.6 over 10 m.

**Fix (the generator's numbers; all with a steady flame, flicker 0.12; no shadows, as before).** Every light has its
lantern hanging at it (`Props.lantern`: the lit glass is the emissive `lantern_glass`), no fill light, no ambient:

| Light | Before | After |
|---|---|---|
| LagerLamp (inside Door_Lager) | 0.9, 6 m | 1.15, 9 m |
| LagerLamp2 (new: over the south aisle's east end, 31.6, 36.05) | | 1.05, 9 m |
| DynamoLamp (inside Door_Dynamo) | 0.9, 6 m | 1.75, 10 m |
| DynamoLamp2 (new: over the east aisle, 41.9, 35.3, between the lever and the perk spot) | | 1.75, 10 m |
| CellarBayLamp (the bay's arch) | 0.7, 4.5 m | 1.1, 7 m |
| CellarBayLamp2 (new: over the bay's south half, 39.7, 27.9) | | 1.3, 7.5 m |
| the lever's bulbs (3 a room, 1 in the bay), the vault's and the Old Cellar's lamps | 1.5 each | unchanged |

The brick Lagering Vault takes less than the whitewashed, bigger Dynamo Room. The first try (1.5 / 1.4 in both)
made the Lagering Vault as bright unlit as it had been lit; these are the second values.

**Measured** (Forward+ frames, 960 x 540, the same cameras; mean luma 0..255 and the share of the picture under
12/255, "black"). References on the same run: the taproom before the lever 45 (13 % black), the Helvetia vault 20
(39 to 40 %), the Old Cellar's vault 21.5 (48 %).

| Camera | Mean before | Mean after | Black before | Black after |
|---|---|---|---|---|
| lager_unlit (from the door) | 12.2 | 18.0 | 73 % | 57 % |
| lager_west_unlit (from the east end) | 4.7 | 25.6 | 90 % | 33 % |
| lager_door_unlit (Door_Dynamo) | 3.2 | 31.2 | 95 % | 28 % |
| lager_zombie_unlit | 15.1 | 21.4 | 72 % | 52 % |
| dynamo_unlit (from the door's corner) | 6.1 | 18.2 | 87 % | 45 % |
| dynamo_east_unlit | 5.9 | 23.0 | 88 % | 34 % |
| dynamo_lever_unlit | 6.4 | 16.4 | 86 % | 55 % |
| dynamo_spot_unlit (the perk spot) | 2.4 | 20.7 | 99 % | 41 % |
| dynamo_zombie_unlit | 4.4 | 16.0 | 92 % | 53 % |
| bay_unlit | 2.4 | 18.7 | 98 % | 46 % |
| **the lever thrown:** dynamo_lit / dynamo_east_lit | 23.1 / 24.8 | 37.9 / 43.2 | 36 % | 11 % |
| lager_lit / lager_west_lit | 38.2 / 23.5 | 40.8 / 45.3 | 30 % / 38 % | 19 % / 8 % |

So before the lever the three rooms now read like the Helvetia vault and the Old Cellar do (means 16 to 31 against
20 and 21.5), and the lever still about doubles them (Dynamo 18 -> 38, 23 -> 43; Lagering Vault 18 -> 41, 26 -> 45).
The vault, the Old Cellar and the taproom are unchanged (their frames match to a point).

## 4. Found on the way: the match's Intel pickups all lay inside the taproom's corner

The blue patch on the floor in the owner's first screenshot is the glint (0.8, 0.7, 1.0) of the match's three to five
random Intel pickups, **all of them at (0, 0, 0)**: on Map 0 that is inside the walls of the taproom's north-west
corner, so nothing but their light showed. `MapRoot._spawn_intel` asked the navigation map for random points two
physics frames after the map entered the tree; until the map has its regions `map_get_random_point` answers the
origin (so does `map_get_closest_point`, and the iteration id is already above 0), and the origin is inside the
TAPROOM zone, so every point was accepted. The code is from M2 (2026-10-20) and every map places its Intel through
it, so this was so on every map (where the origin is; nobody could find them).

Fixed in `gravelight/maps/map_root.gd`: wait until the map answers with a real point (10 s at most, then place
nothing), never take the origin or a point off the navmesh, and lay each pickup on the floor under its point (the
navmesh floats 0.3 m over the floor). Checked headless: three runs gave pickups spread over the map at floor height.
`smoke_map00` now checks them (three or more, on the navmesh, apart, none in the corner).

Not changed: the points are uniform over the whole navmesh inside a zone, so most pickups land out on the grounds
(the navmesh's area is mostly outdoors). That is what the code always asked for; whether the owner wants them
indoors more often is a design call.

## Calls I made

1. **Flush for 16 spots, not only the taproom's.** The lead's brief asked for every spot to be on a wall or in a
   niche; with the old rows gone the same metre of floor behind a cabinet read as "dumped" in the vaults as well (the
   frames). yard_west keeps the walk (reason in the table).
2. **The fine print goes on the cabinet's side on a flush spot** rather than being unreadable against the wall. The
   Fine Print quest needs every panel readable whichever spot the deal picks. See the open item about Peg's line.
3. **The taproom's spot stays in the taproom** (one spot in the start room, as before), in the corner: it faces
   south down the west walk, 2.4 m from the Kar98k's chalk, clear of the clock and the photograph, the walk to the
   Old Cellar door and the service walk's mouth.
4. **old_vault_south keeps its id** on its new wall, so pinned seeds (smokes, `--perk-seed`) deal as before.
5. **Lanterns only.** No sourceless fill and no ambient change: each room got a second lantern you can see, and the
   existing ones a longer reach and a steady flame.
6. **Story item heights and yaws were left alone** except the drawing's 7 cm (clear of the rail).

## Files

- Generator and scene: `gravelight/tools_src/gen_map00.gd` (`PERK_SPOTS`, `PERK_FLUSH_GAP`, `PERK_SIDE`, `ROOM_DOORS`,
  `DEEP_LAMPS`, `BAY_LAMPS`, `_spot_boxes` / `_spot_problems` / `_audit_perk_spots` / `_survey_perk_spots` with the
  flush side, the swing boxes, `GL_PERK_PROBE`), `gravelight/maps/map00_crossroads/map00.tscn` (regenerated).
- Runtime: `gravelight/world/perk_spot.gd`, `perk_layout.gd`, `perk_machine.gd`; `gravelight/maps/map_root.gd`.
- Data: `data/gravelight/story_props.json` (two rows), `data/maps/map00_crossroads/*` (rebaked under WSL: 4 floors,
  9 zones, 41 POIs), `data/gravelight/capture_cams.json` (set `u19_fixes`, before `u18_text`).
- Tools: new `gravelight/tools_src/story_prop_mount.gd`, `tools/tests/test_story_prop_mounts.gd`.
- Tests: `test_perk_layout.gd` (flush spots have their wall behind and their side open; a flush spot stands things
  back and turns the fine print), `test_map00_cellar_bay.gd` (the rooms are readable before the lever),
  `test_story_props.gd` (Map 0's items are on their surfaces; the checker), `test_map00_art.gd` (navmesh
  fingerprints `439b8989...` / `e02f577c...`), `smoke_map00.gd` (Intel), `smoke_map00_cellar_bay.gd` (a machine
  stands on its spot's stand transform).
- Docs: `docs/gravelight/MAPS.md`, this note, `docs/captures/u19_fixes/`.

## Renders (looked at)

Forward+, not the Compatibility renderer of `tools/wsl_godot.sh`: Vulkan on lavapipe under WSL Xvfb, invisible:

```
wsl.exe -e bash -lc "cd <repo> && xvfb-run -a -s '-screen 0 1920x1080x24' <godot linux> --rendering-driver vulkan \
  --audio-driver Dummy --resolution 960x540 --path . res://tools_src/capture.tscn -- --set=u19_fixes --label=after \
  --perk-seed=251 --out=<dir>"
```

About 50 minutes for the 45 cameras (6 to 8 minutes to load, then roughly a frame a minute). The before set is the
same command on master's scene.

- `docs/captures/u19_fixes/pairs/` (27 JPGs, before on the left, the same camera): the taproom's corner from the
  owner's angle and two others (`tap_nook_*`: the crate out in the walk with the violet light behind it; the crate in
  the corner, no light), the drawing from the stair head and from the side (`hall_drawing*`: in the air; on the wall
  over the wainscot), the guest room (`guest_room_*`: the cabinet mid-room by the door's leaf; on the wall), the
  three rooms before the lever (`lager_*_unlit`, `dynamo_*_unlit`, `bay_unlit`, with a zombie in each new room), the
  same lit (`*_lit`), and the references (`tap_ref_*`, `vault_*`, `oldcellar_unlit`).
- `docs/captures/u19_fixes/after/` (18 JPGs): every perk spot from its front and the fine print's side
  (`spot_<id>`; the inn's rooms in their own light, the cellars and the outdoors under the work light), and the
  corner's floor (`tap_nook_floor`). Seed 251: crates on taproom_nook, guest_hall, yard_west, behind_stable and bay.
- The scene was regenerated once more after these frames (the saved machine positions to the millimetre): nothing
  drawn moved and no light changed.
- What they do not show: a real GPU. lavapipe renders the same Forward+ passes, but the capture runs on a new
  profile's graphics settings, at 960 x 540, and the frames are 8-bit screenshots: the numbers above compare before
  with after and room with room; they are not what the owner's monitor shows.

## Verification

Headless on this PC, one Godot at a time; logs in `.smoke_logs/u19_fixes/` (not committed).

- **check_scripts:** 953 scripts, 0 failed.
- **Generator:** `PERKSPOT_AUDIT` 17 clear (16 flush, 1 walk), `WALLBUY_AUDIT` clear, navmesh 1275 polygons (breach
  open 1329), 634 collision boxes. Two regenerations of the final table gave the same navmesh fingerprints.
- **GUT, full suite:** first run on the regenerated map: 2370 tests, 2367 passing, 2 failing, 1 risky (the known
  "did not assert"). The two were mine and are fixed: `test_mapdata` (the POI signature: a machine stood back on a
  flush spot was saved at 0.85 - 0.3, a hair under 0.55, and hashed differently from the mapdata it reads back; saved
  positions are to the millimetre now) and `test_map00_t238` (the strip behind the vault's old east row is the
  vault_east spot's own floor now). Final run on the branch's head: **2370 tests, 2369 passing, 0 failing, 1 risky** (the known one; master: 2366 / 2365 / 1, plus four new tests).
- **Area tests on their own:** `test_perk_layout` 11/11, `test_map00_cellar_bay` 13/13, `test_map00_art` 8/8,
  `test_map00_t238` 6/6, `test_story_props` 7/7, `test_mapdata` 11/11.
- **Facing tool** (`tools/tests/test_interactable_facing.gd -- --maps=map00 --report-only`): PASS, 65 interactables,
  0 backwards, 0 sideways, 0 unreachable, 2 UNSURE (yard_east's machine: the rail fence behind it; the guest-bed
  crate as before).
- **Mount tool** (`tools/tests/test_story_prop_mounts.gd -- --maps=map00`): 16 items, 0 off their surface (4 before:
  the drawing, the letter, and the two slips now listed as open furniture).
- **Minimap:** rebaked under WSL Xvfb, RESULT PASS, 4 floors, 9 zones, 41 POIs.
- **Smokes** (final pass on the branch's head, after every code change):

| Smoke | Final pass | All runs on this branch |
|---|---|---|
| smoke_map00 (now also checks the Intel pickups) | PASS | 1 FAIL (my new check's tolerance, corrected), then 2 PASS |
| smoke_map00_alive | PASS | 2 of 2 |
| smoke_map00_cellar_bay | PASS | 2 of 2 |
| smoke_map00_loop | PASS | 2 of 2 |
| smoke_coop | PASS | 2 of 2 |
| smoke_bots | PASS | 2 of 2 (655 s, 651 s) |
| smoke_jakub | **FAIL** (1 check of its run: "he kills the zombie with the coal shovel") | that check: 2 PASS, 3 FAIL over five runs; master's content 2 PASS. See below: a relief squad takes the breakout zombie |
| smoke_sherman | PASS | 3 of 4 (the known one-in-four) |
| smoke_bots_shop, smoke_bots_u10 | not rerun | 1 of 1 each (before the approach-point fix) |
| smoke_bots_shop_m0 | not in the final pass | 1 of 6, see below |

- **Earlier runs of the same smokes, and what they found:**
  - `smoke_map00` failed once on my own new Intel check (it wanted a pickup within 0.3 m of the navmesh in every
    direction; a pickup lies on the floor 0.3 to 0.5 m under it). Check corrected; PASS since.
  - `smoke_sherman` failed once of four runs with the two checks T-251's note lists as its one-in-four failure
    ("the 75 mm fires on them (0 shells, 0 kills)", "nothing on the players"); PASS on the two reruns and the final.
  - `smoke_bots_shop_m0` (not in the brief's list; `smoke_bots` as a filter runs it): **fails more often than it
    passes, on master as well.** Mine: 1 pass in 6 runs. Master's content (4a527f4f, checked out into this worktree
    for the runs, then restored): 1 pass in 4. Three causes, two of them master's:
    1. *mine, fixed:* a 0.6 m cabinet stood back on a flush spot had the bots' approach point on the edge of the
       navmesh (section 1); the companion stood 500 s in front of Second Wind on the stable's spot.
       `PerkMachine.set_stand_back`; the approach point is 0.00 m off the navmesh on every spot and depth now.
    2. *master's:* **a bot sent to a machine on another floor walks to the place under or over it and stands there.**
       With the deal pinned (`--perk-seed=991832019`) the companion, coming from the Crucible, stands in the
       Lagering Vault at (28.6, -3.2, 31.7) under Ironhide Stout on the behind_stable spot for the rest of the
       phase; on master's content with the same seed she stands at (29.4, -3.2, 32.7) under T-251's place for it.
       In another run she stood 160 s at "drink Hawkeye Brandy" (dealt to old_vault_south), 7.0 m from the human in the taproom: that distance fits the taproom floor over the machine, not the vault (not confirmed: that run did not print positions yet). T-251's fix (call 11) covers a shut
       door only. This is bot movement code (`BotTasks.walk_to` / the locomotion's arrival), which this job may
       not touch.
    3. *master's:* "no squad bot did 'bench'": since the machines are dealt all over the map the squad spends on
       tonics and the Crucible first and the bench only comes when a bot has bought a gun with parts to fit; in a
       300 s phase that is one run in three or four (2 of 3 unpinned runs on master's content failed on it).
    `smoke_bots_shop.gd`'s companion note now prints where she stands and where the thing she is sent to is.
  - `smoke_jakub`: **one check fails on this branch whenever round 5 is a normal round** ("he kills the zombie with
    the coal shovel"; every other check of the run passes, Jakub joins and arms as he should). Five runs here
    (two full; three counted only up to the breakout: two cut off there, and one whose later half ran while I had
    master's files checked out for a baseline, my mistake): the check passed in the two whose round 5 was the
    eight-zombie special round and failed in the three normal rounds. Master's content (two runs, the second cut off
    after the breakout) and the lead's log: passed in one special round and two normal rounds. Traced (a temporary print in `JakubCompanion._tick_breakout`, removed
    again): the breakout zombie rises in the field north of the inn in TO_WINDOW for the coal window and then walks
    off east instead of going down the light well; the cage bursts on the 30 s timeout and Jakub steps out with
    nobody to hit. The code that does that is `ReliefSquad._hand_out_prey` (master's): a zombie in CHASE or
    TO_WINDOW within 18 m of an allied soldier is given that soldier as prey and its window is released; the
    breakout zombie's `forced_target` does not exempt it, the smoke's cull spares only that zombie (so it is the
    one a soldier gets), and a squad holds round the human, who stands in the taproom 17 m from that field. A
    relief squad was on the map in all three failing runs (in from the south-west, the south and the north-east);
    in master's two passing normal rounds the squad had come in from the same south-east edge spawn (64.5, 46).
    So I read it as the edge-spawn lottery of a race that master has, **but I have not seen it fail on master**:
    0 of 3 normal rounds here against 2 of 2 there is not proof of innocence, and the lead should rerun it at
    merge. Nothing of this branch touches the squads, the zombies, the windows or Jakub. A one-line guard
    (`z2.forced_target != null` in `_hand_out_prey`) would end the race; that file is squad / zombie AI and not
    this job's.
- **Not run:** the other maps' smokes (nothing of theirs changed but `MapRoot._spawn_intel`, which `check_scripts`
  and the unit suite load), `smoke_marks` (fails on master: "an empty spot: collect, go"), a rendered run on the
  owner's GPU.

## At merge

- `gen_map00.gd` and `map00.tscn` are this branch's again. If another branch's hunk lands in the generator,
  regenerate once: `PERKSPOT_AUDIT` must print 17 clear (16 `flush`, 1 `walk`) and the fingerprints in
  `test_map00_art` must not move.
- `data/maps/map00_crossroads/*` was rebaked under WSL after the regeneration (the perk POIs and the footprint
  squares moved). If the scene is regenerated again with other positions, rebake:
  `tools/wsl_godot.sh --path . res://tools_src/bake_minimap.tscn -- --map=map00_crossroads`.
- `map_root.gd` (the Intel wait) is every map's: the movement / performance branch may touch the same file; the hunk
  is `_spawn_intel` only.
- `capture_cams.json`: the `u19_fixes` set is inserted before `u18_text`.

## Open items

1. **Peg's Map 4 line** ("The terms are on the back of the machines. They were always on the back", VO_SCRIPT
   PEG_M4D_COLUMN_01) is no longer literally true on Map 0, where sixteen cabinets carry them on the side. Other maps
   keep the back. If the owner wants the back everywhere, the alternative is a spot that stands a walk out again
   (drop the flag and move it a metre: one line a spot).
2. **guest_hall** stands 0.22 m off its wall, not 0.1: an Exterior mesh's bounding box reaches 0.1 m into the hall
   there (a sloped piece of the taproom's roof, most likely), and the audit keeps the machine's box out of it.
3. **yard_west** is the one spot with the walk behind it.
4. **yard_east** reports UNSURE in the facing tool (not a failure): the fence behind it is rails, so the tool sees as
   much open ground behind it as in front. The guest-bed crate's UNSURE is as before.
5. **The other maps' story items** (section 2) and **where random Intel lands** (section 4).
6. The look on the owner's GPU: brightness was judged on software Forward+ frames only.
7. The filler crate and a 0.6 m cabinet stand on the same back line; the deepest machine (the barrel) fills the
   spot. Nothing else about the deal, the prices, the doors or the spawns changed.
