extends Node
## Headless smoke test for Map 1: per-zone navigation (with layer gating for closed doors), then a short
## round with a god-mode player in the yard to confirm zombies come through the windows and reach him.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_map01.tscn

const MAP: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "M": 6, "F": 7, "G": 8, "H": 9, "I": 10}

var _map: Node3D
var _t: float = 0.0
var _frames: int = 0
var _hits: int = 0
var _hist: Dictionary = {}
var _fails: PackedStringArray = []
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_p: int, _a: float) -> void: _hits += 1)


func _mask(zones: String) -> int:
	var m: int = 0
	for z: String in zones.split(","):
		m |= 1 << (int(BITS[z]) - 1)
	return m


func _path_check(label: String, from: Vector3, to: Vector3, zones: String, expect: bool) -> void:
	var rid: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, from, to, true, _mask(zones))
	var end_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.2
	var ok: bool = end_ok == expect
	print("[m1] %-52s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
	if not ok:
		_fails.append(label)


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree() or _done:
		return
	_frames += 1
	_t += delta
	if _frames == 40:
		var all: String = "A,B,C,D,E,M,F,G,H,I"
		_path_check("yard -> rail yard (all open)", Vector3(10, 0, 26), Vector3(50, 0, 44), all, true)
		_path_check("yard -> admin upper floor (radio room)", Vector3(10, 0, 26), Vector3(-8, 3.8, 12), all, true)
		_path_check("yard -> barracks via admin (B closed)", Vector3(10, 0, 26), Vector3(20, 0, 41), "A,C,D", true)
		_path_check("yard -> barracks via rail (C closed)", Vector3(10, 0, 26), Vector3(20, 0, 41), "A,B,D", true)
		_path_check("yard -> barracks with both doors closed", Vector3(10, 0, 26), Vector3(20, 0, 41), "A,D", false)
		_path_check("yard -> rail yard with B closed", Vector3(10, 0, 26), Vector3(50, 0, 44), "A,C,D", false)
		# T-107: the bot-mode soak's round-12 hang: crawlers at the Admin door with the way to the Generator Hall open
		_path_check("admin door -> generator hall (a_c, barracks, stairs, gen open)", Vector3(2.0, 0, 24.9), Vector3(39.0, DY(), 72.1), "A,C,D,M,F,G", true)
		_path_check("admin stair foot -> upstairs enters at the foot", Vector3(-11.8, 0, 27.4), Vector3(-8, 3.8, 12), "A,C", true)
		_path_check("barracks -> chapel via maintenance stairs", Vector3(-6, 0, 38), Vector3(12, DY(), 70), "D,M,F", true)
		_path_check("stairs top -> stairs bottom", Vector3(-10, 0, 47), Vector3(-10, DY(), 57), "D,M", true)
		_path_check("chapel -> generator", Vector3(12, DY(), 70), Vector3(62, DY(), 77), "F,G", true)
		_path_check("generator -> lab (lab closed)", Vector3(62, DY(), 77), Vector3(77, DY(), 90), "F,G", false)
		_path_check("generator -> lab", Vector3(62, DY(), 77), Vector3(77, DY(), 90), "F,G,H", true)
		_path_check("chapel -> core via crypt ramp", Vector3(12, DY(), 70), Vector3(34, CY(), 106), "F,I", true)
		_path_check("generator -> core via G ramp", Vector3(62, DY(), 77), Vector3(40, CY(), 124), "G,I", true)
		_path_check("lab -> core via H ramp", Vector3(77, DY(), 90), Vector3(40, CY(), 124), "H,I", true)
		_path_check("chapel -> core with core closed", Vector3(12, DY(), 70), Vector3(34, CY(), 106), "F,G,H", false)
		_path_check("lift bay -> chapel", Vector3(25, DY(), 57), Vector3(25, DY(), 70), "E,F", true)
		RoundManager.debug_set_round(1)
	if _t > 75.0:
		_done = true
		print("[m1] after 75s: round=%d alive=%d hits=%d states=%s" % [RoundManager.current_round, RoundManager.alive, _hits, _hist])
		if _hits == 0:
			_fails.append("no zombie reached the player in the yard")
		print("[m1] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
		get_tree().quit(0 if _fails.is_empty() else 1)
		return
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			var k: String = str(Zombie.State.keys()[z.state])
			_hist[k] = int(_hist.get(k, 0)) + 1


func DY() -> float:
	return -12.0


func CY() -> float:
	return -18.0
