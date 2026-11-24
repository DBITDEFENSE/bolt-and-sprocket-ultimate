extends Node
## T-273: Totenhafen's round 1 opening, "the night shift runs" (InnOpening with data/gravelight/map02_opening.json).
## The map is dropped in directly (round 1 as the launcher starts it), a god-mode player at the spawn:
##   1. the opening found its file by the map's id and is not cancelled; its three patrons stand in the cannery by the
##      side door; the side door's leaf is shut and barred; its doorway is filled with a collider
##   2. before round 1 the night shift is heard through the door (an intro line), the cue plays, round 1 starts no
##      sooner than look.min_seconds after the map appeared, and the opening goes RUNNING with four of round 1's
##      slots (two risers, two attackers) taken off its queue
##   3. the door is unbarred and opened, the patrons come out onto the quay, Tews gets away down the sea stairs,
##      Boldt and Rahn are caught, fall and rise as zombies on the quay
##   4. while the door stands open a player pushed into the doorway from the quay never gets into the cannery (the
##      1000 door is never skipped); the leaf swings shut afterwards
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map02_opening.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const TIMEOUT: float = 120.0

var _map: MapRoot
var _t: float = 0.0
var _fails: PackedStringArray = []
var _lines: Array = []
var _op: InnOpening = null
var _door: InnFrontDoor = null
var _round1_at: float = -1.0
var _checked_start: bool = false
var _pushed: bool = false
var _push_t: float = 0.0
var _push_min_x: float = INF
var _opened_seen: bool = false
var _queue0: int = -1


func _ready() -> void:
	ProfileSave.path = "user://_qa_m2_opening_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m2_opening_settings.cfg"
	GameState.bot_count = 0
	GameState.god_mode = true
	Campaign.reset()
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(id: StringName, sp: StringName, _tx: String, _d: float) -> void:
		_lines.append([String(id), String(sp), _t]))
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		if r == 1 and _round1_at < 0.0:
			_round1_at = _t)


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	GameState.god_mode = true
	if _t > TIMEOUT:
		_fail("timed out (opening phase %s, round %d)" % [str(_op.phase) if _op != null else "?", RoundManager.current_round])
		_end()
		return
	if _op == null:
		if _t < 0.5:
			return
		_op = _map.find_child("InnOpening", true, false) as InnOpening
		_door = _map.find_child("CannerySideDoor", true, false) as InnFrontDoor
		_check(_op != null and _op.data_path == "" and str(_op.cfg.get("map", "")) == "map02_totenhafen", "the opening found map02_opening.json by the map's id")
		_check(_op != null and _op.phase == InnOpening.Phase.IDLE and _op.patrons.size() == 3, "it is waiting for round 1 with its three patrons")
		_check(_door != null and _door.barred and not _door.is_open, "the side door is shut and barred")
		var blk: Node = _map.find_child("CannerySideDoorBlock", true, false)
		_check(blk is StaticBody3D and ((blk as StaticBody3D).collision_layer & 1) != 0, "its doorway is filled with a collider")
		if _op != null:
			for pb: PatronBody in _op.patrons.values():
				_check(pb.visible and pb.global_position.x < -0.2 and String(ZoneVolume.zone_at(get_tree(), pb.global_position + Vector3.UP * 0.6)) == "B_CANNERY",
					"%s waits in the cannery (%s)" % [pb.patron_id, str(pb.global_position.snapped(Vector3.ONE * 0.1))])
		if _op == null:
			_end()
		return
	if _op.phase == InnOpening.Phase.RUNNING and not _checked_start:
		_checked_start = true
		var heard: bool = false
		var cue: bool = false
		for l: Array in _lines:
			heard = heard or str(l[0]).ends_with("_M2_OPEN_INTRO_01")
			cue = cue or str(l[0]) == "RAH_M2_OPEN_CUE_01"
		_check(heard, "the night shift was heard through the door before round 1 (%s)" % str(_lines.map(func(l: Array) -> String: return str(l[0]))))
		_check(cue and _op.cued, "the cue played")
		_check(_round1_at >= float((_op.cfg["look"] as Dictionary)["min_seconds"]), "round 1 started %.1f s in (not before look.min_seconds)" % _round1_at)
		_check(_op.riser_specs.size() == 2 and _op.attacker_specs.size() == 2, "two risers' and two attackers' slots taken from round 1 (%d, %d)" % [_op.riser_specs.size(), _op.attacker_specs.size()])
	if _op.phase == InnOpening.Phase.RUNNING and _door != null and _door.is_open:
		_opened_seen = true
		if not _pushed:
			# a player pushes into the open doorway from the quay for two seconds
			_pushed = true
			_map.player.global_position = Vector3(1.2, 0.05, 2.6 + 0.6)
		if _push_t < 2.0:
			_push_t += delta
			_map.player.move_and_collide(Vector3(-4.0 * delta, 0.0, 0.0))   # the body pushed west into the doorway
			_push_min_x = minf(_push_min_x, _map.player.global_position.x)
	if _op.phase == InnOpening.Phase.DONE or (_op.phase == InnOpening.Phase.RUNNING and _op.t > 30.0 and _op.risen.size() >= 2):
		_check(_opened_seen and not _door.barred, "the door was unbarred and opened")
		_check(_pushed and _push_min_x > 0.1, "a player pushed into the open doorway never got into the cannery (the furthest west %.2f)" % _push_min_x)
		_check(str(_op.fates.get("tews", "")) == "escaped", "Tews got away (%s)" % str(_op.fates))
		for id: String in ["boldt", "rahn"]:
			var z: Zombie = _op.risen.get(id) as Zombie
			_check(str(_op.fates.get(id, "")) == "risen" and z != null and is_instance_valid(z), "%s fell and rose (%s)" % [id, str(_op.fates.get(id, ""))])
			if z != null and is_instance_valid(z):
				_check(String(ZoneVolume.zone_at(get_tree(), z.global_position + Vector3.UP * 0.6)) == "A_QUAY", "%s rose on the quay" % id)
		_check(_op.attackers.size() == 2, "both attackers rose (%d)" % _op.attackers.size())
		_check(not _door.is_open or _op.t < float((_op.cfg["front_door"] as Dictionary)["close_at"]) + 1.0, "the leaf swung shut behind them")
		_end()


func _check(cond: bool, what: String) -> void:
	print("[m2open] %-4s %s" % ["ok" if cond else "FAIL", what])
	if not cond:
		_fails.append(what)


func _fail(s: String) -> void:
	_fails.append(s)
	print("[m2open] FAIL ", s)


func _end() -> void:
	print("[m2open] RESULT %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	set_physics_process(false)
	get_tree().quit(0 if _fails.is_empty() else 1)
