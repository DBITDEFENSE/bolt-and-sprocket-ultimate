extends GutTest
## THE TEST PILOT's rules (UPDATE 07, docs/MAP4_FERNFLUG.md §5.7; gravelight/enemies/map04/testpilot.gd): phases by
## health, the damage he takes by state, the leap's clamp and arc, the scaled health, and the data the act
## schedules him from.


func test_phases_by_health() -> void:
	var ph: Dictionary = {"lake_at": 0.6, "stall_at": 0.3}
	assert_eq(TestPilot.phase_of(1.0, ph), 1)
	assert_eq(TestPilot.phase_of(0.61, ph), 1)
	assert_eq(TestPilot.phase_of(0.6, ph), 2, "60 %: up to the lake bed")
	assert_eq(TestPilot.phase_of(0.31, ph), 2)
	assert_eq(TestPilot.phase_of(0.3, ph), 3, "30 %: the stall")
	assert_eq(TestPilot.phase_of(0.0, ph), 3)


func test_damage_by_state() -> void:
	var leap: Dictionary = {"air_mult": 0.5, "idle_mult": 0.25}
	var stall: Dictionary = {"vuln_mult": 2.0}
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.VULN, false, leap, stall), 1.0, 0.001, "vulnerable on the ground")
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.LAND, false, leap, stall), 1.0, 0.001, "and at the landing")
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.DRAG, false, leap, stall), 1.0, 0.001, "and while he drags")
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.AIR, false, leap, stall), 0.5, 0.001, "half in the air")
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.IDLE, false, leap, stall), 0.25, 0.001, "a quarter between")
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.CROUCH, false, leap, stall), 0.25, 0.001)
	assert_almost_eq(TestPilot.damage_mult(TestPilot.P.STALL, true, leap, stall), 2.0, 0.001, "double while stalled")


func test_leap_target_is_clamped_to_the_range() -> void:
	var from: Vector3 = Vector3(0, -6, 0)
	assert_eq(TestPilot.leap_target(from, Vector3(10, -6, 0), 22.0), Vector3(10, -6, 0), "within range: the target itself")
	var far: Vector3 = TestPilot.leap_target(from, Vector3(60, 0, 0), 22.0)
	assert_almost_eq(far.x, 22.0, 0.001, "clamped at 22 m")
	assert_almost_eq(far.y, 0.0, 0.001, "the target's height kept (up the hatch)")
	var arc_mid: Vector3 = TestPilot.arc_point(Vector3.ZERO, Vector3(10, 0, 0), 0.5, 6.0)
	assert_almost_eq(arc_mid.y, 6.0, 0.001, "the arc's top is the height")
	assert_almost_eq(arc_mid.x, 5.0, 0.001)
	assert_eq(TestPilot.arc_point(Vector3.ZERO, Vector3(10, 0, 0), 1.0, 6.0), Vector3(10, 0, 0), "it ends at the target")
	assert_eq(TestPilot.arc_point(Vector3.ZERO, Vector3(10, 0, 0), 1.5, 6.0), Vector3(10, 0, 0), "k is clamped")


func test_scaled_health_and_data() -> void:
	var t: Dictionary = GLData.table("bosses/map04")
	var k: Dictionary = t["bosses"]["testpilot"]
	assert_eq(int(k["hp_base"]), 32000)
	assert_almost_eq(HomageBoss.scaled_hp(float(k["hp_base"]), 1, float(t["hp_player_step"])), 32000.0, 0.1)
	assert_almost_eq(HomageBoss.scaled_hp(float(k["hp_base"]), 4, float(t["hp_player_step"])), 104000.0, 0.1, "4 players: x3.25")
	assert_eq(int(k["kill_scrip_per_player"]), 1500)
	assert_eq(str(k["flag"]), "ignition_key", "he drops the rocket's key")
	assert_true((k["drops"] as Array).has("resupply"))
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	assert_true(lines.has(str(k["spawn_vo"])) and lines.has(str(k["death_vo"])), "his Operator lines exist")
	for id: String in ["RRK_BARK_01", "RRK_BARK_02", "RRK_BARK_03", "RRK_PHASE_01", "RRK_PHASE_02", "RRK_PHASE_03", "RRK_DEATH_01"]:
		assert_true(lines.has(id), "his call-out %s exists" % id)
	assert_lt(float(k["leap"]["range"]), float(k["leap"]["range_lake"]), "longer leaps on the lake bed")
	assert_gt(float(k["leap"]["vuln_seconds"]), 0.0)
	assert_lt(float(k["phases"]["stall_at"]), float(k["phases"]["lake_at"]))
	assert_almost_eq(float(k["catch_mult"]), 3.0, 0.001, "the Lodestone's catch is x3 the slam")
	var a: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")["act"]
	assert_eq(str(a["boss"]["id"]), "testpilot")
	assert_eq(str(a["boss"]["arena_zone"]), "F_LAB", "the lab's long hall")
