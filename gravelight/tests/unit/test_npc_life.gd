extends GutTest
## T-246 (the owner, 2026-11-14: "MAKE ALL THE NPCS FEEL MORE ALIVE, ALSO IVE ATTACHED SCREENSHOTS OF LITTLE BUGS"):
## the shared NPC life (NpcLife) and the two body bugs from the screenshots. The pure rules (the look's angles,
## the aim cone, the idle cycle, where breath shows), the life's reactions (a shot turns the head and startles, a
## zombie wins the look, the idles cycle and never repeat), the PatronBody and RemoteBody poses it drives, and the
## fixes: Trudi no longer checks a watch she does not wear with her hand on her face, a knife or pistol goes to the
## hip (not flat across the chest), Jakub's shovel hangs blade down, the warm-hands fidget keeps the hands under the
## chin on a modelled body, Trudi's skirt and stockings read as cloth at night.


class StubDirector extends RefCounted:
	var list: Array = []

	func active_zombies() -> Array:
		return list


class StubMap extends Node3D:
	var players: Dictionary = {}
	var director: Variant = null
	var map_id: StringName = &"map04d"


var _root: Node3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_look_angles_turn_toward_the_target_and_clamp() -> void:
	var b: Basis = Basis.IDENTITY   # facing -Z
	var left: Vector2 = NpcLife.look_angles(Vector3(0, 1.6, 0), b, Vector3(-3, 1.6, -3))
	assert_gt(left.x, 0.5, "a target to the left: a positive yaw (Godot's +Y turn)")
	assert_almost_eq(left.y, 0.0, 0.01, "level")
	var up: Vector2 = NpcLife.look_angles(Vector3(0, 1.6, 0), b, Vector3(0, 3.0, -2))
	assert_gt(up.y, 0.3, "above: looks up")
	var behind: Vector2 = NpcLife.look_angles(Vector3.ZERO, b, Vector3(0.1, 0, 5))
	assert_lte(absf(behind.x), NpcLife.MAX_YAW + 0.001, "behind: clamped to what a neck and chest turn")
	var turned: Vector2 = NpcLife.look_angles(Vector3.ZERO, Basis(Vector3.UP, PI * 0.5), Vector3(-5, 0, 0))
	assert_almost_eq(turned.x, 0.0, 0.01, "body-relative: a body turned left already faces -X")


func test_aimed_at_is_a_narrow_cone_in_range() -> void:
	var at: Vector3 = Vector3(0, 0, -8)
	var eye: Vector3 = Vector3(0, 1.6, 0)
	var fwd: Vector3 = (at + Vector3.UP * 1.2 - eye).normalized()
	assert_true(NpcLife.aimed_at(eye, fwd, at), "the sights on their chest")
	assert_false(NpcLife.aimed_at(eye, fwd.rotated(Vector3.UP, 0.25), at), "a quarter radian off: not at them")
	assert_false(NpcLife.aimed_at(eye, Vector3(0, 0, -1), Vector3(0, 0, -30)), "out of range")


func test_idles_never_repeat_when_there_is_a_choice() -> void:
	var set_: Array[StringName] = [&"warm", &"hug", &"look"]
	for i: int in 20:
		var r: float = float(i) / 20.0
		assert_ne(NpcLife.pick_idle(r, set_, &"hug"), &"hug")
	assert_eq(NpcLife.pick_idle(0.5, [&"warm"] as Array[StringName], &"warm"), &"warm", "one idle: it plays again")
	assert_eq(NpcLife.pick_idle(0.5, [] as Array[StringName], &""), &"", "none")


func test_breath_shows_only_in_the_cold() -> void:
	assert_true(NpcLife.cold_at(null, "map00_crossroads", Vector3(10, 0, 30)), "Map 0's snow")
	assert_true(NpcLife.cold_at(null, "map01", Vector3(0, 0, 0)), "Kaltenbrunn's yard")
	assert_false(NpcLife.cold_at(null, "map01", Vector3(0, -12, 0)), "Kaltenbrunn's depths are not the cold")
	assert_false(NpcLife.cold_at(null, "map04c", Vector3.ZERO), "the desert")
	assert_false(NpcLife.cold_at(null, "map04d", Vector3.ZERO), "the Moon")
	assert_false(NpcLife.cold_at(null, "", Vector3.ZERO))


func _patron(id: String = "kroll") -> PatronBody:
	var pb: PatronBody = PatronBody.new()
	_root.add_child(pb)
	pb.setup({"id": id, "person": id, "pose": "stand"})
	return pb


func _run(pb: Node, seconds: float) -> void:
	var n: int = int(seconds * 30.0)
	for i: int in n:
		pb.call("_process", 1.0 / 30.0)


func test_a_shot_turns_the_head_and_startles() -> void:
	var pb: PatronBody = _patron()
	var l: NpcLife = pb.enable_life()
	assert_not_null(l, "the life is on")
	_run(pb, 0.5)
	GLBus.weapon_fired.emit(1, &"kar98k", false, Vector3(-6, 1.5, -2), Vector3.FORWARD)
	assert_gt(l.startle, 0.3, "startled")
	assert_true(l.events.has("startle"))
	_run(pb, 0.6)
	assert_gt(l.look_yaw, 0.4, "the head turns to the shot on the left")
	assert_gt(pb.get("_head").rotation.y, 0.25, "and the body's head node follows it")
	_run(pb, 3.0)
	assert_lt(l.startle, 0.05, "it passes")


func test_a_far_shot_does_nothing() -> void:
	var pb: PatronBody = _patron()
	var l: NpcLife = pb.enable_life()
	GLBus.weapon_fired.emit(1, &"kar98k", false, Vector3(0, 1.5, -60), Vector3.FORWARD)
	assert_eq(l.startle, 0.0)


func test_a_zombie_close_wins_the_look() -> void:
	var map: StubMap = StubMap.new()
	_root.add_child(map)
	var pb: PatronBody = PatronBody.new()
	map.add_child(pb)
	pb.setup({"id": "pohl", "person": "pohl", "pose": "stand"})
	var l: NpcLife = pb.enable_life()
	assert_same(l.map, null, "a stub is not a MapRoot")
	l.map = map
	var z: Node3D = Node3D.new()
	map.add_child(z)
	z.position = Vector3(5, 0, -3)   # ahead and to the right
	var d: StubDirector = StubDirector.new()
	d.list = [z]
	map.director = d
	_run(pb, 1.5)
	assert_lt(l.look_yaw, -0.4, "the head turns right, to the zombie")
	assert_eq(l.idle, &"", "no idles with the dead this close")


func test_idles_cycle_with_pauses() -> void:
	var pb: PatronBody = _patron("pohl")
	var l: NpcLife = pb.enable_life([&"warm", &"hug", &"adjust"] as Array[StringName])
	_run(pb, 60.0)
	var seen: Array = []
	var last: String = ""
	for e: String in l.events:
		if e.begins_with("idle:"):
			assert_ne(e, last, "never the same idle twice running")
			last = e
			if not seen.has(e):
				seen.append(e)
	assert_gte(seen.size(), 2, "more than one idle in a minute: %s" % str(l.events))
	assert_gt(l.breath + 1.0, 1.0 - 0.001, "breathing")


func test_warm_hands_meet_under_the_chin() -> void:
	var pb: PatronBody = _patron("pohl")
	if pb.person == null:
		pending("no person GLB")
		return
	var l: NpcLife = pb.enable_life([&"warm"] as Array[StringName])
	l.set("_idle_t", 0.0)
	_run(pb, 4.0)
	assert_eq(l.idle, &"warm")
	assert_gt(l.idle_k, 0.9)
	var head: Vector3 = pb.person.bone_world("Head")
	var lh: Vector3 = pb.person.bone_world("LeftHand")
	var rh: Vector3 = pb.person.bone_world("RightHand")
	assert_lt(lh.distance_to(rh), 0.2, "the hands together")
	assert_lt(lh.y, head.y, "below the head (not on top of it)")
	assert_gt(lh.y, head.y - 0.45, "up at the chest and chin")


func test_hands_up_and_fear_when_aimed_at() -> void:
	var pb: PatronBody = _patron("kroll")
	var l: NpcLife = pb.enable_life()
	for i: int in 45:
		l.set("_aimed", true)
		pb.call("_process", 1.0 / 30.0)
	assert_gt(l.hands_up, 0.8, "hands up")
	assert_eq(pb.call("_face_state"), &"fear")
	if pb.person != null:
		assert_gt(pb.person.bone_world("LeftHand").y, pb.person.bone_world("Chest").y + 0.2, "the hands are up")


# ================================================================== the owner's two screenshots (RemoteBody)

func _remote(ch: StringName, weapon: StringName) -> RemoteBody:
	var b: RemoteBody = RemoteBody.new()
	_root.add_child(b)
	b.setup(ch, 31)
	b.set_weapon(weapon)
	return b


func _fidget(b: RemoteBody, kind: StringName, frames: int = 60) -> void:
	b.set("_still_t", 3.0)
	b.set("_fidget_t", 1.0)
	b.set("_fidget_kind", kind)
	for i: int in frames:
		b.calm = true
		b.set("_fidget_t", 1.0)
		b.update_pose(1.0 / 60.0, 0.0, 0.0, NetMatch.PF_FLOOR)


func test_trudi_no_longer_checks_a_watch_she_does_not_wear() -> void:
	var b: RemoteBody = _remote(&"trudi", &"trench_knife")
	var set_: Array[StringName] = b.fidget_set()
	assert_false(set_.has(&"watch"), "Trudi: no watch fidget (Peg's)")
	assert_true(set_.has(&"warm") and set_.has(&"hug"), "she warms her hands, wraps her arms round")
	assert_true(_remote(&"peg", &"thompson").fidget_set().has(&"watch"), "Peg keeps her watch")
	for ch: StringName in RemoteBody.FIDGETS.keys():
		assert_gte((RemoteBody.FIDGETS[ch] as Array).size(), 2, String(ch) + ": more than one idle")


func test_a_knife_goes_to_the_hip_not_across_the_chest() -> void:
	var b: RemoteBody = _remote(&"trudi", &"trench_knife")
	_fidget(b, &"hug")
	var gun: Node3D = b.get("_gun")
	assert_not_null(gun)
	var local: Vector3 = b.global_transform.affine_inverse() * gun.global_position
	assert_gt(local.x, 0.08, "at her right side")
	assert_lt(local.y, 1.15, "at the hip, not the chest")
	assert_lt(gun.global_basis.z.normalized().dot(Vector3.DOWN), -0.7, "pointing down (its -Z)")


func test_jakubs_shovel_hangs_blade_down() -> void:
	var b: RemoteBody = _remote(&"jakub", &"coal_shovel")
	_fidget(b, &"warm")
	var gun: Node3D = b.get("_gun")
	assert_lt((-gun.global_basis.z).normalized().dot(Vector3.UP), -0.7, "the blade end (-Z) down, the handle up")


func test_warm_fidget_hands_stay_under_the_chin() -> void:
	for ch: StringName in [&"jakub", &"trudi"]:
		var b: RemoteBody = _remote(ch, &"kar98k")
		if b.person == null:
			continue
		_fidget(b, &"warm")
		var head: Vector3 = b.person.bone_world("Head")
		var lh: Vector3 = b.person.bone_world("LeftHand")
		assert_lt(lh.y, head.y + 0.02, String(ch) + ": the wrist below the head (0.6 put it on top)")
		assert_gt(lh.y, head.y - 0.4, String(ch) + ": and up at the chin")


func test_trudis_skirt_and_stockings_read_as_cloth() -> void:
	for key: String in ["cloth3", "dark"]:
		var c: Color = PeopleBodies.look_of("trudi", key)[0]
		assert_gt(c.get_luminance(), 0.025, "Trudi's %s is not near black (it read as a black leg at night)" % key)


func test_set_life_on_and_off() -> void:
	var b: RemoteBody = _remote(&"trudi", &"trench_knife")
	b.set_life(true)
	assert_not_null(b.life)
	assert_true(b.life.busy, "its idles are the body's own fidgets")
	b.set_life(true)
	assert_eq(b.find_children("Life", "NpcLife", true, false).size(), 1, "idempotent")
	b.set_life(false)
	assert_null(b.life)
