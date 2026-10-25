extends GutTest
## T-072, "make Map 0 feel alive": the doorway clearance check (the stable door's pole must never come back), and
## the round 1 opening's rules: it plays only on the first start of round 1 on Map 0, its risers and attackers come
## out of round 1's own queue (the total never changes), and its lines are in the script.

const MAP00: StringName = &"map00_crossroads"


func _pole(parent: Node3D, a: Vector3, b: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.position = (a + b) * 0.5
	parent.add_child(mi)
	return mi


func test_triangle_box_overlap() -> void:
	var h: Vector3 = Vector3(0.5, 0.5, 0.5)
	assert_true(DoorClearance.tri_box(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), h), "a triangle through the box")
	assert_false(DoorClearance.tri_box(Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(2, 1, 0), h), "beside it")
	assert_false(DoorClearance.tri_box(Vector3(0.9, -2, 0), Vector3(2, 0.9, 0), Vector3(2, -2, 0), h), "near a corner but outside (edge axes)")


func test_a_pole_through_a_doorway_is_found() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var ops: Array[Dictionary] = [DoorClearance.opening("Door", Vector3(20, 0, 16), 0.0, 2.0, 2.4)]
	assert_eq(DoorClearance.intrusions(root, ops).size(), 0, "an empty doorway is clear")
	# the old taproom post: x 19.85..20.15, z 15.58..15.85, floor to ceiling, on the room side of the stable door
	var pole: MeshInstance3D = _pole(root, Vector3(19.85, 0, 15.58), Vector3(20.15, 3.5, 15.85))
	var hits: PackedStringArray = DoorClearance.intrusions(root, ops)
	assert_eq(hits.size(), 1, "the post in front of the door is caught")
	pole.free()
	_pole(root, Vector3(21.2, 0, 15.58), Vector3(21.5, 3.5, 15.85))   # a post beside the frame
	_pole(root, Vector3(18.0, 0, 15.80), Vector3(19.0, 1.1, 15.85))   # wainscot up to the jamb
	_pole(root, Vector3(19.0, 0.0, 15.0), Vector3(21.0, 0.05, 17.0))  # a rug under the sill line
	assert_eq(DoorClearance.intrusions(root, ops).size(), 0, "trim beside the jamb and a rug on the floor are fine")


func test_colliders_count_areas_and_skipped_nodes_do_not() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var leaf: MeshInstance3D = _pole(root, Vector3(19.2, 0, -0.04), Vector3(20.8, 2.4, 0.04))
	var ops: Array[Dictionary] = [DoorClearance.opening("Front", Vector3(20, 0, 0), 0.0, 1.6, 2.4, [leaf])]
	assert_eq(DoorClearance.intrusions(root, ops).size(), 0, "the door's own leaf is skipped")
	var area: Area3D = Area3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	area.add_child(cs)
	area.position = Vector3(20, 1, 0)
	root.add_child(area)
	assert_eq(DoorClearance.intrusions(root, ops).size(), 0, "an area (a zone, an interact volume) is not in the way")
	var body: StaticBody3D = StaticBody3D.new()
	var cs2: CollisionShape3D = CollisionShape3D.new()
	cs2.shape = BoxShape3D.new()
	body.add_child(cs2)
	body.position = Vector3(20, 1, 0.3)
	root.add_child(body)
	assert_eq(DoorClearance.intrusions(root, ops).size(), 1, "a solid collider in the doorway is")


func test_opening_plays_only_on_the_first_round_one() -> void:
	var c: Dictionary = InnOpening.load_cfg()
	assert_false(c.is_empty(), "map00_opening.json loads")
	assert_true(InnOpening.should_play(MAP00, 1, 1, false, false, c), "round 1 of a fresh match on Map 0")
	assert_false(InnOpening.should_play(MAP00, 2, 2, false, false, c), "never a later round")
	assert_false(InnOpening.should_play(MAP00, 11, 11, true, false, c), "never a campaign arrival")
	assert_false(InnOpening.should_play(MAP00, 1, 1, true, false, c), "an arrival, even on round 1")
	assert_false(InnOpening.should_play(MAP00, 1, 1, false, true, c), "only once")
	assert_false(InnOpening.should_play(&"map01_kaltenbrunn", 1, 1, false, false, c), "only on Map 0")
	assert_false(InnOpening.should_play(MAP00, 1, 5, false, false, c), "a dev skip that lands elsewhere")


func test_slots_come_out_of_the_round_queue() -> void:
	assert_eq(InnOpening.plan_slots(6, 3, 2), {"risers": 3, "attackers": 2})
	assert_eq(InnOpening.plan_slots(4, 3, 2), {"risers": 3, "attackers": 1}, "risers first")
	assert_eq(InnOpening.plan_slots(2, 3, 2), {"risers": 2, "attackers": 0})
	assert_eq(InnOpening.plan_slots(0, 3, 2), {"risers": 0, "attackers": 0}, "never more than the queue")
	var c: Dictionary = InnOpening.load_cfg()
	var risers: PackedStringArray = InnOpening.riser_ids(c)
	assert_eq(risers.size(), 3, "Kubiak, Rother and Sobotta rise")
	var solo: int = RoundManager.zombie_count(1, 1, GLData.table("rounds"))
	assert_lte(risers.size() + (c["attackers"] as Array).size(), solo, "round 1 solo holds every opening zombie")
	# the reservation keeps round 1's total: take the slots, give back what was never used
	RoundManager.to_spawn = solo
	RoundManager.alive = 0
	var plan: Dictionary = InnOpening.plan_slots(RoundManager.to_spawn, risers.size(), 2)
	for i: int in int(plan["risers"]) + int(plan["attackers"]):
		RoundManager.take_spawn()
	assert_eq(RoundManager.remaining(), solo, "taken slots still count toward the round")
	RoundManager.requeue()
	assert_eq(RoundManager.remaining(), solo, "a slot given back too")
	RoundManager.to_spawn = 0
	RoundManager.alive = 0


func test_exit_order_and_fates() -> void:
	var c: Dictionary = InnOpening.load_cfg()
	var ex: Dictionary = InnOpening.exit_times(c)
	var open_at: float = float(c["front_door"]["open_at"])
	assert_eq(float(ex["sobotta"]), -1.0, "the bitten soldier never goes out")
	for id: String in ["trudi", "pohl", "kubiak", "rother"]:
		assert_gte(float(ex[id]), open_at, id + " goes out once the door is open")
	assert_lt(float(c["front_door"]["open_at"]), float(c["front_door"]["close_at"]))
	assert_lte(float(c["end_by"]), 60.0, "brief: well under a minute")
	var escapes: int = 0
	for row: Dictionary in c["patrons"]:
		if str(row["fate"]) == "escape":
			escapes += 1
	assert_eq(escapes, 2, "Trudi and Frau Pohl get away")


func test_opening_lines_are_scripted_and_accounted() -> void:
	var c: Dictionary = InnOpening.load_cfg()
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var man: Dictionary = GLData.load_json("res://data/gravelight/vo/audio_manifest.json")
	for ln: Dictionary in c["lines"]:
		assert_true(lines.has(str(ln["id"])), str(ln["id"]) + " in lines.json")
		assert_true((man["files"] as Dictionary).has(str(ln["id"])) or (man["missing"] as Dictionary).has(str(ln["id"])), str(ln["id"]) + " baked or listed missing")
	for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
		assert_true(lines.has(spk + "_INN_RISE_01"), "the squad reacts: " + spk)


## T-076: round 1 waits for the player to have looked round the taproom (and at the door), and for a line to end.
func test_look_around_gate() -> void:
	var c: Dictionary = InnOpening.load_cfg()
	var lk: Dictionary = c.get("look", {})
	assert_false(lk.is_empty(), "map00_opening.json has a look block")
	var mn: float = float(lk["min_seconds"])
	var mx: float = float(lk["max_seconds"])
	assert_gte(mn, 5.0, "a few seconds to look round first")
	assert_false(InnOpening.look_ready(mn - 0.1, true, 0.0, c), "never before the look-around")
	assert_true(InnOpening.look_ready(mn, true, 0.0, c), "facing the door after it: go")
	assert_false(InnOpening.look_ready(mn + 1.0, false, 0.0, c), "looking away: wait")
	assert_true(InnOpening.look_ready(mx, false, 0.0, c), "but not past the max")
	assert_false(InnOpening.look_ready(mn + 1.0, true, mn + 2.0, c), "a patron mid-line: wait for the end")
	assert_true(InnOpening.look_ready(mx + 6.0, false, mx + 30.0, c), "never held forever")
	assert_true(InnOpening.look_ready(0.0, false, 0.0, {}), "no look block: as before")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	assert_true(lines.has(str((lk["cue_line"] as Dictionary)["id"])), "the cue line exists")


func test_facing() -> void:
	assert_true(InnOpening.facing(Vector3(14.5, 1.6, 13.4), Vector3(0, 0, -1), Vector3(20, 1.2, 0), 50.0), "the front door from the spawn, facing north")
	assert_false(InnOpening.facing(Vector3(14.5, 1.6, 13.4), Vector3(0, 0, 1), Vector3(20, 1.2, 0), 50.0), "facing south")
	assert_false(InnOpening.facing(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -5), 50.0), "90 degrees off")


## T-076: every patron is in the starting view from PlayerSpawn1 (facing north), within 56 deg of forward (an 80 deg
## FOV at 16:9), and the porch catches are in line with the open doorway as seen from there.
func test_the_opening_is_in_front_of_the_spawn() -> void:
	var c: Dictionary = InnOpening.load_cfg()
	var spawn: Vector3 = Vector3(14.5, 1.6, 13.4)
	for row: Dictionary in c["patrons"]:
		var p: Vector3 = InnOpening._v3(row["start"])
		assert_true(InnOpening.facing(spawn, Vector3(0, 0, -1), p, 56.0), "%s at %s is in the starting view" % [row["id"], str(p)])
	var door: Vector3 = Vector3(20, 0, 0)
	for row2: Dictionary in c["patrons"]:
		if str(row2["id"]) in ["kubiak", "rother"]:
			var end: Vector3 = InnOpening._v3((row2["outside"] as Array).back())
			var k: float = (spawn.z - end.z) / (spawn.z - door.z)
			var x_line: float = spawn.x + (door.x - spawn.x) * k
			assert_almost_eq(end.x, x_line, 1.1, "%s is caught in line with the open doorway" % row2["id"])
