# Morning report: THE CLIMB AND THE RIDE MOVE, 2026-11-09 (late)

**The ladder climbs and the zip line ride are animated now, and the stray wood in the Inn's first room is gone.**
Branch `claude/maps-1-2-production` (with the three earlier passes), not merged: look first.

## The ladder (every map)
- Hold Use at the foot: you step onto the ladder, turn to the rungs, the gun goes away and both hands come up. You go
  up in pulls, rung by rung, the view bobbing and tipping toward the pulling hand, a hand letting go and reaching for
  the next rung while the other holds; a rung sound per rung (wood on the tower and the cellar hatch, metal on the
  U-boat). At the top you swing over the rail onto the deck and the gun comes back up. Down is the same, mirrored.
- You keep the mouse, within a wide cone of the ladder. The radar tower's ladder (Act III) moves the same way.

## The zip line (Map 1)
- Hold Use at the trolley: you step under the anchor, grab the bar at shoulder height, step off and drop into the hang.
  The trolley starts slow and gains speed down the slope (gravity, capped at 7.5 m/s), you hang and swing under it,
  lagging as it pulls, the wheels spin, the wind rises, the view opens; at the post you let go and land.
  3.6 seconds instead of a 2-second slide.

## The piece of wood
- The Inn's first room is the taproom. Seven camera renders of it showed one odd upright: the fire poker, a bare block
  standing on the floor a step from the hearth. It is a proper set of fire irons on the hearthstone now (stand, poker,
  tongs, brush, the bellows on the jamb). The Waschkaue (Map 1's first room) was checked too: the one odd thing in its renders, a tan rectangle at the top of the right doorway seen from the back wall, is a lit window of the yard building north-east (x 15, 3.9 m up, on that sight line; two closer doorway cameras, u10_map01 A_kaue_door_r / A_kaue_door_r2, show nothing there); the probe (extended to the generators' geometry boxes, Props.probe_geo) lists nothing wooden in the corridor.

## Checked
- `smoke_ladders`: smoke_ladders PASS (73 checks, four runs through the iterations), smoke_map04c_world PASS (the radar tower's climb, 3.0 s + the mount and dismount, still inside the smoke's 4.2 s wait), unit test_ladders_data 3, test_capture_cams 3, test_world_objects 16, test_map00 60, test_map02 18, test_map04c 8 PASS, check_scripts 877 scripts 0 failed; map00 regenerated (598 collision boxes, unchanged; the fire irons are dressing); renders here under WSL: morning/screenshots/u05/anim4 (ride_zip: the yard below the raised arms, the stable wall ahead; ride_zip_up: the arms up to the trolley), anim3 (ride_climb: the right glove on the lower rung), anim1 (taproom_hearth: the fire irons), u10_map01/anim1 (the Kaue doorway cameras).
- Renders here under WSL: `morning/screenshots/u05/anim1/` (mid-climb, mid-ride, the hearth) and `u10_map01/anim1/`.

## Please look
`tools_src/capture.gd --set=u05 --only=ride_climb,ride_zip,ride_zip_late,taproom_hearth` or DevLauncher into Map 1:
buy the yard door, climb the tower, ride the line. Say if the climb should be faster or slower (one number, PACE in
`gravelight/world/ladder_climb.gd`) or the line faster (speed in `data/gravelight/map00.json`).
