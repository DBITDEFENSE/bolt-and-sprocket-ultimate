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
var only_clip: String = ""
var only_kit: String = ""
var only_kind: String = "ganger"
var frame_sequence: bool = false
var sequence_next: float = 0.0
var sequence_frame: int = 0
var emerge_together: bool = false
var wrap_count: int = 0
var inactive_events: Array[Dictionary] = []
var last_actor_state: Dictionary = {}
var state_samples: Dictionary = {}
var validation_failures: Array[String] = []
var full_rate: bool = false
var actor_count: int = 24
var only_tier: String = ""
var follow_actor: bool = false

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
		elif arg.begins_with("--clip="): only_clip = arg.substr(7)
		elif arg.begins_with("--kit="): only_kit = arg.substr(6)
		elif arg.begins_with("--kind="): only_kind = arg.substr(7)
		elif arg == "--frames": frame_sequence = true
		elif arg == "--emerge": emerge_together = true
		elif arg == "--full-rate": full_rate = true
		elif arg.begins_with("--count="): actor_count = clampi(int(arg.substr(8)), 1, 24)
		elif arg.begins_with("--tier="): only_tier = arg.substr(7)
		elif arg == "--follow": follow_actor = true
	if capture and DisplayServer.get_name() == "headless":
		push_error("Screenshots require a rendered run; omit --headless.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	GameState.map_id = &"map01_kaltenbrunn"
	if full_rate: Zombie.anim_lod_scale = 100.0
	_build_studio()
	await get_tree().process_frame
	while NavigationServer3D.map_get_iteration_id(_studio.get_world_3d().navigation_map) == 0:
		await get_tree().physics_frame
	_player.set_physics_process(false)
	_player.position = Vector3(0, 0.1, -35)
	_cam.position = Vector3(0, 5, -12)
	_cam.look_at(Vector3(0, 1, 5))
	if not horde:
		_cam.position = Vector3(0, 6, -5)
		_cam.look_at(Vector3(0, 1, 6))
		_cam.fov = 55
		if not only_kit.is_empty():
			_cam.position = Vector3(0.6, 1.5, -3.3)
			_cam.look_at(Vector3(0, 1.0, 0))
	# Replace the legacy capture's violet fill with neutral warm studio illumination.
	for light: Node in _studio.get_children():
		if light is OmniLight3D: light.light_color = Color(1.0, 0.85, 0.68)
		# The inherited legacy/new divider crosses the solo preview's ankles.
		if light is MeshInstance3D and light.mesh is BoxMesh and light.mesh.size == Vector3(0.2, 0.3, 80):
			light.queue_free()
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(20, 20)
	ui.add_child(_label)
	var kits: Array = GLData.table("anim")["kits"].keys().filter(func(k: String) -> bool: return not k.begins_with("_"))
	if not only_kit.is_empty():
		if not kits.has(only_kit):
			push_error("Unknown kit: " + only_kit)
			get_tree().quit(2)
			return
		kits = [only_kit]
	if not GLData.table("enemies")["enemies"].has(only_kind) or only_kind in ["foreman", "screamer"]:
		push_error("Unknown kind or bespoke boss unsupported by this shared-rig viewer: " + only_kind)
		get_tree().quit(2)
		return
	if not only_tier.is_empty() and not GLData.table("enemies")["tiers"].has(only_tier) and only_tier != "crawl":
		push_error("Unknown tier: " + only_tier)
		get_tree().quit(2)
		return
	if not horde and not only_kit.is_empty(): actor_count = 1
	min_active = actor_count
	for i: int in actor_count:
		var kit: String = str(kits[i % kits.size()])
		var at: Vector3 = Vector3((i % 8 - 3.5) * 1.6, 0, 3 + (i / 8) * 3) if actor_count > 1 else Vector3(3, 0, 3) if horde else Vector3.ZERO
		var tier_name: String = only_tier if not only_tier.is_empty() and only_tier != "crawl" else str(TIERS[i % TIERS.size()])
		var z: Zombie = _place_new({"enemy_id": only_kind, "variant": kit, "tier": tier_name, "crawler": only_tier == "crawl", "health": 1000}, at)
		if not emerge_together or not horde:
			z.call("_enter", Zombie.State.CHASE)
		if not horde:
			z.set_physics_process(false)
			z.rotation.y = 0
			var label := Label3D.new()
			label.text = kit
			label.position.y = 2.25
			label.font_size = 24
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			z.add_child(label)
	clips = ZombieClips.library().get_animation_list()
	if not only_clip.is_empty():
		if not clips.has(only_clip):
			push_error("Unknown clip: " + only_clip)
			get_tree().quit(2)
			return
		clips = [only_clip]
	var inventory: Dictionary = {"bones": Array(ZombieRig.bone_names()), "kits": kits, "clips": [], "source": "Existing procedural library plus locally converted licensed clips (mco_ prefix)", "mocap": ZombieClips.mocap_info()}
	for clip: String in clips:
		var anim: Animation = ZombieClips.library().get_animation(clip)
		inventory["clips"].append({"name": clip, "seconds": anim.length, "tracks": anim.get_track_count(), "loop": anim.loop_mode, "source": anim.get_meta("source", "existing procedural library")})
	_write_json("runtime_inventory.json", inventory)
	ready_gallery = true

func _process(delta: float) -> void:
	if not ready_gallery or finished: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Zombie.repath_budget = 6
	elapsed += delta
	peak_ragdolls = maxi(peak_ragdolls, ZombieRagdoll.live_count())
	if horde:
		if follow_actor and not _new.is_empty():
			_cam.position = _new[0].position + Vector3(2.2, 1.5, -4.0)
			_cam.look_at(_new[0].position + Vector3.UP)
		var active_count: int = 0
		for actor: Zombie in _new:
			if actor.is_active(): active_count += 1
			var actor_id: int = actor.get_instance_id()
			var state_name: String = Zombie.State.keys()[actor.state]
			state_samples[state_name] = int(state_samples.get(state_name, 0)) + 1
			if not actor.is_active() and not bool(last_actor_state.get(actor_id, {}).get("inactive", false)):
				inactive_events.append({"actor": actor_id, "seconds": elapsed, "state": state_name, "previous": last_actor_state.get(actor_id, {})})
			last_actor_state[actor_id] = {"inactive": not actor.is_active(), "state": state_name, "position": str(actor.position), "no_progress_seconds": actor.get("_progress_t"), "stuck_seconds": actor.get("_stuck_t")}
		min_active = mini(min_active, active_count)
		_label.text = "LIVE AI | %d active zombies | %.1f / %.1f s" % [active_count, elapsed, seconds]
		if elapsed > 2.0: frames.append(delta * 1000.0)
		if capture and elapsed > (6.0 if emerge_together else 3.0) and captures == 0:
			captures = 1
			_save_frame("horde_24")
		if capture and frame_sequence and elapsed >= sequence_next:
			sequence_next += 1.0 / 12.0
			_save_frame("horde_frame_%04d" % sequence_frame)
			sequence_frame += 1
		for z: Zombie in _new:
			if z.is_active() and z.position.z < -12:
				z.position.z = 12
				# This is a tool-owned discontinuity, not lack of navigation progress.
				# Rebase distance watches after the wrap; ordinary stalls still recycle/fail.
				z.set("_progress_best", INF)
				z.set("_progress_t", 0.0)
				z.set("_stuck_origin", z.global_position)
				z.set("_stuck_t", 0.0)
				z.set("_tick_prev", Vector3.INF)
				z.reset_physics_interpolation()
				wrap_count += 1
				previous_feet.erase(z.get_instance_id())
		if elapsed >= seconds: _finish()
		return
	clip_time += delta
	if follow_actor and not _new.is_empty():
		var sk: Skeleton3D = _new[0].get("_skel")
		var origin: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Root")).origin
		_cam.position = origin + Vector3(2.2, 1.5, -4.0)
		_cam.look_at(origin + Vector3.UP)
	if clip_index < 0 or clip_time >= maxf(1.0, ZombieClips.length_of(clips[clip_index])):
		clip_index += 1
		clip_time = 0
		sequence_next = 0
		sequence_frame = 0
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
			else:
				ap.play(clip)
				ap.advance(0.0) # Evaluate before capture, avoiding a tool-only rest frame.
	if capture and frame_sequence and clip_time >= sequence_next:
		sequence_next += 1.0 / 12.0
		_save_frame("sequence_%03d_%s_%04d" % [clip_index, clips[clip_index], sequence_frame])
		sequence_frame += 1
	# Preview root translation is shown, not discarded; reset only at the next clip.
	if capture and clip_time > 0.35 and captures == clip_index:
		captures += 1
		_save_frame("clip_%03d_%s" % [clip_index, clips[clip_index]])

func _physics_process(delta: float) -> void:
	if not ready_gallery or not horde or finished or elapsed < 2: return
	var bins: Dictionary = {}
	for z: Zombie in _new:
		if not z.is_active(): continue
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
	result["full_rate_animation"] = full_rate
	result["requested_active"] = actor_count
	result["tier"] = only_tier
	result["track_wraps"] = wrap_count
	result["inactive_events"] = inactive_events
	result["state_samples"] = state_samples
	result["capture_affects_timing"] = capture and frame_sequence
	result["validation_scope"] = "Active population, missing resources/captures, sampled rest poses only. Not art or foot-contact acceptance."
	result["quality_acceptance"] = "NOT CERTIFIED: mixed legacy/mocap library; full state and planted-contact runtime acceptance still required"
	if horde and min_active < actor_count:
		validation_failures.append("Expected %d active zombies throughout; minimum was %d" % [actor_count, min_active])
	if not missing.is_empty(): validation_failures.append("Missing clips or failed captures")
	if zero_pose_samples > 0: validation_failures.append("Sampled identity/rest poses")
	result["validation_failures"] = validation_failures
	_write_json("horde.json" if horde else "preview.json", result)
	print("[zombie_gallery] ", JSON.stringify(result))
	_clear()
	_studio.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The studio's Player loads weapon templates stored as unattached Nodes. Release them
	# only on tool exit; do not alter the shared gameplay cache's lifecycle here.
	for template: Node in WeaponModels._templates.values():
		if is_instance_valid(template): template.free()
	WeaponModels._templates.clear()
	get_tree().quit(0 if validation_failures.is_empty() else 1)
