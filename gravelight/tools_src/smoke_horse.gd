extends Node
## The rideable horse (T-240) on the Inn (map00): it stands tied at its rail in the Carters' Yard; a player mounts (the
## body is carried into the saddle), rides a loop of the yard through walk, trot and gallop (shooting allowed at a walk
## and a trot, not at a gallop), never leaves the yard through a house door or over a fence, shies from a crowd and
## flings a zombie it gallops through, is pulled off when downed, gets down on a free spot, and the horse walks back to
## its rail. A bot never rides it, zombies pass it, and a peer that does not move it (a remote rider) keeps it under the
## rider's body. Headless, silent.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_horse.tscn

var _fails: PackedStringArray = []
var _checks: int = 0
var _map: Node3D
var _p: Player


func _ready() -> void:
	ProfileSave.path = "user://_qa_horse_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[horse] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _on_nav(pos: Vector3, tol: float = 0.7) -> bool:
	var nav_map: RID = _p.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(nav_map, pos).distance_to(pos) < tol


func _place_horse(h: Horse, at: Vector3, yaw_deg: float) -> void:
	h.global_position = at
	h.rotation.y = deg_to_rad(yaw_deg)
	h.speed = 0.0
	h.pace = 0.0
	h.steer = 0.0
	h.set("_last_ok", at)
	h.set("_prev_pos", at)


## Rides with a fixed input for `seconds`, checking every frame that the horse stays in the yard. Returns
## [fastest speed, the turn made (radians), fastest gait].
func _ride(h: Horse, steer: float, throttle: float, sprint: bool, seconds: float, label: String) -> Array:
	h.input_override = Vector3(steer, throttle, 1.0 if sprint else 0.0)
	var top: float = 0.0
	var turned: float = 0.0
	var gait: int = 0
	var out: int = 0
	var prev: float = h.rotation.y
	var frames: int = int(seconds * 60.0)
	for i: int in frames:
		await get_tree().physics_frame
		top = maxf(top, absf(h.speed))
		gait = maxi(gait, h.rig.gait)
		turned += absf(wrapf(h.rotation.y - prev, -PI, PI))
		prev = h.rotation.y
		var pos: Vector3 = h.global_position
		if pos.x < 2.0 or pos.x > 34.0 or pos.z < 34.0 or pos.z > 48.0 or absf(pos.y) > 0.5:
			out += 1
	h.input_override = Vector3.ZERO
	_check(out == 0, "%s: the horse never left the yard (%d frames outside, now %s)" % [label, out, str(h.global_position.snapped(Vector3.ONE * 0.1))])
	return [top, turned, gait]


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 1
	Campaign.reset()
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	await _frames(20)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	var dir: ZombieDirector = _map.get("director") as ZombieDirector
	var rescues0: int = BoundsGuard.rescues_total

	# ---- it is there, tied, out of the way
	var horses: Array = get_tree().get_nodes_in_group(&"horses")
	_check(horses.size() == 1, "map00: one horse in the scene (%d)" % horses.size())
	if horses.is_empty():
		_finish()
		return
	var h: Horse = horses[0] as Horse
	var r: Dictionary = HorseRules.block("ride")
	_check(h.name == "YardHorse" and h.mode == Horse.Mode.TIED, "it stands tied (%s, mode %d)" % [h.name, h.mode])
	_check(ZoneVolume.zone_at(get_tree(), h.global_position + Vector3.UP) == &"YARD", "it stands in the Carters' Yard (%s)" % str(ZoneVolume.zone_at(get_tree(), h.global_position + Vector3.UP)))
	_check(absf(h.global_position.y) < 0.15 and h.is_on_floor(), "its hooves are on the ground (y %.2f)" % h.global_position.y)
	_check(_map.find_child("HitchingRail", true, false) != null, "the hitching rail is built")
	var rail_body: Node = _map.find_child("RailCollider", true, false)
	_check(rail_body is StaticBody3D and ((rail_body as StaticBody3D).collision_layer & (Zombie.LAYER_WORLD | Zombie.LAYER_ZBODY)) == 0, "the rail's collider is off the zombies' layers (navmesh-safe)")
	_check((h.collision_layer & (Zombie.LAYER_WORLD | Zombie.LAYER_PLAYER | Zombie.LAYER_ZBODY | Zombie.LAYER_DOOR | Hitbox.LAYER_HITBOX)) == 0, "zombies and shots pass the horse (layer %d)" % h.collision_layer)
	_check((h.collision_layer & Player.MASK_MOVE) != 0, "players are stopped by it")
	_check(not h.has_method("take_damage"), "it cannot be hurt (no damage entry point)")
	var zip: Vector3 = Vector3(18.6, 0, 36.2)
	var ladder: Vector3 = Vector3(5.4, 0, 42.6)
	_check(h.global_position.distance_to(zip) > 4.0 and h.global_position.distance_to(ladder) > 10.0, "it is clear of the zip line's post (%.1f m) and the tower's ladder (%.1f m)" % [h.global_position.distance_to(zip), h.global_position.distance_to(ladder)])
	_check(h.rig != null and h.rig.body.mesh.get_surface_count() >= 5, "the model is built (%d surfaces, %d bones)" % [h.rig.body.mesh.get_surface_count(), h.rig.skel.get_bone_count()])

	# ---- bots never ride
	GameState.open_zone(&"YARD")
	GameState.open_zone(&"STABLE")
	var bot: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_bot:
			bot = n as Player
	_check(bot != null, "a squad bot is in the match")
	if bot != null:
		_check(not h.can_use(bot) and not h.use.can_interact(bot), "a bot may not mount")
		var in_bot_groups: bool = false
		for g: StringName in [&"doors", &"power_switch", &"buildable_parts", &"ladders", &"ziplines", &"wall_buys", &"perk_machines", &"crate_spots", &"ammo_boxes"]:
			if h.is_in_group(g) or h.use.is_in_group(g):
				in_bot_groups = true
		_check(not in_bot_groups, "the horse is in none of the groups the bots shop or interact from")

	# ---- mount
	_p.global_position = h.global_transform * Vector3(-1.3, 0.05, 0.2)
	_p.rotation.y = h.rotation.y - PI * 0.5
	_p.velocity = Vector3.ZERO
	await _frames(4)
	_check(h.use.can_interact(_p) and h.use.get_prompt(_p).contains("ride"), "usable from beside it (\"%s\")" % h.use.get_prompt(_p))
	_p.use_interactable(h.use)
	await _frames(2)
	_check(h.rider == _p and h.mode == Horse.Mode.MOUNTING and _p.carry == h, "Use starts the mount: the body is carried")
	_check(not h.use.can_interact(bot if bot != null else _p) and h.use.get_prompt(bot) == "", "one rider: nobody else is offered the horse")
	await _secs(float(r.get("mount_s", 1.0)) * 0.5)
	var mid_y: float = _p.global_position.y
	_check(mid_y > 0.15, "mid-mount the body is on its way up (y %.2f)" % mid_y)
	await _secs(float(r.get("mount_s", 1.0)) * 0.5 + 0.25)
	_check(h.mode == Horse.Mode.RIDDEN and h.seated(), "the mount ends in the saddle")
	var eye: float = _p.global_position.y + Player.EYE_STAND
	_check(eye > 2.2 and eye < 2.7, "the rider's eye is at rider height (%.2f m)" % eye)
	_check(Vector2(_p.global_position.x - h.global_position.x, _p.global_position.z - h.global_position.z).length() < 0.4, "the rider sits over the horse")
	await _frames(6)
	_check(_p.carry_fire and _p.weapons.hands_mode == &"", "at a stand the gun is up and may fire (carry_fire %s, hands \"%s\")" % [str(_p.carry_fire), _p.weapons.hands_mode])

	# ---- the gaits: walk, trot, gallop, by holding forward
	_place_horse(h, Vector3(6.0, 0, 39.0), -90.0)   # facing east down the yard's long side
	await _frames(3)
	var a: Array = await _ride(h, 0.0, 1.0, false, 1.3, "walk")
	_check(int(a[2]) == HorseGait.Gait.WALK and float(a[0]) > 0.8 and float(a[0]) < 3.0, "forward: it steps off at a walk (gait %s, %.1f m/s)" % [HorseGait.gait_name(int(a[2])), float(a[0])])
	h.input_override = Vector3(0, 1, 0)
	await _secs(1.4)
	_check(h.rig.gait == HorseGait.Gait.TROT, "held forward it goes on to a trot (gait %s, %.1f m/s)" % [HorseGait.gait_name(h.rig.gait), h.speed])
	_check(_p.carry_fire and _p.weapons.hands_mode == &"", "at a trot the rider may shoot (carry_fire %s)" % str(_p.carry_fire))
	var bob0: float = _p.global_position.y
	var bob_lo: float = bob0
	var bob_hi: float = bob0
	for i: int in 40:
		await get_tree().physics_frame
		bob_lo = minf(bob_lo, _p.global_position.y)
		bob_hi = maxf(bob_hi, _p.global_position.y)
	_check(bob_hi - bob_lo > 0.03, "the view rides the trot's bounce (%.3f m)" % (bob_hi - bob_lo))
	_place_horse(h, Vector3(5.0, 0, 39.0), -90.0)
	h.pace = 2.0
	h.speed = 4.6
	h.input_override = Vector3(0, 1, 1)
	await _secs(2.0)
	_check(h.rig.gait == HorseGait.Gait.GALLOP and h.speed > 7.0, "urged on it gallops (gait %s, %.1f m/s)" % [HorseGait.gait_name(h.rig.gait), h.speed])
	_check(not _p.carry_fire and _p.weapons.hands_mode == &"climb", "at a gallop both hands are on the reins: no fire (carry_fire %s, hands \"%s\")" % [str(_p.carry_fire), _p.weapons.hands_mode])
	_check(_p.carry_fov > 2.0, "the view opens with the speed (+%.1f deg)" % _p.carry_fov)
	h.input_override = Vector3(0, -1, 0)
	await _secs(2.2)
	_check(absf(h.speed) < 1.2, "back reins it in to a stand (%.2f m/s)" % h.speed)
	await _secs(1.5)
	_check(h.speed < -0.3, "held at a stand it backs up (%.2f m/s)" % h.speed)
	h.input_override = Vector3.ZERO

	# ---- a loop of the yard at a trot, turning
	_place_horse(h, Vector3(18.0, 0, 43.0), -90.0)
	await _frames(3)
	h.pace = 2.0
	var view0: float = wrapf(_p.rotation.y - h.rotation.y, -PI, PI)
	var loop: Array = await _ride(h, 0.75, 0.6, false, 9.0, "a loop of the yard")
	_check(float(loop[1]) > TAU * 0.8, "it turned a full circle (%.0f deg)" % rad_to_deg(float(loop[1])))
	_check(absf(wrapf(_p.rotation.y - h.rotation.y, -PI, PI) - view0) < 0.3, "the rider's view turns with the horse")
	_check(h.global_position.y < 0.3, "it stayed on the ground")

	# ---- it will not go where a horse cannot: the stable's door (open), a fence, the tower
	var door: Node = _map.get_node_or_null("Gameplay/Door_Yard")
	if door != null and door.has_method("open"):
		door.call("open", 0)
	await _secs(1.5)
	_place_horse(h, Vector3(8.0, 0, 37.5), 0.0)   # nose to the stable's south door
	var ref0: int = h.refusals
	var b: Array = await _ride(h, 0.0, 1.0, false, 4.0, "the stable door")
	_check(h.global_position.z >= 34.2 and ZoneVolume.zone_at(get_tree(), h.global_position + Vector3.UP) == &"YARD", "it does not go in at the open stable door (z %.2f)" % h.global_position.z)
	_check(h.refusals > ref0, "it refused the door (%d refusals)" % (h.refusals - ref0))
	_place_horse(h, Vector3(30.0, 0, 42.0), -90.0)   # at the east fence
	h.pace = 3.0
	h.speed = 9.0
	b = await _ride(h, 0.0, 1.0, true, 2.5, "the east fence at a gallop")
	_check(h.global_position.x < 34.0, "a fence stops it (x %.2f)" % h.global_position.x)
	_place_horse(h, Vector3(10.0, 0, 45.0), 90.0)   # at the tower (west)
	b = await _ride(h, 0.0, 1.0, false, 4.0, "the tower")
	_check(h.global_position.y < 0.4, "it never climbs the tower (y %.2f)" % h.global_position.y)
	_check(BoundsGuard.rescues_total == rescues0, "the bounds guard never had to bring the rider back (%d rescues)" % (BoundsGuard.rescues_total - rescues0))

	# ---- zombies: they ignore it, it shies from a crowd, it flings one it gallops through
	_place_horse(h, Vector3(12.0, 0, 39.5), -90.0)
	await _frames(3)
	RoundManager.state = RoundManager.State.ROUND
	var made: int = dir.spawn_burst([Vector3(13.5, 0, 38.5), Vector3(13.5, 0, 40.5), Vector3(11.0, 0, 41.0), Vector3(10.5, 0, 38.0)], 4)
	await _secs(4.5)
	var zs: Array[Zombie] = dir.active_zombies()
	_check(made == 4 and zs.size() >= 4, "four of the dead rise round it (%d)" % zs.size())
	var all_players: bool = true
	for z: Zombie in zs:
		if z.target != null and not (z.target is Player):
			all_players = false
	_check(all_players, "the dead hunt the players, not the horse")
	_check(h.get("_crowd") >= 2 and h.pace_cap() < 3.0, "a crowd slows it (%d within reach, fastest pace %.1f)" % [h.get("_crowd"), h.pace_cap()])
	_check(h.rig.shy > 0.2 or h.get("_shy") > 0.2, "it shies (%.2f)" % float(h.get("_shy")))
	# gallop through one
	dir.kill_all(true)
	await _secs(0.5)
	_place_horse(h, Vector3(8.0, 0, 44.0), -90.0)
	made = dir.spawn_burst([Vector3(20.0, 0, 44.0)], 1)
	await _secs(4.0)
	zs = dir.active_zombies()
	var victim: Zombie = null
	for z: Zombie in zs:
		if victim == null or z.global_position.distance_to(Vector3(20.0, 0, 44.0)) < victim.global_position.distance_to(Vector3(20.0, 0, 44.0)):
			victim = z
	_check(victim != null, "one of the dead stands in its path")
	if victim != null:
		var waited: float = 0.0
		while victim.state == Zombie.State.EMERGE and waited < 8.0:
			await _secs(0.25)
			waited += 0.25
		if victim.state != Zombie.State.CHASE:
			victim.call("_enter", Zombie.State.CHASE)   # (one sent to a window: for this case it stands in the open)
		victim.global_position = Vector3(20.0, 0.0, 44.0)
		print("[horse]   (the victim: state %d after %.1f s more)" % [victim.state, waited])
		var hp0: float = victim.hp
		h.pace = 3.0
		h.speed = 9.0
		h.input_override = Vector3(0, 1, 1)
		var hit: bool = false
		var lost: float = 0.0
		for i: int in 150:
			await get_tree().physics_frame
			if not hit:
				victim.global_position = Vector3(20.0, victim.global_position.y, 44.0)
				victim.velocity = Vector3.ZERO
			if h.tramples > 0 and not hit:
				hit = true
				lost = h.speed
		h.input_override = Vector3.ZERO
		_check(h.tramples == 1, "galloping through it flings it aside, once (%d)" % h.tramples)
		_check(lost < 9.0 * 0.8, "the horse loses speed for it (%.1f m/s after)" % lost)
		await _secs(1.2)
		_check(victim.hp < hp0 or not victim.is_active(), "the flung one is hurt where it lands (%.0f -> %.0f)" % [hp0, victim.hp])
	dir.kill_all(true)
	RoundManager.stop()

	# ---- a peer that does not move the horse: it stays under the rider's replicated body
	h.dismount_wanted = true
	await _secs(float(r.get("dismount_s", 0.7)) + 0.5)
	_check(h.rider == null and _p.carry == null, "Use / jump again: the rider gets down")
	var dd: float = Vector2(_p.global_position.x - h.global_position.x, _p.global_position.z - h.global_position.z).length()
	_check(dd > 0.7 and dd < 2.6 and _p.global_position.y < 0.4, "set down on the ground beside it (%.2f m away)" % dd)
	_check(_on_nav(_p.global_position), "the spot is on the navmesh")
	_check(_p.weapons.hands_mode == &"" and not _p.carry_fire, "the gun is back, the saddle's fire rule is off")
	var p0: Vector3 = _p.global_position
	_p.set("_lunge_t", 0.0)
	await _frames(20)
	_check(_p.is_physics_processing() and h.mode == Horse.Mode.LOOSE, "the player moves again; the horse stands loose")
	if bot != null:
		var hp_before: Vector3 = h.global_position
		h.net_mount(bot.player_id, h.global_position, h.rotation.y)
		await _secs(float(r.get("mount_s", 1.0)) + 0.3)
		_check(h.rider == bot and h.mode == Horse.Mode.RIDDEN and bot.carry == null and not h.simulates(), "a remote rider: this peer does not move the horse or carry the body")
		var worst: float = 0.0
		for i: int in 90:
			await get_tree().physics_frame
			var want: Vector3 = bot.global_position - h.global_basis * (h.rig.point("Body", HorseMesh.SEAT) + Vector3.UP * (float(r.get("eye", 0.8)) - Player.EYE_STAND))
			worst = maxf(worst, h.global_position.distance_to(want))
		_check(worst < 0.05, "the horse stays under the remote rider's body (worst %.3f m)" % worst)
		h.net_dismount(h.global_position, h.rotation.y)
		await _secs(float(r.get("dismount_s", 0.7)) + 0.3)
		_check(h.rider == null and h.mode == Horse.Mode.LOOSE, "the host's dismount frees the saddle")
		_place_horse(h, hp_before, rad_to_deg(h.rotation.y))

	# ---- left alone it walks back to its rail
	_place_horse(h, Vector3(16.0, 0, 44.0), 120.0)
	h.set("_idle", 999.0)
	var t: float = 0.0
	while h.mode != Horse.Mode.TIED and t < 40.0:
		await _secs(0.5)
		t += 0.5
	_check(h.mode == Horse.Mode.TIED and h.homed >= 1, "left alone it walks back to its rail (%.1f s, mode %d)" % [t, h.mode])
	_check(Vector2(h.global_position.x - h.home_pos.x, h.global_position.z - h.home_pos.z).length() < 0.7 and absf(wrapf(h.rotation.y - h.home_yaw, -PI, PI)) < 0.1,
		"it stands as it was tied (%.2f m off, %.0f deg off)" % [Vector2(h.global_position.x - h.home_pos.x, h.global_position.z - h.home_pos.z).length(), rad_to_deg(absf(wrapf(h.rotation.y - h.home_yaw, -PI, PI)))])

	# ---- a rider can be hit, and is pulled off when downed (last: the squad's bleed-out starts)
	_p.global_position = h.global_transform * Vector3(-1.3, 0.05, 0.2)
	_p.velocity = Vector3.ZERO
	await _frames(4)
	_p.use_interactable(h.use)
	await _secs(float(r.get("mount_s", 1.0)) + 0.4)
	_check(h.rider == _p and h.seated(), "mounted again")
	GameState.god_mode = false
	var hp1: float = _p.hp
	_p.take_hit(20.0, null)
	_check(_p.hp < hp1, "a rider can be hit (%.0f -> %.0f)" % [hp1, _p.hp])
	_p.take_hit(9999.0, null)
	await _frames(6)
	_check(_p.downed, "the rider goes down in the saddle")
	_check(h.rider == null and _p.carry == null and h.forced_off == 1, "and is pulled off (rider %s, carry %s)" % [str(h.rider), str(_p.carry)])
	_check(_p.global_position.y < 0.6, "the body is left on the ground beside the horse (y %.2f)" % _p.global_position.y)
	GameState.god_mode = true
	_finish()


func _finish() -> void:
	print("[horse] RESULT %s (%d checks, %d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
	for f: String in _fails:
		print("[horse]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
