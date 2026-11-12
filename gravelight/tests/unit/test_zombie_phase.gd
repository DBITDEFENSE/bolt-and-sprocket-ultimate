extends GutTest

func test_ground_spawns_keep_emerge_and_enter_different_first_strides() -> void:
	seed(812)
	var host := Node3D.new()
	add_child_autofree(host)
	var spawn := ZombieSpawn.new()
	spawn.kind = &"ground"
	host.add_child(spawn)
	var phases: Array[float] = []
	for i: int in 8:
		var z := Zombie.new()
		host.add_child(z)
		z.activate({"enemy_id": "ganger", "tier": "walk", "health": 5000, "variant": "soldier"}, spawn, null)
		z.set_physics_process(false)
		# Equal clip and body scale remove ordinary cadence differences as an explanation.
		z._cycle_len = ZombieClips.length_of("walk_a")
		z._loco_clip = "walk_a"
		z._loco_speed = ZombieClips.stride_speed("walk_a", "walk")
		z._pivot.scale = Vector3.ONE
		for point: int in range(1, 4):
			(z._loco_bs.get_blend_point_node(point) as AnimationNodeAnimation).animation = &"walk_a"
		z.set_posture("none", 0)
		z._tree.advance(0.02)
		assert_eq(String(z._playback.get_current_node()), "Emerge")
		assert_lt(z._playback.get_current_play_position(), 0.1, "random gait phase must not skip the emerge")
		z._enter(Zombie.State.CHASE)
		z.velocity = Vector3(0, 0, -2)
		for tick: int in 20:
			z._animate(0.02)
		var seek: float = float(z._tree.get("parameters/SM/Locomotion/TimeSeek/seek_request"))
		assert_lt(seek, 0.0, "queued stride seek was consumed on first locomotion")
		assert_almost_eq(z._cycle, fposmod(z._playback.get_current_play_position() / z._cycle_len, 1.0), 0.001, "footstep phase follows the evaluated animation")
		phases.append(fposmod(z._playback.get_current_play_position() / z._cycle_len, 1.0))
		z._tree_attack("swipe_l")
		z._tree.advance(0.2)
		z._tree_locomotion()
		for tick: int in 20:
			z._animate(0.02)
		assert_almost_eq(z._cycle, fposmod(z._playback.get_current_play_position() / z._cycle_len, 1.0), 0.001, "footstep phase stays aligned after an attack")
		z.deactivate()
	phases.sort()
	assert_gt(phases.back() - phases.front(), 0.25, "same-frame emerges must not produce synchronized first strides")
