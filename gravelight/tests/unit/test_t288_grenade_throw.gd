extends GutTest
## T-288 (the owner: "MAKE A THROWING ANIMATION FOR GRENADES"): the throw is animated round the two moments that
## were already there (the press starts the cook, the release throws), and changes neither: the grenade leaves on
## the same tick, from the same point, at the same speed, with the same fuse, with the animation on or off. The
## hand is put on the spawn point's spot at the release. Interrupted throws put the arm back. The third-person body
## swings from the release point the thrower sends and holds the cook pose on PF_COOK.

const DT: float = 1.0 / 60.0

var _p: Player
var _saved: bool = true


func before_each() -> void:
	_saved = WeaponHolder.throw_anim
	for g0: Node in _grenades():   # (a grenade an earlier test threw lies in this test node)
		g0.free()
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	WeaponHolder.throw_anim = _saved
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _grenades() -> Array:
	var out: Array = []
	for c: Node in get_children():
		if c is Grenade:
			out.append(c)
	return out


## Holds the lethal button for `hold` ticks, releases, ticks on until a grenade exists. Returns
## [tick it appeared, its offset from the camera in camera space, its velocity in camera space, its fuse].
func _throw_once(hold: int) -> Array:
	var h: WeaponHolder = _p.weapons
	h.grenades = 2
	for g0: Node in _grenades():
		g0.free()
	var t: int = 0
	for i: int in hold:
		h.tick(DT, {"lethal_held": true})
		t += 1
	var found: Grenade = null
	for i2: int in 5:
		h.tick(DT, {"lethal_held": false})
		t += 1
		var gs: Array = _grenades()
		if not gs.is_empty():
			found = gs[0]
			break
	if found == null:
		return []
	var cam: Camera3D = _p.camera
	var inv: Basis = cam.global_basis.inverse()
	var out: Array = [t, inv * (found.global_position - cam.global_position), inv * found.linear_velocity, found.fuse]
	found.free()
	return out


func test_the_grenade_leaves_on_the_same_tick_from_the_same_point_at_the_same_speed() -> void:
	for hold: int in [3, 20, 90]:
		WeaponHolder.throw_anim = false
		var before: Array = _throw_once(hold)
		WeaponHolder.throw_anim = true
		var after: Array = _throw_once(hold)
		assert_false(before.is_empty() or after.is_empty(), "a grenade was thrown (hold %d)" % hold)
		if before.is_empty() or after.is_empty():
			return
		assert_eq(after[0], before[0], "hold %d ticks: the release tick" % hold)
		assert_lt((after[1] as Vector3).distance_to(before[1]), 0.0001, "hold %d: the spawn point" % hold)
		assert_lt((after[2] as Vector3).distance_to(before[2]), 0.0001, "hold %d: the speed and arc" % hold)
		assert_almost_eq(float(after[3]), float(before[3]), 0.0001, "hold %d: the fuse left" % hold)
	assert_almost_eq((_throw_once(10)[1] as Vector3).distance_to(Vector3(0, -0.1, -0.6)), 0.0, 0.0001, "the spawn point: 0.6 m ahead, 0.1 m down")


func test_the_hand_is_on_the_spawn_point_at_the_release() -> void:
	WeaponHolder.throw_anim = true
	var h: WeaponHolder = _p.weapons
	h.grenades = 2
	for i: int in 30:
		h.tick(DT, {"lethal_held": true})
	h.tick(DT, {"lethal_held": false})
	var gs: Array = _grenades()
	assert_eq(gs.size(), 1)
	var g: Grenade = gs[0]
	assert_lt(h.last_release_rig.distance_to(h.vm_target(g.global_position)), 0.0001, "the release point is the spawn point's spot in the viewmodel")
	var pose: Array = WeaponHolder.throw_pose(false, 0.0, WeaponHolder.THROW_S, h.last_release_rig, Vector3(-0.2, -0.35, -0.2))
	assert_lt((pose[0] as Vector3).distance_to(h.last_release_rig), 0.00001, "at the release frame the hand is there")


func test_the_throw_runs_through_its_phases_and_ends_on_the_gun() -> void:
	var gun: Vector3 = Vector3(-0.2, -0.35, -0.2)
	var rel: Vector3 = Vector3(0.0, -0.07, -0.45)
	assert_lt((WeaponHolder.throw_pose(true, 0.0, 0.0, rel, gun)[0] as Vector3).distance_to(gun), 0.0001, "the press: from the gun")
	assert_lt((WeaponHolder.throw_pose(true, WeaponHolder.PIN_S, 0.0, rel, gun)[0] as Vector3).distance_to(WeaponHolder.POSE_PIN), 0.0001, "the pin pull")
	var held: Vector3 = WeaponHolder.throw_pose(true, WeaponHolder.PIN_S + WeaponHolder.DRAW_S + 1.0, 0.0, rel, gun)[0]
	assert_lt(held.distance_to(WeaponHolder.POSE_BACK), 0.0001, "the cook: drawn back")
	assert_gt(held.y, WeaponHolder.POSE_PIN.y, "drawn back means raised")
	var mid: Vector3 = WeaponHolder.throw_pose(false, 0.0, WeaponHolder.THROW_S * 0.5, rel, gun)[0]
	assert_lt(mid.distance_to(rel + WeaponHolder.FOLLOW_OFF), 0.0001, "the follow-through swings forward and down")
	assert_lt((WeaponHolder.throw_pose(false, 0.0, 0.0, rel, gun)[0] as Vector3).distance_to(gun), 0.0001, "back on the gun when _throw_t runs out")
	# continuous: no jump bigger than a fast hand between two 60 Hz frames (rig space, shrunk 4x toward the eye on
	# screen; the swing out of the release and the hand's way back to the gun are the fastest parts)
	var prev: Vector3 = rel
	var t: float = WeaponHolder.THROW_S
	while t > 0.0:
		t -= DT
		var p2: Vector3 = WeaponHolder.throw_pose(false, 0.0, maxf(0.0, t), rel, gun)[0]
		assert_lt(p2.distance_to(prev), 0.1, "smooth at %.3f s left" % t)
		prev = p2


func test_an_interrupted_throw_puts_the_arm_back() -> void:
	WeaponHolder.throw_anim = true
	var h: WeaponHolder = _p.weapons
	for kind: String in ["downed", "spectate", "carry"]:
		h.grenades = 2
		for i: int in 20:
			h.tick(DT, {"lethal_held": true})
		assert_true(h.is_cooking(), "%s: cooking" % kind)
		match kind:
			"downed":
				h.enter_last_stand()
			"spectate":
				h.clear_for_spectate()
			"carry":
				h.apply_carry(h.to_net())
		assert_false(h.is_cooking(), "%s: no longer cooking" % kind)
		assert_eq(float(h.get("_throw_t")), 0.0, "%s: no follow-through left" % kind)
		var prop: Node3D = h.get("_frag_prop") as Node3D
		if prop != null:
			assert_false(prop.visible, "%s: the grenade is out of the hand" % kind)
	# a weapon swap or a ladder mid-cook change nothing in the throw: it still leaves on the release
	h.grenades = 2
	for i2: int in 10:
		h.tick(DT, {"lethal_held": true})
	h.set_hands(&"climb")
	h.tick(DT, {"lethal_held": true})
	h.set_hands(&"")
	h.tick(DT, {"lethal_held": false})
	assert_eq(_grenades().size(), 1, "the cooked grenade still leaves on the release")


func test_the_pin_and_the_spoon_are_parts_of_the_frag() -> void:
	var frag: Node3D = WeaponModels.build(&"frag")
	assert_not_null(frag.get_node_or_null("Pin"), "the ring is its own part (pulled at the cook)")
	assert_not_null(frag.get_node_or_null("Spoon"), "the spoon is its own part (flies at the throw)")
	frag.free()


func test_the_third_person_swings_from_the_release_point_and_holds_the_cook() -> void:
	var chest: Transform3D = Transform3D(Basis(), Vector3(0, 1.0, 0))
	var gun: Vector3 = Vector3(0.1, 1.2, -0.5)
	var rel: Vector3 = Vector3(-0.1, 1.6, -0.45)
	assert_lt(RemoteBody.throw_hand(chest, rel, 0.0, gun).distance_to(rel), 0.0001, "the release: the hand at the spawn point")
	assert_lt(RemoteBody.throw_hand(chest, rel, 1.0, gun).distance_to(gun), 0.0001, "the end: back on the gun")
	var far: Vector3 = RemoteBody.throw_hand(chest, Vector3(0, 9, -9), 0.0, gun)
	assert_lt(far.distance_to(chest * Vector3(-0.2, 0.5, 0.0)), RemoteBody.UPPER + RemoteBody.FORE + 0.001, "a far point is pulled into the arm's reach")
	assert_true(RemoteBody.throw_hand(chest, Vector3.INF, 0.0, gun).is_finite(), "no point sent: a raised point by the head")
	# PF_COOK holds the left hand drawn back with the grenade in it
	var b: RemoteBody = RemoteBody.new()
	add_child_autofree(b)
	b.setup(&"dutch", 41)
	for i: int in 40:
		b.update_pose(DT, 0.0, 0.0, NetMatch.PF_FLOOR | NetMatch.PF_COOK)
	assert_gt(float(b.get("_cook_b")), 0.9, "the cook pose is held")
	var frag: Node3D = b.get("_frag") as Node3D
	assert_true(frag != null and frag.visible, "the grenade in the fist")
	b.fire(4, &"frag", b.global_position + Vector3(0, 1.6, -0.5), b.global_position + Vector3(0, 1.7, -1.5))
	b.update_pose(DT, 0.0, 0.0, NetMatch.PF_FLOOR)
	assert_false(frag.visible, "released: the real grenade flies, the fist is empty")
	for i2: int in 40:
		b.update_pose(DT, 0.0, 0.0, NetMatch.PF_FLOOR)
	assert_lt(float(b.get("_cook_b")), 0.05, "and the arm goes back to the gun")
