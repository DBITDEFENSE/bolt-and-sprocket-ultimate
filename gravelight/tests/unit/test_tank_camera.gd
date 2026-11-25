extends GutTest
## T-278: the driven Sherman's third-person view (TankCamera, ShermanTank's driver, sherman.json "drive" cam_*): the
## boom's length kept in its range and the wheel's steps into and out of the gunner's sight, the orbit turned by the
## player's look and never by the hull, the spring arm, the aim point laying the turret, the sight's narrower view and
## slower look, and everything given back when the driver climbs out or is put out.


func _d() -> Dictionary:
	return ShermanEvent.table()["drive"]


func test_drive_config_has_the_camera() -> void:
	var d: Dictionary = _d()
	assert_almost_eq(float(d["cam_dist_min"]), 5.0, 0.01, "the shortest boom")
	assert_almost_eq(float(d["cam_dist_max"]), 16.0, 0.01, "the longest boom")
	assert_between(float(d["cam_dist_start"]), float(d["cam_dist_min"]), float(d["cam_dist_max"]))
	assert_gt(float(d["sniper_zoom"]), 1.5, "the sight magnifies")
	assert_lt(float(d["cam_pitch_min_deg"]), 0.0)
	assert_gt(float(d["cam_pitch_max_deg"]), 0.0)
	for v: Variant in d["cam_presets"]:
		assert_between(float(v), float(d["cam_dist_min"]), float(d["cam_dist_max"]), "a preset within the boom's range")


func test_boom_distance_clamp() -> void:
	var d: Dictionary = _d()
	assert_eq(TankCamera.clamp_dist(2.0, d), 5.0, "never shorter than cam_dist_min")
	assert_eq(TankCamera.clamp_dist(40.0, d), 16.0, "never longer than cam_dist_max")
	assert_eq(TankCamera.clamp_dist(9.5, d), 9.5)
	# the wheel out from the start, notch by notch, stops at the longest
	var dist: float = float(d["cam_dist_start"])
	for i: int in 20:
		dist = float(TankCamera.zoom(dist, false, -1, d)[0])
	assert_eq(dist, 16.0, "wheel out: the boom stops at its longest")
	# and in again stops at the shortest before the sight
	var r: Array = [dist, false]
	for i2: int in 12:
		r = TankCamera.zoom(float(r[0]), bool(r[1]), 1, d)
		if float(r[0]) <= 5.0:
			break
	assert_eq(float(r[0]), 5.0, "wheel in: down to the shortest boom")
	assert_false(bool(r[1]), "not yet in the sight")
	# the pad's presets go round
	assert_eq(TankCamera.next_preset(6.0, d), 9.0)
	assert_eq(TankCamera.next_preset(9.0, d), 14.0)
	assert_eq(TankCamera.next_preset(14.0, d), 6.0, "after the longest the shortest again")
	# the spring arm: in at once, out eased
	assert_eq(TankCamera.arm_step(9.0, 9.0, 3.0, 12.0, 0.016), 3.0, "a wall: the boom shortens at once")
	assert_almost_eq(TankCamera.arm_step(3.0, 9.0, 20.0, 12.0, 0.1), 4.2, 0.001, "clear again: it eases back out")
	assert_eq(TankCamera.arm_step(8.9, 9.0, 20.0, 12.0, 0.1), 9.0, "never past the length asked for")


func test_sniper_toggle_by_the_wheel() -> void:
	var d: Dictionary = _d()
	var r: Array = TankCamera.zoom(5.0, false, 1, d)
	assert_true(bool(r[1]), "wheel in at the shortest boom: the gunner's sight")
	r = TankCamera.zoom(5.0, true, 1, d)
	assert_true(bool(r[1]), "further in: still the sight")
	r = TankCamera.zoom(5.0, true, -1, d)
	assert_false(bool(r[1]), "wheel out: the orbit again")
	assert_eq(float(r[0]), 5.0, "at the shortest boom")
	r = TankCamera.zoom(9.0, false, 1, d)
	assert_false(bool(r[1]), "in from a long boom only shortens it")
	assert_eq(float(r[0]), 7.5)
	# the sight's view and look
	var f: float = TankCamera.sight_fov(80.0, d)
	assert_lt(f, 80.0 / 3.0, "x4: the view narrowed (%.1f degrees)" % f)
	assert_gt(f, 10.0)
	var m: float = TankCamera.sight_look_mult(80.0, d, 1.0)
	assert_almost_eq(m, tan(deg_to_rad(f) * 0.5) / tan(deg_to_rad(40.0)), 0.001, "the look slowed by the views' ratio")
	assert_almost_eq(TankCamera.sight_look_mult(80.0, d, 0.5), m * 0.5, 0.001, "times the ADS sensitivity setting")
	var pr: Vector2 = TankCamera.pitch_range(true, d)
	var po: Vector2 = TankCamera.pitch_range(false, d)
	assert_gt(po.y - po.x, deg_to_rad(40.0), "the orbit looks well down and a little up")
	assert_almost_eq(pr.y, deg_to_rad(25.0), 0.001, "the sight up to the gun's stop")


func test_orbit_independent_of_hull() -> void:
	var d: Dictionary = _d()
	var pitch: float = deg_to_rad(-15.0)
	var yaw: float = deg_to_rad(30.0)
	var a: Transform3D = TankCamera.orbit_transform(TankCamera.pivot_of(Vector3(3, 0, 4), 0.0, d), pitch, yaw, 9.0)
	var b: Transform3D = TankCamera.orbit_transform(TankCamera.pivot_of(Vector3(3, 0, 4), 2.1, d), pitch, yaw, 9.0)
	assert_true(a.basis.is_equal_approx(b.basis), "the hull turns under it: the view's heading is the player's")
	assert_lt(a.origin.distance_to(b.origin), 1.0, "the pivot only follows the turret ring (%.2f m)" % a.origin.distance_to(b.origin))
	# the camera is behind the pivot along the view and above it when the view looks down
	var pv: Vector3 = TankCamera.pivot_of(Vector3.ZERO, 0.0, d)
	assert_almost_eq(pv.y, ShermanMesh.TURRET_AT.y + float(d["cam_pivot_up"]), 0.001)
	var c: Transform3D = TankCamera.orbit_transform(pv, pitch, 0.0, 9.0)
	assert_almost_eq(c.origin.distance_to(pv), 9.0, 0.001, "on a boom of the asked length")
	assert_gt(c.origin.y, pv.y + 2.0, "looking down, the camera rides above the pivot")
	assert_gt(c.origin.z, pv.z + 7.0, "behind it (the view looks along -z)")
	var fwd: Vector3 = -c.basis.z
	assert_lt(fwd.normalized().angle_to((pv - c.origin).normalized()), 0.001, "it looks through the pivot")


func test_aim_point_to_turret_target() -> void:
	var g: Vector3 = Vector3(0, 2.3, 0)
	var lay: Vector2 = ShermanTank.lay_for(g, 0.0, Vector3(-20, 2.3, 0))
	assert_almost_eq(lay.x, PI * 0.5, 0.001, "a point to the left: the turret a quarter turn left")
	assert_almost_eq(lay.y, 0.0, 0.001)
	lay = ShermanTank.lay_for(g, PI * 0.5, Vector3(-20, 2.3, 0))
	assert_almost_eq(lay.x, 0.0, 0.001, "the hull already facing it: the turret straight ahead")
	lay = ShermanTank.lay_for(g, 0.0, Vector3(0, 2.3 + 10.0, -10.0))
	assert_almost_eq(lay.y, deg_to_rad(25.0), 0.001, "high up: the gun on its top stop")
	lay = ShermanTank.lay_for(g, 0.0, Vector3(0, 0.0, -3.0))
	assert_almost_eq(lay.y, deg_to_rad(-10.0), 0.001, "close under: the gun on its low stop")


## The rig on a floor with a local player: the orbit comes in over the climb, the look turns it and the hull does
## not, the screen centre lays the turret, the sight narrows the view, and climbing out gives everything back.
func test_rig_and_restore_on_exit() -> void:
	var tk: ShermanTank = ShermanTank.new()
	tk.setup(ShermanEvent.table()["tank"], ShermanEvent.table()["assist"], 8000.0, _d(), {})
	add_child_autofree(tk)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)
	var p: Player = Player.new()
	p.player_id = 1
	add_child_autofree(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.global_position = Vector3(2.6, 0.05, 0.5)
	await wait_physics_frames(3)
	var fov0: float = p.camera.fov
	var mask0: int = p.camera.cull_mask
	assert_true(p.camera.current, "first person to begin with")
	tk._board(p)
	assert_not_null(tk.cam, "the driver's machine has the orbit camera")
	assert_true(tk.cam.current, "it is the view")
	assert_eq(tk.cam.cull_mask & WeaponHolder.VM_LAYER, 0, "the viewmodel and the hands are not drawn")
	assert_true(p.carry_sight, "the HUD's crosshair gives way to the tank's sight")
	# the blend in: from the player's own camera to the orbit over mount_s
	tk.cam.update_view(0.0)
	assert_lt(tk.cam.global_position.distance_to(p.camera.global_position), 0.05, "it starts where the player's eye is")
	for i: int in 70:
		tk.cam.update_view(1.0 / 60.0)
	assert_almost_eq(tk.cam.blend, 1.0, 0.001, "blended in within the climb's time")
	var dist_now: float = tk.cam.global_position.distance_to(tk.cam._pivot())
	assert_almost_eq(dist_now, float(_d()["cam_dist_start"]), 0.05, "on the boom (%.2f m)" % dist_now)
	# the hull turns, the view does not
	var b0: Basis = tk.cam.global_basis
	tk.rotation.y += 1.2
	tk.cam.tick_physics()
	tk.cam.tick_physics()
	tk.cam.update_view(1.0 / 60.0)
	assert_true(tk.cam.global_basis.is_equal_approx(b0), "a turning hull leaves the orbit where it is")
	# the look turns it
	p.rotate_y(0.5)
	tk.cam.update_view(1.0 / 60.0)
	assert_false(tk.cam.global_basis.is_equal_approx(b0), "the player's look turns the orbit")
	# the screen centre lays the turret
	tk.seat = ShermanTank.Seat.SEATED
	var ap: Vector3 = tk._view_point(p)
	assert_eq(ap, tk.cam.aim_point, "the aim point is the orbit camera's screen centre")
	tk.aim_world(ap)
	var want: Vector2 = ShermanTank.lay_for(tk.gun.global_position, tk.global_rotation.y, ap)
	assert_almost_eq(tk.lay_target().x, want.x, 0.0001, "the turret is sent toward it")
	assert_almost_eq(tk.lay_target().y, want.y, 0.0001, "and the gun")
	# the wheel: in to the sight and out again
	for n: int in 6:
		tk.carry_wheel(1)
	assert_true(tk.cam.sniper, "the wheel all the way in: the gunner's sight")
	tk.cam.update_view(1.0 / 60.0)
	var base_fov: float = GLSettings.get_f("fov")
	assert_almost_eq(tk.cam.fov, TankCamera.sight_fov(base_fov, _d()), 0.01, "the sight's narrow view (%.1f of the player's %.0f degrees)" % [tk.cam.fov, base_fov])
	assert_lt(tk.cam.fov, base_fov / 2.5, "narrower than the orbit")
	assert_lt(p.carry_look_mult, 0.5, "the look slowed in the sight")
	assert_lt(tk.cam.global_position.distance_to(tk.gun.global_position), 1.0, "at the mantlet")
	tk.carry_wheel(-1)
	assert_false(tk.cam.sniper, "the wheel out leaves it")
	assert_eq(p.carry_look_mult, 1.0)
	# climbing out: blended back, then everything as it was
	tk.carry_wheel(1)
	tk.carry_wheel(1)
	var c: TankCamera = tk.cam
	tk._leave(p.global_position + Vector3(2, 0, 0), false)
	assert_true(c.leaving, "it blends back out")
	for i2: int in 50:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c.update_view(1.0 / 60.0)
	tk._finish_exit()
	await wait_frames(2)
	assert_true(p.camera.current, "the player's own camera is the view again")
	assert_eq(p.camera.fov, fov0, "their FOV untouched")
	assert_eq(p.camera.cull_mask, mask0, "their camera draws the viewmodel as before")
	assert_eq(p.carry_look_mult, 1.0, "their sensitivity as before")
	assert_almost_eq(p.carry_pitch_lim.y, deg_to_rad(88.0), 0.001, "their look's range as before")
	assert_false(p.carry_sight, "the HUD's crosshair is back")
	assert_null(p.carry, "out of the tank")
	assert_true(tk.cam == null or not is_instance_valid(tk.cam), "the orbit camera is gone")
	# put out (down in the hatch, the dive bomber): at once, no blend
	await wait_physics_frames(40)
	tk._board(p)
	assert_true(tk.cam.current)
	tk._leave(p.global_position + Vector3(2.5, 0, 0), true)   # (put_out's own step after it picked the spot)
	await wait_frames(2)
	assert_true(p.camera.current, "put out: the player's camera at once")
	assert_eq(p.carry_look_mult, 1.0)
	assert_false(p.carry_sight)
	assert_null(tk.cam, "no camera left")
