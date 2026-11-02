class_name SunGate
extends DirectionalLight3D
## Mondlicht's Sun (U09 s5, T-149; presentation/perf only, moon_switch.gd's idea): the domes are roofed and shelled,
## so inside them the Sun lights nothing and only costs its shadow cascades (which drew every interior caster again,
## the bulk of the census's growth). While the active camera stands inside a dome and farther than `door_radius`
## from every yard airlock, the Sun is switched off; in the yard, at the airlocks, and above `below_y`'s floor it is on.

@export var below_y: float = -2.5
@export var indoor_rects: Array = []                     # [x0, x1, z0, z1] per dome
@export var door_points: PackedVector3Array = PackedVector3Array()
@export var door_radius: float = 9.0

var _t: float = 0.0


## True when the Sun should be on for a camera at `p`.
static func lit_at(p: Vector3, rects: Array, doors: PackedVector3Array, radius: float, floor_y: float = -2.5) -> bool:
	if p.y < floor_y:
		return false
	var inside: bool = false
	for r: Array in rects:
		if p.x >= float(r[0]) and p.x <= float(r[1]) and p.z >= float(r[2]) and p.z <= float(r[3]):
			inside = true
			break
	if not inside:
		return true
	for d: Vector3 in doors:
		if Vector2(p.x - d.x, p.z - d.z).length() <= radius:
			return true
	return false


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var want: bool = lit_at(cam.global_position, indoor_rects, door_points, door_radius, below_y)
	if visible != want:
		visible = want
