extends Node
## Dev tool: art-review views of Map 0 (cellar unpowered + powered, both staircases, the upstairs landing,
## the taproom) from a free camera. No Player input, the mouse is never captured, the buses are muted.
## Silent, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_map00_art.tscn -- --out=<dir>
## -> <dir>/art_NN_<name>.png, plus a "[art] fps" line averaged over the cellar wide view (powered).
var _out: String = "user://shots"
var map: Node3D
var cam: Camera3D
var _n: int = 0

const DARK: Array = [
	["cellar_stairfoot", Vector3(26.0, -1.55, 18.2), Vector3(30.5, -2.4, 26.0)],
	["cellar_wide", Vector3(35.2, -1.2, 30.4), Vector3(27.0, -2.4, 20.5)],
	["cellar_west_row", Vector3(31.5, -1.6, 24.6), Vector3(25.9, -2.2, 25.8)],
	["cellar_hall_down", Vector3(25.6, 1.6, 11.0), Vector3(26.0, -2.5, 19.0)],
	["cellar_crucible_dark", Vector3(26.6, -1.55, 21.2), Vector3(29.5, -2.0, 19.9)],
]
const LIT: Array = [
	["cellar_stairfoot_lit", Vector3(26.0, -1.55, 18.2), Vector3(30.5, -2.4, 26.0)],
	["cellar_wide_lit", Vector3(35.2, -1.2, 30.4), Vector3(27.0, -2.4, 20.5)],
	["cellar_west_row_lit", Vector3(31.5, -1.6, 24.6), Vector3(25.9, -2.2, 25.8)],
	["cellar_east_row_lit", Vector3(28.5, -1.6, 24.6), Vector3(34.1, -2.2, 24.6)],
	["cellar_south_lit", Vector3(30.0, -1.5, 21.0), Vector3(30.0, -2.4, 30.5)],
	["cellar_lever_lit", Vector3(30.5, -1.5, 23.0), Vector3(33.0, -2.2, 19.3)],
	["cellar_chute_lit", Vector3(29.0, -1.5, 25.5), Vector3(35.0, -2.4, 30.5)],
	["cellar_up_stairs_lit", Vector3(29.0, -1.5, 24.0), Vector3(26.0, -1.2, 16.0)],
	["stair_up_from_door", Vector3(2.2, 1.6, 15.6), Vector3(1.2, 3.6, 10.0)],
	["stair_west_wall", Vector3(2.6, 2.2, 14.2), Vector3(0.0, 2.4, 11.8)],
	["stair_down_from_top", Vector3(1.5, 5.45, 7.4), Vector3(1.5, 1.5, 15.5)],
	["upstairs_landing", Vector3(1.4, 5.4, 9.4), Vector3(10.0, 5.0, 7.6)],
	["upstairs_hall", Vector3(22.5, 5.4, 8.2), Vector3(8.0, 4.8, 7.4)],
	["taproom_hearth", Vector3(15.5, 1.7, 9.5), Vector3(11.5, 1.4, 0.5)],
	["taproom_bar", Vector3(14.0, 1.7, 13.0), Vector3(5.5, 1.2, 5.0)],
	["taproom_south", Vector3(12.0, 1.7, 3.0), Vector3(14.0, 1.3, 15.8)],
	["taproom_east", Vector3(10.0, 1.7, 8.0), Vector3(24.0, 1.4, 9.0)],
	["cellar_bench", Vector3(29.8, -1.5, 22.3), Vector3(29.8, -2.3, 19.3)],
	["cellar_shelves_west", Vector3(27.6, -1.6, 25.6), Vector3(24.2, -2.0, 24.8)],
	["cellar_rack_south", Vector3(27.2, -1.6, 27.6), Vector3(25.6, -2.3, 30.8)],
	["cellar_north_pillar", Vector3(30.0, -1.5, 20.3), Vector3(30.0, -2.0, 23.0)],
	["stair_pictures_close", Vector3(1.7, 2.6, 13.9), Vector3(0.15, 2.9, 13.0)],
	["upstairs_room1", Vector3(6.0, 5.4, 4.6), Vector3(1.5, 4.8, 1.5)],
	["taproom_clock", Vector3(3.6, 1.7, 6.2), Vector3(0.16, 2.4, 3.4)],
	["cellar_crucible_lit", Vector3(29.5, -1.5, 22.3), Vector3(29.5, -2.0, 19.9)],
	["cellar_crucible_side", Vector3(33.2, -1.6, 22.4), Vector3(29.5, -2.2, 19.9)],
]


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_art_profile.json"
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var p: Player = map.get("player") as Player
	if p != null:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
	cam = Camera3D.new()
	cam.fov = 75
	map.add_child(cam)
	cam.make_current()
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	for s: Array in DARK:
		await _shot(s[0], s[1], s[2])
	var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
	sw.call("run_sequence", 1)
	await get_tree().create_timer(4.0).timeout
	for s: Array in LIT:
		await _shot(s[0], s[1], s[2])
	# frame-time sample at the cellar wide view, powered
	cam.global_position = LIT[1][1]
	cam.look_at(LIT[1][2])
	var t0: int = Time.get_ticks_usec()
	var frames: int = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		frames += 1
	print("[art] cellar fps %.1f" % (float(frames) / 3.0))
	cam.global_position = Vector3(15.5, 1.7, 9.5)
	cam.look_at(Vector3(11.5, 1.4, 0.5))
	t0 = Time.get_ticks_usec()
	frames = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		frames += 1
	print("[art] taproom fps %.1f" % (float(frames) / 3.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_art_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("art_%02d_%s.png" % [_n, label]))
	_n += 1
	print("[art] shot ", label)
