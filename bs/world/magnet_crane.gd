class_name MagnetCrane
extends AnimatableBody3D
## A magnet-crane platform (addMovingPlatform 'patrol' + craneTower): a 3.4 m magnet plate that swings
## between `base` and `end` at `speed` (k = (sin(t * speed) + 1) / 2, as updatePlatforms). Bolt rides it
## through get_platform_delta(); CharacterBody3D enemies ride it as a moving floor (AnimatableBody3D).
## The tower, boom and cable are decoration built beside the path.

var base: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var speed: float = 0.55
var size: Vector3 = Vector3(3.4, 0.4, 3.4)
var phase: float = 0.0
var tower_offset: Vector3 = Vector3(-6, 0, 0)    # tower foot relative to the path midpoint (deco)
var tower: bool = true                           # false for plain lifts and the crusher stamp
var plate_color: Variant = "#ffd23e"
var paused: float = 0.0                          # seconds left frozen (Thunder throw on the crusher box)
var _t: float = 0.0
var _delta: Vector3 = Vector3.ZERO
var _cable: MeshInstance3D


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"cranes")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, size, plate_color, false, Vector3.ZERO, 1, 0.5 if tower else 0.0)
	if tower:
		LevelKit.box(self, Vector3(0, size.y * 0.5 + 0.05, 0), Vector3(size.x * 0.7, 0.1, size.z * 0.7), "#232838", false)
	_t = phase
	global_position = _pos_at(_t)
	if tower:
		_build_tower.call_deferred()


func pause_for(seconds: float) -> void:
	paused = maxf(paused, seconds)


func _build_tower() -> void:
	var mid: Vector3 = (base + end) * 0.5
	var foot: Vector3 = Vector3(mid.x, 0, mid.z) + tower_offset
	var parent: Node = get_parent()
	var top: float = maxf(base.y, end.y) + 5.0
	LevelKit.box(parent, Vector3(foot.x, top * 0.5, foot.z), Vector3(1.2, top, 1.2), "#b0652e", false)
	var arm_to: Vector3 = Vector3(mid.x, top, mid.z)
	var arm_from: Vector3 = Vector3(foot.x, top, foot.z)
	var arm_len: float = arm_from.distance_to(arm_to)
	var arm: Node3D = LevelKit.box(parent, (arm_from + arm_to) * 0.5, Vector3(0.8, 0.8, maxf(0.8, arm_len)), "#b0652e", false)
	if arm_len > 0.1:
		arm.look_at_from_position((arm_from + arm_to) * 0.5, arm_to, Vector3.UP)
	_cable = LevelKit.box(parent, Vector3.ZERO, Vector3(0.08, 1.0, 0.08), "#39404f", false) as MeshInstance3D
	_cable.set_meta(&"top", top)


func _pos_at(t: float) -> Vector3:
	var k: float = (sin(t * speed) + 1.0) * 0.5
	return base.lerp(end, k)


func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	if paused > 0.0:
		paused -= delta
		_delta = Vector3.ZERO
		return
	_t += delta
	var p: Vector3 = _pos_at(_t)
	_delta = p - global_position
	global_position = p
	if _cable != null:
		var top: float = float(_cable.get_meta(&"top"))
		var h: float = maxf(0.1, top - p.y)
		_cable.scale = Vector3(1, h, 1)
		_cable.global_position = Vector3(p.x, p.y + h * 0.5, p.z)
