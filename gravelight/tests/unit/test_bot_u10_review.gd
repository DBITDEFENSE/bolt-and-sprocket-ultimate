extends GutTest
## U10 review fixes on the T-172 bot egg code (DECISIONS T-176): the egg's route doors keep the human's first pick
## and the reserve, the hunt pause has an end, the forced hunt prefers a straggler it can reach.

var hunt: Dictionary


func before_all() -> void:
	hunt = BotAIData.combat("hunt") as Dictionary


func test_egg_door_keeps_the_humans_first_pick() -> void:
	var e: Dictionary = {"doors": {"human_opened_needed": true, "bot_led": true}}
	assert_false(BotEconomy.egg_door_allowed(e, false, 0), "with a human who opened nothing: never the first door")
	assert_true(BotEconomy.egg_door_allowed(e, false, 1), "once the human opened one: the egg's route doors too")
	assert_true(BotEconomy.egg_door_allowed(e, true, 0), "no human in the match: the squad's own call")
	assert_false(BotEconomy.egg_door_allowed({"doors": {"bot_led": false}}, true, 0), "bot_led off holds")
	assert_true(BotEconomy.egg_door_allowed({"doors": {"human_opened_needed": false}}, false, 0), "the rule switched off")


func test_hunt_pause_has_an_end() -> void:
	var after: float = float(hunt.get("ee_pause_after_s", 45.0))
	var cap: float = float(hunt.get("ee_pause_max_s", 0.0))
	assert_gt(cap, 0.0, "combat.json hunt.ee_pause_max_s")
	assert_false(BotEE.hunt_pause_on(after - 1.0, hunt), "before ee_pause_after_s: the errand goes on")
	assert_true(BotEE.hunt_pause_on(after + 1.0, hunt), "then it waits for the hunt")
	assert_false(BotEE.hunt_pause_on(after + cap + 1.0, hunt), "a hunt that never gets there lets it go again")
	assert_false(BotEE.hunt_pause_on(0.0, hunt), "no stall: no pause")


func test_forced_hunt_prefers_a_reachable_straggler() -> void:
	assert_gt(BotSquad.hunt_rank(true, false), BotSquad.hunt_rank(false, true), "a walker we can reach beats a wedged Foreman")
	assert_gt(BotSquad.hunt_rank(true, true), BotSquad.hunt_rank(true, false), "between reachable ones, the boss first (as before)")
	assert_gt(BotSquad.hunt_rank(false, true), BotSquad.hunt_rank(false, false), "and between unreachable ones")


func test_gather_defaults_match_the_data() -> void:
	var hr: Dictionary = (GLData.load_json("res://data/gravelight/ai/ee.json") as Dictionary).get("hold_rally", {})
	var src: String = FileAccess.get_file_as_string("res://gravelight/bots/bot_ee.gd")
	assert_true(src.contains("hr.get(\"gather_max_s\", %.1f)" % float(hr["gather_max_s"])), "the code default is ee.json's gather_max_s")
	assert_true(src.contains("hr.get(\"gather_need\", %d)" % int(hr["gather_need"])), "the code default is ee.json's gather_need")
