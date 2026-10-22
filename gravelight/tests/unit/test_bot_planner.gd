extends GutTest
## The bots' spawn kit and the objective planner's pure rules (bots.json "spawn_kit" / "local_ai"): which kit
## guns and perks are missing, the local AI's request body and reply parsing, the model pick, and the scripted
## fallback pick.

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/bots.json")


# ---------------------------------------------------------------- spawn kit

func test_spawn_kit_is_a_thompson_ironhide_and_second_wind() -> void:
	var kit: Dictionary = cfg["spawn_kit"]
	assert_true((kit["weapons"] as Array).has("thompson"), "bots spawn with the Tommy gun")
	assert_eq(str(kit["hold"]), "thompson", "and hold it")
	assert_true((kit["perks"] as Array).has("ironhide_stout"), "the Juggernog equivalent")
	assert_true((kit["perks"] as Array).has("second_wind"), "the Quick Revive equivalent")
	for w: Variant in kit["weapons"]:
		assert_true((GLData.table("weapons")["weapons"] as Dictionary).has(str(w)), "kit gun %s exists" % w)
	for p: Variant in kit["perks"]:
		assert_true((GLData.table("perks")["perks"] as Dictionary).has(str(p)), "kit perk %s exists" % p)
	assert_gt(float(GLData.table("perks")["perks"]["ironhide_stout"]["effects"]["max_health"]), 100.0, "Ironhide raises max health")
	assert_gt(float(GLData.table("perks")["perks"]["second_wind"]["effects"]["revive_speed_mult"]), 1.0, "Second Wind speeds revives")


func test_kit_missing_skips_what_is_held() -> void:
	var kit: Dictionary = {"weapons": ["thompson", "mp40"], "perks": ["ironhide_stout", "second_wind"]}
	assert_eq(BotConfig.kit_weapons_missing(kit, ["m1911"]), [&"thompson", &"mp40"] as Array[StringName])
	assert_eq(BotConfig.kit_weapons_missing(kit, ["m1911", "thompson"]), [&"mp40"] as Array[StringName], "an upgraded Thompson's base counts")
	assert_eq(BotConfig.kit_perks_missing(kit, [&"second_wind"]), [&"ironhide_stout"] as Array[StringName])
	assert_true(BotConfig.kit_perks_missing(kit, ["ironhide_stout", "second_wind"]).is_empty())


func test_kit_perks_leave_room_to_buy_more() -> void:
	# Update 03: the perk plan (data/gravelight/ai/economy.json) goes past the kit, up to the game's perk cap
	var plan: Array = BotAIData.table("economy")["perk_plan"]
	assert_gt(plan.size(), (cfg["spawn_kit"]["perks"] as Array).size(), "bots still shop for perks on top of the kit")
	assert_gt(int(GLData.table("perks")["cap"]), (cfg["spawn_kit"]["perks"] as Array).size(), "the kit leaves room under the cap")


func test_ai_mode_from_settings() -> void:
	assert_eq(BotConfig.ai_mode_from_settings({"bot_local_ai": true}, 2), "local")
	assert_eq(BotConfig.ai_mode_from_settings({"bot_local_ai": false}, 2), "off")
	assert_eq(BotConfig.ai_mode_from_settings({"bot_local_ai": true}, 0), "off", "no bots, no planner")
	assert_eq(BotConfig.ai_mode_from_settings({}, 1), "local", "on by default")


# ---------------------------------------------------------------- local AI client

func test_local_ai_tuning() -> void:
	var lc: Dictionary = cfg["local_ai"]
	assert_true(str(lc["endpoint"]).begins_with("http://127.0.0.1"), "local only")
	assert_false((lc["models"] as Array).is_empty())
	assert_gt(float(lc["timeout_s"]), 1.0)
	assert_gt(float(lc["decide_every_s"]), 1.0)


func test_chat_body_uses_the_schema_and_no_stream() -> void:
	var schema: Dictionary = BotPlanner.reply_schema(["follow", "egg:s1"])
	var b: Dictionary = LocalAI.chat_body("gemma3:4b", [{"role": "user", "content": "hi"}], schema, cfg["local_ai"])
	assert_eq(b["model"], "gemma3:4b")
	assert_false(bool(b["stream"]))
	assert_eq(b["format"], schema)
	assert_eq((b["format"]["properties"]["choice"]["enum"] as Array), ["follow", "egg:s1"], "the ids are an enum")
	assert_eq(LocalAI.chat_body("m", [], {}, cfg["local_ai"])["format"], "json", "no schema: plain JSON mode")


func test_parse_reply() -> void:
	assert_eq(LocalAI.parse_reply({"message": {"content": "{\"choice\": \"follow\", \"say\": \"On you.\"}"}}), {"choice": "follow", "say": "On you."})
	assert_eq(LocalAI.parse_reply({"message": {"content": "```json\n{\"choice\": \"a\"}\n```"}}), {"choice": "a"}, "fenced")
	assert_eq(LocalAI.parse_reply({"message": {"content": "Sure! {\"choice\": \"b\"} done"}}), {"choice": "b"}, "chatty")
	assert_null(LocalAI.parse_reply({"message": {"content": "no json here"}}))
	assert_null(LocalAI.parse_reply({}))


func test_pick_model() -> void:
	assert_eq(LocalAI.pick_model(["gemma3:27b", "gemma3:4b"], ["gemma3:4b", "llama3:8b"]), "gemma3:4b", "first wanted that is installed")
	assert_eq(LocalAI.pick_model(["gemma3:27b", "gemma3:4b"], ["gemma3:4b", "gemma3:27b"]), "gemma3:27b", "wish order wins")
	assert_eq(LocalAI.pick_model(["qwen3"], ["qwen3:latest"]), "qwen3:latest")
	assert_eq(LocalAI.pick_model(["gemma3:27b"], ["mistral:7b"]), "")


# ---------------------------------------------------------------- planner picks

func test_choice_index() -> void:
	var ids: Array = ["egg:s1_notes:NoteA", "door:Door_Stable", "follow"]
	assert_eq(BotPlanner.choice_index({"choice": "follow"}, ids), 2)
	assert_eq(BotPlanner.choice_index({"choice": "DOOR:door_stable"}, ids), 1, "case-insensitive")
	assert_eq(BotPlanner.choice_index({"choice": "1"}, ids), 0, "by number")
	assert_eq(BotPlanner.choice_index({"choice": "fly to the moon"}, ids), -1)
	assert_eq(BotPlanner.choice_index({"choice": "9"}, ids), -1)
	assert_eq(BotPlanner.choice_index(null, ids), -1)
	assert_eq(BotPlanner.choice_index({"say": "hi"}, ids), -1)


func test_fallback_prefers_score_with_stickiness() -> void:
	var ids: Array = ["a", "b", "c"]
	assert_eq(BotPlanner.fallback_index([10.0, 50.0, 20.0], ids, ""), 1)
	assert_eq(BotPlanner.fallback_index([10.0, 50.0, 45.0], ids, "c"), 2, "the current objective survives a near tie")
	assert_eq(BotPlanner.fallback_index([10.0, 70.0, 45.0], ids, "c"), 1, "but not a clearly better one")
	assert_eq(BotPlanner.fallback_index([], [], ""), -1)


func test_prompt_lists_every_option_with_its_id() -> void:
	var opts: Array[Dictionary] = [{"id": "egg:s2_tune", "label": "tune the radio", "score": 75.4}, {"id": "follow", "label": "stick with Dutch", "score": 12.0}]
	var text: String = BotPlanner.build_prompt(PackedStringArray(["Round 3."]), opts, "egg:s2_tune")
	assert_string_contains(text, "Round 3.")
	assert_string_contains(text, "- egg:s2_tune: tune the radio [score 75]")
	assert_string_contains(text, "- follow: stick with Dutch [score 12]")
	assert_string_contains(text, "Current objective: egg:s2_tune")
