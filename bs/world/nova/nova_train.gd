class_name NovaTrain
extends AnimatableBody3D
## The Transit Loop monorail (BS_LEVELS §4.4): an empty driverless car on an elliptical elevated ring
## (centre `center` (x, z), semi-axes rx / rz, floor height `floor_y`). Ring parameter t: point =
## (cx + rx·sin t, floor_y, cz + rz·cos t); t = 0 is the south (hub) end, t = ±π the north (FineTree) end.
## Stations are named ring parameters. ride(from_station -> to_station, passenger) carries Bolt there along
## the shorter arc that `via` allows ("west" = negative t). Bolt rides it as a moving floor through
## get_platform_delta() (the delta of the point under him, so the car can turn under his feet); while he is
## airborne inside the car (boarding, a jump) the car carries him directly, like the air in a carriage.
## Signals: departed(station), arrived(station). `locked` is a Callable() -> bool the level sets (the two
## stamps); a locked car refuses to leave.

signal departed(station: String)
signal arrived(station: String)

var center: Vector2 = Vector2(0, -46)
var rx: float = 22.0
var rz: float = 36.0
var floor_y: float = 12.0
var speed: float = 9.0
var car_length: float = 9.0
var car_width: float = 3.0
var stations: Dictionary = {}               # id -> t
var station: String = ""                    # where it is parked ("" while moving)
var t: float = 0.0
var moving: bool = false
var passenger: Node3D = null
var rides: int = 0
var _goal_t: float = 0.0
var _dir: float = -1.0
var _goal: String = ""
var _delta: Vector3 = Vector3.ZERO
var _dwell: float = 0.0
var dwell_time: float = 0.5                 # seconds the doors stay open after boarding


static func point_at(c: Vector2, ax: float, az: float, y: float, tt: float) -> Vector3:
	return Vector3(c.x + ax * sin(tt), y, c.y + az * cos(tt))


static func tangent_at(ax: float, az: float, tt: float) -> Vector3:
	return Vector3(ax * cos(tt), 0, -az * sin(tt)).normalized()


func ring_point(tt: float) -> Vector3:
	return point_at(center, rx, rz, floor_y, tt)


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"nova_trains")
	_build_car()
	if station != "" and stations.has(station):
		t = float(stations[station])
	_place(t)


func _build_car() -> void:
	var hl: float = car_length * 0.5
	var hw: float = car_width * 0.5
	_solid(Vector3(0, -0.15, 0), Vector3(car_width, 0.3, car_length), "#d8dee9")
	# low side rails with a door gap in the middle of each side, end walls
	for sx: float in [-1.0, 1.0]:
		_solid(Vector3(sx * (hw - 0.08), 0.3, -hl * 0.6 - 0.05), Vector3(0.16, 0.6, car_length * 0.38), "#3a4658")
		_solid(Vector3(sx * (hw - 0.08), 0.3, hl * 0.6 + 0.05), Vector3(0.16, 0.6, car_length * 0.38), "#3a4658")
	for sz: float in [-1.0, 1.0]:
		_solid(Vector3(0, 0.6, sz * (hl - 0.1)), Vector3(car_width, 1.2, 0.2), "#3a4658")
	# roof on four posts, window band, nose lights (deco)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			LevelKit.box(self, Vector3(sx * (hw - 0.12), 1.4, sz * (hl - 0.3)), Vector3(0.14, 2.8, 0.14), "#5a6377", false)
	LevelKit.box(self, Vector3(0, 2.85, 0), Vector3(car_width + 0.3, 0.2, car_length + 0.2), "#232c4a", false)
	for sx: float in [-1.0, 1.0]:
		LevelKit.box(self, Vector3(sx * (hw + 0.15), 2.85, 0), Vector3(0.08, 0.24, car_length + 0.2), "#ff4d9d", false, Vector3.ZERO, 1, 1.2)
	LevelKit.box(self, Vector3(0, 2.6, 0), Vector3(car_width + 0.05, 0.25, car_length), "#9fecff", false, Vector3.ZERO, 1, 0.9)
	for sz: float in [-1.0, 1.0]:
		LevelKit.box(self, Vector3(0, 0.9, sz * (hl + 0.05)), Vector3(1.6, 0.25, 0.06), "#e8f4ff", false, Vector3.ZERO, 1, 2.2)
	# the beam shoe under the car
	LevelKit.box(self, Vector3(0, -0.7, 0), Vector3(1.2, 0.8, car_length * 0.8), "#39404f", false)
	var lbl: Label3D = NovaArt.neon_text(self, "bs.nova.train_sign", Vector3(hw + 0.02, 2.2, 0), 0.008, "#3ee6ff", 90.0)
	lbl.pixel_size = 0.008
	var lbl2: Label3D = NovaArt.neon_text(self, "bs.nova.train_sign", Vector3(-hw - 0.02, 2.2, 0), 0.008, "#3ee6ff", -90.0)
	lbl2.pixel_size = 0.008


func _solid(pos: Vector3, size: Vector3, c: Variant) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	add_child(cs)
	LevelKit.box(self, pos, size, c, false)


func _place(tt: float) -> void:
	var p: Vector3 = ring_point(tt)
	var f: Vector3 = tangent_at(rx, rz, tt)
	global_transform = Transform3D(Basis.looking_at(f, Vector3.UP), p)


## The floor point of the car where a passenger stands (world).
func deck_point() -> Vector3:
	return global_transform * Vector3(0, 0.05, 0)


## Starts a ride to `goal`. `via` = -1 runs toward negative t (west side), +1 toward positive t.
func ride(goal: String, rider: Node3D = null, via: float = 0.0) -> bool:
	if moving or not stations.has(goal) or goal == station:
		return false
	var gt: float = float(stations[goal])
	var d: float = gt - t
	if via != 0.0:
		_dir = signf(via)
		# go the requested way round: unwrap the goal to that side of t
		while _dir < 0.0 and gt > t:
			gt -= TAU
		while _dir > 0.0 and gt < t:
			gt += TAU
	else:
		d = wrapf(d, -PI, PI)
		gt = t + d
		_dir = signf(d)
	_goal_t = gt
	_goal = goal
	passenger = rider
	if passenger != null and is_instance_valid(passenger):
		passenger.global_position = deck_point() + Vector3(0, 1.0, 0)
		var m: Object = passenger.get("motor")
		if m != null:
			m.set("vel", Vector3.ZERO)
		if "last_safe" in passenger:
			passenger.set("last_safe", deck_point() + Vector3(0, 1.0, 0))
	departed.emit(station)
	station = ""
	moving = true
	_dwell = dwell_time
	rides += 1
	return true


## True when a car-local point is inside the car (between the rails, under the roof).
func inside_car(local: Vector3) -> bool:
	return absf(local.x) < car_width * 0.5 + 0.3 and absf(local.z) < car_length * 0.5 and local.y > -0.2 and local.y < 3.0


func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	_delta = Vector3.ZERO
	if not moving:
		return
	if _dwell > 0.0:
		_dwell -= delta
		return
	var old: Transform3D = global_transform
	var tan_len: float = Vector2(rx * cos(t), rz * sin(t)).length()
	var step: float = speed * delta / maxf(0.1, tan_len)
	var nt: float = t + _dir * step
	var done: bool = (_dir < 0.0 and nt <= _goal_t) or (_dir > 0.0 and nt >= _goal_t)
	if done:
		nt = _goal_t
	t = nt
	_place(t)
	var p: Node3D = LevelKit.player(get_tree())
	if p != null:
		var local: Vector3 = old.affine_inverse() * p.global_position
		_delta = global_transform * local - p.global_position
		if inside_car(local) and p.get("ground_collider") != self:
			p.global_position += _delta
	if done:
		t = wrapf(_goal_t, -PI, PI) if absf(_goal_t) > PI + 0.001 else _goal_t
		moving = false
		station = _goal
		arrived.emit(_goal)
