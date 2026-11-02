extends GutTest
## Mondlicht's art pass (UPDATE 09 §5.5, T-149): the presentation pieces' pure rules (the airlock's cycle phases, the
## hall's hum, the conveyor's wrap, the first retained's hand, the light zoning), and the generated scene's contract
## C4 rules: every light carries `zone` meta, at most 6 shadowed lights per zone, the three airlock cycles on their
## doors, the Earth's look data; the zone ambience table covers the six zones, the yard is vacuum (the suit only) and
## every key it names is in the sound bank.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04d.tscn"
const DETAIL: GDScript = preload("res://gravelight/tools_src/detail_map04d.gd")
const ZONES: Array = ["A_RECEPTION", "B_CONCOURSE", "C_YARD", "D_FULFILLMENT", "E_HALL", "F_CORE"]

var _root: Node = null


func before_all() -> void:
	_root = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)


func after_all() -> void:
	if _root != null:
		_root.free()


func test_airlock_cycle_phases() -> void:
	assert_eq(AirlockCycle.phase_at(0.1, 3.6), &"warn", "red and the beacon first")
	assert_eq(AirlockCycle.phase_at(1.5, 3.6), &"vent", "then the hiss and the vapour")
	assert_eq(AirlockCycle.phase_at(3.3, 3.6), &"seal", "the clunk")
	assert_eq(AirlockCycle.phase_at(3.7, 3.6), &"done", "green")


func test_hum_pulse_breathes_within_its_range() -> void:
	var lo: float = INF
	var hi: float = -INF
	for i: int in 60:
		var e: float = HumPulse.energy_at(float(i) * 0.05, 1.6, 0.35, 2.6, 0.0)
		lo = minf(lo, e)
		hi = maxf(hi, e)
	assert_almost_eq(lo, 1.6 * 0.65, 0.05, "the trough")
	assert_almost_eq(hi, 1.6 * 1.35, 0.05, "the swell")


func test_conveyor_wraps() -> void:
	assert_almost_eq(ConveyorRun.advance(10.9, 0.5, 0.55, 22.0), -10.825, 0.001, "a parcel off the east end comes back at the west")
	assert_almost_eq(ConveyorRun.advance(0.0, 1.0, 0.55, 22.0), 0.55, 0.001)


func test_the_hand_moves_and_rests() -> void:
	assert_almost_eq(RetainedHand.curl_at(0.0, 5.5, 24.0), 0.0, 0.001)
	assert_true(RetainedHand.curl_at(5.5 * 0.35, 5.5, 24.0) > 23.0, "closed at the top of the gesture")
	assert_almost_eq(RetainedHand.curl_at(5.5 * 0.9, 5.5, 24.0), 0.0, 0.001, "still for a beat")


func test_zone_at() -> void:
	var boxes: Array = [["A", Vector3(-1, 0, -1), Vector3(1, 3, 1)], ["B", Vector3(5, 0, 5), Vector3(7, 3, 7)]]
	assert_eq(DETAIL.zone_at(Vector3(0, 9, 0), boxes), "A", "inside a box at any height")
	assert_eq(DETAIL.zone_at(Vector3(4, 0, 4), boxes), "B", "outside every box: the nearest")


func test_every_light_has_a_zone_and_the_shadow_cap_holds() -> void:
	var shadowed: Dictionary = {}
	var count: int = 0
	for n: Node in _root.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		count += 1
		assert_true(l.has_meta("zone"), "%s has zone meta" % _root.get_path_to(l))
		if l.shadow_enabled:
			var z: String = str(l.get_meta("zone", ""))
			shadowed[z] = int(shadowed.get(z, 0)) + 1
	assert_true(count > 20, "the scene is lit (%d lights)" % count)
	for z2: String in shadowed.keys():
		assert_true(int(shadowed[z2]) <= 6, "%s has %d shadowed lights (C4: at most 6)" % [z2, shadowed[z2]])
	for z3: String in ["A_RECEPTION", "B_CONCOURSE", "D_FULFILLMENT", "E_HALL", "F_CORE"]:
		assert_true(int(shadowed.get(z3, 0)) >= 1, "%s has a key light that casts" % z3)


func test_airlock_cycles_on_their_doors() -> void:
	var g: Node = _root.get_node("Gameplay")
	for a: Array in [["AirlockCycle_Reception", &"B_CONCOURSE", "Door_Concourse"], ["AirlockCycle_Yard", &"C_YARD", "Door_Yard"], ["AirlockCycle_Store", &"D_FULFILLMENT", "Door_FulfillmentY"]]:
		var n: Node3D = g.get_node_or_null(str(a[0])) as Node3D
		assert_not_null(n, str(a[0]))
		if n == null:
			continue
		assert_eq(n.get("zone_id"), a[1])
		var d: Node3D = g.get_node_or_null(str(a[2])) as Node3D
		assert_not_null(d, str(a[2]))
		if d != null:
			assert_true(n.position.distance_to(d.position) < 0.01, "%s stands on %s" % [a[0], a[2]])


func test_the_earth_is_in_the_yard_s_eye_line() -> void:
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04d.json").get("earth", {})
	var p: Array = cfg["position"]
	var to_earth: Vector3 = Vector3(float(p[0]), float(p[1]), float(p[2])) - Vector3(0, 1.6, 86)
	var elev: float = rad_to_deg(asin(to_earth.normalized().y))
	assert_true(elev > 25.0 and elev < 55.0, "high over the north rim, not straight up (%.0f°)" % elev)
	assert_eq((cfg["sun_dir"] as Array).size(), 3, "the Sun's direction lights the Earth and the yard")


func test_zone_ambience_table() -> void:
	var amb: Dictionary = GLData.load_json("res://data/gravelight/ambience/map04d.json")
	var sounds: Dictionary = GLData.load_json("res://data/gravelight/audio.json").get("sounds", {})
	var zones: Dictionary = amb.get("zones", {})
	for z: String in ZONES:
		assert_true(zones.has(z), "%s has a bed" % z)
	for z2: String in zones.keys():
		var e: Dictionary = zones[z2]
		var bed: String = str(e.get("bed", ""))
		assert_true(sounds.has(bed) or ResourceLoader.exists(bed), "%s's bed %s exists" % [z2, bed])
		for o: Dictionary in e.get("oneshots", []):
			assert_true(sounds.has(str(o["key"])), "%s's one-shot %s exists" % [z2, o["key"]])
	assert_true(bool((zones["C_YARD"] as Dictionary).get("vacuum", false)), "the yard is vacuum: the suit only")
	for o2: Dictionary in (zones["C_YARD"] as Dictionary).get("oneshots", []):
		assert_true(str(o2["key"]).contains("valve"), "only the suit's own sounds in vacuum")
