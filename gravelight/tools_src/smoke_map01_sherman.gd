extends Node
## T-272: the round-30 Sherman on Kaltenbrunn (map01.json sherman_event; ShermanEvent, ShermanTank, YardGate, AirRaid),
## headless, solo, silent. The same event as the Inn's (smoke_sherman), on this map's ground:
##   round 30  the rounds are reserved; der Fuhrmann's round begins too; the Sherman starts on the rail line's terrace
##             north of the yard; the north gate swings open for it; it comes through the gateway between the pillars
##             (its hull clear of both) and the gate shuts behind it; it parks in the forecourt facing the yard; this
##             map's banner; der Fuhrmann comes in by the gate; every attack point on the hull is on the navmesh; the
##             assault rises in the Minehead yard round it (on the navmesh, 10..16 m off), the dead beat on the hull, the
##             team kills them: it HOLDS, a Resupply is thrown on walkable ground;
##   driving   a player climbs in; driven at the hoist house and back at the gate it stops inside the forecourt both
##             ways (never in a lane, never in the gateway); a pivot; out beside the hull on the navmesh;
##   assist    the machine gun on the dead coming in through the north-east corner, nothing on the player;
##   round 40  the dive bomber's bomb lands on the tank: a wreck; the raid: the Kaue's roof shelters, a bomb by a player
##             in the open forecourt hurts them, one by the Kaue's front spares the same player inside; the all clear.
## Prints "[m1sherman] ..." lines and "[m1sherman] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_sherman.tscn

const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 900.0
const KAUE: Vector3 = Vector3(10.0, 0.05, 29.5)      # inside the Waschkaue, under its roof
const FORECOURT_BOX: Array = [15.2, 0.4, 24.8, 9.7]

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0
var _drops: Array[String] = []
var _drop_at: Array[Vector3] = []
var _hurt: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_m1sherman_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m1sherman_settings.cfg"
	GLSettings.values["homage_bosses"] = true
	GameState.character_id = &"dutch"
	Campaign.reset()
	GLBus.powerup_spawned.connect(func(id: StringName, p: Vector3) -> void:
		_drops.append(String(id))
		_drop_at.append(p))
	GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
		_hurt[pid] = float(_hurt.get(pid, 0.0)) + amount)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[m1sherman] %-100s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[m1sherman] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float, each: Callable = Callable()) -> bool:
	var t: float = 0.0
	while t < seconds:
		if each.is_valid():
			each.call()
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _dir() -> ZombieDirector:
	return _root().director


func _p() -> Player:
	return _root().player


func _ev() -> ShermanEvent:
	return _map.get_node_or_null("ShermanEvent") as ShermanEvent


func _gate() -> Node3D:
	return get_tree().get_first_node_in_group(&"yard_gate") as Node3D


func _place(p: Player, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _nav_gap(p: Vector3) -> float:
	var q: Vector3 = NavigationServer3D.map_get_closest_point(_map.get_world_3d().navigation_map, p + Vector3.UP * 0.3)
	return Vector2(q.x - p.x, q.z - p.z).length() if absf(q.y - p.y) < 1.0 else INF


## The round's horde that is not the tank's (not under test) goes down; the horse is kept.
func _cull_horde() -> void:
	var ev: ShermanEvent = _ev()
	for z: Zombie in _dir().active_zombies():
		if z is HomageBoss or (ev != null and ev.attackers.has(z)):
			continue
		z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


func _quiet() -> void:
	RoundManager.to_spawn = 0
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


func _kill_horse() -> void:
	var hr: HorseRound = _map.get_node_or_null("HorseRound_30") as HorseRound
	if hr != null:
		for b: HorseBoss in hr.horses():
			if is_instance_valid(b) and b.hp > 0.0:
				b.take_damage(b.hp + 1.0, &"torso", &"m1911", 1, &"bullet")


func _in_box(xf: Transform3D) -> bool:
	return ShermanRules.in_boxes(xf.origin, [FORECOURT_BOX]) and ShermanRules.may_stand(xf, [], {"drive_boxes": [FORECOURT_BOX]})


func _run() -> void:
	GameState.bot_count = 0
	GameState.god_mode = true
	_map = (load(MAP1) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await _secs(1.0)
	GameState.god_mode = true
	_p().set_process_unhandled_input(false)
	_dir().kill_all(true)
	var ev: ShermanEvent = _ev()
	_check(ev != null and ev.has_tank and ev.arrive_round == 30 and ev.stuka_round == 40, "map01: the full event is on (a tank, rounds 30 and 40)")
	if ev == null or not ev.has_tank:
		_finish()
		return
	_check(RoundManager.is_reserved(30) and RoundManager.is_reserved(40), "rounds 30 and 40 are reserved")
	_check(_gate() != null and not bool(_gate().get("opened")), "the north gate is there, shut")
	_check(str(ev.cfg["arrival"]["banner"]) == "ARMOUR AT THE NORTH GATE" and str(ShermanEvent.table()["arrival"]["banner"]) != "ARMOUR AT THE NORTH GATE",
		"this map's arrival banner ('%s'); the shared table is untouched" % str(ev.cfg["arrival"]["banner"]))
	await _round30(ev)
	await _driving(ev)
	await _assist(ev)
	await _round40(ev)
	_finish()


# ================================================================== round 30

func _round30(ev: ShermanEvent) -> void:
	_place(_p(), KAUE)
	ev.cfg = ev.cfg.duplicate(true)
	ev.cfg["arrival"]["assault_after_park"] = 600.0   # (begun by hand below, once the gate and the parking are checked)
	RoundManager.debug_set_round(30)
	await _until(func() -> bool: return RoundManager.current_round == 30 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	var hr: HorseRound = _map.get_node_or_null("HorseRound_30") as HorseRound
	_check(ev.phase == ShermanEvent.Phase.ARRIVING, "round 30: the Sherman is coming")
	_check(hr != null and hr.phase == HomageEncounter.Phase.ACTIVE, "round 30: der Fuhrmann's round begins too")
	await _until(func() -> bool: return ev.tank != null, 3.0)
	var tk: ShermanTank = ev.tank
	_check(tk != null and tk.global_position.z < -20.0, "it starts on the rail line's terrace north of the yard (z %.1f)" % (tk.global_position.z if tk != null else 0.0))
	if tk == null:
		return
	var gate: Node3D = _gate()
	var gx: Array = []          # the hull's x each frame part of it is in the gateway
	var gate_open_at: Array = [INF]
	var watch: Callable = func() -> void:
		_cull_horde()
		if tk.global_position.z > -4.2 and tk.global_position.z < 3.2:   # some of the hull is between the pillars (z -1.2..0.15)
			gx.append(tk.global_position.x)
		if gate != null and bool(gate.get("opened")) and gate_open_at[0] == INF:
			gate_open_at[0] = tk.global_position.distance_to(gate.global_position)
	var parked: bool = await _until(func() -> bool: return tk.parked() and tk.route.is_empty() and ev.t > 3.0, 60.0, watch)
	var park_t: float = ev.t
	_check(parked and tk.global_position.distance_to(ev.park_point()) < 0.6, "it parks in the forecourt (%.2f m off the park point, t %.1f s)" % [tk.global_position.distance_to(ev.park_point()), park_t])
	_check(gate != null and int(gate.get("opens")) == 1 and float(gate_open_at[0]) < 17.0 and float(gate_open_at[0]) > 6.0, "the gate swings open for it as it comes (%.1f m off)" % float(gate_open_at[0]))
	var worst: float = 0.0
	for x: float in gx:
		worst = maxf(worst, absf(x - 20.0))
	# the gateway is 4.8 m (x 17.6..22.4), the hull 2.62: its centre within 1.0 m of the middle keeps both sides clear
	_check(not gx.is_empty() and worst < 1.0, "it comes through the gateway between the pillars (%d frames, centre at most %.2f m off the middle)" % [gx.size(), worst])
	var fwd: Vector3 = -tk.global_transform.basis.z
	_check(fwd.dot(Vector3(0, 0, 1)) > 0.97, "facing the yard (south)")
	_check(_in_box(tk.global_transform), "parked inside the forecourt's drive box")
	var shut: bool = await _until(func() -> bool: return not bool(gate.get("opened")), 4.0, _cull_horde)
	await _secs(3.0)
	var lw: Node3D = gate.get_node_or_null("LeafW") as Node3D
	_check(shut and lw != null and absf(lw.rotation.y) < 0.02, "the gate shuts behind it (leaf at %.1f degrees)" % (rad_to_deg(lw.rotation.y) if lw != null else 99.0))
	var aps_ok: int = 0
	for ap: ShermanAttackPoint in tk.points:
		if _nav_gap(ap.global_position) < 0.9 and String(ZoneVolume.zone_at(get_tree(), ap.global_position + Vector3.UP * 0.6)) == "A_MINEHEAD":
			aps_ok += 1
	_check(aps_ok == tk.points.size() and aps_ok > 0, "every attack point on the hull is on the yard's navmesh (%d of %d)" % [aps_ok, tk.points.size()])
	var horse_in: bool = await _until(func() -> bool: return hr != null and not hr.horses().is_empty(), 16.0, _cull_horde)
	_check(horse_in and hr.horses()[0].global_position.z < 8.0 and hr.t > park_t - 2.0, "der Fuhrmann comes in by the gate as it parks (t %.1f s, z %.1f)" % [hr.t if hr != null else 0.0, hr.horses()[0].global_position.z if horse_in else 99.0])
	ev._sched.clear()
	ev.begin_assault()
	var on: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSAULT, 12.0, _cull_horde)
	var ring_ok: bool = not ev._ring.is_empty()
	for q: Vector3 in ev._ring:
		var dq: float = ShermanRules.flat(q, tk.global_position)
		if dq < 8.4 or dq > 17.6 or String(ZoneVolume.zone_at(get_tree(), q + Vector3.UP * 0.6)) != "A_MINEHEAD" or _nav_gap(q) > 0.6:
			ring_ok = false
	_check(on and ring_ok, "the assault: the dead rise round it in the Minehead yard (%d ring points, all on the navmesh, 10..16 m off)" % ev._ring.size())
	var sw_a: int = tk.swipes_taken
	var hit: bool = await _until(func() -> bool: return tk.swipes_taken >= sw_a + 3, 50.0, _cull_horde)
	_check(hit and tk.hp < tk.max_hp, "the dead reach the hull and beat on it (%d swipes, %d of %d health)" % [tk.swipes_taken - sw_a, int(tk.hp), int(tk.max_hp)])
	var held: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSIST, 150.0, func() -> void:
		_cull_horde()
		for z2: Zombie in ev.attackers.duplicate():
			if is_instance_valid(z2) and z2.is_active() and z2.state != Zombie.State.EMERGE:
				z2.take_damage(z2.hp + 1.0, &"head", &"m1911", 1, &"bullet"))
	_check(held and ev.outcome == "held" and not tk.is_wreck(), "the team beats them off: THE SHERMAN HOLDS (%d of %d health)" % [int(tk.hp), int(tk.max_hp)])
	var ri: int = _drops.rfind("resupply")   # (the last: the culled horde may drop one of its own)
	var rp: Vector3 = _drop_at[ri] if ri >= 0 else Vector3.INF
	_check(ri >= 0 and _nav_gap(Vector3(rp.x, 0.0, rp.z)) < 0.8, "a Resupply is thrown on walkable ground in front of it (%s)" % str(rp.snapped(Vector3.ONE * 0.1)))


# ================================================================== a player drives it

func _driving(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	if tk == null:
		return
	var p: Player = _p()
	_kill_horse()   # (der Fuhrmann charging about the forecourt stops the hull like anyone in its way)
	_place(p, tk.global_transform * Vector3(2.6, 0.05, 0.5))
	var to_hull: Vector3 = tk.global_transform.basis * Vector3(-1, 0, 0)
	p.rotation.y = atan2(-to_hull.x, -to_hull.z)
	for i: int in 6:
		_cull_horde()
		await get_tree().physics_frame
	_check(tk.drivable and tk.can_use(p) and p.call("_probe_interactable") == tk.use, "parked: the player's Use ray finds the hull ('%s')" % tk.prompt_for(p))
	tk.use.interact(p)
	var seated: bool = await _until(func() -> bool: return tk.seat == ShermanTank.Seat.SEATED, 3.0, _cull_horde)
	_check(seated and tk.driver == p, "the player climbs in")
	var outside: Array = [0]
	var cam_in_wall: Array = [0, 99.0]
	var keep_in: Callable = func() -> void:
		_cull_horde()
		if not _in_box(tk.global_transform):
			outside[0] = int(outside[0]) + 1
		# T-278: the orbit camera in the walled forecourt: never inside a wall (the spring arm)
		if tk.cam != null and is_instance_valid(tk.cam) and tk.cam.blend >= 0.999:
			var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var sph: SphereShape3D = SphereShape3D.new()
			sph.radius = 0.12
			sq.shape = sph
			sq.transform = Transform3D(Basis.IDENTITY, tk.cam.global_position)
			sq.collision_mask = TankCamera.MASK_ARM
			if not tk.get_world_3d().direct_space_state.intersect_shape(sq, 1).is_empty():
				cam_in_wall[0] = int(cam_in_wall[0]) + 1
			cam_in_wall[1] = minf(float(cam_in_wall[1]), tk.cam.dist_shown)
	_check(tk.cam != null and get_viewport().get_camera_3d() == tk.cam and p.carry_sight, "T-278: the driver's view is the tank's orbit camera")
	# the view swung round the forecourt while it drives: walls behind the camera on every side
	var swing: Callable = func() -> void:
		keep_in.call()
		p.rotation.y += 0.04
	# forward at the hoist house, then back at the gate: refused both ways inside the forecourt
	for way: Array in [[1.0, "the hoist house"], [-1.0, "the gate"]]:
		var r0: int = tk.refusals
		tk.input_override = Vector3(0, float(way[0]), 0)
		var stopped: bool = await _until(func() -> bool: return tk.refusals > r0 and absf(tk.speed) < 0.05, 12.0, swing)
		print("[m1sherman] note: stopped at %s heading %.0f" % [str(tk.global_position.snapped(Vector3.ONE * 0.01)), rad_to_deg(tk.rotation.y)])
		tk.input_override = Vector3(0, 0, 0)
		var bow: Vector3 = tk.global_transform * Vector3(0, 0, ShermanRules.HULL_BOW if float(way[0]) > 0.0 else ShermanRules.HULL_STERN)
		_check(stopped and _in_box(tk.global_transform), "driven at %s it stops inside the forecourt (that end at z %.1f)" % [str(way[1]), bow.z])
	# (a pivot sweeps a 6.5 m circle: from the middle of the forecourt only, so it is driven back there first)
	tk.input_override = Vector3(0, 1, 0)
	await _until(func() -> bool: return tk.global_position.z > 4.8, 6.0, keep_in)
	tk.input_override = Vector3(0, 0, 0)
	await _until(func() -> bool: return absf(tk.speed) < 0.05, 3.0, keep_in)
	var yaw0: float = tk.rotation.y
	tk.input_override = Vector3(1, 0, 0)
	await _until(func() -> bool: return false, 2.0, keep_in)
	tk.input_override = Vector3(0, 0, 0)
	print("[m1sherman] note: pivot from %s" % str(tk.global_position.snapped(Vector3.ONE * 0.01)))
	_check(absf(wrapf(tk.rotation.y - yaw0, -PI, PI)) > 0.5, "a pivot on the spot (%.0f degrees in 2 s)" % rad_to_deg(absf(wrapf(tk.rotation.y - yaw0, -PI, PI))))
	_check(int(outside[0]) == 0, "never a frame with the hull outside the forecourt's box (%d)" % int(outside[0]))
	_check(int(cam_in_wall[0]) == 0, "T-278: the orbit camera never inside a wall in the forecourt (%d frames; the boom down to %.1f m at the closest)" % [int(cam_in_wall[0]), float(cam_in_wall[1])])
	tk.dismount_wanted = true
	var out: bool = await _until(func() -> bool: return tk.driver == null, 3.0, _cull_horde)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(p.camera.current and get_viewport().get_camera_3d() == p.camera and not p.carry_sight and p.carry_look_mult == 1.0, "T-278: out of the tank, the player's own camera again")
	_check(out and p.carry == null and not tk.near_hull(p.global_position, 0.2) and _nav_gap(p.global_position) < 1.2, "the driver climbs out beside the hull, on walkable ground")
	tk.park_at(ev.park_point(), ev.park_yaw())


# ================================================================== the assist

func _assist(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	if tk == null:
		return
	_kill_horse()
	_cull_horde()
	_place(_p(), KAUE)
	_hurt.clear()
	var mg0: int = tk.shots_mg
	var hits0: int = tk.mg_hits
	# the north-east corner: the window W_A_N2 and the yard's ground spawn, in its sight past the winding house
	var made: int = _dir().spawn_burst([Vector3(34.0, 0.0, 2.4), Vector3(35.5, 0.0, 2.8), Vector3(36.5, 0.0, 2.2)], 3)
	var shot: bool = await _until(func() -> bool: return tk.shots_mg > mg0 + 2 and tk.mg_hits > hits0, 30.0, func() -> void:
		tk._gun_t = 10.0)
	tk._gun_t = 0.0
	_check(made > 0 and shot, "it covers the yard: the machine gun on the dead coming in at the north-east corner (%d rounds, %d hits)" % [tk.shots_mg - mg0, tk.mg_hits - hits0])
	_check(float(_hurt.get(1, 0.0)) == 0.0, "nothing on the player")
	_quiet()


# ================================================================== round 40

func _round40(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	_dir().kill_all(true)
	_place(_p(), KAUE)
	RoundManager.debug_set_round(40)
	await _until(func() -> bool: return RoundManager.current_round == 40 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	_check(ev.phase == ShermanEvent.Phase.STUKA, "round 40: the dive bomber")
	var hit: bool = await _until(func() -> bool: return ev.stuka_hit_at != Vector3.INF, 30.0, _cull_horde)
	_check(hit and tk != null and ev.stuka_hit_at.distance_to(tk.global_position) < 3.0, "the bomb lands on the Sherman in the forecourt")
	_check(tk != null and is_instance_valid(tk) and tk.is_wreck(), "it brews up and stays, a burning wreck")
	var warned: bool = await _until(func() -> bool: return ev.raid.phase == AirRaid.Phase.WARN, 6.0, _cull_horde)
	_check(warned and ev.raid.is_sheltered(KAUE) and not ev.raid.is_sheltered(Vector3(20.0, 0.05, 9.0)), "the air raid: the Kaue's roof shelters, the forecourt does not")
	ev.raid.phase = AirRaid.Phase.BOMBING
	ev.raid.t = 0.0
	ev.raid.cfg = (ev.raid.cfg as Dictionary).duplicate()
	ev.raid.cfg["duration"] = 10.0
	GameState.god_mode = false
	_p().max_hp = 1000.0
	_p().hp = 1000.0
	_place(_p(), Vector3(14.0, 0.05, 6.0))
	for i: int in 20:
		_quiet()
		await get_tree().physics_frame
	var h0: float = _p().hp
	var out_at: Vector3 = Vector3(14.6, 0.0, 7.0)
	ev.raid.drop(out_at)
	await _until(func() -> bool: return ev.raid.last_impacts.has(out_at), 6.0, _quiet)
	_check(_p().hp < h0 - 50.0, "a bomb by a player in the open forecourt hurts them (%d -> %d)" % [int(h0), int(_p().hp)])
	_place(_p(), KAUE)
	await _secs(0.2)
	var h1: float = _p().hp
	var front: Vector3 = Vector3(10.0, 0.0, 24.0)
	ev.raid.drop(front)
	var landed: bool = await _until(func() -> bool: return ev.raid.last_impacts.has(front), 6.0, _quiet)
	_check(landed and absf(_p().hp - h1) < 0.5, "a bomb in front of the Kaue spares the same player inside it (%d -> %d)" % [int(h1), int(_p().hp)])
	GameState.god_mode = true
	var clear: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.DONE, 40.0, _cull_horde)
	_check(clear, "the all clear")
	_check(tk != null and is_instance_valid(tk) and tk.is_wreck() and _in_box(tk.global_transform), "the wreck stays in the forecourt, out of the lanes")
	print("[m1sherman] %s" % ev.status())
