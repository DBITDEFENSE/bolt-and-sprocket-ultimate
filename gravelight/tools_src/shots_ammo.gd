extends Node
## Dev tool: every ammo box on a map (Update 02 section 4), three views each: the player's own view with the buy
## prompt (holding a half-empty gun), a three-quarter view of the box in its corner, and a top-down plan of the
## floor around it (to check it blocks no door, window or path). Silent and off-screen, never captures the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_ammo.tscn -- --map=map00 --out=<dir> [--power]
## -> writes <dir>/<map>_<box>_{prompt,view,plan}.png

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
}

var _map_key: String = "map00"
var _out: String = "user://shots_ammo"
var _power: bool = false
var _map: Node3D
var _p: Player
var _cam: Camera3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--map="):
			_map_key = a.substr(6)
		elif a == "--power":
			_power = true
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	_map = (load(str(MAPS[_map_key])) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	_run.call_deferred()


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name_: String) -> void:
	await _secs(0.5)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("%s_%s.png" % [_map_key, name_]))
	print("shot ", name_)


func _run() -> void:
	await _secs(1.0)
	_p = _map.get_node_or_null("Player1") as Player
	_p.set_process_unhandled_input(false)
	RoundManager.stop()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		(n as BuyDoor).open(0)
	if _power:
		for n2: Node in _map.find_children("*", "PowerSwitch", true, false):
			(n2 as PowerSwitch).run_sequence(1)
		await _secs(10.0)
		RoundManager.stop()
	await _secs(5.0)
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir != null:
		dir.kill_all(true)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_map.add_child(_cam)
	for n3: Node in get_tree().get_nodes_in_group(&"ammo_boxes"):
		var box: AmmoBox = n3 as AmmoBox
		var tag: String = box.box_name if box.box_name != "" else String(box.name)
		var f: Vector3 = box.global_basis * Vector3(0, 0, -1)
		var side: Vector3 = box.global_basis * Vector3(1, 0, 0)
		# 1. the player's view: a half-empty gun, the prompt on the HUD
		var w: WeaponInstance = _p.weapons.current()
		if w != null:
			w.reserve = w.reserve_max() / 3
		_p.global_position = box.global_position + f * 1.8
		_p.velocity = Vector3.ZERO
		_p.rotation.y = box.global_rotation.y + PI
		_p.set("_pitch", deg_to_rad(-30.0))
		_p.camera.current = true
		await _shot(tag + "_prompt")
		print("  prompt: ", _p.prompt_text)
		# park the player out of the way for the other two
		_p.global_position = box.global_position + f * 6.0 + Vector3(0, 0.0, 0)
		# 2. three-quarter view
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.global_position = box.global_position + f * 2.6 + side * 1.4 + Vector3.UP * 1.7
		_cam.look_at(box.global_position + Vector3.UP * 0.45, Vector3.UP)
		_cam.current = true
		await _shot(tag + "_view")
		# 3. top-down plan, from under the ceiling
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = 12.0
		_cam.near = 0.05
		_cam.far = 30.0
		_cam.global_position = box.global_position + Vector3.UP * 2.3
		_cam.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # north up
		await _shot(tag + "_plan")
	get_tree().quit()
