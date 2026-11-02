extends Node
## Shared harness for the UPDATE 10 §3 Act III smokes (smoke_dust_storm, smoke_wreck_collapse, smoke_radar_ping,
## smoke_map04c_world; DECISIONS T-157): loads Groom Lake the way the launcher's "skip to Act III" does (Campaign
## begin_at match round 21 with the arrival kit), no bots, god mode, the egg help off; a subclass overrides `_body()`
## and calls `_check()`. One "[<tag>] RESULT: PASS|FAIL" line at the end (tools/run_smokes.sh reads it).

const MAP: String = "res://gravelight/maps/map04_fernflug/map04c.tscn"
const TIMEOUT: float = 600.0

var tag: String = "m4c"
var bots: int = 0
var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _gc: GroomController
var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_%s.json" % tag
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_%s_settings.cfg" % tag
	GLSettings.values["bot_ee_help"] = "off"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = bots
	Campaign.begin_at(&"map04c_groomlake", 21, Campaign.arrival_kit(&"map04c_groomlake"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
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
	_gc = _g("GroomController") as GroomController
	await _body()
	_finish()


## The test itself (subclasses).
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
	print("[%s] %-78s %s" % [tag, what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


## Every door that needs no power bought (the zones the squad would have opened by mid-act).
func _open_doors(include_power: bool = false) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var bd: BuyDoor = n as BuyDoor
		if bd != null and not bd.is_open and (include_power or not bd.requires_power):
			bd.open(0)
	await _frames(3)


## Every active zombie away (the smokes place their own).
func _clear_zombies() -> void:
	for z: Zombie in _dir.active_zombies():
		if not (z is HomageBoss):
			z.kill_silently()
	await _frames(4)


## A plain Gänger by console at `pos`, chasing (its window let go), physics on.
func _chaser_at(pos: Vector3) -> Zombie:
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	if zs.is_empty():
		return null
	var z: Zombie = zs[zs.size() - 1]
	z.global_position = pos
	if z.window != null:
		z.window.release(z)
	z.window = null
	z.collision_mask = Zombie.LAYER_WORLD | Zombie.LAYER_PLAYER | Zombie.LAYER_ZBODY | Zombie.LAYER_DOOR
	z._enter(Zombie.State.CHASE)
	await _frames(2)
	return z


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _hud_banner() -> String:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud == null:
		return ""
	var b: Variant = hud.get("_banner")
	return str((b as Label).text) if b is Label else ""


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[%s] RESULT: %s" % [tag, "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
