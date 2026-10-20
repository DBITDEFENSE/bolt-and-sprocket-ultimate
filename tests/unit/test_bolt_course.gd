extends GutTest
## Bolt in real physics on a tiny course (headless): landing, step-up, wall slide + wall kick, the 3-hit
## mallet string, and the slam. Uses Bolt.scripted input, so no window or devices are involved.

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera


func _box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	_world.add_child(b)
	return b


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0))          # floor, top at y = 0
	_box(Vector3(30, 0.5, 4), Vector3(21, 0.25, 0))        # 0.5 m step from x = 6 (auto step-up)
	_box(Vector3(40, 6, 1), Vector3(0, 3, -12))            # tall wall at z = -12 (face at z = -11.5)
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 0)
	_world.add_child(_bolt)
	_cam = BoltCamera.new()
	_cam.target = _bolt
	_world.add_child(_cam)
	_bolt.camera = _cam
	_cam.yaw = 0.0                                         # camera behind +Z, looking toward -Z
	BS.god_mode = false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_lands_and_stands() -> void:
	_bolt.position.y = 3.0
	_bolt.scripted = {"dir": Vector3.ZERO}
	await _frames(60)
	assert_true(_bolt.motor.on_ground, "lands on the floor")
	assert_almost_eq(_bolt.global_position.y, 0.95, 0.06, "stands with feet on y = 0")


func test_steps_up_low_ledge() -> void:
	_bolt.scripted = {"dir": Vector3(1, 0, 0)}
	await _frames(70)
	assert_gt(_bolt.global_position.x, 7.0, "walked onto the step")
	assert_almost_eq(_bolt.global_position.y, 1.45, 0.1, "standing on top of the 0.5 m step")


func test_wall_slide_and_kick() -> void:
	# run toward the wall (-Z), jump into it, hold into it while falling, then kick off
	_bolt.scripted = {"dir": Vector3(0, 0, -1), "jump_held": true, "jump_pressed": true}
	_bolt.global_position = Vector3(0, 0.95, -6)
	var slid: bool = false
	for i: int in 90:
		await get_tree().physics_frame
		if _bolt.motor.wall_sliding:
			slid = true
			break
		_bolt.scripted["jump_held"] = i < 8      # release after takeoff (holding would engage the hover)
	assert_true(slid, "pressing into a tall wall while falling starts a wall slide")
	_bolt.scripted["jump_pressed"] = true
	await _frames(2)
	assert_gt(_bolt.motor.vel.z, 5.0, "wall kick shoves Bolt away from the wall")
	assert_gt(_bolt.motor.vel.y, 5.0, "wall kick goes up")


func test_mallet_string() -> void:
	var d: TestDummy = TestDummy.new()
	d.hp = 9999.0
	d.position = Vector3(0, 0, -2.0)
	_world.add_child(d)
	await _frames(10)
	for i: int in 3:
		_bolt.scripted = {"dir": Vector3.ZERO, "melee_pressed": true}
		await _frames(int(0.6 * 60))
	# Engine.time_scale is reduced during hitstop; let it recover
	Engine.time_scale = 1.0
	assert_gte(d.hits.size(), 3, "three mallet hits landed")
	assert_gte(d.total_damage(), 24.0 + 28.0 + 55.0, "sweep 24 + backswing 28 + spin smash 55")


func test_slam_hits_and_launches() -> void:
	var d: TestDummy = TestDummy.new()
	d.hp = 9999.0
	d.position = Vector3(0, 0, -1.5)
	_world.add_child(d)
	await _frames(10)
	_bolt.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}
	await _frames(20)
	_bolt.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}   # double jump
	await _frames(15)
	_bolt.scripted = {"dir": Vector3.ZERO, "crouch_pressed": true}                     # slam
	await _frames(80)
	Engine.time_scale = 1.0
	assert_gt(d.total_damage(), 0.0, "slam shockwave damaged the dummy")
	assert_gt(d.launched, 0.0, "slam launches enemies")
	assert_true(_bolt.motor.on_ground)
