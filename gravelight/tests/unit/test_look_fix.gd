extends GutTest
## UPDATE 12 (T-214): the blind review's look fixes. The LUT keeps only a strongly saturated red (blood, not a warm
## board) and greys the pink where a warm lamp meets the cold moon; the light rules can neutralise a violet fill and
## leave a violet pool, match by type / name / range / place, and scale a flicker lamp's base energy; a zone with
## boxes thins the inn's haze; the grime layer has a strength and a size per class and per map; the special material
## rules (an emission scale, an accent cap, lit smoke); shader params and node tweaks from the grade.


func before_each() -> void:
	LookGrade.reset_cache()
	LookMaterials.reset_cache()
	GLSettings.compat_override = -1


func after_each() -> void:
	LookGrade.reset_cache()
	LookMaterials.reset_cache()


# ================================================================== the LUT

func test_red_keep_is_blood_not_a_warm_board() -> void:
	var spec: Dictionary = LookGrade.lut_spec(LookGrade.data("map01_kaltenbrunn"))
	var blood: Color = LookGrade.lut_color(Color(0.55, 0.06, 0.06), spec)
	var board: Color = LookGrade.lut_color(Color(0.42, 0.2, 0.12), spec)   # a warm-lit tan board in the filmic toe
	assert_gt(blood.s, 0.6, "blood red keeps its colour: s %.2f" % blood.s)
	assert_lt(board.s, 0.3, "a warm board does not: s %.2f" % board.s)


func test_pink_cast_is_suppressed() -> void:
	for id: String in ["map00_crossroads", "map01_kaltenbrunn"]:
		var spec: Dictionary = LookGrade.lut_spec(LookGrade.data(id))
		assert_true(spec.has("suppress"), "%s greys the pink band" % id)
		var pink: Color = LookGrade.lut_color(Color(0.62, 0.45, 0.55), spec)   # orange lamp + blue moon on a pale wall
		var salmon: Color = LookGrade.lut_color(Color(0.62, 0.45, 0.4), spec)
		assert_lt(pink.s, 0.1, "%s: the pink halo goes grey (s %.2f)" % [id, pink.s])
		assert_lt(salmon.s, 0.18, "%s: the salmon plaster goes grey (s %.2f)" % [id, salmon.s])
	var spec0: Dictionary = LookGrade.lut_spec(LookGrade.data("map00_crossroads"))
	var lavender: Color = LookGrade.lut_color(Color(0.62, 0.6, 0.78), spec0)   # moonlit snow with a warm tint in it
	assert_lt(lavender.s, 0.18, "Map 0's snow is not lavender (s %.2f)" % lavender.s)
	var vio: Color = LookGrade.lut_color(Color.html("#8c33ff"), spec0)
	assert_gt(vio.s, 0.6, "Nachtglas violet is untouched")


func test_mondlicht_keeps_only_strong_violet() -> void:
	var spec: Dictionary = LookGrade.lut_spec(LookGrade.data("map04d_mondlicht"))
	assert_gt(LookGrade.lut_color(Color.html("#8c33ff"), spec).s, 0.6, "the tubes stay violet")
	assert_lt(LookGrade.lut_color(Color(0.35, 0.33, 0.5), spec).s, 0.05, "a violet-washed wall goes grey")
	assert_lt(LookGrade.lut_color(Color(0.3, 0.32, 0.6), spec).s, 0.05, "a blue wall goes grey")


# ================================================================== the light rules

func test_light_rules_neutralise_fill_and_leave_a_pool() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "Lamp_B_Strip_0"
	fill.light_color = Color(0.62, 0.28, 1.0)
	fill.light_energy = 2.4
	fill.omni_range = 15.0
	root.add_child(fill)
	var near: OmniLight3D = OmniLight3D.new()
	near.light_color = Color(0.62, 0.28, 1.0)
	near.omni_range = 8.0
	root.add_child(near)
	var block: Dictionary = {"rules": [
		{"hue": 265, "width": 30, "min_sat": 0.25, "min_range": 12, "sat_scale": 0.1, "pool": {"range": 3.0, "energy": 1.0}},
		{"hue": 265, "width": 30, "min_sat": 0.25, "range_scale": 0.5}]}
	assert_eq(LookGrade.apply_lights(root, block), 2)
	assert_lt(fill.light_color.s, 0.1, "the long fill goes neutral")
	assert_almost_eq(near.omni_range, 4.0, 0.0001, "the short one keeps its colour and reaches half as far")
	assert_gt(near.light_color.s, 0.6)
	await get_tree().process_frame
	var pool: OmniLight3D = fill.get_node_or_null("LookPool") as OmniLight3D
	assert_not_null(pool, "a violet pool stays under the tube")
	if pool != null:
		assert_gt(pool.light_color.s, 0.6)
		assert_almost_eq(pool.omni_range, 3.0, 0.0001)


func test_light_rules_match_type_name_box_and_scale_base_energy() -> void:
	var root: Node3D = Node3D.new()
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	root.add_child(moon)
	var lamp: FlickerLight = FlickerLight.new()
	lamp.name = "Lamp_17"
	lamp.light_color = Color(1.0, 0.75, 0.5)
	lamp.base_energy = 2.0
	lamp.position = Vector3(-12, 2.6, 35.5)
	root.add_child(lamp)
	var outside: OmniLight3D = OmniLight3D.new()
	outside.name = "Lamp_5"
	outside.position = Vector3(7, 1.6, 10)
	root.add_child(outside)
	var block: Dictionary = {"practical_scale": 1.0, "rules": [
		{"type": "directional", "sat_scale": 0.5},
		{"name": ["Lamp_"], "box": [-16, -1, 31, 41, 6, 48], "energy_scale": 2.0}]}
	LookGrade.apply_lights(root, block)
	assert_almost_eq(moon.light_color.s, Color(0.55, 0.65, 1.0).s * 0.5, 0.01, "the moon less blue (a named rule only)")
	assert_almost_eq(lamp.base_energy, 4.0, 0.0001, "a flicker lamp's base energy scales (the script drives it)")
	assert_almost_eq(outside.light_energy, 1.0, 0.0001, "outside the box: untouched")
	root.free()


# ================================================================== zones

func test_zone_boxes_follow_the_camera() -> void:
	var env: Environment = Environment.new()
	env.fog_density = 0.022
	env.volumetric_fog_density = 0.03
	var zones: Dictionary = LookGrade.data("map00_crossroads").get("zones", {})
	assert_true(LookZones.has_boxes(zones), "Map 0's inn is a zone")
	var lz: LookZones = LookZones.new()
	lz.setup(env, zones, null)
	assert_eq(lz.zone_at(Vector3(15, 1.6, 9)), "inn", "the taproom is inside")
	assert_eq(lz.zone_at(Vector3(40, 1.6, -10)), "", "the road is not")
	var t: Dictionary = lz.target("inn", lz.read_env())
	assert_lt(float(t["fog_density"]), 0.01, "the haze thins inside")
	assert_lt(float(t["vol_density"]), 0.015)
	assert_almost_eq(float(lz.target("", lz.read_env())["fog_density"]), 0.022, 0.0001, "outside keeps the map's")
	lz.free()
	assert_false(LookZones.has_boxes(LookGrade.data("map01_kaltenbrunn").get("zones", {})), "Kaltenbrunn blends its own")


# ================================================================== materials

func test_grime_strength_and_size_per_class_and_map() -> void:
	var pale: StandardMaterial3D = StandardMaterial3D.new()
	pale.albedo_color = Color(0.75, 0.68, 0.55)
	pale.roughness = 0.8
	LookMaterials.fix(pale)
	assert_true(pale.detail_enabled)
	assert_not_null(pale.detail_mask, "a pale flat board takes a light grime")
	assert_lt(pale.detail_mask.get_image().get_pixel(0, 0).r, 0.4)
	var tex: StandardMaterial3D = StandardMaterial3D.new()
	tex.albedo_texture = PlaceholderTexture2D.new()
	tex.roughness = 0.8
	tex.resource_name = "concrete_wall"
	LookMaterials.fix(tex)
	assert_eq(tex.detail_uv_layer, BaseMaterial3D.DETAIL_UV_2, "a textured wall wears on its own triplanar, not its UVs")
	assert_true(tex.uv2_triplanar)
	var r: Dictionary = LookMaterials.rules_for("map04d_mondlicht")
	assert_lt(float((r["detail"] as Dictionary)["strength"]), 0.2, "Mondlicht's clean concrete: barely any grime")
	assert_eq(LookMaterials.rules_for("no_such_map"), LookMaterials.rules(), "no block: the shared rules")


func test_special_rules_emission_cap_and_smoke() -> void:
	var strip: StandardMaterial3D = StandardMaterial3D.new()
	strip.emission_enabled = true
	strip.emission = Color.html("#8c33ff")
	strip.emission_energy_multiplier = 1.2
	LookMaterials.fix_special(strip, null, LookMaterials.rules_for("map04b_kranich"))
	assert_almost_eq(strip.emission_energy_multiplier, 0.6, 0.0001, "der Kranich's violet strips glow half")
	var cable: StandardMaterial3D = StandardMaterial3D.new()
	cable.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cable.albedo_color = Color.html("#8c40ff")
	var node: Node3D = Node3D.new()
	node.name = "Pylon_A"
	LookMaterials.fix_special(cable, node, LookMaterials.rules_for("map01_kaltenbrunn"))
	assert_lte(cable.albedo_color.s, 0.5 + 0.001, "the pylon cable capped back")
	node.free()
	var smoke: StandardMaterial3D = StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.vertex_color_use_as_albedo = true
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	LookMaterials.fix_special(smoke, null)
	assert_ne(smoke.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "smoke takes the scene's light")
	assert_eq(LookMaterials.fix_special(smoke, null).size(), 0, "once")


func test_shader_params_and_nodes_from_the_grade() -> void:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CloudDeck"
	mi.mesh = QuadMesh.new()
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://gravelight/world/shaders/cloud_deck.gdshader") as Shader
	mi.material_override = sm
	root.add_child(mi)
	var list: Array = LookGrade.data("map04a_thalbach").get("shader_params", [])
	assert_eq(LookGrade.apply_shader_params(root, list), 1)
	var lit: Color = sm.get_shader_parameter("lit_color")
	assert_lt(lit.v, 0.5, "the searchlight spots on the clouds no longer burn white")
	var ridge: Node3D = Node3D.new()
	ridge.name = "RidgeBand1"
	var land: Node3D = Node3D.new()
	land.name = "Landscape"
	root.add_child(land)
	land.add_child(ridge)
	assert_eq(LookGrade.apply_nodes(root, LookGrade.data("map01_kaltenbrunn").get("nodes", [])), 1)
	assert_lt(ridge.scale.y, 0.8, "Kaltenbrunn's far ridge no longer hangs over the yard like a cloud")
	root.free()
