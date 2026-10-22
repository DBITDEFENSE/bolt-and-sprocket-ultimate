extends GutTest
## The campaign chain (DECISIONS T-033): exfil data, carry-over serialization round-trips, round continuity.

var campaign: Dictionary
var rounds: Dictionary
var weapons: Dictionary


func before_all() -> void:
	campaign = GLData.load_json("res://data/gravelight/campaign.json")
	rounds = GLData.load_json("res://data/gravelight/rounds.json")
	weapons = GLData.load_json("res://data/gravelight/weapons.json")


func after_each() -> void:
	Campaign.reset()
	RoundManager.stop()


# ---------------------------------------------------------------- exfil data

func test_chain_is_map0_map1_map2() -> void:
	assert_eq(Campaign.chain(), ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen"])
	assert_eq(Campaign.first_map(), &"map00_crossroads")
	assert_eq(Campaign.scene_for(&"map00_crossroads"), "res://gravelight/maps/map00_crossroads/map00.tscn")
	assert_eq(Campaign.scene_for(&"map02_totenhafen"), "res://gravelight/maps/map02_totenhafen/map02.tscn")
	assert_eq(Campaign.scene_for(&"map09_unknown"), "res://gravelight/maps/map09_unknown/map09.tscn", "folder convention for ids not in the table")
	assert_true(Campaign.scene_exists(&"map00_crossroads"))
	assert_true(Campaign.scene_exists(&"map01_kaltenbrunn"))


func test_map0_exfil_is_round_10_to_kaltenbrunn() -> void:
	var e: Dictionary = Campaign.exfil_cfg(&"map00_crossroads")
	assert_eq(Campaign.validate_exfil(e), PackedStringArray(), "map00.json exfil block is valid")
	assert_eq(int(e["round"]), 10)
	assert_eq(str(e["target"]), "map01_kaltenbrunn")
	assert_eq(str(e["cutscene"]), "exfil_m0_m1")
	assert_true((campaign["cutscenes"] as Dictionary).has("exfil_m0_m1"))
	assert_eq(Campaign.exfil_position(e), Vector3(18.0, 0.0, 32.0))


func test_map1_exfil_is_round_30_to_totenhafen() -> void:
	var e: Dictionary = Campaign.exfil_cfg(&"map01_kaltenbrunn")
	assert_eq(Campaign.validate_exfil(e), PackedStringArray())
	assert_eq(int(e["round"]), 30)
	assert_eq(str(e["target"]), "map02_totenhafen")
	assert_true((campaign["cutscenes"] as Dictionary).has(str(e["cutscene"])))


func test_cutscene_definitions_have_shots_and_vo_lines() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: Variant in (campaign["cutscenes"] as Dictionary).keys():
		var c: Dictionary = campaign["cutscenes"][id]
		assert_gt(float(c["seconds"]), 19.0, "%s is 20-40 s" % str(id))
		assert_lt(float(c["seconds"]), 41.0, "%s is 20-40 s" % str(id))
		assert_gt((c["shots"] as Array).size(), 1, "%s has shots" % str(id))
		for s: Dictionary in c["shots"]:
			assert_eq((s["from"] as Array).size(), 3, "%s shot camera" % str(id))
			if s.has("vo"):
				assert_true(lines.has(str(s["vo"])), "VO line %s exists" % str(s["vo"]))
	for e: Dictionary in [Campaign.exfil_cfg(&"map00_crossroads"), Campaign.exfil_cfg(&"map01_kaltenbrunn")]:
		for key: String in ["vo_open", "vo_wait", "vo_missed"]:
			assert_true(lines.has(str(e[key])), "VO line %s exists" % str(e[key]))


func test_validate_exfil_reports_every_problem() -> void:
	var errors: PackedStringArray = Campaign.validate_exfil({"round": 0, "position": [1, 2], "window_seconds": 0, "retry_rounds": 0})
	assert_eq(errors.size(), 6)
	assert_eq(Campaign.validate_exfil({"round": 10, "target": "x", "position": [0, 0, 0], "window_seconds": 1, "retry_rounds": 1, "cutscene": "c"}).size(), 0)


func test_missed_window_retries_every_retry_rounds() -> void:
	var e: Dictionary = {"round": 10, "retry_rounds": 3}
	assert_eq(Campaign.exfil_round(e, 0), 10)
	assert_eq(Campaign.exfil_round(e, 1), 13)
	assert_eq(Campaign.exfil_round(e, 2), 16)


# ---------------------------------------------------------------- round continuity

func test_arrival_round_is_the_next_round() -> void:
	assert_eq(Campaign.arrival_round(10), 11)
	assert_eq(Campaign.arrival_round(30), 31)
	assert_eq(Campaign.arrival_round(0), 2, "never below round 2 after a transfer")


func test_carried_schedule_keeps_future_rounds_and_pushes_past_ones() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 7
	assert_eq(Campaign.carried_schedule(14, 11, 5, 7, r), 14, "a special still ahead stays")
	for i: int in 20:
		var n: int = Campaign.carried_schedule(9, 11, 5, 7, r)
		assert_between(n, 16, 18, "a passed entry is re-rolled past the arrival with its gap")


func test_resume_at_continues_the_count_with_round_scaling() -> void:
	RoundManager.start_game(3)
	RoundManager.resume_at(10, 5, 8, 14.0)
	assert_eq(RoundManager.current_round, 10)
	assert_eq(RoundManager.state, RoundManager.State.BREAK)
	assert_almost_eq(RoundManager.break_left, 14.0, 0.01, "arrival grace instead of the intro")
	assert_gt(RoundManager.next_special, 10, "a Bellringer round can't be in the past")
	assert_gt(RoundManager.next_boss, 10)
	RoundManager.advance_round()
	assert_eq(RoundManager.current_round, 11)
	assert_eq(RoundManager.round_total, RoundManager.zombie_count(11, 3, rounds), "round 11 on the new map has round-11 zombies")
	assert_eq(RoundManager.current_health(), RoundManager.zombie_health(11, rounds))
	assert_eq(int(GameState.stats.get(&"round", 0)), 11)


func test_resume_keeps_a_future_boss_round() -> void:
	RoundManager.start_game(1)
	RoundManager.resume_at(30, 33, 32, 14.0)
	assert_eq(RoundManager.next_special, 33)
	assert_eq(RoundManager.next_boss, 32)
	RoundManager.advance_round()
	assert_eq(RoundManager.current_round, 31)


# ---------------------------------------------------------------- carry-over serialization

func _holder() -> WeaponHolder:
	var w: WeaponHolder = WeaponHolder.new()
	w.mirror = true
	w.call("_set_start_loadout")
	return w


func test_loadout_round_trips_with_ammo_and_upgraded_state() -> void:
	var a: WeaponHolder = _holder()
	var kar: WeaponInstance = WeaponInstance.create(&"kar98k")
	kar.mag = 2
	kar.reserve = 31
	var up_id: StringName = kar.upgrade_id()
	assert_ne(up_id, &"", "the Kar98k has an upgrade")
	var up: WeaponInstance = WeaponInstance.create(up_id)
	up.mag = 1
	up.reserve = 9
	a.slots = [kar, up]
	a.current_index = 1
	a.grenades = 3
	var tacticals: Dictionary = weapons.get("tactical", {})
	if not tacticals.is_empty():
		a.give_tactical(StringName(str(tacticals.keys()[0])))
	var d: Dictionary = a.to_net()
	assert_eq(Campaign.validate_payload({"round": 10, "to": "map01_kaltenbrunn", "players": {1: {"inv": d}}}, weapons), PackedStringArray())
	var b: WeaponHolder = _holder()
	b.apply_carry(d)
	assert_eq(b.slots.size(), 2)
	assert_eq(b.slots[0].id, &"kar98k")
	assert_eq(b.slots[0].mag, 2)
	assert_eq(b.slots[0].reserve, 31)
	assert_false(b.slots[0].upgraded)
	assert_eq(b.slots[1].id, up_id)
	assert_true(b.slots[1].upgraded, "the upgraded weapon comes back upgraded")
	assert_eq(b.slots[1].mag, 1)
	assert_eq(b.slots[1].reserve, 9)
	assert_eq(b.current_index, 1)
	assert_eq(b.grenades, 3)
	assert_eq(b.tactical_id, a.tactical_id)
	assert_eq(b.tactical_count, a.tactical_count)
	assert_true(Campaign.entry_is_upgraded(d["s"][1], weapons))
	assert_false(Campaign.entry_is_upgraded(d["s"][0], weapons))
	a.free()
	b.free()


func test_empty_carry_falls_back_to_the_start_loadout() -> void:
	var b: WeaponHolder = _holder()
	b.apply_carry({"s": [], "c": 0, "m": "trench_knife", "g": 0, "t": "", "tc": 0})
	assert_eq(b.slots.size(), 1)
	assert_eq(b.slots[0].id, &"m1911")
	b.free()


func test_payload_validation_catches_unknown_weapons_and_bad_rounds() -> void:
	var bad: Dictionary = {"round": 0, "to": "", "players": {1: {"inv": {"s": [["ray_gun_from_space", 1, 1, "semi", false, 0]]}}}}
	var errors: PackedStringArray = Campaign.validate_payload(bad, weapons)
	assert_eq(errors.size(), 3)


func test_restore_account_sets_scrip_and_perks() -> void:
	Economy.reset([1, 2] as Array[int])
	PerkManager.reset_match()
	Campaign.restore_account(2, {"scrip": 4321, "perks": ["ironhide_stout", "not_a_perk"], "bonus_slots": 1})
	assert_eq(Economy.get_scrip(2), 4321)
	assert_eq(PerkManager.owned(2), [&"ironhide_stout"], "unknown perk ids are dropped")
	assert_eq(PerkManager.cap_for(2), int(GLData.table("perks")["cap"]) + 1)
	PerkManager.reset_match()


func test_bot_bonus_perk_carries_over() -> void:
	Economy.reset([1, 2] as Array[int])
	PerkManager.reset_match()
	Campaign.restore_account(2, {"scrip": 100, "perks": ["ironhide_stout", "marathon_malt"], "bonus_perk": "marathon_malt"})
	assert_eq(PerkManager.bonus_perk(2), &"marathon_malt", "the bot keeps its trait across maps")
	assert_eq(PerkManager.owned(2), [&"ironhide_stout", &"marathon_malt"])
	Campaign.restore_account(1, {"scrip": 100, "perks": ["ironhide_stout"], "bonus_perk": ""})
	assert_eq(PerkManager.bonus_perk(1), &"", "humans have none")
	PerkManager.reset_match()


func test_arriving_only_for_the_carried_target() -> void:
	Campaign.begin()
	Campaign.carry = {"to": "map01_kaltenbrunn"}
	assert_true(Campaign.arriving(&"map01_kaltenbrunn"))
	assert_false(Campaign.arriving(&"map00_crossroads"))
	Campaign.reset()
	assert_false(Campaign.arriving(&"map01_kaltenbrunn"))
	assert_false(Campaign.active)
