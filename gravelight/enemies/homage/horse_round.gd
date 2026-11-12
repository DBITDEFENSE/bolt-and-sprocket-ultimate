class_name HorseRound
extends HomageEncounter
## The round director for an undead horse (T-240; the owner: "add boss zombie horses on round 20 and 30"). One node
## per row of the map's json "round_bosses": [{"round": 20, "boss": "totenross", "count": 1}, ...]; the map's
## "round_boss_arena" says where a horse may go ({"zones": [...], "arrive": [[x, y, z], ...], "exit": [x, y, z]}).
## A map without the row has none (one data line turns it on). MapRoot attaches them (HorseRound.attach).
## It is a HomageEncounter (the shape PAUL's and THE SLENDER's rounds have), so the boss round works as theirs do:
##   - the round is reserved (no Bellringer round, no Foreman on it; if one sits there the horse moves +1);
##   - the horde keeps coming at `horde_fraction` of the round's count, and the horse holds the round open as a
##     reserved slot until it dies or leaves;
##   - it is announced by sound first: hooves far off down the road, then the scream; it comes in `spawn_at` seconds
##     after the round starts, at a gallop from the map's arrival point (a closed gate on its way is broken open);
##   - bots alone: the same scaling switch as the other bosses' (the block's `bots_alone`);
##   - the fail-safe: `failsafe_seconds` after it came in it bolts back the way it came, and returns `return_after`
##     rounds later until it is killed;
##   - a kill pays the block's rewards (Scrip each, drops where it fell), as PAUL's does.
## Host / solo only (a co-op client sees the framework's generic puppet, as with every homage boss).

var row: Dictionary = {}
var arena: Dictionary = {}
var count: int = 1
var bosses: Array[HorseBoss] = []
var dead: int = 0
var card_shown: bool = false
var arrivals: int = 0
var kills: int = 0
var drops_spawned: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The map's rows: [{round, boss, count}] ([] when the map has none or the file is missing).
static func rows_for(map_id: StringName) -> Array:
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return []
	var v: Variant = GLData.load_json(path).get("round_bosses", [])
	return v if v is Array else []


static func arena_for(map_id: StringName) -> Dictionary:
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return {}
	var v: Variant = GLData.load_json(path).get("round_boss_arena", {})
	return v if v is Dictionary else {}


## A row is good when it names a known horse and a round past the first.
static func row_ok(r: Dictionary) -> bool:
	return int(r.get("round", 0)) > 1 and int(r.get("count", 1)) >= 1 and not HorseBoss.block_of(str(r.get("boss", ""))).is_empty()


## One director per good row under `map` (host / solo). Returns them.
static func attach(map: Node) -> Array[HorseRound]:
	var out: Array[HorseRound] = []
	if Net.is_client():
		return out
	var mid: StringName = map.get("map_id") if map.get("map_id") != null else GameState.map_id
	var ar: Dictionary = arena_for(mid)
	for r: Variant in rows_for(mid):
		if not (r is Dictionary) or not row_ok(r):
			continue
		var hr: HorseRound = HorseRound.new()
		hr.row = r
		hr.arena = ar
		hr.count = int((r as Dictionary).get("count", 1))
		hr.boss_id = str((r as Dictionary)["boss"])
		hr.file_key = "bosses/horse"
		hr.fcfg = HorseBoss.table()
		hr.cfg = HorseBoss.block_of(hr.boss_id)
		hr.name = "HorseRound_%d" % int((r as Dictionary)["round"])
		hr.director = map.get("director") as ZombieDirector
		map.add_child(hr)
		out.append(hr)
	return out


func _init() -> void:
	_rng.randomize()


func first_round() -> int:
	return int(row.get("round", cfg.get("round", 20)))


func return_round(r: int) -> int:
	return r + maxi(1, int(cfg.get("return_after", 2)))


func horses() -> Array[HorseBoss]:
	var out: Array[HorseBoss] = []
	for b: HorseBoss in bosses:
		if is_instance_valid(b):
			out.append(b)
	return out


# ================================================================== the arrival

func _begin() -> void:
	var a: Dictionary = cfg.get("arrival", {})
	bosses.clear()
	dead = 0
	card_shown = false
	if count > 1:
		RoundManager.reserve_alive(count - 1)
		reserved_left = count
	var from: Vector3 = arrival_point(0)
	# heard before it is seen: hooves on the road, then the scream
	at(float(a.get("hooves_at", 0.5)), func() -> void:
		if AudioDirector.has_sound("horse_boss_gallop_far"):
			AudioDirector.play_3d("horse_boss_gallop_far", from + Vector3.UP, 6.0, 0.0))
	at(float(a.get("scream_at", 3.5)), func() -> void:
		if AudioDirector.has_sound("horse_boss_scream"):
			AudioDirector.play_3d("horse_boss_scream", from + Vector3.UP * 1.5, 8.0, 0.0))
	at(float(a.get("spawn_at", 6.0)), _spawn_all)


## Where horse `i` comes in: the arena's own points, else the spot in its zones farthest from the squad.
func arrival_point(i: int) -> Vector3:
	var pts: Array = arena.get("arrive", [])
	if not pts.is_empty():
		var p: Array = pts[i % pts.size()]
		return _snap(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return _far_point()


func _far_point() -> Vector3:
	var rid: RID = get_tree().root.get_world_3d().navigation_map if director == null else director.get_world_3d().navigation_map
	var zones: Array = arena.get("zones", [])
	var players: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_alive():
			players.append((n as Player).global_position)
	var best: Vector3 = Vector3.ZERO
	var best_d: float = -1.0
	# on the squad's own level (the arena's centre when it names one): never a deck, a ramp's head or a gallery
	var level: float = float((arena.get("centre", [0, 0, 0]) as Array)[1]) if (arena.get("centre", []) as Array).size() >= 3 else (float((players[0] as Vector3).y) if not players.is_empty() else 0.0)
	for k: int in 80:
		var p: Vector3 = NavigationServer3D.map_get_random_point(rid, director.nav_mask if director != null else 0x7FFFFFFF, true)
		if absf(p.y - level) > 1.0:
			continue
		if not zones.is_empty():
			var z: StringName = ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6)
			if not HorseBoss.may_chase(z, GameState.is_zone_open(z), 0.0, zones):
				continue
		var d: float = INF
		for pp: Variant in players:
			d = minf(d, (pp as Vector3).distance_to(p))
		if players.is_empty():
			d = 20.0
		d = minf(d, 45.0)   # far, not the other end of the world
		if d > best_d:
			best_d = d
			best = p
	if best_d < 0.0 and not players.is_empty():
		best = _snap((players[0] as Vector3) + Vector3(12, 0, 0))
	return best


func _snap(p: Vector3) -> Vector3:
	if director == null:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(director.get_world_3d().navigation_map, p)
	return c if c.distance_to(p) < 3.0 else p


func _spawn_all() -> void:
	for i: int in count:
		_spawn_one(arrival_point(i) + Vector3(2.2 * float(i), 0, 0))
	arrivals += 1


func _spawn_one(at_pos: Vector3) -> HorseBoss:
	var b: HorseBoss = HorseBoss.new()
	b.boss_key = boss_id
	b.name = "HorseBoss_%s_%d" % [boss_id, bosses.size()]
	b.zones = (arena.get("zones", []) as Array).duplicate()
	var ex: Array = arena.get("exit", [])
	if ex.size() >= 3:
		b.exit_point = Vector3(float(ex[0]), float(ex[1]), float(ex[2]))
	elif not (arena.get("arrive", []) as Array).is_empty():
		b.exit_point = at_pos
	var keep: HomageBoss = boss
	adopt(b, HomageEncounter.visit_hp(cfg, RoundManager.players, 0) * (1.0 + 0.15 * float(maxi(0, visits - 1))), at_pos)
	if keep != null and is_instance_valid(keep) and keep.is_active():
		boss = keep   # (the first horse stays the encounter's `boss`: the fail-safe and the squad scaling read it)
	bosses.append(b)
	if bots_alone:
		var m: Array[float] = CousinsRound.squad_mults(true, CousinsRound.bots_alone_cfg(cfg))
		b.set_squad_scale(m[0], m[1], m[2], m[3])
	var to: Vector3 = Vector3.INF
	var c: Array = arena.get("centre", [])
	if c.size() >= 3:
		to = Vector3(float(c[0]), float(c[1]), float(c[2]))
	b.arrive_to(to)
	print("[%s] comes in at %s (hp %d, round %d)" % [boss_id, str(at_pos.snapped(Vector3.ONE * 0.1)), int(b.max_hp), RoundManager.current_round])
	return b


func _show_card(b: HorseBoss) -> void:
	card_shown = true
	spawn_t = t
	if hud != null and is_instance_valid(hud):
		hud.title_card(str(cfg.get("name", "DAS TOTENROSS")), str(cfg.get("small", "")), str(cfg.get("date_line", "24.XII.1944")))
		var i: int = 0
		for h: HorseBoss in horses():
			hud.add_bar("%s_%d" % [boss_id, i], h, str(cfg.get("name", "DAS TOTENROSS")), str(cfg.get("small", "")))
			i += 1


func boss_seconds() -> float:
	return t - spawn_t if card_shown else 0.0


func _tick(_delta: float) -> void:
	if card_shown or bosses.is_empty():
		return
	# the title card when it is close enough to be seen coming, or after a few seconds
	var a: Dictionary = cfg.get("arrival", {})
	var b: HorseBoss = bosses[0]
	if not is_instance_valid(b):
		return
	var near: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).global_position.distance_to(b.global_position) <= float(a.get("card_m", 30.0)):
			near = true
	if near or t - spawn_t >= float(a.get("card_s", 7.0)):
		_show_card(b)


func _apply_squad_scale() -> void:
	var m: Array[float] = CousinsRound.squad_mults(bots_alone, CousinsRound.bots_alone_cfg(cfg))
	for b: HorseBoss in horses():
		if b.is_active():
			b.set_squad_scale(m[0], m[1], m[2], m[3])


# ================================================================== the death, the rewards, the fail-safe

## HomageBoss._boss_die calls this (the hook's name is the Cousins').
func on_cousin_died(b: HomageBoss) -> void:
	var hb: HorseBoss = b as HorseBoss
	if hb == null or not bosses.has(hb):
		return
	dead += 1
	kills += 1
	reserved_left = maxi(0, reserved_left - 1)
	if hud != null and is_instance_valid(hud):
		hud.strike("%s_%d" % [boss_id, bosses.find(hb)], true)
	if dead < bosses.size():
		return
	phase = Phase.CLEARED
	RoundManager.unreserve_round(event_round)
	_on_boss_died_at(hb.global_position)


func _on_boss_died_at(at_pos: Vector3) -> void:
	var rw: Dictionary = cfg.get("rewards", {})
	if str(rw.get("flag", "")) != "":
		GameState.set_flag(StringName(str(rw["flag"])), true)
	var plan: Dictionary = HomageEncounter.reward_plan(cfg, GameState.player_ids)
	grant_plan(plan)
	var i: int = 0
	for d: Variant in plan["drops"]:
		var n: Node3D = PowerupManager.spawn(StringName(str(d)), at_pos + Vector3(1.8 + 0.9 * float(i), 0, 1.4))
		if n != null:
			drops_spawned.append(str(d))
		i += 1
	print("[%s] down: %d Scrip each, drops %s" % [boss_id, int(rw.get("scrip_per_player", 2000)), str(plan["drops"])])


func leave() -> void:
	if phase != Phase.ACTIVE:
		return
	for b: HorseBoss in horses():
		if b != boss and b.is_active():
			b.retreat()
	super.leave()


func _round_over() -> void:
	super._round_over()
	for b: HorseBoss in horses():
		if b.state == Zombie.State.DEAD:
			b.cleanup()


# ================================================================== tools

## Dev / capture: a horse standing still at (x, y, z) facing `yaw` degrees in a pose (HorseBoss.debug_pose), with the
## title card and its bar. CaptureDo: "callv:HorseRound_20:pose:18,0,41,180,rear:3".
func pose(x: float, y: float, z: float, yaw: float = 180.0, pose_name: String = "") -> HorseBoss:
	if director == null:
		return null
	if hud == null or not is_instance_valid(hud):
		hud = BossHud.new()
		_map().add_child(hud)
	for old: HorseBoss in horses():
		old.cleanup()
	bosses.clear()
	var b: HorseBoss = HorseBoss.new()
	b.boss_key = boss_id
	b.name = "HorseBoss_%s_pose" % boss_id
	adopt(b, HomageEncounter.visit_hp(cfg, RoundManager.players, 0), Vector3(x, y, z))
	bosses.append(b)
	b.debug_pose(yaw, pose_name)
	_show_card(b)
	print("[%s] posed at %s (yaw %.0f, %s)" % [boss_id, str(b.global_position.snapped(Vector3.ONE * 0.1)), yaw, pose_name])
	return b
