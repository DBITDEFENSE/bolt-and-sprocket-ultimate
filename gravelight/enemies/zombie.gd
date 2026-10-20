class_name Zombie
extends CharacterBody3D
## Gänger: the standard undead, plus the pooled variants that share its body and state machine:
## Glasshide (crystal-plated, torso armor) and Bellringer (special-round lantern miner, lunge attack).
## Pooled by ZombieDirector, never freed mid-match. Bosses (Foreman, Screamer) subclass this script.
## States: SPAWN -> (window) TO_WINDOW -> WAIT/TEAR -> CLIMB -> CHASE <-> ATTACK, STAGGER, DEAD.
## All tuning comes from data/enemies.json; health and tier come from the RoundManager spawn spec.
##
## Co-op (M7): the host simulates every zombie. On a client each zombie is a *puppet* (`puppet = true`): no AI,
## no navigation; it is placed from interpolated snapshots, animates from the replicated state, and plays its
## death from the host's death event (variant, side, head pop). Damage from the client's own weapons is
## predicted locally (hit markers, wounds) and sent to the host with the shot ray (NetMatch.send_hit).

enum State { INACTIVE, EMERGE, TO_WINDOW, WAIT_WINDOW, TEAR, CLIMB, CHASE, ATTACK, STAGGER, DEAD }

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 1 << 1
const LAYER_ZBODY: int = 1 << 2
const LAYER_DOOR: int = 1 << 8
const GRAVITY: float = 18.0
const TIER_LEAN: Dictionary = {&"shamble": 0.08, &"walk": 0.14, &"jog": 0.3, &"run": 0.45, &"sprint": 0.6}

## Shared per-physics-frame repath budget, reset by the director.
static var repath_budget: int = 6

var enemy_id: StringName = &"ganger"
var state: State = State.INACTIVE
var tier: StringName = &"shamble"
var speed: float = 1.3
var max_hp: float = 150.0
var hp: float = 150.0
var is_crawler: bool = false
var is_last: bool = false
var window: Barricade = null
var target: Player = null
var director: Node = null
## Co-op replication (see the class doc).
var net_id: int = -1
var puppet: bool = false
var net_died: bool = false
var interp: InterpBuffer = null
var _pred_dmg: float = 0.0

var _cfg: Dictionary = {}
var _agent: NavigationAgent3D
var _safe_vel: Vector3 = Vector3.ZERO
var _pivot: Node3D
var _parts: Dictionary = {}       # name -> Node3D (pivot or mesh)
var _hitboxes: Array[Hitbox] = []
var _collision: CollisionShape3D
var _state_t: float = 0.0
var _repath_t: float = 0.0
var _attack_cd: float = 0.0
var _attack_hit_done: bool = false
var _tear_t: float = 0.0
var _climb_from: Vector3
var _climb_to: Vector3
var _climb_mid: Vector3
var _queue_index: int = 0
var _leg_damage: float = 0.0
var _phase: float = 0.0
var _groan_t: float = 3.0
var _stuck_t: float = 0.0
var _stuck_origin: Vector3 = Vector3.ZERO
var _anim_skip: int = 0
var _mats: Dictionary = {}
var _flinch: float = 0.0
var _burn_t: float = 0.0
var _burn_dps: float = 0.0
var _burn_by: int = 0
var _burn_tick: float = 0.0
var _flinch_dir: float = 1.0
## Torso damage multiplier (Glasshides, M4). Armor-piercing / armor-ignoring rounds skip it.
var armor_torso_mult: float = 1.0
var _frost_t: float = 0.0
var _frost_slow: float = 0.0
var _kind_nodes: Dictionary = {}   # "glass" / "lantern" -> Node3D, shown per kind
var _lantern_light: OmniLight3D
var _lunge_dir: Vector3 = Vector3.ZERO
var _ring_t: float = 0.0
var _zstep_t: float = 0.0
## Shared across zombies: the last time any zombie played a footstep (global rate cap for a 24-zombie horde).
static var _last_step_msec: int = 0
const STEP_INTERVAL: float = 0.6
const STEP_RANGE_SQ: float = 18.0 * 18.0
const STEP_GAP_MSEC: int = 70


func _init() -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	safe_margin = 0.02


func _ready() -> void:
	_cfg = GLData.table("enemies")["enemies"]["ganger"]
	_collision = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	_collision.shape = cap
	_collision.position = Vector3(0, 0.875, 0)
	add_child(_collision)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.45
	_agent.path_max_distance = 3.0
	_agent.radius = 0.4
	_agent.height = 1.8
	_agent.avoidance_enabled = true
	_agent.neighbor_distance = 3.0
	_agent.max_neighbors = 6
	_agent.time_horizon_agents = 0.5
	_agent.avoidance_layers = 1
	_agent.avoidance_mask = 1
	_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(_agent)
	_build_body()
	deactivate()


# ---------------------------------------------------------------- pool lifecycle

## Ganger tuning with the kind's overrides on top (data/enemies.json).
static func kind_config(kind: StringName) -> Dictionary:
	var all: Dictionary = GLData.table("enemies")["enemies"]
	var c: Dictionary = (all["ganger"] as Dictionary).duplicate(true)
	if kind != &"ganger" and all.has(String(kind)):
		c.merge(all[String(kind)], true)
	return c


func activate(spec: Dictionary, spawn: ZombieSpawn, at_target: Player) -> void:
	var tiers: Dictionary = GLData.table("enemies")["tiers"]
	var jitter: float = float(GLData.table("enemies")["speed_jitter"])
	net_died = false
	enemy_id = StringName(spec.get("enemy_id", "ganger"))
	_cfg = kind_config(enemy_id)
	tier = StringName(spec.get("tier", "shamble"))
	speed = float(tiers.get(String(tier), 1.3)) * randf_range(1.0 - jitter, 1.0 + jitter)
	if _cfg.has("speed"):
		speed = float(_cfg["speed"]) * randf_range(1.0 - jitter, 1.0 + jitter)
	max_hp = float(spec.get("health", 150))
	hp = max_hp
	is_crawler = false
	is_last = false
	_leg_damage = 0.0
	_attack_cd = 0.0
	_stuck_t = 0.0
	_burn_t = 0.0
	_frost_t = 0.0
	_frost_slow = 0.0
	armor_torso_mult = float(_cfg.get("armor_mult", 1.0))
	target = at_target
	_set_crawl_pose(false)
	_apply_variant(String(spec.get("variant", "soldier")))
	_apply_kind()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	velocity = Vector3.ZERO
	window = spawn.window()
	global_position = spawn.global_position
	_stuck_origin = global_position
	_agent.max_speed = speed
	_agent.avoidance_enabled = true
	_repath_t = randf_range(0.0, 0.2)
	_groan_t = randf_range(0.5, 3.0)
	if spawn.kind == &"ground":
		_enter(State.EMERGE)
	elif window != null:
		_enter(State.TO_WINDOW)
	else:
		_enter(State.CHASE)
	if tier == &"sprint":
		AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0)
	if enemy_id == &"bellringer":
		_portal_flash()


func deactivate() -> void:
	state = State.INACTIVE
	if window != null:
		window.release(self)
	window = null
	hide()
	collision_layer = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	velocity = Vector3.ZERO
	global_position = Vector3(0, -200, 0)
	process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return state != State.INACTIVE and state != State.DEAD


func hitbox_rids() -> Array[RID]:
	var out: Array[RID] = []
	for hb: Hitbox in _hitboxes:
		out.append(hb.get_rid())
	return out


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	match s:
		State.TEAR:
			_tear_t = _tear_interval() * 0.6
		State.ATTACK:
			_attack_hit_done = false
			AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, -2.0)
		State.EMERGE:
			_pivot.position.y = -1.7


# ---------------------------------------------------------------- frame update

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	_state_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	match state:
		State.EMERGE:
			var t: float = clampf(_state_t / (0.7 if enemy_id == &"bellringer" else 1.4), 0.0, 1.0)
			_pivot.position.y = lerpf(-1.7, 0.0, t * t * (3.0 - 2.0 * t))
			if t >= 1.0:
				_enter(State.CHASE)
		State.TO_WINDOW:
			_update_to_window(delta)
		State.WAIT_WINDOW:
			_update_wait_window(delta)
		State.TEAR:
			_update_tear(delta)
		State.CLIMB:
			_update_climb(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.STAGGER:
			_halt(delta)
			if _state_t >= float(_cfg["stagger_seconds"]):
				_enter(State.CHASE)
		State.DEAD:
			_update_dead(delta)
	if state != State.DEAD and global_position.y < -30.0:
		recycle()
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	_update_audio(delta)


func _process(delta: float) -> void:
	# Cheap procedural animation; distant zombies animate at a lower rate.
	_anim_skip += 1
	var far: bool = target != null and global_position.distance_squared_to(target.global_position) > 1600.0
	if far and _anim_skip % 4 != 0:
		return
	var dt: float = delta * (4.0 if far else 1.0)
	_animate(dt)


func _update_to_window(delta: float) -> void:
	if window == null:
		_enter(State.CHASE)
		return
	var goal: Vector3 = window.outside_point()
	# Someone else is already at this window: queue up nearby instead of crowding it.
	var taken: bool = window.occupant != null and is_instance_valid(window.occupant) and window.occupant != self
	if taken and _flat_dist(goal) < 3.5:
		_queue_index = randi() % 4
		_enter(State.WAIT_WINDOW)
		return
	var mine: bool = window.occupant == self
	if mine:
		# Our turn: slip through the queue (no zombie-zombie collision) and start once close enough.
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
		_agent.avoidance_enabled = false
	var reach: float = 1.2 if mine else 0.7
	if _flat_dist(goal) < reach or (mine and _state_t > 6.0):
		if window.claim(self):
			_enter(State.TEAR)
		else:
			_queue_index = randi() % 4
			_enter(State.WAIT_WINDOW)
		return
	_nav_move(goal, speed, delta, 0.5)


func _update_wait_window(delta: float) -> void:
	var spot: Vector3 = window.queue_point(_queue_index)
	if _flat_dist(spot) > 0.4:
		_nav_move(spot, minf(speed, 2.0), delta, 0.6)
	else:
		_halt(delta)
		_face(window.global_position)
	if _state_t > 0.4 and window.claim(self):
		_enter(State.TO_WINDOW)


func _update_tear(delta: float) -> void:
	_halt(delta)
	var settle: Vector3 = window.outside_point()
	settle.y = global_position.y
	global_position = global_position.move_toward(settle, delta * 1.5)
	_face(window.inside_point())
	# Swipe through a mostly-open window at a player standing right behind it.
	if target != null and window.boards <= 2 and _attack_cd <= 0.0:
		if _window_reach_ok(target, 0.0):
			_attack_cd = float(_cfg["attack_interval"])
			_window_swipe()
	_tear_t -= delta
	if _tear_t > 0.0:
		return
	if window.boards > 0:
		window.tear_board()
		_yank = 0.4
		_tear_t = _tear_interval()
	else:
		_start_climb()


func _window_swipe() -> void:
	AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, -2.0)
	var t: Player = target
	var tw: Tween = create_tween()
	tw.tween_interval(float(_cfg["attack_windup"]))
	tw.tween_callback(func() -> void:
		if is_active() and window != null and is_instance_valid(t) and _window_reach_ok(t, 0.2):
			t.take_hit(float(_cfg["damage"]), self))


## Melee needs a clear line to the target: no wall or closed door in between. Without it a long-reach
## attacker (a Bellringer reaches 2.4 m, +0.5 m when the hit lands) could hit through a thin wall or a closed
## door (playtest fix, T-026). Window swipes have their own rule (_window_reach_ok).
func _clear_to(t: Player) -> bool:
	if t == null:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# Two rays (chest, head height), each trimmed 0.35 m at both ends so a wall or door frame that both bodies
	# are hugging doesn't count; any clear ray is enough.
	for h: Vector2 in [Vector2(1.2, 1.0), Vector2(1.55, 1.5)]:
		var from: Vector3 = global_position + Vector3.UP * h.x
		var to: Vector3 = t.global_position + Vector3.UP * h.y
		var span: float = from.distance_to(to)
		if span < 0.8:
			return true
		var dir: Vector3 = (to - from) / span
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + dir * 0.35, to - dir * 0.35, 1 | (1 << 8), [get_rid(), t.get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Through-the-window reach: measured from the window opening (the barricade plane), not from a point 1 m
## inside the room, so only a player standing right at the boards can be swiped (playtest fix, T-026).
func _window_reach_ok(t: Player, grace: float) -> bool:
	var reach: float = float(GLData.table("world")["barricade"]["window_attack_reach"]) + grace
	var w: Vector3 = window.global_position
	var flat: Vector2 = Vector2(t.global_position.x - w.x, t.global_position.z - w.z)
	return flat.length() < reach and absf(t.global_position.y - w.y) < 2.0


func on_board_repaired() -> void:
	if state == State.TEAR:
		_tear_t = _tear_interval()


func _tear_interval() -> float:
	if RoundManager.current_round >= int(_cfg["tear_late_from_round"]):
		return float(_cfg["tear_interval_late"])
	return float(_cfg["tear_interval"])


func _start_climb() -> void:
	_climb_from = global_position
	_climb_mid = window.sill_point()
	_climb_to = window.inside_point()
	collision_mask = 0
	_agent.avoidance_enabled = false
	_enter(State.CLIMB)


func _update_climb(_delta: float) -> void:
	var dur: float = float(_cfg["climb_seconds"]) * (1.6 if is_crawler else 1.0)
	var t: float = clampf(_state_t / dur, 0.0, 1.0)
	var a: Vector3 = _climb_from.lerp(_climb_mid, t)
	var b: Vector3 = _climb_mid.lerp(_climb_to, t)
	global_position = a.lerp(b, t)
	_face(_climb_to + (_climb_to - _climb_from))
	if t >= 1.0:
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
		_agent.avoidance_enabled = true
		if window != null:
			window.release(self)
		window = null
		_stuck_origin = global_position
		_enter(State.CHASE)


func _update_chase(delta: float) -> void:
	# Siren Gramophone: an active lure in range overrides everything else.
	var lure: Node3D = _active_lure()
	if lure != null:
		if _flat_dist(lure.global_position) > 1.2:
			_nav_move(lure.global_position, speed, delta, 0.4)
		else:
			_halt(delta)
			_face(lure.global_position)
		return
	target = _nearest_player()
	if target == null:
		_halt(delta)
		return
	var to_t: Vector3 = target.global_position - global_position
	var dist: float = to_t.length()
	if dist <= float(_cfg["attack_range"]) and absf(to_t.y) < 1.3 and _attack_cd <= 0.0 and _clear_to(target):
		_enter(State.ATTACK)
		return
	var rp: Dictionary = GLData.table("enemies")["repath"]
	var interval: float = float(rp["near_s"])
	if dist > float(rp["far_m"]):
		interval = float(rp["far_s"])
	elif dist > float(rp["near_m"]):
		interval = float(rp["mid_s"])
	var spd: float = float(_cfg["crawler_speed"]) if is_crawler else speed
	if is_last and not is_crawler:
		spd = maxf(spd, float(GLData.table("enemies")["tiers"]["jog"]))
	_nav_move(target.global_position, spd, delta, interval)
	# Stuck check: barely moved for a long time while far from the player -> recycle into the queue.
	_stuck_t += delta
	if _stuck_t > float(_cfg["stuck_respawn_seconds"]):
		# ...or stuck anywhere it isn't within reach of its target: snagged on a stair corner, a stall, or with a
		# closed door / wall in between (T-026). A recycled zombie re-enters through a window.
		if global_position.distance_to(_stuck_origin) < 1.0 and (dist > float(_cfg["attack_range"]) + 1.0 or not _clear_to(target)) and not is_crawler:
			recycle()
			return
		_stuck_t = 0.0
		_stuck_origin = global_position


func _update_attack(delta: float) -> void:
	var windup: float = float(_cfg["attack_windup"])
	if enemy_id == &"bellringer" and _state_t >= windup * 0.5 and _state_t < windup + 0.15 and target != null:
		# Lunge: a short leap at the target during the windup.
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		var leap: float = float(_cfg.get("lunge_distance", 2.0)) / maxf(0.05, windup * 0.5 + 0.15)
		if to_t.length() > 0.9:
			velocity.x = to_t.normalized().x * leap
			velocity.z = to_t.normalized().z * leap
			_apply_gravity(delta)
			move_and_slide()
	else:
		_halt(delta)
	if target != null:
		_face(target.global_position)
	if not _attack_hit_done and _state_t >= windup:
		_attack_hit_done = true
		if target != null and target.is_alive():
			var d: float = global_position.distance_to(target.global_position)
			if d <= float(_cfg["attack_range"]) + 0.5 and _clear_to(target):
				target.take_hit(float(_cfg["damage"]), self)
				if _cfg.has("hit_slow"):
					target.apply_status(&"shard_slow", float(_cfg.get("hit_slow_seconds", 0.5)))
				if enemy_id == &"bellringer":
					AudioDirector.play_3d("bellringer_lantern", global_position + Vector3.UP * 1.4, 2.0)
	if _state_t >= windup + 0.35:
		_attack_cd = maxf(0.0, float(_cfg["attack_interval"]) - windup - 0.35)
		_enter(State.CHASE)


func _update_dead(delta: float) -> void:
	if _state_t > 1.6:
		_pivot.position.y -= delta * 0.8
	if _state_t > 2.4:
		deactivate()
		if director != null:
			director.call("on_zombie_returned", self)


# ---------------------------------------------------------------- movement helpers

func _nav_move(goal: Vector3, spd: float, delta: float, repath_interval: float) -> void:
	_repath_t -= delta
	if _repath_t <= 0.0 and Zombie.repath_budget > 0:
		Zombie.repath_budget -= 1
		if director != null:
			_agent.navigation_layers = (director as ZombieDirector).nav_mask
		_agent.target_position = goal
		_repath_t = repath_interval
	var next: Vector3 = _agent.get_next_path_position()
	var dir: Vector3 = next - global_position
	if _agent.is_navigation_finished() or dir.length_squared() < 0.0004:
		dir = goal - global_position
	dir.y = 0.0
	spd *= frost_speed_mult()
	var desired: Vector3 = dir.normalized() * spd if dir.length_squared() > 0.0001 else Vector3.ZERO
	_agent.max_speed = spd
	if _agent.avoidance_enabled:
		_agent.velocity = desired
	else:
		_safe_vel = desired
	velocity.x = _safe_vel.x
	velocity.z = _safe_vel.z
	_apply_gravity(delta)
	move_and_slide()
	var flat: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if flat.length_squared() > 0.05:
		_face(global_position + flat)


func _on_velocity_computed(safe: Vector3) -> void:
	_safe_vel = safe


func _halt(delta: float) -> void:
	_safe_vel = Vector3.ZERO
	if _agent.avoidance_enabled:
		_agent.velocity = Vector3.ZERO
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, 0.25)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _active_lure() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(&"lures"):
		var g: Gramophone = n as Gramophone
		if g != null and global_position.distance_to(g.global_position) <= g.lure_radius():
			return g
	return null


## Sets the zombie on fire (flamethrower, incendiary rounds). Refreshes rather than stacks.
func ignite(dps: float, seconds: float, by_player: int) -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"ignite", dps, seconds)
		_burn_t = maxf(_burn_t, seconds)
		return
	_burn_dps = maxf(_burn_dps if _burn_t > 0.0 else 0.0, dps)
	_burn_t = maxf(_burn_t, seconds)
	_burn_by = by_player


## Red Winter frost: slows movement. Refreshes the timer; never stacks beyond one slow.
func apply_frost(slow: float, seconds: float) -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"frost", slow, seconds)
		return
	_frost_slow = maxf(_frost_slow if _frost_t > 0.0 else 0.0, slow)
	_frost_t = maxf(_frost_t, seconds)


func frost_speed_mult() -> float:
	return 1.0 - _frost_slow if _frost_t > 0.0 else 1.0


## Interrupts the current attack/chase (Ironmonger stagger rounds).
func force_stagger() -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"stagger")
		return
	if state == State.CHASE or state == State.ATTACK:
		_enter(State.STAGGER)


func is_burning() -> bool:
	return _burn_t > 0.0


func _update_burn(delta: float) -> void:
	if _burn_t <= 0.0 or not is_active():
		return
	_burn_t -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.25
		take_damage(_burn_dps * 0.25, &"torso", &"fire", _burn_by, &"fire")
		Effects.blood(global_position + Vector3.UP * randf_range(0.6, 1.6), Vector3.UP)


func _nearest_player() -> Player:
	var best: Player = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------- damage

## Applies damage from one source in one shot. Returns true if this killed the zombie.
## kind: &"bullet", &"melee", &"explosive", &"world" (traps/blackout: no Scrip).
func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if puppet:
		return _puppet_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	if not is_active():
		return false
	if (limb == &"torso" or limb == &"arms") and kind == &"bullet" and not armor_piercing:
		amount *= armor_torso_mult
	if GameState.has_flag(&"deaths_door") and kind != &"world":
		amount = hp + 1.0
	hp -= amount
	GLBus.enemy_damaged.emit(enemy_id, limb, amount, by_player)
	if kind != &"fire" and kind != &"world":
		_wound(limb)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	if hp <= 0.0:
		_die(limb, weapon_id, by_player, kind)
		return true
	if by_player > 0 and kind != &"fire":
		Economy.award(by_player, int(GLData.table("economy")["hit_nonlethal"]))
	_flinch = 0.18
	_flinch_dir = -1.0 if randf() < 0.5 else 1.0
	# Crawlers: a leg damage pool, or a chance from explosions.
	if not is_crawler and bool(_cfg.get("can_crawl", true)):
		if limb == &"legs":
			_leg_damage += amount
			if _leg_damage >= max_hp * float(_cfg["leg_pool_fraction"]):
				_leg_damage = -INF
				if randf() < float(_cfg["leg_sever_chance"]):
					become_crawler()
		elif kind == &"explosive" and randf() < float(_cfg["explosive_crawler_chance"]):
			become_crawler()
	var stagger_ok: bool = kind != &"bullet" or bool(_cfg.get("bullet_stagger", true))
	if stagger_ok and (kind == &"melee" or kind == &"explosive" or amount >= max_hp * 0.4) and state == State.CHASE:
		_enter(State.STAGGER)
	return false


func become_crawler() -> void:
	if is_crawler:
		return
	if puppet and not Net.applying:
		if Net.session != null:
			Net.session.send_zombie_effect(self, &"crawl")
		return
	is_crawler = true
	if Net.replicating():
		Net.session.zombie_event(self, &"crawl", [])
	AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 0.6)
	for leg: String in ["thigh_l", "thigh_r"]:
		_gib(leg, Vector3(randf_range(-1.5, 1.5), 2.0, randf_range(-1.5, 1.5)), 8.0)
	Effects.blood((_bones["hips"] as Node3D).global_position, Vector3.UP)
	_set_crawl_pose(true)


func _die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	if window != null:
		window.release(self)
		window = null
	collision_layer = 0
	collision_mask = LAYER_WORLD
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_agent.avoidance_enabled = false
	_safe_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	if by_player > 0:
		var econ: Dictionary = GLData.table("economy")
		var value: int = Economy.kill_value(limb, kind == &"melee", econ)
		if _cfg.has("scrip"):
			value = Economy.kill_value(limb, kind == &"melee", {"kill": _cfg["scrip"]})
		if limb == &"head" and kind != &"melee" and GameState.player_has_trait(by_player, &"wren"):
			value += int(GLData.table("player")["traits"]["wren_headshot_scrip_bonus"])
		Economy.award(by_player, value)
	AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.2, -1.0)
	_death_burst()
	state = State.DEAD
	_state_t = 0.0
	GLBus.enemy_killed.emit(enemy_id, limb, weapon_id, by_player)
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	RoundManager.on_zombie_died()
	_death_kind = randi() % 4
	_death_side = -1.0 if randf() < 0.5 else 1.0
	if limb == &"head" and kind != &"world":
		_pop_head()
	elif kind == &"explosive" and randf() < 0.35:
		_pop_head()
	if Net.replicating():
		Net.session.zombie_died(self, limb, kind, _death_kind, _death_side, _head_popped)


## Removes this zombie without a kill (stuck or unreachable) and puts it back in the round queue.
func recycle() -> void:
	if puppet or not is_active():
		return
	RoundManager.requeue()
	deactivate()
	if director != null:
		director.call("on_zombie_returned", self)


## Kills with no Scrip (Blackout, dev console).
func kill_silently() -> void:
	if not puppet and is_active():
		hp = 0.0
		_die(&"torso", &"none", 0, &"world")


# ---------------------------------------------------------------- body (procedural skeleton, see ZombieBody)

const TIER_GAIT: Dictionary = {
	# step length (m), hip swing, knee bend, forward lean, bob, arm mode
	&"shamble": [0.42, 0.3, 0.38, 0.14, 0.022, 0],
	&"walk": [0.58, 0.42, 0.55, 0.18, 0.03, 1],
	&"jog": [0.85, 0.62, 0.95, 0.32, 0.05, 2],
	&"run": [1.15, 0.8, 1.25, 0.46, 0.065, 3],
	&"sprint": [1.3, 0.95, 1.45, 0.6, 0.075, 4],
}

var _bones: Dictionary = {}        # bone name -> Node3D
var _bone_mi: Dictionary = {}      # bone name -> MeshInstance3D
var _variant: String = "soldier"
var _asym: Dictionary = {}
var _death_kind: int = 0
var _death_side: float = 1.0
var _yank: float = 0.0
var _decals: Array[MeshInstance3D] = []
var _decal_i: int = 0
var _head_popped: bool = false


func _build_body() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	for b: Array in ZombieBody.SKELETON:
		var n: Node3D = Node3D.new()
		n.name = str(b[0])
		n.position = b[2]
		var parent: Node3D = _pivot if str(b[1]) == "" else _bones[str(b[1])]
		parent.add_child(n)
		n.set_meta("rest", b[2])
		_bones[str(b[0])] = n
	for bone: String in ZombieBody.MESH_BONES:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "M"
		# only the big pieces cast shadows; small bones are skipped (big win with 24+ zombies)
		if not bone in ["hips", "chest", "head"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(_bones[bone] as Node3D).add_child(mi)
		_bone_mi[bone] = mi
	for h: Array in ZombieBody.HITBOXES:
		var hb: Hitbox = Hitbox.new()
		hb.setup(self, h[1], h[2])
		hb.position = h[3]
		(_bones[str(h[0])] as Node3D).add_child(hb)
		_hitboxes.append(hb)
	# compatibility names used elsewhere (Screamer, kind extras)
	_parts["hip_l"] = _bones["thigh_l"]
	_parts["hip_r"] = _bones["thigh_r"]
	_parts["torso"] = _bones["chest"]
	_parts["head"] = _bones["head"]
	_parts["sh_l"] = _bones["sh_l"]
	_parts["sh_r"] = _bones["sh_r"]
	_parts["hips"] = _bones["hips"]
	_parts["hat"] = Node3D.new()
	_pivot.add_child(_parts["hat"] as Node3D)
	_mats["skin"] = ZombieBody.material("soldier", "skin")
	_mats["coat"] = ZombieBody.material("soldier", "cloth")
	_set_variant_meshes("soldier")
	_build_kind_parts()


func _set_variant_meshes(variant: String) -> void:
	_variant = variant
	for bone: String in ZombieBody.MESH_BONES:
		var mi: MeshInstance3D = _bone_mi[bone]
		mi.mesh = ZombieBody.mesh_for(variant, bone)
		for i: int in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, null)
		mi.show()


## Swap every skin surface for another material (Glasshide).
func _override_skin(m: Material) -> void:
	for bone: String in ZombieBody.MESH_BONES:
		var mi: MeshInstance3D = _bone_mi[bone]
		var am: ArrayMesh = mi.mesh as ArrayMesh
		if am == null:
			continue
		var idx: int = am.surface_find_by_name("skin")
		if idx >= 0:
			mi.set_surface_override_material(idx, m)


func _apply_variant(variant: String) -> void:
	_set_variant_meshes(variant)
	_head_popped = false
	(_bones["head"] as Node3D).show()
	for d: MeshInstance3D in _decals:
		d.hide()
	# per-spawn asymmetry: nobody walks the same way
	_asym = {
		"tilt": randf_range(-0.28, 0.28), "yaw": randf_range(-0.2, 0.2),
		"hang_l": randf_range(-0.25, 0.3), "hang_r": randf_range(-0.25, 0.3),
		"limp": randf_range(0.0, 1.0) if randf() < 0.45 else 0.0, "limp_side": -1.0 if randf() < 0.5 else 1.0,
		"hunch": randf_range(0.0, 0.28), "jaw": randf_range(0.05, 0.45), "phase": randf() * TAU,
		"spine_roll": randf_range(-0.08, 0.08),
	}
	var s: float = 1.0 + randf_range(-0.06, 0.06)
	_pivot.scale = Vector3.ONE * s
	_phase = float(_asym["phase"])


## Shows the variant's extra pieces (crystal plates, lantern) and adjusts the body.
func _apply_kind() -> void:
	(_kind_nodes["glass"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["glass_arm"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["lantern"] as Node3D).visible = enemy_id == &"bellringer"
	_lantern_light.light_energy = 1.6 if enemy_id == &"bellringer" else 0.0
	match enemy_id:
		&"bellringer":
			_set_variant_meshes("bellringer")
			_pivot.scale = Vector3.ONE * 1.04
			_asym["hunch"] = 0.35
		&"glasshide":
			_override_skin(ZombieBody.material("_", "skin_glass"))
			_pivot.scale = Vector3.ONE * 1.1
	_mats["skin"] = ZombieBody.material(_variant, "skin")
	_mats["coat"] = ZombieBody.material(_variant, "cloth")


func _build_kind_parts() -> void:
	var glass: Node3D = Node3D.new()
	glass.name = "GlassPlates"
	(_bones["chest"] as Node3D).add_child(glass)
	var crystal: Array = []
	# chest plates and a jagged cluster growing out of one shoulder (reads at 30 m)
	# overlapping angled crystal plates grown through the coat (front and back), not one slab
	for k: int in 6:
		var fx: float = -0.12 + 0.05 * float(k)
		crystal.append(ZombieBody._box(Vector3(0.11, 0.16 + 0.03 * float(k % 3), 0.03), Vector3(fx, 0.12 + 0.03 * float(k % 2), -0.125),
			"crystal", Vector3(0.25 + 0.1 * float(k % 2), 0.3 * (float(k % 3) - 1.0), 0.4 * (float(k % 2) - 0.5))))
	for k2: int in 4:
		crystal.append(ZombieBody._cyl(0.0, 0.04, 0.2, Vector3(-0.1 + 0.07 * float(k2), 0.2, 0.12), "crystal", Vector3(-1.1, 0, 0.3 * (float(k2) - 1.5)), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.055, 0.5, Vector3(0.2, 0.48, 0), "crystal", Vector3(0, 0, -0.45), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.04, 0.34, Vector3(0.3, 0.4, 0.07), "crystal", Vector3(0.3, 0, -0.9), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.035, 0.3, Vector3(0.12, 0.43, -0.09), "crystal", Vector3(-0.4, 0, -0.2), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.03, 0.24, Vector3(-0.06, 0.3, 0.16), "crystal", Vector3(-0.9, 0, 0.3), Vector3.ONE, 4))
	var gm: MeshInstance3D = MeshInstance3D.new()
	gm.mesh = ZombieBody.build_mesh("_", crystal)
	glass.add_child(gm)
	_kind_nodes["glass"] = glass
	var glass_arm: Node3D = Node3D.new()
	(_bones["el_r"] as Node3D).add_child(glass_arm)
	var gm2: MeshInstance3D = MeshInstance3D.new()
	gm2.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._cyl(0.0, 0.035, 0.22, Vector3(0.04, -0.12, 0), "crystal", Vector3(0, 0, -1.1), Vector3.ONE, 4),
		ZombieBody._cyl(0.0, 0.03, 0.18, Vector3(-0.03, -0.18, -0.03), "crystal", Vector3(0.8, 0, 0.9), Vector3.ONE, 4)])
	glass_arm.add_child(gm2)
	_kind_nodes["glass_arm"] = glass_arm
	var lantern: Node3D = Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0, -0.06, -0.02)
	(_bones["hand_r"] as Node3D).add_child(lantern)
	var lm: MeshInstance3D = MeshInstance3D.new()
	lm.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._box(Vector3(0.012, 0.12, 0.012), Vector3(0, -0.03, 0), "metal"),
		ZombieBody._cyl(0.06, 0.07, 0.03, Vector3(0, -0.1, 0), "metal", Vector3.ZERO, Vector3.ONE, 8),
		ZombieBody._cyl(0.055, 0.055, 0.15, Vector3(0, -0.19, 0), "lens", Vector3.ZERO, Vector3.ONE, 8),
		ZombieBody._cyl(0.07, 0.065, 0.03, Vector3(0, -0.28, 0), "metal", Vector3.ZERO, Vector3.ONE, 8)])
	lantern.add_child(lm)
	var flame: MeshInstance3D = Interactable.add_box(lantern, Vector3(0.04, 0.07, 0.04), Vector3(0, -0.19, 0), Interactable.greybox_mat(Color(1.0, 0.65, 0.25), 6.0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.7, 0.35)
	_lantern_light.omni_range = 6.0
	_lantern_light.light_energy = 0.0
	_lantern_light.shadow_enabled = false
	_lantern_light.position = Vector3(0, -0.19, 0)
	lantern.add_child(_lantern_light)
	_kind_nodes["lantern"] = lantern


## A burst of glass shards (Glasshide shatter, Bellringer death, portal). Presentation only.
func _shards(color: Color, amount: int, speed_max: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed_max * 0.4
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0, -9.0, 0)
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3(0.05, 0.08, 0.02)
	m.material = Interactable.greybox_mat(color, 3.0)
	p.mesh = m
	host.add_child(p)
	p.global_position = global_position + Vector3.UP * 1.1
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _death_burst() -> void:
	match enemy_id:
		&"glasshide":
			_shards(Color(0.6, 0.3, 1.0), 40, 6.0)
			AudioDirector.play_3d("glasshide_shatter", global_position + Vector3.UP, 2.0)
			# Flying shards hurt nearby Gangers a little (never players). Host-side only.
			if director != null and not puppet:
				for z: Zombie in (director as ZombieDirector).active_zombies():
					if z != self and z.enemy_id == &"ganger" and z.global_position.distance_to(global_position) <= float(_cfg.get("shatter_radius", 1.5)):
						z.take_damage(float(_cfg.get("shatter_damage", 50)), &"torso", &"glass_shard", 0, &"world")
		&"bellringer":
			_shards(Color(1.0, 0.65, 0.3), 24, 4.0)
			_lantern_light.light_energy = 0.0
			AudioDirector.play_3d("glasshide_shatter", global_position + Vector3.UP, -6.0)   # the lantern breaks


## The violet flash of a fog portal opening.
func _portal_flash() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.65, 0.3, 1.0)
	l.omni_range = 7.0
	l.light_energy = 5.0
	host.add_child(l)
	l.global_position = global_position + Vector3.UP * 1.2
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	_shards(Color(0.6, 0.3, 1.0), 16, 3.0)
	AudioDirector.play_3d("bellringer_lantern", global_position + Vector3.UP * 1.2, 4.0)


func _set_crawl_pose(crawl: bool) -> void:
	var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
	if crawl:
		for b: String in ["thigh_l", "thigh_r"]:
			(_bones[b] as Node3D).hide()
		for hb: Hitbox in _hitboxes:
			if hb.limb == &"legs":
				hb.collision_layer = 0
		_pivot.rotation.x = -1.35
		_pivot.position = Vector3(0, 0.0, 0.75)
		cap.height = 0.7
		cap.radius = 0.3
		_collision.position = Vector3(0, 0.35, 0)
	else:
		for b: String in ["thigh_l", "thigh_r"]:
			(_bones[b] as Node3D).show()
		_pivot.rotation.x = 0.0
		_pivot.position = Vector3.ZERO
		cap.height = 1.75
		_collision.position = Vector3(0, 0.875, 0)


# ---------------------------------------------------------------- gore (presentation only)

## Throws a copy of one bone mesh away from the body (head pops, severed legs).
func _gib(bone: String, impulse: Vector3, life: float) -> void:
	var host: Node = get_parent()
	var src: Node3D = _bones[bone]
	if host == null or not _bone_mi.has(bone):
		return
	var body: RigidBody3D = RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 3.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = 0.09
	cs.shape = sh
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = (_bone_mi[bone] as MeshInstance3D).mesh
	mi.scale = _pivot.scale
	body.add_child(mi)
	if bone.begins_with("thigh"):
		var shin: MeshInstance3D = MeshInstance3D.new()
		shin.mesh = (_bone_mi["shin" + bone.substr(5)] as MeshInstance3D).mesh
		shin.position = Vector3(0, -0.44, 0) * _pivot.scale.y
		shin.scale = _pivot.scale
		body.add_child(shin)
	host.add_child(body)
	body.global_transform = src.global_transform
	body.linear_velocity = impulse
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	host.get_tree().create_timer(life).timeout.connect(body.queue_free)


func _pop_head() -> void:
	if _head_popped:
		return
	_head_popped = true
	AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 1.7)
	var head: Node3D = _bones["head"]
	var away: Vector3 = (global_position - (target.global_position if target != null else global_position + global_basis.z)).normalized()
	_gib("head", Vector3(away.x * 3.0, 4.5, away.z * 3.0), 6.0)
	head.hide()
	for i: int in 3:
		Effects.blood(head.global_position, Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)))


## A wound decal on the struck limb (cheap quads, recycled per zombie).
func _wound(limb: StringName) -> void:
	var choices: Array = []
	match limb:
		&"head":
			choices = ["head"]
		&"neck":
			choices = ["neck"]
		&"torso":
			choices = ["chest", "abdomen"]
		&"arms":
			choices = ["sh_l", "sh_r", "el_l", "el_r"]
		&"legs":
			choices = ["thigh_l", "thigh_r", "shin_l", "shin_r"]
		_:
			choices = ["chest"]
	var bone: Node3D = _bones[choices[randi() % choices.size()]]
	var d: MeshInstance3D
	if _decals.size() < 6:
		d = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		d.mesh = q
		d.material_override = ZombieBody.blood_material()
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decals.append(d)
	else:
		d = _decals[_decal_i % _decals.size()]
		_decal_i += 1
	if d.get_parent() != bone:
		if d.get_parent() != null:
			d.get_parent().remove_child(d)
		bone.add_child(d)
	var a: float = randf() * TAU
	var up: bool = bone.name == "chest" or bone.name == "abdomen" or bone.name == "head" or bone.name == "neck"
	var r: float = 0.14 if bone.name == "chest" else (0.12 if bone.name == "head" else 0.07)
	var y: float = randf_range(0.05, 0.25) if up else -randf_range(0.05, 0.35)
	var out: Vector3 = Vector3(cos(a), 0, sin(a))
	d.position = out * r + Vector3(0, y, 0)
	d.basis = Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * randf_range(0.07, 0.15))
	d.show()


# ---------------------------------------------------------------- animation

func _bone(n: String) -> Node3D:
	return _bones[n]


func _animate(dt: float) -> void:
	if state == State.INACTIVE:
		return
	ZombieBody.update_cracks(RoundManager.current_round, float(GLData.table("enemies").get("visual", {}).get("crack_energy", 2.6)))
	var g: Array = TIER_GAIT.get(tier, TIER_GAIT[&"walk"])
	var spd: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW] and spd > 0.2
	if is_crawler:
		_phase += dt * (2.2 + spd * 3.0)
	elif moving:
		_phase += dt * PI * spd / float(g[0])
	var t: float = Time.get_ticks_msec() * 0.001
	var p: float = _phase
	var hip_a: float = float(g[1])
	var knee_a: float = float(g[2])
	var lean: float = float(g[3]) + float(_asym.get("hunch", 0.0))
	var bob: float = float(g[4])
	var mode: int = int(g[5])
	var limp: float = float(_asym.get("limp", 0.0))
	var limp_side: float = float(_asym.get("limp_side", 1.0))
	# --- rest values
	var hips_y: float = 0.95
	var hips_roll: float = 0.0
	var hips_x: float = 0.0
	var ab_x: float = -lean * 0.35
	var ch_x: float = -lean * 0.65
	var ch_y: float = 0.0
	var ch_z: float = float(_asym.get("spine_roll", 0.0))
	var nk_x: float = lean * 0.55
	var hd_x: float = 0.15
	var hd_z: float = float(_asym.get("tilt", 0.0))
	var hd_y: float = float(_asym.get("yaw", 0.0))
	var jaw: float = float(_asym.get("jaw", 0.2))
	var tl: float = 0.0
	var tr: float = 0.0
	var kl: float = -0.06
	var kr: float = -0.06
	var sl: Vector3 = Vector3(1.0 + float(_asym.get("hang_l", 0.0)), 0, -0.08)
	var sr: Vector3 = Vector3(1.0 + float(_asym.get("hang_r", 0.0)), 0, 0.08)
	var el: float = 0.3
	var er: float = 0.3
	# --- locomotion
	if moving and not is_crawler:
		var amp_l: float = hip_a * (1.0 - limp * 0.6 * (1.0 if limp_side < 0.0 else 0.0))
		var amp_r: float = hip_a * (1.0 - limp * 0.6 * (1.0 if limp_side > 0.0 else 0.0))
		tl = sin(p) * amp_l
		tr = sin(p + PI) * amp_r
		kl = -knee_a * maxf(0.0, cos(p)) - 0.08
		kr = -knee_a * maxf(0.0, cos(p + PI)) - 0.08
		if tier == &"shamble":
			# dragged foot: the limp side barely lifts
			if limp_side < 0.0:
				kl *= 0.25
			else:
				kr *= 0.25
			hips_roll = sin(p) * 0.12
			ch_z += -sin(p) * 0.1
		hips_y -= bob * (0.5 + 0.5 * cos(2.0 * p)) + limp * 0.04 * maxf(0.0, sin(p) * limp_side)
		ch_y = sin(p) * 0.12
		match mode:
			0:
				sl.x = 0.55 + float(_asym.get("hang_l", 0.0)) + sin(p) * 0.12
				sr.x = 0.45 + float(_asym.get("hang_r", 0.0)) - sin(p) * 0.12
				el = 0.35
				er = 0.25
			1:
				sl.x = 1.25 + sin(p * 0.5 + 1.0) * 0.12
				sr.x = 1.2 - sin(p * 0.5) * 0.12
				el = 0.3
				er = 0.4
			2:
				sl.x = 1.3 + sin(p) * 0.35
				sr.x = 1.3 - sin(p) * 0.35
				el = 0.75
				er = 0.75
			3:
				sl.x = 1.5 + sin(p) * 0.5
				sr.x = 1.5 - sin(p) * 0.5
				el = 0.95
				er = 0.95
				hd_x -= 0.15
			4:
				sl.x = 1.4 + sin(p * 1.7) * 0.8
				sr.x = 1.4 + sin(p * 1.7 + 2.1) * 0.8
				sl.z = -0.3 + sin(p * 2.3) * 0.3
				sr.z = 0.3 + sin(p * 2.1) * 0.3
				el = 1.0 + sin(p * 3.1) * 0.4
				er = 1.0 + cos(p * 2.7) * 0.4
				hd_z += sin(t * 17.0) * 0.12
				jaw = 0.55
	elif not moving and not is_crawler:
		# idle sway
		hips_roll = sin(t * 1.3 + _phase) * 0.04
		ch_x += sin(t * 0.9 + _phase) * 0.04
		hd_z += sin(t * 0.7 + _phase) * 0.08
		sl.x = 0.95 + sin(t * 1.1) * 0.06 + float(_asym.get("hang_l", 0.0))
		sr.x = 0.9 + sin(t * 1.2 + 1.0) * 0.06 + float(_asym.get("hang_r", 0.0))
	# --- crawler pull-along (pivot already pitched forward by the crawl pose)
	if is_crawler and state != State.DEAD:
		var c: float = sin(p)
		sl = Vector3(2.5 + c * 0.55, 0, -0.35)
		sr = Vector3(2.5 - c * 0.55, 0, 0.35)
		el = 0.25 + maxf(0.0, -c) * 0.9
		er = 0.25 + maxf(0.0, c) * 0.9
		nk_x = 0.9
		hd_x = 0.35
		hips_roll = c * 0.1
		ch_x = 0.15
		ab_x = 0.1
		jaw = 0.5
	# --- actions
	match state:
		State.ATTACK:
			var w: float = float(_cfg["attack_windup"])
			if _state_t < w:
				var k: float = clampf(_state_t / w, 0.0, 1.0)
				sl.x = lerpf(sl.x, 2.75, k)
				sr.x = lerpf(sr.x, 2.6, k)
				el = lerpf(el, 0.9, k)
				er = lerpf(er, 0.9, k)
				ch_x += 0.22 * k
				jaw = 0.6
			else:
				var k2: float = clampf((_state_t - w) / 0.16, 0.0, 1.0)
				sl.x = lerpf(2.75, 0.45, k2)
				sr.x = lerpf(2.6, 0.55, k2)
				el = lerpf(0.9, 0.15, k2)
				er = lerpf(0.9, 0.15, k2)
				ch_x -= 0.45 * k2
				ch_y = 0.25 * k2
		State.TEAR:
			var k3: float = sin(_state_t * 6.5)
			_yank = maxf(0.0, _yank - dt * 2.5)
			sl = Vector3(1.6 + k3 * 0.18, 0, -0.15)
			sr = Vector3(1.6 - k3 * 0.18, 0, 0.15)
			el = 0.5 - k3 * 0.3
			er = 0.5 + k3 * 0.3
			ch_x = -0.25 + k3 * 0.12 + _yank
			ab_x = -0.1 + _yank * 0.5
			jaw = 0.5
		State.WAIT_WINDOW:
			if not moving:
				sl.x = 1.6
				sr.x = 1.45
				jaw = 0.4
		State.CLIMB:
			ch_x = -0.75
			ab_x = -0.3
			sl = Vector3(1.0, 0, -0.2)
			sr = Vector3(1.1, 0, 0.2)
			el = 0.2
			er = 0.2
			tl = 1.45
			kl = -1.6
			tr = -0.15
			kr = -0.3
		State.EMERGE:
			sl.x = 2.65 + sin(_state_t * 8.0) * 0.35
			sr.x = 2.45 + cos(_state_t * 8.0) * 0.35
			el = 0.6
			er = 0.7
			ch_x = -0.3
			hd_x = -0.3
			jaw = 0.7
		State.STAGGER:
			ch_x += 0.4
			hd_x -= 0.45
			sl.x = 0.35
			sr.x = 0.5
			ch_y = 0.3 * _flinch_dir
		State.DEAD:
			_pose_dead(dt)
			return
	# flinch overlay
	if _flinch > 0.0:
		_flinch = maxf(0.0, _flinch - dt)
		var fk: float = _flinch / 0.18
		ch_x += 0.3 * fk
		ch_y += 0.35 * fk * _flinch_dir
		hd_x -= 0.4 * fk
	# --- apply (smoothed so state changes don't snap)
	var a: float = clampf(dt * 14.0, 0.0, 1.0)
	var hips: Node3D = _bone("hips")
	hips.position.y = lerpf(hips.position.y, hips_y, a)
	hips.rotation = hips.rotation.lerp(Vector3(hips_x, 0, hips_roll), a)
	_lerp_rot("abdomen", Vector3(ab_x, ch_y * 0.4, ch_z * 0.5), a)
	_lerp_rot("chest", Vector3(ch_x, ch_y, ch_z), a)
	_lerp_rot("neck", Vector3(nk_x, 0, 0), a)
	_lerp_rot("head", Vector3(hd_x, hd_y, hd_z), a)
	_lerp_rot("jaw", Vector3(jaw * 0.6, 0, 0), a)
	if not is_crawler:
		_lerp_rot("thigh_l", Vector3(tl, 0, 0.03), a)
		_lerp_rot("thigh_r", Vector3(tr, 0, -0.03), a)
		_lerp_rot("shin_l", Vector3(kl, 0, 0), a)
		_lerp_rot("shin_r", Vector3(kr, 0, 0), a)
	_lerp_rot("sh_l", sl, a)
	_lerp_rot("sh_r", sr, a)
	_lerp_rot("el_l", Vector3(el, 0, 0), a)
	_lerp_rot("el_r", Vector3(er, 0, 0), a)


func _lerp_rot(n: String, r: Vector3, a: float) -> void:
	var b: Node3D = _bones[n]
	b.rotation = b.rotation.lerp(r, a)


## Death falls: 0 backward, 1 forward, 2 crumple to the knees then forward, 3 twist and fall sideways.
func _pose_dead(dt: float) -> void:
	var t: float = _state_t
	var a: float = clampf(dt * 10.0, 0.0, 1.0)
	if is_crawler:
		_lerp_rot("sh_l", Vector3(2.2, 0, -0.6), a)
		_lerp_rot("sh_r", Vector3(1.8, 0, 0.7), a)
		_lerp_rot("neck", Vector3(-0.2, 0, 0.4), a)
		return
	var k: float = clampf(t / 0.75, 0.0, 1.0)
	var e: float = k * k
	match _death_kind:
		0:
			_pivot.rotation.x = lerpf(0.0, 1.5, e)
			_lerp_rot("thigh_l", Vector3(0.6, 0, 0.1), a)
			_lerp_rot("thigh_r", Vector3(0.2, 0, -0.15), a)
			_lerp_rot("shin_l", Vector3(-0.9, 0, 0), a)
			_lerp_rot("sh_l", Vector3(2.4, 0, -0.9), a)
			_lerp_rot("sh_r", Vector3(2.0, 0, 1.0), a)
			_lerp_rot("head", Vector3(-0.5, 0.3, 0), a)
		1:
			_pivot.rotation.x = lerpf(0.0, -1.45, e)
			_lerp_rot("sh_l", Vector3(0.3, 0, -0.3), a)
			_lerp_rot("sh_r", Vector3(2.6, 0, 0.4), a)
			_lerp_rot("head", Vector3(0.3, -0.5, 0.2), a)
		2:
			var kneel: float = clampf(t / 0.35, 0.0, 1.0)
			_pivot.position.y = lerpf(0.0, -0.42, kneel)
			_lerp_rot("thigh_l", Vector3(1.4, 0, 0.1), a)
			_lerp_rot("thigh_r", Vector3(1.3, 0, -0.1), a)
			_lerp_rot("shin_l", Vector3(-2.3, 0, 0), a)
			_lerp_rot("shin_r", Vector3(-2.2, 0, 0), a)
			_lerp_rot("sh_l", Vector3(0.2, 0, -0.2), a)
			_lerp_rot("sh_r", Vector3(0.1, 0, 0.2), a)
			if t > 0.45:
				_pivot.rotation.x = lerpf(_pivot.rotation.x, -1.25, clampf(dt * 5.0, 0.0, 1.0))
				_pivot.position.y = lerpf(_pivot.position.y, -0.62, clampf(dt * 5.0, 0.0, 1.0))
			_lerp_rot("head", Vector3(0.6, 0, 0.3), a)
		_:
			_pivot.rotation.z = lerpf(0.0, 1.45 * _death_side, e)
			_pivot.rotation.y = lerpf(0.0, 0.6 * _death_side, k)
			_lerp_rot("chest", Vector3(-0.2, 0.5 * _death_side, 0), a)
			_lerp_rot("sh_l", Vector3(1.6, 0, -1.2), a)
			_lerp_rot("sh_r", Vector3(0.6, 0, 0.6), a)
	_lerp_rot("jaw", Vector3(0.5, 0, 0), a)


func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(2.5, 3.5) if tier == &"sprint" else randf_range(3.5, 8.0)
		var snd: String = "zombie_sprint" if tier == &"sprint" else "zombie_groan"
		if enemy_id == &"bellringer":
			snd = "bellringer_wheeze"
		AudioDirector.play_3d(snd, global_position + Vector3.UP * 1.6, -6.0, 0.0)
	# Glasshide grinding / Bellringer lantern-chain jingle.
	_ring_t -= delta
	if _ring_t <= 0.0 and (enemy_id == &"glasshide" or enemy_id == &"bellringer"):
		_ring_t = 1.6 if enemy_id == &"glasshide" else 0.45
		var ring_key: String = "glasshide_grind" if enemy_id == &"glasshide" else "bellringer_lantern"
		AudioDirector.play_3d(ring_key, global_position + Vector3.UP, -8.0, 0.0)
	_update_steps(delta)


## Shuffling footsteps while moving: throttled per zombie, culled by distance to its target player, and
## rate-capped across the whole horde (the bank's max_voices steals the rest).
func _update_steps(delta: float) -> void:
	_zstep_t -= delta
	if _zstep_t > 0.0:
		return
	_zstep_t = STEP_INTERVAL * randf_range(0.85, 1.15) * (0.7 if tier == &"sprint" else 1.0)
	if is_crawler or (not puppet and not is_on_floor()) or velocity.x * velocity.x + velocity.z * velocity.z < 0.25:
		return
	if target == null or global_position.distance_squared_to(target.global_position) > STEP_RANGE_SQ:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_step_msec < STEP_GAP_MSEC:
		return
	_last_step_msec = now
	AudioDirector.play_3d("zombie_step", global_position, 0.0, 0.0)


# ---------------------------------------------------------------- co-op puppet (client side, M7)

func make_puppet() -> void:
	puppet = true
	interp = InterpBuffer.new()
	if _agent != null:
		_agent.avoidance_enabled = false


func variant_name() -> String:
	return _variant


## Sub-state for the snapshot (the bosses' own state machines); 0 for the shared one.
func net_sub_state() -> int:
	return 0


## The host spawned this zombie: dress it the same way and start following the snapshots.
func puppet_activate(enemy: StringName, tier_v: StringName, variant: String, hp_max: float, pos: Vector3, yaw: float,
		st: int, sub: int, local_p: Player) -> void:
	enemy_id = enemy
	_cfg = kind_config(enemy_id)
	tier = tier_v
	max_hp = hp_max
	hp = hp_max
	_pred_dmg = 0.0
	is_crawler = false
	is_last = false
	_burn_t = 0.0
	armor_torso_mult = float(_cfg.get("armor_mult", 1.0))
	target = local_p
	_set_crawl_pose(false)
	_apply_variant(variant)
	_apply_kind()
	_puppet_show(pos, yaw)
	state = State.CHASE
	_puppet_enter(st, sub)
	if tier == &"sprint":
		AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0)
	if enemy_id == &"bellringer":
		_portal_flash()
	GLBus.enemy_spawned.emit(enemy_id, get_instance_id())


func _puppet_show(pos: Vector3, yaw: float) -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	interp.snap(float(Time.get_ticks_msec()), pos, yaw)


## Follows the host's state machine (sounds and poses tied to entering a state play here too).
func _puppet_enter(st: int, _sub: int) -> void:
	var s: State = st as State
	if s == State.INACTIVE or s == State.DEAD or s == state:
		return
	_enter(s)


func _puppet_tick(delta: float) -> void:
	if state == State.DEAD:
		_puppet_dead(delta)
		return
	if state == State.INACTIVE:
		return
	_state_t += delta
	_pred_dmg *= exp(-delta * 4.0)
	if Net.session != null and interp.sample(Net.session.render_time_ms()):
		var prev: Vector3 = global_position
		global_position = interp.pos
		rotation.y = interp.yaw
		velocity = (global_position - prev) / maxf(delta, 0.0001)
		velocity.y = 0.0
		var zf: int = (interp.flags >> 8) & 0xFF
		hp = max_hp * float((interp.aux >> 8) & 0xFF) / 255.0
		is_last = (zf & NetMatch.ZF_LAST) != 0
		if (zf & NetMatch.ZF_CRAWL) != 0 and not is_crawler:
			Net.applying = true
			become_crawler()
			Net.applying = false
		_puppet_enter(interp.flags & 0xFF, interp.aux & 0xFF)
	_puppet_visual_tick(delta)
	_update_audio(delta)


func _puppet_visual_tick(_delta: float) -> void:
	if state == State.EMERGE:
		var t: float = clampf(_state_t / (0.7 if enemy_id == &"bellringer" else 1.4), 0.0, 1.0)
		_pivot.position.y = lerpf(-1.7, 0.0, t * t * (3.0 - 2.0 * t))
	elif not is_crawler and _pivot.position.y < 0.0:
		_pivot.position.y = 0.0


func _puppet_dead(delta: float) -> void:
	_state_t += delta
	_update_dead(delta)


## A hit from this client's own weapon: wounds, flinch and the hit marker now (predicted); the host decides.
func _puppet_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName, armor_piercing: bool) -> bool:
	if not is_active() or Net.session == null or by_player != Net.local_player_id() or Net.applying:
		return false
	Net.session.send_hit(self, amount, limb, weapon_id, kind, armor_piercing)
	var eff: float = amount
	if (limb == &"torso" or limb == &"arms") and kind == &"bullet" and not armor_piercing:
		eff *= armor_torso_mult
	if GameState.has_flag(&"deaths_door") and kind != &"world":
		eff = hp + 1.0
	_pred_dmg += eff
	if kind != &"fire" and kind != &"world":
		_wound(limb)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	_flinch = 0.18
	_flinch_dir = -1.0 if randf() < 0.5 else 1.0
	return hp - _pred_dmg <= 0.0


## The host's death: the same fall, the same head pop, at the host's position.
func puppet_die(_limb: StringName, _kind: StringName, death_kind: int, side: float, pop: bool, pos: Vector3) -> void:
	if state == State.DEAD or state == State.INACTIVE:
		return
	if pos.is_finite():
		global_position = pos
	_puppet_hide_hitboxes()
	AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.2, -1.0)
	_death_burst()
	state = State.DEAD
	_state_t = 0.0
	_death_kind = death_kind
	_death_side = side
	if pop:
		_pop_head()


func _puppet_hide_hitboxes() -> void:
	collision_layer = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	velocity = Vector3.ZERO


## Removed on the host without a death (recycled, round skipped).
func puppet_gone() -> void:
	if state == State.INACTIVE:
		return
	deactivate()
	if net_id >= NetMatch.EXTRA_ID_BASE:
		queue_free()


## A one-off presentation event from the host (boss attacks).
func puppet_fx(_what: StringName, _args: Array) -> void:
	pass
