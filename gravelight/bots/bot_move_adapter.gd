class_name BotMoveAdapter
extends RefCounted
## The brain's movement layer until the U03 section 3 locomotion layer (BotLocomotion, branch u03-2-locomotion)
## is merged: the same API, over the T-031 / U02 section 5 movement code (nav paths that never cross a closed
## door, the moving formation, making way for the human, choke points, traps, personal space, stuck handling).
## The brain decides WHAT; this decides HOW. Switching is one line in BotBrain.setup (the `loco` instance).
##
## Each physics frame the brain calls exactly one of move_to / follow / hold / train / stop, optionally
## look_at_dir (the aim layer), then tick(delta). urgency: 0 walk ... >= 0.7 sprint (not while looking off the
## heading) ... 1 flee. Facing: look_at_dir turns the body (player.rotation.y, head.rotation.x) toward a
## direction at the skill's turn_rate; clear_look() faces the way it moves. Stuck: no progress for 2 s ->
## repath, 4 s -> a nudge (a short random walk), 8 s -> a teleport to the nearest safe navmesh point only when
## no human can see the bot (each one logged: BotMetrics.note(pid, &"teleport")).

enum M { NONE, MOVE, FOLLOW, HOLD, TRAIN }

const MASK_LOS: int = 1 | (1 << 8)
const GRAVITY: float = 14.0   # the 1 g fallback; live: GameState.g_player() (T-112)

var player: Player
var squad: BotSquad
var index: int = 0
var _follow: Dictionary = {}
var _pcfg: Dictionary = {}
var _sk: Dictionary = {}
var _mode: M = M.NONE
var _target: Vector3 = Vector3.INF
var _target_snap: Vector3 = Vector3.INF
var _urgency: float = 0.0
var _stop_dist: float = 0.6
var _leader: Player = null
var _slot: int = 0
var _facing: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
# path
var _goal: Vector3 = Vector3.INF
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _repath_t: float = 0.0
var _sprint: bool = false
var _sprint_t: float = 0.0
# stuck
var _last_pos: Vector3 = Vector3.ZERO
var _progress_pos: Vector3 = Vector3.ZERO
var _no_progress_t: float = 0.0
var _stuck_frame_t: float = 0.0
var _nudge_t: float = 0.0
var _nudge_dir: Vector3 = Vector3.ZERO
var _stuck_stage: int = 0
var teleports: int = 0
# make way / chokes
var _aside_cd: float = 0.0
var _cone_t: float = 0.0
var _choke_t: float = 0.0
var _choke_kind: String = ""
var _choke_reported: bool = false
var _narrow: bool = false
var choke_reports: int = 0
var _watch_t: float = 0.0
var _doors: Array[BuyDoor] = []
var _traps: Array[Node] = []
# training (free loop until TrainingRoute lands)
var _route: Variant = null
var _ring_center: Vector3 = Vector3.INF
var _ring_i: int = 0
var _ring_dir: int = 1
var _ring_pts: Array[Vector3] = []
var _train_ok: bool = true
var _train_check_t: float = 0.0
var _untrain_t: float = 0.0
## Fired when the bot wanted to sprint this frame (the bonus perk's "sprint" moment).
var sprinted_s: float = 0.0


func setup(p: Player, s: BotSquad) -> void:
	player = p
	squad = s
	var cfg: Dictionary = BotConfig.cfg()
	_follow = cfg.get("follow", {})
	_pcfg = GLData.table("player")
	_sk = BotConfig.skill(cfg, GameState.bot_skill)
	yaw = player.rotation.y
	_last_pos = player.global_position
	_progress_pos = player.global_position
	for n: Node in player.get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor:
			_doors.append(n as BuyDoor)
	for t: Node in player.get_tree().get_nodes_in_group(&"traps"):
		if t.has_method("danger_contains"):
			_traps.append(t)


# ================================================================== the API

func move_to(pos: Vector3, urgency: float = 0.3, stop_dist: float = 0.6) -> void:
	_mode = M.MOVE
	if _target == Vector3.INF or pos.distance_to(_target) > 0.3 or _target_snap == Vector3.INF:
		_target_snap = _snap(pos)
	_target = pos
	_urgency = urgency
	_stop_dist = stop_dist


func follow(leader: Player, slot_index: int) -> void:
	_mode = M.FOLLOW
	_leader = leader
	_slot = slot_index
	_urgency = 0.3


func hold(pos: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	_mode = M.HOLD
	if _target == Vector3.INF or pos.distance_to(_target) > 0.3 or _target_snap == Vector3.INF:
		_target_snap = _snap(pos)
	_target = pos
	_facing = facing
	_stop_dist = 0.7
	_urgency = 0.3


func stop() -> void:
	_mode = M.NONE
	_target = Vector3.INF


## Runs the training loop: `route` (a TrainingRoute; null = a free loop round the leader).
func train(route: Variant) -> void:
	if _mode != M.TRAIN or route != _route:
		_route = route
		_ring_pts.clear()
	_mode = M.TRAIN
	_urgency = 0.55


func train_ok() -> bool:
	return _train_ok


## Where the train's head is (the nearest known zombie on the loop behind the bot), flat.
func train_face_dir() -> Vector3:
	var me: Vector3 = player.global_position
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for e: Variant in squad.blackboard.known(squad.time()):
		var p: Vector3 = (e as Dictionary)["pos"]
		var d: float = _flat(p, me)
		if d < best_d:
			best_d = d
			best = p - me
	best.y = 0.0
	return best.normalized() if best.length() > 0.01 else -_heading()


func arrived() -> bool:
	if _mode == M.NONE:
		return true
	var want: Vector3 = _target_snap if _mode == M.MOVE or _mode == M.HOLD else _goal
	return want == Vector3.INF or (_flat(want, player.global_position) <= maxf(0.45, _stop_dist) and absf(want.y - player.global_position.y) < 1.8)


func is_stuck() -> bool:
	return _no_progress_t > 2.0


## Path length to `pos` on the navmesh, INF when it can't get there (only through a closed door).
## The v2 layer's "no way to the goal" queries (bot AI pass 2026-11): the v1 code never reports one.
func no_way() -> bool:
	return false


func no_way_s() -> float:
	return 0.0


func gave_up() -> bool:
	return false


func path_length_to(pos: Vector3) -> float:
	var dest: Vector3 = _snap(pos)
	if dest.distance_to(pos) > 2.5:
		return INF
	var path: PackedVector3Array = open_path(player.global_position, dest)
	if path.is_empty() or path[path.size() - 1].distance_to(dest) > 1.5:
		return INF
	var n: float = 0.0
	for i: int in range(1, path.size()):
		n += path[i - 1].distance_to(path[i])
	return n


func current_target() -> Vector3:
	return _goal


func debug_path() -> PackedVector3Array:
	if _path.is_empty():
		return PackedVector3Array()
	var out: PackedVector3Array = PackedVector3Array([player.global_position])
	for i: int in range(_path_i, _path.size()):
		out.append(_path[i])
	return out


func look_at_dir(dir: Vector3) -> void:
	_look = dir


func clear_look() -> void:
	_look = Vector3.ZERO


## The gun can fire: not sprinting.
func fire_ready() -> bool:
	return not player.sprinting


func sprint_out_left() -> float:
	return 0.0


## The 1.2 m bubble round a human (stretched 1.6x along where they are walking): the push direction x strength,
## zero outside it. Pure (the same rule the U03 locomotion layer exposes).
static func personal_space_push(me: Vector3, human: Vector3, human_vel: Vector3) -> Vector3:
	var off: Vector3 = me - human
	off.y = 0.0
	var hv: Vector3 = Vector3(human_vel.x, 0.0, human_vel.z)
	var r: float = 1.2
	if hv.length() > 0.5 and off.length() > 0.01 and hv.normalized().dot(off.normalized()) > 0.3:
		r *= 1.6   # in front of a walking human: a longer bubble
	var d: float = off.length()
	if d >= r:
		return Vector3.ZERO
	if d < 0.01:
		var side: Vector3 = Vector3(-hv.z, 0.0, hv.x) if hv.length() > 0.1 else Vector3.RIGHT
		return side.normalized()
	return off / d * (1.0 - d / r)


# ================================================================== per frame

func tick(delta: float) -> void:
	_repath_t -= delta
	if _mode != M.TRAIN:
		_untrain_t += delta
		if _untrain_t > 3.0:
			_train_ok = true   # a blocked loop is worth another look after a while
	else:
		_untrain_t = 0.0
	_aside_cd -= delta
	_watch_t -= delta
	if _watch_t <= 0.0:
		_watch_t = 0.2
		_watch_choke(0.2)
	match _mode:
		M.MOVE:
			_sprint = _urgency >= 0.7
			if _urgency < 0.9 and _make_way():
				pass
			elif arrived():
				_clear_goal()
			else:
				_set_goal(_target_snap, _urgency >= 0.6)
		M.FOLLOW:
			_tick_follow(delta)
		M.HOLD:
			_sprint = false
			if _make_way() or _off_the_line():
				pass
			elif _flat(_target_snap, player.global_position) > _stop_dist:
				_set_goal(_target_snap, false)
			else:
				_clear_goal()
		M.TRAIN:
			_tick_train(delta)
		_:
			_sprint = false
			if not _make_way():
				if _choke_kind != "" and _choke_t > 0.6:
					_leave_choke(squad.leader_for_player(player))
				elif _goal != Vector3.INF and _reached():
					_clear_goal()
				elif _goal == Vector3.INF:
					var l: Player = squad.leader_for_player(player)
					if l != null and l != player:
						_keep_out_of_the_way(l, delta)
					if _goal == Vector3.INF:
						_off_the_line()
	_move(delta)
	_turn(delta)
	_look = Vector3.ZERO   # a look lasts one frame: the aim layer asks again every frame it aims


func _tick_follow(delta: float) -> void:
	var leader: Player = _leader
	if leader == null or leader == player or not is_instance_valid(leader):
		_clear_goal()
		return
	var me: Vector3 = player.global_position
	var d_leader: float = _flat(leader.global_position, me)
	var slot: Vector3 = slot_point(leader)
	var d_slot: float = _flat(slot, me)
	var moving: bool = leader_moving(leader)
	var near: float = float(_follow.get("near_m", 2.5))
	if RoundManager.is_special_round and RoundManager.state == RoundManager.State.ROUND:
		near = minf(near, float(_follow.get("special_near_m", 2.0)))
	_sprint = d_leader > float(_follow.get("catchup_sprint_m", 11.0)) or d_slot > 6.0
	if _make_way():
		pass
	elif moving or d_slot > near + 1.0 or d_leader > float(_follow.get("far_m", 6.5)):
		_follow_to(slot)
	elif _goal != Vector3.INF and _reached():
		_clear_goal()
	if _goal == Vector3.INF:
		_keep_out_of_the_way(leader, delta)
		if _goal == Vector3.INF and _choke_kind != "" and _choke_t > 0.6:
			_leave_choke(leader)


## The free training loop: eight navmesh points on a ring round the leader (or where the loop started when the
## bot leads), run in one direction, reversing when the next stretch is blocked by known zombies; train_ok goes
## false when both ways are blocked.
func _tick_train(delta: float) -> void:
	var me: Vector3 = player.global_position
	var leader: Player = squad.leader_for_player(player)
	var center: Vector3 = leader.global_position if leader != null and leader != player and is_instance_valid(leader) else _ring_center
	if _route != null and _route is Object and (_route as Object).has_method("points"):
		var rp: Variant = (_route as Object).call("points")
		if rp is PackedVector3Array or rp is Array:
			if _ring_pts.is_empty():
				for v: Variant in rp:
					_ring_pts.append(_snap(v as Vector3))
				_ring_i = _closest_ring_i(me)
	if center == Vector3.INF or (_route == null and _ring_center != Vector3.INF and _flat(center, _ring_center) > 4.0 and leader != player):
		center = me if center == Vector3.INF else center
	if _route == null and (_ring_pts.is_empty() or _flat(center, _ring_center) > 4.0):
		_ring_center = center
		_build_ring(center)
	if _ring_pts.is_empty():
		_train_ok = false
		_clear_goal()
		return
	_train_check_t -= delta
	var nxt: Vector3 = _ring_pts[_ring_i]
	if _flat(nxt, me) < 1.4:
		_ring_i = posmod(_ring_i + _ring_dir, _ring_pts.size())
		nxt = _ring_pts[_ring_i]
	if _train_check_t <= 0.0:
		_train_check_t = 0.4
		var blocked: bool = _stretch_blocked(me, nxt)
		if blocked:
			var back: Vector3 = _ring_pts[posmod(_ring_i - 2 * _ring_dir, _ring_pts.size())]
			if _stretch_blocked(me, back):
				_train_ok = false
			else:
				_ring_dir = -_ring_dir
				_ring_i = posmod(_ring_i + 2 * _ring_dir, _ring_pts.size())
				nxt = _ring_pts[_ring_i]
				_train_ok = true
		else:
			_train_ok = true
	# run ahead of the train: sprint while its head is on our heels and nothing asks us to look elsewhere
	_sprint = false
	var me2: Vector3 = player.global_position
	for e: Variant in squad.blackboard.known(squad.time()):
		if _flat((e as Dictionary)["pos"], me2) < 3.5:
			_sprint = true
			break
	if _make_way():
		return
	_set_goal(nxt, true)


func _build_ring(center: Vector3) -> void:
	_ring_pts.clear()
	var r: float = 6.0
	for k: int in 8:
		var a: float = float(k) / 8.0 * TAU
		var want: Vector3 = center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var p: Vector3 = _snap(want)
		if p.distance_to(want) < 2.5 and absf(p.y - center.y) < 1.5 and squad.choke_at(p).is_empty():
			_ring_pts.append(p)
	if _ring_pts.size() < 4:
		_ring_pts.clear()
		for k2: int in 8:
			var a2: float = float(k2) / 8.0 * TAU
			var want2: Vector3 = center + Vector3(cos(a2) * 3.5, 0.0, sin(a2) * 3.5)
			var p2: Vector3 = _snap(want2)
			if p2.distance_to(want2) < 1.8 and absf(p2.y - center.y) < 1.5:
				_ring_pts.append(p2)
	_ring_i = _closest_ring_i(player.global_position)


func _closest_ring_i(p: Vector3) -> int:
	var best: int = 0
	var bd: float = INF
	for i: int in _ring_pts.size():
		var d: float = _flat(_ring_pts[i], p)
		if d < bd:
			bd = d
			best = i
	return best


func _stretch_blocked(a: Vector3, b: Vector3) -> bool:
	var n: int = 0
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	for e: Variant in squad.blackboard.known(squad.time()):
		var zp: Vector3 = (e as Dictionary)["pos"]
		var z2: Vector2 = Vector2(zp.x, zp.z)
		if Geometry2D.get_closest_point_to_segment(z2, a2, b2).distance_to(z2) < 1.6 and z2.distance_to(a2) > 1.0:
			n += 1
	return n >= 2


# ================================================================== the old movement (T-031, U02 section 5)

## The leader is on the move (training): faster than follow.moving_speed_mps.
func leader_moving(leader: Player) -> bool:
	if leader == null or leader == player or leader.downed:
		return false
	var v: Vector3 = squad.leader_vel if leader == squad.human() else Vector3(leader.velocity.x, 0.0, leader.velocity.z)
	return v.length() > float(_follow.get("moving_speed_mps", 1.6))


func _follow_to(p: Vector3) -> void:
	if _repath_t > 0.0 and _goal != Vector3.INF and _goal.distance_to(p) < 1.5 and not _path.is_empty() and _path_i < _path.size():
		return
	_set_goal(p, true)


## The formation slot on the navmesh (standing: round the leader's facing; moving: beside and a little ahead).
func slot_point(leader: Player) -> Vector3:
	var nav: RID = player.get_world_3d().navigation_map
	var cands: Array[Vector3] = []
	if leader_moving(leader):
		var v: Vector3 = squad.leader_vel if leader == squad.human() else Vector3(leader.velocity.x, 0.0, leader.velocity.z)
		var base: Vector3 = leader.global_position + v * float(_follow.get("lead_s", 0.6))
		var off: Vector3 = BotConfig.moving_slot_offset(_follow, _slot, v)
		var left: Vector3 = Vector3(v.z, 0.0, -v.x).normalized()
		var mirrored: Vector3 = off - left * 2.0 * off.dot(left)
		for cand: Vector3 in [off, off * 0.6, mirrored, mirrored * 0.6]:
			cands.append(base + cand)
	var off2: Vector3 = BotConfig.slot_offset(_follow, _slot)
	var mirrored2: Vector3 = Vector3(-off2.x, off2.y, off2.z)
	for cand2: Vector3 in [off2, off2 * 0.6, mirrored2, mirrored2 * 0.6, Vector3(0.0, 0.0, 1.5 + 0.8 * float(_slot))]:
		cands.append(leader.global_position + leader.global_basis * cand2)
	var fallback: Vector3 = Vector3.INF
	for want: Vector3 in cands:
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		if p.distance_to(want) < 1.0 and absf(p.y - leader.global_position.y) < 1.5 and not BotLocomotion.walled(player, leader.global_position, p):
			if squad.choke_at(p).is_empty() and not in_danger(p) and not squad.on_human_line(p, 1.1):
				return p
			if fallback == Vector3.INF:
				fallback = p
	if fallback != Vector3.INF:
		return fallback
	return NavigationServer3D.map_get_closest_point(nav, leader.global_position + leader.global_basis.z * 1.5)


func _make_way() -> bool:
	var h: Player = squad.human()
	if h == null or not is_instance_valid(h) or h.spectating or h.downed or _urgency >= 0.9:
		return false
	if _aside_cd > 0.0 and _goal != Vector3.INF:
		return true
	var me: Vector3 = player.global_position
	var parked: bool = player.horizontal_speed() < 0.6
	var in_choke: bool = (_choke_kind != "" or _narrow) and parked
	if not BotConfig.should_step_aside(me, h.global_position, h.velocity, in_choke, _follow):
		return false
	var dir: Vector3 = BotConfig.step_aside_dir(me, h.global_position, h.velocity)
	var step: float = float(_follow.get("step_aside_m", 1.8))
	var cands: Array[Vector3] = []
	if _choke_kind != "":
		cands.append_array(_choke_exits(h.global_position))
	cands.append(me + dir * step)
	cands.append(me + dir * step * 0.6)
	var hv: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
	if hv.length() > 0.5:
		cands.append(me + hv.normalized() * 3.0 + dir * 1.0)
	cands.append(me - dir * step)
	for c: Vector3 in cands:
		var p: Vector3 = _snap(c)
		if p.distance_to(c) > 1.0 or absf(p.y - me.y) > 1.5 or _flat(p, h.global_position) < 1.2:
			continue
		if not squad.choke_at(p).is_empty() or in_danger(p):
			continue
		_set_goal(p, true)
		_aside_cd = 0.9
		return true
	return false


func _leave_choke(leader: Player) -> void:
	var want: Vector3 = slot_point(leader) if leader != null and leader != player else player.global_position
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for c: Vector3 in _choke_exits(Vector3.INF):
		var p: Vector3 = _snap(c)
		if p.distance_to(c) > 1.0 or not squad.choke_at(p).is_empty() or in_danger(p):
			continue
		var d: float = _flat(p, want) + _flat(p, player.global_position) * 0.5
		if d < best_d:
			best_d = d
			best = p
	if best != Vector3.INF:
		_set_goal(best, true)
		_aside_cd = 0.9


func _choke_exits(avoid: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c: Dictionary = squad.choke_at(player.global_position)
	if c.is_empty():
		return out
	var box: AABB = c["box"]
	var me: Vector3 = player.global_position
	for cand: Vector3 in [Vector3(box.position.x - 0.7, me.y, me.z), Vector3(box.end.x + 0.7, me.y, me.z),
			Vector3(me.x, me.y, box.position.z - 0.7), Vector3(me.x, me.y, box.end.z + 0.7)]:
		out.append(cand)
	if avoid != Vector3.INF:
		out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a, avoid) > _flat(b, avoid))
	else:
		out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a, me) < _flat(b, me))
	return out


## Choke watch: which choke it stands in, a narrow passage with the human close, and the soak report.
func _watch_choke(dt: float) -> void:
	var me: Vector3 = player.global_position
	var c: Dictionary = squad.choke_at(me)
	_choke_kind = str(c.get("kind", "")) if not c.is_empty() else ""
	_narrow = false
	var h: Player = squad.human()
	if _choke_kind == "" and h != null and _flat(h.global_position, me) < float(_follow.get("choke_near_m", 4.0)) and player.horizontal_speed() < 0.6:
		_narrow = _narrow_here(h.global_position)
	if _choke_kind != "" and not exempt_choke:
		_choke_t += dt
		if _choke_t > float(_follow.get("choke_report_s", 3.0)) and not _choke_reported:
			_choke_reported = true
			choke_reports += 1
			squad.report_choke_for(player, _choke_kind, me, _choke_t, choke_tag)
	else:
		_choke_t = 0.0
		_choke_reported = false


## Set by the brain: true while reviving (a revive in a doorway is fine), and a label for choke reports.
var exempt_choke: bool = false
var choke_tag: String = ""


func _narrow_here(human_pos: Vector3) -> bool:
	var me: Vector3 = player.global_position
	var axis: Vector3 = me - human_pos
	axis.y = 0.0
	if axis.length() < 0.05:
		axis = -player.global_basis.z
	axis = axis.normalized()
	var side: Vector3 = Vector3(-axis.z, 0.0, axis.x)
	var from: Vector3 = me + Vector3.UP * 1.0
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var dists: Array[float] = []
	for sgn: float in [1.0, -1.0]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + side * sgn * 1.5, MASK_LOS, [player.get_rid()])
		var r: Dictionary = space.intersect_ray(q)
		dists.append(from.distance_to(r["position"]) if not r.is_empty() else 99.0)
	return BotConfig.is_narrow(dists[0], dists[1], float(_follow.get("narrow_half_width_m", 0.85)))


## A live trap or a blackboard danger zone covers `p`.
func in_danger(p: Vector3) -> bool:
	for t: Node in _traps:
		if is_instance_valid(t) and bool(t.call("danger_contains", p)):
			return true
	return squad.blackboard.danger_at(p, squad.time()) >= 1.0


func _escape_danger() -> void:
	var me: Vector3 = player.global_position
	for r: float in [2.5, 4.0, 6.0]:
		for k: int in 8:
			var a: float = float(k) / 8.0 * TAU
			var p: Vector3 = _snap(me + Vector3(cos(a) * r, 0.0, sin(a) * r))
			if absf(p.y - me.y) < 1.5 and not in_danger(p):
				_set_goal(p, true)
				return


## Standing on the human's walking line with the human coming (within 9 m): a step off it. True while moving off.
func _off_the_line() -> bool:
	var h: Player = squad.human()
	if h == null or not is_instance_valid(h) or h.spectating or player.horizontal_speed() > 0.8:
		return _aside_cd > 0.0 and _goal != Vector3.INF and h != null and is_instance_valid(h) and not h.spectating
	var me: Vector3 = player.global_position
	if _flat(h.global_position, me) > 9.0 or not squad.on_human_line(me, 1.1):
		return false
	if _aside_cd > 0.0 and _goal != Vector3.INF:
		return true
	for r: float in [1.6, 2.4, 3.2]:
		for k: int in 8:
			var a: float = float(k) / 8.0 * TAU
			var p: Vector3 = _snap(me + Vector3(cos(a) * r, 0.0, sin(a) * r))
			if absf(p.y - me.y) < 1.2 and not squad.on_human_line(p, 1.2) and squad.choke_at(p).is_empty() and not in_danger(p) and _flat(p, h.global_position) > 1.5:
				_set_goal(p, true)
				_aside_cd = 1.2
				return true
	return false


## Out of the leader's line of fire; never parked in a doorway.
func _keep_out_of_the_way(leader: Player, delta: float) -> void:
	var me: Vector3 = player.global_position
	var fwd: Vector3 = -leader.camera.global_basis.z if leader.camera != null else -leader.global_basis.z
	if leader.is_alive() and BotConfig.in_fire_cone(leader.global_position, fwd, me, float(_follow.get("line_of_fire_cone_deg", 20.0)), float(_follow.get("line_of_fire_range_m", 16.0))):
		_cone_t += delta
		if _cone_t > 0.35:
			var to_me: Vector3 = me - leader.global_position
			to_me.y = 0.0
			var side: Vector3 = Vector3(fwd.z, 0.0, -fwd.x).normalized()
			if side.dot(to_me) < 0.0:
				side = -side
			_set_goal(_snap(me + side * 1.8), true)
			_cone_t = 0.0
			return
	else:
		_cone_t = 0.0
	var keep: float = float(_follow.get("door_keepout_m", 1.3))
	for d: BuyDoor in _doors:
		if not is_instance_valid(d):
			continue
		var dd: float = _flat(d.global_position, me)
		if dd < keep and absf(d.global_position.y - me.y) < 2.0:
			var out: Vector3 = me - d.global_position
			out.y = 0.0
			if out.length() < 0.05:
				out = d.global_basis.z
			_set_goal(_snap(me + out.normalized() * (keep + 0.6)), true)
			return


# ---------------------------------------------------------------- paths

func _snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, p)


## A nav path that doesn't cross a closed BuyDoor (doors aren't baked into the navmesh).
func open_path(from: Vector3, dest: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = BotProf.nav_path(player.get_world_3d().navigation_map, from, dest, true, squad.nav_mask())
	for d: BuyDoor in _doors:
		if is_instance_valid(d) and not d.is_open and ZombieDirector.door_crossed(d, path):
			return PackedVector3Array()
	return path


func _set_goal(dest: Vector3, urgent: bool) -> void:
	if _goal != Vector3.INF and _goal.distance_to(dest) < 0.5 and _repath_t > 0.0 and not _path.is_empty():
		return
	if not urgent and _goal != Vector3.INF and _goal.distance_to(dest) < 0.75 and _repath_t > 0.0:
		return
	_goal = dest
	_path = open_path(player.global_position, dest)
	_path_i = 1 if _path.size() > 1 else 0
	_repath_t = float(_follow.get("repath_s", 0.6))


func _clear_goal() -> void:
	_goal = Vector3.INF
	_path = PackedVector3Array()
	_path_i = 0


func _reached() -> bool:
	return _goal == Vector3.INF or _flat(_goal, player.global_position) < 0.6 or _path_i >= _path.size()


func _heading() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _move(delta: float) -> void:
	var wish: Vector3 = Vector3.ZERO
	if in_danger(player.global_position):
		if _goal == Vector3.INF or in_danger(_goal) or _repath_t <= 0.0:
			_escape_danger()
	elif (_goal != Vector3.INF and in_danger(_goal)) or (_path_i < _path.size() and in_danger(_path[_path_i])):
		_clear_goal()   # wait outside until it is safe
	if _nudge_t > 0.0:
		_nudge_t -= delta
		wish = _nudge_dir
	elif not _path.is_empty() and _path_i < _path.size():
		var p: Vector3 = _path[_path_i]
		var flat: Vector3 = Vector3(p.x - player.global_position.x, 0.0, p.z - player.global_position.z)
		if flat.length() < 0.45:
			_path_i += 1
		else:
			wish = flat.normalized()
	var path_wish: Vector3 = wish
	# personal space: bots don't collide with each other or the human; they step apart on their own
	for p2: Player in squad.all_players():
		if p2 == player or p2.spectating or not is_instance_valid(p2):
			continue
		if p2.is_bot:
			var apart: Vector3 = player.global_position - p2.global_position
			apart.y = 0.0
			var ad: float = apart.length()
			if ad < 1.0 and ad > 0.01:
				wish += apart / ad * (1.0 - ad) * 1.5
			elif ad <= 0.01:
				wish += Vector3(cos(float(index) * 2.1), 0.0, sin(float(index) * 2.1))
		elif not p2.downed:
			wish += personal_space_push(player.global_position, p2.global_position, p2.velocity) * 2.6
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var speed: float = float(_pcfg["walk_speed"])
	var heading_ok: bool = _look == Vector3.ZERO or Vector3(_look.x, 0.0, _look.z).normalized().dot(wish.normalized()) > cos(deg_to_rad(70.0))
	if _urgency >= 0.95 and _mode == M.MOVE:
		heading_ok = true   # fleeing: run, and turn the body the way it runs (no shooting while sprinting)
		if _sprint and wish != Vector3.ZERO:
			_look = Vector3.ZERO
	var sprinting: bool = _sprint and wish != Vector3.ZERO and heading_ok
	if sprinting:
		speed = float(_pcfg["sprint_speed"])
	speed *= player.weapons.move_mult() * float(PerkManager.stat(player.player_id, "move_speed_mult", 1.0)) * player.status_move_mult()
	var on_floor: bool = player.is_on_floor()
	var horizontal: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal = horizontal.move_toward(wish * speed, (45.0 if on_floor else 8.0) * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.velocity.y = -0.5 if on_floor and player.velocity.y < 0.0 else player.velocity.y - GameState.g_player() * delta
	player.sprinting = sprinting
	_sprint_t = _sprint_t + delta if sprinting else 0.0
	sprinted_s = _sprint_t
	player.crouching = false
	player._set_crouch_shape(false)
	player.head.position.y = player._eye
	player.move_with_push()   # turbulence, suction, pulls (T-105): added for the move, taken out after it (T-185)
	_watch_stuck(delta, path_wish, on_floor)
	_last_pos = player.global_position
	if player.global_position.y < -20.0:
		_teleport_safe(true)


## Stuck: wants to move and isn't getting anywhere. 2 s without progress -> repath, 4 s -> a nudge (a short
## random walk), 8 s -> a teleport to a safe navmesh point, only when no human can see the bot.
func _watch_stuck(delta: float, wish: Vector3, on_floor: bool) -> void:
	if wish == Vector3.ZERO or _nudge_t > 0.0:
		if wish == Vector3.ZERO:
			_no_progress_t = 0.0
			_stuck_stage = 0
			_progress_pos = player.global_position
		return
	if player.global_position.distance_to(_last_pos) < 0.015:
		_stuck_frame_t += delta
		BotMetrics.note(player.player_id, &"stuck_time", delta)
		if _stuck_frame_t > 0.6 and on_floor:
			player.velocity.y = float(_pcfg["jump_velocity"]) * 0.8
			_stuck_frame_t = 0.0
	else:
		_stuck_frame_t = 0.0
	if player.global_position.distance_to(_progress_pos) > 0.8:
		_progress_pos = player.global_position
		_no_progress_t = 0.0
		_stuck_stage = 0
		return
	_no_progress_t += delta
	if _no_progress_t > 2.0 and _stuck_stage == 0:
		_stuck_stage = 1
		BotMetrics.note(player.player_id, &"stuck", 1.0, "repath")
		var g: Vector3 = _goal
		_clear_goal()
		_repath_t = 0.0
		if g != Vector3.INF:
			_set_goal(g, true)
	elif _no_progress_t > 4.0 and _stuck_stage == 1:
		_stuck_stage = 2
		BotMetrics.note(player.player_id, &"stuck", 1.0, "nudge")
		var a: float = randf() * TAU
		_nudge_dir = Vector3(cos(a), 0.0, sin(a))
		_nudge_t = 0.8
		_clear_goal()
	elif _no_progress_t > 8.0 and _stuck_stage == 2:
		_stuck_stage = 3
		if not _seen_by_human():
			_teleport_safe(false)
		_no_progress_t = 4.5   # try the nudge again before another teleport check


func _seen_by_human() -> bool:
	var h: Player = squad.human()
	if h == null or not is_instance_valid(h) or h.spectating or h.camera == null:
		return false
	var cam: Camera3D = h.camera
	var p: Vector3 = player.global_position + Vector3.UP * 1.0
	if cam.is_inside_tree() and not cam.is_position_in_frustum(p):
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, p, MASK_LOS, [h.get_rid(), player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## To the nearest navmesh point a little away from here (or behind the leader after a fall out of the world).
func _teleport_safe(fell: bool) -> void:
	var nav: RID = player.get_world_3d().navigation_map
	var me: Vector3 = player.global_position
	var target: Vector3 = Vector3.INF
	if fell:
		var l: Player = squad.leader_for_player(player)
		var base: Vector3 = l.global_position if l != null and l != player else me
		target = NavigationServer3D.map_get_closest_point(nav, base + Vector3.BACK * 1.5)
	else:
		for r: float in [1.5, 2.5, 3.5]:
			for k: int in 8:
				var a: float = float(k) / 8.0 * TAU
				var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, me + Vector3(cos(a) * r, 0.0, sin(a) * r))
				if absf(p.y - me.y) < 1.2 and p.distance_to(me) > 1.0 and not in_danger(p) and squad.choke_at(p).is_empty():
					target = p
					break
			if target != Vector3.INF:
				break
	if target == Vector3.INF:
		return
	player.global_position = target + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	_clear_goal()
	teleports += 1
	BotMetrics.note(player.player_id, &"teleport", 1.0, "fell" if fell else "stuck 8s")


# ---------------------------------------------------------------- facing

func _turn(delta: float) -> void:
	var rate: float = float(_sk.get("turn_rate", 6.0))
	var want: Vector3 = _look
	if want == Vector3.ZERO:
		var v: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
		if _mode == M.HOLD and _facing != Vector3.ZERO and v.length() < 0.5:
			want = _facing
		elif v.length() > 0.8:
			want = v
		rate *= 0.6
	if want == Vector3.ZERO:
		pitch = move_toward(pitch, 0.0, rate * 0.3 * delta)
	else:
		want = want.normalized()
		var want_yaw: float = atan2(-want.x, -want.z)
		var want_pitch: float = asin(clampf(want.y, -1.0, 1.0)) if _look != Vector3.ZERO else 0.0
		var step: float = rate * delta
		var dy: float = wrapf(want_yaw - yaw, -PI, PI)
		yaw = wrapf(yaw + clampf(dy, -step, step), -PI, PI)
		pitch = clampf(pitch + clampf(want_pitch - pitch, -step, step), deg_to_rad(-80.0), deg_to_rad(80.0))
	player.rotation.y = yaw
	player.head.rotation.x = pitch


## The direction the body (the eye) looks along now.
func facing() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
