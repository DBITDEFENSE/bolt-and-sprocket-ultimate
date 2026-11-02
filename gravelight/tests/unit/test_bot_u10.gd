extends GutTest
## UPDATE 10 §7 (C7, DECISIONS T-163): the bots on Fernflug's new set-pieces (BotSetPieces) and the Q-19 tuning
## (bots alone through Act II): the pure rules, the data, where the new points stand, and the hooks into the brain's
## layers. The Kaltenbrunn / Totenhafen bot tests live in their own file.

const EDGES: GDScript = preload("res://gravelight/tests/unit/test_map02_edges.gd")


class FakeBreach:
	extends Node3D
	var phase: int = 0
	var cfg: Dictionary = {"radius": 9.0}

	func hole() -> Vector3:
		return global_position


# ---------------------------------------------------------------- the dust storm

func test_storm_holds_fire_at_a_far_stalker() -> void:
	assert_false(BotSetPieces.storm_may_fire(12.0, true, false, false, 7.0), "a stalker 12 m off: a shot would call it")
	assert_true(BotSetPieces.storm_may_fire(5.0, true, false, false, 7.0), "within quiet_fire_m: shoot")
	assert_true(BotSetPieces.storm_may_fire(12.0, false, false, false, 7.0), "it has eyes (not a stalker): it comes anyway")
	assert_true(BotSetPieces.storm_may_fire(12.0, true, true, false, 7.0), "already on us")
	assert_true(BotSetPieces.storm_may_fire(12.0, true, false, true, 7.0), "a teammate down / hurt: fire")


func test_storm_config() -> void:
	var st: Dictionary = BotSetPieces.cfg().get("storm", {})
	assert_gt(float(st.get("quiet_fire_m", 0.0)), 6.0, "quieter than the stalkers' 6 m hearing would be pointless")
	assert_lt(float(st.get("spacing_mult", 1.0)), 1.0, "the storm tightens the formation (stay close)")


func test_locomotion_reads_the_modifiers() -> void:
	var l: BotLocomotion = BotLocomotion.new()
	assert_true("no_sprint" in l and "spacing_mult" in l)
	assert_false(l.no_sprint)
	assert_eq(l.spacing_mult, 1.0)


# ---------------------------------------------------------------- Act II

func test_grip_rule() -> void:
	assert_true(BotSetPieces.grip_needed("warn", 10.0, 9.0, 4.0), "warned and close: to the rail")
	assert_true(BotSetPieces.grip_needed("pull", 3.0, 9.0, 4.0))
	assert_false(BotSetPieces.grip_needed("pull", 20.0, 9.0, 4.0), "far from the breach: no")
	assert_false(BotSetPieces.grip_needed("", 3.0, 9.0, 4.0), "no event: no")


func test_breach_phase_by_duck_typing() -> void:
	var sp: BotSetPieces = BotSetPieces.new()
	var b: FakeBreach = FakeBreach.new()
	b.phase = 1
	assert_eq(sp._breach_phase(b), "warn")
	b.phase = 2
	assert_eq(sp._breach_phase(b), "pull")
	b.phase = 3
	assert_eq(sp._breach_phase(b), "", "done")
	b.free()


func test_wing_walk_is_a_risky_optional_task() -> void:
	var w: Dictionary = {"open": true, "taken": false, "claimed": false, "allowed": true, "storm": false, "tilt": false,
		"hp": 1.0, "hp_min": 0.7, "break": true, "nearest_m": 2.0, "quiet_m": 18.0}
	assert_true(BotSetPieces.wing_walk_ok(w), "open, the token there, a break")
	for k: String in ["open", "allowed"]:
		var w2: Dictionary = w.duplicate()
		w2[k] = false
		assert_false(BotSetPieces.wing_walk_ok(w2), "not without " + k)
	for k: String in ["taken", "claimed", "tilt"]:
		var w3: Dictionary = w.duplicate()
		w3[k] = true
		assert_false(BotSetPieces.wing_walk_ok(w3), "not when " + k)
	var hurt: Dictionary = w.duplicate()
	hurt["hp"] = 0.5
	assert_false(BotSetPieces.wing_walk_ok(hurt), "not hurt")
	var busy: Dictionary = w.duplicate()
	busy["break"] = false
	assert_false(BotSetPieces.wing_walk_ok(busy), "mid-round with a zombie 2 m off: no")
	busy["nearest_m"] = 30.0
	assert_true(BotSetPieces.wing_walk_ok(busy), "mid-round with nothing near: a quiet spell")


func test_act2_classes_fit_the_bot_hooks() -> void:
	# Act II's rework (T-156) may not be on this branch yet; when it is, its pieces are what the hooks read
	if not ResourceLoader.exists("res://gravelight/world/map04/wing_walk.gd"):
		pass_test("Act II's set-pieces are not on this branch")
		return
	var aux: String = FileAccess.get_file_as_string("res://gravelight/world/map04/aux_bus.gd")
	assert_true(aux.contains("extends PowerSwitch"), "the aux bus is a PowerSwitch: the economy's power plan throws it")
	var src: String = FileAccess.get_file_as_string("res://gravelight/world/map04/bay_doors_trap.gd")
	assert_true(src.contains("func danger_contains") and src.contains("&\"traps\""), "the bay doors are a trap the bots keep out of")
	var ww: String = FileAccess.get_file_as_string("res://gravelight/world/map04/wing_walk.gd")
	assert_true(ww.contains("func is_clipped") and ww.contains("func clip("), "the wing walk's clip API")
	var rg: String = FileAccess.get_file_as_string("res://gravelight/world/map04/rail_grip.gd")
	assert_true(rg.contains("func hold(player: Player, on: bool)"), "RailGrip.hold for bots")
	var dc: String = FileAccess.get_file_as_string("res://gravelight/world/map04/decompression.gd")
	assert_true(dc.contains("enum Phase { IDLE, WARN, PULL, DONE }"), "the phase order _breach_phase reads")
	var ch: String = FileAccess.get_file_as_string("res://gravelight/world/map04/wing_chest.gd")
	assert_true(ch.contains("enum State { SHUT, OPEN, EMPTY }"), "the chest state order the wing walk reads (2 = taken)")


# ---------------------------------------------------------------- Act III

func test_collapse_box_as_a_danger_disc() -> void:
	var d: Dictionary = BotSetPieces.box_disc([[0, 0, 0], [6, 4, 8]], 1.5)
	assert_eq(d["pos"], Vector3(3, 0, 4))
	assert_almost_eq(float(d["radius"]), 5.0 + 1.5, 0.001)
	assert_true(BotSetPieces.box_disc([], 1.0).is_empty())


func test_every_collapse_section_has_a_box() -> void:
	var wc: Dictionary = (GLData.load_json("res://data/gravelight/map04c.json").get("groom", {}) as Dictionary).get("wreck_collapse", {})
	var n: int = 0
	for sec: Variant in wc.get("sections", []):
		assert_eq(((sec as Dictionary).get("box", []) as Array).size(), 2, "section %s has a box the bots avoid" % (sec as Dictionary).get("id", "?"))
		n += 1
	assert_gt(n, 1, "the bay roof and the west hull")


func test_radar_perch_stands_on_the_tower_deck() -> void:
	var sp: Dictionary = GLData.load_json("res://data/gravelight/ai/routes_map04c.json").get("setpieces", {})
	var top: Array = (sp.get("perch", {}) as Dictionary).get("pos", [])
	assert_eq(top.size(), 3)
	var link: Dictionary = (GLData.load_json("res://data/gravelight/map04c.json").get("climb_links", []) as Array)[0]
	assert_eq(str(link.get("name", "")), "Climb_TowerPerch")
	var lt: Array = link.get("to", [])
	assert_almost_eq(Vector3(float(top[0]), float(top[1]), float(top[2])).distance_to(Vector3(float(lt[0]), float(lt[1]), float(lt[2]))), 0.0, 1.0,
		"the perch is where the tower's climb lands")
	assert_true(bool((BotAIData.personality("wren").get("combat", {}) as Dictionary).get("high_ground", false)), "Wren takes high ground")


func test_people_and_the_jukebox_are_never_errands() -> void:
	var bot_groups: Array = ["doors", "traps", "power_switch", "crate_spots", "wall_buys", "perk_machines", "workbenches", "buildable_parts", "quest_radios", "quest_bells", "ammo_boxes"]
	for path: String in ["res://gravelight/world/map04/jukebox.gd", "res://gravelight/world/extra_person.gd"]:
		if not ResourceLoader.exists(path):
			continue
		var src: String = FileAccess.get_file_as_string(path)
		for g: String in bot_groups:
			assert_false(src.contains("add_to_group(&\"%s\")" % g), "%s is in no group a bot shops or works from (%s)" % [path.get_file(), g])


# ---------------------------------------------------------------- Act IV

func test_meteor_box_and_shelters() -> void:
	var box: Array = (GLData.load_json("res://data/gravelight/map04d.json").get("meteor_shower", {}) as Dictionary).get("yard_box", [])
	assert_eq(box.size(), 4)
	assert_true(BotSetPieces.in_box2(box, Vector3(0, 0, 80)), "the yard's middle")
	assert_false(BotSetPieces.in_box2(box, Vector3(0, 0, 40)), "the concourse")
	var sh: Array = (GLData.load_json("res://data/gravelight/ai/routes_map04d.json").get("setpieces", {}) as Dictionary).get("meteor_shelter", [])
	assert_gt(sh.size(), 0, "somewhere to shelter")
	var polys: Array = EDGES._nav_polys(EDGES._state_nodes("res://gravelight/maps/map04_fernflug/map04d.tscn"))
	for a: Variant in sh:
		var p: Vector3 = BotSetPieces._v3(a)
		assert_false(BotSetPieces.in_box2(box, p, 1.5), "shelter %s is out of the yard box (under a roof)" % p)
		assert_true(EDGES._on_navmesh(p, polys, 1.2, 0.6), "shelter %s is on the navmesh" % p)


func test_meteor_shower_says_when_it_warns() -> void:
	var ms: Node = load("res://gravelight/world/map04/meteor_shower.gd").new()
	assert_true("warning" in ms, "the bots shelter from the warning on")
	assert_false(bool(ms.get("warning")))
	ms.free()


func test_lever_rule() -> void:
	assert_true(BotSetPieces.lever_worth(5, 4000, 1000, false, 4, 1500))
	assert_false(BotSetPieces.lever_worth(3, 4000, 1000, false, 4, 1500), "too few on the grate")
	assert_false(BotSetPieces.lever_worth(5, 2000, 1000, false, 4, 1500), "can't spare the price")
	assert_false(BotSetPieces.lever_worth(5, 4000, 1000, true, 4, 1500), "cooling down / open")


func test_jump_pad_shortcut() -> void:
	assert_true(BotSetPieces.pad_shortcut(40.0, 5.0, 10.0, 8.0), "5 + 10 + 8 < 40")
	assert_false(BotSetPieces.pad_shortcut(20.0, 5.0, 10.0, 8.0), "not worth the detour")


func test_night_side_without_a_terminator_is_day() -> void:
	assert_false(BotSetPieces.night_at(null, Vector3.ZERO))
	assert_false(BotSetPieces.night_at(get_tree(), Vector3.ZERO), "no Terminator in the test tree")


# ---------------------------------------------------------------- Q-19 (bots alone through Act II)

func test_every_act_has_a_home_loop() -> void:
	for mid: String in ["map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]:
		var homes: int = 0
		for r: TrainingRoute in TrainingRoute.all_for_map(mid):
			if r.home > 0.0:
				homes += 1
		assert_gt(homes, 0, "%s has a home loop for a self-led squad" % mid)
	var first_home: TrainingRoute = null
	for r2: TrainingRoute in TrainingRoute.all_for_map("map04b_kranich"):
		if r2.home > 0.0 and (first_home == null or r2.home < first_home.home):
			first_home = r2
	assert_true(first_home != null and first_home.requires_doors.is_empty(), "Act II's first home needs no door (the spawn bay)")


func test_bordwart_counters() -> void:
	var c: Dictionary = BotAIData.counter(&"bordwart")
	var b: Dictionary = (GLData.table("bosses/map04").get("bosses", {}) as Dictionary).get("bordwart", {})
	assert_true(bool(c.get("boss", false)) and bool(c.get("never_melee", false)))
	assert_gt(float(c.get("keep_distance_m", 0.0)), float((b.get("vent", {}) as Dictionary).get("radius", 4.0)), "out of the vent")
	assert_gt(float(c.get("keep_distance_m", 0.0)), float((b.get("cable", {}) as Dictionary).get("reach", 5.0)), "out of the cable's reach")
	assert_eq(str(c.get("aim", "")), "chest", "the gauges (torso) are what counts in OVERSPEED")
	for id: StringName in [&"kranfuehrer", &"testpilot", &"account_manager"]:
		assert_true(bool(BotAIData.counter(id).get("boss", false)), "%s has boss counters" % id)


func test_retreat_avoids_dead_ends_and_break_trips_fit() -> void:
	var rc: Dictionary = BotAIData.combat("retreat")
	assert_gt(float(rc.get("escape_probe_m", 0.0)), 0.0, "a retreat spot must have floor beyond it")
	assert_gt(float(rc.get("dead_end_cost", 0.0)), 0.0)
	var eco: Dictionary = BotAIData.table("economy")
	assert_gt(float(eco.get("self_led_trip_mps", 0.0)), 0.0, "a far errand in a break must fit in the break")


func test_setpieces_config_sections() -> void:
	for k: String in ["storm", "collapse", "decompression", "wing_walk", "meteor", "shaft_grate", "jump_pads", "perch"]:
		assert_true(BotSetPieces.cfg().has(k), "setpieces.json " + k)
