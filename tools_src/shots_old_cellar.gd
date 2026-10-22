extends Node
## Dev tool: Map 0's Old Cellar (Update 02 section 6.1, T-051). Renders every room: Door 5 from the taproom, the
## lean-to stairs, the wine cellar, the coal room and the cage (shut and burst), the root cellar's top shelf, the
## ice cellar through its seal and opened, the barrel vault's loop (dark and with the lever thrown), the vault
## window, the breach, and both light wells from the field. Silent (buses muted), off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/shots_old_cellar.tscn -- --out=<dir>
var _out: String = "user://shots"
var map: Node3D
var cam: Camera3D


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_old_cellar_profile.json"
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
	await _shot("door_closed", Vector3(4.6, 1.6, 9.6), Vector3(0, 1.1, 9.05))
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		if str(d.get("door_id")) in ["door_old_cellar", "door_cellar"]:
			(d as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("stairs", Vector3(-1.2, 1.65, 8.5), Vector3(-1.6, -2.6, 16.5))
	await _shot("stair_foot", Vector3(-1.6, -1.55, 15.8), Vector3(4.0, -2.4, 17.0))
	await _shot("wine_cellar", Vector3(0.8, -1.6, 17.6), Vector3(9.0, -2.6, 10.0))
	await _shot("wine_cellar_2", Vector3(9.8, -1.6, 9.0), Vector3(1.0, -2.6, 16.0))
	await _shot("wine_casks", Vector3(5.0, -1.7, 15.0), Vector3(10.5, -2.6, 15.8))
	await _shot("coal_room_cage", Vector3(4.5, -1.5, 7.5), Vector3(1.2, -2.3, 4.6))
	await _shot("coal_window", Vector3(1.8, -1.9, 6.0), Vector3(3.45, -1.0, 0.0))
	await _shot("ice_seal", Vector3(3.2, -1.65, 6.7), Vector3(5.0, -1.8, 6.7))
	await _shot("root_cellar", Vector3(9.6, -1.6, 7.5), Vector3(6.0, -2.0, 1.0))
	await _shot("jam_jars", Vector3(6.5, -1.3, 2.4), Vector3(6.3, -0.7, 0.2))
	await _shot("vault_loop", Vector3(12.0, -1.4, 2.4), Vector3(19.0, -2.7, 9.5))
	await _shot("vault_loop_2", Vector3(23.2, -1.4, 15.2), Vector3(14.0, -2.7, 4.0))
	await _shot("vault_garand_side", Vector3(15.5, -1.6, 4.0), Vector3(11.0, -1.9, 6.6))
	await _shot("vault_window", Vector3(19.0, -1.9, 4.5), Vector3(24.0, -1.0, 1.8))
	await _shot("breach", Vector3(22.3, -1.6, 12.5), Vector3(22.6, -2.4, 21.0))
	await _shot("well_coal", Vector3(3.45, 1.8, -8.0), Vector3(3.45, -1.0, 0.0))
	await _shot("well_vault", Vector3(28.0, 1.9, -5.5), Vector3(24.6, -1.0, 2.0))
	await _shot("leanto_outside", Vector3(-9.0, 2.4, 6.0), Vector3(-1.5, 1.0, 13.0))
	var cage: Node = map.find_child("JakubCage", true, false)
	if cage != null:
		cage.call("burst_open", null)
	var seal: Node = map.find_child("IceCellarSeal", true, false)
	if seal != null:
		seal.call("open")
	await get_tree().create_timer(1.8).timeout
	await _shot("cage_burst", Vector3(4.5, -1.5, 7.5), Vector3(1.2, -2.3, 4.6))
	await _shot("ice_cellar_open", Vector3(4.0, -1.55, 6.7), Vector3(8.1, -2.4, 6.5))
	await _shot("ice_cellar_inside", Vector3(5.4, -1.6, 7.6), Vector3(8.1, -2.4, 5.6))
	var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
	if sw != null:
		sw.call("run_sequence", 1)
	await get_tree().create_timer(5.0).timeout
	await _shot("vault_loop_lit", Vector3(12.0, -1.4, 2.4), Vector3(19.0, -2.7, 9.5))
	await _shot("wine_cellar_lit", Vector3(0.8, -1.6, 17.6), Vector3(9.0, -2.6, 10.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_old_cellar_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("oc_%s.png" % label))
	print("[old cellar] shot ", label)
