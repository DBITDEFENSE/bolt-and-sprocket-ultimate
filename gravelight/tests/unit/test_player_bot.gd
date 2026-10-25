extends GutTest
## T-071 player bot mode: the toggle / hand-back rules (PlayerBot.can_enable, PlayerBot.takeover), the trainer's
## pure parts (loop choice, the train-compactness metric, the gap, classification, the safe-turn rule, dead
## reckoning, the kite's direction score), the data (player_bot.json, the agent's personality, the F6 binding, the
## lead_train action, the agent-only yard loop) and the brain options the agent is built with.

var cfg: Dictionary
var tcfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/ai/player_bot.json")
	tcfg = cfg.get("trainer", {})


# ---------------------------------------------------------------- toggle and hand-back

func test_can_enable() -> void:
	assert_true(bool(PlayerBot.can_enable(false, false, true, false)["ok"]), "solo: yes")
	assert_true(bool(PlayerBot.can_enable(true, true, true, false)["ok"]), "the co-op host: yes")
	var c: Dictionary = PlayerBot.can_enable(true, false, true, false)
	assert_false(bool(c["ok"]), "a co-op client: no (its world is the host's)")
	assert_string_contains(str(c["reason"]), "host")
	assert_false(bool(PlayerBot.can_enable(false, false, false, false)["ok"]), "no player: no")
	assert_false(bool(PlayerBot.can_enable(false, false, true, true)["ok"]), "spectating: no")


func test_takeover_rules() -> void:
	var t: Dictionary = cfg.get("takeover", {})
	assert_false(PlayerBot.takeover(0.0, [], 0.0, 0.0, 0.0, t), "no input: the agent keeps playing")
	assert_true(PlayerBot.takeover(0.8, [], 0.0, 0.0, 0.0, t), "the move stick takes over")
	assert_false(PlayerBot.takeover(0.1, [], 0.0, 0.0, 0.0, t), "a stick inside its dead zone doesn't")
	assert_true(PlayerBot.takeover(0.0, ["fire"], 0.0, 0.0, 0.0, t), "a shot takes over")
	assert_true(PlayerBot.takeover(0.0, [], 12.0, 0.0, 0.0, t), "a real mouse move takes over")
	assert_false(PlayerBot.takeover(0.0, [], 1.0, 0.0, 0.0, t), "mouse jitter doesn't")
	assert_true(PlayerBot.takeover(0.0, [], 0.0, 0.9, 0.0, t), "the pad's look stick takes over")
	assert_false(PlayerBot.takeover(1.0, ["fire"], 50.0, 1.0, 0.2, t), "nothing counts inside the grace after a switch-on")


func test_takeover_actions_cover_the_controls() -> void:
	var acts: Array = (cfg.get("takeover", {}) as Dictionary).get("actions", [])
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "fire", "ads", "jump", "sprint", "reload", "interact"]:
		assert_true(acts.has(a), "%s hands control back" % a)
	assert_false(acts.has("pause"), "pausing doesn't (the pause menu has the toggle)")
	assert_false(acts.has("bot_mode"), "the toggle itself is handled apart")


func test_bot_mode_binding_and_label() -> void:
	var inp: Dictionary = GLData.load_json("res://data/gravelight/input_defaults.json")
	assert_true(inp.has("bot_mode"), "the bot_mode action has a default binding")
	assert_eq(str((inp["bot_mode"] as Dictionary).get("key", "")), "F6")
	var used: Array = []
	for k: String in inp.keys():
		if not k.begins_with("_") and k != "bot_mode" and (inp[k] as Dictionary).has("key"):
			used.append(str((inp[k] as Dictionary)["key"]))
	assert_false(used.has("F6"), "F6 is free otherwise")
	assert_true(MenuSettings.ACTION_NAMES.has("bot_mode"), "rebindable in Settings > Controls")
	assert_string_contains(str((cfg.get("hud", {}) as Dictionary).get("text", "")), "%s", "the HUD tag names the key")


func test_brain_options_for_the_agent() -> void:
	var b: Dictionary = cfg.get("brain", {})
	assert_false(bool(b.get("kit", true)), "no free bot kit for the player's own survivor")
	assert_false(bool(b.get("bonus_perk", true)), "no bonus perk")
	assert_true(bool(b.get("shopping", false)) and bool(b.get("perks", false)), "it shops and drinks with its own Scrip")
	assert_eq(int(b.get("revive_priority", 1)), 0, "revived first, like the human")
	assert_false(BotAIData.skill(str(cfg.get("skill", ""))).is_empty(), "its aim preset exists")
	var pers: Dictionary = BotAIData.personality(str(cfg.get("personality", "")))
	assert_eq(str(pers.get("character", "")), "player_agent")
	assert_gt(float((pers.get("actions", {}) as Dictionary).get("lead_train", 0.0)), 0.9, "lead_train is its fight")
	assert_eq(float((pers.get("actions", {}) as Dictionary).get("follow", 1.0)), 0.0, "it leads, it never follows")
	assert_eq(float(((pers.get("aim", {}) as Dictionary).get("class_pref", {}) as Dictionary).get("bolt", 1.0)), 0.0, "no Kar98k")
	var plan: Array = (pers.get("economy", {}) as Dictionary).get("perk_order", [])
	assert_eq(str(plan[0]), "second_wind", "Second Wind first: the solo self-revive")


func test_lead_train_action_is_gated_for_everyone_else() -> void:
	var acts: Dictionary = BotAIData.table("actions")
	assert_true((acts.get("actions", {}) as Dictionary).has("lead_train"))
	var curves: Dictionary = BotAIData.table("curves")
	var off: Dictionary = BotUtility.score_all(acts, {"trainer": 0.0, "any_ammo": 1.0}, curves)
	assert_eq(float(off.get("lead_train", 1.0)), 0.0, "a bot (trainer input 0) never picks it")
	var on: Dictionary = BotUtility.score_all(acts, {"trainer": 1.0, "any_ammo": 1.0}, curves)
	assert_gt(float(on.get("lead_train", 0.0)), 0.8, "the agent with zombies about")


# ---------------------------------------------------------------- the trainer's pure parts

func test_gap_grows_with_speed_and_reach() -> void:
	var walk: float = BotTrainer.gap_for(2.0, tcfg)
	var run: float = BotTrainer.gap_for(4.8, tcfg)
	assert_gt(run, walk, "a runner gets more room")
	assert_gt(BotTrainer.gap_for(5.4, tcfg, 3.4), run + 1.5, "a Bellringer's lunge more again")
	assert_gt(walk, 1.5, "never inside a ganger's swing")


func test_classify() -> void:
	# a 40 m loop, ring 3 m: loop distance forward 0..40 (the agent at 0, travelling +)
	assert_eq(BotTrainer.classify(4.0, 40.0, 0.5, 4.0, 3.0, tcfg), "ahead", "on the line 4 m ahead: a cutter")
	assert_eq(BotTrainer.classify(35.0, 40.0, 0.5, 5.0, 3.0, tcfg), "behind", "5 m behind on the line: the train")
	assert_eq(BotTrainer.classify(20.0, 40.0, 0.5, 6.0, 3.0, tcfg), "off", "across the loop, far: not part of it")
	assert_eq(BotTrainer.classify(20.0, 40.0, 8.0, 2.0, 3.0, tcfg), "close", "off the ring but close behind: a follower")
	assert_eq(BotTrainer.classify(20.0, 40.0, 8.0, 2.0, 3.0, tcfg, true), "ahead", "off the ring, close and in front: in the way")
	assert_eq(BotTrainer.classify(30.0, 40.0, 0.5, 2.0, 3.0, tcfg, true), "behind", "behind on the loop wins over the facing")


func test_train_stats_compactness() -> void:
	var tight: Dictionary = BotTrainer.train_stats([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1)], 3.0)
	assert_eq(int(tight["n"]), 4)
	assert_almost_eq(float(tight["bunched"]), 1.0, 0.001, "four in a 1 m square: all bunched")
	assert_lt(float(tight["spread"]), 1.0)
	var strung: Dictionary = BotTrainer.train_stats([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(8, 0, 0), Vector3(12, 0, 0)], 3.0)
	assert_lt(float(strung["bunched"]), 0.6, "strung out over 12 m")
	assert_gt(float(strung["spread"]), 3.0)
	var none: Dictionary = BotTrainer.train_stats([], 3.0)
	assert_eq(int(none["n"]), 0)
	assert_eq(none["centroid"], Vector3.INF)


func test_safe_to_turn() -> void:
	var gap: float = BotTrainer.gap_for(3.4, tcfg)
	var far: float = gap + 5.0
	assert_true(BotTrainer.safe_to_turn(far, gap, INF, 1.0, 5, 10, tcfg), "train well back, the way ahead clear: turn and fire")
	assert_false(BotTrainer.safe_to_turn(gap * 0.6, gap, INF, 1.0, 5, 10, tcfg), "the head inside the gap: keep running")
	assert_false(BotTrainer.safe_to_turn(far, gap, 1.0, 1.0, 5, 10, tcfg), "a cutter right ahead: don't turn your back on it")
	assert_false(BotTrainer.safe_to_turn(far, gap, INF, 1.0, 5, 0, tcfg), "an empty magazine: reload on the run")


func test_choose_loop() -> void:
	var w: Dictionary = tcfg.get("loop_weights", {})
	var cands: Array = [
		{"id": "small", "length": 21.0, "ring_width": 5.0, "travel_m": 0.0, "windows": 2, "home": 0.0, "bonus": -3.0},
		{"id": "open", "length": 46.0, "ring_width": 4.5, "travel_m": 5.0, "windows": 2, "home": 0.0, "bonus": 4.0},
		{"id": "far", "length": 60.0, "ring_width": 4.5, "travel_m": 90.0, "windows": 0, "home": 0.0},
	]
	assert_eq(BotTrainer.choose_loop(cands, w), 1, "the long open loop close by wins")
	cands[0]["current"] = true
	cands[0]["bonus"] = 4.0
	cands[0]["length"] = 44.0
	assert_eq(BotTrainer.choose_loop(cands, w), 0, "a loop in use as good as another is kept (stickiness)")
	assert_eq(BotTrainer.choose_loop([], w), -1)
	assert_lt(BotTrainer.loop_score({"length": 12.0, "ring_width": 3.0}, w), BotTrainer.loop_score({"length": 30.0, "ring_width": 3.0}, w) - 5.0, "too small to train on")


func test_dead_reckon() -> void:
	var p: Vector3 = BotTrainer.dead_reckon(Vector3(10, 0, 0), Vector3.ZERO, 3.0, 1.0, 2.0)
	assert_almost_eq(p.x, 7.0, 0.01, "a jogger seen 1 s ago is 3 m closer")
	var cap: Vector3 = BotTrainer.dead_reckon(Vector3(10, 0, 0), Vector3.ZERO, 3.0, 9.0, 2.0)
	assert_almost_eq(cap.x, 4.0, 0.01, "capped at dead_reckon_s")
	var near: Vector3 = BotTrainer.dead_reckon(Vector3(3, 0, 0), Vector3.ZERO, 5.0, 5.0, 5.0)
	assert_almost_eq(near.x, 1.0, 0.01, "never past 1 m of the agent")


func test_kite_score_swerves_round_a_cutter() -> void:
	var w: Dictionary = {"align": 2.0, "wall": 2.5, "zombie": 3.0, "cross": 4.0, "margin": 1.2, "keep": 0.0}
	var fwd: Vector3 = Vector3(1, 0, 0)
	var threats: Array = [[Vector3(2.5, 0, 0), 3.4, 1.5]]
	var straight: float = BotTrainer.kite_score(Vector3.ZERO, fwd, 3.0, fwd, Vector3.ZERO, 4.5, 0.7, threats, w)
	var side: float = BotTrainer.kite_score(Vector3.ZERO, Vector3(0.7, 0, 0.7).normalized(), 3.0, fwd, Vector3.ZERO, 4.5, 0.7, threats, w)
	assert_gt(side, straight, "a zombie dead ahead: veer off the line")
	var clear: float = BotTrainer.kite_score(Vector3.ZERO, fwd, 3.0, fwd, Vector3.ZERO, 4.5, 0.7, [], w)
	assert_gt(clear, side, "with nothing in the way, straight round the loop is best")
	var wall: float = BotTrainer.kite_score(Vector3.ZERO, fwd, 1.0, fwd, Vector3.ZERO, 4.5, 0.7, [], w)
	assert_lt(wall, clear, "a wall a metre ahead costs")
	var into_train: float = BotTrainer.kite_score(Vector3.ZERO, -fwd, 3.0, fwd, Vector3.ZERO, 4.5, 0.7, [[Vector3(-2, 0, 0), 3.4, 1.5]], w)
	assert_lt(into_train, -5.0, "back into the train is the worst")


# ---------------------------------------------------------------- the loops

func test_agent_only_yard_loop() -> void:
	var all: Array[TrainingRoute] = TrainingRoute.all_for_map("map00")
	var yard: TrainingRoute = null
	for r: TrainingRoute in all:
		if r.id == "map00_yard_well":
			yard = r
	assert_not_null(yard, "the Well Loop is authored")
	assert_true(yard.agent_only, "only the agent trains there (the bots' T-058 door rules are unchanged)")
	assert_gt(yard.length(), 40.0)
	assert_true(yard.requires_doors.has("door_yard") and yard.requires_doors.has("door_stable"))
	assert_gt(yard.agent_bonus, 0.0)
	for r2: TrainingRoute in all:
		if r2.id == "map00_taproom_stable":
			assert_lt(r2.agent_bonus, 0.0, "the lollipop (its stick walked both ways) is kept off")


# ---------------------------------------------------------------- pass 2: the game plan

func test_agent_plan_steps() -> void:
	var steps: Array = [{"gun": "m1_garand", "or_tier": 2.4}, {"door": "door_cellar"}, {"power": true}, {"perk": "second_wind"},
		{"crucible": "*"}]
	var st: Dictionary = {"doors": {}, "power": false, "perks": [], "guns": [{"id": "m1911", "upgraded": false, "tier": 0.5}], "round": 2}
	assert_eq(AgentPlan.current(steps, st), steps[0], "a real gun first")
	st["guns"].append({"id": "thompson", "upgraded": false, "tier": 3.6})
	assert_eq(AgentPlan.current(steps, st), steps[1], "any gun of the tier or better does")
	st["doors"]["door_cellar"] = true
	st["power"] = true
	assert_eq(AgentPlan.current(steps, st), steps[3], "door, power: the perk next")
	st["perks"] = ["second_wind"]
	assert_eq(AgentPlan.current(steps, st), steps[4])
	st["guns"][1]["upgraded"] = true
	assert_true(AgentPlan.current(steps, st).is_empty(), "the plan is through: the ordinary economy runs")
	st["perks"] = []
	assert_eq(AgentPlan.current(steps, st), steps[3], "a perk lost on a down is the current step again")
	assert_true(AgentPlan.current([{"door": "x", "from_round": 5}], st).is_empty(), "not before its round")


func test_agent_plan_filter_rule() -> void:
	var step: Dictionary = {"door": "door_stable"}
	assert_true(AgentPlan.allows(step, "door", "door_stable"))
	assert_false(AgentPlan.allows(step, "door", "door_upstairs"), "only the plan's door")
	assert_false(AgentPlan.allows(step, "perk", "hawkeye_brandy"), "no perk while saving for the door")
	assert_true(AgentPlan.allows(step, "ammo", ""), "ammo always")
	assert_true(AgentPlan.allows(step, "ammo_box", ""))
	assert_true(AgentPlan.allows({}, "crate", ""), "no step: anything")
	assert_true(AgentPlan.allows({"crucible": "*"}, "crucible", ""))


func test_plans_name_real_things() -> void:
	var plans: Dictionary = cfg.get("plans", {})
	assert_true(plans.has("map00") and plans.has("map01"))
	for mk: String in ["map00", "map01"]:
		var ids: Array = []
		for r: TrainingRoute in TrainingRoute.all_for_map(mk):
			ids.append(r.id)
		for l: Variant in (plans[mk] as Dictionary).get("train_at", []):
			assert_true(ids.has(str(l)), "%s train_at %s is an authored loop" % [mk, l])
		for s: Variant in (plans[mk] as Dictionary).get("steps", []):
			var sd: Dictionary = s as Dictionary
			if sd.has("perk"):
				assert_false(PerkManager.perk_data(StringName(str(sd["perk"]))).is_empty(), "perk %s exists" % sd["perk"])
			if sd.has("gun"):
				assert_true((GLData.table("weapons")["weapons"] as Dictionary).has(str(sd["gun"])), "gun %s exists" % sd["gun"])
	assert_gt(AgentPlan.loop_bonus("map00", "map00_yard_well", 8.0), AgentPlan.loop_bonus("map00", "map00_taproom", 8.0))
	assert_eq(AgentPlan.loop_bonus("map00", "map00_stable", 8.0), 0.0)


# ---------------------------------------------------------------- pass 3: skip-ahead, the dry reload's room

func test_agent_plan_later_steps() -> void:
	var steps: Array = [{"gun": "m1_garand"}, {"door": "door_cellar"}, {"perk": "second_wind"}, {"door": "door_stable"},
		{"perk": "ironhide_stout", "firm": true}, {"perk": "marathon_malt"}]
	var prices: Dictionary = {0: 600, 1: 1500, 2: 500, 3: 1000, 4: 2500, 5: 2000}
	var st: Dictionary = {"doors": {}, "power": false, "perks": [], "guns": [{"id": "m1_garand", "upgraded": false, "tier": 2.4}], "round": 3}
	# the cellar (1500) unaffordable: of the next two, the cheaper ones may go first
	assert_eq(AgentPlan.later_steps(steps, st, 2, prices, 900), [steps[2], steps[3]])
	assert_eq(AgentPlan.later_steps(steps, st, 1, prices, 900), [steps[2]], "only the next n")
	st["doors"]["door_cellar"] = true
	# Second Wind (500) affordable but waiting (mid-round in the cellar): any of the next n
	assert_eq(AgentPlan.later_steps(steps, st, 2, prices, 1200), [steps[3], steps[4]])
	assert_eq(AgentPlan.later_steps(steps, st, 2, prices, 300), [], "unaffordable: nothing dearer jumps it")
	st["perks"] = ["second_wind"]
	st["doors"]["door_stable"] = true
	assert_eq(AgentPlan.later_steps(steps, st, 2, prices, 2000), [], "a firm step is never jumped")
	assert_eq(AgentPlan.later_steps(steps, st, 0, prices, 2000), [])


func test_reload_room() -> void:
	var cfg: Dictionary = {"reload_dry_m": 0.9}
	var walk: float = float(GLData.table("player").get("walk_speed", 4.5)) * 0.95
	assert_almost_eq(BotTrainer.reload_room(2.2, 2.0, 1.5, cfg), 2.4, 0.001, "a walker never closes on a walk: reach + margin")
	assert_almost_eq(BotTrainer.reload_room(2.2, 4.8, 1.5, cfg), 2.4 + (4.8 - walk) * 2.2, 0.001, "a runner closes for the reload's length")
	assert_gt(BotTrainer.reload_room(6.5, 4.8, 1.5, cfg), BotTrainer.reload_room(2.2, 4.8, 1.5, cfg), "a long reload needs more room")


# ---------------------------------------------------------------- T-086: the agent's easter-egg block

func test_agent_egg_block_rules() -> void:
	var egg: Dictionary = {"quest": "map00_radio", "after": [{"perk": "ironhide_stout"}], "from_round": 3, "max_pressure": 0.3, "quiet_m": 14.0, "value": 0.85}
	var st: Dictionary = {"doors": {}, "power": true, "perks": [], "guns": [], "round": 2, "eggs": {"map00_radio": false}}
	assert_false(AgentPlan.egg_ready(egg, st), "not before its round")
	st["round"] = 4
	assert_false(AgentPlan.egg_ready(egg, st), "not before the after steps (Ironhide here)")
	st["perks"] = ["ironhide_stout"]
	assert_true(AgentPlan.egg_ready(egg, st), "Ironhide drunk, round 4: the egg's moment")
	st["eggs"]["map00_radio"] = true
	assert_false(AgentPlan.egg_ready(egg, st), "done is done")
	assert_false(AgentPlan.egg_ready({}, st), "no block: no egg work")
	assert_eq(AgentPlan.egg_value(egg, true, 0.1, 3.0), 0.85, "a break: go, whatever is near")
	assert_eq(AgentPlan.egg_value(egg, false, 0.1, 20.0), 0.85, "mid-round with nothing within quiet_m: go")
	assert_eq(AgentPlan.egg_value(egg, false, 0.1, 8.0), 0.0, "a zombie near: not now")
	assert_eq(AgentPlan.egg_value(egg, true, 0.7, 30.0), 0.0, "under pressure: not now")


func test_map00_plan_has_an_egg_block_naming_real_things() -> void:
	var egg: Dictionary = AgentPlan.egg_block("map00")
	assert_false(egg.is_empty(), "the Map 0 plan has an egg block")
	assert_true(ResourceLoader.exists("res://data/gravelight/quests/%s.json" % egg.get("quest", "")), "its quest file exists")
	for s: Variant in egg.get("after", []):
		var sd: Dictionary = s as Dictionary
		if sd.has("perk"):
			assert_false(PerkManager.perk_data(StringName(str(sd["perk"]))).is_empty(), "perk %s exists" % sd["perk"])
	var steps: Array = AgentPlan.plan_for("map00").get("steps", [])
	for s2: Variant in steps:
		assert_false((s2 as Dictionary).has("egg"), "the egg never sits in the spend order")
