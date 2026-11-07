extends Node
## Headless smoke for T-185: the Kranich launch and the safety net on every map.
##   1. der Kranich (map04b, skip-to-Act-II start): the set pieces that pushed a body built that push up every
##      frame (16 m/s from a 1.6 m/s tilt, 30 m/s from the bomb-bay doors' 5 m/s, 27 m/s from a decompression) and
##      threw it up whatever low edge it met. Each one is run with the human standing in it (and the bots during a
##      tilt): the speed stays the push plus a walk, the body never rises. Fails on master, passes with T-185.
##   2. the safety net on map00, map01, map02, map04d, map04b: the human put far over the ceiling, beyond the
##      edge, under the floor, (map04b) on the invisible deck outside the hull and a bot put in the sky: each comes
##      back down once, onto the navmesh, unhurt, not downed, still. Map 4 Act IV: a launch plate's arc and the
##      low-gravity jumps are never rescued.
##   3. no false rescues: a short bot match on map00 and on map04b (rounds running, tilts on the flight clock) ends
##      with no rescue at all.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_bounds.tscn
## Prints "[bounds-smoke] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAPS: Array = [
	["map00", "res://gravelight/maps/map00_crossroads/map00.tscn"],
	["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"],
	["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn"],
	["map04d", "res://gravelight/maps/map04_fernflug/map04d.tscn"],
	["map04b", "res://gravelight/maps/map04_fernflug/map04b.tscn"],
]
const TIMEOUT: float = 1500.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _map: Node3D = null
var _p: Player = null
var _watch: bool = false
var _max_h: Dictionary = {}     # pid -> top horizontal speed while _watch
var _max_rise: Dictionary = {}  # pid -> top height over the start while _watch
var _y0: Dictionary = {}
var _last: Dictionary = {}   # pid -> last frame's position


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_bounds.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_bounds_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GLSettings.values["bot_ee_help"] = "off"
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.god_mode = true
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


func _physics_process(_d: float) -> void:
	if not _watch or _map == null or not is_instance_valid(_map):
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not (p.is_local or p.is_bot):
			continue
		var pid: int = p.player_id
		# the body's real speed (its own velocity plus any push), from where it went this frame; a teleport is skipped
		var was: Vector3 = _last.get(pid, p.global_position)
		var step: Vector3 = p.global_position - was
		_last[pid] = p.global_position
		if step.length() < 2.0:
			_max_h[pid] = maxf(float(_max_h.get(pid, 0.0)), Vector2(step.x, step.z).length() / maxf(0.001, _d))
		if _y0.has(pid):
			_max_rise[pid] = maxf(float(_max_rise.get(pid, -99.0)), p.global_position.y - float(_y0[pid]))


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _check(cond: bool, what: String) -> void:
	print("[bounds-smoke] %-86s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


## The map's BoundsGuard, untyped (this smoke also runs on a tree without the class: master, to show the old launch).
func _guard() -> Variant:
	return get_tree().get_first_node_in_group(&"bounds_guard")


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_bot and not p.is_companion:
			out.append(p)
	return out


func _load(key: String, path: String) -> void:
	if _map != null and is_instance_valid(_map):
		get_tree().current_scene = null
		_map.queue_free()
		await _frames(10)
	Campaign.active = false
	if key == "map04b":
		Campaign.begin_at(&"map04b_kranich", 15, Campaign.arrival_kit(&"map04b_kranich"))
		Campaign.cutscene_speed = 12.0
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _frames(60)
	_p = _map.get_node("Player1") as Player
	GameState.god_mode = true
	await _until(func() -> bool: return _guard() != null and _guard().ready_done, 5.0)


func _watch_start() -> void:
	_max_h.clear()
	_max_rise.clear()
	_y0.clear()
	_last.clear()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null:
			_y0[p.player_id] = p.global_position.y
	_watch = true


func _stand(at: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = at
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(20)


# ---------------------------------------------------------------- 1. the Kranich's set pieces

func _kranich_pushes() -> void:
	RoundManager.stop()
	var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
	_check(fc != null, "map04b: the FlightController is there")
	if fc == null:
		return
	# the tilt, standing in the centre body (and the bots wherever they are)
	await _stand(Vector3(0, 0.05, 36))
	for b: Player in _bots():
		b.global_position = Vector3(-2.0 + 1.5 * float(b.player_id), 0.05, 33.0)
		b.velocity = Vector3.ZERO
	await _frames(10)
	_watch_start()
	fc.call("bank_now")
	await _secs(6.5)
	_watch = false
	var push: float = float(((fc.get("cfg") as Dictionary).get("turbulence_tilt", {}) as Dictionary).get("player_push_mps", 1.6))
	_check(float(_max_h.get(1, 99.0)) < push + 1.0, "a tilt: the human drifts at the tilt's push (top %.1f m/s, push %.1f; was ~16)" % [float(_max_h.get(1, 99.0)), push])
	_check(float(_max_rise.get(1, 99.0)) < 0.5, "a tilt: the human never leaves the deck (rose %.2f m)" % float(_max_rise.get(1, 99.0)))
	var bot_top: float = 0.0
	var bot_rise: float = 0.0
	for b2: Player in _bots():
		bot_top = maxf(bot_top, float(_max_h.get(b2.player_id, 0.0)))
		bot_rise = maxf(bot_rise, float(_max_rise.get(b2.player_id, 0.0)))
	_check(bot_top < 9.5 and bot_rise < 1.2, "a tilt: the bots keep their own pace (top %.1f m/s, rose %.2f m)" % [bot_top, bot_rise])
	# the bomb-bay doors, standing on them
	var bd: Node = get_tree().get_first_node_in_group(&"bay_doors")
	_check(bd != null, "map04b: the bomb-bay doors trap is there")
	if bd != null:
		bd.set("cooldown_left", 0.0)
		await _stand(Vector3(0.5, 0.05, 12))
		_watch_start()
		var ok: bool = bool(bd.call("activate", 1))
		await _secs(float(TrapLever.cfg_for("bay_doors").get("warn_seconds", 3.0)) + 3.0)
		_watch = false
		var dpush: float = float(TrapLever.cfg_for("bay_doors").get("push_mps", 5.0))
		_check(ok and float(_max_h.get(1, 99.0)) < dpush + 1.0, "the bomb-bay doors throw the human to the side at their push (top %.1f m/s, push %.1f; was ~30)" % [float(_max_h.get(1, 99.0)), dpush])
		_check(float(_max_rise.get(1, 99.0)) < 0.5, "and never up (rose %.2f m)" % float(_max_rise.get(1, 99.0)))
	# a decompression, standing 4 m from the bay's breach
	for dc: Node in get_tree().get_nodes_in_group(&"decompressions"):
		if str(dc.name) != "DecompBay":
			continue
		await _stand((dc as Node3D).global_position + Vector3(0, 0.05, 4.0))
		_watch_start()
		dc.call("start")
		await _secs(float((dc.get("cfg") as Dictionary).get("warn_s", 3.0)) + 2.5)
		_watch = false
		var pull: float = float((dc.get("cfg") as Dictionary).get("pull_mps", 6.0))
		_check(float(_max_h.get(1, 99.0)) < pull + 1.0, "a decompression pulls the human at its pull (top %.1f m/s, pull %.1f; was ~27)" % [float(_max_h.get(1, 99.0)), pull])
		_check(float(_max_rise.get(1, 99.0)) < 0.5, "and never up (rose %.2f m)" % float(_max_rise.get(1, 99.0)))
		await _until(func() -> bool: return int(dc.get("phase")) == 0, 12.0)
		break
	# a hull breach panel in the port wing
	for bp: Node in get_tree().get_nodes_in_group(&"breach_panels"):
		var at: Vector3 = (bp as Node3D).global_position
		await _stand(Vector3(at.x, 0.05, at.z - 4.0))
		_watch_start()
		bp.call("blow", (fc.get("cfg") as Dictionary).get("breach", {}))
		await _secs(2.0)
		_watch = false
		bp.call("seal", 1)
		var suck: float = float(((fc.get("cfg") as Dictionary).get("breach", {}) as Dictionary).get("suction_mps", 4.0))
		_check(float(_max_h.get(1, 99.0)) < suck + 1.0, "a blown panel (%s) pulls at its suction (top %.1f m/s; was ~22)" % [bp.name, float(_max_h.get(1, 99.0))])
		break
	# the Bordwart's cable lash in the engine room (bordwart.gd _lash: 6 m/s away and 2 m/s up for 0.35 s): the launch
	# the owner saw. Master added the push every frame: ~37 m/s up, ~50 m over the deck, through the roof.
	await _stand(Vector3(-69.0, 0.05, 39.0))
	await _secs(0.6)
	_watch_start()
	_p.external_push(Vector3(1, 0, 0) * 6.0 + Vector3(0, 2.0, 0), 0.35, &"push")
	await _secs(3.0)
	_watch = false
	_check(float(_max_rise.get(1, 99.0)) < 1.0, "the Bordwart's cable lash knocks the human back, it does not launch him (rose %.2f m; was ~50)" % float(_max_rise.get(1, 99.0)))
	_check(float(_max_h.get(1, 99.0)) < 7.0, "and throws him at the lash's 6 m/s (top %.1f m/s)" % float(_max_h.get(1, 99.0)))
	_p.global_position = Vector3(0, 0.05, 36)
	_p.velocity = Vector3.ZERO
	await _frames(20)


# ---------------------------------------------------------------- 2. the safety net

func _put_back_case(what: String, pos: Vector3, body: Player = null) -> void:
	var g: Variant = _guard()
	if g == null:
		return
	var b: Player = body if body != null else _p
	var hp: float = b.hp
	var before: int = g.rescues
	b.global_position = pos
	b.velocity = Vector3.ZERO
	var back: bool = await _until(func() -> bool: return g.rescues > before, 4.0)
	var still: float = b.velocity.length()   # right as it is put down
	await _secs(1.2)
	var rid: RID = _map.get_world_3d().navigation_map
	var near: Vector3 = NavigationServer3D.map_get_closest_point(rid, b.global_position)
	var on_nav: bool = Vector2(near.x - b.global_position.x, near.z - b.global_position.z).length() < 1.5 and absf(near.y - b.global_position.y) < 1.5
	var last: Dictionary = g.history[g.history.size() - 1] if not g.history.is_empty() else {}
	_check(back and g.rescues == before + 1, "%s: %s comes back down once (rescues +%d, %s)" % [GameState.map_id, what, g.rescues - before, str(last.get("reason", "-"))])
	_check(on_nav and not b.downed and b.hp >= hp - 0.01 and still < 1.5, "%s: %s stands on the navmesh, still, unhurt (%s, %.1f m/s, hp %.0f/%.0f, %s)" % [GameState.map_id, what, str(b.global_position.snapped(Vector3.ONE * 0.1)), still, b.hp, hp, str(last.get("how", "-"))])


func _safety_net(key: String) -> void:
	var g: Variant = _guard()
	_check(g != null and g.ready_done and g.enabled, "%s: the BoundsGuard watches the map" % key)
	if g == null or not g.ready_done:
		return
	print("[bounds-smoke] %s bounds: kill %.1f ceiling %.1f rect %s fall %.1f s" % [key, g.kill_y, g.ceiling_y, str(g.rect), g.max_fall_s])
	RoundManager.stop()
	var home: Vector3 = (_map as MapRoot).spawn_transform(1).origin
	var rid: RID = _map.get_world_3d().navigation_map
	home = NavigationServer3D.map_get_closest_point(rid, home)
	await _stand(home + Vector3.UP * 0.05)
	await _secs(0.6)   # a check or two on the floor: the last safe floor
	await _put_back_case("the human far over the ceiling", Vector3(home.x, g.ceiling_y + 25.0, home.z))
	await _put_back_case("the human beyond the edge", Vector3(g.rect.end.x + 40.0, home.y + 1.0, home.z))
	await _put_back_case("the human under the floor", Vector3(home.x, g.kill_y - 20.0, home.z))
	if key == "map04b":
		await _put_back_case("the human on the invisible deck outside the hull", Vector3(-30.0, 0.05, 10.0))
	var bots: Array[Player] = _bots()
	if not bots.is_empty():
		var bot: Player = bots[0]
		await _secs(0.6)
		await _put_back_case("bot P%d in the sky" % bot.player_id, Vector3(bot.global_position.x, g.ceiling_y + 30.0, bot.global_position.z), bot)


## Act IV: a launch plate's arc and the Moon's jumps are never a rescue.
func _moon_legit() -> void:
	var g: Variant = _guard()
	if g == null:
		return
	var pads: Array[Node] = get_tree().get_nodes_in_group(&"jump_pads")
	_check(GameState.gravity_scale < 0.9, "map04d: low gravity (scale %.2f)" % GameState.gravity_scale)
	var before: int = g.rescues
	var used: int = 0
	for n: Node in pads.slice(0, 3):
		var pad: JumpPad = n as JumpPad
		if pad == null:
			continue
		var l0: int = pad.launches
		await _stand(pad.global_position + Vector3.UP * 0.05)
		await _until(func() -> bool: return pad.launches > l0, 2.0)
		used += 1 if pad.launches > l0 else 0
		await _secs(pad.flight_s + 1.5)
	_check(pads.is_empty() or used > 0, "map04d: rode %d launch plates" % used)
	for i: int in 6:
		_p.velocity.y = 4.2
		await _secs(1.2)
	_check(g.rescues == before, "map04d: the plates' arcs and the low-gravity jumps are never rescued (%d)" % (g.rescues - before))


# ---------------------------------------------------------------- 3. no false rescues in a bot match

func _bot_match(key: String, seconds: float) -> void:
	var g: Variant = _guard()
	if g == null:
		_check(false, "%s: no BoundsGuard on the map" % key)
		return
	var before: int = g.rescues
	var home: Vector3 = (_map as MapRoot).spawn_transform(1).origin
	await _stand(home + Vector3.UP * 0.1)
	RoundManager.start_game((_map as MapRoot).scaled_player_count())
	if key == "map04b":
		RoundManager.act_start = 15
		RoundManager.debug_set_round(16)   # Act II round 2: the flight clock's tilts, the wing walk opens
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	_watch_start()
	var t: float = 0.0
	while t < seconds:
		await _secs(1.0)
		t += 1.0
		for z: Zombie in dir.active_zombies():
			if z is HomageBoss:
				continue
			for pn: Node in get_tree().get_nodes_in_group(&"players"):
				if (pn as Player).is_alive() and z.global_position.distance_to((pn as Player).global_position) < 4.0:
					z.take_damage(z.hp + 1.0, &"torso", &"kar98k", 1, &"bullet")
					break
	_watch = false
	RoundManager.stop()
	var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
	var top: float = 0.0
	for k: Variant in _max_h:
		top = maxf(top, float(_max_h[k]))
	_check(g.rescues == before, "%s: a %.0f s bot match (round %d%s) has no rescue (%d)" % [key, seconds, RoundManager.current_round,
		(", %d tilts" % int(fc.get("banks_done"))) if fc != null else "", g.rescues - before])
	_check(top < 12.0, "%s: nobody moved faster than a sprint and a push in it (top %.1f m/s)" % [key, top])


func _run() -> void:
	await _frames(5)
	var total: int = 0
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for m: Array in MAPS:
		var key: String = str(m[0])
		if only != "" and key != only:
			continue
		print("[bounds-smoke] ---- %s" % key)
		await _load(key, str(m[1]))
		if key == "map04b":
			await _kranich_pushes()
		await _safety_net(key)
		if key == "map04d":
			await _moon_legit()
		if key == "map00" or key == "map04b":
			await _bot_match(key, 90.0)
		var g: Variant = _guard()
		total += int(g.rescues) if g != null else 0
	print("[bounds-smoke] rescues this run: %d" % total)
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _fails.is_empty():
		print("RESULT PASS smoke_bounds (%.0f s)" % _t)
		get_tree().quit(0)
	else:
		print("RESULT FAIL smoke_bounds: %s" % "; ".join(_fails))
		get_tree().quit(1)
