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


func test_hunt_can_be_switched_off() -> void:
	var off: Dictionary = tcfg.duplicate()
	off["hunt_enabled"] = false
	assert_eq(int(BotTrainer.hunt_pick([{"d": 20.0, "crawler": true}], 0, false, 99.0, 0.1, off)["idx"]), -1)


# ---------------------------------------------------------------- Full Partner: the main egg first

func test_main_egg_beats_every_side_quest() -> void:
	var sc: Dictionary = (GLData.load_json("res://data/gravelight/ai/ee.json") as Dictionary).get("scores", {})
	var worst_main: float = float(sc["main_quest"]) - float(sc["per_m"]) * 120.0   # the hub caps the distance at 120 m
	var best_side: float = float(sc["side_quest"])
	for k: String in ["carry", "shoot_target", "interact_sequence", "hold_zone", "kill_with_weapon", "collect"]:
		best_side = maxf(best_side, float(sc["side_quest"]) + float(sc.get(k, 0.0)))
	assert_gt(worst_main, best_side, "an open main-egg step 120 m away still beats the best side-quest step next door")


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
