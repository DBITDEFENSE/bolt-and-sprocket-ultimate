extends GutTest
## M0 core: title constant, data loading, ported story integrity, save migrations, unlock flow, VO lookup.


func test_game_title_is_one_constant() -> void:
	assert_eq(Game.GAME_TITLE, "TERMS & CONDITIONS")


func test_original_config_extracted() -> void:
	var cfg: Variant = Data.table("bs_source/CONFIG")
	assert_true(cfg is Dictionary, "CONFIG table loads")
	for key: String in ["move", "jump", "hover", "dash", "slam", "melee"]:
		assert_true((cfg as Dictionary).has(key), "CONFIG.%s present (movement tuning to port)" % key)


func test_story_lines_have_ids_and_text() -> void:
	var idx: Dictionary = Data.table("bs/story/lines_index")
	assert_gt(idx.size(), 450, "all ported lines indexed")
	for id: String in idx.keys():
		assert_ne(str((idx[id] as Dictionary).get("text", "")), "", "%s has text" % id)


func test_every_speaker_is_defined() -> void:
	var speakers: Dictionary = (Data.table("bs/story/speakers") as Dictionary)["speakers"]
	var generic: PackedStringArray = ["memo", "notice", "pa", "dent", "model_m", "scuff", "toasty"]
	var cs: Dictionary = Data.table("bs/story/cutscenes")
	for id: String in cs.keys():
		for st: Variant in (cs[id] as Dictionary)["steps"]:
			var s: Dictionary = st
			if s.get("type") == "line":
				var who: String = str(s["who"])
				assert_true(speakers.has(who) or who in generic, "speaker '%s' in %s is defined" % [who, id])


func test_quest_ids_unique() -> void:
	var seen: Dictionary = {}
	for q: Variant in Data.table("bs/story/quests"):
		var id: String = str((q as Dictionary)["id"])
		assert_false(seen.has(id), "quest id %s is unique" % id)
		seen[id] = true
	assert_eq(seen.size(), 19)


func test_memo_count() -> void:
	assert_eq(((Data.table("bs/story/memos") as Dictionary)["memos"] as Array).size(), 40, "35 original memos + 5 Darkmatter memos")


func test_save_blank_has_three_tracks_and_archive() -> void:
	var b: Dictionary = SaveProfile.blank()
	for k: String in ["bs", "gravelight", "fineprint", "archive", "unlocks"]:
		assert_true(b.has(k), "profile has %s" % k)
	assert_eq(int(b["version"]), SaveProfile.VERSION)


func test_save_migrates_v0() -> void:
	var old: Dictionary = {"bolts": 1234, "memos": ["memo.01", "memo.07"]}
	var d: Dictionary = SaveProfile.migrate(old)
	assert_eq(int(d["version"]), SaveProfile.VERSION)
	assert_eq(int(d["bs"]["bolts"]), 1234)
	assert_eq((d["bs"]["memos"] as Array).size(), 2)
	assert_true(d.has("gravelight"))


func test_save_fills_new_keys_without_losing_data() -> void:
	var d: Dictionary = {"version": SaveProfile.VERSION, "bs": {"bolts": 50}, "unlocks": ["bs_ending"]}
	var m: Dictionary = SaveProfile.migrate(d)
	assert_eq(int(m["bs"]["bolts"]), 50)
	assert_true((m["bs"] as Dictionary).has("gold_bolts"))
	assert_true("bs_ending" in (m["unlocks"] as Array))


func test_unlock_flow() -> void:
	var rules: Dictionary = Data.table("unlocks")
	assert_true(Unlocks.is_open(rules, [], "bs_campaign"))
	assert_true(Unlocks.is_open(rules, [], "gl_map00"))
	assert_false(Unlocks.is_open(rules, [], "fp_ch1"))
	assert_true(Unlocks.is_open(rules, ["bs_ending"], "fp_ch1"))
	# Ch. 2-3: the Map 1 main egg OR round 20 on Map 1, so non-egg players still progress
	assert_true(Unlocks.is_open(rules, ["gl_map01_round20"], "fp_ch2"))
	assert_true(Unlocks.is_open(rules, ["gl_map01_main_egg"], "fp_ch3"))
	assert_false(Unlocks.is_open(rules, ["fp_ch1_done", "fp_ch2_done"], "fp_ch4"))
	assert_true(Unlocks.is_open(rules, ["fp_ch1_done", "fp_ch2_done", "fp_ch3_done"], "fp_ch4"))
	assert_true(Unlocks.is_open(rules, ["fp_ch5_done"], "gl_char_bolt"))


func test_vo_lookup_and_markup() -> void:
	assert_true(VOManager.has_line("cs.l3_brick.04"))
	assert_string_contains(str(VOManager.line("cs.l3_brick.04")["text"]), "friendship")
	assert_eq(VOManager.strip_markup("OmniScrap™ *sighs* deals"), "OmniScrap  deals")
	var p: Dictionary = VOManager.profile_for("sprocket")
	assert_almost_eq(float(p["pitch"]), 1.6, 0.001)
	assert_true(VOManager.profile_for("rusty").has("pitch"), "NPCs fall back to the generic npc voices")


func test_vo_play_is_silent_headless_but_subtitles() -> void:
	watch_signals(EventBus)
	assert_true(VOManager.play("cs.intro.02"))
	assert_signal_emitted(EventBus, "subtitle")
	assert_false(VOManager.play("no.such.line"))


func test_code_spoken_lines_ported() -> void:
	# Boss barks, banners and hints the web build spoke from code, not tables (tools/extract_code_lines.mjs).
	var code: Array = Data.table("bs/story/code_lines")
	assert_gt(code.size(), 300)
	assert_true(VOManager.has_line("code.updateRetention.02"), "Retention Specialist's 'trying to LEAVE' bark")
	assert_string_contains(str(VOManager.line("code.updateRetention.02")["text"]), "LEAVE")
	var html: Array = Data.table("bs/story/html_text")
	assert_gt(html.size(), 150, "menu/lobby/credits copy ported")
