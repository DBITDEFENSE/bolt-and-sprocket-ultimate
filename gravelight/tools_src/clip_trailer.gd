extends Node
## T-285: the trailer shots. One map per run; each shot of the run (gravelight/tools_src/trailer_shots.json) is set
## up with the render loop off (nothing drawn, game time runs as fast as the CPU allows), then recorded frame by
## frame into <out>/<shot>/00000.jpg ... at a fixed game step (run with --fixed-fps so game time per frame is the
## same on every run; software rendering is far slower than real time). No movie writer: the trailer's sound is
## made separately, and per-shot frame folders cut cleanly. ffmpeg turns each folder into an mp4 (tools/trailer/).
##   tools/trailer/record.sh <run> [--only=a,b]    (WSL + Xvfb, Forward+ on lavapipe; one render at a time)
##   headless check: godot --headless --audio-driver Dummy --fixed-fps 24 --path . res://gravelight/tools_src/clip_trailer.tscn -- --run=<run> --check
##
## A run: {"map", "bots", "round", "hour", "character", "weapon", "shots": [...]}. A shot:
##   name, secs, hour (DayCycle.hold_hour), pre (ops before recording, render off), pre_s (more settle, render off),
##   cam: "free" (a Camera3D: from/to positions, look/look_to targets or yaw/pitch(_to), fov/fov_to, ease, shake)
##        "eye"  (the player's own eye and viewmodel: from/to feet positions, aim/aim_to targets or yaw/pitch(_to),
##                aim "zombie" tracks the nearest zombie in front)
##        "tank" (the driven Sherman's orbit camera: tank_yaw/tank_pitch relative to the hull, tank_dist)
##        "keep" (whatever camera is current: the horse, the zip line)
##   hud: "off" (no HUD, viewmodel kept), "none" (no HUD, no viewmodel), "on" (the HUD without its debug lines)
##   events: [[t, op], ...] during the shot.
## Ops (own): clear | horde:x,y,z:n | stand:x,y,z:yaw[:n] (still figures) | blast:x,y,z:r[:kind] | launch:t |
##   player:x,y,z[:yaw] | fire_on | fire_off | aim:x,y,z | tank_in | tank_out | tank_drive:steer,throttle | tank_fire |
##   tank_dist:m | horse_mount | horse:steer,throttle,sprint | zip:<name> | bots_to:x,y,z | god:true/false |
##   lamp:x,y,z:energy:range (a warm omni) ; anything else goes to CaptureDo (power, open, tear, callv, boss, ...).

const SHOTS_JSON: String = "res://gravelight/tools_src/trailer_shots.json"
const EYE: float = 1.62

var _run_name: String = ""
var _out: String = ""
var _only: PackedStringArray = []
var _check: bool = false
var _fps: float = 24.0
var _scale: float = 1.0
var _run: Dictionary = {}
var _map: MapRoot
var _p: Player
var _cam: Camera3D
var _aim_zombie: bool = false
var _aim_point: Vector3 = Vector3.INF
var _fails: PackedStringArray = []
var _frames_total: int = 0
var _huds: Array = []
var _stride: int = 1
var _mag0: int = 0
var _follow_pos: Vector3 = Vector3.INF
var _look_s: Vector3 = Vector3.INF


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--run="):
			_run_name = a.substr(6)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--fps="):
			_fps = maxf(1.0, float(a.substr(6)))
		elif a.begins_with("--scale="):
			_scale = clampf(float(a.substr(8)), 0.25, 1.0)
		elif a.begins_with("--stride="):
			_stride = maxi(1, int(a.substr(9)))   # a framing preview: every n-th frame only (the rest not drawn)
		elif a == "--check":
			_check = true
	var f: FileAccess = FileAccess.open(SHOTS_JSON, FileAccess.READ)
	var all: Dictionary = (JSON.parse_string(f.get_as_text()) if f != null else {}) as Dictionary
	_run = (all.get("runs", {}) as Dictionary).get(_run_name, {})
	if _run.is_empty():
		print("[trailer] RESULT: FAIL no run '%s' in %s" % [_run_name, SHOTS_JSON])
		get_tree().quit(1)
		return
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("build/trailers/src").path_join(_run_name)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_clip_trailer_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_trailer_settings.cfg"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["homage_bosses"] = false
	GLSettings.values["film_grain"] = false
	# the picture: the Low preset (75 % scale, FSR 1) by default: under lavapipe a Medium exterior frame cost 10-20 s
	# (SSIL, volumetric fog), Low's a fraction of it, and the two read nearly the same at night. A run may name
	# "preset" and "gfx_scale".
	GLSettings.set_preset(str(_run.get("preset", "low")))
	if _run.has("gfx_scale"):
		GLSettings.values["gfx_scale"] = float(_run["gfx_scale"])
		GLSettings.apply_visuals()
	Campaign.reset()
	GameState.character_id = StringName(str(_run.get("character", "dutch")))
	GameState.bot_count = int(_run.get("bots", 0))
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	seed(int(_run.get("seed", 2850)))
	if _scale < 1.0:
		get_viewport().scaling_3d_scale = _scale
	_map = (load(str(_run["map"])) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_go.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


# ------------------------------------------------------------------ time

func _skip(s: float) -> void:
	if s <= 0.0:
		return
	RenderingServer.render_loop_enabled = false
	var t: float = 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
	RenderingServer.render_loop_enabled = true


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


static func _v3(a: Variant, fb: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fb


static func _csv3(s: String) -> Vector3:
	var v: PackedStringArray = s.split(",")
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if v.size() >= 3 else Vector3.ZERO


# ------------------------------------------------------------------ the run

func _go() -> void:
	var t: float = 0.0
	while (_map.player == null or not _map.player.is_inside_tree()) and t < 120.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_p = _map.player
	if _p == null:
		print("[trailer] RESULT: FAIL no player")
		get_tree().quit(1)
		return
	_p.set_process_unhandled_input(false)
	await _skip(float(_run.get("settle_s", 14.0)))   # the map's opening plays out
	GameState.god_mode = true
	if int(_run.get("round", 0)) > 0:
		RoundManager.debug_set_round(int(_run["round"]))
	if not bool(_run.get("rounds_live", false)):
		RoundManager.stop()
	if _map.director != null and not bool(_run.get("keep_zombies", false)):
		_map.director.kill_all(true)
	for pid: int in GameState.player_ids:
		Economy.award(pid, 20000)
	for z: Variant in _run.get("open_zones", []):
		GameState.open_zone(StringName(str(z)))
	if _run.has("weapon"):
		await CaptureDo.run(get_tree(), _map, _p, ["give:" + str(_run["weapon"])])
	RenderingServer.render_loop_enabled = false   # setup is never drawn
	await _ops(_run.get("pre", []))
	RenderingServer.render_loop_enabled = true
	_cam = Camera3D.new()
	_cam.name = "TrailerCam"
	_map.add_child(_cam)
	for sh_v: Variant in _run.get("shots", []):
		var sh: Dictionary = sh_v
		if not (_only.is_empty() or _only.has(str(sh.get("name", "")))):
			continue
		await _shot(sh)
	print("[trailer] %d frames in %s" % [_frames_total, _out])
	print("[trailer] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL: " + ", ".join(_fails)))
	Input.action_release(&"fire")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _shot(sh: Dictionary) -> void:
	var nm: String = str(sh.get("name", "shot"))
	var secs: float = float(sh.get("secs", 4.0))
	var mode: String = str(sh.get("cam", "free"))
	_aim_zombie = false
	_aim_point = Vector3.INF
	Input.action_release(&"fire")
	if sh.has("hour"):
		var dc: DayCycle = DayCycle.of(_map)
		if dc != null:
			dc.hold_hour(float(sh["hour"]))
	if mode == "eye":
		_p.noclip = bool(sh.get("noclip", false))
		if _p.noclip:
			_p.collision_mask = 0
		_place_eye(sh, 0.0)
	elif mode == "free" and not bool(sh.get("keep_player", false)):
		_p.global_position = _v3(sh.get("player"), _v3(_run.get("player_park"), Vector3(8.0, 0.2, 3.0)))
		_p.velocity = Vector3.ZERO
		if sh.has("player_yaw"):
			_p.rotation.y = deg_to_rad(float(sh["player_yaw"]))
	if not bool(sh.get("keep", false)) and _map.director != null:
		RoundManager.stop()
		_map.director.kill_all(true)
	if (mode == "eye" or mode == "keep") and _p.camera != null:
		_p.camera.make_current()   # (a horde_cam in pre spawns ahead of this eye)
	if mode == "free" and not sh.has("anchor") and not sh.has("follow"):
		_cam.fov = float(sh.get("fov", 55.0))
		_place_free(sh, 0.0)
		_cam.make_current()
	RenderingServer.render_loop_enabled = false
	await _ops(sh.get("pre", []))
	RenderingServer.render_loop_enabled = true
	await _skip(float(sh.get("pre_s", 1.0)))
	if sh.has("anchor"):
		sh = _anchored(sh)
	match mode:
		"free":
			_cam.fov = float(sh.get("fov", 55.0))
			_place_free(sh, 0.0)
			_cam.make_current()
		"eye":
			if _p.camera != null:
				_p.camera.make_current()
			_place_eye(sh, 0.0)
		"tank":
			pass
	_hud(str(sh.get("hud", "off")))
	print("[trailer] shot %s: %.1f s, cam %s" % [nm, secs, mode])
	var dir: String = _out.path_join(nm)
	DirAccess.make_dir_recursive_absolute(dir)
	if not _check:
		for old: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(old))
	var events: Array = (sh.get("events", []) as Array).duplicate()
	events.sort_custom(func(a: Variant, b: Variant) -> bool: return float(a[0]) < float(b[0]))
	var n: int = int(round(secs * _fps))
	var t: float = 0.0
	var fired: int = 0
	for i: int in n:
		while fired < events.size() and float(events[fired][0]) <= t + 0.0001:
			_ops(PackedStringArray([str(events[fired][1])]))   # not awaited: an event never holds the clock
			fired += 1
		var k: float = float(i) / float(maxi(1, n - 1))
		match mode:
			"free":
				_place_free(sh, k)
			"eye":
				_place_eye(sh, k)
				var wi: WeaponInstance = _p.weapons.current() if _p.weapons != null else null
				if wi != null:
					if i == 0:
						_mag0 = wi.mag
					elif wi.mag < 6 and _mag0 > 6:
						wi.mag = _mag0   # never an empty click mid-shot
			"tank":
				_place_tank(sh, k)
		_hide_debug()
		if i % 12 == 0:
			_hud(str(sh.get("hud", "off")))
			if bool(_run.get("hide_labels", true)):
				_hide_labels()
		if _check or DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		elif i % _stride != 0:
			RenderingServer.render_loop_enabled = false
			await get_tree().process_frame
			RenderingServer.render_loop_enabled = true
		else:
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_jpg(dir.path_join("%05d.jpg" % i), 0.94)
		_frames_total += 1
		t += 1.0 / _fps
	Input.action_release(&"fire")
	var alive: int = _map.director.active_zombies().size() if _map.director != null else 0
	print("[trailer] shot %s done: %d frames, %d zombies alive" % [nm, n, alive])
	if bool(sh.get("clear_after", true)) and _map.director != null:
		_map.director.kill_all(true)
		if Effects.has_method("clear_marks"):
			Effects.call("clear_marks")


## "anchor": a node (an ExtraPerson's first body, a horse, a boss ...); "orbit"/"orbit_to": [dist, side deg round
## the node's facing, height] give from/to, "look_h" the look point's height over it.
func _anchored(sh0: Dictionary) -> Dictionary:
	var sh: Dictionary = sh0.duplicate()
	var n: Node = CaptureDo.find(_map, str(sh["anchor"]))
	if n == null:
		print("[trailer] anchor: no node %s" % str(sh["anchor"]))
		return sh
	var base: Node3D = n as Node3D
	if n is ExtraPerson and not (n as ExtraPerson).bodies.is_empty():
		base = (n as ExtraPerson).bodies[0]
	if base == null:
		return sh
	var at: Vector3 = base.global_position
	var face: float = base.global_rotation.y
	for key: String in ["orbit", "orbit_to"]:
		if sh.has(key):
			var o: Array = sh[key]
			var off: Vector3 = Vector3(0, float(o[2]), -float(o[0])).rotated(Vector3.UP, face + deg_to_rad(float(o[1])))
			var pos: Vector3 = at + off
			sh["from" if key == "orbit" else "to"] = [pos.x, pos.y, pos.z]
	var lh: float = float(sh.get("look_h", 1.5))
	sh["look"] = [at.x, at.y + lh, at.z]
	print("[trailer] anchor %s at %s facing %.0f" % [str(sh["anchor"]), str(at), rad_to_deg(face)])
	return sh


static func _ease(k: float, how: String) -> float:
	match how:
		"smooth":
			return smoothstep(0.0, 1.0, k)
		"in":
			return k * k
		"out":
			return 1.0 - (1.0 - k) * (1.0 - k)
	return k


func _shake(sh: Dictionary, k: float) -> Vector3:
	var a: float = float(sh.get("shake", 0.0))
	if a <= 0.0:
		return Vector3.ZERO
	var tt: float = k * float(sh.get("secs", 4.0))
	return Vector3(sin(tt * 1.7) * 0.6 + sin(tt * 4.3 + 1.0) * 0.25, sin(tt * 2.3 + 2.0) * 0.5 + sin(tt * 5.1) * 0.2, sin(tt * 1.1 + 4.0) * 0.4) * a * 0.03


## A live node for "follow" / "look_follow": tank, horse, rocket, player, or a node name.
func _live_node(nm: String) -> Node3D:
	match nm:
		"tank":
			var ev: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
			return ev.tank if ev != null else null
		"horse":
			return CaptureDo.find(_map, "YardHorse") as Node3D
		"rocket":
			var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
			return rl.rocket if rl != null else null
		"player":
			return _p
	return CaptureDo.find(_map, nm) as Node3D


func _place_free(sh: Dictionary, k0: float) -> void:
	var k: float = _ease(k0, str(sh.get("ease", "linear")))
	if sh.has("follow"):
		# a camera riding with a moving node: "off"/"off_to" in the node's frame, "look_off" a point in its frame
		var fn: Node3D = _live_node(str(sh["follow"]))
		if fn != null:
			var basis_y: Basis = Basis(Vector3.UP, fn.global_rotation.y)
			var oa: Vector3 = _v3(sh.get("off"), Vector3(-5, 2, 0))
			var ob: Vector3 = _v3(sh.get("off_to"), oa)
			var fpos: Vector3 = fn.global_position + basis_y * oa.lerp(ob, k) + _shake(sh, k0)
			if _follow_pos == Vector3.INF or k0 == 0.0:
				_follow_pos = fpos
			_follow_pos = _follow_pos.lerp(fpos, clampf(float(sh.get("follow_rate", 0.35)), 0.02, 1.0))
			_cam.global_position = _follow_pos
			_cam.fov = lerpf(float(sh.get("fov", 55.0)), float(sh.get("fov_to", sh.get("fov", 55.0))), k)
			var lt: Vector3 = fn.global_position + basis_y * _v3(sh.get("look_off"), Vector3(0, 1.2, 0))
			if not _follow_pos.is_equal_approx(lt):
				_cam.look_at(lt, Vector3.UP)
			return
	var a: Vector3 = _v3(sh.get("from"))
	var b: Vector3 = _v3(sh.get("to"), a)
	var pos: Vector3 = a.lerp(b, k) + _shake(sh, k0)
	_cam.global_position = pos
	_cam.fov = lerpf(float(sh.get("fov", 55.0)), float(sh.get("fov_to", sh.get("fov", 55.0))), k)
	if sh.has("look"):
		var la: Vector3 = _v3(sh["look"])
		var lb: Vector3 = _v3(sh.get("look_to"), la)
		var tgt: Vector3 = la.lerp(lb, k) + _shake(sh, k0 + 0.37) * 2.0
		if not pos.is_equal_approx(tgt):
			_cam.look_at(tgt, Vector3.UP)
	else:
		var yaw: float = lerpf(float(sh.get("yaw", 0.0)), float(sh.get("yaw_to", sh.get("yaw", 0.0))), k)
		var pitch: float = lerpf(float(sh.get("pitch", 0.0)), float(sh.get("pitch_to", sh.get("pitch", 0.0))), k)
		_cam.global_rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)
	if sh.has("look_follow"):
		var ln: Node3D = _live_node(str(sh["look_follow"]))
		if ln != null:
			var lt2: Vector3 = ln.global_position + _v3(sh.get("look_off"), Vector3.ZERO)
			if _look_s == Vector3.INF or k0 == 0.0:
				_look_s = lt2
			_look_s = _look_s.lerp(lt2, clampf(float(sh.get("follow_rate", 0.3)), 0.02, 1.0))
			if not pos.is_equal_approx(_look_s):
				_cam.look_at(_look_s, Vector3.UP)
	if sh.has("roll"):
		_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(float(sh["roll"])))


func _place_eye(sh: Dictionary, k0: float) -> void:
	var k: float = _ease(k0, str(sh.get("ease", "linear")))
	if sh.has("from"):
		var a: Vector3 = _v3(sh["from"])
		var b: Vector3 = _v3(sh.get("to"), a)
		_p.global_position = a.lerp(b, k)
		_p.velocity = Vector3.ZERO
	var eye: Vector3 = _p.global_position + Vector3.UP * EYE
	var tgt: Vector3 = Vector3.INF
	var aim: Variant = sh.get("aim")
	if str(aim) == "zombie" or _aim_zombie:
		tgt = _nearest_zombie(eye)
	if tgt == Vector3.INF and _aim_point != Vector3.INF:
		tgt = _aim_point
	if tgt == Vector3.INF and aim is Array:
		tgt = _v3(aim).lerp(_v3(sh.get("aim_to"), _v3(aim)), k)
	if tgt != Vector3.INF:
		var d: Vector3 = tgt - eye
		var want_yaw: float = atan2(-d.x, -d.z)
		var want_pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
		var rate: float = 1.0 if k0 == 0.0 else clampf(float(sh.get("aim_rate", 0.25)), 0.02, 1.0)
		_p.rotation.y = lerp_angle(_p.rotation.y, want_yaw, rate)
		_p.set_look_pitch(lerpf(float(_p.get("_pitch")), want_pitch, rate))
	elif sh.has("yaw"):
		_p.rotation.y = deg_to_rad(lerpf(float(sh["yaw"]), float(sh.get("yaw_to", sh["yaw"])), k))
		_p.set_look_pitch(deg_to_rad(lerpf(float(sh.get("pitch", 0.0)), float(sh.get("pitch_to", sh.get("pitch", 0.0))), k)))


func _nearest_zombie(eye: Vector3) -> Vector3:
	if _map.director == null:
		return Vector3.INF
	var fwd: Vector3 = -_p.global_basis.z
	var best: Vector3 = Vector3.INF
	var best_d: float = 1.0e9
	for z: Zombie in _map.director.active_zombies():
		if not is_instance_valid(z) or z.hp <= 0.0:
			continue
		var at: Vector3 = z.global_position + Vector3.UP * 1.35
		var d: Vector3 = at - eye
		if d.length() > 40.0 or fwd.dot(d.normalized()) < 0.2:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = at
	return best


func _place_tank(sh: Dictionary, k0: float) -> void:
	var ev: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
	if ev == null or ev.tank == null:
		return
	var tk: ShermanTank = ev.tank
	var k: float = _ease(k0, str(sh.get("ease", "linear")))
	var yaw: float = lerpf(float(sh.get("tank_yaw", 0.0)), float(sh.get("tank_yaw_to", sh.get("tank_yaw", 0.0))), k)
	var pitch: float = lerpf(float(sh.get("tank_pitch", -8.0)), float(sh.get("tank_pitch_to", sh.get("tank_pitch", -8.0))), k)
	_p.rotation.y = tk.rotation.y + deg_to_rad(yaw)
	_p.set_look_pitch(deg_to_rad(pitch))
	if tk.cam != null and sh.has("tank_dist"):
		tk.cam.dist = lerpf(float(sh["tank_dist"]), float(sh.get("tank_dist_to", sh["tank_dist"])), k)


# ------------------------------------------------------------------ HUD

func _hud(how: String) -> void:
	var vm: int = 1 << 19
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl: CanvasLayer = n as CanvasLayer
		if cl is LookPost or str(cl.name) == "BlastScreen" or cl == GLConsole or GLSettings.is_ancestor_of(cl):
			continue
		if how == "on":
			cl.visible = cl is Hud or str(cl.name).begins_with("Crosshair") or cl.visible
			cl.offset = Vector2.ZERO
		else:
			cl.visible = false
			cl.offset = Vector2(100000, 0)   # layers that set their own visible every frame (the squad roster) go off-screen
	var subs: Node = GLVO.get("_subtitles") as Node
	if subs is CanvasLayer:
		(subs as CanvasLayer).visible = false
	if _p != null and _p.camera != null:
		_p.camera.cull_mask = (_p.camera.cull_mask & ~vm) if how == "none" else (_p.camera.cull_mask | vm)


## Every Label3D off (painted signs, stencils, name tags, pings): lettering in frame is what the Higgsfield
## re-render keeps worst, and the gameplay cut shows the world, not its labels.
func _hide_labels() -> void:
	for n: Node in _map.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for wm: Node in get_tree().root.find_children("*", "Node3D", true, false):
		if wm is WorldMarks:
			(wm as Node3D).visible = false
	var ms: MapState = MapState.current()
	if ms != null and not ms.markers().is_empty():
		ms.clear_markers()


func _hide_debug() -> void:
	if _huds.is_empty():
		for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n is Hud:
				_huds.append(n)
	for h: Node in _huds:
		if is_instance_valid(h):
			var dl: Variant = h.get("_debug_label")
			if dl is Control:
				(dl as Control).visible = false


# ------------------------------------------------------------------ ops

func _ops(ops: Variant) -> void:
	for op_v: Variant in ops:
		var s: String = str(op_v)
		var op: PackedStringArray = s.split(":")
		match op[0]:
			"round":
				RoundManager.debug_set_round(int(op[1]))
				await get_tree().process_frame
				if not bool(_run.get("rounds_live", false)):
					RoundManager.stop()
			"horde_rel":
				# "horde_rel:<node>:dx,dy,dz:n": a horde at a point in a live node's frame (ahead of the tank: dz < 0)
				var rn: Node3D = _live_node(op[1])
				if rn != null and _map.director != null:
					var c2: Vector3 = rn.global_transform * _csv3(op[2])
					c2.y = rn.global_position.y
					var cnt2: int = int(op[3]) if op.size() > 3 else 6
					var pts2: Array = []
					for i3: int in cnt2:
						pts2.append(c2 + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))
					print("[trailer] horde_rel %d at %s" % [_map.director.spawn_burst(pts2, cnt2), str(c2)])
			"horde_cam":
				# "horde_cam:dist:n[:side]": a horde ahead of the shot's camera (free: the trailer camera, else the eye)
				if _map.director != null:
					var cam3: Camera3D = get_viewport().get_camera_3d()
					var from3: Vector3 = cam3.global_position if cam3 != null else _p.global_position
					var fwd3: Vector3 = (-cam3.global_basis.z) if cam3 != null else (-_p.global_basis.z)
					fwd3.y = 0.0
					fwd3 = fwd3.normalized()
					var c3: Vector3 = from3 + fwd3 * float(op[1]) + fwd3.cross(Vector3.UP) * (float(op[3]) if op.size() > 3 else 0.0)
					c3.y = from3.y - EYE if cam3 != null else _p.global_position.y
					var cnt3: int = int(op[2]) if op.size() > 2 else 6
					var pts3: Array = []
					for i4: int in cnt3:
						pts3.append(c3 + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))
					print("[trailer] horde_cam %d at %s" % [_map.director.spawn_burst(pts3, cnt3), str(c3)])
			"blast_horde":
				# "blast_horde:r[:kind]": a blast at the middle of the live zombies (they move between setup and the event)
				if _map.director != null:
					var zs: Array = _map.director.active_zombies()
					if not zs.is_empty():
						var mid: Vector3 = Vector3.ZERO
						for z: Zombie in zs:
							mid += z.global_position
						mid /= float(zs.size())
						Effects.call("explosion", mid + Vector3.UP * 0.3, float(op[1]) if op.size() > 1 else 5.0, op[2] if op.size() > 2 else "")
			"perk":
				if _p.has_method("give_perk"):
					_p.call("give_perk", StringName(op[1]))
				else:
					print("[trailer] perk: no Player.give_perk")
			"clear":
				if _map.director != null:
					_map.director.kill_all(true)
			"horde":
				if _map.director != null:
					var c: Vector3 = _csv3(op[1])
					var cnt: int = int(op[2]) if op.size() > 2 else 6
					var pts: Array = []
					for i: int in cnt:
						pts.append(c + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))
					var made: int = _map.director.spawn_burst(pts, cnt)
					print("[trailer] horde %d of %d at %s" % [made, cnt, str(c)])
			"stand":
				await _stand(_csv3(op[1]), float(op[2]) if op.size() > 2 else 0.0, int(op[3]) if op.size() > 3 else 1)
			"blast":
				Effects.call("explosion", _csv3(op[1]), float(op[2]) if op.size() > 2 else 4.5, op[3] if op.size() > 3 else "")
			"launch":
				var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
				if rl != null:
					rl.begin_launch()
					if op.size() > 1:
						rl.t = float(op[1])
				else:
					print("[trailer] launch: no RocketLaunch")
			"player":
				_p.global_position = _csv3(op[1])
				_p.velocity = Vector3.ZERO
				if op.size() > 2:
					_p.rotation.y = deg_to_rad(float(op[2]))
			"fire_on":
				Input.action_press(&"fire")
			"fire_off":
				Input.action_release(&"fire")
			"aim":
				_aim_point = _csv3(op[1])
			"aim_zombie":
				_aim_zombie = true
			"tank_in":
				var ev: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
				if ev != null:
					ev.force_assist()
					for i2: int in 30:
						await get_tree().physics_frame
					var tk: ShermanTank = ev.tank
					if op.size() > 1:
						tk.global_position = _csv3(op[1])
						if op.size() > 2:
							tk.rotation.y = deg_to_rad(float(op[2]))
						for i5: int in 10:
							await get_tree().physics_frame
					_p.global_position = tk.global_transform * Vector3(2.6, 0.05, 0.5)
					tk.use.interact(_p)
					var t1: float = 0.0
					while (tk.seat != ShermanTank.Seat.SEATED or tk.cam == null or tk.cam.blend < 1.0) and t1 < 6.0:
						await get_tree().process_frame
						t1 += get_process_delta_time()
					print("[trailer] tank: seated %s" % str(tk.seat == ShermanTank.Seat.SEATED))
				else:
					print("[trailer] tank_in: no ShermanEvent")
			"tank_out":
				# T-290: the Sherman lets the player go (a driver is carried: while in it the horse, a ladder and a zip
				# line all refuse them, and a "player:" move is undone by the hatch every physics frame)
				var evo: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
				if evo != null and evo.tank != null and is_instance_valid(evo.tank):
					evo.tank.input_override = null
					evo.tank.put_out()
					for i6: int in 4:
						await get_tree().physics_frame
			"tank_drive":
				var ev2: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
				if ev2 != null and ev2.tank != null:
					var v: PackedStringArray = op[1].split(",")
					ev2.tank.input_override = Vector3(float(v[0]), float(v[1]), 0.0)
			"tank_fire":
				var ev3: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
				if ev3 != null and ev3.tank != null:
					ev3.tank._gun_t = 0.0
					ev3.tank.fire_wanted = true
			"horse_mount":
				var h: Node = CaptureDo.find(_map, "YardHorse")
				if h != null and h.has_method("ride"):
					if _p.carry != null and _p.carry != h:
						print("[trailer] horse_mount: the player is still carried by %s (add tank_out)" % str(_p.carry))
					h.call("ride", _p)   # the capture hook: mounts (the climb takes a few seconds), then trots on
					await _skip(3.0)
					print("[trailer] horse: rider %s, at %s" % [str(h.get("rider")), str((h as Node3D).global_position)])
				else:
					print("[trailer] horse_mount: no YardHorse")
			"horse":
				var h2: Node = CaptureDo.find(_map, "YardHorse")
				if h2 != null:
					var hv: PackedStringArray = op[1].split(",")
					h2.call("demo", float(hv[0]), float(hv[1]), float(hv[2]) if hv.size() > 2 else 0.0)
			"zip":
				var zl: Node = null
				var names: PackedStringArray = []
				for n: Node in get_tree().get_nodes_in_group(&"ziplines"):
					names.append(str(n.name))
					if n.name == op[1] or (op[1] == "any" and zl == null):
						zl = n
				print("[trailer] zip lines: %s" % ", ".join(names))
				if zl != null:
					zl.call("ride", _p)
					await _frames(3)
					print("[trailer] zip %s: riding %s" % [str(zl.name), str(zl.call("is_riding", _p))])
				else:
					print("[trailer] zip: no zip line %s" % op[1])
			"bots_to":
				var bc: Vector3 = _csv3(op[1])
				var bi: int = 0
				for bn: Node in get_tree().get_nodes_in_group(&"bots"):
					if bn is Node3D:
						(bn as Node3D).global_position = bc + Vector3(float(bi) * 1.2 - 1.2, 0.0, float(bi % 2) * 1.0)
						bi += 1
			"god":
				GameState.god_mode = op.size() < 2 or op[1] == "true"
			"lamp":
				var l: OmniLight3D = OmniLight3D.new()
				_map.add_child(l)
				l.global_position = _csv3(op[1])
				l.light_energy = float(op[2]) if op.size() > 2 else 1.5
				l.omni_range = float(op[3]) if op.size() > 3 else 6.0
				l.light_color = Color(1.0, 0.72, 0.42)
			"cam_parent":
				pass
			_:
				await CaptureDo.run(get_tree(), _map, _p, [s])


## Still figures (a silhouette at the treeline): spawned through the director, then held where they are told.
func _stand(at: Vector3, yaw_deg: float, n: int) -> void:
	if _map.director == null:
		return
	var before: Array = _map.director.active_zombies()
	var pts: Array = []
	for i: int in n:
		pts.append(at + Vector3(float(i) * 1.6, 0.0, float(i % 2) * 1.2))
	_map.director.spawn_burst(pts, n)
	await _skip(5.0)
	var i2: int = 0
	for z: Zombie in _map.director.active_zombies():
		if before.has(z):
			continue
		if i2 >= n:
			z.deactivate()
			continue
		z.global_position = pts[i2] as Vector3
		z.rotation.y = deg_to_rad(yaw_deg)
		z.velocity = Vector3.ZERO
		z.hp = 1.0e9
		z.set_physics_process(false)
		i2 += 1
