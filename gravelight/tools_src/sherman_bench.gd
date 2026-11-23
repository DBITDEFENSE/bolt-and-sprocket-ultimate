extends Node
## T-261: how often the Sherman fires. A headless measurement, not a pass/fail smoke: it plays the round-30 assault
## and an assist round on the Inn with one human standing still in god mode (no bots), and prints what the tank did
## (75 mm shells, machine-gun rounds, kills, health). Run as fast as the machine goes with --fixed-fps 60:
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/sherman_bench.tscn -- <case>
## cases:  assault        nobody helps the tank (the wave runs until it holds or burns)
##         assault_team   a "team": one of the wave that is up dies every TEAM_KILL_S seconds
##         assist_yard    round 31, the human in the yard for ASSIST_S seconds
##         assist_road    round 31, the human on the road 12 m in front of the tank
##         assist_inn     round 31, the human in the taproom (the dead cross the grounds and the yard to get in)
## Prints "[bench] ..." lines; the last is "[bench] RESULT: <case> ...".

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TEAM_KILL_S: float = 2.5
const ASSIST_S: float = 150.0
const ASSAULT_MAX_S: float = 240.0

var _map: Node3D
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_sherman_bench_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_sherman_bench_settings.cfg"
	GLSettings.values["homage_bosses"] = true
	GameState.character_id = &"dutch"
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > 900.0:
		print("[bench] RESULT: timeout")
		get_tree().quit(1)
		set_process(false)


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


func _ev() -> ShermanEvent:
	return _map.get_node_or_null("ShermanEvent") as ShermanEvent


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if not args.is_empty() else "assault"
	GameState.bot_count = 0
	GameState.god_mode = true
	_map = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await get_tree().create_timer(1.0).timeout
	GameState.god_mode = true
	_root().player.set_process_unhandled_input(false)
	_root().director.kill_all(true)
	GLConsole.run("open_doors")
	for z: String in ["YARD", "GROUNDS", "STABLE", "UPSTAIRS", "CELLAR"]:
		GameState.open_zone(StringName(z))
	if which.begins_with("assault"):
		await _assault(which == "assault_team")
	else:
		await _assist(which)
	get_tree().quit(0)
	set_process(false)


func _place(at: Vector3) -> void:
	_root().player.global_position = at
	_root().player.velocity = Vector3.ZERO


func _assault(team: bool) -> void:
	var ev: ShermanEvent = _ev()
	_place(Vector3(14.0, 0.05, 41.0))
	RoundManager.debug_set_round(30)
	await _until(func() -> bool: return RoundManager.current_round == 30 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSAULT, 60.0)
	var tk: ShermanTank = ev.tank
	var t0: float = _t
	var kill_t: Array = [TEAM_KILL_S]
	var team_kills: Array = [0]
	var next_log: Array = [10.0]
	await _until(func() -> bool: return ev.phase != ShermanEvent.Phase.ASSAULT, ASSAULT_MAX_S, func() -> void:
		var dt: float = get_physics_process_delta_time()
		if team:
			kill_t[0] -= dt
			if kill_t[0] <= 0.0:
				kill_t[0] = TEAM_KILL_S
				for z: Zombie in ev.attackers:
					if is_instance_valid(z) and z.is_active() and z.state != Zombie.State.EMERGE and not FireZombie.is_fire(z):
						z.take_damage(z.hp + 1.0, &"head", &"m1911", 1, &"bullet")
						team_kills[0] += 1
						break
		if _t - t0 >= next_log[0]:
			next_log[0] += 10.0
			print("[bench] t %3.0f s: 75 mm %d, mg %d (%d hits), kills %d, tank %d/%d, wave %d/%d up %d" % [_t - t0, tk.shots_main, tk.shots_mg, tk.mg_hits, tk.kills, int(tk.hp), int(tk.max_hp), ev.assault_spawned, ev.assault_total, ev.attackers.size()]))
	var secs: float = _t - t0
	print("[bench] RESULT: %s: outcome '%s' after %.0f s; 75 mm shells %d, machine-gun rounds %d (%d hits), the tank's kills %d, the team's kills %d of %d, tank health %d/%d, swipes %d" % [
		"assault_team" if team else "assault", ev.outcome if ev.phase != ShermanEvent.Phase.ASSAULT else "undecided", secs, tk.shots_main, tk.shots_mg, tk.mg_hits, tk.kills, team_kills[0], ev.assault_total, int(tk.hp), int(tk.max_hp), tk.swipes_taken])


func _assist(which: String) -> void:
	var ev: ShermanEvent = _ev()
	_place(Vector3(14.0, 0.05, 41.0))
	RoundManager.debug_set_round(31)
	await _until(func() -> bool: return RoundManager.current_round == 31 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	ev.force_assist()
	var tk: ShermanTank = ev.tank
	if which == "assist_road":
		_place(tk.global_transform * Vector3(0, 0.05, -12.0))
	elif which == "assist_inn":
		_place(Vector3(10.0, 0.05, 9.0))
	var t0: float = _t
	var seen_max: Array = [0]
	var next_log: Array = [15.0]
	await _until(func() -> bool: return RoundManager.state != RoundManager.State.ROUND, ASSIST_S, func() -> void:
		var n: int = 0
		for z: Zombie in _root().director.active_zombies():
			if z.is_active() and z.global_position.distance_to(tk.global_position) < 45.0:
				n += 1
		seen_max[0] = maxi(seen_max[0], n)
		if _t - t0 >= next_log[0]:
			next_log[0] += 15.0
			print("[bench] t %3.0f s: 75 mm %d, mg %d (%d hits), kills %d, the dead within 45 m %d" % [_t - t0, tk.shots_main, tk.shots_mg, tk.mg_hits, tk.kills, n]))
	var secs: float = maxf(1.0, _t - t0)
	print("[bench] RESULT: %s: %.0f s of round 31; 75 mm shells %d (%.1f a minute), machine-gun rounds %d (%d hits), kills %d, most of the dead within 45 m at once %d" % [
		which, secs, tk.shots_main, float(tk.shots_main) * 60.0 / secs, tk.shots_mg, tk.mg_hits, tk.kills, seen_max[0]])
