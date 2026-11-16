extends GutTest
## T-258: only the lamps nearest the camera draw shadows, within the Shadows setting's budget of shadow views.


func test_pick_nearest_within_budget() -> void:
	var e: Array = [
		{"d": 10.0, "cost": 2, "on": false},
		{"d": 0.0, "cost": 2, "on": false},
		{"d": 5.0, "cost": 2, "on": false},
	]
	assert_eq(ShadowBudget.pick(e, 4, 50.0), [false, true, true] as Array[bool], "the two nearest fit 4 views")


func test_pick_respects_distance() -> void:
	var e: Array = [{"d": 25.0, "cost": 1, "on": false}, {"d": 3.0, "cost": 1, "on": false}]
	assert_eq(ShadowBudget.pick(e, 10, 20.0), [false, true] as Array[bool], "a lamp past the distance loses its shadow")


func test_pick_skips_what_does_not_fit_but_fills_with_cheaper() -> void:
	var e: Array = [{"d": 0.0, "cost": 6, "on": false}, {"d": 1.0, "cost": 6, "on": false}, {"d": 2.0, "cost": 1, "on": false}]
	assert_eq(ShadowBudget.pick(e, 8, 50.0), [true, false, true] as Array[bool])


func test_pick_hysteresis_keeps_the_lit_one() -> void:
	var e: Array = [{"d": 4.0, "cost": 2, "on": false}, {"d": 5.0, "cost": 2, "on": true}]
	assert_eq(ShadowBudget.pick(e, 2, 50.0), [false, true] as Array[bool], "1 m nearer is not enough to take the shadow")
	e[0]["d"] = 2.5
	assert_eq(ShadowBudget.pick(e, 2, 50.0), [true, false] as Array[bool], "past the hysteresis it moves")


func test_levels_ordered() -> void:
	for pair: Array in [["low", "medium"], ["medium", "high"], ["high", "ultra"]]:
		assert_lt(int(ShadowBudget.row(pair[0])[0]), int(ShadowBudget.row(pair[1])[0]), "%s has fewer views than %s" % pair)
	assert_false(bool(ShadowBudget.row("low")[2]), "below Ultra the omni lamps use dual-paraboloid shadows")
	assert_true(bool(ShadowBudget.row("ultra")[2]))
	assert_eq(ShadowBudget.row("nonsense"), ShadowBudget.row("high"))


func _lamp(root: Node3D, nm: String, pos: Vector3, rng: float = 5.0) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = nm
	l.shadow_enabled = true
	l.omni_range = rng
	l.position = pos
	root.add_child(l)
	return l


func test_node_keeps_nearest_and_lets_go_of_script_toggles() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var near: OmniLight3D = _lamp(root, "Near", Vector3(0, 0, 3))
	var mid: OmniLight3D = _lamp(root, "Mid", Vector3(0, 0, 12))
	var far: OmniLight3D = _lamp(root, "Far", Vector3(0, 0, 200))
	var plain: OmniLight3D = _lamp(root, "Plain", Vector3(0, 0, 1))
	plain.shadow_enabled = false
	var actor: CharacterBody3D = CharacterBody3D.new()
	root.add_child(actor)
	var torch: OmniLight3D = _lamp(actor, "Torch", Vector3(0, 0, 400))
	var sb: ShadowBudget = ShadowBudget.new()
	sb.map_root = root
	sb.level = "low"   # 4 views: two dual-paraboloid omnis
	root.add_child(sb)
	await wait_process_frames(3)
	assert_eq(near.omni_shadow_mode, OmniLight3D.SHADOW_DUAL_PARABOLOID, "below Ultra: 2 views, not a cube's 6")
	assert_true(near.shadow_enabled)
	assert_true(mid.shadow_enabled)
	assert_false(far.shadow_enabled, "past the budget and the distance")
	assert_false(plain.shadow_enabled, "a lamp built without a shadow never gets one")
	assert_true(torch.shadow_enabled, "a light a character carries is left alone")
	assert_eq(int(sb.stats["views"]), 4)
	sb.set_level("ultra")
	assert_eq(near.omni_shadow_mode, OmniLight3D.SHADOW_CUBE, "Ultra keeps the cube shadows")
	assert_false(far.shadow_enabled, "Ultra reaches 60 m past a lamp's reach: 195 m is still too far")
	sb.set_level("low")
	cam.global_position = Vector3(0, 0, 200)
	sb._rerank()
	assert_true(far.shadow_enabled, "the camera moved: the lamp now nearest gets the shadow")
	assert_false(near.shadow_enabled)
	near.remove_meta(ShadowBudget.OFF)   # as if the lamp's own script turned it off
	sb._rerank()
	cam.global_position = Vector3.ZERO
	sb._rerank()
	assert_false(near.shadow_enabled, "a shadow its own script turned off is not turned back on")


func test_individual_graphics_settings_survive_a_restart() -> void:
	# T-258: gfx_* keys were saved but never read back (only the defaults' keys were), so every launch played the
	# whole preset again.
	var keep_values: Dictionary = GLSettings.values.duplicate(true)
	var keep_path: String = GLSettings.path
	var keep_over: Dictionary = GLSettings.overrides.duplicate(true)
	var p: String = "user://_test_gfx_reload.cfg"
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings", "graphics_preset", "ultra")
	cfg.set_value("settings", "gfx_shadows", "low")
	cfg.set_value("settings", "gfx_gi", false)
	cfg.save(p)
	GLSettings.path = p
	for k: Variant in (GLSettings.PRESETS["high"] as Dictionary).keys():
		GLSettings.values.erase(str(k))   # as at a fresh launch
	GLSettings.load_settings()
	var shadows: Variant = GLSettings.gfx("gfx_shadows")
	var gi: Variant = GLSettings.gfx("gfx_gi")
	var ao: Variant = GLSettings.gfx("gfx_ao")
	GLSettings.values = keep_values
	GLSettings.path = keep_path
	GLSettings.overrides = keep_over
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	assert_eq(shadows, "low", "the player's Shadows choice is read back")
	assert_eq(gi, false, "the player's GI choice is read back")
	assert_eq(ao, GLSettings.PRESETS["ultra"]["gfx_ao"], "a setting never changed follows the preset")
