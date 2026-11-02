extends GutTest
## UPDATE 10 s6 item 9 (T-162): the citations (achievements). Every quest in data/gravelight/quests has one, the work
## order's list is all there, the guarded ones follow their guard, each is earned once with a toast, the map-bound
## events respect the map, and the Service Record rows list them.

var _saved_path: String = ""
var _toasts: Array = []


func before_all() -> void:
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_cit_%d.json" % OS.get_process_id()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()


func before_each() -> void:
	ProfileSave.profile = ProfileSave.new_profile()
	_toasts.clear()
	if not GLBus.bonus_awarded.is_connected(_on_bonus):
		GLBus.bonus_awarded.connect(_on_bonus)


func after_each() -> void:
	if GLBus.bonus_awarded.is_connected(_on_bonus):
		GLBus.bonus_awarded.disconnect(_on_bonus)


func _on_bonus(_p: int, kind: StringName, _amount: int, text: String) -> void:
	if kind == &"citation":
		_toasts.append(text)


func test_the_work_orders_list_is_there() -> void:
	for id: String in ["wing_walk", "spring_tide", "sent_to_orbit", "dust_walker", "raid_survivor", "beat_paul", "beat_hafenwaechter", "egg_map02_letzte_fahrt"]:
		assert_false(Citations.def_for(id).is_empty(), "citation %s is defined" % id)
	var ids: Dictionary = {}
	for c: Dictionary in Citations.all_defs():
		assert_false(ids.has(c["id"]), "%s is unique" % c["id"])
		ids[c["id"]] = true
		assert_ne(str(c.get("name", "")), "", "%s has a name" % c["id"])
		assert_ne(str(c.get("desc", "")), "", "%s has a task" % c["id"])


func test_every_quest_maps_to_a_citation() -> void:
	var dir: String = "res://data/gravelight/quests/"
	var n: int = 0
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var q: Dictionary = GLData.load_json(dir + f)
		var qid: String = str(q.get("id", f.get_basename()))
		var hit: bool = false
		for c: Dictionary in Citations.all_defs():
			if str(c.get("event", "")) == "quest" and str(c.get("quest", "")) == qid:
				hit = true
		assert_true(hit, "quest %s has a citation" % qid)
		n += 1
	assert_gt(n, 8, "the quests were found")


func test_every_homage_boss_has_a_citation() -> void:
	var bosses: Dictionary = {}
	for c: Dictionary in Citations.all_defs():
		if str(c.get("event", "")) == "boss_killed":
			bosses[str(c["enemy"])] = true
	for id: String in ["paul", "the_slender"]:
		assert_true(bosses.has(id), "%s has a citation" % id)
		var found: bool = false
		for f: String in DirAccess.get_files_at("res://gravelight/enemies/homage/"):
			if f.ends_with(".gd") and FileAccess.get_file_as_string("res://gravelight/enemies/homage/" + f).contains("enemy_id = &\"%s\"" % id):
				found = true
		assert_true(found, "%s is a real enemy id" % id)


func test_guards_follow_their_files_and_signals() -> void:
	var egg: Dictionary = Citations.def_for("egg_map02_letzte_fahrt")
	var landed: bool = FileAccess.file_exists("res://data/gravelight/quests/map02_letzte_fahrt.json")
	assert_eq(Citations.available(egg), landed, "Letzte Fahrt is listed only once its quest file exists")
	var st: Dictionary = Citations.def_for("spring_tide")
	assert_eq(Citations.available(st), GLBus.has_signal(&"spring_tide"), "the spring tide waits for its signal")
	var listed: Array = Citations.defs().map(func(c: Dictionary) -> String: return str(c["id"]))
	assert_eq(listed.has("egg_map02_letzte_fahrt"), landed)


func test_earned_once_with_a_toast() -> void:
	assert_false(Citations.earned("beat_paul"))
	var got: PackedStringArray = Citations.fire("boss_killed", {"map": "map01_kaltenbrunn", "enemy": "paul"})
	assert_eq(got, PackedStringArray(["beat_paul"]))
	assert_true(Citations.earned("beat_paul"))
	assert_eq(_toasts.size(), 1, "one HUD toast")
	assert_string_contains(str(_toasts[0]), "Beat PAUL")
	assert_eq(Citations.fire("boss_killed", {"map": "map01_kaltenbrunn", "enemy": "paul"}).size(), 0, "not twice")
	assert_eq(_toasts.size(), 1, "no second toast")
	assert_eq(Citations.fire("boss_killed", {"enemy": "the_slender"}), PackedStringArray(["beat_hafenwaechter"]), "a different boss, a different citation")
	assert_true(bool((ProfileSave.profile["citations"] as Dictionary)["beat_paul"]), "it is in the profile")


func test_events_respect_the_map() -> void:
	assert_eq(Citations.fire("special_survived", {"map": "map04c_groomlake"}), PackedStringArray(["dust_walker"]))
	assert_eq(Citations.fire("special_survived", {"map": "map04a_thalbach"}), PackedStringArray(["raid_survivor"]))
	assert_eq(Citations.fire("special_survived", {"map": "map00_crossroads"}).size(), 0, "no other map's special round counts")
	assert_eq(Citations.fire("wing_walk", {"map": "map04a_thalbach"}).size(), 0, "the wing walk is Act II's")
	assert_eq(Citations.fire("wing_walk", {"map": "map04b_kranich"}), PackedStringArray(["wing_walk"]))


func test_orbit_needs_its_count() -> void:
	assert_eq(Citations.fire("orbit", {"map": "map04d_mondlicht", "count": 4}).size(), 0, "4 is not enough")
	assert_eq(Citations.fire("orbit", {"map": "map04d_mondlicht", "count": 5}), PackedStringArray(["sent_to_orbit"]))


func test_an_egg_counts_wherever_it_completes() -> void:
	# the Kuendigung egg belongs to Act I's list but completes on Mondlicht
	assert_eq(Citations.fire("quest", {"map": "map04d_mondlicht", "quest": "map04_kuendigung"}), PackedStringArray(["egg_map04_kuendigung"]))


func test_the_service_record_rows() -> void:
	var rows: Array = Citations.rows()
	assert_eq(rows.size(), Citations.defs().size())
	Citations.fire("boss_killed", {"enemy": "paul"})
	var earned_rows: int = 0
	for r: Dictionary in Citations.rows():
		assert_true(r.has("name") and r.has("desc") and r.has("earned"))
		if bool(r["earned"]):
			earned_rows += 1
	assert_eq(earned_rows, 1)
	assert_eq(Citations.count_earned(), 1)


func test_the_archive_has_an_entry_for_each_new_boss_and_egg() -> void:
	var ids: Array = ProfileSave.intel_rows().map(func(r: Dictionary) -> String: return str(r["id"]))
	for k: String in ["ARC_HB_SLENDER", "ARC_HB_PAUL", "INT_HB_04"]:
		assert_true(ids.has(k), "%s is in the Archive" % k)
