class_name HOACompliance
extends Node
## The HOA violation system (BS_LEVELS §4.5, new in the remake). Watches Bolt for violations in front of
## Compliance Eyes and drives each district's walkway reversals:
##   violation kinds: "sprint" (grounded, faster than sprint_speed), "walkway_jump" (a jump taken off a
##   walkway), "jump" (any jump; only the clubhouse lawn eye cares), "fight" (a mallet swing or a hit landed
##   in the last fight_window seconds).
##   A violation is logged when an unblinded Eye that watches that kind sees Bolt. Per district:
##   IDLE -> FLASH (lamp posts and walkways blink red, `flash` 1.0 s) -> REVERSED (every walkway in the
##   district reverses, `reverse` 6 s) -> COOLDOWN (`cooldown` 8 s) -> IDLE. Violations logged outside IDLE
##   still count (and still run an eye's on_violation actions) but don't stack reversals.
## Anything can also call log_violation(district, kind) or force_reversal(district) (a boss, an enemy, tests).
## Tuning: the level data's "nova.hoa" table.

signal violation_logged(district: String, eye: ComplianceEye, kind: String)
signal reversal_started(district: String)
signal reversal_flash(district: String)

const IDLE: int = 0
const FLASH: int = 1
const REVERSED: int = 2
const COOLDOWN: int = 3

var tuning: Dictionary = {}
var director: Node = null                    # LevelDirector (runs eyes' on_violation actions); optional
var districts: Dictionary = {}               # id -> {"state", "t", "walkways": [], "lamps": [], "eyes": []}
var eyes: Array[ComplianceEye] = []
var history: Array[String] = []                # "district:kind" per logged violation (tests read it)
var reversals: Dictionary = {}               # district -> count
var _bolt: Node3D = null
var _fight_t: float = 0.0
var _eye_cd: Dictionary = {}                 # eye -> seconds before it may log again
var _hinted: bool = false


func T(key: String, fallback: float) -> float:
	return float(tuning.get(key, fallback))


func _district(id: String) -> Dictionary:
	if not districts.has(id):
		districts[id] = {"state": IDLE, "t": 0.0, "walkways": [], "lamps": [], "eyes": []}
	return districts[id]


func add_walkway(w: NovaWalkway) -> void:
	(_district(w.district)["walkways"] as Array).append(w)


func add_lamp(l: NovaLampPost) -> void:
	(_district(l.district)["lamps"] as Array).append(l)


func add_eye(e: ComplianceEye) -> void:
	eyes.append(e)
	(_district(e.district)["eyes"] as Array).append(e)


func state(district: String) -> int:
	return int((districts.get(district, {}) as Dictionary).get("state", IDLE))


func _ready() -> void:
	EventBus.enemy_hit.connect(_on_enemy_hit)


func _bind_bolt() -> void:
	var p: Node3D = LevelKit.player(get_tree())
	if p == _bolt:
		return
	_bolt = p
	if _bolt == null:
		return
	var m: Object = _bolt.get("motor")
	if m != null and m.has_signal("jumped"):
		m.connect("jumped", _on_jumped)
	var ml: Object = _bolt.get("melee")
	if ml != null and ml.has_signal("swung"):
		ml.connect("swung", func(_tag: String) -> void: _fight_t = T("fight_window", 0.6))


func _on_enemy_hit(_e: Node, hit: RefCounted, _killed: bool) -> void:
	var src: Variant = hit.get("source") if hit != null else null
	if src is Node and (src as Node).is_in_group(&"player"):
		_fight_t = T("fight_window", 0.6)


func _on_jumped(_kind: StringName) -> void:
	if _bolt == null:
		return
	var g: Variant = _bolt.get("ground_collider")
	var on_walk: bool = g is NovaWalkway
	if not on_walk:
		for n: Node in get_tree().get_nodes_in_group(&"nova_walkways"):
			if (n as NovaWalkway).contains_point(_bolt.global_position + Vector3(0, -0.9, 0)):
				on_walk = true
				break
	_check_eyes("walkway_jump" if on_walk else "jump")
	if on_walk:
		_check_eyes("jump")


## Bolt's state this frame, as the continuous kinds ("sprint", "fight").
func _continuous_kinds() -> PackedStringArray:
	var out: PackedStringArray = []
	if _bolt == null:
		return out
	var m: Object = _bolt.get("motor")
	if m != null and bool(m.get("on_ground")):
		var v: Vector3 = m.get("vel")
		if Vector2(v.x, v.z).length() > T("sprint_speed", 8.2):
			out.append("sprint")
	if _fight_t > 0.0:
		out.append("fight")
	return out


func _physics_process(delta: float) -> void:
	_bind_bolt()
	_fight_t = maxf(0.0, _fight_t - delta)
	for e: Variant in _eye_cd.keys():
		_eye_cd[e] = float(_eye_cd[e]) - delta
	for k: String in _continuous_kinds():
		_check_eyes(k)
	for id: String in districts.keys():
		_step_district(id, delta)


func _check_eyes(kind: String) -> void:
	if _bolt == null:
		return
	var at: Vector3 = _bolt.global_position
	for e: ComplianceEye in eyes:
		if not is_instance_valid(e) or not e.watches_kind(kind):
			continue
		if float(_eye_cd.get(e, 0.0)) > 0.0:
			continue
		if e.sees(at):
			_eye_cd[e] = T("eye_log_cd", 1.0)
			e.note_violation(kind)
			_run_eye_actions(e)
			log_violation(e.district, kind, e)


func _run_eye_actions(e: ComplianceEye) -> void:
	if e.on_violation.is_empty() or (e.once and e.log_count > 1):
		return
	if director != null and is_instance_valid(director) and director.has_method("run_actions"):
		director.call("run_actions", e.on_violation, e, _bolt)


## Logs a violation in a district. Returns true when it started a reversal (the district was idle).
func log_violation(district: String, kind: String, eye: ComplianceEye = null) -> bool:
	history.append("%s:%s" % [district, kind])
	violation_logged.emit(district, eye, kind)
	var d: Dictionary = _district(district)
	if int(d["state"]) != IDLE:
		return false
	if not _hinted:
		_hinted = true
		EventBus.hint.emit(LevelKit.text("bs.nova.hint_violation"), "nova_violation")
	EventBus.bark.emit("bs.nova.pa_violation_" + kind)
	return force_reversal(district)


## Starts the flash -> reverse cycle now (if the district is idle).
func force_reversal(district: String) -> bool:
	var d: Dictionary = _district(district)
	if int(d["state"]) != IDLE:
		return false
	d["state"] = FLASH
	d["t"] = T("flash", 1.0)
	for l: Variant in d["lamps"]:
		if is_instance_valid(l):
			(l as NovaLampPost).flash(T("flash", 1.0))
	for w: Variant in d["walkways"]:
		if is_instance_valid(w):
			(w as NovaWalkway).flash(T("flash", 1.0))
	reversal_flash.emit(district)
	return true


func _step_district(id: String, delta: float) -> void:
	var d: Dictionary = districts[id]
	if int(d["state"]) == IDLE:
		return
	d["t"] = float(d["t"]) - delta
	if float(d["t"]) > 0.0:
		return
	match int(d["state"]):
		FLASH:
			d["state"] = REVERSED
			d["t"] = T("reverse", 6.0)
			for w: Variant in d["walkways"]:
				if is_instance_valid(w):
					(w as NovaWalkway).reverse_for(T("reverse", 6.0))
			reversals[id] = int(reversals.get(id, 0)) + 1
			reversal_started.emit(id)
		REVERSED:
			d["state"] = COOLDOWN
			d["t"] = T("cooldown", 8.0)
		_:
			d["state"] = IDLE
			d["t"] = 0.0
