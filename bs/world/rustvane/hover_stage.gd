class_name HoverStage
extends AnimatableBody3D
## The Content Creator's hover-gimbal stage over the Sunset Stage's north infinity edge (BS_LEVELS §3.10).
## Modes (the arena's phase geometry; the director sets them from the boss's HP, and the boss may too):
##   &"low"    "Unboxing": hangs `low_h` (4 m) over the deck at the centre of the north edge
##   &"drift"  "Collab": drifts along the north edge between HoverPath_W and HoverPath_E
##   &"high"   "Going live": rises to `high_h` (8 m); its ring light sweeps the deck
##   &"parked" after the fight: settles at deck height on the edge (the demonetized Creator stays on it)
## The boss stands on it or follows its "Mount" child (Marker3D on the stage top). Bolt can land on it
## (get_platform_delta), which is how the cabana roofs and the masts matter in the last phase.

var deck_y: float = 8.4
var low_h: float = 4.0
var high_h: float = 8.0
var edge_center: Vector3 = Vector3.ZERO     # north edge centre at deck height
var drift_half: float = 9.0
var drift_speed: float = 0.35
var move_speed: float = 3.0
var size: Vector3 = Vector3(6, 0.5, 4)
var mode: StringName = &"low"
var _t: float = 0.0
var _delta: Vector3 = Vector3.ZERO
var _light: MeshInstance3D


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"hover_stages")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, size, "#c06aff", false, Vector3.ZERO, 1, 0.25)
	LevelKit.box(self, Vector3(0, size.y * 0.5 + 0.03, 0), Vector3(size.x * 0.9, 0.06, size.z * 0.9), "#2c2238", false)
	# gimbal rotors under each corner
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			LevelKit.cylinder(self, Vector3(sx * size.x * 0.42, -0.45, sz * size.z * 0.4), 0.55, 0.12, "#39404f")
			LevelKit.cylinder(self, Vector3(sx * size.x * 0.42, -0.3, sz * size.z * 0.4), 0.12, 0.3, "#8a95a8")
	# ring light halo on a back post
	LevelKit.box(self, Vector3(0, 1.6, -size.z * 0.42), Vector3(0.18, 3.0, 0.18), "#8a95a8", false)
	_light = LevelKit.cylinder(self, Vector3(0, 3.3, -size.z * 0.42), 1.3, 0.16, "#fff4e0", false, "z", -1.0, 2.2) as MeshInstance3D
	var mount: Marker3D = Marker3D.new()
	mount.name = "Mount"
	mount.position = Vector3(0, size.y * 0.5, 0)
	add_child(mount)
	global_position = target_pos()


func set_mode(m: StringName) -> void:
	mode = m


func target_pos() -> Vector3:
	match mode:
		&"drift":
			return edge_center + Vector3(sin(_t * drift_speed) * drift_half, low_h + 1.0, 0)
		&"high":
			return edge_center + Vector3(0, high_h, 0)
		&"parked":
			return edge_center + Vector3(0, 0.6, 0)
		_:
			return edge_center + Vector3(0, low_h, 0)


func height_above_deck() -> float:
	return global_position.y - deck_y


func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Vector3 = global_position.move_toward(target_pos(), move_speed * delta)
	_delta = p - global_position
	global_position = p
	if _light != null:
		_light.rotation_degrees.y = sin(_t * 0.9) * (35.0 if mode == &"high" else 8.0)
