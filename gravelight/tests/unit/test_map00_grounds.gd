extends GutTest
## Map 0's Grounds (T-080): the two bought ways out, the zone, the spawns, the open-ground rules' pure parts and the
## data the bots use out there.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"


func test_generated_map_has_the_grounds() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var df: Node = map.find_child("Door_Front", true, false)
	assert_not_null(df, "Out Front")
	if df != null:
		assert_true(df is GateDoor)
		assert_eq(int(df.get("cost")), 1250)
		assert_eq(StringName(df.get("opens_zone")), &"GROUNDS")
		assert_eq(NodePath(df.get("swing_node")), NodePath("../InnFrontDoor"))
	var dg: Node = map.find_child("Door_Gate", true, false)
	assert_not_null(dg, "the gate")
	if dg != null:
		assert_eq(int(dg.get("cost")), 750)
		assert_eq(StringName(dg.get("opens_zone")), &"GROUNDS")
		assert_true(Array(dg.get("also_opens")).has("YARD"))
	var dy: Node = map.find_child("Door_Yard", true, false)
	assert_true(dy != null and Array(dy.get("also_opens")).has("STABLE"), "the yard door bought from the yard opens the stable")
	assert_null(map.find_child("FrontDoorBlock", true, false), "the front doorway is a bought door now, not a baked block")
	assert_null(map.find_child("YardGate", true, false))
	var roam: int = 0
	for n: Node in map.find_children("Zone_GROUNDS*", "", true, false):
		assert_eq(StringName(n.get("zone_id")), &"GROUNDS")
		if bool(n.get("roam")):
			roam += 1
	assert_gt(roam, 10, "the grounds are tiled with open-ground zone volumes")
	var edge: int = 0
	var snow: int = 0
	for n2: Node in map.find_children("Spawn_*", "", true, false):
		if StringName(n2.get("zone_id")) != &"GROUNDS":
			continue
		assert_true(bool(n2.get("player_zone_only")), String(n2.name))
		assert_gt(float(n2.get("hide_from_m")), 0.0, String(n2.name))
		if StringName(n2.get("kind")) == &"edge":
			edge += 1
		elif StringName(n2.get("kind")) == &"ground":
			snow += 1
	assert_eq(edge, 13)
	assert_eq(snow, 4)
	var w: Node = map.find_child("Spawn_W_TAP_N1", true, false)
	assert_true(w != null and float(w.get("hide_from_m")) > 10.0, "the field window spawns hide from players out there")
	var up: Node = map.find_child("Spawn_W_UP_R1", true, false)
	assert_true(up != null and float(up.get("hide_from_m")) == 0.0, "the ledges' don't")
	map.free()


func test_seen_from_needs_distance() -> void:
	var roamers: Array[Vector3] = [Vector3(0, 0, 0)]
	assert_true(ZombieDirector._seen_from(Vector3(5, 0, 0), 10.0, roamers, null))
	assert_false(ZombieDirector._seen_from(Vector3(12, 0, 0), 10.0, roamers, null))
	assert_false(ZombieDirector._seen_from(Vector3(5, 6, 0), 10.0, roamers, null), "a floor apart")
	assert_false(ZombieDirector._seen_from(Vector3(5, 0, 0), 10.0, [] as Array[Vector3], null))


func test_zone_volume_roam() -> void:
	var a: ZoneVolume = ZoneVolume.new()
	a.zone_id = &"GROUNDS"
	a.size = Vector3(10, 3, 10)
	a.roam = true
	add_child_autofree(a)
	var b: ZoneVolume = ZoneVolume.new()
	b.zone_id = &"TAPROOM"
	b.size = Vector3(4, 3, 4)
	b.position = Vector3(20, 0, 0)
	add_child_autofree(b)
	assert_true(ZoneVolume.roam_at(get_tree(), Vector3(1, 0, 1)))
	assert_false(ZoneVolume.roam_at(get_tree(), Vector3(20, 0, 0)))
	assert_false(ZoneVolume.roam_at(get_tree(), Vector3(50, 0, 0)))


func test_roam_config() -> void:
	var rc: Dictionary = Zombie.roam_cfg()
	assert_gt(float(rc.get("aggro_m", 0.0)), 5.0)
	assert_gt(float(rc.get("recheck_s", 0.0)), 0.0)


func test_bots_have_the_grounds() -> void:
	var ids: Dictionary = {}
	for r: TrainingRoute in TrainingRoute.all_for_map("map00"):
		ids[r.id] = r
	assert_true(ids.has("map00_wreck_loop") and ids.has("map00_grounds_ring"))
	if ids.has("map00_wreck_loop"):
		var wl: TrainingRoute = ids["map00_wreck_loop"]
		assert_true(wl.requires_zones.has("GROUNDS"))
		assert_true(wl.agent_only)
		assert_false(wl.zones_ok([&"TAPROOM"]))
		assert_true(wl.zones_ok([&"TAPROOM", &"GROUNDS"]))
	if ids.has("map00_grounds_ring"):
		assert_gt((ids["map00_grounds_ring"] as TrainingRoute).length(), 180.0, "right round the building")
	var plan: Dictionary = GLData.load_json("res://data/gravelight/ai/player_bot.json")["plans"]["map00"]
	var doors: Array = []
	for st: Dictionary in plan["steps"]:
		if st.has("door"):
			doors.append(str(st["door"]))
	assert_true((plan["train_at"] as Array).has("map00_wreck_loop"), "the agent trains round the wreck when it is out there")
