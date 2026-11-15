extends GutTest
## The movement + frame-rate pass (docs/perf/movement_perf_2026-11.md).
## Movement: the camera's and the viewmodel's springs answer the same at 30 / 60 / 144 / 240 frames a second
## (TickSpring) and are the old code step for step at 60; the FOV and bob eases are one curve at every rate; the
## pad's stick turns the view by the frame's time; the gun's look sway reads the frame's own turn.
## Performance: the zombies' leap-hop gate never hides a due hop, the wedge check asks the navmesh five times a
## second and still recycles at 3 s, and a body's severed pieces cut ahead of time on a worker thread are the
## meshes the on-the-spot cut makes.

const TickSpring: GDScript = preload("res://gravelight/player/tick_spring.gd")
const DT: float = 1.0 / 60.0

var _host: Node3D


class WedgeZombie extends Zombie:
	var looks: int = 0
	var height: float = 2.0

	func _off_navmesh_height() -> float:
		looks += 1
		return height


func before_all() -> void:
	GLSettings.apply_bindings()   # (the look and lean actions exist only once applied)


func before_each() -> void:
	GameState.gravity_scale = 1.0
	_host = Node3D.new()
	add_child_autofree(_host)


func after_each() -> void:
	Input.action_release(&"look_right")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ================================================================== TickSpring

## The spring the camera and the viewmodel used before: one explicit Euler step of the whole frame time.
func _old_step(x: Vector2, v: Vector2, target: Vector2, w: float, z: float, dt: float) -> Array:
	v += ((target - x) * w * w - v * 2.0 * z * w) * dt
	x += v * dt
	return [x, v]


## The peak of |shown x| after an impulse, stepping the spring with frames of `fdt` for `secs`.
func _peak(w: float, z: float, impulse: float, fdt: float, secs: float) -> float:
	var x: float = 0.0
	var v: float = impulse
	var acc: float = 0.0
	var peak: float = 0.0
	for i: int in int(secs / fdt):
		var r: Array = TickSpring.advance(x, v, 0.0, w, z, acc, fdt)
		x = r[0]
		v = r[1]
		acc = r[2]
		peak = maxf(peak, absf(float(r[3])))
	return peak


func test_tick_spring_is_the_old_step_at_60() -> void:
	var x: Vector2 = Vector2.ZERO
	var v: Vector2 = Vector2(3.0, -1.0)
	var ox: Vector2 = x
	var ov: Vector2 = v
	var acc: float = 0.0
	var target: Vector2 = Vector2(0.02, 0.0)
	for i: int in 90:
		var r: Array = TickSpring.advance(x, v, target, 13.0, 0.55, acc, DT)
		x = r[0]
		v = r[1]
		acc = r[2]
		var o: Array = _old_step(ox, ov, target, 13.0, 0.55, DT)
		ox = o[0]
		ov = o[1]
		assert_almost_eq((r[3] as Vector2).x, ox.x, 0.0000001, "step %d: the shown value is the old code's" % i)
		assert_almost_eq((r[3] as Vector2).y, ox.y, 0.0000001)
		assert_eq(acc, 0.0, "a 60 Hz frame leaves no part-step")


func test_tick_spring_peaks_the_same_at_every_frame_rate() -> void:
	for wz: Array in [[10.0, 1.0], [22.0, 1.0], [20.0, 0.55]]:
		var w: float = wz[0]
		var z: float = wz[1]
		var p60: float = _peak(w, z, 1.0, 1.0 / 60.0, 1.5)
		assert_gt(p60, 0.0)
		for fps: float in [30.0, 72.0, 144.0, 240.0, 500.0]:
			var p: float = _peak(w, z, 1.0, 1.0 / fps, 1.5)
			# never above the 60 Hz peak; a frame may fall beside the one step that holds it (a stiff spring's peak
			# lasts one step: 30 FPS draws every other step, 72 FPS lands between two)
			assert_between(p / p60, 0.93, 1.0001, "w %.0f z %.2f at %.0f FPS peaks where 60 FPS does" % [w, z, fps])
		# what it replaced: the same spring stepped with the frame's own time peaked far higher at 240
		var ox: Vector2 = Vector2.ZERO
		var ov: Vector2 = Vector2(1.0, 0.0)
		var old_peak: float = 0.0
		for i: int in 360:
			var o: Array = _old_step(ox, ov, Vector2.ZERO, w, z, 1.0 / 240.0)
			ox = o[0]
			ov = o[1]
			old_peak = maxf(old_peak, absf(ox.x))
		assert_gt(old_peak / p60, 1.2, "(the old per-frame step at 240 FPS: %.2f x the 60 FPS peak)" % (old_peak / p60))


func test_tick_spring_moves_every_frame_and_survives_a_long_frame() -> void:
	var x: float = 0.0
	var v: float = 1.0
	var acc: float = 0.0
	var last: float = 0.0
	var moved: int = 0
	for i: int in 24:   # 0.1 s at 240 FPS: the shown value changes in every frame, not every fourth
		var r: Array = TickSpring.advance(x, v, 0.0, 12.0, 1.0, acc, 1.0 / 240.0)
		x = r[0]
		v = r[1]
		acc = r[2]
		if absf(float(r[3]) - last) > 0.0000001:
			moved += 1
		last = float(r[3])
		assert_between(acc, 0.0, TickSpring.H, "the part-step stays inside one step")
	assert_eq(moved, 24, "shown per rendered frame")
	var long: Array = TickSpring.advance(0.5, 3.0, 0.0, 22.0, 1.0, 0.0, 2.0)   # a 2 s hitch
	assert_true(is_finite(float(long[0])) and absf(float(long[0])) < 1.0, "no blow-up after a hitch")
	assert_between(float(long[2]), 0.0, TickSpring.H)


# ================================================================== the player's camera

func _player() -> Player:
	var p: Player = Player.new()
	p.bot_driven = true   # (no input read by its own tick; the camera code is the same)
	_host.add_child(p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return p


## The recoil kick's shown peak (degrees) with the camera updated every `fdt` seconds.
func _kick_peak(p: Player, recover: float, fdt: float) -> float:
	p.set("_rk", Vector2.ZERO)
	p.set("_rk_v", Vector2.ZERO)
	p.set("_rk_acc", 0.0)
	p.kick_camera(3.0, 0.0, 0.0, recover, 0.0, 0.0)
	var peak: float = 0.0
	for i: int in int(1.0 / fdt):
		p.call("_update_camera", fdt)
		peak = maxf(peak, rad_to_deg((p.get("_rk_show") as Vector2).x))
	return peak


func test_recoil_kick_and_landing_dip_do_not_grow_with_the_frame_rate() -> void:
	var p: Player = _player()
	for recover: float in [10.0, 22.0]:
		var k60: float = _kick_peak(p, recover, 1.0 / 60.0)
		assert_gt(k60, 0.5)
		for fps: float in [30.0, 144.0, 240.0]:
			assert_between(_kick_peak(p, recover, 1.0 / fps) / k60, 0.95, 1.0001, "recover %.0f: the kick at %.0f FPS is the 60 FPS kick" % [recover, fps])
	var dips: Array = []
	for fps: float in [60.0, 240.0]:
		p.set("_land_dip", 0.0)
		p.set("_land_dip_v", 0.0)
		p.set("_land_acc", 0.0)
		p.land_dip(7.0)
		var deep: float = 0.0
		for i: int in int(1.0 * fps):
			p.call("_update_camera", 1.0 / fps)
			deep = maxf(deep, -float(p.get("_land_show")))
		dips.append(deep)
	assert_gt(float(dips[0]), 0.01, "a 7 m/s landing dips the head")
	assert_between(float(dips[1]) / float(dips[0]), 0.97, 1.0001, "the same depth at 240 FPS as at 60")


func test_eases_are_one_curve_at_every_frame_rate() -> void:
	assert_almost_eq(Player._ease60(12.0, DT), 12.0 / 60.0, 0.000001, "at 60 FPS the weight is rate / 60, as before")
	assert_almost_eq(Player._ease60(8.0, DT), 8.0 / 60.0, 0.000001)
	for rate: float in [8.0, 12.0]:
		var left60: float = pow(1.0 - Player._ease60(rate, DT), 60.0)           # what is left after 1 s at 60 FPS
		for fps: float in [30.0, 144.0, 240.0]:
			var left: float = pow(1.0 - Player._ease60(rate, 1.0 / fps), fps)
			assert_almost_eq(left, left60, 0.000001, "rate %.0f: the same share left after a second at %.0f FPS" % [rate, fps])
	assert_eq(Player._ease60(600.0, DT), 1.0, "a rate past one tick snaps, never overshoots")


func test_the_pad_turns_by_the_frame_time() -> void:
	var p: Player = _player()
	Input.action_press(&"look_right", 1.0)
	p.rotation.y = 0.0
	p.call("_pad_look", DT, false)                    # one tick's turn
	var tick_turn: float = p.rotation.y
	assert_lt(tick_turn, -0.001, "the stick turns the view")
	p.rotation.y = 0.0
	for i: int in 4:
		p.call("_pad_look", DT / 4.0, true)           # the same sixtieth of a second in four 240 Hz frames
	assert_almost_eq(p.rotation.y, tick_turn, 0.00001, "four 240 Hz frames turn what one 60 Hz tick does")
	Input.action_release(&"look_right")
	p.rotation.y = 0.0
	p.call("_pad_look", DT, true)
	assert_eq(p.rotation.y, 0.0, "a centred stick does not turn")


func test_frame_look_is_taken_once() -> void:
	var p: Player = _player()
	p.set_smooth_view(true)
	Input.action_press(&"look_right", 1.0)
	p.call("_pad_look", DT, true)
	var l: Vector2 = p.take_frame_look()
	assert_almost_eq(l.x, 8.0, 0.001, "the stick's sway input: 8 a tick at full deflection, by the frame's time")
	assert_eq(p.take_frame_look(), Vector2.ZERO, "taken once")
	p.set_smooth_view(false)
	p.call("_pad_look", DT, false)
	assert_eq(p.take_frame_look(), Vector2.ZERO, "nothing is kept for a viewmodel that animates on the tick")


## The gun's look sway under a steady turn (mouse counts a second), the viewmodel animated every 1 / fps.
func _sway_at(p: Player, counts_per_s: float, fps: float) -> float:
	var h: WeaponHolder = p.weapons
	h.set("_sway", Vector2.ZERO)
	h.set("_sway_v", Vector2.ZERO)
	h.set("_sway_acc", 0.0)
	h.set("_look_in", Vector2.ZERO)
	p.take_frame_look()
	var s: float = 0.0
	for i: int in int(1.0 * fps):
		p.set("_look_frame", Vector2(counts_per_s / fps, 0.0))   # (what the mouse handler adds in one frame)
		h._process(1.0 / fps)
		s = absf((h.get("_sway_show") as Vector2).x)
	return s


func test_gun_sway_is_the_same_at_every_frame_rate() -> void:
	var p: Player = _player()
	p.bot_driven = false                 # the human's viewmodel, animated per rendered frame
	p.set_physics_process(false)         # (this test steps the viewmodel itself)
	p.set_process(false)
	p.weapons.set_physics_process(false)
	p.weapons.set_process(false)
	p.set_smooth_view(true)
	assert_true(p.weapons.call("_per_frame"), "the local human's viewmodel animates per frame with smooth motion")
	var s60: float = _sway_at(p, 1400.0, 60.0)       # about 180 degrees a second at the default sensitivity
	assert_gt(s60, 0.02, "a fast turn drags the gun")
	for fps: float in [30.0, 144.0, 240.0]:
		assert_almost_eq(_sway_at(p, 1400.0, fps) / s60, 1.0, 0.03, "the sway at %.0f FPS is the 60 FPS sway" % fps)
	p.set_smooth_view(false)


# ================================================================== zombies: the chase's avoidable work

func test_the_hop_gate_never_hides_a_due_hop() -> void:
	var hc: Dictionary = Zombie.hop_cfg()
	if hc.is_empty():
		hc = {"max_gravity_scale": 0.7, "range_min": 5.0, "range_max": 8.0}
	var due: int = 0
	for g: float in [0.17, 0.38, 0.7, 1.0]:
		for kind: bool in [true, false]:
			for floor_: bool in [true, false]:
				for dist: float in [2.0, 5.0, 6.5, 8.0, 12.0]:
					for crawler: bool in [true, false]:
						for cd: float in [0.0, 2.0]:
							var gate: bool = Zombie.hop_due(g, kind, floor_, dist, true, false, crawler, cd, hc)
							for clear: bool in [true, false]:
								for vac: bool in [true, false]:
									var full: bool = Zombie.hop_due(g, kind, floor_, dist, clear, vac, crawler, cd, hc)
									if full:
										due += 1
										assert_true(gate, "a due hop passes the cheap gate")
									if not gate:
										assert_false(full, "a shut gate means no hop whatever the rays say")
	assert_gt(due, 0, "the grid has due hops in it")
	assert_false(Zombie.hop_due(1.0, true, true, 6.5, true, false, false, 0.0, hc), "at 1 g the gate is shut: no ray is cast for a hop")


func test_the_wedge_check_looks_five_times_a_second_and_keeps_its_three_seconds() -> void:
	var z: WedgeZombie = WedgeZombie.new()
	var ticks: int = 0
	while not z._wedged(DT) and ticks < 600:
		ticks += 1
	assert_between(float(ticks) * DT, 3.0, 3.0 + 2.0 * Zombie.WEDGE_CHECK_S, "a wedged body is recycled 3 s on (within one look)")
	assert_lt(z.looks, ticks / 6, "the navmesh is asked a few times a second, not every tick (%d looks in %d ticks)" % [z.looks, ticks])
	# free again at any look: the clock starts over
	z.looks = 0
	for i: int in 150:
		assert_false(z._wedged(DT), "2.5 s wedged: not yet")
	z.height = 0.2
	for i: int in 30:
		assert_false(z._wedged(DT))
	z.height = 2.0
	for i: int in 150:
		assert_false(z._wedged(DT), "wedged again for 2.5 s: the first spell does not count")
	z.height = 0.2
	for i: int in 600:
		assert_false(z._wedged(DT), "on the floor: never")
	z.free()


# ================================================================== zombies: the severed pieces, cut ahead

func _mesh_arrays_equal(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for si: int in a.get_surface_count():
		var aa: Array = a.surface_get_arrays(si)
		var ba: Array = b.surface_get_arrays(si)
		for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX, Mesh.ARRAY_TEX_UV]:
			if aa[slot] != ba[slot]:
				return false
		if a.surface_get_name(si) != b.surface_get_name(si) or a.surface_get_material(si) != b.surface_get_material(si):
			return false
	return true


func test_pieces_cut_ahead_are_the_on_the_spot_pieces() -> void:
	if not ZombieBody.base_parts("medium", false).has("Body"):
		pass_test("no built body GLB in this checkout: the procedural pieces are not cut from a skinned mesh")
		return
	var kit: String = "villager"
	var bkey: String = ZombieBody._cache_key(kit, "medium", false)
	# a clean slate for this body, whatever ran before
	while ZombieBody.pieces_warming():
		await wait_frames(1)
	ZombieBody._piece_queued.erase(bkey)
	for bone: String in ZombieBody.PIECE_BONES:
		ZombieBody._meshes.erase("piece:%s:%s" % [bkey, bone])
		ZombieBody._piece_cuts.erase("piece:%s:%s" % [bkey, bone])
	var body: ArrayMesh = ZombieBody.build_skinned(kit, "medium", false)
	ZombieBody.piece_warm = true
	ZombieBody.warm_pieces(kit, "medium", false)
	var waited: int = 0
	while ZombieBody.pieces_warming() and waited < 600:
		await wait_frames(1)
		waited += 1
	assert_false(ZombieBody.pieces_warming(), "the worker finished (%d frames)" % waited)
	assert_eq(ZombieBody._piece_cuts.size() >= ZombieBody.PIECE_BONES.size(), true, "ten cuts are waiting")
	for bone: String in ZombieBody.PIECE_BONES:
		var key: String = "piece:%s:%s" % [bkey, bone]
		assert_true(ZombieBody._piece_cuts.has(key), "%s was cut ahead" % bone)
		var warmed: ArrayMesh = ZombieBody.piece_mesh(kit, "medium", false, bone)
		assert_false(ZombieBody._piece_cuts.has(key), "%s: the cut is taken once, the mesh is cached" % bone)
		assert_same(ZombieBody.piece_mesh(kit, "medium", false, bone), warmed)
		var spot: ArrayMesh = ZombieBody._cut_piece(body, bone)
		assert_gt(warmed.get_surface_count(), 0, "%s has geometry" % bone)
		assert_true(_mesh_arrays_equal(warmed, spot), "%s: the piece cut ahead is the piece cut on the spot" % bone)
	# queued once per body kind
	ZombieBody.warm_pieces(kit, "medium", false)
	assert_false(ZombieBody.pieces_warming(), "a body is handed to a worker once")


func test_a_piece_asked_for_before_its_cut_is_cut_on_the_spot() -> void:
	if not ZombieBody.base_parts("thin", false).has("Body"):
		pass_test("no built body GLB in this checkout")
		return
	var kit: String = "villager"
	var bkey: String = ZombieBody._cache_key(kit, "thin", false)
	while ZombieBody.pieces_warming():
		await wait_frames(1)
	ZombieBody._piece_queued.erase(bkey)
	var key: String = "piece:%s:LeftLowerArm" % bkey
	ZombieBody._meshes.erase(key)
	ZombieBody._piece_cuts.erase(key)
	ZombieBody.piece_warm = false
	ZombieBody.warm_pieces(kit, "thin", false)
	assert_false(ZombieBody._piece_queued.has(bkey), "off: nothing is handed to a worker")
	var m: ArrayMesh = ZombieBody.piece_mesh(kit, "thin", false, "LeftLowerArm")
	assert_gt(m.get_surface_count(), 0, "the piece is there at once")
	ZombieBody.piece_warm = true


func test_warm_up_builds_every_body_a_kit_can_spawn() -> void:
	var kits: Dictionary = GLData.table("anim")["kits"]
	var checked: int = 0
	for k: String in ["villager", "labstaff", "dockworker"]:
		var row: Dictionary = kits[k]
		assert_gt(float(row.get("female", 0.0)), 0.0, "%s spawns women" % k)
		for b: Variant in row["builds"]:
			ZombieBody._meshes.erase("skinned:" + ZombieBody._cache_key(k, str(b), true))
		ZombieBody.warm_up(PackedStringArray([k]))
		for b: Variant in row["builds"]:
			for female: bool in [false, true]:
				assert_true(ZombieBody._meshes.has("skinned:" + ZombieBody._cache_key(k, str(b), female)),
					"%s %s %s is built at load, not in the tick that first spawns one" % [k, str(b), "woman" if female else "man"])
				checked += 1
	assert_gt(checked, 10)
	while ZombieBody.pieces_warming():
		await wait_frames(1)


# ================================================================== bodies merged and cut on worker threads

func test_a_dressed_body_merged_ahead_is_the_body_merged_on_the_spot() -> void:
	if not ZombieBody.base_parts("medium", false, true).has("Body"):
		pass_test("no built human body GLB in this checkout")
		return
	ZombieBody.piece_warm = true
	var tone: Color = Color(0.61, 0.52, 0.43)
	var pal: Dictionary = {"cloth": Color(0.21, 0.33, 0.27), "hair": Color(0.2, 0.1, 0.05)}
	for living: bool in [true, false]:
		var key: String = ZombieBody._dressed_key("soldier", "medium", false, tone, pal, living)
		ZombieBody._meshes.erase(key)
		assert_false(ZombieBody.dressed_ready("soldier", "medium", false, tone, pal, living), "not there yet")
		ZombieBody.request_dressed("soldier", "medium", false, tone, pal, living)
		var waited: int = 0
		while not ZombieBody.dressed_ready("soldier", "medium", false, tone, pal, living) and waited < 600:
			await wait_frames(1)
			waited += 1
		assert_true(ZombieBody.dressed_ready("soldier", "medium", false, tone, pal, living), "the worker's merge came in (%d frames)" % waited)
		var ahead: ArrayMesh = ZombieBody.build_dressed("soldier", "medium", false, tone, pal, living)
		assert_same(ZombieBody.build_dressed("soldier", "medium", false, tone, pal, living), ahead, "cached once taken")
		assert_false(ZombieBody._dressed_tasks.has(key), "the task is waited for and forgotten")
		ZombieBody._meshes.erase(key)
		var spot: ArrayMesh = ZombieBody.build_dressed("soldier", "medium", false, tone, pal, living)   # merged here
		assert_true(_mesh_arrays_equal(ahead, spot), "living %s: the body merged ahead is the body merged on the spot" % str(living))
		for si: int in ahead.get_surface_count():
			assert_true((ahead.surface_get_arrays(si)[Mesh.ARRAY_COLOR] as PackedColorArray) == (spot.surface_get_arrays(si)[Mesh.ARRAY_COLOR] as PackedColorArray), "the same colours")


func test_a_body_asked_for_before_its_merge_is_in_is_merged_on_the_spot() -> void:
	if not ZombieBody.base_parts("thin", false, true).has("Body"):
		pass_test("no built human body GLB in this checkout")
		return
	var tone: Color = Color(0.5, 0.45, 0.4)
	var pal: Dictionary = {"cloth": Color(0.4, 0.1, 0.1)}
	ZombieBody._meshes.erase(ZombieBody._dressed_key("soldier", "thin", false, tone, pal, true))
	ZombieBody.request_dressed("soldier", "thin", false, tone, pal, true)
	var m: ArrayMesh = ZombieBody.build_dressed("soldier", "thin", false, tone, pal, true)   # at once: no waiting on the worker
	assert_gt(m.get_surface_count(), 0, "the body is there in the same call")
	assert_same(ZombieBody.build_dressed("soldier", "thin", false, tone, pal, true), m)
	await wait_frames(30)   # (the worker's own copy arrives and is never taken)


func test_a_squads_plan_rolls_the_look_the_soldier_rolls() -> void:
	var kit_id: String = "partisan"
	var k: Dictionary = SoldierKits.kit(kit_id)
	for seed_v: int in [1, 77, 2451175291]:
		var a: Dictionary = SoldierKits.roll_look(kit_id, seed_v, k)
		var b: Dictionary = SoldierKits.roll_look(kit_id, seed_v, SoldierKits.kit(kit_id))
		assert_eq(str(a), str(b), "seed %d: one look" % seed_v)
	var look: Dictionary = SoldierKits.roll_look(kit_id, 1, k)
	SoldierKits.request_bodies(look)
	var waited: int = 0
	while not SoldierKits.bodies_ready([look]) and waited < 600:
		await wait_frames(1)
		waited += 1
	assert_true(SoldierKits.bodies_ready([look]), "a requested look's living body comes in (%d frames)" % waited)
	assert_not_null(SoldierKits.body_mesh(look, true))
	await wait_frames(30)


func test_a_persons_pieces_cut_ahead_are_the_on_the_spot_pieces() -> void:
	var id: String = "kubiak"
	if not PeopleBodies.available(id):
		pass_test("no built person GLB in this checkout")
		return
	while ZombieBody.pieces_warming():
		await wait_frames(1)
	var body: ArrayMesh = PeopleBodies.mesh(id, true)
	ZombieBody._piece_queued.erase("person:" + id)
	PeopleBodies._meshes.erase("piece:%s:LeftUpperArm" % id)
	ZombieBody.piece_warm = true
	PeopleBodies.warm_risen(id, "villager", false)
	var waited: int = 0
	while ZombieBody.pieces_warming() and waited < 600:
		await wait_frames(1)
		waited += 1
	assert_true(ZombieBody._piece_cuts.has("person:%s:LeftUpperArm" % id), "the arm was cut ahead")
	var ahead: ArrayMesh = PeopleBodies.piece_mesh(id, "LeftUpperArm")
	assert_false(ZombieBody._piece_cuts.has("person:%s:LeftUpperArm" % id), "taken once")
	assert_eq(str(ahead.get_meta("person", "")), id, "the piece knows whose it is")
	assert_true(_mesh_arrays_equal(ahead, ZombieBody._cut_piece(body, "LeftUpperArm")), "the piece cut ahead is the piece cut on the spot")
