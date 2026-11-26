extends Node
## T-290: what still works on Map 0 after a V2 launch (T-276) in the same session. The trailer worker (T-285) found the
## yard horse would not take a rider once a launch had run. Headless, solo, silent, on the launch smoke's compressed
## timeline (the data's beats scaled down; the blast's rules are the data's):
##   before     the horse takes a rider at its rail (and gets down again): the baseline
##   launch     round 6 by the round rule; the player stands beside the table through the main stage (hurt and
##              pushed, as a player in the clearing is) and the dead round it are killed and thrown; it runs to GONE
##   after      the horse takes a rider again, from the Use ray (the prompt) and by Use; it rides and lets them down;
##              a ladder, a zip line, the Sherman (in and out), Rocket Man's machine and a bought door all still work
##   console    a second launch from the console (`begin_launch` with `t` jumped, as the trailer tool did), the
##              horse again
## Prints "[after_launch] ..." lines and "[after_launch] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_after_launch.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 420.0
const FAST: Dictionary = {"delay": 1.0, "arm_down_at": 1.0, "arm_down_seconds": 2.0, "count_at": 4.0, "ignite_at": 8.0, "main_at": 9.0,
	"liftoff_at": 10.0, "gone_after": 8.0, "rearm_delay": 1.0, "erect_seconds": 3.0}

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_after_launch_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_after_launch_settings.cfg"
	GameState.character_id = &"dutch"
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[after_launch] %-96s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[after_launch] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


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


func _zombie_at(pos: Vector3) -> Zombie:
	var dir: ZombieDirector = _root().director
	var before: Dictionary = {}
	for c: Zombie in dir.active_zombies():
		before[c.get_instance_id()] = true
	dir.debug_spawn(1)
	await _frames(2)
	var z: Zombie = null
	for c2: Zombie in dir.active_zombies():
		if not before.has(c2.get_instance_id()):
			z = c2
	if z != null:
		z.global_position = pos
		z.set_physics_process(false)
	await _frames(1)
	return z


func _state(h: Horse, p: Player) -> String:
	return "mode %d, rider %s, carry %s, alive %s, downed %s, status %s, can_use %s, prompt \"%s\"" % [h.mode, str(h.rider),
		str(p.carry), str(p.is_alive()), str(p.downed), str(p.get("_status")), str(h.can_use(p)), h.use.get_prompt(p)]


## The player beside the horse, facing it, then Use; it must end seated; then down again. `label` names the moment.
func _mount_and_off(h: Horse, label: String) -> void:
	var p: Player = _p()
	if h.mode != Horse.Mode.TIED:
		h.stand_at(h.home_pos.x, h.home_pos.z, rad_to_deg(h.home_yaw))
	await _frames(2)
	p.global_position = h.global_transform * Vector3(-1.3, 0.05, 0.2)
	p.rotation.y = h.rotation.y - PI * 0.5
	p.velocity = Vector3.ZERO
	await _frames(6)
	print("[after_launch] %s: %s" % [label, _state(h, p)])
	var probe: Interactable = p.call("_probe_interactable") as Interactable
	_check(probe == h.use, "%s: the Use ray finds the horse (%s)" % [label, str(probe)])
	_check(h.use.can_interact(p) and h.use.get_prompt(p).contains("ride"), "%s: the horse offers a ride (\"%s\")" % [label, h.use.get_prompt(p)])
	p.use_interactable(h.use)
	await _frames(2)
	_check(h.rider == p and p.carry == h, "%s: Use starts the mount (%s)" % [label, _state(h, p)])
	var seated: bool = await _until(func() -> bool: return h.mode == Horse.Mode.RIDDEN and h.seated(), 4.0)
	_check(seated, "%s: the rider ends in the saddle (mode %d)" % [label, h.mode])
	h.input_override = Vector3(0, 1, 0)
	var x0: Vector3 = h.global_position
	await _secs(1.0)
	h.input_override = Vector3.ZERO
	_check(h.global_position.distance_to(x0) > 0.5, "%s: it walks on (%.1f m)" % [label, h.global_position.distance_to(x0)])
	h.on_use(p)
	var off: bool = await _until(func() -> bool: return h.rider == null and p.carry == null, 4.0)
	_check(off, "%s: the rider gets down again (%s)" % [label, _state(h, p)])
	await _secs(1.4)   # (the body is solid to the rider again after 1.2 s)
	h.stand_at(h.home_pos.x, h.home_pos.z, rad_to_deg(h.home_yaw))
	await _frames(2)


func _run() -> void:
	GameState.bot_count = 0
	GameState.god_mode = false
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
	GLConsole.run("open_doors")
	for z: String in ["YARD", "GROUNDS", "STABLE", "FORSTWEG", "STELLUNG"]:
		GameState.open_zone(StringName(z))
	Economy.award(_p().player_id, 50000)
	var horses: Array = get_tree().get_nodes_in_group(&"horses")
	var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
	_check(horses.size() == 1 and rl != null, "the yard horse and the V2 are on the map")
	if horses.is_empty() or rl == null:
		_finish()
		return
	var h: Horse = horses[0] as Horse

	# ---- before: the baseline
	await _mount_and_off(h, "before the launch")

	# ---- the launch by the round rule, the player beside the table through the main stage
	rl.cfg = rl.cfg.duplicate(true)
	rl.cfg.merge(FAST, true)
	var site: Vector3 = rl.global_position
	_p().global_position = site + Vector3(-1.5, 0.05, -4.2)
	_p().velocity = Vector3.ZERO
	RoundManager.debug_set_round(6)
	await _until(func() -> bool: return RoundManager.current_round == 6 and RoundManager.state == RoundManager.State.ROUND, 30.0)
	RoundManager.to_spawn = 0
	_root().director.kill_all(true)
	var began: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.SEQUENCE, 5.0)
	_check(began, "round 6: the launch begins")
	await _until(func() -> bool: return rl.t > float(FAST["ignite_at"]) - 1.5, 15.0)
	for off: Vector3 in [Vector3(3.0, 0, 3.0), Vector3(-2.5, 0, 3.5), Vector3(9.0, 0, 3.0), Vector3(2.0, 0, -9.5)]:
		await _zombie_at(site + off)
	_p().global_position = site + Vector3(-1.5, 0.05, -4.2)
	_p().velocity = Vector3.ZERO
	var hp0: float = _p().hp
	await _until(func() -> bool: return rl.t > float(FAST["main_at"]) + 0.3, 10.0)
	_check(int(rl.last_blast.get("killed", 0)) >= 2 and int(rl.last_blast.get("thrown", 0)) >= 2 and _p().hp < hp0, "the main stage killed, threw and hurt (%s, %.0f hp lost)" % [str(rl.last_blast), hp0 - _p().hp])
	_p().global_position = site + Vector3(-12.0, 0.05, -14.0)   # out of the fire
	_p().velocity = Vector3.ZERO
	var gone: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.GONE, 40.0)
	_check(gone, "the rocket is gone")
	RoundManager.stop()
	_root().director.kill_all(true)
	await _secs(0.5)

	# ---- after: the horse
	await _mount_and_off(h, "after the launch")

	# ---- after: a ladder
	var lad: LadderClimb = null
	for n: Node in get_tree().get_nodes_in_group(&"ladders"):
		var l: LadderClimb = n as LadderClimb
		if l != null and not l.down and l.can_interact(_p()):
			lad = l
			break
	_check(lad != null, "after: a ladder offers a climb")
	if lad != null:
		_p().global_position = Vector3(lad.line_pos().x, lad.rung_base() + 0.05, lad.line_pos().y) - lad.face_dir() * 0.6
		_p().velocity = Vector3.ZERO
		await _frames(3)
		lad.interact(_p())
		await _frames(2)
		_check(_p().carry == lad, "after: Use starts the climb (%s)" % str(lad.name))
		var done: bool = await _until(func() -> bool: return _p().carry == null, 20.0)
		_check(done and _p().is_physics_processing(), "after: the climb ends and the player moves again")

	# ---- after: a zip line
	var zip: ZipLine = null
	for n2: Node in get_tree().get_nodes_in_group(&"ziplines"):
		var zl: ZipLine = n2 as ZipLine
		if zl != null and zl.can_interact(_p()):
			zip = zl
			break
	_check(zip != null, "after: a zip line offers a ride")
	if zip != null:
		_p().global_position = zip.mount_pos(zip.global_position.y)
		_p().velocity = Vector3.ZERO
		await _frames(2)
		zip.ride(_p())
		await _frames(2)
		_check(_p().carry == zip, "after: the zip line carries the player (%s)" % str(zip.name))
		var landed: bool = await _until(func() -> bool: return _p().carry == null, 20.0)
		_check(landed, "after: the ride lands and lets go")

	# ---- after: the Sherman, in and out
	var ev: ShermanEvent = _map.get_node_or_null("ShermanEvent") as ShermanEvent
	_check(ev != null, "after: the Sherman event is on the map")
	if ev != null:
		ev.force_assist()
		await _until(func() -> bool: return ev.tank != null and is_instance_valid(ev.tank) and ev.tank.drivable and ev.tank.mode == ShermanTank.Mode.PARKED, 10.0)
		var tk: ShermanTank = ev.tank
		if tk != null:
			_p().global_position = tk.global_transform * Vector3(2.6, 0.05, 0.5)
			_p().velocity = Vector3.ZERO
			await _frames(3)
			_check(tk.can_use(_p()), "after: the Sherman may be boarded (%s)" % tk.prompt_for(_p()))
			tk.use.interact(_p())
			var seated: bool = await _until(func() -> bool: return tk.seat == ShermanTank.Seat.SEATED, 4.0)
			_check(seated and _p().carry == tk, "after: the player is seated in the Sherman")
			tk.on_use(_p())
			var out: bool = await _until(func() -> bool: return tk.seat == ShermanTank.Seat.NONE and _p().carry == null, 5.0)
			_check(out, "after: and climbs out again")
			ev.set_process(false)
			ev.set_physics_process(false)

	# ---- after: Rocket Man and a door
	var rm: PerkMachine = null
	for n3: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		if n3 is PerkMachine and (n3 as PerkMachine).perk_id == &"rocket_man":
			rm = n3 as PerkMachine
	_check(rm != null, "after: Rocket Man's machine is in the dugout")
	if rm != null:
		_check(rm.can_interact(_p()), "after: it sells (\"%s\")" % rm.get_prompt(_p()))
		rm.interact(_p())
		await _until(func() -> bool: return PerkManager.has_perk(_p().player_id, &"rocket_man"), 6.0)
		_check(PerkManager.has_perk(_p().player_id, &"rocket_man"), "after: the player holds Rocket Man")
	var door: BuyDoor = null
	for n4: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n4 as BuyDoor
		if d != null and not d.is_open and d.can_interact(_p()):
			door = d
			break
	if door == null:
		# (open_doors opened them all at the start: close one again to buy it)
		for n5: Node in get_tree().get_nodes_in_group(&"doors"):
			if n5 is BuyDoor and not (n5 as BuyDoor).boss_locked and not (n5 as BuyDoor).requires_power:
				door = n5 as BuyDoor
				break
		if door != null:
			door.is_open = false
	_check(door != null and door.can_interact(_p()), "after: a shut door offers itself (%s)" % (str(door.door_id) if door != null else "none"))
	if door != null:
		door.interact(_p())
		await _frames(2)
		_check(door.is_open, "after: buying it opens it")

	# ---- a console launch with the clock jumped (the trailer tool's way), then the horse again
	rl.begin_launch()
	rl.t = float(FAST["ignite_at"]) - 0.5
	var gone2: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.GONE, 40.0)
	_check(gone2 and rl.launches == 2, "a second launch from the console runs to the end (%d launches)" % rl.launches)
	await _mount_and_off(h, "after a console launch")

	# ---- the trailer's order (T-285 game_m0: g06/g07 board the Sherman, g09/g10 the launch, g12 the horse): the
	# player was still in the tank (g07's tank_in boards again and no shot gets out), so the horse said no. One
	# carrier at a time is the rule; out of the tank, the horse takes them.
	if ev != null and ev.tank != null and is_instance_valid(ev.tank):
		var tk2: ShermanTank = ev.tank
		ev.force_assist()
		await _frames(10)
		_p().global_position = tk2.global_transform * Vector3(2.6, 0.05, 0.5)
		_p().velocity = Vector3.ZERO
		await _frames(3)
		tk2.use.interact(_p())
		await _until(func() -> bool: return tk2.seat == ShermanTank.Seat.SEATED, 4.0)
		rl.begin_launch()
		rl.t = float(FAST["ignite_at"]) - 0.5
		await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.GONE, 40.0)
		h.stand_at(h.home_pos.x, h.home_pos.z, rad_to_deg(h.home_yaw))
		_p().global_position = h.global_transform * Vector3(-1.3, 0.05, 0.2)
		h.ride(_p())
		await _frames(2)
		_check(_p().carry == tk2 and h.rider == null, "the trailer's case: a player still in the Sherman is not given the horse (carry %s)" % str(_p().carry))
		tk2.put_out()
		await _until(func() -> bool: return _p().carry == null, 3.0)
		await _mount_and_off(h, "out of the Sherman")
	_finish()
