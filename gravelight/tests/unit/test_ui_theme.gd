extends GutTest
## The UI kit (UPDATE 05 section 7, T-096): the bundled fonts load (no system fallback stands in), every scale key
## MenuKit needs is in data/gravelight/ui.json, the theme resource loads and is applied at the HUD / menu roots,
## and no SystemFont is built anywhere in gravelight/ui except the kit's declared fallback (and perk_cap.gd's own,
## which T-082 keeps). The licence gate (test_license_gate) covers the fonts' paperwork.

const UI_DIR: String = "res://gravelight/ui"
## Files allowed to build a SystemFont: the kit (its declared fallback) and the cap renderer (read-only, T-082).
const SYSTEM_FONT_ALLOWED: PackedStringArray = ["menu_kit.gd", "perk_cap.gd"]


func before_all() -> void:
	MenuKit.reset()


func test_ui_table_has_every_key() -> void:
	var cfg: Dictionary = MenuKit.cfg()
	assert_false(cfg.has("_missing"), "data/gravelight/ui.json loads")
	for k: String in ["fonts", "roles", "scale", "outline", "hud", "crosshair", "hitmarker", "minimap", "pause_map"]:
		assert_true(cfg.has(k), "ui.json has '%s'" % k)
	var scale: Dictionary = cfg.get("scale", {})
	for key: String in MenuKit.SIZE_KEYS:
		assert_true(scale.has(key), "scale key '%s'" % key)
		if scale.has(key):
			assert_gt(int(scale[key]), 0, "scale '%s' is a size" % key)
	assert_true((scale.get("steps", []) as Array).size() >= 6, "the scale has its steps")
	for fk: String in MenuKit.FONT_KEYS:
		assert_true((cfg["fonts"] as Dictionary).has(fk), "font key '%s'" % fk)
	for role: Variant in (cfg["roles"] as Dictionary).keys():
		if str(role).begins_with("_"):
			continue
		var fkey: String = str(cfg["roles"][role])
		assert_true(MenuKit.FONT_KEYS.has(fkey), "role %s names a font key (%s)" % [role, fkey])
		assert_true(scale.has(str(role)), "role %s has a scale size" % role)


func test_bundled_fonts_load() -> void:
	var fonts: Dictionary = MenuKit.cfg().get("fonts", {})
	for key: String in MenuKit.FONT_KEYS:
		var path: String = str((fonts[key] as Dictionary).get("file", ""))
		assert_true(path.begins_with("res://assets/third_party/google_fonts/"), key + " is a bundled Google Fonts file")
		assert_true(ResourceLoader.exists(path), key + " file exists: " + path)
		var f: Font = load(path) as Font
		assert_not_null(f, key + " loads as a Font")
		if f != null:
			assert_gt(f.get_string_size("ROUND 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, 10.0, key + " shapes text")
	assert_true(MenuKit.fonts_bundled(), "no system fallback stood in for a bundled font")
	for fn: Callable in [MenuKit.stamp_font, MenuKit.type_font, MenuKit.body_font, MenuKit.mono_font]:
		var f2: Font = fn.call()
		assert_false(f2 is SystemFont, "the kit's fonts are the bundled files, not SystemFonts")


func test_scale_snaps_to_steps() -> void:
	var steps: Array = MenuKit.cfg()["scale"]["steps"]
	for s: Variant in steps:
		assert_eq(MenuKit.px(int(s)), int(s), "a step maps to itself")
	assert_true(steps.has(MenuKit.px(22)), "an odd size lands on a step")
	assert_true(steps.has(MenuKit.px(1)), "a tiny size lands on the smallest step")
	assert_eq(MenuKit.size("body"), int(MenuKit.cfg()["scale"]["body"]))


func test_theme_loads_and_is_applied_at_roots() -> void:
	var th: Theme = MenuKit.theme()
	assert_not_null(th, "gravelight_theme.tres loads")
	assert_true(ResourceLoader.exists(MenuKit.THEME_PATH), "the theme resource exists")
	assert_not_null(th.default_font, "the theme has a default (body) font")
	assert_true(th.has_font("font", "Button"), "buttons get the typewriter from the theme")
	assert_true(th.has_stylebox("focus", "Button"), "buttons have a visible focus style")
	var focus: StyleBoxFlat = th.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_not_null(focus, "the focus style is a flat box")
	if focus != null:
		assert_gt(focus.border_width_left, 0, "the focus outline has a border")
	# the HUD root
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	var root: Control = hud.get_child(0) as Control
	assert_not_null(root, "the HUD has a Control root")
	if root != null:
		assert_eq(root.theme, th, "the HUD root carries the theme")
	# a menu page (MenuScreen) root
	var credits: MenuCredits = MenuCredits.new()
	add_child_autofree(credits)
	await get_tree().process_frame
	assert_eq(credits.theme, th, "a menu screen carries the theme")
	# the pause page root
	var pm: PauseMenu = PauseMenu.new()
	add_child_autofree(pm)
	await get_tree().process_frame
	var proot: Control = pm.get_child(0) as Control
	assert_not_null(proot, "the pause page has a root")
	if proot != null:
		assert_eq(proot.theme, th, "the pause page root carries the theme")


func test_no_stray_system_fonts_in_ui() -> void:
	var offenders: PackedStringArray = []
	for dir: String in [UI_DIR, "res://ui/map"]:
		var da: DirAccess = DirAccess.open(dir)
		assert_not_null(da, dir + " opens")
		if da == null:
			continue
		for f: String in da.get_files():
			if f.get_extension() != "gd":
				continue
			var src: String = FileAccess.get_file_as_string(dir.path_join(f))
			if src.contains("SystemFont.new()") and not SYSTEM_FONT_ALLOWED.has(f):
				offenders.append(dir.path_join(f))
	assert_eq(offenders.size(), 0, "no SystemFont outside the kit's declared fallback: %s" % ", ".join(offenders))


func test_hud_margin_respects_safe_area() -> void:
	var m: Vector2 = MenuKit.hud_margin(Vector2(1920, 1080))
	var cfgm: Array = MenuKit.hud("margin", [56.0, 44.0])
	assert_almost_eq(m.x, maxf(float(cfgm[0]), 1920.0 * float(MenuKit.hud("safe_frac", 0.03))), 0.01)
	var wide: Vector2 = MenuKit.hud_margin(Vector2(3440, 1440))
	assert_gte(wide.x, 3440.0 * float(MenuKit.hud("safe_frac", 0.03)), "ultrawide keeps the safe area")
