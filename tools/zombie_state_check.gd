extends "res://gravelight/tools_src/shots_zombie_anim.gd"
## Actual attack/death state playback, with fixed 60 Hz timing and optional rendered frames.
## --case=swipe_l|swipe_r|death_sit|death_back --out=... [--capture] [--legacy-zombies]
var chosen: String = "swipe_r"
var capture: bool = false
var ready_actor: bool = false
var finished: bool = false
var actor: Zombie
var elapsed: float = 0.0
var frames: int = 0
var next_start: float = 1.0
var hits: Array[Dictionary] = []
var handoffs: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void:
	# A silent capture must not process keyboard input from the owner's desktop.
	GLConsole.set_process_unhandled_input(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.substr(6)
		elif arg.begins_with("--case="): chosen = arg.substr(7)
		elif arg == "--capture": capture = true
	if not chosen in ["swipe_l", "swipe_r", "death_sit", "death_back"]:
		push_error("Unknown state case: " + chosen)
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	seed(74119)
	GLSettings.values["gore"] = "full"
	GameState.map_id = &"map01_kaltenbrunn"
	_build_studio()
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.set_process(false)
	actor = _place_new({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, Vector3(2, 0, 0))
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.target = null
	actor.set_posture("hunch", 0.5)
	actor._enter(Zombie.State.CHASE)
	actor._animate(0.3)
	_cam.position = Vector3(3.7, 1.4, -2.8)
	_cam.look_at(Vector3(2, 0.9, 0.3))
	_cam.fov = 52.0
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(_label)
	ready_actor = true

func _physics_process(delta: float) -> void:
	if not ready_actor or finished: return
	elapsed += delta
	if elapsed >= next_start:
		if chosen.begins_with("swipe"):
			actor._enter(Zombie.State.ATTACK)
			actor._attack_clip = chosen
			actor._tree_attack(chosen)
			next_start += 1.5
		else:
			actor._death_clip = chosen
			actor._start_death()
			next_start = INF
	actor._state_t += delta
	if actor.state == Zombie.State.ATTACK:
		var previous_hit: bool = actor._attack_hit_done
		actor._update_attack(delta)
		if actor._attack_hit_done and not previous_hit:
			hits.append({"state_time": actor._state_t, "windup": actor._cfg["attack_windup"]})
	elif actor.state == Zombie.State.DEAD:
		# PNG capture can take longer than simulated time. Keep the wall-clock freeze budget
		# aligned to this fixed-step studio clock; production's real-time clock is unchanged.
		if actor._ragdoll != null and not handoffs.is_empty():
			for entry: Array in ZombieRagdoll._live:
				if entry[0] == actor._ragdoll:
					entry[1] = Time.get_ticks_msec() - int((actor._state_t - float(handoffs[0]["time"])) * 1000.0)
		var before: Array[Vector3] = []
		if not actor._ragdoll_started:
			for bone: int in actor._skel.get_bone_count():
				before.append(actor._skel.get_bone_global_pose(bone).origin)
		actor._update_dead(delta)
		if not before.is_empty() and actor._ragdoll_started:
			var jump: float = 0.0
			for bone: int in before.size():
				jump = maxf(jump, before[bone].distance_to(actor._skel.get_bone_global_pose(bone).origin))
			var hips: PhysicalBone3D = actor._ragdoll.get_node("PB_Hips")
			handoffs.append({"time": actor._state_t, "expected": ZombieClips.death_key_pose_time(chosen), "immediate_bone_jump_m": jump, "pivot_offset": var_to_str(actor._pivot.position), "hips_velocity_mps": var_to_str(hips.linear_velocity)})

func _process(delta: float) -> void:
	if not ready_actor or finished: return
	actor._animate(delta)
	_label.text = ("AFTER / mocap" if ZombieClips.mocap_enabled() else "BEFORE / legacy") + "  |  " + chosen + "  |  %.2f s" % elapsed
	if actor._ragdoll != null: _label.text += "  |  physics"
	frames += 1
	if capture and frames % 5 == 0:
		await RenderingServer.frame_post_draw
		var err: Error = get_viewport().get_texture().get_image().save_png("%s/frame_%05d.png" % [_out, frames / 5])
		if err != OK: failures.append("capture failed")
	if elapsed >= 6.0 and not finished: _finish_check()

func _finish_check() -> void:
	finished = true
	if chosen.begins_with("swipe"):
		if hits.size() < 3: failures.append("fewer than three actual hit events")
		for hit: Dictionary in hits:
			if absf(float(hit["state_time"]) - float(hit["windup"])) > 1.0/60.0 + 0.0001: failures.append("hit timing changed")
	else:
		if handoffs.size() != 1: failures.append("expected one ragdoll handoff")
		for handoff: Dictionary in handoffs:
			if float(handoff["immediate_bone_jump_m"]) > 0.02: failures.append("pose jumped on ragdoll handoff")
	var report := {"case": chosen, "visual_clip": ZombieClips.visual_clip(chosen), "hits": hits, "handoffs": handoffs, "failures": failures, "seconds": elapsed, "scope": "Actual state callbacks/tree/ragdoll in studio; forced clip selection; freeze clock normalized to simulated time; no player damage/range test"}
	var file := FileAccess.open(_out.path_join("state.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ZOMBIE_STATE_CHECK ", JSON.stringify(report))
	_clear()
	_studio.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	for template: Node in WeaponModels._templates.values():
		if is_instance_valid(template): template.free()
	WeaponModels._templates.clear()
	for scene: Node in Arms._scenes.values():
		if is_instance_valid(scene): scene.free()
	Arms._scenes.clear()
	get_tree().quit(0 if failures.is_empty() else 1)
