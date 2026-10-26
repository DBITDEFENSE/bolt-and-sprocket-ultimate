extends GutTest
## Map 4 Act II flight rules (UPDATE 07, docs/MAP4_FERNFLUG.md §4.5–§4.6): the pure rules of the FlightController,
## the BreachPanel and the Bordwart, and the act's data.

func test_strafe_line_hits_inside_the_width_and_span() -> void:
	assert_true(FlightController.strafe_line_hits(-20.0, 30.0, 44.0, 1.5, Vector3(-20.5, 0, 37)))
	assert_false(FlightController.strafe_line_hits(-20.0, 30.0, 44.0, 1.5, Vector3(-21.0, 0, 37)), "a metre off the line is clear")
	assert_false(FlightController.strafe_line_hits(-20.0, 30.0, 44.0, 1.5, Vector3(-20.0, 0, 45)), "past the span is clear")
	assert_true(FlightController.strafe_line_hits(-20.0, 44.0, 30.0, 1.5, Vector3(-20.0, 0, 31)), "the span may be given either way round")


func test_next_rack_is_the_lowest_armed() -> void:
	assert_eq(FlightController.next_rack(["armed", "armed", "armed"]), 0)
	assert_eq(FlightController.next_rack(["dropped", "jammed", "armed"]), 2)
	assert_eq(FlightController.next_rack(["dropped", "jammed", "dud"]), -1, "nothing left to drop")


func test_duds_are_two_distinct_racks_from_2_to_6() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_v: int in [1, 7, 42, 1000]:
		rng.seed = seed_v
		var d: Array[int] = FlightController.pick_duds(2, rng)
		assert_eq(d.size(), 2)
		assert_ne(d[0], d[1])
		for i: int in d:
			assert_true(i >= 1 and i <= 5, "rack index 1..5 (racks 2..6); rack 1 (Boston) is never a dud")


func test_results_and_city_flags() -> void:
	assert_eq(FlightController.result_of("jammed", false), "saved")
	assert_eq(FlightController.result_of("jammed", true), "saved", "a jammed dud is simply saved")
	assert_eq(FlightController.result_of("dropped", false), "hit")
	assert_eq(FlightController.result_of("dropped", true), "dud")
	assert_eq(FlightController.city_flag("NEW YORK", "saved"), &"bomb_new_york_saved")
	assert_eq(FlightController.city_flag("BOSTON", "hit"), &"bomb_boston_hit")


func test_breach_suction_pulls_toward_the_hole_inside_the_radius() -> void:
	var hole: Vector3 = Vector3(-20, 1, 46)
	var v: Vector3 = BreachPanel.suction_for(hole, Vector3(-20, 0, 42), 6.0, 4.0)
	assert_gt(v.z, 0.0, "pulled toward +z (the hole)")
	assert_almost_eq(v.y, 0.0, 0.001, "flat")
	assert_gt(v.length(), 2.4, "near the hole it is stronger than the far fade")
	assert_eq(BreachPanel.suction_for(hole, Vector3(-20, 0, 30), 6.0, 4.0), Vector3.ZERO, "outside the radius: nothing")
	assert_true(BreachPanel.through_hole(hole, Vector3(-20.5, 0, 46.3)))
	assert_false(BreachPanel.through_hole(hole, Vector3(-18, 0, 46)))


func test_bordwart_phases_arc_and_damage() -> void:
	var ph: Dictionary = {"cable_at": 0.6, "overspeed_at": 0.3}
	assert_eq(Bordwart.phase_of(1.0, ph), 1)
	assert_eq(Bordwart.phase_of(0.59, ph), 2)
	assert_eq(Bordwart.phase_of(0.3, ph), 3)
	assert_true(Bordwart.in_arc(Vector3.ZERO, Vector3(0, 0, -1), Vector3(1, 0, -3), 5.0))
	assert_false(Bordwart.in_arc(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, 3), 5.0), "behind him is safe")
	assert_false(Bordwart.in_arc(Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, -7), 5.0), "out of reach")
	assert_eq(Bordwart.damage_mult(1, false, &"head", false, 2.5, 0.15), 1.0)
	assert_eq(Bordwart.damage_mult(2, true, &"arms", false, 2.5, 0.15), 2.5, "the cable out is the weak point")
	assert_eq(Bordwart.damage_mult(3, false, &"head", false, 2.5, 0.15), 0.15, "overspeed: only the gauges count")
	assert_eq(Bordwart.damage_mult(3, false, &"torso", false, 2.5, 0.15), 1.0)


func test_flight_data_is_sane() -> void:
	var d: Dictionary = GLData.load_json("res://data/gravelight/map04b.json")
	var f: Dictionary = d["flight"]
	assert_gt(float(f["turbulence"]["warn_seconds"]), 2.0, "a bank is warned")
	assert_true(float(f["turbulence"]["push_mps"]) <= 3.0, "a bank is a tool, not a punishment")
	for z: String in (f["strafe"]["zones"] as Dictionary).keys():
		assert_true((d["zones"] as Dictionary).has(z), "strafe zone %s exists" % z)
		assert_true(z != "B_MITTELRUMPF" and z != "F_COCKPIT", "the centre body and the cockpit are never raked")
	assert_eq((f["bomb_run"]["cities"] as Array).size(), 6, "six racks, six cities")
	assert_eq(int(f["bomb_run"]["duds"]), 2)
	assert_true(float(f["bomb_run"]["solo_rack_interval"]) > float(f["bomb_run"]["rack_interval"]), "solo gets longer between drops")
	var ev: Dictionary = d["act"]["events"]
	assert_true(int(ev["london_window_round"]) < int(ev["bomb_run_round"]) and int(ev["bomb_run_round"]) < int(ev["autopilot_fallback_round"]), "London, then the run, then the way down")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: String in [str(f["druckabfall"]["vo_start"]), str(f["druckabfall"]["vo_end"]), str(f["druckabfall"]["pa"]), str(f["bomb_run"]["vo_start"]), str(f["bomb_run"]["vo_end"]),
			str(f["bomb_run"]["pa_start"]), str(f["bomb_run"]["pa_end"]), str(f["london"]["vo_pa"]), "PA_M4B_RACK_06", "BWT_DEATH_01", "WIT_M4A_NOTME_01"]:
		assert_true(lines.has(id), "line %s exists" % id)
	for id2: Variant in f["london"]["vo_opr"]:
		assert_true(lines.has(str(id2)), "London line %s exists" % str(id2))
	for c: String in (f["london"]["squad"] as Dictionary).keys():
		assert_true(lines.has(str(f["london"]["squad"][c])), "a London line for %s" % c)
	var bw: Dictionary = GLData.table("bosses/map04")["bosses"]["bordwart"]
	assert_eq(int(bw["hp_base"]), 30000)
	assert_eq(str(bw["flag"]), "autopilot_key", "the Bordwart drops the key")
