extends GutTest
## HB2, PAUL (docs/HOMAGE_BOSSES.md section 5; DECISIONS T-159): the rage maths and its sources, the stage
## hysteresis, the move table's stage gates and cooldowns, health by player count and per return visit, the
## schedule rules against the Foreman and Bellringer rounds, the fail-safe clock, the return window, the rewards
## plan, and that no Likeness Sheet placeholder ever reaches a string the player sees.

var file: Dictionary
var cfg: Dictionary
var _settings: Dictionary


func before_all() -> void:
	file = GLData.table("bosses/map01")
	cfg = HomageEncounter.block(file, "paul")


func before_each() -> void:
	_settings = GLSettings.values.duplicate(true)
	GLSettings.values["homage_bosses"] = true
	GLSettings.values["homage_names"] = "real"


func after_each() -> void:
	GLSettings.values = _settings
	RoundManager.stop()


# ---------------------------------------------------------------- data

func test_data_block() -> void:
	assert_false(cfg.is_empty(), "bosses/map01.json has the paul block")
	assert_eq(str(cfg["boss_id"]), "paul")
	assert_eq(str(cfg["map"]), "map01_kaltenbrunn")
	assert_eq(int(cfg["round"]), 15)
	assert_almost_eq(float(cfg["horde_fraction"]), 0.6, 0.0001)
	assert_almost_eq(float(cfg["failsafe_seconds"]), 360.0, 0.0001, "he leaves after 6:00")
	assert_true(cfg.has("bots_alone"))
	for m: String in ["haymaker", "zombie_throw", "grab", "ground_pound", "rip_throw", "leap_slam", "thunderclap", "charge", "headframe_dive"]:
		assert_true((cfg["moves"] as Dictionary).has(m), m)


func test_applies_only_on_kaltenbrunn() -> void:
	assert_true(HomageEncounter.applies(&"map01_kaltenbrunn", cfg))
	assert_false(HomageEncounter.applies(&"map02_totenhafen", cfg))
	assert_false(HomageEncounter.applies(&"map00_crossroads", cfg))


# ---------------------------------------------------------------- rage maths

func test_damage_fills_one_point_per_percent() -> void:
	assert_almost_eq(PaulRage.rage_for_damage(300.0, 30000.0), 1.0, 0.0001, "1% of max HP = +1")
	assert_almost_eq(PaulRage.rage_for_damage(3000.0, 30000.0), 10.0, 0.0001)
	assert_almost_eq(PaulRage.rage_for_damage(-5.0, 30000.0), 0.0, 0.0001)
	var r: PaulRage = PaulRage.new(cfg["rage"])
	r.on_damage(6000.0, 30000.0)
	assert_almost_eq(r.value, 20.0, 0.0001)
	assert_eq(r.since_damage, 0.0, "damage resets the cooling clock")


func test_flee_down_and_cooling_sources() -> void:
	var r: PaulRage = PaulRage.new(cfg["rage"])
	r.tick(1.0, 2, 0)
	assert_almost_eq(r.value, 8.0, 0.001, "+4 / s per fleeing player")
	r.on_player_down()
	assert_almost_eq(r.value, 18.0, 0.001, "+10 when he sees a player go down")
	r.tick(1.0, 0, 1)
	assert_almost_eq(r.value, 19.0, 0.001, "+1 / s per downed player in sight")
	# no damage for 8 s: -0.5 / s (the clock has run 2 s already)
	r.tick(6.0, 0, 0)
	assert_almost_eq(r.value, 19.0 - 0.5 * 6.0, 0.001, "cools once 8 s pass without damage")
	r.on_bottle()
	assert_almost_eq(r.value, 16.0 - 20.0 if 16.0 - 20.0 > 0.0 else 0.0, 0.001, "a bottle cools him 20 (never below 0)")
	r.set_value(50.0)
	r.on_cup()
	assert_almost_eq(r.value, 45.0, 0.001, "the tin cup dips 5")
	r.set_value(140.0)
	assert_almost_eq(r.value, 100.0, 0.001, "capped at 100")


func test_stage_thresholds_and_hysteresis() -> void:
	assert_eq(PaulRage.stage_for(0.0, PaulRage.CALM), PaulRage.CALM)
	assert_eq(PaulRage.stage_for(33.9, PaulRage.CALM), PaulRage.CALM)
	assert_eq(PaulRage.stage_for(34.0, PaulRage.CALM), PaulRage.ANGRY, "Angry from 34")
	assert_eq(PaulRage.stage_for(67.0, PaulRage.CALM), PaulRage.BERSERK, "BERSERK from 67 (straight up)")
	# down: 5-point hysteresis below each floor
	assert_eq(PaulRage.stage_for(30.0, PaulRage.ANGRY), PaulRage.ANGRY, "33..29 stays Angry")
	assert_eq(PaulRage.stage_for(28.9, PaulRage.ANGRY), PaulRage.CALM, "below 29 he shrinks to Calm")
	assert_eq(PaulRage.stage_for(63.0, PaulRage.BERSERK), PaulRage.BERSERK, "66..62 stays BERSERK")
	assert_eq(PaulRage.stage_for(61.0, PaulRage.BERSERK), PaulRage.ANGRY)
	assert_eq(PaulRage.stage_for(10.0, PaulRage.BERSERK), PaulRage.CALM, "a big cool steps all the way down")
	var r: PaulRage = PaulRage.new(cfg["rage"])
	r.set_value(70.0)
	assert_eq(r.stage, PaulRage.BERSERK)
	r.on_bottle()   # 50
	assert_eq(r.stage, PaulRage.ANGRY, "a bottle at 70 shrinks him to Angry")
	r.set_value(64.0)
	assert_eq(r.stage, PaulRage.ANGRY, "no regrow under 67")
	assert_eq(r.max_stage_reached, PaulRage.BERSERK)


func test_stage_table_sizes_and_speeds() -> void:
	var st: Array = cfg["stages"]
	assert_eq(st.size(), 3)
	assert_almost_eq(float(st[0]["scale"]), 1.0, 0.001)
	assert_almost_eq(float(st[1]["scale"]), 1.15, 0.001)
	assert_almost_eq(float(st[2]["scale"]), 1.3, 0.001)
	assert_almost_eq(float(st[0]["speed"]), 2.6, 0.001)
	assert_almost_eq(float(st[1]["speed"]), 3.6, 0.001)
	assert_almost_eq(float(st[2]["speed"]), 6.2, 0.001)
	assert_lt(float(st[2]["speed"]), 6.8, "BERSERK still under the 6.8 sprint")


# ---------------------------------------------------------------- moves

func test_move_stage_gates() -> void:
	var calm: PackedStringArray = Paul.moves_for_stage(cfg, PaulRage.CALM)
	assert_true(calm.has("haymaker") and calm.has("zombie_throw") and calm.has("grab"))
	assert_false(calm.has("ground_pound") or calm.has("charge"), "Calm has only the three")
	var angry: PackedStringArray = Paul.moves_for_stage(cfg, PaulRage.ANGRY)
	assert_true(angry.has("ground_pound") and angry.has("rip_throw"))
	assert_false(angry.has("leap_slam"))
	var bz: PackedStringArray = Paul.moves_for_stage(cfg, PaulRage.BERSERK)
	for m: String in ["leap_slam", "thunderclap", "charge", "headframe_dive", "haymaker"]:
		assert_true(bz.has(m), "BERSERK has " + m)


func test_move_table_numbers() -> void:
	var m: Dictionary = cfg["moves"]
	var want: Dictionary = {"haymaker": [0.8, 70, 3], "zombie_throw": [0.9, 60, 10], "grab": [0.7, 25, 14],
		"ground_pound": [1.0, 50, 12], "rip_throw": [1.0, 90, 14], "leap_slam": [1.0, 100, 10],
		"thunderclap": [0.8, 40, 9], "charge": [1.0, 90, 12], "headframe_dive": [1.2, 130, 30]}
	for k: String in want.keys():
		var w: Array = want[k]
		assert_almost_eq(float(m[k]["telegraph"]), float(w[0]), 0.001, k + " telegraph")
		assert_almost_eq(float(m[k]["damage"]), float(w[1]), 0.001, k + " damage")
		assert_almost_eq(float(m[k]["cooldown"]), float(w[2]), 0.001, k + " cooldown")
		assert_true(float(m[k]["telegraph"]) >= 0.5, k + " telegraph in the readable band")


func test_cooldown_clock() -> void:
	var cds: Dictionary = {}
	Paul.start_cooldown(cds, "haymaker", 3.0, 1.0)
	assert_false(Paul.cooldown_ready(cds, "haymaker"))
	Paul.tick_cooldowns(cds, 2.9)
	assert_false(Paul.cooldown_ready(cds, "haymaker"))
	Paul.tick_cooldowns(cds, 0.2)
	assert_true(Paul.cooldown_ready(cds, "haymaker"), "ready after 3 s")
	Paul.start_cooldown(cds, "charge", 12.0, 1.3)
	Paul.tick_cooldowns(cds, 12.5)
	assert_false(Paul.cooldown_ready(cds, "charge"), "bots alone stretches cooldowns x1.3")
	Paul.tick_cooldowns(cds, 3.2)
	assert_true(Paul.cooldown_ready(cds, "charge"))


func test_hit_rules() -> void:
	var lm: Dictionary = cfg["limb_mult"]
	assert_almost_eq(float(lm["head"]), 1.25, 0.001)
	assert_almost_eq(float(lm["arms"]), 0.8, 0.001)
	assert_almost_eq(float(lm["legs"]), 0.8, 0.001)
	# the neck from behind (more than 120 deg from the attacker) is x2
	var fwd: Vector3 = Vector3(0, 0, -1)
	assert_almost_eq(Paul.neck_mult(&"neck", fwd, Vector3(0, 0, 10), 120.0, 2.0), 2.0, 0.001, "behind him")
	assert_almost_eq(Paul.neck_mult(&"neck", fwd, Vector3(0, 0, -10), 120.0, 2.0), 1.0, 0.001, "in front")
	assert_almost_eq(Paul.neck_mult(&"neck", fwd, Vector3(10, 0, 0.1), 120.0, 2.0), 1.0, 0.001, "beside him (90 deg)")
	assert_almost_eq(Paul.neck_mult(&"torso", fwd, Vector3(0, 0, 10), 120.0, 2.0), 1.0, 0.001, "only the neck")
	# a big explosive (3% or more of max HP in one blast) staggers
	assert_true(Paul.staggers(1000.0, 30000.0, &"explosive", 0.03))
	assert_false(Paul.staggers(800.0, 30000.0, &"explosive", 0.03))
	assert_false(Paul.staggers(5000.0, 30000.0, &"bullet", 0.03), "only explosives")


# ---------------------------------------------------------------- health, schedule, fail-safe

func test_health_by_players_and_visits() -> void:
	var want: Array = [30000.0, 52500.0, 75000.0, 97500.0]
	for p: int in 4:
		assert_almost_eq(HomageEncounter.visit_hp(cfg, p + 1, 0), want[p], 0.01, "%d players" % (p + 1))
	assert_almost_eq(HomageEncounter.visit_hp(cfg, 1, 1), 40500.0, 0.01, "first return +35%")
	assert_almost_eq(HomageEncounter.visit_hp(cfg, 1, 2), 51000.0, 0.01, "second return")


func test_schedule_never_on_foreman_or_bellringer() -> void:
	assert_eq(HomageEncounter.pick_round(15, 13, 18), 15, "a free round 15 stays")
	assert_eq(HomageEncounter.pick_round(15, 15, 20), 16, "the Foreman on 15: he moves +1")
	assert_eq(HomageEncounter.pick_round(15, 13, 15), 16, "a Bellringer round on 15: +1")
	assert_eq(HomageEncounter.pick_round(15, 15, 16), 17, "both stacked: +2")
	# the reservation pushes the Foreman and the special round off his round in the first place
	RoundManager.start_game(1)
	RoundManager.next_boss = 15
	RoundManager.next_special = 15
	RoundManager.reserve_round(15)
	assert_ne(RoundManager.next_boss, 15, "the Foreman moved off round 15")
	assert_ne(RoundManager.next_special, 15, "the Bellringer round moved off round 15")


func test_failsafe_and_return_window() -> void:
	assert_false(HomageEncounter.should_leave(359.0, cfg))
	assert_true(HomageEncounter.should_leave(360.0, cfg), "6:00")
	for i: int in 30:
		var back: int = PaulEncounter.return_round_for(15, cfg, i)
		assert_between(back, 23, 25, "8-10 rounds later")


func test_reward_plan() -> void:
	var plan: Dictionary = HomageEncounter.reward_plan(cfg, [1, 2])
	assert_eq(int(plan["scrip"][1]), 2000)
	assert_eq(int(plan["scrip"][2]), 2000)
	assert_true((plan["unlocks"] as Array).has("card_carried_my_share"))
	assert_true((plan["unlocks"] as Array).has("ARC_HB_PAUL"))
	assert_true((plan["intel"] as Array).has("INT_HB_02") and (plan["intel"] as Array).has("INT_HB_03"))
	assert_true((plan["drops"] as Array).has("double_scrip"))


func test_last_round_bottle_rule() -> void:
	assert_eq(Paul.last_round_effect(false), "ironhide", "free Ironhide without a slot")
	assert_eq(Paul.last_round_effect(true), "overshield", "+100 overshield if you have it")


func test_no_placeholder_reaches_the_screen() -> void:
	var tl: PackedStringArray = HomageEncounter.title_of("paul", true, "PAUL")
	assert_eq(tl[0], "PAUL")
	assert_false(tl[0].contains("[") or tl[0].contains("%"))
	var w: PackedStringArray = HomageEncounter.title_of("paul", false, "PAUL")
	assert_eq(w[0], "PAUL")
	assert_eq(HomageEncounter.fill_tokens("Pvt. Paul %PAUL_LASTNAME%."), "Pvt. Paul.", "an unfilled surname leaves nothing")
	assert_false(HomageEncounter.fill_tokens("Unit: %PAUL_UNIT%").contains("%"))
	for id: Variant in (cfg["lines"] as Dictionary).keys():
		if not (cfg["lines"][id] is Dictionary):
			continue
		var txt: String = HomageEncounter.fill_tokens(str((cfg["lines"][id] as Dictionary).get("text", "")))
		assert_false(txt.contains("%") or txt.contains("[PAUL") or txt.contains("[DEVIN"), "line " + str(id))
	for id: String in ["INT_HB_02", "INT_HB_03"]:
		var doc: String = HomageEncounter.fill_tokens(str((cfg["archive"] as Dictionary).get(id, {}).get("text", "")))
		assert_ne(doc, "", id)
		assert_false(doc.contains("%PAUL") or doc.contains("[PAUL"), id)


func test_last_line_per_character() -> void:
	assert_eq(Paul.last_line_for(&"dutch"), "PAU_LAST_DUT_01")
	assert_eq(Paul.last_line_for(&"peg"), "PAU_LAST_PEG_01")
	assert_eq(Paul.last_line_for(&"deacon"), "PAU_LAST_DEA_01")
	assert_eq(Paul.last_line_for(&"wren"), "PAU_LAST_WRN_01")
	assert_eq(Paul.last_line_for(&"nobody"), "PAU_LAST_DUT_01", "an unknown character hears the base line")
