extends GutTest
## Update 03 tuning (T-058): the self-led squad (no human in the match or leading: the bots throw the power
## themselves and open only the doors they have a use for), the power rule with a human (only on an order; perks
## once the human threw it), the weak start pistol, the fair revive rate (a down no bot could reach isn't held
## against the bots) and the soak dummy's realistic kit. Pure rules only.

var eco: Dictionary
var combat: Dictionary


func before_all() -> void:
	BotAIData.reload()
	eco = BotAIData.table("economy")
	combat = BotAIData.table("combat")


# ---------------------------------------------------------------- the power rule

func test_the_power_switch_with_a_human_stays_theirs() -> void:
	assert_false(BotEconomy.may_touch("power", false, false, false, false), "a human leads: never on its own")
	assert_true(BotEconomy.may_touch("power", true, false, false, false), "ordered onto it")
	assert_false(BotEconomy.may_touch("power", false, false, true, false), "'the human did that step' is the power being on: nothing left to throw")


func test_a_self_led_squad_throws_the_power_but_still_leaves_eggs_traps_and_parts() -> void:
	assert_true(BotEconomy.may_touch("power", false, false, false, true), "no human leads: the squad is its own leader")
	for k: String in ["quest", "part", "trap"]:
		assert_false(BotEconomy.may_touch(k, false, false, false, true), "%s stays off limits even self-led" % k)
	assert_true(BotEconomy.may_touch("perk", false, false, false, true))


func test_once_the_human_threw_the_power_the_bots_drink() -> void:
	# perk_wanted only lists powered machines (`available`): before the power nothing, after it the plan's next
	var plan: Array = eco.get("perk_plan", [])
	var owned: Array = ["ironhide_stout", "second_wind"]
	assert_eq(BotEconomy.perk_wanted(eco, plan, owned, {}, "smg", true, 2, 9000, 500), &"", "no powered machine: nothing")
	var avail: Dictionary = {"twin_barrel": 2000, "trigger_tonic": 3000, "hawkeye_brandy": 1500}
	assert_eq(BotEconomy.perk_wanted(eco, plan, owned, avail, "smg", true, 2, 9000, 500), &"trigger_tonic", "the Thompson's perk next")


func test_self_led_doors_go_to_the_power_first() -> void:
	assert_true(BotEconomy.self_led_door_ok(true, false, 1600, 1500, 1500, 300), "the door on the way to the power")
	assert_false(BotEconomy.self_led_door_ok(false, false, 9000, 750, 0, 300), "a door it has no use for (the attic)")
	assert_false(BotEconomy.self_led_door_ok(false, true, 2600, 1000, 1500, 300), "a route's door, but the power door's price must stay in hand")
	assert_true(BotEconomy.self_led_door_ok(false, true, 2900, 1000, 1500, 300), "rich enough for both")
	assert_true(BotEconomy.self_led_door_ok(false, true, 1400, 1000, 0, 300), "power on (not saving): a route's door")


func test_the_data_has_the_power_block() -> void:
	var pw: Dictionary = eco.get("power", {})
	assert_false(pw.is_empty(), "economy.json power")
	assert_gt(float((eco.get("priorities", {}) as Dictionary).get("power", 0.0)), 0.8, "the power outranks ordinary buys")
	assert_true(bool(pw.get("self_led_useful_doors_only", false)))


func test_routes_have_a_home() -> void:
	var homes: int = 0
	for r: TrainingRoute in TrainingRoute.all_for_map("map00"):
		if r.home > 0.0:
			homes += 1
	assert_gt(homes, 0, "Map 0 has a home loop for a self-led squad")


func test_bot_led_means_no_human_leading() -> void:
	var squad: BotSquad = BotSquad.new()
	var map: MapRoot = MapRoot.new()
	squad.map = map
	assert_true(squad.bot_led(), "no human player at all")
	var h: Player = Player.new()
	map.player = h
	assert_false(squad.bot_led(), "a human in the match leads")
	assert_false(squad.bots_alone(), "a human in the match: the power is theirs")
	h.spectating = true
	assert_true(squad.bot_led(), "the human bled out / sits it out: the squad leads itself")
	if Net.session == null:
		assert_true(squad.bots_alone(), "sitting the match out with no co-op life-cycle: bots alone")
	h.free()
	map.free()
	squad.free()


# ---------------------------------------------------------------- the weak start pistol

func test_a_plain_pistol_is_no_answer_late() -> void:
	var wc: Dictionary = combat["weapons"]
	var hot_late: Dictionary = {"crowd": 3, "boss": false, "close": true, "danger": true, "near": true, "weak_pistol": true}
	var hot_early: Dictionary = hot_late.duplicate()
	hot_early["weak_pistol"] = false
	assert_gt(BotAim.weapon_value("pistol", 8, 40, 8, hot_early, wc, {}), BotAim.weapon_value("smg", 0, 180, 30, hot_early, wc, {}),
		"early: the pistol is still worth a swap with the Thompson dry")
	assert_gt(BotAim.weapon_value("smg", 0, 180, 30, hot_late, wc, {}), BotAim.weapon_value("pistol", 8, 40, 8, hot_late, wc, {}),
		"late: reload the Thompson instead of an 8-round pistol against 650+ health")
	assert_gt(BotAim.weapon_value("pistol", 8, 40, 8, hot_late, wc, {}, true), BotAim.weapon_value("smg", 0, 180, 30, hot_late, wc, {}),
		"an upgraded pistol is still a gun")
	assert_gt(BotAim.weapon_value("pistol", 8, 40, 8, hot_late, wc, {}), 0.0, "with nothing else it is still something")


# ---------------------------------------------------------------- the fair revive rate

func test_a_down_no_bot_could_reach_is_excused() -> void:
	var eps: Array = [
		{"pid": 2, "t_down": 10.0, "outcome": "revived", "t_end": 16.0, "attempts": 1, "attempts_ok": 1, "reach_s": 6.0},
		{"pid": 3, "t_down": 20.0, "outcome": "bled", "t_end": 65.0, "attempts": 0, "attempts_ok": 0, "reach_s": 30.0},   # bots stood by: failed
		{"pid": 4, "t_down": 50.0, "outcome": "bled", "t_end": 95.0, "attempts": 0, "attempts_ok": 0, "reach_s": 2.0},    # every bot down: excused
		{"pid": 2, "t_down": 80.0, "outcome": "pending", "t_end": -1.0, "attempts": 0, "attempts_ok": 0, "reach_s": 4.0},  # the collapse: excused
		{"pid": 3, "t_down": 70.0, "outcome": "pending", "t_end": -1.0, "attempts": 0, "attempts_ok": 0, "reach_s": 20.0}, # open, reachable: failed
	]
	var s: Dictionary = BotMetrics.revive_summary(eps, 100.0)
	assert_almost_eq(float(s["success_rate"]), 0.25, 0.0001, "the old rule: 1 revived of 4 judged")
	assert_eq(int(s["excused"]), 2)
	assert_eq(int(s["fair_failed"]), 2)
	assert_almost_eq(float(s["fair_rate"]), 1.0 / 3.0, 0.0001, "1 revived of 3 a bot could have reached")


func test_old_episodes_without_reach_count_as_reachable() -> void:
	var eps: Array = [{"pid": 2, "t_down": 0.0, "outcome": "bled", "t_end": 45.0, "attempts": 0, "attempts_ok": 0}]
	var s: Dictionary = BotMetrics.revive_summary(eps, 50.0)
	assert_eq(int(s["fair_failed"]), 1)
	assert_eq(int(s["excused"]), 0)


# ---------------------------------------------------------------- the soak dummy's kits

func test_the_soak_dummy_kits() -> void:
	var Dummy: GDScript = load("res://tools_src/soak_dummy.gd")
	var d: RefCounted = Dummy.new()
	assert_eq(str(d.get("kit")), "baseline", "the baseline player by default (apples to apples with the Update 03 baseline)")
	var perks: Array = d.get("REALISTIC_PERKS") if d.get("REALISTIC_PERKS") != null else Dummy.get_script_constant_map().get("REALISTIC_PERKS", [])
	assert_true(perks.has(&"ironhide_stout") and perks.has(&"second_wind"), "the realistic player drinks Ironhide and Second Wind")
