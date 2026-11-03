extends GutTest
## Letzte Fahrt, findable (UPDATE 10 s10, DECISIONS T-173): the Operator's pointers (LetzteFahrtGuide.pick), their
## lines and audio, the quest's next-step banners, the pause OBJECTIVES' current lines after the power, and the quest's
## first step needing nothing but a coffin (live from the match's start). The runtime half is smoke_lf_start.

const QUEST_PATH: String = "res://data/gravelight/quests/map02_letzte_fahrt.json"

var def: Dictionary


func before_all() -> void:
	def = GLData.load_json(QUEST_PATH)


func _step(sid: String) -> Dictionary:
	for s: Variant in def["steps"]:
		if str((s as Dictionary)["id"]) == sid:
			return s
	return {}


func _states(active: Array, progress: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for n: Variant in LetzteFahrtGuide.NUDGES:
		var sid: String = str((n as Dictionary)["step"])
		out[sid] = {"active": active.has(sid), "progress": int(progress.get(sid, 0))}
	return out


func test_the_first_step_is_open_from_the_start() -> void:
	var s0a: Dictionary = _step("s0a_load")
	assert_eq((s0a.get("requires", []) as Array).size(), 0, "s0a_load requires nothing: it is live from round 1")
	assert_eq(str(s0a["params"].get("flag", "")), "ballast_loaded", "and a coffin on the crane (BallastHook's flag) finishes it")
	assert_eq(_step("s0_power")["requires"], ["s0a_load"], "the power follows it")


func test_round_one_is_quiet_and_round_two_names_the_crane() -> void:
	var st: Dictionary = _states(["s0a_load", "s3_log", "s4_parts"])
	assert_eq(LetzteFahrtGuide.pick(1, {}, st), "", "round 1: the opening is the match's own")
	assert_eq(LetzteFahrtGuide.pick(2, {}, st), "OPR_LF_HINT_HOOK_01")
	assert_eq(LetzteFahrtGuide.pick(3, {"OPR_LF_HINT_HOOK_01": true}, st), "", "once per match, and the second waits for round 4")
	assert_eq(LetzteFahrtGuide.pick(4, {"OPR_LF_HINT_HOOK_01": true}, st), "OPR_LF_HINT_HOOK_02")
	assert_eq(LetzteFahrtGuide.pick(5, {"OPR_LF_HINT_HOOK_01": true, "OPR_LF_HINT_HOOK_02": true}, st), "OPR_LF_HINT_LOG_01",
		"the log pages from round 5 (s3 needs no power)")


func test_after_the_power_the_radios_then_the_stairs() -> void:
	var said: Dictionary = {"OPR_LF_HINT_HOOK_01": true}
	var st: Dictionary = _states(["s1_ballast", "s2a_radios", "s3_log", "s4_parts"])
	assert_eq(LetzteFahrtGuide.pick(3, said, st), "OPR_LF_HINT_RADIO_01", "the hook is done: the radios")
	said["OPR_LF_HINT_RADIO_01"] = true
	assert_eq(LetzteFahrtGuide.pick(4, said, st), "OPR_LF_HINT_STAIRS_01")
	var heard: Dictionary = _states(["s1_ballast", "s2a_radios"], {"s2a_radios": 1})
	assert_eq(LetzteFahrtGuide.pick(4, {}, heard), "OPR_LF_HINT_STAIRS_01", "a radio already heard: no radio pointer")
	assert_eq(LetzteFahrtGuide.pick(9, {}, _states([])), "", "nothing active, nothing said")


func test_pointer_lines_exist_are_map_two_and_baked() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var files: Dictionary = GLData.load_json("res://data/gravelight/vo/audio_manifest.json").get("files", {})
	for n: Variant in LetzteFahrtGuide.NUDGES:
		var id: String = str((n as Dictionary)["id"])
		assert_true(lines.has(id), "%s is written" % id)
		assert_eq(str((lines.get(id, {}) as Dictionary).get("speaker", "")), "OPR", "%s is the Operator's" % id)
		assert_eq(GLVO.line_map_of(id, lines.get(id, {}), GLVO.rules), "map02", "%s plays only on Totenhafen" % id)
		assert_true(files.has(id), "%s is baked" % id)
		var step: Dictionary = _step(str((n as Dictionary)["step"]))
		assert_false(step.is_empty(), "%s points at a real step" % id)


func test_every_sight_target_is_a_placed_node() -> void:
	var m: Dictionary = GLData.load_json("res://data/gravelight/map02.json")
	var radios: Dictionary = (m["letzte_fahrt"] as Dictionary).get("radios", {})
	for s: Variant in LetzteFahrtGuide.SIGHTS:
		var node_name: String = str((s as Array)[0])
		if node_name.begins_with("Radio_"):
			assert_true(radios.has(node_name.trim_prefix("Radio_")), "%s is a radio in map02.json" % node_name)
		assert_ne(str((s as Array)[1]), "", "%s has a note" % node_name)


func test_steps_name_what_comes_next() -> void:
	# every step a player finishes by hand, before the boat, leaves a banner that names the next thing
	for sid: String in ["s0a_load", "s0_power", "s1_ballast", "s2a_radios", "s2_cipher", "s3_log", "s4_parts", "s5_diesels",
			"s6_boss", "s7_key"]:
		var named: bool = false
		for a: Variant in _step(sid).get("on_complete", []):
			if (a as Dictionary).has("banner"):
				named = true
		assert_true(named, "%s leaves a banner" % sid)
	var on_start: Array = _step("s5a_injector").get("on_start", [])
	assert_true(on_start.size() == 1 and str((on_start[0] as Dictionary).get("banner", "")).contains("lathe"),
		"the diesels' three repairs are named when they open")
	assert_eq(QuestManager.validate(def), PackedStringArray(), "the quest still validates")
	assert_true(QuestManager.client_subset({"banner": "x", "banner_s": 5.5}).has("banner_s"), "co-op clients keep the banner's time")


func test_objectives_point_at_the_radios_after_the_power() -> void:
	var rules: Array = ObjectiveLog.load_data()["maps"]["map02_totenhafen"]["current"]
	var q_before: Dictionary = {"map02_letzte_fahrt": {"steps": [{"id": "s2a_radios", "status": "active"}, {"id": "s2_cipher", "status": "locked"}]}}
	var snap: Dictionary = {"power": true, "flags": {"ballast_loaded": 1}, "zones": ["D_PENHALL", "F_LOWERPENS"], "quests": q_before}
	assert_string_contains(str(ObjectiveLog.current_objective(snap, rules)["title"]), "radios")
	snap["quests"] = {"map02_letzte_fahrt": {"steps": [{"id": "s2a_radios", "status": "complete"}, {"id": "s2_cipher", "status": "active"}]}}
	assert_string_contains(str(ObjectiveLog.current_objective(snap, rules)["title"]), "rotor machine")
	snap["quests"] = {"map02_letzte_fahrt": {"steps": [{"id": "s2a_radios", "status": "complete"}, {"id": "s2_cipher", "status": "complete"}]}}
	assert_eq(str(ObjectiveLog.current_objective(snap, rules)["title"]), "Survive.")
	snap["power"] = false
	snap["flags"] = {}
	snap["zones"] = ["D_PENHALL"]
	assert_string_contains(str(ObjectiveLog.current_objective(snap, rules)["title"]), "crane hook", "before the power: the hook")
