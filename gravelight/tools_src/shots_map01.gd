extends Node
## Renders Map 1 in a real window and saves screenshots from fixed viewpoints, first with the power off,
## then again after the Hauptschalter's light sweep (for visual review of the art pass).
## Usage (silent, off-screen, no mouse capture):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_map01.tscn [-- --out=<dir> --only=a,b]
## -> writes <dir>/m1_<nn>_<name>_<off|on>.png (default user://shots). The Admin and Lab doors stay shut (door art);
## shots with a 6th entry place zombies at those spots first (readability at ~15 m).

const DY: float = -12.0
const CY: float = -18.0
## [name, position (feet), yaw deg (0 = facing -Z), pitch deg, also after power]
var _shots: Array = [
	["yard_headframe", Vector3(20, 0.1, 30.5), 0.0, 16.0, true],
	["yard_gate", Vector3(31, 0.1, 27), 35.0, 4.0, false],
	["admin_facade", Vector3(13, 0.1, 21), 90.0, 6.0, false],
	["railyard", Vector3(48, 0.1, 46.5), 8.0, 2.0, true],
	["admin_inside", Vector3(-1.5, 0.1, 21), 95.0, -4.0, false],
	["barracks", Vector3(38.5, 0.1, 38.5), 92.0, -2.0, true],
	["stairwell", Vector3(-14, 0.1, 47.2), 180.0, -32.0, false],
	["chapel_nave", Vector3(12, DY + 0.1, 61.5), 180.0, 6.0, true],
	["chapel_aisle", Vector3(37, DY + 0.1, 62), 130.0, 4.0, true],
	["generator", Vector3(42, DY + 0.1, 80), -60.0, 6.0, true],
	["generator_panels", Vector3(62, DY + 0.1, 66), 20.0, -2.0, true],
	["lab_hall", Vector3(53.5, DY + 0.1, 90), -90.0, -2.0, true],
	["lab_tanks", Vector3(61, DY + 0.1, 86.5), 80.0, -4.0, true],
	["lab_nursery", Vector3(95, DY + 0.1, 87), 55.0, -10.0, false],
	["core_heart", Vector3(34, CY + 0.1, 103.5), 180.0, 12.0, true],
	["core_crucible", Vector3(37, CY + 0.1, 121), -105.0, 4.0, true],
	["ramp_g", Vector3(44.5, DY + 0.1, 83.5), 180.0, -12.0, false],
	["brick_close", Vector3(44.0, 0.1, 31.0), 90.0, 0.0, false],
	["chapel_altar", Vector3(12, DY + 0.1, 76.5), 180.0, 10.0, true],
	# D-063: interactables in place, and the depths before power with zombies at ~15 m
	["perk_ironhide", Vector3(24, 0.1, 36.4), 0.0, 4.0, true],
	["perk_second_wind", Vector3(-11.6, 0.1, 15.2), 75.0, 4.0, true],
	["perks_chapel", Vector3(5.5, DY + 0.1, 65.0), 25.0, 6.0, true],
	["perk_trigger_wire", Vector3(66.0, DY + 0.1, 76.6), 160.0, 4.0, true],
	["perks_lab", Vector3(57.6, DY + 0.1, 91.4), 35.0, 4.0, true],
	["perk_blastproof", Vector3(62.5, DY + 0.1, 93.8), 200.0, 4.0, true],
	["perk_packmule", Vector3(97.2, DY + 0.1, 91.5), 20.0, 4.0, true],
	["hauptschalter", Vector3(45.0, DY + 0.1, 65.6), 20.0, 0.0, true],
	["gen_dark_15m", Vector3(41.5, DY + 0.1, 76.5), -75.0, 2.0, false, [Vector3(56.0, DY, 74.0), Vector3(55.0, DY, 79.0), Vector3(57.5, DY, 76.5)]],
	["ramp_g_15m", Vector3(44.5, DY + 0.1, 83.0), 180.0, -14.0, false, [Vector3(44.0, DY - 4.5, 97.0), Vector3(45.5, DY - 4.8, 98.0)]],
	["chapel_dark_15m", Vector3(12.0, DY + 0.1, 62.0), 180.0, 2.0, false, [Vector3(12.0, DY, 77.0), Vector3(13.0, DY, 75.2)]],
	["lift_cage", Vector3(25.0, 0.1, 46.6), 180.0, -4.0, false],
	["ore_cart_lever", Vector3(42.2, 0.1, 43.6), 160.0, -6.0, false],
	["pylon_a", Vector3(20.0, 0.1, 25.6), 0.0, 10.0, true],
	["barricade_w_a_n1", Vector3(8.0, 0.1, 3.2), 0.0, 2.0, false],
	["door_admin", Vector3(3.6, 0.1, 25.0), 90.0, 4.0, false],
	["door_lab", Vector3(60.0, DY + 0.1, 78.4), 180.0, 4.0, true],
	["switchboard", Vector3(-3.0, 0.1, 26.2), 180.0, 4.0, false],
	["workbench", Vector3(41.6, DY + 0.1, 65.4), 0.0, -14.0, false],
	["crucible_close", Vector3(42.0, CY + 0.1, 124.6), -95.0, 8.0, true],
]
var _out: String = "user://shots"
var _only: PackedStringArray = []
const KEEP_SHUT: Array = ["Door_Admin", "Door_Lab"]
var _map: Node3D
var _p: Player
var _i: int = 0
var _t: float = 0.0
var _busy: bool = false
var _powered: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _map.is_inside_tree() or _busy:
		return
	if _p == null:
		_p = _map.get_node_or_null("Player1") as Player
		if _p == null:
			return
		_p.set_process_unhandled_input(false)
		RoundManager.stop()
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			if not KEEP_SHUT.has(String(n.name)):
				(n as BuyDoor).open(0)
	_t += delta
	if _t < 8.0:
		return
	if _i >= _shots.size():
		if _powered:
			get_tree().quit()
			return
		_powered = true
		_i = 0
		_busy = true
		(_map.get_node("Gameplay/Hauptschalter")).call("run_sequence", 1)
		await get_tree().create_timer(11.0).timeout
		RoundManager.stop()
		var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
		if dir != null:
			dir.kill_all(true)
		_busy = false
		return
	var s: Array = _shots[_i]
	if (_powered and not bool(s[4])) or (not _only.is_empty() and not _only.has(str(s[0]))):
		_i += 1
		return
	_busy = true
	_p.global_position = s[1]
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(float(s[2]))
	_p.set("_pitch", deg_to_rad(float(s[3])))
	if s.size() > 5:
		await _stage_zombies(s[5])
	await get_tree().create_timer(0.9).timeout
	if s.size() > 5:
		_place_zombies(s[5])
		await get_tree().process_frame
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("m1_%02d_%s_%s.png" % [_i, s[0], "on" if _powered else "off"]))
	print("shot ", s[0], " ", "on" if _powered else "off")
	if s.size() > 5:
		var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
		if dir != null:
			dir.kill_all(true)
	_i += 1
	_busy = false


## Spawns enough zombies for a readability shot (they're moved into place just before the capture).
func _stage_zombies(spots: Array) -> void:
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir == null:
		return
	dir.debug_spawn(spots.size())
	await get_tree().create_timer(2.5).timeout


func _place_zombies(spots: Array) -> void:
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir == null:
		return
	var zs: Array = dir.active_zombies()
	for i: int in mini(zs.size(), spots.size()):
		var z: Node3D = zs[i] as Node3D
		z.global_position = spots[i]
		var to: Vector3 = _p.global_position - z.global_position
		z.rotation.y = atan2(-to.x, -to.z)
