extends GutTest
## Update 02 section 7 (T-052): Map 0's landscape and living world. The pure rules of MapAmbience (the war's
## intensity, the speed-of-sound delay, the round thresholds), the terrain's guarantees (it meets the slab at
## height 0, stays inside the camera's far plane, keeps the roads clear of trees), the frost and breath rules,
## and that every sound key and VO category the director uses exists.

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map00_ambience.json")


func test_config_loads() -> void:
	assert_false(cfg.is_empty(), "map00_ambience.json parses")
	for k: String in ["bombers", "fighters", "plane_down", "artillery", "flares", "crows", "dog", "bell", "frost"]:
		assert_true(cfg.has(k), "section %s" % k)


func test_intensity_escalates_with_rounds() -> void:
	assert_eq(MapAmbience.intensity_for(1, cfg), 0.0)
	assert_almost_eq(MapAmbience.intensity_for(15, cfg), 1.0, 0.001)
	assert_eq(MapAmbience.intensity_for(40, cfg), 1.0, "clamped")
	assert_lt(MapAmbience.intensity_for(5, cfg), MapAmbience.intensity_for(10, cfg))


func test_boom_is_delayed_by_distance() -> void:
	assert_almost_eq(MapAmbience.boom_delay(1.0, cfg), 2.9, 0.001, "about 2.9 s per km")
	assert_almost_eq(MapAmbience.boom_delay(3.0, cfg), 8.7, 0.001)
	assert_eq(MapAmbience.boom_delay(-1.0, cfg), 0.0)


func test_war_gets_closer_and_busier() -> void:
	var early: Vector2 = MapAmbience.artillery_km_range(cfg, 0.0)
	var late: Vector2 = MapAmbience.artillery_km_range(cfg, 1.0)
	assert_lt(late.x, early.x, "the nearest shells land closer late on")
	assert_lt(late.y, early.y)
	var a0: Vector2 = MapAmbience.interval_range(cfg["artillery"], 0.0)
	var a1: Vector2 = MapAmbience.interval_range(cfg["artillery"], 1.0)
	assert_lt(a1.y, a0.y, "shells come more often")
	var b: Vector2 = MapAmbience.interval_range(cfg["bombers"], 0.0)
	assert_between(b.x, 100.0, 140.0, "bombers roughly every 2-4 minutes")
	assert_between(b.y, 200.0, 260.0)


func test_round_thresholds() -> void:
	assert_true(MapAmbience.farm_lit_at(7, cfg))
	assert_false(MapAmbience.farm_lit_at(8, cfg), "the farmhouse window goes dark at round 8")
	assert_true(MapAmbience.dog_barks_at(9, cfg))
	assert_false(MapAmbience.dog_barks_at(10, cfg), "the dog stops at round 10")
	assert_false(MapAmbience.plane_down_allowed(5, false, cfg))
	assert_true(MapAmbience.plane_down_allowed(6, false, cfg), "a plane can go down from round 6")
	assert_false(MapAmbience.plane_down_allowed(9, true, cfg), "once per match")
	assert_eq(int(cfg["bell"]["tolls"]), 12, "midnight")


func test_hearth_out_rule() -> void:
	assert_false(MapAmbience.hearth_out(4.5, 4.5, cfg))
	assert_true(MapAmbience.hearth_out(0.5, 4.5, cfg), "the Cousins' embers (cousins.json fire_ember_energy 0.5) count as out")
	assert_false(MapAmbience.hearth_out(1.0, 0.0, cfg), "no base light, never out")


func test_frost_creeps_and_jumps_when_the_fire_dies() -> void:
	var f: Dictionary = cfg["frost"]
	assert_lt(FrostCreep.frost_at(1, f, false), FrostCreep.frost_at(8, f, false))
	assert_almost_eq(FrostCreep.frost_at(30, f, false), float(f["max"]), 0.001)
	assert_gt(FrostCreep.frost_at(3, f, true), FrostCreep.frost_at(3, f, false))
	assert_lte(FrostCreep.frost_at(30, f, true), 1.0)


func test_breath_only_in_the_cold() -> void:
	var warm: Array = ["TAPROOM", "UPSTAIRS"]
	assert_false(BreathFog.is_cold(&"TAPROOM", warm, false))
	assert_true(BreathFog.is_cold(&"STABLE", warm, false))
	assert_true(BreathFog.is_cold(&"YARD", warm, false))
	assert_true(BreathFog.is_cold(&"TAPROOM", warm, true), "everywhere once the hearth is out")


func test_terrain_meets_the_slab_and_stays_in_range() -> void:
	# along every slab edge the terrain starts at the slab's top (y = 0)
	for p: Vector2 in [Vector2(-45.5, 10), Vector2(70.5, 10), Vector2(10, -40.5), Vector2(10, 75.5)]:
		assert_almost_eq(LandscapeTerrain.height(p.x, p.y), 0.0, 0.25, "edge %s" % p)
	assert_lt(LandscapeTerrain.height(10, 10), 0.0, "under the slab the terrain hides")
	# the far ridges stay inside the camera's 400 m far plane from anywhere in the play space
	assert_lt(LandscapeTerrain.RIDGE_B.z + 31.0, 380.0)
	for b: float in [0.0, 90.0, 180.0, 215.0, 270.0]:
		assert_between(LandscapeTerrain.ridge_crest(1, b), 15.0, 110.0, "mountain crest on bearing %d" % b)
	assert_gt(LandscapeTerrain.ridge_crest(1, 215.0), LandscapeTerrain.ridge_crest(1, 80.0), "taller to the south-west")


func test_no_forest_on_roads_or_the_play_space() -> void:
	assert_eq(LandscapeTerrain.forest_density(-10.75, -150.0), 0.0, "the north road is clear")
	assert_eq(LandscapeTerrain.forest_density(12.0, 20.0), 0.0, "nothing in the play space")
	assert_eq(LandscapeTerrain.forest_density(LandscapeTerrain.BRIDGE.x, LandscapeTerrain.BRIDGE.y), 0.0, "the stream is clear")
	var near: Array[float] = []
	var tr: Dictionary = LandscapeTerrain.forest_transforms(9.0, 3)
	assert_gt((tr["mesh"] as Array).size() + (tr["cards"] as Array).size(), 100, "there is a forest")
	for xf: Transform3D in tr["mesh"]:
		near.append(LandscapeTerrain.slab_distance(xf.origin.x, xf.origin.z))
	assert_gt(near.min() if not near.is_empty() else 99.0, 27.0, "no tree within 28 m of the play space")


func test_bearings_round_trip() -> void:
	for b: float in [0.0, 45.0, 90.0, 200.0, 315.0]:
		var p: Vector3 = LandscapeTerrain.at_bearing(b, 100.0)
		assert_almost_eq(LandscapeTerrain.bearing(p.x, p.z), b, 0.01)
	assert_almost_eq(LandscapeTerrain.dir_of(90.0).x, 1.0, 0.001, "east is +X")
	assert_almost_eq(LandscapeTerrain.dir_of(0.0).z, -1.0, 0.001, "north is -Z")


func test_crow_perches_hang_on_the_wires() -> void:
	for p: Vector3 in CrowFlock.wire_perches(11, 5):
		assert_between(p.x, -31.0, 41.0)
		assert_between(p.y, 5.8, 6.7)
		assert_almost_eq(p.z, -15.5, 0.001)


func test_every_sound_key_exists() -> void:
	var bank: Dictionary = GLData.load_json(AudioDirector.BANK_PATH)
	var sounds: Dictionary = bank.get("sounds", {})
	var keys: Array[String] = []
	for sec: Variant in cfg.values():
		if sec is Dictionary:
			for k: String in (sec as Dictionary).keys():
				if k.ends_with("sound"):
					keys.append(str(sec[k]))
	assert_gt(keys.size(), 15)
	for k2: String in keys:
		assert_true(sounds.has(k2), "audio.json has %s" % k2)
		if sounds.has(k2):
			for f: Variant in (sounds[k2] as Dictionary).get("files", []):
				assert_true(ResourceLoader.exists(str(f)), "%s file %s" % [k2, f])


func test_vo_categories_have_lines_for_the_squad() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for cat: String in ["SKY_PLANE_DOWN", "WRECK_PILOT", "MIDNIGHT"]:
		for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
			assert_true(lines.has("%s_%s_01" % [spk, cat]), "%s has a %s line" % [spk, cat])
