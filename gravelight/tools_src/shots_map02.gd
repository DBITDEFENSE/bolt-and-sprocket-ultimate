extends Node
## Renders Map 2 in a real window and saves screenshots from fixed viewpoints, first with the power off,
## then again after the Pumpenschalter's light sweep (for visual review of the art pass).
## Usage (silent, off-screen, no mouse capture):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_map02.tscn [-- --out=<dir> --only=a,b]
## -> writes <dir>/m2_<nn>_<name>_<off|on>.png (default user://shots). Shots flagged "tide" are taken at high water.

const LY: float = -3.0
const SY: float = -2.0
const CATY: float = 4.0
const TY: float = 7.0
## [name, position (feet), yaw deg (0 = facing -Z, 90 = -X), pitch deg, also after power, (flag)]
var _shots: Array = [
	["quay_spawn", Vector3(24, 0.1, 22), 150.0, 6.0, true],
	["quay_bunker_face", Vector3(16, 0.1, 6), 180.0, 10.0, true],
	["quay_sea", Vector3(16, 0.1, 22), -20.0, 2.0, false],
	["quay_hut", Vector3(5, 0.1, 24), -55.0, 4.0, true],
	["quay_cutter", Vector3(18, 0.1, 10), -40.0, 2.0, false],
	["cannery_lines", Vector3(-1.5, 0.1, 16), 90.0, 2.0, true],
	["cannery_infirmary", Vector3(-21, 0.1, 9.5), 50.0, 2.0, true],
	["cannery_tanks", Vector3(-14, 0.1, 27), 60.0, 0.0, true],
	["workshop", Vector3(33.5, 0.1, 17), -80.0, 2.0, true],
	["workshop_warheads", Vector3(49, 0.1, 21), -90.0, 2.0, true],
	["workshop_trolley", Vector3(36, 0.1, 25), -70.0, 0.0, false],
	["penhall_apron", Vector3(16, 0.1, 34), 180.0, 8.0, true],
	["penhall_boat_bow", Vector3(-3, 0.1, 40), 150.0, 4.0, true],
	["penhall_pier2", Vector3(17, 0.1, 80), 0.0, 4.0, true],
	["penhall_west_catwalk", Vector3(-19, CATY + 0.1, 78), -20.0, 8.0, true],
	["penhall_crane_bay", Vector3(34, 0.1, 50), 190.0, 4.0, true],
	["penhall_crane_office", Vector3(40, 0.1, 55), -90.0, 2.0, false],
	["penhall_pen_mouth", Vector3(26, 0.1, 62), 180.0, 4.0, false],
	["penhall_gangway", Vector3(17.5, 0.1, 58), 90.0, 0.0, false],
	["uboat_deck", Vector3(7, 1.1, 52), 180.0, 2.0, false],
	["uboat_torpedo_room", Vector3(7, SY + 0.1, 47), 0.0, 2.0, true],
	["uboat_control", Vector3(7, SY + 0.1, 66), 180.0, 0.0, true],
	["uboat_engines", Vector3(7, SY + 0.1, 70), 180.0, 0.0, false],
	["lowerpens_deck", Vector3(34, LY + 0.1, 52), 180.0, 4.0, true],
	["lowerpens_pumps", Vector3(42, LY + 0.1, 68), 180.0, 4.0, true],
	["lowerpens_switch", Vector3(46, LY + 0.1, 70), -90.0, 2.0, true],
	["lowerpens_high_tide", Vector3(34, LY + 0.1, 52), 180.0, 4.0, true, "tide"],
	["tower_ramp", Vector3(30, CATY + 0.1, 34), -90.0, 6.0, true],
	["tower_inside", Vector3(43, TY + 0.1, 34.2), -60.0, 2.0, true],
	["tower_view", Vector3(47, TY + 0.1, 34), 180.0, -8.0, true],
	["perk_second_wind", Vector3(-25, 0.1, 5), 0.0, 4.0, true],
	["crucible_close", Vector3(7, SY + 0.1, 43), 0.0, 6.0, true],
	["pump_stair", Vector3(49, 0.1, 40), 180.0, -14.0, false],
	["story_manifest", Vector3(42.5, 0.1, 54.5), -90.0, 2.0, false],
]
var _out: String = "user://shots"
var _only: PackedStringArray = []
const KEEP_SHUT: Array = ["Door_Cannery", "Door_Signal"]
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
	_map = (load("res://gravelight/maps/map02_totenhafen/map02.tscn") as PackedScene).instantiate() as Node3D
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
		(_map.get_node("Gameplay/Pumpenschalter")).call("run_sequence", 1)
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
	var tide: Node = _map.get_node("Gameplay/Tide")
	if s.size() > 5 and str(s[5]) == "tide":
		tide.set("level", -2.2)
		tide.set("target", -2.2)
		tide.call("_apply_level")
	_p.global_position = s[1]
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(float(s[2]))
	_p.set("_pitch", deg_to_rad(float(s[3])))
	await get_tree().create_timer(0.9).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("m2_%02d_%s_%s.png" % [_i, s[0], "on" if _powered else "off"]))
	print("shot ", s[0], " ", "on" if _powered else "off")
	if s.size() > 5 and str(s[5]) == "tide":
		tide.set("level", -4.0)
		tide.set("target", -4.0)
		tide.call("_apply_level")
	_i += 1
	_busy = false
