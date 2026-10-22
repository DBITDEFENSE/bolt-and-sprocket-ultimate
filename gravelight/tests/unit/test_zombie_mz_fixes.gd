extends GutTest
## MZ review fixes: rig-less bodies (the Foreman puppet) skip the rig paths, the ragdoll keeps severed bones
## collapsed, continuous damage can't pin a getting-up zombie, a one-shot state restarts when replayed, the
## sprinter grab pulls without permanent drift or yaw jitter, the hit bone never leaks, the nurse keeps her
## posture, and the Map 1 buy-doors fill their 2.6 m openings.


## Records kick_camera calls instead of moving a camera.
class KickRecorder extends Player:
	var kicks: Array = []

	func kick_camera(pitch_deg: float, yaw_deg: float, keep: float, recover: float, shake: float, fov_punch: float) -> void:
		kicks.append([pitch_deg, yaw_deg, keep, recover, shake, fov_punch])


var _host: Node3D
var _spawn: ZombieSpawn


func before_each() -> void:
	GLSettings.values["gore"] = "full"
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)


func _zombie(variant: String = "miner") -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 5000, "variant": variant}, _spawn, null)
	return z


func test_foreman_has_no_rig_and_rig_paths_are_safe() -> void:
	var f: Foreman = Foreman.new()
	_host.add_child(f)
	assert_false(f.has_rig(), "the Foreman builds his own body")
	f.state = Zombie.State.CHASE
	# what a co-op client's puppet tick and predicted hit run on him
	f._update_senses(0.016)
	f._play_flinch(&"torso", "")
	f._play_flinch(&"arms", "l")
	f._tree_play("React", "flinch_torso", 1.0)
	assert_true(true, "no script error on a rig-less body")
	var z: Zombie = _zombie()
	assert_true(z.has_rig(), "the shared body has the rig")
	z.deactivate()


func test_getup_survives_fire_and_bursts() -> void:
	var z: Zombie = _zombie()
	z._knockdown()
	assert_eq(z.state, Zombie.State.KNOCKDOWN)
	z._enter(Zombie.State.GETUP)
	z._state_t = 0.5
	z.take_damage(5.0, &"torso", &"fire", 0, &"fire")
	assert_eq(z._state_t, 0.5, "a fire tick does not restart the get-up")
	z.take_damage(5.0, &"torso", &"none", 0, &"world")
	assert_eq(z._state_t, 0.5, "a trap tick does not restart the get-up")
	z.take_damage(5.0, &"torso", &"rifle", 0, &"bullet")
	assert_eq(z.state, Zombie.State.GETUP)
	assert_eq(z._state_t, 0.0, "the first real hit knocks it back once")
	z._state_t = 0.5
	z.take_damage(5.0, &"torso", &"rifle", 0, &"bullet")
	z.take_damage(5.0, &"torso", &"rifle", 0, &"bullet")
	assert_eq(z._state_t, 0.5, "the rest of the burst lets it keep getting up")
	# a fresh knockdown allows one restart again
	z._enter(Zombie.State.CHASE)
	z._knockdown()
	z._enter(Zombie.State.GETUP)
	z._state_t = 0.3
	z.take_damage(5.0, &"torso", &"rifle", 0, &"bullet")
	assert_eq(z._state_t, 0.0)
	z.deactivate()


## Zombie._tree_play relies on travel() to the current state restarting it (true in Godot 4.7.2): if an engine
## update changes that, the get-up would start at the knockdown's playhead and this fails.
func test_replayed_one_shot_state_restarts_its_clip() -> void:
	var z: Zombie = _zombie()
	z._knockdown()
	for i: int in 6:
		z._tree.advance(0.1)
	var pb: AnimationNodeStateMachinePlayback = z._playback
	assert_eq(String(pb.get_current_node()), "React", "knocked down")
	assert_gt(pb.get_current_play_position(), 0.3, "the knockdown clip has played a while")
	z._enter(Zombie.State.GETUP)
	z._tree.advance(0.02)
	assert_eq(String(pb.get_current_node()), "React")
	assert_lt(pb.get_current_play_position(), 0.15, "the get-up clip starts from its first frame")
	z.deactivate()


func test_ragdoll_sync_keeps_severed_bones_collapsed() -> void:
	var z: Zombie = _zombie()
	var sk: Skeleton3D = z.skeleton()
	assert_true(ZombieGore.sever(z, "Head", Vector3.ZERO, false))
	assert_true(ZombieGore.sever(z, "LeftUpperArm", Vector3.ZERO, false))
	var sim: PhysicalBoneSimulator3D = ZombieRagdoll.start(sk)
	if sim == null:
		pending("ragdolls disabled or at the cap")
		z.deactivate()
		return
	for i: int in 3:
		ZombieRagdoll.sync(sim, sk)
	for b: String in ["Head", "Jaw", "LeftUpperArm", "LeftLowerArm", "LeftHand"]:
		var s: float = sk.get_bone_global_pose(sk.find_bone(b)).basis.get_scale().x
		assert_lt(s, 0.01, "%s stays severed on the ragdoll (scale %.4f)" % [b, s])
	for b2: String in ["Chest", "RightUpperArm", "RightLowerArm"]:
		var s2: float = sk.get_bone_global_pose(sk.find_bone(b2)).basis.get_scale().x
		assert_almost_eq(s2, 1.0, 0.01, b2 + " keeps its size")
	ZombieRagdoll.stop(sim)
	z.deactivate()
	await get_tree().process_frame   # stop() queue_frees the simulator


func test_grab_pull_is_steady_and_springs_back() -> void:
	var z: Zombie = _zombie()
	var p: KickRecorder = KickRecorder.new()
	z._grab_target = p
	z._grab_t = 0.4
	for i: int in 5:
		z._update_grab(1.0 / 60.0)
	assert_eq(p.kicks.size(), 5)
	for k: Array in p.kicks:
		assert_gt(float(k[0]), 0.0, "pulls the view")
		assert_eq(float(k[1]), 0.0, "no per-frame yaw (kick_camera would roll a random sign each call)")
		assert_eq(float(k[2]), 0.0, "keep 0: all of it springs back after the grab")
	p.free()
	z.deactivate()


func test_last_hit_bone_never_leaks() -> void:
	var z: Zombie = _zombie()
	z.deactivate()
	z.last_hit_bone = "LeftUpperArm"
	assert_false(z.take_damage(10.0, &"arms", &"rifle", 0))
	assert_eq(z.last_hit_bone, "", "consumed even when the zombie is not active")
	var f: Foreman = Foreman.new()
	_host.add_child(f)
	f.last_hit_bone = "RightUpperArm"
	f.take_damage(10.0, &"arms", &"rifle", 0)
	assert_eq(f.last_hit_bone, "")


func test_nurse_keeps_a_slight_hunch() -> void:
	var s: Screamer = Screamer.new()
	_host.add_child(s)
	for i: int in 4:
		s.spawn_screamer(Vector3(0, 0, 0), 800.0)
		assert_eq(String(s._posture_node.animation), "hunch", "her posture is never rolled")
		assert_almost_eq(float(s._tree.get("parameters/Posture/add_amount")), 0.35, 0.001)
	s.deactivate()


func test_map01_buy_doors_fill_their_openings() -> void:
	var text: String = FileAccess.get_file_as_string("res://gravelight/maps/map01_kaltenbrunn/map01.tscn")
	assert_false(text.is_empty())
	var re: RegEx = RegEx.create_from_string("\\[node name=\"(Door_[A-Za-z_]+)\"[^\\n]*\\n(?:[^\\[][^\\n]*\\n)*?size = Vector3\\(([0-9.]+),")
	var found: int = 0
	for m: RegExMatch in re.search_all(text):
		found += 1
		assert_almost_eq(float(m.get_string(2)), 2.6, 0.001, m.get_string(1) + " panel matches the 2.6 m opening")
	assert_eq(found, 8, "all eight buy-doors")
