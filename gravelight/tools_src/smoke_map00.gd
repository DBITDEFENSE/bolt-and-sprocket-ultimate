extends Node
## Headless smoke test for Map 0: loads the map, runs the round loop with a god-mode player standing
## in the taproom, and reports navmesh connectivity, zombie state counts, hits, and round progression.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_map00.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: Node3D
var _t: float = 0.0
var _frames: int = 0
var _hits: int = 0
var _kills: int = 0
var _rounds_seen: Array[int] = []
var _phase: int = 0
var _state_hist: Dictionary = {}
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_p: int, _a: float) -> void: _hits += 1)
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, _b: int) -> void: _kills += 1)
	GLBus.round_started.connect(func(r: int, _s: bool) -> void: _rounds_seen.append(r))


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	_frames += 1
	if _frames == 30:
		_check_paths()
		_check_crucible()
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	for z: Zombie in dir.active_zombies():
		var key: String = str(Zombie.State.keys()[z.state])
		_state_hist[key] = int(_state_hist.get(key, 0)) + 1
	# Phase 0: let round 1 play out for 70 s of game time with the player standing still.
	if _phase == 0 and _t > 70.0:
		print("[smoke] after 70s: round=%d alive=%d queued=%d hits_on_player=%d" % [RoundManager.current_round, RoundManager.alive, RoundManager.to_spawn, _hits])
		print("[smoke] state frames: ", _state_hist)
		if _hits == 0:
			_fails.append("no zombie ever hit the player")
		if not _state_hist.has("CHASE"):
			_fails.append("no zombie reached CHASE (never got inside)")
		dir.kill_all(false)
		_phase = 1
	# Phase 1: kill everything as it spawns until round 3 starts.
	elif _phase == 1:
		for z: Zombie in dir.active_zombies():
			z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
		if RoundManager.current_round >= 3:
			print("[smoke] reached round %d, kills=%d, scrip=%d" % [RoundManager.current_round, _kills, Economy.get_scrip(1)])
			_phase = 2
		elif _t > 200.0:
			_fails.append("round loop stalled at round %d (alive %d queued %d)" % [RoundManager.current_round, RoundManager.alive, RoundManager.to_spawn])
			_phase = 2
	if _phase == 2:
		print("[smoke] rounds seen: ", _rounds_seen)
		if _fails.is_empty():
			print("[smoke] PASS")
		else:
			for f: String in _fails:
				print("[smoke] FAIL: ", f)
		get_tree().quit(0 if _fails.is_empty() else 1)
		set_physics_process(false)


## T-032: Map 0 has a Crucible, in the Helvetia cellar (below ground, south of the stair hall).
func _check_crucible() -> void:
	var cru: Node3D = get_tree().get_first_node_in_group(&"crucible") as Node3D
	var ok: bool = cru != null and cru.global_position.y < -2.0 and cru.global_position.z > 19.0
	print("[smoke] crucible in the Helvetia cellar                   %s" % ("ok" if ok else "MISSING"))
	if not ok:
		_fails.append("no Crucible in the cellar")


func _check_paths() -> void:
	var map_rid: RID = _map.get_world_3d().navigation_map
	var checks: Array = [
		["taproom -> upstairs hall", Vector3(14, 0, 8), Vector3(12, 3.8, 8), true],
		["taproom -> stable", Vector3(14, 0, 8), Vector3(15, 0, 29), true],
		["taproom -> hayloft", Vector3(14, 0, 8), Vector3(9, 3.5, 27), true],
		["outside N -> taproom (must NOT connect)", Vector3(7, 0, -6), Vector3(14, 0, 8), false],
		["outside W -> outside E (around the inn)", Vector3(-6, 0, 6), Vector3(30, 0, 8), true],
		["ledge -> upstairs (must NOT connect)", Vector3(2.5, 3.8, -1.5), Vector3(4, 3.8, 3), false],
	]
	for c: Array in checks:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, c[1], c[2], true)
		var end_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(c[2]) < 1.0
		var ok: bool = end_ok == bool(c[3])
		print("[smoke] path %-44s %s (points %d, end %s)" % [c[0], "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
		if not ok:
			_fails.append("path check: " + str(c[0]))
