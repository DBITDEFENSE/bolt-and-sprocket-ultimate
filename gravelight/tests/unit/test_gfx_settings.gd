extends GutTest
## T-133: the graphics settings. Presets write their individual settings (and the menu reads "Custom" when one
## differs), each AA mode sets the viewport, the effect gates follow the individual settings, brightness scales the
## map's own grade, Ultra is the top, and smooth motion is on by default.

var _saved: Dictionary


func before_each() -> void:
	_saved = GLSettings.values.duplicate(true)


func after_each() -> void:
	GLSettings.values = _saved


func test_every_preset_has_every_setting_and_ultra_is_the_top() -> void:
	var keys: Array = (GLSettings.PRESETS["high"] as Dictionary).keys()
	for pn: String in GLSettings.PRESET_ORDER:
		for k: Variant in keys:
			assert_true((GLSettings.PRESETS[pn] as Dictionary).has(k), "%s has %s" % [pn, k])
		assert_true(GLSettings.AA_MODES.has(str(GLSettings.PRESETS[pn]["gfx_aa"])))
		assert_true(GLSettings.UPSCALERS.has(str(GLSettings.PRESETS[pn]["gfx_upscaler"])))
	var u: Dictionary = GLSettings.PRESETS["ultra"]
	assert_eq(str(u["gfx_shadows"]), "ultra")
	assert_eq(float(u["gfx_scale"]), 1.0)
	assert_lt(float(GLSettings.LOD_Q[str(u["gfx_lod"])]), float(GLSettings.LOD_Q["high"]), "ultra keeps more mesh detail")


func test_a_preset_writes_its_settings_and_a_change_makes_it_custom() -> void:
	for k: Variant in (GLSettings.PRESETS["high"] as Dictionary).keys():
		GLSettings.values.erase(str(k))
	for k2: Variant in (GLSettings.PRESETS["ultra"] as Dictionary).keys():
		GLSettings.values[str(k2)] = GLSettings.PRESETS["ultra"][k2]
	assert_eq(GLSettings.matching_preset(GLSettings.values), "ultra")
	GLSettings.values["gfx_aa"] = "fxaa"
	assert_eq(GLSettings.matching_preset(GLSettings.values), "custom")


func test_every_aa_mode_sets_the_viewport() -> void:
	var vp: SubViewport = SubViewport.new()
	add_child_autofree(vp)
	GLSettings.apply_aa(vp, "msaa4_taa")
	assert_eq(vp.msaa_3d, Viewport.MSAA_4X)
	assert_true(vp.use_taa)
	GLSettings.apply_aa(vp, "fxaa")
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)
	assert_false(vp.use_taa)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	GLSettings.apply_aa(vp, "smaa")
	assert_ne(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "SMAA (or FXAA where the engine has no SMAA)")
	GLSettings.apply_aa(vp, "off")
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)


func test_effects_follow_the_individual_settings_and_brightness_scales_the_grade() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.ssao_enabled = true
	we.environment.sdfgi_enabled = true
	we.environment.adjustment_enabled = true
	we.environment.adjustment_brightness = 0.9
	GLSettings.values["gfx_ao"] = "off"
	GLSettings.values["gfx_gi"] = true
	GLSettings.values["brightness"] = 1.2
	GLSettings._apply_env(we)
	assert_false(we.environment.ssao_enabled, "AO off")
	assert_true(we.environment.sdfgi_enabled, "GI on: the map wanted it")
	assert_almost_eq(we.environment.adjustment_brightness, 0.9 * 1.2, 0.001, "brightness scales the map's grade")
	GLSettings.values["gfx_ao"] = "high"
	GLSettings.values["brightness"] = 1.0
	GLSettings._apply_env(we)
	assert_true(we.environment.ssao_enabled)
	assert_almost_eq(we.environment.adjustment_brightness, 0.9, 0.001, "and back")
	we.free()


func test_smooth_motion_is_on_by_default() -> void:
	var fresh: GDScript = load("res://gravelight/autoload/settings.gd") as GDScript
	var inst: Node = fresh.new()
	assert_true(bool((inst.get("values") as Dictionary).get("smooth_motion", false)))
	inst.free()
