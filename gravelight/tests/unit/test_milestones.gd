extends GutTest
## Milestone rewards and the tonic bottle (T-078): rounds.json "milestones", PowerupManager.milestone_drops /
## pick_gift (pure) and gift_tonic against the real PerkManager (no map: every perks.json tonic is on offer).

const PID: int = 42

var rounds: Dictionary
var pcfg: Dictionary


func _rng(s: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = s
	return r


func before_all() -> void:
	rounds = GLData.load_json("res://data/gravelight/rounds.json")
	pcfg = GLData.load_json("res://data/gravelight/powerups.json")


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = false
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	Economy.reset([PID])


func after_all() -> void:
	GameState.player_ids = [1]
	PerkManager.meta_gate_override = -1
	PerkManager.reset_match()
	Economy.reset([1])


func test_round_five_is_a_tonic_and_a_resupply() -> void:
	var d: Array[StringName] = PowerupManager.milestone_drops(5, rounds)
	assert_eq(d, [&"tonic_bottle", &"resupply"] as Array[StringName])
	assert_eq(PowerupManager.milestone_drops(4, rounds).size(), 0)
	assert_eq(PowerupManager.milestone_drops(6, rounds).size(), 0)
	assert_eq(PowerupManager.milestone_drops(5, {}).size(), 0, "no table, no milestone")


func test_milestones_are_data_driven() -> void:
	var r2: Dictionary = {"milestones": {"10": ["double_scrip"], "5": ["resupply"]}}
	assert_eq(PowerupManager.milestone_drops(10, r2), [&"double_scrip"] as Array[StringName])
	assert_eq(PowerupManager.milestone_drops(5, r2), [&"resupply"] as Array[StringName])


func test_every_milestone_id_is_a_power_up() -> void:
	var names: Dictionary = pcfg["names"]
	for k: Variant in (rounds["milestones"] as Dictionary).keys():
		if str(k).begins_with("_"):
			continue
		for id: Variant in rounds["milestones"][k]:
			assert_true(names.has(str(id)), "milestone %s: %s has a name" % [k, id])


func test_tonic_bottle_never_in_the_bag() -> void:
	assert_false((pcfg["bag"] as Array).has("tonic_bottle"))
	assert_false((pcfg.get("conditional", {}) as Dictionary).has("tonic_bottle"))


func test_pick_gift_rules() -> void:
	var all: Array = [&"ironhide_stout", &"second_wind", &"marathon_malt"]
	var g: Dictionary = PowerupManager.pick_gift([&"ironhide_stout"], all, 1, 4, [&"second_wind"], [], 1500, _rng(1))
	assert_eq(g["kind"], "perk")
	assert_eq(g["perk"], &"marathon_malt", "not owned, not excluded")
	g = PowerupManager.pick_gift(all, all, 3, 4, [], [&"marathon_malt"], 1500, _rng(1))
	assert_eq(g["kind"], "tier", "every map tonic owned: a tier instead")
	g = PowerupManager.pick_gift([&"a", &"b", &"c", &"d"], all, 4, 4, [], [&"b"], 1500, _rng(1))
	assert_eq(g["kind"], "tier", "cap full: a tier")
	assert_eq(g["perk"], &"b")
	g = PowerupManager.pick_gift([&"a", &"b", &"c", &"d"], all, 4, 4, [], [], 1500, _rng(1))
	assert_eq(g, {"kind": "scrip", "scrip": 1500}, "cap full, nothing to upgrade: Scrip")


func test_pick_gift_is_random_over_the_pool() -> void:
	var all: Array = [&"a", &"b", &"c"]
	var seen: Dictionary = {}
	var r: RandomNumberGenerator = _rng(3)
	for i: int in 60:
		seen[PowerupManager.pick_gift([], all, 0, 4, [], [], 0, r)["perk"]] = true
	assert_eq(seen.size(), 3)


func test_gift_tonic_grants_a_free_perk_without_power() -> void:
	var before: int = Economy.get_scrip(PID)
	var g: Dictionary = PowerupManager.gift_tonic(PID)
	assert_eq(g.get("kind"), "perk")
	assert_eq(PerkManager.owned(PID).size(), 1)
	assert_true(PerkManager.has_perk(PID, StringName(g["perk"])))
	assert_eq(Economy.get_scrip(PID), before, "free")


func test_gift_tonic_respects_the_cap() -> void:
	for id: StringName in [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt"]:
		PerkManager.grant(PID, id)
	var g: Dictionary = PowerupManager.gift_tonic(PID)
	assert_eq(PerkManager.owned(PID).size(), 4, "no fifth tonic")
	assert_eq(g.get("kind"), "tier", "a tier on a carried tonic (mastery gate off in this test)")
	assert_eq(PerkManager.tier_of(PID, StringName(g["perk"])), 2)


func test_gift_tonic_full_cap_and_locked_tiers_pay_scrip() -> void:
	PerkManager.meta_gate_override = 1   # no tier unlocked by this test profile... unless it has mastery
	for id: StringName in [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt"]:
		PerkManager.grant(PID, id)
	var locked: bool = true
	for id: StringName in [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt"]:
		if PerkManager.tier_unlocked(id, 2):
			locked = false
	var before: int = Economy.get_scrip(PID)
	var g: Dictionary = PowerupManager.gift_tonic(PID)
	if locked:
		assert_eq(g.get("kind"), "scrip")
		assert_eq(Economy.get_scrip(PID), before + int(pcfg["tonic_bottle"]["full_cap_scrip"]))
	else:
		assert_eq(g.get("kind"), "tier", "the profile has a tier unlocked")


func test_solo_second_wind_gone_is_skipped() -> void:
	PerkManager.second_wind_gone = true
	for i: int in 3:   # every other tonic but Second Wind, then one more gift: never Second Wind
		var g: Dictionary = PowerupManager.gift_tonic(PID)
		assert_ne(g.get("perk", &""), &"second_wind")
