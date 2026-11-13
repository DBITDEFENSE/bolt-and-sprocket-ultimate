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


## T-084: the edge wall and the boundary fences are on the edge layer (bodies collide, shots pass), every edge spawn
## stands 3..6 m beyond the edge, its pocket's gate is a non-baked collider on the same layer, and the barn grew.
func test_edge_layer_pockets_and_the_barn() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	assert_true((Player.MASK_MOVE & (1 << 10)) != 0, "bodies collide with the edge")
	assert_eq(WeaponHolder.MASK_SHOT & (1 << 10), 0, "shots don't")
	assert_eq(Projectile.MASK & (1 << 10), 0, "projectiles don't")
	var gates: Node = map.find_child("EdgeGates", true, false)
	assert_not_null(gates)
	var n_gates: int = 0
	if gates != null:
		assert_true(gates.get_parent() == map, "the gates hang off the map root, outside the navigation region")
		for g: Node in gates.get_children():
			n_gates += 1
			assert_eq(int((g as CollisionObject3D).collision_layer), 1 << 10, String(g.name))
	var edges: int = 0
	for b: Node in (map.find_child("Navigation", true, false) as Node).find_children("*", "StaticBody3D", true, false):
		var nm: String = String(b.name)
		if nm.begins_with("GroundsEdge"):
			edges += 1
			assert_eq(int((b as CollisionObject3D).collision_layer), 1 << 10, nm)
	assert_gt(edges, 0)
	var lo: Vector2 = Vector2(-20, -30)
	var hi: Vector2 = Vector2(60, 64)
	var n_edge: int = 0
	for sp: Node in map.find_children("Spawn_Edge*", "", true, false):
		n_edge += 1
		var p: Vector3 = (sp as Node3D).position
		var beyond: float = maxf(maxf(lo.x - p.x, p.x - hi.x), maxf(lo.y - p.z, p.z - hi.y))
		assert_true(beyond >= 3.0 and beyond <= 6.0, "%s stands %.1f m beyond the edge" % [sp.name, beyond])
	assert_eq(n_edge, 13)
	assert_eq(n_gates, 13, "one gate per pocket")
	assert_eq(Rect2(map.get("drop_bounds")), Rect2(-20, -30, 80, 94))
	# the barn: Door 4 and the great doors stay where they were, the west wall's fittings moved with it
	assert_almost_eq((map.find_child("Door_Yard", true, false) as Node3D).position, Vector3(8, 0, 34), Vector3(0.01, 0.01, 0.01))
	assert_almost_eq((map.find_child("WallBuy_trench_gun", true, false) as Node3D).position.x, 4.66, 0.02)
	assert_almost_eq((map.find_child("AmmoBox_Stable", true, false) as Node3D).position.x, 4.98, 0.02)
	assert_lt((map.find_child("ArmorersBench", true, false) as Node3D).position.x, 5.0)
	var loft: Node = map.find_child("W_STB_LOFT", true, false)
	assert_true(loft != null and StringName(loft.get("zone_id")) == &"STABLE", "the loft door is a stable window")
	var lsp: Node = map.find_child("Spawn_W_STB_LOFT", true, false)
	assert_true(lsp != null and (lsp as Node3D).position.y > 3.0 and float(lsp.get("hide_from_m")) == 0.0, "its zombies stand on the hoist ledge")
	assert_null(map.find_child("LoftRailBake*", true, false), "the rail panels only lived for the bake")
	assert_null(map.find_child("EdgeCarve*", true, false))
	map.free()


## T-084: the baked navmesh climbs the new stair to the loft and the gallery, reaches each spawn pocket through its
## gap and nothing else beyond the edge, and the hoist ledge is an island.
func test_navmesh_loft_stair_and_pockets() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var region: NavigationRegion3D = map.find_child("Navigation", false, false) as NavigationRegion3D
	assert_not_null(region)
	if region == null:
		map.free()
		return
	# the region alone goes into the tree (not the MapRoot, which would start a match); the server syncs it on the
	# next physics frames and the world's map answers
	map.remove_child(region)
	region.owner = null
	add_child_autofree(region)
	var map_rid: RID = region.get_world_3d().navigation_map
	var floor_pt: Vector3 = Vector3(18, 0, 28)
	# the region's iteration builds over a few frames (the map answers the origin until it has polygons)
	var synced: bool = false
	for i: int in 40:
		await wait_physics_frames(3)
		if NavigationServer3D.map_get_closest_point(map_rid, floor_pt).distance_to(floor_pt) < 1.0:
			synced = true
			break
	assert_true(synced, "the navigation map synced with the stable's floor on it")
	for c: Array in [["stable floor -> the loft's west block", floor_pt, Vector3(9, 3.5, 27), true],
			["stable floor -> the gallery over the great doors", floor_pt, Vector3(20, 3.5, 31.5), true],
			["the loft -> the hoist ledge (an island)", Vector3(20, 3.5, 31.5), Vector3(23.6, 3.5, 35.6), false],
			["the field -> a north spawn pocket", Vector3(20, 0, -8), Vector3(5, 0, -34.5), true],
			["the field -> an east spawn pocket", Vector3(20, 0, -8), Vector3(64.5, 0, 22), true],
			["the field -> beyond the pocket's end", Vector3(20, 0, -8), Vector3(5, 0, -40), false],
			["the field -> between two pockets", Vector3(20, 0, -8), Vector3(15, 0, -34.5), false]]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, c[1], c[2], true)
		var reached: bool = not path.is_empty() and path[path.size() - 1].distance_to(c[2]) < 1.2
		assert_eq(reached, bool(c[3]), str(c[0]))
	# the stair's own slope: every path point between the foot and the head lies on the flight (x 23.35..25.35)
	var up: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, floor_pt, Vector3(20, 3.5, 31.5), true)
	# (T-238: sampled along the path's segments. The bake can lay one polygon from the foot to the head, and then the
	# optimised path has no corner of its own on the flight: the corners alone said "never climbs". A straight segment
	# from the last floor corner to the first one up the flight rises before the first riser, so z starts a metre
	# short of the foot; x is the test: the climb stays inside the flight's two sides.)
	var on_flight: int = 0
	for k: int in maxi(0, up.size() - 1):
		var steps: int = maxi(1, int(up[k].distance_to(up[k + 1]) / 0.25))
		for j: int in steps + 1:
			var p: Vector3 = up[k].lerp(up[k + 1], float(j) / float(steps))
			if p.y > 0.3 and p.y < 3.3:
				on_flight += 1
				assert_true(p.x > 23.2 and p.x < 25.5 and p.z > 24.4 and p.z < 31.7, "climbing at %s" % str(p))
	assert_gt(on_flight, 0, "the path climbs the east-wall flight")
	map.free()


func test_drop_bounds_clamp() -> void:
	var mr: MapRoot = MapRoot.new()
	assert_eq(mr.clamp_inside(Vector3(-25, 0, 10)), Vector3(-25, 0, 10), "no bounds: unchanged")
	mr.drop_bounds = Rect2(-20, -30, 80, 94)
	assert_eq(mr.clamp_inside(Vector3(-25, 0, 10)), Vector3(-18.5, 0, 10))
	assert_eq(mr.clamp_inside(Vector3(30, 0.5, 70)), Vector3(30, 0.5, 62.5))
	assert_eq(mr.clamp_inside(Vector3(30, 0, 10)), Vector3(30, 0, 10))
	mr.free()


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
