extends GutTest
## UPDATE_05 section 1 (T-088): the CC0 material library. Every key in data/gravelight/materials.json resolves to
## texture files that exist and import, the shared surface shader parses headless (its uniforms are there), each key
## builds one cached ShaderMaterial with the wear parameters, and the generator flag hands the library to Mats only
## for the keys materials.json enables.


func before_each() -> void:
	MaterialLibrary.reset()


func after_all() -> void:
	MaterialLibrary.reset()


func test_data_file_is_well_formed() -> void:
	var d: Dictionary = MaterialLibrary.data()
	assert_true(d.has("library"), "materials.json has a library")
	assert_true(d.has("generator"), "materials.json has the generator block")
	var lib: Dictionary = d["library"]
	assert_gt(lib.size(), 10, "a real library, not a stub")
	for key: String in lib:
		var e: Dictionary = lib[key]
		assert_true(e.has("set") and e.has("id"), "%s names its set and id" % key)
		assert_gt(float(e.get("tile_m", 0.0)), 0.0, "%s has a tile size" % key)
		var r: Array = e.get("rough", [0.0, 1.0])
		assert_true(float(r[0]) <= float(r[1]), "%s roughness range ordered" % key)
		assert_eq(key, key.to_lower().replace(" ", "_"), "%s is a plain snake-case noun" % key)
	for required: String in ["floorboards", "planks", "plaster", "fieldstone", "shingles", "iron", "canvas", "wool", "leather", "snow", "ice", "frozen_mud"]:
		assert_true(lib.has(required), "the work order's family %s is in the library" % required)


func test_every_key_resolves_to_files_that_exist() -> void:
	for key: String in MaterialLibrary.keys():
		for map: String in ["albedo", "normal", "orm"]:
			var p: String = MaterialLibrary.texture_path(key, map)
			assert_true(FileAccess.file_exists(p), "%s %s: %s is on disk" % [key, map, p])
			assert_true(ResourceLoader.exists(p), "%s %s is imported (run tools/apply_import_presets.sh)" % [key, map])
		var dir: String = MaterialLibrary.texture_path(key, "albedo").get_base_dir().get_base_dir()
		assert_true(FileAccess.file_exists(dir.path_join("LICENSE.txt")), "%s has LICENSE.txt" % key)
		assert_true(FileAccess.file_exists(dir.path_join("SOURCE.txt")), "%s has SOURCE.txt" % key)


func test_source_txt_is_cc0_in_devins_format() -> void:
	for key: String in MaterialLibrary.keys():
		var dir: String = MaterialLibrary.texture_path(key, "albedo").get_base_dir().get_base_dir()
		var txt: String = FileAccess.get_file_as_string(dir.path_join("SOURCE.txt"))
		for field: String in ["Title:", "Authors:", "Source:", "License:", "Credit line:", "Format:", "Downloaded:", "Files used:"]:
			assert_true(txt.contains(field), "%s SOURCE.txt has '%s'" % [key, field])
		assert_true(txt.contains("CC0"), "%s is CC0" % key)
		assert_false(txt.to_lower().contains("noncommercial") or txt.contains("CC-NC"), "%s is not NC" % key)


func test_shader_parses_headless_with_the_wear_parameters() -> void:
	var sh: Shader = MaterialLibrary.shader()
	assert_not_null(sh, "surface_pbr.gdshader loads")
	var names: Array = []
	for u: Dictionary in sh.get_shader_uniform_list():
		names.append(str(u["name"]))
	for want: String in ["albedo_tex", "normal_tex", "orm_tex", "uv_scale", "triplanar", "grime", "wetness", "frost", "frost_height", "albedo_tint", "rough_min", "rough_max"]:
		assert_true(names.has(want), "shader exposes %s (a parse error empties the uniform list)" % want)


func test_every_key_builds_one_cached_material() -> void:
	for key: String in MaterialLibrary.keys():
		var m: Material = MaterialLibrary.get_mat(key)
		assert_not_null(m, "%s builds" % key)
		if m == null:
			continue
		assert_true(m is ShaderMaterial, "%s is a ShaderMaterial on the shared shader" % key)
		assert_same(m, MaterialLibrary.get_mat(key), "%s is cached" % key)
		var sm: ShaderMaterial = m
		assert_not_null(sm.get_shader_parameter("albedo_tex"), "%s albedo set" % key)
		assert_not_null(sm.get_shader_parameter("normal_tex"), "%s normal set" % key)
		assert_not_null(sm.get_shader_parameter("orm_tex"), "%s orm set" % key)
		var e: Dictionary = MaterialLibrary.entry(key)
		var scale: Vector3 = sm.get_shader_parameter("uv_scale")
		assert_almost_eq(scale.x, 1.0 / float(e["tile_m"]), 0.001, "%s uv_scale is tiles per metre" % key)
		var g: float = float(sm.get_shader_parameter("grime"))
		assert_true(g >= 0.0 and g <= 1.0, "%s grime in 0..1" % key)


func test_build_with_overrides_is_a_fresh_variant() -> void:
	var shared: Material = MaterialLibrary.get_mat("floorboards")
	var wet: ShaderMaterial = MaterialLibrary.build("floorboards", {"wetness": 0.9})
	assert_not_null(wet)
	assert_ne(wet, shared, "an override never touches the shared material")
	assert_almost_eq(float(wet.get_shader_parameter("wetness")), 0.9, 0.001)
	assert_almost_eq(float((shared as ShaderMaterial).get_shader_parameter("wetness")), float(MaterialLibrary.entry("floorboards").get("wetness", 0.0)), 0.001)
	assert_null(MaterialLibrary.build("no_such_key"), "an unknown key builds nothing")
	assert_null(MaterialLibrary.get_mat("no_such_key"))


func test_generator_mapping_is_consistent() -> void:
	var g: Dictionary = MaterialLibrary.data()["generator"]
	var keys: Dictionary = g["keys"]
	for mats_key: String in keys:
		assert_true(MaterialLibrary.has_key(str(keys[mats_key])), "generator key %s -> %s exists in the library" % [mats_key, keys[mats_key]])
	for en: String in g["enabled"]:
		assert_true(keys.has(en), "enabled key %s is mapped" % en)
	assert_true((g["enabled"] as Array).has("floorboards") and (g["enabled"] as Array).has("plaster"), "T-088's proof keys are on")


func test_flag_hands_the_library_to_mats_only_for_enabled_keys() -> void:
	Mats._cache.clear()
	var floor_m: Material = Mats.get_mat("floorboards")
	assert_true(floor_m is ShaderMaterial, "floorboards comes from the library when enabled")
	assert_same(floor_m, MaterialLibrary.get_mat("floorboards"))
	assert_same(floor_m, MaterialLibrary.for_generator("floorboards"))
	var planks: Material = Mats.get_mat("planks")
	assert_true(planks is StandardMaterial3D, "planks stays procedural until it is enabled")
	assert_null(MaterialLibrary.for_generator("planks"))
	assert_null(MaterialLibrary.for_generator("nachtglas"), "an unmapped key is never swapped")
	# the master switch
	MaterialLibrary.data()["generator"]["use_library"] = false
	Mats._cache.clear()
	assert_null(MaterialLibrary.for_generator("floorboards"), "use_library false turns the library off")
	assert_true(Mats.get_mat("floorboards") is StandardMaterial3D, "and Mats falls back to the procedural boards")
	MaterialLibrary.reset()
	Mats._cache.clear()
	assert_true(Mats.get_mat("floorboards") is ShaderMaterial, "back on after a reset")
	Mats._cache.clear()
