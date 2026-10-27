extends GutTest
## Map 1 "Kaltenbrunn" edges and reach (UPDATE 07 QA, T-107). The Phase 0 soak found a bot "lost" for 16 minutes
## against the side of the Administration stairs: the navmesh ran over the ramp's low east edge, so paths entered
## the stairs from the side where the body could not. These tests read the generated scene (never the live tree):
## the stairs carry closed strings on both sides, no navmesh vertex sits on the ramp's side band, and the authored
## Kaltenbrunn training routes name the doors a self-led squad must open to reach them.

const SCENE: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const RAMP_X0: float = -15.2
const RAMP_X1: float = -12.2
const RAMP_Z_LOW: float = 28.0   # y 0 here
const RAMP_Z_HIGH: float = 21.0  # y 3.8 here

var _nodes: Array = []


func before_all() -> void:
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		_nodes.append({"name": String(st.get_node_name(i)), "path": String(st.get_node_path(i)), "type": st.get_node_type(i), "props": props})


func _body_box(n: Dictionary) -> Dictionary:
	var pos: Vector3 = (n["props"] as Dictionary).get("position", Vector3.ZERO)
	var xf: Variant = (n["props"] as Dictionary).get("transform", null)
	if xf is Transform3D:
		pos = (xf as Transform3D).origin
	for c: Dictionary in _nodes:
		if str(c["path"]).begins_with(str(n["path"]) + "/") and c["type"] == "CollisionShape3D":
			var shape: Variant = (c["props"] as Dictionary).get("shape", null)
			if shape is BoxShape3D:
				var half: Vector3 = (shape as BoxShape3D).size * 0.5
				return {"lo": pos - half, "hi": pos + half}
	return {}


func _find(name: String) -> Dictionary:
	for n: Dictionary in _nodes:
		if str(n["name"]).trim_prefix("@") == name:
			return n
	return {}


func test_admin_stairs_have_closed_strings_on_both_sides() -> void:
	for side: Array in [["AdminStairStringE", RAMP_X1], ["AdminStairStringW", RAMP_X0]]:
		var n: Dictionary = _find(side[0])
		assert_false(n.is_empty(), "%s exists" % side[0])
		if n.is_empty():
			continue
		var bx: Dictionary = _body_box(n)
		assert_false(bx.is_empty(), "%s is a box collider" % side[0])
		if bx.is_empty():
			continue
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		assert_lt(absf((lo.x + hi.x) * 0.5 - float(side[1])), 0.3, "%s stands on the ramp's edge x=%.1f" % [side[0], float(side[1])])
		assert_lt(lo.z, RAMP_Z_HIGH + 0.1, "%s reaches the stair head" % side[0])
		assert_gt(hi.z, RAMP_Z_LOW - 0.1, "%s reaches the stair foot" % side[0])
		assert_lt(lo.y, 0.05, "%s starts at the floor" % side[0])
		assert_gt(hi.y, 3.0, "%s rises with the stairs" % side[0])


## The ramp's surface height at z (y 0 at the foot, 3.8 at the head).
static func _ramp_y(z: float) -> float:
	return 3.8 * clampf((RAMP_Z_LOW - z) / (RAMP_Z_LOW - RAMP_Z_HIGH), 0.0, 1.0)


func test_no_navmesh_on_the_ramp_sides() -> void:
	var seen: int = 0
	var bad: PackedStringArray = []
	for n: Dictionary in _nodes:
		if n["type"] != "NavigationRegion3D":
			continue
		var nm: Variant = (n["props"] as Dictionary).get("navigation_mesh", null)
		if not (nm is NavigationMesh):
			continue
		for v: Vector3 in (nm as NavigationMesh).get_vertices():
			if v.z < RAMP_Z_HIGH + 0.5 or v.z > RAMP_Z_LOW - 0.5:
				continue   # the foot and the head are where paths may enter
			var on_east: bool = v.x > RAMP_X1 - 0.6 and v.x < RAMP_X1 + 0.6
			var on_west: bool = v.x > RAMP_X0 - 0.6 and v.x < RAMP_X0 + 0.6
			if not (on_east or on_west):
				continue
			seen += 1
			# a vertex beside the ramp at ramp height is the side-entry seam the strings remove: the floor beside the
			# stairs (y ~0.5) and the ramp's own surface (inside x0..x1) are fine
			var ry: float = _ramp_y(v.z)
			var inside: bool = v.x > RAMP_X0 + 0.05 and v.x < RAMP_X1 - 0.05
			if not inside and v.y > 0.9 and v.y < ry + 0.3:
				bad.append(str(v))
	assert_gt(seen, 0, "the Admin block's navmesh is in the scene")
	assert_eq(bad.size(), 0, "no navmesh vertex climbs the ramp's side: %s" % str(bad))


func test_map01_routes_name_the_doors_they_need() -> void:
	var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/ai/routes_map01.json"))
	var ids: Dictionary = {}
	for n: Dictionary in _nodes:
		var did: Variant = (n["props"] as Dictionary).get("door_id", null)
		if did != null:
			ids[String(did)] = true
	var found: Dictionary = {}
	for route: Dictionary in r["routes"]:
		found[str(route["id"])] = route
		for d: Variant in route.get("requires_doors", []):
			assert_true(ids.has(String(d)), "%s requires a real door: %s" % [route["id"], String(d)])
	# a self-led squad opens only the power's door and route doors (economy.json self_led_useful_doors_only), so
	# the loops past the yard must say which doors lead to them (T-107: with none, bots alone bought nothing)
	assert_true((found["map01_pews"].get("requires_doors", []) as Array).has("door_stairs"), "the Pew Loop needs the stairs")
	assert_true((found["map01_turbines"].get("requires_doors", []) as Array).has("door_gen"), "the turbine loop needs the Generator Hall")


## T-123: the spawn yard's south side is dressed with solid props (YardProp* colliders) along the south wall. They
## stay out of the way: nothing within 2.5 m of a player spawn or the yard's ground spawn, nothing inside the
## headframe loop's ring, nothing in front of the yard's doors; and the yard has its own ammo box.
func test_yard_props_keep_clear_of_spawns_doors_and_the_loop() -> void:
	var keep_clear: Array = [   # [point, radius]
		[Vector3(9, 0, 25), 2.5], [Vector3(11, 0, 25), 2.5], [Vector3(9, 0, 27), 2.5], [Vector3(11, 0, 27), 2.5],
		[Vector3(3, 0, 29), 2.5],   # the ground spawn
		[Vector3(0, 0, 25), 3.0], [Vector3(40, 0, 25), 3.0],   # the doors to the Admin Block and the Rail Yard
		[Vector3(20, 0, 21.5), 8.0],   # Pylon A's ring
	]
	var props: int = 0
	for n: Dictionary in _nodes:
		if not str(n["name"]).begins_with("YardProp"):
			continue
		props += 1
		var bx: Dictionary = _body_box(n)
		assert_false(bx.is_empty(), "%s is a box collider" % n["name"])
		if bx.is_empty():
			continue
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		assert_gt(lo.z, 29.5, "%s stands along the south wall, outside the headframe loop (z <= 25.5)" % n["name"])
		for kc: Array in keep_clear:
			var p: Vector3 = kc[0]
			var q: Vector2 = Vector2(clampf(p.x, lo.x, hi.x), clampf(p.z, lo.z, hi.z))
			assert_gt(q.distance_to(Vector2(p.x, p.z)), float(kc[1]), "%s keeps %.1f m from %s" % [n["name"], float(kc[1]), str(p)])
	assert_gt(props, 5, "the yard's props are in the scene")
	var ammo: Dictionary = _find("AmmoBox_Yard")
	assert_false(ammo.is_empty(), "the spawn yard has an ammo box")


## T-123: the yard's props are baked into the navmesh: no navmesh polygon on the floor under the timber stack.
func test_yard_navmesh_goes_round_the_props() -> void:
	for n: Dictionary in _nodes:
		if n["type"] != "NavigationRegion3D":
			continue
		var nm: Variant = (n["props"] as Dictionary).get("navigation_mesh", null)
		if not (nm is NavigationMesh):
			continue
		var verts: PackedVector3Array = (nm as NavigationMesh).get_vertices()
		for i: int in (nm as NavigationMesh).get_polygon_count():
			var poly: PackedInt32Array = (nm as NavigationMesh).get_polygon(i)
			if absf(verts[poly[0]].y) > 0.6:
				continue
			var flat: PackedVector2Array = PackedVector2Array()
			for vi: int in poly:
				flat.append(Vector2(verts[vi].x, verts[vi].z))
			assert_false(Geometry2D.is_point_in_polygon(Vector2(24.5, 31.2), flat), "no floor navmesh under the pit-prop stack")
