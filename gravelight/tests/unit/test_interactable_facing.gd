extends GutTest
## The interactables' facing check (UPDATE 13 Part 3, DECISIONS T-218; gravelight/tools_src/interactable_facing.gd):
## the pure verdict from the four sides' openness, and the scene survey on a tiny built scene (a wall, a navmesh
## floor in front of it, a wall buy turned toward the room and one turned into the wall). The map runs are
## tools/tests/test_interactable_facing.gd.

const Facing: GDScript = preload("res://gravelight/tools_src/interactable_facing.gd")


func _open(f: float, b: float, l: float, r: float) -> Dictionary:
	return {0.0: f, 180.0: b, 90.0: l, -90.0: r}


func test_open_front_is_ok() -> void:
	var c: Dictionary = Facing.classify("faced", _open(1.0, 0.0, 0.6, 0.6), {180.0: true}, true, false, true, {0.0: 0.3})
	assert_eq(c["verdict"], "OK")
	assert_eq(float(c["turn"]), 0.0)


func test_blocked_front_open_back_is_backwards() -> void:
	var c: Dictionary = Facing.classify("faced", _open(0.0, 1.0, 0.4, 0.4), {0.0: true}, false, false, true, {180.0: 0.2})
	assert_eq(c["verdict"], "BACKWARDS")
	assert_eq(float(c["turn"]), 180.0, "the about-turn")


func test_open_side_is_sideways() -> void:
	var c: Dictionary = Facing.classify("faced", _open(0.0, 0.0, 1.0, 0.0), {0.0: true, 180.0: true}, false, false, true, {90.0: 0.1})
	assert_eq(c["verdict"], "SIDEWAYS")
	assert_eq(float(c["turn"]), 90.0)


func test_flank_on_a_wall_turns_its_back_to_it() -> void:
	# open in front and behind (it stands along a wall), the wall is behind the +90 turn: turn +90
	var c: Dictionary = Facing.classify("faced", _open(1.0, 1.0, 0.8, 0.0), {-90.0: true}, true, false, true, {0.0: INF, 180.0: INF, 90.0: 0.2})
	assert_eq(c["verdict"], "SIDEWAYS")
	assert_eq(float(c["turn"]), 90.0)
	# a free-standing object (no wall wanted) stays as it is
	var c2: Dictionary = Facing.classify("faced", _open(1.0, 1.0, 0.8, 0.0), {-90.0: true}, true, false, false, {0.0: INF, 90.0: 0.2})
	assert_eq(c2["verdict"], "OK")


func test_about_turn_wins_a_near_tie() -> void:
	var c: Dictionary = Facing.classify("faced", _open(0.0, 0.8, 1.0, 0.0), {0.0: true}, false, false, true, {180.0: 0.5, 90.0: 0.3})
	assert_eq(float(c["turn"]), 180.0, "the yaw-sign mistake: keep the footprint")
	var c2: Dictionary = Facing.classify("faced", _open(0.0, 0.0, 1.0, 0.0), {0.0: true}, false, false, true, {180.0: 0.5, 90.0: 0.3})
	assert_eq(float(c2["turn"]), 90.0, "no about-turn when the back is shut")


func test_front_on_a_wall_with_a_narrow_aisle_behind() -> void:
	var c: Dictionary = Facing.classify("faced", _open(0.0, 0.2, 0.0, 0.0), {0.0: true}, false)
	assert_eq(c["verdict"], "BACKWARDS")
	assert_eq(float(c["turn"]), 180.0)


func test_free_standing_narrow_front_is_left_alone() -> void:
	# a post in the open (no wall wanted) whose front is only narrower than its back: unsure, never turned
	var c: Dictionary = Facing.classify("faced", _open(0.33, 1.0, 1.0, 1.0), {}, true, false, false, {})
	assert_eq(c["verdict"], "UNSURE")
	assert_eq(float(c["turn"]), 0.0)
	# shut in front: turned
	assert_eq(Facing.classify("faced", _open(0.0, 1.0, 1.0, 1.0), {}, false, false, false, {})["verdict"], "BACKWARDS")


func test_unsure_and_unreachable() -> void:
	assert_eq(Facing.classify("faced", _open(0.3, 0.3, 0.3, 0.3), {}, true)["verdict"], "UNSURE")
	assert_eq(Facing.classify("faced", _open(0.0, 0.0, 0.0, 0.0), {}, false)["verdict"], "UNREACHABLE")
	assert_eq(Facing.classify("faced", _open(1.0, 0.0, 0.0, 0.0), {}, false)["verdict"], "UNREACHABLE", "open but out of reach")


func test_locked_is_reported_never_turned() -> void:
	var c: Dictionary = Facing.classify("faced", _open(0.0, 1.0, 0.0, 0.0), {0.0: true}, false, true, false, {})
	assert_eq(c["verdict"], "BACKWARDS")
	assert_eq(float(c["turn"]), 0.0, "the Crucible stays as placed")


func test_kinds_without_a_front() -> void:
	assert_eq(Facing.classify("omni", _open(0.0, 0.0, 0.0, 0.3), {}, true)["verdict"], "OK")
	assert_eq(Facing.classify("door", _open(1.0, 1.0, 0.0, 0.0), {}, false)["verdict"], "UNREACHABLE")
	assert_eq(Facing.classify("window", _open(0.0, 0.0, 0.0, 0.0), {}, false)["verdict"], "LAYOUT")


func test_failures_skip_locked_and_known() -> void:
	var rows: Array = [{"verdict": "BACKWARDS"}, {"verdict": "UNSURE"}, {"verdict": "OK"}, {"verdict": "UNREACHABLE", "note": "known: under a ramp"},
		{"verdict": "BACKWARDS", "note": "locked (left as placed)"}, {"verdict": "SIDEWAYS"}]
	assert_eq(Facing.failures(rows).size(), 2)


func test_wrap_yaw() -> void:
	assert_eq(Facing.wrap_yaw(270.0), -90.0)
	assert_eq(Facing.wrap_yaw(-180.0), 180.0)
	assert_eq(Facing.wrap_yaw(360.0), 0.0)
	assert_eq(Facing.wrap_yaw(-90.0 + 180.0), 90.0)


func test_segment_box() -> void:
	var half: Vector3 = Vector3(1, 1, 1)
	assert_true(Facing._seg_box(Vector3(-3, 0, 0), Vector3(3, 0, 0), half), "through")
	assert_false(Facing._seg_box(Vector3(-3, 2, 0), Vector3(3, 2, 0), half), "over")
	assert_true(Facing._seg_box(Vector3(0, 0, 0), Vector3(3, 0, 0), half), "starts inside")
	assert_false(Facing._seg_box(Vector3(-3, 0, 0), Vector3(-1.5, 0, 0), half), "stops short")


## A room: navmesh floor x -5..5, z -5..-0.6 at y 0; a wall along z 0..0.3; two wall buys on its room face, one
## turned to the room (yaw 0: front -Z) and one into the wall (yaw 180).
func _room() -> Node3D:
	var root: Node3D = Node3D.new()
	var reg: NavigationRegion3D = NavigationRegion3D.new()
	var nm: NavigationMesh = NavigationMesh.new()
	nm.vertices = PackedVector3Array([Vector3(-5, 0, -5), Vector3(5, 0, -5), Vector3(5, 0, -0.6), Vector3(-5, 0, -0.6)])
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	reg.navigation_mesh = nm
	root.add_child(reg)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "Wall"
	wall.position = Vector3(0, 1.5, 0.15)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(10, 3, 0.3)
	cs.shape = bs
	wall.add_child(cs)
	root.add_child(wall)
	for k: int in 2:
		var wb: Node3D = Node3D.new()
		wb.set_script(load("res://gravelight/world/wall_buy.gd"))
		wb.name = "WallBuy_Room" if k == 0 else "WallBuy_Wall"
		wb.position = Vector3(-2.0 + 4.0 * k, 1.5, -0.02)
		wb.rotation.y = deg_to_rad(0.0 if k == 0 else 180.0)
		root.add_child(wb)
	return root


func test_survey_on_a_built_room() -> void:
	var room: Node3D = _room()
	var rows: Array = Facing.survey(room)
	room.free()
	assert_eq(rows.size(), 2)
	var by: Dictionary = {}
	for r: Dictionary in rows:
		by[r["name"]] = r
	assert_eq(by["WallBuy_Room"]["verdict"], "OK", "front to the room")
	assert_true(by["WallBuy_Room"]["reachable"])
	assert_eq(by["WallBuy_Wall"]["verdict"], "BACKWARDS", "front into the wall")
	assert_eq(float(by["WallBuy_Wall"]["suggested_yaw"]), 0.0)
	assert_true(bool(by["WallBuy_Wall"].get("reachable_after", false)), "reachable once turned")
	var cam: Dictionary = by["WallBuy_Room"]["cam"]
	assert_true(bool(cam["on_nav"]), "the approach camera stands on the navmesh")
	assert_lt((cam["cam_pos"] as Vector3).z, -2.0, "in the room, in front of the buy")
