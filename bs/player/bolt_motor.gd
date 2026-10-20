class_name BoltMotor
extends RefCounted
## Bolt's movement rules, ported line for line from the web build's updatePlayer() (index.html:3366-3597),
## dash() (3131), startSlam()/slamImpact() (3170/3184), startSlide()/updateSlide()/slideLongJump() (3273-3334).
## Pure logic: no nodes, no physics. The controller (bolt.gd) feeds it input and collision results:
##   motor.pre_move(dt, input)   -> sets vel for this frame (horizontal, vertical, hover, jumps, dash, slam, slide)
##   [the body moves and collides]
##   motor.post_move(dt, ground, was_ground) -> landing, coyote, double-jump reset, hover regen, slam impact
## The parity test (tests/unit/test_bolt_parity.gd) drives this against numbers produced by the original
## JavaScript formulas (tools/parity/bolt_reference.mjs). Coordinates: Godot +Y up; "forward" comes from
## the camera via input.dir. Tuning: data/bs/tuning.json (the original CONFIG verbatim).

signal jumped(kind: StringName)          # &"jump", &"double", &"wall", &"dash_jump", &"long", &"bounce"
signal dashed
signal slam_started(kind: StringName)
signal slam_landed(kind: StringName)
signal slide_started
signal landed(fall_height: float)

var T: Dictionary = {}

# --- state (names follow the original P.* fields)
var vel: Vector3 = Vector3.ZERO
var on_ground: bool = true
var jumps: int = 0
var jump_buffer: float = 0.0
var coyote: float = 0.0
var hover: float = 1.0
var hovering: bool = false
var air_t: float = 0.0
var dash_t: float = 0.0
var dash_cd: float = 0.0
var dash_dir: Vector3 = Vector3.FORWARD
var air_dash_used: bool = false
var slam: StringName = &""               # "", "flip", "hang", "fall"
var slam_kind: StringName = &"std"
var slam_flip_t: float = 0.0
var slam_hold_t: float = 0.0
var slam_bounce_t: float = 0.0
var slide_t: float = 0.0
var slide_cd: float = 0.0
var slide_low: bool = false
var slide_dir: Vector3 = Vector3.FORWARD
var wall_t: float = 0.0
var wall_n: Vector3 = Vector3.ZERO
var wall_lock: float = 0.0
var wall_sliding: bool = false
var land_t: float = 0.0
var fall_peak: float = 0.0
var yaw: float = 0.0                      # facing (radians, atan2(x, z) convention like the original)
var attack_committed: bool = false        # set by melee: a windup that hasn't hit yet holds the jump buffer
var slip: float = 0.0                     # ice (Glacius) 0..1
var frost_k: float = 0.0
var frozen_t: float = 0.0
var grav_mul: float = 1.0
var fov_kick: float = 0.0                 # read by the camera
var hy: float = 0.95                      # current half height (slide lowers it)
var pending_dy: float = 0.0               # body y shift owed from slide hitbox changes (the body applies and zeroes it)


func _init(tuning: Dictionary = {}) -> void:
	T = tuning
	hy = float(T.get("body", {}).get("hy", 0.95)) if not T.is_empty() else 0.95


static func damp(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)


func _c(section: String, key: String) -> float:
	return float((T[section] as Dictionary)[key])


# ------------------------------------------------------------------ inputs that happen on press

## Space / pad A: fills the jump buffer (CONFIG.jump.buffer), exactly like the original keydown handler.
func press_jump() -> void:
	jump_buffer = _c("jump", "buffer")


## R / pad B. Returns true if a dash started. `dir` is the camera-relative input direction (may be zero).
func press_dash(dir: Vector3) -> bool:
	if dash_cd > 0.0 or slam != &"":
		return false
	if not on_ground and air_dash_used:
		return false
	if not on_ground:
		air_dash_used = true
	if slide_low:
		set_slide_hitbox(false)
		slide_t = 0.0
	if dir.length_squared() > 0.01:
		dash_dir = Vector3(dir.x, 0, dir.z).normalized()
	else:
		dash_dir = Vector3(sin(yaw), 0, cos(yaw))
	if attack_committed:
		return false
	dash_t = _c("dash", "time")
	dash_cd = _c("dash", "cooldown")
	fov_kick = _c("dash", "fovKick")
	dashed.emit()
	return true


## Ctrl / C / pad LS: slam in the air (after the double jump), slide on the ground.
func press_crouch(dir: Vector3, melee_down_held: bool = false) -> void:
	if not on_ground:
		if jumps >= 2:
			start_slam(&"super" if melee_down_held else &"std")
	else:
		start_slide(dir)


func start_slam(kind: StringName) -> void:
	if slam != &"" or on_ground:
		return
	slam = &"hang" if kind == &"super" else &"flip"
	slam_kind = kind
	slam_flip_t = _c("slam", "superHang") if kind == &"super" else _c("slam", "flipTime")
	slam_hold_t = 0.0
	dash_t = 0.0
	hovering = false
	slam_started.emit(kind)


func start_slide(dir: Vector3) -> void:
	if slide_t > 0.0 or slide_low or slide_cd > 0.0 or not on_ground or dash_t > 0.0:
		return
	if Vector2(vel.x, vel.z).length() < _c("move", "walk") * float(T.get("slide_extra", {}).get("min_speed_mul", 0.9)):
		return
	if dir.length_squared() > 0.01:
		slide_dir = Vector3(dir.x, 0, dir.z).normalized()
	else:
		slide_dir = Vector3(vel.x, 0, vel.z).normalized()
	slide_t = _c("slide", "time")
	slide_cd = _c("slide", "cooldown")
	set_slide_hitbox(true)
	slide_started.emit()


## Returns the vertical offset the body must apply (the original moves P.pos.y by dh so the feet stay put).
func set_slide_hitbox(on: bool) -> float:
	if on == slide_low:
		return 0.0
	slide_low = on
	var full: float = float(T.get("body", {}).get("hy", 0.95))
	var dh: float = full - _c("slide", "hy")
	hy = _c("slide", "hy") if on else full
	var dy: float = -dh if on else dh
	pending_dy += dy
	return dy


# ------------------------------------------------------------------ per-frame

## The frame's input:
##   dir: Vector3 camera-relative move direction (length 0..1, analog), sprint: bool, jump_held: bool,
##   melee_held: bool (slam converts to super), crouch_held: bool (slide stays down), blocked_above: bool.
func pre_move(dt: float, input: Dictionary) -> void:
	var M: Dictionary = T["move"]
	var J: Dictionary = T["jump"]
	dash_cd -= dt; slide_cd -= dt; jump_buffer -= dt; coyote -= dt
	wall_t -= dt; wall_lock -= dt; slam_bounce_t -= dt
	air_t = 0.0 if on_ground else air_t + dt
	fov_kick = maxf(0.0, fov_kick - dt * float(T.get("look", {}).get("fov_kick_decay", 42.0)))
	wall_sliding = false
	hovering = false
	var jump_held: bool = bool(input.get("jump_held", false))
	var dir: Vector3 = input.get("dir", Vector3.ZERO)
	var has_input: bool = dir.length_squared() > 0.01
	var sprint: bool = bool(input.get("sprint", false)) or dir.length() > 0.93
	# frost (Retention Specialist's breath)
	if frozen_t > 0.0:
		frozen_t -= dt * (2.4 if has_input else 1.0)
		if frozen_t <= 0.0:
			frozen_t = 0.0
			frost_k = 0.0
	elif frost_k > 0.0:
		frost_k = maxf(0.0, frost_k - dt * 0.45)
	var frost_mul: float = 0.0 if frozen_t > 0.0 else 1.0 - 0.45 * frost_k
	var speed: float = (float(M["sprint"]) if sprint else float(M["walk"])) * frost_mul
	var h_spd: float = Vector2(vel.x, vel.z).length()

	# ---- horizontal velocity
	if dash_t > 0.0:
		dash_t -= dt
		vel.x = dash_dir.x * _c("dash", "speed")
		vel.z = dash_dir.z * _c("dash", "speed")
		vel.y = 0.0
	elif slide_t > 0.0 or slide_low:
		_update_slide(dt, dir if has_input else Vector3.ZERO, bool(input.get("crouch_held", false)), bool(input.get("blocked_above", false)))
	elif slam != &"":
		var k: float = 1.0 - minf(1.0, dt * float(T.get("slam_extra", {}).get("steer_damp", 8.0)))
		vel.x *= k
		vel.z *= k
	else:
		var rate: float
		if has_input:
			rate = float(M["accel"]) if on_ground else float(M["airAccel"])
			var reversing: bool = (vel.x * dir.x + vel.z * dir.z) < 0.0
			if on_ground and h_spd < float(M["snapTurnSpeed"]):
				rate *= 3.0
			elif on_ground and sprint and reversing:
				rate *= float(M["sprintCarry"])
		else:
			rate = float(M["decel"]) if on_ground else float(M["airDecel"])
		if on_ground and slip > 0.0:
			rate *= 1.0 - float(T.get("ice", {}).get("accel_cut", 0.72)) * slip
		if wall_lock > 0.0:
			rate *= 0.15
		var tx: float = dir.x * speed
		var tz: float = dir.z * speed
		if not on_ground and has_input and h_spd > speed:
			if vel.x * dir.x + vel.z * dir.z > 0.0:
				tx = dir.x * h_spd
				tz = dir.z * h_spd
		var d: float = damp(rate, dt)
		vel.x = lerpf(vel.x, tx, d)
		vel.z = lerpf(vel.z, tz, d)

	# ---- vertical velocity
	if slam == &"flip":
		vel.y = 0.0
		slam_flip_t -= dt
		if slam_flip_t <= 0.0:
			slam = &"fall"
	elif slam == &"hang":
		vel.y = float(T.get("slam_extra", {}).get("hang_fall", -1.4))
		slam_flip_t -= dt
		if slam_flip_t <= 0.0:
			slam = &"fall"
	elif slam == &"fall":
		vel.y = -(_c("slam", "superFall") if slam_kind == &"super" else _c("slam", "fallSpeed"))
		if slam_kind == &"std" and bool(input.get("melee_held", false)):
			slam_hold_t += dt
			if slam_hold_t >= _c("slam", "holdConvert"):
				slam_kind = &"super"
				slam = &"hang"
				slam_flip_t = _c("slam", "superHang") * 0.7
	elif dash_t > 0.0:
		pass   # gravity suspended during dash
	else:
		var g: float = (float(J["riseGrav"]) if jump_held else float(J["cutGrav"])) if vel.y > 0.0 else float(J["fallGrav"])
		g *= grav_mul
		if not on_ground and absf(vel.y) < 1.6 and jump_held:
			g *= float(J["apexGrav"])
		vel.y = maxf(-float(J["maxFall"]), vel.y - g * dt)
		# wall slide: pressed into a tall wall while falling
		var W: Dictionary = T["wall"]
		if not on_ground and wall_t > 0.0 and vel.y < 0.0 and air_t > float(W["minAir"]) and not hovering \
				and has_input and (dir.x * wall_n.x + dir.z * wall_n.z) < -0.3:
			vel.y = maxf(vel.y, -float(W["slideFall"]))
			wall_sliding = true
			jumps = mini(jumps, 1)
			air_dash_used = false

	# ---- hover: hold jump while falling
	var Hv: Dictionary = T["hover"]
	if not on_ground and slam == &"" and dash_t <= 0.0 and jump_held and jump_buffer <= 0.0 \
			and vel.y < float(Hv["engageBelow"]) and hover > 0.0:
		vel.y += (float(Hv["thrust"]) - vel.y) * minf(1.0, dt * float(T.get("hover_extra", {}).get("thrust_rate", 6.0)))
		hover = maxf(0.0, hover - dt / float(Hv["drainTime"]))
		hovering = true

	# ---- jumping (buffered, coyote, double, wall kick, dash-jump, slide long-jump, slam bounce)
	if jump_buffer > 0.0 and slam == &"":
		if attack_committed:
			pass
		elif dash_t > 0.0:
			var DJ: Dictionary = T["dashJump"]
			var d_spd: float = _c("dash", "speed") * float(DJ["hMul"])
			vel = Vector3(dash_dir.x * d_spd, float(DJ["v"]), dash_dir.z * d_spd)
			dash_t = 0.0; jump_buffer = 0.0; coyote = 0.0
			jumps = 1 if on_ground else 2
			fov_kick = maxf(fov_kick, 4.0)
			jumped.emit(&"dash_jump")
		elif slide_t > 0.0 or slide_low:
			if not bool(input.get("blocked_above", false)):
				_slide_long_jump()
		elif on_ground and slam_bounce_t > 0.0:
			var SB: Dictionary = T["slamBounce"]
			vel.y = float(SB["superV"]) if slam_kind == &"super" else float(SB["v"])
			jumps = 1; coyote = 0.0; jump_buffer = 0.0; slam_bounce_t = 0.0; land_t = 0.0
			air_dash_used = false
			fov_kick = maxf(fov_kick, 5.0)
			jumped.emit(&"bounce")
		elif on_ground or coyote > 0.0:
			vel.y = float(J["vel"]); jumps = 1; coyote = 0.0; jump_buffer = 0.0
			if sprint and h_spd > float(M["walk"]):
				vel.x *= float(M["sprintJumpBoost"])
				vel.z *= float(M["sprintJumpBoost"])
			jumped.emit(&"jump")
		elif wall_t > 0.0 and air_t > float(T["wall"]["minAir"]) and wall_lock <= 0.0:
			var W2: Dictionary = T["wall"]
			vel = Vector3(wall_n.x * float(W2["kickH"]), float(W2["kickV"]), wall_n.z * float(W2["kickH"]))
			wall_lock = float(W2["lockTime"]); wall_t = 0.0; jump_buffer = 0.0; coyote = 0.0
			jumps = 1; air_dash_used = false; hover = minf(1.0, hover + 0.25)
			yaw = atan2(wall_n.x, wall_n.z)
			fov_kick = maxf(fov_kick, 3.0)
			jumped.emit(&"wall")
		elif jumps < 2:
			vel.y = float(J["doubleVel"]); jumps = 2; jump_buffer = 0.0
			dash_t = 0.0
			jumped.emit(&"double")


## After the body has moved. `height` is the body's current y (for fall-height landing dips).
func post_move(dt: float, grounded: bool, was_ground: bool, height: float) -> void:
	on_ground = grounded
	if not on_ground:
		fall_peak = maxf(fall_peak, height)
	if on_ground:
		if slam != &"":
			_slam_land()
		elif not was_ground:
			var L: Dictionary = T.get("landing", {})
			var fell: float = fall_peak - height
			if fell > float(L.get("dip_from", 3.0)):
				land_t = maxf(land_t, clampf(float(L.get("dip_base", 0.08)) + fell * float(L.get("dip_per_m", 0.02)),
					float(L.get("dip_base", 0.08)), float(L.get("dip_max", 0.22))))
			landed.emit(fell)
		fall_peak = height
		jumps = 0
		coyote = _c("jump", "coyote")
		air_dash_used = false
		hover = minf(1.0, hover + dt * _c("hover", "regen"))
	land_t = maxf(0.0, land_t - dt)


## A horizontal hit against a tall wall (the controller detects it). `normal` points away from the wall.
func touch_wall(normal: Vector3) -> void:
	wall_n = Vector3(normal.x, 0, normal.z).normalized()
	wall_t = _c("wall", "coyote")


func _slam_land() -> void:
	var kind: StringName = slam_kind
	slam = &""
	land_t = 0.45 if kind == &"super" else 0.26
	slam_bounce_t = _c("slamBounce", "window")
	jump_buffer = minf(jump_buffer, 0.0)
	slam_landed.emit(kind)


func _update_slide(dt: float, steer: Vector3, crouch_held: bool, blocked_above: bool) -> void:
	var S: Dictionary = T["slide"]
	slide_t -= dt
	var k: float = clampf(slide_t / float(S["time"]), 0.0, 1.0)
	var spd: float = lerpf(float(T.get("slide_extra", {}).get("end_speed", 7.5)), float(S["speed"]), k)
	if steer != Vector3.ZERO:
		slide_dir = slide_dir.lerp(Vector3(steer.x, 0, steer.z), damp(float(S["steer"]), dt)).normalized()
	vel.x = slide_dir.x * spd
	vel.z = slide_dir.z * spd
	if slide_t <= 0.0 and not (crouch_held and slide_t > -1.5):
		if blocked_above:
			slide_t = minf(slide_t, 0.0)
			return
		set_slide_hitbox(false)
		slide_t = 0.0


func _slide_long_jump() -> void:
	var S: Dictionary = T["slide"]
	jump_buffer = 0.0
	set_slide_hitbox(false)
	slide_t = 0.0
	vel = Vector3(slide_dir.x * float(S["longJumpH"]), float(S["longJumpV"]), slide_dir.z * float(S["longJumpH"]))
	jumps = 1; coyote = 0.0
	fov_kick = maxf(fov_kick, 5.0)
	jumped.emit(&"long")


## Facing: aim direction while aiming, else direction of travel (updatePlayerMesh 3657).
func update_facing(dt: float, aim_yaw: float, aiming: bool) -> void:
	var h: float = Vector2(vel.x, vel.z).length()
	var target: float = yaw
	if aiming:
		target = aim_yaw
	elif h > 0.8:
		target = atan2(vel.x, vel.z)
	var F: Dictionary = T.get("facing", {"base_rate": 6.0, "speed_rate": 1.1})
	yaw = lerp_angle(yaw, target, damp(float(F["base_rate"]) + h * float(F["speed_rate"]), dt))
