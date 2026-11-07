extends GutTest
## T-186: the bots' round-30 kit (every tonic and a Crucible-taught main gun), the pure parts and the quiet grant.
## The live run (a round-30 start, a bleed-out respawn, a revive, the toggle) is smoke_late_kit.

const PID: int = 1


func after_each() -> void:
	PerkManager.reset_match()
	GLSettings.values["classic_rules"] = false
	GLSettings.values["bot_bonus_perk"] = true


func _rcfg() -> Dictionary:
	return GLData.table("bots")["r30_kit"]


func _all_perks() -> Array:
	return (GLData.table("perks")["perks"] as Dictionary).keys()


func _gun(id: String, tier: int = -1) -> WeaponInstance:
	var w: WeaponInstance = WeaponInstance.create(StringName(id))
	if tier >= 0:
		w.tier = tier
	return w


func test_the_round_gate_and_the_toggles() -> void:
	var r: Dictionary = _rcfg()
	assert_false(BotSquad.r30_kit_due(29, r, {}), "round 29: no")
	assert_true(BotSquad.r30_kit_due(30, r, {}), "round 30: yes")
	assert_true(BotSquad.r30_kit_due(55, r, {}))
	assert_false(BotSquad.r30_kit_due(31, r, {"bot_bonus_perk": false}), "the Bot Bonus Perk toggle turns it off")
	assert_false(BotSquad.r30_kit_due(31, r, {"classic_rules": true}), "Classic Rules turns it off")
	assert_false(BotSquad.r30_kit_due(31, {"enabled": false, "from_round": 30}, {}))
	assert_false(BotSquad.r30_kit_due(31, {}, {}), "no block: nothing")


func test_the_data() -> void:
	var r: Dictionary = _rcfg()
	assert_eq(int(r["from_round"]), 30)
	assert_eq(str(r["perks"]), "all")
	assert_eq(int(r["weapon_tier"]), 2, "twice taught, as the late kit's gun; the third teaching stays the bot's to buy")
	assert_false(bool(r["companions"]), "Jakub and the map companions shop for themselves (T-177)")
	assert_false(bool(r["on_revive"]), "a revive waits for the next round start")
	assert_true((GLData.table("weapons")["upgraded"] as Dictionary).has(str(r["fallback_weapon"])))
	assert_true(int(r["from_round"]) > int((GLData.table("bots")["late_kit"] as Dictionary)["round"]), "it stacks on the round-25 kit")
	assert_true(int(r["weapon_tier"]) <= WeaponInstance.max_tier())


func test_all_means_every_tonic_in_perks_json() -> void:
	var ids: Array = BotSquad.r30_perk_ids(_rcfg(), _all_perks())
	assert_eq(ids.size(), _all_perks().size())
	for pk: Variant in _all_perks():
		assert_true(ids.has(str(pk)), str(pk))
	var ex: Array = BotSquad.r30_perk_ids({"perks": "all", "exclude": ["magpie_mead"]}, _all_perks())
	assert_false(ex.has("magpie_mead"))
	assert_eq(ex.size(), _all_perks().size() - 1)
	assert_eq(BotSquad.r30_perk_ids({"perks": ["second_wind", "no_such_tonic", "second_wind"]}, _all_perks()), ["second_wind"],
		"a list: known ids once")


func test_the_main_gun_is_taught() -> void:
	var eco: Dictionary = BotAIData.table("economy")
	assert_eq(BotSquad.r30_gun_plan([_gun("m1911"), _gun("thompson")], eco, 2), {"do": "teach", "slot": 1}, "the long gun, not the pistol")
	assert_eq(BotSquad.r30_gun_plan([_gun("m1911"), _gun("thompson_up", 2)], eco, 2), {"do": "ok", "slot": 1}, "the Chicago Lament II is enough")
	assert_eq(BotSquad.r30_gun_plan([_gun("thompson_up", 1), _gun("mp40")], eco, 2), {"do": "teach", "slot": 0}, "taught once: taught again")
	assert_eq(BotSquad.r30_gun_plan([_gun("mp40"), _gun("thompson_up", 3)], eco, 2), {"do": "ok", "slot": 1}, "a III is past the tier")
	assert_eq(BotSquad.r30_gun_plan([_gun("m1911")], eco, 2), {"do": "give", "slot": -1}, "a pistol only: the fallback gun")
	assert_eq(BotSquad.r30_gun_plan([_gun("m1911"), _gun("ashlight")], eco, 2), {"do": "give", "slot": -1}, "a wonder is never the main gun")
	assert_eq(BotSquad.r30_gun_plan([], eco, 2), {"do": "give", "slot": -1})


func test_a_quiet_grant_drinks_nothing() -> void:
	PerkManager.reset_match()
	watch_signals(GLBus)
	PerkManager.grant(PID, &"hawkeye_brandy", true)
	assert_true(PerkManager.has_perk(PID, &"hawkeye_brandy"))
	assert_signal_not_emitted(GLBus, "perk_bought", "no drink line, no drink pose, no machine flourish")
	assert_signal_emitted(GLBus, "perks_changed", "the HUD and the nameplates still hear of it")
	PerkManager.grant(PID, &"marathon_malt")
	assert_signal_emitted(GLBus, "perk_bought", "a normal grant still drinks")


func test_every_tonic_past_the_cap() -> void:
	PerkManager.reset_match()
	for pk: Variant in BotSquad.r30_perk_ids(_rcfg(), _all_perks()):
		PerkManager.grant(PID, StringName(str(pk)), true)
	assert_eq(PerkManager.owned(PID).size(), _all_perks().size(), "the cap doesn't stop the kit")
	assert_eq(PerkManager.can_buy(PID, &"ironhide_stout"), &"owned", "the bots' shopping finds nothing new to drink")
	PerkManager.on_player_downed(PID)
	assert_true(PerkManager.owned(PID).is_empty(), "not permanent: a down loses them like any other")
