class_name CraneTrap
extends Node3D
## The Crane Drop (UPDATE 10 contract C2, DECISIONS T-153; traps.json crane_drop, map02.json "crane_drop"): a lever in
## Totenhafen's crane office swings the loading crane's hook out over the east apron and drops a pallet of crates:
## everything in the kill box (box_size, 6 x 4 m, centred on this node) dies, a crash and a dust burst; the debris
## lies there `debris_seconds`, then the hook winches the next pallet up. Cooldown from traps.json (60 s). The
## TrapLever contract: trap_name / cost / can_activate / status_text / activate. Bots keep out (danger_contains).

const KEY: String = "crane_drop"

var cooldown_left: float = 0.0
var drops: int = 0
var kills_last: int = 0

var _cfg: Dictionary = {}
var _phase: int = 0   # 0 idle, 1 swinging, 2 falling, 3 debris
var _t: float = 0.0
var _by: int = 0
var _pallet: Node3D
var _debris: Node3D
var _box: Vector2 = Vector2(6.0, 4.0)


func _ready() -> void:
	add_to_group(&"traps")
	_cfg = GLData.load_json("res://data/gravelight/map02.json").get("crane_drop", {})
	var bs: Array = _cfg.get("box_size", [6.0, 4.0])
	_box = Vector2(float(bs[0]), float(bs[1]))
	_pallet = Node3D.new()
	_pallet.name = "Pallet"
	add_child(_pallet)
	var wood: StandardMaterial3D = Interactable.greybox_mat(Color(0.42, 0.3, 0.18))
	var crate: StandardMaterial3D = Interactable.greybox_mat(Color(0.5, 0.38, 0.22))
	Interactable.add_box(_pallet, Vector3(_box.x * 0.8, 0.2, _box.y * 0.8), Vector3.ZERO, wood)
	for i: int in 6:
		var cx: float = (float(i % 3) - 1.0) * _box.x * 0.26
		var cz: float = (float(i / 3) - 0.5) * _box.y * 0.38
		Interactable.add_box(_pallet, Vector3(1.2, 1.0, 1.1), Vector3(cx, 0.6 + 0.4 * float(i % 2), cz), crate)
	_debris = Node3D.new()
	_debris.name = "Debris"
	add_child(_debris)
	for i: int in 9:
		var a: float = float(i) * 2.1
		var piece: MeshInstance3D = Interactable.add_box(_debris, Vector3(1.0, 0.25, 0.7), Vector3(cos(a) * float(i % 4) * 0.7, 0.12, sin(a) * float(i % 3) * 0.6), crate)
		piece.rotation = Vector3(0.2 * float(i % 3), a, 0.15 * float(i % 2))
	_reset_pallet()


func _reset_pallet() -> void:
	_pallet.visible = true
	_pallet.position = Vector3(0, float(_cfg.get("hang_height", 9.0)), -_box.y * 2.5)
	_debris.visible = false
	_phase = 0


func trap_name() -> String:
	return "Crane Drop"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY).get("cost", 1000))


## Pure (tested): may it fire? Not while running or cooling down.
static func can_fire(phase: int, cooldown: float) -> bool:
	return phase == 0 and cooldown <= 0.0


## Pure (tested): is `p` inside the kill box centred at `c` (box = x by z metres; y within 3 m)?
static func in_box(p: Vector3, c: Vector3, box: Vector2) -> bool:
	return absf(p.x - c.x) <= box.x * 0.5 and absf(p.z - c.z) <= box.y * 0.5 and absf(p.y - c.y) < 3.0


func can_activate() -> bool:
	return can_fire(_phase, cooldown_left)


func status_text() -> String:
	if _phase != 0:
		return "The crane is busy"
	return "The crane is winching the next pallet up (%d s)" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	_by = by_player
	_phase = 1
	_t = 0.0
	AudioDirector.play_3d("lift_winch", global_position + Vector3.UP * 8.0, 4.0, 0.0)
	return true


func _physics_process(delta: float) -> void:
	if _phase == 0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		return
	_t += delta
	var hang: float = float(_cfg.get("hang_height", 9.0))
	match _phase:
		1:
			var swing: float = float(_cfg.get("swing_seconds", 2.2))
			var k: float = clampf(_t / swing, 0.0, 1.0)
			_pallet.position = Vector3(sin(k * PI) * 0.6, hang, lerpf(-_box.y * 2.5, 0.0, k * k * (3.0 - 2.0 * k)))
			_pallet.rotation.y = sin(k * TAU) * 0.15
			if k >= 1.0:
				_phase = 2
				_t = 0.0
				AudioDirector.play_3d("board_break", global_position + Vector3.UP * hang, 4.0, 0.0)
		2:
			var fall: float = float(_cfg.get("fall_seconds", 0.7))
			var k2: float = clampf(_t / fall, 0.0, 1.0)
			_pallet.position.y = hang * (1.0 - k2 * k2)
			if k2 >= 1.0:
				_impact()
		3:
			if _t >= float(_cfg.get("debris_seconds", 20.0)):
				_reset_pallet()


func _impact() -> void:
	_phase = 3
	_t = 0.0
	drops += 1
	kills_last = 0
	_pallet.visible = false
	_debris.visible = true
	AudioDirector.play_3d("crane_crash", global_position + Vector3.UP, 6.0, 0.0)
	AudioDirector.play_3d("chandelier_crash", global_position + Vector3.UP, 0.0, 0.1)
	Effects.explosion(global_position + Vector3.UP * 0.5, maxf(_box.x, _box.y) * 0.5)
	GLBus.crane_drop.emit(global_position)
	var c: Dictionary = TrapLever.cfg_for(KEY)
	cooldown_left = TrapLever.cooldown_for(KEY)
	if not Net.is_authority():
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if in_box(z.global_position, global_position, _box):
				TrapLever.trap_kill(z, float(c.get("zombie_damage", 999999)), KEY, _by)
				kills_last += 1
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and in_box(p.global_position, global_position, _box):
			p.take_hit(float(c.get("player_damage", 9999)), self)
	GLBus.explosion.emit(global_position, 6.0)
	if kills_last >= 3:
		GLVO.play_category(&"OPR", "CRANE_DROP", 0.6)


## Bots keep out while the pallet is in the air over the box (a metre of margin).
func danger_contains(p: Vector3) -> bool:
	if _phase != 1 and _phase != 2:
		return false
	return in_box(p, global_position, _box + Vector2(2.0, 2.0))
