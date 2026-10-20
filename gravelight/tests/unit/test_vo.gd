extends GutTest
## VOManager rules (docs/VO_SCRIPT.md §1) and the extracted line data.


func before_each() -> void:
	GLVO.always_pass_chance = true
	GLVO.reset_match()


func after_each() -> void:
	GLVO.always_pass_chance = false
	GLVO.reset_match()


func test_lines_loaded() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	assert_gt(lines.size(), 300)
	for id: String in ["OPR_PWR_RESUPPLY_01", "DUT_PERK_IRONHIDE_01", "FAS_M0_R6_01", "BNT_DUT_PEG_01"]:
		assert_true(lines.has(id), id)


func test_every_operator_powerup_has_three_variants() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for token: String in ["RESUPPLY", "DEATHSDOOR", "DOUBLESCRIP", "BLACKOUT", "FORTIFY", "CLEARANCE"]:
		var n: int = 0
		for rec: Variant in lines.values():
			if (rec as Dictionary)["speaker"] == "OPR" and (rec as Dictionary)["category"] == "PWR_" + token:
				n += 1
		assert_gte(n, 3, token)


func test_cooldown_blocks_immediate_repeat() -> void:
	assert_true(GLVO.play_category(&"DUT", "HEADSHOT"), "first headshot line plays")
	GLVO.advance(5.0)   # past the 3.5 s chatter gap, inside the 25 s cooldown
	assert_false(GLVO.play_category(&"DUT", "HEADSHOT"), "cooldown blocks the repeat")
	GLVO.advance(25.0)
	assert_true(GLVO.play_category(&"DUT", "HEADSHOT"), "plays again after the cooldown")


func test_no_repeat_until_bag_empties() -> void:
	var seen: Dictionary = {}
	for i: int in 4:
		assert_true(GLVO.play_category(&"OPR", "PWR_RESUPPLY"))
		seen[GLVO.current_line(&"story")] = true
		GLVO.stop_all()
	assert_eq(seen.size(), 4, "all four resupply variants before any repeat")


func test_critical_interrupts_event() -> void:
	assert_true(GLVO.play(&"OPR_ROUND_START_02"))
	assert_eq(GLVO.current_line(&"story"), &"OPR_ROUND_START_02")
	assert_true(GLVO.play(&"FAS_SAMPLE_01"))
	assert_eq(GLVO.current_line(&"story"), &"FAS_SAMPLE_01", "tier 4 cuts tier 2")


func test_announce_queues_behind_event() -> void:
	assert_true(GLVO.play(&"OPR_ROUND_START_02"))
	assert_true(GLVO.play(&"OPR_PWR_RESUPPLY_01"))
	assert_eq(GLVO.current_line(&"story"), &"OPR_ROUND_START_02", "tier 3 can't cut tier 2")
	assert_eq(GLVO.queued_count(&"story"), 1)
	GLVO.advance(30.0)
	assert_ne(GLVO.current_line(&"story"), &"OPR_ROUND_START_02")


func test_story_line_suppresses_chatter() -> void:
	assert_true(GLVO.play(&"OPR_ROUND_START_02"))
	assert_false(GLVO.say_player("HEADSHOT"))


func test_bracket_tags_stripped() -> void:
	assert_eq(GLVO.strip_tags("[cheerful] Good evening, {everyone}! *[tape squeal]* Hi."), "Good evening, everyone! Hi.")


func test_subtitle_chunking() -> void:
	var s: GDScript = load("res://gravelight/ui/subtitles.gd") as GDScript
	var chunks: PackedStringArray = s.call("chunk", "word ".repeat(40).strip_edges(), 84)
	assert_gt(chunks.size(), 1)
	for c: String in chunks:
		assert_lte(c.length(), 84)
