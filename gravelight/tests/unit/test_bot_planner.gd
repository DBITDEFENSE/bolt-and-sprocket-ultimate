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


# ---------------------------------------------------------------- T-217 brains, the built-in brain, the decision log

func test_resolve_brain() -> void:
	assert_eq(BotConfig.resolve_brain("auto", "high", false), "small", "a discrete GPU: the small model")
	assert_eq(BotConfig.resolve_brain("auto", "medium", false), "small")
	assert_eq(BotConfig.resolve_brain("auto", "low", false), "small_cpu", "an integrated GPU: the model on the CPU")
	assert_eq(BotConfig.resolve_brain("large", "low", false), "large", "an explicit choice stands")
	assert_eq(BotConfig.resolve_brain("builtin", "high", false), "builtin")
	assert_eq(BotConfig.resolve_brain("large", "high", true), "builtin", "no Ollama in the web build")
	assert_eq(BotConfig.resolve_brain("nonsense", "high", false), "small", "unknown -> auto")


func test_brain_setting_and_cycle() -> void:
	assert_eq(BotConfig.brain_setting({"bot_local_ai": false, "bot_ai_brain": "large"}), "off")
	assert_eq(BotConfig.brain_setting({"bot_local_ai": true, "bot_ai_brain": "small_cpu"}), "small_cpu")
	assert_eq(BotConfig.brain_setting({}), "auto", "an old settings file")
	var seen: Dictionary = {}
	var b: String = "auto"
	for i: int in BotConfig.AI_BRAIN_CYCLE.size():
		seen[b] = true
		assert_true(BotConfig.AI_BRAIN_LABELS.has(b), "%s has a menu label" % b)
		b = BotConfig.next_brain(b)
	assert_eq(b, "auto", "the cycle comes back round")
	assert_true(seen.has("off") and seen.has("builtin"), "Off and Built-in are on the cycle")


func test_brain_tiers_in_bots_json() -> void:
	var lc: Dictionary = cfg["local_ai"]
	for tier: String in ["small", "small_cpu", "large"]:
		var bc: Dictionary = BotConfig.brain_cfg(lc, tier)
		assert_false((bc["models"] as Array).is_empty(), "%s lists models" % tier)
		assert_eq(int((bc["options"] as Dictionary).get("num_ctx", 0)), 2048, "%s keeps the context small" % tier)
		assert_eq(bc["brain"], tier)
	assert_eq(int(BotConfig.brain_cfg(lc, "small_cpu")["options"]["num_gpu"]), 0, "CPU only: no layers on the GPU")
	assert_false((BotConfig.brain_cfg(lc, "small")["options"] as Dictionary).has("num_gpu"), "the GPU tiers let Ollama decide")
	assert_eq(str(BotConfig.brain_cfg(lc, "small")["models"][0]), "gemma3:4b")
	assert_eq(str(BotConfig.brain_cfg(lc, "small_cpu")["models"][0]), "gemma3:1b")
	assert_eq(str(lc["keep_alive"]), "2m", "the model leaves video memory soon after a match")


func test_chat_options_carry_the_tier() -> void:
	var o: Dictionary = LocalAI.chat_options(BotConfig.brain_cfg(cfg["local_ai"], "small_cpu"))
	assert_eq(o["num_gpu"], 0)
	assert_typeof(o["num_ctx"], TYPE_INT, "JSON floats go to Ollama as integers")
	assert_eq(o["num_ctx"], 2048)
	assert_true(o.has("temperature") and o.has("num_predict"))
	var b: Dictionary = LocalAI.chat_body("gemma3:1b", [], {}, BotConfig.brain_cfg(cfg["local_ai"], "small_cpu"))
	assert_eq(b["options"]["num_gpu"], 0)
	assert_eq(b["keep_alive"], "2m")


func _feats(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append({"id": r[0], "kind": r[1], "score": float(r[2]), "dist": float(r[3]), "cur": bool(r[4])})
	return out


func test_learned_index_plain_is_the_scripted_pick() -> void:
	var plain: Dictionary = {"score_scale": 1.0}
	for case: Array in [[[10.0, 50.0, 20.0], ""], [[10.0, 50.0, 45.0], "c"], [[10.0, 70.0, 45.0], "c"], [[30.0, 30.0, 5.0], "a"]]:
		var ids: Array = ["a", "b", "c"]
		var opts: Array[Dictionary] = []
		for i: int in 3:
			opts.append({"id": ids[i], "kind": "repair", "score": case[0][i], "dist": 5.0})
		assert_eq(BotPlanner.learned_index(BotPlanner.features(opts, case[1]), plain), BotPlanner.fallback_index(case[0], ids, case[1]),
			"no trained weights: the same pick as fallback_index %s" % str(case))
	assert_eq(BotPlanner.learned_index([], plain), -1)


func test_learned_index_applies_the_weights() -> void:
	var f: Array = _feats([["repair:W1", "repair", 40, 3, false], ["door:D", "door", 34, 10, false], ["follow", "follow", 12, 0, false]])
	assert_eq(BotPlanner.learned_index(f, {"score_scale": 1.0}), 0, "the best score")
	assert_eq(BotPlanner.learned_index(f, {"score_scale": 1.0, "kind_bias": {"door": 8.0}}), 1, "a door bias flips it")
	assert_eq(BotPlanner.learned_index(f, {"score_scale": 1.0, "kind_bias": {"door": 8.0}, "dist_w": -1.0}), 0, "but the door is farther")


func test_shipped_weights_load() -> void:
	var w: Dictionary = BotPlanner.learned()
	assert_gt(float(w.get("score_scale", 0.0)), 0.0, "the built-in brain has a score scale")
	assert_true(w.get("kind_bias", {}) is Dictionary)


func test_log_decision_appends_json_lines() -> void:
	var path: String = "user://_test_bot_ai/decisions.jsonl"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var row: Dictionary = {"v": 1, "opts": _feats([["a", "repair", 1, 2, true], ["b", "door", 3, 4, false]]), "pick": 1}
	assert_true(BotPlanner.log_decision(row, path, 1))
	assert_true(BotPlanner.log_decision(row, path, 1))
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert_eq(lines.size(), 2, "one line per decision, appended")
	var back: Dictionary = JSON.parse_string(lines[1])
	assert_eq(int(back["pick"]), 1)
	assert_eq(str((back["opts"] as Array)[1]["kind"]), "door")
	assert_false(BotPlanner.log_decision(row, path, 0), "a full log is left alone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- T-216 the crash probe's --set parser

func test_probe_set_parser() -> void:
	var probe: GDScript = load("res://gravelight/tools_src/probe_campaign_start.gd")
	var v: Dictionary = {"gfx_gi": true, "fov": 80.0, "bots": 0, "gfx_fog": "high"}
	assert_string_contains(probe.apply_set(v, "gfx_gi"), "ignored", "no colon: ignored, no crash")
	assert_string_contains(probe.apply_set(v, "nope:1"), "ignored", "unknown key")
	probe.apply_set(v, "gfx_gi:false")
	assert_eq(v["gfx_gi"], false)
	probe.apply_set(v, "fov:90")
	assert_typeof(v["fov"], TYPE_FLOAT, "a float setting stays a float")
	assert_eq(v["fov"], 90.0)
	probe.apply_set(v, "bots:2")
	assert_eq(v["bots"], 2)
	probe.apply_set(v, "gfx_fog:low")
	assert_eq(v["gfx_fog"], "low")
	assert_string_contains(probe.apply_set(v, "bots:many"), "ignored", "a bad number")
	assert_eq(v["bots"], 2)
