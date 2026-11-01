extends Node
## T-142 (UPDATE 09 section 4): headless probe for the relief squads' edge spawns (data/gravelight/squads.json).
## Loads one map, waits for its navmesh, then prints the outdoor zombie spawns far from the players' start (the
## candidates an edge spawn was picked from) and checks every squads.json edge spawn of that map: it must snap onto
## the navmesh within 1.5 m, stand >= 20 m from the players' start, and have a path to the start on the always-open
## layers plus every zone (the squad walks in). One "[probe] RESULT" line; exit code = failures.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_squad_spawns.tscn -- --map=map00

const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
}

var _key: String = "map00"
var _map: MapRoot
var _frames: int = 0
var _fails: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_key = a.trim_prefix("--map=")
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	_map = (load(str(SCENES.get(_key, SCENES["map00"]))) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _physics_process(_delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	_frames += 1
	if _frames == 120:
		_probe()
		print("[probe] RESULT: %s %s" % [_key, "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]])
		get_tree().quit(_fails.size())


func _probe() -> void:
	var nav: RID = _map.get_world_3d().navigation_map
	var start: Vector3 = _map.spawn_transform(1).origin
	print("[probe] %s start %s iteration %d" % [_key, str(start.snapped(Vector3.ONE * 0.1)), NavigationServer3D.map_get_iteration_id(nav)])
	var rows: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null:
			continue
		var p: Vector3 = sp.global_position
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
		rows.append([ReliefSquad.flat(p, start), sp.name, String(sp.kind), String(sp.zone_id), p, snap.distance_to(p)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i: int in mini(14, rows.size()):
		var r: Array = rows[i]
		print("[probe]   cand %-26s %-7s zone %-10s at %s  %.0f m from start, snap %.2f" % [r[1], r[2], r[3], str((r[4] as Vector3).snapped(Vector3.ONE * 0.1)), r[0], r[5]])
	if OS.get_cmdline_user_args().has("--regions"):
		for n2: Node in _map.find_children("*", "NavigationRegion3D", true, false):
			var nr: NavigationRegion3D = n2 as NavigationRegion3D
			if nr.navigation_mesh == null:
				continue
			var vs: PackedVector3Array = nr.navigation_mesh.get_vertices()
			if vs.is_empty():
				continue
			var bb: AABB = AABB(nr.global_transform * vs[0], Vector3.ZERO)
			for v: Vector3 in vs:
				bb = bb.expand(nr.global_transform * v)
			print("[probe]   region %-28s layers %d  aabb %s .. %s  verts %d" % [nr.name, nr.navigation_layers,
				str(bb.position.snapped(Vector3.ONE * 0.5)), str(bb.end.snapped(Vector3.ONE * 0.5)), vs.size()])
		print("[probe]   zone bits %s always %s" % [str(_map.nav_zone_bits), str(_map.nav_always_bits)])
	var tbl: Dictionary = ReliefSquad.table()
	var mkey: String = ReliefSquad.map_key(String(_map.map_id))
	for f: Dictionary in ReliefSquad.factions_for(mkey, tbl):
		var i2: int = 0
		for e: Variant in f.get("edge_spawns", []):
			var p2: Vector3 = ReliefSquad.vec(e)
			var snap2: Vector3 = NavigationServer3D.map_get_closest_point(nav, p2)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, snap2, start, true)
			var reach: bool = not path.is_empty() and path[path.size() - 1].distance_to(start) < 2.5
			var d: float = ReliefSquad.flat(p2, start)
			var ok: bool = snap2.distance_to(p2) < 1.5 and d >= 20.0 and reach
			print("[probe]   %s %s edge %d at %s: snap %.2f, %.0f m from start, path %s -> %s" % [mkey, str(f.get("id", "?")), i2,
				str(p2), snap2.distance_to(p2), d, "yes" if reach else "NO", "ok" if ok else "BAD"])
			if not ok:
				_fails.append("%s:%s:%d" % [mkey, str(f.get("id", "?")), i2])
			i2 += 1
