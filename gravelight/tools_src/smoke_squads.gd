extends Node
## T-142 (UPDATE 09 section 4): headless smoke for the relief squads on Map 0 with three bots. Round 4 with a squad
## forced (six Home Army soldiers, a short stay, every leaver overrun so a rise is certain); asserts the soldiers spawn
## on the navmesh, shoot, at least one dies and rises as a zombie in its own clothes (no Marke: the Home Army is not
## marked), loot appears, the round still ends after the rise, and a boss fight starting mid-squad despawns it.
## Performance: with six soldiers, 24 zombies and three bots, the soldiers' brains (and the bots' brains, for the
## total) per 60 Hz physics frame; the soldiers' share must stay under 2.5 ms (both printed).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_squads.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const LIMIT_S: float = 420.0
const PERF_FRAMES: int = 300
const BUDGET_MS: float = 2.5

var _map: MapRoot
var _t: float = 0.0
var _frames: int = 0
var _fails: PackedStringArray = []
var _done: bool = false
var _rs: ReliefSquad = null
var _arrived_t: float = -1.0
var _spawn_checked: bool = false
var _rise_t: float = -1.0
var _ended_after_rise: bool = false
var _perf_start: int = -1
var _perf_frames: int = 0
var _perf_soldier_us: int = 0
var _perf_soldier_max: int = 0
var _perf_bot_us0: float = 0.0
var _perf_bot_frames0: int = 0
var _perf_living: int = 0
var _perf_zombies: int = 0
var _perf_result: Dictionary = {}
var _phase_b: int = 0
var _lost_signals: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_squads_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	var g: Dictionary = GLData.table("squads")["global"]
	g["size"] = [6, 6]
	g["stay_seconds"] = [35.0, 35.0]
	g["survivor_chance"] = 0.0
	g["overrun_bias"] = 1.0
	g["rise_delay_s"] = [4.0, 5.0]
	g["chance_per_round"] = 0.0   # only the forced squad
	(g["loot"] as Dictionary)["weapon_chance"] = 1.0
	(g["loot"] as Dictionary)["grenade_chance"] = 1.0
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.squad_arrived.connect(func(id: int, f: StringName) -> void:
		print("[squads] arrived: squad %d (%s) at t=%.0fs" % [id, f, _t])
		if _arrived_t < 0.0:
			_arrived_t = _t)
	GLBus.squad_lost.connect(func(id: int) -> void:
		_lost_signals += 1
		print("[squads] squad %d lost at t=%.0fs" % [id, _t]))
	GLBus.round_ended.connect(func(r: int) -> void:
		print("[squads] round %d ended at t=%.0fs (rises so far %d)" % [r, _t, int(_rs.stats["rises"]) if _rs != null else 0])
		if _rise_t >= 0.0:
			_ended_after_rise = true)
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		print("[squads] round %d started at t=%.0fs" % [r, _t]))


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree() or _done:
		return
	_frames += 1
	_t += delta
	if _frames == 60:
		_rs = ReliefSquad.instance(get_tree())
		if _rs == null:
			_fail("no ReliefSquad on the map")
			_finish()
			return
		_rs.force_next = true
		_rs.force_faction = "ak"
		RoundManager.debug_set_round(4)
	if _rs == null:
		return
	if _arrived_t >= 0.0 and not _spawn_checked and _t > _arrived_t + 0.2:
		_spawn_checked = true
		_check_spawn()
	_perf_tick()
	if _rise_t < 0.0 and int(_rs.stats["rises"]) > 0:
		_rise_t = _t
		_check_rise()
	if _phase_b == 0 and _ended_after_rise and _perf_frames >= PERF_FRAMES:
		_phase_b = 1
		_event_despawn_check()
	if _phase_b == 2 or _t > LIMIT_S:
		_finish()


func _check_spawn() -> void:
	var nav: RID = _map.get_world_3d().navigation_map
	var n: int = 0
	for s: Soldier in _rs.soldiers:
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, s.global_position)
		var d: float = Vector2(c.x - s.global_position.x, c.z - s.global_position.z).length()
		if d > 1.0:
			_fail("soldier %s off the navmesh (%.2f m)" % [s.name, d])
		n += 1
	print("[squads] %d soldiers in, all on the navmesh; actor budget %d (max_active %d, soldiers %d)" % [n, _map.director.actor_budget(),
		RoundManager.max_active(), _map.director.soldiers_alive])
	if n != 6:
		_fail("expected 6 soldiers, got %d" % n)
	if _map.director.actor_budget() != RoundManager.max_active() - 6:
		_fail("budget not reduced by the soldiers")


## Six soldiers + 24 zombies + 3 bots for PERF_FRAMES frames: tops the zombies up to 24 active, then sums the brains.
func _perf_tick() -> void:
	if _perf_start < 0:
		if _arrived_t >= 0.0 and _t > _arrived_t + 6.0 and _rs.living() >= 6:
			var need: int = 24 - _map.director.active_zombies().size()
			if need > 0:
				_map.director.debug_spawn(need)
			_perf_start = _frames
			_perf_bot_us0 = _bot_us()
			_perf_bot_frames0 = _bot_frames()
		return
	if _perf_frames >= PERF_FRAMES:
		return
	_perf_frames += 1
	_perf_soldier_us += _rs.brain_us
	_perf_soldier_max = maxi(_perf_soldier_max, _rs.brain_us)
	_perf_living += _rs.living()
	_perf_zombies += _map.director.active_zombies().size()
	if _perf_frames == PERF_FRAMES:
		var bots_ms: float = 0.0
		var bf: int = _bot_frames() - _perf_bot_frames0
		var nb: int = _map.squad.brains.size() if _map.squad != null else 0
		if bf > 0 and nb > 0:
			bots_ms = (_bot_us() - _perf_bot_us0) / 1000.0 / (float(bf) / float(nb))
		var sol_ms: float = float(_perf_soldier_us) / 1000.0 / float(PERF_FRAMES)
		_perf_result = {"soldier_ms": sol_ms, "soldier_max_ms": float(_perf_soldier_max) / 1000.0, "bots_ms": bots_ms,
			"total_ms": sol_ms + bots_ms, "soldiers": float(_perf_living) / PERF_FRAMES, "zombies": float(_perf_zombies) / PERF_FRAMES, "bots": nb}
		print("[squads] PERF brains per frame over %d frames: soldiers %.3f ms (max %.3f), bots %.3f ms, total %.3f ms (avg %.1f soldiers, %.1f zombies, %d bots)" % [
			PERF_FRAMES, sol_ms, _perf_result["soldier_max_ms"], bots_ms, sol_ms + bots_ms, _perf_result["soldiers"], _perf_result["zombies"], nb])
		if sol_ms >= BUDGET_MS:
			_fail("soldier brains %.3f ms per frame (budget %.1f)" % [sol_ms, BUDGET_MS])


func _bot_us() -> float:
	var s: float = 0.0
	if _map.squad != null:
		for b: BotBrain in _map.squad.brains:
			s += b.us_total
	return s


func _bot_frames() -> int:
	var s: int = 0
	if _map.squad != null:
		for b: BotBrain in _map.squad.brains:
			s += b.frames
	return s


func _check_rise() -> void:
	var z: Zombie = _rs.risen[0] if not _rs.risen.is_empty() else null
	if z == null or not z.is_active():
		_fail("the risen soldier is not an active zombie")
		return
	var tag: String = str(z.get_meta("person", ""))
	if not SoldierKits.is_tag(tag):
		_fail("the risen zombie is not dressed as the soldier (%s)" % tag)
	if z.marke_site != &"":
		_fail("a Home Army soldier rose with a Marke (%s)" % z.marke_site)
	print("[squads] first rise at t=%.0fs: %s, Marke '%s', alive count %d" % [_t, tag, z.marke_site, RoundManager.alive])


func _event_despawn_check() -> void:
	# a second squad, then a boss fight starts: it must go cleanly
	await get_tree().create_timer(1.0).timeout
	while _rs.active():
		_rs.despawn_all("smoke")
		await get_tree().physics_frame
	var n: int = _rs.spawn_squad("sov")
	await get_tree().physics_frame
	if n <= 0:
		_fail("no second squad for the despawn check")
	GameState.set_flag(&"boss_fight", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _rs.active() or _map.director.soldiers_alive != 0 or not get_tree().get_nodes_in_group(&"soldiers").is_empty() and _alive_soldier_nodes() > 0:
		_fail("a boss fight did not despawn the squad")
	else:
		print("[squads] a boss fight despawned squad %d cleanly" % _rs.squad_id)
	GameState.set_flag(&"boss_fight", false)
	_phase_b = 2


func _alive_soldier_nodes() -> int:
	var n: int = 0
	for s: Node in get_tree().get_nodes_in_group(&"soldiers"):
		if not s.is_queued_for_deletion():
			n += 1
	return n


func _fail(why: String) -> void:
	_fails.append(why)
	print("[squads] FAIL: " + why)


func _finish() -> void:
	if _done:
		return
	_done = true
	var st: Dictionary = _rs.stats if _rs != null else {}
	if _arrived_t < 0.0:
		_fail("no squad arrived")
	if int(st.get("shots", 0)) <= 0:
		_fail("the soldiers never fired")
	if int(st.get("deaths", 0)) <= 0:
		_fail("no soldier died")
	if int(st.get("rises", 0)) <= 0:
		_fail("no soldier rose")
	if int(st.get("loot", 0)) <= 0:
		_fail("no loot dropped")
	if not _ended_after_rise:
		_fail("no round ended after the rise")
	if _perf_result.is_empty():
		_fail("the performance window never ran")
	print("[squads] stats %s, lost signals %d" % [str(st), _lost_signals])
	print("[squads] RESULT: %s | brains %.3f ms/frame (soldiers %.3f + bots %.3f) | shots %d deaths %d rises %d loot %d scrip %d" % [
		"PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)],
		float(_perf_result.get("total_ms", -1.0)), float(_perf_result.get("soldier_ms", -1.0)), float(_perf_result.get("bots_ms", -1.0)),
		int(st.get("shots", 0)), int(st.get("deaths", 0)), int(st.get("rises", 0)), int(st.get("loot", 0)), int(st.get("scrip_paid", 0))])
	get_tree().quit(0 if _fails.is_empty() else 1)
