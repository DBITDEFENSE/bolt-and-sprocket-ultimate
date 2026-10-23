extends Node
## Lighting shots: opens a GRAVELIGHT map in a real (off-screen, silent) window with no zombies, no bots and no
## HUD, and saves a PNG from every viewpoint in data/gravelight/lighting/shots_<map>.json, first with the power
## off, then (when the map has a power switch and the file says "power": true) again with the power on.
## Viewpoint file: {"scene": "res://...tscn", "power": true, "settle": 3.0,
##                  "views": [{"name": "taproom", "from": [x, y, z], "look": [x, y, z], "fov": 75}]}
## Silent, off-screen, no mouse capture (tools/light_shots.sh):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/light_shots.tscn \
##     -- --maps=map00,map01,map02 --tag=before [--out=DIR] [--preset=high]
## Output: morning/screenshots/lighting/<tag>/<map>_<view>[_power].png
## --dbg=N: viewport debug draw mode N (e.g. 18 = the GI buffer, to see what SDFGI adds).
## --fps: vsync off, and after each shot the frames rendered in the next second are counted; per-view numbers and
## the GPU time of the frame (ms, measured even when the driver caps the frame rate) go to <out>/fps.txt (a rough
## probe, not a benchmark).

var _out: String = ""
var _tag: String = "now"
var _maps: PackedStringArray = ["map00", "map01", "map02"]
var _scene: Node = null
var _saved: int = 0
var _fps: bool = false
var _fps_lines: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			_maps = a.substr(7).split(",", false)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--dbg="):
			get_viewport().debug_draw = int(a.substr(6)) as Viewport.DebugDraw
		elif a == "--fps":
			_fps = true
		elif a.begins_with("--preset="):
			GLSettings.values["graphics_preset"] = a.substr(9)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots/lighting").path_join(_tag)
	DirAccess.make_dir_recursive_absolute(_out)
	if _fps:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	GLSettings.values["subtitles"] = false   # no VO subtitles over the shots
	ProfileSave.path = "user://_qa_light_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	_saved += 1
	print("[light_shots] ", name)


func _run() -> void:
	for key: String in _maps:
		var f: String = "res://data/gravelight/lighting/shots_%s.json" % key
		if not FileAccess.file_exists(f):
			print("[light_shots] no viewpoint file %s" % f)
			continue
		await _map(key, GLData.load_json(f))
		if _scene != null and is_instance_valid(_scene):
			_scene.queue_free()
			_scene = null
		await _secs(1.0)
	print("[light_shots] %d shots in %s" % [_saved, _out])
	if _fps:
		var fa: FileAccess = FileAccess.open(_out.path_join("fps.txt"), FileAccess.WRITE)
		fa.store_string("\n".join(_fps_lines) + "\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


func _map(key: String, cfg: Dictionary) -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var n: Node = (load(str(cfg["scene"])) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	_scene = n
	var map: MapRoot = n as MapRoot
	GameState.god_mode = true
	await _secs(1.0)
	RoundManager.stop()
	if map != null and map.director != null:
		map.director.kill_all(true)
	if map != null and map.hud != null:
		map.hud.visible = false
	var cam: Camera3D = Camera3D.new()
	cam.near = 0.05
	cam.far = 900.0
	n.add_child(cam)
	cam.make_current()
	var settle: float = float(cfg.get("settle", 3.0))
	await _secs(settle)
	await _views(key, cfg, cam, "")
	if bool(cfg.get("power", false)):
		var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
		if sw != null and sw.has_method("run_sequence"):
			sw.call("run_sequence", 1)
			await _secs(float(cfg.get("power_settle", 8.0)))
			if map != null and map.director != null:
				map.director.kill_all(true)
			await _views(key, cfg, cam, "_power")
	GameState.god_mode = false


func _views(key: String, cfg: Dictionary, cam: Camera3D, suffix: String) -> void:
	for v: Dictionary in cfg.get("views", []):
		var from: Vector3 = _v3(v["from"])
		var look: Vector3 = _v3(v["look"])
		cam.fov = float(v.get("fov", 75.0))
		cam.global_position = from
		cam.look_at(look, Vector3.UP)
		await _secs(float(v.get("wait", 0.6)))   # volumetric fog and SDFGI catch up with the move
		await _shot("%s_%s%s" % [key, str(v["name"]), suffix])
		if _fps:
			var f0: int = Engine.get_frames_drawn()
			var t0: int = Time.get_ticks_usec()
			var gpu: float = 0.0
			var n: int = 0
			while Time.get_ticks_usec() - t0 < 1000000:
				await RenderingServer.frame_post_draw
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
				n += 1
			var fps: float = float(Engine.get_frames_drawn() - f0) / (float(Time.get_ticks_usec() - t0) / 1000000.0)
			_fps_lines.append("%s_%s%s %.1f %.2f" % [key, str(v["name"]), suffix, fps, gpu / maxf(1.0, float(n))])
			print("[light_shots] fps %.1f gpu %.2f ms" % [fps, gpu / maxf(1.0, float(n))])


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
