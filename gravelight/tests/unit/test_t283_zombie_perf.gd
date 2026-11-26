extends GutTest
## T-283 (phase 2 of the zombie-count lag, docs/perf/t281_zombie_count_2026-11.md): the skeleton of a zombie runs its
## modifier pass and moves its bone attachments (the hitboxes with them) only in the frames its animation steps
## (Zombie.t283_skel), its foot rays are cast only before such a frame (t283_rays), and the distance LOD is the
## owner's 12 / 30 m (t283_lod). These tests fire rays at posed zombies with the switches on and off and compare the
## zones they hit, pin that the hitboxes sit where the drawn pose puts them in every frame, and pin the rules.

const DT: float = 1.0 / 60.0

var _host: Node3D
var _spawn: ZombieSpawn
var _cam: Camera3D
var _round_before: int
var _saved: Array = []


func before_each() -> void:
	_saved = [Zombie.t283_opt, Zombie.t283_skel, Zombie.t283_rays, Zombie.t283_lod, Zombie.view_lod, RoundManager.current_round]
	Zombie.t283_opt = true
	Zombie.t283_skel = true
	Zombie.t283_rays = true
	Zombie.t283_lod = true
	Zombie.view_lod = true
	GLSettings.values["gore"] = "off"
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"window"
	_host.add_child(_spawn)
	# the camera decides the animation rate (Zombie._process: the camera's distance and view cone)
	_cam = Camera3D.new()
	_host.add_child(_cam)
	_cam.current = true


func after_each() -> void:
	Zombie.t283_opt = _saved[0]
	Zombie.t283_skel = _saved[1]
	Zombie.t283_rays = _saved[2]
	Zombie.t283_lod = _saved[3]
	Zombie.view_lod = _saved[4]
	RoundManager.current_round = _saved[5]
	ZombieRagdoll.clear_parked()


## A walking zombie at the origin, facing +Z toward the camera, driven by hand: its own process and physics steps are
## off, `_step` calls its _process. The modifiers have nothing to do (no foot IK weight, no spring, no look-at), so the
## drawn pose is the animation's: both switch settings must draw the same pose in every frame.
func _zombie(rng_seed: int) -> Zombie:
	seed(rng_seed)
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 400.0, "variant": "villager"}, _spawn, null)
	z.set_process(false)
	z.set_physics_process(false)
	z.global_position = Vector3.ZERO
	z.rotation = Vector3(0, PI, 0)
	z.state = Zombie.State.CHASE
	z.velocity = Vector3(0, 0, 1.3)
	return z


## The camera `dist` metres in front of the zombie, looking at its chest.
func _place_camera(dist: float) -> void:
	_cam.global_position = Vector3(0.4, 1.5, dist)
	_cam.look_at(Vector3(0, 1.1, 0))


## One frame: the zombie's _process (it animates or skips by its rate), then the engine's frame (the skeleton's
## deferred update, the attachments' transforms into the physics server). Switched off, the skeleton runs its modifier
## pass once a frame with the frame's time (Skeleton3D's IDLE mode); a test frame spans several engine frames with
## their own times, so the switched-off side is played here as exactly that: one pass a frame with DT.
func _step(z: Zombie) -> void:
	z._process(DT)
	var sk: Skeleton3D = z.skeleton()
	if sk.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
		sk.advance(DT)
	await get_tree().process_frame
	await get_tree().physics_frame


## Rays from the camera through a 9 x 15 grid over the zombie's body: the zone (limb) each one hits first, "" = none.
func _zones() -> PackedStringArray:
	var out: PackedStringArray = []
	var space: PhysicsDirectSpaceState3D = _host.get_world_3d().direct_space_state
	for iy: int in 15:
		for ix: int in 9:
			var aim: Vector3 = Vector3(-0.6 + 0.15 * ix, 0.15 + 0.13 * iy, 0.0)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_cam.global_position, _cam.global_position + (aim - _cam.global_position) * 2.0, Hitbox.LAYER_HITBOX)
			q.collide_with_areas = true
			q.collide_with_bodies = false
			var hit: Dictionary = space.intersect_ray(q)
			var hb: Hitbox = hit.get("collider") as Hitbox if not hit.is_empty() else null
			out.append("" if hb == null else "%s:%s" % [hb.limb, hb.bone])
	return out


## `frames` frames of the walk with the T-283 skeleton switch as given: the zones hit in each frame, and the frames the
## modifier pass ran in.
func _walk(dist: float, skel_on: bool, frames: int) -> Dictionary:
	Zombie.t283_skel = skel_on
	_place_camera(dist)
	var z: Zombie = _zombie(11)
	await _step(z)
	var zones: Array = []
	var mod_ticks: Array = []
	var mod: ZombieBodyModifier = z.get("_modifier") as ZombieBodyModifier
	for i: int in frames:
		var t0: int = mod.ticks
		await _step(z)
		zones.append(_zones())
		mod_ticks.append(mod.ticks - t0)
	z._skel_mode_sync()
	var out: Dictionary = {"zones": zones, "mod_ticks": mod_ticks, "div": z.get("_anim_div"), "mode": z.skeleton().modifier_callback_mode_process}
	z.queue_free()
	await get_tree().process_frame
	return out


func _hits(zones: Array) -> int:
	var n: int = 0
	for f: PackedStringArray in zones:
		for s: String in f:
			if s != "":
				n += 1
	return n


# ------------------------------------------------------------------ the zones a shot hits

func test_a_near_zombie_is_hit_in_the_same_zones_in_every_frame_with_the_switch_on_and_off() -> void:
	var off: Dictionary = await _walk(5.0, false, 16)
	var on: Dictionary = await _walk(5.0, true, 16)
	assert_eq(int(on["div"]), 1, "5 m from the camera: animated every frame")
	assert_eq(int(on["mode"]), Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL, "switched on: the skeleton steps with the animation")
	assert_eq(int(off["mode"]), Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE, "switched off: every frame, as before")
	assert_gt(_hits(on["zones"]), 16 * 20, "the grid hits the body (head, torso, arms, legs)")
	for i: int in 16:
		assert_eq(on["zones"][i], off["zones"][i], "frame %d: every ray hits the same zone" % i)
	assert_eq(on["mod_ticks"], off["mod_ticks"], "the modifier pass runs once a frame either way")


func test_a_zombie_at_the_half_rate_is_hit_in_the_same_zones_and_its_skeleton_runs_only_when_it_animates() -> void:
	var off: Dictionary = await _walk(20.0, false, 16)
	var on: Dictionary = await _walk(20.0, true, 16)
	assert_eq(int(on["div"]), 2, "20 m from the camera: every 2nd frame")
	assert_gt(_hits(on["zones"]), 16 * 4, "the grid hits the body")
	for i: int in 16:
		assert_eq(on["zones"][i], off["zones"][i], "frame %d: every ray hits the same zone" % i)
	var ran_on: int = 0
	var ran_off: int = 0
	for i: int in 16:
		ran_on += int(on["mod_ticks"][i])
		ran_off += int(off["mod_ticks"][i])
	assert_eq(ran_off, 16, "switched off: the modifier pass runs in every frame (the work T-283 removes)")
	assert_eq(ran_on, 8, "switched on: only in the 8 frames the animation stepped")


func test_the_hitboxes_sit_where_the_drawn_pose_puts_them_in_every_frame_and_hold_still_between_steps() -> void:
	_place_camera(20.0)
	var z: Zombie = _zombie(11)
	await _step(z)
	var sk: Skeleton3D = z.skeleton()
	var boxes: Array[Hitbox] = []
	for hb: Hitbox in z.get("_hitboxes"):
		boxes.append(hb)
	assert_eq(boxes.size(), ZombieBody.HITBOXES.size(), "the limb layout")
	var held: int = 0
	var moved: int = 0
	var prev: Array = []
	var mod: ZombieBodyModifier = z.get("_modifier") as ZombieBodyModifier
	var stepped: bool = false
	for i: int in 12:
		var t0: int = mod.ticks
		await _step(z)
		stepped = mod.ticks > t0
		var now: Array = []
		for hb: Hitbox in boxes:
			var bi: int = sk.find_bone(hb.bone)
			var want: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi) * hb.position
			assert_lt(hb.global_position.distance_to(want), 0.002, "frame %d, %s: the box is on its bone's drawn pose" % [i, hb.bone])
			# and the physics server has it there (what a ray meets)
			var xf: Transform3D = PhysicsServer3D.area_get_transform(hb.get_rid())
			assert_lt(xf.origin.distance_to(hb.global_position), 0.002, "frame %d, %s: the physics server's box is the node's" % [i, hb.bone])
			now.append(hb.global_position)
		if not prev.is_empty():
			var same: bool = true
			for k: int in now.size():
				if (now[k] as Vector3).distance_to(prev[k]) > 0.0001:
					same = false
			if same:
				held += 1
			else:
				moved += 1
			assert_eq(not same, stepped, "frame %d: the boxes move exactly in the frames the animation steps" % i)
		prev = now
	assert_gt(moved, 4, "the boxes move in the frames the animation steps")
	assert_gt(held, 4, "and hold still with the drawn pose in the frames between")
	z.queue_free()


# ------------------------------------------------------------------ the rules

func test_a_ragdoll_runs_the_skeleton_every_frame_as_before() -> void:
	_place_camera(5.0)
	var z: Zombie = _zombie(3)
	await _step(z)
	assert_eq(z.skeleton().modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL)
	var sim: PhysicalBoneSimulator3D = PhysicalBoneSimulator3D.new()
	z.set("_ragdoll", sim)
	z._skel_mode_sync()
	assert_eq(z.skeleton().modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE, "a ragdoll writes the bones every tick")
	z.set("_ragdoll", null)
	sim.free()
	Zombie.t283_opt = false
	z._skel_mode_sync()
	assert_eq(z.skeleton().modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE, "switched off: as before")
	Zombie.t283_opt = true
	z._skel_mode_sync()
	assert_eq(z.skeleton().modifier_callback_mode_process, Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL)
	z.queue_free()


func test_foot_rays_are_cast_only_before_a_frame_that_steps_the_animation() -> void:
	# full rate: always
	for skip: int in 6:
		assert_true(Zombie.anim_steps_within(skip, 1, 1))
	# every 2nd frame at one frame a tick: the tick before the frames 2, 4, ... (anim_skip 1, 3, ...)
	assert_false(Zombie.anim_steps_within(0, 2, 1))
	assert_true(Zombie.anim_steps_within(1, 2, 1))
	assert_false(Zombie.anim_steps_within(2, 2, 1))
	assert_true(Zombie.anim_steps_within(3, 2, 1))
	# every 4th: one tick in four
	var n: int = 0
	for skip2: int in 16:
		if Zombie.anim_steps_within(skip2, 4, 1):
			n += 1
	assert_eq(n, 4)
	# at a frame rate above the tick rate (two frames a tick) a step in either frame needs the rays
	assert_true(Zombie.anim_steps_within(0, 2, 2))
	assert_true(Zombie.anim_steps_within(2, 4, 2))
	assert_false(Zombie.anim_steps_within(1, 4, 2))
	assert_false(Zombie.anim_steps_within(0, 4, 2))


func test_the_distance_lod_is_the_owners_12_and_30_metres_and_the_old_one_switched_off() -> void:
	var lod: Dictionary = GLData.table("anim")["lod"]
	assert_eq(float(lod["t283"]["full_m"]), 12.0)
	assert_eq(float(lod["t283"]["half_m"]), 30.0)
	assert_eq(float(lod["full_m"]), 15.0, "the switched-off rate: as before")
	assert_eq(float(lod["half_m"]), 35.0)
	for case: Array in [[5.0, 1, 1], [13.0, 2, 1], [20.0, 2, 2], [32.0, 4, 2], [40.0, 4, 4]]:
		Zombie.t283_lod = true
		_place_camera(float(case[0]))
		var z: Zombie = _zombie(5)
		Zombie._vl_frame = -1   # the camera is read once a frame for the whole horde: read it again after the move
		z._process(DT)
		assert_eq(int(z.get("_anim_div")), int(case[1]), "%.0f m, switched on" % case[0])
		Zombie.t283_lod = false
		z._process(DT)
		assert_eq(int(z.get("_anim_div")), int(case[2]), "%.0f m, switched off" % case[0])
		z.queue_free()
		await get_tree().process_frame
