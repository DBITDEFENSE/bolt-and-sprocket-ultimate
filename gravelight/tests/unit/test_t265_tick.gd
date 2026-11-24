extends GutTest
## T-265 (the scripts' cost per tick): the pure rules behind the pass. What the local camera does not see is
## animated at a quarter of the rate with the skipped time handed on; looks that need not happen every tick happen
## at a named rate and count the time between them.


func after_each() -> void:
	Zombie.view_lod = true


# ------------------------------------------------------------------ the view cone

func test_the_view_cone_holds_the_screens_corner_and_a_margin() -> void:
	# 75 degrees of vertical field at 16:9: the corner is 57.4 degrees off the axis, the cone 10 degrees wider
	var c: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_almost_eq(rad_to_deg(acos(c)), 57.4 + rad_to_deg(Zombie.VIEW_MARGIN_RAD), 0.3)
	assert_lt(Zombie.view_cone_cos(110.0, 21.0 / 9.0), Zombie.view_cone_cos(75.0, 16.0 / 9.0), "a wider picture, a wider cone")
	assert_gt(Zombie.view_cone_cos(170.0, 3.0), 0.0, "never as wide as the half space: what is behind is always out of view")


func test_out_of_view_is_outside_the_cone_and_not_near() -> void:
	var fwd: Vector3 = Vector3.FORWARD
	var cone: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_false(Zombie.out_of_view(Vector3(0, 0, -10), fwd, cone), "straight ahead")
	assert_false(Zombie.out_of_view(Vector3(10, 0, -10), fwd, cone), "45 degrees off: on screen")
	assert_false(Zombie.out_of_view(Vector3(17.5, 0, -10), fwd, cone), "60 degrees off: past the edge, inside the margin")
	assert_true(Zombie.out_of_view(Vector3(40, 0, -10), fwd, cone), "76 degrees off: out")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 10), fwd, cone), "behind")
	assert_false(Zombie.out_of_view(Vector3(0, 0, 2.5), fwd, cone), "behind but within VIEW_NEAR_M: its shadow, the screen's edge")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 3.5), fwd, cone))


func test_the_animation_rate_by_distance_and_view() -> void:
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, false), 1, "near and seen: every frame")
	assert_eq(Zombie.anim_div(20.0 * 20.0, 15.0, 35.0, false), 2)
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, false), 4)
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, true), Zombie.VIEW_OUT_DIV, "near and not seen: every 4th frame")
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, true), 4)



# ------------------------------------------------------------------ the day at rest writes nothing

func _day_rig() -> Array:
	var m: Node3D = Node3D.new()
	m.set_script(load("res://gravelight/tests/unit/day_cycle_map_stub.gd"))
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	we.environment.ambient_light_energy = 0.3
	we.environment.tonemap_exposure = 1.3
	m.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_energy = 0.42
	moon.rotation_degrees = Vector3(-40, 28, 0)
	m.add_child(moon)
	add_child_autofree(m)
	return [we.environment, moon, DayCycle.attach(m)]


func test_a_day_that_stands_still_writes_nothing() -> void:
	var rig: Array = _day_rig()
	var env: Environment = rig[0]
	var moon: DirectionalLight3D = rig[1]
	var d: DayCycle = rig[2]
	assert_not_null(d)
	d.hold_hour(12.0)
	d._process(0.016)
	assert_eq(d.full_frames, 1, "the first frame at noon writes the day")
	var amb: float = env.ambient_light_energy
	for i: int in 5:
		d._process(0.016)
	assert_eq(d.full_frames, 1, "the same hour, the same roof, nothing touched: nothing written")
	assert_eq(d.skipped_frames, 5)
	assert_eq(env.ambient_light_energy, amb)
	env.ambient_light_energy = 0.15   # a zone's own night value arrives
	d._process(0.016)
	assert_eq(d.full_frames, 2, "another script's write makes the next frame a full one")
	assert_almost_eq(float(d.night_value("ambient_light_energy")), 0.15, 0.0001)
	d._process(0.016)
	assert_eq(d.full_frames, 2, "and its own write is not taken for one")
	moon.light_energy = 0.0   # a room switches the key light off
	d._process(0.016)
	assert_eq(d.full_frames, 3)
	assert_eq(moon.light_energy, 0.0)
	moon.rotation_degrees = Vector3(-10, 0, 0)   # something turns the key light
	d._process(0.016)
	assert_eq(d.full_frames, 4, "a moved key light is put back")
	d.hold_hour(13.0)
	d._process(0.016)
	assert_eq(d.full_frames, 5, "a new hour is a full frame")


func test_a_walking_hour_is_applied_in_steps_and_exactly_on_arrival() -> void:
	assert_true(DayCycle.hour_settled(13.0005, 13.0, false), "a frame's worth of hour: the light stands")
	assert_false(DayCycle.hour_settled(13.0021, 13.0, false), "HOUR_STEP later it is written again")
	assert_true(DayCycle.hour_settled(0.0005, 23.9995, false), "over midnight the gap is the short way round")
	assert_false(DayCycle.hour_settled(14.0, 13.9995, true), "arrived at the round's hour: written once more, exactly")
	assert_true(DayCycle.hour_settled(14.0, 14.0, true))


func test_the_roof_share_arrives() -> void:
	var rig: Array = _day_rig()
	var d: DayCycle = rig[2]
	d.hold_hour(12.0)
	d._process(0.016)
	d._roofed = true
	var frames: int = 0
	while d.indoor < 1.0 and frames < 600:
		d._process(1.0 / 60.0)
		frames += 1
	assert_eq(d.indoor, 1.0, "the share lands on its target (within SETTLE_EPS it is set there)")
	assert_lt(frames, 400, "in a few seconds")
	var full: int = d.full_frames
	d._process(1.0 / 60.0)
	assert_eq(d.full_frames, full, "and then the frames are free again")


# ------------------------------------------------------------------ rates

func test_the_named_rates() -> void:
	assert_eq(BotLocomotion.NAV_LOOK_S, 0.2, "a walking bot asks the navmesh under it five times a second")
	assert_eq(CoopHud.ROWS_EVERY_S, 0.1, "the squad panel's rows are gathered ten times a second")
	assert_eq(Zombie.VIEW_OUT_DIV, 4)
