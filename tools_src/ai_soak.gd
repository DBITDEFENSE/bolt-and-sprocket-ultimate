extends Node
## The AI soak test (Update 03 sections 0 and 9): plays whole matches with the bots, headless and as fast as the
## machine allows, with a BotMetrics logger on every run, and writes the numbers to logs/ai_runs/ (git-ignored):
## a CSV per run (<run>.csv), a summary row per run (summary_<scenario>.csv) and a markdown table per batch
## (<batch>.md). Prints "[soak] ..." lines, the logger's "[ai_metrics] SUMMARY" line per run, and RESULT.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- --scenario=player3
##         [--runs=3] [--seed=1] [--max-round=0] [--speed=1] [--skill=regular] [--max-minutes=150] [--map=map00]
## (tools/ai_soak.sh wraps this.) Scenarios:
##   player3      3 bots + the scripted player (tools_src/soak_dummy.gd) on Map 0, from round 1 until the squad
##                wipes (or --max-round)
##   bots3        3 bots alone on Map 0: the human slot exists (the game needs a local Player) but sits the match
##                out as an invisible spectator: bled out (zombies and bots ignore it, the bots lead themselves),
##                taken out of the co-op life-cycle (never respawns, isn't counted for the wipe), never fights
##   cousins      player3 forced to round 10 (the Cousins round, HB1; Homage Bosses on), until the round is over
##                (cleared, or the cousins got bored and left) or the squad wipes; every player gets 3000 Scrip
##   kaltenbrunn  player3 on Map 1, rounds 1 to 20 (--max-round, default 20). The Update 03 brief also forces Paul
##                at round 15; Paul doesn't exist yet, so that part is skipped
## The bots' local-AI planner is off (GameState.bot_ai_mode = "off"), so no run depends on Ollama.
## --speed=N sets Engine.time_scale (N physics-seconds per tick-second): headless with --fixed-fps 60 already runs
## as fast as the CPU allows; --speed > 1 also lengthens every physics step (fewer steps per game second). The bots'
## and the game's timers all run on the scaled delta. docs/BOT_AI.md has a 1x vs 2x comparison.
## --seed seeds the global RNG and the round manager; the bots roll their own RNG (randomize), so runs are not
## bit-for-bit repeatable: compare averages over several runs.

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
}
const Dummy: GDScript = preload("res://tools_src/soak_dummy.gd")

var scenario: String = "player3"
var runs: int = 1
var seed_base: int = 1
var max_round: int = 0
var speed: float = 1.0
var max_minutes: float = 150.0
var skill: String = "regular"
var map_key: String = ""

var _run: int = 0
var _map: MapRoot = null
var _metrics: BotMetrics = null
var _dummy: RefCounted = null
var _ready_wait: int = 0
var _live: bool = false
var _results: Array[Dictionary] = []
var _paths: PackedStringArray = []
var _batch: String = ""
var _game_t: float = 0.0
var _wall0: int = 0
var _phys_us: float = 0.0
var _frames: int = 0
var _last_us: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a.begins_with("--runs="):
			runs = maxi(1, int(a.substr(7)))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--max-round="):
			max_round = int(a.substr(12))
		elif a.begins_with("--speed="):
			speed = clampf(float(a.substr(8)), 0.25, 8.0)
		elif a.begins_with("--max-minutes="):
			max_minutes = float(a.substr(14))
		elif a.begins_with("--skill="):
			skill = a.substr(8)
		elif a.begins_with("--map="):
			map_key = a.substr(6)
	if not ["player3", "bots3", "cousins", "kaltenbrunn"].has(scenario):
		print("[soak] unknown --scenario=%s (player3, bots3, cousins, kaltenbrunn)" % scenario)
		print("[soak] RESULT FAIL")
		get_tree().quit(2)
		return
	if map_key == "":
		map_key = "map01" if scenario == "kaltenbrunn" else "map00"
	if scenario == "kaltenbrunn" and max_round <= 0:
		max_round = 20
	if scenario == "cousins":
		max_round = 10
	ProfileSave.path = "user://_ai_soak_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_ai_soak_settings.cfg"   # never write the player's own settings file
	GLSettings.values["homage_bosses"] = true
	GLSettings.values["homage_names"] = "real"
	Engine.time_scale = speed
	_batch = "%s_%s_x%d" % [Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").replace("-", ""), scenario, runs]
	print("[soak] scenario %s, %d run(s), seed %d, max round %s, speed %.2fx, skill %s, map %s, local AI off" % [scenario, runs, seed_base,
		str(max_round) if max_round > 0 else "to the wipe", speed, skill, map_key])
	_start_run.call_deferred()


func _start_run() -> void:
	_run += 1
	var sd: int = seed_base + _run - 1
	seed(sd)
	if RoundManager.get("rng") is RandomNumberGenerator:
		(RoundManager.get("rng") as RandomNumberGenerator).seed = sd
	Campaign.reset()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = skill
	GameState.bot_ai_mode = "off"
	GameState.god_mode = false
	_map = (load(str(MAPS[map_key])) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	_ready_wait = 0
	_live = false
	_game_t = 0.0
	_phys_us = 0.0
	_frames = 0
	_wall0 = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if _map == null or not is_instance_valid(_map):
		return
	if not _live:
		_try_go_live()
		return
	_game_t += delta
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_phys_us += float(now - _last_us)
		_frames += 1
	_last_us = now
	if _dummy != null:
		_dummy.call("tick", delta)
	if _metrics.finished:
		_end_run(_metrics.end_reason)
	elif max_round > 0 and RoundManager.current_round > max_round:
		_end_run("reached round %d" % RoundManager.current_round)
	elif scenario == "cousins" and _cousins_over():
		_end_run("cousins " + str(_metrics.extra.get("cousins", "")))
	elif _game_t > max_minutes * 60.0:
		_end_run("time cap %.0f min" % max_minutes)


func _try_go_live() -> void:
	_ready_wait += 1
	if _map.player == null or not _map.player.is_inside_tree() or _map.squad == null:
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0 or _ready_wait < 30:
		return
	_live = true
	_last_us = 0
	_metrics = BotMetrics.new()
	_metrics.name = "BotMetrics"
	add_child(_metrics)
	var rid: String = "%s_%s_r%d_s%d" % [_batch.substr(0, 15), scenario, _run, seed_base + _run - 1]
	_metrics.setup(_map, scenario, rid, seed_base + _run - 1)
	_dummy = null
	match scenario:
		"bots3":
			_bench_the_human()
		"cousins":
			_dummy = Dummy.new()
			_dummy.call("setup", _map.player, _map, seed_base + _run)
			_force_cousins()
		_:
			_dummy = Dummy.new()
			_dummy.call("setup", _map.player, _map, seed_base + _run)
	print("[soak] run %d/%d live: map %s, %d bots %s, route %s" % [_run, runs, _map.map_id, GameState.bot_ids.size(),
		str(GameState.bot_ids.map(func(p: int) -> String: return Net.display_name(p))), str(_dummy.get("route_name")) if _dummy != null else "(no human: spectator)"])


## bots3: the local Player can't be removed (the HUD, the camera and the round code expect one), so it sits the
## match out: bled out (downed + spectating, no collision, no guns, so zombies and bots ignore it and the bots lead
## themselves) and taken out of the co-op life-cycle (no respawn, the wipe is the bots').
func _bench_the_human() -> void:
	var h: Player = _map.player
	h.bleed_out()
	h.set_physics_process(false)
	if Net.session != null:
		Net.session.coop.remove(h.player_id)


## cousins: round 10 now (as the dev launcher does), the normal horde cleared, Scrip for a round-10 squad.
func _force_cousins() -> void:
	for pid: int in GameState.player_ids:
		Economy.award(pid, 3000)
	RoundManager.debug_set_round(10)
	_map.director.kill_all(true)


func _cousins_over() -> bool:
	var cr: CousinsRound = _map.director.cousins if _map.director != null else null
	if cr == null:
		return false
	_metrics.extra["cousins_dead"] = cr.dead_count()
	if cr.phase == CousinsRound.Phase.CLEARED or cr.cleared_count > 0:
		_metrics.extra["cousins"] = "cleared"
		_metrics.extra["cousins_time_s"] = snappedf(cr.t, 0.1)
		return RoundManager.state != RoundManager.State.ROUND
	if cr.phase == CousinsRound.Phase.BORED or cr.bored_count > 0:
		_metrics.extra["cousins"] = "left (bored)"
		return RoundManager.state != RoundManager.State.ROUND
	return RoundManager.current_round > 10


func _end_run(why: String) -> void:
	if scenario == "cousins" and not _metrics.extra.has("cousins"):
		_metrics.extra["cousins"] = "wipe" if why == "wipe" else why
	if _dummy != null:
		_metrics.extra["dummy_laps"] = int(_dummy.get("laps"))
		_metrics.extra["dummy_reversals"] = int(_dummy.get("reversals"))
	_metrics.extra["wall_s"] = snappedf(float(Time.get_ticks_msec() - _wall0) / 1000.0, 0.1)
	_metrics.extra["frame_ms"] = snappedf(_phys_us / maxf(1.0, float(_frames)) / 1000.0, 0.01)
	_metrics.extra["speed"] = speed
	var sm: Dictionary = _metrics.finish(why)
	print(_metrics.summary_line())
	var dir: String = BotMetrics.log_dir()
	var path: String = _metrics.write_csv(dir)
	_paths.append(path)
	print("[soak] run %d: %s at round %d after %.1f game min (%.0f s real) -> %s" % [_run, why, int(sm["round_reached"]), float(sm["minutes"]),
		float(_metrics.extra["wall_s"]), path])
	print("[soak]   extra: %s" % str(_metrics.extra))
	if _map.squad != null:
		for line: String in _map.squad.report():
			print("[soak]   ", line)
	_results.append(_metrics.summary())
	if _dummy != null:
		_dummy.call("shutdown")
	_dummy = null
	_metrics.queue_free()
	_metrics = null
	_live = false
	GameState.phase = GameState.Phase.MENU
	RoundManager.stop()
	_map.queue_free()
	_map = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _run < runs:
		_start_run()
	else:
		_write_table(dir)


## The batch's markdown table: one row per run and the mean.
func _write_table(dir: String) -> void:
	var cols: Array = [["round", "round_reached", "%d"], ["min", "minutes", "%.1f"], ["bot kills", "bot_kills", "%d"],
		["bot downs", "bot_downs", "%d"], ["downs/round", "bot_downs_per_round", "%.2f"], ["human downs", "human_downs", "%d"],
		["revive %", "revive_rate", "pct"], ["revived", "revived", "%d"], ["bled", "bled", "%d"], ["ttr s", "ttr_mean", "%.1f"],
		["stuck", "stuck_events", "%d"], ["stuck s", "stuck_time", "%.1f"], ["teleports", "teleports", "%d"], ["lost s", "lost_time", "%.0f"],
		["block ev", "block_events", "%d"], ["sustained", "block_sustained", "%d"], ["spent", "scrip_spent", "%d"],
		["wasted", "scrip_wasted", "%d"], ["kar98k>r10", "kar98k_late", "%d"], ["empty-mag", "empty_mag_events", "%d"]]
	var lines: PackedStringArray = []
	lines.append("| run | end | " + " | ".join(PackedStringArray(cols.map(func(c: Array) -> String: return str(c[0])))) + " |")
	lines.append("|---|---|" + "---|".repeat(cols.size()))
	var sums: Dictionary = {}
	for r: Dictionary in _results:
		var cells: PackedStringArray = []
		for c: Array in cols:
			var v: float = float(r.get(c[1], 0.0))
			sums[c[1]] = float(sums.get(c[1], 0.0)) + v
			cells.append(_fmt(v, str(c[2])))
		lines.append("| %s | %s | %s |" % [str(r["run"]).get_slice("_", 2) + "_" + str(r["run"]).get_slice("_", 3), str(r["end"]), " | ".join(cells)])
	var mean: PackedStringArray = []
	for c2: Array in cols:
		mean.append(_fmt(float(sums.get(c2[1], 0.0)) / float(maxi(1, _results.size())), "%.1f" if str(c2[2]) == "%d" else str(c2[2])))
	lines.append("| **mean** | | %s |" % " | ".join(mean))
	var md: String = "# AI soak: %s, %d run(s)\n\n%s\n\nCSVs: %s\n" % [scenario, _results.size(), "\n".join(lines), ", ".join(PackedStringArray(Array(_paths).map(func(p: String) -> String: return p.get_file())))]
	var path: String = dir.path_join("%s.md" % _batch)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
	print("[soak] table -> %s" % path)
	for l: String in lines:
		print("[soak] ", l)
	print("[soak] RESULT PASS (%d run(s) logged)" % _results.size())
	Engine.time_scale = 1.0
	get_tree().quit(0)


static func _fmt(v: float, f: String) -> String:
	if f == "pct":
		return "%.0f%%" % (100.0 * v)
	if f == "%d":
		return "%d" % roundi(v)
	return f % v
