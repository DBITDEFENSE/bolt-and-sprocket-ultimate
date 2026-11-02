extends GutTest
## T-135: the map companions' data (companions.json): one per built map, its own pid apart from Jakub's and the
## squad's, a speaker with a voice and lines for every category it uses, a body (RemoteBody outfit + people.json
## row), a name tag; which ones appear on which map (found there, or carried in by the flag).

const CATS: PackedStringArray = ["CALL", "MEET", "JOIN_ARMED", "JOIN_UNARMED", "GIFT", "FALLEN"]


func _all() -> Dictionary:
	return MapCompanion.table().get("companions", {})


func test_one_companion_per_built_map() -> void:
	for m: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]:
		assert_eq(MapCompanion.ids_for_map(m, {}, MapCompanion.table()).size(), 1, m)


func test_pids_are_unique_and_clear_of_the_squad_and_jakub() -> void:
	var seen: Dictionary = {}
	for cid: Variant in _all().keys():
		var p: int = int((_all()[cid] as Dictionary).get("pid", 0))
		assert_gt(p, 4, "%s: not a squad pid" % cid)
		assert_ne(p, JakubCompanion.pid(), "%s: not Jakub's" % cid)
		assert_false(seen.has(p), "%s: own pid" % cid)
		seen[p] = true


func test_voices_lines_bodies_and_names() -> void:
	var cast: Dictionary = (GLData.load_json("res://data/gravelight/vo/voice_cast.json") as Dictionary).get("cast", {})
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var people: Dictionary = (GLData.load_json("res://data/gravelight/art/people.json") as Dictionary).get("people", {})
	for cid: Variant in _all().keys():
		var e: Dictionary = _all()[cid]
		var spk: String = str(e.get("speaker", ""))
		assert_true(cast.has(spk), "%s: %s has a voice" % [cid, spk])
		var cats: PackedStringArray = CATS.duplicate()
		if str(e.get("carry_flag", "")) != "":
			cats.append("ARRIVE")
		for c: String in cats:
			assert_true(lines.has("%s_COMP_%s_01" % [spk, c]), "%s: a %s line" % [cid, c])
		assert_true(RemoteBody.OUTFITS.has(StringName(str(cid))), "%s: an outfit" % cid)
		assert_true(people.has(str(cid)), "%s: a people.json body" % cid)
		assert_ne(Net.display_name(int(e["pid"])), "", "%s: a name tag" % cid)
		assert_true(GLVO.CHARACTER_SPEAKERS.has(StringName(str(cid))), "%s: speaks as itself" % cid)


func test_jette_is_found_in_act_one_and_carried_after() -> void:
	var t: Dictionary = MapCompanion.table()
	assert_eq(MapCompanion.ids_for_map("map04b_x", {}, t).size(), 0, "act II without her flag: nobody")
	assert_eq(MapCompanion.ids_for_map("map04b_x", {&"jette_with_you": true}, t), PackedStringArray(["jette"]))
	assert_eq(MapCompanion.ids_for_map("map04c_x", {"jette_with_you": true}, t), PackedStringArray(["jette"]))
	assert_eq(MapCompanion.ids_for_map("map04d_x", {&"jette_with_you": true}, t).size(), 0, "she stays behind")
	var keep: Dictionary = Campaign.carried_flags({&"jette_with_you": true, &"jette_gun": "kar98k"},
		GLData.table("campaign").get("carry_flags", []))
	assert_eq(keep.size(), 2, "the flag and her gun carry to the next act")


## UPDATE 10 section 9 (T-170; THE_BAR row 5): Hinnerk's stair scene (companions.json "scene"): a GLBus signal the
## bus has (the first flood), a category of his with a baked line (PET_LF_TRAPPED_01), a near distance, and the
## card's text; MapCompanion plays it once (play_scene) and only while he waits.
func test_petersen_scene() -> void:
	var e: Dictionary = MapCompanion.entry("petersen")
	var sc: Dictionary = e.get("scene", {})
	assert_false(sc.is_empty(), "he has a scene")
	assert_true(GLBus.has_signal(StringName(str(sc.get("signal", "")))), "its signal is on the bus: %s" % str(sc.get("signal", "")))
	assert_gt(float(sc.get("near_m", 0.0)), 5.0, "a survivor near enough triggers it too")
	assert_ne(str(sc.get("said", "")), "", "the card carries the scene")
	var ids: PackedStringArray = []
	for id: Variant in GLVO.lines.keys():
		var r: Dictionary = GLVO.lines[id]
		if str(r["speaker"]) == str(e["speaker"]) and str(r["category"]) == str(sc.get("category", "")):
			ids.append(str(id))
			assert_true(FileAccess.file_exists("res://gravelight/audio/vo/%s/%s.ogg" % [str(e["speaker"]).to_lower(), str(id)]), "%s is baked" % id)
	assert_true(ids.has("PET_LF_TRAPPED_01"), "the trapped line is his scene's")
	var c: MapCompanion = autofree(MapCompanion.new())
	c.cfg = e
	assert_false(c.play_scene(), "no body yet: nothing plays, and it stays unplayed")
	assert_false(c._scene_done)
