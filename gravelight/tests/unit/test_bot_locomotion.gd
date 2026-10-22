extends GutTest
## Update 03 section 3 (T-056): the bots' locomotion layer's pure rules and the training-route maths: route
## smoothing / parameters / ring, the authored route data, wedge slots, the personal-space push and the step-aside
## decision, the stuck ladder's timing, the door rule, the lift rule, and MoveIntent's local stick.

var loco_cfg: Dictionary


func before_all() -> void:
	loco_cfg = GLData.load_json("res://data/gravelight/ai/locomotion.json")


func _square(side: float) -> TrainingRoute:
	return TrainingRoute.make("sq", PackedVector3Array([Vector3(0, 0, 0), Vector3(side, 0, 0), Vector3(side, 0, side), Vector3(0, 0, side)]), 3.0, 0)


# ---------------------------------------------------------------- TrainingRoute

func test_route_length_and_wrap() -> void:
	var r: TrainingRoute = _square(10.0)
	assert_almost_eq(r.length(), 40.0, 0.01, "an unsmoothed 10 m square is 40 m round")
	assert_almost_eq(r.wrap_param(41.0), 1.0, 0.001)
	assert_almost_eq(r.wrap_param(-1.0), 39.0, 0.001)
	assert_true(r.point_at(0.0).distance_to(Vector3(0, 0, 0)) < 0.01)
	assert_true(r.point_at(15.0).distance_to(Vector3(10, 0, 5)) < 0.01, "15 m along: halfway down the second side")
	assert_true(r.point_at(40.0).distance_to(r.point_at(0.0)) < 0.01, "the loop is closed")


func test_route_closest_param_and_advance() -> void:
	var r: TrainingRoute = _square(10.0)
	assert_almost_eq(r.closest_param(Vector3(5, 0, -1.5)), 5.0, 0.01, "off the first side: its middle")
	assert_almost_eq(r.closest_param(Vector3(11, 0, 5)), 15.0, 0.01)
	assert_almost_eq(r.advance(38.0, 4.0, 1), 2.0, 0.001, "advance wraps forward")
	assert_almost_eq(r.advance(2.0, 4.0, -1), 38.0, 0.001, "and backward")
	assert_almost_eq(r.distance_along(38.0, 2.0, 1), 4.0, 0.001)
	assert_almost_eq(r.distance_along(2.0, 38.0, -1), 4.0, 0.001)
	assert_true(r.tangent_at(5.0).distance_to(Vector3(1, 0, 0)) < 0.01, "the first side runs +x")


func test_route_ring() -> void:
	var r: TrainingRoute = _square(10.0)
	assert_true(r.contains_ring(Vector3(5, 0, 1.2)), "1.2 m off the line, ring 3 m wide")
	assert_false(r.contains_ring(Vector3(5, 0, 1.8)), "1.8 m off: outside")
	assert_false(r.contains_ring(Vector3(5, 3, 0)), "another floor")


func test_route_smoothing_caps_the_cut() -> void:
	var raw: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(40, 0, 0), Vector3(40, 0, 10), Vector3(0, 0, 10)])
	var cut: PackedVector3Array = TrainingRoute.chaikin_closed(raw, 1.2)
	assert_eq(cut.size(), 8)
	assert_true(cut[0].distance_to(Vector3(1.2, 0, 0)) < 0.01, "a long edge is cut 1.2 m from its corner, not a quarter")
	assert_true(cut[2].distance_to(Vector3(40, 0, 1.2)) < 0.01)
	var r: TrainingRoute = TrainingRoute.make("long", raw, 3.0, 2)
	assert_true(r.length() < 100.0 and r.length() > 95.0, "smoothing shortens the loop only a little (%.2f)" % r.length())
	for i: int in r.samples.size():
		var nxt: Vector3 = r.samples[(i + 1) % r.samples.size()]
		assert_true(r.samples[i].distance_to(nxt) < 0.6, "samples about 0.5 m apart")


func test_route_requirements() -> void:
	var r: TrainingRoute = TrainingRoute.from_dict({"id": "x", "points": [[0, 0, 0], [8, 0, 0], [8, 0, 8], [0, 0, 8]],
		"requires_doors": ["door_stable"], "requires_zones": ["STABLE"]}, "map00")
	assert_false(r.doors_ok({}))
	assert_true(r.doors_ok({"door_stable": true}))
	assert_false(r.zones_ok({&"TAPROOM": true}))
	assert_true(r.zones_ok({&"TAPROOM": true, &"STABLE": true}))


func test_authored_routes_load() -> void:
	assert_eq(TrainingRoute.map_key_of("map00_crossroads"), "map00")
	var m0: Array[TrainingRoute] = TrainingRoute.all_for_map("map00_crossroads")
	var m1: Array[TrainingRoute] = TrainingRoute.all_for_map("map01")
	var ids: Array = []
	for r: TrainingRoute in m0 + m1:
		ids.append(r.id)
		assert_true(r.length() > 15.0, "%s has a real loop (%.1f m)" % [r.id, r.length()])
		assert_true(r.ring_width >= 2.0, "%s ring width" % r.id)
		assert_true(r.point_at(r.length()).distance_to(r.point_at(0.0)) < 0.01, "%s is closed" % r.id)
	for want: String in ["map00_taproom", "map00_taproom_stable", "map00_cellar_barrels", "map01_headframe", "map01_pews", "map01_turbines"]:
		assert_has(ids, want)


# ---------------------------------------------------------------- formation

func test_wedge_slots_spread() -> void:
	var still: Array = (loco_cfg["formation"] as Dictionary)["still"]
	var heading: Vector3 = Vector3(0, 0, -1)
	var offs: Array[Vector3] = []
	for i: int in 3:
		var o: Vector3 = BotLocomotion.wedge_offset(still, i, heading)
		offs.append(o)
		assert_true(o.dot(heading) < 0.0, "standing still, slot %d is behind the leader's facing" % i)
		assert_true(o.length() >= 2.0, "slot %d keeps out of the leader's personal space" % i)
	# never all in one cone from the leader: at least 60 degrees between any two slots
	for a: int in 3:
		for b: int in range(a + 1, 3):
			assert_true(rad_to_deg(offs[a].angle_to(offs[b])) >= 40.0, "slots %d and %d spread apart" % [a, b])
	var mirrored: Vector3 = BotLocomotion.wedge_offset(still, 0, heading, true)
	assert_almost_eq(mirrored.x, -offs[0].x, 0.001, "mirrored = the other side")


func test_wedge_moving_never_behind() -> void:
	var moving: Array = (loco_cfg["formation"] as Dictionary)["moving"]
	var heading: Vector3 = Vector3(1, 0, 0)
	for i: int in 3:
		var o: Vector3 = BotLocomotion.wedge_offset(moving, i, heading)
		assert_true(o.dot(heading) > -0.05, "a training leader's slot %d is beside or ahead, never behind" % i)
		assert_true(absf(o.z) > 1.2, "slot %d is off the leader's line (lateral %.2f)" % [i, o.z])


# ---------------------------------------------------------------- personal space / step aside

func test_personal_space_push() -> void:
	var h: Vector3 = Vector3.ZERO
	assert_eq(BotLocomotion.personal_space_push(Vector3(2.0, 0, 0), h, Vector3.ZERO), Vector3.ZERO, "outside the 1.2 m bubble: nothing")
	var p: Vector3 = BotLocomotion.personal_space_push(Vector3(0.6, 0, 0), h, Vector3.ZERO)
	assert_true(p.x > 0.0 and absf(p.z) < 0.001, "a standing human pushes straight away")
	var closer: Vector3 = BotLocomotion.personal_space_push(Vector3(0.3, 0, 0), h, Vector3.ZERO)
	assert_true(closer.length() > p.length(), "stronger the closer it is")
	# a human walking at the bot (+z): the bubble reaches further ahead and the push is mostly sideways
	var ahead: Vector3 = BotLocomotion.personal_space_push(Vector3(0.1, 0, 1.6), h, Vector3(0, 0, 4.5))
	assert_ne(ahead, Vector3.ZERO, "1.6 m ahead of a walking human is inside the stretched bubble")
	assert_true(absf(ahead.x) > absf(ahead.z) * 0.8, "pushed off their line, not along it")
	assert_true(ahead.x > 0.0, "to the side it already leans to")
	assert_eq(BotLocomotion.personal_space_push(Vector3(0, 0, -1.6), h, Vector3(0, 0, 4.5)), Vector3.ZERO, "behind them the bubble isn't stretched")


func test_should_yield() -> void:
	var sp: Dictionary = loco_cfg["space"]
	var hz: float = float(sp["horizon_s"])
	var pm: float = float(sp["pass_m"])
	assert_true(BotLocomotion.should_yield(Vector3(0, 0, 3), Vector3.ZERO, Vector3(0, 0, 4.5), hz, pm), "a human running straight at it")
	assert_false(BotLocomotion.should_yield(Vector3(3, 0, 3), Vector3.ZERO, Vector3(0, 0, 4.5), hz, pm), "passing 3 m to the side")
	assert_false(BotLocomotion.should_yield(Vector3(0, 0, -3), Vector3.ZERO, Vector3(0, 0, 4.5), hz, pm), "moving away")
	assert_false(BotLocomotion.should_yield(Vector3(0, 0, 9), Vector3.ZERO, Vector3(0, 0, 4.5), hz, pm), "too far ahead to matter yet")
	assert_false(BotLocomotion.should_yield(Vector3(0, 0, 1), Vector3.ZERO, Vector3(0, 0, 0.3), hz, pm), "standing still")


# ---------------------------------------------------------------- stuck ladder

func test_stuck_ladder_timing() -> void:
	var st: Dictionary = loco_cfg["stuck"]
	var r: float = float(st["repath_s"])
	var n: float = float(st["nudge_s"])
	var t: float = float(st["teleport_s"])
	assert_eq([r, n, t], [2.0, 4.0, 8.0], "the brief's 2 / 4 / 8 s")
	assert_eq(BotLocomotion.stuck_stage(1.9, r, n, t), 0)
	assert_eq(BotLocomotion.stuck_stage(2.0, r, n, t), 1, "2 s: repath")
	assert_eq(BotLocomotion.stuck_stage(3.9, r, n, t), 1)
	assert_eq(BotLocomotion.stuck_stage(4.0, r, n, t), 2, "4 s: nudge")
	assert_eq(BotLocomotion.stuck_stage(7.99, r, n, t), 2)
	assert_eq(BotLocomotion.stuck_stage(8.0, r, n, t), 3, "8 s: teleport (when unseen)")


# ---------------------------------------------------------------- doors / lift

func test_door_rule() -> void:
	# a door at the origin in the x-y plane (normal +z), 2 m wide
	var pos: Vector3 = Vector3.ZERO
	var nrm: Vector3 = Vector3(0, 0, 1)
	var along: Vector3 = Vector3(1, 0, 0)
	var through: PackedVector3Array = PackedVector3Array([Vector3(0.2, 0, -3), Vector3(0.1, 0, 3)])
	var beside: PackedVector3Array = PackedVector3Array([Vector3(4, 0, -3), Vector3(4, 0, 3)])
	var corner: PackedVector3Array = PackedVector3Array([Vector3(0.5, 0, -3), Vector3(0.0, 0, 0.0), Vector3(-0.5, 0, 3)])
	var same_side: PackedVector3Array = PackedVector3Array([Vector3(-2, 0, -3), Vector3(2, 0, -1)])
	var other_floor: PackedVector3Array = PackedVector3Array([Vector3(0, -3.2, -3), Vector3(0, -3.2, 3)])
	assert_true(BotLocomotion.path_crosses_door(through, pos, nrm, along, 1.3), "straight through the doorway")
	assert_true(BotLocomotion.path_crosses_door(corner, pos, nrm, along, 1.3), "a path corner exactly in the doorway still crosses")
	assert_false(BotLocomotion.path_crosses_door(beside, pos, nrm, along, 1.3), "through the wall beside it is not this door")
	assert_false(BotLocomotion.path_crosses_door(same_side, pos, nrm, along, 1.3), "staying on one side")
	assert_false(BotLocomotion.path_crosses_door(other_floor, pos, nrm, along, 1.3), "the cellar under it")


func test_lift_rule() -> void:
	assert_true(BotLocomotion.lift_ok(3, 3, 20.0, 10.0), "the whole squad in the cage, nothing near")
	assert_false(BotLocomotion.lift_ok(2, 3, 20.0, 10.0), "someone is missing")
	assert_false(BotLocomotion.lift_ok(3, 3, 6.0, 10.0), "a train is near")
	assert_false(BotLocomotion.lift_ok(0, 0, 50.0, 10.0))


# ---------------------------------------------------------------- MoveIntent

func test_move_intent_local_stick() -> void:
	var b: Basis = Basis()   # facing -z
	assert_true(MoveIntent.local_move(b, Vector3(0, 0, -1)).distance_to(Vector2(0, -1)) < 0.001, "forward = stick up (-y)")
	assert_true(MoveIntent.local_move(b, Vector3(1, 0, 0)).distance_to(Vector2(1, 0)) < 0.001, "right")
	var turned: Basis = Basis(Vector3.UP, PI * 0.5)   # facing -x
	assert_true(MoveIntent.local_move(turned, Vector3(-1, 0, 0)).distance_to(Vector2(0, -1)) < 0.001, "walking where it faces is forward")
	assert_true(MoveIntent.local_move(b, Vector3(3, 0, 4)).length() <= 1.0001, "never longer than a full stick")
	assert_eq(MoveIntent.local_move(b, Vector3.ZERO), Vector2.ZERO)


func test_locomotion_flag() -> void:
	assert_true(BotLocomotion.enabled({"locomotion": "v2"}))
	assert_false(BotLocomotion.enabled({"locomotion": "v1"}))
	assert_eq(str(GLData.load_json("res://data/gravelight/bots.json").get("locomotion", "")), "v2", "on by default")
