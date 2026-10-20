extends GutTest
## QuestManager step graph (EASTER_EGGS.md §1).

var _saved_path: String = ""


func before_all() -> void:
	# Quest rewards write to the profile; keep the real one untouched.
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_quest.json"
	ProfileSave.profile = ProfileSave.new_profile()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()


func test_map00_radio_is_valid() -> void:
	var def: Dictionary = GLData.load_json("res://data/gravelight/quests/map00_radio.json")
	assert_eq(QuestManager.validate(def), PackedStringArray())


func test_validate_catches_cycles_and_bad_requires() -> void:
	var cyc: Dictionary = {"id": "q", "steps": [
		{"id": "a", "type": "flag", "requires": ["b"], "params": {"flag": "x"}},
		{"id": "b", "type": "flag", "requires": ["a"], "params": {"flag": "y"}}]}
	assert_gt(QuestManager.validate(cyc).size(), 0)
	var bad: Dictionary = {"id": "q", "steps": [{"id": "a", "type": "nope", "requires": ["zzz"]}]}
	assert_eq(QuestManager.validate(bad).size(), 2)


func test_radio_quest_flow() -> void:
	QuestManager.clear()
	GameState.flags.clear()
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	assert_eq(QuestManager.status(qid, &"s1_notes"), "active")
	assert_eq(QuestManager.status(qid, &"s2_tune"), "locked")
	assert_eq(str(QuestManager.submit(&"radio_m0", "3.120")["result"]), "inactive", "can't tune before the notes")
	QuestManager.collect(&"radio_note", &"note_a")
	QuestManager.collect(&"radio_note", &"note_a")   # duplicates don't count
	QuestManager.collect(&"radio_note", &"note_b")
	assert_eq(QuestManager.status(qid, &"s1_notes"), "active")
	QuestManager.collect(&"radio_note", &"note_c")
	assert_eq(QuestManager.status(qid, &"s2_tune"), "active")
	assert_eq(str(QuestManager.submit(&"radio_m0", "3.120")["result"]), "ok")
	assert_eq(str(QuestManager.submit(&"radio_m0", "9.999")["result"]), "wrong")
	assert_eq(int(QuestManager.progress(qid, &"s2_tune")), 0, "wrong input resets the sequence")
	QuestManager.submit(&"radio_m0", "3.120")
	QuestManager.submit(&"radio_m0", "5.785")
	assert_eq(str(QuestManager.submit(&"radio_m0", "7.440")["result"]), "done")
	assert_true(QuestManager.is_complete(qid))
	assert_true(GameState.has_flag(&"map00_complete"))


func test_flag_step_completes_on_flag() -> void:
	QuestManager.clear()
	GameState.flags.clear()
	var path: String = "user://_test_quest.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "qf", "steps": [{"id": "a", "type": "flag", "params": {"flag": "power_on_test"}, "requires": []}]}))
	f.close()
	var qid: StringName = QuestManager.load_quest(path)
	assert_false(QuestManager.is_complete(qid))
	GameState.set_flag(&"power_on_test", true)
	assert_true(QuestManager.is_complete(qid))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	QuestManager.clear()
