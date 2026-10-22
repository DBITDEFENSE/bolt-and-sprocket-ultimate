class_name Player
extends CharacterBody3D
## First-person survivor: movement (walk/sprint/crouch/slide/jump/lean), health and regen, the
## interaction ray with hold-to-use, and the camera. Weapons live in the WeaponHolder under the camera.
## Built entirely in code so the map just instances `Player.new()`.
##
## Co-op (M7): every peer has one *local* Player (camera, HUD, input, client-side prediction of its own
## movement) and a *remote* Player per teammate (`is_local = false`): a third-person RemoteBody moved by
## interpolated network state, a mirrored inventory (WeaponHolder.mirror) for host-side rules, and calls that
## must reach the owner (take_hit, apply_status, apply_knockback) forwarded to them. In co-op a downed player
## crawls with a pistol (last stand) until revived or bled out; bled out = spectate until the next round.
##
## AI teammates (T-031): a bot is a remote-style Player (`is_local = false, is_bot = true`) that lives on this
## machine: it collides with the world, takes damage and goes down here instead of forwarding to an owner, and a
## BotBrain child moves it, aims it and fires its weapons. Its RemoteBody is the same third-person body a co-op
## teammate has.

signal prompt_denied

const LAYER_PLAYER: int = 1 << 1
const MASK_MOVE: int = 1 | (1 << 2) | (1 << 5) | (1 << 8)   # world, zombie bodies, barricades, doors
const MASK_INTERACT: int = 1 | (1 << 4) | (1 << 8)          # world, interactables, doors
const GRAVITY: float = 14.0
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.1
const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.0
const INTERACT_RANGE: float = 2.3
const STRIDE: float = 2.1                  # metres per footstep (sprint stretches it a little)
const HEARTBEAT_BELOW: float = 0.35        # health fraction that starts the heartbeat loop
## Footstep surface by collider name (lower-case substring). First match wins; see _floor_surface().
const METAL_HINTS: PackedStringArray = ["lift", "cage", "grate", "catwalk", "deck", "boxcar", "locomotive", "fuselage", "turbine"]
const WOOD_HINTS: PackedStringArray = ["hay", "bed", "table", "bunk", "pew", "stall", "loft", "plank", "board", "trunk", "cart"]
const STONE_HINTS: PackedStringArray = ["hearth", "chimney", "stone", "altar", "font", "salt", "core", "chapel", "ramp", "corr"]

var player_id: int = 1
var character_id: StringName = &"dutch"
## false = a teammate's puppet on this peer (set by the map before add_child).
var is_local: bool = true
## An AI teammate (with is_local = false): simulated here, driven by its BotBrain (set before add_child).
var is_bot: bool = false
var remote_body: RemoteBody = null
var last_stand: bool = false      # co-op: downed and crawling with a pistol
var spectating: bool = false      # co-op: bled out, watching a teammate until the next round
var net_flags: int = 0            # remote: the last replicated state flags (see NetMatch.PF_*)
var interp: InterpBuffer = null   # remote: interpolation samples
var bot_damage_mult: float = 1.0  # bot: skill preset damage_taken_mult (bots.json)

var camera: Camera3D
var head: Node3D
var weapons: WeaponHolder

var max_hp: float = 100.0
var hp: float = 100.0
var downed: bool = false
var crouching: bool = false
var sliding: bool = false
var sprinting: bool = false
var noclip: bool = false

var interact_target: Interactable = null
var interact_progress: float = 0.0   # 0..1 for the HUD
var prompt_text: String = ""

var _cfg: Dictionary = {}
var _pitch: float = 0.0
var _rk: Vector2 = Vector2.ZERO          # recoil camera offset (pitch, yaw) radians, spring back to 0
var _rk_v: Vector2 = Vector2.ZERO
var _rk_w: float = 12.0                  # recoil spring angular frequency (per weapon, from data)
var _fov_punch: float = 0.0
var _shake_t: float = 0.0
var _step_count: int = 0
var _look_delta: Vector2 = Vector2.ZERO
var _since_hit: float = 99.0
var _stamina: float = 4.0
var _stamina_wait: float = 0.0
var _slide_t: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0            # current slide speed (decays with friction, slopes add or take)
var _slide_cd: float = 0.0               # seconds until the next slide may start
var _slide_k: float = 0.0                # 0..1 camera blend for the slide dip / tilt
var slides: int = 0                      # slides started this match (tools / HUD)
var slide_jumps: int = 0
var _lunge_t: float = 0.0
var _lunge_vel: Vector3 = Vector3.ZERO
var _status: Dictionary = {}      # effect -> seconds left (scream, shard_slow, whip_slow, knockdown)
var _status_fx: CanvasLayer = null
var _hold_t: float = 0.0
var _hold_locked: bool = false
var _lean: float = 0.0
var _eye: float = EYE_STAND
var _shake: float = 0.0
var _fov_base: float = 0.0
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D
var _was_on_floor: bool = true
var _step_dist: float = 0.0
var _surface_cache: Dictionary = {}   # collider instance id -> "snow"/"wood"/"stone"/"metal", or "ground" (roof probe)
var _heartbeat: AudioStreamPlayer
var _hold_node: Interactable = null   # the interactable a hold is in progress on (Interactable.hold_changed)


func _ready() -> void:
	if not is_local:
		_ready_remote()
		return
	_cfg = GLData.table("player")
	add_to_group(&"players")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_MOVE
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	max_hp = float(_cfg["max_health"])
	hp = max_hp
	_stamina = float(_cfg["sprint_duration"])
	character_id = GameState.character_of(player_id)
	_collider = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_collider.shape = _capsule
	_collider.position.y = STAND_HEIGHT * 0.5
	add_child(_collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.01        # the viewmodel is compressed toward the eye (D-062)
	camera.far = 400.0
	camera.current = true
	head.add_child(camera)
	weapons = WeaponHolder.new()
	weapons.name = "Weapons"
	camera.add_child(weapons)
	weapons.setup(self)
	_heartbeat = AudioDirector.make_loop_2d("heartbeat", self)
	GLBus.explosion.connect(_on_explosion)
	GLBus.perks_changed.connect(_on_perks_changed)
	GLBus.player_status.connect(_on_player_status)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A teammate's puppet: collision (zombies push against it), a head + camera that carry the aim, a mirrored
## inventory, and the third-person body. It never reads input.
func _ready_remote() -> void:
	_cfg = GLData.table("player")
	add_to_group(&"players")
	collision_layer = LAYER_PLAYER
	collision_mask = 0
	if is_bot:
		add_to_group(&"bots")
		collision_mask = MASK_MOVE   # a bot walks the world itself
		floor_max_angle = deg_to_rad(46.0)
		floor_snap_length = 0.35
	max_hp = float(_cfg["max_health"])
	hp = max_hp
	character_id = GameState.character_of(player_id)
	_collider = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_collider.shape = _capsule
	_collider.position.y = STAND_HEIGHT * 0.5
	add_child(_collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = false
	head.add_child(camera)
	weapons = WeaponHolder.new()
	weapons.name = "Weapons"
	weapons.mirror = true
	camera.add_child(weapons)
	weapons.setup(self)
	remote_body = RemoteBody.new()
	remote_body.name = "Body"
	add_child(remote_body)
	remote_body.setup(character_id, player_id)
	if not is_bot:
		interp = InterpBuffer.new()
	GLBus.perks_changed.connect(_on_perks_changed)
	if is_bot:
		GLBus.player_status.connect(_on_player_status)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or (downed and not last_stand) or spectating or GameState.phase != GameState.Phase.PLAYING or GameState.input_blocked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var sens: float = 0.0022 * GLSettings.get_f("sensitivity")
		if weapons.ads_t > 0.5:
			sens *= GLSettings.get_f("ads_sensitivity")
		_apply_look(mm.relative * sens)
		_look_delta += mm.relative
	elif event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_swap = true
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var _wheel_swap: bool = false


func _apply_look(rel: Vector2) -> void:
	rotate_y(-rel.x)
	var inv: float = -1.0 if bool(GLSettings.values.get("invert_y", false)) else 1.0
	_pitch = clampf(_pitch - rel.y * inv, deg_to_rad(-88.0), deg_to_rad(88.0))


func _pad_look(delta: float) -> void:
	var v: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.15)
	if v.length_squared() < 0.0001:
		return
	v = v * v.length()   # response curve
	var rate: float = 2.8 * GLSettings.get_f("pad_sensitivity")
	if weapons.ads_t > 0.5:
		rate *= 0.55
	if _crosshair_on_enemy():
		rate *= 0.6     # aim-assist slowdown
	_apply_look(v * rate * delta)
	_look_delta += v * 8.0


func _crosshair_on_enemy() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 30.0, 1 | (1 << 3))
	q.collide_with_areas = true
	var res: Dictionary = space.intersect_ray(q)
	return not res.is_empty() and res["collider"] is Hitbox


func _gather_intent() -> Dictionary:
	var slot: int = -1
	if Input.is_action_just_pressed(&"weapon_1"):
		slot = 0
	elif Input.is_action_just_pressed(&"weapon_2"):
		slot = 1
	elif Input.is_action_just_pressed(&"weapon_3"):
		slot = 2
	var swap: bool = Input.is_action_just_pressed(&"swap_weapon") or _wheel_swap
	_wheel_swap = false
	# On a pad, X is both reload and use: it reloads only when nothing is in front of you.
	var reload: bool = Input.is_action_just_pressed(&"reload") and (interact_target == null or not Input.is_action_pressed(&"interact"))
	var intent: Dictionary = {
		"fire_pressed": Input.is_action_just_pressed(&"fire"),
		"fire_held": Input.is_action_pressed(&"fire"),
		"ads": Input.is_action_pressed(&"ads") and not _status_flag("no_ads"),
		"reload": reload,
		"melee": Input.is_action_just_pressed(&"melee"),
		"lethal_held": Input.is_action_pressed(&"lethal"),
		"tactical": Input.is_action_just_pressed(&"tactical"),
		"alt_fire": Input.is_action_just_pressed(&"alt_fire"),
		"swap": swap,
		"slot": slot,
		"sprinting": sprinting,
		"look_delta": _look_delta,
	}
	_look_delta = Vector2.ZERO
	return intent


# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if not is_local:
		if not is_bot:
			_remote_tick(delta)   # a bot's BotBrain moves it
		return
	if GameState.phase != GameState.Phase.PLAYING or downed or spectating:
		_set_heartbeat(false)
		if last_stand and GameState.phase == GameState.Phase.PLAYING:
			_last_stand_tick(delta)
		return
	if GameState.input_blocked:
		velocity = Vector3(0, velocity.y - GRAVITY * delta, 0) if not is_on_floor() else Vector3.ZERO
		move_and_slide()
		_update_health(delta)   # keep regen + heartbeat in step while a radio/switchboard UI is open
		return
	_pad_look(delta)
	_update_movement(delta)
	_update_health(delta)
	_update_interaction(delta)
	weapons.tick(delta, _gather_intent())
	_update_camera(delta)


func _update_movement(delta: float) -> void:
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
	var wish: Vector3 = (global_basis * Vector3(input.x, 0, input.y))
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	if noclip:
		var fly: Vector3 = (camera.global_basis * Vector3(input.x, 0, input.y)) * 12.0
		if Input.is_action_pressed(&"jump"):
			fly.y += 8.0
		global_position += fly * delta
		velocity = Vector3.ZERO
		return
	var on_floor: bool = is_on_floor()
	_slide_cd = maxf(0.0, _slide_cd - delta)
	var S: Dictionary = _cfg.get("slide", {})
	# crouch toggle / slide: crouch while sprinting (or carrying sprint speed) drops into a slide; crouch again
	# during one cancels it; jump out of it is a slide-jump that keeps the speed
	if Input.is_action_just_pressed(&"crouch"):
		var fast: bool = horizontal_speed() >= float(S.get("min_sprint_speed", 4.0))
		if sliding:
			_end_slide(false)
		elif (sprinting or (fast and Input.is_action_pressed(&"sprint"))) and on_floor and _slide_cd <= 0.0:
			_start_slide(wish)
		else:
			crouching = not crouching
	if Input.is_action_just_pressed(&"jump") and sliding and on_floor:
		_slide_jump()
	elif Input.is_action_just_pressed(&"jump") and crouching and not sliding:
		crouching = false
	# sprint (forward-ish only, not while aiming)
	var unlimited: bool = bool(PerkManager.stat(player_id, "unlimited_sprint", false))
	var wants_sprint: bool = Input.is_action_pressed(&"sprint") and input.y < -0.3 and weapons.ads_t < 0.3 and not crouching
	if wants_sprint and (_stamina > 0.0 or unlimited) and on_floor or (sprinting and not on_floor and wants_sprint):
		sprinting = true
		if not unlimited:
			_stamina = maxf(0.0, _stamina - delta)
		_stamina_wait = float(_cfg["sprint_recharge_delay"])
	else:
		sprinting = false
		_stamina_wait = maxf(0.0, _stamina_wait - delta)
		if _stamina_wait <= 0.0:
			_stamina = minf(float(_cfg["sprint_duration"]), _stamina + delta * 1.5)
	var target_speed: float = float(_cfg["walk_speed"])
	if sprinting:
		target_speed = float(_cfg["sprint_speed"])
	elif crouching:
		target_speed = float(_cfg["crouch_speed"])
	target_speed *= weapons.move_mult() * lerpf(1.0, 0.6, weapons.ads_t) * float(PerkManager.stat(player_id, "move_speed_mult", 1.0))
	target_speed *= status_move_mult()
	var horizontal: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if sliding:
		_slide_t -= delta
		# steer a little toward the stick, lose speed to friction, gain it downhill (lose it uphill)
		if wish.length_squared() > 0.01:
			var want: Vector3 = wish.normalized()
			var ang: float = _slide_dir.signed_angle_to(want, Vector3.UP)
			_slide_dir = _slide_dir.rotated(Vector3.UP, clampf(ang, -float(S.get("steer", 1.6)) * delta, float(S.get("steer", 1.6)) * delta)).normalized()
		var slope: float = 0.0
		if on_floor:
			slope = get_floor_normal().dot(_slide_dir)           # > 0 heading downhill (the normal leans that way)
		_slide_speed -= float(S.get("friction", 7.5)) * delta
		_slide_speed += slope * float(S.get("slope_accel", 9.0)) * delta
		horizontal = _slide_dir * _slide_speed * minf(1.0, status_move_mult())
		if _slide_t <= 0.0 or _slide_speed <= float(S.get("min_speed", 3.2)):
			_end_slide(true)
		elif not on_floor:
			_end_slide(false)                                      # left the ground: keep the momentum
	elif _lunge_t > 0.0:
		_lunge_t -= delta
		horizontal = _lunge_vel
	else:
		var accel: float = 45.0 if on_floor else 8.0
		horizontal = horizontal.move_toward(wish * target_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if on_floor:
		if Input.is_action_just_pressed(&"jump") and not crouching and velocity.y <= 0.0:
			velocity.y = float(_cfg["jump_velocity"])
		elif velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	_set_crouch_shape(crouching or sliding)
	_slide_k = move_toward(_slide_k, 1.0 if sliding else 0.0, delta * (9.0 if sliding else 5.0))
	var fall_speed: float = -velocity.y
	move_and_slide()
	if not _was_on_floor and is_on_floor():
		_shake = maxf(_shake, 0.15)
		_footstep(-2.0)
		weapons.on_landed(fall_speed)
	_was_on_floor = is_on_floor()
	if is_on_floor() and not sliding:
		_step_dist += Vector2(velocity.x, velocity.z).length() * delta
		var stride: float = STRIDE * (1.25 if sprinting else (0.8 if crouching else 1.0))
		if _step_dist >= stride:
			_step_dist = 0.0
			_step_count += 1
			_footstep(-6.0 if crouching else 0.0)
	else:
		_step_dist = minf(_step_dist, STRIDE * 0.7)


## One footstep on whatever is underfoot (a short ray down, only when a step lands).
func _footstep(volume_db: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 0.3
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.9, 1 | (1 << 8), [get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	var surface: String = _floor_surface(hit.get("collider") as Object) if not hit.is_empty() else "stone"
	AudioDirector.play_2d("footstep_" + surface, volume_db, 0.0)


## Floor material heuristic (cached per collider). Priority: a "surface" metadata on the collider (or its
## parent), moving bodies (the lift cage) = metal, name hints, then per map: the open "Ground" is snow, ground
## under a roof is the inn's boards on Map 0 / concrete on Map 1, other floors are wood on Map 0, stone on Map 1.
func _floor_surface(col: Object) -> String:
	var n: Node = col as Node
	if n == null:
		return "stone"
	var id: int = n.get_instance_id()
	var s: String = str(_surface_cache.get(id, ""))
	if s == "":
		s = _classify_floor(n)
		_surface_cache[id] = s
	if s == "ground":
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var from: Vector3 = global_position + Vector3.UP * 2.0
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 10.0, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			return "snow"
		return "wood" if GameState.map_id == &"map00_crossroads" else "stone"
	return s


func _classify_floor(n: Node) -> String:
	for m: Node in [n, n.get_parent()]:
		if m != null and m.has_meta("surface"):
			return str(m.get_meta("surface"))
	if n is AnimatableBody3D:
		return "metal"
	var nm: String = String(n.name).to_lower()
	for h: String in METAL_HINTS:
		if nm.contains(h):
			return "metal"
	if nm.begins_with("ground"):
		return "ground"
	for h: String in STONE_HINTS:
		if nm.contains(h):
			return "stone"
	for h: String in WOOD_HINTS:
		if nm.contains(h):
			return "wood"
	return "wood" if GameState.map_id == &"map00_crossroads" else "stone"


func _start_slide(wish: Vector3) -> void:
	var S: Dictionary = _cfg.get("slide", {})
	sliding = true
	sprinting = false
	crouching = true
	slides += 1
	_slide_t = float(S.get("duration", _cfg.get("slide_duration", 0.7)))
	_slide_dir = wish.normalized() if wish.length_squared() > 0.01 else -global_basis.z
	_slide_dir.y = 0.0
	_slide_dir = _slide_dir.normalized()
	_slide_speed = maxf(float(S.get("speed", _cfg.get("slide_speed", 8.5))), horizontal_speed() + 1.0)
	_slide_cd = float(S.get("cooldown", 0.45))
	_shake = maxf(_shake, 0.08)
	_footstep(-3.0)                                                 # the scrape as the knees hit the floor
	weapons.on_landed(2.0)                                          # a small viewmodel dip
	# Blastproof Bock: sliding releases a small concussive shockwave (no self damage).
	var shock: float = float(PerkManager.stat(player_id, "slide_shockwave_damage", 0.0))
	if shock > 0.0:
		var r: float = float(PerkManager.stat(player_id, "slide_shockwave_radius", 3.0))
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z.global_position.distance_to(global_position) <= r:
					z.take_damage(shock, &"torso", &"blastproof_bock", player_id, &"explosive")
		Effects.explosion(global_position + Vector3.UP * 0.3, r * 0.6)
		AudioDirector.play_3d("grenade_explode", global_position, -8.0, 0.2)


## The slide is over: pop back up when sprint is still held and the head is clear (COD), else stay crouched.
func _end_slide(natural: bool) -> void:
	if not sliding:
		return
	sliding = false
	var S: Dictionary = _cfg.get("slide", {})
	var stand: bool = bool(S.get("stand_up", true)) and Input.is_action_pressed(&"sprint") and not _head_blocked()
	crouching = not stand
	if natural and not stand and Input.is_action_pressed(&"crouch"):
		crouching = true
	# whatever speed is left carries into the walk / sprint (the move_toward settles it)
	velocity.x = _slide_dir.x * _slide_speed
	velocity.z = _slide_dir.z * _slide_speed


## Jump out of a slide: keep the slide speed along its direction, a slightly bigger hop, stand up.
func _slide_jump() -> void:
	var S: Dictionary = _cfg.get("slide", {})
	var spd: float = _slide_speed
	sliding = false
	crouching = _head_blocked()
	slide_jumps += 1
	velocity.x = _slide_dir.x * spd
	velocity.z = _slide_dir.z * spd
	velocity.y = float(_cfg["jump_velocity"]) + float(S.get("jump_boost", 0.6))
	_slide_cd = maxf(_slide_cd, float(S.get("cooldown", 0.45)))


func is_sliding() -> bool:
	return sliding


func _set_crouch_shape(crouch: bool) -> void:
	var h: float = CROUCH_HEIGHT if crouch else STAND_HEIGHT
	if not crouch and _capsule.height < STAND_HEIGHT and _head_blocked():
		h = _capsule.height
		crouching = true
	_capsule.height = move_toward(_capsule.height, h, 0.2)
	_collider.position.y = _capsule.height * 0.5
	_eye = move_toward(_eye, EYE_CROUCH if crouch else EYE_STAND, 0.12)


func _head_blocked() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * CROUCH_HEIGHT
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT + 0.1), 1 | (1 << 8))
	return not space.intersect_ray(q).is_empty()


## Timed status effects from enemies (data/enemies.json "status"). Refreshes, never stacks.
func apply_status(effect: StringName, seconds: float) -> void:
	if not is_local and not is_bot:
		_forward(&"status", [effect, seconds])
		return
	if downed:
		return
	_status[effect] = maxf(float(_status.get(effect, 0.0)), seconds)
	var def: Dictionary = (GLData.table("enemies").get("status", {}) as Dictionary).get(String(effect), {})
	if bool(def.get("fx", false)) and is_local:
		if _status_fx == null or not is_instance_valid(_status_fx):
			_status_fx = (load("res://gravelight/ui/status_fx.gd") as GDScript).new() as CanvasLayer
			add_child(_status_fx)
		_status_fx.call("pulse", effect, seconds)


func has_status(effect: StringName) -> bool:
	return float(_status.get(effect, 0.0)) > 0.0


func status_move_mult() -> float:
	var m: float = 1.0
	var defs: Dictionary = GLData.table("enemies").get("status", {})
	for e: Variant in _status.keys():
		if float(_status[e]) > 0.0:
			m = minf(m, float((defs.get(String(e), {}) as Dictionary).get("move_mult", 1.0)))
	return m


func _status_flag(key: String) -> bool:
	var defs: Dictionary = GLData.table("enemies").get("status", {})
	for e: Variant in _status.keys():
		if float(_status[e]) > 0.0 and bool((defs.get(String(e), {}) as Dictionary).get(key, false)):
			return true
	return false


## Shoves the player (Foreman jab, slam, charge).
func apply_knockback(impulse: Vector3) -> void:
	if not is_local and not is_bot:
		_forward(&"knock", [impulse])
		return
	impulse.y = 0.0
	if impulse.length() < 0.1:
		return
	_lunge_t = 0.25
	_lunge_vel = impulse
	velocity.y = maxf(velocity.y, 2.5)
	_shake = maxf(_shake, 0.5)


func _on_player_status(pid: int, effect: StringName, seconds: float) -> void:
	if pid == player_id:
		apply_status(effect, seconds)


func _update_health(delta: float) -> void:
	for e: Variant in _status.keys():
		_status[e] = maxf(0.0, float(_status[e]) - delta)
	_since_hit += delta
	if _since_hit >= float(_cfg["regen_delay"]) and hp < max_hp:
		hp = minf(max_hp, hp + float(_cfg["regen_per_second"]) * delta)
	_set_heartbeat(hp < max_hp * HEARTBEAT_BELOW)


## Low-health heartbeat: one looping child player, toggled only when the state changes.
func _set_heartbeat(on: bool) -> void:
	if _heartbeat == null or _heartbeat.playing == on:
		return
	if on:
		_heartbeat.play()
	else:
		_heartbeat.stop()


func _update_interaction(delta: float) -> void:
	interact_target = _probe_interactable()
	prompt_text = "" if interact_target == null else interact_target.get_prompt(self)
	var held: bool = Input.is_action_pressed(&"interact")
	if interact_target == null or prompt_text == "" or not held:
		_hold_t = 0.0
		interact_progress = 0.0
		_set_hold_node(null)
		if not held:
			_hold_locked = false
		return
	if _hold_locked:
		_set_hold_node(null)
		return
	_set_hold_node(interact_target)
	var need: float = maxf(0.01, interact_target.hold_time(self))
	_hold_t += delta
	interact_progress = clampf(_hold_t / need, 0.0, 1.0)
	if _hold_t >= need:
		_hold_t = 0.0
		if interact_target.can_interact(self):
			use_interactable(interact_target)
		else:
			AudioDirector.play_2d("deny", -4.0)
		if not interact_target.repeats():
			_hold_locked = true
			_set_hold_node(null)


## Completes a use. On a co-op client the host runs it (with this player's puppet); local-only
## interactables (Intel, UIs that only read) run here.
func use_interactable(target: Interactable) -> void:
	if Net.is_client() and not target.net_local() and Net.session != null:
		Net.session.request_interact(target)
	else:
		target.interact(self)


## Tells an interactable when a hold starts/stops (a revive pauses the bleed-out while it's held).
func _set_hold_node(n: Interactable) -> void:
	if n == _hold_node:
		return
	if _hold_node != null and is_instance_valid(_hold_node):
		_hold_node.hold_changed(self, false)
	_hold_node = n
	if n != null:
		n.hold_changed(self, true)


func _probe_interactable() -> Interactable:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * INTERACT_RANGE, MASK_INTERACT, [get_rid()])
	q.collide_with_areas = true
	var res: Dictionary = space.intersect_ray(q)
	if res.is_empty():
		return null
	var col: Node = res["collider"] as Node
	if col is Area3D and col.get_parent() is Interactable:
		return col.get_parent() as Interactable
	return null


func _update_camera(delta: float) -> void:
	# Recoil: a critically damped spring pulls the kicked view back (the share of each kick that stays
	# in _pitch is the part you pull down yourself).
	var steps: int = 1 if delta <= 1.0 / 50.0 else 2
	var dt: float = delta / float(steps)
	for i: int in steps:
		_rk_v += (-_rk * _rk_w * _rk_w - _rk_v * 2.0 * _rk_w) * dt
		_rk += _rk_v * dt
	var S: Dictionary = _cfg.get("slide", {})
	var dip: float = _slide_k * float(S.get("cam_dip", 0.22)) * (0.75 + 0.25 * sin(_shake_t * 0.9))
	head.position.y = _eye - dip
	head.rotation.x = _pitch + _rk.x
	head.rotation.y = _rk.y
	# lean (and the slide's roll: the body leans into the slide direction)
	var lean_in: float = 0.0
	if bool(GLSettings.values.get("lean_enabled", true)):
		lean_in = Input.get_action_strength(&"lean_right") - Input.get_action_strength(&"lean_left")
	_lean = move_toward(_lean, lean_in, delta * 5.0)
	head.position.x = _lean * 0.35
	var side: float = 0.0
	if _slide_k > 0.001:
		side = global_basis.x.dot(_slide_dir)                      # +1 sliding to the right
	camera.rotation.z = -_lean * 0.12 - _slide_k * (deg_to_rad(float(S.get("cam_tilt_deg", 3.5))) * (0.6 + 0.4 * side))
	# shake (smooth pseudo-noise rather than per-frame white noise, scaled by the Screen Shake setting)
	_shake = maxf(0.0, _shake - delta * 1.8)
	_shake_t += delta * 38.0
	var sk: float = _shake * 0.05 * shake_setting()
	camera.h_offset = (sin(_shake_t * 1.13) + sin(_shake_t * 2.71) * 0.5) * 0.67 * sk
	camera.v_offset = (sin(_shake_t * 1.37 + 1.9) + sin(_shake_t * 3.07) * 0.5) * 0.67 * sk
	# fov (+ a short punch on heavy shots)
	_fov_punch = move_toward(_fov_punch, 0.0, delta * maxf(8.0, absf(_fov_punch) * 14.0))
	var fov: float = GLSettings.get_f("fov") * weapons.fov_mult()
	if sprinting:
		fov *= 1.06
	fov *= lerpf(1.0, float(S.get("fov_mult", 1.09)), _slide_k)
	if _fov_base <= 0.0:
		_fov_base = camera.fov
	_fov_base = lerpf(_fov_base, fov, clampf(delta * 12.0, 0.0, 1.0))
	camera.fov = _fov_base + _fov_punch


# ---------------------------------------------------------------- API used by weapons / zombies / world

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Generic kick (explosive alt-fires, the Totenglocke ring). Weapons use kick_camera() with data values.
func add_recoil(degrees: float) -> void:
	kick_camera(degrees * 0.8, degrees * 0.2, 0.35, 10.0, degrees * 0.04, degrees * 0.4)


## One shot's camera recoil: `pitch_deg` up and a random +-`yaw_deg`; `keep` of it stays in the aim
## (you pull it down), the rest springs back at angular frequency `recover`. Shake and FOV punch are
## scaled by the Screen Shake setting.
func kick_camera(pitch_deg: float, yaw_deg: float, keep: float, recover: float, shake: float, fov_punch: float) -> void:
	var p: float = deg_to_rad(pitch_deg)
	var y: float = deg_to_rad(yaw_deg) * randf_range(-1.0, 1.0)
	_pitch = clampf(_pitch + p * keep, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotate_y(-y * keep)
	_rk_w = maxf(3.0, recover)
	# Velocity impulse that peaks at about the remaining kick for a critically damped spring (peak = v/(w*e)).
	_rk_v += Vector2(p, -y) * (1.0 - keep) * _rk_w * 2.72
	var sk: float = shake_setting()
	_shake = maxf(_shake, shake)
	_fov_punch = maxf(_fov_punch, fov_punch * sk)


func shake_setting() -> float:
	return clampf(float(GLSettings.values.get("screen_shake", 1.0)), 0.0, 1.5)


## Footstep cadence as a continuous phase: the integer part counts footsteps, so sin(PI * phase) crosses
## zero on every footfall (the viewmodel bob dips there).
func step_phase() -> float:
	var stride: float = STRIDE * (1.25 if sprinting else (0.8 if crouching else 1.0))
	return float(_step_count) + clampf(_step_dist / stride, 0.0, 1.0)


func reload_mult() -> float:
	return float(PerkManager.stat(player_id, "reload_time_mult", 1.0))


func has_explosive_immunity() -> bool:
	return bool(PerkManager.stat(player_id, "self_explosive_immune", false))


func _on_perks_changed(pid: int) -> void:
	if pid != player_id:
		return
	var new_max: float = float(PerkManager.stat(player_id, "max_health", float(_cfg["max_health"])))
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	hp = minf(hp, max_hp)
	weapons.enforce_slot_limit()


func lunge_toward(target: Vector3, distance: float) -> void:
	if distance <= 0.1:
		return
	var d: Vector3 = target - global_position
	d.y = 0.0
	_lunge_t = 0.15
	_lunge_vel = d.normalized() * (distance / 0.15)


func is_alive() -> bool:
	return not downed


func take_hit(amount: float, _source: Node) -> void:
	if downed or spectating or GameState.phase != GameState.Phase.PLAYING:
		return
	if not is_local and not is_bot:
		_forward(&"hit", [amount])   # the owner applies it (their health is theirs, D-065)
		return
	if GameState.god_mode and is_local:
		GLBus.player_damaged.emit(player_id, 0.0)
		return
	if is_bot:
		amount *= bot_damage_mult
	hp -= amount
	_since_hit = 0.0
	_shake = maxf(_shake, 0.35)
	if is_bot:
		AudioDirector.play_3d("player_hurt", global_position + Vector3.UP * 1.3, -6.0)
	else:
		AudioDirector.play_2d("player_hurt", -2.0)
	GLBus.player_damaged.emit(player_id, amount)
	if hp <= 0.0:
		hp = 0.0
		down()


func down() -> void:
	if downed:
		return
	if not is_local and not is_bot:
		_forward(&"down", [])
		return
	downed = true
	sprinting = false
	sliding = false
	_slide_k = 0.0
	velocity = Vector3.ZERO
	_set_heartbeat(false)
	_hold_t = 0.0
	interact_progress = 0.0
	_set_hold_node(null)
	if not GameState.is_solo():
		_enter_last_stand()
	else:
		var tw: Tween = create_tween()
		tw.tween_property(head, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(camera, "rotation:z", 0.5, 0.6)
	if Net.is_client():
		if Net.session != null:
			Net.session.report_downed()   # the host decides, then relays player_downed to everyone
	else:
		GLBus.player_downed.emit(player_id)


## Co-op last stand: crawl, keep shooting with a pistol, wait for a teammate (GDD §3).
func _enter_last_stand() -> void:
	last_stand = true
	crouching = false
	weapons.enter_last_stand()
	if is_bot:
		AudioDirector.play_3d("player_hurt", global_position + Vector3.UP, -2.0, 0.0)
	else:
		AudioDirector.play_2d("player_hurt", 0.0, 0.0)


func _last_stand_tick(delta: float) -> void:
	var dcfg: Dictionary = _cfg.get("downed", {})
	_eye = move_toward(_eye, float(dcfg.get("eye_height", 0.45)), delta * 2.0)
	_set_crouch_shape(true)
	var input: Vector2 = Vector2.ZERO
	if not GameState.input_blocked:
		_pad_look(delta)
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
	var wish: Vector3 = global_basis * Vector3(input.x, 0, input.y)
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var spd: float = float(dcfg.get("crawl_speed", 0.9))
	velocity.x = wish.x * spd
	velocity.z = wish.z * spd
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	for e: Variant in _status.keys():
		_status[e] = maxf(0.0, float(_status[e]) - delta)
	if GameState.input_blocked:
		_update_camera(delta)
		return
	var intent: Dictionary = _gather_intent()
	for k: String in ["melee", "lethal_held", "tactical", "swap", "alt_fire"]:
		intent[k] = false
	intent["slot"] = -1
	intent["sprinting"] = false
	weapons.tick(delta, intent)
	_update_camera(delta)
func health_fraction() -> float:
	return hp / max_hp


## Second Wind (solo): lie downed for `seconds`, then get up at full health with nearby zombies knocked back.
func begin_self_revive(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(_finish_self_revive)


func _finish_self_revive() -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if z.global_position.distance_to(global_position) < 4.0:
				z.take_damage(0.0, &"torso", &"second_wind", 0, &"melee")
	revive(player_id)


func revive(by_player: int) -> void:
	if not downed:
		return
	_get_up()
	# A client's revive was decided (and announced) by the host; offline / host-local it's announced here.
	if not Net.is_client():
		GLBus.player_revived.emit(player_id, by_player)


func _get_up() -> void:
	downed = false
	hp = max_hp
	_since_hit = 99.0
	if last_stand:
		last_stand = false
		weapons.exit_last_stand()
		_eye = EYE_CROUCH
		crouching = true   # stands up out of the crawl next frame (or stays crouched under a low roof)
		return
	var tw: Tween = create_tween()
	tw.tween_property(head, "position:y", _eye, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(camera, "rotation:z", 0.0, 0.5)


## Co-op: the bleed-out timer ran out. Everything is lost; watch a teammate until the next round.
func bleed_out() -> void:
	if spectating:
		return
	downed = true
	last_stand = false
	spectating = true
	velocity = Vector3.ZERO
	weapons.clear_for_spectate()
	collision_layer = 0
	_set_heartbeat(false)


## Co-op: back in at the start of a round with the starting loadout (GDD §3).
func respawn_at(xf: Transform3D) -> void:
	spectating = false
	downed = false
	last_stand = false
	collision_layer = LAYER_PLAYER
	global_transform = xf
	velocity = Vector3.ZERO
	max_hp = float(PerkManager.stat(player_id, "max_health", float(_cfg["max_health"])))
	hp = max_hp
	_since_hit = 99.0
	_status.clear()
	_eye = EYE_STAND
	crouching = false
	camera.rotation.z = 0.0
	weapons.reset_loadout()
	if is_local:
		camera.current = true


## Host -> owner: a call that has to run on the player's own machine (see take_hit / apply_status).
func _forward(op: StringName, args: Array) -> void:
	if Net.session != null:
		Net.session.send_player_op(player_id, op, args)


# ---------------------------------------------------------------- remote (puppet) update

func _remote_tick(delta: float) -> void:
	if interp == null or not interp.sample(Net.session.render_time_ms() if Net.session != null else float(Time.get_ticks_msec())):
		return
	var prev: Vector3 = global_position
	global_position = interp.pos
	rotation.y = interp.yaw
	head.rotation.x = interp.pitch
	net_flags = interp.flags
	var crouched: bool = (net_flags & NetMatch.PF_CROUCH) != 0
	head.position.y = EYE_CROUCH if crouched else EYE_STAND
	velocity = (global_position - prev) / maxf(delta, 0.0001)
	if not Net.is_host():
		downed = (net_flags & (NetMatch.PF_DOWNED | NetMatch.PF_SPECTATE)) != 0
	spectating = (net_flags & NetMatch.PF_SPECTATE) != 0
	collision_layer = 0 if spectating else LAYER_PLAYER
	if remote_body != null:
		remote_body.update_pose(delta, Vector2(velocity.x, velocity.z).length(), interp.pitch, net_flags)


## Remote: one shot/use seen on the owner's machine (muzzle flash, 3D sound, tracer).
func remote_fire(kind: int, weapon_id: StringName, origin: Vector3, end: Vector3) -> void:
	if remote_body != null:
		remote_body.fire(kind, weapon_id, origin, end)


func flash_prompt_denied() -> void:
	if not is_local:
		if not is_bot:
			_forward(&"deny", [])
		return
	prompt_denied.emit()


func _on_explosion(pos: Vector3, radius: float) -> void:
	var d: float = global_position.distance_to(pos)
	if d < radius * 3.0:
		_shake = maxf(_shake, lerpf(0.9, 0.1, d / (radius * 3.0)))
