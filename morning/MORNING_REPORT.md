# Morning report: SNIPER TOWER, ZIP LINE, LADDERS, 2026-11-09 (night)

**The Inn's yard has a sniper tower with a zip line, and ladders are a real mechanic now: every drawn ladder on every
map either climbs (hold Use) or is visibly shut.** Branch `claude/maps-1-2-production` (with the two earlier passes),
not merged: look first.

## Map 1 (the Inn): the Hochsitz
- A timber watch tower in the Carters' Yard's south-west corner: 3.8 m boarded deck 6.2 m up, a closed rail, a roof with
  a lantern, sandbags on the field side. Hold Use at the ladder's foot to climb, again at the top to come down.
- Zombies climb the same ladder (their own climb link), so you hold the deck, you do not hide on it.
- The zip line leaves the roof post and lands you by the yard door's lamp on the stable wall: hold Use at the trolley.
  Two seconds, the trolley rides with you and winds back.
- The cellar hatch behind the bar is real: the floor is cut, a plank leaf covers it until you buy the Old Cellar, then it
  falls back and the aunt's ladder climbs both ways (zombies come up it too).

## Ladders on every map (audited against the baked navmesh, `probe_ladder_tops.gd`)
- **Work:** the tower, the cellar hatch (Map 1); U-1047's engine room escape hatch to the deck (Map 3, new: the deck is
  cut, coaming, lid thrown back, NOTAUSSTIEG); the radar tower and the Kranich's wing hatch as before.
- **Shut, and look it:** Map 3's crane-leg ladder (locked guard plate), both U-boats' bridge ladders (GESPERRT chain),
  Thalbach's signal-post ladder (anti-climb guard) and the hung office's ladder (chain under its own sign).
- **Stowed:** the Inn attic's hatch ladder and Thalbach's four jig ladders hang on hooks: nothing to climb to.
- **Left as drawn:** Map 3's landing-stage and lower-pen ladders go down into the water.

## Checked
- `smoke_ladders`: every climb and the ride end where they should, on the navmesh, the body moves again; the hatch is
  bolted then opens with its zone; the climb links exist. Facing runner, invisible-wall probe unchanged on Maps 1, 3, 4a.
- Unit: Map 0 (navmesh fingerprint re-set for the deck and the hatch cut), Map 2, Thalbach, capture cams PASS.
- Smokes: smoke_ladders, map00, map00_alive, map00_cellar_bay, map00_loop (failed once under load, PASS alone), inn_opening_paths, inn_survivors, story_props, interact, cousins, map02 (failed twice under load with the rounds running 3x slow, PASS alone in 142 s), map02_art (after the hatch's deck pieces were tagged to draw from the hall), map02_world, map04a, map04a_world PASS; letzte_fahrt hit the runner's 20-minute cap as before (no result, no error)
- Minimap for Map 1 re-baked (the tower and hatch are connectors).

## Please look
`tools_src/capture.gd --set=u05 --only=yard_tower,tower_deck,bar_hatch` or DevLauncher into Map 1, out of the yard door,
turn left. My own renders: `morning/screenshots/u05/t229b/` (the deck) and `t229c/` (the tower from the well, the bar hatch).
