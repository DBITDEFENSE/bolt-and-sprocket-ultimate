class_name LevelGate
extends AnimatableBody3D
## A door, gate, lid or fence that slides between its closed position and closed + open_offset at
## `speed` m/s (addDoor; the heavy hull blast door, the Compaction Lot gates, the inspection-pit lid, the
## Teleporter Yard fence). World layer, so it blocks Bolt, enemies and the camera while shut.

signal opened(gate: LevelGate)
signal closed(gate: LevelGate)

var gate_id: String = ""
var size: Vector3 = Vector3(6, 4, 0.6)
var open_offset: Vector3 = Vector3(0, -4.2, 0)
var speed: float = 3.0
var start_open: bool = false
var gate_color: Variant = "#5a6377"
var is_open: bool = false
var _closed_pos: Vector3
var _target: Vector3


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"gates")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, size, gate_color, false)
	LevelKit.box(self, Vector3(0, size.y * 0.3, size.z * 0.5 + 0.01), Vector3(size.x * 0.9, 0.18, 0.02), "#ffd23e", false, Vector3.ZERO, 1, 0.4)
	_closed_pos = position
	is_open = start_open
	if start_open:
		position = _closed_pos + open_offset
	_target = position


func open(instant: bool = false) -> void:
	_target = _closed_pos + open_offset
	if instant:
		position = _target
	if not is_open:
		is_open = true
		opened.emit(self)


func close(instant: bool = false) -> void:
	_target = _closed_pos
	if instant:
		position = _target
	if is_open:
		is_open = false
		closed.emit(self)


## True once it has finished moving.
func settled() -> bool:
	return position.distance_to(_target) < 0.01


func _physics_process(delta: float) -> void:
	if position != _target:
		position = position.move_toward(_target, speed * delta)
