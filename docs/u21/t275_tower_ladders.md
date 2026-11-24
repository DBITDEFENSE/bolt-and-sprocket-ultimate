# T-275: the watchtower's ladders, placed where a body can use them

The owner (2026-11-24): "The guard tower looks good but it needs work on the ladder placement."

Branch `claude/tower-ladders` (from master a15b7146). Map 0 is generated: `gen_map00.gd` (`TOWER_*`, `_dress_tower`,
`_tower_ladder`, `_tower_parapet`, `_tower_floor_rects`) and `data/gravelight/map00.json` (`ladders`, `climb_links`).

## What was wrong (T-268's tower)

Both decks had a parapet closed on all four sides. The lower ladder ran up the outside of the north face and arrived
against the landing's solid parapet. The upper ladder ran up the outside of the east face from the landing's height,
outside the landing's parapet: its foot hung in the air beside the deck, you would have had to climb out over the rail
to reach it, and it too arrived against the top's closed parapet; climbing zombies hung off the outside of the tower.
The climbs only worked because `LadderClimb` / the climb link carried the body over the boards.

## What it is now

All coordinates are world metres (the tower's centre is x 5.4, z 45.0; landing floor y 6.2, top floor y 12.0).

**The lower ladder** (north face, ground to the landing) stays where it was: its back on the north face (z 42.58),
the rungs at z 42.465, the climber's line (5.4, 42.065).

- The landing's north parapet has a 1.0 m opening centred on the ladder, x 4.9..5.9: the boards, the cap and the
  three collider rail bars stop there, a post closes each end.
- The rungs stop at the landing's floor; the two stiles go on 1.0 m over the deck (to y 7.2) as hand holds and bend
  over onto the deck's edge (a short return and a post down to the boards, an iron strap at the floor). You step
  through between them.
- The stiles' hand holds have colliders (`TowerLadderStile`, 5 cm poles 0.35 m apart, y 6.2..7.2): nobody walks off
  the landing through the opening (the smoke walks into it straight and at both posts, sprinting: stopped every time).
- The player's climb ends at (5.4, 6.2, 43.05), just inside the opening; the head's prompt stand (`TowerLadder_Top`)
  is there. The dead's link ends at (5.4, 6.2, 43.35) (the navmesh starts about 0.5 m in from the deck's edge).

**The upper ladder** (landing to the top) moved INSIDE the tower:

- It stands on the landing's floor against the east side, its centre x 6.875, its back on z 45.6, the stiles at
  x 6.65..6.70 and 7.05..7.10, z 45.46..45.51; the climber's line (6.875, 45.085), facing south.
- It goes up through a hatch in the top platform's floor: x 6.45..7.3, z 44.65..45.6 (0.85 x 0.95 m). The hatch's
  east edge is the parapet itself. It sits between the joists at x 6.4 and 7.4 (none is cut), with a trimmer beam
  under the boards on its north and south edges and two iron cleats tying the ladder to the south trimmer. Clear of:
  the legs (the nearest, the south-east leg, is at x 7.37..7.63, z 46.97..47.23), the upper bracing (on the faces, at
  the leg lines), the zip mounts (north-east, north-west and south-west corners; the YardZip rider stands about 1.5 m
  north of the hatch's rail), the searchlight (on the roof's east gable, 2.75 m over the floor) and the roof posts.
- The top's slab collider is four pieces round the hatch (`_tower_floor_rects`, also the floorboards). A guard rail
  (`TowerHatchRail`: kick board, mid rail and top rail like the parapet's, three posts) closes the hatch's north and
  west sides; the parapet closes its east side; the open side is the south, where the ladder's head is.
- The rungs stop under the top's floor; the stiles go on 1.0 m over it (to y 13.0) as hand holds bent over onto the
  boards south of the hatch. Their colliders run the ladder's whole height (y 6.2..13.0): on the landing the ladder is
  a thing you walk round; on the top, with 0.2 m between each stile and the rail's end or the parapet and 0.35 m
  between the stiles, nobody walks into the hatch (the smoke tries from the south over the ladder's head, past both
  stiles, from the west and from the north: stopped every time).
- The climber steps off over the ladder's head onto the platform south of it: the player's climb ends at
  (6.8, 12.0, 46.4), where the head's prompt stand (`TowerLadder_Head`) is; the dead's link ends at (6.6, 12.0, 46.5).
  The foot's prompt stand (`TowerLadder_Upper`) and the player's way down end at (6.875, 6.2, 44.7), the dead's link
  starts at (6.875, 6.2, 44.75).
- Why the ladder faces that way: a body shot on the rungs is pushed away from the link's head (zombie.gd,
  `_ladder_on_death`: 1.1 m/s, away from `to`). With the head on the south side the push is north, toward the
  landing's middle, so a body killed anywhere on it falls inside the tower onto the landing. The smoke shoots one 2.5 m
  and one 5.0 m up the ladder (just under the hatch): both bodies lie on the landing. Had the step-off been toward the
  tower's middle, the push would have thrown a body killed near the top over the landing's parapet.

The landing's parapet is closed except the ladder's opening; the top's parapet is closed all round.

`map00.json`: `TowerLadder_Foot` (to), `TowerLadder_Top` (pos), `TowerLadder_Upper` and `TowerLadder_Head` (pos, to,
yaw, line, face), `Climb_Tower` (to, perch) and `Climb_TowerUpper` (from, to, line, perch). Both tower links got
`"perch": 5.3` (T-272's field): with the heads moved, 4.5 m from the head no longer reached every corner of the decks
(the landing's south corners are 4.7 m from the new lower head, the top's north-west corner 5.2 m from the upper head),
so the horse's siege shake now covers both decks to the corners, as T-268 meant it to. Nothing else in the rows (no
timing, no prompt text, no zone, no spacing) changed.

Unchanged: `climb.speed_mps`, `mantle_seconds`, the hold time, the prompts, the queue's spacing, the drop, the zip lines
and their mounts, all code. The dead still climb one at a time, wait at the foot, and drop back down when the players
leave (the drop now falls down the line inside the tower).

## The scene diff (master's map00.tscn against the regenerated one)

`.smoke_logs/t275/scenediff.gd` (a throwaway): every mesh, collision shape, light, marker and area as a multiset of
(type, world position, size, material), so the renamed duplicates do not count, and the navmesh polygon by polygon.

| | master | new | change |
|---|---|---|---|
| triangles (whole map) | 390,688 | 390,724 | +36 |
| of them in shadow-casting meshes | 177,908 | 177,920 | +12 |
| collision shapes | 651 | 667 | +16 |
| lights (shadowed) | 140 (19) | 140 (19) | none |

All differing items are inside the tower's box (x 2..9.5, z 41..49): 10 items only in master, 26 only in new, 0
outside. Colliders: +3 slab pieces, +3 rail bars (the landing's north side in two runs), +6 hatch rail bars, +4 stile
poles. Triangles: six fewer rungs (both ladders stop at the floor) and the removed iron stand-offs of the old upper
ladder roughly pay for the hand holds, posts, trimmers and the split floor. No light was added.

Navmesh (both `Navigation` and `NavigationBreachOpen`): 4 polygons gone and 12 new, all of them on the tower's decks;
no polygon changed anywhere else. On the top the hatch is a hole in the navmesh (with the rail and stiles, x 5.75..7.0,
z 44.25..46.0); the strip south of it, where the dead step off, is joined to the rest round the hatch's west side, and
paths from the head reach all four corners. On the landing the ladder is a hole of about 1 x 1.2 m; the opening's head
is on the navmesh. `test_map00_art`'s fingerprints re-set.

`data/maps/map00_crossroads/mapdata.json`: `resign_mapdata` ran; the signature did not change (the map data's POIs
are the inn's stairs and the cellar hatch's ladder, nothing on the tower). The minimap's floor images were not rebaked
(a rendered run; the hatch is under the tower's roof on a top-down view).

## Verified

Headless on Windows (`--headless --audio-driver Dummy`); renders under WSL + Xvfb only, one at a time.

- `check_scripts`: 1020 scripts, 0 failed.
- Full GUT: 2631 tests, 2630 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised`).
  None of the known intermittents (`test_transitions` preload, the `test_movement_perf` test) failed this time.
  `test_ladders_data` 7 of 7 (both links' ends on the baked navmesh, the players' ladders on the same lines, the
  upper link starting on the landing the lower one ends on); `test_map00_art` 8 of 8 after the fingerprints.
- `probe_ladder_tops -- --map=map00`: every ladder and link end on the navmesh (d 0.00).
- `smoke_ladders` PASS (234 checks, 0 failed; two passing runs, the second with the new checks). The four tower climbs,
  the three zip lines (mounts on the top unchanged), a zombie climbs both stages to a player on the top and hits them
  (hp 100 to 50 in 16 s), left there it drops back down both stages (5 s), one follows a player up, four queue up one
  after another (up to 3 on the rungs, never closer than 1.93 m), a climber killed on the lower ladder falls to the
  ground, the crawler is requeued after 8 s. New (T-275): a climber shot 2.6 m and 5.0 m up the upper ladder lies on
  the landing both times (hips at y 6.31, z 42.97 / 43.07: the ragdoll slides north to the landing's north rail and
  stops there); the player sprinting into the landing's opening (straight, at each post) and into the hatch (over the
  ladder's head, past each stile, from the west, from the north) is stopped on the floor every time.
- `probe_tower_soak -- --soak --round=2 --secs=720` (the scripted player on the top platform at (6.2, 12, 46.6), beside
  the upper head), twice:
  - run 1: rounds 2 to 6 ended in 84, 92, 146, 158, 119 s with 9, 11, 14, 18, 20 arrivals on the top; up to 6
    bodies on the two ladders at once; 2 put back in the queue over the run;
  - run 2: rounds 2 to 8 ended in 85, 74, 94, 124, 104, 91, 109 s with 9, 11, 14, 12, 23, 23, 26 arrivals; up to 6 on
    the ladders; once a queue forms one arrival about every 2 s, as T-268 measured; at the end 5 bodies were on the
    rungs of both ladders and the rest on their way (round 9 had begun).
  - In round 5 of both runs (the round a friendly squad walks in) the director relocated 6 and 4 "stranded" bodies to
    the top; T-268's own soaks show the same in round 5 (2 each), so it is the squad event, not the new ladders.
- `smoke_map00`, `smoke_map00_alive`, `smoke_map00_cellar_bay`, `smoke_map00_loop` PASS. `smoke_horse_boss` PASS (81
  checks): with a player on the tower's top the horse does not chase and its siege scream shakes them. `smoke_coop`
  PASS: the client sees the climbers on the lower ladder.
- Renders (`docs/captures/t275/`, 1280x720, the Compatibility renderer under WSL): the `t275` set, 15 cameras, shot on
  master's scene (`*_before.png`) and on this branch's (`*_after.png`), all looked at. The opening and its hand holds
  read from the yard and from the landing; the upper ladder stands on the landing and goes up into the hatch; from
  the top the hatch is a framed hole with the ladder's head on its open side; a climber comes up inside the rail.
  Nothing in the frames needed a change.

## Not verified

- The look on a real GPU (Forward+): seen only through the software renderer.
- The co-op client's view of a climber on the upper ladder (smoke_coop puts its climbers on the lower ladder) and of a
  body falling inside the tower; the code is the same as for the lower ladder.
- The minimap's floor image of the top platform (not rebaked: a rendered run; the hatch is under the roof).
- How it feels to climb in first person on a GPU: the hands still reach for rungs over the floor at the end of a climb
  (LadderClimb places them by the rung spacing, not by the drawn rungs; unchanged, as on every ladder in the game).
- A zombie still lifts 1.15 m crossing the head of either ladder (`LADDER_HUMP`, made for the old parapet; code
  untouched by this task): through the opening and over the hatch's hand holds it reads as a vault, not a step.
- A body shot on the upper ladder ends near the landing's north rail (its ragdoll slides about 2 m north); it has
  never gone over the rail in the checks, but only two heights were tried.

## DECISIONS paragraph (ready to paste)

**T-275, 2026-11-24: the watchtower's ladders (the owner: "the guard tower looks good but it needs work on the ladder placement").** Branch `claude/tower-ladders`, notes `docs/u21/t275_tower_ladders.md`, renders `docs/captures/t275/` (before / after, same cameras). T-268's tower had both decks closed by a parapet on all four sides: the lower ladder (outside the north face) arrived against the landing's boards, and the upper one ran up the outside of the east face from the landing's height, outside the landing's rail, its foot in the air, arriving against the top's boards; climbers hung off the outside of the tower. Now: the lower ladder stays on the north face and arrives through a 1.0 m opening in the landing's north parapet (x 4.9..5.9), its stiles carried on 1 m over the deck as hand holds; the upper ladder stands inside the tower on the landing (centre x 6.875, back on z 45.6) and goes up through a 0.85 x 0.95 m hatch in the top's floor against the east parapet (x 6.45..7.3, z 44.65..45.6, between two joists; clear of the legs, the bracing, the three zip mounts and the searchlight), the slab collider cut round it, a guard rail on its north and west sides, the ladder's head and hand holds on its open south side. The climber on the upper ladder faces south and steps off over the ladder's head: chosen so the push a body gets when shot on the rungs (away from the link's head) points north into the landing, so it falls inside the tower, not over the rail. The hand holds have colliders (two poles 0.35 m apart): nobody walks off through the opening or into the hatch. `map00.json`: the four tower `ladders` rows and both climb links moved; both links got `"perch": 5.3` so the horse's siege shake still reaches every corner of both decks. No timing, prompt, zone, spacing or code changed. Map 0 regenerated: the scene diff (multiset of meshes, shapes, lights, markers; both navmeshes polygon by polygon) shows changes only inside the tower's box: +36 triangles (+12 shadow-casting), +16 collision shapes, no light; navmesh 4 polygons gone and 12 new, all on the decks. Verified: check_scripts 0 failed; full GUT 2631 / 2630 passing / 1 risky (known); smoke_ladders (234 checks, with new ones: a body shot on the upper ladder lies on the landing, the player cannot walk off through the opening or into the hatch), smoke_map00 (4), horse_boss, coop PASS; two 12-minute soaks on the top (rounds 2-6 and 2-8 all ended, up to 6 on the ladders, one arrival about every 2 s once a queue forms). Honest state: software renderer only; the client's view of the upper ladder and the minimap's top floor not checked; zombies still vault 1.15 m over a ladder's head (`LADDER_HUMP`, unchanged).
