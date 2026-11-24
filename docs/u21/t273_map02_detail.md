# T-273: Totenhafen's map detail pass (the geometry step)

The owner, 2026-11-24: "go through and look at all the maps and apply a level of detail that you see that we have in
the first map ... there's level design, there's things that happen throughout the rounds."

Branch `claude/detail-map02`. Map 2 is generated: `gravelight/tools_src/gen_map02.gd` (+ `detail_map02.gd`), data in
`data/gravelight/map02.json`. Regenerate headless:

    "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map02.gd

Coordinates are map space, metres, `[x, y, z]` (+X east, +Z south, the sea north of the quay at z < 0).

## 1. The raid's landmark: the patrol boat V 1507

| What | Where | Verified by |
|---|---|---|
| A Vorpostenboot (a requisitioned steam trawler in navy grey), 34 m, moored to two buoys | waterline amidships `[16, -2, -20]`, bow west (yaw 90), port side and number to the quay; 16.5 m off the parapet at its nearest | test_map02_detail (on the scene: its meshes in the quay's batch group, the target on it, nothing of it over the shingle); renders |
| `stuka_target` | `[17.0, 1.7, -20.0]`, the wheelhouse; `stuka_from [40, 0, -420]` (down out of the north, over the sea the quay looks at) | smoke_map_detail: the bomb lands at `(17.0, 1.7, -20.0)` |
| The fire the bomb starts | `MooredHullFire` (flames on the bridge, the forecastle and the waist, smoke, one light without a shadow), hidden until the hit; `stuka_hit_show` | smoke: hidden before, shown after the hit; render `02_boat_fire_night` |
| Its own banner and lines | stuka `banner_small` "A DIVE BOMBER IS COMING DOWN ON THE PATROL BOAT"; raid `vo_warn` `OPR_RAID_M2_WARN_01` (the pens, not Map 0's cellars), `vo_clear` `OPR_RAID_M2_CLEAR_01` (`vo_during` was already the map's) | test_map02_detail; smoke banners |
| The bursts on the quay | raid `burst`: stone and a little snow (Map 0's yard keeps snow and earth) | test_map02_detail (the kinds are Effects' own) |

Built in `DetailMap02.patrol_boat`: a lofted steel hull (raised forecastle with a sloped break, a cruiser stern and
its transom, red below the boot-top), inner bulwarks and cap, the decks, the bridge house, the wheelhouse with windows
and wings, a searchlight, the raked funnel with its black top, two masts with stays, shrouds and the aerial, an 8.8 cm
in its tub on the forecastle, a 2 cm on the stern, the fish hold's coaming, a winch, depth-charge rails, the ship's boat
on its davits (over the sea side), the hull number on both bows, riding lamps (emissive only), the anchor cable, two
buoys and their lines, snow on the decks. No collider: nobody reaches it (the parapet and the stages' kerb rails hold
the quay). The bomb hurts within 6.5 m; the nearest ground anyone stands on is 16.5 m off.

Script changes, data-driven, defaults unchanged:
- `sherman_event.gd`: `stuka_hit_show` (names of hidden nodes shown where the dive bomber's bomb lands, on every
  peer: it runs before the puppet's early return). `show_hit_nodes()` is also a capture `call:` verb. Map 0 and
  Kaltenbrunn do not set it.
- `air_raid.gd`: `burst_fx(..., kinds)` takes the raid table's `burst` rows (`[[dirt kind, strength, amount]]`);
  empty is snow and earth, as before. `sherman.json` has no `burst` row (a test holds it).

Cost: the boat is folded to one mesh per material and shadow mode (`GenDetail.merge_children`) and hung in
`StaticBatches/VisGroup_A` (the quay's batch group: the shadow proxies and the view cells already work on it; no new
container). Scene census before / after: meshes 1210 -> 1233 (+23 draw calls where the quay is drawn: 4 hull meshes,
19 folded), triangles 381,361 -> 395,587 (+14,226; in shadow casters +7,906), lights 192 -> 193 (+1, the fire's,
hidden until round 30, no shadow), shadowed lights 22 (unchanged), collision shapes unchanged.

Renders (WSL + Xvfb, Compatibility renderer, 1280x720), looked at: `docs/captures/t273/00_boat_night` ..
`04_boat_stage_noon`. At night the boat is a silhouette with its riding lamps against the sky; at noon the grey hull,
the number, the bridge and the funnel read from the parapet. Seen and not mine: at noon the storm card on the north
horizon reads as a black band (the T-259 day cycle's), and the Compatibility sea is pale.

## 2. The catwalk ladders and the signal balcony's zip line

| What | Where | Verified by |
|---|---|---|
| West catwalk ladder (iron rungs against the catwalk's edge, stayed to its underside) | foot `[-17.415, 0, 55.5]` on pier 0, head `[-19.0, 4.0, 55.5]`; line `[-17.415, 55.5]` | smoke_ladders: up and down, ends on the navmesh; a zombie on pier 0 came up it to a player on the catwalk in 9 s |
| North catwalk ladder | foot `[15.0, 0, 35.585]` on the north apron, head `[15.0, 4.0, 34.0]` | smoke_ladders |
| East catwalk ladder | foot `[49.415, 0, 72.0]` on the east apron, head `[51.0, 4.0, 72.0]` | smoke_ladders |
| The zombies' climb links | `Ladder_CatwalkW/N/E` on the same lines, now ladder links (`line`, `bidirectional`, `drop`: one at a time up the rungs, they drop back down) | test_map02_detail, smoke_ladders |
| The signal balcony | a grated platform x 46.8..50.4, z 38.15..40.65, 7 m up, outside a new door (x 47.6..49.6) in the signal tower's south wall; the window beside it is shorter (x 44..46.8). Rails on its three open sides; zone `G_SIGNAL` (a new zone box), a nav link through the door | test_map02_detail (balcony on the baked navmesh, in G_SIGNAL); smoke_ladders |
| `SignalZip` | anchor `[48.6, 9.0, 40.8]` (2 m over the balcony, a step outside its south rail), cable to its post at `[40.0, 0, 49.6]` (2.75 m), set down at `[40.629, 0, 48.956]` on the east apron between the pump stair and the crane office: 12.3 m, 27 degrees, speed cap 7.5 m/s, a 3.2 s ride | smoke_ladders: nothing in a hanging rider's way, the bar reached from the balcony, the ride, the landing on the navmesh, the rider stands free; test_map02_detail: the slope, the brake, the set-down, the spawns (none within 3.5 m) and the tide's live cable (4.7 m off) |

Choices:
- **Doors.** The line lands in the Pen Hall; the tower is reached only through the Pen Hall (its door costs 2500 and
  wants the power), so the line skips nothing and has no chain.
- **Rails closed.** As on Map 0's tower (T-268) the catwalks' and the balcony's rails stay closed; the climb carries
  a body over them.
- **Moved links.** `Ladder_CatwalkE` sat at z 60, the foot of the east stair: it is at z 72 now, where the ladder is
  drawn. `Ladder_CatwalkN` x 17 -> 15 and `Ladder_CatwalkW` z 60 -> 55.5: the tide's catwalk spawns stand at
  `(20, 4, 34)` and `(-19, 4, 60)` (the old west head itself); every head is 4 m or more from a spawn now.
- **One zip line, not two.** A line from a 4 m catwalk is 6.7 m long at 26 degrees: not worth a post. The balcony is
  the only 7 m floor with open hall below it.
- **The shelves** in the signal room moved west off the new door (`_dress_tower`).

Cost (scene census, after item 1 -> after item 2): meshes 1233 -> 1241 (+8), triangles 395,587 -> 403,555 (+7,968;
in shadow casters +6,468), lights unchanged (the post and arm lamps are emissive only), collision shapes 1288 ->
1295 (+7: the balcony floor, three rails, the post, the wall's new pieces). The navmesh changed only in the signal
tower (the door, the balcony) and under the new zip post.

Renders, looked at: `docs/captures/t273/05_ladder_n_night` .. `12_ladder_w_noon` (each ladder from its floor, the
balcony from the landing, down the line from the balcony, the door from inside the signal room).

## 3. The perk deal on Totenhafen

`perk_layout.json` has a `map02` row (the seven: Second Wind, Marathon Malt, Ironhide Stout, Trigger Tonic, Overclock
Cordial, Hawkeye Brandy, Ledger Lager) and the scene twelve `PerkSpot` nodes (gen_map02 `PERK_SPOTS`); `PerkLayout`
deals the seven onto them at every match start from the match seed, the spots left over show their filler crate. The
scene is saved with the seed-0 deal (Second Wind in the cannery by its pen passage, Ironhide in the signal room,
Overclock on pier 0, Ledger Lager and Hawkeye in the workshop, Trigger in the cannery, Marathon on the quay).

| Spot | Zone | Floor point, yaw | Flags | From |
|---|---|---|---|---|
| infirmary | B_CANNERY | `[-26, 0, 0.9]`, 180 | near | Second Wind's old place |
| cannery_passage | B_CANNERY | `[-5, 0, 29.3]`, 0 | near | Marathon's old place |
| cannery_north | B_CANNERY | `[-7, 0, 0.86]`, 180 | near, flush +1 | new: the north wall east of the conveyor's end |
| workshop_west | C_WORKSHOP | `[32.8, 0, 8]`, -90 | near | Ironhide's old place |
| workshop_north | C_WORKSHOP | `[40, 0, 0.8]`, 180 | near | Trigger's old place |
| workshop_lathe | C_WORKSHOP | `[57.5, 0, 0.86]`, 180 | near, flush +1 | new: the north wall over the lathe |
| signal_west | G_SIGNAL | `[42.9, 7, 36.7]`, -90 | | Overclock's old place |
| signal_east | G_SIGNAL | `[51.4, 7, 36.3]`, 90 | | Hawkeye's old place |
| crane_office | D_PENHALL | `[43.6, 0, 56.1]`, 90 | | Ledger Lager's old place (T-141) |
| north_apron | D_PENHALL | `[18, 0, 33.72]`, 180 | flush -1 | new: the bunker face under the north catwalk, 3 m east of its ladder |
| pier0_wall | D_PENHALL | `[-19.14, 0, 74]`, -90 | flush +1 | new: the hall's west wall on pier 0, under the west catwalk |
| quay_cannery_wall | A_QUAY | `[0.86, 0, 9]`, -90 | start, outdoor, flush -1 | new: the cannery's outside wall on the quay, north of its door |

The rules are perk_layout.json's (at most two machines in a zone; the quay takes only a weather-safe cabinet up to
2000, never Second Wind; Second Wind only one bought door from the quay, the cannery or the workshop). The new five
were found with `locker_spot.gd`'s wall scan (the wall behind a 1.8 m body, no collider in front, no navmesh under it,
6 m of room, nothing within 1.6 m) and get a 1.8 x 1.2 m footprint baked out of the navmesh (`NavBlock_PerkSpot_*`,
bake only); the seven old places keep the footprints their machines had. Every spot is 4 m or more from the ammo
boxes and the Crucible. test_map02_detail: the table and the scene agree, each spot stands in its zone with no
navmesh under it and its front on the navmesh, the scene holds the seed-0 deal, 300 seeds all deal the seven within
the rules and every spot is used by some seed. The minimap was rebaked (WSL): its POIs follow the seed-0 deal
(test_mapdata), the balcony is on the tower's floor image.

Known: the old seven places were sized for their own machine, not the deepest; the Ironhide barrel (1.2 m deep) on
`signal_east` or `crane_office` stands about 0.15 m into the wall behind it (drawing only; its collider overlaps the
wall). The bot planner's Totenhafen plan names perks by id and walks to wherever they stand.

## 4. Reactive props

Built at load under `Reactive` (gen_map02 `build_reactive`), Map 0's scripts: seven drips (the lower pens' slab x3,
U-1047's deckhead x2, the two pen passages); three doors left ajar (`SwingDoor`: the cannery infirmary's east and
south doors, the harbourmaster's hut's door; whoever comes through swings the leaf, it never collides); the infirmary
window's two curtains in the draught from `W_B_N` (they billow harder as its boards come off); glassware that breaks
when shot on the hut's desk and on the signal room's chart table (`ShatterSet`). Nothing collides, nothing changes the
navmesh, nothing casts a shadow. Paper (`PaperDecor`) left out: its kinds are Map 0's (the inn's December calendar,
the patrol's map, the cousins' drawings).

## 5. Not built in the first pass: the round-1 opening and the survivors (both built after the merge: sections 6 and 7)

Left for a later pass (the run's time went to items 1 to 4 and their checks). What each needs, from reading
`inn_opening.gd` / `inn_survivors.gd` (both already take any map: `data/gravelight/map02_opening.json` /
`map02_survivors.json`, `"map": "map02_totenhafen"`):
- **Survivors in the torpedo store** (the smaller job): `reveal_door` `door_workshop`; two or three sailors hidden in
  the warhead cage (x 52..62, z 16..24; its gap at x 52, z 19..21; keep clear of the crate spot `Warheads` at
  `(58.6, 0, 19)` and the lead coffins), posts in the workshop facing its windows (`W_C_E1/E2`, `W_C_N`); an `arm`
  row (a gun and a price); the `ally` numbers can be Map 0's. Each survivor needs nine text lines in `lines.json`
  (reveal, scared x2, flinch, armed, fight, hurt, downed, death: the "SURV_*" categories), an `audio_manifest.json`
  "missing" row for each, a speaker code and probably a `people.json` look; then an `InnSurvivors` node under
  Gameplay (gen_map02) and a smoke like `smoke_inn_survivors` for the map.
- **The opening (dockworkers flee the cannery)**: the players start on the quay, the cannery is behind a 1000 door.
  An `InnFrontDoor` is a doorway the generator fills with an invisible collider until it is unbarred: a second
  doorway from the cannery onto the quay would skip the paid door unless it is barred again for good after round 1
  (the script re-bars at `bar_at`, which fits). The patrons' routes would run out of that door, across the quay and
  down the surf steps at the parapet's ends (both steps are already ground spawns' heads: `(2, 0, 2)`,
  `(31, 0, 1.6)`), with `attackers` rising there; a `flare.light` (the quay's brazier) and the title card. The tide
  is not touched by either (round 1 is before its `min_round` 3).
- **The optional U-boat surfacing** (a round event of the map's own with `uboat_sail.gd` and the drowned / Kielholer
  kinds): not started.

## Cost, all of it (scene census, master -> this branch)

Every MeshInstance3D / Light3D / CollisionShape3D in `map02.tscn`: meshes 1210 -> 1241 (+31 draw calls at most: 23
for the boat where the quay is drawn, 8 in the hall), triangles 381,361 -> 403,567 (+22,206; in shadow casters
+14,374), lights 192 -> 193 (+1: the boat's fire light, hidden until round 30's bomb, no shadow), shadowed lights 22
(unchanged), collision shapes 1288 -> 1300 (+12: the balcony and its rails, the zip post, the tower wall's new
pieces, five perk footprints that are bake-only and switched off at runtime). Everything new batches into
`StaticBatches` (the boat into `VisGroup_A`, the hall pieces by their boxes) except the hull's four lofted meshes,
which are in `VisGroup_A` too. The reactive props are scripts built at load (idle when nobody is near), no lights.
`perf_marks` was not run (it opens a rendered window); the census is the headless count.

## Results (headless, this PC, 2026-11-24)

- `check_scripts`: 0 failed.
- Full GUT: 2599 tests, 2598 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised`).
  New: `test_map02_detail` (10 tests). Changed: `test_map_detail` (Totenhafen has a dive bomber now; a raid
  landmark may stand outside every zone, out on the water).
- Smokes, all PASS with 0 script errors: `smoke_map_detail` (155 checks), `smoke_ladders` (twice), `smoke_coop`,
  `smoke_sherman` (74), `smoke_weapon_locker`, `smoke_map02`, `smoke_map02_art`, `smoke_map02_world`,
  `smoke_ammo_box`, `smoke_bank`, `smoke_bots_u10`, `smoke_lf_start`.
- Minimap rebaked under WSL (`bake_minimap --map=map02_totenhafen`), PNGs imported; `test_mapdata` passes.
- Not run: the other bot smokes, `smoke_campaign`, `smoke_kielholer`, `smoke_undertow`, `smoke_horse_boss`,
  `perf_marks`.

## Not verified

- Seen only through the software Compatibility renderer (WSL + Xvfb). The boat at night is a silhouette with riding
  lamps; its fire, the balcony's lamps and the ladders want a look on a real GPU.
- The raid's new lines have no voice (subtitle with a timed silence until a bake).
- Co-op: the boat's fire shows on every peer from the mirrored dive (the show runs before the puppet's return); not run
  on two machines. A client joining after round 30 does not see the fire.
- The perk deal's live run on Totenhafen (a match with PerkLayout dealing from a random seed, buying at a dealt
  machine) is covered by the smokes that load the map with a match (smoke_map02, smoke_bank found Ledger Lager
  wherever it stood), not by a dedicated smoke like Map 0's `smoke_map00_cellar_bay`.
- Bots: the Totenhafen plan buys perks by id; when the deal puts Ironhide in the signal tower the plan's order
  (Ironhide right after the workshop door) waits on the tower; smoke_bots_u10 passed, a long solo-bot run on many
  seeds was not made.

## For DECISIONS.md (the main session writes it at the merge)

**T-273: Totenhafen's map detail pass (the geometry step).** Branch `claude/detail-map02`, notes
`docs/u21/t273_map02_detail.md`, renders `docs/captures/t273/`. Round 30's raid opens with a dive bomber after all:
its landmark is the patrol boat V 1507 (a Vorpostenboot, `DetailMap02.patrol_boat`) moored 20 m off the parapet,
`stuka_target` its wheelhouse, its fire shown at the hit (`ShermanEvent.stuka_hit_show`), the raid's own banner and
Operator lines (`OPR_RAID_M2_WARN_01` / `_CLEAR_01`, not Map 0's cellars), a stone burst on the concrete quay
(`AirRaid.burst_fx` kinds; defaults unchanged for Map 0 and Kaltenbrunn). Drawn ladders at the three catwalk climb
links with the players' LadderClimbs on the zombies' lines (now ladder links: one at a time, they drop back down;
the east link moved off the east stair's foot to z 72, the north to x 15 and the west to z 55.5, clear of the tide's
catwalk spawns). A signal balcony outside a new door in the tower's south wall and one zip line from it, 12.3 m at 27
degrees down to the east apron (no chain: it lands in the Pen Hall the tower is reached through); a second line from
a 4 m catwalk was not worth a post. The perk deal on Totenhafen: twelve spots for the seven machines (the seven old
places and five new wall spots found with locker_spot's scan), `perk_layout.json` `map02`, the scene saved with the
seed-0 deal, the minimap rebaked. Reactive props built at load: drips, three doors left ajar, the infirmary's
curtains, glassware that breaks. Not built: the round-1 opening (dockworkers flee the cannery), the sailors in the
torpedo store and the optional U-boat surfacing (what each needs is in the notes). Cost: +31 meshes at most, +22 k
triangles, one hidden unshadowed light.

## 6. Added after the merge: the sailors in the torpedo store

`data/gravelight/map02_survivors.json` and an `InnSurvivors` node under Gameplay (gen_map02); no script changed.
Two of U-1047's crew, Obermaschinist Hinrich Kahlke (`KAH`) and Matrosengefreiter Jonas Pietsch (`PIE`), shut
themselves into the warhead cage in the Torpedo Workshop's south-east corner when the boat's crew turned. Hidden until
the workshop's door (`door_workshop`, 1000, off the quay) opens; then crouched in the cage: hide spots `[53.5, 0, 17.4]`
and `[55.8, 0, 17.3]` (clear of the Warheads crate spot and the lead coffins). Arming one costs 1000 (a Kar98k); they
walk out of the cage's gap to posts `[50.5, 0, 19.0]` (facing the cradles and the north window) and `[50.5, 0, 22.0]`
(facing the workshop's door). Map 0's ally numbers. They rise as the `sailor` kind. Nine text lines each
(`KAH_SURV_*`, `PIE_SURV_*`) and the squad's warning in a category of this map's (`M2_SURV_TURN`: Map 0's says
"upstairs"), 22 lines in all, every one listed as not baked in `audio_manifest.json` (a subtitle with a timed
silence); both cast in `voice_cast.json` (German accent, for a later bake). Their bodies are the project's modelled people
(`person` in each row, reused the way `people_extra.json` reuses them: Kahlke wears Ammer's, Pietsch the
Obergefreiter's; neither is anyone else on Totenhafen); the walk from the cage asks the workshop's navigation layer
(`nav_layers` 4).

Verified: `smoke_map02_survivors` (new, Map 0's survivor smoke on this map) PASS: hidden before the door, spots and
posts on the navmesh, nothing solid on them; the door reveals them cowering with the arm prompt; Pietsch's reveal
line; a shot makes one flinch; a zombie in the cage killed Kahlke, who warned and rose as a zombie; Pietsch armed for
1000, walked to his post (0.0 m off) and hit a zombie in the workshop; downed at 0 hp and helped up.
`test_map02_detail.test_the_sailors_in_the_torpedo_store`. Cost: nothing drawn until the door opens; two procedural
bodies after.

## 7. Added after the merge: the round-1 opening, "the night shift runs"

`data/gravelight/map02_opening.json`, and in gen_map02 a side door in the cannery's east wall onto the quay
(`SIDE_DOOR_Z` 2.6: x 0, z 1.8..3.4, a frame and a "NACHTSCHICHT" sign on the quay face), its leaf and bar
(`InnFrontDoor` "CannerySideDoor", the bar on the cannery's side) and an `InnOpening` node.

**The 1000 door is never skipped.** The doorway is filled for good with an invisible collider
(`CannerySideDoorBlock`, baked into the navmesh like the wall it replaces). The opening's patrons have no colliders and
pass through; nobody else ever does, before, during or after the opening. The leaf swings shut behind them and is
never barred again (`bar_at` past `end_by`: nobody is left inside to drop the bar). The navmesh and the POIs are
unchanged (no minimap rebake needed).

The beats: three of the cannery's night shift (Hein Boldt the foreman, Ole Rahn a stevedore, Anni Tews a packer) are
heard through the side door before round 1 (three intro lines: the cold, the Hafenmeister's pallet, "somebody
singing under the water" out by the pens); the look gate waits for the player to face the door (7 to 9.5 s); the
pounding at the windows and the door and Rahn's "What was that?" are the cue; round 1 starts. Boldt unbars the door and
holds it; Rahn and Tews run out for the sea stairs at the parapet's west end. Two of the dead rise on the quay by the
stairs' head (`[2.2, 0, 2.2]`, `[3.6, 0, 1.6]`): one catches Rahn two steps out of the door, the other Boldt as he
comes out last; both fall and rise as dockworkers on the quay. Tews gets down the stairs and away west along the beach
under the cannery's wall. Round accounting is Map 0's: 4 of round 1's slots (two risers, two attackers). No title card
(Map 2 is never a campaign's first map; a campaign arrival cancels the opening), no flare (no hearth on a quay). Eight
text lines (`BOL_/TEW_/RAH_M2_OPEN_*`, not baked), the three cast in `voice_cast.json`.

Script change (shared, data-driven, default unchanged): `inn_opening.gd` `front_door.face_door`: a patron working the
door faces the door node (Totenhafen's door is in an east wall); without it, north, as on Map 0. A test holds that
Map 0's file does not set it.

Verified: `smoke_map02_opening` (new) PASS, 20 checks: the file found by the map's id, three patrons in the cannery,
the door shut and barred, the doorway's collider; the intro lines and the cue before round 1, round 1 at 11.1 s (not
before look.min_seconds), four slots taken; the door unbarred and opened; a player body pushed west into the open
doorway from the quay stopped at x 0.50 (the wall's face is at 0.15: never inside); Tews escaped, Boldt and Rahn rose
on the quay, both attackers rose, the leaf shut. `test_map02_detail.test_the_night_shift_opening`. The tide is not
touched (round 1 is before its `min_round` 3).

## Results of the addition (headless, this PC, 2026-11-24)

- Smokes, all PASS with 0 script errors: `smoke_map02_survivors` (new; twice after one fix in the smoke: with two
  sailors, not Map 0's three, the zombie in the cage took the second one before the smoke could arm him, so the smoke
  now puts its zombie down once the first falls), `smoke_map02_opening` (new, twice), `smoke_map02`,
  `smoke_map02_art`, `smoke_map02_world`, `smoke_map_detail` (155), `smoke_coop`, and Map 0's `smoke_map00_alive`,
  `smoke_inn_survivors`, `smoke_inn_opening_paths` (7 cases: the opening change keeps Map 0's).
- `test_map02_detail` 12 tests; `test_inn_survivors`, `test_vo`, `test_mapdata` pass. Full GUT and check_scripts:
  see the report.
- Not seen in motion: a capture holds the rounds, so the opening's run was not rendered (`19_side_door_night` shows
  the shut door, its frame and sign). The sailors cowering in the cage were (`18_survivors_night`).
- The patrons and the sailors wear the project's modelled people (`person`: Boldt Rother's, Rahn Sobotta's, Tews
  Agnes Pohl's, Kahlke Ammer's, Pietsch the Obergefreiter's; none of them is anyone else on Totenhafen), and when
  they rise the same body rises. Rendered and looked at: `18_survivors_night` (the two crouched in the cage),
  `20_night_shift_night` (the three by the conveyor before round 1).
- The opening's patrons duck through the surf steps' chain at the parapet's west end (they have no colliders and the
  chain is dressing); not seen.

## For DECISIONS.md: the addition (the main session writes it at the merge)

**T-273 addition: Totenhafen's survivors and round-1 opening.** Branch `claude/detail-map02` (after the T-273 merge),
notes `docs/u21/t273_map02_detail.md` sections 6 and 7. Two of U-1047's crew (Kahlke, Pietsch) hide in the
Torpedo Workshop's warhead cage, revealed by the workshop's door, armed for 1000 (a Kar98k) to hold posts by the cage,
rising as sailors when they fall (`map02_survivors.json`, Map 0's InnSurvivors unchanged). Round 1 opens with the
cannery's night shift running out of a new side door onto the quay (`map02_opening.json`, Map 0's InnOpening): two
caught and risen on the quay, one away down the sea stairs. The side door's doorway is filled for good with an
invisible collider: only the patrons (no colliders) pass, so the cannery's 1000 door is never skipped; the leaf is
never barred again. One shared change, data-driven with Map 0's default kept: `inn_opening.gd`
`front_door.face_door`. 30 new text lines (not baked) and five cast rows. Every survivor and patron wears one of the project's modelled people
(`person`; the risen too). Shared changes (all data-driven, Map 0's defaults kept): `inn_opening.gd`
`front_door.face_door` and `person` for the risen, `inn_survivors.gd` `person`, `inn_survivor.gd` `nav_layers`;
`probe_npc_walls.gd` reads each map's own survivors file. Verified by two new smokes and Map 0's
opening and survivor smokes.

### Follow-up in the addition (the coordinator: real person models; a full GUT run)

Shared changes, all data-driven with Map 0's behaviour unchanged (Map 0's files set none of the keys):
- `inn_opening.gd`, `inn_survivors.gd`: a row's `person` (a people.json id) is the body the risen wear too
  (`warm_risen` / `dress_risen`); without it, the row's id, as before. PatronBody already read `person` for the living.
- `inn_survivor.gd`: the walk to the post asks the survivors file's `nav_layers` (default 1, Map 0's single layer);
  Totenhafen's zones are on their own layers, so the cage-to-post path needs the workshop's.
- `probe_npc_walls.gd` (the tool behind `test_npc_navmesh`): reads the running map's own survivors file (it read Map
  0's on every map) and walks with its `nav_layers`.
- `test_map_detail.test_opening_and_survivors_read_their_file_by_map` no longer lists Totenhafen among the maps
  without the files.
