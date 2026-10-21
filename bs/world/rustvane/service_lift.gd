class_name ServiceLift
extends AnimatableBody3D
## The Back of House freight cage (BS_LEVELS §3.2 step 2, §3.4): a staff lift bolted to the canyon wall that
## rises from `bottom` to `top` (18 m, to the Strip Mine rim) and back, pausing `dwell` s at each end. It is
## parked at the bottom, gate lamp red, until enable() (the staff badge from the time clock). Bolt rides it
## through get_platform_delta() like the Scrapheap cranes.

var bottom: Vector3 = Vector3.ZERO
var top: Vector3 = Vector3(0, 18, 0)
var speed: float = 3.0
var dwell: float = 1.6
var size: Vector3 = Vector3(3.2, 0.4, 3.2)
var enabled: bool = false
var trips: int = 0
var _going_up: bool = true
var _wait: float = 0.0
var _delta: Vector3 = Vector3.ZERO
var _lamp: MeshInstance3D


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"lifts")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, size, "#5a6377", false)
	LevelKit.box(self, Vector3(0, size.y * 0.5 + 0.02, 0), Vector3(size.x * 0.8, 0.04, size.z * 0.8), "#ffd23e", false, Vector3.ZERO, 1, 0.3)
	# cage: four posts, a top frame and a back mesh panel
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			LevelKit.box(self, Vector3(sx * size.x * 0.47, 1.3, sz * size.z * 0.47), Vector3(0.12, 2.6, 0.12), "#39404f", false)
	LevelKit.box(self, Vector3(0, 2.6, 0), Vector3(size.x, 0.12, size.z), "#39404f", false)
	_lamp = LevelKit.box(self, Vector3(size.x * 0.47, 2.8, size.z * 0.47), Vector3(0.3, 0.3, 0.3), "#d42f2f", false, Vector3.ZERO, 1, 1.4) as MeshInstance3D
	global_position = bottom


func enable(on: bool = true) -> void:
	enabled = on
	if _lamp != null:
		_lamp.material_override = LevelKit.mat("#3ee66a" if on else "#d42f2f", 1.4)


func get_platform_delta() -> Vector3:
	return _delta


func at_top() -> bool:
	return global_position.distance_to(top) < 0.05


func _physics_process(delta: float) -> void:
	_delta = Vector3.ZERO
	if not enabled:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var goal: Vector3 = top if _going_up else bottom
	var p: Vector3 = global_position.move_toward(goal, speed * delta)
	_delta = p - global_position
	global_position = p
	if p.distance_to(goal) < 0.001:
		_going_up = not _going_up
		_wait = dwell
		trips += 1
