extends GutTest
## M4 quest logic: Requiem for Kaltenbrunn data, seeding, new step types (EASTER_EGGS.md §1–2, §5).

const REQ: String = "res://data/gravelight/quests/map01_requiem.json"
var _saved_path: String = ""


func before_all() -> void:
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_m4.json"


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()
	QuestManager.clear()


func before_each() -> void:
	QuestManager.clear()
	GameState.flags.clear()


func test_quest_files_validate() -> void:
	for path: String in [REQ, "res://data/gravelight/quests/map01_song.json", "res://data/gravelight/quests/map01_wren_tag.json"]:
		assert_eq(QuestManager.validate(GLData.load_json(path)), PackedStringArray(), path)


func test_requiem_has_ten_steps_and_rewards() -> void:
	var def: Dictionary = GLData.load_json(REQ)
	var ids: Array = []
	for s: Dictionary in def["steps"]:
		ids.append(str(s["id"]))
	for want: String in ["s1_vault", "s2a_radios", "s2b_switchboard", "s3_build", "s4_key", "s5_reliquary", "s6_bells",
			"s7_drummer", "s8a_place", "s8b_charge", "s9_heartstorm", "s10_ending"]:
		assert_true(ids.has(want), want)
	assert_gt((def["on_complete"] as Array).size(), 4)


func test_seeding_is_deterministic() -> void:
	var spec: Dictionary = GLData.load_json(REQ)["random"]
	var a: Dictionary = QuestManager.roll_random(spec, 1234, "map01_requiem")
	var b: Dictionary = QuestManager.roll_random(spec, 1234, "map01_requiem")
	assert_eq(a, b)
	assert_eq((a["code"] as String).length(), 6)
	assert_eq((a["melody"] as Array).size(), 4)
	assert_eq((a["radios"] as Dictionary).size(), 3)
	assert_eq(a["radios"]["3_lab"], "radio_lab_intake")
	var differs: bool = false
	for s: int in [1, 2, 3, 4, 5, 6]:
		if QuestManager.roll_random(spec, s, "map01_requiem") != a:
			differs = true
	assert_true(differs, "different seeds give different rolls")


func test_each_system_has_its_own_rng() -> void:
	# Changing one key's spec must not shift another key's roll.
	var spec: Dictionary = GLData.load_json(REQ)["random"]
	var full: Dictionary = QuestManager.roll_random(spec, 77, "q")
	var only_code: Dictionary = QuestManager.roll_random({"code": spec["code"]}, 77, "q")
	assert_eq(full["code"], only_code["code"])


func test_bell_order_wrong_input_resets() -> void:
	QuestManager.match_seed = 99
	var qid: StringName = QuestManager.load_quest(REQ)
	QuestManager.debug_skipto(qid, &"s6_bells")
	assert_eq(QuestManager.status(qid, &"s6_bells"), "active")
	var melody: Array = QuestManager.sequence_inputs(qid, &"s6_bells")
	assert_eq(str(QuestManager.submit(&"four_bells", str(melody[0]))["result"]), "ok")
	var wrong: String = str(melody[2])
	assert_eq(str(QuestManager.submit(&"four_bells", wrong)["result"]), "wrong")
	assert_eq(int(QuestManager.progress(qid, &"s6_bells")), 0)
	for n: Variant in melody:
		QuestManager.submit(&"four_bells", str(n))
	assert_true(QuestManager.is_step_done(qid, &"s6_bells"))
	assert_eq(QuestManager.status(qid, &"s7_drummer"), "active")


func test_switchboard_code_matches_radio_lines() -> void:
	QuestManager.match_seed = 5
	var qid: StringName = QuestManager.load_quest(REQ)
	var code: String = str(QuestManager.random_value(qid, "code"))
	var line: String = str(GLVO.lines["FAS_M1_CODE1_01"]["text"])
	assert_true(line.contains("%s %s" % [code[0], code[1]]), "fragment 1 speaks the first pair")
	assert_false(line.contains("%d1%"))


func test_build_step_completes_on_buildable() -> void:
	var qid: StringName = QuestManager.load_quest(REQ)
	assert_eq(QuestManager.status(qid, &"s3_build"), "active")
	GLBus.buildable_completed.emit(&"totenglocke", 1)
	assert_true(QuestManager.is_step_done(qid, &"s3_build"))


func test_interact_step_needs_item() -> void:
	var qid: StringName = QuestManager.load_quest(REQ)
	QuestManager.debug_skipto(qid, &"s5_reliquary")
	QuestManager.take_item(&"overseers_key")
	assert_false(QuestManager.interact(&"altar", 1))
	QuestManager.give_item(&"overseers_key", 1)
	assert_true(QuestManager.interact(&"altar", 1))
	assert_true(QuestManager.has_item(&"music_box"))


func test_chase_completes_on_item_pickup() -> void:
	var qid: StringName = QuestManager.load_quest(REQ)
	QuestManager.debug_skipto(qid, &"s7_drummer")
	assert_eq(QuestManager.is_chase_armed(&"drummer"), [qid, &"s7_drummer"])
	QuestManager.give_item(&"nachtglas_shard", 1)
	assert_true(QuestManager.is_step_done(qid, &"s7_drummer"))


func test_kill_count_radius_and_weapon_filter() -> void:
	var qid: StringName = QuestManager.load_quest(REQ)
	QuestManager.debug_skipto(qid, &"s8b_charge")
	QuestManager.debug_complete(qid, &"s8a_place")
	var heart: Vector3 = Vector3(34, -18, 116)
	GLBus.enemy_killed.emit(&"ganger", &"torso", &"mp40", 1)
	GLBus.enemy_killed_at.emit(&"ganger", heart, 1)
	assert_eq(QuestManager.progress(qid, &"s8b_charge"), null, "wrong weapon doesn't count")
	GLBus.enemy_killed.emit(&"ganger", &"torso", &"totenglocke", 1)
	GLBus.enemy_killed_at.emit(&"ganger", heart + Vector3(40, 0, 0), 1)
	assert_eq(QuestManager.progress(qid, &"s8b_charge"), null, "too far from the heart doesn't count")
	for i: int in 30:
		GLBus.enemy_killed.emit(&"ganger", &"torso", &"totenglocke_up", 1)
		GLBus.enemy_killed_at.emit(&"ganger", heart + Vector3(3, 0, 0), 1)
	assert_true(QuestManager.is_step_done(qid, &"s8b_charge"))


func test_every_vo_id_in_quests_exists() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for path: String in [REQ, "res://data/gravelight/quests/map01_song.json", "res://data/gravelight/quests/map01_wren_tag.json"]:
		for id: String in QuestManager.referenced_vo(GLData.load_json(path)):
			assert_true(lines.has(id), "%s references missing VO %s" % [path, id])
	for id2: String in ["FAS_M1_CODE1_01", "FAS_M1_CODE2_01", "FAS_M1_CODE3_01", "OPR_QUEST_S4_BELL_LIT_01", "OPR_QUEST_S7_START_01",
			"REI_CYL1_01", "REI_CYL2_01", "REI_CYL3_01", "TAG_KB4471_01", "LSL_REC_HIDE_01", "OPR_QUEST_S9_END_01",
			"OPR_QUEST_S10_01", "REI_END_01", "REI_END_02", "FAS_M1_ENDING_01"]:
		assert_true(lines.has(id2), "code references missing VO " + id2)


func test_totenglocke_data_and_falloff() -> void:
	var w: Dictionary = GLData.table("weapons")
	assert_true(w["weapons"].has("totenglocke"))
	assert_true(w["upgraded"].has("totenglocke_up"))
	var b: Dictionary = w["weapons"]["totenglocke"]["bell"]
	assert_almost_eq(WeaponHolder.bell_damage(b, 3000.0, 3.0), 3000.0, 0.1)
	assert_almost_eq(WeaponHolder.bell_damage(b, 3000.0, 8.0), 1800.0, 0.1)
	var up: Dictionary = w["upgraded"]["totenglocke_up"]["bell"]
	assert_gt(float(up["range"]), float(b["range"]))
