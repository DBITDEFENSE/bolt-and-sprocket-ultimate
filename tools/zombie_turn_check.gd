extends "res://gravelight/tools_src/shots_zombie_anim.gd"
## Live facing + AnimationTree turn check. --capture [--legacy-zombie-turns] [--interrupt=move|attack]
var actor: Zombie
var started: bool = false
var finished: bool = false
var capture: bool = false
var interrupt: String = ""
var elapsed: float = 0.0
var frames: int = 0
var expected_yaw: float = 0.0
var old_visual_yaw: float = 0.0
var worst_facing_error: float = 0.0
var worst_visual_step: float = 0.0
var old_toes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var old_ids: Array[int] = [-1, -1]
var contacts: Array[float] = []
var played: Dictionary = {}
var samples: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void:
	GLConsole.set_process_unhandled_input(false)
	_out = "res://docs/captures/after/mocap/turns/check"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.substr(6)
		elif arg == "--capture": capture = true
		elif arg.begins_with("--interrupt="): interrupt = arg.substr(12)
	DirAccess.make_dir_recursive_absolute(_out)
	seed(74119)
	GameState.map_id = &"map01_kaltenbrunn"
	_build_studio()
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.set_process(false)
	actor = _place_new({"enemy_id":"ganger", "variant":"soldier", "tier":"walk"}, Vector3(2, 0, 0))
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.target = null
	actor.rotation.y = 0.0
	actor.set_posture("hunch", 0.5)
	actor._enter(Zombie.State.CHASE)
	actor._animate(0.3)
	# the final pose (after the body modifier's terrain IK and the contact lock, which runs inside it) is only
	# readable here: by the next _process a modifier's result has been rolled back
	actor._skel.skeleton_updated.connect(_on_final_pose)
	_cam.position = Vector3(3.6, 1.5, -3.0)
	_cam.look_at(Vector3(2, 0.9, 0))
	_cam.fov = 48.0
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 24)
	ui.add_child(_label)
	# Warm the rendered shader before collecting a comparable first frame.
	if DisplayServer.get_name() != "headless":
		var warm: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - warm < 1000: await get_tree().process_frame
	started = true

func _physics_process(delta: float) -> void:
	if not started or finished: return
	elapsed += delta
	var heading: float = PI/4.0 if elapsed >= 1.0 and elapsed < 3.5 else 0.0
	expected_yaw = lerp_angle(expected_yaw, heading, 0.25)
	actor._face(actor.global_position + Vector3(-sin(heading), 0, -cos(heading)) * 10.0)
	worst_facing_error = maxf(worst_facing_error, absf(wrapf(actor.rotation.y - expected_yaw, -PI, PI)))
	if elapsed >= 1.4 and interrupt == "move": actor.velocity = Vector3(0, 0, -actor.speed)
	elif elapsed >= 1.4 and interrupt == "attack" and actor.state != Zombie.State.ATTACK:
		actor._enter(Zombie.State.ATTACK)
	actor._state_t += delta

func _process(delta: float) -> void:
	if not started or finished: return
	actor._animate(delta)
	frames += 1
	var visual_yaw: float = actor.rotation.y + actor._pivot.rotation.y
	if frames > 1: worst_visual_step = maxf(worst_visual_step, absf(wrapf(visual_yaw - old_visual_yaw, -PI, PI)))
	old_visual_yaw = visual_yaw
	if actor._tree_state == "Turn": played[actor._turn_motion.clip] = true
	_frame_delta = delta
	var mode: String = "AFTER / recorded turn" if ZombieClips.recorded_turns_enabled() else "BEFORE / existing turn"
	_label.text = "%s  |  %.2f s  |  %s" % [mode, elapsed, actor._tree_state]
	if frames % 5 == 0:
		samples.append({"seconds":elapsed, "body_degrees":rad_to_deg(actor.rotation.y), "visual_degrees":rad_to_deg(visual_yaw), "state":actor._tree_state, "recording_seconds":actor._turn_motion.clock})
		if capture:
			await RenderingServer.frame_post_draw
			if get_viewport().get_texture().get_image().save_png("%s/frame_%05d.png" % [_out, frames/5]) != OK: failures.append("capture failed")
	if elapsed >= 6.0: _finish_turn()

var _frame_delta: float = 1.0 / 60.0

func _on_final_pose() -> void:
	if not started or finished: return
	for side: int in 2:
		var foot: int = actor._skel.find_bone("LeftFoot" if side == 0 else "RightFoot")
		var toe: Vector3 = actor._skel.global_transform * (actor._skel.get_bone_global_pose(foot) * Vector3(0, -0.06, -0.15))
		var id: int = actor._contact_lock.intervals[side]
		if actor._tree_state == "Turn" and id >= 0 and id == old_ids[side]:
			var d: Vector3 = toe - old_toes[side]
			contacts.append(Vector2(d.x, d.z).length() / maxf(_frame_delta, 0.0001))
		old_toes[side] = toe
		old_ids[side] = id

func _finish_turn() -> void:
	finished = true
	contacts.sort()
	var p95: float = contacts[int(contacts.size()*0.95)] if not contacts.is_empty() else -1.0
	if worst_facing_error > 0.0001: failures.append("gameplay facing changed")
	if ZombieClips.recorded_turns_enabled() and interrupt.is_empty():
		if played.size() != 2: failures.append("both recorded directions not exercised")
		if contacts.size() < 50 or p95 > 0.10: failures.append("stationary turn contact drift")
		if rad_to_deg(worst_visual_step) > 5.0: failures.append("visual heading stepped over 5 degrees at 60 Hz")
	if absf(actor._pivot.rotation.y) > 0.001: failures.append("turn offset did not clear")
	if not interrupt.is_empty() and actor._turn_motion.active: failures.append("turn survived interruption")
	var report := {"failures":failures, "clips":played.keys(), "contact_samples":contacts.size(), "contact_p95_mps":p95, "body_facing_error_degrees":rad_to_deg(worst_facing_error), "max_visual_yaw_step_degrees":rad_to_deg(worst_visual_step), "interrupt":interrupt, "frames":frames, "samples":samples, "scope":"Fixed-60 stationary studio, real facing function/tree, source-contact toe drift after entry blend. Not full-map or network coverage."}
	var file := FileAccess.open(_out.path_join("turn.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ZOMBIE_TURN_CHECK ", JSON.stringify(report))
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
