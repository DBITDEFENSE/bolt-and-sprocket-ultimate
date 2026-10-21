extends Node
## Dev tool: the Map 0 cellar. Checks the navmesh route taproom -> cellar (door open) and renders views:
## the door, the stairs, the vault unpowered and powered, a machine's back. Silent (buses muted), off-screen:
##   godot --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/shots_cellar.tscn -- --out=<dir>
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
	ProfileSave.path = "user://_shots_cellar_profile.json"
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var nav: RID = map.get_world_3d().navigation_map
	var from: Vector3 = NavigationServer3D.map_get_closest_point(nav, Vector3(14, 0, 7))
	var to: Vector3 = NavigationServer3D.map_get_closest_point(nav, Vector3(30, -3.2, 25))
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, from, to, true)
	print("[cellar] nav to cellar: %d points, end %s (want (30,-3.2,25))" % [path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.INF])
	for m: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: Node3D = m as Node3D
		print("[cellar] machine %s at %s" % [pm.get("perk_id"), pm.global_position.snapped(Vector3.ONE * 0.1)])
	var p: Player = map.get("player") as Player
	if p != null:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
	cam = Camera3D.new()
	cam.fov = 75
	map.add_child(cam)
	cam.make_current()
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		if str(d.get("door_id")) == "door_cellar":
			await _shot("door_closed", Vector3(19.5, 1.7, 11.5), Vector3(24, 1.2, 11.5))
			(d as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("stairs", Vector3(25.6, 1.6, 11.0), Vector3(26, -2.5, 19))
	await _shot("vault_dark", Vector3(30, -1.6, 19.8), Vector3(30, -2.6, 28))
	await _shot("west_row_dark", Vector3(31.5, -1.6, 24.6), Vector3(25.9, -2.2, 25.8))
	var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
	sw.call("run_sequence", 1)
	await get_tree().create_timer(4.0).timeout
	await _shot("vault_lit", Vector3(30, -1.6, 19.8), Vector3(30, -2.6, 28))
	await _shot("west_row_lit", Vector3(31.5, -1.6, 24.6), Vector3(25.9, -2.2, 25.8))
	await _shot("east_row_lit", Vector3(28.5, -1.6, 24.6), Vector3(34.1, -2.2, 24.6))
	await _shot("machine_back", Vector3(24.6, -1.5, 24.6), Vector3(25.9, -2.0, 23.0))
	await _shot("lever", Vector3(32.5, -1.4, 21.5), Vector3(32.5, -2.0, 19.35))
	# an upgraded muzzle flash at the Ironhide machine reveals its stencil
	var eye: Vector3 = Vector3(28.6, -1.6, 23.0)
	GLBus.weapon_fired.emit(1, &"kar98k", true, eye, (Vector3(25.9, -3.0, 23.0) - eye).normalized())
	await _shot("stencil", eye, Vector3(25.9, -2.9, 23.0))
	await get_tree().create_timer(2.0).timeout
	await _shot("stencil_faded", eye, Vector3(25.9, -2.9, 23.0))
	FinePrintReader.open_for(map.get("player") as Player, &"ironhide_stout")
	await _shot("reader", eye, Vector3(25.9, -2.9, 23.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_cellar_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("cellar_%s.png" % label))
	print("[cellar] shot ", label)
