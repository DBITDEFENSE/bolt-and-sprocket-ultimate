# T-273: Totenhafen's map detail pass (the geometry step)

The owner, 2026-11-24: "go through and look at all the maps and apply a level of detail that you see that we have in
the first map ... there's level design, there's things that happen throughout the rounds."

Branch `claude/detail-map02`. Map 2 is generated: `gravelight/tools_src/gen_map02.gd` (+ `detail_map02.gd`), data in
`data/gravelight/map02.json`. Regenerate headless:

    "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map02.gd

Coordinates are map space, metres, `[x, y, z]` (+X east, +Z south, the sea north of the quay at z < 0).

## 1. The raid's landmark: the patrol boat V 1507

| What | Where | Verified by |
|---|---|---|
| A Vorpostenboot (a requisitioned steam trawler in navy grey), 34 m, moored to two buoys | waterline amidships `[16, -2, -20]`, bow west (yaw 90), port side and number to the quay; 16.5 m off the parapet at its nearest | test_map02_detail (on the scene: its meshes in the quay's batch group, the target on it, nothing of it over the shingle); renders |
| `stuka_target` | `[17.0, 1.7, -20.0]`, the wheelhouse; `stuka_from [40, 0, -420]` (down out of the north, over the sea the quay looks at) | smoke_map_detail: the bomb lands at `(17.0, 1.7, -20.0)` |
| The fire the bomb starts | `MooredHullFire` (flames on the bridge, the forecastle and the waist, smoke, one light without a shadow), hidden until the hit; `stuka_hit_show` | smoke: hidden before, shown after the hit; render `02_boat_fire_night` |
| Its own banner and lines | stuka `banner_small` "A DIVE BOMBER IS COMING DOWN ON THE PATROL BOAT"; raid `vo_warn` `OPR_RAID_M2_WARN_01` (the pens, not Map 0's cellars), `vo_clear` `OPR_RAID_M2_CLEAR_01` (`vo_during` was already the map's) | test_map02_detail; smoke banners |
| The bursts on the quay | raid `burst`: stone and a little snow (Map 0's yard keeps snow and earth) | test_map02_detail (the kinds are Effects' own) |

Built in `DetailMap02.patrol_boat`: a lofted steel hull (raised forecastle with a sloped break, a cruiser stern and
its transom, red below the boot-top), inner bulwarks and cap, the decks, the bridge house, the wheelhouse with windows
and wings, a searchlight, the raked funnel with its black top, two masts with stays, shrouds and the aerial, an 8.8 cm
in its tub on the forecastle, a 2 cm on the stern, the fish hold's coaming, a winch, depth-charge rails, the ship's boat
on its davits (over the sea side), the hull number on both bows, riding lamps (emissive only), the anchor cable, two
buoys and their lines, snow on the decks. No collider: nobody reaches it (the parapet and the stages' kerb rails hold
the quay). The bomb hurts within 6.5 m; the nearest ground anyone stands on is 16.5 m off.

Script changes, data-driven, defaults unchanged:
- `sherman_event.gd`: `stuka_hit_show` (names of hidden nodes shown where the dive bomber's bomb lands, on every
  peer: it runs before the puppet's early return). `show_hit_nodes()` is also a capture `call:` verb. Map 0 and
  Kaltenbrunn do not set it.
- `air_raid.gd`: `burst_fx(..., kinds)` takes the raid table's `burst` rows (`[[dirt kind, strength, amount]]`);
  empty is snow and earth, as before. `sherman.json` has no `burst` row (a test holds it).

Cost: the boat is folded to one mesh per material and shadow mode (`GenDetail.merge_children`) and hung in
`StaticBatches/VisGroup_A` (the quay's batch group: the shadow proxies and the view cells already work on it; no new
container). Scene census before / after: meshes 1210 -> 1233 (+23 draw calls where the quay is drawn: 4 hull meshes,
19 folded), triangles 381,361 -> 395,587 (+14,226; in shadow casters +7,906), lights 192 -> 193 (+1, the fire's,
hidden until round 30, no shadow), shadowed lights 22 (unchanged), collision shapes unchanged.

Renders (WSL + Xvfb, Compatibility renderer, 1280x720), looked at: `docs/captures/t273/00_boat_night` ..
`04_boat_stage_noon`. At night the boat is a silhouette with its riding lamps against the sky; at noon the grey hull,
the number, the bridge and the funnel read from the parapet. Seen and not mine: at noon the storm card on the north
horizon reads as a black band (the T-259 day cycle's), and the Compatibility sea is pale.

## 2. The catwalk ladders and the signal balcony's zip line

| What | Where | Verified by |
|---|---|---|
| West catwalk ladder (iron rungs against the catwalk's edge, stayed to its underside) | foot `[-17.415, 0, 55.5]` on pier 0, head `[-19.0, 4.0, 55.5]`; line `[-17.415, 55.5]` | smoke_ladders: up and down, ends on the navmesh; a zombie on pier 0 came up it to a player on the catwalk in 9 s |
| North catwalk ladder | foot `[15.0, 0, 35.585]` on the north apron, head `[15.0, 4.0, 34.0]` | smoke_ladders |
| East catwalk ladder | foot `[49.415, 0, 72.0]` on the east apron, head `[51.0, 4.0, 72.0]` | smoke_ladders |
| The zombies' climb links | `Ladder_CatwalkW/N/E` on the same lines, now ladder links (`line`, `bidirectional`, `drop`: one at a time up the rungs, they drop back down) | test_map02_detail, smoke_ladders |
| The signal balcony | a grated platform x 46.8..50.4, z 38.15..40.65, 7 m up, outside a new door (x 47.6..49.6) in the signal tower's south wall; the window beside it is shorter (x 44..46.8). Rails on its three open sides; zone `G_SIGNAL` (a new zone box), a nav link through the door | test_map02_detail (balcony on the baked navmesh, in G_SIGNAL); smoke_ladders |
| `SignalZip` | anchor `[48.6, 9.0, 40.8]` (2 m over the balcony, a step outside its south rail), cable to its post at `[40.0, 0, 49.6]` (2.75 m), set down at `[40.629, 0, 48.956]` on the east apron between the pump stair and the crane office: 12.3 m, 27 degrees, speed cap 7.5 m/s, a 3.2 s ride | smoke_ladders: nothing in a hanging rider's way, the bar reached from the balcony, the ride, the landing on the navmesh, the rider stands free; test_map02_detail: the slope, the brake, the set-down, the spawns (none within 3.5 m) and the tide's live cable (4.7 m off) |

Choices:
- **Doors.** The line lands in the Pen Hall; the tower is reached only through the Pen Hall (its door costs 2500 and
  wants the power), so the line skips nothing and has no chain.
- **Rails closed.** As on Map 0's tower (T-268) the catwalks' and the balcony's rails stay closed; the climb carries
  a body over them.
- **Moved links.** `Ladder_CatwalkE` sat at z 60, the foot of the east stair: it is at z 72 now, where the ladder is
  drawn. `Ladder_CatwalkN` x 17 -> 15 and `Ladder_CatwalkW` z 60 -> 55.5: the tide's catwalk spawns stand at
  `(20, 4, 34)` and `(-19, 4, 60)` (the old west head itself); every head is 4 m or more from a spawn now.
- **One zip line, not two.** A line from a 4 m catwalk is 6.7 m long at 26 degrees: not worth a post. The balcony is
  the only 7 m floor with open hall below it.
- **The shelves** in the signal room moved west off the new door (`_dress_tower`).

Cost (scene census, after item 1 -> after item 2): meshes 1233 -> 1241 (+8), triangles 395,587 -> 403,555 (+7,968;
in shadow casters +6,468), lights unchanged (the post and arm lamps are emissive only), collision shapes 1288 ->
1295 (+7: the balcony floor, three rails, the post, the wall's new pieces). The navmesh changed only in the signal
tower (the door, the balcony) and under the new zip post.

Renders, looked at: `docs/captures/t273/05_ladder_n_night` .. `12_ladder_w_noon` (each ladder from its floor, the
balcony from the landing, down the line from the balcony, the door from inside the signal room).

## 3. The perk deal on Totenhafen

`perk_layout.json` has a `map02` row (the seven: Second Wind, Marathon Malt, Ironhide Stout, Trigger Tonic, Overclock
Cordial, Hawkeye Brandy, Ledger Lager) and the scene twelve `PerkSpot` nodes (gen_map02 `PERK_SPOTS`); `PerkLayout`
deals the seven onto them at every match start from the match seed, the spots left over show their filler crate. The
scene is saved with the seed-0 deal (Second Wind in the cannery by its pen passage, Ironhide in the signal room,
Overclock on pier 0, Ledger Lager and Hawkeye in the workshop, Trigger in the cannery, Marathon on the quay).

| Spot | Zone | Floor point, yaw | Flags | From |
|---|---|---|---|---|
| infirmary | B_CANNERY | `[-26, 0, 0.9]`, 180 | near | Second Wind's old place |
| cannery_passage | B_CANNERY | `[-5, 0, 29.3]`, 0 | near | Marathon's old place |
| cannery_north | B_CANNERY | `[-7, 0, 0.86]`, 180 | near, flush +1 | new: the north wall east of the conveyor's end |
| workshop_west | C_WORKSHOP | `[32.8, 0, 8]`, -90 | near | Ironhide's old place |
| workshop_north | C_WORKSHOP | `[40, 0, 0.8]`, 180 | near | Trigger's old place |
| workshop_lathe | C_WORKSHOP | `[57.5, 0, 0.86]`, 180 | near, flush +1 | new: the north wall over the lathe |
| signal_west | G_SIGNAL | `[42.9, 7, 36.7]`, -90 | | Overclock's old place |
| signal_east | G_SIGNAL | `[51.4, 7, 36.3]`, 90 | | Hawkeye's old place |
| crane_office | D_PENHALL | `[43.6, 0, 56.1]`, 90 | | Ledger Lager's old place (T-141) |
| north_apron | D_PENHALL | `[18, 0, 33.72]`, 180 | flush -1 | new: the bunker face under the north catwalk, 3 m east of its ladder |
| pier0_wall | D_PENHALL | `[-19.14, 0, 74]`, -90 | flush +1 | new: the hall's west wall on pier 0, under the west catwalk |
| quay_cannery_wall | A_QUAY | `[0.86, 0, 9]`, -90 | start, outdoor, flush -1 | new: the cannery's outside wall on the quay, north of its door |

The rules are perk_layout.json's (at most two machines in a zone; the quay takes only a weather-safe cabinet up to
2000, never Second Wind; Second Wind only one bought door from the quay, the cannery or the workshop). The new five
were found with `locker_spot.gd`'s wall scan (the wall behind a 1.8 m body, no collider in front, no navmesh under it,
6 m of room, nothing within 1.6 m) and get a 1.8 x 1.2 m footprint baked out of the navmesh (`NavBlock_PerkSpot_*`,
bake only); the seven old places keep the footprints their machines had. Every spot is 4 m or more from the ammo
boxes and the Crucible. test_map02_detail: the table and the scene agree, each spot stands in its zone with no
navmesh under it and its front on the navmesh, the scene holds the seed-0 deal, 300 seeds all deal the seven within
the rules and every spot is used by some seed. The minimap was rebaked (WSL): its POIs follow the seed-0 deal
(test_mapdata), the balcony is on the tower's floor image.

Known: the old seven places were sized for their own machine, not the deepest; the Ironhide barrel (1.2 m deep) on
`signal_east` or `crane_office` stands about 0.15 m into the wall behind it (drawing only; its collider overlaps the
wall). The bot planner's Totenhafen plan names perks by id and walks to wherever they stand.

## 4. Reactive props

Built at load under `Reactive` (gen_map02 `build_reactive`), Map 0's scripts: seven drips (the lower pens' slab x3,
U-1047's deckhead x2, the two pen passages); three doors left ajar (`SwingDoor`: the cannery infirmary's east and
south doors, the harbourmaster's hut's door; whoever comes through swings the leaf, it never collides); the infirmary
window's two curtains in the draught from `W_B_N` (they billow harder as its boards come off); glassware that breaks
when shot on the hut's desk and on the signal room's chart table (`ShatterSet`). Nothing collides, nothing changes the
navmesh, nothing casts a shadow. Paper (`PaperDecor`) left out: its kinds are Map 0's (the inn's December calendar,
the patrol's map, the cousins' drawings).
