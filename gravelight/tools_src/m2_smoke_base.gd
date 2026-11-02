extends Node
## Shared scaffold for the UPDATE 10 Totenhafen smokes (smoke_tide2, smoke_ballast2, smoke_sail, smoke_letzte_fahrt;
## T-153): loads map02 with the human (god mode) and `bots` bots, gives Scrip, stops the rounds, and offers the checks
## and helpers smoke_map02 uses. A smoke extends this and overrides `tag` and `_body()`.

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const LY: float = -3.0
const SY: float = -2.0
const TY: float = 7.0

var tag: String = "m2x"
var bots: int = 0
var stop_rounds: bool = true
var _map: MapRoot
var _p: Player
var _dir: ZombieDirector
var _t: Totenhafen
var _tide: TideController
var _fails: PackedStringArray = []
var _timeout_s: float = 900.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_%s.json" % tag
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_settings_%s.cfg" % tag
	GameState.character_id = &"wren"
	GameState.bot_count = bots
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	get_tree().create_timer(_timeout_s).timeout.connect(func() -> void:
		_check(false, "the smoke finished within %d s" % int(_timeout_s))
		_finish())
	_run.call_deferred()


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	_t = Totenhafen.of(get_tree())
	_tide = get_tree().get_first_node_in_group(&"tide") as TideController
	if stop_rounds:
		RoundManager.stop()
	Economy.grant(1, 100000)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	_check(_t != null and _tide != null, "Totenhafen's systems are attached")
	await _body()
	_finish()


func _body() -> void:
	pass


func _finish() -> void:
	print("[%s] RESULT: %s" % [tag, "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Wait until `pred` is true or `s` seconds pass; true when it came true.
func _until(pred: Callable, s: float) -> bool:
	var t: float = 0.0
	while t < s:
		if bool(pred.call()):
			return true
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	return bool(pred.call())


func _check(cond: bool, what: String) -> void:
	print("[%s] %-66s %s" % [tag, what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


## A frozen zombie placed at `pos` (physics off so it stays put; the systems act on it).
func _zombie_at(pos: Vector3, frozen: bool = true) -> Zombie:
	var zs: Array[Zombie] = []
	for attempt: int in 20:
		_dir.debug_spawn(1)
		await _frames(3)
		zs = _dir.active_zombies()
		if not zs.is_empty():
			break
	if zs.is_empty():
		_check(false, "a test zombie could be spawned")
		return null
	var z: Zombie = zs[zs.size() - 1]
	for c: Zombie in zs:
		if c.state == Zombie.State.TO_WINDOW or c.state == Zombie.State.EMERGE:
			z = c
	z.global_position = pos
	if frozen:
		z.set_physics_process(false)
	await _frames(2)
	return z


## The authority's use of an interactable as player `p` (no hold timer).
func _use(n: Node, p: Player = null) -> void:
	var who: Player = p if p != null else _p
	if n is Interactable:
		(n as Interactable).interact(who)
	await _frames(2)
