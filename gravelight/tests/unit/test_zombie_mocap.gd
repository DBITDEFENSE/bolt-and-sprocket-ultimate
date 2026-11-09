extends GutTest

func test_contact_event_crossings_include_wrap_without_duplicate_boundaries() -> void:
	assert_true(ZombieClips.crossed_phase(0.9, 0.1, 0.0))
	assert_true(ZombieClips.crossed_phase(0.9, 0.1, 0.95))
	assert_true(ZombieClips.crossed_phase(0.1, 0.2, 0.2))
	assert_false(ZombieClips.crossed_phase(0.1, 0.2, 0.1))
	assert_false(ZombieClips.crossed_phase(0.9, 0.1, 0.5))
	assert_false(ZombieClips.crossed_phase(0.2, 0.2, 0.2))

func test_local_licensed_clips_keep_targets_and_multiple_step_events() -> void:
	var info: Dictionary = ZombieClips.mocap_info()
	if (info["loaded"] as Array).is_empty():
		pending("Licensed source files are local; run zombie_mocap_build.ps1 to exercise imports")
		return
	assert_eq((info["loaded"] as Array).size(), 26)
	assert_eq((info["errors"] as Array).size(), 0)
	for name: String in info["loaded"]:
		var a: Animation = ZombieClips.library().get_animation(name)
		assert_gte(a.get_track_count(), 19, name + " preserves the full retarget")
		assert_false(str(a.get_meta("source", "")).is_empty(), name + " source provenance")
		for track: int in a.get_track_count():
			assert_true(str(a.track_get_path(track)).begins_with("Skel:"), name + " targets runtime skeleton")
	assert_gt(ZombieClips.footstep_events("mco_fast_chase").size(), 2, "multi-stride source gets every recorded contact onset")
	var windows: Dictionary = ZombieClips.contact_windows("mco_fast_chase")
	for event: Dictionary in ZombieClips.footstep_events("mco_fast_chase"):
		var match_contact: bool = false
		for interval: Array in windows["Left" if event["left"] else "Right"]:
			if absf(float(event["phase"]) * ZombieClips.length_of("mco_fast_chase") - float(interval[0])) < 0.0001: match_contact = true
		assert_true(match_contact, "audio event is a source contact, not a fabricated phase")

func test_live_gaits_keep_speed_and_match_root_travel_after_random_seek() -> void:
	if not ZombieClips.has_clip("mco_fast_chase"):
		pending("Local licensed pack required")
		return
	seed(74119)
	var host := Node3D.new()
	add_child_autofree(host)
	var spawn := ZombieSpawn.new()
	host.add_child(spawn)
	var speeds: Dictionary = GLData.table("enemies")["tiers"]
	var jitter: float = float(GLData.table("enemies")["speed_jitter"])
	var held_speeds: Array[float] = []
	for tier: String in ["shamble", "walk", "jog", "run", "sprint"]:
		var z := Zombie.new()
		host.add_child(z)
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":tier}, spawn, null)
		z.set_physics_process(false)
		z.set_process(false)
		z.set_posture("limp_l", 0.8)
		assert_between(z.speed, float(speeds[tier]) * (1.0-jitter), float(speeds[tier]) * (1.0+jitter), "gameplay speed contract " + tier)
		assert_true(z._loco_clip.begins_with("mco_"), tier + " uses licensed motion")
		z._enter(Zombie.State.CHASE)
		z.velocity = Vector3(0, 0, -z.speed)
		var old_toes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var old_ids: Array[int] = [-1, -1]
		for frame: int in 240:
			z.position += z.velocity / 60.0
			z._animate(1.0/60.0)
			for side: int in 2:
				var foot: int = z._skel.find_bone("LeftFoot" if side == 0 else "RightFoot")
				var toe: Vector3 = z._skel.global_transform * (z._skel.get_bone_global_pose(foot) * Vector3(0, -0.06, -0.15))
				var interval: int = z._contact_lock.intervals[side]
				if frame > 60 and interval >= 0 and interval == old_ids[side]:
					var d: Vector3 = toe - old_toes[side]
					held_speeds.append(Vector2(d.x, d.z).length() * 60.0)
				old_ids[side] = interval
				old_toes[side] = toe
		assert_almost_eq(z._rm_speed, z._body_speed, z.speed * 0.05, tier + " evaluated root matches real body travel")
		assert_almost_eq(z._cycle, fposmod(z._playback.get_current_play_position() / z._cycle_len, 1.0), 0.001)
		z.deactivate()
		assert_eq(z._contact_lock.previous_clip, "", "pooled bodies clear old contact anchors")
		assert_eq(z._contact_lock.intervals, [-1, -1])
	held_speeds.sort()
	assert_gt(held_speeds.size(), 100, "planted-foot regression exercised actual contact windows")
	if not held_speeds.is_empty():
		assert_lt(held_speeds[int(held_speeds.size() * 0.95)], 0.1, "p95 planted foot drift with additive limp stays below 0.1 m/s")
