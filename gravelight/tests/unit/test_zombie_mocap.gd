extends GutTest

func test_recorded_turns_keep_gameplay_facing_and_release_on_interrupt() -> void:
	if not ZombieClips.recorded_turns_enabled():
		pending("Local licensed root-yaw clips required")
		return
	var host := Node3D.new()
	add_child_autofree(host)
	var spawn := ZombieSpawn.new()
	host.add_child(spawn)
	var z := Zombie.new()
	host.add_child(z)
	var drift: Array[float] = []
	for degrees: float in [35.0, 45.0, 60.0, -35.0, -45.0, -60.0]:
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
		z.set_physics_process(false)
		z.set_process(false)
		z.rotation.y = 0.0
		z.set_posture("none", 0.0)
		z._enter(Zombie.State.CHASE)
		z._animate(0.3)
		var yaw: float = deg_to_rad(degrees)
		var target: Vector3 = z.position + Vector3(-sin(yaw), 0, -cos(yaw)) * 10.0
		var expected: float = 0.0
		var old_toes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var old_ids: Array[int] = [-1, -1]
		var entered: bool = false
		var here: Vector3 = z.position
		var speed: float = z.speed
		for tick: int in 120:
			expected = lerp_angle(expected, yaw, 0.25)
			z._face(target)
			z._animate(1.0/60.0)
			assert_almost_eq(wrapf(z.rotation.y - expected, -PI, PI), 0.0, 0.00001, "gameplay facing response unchanged")
			if z._tree_state == "Turn":
				entered = true
				assert_lt(z._skel.get_bone_pose_rotation(z._skel.find_bone("Root")).angle_to(Quaternion.IDENTITY), 0.001, "tree extracts yaw instead of double rotating skeleton")
			for side: int in 2:
				var foot: int = z._skel.find_bone("LeftFoot" if side == 0 else "RightFoot")
				var toe: Vector3 = z._skel.global_transform * (z._skel.get_bone_global_pose(foot) * Vector3(0, -0.06, -0.15))
				var id: int = z._contact_lock.intervals[side]
				if id >= 0 and id == old_ids[side] and z._tree_state == "Turn":
					var d: Vector3 = toe - old_toes[side]
					drift.append(Vector2(d.x, d.z).length() * 60.0)
				old_toes[side] = toe
				old_ids[side] = id
		assert_true(entered, "recorded turn selected " + str(degrees))
		assert_false(z._turn_motion.active)
		assert_almost_eq(z._pivot.rotation.y, 0.0, 0.001, "visual turn settles exactly onto gameplay heading")
		assert_eq(z.position, here)
		assert_eq(z.speed, speed)
		# Interrupt a fresh turn with an attack; its windup and visual state must win immediately.
		z._face(z.position + Vector3(-sin(yaw + 0.7), 0, -cos(yaw + 0.7)) * 10.0)
		z._animate(0.1)
		assert_true(z._turn_motion.active)
		z._enter(Zombie.State.ATTACK)
		for tick: int in 24: z._animate(1.0/60.0)
		assert_eq(z._tree_state, "Attack")
		assert_false(z._turn_motion.active)
		assert_almost_eq(z._pivot.rotation.y, 0.0, 0.002)
		assert_false(z._attack_hit_done, "turn presentation cannot cause damage")
		z.deactivate()
		assert_eq(z._turn_motion.offset, 0.0, "pool reuse clears turn compensation")
	drift.sort()
	assert_gt(drift.size(), 100)
	if not drift.is_empty(): assert_lt(drift[int(drift.size()*0.95)], 0.1, "turn contact p95 below 0.1 m/s")

func test_recorded_swipes_keep_gameplay_windup_and_recovery() -> void:
	if not ZombieClips.has_clip("mco_swipe_l"):
		pending("Local licensed pack required")
		return
	var host := Node3D.new()
	add_child_autofree(host)
	var spawn := ZombieSpawn.new()
	host.add_child(spawn)
	var z := Zombie.new()
	host.add_child(z)
	z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
	z.set_physics_process(false)
	z.set_process(false)
	z._cfg = z._cfg.duplicate(true)
	for clip: String in ["swipe_l", "swipe_r"]:
		assert_eq(ZombieClips.visual_clip(clip), "mco_" + clip)
		assert_almost_eq(ZombieClips.length_of("mco_" + clip), 0.8, 0.0001)
		assert_eq(ZombieClips.library().get_animation("mco_" + clip).loop_mode, Animation.LOOP_NONE)
		assert_almost_eq(ZombieClips.hit_event_time(clip), 0.45, 0.0001)
		for windup: float in [0.3, 0.45, 0.65]:
			z._cfg["attack_windup"] = windup
			z._enter(Zombie.State.CHASE)
			z._animate(0.3)
			z._enter(Zombie.State.ATTACK)
			z._attack_clip = clip
			z._tree_attack(clip)
			for tick: int in int(round(windup * 60.0)) - 1:
				z._state_t = float(tick + 1) / 60.0
				z._update_attack(1.0/60.0)
				z._animate(1.0/60.0)
			assert_false(z._attack_hit_done, "no early damage " + clip)
			z._state_t = windup
			z._update_attack(1.0/60.0)
			assert_true(z._attack_hit_done, "original windup reaches damage")
			z._animate(0.0)
			assert_almost_eq(z._playback.get_current_play_position(), 0.45, 0.0001, "source strike evaluated at damage")
			assert_eq(z._attack_clip, clip, "network/gameplay name unchanged")
			assert_almost_eq(float(z._tree.get("parameters/SM/Attack/TimeScale/scale")), 1.0, 0.0001)
			z._state_t = windup + 0.34
			z._update_attack(1.0/60.0)
			assert_eq(z.state, Zombie.State.ATTACK, "original recovery retained")
			z._state_t = windup + 0.35
			z._update_attack(1.0/60.0)
			assert_eq(z.state, Zombie.State.CHASE)
	# Client puppets only advance presentation; no host hit callback is required.
	z._cfg["attack_windup"] = 0.65
	z._enter(Zombie.State.ATTACK)
	z._attack_clip = "swipe_l"
	z._tree_attack("swipe_l")
	z._state_t = 0.65
	z._animate(0.0)
	assert_almost_eq(z._playback.get_current_play_position(), 0.45, 0.0001)
	assert_false(z._attack_hit_done, "visual strike does not deal or authorize damage")

func test_recorded_deaths_keep_network_names_and_reset_pooled_root_offset() -> void:
	if not ZombieClips.has_clip("mco_death_back"):
		pending("Local licensed pack required")
		return
	var host := Node3D.new()
	add_child_autofree(host)
	var spawn := ZombieSpawn.new()
	host.add_child(spawn)
	var z := Zombie.new()
	host.add_child(z)
	for clip: String in ["death_sit", "death_back"]:
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
		z.set_physics_process(false)
		z.set_process(false)
		z._enter(Zombie.State.CHASE)
		z._animate(0.3)
		var here: Vector3 = z.global_position
		z._death_clip = clip
		z._start_death()
		assert_eq(z._death_clip, clip, "network death index continues to use original name")
		assert_eq(String((z._anim_nodes["Death"] as AnimationNodeAnimation).animation), ZombieClips.visual_clip(clip))
		assert_eq(float(z._tree.get("parameters/Posture/add_amount")), 0.0)
		var handoff: float = ZombieClips.death_key_pose_time(clip)
		for tick: int in int(round(handoff * 60.0)) - 1:
			z._state_t = float(tick + 1) / 60.0
			z._update_dead(1.0/60.0)
			z._animate(1.0/60.0)
		assert_false(z._ragdoll_started, "recording reaches its reviewed key pose")
		assert_gt(z._pivot.position.z, 0.05, "recorded backward travel reaches presentation root")
		assert_eq(z.global_position, here, "corpse animation does not move gameplay body")
		z._state_t = handoff
		z._update_dead(1.0/60.0)
		assert_true(z._ragdoll_started)
		assert_not_null(z._ragdoll)
		var hips: PhysicalBone3D = z._ragdoll.get_node("PB_Hips")
		assert_true(hips.linear_velocity.is_finite())
		assert_gt(hips.linear_velocity.length(), 0.05, "ragdoll inherits the evaluated fall's momentum")
		z.deactivate()
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
		assert_eq(z._pivot.position, Vector3.ZERO, "pool reuse clears corpse root displacement")
		z.deactivate()
	# stop() frees detached physics bodies deferred, as it does in gameplay.
	await get_tree().process_frame
	await get_tree().process_frame

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
	assert_eq((info["loaded"] as Array).size(), (GLData.load_json("res://data/gravelight/zombie_mocap.json")["clips"] as Array).size())
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


## Co-op: a client's copy sees only the host's interpolated yaw (20 snapshots a second, 100 ms behind, with jitter and
## a lost packet now and then), never the destination. The real InterpBuffer carries a real host zombie's _face().
func _puppet_turn_run(degrees: float, jitter_ms: float, drop_every: int, seed_v: int, track_dps: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	add_child_autofree(root)
	var spawn := ZombieSpawn.new()
	root.add_child(spawn)
	var host := Zombie.new()
	root.add_child(host)
	var pup := Zombie.new()
	root.add_child(pup)
	for z: Zombie in [host, pup]:
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
		z.set_physics_process(false)
		z.set_process(false)
		z.rotation.y = 0.0
		z.set_posture("none", 0.0)
		z._enter(Zombie.State.CHASE)
		z._animate(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	pup.puppet = true
	pup.interp = InterpBuffer.new()
	pup.interp.snap(0.0, pup.global_position, 0.0)
	var yaw: float = deg_to_rad(degrees)
	var out: Dictionary = {"entered": 0, "max_step_deg": 0.0, "host_entered": false, "end_pivot": 0.0, "end_err": 0.0, "active_end": false}
	var acc: float = 0.0
	var sent: int = 0
	var last_visual: float = 0.0
	var was_turn: bool = false
	for tick: int in 240:
		var t_ms: float = float(tick + 1) * 1000.0 / 60.0
		if tick >= 30:
			if track_dps != 0.0:
				yaw = deg_to_rad(track_dps) * float(tick - 30) / 60.0
			host._face(host.position + Vector3(-sin(yaw), 0, -cos(yaw)) * 10.0)
		host._animate(1.0 / 60.0)
		if host._tree_state == "Turn": out["host_entered"] = true
		acc += 1.0 / 60.0
		if acc >= 1.0 / 20.0:
			acc = 0.0
			sent += 1
			if drop_every <= 0 or sent % drop_every != 0:
				# the wire's yaw is 16 bit; the arrival time wobbles
				var q: float = roundf(wrapf(host.rotation.y, -PI, PI) / PI * 32767.0) / 32767.0 * PI
				pup.interp.push(t_ms + rng.randf_range(0.0, jitter_ms), host.global_position, q, 0.0, int(Zombie.State.CHASE), 0)
		if pup.interp.sample(t_ms - 100.0):
			pup._puppet_apply_sample(1.0 / 60.0)
		pup._animate(1.0 / 60.0)
		var visual: float = pup.rotation.y + pup._pivot.rotation.y
		out["max_step_deg"] = maxf(float(out["max_step_deg"]), rad_to_deg(absf(wrapf(visual - last_visual, -PI, PI))))
		last_visual = visual
		var is_turn: bool = pup._tree_state == "Turn"
		if is_turn and not was_turn: out["entered"] = int(out["entered"]) + 1
		was_turn = is_turn
	out["end_pivot"] = rad_to_deg(absf(pup._pivot.rotation.y))
	out["end_err"] = rad_to_deg(absf(wrapf(pup.rotation.y - host.rotation.y, -PI, PI)))
	out["active_end"] = pup._turn_motion.active or pup._turn_motion.holding
	pup.deactivate()
	out["reset_ok"] = not pup._turn_motion.holding and pup._turn_motion.offset == 0.0
	host.deactivate()
	return out


func test_a_clients_copy_plays_the_recorded_turn_from_observed_yaw() -> void:
	if not ZombieClips.recorded_turns_enabled():
		pending("Local licensed root-yaw clips required")
		return
	var seed_v: int = 1
	for degrees: float in [35.0, 45.0, 60.0, -35.0, -45.0, -60.0]:
		for net: Array in [[0.0, 0], [18.0, 0], [18.0, 5]]:
			seed_v += 1
			var r: Dictionary = _puppet_turn_run(degrees, float(net[0]), int(net[1]), seed_v)
			var what: String = "%s deg, jitter %s ms, drop every %s" % [str(degrees), str(net[0]), str(net[1])]
			assert_true(bool(r["host_entered"]), "the host turns: " + what)
			assert_eq(int(r["entered"]), 1, "the client's copy plays one recorded turn: " + what)
			assert_lt(float(r["max_step_deg"]), 6.0, "no visual heading pop: " + what)
			assert_lt(float(r["end_pivot"]), 0.1, "it settles onto the gameplay heading: " + what)
			assert_lt(float(r["end_err"]), 0.1, "the body faces as the host's does: " + what)
			assert_false(bool(r["active_end"]), "nothing left running: " + what)
			assert_true(bool(r["reset_ok"]), "pool reuse clears the hold: " + what)


func test_a_clients_copy_does_not_step_on_small_or_slow_or_large_facing() -> void:
	if not ZombieClips.recorded_turns_enabled():
		pending("Local licensed root-yaw clips required")
		return
	# under the recorded range, over it, and slow tracking of a target walking round it
	for c: Array in [[12.0, 0.0], [20.0, 0.0], [110.0, 0.0], [170.0, 0.0], [0.0, 25.0], [0.0, 60.0]]:
		for seed_v: int in [3, 4, 5]:
			var r: Dictionary = _puppet_turn_run(float(c[0]), 18.0, 5, seed_v, float(c[1]))
			var what: String = "%s deg / tracking %s deg/s (seed %d)" % [str(c[0]), str(c[1]), seed_v]
			assert_eq(int(r["entered"]), 0, "no recorded turn: " + what)
			assert_lt(float(r["end_err"]), float(c[1]) * 0.13 + 0.1, "the body follows the host (a moving target is seen 100 ms late): " + what)


func test_a_facing_past_the_recorded_range_plays_no_partial_turn_on_the_host() -> void:
	if not ZombieClips.recorded_turns_enabled():
		pending("Local licensed root-yaw clips required")
		return
	var root := Node3D.new()
	add_child_autofree(root)
	var spawn := ZombieSpawn.new()
	root.add_child(spawn)
	var z := Zombie.new()
	root.add_child(z)
	for degrees: float in [90.0, 120.0, 170.0, -120.0]:
		z.activate({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, spawn, null)
		z.set_physics_process(false)
		z.set_process(false)
		z.rotation.y = 0.0
		z.set_posture("none", 0.0)
		z._enter(Zombie.State.CHASE)
		z._animate(0.3)
		var yaw: float = deg_to_rad(degrees)
		var target: Vector3 = z.position + Vector3(-sin(yaw), 0, -cos(yaw)) * 10.0
		var expected: float = 0.0
		var entered: bool = false
		for tick: int in 90:
			expected = lerp_angle(expected, yaw, 0.25)
			z._face(target)
			z._animate(1.0 / 60.0)
			assert_almost_eq(wrapf(z.rotation.y - expected, -PI, PI), 0.0, 0.00001, "gameplay facing response unchanged")
			entered = entered or z._tree_state == "Turn"
		assert_false(entered, "no recorded step for the remainder of a %s degree facing" % str(degrees))
		# once that facing has settled, an in-range one turns as before
		var yaw2: float = yaw + deg_to_rad(45.0)
		for tick: int in 120:
			z._face(z.position + Vector3(-sin(yaw2), 0, -cos(yaw2)) * 10.0)
			z._animate(1.0 / 60.0)
			entered = entered or z._tree_state == "Turn"
		assert_true(entered, "the next in-range facing plays its recorded turn")
		z.deactivate()
		assert_false(z._turn_motion.over_range, "pool reuse clears the over-range latch")
