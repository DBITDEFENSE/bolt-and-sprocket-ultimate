class_name BotCensus
extends Node
## The bot census (bot AI pass, 2026-11): an outside observer the soak adds beside BotMetrics (ai_soak --census).
## It does two things the metrics logger doesn't:
##   1. STUCK CENSUS. Every SAMPLE_S it samples every standing bot of the squad (the three bots, Jakub, the map's
##      companion) and judges, from positions alone (not from the locomotion layer's own ladder), whether a bot
##      that wants to be somewhere is getting there:
##        "noprog"  it has a goal further than GOAL_FAR_M and in NOPROG_S it neither moved NOPROG_NET_M net nor got
##                  NOPROG_NET_M closer to the goal
##        "osc"     it walked OSC_WALK_M or more in OSC_S inside a box under OSC_BOX_M across, with a goal further
##                  than GOAL_FAR_M that it didn't get OSC_GAIN_M closer to (pacing, flipping between two ways)
##        "nopath"  it has a goal further than GOAL_FAR_M, no path and stands for NOPATH_S
##        "parked"  it stands for PARKED_S with no goal while its leader is PARKED_FAR_M away or on another floor
##      Each episode is logged with where, the zone, the action and the task, the goal, the path's state, what the
##      body is pressed against (a shape cast toward the next path point), how far the navmesh is, the nearest
##      teammate and zombie, and how long it lasted. finish() clusters them into CELL_M cells (per storey), ranks
##      the hot spots, prints them, writes <stem>_stuck.jsonl / _hotspots.md and top-down PNG plots per storey.
##   2. THE LATE GAME. A row per bot per round: kills, downs, revives, time standing, damage taken (by the nearest
##      enemy kind at the hit), shots and hits, the guns (taught? tier) and tonics held at the round's end, Scrip,
##      ammo, how much of the round it spent standing still with a zombie within PRESS_M, backed against a wall,
##      and the seconds in each action. Written to <stem>_rounds.csv; a per-round squad table goes to the .md.
## The pure rules (the episode tests and the clustering) are static and unit-tested
## (gravelight/tests/unit/test_bot_census.gd).

const SAMPLE_S: float = 0.25
const GOAL_FAR_M: float = 2.5
const NOPROG_S: float = 5.0
const NOPROG_NET_M: float = 1.0
const OSC_S: float = 8.0
const OSC_WALK_M: float = 7.0
const OSC_BOX_M: float = 4.0
const OSC_GAIN_M: float = 2.0
const NOPATH_S: float = 4.0
const PARKED_S: float = 12.0
const PARKED_FAR_M: float = 14.0
const CELL_M: float = 2.5
const STOREY_M: float = 3.0
const PRESS_M: float = 3.5
const KEEP_S: float = 8.5

var map: MapRoot
var stem: String = ""
var t: float = 0.0
var episodes: Array[Dictionary] = []
var round_rows: Array[Dictionary] = []
var bot_seconds: float = 0.0          # standing bot time sampled (the "bot-hours" under the rates)
var _acc: float = 0.0
var _hist: Dictionary = {}            # pid -> Array of samples {t, p, gd, far, path, spd}
var _open: Dictionary = {}            # "pid:kind" -> episode
var _still_t: Dictionary = {}         # pid -> seconds standing with no goal
var _rs: Dictionary = {}              # pid -> this round's counters
var _round: int = 0
var _round_t0: float = 0.0
var _shots0: Dictionary = {}
var _hits0: Dictionary = {}
var _total_kills: int = 0
var _human_kills: int = 0


func setup(map_root: MapRoot, out_stem: String) -> void:
	map = map_root
	stem = out_stem
	GLBus.enemy_killed.connect(_on_killed)
	GLBus.player_downed.connect(_on_downed)
	GLBus.player_revived.connect(_on_revived)
	GLBus.player_damaged.connect(_on_damaged)
	GLBus.round_started.connect(_on_round_started)
	_round = maxi(1, RoundManager.current_round)
	_round_t0 = 0.0


func _exit_tree() -> void:
	for pair: Array in [[GLBus.enemy_killed, _on_killed], [GLBus.player_downed, _on_downed], [GLBus.player_revived, _on_revived],
			[GLBus.player_damaged, _on_damaged], [GLBus.round_started, _on_round_started]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


# ================================================================== the pure rules

## No progress: over the window the body moved under net_m net and the goal got under net_m closer.
static func is_noprog(net_moved: float, goal_then: float, goal_now: float, net_m: float = NOPROG_NET_M) -> bool:
	return net_moved < net_m and goal_then - goal_now < net_m


## Oscillating: it walked walk_m or more inside a box under box_m across and gained under gain_m on the goal.
static func is_osc(walked: float, box_diag: float, goal_then: float, goal_now: float, walk_m: float = OSC_WALK_M, box_m: float = OSC_BOX_M, gain_m: float = OSC_GAIN_M) -> bool:
	return walked >= walk_m and box_diag < box_m and goal_then - goal_now < gain_m


## The cell key of a position: CELL_M squares per storey (STOREY_M bands).
static func cell_of(p: Vector3, cell_m: float = CELL_M, storey_m: float = STOREY_M) -> Vector3i:
	return Vector3i(int(floor(p.x / cell_m)), int(floor((p.y + 0.5) / storey_m)), int(floor(p.z / cell_m)))


## Clusters episodes ({pos, dur, kind, ...}) into cells: [{cell, n, secs, center, kinds{}, zone, against{}, what{}}]
## sorted by seconds, the worst first.
static func cluster(eps: Array, cell_m: float = CELL_M) -> Array[Dictionary]:
	var cells: Dictionary = {}
	for ev: Variant in eps:
		var e: Dictionary = ev
		var p: Vector3 = e["pos"]
		var k: Vector3i = cell_of(p, cell_m)
		if not cells.has(k):
			cells[k] = {"cell": k, "n": 0, "secs": 0.0, "sum": Vector3.ZERO, "kinds": {}, "zone": str(e.get("zone", "")), "against": {}, "what": {}, "who": {}}
		var c: Dictionary = cells[k]
		c["n"] = int(c["n"]) + 1
		c["secs"] = float(c["secs"]) + float(e.get("dur", 0.0))
		c["sum"] = (c["sum"] as Vector3) + p
		_bump(c["kinds"], str(e.get("kind", "")))
		_bump(c["against"], str(e.get("against", "")))
		_bump(c["what"], "%s/%s" % [str(e.get("action", "")), str(e.get("task", ""))])
		_bump(c["who"], str(e.get("name", "")))
	var out: Array[Dictionary] = []
	for k2: Variant in cells.keys():
		var c2: Dictionary = cells[k2]
		c2["center"] = (c2["sum"] as Vector3) / float(maxi(1, int(c2["n"])))
		out.append(c2)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["secs"]) > float(b["secs"]))
	return out


static func _bump(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1


static func _top(d: Dictionary, n: int = 2) -> String:
	var ks: Array = d.keys()
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return int(d[a]) > int(d[b]))
	var out: PackedStringArray = []
	for i: int in mini(n, ks.size()):
		out.append("%s x%d" % [str(ks[i]), int(d[ks[i]])])
	return ", ".join(out)


# ================================================================== sampling

func _physics_process(delta: float) -> void:
	if map == null or not is_instance_valid(map) or map.squad == null:
		return
	t += delta
	_tick_round(delta)
	_acc += delta
	if _acc < SAMPLE_S:
		return
	var dt: float = _acc
	_acc = 0.0
	for b: BotBrain in map.squad.brains:
		if b == null or not is_instance_valid(b) or b.player == null or not is_instance_valid(b.player):
			continue
		var p: Player = b.player
		if p.downed or p.spectating or not p.is_inside_tree():
			_hist.erase(p.player_id)
			_close_all(p.player_id)
			continue
		bot_seconds += dt
		_sample(b, dt)


func _sample(b: BotBrain, dt: float) -> void:
	var p: Player = b.player
	var pid: int = p.player_id
	var lo: Object = b.loco as Object
	var pos: Vector3 = p.global_position
	var goal: Vector3 = Vector3.INF
	var has_path: bool = false
	if lo != null and lo.has_method("current_target"):
		goal = lo.call("current_target")
		var pth: Variant = lo.get("_path")
		has_path = pth is PackedVector3Array and not (pth as PackedVector3Array).is_empty()
	var gd: float = _flat(goal, pos) if goal.is_finite() else -1.0
	var arrived: bool = lo == null or not lo.has_method("arrived") or bool(lo.call("arrived"))
	var far: bool = gd > GOAL_FAR_M and not arrived
	var h: Array = _hist.get(pid, [])
	h.append({"t": t, "p": pos, "gd": gd, "far": far, "path": has_path, "spd": p.horizontal_speed()})
	while not h.is_empty() and t - float((h[0] as Dictionary)["t"]) > KEEP_S:
		h.pop_front()
	_hist[pid] = h
	# --- noprog
	var w: Dictionary = _window(h, NOPROG_S)
	_judge(b, "noprog", not w.is_empty() and bool(w["all_far"]) and is_noprog(float(w["net"]), float(w["gd0"]), gd), NOPROG_S)
	# --- osc
	var w2: Dictionary = _window(h, OSC_S)
	_judge(b, "osc", not w2.is_empty() and bool(w2["all_far"]) and is_osc(float(w2["walked"]), float(w2["box"]), float(w2["gd0"]), gd), OSC_S)
	# --- nopath
	var w3: Dictionary = _window(h, NOPATH_S)
	_judge(b, "nopath", not w3.is_empty() and bool(w3["all_far"]) and not bool(w3["any_path"]) and float(w3["net"]) < 0.5, NOPATH_S)
	# --- parked
	var leader: Player = map.squad.leader_for(b)
	var away: bool = leader != null and leader != p and is_instance_valid(leader) and not leader.downed and not leader.spectating \
		and (_flat(leader.global_position, pos) > PARKED_FAR_M or absf(leader.global_position.y - pos.y) > 2.5)
	if not far and p.horizontal_speed() < 0.3 and away and not ["revive", "buy", "crate", "resupply", "repair"].has(b.action):
		_still_t[pid] = float(_still_t.get(pid, 0.0)) + dt
	else:
		_still_t[pid] = 0.0
	_judge(b, "parked", float(_still_t.get(pid, 0.0)) >= PARKED_S, PARKED_S)


## The last `secs` of a history: {} when it doesn't reach back that far, else {net, walked, box, gd0, all_far, any_path}.
static func _window(h: Array, secs: float) -> Dictionary:
	if h.size() < 2:
		return {}
	var last: Dictionary = h[h.size() - 1]
	var now: float = float(last["t"])
	if now - float((h[0] as Dictionary)["t"]) < secs - 0.01:
		return {}
	var i0: int = h.size() - 1
	while i0 > 0 and now - float((h[i0 - 1] as Dictionary)["t"]) <= secs + 0.01:
		i0 -= 1
	var first: Dictionary = h[i0]
	var walked: float = 0.0
	var lo: Vector3 = first["p"]
	var hi: Vector3 = first["p"]
	var all_far: bool = true
	var any_path: bool = false
	for i: int in range(i0, h.size()):
		var s: Dictionary = h[i]
		var q: Vector3 = s["p"]
		if i > i0:
			walked += _flat(q, (h[i - 1] as Dictionary)["p"])
		lo = Vector3(minf(lo.x, q.x), 0.0, minf(lo.z, q.z))
		hi = Vector3(maxf(hi.x, q.x), 0.0, maxf(hi.z, q.z))
		all_far = all_far and bool(s["far"])
		any_path = any_path or bool(s["path"])
	return {"net": _flat(last["p"], first["p"]), "walked": walked, "box": Vector2(hi.x - lo.x, hi.z - lo.z).length(), "gd0": float(first["gd"]),
		"all_far": all_far, "any_path": any_path}


func _judge(b: BotBrain, kind: String, on: bool, window_s: float) -> void:
	var key: String = "%d:%s" % [b.player.player_id, kind]
	if on:
		if not _open.has(key):
			_open[key] = _describe(b, kind, window_s)
		var e: Dictionary = _open[key]
		e["dur"] = t - float(e["t0"])
		e["off_t"] = 0.0
	elif _open.has(key):
		var e2: Dictionary = _open[key]
		e2["off_t"] = float(e2.get("off_t", 0.0)) + SAMPLE_S
		if float(e2["off_t"]) >= 1.0:
			_close(key)


func _close(key: String) -> void:
	var e: Dictionary = _open[key]
	_open.erase(key)
	e.erase("off_t")
	episodes.append(e)


func _close_all(pid: int) -> void:
	for k: Variant in _open.keys():
		if str(k).begins_with("%d:" % pid):
			_close(str(k))
	_still_t[pid] = 0.0


func _describe(b: BotBrain, kind: String, window_s: float) -> Dictionary:
	var p: Player = b.player
	var pos: Vector3 = p.global_position
	var lo: Object = b.loco as Object
	var goal: Vector3 = lo.call("current_target") if lo != null and lo.has_method("current_target") else Vector3.INF
	var nav: RID = p.get_world_3d().navigation_map
	var nav_pt: Vector3 = NavigationServer3D.map_get_closest_point(nav, pos)
	var path: PackedVector3Array = PackedVector3Array()
	var path_i: int = 0
	var mode: int = -1
	if lo != null:
		var pv: Variant = lo.get("_path")
		if pv is PackedVector3Array:
			path = pv
		path_i = int(lo.get("_path_i")) if lo.get("_path_i") != null else 0
		mode = int(lo.get("mode")) if lo.get("mode") != null else -1
	var toward: Vector3 = path[path_i] if path_i < path.size() else goal
	var mate_d: float = INF
	for o: BotBrain in map.squad.brains:
		if o != b and o.player != null and is_instance_valid(o.player) and not o.player.spectating:
			mate_d = minf(mate_d, o.player.global_position.distance_to(pos))
	var hu: Player = map.squad.human()
	var human_d: float = hu.global_position.distance_to(pos) if hu != null and is_instance_valid(hu) and not hu.spectating else INF
	var z_d: float = INF
	if map.director != null:
		for z: Zombie in map.director.active_zombies():
			z_d = minf(z_d, z.global_position.distance_to(pos))
	var leader: Player = map.squad.leader_for(b)
	return {"t0": t - window_s, "dur": window_s, "round": RoundManager.current_round, "kind": kind, "pid": p.player_id, "name": Net.display_name(p.player_id),
		"pos": pos, "zone": String(ZoneVolume.zone_at(get_tree(), pos)), "action": b.action, "task": str(b.task.get("label", b.task.get("kind", ""))),
		"mode": ["stop", "move", "follow", "hold", "train"][mode] if mode >= 0 and mode < 5 else "?", "goal": goal,
		"goal_d": _flat(goal, pos) if goal.is_finite() else -1.0, "goal_dy": goal.y - pos.y if goal.is_finite() else 0.0,
		"path_n": path.size(), "path_i": path_i, "against": _against(p, toward), "nav_off": _flat(nav_pt, pos), "nav_dy": pos.y - nav_pt.y,
		"mate_d": mate_d, "human_d": human_d, "zombie_d": z_d, "on_floor": p.is_on_floor(),
		"leader_d": _flat(leader.global_position, pos) if leader != null and is_instance_valid(leader) else -1.0}


## What stands between the body and where it wants to step: a waist-high and a knee-high sphere swept 0.9 m toward
## `toward` on the world, door, player and zombie layers. "" when the way is clear (or there is nowhere to go).
func _against(p: Player, toward: Vector3) -> String:
	if not toward.is_finite():
		return ""
	var d: Vector3 = toward - p.global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return ""
	d = d.normalized()
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for hgt: float in [0.45, 1.1]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * hgt, p.global_position + Vector3.UP * hgt + d * 1.1,
			1 | (1 << 1) | (1 << 2) | (1 << 5) | (1 << 8) | (1 << 10))
		q.exclude = [p.get_rid()]
		var r: Dictionary = space.intersect_ray(q)
		if not r.is_empty():
			return _node_tag(r["collider"] as Node)
	return ""


static func _node_tag(n: Node) -> String:
	if n == null:
		return "?"
	if n is Player:
		return "player:" + n.name
	if n is Zombie:
		return "zombie"
	var parts: PackedStringArray = []
	var c: Node = n
	while c != null and parts.size() < 3 and not (c is MapRoot):
		parts.insert(0, c.name)
		c = c.get_parent()
	return "/".join(parts)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ================================================================== the late game: a row per bot per round

func _blank_round() -> Dictionary:
	return {"kills": 0, "downs": 0, "revives": 0, "revived": 0, "dmg": 0.0, "dmg_by": {}, "up_s": 0.0, "down_s": 0.0, "still_press_s": 0.0, "press_s": 0.0,
		"cornered_s": 0.0, "acts": {}, "moved": 0.0, "last": Vector3.INF, "n3_s": 0.0, "empty_s": 0.0}


func _r(pid: int) -> Dictionary:
	if not _rs.has(pid):
		_rs[pid] = _blank_round()
	return _rs[pid]


func _tick_round(delta: float) -> void:
	for b: BotBrain in map.squad.brains:
		if b == null or not is_instance_valid(b) or b.player == null or not is_instance_valid(b.player):
			continue
		var p: Player = b.player
		var r: Dictionary = _r(p.player_id)
		if p.spectating or p.downed:
			r["down_s"] = float(r["down_s"]) + delta
			r["last"] = Vector3.INF
			continue
		r["up_s"] = float(r["up_s"]) + delta
		var acts: Dictionary = r["acts"]
		acts[b.action] = float(acts.get(b.action, 0.0)) + delta
		var pos: Vector3 = p.global_position
		if (r["last"] as Vector3).is_finite():
			r["moved"] = float(r["moved"]) + _flat(pos, r["last"])
		r["last"] = pos
		var nd: float = b.perception.nearest_d if b.perception != null else INF
		if nd < PRESS_M:
			r["press_s"] = float(r["press_s"]) + delta
			if p.horizontal_speed() < 0.5:
				r["still_press_s"] = float(r["still_press_s"]) + delta
		if b.perception != null and b.perception.n5 >= 3:
			r["n3_s"] = float(r["n3_s"]) + delta
		var cw: WeaponInstance = b.aim.cur() if b.aim != null else null
		if cw != null and cw.mag <= 0 and nd < 6.0:
			r["empty_s"] = float(r["empty_s"]) + delta


func _on_killed(_eid: StringName, _limb: StringName, _wid: StringName, by: int) -> void:
	_total_kills += 1
	if by > 0 and not GameState.is_bot(by):
		_human_kills += 1
	if by > 0:
		_r(by)["kills"] = int(_r(by)["kills"]) + 1


func _on_downed(pid: int) -> void:
	_r(pid)["downs"] = int(_r(pid)["downs"]) + 1


func _on_revived(pid: int, by: int) -> void:
	_r(pid)["revived"] = int(_r(pid)["revived"]) + 1
	if by > 0:
		_r(by)["revives"] = int(_r(by)["revives"]) + 1


func _on_damaged(pid: int, amount: float) -> void:
	if amount <= 0.0 or map == null or map.squad == null:
		return
	var r: Dictionary = _r(pid)
	r["dmg"] = float(r["dmg"]) + amount
	var p: Player = map.squad.player_by_id(pid)
	var kind: String = "other"
	if p != null and map.director != null:
		var best: float = 4.5
		for z: Zombie in map.director.active_zombies():
			var d: float = z.global_position.distance_to(p.global_position)
			if d < best:
				best = d
				kind = String(z.enemy_id)
	var by: Dictionary = r["dmg_by"]
	by[kind] = float(by.get(kind, 0.0)) + amount


func _on_round_started(r: int, _special: bool) -> void:
	if r == _round:
		return
	_close_round()
	_round = r
	_round_t0 = t


func _close_round() -> void:
	if map == null or not is_instance_valid(map) or map.squad == null:
		return
	var secs: float = t - _round_t0
	var pids: Array = []
	for b: BotBrain in map.squad.brains:
		if b != null and is_instance_valid(b) and b.player != null and is_instance_valid(b.player):
			pids.append(b.player.player_id)
	var hu: Player = map.squad.human()
	if hu != null and is_instance_valid(hu) and not pids.has(hu.player_id):
		pids.append(hu.player_id)
	for pid: Variant in pids:
		var p: Player = map.squad.player_by_id(int(pid))
		if p == null:
			continue
		var r: Dictionary = _r(int(pid))
		var b2: BotBrain = null
		for bb: BotBrain in map.squad.brains:
			if bb.player == p:
				b2 = bb
		var guns: PackedStringArray = []
		var ammo: float = 0.0
		var best_tier: int = -1
		if p.weapons != null:
			for w: WeaponInstance in p.weapons.slots:
				guns.append("%s%s" % [str(w.id), ("+%d" % w.tier) if w.upgraded else ""])
				if w.weapon_class() != &"pistol":
					ammo = maxf(ammo, float(w.mag + w.reserve) / float(maxi(1, w.mag_size() + w.reserve_max())))
					best_tier = maxi(best_tier, w.tier if w.upgraded else 0)
		var shots: int = b2.aim.shots if b2 != null and b2.aim != null else 0
		var hits: int = b2.aim.hits_landed if b2 != null and b2.aim != null else 0
		var acts: Dictionary = r["acts"]
		var act_s: PackedStringArray = []
		var ak: Array = acts.keys()
		ak.sort_custom(func(a: Variant, c: Variant) -> bool: return float(acts[a]) > float(acts[c]))
		for a2: Variant in ak:
			act_s.append("%s %.0f" % [str(a2), float(acts[a2])])
		var by: Dictionary = r["dmg_by"]
		var by_s: PackedStringArray = []
		for k: Variant in by.keys():
			by_s.append("%s %.0f" % [str(k), float(by[k])])
		round_rows.append({"round": _round, "secs": secs, "pid": int(pid), "name": Net.display_name(int(pid)), "bot": p.is_bot, "companion": p.is_companion,
			"kills": int(r["kills"]), "downs": int(r["downs"]), "revives": int(r["revives"]), "revived": int(r["revived"]), "up_s": float(r["up_s"]), "down_s": float(r["down_s"]),
			"dmg": float(r["dmg"]), "dmg_by": "; ".join(by_s), "shots": shots - int(_shots0.get(pid, 0)), "hits": hits - int(_hits0.get(pid, 0)),
			"guns": " ".join(guns), "gun_tier": best_tier, "perks": PerkManager.owned(int(pid)).size(),
			"perk_ids": " ".join(PackedStringArray(PerkManager.owned(int(pid)).map(func(x: Variant) -> String: return str(x)))),
			"scrip": Economy.get_scrip(int(pid)), "ammo": ammo, "press_s": float(r["press_s"]), "still_press_s": float(r["still_press_s"]),
			"n3_s": float(r["n3_s"]), "empty_s": float(r["empty_s"]), "moved": float(r["moved"]), "acts": "; ".join(act_s), "zhp": RoundManager.current_health()})
		_shots0[pid] = shots
		_hits0[pid] = hits
	_rs.clear()


# ================================================================== the report

## Ends the census: closes what is open, writes the files, prints the hot spots. Returns the summary.
func finish() -> Dictionary:
	for k: Variant in _open.keys().duplicate():
		_close(str(k))
	_close_round()
	var hours: float = maxf(bot_seconds / 3600.0, 0.0001)
	var by_kind: Dictionary = {}
	var secs: float = 0.0
	for e: Dictionary in episodes:
		_bump(by_kind, str(e["kind"]))
		secs += float(e["dur"])
	var hot: Array[Dictionary] = cluster(episodes)
	var sm: Dictionary = {"bot_hours": hours, "episodes": episodes.size(), "episodes_per_hour": float(episodes.size()) / hours, "stuck_s_per_hour": secs / hours, "by_kind": by_kind}
	print("[census] %.2f bot-hours | %d stuck episodes (%.1f per bot-hour, %.0f s per bot-hour) | %s" % [hours, episodes.size(), float(sm["episodes_per_hour"]), float(sm["stuck_s_per_hour"]), str(by_kind)])
	var lines: PackedStringArray = []
	lines.append("| # | cell centre (x, y, z) | zone | episodes | seconds | kinds | pressed against | action/task | who |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for i: int in mini(25, hot.size()):
		var c: Dictionary = hot[i]
		var ctr: Vector3 = c["center"]
		lines.append("| %d | %.1f, %.1f, %.1f | %s | %d | %.0f | %s | %s | %s | %s |" % [i + 1, ctr.x, ctr.y, ctr.z, str(c["zone"]), int(c["n"]), float(c["secs"]),
			_top(c["kinds"], 3), _top(c["against"], 2), _top(c["what"], 2), _top(c["who"], 3)])
	for l: String in lines:
		print("[census] ", l)
	if stem != "":
		var f: FileAccess = FileAccess.open(stem + "_stuck.jsonl", FileAccess.WRITE)
		if f != null:
			for e2: Dictionary in episodes:
				var d: Dictionary = e2.duplicate()
				for k2: String in ["pos", "goal"]:
					var v: Vector3 = d[k2]
					d[k2] = [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)] if v.is_finite() else []
				for k3: Variant in d.keys():
					if d[k3] is float:
						d[k3] = snappedf(float(d[k3]), 0.01) if is_finite(float(d[k3])) else -1.0
				f.store_line(JSON.stringify(d))
			f.close()
		var m: FileAccess = FileAccess.open(stem + "_hotspots.md", FileAccess.WRITE)
		if m != null:
			m.store_line("%.2f bot-hours, %d episodes (%.1f per bot-hour), %.0f stuck seconds per bot-hour, by kind %s" % [hours, episodes.size(), float(sm["episodes_per_hour"]), float(sm["stuck_s_per_hour"]), str(by_kind)])
			m.store_line("")
			for l2: String in lines:
				m.store_line(l2)
			m.store_line("")
			for l3: String in round_table():
				m.store_line(l3)
			m.close()
		_write_rounds(stem + "_rounds.csv")
		_plot(stem)
	for l4: String in round_table():
		print("[census] ", l4)
	return sm


## The squad's table per round (the bots proper, not the companions): kills share, downs, standing share, the guns.
func round_table() -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("| round | s | zombie hp | squad kills | all kills | bot share | bot downs | bot revives | standing | dmg taken | hit share | still under pressure | best gun tier (mean) | tonics (mean) | Scrip (mean) |")
	out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var rounds: Dictionary = {}
	for r: Dictionary in round_rows:
		var k: int = int(r["round"])
		if not rounds.has(k):
			rounds[k] = {"secs": float(r["secs"]), "zhp": int(r["zhp"]), "bk": 0, "all": 0, "downs": 0, "rev": 0, "up": 0.0, "tot": 0.0, "dmg": 0.0, "shots": 0, "hits": 0, "still": 0.0, "press": 0.0, "tier": 0.0, "perks": 0.0, "scrip": 0.0, "n": 0}
		var a: Dictionary = rounds[k]
		a["all"] = int(a["all"]) + int(r["kills"])
		if bool(r["bot"]) and not bool(r["companion"]):
			a["bk"] = int(a["bk"]) + int(r["kills"])
			a["downs"] = int(a["downs"]) + int(r["downs"])
			a["rev"] = int(a["rev"]) + int(r["revives"])
			a["up"] = float(a["up"]) + float(r["up_s"])
			a["tot"] = float(a["tot"]) + float(r["up_s"]) + float(r["down_s"])
			a["dmg"] = float(a["dmg"]) + float(r["dmg"])
			a["shots"] = int(a["shots"]) + int(r["shots"])
			a["hits"] = int(a["hits"]) + int(r["hits"])
			a["still"] = float(a["still"]) + float(r["still_press_s"])
			a["press"] = float(a["press"]) + float(r["press_s"])
			a["tier"] = float(a["tier"]) + float(r["gun_tier"])
			a["perks"] = float(a["perks"]) + float(r["perks"])
			a["scrip"] = float(a["scrip"]) + float(r["scrip"])
			a["n"] = int(a["n"]) + 1
	var ks: Array = rounds.keys()
	ks.sort()
	for k2: Variant in ks:
		var a2: Dictionary = rounds[k2]
		var n: float = maxf(1.0, float(a2["n"]))
		out.append("| %d | %.0f | %d | %d | %d | %.0f%% | %d | %d | %.0f%% | %.0f | %.0f%% | %.0f%% | %.1f | %.1f | %.0f |" % [int(k2), float(a2["secs"]), int(a2["zhp"]), int(a2["bk"]), int(a2["all"]),
			100.0 * float(a2["bk"]) / maxf(1.0, float(a2["all"])), int(a2["downs"]), int(a2["rev"]), 100.0 * float(a2["up"]) / maxf(1.0, float(a2["tot"])), float(a2["dmg"]),
			100.0 * float(a2["hits"]) / maxf(1.0, float(a2["shots"])), 100.0 * float(a2["still"]) / maxf(1.0, float(a2["press"])), float(a2["tier"]) / n, float(a2["perks"]) / n, float(a2["scrip"]) / n])
	return out


func _write_rounds(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null or round_rows.is_empty():
		return
	var keys: Array = round_rows[0].keys()
	f.store_line(",".join(PackedStringArray(keys.map(func(k: Variant) -> String: return str(k)))))
	for r: Dictionary in round_rows:
		var cells: PackedStringArray = []
		for k2: Variant in keys:
			var v: Variant = r[k2]
			var s: String = ("%.2f" % float(v)) if v is float else str(v)
			cells.append("\"" + s.replace("\"", "'") + "\"" if s.contains(",") else s)
		f.store_line(",".join(cells))
	f.close()


## Top-down plots, one per storey that has episodes: the walkable navmesh in grey, every episode a dot (red noprog,
## orange osc, blue nopath, purple parked) whose size grows with its seconds. 1 px = 0.1 m.
func _plot(out_stem: String) -> void:
	if episodes.is_empty() or map == null or not is_instance_valid(map):
		return
	var polys: Array = []
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = Vector3(-INF, -INF, -INF)
	for n: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var nr: NavigationRegion3D = n as NavigationRegion3D
		if nr == null or nr.navigation_mesh == null:
			continue
		var nm: NavigationMesh = nr.navigation_mesh
		var vs: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var poly: PackedVector3Array = PackedVector3Array()
			for vi: int in nm.get_polygon(i):
				var v: Vector3 = nr.global_transform * vs[vi]
				poly.append(v)
				lo = lo.min(v)
				hi = hi.max(v)
			polys.append(poly)
	if polys.is_empty():
		return
	var scale: float = 10.0
	var wpx: int = clampi(int((hi.x - lo.x) * scale) + 40, 64, 4096)
	var hpx: int = clampi(int((hi.z - lo.z) * scale) + 40, 64, 4096)
	var storeys: Dictionary = {}
	for e: Dictionary in episodes:
		storeys[cell_of(e["pos"]).y] = true
	for st: Variant in storeys.keys():
		var img: Image = Image.create(wpx, hpx, false, Image.FORMAT_RGB8)
		img.fill(Color(0.08, 0.08, 0.09))
		for poly2: PackedVector3Array in polys:
			if poly2.is_empty() or cell_of(poly2[0]).y != int(st):
				continue
			var pts: PackedVector2Array = PackedVector2Array()
			for v2: Vector3 in poly2:
				pts.append(Vector2((v2.x - lo.x) * scale + 20.0, (v2.z - lo.z) * scale + 20.0))
			_fill_poly(img, pts, Color(0.32, 0.33, 0.35))
		for e2: Dictionary in episodes:
			var p: Vector3 = e2["pos"]
			if cell_of(p).y != int(st):
				continue
			var col: Color = {"noprog": Color(1.0, 0.2, 0.15), "osc": Color(1.0, 0.65, 0.1), "nopath": Color(0.3, 0.6, 1.0), "parked": Color(0.75, 0.35, 1.0)}.get(str(e2["kind"]), Color.WHITE)
			var rad: int = clampi(2 + int(sqrt(float(e2["dur"]))), 3, 14)
			var cx: int = int((p.x - lo.x) * scale + 20.0)
			var cy: int = int((p.z - lo.z) * scale + 20.0)
			for dy: int in range(-rad, rad + 1):
				for dx: int in range(-rad, rad + 1):
					if dx * dx + dy * dy <= rad * rad and cx + dx >= 0 and cx + dx < wpx and cy + dy >= 0 and cy + dy < hpx:
						img.set_pixel(cx + dx, cy + dy, col)
		img.save_png("%s_storey%d.png" % [out_stem, int(st)])


static func _fill_poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var y0: int = img.get_height()
	var y1: int = 0
	for p: Vector2 in pts:
		y0 = mini(y0, int(floor(p.y)))
		y1 = maxi(y1, int(ceil(p.y)))
	for y: int in range(maxi(0, y0), mini(img.get_height(), y1 + 1)):
		var xs: Array[float] = []
		var fy: float = float(y) + 0.5
		for i: int in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k: int in range(0, xs.size() - 1, 2):
			for x: int in range(maxi(0, int(xs[k])), mini(img.get_width(), int(ceil(xs[k + 1])))):
				# a 1 px dark seam between polygons keeps the mesh readable
				img.set_pixel(x, y, col if (x != int(xs[k]) and y != y0) else col.darkened(0.25))
