extends GutTest
## UPDATE 10 section 5 (T-161): Kaltenbrunn's living world. The data file validates (and Map 0's still does, under
## the same rules), every sound key it names resolves, the U10 round rules hold, the terrain meets the Ground slabs
## and keeps the mine's underground roofs covered, the ridges and the rail terrace behave, and the zone beds exist.

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map01_ambience.json")


func test_file_validates_and_map0_still_does() -> void:
	assert_false(cfg.is_empty(), "map01_ambience.json parses")
	assert_eq(MapAmbience.validate(cfg), PackedStringArray(), "map01 validates")
	assert_eq(MapAmbience.validate(GLData.load_json("res://data/gravelight/map00_ambience.json")), PackedStringArray(), "map00 validates unchanged")
	assert_true(MapAmbience.validate({"dogfight": 3}).size() > 0, "a block that is not a dictionary is caught")
	assert_true(MapAmbience.validate({"bombers": {"interval": [9, 3]}}).size() > 0, "an unordered range is caught")


func test_every_block_the_order_asks_for_is_there() -> void:
	for k: String in ["bombers", "fighters", "plane_down", "dogfight", "avalanche", "cable_car", "siren", "snow_harder", "dust_fall", "lift_chains", "gallery_drips", "salt_glint", "artillery"]:
		assert_true(cfg.has(k), "section %s" % k)
	assert_true((cfg["plane_down"] as Dictionary).get("ridge", false), "the plane goes down onto the ridge")
	assert_false(cfg.has("crows") or cfg.has("frost") or cfg.has("bell") or cfg.has("farm_light"), "Map 0's inn pieces stay off")


func _collect_sounds(d: Variant, out: Array) -> void:
	if d is Dictionary:
		for k: String in (d as Dictionary).keys():
			var v: Variant = d[k]
			if k.ends_with("sound") and v is String and v != "":
				out.append(v)
			else:
				_collect_sounds(v, out)


func test_every_sound_key_exists_in_the_bank() -> void:
	var keys: Array = []
	_collect_sounds(cfg, keys)
	assert_gt(keys.size(), 10, "the file names its sounds")
	var bank: Dictionary = (GLData.load_json("res://data/gravelight/audio.json").get("sounds", {}) as Dictionary)
	for key: Variant in keys:
		assert_true(bank.has(key), "audio.json has %s" % key)
		for f: String in (bank.get(key, {}).get("files", []) as Array):
			assert_true(ResourceLoader.exists(f), "%s exists" % f)


func test_round_rules() -> void:
	assert_false(MapAmbience.dogfight_due_at(6, cfg))
	assert_true(MapAmbience.dogfight_due_at(7, cfg), "the dogfight is round 7")
	assert_false(MapAmbience.dogfight_due_at(8, cfg))
	assert_true(MapAmbience.siren_due_at(10, cfg), "the siren is round 10")
	assert_false(MapAmbience.siren_due_at(9, cfg) or MapAmbience.siren_due_at(11, cfg))
	assert_false(MapAmbience.snow_harder_at(19, cfg))
	assert_true(MapAmbience.snow_harder_at(20, cfg) and MapAmbience.snow_harder_at(35, cfg), "harder snow from round 20 on")
	var m0: Dictionary = GLData.load_json("res://data/gravelight/map00_ambience.json")
	assert_false(MapAmbience.dogfight_due_at(7, m0) or MapAmbience.siren_due_at(10, m0) or MapAmbience.snow_harder_at(20, m0), "Map 0 has none of them")
	assert_false(MapAmbience.dust_falls_for(0.1, m0), "no dust on Map 0")


func test_dust_falls_only_for_near_shells() -> void:
	assert_true(MapAmbience.dust_falls_for(1.0, cfg))
	assert_true(MapAmbience.dust_falls_for(3.6, cfg))
	assert_false(MapAmbience.dust_falls_for(6.0, cfg), "a far shell moves nothing underground")


func test_dust_points_sit_in_the_underground_zones() -> void:
	var pts: Array = (cfg["dust_fall"] as Dictionary)["points"]
	assert_gte(pts.size(), 12)
	for p: Array in pts:
		assert_gt(float(p[2]), 45.0, "south of the surface slabs (a gallery)")
		assert_lt(float(p[1]), 3.0)


func test_terrain_meets_the_slabs_and_covers_the_roofs() -> void:
	assert_almost_eq(KaltenTerrain.height(20.0, 10.0), -0.05, 0.001, "inside the shelf")
	assert_almost_eq(KaltenTerrain.height(-40.0, 10.0), -0.05, 0.001, "at the shelf's west edge")
	# the chapel roof tops out at y 2.3 under z 60..90: the hillside must cover it
	for z: float in [60.0, 62.0, 70.0, 88.0]:
		for x: float in [-14.0, 10.0, 38.0]:
			assert_gt(KaltenTerrain.height(x, z), 2.5, "hill over the chapel at (%d, %d)" % [x, z])
	# the valley falls away to the north
	assert_lt(KaltenTerrain.height(20.0, -120.0), -20.0, "the valley is deep")


func test_ridges_and_forest() -> void:
	for b: float in [0.0, 45.0, 90.0, 180.0, 270.0]:
		assert_gt(KaltenTerrain.ridge_crest(1, b), KaltenTerrain.ridge_crest(0, b) * 0.9, "the Alpine wall stands behind the foothills at %d" % b)
		assert_lt(KaltenTerrain.ridge_crest(1, b), 330.0, "...and stays under the far plane's silhouette budget")
	assert_eq(KaltenTerrain.forest_density(20.0, 10.0), 0.0, "no trees in the yard")
	assert_eq(KaltenTerrain.forest_density(60.0, 30.0), 0.0, "none near the shelf")
	var tr: Dictionary = KaltenTerrain.forest_transforms(8.0, 17)
	assert_gt((tr["mesh"] as Array).size() + (tr["cards"] as Array).size(), 500, "a forest")
	assert_lt((tr["cards"] as Array).size() + (tr["mesh"] as Array).size(), 6000, "within the triangle budget")


func test_rail_terrace_is_cut_and_the_line_leaves_the_rail_yard() -> void:
	var a: Vector3 = KaltenTerrain.RAIL[0]
	assert_almost_eq(a.x, 48.0, 0.5)
	assert_lt(a.y, 14.5, "it starts at the rail yard's north wall")
	var info: Vector2 = KaltenTerrain.rail_info(70.0, -52.0)
	assert_almost_eq(info.x, 0.0, 0.01)
	assert_almost_eq(KaltenTerrain.height(70.0, -52.0), -4.0 - 0.35, 0.6, "the bed is cut to its height")


func test_cable_car_geometry() -> void:
	var a: Vector3 = Vector3(0, 20, 0)
	var b: Vector3 = Vector3(100, 40, 0)
	assert_eq(KaltenTerrain.cable_point(a, b, 0.0, 6.0), a)
	assert_eq(KaltenTerrain.cable_point(a, b, 1.0, 6.0), b)
	assert_almost_eq(KaltenTerrain.cable_point(a, b, 0.5, 6.0).y, 30.0 - 6.0, 0.001, "it sags at mid-span")


func test_zone_beds_exist() -> void:
	var zc: Dictionary = ZoneAmbience.load_config(ZoneAmbience.config_path(&"map01_kaltenbrunn"))
	assert_false(zc.is_empty(), "data/gravelight/ambience/map01.json is found for map01_kaltenbrunn")
	assert_eq(ZoneAmbience.validate(zc), PackedStringArray())
	for z: String in ["A_MINEHEAD", "B_RAILYARD", "C_ADMIN", "D_BARRACKS", "E_LIFT", "M_STAIRS", "F_CHAPEL", "G_GENERATOR", "H_LAB", "I_CORE"]:
		assert_true((zc["zones"] as Dictionary).has(z), "a bed for %s" % z)
		assert_true(ZoneAmbience.resolvable(str(zc["zones"][z]["bed"])), "%s's bed resolves" % z)
