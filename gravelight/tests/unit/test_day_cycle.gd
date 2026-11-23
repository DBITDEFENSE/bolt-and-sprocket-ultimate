extends GutTest
## T-259: the day (DayCycle). One hour per round and a day every 24 rounds on every map the file turns on; round 1
## is the authored night exactly; the sun is up between rounds 7 and 19; the key light is the authored moon at night
## and the sun on an east-south-west arc by day; the air's daylight is blended over what other scripts write, is
## smaller under a roof and absent below ground; leaving the tree puts the shader global back.

const NIGHT_MAPS: PackedStringArray = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]


func before_each() -> void:
	DayCycle.reset_cache()


func _cfg() -> Dictionary:
	return DayCycle.config_for("map00_crossroads")


func test_a_day_is_24_rounds_on_every_night_map() -> void:
	for id: String in NIGHT_MAPS:
		var c: Dictionary = DayCycle.config_for(id)
		assert_true(bool(c.get("enabled", false)), id + " has the day")
		assert_eq(int(c["rounds_per_day"]), 24, id)
		assert_almost_eq(DayCycle.hour_for_round(1, c), 0.0, 0.001, id + ": round 1 is midnight")
		assert_almost_eq(DayCycle.hour_for_round(13, c), 12.0, 0.001, id + ": round 13 is noon")
		assert_almost_eq(DayCycle.hour_for_round(25, c), 0.0, 0.001, id + ": round 25 is midnight again")
		assert_almost_eq(DayCycle.hour_for_round(0, c), 0.0, 0.001, id + ": before the first round")


func test_round_1_is_the_authored_night() -> void:
	var f: Dictionary = DayCycle.factors(DayCycle.hour_for_round(1, _cfg()), _cfg())
	assert_eq(float(f["day"]), 0.0)
	assert_eq(float(f["sun"]), 0.0)
	assert_eq(float(f["moon"]), 1.0)
	assert_almost_eq(float(f["twilight"]), 0.0, 0.0001)


func test_it_becomes_day_slowly_and_night_again() -> void:
	var c: Dictionary = _cfg()
	var last: float = -1.0
	for r: int in range(1, 14):
		var d: float = float(DayCycle.factors(DayCycle.hour_for_round(r, c), c)["day"])
		assert_true(d >= last, "round %d is no darker than the round before" % r)
		last = d
	assert_eq(float(DayCycle.factors(DayCycle.hour_for_round(5, c), c)["day"]), 0.0, "round 5 is still night")
	assert_gt(float(DayCycle.factors(DayCycle.hour_for_round(7, c), c)["day"]), 0.1, "round 7: the sun rises")
	assert_almost_eq(float(DayCycle.factors(DayCycle.hour_for_round(13, c), c)["day"]), 1.0, 0.001, "noon")
	assert_almost_eq(float(DayCycle.factors(DayCycle.hour_for_round(13, c), c)["sun"]), 1.0, 0.001)
	assert_eq(float(DayCycle.factors(DayCycle.hour_for_round(21, c), c)["day"]), 0.0, "round 21 is night again")
	assert_eq(float(DayCycle.factors(DayCycle.hour_for_round(22, c), c)["moon"]), 1.0, "the moon is back")
	# the two are never the key light at once: the swap is in the dark
	for h: int in 240:
		var f: Dictionary = DayCycle.factors(h * 0.1, c)
		assert_true(float(f["sun"]) == 0.0 or float(f["moon"]) == 0.0, "hour %.1f" % (h * 0.1))


func test_the_sun_rises_east_and_stands_south() -> void:
	var c: Dictionary = _cfg()
	assert_gt(DayCycle.sun_dir(7.0, c).x, 0.8, "morning: in the east (+X)")
	assert_lt(DayCycle.sun_dir(12.0, c).z, -0.8, "noon: in the south (-Z)")
	assert_lt(DayCycle.sun_dir(17.0, c).x, -0.8, "evening: in the west")
	assert_almost_eq(rad_to_deg(asin(DayCycle.sun_dir(12.0, c).y)), float(c["noon_elevation"]), 0.01)
	assert_gt(DayCycle.sun_dir(6.0, c).y, 0.05, "never along the ground")


func test_the_hour_follows_slowly_and_snaps_on_a_jump() -> void:
	assert_almost_eq(DayCycle.step_hour(3.0, 4.0, 0.1), 3.1, 0.0001)
	assert_almost_eq(DayCycle.step_hour(3.95, 4.0, 0.1), 4.0, 0.0001, "never past the round's hour")
	assert_almost_eq(DayCycle.step_hour(23.95, 0.0, 0.1), 0.0, 0.0001, "over midnight")
	assert_almost_eq(DayCycle.step_hour(3.0, 12.0, 0.1), 12.0, 0.0001, "a join in progress lands on the hour")
	assert_almost_eq(DayCycle.step_hour(12.0, 0.0, 0.1), 0.0, 0.0001, "a restart goes back at once")


func test_the_air_under_a_roof_and_below_ground() -> void:
	var c: Dictionary = _cfg()
	assert_eq(DayCycle.air_share(0.0, 0.0, c), 1.0)
	assert_almost_eq(DayCycle.air_share(1.0, 0.0, c), float(c["indoor_share"]), 0.0001)
	assert_eq(DayCycle.air_share(0.0, 1.0, c), 0.0, "the cellar and the mine keep their dark")


func _rig() -> Array:
	var m: Node3D = Node3D.new()
	m.set_script(load("res://gravelight/tests/unit/day_cycle_map_stub.gd"))
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	we.environment.ambient_light_energy = 0.3
	we.environment.ambient_light_color = Color(0.22, 0.27, 0.4)
	we.environment.tonemap_exposure = 1.3
	we.environment.fog_light_color = Color(0.07, 0.09, 0.15)
	m.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_energy = 0.42
	moon.light_color = Color(0.5, 0.6, 0.95)
	moon.rotation_degrees = Vector3(-40, 28, 0)
	m.add_child(moon)
	add_child_autofree(m)
	var d: DayCycle = DayCycle.attach(m)
	return [m, we.environment, moon, d]


func test_night_leaves_the_map_as_authored_and_noon_is_day() -> void:
	var rig: Array = _rig()
	var env: Environment = rig[1]
	var moon: DirectionalLight3D = rig[2]
	var d: DayCycle = rig[3]
	assert_not_null(d, "attached")
	var basis0: Basis = moon.global_basis
	d.hold_hour(0.0)
	d._process(0.016)
	assert_almost_eq(env.ambient_light_energy, 0.3, 0.0001)
	assert_almost_eq(env.tonemap_exposure, 1.3, 0.0001)
	assert_true(env.fog_light_color.is_equal_approx(Color(0.07, 0.09, 0.15)))
	assert_almost_eq(moon.light_energy, 0.42, 0.0001)
	assert_true(moon.light_color.is_equal_approx(Color(0.5, 0.6, 0.95)))
	assert_true(moon.global_basis.is_equal_approx(basis0), "the moon stands where it was authored")
	d.hold_hour(12.0)
	d._process(0.016)
	assert_almost_eq(env.ambient_light_energy, float(d.cfg["ambient_energy_day"]), 0.001)
	assert_almost_eq(env.tonemap_exposure, float(d.cfg["exposure_day"]), 0.001)
	assert_gt(env.fog_light_color.g, 0.3)
	assert_almost_eq(moon.light_energy, float(d.cfg["sun_energy"]), 0.001)
	assert_lt(moon.global_basis.z.z, -0.7, "the key light comes from the south at noon")
	d.hold_hour(0.0)
	d._process(0.016)
	assert_almost_eq(env.ambient_light_energy, 0.3, 0.0001, "and the night comes back exactly")
	assert_true(moon.global_basis.is_equal_approx(basis0))


func test_the_day_is_blended_over_what_other_scripts_write() -> void:
	var rig: Array = _rig()
	var env: Environment = rig[1]
	var moon: DirectionalLight3D = rig[2]
	var d: DayCycle = rig[3]
	d.hold_hour(12.0)
	d._process(0.016)
	var mult: float = float(d.cfg["ambient_energy_day"]) / 0.3
	env.ambient_light_energy = 0.15   # a zone's own (night) value arrives
	d._process(0.016)
	assert_almost_eq(env.ambient_light_energy, 0.15 * mult, 0.001, "the new value is taken as the night's")
	assert_almost_eq(float(d.night_value("ambient_light_energy")), 0.15, 0.0001)
	d._process(0.016)
	assert_almost_eq(env.ambient_light_energy, 0.15 * mult, 0.001, "and its own write is not taken for one")
	moon.light_energy = 0.0   # ViewCells: this room has no moon
	d._process(0.016)
	assert_eq(moon.light_energy, 0.0, "a room that switches the key light off keeps it off by day")
	moon.light_energy = 0.42  # ViewCells: back outside
	d._process(0.016)
	assert_almost_eq(moon.light_energy, float(d.cfg["sun_energy"]), 0.001)


func test_off_maps_get_none() -> void:
	var m: Node3D = Node3D.new()
	m.set_script(load("res://gravelight/tests/unit/day_cycle_map_stub.gd"))
	m.set("map_id", &"map04b_kranich")
	add_child_autofree(m)
	assert_null(DayCycle.attach(m), "the flight keeps its own clock")
