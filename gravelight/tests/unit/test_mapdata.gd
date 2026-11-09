extends GutTest
## Update 04 section 1 (DECISIONS T-065): every playable level has map data whose images exist and whose POIs match
## the scene (the bake check), the playable list comes from the campaign chain and the star map, and MapData's
## geometry helpers (world <-> uv, floors by height, zones) hold on the real maps.


func before_each() -> void:
	MapData.clear_cache()


func test_bake_check_passes_for_every_playable_level() -> void:
	var problems: PackedStringArray = MapCheck.check_all(true)
	assert_eq(problems.size(), 0, "map data up to date: %s" % "; ".join(problems))


func test_playable_levels_come_from_campaign_and_star_map() -> void:
	var ids: Array[StringName] = MapCatalog.ids()
	var camp: Dictionary = GLData.load_json("res://data/gravelight/campaign.json")
	for id: Variant in camp["chain"]:
		assert_has(ids, StringName(str(id)), "campaign map %s is a playable level" % id)
	var planets: Dictionary = GLData.load_json("res://data/bs/planets.json")
	for row: Variant in planets["campaign"]:
		var r: Dictionary = row as Dictionary
		if str(r["scene"]) != "":
			assert_has(ids, StringName(str(r["level_id"])), "built planet %s is a playable level" % r["level_id"])
		else:
			assert_does_not_have(ids, StringName(str(r["level_id"])), "unbuilt planet %s is not required yet" % r["level_id"])


func test_a_level_without_map_data_fails_the_check() -> void:
	var fake: Dictionary = {"map_id": &"map99_nowhere", "game": "gravelight", "scene": "res://nowhere.tscn", "display_name": "Nowhere"}
	var problems: PackedStringArray = MapCheck.check_level(fake, false)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "no map data")


func test_stale_pois_change_the_signature() -> void:
	var md: MapData = MapData.for_map(&"map00_crossroads")
	var pois: Array = md.pois.duplicate(true)
	assert_eq(MapScan.poi_signature(pois), md.poi_signature, "the stored signature is the POIs' own")
	(pois[0] as Dictionary)["price"] = int(pois[0]["price"]) + 250
	assert_ne(MapScan.poi_signature(pois), md.poi_signature, "a price change is caught")
	var moved: Array = md.pois.duplicate(true)
	(moved[1] as Dictionary)["pos"] = (moved[1]["pos"] as Vector3) + Vector3(1, 0, 0)
	assert_ne(MapScan.poi_signature(moved), md.poi_signature, "a moved buyable is caught")
	assert_string_contains(MapCheck.poi_diff(md.pois, moved), "~")


func test_every_level_has_floors_images_and_pois() -> void:
	for id: StringName in MapCatalog.ids():
		var md: MapData = MapData.for_map(id)
		assert_not_null(md, "%s has map data" % id)
		if md == null:
			continue
		assert_gt(md.floors.size(), 0, "%s has floors" % id)
		assert_gt(md.pois.size(), 0, "%s has POIs" % id)
		for i: int in md.floors.size():
			assert_not_null(md.floor_texture(i), "%s floor %d image loads" % [id, i])


func test_gravelight_floors_match_the_brief() -> void:
	var inn: MapData = MapData.for_map(&"map00_crossroads")
	assert_eq(inn.floors.map(func(f: Dictionary) -> String: return str(f["id"])), ["cellar", "ground", "upstairs", "attic"])   # (the attic since T-224)
	var kb: MapData = MapData.for_map(&"map01_kaltenbrunn")
	assert_eq(kb.floors.map(func(f: Dictionary) -> String: return str(f["id"])), ["vault", "level_2", "surface", "admin"])


func test_world_uv_round_trip() -> void:
	for id: StringName in MapCatalog.ids():
		var md: MapData = MapData.for_map(id)
		var r: Rect2 = md.world_rect
		for k: int in 20:
			var p: Vector3 = Vector3(r.position.x + r.size.x * randf(), 0.0, r.position.y + r.size.y * randf())
			for fi: int in md.floors.size():
				var uv: Vector2 = md.world_to_uv(p, fi)
				assert_between(uv.x, 0.0, 1.0)
				assert_between(uv.y, 0.0, 1.0)
				var back: Vector3 = md.uv_to_world(uv, fi)
				assert_almost_eq(Vector2(back.x, back.z), Vector2(p.x, p.z), Vector2(0.001, 0.001), "%s round trip" % id)
				assert_almost_eq(back.y, float(md.floors[fi]["base_y"]), 0.001)
		assert_eq(md.world_to_uv(Vector3(r.position.x, 0, r.position.y)), Vector2.ZERO, "%s: the rect's corner is uv 0,0" % id)
		assert_almost_eq(md.world_to_pixel(Vector3(r.end.x, 0, r.end.y)), Vector2(md.image_size), Vector2(0.01, 0.01))


func test_floor_for_y_and_floor_at() -> void:
	var inn: MapData = MapData.for_map(&"map00_crossroads")
	assert_eq(inn.floor_for_y(-3.2), 0, "the cellar")
	assert_eq(inn.floor_for_y(0.0), 1, "the ground floor")
	assert_eq(inn.floor_for_y(3.8), 2, "upstairs")
	assert_eq(inn.floor_for_y(-50.0), 0, "below everything: the bottom floor")
	assert_eq(inn.floor_for_y(7.1), 3, "the attic (T-224)")
	assert_eq(inn.floor_for_y(99.0), 3, "above everything: the top floor")
	assert_eq(inn.floor_at(Vector3(12, 3.9, 4)), 2, "the guest rooms")
	assert_eq(inn.floor_at(Vector3(18, 7.2, 5)), 3, "the attic")
	assert_eq(inn.floor_at(Vector3(40, 3.9, 40)), 1, "up on something outside the inn: still the ground floor")
	var kb: MapData = MapData.for_map(&"map01_kaltenbrunn")
	assert_eq(kb.floor_at(Vector3(47, -18, 110)), 0, "the core vault")
	assert_eq(kb.floor_at(Vector3(12, -12, 74)), 1, "the Salt Chapel, level -2")
	assert_eq(kb.floor_at(Vector3(20, 0, 20)), 2, "the Minehead yard")
	assert_eq(kb.floor_at(Vector3(-8, 3.8, 20)), 3, "the admin upper floor")
	assert_eq(kb.floor_at(Vector3(20, 4.0, 20)), 2, "high in the yard is still the surface")


func test_zone_at() -> void:
	var inn: MapData = MapData.for_map(&"map00_crossroads")
	assert_eq(inn.zone_at(Vector3(12, 0.1, 8)), "TAPROOM")
	assert_eq(inn.zone_at(Vector3(12, -3.0, 8)), "OLD_CELLAR", "the old cellar under the taproom")
	assert_eq(inn.zone_at(Vector3(30, -3.0, 25)), "CELLAR")
	assert_eq(inn.zone_label_at(Vector3(30, -3.0, 25)), "Helvetia Cellar")
	assert_eq(inn.zone_at(Vector3(500, 0, 500)), "", "outside every zone")
	var kb: MapData = MapData.for_map(&"map01_kaltenbrunn")
	assert_eq(kb.zone_at(Vector3(12, -12, 74)), "F_CHAPEL")
	assert_eq(kb.zone_label_at(Vector3(12, -12, 74)), "Salt Chapel")
	var sh: MapData = MapData.for_map(&"scrapheap")
	assert_eq(sh.zone_at(Vector3(-2, 0, 8)), "junction_yard", "B&S zones come from the level data")


func test_pois_carry_what_the_runtime_needs() -> void:
	var inn: MapData = MapData.for_map(&"map00_crossroads")
	var types: Dictionary = {}
	for p: Dictionary in inn.pois:
		types[str(p["type"])] = true
		assert_true(str(p["id"]) != "" and str(p["node_path"]) != "", "%s has an id and a node path" % p["id"])
		assert_between(int(p["floor"]), 0, inn.floors.size() - 1)
	for t: String in ["door", "perk", "wall_buy", "ammo_box", "crate_spot", "crucible", "power_switch"]:
		assert_true(types.has(t), "the Inn has a %s POI" % t)
	var perk: Dictionary = inn.pois_of_type("perk")[0]
	assert_eq(int(perk["floor"]), 0, "the perk machines are in the cellar")
	assert_gt(int(perk["price"]), 0)
	var kb: MapData = MapData.for_map(&"map01_kaltenbrunn")
	assert_gt(kb.pois_of_type("trap").size(), 0, "Kaltenbrunn's traps")
	assert_gt(kb.pois_of_type("workbench").size(), 0, "Kaltenbrunn's workbench")
	assert_gt(kb.pois_of_type("lift").size(), 0, "Kaltenbrunn's lift")
	var lift_conn: bool = false
	for c: Dictionary in kb.connectors:
		lift_conn = lift_conn or (str(c["kind"]) == "lift" and int(c["floor_a"]) == 1 and int(c["floor_b"]) == 2)
	assert_true(lift_conn, "the lift joins level -2 and the surface")


func test_json_round_trip() -> void:
	var md: MapData = MapData.for_map(&"map01_kaltenbrunn")
	var again: MapData = MapData.from_dict(JSON.parse_string(JSON.stringify(md.to_dict())) as Dictionary)
	assert_eq(again.floors.size(), md.floors.size())
	assert_eq(again.pois.size(), md.pois.size())
	assert_eq(again.poi_signature, md.poi_signature)
	assert_eq(MapScan.poi_signature(again.pois), md.poi_signature)
	assert_eq(again.zone_at(Vector3(12, -12, 74)), "F_CHAPEL")
	assert_eq(again.world_rect, md.world_rect)
