extends Node
## UPDATE 12 §5 (T-211): GRAVELIGHT ONE's acceptance captures and its frame log, in one short off-screen run.
## Captures (JPG, 1280x720) from the inn's front door, the field (two sides), inside the cabin and inside the cockpit,
## then a frame log: vsync off, `--perf_s` seconds at each of three views (the inn's door, the field, the cabin),
## the mean / p95 frame time and FPS printed as `[c47] perf <view> ...` lines and written to <out>/perf.json.
## Usage (C3: the GPU lock, off-screen, silent):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_c47.tscn \
##     -- --out=<dir> [--tag=before|after] [--perf_s=6] [--no-perf]

var MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN: Script = preload("res://gravelight/tools_src/gen_map00.gd")

var _map: Node3D
var _cam: Camera3D
var _out: String = "user://shots_c47"
var _tag: String = "after"
var _perf_s: float = 6.0
var _perf: bool = true
var _t: float = 0.0
var _busy: bool = false
var _started: bool = false


## [name, eye, target, frame (wreck = the wreck's local frame, world = map coordinates), fov]
func _views() -> Array:
	return [
		["inn_door", Vector3(22.2, 1.65, -2.8), Vector3(46.0, 1.4, 6.0), "world", 62.0],
		["field_nw", Vector3(35.5, 1.7, -7.5), Vector3(46.0, 1.3, 6.5), "world", 62.0],
		["field_se", Vector3(8.5, 1.7, 10.0), Vector3(-1.0, 1.0, 0.0), "wreck", 66.0],
		["field_tail", Vector3(-6.0, 1.7, 15.5), Vector3(0.5, 1.2, 3.0), "wreck", 66.0],
		["cabin", Vector3(0.15, 1.75, 4.7), Vector3(0.0, 1.05, -4.6), "wreck", 72.0],
		["cockpit", Vector3(0.05, 1.95, -4.55), Vector3(-0.25, 0.85, -6.5), "wreck", 70.0],
	]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--perf_s="):
			_perf_s = float(a.substr(9))
		elif a.begins_with("--map="):
			MAP = a.substr(6)
		elif a == "--no-perf":
			_perf = false
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)


func _place(v: Array) -> void:
	var eye: Vector3 = v[1]
	var tgt: Vector3 = v[2]
	if str(v[3]) == "wreck":
		eye = GEN.wreck_xf() * eye
		tgt = GEN.wreck_xf() * tgt
	_cam.fov = float(v[4])
	_cam.look_at_from_position(eye, tgt, Vector3.UP)
	_cam.make_current()


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # D-058: never hold the mouse
	if not _map.is_inside_tree() or _busy:
		return
	_t += delta
	if _t < 8.0 or _started:
		return
	_started = true
	_busy = true
	_run()


## The HUD, the subtitles and the minimap stay out of the captures.
func _hide_hud(n: Node) -> void:
	for c: Node in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		else:
			_hide_hud(c)


func _run() -> void:
	var p: Player = (_map as MapRoot).player if _map is MapRoot else null
	if p != null:
		p.global_position = Vector3(12.0, 0.1, 8.0)   # in the taproom, out of every shot
		p.set_physics_process(false)
	RoundManager.stop()
	if _map is MapRoot and (_map as MapRoot).director != null:
		(_map as MapRoot).director.kill_all(true)
	_hide_hud(get_tree().root)
	_cam = Camera3D.new()
	_cam.near = 0.03
	_cam.far = 900.0
	_map.add_child(_cam)
	for v: Array in _views():
		_place(v)
		await get_tree().create_timer(1.4).timeout
		var img: Image = get_viewport().get_texture().get_image()
		if img.get_width() > 1280:   # a window the OS opened at the desktop size: keep the file small (<= ~400 KB)
			img.resize(1280, int(1280.0 * float(img.get_height()) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
		var path: String = _out.path_join("%s_%s.jpg" % [_tag, v[0]])
		img.save_jpg(path, 0.82)
		print("[c47] shot %s -> %s" % [v[0], path])
	if _perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var rep: Dictionary = {"tag": _tag, "seconds": _perf_s, "views": {}}
		for v2: Array in _views():
			if not ["inn_door", "field_nw", "cabin"].has(str(v2[0])):
				continue
			_place(v2)
			await get_tree().create_timer(1.0).timeout
			var times: PackedFloat32Array = []
			var t0: int = Time.get_ticks_usec()
			var last: int = t0
			while Time.get_ticks_usec() - t0 < int(_perf_s * 1e6):
				await get_tree().process_frame
				var now: int = Time.get_ticks_usec()
				times.append(float(now - last) / 1000.0)
				last = now
			var sorted: PackedFloat32Array = times.duplicate()
			sorted.sort()
			var mean: float = 0.0
			for ft: float in times:
				mean += ft
			mean /= maxf(1.0, float(times.size()))
			var p95: float = sorted[int(0.95 * float(sorted.size() - 1))] if not sorted.is_empty() else 0.0
			var r: Dictionary = {"frames": times.size(), "mean_ms": snappedf(mean, 0.01), "p95_ms": snappedf(p95, 0.01),
				"fps": snappedf(1000.0 / maxf(mean, 0.001), 0.1), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
			rep["views"][v2[0]] = r
			print("[c47] perf %s %s" % [v2[0], JSON.stringify(r)])
		var f: FileAccess = FileAccess.open(_out.path_join("perf_%s.json" % _tag), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rep, "  "))
			f.close()
	print("[c47] done")
	get_tree().quit()
