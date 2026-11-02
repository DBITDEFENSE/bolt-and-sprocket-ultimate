extends Node
## The shared harness of UPDATE 10 §3 Act IV's smokes (T-158): smoke_terminator, smoke_earthrise, smoke_low_g,
## smoke_meteors, smoke_map04d_world. Each extends this, names itself in TAG and writes `_body()`. The act is entered
## the way the launcher's "skip to Act IV" does (Campaign.begin_at at match round 30 with the arrival kit), the
## round clock is stopped, the human is in god mode with money, and the VO lines played are recorded.

const MAP: String = "res://gravelight/maps/map04_fernflug/map04d.tscn"
const TIMEOUT: float = 600.0

var TAG: String = "u10"
var BOTS: int = 0
var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _vo: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_%s.json" % TAG
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_%s_settings.cfg" % TAG
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = BOTS
	Campaign.begin_at(&"map04d_mondlicht", 30, Campaign.arrival_kit(&"map04d_mondlicht"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.vo_line_started.connect(func(id: StringName, _s: StringName, _tx: String, _d: float) -> void: _vo.append(String(id)))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


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
	print("[%s] %-78s %s" % [TAG, what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


## A fresh Gänger at `pos`, risen and on its feet (spawned there from the director's pool; null if none came).
func _zombie_at(pos: Vector3) -> Zombie:
	var before: Array[Zombie] = _dir.active_zombies().duplicate()
	_dir.spawn_special(&"ganger", 1, [pos])
	await _frames(3)
	var z: Zombie = null
	for c: Zombie in _dir.active_zombies():
		if not before.has(c):
			z = c
	if z == null:
		return null
	await _until(func() -> bool: return z.state != Zombie.State.EMERGE, 8.0)
	z.global_position = pos
	await _frames(2)
	return z


func _said(prefix: String) -> bool:
	for id: String in _vo:
		if id.begins_with(prefix):
			return true
	return false


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group)


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	Economy.grant(1, 100000)
	_dir.kill_all(true)
	await _frames(5)
	await _body()
	_finish()


## Override: the smoke's steps.
func _body() -> void:
	pass


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[%s] RESULT: %s" % [TAG, "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
