extends GutTest
## Graphics presets gate the costly lighting a map asks for (GLSettings._apply_env): SDFGI, SSIL and SSR stay on
## only when both the map's Environment wanted them and the preset allows them; a preset never adds one.

var _saved: Dictionary


func before_each() -> void:
	_saved = GLSettings.values.duplicate(true)
	for k: Variant in (GLSettings.PRESETS["high"] as Dictionary).keys():
		GLSettings.values.erase(str(k))   # T-258: the machine's saved individual settings now load; these tests drive the presets alone


func after_each() -> void:
	GLSettings.values = _saved


func _we(sdfgi: bool, ssil: bool) -> WorldEnvironment:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.sdfgi_enabled = sdfgi
	we.environment.ssil_enabled = ssil
	return we


func test_low_strips_and_high_restores() -> void:
	var we: WorldEnvironment = _we(true, true)
	GLSettings.values["graphics_preset"] = "low"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled)
	assert_false(we.environment.ssil_enabled)
	GLSettings.values["graphics_preset"] = "medium"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled, "medium: no SDFGI")
	assert_true(we.environment.ssil_enabled, "medium keeps SSIL")
	GLSettings.values["graphics_preset"] = "high"
	GLSettings._apply_env(we)
	assert_true(we.environment.sdfgi_enabled, "the map's wish comes back on high")
	we.free()


func test_a_preset_never_adds_an_effect() -> void:
	var we: WorldEnvironment = _we(false, false)
	GLSettings.values["graphics_preset"] = "high"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled)
	assert_false(we.environment.ssil_enabled)
	assert_false(we.environment.ssr_enabled)
	we.free()


# ------------------------------------------------------------------ T-264: handheld, Apple silicon, the 3D limit

const _I: int = RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
const _D: int = RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
const _O: int = RenderingDevice.DEVICE_TYPE_OTHER


func test_the_deck_gets_handheld_by_name_or_by_its_environment() -> void:
	for name_: String in ["AMD Custom GPU 0405 (RADV VANGOGH)", "AMD Custom GPU 0932 (RADV VANGOGH)", "AMD Custom GPU 0405", "AMD Custom GPU 0932"]:
		assert_true(GLSettings.is_deck_adapter(name_), name_)
		assert_eq(GLSettings.detect_preset(name_, _I, "forward_plus"), "handheld", name_)
		assert_eq(GLSettings.detect_preset(name_, _O, "mobile"), "handheld", name_ + " (type unknown)")
	# the client's SteamDeck=1 alone is enough (a future APU with another name)
	assert_eq(GLSettings.detect_preset("AMD Radeon Graphics (RADV FUTURECHIP)", _I, "forward_plus", true), "handheld")
	assert_eq(GLSettings.detect_preset("", _O, "forward_plus", true), "handheld")
	# and without either, another AMD APU stays what it was
	assert_false(GLSettings.is_deck_adapter("AMD Radeon 780M Graphics"))
	assert_eq(GLSettings.detect_preset("AMD Radeon 780M Graphics", _I, "forward_plus"), "low")
	assert_eq(GLSettings.detect_preset("AMD Radeon Graphics (RADV REMBRANDT)", _I, "forward_plus"), "low")
	assert_false(GLSettings.is_deck_adapter("NVIDIA GeForce RTX 5090"))


func test_the_renderer_and_software_come_before_the_deck() -> void:
	assert_eq(GLSettings.detect_preset("AMD Custom GPU 0405 (RADV VANGOGH)", _I, "gl_compatibility", true), "web", "the Compatibility renderer has its own preset")
	assert_eq(GLSettings.detect_preset("llvmpipe (LLVM 17.0.6, 256 bits)", RenderingDevice.DEVICE_TYPE_CPU, "forward_plus", true), "low", "a software renderer is low wherever it runs")


func test_apple_silicon_by_tier() -> void:
	var cases: Array = [
		["Apple M1", "base", "medium", 900], ["Apple M2", "base", "medium", 900], ["Apple M3", "base", "medium", 900], ["Apple M4", "base", "medium", 900],
		["Apple M1 Pro", "pro", "medium", 1200], ["Apple M3 Pro", "pro", "medium", 1200], ["Apple M4 Pro", "pro", "medium", 1200],
		["Apple M1 Max", "max", "high", 1440], ["Apple M2 Ultra", "max", "high", 1440], ["Apple M4 Max", "max", "high", 1440],
	]
	for c: Array in cases:
		assert_eq(GLSettings.apple_tier(str(c[0])), str(c[1]), str(c[0]))
		assert_eq(GLSettings.detect_preset(str(c[0]), _I, "forward_plus"), str(c[2]), str(c[0]))
		assert_eq(GLSettings.detect_max_lines(str(c[0])), int(c[3]), str(c[0]))
	for other: String in ["NVIDIA GeForce RTX 5090", "Intel(R) Iris(R) Plus Graphics 655", "AMD Radeon Pro 5500M", "Apple Paravirtual device", "", "Pineapple M1"]:
		assert_eq(GLSettings.apple_tier(other), "", other)
		assert_eq(GLSettings.detect_max_lines(other), 0, other + ": no limit")
	# an Intel Mac: its Intel graphics are low, its Radeon Pro is a discrete card
	assert_eq(GLSettings.detect_preset("Intel(R) Iris(R) Plus Graphics 655", _I, "forward_plus"), "low")
	assert_eq(GLSettings.detect_preset("AMD Radeon Pro 5500M", _D, "forward_plus"), "high")
	assert_eq(GLSettings.detect_preset("Apple Paravirtual device", RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU, "forward_plus"), "low")
	# on the Compatibility renderer the tier does not matter
	assert_eq(GLSettings.detect_preset("Apple M3 Max", _I, "gl_compatibility"), "web")


func test_no_new_branch_picks_ultra() -> void:
	for name_: String in ["AMD Custom GPU 0932 (RADV VANGOGH)", "Apple M4 Max", "Apple M2 Ultra", "Apple M1"]:
		for deck: bool in [false, true]:
			assert_ne(GLSettings.detect_preset(name_, _I, "forward_plus", deck), "ultra")


func test_effective_scale_holds_the_3d_picture_to_the_limit() -> void:
	assert_almost_eq(GLSettings.effective_scale(1.0, 0, 2880), 1.0, 0.0001, "no limit: the setting")
	assert_almost_eq(GLSettings.effective_scale(0.9, 0, 1600), 0.9, 0.0001)
	assert_almost_eq(GLSettings.effective_scale(0.9, 900, 1664), 900.0 / 1664.0, 0.0001, "a 13 inch Retina panel: 900 lines")
	assert_almost_eq(GLSettings.effective_scale(1.0, 1440, 2880), 0.5, 0.0001, "5K: 1440 lines")
	assert_almost_eq(GLSettings.effective_scale(1.0, 900, 2880), 0.5, 0.0001, "never under 50%")
	assert_almost_eq(GLSettings.effective_scale(0.9, 900, 800), 0.9, 0.0001, "a window smaller than the limit keeps the setting")
	assert_almost_eq(GLSettings.effective_scale(0.75, 1080, 1080), 0.75, 0.0001, "the limit never raises the scale")
	assert_almost_eq(GLSettings.effective_scale(1.0, 900, 0), 1.0, 0.0001, "no window size: the setting")
	assert_almost_eq(GLSettings.effective_scale(0.2, 0, 1080), 0.5, 0.0001)


func test_the_limit_reaches_the_viewport_and_is_not_a_presets() -> void:
	var root: Window = get_tree().root
	var before_scale: float = root.scaling_3d_scale
	var before_mode: Viewport.Scaling3DMode = root.scaling_3d_mode
	GLSettings.values["graphics_preset"] = "high"
	GLSettings.values["gfx_max_lines"] = maxi(1, int(root.size.y / 2.0))
	GLSettings._apply_scale()
	assert_almost_eq(root.scaling_3d_scale, 0.5, 0.01, "half the window's lines")
	GLSettings.values["gfx_max_lines"] = 0
	GLSettings._apply_scale()
	assert_almost_eq(root.scaling_3d_scale, 1.0, 0.0001, "the limit off: High's 100%")
	for pn: String in GLSettings.PRESETS.keys():
		assert_false((GLSettings.PRESETS[pn] as Dictionary).has("gfx_max_lines"), "the limit is not %s's to overwrite" % pn)
	for lines: int in [0, 900, 1200, 1440]:
		assert_true(GLSettings.MAX_LINES_STEPS.has(lines), "the menu offers %d, which first launch can pick" % lines)
	root.scaling_3d_scale = before_scale
	root.scaling_3d_mode = before_mode


func test_handheld_frame_cap() -> void:
	assert_eq(GLSettings.handheld_frame_cap(60.0), 60)
	assert_eq(GLSettings.handheld_frame_cap(59.94), 60)
	assert_eq(GLSettings.handheld_frame_cap(90.0), 45, "the OLED panel: half its refresh")
	assert_eq(GLSettings.handheld_frame_cap(120.0), 60)
	assert_eq(GLSettings.handheld_frame_cap(144.0), 60)
	assert_eq(GLSettings.handheld_frame_cap(40.0), 40)
	assert_eq(GLSettings.handheld_frame_cap(-1.0), 60, "unknown refresh")


func test_handheld_is_a_whole_preset_the_menu_can_show() -> void:
	var h: Dictionary = GLSettings.PRESETS["handheld"]
	assert_eq(h.keys().size(), (GLSettings.PRESETS["high"] as Dictionary).keys().size(), "every individual setting")
	assert_true(GLSettings.preset_order(false).has("handheld"))
	assert_true(GLSettings.preset_order(true).has("handheld"))
	var with_web: PackedStringArray = GLSettings.preset_order(true)
	assert_eq(with_web[with_web.size() - 1], "web", "the browser's preset stays last")
	for pn: String in with_web:
		assert_true(GLSettings.PRESET_LABELS.has(pn), "%s has a menu label" % pn)
		assert_eq(GLSettings.matching_preset(GLSettings.PRESETS[pn]), pn, "%s reads as itself, not as another preset" % pn)
	assert_eq(str(GLSettings.PRESET_LABELS["handheld"]), "Handheld")
	# its choices: full resolution with no upscaler, the thin fog kept, no bounce light / SSIL / SSR
	assert_eq(float(h["gfx_scale"]), 1.0)
	assert_eq(str(h["gfx_upscaler"]), "bilinear")
	assert_eq(str(h["gfx_fog"]), "low")
	assert_false(bool(h["gfx_gi"]) or bool(h["gfx_ssil"]) or bool(h["gfx_ssr"]))
	# the shared settings' quality table knows it too (core/settings.gd mirrors graphics_preset)
	assert_true(Settings.QUALITY.has("handheld"))


func test_set_preset_handheld_writes_gates_and_survives_a_restart() -> void:
	var path_before: String = GLSettings.path
	GLSettings.path = "user://test_t264_settings.cfg"
	GLSettings.values["gfx_max_lines"] = 900
	GLSettings.set_preset("handheld")
	assert_eq(str(GLSettings.values["graphics_preset"]), "handheld")
	assert_eq(str(GLSettings.gfx("gfx_fog")), "low")
	assert_eq(int(GLSettings.values["gfx_max_lines"]), 900, "a preset leaves the 3D limit alone")
	var we: WorldEnvironment = _we(true, true)
	we.environment.volumetric_fog_enabled = true
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled)
	assert_false(we.environment.ssil_enabled)
	assert_true(we.environment.volumetric_fog_enabled, "the map's fog stays on Handheld")
	we.free()
	# saved and read back: the limit and the preset survive a restart, and first-launch detection will not run again
	GLSettings.values["gfx_max_lines"] = 0
	GLSettings.values["graphics_preset"] = "high"
	GLSettings.load_settings()
	assert_eq(int(GLSettings.values["gfx_max_lines"]), 900)
	assert_eq(str(GLSettings.values["graphics_preset"]), "handheld")
	assert_true(GLSettings._had_preset, "a saved preset is never replaced by the detection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_t264_settings.cfg"))
	GLSettings.path = path_before
	GLSettings.load_settings()
	GLSettings.values = _saved.duplicate(true)
	GLSettings.apply_visuals()


func test_pad_ui_actions_are_bound_once() -> void:
	# GLSettings._ready already ran: A confirms and B goes back, and asking again adds nothing
	assert_eq(GLSettings.ensure_pad_ui_actions(), 0, "bound at start, not twice")
	var want: Dictionary = {&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B}
	for action: StringName in want.keys():
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.device = 3
		e.button_index = want[action] as JoyButton
		e.pressed = true
		assert_true(e.is_action_pressed(action), "%s answers to the pad on any device" % action)
		var pads: int = 0
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				pads += 1
		assert_eq(pads, 1, "%s has one pad button" % action)


func test_small_text_floor() -> void:
	var before: int = MenuKit.text_floor
	MenuKit.text_floor = 0
	var fine: int = MenuKit.size("fine")
	var title: int = MenuKit.size("title")
	assert_lt(fine, 15, "the scale has print under 15")
	assert_eq(MenuKit.px(14), MenuKit.px(14))
	MenuKit.text_floor = 15
	assert_eq(MenuKit.size("fine"), 15, "the floor lifts the smallest size")
	assert_gte(MenuKit.px(12), 15)
	assert_gte(MenuKit.px(14), 15)
	assert_eq(MenuKit.size("title"), title, "and leaves the big sizes alone")
	MenuKit.text_floor = 18
	assert_eq(MenuKit.size("caption"), 18)
	assert_eq(MenuKit.size("title"), title)
	MenuKit.text_floor = before
	for f: int in GLSettings.TEXT_FLOORS:
		assert_true(f == 0 or f >= 15)
	assert_true(GLSettings.TEXT_FLOORS.has(GLSettings.HANDHELD_TEXT_FLOOR), "the menu offers what a handheld gets at first launch")
	GLSettings.values["ui_text_floor"] = 18
	GLSettings.apply_visuals()
	assert_eq(MenuKit.text_floor, 18, "the setting reaches MenuKit")
	GLSettings.values["ui_text_floor"] = 0
	GLSettings.apply_visuals()
	assert_eq(MenuKit.text_floor, 0)
	assert_eq(fine, MenuKit.size("fine"))
