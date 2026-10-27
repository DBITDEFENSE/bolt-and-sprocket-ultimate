extends GutTest
## Perk upgrades, tiers II / III (DECISIONS T-075, docs/gravelight/PERKS_LORE.md section 1): pricing and gating,
## each tier's effect, the cap, the campaign carry, and the bots' choice.

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
	Economy.reset([PID])
	Economy.grant(PID, 100000)


func after_each() -> void:
	PerkManager.meta_gate_override = -1
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


# ---------------------------------------------------------------- data

func test_every_perk_has_two_tiers_with_cost_name_desc_and_a_new_effect() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	for pk: Variant in perks.keys():
		var base: Dictionary = (perks[pk] as Dictionary).get("effects", {})
		var prev: int = PerkManager.cost_for(perks[pk], true)
		for t: int in [2, 3]:
			var td: Dictionary = PerkManager.tier_data(StringName(pk), t)
			assert_false(td.is_empty(), "%s has tier %d" % [pk, t])
			assert_gt(int(td.get("cost", 0)), prev, "%s tier %d costs more than the step below" % [pk, t])
			prev = int(td.get("cost", 0))
			assert_ne(str(td.get("name", "")), "", "%s tier %d name" % [pk, t])
			assert_ne(str(td.get("desc", "")), "", "%s tier %d desc" % [pk, t])
			var fresh: bool = false
			for k: Variant in (td.get("effects", {}) as Dictionary).keys():
				if not base.has(k):
					fresh = true
			assert_true(fresh, "%s tier %d adds an effect key of its own" % [pk, t])


func test_tier_names_and_marks() -> void:
	assert_eq(PerkManager.tier_name(&"ironhide_stout", 2), "Ironhide Stout II")
	assert_eq(PerkManager.tier_name(&"ironhide_stout", 3), "Ironhide Stout III")
	assert_eq(PerkManager.tier_name(&"ironhide_stout", 1), "Ironhide Stout")


# ---------------------------------------------------------------- pricing and gating

func test_upgrade_needs_the_perk_power_round_and_order() -> void:
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"none", "not carried")
	PerkManager.grant(PID, &"ironhide_stout")
	GameState.power_on = false
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"no_power")
	GameState.power_on = true
	RoundManager.current_round = 7
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"round", "tier II from round 8")
	RoundManager.current_round = 8
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"ok")
	var before: int = Economy.get_scrip(PID)
	assert_eq(PerkManager.upgrade_for(PID, &"ironhide_stout"), &"ok")
	assert_eq(before - Economy.get_scrip(PID), PerkManager.tier_price(&"ironhide_stout", 2), "charged tier II's price")
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 2)
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"round", "tier III from round 15")
	RoundManager.current_round = 15
	assert_eq(PerkManager.upgrade_for(PID, &"ironhide_stout"), &"ok")
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 3)
	assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"max")


func test_no_scrip_keeps_the_tier() -> void:
	PerkManager.grant(PID, &"trigger_tonic")
	Economy.reset([PID])
	assert_eq(PerkManager.upgrade_for(PID, &"trigger_tonic"), &"no_scrip")
	assert_eq(PerkManager.tier_of(PID, &"trigger_tonic"), 1)


func test_mastery_gate() -> void:
	PerkManager.meta_gate_override = 1
	var pm: Dictionary = ProfileSave.profile.get("perk_mastery", {})
	pm["hawkeye_brandy"] = 0
	ProfileSave.profile["perk_mastery"] = pm
	PerkManager.grant(PID, &"hawkeye_brandy")
	assert_eq(PerkManager.can_upgrade(PID, &"hawkeye_brandy"), &"locked")
	PerkManager.add_mastery(&"hawkeye_brandy", PerkManager.mastery_needed(2))
	assert_eq(PerkManager.can_upgrade(PID, &"hawkeye_brandy"), &"ok", "tier II unlocked by mastery")
	PerkManager.upgrade_for(PID, &"hawkeye_brandy")
	assert_eq(PerkManager.can_upgrade(PID, &"hawkeye_brandy"), &"locked", "tier III needs more")
	PerkManager.add_mastery(&"hawkeye_brandy", PerkManager.mastery_needed(3))
	assert_eq(PerkManager.can_upgrade(PID, &"hawkeye_brandy"), &"ok")
	assert_eq(int(PerkManager.unlocked_tiers()["hawkeye_brandy"]), 3)


func test_tiers_take_no_cap_slot_and_go_with_the_perk() -> void:
	var ids: Array[StringName] = [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"blastproof_bock", &"packmule_porter"]
	for i: int in PerkManager.base_cap():
		PerkManager.buy_for(PID, ids[i])
		PerkManager.set_tier(PID, ids[i], 3)
	assert_eq(PerkManager.capped_count(PID), PerkManager.base_cap(), "a full cap of tonics, tiers take no extra slot")
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"cap", "the cap still holds")
	PerkManager.on_player_downed(PID)
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 0)
	assert_true(PerkManager.tiers(PID).is_empty(), "the tiers went with the perks")
	PerkManager.buy_for(PID, &"ironhide_stout")
	assert_eq(PerkManager.tier_of(PID, &"ironhide_stout"), 1, "a rebuy starts at tier I")


func test_solo_second_wind_remembers_its_tier() -> void:
	PerkManager.grant(PID, &"second_wind")
	PerkManager.set_tier(PID, &"second_wind", 2)
	assert_true(PerkManager.try_self_revive(PID))
	assert_false(PerkManager.has_perk(PID, &"second_wind"))
	PerkManager.grant(PID, &"second_wind")
	assert_eq(PerkManager.tier_of(PID, &"second_wind"), 2)


# ---------------------------------------------------------------- effects

func test_stat_merges_tier_effects() -> void:
	PerkManager.grant(PID, &"ironhide_stout")
	assert_eq(float(PerkManager.stat(PID, "max_health", 100.0)), 275.0)
	PerkManager.set_tier(PID, &"ironhide_stout", 2)
	assert_eq(float(PerkManager.stat(PID, "max_health", 100.0)), 330.0)
	assert_eq(float(PerkManager.stat(PID, "regen_delay_mult", 1.0)), 0.6)
	PerkManager.set_tier(PID, &"ironhide_stout", 3)
	assert_eq(float(PerkManager.stat(PID, "max_health", 100.0)), 330.0, "tier III keeps tier II's effects")
	assert_gt(float(PerkManager.stat(PID, "iron_skin_seconds", 0.0)), 0.0)


func test_ironhide_iron_skin_after_a_near_death_hit() -> void:
	var p: Player = _player()
	PerkManager.grant(PID, &"ironhide_stout")
	PerkManager.set_tier(PID, &"ironhide_stout", 3)
	p.max_hp = 300.0
	p.hp = 120.0
	assert_eq(PerkManager.filter_hit(p, 50.0), 50.0, "the hit to 70 / 300 lands")
	assert_true(PerkManager.is_protected(PID), "then the iron skin is up")
	assert_eq(PerkManager.filter_hit(p, 50.0), 0.0, "and the next hit does nothing")
	PerkManager.clear_tier_timers()
	p.hp = 120.0
	assert_eq(PerkManager.filter_hit(p, 50.0), 50.0)


func test_marathon_dodge_while_sprinting() -> void:
	var p: Player = _player()
	PerkManager.grant(PID, &"marathon_malt")
	PerkManager.set_tier(PID, &"marathon_malt", 3)
	p.sprinting = false
	assert_eq(PerkManager.filter_hit(p, 50.0), 50.0, "walking: no dodge")
	p.sprinting = true
	var base_speed: float = float(PerkManager.stat(PID, "move_speed_mult", 1.0))
	assert_eq(PerkManager.filter_hit(p, 50.0), 0.0, "sprinting: the swipe is dodged")
	assert_gt(float(PerkManager.stat(PID, "move_speed_mult", 1.0)), base_speed, "with a burst of speed")
	assert_eq(PerkManager.filter_hit(p, 50.0), 50.0, "once per cooldown")


func test_second_wind_revive_boost_and_window() -> void:
	PerkManager.grant(2, &"second_wind")
	PerkManager.set_tier(2, &"second_wind", 3)
	GLBus.player_revived.emit(PID, 2)
	assert_gt(float(PerkManager.stat(PID, "move_speed_mult", 1.0)), 1.0, "the revived run faster")
	assert_true(PerkManager.is_protected(PID), "and nothing hurts them for a moment")


func test_trigger_fresh_clip_and_hawkeye_patience() -> void:
	PerkManager.grant(PID, &"trigger_tonic")
	assert_eq(PerkManager.shot_mult(PID, false), 1.0)
	PerkManager.set_tier(PID, &"trigger_tonic", 3)
	PerkManager.reload_finished(PID)
	assert_almost_eq(PerkManager.shot_mult(PID, false), 1.3, 0.001, "fresh clip")
	PerkManager.reset_match()
	PerkManager.grant(PID, &"hawkeye_brandy")
	PerkManager.set_tier(PID, &"hawkeye_brandy", 3)
	assert_almost_eq(PerkManager.shot_mult(PID, true), 1.75, 0.001, "a patient aimed shot")
	assert_eq(PerkManager.shot_mult(PID, true), 1.0, "the next one straight after is not")


func test_hawkeye_refund_and_twin_barrel_save() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"kar98k")
	w.refill()
	w.mag = 2
	PerkManager.grant(PID, &"hawkeye_brandy")
	PerkManager.on_bullet_kill(PID, w, true)
	assert_eq(w.mag, 2, "tier I: no refund")
	PerkManager.set_tier(PID, &"hawkeye_brandy", 2)
	PerkManager.on_bullet_kill(PID, w, false)
	assert_eq(w.mag, 2, "a body kill: no refund")
	PerkManager.on_bullet_kill(PID, w, true)
	assert_eq(w.mag, 3, "a headshot kill puts a round back")
	PerkManager.grant(PID, &"twin_barrel")
	PerkManager.set_tier(PID, &"twin_barrel", 3)
	var saved: int = 0
	for i: int in 2000:
		if PerkManager.round_saved(PID, w):
			saved += 1
	assert_between(saved, 380, 620, "about one shot in four is free (%d / 2000)" % saved)


func test_packmule_prices_grenades_and_resupply() -> void:
	var p: Player = _player()
	PerkManager.grant(PID, &"packmule_porter")
	assert_eq(PerkManager.ammo_price_mult(PID), 1.0)
	var g0: int = p.weapons.grenade_max()
	PerkManager.set_tier(PID, &"packmule_porter", 2)
	assert_eq(PerkManager.ammo_price_mult(PID), 0.5)
	assert_eq(p.weapons.grenade_max(), g0 + 1)
	assert_false(PerkManager.resupply(p), "tier II has no round resupply")
	PerkManager.set_tier(PID, &"packmule_porter", 3)
	var w: WeaponInstance = p.weapons.current()
	w.reserve = 0
	assert_true(PerkManager.resupply(p))
	assert_eq(w.reserve, ceili(float(w.reserve_max()) * 0.2))


func test_blastproof_heal_and_round_shockwave() -> void:
	var p: Player = _player()
	PerkManager.grant(PID, &"blastproof_bock")
	PerkManager.set_tier(PID, &"blastproof_bock", 2)
	p.max_hp = 100.0
	p.hp = 50.0
	PerkManager.blast_heal(p, p.global_position, 4.0)
	assert_eq(p.hp, 75.0, "the blast heals 25")
	assert_eq(PerkManager.slide_shock_damage(PID, 600.0), 600.0, "tier II: flat")
	PerkManager.set_tier(PID, &"blastproof_bock", 3)
	RoundManager.current_round = 30
	assert_gt(PerkManager.slide_shock_damage(PID, 600.0), 600.0, "tier III grows with the round")


func test_overclock_tiers() -> void:
	PerkManager.grant(PID, &"overclock_cordial")
	PerkManager.set_tier(PID, &"overclock_cordial", 2)
	assert_eq(float(PerkManager.stat(PID, "overclock_cooldown", 3.0)), 2.0)
	assert_eq(int(PerkManager.stat(PID, "overclock_arcs", 0)), 3)
	PerkManager.set_tier(PID, &"overclock_cordial", 3)
	assert_eq(float(PerkManager.stat(PID, "overclock_aftershock_spent", 0.0)), 0.75)


# ---------------------------------------------------------------- carry and bots

func test_campaign_carries_tiers() -> void:
	Campaign.restore_account(2, {"scrip": 100, "perks": ["ironhide_stout", "marathon_malt"], "perk_tiers": {"ironhide_stout": 3, "hawkeye_brandy": 2}})
	assert_eq(PerkManager.tier_of(2, &"ironhide_stout"), 3)
	assert_eq(PerkManager.tier_of(2, &"marathon_malt"), 1)
	assert_eq(PerkManager.tier_of(2, &"hawkeye_brandy"), 0, "no tier without its perk")


func test_bots_upgrade_only_when_nothing_new_and_affordable() -> void:
	var eco: Dictionary = BotAIData.table("economy")
	var ups: Dictionary = {"ironhide_stout": 3500, "marathon_malt": 3000}
	assert_eq(BotEconomy.upgrade_wanted(eco, {}, ups, "smg", 12, 20000, 1000, false), &"", "a base perk still to buy comes first")
	assert_eq(BotEconomy.upgrade_wanted(eco, {}, ups, "smg", 7, 20000, 1000, true), &"", "not before min_round (8, the machine's own, T-121)")
	assert_eq(BotEconomy.upgrade_wanted(eco, {}, ups, "smg", 8, 20000, 1000, true), &"ironhide_stout", "from round 8")
	assert_eq(BotEconomy.upgrade_wanted(eco, {}, ups, "smg", 12, 20000, 1000, true), &"ironhide_stout", "plan order")
	assert_eq(BotEconomy.upgrade_wanted(eco, {}, ups, "smg", 12, 4000, 1000, true), &"", "saves for its first choice")
	assert_eq(BotEconomy.upgrade_wanted(eco, {"ironhide_stout": 2}, {"ironhide_stout": 7000}, "smg", 14, 20000, 1000, true), &"",
		"tier III waits for tier3_min_round")
	assert_eq(BotEconomy.upgrade_wanted(eco, {"ironhide_stout": 2}, {"ironhide_stout": 7000}, "smg", 15, 20000, 1000, true), &"ironhide_stout")


## T-121: a squad bot has no profile, so the mastery lock is not its; a human (or the bot-mode agent) keeps it.
func test_bots_skip_the_mastery_lock() -> void:
	PerkManager.meta_gate_override = 1
	var saved_bots: Variant = GameState.bot_ids.duplicate()
	GameState.bot_ids = [7]
	PerkManager.grant(7, &"ironhide_stout")
	PerkManager.grant(PID, &"ironhide_stout")
	var human_locked: bool = not PerkManager.tier_unlocked(&"ironhide_stout", 2)
	assert_eq(PerkManager.can_upgrade(7, &"ironhide_stout"), &"ok", "the bot brews tier II")
	if human_locked:
		assert_eq(PerkManager.can_upgrade(PID, &"ironhide_stout"), &"locked", "the human still has to earn it")
	PerkManager.set_tier(7, &"ironhide_stout", 2)
	assert_eq(PerkManager.can_upgrade(7, &"ironhide_stout"), &"ok", "and tier III")
	GameState.bot_ids = saved_bots
