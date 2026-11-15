extends Node
## Dev tool: the Map 0 cellar. Checks the navmesh route taproom -> cellar (door open) and renders views:
## the door, the stairs, the vault, the Lagering Vault and the Dynamo Room behind their doors (T-251) unpowered and
## powered, the lever, a machine's front and back wherever the match's deal stood it. Silent (buses muted), off-screen:
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
	var doors: Dictionary = {}
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		doors[str(d.get("door_id"))] = d
	await _shot("door_closed", Vector3(19.5, 1.7, 11.5), Vector3(24, 1.2, 11.5))
	(doors["door_cellar"] as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("stairs", Vector3(25.6, 1.6, 11.0), Vector3(26, -2.5, 19))
	await _shot("vault_dark", Vector3(30, -1.6, 19.8), Vector3(30, -2.6, 28))
	await _shot("vault_alcove_dark", Vector3(29.5, -1.6, 23.4), Vector3(29.5, -2.2, 19.2))   # (T-251: the wash copper where the Crucible stood)
	# T-251: the two rooms past the vault, each behind its own door; the lever and the Crucible are in the second
	await _shot("door_lager_closed", Vector3(26.0, -1.6, 25.0), Vector3(26.0, -2.0, 31.0))
	(doors["door_lager"] as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("lager_dark", Vector3(24.9, -1.6, 31.9), Vector3(32.5, -2.4, 35.0))
	await _shot("door_dynamo_closed", Vector3(30.5, -1.6, 35.6), Vector3(34.0, -2.0, 35.4))
	(doors["door_dynamo"] as BuyDoor).open(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("dynamo_dark", Vector3(34.8, -1.6, 38.2), Vector3(40.5, -2.3, 33.6))
	var sw: Node3D = get_tree().get_first_node_in_group(&"power_switch") as Node3D
	await _shot("lever", sw.global_position + Vector3(0.0, 1.5, 2.2), sw.global_position + Vector3(0, 0.9, 0))
	sw.call("run_sequence", 1)
	await get_tree().create_timer(4.0).timeout
	await _shot("dynamo_lit", Vector3(34.8, -1.6, 38.2), Vector3(40.5, -2.3, 33.6))
	await _shot("dynamo_crucible_lit", Vector3(37.5, -1.6, 35.2), Vector3(37.5, -2.0, 31.9))
	await _shot("lager_lit", Vector3(24.9, -1.6, 31.9), Vector3(32.5, -2.4, 35.0))
	await _shot("vault_lit", Vector3(30, -1.6, 19.8), Vector3(30, -2.6, 28))
	# a machine wherever this match's deal stood one (the first in the group): its front, its back (the fine print),
	# its stencil under an upgraded muzzle flash, the reader
	var pm0: PerkMachine = get_tree().get_first_node_in_group(&"perk_machines") as PerkMachine
	var f: Vector3 = pm0.global_basis * Vector3(0, 0, -1)
	var eye: Vector3 = pm0.global_position + f * 2.7 + Vector3.UP * 1.6
	await _shot("machine_front", eye, pm0.global_position + Vector3.UP * 1.1)
	await _shot("machine_back", pm0.global_position - f * 1.5 + pm0.global_basis * Vector3(0.9, 1.6, 0), pm0.global_position + Vector3.UP * 1.1)
	GLBus.weapon_fired.emit(1, &"kar98k", true, eye, (pm0.global_position + Vector3.UP * 0.2 - eye).normalized())
	await _shot("stencil", eye, pm0.global_position + Vector3.UP * 0.3)
	await get_tree().create_timer(2.0).timeout
	await _shot("stencil_faded", eye, pm0.global_position + Vector3.UP * 0.3)
	FinePrintReader.open_for(map.get("player") as Player, pm0.perk_id)
	await _shot("reader", eye, pm0.global_position + Vector3.UP * 0.3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_cellar_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("cellar_%s.png" % label))
	print("[cellar] shot ", label)
