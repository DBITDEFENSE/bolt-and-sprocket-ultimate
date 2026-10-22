extends GutTest
## HB1, the Cousins (docs/HOMAGE_BOSSES.md sections 3-4, 12): HP by player count, the enrage chain, the 6:00
## fail-safe and the round-15 return, the clear's rewards, the Homage toggle (Off = a normal round 10, the
## campaign beacon unchanged), Homage Names, boss damage terms, ObservedFreeze's view test, reserved rounds.

var cfg: Dictionary
var _settings: Dictionary
var _profile: Dictionary
var _pids: Array[int] = []


func before_all() -> void:
	cfg = GLData.table("bosses/cousins")


func before_each() -> void:
	_settings = GLSettings.values.duplicate(true)
	_profile = ProfileSave.profile.duplicate(true)
	_pids = GameState.player_ids.duplicate()
	GLSettings.values["homage_bosses"] = true
	GLSettings.values["homage_names"] = "real"


func after_each() -> void:
	GLSettings.values = _settings
	ProfileSave.profile = _profile
	GameState.player_ids = _pids
	RoundManager.stop()


# ---------------------------------------------------------------- data and HP

func test_data_loads_through_gldata() -> void:
	assert_eq(int(cfg["round"]), 10)
	assert_eq(str(cfg["map"]), "map00_crossroads")
	assert_almost_eq(float(cfg["horde_fraction"]), 0.4, 0.0001)
	assert_almost_eq(float(cfg["failsafe_seconds"]), 360.0, 0.0001)
	assert_almost_eq(float(cfg["enrage_speed_step"]), 0.2, 0.0001)
	for k: String in CousinsRound.KEYS:
		assert_true((cfg["bosses"] as Dictionary).has(k), k)


func test_hp_scaling_by_player_count() -> void:
	# HP = base x (1 + 0.75 x (players - 1)): the table in section 3.1
	var want: Dictionary = {"hammer": [6000, 10500, 15000, 19500], "reach": [5000, 8750, 12500, 16250], "alix": [7500, 13125, 18750, 24375]}
	for k: String in want.keys():
		for p: int in 4:
			assert_almost_eq(CousinsRound.boss_hp(k, p + 1, cfg), float(want[k][p]), 0.01, "%s at %d players" % [k, p + 1])
	assert_almost_eq(HomageBoss.scaled_hp(6000.0, 0), 6000.0, 0.01, "never below the solo base")


func test_hp_uses_the_round_scaling_count_with_bots() -> void:
	# players = MapRoot.scaled_player_count (bots at their weight): solo + 3 bots scales like 3 players
	var bc: Dictionary = BotConfig.cfg()
	var players: int = BotConfig.scaled_player_count(1, 3, bc)
	assert_almost_eq(CousinsRound.boss_hp("hammer", players, cfg), 6000.0 * (1.0 + 0.75 * float(players - 1)), 0.01)
	assert_gt(CousinsRound.boss_hp("alix", players, cfg), CousinsRound.boss_hp("alix", 1, cfg))


func test_horde_is_forty_percent() -> void:
	var full: int = RoundManager.zombie_count(10, 1, GLData.table("rounds"))
	assert_eq(CousinsRound.horde_count(full, cfg), int(ceil(float(full) * 0.4)))
	assert_eq(CousinsRound.horde_count(0, cfg), 1, "never zero")


# ---------------------------------------------------------------- the enrage chain

func test_enrage_multiplier_stacks() -> void:
	assert_almost_eq(CousinsRound.enrage_mult(0, cfg), 1.0, 0.0001)
	assert_almost_eq(CousinsRound.enrage_mult(1, cfg), 1.2, 0.0001)
	assert_almost_eq(CousinsRound.enrage_mult(2, cfg), 1.4, 0.0001)


func _event() -> CousinsRound:
	var cr: CousinsRound = CousinsRound.new()
	add_child_autofree(cr)
	cr.cfg = cfg.duplicate(true)
	(cr.cfg["rewards"] as Dictionary)["drops"] = []   # no map to drop pickups into here
	return cr


func _boss(cls: GDScript, cr: CousinsRound) -> HomageBoss:
	var b: HomageBoss = cls.new() as HomageBoss
	b.event = cr
	add_child_autofree(b)
	b.max_hp = 1000.0
	b.hp = 1000.0
	b.state = Zombie.State.CHASE   # "alive" without running its brain
	return b


func test_each_death_enrages_the_survivors() -> void:
	var cr: CousinsRound = _event()
	var ham: HomageBoss = _boss(CousinHammer, cr)
	var rch: HomageBoss = _boss(CousinReach, cr)
	var alx: CousinAlix = _boss(CousinAlix, cr) as CousinAlix
	cr.bosses = {"hammer": ham, "reach": rch, "alix": alx}
	cr.phase = CousinsRound.Phase.ACTIVE
	cr.reserved_left = 3
	assert_almost_eq(rch.move_speed(), float(cfg["bosses"]["reach"]["speed"]), 0.001)
	ham.state = Zombie.State.DEAD
	cr.on_cousin_died(ham)
	assert_eq(rch.enrage_steps, 1)
	assert_eq(alx.enrage_steps, 1)
	assert_eq(ham.enrage_steps, 0, "the dead don't enrage")
	assert_almost_eq(rch.speed_mult(), 1.2, 0.0001)
	assert_almost_eq(rch.move_speed(), float(cfg["bosses"]["reach"]["speed"]) * 1.2, 0.001, "+20% move speed")
	assert_almost_eq(rch.cd_for(6.0), 5.0, 0.001, "+20% attack speed (cooldowns / 1.2)")
	assert_eq(alx._grief_queue.size(), 1, "Alix goes to hold the fallen cousin's hand")
	assert_eq(cr.dead_count(), 1)
	assert_eq(cr.reserved_left, 2)
	rch.state = Zombie.State.DEAD
	cr.on_cousin_died(rch)
	assert_eq(alx.enrage_steps, 2, "stacking: +40% for the last one")
	assert_almost_eq(alx.speed_mult(), 1.4, 0.0001)
	assert_true(cr.lines_said.has("OPR_BOSS_COUSINS_DEAD_M0_01") and cr.lines_said.has("OPR_BOSS_COUSINS_DEAD_M0_02"))
	Economy.reset([1] as Array[int])
	GameState.player_ids = [1] as Array[int]
	alx.state = Zombie.State.DEAD
	cr.on_cousin_died(alx)
	assert_eq(cr.phase, CousinsRound.Phase.CLEARED, "all three dead: cleared")
	assert_true(cr.rewards_given)


func test_alix_arrival_triggers() -> void:
	assert_false(CousinsRound.alix_due(10.0, [1.0, 0.9], false, cfg))
	assert_true(CousinsRound.alix_due(10.0, [0.49, 1.0], false, cfg), "a cousin under 50%")
	assert_true(CousinsRound.alix_due(10.0, [1.0], true, cfg), "a cousin died")
	assert_true(CousinsRound.alix_due(180.0, [1.0, 1.0], false, cfg), "3:00 at the latest")


func test_grief_window_doubles_damage() -> void:
	var cr: CousinsRound = _event()
	var alx: CousinAlix = _boss(CousinAlix, cr) as CousinAlix
	assert_almost_eq(alx.damage_taken_mult(), 1.0, 0.0001)
	alx.bstate = HomageBoss.B.SPECIAL
	alx._grief_body = alx
	alx._grief_kneeling = true
	assert_almost_eq(alx.damage_taken_mult(), 2.0, 0.0001)


func test_hammer_airborne_mallet_window() -> void:
	var cr: CousinsRound = _event()
	var ham: CousinHammer = _boss(CousinHammer, cr) as CousinHammer
	assert_almost_eq(ham.damage_taken_mult(), 1.0, 0.0001)
	ham.maul_out = true
	assert_almost_eq(ham.damage_taken_mult(), 1.5, 0.0001)


# ---------------------------------------------------------------- the fail-safe

func test_failsafe_timing_and_return_round() -> void:
	assert_false(CousinsRound.should_retreat(359.9, cfg))
	assert_true(CousinsRound.should_retreat(360.0, cfg))
	assert_eq(CousinsRound.return_round(10, cfg), 15)
	assert_eq(CousinsRound.return_round(15, cfg), 20, "bored again: every 5 rounds")


func test_retreat_moves_the_event_to_round_15() -> void:
	var cr: CousinsRound = _event()
	RoundManager.reserve_round(10)
	cr.event_round = 10
	cr.phase = CousinsRound.Phase.ACTIVE
	cr.reserved_left = 3
	RoundManager.alive = 3
	cr.t = 361.0
	cr._process(0.016)   # the clock is past 6:00: they leave
	assert_eq(cr.phase, CousinsRound.Phase.BORED)
	assert_eq(cr.bored_count, 1)
	assert_eq(cr.event_round, 15)
	assert_true(cr.returning)
	assert_true(RoundManager.is_reserved(15))
	assert_false(RoundManager.is_reserved(10))
	assert_eq(cr.reserved_left, 0)
	assert_eq(RoundManager.alive, 0, "the cousins who left stop holding the round open")
	assert_false(cr.rewards_given, "no rewards for a bored round")
	assert_true(cr.lines_said.has("CSN_BORED_01"))


# ---------------------------------------------------------------- rewards

func test_reward_plan() -> void:
	var plan: Dictionary = CousinsRound.reward_plan(cfg, [1, 2])
	assert_eq(int(plan["scrip"][1]), 1500)
	assert_eq(int(plan["scrip"][2]), 1500)
	assert_true((plan["drops"] as Array).has("deaths_door") and (plan["drops"] as Array).has("resupply"))
	assert_true((plan["unlocks"] as Array).has("card_the_game_is_over"))
	assert_true((plan["unlocks"] as Array).has("charm_three_ribbons"))
	assert_eq(str(plan["intel"]), "INT_HB_01")


func test_reward_grants() -> void:
	var cr: CousinsRound = _event()
	GameState.player_ids = [1, 2] as Array[int]
	Economy.reset([1, 2] as Array[int])
	var before: int = Economy.get_scrip(1)
	cr.grant_rewards(Vector3.ZERO, false)
	assert_eq(Economy.get_scrip(1) - before, 1500)
	assert_eq(Economy.get_scrip(2), Economy.get_scrip(1))
	assert_true(ProfileSave.is_unlocked("card_the_game_is_over"))
	assert_true(ProfileSave.is_unlocked("charm_three_ribbons"))
	assert_true(ProfileSave.is_unlocked("ARC_HB_COUSINS"))
	assert_true(ProfileSave.has_intel("INT_HB_01"))
	GameState.player_ids = [1] as Array[int]


# ---------------------------------------------------------------- the toggle and the names

func test_homage_toggle_off_is_a_normal_round_10() -> void:
	assert_true(CousinsRound.is_event_round(10, 10, true))
	assert_false(CousinsRound.is_event_round(10, 10, false))
	GLSettings.values["homage_bosses"] = false
	var cr: CousinsRound = _event()
	assert_false(RoundManager.is_reserved(10), "Off: round 10 isn't reserved")
	RoundManager.round_total = 34
	RoundManager.to_spawn = 34
	cr._on_round_started(10, false)
	assert_eq(cr.phase, CousinsRound.Phase.IDLE, "Off: no encounter")
	assert_eq(RoundManager.round_total, 34, "Off: the full horde")


func test_homage_toggle_on_reserves_round_10() -> void:
	RoundManager.next_special = 10
	RoundManager.next_boss = 10
	var cr: CousinsRound = _event()
	assert_not_null(cr)
	assert_true(RoundManager.is_reserved(10))
	assert_eq(RoundManager.next_special, 11, "a Bellringer round that would land on 10 moves to 11")
	assert_eq(RoundManager.next_boss, 11, "so does a Foreman")


func test_campaign_beacon_waits_for_the_cousins() -> void:
	var e: Dictionary = {"round": 10, "retry_rounds": 3, "target": "map01_kaltenbrunn"}
	assert_eq(int(CousinsRound.adjust_exfil(&"map00_crossroads", e, true)["round"]), 11)
	assert_eq(Campaign.exfil_round(CousinsRound.adjust_exfil(&"map00_crossroads", e, true), 1), 14, "retries 14, 17 ...")
	assert_eq(int(CousinsRound.adjust_exfil(&"map00_crossroads", e, false)["round"]), 10, "Off: unchanged")
	assert_eq(int(CousinsRound.adjust_exfil(&"map01_kaltenbrunn", {"round": 30}, true)["round"]), 30, "other maps unchanged")


func test_homage_names() -> void:
	assert_eq(HomageBoss.real_name("cousin_1"), "Mara", "the unfilled placeholder uses the sheet's default")
	assert_eq(HomageBoss.real_name("cousin_2"), "Jo")
	assert_eq(HomageBoss.real_name("cousin_3"), "Alix")
	assert_eq(HomageBoss.title_for("cousin_3", true), PackedStringArray(["ALIX", "THE THIRD HAND"]))
	assert_eq(HomageBoss.title_for("cousin_1", false), PackedStringArray(["THE HAMMER", ""]), "In-World: no real name")
	for slot: String in ["cousin_1", "cousin_2", "cousin_3"]:
		for real: bool in [true, false]:
			for s: String in HomageBoss.title_for(slot, real):
				assert_false(s.contains("["), "never a placeholder on screen: %s" % s)


func test_in_world_names_swap_named_lines_for_twins() -> void:
	var cr: CousinsRound = _event()
	GLSettings.values["homage_names"] = "world"
	cr.say("ALX_COUSIN_01")
	assert_eq(cr.lines_said.back(), "ALX_COUSIN_TWIN_01")
	GLSettings.values["homage_names"] = "real"
	cr.say("ALX_COUSIN_01")
	assert_eq(cr.lines_said.back(), "ALX_COUSIN_01")


# ---------------------------------------------------------------- damage terms, observation

func test_boss_damage_terms() -> void:
	# a hitscan head shot arrives x4 (the weapon's default); the boss table says x2
	assert_almost_eq(HomageBoss.boss_damage(400.0, &"head", &"bullet", 2.0, 1.0, false), 200.0, 0.01)
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"wrist", &"bullet", 2.0, 1.0, false), 200.0, 0.01, "the wrist weak point x2")
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"torso", &"bullet", 1.0, 1.5, false), 150.0, 0.01, "a state multiplier")
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"torso", &"melee", 1.0, 1.0, true), 200.0, 0.01, "Death's Door doubles, never kills")


func test_observed_freeze_view_test() -> void:
	var cam: Transform3D = Transform3D.IDENTITY   # at the origin, looking down -Z
	assert_true(ObservedFreeze.point_in_view(cam, 70.0, 16.0 / 9.0, 5.0, Vector3(0, 0, -10)))
	assert_false(ObservedFreeze.point_in_view(cam, 70.0, 16.0 / 9.0, 5.0, Vector3(0, 0, 10)), "behind")
	assert_true(ObservedFreeze.point_in_view(cam, 70.0, 16.0 / 9.0, 5.0, Vector3(0, 4, -10)))
	assert_false(ObservedFreeze.point_in_view(cam, 70.0, 16.0 / 9.0, 5.0, Vector3(0, 9, -10)), "above the frustum")
	assert_false(ObservedFreeze.point_in_view(cam, 70.0, 16.0 / 9.0, 5.0, Vector3(30, 0, -10)), "off to the side")
	var turned: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	assert_true(ObservedFreeze.point_in_view(turned, 70.0, 16.0 / 9.0, 5.0, Vector3(0, 0, 10)), "turned around")


func test_reserved_rounds_clear_on_stop() -> void:
	RoundManager.reserve_round(15)
	assert_true(RoundManager.is_reserved(15))
	RoundManager.stop()
	assert_false(RoundManager.is_reserved(15))
