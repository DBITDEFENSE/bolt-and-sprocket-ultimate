# T-239: Kaltenbrunn (map01), the final pass

The owner: "do a final pass on map 1 and 2 make sure the maps feel smooth and everything looks logically placed, the
cellar for example is too cluttered, the haystacks fell half baked in the barn." This is "map 2", Kaltenbrunn. Everything
is in the generator (`gravelight/tools_src/gen_map01.gd`) and the map's data; the scene is regenerated.

## What was wrong, in one paragraph

Kaltenbrunn was not cluttered. Its two faults were the opposite of each other. **Most of what stood on its floors was
not there**: the generator's dressing is drawn without colliders, and only the south wall of the yard, the Kaue and the
Core had hidden blocks under their props. The ore carts, every drum and brazier, the desks, the bunks' foot lockers,
the mess benches, the hoist motor, the lab's gurneys, cabinets and operating table, the votive racks, the altar's
steps, the three pylons: a player and every zombie walked through all of them (156 clusters in the new probe). And
**a handful of things read as unfinished or wrong**, some of them on every screen: all the "new" timber (bunks, mess
tables, pit props, door frames in the Chapel) was drawn in the wrong colour by a stale look-pass table; the door trims
were 0.6 m narrower than their doorways and hung in the open doorways; a 0.45 m plinth ran across both of the Kaue's
doorways and a rail at eye height across all six lab doorways; the Administration stairs were boxed in two bare black
slabs; a brazier's drum lay on its side under its own flames; two votive racks stood inside pilasters; four white discs
lay on the Core's floor.

## How it was found

- `gravelight/tools_src/probe_snags.tscn` (new, headless): from every reachable spot of the navmesh (0.5 m grid, 21 990
  spots on this map) the player's capsule is moved 1.5 m in 16 directions the way `move_and_slide` would. It reports
  colliders that stop it low (LOW: top under 0.75 m), from above (OVERHANG), dead while sliding along another
  collider (CATCH), and small free-standing ones (SMALL); and, with MapArtAudit's art copies, **GHOST**: drawn things a
  body stands inside. Before: `.smoke_logs/t239/snags_before.log`; after: `.smoke_logs/t239/snags_final.log`.
- `audit_map_art.tscn -- --map=map01` (MapArtAudit, colliders with no art), `probe_invisible_walls`, the facing runner.
- One generator run with `GL_PROBE_BOX` over the whole map named the pieces in each ghost cluster.
- Renders under WSL Xvfb, 150 cameras added to the `u10_map01` set: `u15_*` before the power, `u15p_*` power on,
  `u15b_*` under a flat work light (the night frames hide what stands where). Darkness before the power was ranked from
  the frames (share of near-black pixels in the lower 60 %).

## Zone by zone

### A. Minehead Yard and the Waschkaue
- The Kaue's concrete plinth ran across both doorways as a 0.45 m kerb. It stops at them.
- The Kaue's benches stopped 0.95 m short of the back wall: a 0.55 m pocket in each back corner. **PAUL wedged there**
  (the lead's report: `smoke_paul` "he stands over the body" failed, he hung at y 0.2 with his fall speed building).
  The probe print showed him at (4.45, 0.25, 31.18) resting on `KauePropBenchW`'s end between the bench, the wall and
  the lockers. Both benches run to the wall now; `smoke_paul` passes. For the lead: paul.gd lets `velocity.y` build
  without limit while he is not on a floor (-277 m/s in the print), and he stands 0.2 m above the ground with
  `is_on_floor()` false even on open floor after the fix (his capsule's foot); neither is the map's.
- The stove stood 0.75 m off the back wall (a slot a player fits). Its collider reaches the wall; a brick hearth and a
  coal box are drawn behind it, the scuttle beside the box.
- The night shift's brazier before the pier stood 0.55 m off the facade: its collider reaches the wall.
- The squad's sled stood 0.85 m off the Kaue's east wall, ankle high in the way along the south wall. It is in the corner.
- The gatehouse's shelf was a 10 cm collider at hip height 0.5 m into the 3 m lane by the Armorer's Bench (39 sweeps
  stopped on it). It is drawn only, 0.3 m deep; the cylinder on it has not moved.
- Solid now: the spur's ore carts on the north wall (the third stood across the rails with a knee-high salt heap; it is
  on the rails, tipped, its spill flat), the crates by the winding house door (0.75 m off its wall in a 3 m lane: against
  it), the drums on the east wall with their brazier (the drum lay on its side under its flames: upright, against the
  row, round collider), the crate and the sandbags under the Administration's balcony (one line against the wall), the
  brazier by the Administration door (against the wall under the gooseneck, round), Pylon A's foot (round).
- The south wall's crate stack is restacked square with its sack on top (two sacks stood loose in front; its collider
  was a box half full of air); lagging boards stand inside the spare timber set so the frame its collider closes reads
  closed.
- Light before the power: a lantern on the gatehouse's east wall (the Armorer's Bench lane was 90 % black) and one on
  the north wall behind the winding house (a ground spawn and two windows, 89 % black).

### B. Rail Yard
- Solid: the two ore carts on track 3 (in front of the MP40 chalk: 2 m of lane either side), the coal heap (heaped into
  the north-east corner behind planks), the locomotive's buffer beam (0.7 m ahead of its collider; a pilot plate drawn
  under it), the water crane (it stood in the walkway between the tracks: by the south wall now, round collider).
- Light before the power: a lantern on the east wall between the two chalks and one on the north wall by the boxcar.
- Left: the Runaway Ore Cart's parked cart has no collider (the trap's own node); the 1.35 m slot east of the boxcar.

### C. Administration
- **The stairs**: T-107's closed strings were drawn as two bare dark boards 7 m long and 3.5 m high, the black block in
  the middle of the lobby in every frame. They are the walls of a boxed staircase now: plaster over a wainscot like
  the room's walls, skirting, chair rail, a post at each end. The colliders are untouched. On its lobby face (the lead's
  look at the first render: a blank 7 x 2 m slab) hang the shift board with a brass tally per man, the stopped clock
  over the framed plan of the workings, the notice board and a lantern: drawn only, at most 8 cm off the face
  (`164_u15b_C_stair_wall.png`).
- The three clerks' desks stood loose in the lobby (one in front of the bank's counter), intangible. They stand against
  the walls with their chairs pushed in: one under the map on the north wall, two on the east wall. The safe is in its
  corner (it stood 0.85 m out of it). The coat rack is by the wall.
- **Upstairs**: the partition's door trim stood a metre east of its doorway, one jamb in the middle of the opening.
  The office was a 16 x 16 m room with a desk on a rug: it has filing cabinets on the south wall, a plan table under
  the picture, a waiting bench against the partition, all solid; the desk is solid, with one chair instead of two.
  The radio room has Fasbender's cot (MAPS.md names it) and his lantern on the radio desk: the room and the balcony
  window beside it were 94 % and 81 % black before the power.
- A lantern on the lobby's east wall by the yard door.
- Left: the bank's grille stands 0.3 m proud of its collider and the switchboard's key shelf 0.4 m (the bank is
  data-driven, the switchboard a Requiem step: not moved).

### D. Barracks and mess
- Solid: the lockers on the north wall, the quartermaster's shelf, the stove (on an iron plate in its corner, a coal
  box beside it), the foot lockers (two a bunk, the bunk's own width, so bunk and lockers are one outline), the mess
  benches (one block with their table).
- The bunks, the mess tables' legs and the benches were drawn grey-green: see "The timber" below.

### E. Lift house and bay
- Solid: the hoist motor in its corner (the before frame `u15b_E_lifthouse_s` was taken from inside it).
- The three ambience chains hung in the middle of the arrival bay with a weight at chest height where the squad steps
  out of the cage (`map01_ambience.json` lift_chains): along the side walls now. A lantern on the bay's east wall.

### F. Salt Chapel
- Two of the four votive racks stood inside a pilaster's shaft. All four stand between pilasters, solid.
- The altar's steps were drawn and not there. They are solid and stop 2 m either side of the reliquary (4 m of clear
  floor in front of it, was 2.8); the Altar's own node has not moved.
- The salt columns' bases stood 0.25 m proud of their colliders: drawn to the collider. The two standing candelabras in
  the cross aisle stand at the pew blocks' corners. Pylon F's foot is solid (round).
- Left: the pew blocks are one collider each (rows are drawn with gaps): a deliberate training-loop block, smooth.

### G. Generator Hall
- **The Hauptschalter's dais** was the worst LOW finding (199 sweeps): a 0.3 m step 1.85 m out of the wall in the north
  lane. It has a ramp skirt on its three open sides (`DaisSkirt`, chequer plate, a painted edge): a body walks over it.
- The Chapel-side timber frame of the hall's door was the doorway's width, its legs standing in the opening: widened.
- The crate in the south-west corner stood 0.5 m in front of the vault ramp's blast door and a drum on its jamb. Crate
  and drums are in the corner west of the door, solid.
- The catwalk's ladder (no climb) has its GESPERRT chain (T-229's rule). The Foreman's lantern on his desk.
- Left: the turbines' colliders are boxes over round machines (invisible above the 0.7 m plinth only; opening the
  plinth's top would make a ledge to camp on).

### H. Laboratory Wing
- The dado rail ran across all six doorways at eye height. It stops at them.
- Solid and against walls: both cabinets, the three gurneys (one stood between the two doors of Reinholt's lab, one
  across the cold store), the trolleys, the hall's crate and benches, the coils, the intake bench, the refrigerator.
- The operating table was a steel box under a sheet, 1.5 m from the cabinet: a top on a pedestal with its sheet hanging,
  half a metre west (2 m round it), its trolley at its head, one block.
- The nursery's cot was a 3.9 x 2.4 m platform inside bars. It is a child's cot, 2.0 x 1.1 m, against the wall, the
  mobile over it. Pylon H's foot is solid.

### I. Core Vault
- The four "salt crust" pieces were bright white 1.8 m discs on the dark floor: removed.
- The crystal formations (size 1.2 to 2.4) leaned up to 1.4 m into the ring round the pit and two stood free beside
  pillars (`u15b_I_installers` before was taken from inside one). They are 0.8 to 1.25, at the wall feet.
- The 0.7 m slot between the Crucible and the south-east pillar fitted a body exactly (11 sweeps wedged): closed by two
  of the installers' crates. The Ledger's lectern stands in front of the drawers, solid.
- Left: the Crucible room's own dressing (T-175, data-driven) overlaps the walkable floor round the machine.

### Every zone
- **The timber.** The look pass keys its per-texture fixes by the scene's sub-resource ids. Those ids change at every
  regeneration, and the table (`data/look/_materials.json` tex_fix) was last written before T-225: of its eight map01
  rows six named nothing and two named other textures. The pit-prop timber ("pine": bunks, mess tables, benches, pit
  props, the Chapel's door frames) took a red paint's fix (saturation 0.07): grey timber on the owner's renderer,
  bright green in the WSL captures. The generator now gives every noise texture an id made from its content
  (`_name_noise_textures`, 68 textures), the audit was re-run and its ten fixes written, the stale rows pruned.
  **Map 0 and Totenhafen have the same exposure after any regeneration** (their generators do not name their
  textures; for the lead and the map00 worker).
- **Door trims.** Sixteen trims were 2.0 m wide on 2.6 m doorways (`DW`): they are the doorway's width.

## Counts

| | before | after |
|---|---|---|
| GHOST clusters (probe_snags) | 156 | 97 (what is left: gameplay nodes' own art, the bank, the Crucible room, the probe standing on the mess benches) |
| CATCH sweeps at the Crucible / pillar slot | 11 | 2 |
| SwitchDais LOW sweeps | 199 | 0 |
| GatehouseShelf OVERHANG sweeps | 39 | 0 |
| hidden prop colliders | 15 | 80 |

## Renders

Before: `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\.claude\worktrees\agent-abf4930be315e4848\morning\screenshots\u10_map01\u15_before\` (150 PNGs).
After: `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\.claude\worktrees\agent-abf4930be315e4848\morning\screenshots\u10_map01\u15_after\`.
Pairs share a file name. The before work-light frames (`u15b_*`) were taken with the power off, the after ones in one
run after the `u15p_*` frames, so with the power on.

## Results

Run on the final scene, headless (`.smoke_logs/t239/`):

- `check_scripts`: 884 scripts, 0 failed.
- GUT: map01 26/26 (ambience, edges with two new tests, mechanics), mapdata 11/11, npc_navmesh 7/7, machine_lore 4/4,
  capture_cams 3/3, world_objects 16/16, ladders_data 3/3, crucible_rooms 5/5.
- Facing runner, map01: 70 OK, the 3 desk pickups UNREACHABLE as before (exit 3, unchanged).
- `probe_invisible_walls` map01: one line, a pew block, as before.
- MapArtAudit map01: 28 findings before, 41 on the final scene. The new ones are low colliders a little larger than what is drawn
  (desks with their chairs, the mess benches' block, the altar steps, the pylons' feet, the drum rows): the price of a
  smooth outline; none stands in a lane. The old 28 (turbines, pews, bunks, locomotive, tanks) are unchanged.
- Generation: WALLBUY_AUDIT clear for all nine chalks.
- Smokes: map01 PASS, map01_systems PASS (it failed one Foreman-model check on the untouched scene before the
  worktree's import had finished), map01_world PASS, requiem PASS, ee_bots PASS, bank PASS, ladders PASS, bots_shop
  PASS, map_companions PASS, paul PASS (every check; with `claude/boss-rework`'s smoke_paul.gd from 3ad95961, and 132
  script errors from boss_fx.gd:106 that 3ad95961 fixes in boss_fx.gd, not taken here). bots_shop_m0 (Map 0, not
  touched here) FAILED once under load: "no squad bot did 'bench'".
- Baseline on the untouched scene: map01 PASS, map01_world PASS, requiem PASS, ee_bots PASS.
- Minimap: re-baked on the final scene under WSL (`sh tools/wsl_godot.sh --path . res://tools_src/bake_minimap.tscn --
  --map=map01_kaltenbrunn`: RESULT PASS, 4 floors, 50 POIs), test_mapdata 11/11.

## What is left, and why

- Gameplay nodes draw themselves without colliders: the ore-cart trap's parked cart, the trap levers (one stands in
  the Generator Hall's south lane), the Live Wire fence's posts, the phonograph's table, the switchboard's key shelf.
  Their scripts and positions were out of bounds.
- The bank branch's grille and the Crucible room's dressing (both data-driven dressers) overlap the walkable floor.
- Navmesh islands on top of low wide blocks (the pews and bunks before, the mess benches now): unreachable, as before.
- The pews, turbines, tanks, locomotive and boxcar keep their box colliders (see the zones).
- The 1.35 m dead-end slot east of the boxcar (the shell).
- paul.gd: `velocity.y` builds without limit off the floor; he reads `is_on_floor()` false standing on open ground.
- Map 0 / Totenhafen: the look pass's tex_fix rows go stale at their next regeneration, as map01's had.
- The after work-light frames were rendered with the power on (one run); a few after frames predate the last
  regeneration (the Chapel-side door frame), re-rendered under `u15_after` where listed.
