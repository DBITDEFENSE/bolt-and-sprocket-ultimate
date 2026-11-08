extends GutTest
## UPDATE 12 section 6 (T-212): the sky matches the Soviet-front story. Soviet Pe-2 streams, a Soviet Il-2 chased by a
## German night fighter, red stars on the Soviet planes only, and the round-6 plane that falls is the Soviet one.


func test_models_build_and_are_small() -> void:
	for key: String in ["pe2", "il2", "nightfighter"]:
		var m: ArrayMesh = PlaneModels.by_name(key)
		assert_not_null(m, key)
		var tris: int = 0
		for s: int in m.get_surface_count():
			tris += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		assert_lt(tris, 1200, "%s stays a far-away silhouette" % key)
	assert_eq(PlaneModels.by_name("pe2").get_surface_count(), 3, "Soviet planes carry the star surface")
	assert_eq(PlaneModels.by_name("nightfighter").get_surface_count(), 2, "German planes carry no marking surface")
	assert_same(PlaneModels.by_name("unknown"), PlaneModels.bomber(), "fallback is the old bomber")


func test_fighter_pair_is_soviet_chased_by_german() -> void:
	assert_same(SkyFlight._fighter_mesh("il2_vs_night", 0), PlaneModels.il2(), "the chased plane (the one that falls) is Soviet")
	assert_same(SkyFlight._fighter_mesh("il2_vs_night", 1), PlaneModels.nightfighter(), "the chaser is a German night fighter")
	assert_same(SkyFlight._fighter_mesh("mosquito", 1), PlaneModels.mosquito(), "Totenhafen's low pass is untouched")


func test_data_names_the_new_models() -> void:
	for f: String in ["map00", "map01"]:
		var cfg: Dictionary = GLData.load_json("res://data/gravelight/%s_ambience.json" % f)
		assert_eq((cfg["bombers"] as Dictionary).get("model"), "pe2", "%s bombers" % f)
		assert_eq((cfg["fighters"] as Dictionary).get("model"), "il2_vs_night", "%s fighters" % f)
	var k: Dictionary = GLData.load_json("res://data/gravelight/map01_ambience.json")
	assert_eq((k["dogfight"] as Dictionary).get("model"), "il2_vs_night", "Kaltenbrunn dogfight")
