extends Node
## Aim assist, ported from the web build (index.html:4104-4206). One shared target-selection core drives
## bullet magnetism, reticle friction, rotational tracking and the mallet's magnetism. Per-device stickiness
## (settings stickPad / stickMouse) is the master dial: 0 disables everything even with the toggle on.
## Never assists through walls. Autoload name: AimAssist.
## Tuning: data/bs/tuning.json AIM_ASSIST (original values).

var target: Node3D = null
var los: bool = false
var fall: float = 1.0
var last_melee: Node3D = null
var last_device: String = "kb"          # "kb" or "pad"
var narrow: bool = true                  # the starter blaster uses the narrow cone (P.weapon === 0)
var enabled_mode: bool = false           # only while a B&S level is playing
var player: Node3D = null


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3):
		last_device = "pad"
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		last_device = "kb"


func _A() -> Dictionary:
	return (Data.table("bs/tuning") as Dictionary)["AIM_ASSIST"]


func k() -> float:
	if not enabled_mode or not bool(Settings.get_value("aimAssist", true)):
		return 0.0
	return float(Settings.get_value("stickPad", 0.6)) if last_device == "pad" else float(Settings.get_value("stickMouse", 0.2))


func melee_k() -> float:
	return k() if bool(Settings.get_value("meleeAssist", true)) else 0.0


func eye() -> Vector3:
	return player.global_position + Vector3(0, 0.5, 0) if player != null else Vector3.ZERO


## Score living enemies: angle to aim, distance, LOS, stickiness, melee continuity (pickTarget 4133).
func pick_target(aim_dir: Vector3, cone: float, rng: float, for_melee: bool) -> Node3D:
	if player == null:
		return null
	var A: Dictionary = _A()
	var e0: Vector3 = eye()
	var best: Node3D = null
	var bs: float = -1.0
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not e.call("is_alive") or e.is_in_group(&"props"):
			continue
		var to: Vector3 = (e.call("get_center") as Vector3) - e0
		var d: float = to.length()
		if d > rng + float(e.get("radius")) or d < 0.1:
			continue
		var a: float = (to / d).dot(aim_dir)
		if a < cone:
			continue
		var score: float = a * 2.0 - d * 0.03
		if e == target:
			score += float(A["stickyBonus"])
		if for_melee and e == last_melee:
			score += float(A["comboBonus"])
		if score <= bs:
			continue
		if not los_clear(e0, e.call("get_center")):
			continue
		best = e
		bs = score
	return best


func los_clear(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var dir: Vector3 = (to - from)
	var d: float = dir.length()
	if d < 0.7:
		return true
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir / d * (d - 0.6), 1)
	return space.intersect_ray(q).is_empty()


func falloff(d: float) -> float:
	var A: Dictionary = _A()
	var rng: float = float(A["rangeNarrow"]) if narrow else float(A["rangeMed"])
	if d <= float(A["falloffStart"]):
		return 1.0
	return lerpf(1.0, float(A["falloffFloor"]), clampf((d - float(A["falloffStart"])) / (rng - float(A["falloffStart"])), 0.0, 1.0))


## Per frame (updateAssist 4167): refresh the assisted target from the camera's view direction.
func update(view_dir: Vector3) -> void:
	if k() <= 0.0:
		target = null
		los = false
		return
	var A: Dictionary = _A()
	var cone: float = float(A["coneNarrow"]) if narrow else float(A["coneMed"])
	var rng: float = float(A["rangeNarrow"]) if narrow else float(A["rangeMed"])
	target = pick_target(view_dir, cone, rng, false)
	if target != null:
		los = true
		fall = falloff((target.call("get_center") as Vector3).distance_to(eye()))
	else:
		los = false


## Reticle friction: look sensitivity multiplier while the aim passes over the target (frictionMul 4161).
func friction() -> float:
	var K: float = k()
	if K <= 0.0 or target == null or not los:
		return 1.0
	return 1.0 - (1.0 - float(_A()["frictionFloor"])) * K * fall


## Rotational assist (updateCamera 4248): tiny capped yaw/pitch nudge toward the target while fire/aim is
## held. Mouse: off unless stickiness > 50%. Returns (dyaw, dpitch) in radians for this frame.
func rotation_nudge(cam: Node3D, dt: float) -> Vector2:
	var K: float = k()
	var engaged: bool = Input.is_action_pressed(&"fire") or Input.is_action_pressed(&"aim")
	var rot_ok: bool = K > 0.0 if last_device == "pad" else K > 0.5
	if not engaged or not rot_ok or target == null or not los or player == null:
		return Vector2.ZERO
	var to: Vector3 = ((target.call("get_center") as Vector3) - eye()).normalized()
	var want_yaw: float = atan2(-to.x, -to.z)
	var want_pitch: float = asin(clampf(-to.y, -1.0, 1.0))
	var rate: float = deg_to_rad(float(_A()["rotAssist"])) * K * fall * dt
	var yaw: float = float(cam.get("yaw"))
	var pitch: float = float(cam.get("pitch"))
	return Vector2(clampf(wrapf(want_yaw - yaw, -PI, PI), -rate, rate), clampf(want_pitch - pitch, -rate, rate))


## Bullet magnetism: bends a shot direction toward the assisted target by at most bendMax degrees.
func bend(dir: Vector3, from: Vector3) -> Vector3:
	var K: float = k()
	if K <= 0.0 or target == null or not los:
		return dir
	var to: Vector3 = ((target.call("get_center") as Vector3) - from).normalized()
	var ang: float = dir.angle_to(to)
	var max_a: float = deg_to_rad(float(_A()["bendMax"])) * K * fall
	if ang < 0.0001 or ang > deg_to_rad(25.0):
		return dir
	return dir.slerp(to, minf(1.0, max_a / ang)).normalized()
