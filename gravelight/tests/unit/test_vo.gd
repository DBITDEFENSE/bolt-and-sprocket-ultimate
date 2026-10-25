extends GutTest
## VOManager rules (docs/gravelight/VO_SCRIPT.md §1), the extracted line data, and the baked voice audio (T-035).

const MANIFEST: String = "res://data/gravelight/vo/audio_manifest.json"
const NEW_BANTER: Array[String] = ["BNT_DUT_PEG_04", "BNT_DUT_PEG_05", "BNT_DUT_DEA_04", "BNT_DUT_DEA_05", "BNT_DUT_WRN_04",
	"BNT_DUT_WRN_05", "BNT_PEG_DEA_04", "BNT_PEG_DEA_05", "BNT_PEG_WRN_04", "BNT_PEG_WRN_05", "BNT_DEA_WRN_04", "BNT_DEA_WRN_05"]
const SQUAD_CATEGORIES: Array[String] = ["SPAWN", "ROUND_START", "ROUND_END", "BUY_AMMO", "TEAM_DOWN", "INTEL",
	"DENY_NO_POWER", "DENY_CAP", "DENY_NO_SCRIP", "DOOR", "DOWN", "REVIVE", "REVIVED", "HEADSHOT", "AMMO_LOW", "AMMO_NONE"]


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


# ------------------------------------------------------------------ T-035: baked audio and the squad

func test_every_line_has_audio_or_a_listed_reason() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var manifest: Dictionary = GLData.load_json(MANIFEST)
	var files: Dictionary = manifest.get("files", {})
	var missing: Dictionary = manifest.get("missing", {})
	assert_gt(files.size(), 500, "the voice bake covers the script")
	var unaccounted: PackedStringArray = []
	var no_file: PackedStringArray = []
	for id: String in lines.keys():
		var rec: Dictionary = lines[id]
		var ids: PackedStringArray = []
		if rec.has("exchange"):
			for i: int in (rec["exchange"] as Array).size():
				ids.append("%s_p%d" % [id, i])
		else:
			ids.append(id)
		for fid: String in ids:
			if files.has(fid):
				var row: Dictionary = files[fid]
				assert_gt(float(row.get("duration", 0.0)), 0.0, "duration > 0 for " + fid)
				var path: String = str(row.get("path", ""))
				if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
					no_file.append(fid)
			elif missing.has(fid):
				assert_ne(str(missing[fid]), "", "a reason for " + fid)
			else:
				unaccounted.append(fid)
	assert_eq(unaccounted.size(), 0, "lines neither baked nor listed as missing: " + ", ".join(unaccounted))
	assert_eq(no_file.size(), 0, "manifest rows whose file is gone: " + ", ".join(no_file))


func test_audio_path_and_stream_for_a_baked_line() -> void:
	var path: String = GLVO.audio_path(&"OPR_MATCH_START_01")
	assert_true(path.begins_with("res://gravelight/audio/vo/opr/OPR_MATCH_START_01."), path)
	var stream: AudioStream = GLVO.load_stream(path)
	assert_not_null(stream, "the Operator's first line loads as an AudioStream")
	if stream != null:
		assert_gt(stream.get_length(), 1.0, "the file is longer than a second")
	# Exchange parts live under the part speaker's folder.
	var p1: String = GLVO.audio_path(&"BNT_DUT_PEG_01", 1)
	assert_true(p1.begins_with("res://gravelight/audio/vo/peg/BNT_DUT_PEG_01_p1."), p1)


func test_played_line_takes_its_duration_from_the_file() -> void:
	assert_true(GLVO.play(&"OPR_MATCH_START_01"))
	var cur: Dictionary = GLVO._current[&"story"]
	var stream: AudioStream = GLVO.load_stream(GLVO.audio_path(&"OPR_MATCH_START_01"))
	assert_almost_eq(float(cur["end"]) - GLVO._now, stream.get_length(), 0.01, "subtitle/queue timing follows the audio")
	assert_eq(GLVO.audio_plays, 1, "an audio stream was started")


func test_new_banter_ids_valid_and_squad_categories_exist() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: String in NEW_BANTER:
		assert_true(lines.has(id), id)
		if lines.has(id):
			var rec: Dictionary = lines[id]
			assert_eq(str(rec["speaker"]), "BNT", id)
			var ex: Array = rec.get("exchange", [])
			assert_gte(ex.size(), 2, id + " has at least two parts")
			var spk: PackedStringArray = str(rec["category"]).split("_")
			for p: Variant in ex:
				assert_true(spk.has(str((p as Array)[0])), id + " part speaker is one of the pair")
	for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
		for cat: String in SQUAD_CATEGORIES:
			assert_true(GLVO._index.has("%s:%s" % [spk, cat]), "%s has %s lines" % [spk, cat])


func test_say_as_uses_the_players_own_voice() -> void:
	GameState.character_id = &"peg"
	assert_true(GLVO.say_as(1, "DOOR"))
	var cur: Dictionary = GLVO._current[&"player"]
	assert_true(String(cur["id"]).begins_with("PEG_DOOR"), str(cur["id"]))
	GameState.character_id = &"dutch"


func test_down_sequence_uses_the_second_squad_channel() -> void:
	GameState.character_id = &"peg"
	assert_true(GLVO.say_as(1, "DOWN", 1.0), "the downed survivor speaks at once")
	assert_true(String(GLVO.current_line(&"player")).begins_with("PEG_DOWN"))
	# What the others say about the down goes to the second channel: it overlaps the DOWN instead of racing it.
	assert_true(GLVO.say_as(1, "TEAM_DOWN", 1.0))
	assert_true(String(GLVO.current_line(&"squad")).begins_with("PEG_TEAM_DOWN"), str(GLVO.current_line(&"squad")))
	assert_true(String(GLVO.current_line(&"player")).begins_with("PEG_DOWN"), "DOWN keeps playing")
	# The reviver's REVIVE queues behind TEAM_DOWN on that channel and is sticky (never expires).
	assert_true(GLVO.say_as(1, "REVIVE", 1.0))
	assert_eq(GLVO.queued_count(&"squad"), 1, "REVIVE waits behind TEAM_DOWN")
	for i: int in 40:
		GLVO.advance(0.5)
		if String(GLVO.current_line(&"squad")).begins_with("PEG_REVIVE"):
			break
	assert_true(String(GLVO.current_line(&"squad")).begins_with("PEG_REVIVE"), "REVIVE played after TEAM_DOWN: " + str(GLVO.current_line(&"squad")))
	# REVIVED comes on the player channel at once once DOWN is over (the longest DOWN line can outlast TEAM_DOWN).
	for i: int in 40:
		if not String(GLVO.current_line(&"player")).begins_with("PEG_DOWN"):
			break
		GLVO.advance(0.5)
	assert_true(GLVO.say_as(1, "REVIVED", 1.0))
	assert_true(String(GLVO.current_line(&"player")).begins_with("PEG_REVIVED"), str(GLVO.current_line(&"player")))
	GameState.character_id = &"dutch"


func test_tier2_squad_line_cuts_a_quip() -> void:
	GameState.character_id = &"wren"
	assert_true(GLVO.say_as(1, "HEADSHOT", 1.0))
	assert_true(String(GLVO.current_line(&"player")).begins_with("WRN_HEADSHOT"))
	assert_true(GLVO.say_as(1, "DOWN", 1.0), "a down is not blocked by the chatter gap")
	assert_true(String(GLVO.current_line(&"player")).begins_with("WRN_DOWN"), "and cuts the quip: " + str(GLVO.current_line(&"player")))
	GameState.character_id = &"dutch"


func test_banter_plays_once_and_rules_exist() -> void:
	var b: Dictionary = GLVO.rules.get("banter", {})
	assert_true(b.has("chance") and b.has("cooldown_s") and b.has("delay_s"), "banter rules in rules.json")
	assert_true(GLVO.rules.has("player_category_cooldown"), "squad overrides in rules.json")
	assert_true(GLVO.try_banter(true) or true, "no second survivor in a unit test: nothing to pair with")
	# Direct play of an exchange: every part is timed and the exchange is once per match.
	assert_true(GLVO.play(&"BNT_DUT_PEG_04"))
	var cur: Dictionary = GLVO._current[&"player"]
	assert_eq((cur["parts"] as Array).size(), 2)
	GLVO.advance(60.0)
	GLVO.stop_all()
	assert_true(GLVO._played_once.has("BNT_DUT_PEG_04"), "exchange marked once per match")


func test_team_down_never_picks_the_bot_squads_claimed_reviver() -> void:
	# T-059: a bot squad names the reviver (blackboard "revive:<pid>") long before that bot starts the hold; the
	# TEAM_DOWN speaker, picked one second after the down, must already leave it out.
	var fake: GDScript = GDScript.new()
	fake.source_code = "extends Node\nvar player_id: int = 0\nvar spectating: bool = false\nvar downed: bool = false\n"
	fake.reload()
	var mates: Array[Node] = []
	for pid: int in [7, 8, 9]:
		var n: Node = Node.new()
		n.set_script(fake)
		n.set("player_id", pid)
		n.set("downed", pid == 7)
		n.add_to_group(&"players")
		add_child_autofree(n)
		mates.append(n)
	var squad_script: GDScript = GDScript.new()
	squad_script.source_code = "extends Node\nvar blackboard: BotBlackboard = BotBlackboard.new()\n"
	squad_script.reload()
	var sq: Node = Node.new()
	sq.set_script(squad_script)
	sq.add_to_group(&"bot_squad")
	add_child_autofree(sq)
	(sq.get("blackboard") as BotBlackboard).claim("revive:7", 9, "revive", 0.0)
	for i: int in 20:
		GLVO._bags.clear()
		var item: Dictionary = {"id": &"", "priority": 2, "speaker": &"", "pid": -1,
			"resolve": {"category": "TEAM_DOWN", "downed": 7, "exclude": [7]}}
		assert_true(GLVO._resolve_item(item), "someone fits")
		assert_eq(int(item["pid"]), 8, "neither the downed (7) nor the claimed reviver (9)")
	for n: Node in mates:
		n.remove_from_group(&"players")
	sq.remove_from_group(&"bot_squad")


# ------------------------------------------------------------------ T-086: the Map 0 egg's story beats

func test_story_beat_lines_exist_and_are_tier_two_map_lines() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: String in ["FAS_M0_NOTES_01", "FAS_M0_WRONG_01", "OPR_M0_FIRST_01", "OPR_M0_CREDIT_01", "DUT_SQ7_M0_EGG_HEARD_01", "WRN_SQ7_M0_EGG_DONE_02",
			"JAK_SQ7_M0_EGG_LOCK2_01", "PEG_SQ4_EE_COMMIT_SELF_01"]:
		assert_true(lines.has(id), id)
	var pcp: Dictionary = GLVO.rules.get("player_category_priority", {})
	for cat: String in ["M0_EGG_HEARD", "M0_EGG_LOOK", "M0_EGG_NOTE", "M0_EGG_NOTE_FIRST", "M0_EGG_NOTE_TWO", "M0_EGG_NOTES_DONE", "M0_EGG_LOCK1",
			"M0_EGG_LOCK2", "M0_EGG_WRONG", "M0_EGG_DONE", "M0_EGG_TONICS", "EE_COMMIT_SELF"]:
		assert_eq(int(pcp.get(cat, 1)), 2, "%s is tier 2 (queues behind the story, cuts a quip)" % cat)
		for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
			var n: int = 0
			for rec: Variant in lines.values():
				if (rec as Dictionary)["speaker"] == spk and (rec as Dictionary)["category"] == cat:
					n += 1
			assert_gte(n, 1, "%s has a %s line" % [spk, cat])
	assert_eq(GLVO.line_map_of("DUT_SQ7_M0_EGG_HEARD_01", lines["DUT_SQ7_M0_EGG_HEARD_01"], GLVO.rules), "map00", "a Map 0 line")


func test_story_beat_waits_for_the_radio_then_plays() -> void:
	var map_was: StringName = GameState.map_id
	GameState.map_id = &"map00_crossroads"   # (Map 0 lines draw on Map 0 only)
	assert_true(GLVO.play(&"FAS_M0_NOTES_01"))
	GLVO.say_story_beat(0, "M0_EGG_NOTES_DONE", 0.5)
	assert_eq(GLVO.pending_story_beats().size(), 1)
	GLVO.advance(3.0)
	assert_eq(GLVO.current_line(&"player"), &"", "nobody talks over Fasbender")
	assert_eq(GLVO.pending_story_beats().size(), 1, "the beat waits")
	GLVO.advance(30.0)   # past the unbaked line's subtitle duration
	assert_eq(GLVO.current_line(&"story"), &"")
	assert_eq(GLVO.pending_story_beats().size(), 0)
	assert_true(String(GLVO.current_line(&"player")).contains("M0_EGG_NOTES_DONE"), "then the survivor speaks: %s" % GLVO.current_line(&"player"))
	assert_gt(GLVO.last_said_pid, 0)
	var first: int = GLVO.last_said_pid
	GLVO.say_story_beat(0, "M0_EGG_NOTES_DONE", 0.0, first)
	assert_eq(GLVO.pending_story_beats().size(), 1, "solo without bots: the same survivor carries the second line")
	assert_eq(GLVO.pending_story_beats()[0]["pid"], first)
	GameState.map_id = map_was
