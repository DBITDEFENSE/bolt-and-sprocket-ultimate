extends GutTest
## UPDATE 10 s6 item 1 (T-162): zombies above 60 Hz. With Zombie.smooth_motion the Pivot is offset each rendered frame
## so the mesh shows the position interpolated between the tick's start and end; a teleport snaps; far zombies are not
## smoothed; switching it off puts the Pivot back; the setting is on by default and never on headless.

var _host: Node3D
var _spawn: ZombieSpawn
var _round_before: int


func before_each() -> void:
	seed(5)
	GLSettings.values["gore"] = "off"
	_round_before = RoundManager.current_round
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)
	Zombie.smooth_motion = false


func after_each() -> void:
	Zombie.smooth_motion = false
	RoundManager.current_round = _round_before


func _zombie() -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 400.0, "variant": "villager"}, _spawn, null)
	z.global_position = Vector3.ZERO
	z._enter(Zombie.State.CHASE)
	return z


func test_default_on_and_headless_off() -> void:
	var fresh: GDScript = load("res://gravelight/autoload/settings.gd") as GDScript
	var inst: Node = fresh.new()
	assert_true(bool((inst.get("values") as Dictionary).get("zombie_smooth", false)), "zombie_smooth is on by default")
	inst.free()
	assert_false(Zombie.smooth_motion, "the flag is off here (headless)")


func test_the_pivot_leads_back_by_the_unfinished_part_of_the_tick() -> void:
	var z: Zombie = _zombie()
	Zombie.smooth_motion = true
	z._tick_prev = Vector3.ZERO
	z.global_position = Vector3(0.1, 0, 0)   # the tick moved it 10 cm along +x
	var base: Vector3 = z._pivot.position
	z._smooth_visual(true)
	# Engine.get_physics_interpolation_fraction() is 0 outside a frame loop here: the visual sits at the tick's start
	var off: Vector3 = z._pivot.position - base
	var frac: float = Engine.get_physics_interpolation_fraction()
	var want: Vector3 = z.global_basis.inverse() * (Vector3(-0.1, 0, 0) * (1.0 - frac))
	assert_almost_eq(off.x, want.x, 0.0001)
	assert_almost_eq(off.z, want.z, 0.0001)
	assert_lte(absf(off.x), 0.1001, "never more than a tick of travel")


func test_a_teleport_snaps() -> void:
	var z: Zombie = _zombie()
	Zombie.smooth_motion = true
	z._tick_prev = Vector3.ZERO
	z.global_position = Vector3(5, 0, 0)
	z._smooth_visual(true)
	assert_eq(z._smooth_off, Vector3.ZERO, "a jump over 2 m is not smoothed")


func test_far_zombies_and_the_switch_clear_the_offset() -> void:
	var z: Zombie = _zombie()
	Zombie.smooth_motion = true
	z._tick_prev = Vector3.ZERO
	z.global_position = Vector3(0.1, 0, 0)
	var base: Vector3 = z._pivot.position
	z._smooth_visual(true)
	if z._smooth_off == Vector3.ZERO:
		z._tick_prev = Vector3(-1.0, 0, 0)   # (a fraction of 1 would hide the offset: make sure there is one)
		z.global_position = Vector3(-0.9, 0, 0)
		z._smooth_visual(true)
	z._smooth_visual(false)
	assert_eq(z._smooth_off, Vector3.ZERO, "beyond the full-rate distance the offset is removed")
	assert_almost_eq(z._pivot.position.x, base.x, 0.0001, "and the Pivot is back where it was")
	Zombie.smooth_motion = false
	z._smooth_visual(true)
	assert_eq(z._smooth_off, Vector3.ZERO, "switched off: no offset")


func test_the_pivot_move_of_a_state_is_kept() -> void:
	var z: Zombie = _zombie()
	Zombie.smooth_motion = true
	z._tick_prev = Vector3.ZERO
	z.global_position = Vector3(0.1, 0, 0)
	z._smooth_visual(true)
	z._pivot.position.y = -1.0   # a state sinks the Pivot (the Foreman rising, a crawler)
	z._smooth_visual(false)
	assert_almost_eq(z._pivot.position.y, -1.0, 0.0001, "the delta approach leaves other moves alone")


func test_the_face_and_the_posing_share_the_animation_lod() -> void:
	var n: Node3D = Node3D.new()
	_host.add_child(n)
	assert_eq(PatronBody.lod_div(n), 1, "no camera: every frame")
	var cam: Camera3D = Camera3D.new()
	_host.add_child(cam)
	cam.make_current()
	n.global_position = cam.global_position + Vector3(0, 0, -3)
	assert_eq(PatronBody.lod_div(n), 1, "near: every frame")
	n.global_position = cam.global_position + Vector3(0, 0, -(30.0 * Zombie.anim_lod_scale))
	assert_eq(PatronBody.lod_div(n), 2, "mid: every 2nd frame")
	n.global_position = cam.global_position + Vector3(0, 0, -(80.0 * Zombie.anim_lod_scale))
	assert_eq(PatronBody.lod_div(n), 4, "far: every 4th frame")
