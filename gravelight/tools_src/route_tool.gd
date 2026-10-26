extends Node
## Training-route tool (Update 03 section 3, T-056). Loads a map, waits for the navmesh, then:
##   --validate                      checks every route in data/gravelight/ai/routes_<map>.json on the navmesh
##                                   (TrainingRoute.validate_on) and prints PASS/FAIL per route
##   --dump=x0,z0,x1,z1,y[,step]     prints the walkable navmesh of a box as ASCII (. walkable, # not), with the
##                                   routes' samples drawn as o (for authoring points)
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/route_tool.tscn -- --map=map00 --validate
## Exit code: the number of routes that failed validation.

const MAPS: Dictionary = {"map00": "res://gravelight/maps/map00_crossroads/map00.tscn", "map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "map02": "res://gravelight/maps/map02_totenhafen/map02.tscn"}

var _map_key: String = "map00"
var _validate: bool = false
var _dump: PackedFloat32Array = PackedFloat32Array()
var _probe: PackedFloat32Array = PackedFloat32Array()
var _map: Node3D
var _frames: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_map_key = a.substr(6)
		elif a == "--validate":
			_validate = true
		elif a.begins_with("--probe="):
			for v: String in a.substr(8).split(","):
				_probe.append(float(v))
		elif a.begins_with("--dump="):
			for v: String in a.substr(7).split(","):
				_dump.append(float(v))
	ProfileSave.path = "user://_qa_routes_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.bot_count = 0
	_map = (load(str(MAPS[_map_key])) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _map == null or not _map.is_inside_tree() or _frames < 30:
		return
	var world: World3D = _map.get_world_3d()
	if NavigationServer3D.map_get_iteration_id(world.navigation_map) <= 0:
		return
	set_physics_process(false)
	var fails: int = 0
	var k: int = 0
	while k + 2 < _probe.size():
		var pp: Vector3 = Vector3(_probe[k], _probe[k + 1], _probe[k + 2])
		print("[routes] probe %s -> closest navmesh point %s" % [pp, NavigationServer3D.map_get_closest_point(world.navigation_map, pp)])
		k += 3
	if _probe.size() >= 6:
		var a: Vector3 = Vector3(_probe[0], _probe[1], _probe[2])
		var b: Vector3 = Vector3(_probe[3], _probe[4], _probe[5])
		print("[routes] path %s -> %s: %s" % [a, b, NavigationServer3D.map_get_path(world.navigation_map, a, b, true)])
	if _dump.size() >= 5:
		_print_dump(world)
	if _validate:
		fails = validate_map(world, _map_key)
		print("[routes] RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_routes_profile.json"))
	get_tree().quit(fails)


## Validates every authored route of `map_key` in `world`; prints a line per route. Returns the failures.
static func validate_map(world: World3D, map_key: String) -> int:
	var fails: int = 0
	var routes: Array[TrainingRoute] = TrainingRoute.all_for_map(map_key)
	if routes.is_empty():
		print("[routes] no routes for %s" % map_key)
		return 1
	for r: TrainingRoute in routes:
		var res: Dictionary = r.validate_on(world)
		print("[routes] %s %s: %.1f m loop, width min %.1f / mean %.1f m (ring %.1f), %d samples, needs %s" % [
			"PASS" if bool(res["ok"]) else "FAIL", r.id, float(res["length"]), float(res["min_width"]), float(res["mean_width"]),
			r.ring_width, r.samples.size(), ",".join(r.requires_doors + r.requires_zones) if not (r.requires_doors + r.requires_zones).is_empty() else "-"])
		if not bool(res["ok"]):
			fails += 1
			var probs: PackedStringArray = res["problems"]
			for k: int in mini(probs.size(), 12):
				print("[routes]    ", probs[k])
			if probs.size() > 12:
				print("[routes]    ... %d more" % (probs.size() - 12))
	return fails


func _print_dump(world: World3D) -> void:
	var x0: float = _dump[0]
	var z0: float = _dump[1]
	var x1: float = _dump[2]
	var z1: float = _dump[3]
	var y: float = _dump[4]
	var step: float = _dump[5] if _dump.size() > 5 else 0.5
	var nav: RID = world.navigation_map
	var marks: Dictionary = {}
	for r: TrainingRoute in TrainingRoute.all_for_map(_map_key):
		for s: Vector3 in r.samples:
			if absf(s.y - y) < 1.0:
				marks[Vector2i(int(floor((s.x - x0) / step)), int(floor((s.z - z0) / step)))] = true
	print("[routes] dump %s x %.1f..%.1f (cols), z %.1f..%.1f (rows, top = north), y %.1f, %.2f m per char" % [_map_key, x0, x1, z0, z1, y, step])
	var header: String = "        "
	var cx: float = x0
	var col: int = 0
	while cx < x1:
		header += str(int(absf(floor(cx))) % 10) if col % 2 == 0 else " "
		cx += step
		col += 1
	print(header)
	var z: float = z0
	var row: int = 0
	while z < z1:
		var line: String = "%7.1f " % z
		var x: float = x0
		var ci: int = 0
		while x < x1:
			var p: Vector3 = Vector3(x + step * 0.5, y, z + step * 0.5)
			var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p + Vector3.UP * 0.4)
			var walk: bool = Vector2(c.x - p.x, c.z - p.z).length() < step * 0.6 and absf(c.y - y) < 0.8
			if marks.has(Vector2i(ci, row)):
				line += "o" if walk else "X"
			else:
				line += "." if walk else "#"
			x += step
			ci += 1
		print(line)
		z += step
		row += 1
