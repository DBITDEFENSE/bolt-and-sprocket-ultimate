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
