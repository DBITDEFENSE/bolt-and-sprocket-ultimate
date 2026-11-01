class_name SoldierBrain
extends RefCounted
## T-142 (UPDATE 09 section 4, contract C5): a relief-squad soldier's brain, the squad bots' utility brain cut down to
## what a soldier passing through needs. No economy, no eggs, no commands, no perks, no mark orders.
##   - Modes (decide(), pure): leave (the squad is pulling out) > retreat (under retreat_hp_frac of its health) >
##     revive (a downed squad mate near, this soldier's one revive unused, little threat) > fight (a target) > follow.
##   - Follow: hold a point in a fan on the leader's side of the nearest player, between hold_m[0] and hold_m[1]
##     (6-12 m: close enough to help, out of the players' way). Fighting keeps that position and shoots from it.
##   - Targets: BotPerception's threat score (combat.json threat) on the zombies it can see (a line of sight from
##     the eye; the nearest few per think), plus a small far term out to the weapon class's max range.
##   - Aim (BotAim's rules with skills.json "recruit", times the kit's aim_mult): a reaction delay on a new target, an
##     error that settles from aim_error_deg to settle_error_deg over track_tau_s, fire only within fire_tolerance of
##     the body; autos fire in bursts beyond burst_range_m; a magazine and a reload (weapons.json mag / reload_empty).
##   - Damage: weapons.json damage x squads.json damage_mult x limb_mult; through Zombie.take_damage with by_player 0
##     (no Scrip of its own: ReliefSquad pays the nearest player scrip_share of the kill).
## Thinks at think_hz (staggered per soldier); moves and aims every physics frame. `us_last` is this brain's cost in
## the last frame (microseconds; the smoke's performance check sums them).

const MASK_SHOT: int = 1 | (1 << 3) | (1 << 8)   # world | zombie hitbox | door (WeaponHolder.MASK_SHOT)
const MASK_LOS: int = 1 | (1 << 8)
const EYE: float = 1.55
const LOS_CANDIDATES: int = 3

var soldier: Soldier
var cfg: Dictionary = {}       # squads.json global
var tcfg: Dictionary = {}      # combat.json threat
var acfg: Dictionary = {}      # combat.json aim
var skill: Dictionary = {}     # skills.json recruit
var mode: StringName = &"follow"
var target: Zombie = null
var target_visible: bool = false
var goal: Vector3 = Vector3.INF
var revive_mate: Soldier = null
var shots: int = 0
var hits: int = 0
var kills: int = 0
var us_last: int = 0

var _think_t: float = 0.0
var _path: PackedVector3Array = []
var _path_i: int = 0
var _repath_t: float = 0.0
var _path_goal: Vector3 = Vector3.INF
var _on_target_t: float = 0.0
var _react_t: float = 0.0
var _shot_cd: float = 0.0
var _burst_t: float = 0.0
var _pause_t: float = 0.0
var _mag: int = 0
var _reload_t: float = 0.0
var _revive_t: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(s: Soldier) -> void:
	soldier = s
	cfg = ReliefSquad.cfg()
	var combat: Dictionary = GLData.load_json("res://data/gravelight/ai/combat.json")
	tcfg = combat.get("threat", {})
	acfg = combat.get("aim", {})
	skill = (GLData.load_json("res://data/gravelight/ai/skills.json").get("recruit", {}) as Dictionary)
	_rng.seed = hash(s.tag) + s.idx
	_think_t = _rng.randf_range(0.0, 1.0 / maxf(1.0, float(cfg.get("think_hz", 6.0))))
	_mag = soldier.mag_size()


# ================================================================== pure decisions (test_soldier_brain.gd)

## The mode for this moment. s: {leaving, hp_frac, retreat_frac, mate_down_d (INF: none), revives_left,
## threat_near (zombies within 6 m), has_target}.
static func decide(s: Dictionary) -> StringName:
	if bool(s.get("leaving", false)):
		return &"leave"
	if float(s.get("hp_frac", 1.0)) < float(s.get("retreat_frac", 0.3)):
		return &"retreat"
	if can_revive(float(s.get("mate_down_d", INF)), int(s.get("revives_left", 0)), int(s.get("threat_near", 0))):
		return &"revive"
	if bool(s.get("has_target", false)):
		return &"fight"
	return &"follow"


## A downed mate is worth the one revive: near enough (20 m), not used yet, fewer than 3 zombies within 6 m.
static func can_revive(mate_d: float, revives_left: int, threat_near: int) -> bool:
	return revives_left > 0 and mate_d < 20.0 and threat_near < 3


## The point a soldier holds: in a fan on the side of `from` (the leader / where the squad came from) around
## `anchor` (the nearest player), between hold_min and hold_max metres from it. Deterministic per index.
static func hold_point(anchor: Vector3, from: Vector3, idx: int, n: int, hold_min: float, hold_max: float) -> Vector3:
	var d: Vector3 = from - anchor
	d.y = 0.0
	if d.length() < 0.1:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	var spread: float = deg_to_rad(110.0)
	var ang: float = 0.0 if n <= 1 else (float(idx) / float(n - 1) - 0.5) * spread
	var k: float = 0.5 + 0.5 * sin(float(idx) * 1.7 + 0.4)
	var r: float = lerpf(hold_min, hold_max, k)
	return anchor + d.rotated(Vector3.UP, ang) * r


## Whether a flat distance to the anchor sits in the hold band (no need to move).
static func in_hold_band(d: float, hold_min: float, hold_max: float) -> bool:
	return d >= hold_min - 0.5 and d <= hold_max + 0.5


## A retreat point: 6 m away from the threats' centre, pulled toward the safe anchor (the nearest player).
static func retreat_point(me: Vector3, threat_c: Vector3, anchor: Vector3) -> Vector3:
	var away: Vector3 = me - threat_c
	away.y = 0.0
	if away.length() < 0.1:
		away = me - anchor
		away.y = 0.0
	var to_a: Vector3 = anchor - me
	to_a.y = 0.0
	var dir: Vector3 = (away.normalized() * 0.65 + (to_a.normalized() if to_a.length() > 0.1 else Vector3.ZERO) * 0.35)
	if dir.length() < 0.05:
		dir = Vector3(0, 0, 1)
	return me + dir.normalized() * 6.0


## Target score: BotPerception's threat (0 beyond threat range_m) plus a far term out to `max_range` so a soldier
## also shoots what is coming; going for this soldier (prey) counts like targeting a downed teammate.
static func target_score(d: float, tier: StringName, crawler: bool, type_mult: float, on_me: bool, max_range: float, t: Dictionary) -> float:
	if d > max_range:
		return 0.0
	var s: float = BotPerception.threat_score(d, tier, crawler, type_mult, on_me, false, false, false, t)
	return s + 0.08 * (1.0 - d / maxf(1.0, max_range))


## The index of the best visible row ({score, visible}); -1 when none scores.
static func pick_target(rows: Array) -> int:
	var best: int = -1
	var bs: float = 0.0
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if not bool(r.get("visible", false)):
			continue
		var s: float = float(r.get("score", 0.0))
		if s > bs:
			bs = s
			best = i
	return best


## BotAim's tracking error after `t_on` seconds on a steady target (degrees), scaled down by a better aim.
static func aim_error_deg(t_on: float, err0: float, err1: float, tau: float, aim_mult: float) -> float:
	var e: float = err1 + (err0 - err1) * exp(-maxf(0.0, t_on) / maxf(0.05, tau))
	return e / maxf(0.2, aim_mult)


## Seconds between shots for a weapon's rpm (capped: a soldier's gun is not the holder's, it need not sound like it).
static func shot_interval(rpm: float, cap_rpm: float = 720.0) -> float:
	return 60.0 / clampf(rpm, 20.0, cap_rpm)


# ================================================================== the tick

func tick(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_tick_timers(delta)
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 1.0 / maxf(1.0, float(cfg.get("think_hz", 6.0)))
		_think()
	_move(delta)
	_aim_and_fire(delta)
	us_last = Time.get_ticks_usec() - t0


func _tick_timers(delta: float) -> void:
	_shot_cd = maxf(0.0, _shot_cd - delta)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_mag = soldier.mag_size()
	if target != null and target_visible:
		_on_target_t += delta
	_react_t = maxf(0.0, _react_t - delta)


func _think() -> void:
	var sq: ReliefSquad = soldier.squad
	if sq == null:
		return
	_pick_target(sq)
	var mate: Soldier = sq.downed_mate_near(soldier)
	var mate_d: float = soldier.global_position.distance_to(mate.global_position) if mate != null else INF
	var near: int = sq.zombies_near(soldier.global_position, 6.0)
	mode = decide({"leaving": soldier.leaving, "hp_frac": soldier.hp / maxf(1.0, soldier.max_hp),
		"retreat_frac": float(cfg.get("retreat_hp_frac", 0.3)), "mate_down_d": mate_d, "revives_left": soldier.revives_left,
		"threat_near": near, "has_target": target != null})
	revive_mate = mate if mode == &"revive" else null
	if mode != &"revive":
		_revive_t = 0.0
	match mode:
		&"leave":
			goal = sq.exit_point
		&"retreat":
			goal = retreat_point(soldier.global_position, sq.threat_centre(soldier.global_position, 10.0), sq.anchor_for(soldier))
		&"revive":
			goal = mate.global_position
		_:
			var hm: Array = cfg.get("hold_m", [6.0, 12.0])
			var anchor: Vector3 = sq.anchor_for(soldier)
			var lead: Soldier = sq.leader()
			var from: Vector3 = lead.global_position if lead != null and lead != soldier else sq.entry_point
			var want: Vector3 = hold_point(anchor, from, soldier.idx, sq.size(), float(hm[0]), float(hm[1]))
			var d: float = ReliefSquad.flat(soldier.global_position, anchor)
			if goal == Vector3.INF or not in_hold_band(d, float(hm[0]), float(hm[1])) or goal.distance_to(want) > 4.0:
				goal = want


func _pick_target(sq: ReliefSquad) -> void:
	var me: Vector3 = soldier.global_position
	var mr: float = soldier.max_range()
	var rows: Array = []
	var nodes: Array[Zombie] = []
	for z: Zombie in sq.zombie_cache:
		if not BotPerception.targetable(z):
			continue
		var d: float = ReliefSquad.flat(me, z.global_position)
		if d > mr:
			continue
		var on_me: bool = z.prey == soldier
		var tm: float = float(BotAIData.counter(z.enemy_id).get("threat_mult", 1.0))
		rows.append({"score": target_score(d, z.tier, z.is_crawler, tm, on_me, mr, tcfg), "visible": false, "d": d})
		nodes.append(z)
	# line of sight for the best few only (the cost stays flat however many zombies there are)
	var order: Array = range(rows.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(rows[a]["score"]) > float(rows[b]["score"]))
	var rays: int = 0
	for i: int in order:
		if rays >= LOS_CANDIDATES:
			break
		if float(rows[i]["score"]) <= 0.0:
			break
		rays += 1
		rows[i]["visible"] = _los(nodes[i])
	var pick: int = pick_target(rows)
	var nt: Zombie = nodes[pick] if pick >= 0 else null
	if nt != target:
		var flick: bool = target != null and nt != null and _angle_to(nt.global_position) < float(acfg.get("quick_switch_deg", 20.0))
		_react_t = float(acfg.get("quick_switch_s", 0.06)) if flick else _rng.randf_range(float((skill.get("reaction_s", [0.27, 0.33]) as Array)[0]), float((skill.get("reaction_s", [0.27, 0.33]) as Array)[1]))
		_on_target_t = 0.0
	target = nt
	target_visible = nt != null


func _los(z: Zombie) -> bool:
	var space: PhysicsDirectSpaceState3D = soldier.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_eye(), z.global_position + Vector3.UP * 1.2, MASK_LOS, [soldier.get_rid()])
	return space.intersect_ray(q).is_empty()


func _eye() -> Vector3:
	return soldier.global_position + Vector3.UP * EYE * soldier.height_k()


func _angle_to(p: Vector3) -> float:
	var f: Vector3 = -soldier.global_basis.z
	var d: Vector3 = p - soldier.global_position
	d.y = 0.0
	f.y = 0.0
	if d.length() < 0.05 or f.length() < 0.05:
		return 0.0
	return rad_to_deg(f.angle_to(d))


# ================================================================== moving

func _move(delta: float) -> void:
	var v: Vector3 = Vector3.ZERO
	var running: bool = false
	if mode == &"revive" and revive_mate != null and is_instance_valid(revive_mate):
		if soldier.global_position.distance_to(revive_mate.global_position) < 1.4:
			_revive(delta)
			soldier.set_move(Vector3.ZERO, false)
			return
	if goal != Vector3.INF:
		var to_goal: Vector3 = goal - soldier.global_position
		to_goal.y = 0.0
		var arrive: float = 0.8 if mode != &"leave" else 1.5
		if to_goal.length() > arrive:
			var nxt: Vector3 = _next_corner(delta)
			var dir: Vector3 = nxt - soldier.global_position
			dir.y = 0.0
			if dir.length() > 0.05:
				running = to_goal.length() > 8.0 or mode == &"retreat" or mode == &"leave"
				var sp: float = float(cfg.get("run_speed", 5.2)) if running else float(cfg.get("walk_speed", 3.4))
				v = dir.normalized() * sp * soldier.speed_mult
	soldier.set_move(v, running)
	_check_stuck(delta, v)


func _next_corner(delta: float) -> Vector3:
	_repath_t -= delta
	if _repath_t <= 0.0 or _path.is_empty() or _path_goal.distance_to(goal) > 2.0:
		_repath_t = float(cfg.get("repath_s", 0.8)) * _rng.randf_range(0.85, 1.15)
		_path_goal = goal
		var w: World3D = soldier.get_world_3d()
		var mask: int = soldier.squad.nav_mask() if soldier.squad != null else 0xFFFFFFFF
		_path = NavigationServer3D.map_get_path(w.navigation_map, soldier.global_position, goal, true, mask)
		_path_i = 0
	while _path_i < _path.size() and ReliefSquad.flat(_path[_path_i], soldier.global_position) < 0.45:
		_path_i += 1
	if _path_i >= _path.size():
		return goal
	return _path[_path_i]


func _check_stuck(delta: float, v: Vector3) -> void:
	if v.length() < 0.1:
		_stuck_t = 0.0
		_last_pos = soldier.global_position
		return
	if _last_pos == Vector3.INF or soldier.global_position.distance_to(_last_pos) > 0.6:
		_last_pos = soldier.global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t > 2.5:
		_stuck_t = 0.0
		_repath_t = 0.0
		goal = soldier.global_position + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))   # unstick: a step aside


func _revive(delta: float) -> void:
	_revive_t += delta
	soldier.kneel_revive()
	if _revive_t >= float(cfg.get("revive_seconds", 3.0)):
		_revive_t = 0.0
		if revive_mate.revive():
			soldier.revives_left -= 1
			soldier.squad.on_revived(soldier, revive_mate)
		revive_mate = null
		mode = &"follow"


# ================================================================== aim and fire

func _aim_and_fire(delta: float) -> void:
	var face_to: Vector3 = Vector3.INF
	if target != null and BotPerception.targetable(target):
		face_to = target.global_position
	elif soldier.velocity.length() > 0.3:
		face_to = soldier.global_position + soldier.velocity
	if face_to != Vector3.INF:
		soldier.turn_toward(face_to, delta)
	if target == null or not target_visible or not BotPerception.targetable(target) or mode == &"revive":
		return
	if _react_t > 0.0 or _reload_t > 0.0 or _shot_cd > 0.0:
		return
	if _mag <= 0:
		_reload_t = soldier.reload_seconds()
		return
	var d: float = soldier.global_position.distance_to(target.global_position)
	var tol: float = maxf(float(skill.get("fire_tolerance_deg", 3.5)), rad_to_deg(atan2(float(acfg.get("body_half_width_m", 0.22)), maxf(0.5, d))))
	if _angle_to(target.global_position) > tol * 2.5:
		return   # still turning onto it
	# bursts beyond burst range for automatic weapons (BotAim's fire discipline)
	if soldier.is_auto() and d > float(acfg.get("burst_range_m", 9.0)):
		if _pause_t > 0.0:
			_pause_t -= delta
			return
		_burst_t += soldier.shot_interval()
		var bs: Array = acfg.get("burst_s", [0.3, 0.6])
		if _burst_t > float(bs[1]):
			_burst_t = 0.0
			var ps: Array = acfg.get("pause_s", [0.18, 0.35])
			_pause_t = _rng.randf_range(float(ps[0]), float(ps[1]))
	_fire(d)


func _fire(d: float) -> void:
	_shot_cd = soldier.shot_interval()
	_mag -= 1
	shots += 1
	var err: float = aim_error_deg(_on_target_t, float(skill.get("aim_error_deg", 6.0)), float(skill.get("settle_error_deg", 1.3)),
		float(skill.get("track_tau_s", 0.5)), soldier.aim_mult)
	var head: bool = _rng.randf() < float((acfg.get("base_head", {}) as Dictionary).get(soldier.weapon_class(), 0.5)) * float(skill.get("head_aim_mult", 0.6))
	var aim_p: Vector3 = target.global_position + Vector3.UP * ((1.62 if head else 1.15) if not target.is_crawler else 0.5)
	var from: Vector3 = _eye()
	var base_dir: Vector3 = (aim_p - from).normalized()
	var end: Vector3 = from + base_dir * d
	for p: int in maxi(1, soldier.pellets()):
		var spread: float = deg_to_rad(err + (4.0 if soldier.pellets() > 1 else 0.0))
		var dir: Vector3 = base_dir.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
		var side: Vector3 = dir.cross(Vector3.UP)
		if side.length() > 0.01:
			dir = dir.rotated(side.normalized(), _rng.randf_range(-spread, spread) * 0.7)
		end = _trace(from, dir.normalized())
	soldier.on_fired(from, end)


func _trace(from: Vector3, dir: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = soldier.get_world_3d().direct_space_state
	var to: Vector3 = from + dir * soldier.max_range() * 1.2
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_SHOT, [soldier.get_rid()])
	q.collide_with_areas = true
	var res: Dictionary = space.intersect_ray(q)
	if res.is_empty():
		return to
	var pos: Vector3 = res["position"]
	var hb: Hitbox = res["collider"] as Hitbox
	if hb == null:
		return pos
	var z: Zombie = hb.enemy as Zombie
	if z == null or not z.is_active():
		return pos
	hits += 1
	var wl: StringName = z.marke_host_limb() if hb.limb == &"marke" else hb.limb
	var lm: Dictionary = cfg.get("limb_mult", {})
	var dmg: float = soldier.weapon_damage() * float(cfg.get("damage_mult", 0.55)) * float(lm.get(String(wl), 1.0))
	z.last_hit_bone = hb.bone
	if ZombieGore.blood_allowed():
		Effects.blood(pos, -dir)
	if z.take_damage(dmg, hb.limb, soldier.weapon_id, 0, &"bullet"):
		kills += 1
		if soldier.squad != null:
			soldier.squad.on_soldier_kill(soldier, z, wl)
	return pos
