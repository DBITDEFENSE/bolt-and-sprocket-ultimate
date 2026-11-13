# T-238: the Inn's final layout and dressing pass (map00)

The owner: "do a final pass on map 1 and 2 make sure the maps feel smooth and everything looks logically placed, the
cellar for example is too cluttered, the haystacks feel half baked in the barn." Map 1 is the Crossroads Inn (`map00`).

Everything below is in the generator (`gravelight/tools_src/gen_map00.gd`) and one new dressing library
(`gravelight/world/props_hay.gd`, preloaded as `Hay`; no existing library function changed). The scene and its two
navmeshes are regenerated. Base: `claude/boss-rework` at e31a4e92 (the worktree was cut from `master`, which has none
of T-224..T-230; it was fast-forwarded before any work). Rendered under WSL + Xvfb before and after (`tools/wsl_godot.sh`, set `u05`, labels
`u15_before` / `u15_after`); the camera rows are in `data/gravelight/capture_cams.json`.

## 1. The cellar ("too cluttered")

There are three cellars. The renders say which one is crowded: the **Helvetia vault** (12 x 12 m, ten perk machines,
the Crucible, the lever, two pillars) with stores wedged into every gap between the machines. The Old Cellar (wine
cellar, coal room, root cellar, barrel vault) and the late-delivery bay are roomy; they got a tidy, not a thinning.

### The Helvetia vault (x 24..36, z 19..31)

| | before | after |
|---|---|---|
| things standing on the floor or against a wall, the machines, the Crucible, the lever and the pillars not counted | 18 (+ 9 loose coal lumps) | 8 (+ 5 lumps) |
| drawn pieces the probe counts in the vault (`GL_PROBE_BOX`) | 342 | 244 |
| solid dressing (colliders) | 2: crates 0.6 x 0.6 m between the Crucible and the lever; a 2.65 x 1.65 m heap in the north-east corner | 2: the bench (1.57 x 0.73 m) and the two crates at its end (0.68 x 0.7 m), both against the north wall |
| the lever's approach (x 31.0..) | 1.8 m between the crates and the heap | 2.6 m of bare wall and floor, Crucible column to crates |
| the walk behind Twin Barrel | a dead end against the heap (0.2 m gap) | open at both ends (1.1 m past the bench) |
| the back-panel walks behind the west and east rows | 1.15 m less a 0.28 m shelf | their full width, bare stone |

What went: the two installers' crates from between the Crucible and the lever (they stand at the bench's end now);
two barrels, a sack and a loose crate from the north-east corner; the three shelves of preserves in the machines'
back-panel walks (west wall z 24.5 and 27.15, east wall z 23.15); three of four puddles (one lay between the pillars
and rendered as a black hole in the floor); the coal heap shrank from 2.2 m (it ran under Ledger Lager) to 1.3 m in
its corner, four of nine lumps with it.

What stays, placed the way the room is used: the Crucible's alcove, the fuse box and conduit on the wall, the lever,
the bench in the north-east corner with the two Helvetia crates at its end, the wine rack flat against the south
wall's west half, the coal chute, its heap and the shovel in the south-east corner, the drain with one puddle, the
pipes, the hanging lamps and the NACHLIEFERUNG plate overhead.

Lanes (machine footprints from `MACHINE_FOOTPRINTS`): west row to the pillars 3.15 m, pillars to the east row 3.45 m,
Crucible to the north pillar 1.9 m, south pillar to the south row 1.75 m, the arch to the bay 1.66 m, the lever's
approach 2.6 m. No dressing collider stands in any of them; the only solids off the walls are the machines, the
Crucible and the pillars, which may not move.

**Left for the owner:** the vault is still a dense room, because twelve machines stand in it and its bay. If it should
breathe more, the lever is to move machines, not dressing (for example the south row's three into the Old Cellar's
barrel vault, which has the floor for them). Machine positions were out of bounds for this pass.

### The late-delivery bay (T-179)

Two machines, two opened crates in the corners beside the arch, a 3.8 m apron: nothing to thin. The olive crate
rendered as a plain green block; it has corner posts and a top and foot rail now. Its nine flat straw blobs are stalks.

### The Old Cellar

- **Coal room:** the guard's stool stood in the middle of the walk and his crate half a metre inside the wine
  cellar's doorway, both drawn without colliders. They stand against the east wall under his lamp now (clear of the
  ice chute's seal at z 5.9..7.5).
- **Barrel vault:** three small kegs stood loose at the corners of the barrel stack, on the training loop's turns
  (drawn, not solid). Gone.
- **Wine cellar:** a crate stood in the corner in front of two racks. Gone. The puddles left are the four under a
  drip and the one in the ice cellar.
- Unchanged: the racks, the casks on their cradles, the cage and everything in it, the root cellar, the ice cellar
  (the Cousins' room), the breach, both light wells.

## 2. The hay ("half baked")

Before: the hay pile was one 2 x 0.7 x 2.6 m hay-coloured block; a bale was a plain box with two dark strips; five
bales stood in the north door's lane without colliders (you walked through them); the loft's stack drew one course of
fifteen bales and three on top inside a 3.2 x 3.2 x 0.9 m collider (an invisible step round the three); the cover
bales were drawn smaller (0.9 x 0.45 x 0.5) than their colliders (1.0 x 0.47 x 0.6); loose hay was 0.5 x 0.12 x 0.3 m
blocks; trodden straw was flat dark rectangles that read as mats.

After (`props_hay.gd`):

- **A bale** is a bevelled box with blended normals (the edges read rounded), two dark twine bands standing proud all
  round it, a few stalks worked loose on top and at the ends.
- **A stack** is laid in courses that fill their collider exactly; each course turns the bales 90 degrees, every bale
  a touch out of line.
- **The heap** is a mound: a dome, sixteen lower lobes, clumps over them, a thin skirt, wisps lying down the slope.
- **Loose straw** is stalks strewn on the boards, not rectangles.
- **The pitchfork** has a handle, a socket, a head bar and three curved tines; it stands on its tines.

Where it is now:

- **Stable floor:** four bales stacked two high against the north wall east of the north door (`StableBales`, a new
  1.8 x 0.9 x 0.52 m collider), the bale that was forked open in front of them as the heap (no collider: the round-6
  ground spawn `Spawn_HayPile` rises out of it, unmoved at (22.5, 0, 23.7); `HayPuff6` still covers it), the fork left
  in it, stalks trodden toward the door, the stair foot, the stalls and under the bale drop. **Nothing stands in the
  north door's lane any more.**
- **Loft:** the stack is two full crosswise courses over `HayBales` (same collider, same place) with three bales of a
  third course in the corner (`LoftBaleTop1..3`, new colliders on top of the stack), hay dropped at its foot, the fork
  leaning on it. The six cover bales (`LoftBale`, unmoved, same size) are drawn at their colliders' size.
- The three library crates beside the loft's solid crate (0.7 m high, no collider) are gone.

## 3. Room by room

| zone | what was wrong | what changed |
|---|---|---|
| Taproom | the signals unit's three crates stood 0.7 m off the east wall and 1.6 m off the north one, without a collider, between the front door and the Garand | against the east wall under the portrait, solid (`TapCrates`, `TapCratesTop`, no_mantle); the Garand's chalk window is clear (WALLBUY_AUDIT) |
| Taproom | the "spare planks leaning by the west window" stood upright a metre out in the walk to the Old Cellar door, tipped along the wall and touching nothing | feet 0.3 m out, heads on the plaster, south of the window, north of Door 5 |
| Taproom | a tipped chair on the line from Door 2 into the room | half a metre nearer its table |
| Bar | the till was a 0.55 x 0.35 x 0.5 m brass block with a black lid: a plain box from the customers' side | a drawer base, the body, a sloped key bank, the indicator housing with a rounded top and price flags, an embossed plate toward the room, the crank |
| Hearth | the fire brush used an unknown material key ("straw"; a generator warning) | "hay" |
| Stair, hall, guest rooms, attic | every doorway, stair foot and stair head probed for dressing standing in it: only frames, trim and newels | nothing |
| Passage | clear | nothing |
| Stable | see section 2; a crate stood loose by the Tack Room crate spot without a collider | the crate is gone |
| Carters' Yard | the sledge lay across the open middle; the chopping block stood, without a collider, on the edge of the trodden path two metres out of the yard door; a cart wheel stood on its rim in the open, leaning on nothing; one snow drift lay under the Thompson's chalk (you stood in it to buy), another across the open south-east quarter | the sledge is pulled up along the south fence east of the gate; the block and its axe stand in the corner west of the door against the stable wall; the wheel leans on the woodpile; the drifts are against the wall east of the chalk and against the fence |
| Helvetia cellar, bay, Old Cellar | section 1 | section 1 |
| Grounds, wreck, roads | the night frames (front of the inn, the wreck, the crossroads, the field edge, the carters' road) show nothing stray; they are too dark to judge dressing in detail | nothing |
| Woodshed bank | no camera; the two whole-map probes (drawn pieces standing on a floor with no collider near; pieces in a doorway or at a stair foot) list nothing there | nothing |

**The yard and the horse:** the open ground is about 13 x 12 m between the well and its crate spot (x up to 13.9) and
the cart (x from 27), z 36..48, with the zip line's post (18.6, 36.2) and the woodpile against the stable wall the only
things on its north edge. With the sledge, the wheel and the drift off the middle, nothing lies in it (the drift along
the stable's south wall now covers x 23.1..25.6 only, east of the Thompson's chalk; it is drawn, not solid). A 2.4 m horse turns there with room to
spare; the tight spots are the 1.6 m fence gaps (the barricaded windows), which a horse should not use anyway. No
obstacle was added to the yard.

**Lit before the power:** the unlit frames (`24_cellar_vault`, `25_old_cellar_wine`, `26_old_cellar_cage`, the stable
and loft views, the taproom, hall and rooms) all read: the oil lanterns carry each room. Nothing was added.

## 4. Snags removed

- Drawn-but-not-solid pieces in lanes (you walked through them): the five bales in the stable's north-door lane, the
  signals crates, the leaning planks, the guard's stool and crate, the three kegs on the Old Cellar loop, the wine
  cellar's corner crate, the stable's loose crate, the loft's three crates, the yard's sledge, chopping block, cart
  wheel and the drift under the Thompson's chalk.
- Solid-but-not-drawn: the loft stack's upper course (0.45 m of collider with art only where three bales stood).
- Solids taken out of approaches: the crates between the Crucible and the lever, the north-east corner's heap.
- New solids, all against a wall and drawn at their size: `StableBales`, `LoftBaleTop1..3`, `TapCrates` /
  `TapCratesTop`, `CellarBenchCol` (with `CellarCrateCol` moved to the bench's end).
- A whole-map list of small colliders (footprint under 0.5 m or under 0.4 m high) found nothing new in a lane: fence
  and porch posts, the tower's legs, the zip line's post, the wreck's hull.

## 5. Not changed

Room shells, doors, spawn points, barricade windows, prices, wall-buys, perk machine positions, prompts, ladders, the
zip line, the tower, the survivors' posts, quest and egg objects (none stood in the clutter that moved), the cover
colliders in the loft (`HayBales`, `LoftBale`, `LoftCrate`).

## 6. Renders

Folders (git-ignored, left on disk):

- before: `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\.claude\worktrees\agent-a6a9ac3c9453d1801\morning\screenshots\u05\u15_before\`
- after: `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\.claude\worktrees\agent-a6a9ac3c9453d1801\morning\screenshots\u05\u15_after\`

Same file name in both folders unless noted (`NN_<camera>.png`; "bright" frames use the capture tool's work light, the
others are the room's own light before the power). Frames marked * are new cameras of this pass.

| what | frames |
|---|---|
| Helvetia vault | `24_cellar_vault` (unlit, from the stair mouth), `41_cellar_vault_n`*, `42_cellar_vault_ne`*, `43_cellar_vault_sw`*, `59_cellar_vault_s`*, `60_cellar_vault_e`*, `61_cellar_vault_w`* |
| the bay | `44_cellar_bay`*, `45_cellar_bay_back`* |
| Old Cellar | `25_old_cellar_wine`, `26_old_cellar_cage` (both unlit), `46_old_cellar_vault`*, `47_old_cellar_vault_ne`*, `48_old_cellar_root`*, `49_old_cellar_wine_e`*, `50_old_cellar_foot`*, `51_old_cellar_coal`* |
| the hay | `52_stable_hay`*, `53_stable_hay_close`*, `55_loft_stack`*, `56_loft_stack_close`*, `57_loft_rail_bales`*, `58_loft_gallery_bales`* |
| stable and loft | `19_stable_floor`, `20_stable_stair`, `21_hayloft_west`, `22_hayloft_gallery`, `23_hayloft_bay_down`, `54_stable_west`* |
| taproom and bar | `06_bar_hatch`, `07_bar_counter`, `08_bar_service`, `09_taproom_spawn`, `10_taproom_bar`, `11_taproom_hearth`, `12_taproom_window_n` (the till), `13_taproom_tables`; after only: `62_tap_ne_corner`* (the crates), `63_tap_west_walk`* (the planks), `64_bar_till`* |
| stairs, hall, rooms, attic | `14_stairs`, `15_upstairs_hall`, `16_room1_cousins`, `17_room2_gentleman`, `18_room3_josef`, `00_attic_stairhead`, `01_attic_east`, `02_attic_flight`, `03_attic_well` |
| yard and tower | `04_yard_tower`, `05_tower_deck`, `27_yard`, `28_yard_gate` (before: the sledge in the open); after only: `65_yard_door_corner`* (the chopping block), `66_yard_sledge`* |
| outside | `29_front_of_inn`, `30_wreck`, `31_road_crossroads`, `32_field_edge`, `33_carters_road` (night frames: they show nothing stray, they are too dark to judge dressing in detail) |

The five "after only" cameras were added after the change they show; their "before" is in the frames named beside
them. The first frame of a capture run carries the map's title card (`19_stable_floor` and `41_cellar_vault_n` in the
before set).

## 7. Checks

Regenerated with `godot --headless --path . --script res://gravelight/tools_src/gen_map00.gd`: WALLBUY_AUDIT clear
for all seven buys, 604 collision boxes (598), navmesh 1247 polygons and 1299 with the breach open (1249 / 1301).
`test_map00_art` NAV_FP re-set. The minimap is re-baked under WSL (`tools/wsl_godot.sh --path .
res://tools_src/bake_minimap.tscn -- --map=map00_crossroads`: the cellar, ground and upstairs floors changed; no POI
moved).

| check | result |
|---|---|
| `check_scripts` | 885 scripts, 0 failed |
| GUT `test_map00*` (alive, art, cellar_bay, fences, grounds, landscape, polish, t238) | 66 / 66, 8 scripts |
| GUT `test_mapdata` | 11 / 11 (after the minimap bake) |
| GUT `test_npc_navmesh`, `test_inn_survivors`, `test_machine_lore`, `test_capture_cams`, `test_world_objects*`, `test_ladders_data`, `test_interactable*`, `test_vfx` | 7 / 7, 6 / 6, 4 / 4, 3 / 3, 16 / 16, 3 / 3, 15 / 15, 8 / 8 |
| the facing runner (`tools/tests/test_interactable_facing.gd --maps=map00`) | PASS: 63 interactables, 0 failing (Ledger Lager and Overclock Cordial are reported UNSURE, not failed; no machine moved) |
| `probe_invisible_walls` on map00 | the same 100 lines before and after: none of the new colliders is uncovered |
| smokes `map00`, `map00_alive`, `map00_cellar_bay`, `ladders`, `bots_shop_m0`, `bank`, `polish`, `inn_opening_paths`, `inn_survivors`, `story_props`, `interact` | PASS |
| smoke `map00_loop` | FAIL once with two captures and another smoke on the machine ("no zombie from the edge spawns reached the player out in the field", a timed check; T-229 saw the same under load); PASS alone in 55 s |
| smoke `npc_walls` | FAIL on map00, **and the same failure on the scene as it was before this pass**: a squad bot stands pressed in the bar's service walk at (4.9, 0, 7.1) heading for a hold point in the still-shut Old Cellar (19, -2.7, 1.1), from t = 21..25 s for about 4 s. Not caused here and not fixed here (it is the bots' goal choice, `gravelight/bots/` is out of this slice); map01 passes |
| smoke `jakub` | no RESULT: twice it ran into the runner's 20-minute cap on the shared machine. In the run that got furthest (rounds 1 to 9 of 12) every line passed (the cage, the breakout, the gun, the fight, the revive) except "he kills the zombie with the coal shovel" (see below) |

**Jakub's shovel kill is a flaky check, on the old scene too.** The coal room is where the guard's stool and crate
moved (drawn only, no collider), so this was chased: a scratch probe that sets round 5 directly and watches the
breakout (`.smoke_logs/t238/probe_jakub_breakout.gd`, not committed) ran four breakouts per scene. This pass's scene:
4 of 4 ended with the kill. The scene as it was before: 3 of 4 (one burst the hinge and went straight to waiting, as
in the smoke's failing runs). One 330 s run of the real smoke on each scene passed the line on both. The breakout
needs the zombie within 2.5 m of him for three swings after the burst (`jakub_companion.gd` `_tick_breakout`); when
it is not, there is no kill event. Not a layout matter; left for whoever owns the companion.

## 8. Left as it is, and why

- **The vault's density** is the machines' (section 1): an owner's decision.
- **The bot pressed behind the bar** (`npc_walls`): there before this pass, in the bots' goal choice.
- **Drawn, not solid, on purpose:** the taproom's chairs and the guest rooms' (library props; a chair you catch on
  while backing away from a pack is the opposite of smooth), the hay heap (the ground spawn rises out of it), Frau
  Pohl's suitcase beside her table, sacks, snow drifts, the straw. A tipped oil drum lies beside the drum cluster in
  the far south-east field, outside the cluster's collider: left, nobody fights there.
- **Puddles** render as dark ellipses under the capture's Compatibility renderer. The ones left are under a drip (Old
  Cellar), at the drain (vault, bay) or the ice cellar's; if they read the same on the owner's Forward+ they want a
  material pass, not a layout one.
- **Night exteriors** were looked at but are too dark in the capture to judge small dressing; the two geometry probes
  cover them instead.
- **No horse-sized test** of the yard: the horse is another worker's; the numbers are in section 3.

## 9. A note on worktrees (for whoever runs the next pass)

This worktree's `assets/` are Git LFS pointer files and it has no import cache of its own. Copying the main
checkout's `.godot/imported` and its untracked `*.import` files makes it run and render. **Do not run
`godot --import` or an editor scan in such a worktree:** every pointer file reads as a changed, corrupt source, the
cache is rewritten with failed imports and 496 tracked `.import` files are marked `valid=false`. It happened here once
(importing the re-baked minimap PNGs); the tracked files were restored with `git checkout -- '*.import'` and the cache
copied again before the final checks. Nothing of it is in the commits.

## 10. Tools left in the tree

- `GL_GEN_OUT` (gen_map00): saves the scene somewhere else, so a `GL_PROBE_BOX` inventory run never rewrites the map
  while a capture or a smoke is reading it. Example: `GL_GEN_OUT=user://probe.tscn GL_PROBE_BOX="24,-3.3,19,36,-0.2,31"`.
- `gravelight/tests/unit/test_map00_t238.gd`: the hay colliders, the north door's lane, the thinned cellar, the
  taproom crates, the bevelled mesh.
