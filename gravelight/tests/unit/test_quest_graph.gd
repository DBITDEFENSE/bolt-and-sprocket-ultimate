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


# ---------------------------------------------------------------- T-086: the egg tells its story (beat actions)

func _beat_cats() -> Array:
	var out: Array = []
	for b: Dictionary in GLVO.pending_story_beats():
		out.append(b["cat"])
	return out


func test_map00_radio_beats_fire_in_order() -> void:
	QuestManager.clear()
	GameState.flags.clear()
	var map_was: StringName = GameState.map_id
	GameState.map_id = &"map00_crossroads"   # (the Map 0 lines only draw on Map 0; an earlier test may have left Kaltenbrunn set)
	GLVO.always_pass_chance = true
	GLVO.reset_match()
	var qid: StringName = QuestManager.load_quest("res://data/gravelight/quests/map00_radio.json")
	# the setup beat waits for the round-2 radio call (on_vo), it does not fire at load
	var waiting: int = 0
	for w: Dictionary in QuestManager.pending_beats():
		if str(w.get("on_vo", "")) == "FAS_M0_R1_01":
			waiting += 1
	assert_eq(waiting, 2, "the squad's two-line reaction waits for Glasmacher's first call")
	assert_eq(_beat_cats(), [], "nothing said yet")
	GLBus.vo_line_started.emit(&"FAS_M0_R1_01", &"FAS", "Glasmacher calling", 4.0)
	QuestManager.advance(12.0)
	assert_eq(_beat_cats(), ["M0_EGG_HEARD", "M0_EGG_LOOK"], "after the call: 'that's us', then 'look for paper'")
	GLVO.reset_match()
	# progress beats: the one who took the note reads it, someone answers on the first and second note only
	QuestManager.collect(&"radio_note", &"note_a", 1)
	assert_eq(_beat_cats(), ["M0_EGG_NOTE"], "the note's words at once")
	QuestManager.advance(4.5)
	assert_eq(_beat_cats(), ["M0_EGG_NOTE", "M0_EGG_NOTE_FIRST"], "someone answers a beat later")
	assert_eq(GLVO.pending_story_beats()[0]["pid"], 1, "the note's words go to the one who took it")
	GLVO.reset_match()
	QuestManager.collect(&"radio_note", &"note_b", 1)
	QuestManager.advance(4.5)
	assert_eq(_beat_cats(), ["M0_EGG_NOTE", "M0_EGG_NOTE_TWO"])
	GLVO.reset_match()
	assert_false(GLVO.is_retired(&"FAS_M0_R7_01"))
	QuestManager.collect(&"radio_note", &"note_c", 1)
	# payoff of the notes = the setup of the radio: Fasbender's standing call, then two survivors
	assert_true(GLVO.is_retired(&"FAS_M0_R7_01"), "'find the notes' is retired once they are found")
	assert_eq(GLVO.current_line(&"story"), &"FAS_M0_NOTES_01", "Glasmacher: lowest first")
	QuestManager.advance(8.0)
	assert_eq(_beat_cats(), ["M0_EGG_NOTE", "M0_EGG_NOTES_DONE", "M0_EGG_NOTES_DONE"], "no 'two of three' after the third: the step was done")
	GLVO.reset_match()
	# the reset beat
	QuestManager.submit(&"radio_m0", "3.120")
	QuestManager.submit(&"radio_m0", "9.999")
	assert_true(String(GLVO.current_line(&"story")).begins_with("FAS_M0_WRONG"), "Fasbender: start again (%s)" % GLVO.current_line(&"story"))
	QuestManager.advance(1.0)
	assert_true(_beat_cats().has("M0_EGG_WRONG"))
	GLVO.reset_match()
	# the locks: the squad answers Fasbender's own lines (on_vo), not the click of the dial
	QuestManager.submit(&"radio_m0", "3.120")
	assert_eq(_beat_cats(), [], "nothing until FREQ1 has played")
	GLBus.vo_line_started.emit(&"FAS_M0_FREQ1_01", &"FAS", "", 6.0)
	QuestManager.advance(8.0)
	assert_eq(_beat_cats(), ["M0_EGG_LOCK1"])
	GLVO.reset_match()
	QuestManager.submit(&"radio_m0", "5.785")
	QuestManager.submit(&"radio_m0", "7.440")
	assert_true(QuestManager.is_complete(qid))
	assert_true(GLVO.is_retired(&"FAS_M0_R1_01"), "Glasmacher stops calling 'anyone?' once he has been answered")
	# the payoff chain: FREQ3 -> the Operator cuts in -> the squad -> the Ledger's credit -> every tonic
	GLBus.vo_line_started.emit(&"FAS_M0_FREQ3_01", &"FAS", "", 10.0)
	QuestManager.advance(13.0)
	assert_eq(GLVO.current_line(&"story"), &"OPR_M0_FIRST_01", "the Operator, faintly, for the first time")
	GLBus.vo_line_started.emit(&"OPR_M0_FIRST_01", &"OPR", "", 4.0)
	QuestManager.advance(14.0)   # (the line's 4 s plus 8 s for the second speaker)
	assert_eq(_beat_cats(), ["M0_EGG_DONE", "M0_EGG_DONE"], "two survivors on what it means")
	var owned_before: int = PerkManager.owned(1).size()
	QuestManager.advance(9.0)
	GLBus.vo_line_started.emit(&"OPR_M0_CREDIT_01", &"OPR", "", 5.0)
	QuestManager.advance(7.0)
	assert_eq(PerkManager.owned(1).size(), (GLData.table("perks")["perks"] as Dictionary).size(), "every tonic, slot-free, on the Ledger's credit (had %d)" % owned_before)
	assert_true(_beat_cats().has("M0_EGG_TONICS"))
	GLVO.always_pass_chance = false
	GLVO.reset_match()
	GameState.map_id = map_was
	for p: Variant in PerkManager.owned(1).duplicate():
		PerkManager.remove(1, StringName(str(p)))
	QuestManager.clear()


func test_beat_filters_at_n_and_while_active() -> void:
	QuestManager.clear()
	GameState.flags.clear()
	var path: String = "user://_test_quest_beats.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "qb", "steps": [
		{"id": "a", "type": "collect", "params": {"tag": "t", "count": 2}, "requires": [],
			"on_item": [{"at_n": 2, "flag": "second_item"}, {"at_n": 1, "flag": "first_item"}],
			"on_start": [{"after": 5.0, "while_active": "a", "flag": "late_flag"}]}]}))
	f.close()
	var qid: StringName = QuestManager.load_quest(path)
	assert_eq(QuestManager.pending_beats().size(), 1, "the timed action waits")
	QuestManager.collect(&"t", &"x")
	assert_true(GameState.has_flag(&"first_item"))
	assert_false(GameState.has_flag(&"second_item"), "at_n 2 not yet")
	QuestManager.collect(&"t", &"y")
	assert_true(GameState.has_flag(&"second_item"))
	assert_true(QuestManager.is_complete(qid))
	QuestManager.advance(6.0)
	assert_false(GameState.has_flag(&"late_flag"), "while_active: the step finished first, the beat is dropped")
	assert_eq(QuestManager.pending_beats().size(), 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	QuestManager.clear()
