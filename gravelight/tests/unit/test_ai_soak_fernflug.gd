extends GutTest
## UPDATE 07 (T-116): the AI soak's fernflug scenario, the pure parts: the act starts (the launcher's skips), the
## transition kinds, the per-act rows summed into the run's row; the scripted player's beacon errand helpers;
## ExfilPoint.force_depart's rules.

const Soak: GDScript = preload("res://tools_src/ai_soak.gd")


func test_act_starts_match_the_launcher_and_console() -> void:
	assert_eq(Soak.fernflug_start_for(1), ["map04a", "map04a_thalbach", 1])
	assert_eq(Soak.fernflug_start_for(2), ["map04b", "map04b_kranich", 15])
	assert_eq(Soak.fernflug_start_for(3), ["map04c", "map04c_groomlake", 21])
	assert_eq(Soak.fernflug_start_for(4), ["map04d", "map04d_mondlicht", 30])
	assert_eq(Soak.fernflug_start_for(0), Soak.fernflug_start_for(1), "clamped")
	assert_eq(Soak.fernflug_start_for(9), Soak.fernflug_start_for(4), "clamped")
	for st: Array in Soak.ACT_STARTS:
		assert_true(Soak.MAPS.has(str(st[0])), "%s is a soak map" % str(st[0]))
		assert_eq(Campaign.scene_for(StringName(str(st[1]))), str(Soak.MAPS[str(st[0])]), "the soak loads the campaign's scene for %s" % str(st[1]))
		assert_eq(Campaign.act_first_round(StringName(str(st[1]))), int(st[2]), "%s starts on the act's first match round" % str(st[1]))
	assert_eq(GLConsole.ACT_ROUNDS, [1, 15, 21, 30], "the console's `act <n>` agrees")


func test_transition_kind() -> void:
	assert_eq(Soak.transition_kind(12, 15, false), "egg", "left before the beacon's round: the egg lit it")
	assert_eq(Soak.transition_kind(15, 15, false), "clock")
	assert_eq(Soak.transition_kind(17, 15, false), "clock", "a missed window, then the clock")
	assert_eq(Soak.transition_kind(17, 15, true), "forced", "the harness voted")


func test_act_totals_sum_the_acts() -> void:
	var acts: Array = [
		{"act": 1, "round_reached": 15, "minutes": 30.5, "bot_kills": 400, "bot_downs": 3, "human_downs": 1, "revived": 3, "bled": 0, "stuck_events": 2, "stuck_time": 4.5, "teleports": 0, "stranded": 1, "scrip_spent": 9000, "doors_open": 9, "bosses": 1, "forced": 0},
		{"act": 2, "round_reached": 20, "minutes": 12.0, "bot_kills": 150, "bot_downs": 2, "human_downs": 0, "revived": 1, "bled": 1, "stuck_events": 0, "stuck_time": 0.0, "teleports": 1, "stranded": 0, "scrip_spent": 2000, "doors_open": 4, "bosses": 0, "forced": 1}]
	var t: Dictionary = Soak.act_totals(acts)
	assert_eq(int(t["acts"]), 2)
	assert_eq(int(t["round_reached"]), 20, "the last round")
	assert_almost_eq(float(t["minutes"]), 42.5, 0.01)
	assert_eq(int(t["bot_kills"]), 550)
	assert_eq(int(t["bot_downs"]), 5)
	assert_eq(int(t["revived"]), 4)
	assert_eq(int(t["bled"]), 1)
	assert_almost_eq(float(t["stuck_time"]), 4.5, 0.01)
	assert_eq(int(t["teleports"]), 1)
	assert_eq(int(t["stranded"]), 1)
	assert_eq(int(t["scrip_spent"]), 11000)
	assert_eq(int(t["doors_open"]), 13)
	assert_eq(int(t["bosses"]), 1)
	assert_eq(int(t["forced"]), 1)
	var empty: Dictionary = Soak.act_totals([])
	assert_eq(int(empty["acts"]), 0)
	assert_eq(int(empty["round_reached"]), 0)


func test_boss_ids_are_the_four_act_bosses() -> void:
	for id: StringName in Soak.BOSS_IDS:
		assert_true(ResourceLoader.exists("res://gravelight/enemies/map04/%s.gd" % id), "%s is a Map 4 boss script" % id)
	for m: String in ["map04a", "map04b", "map04c", "map04d"]:
		var act: Dictionary = RoundManager.act_block_of(StringName(m))
		var bid: String = str((act.get("boss", {}) as Dictionary).get("id", ""))
		assert_true(Soak.BOSS_IDS.has(StringName(bid)), "%s's boss %s is counted" % [m, bid])


func test_force_depart_needs_a_lit_unlocked_beacon() -> void:
	var x: ExfilPoint = ExfilPoint.new()
	x.cfg = {"target": "map04c_groomlake", "requires_flag": "autopilot_key", "stage_flag": "autopilot_unlocked"}
	GameState.flags.erase(&"autopilot_key")
	GameState.flags.erase(&"autopilot_unlocked")
	assert_false(x.force_depart(), "dormant: nothing")
	x.state = ExfilPoint.State.ACTIVE
	assert_false(x.force_depart(), "lit but locked (no key): the act's fallback must set it first")
	assert_eq(x.state, ExfilPoint.State.ACTIVE)
	GameState.flags.erase(&"autopilot_key")
	x.free()


func test_dummy_has_the_beacon_counters() -> void:
	var d: RefCounted = (load("res://tools_src/soak_dummy.gd") as GDScript).new()
	assert_eq(int(d.get("exfil_votes")), 0)
	assert_eq(int(d.get("doors_bought")), 0)
	assert_eq(int(d.get("ALL_LAYERS")), 0x7FFFFFFF)
	assert_true(float(d.get("EXFIL_ERRAND_S")) > 40.0, "a beacon errand outlasts the shopping limit")
