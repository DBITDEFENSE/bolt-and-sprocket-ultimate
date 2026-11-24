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
