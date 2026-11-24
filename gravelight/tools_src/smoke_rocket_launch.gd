extends Node
## T-276: the V2 launch at Map 0's site (RocketLaunch, map00.json "rocket_launch"), headless, solo, silent, on a
## compressed timeline (the data's beats scaled down; the order and the rules are the data's):
##   ready      a rocket on the table, the arm up beside it, round 6 a launch round, round 5 not
##   round 6    the sequence starts `delay` s into the round; the arm lowers before the count; the count runs
##   ignition   the main stage: the dead within kill_radius die, those within throw_radius are thrown, those past it
##              are untouched; a player beside the table is hurt (less than a down); the ground burns (FirePatch)
##   lift-off   the rocket rises off the table, slowly first, climbs and pitches east, and is gone; the table is
##              empty, the arm down, the flag says so
##   rearm      the next round a new rocket is raised on the arm and stands ready on the table again
## Prints "[rocket_launch] ..." lines and "[rocket_launch] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_rocket_launch.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 300.0
const FAST: Dictionary = {"delay": 1.0, "arm_down_at": 1.0, "arm_down_seconds": 2.0, "count_at": 4.0, "ignite_at": 14.0, "main_at": 15.0,
	"liftoff_at": 16.0, "gone_after": 22.0, "rearm_delay": 1.0, "erect_seconds": 3.0}

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_rocket_launch_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_rocket_launch_settings.cfg"
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
	print("[rocket_launch] %-92s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[rocket_launch] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
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
	var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
	_check(rl != null and rl.rocket != null and rl.phase == RocketLaunch.Phase.READY, "a rocket stands on the table, ready")
	if rl == null:
		_finish()
		return
	_check(absf(rl.arm_pivot.rotation.z) < 0.01, "the erector arm is up beside it")
	_check(rl.rocket.global_position.distance_to(rl.global_position + Vector3(0, RocketSite.TABLE_TOP, 0)) < 0.05, "standing on the table's ring")
	_check(RocketLaunch.is_launch_round(6, rl.cfg) and not RocketLaunch.is_launch_round(5, rl.cfg), "round 6 launches, round 5 does not")
	rl.cfg = rl.cfg.duplicate(true)
	rl.cfg.merge(FAST, true)
	# the player stands 4 m from the table (to be hurt by the main stage), out of the dead's way otherwise
	_p().global_position = rl.global_position + Vector3(-1.5, 0.05, -4.2)
	_p().velocity = Vector3.ZERO
	RoundManager.debug_set_round(6)
	await _until(func() -> bool: return RoundManager.current_round == 6 and RoundManager.state == RoundManager.State.ROUND, 30.0)
	RoundManager.to_spawn = 0
	_root().director.kill_all(true)
	var began: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.SEQUENCE, 5.0)
	_check(began, "round 6: the sequence starts %.0f s into the round" % float(FAST["delay"]))
	await _until(func() -> bool: return rl.t > float(FAST["count_at"]) + 0.5, 10.0)
	_check(absf(rl.arm_pivot.rotation.z - PI * 0.5) < 0.05, "the arm is down before the count")
	await _until(func() -> bool: return rl.t > float(FAST["count_at"]) + 3.5, 10.0)
	_check(rl._count_shown >= 5 and rl._count_shown <= 7, "the count is running (%d)" % rl._count_shown)
	# the dead round the table, placed just before the main stage
	await _until(func() -> bool: return rl.t > float(FAST["ignite_at"]) - 1.5, 15.0)
	var site: Vector3 = rl.global_position
	var near: Array = [await _zombie_at(site + Vector3(3.0, 0, 3.0)), await _zombie_at(site + Vector3(-2.5, 0, 3.5))]
	var mid: Array = [await _zombie_at(site + Vector3(9.0, 0, 3.0)), await _zombie_at(site + Vector3(2.0, 0, -9.5))]
	var far: Zombie = await _zombie_at(site + Vector3(18.0, 0, 12.0))
	var far_hp: float = far.hp if far != null else 0.0
	_p().global_position = site + Vector3(-1.5, 0.05, -4.2)
	_p().velocity = Vector3.ZERO
	var hp0: float = _p().hp
	await _until(func() -> bool: return rl.t > float(FAST["main_at"]) + 0.3, 10.0)
	var killed: int = 0
	for z: Variant in near:
		if z == null or not is_instance_valid(z) or not (z as Zombie).is_active():
			killed += 1
	_check(killed == 2 and int(rl.last_blast.get("killed", 0)) >= 2, "the main stage kills the dead by the table (%d of 2; blast: %s)" % [killed, str(rl.last_blast)])
	_check(int(rl.last_blast.get("thrown", 0)) >= 2, "and throws those further out (%d)" % int(rl.last_blast.get("thrown", 0)))
	_check(far != null and is_instance_valid(far) and far.is_active() and far.hp >= far_hp, "one 21 m off is untouched")
	var lost: float = hp0 - _p().hp
	_check(lost > 5.0 and lost < 100.0, "the player beside the table is hurt, not downed (%.0f)" % lost)
	var fire: bool = false
	for n: Node in get_tree().current_scene.get_children():
		if n is FirePatch and (n as Node3D).global_position.distance_to(site) < 2.0:
			fire = true
	_check(fire, "the ground round the table burns")
	_p().global_position = site + Vector3(-12.0, 0.05, -14.0)   # out of the fire
	_p().velocity = Vector3.ZERO
	# lift-off and the climb
	await _until(func() -> bool: return rl.t > float(FAST["liftoff_at"]) + 1.0, 10.0)
	var y1: float = rl.rocket.global_position.y
	_check(y1 > site.y + RocketSite.TABLE_TOP and y1 < site.y + RocketSite.TABLE_TOP + 3.0, "1 s after lift-off it is just off the table (%.2f m up)" % (y1 - RocketSite.TABLE_TOP))
	await _until(func() -> bool: return rl.t > float(FAST["liftoff_at"]) + 9.0, 15.0)
	var p9: Vector3 = rl.rocket.global_position
	_check(p9.y > 60.0, "9 s after lift-off it is high (%.0f m)" % p9.y)
	_check(p9.x > site.x + 1.0, "and pitching over to the east (%.1f m)" % (p9.x - site.x))
	await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.GONE, 30.0)
	_check(rl.phase == RocketLaunch.Phase.GONE and not rl.rocket.visible, "it is gone; the table stands empty")
	_check(int(GameState.flags.get(RocketLaunch.FLAG, 0)) == 1, "the flag a late joiner reads says so")
	# the next round: a new rocket raised
	RoundManager.to_spawn = 0
	_root().director.kill_all(true)
	var next: bool = await _until(func() -> bool: return RoundManager.current_round == 7 and RoundManager.state == RoundManager.State.ROUND, 60.0)
	_check(next, "round 7 begins")
	var erecting: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.ERECTING, 5.0)
	_check(erecting and rl.rocket.get_parent() == rl.arm_pivot, "a new rocket lies on the arm and is being raised")
	var up: bool = await _until(func() -> bool: return rl.phase == RocketLaunch.Phase.READY, 10.0)
	_check(up and rl.rocket.get_parent() == rl and rl.rocket.global_position.distance_to(site + Vector3(0, RocketSite.TABLE_TOP, 0)) < 0.05, "and stands ready on the table again")
	_check(int(GameState.flags.get(RocketLaunch.FLAG, 1)) == 0, "the flag says ready")
	_check(not RocketLaunch.is_launch_round(7, rl.cfg) and RocketLaunch.is_launch_round(11, rl.cfg), "the next launch is round 11")
	_check(rl.launches == 1, "one launch")
	_finish()
