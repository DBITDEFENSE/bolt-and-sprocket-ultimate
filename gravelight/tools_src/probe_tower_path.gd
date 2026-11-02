extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Probe (T-153, not a smoke): the navmesh route from the north apron to the signal tower's door with the tower zone
## shut (the open-zone mask a bot uses) and over every layer, waypoint by waypoint. Run: godot --headless
## --audio-driver Dummy --path . res://gravelight/tools_src/probe_tower_path.tscn


func _init() -> void:
	tag = "tower_path"


func _body() -> void:
	GameState.power_on = true
	GLBus.power_activated.emit()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if String(d.door_id) != "door_signal":
			d.open(0)
	await _frames(30)
	_dir.recompute_nav_mask()
	var rid: RID = _map.get_world_3d().navigation_map
	var from: Vector3 = Vector3(32.1, 0.0, 34.2)
	for to: Vector3 in [Vector3(36.5, 5.8, 34.0), Vector3(34.0, 5.0, 34.0), Vector3(30.0, 4.0, 34.0), Vector3(40.9, 7.0, 34.0)]:
		for m: int in [_dir.nav_mask & ClimbLink.WALK_MASK, _dir.nav_mask, 0x7FFFFFFF]:
			var near: Vector3 = NavigationServer3D.map_get_closest_point(rid, to)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, from, near, true, m)
			var pts: PackedStringArray = []
			for p: Vector3 in path:
				pts.append(str(p.snapped(Vector3.ONE * 0.1)))
			var end: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.INF
			print("[tower_path] to %s (near %s) mask %s: end %.2f m off, %d pts: %s" % [to, near.snapped(Vector3.ONE * 0.1),
				("bots" if m == (_dir.nav_mask & ClimbLink.WALK_MASK) else ("zombies" if m == _dir.nav_mask else "all")), end.distance_to(near) if end != Vector3.INF else 999.0, path.size(), " ".join(pts)])
