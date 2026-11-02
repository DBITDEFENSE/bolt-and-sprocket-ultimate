extends Node
## UPDATE 10 blind-review tour clips (THE_BAR section 6; DECISIONS T-167): a capture set's cameras, walked. Opens the
## set's map with bots, god mode and the power on, lets the round run (zombies, the squad, the ambience beds and VO
## are alive in the frame), applies each camera's `do` list (tools_src/capture_do.gd) as the eye sets off toward it,
## and glides the player's eye from camera to camera (lerped feet position, shortest-way yaw, pitch; a short hold at
## each). Several sets concatenate (`--sets=a,b`); cameras of another map than the tour's are skipped, so
## `--sets=u10_map01,u09_ref` walks Kaltenbrunn with u09_ref's Map 1 cameras only. If the cameras would take more
## than MAX_CAM_S each, the walk comes back the way it went (the return cameras without their `do` lists); if fewer
## than MIN_CAM_S each, every n-th is skipped. Rendered through WSL + Xvfb by tools/wsl_clip.sh:
##   godot --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --write-movie <abs>.avi --fixed-fps 24 \
##         --path . res://gravelight/tools_src/clip_tour.tscn -- --set=u10_map02 --secs=120 [--map=res://...] [--bots=2] [--round=5] [--no-power]
## Also runs headless as a check (--headless --audio-driver Dummy --fixed-fps 60 ... -- --set=u09_ref --secs=10) and
## prints "[tour] RESULT: PASS" / "FAIL: ...". Never holds the mouse; the audio bus is NOT muted (the movie writer
## mixes the Dummy driver's output into the AVI).

const CAMS_JSON: String = "res://data/gravelight/capture_cams.json"
const MIN_CAM_S: float = 6.0
const MAX_CAM_S: float = 9.0
const EYE: float = 1.62

var _sets: PackedStringArray = []
var _map_path: String = ""
var _secs_total: float = 120.0
var _bots: int = 2
var _round: int = 5
var _hold_s: float = 1.6
var _power: bool = true
var _cams: Array = []
var _map: MapRoot
var _p: Player
var _live: bool = false
var _settle: float = 0.0
var _t: float = 0.0
var _seg_i: int = -1
var _seg_t: float = 0.0
var _seg_s: float = 0.0
var _from_pos: Vector3 = Vector3.ZERO
var _from_yaw: float = 0.0
var _from_pitch: float = 0.0
var _to_pos: Vector3 = Vector3.ZERO
var _to_yaw: float = 0.0
var _to_pitch: float = 0.0
var _visited: int = 0
var _frames: int = 0
var _zombies_seen: int = 0
var _bots_seen: int = 0
var _do_queue: Array = []
var _do_busy: bool = false
var _do_ran: int = 0
var _fails: PackedStringArray = []
var _finished: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set=") or a.begins_with("--sets="):
			_sets = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--map="):
			_map_path = a.substr(6)
		elif a.begins_with("--secs="):
			_secs_total = maxf(2.0, float(a.substr(7)))
		elif a.begins_with("--bots="):
			_bots = clampi(int(a.substr(7)), 0, 3)
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
		elif a.begins_with("--hold="):
			_hold_s = maxf(0.0, float(a.substr(7)))
		elif a == "--no-power":
			_power = false   # T-167: Map 0's electric lights are shadowed omnis the Compatibility renderer draws black
	if _sets.is_empty():
		_check(false, "a capture set (--set=<name>)")
		_finish()
		return
	_cams = _build_cams()
	if _cams.is_empty() or _map_path == "" or not ResourceLoader.exists(_map_path):
		_check(false, "cameras for the map %s in sets %s (%d found)" % [_map_path, ",".join(_sets), _cams.size()])
		_finish()
		return
	_seg_s = _secs_total / float(_cams.size())
	print("[tour] sets %s: %d cameras on %s, %.1f s each, %d bots, round %d" % [",".join(_sets), _cams.size(), _map_path.get_file(), _seg_s, _bots, _round])
	ProfileSave.path = "user://_qa_clip_tour_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_tour_settings.cfg"
	GLSettings.values["homage_bosses"] = false   # the walk, not a boss fight (the boss sets have their own cameras)
	GLSettings.values["vfx_quality"] = "high"
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = _bots
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	_map = (load(_map_path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


## The cameras of every named set on the tour's map (the first set's map when --map= is not given), thinned or
## ping-ponged so each takes between MIN_CAM_S and MAX_CAM_S of the clip.
func _build_cams() -> Array:
	var f: FileAccess = FileAccess.open(CAMS_JSON, FileAccess.READ)
	var cfg: Dictionary = (JSON.parse_string(f.get_as_text()) if f != null else {}) as Dictionary
	var sets: Dictionary = cfg.get("sets", {})
	var out: Array = []
	for sname: String in _sets:
		var set_d: Dictionary = sets.get(sname, {})
		if set_d.is_empty():
			print("[tour] no set '%s' in %s" % [sname, CAMS_JSON])
			continue
		var smap: String = str(set_d.get("map", ""))
		for cam_v: Variant in set_d.get("cams", []):
			var cam: Dictionary = (cam_v as Dictionary).duplicate()
			var cmap: String = str(cam.get("map", smap))
			if _map_path == "":
				_map_path = cmap
			if cmap != _map_path or not cam.has("pos"):
				continue
			cam["_set"] = sname
			out.append(cam)
	# thin: at most secs / MIN_CAM_S cameras, spread evenly over the list
	var n_max: int = maxi(2, int(floor(_secs_total / MIN_CAM_S)))   # a short check still walks two
	if out.size() > n_max:
		var thinned: Array = []
		for i: int in n_max:
			var j: int = int(round(float(i) * float(out.size() - 1) / float(maxi(1, n_max - 1))))
			if thinned.is_empty() or thinned[thinned.size() - 1] != out[j]:
				thinned.append(out[j])
		print("[tour] %d cameras thinned to %d" % [out.size(), thinned.size()])
		out = thinned
	# ping-pong: the walk back (without the world-state steps) until each camera has at most MAX_CAM_S
	if out.size() >= 2 and _secs_total / float(out.size()) > MAX_CAM_S:
		var back: Array = []
		for i: int in range(out.size() - 2, -1, -1):
			var c: Dictionary = (out[i] as Dictionary).duplicate()
			c.erase("do")
			c.erase("kind")
			c["_back"] = true
			back.append(c)
		var k: int = 0
		while _secs_total / float(out.size()) > MAX_CAM_S and k < back.size():
			out.append(back[k])
			k += 1
		print("[tour] the walk comes back over %d cameras" % k)
	return out


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _physics_process(delta: float) -> void:
	if _finished or _map == null or not _map.is_inside_tree():
		return
	if not _live:
		_settle += delta
		if _settle > 2.0:
			_try_live()
		return
	_frames += 1
	_t += delta
	if _p == null or not is_instance_valid(_p):
		return
	if _map.director != null and _zombies_seen == 0:
		_zombies_seen = _map.director.active_zombies().size()
	if _seg_i >= 0 and _seg_i < _cams.size():
		_seg_t += delta
		var travel: float = maxf(0.3, _seg_s - _hold_s)
		var k: float = smoothstep(0.0, 1.0, clampf(_seg_t / travel, 0.0, 1.0))
		var pos: Vector3 = _from_pos.lerp(_to_pos, k)
		var yaw: float = lerp_angle(_from_yaw, _to_yaw, k)
		var pitch: float = lerpf(_from_pitch, _to_pitch, k)
		_p.global_position = pos
		_p.velocity = Vector3.ZERO
		_p.rotation.y = yaw
		_p.set("_pitch", pitch)
		if _seg_t >= _seg_s:
			_next_segment()
	elif _seg_i >= _cams.size():
		_finish()


func _try_live() -> void:
	if _map.player == null or not _map.player.is_inside_tree():
		return
	if _bots > 0 and _map.squad == null:
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0:
		return
	_live = true
	_p = _map.player
	_p.set_process_unhandled_input(false)
	GameState.god_mode = true
	RoundManager.debug_set_round(_round)
	for pid: int in GameState.player_ids:
		Economy.award(pid, 3000)
	_bots_seen = GameState.bot_ids.size()
	if _power:
		_queue_do(["power"])
	_from_pos = _p.global_position
	_from_yaw = _p.rotation.y
	_from_pitch = float(_p.get("_pitch"))
	print("[tour] live: round %d next, bots %d, %d cameras" % [RoundManager.current_round + 1, _bots_seen, _cams.size()])
	_next_segment()


## Set off toward the next camera: its `do` list is queued (it plays while the eye travels), a "zombie" camera's
## subject rises where the eye is heading, and the lerp targets are set (look_at resolved against the live map).
func _next_segment() -> void:
	if _seg_i >= 0:
		_visited += 1
	_seg_i += 1
	_seg_t = 0.0
	if _seg_i >= _cams.size():
		return
	var cam: Dictionary = _cams[_seg_i]
	_from_pos = _p.global_position
	_from_yaw = _p.rotation.y
	_from_pitch = float(_p.get("_pitch"))
	_to_pos = _v3(cam.get("pos", [0, 0, 0]))
	_to_yaw = deg_to_rad(float(cam.get("yaw", 0.0)))
	_to_pitch = deg_to_rad(float(cam.get("pitch", 0.0)))
	if cam.has("look_at"):
		var tgt: Node = CaptureDo.find(_map, str(cam["look_at"]))
		if tgt is Node3D:
			var a: Vector2 = CaptureDo.aim(_to_pos + Vector3.UP * EYE, (tgt as Node3D).global_position + Vector3.UP * float(cam.get("look_up", 0.5)))
			_to_yaw = deg_to_rad(a.x)
			_to_pitch = deg_to_rad(a.y)
	var ops: Array = cam.get("do", [])
	if not ops.is_empty():
		_queue_do(ops)
	if str(cam.get("kind", "view")) == "zombie" and _map.director != null:
		var at: Vector3 = _v3(cam.get("subject", [_to_pos.x, _to_pos.y, _to_pos.z - 3.0]))
		var before: Array = _map.director.active_zombies()
		var made: int = _map.director.spawn_burst([at], 1)
		if made > 0 and cam.has("make"):
			var kc: Node = get_tree().get_first_node_in_group(&"kielholer_controller")
			for z: Zombie in _map.director.active_zombies():
				if not before.has(z) and kc != null and kc.has_method("make"):
					kc.call("make", str(cam["make"]), z)
	print("[tour] t=%.1f -> %d/%d %s%s (%s)" % [_t, _seg_i + 1, _cams.size(), str(cam.get("name", "cam")), " (back)" if cam.has("_back") else "", str(cam.get("_set", ""))])


func _queue_do(ops: Array) -> void:
	_do_queue.append(ops)
	if not _do_busy:
		_drain_do()


func _drain_do() -> void:
	_do_busy = true
	while not _do_queue.is_empty() and not _finished:
		var ops: Array = _do_queue.pop_front()
		await CaptureDo.run(get_tree(), _map, _p, ops)
		_do_ran += 1
	_do_busy = false


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _check(ok: bool, what: String) -> void:
	print("[tour] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	if _map != null:
		var alive: int = _map.director.active_zombies().size() if _map.director != null else 0
		print("[tour] %.1f s, %d physics frames, %d/%d cameras, %d do lists run (%d queued), round %d, zombies now %d (seen %d), bots %d" % [
			_t, _frames, _visited, _cams.size(), _do_ran, _do_queue.size(), RoundManager.current_round, alive, _zombies_seen, _bots_seen])
		_check(_p != null and is_instance_valid(_p), "the map has a player")
		_check(_visited >= _cams.size(), "every camera was visited (%d/%d)" % [_visited, _cams.size()])
		_check(_frames >= int(_secs_total * 30.0), "the walk ran its length (%d physics frames for %.0f s)" % [_frames, _secs_total])
		_check(_bots == 0 or _bots_seen == _bots, "the bots are in (%d of %d)" % [_bots_seen, _bots])
		if _zombies_seen == 0:
			print("[tour] note: no zombie was seen (a short check, or the round had not started)")
	print("[tour] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL: " + ", ".join(_fails)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
