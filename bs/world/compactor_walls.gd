class_name CompactorWalls
extends Node3D
## The Compaction Lot's crushed-car side walls on rails (BS_LEVELS §2.10). Two world-layer walls (east and
## west) slide toward each other to `width` metres apart at `speed` m/s; cubes listed as riders move with
## their wall. The director narrows them per phase from data (36 -> 28 -> 22 m); REPO-TRON can also drive
## them directly through set_width() / push_back() (BS_ENEMIES §4.1 phase 3: 1 m every 10 s, min 14 m,
## a hit in the Compact recovery window pushes them back 2 m).

var center: Vector3 = Vector3.ZERO
var start_width: float = 36.0
var min_width: float = 14.0
var wall_size: Vector3 = Vector3(2.0, 4.0, 24.0)
var speed: float = 2.0
var width: float = 36.0            # current target width
var west: AnimatableBody3D
var east: AnimatableBody3D


func _ready() -> void:
	add_to_group(&"compactor_walls")
	width = start_width
	west = _wall(-1.0)
	east = _wall(1.0)


func _wall(side: float) -> AnimatableBody3D:
	var w: AnimatableBody3D = AnimatableBody3D.new()
	w.sync_to_physics = false
	w.collision_layer = 1
	w.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = wall_size
	cs.shape = sh
	w.add_child(cs)
	add_child(w)
	w.global_position = _wall_pos(side, start_width)
	# stacked crushed cars as the wall's face
	var cols: Array[String] = ["#b04a3a", "#4a7ab0", "#7ab04a", "#9a8a6a", "#b0652e"]
	var n: int = int(wall_size.z / 3.0)
	for i: int in n:
		for k: int in 2:
			var z: float = -wall_size.z * 0.5 + 1.5 + i * 3.0
			LevelKit.box(w, Vector3(0, -wall_size.y * 0.5 + 0.9 + k * 1.8, z), Vector3(wall_size.x, 1.7, 2.8), cols[(i + k * 2) % cols.size()], false)
	return w


func _wall_pos(side: float, w: float) -> Vector3:
	return center + Vector3(side * (w * 0.5 + wall_size.x * 0.5), wall_size.y * 0.5, 0)


## Attaches a node so it moves with one wall (side -1 west, +1 east).
func add_rider(n: Node3D, side: float) -> void:
	var w: AnimatableBody3D = west if side < 0.0 else east
	var gt: Transform3D = n.global_transform
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	w.add_child(n)
	n.global_transform = gt


func set_width(w: float) -> void:
	width = clampf(w, min_width, start_width)


func push_back(metres: float) -> void:
	set_width(width + metres * 2.0)


func step_in(metres: float) -> void:
	set_width(width - metres * 2.0)


## Current inner gap between the walls.
func current_width() -> float:
	return (east.global_position.x - west.global_position.x) - wall_size.x


func _physics_process(delta: float) -> void:
	for side: float in [-1.0, 1.0]:
		var wb: AnimatableBody3D = west if side < 0.0 else east
		var target: Vector3 = _wall_pos(side, width)
		wb.global_position = wb.global_position.move_toward(target, speed * delta)
