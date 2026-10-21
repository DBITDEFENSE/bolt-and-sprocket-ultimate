extends Node
## Dev tool: the Requisition Crate in context on Map 0 (each spot, closed, then the Hearth spot opened and
## cycling). Silent and off-screen, never captures the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_crate_map.tscn -- --out=<dir>
## -> writes <dir>/cm_NN_<name>.png

var _map: Node3D
## [name, spot index made current, player position, yaw deg, pitch deg, open?]
var _shots: Array = [
	["hearth_closed", 0, Vector3(20.4, 0, 14.2), -90.0, -6.0, false],
	["hearth_cycling", 0, Vector3(20.4, 0, 14.2), -90.0, -6.0, true],
	["guestbed", 1, Vector3(22.0, 3.8, 3.4), 0.0, -8.0, false],
	["tackroom", 2, Vector3(20.3, 0, 31.3), -90.0, -6.0, false],
	["hearth_empty", 2, Vector3(20.4, 0, 14.2), -90.0, -6.0, false],
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _map.is_inside_tree() or _busy:
		return
	_t += delta
	if _t < 8.0 + _i * 1.5:
		return
	if _i >= _shots.size():
		get_tree().quit()
		return
	_busy = true
	var s: Array = _shots[_i]
	CrateManager.location_index = int(s[1])
	var spot: MysteryCrate = null
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		var c: MysteryCrate = n as MysteryCrate
		if c.phase == MysteryCrate.Phase.CYCLING or c.phase == MysteryCrate.Phase.OFFERED:
			c.call("_close")
		c.refresh()
		if c.spot_index == int(s[1]):
			spot = c
	if bool(s[5]) and spot != null:
		spot.call("_net_open", 1, "ppsh41")
	var p: Player = _map.get_node("Player1") as Player
	p.global_position = s[2]
	p.rotation.y = deg_to_rad(float(s[3]))
	p.set("_pitch", deg_to_rad(float(s[4])))
	await get_tree().create_timer(1.2 if bool(s[5]) else 0.6).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("cm_%02d_%s.png" % [_i, s[0]]))
	print("shot ", s[0])
	_i += 1
	_busy = false
