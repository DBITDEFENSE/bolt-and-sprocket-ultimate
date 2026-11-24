extends Node
## Live frame-time logger for a played session (dev aid): on with the command-line flag `--frame-log` (GLSettings adds
## it). Writes logs/frame_log_<time>.csv in the project (git-ignored):
##   a "setup" row (refresh rate, vsync, max_fps, physics ticks, interpolation, window size, GPU),
##   a "sec" row every second (fps, mean / p99 / max frame ms, CPU process + physics ms, GPU and CPU render ms of the
##   main viewport, draw calls, objects, nodes, scene, round, zombies alive),
##   a "spike" row for every frame over max(25 ms, 2.5 x the running median) with the same context.
## Cheap: a few Performance reads per frame, a file write per second.

var _f: FileAccess = null
var _frames: PackedFloat32Array = []
var _sec_t: float = 0.0
var _median: float = 1.0 / 60.0
var _t0: int = 0
var _spikes: int = 0


func _ready() -> void:
	process_priority = 1000   # last, so the frame's work is measured
	# T-264: an exported build has no res:// folder to write to (and a Mac app's working directory is /): user://logs
	var dir: String = "user://logs" if OS.has_feature("template") else "res://logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path: String = ProjectSettings.globalize_path("%s/frame_log_%s.csv" % [dir, stamp])
	_f = FileAccess.open(path, FileAccess.WRITE)
	if _f == null:
		push_warning("frame_log: can't write " + path)
		return
	print("[frame_log] -> ", path)
	_t0 = Time.get_ticks_msec()
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_f.store_line("kind,t_s,fps,mean_ms,p99_ms,max_ms,cpu_process_ms,cpu_physics_ms,gpu_ms,render_cpu_ms,draw_calls,objects,nodes,scene,round,zombies,note")
	var scr: int = DisplayServer.window_get_current_screen()
	_f.store_line("setup,0,,,,,,,,,,,,,,,refresh=%.1f vsync=%d max_fps=%d physics_ticks=%d interp=%s window=%s gpu=%s" % [
		DisplayServer.screen_get_refresh_rate(scr), DisplayServer.window_get_vsync_mode(), Engine.max_fps,
		Engine.physics_ticks_per_second, str(ProjectSettings.get_setting("physics/common/physics_interpolation", false)),
		str(DisplayServer.window_get_size()), RenderingServer.get_video_adapter_name().replace(",", " ")])
	_f.flush()


func _ctx() -> String:
	var sc: Node = get_tree().current_scene
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	var z: int = -1
	if dir != null and dir.has_method("active_zombies"):
		z = (dir.call("active_zombies") as Array).size()
	return "%s,%d,%d" % [sc.name if sc != null else "-", RoundManager.current_round, z]


func _perf_cols() -> String:
	var vp: RID = get_viewport().get_viewport_rid()
	return "%.2f,%.2f,%.2f,%.2f,%d,%d,%d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_gpu(vp), RenderingServer.viewport_get_measured_render_time_cpu(vp),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


func _process(delta: float) -> void:
	if _f == null:
		return
	var t: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	_frames.append(delta)
	_median = lerpf(_median, delta, 0.02)
	if delta > maxf(0.025, _median * 2.5) and t > 2.0:
		_spikes += 1
		_f.store_line("spike,%.2f,,%.1f,,,%s,%s," % [t, delta * 1000.0, _perf_cols(), _ctx()])
	_sec_t += delta
	if _sec_t < 1.0:
		return
	_sec_t = 0.0
	var s: PackedFloat32Array = _frames.duplicate()
	s.sort()
	var mean: float = 0.0
	for x: float in s:
		mean += x
	mean /= maxf(1.0, float(s.size()))
	var p99: float = s[mini(s.size() - 1, int(float(s.size()) * 0.99))]
	_f.store_line("sec,%.1f,%d,%.2f,%.2f,%.2f,%s,%s," % [t, s.size(), mean * 1000.0, p99 * 1000.0, s[s.size() - 1] * 1000.0, _perf_cols(), _ctx()])
	_f.flush()
	_frames.clear()


func _exit_tree() -> void:
	if _f != null:
		_f.store_line("end,%.1f,,,,,,,,,,,,,,,spikes=%d" % [float(Time.get_ticks_msec() - _t0) / 1000.0, _spikes])
		_f.close()
