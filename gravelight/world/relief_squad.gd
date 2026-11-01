class_name ReliefSquad
extends Node
## T-142 (UPDATE 09 section 4, contract C5; data/gravelight/squads.json; docs/gravelight/BOT_AI.md "Relief squads"):
## a living war at the edge of the map. At each round start (host / offline) the event rolls (roll_allowed + chance):
## never before from_round, never with a squad still active (max_active), never within cooldown_rounds of the last
## arrival, never in a special round, never while GameState says boss_fight / holdout / cutscene. A squad of 3-6
## soldiers of one of the map's factions walks in from an edge spawn far from every player, with a bark and the HUD
## line "A relief squad is coming in". It holds near the players for stay_seconds (SoldierBrain), then rolls
## survivor_chance: one soldier stays to the round's end (squad_survivor; a crate at its feet), the others pull out to
## the edge, and each leaver is overrun with overrun_bias (zombies are sent after it and it dies at the edge), so most
## squads are lost (squad_lost when the last one dies). A dead soldier drops loot (an ammo crate, its gun, grenades)
## and rises 4-8 s later as a zombie (ZombieDirector.rise_at; the first rise of a match draws a SQD_RISE line from the
## squad). Kills pay the nearest player scrip_share of the kill value (Economy.award: Double Scrip and Ledger Lager
## apply). Every living soldier holds one actor slot (ZombieDirector.set_soldiers_alive -> RoundManager.actor_reserve).
## A boss fight, holdout or cutscene starting mid-squad despawns it cleanly (no rises, no loot).

const BARK_SPEAKER: StringName = &"SQD"

static var perf: Dictionary = {"frames": 0, "total_us": 0, "max_us": 0}   # the soldiers' brains per frame (smoke)

var map: MapRoot = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_round: int = -1000
var squad_id: int = 0
var soldiers: Array[Soldier] = []
var faction: Dictionary = {}
var phase: StringName = &"none"          # none | holding | leaving
var stay_left: float = 0.0
var entry_point: Vector3 = Vector3.ZERO
var exit_point: Vector3 = Vector3.ZERO
var force_next: bool = false
var force_faction: String = ""
var zombie_cache: Array[Zombie] = []
var pending_rises: Array[Dictionary] = []
var risen: Array[Zombie] = []
var events: PackedStringArray = []
var stats: Dictionary = {"squads": 0, "lost": 0, "survivors": 0, "escaped": 0, "deaths": 0, "rises": 0, "kills": 0, "scrip_paid": 0, "loot": 0, "shots": 0}
var brain_us: int = 0
var _first_rise_done: bool = false
var _prey_t: float = 0.0
var _contact_said: bool = false
var _escaped: int = 0
var _survived_home: bool = false
var _crate_dropped: bool = false
var _next_net: int = 0


# ================================================================== data (pure, for tests)

static func table() -> Dictionary:
	return GLData.table("squads")


static func cfg() -> Dictionary:
	return table().get("global", {})


## "map00_crossroads" -> "map00", "map04a_thalbach" -> "map04a".
static func map_key(map_id: String) -> String:
	return map_id.split("_")[0]


static func factions_for(mkey: String, tbl: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Variant in ((tbl.get("maps", {}) as Dictionary).get(mkey, {}) as Dictionary).get("factions", []):
		out.append(f as Dictionary)
	return out


static func faction_by_id(mkey: String, fid: String, tbl: Dictionary) -> Dictionary:
	for f: Dictionary in factions_for(mkey, tbl):
		if str(f.get("id", "")) == fid:
			return f
	return {}


static func vec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Whether a squad may be rolled for this round (everything but the chance). `blocked`: a boss fight, holdout or
## cutscene is on (or a special round with skip_special_rounds).
static func roll_allowed(round_number: int, last: int, active: int, blocked: bool, g: Dictionary) -> bool:
	if blocked:
		return false
	if round_number < int(g.get("from_round", 4)):
		return false
	if active >= int(g.get("max_active", 1)):
		return false
	if round_number - last < int(g.get("cooldown_rounds", 3)):
		return false
	return true


## The roll itself (seeded RNG): allowed and the chance came up.
static func roll(round_number: int, last: int, active: int, blocked: bool, g: Dictionary, r: RandomNumberGenerator) -> bool:
	if not roll_allowed(round_number, last, active, blocked, g):
		return false
	return r.randf() < float(g.get("chance_per_round", 0.35))


static func pick_size(g: Dictionary, r: RandomNumberGenerator) -> int:
	var s: Array = g.get("size", [3, 6])
	return r.randi_range(int(s[0]), int(s[1]))


static func pick_stay(g: Dictionary, r: RandomNumberGenerator) -> float:
	var s: Array = g.get("stay_seconds", [60, 150])
	return r.randf_range(float(s[0]), float(s[1]))


static func pick_faction(fs: Array[Dictionary], r: RandomNumberGenerator) -> Dictionary:
	if fs.is_empty():
		return {}
	var total: float = 0.0
	for f: Dictionary in fs:
		total += maxf(0.0, float(f.get("weight", 1.0)))
	var x: float = r.randf() * total
	for f2: Dictionary in fs:
		x -= maxf(0.0, float(f2.get("weight", 1.0)))
		if x <= 0.0:
			return f2
	return fs.back()


## The share of a kill a soldier's kill pays the nearest player (rounded down, at least 1 for a paying kill).
static func scrip_share_of(value: int, g: Dictionary) -> int:
	if value <= 0:
		return 0
	return maxi(1, int(floor(float(value) * float(g.get("scrip_share", 0.25)))))


## True when the event flags (or a special round) keep squads out right now.
static func blocked_now(special: bool, g: Dictionary) -> bool:
	return GameState.in_event() or (special and bool(g.get("skip_special_rounds", true)))


# ================================================================== the event on a map

static func instance(tree: SceneTree) -> ReliefSquad:
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(&"relief_squad"):
		return n as ReliefSquad
	return null


## MapRoot: one event per map on the host (or offline); clients only see puppets (NetMatch).
static func attach(map_root: MapRoot) -> ReliefSquad:
	if map_root == null or not Net.is_authority():
		return null
	var rs: ReliefSquad = ReliefSquad.new()
	rs.name = "ReliefSquad"
	map_root.add_child(rs)
	rs.setup(map_root)
	return rs


func setup(map_root: MapRoot) -> void:
	map = map_root
	add_to_group(&"relief_squad")
	rng.randomize()
	perf = {"frames": 0, "total_us": 0, "max_us": 0}
	if map.director != null:
		map.director.set_soldiers_alive(0)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "squad", _cmd, "squad force|now|status|clear: the relief squads (T-142)")


func map_factions() -> Array[Dictionary]:
	return factions_for(map_key(String(map.map_id)), table())


func active() -> bool:
	return not soldiers.is_empty()


func size() -> int:
	return soldiers.size()


func living() -> int:
	var n: int = 0
	for s: Soldier in soldiers:
		if is_instance_valid(s) and s.is_alive():
			n += 1
	return n


func _on_round_started(r: int, special: bool) -> void:
	_rise_pending(true)
	if active():
		return
	var g: Dictionary = cfg()
	var forced: bool = force_next
	if forced and not GameState.in_event():
		force_next = false
		spawn_squad()
		return
	if roll(r, last_round, 1 if active() else 0, blocked_now(special, g), g, rng):
		spawn_squad()


func _on_round_ended(_r: int) -> void:
	for s: Soldier in soldiers.duplicate():
		if is_instance_valid(s) and s.survivor and s.is_alive():
			_survivor_home(s)


## Brings a squad in now (the roll, a dev command, the smoke). Returns the soldiers made (0: no faction or spawn).
func spawn_squad(fid: String = "") -> int:
	if active():
		return 0
	var fs: Array[Dictionary] = map_factions()
	if fs.is_empty():
		events.append("no_factions")
		return 0
	var want: String = fid if fid != "" else force_faction
	faction = faction_by_id(map_key(String(map.map_id)), want, table()) if want != "" else {}
	if faction.is_empty():
		faction = pick_faction(fs, rng)
	var at: Vector3 = _pick_edge(faction)
	if at == Vector3.INF:
		events.append("no_edge")
		return 0
	var g: Dictionary = cfg()
	squad_id += 1
	last_round = RoundManager.current_round
	entry_point = at
	exit_point = at
	stay_left = pick_stay(g, rng)
	phase = &"holding"
	_contact_said = false
	_escaped = 0
	_survived_home = false
	_crate_dropped = false
	var n: int = pick_size(g, rng)
	var weapons: Array = faction.get("weapons", ["kar98k"])
	var nav: RID = map.get_world_3d().navigation_map
	for i: int in n:
		var s: Soldier = Soldier.new()
		var seed_v: int = rng.randi()
		s.setup(self, i, faction, seed_v, StringName(str(weapons[i % weapons.size()])), true)
		s.net_id = _next_net
		_next_net = (_next_net + 1) % 250
		map.add_child(s)
		var off: Vector3 = Vector3((i % 3) - 1.0, 0, -float(i / 3)) * 1.3
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, at + off)
		s.global_position = (p if p.distance_to(at + off) < 3.0 else at) + Vector3.UP * 0.1
		s.died.connect(_on_soldier_died)
		s.downed.connect(_on_soldier_downed)
		soldiers.append(s)
	_update_budget()
	stats["squads"] = int(stats["squads"]) + 1
	events.append("arrive:%s:%d" % [str(faction.get("id", "")), n])
	GLBus.squad_arrived.emit(squad_id, StringName(str(faction.get("id", ""))))
	var line: String = str(g.get("announce", "A relief squad is coming in"))
	if map.hud != null:
		map.hud.show_banner(line, 3.5)
	if Net.replicating():
		Net.session.soldier_event(-1, &"arrive", [line])
	_bark(soldiers[0], "ARRIVE")
	print("[squads] round %d: %s (%d) in from %s, staying %.0f s" % [RoundManager.current_round, str(faction.get("display", "?")), n, str(at.snapped(Vector3.ONE * 0.1)), stay_left])
	return n


## An edge spawn of the faction at least 20 m from every living player (random among those), else the farthest.
func _pick_edge(fac: Dictionary) -> Vector3:
	var pts: Array[Vector3] = []
	for e: Variant in fac.get("edge_spawns", []):
		pts.append(vec(e))
	if pts.is_empty():
		return Vector3.INF
	var ok: Array[Vector3] = []
	var best: Vector3 = pts[0]
	var best_d: float = -1.0
	for p: Vector3 in pts:
		var dmin: float = INF
		for pl: Player in _players():
			dmin = minf(dmin, flat(p, pl.global_position))
		if dmin >= 20.0:
			ok.append(p)
		if dmin > best_d:
			best_d = dmin
			best = p
	return ok[rng.randi() % ok.size()] if not ok.is_empty() else best


func _players() -> Array[Player]:
	var out: Array[Player] = []
	if map == null:
		return out
	for k: Variant in map.players.keys():
		var p: Player = map.players[k] as Player
		if p != null and is_instance_valid(p) and p.is_alive() and not p.spectating:
			out.append(p)
	return out


# ================================================================== the frame

func _physics_process(delta: float) -> void:
	if pending_rises.size() > 0:
		_tick_rises(delta)
	if not active():
		return
	if GameState.in_event():
		despawn_all("event")
		return
	zombie_cache = map.director.active_zombies() if map.director != null else ([] as Array[Zombie])
	var us: int = 0
	for s: Soldier in soldiers:
		if is_instance_valid(s) and s.brain != null and s.state == Soldier.State.ACTIVE:
			us += s.brain.us_last
	brain_us = us
	perf["frames"] = int(perf["frames"]) + 1
	perf["total_us"] = int(perf["total_us"]) + us
	perf["max_us"] = maxi(int(perf["max_us"]), us)
	_prey_t -= delta
	if _prey_t <= 0.0:
		_prey_t = 0.5
		_hand_out_prey()
	match phase:
		&"holding":
			stay_left -= delta
			if stay_left <= 0.0:
				_pull_out()
		&"leaving":
			_tick_leaving(delta)


## Zombies near a soldier (in a chase or on the way to a window, no prey yet, not a boss) go for it: prey_per_soldier
## while it holds, leave_prey_per_soldier while it pulls out. Down soldiers are still prey.
func _hand_out_prey() -> void:
	var g: Dictionary = cfg()
	var r: float = float(g.get("prey_radius_m", 18.0))
	var hunting: Dictionary = {}
	for z: Zombie in zombie_cache:
		if z.prey != null and is_instance_valid(z.prey):
			hunting[z.prey.get_instance_id()] = int(hunting.get(z.prey.get_instance_id(), 0)) + 1
	for s: Soldier in soldiers:
		if not is_instance_valid(s) or not s.is_catchable():
			continue
		var want: int = int(g.get("leave_prey_per_soldier", 3)) if s.leaving else int(g.get("prey_per_soldier", 1))
		var have: int = int(hunting.get(s.get_instance_id(), 0))
		while have < want:
			var best: Zombie = null
			var bd: float = r
			for z2: Zombie in zombie_cache:
				if z2.prey != null or BotPerception.is_boss(z2) or z2.is_crawler:
					continue
				if z2.state != Zombie.State.CHASE and z2.state != Zombie.State.TO_WINDOW:
					continue
				var d: float = z2.global_position.distance_to(s.global_position)
				if d < bd:
					bd = d
					best = z2
			if best == null:
				break
			if best.window != null:
				best.window.release(best)
				best.window = null
			best.prey = s
			have += 1


func _pull_out() -> void:
	var g: Dictionary = cfg()
	phase = &"leaving"
	exit_point = _far_edge()
	var alive: Array[Soldier] = []
	for s: Soldier in soldiers:
		if is_instance_valid(s) and s.state == Soldier.State.ACTIVE:
			alive.append(s)
	var keep: Soldier = null
	if not alive.is_empty() and rng.randf() < float(g.get("survivor_chance", 0.25)):
		alive.sort_custom(func(a: Soldier, b: Soldier) -> bool: return a.hp > b.hp)
		keep = alive[0]
		keep.survivor = true
		events.append("survivor_pick")
	for s2: Soldier in soldiers:
		if not is_instance_valid(s2) or s2 == keep or not s2.is_alive():
			continue
		s2.leaving = true
		s2.set_meta("doomed", rng.randf() < float(g.get("overrun_bias", 0.8)))
		s2.set_meta("leave_t", float(g.get("leave_timeout_s", 40.0)))
	events.append("leave")
	var speaker: Soldier = alive[1] if alive.size() > 1 and alive[0] == keep else (alive[0] if not alive.is_empty() else null)
	_bark(speaker, "LEAVE")


## The edge spawn farthest from the players' centre (they pull out away from the fight).
func _far_edge() -> Vector3:
	var pts: Array[Vector3] = []
	for e: Variant in faction.get("edge_spawns", []):
		pts.append(vec(e))
	if pts.is_empty():
		return entry_point
	var c: Vector3 = Vector3.ZERO
	var ps: Array[Player] = _players()
	for p: Player in ps:
		c += p.global_position
	if ps.is_empty():
		return pts[0]
	c /= float(ps.size())
	var best: Vector3 = pts[0]
	for p2: Vector3 in pts:
		if flat(p2, c) > flat(best, c):
			best = p2
	return best


func _tick_leaving(delta: float) -> void:
	for s: Soldier in soldiers.duplicate():
		if not is_instance_valid(s) or not s.leaving or not s.is_alive():
			continue
		var lt: float = float(s.get_meta("leave_t", 40.0)) - delta
		s.set_meta("leave_t", lt)
		if flat(s.global_position, exit_point) < 2.5 or lt <= 0.0:
			if bool(s.get_meta("doomed", true)):
				events.append("overrun")
				if s.state == Soldier.State.ACTIVE:
					s.go_down()
				s.die()   # caught at the edge
			else:
				_escape(s)
	_check_done()


func _escape(s: Soldier) -> void:
	_escaped += 1
	stats["escaped"] = int(stats["escaped"]) + 1
	events.append("escaped")
	soldiers.erase(s)
	s.queue_free()
	_update_budget()


func _survivor_home(s: Soldier) -> void:
	stats["survivors"] = int(stats["survivors"]) + 1
	_survived_home = true
	events.append("survivor")
	GLBus.squad_survivor.emit(squad_id, s)
	_bark(s, "SURVIVE")
	if str(cfg().get("survivor_gift", "crate")) == "crate":
		_drop_crate(s.global_position + s.global_basis.z * 1.2)
	soldiers.erase(s)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(s):
			s.queue_free())
	_update_budget()
	_check_done()


func _check_done() -> void:
	for s: Soldier in soldiers:
		if is_instance_valid(s) and s.is_alive():
			return
	# everyone left is dead (their bodies wait for the rise) or gone
	if phase != &"none":
		if _escaped == 0 and not _survived_home:
			stats["lost"] = int(stats["lost"]) + 1
			events.append("lost")
			GLBus.squad_lost.emit(squad_id)
		phase = &"none"
	var still: Array[Soldier] = []
	for s2: Soldier in soldiers:
		if is_instance_valid(s2):
			still.append(s2)
	soldiers = still
	if soldiers.is_empty():
		phase = &"none"


## A boss fight, holdout or cutscene began (or the dev console): every soldier and body goes, nothing rises.
func despawn_all(reason: String = "") -> void:
	for s: Soldier in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	soldiers.clear()
	pending_rises.clear()
	phase = &"none"
	events.append("despawn:" + reason)
	_update_budget()


func _update_budget() -> void:
	if map != null and map.director != null:
		map.director.set_soldiers_alive(living())


# ================================================================== soldiers' events

func _on_soldier_downed(s: Soldier) -> void:
	_update_budget()
	var mate: Soldier = _another(s)
	_bark(mate, "DOWN")


func _on_soldier_died(s: Soldier) -> void:
	stats["deaths"] = int(stats["deaths"]) + 1
	_update_budget()
	_drop_loot(s)
	var rd: Array = cfg().get("rise_delay_s", [4.0, 8.0])
	pending_rises.append({"soldier": s, "pos": s.global_position, "tag": s.tag, "t": rng.randf_range(float(rd[0]), float(rd[1]))})
	if not s.leaving and living() > 0:
		_bark(_another(s), "DOWN")
	_check_done()


func _tick_rises(delta: float) -> void:
	for e: Dictionary in pending_rises:
		e["t"] = float(e["t"]) - delta
	_rise_pending(false)


## Rises every body whose time is up while a round runs (a body that dies in the break waits for the next round).
func _rise_pending(round_start: bool) -> void:
	if RoundManager.state != RoundManager.State.ROUND and not round_start:
		return
	if GameState.in_event() or map == null or map.director == null:
		return
	var keep: Array[Dictionary] = []
	for e: Dictionary in pending_rises:
		if float(e["t"]) > 0.0:
			keep.append(e)
			continue
		var s: Soldier = e.get("soldier") as Soldier
		var z: Zombie = map.director.rise_at(e["pos"] as Vector3, str(e["tag"]))
		if z == null:
			keep.append(e)   # the pool is full: try again in a moment
			e["t"] = 1.0
			continue
		stats["rises"] = int(stats["rises"]) + 1
		risen.append(z)
		events.append("rise")
		if is_instance_valid(s):
			soldiers.erase(s)
			s.queue_free()
		if not _first_rise_done:
			_first_rise_done = true
			get_tree().create_timer(1.0).timeout.connect(func() -> void: GLVO.squad_say("SQD_RISE", 1.0))
	pending_rises = keep


func on_soldier_fired(s: Soldier, _end: Vector3) -> void:
	stats["shots"] = int(stats["shots"]) + 1
	if not _contact_said:
		_contact_said = true
		_bark(s, "CONTACT")


func on_soldier_hurt(s: Soldier) -> void:
	if s.hp > 0.0 and rng.randf() < 0.35:
		_bark(s, "HURT")


func on_revived(_by: Soldier, s: Soldier) -> void:
	events.append("revive")
	_update_budget()
	_bark(s, "HURT")


## A soldier's kill: the nearest player gets scrip_share of what the kill would have paid them (Economy.award).
func on_soldier_kill(s: Soldier, z: Zombie, limb: StringName) -> void:
	stats["kills"] = int(stats["kills"]) + 1
	var p: Player = _nearest_player(s.global_position)
	if p == null:
		return
	var econ: Dictionary = GLData.table("economy")
	var zc: Dictionary = z.get("_cfg") if z.get("_cfg") is Dictionary else {}
	var value: int = Economy.kill_value(limb, false, {"kill": zc["scrip"]}) if zc.has("scrip") else Economy.kill_value(limb, false, econ)
	var share: int = scrip_share_of(value, cfg())
	if share > 0:
		Economy.award(p.player_id, share)
		stats["scrip_paid"] = int(stats["scrip_paid"]) + share


func _nearest_player(at: Vector3) -> Player:
	var best: Player = null
	var bd: float = INF
	for p: Player in _players():
		var d: float = p.global_position.distance_squared_to(at)
		if d < bd:
			bd = d
			best = p
	return best


# ================================================================== helpers the brains use

func leader() -> Soldier:
	for s: Soldier in soldiers:
		if is_instance_valid(s) and s.state == Soldier.State.ACTIVE:
			return s
	return null


## The point a soldier holds around: the living player nearest the squad's leader (else the leader itself).
func anchor_for(s: Soldier) -> Vector3:
	var lead: Soldier = leader()
	var from: Vector3 = lead.global_position if lead != null else s.global_position
	var p: Player = _nearest_player(from)
	return p.global_position if p != null else from


func downed_mate_near(s: Soldier) -> Soldier:
	var best: Soldier = null
	var bd: float = 20.0
	for o: Soldier in soldiers:
		if o == s or not is_instance_valid(o) or o.state != Soldier.State.DOWN:
			continue
		var d: float = o.global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = o
	return best


func zombies_near(p: Vector3, r: float) -> int:
	var n: int = 0
	for z: Zombie in zombie_cache:
		if z.global_position.distance_squared_to(p) < r * r:
			n += 1
	return n


func threat_centre(p: Vector3, r: float) -> Vector3:
	var c: Vector3 = Vector3.ZERO
	var n: int = 0
	for z: Zombie in zombie_cache:
		if z.global_position.distance_squared_to(p) < r * r:
			c += z.global_position
			n += 1
	return c / float(n) if n > 0 else p


func nav_mask() -> int:
	return map.director.nav_mask if map != null and map.director != null else 0xFFFFFFFF


## Leavers marked to be overrun take three times the damage (the pack catches them out in the open).
func damage_taken_mult(s: Soldier) -> float:
	return 3.0 if s.leaving and bool(s.get_meta("doomed", false)) else 1.0


func _another(s: Soldier) -> Soldier:
	for o: Soldier in soldiers:
		if o != s and is_instance_valid(o) and o.state == Soldier.State.ACTIVE:
			return o
	return null


# ================================================================== loot

func _drop_loot(s: Soldier) -> void:
	var l: Dictionary = cfg().get("loot", {})
	var at: Vector3 = s.global_position
	if not _crate_dropped:
		_crate_dropped = true
		_drop_crate(at + Vector3(0.9, 0, 0.4))
	if rng.randf() < float(l.get("weapon_chance", 0.6)):
		var wp: WeaponParcel = WeaponParcel.make(s.weapon_id, 0, 0)
		map.add_child(wp)
		wp.global_position = at + Vector3(-0.6, 0.12, 0.3)
		wp.rotation = Vector3(0.0, rng.randf() * TAU, PI * 0.5)
		wp.build_greybox()
		_loot_spawned(wp, "res://gravelight/world/weapon_parcel.gd", {"weapon_id": s.weapon_id, "for_pid": 0, "from_pid": 0})
		get_tree().create_timer(float(l.get("loot_seconds", 90.0))).timeout.connect(func() -> void:
			if is_instance_valid(wp):
				wp.queue_free())
	if rng.randf() < float(l.get("grenade_chance", 0.4)):
		var gp: SquadPouch = SquadPouch.new()
		gp.grenades = int(l.get("grenades", 2))
		gp.seconds_left = float(l.get("loot_seconds", 90.0))
		map.add_child(gp)
		gp.global_position = at + Vector3(0.3, 0.0, -0.7)
		_loot_spawned(gp, "res://gravelight/world/squad_pouch.gd", {"grenades": gp.grenades})


func _drop_crate(at: Vector3) -> void:
	var l: Dictionary = cfg().get("loot", {})
	var c: SquadCrate = SquadCrate.new()
	c.uses_left = int(l.get("crate_uses", 4))
	c.seconds_left = float(l.get("loot_seconds", 90.0))
	map.add_child(c)
	var nav: RID = map.get_world_3d().navigation_map
	var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, at)
	c.global_position = p if p.distance_to(at) < 3.0 else at
	_loot_spawned(c, "res://gravelight/world/squad_crate.gd", {"uses_left": c.uses_left})


func _loot_spawned(n: Node3D, script_path: String, props: Dictionary) -> void:
	stats["loot"] = int(stats["loot"]) + 1
	events.append("loot:" + n.get_class() + ":" + script_path.get_file())
	if Net.replicating():
		Net.session.spawn_dynamic(n, script_path, props)


# ================================================================== barks

## A faction line (speaker SQD, category <FACTION>_<CAT>: line ids SQD_<FACTION>_<CAT>_NN), heard at the soldier.
func _bark(s: Soldier, cat: String) -> bool:
	var prefix: String = str(faction.get("barks_prefix", ""))
	if prefix == "":
		return false
	var category: String = prefix.trim_prefix("SQD_") + "_" + cat
	events.append("bark:" + category)
	return GLVO.play_category(BARK_SPEAKER, category)


# ================================================================== dev console

func _cmd(a: PackedStringArray) -> String:
	match a[0] if a.size() > 0 else "status":
		"force":
			force_next = true
			if a.size() > 1:
				force_faction = a[1]
			return "squad: forced on the next round"
		"now":
			var n: int = spawn_squad(a[1] if a.size() > 1 else "")
			return "squad: %d soldiers" % n
		"clear":
			despawn_all("console")
	return "squad: %s, %d soldiers (%d living), stay %.0f, last round %d, stats %s" % [phase, soldiers.size(), living(), stay_left, last_round, str(stats)]
