extends Node
## Renders Map 0 in a real window and saves screenshots from a few viewpoints (for visual review).
## Usage (silent, off-screen, no mouse capture):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_map00.tscn [-- --out=<dir>]
## -> writes <dir>/NN_<name>.png (default user://shots). Door_Stable stays shut for its close-up.

var _map: Node3D
var _shots: Array = [
	# D-063 close-ups first (before any zombie reaches a window): barricade planks, the boarded doors, the radio
	["barricade_tap_n1", Vector3(7.0, 0.1, 2.4), 0.0, 4.0],
	["barricade_tap_e", Vector3(21.6, 0.1, 8.6), -80.0, 2.0],
	["door_stable", Vector3(21.6, 0.1, 13.0), 205.0, 4.0],
	["door_upstairs", Vector3(5.8, 0.1, 13.2), 115.0, 4.0],
	["field_radio", Vector3(6.4, 0.1, 4.0), 119.0, 10.0],
	["spawn_view", Vector3(15, 0, 9), 0.0, -2.0],
	["bar_and_hearth", Vector3(20, 0, 13), 40.0, -6.0],
	["stairs_door", Vector3(10, 0, 13.5), 60.0, -4.0],
	["window_zombies", Vector3(9, 0, 4), 20.0, -6.0],
	["stable", Vector3(20, 0, 23.5), 150.0, -8.0],
	["upstairs_hall", Vector3(20, 3.8, 8), 90.0, -4.0],
	["outside_wreck", Vector3(30, 0, -4), -60.0, 2.0],
]
var _out: String = "user://shots"
var _i: int = 0
var _t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	GameState.god_mode = true


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # D-058: never hold the mouse
	if not _map.is_inside_tree() or _busy:
		return
	_t += delta
	if _t < 9.0 + _i * 1.2:
		return
	if _i < _shots.size() and str(_shots[_i][0]) == "spawn_view":
		var d: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
		d.debug_spawn(6)
	if _i >= _shots.size():
		get_tree().quit()
		return
	_busy = true
	var s: Array = _shots[_i]
	var p: Player = _map.get_node("Player1") as Player
	p.global_position = s[1]
	p.rotation.y = deg_to_rad(float(s[2]))
	p.set("_pitch", deg_to_rad(float(s[3])))
	await get_tree().create_timer(0.6).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("m0_%02d_%s.png" % [_i, s[0]]))
	print("shot ", s[0])
	_i += 1
	_busy = false
