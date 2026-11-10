extends GutTest
## HB1, the Cousins (docs/HOMAGE_BOSSES.md sections 3-4, 12): HP by player count, the enrage chain, the 6:00
## fail-safe and the round-15 return, the clear's rewards, the Homage toggle (Off = a normal round 10, the
## campaign beacon unchanged), Homage Names, boss damage terms, ObservedFreeze's view test, reserved rounds.
## T-232 (the boss rework): the dread blocks, the crack tiers, the Hammer's hurt-player aim, the Reach's lone-player
## grab terms and Through-the-Window rule, Alix's lengthening grief and harder hits and the look-away rule, the
## dark hunt's trigger.

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


# ---------------------------------------------------------------- bots alone (squad scaling)

func test_bots_alone_when_no_human_is_up() -> void:
	assert_true(CousinsRound.squad_is_bots_alone(0, 1), "the human is down or bled out")
	assert_true(CousinsRound.squad_is_bots_alone(0, 0), "nobody but bots")
	assert_false(CousinsRound.squad_is_bots_alone(1, 1), "a human on their feet")
	assert_false(CousinsRound.squad_is_bots_alone(1, 2), "one of two humans up")


func test_bots_alone_mults_come_from_the_table() -> void:
	var ba: Dictionary = CousinsRound.bots_alone_cfg(cfg)
	assert_true(bool(ba["enabled"]))
	assert_eq(CousinsRound.squad_mults(false, ba), [1.0, 1.0, 1.0, 1.0] as Array[float], "off: the normal scaling")
	var on: Array[float] = CousinsRound.squad_mults(true, ba)
	assert_lt(on[0], 1.0, "less health")
	assert_lt(on[1], 1.0, "softer hits")
	assert_gt(on[2], 1.0, "longer cooldowns")
	assert_lte(on[3], 1.0, "never faster")
	ba["enabled"] = false
	assert_eq(CousinsRound.squad_mults(true, ba), [1.0, 1.0, 1.0, 1.0] as Array[float], "disabled in the table")


func test_squad_scale_keeps_the_bar_fraction_and_round_trips() -> void:
	var b: CousinHammer = CousinHammer.new()
	b.max_hp = 15000.0
	b.hp = 9000.0   # 60%
	b.set_squad_scale(0.5, 0.6, 1.3, 0.9)
	assert_almost_eq(b.max_hp, 7500.0, 0.01)
	assert_almost_eq(b.hp, 4500.0, 0.01, "still 60%")
	b.hp = 1500.0   # 20% while bots alone
	b.set_squad_scale(1.0, 1.0, 1.0, 1.0)
	assert_almost_eq(b.max_hp, 15000.0, 0.01, "back to the unscaled max")
	assert_almost_eq(b.hp, 3000.0, 0.01, "still 20%")
	b.free()


func test_bots_alone_thins_the_queued_horde() -> void:
	var ba: Dictionary = CousinsRound.bots_alone_cfg(cfg)
	ba["horde_mult"] = 0.6
	assert_eq(CousinsRound.cut_horde(30, ba), 18)
	assert_eq(CousinsRound.cut_horde(1, ba), 1, "never cut to zero while one is queued")
	assert_eq(CousinsRound.cut_horde(0, ba), 0)
	ba["horde_mult"] = 1.5
	assert_eq(CousinsRound.cut_horde(10, ba), 10, "never adds zombies")


# ---------------------------------------------------------------- T-232: the boss rework

func test_every_cousin_has_a_porcelain_dread_block() -> void:
	for k: String in CousinsRound.KEYS:
		var b: Dictionary = (cfg["bosses"] as Dictionary)[k]
		assert_true(b.has("dread"), k + " has a dread block")
		assert_eq(str((b["dread"] as Dictionary).get("surface", "")), "porcelain", k + " is porcelain")
	assert_almost_eq(float(cfg["bosses"]["alix"]["dread"]["step_shake"]), 0.0, 0.0001, "Alix's steps make no sound and no shake")
	assert_gt(float(cfg["bosses"]["hammer"]["dread"]["step_shake"]), 0.0, "the Hammer has weight")
	assert_eq((cfg["crack_tiers"] as Array).size(), 3)


func test_crack_tiers_open_with_the_damage() -> void:
	var tiers: Array = [0.75, 0.5, 0.25]
	assert_eq(CousinHammer.crack_tier(1.0, tiers), 0)
	assert_eq(CousinHammer.crack_tier(0.75, tiers), 0, "at the edge: not yet")
	assert_eq(CousinHammer.crack_tier(0.7, tiers), 1)
	assert_eq(CousinHammer.crack_tier(0.4, tiers), 2)
	assert_eq(CousinHammer.crack_tier(0.1, tiers), 3)
	assert_eq(CousinHammer.crack_tier(0.0, tiers), 3)


func test_hammer_aims_at_the_hurt_player() -> void:
	assert_eq(CousinHammer.pick_hurt([1.0, 0.9, 0.8], 0.5), -1, "nobody hurt enough: the nearest as before")
	assert_eq(CousinHammer.pick_hurt([1.0, 0.3, 0.8], 0.5), 1)
	assert_eq(CousinHammer.pick_hurt([0.45, 0.3, 0.8], 0.5), 1, "the most hurt of the hurt")
	assert_eq(CousinHammer.pick_hurt([], 0.5), -1)
	assert_almost_eq(float(cfg["bosses"]["hammer"]["hurt"]["fraction"]), 0.5, 0.0001)


func test_reach_grab_terms_read_a_lone_player() -> void:
	var gc: Dictionary = cfg["bosses"]["reach"]["grab"]
	var lone: Dictionary = cfg["bosses"]["reach"]["lone"]
	var squad: Dictionary = CousinReach.grab_need(gc, 5000.0, false, lone)
	assert_almost_eq(float(squad["max"]), 6.0, 0.001, "a squad: the full hold")
	assert_almost_eq(float(squad["weak"]), 400.0, 0.001, "the wrist break: 8% of her HP")
	assert_eq(int(squad["mash"]), 6)
	var alone: Dictionary = CousinReach.grab_need(gc, 5000.0, true, lone)
	assert_almost_eq(float(alone["max"]), 4.5, 0.001, "a lone player is held for less (x0.75)")
	assert_eq(int(alone["mash"]), int(squad["mash"]), "the mash break is the same: every grab breaks in solo")
	assert_almost_eq(CousinReach.drag_speed(2.5, true, lone), 2.0, 0.001, "and dragged slower (x0.8)")
	assert_almost_eq(CousinReach.drag_speed(2.5, false, lone), 2.5, 0.001)
	assert_lt(float(lone["wall_cooldown_mult"]), 1.0, "but the walls come alive sooner")


func test_reach_window_grab_rule() -> void:
	var wc: Dictionary = cfg["bosses"]["reach"]["window"]
	assert_true(CousinReach.window_applies(2.0, 3, false, 5.0, wc), "near a boarded window, out of her sight")
	assert_true(CousinReach.window_applies(4.0, 1, true, 9.0, wc), "in sight but far off")
	assert_false(CousinReach.window_applies(2.0, 0, false, 5.0, wc), "no boards: no window to come through")
	assert_false(CousinReach.window_applies(6.0, 3, false, 5.0, wc), "too far from the window")
	assert_false(CousinReach.window_applies(2.0, 3, true, 4.0, wc), "in sight and close: the Long Reach instead")
	assert_gte(float(wc["telegraph"]), 0.5, "the boards creak for a readable telegraph")
	assert_lte(float(wc["telegraph"]), 1.0)


func test_alix_grief_lengthens_and_she_hits_harder() -> void:
	var g: Dictionary = cfg["bosses"]["alix"]["grieve"]
	assert_almost_eq(CousinAlix.grief_seconds(float(g["seconds"]), float(g["seconds_step"]), 1), 3.0, 0.001, "the first grief: 3 s as before")
	assert_almost_eq(CousinAlix.grief_seconds(float(g["seconds"]), float(g["seconds_step"]), 2), 4.5, 0.001, "the second: longer")
	assert_almost_eq(CousinAlix.grief_seconds(3.0, 1.5, 0), 3.0, 0.001, "never under the base")
	assert_almost_eq(CousinAlix.grief_damage_mult(float(g["damage_step"]), 0), 1.0, 0.001)
	assert_almost_eq(CousinAlix.grief_damage_mult(float(g["damage_step"]), 1), 1.15, 0.001, "+15% after the first rise")
	assert_almost_eq(CousinAlix.grief_damage_mult(float(g["damage_step"]), 2), 1.3, 0.001)
	var cr: CousinsRound = _event()
	var alx: CousinAlix = _boss(CousinAlix, cr) as CousinAlix
	alx.grief_rises = 1
	assert_almost_eq(alx.grief_damage_mult(0.15, alx.grief_rises) * float(alx.bcfg.get("damage_mult", 1.0)), 2.3, 0.001, "on top of her double damage")


func test_alix_look_away_rule() -> void:
	var to_boss: Vector3 = Vector3(0, 0, -5)   # she is north of the player
	assert_false(CousinAlix.looking_away(Vector3(0, 0, -1), to_boss, 100.0), "looking at her")
	assert_false(CousinAlix.looking_away(Vector3(1, 0, -1), to_boss, 100.0), "45 deg off: still watching")
	assert_true(CousinAlix.looking_away(Vector3(0, 0, 1), to_boss, 100.0), "back turned")
	assert_true(CousinAlix.looking_away(Vector3(1, 0, 0.3), to_boss, 100.0), "more than 100 deg off")
	assert_false(CousinAlix.looking_away(Vector3(0, -1, 0), to_boss, 100.0), "looking straight down counts as nothing (flat test)")
	var sc: Dictionary = cfg["bosses"]["alix"]["step"]
	assert_gt(float(sc["stop_at"]), float(cfg["bosses"]["alix"]["hold"]["range"]), "the step stops short of her grab range: no step into a grab")


func test_dark_hunt_when_one_cousin_is_left() -> void:
	assert_false(CousinsRound.dark_hunt_due(0, 3, cfg))
	assert_false(CousinsRound.dark_hunt_due(1, 3, cfg))
	assert_true(CousinsRound.dark_hunt_due(2, 3, cfg), "two dead of three: the last one puts the lamps out")
	assert_false(CousinsRound.dark_hunt_due(3, 3, cfg), "all dead: the clear relights")
	var off: Dictionary = cfg.duplicate(true)
	(off["dark_hunt"] as Dictionary)["enabled"] = false
	assert_false(CousinsRound.dark_hunt_due(2, 3, off), "the block can be switched off")
	assert_gte(float(cfg["dark_hunt"]["after"]), 2.0, "a beat after the second death, not on it")


func test_dark_hunt_is_scheduled_on_the_second_death() -> void:
	var cr: CousinsRound = _event()
	var ham: HomageBoss = _boss(CousinHammer, cr)
	var rch: HomageBoss = _boss(CousinReach, cr)
	var alx: CousinAlix = _boss(CousinAlix, cr) as CousinAlix
	cr.bosses = {"hammer": ham, "reach": rch, "alix": alx}
	cr.phase = CousinsRound.Phase.ACTIVE
	cr.reserved_left = 3
	ham.state = Zombie.State.DEAD
	cr.on_cousin_died(ham)
	assert_eq(cr._sched.size(), 0, "one death: no dark hunt yet")
	rch.state = Zombie.State.DEAD
	cr.on_cousin_died(rch)
	assert_eq(cr._sched.size(), 1, "two dead: the dark hunt beat is scheduled")
	assert_false(cr.dark_hunt, "not before its beat")
	assert_almost_eq(alx.grief_seconds_now(), 4.5, 0.001, "her second grief window is longer")
