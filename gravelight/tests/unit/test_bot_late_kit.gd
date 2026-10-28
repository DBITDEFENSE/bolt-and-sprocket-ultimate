extends GutTest
## UPDATE 08 section 3 (T-130): the bots' late kit, the pure parts (the live run is smoke_late_kit).


func test_it_is_due_from_round_twenty_five() -> void:
	var lcfg: Dictionary = GLData.table("bots")["late_kit"]
	assert_eq(int(lcfg["round"]), 25)
	assert_false(BotSquad.late_kit_due(24, lcfg, {}), "round 24: no")
	assert_true(BotSquad.late_kit_due(25, lcfg, {}), "round 25: yes")
	assert_true(BotSquad.late_kit_due(40, lcfg, {}))
	assert_false(BotSquad.late_kit_due(30, lcfg, {"bot_bonus_perk": false}), "the Bot Bonus Perk toggle turns it off")
	assert_false(BotSquad.late_kit_due(30, lcfg, {"classic_rules": true}), "Classic Rules turns it off")
	assert_false(BotSquad.late_kit_due(30, {"enabled": false, "round": 25}, {}))


func test_the_weapon_and_tier_are_data() -> void:
	var lcfg: Dictionary = GLData.table("bots")["late_kit"]
	assert_eq(str(lcfg["weapon"]), "thompson_up")
	assert_eq(int(lcfg["crucible_tier"]), 2)
	assert_eq(int(lcfg["perk_tier"]), 3)
	assert_true((GLData.table("weapons")["upgraded"] as Dictionary).has("thompson_up"))


func test_the_late_tonic_is_never_one_already_taken() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var pool: Array = ["ironhide_stout", "second_wind", "trigger_tonic", "hawkeye_brandy"]
	for s: int in 30:
		rng.seed = s
		var pick: StringName = BotSquad.pick_late_perk(pool, [&"ironhide_stout", "second_wind"], ["hawkeye_brandy"], rng)
		assert_eq(pick, &"trigger_tonic", "the only one left")
	assert_eq(BotSquad.pick_late_perk(pool, pool, [], rng), &"", "nothing left: none")
