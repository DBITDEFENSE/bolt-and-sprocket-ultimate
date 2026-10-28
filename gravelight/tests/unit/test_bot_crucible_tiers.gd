extends GutTest
## T-121: bots teach their guns a second and a third time at the Crucible. They feed their best gun first (a taught
## gun counts its teachings), save the re-teach price from the crate and the wall guns, and the bot-mode agent's map
## plans end with a second and a third teaching.

var eco: Dictionary


func before_all() -> void:
	eco = BotAIData.table("economy")


func _taught(base: StringName, tier: int) -> WeaponInstance:
	var w: WeaponInstance = WeaponInstance.create(base)
	var up: StringName = w.upgrade_id()
	var t: WeaponInstance = WeaponInstance.create(up)
	t.tier = tier
	return t


func test_tier_of_counts_teachings() -> void:
	var base: float = BotEconomy.tier_of("thompson", false, eco)
	var once: float = BotEconomy.tier_of("thompson", true, eco, 1)
	var twice: float = BotEconomy.tier_of("thompson", true, eco, 2)
	var thrice: float = BotEconomy.tier_of("thompson", true, eco, 3)
	assert_almost_eq(once, base + float(eco["upgraded_tier_bonus"]), 0.001, "the old rule for a gun taught once")
	assert_gt(twice, once)
	assert_gt(thrice, twice)
	assert_gt(BotEconomy.tier_of("thompson", true, eco, 2), float(eco["crate"]["rich_until_tier"]),
		"a Thompson taught twice no longer reads as 'no good gun yet' to the rich-crate rule")


func test_best_to_teach_prefers_the_taught_main_gun() -> void:
	var pistol: WeaponInstance = WeaponInstance.create(&"m1911")
	var mp40: WeaponInstance = WeaponInstance.create(&"mp40")
	var tommy: WeaponInstance = _taught(&"thompson", 1)
	assert_eq(BotBrain.best_to_teach([pistol, mp40, tommy], 1, eco), 2, "the taught Thompson before a fresh MP40, even with the MP40 in hand")
	assert_eq(BotBrain.best_to_teach([pistol, mp40], 0, eco), 1, "pistols last")
	var maxed: WeaponInstance = _taught(&"thompson", WeaponInstance.max_tier())
	assert_eq(BotBrain.best_to_teach([pistol, maxed], 1, eco), 0, "a gun at the top tier can't learn more: next best")
	assert_eq(Crucible.action_for(maxed), &"full")


func test_reteach_save() -> void:
	var c: Dictionary = eco["crucible"]
	var mr: int = int(c["min_round"])
	assert_eq(BotEconomy.reteach_save(eco, 3.6, true, 1, 3, mr, true, 7500), 7500, "taught once: save the second teaching")
	assert_eq(BotEconomy.reteach_save(eco, 3.6, true, 2, 3, mr, true, 10000), 10000, "taught twice: save the third")
	assert_eq(BotEconomy.reteach_save(eco, 3.6, true, 3, 3, mr, true, 10000), 0, "top tier: nothing to save for")
	assert_eq(BotEconomy.reteach_save(eco, 3.6, false, 0, 3, mr, true, 5000), 0, "the first teaching is not saved for (the old rule)")
	assert_eq(BotEconomy.reteach_save(eco, 3.6, true, 1, 3, mr, false, 7500), 0, "no powered Crucible")
	assert_eq(BotEconomy.reteach_save(eco, 3.6, true, 1, 3, mr - 1, true, 7500), 0, "before min_round")
	assert_eq(BotEconomy.reteach_save(eco, 1.0, true, 1, 3, mr, true, 7500), 0, "a gun under min_tier")


func test_saving_holds_back_the_crate() -> void:
	var rich: int = int(eco["crate"]["rich_scrip"]) + 500
	var t1: float = BotEconomy.tier_of("thompson", true, eco, 1)
	assert_true(BotEconomy.crate_wanted(eco, rich, 950, t1, 12, 800), "without saving a rich bot rolls")
	assert_false(BotEconomy.crate_wanted(eco, rich, 950, t1, 12, 800 + 7500), "saving for the re-teach: no roll")


func test_crucible_prices_climb() -> void:
	var econ: Dictionary = GLData.table("economy")
	assert_eq(Crucible.price_for(&"upgrade", econ, 0), int(econ["crucible_upgrade"]))
	assert_eq(Crucible.price_for(&"upgrade", econ, 1), int(econ["crucible_upgrade_tiers"]["2"]))
	assert_eq(Crucible.price_for(&"upgrade", econ, 2), int(econ["crucible_upgrade_tiers"]["3"]))


func test_agent_plan_crucible_tier_steps() -> void:
	var st: Dictionary = {"round": 20, "guns": [{"id": "thompson", "upgraded": true, "tier": 5.1, "ctier": 1}]}
	assert_true(AgentPlan.step_done({"crucible": "*"}, st))
	assert_false(AgentPlan.step_done({"crucible": "*", "tier": 2}, st), "taught once is not taught twice")
	(st["guns"][0] as Dictionary)["ctier"] = 2
	assert_true(AgentPlan.step_done({"crucible": "*", "tier": 2}, st))
	assert_false(AgentPlan.step_done({"crucible": "*", "tier": 3}, st))
	assert_true(AgentPlan.allows({"crucible": "*", "tier": 3}, "crucible", "thompson_up"))


func test_every_plan_with_a_crucible_ends_with_two_more_teachings() -> void:
	var plans: Dictionary = BotAIData.table("player_bot")["plans"]
	var n: int = 0
	for k: Variant in plans.keys():
		if not (plans[k] is Dictionary) or not (plans[k] as Dictionary).has("steps"):
			continue
		var steps: Array = plans[k]["steps"]
		if not steps.any(func(s: Dictionary) -> bool: return s.has("crucible")):
			continue
		n += 1
		assert_eq(int((steps[-2] as Dictionary).get("tier", 0)), 2, "%s: the second teaching" % k)
		assert_eq(int((steps[-1] as Dictionary).get("tier", 0)), 3, "%s: the third teaching" % k)
	assert_gt(n, 3)
