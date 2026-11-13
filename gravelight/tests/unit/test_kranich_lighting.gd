extends GutTest
## T-221 (the owner: the sunset, the bombs dropping, too many dark areas, the hallways): KranichSunset's golden hour
## (the act's clock, the run's hold), the falling casing's path, KranichInterior's lamps (energies before / after the
## aux bus, none shadowed, every lamp inside its zone, clear of the buyables), the trailer console commands, the bomb
## rack's visual hook, and that the run's gameplay data is untouched.

const PLANE: String = "res://data/gravelight/map04b_plane.json"

var golden: Dictionary
var interior: Dictionary


func before_all() -> void:
	var d: Dictionary = GLData.load_json(PLANE)
	golden = d.get("golden", {})
	interior = d.get("interior", {})


func test_golden_hour_follows_the_act_and_holds_for_the_run() -> void:
	assert_eq(KranichSunset.golden_for(0.0, 0.0, golden), 0.0, "night: no golden hour")
	assert_eq(KranichSunset.golden_for(0.3, 0.0, golden), 0.0, "early dawn: still the night look")
	assert_gt(KranichSunset.golden_for(0.58, 0.0, golden), 0.2, "it comes up gradually")
	assert_lt(KranichSunset.golden_for(0.58, 0.0, golden), 0.8)
	# the run starts at act round 5: MapAmbience's flight_sun gives 0.85 * (4 / 5) = 0.68 at its start
	assert_gt(KranichSunset.golden_for(0.68, 0.0, golden), 0.9, "the bomb run is in the golden hour by the act's own clock")
	assert_eq(KranichSunset.golden_for(0.2, 1.0, golden), 1.0, "and held there while the run is on")


func test_a_casing_falls_away_aft_and_down() -> void:
	var from: Vector3 = Vector3(-5.6, -1.4, 6.0)
	var a: Vector4 = KranichSunset.fall_at(from, 0.0)
	assert_almost_eq(a.y, from.y, 0.001)
	var b: Vector4 = KranichSunset.fall_at(from, 3.0)
	assert_lt(b.y, -40.0, "it drops into the cloud deck in a few seconds")
	assert_lt(b.z, from.z - 20.0, "and drifts aft in the slipstream")
	assert_gt(b.w, 0.5, "nose down")


func test_interior_lamps() -> void:
	var kinds: Dictionary = interior["kinds"]
	assert_lt(KranichInterior.lamp_energy(kinds["bulkhead"], 0.0), 0.1, "the ship's lamps are out before the aux bus")
	assert_gt(KranichInterior.lamp_energy(kinds["bulkhead"], 1.0), 1.0, "and bright after")
	assert_gt(KranichInterior.lamp_energy(kinds["emergency"], 0.0), 0.3, "the battery lamps are on from the start")
	# every lamp inside its zone's boxes (gen_map04b.gd's zone plan, generous by 0.6 m)
	var boxes: Dictionary = {
		"A_BOMBENSCHACHT": [[-9, 0, 9, 24]], "B_MITTELRUMPF": [[-9, 24, 9, 54]], "C_FLUEGEL_L": [[-52, 28, -9, 46]],
		"C_FLUEGEL_R": [[9, 28, 52, 46]], "D_TRIEBWERK": [[-78, 24, -52, 58], [-52, 50, -22, 58]],
		"E_KANZEL": [[52, 24, 78, 58], [22, 50, 52, 58]], "F_COCKPIT": [[-22, 54, 22, 74]]}
	var buys: Array = [Vector3(-8.83, 1.5, 6.0), Vector3(8.83, 1.5, 30.0), Vector3(-30.0, 1.5, 45.83), Vector3(30.0, 1.5, 45.83), Vector3(66.0, 1.5, 57.83)]
	for l: Variant in interior["lamps"]:
		var a: Array = l
		assert_true(kinds.has(str(a[3])), "lamp kind %s exists" % a[3])
		var inside: bool = false
		for r: Array in boxes.get(str(a[4]), []):
			if float(a[0]) >= float(r[0]) - 0.6 and float(a[0]) <= float(r[2]) + 0.6 and float(a[2]) >= float(r[1]) - 0.6 and float(a[2]) <= float(r[3]) + 0.6:
				inside = true
		assert_true(inside, "lamp at (%s, %s) inside %s" % [a[0], a[2], a[4]])
		for b: Vector3 in buys:
			assert_gt(Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(b), 1.5, "lamp at (%s, %s) clear of a wall-buy" % [a[0], a[2]])


func test_interior_builds_without_shadows_or_colliders() -> void:
	var ki: KranichInterior = KranichInterior.new()
	add_child_autofree(ki)
	assert_gt(ki.lamps.size(), 30, "the lamps went up")
	for n: Node in ki.find_children("*", "Light3D", true, false):
		assert_false((n as Light3D).shadow_enabled, "%s casts no shadow (the zones' budget is untouched)" % n.name)
	assert_eq(ki.find_children("*", "CollisionObject3D", true, false).size(), 0, "nothing collides")


func test_sunset_builds_one_shadowed_shaft() -> void:
	var ks: KranichSunset = KranichSunset.new()
	add_child_autofree(ks)
	var shadowed: int = 0
	for n: Node in ks.find_children("*", "Light3D", true, false):
		if (n as Light3D).shadow_enabled:
			shadowed += 1
	assert_eq(shadowed, 1, "one shadowed light: the ramp's sun shaft (zone A's budget is 6)")
	ks.drop_fx(1)   # no racks in the test tree: nothing happens, nothing breaks
	assert_eq(ks.drops_seen, 0)


func test_trailer_commands_outside_the_kranich() -> void:
	assert_string_contains(TrailerCommands.tod(get_tree(), PackedStringArray(["golden"])), "only on der Kranich")
	assert_string_contains(TrailerCommands.bombrun(get_tree(), PackedStringArray(["now"])), "only on der Kranich")
	assert_string_contains(TrailerCommands.hud(get_tree(), PackedStringArray(["on"])), "HUD on")


func test_the_run_stays_the_run() -> void:
	var rack: String = FileAccess.get_file_as_string("res://gravelight/world/map04/bomb_rack.gd")
	assert_true(rack.contains("call_group(&\"bomb_drop_fx\", \"on_rack_dropped\", self)"), "the rack tells the fx (visual)")
	assert_true(rack.contains("state = R.DUD if marked else R.DROPPED"), "and decides its state as before")
	var br: Dictionary = (GLData.load_json("res://data/gravelight/map04b.json") as Dictionary)["flight"]["bomb_run"]
	assert_eq(float(br.get("rack_interval", 0.0)), 35.0, "the run's interval is the design's")
	var sky: String = FileAccess.get_file_as_string("res://gravelight/world/map04/flight_sky_bg.gdshader")
	assert_true(sky.contains("uniform float golden"), "the sky has the golden hour")
