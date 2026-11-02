class_name TowerSway
extends Node3D
## A room that sways in the gusts (UPDATE 09 section 5, T-145: Totenhafen's signal tower): while the local player
## stands inside `size` (centred on this node, y from its origin up), a gust every `every_s` seconds gives the
## camera a faint shake for `gust_s` (Player._shake, scaled by the player's own shake setting like every other
## shake). Presentation only; never on puppets or bots.

@export var size: Vector3 = Vector3(10, 4, 5)
@export var every_s: Vector2 = Vector2(6.0, 14.0)
@export var gust_s: float = 2.2
@export var amount: float = 0.045

var _next: float = 4.0
var _left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func inside(p: Vector3) -> bool:
	var l: Vector3 = p - global_position
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 and l.y >= -0.3 and l.y <= size.y


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
	else:
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(every_s.x, every_s.y)
			_left = gust_s
	if _left <= 0.0:
		return
	var root: Node = get_tree().current_scene
	var p: Node3D = root.get("player") as Node3D if root != null else null
	if p == null or not bool(p.get("is_local")) or bool(p.get("is_bot")) or not inside(p.global_position):
		return
	var k: float = sin(PI * clampf(_left / gust_s, 0.0, 1.0))
	p.set("_shake", maxf(float(p.get("_shake")), amount * k))
