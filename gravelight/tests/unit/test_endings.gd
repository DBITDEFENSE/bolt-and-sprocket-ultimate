extends GutTest
## The two endings' data and pure rules (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §11.5–§11.6, §12.11, T-113):
## the epilogue cards follow the flags and who is present, the stock shots add one per burned city, the writer
## rule holds on every card and credit line, the profile keeps the endings seen, and the speaker codes are right.

var data: Dictionary


func before_all() -> void:
	data = GLData.load_json("res://data/gravelight/cards_m4.json")


func test_cards_follow_flags_and_presence() -> void:
	var base: Array[String] = CancelEnding.card_list(data, ["dutch"], {}, false)
	assert_true(base.size() >= 7, "London, Boston, Dutch, Dee, Hale, Fasbender, Wittkamp, the Moon (%d)" % base.size())
	assert_string_contains(base[0], "violet snow")
	assert_true(base.has(str(data["cards"]["dutch"])))
	assert_false(base.has(str(data["cards"]["peg_resigned"])), "Peg absent: no Peg card")
	assert_false(base.has(str(data["cards"]["jakub"])), "no Jakub")
	var with: Array[String] = CancelEnding.card_list(data, ["peg", "wren"], {&"peg_delivered": true, &"bomb_new_york_hit": true, &"bomb_washington_saved": true, &"bomb_philadelphia_dud": true}, true)
	assert_true(with.has(str(data["cards"]["peg_delivered"])), "Peg delivered: her other card")
	assert_false(with.has(str(data["cards"]["peg_resigned"])))
	assert_true(with.has(str(data["cards"]["jakub"])))
	assert_true(with.has("The same, in New York."), "a burned city")
	assert_true(with.has("Washington slept through it."), "a saved city")
	assert_true(with.has(str(data["cards"]["city_dud"]) % "Philadelphia"), "a dud")
	assert_false(with.has(str(data["cards"]["dutch"])))


func test_dioramas_add_one_per_burned_city() -> void:
	var none: Array[Dictionary] = CancelEnding.diorama_list(data, {})
	assert_eq(none.size(), 5, "the five fixed shots")
	var two: Array[Dictionary] = CancelEnding.diorama_list(data, {&"bomb_boston_hit": true, &"bomb_new_york_hit": true, &"bomb_washington_saved": true})
	assert_eq(two.size(), 7, "plus Boston and New York")
	assert_eq(str(two[5]["id"]), "city")
	assert_string_contains(str(two[5]["caption"]), "Boston")


func test_writer_rule_on_every_card_and_credit() -> void:
	var texts: Array = []
	for v: Variant in (data["cards"] as Dictionary).values():
		texts.append(str(v))
	for c: Variant in data["credits"]:
		texts.append(str(c))
	for d: Variant in data["dioramas"]:
		texts.append(str((d as Dictionary).get("caption", "")))
	for t: Variant in texts:
		var low: String = str(t).to_lower()
		assert_false(low.contains("subscription") or low.contains("darkmatter"), "writer rule: " + str(t).left(40))
		assert_false(low.contains("sable") or low.contains("vantage"), "the Woman in Violet is never named: " + str(t).left(40))


func test_speaker_codes() -> void:
	assert_eq(CancelEnding.speaker_code(&"dutch"), "DUT")
	assert_eq(CancelEnding.speaker_code(&"peg"), "PEG")
	assert_eq(CancelEnding.speaker_code(&"deacon"), "DEA")
	assert_eq(CancelEnding.speaker_code(&"wren"), "WRN")
	assert_eq(CancelEnding.speaker_code(&"jakub"), "", "Jakub's hand, not the key")


func test_profile_keeps_the_endings_seen() -> void:
	var before: String = ProfileSave.path
	var prof: Dictionary = ProfileSave.profile
	ProfileSave.path = "user://_test_endings_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	assert_eq(ProfileSave.endings_seen(), [])
	ProfileSave.note_ending("kuendigung")
	ProfileSave.note_ending("kuendigung")
	ProfileSave.note_ending("renewed")
	assert_eq(ProfileSave.endings_seen(), ["kuendigung", "renewed"])
	ProfileSave.load_profile()
	assert_eq(ProfileSave.endings_seen(), ["kuendigung", "renewed"], "saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = before
	ProfileSave.profile = prof


func test_every_ending_line_is_written() -> void:
	for id: String in ["OPR_M4D_SURE_01", "OPR_M4D_LAST_01", "OPR_M4D_RENEW_01", "WIV_M4D_END_01", "WIV_M4D_RENEW_01", "DUT_M4D_CANCEL_01", "PEG_M4D_CANCEL_01",
			"DEA_M4D_CANCEL_01", "WRN_M4D_CANCEL_01", "WRN_M4D_END_01", "DUT_M4D_LASTWORD_01", "JAK_M4D_KEY_01", "DUT_M4D_RENEW_01", "PEG_M4D_RENEW_01",
			"DUT_TERMS_READ_1", "WRN_TERMS_READ_3", "OPR_M4D_TERMS_2", "WIV_M4D_ESCALATE_01"]:
		assert_true(GLVO.lines.has(id), id + " is in lines.json")
	assert_true((GLVO.rules.get("story_speakers", []) as Array).has("WIV"), "WIV is a story speaker")
	assert_eq(GLVO.line_map_of("WIV_M4D_END_01", GLVO.lines["WIV_M4D_END_01"], GLVO.rules), "map04d", "an Act IV line")
	var squad: Array = []
	for id2: Variant in GLVO.lines.keys():
		var rec: Dictionary = GLVO.lines[id2]
		if str(rec.get("speaker", "")) in ["DUT", "PEG", "DEA", "WRN", "JAK"] and str(id2).contains("M4D"):
			assert_false(str(rec.get("text", "")).to_lower().contains("subscription"), "the squad never says it: " + str(id2))
			squad.append(id2)
	assert_gt(squad.size(), 30)
