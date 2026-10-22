class_name BotLocomotion
extends RefCounted
## The bots' locomotion layer (Update 03 section 3, T-056). The brain decides WHAT to do; this decides HOW to
## move there: navmesh paths with danger costs, a loose wedge round the leader, training loops, personal space
## round humans, doors and the lift rule, stuck recovery. It moves the body through the human Player's own
## movement code (Player.drive_bot with a MoveIntent): the same acceleration curves, stamina, sprint (forward-ish
## only), sprint-out, slide and mantle, and it turns the body at a player's rate. Tuning:
## data/gravelight/ai/locomotion.json; the turn rate is bots.json skills.<skill>.turn_rate.
##
## API (the brain codes against these; keep the names):
##   setup(player: Player, squad: BotSquad)            once
##   each physics frame: exactly one of
##     move_to(pos: Vector3, urgency := 0.5, stop_dist := 1.0)   urgency 0 walk .. >= 0.7 sprint (no look set) .. 1 flee
##     follow(leader: Player, slot_index: int)          loose wedge slots round the leader (BotLocomotion.wedge_offset)
##     hold(pos: Vector3, facing: Vector3)              stand there, face `facing` unless a look is set
##     train(route: TrainingRoute)                      run the loop ahead of the horde (null: a ring round the leader)
##     stop()
##   then tick(delta)                                   moves and turns the body
##   look_at_dir(dir: Vector3) / clear_look()           the aim layer's facing (3D, with pitch); obeyed while moving
##                                                      (strafing) and standing; turn-rate limited. Without one the
##                                                      body faces where it moves (no moonwalking).
##   queries: arrived() -> bool, is_stuck() -> bool, path_length_to(pos) -> float (cached, budgeted),
##            current_target() -> Vector3, debug_path() -> PackedVector3Array, train_face_dir() -> Vector3,
##            train_ok() -> bool, fire_ready() -> bool / sprint_out_left() -> float (the gun's sprint-out after a
##            sprint: don't fire before), avg_tick_us() -> float
##   pure (unit-tested): personal_space_push(me, human, human_vel) -> Vector3, wedge_offset(...), stuck_stage(...),
##            path_crosses_door(...), lift_ok(...), should_yield(...)
## Metrics: BotMetrics.note(pid, &"stuck_time" / &"stuck" / &"teleport") are called from here.
## Danger: squad.blackboard.danger_zones (duck-typed: Array of {pos, radius, cost, until} with `until` in
## squad.time() seconds) when the brain provides it; traps (danger_contains), Bell Domes (group bell_domes), the
## fire_hazards group, zombies and lift cages are read here.

enum Mode { STOP, MOVE, FOLLOW, HOLD, TRAIN }

const MASK_WORLD: int = 1 | (1 << 8)             # world | doors
const MASK_BLOCK: int = 1 | (1 << 2) | (1 << 8)  # + zombie bodies (the "cut off" ray)
const EYE_Y: float = 1.5

static var _cfg_cache: Dictionary = {}
static var force_mode: String = ""
static var _plans_frame: int = -1
static var _plans_used: int = 0
static var _z_frame: int = -1000
static var _z_cache: Array[Zombie] = []
static var _dome_frame: int = -1000
static var _dome_cache: Array[Node3D] = []
static var _fire_cache: Array[Node3D] = []
static var _trap_cache: Array[Node] = []

var player: Player
var squad: BotSquad
var mode: Mode = Mode.STOP
## Counters (soak / debug overlay).
var repaths: int = 0
var nudges: int = 0
var teleports: int = 0
var reversals: int = 0
var yields: int = 0
var slides_started: int = 0
var mantles_started: int = 0

var _c: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mi: MoveIntent = MoveIntent.new()
var _nav_ready: bool = false
# goal
var _goal: Vector3 = Vector3.INF
var _urgency: float = 0.5
var _stop_dist: float = 1.0
var _hold_facing: Vector3 = Vector3.ZERO
var _leader: Player = null
var _slot: int = 0
var _slot_t: float = 0.0
var _slot_pos: Vector3 = Vector3.INF
# path
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_t: float = 0.0
var _need_plan: bool = false
var _arrived: bool = true
# look
var _look: Vector3 = Vector3.ZERO
var _look_set: bool = false
# stuck ladder
var _best_rem: float = INF
var _no_prog_t: float = 0.0
var _stage_done: int = 0
var _nudge_t: float = 0.0
var _nudge_to: Vector3 = Vector3.INF
var _last_pos: Vector3 = Vector3.ZERO
var _block_t: float = 0.0
var _tp_try_t: float = 0.0
var _rebase: bool = false
var _win_t: float = 0.0
var _win_pos: Vector3 = Vector3.ZERO
var _stuck_at: Vector3 = Vector3.INF   # where this ladder's first nudge started (window progress must escape it)
# yielding to humans
var _aside_t: float = 0.0
var _aside_to: Vector3 = Vector3.INF
var _choke_t: float = 0.0
# sprint / slide
var _was_sprinting: bool = false
var _sprint_out: float = 0.0
var _slide_cd: float = 0.0
var _sprint_pressed_last: bool = false
var _crouch_pressed_last: bool = false
# training
var _route: TrainingRoute = null
var _fallback_route: TrainingRoute = null
var _fallback_center: Vector3 = Vector3.INF
var _t_param: float = 0.0
var _t_dir: int = 1
var _t_ok: bool = true
var _t_check_at: float = INF
var _t_rev_cd: float = 0.0
var _t_head: Zombie = null
var _t_think: float = 0.0
var _t_urg: float = 0.5
# path length cache
var _plen_cache: Dictionary = {}   # Vector3i key -> [time, length]
# budget
var _us_total: int = 0
var _us_body: int = 0   # of which the shared Player movement (move_and_slide), which the old brain paid too
var _ticks: int = 0
var _time: float = 0.0
var _turn_rate: float = -1.0
var _turn_skill: String = ""


# ================================================================== config

static func cfg() -> Dictionary:
	if _cfg_cache.is_empty():
		var path: String = "res://data/gravelight/ai/locomotion.json"
		_cfg_cache = GLData.load_json(path) if FileAccess.file_exists(path) else {}
	return _cfg_cache


## "v2" (default) when bots.json says so: the brain then moves through this layer. force_mode ("v1" / "v2",
## the soak's --loco=) overrides the table for A/B runs.
static func enabled(bots_cfg: Dictionary) -> bool:
	if force_mode != "":
		return force_mode == "v2"
	return str(bots_cfg.get("locomotion", "v2")) == "v2"


func _g(section: String, key: String, dflt: Variant) -> Variant:
	return (_c.get(section, {}) as Dictionary).get(key, dflt)


func setup(p: Player, s: BotSquad) -> void:
	player = p
	squad = s
	_c = cfg()
	_rng.randomize()
	_last_pos = p.global_position


# ================================================================== the brain's calls

func move_to(pos: Vector3, urgency: float = 0.5, stop_dist: float = 1.0) -> void:
	_set_mode(Mode.MOVE)
	_urgency = clampf(urgency, 0.0, 1.0)
	_stop_dist = maxf(0.2, stop_dist)
	_set_goal(pos)


func follow(leader: Player, slot_index: int) -> void:
	if mode != Mode.FOLLOW or leader != _leader or slot_index != _slot:
		_slot_t = 0.0
	_set_mode(Mode.FOLLOW)
	_leader = leader
	_slot = slot_index
	_stop_dist = float(_g("formation", "near_m", 1.2))


func hold(pos: Vector3, facing: Vector3) -> void:
	_set_mode(Mode.HOLD)
	_hold_facing = facing
	_urgency = 0.6
	_stop_dist = 0.6
	_set_goal(pos)


func stop() -> void:
	_set_mode(Mode.STOP)
	_goal = Vector3.INF
	_clear_path()


func train(route: TrainingRoute) -> void:
	var entering: bool = mode != Mode.TRAIN or route != _route
	_set_mode(Mode.TRAIN)
	_route = route
	if entering:
		_t_think = 0.0
		_t_ok = true
		_t_check_at = INF
		var r: TrainingRoute = _active_route()
		if r != null:
			_t_param = r.closest_param(player.global_position)
			_t_dir = _pick_train_dir(r)
	_stop_dist = 0.5


func look_at_dir(dir: Vector3) -> void:
	if dir.length_squared() < 0.000001:
		return
	_look = dir.normalized()
	_look_set = true


func clear_look() -> void:
	_look_set = false


# ================================================================== queries

func arrived() -> bool:
	return _arrived


func is_stuck() -> bool:
	return _no_prog_t >= float(_g("stuck", "repath_s", 2.0))


func current_target() -> Vector3:
	return _goal


func debug_path() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if player != null:
		out.append(player.global_position)
	for i: int in range(_path_i, _path.size()):
		out.append(_path[i])
	return out


func train_ok() -> bool:
	return _t_ok


## Where to turn to fire at the train's head (the nearest zombie following us), from the eye; ZERO without one.
func train_face_dir() -> Vector3:
	if _t_head == null or not is_instance_valid(_t_head) or not _t_head.is_active():
		return Vector3.ZERO
	var eye: Vector3 = player.global_position + Vector3.UP * EYE_Y
	return (_t_head.global_position + Vector3.UP * 1.1 - eye).normalized()


## The gun in hand may fire: the sprint-out after a sprint is over (movement.json sprint_out), and not sprinting.
func fire_ready() -> bool:
	return _sprint_out <= 0.0 and not player.sprinting and not player.mantling


func sprint_out_left() -> float:
	return maxf(0.0, _sprint_out)


## Navmesh path length from the bot to `pos` (door rule applied; INF when there is no way). Cached per ~1 m cell
## for 1.5 s and budgeted with the other path queries (a cached or straight-line estimate when over budget).
func path_length_to(pos: Vector3) -> float:
	var key: Vector3i = Vector3i(roundi(pos.x), roundi(pos.y), roundi(pos.z))
	var hit: Variant = _plen_cache.get(key)
	if hit != null and _time - float((hit as Array)[0]) < 1.5:
		return float((hit as Array)[1])
	if not _take_plan_budget():
		return _flat(pos, player.global_position) * 1.3 if hit == null else float((hit as Array)[1])
	var p: PackedVector3Array = _raw_path(player.global_position, pos)
	var l: float = INF if p.is_empty() or _flat(p[p.size() - 1], pos) > 1.5 else _poly_len(p)
	_plen_cache[key] = [_time, l]
	if _plen_cache.size() > 64:
		_plen_cache.clear()
	return l


## Average cost of tick() in microseconds (the layer's share of the 0.5 ms per bot budget), body movement included.
func avg_tick_us() -> float:
	return float(_us_total) / maxf(1.0, float(_ticks))


## Average cost of the body's movement inside tick() (Player.drive_bot: the shared movement code, move_and_slide).
func avg_body_us() -> float:
	return float(_us_body) / maxf(1.0, float(_ticks))


# ================================================================== tick

func tick(delta: float) -> void:
	if player == null or not player.is_inside_tree() or player.downed or player.spectating:
		return
	var t0: int = Time.get_ticks_usec()
	_time += delta
	if not _nav_ready:
		_nav_ready = NavigationServer3D.map_get_iteration_id(player.get_world_3d().navigation_map) > 0
		if not _nav_ready:
			return
	_repath_t -= delta
	_aside_t -= delta
	_slide_cd -= delta
	_t_rev_cd -= delta
	_tp_try_t -= delta
	_sprint_out -= delta
	var me: Vector3 = player.global_position
	# 1. where to: the mode's goal (follow / train recompute theirs)
	match mode:
		Mode.FOLLOW:
			_tick_follow_goal(delta)
		Mode.TRAIN:
			_tick_train(delta)
	# 2. yield to humans: a step aside overrides the goal for a moment
	_tick_yield(delta)
	var goal: Vector3 = _aside_to if _aside_t > 0.0 and _aside_to != Vector3.INF else _goal
	var detour: int = 1 if goal != _goal else 0   # 1: stepping aside for a human (not stuck), 2: a stuck nudge
	if _nudge_t > 0.0 and _nudge_to != Vector3.INF:
		goal = _nudge_to
		detour = 2
		_nudge_t -= delta
	# 3. the path
	if goal != Vector3.INF:
		if _path_goal == Vector3.INF or _path_goal.distance_to(goal) > float(_g("path", "goal_moved_m", 0.75)) or _need_plan \
				or (_repath_t <= 0.0 and (_path.is_empty() or (mode != Mode.MOVE and mode != Mode.HOLD))):
			if _take_plan_budget():
				_plan(goal)
	# 4. steering
	var wish: Vector3 = Vector3.ZERO
	var remaining: float = 0.0
	_arrived = goal == Vector3.INF or _flat(goal, me) <= _stop_dist
	if not _arrived and not _path.is_empty():
		var reach: float = float(_g("path", "waypoint_m", 0.45))
		while _path_i < _path.size() and _flat(_path[_path_i], me) < reach:
			_path_i += 1
		if _path_i >= _path.size():
			_arrived = _flat(goal, me) <= maxf(_stop_dist, 1.2)
			if not _arrived:
				_need_plan = true
		else:
			var to: Vector3 = _path[_path_i] - me
			to.y = 0.0
			wish = to.normalized()
			remaining = to.length()
			for k: int in range(_path_i + 1, _path.size()):
				remaining += _flat(_path[k], _path[k - 1])
			var slow: float = float(_g("speed", "arrive_slow_m", 1.2))
			if remaining < slow:
				wish *= clampf(remaining / slow, 0.4, 1.0)
	elif not _arrived and _path.is_empty() and goal != Vector3.INF and _flat(goal, me) < 2.0:
		var to2: Vector3 = goal - me
		to2.y = 0.0
		wish = to2.normalized() * 0.6   # the last steps with no path (a point just off the mesh)
	var goal_move: bool = wish.length_squared() > 0.0004
	# personal space / bot spacing (always on, even when standing)
	var push: Vector3 = _space_push(me)
	wish = _no_closer(me, wish)
	wish += push
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	# 5. stance, speed, facing
	var wants_move: bool = wish.length_squared() > 0.0004
	var sprint: bool = _want_sprint(wish, remaining)
	_face(delta, wish if wants_move else Vector3.ZERO, sprint)
	_fill_intent(wish, sprint, remaining, delta)
	var tb: int = Time.get_ticks_usec()
	player.drive_bot(delta, _mi)
	_us_body += Time.get_ticks_usec() - tb
	# sprint-out bookkeeping (fire_ready)
	if _was_sprinting and not player.sprinting:
		_sprint_out = WeaponHolder.sprint_out_time(player.weapons.current() if player.weapons != null else null)
	_was_sprinting = player.sprinting
	# 6. stuck ladder + metrics
	_tick_stuck(delta, me, goal, goal_move, remaining, detour)
	_last_pos = player.global_position
	_us_total += Time.get_ticks_usec() - t0
	_ticks += 1


func _set_mode(m: Mode) -> void:
	if m != mode:
		mode = m
		_no_prog_t = 0.0
		_best_rem = INF
		_stage_done = 0


func _set_goal(pos: Vector3) -> void:
	if _goal != Vector3.INF and _goal.distance_to(pos) < 0.05:
		return
	_goal = pos


func _clear_path() -> void:
	_path = PackedVector3Array()
	_path_i = 0
	_path_goal = Vector3.INF


# ================================================================== planning (navmesh + danger cost)

func _take_plan_budget() -> bool:
	var f: int = Engine.get_physics_frames()
	if f != _plans_frame:
		_plans_frame = f
		_plans_used = 0
	if _plans_used >= int(_g("path", "plans_per_frame", 2)):
		return false
	_plans_used += 1
	return true


func _nav() -> RID:
	return player.get_world_3d().navigation_map


func _snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_nav(), p)


## A navmesh path that never crosses a closed BuyDoor (doors are baked open on some maps); empty if it would.
func _raw_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_nav(), from, to, true, squad.nav_mask() if squad != null else 0x7FFFFFFF)
	for n: Node in player.get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and not d.is_open and path_crosses_door(path, d.global_position, d.global_basis.z, d.global_basis.x, d.size.x * 0.5 + 0.3):
			return PackedVector3Array()
	return path


## Plans to `goal`: the plain path, and when it runs through danger, detours beside its worst spot; the cheapest
## (length + danger) wins.
func _plan(goal: Vector3) -> void:
	_need_plan = false
	_repath_t = float(_g("path", "repath_s", 0.8))
	repaths += 1
	var me: Vector3 = player.global_position
	var base: PackedVector3Array = _raw_path(me, goal)
	_path_goal = goal
	if base.is_empty():
		_path = PackedVector3Array()
		_path_i = 0
		return
	var dz: Array = _danger_list()
	var worst: Vector3 = Vector3.INF
	var cost: Dictionary = _path_cost(base, dz)
	var best: PackedVector3Array = base
	var best_c: float = float(cost["cost"])
	if float(cost["danger"]) > float(_g("danger", "alt_threshold", 6.0)):
		worst = cost["worst"]
		var seg_dir: Vector3 = (goal - me)
		seg_dir.y = 0.0
		seg_dir = seg_dir.normalized() if seg_dir.length_squared() > 0.01 else Vector3.FORWARD
		var side: Vector3 = Vector3(-seg_dir.z, 0.0, seg_dir.x)
		for off: Variant in _g("danger", "alt_offsets_m", [2.5, 4.5]):
			for sgn: float in [1.0, -1.0]:
				var via_want: Vector3 = worst + side * sgn * float(off)
				var via: Vector3 = _snap(via_want)
				if _flat(via, via_want) > 1.0 or absf(via.y - worst.y) > 1.5:
					continue
				var a: PackedVector3Array = _raw_path(me, via)
				var b: PackedVector3Array = _raw_path(via, goal)
				if a.is_empty() or b.is_empty():
					continue
				var joined: PackedVector3Array = a.duplicate()
				joined.append_array(b.slice(1))
				var c2: float = float(_path_cost(joined, dz)["cost"])
				if c2 < best_c:
					best_c = c2
					best = joined
			if best != base:
				break
	_path = best
	_path_i = 1 if best.size() > 1 else 0


## {cost, danger, worst}: path length plus the danger sampled along it.
func _path_cost(path: PackedVector3Array, dz: Array) -> Dictionary:
	var length: float = 0.0
	var danger: float = 0.0
	var worst: Vector3 = path[0] if not path.is_empty() else Vector3.ZERO
	var worst_v: float = -1.0
	var step: float = float(_g("danger", "sample_m", 1.0))
	for i: int in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var seg: float = a.distance_to(b)
		length += seg
		var n: int = maxi(1, int(ceil(seg / step)))
		for k: int in n:
			var p: Vector3 = a.lerp(b, (float(k) + 0.5) / float(n))
			var v: float = _danger_at(p, dz) * (seg / float(n))
			danger += v
			if v > worst_v:
				worst_v = v
				worst = p
	return {"cost": length + danger, "danger": danger, "worst": worst}


## The danger sources this plan weighs: [[kind, pos, radius, cost]] (zombies, blackboard zones, domes, fire, lifts).
func _danger_list() -> Array:
	var out: Array = []
	var me: Vector3 = player.global_position
	var zr: float = float(_g("danger", "zombie_r", 2.5))
	var zc: float = float(_g("danger", "zombie_cost", 5.0))
	for z: Zombie in zombies():
		if _flat(z.global_position, me) < 30.0:
			out.append([0, z.global_position, zr, zc])
	var bb_zones: Array = blackboard_zones(squad)
	var now: float = squad.time() if squad != null else 0.0
	for dzv: Variant in bb_zones:
		var d: Dictionary = dzv as Dictionary
		if d.is_empty() or float(d.get("until", INF)) < now:
			continue
		out.append([1, d.get("pos", Vector3.ZERO), float(d.get("radius", 1.0)), float(d.get("cost", 10.0))])
	_refresh_world_hazards()
	for dome: Node3D in _dome_cache:
		if is_instance_valid(dome):
			out.append([2, dome.global_position, float(dome.get("radius")), float(_g("danger", "dome_cost", 8.0))])
	for f: Node3D in _fire_cache:
		if is_instance_valid(f):
			out.append([1, f.global_position, float(f.get("radius")) if f.get("radius") != null else 1.5, float(_g("danger", "fire_cost", 25.0))])
	for l: Node in player.get_tree().get_nodes_in_group(&"lifts"):
		var box: AABB = _lift_box(l)
		if box.size != Vector3.ZERO and not _lift_ok_now(box):
			out.append([3, box, 0.0, float(_g("danger", "lift_cost", 30.0))])
	return out


## Danger at a point (path cost per metre): zombies fall off with distance, zones and fire are flat inside,
## a Bell Dome only at its rim, live traps and an unsafe lift cage are steep.
func _danger_at(p: Vector3, dz: Array) -> float:
	var v: float = 0.0
	for e: Array in dz:
		match int(e[0]):
			0:
				var d: float = _flat(e[1] as Vector3, p)
				if d < float(e[2]) and absf((e[1] as Vector3).y - p.y) < 2.0:
					v += float(e[3]) * (1.0 - d / float(e[2]))
			1:
				if _flat(e[1] as Vector3, p) < float(e[2]) and absf((e[1] as Vector3).y - p.y) < 2.5:
					v += float(e[3])
			2:
				var dd: float = _flat(e[1] as Vector3, p)
				if absf(dd - float(e[2])) < float(_g("danger", "dome_edge_m", 1.2)) and absf((e[1] as Vector3).y - p.y) < 3.0:
					v += float(e[3])
			3:
				if (e[1] as AABB).has_point(p + Vector3.UP * 0.5):
					v += float(e[3])
	for t: Node in _trap_cache:
		if is_instance_valid(t) and bool(t.call("danger_contains", p)):
			v += float(_g("danger", "trap_cost", 40.0))
	return v


## The squad blackboard's danger zones when the brain keeps one (squad.blackboard.danger_zones), else [].
static func blackboard_zones(s: Object) -> Array:
	if s == null:
		return []
	var bb: Variant = s.get("blackboard")
	if bb == null:
		return []
	var zones: Variant = null
	if bb is Dictionary:
		zones = (bb as Dictionary).get("danger_zones")
	elif bb is Object:
		zones = (bb as Object).get("danger_zones")
	return zones if zones is Array else []


## Active zombies, shared by the squad and refreshed once per physics frame.
func zombies() -> Array[Zombie]:
	var f: int = Engine.get_physics_frames()
	if f != _z_frame:
		_z_frame = f
		_z_cache.clear()
		var dir: ZombieDirector = squad.director() if squad != null else null
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z.state != Zombie.State.DEAD and z.state != Zombie.State.INACTIVE:
					_z_cache.append(z)
	return _z_cache


func _refresh_world_hazards() -> void:
	var f: int = Engine.get_physics_frames()
	if f - _dome_frame < 15 and f >= _dome_frame:
		return
	_dome_frame = f
	_dome_cache.clear()
	_fire_cache.clear()
	_trap_cache.clear()
	for t: Node in player.get_tree().get_nodes_in_group(&"traps"):
		if t.has_method("danger_contains"):
			_trap_cache.append(t)
	for n: Node in player.get_tree().get_nodes_in_group(&"bell_domes"):
		if n is Node3D:
			_dome_cache.append(n as Node3D)
	for n2: Node in player.get_tree().get_nodes_in_group(&"fire_hazards"):
		if n2 is Node3D:
			_fire_cache.append(n2 as Node3D)


# ================================================================== the lift (Kaltenbrunn)

func _lift_box(l: Node) -> AABB:
	var l3: Node3D = l as Node3D
	if l3 == null:
		return AABB()
	var size: Vector3 = l3.get("cage_size") if l3.get("cage_size") != null else Vector3(4, 3, 4)
	var cage: Node3D = l3.get("_cage") as Node3D
	var c: Vector3 = cage.global_position if cage != null else l3.global_position
	return AABB(c - Vector3(size.x * 0.5, 0.5, size.z * 0.5), Vector3(size.x, size.y + 1.0, size.z))


func _lift_ok_now(box: AABB) -> bool:
	var inside: int = 0
	var standing: int = 0
	if squad != null:
		for p: Player in squad.standing():
			standing += 1
			if box.has_point(p.global_position + Vector3.UP * 0.5):
				inside += 1
	var nearest: float = INF
	var c: Vector3 = box.get_center()
	for z: Zombie in zombies():
		nearest = minf(nearest, z.global_position.distance_to(c))
	return lift_ok(inside, standing, nearest, float(_g("lift", "train_near_m", 10.0)))


## The lift rule: ride only when the whole standing squad is in the cage and no zombie (a train) is near.
static func lift_ok(squad_in_cage: int, squad_standing: int, nearest_zombie_m: float, train_near_m: float) -> bool:
	return squad_standing > 0 and squad_in_cage >= squad_standing and nearest_zombie_m > train_near_m


# ================================================================== follow (the wedge)

func _tick_follow_goal(delta: float) -> void:
	if _leader == null or not is_instance_valid(_leader) or _leader == player:
		_goal = Vector3.INF
		return
	_slot_t -= delta
	if _slot_t > 0.0 and _slot_pos != Vector3.INF:
		_goal = _slot_pos
		return
	_slot_t = float(_g("formation", "refresh_s", 0.3))
	var lv: Vector3 = Vector3(_leader.velocity.x, 0.0, _leader.velocity.z)
	if squad != null and _leader == squad.human():
		lv = squad.leader_vel
	var moving: bool = lv.length() > float(_g("formation", "moving_mps", 1.6))
	var heading: Vector3 = lv if moving else -_leader.global_basis.z
	var base: Vector3 = _leader.global_position + (lv * float(_g("formation", "lead_s", 0.6)) if moving else Vector3.ZERO)
	var slots: Array = _g("formation", "moving" if moving else "still", [])
	var off: Vector3 = wedge_offset(slots, _slot, heading)
	# catch up at a run when the slot is far (a training leader walks at full speed)
	var slot_d: float = _flat(base + off, player.global_position)
	_urgency = 0.9 if slot_d > float(_g("formation", "run_m", 3.5)) else (0.6 if moving else 0.4)
	var cands: Array[Vector3] = [base + off, base + off * 0.65]
	var mirror: Vector3 = wedge_offset(slots, _slot, heading, true)
	cands.append(base + mirror)
	cands.append(base + mirror * 0.65)
	var fallback: Vector3 = Vector3.INF
	for want: Vector3 in cands:
		var p: Vector3 = _snap(want)
		if _flat(p, want) > 1.0 or absf(p.y - _leader.global_position.y) > 1.5:
			continue
		if _bad_stand(p):
			if fallback == Vector3.INF:
				fallback = p
			continue
		_slot_pos = p
		_goal = p
		return
	_slot_pos = fallback if fallback != Vector3.INF else _snap(_leader.global_position - heading.normalized() * 2.0)
	_goal = _slot_pos


## Slot `i`'s world offset from the leader for a heading: slots = [[angle_deg, radius_m], ...] with angles from
## the heading (+ = its left); slots past the list repeat further out. `mirrored` flips the side.
static func wedge_offset(slots: Array, i: int, heading: Vector3, mirrored: bool = false) -> Vector3:
	var fwd: Vector3 = Vector3(heading.x, 0.0, heading.z)
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	if slots.is_empty():
		slots = [[135.0, 2.8], [-135.0, 2.8], [180.0, 3.8]]
	var s: Array = slots[i % slots.size()]
	var ring: int = i / slots.size()
	var ang: float = deg_to_rad(float(s[0])) * (-1.0 if mirrored else 1.0)
	var r: float = float(s[1]) + 1.2 * float(ring)
	return fwd.rotated(Vector3.UP, ang) * r


## A spot a bot should not park on: a doorway / stairs (squad chokes), a live trap, a danger zone.
func _bad_stand(p: Vector3) -> bool:
	if squad != null and not squad.choke_at(p).is_empty():
		return true
	_refresh_world_hazards()
	for t: Node in _trap_cache:
		if is_instance_valid(t) and bool(t.call("danger_contains", p)):
			return true
	for dzv: Variant in blackboard_zones(squad):
		var d: Dictionary = dzv as Dictionary
		if not d.is_empty() and _flat(d.get("pos", Vector3.ZERO), p) < float(d.get("radius", 0.0)):
			return true
	return false


# ================================================================== training

func _active_route() -> TrainingRoute:
	if _route != null:
		return _route
	# train(null): a ring round the leader (or where we stand), rebuilt when they move off it
	var c: Vector3 = player.global_position
	if squad != null:
		var h: Player = squad.human()
		if h != null and is_instance_valid(h) and h != player and not h.spectating:
			c = h.global_position
	if _fallback_route == null or _fallback_center == Vector3.INF or _flat(c, _fallback_center) > 6.0:
		_fallback_center = c
		var r: float = float(_g("train", "fallback_r_m", 5.5))
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in 12:
			var a: float = float(k) / 12.0 * TAU
			var want: Vector3 = c + Vector3(cos(a), 0.0, sin(a)) * r
			var sp: Vector3 = _snap(want)
			if absf(sp.y - c.y) < 1.5:
				pts.append(sp)
		_fallback_route = TrainingRoute.make("fallback", pts, 2.0, 1) if pts.size() >= 4 else null
		if _fallback_route != null:
			_t_param = _fallback_route.closest_param(player.global_position)
	return _fallback_route


## The direction round the loop with fewer zombies close ahead.
func _pick_train_dir(r: TrainingRoute) -> int:
	var fwd: int = _density_ahead(r, _t_param, 1, 8.0)
	var back: int = _density_ahead(r, _t_param, -1, 8.0)
	return 1 if fwd <= back else -1


func _density_ahead(r: TrainingRoute, from_param: float, dir: int, dist: float) -> int:
	var br: float = float(_g("train", "block_r", 1.6))
	var n: int = 0
	var zs: Array[Zombie] = zombies()
	var d: float = 1.0
	while d <= dist:
		var p: Vector3 = r.point_at(r.advance(from_param, d, dir))
		for z: Zombie in zs:
			if _flat(z.global_position, p) < br and absf(z.global_position.y - p.y) < 2.0:
				n += 1
		d += 1.0
	return n


func _tick_train(delta: float) -> void:
	var r: TrainingRoute = _active_route()
	if r == null or r.length() < 4.0:
		_t_ok = false
		_goal = Vector3.INF
		return
	var me: Vector3 = player.global_position
	# track our place on the loop (the nearest point within a window round the last one: overlapping stretches,
	# like a lollipop's stick, never make it jump)
	_t_param = _near_param(r, me, _t_param)
	var off_line: float = _flat(r.point_at(_t_param), me)
	_t_think -= delta
	if _t_think <= 0.0:
		_t_think = 0.2
		_train_think(r, me, off_line)
	var lead: float = float(_g("train", "lead_m", 3.5))
	var target_param: float = r.advance(_t_param, lead, _t_dir)
	_goal = _snap(r.point_at(target_param))
	_urgency = _t_urg
	if r == _route and off_line < 1.5 and _nudge_t <= 0.0 and _aside_t <= 0.0:
		# on an authored (validated) loop: its own samples are the path, no navmesh query
		_path = PackedVector3Array()
		var d: float = 0.5
		while d <= lead + 0.01:
			_path.append(r.point_at(r.advance(_t_param, d, _t_dir)))
			d += 0.5
		_path_i = 0
		_path_goal = _goal
		_need_plan = false
		_repath_t = float(_g("path", "repath_s", 0.8))


func _train_think(r: TrainingRoute, me: Vector3, off_line: float) -> void:
	var zs: Array[Zombie] = zombies()
	var horde_r: float = float(_g("train", "horde_r", 14.0))
	# the train's head: the nearest zombie behind us on the loop (or simply the nearest)
	_t_head = null
	var head_d: float = INF
	for z: Zombie in zs:
		var d: float = z.global_position.distance_to(me)
		if d < horde_r and d < head_d:
			head_d = d
			_t_head = z
	# keep it tight: run when it's close, walk at mid range, let it catch up when it falls back
	if head_d < float(_g("train", "close_m", 3.0)):
		_t_urg = 1.0
	elif head_d > float(_g("train", "far_m", 7.5)):
		_t_urg = 0.0
	else:
		_t_urg = 0.5
	# don't get cut off: before committing to the next stretch, look ahead (zombies on it, a ray along it)
	var every: float = float(_g("train", "check_every_m", 2.0))
	var since: float = r.distance_along(_t_check_at, _t_param, _t_dir) if _t_check_at != INF else INF
	if since == INF or (since >= every and since < r.length() * 0.5):
		_t_check_at = _t_param
		if _cut_off(r, _t_param, _t_dir):
			if _t_rev_cd <= 0.0 and not _cut_off(r, _t_param, -_t_dir):
				_t_dir = -_t_dir
				_t_rev_cd = float(_g("train", "reverse_cd_s", 1.5))
				reversals += 1
				_t_ok = true
			else:
				_t_ok = false   # boxed in both ways (or just turned): the brain should fight its way out
		else:
			_t_ok = true
		if not _t_ok:
			_t_urg = 1.0
	# far from the loop (just entered train mode): head for it at a run
	if off_line > 3.0:
		_t_urg = maxf(_t_urg, 0.8)


func _cut_off(r: TrainingRoute, param: float, dir: int) -> bool:
	var ahead: float = float(_g("train", "check_ahead_m", 6.0))
	var me: Vector3 = player.global_position
	var n: int = _density_ahead(r, param, dir, ahead)
	if n >= int(_g("train", "block_count", 2)):
		return true
	# one on the line close ahead
	var br: float = float(_g("train", "block_r", 1.6))
	var d: float = 1.0
	while d <= 4.0:
		var p: Vector3 = r.point_at(r.advance(param, d, dir))
		for z: Zombie in zombies():
			if _flat(z.global_position, p) < br * 0.8 and absf(z.global_position.y - p.y) < 2.0:
				return true
		d += 1.0
	# the ray along the next stretch (walls of a sharp corner don't count: only a zombie body blocks)
	var to: Vector3 = r.point_at(r.advance(param, minf(ahead, 4.0), dir)) + Vector3.UP * 1.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(me + Vector3.UP * 1.0, to, MASK_BLOCK, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] is Zombie


## The loop parameter nearest `pos` within +-6 m of `hint` (falls back to the whole loop when far off it).
func _near_param(r: TrainingRoute, pos: Vector3, hint: float) -> float:
	var best: float = INF
	var best_t: float = hint
	var d: float = -6.0
	while d <= 6.0:
		var t: float = r.wrap_param(hint + d)
		var p: Vector3 = r.point_at(t)
		var dd: float = _flat(p, pos) + (50.0 if absf(p.y - pos.y) > 2.0 else 0.0)
		if dd < best:
			best = dd
			best_t = t
		d += 0.5
	if best > 3.0:
		return r.closest_param(pos)
	return best_t


# ================================================================== never block a human

## The push out of a human's personal space: zero outside the bubble (personal_m, stretched ahead_m along their
## velocity when the bot is ahead of them); inside, away from them and, when they move, mostly sideways off their
## line. Length 0..1.5 (1.5 = on top of them).
static func personal_space_push(me: Vector3, human: Vector3, human_vel: Vector3, personal_m: float = 1.2, ahead_m: float = 1.0) -> Vector3:
	var off: Vector3 = Vector3(me.x - human.x, 0.0, me.z - human.z)
	var d: float = off.length()
	var hv: Vector3 = Vector3(human_vel.x, 0.0, human_vel.z)
	var speed: float = hv.length()
	var r: float = personal_m
	var fwd: Vector3 = hv / speed if speed > 0.3 else Vector3.ZERO
	var ahead: bool = fwd != Vector3.ZERO and d > 0.001 and fwd.dot(off / d) > 0.2
	if ahead:
		r += ahead_m * clampf(speed / 4.5, 0.0, 1.0)
	if d >= r:
		return Vector3.ZERO
	var away: Vector3 = off / d if d > 0.001 else (Vector3(-fwd.z, 0.0, fwd.x) if fwd != Vector3.ZERO else Vector3.RIGHT)
	var dir: Vector3 = away
	if fwd != Vector3.ZERO:
		var side: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
		if side.dot(off) < 0.0:
			side = -side
		dir = (side * 0.85 + away * 0.45).normalized()
	return dir * (1.5 * (1.0 - d / r))


## Should a bot at `me` step out of the way of a human at `human` moving at `hv`? True when the human's straight
## line passes within pass_m of the bot within horizon_s (and they are coming toward it).
static func should_yield(me: Vector3, human: Vector3, hv: Vector3, horizon_s: float, pass_m: float) -> bool:
	var v: Vector3 = Vector3(hv.x, 0.0, hv.z)
	var speed: float = v.length()
	if speed < 0.8:
		return false
	var rel: Vector3 = Vector3(me.x - human.x, 0.0, me.z - human.z)
	var t: float = rel.dot(v) / (speed * speed)   # time of closest approach
	if t < 0.0 or t > horizon_s:
		return false
	var closest: Vector3 = rel - v * t
	return closest.length() < pass_m


func _space_push(me: Vector3) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	if squad == null:
		return push
	var pm: float = float(_g("space", "personal_m", 1.2))
	var am: float = float(_g("space", "ahead_m", 1.0))
	var bm: float = float(_g("space", "bot_m", 0.9))
	for p: Player in squad.all_players():
		if p == player or p.spectating or not is_instance_valid(p):
			continue
		if absf(p.global_position.y - me.y) > 1.6:
			continue
		if p.is_bot:
			var off: Vector3 = Vector3(me.x - p.global_position.x, 0.0, me.z - p.global_position.z)
			var d: float = off.length()
			if d < bm:
				push += (off / d if d > 0.01 else Vector3(cos(float(player.player_id) * 2.1), 0.0, sin(float(player.player_id) * 2.1))) * (1.0 - d / bm) * 0.8
		elif not p.downed:
			push += personal_space_push(me, p.global_position, p.velocity, pm, am) * 1.4   # humans weigh more
	return push


## Never walk into a human's bubble: the part of `wish` heading at a human inside personal_m + 0.4 is taken out
## (the bot slides round them instead, and the push moves it out).
func _no_closer(me: Vector3, wish: Vector3) -> Vector3:
	if squad == null or wish == Vector3.ZERO:
		return wish
	var r: float = float(_g("space", "personal_m", 1.2)) + 0.4
	for h: Player in squad.all_players():
		if h.is_bot or h == player or h.spectating or h.downed or not is_instance_valid(h):
			continue   # (a downed human is someone to revive, not to give way to)
		var to: Vector3 = Vector3(h.global_position.x - me.x, 0.0, h.global_position.z - me.z)
		var d: float = to.length()
		if d > r or d < 0.01 or absf(h.global_position.y - me.y) > 1.6:
			continue
		var dir: Vector3 = to / d
		var c: float = wish.dot(dir)
		if c > 0.0:
			wish -= dir * c
	return wish


## Steps aside: a human about to pass through us, a stopped bot in a choke (door, stairs) or on the human's
## training line. Sets a short-lived aside goal that overrides the brain's for ~1 s.
func _tick_yield(delta: float) -> void:
	if squad == null or _aside_t > 0.0:
		return
	var me: Vector3 = player.global_position
	var stopped: bool = _arrived or _goal == Vector3.INF
	if stopped and _near_downed(me):
		_choke_t = 0.0
		return   # reviving (or covering) a downed teammate: stay put, even in a doorway
	var horizon: float = float(_g("space", "horizon_s", 1.2))
	var pass_m: float = float(_g("space", "pass_m", 1.3))
	var in_choke: bool = not squad.choke_at(me).is_empty()
	_choke_t = _choke_t + delta if in_choke and stopped else 0.0
	for h: Player in squad.all_players():
		if h.is_bot or h == player or h.spectating or h.downed or not is_instance_valid(h):
			continue
		if absf(h.global_position.y - me.y) > 1.6 or _flat(h.global_position, me) > 6.0:
			continue
		var hv: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
		var on_line: bool = stopped and _on_training_line(me, h.global_position, hv)
		if should_yield(me, h.global_position, hv, horizon, pass_m) or on_line:
			_step_aside(me, h.global_position, hv)
			return
	if _choke_t > float(_g("space", "choke_leave_s", 0.6)):
		_step_aside(me, me + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), Vector3.ZERO)
		_choke_t = 0.0


## A downed teammate within 2 m (the bot is reviving or covering them).
func _near_downed(me: Vector3) -> bool:
	for p: Player in squad.all_players():
		if p != player and p.downed and not p.spectating and is_instance_valid(p) and _flat(p.global_position, me) < 2.0:
			return true
	return false


## On the human's training line: within line_clear_m of where their velocity takes them in the next line_s.
func _on_training_line(me: Vector3, human: Vector3, hv: Vector3) -> bool:
	if hv.length() < 1.2:
		return false
	var a: Vector2 = Vector2(human.x, human.z)
	var end: Vector3 = human + hv * float(_g("space", "line_s", 3.0))
	var b: Vector2 = Vector2(end.x, end.z)
	var p: Vector2 = Vector2(me.x, me.z)
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < float(_g("space", "line_clear_m", 1.1))


func _step_aside(me: Vector3, human: Vector3, hv: Vector3) -> void:
	var dir: Vector3 = BotConfig.step_aside_dir(me, human, hv)
	var cands: Array[Vector3] = [me + dir * 1.8, me + dir * 1.1, me + dir * 2.6]
	if hv.length() > 0.5:
		cands.append(me + dir * 1.6 + hv.normalized() * 1.5)
	cands.append(me - dir * 1.8)
	for c: Vector3 in cands:
		var p: Vector3 = _snap(c)
		if _flat(p, c) > 0.8 or absf(p.y - me.y) > 1.2:
			continue
		if _flat(p, human) < 1.4 or _bad_stand(p):
			continue
		if hv.length() > 1.2 and _on_training_line(p, human, hv):
			continue
		_aside_to = p
		_aside_t = 0.9
		yields += 1
		_need_plan = true
		return


# ================================================================== speed, facing, intent

func _want_sprint(wish: Vector3, remaining: float) -> bool:
	if _look_set or wish.length_squared() < 0.25:
		return false
	var u: float = _urgency
	if _aside_t > 0.0:
		u = 0.5
	if u < float(_g("speed", "sprint_urgency", 0.7)) or remaining < float(_g("speed", "sprint_min_m", 3.0)):
		return false
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	return fwd.normalized().angle_to(wish.normalized()) < deg_to_rad(float(_g("speed", "sprint_face_deg", 55.0)))


## Turns the body: toward the look when the aim layer set one, else toward where it moves (or the hold facing
## when standing). Yaw and pitch at the skill's turn rate (x sprint_turn_mult at a run).
func _face(delta: float, wish: Vector3, sprint: bool) -> void:
	var want: Vector3 = Vector3.ZERO
	if _look_set:
		want = _look
	elif wish != Vector3.ZERO:
		want = Vector3(wish.x, 0.0, wish.z).normalized()
	elif mode == Mode.HOLD and _hold_facing != Vector3.ZERO:
		want = _hold_facing.normalized()
	if want == Vector3.ZERO:
		return
	var rate: float = turn_rate()
	if sprint or player.sprinting:
		rate *= float(player._mv.get("sprint_turn_mult", 0.78))
	var step: float = rate * delta
	var want_yaw: float = atan2(-want.x, -want.z)
	if Vector2(want.x, want.z).length_squared() > 0.0001:
		var dy: float = wrapf(want_yaw - player.rotation.y, -PI, PI)
		player.rotation.y = wrapf(player.rotation.y + clampf(dy, -step, step), -PI, PI)
	var want_pitch: float = asin(clampf(want.y, -1.0, 1.0)) if _look_set else 0.0
	var dp: float = want_pitch - player.head.rotation.x
	player.head.rotation.x = clampf(player.head.rotation.x + clampf(dp, -step, step), deg_to_rad(-80.0), deg_to_rad(80.0))


## The skill's turn rate (bots.json skills.<skill>.turn_rate, rad/s).
func turn_rate() -> float:
	if _turn_rate < 0.0 or _turn_skill != GameState.bot_skill:
		_turn_skill = GameState.bot_skill
		_turn_rate = float(BotConfig.skill(BotConfig.cfg(), _turn_skill).get("turn_rate", 6.0))
	return _turn_rate


func _fill_intent(wish: Vector3, sprint: bool, remaining: float, _delta: float) -> void:
	_mi.move = MoveIntent.local_move(player.global_basis, wish)
	_mi.sprint_held = sprint
	_mi.sprint_pressed = sprint and not _sprint_pressed_last
	_sprint_pressed_last = sprint
	_mi.jump_pressed = false
	_mi.jump_held = false
	_mi.fire_pressed = false
	_mi.fire_held = false
	_mi.ads_held = false
	# stand up when nothing asks for a crouch (a revive leaves the body crouched)
	var crouch_press: bool = player.crouching and not player.sliding and not player.prone and not player._head_blocked()
	# slide: fleeing at a sprint with something on our heels and a straight run ahead
	if not crouch_press and player.sprinting and _urgency >= float(_g("slide", "urgency", 0.9)) and _slide_cd <= 0.0 \
			and remaining >= float(_g("slide", "straight_m", 6.0)) and _straight_ahead() >= float(_g("slide", "straight_m", 6.0)) and _chaser_behind():
		crouch_press = true
		_slide_cd = float(_g("slide", "cooldown_s", 4.0))
		slides_started += 1
	_mi.crouch_pressed = crouch_press and not _crouch_pressed_last
	_crouch_pressed_last = crouch_press
	_mi.crouch_held = false
	# mantle: blocked while walking into something waist-high (Player.probe_mantle finds a ledge in front)
	if _block_t >= float(_c.get("mantle_after_s", 0.35)) and wish.length_squared() > 0.25 and player.is_on_floor():
		var fwd: Vector3 = -player.global_basis.z
		if Vector3(fwd.x, 0, fwd.z).normalized().dot(wish.normalized()) > 0.8 and not player.probe_mantle().is_empty():
			_mi.jump_pressed = true
			_mi.jump_held = true
			_mi.move = Vector2(0.0, -1.0)
			mantles_started += 1
			_block_t = 0.0


func _straight_ahead() -> float:
	if _path_i >= _path.size():
		return 0.0
	var me: Vector3 = player.global_position
	var d0: Vector3 = (_path[_path_i] - me)
	d0.y = 0.0
	var l: float = d0.length()
	if l < 0.01:
		return 0.0
	d0 /= l
	for k: int in range(_path_i + 1, _path.size()):
		var seg: Vector3 = _path[k] - _path[k - 1]
		seg.y = 0.0
		if seg.length() > 0.05 and seg.normalized().dot(d0) < 0.95:
			break
		l += seg.length()
	return l


func _chaser_behind() -> bool:
	var me: Vector3 = player.global_position
	var fwd: Vector3 = -player.global_basis.z
	var r: float = float(_g("slide", "chaser_m", 4.0))
	for z: Zombie in zombies():
		var off: Vector3 = z.global_position - me
		off.y = 0.0
		if off.length() < r and off.dot(fwd) < 0.0:
			return true
	return false


# ================================================================== stuck recovery

## The ladder: no progress for stuck.repath_s -> re-plan, nudge_s -> a local random walk, teleport_s -> a
## teleport to a safe navmesh point (only unseen). Pure, unit-tested: 0 none, 1 repath, 2 nudge, 3 teleport.
static func stuck_stage(no_progress_s: float, repath_s: float = 2.0, nudge_s: float = 4.0, teleport_s: float = 8.0) -> int:
	if no_progress_s >= teleport_s:
		return 3
	if no_progress_s >= nudge_s:
		return 2
	if no_progress_s >= repath_s:
		return 1
	return 0


func _tick_stuck(delta: float, me_before: Vector3, goal: Vector3, wants_move: bool, remaining: float, detour: int) -> void:
	var now: Vector3 = player.global_position
	var moved: float = now.distance_to(me_before)
	# the soak metric, unchanged from the old brain: wants to move, moved under 0.015 m this frame
	if wants_move and moved < 0.015:
		BotMetrics.note(player.player_id, &"stuck_time", delta)
	_block_t = _block_t + delta if wants_move and moved < 0.02 * (delta * 60.0) else 0.0
	if detour == 1:
		return   # stepping aside for a human on purpose
	if detour == 0 and (goal == Vector3.INF or _arrived):
		_no_prog_t = 0.0
		_best_rem = INF
		_stage_done = 0
		return
	if detour == 0 and not wants_move and _path.is_empty() and not _need_plan:
		return   # no way there (a shut door): the brain's problem, not a stuck body
	# progress is only ever measured toward the real goal (a nudge's own little walk doesn't count)
	var rem: float = remaining if remaining > 0.0 and detour == 0 else _flat(_goal, now)
	if detour == 0 and _rebase and remaining > 0.0:
		_rebase = false
		_best_rem = minf(_best_rem, rem)   # back from a nudge: where it landed is not progress by itself
	if detour == 0 and (_best_rem == INF or rem < _best_rem - float(_g("stuck", "progress_m", 0.3))):
		_best_rem = rem
		_no_prog_t = 0.0
		_stage_done = 0
		return
	# a goal that moves (a leader's slot, a train's lead point) may never get closer while the body walks fine:
	# real movement (window_m in a window_s window, on the real goal's path) also counts as progress. Once this
	# ladder has nudged, only movement that has left the stuck spot (escape_m) counts: walking back from a nudge
	# to the same wall is not progress (it used to restart the ladder after every nudge, so the bot never
	# reached the teleport and stayed stuck for good, unseen or not).
	_win_t += delta
	if _win_t >= float(_g("stuck", "window_s", 1.0)):
		var net: float = _flat(now, _win_pos)
		_win_t = 0.0
		_win_pos = now
		var escaped: bool = _stage_done < 2 or _stuck_at == Vector3.INF or _flat(now, _stuck_at) >= float(_g("stuck", "escape_m", 4.0))
		if detour == 0 and escaped and net >= float(_g("stuck", "window_m", 0.6)):
			_best_rem = rem
			_no_prog_t = 0.0
			_stage_done = 0
			return
	_no_prog_t += delta
	var stage: int = stuck_stage(_no_prog_t, float(_g("stuck", "repath_s", 2.0)), float(_g("stuck", "nudge_s", 4.0)), float(_g("stuck", "teleport_s", 8.0)))
	if stage >= 1 and _stage_done < 1:
		_stage_done = 1
		_need_plan = true
		_path_goal = Vector3.INF
		BotMetrics.note(player.player_id, &"stuck")
	elif stage >= 2 and _stage_done < 2:
		_stage_done = 2
		_stuck_at = now
		_start_nudge(now)
		BotMetrics.note(player.player_id, &"stuck")
	elif stage >= 3 and _tp_try_t <= 0.0:
		_tp_try_t = 1.0
		if _teleport_safe(_goal):
			_no_prog_t = 0.0
			_best_rem = INF
			_stage_done = 0
		else:
			_start_nudge(now)   # someone is watching: keep wriggling, try again in a second


func _start_nudge(now: Vector3) -> void:
	var rr: Array = _g("stuck", "nudge_r_m", [1.5, 3.0])
	for k: int in 8:
		var a: float = _rng.randf() * TAU
		var want: Vector3 = now + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(float(rr[0]), float(rr[1]))
		var p: Vector3 = _snap(want)
		if _flat(p, want) < 0.8 and absf(p.y - now.y) < 1.2 and not _bad_stand(p):
			_nudge_to = p
			_nudge_t = float(_g("stuck", "nudge_walk_s", 1.2))
			_rebase = true
			_need_plan = true
			nudges += 1
			return


## Teleports past what holds the bot: to the goal when it is within 8 m along the path, else to the furthest
## path point 3-8 m on (a safe navmesh spot: no choke, trap or zombie), only when no human can see the bot or the
## spot. Logged (BotMetrics teleport). True when it happened.
func _teleport_safe(goal: Vector3) -> bool:
	var me: Vector3 = player.global_position
	var cands: Array[Vector3] = []
	var p0: PackedVector3Array = _raw_path(me, goal) if goal != Vector3.INF else PackedVector3Array()
	var acc: float = 0.0
	for i: int in range(1, p0.size()):
		var seg: float = p0[i].distance_to(p0[i - 1])
		if acc + seg > 8.0:
			cands.push_front(p0[i - 1].lerp(p0[i], clampf((8.0 - acc) / maxf(0.01, seg), 0.0, 1.0)))
			break
		acc += seg
		if acc >= 3.0:
			cands.push_front(p0[i])   # the furthest first
	for c: Vector3 in cands:
		if _bad_stand(c) or not _unseen(me) or not _unseen(c):
			continue
		var clear: bool = true
		for z: Zombie in zombies():
			if _flat(z.global_position, c) < 2.5:
				clear = false
				break
		if not clear:
			continue
		player.global_position = c + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		_clear_path()
		_need_plan = true
		teleports += 1
		BotMetrics.note(player.player_id, &"teleport")
		return true
	return false


## For the brain's "cut off from the leader" catch-up: a teleport near the leader under the same rule (no human
## sees the bot vanish or appear). True when it happened.
func teleport_near(leader: Player) -> bool:
	if leader == null or not is_instance_valid(leader):
		return false
	if not _unseen(player.global_position):
		return false
	var back: Vector3 = leader.global_basis.z
	for k: int in 8:
		var a: float = float(k) * 0.8 - 2.8
		var want: Vector3 = leader.global_position + back.rotated(Vector3.UP, a) * 4.0
		var p: Vector3 = _snap(want)
		if _flat(p, want) > 1.2 or absf(p.y - leader.global_position.y) > 1.0 or _bad_stand(p) or not _unseen(p):
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(leader.global_position + Vector3.UP * 0.9, p + Vector3.UP * 0.9, MASK_WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue   # (behind a wall from the leader: they'd be cut off again)
		player.global_position = p + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		_clear_path()
		teleports += 1
		BotMetrics.note(player.player_id, &"teleport")
		return true
	return false


## No human sees `p`: outside every human's view cone (view_cone_deg, view_m) or behind a wall from their eye.
func _unseen(p: Vector3) -> bool:
	if squad == null:
		return true
	var cone: float = deg_to_rad(float(_g("stuck", "view_cone_deg", 65.0)))
	var view_m: float = float(_g("stuck", "view_m", 60.0))
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for h: Player in squad.all_players():
		if h.is_bot or h.spectating or not is_instance_valid(h) or h.camera == null:
			continue
		var eye: Vector3 = h.camera.global_position
		var to: Vector3 = p + Vector3.UP * 1.0 - eye
		var d: float = to.length()
		if d > view_m:
			continue
		if d < 2.0:
			return false   # right next to them: they'd notice
		if (-h.camera.global_basis.z).angle_to(to / d) > cone:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, p + Vector3.UP * 1.0, MASK_WORLD)
		if space.intersect_ray(q).is_empty():
			return false
	return true


# ================================================================== doors (pure)

## Does `path` cross a door plane (at `door_pos`, normal `door_normal`, along `door_along`) within `half_width`
## of its middle? The same rule as ZombieDirector.door_crossed, on plain vectors (unit-tested).
static func path_crosses_door(path: PackedVector3Array, door_pos: Vector3, door_normal: Vector3, door_along: Vector3, half_width: float) -> bool:
	var nrm: Vector3 = Vector3(door_normal.x, 0.0, door_normal.z).normalized()
	var along: Vector3 = Vector3(door_along.x, 0.0, door_along.z).normalized()
	var last_side: float = 0.0
	var last_p: Vector3 = Vector3.ZERO
	for p: Vector3 in path:
		if absf(p.y - door_pos.y) > 2.2:
			last_side = 0.0
			continue
		var dist: float = nrm.dot(p - door_pos)
		if absf(dist) < 0.02:
			if absf(along.dot(p - door_pos)) <= half_width and last_side != 0.0:
				return true
			continue
		var side: float = signf(dist)
		if last_side != 0.0 and side != last_side:
			var dl: float = nrm.dot(last_p - door_pos)
			var t: float = dl / (dl - dist)
			var hit: Vector3 = last_p.lerp(p, t)
			if absf(along.dot(hit - door_pos)) <= half_width:
				return true
		last_side = side
		last_p = p
	return false


# ================================================================== helpers

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _poly_len(p: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, p.size()):
		l += p[i].distance_to(p[i - 1])
	return l
