class_name NovaWalkway
extends StaticBody3D
## A Nova Plaza moving walkway (addWalkway / updateWalkways, BS_LEVELS §4.5): a 4 m strip whose top surface
## runs from `from` to `to` (flat or a ramp). Carry direction is from -> to.
## - Push (source): while Bolt stands on it, his velocity gets `force` m/s² along the arrows (10, as the web
##   build's addWalkway(…, 10)).
## - Carry (remake): the floor itself drifts at `carry` m/s through get_platform_delta(), the same contract the
##   conveyors and cranes use (Bolt._move adds the ground collider's frame delta). The source's push alone
##   only drifts a standing Bolt ~0.8 m/s against his ground friction, too little to read when it reverses.
## - HOA violation reversal: reverse_for(seconds) flips both for that long (6 s from a district violation);
##   flash(seconds) blinks the chevrons red first. set_stopped(true) halts it (the Doomscroll phase).
##
## Contract for enemies and bosses (HOA Enforcer VIOLATION, The Algorithm): group "nova_walkways";
## reverse() (default 6 s), reverse_for(seconds), contains_point(p) -> bool, is_reversed(), set_stopped(on),
## `district` (String), `walkway_id` (String).

signal reversed_changed(walkway: NovaWalkway, on: bool)

var walkway_id: String = ""
var district: String = ""
var from: Vector3 = Vector3.ZERO          # top-surface start (parent space)
var to: Vector3 = Vector3(0, 0, -16)      # top-surface end (parent space)
var width: float = 4.0
var thickness: float = 0.3
var carry: float = 2.5
var force: float = 10.0
var reverse_default: float = 6.0
var stopped: bool = false
var visual_only: bool = false             # chevrons scroll, nothing is carried (the Doomscroll feed)
var strip_color: Variant = "#18324a"
var chevron_color: Variant = "#3ee6ff"
var reverse_color: Variant = "#ff3a6a"
var _rev_t: float = 0.0
var _flash_t: float = 0.0
var _delta: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.FORWARD       # world-space unit carry direction (along the surface)
var _len: float = 16.0
var _scroll: float = 0.0
var _chev: Array[Node3D] = []
var _t: float = 0.0
var _was_rev: bool = false
var _red_last: int = -1


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if not visual_only:
		add_to_group(&"nova_walkways")
		add_to_group(&"conveyors")
	var d: Vector3 = to - from
	_len = maxf(0.5, d.length())
	var b: Basis = Basis.looking_at(d.normalized(), Vector3.UP)
	transform = Transform3D(b, (from + to) * 0.5 - b.y * (thickness * 0.5))
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(width, thickness, _len)
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, Vector3(width, thickness, _len), strip_color, false, Vector3.ZERO, 1, 0.35)
	# side trims
	for sx: float in [-1.0, 1.0]:
		LevelKit.box(self, Vector3(sx * (width * 0.5 - 0.08), thickness * 0.5 + 0.02, 0), Vector3(0.16, 0.05, _len), "#3ee6ff", false, Vector3.ZERO, 1, 0.9)
	var n: int = maxi(2, int(_len / 2.0))
	for i: int in n:
		var c: Node3D = Node3D.new()
		add_child(c)
		for s: float in [-1.0, 1.0]:
			LevelKit.box(c, Vector3(s * width * 0.14, 0, 0.12), Vector3(width * 0.3, 0.04, 0.22), chevron_color, false, Vector3(0, s * 32.0, 0), 1, 1.2)
		_chev.append(c)
	_update_dir()
	_update_chevrons()


func _update_dir() -> void:
	_dir = -global_transform.basis.z.normalized() if is_inside_tree() else (to - from).normalized()


func is_reversed() -> bool:
	return _rev_t > 0.0


func sign_now() -> float:
	return -1.0 if _rev_t > 0.0 else 1.0


## World velocity of the surface (zero while stopped).
func current_velocity() -> Vector3:
	return Vector3.ZERO if stopped or visual_only else _dir * carry * sign_now()


func reverse() -> void:
	reverse_for(reverse_default)


func reverse_for(seconds: float) -> void:
	_rev_t = maxf(_rev_t, seconds)


func flash(seconds: float) -> void:
	_flash_t = maxf(_flash_t, seconds)


func set_stopped(on: bool) -> void:
	stopped = on


func length() -> float:
	return _len


## True when p (world) is over the strip (within its footprint and up to 3 m above the surface).
func contains_point(p: Vector3, margin: float = 0.3) -> bool:
	var l: Vector3 = global_transform.affine_inverse() * p
	return absf(l.x) <= width * 0.5 + margin and absf(l.z) <= _len * 0.5 + margin and l.y >= -0.6 and l.y <= 3.5


func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	_rev_t = maxf(0.0, _rev_t - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	_update_dir()
	var v: Vector3 = current_velocity()
	constant_linear_velocity = v
	_delta = v * delta
	if _was_rev != is_reversed():
		_was_rev = is_reversed()
		reversed_changed.emit(self, _was_rev)
	# the source push, on Bolt's velocity while he stands on this strip
	if not stopped and not visual_only and force > 0.0:
		var p: Node3D = LevelKit.player(get_tree())
		if p != null and p.get("ground_collider") == self and p.get("motor") != null:
			var m: Object = p.get("motor")
			if bool(m.get("on_ground")):
				var h: Vector3 = Vector3(_dir.x, 0, _dir.z).normalized() * force * sign_now() * delta
				m.set("vel", (m.get("vel") as Vector3) + h)


func _process(delta: float) -> void:
	_t += delta
	if not stopped:
		_scroll += carry * sign_now() * delta
	_update_chevrons()


func _update_chevrons() -> void:
	var spacing: float = _len / float(maxi(1, _chev.size()))
	var red: bool = _flash_t > 0.0 or is_reversed()
	var blink: bool = _flash_t > 0.0 and fmod(_t, 0.2) < 0.1
	var recolor: bool = int(red) != _red_last
	_red_last = int(red)
	for i: int in _chev.size():
		var off: float = fposmod(float(i) * spacing + _scroll, _len) - _len * 0.5
		var c: Node3D = _chev[i]
		# local -z is the carry direction; chevrons point the way the floor moves
		c.position = Vector3(0, thickness * 0.5 + 0.02, -off)
		c.rotation_degrees.y = 180.0 if is_reversed() else 0.0
		c.visible = not blink
		if not recolor:
			continue
		for k: Node in c.get_children():
			(k as MeshInstance3D).material_override = LevelKit.mat(reverse_color if red else chevron_color, 1.2)
