extends Node
## Renders Map 0 in a real window and saves screenshots from a few viewpoints (for visual review).
## Usage: godot --path . res://gravelight/tools_src/shots_map00.tscn   -> writes user://shots/*.png

var _map: Node3D
var _shots: Array = [
	["perks", Vector3(22, 0, 9), 0.0, 4.0],
	["perks_left", Vector3(10, 0, 6), 20.0, 6.0],
	["crate_open", Vector3(22, 0, 9.5), 0.0, -18.0],
	["wallbuys", Vector3(6, 0, 12), 90.0, 0.0],
]
var _i: int = 0
var _t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_map = (load("res://gravelight/maps/test_range/test_range.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	GameState.god_mode = true


func _process(delta: float) -> void:
	if not _map.is_inside_tree() or _busy:
		return
	_t += delta
	if _t < 3.0 + _i * 2.5:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _i == 2:
		Economy.grant(1, 5000)
		var c: Node = get_tree().get_first_node_in_group(&"crate_spots")
		c.call("interact", _map.get_node("Player1"))
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
	img.save_png("user://shots/range_%02d_%s.png" % [_i, s[0]])
	print("shot ", s[0])
	_i += 1
	_busy = false
