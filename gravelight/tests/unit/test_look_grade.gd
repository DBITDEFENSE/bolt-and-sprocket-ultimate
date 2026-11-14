extends GutTest
## UPDATE 12 section 1 (T-207, contract C2): the per-map colour grade loader. The zones merge over the map's block,
## an absent key leaves the Environment alone, a missing file leaves it untouched, every map's file names its map,
## the post block comes back filled, the generated LUT keeps Nachtglas violet when everything else goes grey, the
## brightness slider still scales the grade and the reel's cuts take the reel grade.

const MAPS: PackedStringArray = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach",
	"map04b_kranich", "map04c_groomlake", "map04d_mondlicht", "menu", "cinema_reel"]

var _saved_brightness: Variant = null


func before_each() -> void:
	LookGrade.reset_cache()
	_saved_brightness = GLSettings.values.get("brightness", 1.0)
	GLSettings.values["brightness"] = 1.0


func after_each() -> void:
	GLSettings.values["brightness"] = _saved_brightness
	LookGrade.reset_cache()


func _env() -> Environment:
	var e: Environment = Environment.new()
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.3
	e.ambient_light_energy = 0.3
	e.ambient_light_color = Color(0.22, 0.27, 0.4)
	e.fog_enabled = true
	e.fog_density = 0.016
	e.fog_light_color = Color(0.07, 0.09, 0.15)
	e.volumetric_fog_density = 0.022
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.78
	e.adjustment_contrast = 1.14
	e.adjustment_brightness = 1.0
	return e


func test_merge_is_deep_and_leaves_the_base_alone() -> void:
	var base: Dictionary = {"fog": {"density": 0.01, "color": "#101010"}, "exposure": 1.0, "adjust": {"contrast": 1.1}}
	var out: Dictionary = LookGrade.merge(base, {"fog": {"density": 0.02}, "tonemap": "filmic"})
	assert_eq(float(out["fog"]["density"]), 0.02, "the zone's density wins")
	assert_eq(str(out["fog"]["color"]), "#101010", "the map's colour stays")
	assert_eq(str(out["tonemap"]), "filmic", "new keys come in")
	assert_eq(float(out["adjust"]["contrast"]), 1.1, "untouched blocks stay")
	assert_eq(float(base["fog"]["density"]), 0.01, "the base is not written")


func test_zones_merge_over_the_map_and_the_zones_key_is_dropped() -> void:
	var d: Dictionary = LookGrade.resolved("map01_kaltenbrunn", "core")
	assert_false(d.has("zones"), "the zones block is not in a resolved grade")
	assert_eq(float(d["adjust"]["saturation"]), 1.0, "the core keeps full saturation (GDD 17)")
	assert_eq(float(d["adjust"]["contrast"]), float(LookGrade.data("map01_kaltenbrunn")["adjust"]["contrast"]), "the map's contrast carries into the zone")
	var s: Dictionary = LookGrade.resolved("map01_kaltenbrunn", "surface")
	assert_lt(float(s["adjust"]["saturation"]), 1.0, "the surface is desaturated")
	var none: Dictionary = LookGrade.resolved("map01_kaltenbrunn", "no_such_zone")
	assert_eq(none, LookGrade.resolved("map01_kaltenbrunn"), "an unknown zone is the map's own grade")


func test_absent_keys_leave_the_environment_alone() -> void:
	var e: Environment = _env()
	LookGrade.apply_dict(e, {"fog": {"density": 0.03}})
	assert_almost_eq(e.fog_density, 0.03, 0.0001, "the given key is written")
	assert_eq(e.fog_light_color, Color(0.07, 0.09, 0.15), "the fog colour was not in the dict")
	assert_eq(e.tonemap_mode, Environment.TONE_MAPPER_AGX, "no tonemap key: the map's tonemap stays")
	assert_almost_eq(e.tonemap_exposure, 1.3, 0.0001, "no exposure key")
	assert_almost_eq(e.adjustment_saturation, 0.78, 0.0001, "no adjust block")
	assert_almost_eq(e.ambient_light_energy, 0.3, 0.0001, "no ambient block")
	assert_null(e.adjustment_color_correction, "no tint / mono / lut: no LUT")


func test_a_missing_file_leaves_the_environment_untouched() -> void:
	var e: Environment = _env()
	var before: Dictionary = _snapshot(e)
	var d: Dictionary = LookGrade.apply(e, "no_such_map_xyz")
	assert_true(d.is_empty(), "nothing applied")
	assert_eq(_snapshot(e), before, "nothing changed")
	assert_false(LookGrade.has("no_such_map_xyz"))
	assert_true(LookGrade.post_params("no_such_map_xyz").is_empty(), "no file: no post block (the shader keeps its own)")


func test_every_grade_file_names_its_map_and_applies() -> void:
	for m: String in MAPS:
		var d: Dictionary = LookGrade.data(m)
		assert_false(d.is_empty(), m + " has a grade file")
		assert_eq(str(d.get("map", "")), m, m + ": the file names its map")
		assert_true(d.has("accents") and (d["accents"] as Dictionary).has("violet"), m + ": the violet accent is named")
		var e: Environment = _env()
		var applied: Dictionary = LookGrade.apply(e, m)
		assert_false(applied.is_empty(), m + " applies")
		assert_eq(str(e.get_meta("gl_look")), m, m + ": the Environment remembers its grade")
		assert_true(e.adjustment_enabled, m + ": adjustments on")
		var p: Dictionary = LookGrade.post_params(m)
		for k: String in ["grain", "vignette", "edge_soft", "ca"]:
			assert_true(p.has(k), "%s: post block has %s" % [m, k])
	var rd: Dictionary = LookGrade.data("cinema_reel")
	assert_true((rd.get("cuts", []) as Array).has("lazarus_saturday"), "the reel grade knows the prologue")


func test_replacement_cuts_keep_their_grade_in_theatre_and_campaign() -> void:
	var host: Node3D = Node3D.new()
	host.set_script(load("res://gravelight/maps/map_root.gd"))
	host.set("map_id", &"map00_crossroads")
	assert_eq(LookGrade.cinema_id(host, "lazarus_saturday"), "cinema_horror")
	assert_eq(LookGrade.cinema_id(host, "fourth_day"), "cinema_horror")
	assert_eq(LookGrade.cinema_id(host, "gravelight_one"), "cinema_horror")
	assert_eq(LookGrade.cinema_id(null, "gravelight_one"), "cinema_horror")
	assert_eq(LookGrade.cinema_id(null, "reel:lazarus_saturday"), "cinema_reel")
	assert_eq(LookGrade.cinema_id(host, "exfil_m0_m1"), "map00_crossroads")
	host.free()


func test_the_lut_keeps_violet_and_greys_the_rest_in_mono() -> void:
	var spec: Dictionary = LookGrade.lut_spec(LookGrade.data("map04d_mondlicht"))
	assert_true(spec.has("mono"), "Mondlicht is mono")
	var violet: Color = LookGrade.lut_color(Color.html("#8c33ff"), spec)
	var green: Color = LookGrade.lut_color(Color(0.2, 0.7, 0.2), spec)
	var red: Color = LookGrade.lut_color(Color(0.55, 0.08, 0.08), spec)
	assert_gt(violet.s, 0.6, "Nachtglas violet keeps its colour: s %.2f" % violet.s)
	assert_lt(green.s, 0.05, "green goes grey: s %.2f" % green.s)
	assert_lt(red.s, 0.05, "on Mondlicht even red goes grey (violet the only colour): s %.2f" % red.s)
	var spec0: Dictionary = LookGrade.lut_spec(LookGrade.data("map00_crossroads"))
	var red0: Color = LookGrade.lut_color(Color(0.55, 0.08, 0.08), spec0)
	var green0: Color = LookGrade.lut_color(Color(0.2, 0.7, 0.2), spec0)
	assert_gt(red0.s, green0.s, "on Map 0 blood red keeps more colour than a green")
	var grey: Color = LookGrade.lut_color(Color(0.5, 0.5, 0.5), spec0)
	assert_almost_eq(grey.r * 0.299 + grey.g * 0.587 + grey.b * 0.114, 0.5, 0.03, "the split tone keeps the luma")
	var tex: ImageTexture3D = LookGrade.make_lut(spec, 8)
	assert_eq(tex.get_width(), 8)
	assert_eq(tex.get_depth(), 8)
	assert_true(LookGrade.lut_spec({"tint": {"amount": 0.0}, "mono": 0.0}).is_empty(), "a neutral spec makes no LUT")


func test_the_brightness_slider_and_the_horror_night_still_scale_the_grade() -> void:
	var e: Environment = _env()
	GLSettings.values["brightness"] = 1.2
	e.set_meta("gl_horror_mult", 0.9)
	LookGrade.apply_dict(e, {"adjust": {"brightness": 1.0}})
	assert_almost_eq(float(e.get_meta("gl_base_brightness")), 0.9, 0.0001, "the base folds the horror night in")
	assert_almost_eq(e.adjustment_brightness, 1.08, 0.0001, "the slider scales the base")
	var e2: Environment = _env()
	LookGrade.apply_dict(e2, {"ambient": {"energy_scale": 0.5}})
	LookGrade.apply_dict(e2, {"ambient": {"energy_scale": 0.5}})
	assert_almost_eq(e2.ambient_light_energy, 0.15, 0.0001, "the ambient scale is idempotent (applied twice = once)")


func test_colour_parsing() -> void:
	assert_eq(LookGrade.color("#ff0000"), Color(1, 0, 0))
	assert_eq(LookGrade.color([0.0, 1.0, 0.0]), Color(0, 1, 0))
	assert_eq(LookGrade.color("nonsense", Color.BLUE), Color.BLUE)
	assert_eq(LookGrade.color(null, Color.BLUE), Color.BLUE)


func _snapshot(e: Environment) -> Dictionary:
	return {"tm": e.tonemap_mode, "ex": e.tonemap_exposure, "amb": e.ambient_light_energy, "fog": e.fog_density,
		"fc": e.fog_light_color, "vf": e.volumetric_fog_density, "sat": e.adjustment_saturation, "con": e.adjustment_contrast,
		"br": e.adjustment_brightness, "cc": e.adjustment_color_correction}
