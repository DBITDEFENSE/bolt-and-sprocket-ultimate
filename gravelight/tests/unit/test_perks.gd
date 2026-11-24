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


const SIX: Array[StringName] = [&"ironhide_stout", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"blastproof_bock", &"packmule_porter"]


## T-081: the cap is six (perks.json "cap"); Classic Rules keeps the old four ("classic_cap").
func test_cap_data() -> void:
	assert_eq(PerkManager.data_cap(false), 6)
	assert_eq(PerkManager.data_cap(true), 4)
	assert_lt(PerkManager.data_cap(false), (GLData.table("perks")["perks"] as Dictionary).size(), "more tonics than slots: still a choice")


func test_cap_of_six() -> void:
	var was: bool = bool(GLSettings.values.get("classic_rules", false))
	GLSettings.values["classic_rules"] = false
	PerkManager.reset_match()
	assert_eq(PerkManager.base_cap(), 6)
	for id: StringName in SIX:
		assert_eq(PerkManager.buy_for(PID, id), &"ok", String(id))
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"cap", "the seventh is refused")
	assert_eq(PerkManager.owned(PID).size(), 6)
	PerkManager.add_bonus_slot(PID)   # the Map 1 egg's slot
	assert_eq(PerkManager.cap_for(PID), 7)
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"ok", "a seventh with the egg slot")
	assert_eq(PerkManager.buy_for(PID, &"overclock_cordial"), &"cap")
	GLSettings.values["classic_rules"] = was


func test_classic_rules_cap_of_four_latched_per_match() -> void:
	var was: bool = bool(GLSettings.values.get("classic_rules", false))
	GLSettings.values["classic_rules"] = true
	PerkManager.reset_match()
	for i: int in 4:
		assert_eq(PerkManager.buy_for(PID, SIX[i]), &"ok", String(SIX[i]))
	assert_eq(PerkManager.buy_for(PID, SIX[4]), &"cap", "Classic Rules: four")
	GLSettings.values["classic_rules"] = false
	assert_eq(PerkManager.base_cap(), 4, "a mid-match toggle waits for the next match")
	PerkManager.reset_match()
	assert_eq(PerkManager.base_cap(), 6)
	GLSettings.values["classic_rules"] = was
	PerkManager.reset_match()


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
	assert_eq(int(PerkManager.stat(PID, "max_health", 100)), 275)
	assert_almost_eq(float(PerkManager.stat(PID, "reload_time_mult", 1.0)), 0.45, 0.001)
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


# ---------------------------------------------------------------- data integrity (eleven machines, lore)

func test_perks_json_valid() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	assert_eq(perks.size(), 13, "nine perk tonics plus Map 4's two (Skyhook Sekt, Magpie Mead; T-105), Ledger Lager (T-141) and Rocket Man (T-276)")
	var shapes: Dictionary = {}
	for id: String in perks.keys():
		var p: Dictionary = perks[id]
		for field: String in ["name", "desc", "cost", "effects", "color", "abbr", "shape", "sign"]:
			assert_true(p.has(field), "%s has %s" % [id, field])
		assert_gt(int(p.get("cost", 0)), 0, id + " costs something")
		assert_eq(str(p.get("abbr", "")).length(), 2, id + " abbr is two letters (the fallback for a cap without a glyph)")
		assert_true(PerkCap.has_glyph(StringName(id)), id + " has a cap glyph (T-082)")
		assert_gt(str(p.get("desc", "")).length(), 20, id + " has a one-line description")
		assert_false(shapes.has(p.get("shape")), "%s: shape %s is unique" % [id, p.get("shape")])
		shapes[p.get("shape")] = id
		var fp: Vector3 = PerkMachine._shape_footprint(str(p["shape"]))
		assert_gt(fp.y, 1.5, id + " shape has a footprint")
	assert_eq(int(perks["overclock_cordial"]["cost"]), 2500)
	assert_eq(str(perks["overclock_cordial"]["shape"]), "coil")
	assert_eq(PerkMachine._shape_footprint("coil"), Vector3(0.8, 2.3, 0.6), "coil shares the cabinet footprint")


func test_perk_lore_covers_every_perk() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	for id: String in perks.keys():
		var lo: Dictionary = FinePrintReader.lore(StringName(id))
		assert_false(lo.is_empty(), id + " has lore")
		assert_true(str(lo.get("plan_id", "")).begins_with("DMS-VP-"), id + " has a plan ID stencil")
		assert_gt((lo.get("panel", []) as Array).size(), 3, id + " has a fine-print panel")
	var oc: Dictionary = FinePrintReader.lore(&"overclock_cordial")
	assert_eq(str(oc.get("plan_id", "")), "DMS-VP-SRG-X2")
	assert_true(str(oc.get("plan_name", "")).begins_with("SURGE"))


# ---------------------------------------------------------------- Overclock Cordial (WEAPONS.md section 20.2)

func test_overclock_rules() -> void:
	assert_almost_eq(PerkManager.overclock_spent(30, 30), 0.0, 0.001, "full mag")
	assert_almost_eq(PerkManager.overclock_spent(0, 30), 1.0, 0.001, "empty mag")
	assert_almost_eq(PerkManager.overclock_spent(15, 30), 0.5, 0.001)
	assert_almost_eq(PerkManager.overclock_radius(1.0), 6.5, 0.001, "6.5 m on an empty mag (T-082: was 6.0)")
	assert_almost_eq(PerkManager.overclock_radius(0.25), 2.5 + 4.0 * 0.25, 0.001)
	# damage: 0.66 x health(r) x e (T-082: was 0.6); the doc's examples (150 at r1, 2710 at r20, 7030 at r30)
	assert_almost_eq(PerkManager.overclock_damage(1.0, 150.0, false), 99.0, 0.01, "99 at r1 empty")
	assert_almost_eq(PerkManager.overclock_damage(1.0, 2710.0, false), 1788.6, 0.01, "1789 at r20 empty")
	assert_almost_eq(PerkManager.overclock_damage(1.0, 7030.0, false), 4639.8, 0.01, "4640 at r30 empty")
	assert_almost_eq(PerkManager.overclock_damage(0.5, 1000.0, false), 330.0, 0.01, "scales with e")
	assert_almost_eq(PerkManager.overclock_damage(1.0, 1000.0, false, true), 1320.0, 0.01, "Repossessors take x2")
	assert_almost_eq(PerkManager.overclock_damage(1.0, 99999.0, true), 1700.0, 0.01, "bosses: flat 1700 x e")
	assert_almost_eq(PerkManager.overclock_damage(0.5, 99999.0, true), 850.0, 0.01)
	assert_false(PerkManager.overclock_staggers(0.5))
	assert_true(PerkManager.overclock_staggers(0.75))
	assert_true(PerkManager.overclock_staggers(1.0))


func _armed_player(weapon_id: StringName, mag: int, reserve: int) -> Player:
	var p: Player = Player.new()
	p.player_id = PID
	add_child_autofree(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var h: WeaponHolder = p.weapons
	h.give_weapon(weapon_id)
	h.current_index = h.slots.find(h.find_weapon(weapon_id))
	h.call("_rebuild_gun")
	var w: WeaponInstance = h.current()
	w.mag = mag
	w.reserve = reserve
	h.set("_swap_t", 0.0)
	return p


func _tick(p: Player, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		p.weapons.tick(1.0 / 60.0, {})
		t += 1.0 / 60.0


func test_overclock_needs_the_perk_and_a_quarter_spent() -> void:
	var p: Player = _armed_player(&"mp40", 16, 64)   # mp40 mag 32: e = 0.5
	assert_false(PerkManager.overclock_reload(p, 0.5), "no perk, no burst")
	assert_eq(PerkManager.buy_for(PID, &"overclock_cordial"), &"ok")
	assert_false(PerkManager.overclock_reload(p, 0.2), "below the 0.25 threshold")
	assert_true(PerkManager.overclock_reload(p, 0.25), "at the threshold")
	assert_false(PerkManager.overclock_reload(p, 1.0), "3 s cooldown")
	PerkManager.overclock_clear_cooldown(PID)
	assert_true(PerkManager.overclock_reload(p, 1.0), "cooldown cleared")


func test_overclock_reload_hook_scales_with_spent() -> void:
	var p: Player = _armed_player(&"mp40", 8, 64)
	PerkManager.buy_for(PID, &"overclock_cordial")
	var seen: Array = []
	var cb: Callable = func(pid: int, e: float) -> void: seen.append([pid, e])
	PerkManager.overclock_triggered.connect(cb)
	p.weapons.start_reload()
	assert_eq(seen.size(), 1, "the reload start triggered a burst")
	assert_almost_eq(float(seen[0][1]), 0.75, 0.001, "e = 1 - 8/32")
	assert_eq(int(seen[0][0]), PID)
	# a nearly full mag reloads without a burst
	p.weapons.call("_cancel_reload")
	PerkManager.overclock_clear_cooldown(PID)
	p.weapons.current().mag = 30
	p.weapons.start_reload()
	assert_eq(seen.size(), 1, "e = 0.06: no burst")
	PerkManager.overclock_triggered.disconnect(cb)


func test_overclock_once_per_bolt_and_shell_reload() -> void:
	# shell-by-shell (trench gun): the reload loads four rounds one at a time and bursts once, at the start
	var p: Player = _armed_player(&"trench_gun", 2, 30)
	PerkManager.buy_for(PID, &"overclock_cordial")
	var count: Array = [0]
	var cb: Callable = func(_pid: int, _e: float) -> void: count[0] += 1
	PerkManager.overclock_triggered.connect(cb)
	p.weapons.start_reload()
	_tick(p, 4.0)
	assert_eq(p.weapons.current().mag, 6, "shotgun fully reloaded round by round")
	assert_false(p.weapons.is_reloading())
	assert_eq(count[0], 1, "shell reload: one burst")
	PerkManager.overclock_triggered.disconnect(cb)
	p.queue_free()
	# bolt rifle (Kar98k) from empty: a stripper clip, one burst; from 2/5 it loads one at a time, still one burst
	for start_mag: int in [0, 2]:
		var pb: Player = _armed_player(&"kar98k", start_mag, 30)
		PerkManager.overclock_clear_cooldown(PID)
		var n: Array = [0]
		var cb2: Callable = func(_pid: int, _e: float) -> void: n[0] += 1
		PerkManager.overclock_triggered.connect(cb2)
		pb.weapons.start_reload()
		_tick(pb, 5.0)
		assert_eq(pb.weapons.current().mag, 5, "bolt rifle full from %d" % start_mag)
		assert_eq(n[0], 1, "bolt reload from %d: one burst" % start_mag)
		PerkManager.overclock_triggered.disconnect(cb2)
		pb.queue_free()
