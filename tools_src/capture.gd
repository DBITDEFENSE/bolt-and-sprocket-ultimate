extends Node
## Morning screenshots: opens each playable scene in a real (off-screen, silent) window, lets it settle and saves
## 2-3 PNGs per scene into morning/screenshots/<milestone>/: the spawn view, combat with zombies / enemies on
## screen, and a boss when the scene has one. GRAVELIGHT maps run with two bots and god mode.
## Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/capture.tscn \
##     [-- --milestone=overnight --only=map00,scrapheap]
## (tools/capture.sh does exactly that.)

## [key, scene, kind, boss id ("" = none)]
const TARGETS: Array = [
	["map00", "res://gravelight/maps/map00_crossroads/map00.tscn", "gl", "screamer"],
	["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "gl", "foreman"],
	["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn", "gl", ""],
	["cousins", "res://gravelight/maps/map00_crossroads/map00.tscn", "cousins", ""],
	["scrapheap", "res://bs/planets/scrapheap/scrapheap.tscn", "bs", ""],
	["verdant", "res://bs/planets/verdant/verdant.tscn", "bs", ""],
]

## Same-camera before/after sets (UPDATE_05 section 1, T-088): `--set=u05 [--label=before] [--only=cam,cam]` reads the
## fixed camera list in data/gravelight/capture_cams.json and saves morning/screenshots/<set>/<label>/NN_<name>.png,
## one per camera, so two labels pair up by file name (tools/compare_shots.py stitches the pairs side by side).
const CAMS_JSON: String = "res://data/gravelight/capture_cams.json"

var _out: String = ""
var _only: PackedStringArray = []
var _scene: Node = null
var _saved: PackedStringArray = []
var _set_name: String = ""
var _label: String = "before"


func _ready() -> void:
	var milestone: String = "overnight"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--milestone="):
			milestone = a.substr(12)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--set="):
			_set_name = a.substr(6)
		elif a.begins_with("--label="):
			_label = a.substr(8)
	if _out == "":
		if _set_name != "":
			_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots").path_join(_set_name).path_join(_label)
		else:
			_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots").path_join(milestone)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_capture_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	_saved.append(path)
	print("[capture] ", path)


func _run() -> void:
	if _set_name != "":
		await _cam_set()
		print("[capture] %d screenshots in %s" % [_saved.size(), _out])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
		get_tree().quit()
		return
	for t: Array in TARGETS:
		var key: String = str(t[0])
		if not _only.is_empty() and not _only.has(key):
			continue
		if not ResourceLoader.exists(str(t[1])):
			print("[capture] missing %s" % t[1])
			continue
		if str(t[2]) == "gl":
			await _gl(key, str(t[1]), str(t[3]))
		elif str(t[2]) == "cousins":
			await _cousins(key, str(t[1]))
		else:
			await _bs(key, str(t[1]))
		if _scene != null and is_instance_valid(_scene):
			_scene.queue_free()
			_scene = null
		await _secs(1.0)
	print("[capture] %d screenshots in %s" % [_saved.size(), _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


## One camera set from capture_cams.json: the map once (bots standing, no round), then the Player moved to each
## camera (feet position, yaw, pitch) and a frame saved after it settles. `kind` "zombie" spawns one Ganger at the
## cam's `subject` point and freezes it facing the camera; "squad" turns the camera to the bots' centroid;
## "viewmodel" is a plain view framed so the gun is the subject.
func _cam_set() -> void:
	var cfg: Dictionary = load_cams()
	var set_d: Dictionary = (cfg.get("sets", {}) as Dictionary).get(_set_name, {})
	if set_d.is_empty():
		push_error("[capture] no camera set '%s' in %s" % [_set_name, CAMS_JSON])
		return
	if str(set_d.get("mode", "")) == "maps":
		await _cam_set_maps(set_d)
		return
	GameState.character_id = &"dutch"
	GameState.bot_count = int(set_d.get("bots", 3))
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map: MapRoot = _load(str(set_d["map"])) as MapRoot
	GameState.god_mode = true
	await _secs(float(set_d.get("settle_s", 6.0)))
	RoundManager.stop()
	var p: Player = map.player
	var dir: ZombieDirector = map.director
	if p == null:
		push_error("[capture] the map has no player")
		return
	p.set_process_unhandled_input(false)
	var cams: Array = set_d.get("cams", [])
	var cur_map_path: String = str(set_d["map"])
	for i: int in cams.size():
		var cam: Dictionary = cams[i]
		var cname: String = str(cam.get("name", "cam%02d" % i))
		if not _only.is_empty() and not _only.has(cname):
			continue
		# UPDATE 09 §5: a camera may name its own `map` (the u09_ref set mixes Map 0 and Map 1): the current map is
		# freed and the new one spawned the same way as the set's first (bots standing, no round, god mode)
		var want_map: String = str(cam.get("map", cur_map_path))
		if want_map != cur_map_path:
			if _scene != null and is_instance_valid(_scene):
				_scene.free()
				_scene = null
			await _secs(0.5)
			Campaign.reset()
			map = _load(want_map) as MapRoot
			cur_map_path = want_map
			GameState.god_mode = true
			await _secs(float(set_d.get("settle_s", 6.0)))
			RoundManager.stop()
			p = map.player
			dir = map.director
			if p == null:
				push_error("[capture] the map %s has no player" % want_map)
				return
			p.set_process_unhandled_input(false)
		var kind: String = str(cam.get("kind", "view"))
		var pos: Vector3 = _v3(cam.get("pos", [0, 0, 0]))
		var yaw: float = float(cam.get("yaw", 0.0))
		var pitch: float = float(cam.get("pitch", 0.0))
		var subject: Node3D = null
		var posed: Array[Node3D] = []
		await _cam_do(map, cam.get("do", []))
		if cam.has("look_at"):
			# T-167: aim at a node by name (a seeded log page, a station placed from data) instead of fixed angles
			var tgt: Node = CaptureDo.find(map, str(cam["look_at"]))
			if tgt is Node3D:
				var a: Vector2 = CaptureDo.aim(pos + Vector3.UP * 1.62, (tgt as Node3D).global_position + Vector3.UP * float(cam.get("look_up", 0.5)))
				yaw = a.x
				pitch = a.y
			else:
				print("[capture] look_at: no node %s for %s" % [cam["look_at"], cname])
		p.global_position = pos
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(yaw)
		p.set("_pitch", deg_to_rad(pitch))
		if kind == "zombie" and dir != null:
			var at: Vector3 = _v3(cam.get("subject", [pos.x, pos.y, pos.z - 3.0]))
			if map.squad != null:
				map.squad.process_mode = Node.PROCESS_MODE_DISABLED   # the bots would shoot the model
			var before: Array = dir.active_zombies()
			var made: int = dir.spawn_burst([at], 1)
			for z: Zombie in dir.active_zombies():
				if not before.has(z):
					subject = z
			print("[capture] spawn_burst made %d (pool %d, active before %d) subject %s" % [made, dir.free_count(), before.size(), subject])
			# let the rise play, then freeze it the moment it would start chasing (the chase's stuck / off-navmesh
			# checks would otherwise recycle a posed zombie)
			var t: float = 0.0
			while subject != null and is_instance_valid(subject) and t < 4.0 and (subject as Zombie).state == Zombie.State.EMERGE:
				await _secs(0.1)
				t += 0.1
			if subject != null and is_instance_valid(subject) and (subject as Zombie).is_active():
				await _secs(float(cam.get("walk_s", 1.0)))   # a step or two out of the rise so it stands
			if subject != null and is_instance_valid(subject):
				var z: Zombie = subject as Zombie
				print("[capture] zombie %s after %.1fs: state %d active %s at %s" % [z.name, t, z.state, z.is_active(), z.global_position])
				if z.is_active():
					z.set_physics_process(false)
					z.global_position = at
					z.look_at(Vector3(pos.x, at.y, pos.z), Vector3.UP, true)
					if cam.has("make"):
						# T-167: a Kielholer (kits drowned / drowned_diver) at a Surface_* point: the controller's own cut
						var kc: Node = get_tree().get_first_node_in_group(&"kielholer_controller")
						if kc != null and kc.has_method("make"):
							kc.call("make", str(cam["make"]), z)
							print("[capture] made %s a %s" % [z.name, cam["make"]])
						else:
							print("[capture] make: no KielholerController for %s" % cname)
				else:
					subject = null
			if subject == null:
				print("[capture] no zombie came up for %s" % cname)
		elif kind == "squad":
			if map.squad != null:
				map.squad.process_mode = Node.PROCESS_MODE_DISABLED   # brains off while they pose
			var spots: Array = cam.get("subjects", [])
			var k: int = 0
			for node: Node in get_tree().get_nodes_in_group(&"players"):
				if node is Player and node != p and k < spots.size():
					var b: Player = node as Player
					var at: Vector3 = _v3(spots[k])
					b.set_physics_process(false)
					b.global_position = at
					b.velocity = Vector3.ZERO
					b.rotation.y = atan2(-(pos.x - at.x), -(pos.z - at.z))   # face the camera (forward is -Z)
					posed.append(b)
					k += 1
			print("[capture] squad posed %d bots" % posed.size())
		await _secs(float(cam.get("settle_s", 1.0 if i > 0 else 2.0)))
		if cam.has("shot_on"):
			# T-167: wait (up to shot_on_timeout s) for a GLBus signal, e.g. tide_cable_spark, and shoot the next frame
			await _wait_signal(str(cam["shot_on"]), float(cam.get("shot_on_timeout", 6.0)))
		await _shot("%02d_%s" % [i, cname])
		for b: Node3D in posed:
			if is_instance_valid(b):
				b.set_physics_process(true)
		if kind == "squad" and map.squad != null:
			map.squad.process_mode = Node.PROCESS_MODE_INHERIT
		if kind == "zombie":
			if subject != null and is_instance_valid(subject):
				(subject as Zombie).set_physics_process(true)
			if dir != null:
				dir.kill_all(true)
			if map.squad != null:
				map.squad.process_mode = Node.PROCESS_MODE_INHERIT
			await _secs(0.5)


## T-144 (the u09_menu_previews set, "mode": "maps"): one establishing frame per map, each cam naming its own
## `map`. No bots, no round, the HUD hidden, a free Camera3D (fov `fov`, default 64) either at `pos` (the eye, not the
## feet) with `yaw` / `pitch`, or behind the map's first player spawn (`spawn`: true; `back` metres behind it, `up`
## above the eye, `pitch`). Saved as <name>.png (the map id), so tools/menu_previews.py can copy them as they are.
func _cam_set_maps(set_d: Dictionary) -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	var cams: Array = set_d.get("cams", [])
	for i: int in cams.size():
		var cam: Dictionary = cams[i]
		var cname: String = str(cam.get("name", "cam%02d" % i))
		if not _only.is_empty() and not _only.has(cname):
			continue
		if cam.has("scene"):
			# UPDATE 12 (T-207, the u12_look set): a plain scene (the main menu's live backdrop) as it opens, its
			# CanvasLayers hidden, shot from its own camera after it settles
			if not ResourceLoader.exists(str(cam["scene"])):
				print("[capture] missing scene for %s" % cname)
				continue
			Campaign.reset()
			_load(str(cam["scene"]))
			await _secs(float(cam.get("settle_s", set_d.get("settle_s", 6.0))))
			for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
				if not (cl.get_script() != null and str((cl.get_script() as Script).resource_path).ends_with("postfx.gd")):
					(cl as CanvasLayer).visible = false
			await _secs(1.0)
			await _shot(cname)
			_scene.queue_free()
			_scene = null
			await _secs(1.5)
			continue
		if not ResourceLoader.exists(str(cam.get("map", ""))):
			print("[capture] missing map for %s" % cname)
			continue
		Campaign.reset()
		var map: MapRoot = _load(str(cam["map"])) as MapRoot
		GameState.god_mode = true
		await _secs(float(set_d.get("settle_s", 6.0)))
		RoundManager.stop()
		if map.director != null:
			map.director.kill_all(true)
		for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):   # the HUD, subtitles, toasts
			if not (cl.get_script() != null and str((cl.get_script() as Script).resource_path).ends_with("postfx.gd")):
				(cl as CanvasLayer).visible = false
		var c3: Camera3D = Camera3D.new()
		c3.name = "PreviewCamera"
		c3.fov = float(cam.get("fov", 64.0))
		c3.far = 1500.0
		map.add_child(c3)
		var eye: Vector3
		var yaw: float = deg_to_rad(float(cam.get("yaw", 0.0)))
		var pitch: float = deg_to_rad(float(cam.get("pitch", -6.0)))
		if bool(cam.get("player", false)) and map.player != null and map.player.camera != null:
			# the map's own start view: the player's camera as the map placed it, pulled back and up a little
			var pc: Transform3D = map.player.camera.global_transform
			var fwd2: Vector3 = -pc.basis.z
			fwd2.y = 0.0
			fwd2 = fwd2.normalized() if fwd2.length() > 0.01 else Vector3.FORWARD
			yaw = atan2(-fwd2.x, -fwd2.z) + deg_to_rad(float(cam.get("turn", 0.0)))
			fwd2 = Vector3(-sin(yaw), 0.0, -cos(yaw))
			eye = pc.origin - fwd2 * float(cam.get("back", 1.5)) + Vector3.UP * float(cam.get("up", 0.5))
		elif bool(cam.get("spawn", false)):
			var mk: Node3D = null
			for n: Node in map.find_children("PlayerSpawn*", "", true, false):
				if n is Node3D:
					mk = n as Node3D
					break
			if mk == null and map.player != null:
				mk = map.player
			var base: Vector3 = mk.global_position if mk != null else Vector3.ZERO
			var fwd: Vector3 = -mk.global_basis.z if mk != null else Vector3.FORWARD
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			yaw = atan2(-fwd.x, -fwd.z) + deg_to_rad(float(cam.get("turn", 0.0)))
			fwd = Vector3(-sin(yaw), 0.0, -cos(yaw))
			eye = base - fwd * float(cam.get("back", 3.0)) + Vector3.UP * (1.6 + float(cam.get("up", 1.0)))
		else:
			eye = _v3(cam.get("pos", [0, 1.6, 0]))
		c3.global_position = eye
		c3.rotation = Vector3(pitch, yaw, 0.0)
		c3.current = true
		if map.player != null:
			map.player.visible = false
		await _secs(float(cam.get("settle_s", 2.0)))
		await _shot(cname)
		_scene.queue_free()
		_scene = null
		await _secs(1.5)


## A camera's `do` list: see tools_src/capture_do.gd (shared with the tour clips, T-167).
func _cam_do(map: Node, ops: Array) -> void:
	var p: Player = (map as MapRoot).player if map is MapRoot else null
	await CaptureDo.run(get_tree(), map, p, ops)


func _wait_signal(sig: String, timeout: float) -> void:
	if not GLBus.has_signal(sig):
		print("[capture] shot_on: GLBus has no signal %s" % sig)
		return
	var got: Array = [false]
	var cb: Callable = func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
		got[0] = true
	GLBus.connect(sig, cb)
	var t: float = 0.0
	while not got[0] and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	GLBus.disconnect(sig, cb)
	print("[capture] shot_on %s: %s after %.1fs" % [sig, "fired" if got[0] else "timed out", t])


static func load_cams() -> Dictionary:
	var f: FileAccess = FileAccess.open(CAMS_JSON, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _load(path: String) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	_scene = n
	return n


func _gl(key: String, path: String, boss: String) -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 2
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map: MapRoot = _load(path) as MapRoot
	GameState.god_mode = true
	await _secs(4.0)
	await _shot("%s_1_spawn" % key)
	var p: Player = map.player
	var dir: ZombieDirector = map.director
	if p != null and dir != null:
		RoundManager.stop()
		var fwd: Vector3 = -p.camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
		var nav: RID = p.get_world_3d().navigation_map
		var pts: Array = []
		for i: int in 6:
			var want: Vector3 = p.global_position + fwd * (6.0 + float(i % 3) * 1.5) + fwd.cross(Vector3.UP) * (float(i) - 2.5) * 0.9
			pts.append(NavigationServer3D.map_get_closest_point(nav, want))
		dir.spawn_burst(pts, 6)
		await _secs(3.5)
		await _shot("%s_2_combat" % key)
		if boss != "":
			dir.kill_all(true)
			QuestManager.summon_boss(StringName(boss), NavigationServer3D.map_get_closest_point(nav, p.global_position + fwd * 6.0))
			await _secs(2.0)
			await _shot("%s_3_boss_%s" % [key, boss])
			await _secs(2.5)
			await _shot("%s_4_boss_%s" % [key, boss])
	GameState.god_mode = false


## HB1: the three Cousins side by side at eye level in the taproom (full figure), the third arm close, then the
## encounter's title card and boss bars.
func _cousins(key: String, path: String) -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	Campaign.reset()
	var map: MapRoot = _load(path) as MapRoot
	GameState.god_mode = true
	await _secs(3.0)
	RoundManager.stop()
	var p: Player = map.player
	var dir: ZombieDirector = map.director
	if p == null or dir == null:
		return
	p.set_process_unhandled_input(false)
	p.global_position = Vector3(14.0, 0.0, 12.5)
	p.rotation.y = 0.0   # facing -Z, toward the hearth
	p.set("_pitch", deg_to_rad(-4.0))
	var spots: Array = [Vector3(12.6, 0, 8.6), Vector3(14.0, 0, 8.4), Vector3(15.4, 0, 8.6)]
	var ids: Array = [&"hammer", &"reach", &"alix"]
	var made: Array = []
	for i: int in 3:
		var b: Node = dir.summon_boss(ids[i], spots[i])
		if b != null:
			b.set_physics_process(false)   # posed: no brain, the idle animation still runs
			(b as Node3D).rotation.y = PI
			made.append(b)
	await _secs(2.5)
	await _shot("%s_1_trio" % key)
	for b: Node in made:
		if is_instance_valid(b):
			(b as Node3D).rotation.y = PI * 0.75
	p.global_position = Vector3(15.6, 0.0, 10.4)
	p.rotation.y = deg_to_rad(15.0)
	await _secs(1.0)
	await _shot("%s_2_third_hand" % key)
	for b: Node in made:
		if is_instance_valid(b):
			(b as HomageBoss).cleanup()
	await _secs(0.5)
	p.global_position = Vector3(14.0, 0.0, 12.5)
	p.rotation.y = 0.0
	if dir.cousins != null:
		RoundManager.debug_set_round(10)
		await _secs(3.6)
		await _shot("%s_3_title_card" % key)
		await _secs(4.0)
		await _shot("%s_4_hammer_and_bars" % key)
	GameState.god_mode = false


func _bs(key: String, path: String) -> void:
	BSLevel.pending_cutscene = ""
	BS.god_mode = true
	_load(path)
	await _secs(5.0)
	await _shot("%s_1_spawn" % key)
	await _secs(6.0)
	await _shot("%s_2_play" % key)
	BS.god_mode = false
