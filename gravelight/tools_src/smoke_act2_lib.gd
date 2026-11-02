extends Node
## UPDATE 10 §3 (T-156): the shared harness of the Act II set-piece smokes (smoke_wing_walk, smoke_turbulence,
## smoke_decompression, smoke_map04b_world). Enters der Kranich the way the launcher's "skip to Act II" does
## (Campaign.begin_at, match round 15), stops the round clock and hands the scene to `_body()`; one RESULT line.

const MAP: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"
const TIMEOUT: float = 600.0

var tag: String = "act2"
var bots: int = 0
var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fc: FlightController
var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_%s.json" % tag
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_%s_settings.cfg" % tag
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = bots
	Campaign.begin_at(&"map04b_kranich", 15, Campaign.arrival_kit(&"map04b_kranich"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	_fc = get_tree().get_first_node_in_group(&"flight_controller") as FlightController
	RoundManager.stop()
	Economy.grant(1, 100000)
	await _body()
	_finish()


## Override: the smoke's steps.
func _body() -> void:
	pass


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _check(cond: bool, what: String) -> void:
	print("[%s] %-72s %s" % [tag, what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


## A ganger standing at `pos` and chasing (out of its emerge), from the director's pool.
func _zombie_on(pos: Vector3, hp: float = -1.0) -> Zombie:
	RoundManager.to_spawn += 1
	var spec: Dictionary = _dir._spec_for(&"ganger", RoundManager.take_spawn())
	var z: Zombie = _dir._activate_at(spec, pos)
	if z == null:
		return null
	await _until(func() -> bool: return z.state != Zombie.State.EMERGE, 6.0)
	z.global_position = pos
	if hp > 0.0:
		z.hp = hp
	await _frames(2)
	return z


func _path_ok(from: Vector3, to: Vector3, layers: int) -> bool:
	var rid: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, from, to, true, layers)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.5


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[%s] RESULT: %s" % [tag, "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
