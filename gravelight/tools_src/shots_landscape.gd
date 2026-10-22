extends Node
## Update 02 section 7 acceptance views (T-052): Map 0's landscape, sky and distant war from a free camera, silent
## and off-screen (the Player is disabled, the mouse is never captured, the buses are muted):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . \
##     res://gravelight/tools_src/shots_landscape.tscn -- --out=<dir> [--round=8] [--only=spawn,stable] [--events]
## -> <dir>/s7_NN_<view>.png. --round sets the war's intensity (and the farmhouse light / dog rules) as if that round
## were running; --events stages a bomber stream, a fighter pair, a falling plane, flares and a barrage before the
## shots (MapAmbience's debug hooks) so they are in frame. The window boards are torn off unless --boards. Prints "[s7] fps <view> <n>" for each view.

const VIEWS: Array = [
	# [name, camera position, look-at]
	["spawn", Vector3(15.0, 1.7, 9.0), Vector3(8.5, 2.6, -40.0)],
	["spawn_east", Vector3(14.0, 1.7, 8.0), Vector3(60.0, 4.0, 0.0)],
	["upstairs_window", Vector3(20.0, 5.45, 1.2), Vector3(4.0, 9.0, -80.0)],
	["upstairs_window_ne", Vector3(19.6, 5.45, 0.7), Vector3(48.0, 14.0, -80.0)],
	["stable", Vector3(10.5, 1.7, 24.5), Vector3(20.0, 2.2, 33.0)],
	["stable_shafts", Vector3(8.0, 1.8, 23.2), Vector3(16.0, 2.6, 31.0)],
	["field_edge", Vector3(32.8, 1.75, 40.5), Vector3(90.0, 6.0, 10.0)],
	["field_edge_south", Vector3(18.0, 1.75, 46.5), Vector3(30.0, 6.0, 140.0)],
	["east_window", Vector3(22.8, 1.7, 8.0), Vector3(80.0, 6.0, -6.0)],
	["exterior_wide", Vector3(-30.0, 14.0, 70.0), Vector3(20.0, 2.0, 10.0)],
	["north_road", Vector3(-6.0, 2.0, -30.0), Vector3(-11.0, 1.0, -70.0)],
	# details (outside the play space too: a free camera)
	["detail_inn_sign", Vector3(9.0, 2.6, -6.5), Vector3(11.8, 3.0, -0.8)],
	["detail_cockpit", Vector3(36.5, 2.6, -3.0), Vector3(44.0, 1.8, 0.8)],
	["detail_parachute", Vector3(31.0, 2.0, 30.0), Vector3(39.5, 4.5, 24.5)],
	["detail_yard_wall", Vector3(20.0, 1.7, 44.0), Vector3(17.0, 4.6, 34.0)],
	["detail_frost_window", Vector3(9.0, 1.6, 3.2), Vector3(7.0, 1.55, 0.0)],
	["detail_road_car", Vector3(-3.0, 2.4, -38.0), Vector3(-8.0, 0.5, -51.0)],
]

var _out: String = "user://shots"
var _only: PackedStringArray = []
var _round: int = 1
var _events: bool = false
var _boards: bool = false
var _hide: PackedStringArray = []
var map: Node3D
var cam: Camera3D
var _n: int = 0


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--round="):
			_round = int(a.substr(8))
		elif a == "--events":
			_events = true
		elif a.begins_with("--hide="):
			_hide = a.substr(7).split(",", false)
		elif a == "--boards":
			_boards = true
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_s7_profile.json"
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var p: Player = map.get("player") as Player
	if p != null:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
	cam = Camera3D.new()
	cam.fov = 75
	cam.far = 400.0
	map.add_child(cam)
	cam.make_current()
	var hud: Node = map.get("hud") as Node
	if hud != null:
		hud.set("visible", false)
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if cl.name != "PostFx":
			(cl as CanvasLayer).visible = false
	if not _boards:   # the boards are torn off (as mid-round), so the windows show the land beyond
		for b: Node in get_tree().get_nodes_in_group(&"barricades"):
			for k: int in 6:
				b.call("tear_board")
	for h: String in _hide:   # debugging: hide nodes by name
		for n: Node in map.find_children(h, "", true, false):
			if n is Node3D:
				(n as Node3D).visible = false
	RoundManager.current_round = _round
	var amb: Node = map.find_child("MapAmbience", false, false)
	if amb != null and amb.has_method("debug_set_round"):
		amb.call("debug_set_round", _round)
	await get_tree().create_timer(1.0).timeout
	for v: Array in VIEWS:
		if not _only.is_empty() and not _only.has(str(v[0])):
			continue
		cam.global_position = v[1]
		cam.look_at(v[2])
		if _events and amb != null and amb.has_method("debug_stage_for_view"):
			amb.call("debug_stage_for_view", cam)
			await get_tree().create_timer(3.0).timeout
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("s7_%02d_%s.png" % [_n, v[0]]))
		_n += 1
		var t0: int = Time.get_ticks_usec()
		var frames: int = 0
		while Time.get_ticks_usec() - t0 < 1000000:
			await get_tree().process_frame
			frames += 1
		print("[s7] fps %s %d" % [v[0], frames])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_s7_profile.json"))
	get_tree().quit()
