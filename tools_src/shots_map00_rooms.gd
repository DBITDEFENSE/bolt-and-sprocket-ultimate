extends Node
## Dev tool: Map 0 room by room (Update 02 section 8, T-053). Fixed free-camera views of every room, the same views
## before and after the small-detail polish pass, so the two sets compare one to one: the taproom (four views), the
## stairs, the upstairs hall and the three guest rooms, the stable and the hayloft, both cellars, the yard and the
## inn's front. Every door is opened first; the player is hidden; rounds don't run. Silent (buses muted), off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/shots_map00_rooms.tscn -- --out=<dir> --suffix=before
## -> <dir>/<view>_<suffix>.png
var _out: String = "user://shots"
var _suffix: String = "shot"
var map: Node3D
var cam: Camera3D

## [view, camera position, look-at point]
const VIEWS: Array = [
	["taproom_hearth", Vector3(15.0, 1.65, 9.5), Vector3(12.0, 1.0, 0.5)],
	["taproom_bar", Vector3(14.5, 1.65, 6.0), Vector3(5.0, 1.2, 5.0)],
	["taproom_east", Vector3(10.0, 1.65, 9.0), Vector3(22.5, 0.9, 4.0)],
	["taproom_south", Vector3(12.0, 1.65, 3.0), Vector3(17.0, 0.9, 14.5)],
	["taproom_floor", Vector3(18.0, 2.6, 7.5), Vector3(11.0, 0.0, 11.5)],
	["stairs", Vector3(5.0, 1.65, 15.2), Vector3(1.5, 3.2, 10.0)],
	["upstairs_hall", Vector3(2.0, 5.45, 8.2), Vector3(22.0, 4.6, 8.0)],
	["room1_cousins", Vector3(6.6, 5.45, 5.2), Vector3(1.0, 4.2, 1.0)],
	["room2", Vector3(9.0, 5.45, 5.3), Vector3(14.5, 4.2, 1.0)],
	["room3", Vector3(17.0, 5.45, 5.3), Vector3(22.5, 4.3, 2.0)],
	["stable", Vector3(20.5, 1.65, 23.2), Vector3(12.0, 0.6, 31.0)],
	["stable_stalls", Vector3(9.0, 1.65, 31.5), Vector3(14.0, 0.8, 23.0)],
	["hayloft", Vector3(14.2, 5.15, 26.5), Vector3(7.5, 3.6, 32.0)],
	["helvetia_cellar", Vector3(26.0, -1.55, 20.6), Vector3(32.0, -2.6, 28.0)],
	["old_cellar_vault", Vector3(12.0, -1.4, 2.4), Vector3(19.0, -2.7, 9.5)],
	["old_cellar_wine", Vector3(0.8, -1.6, 17.6), Vector3(9.0, -2.6, 10.0)],
	["yard", Vector3(9.0, 1.65, 35.5), Vector3(22.0, 0.3, 45.0)],
	["exterior_front", Vector3(8.0, 1.8, -9.0), Vector3(12.0, 1.5, 0.0)],
	["exterior_snow", Vector3(20.0, 2.0, -6.0), Vector3(14.0, 0.0, -1.0)],
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
		elif a.begins_with("--suffix="):
			_suffix = a.substr(9)
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_map00_rooms_profile.json"
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
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		if d is BuyDoor:
			(d as BuyDoor).open(1)
	cam = Camera3D.new()
	cam.fov = 75
	map.add_child(cam)
	cam.make_current()
	await get_tree().create_timer(2.0).timeout
	# the HUD, subtitles and intro card off (they differ run to run); the post-processing layer stays
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(n.name) != "PostFx":
			(n as CanvasLayer).visible = false
	for v: Array in VIEWS:
		await _shot(str(v[0]), v[1], v[2])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_map00_rooms_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [label, _suffix]))
	print("[rooms] shot ", label)
