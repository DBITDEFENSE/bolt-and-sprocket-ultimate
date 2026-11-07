class_name CinemaCamera
extends Camera3D
## T-184: the cutscene camera. Plays one CinemaShot at a time on its eased path (CinemaShot.sample), comes into a
## shot by a cut or a blend from where it was, keeps a `target` node or a `rel` node in frame while they move,
## breathes a little (hand-held drift: layered slow sines, a different seed per shot) and kicks on impacts
## (`impulse`: trauma that decays, squared, at a higher frequency). Both scale with the player's Screen Shake setting
## (0 = a locked-off camera). Depth of field rides on CameraAttributesPractical where the renderer has it
## (Forward+, not the Compatibility / browser renderer, not the low preset); the colour grade is CinemaOverlay's.
## `advance(dt)` is the whole update, so the tests (and a fast-forwarded cutscene) can drive it by hand.

const HANDHELD_DEG: float = 0.55        # rotation drift at handheld 1.0
const HANDHELD_M: float = 0.035         # position drift at handheld 1.0
const SHAKE_DEG: float = 2.6            # rotation at trauma 1.0
const SHAKE_DECAY: float = 1.5          # trauma per second

var shot: CinemaShot = null
var shot_t: float = 0.0
var trauma: float = 0.0
var resolve: Callable = Callable()      # (name: String) -> Node3D, the director's node lookup
var dof_allowed: bool = true
var _blend_from: Transform3D = Transform3D.IDENTITY
var _blend_fov: float = 60.0
var _blend_s: float = 0.0
var _seed: float = 0.0
var _clock: float = 0.0
var _attr: CameraAttributesPractical = null
var _last_xf: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	far = maxf(far, 500.0)
	dof_allowed = dof_allowed and not GLSettings.is_compat() and str(GLSettings.values.get("graphics_preset", "high")) not in ["low", "web"] and DisplayServer.get_name() != "headless"


## Starts a shot. A "blend" (or "dip", whose black the overlay draws) eases from the current frame into the new path
## over the shot's `blend` seconds; a "cut" jumps.
func play(s: CinemaShot) -> void:
	var had: bool = shot != null
	_blend_from = global_transform if had else Transform3D.IDENTITY
	_blend_fov = fov
	_blend_s = s.blend if had and s.cut == "blend" else 0.0
	shot = s
	shot_t = 0.0
	_seed = fmod(s.t * 7.31 + 0.37, 97.0)
	_apply_dof(s)
	advance(0.0)


func impulse(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)


func _shake_scale() -> float:
	return clampf(float(GLSettings.values.get("screen_shake", 1.0)), 0.0, 1.5)


## Hand-held drift, pure: radians (pitch, yaw, roll) and metres for `amount` at clock `c` with seed `sd`.
static func drift(c: float, sd: float, amount: float) -> Dictionary:
	var p: float = sin(c * 0.73 + sd) * 0.6 + sin(c * 1.37 + sd * 2.1) * 0.3 + sin(c * 2.9 + sd * 0.7) * 0.1
	var y: float = sin(c * 0.51 + sd * 1.7) * 0.6 + sin(c * 1.13 + sd * 0.3) * 0.3 + sin(c * 3.1 + sd) * 0.1
	var r: float = sin(c * 0.41 + sd * 0.9) * 0.7 + sin(c * 1.7 + sd * 1.3) * 0.3
	var a: float = deg_to_rad(HANDHELD_DEG) * amount
	return {"rot": Vector3(p * a, y * a, r * a * 0.6), "pos": Vector3(y, p, 0.0) * HANDHELD_M * amount}


## Impact shake, pure: radians for trauma `tr` at clock `c` (squared, so a small kick stays small).
static func shake_rot(c: float, tr: float) -> Vector3:
	var a: float = deg_to_rad(SHAKE_DEG) * tr * tr
	return Vector3(sin(c * 37.0) * 0.6 + sin(c * 23.0) * 0.4, sin(c * 31.0 + 1.3) * 0.6 + sin(c * 19.0) * 0.4, sin(c * 27.0 + 0.4) * 0.5) * a


func advance(dt: float) -> void:
	if shot == null:
		return
	shot_t += dt
	_clock += dt
	trauma = maxf(0.0, trauma - SHAKE_DECAY * dt)
	var origin: Vector3 = Vector3.ZERO
	if shot.rel != "" and resolve.is_valid():
		var rn: Node3D = resolve.call(shot.rel) as Node3D
		if rn != null and rn.is_inside_tree():
			origin = rn.global_position
	var tp: Variant = null
	if shot.target != "" and resolve.is_valid():
		var tn: Node3D = resolve.call(shot.target) as Node3D
		if tn != null and tn.is_inside_tree():
			tp = tn.global_position
	var s: Dictionary = shot.sample(shot_t, origin, tp)
	var pos: Vector3 = s["pos"]
	var lk: Vector3 = s["look"]
	var xf: Transform3D = Transform3D(Basis(), pos).looking_at(lk, up_for(pos, lk)) if pos.distance_squared_to(lk) > 0.0001 else Transform3D(Basis(), pos)
	xf.basis = xf.basis * Basis(Vector3.BACK, deg_to_rad(float(s["roll"])))
	var f: float = float(s["fov"])
	if _blend_s > 0.0 and shot_t < _blend_s:
		var b: float = CinemaEase.apply("smooth", shot_t / _blend_s)
		xf = _blend_from.interpolate_with(xf, b)
		f = lerpf(_blend_fov, f, b)
	var sk: float = _shake_scale()
	var d: Dictionary = drift(_clock, _seed, shot.handheld * minf(1.0, sk))
	var rot: Vector3 = (d["rot"] as Vector3) + shake_rot(_clock, trauma) * sk
	xf.basis = xf.basis * Basis.from_euler(rot)
	xf.origin += xf.basis * (d["pos"] as Vector3)
	_last_xf = xf
	if is_inside_tree():
		global_transform = xf
	else:
		transform = xf
	fov = clampf(f, 10.0, 120.0)
	if _attr != null and shot.focus < 0.0:
		_attr.dof_blur_far_distance = maxf(1.0, pos.distance_to(lk) + 2.5)


## The frame the camera holds now (for tests and the director's checks).
func frame() -> Transform3D:
	return _last_xf


func _apply_dof(s: CinemaShot) -> void:
	if not dof_allowed or s.blur <= 0.0:
		attributes = null
		_attr = null
		return
	if _attr == null:
		_attr = CameraAttributesPractical.new()
	var dist: float = s.focus if s.focus > 0.0 else maxf(1.0, s.from.distance_to(s.look))
	_attr.dof_blur_far_enabled = true
	_attr.dof_blur_far_distance = dist + 2.5
	_attr.dof_blur_far_transition = maxf(2.0, dist * 0.8)
	_attr.dof_blur_near_enabled = dist > 3.0
	_attr.dof_blur_near_distance = maxf(0.3, dist * 0.35)
	_attr.dof_blur_near_transition = maxf(0.3, dist * 0.25)
	_attr.dof_blur_amount = 0.04 + 0.12 * s.blur
	attributes = _attr


## A shot looking straight up or down (the rocket's climb) has no usable world-up; use north as up then.
static func up_for(eye: Vector3, target: Vector3) -> Vector3:
	var d: Vector3 = target - eye
	if d.length_squared() < 0.0001 or absf(d.normalized().dot(Vector3.UP)) > 0.999:
		return Vector3.FORWARD
	return Vector3.UP
