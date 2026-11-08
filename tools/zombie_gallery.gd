extends "res://gravelight/tools_src/shots_zombie_anim.gd"
## Baseline viewer. --horde runs real AI; default previews every registered clip on every outfit.
## --capture saves frames (requires rendering); --out=res://docs/captures/before
## --seconds=60 controls horde duration. No settings/profile saves; no synthetic animation keys.

var horde: bool = false
var capture: bool = false
var seconds: float = 60.0
var elapsed: float = 0.0
var ready_gallery: bool = false
var clip_index: int = -1
var clip_time: float = 0.0
var clips: PackedStringArray
var frames: Array[float] = []
var slips: Array[float] = []
var previous_feet: Dictionary = {}
var phase_bins: Dictionary = {}
var captures: int = 0
var missing: Array[String] = []
var peak_ragdolls: int = 0
var zero_pose_samples: int = 0
var sample_count: int = 0
var finished: bool = false
var min_active: int = 24
var moving_samples: int = 0

func _ready() -> void:
	seed(74119)
	# Tool owns its input; the project's console references a missing action in this baseline.
	for autoload: Node in get_tree().root.get_children():
		if autoload.get_script() != null and str(autoload.get_script().resource_path).ends_with("/dev_console.gd"):
			autoload.set_process_unhandled_input(false)
	_out = "res://docs/captures/before"
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--horde": horde = true
		elif arg == "--capture": capture = true
		elif arg.begins_with("--seconds="): seconds = maxf(2.0, float(arg.substr(10)))
		elif arg.begins_with("--out="): _out = arg.substr(6)
	if capture and DisplayServer.get_name() == "headless":
		push_error("Screenshots require a rendered run; omit --headless.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	GameState.map_id = &"map01_kaltenbrunn"
	_build_studio()
	await get_tree().process_frame
	while NavigationServer3D.map_get_iteration_id(_studio.get_world_3d().navigation_map) == 0:
		await get_tree().physics_frame
	_player.set_physics_process(false)
	_player.position = Vector3(0, 0.1, -35)
	_cam.position = Vector3(0, 5, -12)
	_cam.look_at(Vector3(0, 1, 5))
	# Replace the legacy capture's violet fill with neutral warm studio illumination.
	for light: Node in _studio.get_children():
		if light is OmniLight3D: light.light_color = Color(1.0, 0.85, 0.68)
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(20, 20)
	ui.add_child(_label)
	var kits: Array = GLData.table("anim")["kits"].keys().filter(func(k: String) -> bool: return not k.begins_with("_"))
	for i: int in 24:
		var kit: String = str(kits[i % kits.size()])
		var z: Zombie = _place_new({"enemy_id": "ganger", "variant": kit, "tier": TIERS[i % TIERS.size()], "health": 1000}, Vector3((i % 8 - 3.5) * 1.6, 0, 3 + (i / 8) * 3))
		z.call("_enter", Zombie.State.CHASE)
		if not horde:
			z.set_physics_process(false)
			var label := Label3D.new()
			label.text = kit
			label.position.y = 2.25
			label.font_size = 24
			z.add_child(label)
	clips = ZombieClips.library().get_animation_list()
	var inventory: Dictionary = {"bones": Array(ZombieRig.bone_names()), "kits": kits, "clips": [], "source": "Existing procedural ZombieClips library; NOT mocap"}
	for clip: String in clips:
		var anim: Animation = ZombieClips.library().get_animation(clip)
		inventory["clips"].append({"name": clip, "seconds": anim.length, "tracks": anim.get_track_count(), "loop": anim.loop_mode})
	_write_json("runtime_inventory.json", inventory)
	ready_gallery = true

func _process(delta: float) -> void:
	if not ready_gallery or finished: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Zombie.repath_budget = 6
	elapsed += delta
	peak_ragdolls = maxi(peak_ragdolls, ZombieRagdoll.live_count())
	if horde:
		var active_count: int = 0
		for actor: Zombie in _new:
			if actor.state != Zombie.State.INACTIVE: active_count += 1
		min_active = mini(min_active, active_count)
		_label.text = "LIVE AI BASELINE | 24 zombies | %.1f / %.1f s" % [elapsed, seconds]
		if elapsed > 2.0: frames.append(delta * 1000.0)
		if capture and elapsed > 3.0 and captures == 0:
			captures = 1
			_save_frame("horde_24")
		for z: Zombie in _new:
			if z.position.z < -12:
				z.position.z = 12
				previous_feet.erase(z.get_instance_id())
		if elapsed >= seconds: _finish()
		return
	clip_time += delta
	if clip_index < 0 or clip_time >= maxf(1.0, ZombieClips.length_of(clips[clip_index])):
		clip_index += 1
		clip_time = 0
		if clip_index >= clips.size():
			_finish()
			return
		var clip: String = clips[clip_index]
		_label.text = "CLIP PREVIEW (not gameplay) | %s | %d / %d" % [clip, clip_index + 1, clips.size()]
		for z: Zombie in _new:
			var tree: AnimationTree = z.get("_tree")
			tree.active = false
			var ap: AnimationPlayer = z.get("_ap")
			if not ap.has_animation(clip): missing.append(clip)
			else: ap.play(clip)
	# Preview root translation is shown, not discarded; reset only at the next clip.
	if capture and clip_time > 0.35 and captures == clip_index:
		captures += 1
		_save_frame("clip_%03d_%s" % [clip_index, clips[clip_index]])

func _physics_process(delta: float) -> void:
	if not ready_gallery or not horde or finished or elapsed < 2: return
	var bins: Dictionary = {}
	for z: Zombie in _new:
		var sk: Skeleton3D = z.get("_skel")
		if sk == null: continue
		var id: int = z.get_instance_id()
		var old: Dictionary = previous_feet.get(id, {})
		var now: Dictionary = {}
		for bone: String in ["LeftFoot", "RightFoot"]:
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
			now[bone] = p
			if old.has(bone) and z.current_clip_state() == "Locomotion" and Vector2(z.velocity.x, z.velocity.z).length() > 0.4:
				var v: Vector3 = (p - (old[bone] as Vector3)) / delta
				# Contact heuristic, not authored contact labels: low foot and low vertical velocity.
				if p.y < 0.14 and absf(v.y) < 0.2:
					slips.append(Vector2(v.x, v.z).length())
		previous_feet[id] = now
		if Vector2(z.velocity.x, z.velocity.z).length() > 0.4: moving_samples += 1
		var rest: bool = true
		for b: int in sk.get_bone_count():
			if sk.get_bone_pose_rotation(b).angle_to(Quaternion.IDENTITY) > 0.02: rest = false
		if rest: zero_pose_samples += 1
		sample_count += 1
		var playback: AnimationNodeStateMachinePlayback = z.get("_playback")
		var phase: float = playback.get_current_play_position() / maxf(0.001, playback.get_current_length())
		var bin: int = int(fposmod(phase, 1.0) * 16) % 16
		bins[bin] = int(bins.get(bin, 0)) + 1
	for key: int in bins:
		phase_bins[str(key)] = maxi(int(phase_bins.get(str(key), 0)), int(bins[key]))

func _save_frame(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var err: Error = get_viewport().get_texture().get_image().save_png(_out.path_join(stem + ".png"))
	if err != OK: missing.append("capture error %s: %d" % [stem, err])

func _percentile(values: Array[float], fraction: float) -> Variant:
	if values.is_empty(): return null
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * fraction))]

func _write_json(filename: String, value: Dictionary) -> void:
	var f := FileAccess.open(_out.path_join(filename), FileAccess.WRITE)
	if f == null:
		push_error("Cannot write gallery report: " + filename)
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify(value, "\t"))

func _finish() -> void:
	finished = true
	var result := {"mode": "horde" if horde else "clip_preview", "seconds": elapsed, "zombies": _new.size(), "rendered": DisplayServer.get_name() != "headless", "frame_ms_p50": _percentile(frames, 0.5), "frame_ms_p95": _percentile(frames, 0.95), "planted_foot_speed_mps_p50": _percentile(slips, 0.5), "planted_foot_speed_mps_p95": _percentile(slips, 0.95), "contact_samples": slips.size(), "contact_method": "y < 0.14m and abs(vertical velocity) < 0.2m/s; heuristic only", "rest_pose_samples": zero_pose_samples, "pose_samples": sample_count, "phase_bin_peak_occupancy": phase_bins, "ragdoll_peak": peak_ragdolls, "missing": missing, "limitations": "Headless timing excludes GPU. Rest-pose heuristic does not prove zero T-poses or pops. Ragdolls are not exercised by horde mode. Preview bypasses gameplay transitions. No target-machine performance sign-off."}
	result["min_active"] = min_active
	result["moving_pose_samples"] = moving_samples
	result["contact_requires_body_speed_mps"] = 0.4
	_write_json("horde.json" if horde else "preview.json", result)
	print("[zombie_gallery] ", JSON.stringify(result))
	_clear()
	_studio.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if missing.is_empty() else 1)
