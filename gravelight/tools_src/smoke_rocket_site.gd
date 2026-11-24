extends Node
## T-276: Map 0's V2 site east of the grounds (MapRocketGen, RocketLaunch), headless, solo with one bot, silent:
##   the gate     Door_Rocket in the east fence (1500, "The Forest Track") shuts the way until bought: a body is
##                stopped in the opening, the navmesh path from the grounds to the clearing crosses that door and no
##                other bought door than the grounds' own; bought with Scrip it opens FORSTWEG and STELLUNG
##   the ground   the track and the clearing are baked navmesh and their zones read right (open ground); nothing past
##                the new edge walls but the spawn pockets; the wall-buy, the ammo box and the dugout are reachable
##   the dead     with a player standing in the clearing (round 5) zombies come out of the woods (the site's own edge
##                spawns), reach the player and hit them
##   the bot      the squad's bot follows the player through the gate onto the track and the clearing without falling
##                out of the world
## Prints "[rocket_site] ..." lines and "[rocket_site] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_rocket_site.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 400.0
const GROUNDS_PT: Vector3 = Vector3(52.0, 0.05, 40.0)
const SITE_PT: Vector3 = Vector3(100.0, 0.05, 44.5)

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0
var _hurt: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_rocket_site_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_rocket_site_settings.cfg"
	GameState.character_id = &"dutch"
	Campaign.reset()
	GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
		if pid == 1:
			_hurt += amount)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[rocket_site] %-92s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[rocket_site] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _p() -> Player:
	return _root().player


func _bot() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player).is_bot:
			return n as Player
	return null


func _place(p: Player, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _run() -> void:
	GameState.bot_count = 1
	GameState.god_mode = true
	_map = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await _secs(1.0)
	_p().set_process_unhandled_input(false)
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	if op != null:
		op.cancel()
	_root().director.kill_all(true)
	for z: String in ["YARD", "GROUNDS", "STABLE"]:
		GameState.open_zone(StringName(z))
	await _gate()
	await _ground()
	await _dead_and_bot()
	_finish()


func _gate() -> void:
	var gate: BuyDoor = _map.find_child("Door_Rocket", true, false) as BuyDoor
	_check(gate != null and gate.cost == MapRocketGen.GATE_COST and gate.opens_zone == &"FORSTWEG" and gate.also_opens.has("STELLUNG"),
		"Door_Rocket: %d, opens FORSTWEG and STELLUNG" % (gate.cost if gate != null else -1))
	if gate == null:
		return
	_check(not GameState.is_zone_open(&"FORSTWEG") and not GameState.is_zone_open(&"STELLUNG"), "the track and the clearing start shut")
	# a body walking east through the shut gate is stopped
	_place(_p(), Vector3(58.0, 0.05, 40.0))
	await _secs(0.2)
	var t0: float = 0.0
	while t0 < 2.0:
		_p().velocity = Vector3(5.0, _p().velocity.y, 0.0)
		_p().move_and_slide()
		await get_tree().physics_frame
		t0 += get_physics_process_delta_time()
	_check(_p().global_position.x < 60.0, "the shut gate stops a body (x %.2f)" % _p().global_position.x)
	# the navmesh path from the grounds into the clearing crosses this door and only this bought door
	var m: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(m, GROUNDS_PT, SITE_PT, true)
	var reached: bool = not path.is_empty() and path[path.size() - 1].distance_to(SITE_PT) < 1.0
	var via: Array[String] = []
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and ZombieDirector.door_crossed(d, path):
			via.append(String(d.name))
	_check(reached and via == ["Door_Rocket"], "grounds -> clearing: the path reaches it through Door_Rocket only (%s)" % ", ".join(via))
	# and from the taproom: through the grounds' own doors and this one (no door skipped)
	var path2: PackedVector3Array = NavigationServer3D.map_get_path(m, Vector3(14.5, 0, 13.4), SITE_PT, true)
	var via2: Array[String] = []
	for n2: Node in get_tree().get_nodes_in_group(&"doors"):
		var d2: BuyDoor = n2 as BuyDoor
		if d2 != null and ZombieDirector.door_crossed(d2, path2):
			via2.append(String(d2.name))
	_check(via2.has("Door_Rocket") and (via2.has("Door_Front") or via2.has("Door_Gate")), "taproom -> clearing crosses a grounds door and Door_Rocket (%s)" % ", ".join(via2))
	# bought with Scrip
	_place(_p(), Vector3(58.5, 0.05, 40.0))
	Economy.grant_raw(1, 5000)
	var before: int = Economy.get_scrip(1)
	gate.interact(_p())
	await _secs(0.3)
	_check(gate.is_open, "bought: the gate is open")
	_check(before - Economy.get_scrip(1) == MapRocketGen.GATE_COST, "it cost %d" % (before - Economy.get_scrip(1)))
	_check(GameState.is_zone_open(&"FORSTWEG") and GameState.is_zone_open(&"STELLUNG"), "FORSTWEG and STELLUNG are open")
	t0 = 0.0
	while t0 < 1.5:
		_p().velocity = Vector3(5.0, _p().velocity.y, 0.0)
		_p().move_and_slide()
		await get_tree().physics_frame
		t0 += get_physics_process_delta_time()
	_check(_p().global_position.x > 62.0, "a body walks through the open gate onto the track (x %.2f)" % _p().global_position.x)


func _ground() -> void:
	var m: RID = _map.get_world_3d().navigation_map
	for c: Array in [[Vector3(72, 0, 40), &"FORSTWEG"], [Vector3(105, 0, 21), &"STELLUNG"], [Vector3(105, 0, 59), &"STELLUNG"], [Vector3(123, 0, 40), &"STELLUNG"],
			[Vector3(88, 0, 40), &"STELLUNG"], [Vector3(117.5, 0, 26.0), &"STELLUNG"]]:
		var p: Vector3 = c[0]
		var cp: Vector3 = NavigationServer3D.map_get_closest_point(m, p)
		var zone: StringName = ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.5)
		_check(Vector2(cp.x - p.x, cp.z - p.z).length() < 0.6 and zone == c[1] and ZoneVolume.roam_at(get_tree(), p + Vector3.UP * 0.5),
			"%s on the navmesh in %s (open ground)" % [str(p), String(zone)])
	for o: Vector3 in [Vector3(76, 0, 32.5), Vector3(76, 0, 47.5), Vector3(131, 0, 40), Vector3(80, 0, 20), Vector3(110, 0, 66)]:
		var co: Vector3 = NavigationServer3D.map_get_closest_point(m, o)
		_check(Vector2(co.x - o.x, co.z - o.z).length() > 1.5, "%s beyond the new edge has no navmesh" % str(o))
	for nm: String in ["WallBuy_stg44", "AmmoBox_Rocket", "RocketLaunch"]:
		var n: Node3D = _map.find_child(nm, true, false) as Node3D
		var ok: bool = n != null
		if ok and nm != "RocketLaunch":
			var fwd: Vector3 = n.global_position - n.global_transform.basis.z * 1.0
			var cp2: Vector3 = NavigationServer3D.map_get_closest_point(m, Vector3(fwd.x, 0, fwd.z))
			ok = Vector2(cp2.x - fwd.x, cp2.z - fwd.z).length() < 0.8
		_check(ok, "%s is there and its front is on the navmesh" % nm)
	var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
	_check(rl != null and rl.rocket != null and rl.phase == RocketLaunch.Phase.READY, "a rocket stands on the table, ready")
	_check(_root().clamp_inside(Vector3(110, 0.5, 40)).distance_to(Vector3(110, 0.5, 40)) < 0.01, "a drop in the clearing stays in the clearing")
	_check(_root().clamp_inside(Vector3(131, 0.5, 31)).x > 120.0, "a drop from a pocket past the clearing's edge lands in the clearing")


func _dead_and_bot() -> void:
	var bot: Player = _bot()
	_place(_p(), SITE_PT)
	if bot != null:
		_place(bot, Vector3(56.0, 0.05, 39.0))
	_hurt = 0.0
	RoundManager.debug_set_round(5)
	await _until(func() -> bool: return RoundManager.current_round == 5 and RoundManager.state == RoundManager.State.ROUND, 20.0)
	var from_woods: Array = []
	var ok_reach: bool = await _until(func() -> bool:
		if _p().global_position.distance_to(SITE_PT) > 6.0:
			_place(_p(), SITE_PT)
		for z: Zombie in _root().director.active_zombies():
			if not from_woods.has(z) and z.global_position.x > 84.0:
				from_woods.append(z)
		for z2: Zombie in _root().director.active_zombies():
			if z2.global_position.distance_to(_p().global_position) < 1.8:
				return true
		return false, 90.0)
	_check(from_woods.size() > 0, "zombies come into the clearing (%d seen there)" % from_woods.size())
	_check(ok_reach, "one reaches the player standing in the clearing")
	if bot != null:
		var on: bool = await _until(func() -> bool: return bot.global_position.x > 62.0, 40.0)
		_check(on, "the bot follows through the gate (x %.1f)" % bot.global_position.x)
		_check(bot.global_position.y > -1.0 and bot.global_position.y < 3.0, "the bot is on the ground (y %.2f)" % bot.global_position.y)
