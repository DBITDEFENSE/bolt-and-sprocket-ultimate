class_name BotTrainer
extends RefCounted
## Training the horde (T-071, player bot mode): how the agent playing the local human's survivor trains a round's
## zombies round one of the map's TrainingRoutes (data/gravelight/ai/routes_<map>.json), the way a skilled zombies
## player does. The utility action "lead_train" runs it (BotActions.run); its score input is value(). Tuning:
## data/gravelight/ai/player_bot.json "trainer".
##
## The picture (think_hz): every known zombie (BotPerception: sight cone, hearing, the squad blackboard; nothing
## through walls) is placed on the loop. Unseen ones are dead-reckoned toward the agent at their speed (the train
## follows; a person knows that). Each is a follower (behind on the loop within follow_m, or within close_m), a
## cutter (ahead on the loop within ahead_m, on the ring) or off the loop. The train's head is the nearest follower.
##
## The phases:
##   TRAVEL  off the loop: go to it (shooting on the way while nothing is close)
##   RUN     facing the way round the loop: walk, sprint when the head is inside the gap (gap_for: more room for
##           faster zombies), reload on the move when the gap allows; it sees what is ahead
##   FACE    turned on the train: fire into it while backing round the loop at a walk, or stand and let a far train
##           bunch; only when safe_to_turn (the head beyond the gap, the stretch ahead clear, the train bunched or
##           stalled); at most face_max_s, then a glance forward (it can't see ahead while it looks back)
##   CUT     a zombie on the loop ahead: shoot it when the train is far enough behind, pass it on the ring's far side
##           when there is room, reverse round the loop when the other way is clear, else fight it out
## The last zombies of a round are killed (no crawler is kept alive: the code has no such pattern), and a stalled
## round sends it after the squad's hunt point.
## Measured by the soak (tools_src/ai_soak.gd --scenario=botmode): stats() below.

enum Phase { IDLE, TRAVEL, RUN, FACE, CUT }
const PHASE_NAMES: PackedStringArray = ["idle", "travel", "run", "face", "cut"]

var brain: BotBrain
var player: Player
var c: Dictionary = {}
var route: TrainingRoute = null
var param: float = 0.0
var dir: int = 1
var phase: Phase = Phase.IDLE
var phase_t: float = 0.0
var lateral: float = 0.0

# the picture (refreshed at think_hz while running)
var followers: int = 0
var head: Zombie = null
var head_d: float = INF
var head_speed: float = 0.0
var head_reach: float = 1.5
var spread_m: float = 0.0
var bunched: float = 1.0
var ahead: Zombie = null
var ahead_d: float = INF
var ahead_lat: float = 0.0
var ahead_n: int = 0
var behind_clear_m: float = INF
## Cutters within cut_m on each side of the line: x = left, y = right of the travel direction.
var ahead_sides: Vector2i = Vector2i.ZERO

## Soak numbers (stats()).
var stats: Dictionary = {}
## Every hit taken: "r<round> <action>/<phase> f<followers> h<head m> a<cutter m> n<nearest m> <tier> hp<left>" (soak).
var hit_log: PackedStringArray = PackedStringArray()
## The soak's --trace: each hit also lists the zombies within 9 m (? = not known to the agent).
var verbose_hits: bool = false

var _think_t: float = 0.0
var _loop_t: float = -1.0
var _rev_cd: float = 0.0
var _was_cut: bool = false
var _windows: Dictionary = {}   # route id -> windows (barricades) near its line
var _routes: Array[TrainingRoute] = []
var _active: bool = false
var _active_t: float = -10.0
var _passing: bool = false
var _esc_p: Vector3 = Vector3.INF
var _esc_t: float = 0.0
var _cut_mode: String = ""
## A purchase on the way (a wall gun, its ammo, an ammo box within shop_near_m of the agent while the train is far
## enough back): the economy's own candidate, done through BotTasks without leaving the loop for long.
var _shop: Dictionary = {}
## The known zombies on this floor as [position (dead-reckoned when unseen), speed, reach], for the kite.
var _threats: Array = []
var _kite_dir: Vector3 = Vector3.ZERO
var _kite_t: float = 0.0
var _kite_score: float = 0.0
var _against_t: float = 0.0
var _cut_until: float = 0.0
var _pass_off: float = 0.0
## Zombies at windows ahead on the loop (outside, tearing or about to climb in): the nearest one's loop distance.
var window_ahead_m: float = INF


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player
	c = (BotAIData.table("player_bot").get("trainer", {}) as Dictionary)
	reset_stats()
	GLBus.player_damaged.connect(_on_damaged)
	GLBus.enemy_killed.connect(_on_killed)


func reset_stats() -> void:
	stats = {"time_s": 0.0, "training_s": 0.0, "run_s": 0.0, "face_s": 0.0, "cut_s": 0.0, "travel_s": 0.0,
		"samples": 0, "follow_sum": 0.0, "spread_sum": 0.0, "bunched_sum": 0.0, "train_max": 0, "big_samples": 0,
		"cut_ins": 0, "hits": 0, "hits_training": 0, "damage_training": 0.0, "kills": 0, "kills_training": 0,
		"reversals": 0, "passes": 0, "cutter_shots": 0, "escapes": 0, "loop_changes": 0, "stuck_s": 0.0, "turns": 0, "loops": PackedStringArray()}


func _f(key: String, dflt: float) -> float:
	return float(c.get(key, dflt))


# ================================================================== pure rules (unit-tested)

## The gap to keep to the train's head (m): its reach (a swing, plus a lunge) + a margin, and more room for faster
## zombies.
static func gap_for(speed: float, cfg: Dictionary, reach_m: float = 1.5) -> float:
	return reach_m + float(cfg.get("gap_margin_m", 0.8)) + maxf(0.0, speed) * float(cfg.get("gap_per_speed_s", 0.38))


## Where a known zombie is relative to the agent on the loop: "ahead" (on the ring in front, within ahead_m),
## "behind" (following on the loop within follow_m), "close" (within close_m wherever it is) or "off".
## `along_fwd` = loop distance from the agent to it in the direction of travel (0..length).
static func classify(along_fwd: float, loop_len: float, lateral_m: float, flat_d: float, ring_width: float, cfg: Dictionary, in_front: bool = false) -> String:
	var half: float = loop_len * 0.5
	var on_ring: bool = lateral_m <= ring_width * 0.5 + float(cfg.get("lateral_slack_m", 2.5))
	var close: bool = flat_d <= float(cfg.get("close_m", 3.5))
	if not on_ring:
		if close and in_front:
			return "ahead"   # off the line but close in front of us (cutting across the ring): in the way
		return "close" if close else "off"
	if along_fwd <= half and along_fwd <= float(cfg.get("ahead_m", 10.0)) and lateral_m <= ring_width * 0.5 + float(cfg.get("ahead_lateral_m", 1.3)):
		return "ahead"
	if along_fwd > half and loop_len - along_fwd <= float(cfg.get("follow_m", 13.0)):
		return "behind"
	if close and in_front:
		return "ahead"
	return "close" if close else "off"


## The train's shape from the followers' positions: n, spread (mean distance to their centroid, m), bunched (the
## share within bunch_m of the centroid) and the centroid.
static func train_stats(pts: Array, bunch_m: float) -> Dictionary:
	var n: int = pts.size()
	if n == 0:
		return {"n": 0, "spread": 0.0, "bunched": 1.0, "centroid": Vector3.INF}
	var cen: Vector3 = Vector3.ZERO
	for p: Variant in pts:
		cen += p as Vector3
	cen /= float(n)
	var s: float = 0.0
	var inside: int = 0
	for p2: Variant in pts:
		var d: float = Vector2((p2 as Vector3).x - cen.x, (p2 as Vector3).z - cen.z).length()
		s += d
		if d <= bunch_m:
			inside += 1
	return {"n": n, "spread": s / float(n), "bunched": float(inside) / float(n), "centroid": cen}


## May it turn round and fire into the train now? The head beyond the gap + turn_extra_m, the next ahead_need_m
## of the loop clear, a round in the magazine, and the train bunched (or stalled far back, or just a few).
static func safe_to_turn(head_dist: float, gap: float, ahead_clear: float, bunched_share: float, n_followers: int, mag: int, cfg: Dictionary) -> bool:
	if mag <= 0:
		return false
	if head_dist < gap + float(cfg.get("turn_extra_m", 1.6)):
		return false
	if ahead_clear < float(cfg.get("ahead_need_m", 6.0)):
		return false
	var stalled: bool = head_dist >= gap + float(cfg.get("turn_extra_m", 1.6)) + float(cfg.get("hold_extra_m", 4.0))
	if n_followers >= 3 and bunched_share < float(cfg.get("bunch_need", 0.5)) and not stalled:
		return false
	return true


## The loop to train on: each candidate {id, length, ring_width, travel_m, windows, home, current} scores
## width x w.width + clamped length / 10 x w.length - travel / 10 x w.travel - windows x w.windows + home x w.home
## + the route's agent_bonus (+ w.stick for the one in use). Returns the best index (-1 when empty).
static func choose_loop(cands: Array, w: Dictionary) -> int:
	var best: int = -1
	var best_s: float = -INF
	for i: int in cands.size():
		var r: Dictionary = cands[i]
		var s: float = loop_score(r, w)
		if s > best_s:
			best_s = s
			best = i
	return best


static func loop_score(r: Dictionary, w: Dictionary) -> float:
	var length: float = clampf(float(r.get("length", 0.0)), float(w.get("min_len_m", 20.0)), float(w.get("max_len_m", 90.0)))
	var s: float = minf(float(r.get("ring_width", 3.0)), 5.0) * float(w.get("width", 1.2))
	s += length / 10.0 * float(w.get("length", 0.6))
	s -= float(r.get("travel_m", 0.0)) / 10.0 * float(w.get("travel", 1.5))
	s -= float(r.get("windows", 0)) * float(w.get("windows", 0.9))
	s += float(r.get("home", 0.0)) * float(w.get("home", 0.8))
	s += float(r.get("bonus", 0.0))
	if bool(r.get("current", false)):
		s += float(w.get("stick", 2.5))
	if float(r.get("length", 0.0)) < float(w.get("min_len_m", 20.0)):
		s -= 10.0   # too small to train on at all
	return s


## A remembered (unseen) zombie's likely position now: moved toward the agent at its speed for the time since it
## was last perceived (capped), never past 1 m of the agent.
static func dead_reckon(last_pos: Vector3, me: Vector3, speed: float, age_s: float, cap_s: float) -> Vector3:
	var to: Vector3 = Vector3(me.x - last_pos.x, 0.0, me.z - last_pos.z)
	var d: float = to.length()
	if d < 1.0 or age_s <= 0.0:
		return last_pos
	var step: float = minf(maxf(0.0, speed) * minf(age_s, cap_s), d - 1.0)
	return last_pos + to / d * step


# ================================================================== the utility input

## lead_train's input: 0 when it can't train (no gun, no round, no loop, a special round on "fight"), 1 with
## zombies about, calm_value when nothing is near (the shopping and repairs may win then).
func value() -> float:
	if not brain.armed() or RoundManager.state != RoundManager.State.ROUND:
		return 0.0
	if RoundManager.is_special_round and str(c.get("special_round", "hold")) == "fight":
		return 0.0
	var now: float = brain.squad.time()
	if now >= _loop_t or (route == null and _routes.is_empty()):
		_refresh_routes(now)
	if _routes.is_empty():
		return 0.0
	var per: BotPerception = brain.perception
	var dirn: ZombieDirector = brain.squad.director()
	if per.known.is_empty() and RoundManager.to_spawn <= 0 and (dirn == null or dirn.active_zombies().is_empty()):
		return 0.0
	# a horde to train: train_min zombies chasing within horde_m (fewer are shot where they stand: the fight action,
	# measured better than kiting a handful); once training, it keeps on while train_keep still follow
	var chasing: int = 0
	for e: Variant in per.known:
		var z: Zombie = (e as Dictionary).get("node") as Zombie
		if z == null or not is_instance_valid(z) or z.state == Zombie.State.TO_WINDOW or z.state == Zombie.State.WAIT_WINDOW or z.state == Zombie.State.TEAR:
			continue
		if _flat((e as Dictionary)["pos"], player.global_position) < _f("horde_m", 12.0):
			chasing += 1
	if chasing < int(_f("train_min", 4.0)) and not (_active and followers >= int(_f("train_keep", 3.0))):
		return 0.0
	var v: float = 1.0
	if ammo_frac() < _f("low_ammo_frac", 0.2):
		v = minf(v, _f("low_ammo_value", 0.35))   # nearly dry: the ammo box (resupply) comes first
	return v


## The best (mag + reserve) / max over every carried gun.
func ammo_frac() -> float:
	var best: float = 0.0
	for w: WeaponInstance in player.weapons.slots:
		best = maxf(best, float(w.mag + w.reserve) / float(maxi(1, w.mag_size() + w.reserve_max())))
	return best


## Is it training right now (the action running and a train behind it)?
func training() -> bool:
	return _active and followers >= 1 and (phase == Phase.RUN or phase == Phase.FACE or phase == Phase.CUT)


func phase_name() -> String:
	return PHASE_NAMES[phase]


# ================================================================== per frame

func enter() -> void:
	_active = true
	_think_t = 0.0
	_set_phase(Phase.IDLE)


func exit() -> void:
	_active = false
	brain.aim.focus_target = null
	if not _shop.is_empty():
		_end_shop("left")


func run(delta: float) -> void:
	var now: float = brain.squad.time()
	_active = true
	_active_t = now
	phase_t += delta
	_rev_cd -= delta
	stats["time_s"] = float(stats["time_s"]) + delta
	if route == null or now >= _loop_t:
		_choose_route(now)
	var per: BotPerception = brain.perception
	if route == null:
		brain.loco.stop()
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	var me: Vector3 = player.global_position
	param = _near_param(route, me, param)
	var on: Vector3 = route.point_at(param)
	var off: float = _flat(on, me) + (50.0 if absf(on.y - me.y) > 2.0 else 0.0)
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 1.0 / maxf(1.0, _f("think_hz", 10.0))
		_think(now, me)
	if brain.loco.is_stuck():
		stats["stuck_s"] = float(stats["stuck_s"]) + delta
	if training():
		stats["training_s"] = float(stats["training_s"]) + delta
	var gap: float = gap_for(head_speed, c, head_reach)
	var w: WeaponInstance = brain.aim.cur()
	var mag: int = w.mag if w != null else 0
	if _esc_t > 0.0:
		_escape(delta)   # breaking off the loop (boxed in): finish that first
		return
	# off the loop: get on it (fire on the way unless the head is close)
	if off > _f("travel_m", 3.0):
		_set_phase(Phase.TRAVEL)
		stats["travel_s"] = float(stats["travel_s"]) + delta
		var hunt: Vector3 = brain.squad.hunt_point()
		if per.nearest != null and per.nearest_d < _f("travel_clear_m", 3.0):
			# something in reach on the way back: away from it first, shooting (the kite), then on to the loop
			_kite(delta, 0.5, per.pos_of(per.nearest))
			if not brain.aim.update(delta, true):
				brain.idle_look(delta)
			return
		brain.loco.move_to(_entry_point(me), 1.0 if head_d < gap else 0.6, 0.6)
		if head_d >= gap and per.nearest_d > 2.5:
			if not brain.aim.update(delta, true):
				brain.loco.clear_look()
		if hunt != Vector3.INF and followers == 0 and per.known.is_empty():
			brain.loco.move_to(hunt, 0.55, 2.0)
		return
	var cut: bool = ahead != null and is_instance_valid(ahead) and ahead_d < _f("cut_m", 6.0)
	if not _shop.is_empty():
		if cut or (head != null and head_d < gap + 0.5):
			_end_shop("aborted")
		else:
			var st: String = brain.tasks.run(_shop, delta)
			if st == "done" or st == "failed" or str(_shop.get("state", "")) == "failed":
				_end_shop(st)
			return
	if _holding_ground():
		_hold_ground(delta)
		return
	# transitions
	match phase:
		Phase.IDLE, Phase.TRAVEL, Phase.RUN:
			if cut and mag > 0 and head_d >= _f("cut_kill_gap_m", 5.0):
				_set_phase(Phase.CUT)
			elif (phase_t >= _f("run_min_s", 0.45) or phase != Phase.RUN) and brain.loco.fire_ready() and not brain.aim.reloading \
					and (safe_to_turn(head_d, gap, minf(ahead_d, window_ahead_m + _f("ahead_need_m", 6.0) - _f("window_turn_m", 4.0)), bunched, followers, mag, c) \
						or (phase == Phase.RUN and phase_t >= _f("run_max_s", 5.0) and mag > 0 and head_d >= gap and ahead_d >= _f("ahead_need_m", 6.0))):
				_set_phase(Phase.FACE)
				stats["turns"] = int(stats["turns"]) + 1
			elif phase != Phase.RUN:
				_set_phase(Phase.RUN)
		Phase.FACE:
			if cut and ahead_d < _f("cut_m", 6.0) * 0.8:
				_set_phase(Phase.CUT if mag > 0 and head_d >= _f("cut_kill_gap_m", 5.0) else Phase.RUN)
			elif head_d < gap or (mag <= 0 and not brain.aim.reloading and brain.aim.cur() != null and brain.aim.cur().reserve <= 0) 					or (phase_t > _f("face_max_s", 2.4) and (followers > 0 or player.horizontal_speed() > 1.0)):
				_set_phase(Phase.RUN)
		Phase.CUT:
			if not cut or mag <= 0 or head_d < _f("cut_kill_gap_m", 5.0) - 1.5:
				_set_phase(Phase.RUN)
	match phase:
		Phase.RUN:
			stats["run_s"] = float(stats["run_s"]) + delta
			_run(delta, gap, w)
		Phase.FACE:
			stats["face_s"] = float(stats["face_s"]) + delta
			_face(delta, gap)
		Phase.CUT:
			stats["cut_s"] = float(stats["cut_s"]) + delta
			_cut(delta, gap, w)
		_:
			_run(delta, gap, w)


func _set_phase(p: Phase) -> void:
	if p == phase:
		return
	if phase == Phase.CUT:
		brain.aim.focus_target = null
		_passing = false
		_cut_mode = ""
	phase = p
	phase_t = 0.0


## Facing the way: walk round the loop, sprint when the head is inside the gap, reload when the gap allows; a
## visible target in front (a window, the side of the ring) is shot on the walk.
func _run(delta: float, gap: float, w: WeaponInstance) -> void:
	lateral = move_toward(lateral, 0.0, delta * 2.0)
	var urg: float = 0.5
	var walk_v: float = float(GLData.table("player").get("walk_speed", 4.5)) * 0.95
	var need_sprint: bool = head_d < gap - _f("sprint_inside_m", 0.7) or (phase_t < 0.6 and head_d < gap + 0.5 and followers > 0) \
			or (head_speed >= walk_v and head_d < gap + _f("turn_extra_m", 1.6) + 0.3)   # (a runner at our heels: a walk never opens the gap to turn)
	var stamina: float = float(player.get("_stamina")) if player.get("_stamina") != null else 4.0
	if need_sprint and (stamina > _f("stamina_keep_s", 0.8) or head_d < gap * 0.6):
		urg = 1.0
	if brain.aim.reloading and urg >= 0.7:
		if head_d < gap * 0.7:
			brain.aim.cancel_reload()   # sprinting and reloading don't mix (the player's own rule)
		else:
			urg = 0.5
	if w != null and not brain.aim.reloading and w.reserve > 0 and float(w.mag) / float(maxi(1, w.mag_size())) < _f("reload_frac", 0.4) \
			and head_d > gap + _f("reload_gap_extra_m", 1.0) and urg < 0.7:
		brain.aim.start_reload()
	_kite(delta, urg)
	if urg < 0.7 and brain.aim.target != null and brain.perception.is_visible(brain.aim.target):
		var to: Vector3 = brain.aim.target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.5 and (route.tangent_at(param) * float(dir)).angle_to(to.normalized()) < deg_to_rad(65.0):
			brain.aim.update(delta, true)


## Turned on the train: fire into it; back round the loop at a walk while the head closes, stand still while it
## is far (it bunches up). With no train, stand on the loop and shoot what comes (or go after a stalled round's
## last zombie).
func _face(delta: float, gap: float) -> void:
	lateral = move_toward(lateral, 0.0, delta * 2.0)
	var fired: bool = brain.aim.update(delta, true)
	if not fired:
		if head != null and is_instance_valid(head):
			brain.loco.look_at_dir(brain.perception.pos_of(head) + Vector3.UP * 1.2 - brain.aim.eye())
		else:
			brain.idle_look(delta)
	var hunt: Vector3 = brain.squad.hunt_point()
	if head == null and hunt != Vector3.INF and brain.perception.known.is_empty():
		brain.loco.move_to(hunt, 0.55, 2.0)
		return
	if head == null or head_d > gap + _f("turn_extra_m", 1.6) + _f("hold_extra_m", 4.0):
		brain.loco.stop()
	else:
		_kite(delta, 0.5)


## A zombie on the loop ahead.
func _cut(delta: float, gap: float, w: WeaponInstance) -> void:
	var z: Zombie = ahead
	if _esc_t > 0.0:
		_escape(delta)
		return
	var loaded: bool = w != null and w.mag > 0 and not brain.aim.reloading
	var now: float = brain.squad.time()
	if _cut_mode == "" or now >= _cut_until or not _cut_mode_ok(loaded):
		var was: String = _cut_mode
		_cut_mode = _cut_decide(loaded)
		_cut_until = now + _f("cut_commit_s", 0.8)
		if _cut_mode != was:
			stats["cut_" + _cut_mode] = int(stats.get("cut_" + _cut_mode, 0)) + 1
	match _cut_mode:
		"shoot":
			# the train is well back (or there is none): face the cutter and shoot it, backing round the loop away
			# from it while it is inside its gap (and the train is still far)
			if brain.aim.focus_target != z:
				brain.aim.focus_target = z
				stats["cutter_shots"] = int(stats["cutter_shots"]) + 1
			if not brain.aim.update(delta, true):
				brain.loco.look_at_dir(brain.perception.pos_of(z) + Vector3.UP * 1.2 - brain.aim.eye())
			if ahead_d < gap_for(z.speed, c, reach_of(z)) and head_d >= _f("cut_kill_gap_m", 5.0) and behind_clear_m > 3.0:
				_steer(-dir, 0.0, 0.5)
			else:
				brain.loco.stop()
		"pass":
			# to the ring's far side and past it; loaded, it shoots the cutter while it walks by (strafing), dry it runs
			lateral = move_toward(lateral, _pass_off, delta * 6.0)
			if loaded and brain.perception.is_visible(z):
				brain.aim.focus_target = z
				brain.aim.update(delta, true)
				_steer(dir, lateral, 0.5)
			else:
				brain.aim.focus_target = null
				_steer(dir, lateral, 1.0)
		"reverse":
			brain.aim.focus_target = null
			_cut_mode = ""
			_reverse()
		_:
			brain.aim.focus_target = null
			_cut_mode = ""
			_esc_t = 1.2
			_esc_p = Vector3.INF
			stats["escapes"] = int(stats.get("escapes", 0)) + 1
			_escape(delta)


## What to do about the cutter: "shoot" it (loaded, the train well back), "pass" it wide (there is room on its far
## side: physics rays across the ring, and every cutter is on one side), "reverse" round the loop (the other way
## clear), else "escape" off the loop.
func _cut_decide(loaded: bool) -> String:
	if loaded and head_d >= _f("cut_kill_gap_m", 5.0):
		return "shoot"
	if ahead_d >= _f("pass_min_m", 2.5) and (ahead_sides.x == 0 or ahead_sides.y == 0):
		var off: float = _pass_offset()
		if not is_nan(off):
			_pass_off = off
			if not _passing:
				_passing = true
				stats["passes"] = int(stats["passes"]) + 1
			return "pass"
	if behind_clear_m >= _f("reverse_clear_m", 7.0) and _rev_cd <= 0.0:
		return "reverse"
	return "escape"


func _cut_mode_ok(loaded: bool) -> bool:
	match _cut_mode:
		"shoot":
			return loaded and head_d >= _f("cut_kill_gap_m", 5.0) - 1.5
		"pass":
			return ahead_d >= 0.6 or absf(lateral - ahead_lat) >= _f("pass_sep_m", 1.7)
	return false


## The lateral offset (m, + = left of travel) that passes the cutter on its far side, from the free room across the
## ring at the cutter (physics rays at knee height), or NAN when the gap left would be under pass_sep_m.
func _pass_offset() -> float:
	var t: float = route.advance(param, minf(ahead_d, 3.0), dir)
	var p: Vector3 = route.point_at(t) + Vector3.UP * 0.5
	var tan: Vector3 = route.tangent_at(t) * float(dir)
	var left: Vector3 = Vector3(-tan.z, 0.0, tan.x)
	var room: Array[float] = [0.0, 0.0]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for k: int in 2:
		var sgn: float = 1.0 if k == 0 else -1.0
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + left * sgn * 3.2, BotLocomotion.MASK_WORLD, [player.get_rid()])
		var hit: Dictionary = space.intersect_ray(q)
		room[k] = (p.distance_to(hit["position"]) if not hit.is_empty() else 3.2) - _f("pass_margin_m", 0.55)
	var side: float = -1.0 if ahead_lat > 0.15 else (1.0 if ahead_lat < -0.15 else (1.0 if room[0] >= room[1] else -1.0))
	var r: float = room[0] if side > 0.0 else room[1]
	var off: float = side * clampf(r, 0.0, _f("pass_max_off_m", 2.4))
	if absf(off - ahead_lat) < _f("pass_sep_m", 1.7):
		return NAN
	return off


## The economy's best purchase or resupply is right by the loop and the train is far enough back: do it now.
func _maybe_shop(now: float, me: Vector3) -> void:
	if not _shop.is_empty() or phase == Phase.CUT or not _active or (ahead != null and ahead_d < _f("cut_m", 6.0)):
		return
	if head != null and head_d < gap_for(head_speed, c, head_reach) + _f("shop_gap_extra_m", 3.0):
		return
	var best: Dictionary = brain.economy.best(now)
	for key: String in ["resupply", "buy"]:
		var cnd: Dictionary = best.get(key, {}) as Dictionary
		if cnd.is_empty() or not ["gun", "ammo", "ammo_box", "perk"].has(str(cnd.get("kind", ""))):
			continue
		var node: Node = cnd.get("node") as Node
		if node == null or not is_instance_valid(node) or not node is Interactable:
			continue
		var front: Vector3 = cnd["stand"] if cnd.get("stand", Vector3.INF) is Vector3 and cnd.get("stand", Vector3.INF) != Vector3.INF else BotBrain._front_of(node as Interactable)
		if _flat(front, me) > _f("shop_near_m", 4.0) or absf(front.y - me.y) > 1.5:
			continue
		if not brain.squad.can_claim(node, player.player_id):
			continue
		brain.squad.claim(node, player.player_id)
		_shop = cnd.duplicate()
		_shop["hold"] = 0.0
		_shop["state"] = "running"
		_shop["until"] = now + _f("shop_timeout_s", 6.0)
		stats["shops"] = int(stats.get("shops", 0)) + 1
		return


func _end_shop(result: String) -> void:
	var node: Variant = _shop.get("node")
	if node != null and is_instance_valid(node):
		brain.squad.release(node as Node, player.player_id)
	if result == "done":
		stats["shops_done"] = int(stats.get("shops_done", 0)) + 1
	_shop = {}
	brain.economy.invalidate()


## Special rounds and anything that holds its ground (ai_counters hold_ground: the Bellringers, 5.4 m/s with a
## lunge): nobody outruns them, so no training: face them and fire, standing still for the aim while they are out
## of reach, backing round the loop away from the nearest one inside it.
func _holding_ground() -> bool:
	if RoundManager.is_special_round and str(c.get("special_round", "train")) == "hold":
		return true
	return head != null and is_instance_valid(head) and bool(BotAIData.counter(head.enemy_id).get("hold_ground", false))


func _hold_ground(delta: float) -> void:
	if phase != Phase.FACE:
		_set_phase(Phase.FACE)
	stats["hold_s"] = float(stats.get("hold_s", 0.0)) + delta
	lateral = move_toward(lateral, 0.0, delta * 2.0)
	if not brain.aim.update(delta, true):
		if head != null and is_instance_valid(head):
			brain.loco.look_at_dir(brain.perception.pos_of(head) + Vector3.UP * 1.2 - brain.aim.eye())
		else:
			brain.idle_look(delta)
	var near_d: float = minf(head_d, ahead_d if ahead != null else INF)
	var z: Zombie = head if head_d <= ahead_d or ahead == null else ahead
	if z == null or near_d > reach_of(z) + _f("hold_back_m", 1.5):
		brain.loco.stop()
	else:
		_kite(delta, 0.5, brain.perception.pos_of(z))


func _reverse() -> void:
	dir = -dir
	_rev_cd = _f("reverse_cd_s", 2.0)
	stats["reversals"] = int(stats["reversals"]) + 1
	_think_t = 0.0
	_set_phase(Phase.RUN)
	_steer(dir, 0.0, 1.0)


## A zombie's reach (ai_counters reach_m: its swing, plus a lunge), for the gap.
static func reach_of(z: Zombie) -> float:
	return float(BotAIData.counter(z.enemy_id).get("reach_m", 1.5)) if z != null else 1.5


## Off the loop to the open ground away from the crowd (BotActions.retreat_point), at a run; with nowhere to go,
## it fights where it stands.
func _escape(delta: float) -> void:
	_esc_t -= delta
	if _esc_p == Vector3.INF or brain.loco.arrived() or fmod(_esc_t, 0.5) < delta:
		_esc_p = _escape_point()
	if _esc_p == Vector3.INF:
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		brain.loco.stop()
		return
	brain.loco.move_to(_esc_p, 1.0, 0.5)
	if head_d > 3.0 and ahead_d > 3.0 and brain.aim.update(delta, true):
		pass   # (shoots on the way while nothing is in reach)


## Moves along the loop in `d` with a lateral offset (m, + = left of the travel direction): the loop's own
## validated samples are the path (no navmesh query).
func _steer(d: int, lat: float, urgency: float) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lead: float = _f("lead_m", 3.5)
	var s: float = 1.0
	while s <= lead + 0.01:
		var t: float = route.advance(param, s, d)
		var p: Vector3 = route.point_at(t)
		if absf(lat) > 0.05:
			var tan: Vector3 = route.tangent_at(t) * float(d)
			p += Vector3(-tan.z, 0.0, tan.x) * lat
		pts.append(p)
		s += 0.5
	brain.loco.steer_path(pts, urgency)


## Steering for an open room (the taproom is a ring round three small tables: zombies cut straight across):
## every kite_every_s, of kite_dirs directions, the one that best goes on round the loop (toward the point lead_m
## ahead on it) while keeping clear of where every known zombie will be in kite_horizon_s (its reach + a margin,
## squared penalty, and a penalty for a straight line that brushes past one) and of walls (a ray per direction);
## a little hysteresis keeps the choice steady. A cutter is swerved round on whichever side is open; a loop whose
## best way stays against the travel direction for kite_reverse_after_s is reversed. `away_from` (not INF): head
## away from that point instead of round the loop (holding ground).
func _kite(delta: float, urgency: float, away_from: Vector3 = Vector3.INF) -> void:
	var me: Vector3 = player.global_position
	_kite_t -= delta
	if _kite_t <= 0.0 or _kite_dir == Vector3.ZERO:
		_kite_t = _f("kite_every_s", 0.1)
		_kite_dir = _best_dir(me, urgency, away_from)
		var tan: Vector3 = route.tangent_at(param) * float(dir)
		if away_from == Vector3.INF and _kite_dir.dot(tan) < -0.45:
			_against_t += _f("kite_every_s", 0.1)
			if _against_t >= _f("kite_reverse_after_s", 0.5) and _rev_cd <= 0.0:
				dir = -dir
				_rev_cd = _f("reverse_cd_s", 2.0)
				_against_t = 0.0
				stats["reversals"] = int(stats["reversals"]) + 1
		else:
			_against_t = 0.0
	var pts: PackedVector3Array = PackedVector3Array([me + _kite_dir * 1.2, me + _kite_dir * 2.4, me + _kite_dir * 3.6])
	brain.loco.steer_path(pts, urgency)


func _best_dir(me: Vector3, urgency: float, away_from: Vector3) -> Vector3:
	var speed: float = float(GLData.table("player").get("sprint_speed" if urgency >= 0.7 else "walk_speed", 4.5))
	var horizon: float = _f("kite_horizon_s", 0.7)
	var desired: Vector3
	if away_from != Vector3.INF:
		desired = Vector3(me.x - away_from.x, 0.0, me.z - away_from.z)
	else:
		var tgt: Vector3 = route.point_at(route.advance(param, _f("lead_m", 3.5), dir))
		desired = Vector3(tgt.x - me.x, 0.0, tgt.z - me.z)
	desired = desired.normalized() if desired.length() > 0.05 else (route.tangent_at(param) * float(dir))
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var w: Dictionary = {"align": _f("kite_w_align", 2.0), "wall": _f("kite_w_wall", 2.5), "zombie": _f("kite_w_zombie", 3.0),
		"cross": _f("kite_w_cross", 4.0), "margin": _f("kite_margin_m", 1.2), "keep": _f("kite_w_keep", 0.3)}
	var best: Vector3 = desired
	var best_s: float = -INF
	var n: int = int(_f("kite_dirs", 16.0))
	var knee: Vector3 = me + Vector3.UP * 0.5
	for k: int in n:
		var a: float = float(k) / float(n) * TAU
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(knee, knee + d * 3.0, BotLocomotion.MASK_WORLD, [player.get_rid()])
		var hit: Dictionary = space.intersect_ray(q)
		var free: float = knee.distance_to(hit["position"]) if not hit.is_empty() else 3.0
		if free < 0.8:
			continue
		var sc: float = kite_score(me, d, free, desired, _kite_dir, speed, horizon, _threats, w)
		if sc > best_s:
			best_s = sc
			best = d
	_kite_score = best_s
	return best


## Pure (unit-tested): how good moving `d` (flat unit) is: toward `desired`, a little for keeping `prev`, away from
## walls (`free` metres open that way), and clear of every threat [pos, speed, reach]: where it will be in
## `horizon` s (coming at where we will be) inside its reach + margin costs the square of the overlap; a straight
## line there that brushes past it costs too. w: {align, wall, zombie, cross, margin, keep}.
static func kite_score(me: Vector3, d: Vector3, free: float, desired: Vector3, prev: Vector3, speed: float, horizon: float, threats: Array, w: Dictionary) -> float:
	var sc: float = float(w.get("align", 2.0)) * d.dot(desired) - float(w.get("wall", 2.5)) * maxf(0.0, 2.2 - free) + float(w.get("keep", 0.3)) * d.dot(prev)
	var p1: Vector3 = me + d * minf(maxf(0.0, free - 0.4), speed * horizon)
	var a2: Vector2 = Vector2(me.x, me.z)
	var b2: Vector2 = Vector2(p1.x, p1.z)
	var margin: float = float(w.get("margin", 1.2))
	for t: Variant in threats:
		var zp: Vector3 = (t as Array)[0]
		var zr: float = float((t as Array)[2])
		var to_me: Vector3 = Vector3(p1.x - zp.x, 0.0, p1.z - zp.z)
		var dz: float = to_me.length()
		if dz > 10.0:
			continue
		var zf: Vector3 = zp + (to_me / maxf(0.01, dz)) * minf(float((t as Array)[1]) * horizon, maxf(0.0, dz - 0.5))
		var dist: float = Vector2(p1.x - zf.x, p1.z - zf.z).length()
		var rr: float = zr + margin
		if dist < rr:
			sc -= float(w.get("zombie", 3.0)) * (rr - dist) * (rr - dist)
		var z2: Vector2 = Vector2(zp.x, zp.z)
		var cpa: float = Geometry2D.get_closest_point_to_segment(z2, a2, b2).distance_to(z2)
		if cpa < zr + 0.6:
			sc -= float(w.get("cross", 4.0)) * (zr + 0.6 - cpa)
	return sc


# ================================================================== the picture

func _think(now: float, me: Vector3) -> void:
	var per: BotPerception = brain.perception
	var L: float = route.length()
	var pts: Array = []
	head = null
	head_d = INF
	head_speed = 0.0
	head_reach = 1.5
	ahead = null
	ahead_d = INF
	ahead_lat = 0.0
	ahead_n = 0
	ahead_sides = Vector2i.ZERO
	window_ahead_m = INF
	behind_clear_m = INF
	followers = 0
	_threats.clear()
	var cap: float = _f("dead_reckon_s", 2.0)
	var travel: Vector3 = route.tangent_at(param) * float(dir)
	for e: Variant in per.known:
		var ed: Dictionary = e as Dictionary
		var z: Zombie = ed.get("node") as Zombie
		if not BotPerception.targetable(z):
			continue
		var zp: Vector3 = per.pos_of(z)
		var at_window: bool = z.state == Zombie.State.TO_WINDOW or z.state == Zombie.State.WAIT_WINDOW or z.state == Zombie.State.TEAR
		if not per.is_visible(z) and not at_window:
			zp = dead_reckon(zp, me, z.speed, now - float(ed.get("t", now)), cap)
		if absf(zp.y - me.y) > 2.6:
			continue
		var d: float = _flat(zp, me)
		var zt: float = route.closest_param(zp)
		var on: Vector3 = route.point_at(zt)
		var lat: float = _flat(on, zp)
		var fwd: float = route.distance_along(param, zt, dir)
		if not at_window:
			_threats.append([zp, z.speed, reach_of(z)])
		if at_window:
			# still outside a window (on its way, waiting or tearing the boards): not on the loop yet, but that window
			# will spill onto it; noted for the turn rule
			if fwd <= L * 0.5 and fwd <= _f("ahead_m", 10.0) and lat <= route.ring_width * 0.5 + 3.5:
				window_ahead_m = minf(window_ahead_m, fwd)
			continue
		var to_z: Vector3 = Vector3(zp.x - me.x, 0.0, zp.z - me.z)
		var in_front: bool = to_z.length() > 0.05 and travel.dot(to_z.normalized()) > _f("front_dot", 0.35)
		var cls: String = classify(fwd, L, lat, d, route.ring_width, c, in_front)
		if cls == "ahead" and (fwd > L * 0.5 or fwd > _f("ahead_m", 10.0)):
			fwd = d   # a close one cutting across in front: its own distance
		if cls == "ahead":
			ahead_n += 1
			var tan: Vector3 = route.tangent_at(zt) * float(dir)
			var slat: float = Vector3(-tan.z, 0.0, tan.x).dot(Vector3(zp.x - on.x, 0.0, zp.z - on.z))
			if fwd < _f("cut_m", 6.0):
				if slat > 0.0:
					ahead_sides.x += 1
				else:
					ahead_sides.y += 1
			if fwd < ahead_d:
				ahead_d = fwd
				ahead = z
				ahead_lat = slat
			continue
		if cls == "behind" or cls == "close":
			followers += 1
			pts.append(zp)
			if d < head_d:
				head_d = d
				head = z
				head_speed = z.speed
				head_reach = reach_of(z)
			behind_clear_m = minf(behind_clear_m, route.distance_along(param, zt, -dir))
	# a boss on the loop ahead within its keep-away ring counts as a cutter at that ring's edge
	if ahead != null and BotPerception.is_boss(ahead):
		ahead_d = maxf(0.0, ahead_d - float(BotAIData.counter(ahead.enemy_id).get("keep_distance_m", 0.0)))
	var ts: Dictionary = train_stats(pts, _f("bunch_m", 3.0))
	spread_m = float(ts["spread"])
	bunched = float(ts["bunched"])
	if _active and followers >= 1:
		stats["samples"] = int(stats["samples"]) + 1
		stats["follow_sum"] = float(stats["follow_sum"]) + float(followers)
		stats["spread_sum"] = float(stats["spread_sum"]) + spread_m
		stats["bunched_sum"] = float(stats["bunched_sum"]) + bunched
		stats["train_max"] = maxi(int(stats["train_max"]), followers)
		if followers >= 4:
			stats["big_samples"] = int(stats["big_samples"]) + 1
	_maybe_shop(now, me)
	var cut_now: bool = ahead != null and ahead_d < _f("cut_m", 6.0)
	if cut_now and not _was_cut and _active:
		stats["cut_ins"] = int(stats["cut_ins"]) + 1
	_was_cut = cut_now


## Where to break off to: of the loop points 4-12 m either way round and the open-ground retreat point
## (BotActions.retreat_point), the one with the most room from the known zombies whose straight way there doesn't
## brush past one (corners next to a window were where the first version died).
func _escape_point() -> Vector3:
	var me: Vector3 = player.global_position
	var cands: Array[Vector3] = []
	for off: float in [4.0, -4.0, 7.0, -7.0, 10.0, -10.0, 13.0, -13.0]:
		cands.append(route.point_at(route.wrap_param(param + off)))
	var rp: Vector3 = brain.actions.retreat_point()
	if rp != Vector3.INF:
		cands.append(rp)
	var best: Vector3 = Vector3.INF
	var best_s: float = -INF
	for p: Vector3 in cands:
		if absf(p.y - me.y) > 1.6:
			continue
		var clear: float = 12.0
		var brush: bool = false
		var a: Vector2 = Vector2(me.x, me.z)
		var b: Vector2 = Vector2(p.x, p.z)
		for e: Variant in brain.perception.known:
			var zp: Vector3 = (e as Dictionary)["pos"]
			var z2: Vector2 = Vector2(zp.x, zp.z)
			clear = minf(clear, z2.distance_to(b))
			if Geometry2D.get_closest_point_to_segment(z2, a, b).distance_to(z2) < 1.4:
				brush = true
		var s: float = minf(clear, 9.0) - (6.0 if brush else 0.0) - _flat(p, me) * 0.1
		if s > best_s:
			best_s = s
			best = p
	return best


## Where to get back on the loop: of the nearest point and the points 3 and 6 m either side of it, the one with
## the most room from the known zombies (cached for 0.5 s).
var _entry_p: Vector3 = Vector3.INF
var _entry_t: float = -1.0


func _entry_point(me: Vector3) -> Vector3:
	var now: float = brain.squad.time()
	if _entry_p != Vector3.INF and now - _entry_t < 0.5:
		return _entry_p
	_entry_t = now
	var base: float = route.closest_param(me)
	var best_s: float = -INF
	for off: float in [0.0, 3.0, -3.0, 6.0, -6.0]:
		var p: Vector3 = route.point_at(route.wrap_param(base + off))
		var clear: float = 12.0
		for e: Variant in brain.perception.known:
			clear = minf(clear, _flat((e as Dictionary)["pos"], p))
		var s: float = minf(clear, 8.0) - absf(off) * 0.25
		if s > best_s:
			best_s = s
			_entry_p = p
	return _entry_p


## The loop parameter nearest `pos` within +-6 m of `hint` (the whole loop when far off it).
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


# ================================================================== the loop

func _refresh_routes(now: float) -> void:
	_loop_t = now + _f("loop_every_s", 3.0)
	_routes = TrainingRoute.for_map(String(brain.squad.map.map_id), true) if brain.squad.map != null else ([] as Array[TrainingRoute])


func _choose_route(now: float) -> void:
	_refresh_routes(now)
	if _routes.is_empty():
		route = null
		return
	var me: Vector3 = player.global_position
	var rows: Array = []
	var rs: Array[TrainingRoute] = []
	for r: TrainingRoute in _routes:
		var tp: Vector3 = r.point_at(r.closest_param(me))
		var travel: float = _flat(tp, me) if (r == route or _flat(tp, me) < 1.5) else brain.loco.path_length_to(tp)
		if travel == INF:
			continue
		rows.append({"id": r.id, "length": r.length(), "ring_width": r.ring_width, "travel_m": travel, "windows": _windows_near(r),
			"home": r.home, "bonus": r.agent_bonus, "current": route != null and r.id == route.id})
		rs.append(r)
	var i: int = choose_loop(rows, c.get("loop_weights", {}) as Dictionary)
	if i < 0:
		route = null
		return
	if route == null or rs[i].id != route.id:
		route = rs[i]
		param = route.closest_param(me)
		dir = _pick_dir()
		stats["loop_changes"] = int(stats["loop_changes"]) + 1
		(stats["loops"] as PackedStringArray).append("r%d %s" % [RoundManager.current_round, route.id])
	else:
		route = rs[i]   # the same loop (a fresh object after a door opened)


## Windows (barricades) within window_near_m of a loop's line: where zombies climb in onto it (cached).
func _windows_near(r: TrainingRoute) -> int:
	if _windows.has(r.id):
		return int(_windows[r.id])
	var n: int = 0
	var near: float = _f("window_near_m", 3.5)
	for b: Node in player.get_tree().get_nodes_in_group(&"barricades"):
		var b3: Node3D = b as Node3D
		if b3 != null and r.distance_to_line(b3.global_position) < near:
			n += 1
	_windows[r.id] = n
	return n


## The way round with fewer known zombies close ahead.
func _pick_dir() -> int:
	var per: BotPerception = brain.perception
	var me: Vector3 = player.global_position
	var n: Array[int] = [0, 0]
	for e: Variant in per.known:
		var zp: Vector3 = (e as Dictionary)["pos"]
		if _flat(zp, me) > 12.0:
			continue
		var zt: float = route.closest_param(zp)
		if route.distance_along(param, zt, 1) < route.distance_along(param, zt, -1):
			n[0] += 1
		else:
			n[1] += 1
	return 1 if n[0] <= n[1] else -1


# ================================================================== stats

func _on_damaged(pid: int, amount: float) -> void:
	if player == null or not is_instance_valid(player) or pid != player.player_id or amount <= 0.0:
		return
	stats["hits"] = int(stats["hits"]) + 1
	if hit_log.size() < 80:
		var per: BotPerception = brain.perception
		hit_log.append("r%d %s/%s f%d h%.1f a%.1f n%.1f %s hp%.0f v%.1f%s" % [RoundManager.current_round, brain.action, phase_name(), followers,
			minf(head_d, 99.0), minf(ahead_d, 99.0), minf(per.nearest_d, 99.0), str(per.nearest.tier) if per.nearest != null else "-",
			player.hp, player.horizontal_speed(), " SPECIAL" if RoundManager.is_special_round else ""])
		if verbose_hits:
			var me: Vector3 = player.global_position
			var fw: Vector3 = -player.global_basis.z
			var zs: PackedStringArray = []
			var dirn: ZombieDirector = brain.squad.director()
			for zz: Zombie in (dirn.active_zombies() if dirn != null else []):
				if _flat(zz.global_position, me) < 9.0:
					zs.append("(%.1f,%.1f %s%s)" % [zz.global_position.x, zz.global_position.z, Zombie.State.keys()[zz.state].left(4), "" if per.is_known(zz) else "?"])
			hit_log[hit_log.size() - 1] += " | me (%.1f,%.1f) face (%.1f,%.1f) dir %d param %.1f lat %.1f cut %s | %s" % [me.x, me.z, fw.x, fw.z, dir, param, lateral, _cut_mode, " ".join(zs)]
	if training():
		stats["hits_training"] = int(stats["hits_training"]) + 1
		stats["damage_training"] = float(stats["damage_training"]) + amount


func _on_killed(_enemy: StringName, _limb: StringName, _weapon: StringName, by: int) -> void:
	if player == null or not is_instance_valid(player) or by != player.player_id:
		return
	stats["kills"] = int(stats["kills"]) + 1
	if training():
		stats["kills_training"] = int(stats["kills_training"]) + 1


## The soak's summary: seconds per phase, the train (mean followers, spread, bunched share, max), cut-ins, hits.
func summary() -> Dictionary:
	var s: int = maxi(1, int(stats["samples"]))
	return {"training_s": snappedf(float(stats["training_s"]), 0.1), "run_s": snappedf(float(stats["run_s"]), 0.1),
		"face_s": snappedf(float(stats["face_s"]), 0.1), "cut_s": snappedf(float(stats["cut_s"]), 0.1), "travel_s": snappedf(float(stats["travel_s"]), 0.1),
		"train_mean": snappedf(float(stats["follow_sum"]) / float(s), 0.01), "train_spread_m": snappedf(float(stats["spread_sum"]) / float(s), 0.01),
		"train_bunched": snappedf(float(stats["bunched_sum"]) / float(s), 0.01), "train_max": int(stats["train_max"]),
		"big_train_share": snappedf(float(stats["big_samples"]) / float(s), 0.01),
		"cut_ins": int(stats["cut_ins"]), "hits": int(stats["hits"]), "hits_training": int(stats["hits_training"]),
		"damage_training": snappedf(float(stats["damage_training"]), 1.0), "kills": int(stats["kills"]), "kills_training": int(stats["kills_training"]),
		"reversals": int(stats["reversals"]), "passes": int(stats["passes"]), "cutter_shots": int(stats["cutter_shots"]), "escapes": int(stats["escapes"]),
		"shops": int(stats.get("shops", 0)), "shops_done": int(stats.get("shops_done", 0)), "cut_modes": "shoot %d pass %d reverse %d escape %d" % [int(stats.get("cut_shoot", 0)), int(stats.get("cut_pass", 0)), int(stats.get("cut_reverse", 0)), int(stats.get("cut_escape", 0))],
		"turns": int(stats["turns"]), "stuck_s": snappedf(float(stats["stuck_s"]), 0.1), "loop_changes": int(stats["loop_changes"]),
		"loops": " ".join(stats["loops"] as PackedStringArray)}


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
