extends GutTest
## The gadget framework (bs/gadgets) and the Tether-Hook: ownership flags and the belt, the "gadget" input,
## targeting (16 m range, 30° cone, line of sight, Scrapheap's gadget_points markers), the swing (rope clamp,
## constraint, pumping, speed cap, release velocity + 4 up with double jump and hover ready, landing), pull
## points (reel, mantle onto the ledge), the 0.25 s re-fire and the body takeover hand-back.

const PROFILE: String = "user://test_bs_rustvane_gadgets_profile.json"

var _saved_path: String
var _saved_doc: Dictionary
var _world: Node3D


func before_all() -> void:
	_saved_path = SaveProfile.path
	_saved_doc = SaveProfile.doc.duplicate(true)
	SaveProfile.path = PROFILE


func after_all() -> void:
	SaveProfile.path = _saved_path
	SaveProfile.doc = _saved_doc
	BS.load_from_profile()
	BS.god_mode = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func before_each() -> void:
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.god_mode = true
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	BS.god_mode = false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _wait(cond: Callable, n: int) -> bool:
	for i: int in n:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _bolt_at(p: Vector3) -> Bolt:
	var b: Bolt = Bolt.new()
	b.position = p
	_world.add_child(b)
	b.scripted = {"dir": Vector3.ZERO}
	return b


func _ring(p: Vector3, kind: StringName = TetherPoint.SWING, land: Vector3 = Vector3(0, 1.4, 0)) -> TetherPoint:
	var t: TetherPoint = TetherPoint.new()
	t.kind = kind
	t.land_offset = land
	t.position = p
	_world.add_child(t)
	return t


func _hooked(b: Bolt) -> TetherHook:
	GadgetManager.grant(&"tether_hook")
	var m: GadgetManager = GadgetManager.attach_to(b)
	return m.get_gadget(&"tether_hook") as TetherHook


func _def() -> Dictionary:
	return ((Data.table("bs/gadgets") as Dictionary)["gadgets"] as Dictionary)["tether_hook"]


# ------------------------------------------------------------------ framework

func test_data_tuning_matches_bs_levels() -> void:
	var d: Dictionary = _def()
	assert_eq(float(d["acquire_range"]), 16.0)
	assert_eq(float(d["acquire_cone_deg"]), 30.0)
	assert_eq([float(d["rope_min"]), float(d["rope_max"])], [5.0, 14.0])
	assert_eq(float(d["swing_gravity"]), 38.0, "swing gravity = jump.fallGrav")
	assert_eq(float(d["pump_accel"]), 6.0)
	assert_eq(float(d["max_swing_speed"]), 18.0)
	assert_eq(float(d["release_up"]), 4.0)
	assert_eq(float(d["pull_speed"]), 20.0)
	assert_eq(float(d["pull_hop"]), 6.0)
	assert_eq(float(d["refire"]), 0.25)


func test_belt_ownership_and_attach_is_idempotent() -> void:
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var m: GadgetManager = GadgetManager.attach_to(b)
	assert_eq(GadgetManager.attach_to(b), m, "one belt per Bolt")
	assert_eq(m.name, "Gadgets")
	assert_null(m.get_gadget(&"tether_hook"), "not owned yet")
	assert_false(m.press(), "nothing to press")
	GadgetManager.grant(&"tether_hook")
	assert_true(BS.flag("gadget.tether_hook"), "BS.flags[gadget.<id>] marks ownership")
	assert_true(SaveProfile.is_unlocked("bs.gadget.tether_hook"))
	assert_true(m.get_gadget(&"tether_hook") is TetherHook, "grant adds it to live belts")
	assert_eq(m.primary(), m.get_gadget(&"tether_hook"))
	assert_true(InputMap.has_action(&"gadget"), "input action 'gadget' exists")


func test_owned_gadget_is_on_a_new_belt() -> void:
	BS.set_flag("gadget.tether_hook")
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var m: GadgetManager = GadgetManager.attach_to(b)
	await _frames(1)
	assert_not_null(m.get_gadget(&"tether_hook"), "loaded from the save flag")


func test_gadget_lines_registered() -> void:
	GadgetManager.register_lines()
	for id: String in ["bs.gadget.tether.weight.01", "bs.gadget.tether.no_target", "bs.gadget.tether.how"]:
		assert_true(VOManager.has_line(id), id)


# ------------------------------------------------------------------ targeting

func test_acquire_range_cone_and_los() -> void:
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var h: TetherHook = _hooked(b)
	await _frames(2)
	b.motor.yaw = 0.0           # no camera: aim straight down +z
	var near: TetherPoint = _ring(Vector3(0, 3, 8))
	await _frames(1)
	assert_eq(h.acquire(), near, "in range, in the cone")
	near.enabled = false
	assert_null(h.acquire(), "disabled rings are skipped")
	near.enabled = true
	near.position = Vector3(0, 3, 17.5)
	await _frames(1)
	assert_null(h.acquire(), "beyond 16 m")
	near.position = Vector3(8, 1.5, 8)
	await _frames(1)
	assert_null(h.acquire(), "45° off the aim line is outside the 30° cone")
	near.position = Vector3(0, 1.5, 9)
	LevelKit.box(_world, Vector3(0, 1.5, 4.5), Vector3(4, 4, 0.4), "#444444", true)
	await _frames(2)
	assert_null(h.acquire(), "a wall blocks line of sight")


func test_scrapheap_gadget_point_markers_count() -> void:
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var h: TetherHook = _hooked(b)
	var mk: Marker3D = Marker3D.new()
	mk.position = Vector3(0, 3, 8)
	mk.add_to_group(&"gadget_points")
	mk.set_meta(&"kind", "tether")
	_world.add_child(mk)
	await _frames(2)
	assert_eq(h.acquire(), mk, "LevelDirector gadget_points with kind 'tether' (Scrapheap's blimp ring) are rings")


func test_no_target_press_hints() -> void:
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var h: TetherHook = _hooked(b)
	var hints: Array = []
	var cb: Callable = func(_t: String, k: String) -> void: hints.append(k)
	EventBus.hint.connect(cb)
	await _frames(1)
	assert_false(h.press())
	EventBus.hint.disconnect(cb)
	assert_true("tether_no_target" in hints)


# ------------------------------------------------------------------ swing

func _swing_rig() -> Array:
	LevelKit.box(_world, Vector3(0, -30.5, 0), Vector3(200, 1, 200), "#333333", true)   # far below
	var b: Bolt = _bolt_at(Vector3(0, 10, 0))
	var h: TetherHook = _hooked(b)
	var r: TetherPoint = _ring(Vector3(0, 16, 6))
	return [b, h, r]


func test_swing_rope_clamp_and_constraint() -> void:
	var rig: Array = _swing_rig()
	var b: Bolt = rig[0]
	var h: TetherHook = rig[1]
	var r: TetherPoint = rig[2]
	await _frames(2)
	h.attach(r)
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20))
	var d0: float = b.global_position.distance_to(r.global_position)
	assert_almost_eq(h.rope_target, clampf(d0, 5.0, 14.0), 0.3, "rope = attach distance clamped 5..14")
	assert_false(b.is_physics_processing(), "the hook owns the body")
	var maxd: float = 0.0
	var maxv: float = 0.0
	for i: int in 120:
		await get_tree().physics_frame
		maxd = maxf(maxd, b.global_position.distance_to(r.global_position) - h.rope)
		maxv = maxf(maxv, h.vel.length())
	assert_lt(maxd, 0.05, "Bolt never leaves the rope's sphere")
	assert_lte(maxv, 18.01, "swing speed capped at 18 m/s")
	assert_gt(maxv, 5.0, "it actually swings")


func test_far_ring_reels_rope_to_14() -> void:
	LevelKit.box(_world, Vector3(0, -30.5, 0), Vector3(200, 1, 200), "#333333", true)
	var b: Bolt = _bolt_at(Vector3(0, 0, 0))
	var h: TetherHook = _hooked(b)
	var r: TetherPoint = _ring(Vector3(0, 11, 10.5))
	await _frames(2)
	h.attach(r)
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20))
	assert_almost_eq(h.rope_target, 14.0, 0.01, "15 m away: the rope clamps to 14")
	await _frames(30)
	assert_almost_eq(h.rope, 14.0, 0.01, "and reels in to it")


func test_pumping_adds_energy() -> void:
	var speeds: Array[float] = []
	var root: Node3D = _world
	for pump: bool in [false, true]:
		_world = Node3D.new()
		root.add_child(_world)
		var rig: Array = _swing_rig()
		var b: Bolt = rig[0]
		var h: TetherHook = rig[1]
		await _frames(2)
		h.attach(rig[2])
		await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20)
		b.scripted = {"dir": Vector3(0, 0, 1) if pump else Vector3.ZERO}
		var e: float = 0.0
		for i: int in 90:
			await get_tree().physics_frame
			e = maxf(e, b.global_position.y)
		speeds.append(e)
		h.cancel()
		_world.queue_free()
		await _frames(1)
	_world = root
	assert_gt(speeds[1], speeds[0] + 0.3, "pumping toward the swing raises the arc (%.2f vs %.2f)" % [speeds[1], speeds[0]])


func test_release_rule_and_refire() -> void:
	var rig: Array = _swing_rig()
	var b: Bolt = rig[0]
	var h: TetherHook = rig[1]
	await _frames(2)
	h.attach(rig[2])
	await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20)
	await _frames(20)
	var v: Vector3 = h.vel
	b.scripted["jump_pressed"] = true
	await _frames(1)
	assert_eq(h.state, TetherHook.State.IDLE, "jump lets go")
	assert_almost_eq(h.last_release_vel.y, v.y + 4.0, 1.0, "keeps velocity, adds 4 m/s up")
	assert_true(b.is_physics_processing(), "Bolt's own movement is back")
	assert_eq(b.motor.jumps, 1, "double jump ready")
	assert_almost_eq(b.motor.hover, 1.0, 0.01, "hover ready")
	assert_false(b.motor.air_dash_used)
	assert_false(h.press(), "0.25 s re-fire")
	await _frames(20)
	assert_true(h.cd <= 0.0, "re-fire ready again")


func test_press_toggles_release() -> void:
	var rig: Array = _swing_rig()
	var h: TetherHook = rig[1]
	await _frames(2)
	h.attach(rig[2])
	await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20)
	assert_true(h.press(), "pressing again lets go")
	assert_eq(h.state, TetherHook.State.IDLE)


func test_swing_touchdown_lets_go() -> void:
	LevelKit.box(_world, Vector3(0, -0.5, 0), Vector3(60, 1, 60), "#555555", true)
	var b: Bolt = _bolt_at(Vector3(0, 3, 0))
	var h: TetherHook = _hooked(b)
	var r: TetherPoint = _ring(Vector3(0, 6, 4))
	await _frames(2)
	h.attach(r)
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.IDLE, 120), "landing ends the swing")
	await _frames(10)
	assert_true(b.motor.on_ground, "standing")


# ------------------------------------------------------------------ pull

func test_pull_reels_and_mantles_onto_the_ledge() -> void:
	LevelKit.box(_world, Vector3(0, -0.5, 0), Vector3(60, 1, 60), "#555555", true)
	LevelKit.box(_world, Vector3(6, 5, 0), Vector3(4, 10, 6), "#7a4c3a", true)          # ledge x 4..8, top 10
	var b: Bolt = _bolt_at(Vector3(-4, 1, 0))
	var h: TetherHook = _hooked(b)
	var r: TetherPoint = _ring(Vector3(3.7, 10.3, 0), TetherPoint.PULL, Vector3(-0.9, 0.9, 0))
	await _frames(6)
	h.attach(r)
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.PULL, 20), "green ring pulls")
	var max_speed: float = 0.0
	while h.state == TetherHook.State.PULL:
		await get_tree().physics_frame
		max_speed = maxf(max_speed, h.vel.length())
	assert_almost_eq(max_speed, 20.0, 0.5, "reels at 20 m/s")
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.IDLE, 90), "mantle finishes")
	assert_true(await _wait(func() -> bool: return b.motor.on_ground, 60))
	assert_almost_eq(b.global_position.y - b.motor.hy, 10.0, 0.1, "stands on the ledge")
	assert_gt(b.global_position.x, 4.0, "over the lip")
	assert_eq(h.pulls, 1)


func test_pull_without_lip_offset_hops() -> void:
	LevelKit.box(_world, Vector3(0, -0.5, 0), Vector3(60, 1, 60), "#555555", true)
	var b: Bolt = _bolt_at(Vector3(0, 1, 0))
	var h: TetherHook = _hooked(b)
	var r: TetherPoint = _ring(Vector3(0, 9, 6), TetherPoint.PULL, Vector3(0, 0, 0))
	await _frames(6)
	h.attach(r)
	assert_true(await _wait(func() -> bool: return h.state == TetherHook.State.IDLE and h.last_release_vel != Vector3.ZERO, 120))
	assert_almost_eq(h.last_release_vel.y, 6.0, 0.01, "6 m/s hop at the end of the reel")


func test_cancel_hands_the_body_back() -> void:
	var rig: Array = _swing_rig()
	var b: Bolt = rig[0]
	var h: TetherHook = rig[1]
	await _frames(2)
	h.attach(rig[2])
	await _wait(func() -> bool: return h.state == TetherHook.State.SWING, 20)
	assert_false(Gadget.body_free(b))
	h.cancel()
	assert_true(Gadget.body_free(b) and b.is_physics_processing())
