extends GutTest
## AI teammates (T-031): the pure rules in BotConfig and how bots count for round scaling, against the real
## tuning in data/gravelight/bots.json.

var cfg: Dictionary
var rounds: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/bots.json")
	rounds = GLData.load_json("res://data/gravelight/rounds.json")


# ---------------------------------------------------------------- tuning shape

func test_tuning_loads_and_is_a_data_table() -> void:
	assert_false(cfg.is_empty())
	assert_eq(BotConfig.cfg(), GLData.table("bots"), "bots.json is served by GLData")
	assert_eq(int(cfg["max_bots"]), 3)


func test_every_skill_in_the_menu_cycle_exists() -> void:
	for s: Variant in cfg["skill_order"]:
		assert_true((cfg["skills"] as Dictionary).has(str(s)), "skill %s" % str(s))
		var sk: Dictionary = BotConfig.skill(cfg, str(s))
		for key: String in ["reaction_s", "turn_rate", "aim_error_deg", "settle_error_deg", "head_aim_chance", "fire_tolerance_deg", "burst_s"]:
			assert_true(sk.has(key), "%s.%s" % [str(s), key])
	assert_true((cfg["skills"] as Dictionary).has(str(cfg["skill_default"])))


func test_skill_lookup_falls_back_to_the_default() -> void:
	assert_eq(BotConfig.skill(cfg, "nonsense"), BotConfig.skill(cfg, str(cfg["skill_default"])))
	assert_eq(BotConfig.next_skill(cfg, "recruit"), "veteran")
	assert_eq(BotConfig.next_skill(cfg, "elite"), "recruit", "the cycle wraps")
	assert_eq(BotConfig.next_skill(cfg, "???"), "recruit", "unknown restarts the cycle")
	assert_eq(BotConfig.next_skill(cfg, "green"), "veteran", "an old name counts as its new one (U03)")


func test_skills_get_sharper_from_recruit_to_elite() -> void:
	var g: Dictionary = BotConfig.skill(cfg, "recruit")
	var v: Dictionary = BotConfig.skill(cfg, "elite")
	assert_lt(float(v["aim_error_deg"]), float(g["aim_error_deg"]))
	assert_lt(float(v["reaction_s"][1]), float(g["reaction_s"][1]))
	assert_gt(float(v["head_aim_chance"]), float(g["head_aim_chance"]))
	assert_gt(float(v["turn_rate"]), float(g["turn_rate"]))


# ---------------------------------------------------------------- bots and characters

func test_clamp_bots() -> void:
	assert_eq(BotConfig.clamp_bots(cfg, -1), 0)
	assert_eq(BotConfig.clamp_bots(cfg, 2), 2)
	assert_eq(BotConfig.clamp_bots(cfg, 9), 3)


func test_bots_take_the_survivors_the_human_did_not_pick() -> void:
	var out: Array[StringName] = BotConfig.assign_characters(["peg"], 3)
	assert_eq(out, [&"dutch", &"deacon", &"wren"] as Array[StringName])
	assert_eq(BotConfig.assign_characters([&"dutch"], 1), [&"peg"] as Array[StringName])
	assert_eq(BotConfig.assign_characters(["dutch", "peg", "deacon", "wren"], 3).size(), 0, "no survivor twice")
	assert_eq(BotConfig.assign_characters([], 0).size(), 0)


# ---------------------------------------------------------------- round scaling

func test_bots_count_as_three_quarters_of_a_player() -> void:
	assert_almost_eq(float(cfg["scaling"]["bot_player_weight"]), 0.75, 0.001)
	assert_eq(BotConfig.scaled_player_count(1, 0, cfg), 1)
	assert_eq(BotConfig.scaled_player_count(1, 1, cfg), 2)    # 1 + round(0.75)
	assert_eq(BotConfig.scaled_player_count(1, 2, cfg), 3)    # 1 + round(1.5) = 3 (round half away from zero)
	assert_eq(BotConfig.scaled_player_count(1, 3, cfg), 3)    # 1 + round(2.25)
	assert_eq(BotConfig.scaled_player_count(2, 2, cfg), 4)
	assert_eq(BotConfig.scaled_player_count(4, 3, cfg), 4, "never above the player cap")
	assert_eq(BotConfig.scaled_player_count(0, 0, cfg), 1, "never below one")


func test_full_squad_of_bots_is_harder_than_solo_but_not_a_full_four() -> void:
	var solo: int = RoundManager.zombie_count(10, 1, rounds)
	var with_bots: int = RoundManager.zombie_count(10, BotConfig.scaled_player_count(1, 3, cfg), rounds)
	var four: int = RoundManager.zombie_count(10, 4, rounds)
	assert_gt(with_bots, solo)
	assert_lt(with_bots, four)
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	assert_gt(RoundManager.foreman_health(13, BotConfig.scaled_player_count(1, 3, cfg), fm), RoundManager.foreman_health(13, 1, fm))


func test_weight_one_counts_bots_like_humans() -> void:
	var c: Dictionary = {"scaling": {"bot_player_weight": 1.0}}
	assert_eq(BotConfig.scaled_player_count(1, 3, c), 4)


# ---------------------------------------------------------------- kill share

func test_kill_share_waits_for_a_sample_then_protects_the_human() -> void:
	var ks: Dictionary = cfg["combat"]["kill_share"]
	assert_true(BotConfig.human_share_ok([], [1], ks), "nothing logged yet")
	assert_true(BotConfig.human_share_ok([2, 2, 2, 2, 2], [1], ks), "under min_sample: no rule yet")
	assert_false(BotConfig.human_share_ok([2, 3, 4, 2, 3, 4, 2, 3], [1], ks), "bots took everything")
	assert_true(BotConfig.human_share_ok([1, 1, 1, 2, 1, 1, 2, 3], [1], ks), "the human has most of them")
	# only the window counts: an old streak of bot kills is forgotten
	var old: Array = []
	for i: int in 40:
		old.append(2)
	for i2: int in 24:
		old.append(1)
	assert_true(BotConfig.human_share_ok(old, [1], ks))


func test_kill_share_counts_every_human() -> void:
	var ks: Dictionary = {"window": 10, "min_sample": 4, "human_min_share": 0.5}
	assert_true(BotConfig.human_share_ok([1, 5, 2, 3, 1, 5], [1, 5], ks))
	assert_false(BotConfig.human_share_ok([1, 2, 2, 3, 2, 3], [1, 5], ks))


# ---------------------------------------------------------------- shopping

# ---------------------------------------------------------------- aim and formation geometry

func test_aim_error_settles_from_wide_to_tight() -> void:
	var sk: Dictionary = BotConfig.skill(cfg, "regular")
	assert_almost_eq(BotConfig.aim_error_deg(sk, 0.0), float(sk["aim_error_deg"]), 0.001)
	assert_almost_eq(BotConfig.aim_error_deg(sk, 100.0), float(sk["settle_error_deg"]), 0.001)
	var mid: float = BotConfig.aim_error_deg(sk, float(sk["settle_s"]))
	assert_lt(mid, float(sk["aim_error_deg"]))
	assert_gt(mid, float(sk["settle_error_deg"]))
	assert_almost_eq(BotConfig.aim_error_deg(sk, -5.0), float(sk["aim_error_deg"]), 0.001, "no time travel")


func test_range_roll() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 20:
		var v: float = BotConfig.range_roll([0.3, 0.6], rng, 9.0)
		assert_between(v, 0.3, 0.6)
	assert_almost_eq(BotConfig.range_roll(null, rng, 9.0), 9.0, 0.001)
	assert_almost_eq(BotConfig.range_roll([1.0], rng, 9.0), 9.0, 0.001)


func test_formation_slots_are_behind_the_leader_and_distinct() -> void:
	var f: Dictionary = cfg["follow"]
	var seen: Array[Vector3] = []
	for i: int in 3:
		var o: Vector3 = BotConfig.slot_offset(f, i)
		assert_gt(o.z, 0.0, "slot %d is behind (leader-local -Z is forward)" % i)
		assert_almost_eq(o.length(), float(f["slot_radius_m"]), 0.01)
		for s: Vector3 in seen:
			assert_gt(s.distance_to(o), 1.0, "slots don't overlap")
		seen.append(o)
	assert_gt(BotConfig.slot_offset(f, 3).length(), float(f["slot_radius_m"]), "a fourth bot would stand further out")


func test_fire_cone_and_blocked_shots() -> void:
	var origin: Vector3 = Vector3.ZERO
	var fwd: Vector3 = Vector3(0, 0, -1)
	assert_true(BotConfig.in_fire_cone(origin, fwd, Vector3(0.5, 0, -6), 20.0, 16.0))
	assert_false(BotConfig.in_fire_cone(origin, fwd, Vector3(6, 0, -6), 20.0, 16.0), "45 degrees off")
	assert_false(BotConfig.in_fire_cone(origin, fwd, Vector3(0, 0, -20), 20.0, 16.0), "past the range")
	assert_false(BotConfig.in_fire_cone(origin, fwd, Vector3(0, 0, 6), 20.0, 16.0), "behind")
	assert_false(BotConfig.in_fire_cone(origin, Vector3.ZERO, Vector3(0, 0, -6), 20.0, 16.0), "no facing")
	assert_true(BotConfig.blocks_shot(Vector3.ZERO, Vector3(0, 0, -10), Vector3(0.2, 0, -5), 0.6))
	assert_false(BotConfig.blocks_shot(Vector3.ZERO, Vector3(0, 0, -10), Vector3(2.0, 0, -5), 0.6))
	assert_false(BotConfig.blocks_shot(Vector3.ZERO, Vector3(0, 0, -10), Vector3(0, 0, -12), 0.6), "beyond the target")
	assert_false(BotConfig.blocks_shot(Vector3.ZERO, Vector3(0, 0, -10), Vector3(0, 0, 1), 0.6), "behind the shooter")


# ---------------------------------------------------------------- match state

func test_game_state_knows_bots_from_humans() -> void:
	var keep_ids: Array[int] = GameState.player_ids.duplicate()
	var keep_bots: Array[int] = GameState.bot_ids.duplicate()
	GameState.player_ids = [1, 2, 3, 4]
	GameState.bot_ids = [2, 3, 4]
	assert_true(GameState.is_bot(3))
	assert_false(GameState.is_bot(1))
	assert_eq(GameState.human_ids(), [1] as Array[int])
	assert_false(GameState.is_solo(), "a match with bots plays by the co-op rules (last stand, revives)")
	GameState.player_ids = keep_ids
	GameState.bot_ids = keep_bots


func test_settings_remember_the_squad() -> void:
	assert_true(GLSettings.values.has("bots"))
	assert_true(GLSettings.values.has("bot_skill"))


# ---------------------------------------------------------------- doors and the Crucible

func test_door_tuning_is_present_and_switchable() -> void:
	var d: Dictionary = cfg["shopping"]["doors"]
	for key: String in ["enabled", "reserve_scrip", "round_delay_s", "max_per_round_per_bot"]:
		assert_true(d.has(key), key)
	# Update 03: whether a bot may buy a door at all is BotEconomy.door_allowed (test_bot_brain.gd)


func test_crucible_wanted() -> void:
	var c: Dictionary = cfg["shopping"]["crucible"]
	var cost: int = int(GLData.table("economy")["crucible_upgrade"])
	var r: int = int(c["min_round"])
	assert_true(BotConfig.crucible_wanted(c, true, cost + int(c["reserve_scrip"]), cost, r))
	assert_false(BotConfig.crucible_wanted(c, true, cost + int(c["reserve_scrip"]) - 1, cost, r), "keeps the reserve")
	assert_false(BotConfig.crucible_wanted(c, true, 99999, cost, r - 1), "not before min_round")
	assert_false(BotConfig.crucible_wanted(c, false, 99999, cost, r), "nothing to teach the gun in hand")
	var off: Dictionary = c.duplicate()
	off["enabled"] = false
	assert_false(BotConfig.crucible_wanted(off, true, 99999, cost, r))


func test_backpedal_radius_sits_between_knife_and_danger() -> void:
	var cb: Dictionary = cfg["combat"]
	assert_gt(float(cb["backpedal_radius_m"]), float(cb["melee_range_m"]))
	assert_lt(float(cb["backpedal_radius_m"]), float(cb["danger_radius_m"]))


func test_crucible_sells_no_ammo_to_bots() -> void:
	# T-083: the Crucible only teaches; a bot's taught gun refills at an ammo box like any other gun.
	var c: Dictionary = cfg["shopping"]["crucible"]
	for key: String in ["only_in_break", "priority", "min_round", "reserve_scrip"]:
		assert_true(c.has(key), key)
	for gone: String in ["ammo_below_frac", "ammo_reserve_scrip"]:
		assert_false(c.has(gone), "%s left with the Crucible's ammo counter" % gone)
	assert_false(GLData.table("economy").has("crucible_upgraded_ammo"), "no Crucible ammo price in economy.json")
	assert_false((BotAIData.table("economy")["priorities"] as Dictionary).has("crucible_ammo"), "no crucible_ammo errand priority")
	assert_false(AgentPlan.ALWAYS.has("crucible_ammo"), "the agent plan's always-list dropped it")
	var up: WeaponInstance = WeaponInstance.create(&"thompson_up")
	up.reserve = 0
	up.mag = 1
	assert_eq(Crucible.action_for(up), &"upgrade", "a dry taught gun is offered its next teaching, not ammo")
	assert_eq(AmmoBox.price_for(up.data, up.upgraded, AmmoBox.cfg()), int(AmmoBox.cfg()["upgraded"]), "the box prices its refill")
	assert_false(bool(c["only_in_break"]), "T-058: upgrades mid-round too when it is calm (break-only, the Crucible never happened)")
	assert_lte(int(c["min_round"]), 6, "T-058: the Thompson goes in from round 5")
	assert_gt(float(c["priority"]), 60.0, "the Crucible outranks ammo (60) and boards (30) in the break")


