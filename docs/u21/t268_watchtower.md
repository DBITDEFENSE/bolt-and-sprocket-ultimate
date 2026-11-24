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
| top of the roof / mast | 9.2 m | roof ridge 15.3 m, mast and red lamp 17.6 m |
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
pennant and the red lamp; a searchlight drum on a yoke on the top's north-east corner.

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

RESULTS_COSTS

## Verified, and how

RESULTS_VERIFIED

## For the owner's eye

RESULTS_OWNER

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
