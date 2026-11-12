extends GutTest
## T-234 (docs/boss_rework/w4_fernflug.md): the Fernflug bosses' rework rules and data. The Kranführer's work-light
## drops and his alone rule; the Bordwart's hurt pull; the Test Pilot's unwatching pick and the Stall's Burrowers; the
## Account Manager's light, the squad pricing's trigger and the solo presentation; every boss's dread block (a kit
## surface, no footfalls through the base) and the rework numbers the scripts read.


func test_kranfuehrer_work_lights_drop_by_phase_never_the_last_three() -> void:
	assert_eq(Kranfuehrer.lights_to_drop(10, 10, 0.35, 3), 4, "35 % of ten, rounded up")
	assert_eq(Kranfuehrer.lights_to_drop(10, 6, 0.35, 3), 3, "the second step stops at three lit")
	assert_eq(Kranfuehrer.lights_to_drop(10, 3, 0.35, 3), 0, "the three nearest the ramp stay")
	assert_eq(Kranfuehrer.lights_to_drop(0, 0, 0.35, 3), 0, "no lights (the power is off): nothing")
	assert_eq(Kranfuehrer.lights_to_drop(4, 4, 0.35, 3), 1)


func test_kranfuehrer_alone_needs_teammates() -> void:
	assert_false(Kranfuehrer.is_alone(Vector3.ZERO, [], 12.0), "a squad of one is never alone")
	assert_true(Kranfuehrer.is_alone(Vector3.ZERO, [Vector3(20, 0, 0)], 12.0))
	assert_false(Kranfuehrer.is_alone(Vector3.ZERO, [Vector3(20, 0, 0), Vector3(5, 0, 5)], 12.0), "one teammate near: covered")
	assert_false(Kranfuehrer.is_alone(Vector3.ZERO, [Vector3(0, 30, 11)], 12.0), "height does not count: a teammate 11 m away flat covers you from the catwalk")


func test_bordwart_pull_takes_the_hurt_first() -> void:
	assert_almost_eq(Bordwart.pull_mps(2.5, 1.0, 0.5, 1.4), 2.5, 0.001)
	assert_almost_eq(Bordwart.pull_mps(2.5, 0.5, 0.5, 1.4), 2.5, 0.001, "at the line: normal")
	assert_almost_eq(Bordwart.pull_mps(2.5, 0.49, 0.5, 1.4), 3.5, 0.001, "under half health: x1.4")


func test_testpilot_watching_and_the_stalls_burrowers() -> void:
	assert_true(TestPilot.watching(Vector3(0, 0, -1), Vector3.ZERO, Vector3(0, 0, -10)), "looking straight at him")
	assert_true(TestPilot.watching(Vector3(0, 0, -1), Vector3.ZERO, Vector3(5, 0, -6)), "in the view's half")
	assert_false(TestPilot.watching(Vector3(0, 0, -1), Vector3.ZERO, Vector3(0, 0, 10)), "he is behind you")
	assert_false(TestPilot.watching(Vector3(0, 0, -1), Vector3.ZERO, Vector3(10, 0, 0)), "square to your side: not watched")
	assert_true(TestPilot.watching(Vector3(0, 0, -1), Vector3.ZERO, Vector3.ZERO), "on top of you counts as seen")
	assert_eq(TestPilot.stall_burrowers(1, 3, 1), 3)
	assert_eq(TestPilot.stall_burrowers(4, 3, 1), 6, "one more per extra player")


func test_account_manager_light_and_the_squad_pricing() -> void:
	var o: Vector3 = Vector3(28, 0, -34)
	var fwd: Vector3 = Vector3(0, 0, 1)
	assert_true(AccountManager.in_light(o, fwd, o + Vector3(0, 0, 4), 7.0, 0.35), "in front, close")
	assert_false(AccountManager.in_light(o, fwd, o + Vector3(0, 0, 10), 7.0, 0.35), "too far")
	assert_false(AccountManager.in_light(o, fwd, o + Vector3(0, 0, -4), 7.0, 0.35), "behind her")
	assert_false(AccountManager.in_light(o, fwd, o + Vector3(6, 0, 1), 7.0, 0.35), "off to the side of the beam")
	assert_true(AccountManager.in_light(o, fwd, o, 7.0, 0.35), "at the console")
	assert_false(AccountManager.price_all_due(2, 10.0, 6.0, true), "not before COLLECTIONS")
	assert_false(AccountManager.price_all_due(3, 5.9, 6.0, true), "someone stood in the light lately")
	assert_false(AccountManager.price_all_due(3, 9.0, 6.0, false), "on cooldown")
	assert_true(AccountManager.price_all_due(3, 6.0, 6.0, true))
	assert_almost_eq(AccountManager.present_seconds(3.0, 1, 1.5), 4.5, 0.001, "one human standing: longer")
	assert_almost_eq(AccountManager.present_seconds(3.0, 2, 1.5), 3.0, 0.001)
	assert_almost_eq(AccountManager.present_seconds(3.0, 0, 1.5), 4.5, 0.001, "bots alone: the long one too")


func test_every_fernflug_boss_has_a_dread_block_and_the_rework_numbers() -> void:
	var t: Dictionary = GLData.table("bosses/map04")
	var bosses: Dictionary = t["bosses"]
	var want_surface: Dictionary = {"kranfuehrer": "iron", "bordwart": "iron", "testpilot": "flesh", "account_manager": "glass"}
	for id: String in want_surface.keys():
		var b: Dictionary = bosses[id]
		assert_true(b.has("dread"), id + " has a dread block")
		var d: Dictionary = b.get("dread", {})
		assert_eq(str(d.get("surface", "")), str(want_surface[id]), id + "'s surface")
		assert_eq(str(d.get("step_sound", "")), "", id + " has no footfalls through the base")
		assert_almost_eq(float(d.get("step_shake", 0.0)), 0.0, 0.001, id + " has no step shake")
		assert_true(b.has("rework"), id + " has its rework block")
	var tp: Dictionary = bosses["testpilot"]["dread"]
	assert_eq(str(tp["land_sound"]), "boss_stomp", "the Pilot's landings stomp")
	assert_almost_eq(float(tp["land_shake"]), 0.5, 0.001)
	assert_true(bool(bosses["testpilot"]["leap"]["prefer_unwatching"]))
	assert_gt(int(bosses["testpilot"]["stall"]["burrowers"]), 0)
	assert_gt(float(bosses["kranfuehrer"]["rework"]["alone_dist"]), 0.0)
	assert_gte(int(bosses["kranfuehrer"]["rework"]["keep_lit"]), 1, "the hangar never goes fully dark")
	assert_lt(float(bosses["bordwart"]["pull"]["hurt_below"]), 1.0)
	assert_gt(float(bosses["bordwart"]["pull"]["hurt_mult"]), 1.0)
	var pc: Dictionary = bosses["account_manager"]["price"]
	assert_gt(float(pc["dark_after"]), 0.0)
	assert_gte(float(pc["all_telegraph"]), 0.5, "the squad pricing keeps a telegraph of half a second or more")
	assert_lt(float(pc["all_damage"]), float(pc["damage"]), "the squad pricing hits each lighter than one stamp")
	assert_lt(float(pc["all_scrip_fraction"]), float(pc["scrip_fraction"]))
	assert_gt(float(pc["all_cooldown"]), float(pc["cooldown"]))
	# the kit's sound ids these scripts play all exist
	var sounds: Dictionary = (GLData.load_json("res://data/gravelight/audio.json") as Dictionary).get("sounds", {})
	for k: String in ["kran_rail_screech", "kran_casing_drop", "bordwart_impeller_loop", "bordwart_cable_sing", "pilot_rig_whine",
			"pilot_rig_misfire", "manager_servo", "manager_stamp", "manager_field_hum", "boss_stomp", "boss_breath", "boss_roar_low",
			"boss_hit_iron", "boss_hit_glass", "boss_telegraph_rise"]:
		assert_true(sounds.has(k), k + " is in audio.json")
