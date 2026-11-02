extends GutTest
## UPDATE 10 section 7 (T-163), the eggs half: the agent's round-end hunt (BotTrainer.hunt_pick), Full Partner's
## main-egg-first scores (ee.json), the boss-grab break-free data (ai_counters der_kielholer) and the soak's
## --egg-from switch. The Fernflug set-pieces are in test_bot_u10.gd.

var tcfg: Dictionary


func before_all() -> void:
	tcfg = (GLData.load_json("res://data/gravelight/ai/player_bot.json") as Dictionary).get("trainer", {})


# ---------------------------------------------------------------- the round-end hunt

func test_hunt_config_present() -> void:
	for k: String in ["hunt_enabled", "hunt_max_left", "hunt_quiet_m", "hunt_after_s", "hunt_shoot_m"]:
		assert_true(tcfg.has(k), "player_bot.json trainer has %s" % k)


func test_hunt_never_while_the_round_spawns() -> void:
	var rows: Array = [{"d": 20.0, "crawler": true}]
	assert_eq(int(BotTrainer.hunt_pick(rows, 3, false, 99.0, 0.1, tcfg)["idx"]), -1, "zombies still to come: keep training")
	assert_eq(int(BotTrainer.hunt_pick(rows, 0, true, 99.0, 0.1, tcfg)["idx"]), -1, "a special round: no hunt")
	assert_eq(int(BotTrainer.hunt_pick([], 0, false, 99.0, 0.1, tcfg)["idx"]), -1, "nothing up")


func test_hunt_too_many_left() -> void:
	var rows: Array = []
	for i: int in int(tcfg.get("hunt_max_left", 3)) + 1:
		rows.append({"d": 30.0, "crawler": true})
	assert_eq(int(BotTrainer.hunt_pick(rows, 0, false, 99.0, 0.1, tcfg)["idx"]), -1, "more than hunt_max_left: the train still has a job")


func test_hunt_a_crawler_at_once() -> void:
	var rows: Array = [{"d": 25.0, "crawler": false}, {"d": 18.0, "crawler": true}]
	var r: Dictionary = BotTrainer.hunt_pick(rows, 0, false, 0.0, 0.1, tcfg)
	assert_eq(int(r["idx"]), 1, "the nearest is a crawler: it never comes, go for it now")


func test_hunt_a_walker_after_the_quiet() -> void:
	var rows: Array = [{"d": 20.0, "crawler": false}]
	var after: float = float(tcfg.get("hunt_after_s", 5.0))
	var r: Dictionary = BotTrainer.hunt_pick(rows, 0, false, 0.0, 0.1, tcfg)
	assert_eq(int(r["idx"]), -1, "a walker far off: give it a moment to come")
	assert_almost_eq(float(r["quiet"]), 0.1, 0.001, "the quiet time counts up")
	r = BotTrainer.hunt_pick(rows, 0, false, after, 0.1, tcfg)
	assert_eq(int(r["idx"]), 0, "it didn't come for hunt_after_s: go and get it (the stuck Foreman)")


func test_hunt_not_with_a_walker_close() -> void:
	var rows: Array = [{"d": 3.0, "crawler": false}, {"d": 30.0, "crawler": true}]
	var r: Dictionary = BotTrainer.hunt_pick(rows, 0, false, 99.0, 0.1, tcfg)
	assert_eq(int(r["idx"]), -1, "one on its feet within hunt_quiet_m: the train / the fight handles it")
	assert_eq(float(r["quiet"]), 0.0, "and the quiet starts over")


func test_hunt_another_floor_counts_far() -> void:
	# a zombie 2 m away on the floor below (+30 m) is no "close walker"; a crawler further on this floor is nearer
	var rows: Array = [{"d": 32.0, "crawler": false}, {"d": 12.0, "crawler": true}]
	assert_eq(int(BotTrainer.hunt_pick(rows, 0, false, 0.0, 0.1, tcfg)["idx"]), 1)


func test_hunt_gives_up_an_unreachable_straggler() -> void:
	var s: float = float(tcfg.get("hunt_unreach_s", 8.0))
	assert_false(BotTrainer.hunt_unreachable(s - 1.0, 99.0, tcfg), "still getting closer: keep at it")
	assert_false(BotTrainer.hunt_unreachable(99.0, s - 1.0, tcfg), "no closer but the shots land: keep shooting")
	assert_true(BotTrainer.hunt_unreachable(s + 0.5, s + 0.5, tcfg), "no closer and no hits: leave it to the game's no-progress recycle")
	assert_lt(float(tcfg.get("hunt_unreach_s", 8.0)) + 1.0, 40.0, "gives up well inside enemies.json no_progress_respawn_seconds")


func test_hunt_can_be_switched_off() -> void:
	var off: Dictionary = tcfg.duplicate()
	off["hunt_enabled"] = false
	assert_eq(int(BotTrainer.hunt_pick([{"d": 20.0, "crawler": true}], 0, false, 99.0, 0.1, off)["idx"]), -1)


# ---------------------------------------------------------------- the errand window

func test_errand_window_rule() -> void:
	assert_true(BotTrainer.errand_window_rule(true, 0, false, 2, 20.0, 3, true, tcfg), "two left far off, teammates up, an errand: go")
	assert_false(BotTrainer.errand_window_rule(true, 4, false, 2, 20.0, 3, true, tcfg), "still spawning")
	assert_false(BotTrainer.errand_window_rule(true, 0, false, 3, 20.0, 3, true, tcfg), "three left: the train still has a job")
	assert_false(BotTrainer.errand_window_rule(true, 0, false, 2, 4.0, 3, true, tcfg), "one in reach: fight first")
	assert_false(BotTrainer.errand_window_rule(true, 0, false, 2, 20.0, 0, true, tcfg), "solo: the crawler break's job")
	assert_false(BotTrainer.errand_window_rule(true, 0, false, 2, 20.0, 3, false, tcfg), "nothing to do: keep the round")
	assert_false(BotTrainer.errand_window_rule(true, 0, true, 1, 20.0, 3, true, tcfg), "a special round: never")
	assert_false(BotTrainer.errand_window_rule(false, 0, false, 1, 20.0, 3, true, tcfg), "a real break is a break already")


func test_train_order_follows_the_egg_underground() -> void:
	var plan: Dictionary = AgentPlan.plan_for("map01")
	assert_eq(str(AgentPlan.train_order(plan, {})[0]), "map01_headframe", "early: the Headframe")
	var later: Array = AgentPlan.train_order(plan, {"s0_power": true, "s1_vault": true})
	assert_eq(str(later[0]), "map01_turbines", "the vault open: underground, by the Chapel, the Lab and the Core")
	assert_true(later.has("map01_headframe"), "the Headframe stays a fallback")


# ---------------------------------------------------------------- the agent's plan before the egg in a break

func test_buy_first_rule() -> void:
	var ih: Dictionary = {"perk": "ironhide_stout"}
	assert_true(AgentPlan.buy_first_rule(ih, 2500, 21000, 300, 0.78, false), "Ironhide affordable in a break: buy it before the next egg errand")
	assert_false(AgentPlan.buy_first_rule(ih, 2500, 21000, 300, 0.78, true), "mid-round: the trainer owns it, no errand either way")
	assert_false(AgentPlan.buy_first_rule(ih, 2500, 2600, 300, 0.78, false), "can't keep the reserve: the egg may have the break")
	assert_false(AgentPlan.buy_first_rule(ih, 2500, 21000, 300, 0.0, false), "no buy to make (unreachable now): the egg goes on")
	assert_false(AgentPlan.buy_first_rule({"power": true}, 0, 21000, 300, 0.9, false), "the power is the egg's own s0 step")
	assert_false(AgentPlan.buy_first_rule({"crucible": "*"}, 5000, 21000, 300, 0.9, false), "a Crucible teaching waits for the egg")
	assert_true(AgentPlan.buy_first_rule({"door": "door_lab"}, 1500, 2000, 300, 0.6, false), "a plan door (the Lab, Pylon H behind it)")
	assert_false(AgentPlan.buy_first_rule({}, 0, 99999, 300, 1.0, false), "the plan is through")


# ---------------------------------------------------------------- Full Partner: the main egg first

func test_main_egg_beats_every_side_quest() -> void:
	var sc: Dictionary = (GLData.load_json("res://data/gravelight/ai/ee.json") as Dictionary).get("scores", {})
	var worst_main: float = float(sc["main_quest"]) - float(sc["per_m"]) * 120.0   # the hub caps the distance at 120 m
	var best_side: float = float(sc["side_quest"])
	for k: String in ["carry", "shoot_target", "interact_sequence", "hold_zone", "kill_with_weapon", "collect"]:
		best_side = maxf(best_side, float(sc["side_quest"]) + float(sc.get(k, 0.0)))
	assert_gt(worst_main, best_side, "an open main-egg step 120 m away still beats the best side-quest step next door")


# ---------------------------------------------------------------- Full Partner's risky stages

func test_stage_allowed() -> void:
	var drum: Dictionary = {"risky": "trigger", "full_partner": ["trigger"]}
	assert_true(BotEECatalog.stage_allowed(drum, "trigger", false, "full"), "Full Partner pulls the crate for Herr Tamtam unasked")
	assert_false(BotEECatalog.stage_allowed(drum, "trigger", false, "ask"), "When Asked: only on an order")
	assert_true(BotEECatalog.stage_allowed(drum, "trigger", true, "ask"), "ordered: always")
	var bell: Dictionary = {"risky": "shoot"}
	assert_false(BotEECatalog.stage_allowed(bell, "shoot", false, "full"), "no full_partner list: still the player's call")
	assert_true(BotEECatalog.stage_allowed(bell, "", false, "off"), "the safe part of a task")


func test_requiem_full_partner_stages() -> void:
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	var want: Dictionary = {"s4_key": "shoot", "s7_drummer": "trigger"}
	for st: Variant in q["steps"]:
		var sd: Dictionary = st
		var t: Dictionary = BotEECatalog.task_def(sd)
		assert_eq(BotEECatalog.validate(t), PackedStringArray(), "%s bot_task valid" % sd["id"])
		if want.has(str(sd["id"])):
			assert_true(BotEECatalog.stage_allowed(t, str(want[sd["id"]]), false, "full"), "%s: Full Partner may do its risky stage" % sd["id"])
	assert_false(BotEECatalog.validate({"type": "shoot_target", "target": {"group": "g"}, "risky": "shoot", "full_partner": ["trigger"]}).is_empty(),
		"full_partner must name the task's own risky stage")


func test_task_pause_pressure() -> void:
	var c: Dictionary = GLData.load_json("res://data/gravelight/ai/ee.json")
	var base: Dictionary = {"type": "shoot_target", "pressure": 0.7, "teammate_down": false, "round_left": -1, "player_away": false, "was": ""}
	assert_eq(BotEECatalog.pause_reason(base, c), "threat", "the default threshold (0.65) pauses at 0.7")
	var own: Dictionary = base.duplicate()
	own["pause_pressure"] = 0.85
	assert_eq(BotEECatalog.pause_reason(own, c), "", "the drummer's pulls go on at 0.7")
	own["pressure"] = 0.9
	assert_eq(BotEECatalog.pause_reason(own, c), "threat", "and stop at 0.9")
	own["was"] = "threat"
	own["pressure"] = 0.7
	assert_eq(BotEECatalog.pause_reason(own, c), "threat", "resuming waits for the same margin below its own threshold")
	own["pressure"] = 0.6
	assert_eq(BotEECatalog.pause_reason(own, c), "", "back to it")
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	for st: Variant in q["steps"]:
		if str((st as Dictionary)["id"]) == "s7_drummer":
			assert_gt(float(BotEECatalog.task_def(st as Dictionary).get("pause_pressure", 0.0)), 0.65, "s7 carries its own threshold")


# ---------------------------------------------------------------- s4: the Chapel bell and the Foreman

func test_hold_fire_until_the_foreman_is_in_the_chapel() -> void:
	assert_true(BotAim.hold_fire_for_zone(&"E_LIFT", &"F_CHAPEL", 12.0), "on its way in: let it come")
	assert_false(BotAim.hold_fire_for_zone(&"F_CHAPEL", &"F_CHAPEL", 12.0), "in the Chapel: fire")
	assert_false(BotAim.hold_fire_for_zone(&"E_LIFT", &"F_CHAPEL", 2.0), "at arm's length: self-defence first")
	assert_false(BotAim.hold_fire_for_zone(&"E_LIFT", &"", 12.0), "no kill condition armed: shoot as ever")


func test_rally_on_the_lit_bell() -> void:
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	var t: Dictionary = {}
	for st: Variant in q["steps"]:
		if str((st as Dictionary)["id"]) == "s4_key":
			t = BotEECatalog.task_def(st as Dictionary)
	var was: bool = GameState.has_flag(&"chapel_bell_lit")
	GameState.set_flag(&"chapel_bell_lit", false)
	assert_false(BotEEHub.rally_now(t), "unlit: one bot goes to light it")
	GameState.set_flag(&"chapel_bell_lit", true)
	assert_true(BotEEHub.rally_now(t), "lit: every free bot joins the Chapel hold")
	GameState.set_flag(&"chapel_bell_lit", was)
	assert_false(BotEEHub.rally_now({"type": "shoot_target", "target": {"group": "g"}}), "no then_hold: no rally")


# ---------------------------------------------------------------- wonders from the bench

func test_wonder_wanted() -> void:
	var eco: Dictionary = GLData.load_json("res://data/gravelight/ai/economy.json")
	var bell: float = BotEconomy.tier_of("totenglocke", false, eco)
	assert_gt(bell, 5.0, "the Totenglocke is a wonder tier")
	assert_true(BotEconomy.wonder_wanted(bell, 3.2, false, eco), "over an MP40: take it")
	assert_false(BotEconomy.wonder_wanted(bell, bell + 1.0, false, eco), "every gun held is better: leave it")
	assert_true(BotEconomy.wonder_wanted(0.0, 9.0, true, eco), "a free slot: always")


# ---------------------------------------------------------------- boss grabs

func test_kielholer_counter() -> void:
	var c: Dictionary = BotAIData.counter(&"der_kielholer")
	assert_true(bool(c.get("boss", false)), "the Kielholer is a boss to the bots")
	assert_true(bool(c.get("break_grab", false)), "teammates shoot him off a grabbed bot")
	assert_true(bool(c.get("never_melee", false)), "nobody walks up to knife him (the held bot knifes itself free: BotAim.break_free)")
	assert_gt(float(c.get("keep_distance_m", 0.0)), 2.2, "out of the grab's 2.2 m")
	assert_true(bool(c.get("spread_out", false)), "spread against the chain sweep")


func test_break_free_exists() -> void:
	var names: Array = []
	for m: Dictionary in (load("res://gravelight/bots/bot_aim.gd") as Script).get_script_method_list():
		names.append(str(m["name"]))
	assert_has(names, "break_free", "BotAim.break_free: the held bot's way out")


# ---------------------------------------------------------------- the soak switch

func test_soak_egg_from_flag() -> void:
	var src: String = FileAccess.get_file_as_string("res://tools_src/ai_soak.gd")
	assert_string_contains(src, "--egg-from=", "ai_soak takes --egg-from")
	assert_string_contains(src, "debug_skipto", "and skips the egg there with its prerequisites")
