extends GutTest
## U10 T-172: the bots finish Kaltenbrunn's and Totenhafen's eggs: shopping breaks that buy (around the bot, perk_first,
## only with something on the list), the squad together in hot rounds (ee.json together), the hold rally (joiners go
## to the one hold, never start their own), the pylons' start wait, the egg's Crucible gun, the s1 priority.

var c: Dictionary


func before_all() -> void:
	c = GLData.load_json("res://data/gravelight/ai/ee.json")


func test_data_blocks() -> void:
	var sb: Dictionary = c.get("shop_break", {})
	assert_gt(float(sb.get("range_m", 0.0)), 26.0, "the break shops wider than the leader's 26 m")
	assert_true((sb.get("perk_first", []) as Array).has("ironhide_stout"), "armour first")
	assert_true(bool(sb.get("between_steps", false)), "a break between steps too")
	for k: String in ["together", "hold_rally", "egg_gun"]:
		assert_false((c.get(k, {}) as Dictionary).is_empty(), "ee.json has %s" % k)
	assert_gt(float(c.get("start_wait_s", 0.0)), 0.0, "the pylons' start wait")
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	for s: Variant in q["steps"]:
		if str((s as Dictionary)["id"]) == "s1_vault":
			assert_gt(float(((s as Dictionary)["bot_task"] as Dictionary).get("priority", 0.0)), 0.0, "the pylons come first once the power is on")


func test_perk_first() -> void:
	var plan: Array = ["ironhide_stout", "second_wind", "ledger_lager", "@weapon", "marathon_malt"]
	assert_eq(BotEconomy.plan_with_first(plan, ["ironhide_stout", "second_wind", "marathon_malt"]),
		["ironhide_stout", "second_wind", "marathon_malt", "ledger_lager", "@weapon"], "speed before the bank")
	assert_eq(BotEconomy.plan_with_first(plan, []), plan, "no list: the plan as it is")
	assert_eq(BotEconomy.plan_with_first(["second_wind"], ["ironhide_stout"]), ["second_wind"], "never a perk the plan leaves out")


func test_apart_rule() -> void:
	var tg: Dictionary = c["together"]
	var far: float = float(tg["max_m"]) + 5.0
	assert_true(BotEE.apart_rule(tg, true, false, false, far, 0.0), "alone, far, in a hot round: apart")
	assert_true(BotEE.apart_rule(tg, true, false, false, 4.0, float(tg["storey_dy"]) + 1.0), "another storey: apart")
	assert_false(BotEE.apart_rule(tg, true, false, false, 4.0, 0.0), "with a teammate: fine")
	assert_false(BotEE.apart_rule(tg, false, false, false, far, 0.0), "a quiet round: fine")
	assert_false(BotEE.apart_rule(tg, true, true, false, far, 0.0), "holding a running hold: never (the others come)")
	assert_false(BotEE.apart_rule(tg, true, false, true, far, 0.0), "an exempt type")
	assert_false(BotEE.apart_rule({}, true, false, false, far, 0.0), "no block: the old behaviour")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.0, "apart": true}, c), "apart", "apart pauses the errand")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.9, "apart": true}, c), "threat", "a fight first")
	assert_eq(BotEECatalog.pause_reason({"type": "collect", "pressure": 0.0, "apart": true, "shop": true}, c), "apart", "back to the squad before shopping")


func test_joiner_never_starts_its_own_hold() -> void:
	var p1: Node3D = autofree(Node3D.new())
	var p2: Node3D = autofree(Node3D.new())
	var t: Dictionary = {"type": "hold_zone", "anchors": {"group": "pylons"}, "start": "interact"}
	var w: Dictionary = {"joiner": true, "anchors": [{"node": p1, "state": "start_ok", "d": 2.0}]}
	assert_eq(str(BotEE.plan_hold(t, w)["do"]), "near", "a joiner goes to the teammate's hold and waits")
	assert_eq(BotEE.plan_hold(t, w)["node"], p1)
	assert_eq(str(BotEE.plan_hold(t, {"joiner": true, "anchors": [{"node": p2, "state": "charging", "d": 9.0}]})["do"]), "hold", "and holds it once it runs")
	assert_eq(str(BotEE.plan_hold(t, {"joiner": true, "anchors": [{"node": p2, "state": "done", "d": 9.0}]})["do"]), "done", "the hold is done: so is the joiner")
	assert_eq(str(BotEE.plan_hold(t, {"anchors": [{"node": p1, "state": "start_ok", "d": 2.0}]})["do"]), "use", "the leader starts it")


func test_egg_gun_ok() -> void:
	assert_true(BotEconomy.egg_gun_ok(true, true, 5600, 5000, 500), "the designated bot with the price: feed it")
	assert_false(BotEconomy.egg_gun_ok(false, true, 9000, 5000, 500), "only the designated bot")
	assert_false(BotEconomy.egg_gun_ok(true, true, 5300, 5000, 500), "not under the reserve")
	assert_false(BotEconomy.egg_gun_ok(true, false, 9000, 5000, 500), "a gun that can learn")
