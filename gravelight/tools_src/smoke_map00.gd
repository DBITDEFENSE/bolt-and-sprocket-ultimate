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
		["stable -> the yard (the yard door)", Vector3(15, 0, 29), Vector3(18, 0, 41), true],
		["yard -> round the well and the cart", Vector3(8, 0, 36), Vector3(31, 0, 46), true],
		["yard -> the field (must NOT connect)", Vector3(18, 0, 41), Vector3(18, 0, 56), false],
		["yard -> the cellar's roof (must NOT connect)", Vector3(18, 0, 41), Vector3(30, 0, 22), false],
		# the Old Cellar (Update 02 section 6.1, T-051)
		["taproom -> the Old Cellar's barrel vault", Vector3(14, 0, 8), Vector3(17.45, -3.2, 4.5), true],
		["vault -> the Helvetia cellar (round by the taproom)", Vector3(13, -3.2, 12), Vector3(30, -3.2, 25), true],
		["the lean-to landing -> the wine cellar", Vector3(-1.5, 0, 9.0), Vector3(5, -3.2, 15), true],
		["wine cellar -> root cellar -> vault", Vector3(5, -3.2, 10), Vector3(14, -3.2, 2.5), true],
		["coal room -> into the cage (door gap)", Vector3(3.6, -3.2, 6.0), Vector3(1.25, -3.2, 4.9), true],
		["coal room -> the ice cellar (behind the seal)", Vector3(3.6, -3.2, 6.8), Vector3(6.6, -3.2, 6.6), true],
		["field -> the coal-chute light well", Vector3(3.45, 0, -8), Vector3(3.45, -1.3, -1.0), true],
		["field -> the vault's light well", Vector3(25, 0, -6), Vector3(25.0, -1.3, 1.8), true],
		["coal well -> coal room (must NOT connect)", Vector3(3.45, -1.3, -1.0), Vector3(3.45, -3.2, 2.0), false],
		["vault well -> vault (must NOT connect)", Vector3(25, -1.3, 1.8), Vector3(22, -3.2, 1.8), false],
	]
	_check_loop(map_rid)
	_check_breach(map_rid)
	for c: Array in checks:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, c[1], c[2], true)
		var end_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(c[2]) < 1.0
		var ok: bool = end_ok == bool(c[3])
		print("[smoke] path %-44s %s (points %d, end %s)" % [c[0], "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
		if not ok:
			_fails.append("path check: " + str(c[0]))


## T-051: the Old Cellar's training loop round the barrel stack. Every sample on the ring (one per corridor, 2 m
## off the stack) is on the navmesh, the four link up in order, and each corridor is at least 2.2 m wide (casts
## both ways across it against the collision shell).
func _check_loop(map_rid: RID) -> void:
	var ring: Array[Vector3] = [Vector3(13.6, -3.2, 8.0), Vector3(17.45, -3.2, 4.7), Vector3(21.2, -3.2, 8.0), Vector3(17.45, -3.2, 11.4)]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.RIGHT, Vector3.BACK]
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var ok: bool = true
	var widths: PackedStringArray = []
	for i: int in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		if NavigationServer3D.map_get_closest_point(map_rid, a).distance_to(a + Vector3(0, 0.5, 0)) > 0.6:
			ok = false
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, a, b, true)
		if path.is_empty() or path[path.size() - 1].distance_to(b) > 1.0:
			ok = false
		var w: float = 0.0
		for s: float in [1.0, -1.0]:
			var from: Vector3 = a + Vector3.UP * 1.0
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + axes[i] * s * 8.0, 1)
			var hit: Dictionary = space.intersect_ray(q)
			w += 8.0 if hit.is_empty() else from.distance_to(hit["position"])
		widths.append("%.1f" % w)
		if w < 2.2:
			ok = false
	print("[smoke] Old Cellar loop round the barrel stack (widths %s m) %s" % [", ".join(widths), "ok" if ok else "WRONG"])
	if not ok:
		_fails.append("the Old Cellar's training loop")


## T-051: the breach between the Old Cellar and the Helvetia cellar is shut in the navmesh until both cellar
## doors are bought (no path may run through it while a door on that ring is shut), then opens on its own.
func _check_breach(map_rid: RID) -> void:
	var a: Vector3 = Vector3(22.4, -3.2, 19.0)
	var b: Vector3 = Vector3(25.6, -3.2, 20.25)
	var shut: float = _path_len(NavigationServer3D.map_get_path(map_rid, a, b, true))
	GameState.open_zone(&"CELLAR")
	GameState.open_zone(&"OLD_CELLAR")
	var br: SealedPassage = _map.find_child("CellarBreach", true, false) as SealedPassage
	var opened: bool = br != null and br.is_open and br.nav_link() != null and br.nav_link().enabled
	print("[smoke] the breach: shut path %.0f m (round by the taproom), opens with both cellars: %s" % [shut, str(opened)])
	if shut < 20.0 or not opened:
		_fails.append("the cellar breach (shut path %.1f m, opened %s)" % [shut, str(opened)])


func _path_len(path: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l
