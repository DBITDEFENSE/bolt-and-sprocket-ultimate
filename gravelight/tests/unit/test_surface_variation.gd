extends GutTest
## UPDATE 19 (T-252): the surface pass. The shared surface shader's variation uniforms (macro drift, the second
## sample, snow sparkle), the terrain shader that mirrors them, MaterialLibrary.apply_runtime (a baked scene's
## library materials brought up to materials.json when the map loads), the sky dome's contract with MapAmbience and
## Landscape, and NightSkyDome (a map without a Landscape gets the dome from its grade).


func before_each() -> void:
	MaterialLibrary.reset()


func after_all() -> void:
	MaterialLibrary.reset()


func _uniforms(path: String) -> Array:
	var sh: Shader = load(path) as Shader
	var names: Array = []
	if sh != null:
		for u: Dictionary in sh.get_shader_uniform_list():
			names.append(str(u["name"]))
	return names


func _stale(lib_name: String, albedo_key: String = "") -> ShaderMaterial:
	# what a scene baked before U19 holds: the shared shader, the lib_<key> name, none of the new uniforms
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = MaterialLibrary.shader()
	m.resource_name = lib_name
	if albedo_key != "":
		m.set_shader_parameter("albedo_tex", MaterialLibrary.texture(albedo_key, "albedo"))
	return m


func test_surface_shader_has_the_variation_uniforms() -> void:
	var names: Array = _uniforms("res://assets/materials/shaders/surface_pbr.gdshader")
	for want: String in ["macro_var", "macro_scale", "detile", "sparkle", "grime", "frost", "albedo_tex", "triplanar"]:
		assert_true(names.has(want), "surface_pbr exposes %s (a parse error empties the list)" % want)


func test_terrain_shader_mirrors_the_slab() -> void:
	var names: Array = _uniforms("res://gravelight/world/landscape/shaders/near_land.gdshader")
	for want: String in ["macro_var", "macro_scale", "detile", "sparkle", "albedo_tex", "mud_tex", "snow_tint", "mud_tint"]:
		assert_true(names.has(want), "near_land exposes %s" % want)
	var near: ShaderMaterial = ShaderMaterial.new()
	near.shader = load("res://gravelight/world/landscape/shaders/near_land.gdshader") as Shader
	Landscape._near_land_textures(near)
	var e: Dictionary = MaterialLibrary.entry(MaterialLibrary.generator_key("snow"))
	assert_almost_eq(float(near.get_shader_parameter("detile")), float(e["detile"]), 0.001, "the terrain takes the slab snow's detile")
	assert_almost_eq(float(near.get_shader_parameter("sparkle")), float(e["sparkle"]), 0.001, "and its sparkle")
	assert_almost_eq(float(near.get_shader_parameter("uv_scale")), 1.0 / float(e["tile_m"]), 0.001, "and its tile")


func test_build_writes_the_variation_values() -> void:
	var snow: ShaderMaterial = MaterialLibrary.get_mat("snow") as ShaderMaterial
	assert_not_null(snow)
	assert_gt(float(snow.get_shader_parameter("detile")), 0.3, "the snow blends its second sample")
	assert_gt(float(snow.get_shader_parameter("sparkle")), 0.0, "the snow sparkles")
	for structured: String in ["fieldstone", "brick_cellar", "cellar_stone", "cellar_floor", "floorboards", "planks", "shingles", "fl_brick", "m1_brick"]:
		assert_false(MaterialLibrary.entry(structured).has("detile"), "%s is coursed / boarded: no second, larger sample" % structured)


func test_apply_runtime_gives_a_baked_material_the_variation() -> void:
	var m: ShaderMaterial = _stale("lib_snow", "snow")
	assert_null(m.get_shader_parameter("detile"), "a scene baked before U19 has no detile")
	assert_eq(MaterialLibrary.apply_runtime(m), 1, "variation only: snow is not a live key")
	assert_almost_eq(float(m.get_shader_parameter("detile")), float(MaterialLibrary.entry("snow")["detile"]), 0.001)
	assert_almost_eq(float(m.get_shader_parameter("sparkle")), float(MaterialLibrary.entry("snow")["sparkle"]), 0.001)


func test_apply_runtime_rewrites_a_live_key_whole() -> void:
	var m: ShaderMaterial = _stale("lib_snow_trodden", "snow")   # the wrong texture stands in for the old set
	assert_eq(MaterialLibrary.apply_runtime(m), 2, "snow_trodden is live: textures and every parameter")
	var t: Texture2D = m.get_shader_parameter("albedo_tex") as Texture2D
	assert_eq(t.resource_path, MaterialLibrary.texture_path("snow_trodden", "albedo"), "the entry's own albedo")
	assert_almost_eq((m.get_shader_parameter("uv_scale") as Vector3).x, 1.0 / float(MaterialLibrary.entry("snow_trodden")["tile_m"]), 0.001)
	assert_eq(MaterialLibrary.apply_runtime(m), 0, "once: the material is current now")


func test_apply_runtime_leaves_the_rest_alone() -> void:
	assert_eq(MaterialLibrary.apply_runtime(MaterialLibrary.get_mat("plaster")), 0, "a material build() made in this session is current")
	assert_eq(MaterialLibrary.apply_runtime(StandardMaterial3D.new()), 0, "not the shared shader")
	assert_eq(MaterialLibrary.apply_runtime(null), 0)
	assert_eq(MaterialLibrary.apply_runtime(_stale("some_other_name")), 0, "no lib_ name, no texture the data knows")
	var moon: ShaderMaterial = _stale("m4d_regolith")
	moon.set_shader_parameter("albedo_tex", load("res://assets/third_party/polyhaven/moon-dusted-01/textures/moon_dusted_01_albedo.png"))
	assert_eq(MaterialLibrary.apply_runtime(moon), 1, "a renamed variant is found by its albedo file (by_texture)")
	assert_gt(float(moon.get_shader_parameter("detile")), 0.0)


func test_apply_library_walks_a_tree() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	for nm: String in ["lib_snow", "lib_frozen_mud"]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = _stale(nm, "snow")
		root.add_child(mi)
	var plain: MeshInstance3D = MeshInstance3D.new()
	plain.mesh = BoxMesh.new()
	plain.material_override = StandardMaterial3D.new()
	root.add_child(plain)
	assert_eq(LookMaterials.apply_library(root), [1, 1], "one variation, one live, the plain one untouched")


func test_live_and_kaltenbrunn_keys_resolve() -> void:
	for key: String in ["snow_trodden", "frozen_mud", "plaster", "fl_yard"]:
		assert_true(bool(MaterialLibrary.entry(key).get("live", false)), "%s is live" % key)
		assert_not_null(MaterialLibrary.get_mat(key), "%s builds" % key)
	for mats_key: String in ["stucco", "brick", "concrete", "concrete_floor", "rock_dark", "rock_floor"]:
		var m: Material = Mats.get_mat(mats_key)
		assert_true(m is ShaderMaterial and String(m.resource_name).begins_with("lib_m1_"), "Mats %s is a library set now (%s)" % [mats_key, m.resource_name if m != null else "null"])
	assert_false(MaterialLibrary.texture_path("snow_trodden", "albedo").contains("snow-015"), "the trodden snow is no longer the grass set")


func test_sky_dome_keeps_its_contract() -> void:
	var names: Array = _uniforms("res://gravelight/world/landscape/shaders/sky_dome.gdshader")
	for want: String in ["zenith", "horizon", "cloud_tint", "moon_dir", "moon_color", "town_dir", "town_strength", "cloud_cover", "exposure",
			"flashes", "flash_cols", "beams", "moon_size", "moon_gain", "star_gain", "high_veil", "deck_light"]:
		assert_true(names.has(want), "sky_dome exposes %s (Landscape / MapAmbience / the grades write it)" % want)


func test_night_sky_dome_from_a_grade_block() -> void:
	assert_eq(NightSkyDome.value_of("#ff0000"), Color(1, 0, 0))
	assert_eq(NightSkyDome.value_of([1, 2, 3]), Vector3(1, 2, 3))
	assert_eq(NightSkyDome.value_of([0.5, 0.25]), Vector2(0.5, 0.25))
	assert_eq(NightSkyDome.value_of(0.7), 0.7)
	var map: Node3D = Node3D.new()
	add_child_autofree(map)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-40, 30, 0)
	map.add_child(moon)
	assert_null(NightSkyDome.add_to(map, {}), "no block, no dome")
	var d: NightSkyDome = NightSkyDome.add_to(map, {"cloud_cover": 0.8, "zenith": [0.01, 0.02, 0.03], "moon_gain": 1.2})
	assert_not_null(d)
	assert_same(NightSkyDome.add_to(map, {"cloud_cover": 0.1}), d, "one dome per map")
	var sm: ShaderMaterial = d.material_override as ShaderMaterial
	assert_almost_eq(float(sm.get_shader_parameter("cloud_cover")), 0.8, 0.001)
	assert_eq(sm.get_shader_parameter("zenith"), Vector3(0.01, 0.02, 0.03))
	assert_true((sm.get_shader_parameter("moon_dir") as Vector3).is_equal_approx(moon.transform.basis.z.normalized()), "the moon stands behind the map's own light")
	assert_eq(d.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var grade: Dictionary = LookGrade.load_file("res://data/look/map02_totenhafen.json")
	assert_true(grade.has("sky_dome"), "Totenhafen's grade asks for the dome")
	for k: Variant in (grade["sky_dome"] as Dictionary).keys():
		if not str(k).begins_with("_") and str(k) != "moon_light":
			assert_true(_uniforms(NightSkyDome.SHADER).has(str(k)), "sky_dome block key %s is a uniform" % k)
