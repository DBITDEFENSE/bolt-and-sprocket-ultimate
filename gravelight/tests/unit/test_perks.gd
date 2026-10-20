extends GutTest
## Perk tonic rules (docs/GDD.md §8, data/perks.json).

const PID: int = 42


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	PerkManager.reset_match()
	Economy.reset([PID])
	Economy.grant(PID, 50000)


func after_all() -> void:
	GameState.player_ids = [1]
	GameState.power_on = false
	PerkManager.reset_match()


func test_cap_of_four() -> void:
	for id: StringName in [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt"]:
		assert_eq(PerkManager.buy_for(PID, id), &"ok", String(id))
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"cap")
	assert_eq(PerkManager.owned(PID).size(), 4)


func test_cannot_buy_owned() -> void:
	assert_eq(PerkManager.buy_for(PID, &"ironhide_stout"), &"ok")
	var before: int = Economy.get_scrip(PID)
	assert_eq(PerkManager.buy_for(PID, &"ironhide_stout"), &"owned")
	assert_eq(Economy.get_scrip(PID), before)


func test_charges_price() -> void:
	var before: int = Economy.get_scrip(PID)
	PerkManager.buy_for(PID, &"trigger_tonic")
	assert_eq(Economy.get_scrip(PID), before - 3000)


func test_no_scrip() -> void:
	Economy.reset([PID])
	assert_eq(PerkManager.buy_for(PID, &"packmule_porter"), &"no_scrip")
	assert_false(PerkManager.has_perk(PID, &"packmule_porter"))


func test_needs_power() -> void:
	GameState.power_on = false
	assert_eq(PerkManager.buy_for(PID, &"ironhide_stout"), &"no_power")


func test_second_wind_solo_price_and_no_power() -> void:
	GameState.power_on = false
	assert_eq(PerkManager.price(&"second_wind"), 500)
	assert_eq(PerkManager.buy_for(PID, &"second_wind"), &"ok")


func test_second_wind_coop_price_and_power() -> void:
	GameState.player_ids = [PID, PID + 1]
	GameState.power_on = false
	assert_eq(PerkManager.price(&"second_wind"), 1500)
	assert_eq(PerkManager.buy_for(PID, &"second_wind"), &"no_power")
	GameState.player_ids = [PID]


func test_stat_aggregation() -> void:
	assert_eq(int(PerkManager.stat(PID, "max_health", 100)), 100)
	PerkManager.buy_for(PID, &"ironhide_stout")
	PerkManager.buy_for(PID, &"trigger_tonic")
	PerkManager.buy_for(PID, &"packmule_porter")
	assert_eq(int(PerkManager.stat(PID, "max_health", 100)), 250)
	assert_almost_eq(float(PerkManager.stat(PID, "reload_time_mult", 1.0)), 0.5, 0.001)
	assert_eq(int(PerkManager.stat(PID, "weapon_slots", 2)), 3)
	assert_almost_eq(float(PerkManager.stat(PID, "fire_rate_mult", 1.0)), 1.0, 0.001)


func test_self_revive_three_times_then_gone() -> void:
	GameState.power_on = false
	assert_false(PerkManager.try_self_revive(PID), "no Second Wind owned")
	PerkManager.buy_for(PID, &"ironhide_stout")   # power off: denied, fine
	for i: int in 3:
		assert_eq(PerkManager.buy_for(PID, &"second_wind"), &"ok", "rebuy %d" % i)
		assert_true(PerkManager.try_self_revive(PID), "revive %d" % i)
		assert_false(PerkManager.has_perk(PID, &"second_wind"), "used up on revive %d" % i)
	assert_eq(PerkManager.solo_self_revives_left, 0)
	assert_true(PerkManager.second_wind_gone)
	assert_eq(PerkManager.buy_for(PID, &"second_wind"), &"gone")
	assert_false(PerkManager.try_self_revive(PID))


func test_self_revive_keeps_other_perks() -> void:
	PerkManager.buy_for(PID, &"ironhide_stout")
	PerkManager.buy_for(PID, &"second_wind")
	assert_true(PerkManager.try_self_revive(PID))
	assert_true(PerkManager.has_perk(PID, &"ironhide_stout"))


func test_coop_down_loses_all() -> void:
	GameState.player_ids = [PID, PID + 1]
	PerkManager.buy_for(PID, &"ironhide_stout")
	PerkManager.buy_for(PID, &"second_wind")
	assert_false(PerkManager.try_self_revive(PID), "no self-revive in co-op")
	PerkManager.on_player_downed(PID)
	assert_eq(PerkManager.owned(PID).size(), 0)
	GameState.player_ids = [PID]
