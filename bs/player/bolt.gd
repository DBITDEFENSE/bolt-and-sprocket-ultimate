class_name Bolt
extends CharacterBody3D
## The player in Bolt & Sprocket. Movement rules live in BoltMotor (a line-by-line port of the web build,
## parity-tested); this node turns input into motor input, moves the body with collision rules mirroring the
## original movePlayer()/collideAxis() (index.html:2971-3061), and owns health, damage, void/water recovery.
##
## Public API (used by camera, melee, weapons, enemies, HUD, Sprocket):
##   motor: BoltMotor          hp / max_hp          camera: BoltCamera (set by the level)
##   aim_dir() -> Vector3      aim_origin() -> Vector3   is_aiming() -> bool
##   take_damage(hit: Combat.Hit) -> bool   heal(n)   respawn_at(pos)   get_center() -> Vector3
## Groups: "player", "damageable".

signal died
signal damaged(amount: float)

const UP: Vector3 = Vector3.UP

var T: Dictionary
var motor: BoltMotor
var camera: BoltCamera = null
var melee: BoltMelee = null
var hp: float = 100.0
var max_hp: float = 100.0
var invuln: float = 1.5
var dead: bool = false
var radius: float = 0.45
var kill_y: float = -40.0
var water_zones: Array[AABB] = []        # set by the level
var input_enabled: bool = true
## Scripted input (tests, cutscenes, demo playback). When non-empty it replaces device input. Keys as in
## _gather_input(); one-shot presses (jump_pressed, dash_pressed, crouch_pressed, melee_pressed) clear after use.
var scripted: Dictionary = {}
var last_safe: Vector3 = Vector3.ZERO
var ground_collider: Object = null
var _safe_timer: float = 0.0
var _was_terrain_ground: bool = false
var _in_dir: Vector3 = Vector3.ZERO      # smoothed input direction (inputDir 3360)
var _shape: CollisionShape3D
var _box: BoxShape3D
var _visual: Node3D
var _splash_quip_cd: float = 0.0


func _ready() -> void:
	T = Data.table("bs/tuning")
	motor = BoltMotor.new(T)
	add_to_group(&"player")
	add_to_group(&"damageable")
	max_hp = float(BS.max_hp)
	hp = max_hp
	collision_layer = 1 << 1                 # player
	collision_mask = 1 | (1 << 5)            # world, barricade/solid props
	var B: Dictionary = T["body"]
	_box = BoxShape3D.new()
	_box.size = Vector3(float(B["hx"]) * 2.0, float(B["hy"]) * 2.0, float(B["hz"]) * 2.0)
	_shape = CollisionShape3D.new()
	_shape.shape = _box
	add_child(_shape)
	safe_margin = 0.01
	var status: StatusEffects = StatusEffects.new()
	status.name = "Status"                   # statuses on the player (LIEN, frost...) per the damageable contract
	add_child(status)
	melee = BoltMelee.new()
	melee.name = "Melee"
	add_child(melee)
	_visual = BoltVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	last_safe = global_position
	motor.slam_landed.connect(_on_slam_landed)


func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, float(T["loop"]["dt_max"]))
	if dead:
		return
	invuln -= dt
	_splash_quip_cd -= dt
	var inp: Dictionary = _gather_input(dt)
	# presses first (the web build handled them in keydown, before the frame's update)
	if inp["jump_pressed"]:
		motor.press_jump()
	if inp["dash_pressed"]:
		motor.press_dash(inp["dir"])
	if inp["crouch_pressed"]:
		motor.press_crouch(inp["dir"], melee.down_held())
	motor.attack_committed = melee.windup_committed()
	_apply_slide_shift()
	var was_ground: bool = motor.on_ground
	motor.pre_move(dt, inp)
	_apply_slide_shift()
	var grounded: bool = _move(dt)
	motor.post_move(dt, grounded, was_ground, global_position.y)
	motor.update_facing(dt, (camera.yaw + PI) if camera != null else motor.yaw, is_aiming())
	_safety(dt)


## Slide changes the body height; the motor reports the y shift so the feet stay planted.
func _apply_slide_shift() -> void:
	if motor.pending_dy != 0.0:
		_box.size.y = motor.hy * 2.0
		global_position.y += motor.pending_dy
		motor.pending_dy = 0.0


# ------------------------------------------------------------------ input

func _gather_input(dt: float) -> Dictionary:
	var out: Dictionary = {"dir": Vector3.ZERO, "sprint": false, "jump_held": false, "jump_pressed": false,
		"dash_pressed": false, "crouch_pressed": false, "crouch_held": false, "melee_held": false, "blocked_above": false}
	if not scripted.is_empty():
		out.merge(scripted, true)
		for k: String in ["jump_pressed", "dash_pressed", "crouch_pressed"]:
			scripted.erase(k)
		out["blocked_above"] = motor.slide_low and _blocked_above()
		return out
	if not input_enabled or BS.blocked():
		_in_dir = Vector3.ZERO
		return out
	var cam_yaw: float = camera.yaw if camera != null else 0.0
	var f: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r: Vector3 = Vector3(-f.z, 0, f.x)
	var kb: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): kb.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): kb.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D): kb.x += 1.0
	if Input.is_physical_key_pressed(KEY_A): kb.x -= 1.0
	var dir: Vector3 = Vector3.ZERO
	if kb.length_squared() > 0.0:
		dir = (f * kb.y + r * kb.x).normalized()
		if Input.is_action_pressed(&"walk"):
			dir *= 0.45                                        # hold-to-walk on keyboard
	else:
		var stick: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward",
			float(Settings.get_value("deadzone", 0.15)))
		dir = f * stick.y + r * stick.x
		var m: float = dir.length()
		if m > 0.01:
			var m2: float = pow(minf(1.0, m), float(T["cam"]["padCurve"]))   # slow near center, fast at the rim
			dir *= m2 / m
	# short smoothing window (inputDir 3360-3362)
	_in_dir = _in_dir.lerp(dir, BoltMotor.damp(float(T["cam"]["inputSmooth"]), 1.0 / 120.0))
	if dir.length_squared() > 0.001:
		dir = dir.lerp(_in_dir, 0.35)
	out["dir"] = dir
	out["sprint"] = Input.is_action_pressed(&"sprint")
	out["jump_held"] = Input.is_action_pressed(&"jump")
	out["jump_pressed"] = Input.is_action_just_pressed(&"jump")
	out["dash_pressed"] = Input.is_action_just_pressed(&"dash")
	out["crouch_pressed"] = Input.is_action_just_pressed(&"crouch")
	out["crouch_held"] = Input.is_action_pressed(&"crouch")
	out["melee_held"] = Input.is_action_pressed(&"melee")
	out["blocked_above"] = motor.slide_low and _blocked_above()
	return out


func is_aiming() -> bool:
	return input_enabled and (Input.is_action_pressed(&"aim") or Input.is_action_pressed(&"fire"))


# ------------------------------------------------------------------ collision (mirrors movePlayer / collideAxis)

## Swept, sub-stepped movement. Returns true when standing on something at the end of the frame.
func _move(dt: float) -> bool:
	var B: Dictionary = T["body"]
	var v: Vector3 = motor.vel
	# ride moving platforms (the platform reports its frame delta through get_platform_delta())
	if ground_collider != null and is_instance_valid(ground_collider) and ground_collider.has_method("get_platform_delta"):
		global_position += ground_collider.call("get_platform_delta")
	ground_collider = null
	var max_disp: float = maxf(absf(v.x), maxf(absf(v.y), absf(v.z))) * dt
	var steps: int = mini(8, maxi(1, ceili(max_disp / float(B["max_substep"]))))
	var sdt: float = dt / float(steps)
	var grounded: bool = false
	for i: int in steps:
		_move_horizontal(Vector3(motor.vel.x, 0, motor.vel.z) * sdt)
		var vy: float = motor.vel.y * sdt
		if vy != 0.0:
			var c: KinematicCollision3D = move_and_collide(Vector3(0, vy, 0))
			if c != null:
				var n: Vector3 = c.get_normal()
				if vy < 0.0 and n.y > 0.5:
					grounded = true
					ground_collider = c.get_collider()
					if motor.vel.y < 0.0:
						motor.vel.y = 0.0
				elif vy > 0.0 and n.y < -0.5:
					if motor.vel.y > 0.0:
						motor.vel.y = 0.0
		if grounded and motor.slam != &"":
			break   # slam landing resolves exactly once, at the surface
	# stick to the ground going downhill (no bunny-bouncing down slopes)
	if not grounded and _was_terrain_ground and motor.vel.y <= 0.5 and motor.slam == &"":
		var probe: KinematicCollision3D = move_and_collide(Vector3(0, -0.5, 0), true)
		if probe != null and probe.get_normal().y > 0.5:
			global_position += probe.get_travel()
			motor.vel.y = 0.0
			grounded = true
			ground_collider = probe.get_collider()
	# too-steep faces shed the player downhill
	if grounded:
		var below: KinematicCollision3D = move_and_collide(Vector3(0, -0.05, 0), true)
		if below != null:
			var nn: Vector3 = below.get_normal()
			if nn.y < 0.62:
				motor.vel.x += nn.x * 46.0 * dt
				motor.vel.z += nn.z * 46.0 * dt
	_was_terrain_ground = grounded
	return grounded


## Horizontal step: auto step-up onto low ledges, airborne ledge assist, wall contact for wall slide/kick.
## Moves for real first; whatever motion the collision left over decides between climbing and sliding.
func _move_horizontal(h: Vector3) -> void:
	if h.length_squared() < 1e-10:
		return
	var B: Dictionary = T["body"]
	var c: KinematicCollision3D = move_and_collide(h)
	if c == null:
		return
	var rem: Vector3 = c.get_remainder()
	rem.y = 0.0
	var n: Vector3 = c.get_normal()
	var hn: Vector3 = Vector3(n.x, 0, n.z)
	if hn.length_squared() < 1e-6:
		return
	hn = hn.normalized()
	# try to climb: step-up (stairs) always; ledge assist (barely missed a lip) in the air
	var lifts: Array[float] = []
	if motor.vel.y <= 0.5:
		lifts.append(float(B["step_up"]))
	if motor.vel.y <= float(B["ledge_assist_max_vy"]) and motor.slam != &"fall" and not motor.slide_low:
		lifts.append(float(B["ledge_assist"]))
	var probe: Vector3 = rem if rem.length_squared() > 1e-8 else -hn * 0.05
	for lift: float in lifts:
		if test_move(global_transform, UP * lift) or test_move(global_transform.translated(UP * lift), probe):
			continue
		global_position += UP * lift
		move_and_collide(probe)
		var settle: KinematicCollision3D = move_and_collide(Vector3(0, -lift, 0))
		if settle != null and settle.get_normal().y > 0.5 and motor.vel.y < 0.0:
			motor.vel.y = 0.0
		return
	# blocked: kill the velocity into the wall, slide along it, and remember it if it's tall (not a lip)
	var into: float = motor.vel.dot(-hn)
	if into > 0.0:
		motor.vel += hn * into
	if rem.length_squared() > 1e-8:
		move_and_collide(rem.slide(hn))
	if test_move(global_transform.translated(UP * minf(float(B["wall_min_height"]), motor.hy)), -hn * 0.05):
		motor.touch_wall(hn)


func _blocked_above() -> bool:
	var full: float = float(T["body"]["hy"])
	var dh: float = full - float(T["slide"]["hy"])
	return test_move(global_transform, UP * (dh + 0.1))


# ------------------------------------------------------------------ safety, damage

func _safety(dt: float) -> void:
	if motor.on_ground and (ground_collider == null or not (ground_collider as Object).has_method("get_platform_delta")):
		_safe_timer -= dt
		if _safe_timer <= 0.0:
			_safe_timer = float(T["death"]["safe_interval"])
			last_safe = global_position
	if global_position.y < kill_y:
		_recover(float(T["death"]["void_damage"]), false)
		return
	for wz: AABB in water_zones:
		var p: Vector3 = global_position
		if wz.has_point(Vector3(p.x, p.y - motor.hy + 0.01, p.z)):
			_recover(float(T["death"]["water_damage"]), true)
			return


func _recover(dmg: float, splash: bool) -> void:
	var h: Combat.Hit = Combat.Hit.make(dmg)
	take_damage(h, true)
	if dead:
		return
	if motor.slide_low:
		motor.set_slide_hitbox(false)
		_apply_slide_shift()
	motor.slam = &""
	motor.dash_t = 0.0
	motor.slide_t = 0.0
	motor.vel = Vector3.ZERO
	global_position = last_safe
	_settle_after_teleport()
	if splash and _splash_quip_cd <= 0.0:
		_splash_quip_cd = 20.0
		var n: int = (Data.table("bs/story/barks")["out_of_bounds"] as Array).size() if Data.table("bs/story/barks")["out_of_bounds"] is Array else 0
		if n > 0:
			EventBus.bark.emit("splash.%02d" % randi_range(1, n))


func take_damage(hit: Combat.Hit, ignore_invuln: bool = false) -> bool:
	if dead or (invuln > 0.0 and not ignore_invuln) or BS.god_mode:
		return false
	hp = maxf(0.0, hp - hit.amount)
	invuln = maxf(invuln, 0.6)
	if hit.knock > 0.0 and hit.dir != Vector3.ZERO:
		motor.vel += Vector3(hit.dir.x, 0, hit.dir.z).normalized() * hit.knock + UP * minf(4.0, hit.knock * 0.4)
	damaged.emit(hit.amount)
	EventBus.player_damaged.emit(hit.amount, hp)
	if camera != null:
		camera.shake(0.35)
	if hp <= 0.0:
		dead = true
		died.emit()
		EventBus.player_died.emit()
		return true
	return false


func heal(n: float) -> void:
	hp = minf(max_hp, hp + n)


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	last_safe = pos
	motor.vel = Vector3.ZERO
	motor.slam = &""
	motor.dash_t = 0.0
	motor.hover = 1.0
	motor.jumps = 0
	dead = false
	hp = max_hp
	invuln = 1.5
	if melee != null:
		melee.reset()          # resetPlayer: attackT = 0, queue cleared, combo reset, mallet retrieved
	_settle_after_teleport()
	if camera != null:
		camera.snap_to(self)


## After a teleport the motor still remembers the old frame's air/ground state, so the first jump press
## would be spent as a double jump. Probe the floor and restore a clean grounded (or airborne) state.
func _settle_after_teleport() -> void:
	var c: KinematicCollision3D = move_and_collide(Vector3(0, -0.15, 0), true)
	var grounded: bool = c != null and c.get_normal().y > 0.5
	if grounded:
		global_position += c.get_travel()
	motor.on_ground = grounded
	motor.jumps = 0
	motor.coyote = float(T["jump"]["coyote"]) if grounded else 0.0
	motor.jump_buffer = 0.0
	motor.air_dash_used = false
	motor.fall_peak = global_position.y


func is_alive() -> bool:
	return not dead


func get_center() -> Vector3:
	return global_position


## Where shots come from and go: the camera's view ray (third-person shooter aim), from the chest.
func aim_origin() -> Vector3:
	return global_position + Vector3(0, 0.35, 0)


func aim_dir() -> Vector3:
	if camera == null:
		return Vector3(sin(motor.yaw), 0, cos(motor.yaw))
	return camera.view_dir()


func _on_slam_landed(kind: StringName) -> void:
	melee.slam_impact(kind)
