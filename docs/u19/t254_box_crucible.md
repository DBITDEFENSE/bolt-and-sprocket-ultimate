# T-254 (UPDATE 19): the Requisition Crate as a set-piece, the Crucible built into its room

Branch `claude/u19-box-crucible`. The owner, 2026-11-14: "make the mystery box better and the crucible more merged and
imersed". An art / presentation pass: no price, odd, timing, prompt, use box, navmesh or machine collider changed
(tested, see the end).

## What was weak (the before renders, `docs/captures/u19_box_crucible/before/`)

The crate. The model itself was fine (planks, straps, rope handles, the LOS stencil), but nothing happened round it:
shut, it was a dead box beside a small lantern; open, the inside was a flat violet slab and the cycling gun a small flat
violet silhouette you could not tell from the next one; the offer was the gun and a name you could not read against a
lit wall; an empty spot was a cold lantern on a stick (its chalk footprint is 4 mm high and lies UNDER the maps' drawn
floors: it has never been visible); the only locator was a hard dark-blue cylinder for 20 s after a move.

The Crucible. It stood on its plinth in front of its wall with its flue ending in the air wherever the ceiling was
higher than 3.3 m, nothing round it took its heat, its mouth glowed the same orange with and without power, the forge
was a brightness ramp with glowing balls for sparks, and what came out was a violet bar.

## The crate (`gravelight/world/mystery_crate.gd`, `crate_art.gd`, new `crate_fx.gd`)

- **The locator.** A column of pale ashlight, 60 m, widening as it climbs, soft-edged, not eaten by fog
  (`CrateFx.beacon`, one unshaded additive cylinder: 28 triangles, no light, no shadow). On where the crate is, off
  everywhere else, brighter for `move_beam_seconds` after a move (the old beam's job). Each spot probes the sky over
  itself once at load (rays up through the world layer): under a roof the column starts above the LAST thing hit, so it
  stands on the roof and never in a room, this one or the one upstairs; under the open sky it starts at the crate. It
  follows `CrateManager.location_index`, which co-op already replicates, so every peer sees the same column. Indoors the
  lantern's halo, the light under the lid's edge, the pool of ashlight on the floor and a quiet hum (`crate_hum`, 11 m)
  lead you the last steps.
- **Shut.** A line of violet light under the lid's edge and a soft pool of it on the floor, both breathing; the
  unit's own word for its contents stencilled on the lid through SurfaceText (`RÜCKGUT`, "returned goods": the lore's
  Loot Allocation Unit dispenses returned inventory; invented, no maker). Outdoors on the snowy maps (crate.json
  `look`: map00, map01) snow lies on the lid and is banked against the spot.
- **The roll.** The hasp gives (a jolt), the lid heaves up and rocks once against its stays; the snow slides off;
  light stands out of the box (`CrateFx.spill`, a soft oval shaft, `crate_spill`); the guns rise out of the straw as
  the REAL models in their own materials under a violet rim (the old flat ghost hid what they were), one holder per
  id for the opening instead of a rebuild per swap. The settle: a ring runs out, the light flares, the gun kicks,
  `crate_settle`; the offer hangs over a bed of light with its name on a dark card (readable against a lit wall), sinks
  back toward the box over its last 4 s and gutters in the last 1.5 s; the take or the timeout drops the lid with a
  thud and a puff of dust (`crate_close`).
- **Herr Tamtam** (the 3.6 s scene, unchanged in length): he pops up out of the straw and turns as he drums; a pool
  of light opens in the floor; at 2.0 s the lid slams on him; the crate rattles on its skids and goes down through the
  pool (`crate_sink`) while its lantern gutters out and the locator fades; the pool closes. At the new spot (every
  peer, from the relayed `crate_moved`) the pool opens, the crate comes up through it with a knock (`crate_arrive`),
  the lantern catches, the locator flares. The new spot is usable from the first frame, as before.
- **An empty spot** now reads as one: the cold lantern, the chalk corners and cross redrawn 2.4 cm up where a floor
  shows them, the scrapes of the two skids, loose straw, a splinter, the broken seal, and hairline cracks with
  Nachtglas still breathing in them; outdoors the bare ground inside the snow bank.

## The Crucible (`gravelight/world/crucible.gd`, `crucible_room.gd`, `data/gravelight/crucible_rooms.json`)

- **The room probes itself.** Two physics frames after load `CrucibleRoom` moves to the Crucible node's transform and
  casts rays on the world layer: the wall behind (six rays above 1.7 m, the lower median), the ceiling over the machine
  and the housing (the highest hit), the side walls along the back wall. Then it rebuilds its dressing once. Where no
  physics runs (tests, the survey) the json's new `room` entry gives the same four numbers.
- **The housing** (`surround` in the json, `_surround`): masonry, riveted plate, concrete or hull plating from the
  machine's rear third back INTO the wall and up INTO the ceiling; a base course, quoins or seam strips, a relieving
  arch over the firebox, iron straps that clamp the drum to it, a hood that corbels out over the firebox and takes the
  flue up through the ceiling (a collar where the flue meets a low ceiling, an elbow back into the housing under a high
  one), a foundation slab the plinth is keyed into, ash and clinker in front of the mouth, the fire irons against the
  flank, two gauges whose needles lie on their pins cold, tremble at idle and climb with the forge; soot on the hood,
  under the ceiling and on the floor (one alpha mesh); a wisp of steam at the flue while the fire is in.
- **It never blocks a path.** The housing is only as wide as stays off the baked navmesh (`_fits_nav`, stepping
  narrower; where the wall is further back than the plinth the part behind may be wider: a shoulder), it is solid
  (one or two boxes on the Crucible body's layers) only where it is drawn, and a machine that stands free of any
  wall, or with walkable floor behind it, gets a back-plate and a stack on its OWN plinth instead (inside the model's
  footprint, no collider added). The hood and the flue are over head height.
- **Anchors.** Any coordinate in the json may be `"ceil-0.04"`, `"back-0.3"`, `"left+0.5"`, `"-w-1.35"`, `"top"`:
  Map 0's pipes, cable, lamp, key light, rack and form now hang from the probed ceiling, wall and housing.
- **Alive** (`crucible.gd`, all built after `ArtCollider.fit` so none of it is ever collided with). Cold: the mouth is
  dark (it was lit orange by any lamp), the iron ticks as it settles (`crucible_tick`, only with a camera within 14 m).
  Powered: the fire breathes in the mouth and on the floor in front (one unshadowed warm light), a few sparks drift up.
  Fed: `crucible_feed`, the fed weapon's own model slides into the mouth; a hammer works inside, quickening
  (`crucible_clank` at 7 fractions of `forge_seconds`), the body jolts and spits sparks with each blow (real sparks:
  the old ones were 5 cm glowing balls), the mouth climbs to 5x, not the 8x that blew out. Done: `crucible_out`, the
  real upgraded model comes out of the mouth to where the violet bar used to hang, over a warm halo, its name on a
  dark card.

Per map (the `fiction` line in each `surround`):

| map | style | what the probe finds | result |
|---|---|---|---|
| map00 Crossroads cellar | brick | wall 0.8 m behind, vault 3.0 m | chimney breast with stone quoins, hood into the vault |
| map01 Kaltenbrunn Core Vault | plate | wall 2.75 m, the navmesh runs behind (and under) the machine, 12 m cavern | riveted back-plate and a stack on its own plinth |
| map02 Totenhafen, U-1047 bow | hull | bulkhead 2.0 m, deckhead 2.6 m | plated into the bulkhead, full width behind the machine, flue collar in the deckhead |
| map04a Thalbach Messbunker | concrete | wall 1.5 m, slab 4.0 m | board-marked concrete housing with a shoulder, steel lintel, flue up through the slab |
| map04b der Kranich | cradle | cargo, navmesh all round | deck plate, capped flue (nothing built round cargo) |
| map04c Groom Lake | concrete | its bay behind it | back-plate and capped flue on its own plinth |
| map04d Mondlicht | chrome | alcove under the chrome portal | chrome back-plate inside the portal, capped flue |

## Calls I made

- **Runtime scripts and data only.** `gen_map00.gd`, `map00.tscn` and every other generator and scene are untouched.
- **Where a wall cannot be reached without closing walkable floor, the machine is not walled in.** Kaltenbrunn's
  Crucible has baked navmesh behind and under it, the Kranich's is cargo, Groom Lake's and the Moon's have their bays.
  They get what fits on their own plinth. Building them in properly needs their generators (a NavBlock behind them).
- **The housing has a collider** (the brief allows the walk-blocking shape to change only where new geometry is
  drawn): it is the drawn mass, on layers 1 and 9. It is off the navmesh by construction and by test.
- **The offer's name on a dark card.** T-247's FLOAT text was unreadable against a lit wall or the white-hot mouth;
  the card is a soft dark quad behind it, not an outline.
- **No rim overlay on the taught weapon** at the Crucible: the upgraded weapons' shader moves their surface and a
  second pass speckled over it in the first render.
- **`crate_settle` replaces the `buy` cash sound at the settle** (the `crate_result` event sting still plays), and
  `crucible_feed` / `crucible_out` replace `door_open` / `buy` at the Crucible.
- **test_crucible_rooms**: the draw budget is 30 (was 24: the housing's two materials, the soot, two needles), and the
  housing's part on the machine's own plinth is not counted as "a prop on the navmesh" (Kaltenbrunn bakes navmesh
  under its machine).
- **Snow per map is data** (`crate.json` `look`), not a guess from the sky: Totenhafen has rain, the Moon has none.

## Found, not changed (for the lead)

- **An invisible bar in front of the Crucible.** `ArtCollider.fit(self, self, body)` (T-188) also hulls the hidden
  0.7 x 0.12 x 0.08 m violet offer bar at (0, 1.2, -1.5) and the flat mouth quad: a chest-high collider 0.55 m in front
  of the use box on every map (measured: the fitted body has 126 hulls; the last is the bar, x -0.35..0.35,
  y 1.14..1.26, z -1.54..-1.46; the one before it the mouth quad). I left it (colliders do not change in an art pass) and hid the bar's mesh only; the fix
  is one line (`fit(self, _art, body)` or skip `_float`).
- Kaltenbrunn's Crucible still has no NavBlock (T-175's open item): the bots can plan through it.
- The model's chalk footprint (`Spot` part, 4 mm) is under the drawn floors on Map 0; the empty spot now draws its
  own. The GLB could lose it.

## What the lead must do at merge

- **Once T-251's new Crucible room exists on Map 0**: nothing is needed for the housing, the flue, the soot, the
  anchored pipes, lamp, key light, rack and form (they follow the node and the probe). Update in
  `crucible_rooms.json` `maps.map00`: `room` (back / ceil / left / right of the new room: the fallback for tests and
  the survey; `smoke_u19_box` prints the probed numbers), `zone` if the room is a new zone, and the three pieces and
  one light that are still placed by hand for the old alcove: the `KÜHLANLAGE` notice at `[-1.7, 0.78, 0.185]`
  (it is on the delivery crate gen_map00 draws there), the `ledger` at `[-5.8, 0, 0.45]` (on the installers' bench),
  the `cable`'s end `b`, and the work light at `[-4.6, 2.3, 0.2]`. If the new room has walkable floor right behind
  the machine it gets the stack instead of the breast: stand it with its back to a wall (within 2.6 m, no navmesh
  between) and the breast builds itself. `test_crucible_rooms` checks the json's fallback layout against the
  regenerated navmesh.
- `data/gravelight/audio.json`: one new block of 10 keys at the END of "sounds" (the Sherman pack's way), so a
  three-way merge does not meet it.
- `crate.json` gained a `look` block (presentation), `crucible_rooms.json` a `room` and a `surround` per map.
- T-252 (textures): the housing uses the Mats keys `brick_cellar`, `cellar_stone`, `machine_grey`, `bunker_concrete`,
  `concrete`, `u_interior`, `chrome_worn`, `loco_black`, `coal`, `iron`, `brass`, `steel`, `copper`; the crate's and
  the soot's light and stains are their own shaders in `crate_fx.gd`. Nothing in the shared library was edited.

## Files

- `gravelight/world/crate_fx.gd` (new): the beacon, spill, halo, ring, pool, rim, soot shaders and helpers.
- `gravelight/world/mystery_crate.gd`, `crate_art.gd`, `data/gravelight/crate.json` (`look`).
- `gravelight/world/crucible.gd`, `crucible_room.gd`, `data/gravelight/crucible_rooms.json` (`room`, `surround`,
  anchors on map00).
- `gravelight/tools_src/gen_audio_u19_box.py` (new) -> `gravelight/audio/sfx/world/crate_{spill,settle,close,sink,arrive,hum}_01.ogg`,
  `crucible_{tick_01..03,feed_01,clank_01..03,out_01}.ogg`: 14 files, 0.31 MB, synthesized (our own work);
  `data/gravelight/audio.json` (+10 keys).
- `gravelight/tools_src/shots_u19_box.gd/.tscn`, `shots_u19_probe.gd/.tscn`, `smoke_u19_box.gd/.tscn` (new), README.
- `gravelight/tests/unit/test_t254_box_crucible.gd` (new, 6 tests), `test_crucible_rooms.gd` (budget, own plinth).

Cost: no texture, no model file. The crate adds per spot 1 locator (28 tris), the light effects (about 150 tris, drawn
only when on), the empty-spot marks (about 600 tris, only where the crate is not), no new light (the old glow light is
now on at 0.2 where the crate stands). The Crucible room adds the housing (about 500 to 900 tris in 2 to 4 material
meshes), one soot mesh, two needles, one particle wisp, and the Crucible one unshadowed light.

## Renders (`docs/captures/u19_box_crucible/`, WSL + Xvfb, Compatibility renderer, looked at)

Tool: `gravelight/tools_src/shots_u19_box.tscn` (the same cameras for `--label=before` and `after`), saved as JPG.

- `before/` (43, master's look, maps 00 / 01 / 02) and `after/` (77, all seven maps), `<map>_<shot>.jpg`:
  - crate (map00): `crate_idle`, `crate_idle_close`, `crate_open` (0.35 s in), `crate_roll` (2.4 s in), `crate_settle`,
    `crate_offer`, `crate_drummer`, `crate_sinking`, `crate_empty`, `crate_empty_close` (the Hearth spot), `crate_well_idle`,
    `crate_well_mid` (the Well spot, outdoors, snow), `locator_well_a/b/c` and `locator_hearth_a/b` (from across the map
    at night: `locator_hearth_b` and `locator_well_a` are the ones to open: the column over the inn's roof and over the
    yard; before, the only beam was the 20 s one after a move), `locator_hearth_room` (indoors: no column in the room).
  - Crucible (every map): `crucible_off_front/wide` (map00, before the lever), `crucible_idle_front/wide`,
    `crucible_feed_front` (0.3 s: the fed weapon on its way in), `crucible_forge_front` (3.5 s), `crucible_out_front`,
    `crucible_offer_front/wide`.
- `probe/` (6): the same machine in a bare test cellar (`shots_u19_probe.tscn`) against the north wall (1.3 m behind,
  3.4 m ceiling, a stone wall: the breast is built of that stone), against the east wall (0.9 m, 2.9 m, concrete) and
  free on the floor (the stack on its own plinth): the proof that the room finds its wall after a move.

What I saw and changed on the way: the first light shaft was a hard-edged white box (now a soft oval that fades where
it turns from the eye); the first snow banks read as sacks under the warm lantern (now only a blanket on the lid and a
low bank behind); the empty spot's marks at 4 mm were under the floor like the model's chalk (now 2.4 cm up); the
floor glow's falloff put all its light under the crate (a flatter disc); the first housing was dark bunker concrete in
a tan bunker (it now takes the material of the wall it is built against, read off the ray's hit); the soot on the
housing read as a hole (weaker, and on the hood's lip); the offer's name was lost over the white-hot mouth (it hangs
under the weapon on a dark card).

Honest limits: on Map 0 the present alcove is small and dark and the machine already half stood in its wall, so the
difference there is the hood, the quoined jambs, the slab, the fire and the forge, not a new silhouette (T-251's
room will show it better; `probe/` shows what it does in an open room). On Kaltenbrunn, the Kranich, Groom Lake and
the Moon the machine cannot be walled in from the dresser without closing walkable floor: they got the flue, the
back-plate, the slab, the soot and the life, not a wall. The renders are the Compatibility renderer under llvmpipe;
the owner's Forward+ will bloom the seam light and the mouth a little more. The taught weapon on offer is dark with
its violet veins (the game's own look for a taught gun); it reads by its halo, its size and the name card.

## Tests

- `check_scripts`: 942 scripts, 0 failed.
- Unit tests of the area (GUT, headless): `test_t254_box_crucible` 6/6 (the probe in a test cellar against one wall,
  moved to another wall with another ceiling, stood free; the housing off a navmesh it is given; the wall's material;
  anchors; the Crucible's collider is the fit of its art alone; the crate's locator and snow follow the sky; the old
  numbers), `test_crucible_rooms` 5/5, `test_world_objects_visual` 16/16 (art on / off: identical colliders and use
  areas), `test_art_collider` 3/3, `test_crate` 7/7, `test_interactable_facing` 15/15, `test_machine_lore` 4/4,
  `test_capture_cams` 3/3.
- The T-219 facing check (`tools/tests/test_interactable_facing.gd`, all seven maps, from the scene files): unchanged,
  as it must be (no scene was touched): map00 63 interactables, 42 OK, 0 backwards, 0 sideways (Crate_GuestBed UNSURE
  as before); the UNREACHABLE rows are the known ones (Kaltenbrunn's three desk pickups, Totenhafen's two pen doors,
  Groom Lake's generator and gimbal part).
- Smokes (`.smoke_logs/u19_box/`): `smoke_u19_box` PASS (new: a real crate roll, the move, a real Crucible teaching,
  the probe: wall 0.80 m, ceiling 3.00 m, housed, 0 samples on the navmesh), `smoke_map00` PASS, `smoke_coop` PASS,
  `smoke_companion_perks` PASS, `smoke_bots_shop_m0` PASS (three bots and Trudi each taught a gun at the Map 0
  Crucible with the housing round it), `smoke_bots` FAIL, 3 runs of 3, each with the one failure
  `P4 never refilled its upgraded gun at an ammo box`: after its teaching the bot stands on the taproom floor at
  about (15, 0, 15), straight above `AmmoBox_Cellar` (14.6, -3.2, 15.5, "3 m"), action `resupply`, for the whole 90 s
  window (in one run it bought the refill at t = 708 s, too late). **Not T-254's:** I ran the same smoke with master's
  `mystery_crate.gd`, `crate_art.gd`, `crucible.gd`, `crucible_room.gd`, `crucible_rooms.json` and `crate.json`
  checked out over the branch: the same failure at the same spot
  (`.smoke_logs/u19_box/smoke_bots_BASELINE_master_runtime.log`). The Crucible phase of the smoke passes on the branch
  (two bot teachings inside 100 s, the gun taken back). So on this machine it is not intermittent at 9c416e22: a bot
  picks the ammo box that is nearest through the floor. For the bots' owner.
- Full GUT suite: 2336 tests (master's 2330 + the 6 new), 2335 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised did not assert`), 80,989 asserts, 0 script errors, 573 s.
- `python -I tools/assets_manifest.py --check`: current (no asset folder added; the sounds are under
  `gravelight/audio`, synthesized).
- Not run: a Forward+ (GPU) run, by the rule; the web build; a real two-machine co-op session (the mirrored calls
  `_net_open`, `_close`, `_forge`, `_offer`, `_reset` and the relayed `crate_moved` are the ones every effect hangs
  on, and `smoke_coop` passes).

## Open items

- A quench trough, a drip and a conduit run to the power were in the brief's list; the housing took the time. A
  trough is a standing prop and wants a per-map spot off the navmesh (a `pieces` entry, kind to be added).
- The crate's model (the GLB) is as it was: the pass is what happens round it. A re-model (deeper plank relief, dents,
  a broken board) is a Blender job (`tools_src/blender/world/requisition_crate.py`).
- Kaltenbrunn, the Kranich, Groom Lake, the Moon: a NavBlock behind each machine in its generator would let the
  dresser wall them in (set `max_depth` back to the default on map01).
- The owner should look at both in a real run: the locator's strength at night (`BEACON_IDLE` 0.3 in
  `mystery_crate.gd`), the seam light, and the Map 0 Crucible once T-251's room stands.
