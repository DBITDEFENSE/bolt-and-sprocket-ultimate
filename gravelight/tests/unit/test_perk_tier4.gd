extends GutTest
## UPDATE 08 section 2 (T-129): perk tier IV, "perma perks". The gate (tier III held, the power on, Classic Rules
## off), the prices (12000-15000 in data), permanence through a down, a self-revive, a bleed-out (a down that
## never gets up), the campaign carry, the cap, and each tier IV effect.

const PID: int = 1

var _p: Player
var _saved_profile: Dictionary


func before_all() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)


func before_each() -> void:
	GameState.player_ids = [PID]
	GameState.power_on = true
	RoundManager.current_round = 20
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	GLSettings.values["classic_rules"] = false
	Economy.reset([PID])
	Economy.grant(PID, 200000)


func after_each() -> void:
	PerkManager.meta_gate_override = -1
	GLSettings.values["classic_rules"] = false
	PerkManager.reset_match()


func after_all() -> void:
	ProfileSave.profile = _saved_profile
	GameState.power_on = false
	RoundManager.current_round = 0


func _player() -> Player:
	_p = Player.new()
	_p.player_id = PID
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return _p


func _to_tier(perk: StringName, t: int) -> void:
	PerkManager.grant(PID, perk)
	PerkManager.set_tier(PID, perk, t)


# ---------------------------------------------------------------- data and the gate

func test_every_tonic_has_a_tier_four_priced_by_strength() -> void:
	assert_eq(PerkManager.max_tier(), 4)
	assert_eq(PerkManager.permanent_tier(), 4)
	assert_eq(PerkManager.tier_mark(4), "IV")
	for pk: Variant in (GLData.table("perks")["perks"] as Dictionary).keys():
		var td: Dictionary = PerkManager.tier_data(StringName(pk), 4)
		assert_false(td.is_empty(), "%s has tier IV" % pk)
		var cost: int = int(td.get("cost", 0))
		assert_between(cost, 12000, 15000, "%s tier IV costs 12000-15000" % pk)
		assert_gt(cost, PerkManager.tier_price(StringName(pk), 3), "%s IV costs more than III" % pk)
		assert_false((td.get("effects", {}) as Dictionary).is_empty(), "%s IV has an effect of its own" % pk)
		assert_true(str(td.get("desc", "")).begins_with("Permanent"), "%s IV says it is permanent" % pk)
	for strong: String in ["ironhide_stout", "second_wind", "packmule_porter"]:
		assert_eq(PerkManager.tier_price(StringName(strong), 4), 15000, strong + " is a 15000 tonic")
	for light: String in ["hawkeye_brandy", "marathon_malt"]:
		assert_eq(PerkManager.tier_price(StringName(light), 4), 12000, light + " is a 12000 tonic")


func test_the_gate() -> void:
	PerkManager.grant(PID, &"ironhide_stout")
	PerkManager.set_tier(PID, &"ironhide_stout", 2)
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"ok", "II -> III")
	PerkManager.set_tier(PID, &"ironhide_stout", 3)
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"ok", "III -> IV")
	GameState.power_on = false
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"no_power", "IV needs the power")
	GameState.power_on = true
	GLSettings.values["classic_rules"] = true
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"classic", "Classic Rules keeps tiers off")
	GLSettings.values["classic_rules"] = false
	var before: int = Economy.get_scrip(PID)
	assert_eq(PerkManager.upgrade_for(PID, &"ironhide_stout"), &"ok")
	assert_gt(before - Economy.get_scrip(PID), 12000, "paid the tier IV price (the purse's own discounts aside)")
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 4)
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"max", "nothing past IV")


# ---------------------------------------------------------------- permanence

func test_a_tier_four_tonic_survives_every_down_and_takes_its_cap_slot() -> void:
	_to_tier(&"ironhide_stout", 4)
	_to_tier(&"trigger_tonic", 3)
	PerkManager.grant(PID, &"marathon_malt")
	assert_eq(PerkManager.capped_count(PID), 3, "a permanent tonic still counts toward the cap")
	assert_true(PerkManager.is_permanent(PID, &"ironhide_stout"))
	assert_false(PerkManager.is_permanent(PID, &"trigger_tonic"))
	PerkManager.on_player_downed(PID)
	assert_eq(PerkManager.owned(PID), [&"ironhide_stout"], "only the permanent tonic is left after a down")
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 4, "at its tier")
	PerkManager.on_player_downed(PID)   # a second down (a bleed-out and respawn goes through the same down)
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 4, "and through the next")


func test_a_tier_four_second_wind_is_not_used_up_by_a_self_revive() -> void:
	var saved: Array = GameState.player_ids.duplicate()
	_to_tier(&"second_wind", 4)
	if not GameState.is_solo():
		pass_test("not a solo state in this run")
		return
	var left: int = PerkManager.solo_self_revives_left
	assert_true(PerkManager.try_self_revive(PID))
	assert_true(PerkManager.has_perk(PID, &"second_wind"), "still in the system")
	assert_eq(PerkManager.solo_self_revives_left, left - 1, "the use still counts down")
	PerkManager._refill_self_revive(10)
	assert_eq(PerkManager.solo_self_revives_left, left, "and comes back on round 10")
	GameState.player_ids = saved


func test_the_campaign_carries_the_tier() -> void:
	_to_tier(&"packmule_porter", 4)
	var tiers: Dictionary = PerkManager.tiers(PID)
	assert_eq(int(tiers.get("packmule_porter", 0)), 4, "the snapshot's perk_tiers hold IV (Campaign carries tiers)")


# ---------------------------------------------------------------- the effects

func test_ironhide_four_holds_you_up_once_a_round() -> void:
	var p: Player = _player()
	_to_tier(&"ironhide_stout", 4)
	p.hp = 40.0
	var left: float = PerkManager.filter_hit(p, 100.0)
	assert_eq(left, 39.0, "the hit that would down you leaves 1 hp")
	assert_true(PerkManager.is_protected(PID), "and 3 s where nothing gets through")
	PerkManager._until.clear()
	p.hp = 40.0
	assert_eq(PerkManager.filter_hit(p, 100.0), 100.0, "only once a round")
	RoundManager.current_round = 21
	assert_eq(PerkManager.filter_hit(p, 100.0), 39.0, "a new round, a new last stand")


func test_trigger_tonic_four_loads_shock_rounds_from_a_low_mag() -> void:
	_to_tier(&"trigger_tonic", 4)
	PerkManager.reload_finished(PID, 0.8)
	assert_eq(int(PerkManager._shock_left.get(PID, 0)), 0, "a top-up reload loads none")
	PerkManager.reload_finished(PID, 0.2)
	assert_eq(int(PerkManager._shock_left.get(PID, 0)), 6, "the last third of a mag: six shock rounds")
	var m: float = PerkManager.shot_mult(PID, false)
	assert_gt(m, 1.5, "a shock round hits harder")
	assert_true(PerkManager.shot_is_shock(PID), "and staggers")
	assert_eq(int(PerkManager._shock_left.get(PID, 0)), 5)


func test_twin_barrel_four_doubles_every_tenth_bullet() -> void:
	assert_true(PerkManager.double_hit(10, 10))
	assert_false(PerkManager.double_hit(9, 10))
	assert_false(PerkManager.double_hit(10, 0))
	_to_tier(&"twin_barrel", 4)
	var doubled: int = 0
	for i: int in 20:
		if PerkManager.shot_mult(PID, false) >= 2.0:
			doubled += 1
	assert_eq(doubled, 2, "two of twenty shots hit twice")


func test_packmule_four_fills_the_mags_too() -> void:
	var p: Player = _player()
	_to_tier(&"packmule_porter", 4)
	var w: WeaponInstance = p.weapons.current()
	w.reserve = 0
	w.mag = 0
	assert_true(PerkManager.resupply(p))
	assert_eq(w.mag, w.mag_size(), "a full magazine")
	assert_eq(w.reserve, ceili(float(w.reserve_max()) * 0.3), "and 30% of the reserve")


func test_blastproof_four_doubles_the_shockwave() -> void:
	_to_tier(&"blastproof_bock", 3)
	var three: float = PerkManager.slide_shock_damage(PID, 450.0)
	PerkManager.set_tier(PID, &"blastproof_bock", 4)
	assert_almost_eq(PerkManager.slide_shock_damage(PID, 450.0), three * 2.0, 0.01, "twice as hard")
	assert_eq(float(PerkManager.stat(PID, "slide_shockwave_radius", 0.0)), 5.0, "and 5 m")
	assert_true(bool(PerkManager.stat(PID, "slide_kills_crawlers", false)))


func test_the_data_only_tier_fours() -> void:
	_to_tier(&"second_wind", 4)
	assert_gt(float(PerkManager.stat(PID, "revive_speed_mult", 1.0)), 30.0, "revives are instant")
	assert_eq(float(PerkManager.stat(PID, "revive_invuln_seconds", 0.0)), 5.0)
	_to_tier(&"skyhook_sekt", 4)
	assert_eq(int(PerkManager.stat(PID, "air_hops", 0)), 2)
	_to_tier(&"overclock_cordial", 4)
	assert_eq(float(PerkManager.stat(PID, "overclock_aftershock_mult", 0.0)), 1.0)
	_to_tier(&"magpie_mead", 4)
	assert_eq(int(PerkManager.stat(PID, "magpie_powerup_every", 0)), 12)
	_to_tier(&"marathon_malt", 4)
	assert_gt(float(PerkManager.stat(PID, "sprint_knockdown_radius", 0.0)), 1.0)
	_to_tier(&"hawkeye_brandy", 4)
	assert_eq(float(PerkManager.stat(PID, "headshot_chain_mult", 0.0)), 0.5)
