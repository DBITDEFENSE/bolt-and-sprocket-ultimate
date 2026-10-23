extends Node
## Screenshots of the HUD minimap (Update 04 section 2, DECISIONS T-065) on every GRAVELIGHT map and one B&S planet,
## plus the minimap's measured cost per frame. Rendered off-screen, audio muted, the mouse never captured, the
## user's settings file untouched (a scratch settings path).
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1920x1080 --path . res://tools_src/shots_minimap.tscn -- --out=C:/dir [--only=map00]
## Writes <n>_<shot>.png (full frame) and <n>_<shot>_crop.png (the minimap, 2x) to --out, and prints
## "[shots_minimap] perf <shot> <us>" lines and "RESULT PASS" at the end.

const SHOTS: Array = [
	# [label, scene, player pos, yaw deg (Godot: 0 faces north -Z, 90 faces west, -90 faces east), bots, settings]
	# north-up checks (Map 0: the wreck east of the inn, the stairwell in the taproom's south-west, the stable south)
	["map00_northup", "res://gravelight/maps/map00_crossroads/map00.tscn", Vector3(12.0, 0.1, 8.0), -90.0, 2, {"minimap_rotate": false, "minimap_zoom": 2}],
	["map00_rotate_west", "res://gravelight/maps/map00_crossroads/map00.tscn", Vector3(30.0, -3.1, 24.0), 90.0, 0, {}],
	["map01_northup", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", Vector3(20.0, 0.1, 22.0), 160.0, 3, {"minimap_rotate": false, "minimap_zoom": 2}],
	["map01_rotate_chapel_square", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", Vector3(12.0, -11.9, 74.0), -90.0, 0, {"minimap_shape": "square"}],
	["map02_northup", "res://gravelight/maps/map02_totenhafen/map02.tscn", Vector3(16.0, 0.1, 16.0), 180.0, 2, {"minimap_rotate": false, "minimap_zoom": 2}],
	["map02_rotate_south", "res://gravelight/maps/map02_totenhafen/map02.tscn", Vector3(16.0, 0.1, 16.0), 180.0, 2, {}],
	["scrapheap_northup", "res://bs/planets/scrapheap/scrapheap.tscn", Vector3.INF, 0.0, 0, {"minimap_rotate": false}],
	["scrapheap_rotate_east", "res://bs/planets/scrapheap/scrapheap.tscn", Vector3.INF, -90.0, 0, {}],
]


var _out: String = "user://shots_minimap"
var _only: String = ""
var _n: int = 0
var _fails: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	DirAccess.make_dir_recursive_absolute(_out)
	GLSettings.path = "user://_shots_minimap_settings.cfg"
	ProfileSave.path = "user://_shots_minimap_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run() -> void:
	var base: Dictionary = GLSettings.values.duplicate()
	for s: Array in SHOTS:
		if _only != "" and not str(s[0]).contains(_only):
			continue
		GLSettings.values = base.duplicate()
		GLSettings.values["minimap_zombies"] = "always"
		for k: Variant in (s[5] as Dictionary).keys():
			GLSettings.values[k] = s[5][k]
		await _shot(str(s[0]), str(s[1]), s[2] as Vector3, float(s[3]), int(s[4]))
	GLSettings.values = base
	print("[shots_minimap] RESULT %s %s" % ["PASS" if _fails.is_empty() else "FAIL", "; ".join(_fails)])
	get_tree().paused = false
	get_tree().quit(0 if _fails.is_empty() else 1)


func _shot(label: String, scene: String, pos: Vector3, yaw: float, bots: int) -> void:
	GameState.bot_count = bots
	GameState.god_mode = true
	var lvl: Node = (load(scene) as PackedScene).instantiate()
	lvl.set("play_arrival", false)
	get_tree().root.add_child(lvl)
	get_tree().current_scene = lvl
	await _frames(40)
	var ms: MapState = MapState.current()
	if ms == null:
		_fails.append("%s: no MapState" % label)
		lvl.queue_free()
		await _frames(5)
		return
	var body: Node3D = ms.local_body()
	if pos != Vector3.INF and body != null:
		body.global_position = pos
		body.rotation.y = deg_to_rad(yaw)
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
	for turn: int in 4:   # look around: discovery is by sight
		if body != null:
			body.rotation.y = deg_to_rad(yaw + 90.0 * turn)
		await _frames(30)
	if body != null:
		body.rotation.y = deg_to_rad(yaw)
	await _aim_bs_camera(lvl, yaw)
	await _frames(2)
	print("[shots_minimap]   %s: asked yaw %.0f, body facing %.0f, view %.0f" % [label, yaw, rad_to_deg(ms.facing_yaw()), rad_to_deg(ms.view_yaw())])
	print("[shots_minimap]   %s: %d POIs discovered by sight after looking around for 2 s, %.0f%% of the floor revealed" % [label, ms.discovered.size(),
		ms.revealed_fraction(ms.local_floor()) * 100.0])
	ms.discover_all()
	if body != null:
		var fwd: Vector3 = -body.global_basis.z
		ms.add_marker({"pos": body.global_position + fwd * 9.0 + body.global_basis.x * 4.0, "kind": "defend", "label": "Defend here", "owner": 1})
		ms.add_marker({"pos": body.global_position - fwd * 6.0 - body.global_basis.x * 7.0, "kind": "danger", "label": "Danger", "owner": 1})
		if ms.game == "gravelight":
			PowerupManager.spawn(&"double_scrip", body.global_position + body.global_basis.x * 5.0)
			ms.reveal_zombies(body.global_position, 60.0, 30.0)
	await _frames(90)
	var mm: Minimap = null
	for n: Node in get_tree().root.find_children("Minimap", "Control", true, false):
		mm = n as Minimap
	if mm == null or not mm.visible:
		_fails.append("%s: the minimap is not shown" % label)
	else:
		print("[shots_minimap]   parts ", mm.canvas.prof)
		print("[shots_minimap] perf %s %.0f us (minimap %d + canvas %d + redraws %d, last frame)" % [label, mm.perf_usec(), mm.get("_process_usec"), mm.canvas.cost_usec, mm.canvas.draw_usec])
		if mm.perf_usec() > 300.0:
			print("[shots_minimap]   over the 300 us budget")
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("%02d_%s.png" % [_n, label])
	img.save_png(path)
	if mm != null:
		var r: Rect2i = Rect2i(Minimap.layout_rect.grow(14.0))
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var k: Vector2 = Vector2(img.get_width(), img.get_height()) / vs
		var rr: Rect2i = Rect2i(Vector2i(Vector2(r.position) * k), Vector2i(Vector2(r.size) * k)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if rr.size.x > 4 and rr.size.y > 4:
			var crop: Image = img.get_region(rr)
			crop.resize(rr.size.x * 2, rr.size.y * 2, Image.INTERPOLATE_LANCZOS)
			crop.save_png(_out.path_join("%02d_%s_crop.png" % [_n, label]))
	print("[shots_minimap] %02d %s -> %s" % [_n, label, path])
	_n += 1
	get_tree().paused = false
	lvl.queue_free()
	await _frames(10)


## B&S: the minimap turns with the chase camera. BoltCamera.yaw is already a Godot yaw (the boom points along
## (sin, cos) of it, so the camera looks along (-sin, -cos)); set it, let the camera settle, print what MapState reads.
func _aim_bs_camera(lvl: Node, godot_yaw_deg: float) -> void:
	var bc: Variant = lvl.get("camera")
	if bc == null or not (bc is Node) or (bc as Node).get("yaw") == null:
		return
	for k: int in 30:
		(bc as Node).set("yaw", deg_to_rad(godot_yaw_deg))
		await get_tree().process_frame
	var ms: MapState = MapState.current()
	if ms != null:
		print("[shots_minimap]   B&S view yaw now %.0f deg (asked %.0f)" % [rad_to_deg(ms.view_yaw()), godot_yaw_deg])
