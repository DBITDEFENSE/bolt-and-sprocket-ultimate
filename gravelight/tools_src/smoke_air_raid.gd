extends Node
## Headless smoke for Werk Thalbach's air raid (UPDATE 10 Act I, contract C6 `air_raid`, DECISIONS T-155):
##   1. before: the Montage -> test stands route runs through Door_Pruefstand; the breach is shut (plug, sealed door)
##   2. act round 8 schedules the raid; the show runs (sirens, flak, the bomb walk lands every bomb)
##   3. fairness: a player standing in the roof bay is thrown out by the shockwave; one put back in after it is moved
##      out at the fall; nobody is in the collapse box when it comes down; zombies in it are crushed
##   4. after: the RubbleBlock collides, the plug is gone, the breach door is open (the stands were bought), the
##      navmesh swapped (Nav_E_MONTAGE_4 off, Nav_E_MONTAGE_raid on, Link_5 off, Link_Breach_E_apron on); a path from
##      Montage 2 into the test stands goes through the breach, never the old door; a bot walks it
##   5. the fires burn (6 zones) and are out three act rounds later
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_air_raid.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const DOOR_OLD: Vector3 = Vector3(-30, 0, 110)
const BREACH: Vector3 = Vector3(-55, 0, 110)

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _raid: ThalbachRaid
var _fails: PackedStringArray = []
var _at_fall: Array = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_raid.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 1
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.round_started.connect(func(_r: int, _s: bool) -> void:
		RoundManager.to_spawn = mini(RoundManager.to_spawn, 4)
		RoundManager.round_total = mini(RoundManager.round_total, 4))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[raid] %-70s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _mask_all() -> int:
	return 0xFF


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map.get_world_3d().navigation_map, from, to, true, _mask_all())


static func _min_dist(path: PackedVector3Array, p: Vector3) -> float:
	var best: float = INF
	for i: int in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var ab: Vector3 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
		var c: Vector3 = a + ab * t
		best = minf(best, Vector2(c.x - p.x, c.z - p.z).length())
	return best


func _tp(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	await _frames(2)


func _zombie_at(pos: Vector3) -> Zombie:
	var before: Dictionary = {}
	for c: Zombie in _dir.active_zombies():
		before[c.get_instance_id()] = true
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = zs[zs.size() - 1]
	for c2: Zombie in zs:
		if not before.has(c2.get_instance_id()):
			z = c2
	z.global_position = pos
	z.set_physics_process(false)
	await _frames(1)
	return z


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	_raid = _map.get_node_or_null("Gameplay/AirRaid") as ThalbachRaid
	RoundManager.stop()
	_check(_raid != null and not _raid.cfg.is_empty(), "the AirRaid node is placed and reads map04a.json raid")
	if _raid == null:
		_finish()
		return
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		(n as BuyDoor).open(1)
	await _frames(5)
	var nav: Node = _map.get_node("Navigation")
	var plug: CollisionObject3D = _map.find_child("BreachPlug", true, false) as CollisionObject3D
	var breach_door: BreachDoor = _map.get_node_or_null("Gameplay/Breach_E_apron") as BreachDoor
	var rubble: StaticBody3D = _raid.get_node_or_null("RubbleBlock") as StaticBody3D

	# ---- 1. before
	_check(plug != null and plug.collision_layer == 1, "the breach is plugged (BreachPlug on the world layer)")
	_check(breach_door != null and breach_door.sealed and not breach_door.visible, "Breach_E_apron is sealed and hidden")
	_check(rubble != null and rubble.collision_layer == 0, "the RubbleBlock does not collide yet")
	_check(_raid.route_node_on("Navigation/Nav_E_MONTAGE_4") and not _raid.route_node_on("Navigation/Nav_E_MONTAGE_raid") and nav.get_node_or_null("Nav_E_MONTAGE_raid") == null,
		"the Montage navmesh is the hall as built (the raid region is out of the map)")
	_check(_raid.route_node_on("Navigation/Link_5_G_PRUEFSTAND") and not _raid.route_node_on("Navigation/Link_Breach_E_apron"),
		"Door_Pruefstand's link on, the breach link off")
	var pre: PackedVector3Array = _path(Vector3(-20, 0, 104.5), Vector3(-30, 0, 116))
	_check(not pre.is_empty() and _min_dist(pre, DOOR_OLD) < 2.0 and _min_dist(pre, BREACH) > 4.0, "Montage 2 -> test stands: through Door_Pruefstand (%.1f m / %.1f m)" % [
		_min_dist(pre, DOOR_OLD), _min_dist(pre, BREACH)])

	# ---- 2. act round 8 schedules it
	RoundManager.debug_set_round(8)
	var wt: int = Time.get_ticks_msec()
	while _raid.phase != ThalbachRaid.Phase.RUNNING and Time.get_ticks_msec() - wt < 20000:
		await _frames(1)
	_check(RoundManager.act_round() == 8 and _raid.phase == ThalbachRaid.Phase.RUNNING and _raid.t < 0.0, "act round 8 schedules the raid (t %.1f)" % _raid.t)
	RoundManager.stop()
	_dir.kill_all(true)
	# a player and two zombies in the roof bay
	await _tp(Vector3(-27, 0.1, 89))
	var z1: Zombie = await _zombie_at(Vector3(-30, 0.1, 90))
	var z2: Zombie = await _zombie_at(Vector3(-25, 0.1, 106))
	_raid.collapsed.connect(func() -> void:
		var box: Array = _raid.cfg["collapse_box"]
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			_at_fall.append(ThalbachRaid.in_box((n as Node3D).global_position, ThalbachRaid.v3(box[0]), ThalbachRaid.v3(box[1]))))
	_raid.start_raid()
	_check(GameState.has_flag(&"a1_raid_running"), "the sirens: a1_raid_running")
	var fall_at: float = float(_raid.cfg["warning_at"]) + float(_raid.cfg["warning_seconds"])
	var push_at: float = fall_at - float(_raid.cfg["push_lead"])
	while _raid.t < push_at - 0.3:
		await _frames(1)
	_check(GameState.has_flag(&"a1_raid_warning"), "the 10 s warning is up (a1_raid_warning)")
	_check(_raid.danger_contains(Vector3(-30, 0, 100)), "bots keep out of the bay during the warning")
	await _tp(Vector3(-27, 0.1, 89))   # stand in it at the last moment
	while _raid.t < push_at + 0.9:
		await _frames(1)
	var box2: Array = _raid.cfg["collapse_box"]
	_check(_raid.players_pushed >= 1 and not ThalbachRaid.in_box(_p.global_position, ThalbachRaid.v3(box2[0]), ThalbachRaid.v3(box2[1])),
		"the shockwave threw the player out (%s)" % str(_p.global_position))
	await _tp(Vector3(-36.5, 0.1, 104.0))   # a stubborn one walks back in
	while not _raid.is_collapsed and _raid.t < fall_at + 2.0:
		await _frames(1)
	_check(_raid.is_collapsed, "the roof came down at %.1f s" % _raid.t)
	_check(not _at_fall.is_empty() and not _at_fall.has(true), "nobody was in the collapse box when it fell (%s)" % str(_at_fall))
	_check(_raid.players_moved >= 1, "the one who walked back in was moved out (%d)" % _raid.players_moved)
	_check(_raid.zombies_crushed >= 2 and not z1.is_active() and not z2.is_active(), "the zombies under it were crushed (%d)" % _raid.zombies_crushed)
	var bw: Array = (_raid.cfg["bomb_walk"] as Dictionary)["points"]
	_check(_raid.bombs_dropped == bw.size(), "every bomb of the walk landed (%d/%d)" % [_raid.bombs_dropped, bw.size()])

	# ---- 4. after
	await _frames(10)
	_check(rubble.collision_layer == 1, "the RubbleBlock collides")
	_check(plug.collision_layer == 0, "the breach plug is gone")
	_check(breach_door != null and not breach_door.sealed and breach_door.is_open, "the breach door is unsealed and open (the stands were bought)")
	_check(not _raid.route_node_on("Navigation/Nav_E_MONTAGE_4") and _raid.route_node_on("Navigation/Nav_E_MONTAGE_raid") and nav.get_node_or_null("Nav_E_MONTAGE_4") == null,
		"the navmesh swapped to Nav_E_MONTAGE_raid (the hall as built is out of the map)")
	_check(not _raid.route_node_on("Navigation/Link_5_G_PRUEFSTAND") and _raid.route_node_on("Navigation/Link_Breach_E_apron"),
		"Link_5 (Door_E_south) off, Link_Breach_E_apron on")
	await _frames(6)   # the navigation map syncs
	var post: PackedVector3Array = _path(Vector3(-20, 0, 104.5), Vector3(-30, 0, 116))
	_check(not post.is_empty() and post[post.size() - 1].distance_to(Vector3(-30, 0, 116)) < 1.5 and _min_dist(post, BREACH) < 2.5 and _min_dist(post, DOOR_OLD) > 2.5,
		"Montage 2 -> test stands: through the breach now (breach %.1f m, old door %.1f m)" % [_min_dist(post, BREACH), _min_dist(post, DOOR_OLD)])
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(-30, 1.0, 102.5), Vector3(-30, 1.0, 111.5), 1)
	_check(not space.intersect_ray(q).is_empty(), "the old doorway is buried (a ray hits the rubble)")
	var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(-55, 1.0, 108.0), Vector3(-55, 1.0, 112.0), 1 | (1 << 8))
	_check(space.intersect_ray(q2).is_empty(), "the breach is open (a ray passes)")
	# a bot walks the new route
	var root: MapRoot = _map as MapRoot
	var ok_bot: bool = false
	var near_breach: float = INF
	var near_door: float = INF
	if root.squad != null and not root.squad.brains.is_empty():
		var b: BotBrain = root.squad.brains[0]
		b.set_physics_process(false)
		if b.loco == null:
			b.loco = BotLocomotion.new()
			b.loco.setup(b.player, root.squad)
		b.player.global_position = Vector3(-20, 0.1, 104.5)
		b.player.velocity = Vector3.ZERO
		await _frames(3)
		var goal: Vector3 = Vector3(-30, 0, 116)
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 45000:
			b.loco.move_to(goal, 0.6, 1.0)
			b.loco.tick(1.0 / 60.0)
			await get_tree().physics_frame
			var bp: Vector3 = b.player.global_position
			near_breach = minf(near_breach, Vector2(bp.x - BREACH.x, bp.z - BREACH.z).length())
			near_door = minf(near_door, Vector2(bp.x - DOOR_OLD.x, bp.z - DOOR_OLD.z).length())
			if Vector2(bp.x - goal.x, bp.z - goal.z).length() < 1.6:
				ok_bot = true
				break
		print("[raid] bot at %s after %.1f s (breach %.1f m, old door %.1f m)" % [str(b.player.global_position), float(Time.get_ticks_msec() - t0) / 1000.0, near_breach, near_door])
	_check(ok_bot and near_breach < 2.5 and near_door > 2.0, "a bot walks Montage 2 -> the test stands through the breach")

	# ---- 5. the fires
	_check(_raid.status()["fires"] == 6 and is_equal_approx(_raid.heat_now(), 1.0), "six fires burn at full heat")
	RoundManager.debug_set_round(10)
	var wr: int = Time.get_ticks_msec()
	while RoundManager.act_round() < 10 and Time.get_ticks_msec() - wr < 20000:
		await _frames(1)
	await _frames(40)
	_check(_raid.heat_now() > 0.0 and _raid.heat_now() < 0.5, "two rounds on they are dying down (%.2f)" % _raid.heat_now())
	RoundManager.debug_set_round(11)
	var wr2: int = Time.get_ticks_msec()
	while RoundManager.act_round() < 11 and Time.get_ticks_msec() - wr2 < 20000:
		await _frames(1)
	await _frames(60)
	_check(_raid.status()["fires"] == 0, "three act rounds on the fires are out")
	_finish()


func _finish() -> void:
	RoundManager.stop()
	if _fails.is_empty():
		print("[raid] RESULT: PASS")
		get_tree().quit(0)
	else:
		print("[raid] RESULT: FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)])
		get_tree().quit(1)
