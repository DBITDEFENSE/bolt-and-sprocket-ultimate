class_name AttackTokens
extends RefCounted
## Attack tokens for readability (BS_ENEMIES §2.3):
##   - melee: at most `max_melee` (2) enemies in TELEGRAPH/ATTACK against Bolt at once; others circle.
##   - ranged: at most `max_ranged` (3) enemy shots may *begin* in any `window` (1 s).
##   - bosses keep their own reserved token: they never ask.
##   - off-screen enemies only get a melee token while one slot stays free for on-screen ones.
## Game time comes from tick(), called by every enemy each physics frame (counted once per frame).

static var max_melee: int = 2
static var max_ranged: int = 3
static var window: float = 1.0
static var hold_max: float = 3.0
static var clock: float = 0.0
static var _frame: int = -1
static var _melee: Dictionary = {}     # instance id -> {"ref": WeakRef, "since": float}
static var _shots: Array[float] = []
static var _configured: bool = false


static func _configure() -> void:
	if _configured:
		return
	_configured = true
	var t: Variant = Data.table("bs/enemies")
	if t is Dictionary:
		var k: Dictionary = ((t as Dictionary).get("globals", {}) as Dictionary).get("tokens", {})
		max_melee = int(k.get("melee", max_melee))
		max_ranged = int(k.get("ranged_per_window", max_ranged))
		window = float(k.get("ranged_window", window))
		hold_max = float(k.get("melee_hold_max", hold_max))


static func tick(delta: float) -> void:
	var f: int = Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		clock += delta


static func reset() -> void:
	_melee.clear()
	_shots.clear()


static func _prune() -> void:
	for k: Variant in _melee.keys():
		var rec: Dictionary = _melee[k]
		var e: Object = (rec["ref"] as WeakRef).get_ref()
		if e == null or not is_instance_valid(e) or not bool(e.call("is_alive")) or not (e as Node).is_inside_tree():
			_melee.erase(k)
		elif clock - float(rec["since"]) > hold_max and not bool(e.call("is_attacking")):
			_melee.erase(k)        # held too long without committing: give it back


static func request_melee(e: Node, onscreen: bool = true) -> bool:
	_configure()
	_prune()
	var id: int = e.get_instance_id()
	if _melee.has(id):
		return true
	var n: int = _melee.size()
	if n >= max_melee:
		return false
	if not onscreen and n >= max_melee - 1:
		return false
	_melee[id] = {"ref": weakref(e), "since": clock}
	return true


static func holds_melee(e: Node) -> bool:
	return _melee.has(e.get_instance_id())


static func release_melee(e: Node) -> void:
	_melee.erase(e.get_instance_id())


static func melee_holders() -> int:
	_prune()
	return _melee.size()


static func request_ranged() -> bool:
	_configure()
	while not _shots.is_empty() and clock - _shots[0] >= window:
		_shots.pop_front()
	if _shots.size() >= max_ranged:
		return false
	_shots.append(clock)
	return true


static func ranged_in_window() -> int:
	while not _shots.is_empty() and clock - _shots[0] >= window:
		_shots.pop_front()
	return _shots.size()
