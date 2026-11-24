# T-272: Kaltenbrunn's map detail pass (the geometry step)

The owner: "go through and look at all the maps and apply a level of detail that you see that we have in the first map
... there's level design, there's things that happen throughout the rounds. That needs to be the case for the other
maps." T-271 switched Map 0's match systems on with data; this is the geometry step for Map 1, Kaltenbrunn.

Branch `claude/detail-map01`. The map is generated: `gravelight/tools_src/gen_map01.gd`, regenerated headless with

    "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map01.gd

Coordinates are map space, metres, `[x, y, z]` (+X east, +Z south, the yard's north wall at z 0).

## 1. The Sherman: in through the north gate, the full round-30 event

**Decision: the tank precedes the raid; the raid stays.** Kaltenbrunn now runs the Inn's whole event: round 30 the
Sherman arrives and the dead go for it; it covers the yard for rounds 31..39; round 40 the dive bomber kills it and
the air raid follows. The raid is the event's last act on the Inn too, and T-271's raid rows (any roof shelters, this
map's banners, the bomb zones) were already right for this map, so the tank is put in front of it rather than
replacing it. A tank instead of the raid would have dropped the round-40 beat that T-271 built and tested; a raid
without a tank was only ever the fallback for "no way in".

**The way in: the yard's north gate, not the rail yard.** T-271 measured two places: the Rail Yard at (47, 0, 21),
reached through a breach where the buried rail line meets the Rail Yard's north wall, and the forecourt between the
north gate and the headframe. The forecourt wins on the one thing that decides the fight: the assault rises round the
parked hull in its zone, and the Minehead yard is the squad's own zone, open from round 1. The Rail Yard sits behind a
750 door that a squad going down by the Administration and the stairs never buys; a tank parked there on round 30
would be beaten to death by dead nobody can reach. The gate is also where the road arrives, the exfil already calls it
"THE NORTH GATE", and der Fuhrmann already comes in by it (`round_boss_arena.arrive` (33, 0, 1.8)).

What was built:

| What | Where | How |
|---|---|---|
| The gateway | the yard's north wall, x 17.6..22.4 (the brick pillars' inner faces), full 4 m height | `gen_map01` `GATE_X0/X1`: an opening in `YardN`; the coping and wire stop at the pillars |
| The gateway's collider | `Gate`, x 17.5..22.5, z -0.55..-0.15, 4.5 m high | always there: nobody leaves the yard, the navmesh is the same with the gate open or shut; the tank's scripted drive goes through it |
| The gate | `Gameplay/YardGate` at (20, 0, -0.45): two iron-framed plank leaves (`LeafW`, `LeafE`) on pivots at the pillars | `_build_yard_gate`; each leaf baked to one mesh per material (3 draw calls a leaf). `yard_gate.gd` swings them out (away from the yard) while a Sherman on its scripted drive is within 16 m or any of it is in the gateway, and shuts them behind it. Runs on every peer from the tank it sees |
| The north road | trodden snow from the rail line's head (48, -24) west between the drifts and south to the gate | four `snow_trodden` strips in `_dress_yard` (drawing only) |
| The route | (48, 0, -24) the rail terrace's head, (46, 0, -17), (32, 0, -14), (21, 0, -12), then straight south through the gateway to (20, 0, 4.4) | `map01.json` `sherman_event.route`; the shelf is flat at y 0 to z -25 |
| The park | (20, 0, 4.4) facing south (the yard); hull x 18.7..21.3, z 1.4..7.3; 2.7 m clear of the hoist house | the route's last point and leg |
| The assault | ring points 10..16 m round the hull in `A_MINEHEAD` | `assault_zones: ["A_MINEHEAD"]` |
| Driving (T-261) | the forecourt only: box x 15.2..24.8, z 0.4..9.7 (the hoist house's own width) | `drive_zones`, `drive_boxes`; a hull left anywhere in it, or its wreck, never stands in the 3 m lanes past the gatehouse and the winding house. A pivot needs the middle of the box (a 6.6 m circle) |
| The exfil beacon (campaign) | moved from (20, 0, 2.2), the gateway's axis, to (24.4, 0, 2.4) beside it | `map01.json` `exfil.position`; the tank comes through the gateway on round 30, which is also the campaign's exfil round here; a `drive_no_go` disc (r 1.0) keeps a driver off it |
| Banners | "ARMOUR AT THE NORTH GATE" / "A SHERMAN IS COMING UP OUT OF THE VALLEY" | the block's own `arrival` row (see the script change) |
| der Fuhrmann | hooves 20 s, scream 23 s, in at 25 s (the tank parks at about 21 s) | `round_bosses` round 30 `arrival` |
| Round 40 | the dive bomber on the tank (the default banner names the Sherman); the raid as T-271 built it | `stuka_target` (the locomotive) is kept only for a match where both tanks were lost |

**Script change (shared, data-driven, default unchanged):** `sherman_event.gd` `with_map_rows`: a map's block may
carry its own `"arrival"` and `"assault"` rows, laid over `sherman.json`'s on a copy of the table (as T-271's `merged`
does for `raid` and `stuka`). Map 0's block has neither; the function then returns the table itself (a unit test holds
that it is the same object).

The tank's view from the forecourt: the gatehouse, the winding house and the hoist house box it in. It sees the
forecourt, the two north windows (W_A_N1, W_A_N2) and the north-east ground spawn, the mouths of the lanes; not the
Kaue or the south lane. That is where the dead come in from the north side; the smoke's assist check fires on the dead
at the north-east corner.

Verified (headless):
- `probe_map_site --route=48,0,-24;46,0,-17;32,0,-14;21,0,-12;20,0,4.4`: one thing in the hull's way, `Geometry/Gate`
  (the always-shut collider, by design); 8 of 520 ground points off, all at the first three places where the hull's
  tail hangs over the terrace beyond the Ground slab (z < -25); the assault ring: 46 of 72 places on the navmesh, all
  in `A_MINEHEAD`; the park point 4.6 m free.
- `smoke_map01_sherman` (new, 36 checks) PASS: rounds 30 and 40 reserved; the tank starts at z -24; the gate opens at
  16 m; it comes through the gateway with its centre at most 0.43 m off the middle (the hull clears each pillar by
  more than 0.6 m); parks 0.00 m off the park point at 21.3 s, facing south, inside the drive box; the gate shuts
  behind it; all 10 attack points on the yard's navmesh; der Fuhrmann in by the gate at 25 s; 46 ring points, all on
  the navmesh and 10..16 m off; the dead beat on the hull; the team kills 24 of them (6 burning): it HOLDS; the
  Resupply lands at (19.7, 0.3, 9.4), on walkable ground; a player climbs in, drives at the hoist house and back at
  the gate and is stopped inside the forecourt both ways, never a frame outside the box, pivots in the middle, climbs
  out on the navmesh; the machine gun fires on the dead at the north-east corner, nothing hits the player; round 40
  the bomb lands on the tank, a wreck; the Kaue's roof shelters, the forecourt does not; a bomb by a player in the
  forecourt hurts them, one in front of the Kaue spares them inside; the all clear; the wreck stays in the forecourt.
- `test_map01_detail` (new): the block, the route through the gateway (the hull clears both pillars by 0.3 m or more
  on the whole last leg), the park and the drive box, the beacon off the route and the hull, `with_map_rows`, the gate
  and the gateway's collider in the scene file. `test_sherman` and `test_map_detail` changed where they asserted
  "Kaltenbrunn: the raid only".

## 2. The headframe as the map's tower

The deck is the hoist house's flat roof under the headframe (`TowerBase`, x 15..25, z 10..20, 6.0 m up): a 10 m square
round the shaft collar, already a navmesh island before this pass, with nothing that kept anyone on it or got anyone up.
A second, higher platform in the frame was looked at and dropped: from 11 m the lines would have to be 20 m and more
long to stay under 30 degrees, and the yard is 40 x 32 m with the headframe in its middle; every such line would leave
the yard over a 4 m wall (the rider's feet 3 to 4 m up at the wall) or skip a paid door.

| What | Where | Notes |
|---|---|---|
| The railing | the roof's edge, three collider bars a side (`HFRail_*`, 0.06 / 0.55 / 1.05 m over the deck), drawn as an iron railing (posts every 1.25 m, top rail, knee rail, toe plate, snow on the top rail) | closed all round as on Map 0's tower: the climb and the zip mounts carry over it, nobody walks off |
| The frame's feet | `Prop_A_FrameFoot_*`, 0.76 m square from the deck to 8.4 m at the four corners; the pads drawn the same size (they were 1.2 m and reached past the roof's edge) | the legs were drawn only |
| The shaft collar | `Prop_A_ShaftCollar`, x 17.2..22.8, z 12.2..17.8, 0.5 m (the iron box already drawn there) | was a ghost; the deck is a 2.1 m walk all round it |
| The frame's bracing | the lowest tier's cross-braces start on a ring at 8.4 m (2.4 m over the deck); the ring beam that lay across the roof at the legs' line is gone | nobody walks or shoots through a brace on the deck (Map 0's rule) |
| The ladder | up the west face at z 15 (Props.ladder at x 14.86, stand-offs to the wall, the stiles 0.9 m over the deck), a lantern on a post at its head | `map01.json` `ladders` (foot / head, line [14.345, 15]) and `climb_links` `Climb_Headframe` (line, both ways, drop, `perch` 10) |
| EastZip | from a davit off the south-east leg, anchor (25.25, 8.0, 18.3), down the east lane to a post at (36.4, 0, 26.8), set down at (35.68, 0, 26.25) by the Rail Yard door's corner | 15.0 m, 21 degrees, 3.3 s |
| WestZip | from the south-west leg, anchor (14.75, 8.0, 18.3), down the west lane to a post at (3.6, 0, 22.6), set down at (4.44, 0, 22.28) by the Administration door | 13.1 m, 24 degrees, 3.0 s |
| Lights | the ladder head's lantern (1.6, 9 m) and a lantern on each landing post (1.6, 6.5 m); no shadows | +3 lights |

Rules kept: both lines land in the Minehead yard, so neither skips a paid door and neither is chained; both landings
are more than 3.5 m from every spawn marker and 31 m apart; down only; the dead and the bots never ride. Two lines, not
three: a third, north into the forecourt, would be 8 m long at 37 degrees and land where the Sherman parks.

**Shared script change (data-driven, default unchanged):** `climb_link.gd`: a climb-link row's `"perch"` (metres)
widens `ClimbLink.on_perch` for its own platform, so the undead horse's siege shake (T-268) reaches the whole 10 m deck
(its far corner is 9.7 m from the ladder's head; the default reach is 4.5 m, made for Map 0's 4.8 m decks). Rows
without it (Map 0's) behave as before.

Verified (headless):
- `probe_ladder_tops -- --map=map01`: both ladder ends, both climb-link ends and both landings on the navmesh (0.00 m).
- `probe_map_site --line`: EastZip 15.0 m, 21 degrees, WestZip 13.1 m, 24 degrees; the only thing in a rider's way is
  the landing post at the very end (as on Map 0).
- `smoke_map01_tower` (new, 63 checks) PASS: up and down the ladder (carried, on the line, hands on the rungs, ends on
  the navmesh); the deck's navmesh goes from the ladder's head all the way round the collar (7 of 7 places); the zone
  up there is the yard's; the horse's siege counts the whole deck; each line: nothing in the rider's way, the anchor
  reached on foot, the bar under the Use ray, named prompt, the ride, the landing, standing free; the dead: one climbs
  and comes round the deck to the player in the far corner and hits them (20 s from its rise), drops back down when
  the player leaves, one follows the player up, four go up one after another (up to 3 on the rungs, never closer than
  2.19 m), a climber killed 3.5 m up falls, a crawler never climbs and is requeued after 9 s.
- `smoke_ladders` PASS (Map 0 and Map 2 unchanged by the climb-link change).
- `test_map01_detail`: the ladder rows (the same line for players and the dead, the line 0.4 m off the drawn rungs,
  perch reaches the far corner), the zip rows against the drawn lines (2 m over the deck, outside the railing, 15..30
  degrees, the cable on its post, set down 0.9 m short on the line, inside the yard, clear of every spawn, apart), the
  deck's colliders in the scene (12 bars, 4 feet, the collar, braces over head height), `perch`.

Seen (WSL + Xvfb, the Compatibility renderer, 1280x720; `docs/captures/t272/`, set `t272_m01` in `capture_cams.json`):
the gate shut from the forecourt (`00`), the deck from the Kaue at night and noon (`02`, `11`: the railing on the roof's
edge, the frame's lowest braces over the deck, both cables), from the east lane (`03`), on the deck at night and noon
(`05`, `12`: the walk round the shaft collar, the ropes into it, the feet, the lantern post at the ladder's head), down
the east line with its prompt (`06`) and the west line (`07`), back up from the east landing (`08`), the Sherman parked
in the forecourt at night and noon (`09`, `10`) and coming through the gateway (`13`). What the frames changed: nothing
yet; the ladder itself does not read in the night frame (`04`, the west face is dark) and the camera placed outside the
gate was put back inside the yard by the map (no player may stand there), so that view was dropped; a noon frame of the
ladder was added to the set for the next render.

## 3. Perk spots for the perk deal

T-251's deal (PerkShuffle / PerkLayout, `perk_layout.json`) now runs on Kaltenbrunn: 14 `PerkSpot` nodes, a row
`maps.map01` with 8 dealt machines, the scene saved with the seed-0 deal, the mapdata's POIs refreshed
(`tools_src/refresh_mapdata_pois.tscn -- --maps=map01_kaltenbrunn`: the eight dealt machines' rows moved; no bake).

**Eight of eleven are dealt; three stay where they belong.** Ledger Lager is the pay office's own cabinet beside
Fenske's desk (T-141, its lore and its quest line), Overclock Cordial is wired into the Generator Hall's switchgear
(T-034), Skyhook Sekt is the cabinet the installers set up in the Core Vault (T-226). Map 0 deals all twelve because
its machines were one delivery in the vault; here three are part of the rooms they stand in. They keep their own baked
footprints and their places; the deal moves the other eight (`perk_layout.json` lists only those).

| Spot | Zone | Floor point, yaw | Flags | Notes |
|---|---|---|---|---|
| `pay_office` | C_ADMIN | (-15.2, 0, 14), -90 | near, flush -1 | Second Wind's old place |
| `mess_west` | D_BARRACKS | (24, 0, 32.8), 180 | flush 1 | Ironhide's old place |
| `chapel_nw` | F_CHAPEL | (2, -12, 60.8), 180 | flush 1 | Marathon's old place |
| `chapel_ne` | F_CHAPEL | (34, -12, 60.8), 180 | flush -1 | Twin Barrel's old place |
| `gen_south` | G_GENERATOR | (68, -12, 81.2), 0 | flush 1 | Trigger Tonic's old place |
| `lab_hall_west` | H_LAB | (55, -12, 88.8), 180 | flush 1 | Hawkeye's old place |
| `lab_hall_east` | H_LAB | (96, -12, 88.8), 180 | flush 1 | Packmule's old place |
| `lab_south` | H_LAB | (64, -12, 97.2), 0 | flush 1 | Blastproof's old place |
| `admin_upper` | C_ADMIN | (-0.83, 3.8, 29.0), 90 | near, flush 1 | new: the upper floor's east wall at the stair head's end |
| `railyard_west` | B_RAILYARD | (40.8, 0, 16.6), -90 | outdoor, near, flush 1 | new: the Rail Yard's west wall near its north end, 3.2 m from the ore-cart trap's track (first placed at z 19: `smoke_map_detail` found it 1.9 m through the wall from the yard horse's rail, inside its 2.5 m clearance; moved, re-probed clean, POIs refreshed) |
| `mess_east` | D_BARRACKS | (32.0, 0, 32.8), 180 | flush 1 | new: the mess hall's north wall |
| `lift_house` | E_LIFT | (20.81, 0, 54.2), -90 | flush -1 | new: the lift house's west wall, opposite the cage |
| `stairs_foot` | M_STAIRS | (-4.82, -12, 56.5), 90 | flush 1 | new: the foot of the maintenance stairs |
| `gen_north` | G_GENERATOR | (70.0, -12, 60.8), 180 | flush 1 | new: the Generator Hall's north wall east of the switchgear |

Every origin is 0.65 m out from its wall's face (measured: a ray from each origin hits its wall at 0.65..0.68 m); the
deepest machine's back is then 0.05 m off the wall and `PerkSpot.stand_transform` sets shallower cabinets back to the
same line. Each spot bakes a 1.7 x 1.2 m footprint (`NavBlock_PerkSpot_*`, bake only, as on Map 0), so whatever
stands there (machine or crate) is walked round. The six new places were measured on the running map with a throwaway
probe: nothing solid in the footprint, the front on the navmesh, no door, window or spawn within 2.4 m. Two candidates
were dropped: the Chapel's south wall at x 8 (the pews leave no navmesh in front of it) and at x -8 (2.2 m from the
window W_F_S1).

Second Wind (near-start, never outdoor) has two places: the pay office and the Administration's upper floor. Max two
dealt machines a zone: the Generator Hall can then hold three machines in all with Overclock Cordial (fixed); the Lab
has three spots for at most two.

Verified (headless): `smoke_map01_perks` (new, 13 checks) PASS: the pinned seed's deal, 14 spots / 11 machines / 8
dealt, the rules kept, every dealt machine on its spot with its front in the spot's zone, the three fixed machines
where they belong, the 6 spots left over show a solid crate, the bake boxes stop nobody, the navmesh reaches all 14
fronts from the yard with every door open, another seed moves 6 of 8, the POIs follow the machines, Ironhide Stout and
Marathon Malt bought at dealt machines (one above ground, one below). `test_map01_detail`: the table and the scene
agree, each spot in its zone with its floor baked out and its front on the navmesh, the seed-0 deal in the saved
scene, the three fixed machines and their footprints, 300 seeds keep the rules (weather kit under the snow, Second Wind
near the yard and in two places over the seeds, at most two a zone, every spot used). `test_perk_layout` (Map 0),
`test_mapdata`, `test_ledger_lager` PASS.

## 4. Reactive props

`gen_map01` `build_reactive()`: runtime nodes under `Reactive` (T-053's kit; they build their art at load, the scene
holds only their settings). Nothing collides or touches the navmesh.

| What | Where |
|---|---|
| Glass that breaks when shot (`ShatterSet`) | `Glass_Mess`: 15 steins and glasses on the three mess tables (kept 0.16 m off the crockery already drawn there) and 5 bottles on the serving line's counter; `Glass_Lab`: jars and glasses on Fasbender's bench behind its bottles; `Glass_Office`: a bottle and two glasses on Reinholt's desk |
| Curtains in the draught of their window (`DraftCurtain`, linked to the barricade: harder when boards are gone) | the Administration's three windows (W_C_N, W_C_UN, W_C_BAL; green cloth) and the barracks' three (W_D_W, W_D_S1, W_D_S2; sacking), a rod over each |
| A door left ajar (`SwingDoor`) | the Administration's upstairs partition (hinge (-9.8, 3.8, 15.85)), opening into the radio room; it swings back for anyone coming through |
| Footprints (`SnowFootprints`) | the open snow of the Minehead yard and the Rail Yard; not in the Kaue, the gatehouse, the winding house or the hoist house |
| Drips (`DripPoint`) | the Salt Chapel's east aisle (from the dome, 14 m), the F and G vault ramps (from their rock roofs onto the slope), the Core's west side (12 m), the H corridor |
| Wind (`AudioZone`, linked to the window) | the six windows with a room behind them (the Administration's two north windows, the barracks' three, the lift house's) |
| Timber creaks | the barracks (random, 14..34 s) |
| Paper (`PaperDecor`) | the December calendar on the pay office's north wall |

Not added: hay (there is none on this map); a second paper (the patrol's map would lie on Reinholt's plan table over
the open plan already drawn there). Cost: 12 curtain nodes (4 strips each, built at load, idle beyond 30 m), 6 curtain
rods (6 small meshes without shadows, outside the batches: built after them), 3 glass sets (one MultiMesh per glass
material each), 7 looping or random sound players, 5 drips (one-shot particles), one footprint MultiMesh.

Verified (headless): `smoke_map01_reactive` (new, 16 checks) PASS: the three glass sets build their 30 pieces, all 30
on a collider's top, none inside one, a shot piece of each breaks; 12 curtains each find their barricade and hang
inside the room, off the wall, over the floor; the partition door swings from 65 to 100 degrees for the player walking
through; the yards take prints and the Kaue does not, 7 prints from a walk; every drip under a ceiling and falling its
height onto a floor; the six wind zones find their windows.

## 5. The round-1 opening: the night shift runs

`data/gravelight/map01_opening.json`, read by the generalised `inn_opening.gd` (T-271's `data_path_for`; the node
`Gameplay/InnOpening` with an empty `data_path`). No script of the opening was changed.

The night shift has come up and is changing in the Waschkaue when the squad's sled pulls in (the sled is drawn at the
Kaue's east wall): four miners on the benches and at the stove, in the room with the squad. Round 1 is held for the
settled view (9..10.5 s) facing the south lane, then the cue (boards slammed at the yard's windows, Gorny: "What was
that? ...At the windows."). When round 1 starts the miners run out of the two doorways: Gorny and Kania up the west and
east lanes to the north gate (YardGate opens for them from 6.5 to 15 s: the opening's own `gate` row, read by
`yard_gate.gd`) and off up the north road; Pietsch and Mrozek are caught in the south lane 7..9 m in front of the
spawn by two of the dead rising out of the snow ((8.6, 0, 20.2) and (17.6, 0, 23.0)) and rise as zombies of round 1
where they fell, (11.0, 0, 21.6) and (14.6, 0, 22.0), on the navmesh. Their two slots and the attackers' two come off
round 1's queue (the round's size is unchanged, as on Map 0). No front door (the Kaue's doorways are open), no flare,
no squad line on a rise (the squad's INN_RISE lines name Map 0's people). The title card (campaign only) reads
"SALZBERGWERK KALTENBRUNN / the Waschkaue, Schacht II · Upper Silesia / 23 December 1944 · night". A campaign arrival
from the inn never plays it (as on Map 0: `Campaign.arriving`); it plays when a match starts on Kaltenbrunn.

Lines: nine new text lines in `vo/lines.json` (GOR_M1_*, KAN_M1_*, MRO_M1_*, PIE_M1_*; the existing INN_* categories)
and four speakers in `voice_cast.json` (GOR, KAN, PIE, MRO: descriptions for a later voice pass). No audio was made
(no outside services): the nine are listed in `audio_manifest.json` `missing` with that reason; the subtitles show.
The patrons wear the opening's primitive bodies with their colours (there is no modelled miner in `art/people.json`).

Verified (headless): `smoke_map01_opening` (new, 15 checks) PASS: the file read by the map's id; the four miners in the
Kaue under its roof before round 1; round 1 waited 10.9 s of settled view and the cue; two intro lines first; four
slots off the queue; every miner runs through the squad's starting view (within 56 degrees of its forward); the gate
opens for them and shuts; Gorny and Kania through the gateway and gone; Pietsch and Mrozek risen on the yard's navmesh
in A_MINEHEAD; two attackers rose; no slot returned. `test_map01_detail` `test_the_opening_data`: the starts in the
Kaue, the caught fall on the navmesh in the south lane, the escapees cross z 0 inside the gateway, the attackers rise
on the navmesh, every line and the cue's line exist, the speakers are in the cast, the escapees reach the gate while
it is open. `test_vo` (every line baked or listed), `test_map_detail` (Kaltenbrunn no longer "has no opening") PASS.

**Survivors behind a door: not built** (time). The generalised `inn_survivors.gd` would take a
`data/gravelight/map01_survivors.json` (a `reveal_door` id and survivors with hide / post places and eight lines each);
the natural place is the Administration (`door_a_c`, 1000): two clerks and the night watchman (the KAN line asks where
he is) hiding in the radio room upstairs, armed for 750 to hold the upstairs windows. Note that Kaltenbrunn already has
T-143's hidden people (the shift boss Brzezina, the orderly, the switchboard operator) who trade, not fight.

## Cost (the scene file, counted headless before and after: every MeshInstance3D, Light3D and collision shape)

| | before (master) | after | added |
|---|---|---|---|
| triangles | 284,794 | 296,194 | +11,400 (the ladder's rungs, the two cables, the railing, the gate's leaves) |
| of them in shadow-casting meshes | 167,176 | 174,712 | +7,536 |
| mesh instances (about the static draw calls) | 866 | 897 | +31: the gate's two leaves (6), the curtain rods (6), the rest are new batch cells of the merged dressing (the north road's strips, the deck) |
| lights | 207 | 210 | +3 (the ladder head's lantern, the two landing-post lanterns), none shadowed |
| shadowed lights | 4 | 4 | 0 |
| collision shapes | 477 | 503 | +26 (the railing's 12 bars, 4 frame feet, the collar, 2 zip posts, 14 perk-spot bake boxes off at runtime, the gateway's collider widened) |

Built at load, not in the file: up to 6 filler crates on the free perk spots (each baked to a few meshes), 12 curtains
(4 strips each, idle beyond 30 m), the 3 glass sets (one MultiMesh per glass material), the footprints' MultiMesh, 5
drips, 7 sound players, the opening's 4 patrons (gone after round 1). Draw calls were not measured on a GPU (headless
counts are zero); the Sherman's mesh is T-249's.

## For DECISIONS.md (the main session writes it at the merge)

**T-272: Kaltenbrunn's map detail pass (the geometry step).** Branch `claude/detail-map01`, notes
`docs/u21/t272_map01_detail.md`. (1) The full round-30 Sherman event: the yard's north wall got a real gateway (x
17.6..22.4) whose collider never moves; `YardGate`'s two leaves swing out for the tank and shut behind it; the tank
comes up the rail terrace and the north road and parks in the forecourt facing the yard, so the assault rises in the
squad's own zone (the Rail Yard was dropped: it sits behind a door many squads never buy); driving is kept to the
forecourt; the campaign's exfil beacon moved beside the gateway; der Fuhrmann timed to the parking. The tank precedes
the raid, it does not replace it: round 40 is the dive bomber on the tank and T-271's raid. `sherman_event.gd`
`with_map_rows` (a block's own `arrival` / `assault` rows; Map 0 unchanged). (2) The headframe as the map's tower: the
hoist house's roof (6 m, 10 m square) is a railed deck round the shaft collar, the frame's lowest braces start 2.4 m over
it, one ladder up the west face for players and the dead (T-268's ladder links, `perch` 10: `climb_link.gd` lets a row
widen `on_perch`, default unchanged), two zip lines from davits on the south legs into the yard (15.0 m / 21 degrees to
the Rail Yard door, 13.1 m / 24 degrees to the Administration door; inside the yard, never chained; a higher deck was
dropped: every line from it would leave the yard over a wall or skip a door). (3) The perk deal: 14 spots, 8 of 11
machines dealt (Ledger Lager, Overclock Cordial and Skyhook Sekt belong where they stand), mapdata POIs refreshed. (4)
Reactive props: glass on the mess tables, the serving line, Fasbender's bench and Reinholt's desk; curtains at the
Administration's and the barracks' windows; the upstairs partition door ajar; footprints in both yards; drips in the
Chapel, the vault ramps and the Core; wind at six windows; barracks creaks; a calendar. (5) A round-1 opening on the
generalised `inn_opening.gd`: the night shift runs out of the Waschkaue, two through the north gate, two caught in front
of the Kaue and risen; nine text lines and four cast entries, no audio (listed as missing). Survivors behind a door
were not built. Costs: +11.4 k triangles, +31 mesh instances, +3 unshadowed lights, no shadowed light. Verified
headless: five new smokes (`smoke_map01_sherman` 36, `_tower` 63, `_perks` 13, `_reactive` 16, `_opening` 15 checks),
`test_map01_detail`; renders under WSL (`docs/captures/t272/`). Not seen on the owner's GPU; the opening's miners are
primitive bodies; no co-op run of the new pieces.

Second render pass (`t272_m01b`, `docs/captures/t272/b*.jpg`): the night shift in the Kaue before round 1 (`b00`: the
miners are the opening's primitive bodies, blocky beside the modelled squad; a person model for them is open), the
ladder at noon (`b01`: stiles, rungs and stand-offs read, the railing over it, the lantern post), the gate at noon
(`b02`), the glass on the mess tables among the crockery (`b03`) and on the serving line (`b04`), the Administration's
north window (`b05`: dark; the curtains barely read), the partition doorway (`b06`: the leaf stands in the dark radio
room and does not read from the hall), the Rail Yard's perk spot with its machine flush on the wall north of the door
(`b07`, before the spot moved 2.4 m north), the jars on Fasbender's bench (`b08`), the sacking at the bunk room's window (`b09`). What the frames changed:
the calendar stood on the corner of the Gewehr 43's chalk board (`b05`); it moved 2.6 m east, between the chalk and the
window (not re-rendered).

## Results (headless, this PC, 2026-11-24)

- `check_scripts`: 1011 scripts, 0 failed.
- Full GUT (on the commit before the last spot move): 2602 tests, 2600 passing, 1 risky (the known
  `test_neural_lines_are_loudness_normalised`), 1 failing: `test_transitions.test_preload_next_is_idempotent_for_every_target`
  ('Parameter "t" is null / "texture" is null', the known intermittent under load). After the move: `test_map01_detail`
  (13) and `test_mapdata` (11) PASS again.
- Smokes, all 0 script errors: `smoke_map01`, `smoke_map01_systems`, `smoke_map01_world` PASS; the new
  `smoke_map01_sherman` (36), `smoke_map01_tower` (63), `smoke_map01_perks` (13), `smoke_map01_reactive` (16),
  `smoke_map01_opening` (15) PASS; `smoke_weapon_locker`, `smoke_ladders`, `smoke_coop`, `smoke_sherman` (74) PASS.
  `smoke_map_detail` FAILED once (121 checks, 1: the Rail Yard perk spot 1.9 m through the wall from the yard horse's
  rail); the spot moved to z 16.6, then `smoke_map_detail -- --only=map01` (27) and `smoke_map01_perks` PASS.
- Not run: the bot smokes, the campaign smoke, the full `smoke_map_detail` after the move (only its Map 1 part).

## Not verified, open

- Everything was seen only in the software Compatibility renderer under WSL; nothing on the owner's GPU.
- Co-op: the Sherman on this map, the gate, the tower, the deal, the reactive pieces and the opening use the existing
  mirrored machinery, but only `smoke_coop` (Map 0) was run.
- Bots: they do not climb or ride (as on Map 0); not soaked on the deck. Bots with a Sherman parked in the forecourt:
  only the danger discs (T-249's), not run.
- The tank's assist from the forecourt sees only the north side of the yard (the hoist house, the gatehouse and the
  winding house box it in).
- The opening's miners are primitive bodies; their nine lines have no voice yet.
- Survivors behind a door: not built (see section 5).

## Additions after the merge

### The opening's miners wear the project's person models

Each patron row in `map01_opening.json` has a `person` key now (T-273's key: the body worn alive and when risen):
Gorny `rother`, Kania `sobotta`, Pietsch `kubiak`, Mrozek `petersen`. No script change. The project has eleven
modelled civilian men and reuses them across maps (`people_extra.json` does the same: Kaltenbrunn's hidden miners are
rother, sobotta and petersen too, met deep in the mine much later; Totenhafen's opening uses rother and sobotta). A face
of its own for each miner would need new person models. `smoke_map01_opening` now also checks that all four wear a
modelled body (4 of 4) and that both risen wear their person's body (2 of 2): 17 checks, PASS. Seen:
`docs/captures/t272/c00_kaue_miners_night_models.jpg` (Kubiak warming his hands at the stove, Rother and Petersen on
the west bench, in their own clothes; the blockout bodies of `b00` are gone).

### The survivors behind a door: the Administration

`data/gravelight/map01_survivors.json` on the generalised `inn_survivors.gd` / `inn_survivor.gd` (the node
`Gameplay/InnSurvivors`, empty `data_path`); no script change. The night watchman ran from his gatehouse to the
Administration with the keys when the dead came over the wall (the opening's Kania asks where he is); two of the office
staff were still upstairs. They locked the Administration's yard door (`door_a_c`, Door_Admin, 1000) and hid in the
radio room upstairs. Opening that door reveals them, cowering and pleading; a player pays 750 to hand one a Kar98k and
they take a post on the upper floor and shoot the dead they see. Downs, helping up, deaths and rises as on Map 0.

| Survivor | Body (`person`) | Hides | Post |
|---|---|---|---|
| Paul Bartsch, the night watchman (60s), speaker BAR | wiesner | (-13.6, 3.8, 13.6) by the radio desk | (-1.0, 3.8, 14.0), the balcony window over the yard (facing east) |
| Martha Lenz, the pay office's senior clerk (40s), LNZ | pohl | (-11.0, 3.8, 9.0) | (-8.0, 3.8, 9.3), the north window (the ledge the dead climb to) |
| Hedda Schramm, the switchboard's relief typist (19), SHR | trudi | (-2.2, 3.8, 10.4) | (-9.0, 3.8, 18.6), the south room by the stair head |

`nav_layers` 4 (T-273's key): Kaltenbrunn bakes a navigation layer per zone and the Administration is bit 3. The
numbers (`ally`, `arm`, `squad_turn_line` INN_SURV_TURN: "one of the civvies upstairs") are Map 0's. Lines: 27 text
lines (nine a survivor: reveal, two scared, flinch, armed, fight, hurt, downed, death) and three cast entries; no
audio, listed under `missing` in `audio_manifest.json`. Faces: wiesner is also the hidden orderly on this map (T-143),
pohl and trudi are the Inn's women who got away; the same reuse as above.

Verified: `smoke_map01_survivors` (new, the steps of `smoke_map02_survivors`) PASS: hidden before the door, their spots
on the navmesh, nothing solid on them, each in a modelled body; the door reveals them cowering with an arm prompt
("Hold [F] to arm Paul Bartsch with a Kar98k [750]"); Frau Lenz's reveal line plays near them and she flinches at a
shot; a zombie in the radio room kills Bartsch while hiding (3 swipes), who rises in his body after the turning
warning; Lenz is armed for 750, walks to her post (0.0 m off in 1.4 s) and shoots a zombie on the upper floor; downed
at 0 hp, helped up, she holds again. `test_map01_detail` `test_the_survivors_data`; `test_vo`, `test_inn_survivors`
PASS. Not seen in a render (they are hidden until the door is bought; the capture tool does not buy doors).

### Results of the additions (headless, 2026-11-24)

`check_scripts` 1020 scripts, 0 failed. The full `smoke_map_detail` (the run missing after the Rail Yard perk spot
moved): PASS, 125 checks, 0 failed. `smoke_map01`, `smoke_map01_opening` (17), `_perks` (13), `_reactive` (16),
`_sherman` (36), `_survivors`, `_systems`, `_tower` (63), `_world` PASS, all 0 script errors. `test_map01_detail` (14),
`test_vo`, `test_inn_survivors`, `test_map_detail` PASS. The full GUT was not re-run for the additions (data files, one
generator line, a smoke and tests).

### For DECISIONS.md (the additions)

**T-272 additions (after the merge).** The opening's four miners wear the project's person models through the rows'
`person` key (T-273's; alive and risen): rother, sobotta, kubiak, petersen, reused as people_extra.json reuses them (a
face of their own would need new person models). Survivors behind a door on the generalised `inn_survivors.gd`
(`map01_survivors.json`, no script change): the night watchman Bartsch and two office staff, Frau Lenz and Hedda
Schramm, hidden in the Administration's upstairs radio room behind its yard door (`door_a_c`, 1000), armed for 750 to
hold the balcony window, the north window and the stair head; person bodies wiesner, pohl, trudi; `nav_layers` 4 (the
Administration's layer); 27 text lines and three cast entries, no audio (listed missing). Verified headless:
`smoke_map01_survivors` and the extended `smoke_map01_opening` PASS, the full `smoke_map_detail` PASS (125 checks).
The survivors were not rendered (hidden until the door is bought).
