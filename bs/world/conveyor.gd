class_name ConveyorBelt
extends StaticBody3D
## A conveyor belt (addConveyor): a world-layer slab whose top surface carries whatever stands on it.
## - Bolt rides it through get_platform_delta() (Bolt._move adds the ground collider's frame delta).
## - CharacterBody3D enemies (move_and_slide) and rigid bodies ride it through constant_linear_velocity,
##   which Godot applies as floor / contact velocity.
## A belt-reverser lever (a MalletSwitch) calls reverse_for(seconds): the chevrons flash during the last
## warn_time seconds before it flips back (BS_LEVELS §2.5: 8 s with a 1 s warning).

var size: Vector3 = Vector3(12, 0.5, 3)
var dir: Vector3 = Vector3(-1, 0, 0)       # default carry direction (horizontal, normalised)
var speed: float = 3.2
var warn_time: float = 1.0
var belt_color: Variant = "#2c3242"
var _rev_t: float = 0.0
var _delta: Vector3 = Vector3.ZERO
var _scroll: float = 0.0
var _chev: Array[MeshInstance3D] = []
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"conveyors")
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, size, belt_color, false)
	# chevron stripes across the belt (visual only)
	var along_x: bool = absf(dir.x) > absf(dir.z)
	var length: float = size.x if along_x else size.z
	var width: float = size.z if along_x else size.x
	var n: int = maxi(2, int(length / 2.0))
	for i: int in n:
		var s: Vector3 = Vector3(0.5, 0.02, width * 0.8) if along_x else Vector3(width * 0.8, 0.02, 0.5)
		var m: MeshInstance3D = LevelKit.box(self, Vector3.ZERO, s, "#ffd23e", false, Vector3.ZERO, 1, 0.6) as MeshInstance3D
		_chev.append(m)
	_update_chevrons()


## Top of the belt surface in world space.
func top_y() -> float:
	return global_position.y + size.y * 0.5


func reversed() -> bool:
	return _rev_t > 0.0


func current_velocity() -> Vector3:
	return dir * speed * (-1.0 if _rev_t > 0.0 else 1.0)


func reverse_for(seconds: float) -> void:
	_rev_t = seconds


func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	_rev_t = maxf(0.0, _rev_t - delta)
	var v: Vector3 = current_velocity()
	constant_linear_velocity = v
	_delta = v * delta
	_scroll += (speed * (-1.0 if _rev_t > 0.0 else 1.0)) * delta
	_t += delta
	_update_chevrons()


func _update_chevrons() -> void:
	if _chev.is_empty():
		return
	var along_x: bool = absf(dir.x) > absf(dir.z)
	var length: float = size.x if along_x else size.z
	var axis: Vector3 = dir
	var spacing: float = length / float(_chev.size())
	var warn: bool = _rev_t > 0.0 and _rev_t < warn_time
	for i: int in _chev.size():
		var off: float = fposmod(float(i) * spacing + _scroll, length) - length * 0.5
		_chev[i].position = axis * off + Vector3(0, size.y * 0.5 + 0.01, 0)
		_chev[i].visible = not warn or fmod(_t, 0.2) < 0.1
