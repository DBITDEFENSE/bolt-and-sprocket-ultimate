# T-271: the base of the map detail pass

The owner, 2026-11-24: "go through and look at all the maps and apply a level of detail that you see that we have in
the first map ... there's level design, there's things that happen throughout the rounds. That needs to be the case
for the other maps."

Branch `claude/map-detail-base`. This is the foundation: Map 0's match systems switched on for the other six maps
with data rows and small script changes. No generator, no `.tscn`, no navmesh was touched; everything new is built
at load from a json row, like Map 0's locker, rail and bank branch. The geometry work per map (decks, openings,
perk spots) is for the later workers; the list is at the end.

**Nothing here has been seen.** Every check is headless: colliders, the navmesh, zone volumes, the running game's
own rules. "Measured free" is not "looks right".

## What is on now, per map

Coordinates are map space, metres, `[x, y, z]`. "Probe" = `probe_map_site` on the running map, "spot" =
`locker_spot_probe` on the scene file, "smoke" = `smoke_map_detail` (or `smoke_weapon_locker` for the lockers).

### Map 1, Kaltenbrunn

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[12.02, 0, 4.5]` yaw 90: the Armorer's Bench's own wall, 4.3 m along it | spot: wall 9/9, room 6.0 m, nearest machine 2.5 m, no navmesh under it; smoke_weapon_locker: walked to, used, a gun stored and taken |
| Rideable horse, rail, tack chest | horse `[37.65, 0, 19.0]` yaw -90, rail `[38.9, 0, 19.0]`, chest `[38.9, 0, 20.62]`: the Minehead yard's east wall, 6 m from the Rail Yard door. Zones `A_MINEHEAD`, `B_RAILYARD` | probe: floor 0.00, on the navmesh, 2.2 m free; smoke: tied, nothing solid in its body, a wall behind the rail, nearest other thing 6.1 m, path from the spawn (32 m), mounted, ridden 6.1 m in 2.5 s inside its zones, dismounted onto the navmesh, walked home (0.43 m off), Studded Shoes bought for 1500 |
| Round 40: the raid (no tank) | dive bomber on the locomotive `[52.5, 3.0, 33.0]` from the valley (`stuka_from [300, 0, -200]`), then the air raid. Bombs: `A_MINEHEAD`, `B_RAILYARD`, `D_BARRACKS`, `E_LIFT` where there is no roof. Shelter: any roof (the Kaue, the barracks' rooms, the lift house) and the zones `C_ADMIN`, `M_STAIRS`, `F_CHAPEL`, `G_GENERATOR`, `H_LAB`, `I_CORE`. Bots run to `[10, 0, 29]` (the Kaue), `[-6, 0, 25]` (Administration), `[10, 0, 38]` (barracks). Banner: "GET UNDER A ROOF: THE KAUE, THE BARRACKS, THE MINE" | probe: roof over 3 % of the yard (the Kaue), 0 % of the rail yard, 64 % of the barracks, 100 % of the rest; smoke: round 40 reserved, no round held for a tank, the dive bomber flies and its bomb lands on the landmark, the warning, 8 bombs all on open ground in a bomb zone, a player in the Kaue never hurt (2 bombs stopped by its roof), all-clear |

Already there before this task: the undead horses' rounds 20 and 30, the day cycle, the bank branch.

### Map 2, Totenhafen

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[12.0, 0, 17.17]` yaw 0: the Armorer's Bench's wall on the quay, 4.3 m from it | spot: wall 9/9, room 6.0 m, nearest 4.3 m; smoke_weapon_locker |
| Round 30: the raid (no tank, no dive bomber) | bombs: `A_QUAY` and the roofless part of `B_CANNERY`. Shelter: any roof (the quay's hut, the cannery's roofed part) and the zones `C_WORKSHOP`, `D_PENHALL`, `E_UBOAT`, `F_LOWERPENS`, `G_SIGNAL`. Bots run to `[-10, 0, 35]` and `[44, 0, 35]` (inside the two pen hall doors) and `[-5, 0, 25]` (the cannery). Banner: "GET INTO THE PENS" | probe: roof over 4 % of the quay, 63 % of the cannery, 100 % of the rest; smoke: round 30 reserved, the siren at once, 9 bombs all on open ground in a bomb zone, a player in the pen hall never hurt, all-clear |

Round 30 and not 40: round 40 is the campaign's exfil on this map.

### Map 4 Act I, Werk Thalbach

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[39.84, 0, 7.0]` yaw 270: the Siedlung's east wall | spot: wall 9/9, room 6.0 m, nearest 9.0 m; smoke_weapon_locker |
| Rideable horse, rail, tack chest | horse `[13.0, 0, 27.65]` yaw 180, rail `[13.0, 0, 28.9]`, chest `[11.38, 0, 28.9]`: the Siedlung's south wall between the ammunition box and the Bahnhof door. Zones `A_SIEDLUNG`, `B_BAHNHOF`, `D_KIRCHPLATZ` | probe and smoke as on Kaltenbrunn: nearest other thing 7.0 m, ridden 6.1 m, home 0.42 m off, tack bought |
| Three of Map 0's sky-war kinds | `map04a_ambience.json`: `intensity`, `bombers`, `fighters`, `machine_guns`, copied row for row | smoke: the living world runs without a Landscape, the three kinds are on their timers, a bomber stream and a fighter pair fly (lowest plane 67 m; the hall's crane rails are at 15 m), the far gun is counted |

### Map 4 Act II, der Kranich

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[4.75, 0, 0.17]` yaw 0: the bomb bay's aft bulkhead, 8 m behind the spawn | spot: wall 9/9, room 6.0 m, nearest 4.8 m; smoke_weapon_locker |

### Map 4 Act III, Groom Lake

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[13.84, 0, -14.0]` yaw 270: the wreck site's east side | spot: wall 9/9, room 6.0 m, nearest 6.0 m; smoke_weapon_locker |
| Rideable horse, rail, tack chest | horse `[-9.0, 0, -1.75]` yaw 0, rail `[-9.0, 0, -3.0]`, chest `[-7.38, 0, -3.0]`: the lakebed side of the wreck's wall, behind the Lakebed door (750). Zone `B_LAKEBED` (120 x 64 m of flat ground) | probe and smoke: nearest other thing 9.1 m, ridden 6.1 m, home 0.48 m off, tack bought |

### Map 4 Act IV, Mondlicht

| What | Where | Verified by |
|---|---|---|
| Arms locker | `[5.5, 0, 0.17]` yaw 0: reception's south wall, 6 m from the ammunition box | spot: wall 9/9, room 6.0 m, nearest 6.8 m; smoke_weapon_locker |

With a locker on every map the gun left in one at a campaign exfil can now be taken out on the next map (T-263's
open point).

## Script changes (all small, all data-driven)

- `gravelight/world/sherman/sherman_event.gd`: a map's `sherman_event` block may say `"tank": false` (the raid
  only). Then no round is reserved or used for an arrival, the console's tank commands answer "No Sherman on this
  map", and on `stuka_round` the dive bomber goes for `stuka_target` (left out: no dive bomber, the siren at once).
  The block's own `"raid"` and `"stuka"` rows are laid over `sherman.json`'s (`ShermanEvent.merged`), which is how a
  map gets its own banners. Map 0's block has none of the new keys; a unit test holds that its merged tables equal
  `sherman.json`'s.
- `gravelight/world/sherman/air_raid.gd`: `"shelter_roof": true` in the block makes anything with a collider
  overhead a shelter (a ray up from 2.2 m) and keeps bombs off it. Map 0 does not set it: its shelters are its
  zones and the inn's box, as before.
- `gravelight/world/horse/horse.gd`: the path home asks for the navigation layers of the horse's own zones
  (`Horse.layers_for`). Found by the smoke: Groom Lake's lakebed is not on layer 1, so the horse's path home ended
  on the wrong side of the wall and it stood loose for good. Map 0 has no per-zone layers and keeps layer 1.
- `gravelight/world/inn_opening/inn_opening.gd`, `inn_survivors.gd`: the data file is per map. `data_path` (an
  export, empty by default) or, when empty, `data/gravelight/<map prefix>_opening.json` / `_survivors.json` for the
  map the node stands in. Map 0 resolves to the files it always read; `load_cfg()` without an argument still
  returns Map 0's (six tests and a probe call it that way). A map without the file has none.

New tools: `gravelight/tools_src/map_site_survey.gd` (what stands where, from a scene file),
`probe_map_site.tscn` (a running map: the most open ground of a zone, a point's floor / navmesh / zone / roof /
free radius, a tank hull swept along a route, a rider swept under a zip cable, the roofed share of every zone).

## Tried and dropped, and why

- **A Sherman on Kaltenbrunn ("tank up the rail road").** Not possible with data. The surface is two walled yards.
  The buried rail line (`KaltenTerrain.RAIL`) runs up to the Rail Yard's north wall at x 48 and stops at solid
  brick; the yard's gate (x 18..22, z -0.45) is one static body whose drawing is merged into the baked batches, so
  it cannot be opened or hidden from data, and the tank's scripted drive goes through colliders without looking.
  Outside the walls there is no navmesh, so the dead could not reach a tank parked there (the assault ring is laid
  on the navmesh) and its gunner could not see over a 4 m wall. Kaltenbrunn gets the raid only. What a tank would
  need is in the list below.
- **The day cycle on Groom Lake.** Left off. Its row says `start_hour` 6 (the act is authored at first light).
  At hour 6 the cycle's own numbers put the authored key light at 0 % and the sun at 2 % in round 1, so the act
  would open on a look nobody authored, and the act is over at about act round 9 (noon would never come). With
  `start_hour` 0 it would treat the authored dawn as night and play a second dawn at act round 7. It needs its own
  authored day (a `maps.map04c_groomlake` block where "night" is first light) and a render. A unit test records
  the numbers.
- **Zip lines.** None added. `ZipLine` draws only the trolley; the cable and both posts are the generator's
  dressing, so a data row alone is a trolley hanging in the air. The one existing tower with a player ladder is
  Groom Lake's radar tower (deck at 16 m); whether a cable and a rider clear its lattice and the dish cannot be
  checked without seeing it.
- **Ladders.** Nothing left to switch on: T-229 already gave every drawn ladder that leads to a real floor a
  `LadderClimb` (Totenhafen's engine hatch, Groom Lake's tower) and locked off the others. The zombies' climb
  links on Totenhafen's catwalks and Thalbach's crane rails have no drawn ladder for a player.
- **A dive bomber on Totenhafen.** No landmark on the quay that I could name without seeing it; the raid starts
  with the siren.
- **Map 0's other sky-war kinds on Thalbach.** Artillery flashes, flak tracers, flares, searchlight beams and the
  burning town draw on the Landscape node's sky, which Thalbach does not have; the rest are the inn's own (crows,
  dog, sign, shutter, bell, farm light, chimney, cook-off, the pilot's line, frost). The survey's "Thalbach has 2
  kinds" counted top-level keys: its own living world has twelve kinds under `act1`.
- **Round-numbered events on the four Map 4 acts.** None added. The acts count act rounds and each has its own
  set pieces (Thalbach's air raid, the flight, the dust storm, the meteor shower). A unit test holds that no act
  has a `sherman_event` or `round_bosses` block.
- **A horse on Totenhafen, der Kranich, Mondlicht.** Not placed (a harbour quay 32 m wide with the tide, an
  aircraft, the Moon).

## Not verified, open

- Nothing was rendered. The locker in six new rooms, the rail, rope, chest and horse against three new walls, the
  raid's markers and bursts on new ground, the bombers over Thalbach's cloud deck: unseen.
- The horse is a Noriker with a carter's hay net and a snow-capped rail on all three maps; on Groom Lake (Nevada,
  a dry lake) that dressing is wrong for the place. `Horse.build_rail` draws snow on the rail's posts.
- The raid's burst effects throw snow and earth (`AirRaid.burst_fx`); on Totenhafen's concrete quay that may read
  wrong.
- The raid's voice lines are Map 0's (the Operator: "please proceed to the cellars"). No line names the Kaue or
  the pens.
- The dive bomber's bomb hurts players within 6.5 m of the locomotive, as it does at the Sherman on Map 0; the
  banner gives about eleven seconds.
- Bots: the rail's collider is on the map-edge layer (bots are stopped, the navmesh does not know it), as on Map 0.
  A bot whose path hugs the wall may brush the rail or the horse. Not soaked with bots on the new maps.
- Co-op: the raid-only path uses the same mirrored calls as Map 0's; not run on two machines. A client joining
  after a tack purchase is still not sent the tack (T-262's open point, every map now).
- Balance: a horse on a ten-round act (Thalbach, Groom Lake) with 6000 Scrip of tack; a raid on round 30 of
  Totenhafen. First settings.
- The lockers, rails and chests are not on the minimap (T-263's open point).

## For the per-map geometry workers

**Kaltenbrunn**
- A way in for a tank, then the full Sherman block. Either the gate as its own node (leaves that can swing or be
  crushed: `sherman_event.barrier` hides nodes by name within 1 m of `pos`) or a breach in the Rail Yard's north
  wall at x 46..54 where the buried line meets it (`RailN_1`, between the two windows at x 45 and 55). Measured
  open ground for a park point: the Rail Yard at `(47, 0, 21)` (6.1 m free), the forecourt between the gate and
  the headframe (x 12..28, z 0..10). The park point must be on the navmesh with a ring of it 10..16 m round.
  Check a route with `probe_map_site -- --map=map01 --route=x,y,z;...`.
- An opening (the squad arrives by sled at the Kaue: the sled and their trail are already drawn) and survivors
  (the night shift?), see "An opening" below.
- Perk spots for the perk deal (`perk_layout.json` has only `map00`; no other scene has a `perk_spot.gd` node).
- Reactive props (`gravelight/world/reactive/`: swing doors, draft curtains, shatter sets, snow footprints,
  decor targets). Only `gen_map00` places them.
- A deck for a tower and zip lines: the headframe (`TowerBase`, x 15..25, z 10..20, a 6 m block under the 28 m
  frame) is the obvious tower.

**Totenhafen**
- A landmark under open sky for a dive bomber (a moored hull off the quay), then `stuka_target`.
- Zip lines from the signal tower (`G_SIGNAL`, 7 m) or the catwalks (4 m) need posts and cables drawn; a 26
  degree line from 7 m is only about 14 m long.
- Player ladders at the three catwalk climb links (`Ladder_CatwalkW/E/N`) need a drawn ladder each; then a
  `ladders` row pair per ladder.
- Opening, survivors, perk spots, reactive props: as Kaltenbrunn.

**Thalbach**
- Player ladders up the crane-rail catwalks (12 m, `Climb_CraneLadderW/E` at `(-66, 0, 190)` and `(26, 0, 190)`):
  drawn ladders and a decision whether players belong up there.
- A Landscape (or a sky that takes MapAmbience's flashes and beams) if the rest of the sky war is wanted.
- Opening, survivors, perk spots, reactive props.

**Der Kranich**
- Nothing round-numbered should be added by round number: the flight's clock is by act round.
- Perk spots, reactive props.

**Groom Lake**
- A zip line off the radar tower's deck (16 m; ladder foot `(45, 1, 116.7)`, ladder head `(45, 16, 117.6)`, the
  deck's side rails 0.9 m outside x 43 and x 47, the mast at its middle, the dish's controller at 22 m). A 25 degree line needs 32 m of ground: south-west toward
  `(22, 0, 102)` stays inside `E_RADAR`. It needs an anchor post over the deck, the cable, a landing post, and a
  look at what the lattice and the dish do to it. `probe_map_site -- --map=map04c --line=ax,ay,az;ex,ey,ez;lx,ly,lz`
  sweeps a rider under it.
- The horse's dressing for the desert (a rail without snow, no hay net; a different coat).
- Its own day in `day_cycle.json` (see "dropped"), with a render.
- Roofs: no roof on this map has a collider (the hangar reads as open sky to a ray), so `shelter_roof` would not
  work here if a raid is ever wanted.
- Opening, perk spots, reactive props.

**Mondlicht**
- Perk spots, reactive props. No horse, no day.

**An opening on another map** (the scripts now take any map; no opening was authored)
- A node with `inn_opening.gd` under the map's gameplay holder (and `inn_survivors.gd` for survivors). Leave
  `data_path` empty and add `data/gravelight/<prefix>_opening.json` with `"map": "<map id>"`.
- The file's rows name things the scene must have: `front_door.node` (an `InnFrontDoor`: a doorway the generator
  fills with an invisible collider until it is unbarred), the `flare.light` (Map 0: `Hearthfire`), the barricades
  the attackers come through (found by name), `patrons[]` with start points and run paths on the navmesh,
  `attackers[]` (spawn windows), `lines`, `sfx`, `look`, `title_card`.
- The survivors' file needs `reveal_door` (a door node's name) and `survivors[]` rows with places behind it.
- `VOManager` holds the squad's spawn lines while a node in group `inn_opening` is running; `LazarusCinema` makes
  the opening wait for its reels. Both work by group and will see a second map's opening without a change.
- The class and file names still say "inn". Renaming them is a wide change (generator, scene, tests) and was left.

## Tests

- `gravelight/tests/unit/test_map_detail.gd`, 14 tests: a locker row on all seven maps; every new locker spot
  measured on its scene file (wall 9/9, off the navmesh, room in front); the horse rows (1.25 m from the rail,
  facing it, zones the scene has, standing in the first); no horse on the three maps without one; the horse's
  navigation layers; the raid-only blocks (zones the scene has, every zone either bombed or a shelter, banners,
  not on the exfil's or a horse's round, none on the acts); Map 0's block and merged tables unchanged; `merged`;
  a raid-only event node (no round held for a tank, tank commands refused, the siren at once); a tank event still
  holds 30 and 40; a roof shelters only where the map says so; the opening's and survivors' paths; Thalbach's
  sky rows; Groom Lake's day off, with the numbers.
- `gravelight/tools_src/smoke_map_detail.tscn`: 151 checks over Kaltenbrunn, Totenhafen, Thalbach, Groom Lake and
  Map 0 (see the header of the script). `-- --only=map01` runs one map.
- `smoke_weapon_locker` already walks every map with a row: now seven.

## Results (headless, this PC, 2026-11-24)

- `check_scripts`: 992 scripts, 0 failed.
- Full GUT: 2547 tests, 2546 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised`).
  Master had 2533; +14 are `test_map_detail`. Two older tests asserted the old state and were changed to the new
  one: `test_sherman.test_on_the_inn_only` (Kaltenbrunn and Totenhafen now have a block, without a tank) and
  `test_horse_gait.test_map_rows` (Kaltenbrunn now has a horse).
- Smokes, all PASS with 0 script errors: `smoke_map_detail` (151 checks), `smoke_sherman` (74), `smoke_horse`
  (116), `smoke_horse_boss` (81), `smoke_weapon_locker` (seven maps), `smoke_ladders`, `smoke_coop`, the four
  `smoke_map00*`, the three `smoke_map01*`, the three `smoke_map02*`, the eleven `smoke_map04*`.
- One smoke fault found and fixed on the way: `smoke_map_detail` first took any random open navmesh point on
  Totenhafen's quay as "the open"; one run drew a point on a navmesh island no path leaves. It now takes open
  ground the spawn can walk to (3 of 3 runs PASS after). The island itself is the map's, older than this task.
- Not run: the bot smokes, the campaign smoke, the other set-piece smokes.

## For DECISIONS.md (the main session writes it at the merge)

**T-271: the base of the map detail pass.** Branch `claude/map-detail-base`, notes
`docs/u21/t271_map_detail_base.md`. Data rows and four small script changes, no generator and no scene touched.
An arms locker on all seven maps. A rideable horse with rail and tack chest on Kaltenbrunn (the Minehead yard's
east wall), Thalbach (the Siedlung's south wall) and Groom Lake (the lakebed behind its door); none on the
harbour, the aircraft or the Moon. A raid-only mode of the Sherman event (`"tank": false`; `shelter_roof`; a
map's own banners): Kaltenbrunn round 40 with a dive bomber on the locomotive, Totenhafen round 30 with the siren
only (40 is its exfil). No tank on Kaltenbrunn: its walls have no way in that data can open. Three of Map 0's
sky-war kinds on Thalbach. The opening and the survivors read `<map prefix>_opening.json` / `_survivors.json`;
none authored. Left off: Groom Lake's day (its start hour would put the authored light out in round 1), zip lines
(the cable and posts are generator dressing), round-numbered events on the Map 4 acts. Seen by nobody: all checks
are headless.
