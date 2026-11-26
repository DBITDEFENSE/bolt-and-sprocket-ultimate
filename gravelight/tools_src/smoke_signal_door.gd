extends "res://gravelight/tools_src/m2_smoke_base.gd"
## T-286: Totenhafen's signal tower door, the way to Letzte Fahrt's rotor machine (s2_cipher), for a bot and a player.
## The power thrown, every other door open, the quest skipped to s2_cipher. (1) The bots' place to buy door_signal
## (BotBrain.door_approach) is a spot on the ramp within 7 m of the door that the open zones' navmesh reaches, from three
## places round the hall (T-251's shut-zone rule had made every spot there count as behind the door, so the bots
## walked for the unreachable front and gave up: "couldn't open signal door"). (2) The human walks (the move key held,
## real physics) from the north apron up the catwalk and the ramp to the door, buys it, walks to the rotor machine and
## can use it. Run: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_signal_door.tscn

const QUEST: StringName = &"map02_letzte_fahrt"
const STARTS: Array = [Vector3(32.1, 0.0, 34.2), Vector3(42.0, 0.0, 45.4), Vector3(17.0, 0.0, 49.1)]


func _init() -> void:
	tag = "signal_door"
	bots = 1
	_timeout_s = 600.0


func _body() -> void:
	GameState.set_flag(&"ballast_loaded", 1)
	(_g("Pumpenschalter") as PowerSwitch).run_sequence(0)
	await _secs(10.0)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if String(d.door_id) != "door_signal" and not d.is_open:
			d.open(0)
	QuestManager.debug_skipto(QUEST, &"s2_cipher")
	await _frames(30)
	_dir.recompute_nav_mask()
	var door: BuyDoor = _g("Door_Signal") as BuyDoor
	_check(GameState.power_on and door.can_interact(_p) and not door.is_open, "the power is on and the signal door is for sale")
	_check(QuestManager.is_active(QUEST, &"s2_cipher"), "s2_cipher is the open step")
	await _bot_approach(door)
	await _human(door)


func _bot_approach(door: BuyDoor) -> void:
	var bot: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		bot = n as Player
	var brain: BotBrain = null
	for c: Node in bot.get_children():
		if c is BotBrain:
			brain = c
	_check(brain != null, "the bot has its brain")
	if brain == null:
		return
	for st: Vector3 in STARTS:
		bot.global_position = st
		bot.velocity = Vector3.ZERO
		await _frames(5)
		brain.invalidate_stand_cache()
		var front: Vector3 = BotBrain._door_side(door, bot.global_position)
		var ap: Vector3 = brain.door_approach(door, front)
		var path: PackedVector3Array = brain.open_path(bot.global_position, brain.snap(ap))
		var reach: bool = not path.is_empty() and path[path.size() - 1].distance_to(brain.snap(ap)) < 1.5
		_check(reach and ap.distance_to(door.global_position) <= 7.0 and ap.y > TY - 2.0,
			"from %s the bots buy the signal door from %s (%.1f m from it, on the ramp, the open zones reach it: %s)" % [st, ap.snapped(Vector3.ONE * 0.1),
			ap.distance_to(door.global_position), reach])
	bot.global_position = Vector3(-20.0, 0.2, 10.0)   # out of the human's way
	bot.velocity = Vector3.ZERO


## The human's own walk: waypoints from the walkable layers (every zone, no zombie climb links), the move key held.
func _human(door: BuyDoor) -> void:
	var rid: RID = _map.get_world_3d().navigation_map
	await _tp(Vector3(32.1, 0.2, 34.2), 0.0)
	var front: Vector3 = BotBrain._door_side(door, _p.global_position)
	var got: bool = await _walk_path(rid, front, 90.0)
	print("[%s] human at %s, %.1f m from the door's front; prompt '%s'" % [tag, _p.global_position.snapped(Vector3.ONE * 0.1),
		_p.global_position.distance_to(front), door.get_prompt(_p)])
	_check(got and door.can_interact(_p), "the human walked up the ramp to the signal door and can buy it")
	Economy.grant(1, 5000)
	door.interact(_p)
	await _frames(10)
	_check(door.is_open, "the human bought the signal door")
	var cm: Interactable = get_tree().get_first_node_in_group(&"cipher_machines") as Interactable
	var cfront: Vector3 = BotBrain._front_of(cm)
	var got2: bool = await _walk_path(rid, cfront, 40.0)
	print("[%s] human at %s, %.1f m from the rotor machine's front; prompt '%s'" % [tag, _p.global_position.snapped(Vector3.ONE * 0.1),
		_p.global_position.distance_to(cfront), cm.get_prompt(_p)])
	_check(got2 and cm.can_interact(_p), "the human walked into the tower to the rotor machine and can use it")


func _walk_path(rid: RID, goal: Vector3, limit_s: float) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, _p.global_position, NavigationServer3D.map_get_closest_point(rid, goal), true, ClimbLink.WALK_MASK)
	var i: int = 1
	var t: float = 0.0
	var stuck_t: float = 0.0
	var last: Vector3 = _p.global_position
	while i < path.size() and t < limit_s:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		var to: Vector3 = path[i] - _p.global_position
		to.y = 0.0
		if to.length() < 0.45:
			i += 1
			continue
		_p.rotation.y = atan2(-to.x, -to.z)
		Input.action_press(&"move_forward")
		stuck_t = stuck_t + dt if _p.global_position.distance_to(last) < 0.01 else 0.0
		last = _p.global_position
		if stuck_t > 3.0:
			print("[%s]   the human is stuck at %s on the way to %s" % [tag, _p.global_position.snapped(Vector3.ONE * 0.1), path[i].snapped(Vector3.ONE * 0.1)])
			break
	Input.action_release(&"move_forward")
	await _frames(5)
	return i >= path.size()
