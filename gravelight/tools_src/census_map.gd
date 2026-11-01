extends Node
## Render census of one map (UPDATE 09 section 5, the audit for the Maps 3-4 rebuild; contract C4 budgets).
## Spawns the map like tools_src/capture.gd (god mode, no round, no bots), then walks the player through a camera
## set from data/gravelight/capture_cams.json and, at each camera, waits for the frame and prints what the renderer
## reports (draw calls, primitives, objects in the frame). It also counts what is in the scene tree: lights by type
## and shadow (and shadowed lights per zone, from the `zone` meta the generators put on power lights), geometry
## instances, static bodies, mesh triangles. Needs a renderer: run it through tools/wsl_godot.sh (software GL,
## invisible), never as a window on the owner's screen:
##   sh tools/wsl_godot.sh --path . res://gravelight/tools_src/census_map.tscn -- --set=u09_map04a [--only=A_wide,H_kranich]
## One line starting "CENSUS" is the summary; "CENSUS_CAM" lines are one per camera. Budgets (C4): <= 2500 draw
## calls in view, <= 6 shadowed lights per zone, <= 400k triangles in view (<= 200k on web).

var _set_name: String = ""
var _only: PackedStringArray = []
var _scene: Node = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			_set_name = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_census_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	var cfg: Dictionary = load_cams()
	var set_d: Dictionary = (cfg.get("sets", {}) as Dictionary).get(_set_name, {})
	if set_d.is_empty():
		print("CENSUS ERROR no camera set '%s'" % _set_name)
		get_tree().quit(1)
		return
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map_path: String = str(set_d["map"])
	var map: MapRoot = (load(map_path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	_scene = map
	GameState.god_mode = true
	await _secs(float(set_d.get("settle_s", 6.0)))
	RoundManager.stop()
	var p: Player = map.player
	if p == null:
		print("CENSUS ERROR the map has no player")
		get_tree().quit(1)
		return
	p.set_process_unhandled_input(false)
	# power on (the same as the capture sets' first camera), so the powered lights count
	if not GameState.power_on:
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		GLBus.power_activated.emit()
		await _secs(2.5)
	var stat: Dictionary = _scene_stats(map)
	var peak_dc: int = 0
	var peak_prim: int = 0
	var peak_obj: int = 0
	var cams: Array = set_d.get("cams", [])
	for i: int in cams.size():
		var cam: Dictionary = cams[i]
		var cname: String = str(cam.get("name", "cam%02d" % i))
		if not _only.is_empty() and not _only.has(cname):
			continue
		var pos: Vector3 = _v3(cam.get("pos", [0, 0, 0]))
		p.global_position = pos
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(float(cam.get("yaw", 0.0)))
		p.set("_pitch", deg_to_rad(float(cam.get("pitch", 0.0))))
		await _secs(1.5)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var prim: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var obj: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		peak_dc = maxi(peak_dc, dc)
		peak_prim = maxi(peak_prim, prim)
		peak_obj = maxi(peak_obj, obj)
		print("CENSUS_CAM %s draw_calls=%d primitives=%d objects=%d" % [cname, dc, prim, obj])
	var zl: Array = []
	var worst_zone: int = 0
	for z: Variant in (stat["shadow_by_zone"] as Dictionary).keys():
		var n: int = int((stat["shadow_by_zone"] as Dictionary)[z])
		worst_zone = maxi(worst_zone, n)
		zl.append("%s:%d" % [z, n])
	zl.sort()
	print("CENSUS map=%s set=%s draw_calls_peak=%d primitives_peak=%d objects_peak=%d" % [map_path.get_file(), _set_name, peak_dc, peak_prim, peak_obj])
	print("CENSUS lights omni=%d spot=%d directional=%d shadowed=%d shadowed_per_zone_max=%d (%s)" % [stat["omni"], stat["spot"], stat["dir"], stat["shadowed"], worst_zone, ", ".join(zl)])
	print("CENSUS scene geometry_instances=%d mesh_instances=%d multimesh=%d static_bodies=%d collision_shapes=%d mesh_triangles_total=%d nodes=%d" % [
		stat["geom"], stat["mesh"], stat["multimesh"], stat["bodies"], stat["shapes"], stat["tris"], stat["nodes"]])
	print("CENSUS render_info total_objects=%d video_mem=%.1f MB texture_mem=%.1f MB" % [
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	GameState.god_mode = false
	get_tree().quit()


## Counts over the whole tree: lights, geometry, bodies, triangles of every distinct mesh instance.
func _scene_stats(root: Node) -> Dictionary:
	var s: Dictionary = {"omni": 0, "spot": 0, "dir": 0, "shadowed": 0, "geom": 0, "mesh": 0, "multimesh": 0,
		"bodies": 0, "shapes": 0, "tris": 0, "nodes": 0, "shadow_by_zone": {}}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		s["nodes"] = int(s["nodes"]) + 1
		for c: Node in n.get_children():
			stack.append(c)
		if n is Light3D:
			var l: Light3D = n as Light3D
			if not l.is_visible_in_tree():
				continue
			if l is OmniLight3D:
				s["omni"] = int(s["omni"]) + 1
			elif l is SpotLight3D:
				s["spot"] = int(s["spot"]) + 1
			else:
				s["dir"] = int(s["dir"]) + 1
			if l.shadow_enabled:
				s["shadowed"] = int(s["shadowed"]) + 1
				var z: String = str(l.get_meta("zone", "(none)"))
				var d: Dictionary = s["shadow_by_zone"]
				d[z] = int(d.get(z, 0)) + 1
		elif n is StaticBody3D or n is AnimatableBody3D:
			s["bodies"] = int(s["bodies"]) + 1
		elif n is CollisionShape3D:
			s["shapes"] = int(s["shapes"]) + 1
		if n is GeometryInstance3D:
			s["geom"] = int(s["geom"]) + 1
			if n is MeshInstance3D:
				s["mesh"] = int(s["mesh"]) + 1
				var m: Mesh = (n as MeshInstance3D).mesh
				if m != null:
					for k: int in m.get_surface_count():
						var arr: Array = m.surface_get_arrays(k)
						var idx: Variant = arr[Mesh.ARRAY_INDEX]
						if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
							s["tris"] = int(s["tris"]) + (idx as PackedInt32Array).size() / 3
						elif arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
							s["tris"] = int(s["tris"]) + (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			elif n is MultiMeshInstance3D:
				s["multimesh"] = int(s["multimesh"]) + 1
	return s


static func load_cams() -> Dictionary:
	var f: FileAccess = FileAccess.open("res://data/gravelight/capture_cams.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
