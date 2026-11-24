# T-274: the map detail pass, geometry step, on the four Fernflug acts

The owner, 2026-11-24: "go through and look at all the maps and apply a level of detail that you see that we have in
the first map ... there's level design, there's things that happen throughout the rounds."

Branch `claude/detail-map04`. Work order: T-271's notes ("For the per-map geometry workers") and the T-272..274
brief. Coordinates are map space, metres, `[x, y, z]`. Everything is built by the act generators
(`gen_map04a..d.gd` on `gen_map04_lib.gd`) and regenerated headless.

## What was built

### 1. Perk spots and the perk deal (all four acts)

The acts' machines are dealt onto perk spots each match from the match seed, as on Map 0 (T-251, T-255):
`perk_layout.json` rows `map04a..d`; PerkLayout attaches by itself where a scene has PerkSpot nodes. A spot left
without a machine shows the nailed Helvetia crate.

| Act | Machines | Spots | New spots |
|---|---|---|---|
| Thalbach | 9 | 15 | rail yard west wall `[0.75, 0, 42.5]`, church square west `[0.75, 0, 76]`, hall 1 west `[-59.25, 0, 87.25]`, wind tunnel south-west `[0.75, 0, 107.75]`, Great Hangar west `[-69.25, 0, 186.25]` and east `[29.25, 0, 195]` |
| der Kranich | 9 | 14 | bay port wall `[-8.25, 0, 14.5]`, port wing aft `[-45.25, 0, 31.75]`, starboard wing fore `[16.75, 0, 42.25]`, engine room outboard `[-77, 0, 48.75]`, gun room inboard `[52.75, 0, 41.25]` |
| Groom Lake | 10 | 16 | crash site west `[-13.25, 0, -22.5]`, lakebed side of the wreck's wall `[-38.25, 0, -3]` and `[-50.25, 0, -3]`, radar yard west `[20.75, 0, 107]`, service lane `[-5.75, 0, 99]`, lab records wall `[-62, -6, 136.75]` |
| Mondlicht | 9 | 13 | reception west `[-11.25, 0, 13.5]`, concourse west north end `[-11.25, 0, 48.75]`, hall west south end `[12.75, 0, -4.25]`, core west `[14.75, 0, -31]`; none out on the regolith |

- The machines' old places are spots too, moved back onto their walls: most stood 0.15..0.85 m off the wall
  (`spot_from_perk` + `_snap_spots`: the spot walks back until the deepest machine would touch, and stops 0.1 m
  short). Four old places were moved: Thalbach's Twin Barrel 0.6 m west (it was 0.15 m from the wind tunnel door's
  jamb), Kranich's Second Wind 1 m starboard (1.2 m from the bay doors' lever) and both wing machines centred between
  their ribs (a wagon would have stood in a rib), Groom Lake's Twin Barrel place (the lab's glass jamb and the work
  bench were in its floor) 3 m west on the hall's wall, Mondlicht's Ironhide barrel (5 cm into the concourse wall,
  2.1 m from a window) 5.75 m south on the same wall.
- Flags from the act's own zone graph: "start" in the start zone (cheap tonics only, never Second Wind), "near" in a
  zone one door from it (where Second Wind may stand: each act has three or four). "outdoor" is off everywhere: no
  snow on these four (the filler crate would wear snow), and the acts stood cabinets in the open before.
- The act hand-over: checked, nothing unsafe. The campaign deals each act from the new match seed the travel sends
  (`Net` travel); Groom Lake's power-on wakes the machines nearest the generator first by their live positions,
  Kranich's aux bus wakes them by the zone each stands in, Mondlicht's heaters wake every machine: all read where
  the machines stand now. The four acts' smokes and `smoke_map04_full` (the chain 04a -> b -> c -> d) pass with
  dealt layouts (`[PerkLayout] seed ...` lines in each act).
- `gen_map04_lib.gd` "perk spots" (opt-in table `perk_spots`): bake-only footprints (1.7 x 1.2, the navmesh goes
  round, no collider left in the scene: the machine or the crate has its own body), the seed-0 deal in the saved
  scene, and gen_map00's audit run before every save: the footprint, the walk in front and the walk beside the fine
  print against every collider and every drawn piece (before the batching), a wall behind, keep radii from every
  gameplay node (doors, windows, wall-buys, ammo, crates, levers, spawns, the act's own set pieces), the act's arms
  locker and horse rows, the other spots, the floor in front on the navmesh. A blocked spot keeps the scene unsaved
  (`GL_PERK_FORCE=1` saves anyway); `GL_PERK_SURVEY=1|<zone>` prints the clear places on the walls,
  `GL_PERK_PROBE="x,y,z,yaw;..."` probes. Groom Lake's dressing is partly pre-baked into region batches whose boxes
  say nothing about one piece: those batches are left out of the audit (its colliders still count).
- `data/maps/map04*/mapdata.json`: the POIs re-read headless by the new `refresh_mapdata_pois.tscn` (POIs and their
  signature only; the floor images are kept, nothing on the floors changed). `tools/bake_minimap.sh` needs a
  rendered window, which this PC may not open.
- Thalbach's regeneration also picks up T-252's `m1_brick` tint (`materials.json`, tuned for Kaltenbrunn, which
  shares the material): the act's brick is a little warmer than the scene on master. Not chosen here; it is the
  table's current value.

### 2. Reactive props (all four acts)

Map 0's kit (`gravelight/world/reactive/`), placed by `gen_map04_lib.gd` helpers under one `Reactive` node, all built
at load, nothing collides, nothing touches the navmesh:

- **Thalbach**: door leaves left ajar in the three open doorways that had no leaf (the yardmaster's hut
  `[5.85, 0, 54.9]`, parish hall `[36, 0, 88.15]`, the air-raid cellar `[6.1, 0, 9.85]`; the goods shed keeps its drawn sliding door); blackout curtains at the
  canteen's south window `W_C_S` (billow harder as its boards go); the night shift's glasses, steins and bottles on
  the three canteen tables (break when shot or blasted); loose papers on the hut desk, on the floor beside the three
  office desks (beside the Fernflug files, never on them) and on hall 1's floor; drips in the air-raid cellar
  (`[4.5, 2.97, 4]`, `[9.5, 2.97, 7.5]`) and the bunker (`[-54, 3.97, 141]`).
- **der Kranich**: papers by the bay's forward bulkhead `[-1.5, 0, 22.6]` and in the starboard crawlway
  `[34.5, 0, 41]`, two stashes of glass (the ramp seam `[6.5, 0, 1.6]`, the crawlway `[27.5, 0, 42.2]`): when a
  decompression pulls, the papers near it fly out through the hole and the glass nearest it breaks
  (`DecompReactive`, new); the galley's glasses and jars on its counter; four slack cable loops (body, both engine
  rooms) in `flight_swing`, swung by the bank like the lamps (`detail_map04b.gd swing_cables`). The "windows that
  shatter": the act's portholes are drawn into the hull batches and cannot be hidden one by one, so the glass that
  breaks at a breach is the two stashes; `DecompReactive.panes` (glass bursts at points) exists but is unused.
- **Groom Lake**: salt dust that puffs under feet on the crash site, the lakebed track and the motor pool apron
  (HayPuffZone with a tint); door leaves in the open doorways (the wreck's buckled hatch `[8.8, 0, -4.15]`, the lab's
  door to the cable trench, the silo control room's door); the lab bench's jars, glasses and notes; the Kranich's
  manifests blown across the crash site `[-4, 0, -24]`; papers in the motor pool.
- **Mondlicht** (inside the base): papers behind the reception desk `[8.5, 0, 16.4]` and in the concourse that float
  up and drift down at 1.62 m/s2; grey regolith dust trodden in at the yard airlock's and the store's inner doors.
- New `gravelight/world/map04/loose_papers.gd` (LoosePapers): sheets as one MultiMesh, lifted by a body moving
  through them, a blast or `blow()`, falling at their own slow speed (gravity per set), settling where they land; a
  sink takes them for good.

### 3. Groom Lake: the zip line, the desert horse

- **RadarZip** (`map04c.json ziplines`): from the radar tower's perch deck, the cable's top `[41.55, 18, 116.55]` on
  an arm off a post in the deck's south-west corner (2 m over the deck, a step outside the rails), past the hangar's
  north-west corner and over the motor pool's north wall to a post in the service lane `[2.6, 0, 88.9]` (the cable
  ends 2.75 m up it), landing `[3.33, 0, 89.42]` by the hangar's side door. 50.1 m, 18 degrees, speed cap 9.
  `probe_map_site --line`: nothing in a rider's way (the post itself at the very end, as on Map 0); the landing is on
  the navmesh, 3.3 m free. Chained until the motor pool is open (the tower is beyond the hangar's doors).
  T-271's south-west line inside the radar yard does not exist: every corner of the yard is under 24 m from the deck,
  33 degrees or more; the lane is the nearest open ground with the run for a cable.
  Drawn (`gen_map04c.gd` ZIP_*): both posts (colliders), the arm and its brace, the sheave, the sagging cable, the
  landing post's cap, back-stay and ground anchor, a rubber buffer, a red marker lamp (no light).
- **The horse's dressing by data** (`horse.gd`, `horse_mesh.gd`; defaults unchanged): a horse row's `rail_dress`
  (`snow`, `hay_net`, `ice`, `post`, `pole`) and a coat by look (`HorseMesh.COATS`). Groom Lake's is a buckskin on
  a sun-greyed board rail, no snow, a nosebag for the hay net, water in the bucket. Thalbach and Kaltenbrunn keep
  the Noriker and the snowy rail. Hooves on non-Inn maps were already "stone" (no snow puffs).
- **Its own day** (`day_cycle.json`): left off. It needs its own authored dawn-to-noon block and a judged render of
  each hour; no render of the day was made here.

### 4. Thalbach: the catwalk ladders (survivors not done)

- Decided: players belong up there (the catwalks already have ramps from the south corners and catwalk spawns).
  Fixed steel ladders are drawn up both catwalks' edges at z 190 (`CRANE_LADDER_Z`) with grab handles through a gap
  in the rail (the rail's collider and its drawing are split 1.2 m round the ladder). `map04a.json`: the players'
  rows `CraneLadderW/E_Foot/_Top` and the dead's `Climb_CraneLadderW/E` on one line (`[-65.985, 190]`,
  `[25.985, 190]`), the dead one at a time up the rungs, down by dropping (as on Map 0's tower). The heads moved
  from 2.2 m to 1.6 m in from the line (`test_ladders_data`: a head is a step from the line). `probe_ladder_tops`:
  every end on the navmesh (0.00 m).
- **Not done**: the survivors in the Montage locker room and a shift-siren opening. They need 2..3 people's line sets
  written into `vo/lines.json` (text only, no voice generation), the hiding places behind a door and a smoke; the
  forced labourers need care in the writing. Left for a later pass.

### 5. Act-clock happenings (Kranich, Mondlicht)

- **der Kranich**: on act rounds 2, 5 and 8 (the flight's own clock, `RoundManager.act_round`), 45 s in, a night
  fighter comes up alongside, is hit abeam, bursts into flame and falls away burning through the cloud deck; the
  crash booms up 9 s later (`map04b.json flight.sky.fighters.downed`, `FlightSky.spawn_downed`). Presentation only.
- **Mondlicht**: after each meteor shower ends, a supply capsule comes down on the yard's open ground (the ring and
  the streak like a strike's; the dead under it die, nobody living is hurt; a capsule in its crater with a blinking
  beacon; three AmmoDrop tins round it; host-picked, mirrored). Keyed to the shower's end, so it follows the
  shower's own schedule (`meteor_shower.capsule`; dev console `meteors capsule`). The shower itself still starts on
  match round 33, every 6 (T-158's row, act round 4 when Act IV starts at 30): not changed here.

## Cost

Static (the scene files, before -> after; `.smoke_logs/t274/census.gd`): Thalbach meshes 738 -> 738, triangles
221 k -> 228 k; Kranich 457 -> 469 meshes (the cable movers), 62 k -> 66 k; Groom Lake 522 -> 525, 156 k -> 160 k;
Mondlicht unchanged. Lights: none added in any scene, shadowed lights unchanged (5 / 6 / 6 / 5). New static
geometry sits in the existing containers (StaticBatches, DressBatches); the moving cables are kept movers like the
act's lamps.
Built at load (not in the files): the Reactive nodes (Thalbach 17, Kranich 7, Groom Lake 10, Mondlicht 4: a paper set
or a glass set is one MultiMesh per material, a door leaf about five small meshes, a curtain four strips) and one
filler crate per free perk spot (6 / 5 / 6 / 4 crates, as on Map 0). The supply capsule adds one unshadowed blinking
light for 60 s after a shower. Draw calls were not measured (no rendered run on this PC); a rough upper bound for
the reactive props is 40 extra on Thalbach's busiest view, under 15 elsewhere, all near things.

## Tests and smokes

- `test_map04_perk_spots` (5): rows and machines, spots spread / flagged / flush, footprints off and fronts on the
  navmesh, the seed-0 deal in each scene, the rules over 300 seeds per act (every spot used, Second Wind always
  one door from the start).
- `test_map04_detail_t274` (9): the reactive nodes per act and every path they name, LoosePapers (lift, fall,
  settle; the Moon's slow fall; a sink), DecompReactive with a stand-in breach, the zip row against the drawn posts,
  the ladders' rows and links on one line, the desert horse and the default snowy rail, the supply capsule.
- `test_map_detail.test_horse_rows` now expects the buckskin on Groom Lake (it held the Noriker everywhere).
- `smoke_map04b_world`: + the fighter shot down on act round 2, + the starboard decompression taking the crawlway's
  papers and stash. `smoke_map04d_world`: + the capsule (tins on the yard's open ground, by the navmesh).

## Results (headless, this PC, 2026-11-24)

- `check_scripts`: 1009 scripts, 0 failed.
- Full GUT: 2603 tests, 2601 passing, 1 risky (the known `test_neural_lines_are_loudness_normalised`), 1 failing:
  `test_hud_stamp_perks.test_round_stamp_fits_high_rounds` on "Lambda capture at index 0 was freed" (an earlier
  test's timer firing late under load); it passes alone and with every `test_h*` file (85 of 85). Master had about
  2570; the new ones are `test_map04_perk_spots` (5), `test_map04_detail_t274` (9) and other branches' merges.
- Smokes, all PASS with 0 script errors: the eleven `smoke_map04*` (on the perk-spot build, and again after the
  reactive props, the zip line and the ladders; `smoke_map04b_world` failed first on its new checks: json act rounds
  are floats and `Array.has(int)` missed them, and the papers landed short of the breach; both fixed, then PASS),
  `smoke_ladders`, `smoke_map_detail` (151), `smoke_weapon_locker`, `smoke_horse` (116), `smoke_horse_boss` (81),
  `smoke_coop`; on the final build again `smoke_map04a`, `smoke_map04b`, `smoke_map04b_world`, `smoke_map04_full`.
  `smoke_map04b_world`'s fighter check was moved to the end: run before the bay doors at act round 2
  it left the player mid-push and the old bay-doors check failed.
- `probe_map_site --line` (the zip), `probe_ladder_tops --map=map04a` (all eight ends 0.00 m from the navmesh).

## Renders

`docs/captures/t274/` (WSL Xvfb, Compatibility renderer, 960 x 540, the acts' night): one contact sheet per act from
the sets `t274_m04a..d` in `capture_cams.json`. Looked at: the dealt machines and crates stand on their walls (the
Great Hangar, the church square, the Kranich's wing and bay, Mondlicht's core); the catwalk ladder runs from the floor
to the rail's gap; the parish and cellar leaves hang open in their doorways; the desert horse is a buckskin on a
plain board rail; the zip cable is visible from the deck and its landing post stands in the lane; the Kranich's
slack cable hangs in the body; Mondlicht's papers lie behind the reception desk. Fixed from the pictures: the goods
shed got a hinged leaf in a doorway that already has its sliding door drawn (removed). Too dark to judge at this
size: the canteen's curtains and glasses, the zip cable's full run, the lab bench (the camera stood on the other
side of its wall).

## Not verified, open

- Renders are Compatibility-renderer night shots: they show shapes and placement, not the final light.
- The decompression's papers and glass, the fighter going down, the capsule landing: seen only in headless smokes.
- Co-op: the capsule is host-picked and mirrored like the meteor strikes; the reactive props are local presentation;
  not run on two machines.
- Bots: they buy at dealt machines through the "perk_machines" group (as on Map 0); not soaked on the acts.
- The minimap floor images still show the old floors (nothing on them changed); the perk POIs are current.

## For DECISIONS.md

**T-274: the map detail pass on the Fernflug acts.** Branch `claude/detail-map04`, notes
`docs/u21/t274_map04_detail.md`. The perk deal on all four acts (Thalbach 15 spots for 9 machines, Kranich 14/9,
Groom Lake 16/10, Mondlicht 13/9; the old places moved back onto their walls; start / near from each act's zone
graph; no outdoor spots), with gen_map00's audit in `gen_map04_lib.gd` keeping a blocked scene unsaved, and the
mapdata POIs re-read headless (`refresh_mapdata_pois.tscn`). Reactive props on every act (door leaves, curtains,
glass, loose papers, drips, salt and regolith dust; LoosePapers new), Kranich's decompressions taking papers and
glass out (DecompReactive) and its slack cables swinging. Groom Lake: a zip line from the radar perch to the motor
pool lane (50 m, 18 degrees, chained until the motor pool opens; T-271's line inside the radar yard would be 33
degrees), a buckskin horse on a rail without snow (horse rows' `rail_dress` and `HorseMesh.COATS`, defaults
unchanged); its own day left off (no judged render). Thalbach: drawn ladders up both catwalks, players and the dead
on one line. Kranich: a night fighter shot down on act rounds 2, 5, 8; Mondlicht: a supply capsule after each meteor
shower. Not done: Thalbach's survivors and shift-siren opening.
