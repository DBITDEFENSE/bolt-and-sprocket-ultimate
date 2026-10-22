class_name Zombie
extends CharacterBody3D
## Gänger: the standard undead, plus the pooled variants that share its body and state machine:
## Glasshide (crystal-plated, torso armor) and Bellringer (special-round lantern miner, lunge attack).
## Pooled by ZombieDirector, never freed mid-match. Bosses (Foreman, Screamer) subclass this script.
## States: SPAWN -> (window) TO_WINDOW -> WAIT/TEAR -> CLIMB -> CHASE <-> ATTACK, STAGGER, KNOCKDOWN/GETUP,
## CLIMB_LINK (authored climb volumes), DEAD.
## All tuning comes from data/enemies.json; health and tier come from the RoundManager spawn spec.
##
## Animation (MZ, T-041, docs/ZOMBIE_ANIM_SPEC.md): the body is a procedural skinned mesh on the shared ZombieRig
## skeleton, driven by an AnimationTree (ZombieClips) whose parameters this script sets from the state machine:
## locomotion matched to the nav velocity by time scale (root motion = nav speed, no foot-sliding), per-instance
## clip picks, posture trait and start phase, additive flinches with hit springs, foot IK and head look-at within
## range, authored deaths into a ragdoll, dismemberment (ZombieGore), outfit kits and the infection shader
## (ZombieBody). Everything tunable lives in data/gravelight/anim.json.
##
## Co-op (M7): the host simulates every zombie. On a client each zombie is a *puppet* (`puppet = true`): no AI,
## no navigation; it is placed from interpolated snapshots, animates from the replicated state, and plays its
## death from the host's death event (variant, side, head pop). Damage from the client's own weapons is
## predicted locally (hit markers, wounds) and sent to the host with the shot ray (NetMatch.send_hit).

enum State { INACTIVE, EMERGE, TO_WINDOW, WAIT_WINDOW, TEAR, CLIMB, CHASE, ATTACK, STAGGER, DEAD, KNOCKDOWN, GETUP, CLIMB_LINK }

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 1 << 1
const LAYER_ZBODY: int = 1 << 2
const LAYER_DOOR: int = 1 << 8
const GRAVITY: float = 18.0

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
## The hitbox bone of the last shot that landed (weapon_holder / bot_brain set it before take_damage), for the
## side of arm and leg hits. "" = unknown: a side is rolled.
var last_hit_bone: String = ""
## Co-op replication (see the class doc).
var net_id: int = -1
var puppet: bool = false
var net_died: bool = false
var interp: InterpBuffer = null
var _pred_dmg: float = 0.0

var _cfg: Dictionary = {}
var _anim: Dictionary = {}
var _agent: NavigationAgent3D
var _safe_vel: Vector3 = Vector3.ZERO
var _pivot: Node3D
var _parts: Dictionary = {}       # name -> Node3D (the Foreman's own parts)
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
var _phase: float = 0.0           # the Foreman's own walk cycle (foreman.gd); the shared body uses the tree
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
var _vuln_mult: float = 1.0        # Bell Dome (Totenglocke, T-048): damage taken x this until _vuln_until_ms
var _vuln_until_ms: int = 0
var _kind_nodes: Dictionary = {}   # "glass" / "lantern" -> Node3D, shown per kind
var _lantern_light: OmniLight3D
var _lunge_dir: Vector3 = Vector3.ZERO
var _ring_t: float = 0.0
## Shared across zombies: the last time any zombie played a footstep (global rate cap for a 24-zombie horde).
static var _last_step_msec: int = 0


func _init() -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	safe_margin = 0.02


func _ready() -> void:
	_cfg = GLData.table("enemies")["enemies"]["ganger"]
	_anim = GLData.table("anim")
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
	_agent.link_reached.connect(_on_link_reached)
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
	_reset_presentation()
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
	_emerge_kind = _emerge_kind_for(spawn)
	if spawn.kind == &"ground":
		_enter(State.EMERGE)
	elif window != null:
		_enter(State.TO_WINDOW)
	else:
		_enter(State.CHASE)
	_random_phase()
	if tier == &"sprint":
		AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0)
	if enemy_id == &"bellringer":
		_portal_flash()


func deactivate() -> void:
	state = State.INACTIVE
	if window != null:
		window.release(self)
	window = null
	_end_ragdoll()
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
			_tear_clip = _pick(_anim["clips"]["tear"])
			_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())
		State.ATTACK:
			_attack_hit_done = false
			_attack_clip = _pick_attack()
			AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, float(_anim["vocals"].get("attack_snarl_db", -2.0)))
			_tree_attack(_attack_clip)
		State.EMERGE:
			_tree_emerge()
		State.STAGGER:
			if _react_clip == "":
				_react_clip = str(_anim["clips"]["react"]["stagger"])
				_react_len = float(_cfg["stagger_seconds"])
			_tree_play("React", _react_clip, ZombieClips.length_of(_react_clip) / maxf(0.05, _react_len))
		State.KNOCKDOWN:
			_getup_restarted = false
			var kd: String = str(_anim["clips"]["react"]["knockdown_front" if _down_front else "knockdown_back"])
			_tree_play("React", kd, 1.0)
		State.GETUP:
			var gu: String = str(_anim["clips"]["react"]["getup_front" if _down_front else "getup_back"])
			_tree_play("React", gu, 1.0)
		State.CLIMB:
			_tree_play("Climb", _climb_clip, ZombieClips.length_of(_climb_clip) / maxf(0.1, _climb_dur()))
		State.CLIMB_LINK:
			_tree_play("Climb", str(_anim["clips"]["climb"]["loop"]), 1.0)
		State.DEAD:
			_tree_play("Death", _death_clip, 1.0)
		State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW:
			_tree_locomotion(true)


# ---------------------------------------------------------------- frame update

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	_state_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	match state:
		State.EMERGE:
			if _state_t >= _emerge_seconds():
				_enter(State.CHASE)
			else:
				_halt(delta)
		State.TO_WINDOW:
			_update_to_window(delta)
		State.WAIT_WINDOW:
			_update_wait_window(delta)
		State.TEAR:
			_update_tear(delta)
		State.CLIMB:
			_update_climb(delta)
		State.CLIMB_LINK:
			_update_link_climb(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.STAGGER:
			_halt(delta)
			if _state_t >= _react_len:
				_react_clip = ""
				_enter(State.CHASE)
		State.KNOCKDOWN:
			_halt(delta)
			if _state_t >= float(_anim["knockdown"]["down_seconds"]):
				_enter(State.GETUP)
		State.GETUP:
			_halt(delta)
			if _state_t >= float(_anim["knockdown"]["getup_seconds"]):
				_enter(State.CHASE)
		State.DEAD:
			_update_dead(delta)
	if state != State.DEAD and global_position.y < -30.0:
		recycle()
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	if _grab_t > 0.0:
		_update_grab(delta)
	_update_audio(delta)
	_update_senses(delta)


func _process(delta: float) -> void:
	# Animation LOD: full rate within lod.full_m, half to lod.half_m, quarter beyond (anim.json).
	if state == State.INACTIVE:
		return
	_anim_skip += 1
	var d2: float = global_position.distance_squared_to(target.global_position) if target != null else 0.0
	var lod: Dictionary = _anim["lod"]
	var div: int = 1
	if d2 > float(lod["half_m"]) * float(lod["half_m"]):
		div = 4
	elif d2 > float(lod["full_m"]) * float(lod["full_m"]):
		div = 2
	if _anim_skip % div != 0:
		return
	_animate(delta * float(div))


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
	if _swipe_t > 0.0:
		_swipe_t -= delta
		if _swipe_t <= 0.0:
			_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())
	if _tear_t > 0.0:
		return
	if window.boards > 0:
		window.tear_board()
		_tear_t = _tear_interval()
		AudioDirector.play_3d("zombie_groan", global_position + Vector3.UP * 1.5, float(_anim["vocals"].get("rip_db", -4.0)), 0.1)
	else:
		_start_climb()


## The reach-through swipe: the window_swipe clip plays over the tear, the hit lands at the windup if the
## player is still at the boards and the hand reaches them (anim.json attack.window_reach_m / hand_reach_m).
func _window_swipe() -> void:
	AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, -2.0)
	var t: Player = target
	var clip: String = str(_anim["clips"]["attack"]["window"])
	_tree_attack(clip)
	_swipe_t = ZombieClips.length_of(clip) * float(_cfg["attack_windup"]) / ZombieClips.ATTACK_WINDUP
	var tw: Tween = create_tween()
	tw.tween_interval(float(_cfg["attack_windup"]))
	tw.tween_callback(func() -> void:
		if is_active() and window != null and is_instance_valid(t) and _window_reach_ok(t, 0.2) and _hand_reaches(t):
			t.take_hit(float(_cfg["damage"]), self))


## The reach-through hitbox: the swinging hand must get within attack.hand_reach_m of the player's chest.
func _hand_reaches(t: Player) -> bool:
	var hand: Node3D = bone_attachment("RightHand")
	if hand == null:
		return true
	var reach: float = float(_anim["attack"].get("hand_reach_m", 0.75)) + float(_anim["attack"].get("window_reach_m", 0.95))
	return hand.global_position.distance_to(t.global_position + Vector3.UP * 1.2) <= reach


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
		_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())


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
	var high: bool = _climb_mid.y - _climb_to.y > float(_anim["climb"].get("high_window_m", 1.2))
	_climb_clip = str(_anim["clips"]["drop"]) if high else _pick(_anim["clips"]["vault"])
	_enter(State.CLIMB)


func _climb_dur() -> float:
	return float(_cfg["climb_seconds"]) * (1.6 if is_crawler else 1.0)


func _update_climb(_delta: float) -> void:
	var t: float = clampf(_state_t / _climb_dur(), 0.0, 1.0)
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


# ---------------------------------------------------------------- climb volumes (NavigationLink3D with meta "climb")

## The agent reached a navigation link: a climb link starts the scripted climb (vulnerable, no attacks).
func _on_link_reached(details: Dictionary) -> void:
	if puppet or state != State.CHASE or is_crawler:
		return
	var owner_v: Variant = details.get("owner", null)
	var link: NavigationLink3D = owner_v as NavigationLink3D
	if link == null or not link.has_meta("climb"):
		return
	var start: Vector3 = details.get("link_entry_position", global_position)
	var end: Vector3 = details.get("link_exit_position", global_position)
	if end.y - start.y < 0.5:
		return   # a drop or a flat link: walk it
	_climb_from = start
	_climb_to = end
	_climb_dist = start.distance_to(end)
	collision_mask = 0
	_agent.avoidance_enabled = false
	_enter(State.CLIMB_LINK)


func _update_link_climb(_delta: float) -> void:
	var spd: float = float(_anim["climb"]["speed_mps"])
	var mantle: float = float(_anim["climb"]["mantle_seconds"])
	var dur: float = _climb_dist / maxf(0.2, spd) + mantle
	var t: float = clampf(_state_t / maxf(0.05, dur), 0.0, 1.0)
	global_position = _climb_from.lerp(_climb_to, t)
	var face_to: Vector3 = _climb_to + (_climb_to - _climb_from)
	face_to.y = global_position.y
	_face(face_to)
	if not _mantling and _state_t >= dur - mantle:
		_mantling = true
		_tree_play("Climb", str(_anim["clips"]["climb"]["mantle"]), 1.0)
	if t >= 1.0:
		_mantling = false
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
		_agent.avoidance_enabled = true
		_stuck_origin = global_position
		_enter(State.CHASE)


## Dev / tools: re-tier a live zombie (speed from enemies.json tiers, a fresh locomotion clip for the tier).
func debug_set_tier(t: StringName) -> void:
	tier = t
	speed = float(GLData.table("enemies")["tiers"].get(String(t), speed))
	_agent.max_speed = speed
	_pick_locomotion()


## Dev / tools: start a climb between two points as if a link had been reached.
func debug_climb(from: Vector3, to: Vector3) -> void:
	_climb_from = from
	_climb_to = to
	_climb_dist = from.distance_to(to)
	collision_mask = 0
	_agent.avoidance_enabled = false
	_enter(State.CLIMB_LINK)


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
	if dist <= _attack_range() and absf(to_t.y) < 1.3 and _attack_cd <= 0.0 and _clear_to(target):
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
	# Wedged well above the walkable floor (pushed out of an overlap into a ceiling, etc.): recycle it now.
	_wedge_t = _wedge_t + delta if _off_navmesh_height() > 1.0 else 0.0
	if _wedge_t > 3.0:
		_wedge_t = 0.0
		recycle()
		return
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


func _attack_range() -> float:
	return float(_cfg["attack_range"])


func _update_attack(delta: float) -> void:
	var windup: float = float(_cfg["attack_windup"])
	var lunging: bool = enemy_id == &"bellringer" or _attack_clip == str(_anim["clips"]["attack"]["lunge"])
	if lunging and _state_t >= windup * 0.5 and _state_t < windup + 0.15 and target != null:
		# Lunge: a short leap at the target during the windup.
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		var leap: float = float(_cfg.get("lunge_distance", 2.0 if enemy_id == &"bellringer" else 1.2)) / maxf(0.05, windup * 0.5 + 0.15)
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
			if d <= _attack_range() + 0.5 and _clear_to(target):
				target.take_hit(float(_cfg["damage"]), self)
				if _cfg.has("hit_slow"):
					target.apply_status(&"shard_slow", float(_cfg.get("hit_slow_seconds", 0.5)))
				if enemy_id == &"bellringer":
					AudioDirector.play_3d("bellringer_lantern", global_position + Vector3.UP * 1.4, 2.0)
				if _attack_clip == str(_anim["clips"]["attack"]["grab"]):
					_start_grab(target)
	if _state_t >= windup + 0.35:
		_attack_cd = maxf(0.0, float(_cfg["attack_interval"]) - windup - 0.35)
		_enter(State.CHASE)


## The sprinter grab: the hit pulls the player's view for attack.grab.seconds (cancelled by a melee hit on
## this zombie). Presentation only: the damage is the normal hit.
func _start_grab(t: Player) -> void:
	var g: Dictionary = _anim["attack"]["grab"]
	_grab_target = t
	_grab_t = float(g.get("seconds", 0.4))
	t.kick_camera(float(g.get("pitch_deg", 9.0)), float(g.get("yaw_deg", 22.0)), 0.45, float(g.get("recover", 7.0)), 0.35, 0.0)


func _update_grab(delta: float) -> void:
	_grab_t -= delta
	if _grab_target == null or not is_instance_valid(_grab_target) or not is_active():
		_grab_t = 0.0
		return
	# A steady pull while held: pitch only (kick_camera rolls a fresh yaw sign per call, which per frame is
	# jitter; the opening kick in _start_grab already yanked the yaw) and keep 0, so it all goes into the
	# recoil spring and the view settles back once the grab ends instead of drifting for good.
	var g: Dictionary = _anim["attack"]["grab"]
	_grab_target.kick_camera(float(g.get("pitch_deg", 9.0)) * 2.5 * delta, 0.0, 0.0, float(g.get("recover", 7.0)), 0.0, 0.0)


func _update_dead(delta: float) -> void:
	var rd: Dictionary = _anim["ragdoll"]
	if not _ragdoll_started and _state_t >= float(rd.get("key_pose_seconds", 0.55)):
		_ragdoll_started = true
		_begin_ragdoll()
	if _ragdoll != null:
		ZombieRagdoll.tick()
		ZombieRagdoll.sync(_ragdoll, _skel)
	var corpse: float = _corpse_seconds
	if director != null and director.has_method("free_count") and int(director.call("free_count")) < int(rd.get("pool_pressure_free", 4)):
		corpse = minf(corpse, float(rd.get("pool_pressure_corpse_seconds", 1.6)))
	var dissolve: float = float(rd.get("dissolve_seconds", 1.4))
	if _state_t > corpse:
		_set_inst("inst_dissolve", clampf((_state_t - corpse) / dissolve, 0.0, 1.0))
	if _state_t > corpse + dissolve:
		deactivate()
		if director != null:
			director.call("on_zombie_returned", self)


# ---------------------------------------------------------------- movement helpers

## True while the agent's current path point is a NavigationLink (a door seam between two zone regions): a
## re-path from inside the seam's eroded gap would start back on the region it came from and the zombie would
## shuttle on the spot (playtest T-040), so links are crossed before the path is recomputed.
func _crossing_link() -> bool:
	var res: NavigationPathQueryResult3D = _agent.get_current_navigation_result()
	if res == null:
		return false
	var types: PackedInt32Array = res.get_path_types()
	var i: int = _agent.get_current_navigation_path_index()
	return i > 0 and i < types.size() and types[i] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK


var _link_t: float = 0.0          # seconds spent on the current link point (the re-path hold has a limit)


func _nav_move(goal: Vector3, spd: float, delta: float, repath_interval: float) -> void:
	_repath_t -= delta
	var on_link: bool = _crossing_link()
	_link_t = _link_t + delta if on_link else 0.0
	if _repath_t <= 0.0 and Zombie.repath_budget > 0 and not (on_link and _link_t < 3.0):
		Zombie.repath_budget -= 1
		if director != null:
			_agent.navigation_layers = (director as ZombieDirector).nav_mask
		_agent.target_position = goal
		_repath_t = repath_interval
	var next: Vector3 = _agent.get_next_path_position()
	if _corner_t > 0.0:
		_corner_t -= delta
		if Vector2(_corner_pt.x - global_position.x, _corner_pt.z - global_position.z).length() < 0.12:
			_corner_t = 0.0   # back on the corner: the path's own next point is clear from here
		else:
			next = _corner_pt
	var dir: Vector3 = next - global_position
	if _agent.is_navigation_finished() or (dir.length_squared() < 0.0004 and _corner_t <= 0.0):
		dir = goal - global_position
	dir.y = 0.0
	spd *= frost_speed_mult()
	var desired: Vector3 = dir.normalized() * spd if dir.length_squared() > 0.0001 else Vector3.ZERO
	if _sidestep_t > 0.0:
		_sidestep_t -= delta
		desired = _sidestep_dir * spd
	_agent.max_speed = spd
	if _agent.avoidance_enabled:
		_agent.velocity = desired
	else:
		_safe_vel = desired
	velocity.x = _safe_vel.x
	velocity.z = _safe_vel.z
	_apply_gravity(delta)
	var before: Vector3 = global_position
	move_and_slide()
	# Corner snag: it wants to move but the wall/corner eats all of it -> sidestep at ~75 degrees for a moment,
	# alternating sides, then resume the path (playtest fix, T-028).
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if desired.length() > 0.3 and moved < desired.length() * delta * 0.2 and is_on_floor() and _step_up(desired):
		moved = desired.length() * delta
	if desired.length() > 0.3 and moved < desired.length() * delta * 0.2 and _sidestep_t <= 0.0:
		_blocked_t += delta
		if _blocked_t > 0.5:
			_blocked_t = 0.0
			_start_sidestep(desired)
	else:
		_blocked_t = 0.0
	# Progress over a 0.4 s window (T-057): a body jittering against a rail end moves just enough on some frames
	# to reset the per-frame check above, so it never sidestepped. Snagged -> back onto the corner it cut if
	# there is one, else the sidestep.
	if _sidestep_t <= 0.0 and _corner_t <= 0.0:
		_prog_want += desired.length() * delta
	_prog_t += delta
	if _prog_t >= 0.4:
		var got: float = Vector2(global_position.x - _prog_from.x, global_position.z - _prog_from.z).length()
		if _prog_want > 0.6 and got < _prog_want * 0.25:
			var corner: Vector3 = _skipped_corner()
			if corner != Vector3.INF:
				_corner_pt = corner
				_corner_t = 0.8
			elif _sidestep_t <= 0.0:
				_start_sidestep(desired)
		_prog_t = 0.0
		_prog_want = 0.0
		_prog_from = global_position
	var flat: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if flat.length_squared() > 0.05:
		_face(global_position + flat)


## A small step up (T-057): at the crest of Map 0's staircase the ramp meets the hall floor in a seam the slide
## treats as a wall, and a walker stopped dead there (the stair-head idle near (3, 3.8, 9)). When it's blocked
## on the floor and there's room 0.25 m up and a little ahead, lift it over; gravity and the floor snap set it down.
func _step_up(desired: Vector3) -> bool:
	var fwd: Vector3 = Vector3(desired.x, 0.0, desired.z).normalized() * 0.12
	var up: Vector3 = Vector3.UP * 0.25
	if test_move(global_transform, up):
		return false
	if test_move(global_transform.translated(up), fwd):
		return false
	global_position += up + fwd
	return true


func _start_sidestep(desired: Vector3) -> void:
	if desired.length_squared() < 0.0001:
		return
	_sidestep_side = -_sidestep_side
	_sidestep_dir = desired.normalized().rotated(Vector3.UP, deg_to_rad(75.0) * _sidestep_side)
	_sidestep_t = 0.6


## The path corner the agent has just passed when it's snagged (T-057). NavigationAgent3D moves on to the next
## point once it is within path_desired_distance (0.6 m) of a corner, so a fast zombie turns early and runs into
## what the corner goes round: the stair foot's balustrade end (Map 0, at about (3.6, 0, 14.6)) caught every runner
## heading upstairs. Walking back onto the skipped corner first clears it. INF when there is none worth it.
func _skipped_corner() -> Vector3:
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	var i: int = _agent.get_current_navigation_path_index()
	if i < 1 or i >= path.size():
		return Vector3.INF
	var c: Vector3 = path[i - 1]
	var d: float = Vector2(c.x - global_position.x, c.z - global_position.z).length()
	if d < 0.15 or d > 1.5 or absf(c.y - global_position.y) > 1.0:
		return Vector3.INF
	return c


func _on_velocity_computed(safe: Vector3) -> void:
	_safe_vel = safe


var _wedge_t: float = 0.0
var _blocked_t: float = 0.0
var _corner_t: float = 0.0        # seconds left steering back onto a path corner it cut (T-057)
var _corner_pt: Vector3 = Vector3.ZERO
var _prog_t: float = 0.0          # the 0.4 s progress window (T-057): time in it, metres wanted, where it began
var _prog_want: float = 0.0
var _prog_from: Vector3 = Vector3.ZERO
var _sidestep_t: float = 0.0
var _sidestep_dir: Vector3 = Vector3.ZERO
var _sidestep_side: float = 1.0


## How far this zombie's feet are above the closest walkable navmesh point (about 0 when walking normally).
func _off_navmesh_height() -> float:
	var nav: RID = get_world_3d().navigation_map
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, global_position)
	if Vector2(c.x - global_position.x, c.z - global_position.z).length() > 1.5:
		return 0.0   # nowhere near the mesh horizontally (climbing, scripted moves): not this check's business
	return global_position.y - c.y


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
		_slide_off_zombie()
	else:
		velocity.y -= GRAVITY * delta


## A zombie must never stand on another zombie's head (two emerging on one spot, or a crush at a window):
## it steps off sideways, away from the one beneath (playtest fix, T-027).
func _slide_off_zombie() -> void:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if c.get_normal().y > 0.6 and c.get_collider() is Zombie:
			var under: Node3D = c.get_collider() as Node3D
			var away: Vector3 = global_position - under.global_position
			away.y = 0.0
			if away.length_squared() < 0.0001:
				away = Vector3(cos(float(get_instance_id() % 628) * 0.01), 0, sin(float(get_instance_id() % 628) * 0.01))
			away = away.normalized()
			velocity.x = away.x * 3.0
			velocity.z = away.z * 3.0
			return


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-d.x, -d.z)
	var before: float = rotation.y
	rotation.y = lerp_angle(rotation.y, yaw, 0.25)
	_turn_rate = wrapf(rotation.y - before, -PI, PI) / maxf(0.001, get_physics_process_delta_time())


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


## Bell Dome (Totenglocke alt-fire, T-048): takes `mult` x damage for the next `seconds` (real time; the dome
## refreshes it every tick while the zombie is inside).
func set_vulnerable(mult: float, seconds: float) -> void:
	_vuln_mult = mult
	_vuln_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func vulnerability() -> float:
	return _vuln_mult if _vuln_until_ms > Time.get_ticks_msec() else 1.0


## Interrupts the current attack/chase (Ironmonger stagger rounds).
func force_stagger() -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"stagger")
		return
	if state == State.CHASE or state == State.ATTACK:
		_react_clip = ""
		_enter(State.STAGGER)


func is_burning() -> bool:
	return _burn_t > 0.0


func _update_burn(delta: float) -> void:
	if _burn_t <= 0.0 or not is_active():
		return
	_burn_t -= delta
	_burn_tick -= delta
	_char = minf(1.0, _char + delta * 0.25)
	if _burn_tick <= 0.0:
		_burn_tick = 0.25
		take_damage(_burn_dps * 0.25, &"torso", &"fire", _burn_by, &"fire")
		if ZombieGore.blood_allowed():
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
	# the caller's hitbox bone belongs to this hit only: consumed before any early return so it can never leak
	# into a later boneless hit (explosions, fire) as the wrong wound side
	var side: String = _hit_side(limb)
	last_hit_bone = ""
	if not is_active():
		return false
	if (limb == &"torso" or limb == &"arms") and kind == &"bullet" and not armor_piercing:
		amount *= armor_torso_mult
	amount *= vulnerability()
	if GameState.has_flag(&"deaths_door") and kind != &"world":
		amount = hp + 1.0
	hp -= amount
	GLBus.enemy_damaged.emit(enemy_id, limb, amount, by_player)
	if kind != &"fire" and kind != &"world":
		_wound(limb, side)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	if kind == &"melee" and _grab_t > 0.0:
		_grab_t = 0.0   # a knife to the grabbing zombie breaks the grab
	if hp <= 0.0:
		_die(limb, weapon_id, by_player, kind)
		return true
	if by_player > 0 and kind != &"fire":
		Economy.award(by_player, int(GLData.table("economy")["hit_nonlethal"]))
	if kind != &"fire":
		_play_flinch(limb, side)
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
	# Arms: a damage pool per side; an emptied pool can take the forearm or the whole arm (anim.json gore).
	if limb == &"arms" and bool(_cfg.get("can_crawl", true)):
		_arm_hit(amount, side)
	elif limb == &"head" and kind == &"bullet" and randf() < float(_anim["gore"].get("jaw_chance_on_head_hit", 0.12)):
		ZombieGore.sever(self, "Jaw", _away_from_target() * 2.0 + Vector3.UP * 2.0)
	var kd: Dictionary = _anim["knockdown"]
	var knock: bool = (kd["kinds"] as Array).has(String(kind)) or (kd["weapons"] as Array).has(String(weapon_id))
	if knock and amount >= max_hp * float(kd.get("min_fraction", 0.08)) and state in [State.CHASE, State.ATTACK, State.STAGGER] and not is_crawler and bool(_cfg.get("can_crawl", true)):
		_knockdown()
		return false
	if state == State.GETUP:
		# A real hit knocks it back down once per knockdown; fire / trap ticks (every 0.25 s) and the rest of an
		# automatic burst don't, so continuous damage can never pin a zombie on the floor.
		if kind != &"fire" and kind != &"world" and not _getup_restarted:
			_getup_restarted = true
			_enter(State.GETUP)
		return false
	var stagger_ok: bool = kind != &"bullet" or bool(_cfg.get("bullet_stagger", true))
	if stagger_ok and (kind == &"melee" or kind == &"explosive" or amount >= max_hp * float(_anim["stagger"].get("damage_fraction", 0.4))) and state == State.CHASE:
		_react_clip = ""
		_enter(State.STAGGER)
	return false


## Which side an arm / leg hit landed on, from the hitbox bone the weapon reported (or a coin toss).
func _hit_side(limb: StringName) -> String:
	if limb != &"arms" and limb != &"legs":
		return ""
	var b: String = ZombieRig.legacy_name(last_hit_bone)
	if b.begins_with("Left"):
		return "l"
	if b.begins_with("Right"):
		return "r"
	return "l" if randf() < 0.5 else "r"


func _arm_hit(amount: float, side: String) -> void:
	var g: Dictionary = _anim["gore"]
	_arm_damage[side] = float(_arm_damage.get(side, 0.0)) + amount
	if _arm_damage[side] >= max_hp * float(g.get("arm_pool_fraction", 0.28)):
		_arm_damage[side] = -INF
		if randf() < float(g.get("arm_sever_chance", 0.55)):
			var upper: String = "LeftUpperArm" if side == "l" else "RightUpperArm"
			var fore: String = "LeftLowerArm" if side == "l" else "RightLowerArm"
			var bone: String = fore if randf() < float(g.get("forearm_vs_upper", 0.65)) else upper
			sever_limb(bone)


## Severs a chain (gameplay + presentation): arm pieces change the attack set, legs at the hip make a crawler.
func sever_limb(bone: String) -> void:
	if puppet and not Net.applying:
		return
	var imp: Vector3 = _away_from_target() * randf_range(1.5, 3.0) + Vector3.UP * randf_range(2.0, 3.5)
	if ZombieGore.severs_allowed() and not is_severed(bone):
		AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 1.2, -3.0)
	ZombieGore.sever(self, bone, imp)
	_severed_logic[bone] = true
	if Net.replicating():
		Net.session.zombie_event(self, &"fx", [&"sever", bone, imp])


func arms_lost() -> int:
	var n: int = 0
	for side: String in ["Left", "Right"]:
		if _severed_logic.has(side + "UpperArm") or _severed_logic.has(side + "LowerArm"):
			n += 1
	return n


func _away_from_target() -> Vector3:
	var away: Vector3 = global_position - (target.global_position if target != null else global_position + global_basis.z)
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.001 else -global_basis.z


func _knockdown() -> void:
	# a blast from the front throws the zombie onto its back
	var from_front: bool = true
	if target != null:
		var to_t: Vector3 = target.global_position - global_position
		from_front = (-global_basis.z).dot(to_t) > 0.0
	_down_front = not from_front
	if Net.replicating():
		Net.session.zombie_event(self, &"fx", [&"knockdown", _down_front])
	_enter(State.KNOCKDOWN)


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
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 1.5
	for leg: String in ["LeftUpperLeg", "RightUpperLeg"]:
		ZombieGore.sever(self, leg, Vector3(randf_range(-1.5, 1.5), 2.0, randf_range(-1.5, 1.5)))
	if ZombieGore.blood_allowed():
		Effects.blood(global_position + Vector3.UP * 0.9, Vector3.UP)
	_set_crawl_pose(true)
	# the fall-into-crawler transition: a stumble that ends in the crawl pose, then the crawl locomotion
	if not puppet and state in [State.CHASE, State.ATTACK, State.STAGGER, State.TO_WINDOW, State.WAIT_WINDOW] and moving:
		_react_clip = str(_anim["clips"]["react"]["fall_crawl"])
		_react_len = ZombieClips.length_of(_react_clip)
		_enter(State.STAGGER)
	elif state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW]:
		_tree_locomotion(true)


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
	_grab_t = 0.0
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
	GLBus.enemy_killed.emit(enemy_id, limb, weapon_id, by_player)
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	RoundManager.on_zombie_died()
	_death_kind = _pick_death(limb, kind)
	_death_side = -1.0 if randf() < 0.5 else 1.0
	_death_explosive = kind == &"explosive"
	var pop: bool = false
	if limb == &"head" and kind != &"world" and _death_clip != "death_head_snap":
		pop = true
	elif kind == &"explosive" and randf() < float(_anim["gore"].get("head_pop_explosive_chance", 0.35)):
		pop = true
	_start_death()
	if pop:
		_pop_head()
	if kind == &"explosive" and ZombieGore.severs_allowed() and randf() < 0.5:
		var loose: String = _pick(["LeftLowerLeg", "RightLowerLeg", "LeftLowerArm", "RightLowerArm"])
		ZombieGore.sever(self, loose, _away_from_target() * 4.0 + Vector3.UP * 4.0)
	if Net.replicating():
		Net.session.zombie_died(self, limb, kind, _death_kind, _death_side, _head_popped)


## The death clip for the cause: head kills snap or walk headless, sprinters tumble, blasts throw (anim.json).
func _pick_death(limb: StringName, kind: StringName) -> int:
	var deaths: Array = _anim["clips"]["death"]
	var by: Dictionary = _anim["clips"].get("death_by_cause", {})
	var pool: Array = []
	if is_crawler:
		_death_clip = str(_anim["clips"]["death_crawler"])
		return deaths.size()
	if limb == &"head" and kind != &"world":
		pool = (by.get("head", []) as Array).duplicate()
		if randf() >= float(_anim["gore"].get("headless_stagger_chance", 0.5)):
			pool.erase("death_headless")
	elif kind == &"explosive":
		pool = (by.get("explosive", []) as Array).duplicate()
	elif tier == &"sprint":
		pool = (by.get("sprint", []) as Array).duplicate()
	if pool.is_empty():
		pool = deaths.duplicate()
		pool.erase("death_headless")
		pool.erase("death_head_snap")
	_death_clip = str(_pick(pool))
	return maxi(0, deaths.find(_death_clip))


func _start_death() -> void:
	state = State.DEAD
	_state_t = 0.0
	_ragdoll_started = false
	var rd: Array = _anim["ragdoll"].get("corpse_seconds", [8.0, 12.0])
	_corpse_seconds = randf_range(float(rd[0]), float(rd[1]))
	if has_rig():
		_look.active = false
		_modifier.ik_weight = 0.0
	_enter(State.DEAD)


func _begin_ragdoll() -> void:
	var launch: Vector3 = Vector3.ZERO
	if _death_explosive:
		launch = _away_from_target() * float(_anim["ragdoll"].get("explosive_launch", 5.0)) + Vector3.UP * 3.0
	_ragdoll = ZombieRagdoll.start(_skel, launch)
	# the tree stays active (deactivating an AnimationTree resets the rendered skin to rest); it simply is not
	# advanced any more while the ragdoll writes the bones (_animate)


func _end_ragdoll() -> void:
	if _ragdoll != null:
		ZombieRagdoll.stop(_ragdoll)
		_ragdoll = null


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


# ---------------------------------------------------------------- body (skinned procedural body on the shared rig)

var _skel: Skeleton3D
var _body: MeshInstance3D
var _ap: AnimationPlayer
var _tree: AnimationTree
var _sm: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _anim_nodes: Dictionary = {}     # state -> AnimationNodeAnimation (one-shot states)
var _loco_bs: AnimationNodeBlendSpace2D
var _crawl_bs: AnimationNodeBlendSpace1D
var _posture_node: AnimationNodeAnimation
var _flinch_node: AnimationNodeAnimation
var _modifier: ZombieBodyModifier
var _look: LookAtModifier3D
var _look_target: Node3D
var _bones: Dictionary = {}          # profile bone name -> BoneAttachment3D (lazy)
var _gear: Array[MeshInstance3D] = []
var _caps: Dictionary = {}           # bone -> stump cap MeshInstance3D
var _severed: Dictionary = {}        # visual
var _severed_logic: Dictionary = {}  # gameplay (also set on puppets from the host's event)
var _arm_damage: Dictionary = {}
var _variant: String = "soldier"
var _build: String = "medium"
var _female: bool = false
var _height: float = 1.0
var _death_kind: int = 0
var _death_side: float = 1.0
var _death_clip: String = "death_back"
var _death_explosive: bool = false
var _corpse_seconds: float = 10.0
var _ragdoll: PhysicalBoneSimulator3D = null
var _ragdoll_started: bool = false
var _decals: Array[MeshInstance3D] = []
var _decal_i: int = 0
var _head_popped: bool = false
var _tree_state: String = ""
var _loco_clip: String = "walk_a"
var _loco_speed: float = 2.0
var _loco_x: float = 0.0
var _loco_turn: float = 0.0
var _turn_rate: float = 0.0
var _cycle: float = 0.0
var _cycle_len: float = 1.0
var _attack_clip: String = "swipe_l"
var _tear_clip: String = "tear_rip"
var _climb_clip: String = "vault_a"
var _react_clip: String = ""
var _react_len: float = 0.35
var _emerge_kind: String = "ground"
var _emerge_clip: String = "emerge_dig"
var _down_front: bool = false
var _getup_restarted: bool = false   # this knockdown's get-up was already restarted by a hit (one restart max)
var _climb_dist: float = 1.0
var _mantling: bool = false
var _swipe_t: float = 0.0
var _grab_t: float = 0.0
var _grab_target: Player = null
var _char: float = 0.0
var _frost_base: float = 0.0
var _inst: Dictionary = {}
var _rm_dist: float = 0.0
var _rm_time: float = 0.0
var _rm_speed: float = 0.0
var _body_dist: float = 0.0
var _body_speed: float = 0.0
var _rm_pos_last: Vector3 = Vector3.ZERO
var _foot_idx: PackedInt32Array = [-1, -1]


func _build_body() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_skel = ZombieRig.build_skeleton()
	_pivot.add_child(_skel)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = ZombieBody.build_skinned("soldier", "medium", false)
	_skel.add_child(_body)
	_body.skeleton = NodePath("..")   # explicit: the default path does not survive the skin being set first
	_body.skin = _skel.create_skin_from_rest_transforms()
	_foot_idx = [_skel.find_bone("LeftFoot"), _skel.find_bone("RightFoot")]
	for h: Array in ZombieBody.HITBOXES:
		var hb: Hitbox = Hitbox.new()
		var bone: String = ZombieRig.legacy_name(str(h[0]))
		hb.setup(self, h[1], h[2])
		hb.bone = bone
		hb.position = h[3]
		bone_attachment(bone).add_child(hb)
		_hitboxes.append(hb)
	# the animation tree
	_ap = AnimationPlayer.new()
	_ap.name = "AP"
	_ap.root_node = NodePath("..")
	_ap.add_animation_library(&"", ZombieClips.library())
	_pivot.add_child(_ap)
	_tree = AnimationTree.new()
	_tree.name = "AT"
	_pivot.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_ap)
	var root: AnimationNodeBlendTree = ZombieClips.build_tree_root()
	_tree.tree_root = root
	_tree.root_motion_track = NodePath("Skel:Root")
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_sm = root.get_node("SM") as AnimationNodeStateMachine
	_posture_node = root.get_node("PostureAnim") as AnimationNodeAnimation
	_flinch_node = root.get_node("FlinchAnim") as AnimationNodeAnimation
	for s: String in ZombieClips.STATES:
		var st: AnimationNodeBlendTree = _sm.get_node(s) as AnimationNodeBlendTree
		var an: AnimationNode = st.get_node("Anim")
		if an is AnimationNodeAnimation:
			_anim_nodes[s] = an
		elif s == "Locomotion":
			_loco_bs = an as AnimationNodeBlendSpace2D
		elif s == "Crawl":
			_crawl_bs = an as AnimationNodeBlendSpace1D
	_playback = _tree.get("parameters/SM/playback") as AnimationNodeStateMachinePlayback
	# modifiers: head look-at, then foot IK + hit springs
	_look_target = Node3D.new()
	_look_target.name = "LookTarget"
	add_child(_look_target)
	_look = LookAtModifier3D.new()
	_look.name = "LookAt"
	_look.bone_name = "Head"
	_look.forward_axis = SkeletonModifier3D.BONE_AXIS_MINUS_Z
	_look.primary_rotation_axis = Vector3.AXIS_Y
	_look.use_secondary_rotation = true
	_look.use_angle_limitation = true
	_look.symmetry_limitation = true
	_look.primary_limit_angle = deg_to_rad(float(_anim["look_at"].get("cone_deg", 60.0)))
	_look.secondary_limit_angle = deg_to_rad(40.0)
	_look.duration = float(_anim["look_at"].get("smooth_s", 0.2))
	_look.active = false
	_skel.add_child(_look)
	_look.target_node = _look.get_path_to(_look_target)
	_modifier = ZombieBodyModifier.new()
	_modifier.name = "BodyMod"
	_modifier.setup(_anim["foot_ik"], _anim["flinch"]["spring"])
	_skel.add_child(_modifier)
	_build_kind_parts()
	_apply_variant("soldier")


# ---- the public body API ZombieGore / tools use

## True when this body runs on the shared MZ rig (skeleton, AnimationTree, modifiers). The Foreman builds his
## own body in an overriding _ready() and has none of it, so every shared path that drives the rig (senses,
## flinches, tree states, death setup) checks this first; on a co-op client his puppet goes through them.
func has_rig() -> bool:
	return _tree != null and _modifier != null and _look != null and _flinch_node != null


func skeleton() -> Skeleton3D:
	return _skel


func body_mesh() -> MeshInstance3D:
	return _body


func kit_name() -> String:
	return _variant


func build_name() -> String:
	return _build


func is_female() -> bool:
	return _female


func pivot_scale() -> Vector3:
	return _pivot.scale


func is_severed(bone: String) -> bool:
	return _severed.has(bone)


func mark_severed(bone: String) -> void:
	_severed[bone] = true


func clear_severed() -> void:
	_severed.clear()
	for c: MeshInstance3D in _caps.values():
		c.hide()


func stump_cap(bone: String) -> MeshInstance3D:
	if _caps.has(bone):
		return _caps[bone]
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ZombieBody.stump_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caps[bone] = mi
	return mi


## A BoneAttachment3D for a profile (or legacy) bone name, created on first use.
func bone_attachment(name: String) -> BoneAttachment3D:
	var bone: String = ZombieRig.legacy_name(name)
	if _bones.has(bone):
		return _bones[bone]
	if _skel == null or _skel.find_bone(bone) < 0:
		return null
	var at: BoneAttachment3D = BoneAttachment3D.new()
	at.name = "At_" + bone
	at.bone_name = bone
	_skel.add_child(at)
	_bones[bone] = at
	return at


## Legacy accessor (Screamer's throat): bone name -> the attachment node.
func _bone(n: String) -> Node3D:
	return bone_attachment(n)


## Root-motion speed of the current animation (m/s, averaged over the last half second of full-gait locomotion):
## the foot-slide check compares it to body_speed() over the same window.
func anim_speed() -> float:
	return _rm_speed


## Horizontal body speed over the same window as anim_speed().
func body_speed() -> float:
	return _body_speed


func current_clip_state() -> String:
	return _tree_state


func _set_inst(key: String, v: Variant) -> void:
	if _inst.get(key, null) == v:
		return
	_inst[key] = v
	_body.set_instance_shader_parameter(key, v)
	for g: MeshInstance3D in _gear:
		g.set_instance_shader_parameter(key, v)


func _reset_presentation() -> void:
	_end_ragdoll()
	ZombieGore.restore(self)
	_severed_logic.clear()
	_arm_damage = {"l": 0.0, "r": 0.0}
	_char = 0.0
	_grab_t = 0.0
	_swipe_t = 0.0
	_mantling = false
	_react_clip = ""
	_head_popped = false
	_set_inst("inst_dissolve", 0.0)
	_set_inst("inst_char", 0.0)
	_tree_state = ""
	_skel.reset_bone_poses()
	for g: MeshInstance3D in _gear:
		g.hide()


func _apply_variant(variant: String) -> void:
	var kits: Dictionary = _anim["kits"]
	if not kits.has(variant):
		variant = "soldier"
	var kit: Dictionary = kits[variant]
	_variant = variant
	var builds: Array = kit.get("builds", ["medium"])
	_build = str(_pick(builds))
	_female = randf() < float(kit.get("female", 0.0))
	var heights: Array = _anim["builds"].get("heights", [0.95, 1.04])
	_height = randf_range(float(heights[0]), float(heights[1]))
	_body.mesh = ZombieBody.build_skinned(_variant, _build, _female)
	_body.set_surface_override_material(0, null)
	_pivot.scale = Vector3.ONE * _height
	for d: MeshInstance3D in _decals:
		d.hide()
	# gear pieces
	for g: MeshInstance3D in _gear:
		g.hide()
	var gi: int = 0
	var gear: Dictionary = kit.get("gear", {})
	for piece: String in gear.keys():
		if randf() >= float(gear[piece]):
			continue
		var spec: Array = ZombieBody.gear_mesh(piece, _female)
		var at: BoneAttachment3D = bone_attachment(str(spec[0]))
		if at == null:
			continue
		var mi: MeshInstance3D
		if gi < _gear.size():
			mi = _gear[gi]
		else:
			mi = MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_gear.append(mi)
		gi += 1
		if mi.get_parent() != at:
			if mi.get_parent() != null:
				mi.get_parent().remove_child(mi)
			at.add_child(mi)
		mi.mesh = spec[1]
		mi.show()
	# per-instance look: tint, dirt, frost (anim.json variation)
	var va: Dictionary = _anim["variation"]
	var t: float = float(va.get("tint", 0.08))
	_set_inst("inst_tint", Color(1.0 + randf_range(-t, t), 1.0 + randf_range(-t, t), 1.0 + randf_range(-t, t), 1.0))
	var dirt: Array = va.get("dirt", [0.1, 0.8])
	_set_inst("inst_dirt", randf_range(float(dirt[0]), float(dirt[1])))
	var fbm: Dictionary = va.get("frost_by_map", {})
	var fr: Array = fbm.get(String(GameState.map_id), fbm.get("default", [0.0, 0.2]))
	_frost_base = randf_range(float(fr[0]), float(fr[1]))
	_set_inst("inst_frost", _frost_base)
	_set_inst("inst_fuel", 0.0)
	# posture trait, locomotion clip and the cadence
	_roll_posture()
	_pick_locomotion()


func _roll_posture() -> void:
	var w: Dictionary = _anim["postures"]["weights"]
	var total: float = 0.0
	for k: String in w.keys():
		total += float(w[k])
	var roll: float = randf() * total
	var posture: String = "none"
	for k: String in w.keys():
		roll -= float(w[k])
		if roll <= 0.0:
			posture = k
			break
	var amt: Array = _anim["postures"].get("amount", [0.6, 1.0])
	set_posture(posture, randf_range(float(amt[0]), float(amt[1])))


## Fixes the posture trait (a postures clip name, or "none") at `amount` of the additive layer: the authored
## characters (Bellringer, the Screamer) keep theirs instead of the random roll.
func set_posture(posture: String, amount: float) -> void:
	if _posture_node == null:
		return
	_posture_node.animation = StringName("posture_none" if posture == "none" else posture)
	_tree.set("parameters/Posture/add_amount", 0.0 if posture == "none" else amount)


func _pick_locomotion() -> void:
	var loco: Dictionary = _anim["clips"]["locomotion"]
	var key: String = String(tier) if loco.has(String(tier)) else "walk"
	_loco_clip = str(_pick(loco[key]))
	_loco_speed = float(_anim["gait"][key]["speed"])
	_cycle_len = ZombieClips.length_of(_loco_clip)
	for i: int in 3:
		(_loco_bs.get_blend_point_node(1 + i) as AnimationNodeAnimation).animation = StringName(_loco_clip if i == 0 else _loco_clip + ("_lean_l" if i == 1 else "_lean_r"))
	var crawl: String = str(_pick(loco["crawl"]))
	(_crawl_bs.get_blend_point_node(1) as AnimationNodeAnimation).animation = StringName(crawl)


func _pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]


## Shows the variant's extra pieces (crystal plates, lantern) and adjusts the body.
func _apply_kind() -> void:
	(_kind_nodes["glass"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["glass_arm"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["lantern"] as Node3D).visible = enemy_id == &"bellringer"
	_lantern_light.light_energy = 1.6 if enemy_id == &"bellringer" else 0.0
	match enemy_id:
		&"bellringer":
			_body.mesh = ZombieBody.build_skinned("bellringer", "thin", false)
			_variant = "bellringer"
			_build = "thin"
			_female = false
			_pivot.scale = Vector3.ONE * 1.04
			set_posture("hunch", 0.9)
		&"glasshide":
			_body.set_surface_override_material(0, ZombieBody.skin_material("glass"))
			_pivot.scale = Vector3.ONE * 1.1
	_mats["skin"] = ZombieBody.material(_variant, "skin")
	_mats["coat"] = ZombieBody.material(_variant, "cloth")


func _build_kind_parts() -> void:
	var glass: Node3D = Node3D.new()
	glass.name = "GlassPlates"
	bone_attachment("Chest").add_child(glass)
	var crystal: Array = []
	# chest plates and a jagged cluster growing out of one shoulder (reads at 30 m)
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
	bone_attachment("RightLowerArm").add_child(glass_arm)
	var gm2: MeshInstance3D = MeshInstance3D.new()
	gm2.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._cyl(0.0, 0.035, 0.22, Vector3(0.04, -0.12, 0), "crystal", Vector3(0, 0, -1.1), Vector3.ONE, 4),
		ZombieBody._cyl(0.0, 0.03, 0.18, Vector3(-0.03, -0.18, -0.03), "crystal", Vector3(0.8, 0, 0.9), Vector3.ONE, 4)])
	glass_arm.add_child(gm2)
	_kind_nodes["glass_arm"] = glass_arm
	var lantern: Node3D = Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0, -0.06, -0.02)
	bone_attachment("RightHand").add_child(lantern)
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
		for hb: Hitbox in _hitboxes:
			if hb.limb == &"legs":
				hb.collision_layer = 0
		cap.height = 0.7
		cap.radius = 0.3
		_collision.position = Vector3(0, 0.35, 0)
	else:
		cap.height = 1.75
		_collision.position = Vector3(0, 0.875, 0)


# ---------------------------------------------------------------- gore (presentation only)

func _pop_head() -> void:
	if _head_popped:
		return
	_head_popped = true
	AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 1.7)
	var away: Vector3 = _away_from_target()
	ZombieGore.sever(self, "Head", Vector3(away.x * 3.0, 4.5, away.z * 3.0))
	if ZombieGore.blood_allowed():
		var at: Node3D = bone_attachment("Neck")
		var p: Vector3 = at.global_position if at != null else global_position + Vector3.UP * 1.6
		for i: int in 3:
			Effects.blood(p, Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)))


## A wound decal on the struck limb (cheap quads, recycled per zombie).
func _wound(limb: StringName, side: String = "") -> void:
	if ZombieGore.level() == "off":
		return
	var choices: Array = []
	match limb:
		&"head":
			choices = ["Head"]
		&"neck":
			choices = ["Neck"]
		&"torso":
			choices = ["Chest", "Spine"]
		&"arms":
			choices = ["LeftUpperArm", "LeftLowerArm"] if side == "l" else ["RightUpperArm", "RightLowerArm"]
		&"legs":
			choices = ["LeftUpperLeg", "LeftLowerLeg"] if side == "l" else ["RightUpperLeg", "RightLowerLeg"]
		_:
			choices = ["Chest"]
	var bone_name: String = str(choices[randi() % choices.size()])
	var bone: Node3D = bone_attachment(bone_name)
	if bone == null:
		return
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
	var up: bool = bone_name in ["Chest", "Spine", "Head", "Neck"]
	var r: float = 0.14 if bone_name == "Chest" else (0.12 if bone_name == "Head" else 0.07)
	var y: float = randf_range(0.05, 0.25) if up else -randf_range(0.05, 0.35)
	var out: Vector3 = Vector3(cos(a), 0, sin(a))
	d.position = out * r + Vector3(0, y, 0)
	d.basis = Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * randf_range(0.07, 0.15))
	d.show()


# ---------------------------------------------------------------- animation (AnimationTree parameters)

func _tree_play(st: String, clip: String, time_scale: float) -> void:
	if _tree == null or _playback == null:
		return
	if _anim_nodes.has(st):
		(_anim_nodes[st] as AnimationNodeAnimation).animation = StringName(clip)
	_tree.set("parameters/SM/%s/TimeScale/scale" % st, maxf(0.01, time_scale))
	# One-shot states share one AnimationNodeAnimation per state; travel() to the state already playing restarts
	# it from 0 in Godot 4.7 (reset_on_teleport), so a swapped clip (knockdown -> get-up, climb loop -> mantle)
	# starts at its first frame. test_zombie_mz_fixes guards that engine behaviour.
	_playback.travel(st)
	_tree_state = st
	_cycle = 0.0


func _tree_attack(clip: String) -> void:
	_tree.set("parameters/SM/Attack/Anim/blend_position", ZombieClips.attack_index(clip))
	_tree_play("Attack", clip, ZombieClips.ATTACK_WINDUP / maxf(0.05, float(_cfg["attack_windup"])))


func _tree_emerge() -> void:
	var em: Dictionary = _anim["clips"]["emerge"]
	match _emerge_kind:
		"portal":
			_emerge_clip = str(em["portal"])
		"ceiling":
			_emerge_clip = str(em["ceiling"])
		"water":
			_emerge_clip = str(em["water"])
		_:
			_emerge_clip = str(_pick(em["ground"]))
	_tree_play("Emerge", _emerge_clip, ZombieClips.length_of(_emerge_clip) / maxf(0.05, _emerge_seconds()))


func _emerge_seconds() -> float:
	var e: Dictionary = _anim["emerge"]
	match _emerge_kind:
		"portal":
			return float(e["portal_seconds"])
		"ceiling":
			return float(e["ceiling_seconds"])
		"water":
			return float(e["water_seconds"])
	return float(e["ground_seconds"])


## Spawn kind -> emerge clip family: Bellringers step out of portals; a spawn's name prefix can pick the chute
## drop or the wade-up (anim.json emerge_by_spawn_prefix per map).
func _emerge_kind_for(spawn: ZombieSpawn) -> String:
	if enemy_id == &"bellringer":
		return "portal"
	var by: Dictionary = (_anim.get("emerge_by_spawn_prefix", {}) as Dictionary).get(String(GameState.map_id), {})
	for prefix: String in by.keys():
		if spawn.name.begins_with(prefix):
			return str(by[prefix])
	return "ground"


func _tree_locomotion(force: bool = false) -> void:
	var st: String = "Crawl" if is_crawler else "Locomotion"
	if _playback == null:
		return
	if _tree_state != st or force:
		_playback.travel(st)
		_tree_state = st


func _random_phase() -> void:
	if _tree_state == "Locomotion" or _tree_state == "Crawl":
		_tree.advance(randf() * _cycle_len)


func _pick_attack() -> String:
	var at: Dictionary = _anim["clips"]["attack"]
	if is_crawler:
		return str(at["bite"])
	var lost: int = arms_lost()
	if lost >= 2:
		return str(at["headbutt"])
	if (_anim["attack"]["grab_tiers"] as Array).has(String(tier)) and randf() < 0.5 and lost == 0:
		return str(at["grab"])
	if (_anim["attack"]["lunge_tiers"] as Array).has(String(tier)) and randf() < 0.3 and enemy_id == &"ganger":
		return str(at["lunge"])
	var swipes: Array = (at["swipe"] as Array).duplicate()
	if _severed_logic.has("LeftUpperArm") or _severed_logic.has("LeftLowerArm"):
		swipes = swipes.filter(func(s: String) -> bool: return s == "swipe_r")
	elif _severed_logic.has("RightUpperArm") or _severed_logic.has("RightLowerArm"):
		swipes = swipes.filter(func(s: String) -> bool: return s == "swipe_l")
	return str(_pick(swipes))


func _play_flinch(limb: StringName, side: String) -> void:
	if not has_rig():
		return
	var zone: String = "torso"
	var chain: int = -1
	var kick: Vector3 = Vector3.ZERO
	var imp: float = float(_anim["flinch"]["spring"].get("impulse", 0.9))
	match limb:
		&"head", &"neck":
			zone = "head"
			chain = 2
			kick = Vector3(-imp * 4.0, randf_range(-imp, imp) * 2.0, randf_range(-imp, imp) * 2.0)
		&"arms":
			zone = "arm_" + side
			chain = 0 if side == "l" else 1
			kick = Vector3(imp * 3.0, 0, (-imp if side == "l" else imp) * 4.0)
		&"legs":
			zone = "leg_" + side
		_:
			zone = "torso"
			chain = 0 if randf() < 0.5 else 1
			kick = Vector3(imp * 2.0, 0, (-imp if chain == 0 else imp) * 2.0)
	_flinch_node.animation = StringName(str(_anim["clips"]["flinch"].get(zone, "flinch_torso")))
	_tree.set("parameters/Flinch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if chain >= 0:
		_modifier.kick(chain, kick)
	_flinch = float(_anim["flinch"].get("seconds", 0.25))
	_flinch_dir = -1.0 if side == "l" else 1.0


## Per visual tick: tree parameters from the state and velocity, LOD-rated advance, animation events.
func _animate(dt: float) -> void:
	if state == State.INACTIVE or _tree == null or _ragdoll != null:
		return   # a ragdolling corpse: the physics bodies drive the bones (ZombieRagdoll.sync)
	ZombieBody.update_cracks(RoundManager.current_round, float(GLData.table("enemies").get("visual", {}).get("crack_energy", 2.6)))
	var spd: float = Vector2(velocity.x, velocity.z).length()
	var moving_state: bool = state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW]
	if moving_state:
		if state == State.WAIT_WINDOW and spd < 0.2:
			if _tree_state != "Barricade":
				_tree_play("Barricade", str(_anim["clips"]["wait"]), 1.0)
		else:
			_tree_locomotion()
	if _tree_state == "Locomotion":
		var below: float = float(_anim["turn"].get("in_place_below_mps", 0.5))
		var target_x: float = 1.0 if spd > below else 0.0
		_loco_x = move_toward(_loco_x, target_x, dt * 6.0)
		var lean_t: Dictionary = _anim["turn"]["lean_tiers"]
		var lean: float = float(lean_t.get(String(tier), 0.0))
		var turn_norm: float = clampf(_turn_rate / float(_anim["turn"].get("full_turn_rate", 2.5)), -1.0, 1.0)
		var want_turn: float = turn_norm * (lean / 0.18 if spd > below else 1.0)
		_loco_turn = move_toward(_loco_turn, want_turn if absf(turn_norm) > 0.15 else 0.0, dt * 5.0)
		_tree.set("parameters/SM/Locomotion/Anim/blend_position", Vector2(_loco_x, _loco_turn))
		# the clip's root motion is in rig space: the height scale on the pivot stretches every stride by that much
		var scale: float = maxf(spd, 0.15) / maxf(0.1, _loco_speed * _pivot.scale.y) if _loco_x > 0.01 else 1.0
		_tree.set("parameters/SM/Locomotion/TimeScale/scale", scale)
		if _loco_x > 0.5:
			var before: float = _cycle
			_cycle = fmod(_cycle + dt * scale / _cycle_len, 1.0)
			if (before < 0.5 and _cycle >= 0.5) or _cycle < before:
				_footstep(_cycle < before)
	elif _tree_state == "Crawl":
		var cx: float = clampf(spd / float(_cfg["crawler_speed"]), 0.0, 1.0)
		_tree.set("parameters/SM/Crawl/Anim/blend_position", cx)
		var cs: float = maxf(spd, 0.1) / (float(_anim["gait"]["crawl"]["speed"]) * _pivot.scale.y) if cx > 0.05 else 1.0
		_tree.set("parameters/SM/Crawl/TimeScale/scale", cs)
	_turn_rate = move_toward(_turn_rate, 0.0, dt * 8.0)
	if _flinch > 0.0:
		_flinch = maxf(0.0, _flinch - dt)
	_tree.advance(dt)
	# root motion bookkeeping for the foot-slide check: the clip's stride distance against the body's travel
	# over the same window, only while fully in the gait (the idle blend scales the root motion down)
	var rm: Vector3 = _tree.get_root_motion_position()
	var here: Vector3 = Vector3(global_position.x, 0, global_position.z)
	if _tree_state == "Locomotion" and _loco_x >= 0.95 and _rm_time > 0.0:
		_rm_dist += rm.length() * _pivot.scale.y
		_body_dist += (here - _rm_pos_last).length()
	elif _tree_state != "Locomotion" or _loco_x < 0.95:
		_rm_dist = 0.0
		_body_dist = 0.0
		_rm_time = 0.0
	_rm_pos_last = here
	_rm_time += dt
	if _rm_time >= 0.5:
		_rm_speed = _rm_dist / _rm_time
		_body_speed = _body_dist / _rm_time
		_rm_dist = 0.0
		_body_dist = 0.0
		_rm_time = 0.0


## Foot IK rays, look-at target and the per-distance modifier gates (physics step).
func _update_senses(delta: float) -> void:
	if state == State.INACTIVE or state == State.DEAD or not has_rig():
		return
	var d: float = global_position.distance_to(target.global_position) if target != null else 999.0
	var fi: Dictionary = _anim["foot_ik"]
	var la: Dictionary = _anim["look_at"]
	var ik_on: bool = d <= float(fi["range_m"]) and is_on_floor() and state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW, State.TEAR, State.ATTACK, State.STAGGER] and not is_crawler
	_modifier.active = d <= float(fi["off_m"]) or _modifier.springs_active()
	if ik_on:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		for i: int in 2:
			var fidx: int = _foot_idx[i]
			if fidx < 0:
				_modifier.foot_ground_y[i] = NAN
				continue
			var foot_g: Vector3 = _skel.to_global(_skel.get_bone_global_pose(fidx).origin)
			var from: Vector3 = Vector3(foot_g.x, global_position.y + float(fi["ray_up"]), foot_g.z)
			var to: Vector3 = Vector3(foot_g.x, global_position.y - float(fi["ray_down"]), foot_g.z)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD, [get_rid()])
			var hit: Dictionary = space.intersect_ray(q)
			_modifier.foot_ground_y[i] = (_skel.to_local(hit["position"] as Vector3).y) if not hit.is_empty() else NAN
		_modifier.ik_weight = move_toward(_modifier.ik_weight, 1.0, delta * 4.0)
	else:
		_modifier.ik_weight = move_toward(_modifier.ik_weight, 0.0, delta * 4.0)
	var look_on: bool = target != null and d <= float(la["range_m"]) and state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW, State.TEAR, State.ATTACK] and not is_severed("Head")
	if look_on:
		_look_target.global_position = target.global_position + Vector3.UP * 1.6
	_look.active = look_on
	# damage-state materials: burn char builds while burning, frost crust while frosted
	_set_inst("inst_char", snappedf(_char, 0.05))
	_set_inst("inst_frost", snappedf(_frost_base + (0.5 if _frost_t > 0.0 else 0.0), 0.05))


# ---------------------------------------------------------------- audio

func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_groan_t -= delta
	if _groan_t <= 0.0:
		var v: Dictionary = _anim["vocals"]
		var every: Array = v["sprint_every"] if tier == &"sprint" else v["breath_every"]
		_groan_t = randf_range(float(every[0]), float(every[1]))
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


## A footstep from the locomotion clip's events (phase 0 and 0.5), surface-aware: culled by distance to the
## target player and rate-capped across the horde (anim.json footsteps).
func _footstep(_left: bool) -> void:
	var fs: Dictionary = _anim["footsteps"]
	if (not puppet and not is_on_floor()) or target == null:
		return
	var r: float = float(fs.get("range_m", 18.0))
	if global_position.distance_squared_to(target.global_position) > r * r:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_step_msec < int(fs.get("gap_ms", 70)):
		return
	_last_step_msec = now
	var surface: String = _floor_surface()
	var key: String = "footstep_" + surface
	if surface == "water" or not AudioDirector.bank.has(key):
		key = "zombie_step"
	AudioDirector.play_3d(key, global_position, float(fs.get("volume_db", -3.0)), 0.08)


## What the zombie stands on, from the floor collider's "surface" metadata or name hints (anim.json footsteps).
func _floor_surface() -> String:
	var fs: Dictionary = _anim["footsteps"]
	var col: Object = get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null
	var n: Node = col as Node
	if n != null:
		for m: Node in [n, n.get_parent()]:
			if m != null and m.has_meta("surface"):
				return str(m.get_meta("surface"))
		var lname: String = n.name.to_lower()
		for s: String in (fs["surfaces"] as Dictionary).keys():
			for hint: String in fs["surfaces"][s]:
				if lname.contains(hint):
					return s
	var defaults: Dictionary = fs["default_by_map"]
	return str(defaults.get(String(GameState.map_id), defaults.get("default", "stone")))


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
	_reset_presentation()
	_set_crawl_pose(false)
	_apply_variant(variant)
	_apply_kind()
	_puppet_show(pos, yaw)
	state = State.CHASE
	_emerge_kind = "portal" if enemy_id == &"bellringer" else "ground"
	_puppet_enter(st, sub)
	_random_phase()
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
	if s == State.CLIMB:
		_climb_clip = _pick(_anim["clips"]["vault"])
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
		var before: float = rotation.y
		rotation.y = interp.yaw
		_turn_rate = wrapf(rotation.y - before, -PI, PI) / maxf(delta, 0.0001)
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
	_update_senses(delta)


func _puppet_visual_tick(_delta: float) -> void:
	pass


func _puppet_dead(delta: float) -> void:
	_state_t += delta
	_update_dead(delta)


## A hit from this client's own weapon: wounds, flinch and the hit marker now (predicted); the host decides.
func _puppet_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName, armor_piercing: bool) -> bool:
	var side: String = _hit_side(limb)
	last_hit_bone = ""   # consumed by this hit even when it is not predicted here (see take_damage)
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
		_wound(limb, side)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	if kind != &"fire":
		_play_flinch(limb, side)
	return hp - _pred_dmg <= 0.0


## The host's death: the same fall, the same head pop, at the host's position.
func puppet_die(_limb: StringName, kind: StringName, death_kind: int, side: float, pop: bool, pos: Vector3) -> void:
	if state == State.DEAD or state == State.INACTIVE:
		return
	if pos.is_finite():
		global_position = pos
	_puppet_hide_hitboxes()
	AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.2, -1.0)
	_death_burst()
	var deaths: Array = _anim["clips"]["death"]
	_death_kind = death_kind
	_death_side = side
	_death_explosive = kind == &"explosive"
	_death_clip = str(_anim["clips"]["death_crawler"]) if (is_crawler or death_kind >= deaths.size()) else str(deaths[clampi(death_kind, 0, deaths.size() - 1)])
	_start_death()
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


## A one-off presentation event from the host (boss attacks; severs and knockdown sides for the shared body).
func puppet_fx(what: StringName, args: Array) -> void:
	match what:
		&"sever":
			if args.size() >= 2:
				Net.applying = true
				_severed_logic[str(args[0])] = true
				ZombieGore.sever(self, str(args[0]), args[1] as Vector3)
				Net.applying = false
		&"knockdown":
			if args.size() >= 1:
				_down_front = bool(args[0])
