extends "res://gravelight/tools_src/smoke_m4c_base.gd"
## UPDATE 10 §3 Act III `wreck_collapse` (T-157): the bay roof falls on act round 3 and the west hull on act round 6
## (match 23 / 26), each telegraphed 10 s ahead (groans, sparks); a player under it is pushed clear (never crushed),
## a zombie under it dies; the debris leaves the navmesh (the wreck's region re-baked); a crate spot opens in the
## bay; the west window is sealed and the bulkhead's plate tears out (a new gap and link to the salt). The fuel fire
## spreads one node per act round and its hull nodes burn.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_wreck_collapse.tscn


func _init() -> void:
	tag = "wreck"


func _path_end(from: Vector3, to: Vector3, mask: int) -> Vector3:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map.get_world_3d().navigation_map, from, to, true, mask)
	return path[path.size() - 1] if not path.is_empty() else Vector3.INF


func _path_len(from: Vector3, to: Vector3, mask: int) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map.get_world_3d().navigation_map, from, to, true, mask)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > 1.2:
		return INF
	var l: float = 0.0
	for i: int in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l


func _body() -> void:
	var wc: Dictionary = _gc.cfg.get("wreck_collapse", {})
	_check((wc.get("sections", []) as Array).size() == 2, "map04c.json: two wreck sections")
	_check(GroomController.collapse_due(3, wc, {}).size() == 1 and GroomController.collapse_due(6, wc, {}).size() == 1 and GroomController.collapse_due(4, wc, {}).is_empty(), "the schedule: act rounds 3 and 6")
	RoundManager.stop()
	await _open_doors()
	await _clear_zombies()
	var crates0: int = get_tree().get_nodes_in_group(&"crate_spots").size()
	var plate: StaticBody3D = _g("BulkheadPlate") as StaticBody3D
	_check(plate != null and plate.collision_layer == 1, "the bulkhead plate stands in the x 10 opening")
	var mask_a: int = 1
	var bay: Vector3 = Vector3(-11.0, 0, -8.0)
	_check(_path_end(Vector3(0, 0, -30), bay, mask_a).distance_to(bay) < 1.2, "before: the west bay is on the navmesh")

	# --- the bay roof: the warning, the shove, the crush, the navmesh, the crate spot
	await _tp(bay, 0.0)
	var z: Zombie = await _chaser_at(Vector3(-12.0, 0, -10.5))
	if z != null:
		z.set_physics_process(false)
	var sec: Dictionary = _gc._section("bay_roof")
	_gc._warn_collapse(sec)
	await _frames(3)
	_check(_map.find_child("CollapseSparks_bay_roof", true, false) != null, "the telegraph: sparks fall over the bay roof's box")
	_check(not _gc.collapsed.has("bay_roof"), "it has not fallen yet")
	var hp0: float = _p.hp
	await _secs(10.8)
	_check(_gc.collapsed.has("bay_roof"), "10 s later the bay roof falls")
	await _secs(1.2)
	var box: Array = sec["box"]
	_check(not GroomController.in_box(_p.global_position, box) and _p.global_position.y < 2.0, "the player under it was pushed clear, feet on the floor (%s)" % str(_p.global_position))
	_check(_p.is_alive() and _p.hp >= hp0 - 0.1, "nobody is crushed (hp %.0f -> %.0f)" % [hp0, _p.hp])
	_check(z == null or z.state == Zombie.State.DEAD or not z.is_active(), "the zombie under it is crushed")
	_check(_gc.nav_rebakes >= 1, "the wreck's navmesh was re-baked (%d)" % _gc.nav_rebakes)
	var e: Vector3 = _path_end(Vector3(0, 0, -30), Vector3(-11.0, 0, -8.5), mask_a)
	_check(e == Vector3.INF or e.distance_to(Vector3(-11.0, 0, -8.5)) > 1.4, "after: the debris is off the navmesh (path ends %s)" % str(e))
	_check(_path_end(Vector3(0, 0, -30), Vector3(0, 0, -6), mask_a).distance_to(Vector3(0, 0, -6)) < 1.2, "after: the aft -> the bay door still walks")
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == crates0 + 1, "a crate spot opened in the bay (%d -> %d)" % [crates0, get_tree().get_nodes_in_group(&"crate_spots").size()])

	# --- the west hull: the window sealed, the bulkhead's gap
	var long_way: float = _path_len(Vector3(10, 0, -8), Vector3(10, 0, 2), 1 | 2)
	_gc.collapse("hull_west")
	await _secs(1.5)
	_check(_gc.collapsed.has("hull_west"), "the west hull falls (act round 6)")
	var sp: ZombieSpawn = _g("Spawn_W_A_L") as ZombieSpawn
	_check(sp != null and not sp.enabled, "the west window's spawn is sealed")
	_check(plate != null and plate.collision_layer == 0, "the bulkhead plate is out: players walk through")
	var short_way: float = _path_len(Vector3(10, 0, -8), Vector3(10, 0, 2), 1 | 2)
	_check(short_way < long_way - 3.0, "the gap: zombies take the new way to the salt (%.1f m, was %.1f m)" % [short_way, long_way])
	_check(_gc.nav_rebakes >= 2, "re-baked again (%d)" % _gc.nav_rebakes)

	# --- the fire spreads along the wing, one node per act round from act round 2
	_gc._collapse_round(4)
	await _frames(2)
	_check(_gc.spread_n == 3 and _gc.spread_points().size() == 3, "act round 4: three spread nodes burn (%d)" % _gc.spread_n)
	_check(_map.find_child("FireSpread_wing_2", true, false) != null and _map.find_child("FireSpread_hull_2", true, false) != null, "flames on the wing and along the hull wall")
	GameState.god_mode = false
	_p.set_physics_process(false)
	_p.global_position = _gc.spread_points()[0]
	var h1: float = _p.hp
	await _secs(1.0)
	_check(_p.hp < h1, "the hull's fire burns (%.0f -> %.0f)" % [h1, _p.hp])
	_p.global_position = Vector3(0, 0, -26)
	GameState.god_mode = true
	_p.set_physics_process(true)
	_gc._collapse_round(30)
	_check(_gc.spread_n == 5, "the loop past round 9: the spread stops at the path's end (%d)" % _gc.spread_n)
