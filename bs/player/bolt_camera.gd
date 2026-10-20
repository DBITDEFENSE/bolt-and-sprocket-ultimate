class_name BoltCamera
extends Node3D
## Third-person camera, ported from the web build's updateCamera() (index.html:4221-4316) and mouse look
## (1116-1121). Rules kept from the original:
##   - yaw/pitch are written ONLY by player look input (plus the capped rotational aim assist and the lazy
##     auto-cam); movement never rotates the camera; no roll, ever
##   - smoothing applies to the follow point and the boom length, never to angles
##   - collision shortens the boom (fast pull-in, gentle recovery); the remake uses a sphere cast instead of
##     the original's point-in-box march (the brief's "SpringArm with no wall clipping")
## Add as a sibling of Bolt; set `target`.

var T: Dictionary
var target: Bolt
var cam: Camera3D
var yaw: float = 0.0
var pitch: float = 0.35
var dist: float = 6.2
var dist_cur: float = 6.2
var anchor: Vector3 = Vector3.ZERO
var lead: Vector3 = Vector3.ZERO
var punch: float = 0.0
var recoil_debt: float = 0.0
var look_idle_t: float = 0.0
var sprint_fov: float = 0.0
var _shake: float = 0.0
var _probe: SphereShape3D


func _ready() -> void:
	T = Data.table("bs/tuning")
	var L: Dictionary = T["look"]
	pitch = float(L["pitch_start"])
	dist = float(L["dist"])
	dist_cur = dist
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 500.0
	cam.fov = float(Settings.get_value("fov", 70))
	cam.current = true
	add_child(cam)
	_probe = SphereShape3D.new()
	_probe.radius = float(L["collide_pad"])
	if target != null:
		snap_to(target)


func snap_to(b: Bolt) -> void:
	target = b
	anchor = b.global_position + Vector3(0, float(T["look"]["anchor_height"]), 0)
	lead = Vector3.ZERO
	dist_cur = dist


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Melee finishers push the camera in briefly (camPunch).
func punch_in(amount: float) -> void:
	punch = maxf(punch, amount)


## Weapon recoil: kick the pitch now, spring it back over ~0.2 s so aim never drifts.
func add_recoil(rad: float) -> void:
	pitch = clampf(pitch + rad, float(T["look"]["pitch_min"]), float(T["look"]["pitch_max"]))
	recoil_debt += rad


## Camera forward (where the reticle points).
func view_dir() -> Vector3:
	return -cam.global_basis.z if cam != null else Vector3.FORWARD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not BS.blocked():
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var L: Dictionary = T["look"]
		var sens: float = float(Settings.get_value("mouseSens", 1.0)) * AimAssist.friction()
		if absf(mm.relative.x) + absf(mm.relative.y) > 1.0:
			look_idle_t = 0.0
		yaw -= mm.relative.x * float(L["mouse_yaw"]) * sens * (-1.0 if Settings.get_value("invertX", false) else 1.0)
		pitch = clampf(pitch + mm.relative.y * float(L["mouse_pitch"]) * sens * (-1.0 if Settings.get_value("invertY", false) else 1.0),
			float(L["pitch_min"]), float(L["pitch_max"]))


func _process(delta: float) -> void:
	if target == null or cam == null:
		return
	var dt: float = minf(delta, float(T["loop"]["dt_max"]))
	var L: Dictionary = T["look"]
	var C: Dictionary = T["cam"]
	var pmin: float = float(L["pitch_min"])
	var pmax: float = float(L["pitch_max"])
	var motor: BoltMotor = target.motor
	punch = maxf(0.0, punch - dt * float(L["punch_decay"]))
	# recoil spring-back
	if recoil_debt != 0.0:
		var rr: float = recoil_debt * BoltMotor.damp(9.0, dt)
		pitch = clampf(pitch - rr, pmin, pmax)
		recoil_debt -= rr
		if absf(recoil_debt) < 0.0004:
			recoil_debt = 0.0
	# right stick look
	if not BS.blocked():
		var look: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", float(Settings.get_value("deadzone", 0.15)))
		if look.length_squared() > 0.0:
			var fr: float = AimAssist.friction()
			if absf(look.x) + absf(look.y) > 0.05:
				look_idle_t = 0.0
			yaw -= look.x * float(L["pad_yaw"]) * float(Settings.get_value("padSens", 1.0)) * fr * dt * (-1.0 if Settings.get_value("invertX", false) else 1.0)
			pitch = clampf(pitch + look.y * float(L["pad_pitch"]) * float(Settings.get_value("padSens", 1.0)) * fr * dt * (-1.0 if Settings.get_value("invertY", false) else 1.0), pmin, pmax)
	# rotational aim assist (capped deg/s, only while aiming/firing on an assisted target)
	var assist: Vector2 = AimAssist.rotation_nudge(self, dt)
	yaw += assist.x
	pitch = clampf(pitch + assist.y, pmin, pmax)
	# lazy auto-cam: eases behind the run direction after the look input has been idle
	look_idle_t += dt
	var hs: float = Vector2(motor.vel.x, motor.vel.z).length()
	var walk: float = float(T["move"]["walk"])
	var sprint: float = float(T["move"]["sprint"])
	if Settings.get_value("camAuto", true) and not target.dead and look_idle_t > float(C["autoIdle"]) \
			and not target.is_aiming() and hs > walk * 0.7:
		var want: float = atan2(-motor.vel.x, -motor.vel.z)
		var dy: float = wrapf(want - yaw, -PI, PI)
		var ady: float = absf(dy)
		if ady > 0.12 and ady < 2.5:
			var spd_k: float = clampf((hs - walk * 0.7) / (sprint - walk * 0.7), 0.0, 1.0)
			var idle_k: float = clampf((look_idle_t - float(C["autoIdle"])) / 0.6, 0.0, 1.0)
			var rate: float = float(C["autoYawRate"]) * (0.35 + 0.65 * spd_k) * idle_k * minf(1.0, ady / 0.8) * dt
			yaw += clampf(dy, -rate, rate)
			pitch += clampf(float(C["autoPitch"]) - pitch, -0.25 * idle_k * dt, 0.25 * idle_k * dt)
	# FOV: settings + dash/long-jump kick + sprint widen (tightened while aiming)
	var sprint_k: float = clampf((hs - walk) / (sprint - walk), 0.0, 1.0)
	sprint_fov = lerpf(sprint_fov, 0.0 if target.is_aiming() else sprint_k * float(C["sprintFov"]), BoltMotor.damp(6.0, dt))
	var target_fov: float = float(Settings.get_value("fov", 70)) + motor.fov_kick + sprint_fov
	if absf(cam.fov - target_fov) > 0.05:
		cam.fov = lerpf(cam.fov, target_fov, BoltMotor.damp(float(L["fov_rate"]), dt))
	# follow point = player + height (+ opt-in positional lead)
	var lead_max: float = float(C["leadMax"])
	var want_lead: Vector3 = Vector3(clampf(motor.vel.x * 0.05, -lead_max, lead_max), 0, clampf(motor.vel.z * 0.05, -lead_max, lead_max)) \
		if Settings.get_value("camLookAhead", false) else Vector3.ZERO
	lead = lead.lerp(want_lead, BoltMotor.damp(3.0, dt))
	var want_anchor: Vector3 = target.global_position + lead + Vector3(0, float(L["anchor_height"]), 0)
	anchor = anchor.lerp(want_anchor, BoltMotor.damp(float(C["followRate"]), dt))
	# boom direction purely from yaw/pitch
	var boom: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var d_want: float = _boom_clear(boom)
	d_want = maxf(float(L["dist_min"]), d_want - punch)
	var rate2: float = float(L["dist_in_rate"]) if d_want < dist_cur else float(L["dist_out_rate"])
	dist_cur = lerpf(dist_cur, d_want, BoltMotor.damp(rate2, dt))
	var pos: Vector3 = anchor + boom * dist_cur
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - dt * float(L["shake_decay"]))
		var s: float = _shake * float(L["shake_amp"]) * float(Settings.get_value("shakeMul", 1.0))
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * s
	cam.global_position = pos
	cam.look_at(anchor, Vector3.UP)


## Longest clear boom along `boom` (sphere cast from the anchor; world geometry only).
func _boom_clear(boom: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis(), anchor)
	q.motion = boom * dist
	q.collision_mask = 1
	var res: PackedFloat32Array = space.cast_motion(q)
	if res.size() < 2 or res[0] >= 1.0:
		return dist
	return maxf(float(T["look"]["dist_min"]), dist * res[0] - 0.05)
