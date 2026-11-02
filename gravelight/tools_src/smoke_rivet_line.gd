extends Node
## Headless smoke for Werk Thalbach's rivet line (UPDATE 10 Act I, contract C6 `rivet_line`, DECISIONS T-155):
## the lever and the trap are placed in Montage 1; without the power the lever refuses; with it the lever takes the
## price and starts the gantry after the klaxon; the carriage runs the hall's south aisle end to end; a zombie under
## its path is riveted, one beside the strip lives; a player under it is hit; bots keep out of the strip while it
## runs; it stops after `duration` s and cools down for `cooldown` s (traps.json rivet_line).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_rivet_line.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _hits: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_rivet.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_pid: int, _a: float) -> void: _hits += 1)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	print("[rivet] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


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
	RoundManager.stop()
	_dir.kill_all(true)
	Economy.grant(1, 100000)
	var trap: RivetLineTrap = _map.get_node_or_null("Gameplay/Trap_RivetLine") as RivetLineTrap
	var lever: TrapLever = _map.get_node_or_null("Gameplay/Lever_RivetLine") as TrapLever
	_check(trap != null and lever != null, "Trap_RivetLine and Lever_RivetLine are placed")
	if trap == null or lever == null:
		_finish()
		return
	var cfg: Dictionary = TrapLever.cfg_for("rivet_line")
	_check(is_equal_approx(float(cfg["duration"]), 25.0) and is_equal_approx(float(cfg["cooldown"]), 60.0), "traps.json: 25 s run, 60 s cooldown")
	var lz: String = ZoneVolume.zone_at(get_tree(), lever.global_position)
	_check(lz == &"E_MONTAGE" and ZoneVolume.zone_at(get_tree(), trap.to_global(trap.track_start)) == &"E_MONTAGE", "lever and rail are in the Montage (%s)" % lz)
	_check(not trap.can_activate() and lever.get_prompt(_p).contains("power"), "no power: the lever refuses (%s)" % lever.get_prompt(_p))
	(_map.get_node("Gameplay/Hauptschalter")).call("run_sequence", 1)
	var t_pow: int = 0
	while not GameState.power_on and t_pow < 600:
		await _frames(1)
		t_pow += 1
	await _frames(30)
	_dir.kill_all(true)
	_check(trap.can_activate() and lever.get_prompt(_p).contains("Rivet Line"), "with the power the lever offers the Rivet Line")
	# the bodies: one under the line, one beside it, the player under it at the far end
	var z_in: Zombie = await _zombie_at(Vector3(-24.0, 0.1, 64.0))
	var z_out: Zombie = await _zombie_at(Vector3(-24.0, 0.1, 69.5))
	_p.global_position = Vector3(-8.0, 0.1, 64.0)
	_p.velocity = Vector3.ZERO
	var before: int = Economy.get_scrip(1) if Economy.has_method("get_scrip") else -1
	lever.interact(_p)
	await _frames(2)
	_check(trap.active and GameState.has_flag(&"rivet_line_running"), "the lever starts it (rivet_line_running)")
	if before >= 0:
		_check(Economy.get_scrip(1) <= before - 1000 + 500, "the price was taken (%d -> %d)" % [before, Economy.get_scrip(1)])
	_check(trap.danger_contains(Vector3(-10, 0, 64)) and not trap.danger_contains(Vector3(-10, 0, 70)), "bots keep out of the strip, not the hall")
	var xmin: float = INF
	var xmax: float = -INF
	var t0: int = Time.get_ticks_msec()
	var hit_seen: bool = false
	while trap.active and Time.get_ticks_msec() - t0 < 40000:
		await _frames(1)
		var cx: float = trap.get_node("Carriage").global_position.x
		xmin = minf(xmin, cx)
		xmax = maxf(xmax, cx)
		_p.global_position = Vector3(-8.0, 0.1, 64.0)   # stays under it
		if _hits > 0:
			hit_seen = true
	var ran: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_check(xmin < -44.0 and xmax > -4.0, "the carriage ran the hall's length (x %.1f .. %.1f)" % [xmin, xmax])
	_check(not z_in.is_active(), "the zombie under the line was riveted")
	_check(z_out.is_active(), "the zombie beside the strip lives")
	_check(hit_seen, "the player under it was hit (%d)" % _hits)
	_check(ran > 24.0 and ran < 30.0, "it ran %.1f s (25 + the klaxon)" % ran)
	_check(not trap.active and not GameState.has_flag(&"rivet_line_running") and trap.cooldown_left > 55.0, "then it cools down (%.0f s)" % trap.cooldown_left)
	_check(not trap.can_activate() and lever.get_prompt(_p).contains("cooling"), "the lever says so")
	_check(RivetLineTrap.under(Vector3(1, 0, 0.5), Vector3.ZERO, Vector3.RIGHT, 3.0, 3.2) and not RivetLineTrap.under(Vector3(2, 0, 0), Vector3.ZERO, Vector3.RIGHT, 3.0, 3.2),
		"the kill box is the carriage's footprint")
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("[rivet] RESULT: PASS")
		get_tree().quit(0)
	else:
		print("[rivet] RESULT: FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)])
		get_tree().quit(1)
