extends Node
## Dev tool (rendered, needs the user's OK): screenshots of Map 0's Grounds (T-080) and the HUD perk row with
## 6, 7 and 9 tonics (T-081). Off-screen, silent, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_grounds.tscn -- --out=<dir>
## -> <dir>/g_NN_<name>.png. The profile is never written (temp path).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const SIX: Array = [&"ironhide_stout", &"second_wind", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"hawkeye_brandy"]

# [name, position, yaw deg (0 = looking north / -z), pitch deg, perks: 6 / 7 / 9]
var _shots: Array = [
	["front_of_inn", Vector3(20, 0, -15), 180.0, 2.0, 6],
	["front_door_price", Vector3(19, 0, -5), 180.0, 4.0, 6],
	["north_field_east", Vector3(4, 0, -20), -90.0, 0.0, 6],
	["north_field_west", Vector3(40, 0, -22), 90.0, 0.0, 6],
	["crash_site", Vector3(40, 0, 6), 10.0, 2.0, 7],
	["east_ring", Vector3(31, 0, 14), 180.0, 0.0, 7],
	["east_road_block", Vector3(48, 0, -7), -90.0, 0.0, 7],
	["carters_road", Vector3(2, 0, 56), -90.0, 0.0, 7],
	["yard_gate_outside", Vector3(18, 0, 56), 0.0, 4.0, 9],
	["west_road", Vector3(-8, 0, 50), 0.0, 0.0, 9],
	["crossroads_shrine", Vector3(-4, 0, -2), -45.0, 0.0, 9],
	["edge_trees", Vector3(10, 0, -26), 0.0, 6.0, 9],
	# T-084: the barn's loft stair and gallery, the loft door from the yard, the edge pockets
	["barn_stair", Vector3(19.0, 0.1, 29.5), 281.0, 10.0, 6],
	["barn_stair_head", Vector3(24.3, 3.6, 32.5), 73.0, -5.0, 6],
	["barn_loft_west", Vector3(7.5, 3.6, 25.5), 252.0, -4.0, 6],
	["barn_bay_down", Vector3(18.5, 3.6, 30.5), 339.0, -25.0, 6],
	["barn_loft_door", Vector3(22.0, 0.1, 40.0), 0.0, 22.0, 6],
	["edge_inside", Vector3(5.0, 0.1, -26.0), 0.0, 0.0, 6],
	["edge_fence_bay", Vector3(0.0, 0.1, -27.0), 309.0, -3.0, 6],
]

var _out: String = "user://shots"
var _map: Node3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_grounds_profile.json"
	GLSettings.path = "user://_shots_grounds_settings.cfg"
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _perks(n: int) -> void:
	if n >= 9:
		PerkManager.grant_all(1)
		PerkManager.set_tier(1, &"ironhide_stout", 2)
		PerkManager.set_tier(1, &"trigger_tonic", 3)
		return
	for p: StringName in SIX:
		PerkManager.grant(1, p)
	if n >= 7:
		PerkManager.grant(1, &"packmule_porter")


func _run() -> void:
	await _wait(9.0)
	var p: Player = _map.get_node("Player1") as Player
	for i: int in _shots.size():
		var s: Array = _shots[i]
		_perks(int(s[4]))
		p.global_position = s[1]
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(float(s[2]))
		p.set("_pitch", deg_to_rad(float(s[3])))
		await _wait(0.8)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("g_%02d_%s.png" % [i, s[0]]))
		print("[grounds] shot ", s[0], " perks ", PerkManager.capped_count(1))
	# overhead: the whole Grounds
	var cam: Camera3D = Camera3D.new()
	_map.add_child(cam)
	cam.global_position = Vector3(20, 95, 17)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.far = 400.0
	cam.current = true
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("g_%02d_overhead.png" % _shots.size()))
	print("[grounds] done")
	get_tree().quit()
