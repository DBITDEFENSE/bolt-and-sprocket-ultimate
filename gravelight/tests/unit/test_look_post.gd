extends GutTest
## UPDATE 12 section 2 (T-208): the post stack (LookPost), the grade's `lights` and `sky` blocks, and the material
## pass + audit rules (LookMaterials). The post's uniforms come from every map's `post` block, each graphics switch
## turns its piece off, the web profile drops the edge taps, the archive-reel grade stands aside for section 3, a map
## with no grade keeps the legacy PostFx look, the post sits under the HUD; the night lights scale once and the
## crater's violet lamps shrink; the material rules flag and fix glossy, plastic, saturated and unworn materials and
## leave glass, emissive and accent materials alone.

const MAPS: PackedStringArray = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach",
	"map04b_kranich", "map04c_groomlake", "map04d_mondlicht", "menu"]
const ALL_ON: Dictionary = {"grain": true, "vignette": true, "edge_soft": true, "ca": true}


func before_each() -> void:
	LookGrade.reset_cache()
	LookMaterials.reset_cache()
	GLSettings.compat_override = -1


func after_each() -> void:
	GLSettings.compat_override = -1
	LookGrade.reset_cache()
	LookMaterials.reset_cache()


# ================================================================== the post stack

func test_every_map_post_params_drive_the_shader() -> void:
	for m: String in MAPS:
		var u: Dictionary = LookPost.compute(m, "", ALL_ON)
		var p: Dictionary = LookGrade.post_params(m)
		assert_true(bool(u["draws"]), "%s: the post draws" % m)
		assert_eq(float(u["legacy"]), 0.0, "%s: the grade's post, not the legacy look" % m)
		for k: String in ["grain", "vignette", "edge_soft", "ca"]:
			assert_almost_eq(float(u[k]), float(p[k]), 0.0001, "%s: %s from data/look" % [m, k])
		assert_between(float(u["vignette"]), 0.3, 0.55, "%s: vignette in the bible's range" % m)
		assert_lt(float(u["ca"]), 0.0025, "%s: CA mild (edge only)" % m)
	assert_gt(float(LookPost.compute("menu", "", ALL_ON)["flicker"]), 0.0, "the menu flickers like a projector")
	assert_eq(float(LookPost.compute("map00_crossroads", "", ALL_ON)["flicker"]), 0.0, "a map does not flicker")


func test_each_setting_turns_its_piece_off() -> void:
	for k: String in ALL_ON.keys():
		var t: Dictionary = ALL_ON.duplicate()
		t[k] = false
		var u: Dictionary = LookPost.compute("map02_totenhafen", "", t)
		assert_eq(float(u[k]), 0.0, "%s off" % k)
		for other: String in ALL_ON.keys():
			if other != k:
				assert_gt(float(u[other]), 0.0, "%s off leaves %s on" % [k, other])
	var none: Dictionary = {"grain": false, "vignette": false, "edge_soft": false, "ca": false}
	assert_false(bool(LookPost.compute("map02_totenhafen", "", none)["draws"]), "every piece off: the pass is skipped")
	for k: String in LookPost.TOGGLES.keys():
		assert_true(GLSettings.values.has(LookPost.TOGGLES[k]), "GLSettings has the %s switch" % k)


func test_web_preset_drops_the_edge_taps() -> void:
	GLSettings.compat_override = 1
	LookGrade.reset_cache()
	for m: String in MAPS:
		var u: Dictionary = LookPost.compute(m, "", ALL_ON)
		assert_eq(float(u["edge_soft"]), 0.0, "%s web: no lens softness" % m)
		assert_eq(float(u["ca"]), 0.0, "%s web: no chromatic aberration" % m)
		assert_gt(float(u["grain"]), 0.0, "%s web: the grain stays (one tap)" % m)
		assert_gt(float(u["vignette"]), 0.0, "%s web: the vignette stays" % m)


func test_reel_grade_and_no_grade() -> void:
	var reel: Dictionary = LookPost.compute("cinema_reel", "", ALL_ON)
	assert_false(bool(reel["draws"]), "the archive reels are section 3's treatment: the post stands aside")
	var legacy: Dictionary = LookPost.compute("no_such_map_xyz", "", ALL_ON)
	assert_true(bool(legacy["draws"]), "a map with no grade keeps the old PostFx look")
	assert_eq(float(legacy["legacy"]), 1.0)
	assert_almost_eq(float(legacy["vignette"]), 0.42, 0.0001)
	assert_eq(float(legacy["grain"]), 0.0, "the legacy grain is GLSettings' own overlay")


func test_post_node_sits_under_the_hud_and_owns_the_grain() -> void:
	var host: Node3D = Node3D.new()
	host.set("name", "Host")
	add_child_autofree(host)
	var lp: LookPost = LookPost.add_to(host, "map00_crossroads")
	await wait_process_frames(1)
	assert_lt(lp.layer, 10, "under the HUD (layer 10)")
	assert_true(lp.visible, "drawing")
	assert_true(lp.is_in_group(LookPost.GRAIN_GROUP), "the grade's grain: GLSettings hides its full-screen grain")
	assert_eq(lp.get_child(0).get_class(), "ColorRect")
	lp.set_grade("cinema_reel")
	assert_false(lp.visible, "the reel grade: hidden")
	assert_false(lp.is_in_group(LookPost.GRAIN_GROUP))
	assert_true(ResourceLoader.exists(LookPost.SHADER_PATH))
	assert_true(load("res://gravelight/ui/postfx.gd").new() is LookPost, "every map's PostFx is the post stack")


# ================================================================== lights and sky

func test_lights_block_scales_once_and_shrinks_violet() -> void:
	var root: Node3D = Node3D.new()
	var warm: OmniLight3D = OmniLight3D.new()
	warm.light_color = Color(1.0, 0.66, 0.36)
	warm.light_energy = 2.0
	warm.set_meta("energy", 2.0)
	root.add_child(warm)
	var violet: OmniLight3D = OmniLight3D.new()
	violet.light_color = Color(0.62, 0.28, 1.0)
	violet.light_energy = 3.0
	violet.omni_range = 20.0
	root.add_child(violet)
	var block: Dictionary = {"practical_scale": 1.25, "rules": [{"hue": 268, "width": 30, "min_sat": 0.4, "range_scale": 0.5, "energy_scale": 0.8}]}
	assert_eq(LookGrade.apply_lights(root, block), 2)
	assert_almost_eq(warm.light_energy, 2.5, 0.0001, "a practical is stronger")
	assert_almost_eq(float(warm.get_meta("energy")), 2.5, 0.0001, "and so is the base energy a script keeps")
	assert_almost_eq(violet.omni_range, 10.0, 0.0001, "the crater's violet reaches half as far")
	assert_almost_eq(violet.light_energy, 2.4, 0.0001, "and is not a practical")
	root.free()
	var map: Node3D = Node3D.new()
	map.set_script(load("res://gravelight/maps/map_root.gd"))
	map.set("map_id", &"map00_crossroads")
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_energy = 1.0
	map.add_child(lamp)
	LookGrade.attach_scene(map)
	var once: float = lamp.light_energy
	LookGrade.attach_scene(map)
	assert_almost_eq(lamp.light_energy, once, 0.0001, "the lights block applies once per map")
	assert_gt(once, 1.0, "Map 0's practicals are stronger (darker nights)")
	map.free()


func test_groom_lake_is_dust_not_lavender() -> void:
	var d: Dictionary = LookGrade.resolved("map04c_groomlake")
	for k: String in ["zenith", "upper", "band", "belt", "ground"]:
		var c: Color = LookGrade.color(d["sky"][k])
		assert_false(c.s > 0.12 and c.h > 0.6 and c.h < 0.85, "Groom Lake sky %s is not violet / blue (%s)" % [k, c.to_html(false)])
	var amb: Color = LookGrade.color(d["ambient"]["color"])
	assert_lt(amb.b, amb.r, "the ambient is dust brown, not the dawn blue")
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://gravelight/world/map04/shaders/desert_sky.gdshader") as Shader
	var e: Environment = Environment.new()
	e.sky = Sky.new()
	e.sky.sky_material = sm
	LookGrade.apply_dict(e, {"sky": {"belt": "#5a4e42"}})
	assert_almost_eq((sm.get_shader_parameter("belt") as Color).r, Color.html("#5a4e42").r, 0.001, "the sky block writes the shader")
	var nights: Dictionary = {"map00_crossroads": 0.7, "map02_totenhafen": 0.85, "map04a_thalbach": 0.85}
	for m: String in nights.keys():
		var r: Dictionary = LookGrade.resolved(m)
		assert_lt(float(r["ambient"]["energy_scale"]), float(nights[m]), "%s: a darker night than T-207's" % m)
		assert_gt(float(r["lights"]["practical_scale"]), 1.0, "%s: stronger practicals" % m)


# ================================================================== the material pass

func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func test_material_rules_flag_the_outliers() -> void:
	var r: Dictionary = LookMaterials.rules()
	assert_false(r.is_empty(), "data/look/_materials.json loads")
	var plastic: StandardMaterial3D = _mat(Color(0.1, 0.4, 0.9), 0.2)
	var ev: Dictionary = LookMaterials.evaluate(plastic)
	for i: String in ["rough_low", "clean_plastic", "albedo_sat", "no_wear"]:
		assert_has(ev["issues"], i, "a glossy saturated flat colour: %s" % i)
	var good: StandardMaterial3D = _mat(Color(0.4, 0.38, 0.35), 0.8)
	good.detail_enabled = true
	assert_eq((LookMaterials.evaluate(good)["issues"] as Array).size(), 0, "a rough grey worn material is clean")
	var metal: StandardMaterial3D = _mat(Color(0.3, 0.3, 0.3), 0.4, 1.0)
	assert_does_not_have(LookMaterials.evaluate(metal)["issues"], "rough_low", "metal's floor is 0.35")
	var glass: StandardMaterial3D = _mat(Color(0.6, 0.7, 0.8), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	assert_eq(LookMaterials.exempt_reason(glass), "transparent")
	var lamp: StandardMaterial3D = _mat(Color(1, 0.6, 0.3), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(1, 0.6, 0.3)
	assert_eq(LookMaterials.exempt_reason(lamp), "emissive")
	var blood: StandardMaterial3D = _mat(Color(0.56, 0.08, 0.08), 0.6)
	blood.resource_name = "blood_pool"
	assert_does_not_have(LookMaterials.evaluate(blood)["issues"], "albedo_sat", "blood red is an accent")


func test_material_fix_brings_it_inside_once() -> void:
	var plastic: StandardMaterial3D = _mat(Color(0.1, 0.4, 0.9), 0.2)
	var changed: Array = LookMaterials.fix(plastic)
	assert_has(changed, "rough")
	assert_has(changed, "albedo")
	assert_has(changed, "wear")
	assert_gt(plastic.roughness, 0.5, "past the plastic line")
	assert_lt(plastic.albedo_color.s, 0.3 + 0.001, "desaturated to the palette")
	assert_true(plastic.detail_enabled, "the shared grime layer")
	assert_eq(plastic.detail_blend_mode, BaseMaterial3D.BLEND_MODE_MUL)
	assert_true(plastic.uv1_triplanar, "an untextured material wears in world space")
	assert_eq((LookMaterials.evaluate(plastic)["issues"] as Array).size(), 0, "clean after the pass")
	var r0: float = plastic.roughness
	assert_eq(LookMaterials.fix(plastic).size(), 0, "a material is fixed once")
	assert_eq(plastic.roughness, r0)
	var snow: StandardMaterial3D = _mat(Color(0.84, 0.86, 0.9), 0.7)
	snow.resource_name = "snow_drift"
	LookMaterials.fix(snow)
	assert_false(snow.detail_enabled, "snow takes frost, not dirt")


func test_texture_fix_desaturates_and_caps_the_multiply() -> void:
	var wood: Color = Color(0.42, 0.24, 0.1)
	var fx: Dictionary = LookMaterials.tex_fix_for(wood)
	var out: Color = LookMaterials.desat(wood, float(fx["sat"]))
	assert_lt(out.s, 0.3, "the desaturated average is inside the palette (the surface shader's albedo_saturation)")
	assert_almost_eq(out.h, wood.h, 0.02, "and keeps its hue")
	assert_almost_eq(float(fx["val"]), 1.0, 0.0001, "a dark wood keeps its value")
	var k: Color = LookMaterials.base_tint(wood, fx)
	for ch: float in [k.r, k.g, k.b]:
		assert_lte(ch, 1.6 + 0.0001, "a StandardMaterial3D's multiply is capped (no amplified texture noise)")
	var bright: Dictionary = LookMaterials.tex_fix_for(Color(0.97, 0.96, 0.95))
	assert_lt(float(bright["val"]), 0.95, "too bright: the value comes down")
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(LookMaterials.SURFACE_SHADER) as Shader
	sm.set_shader_parameter("albedo_tint", Color(0.42, 0.24, 0.1))
	sm.set_shader_parameter("albedo_saturation", float(fx["sat"]))
	assert_lt(LookMaterials.effective_albedo(sm).s, 0.3, "the surface shader's saturation counts in the audit")


func test_audit_tool_collects_skips_and_counts() -> void:
	var root: Node3D = Node3D.new()
	var a: MeshInstance3D = MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	a.material_override = _mat(Color(0.1, 0.4, 0.9), 0.2)
	root.add_child(a)
	var wreck: Node3D = Node3D.new()
	wreck.name = "Wreck"
	root.add_child(wreck)
	var b: MeshInstance3D = MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	b.material_override = _mat(Color(0.9, 0.1, 0.1), 0.1)
	wreck.add_child(b)
	var entries: Array[Dictionary] = LookMaterials.collect(root)
	assert_eq(entries.size(), 2)
	var skipped: int = 0
	for e: Dictionary in entries:
		if String(e["skip"]) != "":
			skipped += 1
	assert_eq(skipped, 1, "section 5's wreck is skipped")
	var res: Dictionary = LookMaterials.apply_tree(root)
	assert_eq(int(res["changed"]), 1)
	assert_eq(int(res["skipped"]), 1)
	assert_almost_eq((b.material_override as StandardMaterial3D).roughness, 0.1, 0.0001, "the wreck's material untouched")
	root.free()
	var audit: Script = load("res://gravelight/tools_src/material_audit.gd")
	assert_not_null(audit, "the audit tool loads")
	assert_true(audit.can_instantiate())
	assert_true(ResourceLoader.exists("res://gravelight/tools_src/material_audit.tscn"))
	assert_true(ResourceLoader.exists(str((LookMaterials.rules()["detail"] as Dictionary)["texture"])), "the grime map exists")
