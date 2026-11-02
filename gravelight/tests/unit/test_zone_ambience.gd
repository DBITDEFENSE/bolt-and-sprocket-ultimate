extends GutTest
## ZoneAmbience (UPDATE 09 section 5, T-145): the schema check, the crossfade state machine (a bed fades in from
## silence while the old one fades out and is dropped, no flapping, silence for an unknown zone), the one-shot timers,
## and every file in data/gravelight/ambience/ (map02 at least) valid with every bed and one-shot key resolvable.

const AMB_DIR: String = "res://data/gravelight/ambience/"

var _za: ZoneAmbience


func _cfg() -> Dictionary:
	return {"crossfade_s": 2.0, "zones": {
		"A": {"bed": "test_bed_a", "db": -6.0, "oneshots": [{"key": "test_shot", "every_s": [1.0, 1.0], "db": -3.0}]},
		"B": {"bed": "test_bed_b", "db": -10.0}}}


func before_each() -> void:
	_za = ZoneAmbience.new()
	_za.setup(_cfg())
	_za.enabled = false   # the tests drive set_zone / advance themselves (no listener polling)
	add_child_autofree(_za)


func test_schema_accepts_a_good_config_and_names_the_bad_parts() -> void:
	assert_eq(ZoneAmbience.validate(_cfg()).size(), 0, "a good config has no errors")
	assert_gt(ZoneAmbience.validate({}).size(), 0, "no zones")
	assert_gt(ZoneAmbience.validate({"zones": {"A": {"db": -3}}}).size(), 0, "a zone without a bed")
	assert_gt(ZoneAmbience.validate({"zones": {"A": {"bed": "x", "oneshots": [{"key": "y", "every_s": [5, 2]}]}}}).size(), 0, "every_s max < min")
	assert_gt(ZoneAmbience.validate({"zones": {"A": {"bed": "x", "oneshots": [{"every_s": [1, 2]}]}}}).size(), 0, "a one-shot without a key")
	assert_gt(ZoneAmbience.validate({"crossfade_s": "slow", "zones": {}}).size(), 0, "crossfade_s not a number")


func test_entering_a_zone_fades_its_bed_in_from_silence() -> void:
	_za.set_zone(&"A")
	assert_eq(_za.current_zone, &"A")
	var b: Array[Dictionary] = _za.beds()
	assert_eq(b.size(), 1, "one bed")
	assert_eq(str(b[0]["key"]), "test_bed_a")
	assert_almost_eq(float(b[0]["db"]), ZoneAmbience.SILENT_DB, 0.01, "starts silent")
	assert_true(_za.fading())
	_za.advance(1.0)
	var mid: float = float(_za.beds()[0]["db"])
	assert_true(mid > ZoneAmbience.SILENT_DB and mid < -6.0, "half way up at half the crossfade (%.1f dB)" % mid)
	_za.advance(1.5)
	assert_almost_eq(float(_za.beds()[0]["db"]), -6.0, 0.01, "at the zone's level after crossfade_s")
	assert_false(_za.fading())


func test_crossing_into_the_next_zone_crossfades_and_drops_the_old_bed() -> void:
	_za.set_zone(&"A")
	_za.advance(3.0)
	_za.set_zone(&"B")
	var b: Array[Dictionary] = _za.beds()
	assert_eq(b.size(), 2, "old and new both sound during the crossfade")
	assert_true(bool(b[0]["out"]) and str(b[0]["key"]) == "test_bed_a", "A is fading out")
	assert_false(bool(b[1]["out"]), "B is fading in")
	_za.advance(1.0)
	b = _za.beds()
	assert_true(float(b[0]["db"]) < -6.0 and float(b[1]["db"]) > ZoneAmbience.SILENT_DB, "both mid-fade")
	_za.advance(1.1)
	b = _za.beds()
	assert_eq(b.size(), 1, "the faded-out bed is gone")
	assert_eq(str(b[0]["key"]), "test_bed_b")
	assert_almost_eq(float(b[0]["db"]), -10.0, 0.01)


func test_same_zone_again_changes_nothing_and_unknown_zone_is_silence() -> void:
	_za.set_zone(&"A")
	_za.advance(3.0)
	_za.set_zone(&"A")
	assert_eq(_za.beds().size(), 1, "re-entering the same zone does not restart its bed")
	assert_false(_za.fading())
	_za.set_zone(&"NOWHERE")
	assert_eq(_za.beds().size(), 1, "only the old bed, fading out")
	_za.advance(2.5)
	assert_eq(_za.beds().size(), 0, "a zone without an entry is silent")


func test_quick_back_and_forth_never_stacks_beds() -> void:
	for i: int in 6:
		_za.set_zone(&"A" if i % 2 == 0 else &"B")
		_za.advance(0.3)
	_za.advance(5.0)
	assert_eq(_za.beds().size(), 1, "one bed left after the fades settle")
	assert_eq(str(_za.beds()[0]["key"]), "test_bed_b")


func test_oneshots_fire_on_their_interval_for_the_current_zone_only() -> void:
	_za.set_zone(&"A")
	_za.advance(0.5)
	assert_eq(_za.oneshots_played, 0)
	_za.advance(0.6)
	assert_eq(_za.oneshots_played, 1, "every_s [1, 1]: one after a second")
	_za.advance(1.0)
	assert_eq(_za.oneshots_played, 2)
	_za.set_zone(&"B")
	_za.advance(5.0)
	assert_eq(_za.oneshots_played, 2, "B has no one-shots")


func test_config_path_falls_back_to_the_map_prefix() -> void:
	assert_eq(ZoneAmbience.config_path(&"map02_totenhafen"), AMB_DIR + "map02.json")
	assert_eq(ZoneAmbience.config_path(&"no_such_map"), "")


func test_every_ambience_file_is_valid_and_every_key_resolves() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(AMB_DIR)
	var checked: int = 0
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var cfg: Dictionary = ZoneAmbience.load_config(AMB_DIR + f)
		assert_false(cfg.is_empty(), "%s parses" % f)
		var errs: PackedStringArray = ZoneAmbience.validate(cfg)
		assert_eq(errs.size(), 0, "%s: %s" % [f, ", ".join(errs)])
		for z: String in (cfg.get("zones", {}) as Dictionary).keys():
			var zc: Dictionary = cfg["zones"][z]
			assert_true(ZoneAmbience.resolvable(str(zc["bed"])), "%s %s bed %s resolves" % [f, z, zc["bed"]])
			for os: Dictionary in zc.get("oneshots", []):
				assert_true(ZoneAmbience.resolvable(str(os["key"])), "%s %s one-shot %s resolves" % [f, z, os["key"]])
		checked += 1
	assert_gt(checked, 0, "at least one ambience file")


func test_map02_covers_every_totenhafen_zone() -> void:
	var cfg: Dictionary = ZoneAmbience.load_config(AMB_DIR + "map02.json")
	var zones: Dictionary = GLData.load_json("res://data/gravelight/map02.json").get("zones", {})
	assert_gt(zones.size(), 0)
	for z: String in zones.keys():
		assert_true((cfg.get("zones", {}) as Dictionary).has(z), "map02 ambience has a bed for %s" % z)
	var amb: Dictionary = GLData.load_json("res://data/gravelight/audio.json").get("music", {}).get("ambient", {})
	assert_eq(str(amb.get("map02_totenhafen", "")), "ambient_map02_storm", "the map bed under the zone beds")


func test_attach_adds_the_node_only_for_maps_with_a_file() -> void:
	var m: MapRoot = MapRoot.new()   # not added to the tree: _ready (the whole match) never runs
	m.map_id = &"map02_totenhafen"
	var za: ZoneAmbience = ZoneAmbience.attach(m)
	assert_not_null(za, "map02 has an ambience file")
	assert_eq(za.get_parent(), m)
	assert_almost_eq(za.crossfade_s, 1.5, 0.001)
	m.map_id = &"test_range"
	assert_null(ZoneAmbience.attach(m), "no file, no node")
	m.free()
