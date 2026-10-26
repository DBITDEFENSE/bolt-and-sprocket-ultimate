# Map data and the minimap (Update 04 sections 1-2, DECISIONS T-065)

## Map data (section 1)

Every playable level has `data/maps/<map_id>/mapdata.json` plus one PNG per floor (`floor_<n>_<id>.png`).
"Playable" comes from data the project already keeps (`MapCatalog`): the GRAVELIGHT campaign chain
(`data/gravelight/campaign.json`) and every B&S planet with a built scene (`data/bs/planets.json`). A new map in either
list is required automatically: the bake check fails until it is baked.

- **Bake**: `tools/bake_minimap.sh [all | id,id]` (off-screen window, the render needs the GPU; ~3 s per map, retried if
  a run exits early). Dev console: `bake_minimap <id|all>` (background process), then `minimap reload`.
- **Inputs**: `data/maps/bake_config.json`: per map floors (`y_min`/`y_max` feet band, `base_y`, `cut` = slice
  height, `zones` = XZ limits, `mask_zones` = image-only limits), zone names, px per metre, the three styles
  (ink / holo / blueprint; Helvetia Works already has its blueprint row). A map with no row gets one floor and its
  game's style.
- **How**: `MapScan` reads the level (GRAVELIGHT: the packed scene instantiated but never added to the tree; B&S: the
  level json the planet is built from) for POIs, zone boxes, stairs/ramps (StaticBody names), lifts and ladders
  (`climb_links`). The bake copies every visible mesh into a private SubViewport with `map_encode.gdshader`
  (height / class / albedo luminance), renders each floor top-down with an orthographic camera at the floor's cut
  (wall colliders the cut passes through get a flat "section cap", so walls always read solid), then
  `map_style.gdshader` turns that into the floor image.
- **Check**: `tools/check_mapdata.sh` (`MapCheck`), and the GUT test `test_mapdata.gd` runs it on every map:
  missing data, missing / wrong-size images, floors out of date with the config, POIs out of date with the scene.

## Runtime (section 2) - APIs for the other sections

| API | What |
|---|---|
| `MapData.for_map(id)` | cached; `floors`, `floor_for_y(y)`, `floor_at(pos)` (uses the XZ limits; use this for players), `world_to_uv(pos, floor)`, `uv_to_world(uv, floor)`, `world_to_pixel`, `floor_texture(i)`, `floor_name(i)`, `pois` ({id, type, pos, floor, label, price, node_path, key, data}), `poi(id)`, `pois_of_type(t)`, `zones`, `zone_at(pos)` (id), `zone_name(id)`, `zone_label_at(pos)`, `connectors` |
| `MapState.current()` | the match's state (added by `MapRoot` / `BSLevel`): `discovered`, `is_discovered(id)`, `discover(id)`, `visible_pois(floor, fog_on)`, `poi_state(poi)` ({open, locked, powered, ready, price, label, here}), `poi_node(poi)`, `is_revealed(pos, floor)`, `fog_textures[floor]`, `live_icons()`, `objectives()`, `add_objective_provider(callable)`, `reveal_zombies(origin, r, s)`, `local_body()`, `local_floor()` |
| marks | `MapState.add_marker({pos, kind, label, color, owner, target, poi_id}) -> id`, `update_marker(id, changes)`, `remove_marker(id)`, `clear_markers(owner)`, `markers()`, signal `markers_changed`; `Minimap.add_marker(...)` forwards. The minimap / map draw them (pin + letter by kind: go, defend, danger, regroup, note, buy, collect). Limits are the caller's job. |
| suppressor | `MapState.suppressed_check = func(pid, weapon_id) -> bool`, or give `WeaponInstance` an `is_suppressed()` method / `suppressed` property / meta. |
| spoilers | objectives read `GLSettings.values["objective_spoilers"] (section 4's key)` = `hidden` / `hints` / `full` (`MapState.SPOILER_KEY`). |
| `MapCanvas` | the drawing Control for any map view: `set_state(ms)`, `floor_index`, `center` (world XZ), `zoom` (px/m), `heading`, `show_*` flags, `show_zone_labels`, `fit_floor()`, `world_to_canvas` / `canvas_to_world`, `icon_at(pt)` (hover: {kind, poi/live/marker/objective/connector, state}), `record_hits`. |

The minimap (`ui/map/minimap.gd`) is a `MapCanvas` in a circular / rounded-square clip with the bezel; settings are in
`GLSettings.values` (`classic_hud`, `minimap_*`) and the Gameplay tab's "Minimap" rows; the zoom key is
`minimap_zoom` (N / D-pad left). Cost: 50-150 us per frame measured (`minimap perf`), under the 300 us budget; in the
busy perf_marks scene (24 zombie dots, 4 squad icons) it measured 300-360 us before the T-070 pass and ~190-280 us after
(the bezel is retained: its ticks / letters move instead of redrawing; zombie dots take a lean path; only rim-pinned marks
are placed per frame). See docs/gravelight/PERFORMANCE.md.

## T-096 (Update 05 section 7): the bezel art, open ground, the pause map's first fit

The GRAVELIGHT bezel is drawn (no texture): a bevelled brass band with screws, N/E/S/W discs, intercardinal
rose points on the tick ring, a faint etched rose and a glass glint over the map (`ui.json "minimap"`
`compass_rose_alpha`, `glint_alpha`, `ring_px`), the zone stamp and floor name typed under it in the kit's fonts.
On open ground (a zone whose bounding box covers more than `outdoor_zone_frac` of the map's rect: Map 0's Grounds,
104 x 118 m) the view steps out by `outdoor_zoom_step` zoom levels (`Minimap.zoom_level_effective`), so the field
reads at a useful scale while rooms keep the chosen level. The pause MAP tab's first view fits the built zones
(`PauseMapView.built_rect`, `ui.json "pause_map"`), with the whole rect as the zoom-out floor and the last zoom
kept for the match; `MapCanvas.fit_rect(rect, margin)` is the primitive. See docs/gravelight/UI_KIT.md.
