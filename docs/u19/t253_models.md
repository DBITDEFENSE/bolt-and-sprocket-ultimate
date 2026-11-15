# T-253 (UPDATE 19): more detailed models: the tank, the aircraft, the wagon

The owner (2026-11-14): "Make the textures for the maps higher quality aand the models more detailed. snow sky planes
tanks etc ..." This is the models' part. Branch `claude/u19-models`, cut from `master` at 9c416e22. An art pass:
no gameplay number, collider, hitbox, navmesh, timing or prompt was changed.

## 1. What was done, in one table

| Model | Where it is seen | How it is built | Triangles before | Triangles after | Done |
|---|---|---|---|---|---|
| **The Sherman** | the Inn, rounds 30..40, the players stand next to it | code (`ShermanMesh`, `ProcKit`) | 30,972, no levels of detail | 44,658 within 38 m; 18,670 beyond 48 m | rebuilt, new paint (section 2) |
| **The dive bomber** | the Inn, round 40 | code (`StukaPlane`) | 3,844 | 8,194 | rebuilt, camouflage and crosses (section 3) |
| The air raid's bombs | the Inn, round 40 | code (`StukaPlane.bomb_mesh`) | 496 each | 560 each | lathed body, a carrying band |
| **The sky's six aircraft** (bomber, fighter, Mosquito, Il-2, Pe-2, night fighter) | the sky of the Inn, Kaltenbrunn, Totenhafen, the menu | code (`PlaneModels`), at run time | 144..480 (boxes and tubes) | 428..1,048 | reshaped (section 4) |
| **The farm wagon** (`Props.cart`) | the Inn x3 (the hay wagon, the road cart, the yard cart), Totenhafen x1 | code, **baked into the map scenes** | 444 in 17 pieces | 3,216 in 202 pieces | rebuilt (section 5); shows after the maps are regenerated |
| **The crate** (`Props.crate`) | about fifty places: the Inn, Kaltenbrunn, Totenhafen, Groom Lake, the far landscape, the menu | code, baked | 24 | 180 | framed (section 5); same |

Everything else was looked at and left; the list with the reasons is section 6.

## 2. The Sherman

Kept in code, not moved to Blender. The rig drives the model part by part (the hull rocks, the turret and the gun lay,
twelve wheels, six rollers, the sprockets and the idlers turn, 168 links run round the loop as two MultiMeshes), and the
event, the co-op puppet, the wreck and the tests all reach those parts by name. A GLB would have had to be cut into
the same parts and re-rigged in code anyway; building on `ShermanMesh` kept every one of those contracts and let the
track path, the wheel places and the muzzles stay the constants they were. What the model lacked was shape and surface,
and both could be given to it where it stood.

**Shape** (`gravelight/world/sherman/sherman_mesh.gd`, rewritten; `proc_kit.gd`, extended):
- The welded upper hull is one side profile (glacis, roof, the rear plate sloping out, the sponson floor) pushed
  across with its side plates' rims chamfered, weld beads where the plates meet, applique plates over the ammunition
  racks, the sponsons' bolt strips. The final drive housing is the rounded cast nose with its ends drawn in, the two
  bolted flanges, and the bolt strip that joins it to the glacis.
- On the glacis: the bow machine gun in its ball mount, the headlights (lit lenses) in their brush guards, the siren
  in its guard, the gun's travel lock folded down, three spare links on their bar, the towing shackles. On the roof:
  the two hatches with hinges, handles and a periscope in each door, the fixed periscopes with wire guards, the vent,
  the lifting rings. The engine deck: two grille doors with slanted slats and handles, the centre plate, four filler
  caps. The rear: the air cleaners with their bands and pipes, tail lights in guards, two engine doors with hinges and
  handles, the exhaust deflector's slats, shackles, the pintle.
- Stowage: a lumpy tarp roll under three straps, three jerrycans with their pressed crosses and handles under a rack
  strap, a lashed crate, two ammunition boxes, the axe, the shovel, the crowbar and the sledge in their clamps, the tow
  cable sagging between its clips along the left side. On the turret: two bedrolls strapped to a rail on the bustle, a
  pack, three spare links on each cheek.
- The turret is lofted through fifteen eased sections (it was eight), with the bolted rotor shield, the commander's
  cupola (six vision blocks, the two doors open with their pads, the dark of the opening), the loader's hatch, two
  periscopes, the vent, four lifting rings, the pistol port, the antenna, and the .50 with its cradle, cover, barrel
  support, spade grips and ammunition can. The 75 mm has its collar, recoil sleeve, taper, muzzle swell and bore.
- The running gear was wrong and is now an M4's: **single** road wheels (they were drawn as twin wheels) with a dished,
  ribbed disc; sprockets with two rings of 13 real teeth on a drum; the track link has its **guide horns on the end
  connectors**, outside the wheels (it had one centre horn), and the chevron. Bogies: the cast bracket both sides of the
  wheels, the volute springs' housings, arms, axles, the skid, the roller's arm; the final drive's housing with its bolt
  circle; the idler's bracket and adjuster.
- Snow: fourteen low drifts where the wind leaves it (fenders, the tarp, the roof's corners, the bustle).

**Surface**: every painted part now uses one shader, `gravelight/world/sherman/vehicle_paint.gdshader` (its body is
`vehicle_paint.gdshaderinc`), with two
512 px tiling textures of our own (`assets/ours/world/vehicle_paint/`, made by
`gravelight/tools_src/gen_vehicle_paint_tex.py` from filtered noise; no photograph): olive drab with broad grime, rain
streaks down the upright plates, paint chipped to metal (first along the chamfers, which the kit marks in the vertex
colour), frozen mud up from the tracks, **snow on whatever faces the sky** (in world space: it stays on top as the
turret turns), a fine steel grain. It is sampled in the part's own space, so nothing slides as the tank drives. The
stars are worn through to the hull. The wreck is the same shader burnt: scale, rust and ash, no snow, the lying snow
gone. The tank's own materials: nothing of the shared wall and ground library is used or edited (T-252's ground).

**Levels of detail**: the bolts, weld beads, handles, guards, clamps and the cable are a second mesh per part, drawn
within 38 m (5,000 triangles). Beyond 48 m the wheels, rollers, sprockets and idlers are plain drums and each link a
slab: 18,670 triangles for the whole tank. Near, it is 44,658: over the 40,000 the order named, by the 168 links
(14,112); said plainly rather than hidden. A pixel of the paint shader costs ten texture reads.

**Night**: the tank stood black against the Inn's night in T-249's frames. Measured in this pass's own frame at 3 m
(8-bit values, the same camera each time): the hull's side 2 (already with a first lift of 0.36, which changed
nothing), the night sky 2, the moonlit snow beside it 55. Three
things now carry it: the snow on its upper surfaces; a `HeadLamp` (one shadowless spot from the bow lighting the road
ahead of it, with lit lenses; removed with the crew lamp when it is wrecked); and `night_lift` in the shader: a little
of the paint's own colour given back as emission, weighted like light from the sky (more on what faces up, a little
blue) and pressed flat for pale paint so the star does not glow. Its strength is one constant,
`ShermanMesh.NIGHT_LIFT` (the wreck takes half; 0 turns it off). It was set by measuring, not by eye: the Inn's grade
is steep in the dark, so 2.0 moved the hull's side only from 2 to 5, and 5.0 put it at 55, as bright as the snow (a
tank lit from inside). **3.2 is what ships: the hull's side at 23**, under half the snow, the star at 73. T-249's
`CrewLamp`, the exhaust and the wreck's fire and light are as they were.

**Contracts kept** (all asserted in `test_u19_models.gd`): `ShermanMesh.part / instance / material(key, burnt) /
track_path / wheel_centres / roller_centres` and every constant; the nodes `Body`, `Body/Turret`, `Body/Turret/Gun`,
`TrackL`, `TrackR`, `Exhaust`, `CrewLamp`, `HullBody`, `AttackPoint0..9`, `wheel_N` ...; the two collider boxes
(2.62 x 1.75 x 5.9 and 1.9 x 0.85 x 2.1) on the map-edge layer; `muzzle()`, `coax()`; the wreck. `sherman_tank.gd`
changed in three places only: the track's MultiMeshes (near and far, both laid by the same loop), the wreck's
materials (`ShermanMesh.burn`), the head lamp. Nothing in `sherman_event.gd`, `air_raid.gd`, the data or the net code.

## 3. The dive bomber

Also kept in code (one mesh that flies a path; nothing to gain from a file). `stuka_plane.gd`'s model half is new,
its flight half untouched:
- The fuselage through twenty-one sections (eleven, eased), the chin radiator and its mouth; the inverted gull wing
  with the separate flap and aileron hung under its trailing edge on their brackets (the type's mark); the trousered
  gear with real wheels and a four-bladed siren on each leg; the slatted dive brakes; two small bombs on racks under
  each wing; the tailplane on two struts a side, the fin, the tail wheel; the greenhouse with hoop frames, three
  longitudinals and sills, **the pilot and the gunner under it**, their seat armour, the gunner's gun; the aerial mast
  and its wire to the fin; a pitot. The airscrew has a spinner and three twisted blades in a faint disc.
- Paint (the same shader, its `scheme` on): two dark greens in straight-edged fields over a pale blue underside, panel
  lines, a yellow band round the rear fuselage, and **plain straight-armed crosses** (black with a white edge) on and
  under each wing and on each side of the fuselage. They are drawn by the shader from the model's own coordinates, so
  they cannot be distorted by the wing or flicker (T-249 dropped its cross because the geometry one read wrong on the
  gull wing). **No swastika, no unit code, no other mark; the fin is plain.**
- Against the night it was only its exhaust flames: the Inn's fog (density 0.016) and its grade swallow anything dark
  60 m up. Its paint is now the shader's sky variant
  (`vehicle_paint_sky.gdshader`: the same body, `fog_disabled`, as the sky's other aircraft have always set
  `disable_fog`) with an even night lift, `StukaPlane.NIGHT_LIFT`. Measured the same way (the wing's blue channel as it
  pulls out over the yard): 6 at 1.0, 113 at 4.0 (a lit model aeroplane), **50 at the 2.2 that ships**: a pale shape
  with its crosses, plainly a dive bomber, still darker than the snow. The flames and their two lights are kept.

A call made here: `docs/ART_FACTIONS.md` forbids real Nazi symbols; the night fighter of T-212 carries "no insignia
of any kind" and T-249's dive bomber had "no national markings at all". The order for this pass asked for plain crosses and nothing else. The straight-armed
cross is a military aircraft marking still in use, not one of the forbidden symbols, and the Soviet aircraft and the
Sherman carry their stars, so it is on. **One switch turns it off**: `StukaPlane.CROSSES = false` (the aircraft is then
unmarked, as T-249 had it). For the owner to confirm (NEEDS_DEVIN).

## 4. The sky's aircraft

`gravelight/world/landscape/plane_models.gd`: the six silhouettes that cross the sky of three maps and the menu were
boxes on a tube. Each is now drawn from a short table: a lofted fuselage, a tapered wing and tailplane with dihedral,
shaped fins, cowlings with spinners and a three-bladed airscrew, glazing as low blisters, the Il-2's radiator bath and
gear fairings, the night fighter's antenna array; the Soviet pair carry real five-pointed stars (on and under the
wings, on the fins) where they had red slabs. Same functions, same surfaces in the same order (airframe, glow, stars),
span 1, still under 1,200 triangles (`test_u12_aircraft` holds). They are built at run time: the change is live on
every map without regenerating anything. The German night fighter stays unmarked.

## 5. The wagon and the crate (shared library, baked)

`gravelight/world/props.gd`:
- `Props.cart` was a slab, two side boards and two discs. It is a farm wagon: four spoked wheels (twelve felloes, an
  iron tyre, ten spokes, hub and cap; the front pair smaller), two axles, the reach pole, five bed boards on three
  sills, end boards, ladder sides leaning out on their stakes, the drawbar with its swingletree and braces, the bales
  and loose hay. New helper `Props.wagon_wheel`.
- `Props.crate` was a cube with one band: now the planked box with battens along its twelve edges and a brace across
  each flank. The stencil's place is unchanged.

Both stay inside the boxes they had (asserted: the wagon within its 1.9 x 3.0 m collider, the crate within
1.04 x 1.0 x 1.04 of its size), so no collider or navmesh moves. **They are baked**: they show only when a map is
regenerated. The Inn will be (the lead regenerates map00 after the merges: three wagons, fifteen crates). Kaltenbrunn,
Totenhafen and Groom Lake get them whenever their generators are next run (T-252 may; nobody else should).

## 6. Inventory: every vehicle and big model, and what was left

Baked = built by a generator into the map's scene (a change needs the map regenerated, which only T-251 / the lead
(map00) and T-252 (the others) may do in this update). Triangles are given where the model is a mesh of its own; a
baked one is merged into the map's per-material meshes and has no count of its own.

| Model | Map | Built by | Kind | Left because |
|---|---|---|---|---|
| C-47 wreck "GRAVELIGHT ONE" | the Inn | `tools/c47/*.py` (Blender) -> `assets/ours/world/c47_crashed/model.glb` | GLB, 60,301 tris, 3 LODs, its own skin / decal / impostor shaders | already the most detailed model in the game (T-211); rendered and looked at for this pass (section 8) |
| C-47 intact | tests only | same -> `c47_intact/model.glb` | GLB, 37,811 | not in the game |
| The C-47's hull colliders and debris boxes | the Inn | `gen_map00.gd` `build_wreck_hull`, `build_c47_debris`, `_dress_wreck` | baked | T-251's file; colliders |
| Der Kranich, inside (bay, body, wings, nacelle, cockpit, Kanzel) | map04b | `tools_src/blender/world/kranich_shell.py` -> seven GLBs | GLB, 7,954..22,458 each (95,854 together) | detailed Blender work of UPDATE 12/16 |
| Der Kranich, outside (the 268 m wing, engines, masts) | map04b | `gravelight/world/map04/kranich_exterior.gd` (1,134 lines) | run time | detailed; out of reach in the time |
| Der Kranich parked | map04a | `gen_map04a.gd` `_dress_kranich` + `GenDetail.flying_wing_mesh` | baked | lofted already; needs a regenerate |
| Der Kranich crashed | map04c | `detail_map04c.gd` `kranich_shell`, `torn_wing`, `torn_ribs` | baked | lofted already; needs a regenerate |
| Trucks x3, utility car, cannibalized bomber, LANTERN rocket, gantry | map04c | `detail_map04c.gd` `truck` (63 lines), `utility_car`, `bomber` (56), `lantern_rocket` | baked | **crude (boxes); the next ones worth doing**; needs a regenerate |
| Flatcars, gantry cranes, wing skeletons | map04a | `gen_map04a.gd` `_flatcar`, `GenDetail.crane_gantry` | baked | needs a regenerate |
| Arriving train, test jet | map04a | `thalbach_life.gd` | run time | distant set dressing |
| LANTERN capsule | map04d | `gen_map04d.gd` `_capsule` | baked (lathed) | fine |
| U-1047, the dead U-boat offshore | Totenhafen | `detail_map02.gd` `type_vii` (100 lines, lofted), `vii_tower` | baked | lofted Type VII, good |
| Fishing cutter | Totenhafen | `detail_map02.gd` `cutter` (86, clinker loft) | baked | good |
| Burning freighter, destroyer | Totenhafen, far out at sea | `detail_map02.gd` (30 and 18 lines of boxes) | baked | **crude**, but silhouettes at several hundred metres; needs a regenerate |
| Pen crane, harbour gantries, torpedo cradles | Totenhafen | `gen_map02.gd`, `detail_map02.gd` | baked | needs a regenerate |
| Locomotive 52 4471, boxcar | Kaltenbrunn | `gen_map01.gd` `_dress_railyard` (38 and 21 lines) | baked | **crude (tubes and boxes), seen close: the next ones worth doing**; needs a regenerate |
| Ore carts, squad sled, cranes | Kaltenbrunn | `Props.ore_cart`, `gen_map01.gd` | baked | needs a regenerate |
| Runaway ore cart (the trap) | Kaltenbrunn | `interactable_art.gd` `cart_body` | run time | a gameplay prop with its own art pass |
| Buried wagon, dead cable car | Kaltenbrunn's far landscape | `kalten_landscape.gd` | run time | far, under snow |
| Burnt Kübelwagen, tipped cart | the Inn's field and far landscape | `landscape_props.gd` | run time / baked | burnt shapes under snow |
| The well, the sniper tower, the sledges | the Inn | `gen_map00.gd` | baked | T-251's file |
| Fences | the Inn | `Props.fence` | baked MultiMesh | hewn rails already (T-093) |
| Barrels, the welding cart, library crates | several | CC0 GLBs through `PropLibrary` | GLB | real models already |
| The AMO truck, the train compartment, the cutscene C-47s | cutscenes | `cinema_sets/*.gd` | run time | seen for seconds, framed by their cameras |

There are no trucks or lorries on Kaltenbrunn (the order's list assumed some); its vehicles are the locomotive, the
boxcar and the ore carts.

## 7. Files

New: `gravelight/world/sherman/vehicle_paint.gdshaderinc` (the paint) with `vehicle_paint.gdshader` and
`vehicle_paint_sky.gdshader` (the two that include it); `assets/ours/world/vehicle_paint/` (`paint_mask.png`,
`paint_normal.png`, 512 px, 1.6 MB as PNG, VRAM-compressed with mipmaps on import; `LICENSE.txt`, `SOURCE.txt`: ours);
`gravelight/tools_src/gen_vehicle_paint_tex.py`; `gravelight/tools_src/vehicle_census.gd` (triangle counts);
`gravelight/tools_src/u19_model_shots.gd/.tscn` (turntables of the small models);
`gravelight/tests/unit/test_u19_models.gd`; this note; `docs/captures/u19_models/` (JPG, 9.8 MB).

Changed: `gravelight/world/sherman/proc_kit.gd` (added: chamfered boxes, prisms, lathes, tubes, soft lumps, bolts,
weld beads, U-bars, the edge-wear mark, `paint_material`, `mesh_tris`; nothing removed),
`sherman_mesh.gd` (rewritten), `sherman_tank.gd` (three hunks), `stuka_plane.gd` (the model half),
`gravelight/world/landscape/plane_models.gd`, `gravelight/world/props.gd` (`cart`, `wagon_wheel`, `crate`),
`gravelight/tools_src/sherman_shots.gd` (`--dir=`, six more frames).

Not touched: `gen_map00.gd`, `map00.tscn`, any other generator or map scene, the shared material library
(`materials.gd`), `PROGRESS.md`, `docs/DECISIONS.md`, the data files.

## 8. Verification

All on the owner's PC, headless (`--headless --audio-driver Dummy`); renders under WSL / Xvfb (software OpenGL, the
Compatibility renderer), never a window. Final state of the branch.

- `check_scripts.gd`: 940 scripts, 0 failed.
- GUT, the whole suite: **2,336 tests, 2,335 passing, 0 failing, 1 risky** ("did not assert":
  `test_neural_lines_are_loudness_normalised`, the one master already has). 2,330 on master + the 6 of
  `test_u19_models.gd`. `test_sherman` 10/10 and `test_u12_aircraft` 3/3 unchanged and passing.
- Smokes (`tools/run_smokes.sh .smoke_logs/u19_models <name>`), all PASS, 0 script errors: `smoke_sherman` (41 checks),
  `smoke_horse_boss` (79), `smoke_map00`, `smoke_map00_alive`, `smoke_map00_cellar_bay`, `smoke_map00_loop`,
  `smoke_map01_world`, `smoke_map02_world` (the last six for the sky's aircraft; no map scene was changed).
- `python -I tools/assets_manifest.py --check`: current (112 folders).
- Not run: the other maps' smokes (nothing of theirs changed), the FPS bench (needs a GPU window), a generator (not
  mine to run): so the new wagon and crate have been built and measured by the unit test and rendered on a turntable,
  but **not yet seen baked in a map**.

Renders, all looked at (`docs/captures/u19_models/`, JPG, 9.8 MB together):
- `before/`: T-249's frames of the same subjects from master (the tank from four sides, its running gear, the wreck,
  the dive bomber from three sides; the tank, the wreck and the dive bomber at the Inn).
- `turntable/` (neutral light): the tank from the quarter, the side, the front, the rear quarter, above, its running
  gear, its turret, its rear deck, at a player's eye from 3 m; the wreck from two sides; the dive bomber from five
  sides; the bomb. What they show: an M4 by its shape from every side; no missing or inverted face, no z-fighting, no
  floating part found. Things seen and left: the surface grain is a little coarse at 3 m in hard light; the cupola's
  opening is lit warm by the crew lamp; in daylight the night lift flattens the paint a little (the tank is only
  ever on the Inn at night).
- `inn/` (the real scene and its night): the tank parked outside the gate from the yard, close, **at eye height from
  3 m and from 15 m**, from behind; the wreck burning; the dive bomber **in its dive** and pulling out over the yard.
  What they show: at 3 m the hull's side, its plates, cable and star, the turret and the running gear read (they were
  black); at 15 m it is a Sherman by its outline with its lamps lit; the dive bomber overhead is a pale gull-winged
  shape with its crosses (it was two orange dashes); head-on in the dive it is still a thin line with its exhaust
  glow, which is what a head-on aircraft is; the wreck is dark and burnt under its fire.
- `night_check/`: the tank and the dive bomber with no light at all (what the lift alone gives), and the calibration
  boxes.
- `small/` and `before_small/`: the six sky aircraft from four sides each, the wagon from four, the crates from two,
  new and old (the old ones built from master's files by the same tool). Seen and left: the red stars on the Soviet
  pair are ragged at this size (they are 4 cm on a 1 m model, a dot of colour in the sky).
- `c47/`: the C-47 wreck as it is (six frames from `shots_c47`), for the record: untouched by this pass.

## 9. For the lead at merge

- **Regenerate map00** (already planned): it picks up the new wagon (x3) and crates (x15). No generator edit of mine.
- `python -I tools/assets_manifest.py --check` passes with the new asset folder (it is under `assets/ours`, which the
  manifest does not list; the licence gate reads its SOURCE.txt).
- No data key added. No autoload, input or project setting changed.
- NEEDS_DEVIN: the crosses on the dive bomber (section 3): keep, or `StukaPlane.CROSSES = false`. And a look at the
  tank and the dive bomber at night in a real window (`ShermanMesh.NIGHT_LIFT`, `StukaPlane.NIGHT_LIFT`).
- The regenerated map00 gains about 11,000 triangles from the three wagons and fifteen crates (merged per material,
  no extra draw calls); if a map budget test objects, that is why.

## 10. Open

- A look in a real window with a real GPU: every frame here is WSL's software OpenGL (the Compatibility renderer).
  The shader uses nothing renderer-specific, but Forward+ has not drawn it yet.
- The tank near is 44,658 triangles against the ~40,000 named. A lighter link (the horns as one wedge) would bring it
  to about 41,000 if the FPS bench asks for it.
- The wreck's gun still droops through the glacis' fittings (T-249's pose, unchanged).
- **The C-47 wreck has the night problem the tank had**: in `c47/asis_field_se.jpg` its fuselage side is as black as
  the sky; only its snow and its fires read. The same lift in `c47_skin.gdshader` would cure it. Not done here: it
  wants its own measured frames, and the wreck's model was not otherwise in need.
- `NIGHT_LIFT` (3.2 and 2.2) was set from software-OpenGL frames. If the owner's renderer shows the tank or the
  aircraft too bright or too dim, those two constants are the only thing to turn.
- The next models worth this treatment, all baked (each needs its map regenerated): Kaltenbrunn's locomotive and
  boxcar, Groom Lake's trucks and bomber, then the freighter and destroyer off Totenhafen.
