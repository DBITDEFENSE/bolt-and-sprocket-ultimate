extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Probe (T-153, not a smoke): can a bot walk from the quay to every Letzte Fahrt object? Opens every door (the power
## ones too: the power is thrown), then asks the navmesh for a path from the spawn to each placed node in the egg's
## groups and to the nodes' interact points, and prints the path's end distance. A row "FAR" is a spot a bot can't
## reach. Run: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_lf_reach.tscn

const GROUPS: Array = [&"lf_radios", &"cipher_machines", &"lf_log_pages", &"diesel_holdouts", &"lf_key_slot", &"lf_curtain_lever",
	&"ballast_dumps", &"ballast_hooks", &"ballast_coffins", &"buildable_parts", &"workbenches", &"searchlights", &"uboat_sail", &"pump_cranks"]


func _init() -> void:
	tag = "lf_reach"


func _body() -> void:
	GameState.power_on = true
	GLBus.power_activated.emit()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		(n as BuyDoor).open(0)
	await _frames(30)
	var rid: RID = _map.get_world_3d().navigation_map
	var from: Vector3 = Vector3(25.0, 0.0, 21.0)
	var far: int = 0
	for g: StringName in GROUPS:
		var nodes: Array = get_tree().get_nodes_in_group(g)
		if nodes.is_empty():
			print("[lf_reach] %-20s (no nodes)" % g)
		for n: Node in nodes:
			var n3: Node3D = n as Node3D
			if n3 == null or not n3.is_inside_tree():
				continue
			var to: Vector3 = n3.global_position
			var near: Vector3 = NavigationServer3D.map_get_closest_point(rid, to)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, from, near, true, 0xFFFFFFFF)
			var end: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.INF
			var d_mesh: float = Vector2(near.x - to.x, near.z - to.z).length()
			var d_end: float = end.distance_to(near) if end != Vector3.INF else 999.0
			var bad: bool = d_mesh > 1.6 or absf(near.y - to.y) > 1.2 or d_end > 1.0
			if bad:
				far += 1
			print("[lf_reach] %-20s %-34s at %s  navmesh %.2f m (dy %.2f)  path end %.2f m  %s" % [g, n.name, str(to), d_mesh, near.y - to.y, d_end, "FAR" if bad else "ok"])
	print("[lf_reach] %d unreachable" % far)
