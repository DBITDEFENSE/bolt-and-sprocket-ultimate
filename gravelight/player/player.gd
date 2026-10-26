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
const MASK_MOVE: int = 1 | (1 << 2) | (1 << 5) | (1 << 8) | (1 << 10)   # world, zombie bodies, barricades, doors, the map's edge (T-084: shots pass it, bodies don't)
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
const HAY_HINTS: PackedStringArray = ["bale", "straw", "hayloft", "haypile"]
## Ground under one of these roofs is straw-strewn (the Map 0 stable): see _floor_surface().
const HAY_ROOF_HINTS: PackedStringArray = ["stbroof", "hayloft"]
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
var bleedout_seconds: float = 0.0  # > 0: this player's own co-op bleed-out clock (a companion; 0 = player.json)
## A companion (Jakub, U02 section 6.2): a bot-style Player that is no match player (no id in GameState.player_ids,
## no slot, no scaling, no perks). It always goes into last stand when downed (even in solo) and never keeps a
## solo match alive on its own (MapRoot._on_player_downed).
var is_companion: bool = false
## Player bot mode (T-071, gravelight/bots/player_bot.gd): the local human's survivor driven by a BotBrain while
## they watch. Movement, aim and firing come from the brain (drive_bot, bot_view_tick); the local input is not read.
var bot_driven: bool = false

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
# UPDATE 07 (T-105): outside pushes (turbulence, a breach's suction, the Bordwart's pull, the Lodestone) and
# Skyhook Sekt's air hop / stomp.
var _push_v: Vector3 = Vector3.ZERO
var _push_t: float = 0.0
var _hops_left: int = 0
var _did_hop: bool = false
var _stomp_cd: float = 0.0
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

# Update 02 §1 feel (numbers: data/gravelight/movement.json, see _mv)
var prone: bool = false
var mantling: bool = false
var mantles: int = 0                     # mantles / vaults started this match (tools)
var _mv: Dictionary = {}
var _sprint_toggled: bool = false        # Toggle sprint mode: on until cancelled / you stop moving forward
var _sprint_block: float = 0.0           # fire / ADS cancelled the sprint: Hold mode resumes when this runs out
var _fire_override: bool = false         # sprint pressed while fire / ADS was held: those no longer cancel it until released
var _sprint_k: float = 0.0               # eased 0..1 sprint blend (FOV kick, head bob)
var _crouch_hold_t: float = -1.0         # seconds crouch has been held toward prone (< 0: not counting)
var _crouch_release_stands: bool = false # prone setting: a crouched tap stands up on release (a hold goes prone)
var _air_cap: float = 0.0                # horizontal speed allowed while airborne (no bunny-hop gain)
var _floor_y: float = 0.0                # feet height on the last floor (mantle reach in the air)
var _roll: float = 0.0                   # strafe roll (radians)
var _bob_k: float = 0.0
var _land_dip: float = 0.0               # head dip on landing (spring)
var _land_dip_v: float = 0.0
var _punch_roll: float = 0.0             # damage punch roll (decays)
var ext_roll_deg: float = 0.0            # UPDATE 07: the Kranich banks (FlightController sets it; eased in the camera tick)
var _ext_roll: float = 0.0
var _slide_dur: float = 1.0
var _slide_v0: float = 1.0
var _mantle_t: float = 0.0
var _mantle_pts: PackedVector3Array = []  # rise, across, (drop) waypoints of the current mantle
var _mantle_exit: Vector3 = Vector3.ZERO
var _mantle_vault: bool = false
var _mantle_from: Vector3 = Vector3.ZERO
var _mantle_buffer: float = 0.0
var _mantle_air: bool = false            # airborne from a jump: moving forward into a ledge still catches it
var _rc_pool: Vector2 = Vector2.ZERO     # recoil pattern still to recover (pitch, yaw) radians
var _rc_recover: float = 8.0
var _rc_delay: float = 0.1
var _rc_since: float = 99.0
## Update 03 section 3 (T-056): the movement code reads this, not Input. The local human fills it from Input
## each frame (_read_move_intent); a bot's BotLocomotion passes its own to drive_bot().
var _mi: MoveIntent = MoveIntent.new()


func _ready() -> void:
	if not is_local:
		_ready_remote()
		return
	_cfg = GLData.table("player")
	_mv = GLData.table("movement")
	add_to_group(&"players")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_MOVE
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	max_hp = float(_cfg["max_health"])
	hp = max_hp
	_stamina = float(_cfg["sprint_duration"]) * Muster.mult(player_id, "sprint_duration_mult")   # Long March (T-079)
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
	_mv = GLData.table("movement")
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
	if not is_local or bot_driven or (downed and not last_stand) or spectating or GameState.phase != GameState.Phase.PLAYING or GameState.input_blocked:
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
	if sprinting:
		rel *= float(_mv.get("sprint_turn_mult", 1.0))   # a little heavier to turn at a run
	rotate_y(-rel.x)
	var inv: float = -1.0 if bool(GLSettings.values.get("invert_y", false)) else 1.0
	var before: float = _pitch
	_pitch = clampf(_pitch - rel.y * inv, deg_to_rad(-88.0), deg_to_rad(88.0))
	if _pitch < before and _rc_pool.x > 0.0:
		_rc_pool.x = maxf(0.0, _rc_pool.x - (before - _pitch))   # pulling down already paid back that much recoil


func _pad_look(delta: float) -> void:
	var v: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.15)
	if v.length_squared() < 0.0001 or BotCommandWheel.capturing:
		return   # (the squad command wheel uses the stick while it is open)
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
		"fire_block": mantling or (sliding and not slide_fire_ok()),   # mantle / first half of a slide: fire is buffered
		"mantle": mantling,
	}
	_look_delta = Vector2.ZERO
	return intent


# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if _push_t > 0.0:
		_push_t -= delta   # every body, bots included (their adapter adds push_velocity())
	_stomp_cd = maxf(0.0, _stomp_cd - delta)
	if not is_local:
		if not is_bot:
			_remote_tick(delta)   # a bot's BotBrain moves it
		return
	if bot_driven:
		return   # T-071: the brain moves, aims and fires this body, then calls bot_view_tick (camera, viewmodel)
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


## The local human's movement intent, from the input actions (the same reads the movement code made before T-056).
func _read_move_intent(mi: MoveIntent) -> void:
	mi.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
	mi.jump_pressed = Input.is_action_just_pressed(&"jump")
	mi.jump_held = Input.is_action_pressed(&"jump")
	mi.sprint_pressed = Input.is_action_just_pressed(&"sprint")
	mi.sprint_held = Input.is_action_pressed(&"sprint")
	mi.crouch_pressed = Input.is_action_just_pressed(&"crouch")
	mi.crouch_held = Input.is_action_pressed(&"crouch")
	mi.fire_pressed = Input.is_action_just_pressed(&"fire")
	mi.fire_held = Input.is_action_pressed(&"fire")
	mi.ads_held = Input.is_action_pressed(&"ads")


## A bot's body (BotLocomotion): one physics frame of the shared movement code driven by `intent` instead of
## Input. The caller turns the body (rotation.y) first; `intent.move` is in the body's frame. Bots have no
## camera update, so the head height follows the stance here.
func drive_bot(delta: float, intent: MoveIntent) -> void:
	if not (is_bot or bot_driven) or downed or spectating:
		return
	_mi = intent
	_update_movement(delta)
	if not is_local:
		head.position.y = _eye   # (the local player's camera update places the head: bot_view_tick)


## Player bot mode (T-071): the rest of the local player's frame once the brain has moved and turned the body:
## the aim the brain left on the head becomes the view pitch, the viewmodel follows the brain's gun, the camera
## (bob, recoil springs, FOV) updates. Called by BotBrain at the end of its physics frame.
func bot_view_tick(delta: float, reloading: bool, reload_left: float, ads: bool = false) -> void:
	if not is_local or not bot_driven:
		return
	_pitch = clampf(head.rotation.x - _rk.x + mantle_k() * 0.06, deg_to_rad(-88.0), deg_to_rad(88.0))
	if GameState.phase != GameState.Phase.PLAYING or spectating:
		return
	if downed and not last_stand:
		return   # solo down: the fall tween owns the head
	interact_target = null
	interact_progress = 0.0
	prompt_text = ""
	weapons.bot_view_tick(delta, sprinting, reloading, reload_left, ads)
	_update_camera(delta)


func _update_movement(delta: float) -> void:
	if is_local and not bot_driven:
		_read_move_intent(_mi)
	var input: Vector2 = _mi.move
	var wish: Vector3 = (global_basis * Vector3(input.x, 0, input.y))
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	if noclip:
		var fly: Vector3 = (camera.global_basis * Vector3(input.x, 0, input.y)) * 12.0
		if _mi.jump_held:
			fly.y += 8.0
		global_position += fly * delta
		velocity = Vector3.ZERO
		return
	if mantling:
		_tick_mantle(delta)
		return
	var on_floor: bool = is_on_floor()
	_slide_cd = maxf(0.0, _slide_cd - delta)
	var S: Dictionary = _cfg.get("slide", {})
	_update_stance_input(delta, wish, on_floor, S)
	# mantle / vault: jump facing a waist-high ledge; a jump pressed a little early still catches the ledge
	# (mantle_buffer s while moving forward), and so does holding jump into one while airborne
	var jump_pressed: bool = _mi.jump_pressed
	_mantle_buffer = float((_mv.get("mantle", {}) as Dictionary).get("buffer", 0.35)) if jump_pressed else maxf(0.0, _mantle_buffer - delta)
	var forward: bool = input.y < -0.3
	if jump_pressed:
		_mantle_air = true                    # this jump may catch a ledge on the way (cleared on landing)
	if not sliding and not prone and (jump_pressed or (forward and (_mantle_buffer > 0.0 or (not on_floor and (_mantle_air or _mi.jump_held))))):
		if _try_mantle():
			return
	if jump_pressed and sliding and on_floor:
		_slide_jump()
	elif jump_pressed and prone:
		_set_prone(false)
		jump_pressed = false
	elif jump_pressed and crouching and not sliding:
		crouching = false
	_update_sprint(delta, input, on_floor)
	var target_speed: float = float(_cfg["walk_speed"])
	if prone:
		target_speed = float((_mv.get("prone", {}) as Dictionary).get("speed", 1.1))
	elif sprinting:
		target_speed = float(_cfg["sprint_speed"])
	elif crouching:
		target_speed = float(_cfg["crouch_speed"])
	target_speed *= weapons.move_mult() * lerpf(1.0, weapons.ads_move_mult(), weapons.ads_t) * float(PerkManager.stat(player_id, "move_speed_mult", 1.0))
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
	elif on_floor:
		# acceleration curves: ~accel_time to full speed whatever the target, a short slide to a stop
		var walk: float = float(_cfg["walk_speed"])
		var rate: float
		if wish.length_squared() < 0.0001:
			rate = maxf(walk, horizontal.length()) / maxf(0.02, float(_mv.get("decel_time", 0.17)))
		else:
			rate = maxf(target_speed, horizontal.length()) / maxf(0.02, float(_mv.get("accel_time", 0.12)))
		horizontal = horizontal.move_toward(wish * target_speed, rate * delta)
	else:
		# air control: weak, and never faster than you left the ground (no bunny-hop gain)
		horizontal = horizontal.move_toward(wish * target_speed, float(_mv.get("air_accel", 5.0)) * float(PerkManager.stat(player_id, "air_accel_mult", 1.0)) * delta)
		var cap: float = maxf(_air_cap, target_speed) * float(_mv.get("air_speed_cap_mult", 1.0))
		if horizontal.length() > cap:
			horizontal = horizontal.limit_length(cap)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if on_floor:
		if jump_pressed and not crouching and not prone and velocity.y <= 0.0:
			velocity.y = float(_cfg["jump_velocity"])
			_air_cap = horizontal_speed()
			weapons.on_jump()
			GLBus.player_jumped.emit(player_id, global_position)
		elif velocity.y < 0.0:
			velocity.y = -0.5
	else:
		# Skyhook Sekt: one more jump in the air (air_hops), a smaller one, reset on landing (tier II: on a slide too)
		if jump_pressed and _hops_left > 0 and not sliding and not prone and not _mantle_air_catching():
			_hops_left -= 1
			_did_hop = true
			velocity.y = float(_cfg["jump_velocity"]) * float(PerkManager.stat(player_id, "air_hop_mult", 0.6))
			_air_cap = maxf(_air_cap, horizontal_speed())
			weapons.on_jump()
			AudioDirector.play_2d("perk_skyhook_hop", -6.0, 0.1)
			GLBus.player_jumped.emit(player_id, global_position)
			PerkManager.note_proc(player_id, &"skyhook_sekt", &"hop")
		velocity.y -= GRAVITY * delta
	_update_stance_shape(delta)
	_slide_k = move_toward(_slide_k, 1.0 if sliding else 0.0, delta * (9.0 if sliding else 5.0))
	var fall_speed: float = -velocity.y
	if _push_t > 0.0:
		velocity += _push_v
	move_and_slide()
	if not _was_on_floor and is_on_floor():
		_on_landed(fall_speed)
	if is_on_floor():
		_air_cap = horizontal_speed()
		_floor_y = global_position.y
		if not jump_pressed:
			_mantle_air = false
	_was_on_floor = is_on_floor()
	if is_on_floor() and not sliding:
		_step_dist += Vector2(velocity.x, velocity.z).length() * delta
		var stride: float = _stride()
		if _step_dist >= stride:
			_step_dist = 0.0
			_step_count += 1
			_footstep(_gait_db())
	else:
		_step_dist = minf(_step_dist, STRIDE * 0.7)


## Crouch / prone / slide input. Crouch toggles; crouch while sprinting (or carrying sprint speed) drops into a
## slide; crouch again during one cancels it; jump out of it is a slide-jump that keeps the speed. With the Prone
## setting on, holding crouch goes prone (a tap while crouched stands up on release), crouch or jump gets up.
func _update_stance_input(delta: float, wish: Vector3, on_floor: bool, S: Dictionary) -> void:
	var prone_on: bool = is_local and bool(GLSettings.values.get("prone_enabled", false))   # (bots never go prone)
	if prone and not prone_on:
		_set_prone(false)
	if _mi.crouch_pressed:
		_crouch_hold_t = 0.0
		var fast: bool = horizontal_speed() >= float(S.get("min_sprint_speed", 4.0))
		if prone:
			_set_prone(false)
			_crouch_hold_t = -1.0
		elif sliding:
			_end_slide(false)
			_crouch_hold_t = -1.0
		elif (sprinting or (fast and sprint_held())) and on_floor and _slide_cd <= 0.0:
			_start_slide(wish)
			_crouch_hold_t = -1.0
		elif crouching and prone_on:
			_crouch_release_stands = true      # decided on release: a tap stands, a hold goes prone
		else:
			crouching = not crouching
	if prone_on and _crouch_hold_t >= 0.0 and _mi.crouch_held and not sliding and not prone and on_floor:
		_crouch_hold_t += delta
		if _crouch_hold_t >= float((_mv.get("prone", {}) as Dictionary).get("hold", 0.45)):
			_crouch_hold_t = -1.0
			_crouch_release_stands = false
			_set_prone(true)
	if not _mi.crouch_held:
		_crouch_hold_t = -1.0
		if _crouch_release_stands:
			_crouch_release_stands = false
			crouching = false


func _set_prone(on: bool) -> void:
	if on == prone:
		return
	prone = on
	crouching = true          # prone counts as crouched for everything else (net flags, slides, sprint)
	sprinting = false
	_sprint_toggled = false
	if on:
		_footstep(-8.0)


## True while the sprint input is on: the key held (Hold mode) or toggled on (Toggle mode).
func sprint_held() -> bool:
	if is_local and str(GLSettings.values.get("sprint_mode", "hold")) == "toggle":
		return _sprint_toggled
	return _mi.sprint_held


## Sprint: forward-ish only. Fire or ADS input cancels it at once (the gun's sprint-out runs and the shot is
## buffered, see WeaponHolder); Hold mode comes back once they are released, Toggle mode needs a new press.
## Pressing sprint while firing / aiming wins until those are let go.
func _update_sprint(delta: float, input: Vector2, on_floor: bool) -> void:
	var toggle_mode: bool = is_local and str(GLSettings.values.get("sprint_mode", "hold")) == "toggle"
	var fire_in: bool = _mi.fire_held
	var ads_in: bool = _mi.ads_held and not _status_flag("no_ads")
	if not fire_in and not ads_in:
		_fire_override = false
	if _mi.sprint_pressed:
		if toggle_mode:
			_sprint_toggled = not (_sprint_toggled or sprinting)
		_sprint_block = 0.0
		if fire_in or ads_in:
			_fire_override = true
	if toggle_mode and (input.y > -0.3 or crouching or prone) and not sliding:
		_sprint_toggled = false
	var cancel: bool = (not _fire_override and (_mi.fire_pressed or fire_in or ads_in)) or weapons.fire_pending()
	if cancel:
		if toggle_mode and (sprinting or _sprint_toggled) and not weapons.fire_pending():
			_sprint_toggled = false
		_sprint_block = float(_mv.get("sprint_resume_delay", 0.25))
	else:
		_sprint_block = maxf(0.0, _sprint_block - delta)
	var unlimited: bool = bool(PerkManager.stat(player_id, "unlimited_sprint", false))
	var wants_sprint: bool = sprint_held() and input.y < -0.3 and not crouching and not prone and not cancel and _sprint_block <= 0.0
	if wants_sprint and (_stamina > 0.0 or unlimited) and on_floor or (sprinting and not on_floor and wants_sprint):
		sprinting = true
		if not unlimited:
			_stamina = maxf(0.0, _stamina - delta)
		_stamina_wait = float(_cfg["sprint_recharge_delay"])
	else:
		sprinting = false
		_stamina_wait = maxf(0.0, _stamina_wait - delta)
		if _stamina_wait <= 0.0:
			_stamina = minf(float(_cfg["sprint_duration"]) * Muster.mult(player_id, "sprint_duration_mult"), _stamina + delta * 1.5)


## Landing: the fall height sets the camera shake and head dip; speed above the target is partly lost (no
## bunny-hop gain from chained jumps).
func _on_landed(fall_speed: float) -> void:
	var J: Dictionary = _mv.get("jump", {})
	var h: float = fall_speed * fall_speed / (2.0 * GRAVITY)
	var safe: bool = bool(PerkManager.stat(player_id, "safe_landing", false))   # Skyhook Sekt (T-105)
	var shake_mult: float = float(PerkManager.stat(player_id, "landing_shake_mult", 1.0)) if safe else 1.0
	_shake = maxf(_shake, clampf((h - float(J.get("shake_from_m", 0.25))) * float(J.get("shake_per_m", 0.22)), 0.0, float(J.get("shake_max", 0.7))) * shake_mult)
	if not safe:
		_land_dip_v -= minf(float(J.get("land_head_dip_max", 0.12)), maxf(0.0, fall_speed - 1.5) * float(J.get("land_head_dip", 0.012))) * 30.0
	_footstep(-2.0 + clampf(h - 0.5, 0.0, 4.0) - (4.0 if safe else 0.0))
	weapons.on_landed(fall_speed * (0.4 if safe else 1.0))
	if not sliding and not safe:
		var hv: Vector2 = Vector2(velocity.x, velocity.z)
		var walk: float = float(_cfg["sprint_speed"] if sprinting else _cfg["walk_speed"])
		if hv.length() > walk:
			var keep: float = walk + (hv.length() - walk) * (1.0 - float(_mv.get("land_speed_loss", 0.35)))
			hv = hv.limit_length(keep)
			velocity.x = hv.x
			velocity.z = hv.y
	_hops_left = int(PerkManager.stat(player_id, "air_hops", 0))
	if safe and bool(PerkManager.stat(player_id, "instant_sprint_out_on_land", false)):
		weapons.instant_sprint_out()
	if _did_hop:
		_did_hop = false
		if bool(PerkManager.stat(player_id, "hop_stomp", false)) and _stomp_cd <= 0.0:
			_stomp_cd = float(PerkManager.stat(player_id, "hop_stomp_cooldown", 1.5))
			PerkManager.hop_stomp(self)


func _stride() -> float:
	return STRIDE * (float((_mv.get("footsteps", {}) as Dictionary).get("sprint_stride_mult", 1.25)) if sprinting else (0.8 if crouching else 1.0))


## Footstep volume by gait (movement.json footsteps): sprinting is louder, crouching / prone quieter.
func _gait_db() -> float:
	var F: Dictionary = _mv.get("footsteps", {})
	if prone:
		return float(F.get("prone_db", -9.0))
	if crouching:
		return float(F.get("crouch_db", -6.0))
	if sprinting:
		return float(F.get("sprint_db", 4.0))
	return float(F.get("walk_db", 0.0))


# ---------------------------------------------------------------- mantle / vault

## Tries to start a mantle or vault over what is in front (movement.json "mantle"). Returns true if one started.
func _try_mantle() -> bool:
	var plan: Dictionary = probe_mantle()
	if plan.is_empty():
		return false
	var M: Dictionary = _mv.get("mantle", {})
	_mantle_buffer = 0.0
	mantling = true
	mantles += 1
	sprinting = false
	crouching = false
	_mantle_t = 0.0
	_mantle_from = global_position
	_mantle_pts = plan["points"]
	_mantle_vault = bool(plan["vault"])
	var fwd: Vector3 = plan["dir"]
	_mantle_exit = fwd * maxf(float(M.get("exit_speed", 3.2)), minf(horizontal_speed(), float(_cfg["walk_speed"])))
	velocity = Vector3.ZERO
	weapons.on_landed(3.5)                 # the gun dips as the hands go to the ledge
	_shake = maxf(_shake, 0.06)
	_footstep(-4.0)
	return true


## Where a mantle / vault in front would go, or {} if there is none. Thin obstacles (the far side drops back down
## within vault_depth) are vaulted, deeper ones climbed onto. The path (rise, across, drop) is swept with a
## crouched capsule so it can never end inside geometry; barricade windows, doors, no_mantle colliders, spots off
## the navmesh, outside every zone or in a closed zone, and anything without a floor under it are refused.
## Returns {"points": [rise, across, land], "vault": bool, "dir": Vector3, "top": float}.
func probe_mantle() -> Dictionary:
	var M: Dictionary = _mv.get("mantle", {})
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return {}
	fwd = fwd.normalized()
	var feet: Vector3 = global_position
	var ref_y: float = feet.y if is_on_floor() else minf(feet.y, _floor_y)   # airborne: still measured from the floor
	var radius: float = _capsule.radius
	var block_mask: int = MASK_MOVE & ~(1 << 2)      # world, barricades, doors (zombies are checked by the sweep)
	var hit: Dictionary = {}
	for h: float in [0.35, 0.7, 1.05, 1.25]:
		# measured from the floor you left, so a ledge is still found on the way up a jump
		var from: Vector3 = Vector3(feet.x, ref_y + h, feet.z)
		if from.y < feet.y + 0.05:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + fwd * (radius + float(M.get("reach", 0.75))), block_mask, [get_rid()])
		hit = space.intersect_ray(q)
		if not hit.is_empty():
			break
	if hit.is_empty() or _no_mantle(hit["collider"] as Object):
		return {}
	var n: Vector3 = hit["normal"]
	if absf(n.y) > 0.4:
		return {}                                   # a ramp or step face, not a wall
	var into: Vector3 = Vector3(-n.x, 0.0, -n.z).normalized()
	if into.dot(fwd) < 0.6:
		return {}                                   # too glancing
	var face: Vector3 = hit["position"]
	var min_h: float = float(M.get("min_h", 0.5))
	var max_h: float = float(M.get("max_h", 1.3))
	var tp: Vector3 = face + into * 0.18
	var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(tp.x, ref_y + max_h + 0.5, tp.z), Vector3(tp.x, ref_y + min_h - 0.2, tp.z), block_mask, [get_rid()])
	var top: Dictionary = space.intersect_ray(q2)
	if top.is_empty() or (top["normal"] as Vector3).y < 0.7 or _no_mantle(top["collider"] as Object):
		return {}
	var top_y: float = (top["position"] as Vector3).y
	if top_y - ref_y < min_h or top_y - ref_y > max_h or top_y < feet.y + 0.1:
		return {}
	# vault or climb: does the top end within vault_depth (the far side drops back toward the floor)?
	var vault: bool = false
	var land: Vector3 = Vector3.ZERO
	var depth: float = float(M.get("vault_depth", 0.9))
	var d: float = 0.3
	while d <= depth + 0.001:
		var p: Vector3 = face + into * d
		var qd: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, top_y + 0.3, p.z), Vector3(p.x, top_y - 0.35, p.z), block_mask, [get_rid()])
		if space.intersect_ray(qd).is_empty():
			vault = true
			land = face + into * (d + radius + 0.08)
			break
		d += 0.15
	if vault:
		var ql: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(land.x, top_y + 0.3, land.z), Vector3(land.x, ref_y - 1.6, land.z), block_mask, [get_rid()])
		var lh: Dictionary = space.intersect_ray(ql)
		if lh.is_empty() or (lh["normal"] as Vector3).y < 0.7:
			return {}                               # nothing to land on (a drop off the map)
		land.y = (lh["position"] as Vector3).y
	else:
		land = face + into * (radius + 0.12)
		land.y = top_y
	var rise: Vector3 = Vector3(feet.x, top_y + 0.04, feet.z)
	var across: Vector3 = Vector3(land.x, top_y + 0.04, land.z)
	land.y += 0.02
	# the path, swept with a crouched capsule a hair slimmer than ours, and the end spot itself
	for seg: Array in [[feet + Vector3.UP * 0.04, rise], [rise, across], [across, land]]:
		if not _sweep_clear(seg[0] as Vector3, seg[1] as Vector3, radius - 0.02):
			return {}
	if not _spot_clear(land, radius):
		return {}
	if not _mantle_spot_allowed(feet, land, float(M.get("nav_tolerance", 1.2)), float(M.get("barricade_clear", 1.6))):
		return {}
	return {"points": PackedVector3Array([rise, across, land]), "vault": vault, "dir": into, "top": top_y}


func _no_mantle(col: Object) -> bool:
	var n: Node = col as Node
	if n == null:
		return true
	if n is CollisionObject3D and ((n as CollisionObject3D).collision_layer & (Barricade.LAYER_BARRICADE | (1 << 8))) != 0:
		return true                                 # zombie windows and doors are never exits
	for m: Node in [n, n.get_parent()]:
		if m != null and (m.has_meta("no_mantle") or m is Barricade or m is BuyDoor):
			return true
	return false


## A crouched capsule (feet at `a`) moved to `b` hits nothing that blocks the player (zombies included).
func _sweep_clear(a: Vector3, b: Vector3, r: float) -> bool:
	if a.distance_squared_to(b) < 0.0001:
		return true
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = r
	shape.height = CROUCH_HEIGHT
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MASK_MOVE
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis(), a + Vector3.UP * (CROUCH_HEIGHT * 0.5))
	q.motion = b - a
	var res: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(q)
	return res.size() >= 1 and res[0] >= 0.999


## Room for a crouched capsule standing at `p`.
func _spot_clear(p: Vector3, r: float) -> bool:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = r
	shape.height = CROUCH_HEIGHT
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = MASK_MOVE
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis(), p + Vector3.UP * (CROUCH_HEIGHT * 0.5 + 0.03))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Keeps mantles inside the playable map: the landing must be on the navmesh (when the map has one), inside a
## zone volume that is open (or the one you are in), and well clear of every barricade window.
func _mantle_spot_allowed(from: Vector3, land: Vector3, nav_tol: float, bar_clear: float) -> bool:
	for b: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b3: Node3D = b as Node3D
		if b3 == null:
			continue
		var bp: Vector3 = b3.global_position
		if Vector2(bp.x - land.x, bp.z - land.z).length() < bar_clear or Vector2(bp.x - from.x, bp.z - from.z).length() < bar_clear * 0.75:
			return false
	var map_rid: RID = get_world_3d().navigation_map
	if map_rid.is_valid() and not NavigationServer3D.map_get_regions(map_rid).is_empty():
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, land)
		if Vector2(closest.x - land.x, closest.z - land.z).length() > nav_tol or absf(closest.y - land.y) > 1.0:
			return false
	if not get_tree().get_nodes_in_group(&"zone_volumes").is_empty():
		var here: StringName = ZoneVolume.zone_at(get_tree(), from + Vector3.UP * 0.2)
		var there: StringName = ZoneVolume.zone_at(get_tree(), land + Vector3.UP * 0.2)
		if there == &"" and here != &"":
			return false
		if there != here and there != &"" and not GameState.is_zone_open(there):
			return false
	return true


## 0.4 s scripted move along the planned path (rise, across, drop); the camera and gun dip with it. Ends with a
## little forward speed so a vault flows into the run.
func _tick_mantle(delta: float) -> void:
	var M: Dictionary = _mv.get("mantle", {})
	var dur: float = maxf(0.1, float(M.get("seconds", 0.4)))
	_mantle_t += delta
	var k: float = clampf(_mantle_t / dur, 0.0, 1.0)
	var pos: Vector3
	var rise_end: float = 0.4
	var across_end: float = 0.8 if _mantle_vault else 1.0
	if k < rise_end:
		var a: float = smoothstep(0.0, 1.0, k / rise_end)
		pos = _mantle_from.lerp(_mantle_pts[0], a)
		pos += (_mantle_pts[1] - _mantle_pts[0]) * 0.12 * a     # start drifting forward near the top
	elif k < across_end:
		var b: float = smoothstep(0.0, 1.0, (k - rise_end) / (across_end - rise_end))
		pos = (_mantle_pts[0] + (_mantle_pts[1] - _mantle_pts[0]) * 0.12).lerp(_mantle_pts[1], b)
	else:
		var c: float = (k - across_end) / maxf(0.01, 1.0 - across_end)
		pos = _mantle_pts[1].lerp(_mantle_pts[2], c * c)
	global_position = pos
	velocity = Vector3.ZERO
	_set_crouch_shape(true, delta)
	_slide_k = move_toward(_slide_k, 0.0, delta * 5.0)
	if k >= 1.0:
		mantling = false
		global_position = _mantle_pts[2]
		velocity = _mantle_exit
		_air_cap = _mantle_exit.length()
		_was_on_floor = false
		move_and_slide()                           # settle onto the floor; resolves any hairline contact
		_on_landed(3.0 if _mantle_vault else 1.5)


## 0 -> 1 -> 0 over a mantle (camera roll / gun dip for the holder and the camera).
func mantle_k() -> float:
	if not mantling:
		return 0.0
	var dur: float = maxf(0.1, float((_mv.get("mantle", {}) as Dictionary).get("seconds", 0.4)))
	return sin(clampf(_mantle_t / dur, 0.0, 1.0) * PI)


## One footstep on whatever is underfoot (a short ray down, only when a step lands).
func _footstep(volume_db: float) -> void:
	if not is_local:
		return   # a bot driven by drive_bot(): its RemoteBody plays teammates' footsteps in 3D
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
		var roof: Dictionary = space.intersect_ray(q)
		if roof.is_empty():
			return "snow"
		var roof_node: Node = roof.get("collider") as Node
		if roof_node != null:
			var rn: String = String(roof_node.name).to_lower()
			for h: String in HAY_ROOF_HINTS:
				if rn.contains(h):
					return "hay"      # the stable floor is strewn with straw
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
	for h: String in HAY_HINTS:
		if nm.contains(h):
			return "hay"
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
	_slide_t = float(S.get("duration", _cfg.get("slide_duration", 0.7))) * float(PerkManager.stat(player_id, "slide_duration_mult", 1.0))
	if bool(PerkManager.stat(player_id, "hop_reset_on_slide", false)):
		_hops_left = int(PerkManager.stat(player_id, "air_hops", 0))   # Skyhook II: a slide re-arms the hop
	_slide_dir = wish.normalized() if wish.length_squared() > 0.01 else -global_basis.z
	_slide_dir.y = 0.0
	_slide_dir = _slide_dir.normalized()
	_slide_speed = maxf(float(S.get("speed", _cfg.get("slide_speed", 8.5))), horizontal_speed() + 1.0) * float(PerkManager.stat(player_id, "slide_speed_mult", 1.0))
	_slide_dur = maxf(0.05, _slide_t)
	_slide_v0 = _slide_speed
	_slide_cd = float(S.get("cooldown", 0.45))
	_shake = maxf(_shake, 0.08)
	_footstep(-3.0)                                                 # the scrape as the knees hit the floor
	weapons.on_landed(2.0)                                          # a small viewmodel dip
	# Blastproof Bock: sliding releases a small concussive shockwave (no self damage).
	var shock: float = PerkManager.slide_shock_damage(player_id, float(PerkManager.stat(player_id, "slide_shockwave_damage", 0.0)))
	if shock > 0.0:
		var r: float = float(PerkManager.stat(player_id, "slide_shockwave_radius", 3.0))
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z.global_position.distance_to(global_position) <= r:
					PerkManager.slide_hit(self, z, shock)   # Blastproof III also knocks survivors down

		Effects.explosion(global_position + Vector3.UP * 0.3, r * 0.6)
		AudioDirector.play_3d("grenade_explode", global_position, -8.0, 0.2)


## The slide is over: pop back up when sprint is still held and the head is clear (COD), else stay crouched.
func _end_slide(natural: bool) -> void:
	if not sliding:
		return
	sliding = false
	var S: Dictionary = _cfg.get("slide", {})
	var stand: bool = bool(S.get("stand_up", true)) and sprint_held() and not _head_blocked()
	crouching = not stand
	if natural and not stand and _mi.crouch_held:
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
	velocity.y = float(_cfg["jump_velocity"]) + float(S.get("jump_boost", 0.6)) * float(PerkManager.stat(player_id, "slide_jump_boost_mult", 1.0))
	_slide_cd = maxf(_slide_cd, float(S.get("cooldown", 0.45)))


func is_sliding() -> bool:
	return sliding


## How far through the slide we are (0..1): the later of its time and its lost speed.
func slide_progress() -> float:
	if not sliding:
		return 1.0
	var S: Dictionary = _cfg.get("slide", {})
	var by_time: float = 1.0 - _slide_t / maxf(0.05, _slide_dur)
	var by_speed: float = (_slide_v0 - _slide_speed) / maxf(0.1, _slide_v0 - float(S.get("min_speed", 3.2)))
	return clampf(maxf(by_time, by_speed), 0.0, 1.0)


## Hip fire is allowed in the last part of a slide (movement.json slide_fire_from).
func slide_fire_ok() -> bool:
	return not sliding or slide_progress() >= float(_mv.get("slide_fire_from", 0.5))


## Last stand: the downed capsule and eye (kept for callers; the crawl passes its own eye height).
func _set_crouch_shape(crouch: bool, delta: float = 1.0 / 60.0, eye_target: float = -1.0) -> void:
	_shape_toward(CROUCH_HEIGHT if crouch else STAND_HEIGHT, (EYE_CROUCH if crouch else EYE_STAND) if eye_target < 0.0 else eye_target, delta)


## Stand / crouch / prone: capsule and eye ease to the stance's targets at a frame-rate independent rate. You
## can't stand (or leave prone) into a low ceiling: the stance drops back to what fits.
func _update_stance_shape(delta: float) -> void:
	var P: Dictionary = _mv.get("prone", {})
	var h: float = STAND_HEIGHT
	var eye: float = EYE_STAND
	if prone:
		h = float(P.get("height", 0.75))
		eye = float(P.get("eye", 0.6))
	elif crouching or sliding:
		h = CROUCH_HEIGHT
		eye = EYE_CROUCH
	if h > _capsule.height + 0.001 and _head_blocked_to(h):
		if h >= STAND_HEIGHT and not _head_blocked_to(CROUCH_HEIGHT):
			crouching = true
			h = CROUCH_HEIGHT
			eye = EYE_CROUCH
		else:
			h = _capsule.height
			eye = minf(_eye, eye)
			if not prone and _capsule.height < CROUCH_HEIGHT - 0.01:
				prone = true          # still under something low: stay down
			crouching = true
	_shape_toward(h, eye, delta)


func _shape_toward(h: float, eye: float, delta: float) -> void:
	_capsule.height = move_toward(_capsule.height, h, 12.0 * delta)
	_collider.position.y = _capsule.height * 0.5
	var k: float = 1.0 - exp(-float(_mv.get("crouch_rate", 11.0)) * delta)
	_eye = lerpf(_eye, eye, k)
	if absf(_eye - eye) < 0.002:
		_eye = eye


func _head_blocked() -> bool:
	return _head_blocked_to(STAND_HEIGHT)


## Is there a ceiling between the top of the current capsule and `height` above the feet?
func _head_blocked_to(height: float) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var base: float = minf(_capsule.height if _capsule != null else CROUCH_HEIGHT, height) - 0.05
	var from: Vector3 = global_position + Vector3.UP * maxf(0.3, base)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, global_position + Vector3.UP * (height + 0.1), 1 | (1 << 8), [get_rid()])
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
	if _since_hit >= float(_cfg["regen_delay"]) * float(PerkManager.stat(player_id, "regen_delay_mult", 1.0)) * Muster.mult(player_id, "regen_delay_mult") and hp < max_hp:
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
		# landing head dip: a stiffer spring of its own
		_land_dip_v += (-_land_dip * 196.0 - _land_dip_v * 2.0 * 14.0) * dt
		_land_dip += _land_dip_v * dt
	_tick_recoil_recovery(delta)
	var S: Dictionary = _cfg.get("slide", {})
	var C: Dictionary = _mv.get("camera", {})
	var dip: float = _slide_k * float(S.get("cam_dip", 0.22)) * (0.75 + 0.25 * sin(_shake_t * 0.9))
	# head bob on the footstep cadence: the head dips on every footfall and sways toward the planted foot;
	# bigger at a sprint, small crouched, almost nothing aimed
	var on_floor: bool = is_on_floor() and not sliding and not mantling
	var amp: float = float(C.get("bob_walk", 0.012))
	if sprinting:
		amp = float(C.get("bob_sprint", 0.032))
	elif crouching or prone:
		amp = float(C.get("bob_crouch", 0.006))
	var walk: float = float(_cfg["walk_speed"])
	var moving: float = clampf(horizontal_speed() / maxf(0.1, walk), 0.0, 1.3) if on_floor else 0.0
	_bob_k = lerpf(_bob_k, moving * amp * lerpf(1.0, float(C.get("bob_ads_mult", 0.25)), weapons.ads_t), clampf(delta * 8.0, 0.0, 1.0))
	var bob_scale: float = lerpf(0.4, 1.0, clampf(shake_setting(), 0.0, 1.0))
	var ph: float = step_phase() * PI
	var sw: float = sin(ph)
	var bob_y: float = (0.5 - (1.0 - absf(sw))) * _bob_k * bob_scale
	var bob_x: float = sw * _bob_k * float(C.get("bob_side", 0.45)) * bob_scale
	var bob_roll: float = sw * deg_to_rad(float(C.get("bob_roll_deg", 0.35))) * (_bob_k / maxf(0.001, float(C.get("bob_walk", 0.012)))) * 0.5 * bob_scale
	_sprint_k = lerpf(_sprint_k, 1.0 if sprinting else 0.0, 1.0 - exp(-float(_mv.get("sprint_fov_rate", 7.0)) * delta))
	var mk: float = mantle_k()
	head.position.y = _eye - dip + bob_y + _land_dip - mk * 0.08
	head.rotation.x = _pitch + _rk.x - mk * 0.06
	head.rotation.y = _rk.y
	# lean (and the slide's roll: the body leans into the slide direction)
	var lean_in: float = 0.0
	if bool(GLSettings.values.get("lean_enabled", true)):
		lean_in = Input.get_action_strength(&"lean_right") - Input.get_action_strength(&"lean_left")
	_lean = move_toward(_lean, lean_in, delta * 5.0)
	head.position.x = _lean * 0.35 + bob_x
	var side: float = 0.0
	if _slide_k > 0.001:
		side = global_basis.x.dot(_slide_dir)                      # +1 sliding to the right
	# strafe roll: the view tips a little into a sideways move
	var lateral: float = global_basis.x.dot(velocity) if not sliding else 0.0
	var roll_target: float = -clampf(lateral / maxf(0.1, walk), -1.0, 1.0) * deg_to_rad(float(C.get("strafe_roll_deg", 1.5))) * bob_scale
	_roll = lerpf(_roll, roll_target, 1.0 - exp(-float(C.get("roll_rate", 8.0)) * delta))
	_punch_roll = move_toward(_punch_roll, 0.0, delta * maxf(0.2, absf(_punch_roll) * 6.0))
	_ext_roll = lerpf(_ext_roll, deg_to_rad(ext_roll_deg), 1.0 - exp(-3.0 * delta))
	camera.rotation.z = -_lean * 0.12 - _slide_k * (deg_to_rad(float(S.get("cam_tilt_deg", 3.5))) * (0.6 + 0.4 * side)) + _roll + bob_roll + _punch_roll + mk * 0.05 + _ext_roll
	# shake (smooth pseudo-noise rather than per-frame white noise, scaled by the Screen Shake setting)
	_shake = maxf(0.0, _shake - delta * 1.8)
	_shake_t += delta * 38.0
	var sk: float = _shake * 0.05 * shake_setting()
	camera.h_offset = (sin(_shake_t * 1.13) + sin(_shake_t * 2.71) * 0.5) * 0.67 * sk
	camera.v_offset = (sin(_shake_t * 1.37 + 1.9) + sin(_shake_t * 3.07) * 0.5) * 0.67 * sk
	# fov (+ a short punch on heavy shots, + the eased sprint kick)
	_fov_punch = move_toward(_fov_punch, 0.0, delta * maxf(8.0, absf(_fov_punch) * 14.0))
	var fov: float = GLSettings.get_f("fov") * weapons.fov_mult() + float(_mv.get("sprint_fov_deg", 6.0)) * _sprint_k
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


## Recoil pattern (WeaponHolder._apply_recoil_pattern): one shot moves the aim itself by `pitch_deg` up and
## `yaw_deg` sideways. After `delay` s without a shot, (1 - keep) of what the burst added drifts back at `recover`
## (1/s, exponential), so a short burst settles near where you started and a long one leaves you to pull down.
func apply_recoil_pattern(pitch_deg: float, yaw_deg: float, keep: float, recover: float, delay: float) -> void:
	var p: float = deg_to_rad(pitch_deg)
	var y: float = deg_to_rad(yaw_deg)
	var before: float = _pitch
	_pitch = clampf(_pitch + p, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotate_y(-y)
	_rc_pool += Vector2(_pitch - before, y) * (1.0 - clampf(keep, 0.0, 1.0))
	_rc_recover = maxf(0.5, recover)
	_rc_delay = maxf(0.0, delay)
	_rc_since = 0.0


func _tick_recoil_recovery(delta: float) -> void:
	_rc_since += delta
	if _rc_since < _rc_delay or _rc_pool.length_squared() < 1e-10:
		return
	var take: Vector2 = _rc_pool * (1.0 - exp(-_rc_recover * delta))
	_rc_pool -= take
	_pitch = clampf(_pitch - take.x, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotate_y(take.y)


## Damage punch: the view snaps up and rolls a little with each hit, scaled by the damage (movement.json camera).
func _damage_punch(amount: float) -> void:
	var C: Dictionary = _mv.get("camera", {})
	var deg: float = minf(float(C.get("punch_max_deg", 4.0)), amount / 10.0 * float(C.get("punch_deg_per_10", 1.1))) * shake_setting()
	if deg <= 0.0:
		return
	_rk_w = maxf(_rk_w, 10.0)
	_rk_v += Vector2(deg_to_rad(deg), deg_to_rad(deg) * randf_range(-0.6, 0.6)) * _rk_w * 2.72
	_punch_roll += deg_to_rad(deg) * 0.6 * (1.0 if randf() < 0.5 else -1.0)


func shake_setting() -> float:
	return clampf(float(GLSettings.values.get("screen_shake", 1.0)), 0.0, 1.5)


## Footstep cadence as a continuous phase: the integer part counts footsteps, so sin(PI * phase) crosses
## zero on every footfall (the viewmodel bob dips there).
func step_phase() -> float:
	return float(_step_count) + clampf(_step_dist / _stride(), 0.0, 1.0)


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


# ---------------------------------------------------------------- outside forces (UPDATE 07, T-105)

## Adds `v` (m/s, world frame) to this body's motion for `seconds`: the Kranich's turbulence, a breach's suction,
## the impeller pit's and the Bordwart's pull (`kind` &"pull"), the Lodestone's slam wave. Skyhook Sekt resists
## pushes (push_resist) and pulls (pull_resist); the Lodestone's holder ignores pulls (Ballast). Bots take it
## through push_velocity() in their adapter.
## True while an external push / pull (a bank, a breach, the Lodestone) still drives this body.
func is_pushed() -> bool:
	return _push_t > 0.0


func external_push(v: Vector3, seconds: float, kind: StringName = &"push") -> void:
	if downed or spectating:
		return
	var resist: float = float(PerkManager.stat(player_id, "pull_resist" if kind == &"pull" else "push_resist", 0.0))
	if kind == &"pull" and lodestone_ballast():
		return
	_push_v = v * (1.0 - clampf(resist, 0.0, 1.0))
	_push_t = maxf(0.05, seconds)


## The current push (zero when none), for the bots' movement adapter.
func push_velocity() -> Vector3:
	return _push_v if _push_t > 0.0 else Vector3.ZERO


## True while the Lodestone is in hand: immune to pulls and to its own slam's shockwave (docs/MAP4_FERNFLUG.md 8.2).
func lodestone_ballast() -> bool:
	var w: WeaponInstance = weapons.current() if weapons != null else null
	return w != null and w.data.has("gravity")


## True while a jump pressed in the air could still catch a ledge (the mantle wins over Skyhook's hop).
func _mantle_air_catching() -> bool:
	return mantling


func take_hit(amount: float, _source: Node) -> void:
	if downed or spectating or GameState.phase != GameState.Phase.PLAYING:
		return
	if not is_local and not is_bot:
		Economy.bonuses.note_hit(player_id)   # T-078: the host never sees this hit land; it still spoils a clean round
		_forward(&"hit", [amount])   # the owner applies it (their health is theirs, D-065)
		return
	if GameState.god_mode and is_local:
		GLBus.player_damaged.emit(player_id, 0.0)
		return
	if is_bot:
		amount *= bot_damage_mult
	amount = PerkManager.filter_hit(self, amount)   # perk tiers: iron skin, revive window, sprint dodge (T-075)
	if amount <= 0.0:
		return
	hp -= amount
	_since_hit = 0.0
	_shake = maxf(_shake, 0.35)
	if is_local:
		_damage_punch(amount)
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
	mantling = false
	prone = false
	_slide_k = 0.0
	velocity = Vector3.ZERO
	_set_heartbeat(false)
	_hold_t = 0.0
	interact_progress = 0.0
	_set_hold_node(null)
	if not GameState.is_solo() or is_companion:
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
	_set_crouch_shape(true, delta, float(dcfg.get("eye_height", 0.45)))
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
	prone = false
	mantling = false
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
