extends GutTest
## UPDATE 10 section 2 (T-154): Totenhafen's living world. data/gravelight/map02_ambience.json validates on Map 0's
## schema with the new event kinds, every kind's numbers are in range, every sound key and VO line it names exists,
## the pure rules (the lighthouse, the beats, the storm by tide stage and level, the dock-by-dock sweep, campaign beat
## rounds) hold, and Map 0's file still validates unchanged (none of the new kinds, its own sections intact).

const KINDS: Array[String] = ["gulls", "lighthouse", "bell_tower", "ships", "low_pass", "raid", "chains", "drips",
	"conveyor_jolt", "radio_chatter", "cutter_slip", "footprints", "frozen_spray", "fish_crates", "storm", "power_spectacle",
	"arrival"]   # (+ T-170: the first step onto the quay)

var cfg: Dictionary
var sounds: Dictionary
var lines: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map02_ambience.json")
	sounds = GLData.load_json("res://data/gravelight/audio.json").get("sounds", {})
	lines = GLData.load_json("res://data/gravelight/vo/lines.json")


func test_file_validates() -> void:
	assert_false(cfg.is_empty(), "map02_ambience.json parses")
	assert_false(bool(cfg.get("needs_landscape", true)), "Totenhafen runs without the Landscape")
	for k: String in KINDS:
		assert_true(cfg.get(k) is Dictionary, "event kind %s is a block" % k)
	for k2: String in ["bombers", "fighters", "artillery", "crows", "dog", "bell", "farm_light", "frost", "chimney"]:
		assert_false(cfg.has(k2), "no Map 0 inn section %s on Totenhafen" % k2)


## T-170 (THE_BAR row 22): the arrival beat is data on the existing kinds: a move distance, a round ceiling, the
## siren's posts with a sound audio.json has, and a flash delay; nothing it names is a new system.
func test_arrival_beat() -> void:
	var a: Dictionary = cfg.get("arrival", {})
	assert_false(a.is_empty(), "an arrival block")
	assert_between(float(a.get("first_move_m", 0.0)), 1.0, 6.0, "a step or two onto the quay")
	assert_between(int(a.get("max_round", 0)), 1, 5, "only an opening")
	assert_gt((a.get("siren", {}) as Dictionary).get("points", []).size(), 0, "siren posts")
	assert_true(sounds.has(str(a["siren"].get("sound", ""))), "the siren's sound exists")
	assert_between(float(a.get("flash_after", 0.0)), 0.5, 5.0, "the lightning follows the siren")
	var amb: MapAmbience = autofree(MapAmbience.new())
	assert_true(amb.has_method(&"_kinds_setup_arrival"), "the kind has its setup block")


func test_beats_in_range() -> void:
	assert_eq(int(cfg["low_pass"]["round"]), 6, "Mosquitoes at round 6")
	assert_eq(int(cfg["lighthouse"]["off_round"]), 10, "the lighthouse goes dark at round 10")
	assert_eq(int(cfg["raid"]["round"]), 12, "the raid at round 12")
	assert_eq(int(cfg["cutter_slip"]["round"]), 15, "the cutter slips at round 15")
	assert_almost_eq(float(cfg["lighthouse"]["period_s"]), 9.0, 0.01, "a beam every 9 s")
	for k: String in ["low_pass", "raid", "cutter_slip"]:
		var r: int = int(cfg[k]["round"])
		assert_true(r >= 1 and r <= 30, "%s round in 1..30" % k)
	var b: Dictionary = cfg["raid"]["bombs"]
	assert_true(int(b["count"]) >= 3 and int(b["count"]) <= 12, "a bomb walk of 3..12")
	assert_eq(str(cfg["bell_tower"]["flag"]), "egg_lf_started", "the bell tolls on the egg's start flag")
	assert_eq(str(cfg["cutter_slip"]["spawn"]), "Surf_Cutter", "the cutter opens the systems worker's sea-stair spawn")
	assert_almost_eq(float(cfg["power_spectacle"]["drain_m"]), 0.4, 0.001, "the docks drain 0.4 m (visual)")


func test_intervals_are_ordered() -> void:
	var secs: Array = [cfg["gusts"], cfg["drips"], cfg["radio_chatter"], cfg["frozen_spray"], cfg["lighthouse"]["foghorn"],
		cfg["ships"]["guns"], cfg["ships"]["star_shells"]]
	for s: Dictionary in secs:
		var iv: Vector2 = MapAmbience.interval_range(s, 0.0)
		var iv2: Vector2 = MapAmbience.interval_range(s, 1.0)
		assert_true(iv.x > 0.0 and iv.x <= iv.y, "interval ordered %s" % str(s.get("interval")))
		assert_true(iv2.x > 0.0 and iv2.x <= iv2.y, "late interval ordered")


func test_every_sound_and_line_exists() -> void:
	var keys: Array[String] = []
	_collect_sounds(cfg, keys)
	assert_gt(keys.size(), 15, "the file names its sounds")
	for k: String in keys:
		assert_true(sounds.has(k), "audio.json has %s" % k)
	for l: Variant in cfg["radio_chatter"]["lines"]:
		assert_true(lines.has(str(l)), "lines.json has %s" % l)
		assert_eq(str(lines[str(l)]["speaker"]), "UBR")
		assert_true(str(lines[str(l)].get("speech", "")) != "", "%s is spoken in German (speech)" % l)
		assert_true(FileAccess.file_exists("res://gravelight/audio/vo/ubr/%s.ogg" % l), "%s baked" % l)
	assert_eq((cfg["radio_chatter"]["lines"] as Array).size(), 6, "six U-boat radio lines")
	assert_true(lines.has(str(cfg["raid"]["vo_line"])), "the Operator's raid line")
	assert_true(FileAccess.file_exists("res://gravelight/audio/vo/opr/OPR_RAID_M2_01.ogg"), "the raid line baked")


func _collect_sounds(d: Dictionary, out: Array[String]) -> void:
	for k: Variant in d.keys():
		var v: Variant = d[k]
		if v is Dictionary:
			_collect_sounds(v, out)
		elif v is String and (str(k) == "sound" or str(k).ends_with("_sound")) and str(v) != "":
			out.append(str(v))


func test_lighthouse_and_beats() -> void:
	assert_true(MapAmbience.lighthouse_lit_at(9, cfg))
	assert_false(MapAmbience.lighthouse_lit_at(10, cfg), "dark from round 10")
	assert_true(MapAmbience.beat_fires(12, cfg["raid"], false))
	assert_false(MapAmbience.beat_fires(12, cfg["raid"], true), "once per match")
	assert_false(MapAmbience.beat_fires(13, cfg["raid"], false), "only on its round")
	assert_false(MapAmbience.beat_fires(6, {}, false), "a block without a round never fires")
	assert_eq(MapAmbience.beat_round_of(6, 0), 6, "standalone: the match round")
	assert_eq(MapAmbience.beat_round_of(26, 20), 6, "campaign arrival on round 21: round 26 is the map's sixth")


func test_storm_follows_the_tide() -> void:
	var lo: float = MapAmbience.storm_level_for(&"low", cfg)
	var half: float = MapAmbience.storm_level_for(&"half", cfg)
	var high: float = MapAmbience.storm_level_for(&"high", cfg)
	var spring: float = MapAmbience.storm_level_for(&"spring", cfg)
	assert_true(lo < half and half < high and high < spring, "the storm worsens stage by stage")
	assert_almost_eq(spring, 1.0, 0.001)
	assert_eq(MapAmbience.storm_level_for(&"nonsense", cfg), 0.0)
	assert_almost_eq(MapAmbience.storm_level_for_y(-4.0, cfg), 0.0, 0.001, "low water: calm")
	assert_almost_eq(MapAmbience.storm_level_for_y(-1.0, cfg), 1.0, 0.001, "spring height: full storm")
	assert_true(MapAmbience.storm_level_for_y(-2.2, cfg) > MapAmbience.storm_level_for_y(-3.3, cfg))


func test_sweep_runs_from_the_pump_room() -> void:
	var sw: Dictionary = cfg["power_spectacle"]["sweep"]
	var near: float = MapAmbience.sweep_delay_for(Vector3(46, 0, 68), sw)
	var mid: float = MapAmbience.sweep_delay_for(Vector3(16, 0, 60), sw)
	var far: float = MapAmbience.sweep_delay_for(Vector3(-17, 0, 36), sw)
	assert_true(near < mid and mid < far, "dock by dock from the pump room to the quay (%.2f %.2f %.2f)" % [near, mid, far])
	assert_true(far <= float(sw["max_s"]) + 0.001, "capped")


func test_map00_file_unchanged() -> void:
	var m0: Dictionary = GLData.load_json("res://data/gravelight/map00_ambience.json")
	for k: String in ["bombers", "fighters", "plane_down", "searchlights", "artillery", "tracers", "flares", "machine_guns",
			"town", "gusts", "crows", "dog", "inn_sign", "shutter", "bell", "farm_light", "chimney", "cookoff", "pilot_line",
			"breath", "frost", "lamp_sway"]:
		assert_true(m0.has(k), "Map 0 keeps %s" % k)
	for k2: String in KINDS:
		assert_false(m0.has(k2), "Map 0 has no %s (the new kinds default to off)" % k2)
	assert_false(m0.has("needs_landscape"), "Map 0 still needs its Landscape (the default)")


func test_story_props_placed() -> void:
	var props: Array = GLData.load_json("res://data/gravelight/story_props.json").get("props", [])
	var intel: Array = GLData.load_json("res://data/gravelight/intel.json").get("intel", [])
	var ids: Dictionary = {}
	for r: Dictionary in intel:
		ids[str(r["id"])] = r
	var want: Array[String] = ["INT_M2_SAILOR_LETTER", "INT_M2_HALE_TELEGRAM", "INT_M2_PAYSLIP", "INT_M2_DRAWING", "INT_M2_RATION_BOOK"]
	for id: String in want:
		var found: Dictionary = {}
		for e: Dictionary in props:
			if str(e["id"]) == id:
				found = e
		assert_false(found.is_empty(), "%s placed" % id)
		assert_eq(str(found.get("map", "")), "2")
		assert_true(ids.has(id) and str(ids[id].get("placement", "")) == "fixed", "%s in the Archive, fixed" % id)
	for e2: Dictionary in props:
		if str(e2["id"]) == "INT_M2_SAILOR_LETTER":
			assert_eq(str(e2.get("hidden_until_flag", "")), "cutter_slipped", "the letter shows when the cutter slips")
