extends GutTest
## T-281 (docs/perf/t281_zombie_count_2026-11.md): the horde-size optimisations do the same thing as the code they
## replace. Zombie.t281_opt switches them; every test here compares the switched-on result with the switched-off one
## or pins the rule that makes them the same.

var _host: Node3D
var _spawn: ZombieSpawn
var _round_before: int
var _opt_before: bool


func before_each() -> void:
	seed(5)
	GLSettings.values["gore"] = "off"
	_round_before = RoundManager.current_round
	_opt_before = Zombie.t281_opt
	Zombie.t281_opt = true
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	# a floor to stand on (the world layer, as the maps' static batches)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = Zombie.LAYER_WORLD
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	_host.add_child(floor_body)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"window"
	_host.add_child(_spawn)


func after_each() -> void:
	RoundManager.current_round = _round_before
	Zombie.t281_opt = _opt_before
	ZombieRagdoll.clear_parked()


func _zombie() -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 400.0, "variant": "villager"}, _spawn, null)
	z.global_position = Vector3(0, 0.05, 0)
	z._enter(Zombie.State.STAGGER)
	z._react_len = 100.0
	return z


## `ticks` physics ticks of the body's own stagger (one halt a tick).
func _settle(_z: Zombie, ticks: int) -> void:
	for i: int in ticks:
		await get_tree().physics_frame


# ------------------------------------------------------------------ a halted body at rest

func test_a_halted_body_at_rest_skips_its_slides_and_ends_where_the_slides_would_leave_it() -> void:
	var z: Zombie = _zombie()
	await _settle(z, 20)   # lands, stops moving
	var at: Vector3 = z.global_position
	assert_true(z.is_on_floor(), "standing on the floor")
	var skips0: int = Zombie.halt_skips
	await _settle(z, 30)
	var skipped: int = Zombie.halt_skips - skips0
	assert_gt(skipped, 20, "most of the ticks at rest skip the slide")
	assert_lt(skipped, 30, "but every REST_REFRESH_TICKS-th tick slides for real")
	assert_true(z.global_position.is_equal_approx(at), "the body stays exactly where it was")
	# the same body with the switch off: every tick slides, and it is still in the same place
	Zombie.t281_opt = false
	var skips1: int = Zombie.halt_skips
	await _settle(z, 10)
	assert_eq(Zombie.halt_skips, skips1, "switched off: no slide skipped")
	assert_true(z.global_position.distance_to(at) < 0.001, "and the real slides leave it where the skipped ones did")


func test_anything_that_could_move_the_body_makes_it_slide() -> void:
	var z: Zombie = _zombie()
	await _settle(z, 20)
	z._rest_tick = 5
	assert_true(z._at_rest(), "at rest")
	z.global_position += Vector3(0.3, 0, 0)   # moved by someone (a relocation, a step up)
	assert_false(z._at_rest(), "moved since its last slide: slides")
	await _settle(z, 3)
	z._rest_tick = 5
	z.velocity.x = 0.2   # still braking
	assert_false(z._at_rest(), "velocity left on the flat: slides")
	z.velocity.x = 0.0
	z.velocity.y = 1.0
	assert_false(z._at_rest(), "going up: slides")


func test_a_body_still_settling_is_not_at_rest() -> void:
	var z: Zombie = _zombie()
	z.global_position = Vector3(0, 1.5, 0)   # in the air
	z._halt(1.0 / 60.0)
	assert_false(z._at_rest(), "falling: not at rest")


# ------------------------------------------------------------------ the weak-point boxes

func test_weak_point_boxes_that_are_not_live_leave_the_physics_space() -> void:
	var z: Zombie = _zombie()
	var live: int = 0
	for site: StringName in z._marke_hb.keys():
		var hb: Hitbox = z._marke_hb[site]
		if hb.collision_layer != 0:
			live += 1
			assert_eq(hb.process_mode, Node.PROCESS_MODE_INHERIT, "the live box stays in the space")
		else:
			assert_eq(hb.process_mode, Node.PROCESS_MODE_DISABLED, "a box with no layer is out of the space")
	for ws: StringName in z._wound_hb.keys():
		var whb: Hitbox = z._wound_hb[ws]
		assert_eq(whb.process_mode, Node.PROCESS_MODE_DISABLED if whb.collision_layer == 0 else Node.PROCESS_MODE_INHERIT)
	assert_lte(live, 1, "one live Marke box at most")
	z.deactivate()
	for site2: StringName in z._marke_hb.keys():
		assert_eq((z._marke_hb[site2] as Hitbox).process_mode, Node.PROCESS_MODE_DISABLED, "pooled: all out")
	Zombie.t281_opt = false
	z._marke_layers(false)
	for site3: StringName in z._marke_hb.keys():
		assert_eq((z._marke_hb[site3] as Hitbox).process_mode, Node.PROCESS_MODE_INHERIT, "switched off: in the space, as before")


# ------------------------------------------------------------------ the foot rays

func test_a_still_foot_keeps_its_rays_and_gets_the_same_ground() -> void:
	var z: Zombie = _zombie()
	await _settle(z, 20)
	z._enter(Zombie.State.CHASE)
	z._out_of_view = false
	var p: Player = Player.new()
	p.player_id = 1
	_host.add_child(p)
	p.global_position = Vector3(0, 0, 4)
	z.target = p
	z._update_senses(1.0 / 60.0)
	var fresh: PackedFloat32Array = z._modifier.foot_ground_y.duplicate()
	var toe: PackedFloat32Array = z._modifier.toe_ground_y.duplicate()
	var reuses0: int = Zombie.foot_ray_reuses
	z._update_senses(1.0 / 60.0)
	assert_eq(Zombie.foot_ray_reuses - reuses0, 2, "both feet kept their rays")
	for i: int in 2:
		assert_almost_eq(z._modifier.foot_ground_y[i], fresh[i], 1.0e-5, "the same ground under foot %d" % i)
		assert_almost_eq(z._modifier.toe_ground_y[i], toe[i], 1.0e-5, "the same ground under toe %d" % i)
	# moved: cast again
	z.global_position += Vector3(0.2, 0, 0)
	var reuses1: int = Zombie.foot_ray_reuses
	z._update_senses(1.0 / 60.0)
	assert_eq(Zombie.foot_ray_reuses, reuses1, "a foot that moved casts again")
	Zombie.t281_opt = false
	z._update_senses(1.0 / 60.0)
	assert_eq(Zombie.foot_ray_reuses, reuses1, "switched off: always cast")


# ------------------------------------------------------------------ ragdoll rigs kept for the next death

func _skel(x: float) -> Skeleton3D:
	var sk: Skeleton3D = ZombieRig.build_skeleton()
	_host.add_child(sk)
	sk.position = Vector3(x, 2.0, 0.0)
	return sk


func test_a_stopped_rig_is_kept_and_starts_again_on_another_skeleton() -> void:
	if not ZombieRagdoll.enabled():
		pending("ragdolls disabled")
		return
	ZombieRagdoll._prune()   # (rigs an earlier test freed: casting a freed object errors)
	for e: Array in ZombieRagdoll._live:
		ZombieRagdoll.freeze(e[0] as PhysicalBoneSimulator3D)
	ZombieRagdoll.clear_parked()
	var a: PhysicalBoneSimulator3D = ZombieRagdoll.start(_skel(0.0), Vector3(0, 3, 0))
	assert_not_null(a)
	var bones: int = a.get_child_count()
	await get_tree().physics_frame
	ZombieRagdoll.freeze(a)   # (a frozen rig has its mask off: the kept one must get it back)
	ZombieRagdoll.stop(a)
	assert_true(is_instance_valid(a) and a.get_parent() == null, "kept, out of the tree")
	var reused0: int = ZombieRagdoll.reused
	var sk2: Skeleton3D = _skel(3.0)
	var b: PhysicalBoneSimulator3D = ZombieRagdoll.start(sk2)
	assert_eq(b, a, "the next death takes the kept rig")
	assert_eq(ZombieRagdoll.reused - reused0, 1)
	assert_eq(b.get_parent(), sk2, "on the new skeleton")
	assert_eq(b.get_child_count(), bones, "every bone")
	assert_true(b.is_simulating_physics(), "simulating")
	for c: Node in b.get_children():
		var pb: PhysicalBone3D = c as PhysicalBone3D
		assert_eq(pb.collision_mask, 1, "%s collides with the world again" % pb.name)
		assert_true(pb.linear_velocity.length() < 0.001, "%s starts at rest (no speed left from the last death)" % pb.name)
		var bi: int = sk2.find_bone(String(pb.bone_name))
		var want: Vector3 = (sk2.global_transform * sk2.get_bone_global_pose(bi) * pb.body_offset).origin
		assert_true(pb.global_position.distance_to(want) < 0.05, "%s starts at the new skeleton's pose" % pb.name)
	ZombieRagdoll.stop(b)


func test_switched_off_a_stopped_rig_is_freed_as_before() -> void:
	if not ZombieRagdoll.enabled():
		pending("ragdolls disabled")
		return
	for e: Array in ZombieRagdoll._live:
		ZombieRagdoll.freeze(e[0] as PhysicalBoneSimulator3D)
	ZombieRagdoll.clear_parked()
	Zombie.t281_opt = false
	var a: PhysicalBoneSimulator3D = ZombieRagdoll.start(_skel(0.0))
	ZombieRagdoll.stop(a)
	assert_true(a.is_queued_for_deletion(), "freed")
	assert_eq(ZombieRagdoll._parked.size(), 0, "nothing kept")


func test_at_most_park_max_rigs_are_kept() -> void:
	if not ZombieRagdoll.enabled():
		pending("ragdolls disabled")
		return
	ZombieRagdoll.clear_parked()
	var sims: Array = []
	for i: int in ZombieRagdoll.PARK_MAX + 2:
		for e: Array in ZombieRagdoll._live:
			ZombieRagdoll.freeze(e[0] as PhysicalBoneSimulator3D)
		ZombieRagdoll._live.clear()
		var s: PhysicalBoneSimulator3D = ZombieRagdoll.start(_skel(i * 2.0))
		if s != null:
			sims.append(s)
	for s2: PhysicalBoneSimulator3D in sims:
		ZombieRagdoll.stop(s2)
	assert_eq(ZombieRagdoll._parked.size(), mini(sims.size(), ZombieRagdoll.PARK_MAX), "the kept rigs are capped")
