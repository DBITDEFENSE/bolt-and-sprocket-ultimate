extends GutTest
## T-236 movement feel: the jump forgiveness (coyote time, the jump buffer), the step assist (kerbs walked up,
## short drops walked down, the eased eye, off for bots by default), the quicker strafe reversal and the
## fall-gravity switch. The body here is a player in bot mode (Player.drive_bot with a MoveIntent), so the shared
## movement code runs without the input map; the smoke (tools_src/smoke_move_feel) drives the real inputs.

const DT: float = 1.0 / 60.0

var _host: Node3D
var _p: Player
var _mi: MoveIntent
var _mv: Dictionary


func before_each() -> void:
	GameState.gravity_scale = 1.0
	_host = Node3D.new()
	add_child_autofree(_host)
	_box(Vector3(-20, -1, -40), Vector3(20, 0, 40))             # the floor
	_box(Vector3(-2, 0, -20), Vector3(2, 0.25, -2))             # a 0.25 m kerb across the way north
	_box(Vector3(8, 0, 0), Vector3(12, 1.2, 10))                # a 1.2 m ledge; its north edge is z = 0
	_p = Player.new()
	_p.bot_driven = true
	_host.add_child(_p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mv = (GLData.table("movement") as Dictionary).duplicate(true)
	_p.set("_mv", _mv)                                           # this test's own copy of the tunables
	_mi = MoveIntent.new()
	await _frames(3)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _box(a: Vector3, b: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = (b - a).abs()
	cs.shape = bs
	body.add_child(cs)
	_host.add_child(body)
	body.global_position = (a + b) * 0.5


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## n physics ticks of the shared movement code; a jump press lasts one tick.
func _tick(n: int = 1) -> void:
	for i: int in n:
		await get_tree().physics_frame
		_p.drive_bot(DT, _mi)
		_mi.jump_pressed = false


func _put(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = 0.0
	_mi.clear()
	await _tick(10)


func test_the_tunables_are_data() -> void:
	var mv: Dictionary = GLData.table("movement")
	var j: Dictionary = mv.get("jump", {})
	var s: Dictionary = mv.get("step", {})
	assert_between(float(j.get("coyote_time", 0.0)), 0.05, 0.2, "coyote time")
	assert_between(float(j.get("buffer_time", 0.0)), 0.05, 0.25, "jump buffer")
	assert_between(float(j.get("fall_gravity_mult", 0.0)), 1.0, 1.6, "fall gravity")
	assert_between(float(mv.get("turn_boost", 0.0)), 1.0, 2.5, "turn boost")
	assert_lt(float(s.get("max_h", 9.0)), float((mv.get("mantle", {}) as Dictionary).get("min_h", 0.5)), "steps end where mantles begin")
	assert_false(bool(s.get("bots", true)), "bots keep the plain slide (their paths were tuned on it)")


func test_a_bot_is_still_stopped_by_a_kerb() -> void:
	await _put(Vector3(0, 0.02, 0))
	_mi.move = Vector2(0, -1)
	await _tick(90)
	assert_lt(_p.global_position.y, 0.05, "not climbed")
	assert_gt(_p.global_position.z, -2.0, "held at the kerb")


func test_the_step_assist_walks_up_a_kerb_and_the_eye_follows_eased() -> void:
	(_mv["step"] as Dictionary)["bots"] = true
	await _put(Vector3(0, 0.02, 0))
	_mi.move = Vector2(0, -1)
	var stepped: bool = false
	var air: int = 0
	for i: int in 90:
		await _tick()
		if not _p.is_on_floor():
			air += 1
		if not stepped and _p.global_position.y > 0.2:
			stepped = true
			var off: Vector3 = _p.get("_view_off")
			assert_almost_eq(off.y, -0.25, 0.06, "the eye starts where it was: a step below the body")
			assert_gt(off.z, 0.1, "and behind it by the edge the step skipped")
			assert_gt(float(_p.get("_step_hold")), 0.0, "the body waits out that distance")
	assert_true(stepped, "walked up the 0.25 m kerb")
	assert_almost_eq(_p.global_position.y, 0.25, 0.02, "standing on it")
	assert_eq(air, 0, "never airborne (no landing, no fall)")
	assert_eq(_p.get("_view_off"), Vector3.ZERO, "the eye has caught up")
	var speed: float = float(GLData.table("player")["walk_speed"]) * _p.weapons.move_mult()
	assert_gt(_p.global_position.z, -speed * 1.5 - 0.1, "no head start from the step (%.2f m in 1.5 s)" % -_p.global_position.z)
	assert_lt(_p.global_position.z, -speed * 1.5 + 0.8, "and under 0.2 s lost to it")


func test_a_short_drop_is_walked_down() -> void:
	(_mv["step"] as Dictionary)["bots"] = true
	await _put(Vector3(0, 0.27, -4.0))
	_p.rotation.y = PI                       # facing south, off the kerb's edge at z = -2
	_mi.move = Vector2(0, -1)
	var air: int = 0
	for i: int in 60:
		await _tick()
		if not _p.is_on_floor():
			air += 1
	assert_lt(_p.global_position.y, 0.02, "down on the floor")
	assert_lte(air, 1, "without a fall")


func test_coyote_time() -> void:
	for late: int in [3, 12]:
		await _put(Vector3(10, 1.22, 1.5))
		_mi.move = Vector2(0, -1)
		var n: int = 0
		while _p.is_on_floor() and n < 120:
			await _tick()
			n += 1
		assert_lt(n, 120, "walked off the ledge")
		await _tick(late - 1)
		_mi.jump_pressed = true
		await _tick()
		if late == 3:
			assert_gt(_p.velocity.y, 3.0, "a jump pressed 3 ticks after the feet left the ledge jumps")
		else:
			assert_lt(_p.velocity.y, 0.0, "one pressed 12 ticks after does not")


func test_coyote_time_gives_no_second_jump() -> void:
	await _put(Vector3(0, 0.02, 10))
	_mi.jump_pressed = true
	await _tick(3)
	var vy: float = _p.velocity.y
	_mi.jump_pressed = true
	await _tick()
	assert_lt(_p.velocity.y, vy, "a press just after take-off is not a second jump")


func test_jump_buffer() -> void:
	await _put(Vector3(0, 0.02, 10))
	_mi.jump_pressed = true
	await _tick(4)
	var n: int = 0
	while not (_p.velocity.y < 0.0 and _p.global_position.y < 0.2) and n < 120:
		await _tick()
		n += 1
	_mi.jump_pressed = true                  # still in the air, a few ticks above the floor
	await _tick()
	assert_false(_p.is_on_floor(), "pressed in the air")
	var jumped: bool = false
	for i: int in 10:
		await _tick()
		if _p.velocity.y > 3.0:
			jumped = true
			break
	assert_true(jumped, "the press is remembered and jumps on the landing")
	assert_eq(float(_p.get("_jump_buf")), 0.0, "and is spent")


func test_an_old_press_is_forgotten() -> void:
	await _put(Vector3(0, 0.02, 10))
	_mi.jump_pressed = true
	await _tick(8)
	_mi.jump_pressed = true                  # near the top of the jump: far too early
	var jumps: int = 0
	var up: bool = true
	for i: int in 60:
		await _tick()
		if _p.velocity.y > 3.0 and not up:
			jumps += 1
		up = _p.velocity.y > 0.0
	assert_eq(jumps, 0, "no jump on the landing half a second later")


func _reversal_ticks(boost: float) -> int:
	_mv["turn_boost"] = boost
	await _put(Vector3(0, 0.02, 10))
	_mi.move = Vector2(-1, 0)
	await _tick(30)
	_mi.move = Vector2(1, 0)
	var n: int = 0
	while _p.velocity.x < 4.0 and n < 120:
		await _tick()
		n += 1
	return n


func test_turn_boost_shortens_a_strafe_reversal() -> void:
	var plain: int = await _reversal_ticks(1.0)
	var boosted: int = await _reversal_ticks(float(GLData.table("movement").get("turn_boost", 1.0)))
	assert_lt(boosted, plain, "the reversal is quicker (%d -> %d ticks)" % [plain, boosted])
	assert_gt(boosted, 6, "but still a curve, not a snap")


func test_fall_gravity_is_plain_by_default_and_never_bends_a_launch() -> void:
	_p.velocity.y = -3.0
	assert_almost_eq(float(_p.call("_fall_gravity_mult")), 1.0, 0.001, "shipped: the same both ways")
	(_mv["jump"] as Dictionary)["fall_gravity_mult"] = 1.3
	assert_almost_eq(float(_p.call("_fall_gravity_mult")), 1.3, 0.001, "falling")
	_p.velocity.y = 2.0
	assert_almost_eq(float(_p.call("_fall_gravity_mult")), 1.0, 0.001, "rising")
	assert_almost_eq(float(_p.call("_fall_gravity_mult", true)), 1.3, 0.001, "a landing reads the falling value")
	_p.velocity.y = -3.0
	_p.air_grace_t = 1.0
	assert_almost_eq(float(_p.call("_fall_gravity_mult")), 1.0, 0.001, "a launch plate's arc keeps plain gravity")
	_p.air_grace_t = 0.0


func test_the_tick_path_reads_the_step_phase_unblended() -> void:
	_p.set("_step_count", 3)
	_p.set("_step_dist", 1.05)
	_p.set("_phase_prev", 3.1)
	assert_almost_eq(_p.step_phase(), 3.5, 0.001, "no smooth motion: the tick's own value")
	assert_almost_eq(float(_p.call("_view_frac")), 1.0, 0.001)


# ---------------------------------------------------------------- T-291: stairs on either physics engine

## A staircase north from z = 0 at x = -12: `n` steps of rise x run, as overlapping boxes (like smoke_move_feel's)
## or as one trimesh (like a map's collision mesh).
func _stairs(rise: float, run: float, n: int, trimesh: bool) -> void:
	if not trimesh:
		for i: int in n:
			_box(Vector3(-14, 0, -20), Vector3(-10, rise * float(i + 1), -run * float(i)))
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in n:
		var z0: float = -run * float(i)
		var z1: float = -run * float(i + 1) if i < n - 1 else -20.0
		var y0: float = rise * float(i)
		var y1: float = rise * float(i + 1)
		# (front faces wind clockwise: the riser faces +z, the tread up; a trimesh collides on its front only)
		for v: Vector3 in [Vector3(-14, y0, z0), Vector3(-10, y1, z0), Vector3(-10, y0, z0), Vector3(-14, y0, z0), Vector3(-14, y1, z0), Vector3(-10, y1, z0),
				Vector3(-14, y1, z0), Vector3(-10, y1, z1), Vector3(-10, y1, z0), Vector3(-14, y1, z0), Vector3(-14, y1, z1), Vector3(-10, y1, z1)]:
			st.add_vertex(v)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = st.commit().create_trimesh_shape()
	body.add_child(cs)
	_host.add_child(body)


## Walks north up the staircase from 2 m out. Returns [climbed to the top, slowest speed on the steps, airborne ticks].
func _climb_stairs(rise: float, run: float, n: int) -> Array:
	(_mv["step"] as Dictionary)["bots"] = true
	await _put(Vector3(-12, 0.02, 2.0))
	_mi.move = Vector2(0, -1)
	var slow: float = 99.0
	var air: int = 0
	var t: int = 0
	while t < 240 and _p.global_position.z > -run * float(n) - 0.8:
		await _tick()
		t += 1
		if _p.global_position.z < 0.3 and _p.global_position.z > -run * float(n):
			slow = minf(slow, _p.horizontal_speed())
			if not _p.is_on_floor():
				air += 1
	return [absf(_p.global_position.y - rise * float(n)) < 0.03, slow, air]


## The tread (0.30 m) is shorter than the capsule is wide (0.70 m): the step down past an edge meets the next
## step's nose at 45.6 deg, right on the 46 deg floor limit; Jolt reports 46.3 (its box edges are rounded) and
## refused every step until T-291 (smoke_move_feel). Climbed on whichever engine runs the suite, without a stall.
func test_a_staircase_with_treads_shorter_than_the_capsule_is_walked_up() -> void:
	for spec: Array in [[0.18, 0.30, false], [0.20, 0.28, false], [0.18, 0.30, true], [0.20, 0.28, true]]:
		_stairs(float(spec[0]), float(spec[1]), 8, bool(spec[2]))
		await _frames(1)
		var r: Array = await _climb_stairs(float(spec[0]), float(spec[1]), 8)
		var what: String = "%.2f x %.2f %s (%s)" % [spec[0], spec[1], "trimesh" if spec[2] else "boxes", ProjectSettings.get_setting("physics/3d/physics_engine")]
		assert_true(bool(r[0]), "climbed: " + what)
		assert_gt(float(r[1]), 2.0, "never stalled on a step: " + what)
		assert_lte(int(r[2]), 1, "feet on the steps: " + what)
		for c: Node in _host.get_children():
			if c is StaticBody3D and (c.global_position.x < -9.0):
				c.free()


## The nose rule: how far on, for an edge met ahead under the capsule's round, before it reads as floor.
func test_the_nose_advance_is_small_and_only_for_an_edge_ahead() -> void:
	var cos_floor: float = cos(_p.floor_max_angle)
	var into: Vector3 = Vector3(0, 0, -1)
	var at_limit: Vector3 = Vector3(0, cos(deg_to_rad(46.3)), sin(deg_to_rad(46.3)))   # Jolt's 0.18 x 0.30 nose
	var more: float = float(_p.call("_nose_advance", at_limit, into, cos_floor))
	assert_between(more, 0.01, 0.04, "a couple of centimetres (%.3f m)" % more)
	assert_eq(float(_p.call("_nose_advance", Vector3.UP, into, cos_floor)), 0.0, "a flat top needs none")
	assert_eq(float(_p.call("_nose_advance", Vector3(0, at_limit.y, -at_limit.z), into, cos_floor)), 0.0, "an edge behind: none")
	assert_eq(float(_p.call("_nose_advance", Vector3(at_limit.z, at_limit.y, 0), into, cos_floor)), 0.0, "an edge to the side: none")
	var steep: Vector3 = Vector3(0, cos(deg_to_rad(75.0)), sin(deg_to_rad(75.0)))
	assert_eq(float(_p.call("_nose_advance", steep, into, cos_floor)), 0.0, "a nose far ahead is not reached for")


## A steep slab (60 deg) low enough to step is still not stepped onto: the second set-down meets the slope again.
func test_a_steep_slope_is_not_stepped_onto() -> void:
	(_mv["step"] as Dictionary)["bots"] = true
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(4, 0.2, 3)
	cs.shape = bs
	body.add_child(cs)
	_host.add_child(body)
	body.global_position = Vector3(-12, 0.0, -1.5)
	body.rotation_degrees.x = 60.0                   # rises toward -z
	await _put(Vector3(-12, 0.02, 1.5))
	_mi.move = Vector2(0, -1)
	await _tick(90)
	assert_lt(_p.global_position.y, 0.3, "held at the foot of the slope (y %.2f)" % _p.global_position.y)
