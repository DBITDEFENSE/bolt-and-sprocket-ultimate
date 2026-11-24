extends Node
## The rideable horse (T-240) on the Inn (map00): it stands tied at its rail in the Carters' Yard; a player mounts (the
## body is carried into the saddle), rides a loop of the yard through walk, trot and gallop (shooting allowed at every
## gait; T-262: at a gallop the hands are on the reins until the trigger is pulled, the press is kept and fires when the
## gun is up, the cone and the swing of the aim are wider than at a trot and smaller down the sights), buys the three
## pieces of tack at the chest by the rail (T-262: who may buy, the prices, what each changes, the model), never leaves the yard through a house door or over a fence, shies from a crowd and
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


## Sets the horse galloping east down the yard's long side from x (from x 5: about 2 s of room; west of 5 the
## quarters are at the yard's edge and it refuses).
func _gallop_from(h: Horse, x: float) -> void:
	_place_horse(h, Vector3(x, 0, 39.0), -90.0)
	h.pace = 3.0
	h.speed = 9.0
	h.input_override = Vector3(0, 1, 1)


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
	var zip: Vector3 = Vector3(29.8, 0, 42.1)   # (T-268: the yard zip line's landing post moved east of the cart)
	var ladder: Vector3 = Vector3(5.4, 0, 42.1)
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
	var trot_spread: float = _p.weapons.spread_deg()
	_check(_p.carry_spread == 0.0, "the trot adds nothing to the cone (carry_spread %.2f, cone %.2f deg, on_floor %s)" % [_p.carry_spread, trot_spread, str(_p.is_on_floor())])
	h.pace = 2.0                      # (it holds the trot while it is measured)
	h.input_override = Vector3.ZERO
	await _frames(20)
	var bob0: float = _p.global_position.y
	var bob_lo: float = bob0
	var bob_hi: float = bob0
	var trot_swing: Vector2 = Vector2(INF, -INF)
	for i: int in 40:
		await get_tree().physics_frame
		bob_lo = minf(bob_lo, _p.global_position.y)
		bob_hi = maxf(bob_hi, _p.global_position.y)
		trot_swing = Vector2(minf(trot_swing.x, _p.carry_pitch), maxf(trot_swing.y, _p.carry_pitch))
	_check(h.rig.gait == HorseGait.Gait.TROT, "(still at a trot: %s)" % HorseGait.gait_name(h.rig.gait))
	_check(bob_hi - bob_lo > 0.03, "the view rides the trot's bounce (%.3f m)" % (bob_hi - bob_lo))
	_place_horse(h, Vector3(5.0, 0, 39.0), -90.0)
	h.pace = 2.0
	h.speed = 4.6
	h.input_override = Vector3(0, 1, 1)
	await _secs(2.0)
	_check(h.rig.gait == HorseGait.Gait.GALLOP and h.speed > 7.0, "urged on it gallops (gait %s, %.1f m/s)" % [HorseGait.gait_name(h.rig.gait), h.speed])
	_check(not _p.carry_fire and _p.weapons.hands_mode == &"climb", "at a gallop, the gun idle, both hands are on the reins (carry_fire %s, hands \"%s\")" % [str(_p.carry_fire), _p.weapons.hands_mode])
	_check(_p.carry_fov > 2.0, "the view opens with the speed (+%.1f deg)" % _p.carry_fov)

	# ---- T-262: shooting at a gallop. The weapon is wanted: the gun comes up, the cone opens, the view swings wider
	# than at a trot, a shot leaves the gun; left alone the hands go back to the reins
	var fc: Dictionary = HorseRules.block("fire")
	# the player's own trigger, from the reins: the press is kept while the gun comes up, and the shot goes
	_gallop_from(h, 5.0)
	var wk: WeaponInstance = _p.weapons.current()
	var mag_k: int = wk.mag
	var playing: bool = GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked
	Input.action_press(&"fire")
	await _frames(2)
	Input.action_release(&"fire")
	_check(playing and wk.mag == mag_k, "the trigger pressed from the reins: no shot yet (match playing %s, mag %d)" % [str(playing), wk.mag])
	await _secs(0.6)
	_check(wk.mag == mag_k - 1 and _p.carry_fire and _p.weapons.hands_mode == &"" and h.rig.gait == HorseGait.Gait.GALLOP, "the gun comes up and the kept press fires, once (mag %d -> %d, hands \"%s\", carry_fire %s, gait %s, x %.1f)" % [mag_k, wk.mag, _p.weapons.hands_mode, str(_p.carry_fire), HorseGait.gait_name(h.rig.gait), h.global_position.x])
	_gallop_from(h, 5.0)
	await _secs(float(fc["reins_after_s"]))
	_check(h.rig.gait == HorseGait.Gait.GALLOP and _p.weapons.hands_mode == &"climb", "and the hands are back on the reins %.1f s later (gait %s)" % [float(fc["reins_after_s"]), HorseGait.gait_name(h.rig.gait)])
	_gallop_from(h, 5.0)
	h.weapon_override = true
	await _frames(3)
	_check(_p.carry_fire and _p.weapons.hands_mode == &"", "the weapon wanted at a gallop: the gun comes up (carry_fire %s, hands \"%s\")" % [str(_p.carry_fire), _p.weapons.hands_mode])
	_check(_p.weapons.is_busy(), "it rises as after a swap (no shot for a moment)")
	var w: WeaponInstance = _p.weapons.current()
	var mag0: int = w.mag
	_p.weapons.tick(1.0 / 60.0, {"fire_pressed": true, "fire_held": true, "sprinting": false, "fire_block": false})
	_check(w.mag == mag0, "no shot while the gun is still coming up")
	await _secs(0.5)
	_check(h.rig.gait == HorseGait.Gait.GALLOP and h.speed > 7.0, "still at a gallop (%.1f m/s)" % h.speed)
	var gallop_spread: float = _p.weapons.spread_deg()
	_check(absf(_p.carry_spread - float(fc["spread_gallop_deg"])) < 0.01 and gallop_spread > trot_spread + 1.0, "the gallop opens the cone (%.2f deg, a trot %.2f)" % [gallop_spread, trot_spread])
	var gallop_swing: Vector2 = Vector2(INF, -INF)
	var shots: int = 0
	for i: int in 40:
		await get_tree().physics_frame
		gallop_swing = Vector2(minf(gallop_swing.x, _p.carry_pitch), maxf(gallop_swing.y, _p.carry_pitch))
		if i % 8 == 0:
			var before: int = w.mag
			_p.weapons.tick(1.0 / 60.0, {"fire_pressed": true, "fire_held": true, "sprinting": false, "fire_block": not _p.carry_fire})
			if w.mag < before:
				shots += 1
	_check(shots >= 2 and h.rig.gait == HorseGait.Gait.GALLOP, "shots leave the gun at a gallop (%d, mag %d -> %d)" % [shots, mag0, w.mag])
	_check(gallop_swing.y - gallop_swing.x > (trot_swing.y - trot_swing.x) * 1.5 + 0.01, "the aim swings more than at a trot (%.1f deg against %.1f)" % [rad_to_deg(gallop_swing.y - gallop_swing.x), rad_to_deg(trot_swing.y - trot_swing.x)])
	var ads_swing: Vector2 = Vector2(INF, -INF)
	for i: int in 30:
		_p.weapons.ads_t = 1.0
		await get_tree().physics_frame
		ads_swing = Vector2(minf(ads_swing.x, _p.carry_pitch), maxf(ads_swing.y, _p.carry_pitch))
	_check(_p.carry_spread < float(fc["spread_gallop_deg"]) * 0.75, "aimed down the sights the gallop's cone is smaller (%.2f deg)" % _p.carry_spread)
	_check(ads_swing.y - ads_swing.x < (gallop_swing.y - gallop_swing.x) * 0.8, "and the aim swings less (%.1f deg against %.1f from the hip)" % [rad_to_deg(ads_swing.y - ads_swing.x), rad_to_deg(gallop_swing.y - gallop_swing.x)])
	_gallop_from(h, 5.0)
	h.weapon_override = false
	await _secs(0.6)
	_check(_p.carry_fire and _p.weapons.hands_mode == &"", "between shots the gun stays up (%.1f s after)" % 0.6)
	_gallop_from(h, 5.0)              # (the yard is 30 m long: a fresh run for the rest of the wait)
	await _secs(float(fc["reins_after_s"]) - 0.6 + 0.2)
	_check(h.rig.gait == HorseGait.Gait.GALLOP and not _p.carry_fire and _p.weapons.hands_mode == &"climb" and _p.carry_spread == 0.0, "left alone the hands go back to the reins (gait %s, hands \"%s\")" % [HorseGait.gait_name(h.rig.gait), _p.weapons.hands_mode])
	h.weapon_override = null
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

	# ---- T-262: the tack. Bought on foot at the chest by the rail, one piece at a time, for Scrip, the horse tied
	await _tack(h, bot)

	# ---- a rider can be hit, and is pulled off when downed (last: the squad's bleed-out starts)
	_p.global_position = h.global_transform * Vector3(-1.3, 0.05, 0.2)
	_p.velocity = Vector3.ZERO
	await _frames(4)
	_p.use_interactable(h.use)
	await _secs(float(r.get("mount_s", 1.0)) + 0.4)
	_check(h.rider == _p and h.seated(), "mounted again")
	await _tack_ridden(h, dir)
	_place_horse(h, h.home_pos, rad_to_deg(h.home_yaw))
	await _frames(4)
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


## The tack chest: where it is, who may buy, what each piece costs and changes on the horse.
func _tack(h: Horse, bot: Player) -> void:
	var pid: int = _p.player_id
	var rows: Array = HorseRules.upgrade_rows()
	var t: Horse.HorseTack = h.tack
	_check(t != null and t.is_inside_tree() and rows.size() == 3, "the tack chest stands by the rail (%d pieces on sale)" % rows.size())
	if t == null:
		return
	var space: PhysicsDirectSpaceState3D = _p.get_world_3d().direct_space_state
	var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(t.global_position + Vector3.UP * 3.0, t.global_position + Vector3.DOWN, 1))
	_check(not down.is_empty() and absf((down["position"] as Vector3).y) < 0.15, "it stands on the yard's ground, under nothing (%s)" % str(down.get("position", "no floor")))
	_check(t.global_position.distance_to(h.rail_pos) < 2.2 and absf(t.global_position.x - h.global_position.x) > 1.2, "at the rail's end, clear of the horse's own Use box (%.2f m along)" % (t.global_position.x - h.rail_pos.x))
	_check(ZoneVolume.zone_at(get_tree(), t.global_position + Vector3.UP) == &"YARD", "in the Carters' Yard")
	_check(t.get_child_count() > 4 and t.find_children("*", "CollisionObject3D", true, false).size() == 1, "it is drawn, and its only body is the Use area (nothing for a zombie's path)")
	# the player walks up to it: the Use ray finds it, the prompt names the piece and its price
	_p.global_position = t.global_position + Vector3(0.0, 0.05, 1.15)
	_p.rotation.y = 0.0
	_p.velocity = Vector3.ZERO
	_p.set("_pitch", -0.15)
	await _frames(8)
	var stood: Vector3 = _p.global_position
	_check(stood.distance_to(t.global_position + Vector3(0, 0, 1.15)) < 0.25 and _on_nav(stood), "a player can stand in front of it (%s)" % str(stood.snapped(Vector3.ONE * 0.01)))
	_check(_p.call("_probe_interactable") == t, "looking at it, the Use ray finds the chest (%s)" % str(_p.call("_probe_interactable")))
	var first: Dictionary = rows[0]
	var prompt: String = t.get_prompt(_p)
	_check(prompt.contains(str(first["name"])) and prompt.contains(str(int(first["cost"]))) and prompt.contains(str(first["desc"])), "the prompt: \"%s\"" % prompt.replace("\n", " / "))
	if bot != null:
		_check(t.get_prompt(bot) == "" and not t.can_interact(bot), "a bot is offered nothing and may not buy")
		var bot_scrip: int = Economy.get_scrip(bot.player_id)
		t.interact(bot)
		_check(h.upgrades.is_empty() and Economy.get_scrip(bot.player_id) == bot_scrip, "a bot's use buys nothing")
	# no Scrip: denied, nothing changes
	Economy.grant_raw(pid, -Economy.get_scrip(pid))
	_p.use_interactable(t)
	_check(h.upgrades.is_empty() and Economy.get_scrip(pid) == 0, "with no Scrip nothing is sold")
	# the horse away from its rail: not for sale
	Economy.grant_raw(pid, 10000)
	h.mode = Horse.Mode.LOOSE
	_check(not t.can_interact(_p) and t.get_prompt(_p).contains("rail"), "the horse away from its rail: not for sale (\"%s\")" % t.get_prompt(_p))
	_p.use_interactable(t)
	_check(h.upgrades.is_empty() and Economy.get_scrip(pid) == 10000, "and a use then costs nothing")
	h.mode = Horse.Mode.TIED
	# each piece in turn
	var r0: Dictionary = HorseRules.block("ride")
	var spent: int = 0
	var names: Array = []
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var before: int = Economy.get_scrip(pid)
		_check(t.can_interact(_p) and t.get_prompt(_p).contains(str(row["name"])), "on sale: %s [%d]" % [row["name"], int(row["cost"])])
		_p.use_interactable(t)
		await _frames(3)
		spent += int(row["cost"])
		names.append(str(row["id"]))
		_check(h.upgrades == names and before - Economy.get_scrip(pid) == int(row["cost"]) and h.bought == i + 1, "bought: %s for %d Scrip (the horse wears %s)" % [row["name"], before - Economy.get_scrip(pid), str(h.upgrades)])
	_check(spent == 6000 and Economy.get_scrip(pid) == 10000 - spent, "the whole set cost %d" % spent)
	_check(not t.can_interact(_p) and t.get_prompt(_p).contains("all its tack"), "then nothing is left to buy (\"%s\")" % t.get_prompt(_p))
	_p.use_interactable(t)
	_check(Economy.get_scrip(pid) == 10000 - spent and h.upgrades.size() == 3, "and a use costs nothing")
	# what it changed on this horse
	var r1: Dictionary = h.get("_r")
	_check(float(r1["gallop_speed"]) > float(r0["gallop_speed"]) + 0.5 and float((r1["turn_rate"] as Array)[3]) > float((r0["turn_rate"] as Array)[3]), "shod: gallop %.2f m/s (was %.2f), turn at a gallop %.2f rad/s (was %.2f)" % [float(r1["gallop_speed"]), float(r0["gallop_speed"]), float((r1["turn_rate"] as Array)[3]), float((r0["turn_rate"] as Array)[3])])
	_check(float(HorseRules.block("ride")["gallop_speed"]) == float(r0["gallop_speed"]), "the table itself is as it was (another horse, the next match)")
	var shown: Array = h.get("_tack_nodes")
	var on_model: int = 0
	for n: Variant in shown:
		if n is BoneAttachment3D and (n as Node).get_parent() == h.rig.skel and (n as Node).get_child_count() == 1 and ((n as Node).get_child(0) as Node).get_child_count() > 0:
			on_model += 1
	_check(shown.size() == 6 and on_model == 6, "the tack is on the model: four shoes, the saddle kit, the barding (%d bone attachments)" % on_model)
	_check(h.find_children("*", "CollisionObject3D", true, false).size() == 1, "none of it is a body (the horse's Use area only)")
	# a client is told the same list (net_upgrades): cleaned, applied, drawn
	h.net_upgrades(["barding", "junk", "shoes"])
	_check(h.upgrades == ["shoes", "barding"] and (h.get("_tack_nodes") as Array).size() == 5 and float((h.get("_tab") as Dictionary)["fire"]["sway_gallop"]) == float(HorseRules.block("fire")["sway_gallop"]), "the host's list on a client: %s" % str(h.upgrades))
	h.net_upgrades(["shoes", "saddle", "barding"])
	await _frames(2)
	_check(h.upgrades.size() == 3 and (h.get("_tack_nodes") as Array).size() == 6, "all three again")
	_p.set("_pitch", 0.0)


## The tack felt from the saddle: a faster gallop, a steadier aim, a harder trample that costs less speed.
func _tack_ridden(h: Horse, dir: ZombieDirector) -> void:
	var base: Dictionary = HorseRules.table()
	_gallop_from(h, 5.0)
	h.weapon_override = true
	var top: float = 0.0
	var cone: float = -1.0
	for i: int in 110:
		await get_tree().physics_frame
		top = maxf(top, h.speed)
		if i == 50 and h.rig.gait == HorseGait.Gait.GALLOP and _p.carry_fire:
			cone = _p.carry_spread
	_check(top > float(base["ride"]["gallop_speed"]) + 0.5, "shod it gallops faster (%.2f m/s, unshod %.2f)" % [top, float(base["ride"]["gallop_speed"])])
	_check(absf(cone - float(base["fire"]["spread_gallop_deg"]) * 0.5) < 0.01, "the trooper's saddle halves the gallop's cone (%.2f deg)" % cone)
	h.weapon_override = null
	h.input_override = Vector3.ZERO
	# the trample, barded
	RoundManager.state = RoundManager.State.ROUND
	_place_horse(h, Vector3(8.0, 0, 44.0), -90.0)
	dir.spawn_burst([Vector3(20.0, 0, 44.0)], 1)
	await _secs(4.0)
	var victim: Zombie = null
	for z: Zombie in dir.active_zombies():
		if victim == null or z.global_position.distance_to(Vector3(20.0, 0, 44.0)) < victim.global_position.distance_to(Vector3(20.0, 0, 44.0)):
			victim = z
	_check(victim != null, "one of the dead stands in the barded horse's path")
	if victim != null:
		var waited: float = 0.0
		while victim.state == Zombie.State.EMERGE and waited < 8.0:
			await _secs(0.25)
			waited += 0.25
		if victim.state != Zombie.State.CHASE:
			victim.call("_enter", Zombie.State.CHASE)
		victim.max_hp = 5000.0
		victim.hp = 5000.0
		victim.global_position = Vector3(20.0, 0.0, 44.0)
		var n0: int = h.tramples
		h.pace = 3.0
		h.speed = 9.0
		h.input_override = Vector3(0, 1, 1)
		var before: float = 0.0
		var after: float = 0.0
		for i: int in 150:
			var sp: float = h.speed
			await get_tree().physics_frame
			if h.tramples == n0:
				victim.global_position = Vector3(20.0, victim.global_position.y, 44.0)
				victim.velocity = Vector3.ZERO
				before = sp
			elif after == 0.0:
				after = h.speed
		h.input_override = Vector3.ZERO
		var slow: float = float((h.get("_tab") as Dictionary)["trample"]["slow"])
		_check(h.tramples == n0 + 1 and after > before * (1.0 - slow) - 0.4 and after > before * 0.75, "barded it rides one down and keeps its speed (%.1f -> %.1f m/s; unbarded it would keep %.0f%%)" % [before, after, 100.0 * (1.0 - float(base["trample"]["slow"]))])
		await _secs(1.2)
		var took: float = 5000.0 - victim.hp
		_check(absf(took - float(base["trample"]["damage"]) * 2.5) < 1.0 or not victim.is_active(), "and it is hurt harder where it lands (%.0f, unbarded %.0f)" % [took, float(base["trample"]["damage"])])
	dir.kill_all(true)
	RoundManager.stop()
	await _secs(0.3)


func _finish() -> void:
	print("[horse] RESULT %s (%d checks, %d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
	for f: String in _fails:
		print("[horse]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
