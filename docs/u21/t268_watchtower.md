# T-268: the watchtower, its three zip lines, and the dead that climb

The owner: "Also the zip line and the watchtower. 1, zombies need to be able to crawl up the watchtower. 2, let's make
the watchtower like more badass, make it taller, and then make the zip line go to make like 3 zip lines that go to 3
different spots on the map. If you go on the ladder, have the zombies be able to chase you."

Branch `claude/watchtower`. Map 0 is generated: the tower is `gen_map00.gd` (`TOWER_*`, `ZIP_LINES`, `_dress_tower`,
`_tower_parapet`, `_tower_lights`) and `data/gravelight/map00.json` (`ladders`, `ziplines`, `climb_links`). The map is
regenerated with

    "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map00.gd

(20 s; the two `Identifier not found: GLSettings` lines at its start are the generator's known first compile of
`landscape.gd`, it recompiles and goes on.)

## What was there before

The T-229 tower already had a zombie climb link (`Climb_Tower`), and a probe on the old map showed the dead did use it:
eight spawned with a scripted player on the deck, all eight were on the deck hitting within 45 s. What was wrong with it:

- the climb was a straight diagonal from the ladder's foot to a point on the deck, through the deck's edge, not up
  the ladder;
- any number climbed at once, inside each other (three within 2.4 m of height on one frame of the probe);
- one way up and no way down: with the player gone (the zip line) the dead stood on the deck until the stuck / no
  progress checks recycled them;
- a crawler whose path led up the link shuttled at the ladder's foot for good (crawlers are exempt from the stuck
  recycle), so a legless zombie could hold a round open under a player on the deck;
- a body killed on the climb hung in the air until its ragdoll started (or for good when the ragdoll cap was full);
- nothing checked any of it: `smoke_ladders` only climbed the player.

## The tower

| | before | now |
|---|---|---|
| decks | one, 3.8 m square, 6.2 m up | the landing 6.2 m up and the top platform 12.0 m up, both 4.8 m square |
| top of the roof / mast | 9.2 m | roof ridge 15.3 m, mast and red lamp 19.1 m |
| ladders | one (north face) | two in stages: north face to the landing, east face from the landing to the top |
| zip lines | one, 14 m, from the deck's roof post | three, 24.6 to 25.5 m, from the top's roof posts |
| lights | 2 lanterns | 5 lanterns, a red masthead lamp, 3 landing-post lanterns, a powered searchlight |

Position unchanged (the yard's south-west corner, `TOWER_X` 5.4, `TOWER_Z` 45.0). Height: 12.0 m for the top was picked
from the lines: the anchors are 2.0 m over the platform (a standing rider's hands reach the bar, as on the old line),
so 14.0 m, and the three landings that are worth going to are 22 to 23 m away on the flat, which gives 26 to 27 degrees.
Much higher and the slopes pass 30 degrees, where the trolley's 5 m/s2 brake no longer holds the speed cap.

Build (own geometry from `Props` and the map's materials: `beam`, `planks`, `floorboards`, `stone`, `iron`,
`sandbag`, `snow`): four 26 cm legs on stone pads with iron straps, running from the ground through the landing to
under the top platform; one tall cross-brace a face a stage with ring beams under and over it and an iron plate where
the cross meets, knee braces and joist ends under each deck; a boarded parapet with a plank cap on three collider bars
round each deck (closed all round, as before: nobody walks off, the climbs and the zip mounts carry over it);
sandbags on the caps of the field sides; four roof posts, plates, a gable roof with snow, a mast with a frozen red
pennant and the red lamp; a searchlight drum on a yoke on the roof's east gable, over everyone's head.

Fair-fight rules kept:

- every brace starts 2.35 m or more over the floor it stands on (the ground and the landing), so nobody walks or
  shoots through a brace at body height and nothing can snag; the old tower's lowest braces started at 0.5 m and were
  walked through;
- the parapet with its sandbags is 1.4 m: the eye (1.62 m) is over it;
- no spot up there is out of reach: both decks are baked navmesh inside the parapet (4.8 m decks leave about 3.7 m
  square walkable), and the dead arrive on both;
- the legs are the only colliders below the landing (four 26 cm posts); the ground spawn `Spawn_YardMound` under the
  tower is where it was.

Lights (`_tower_lights`): the oil lanterns always burn. Three hang outside the yard-side (north-east) corner, one a
stage, so they light the timber of the north and east faces from the ground to the eaves (a lamp inside a parapet
lights the deck and leaves the tower a black shape from the yard); one on the field (south-west) corner; one under the
roof; the red masthead lamp; a small lantern on each zip landing post. The searchlight is electric: group
`power_lights`, zone `STABLE` (the last zone of the cellar lever's sweep; the yard has no turn of its own in
`zone_order`), dark until the lever is thrown, then a 17 degree beam over the yard onto the gate with a little
volumetric fog. It is the only one that asks for a shadow (one spot view, `ShadowBudget` decides); none of the
lanterns cast shadows; the small parts (straps, plates, lantern bodies, joist ends, stays, snow caps, the pennant)
are built with shadow casting off.

## The three zip lines

All from the top platform, each at its own roof post, each its own `ZipLine` node with its own prompt
("Hold [F] to ride the zip line <where>").

| line | anchor (corner) | landing | length, slope | lands in | usable |
|---|---|---|---|---|---|
| `YardZip` "across the yard to the hitching rail" | north-east | (28.9, 42.1), between the cart and the trough, 7 m from the horse | 24.6 m, 27 deg | YARD | always |
| `InnZip` "north to the passage behind the inn" | north-west | (1.7, 20.5), the passage between the inn and the stable, by the stable's north-west corner | 25.5 m, 26 deg | GROUNDS | once the grounds are open |
| `BankZip` "over the fence to the bank road" | south-west | (-14.5, 59.1), the south-west road by the savings bank's shed | 24.6 m, 27 deg | GROUNDS | once the grounds are open |

Why these: three different escapes. The yard line stays inside the yard and puts you by the horse and the gate. The inn
line is the way back to the house: it runs north past the stable's west wall and drops you a few steps from the
passage and the inn's back. The bank line leaves the yard over the south-west fences to the far corner of the grounds,
beside the bank. The landings are 35 to 47 m apart. The wreck (46, 6) is 57 m off behind the stable and the inn, out of
reach of any sensible cable. A line toward the carters' road south-east would cross the Sherman's parking place and
end 6 m from a snow spawn, so the third line goes south-west instead.

Rules chosen:

- **Doors.** A zip line never skips a paid door. A row may name a `zone`; the line is chained ("The trolley is
  chained: the grounds are not open", a use is refused) until that zone is open. `InnZip` and `BankZip` land on the
  grounds, so they need the gate (750, right under the tower) or the front door. `test_ladders_data` holds this: a
  landing outside the tower's own zone must carry that zone.
- **Spawns.** Every landing is more than 3.5 m from every spawn marker (the test checks all of them) and stands on the
  baked navmesh.
- **Down only.** As before. Nothing rides up.
- **Nothing grabs a rider.** The rider is carried (`Player.begin_carry`): no fire, no ADS, the same as the old line.
- **Cooldown.** The old line had none beyond its 0.35 s hold and the ride itself, and the trolley winds back in about
  2 s; unchanged.
- **Speed.** From the slope, by the old ride's physics (gravity down the cable, drag, a cap, a bumper at the post). The
  cap is 9.0 m/s on the three (it was 7.5 on the 14 m line): the rides take about 4.2 s.
- **Bots and companions** do not use ladders or zip lines today (their navigation mask leaves the climb layers out,
  T-153; `ZipLine` never offered itself to them) and still do not.

The old landing post by the stable wall (18.6, 36.2) is gone; `smoke_horse`'s hard-coded post and ladder points were
moved to the new ones.

## The dead climb: "ladder" links

`ClimbLink` (data: the map json's `climb_links`) gained three optional fields. A row with a `line` is a ladder:

    {"name": "Climb_Tower", "zone": "YARD", "from": [5.4, 0, 42.1], "to": [5.4, 6.2, 43.6],
     "bidirectional": true, "line": [5.4, 42.065], "drop": true}

- `line` [x, z]: where a body hangs on the rungs (the players' `LadderClimb` row has the same `line`). The zombie steps
  onto it (0.35 s), goes straight up it at anim.json `climb.speed_mps` (1.4 m/s, the players' pace), then swings over
  the edge onto `to` (`climb.mantle_seconds`, lifting 1.15 m over the parapet).
- one at a time with room between: `ClimbLink.try_enter` lets a body start only when nobody on the rungs is within
  `space` (default 1.9 m) of the foot; the rest stand at the foot (state CHASE, halted, facing the ladder) and ask
  again every 0.25 s. A waiting body goes back to its chase when its target is no longer above, when it is shoved
  3.5 m off the foot, or after 25 s.
- `drop` with `bidirectional`: the dead come back down. Taking the link downward, a body swings out over the edge
  (0.45 s), falls down the line under the map's gravity and reels (STAGGER) where it lands.

Rows without `line` behave exactly as before (every other map's links). Map 0 has two ladder links, `Climb_Tower`
(ground to landing) and `Climb_TowerUpper` (landing to top). The path decides everything: the code runs when the
navigation agent reaches the link. Nothing scans while a zombie chases; the one added check in the chase tick is
`_ladder_wait != null`.

Rules per kind:

| kind | on a ladder |
|---|---|
| Ganger (all variants, the Soviet risen, runners) | climbs, queues, drops back down |
| Bellringer (Map 0's special) | the same (it is a Ganger kind) |
| crawler (legless) | does not climb. One whose path leads up a ladder is put back in the round's queue after 8 s (`recycle()`: it comes back whole through a window or the snow), so it never waits at the foot for good. It may still drop down a ladder (there is no other way down). A climber whose legs are shot off on the rungs lets go and falls |
| the undead horses (HorseBoss, rounds 20 and 30) | never climb (`can_climb_ladders`). See below |
| the yard horse, dogs | not zombies, no navigation links: unchanged |
| the Sherman | never leaves the road: unchanged |

**What the boss does instead.** The horse already had a siege rule (T-240): a player it cannot reach is not chased;
after 8 s it screams every 14 s and every one of the dead within 45 m runs. Those runners now climb. Added: at each
siege scream every player standing on a platform a ladder serves (`ClimbLink.on_perch`: within 4.5 m of a ladder
link's head, 3 m or more up; on Map 0 that is the tower's landing and top) within `siege.perch_radius` (30 m) is
shaken for `siege.perch_damage` (20) with a jolt of the view. So the tower is a strong place to shoot the horse from,
not a safe one: 20 damage every 14 s on top of a sprinting queue up the ladders. `data/gravelight/bosses/horse.json`
`siege`; 0 turns it off. The hayloft and the inn's upper floors are not ladder platforms and are untouched.

**Killed on the rungs.** Hitboxes ride the skeleton, so a climber is shot like any other. A body killed in the climb
state (any climb link, on any map) is let go: it gets the world collision mask back, a 1.1 m/s push away from the
platform, and falls under gravity until its ragdoll takes over or it lies on the floor.

**The player on the ladder.** A player on the rungs is targeted like anywhere else: the dead come to the foot (their
path's nearest floor) and hit a player within reach there, and when the player is over the edge the link is their
path and they come up after them at the same 1.4 m/s. A player at a ladder's head is not safe: `to` is on the navmesh
a step inside the parapet.

## Co-op

Host-authoritative as before. The host moves the climber; the client's puppet follows the snapshots (position, yaw,
state). The climb state is the existing `CLIMB_LINK`, so the puppet plays the climb loop. Two sub-states were added to
the snapshot's sub-state byte (`net_sub_state`: 2 = over the edge, 3 = dropping) so the client plays the mantle and the
drop clips too. A death on the rungs goes through `_start_death` on both sides, so the client's body falls as the
host's does. Waiting at the foot is plain CHASE standing still. Zip rides and ladder climbs of players are, as before,
moved on the rider's own machine (`net_local`) and seen by the others through the player snapshots; the trolley of
another player's ride does not travel on your screen (as before; not changed).

## Animation

The purchased mocap set (`assets/user_supplied/mocap_online/zombie_starter_2_7`, 26 clips) has no climbing or ladder
clip (crawl loop and stand-to-crawl are its only low clips). The climb uses the project's own procedural clips that
T-041 made for climb links: `climb_loop` (hands over head alternating, knees up) on the rungs, `climb_mantle` over the
edge, and `drop_down` (the high-window drop) for the drop back down. If a climb clip is bought later, it goes in
anim.json `clips.climb.loop`.

## Costs added (Map 0)

Counted from the generated scene before and after (every MeshInstance3D and Light3D in `map00.tscn`):

| | before | after | added |
|---|---|---|---|
| triangles (whole map) | 374,608 | 390,688 | 16,080 |
| of them in shadow-casting meshes | 166,412 | 177,908 | 11,496 |
| lights | 132 | 140 | 8 |
| lights that ask for a shadow | 18 | 19 | 1 (the searchlight, a spot: one shadow view) |
| collision shapes | 636 | 651 | 15 (the second deck and its 12 rail bars, two more posts) |

Most of the 16 k triangles are the round parts the prop library makes: about 45 sandbags (spheres),
three 20-segment cables, the lantern bodies. The sandbags and the heavy timber cast shadows; the straps, plates, joist
ends, lantern bodies, stays, snow caps, cables and the pennant do not. The lights: 2 lanterns before; now 5 lanterns
(ranges 11 to 16 m), the masthead lamp (12 m), 3 landing-post lanterns (6.5 m), all without shadows, and the
searchlight (38 m, 17 degrees, shadowed, only after the power is on). If T-266's budget wants less: the field-corner
lantern and the three post lanterns are the first to go, and the sandbags' shadows.

Per-frame script cost: none while nothing is at a ladder. A waiting zombie does one list walk of the ladder's queue
(at most the bodies on the rungs, 6 in the soak) every 0.25 s; a climber does one position write a tick, like the old
link climb. The horse's platform check walks the map's ladder links (2) once a siege scream (every 14 s).

## Verified, and how

Headless on Windows (`--headless --audio-driver Dummy`); renders under WSL + Xvfb only.

- `check_scripts`: 975 scripts, 0 failed.
- Full GUT: 2463 tests, 2462 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised`); the baseline was 2460 / 2459 / 1, the three more are `test_ladders_data`'s new ones. The fourth new test (the tower's lights) was added while that run was going and was run with its file afterwards (7 of 7). The intermittent `test_movement_perf` test passed.
- `test_ladders_data` (7 tests): the three lines (anchors 2 m over the top, slopes 15..30 degrees and inside the
  brake's hold, the set-down a step short of the post on the line, landings on the baked navmesh, a landing outside
  the tower's zone carries that zone and a locked text, every landing more than 3.5 m from every spawn marker, a post
  built where each cable ends, landings more than 15 m apart, three names and three targets, both decks in the yard's
  zone); the ladder links (line a step from both ends, both ends on the navmesh, drop needs a two-way link, the
  players' ladder shares the line, the upper starts where the lower ends); the queue's rule (pure); the tower's
  lights (nine lanterns without shadows, the searchlight on the power sweep). `test_map00_art`'s navmesh fingerprints
  re-set (the bake changed: see below). `test_capture_cams`' height bound raised for the top platform.
- The navmesh elsewhere: the old and new scenes' polygons compared one by one (`.smoke_logs/t268/navdiff.gd`, a
  throwaway): 70 polygons gone, 81 new, all of them in the yard (the tower, the old and new yard post), at the
  passage's west end by the InnZip post (x -1..3, z 18..21) and round the BankZip post (x -18..-8, z 51..63). No
  polygon changed anywhere else.
- `smoke_ladders` PASS (0 failed, 144 checks; three passing runs, the last on the final build; the one failing run before them was the crawler's refusal clock being reset each time it re-reached the link, fixed): the four ladder climbs in stages;
  for each zip line: nothing in a hanging rider's way down the line (a body capsule at 40 places), the anchor reached
  on foot on the top platform, the bar under the interaction ray from there, the two grounds lines chained until the
  grounds open, the ride carried and hanging, the landing where the data says, the rider standing free there; a
  zombie climbs both stages to a player on the top and hits them (hp 100 to 50 in 16 s from its rise in the yard);
  left up there it drops back down both stages; a zombie follows a player up the ladder; four at the foot go up one
  after another (up to 3 on the rungs, never closer than 2.02 m); a climber killed 3.5 m up falls to the ground (its
  hitboxes live on the rungs); a crawler never climbs and is requeued 8 s after reaching the foot.
- `smoke_coop` PASS (failed once on my own first check, which wanted the puppet standing on the landing; the host's
  zombie turns round at once and drops, the players being in the taproom; the check now wants it over the edge at the
  ladder's head): the client sees a zombie puppet in the climb state on the ladder's line rising, then at the head.
- `smoke_horse_boss` PASS (81 checks): with a player on the tower's top the horse does not chase, stays on the
  ground, and its siege scream shakes them. `smoke_horse` PASS (116 checks).
- `smoke_sherman` PASS, first run (74 checks). `smoke_map00`, `_alive`, `_cellar_bay`, `_loop` PASS (twice: before
  and after the last lighting changes). `smoke_bots`, `smoke_bots_shop`, `smoke_bots_u10`, `smoke_squads`,
  `smoke_jakub`, `smoke_weapon_locker` PASS. `smoke_bots_shop_m0`: FAIL 'no squad bot did bench' in 3 of 4 runs, PASS in the fourth (the known intermittent; the bench is in the stable, nothing of this work is near it; the three failures ran while WSL renders loaded the machine, the pass after they had stopped; no baseline run on master was made here).
- The soak (`probe_tower_soak.tscn -- --soak --round=2 --secs=720`): the rounds run, the stable's and the yard's doors
  open as a squad would have them, a scripted player stands on the top platform and kills only what has stood within
  2.5 m of them for 1.5 s; every sixth riser has its legs shot off on the way. Rounds 2 to 7 all ended, in 84, 101,
  106, 56, 168 and 121 s, with 9, 11, 14, 9, 21 and 23 arrivals on the top; the first arrival 15 to 34 s into a
  round, then one about every 2 s while the queue at the ladder is full (the ladders' throughput), up to 6 bodies on
  the two ladders at once; 3 bodies put back in the queue over the six rounds; nothing left standing at the base
  (round 8 had begun when the time ran out, its one live zombie 58 s old and on its way).
  Two earlier soak runs are not evidence for the game and are kept only as a warning about the probe: with only the
  yard's zone opened by hand (no door actually open) or with `forced_target` on every zombie, one or two bodies stood
  at a shut door for minutes; `forced_target` switches off the dead's own way round a shut door.
- `check_mapdata` PASS after the minimap rebake (WSL): the yard's zone on the map data reaches the top platform (the
  HUD says THE CARTERS' YARD up there; it said CROSSROADS INN before the rebake).
- Renders (WSL + Xvfb, the Compatibility renderer: no SDFGI, no volumetric fog, so nights are darker and beams do
  not show; 1280x720), all looked at: `docs/captures/t268/`, 31 frames from the final build. Night and noon: the
  tower from 12, 20, 43 and 35 m (`near`, `mid`, `far`, `inn`), the landing and the top platform, down each line from
  its anchor (`down_*`), each landing looking back up the cable (`land_*`); the dead on the lower ladder at noon and
  at night and on the upper ladder (`climbers_*`); the searchlight after the lever (`searchlight_*`); a frame mid-ride
  on the inn line (`ride_inn_night`). What the frames changed: the lanterns were moved outside the yard-side corner
  and made stronger (inside the parapet they lit the deck and left the tower black from 20 m); the top's lantern went
  up into the gable (it hung at eye height); the searchlight went from the parapet's corner to the roof's east gable
  (it stood in the face of whoever took the yard line); the mast grew to 6.8 m over the platform (the eaves hid it).

## For the owner's eye

- **The look on a real GPU.** Everything was seen only through the software Compatibility renderer. Night reads
  there as a lit timber frame with a red masthead lamp from 20 m and as lamp points with a faint frame from 43 m. On
  the Forward+ renderer the lanterns' pools, the fog and the searchlight's beam will look different: please look at
  the tower at night from the inn's side and from the south-east grounds, before and after the lever.
- **The searchlight's beam and pool.** In the renders the lit lens shows after the lever; the pool on the snow inside
  the gate is a general brightening of the yard between the gate and the well with no edge and no beam in the Compatibility
  renderer (`searchlight_pool_night`). Its real look is unverified.
- **The pace on the top.** One zombie about every 2 s once a queue has formed is what the ladders pass. If the top is
  too hot or too safe, the two numbers are `space` on the climb link rows (1.9 m: bigger is slower) and anim.json
  `climb.speed_mps` (1.4; it is shared with every other map's climb links).
- **The horse's shake** (20 damage every 14 s to players on the tower within 30 m of it) is a new rule nobody asked for
  by name; it is the answer to "the tower must not be where a boss can never reach the player". `horse.json`
  `siege.perch_damage` 0 switches it off.
- **Two of the three lines need the grounds open.** If the owner would rather have all three free, drop `zone` from
  the two rows (a rider would then get onto the grounds without paying for the gate or the front door).
- **The dead tree at (5, 48)** stands a metre and a half south of the tower's deck edge, outside the fence. It did
  not reach into a deck in any frame, but no frame looks at the tower's south face from close by.
- **Players' rides and climbs in co-op** look as they did (the rider's own machine moves the body; the trolley of
  another player's ride does not travel on your screen). Not changed, not rechecked beyond `smoke_coop`.
- **Bots** do not climb the tower or ride the lines (as before). A human who goes up leaves the squad on the ground;
  the bots' "cut off" logic is the old one.
- **A zombie that lands on the roof.** `debug_spawn` with many bodies on one spawn point at once can throw one high
  into the air (it did so before this work too); with the tower taller and wider one landed on the top platform in a
  probe. The director's normal spawning does not stack bodies like that; not seen in the soak.

## Another map: a ladder link or a zip line from data

Both are rows in `data/gravelight/<map>.json`; `MapRoot` spawns them. No code.

A ladder the dead climb (and drop down):

    "climb_links": [{"name": "Climb_X", "zone": "<zone id>", "from": [x, y, z], "to": [x, y, z],
                     "bidirectional": true, "line": [x, z], "drop": true, "space": 1.9}]

`from` and `to` must be on the baked navmesh (`probe_ladder_tops.gd -- --map=<map>` prints every end's distance to
it); `line` is 0.4 m off the rungs on the side a body hangs; `zone` keeps the ladder shut until that zone opens. Leave
`line` out for the old straight climb. The players' side of the same ladder is a pair of `ladders` rows with the same
`line` (`test_ladders_data` wants a climb link for every player ladder, so no ladder is a route for players alone).

A zip line:

    "ziplines": [{"name": "XZip", "pos": [x, y, z], "end": [x, y, z], "to": [x, y, z], "yaw": deg, "speed": 9.0,
                  "hang": 2.7, "sag": 0.45, "target": "to the ...", "zone": "<zone the landing is in>",
                  "locked_text": "The trolley is chained: ..."}]

`pos` is the cable's top, 2.0 m over the floor the rider stands on and a step outside its rail; `end` the cable's low
end on its post (2.75 m up); `to` the feet, 0.9 m short of the post on the line; keep the slope under 30 degrees. The
cable, the posts and their lanterns are the generator's dressing (Map 0: `ZIP_LINES` in `gen_map00.gd`, one row a
line); the trolley is the `ZipLine`'s own.
