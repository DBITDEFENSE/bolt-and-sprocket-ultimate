extends Node3D
## The wreck's moving fire, made visible (UPDATE 09 §5.4, DECISIONS T-148). The GroomController owns the damage
## zone (map04c.json groom.fire: radius 4 m at one of its points, moving every `move_every` s with the wind);
## this node only shows it: its children (flames, smoke column, heat shimmer, a flickering light) glide to the
## visual spot that belongs to the live point (`points[i]` -> `visual[i]`: on the wing root's top, in the tear,
## on the bay floor) over `glide_s`. Nothing here touches gameplay; headless it just moves an empty node.

@export var points: PackedVector3Array = PackedVector3Array()
@export var visual: PackedVector3Array = PackedVector3Array()
@export var glide_s: float = 3.0

var _ctrl: Node = null
var _t: float = 0.0
var _target: Vector3 = Vector3.INF


func _ready() -> void:
	if not visual.is_empty():
		position = visual[0]


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_poll()
	if _target != Vector3.INF:
		position = position.lerp(_target, clampf(delta * 3.0 / maxf(glide_s, 0.1), 0.0, 1.0))


func _poll() -> void:
	if _ctrl == null or not is_instance_valid(_ctrl):
		var root: Node = get_parent()
		_ctrl = root.find_child("GroomController", true, false) if root != null else null
		if _ctrl == null:
			return
	if not _ctrl.has_method("fire_point"):
		return
	var fp: Vector3 = _ctrl.call("fire_point")
	if fp == Vector3.INF or points.is_empty():
		return
	var best: int = 0
	var bd: float = INF
	for i: int in points.size():
		var d: float = Vector2(points[i].x - fp.x, points[i].z - fp.z).length()
		if d < bd:
			bd = d
			best = i
	_target = visual[best] if best < visual.size() else fp
