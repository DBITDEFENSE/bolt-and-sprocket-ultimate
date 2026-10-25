extends Node
## The AI soak test (Update 03 sections 0 and 9): plays whole matches with the bots, headless and as fast as the
## machine allows, with a BotMetrics logger on every run, and writes the numbers to logs/ai_runs/ (git-ignored):
## a CSV per run (<run>.csv), a summary row per run (summary_<scenario>.csv) and a markdown table per batch
## (<batch>.md). Prints "[soak] ..." lines, the logger's "[ai_metrics] SUMMARY" line per run, and RESULT.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/ai_soak.tscn -- --scenario=player3
##         [--runs=3] [--seed=1] [--max-round=0] [--speed=1] [--skill=regular] [--max-minutes=150] [--map=map00] [--god]
##         [--player-kit=baseline|realistic]
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
##   ee_full      (Update 04 section 5, T-067) player3 on Map 0 with "Bot Easter-Egg Help" on Full Partner: the bots
##                work "Glasmacher Calling" (the notes, then the radio up to its last frequency, which is the player's
##                commit; the harness then locks it as the player). Ends when the egg is complete, the squad wipes or
##                at --max-round (default 12). Logs the egg numbers (steps, inputs, egg-failure events).
##   botmode      (T-071) player bot mode: the local Player is played by the agent (PlayerBot: the bots' brain +
##                BotTrainer training the horde round the map's loop) instead of the scripted player; --bots=N (0-3,
##                default 0: solo) teammates follow it. Map 0 by default (--map=map01: Kaltenbrunn). From round 1 to
##                the game over (solo) / the wipe, or --max-round. Logs the training numbers (pb_* in the extras:
##                time training, the train's mean length / spread / bunched share, cut-ins, hits while training,
##                stuck time) and a table of its own.
## --ee=off|ask|full: Bot Easter-Egg Help for any scenario (default: the setting, When Asked; ee_full: full).
## --player-kit (T-058): the scripted player's kit. "baseline" (the default, as in the Update 03 baseline): the
## bots' free spawn kit, buys nothing, never touches the power. "realistic": the Thompson only, opens the way to the
## power and throws it by round 3-4, drinks (and rebuys) Ironhide Stout and Second Wind (tools_src/soak_dummy.gd).
## The bots' local-AI planner is off (GameState.bot_ai_mode = "off"), so no run depends on Ollama.
## Accelerated time: headless with --fixed-fps 60 (as tools/ai_soak.sh runs it) is not tied to the clock, so a run
## goes as fast as the CPU allows (6-7x real time on Map 0's early rounds here) with the exact 1/60 s physics step a
## real-time match uses; every bot and game timer runs on that delta. --speed=N also sets Engine.time_scale, but
## under --fixed-fps that gains nothing: measured, the physics step stays ~1/60 s and a game minute costs the same
## wall time (docs/BOT_AI.md has the real-time vs accelerated and the time_scale 1 vs 2 comparisons).
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
var skill: String = "veteran"
var map_key: String = ""
## --player-kit: the scripted player's kit ("baseline" or "realistic", see the doc above).
var player_kit: String = "baseline"
## --start-round=N (tuning only, T-058): jump to round N at go-live (RoundManager.debug_set_round) with 450 x N
## Scrip each; not for the acceptance numbers.
var start_round: int = 0
## --homage=0 (tuning only): the Homage Bosses off (no Cousins round at 10 on Map 0); the default (as in every
## Update 03 measurement) is on.
var homage: bool = true
## --character=<id>: the scripted player's character (default peg, so the bots are Dutch, Deacon and Wren; e.g.
## --character=dutch puts Peg among the bots).
var character: String = "peg"
var god: bool = false   # --god: the scripted player can't be hurt (it outlives the bots: T-057's stalled-round hunt)
## --trace=N: every N game seconds, one status line per bot (action, top scores, gun, threat) and its task.
var trace_s: float = 0.0
var _trace_t: float = 0.0
## --orders=N: every N game seconds the scripted player gives the squad a command-wheel order (cycling follow,
## hold, train, repair, revive, buy_perks), so BotMetrics measures the command response time. Off by default
## (the baseline had no orders).
var orders_s: float = 0.0
var _order_t: float = 0.0
var _order_i: int = 0
## --ee: the Bot Easter-Egg Help mode for the run ("" = the setting); ee_full forces "full".
var ee_mode: String = ""
## --bots=N (botmode only): the AI teammates beside the agent-played player (default 0).
var bots_n: int = 3
var _bots_set: bool = false
## Tuning only (T-071 pass 2), applied at go-live: --open-doors=door_a,door_b|all (bought for free), --power (the
## map's power switch thrown), --give=thompson,ironhide_stout (weapons and perks for the agent / scripted player),
## --loop=<route id> (the agent trains on that loop only: BotTrainer.force_loop).
var open_doors: String = ""
var power_on: bool = false
var give: String = ""
## --posdump=<abs path stem> (tuning only): every 0.2 game s one JSON line per run (<stem>_r<run>.jsonl) with the
## agent (position, facing, phase, train) and every active zombie (position, state, known to the agent), plus the
## walkable navmesh polygons (<stem>_nav.json) once: tools for plotting what happened round a hit.
var posdump: String = ""
var _pd_f: FileAccess = null
var _pd_t: float = 0.0
var _pb: PlayerBot = null
var _pb_rounds: Dictionary = {}   # round -> [downs, hits] of the agent
## (T-071 pass 3) the agent's per-round ledger line: Scrip earned / spent since the last round start, training time.
var _pb_round_seen: int = 0
var _pb_earned: int = 0
var _pb_spent: int = 0
var _pb_train0: float = 0.0
var _pb_t0: float = 0.0
## T-078: Scrip earned (positive deltas, every source) by player 1 so far, and the running total at each round's end.
var _earned: int = 0
var _earned_by_round: Dictionary = {}   # round -> cumulative Scrip earned by P1 when it ended
var _bonus_by_kind: Dictionary = {}   # T-078: P1's bonus Scrip by kind (round_pay, untouched, salvage...)
var _ee_committed_t: float = -1.0
var _ee_events: PackedStringArray = []
const SOAK_ORDERS: Array[StringName] = [&"hold", &"follow", &"train", &"repair", &"revive", &"buy_perks"]

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
		elif a == "--god":
			god = true
		elif a.begins_with("--trace="):
			trace_s = float(a.substr(8))
		elif a.begins_with("--orders="):
			orders_s = float(a.substr(9))
		elif a.begins_with("--player-kit="):
			player_kit = a.substr(13)
		elif a.begins_with("--start-round="):
			start_round = int(a.substr(14))
		elif a.begins_with("--character="):
			character = a.substr(12)
		elif a.begins_with("--homage="):
			homage = a.substr(9) != "0"
		elif a.begins_with("--ee="):
			ee_mode = a.substr(5)
		elif a.begins_with("--bots="):
			bots_n = clampi(int(a.substr(7)), 0, 3)
			_bots_set = true
		elif a.begins_with("--open-doors="):
			open_doors = a.substr(13)
		elif a == "--power":
			power_on = true
		elif a.begins_with("--give="):
			give = a.substr(7)
		elif a.begins_with("--posdump="):
			posdump = a.substr(10)
		elif a.begins_with("--loop="):
			BotTrainer.force_loop = a.substr(7)   # (tuning only, T-071 pass 2) the agent trains on this loop only
		elif a.begins_with("--loco="):
			BotLocomotion.force_mode = a.substr(7)   # U03 section 3: v1 / v2 against bots.json locomotion
	if not ["player3", "bots3", "cousins", "kaltenbrunn", "ee_full", "botmode"].has(scenario):
		print("[soak] unknown --scenario=%s (player3, bots3, cousins, kaltenbrunn, ee_full, botmode)" % scenario)
		print("[soak] RESULT FAIL")
		get_tree().quit(2)
		return
	if map_key == "":
		map_key = "map01" if scenario == "kaltenbrunn" else "map00"
	if scenario == "kaltenbrunn" and max_round <= 0:
		max_round = 20
	if scenario == "cousins":
		max_round = 10
	if scenario == "ee_full":
		ee_mode = "full"
		if max_round <= 0:
			max_round = 12
	if scenario == "botmode" and not _bots_set:
		bots_n = 0
	GLBus.quest_step_completed.connect(func(q: StringName, st: StringName) -> void:
		if _live:
			_ee_events.append("r%d %.0fs %s/%s done" % [RoundManager.current_round, _game_t, q, st]))
	GLBus.quest_step_failed.connect(func(q: StringName, st: StringName, r: StringName) -> void:
		if _live:
			_ee_events.append("r%d %.0fs %s/%s FAILED (%s)" % [RoundManager.current_round, _game_t, q, st, r]))
	ProfileSave.path = "user://_ai_soak_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_ai_soak_settings.cfg"   # never write the player's own settings file
	GLSettings.values["homage_bosses"] = homage
	GLSettings.values["homage_names"] = "real"
	GLSettings.values["bot_local_ai"] = false   # T-071: the agent's planner is the scripted one in every soak (no Ollama)
	Engine.time_scale = speed
	_batch = "%s_%s_x%d" % [Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").replace("-", ""), scenario, runs]
	if BotLocomotion.force_mode != "":
		_batch += "_loco" + BotLocomotion.force_mode
	if not ["baseline", "realistic", "bots"].has(player_kit):
		print("[soak] unknown --player-kit=%s (baseline, realistic)" % player_kit)
		print("[soak] RESULT FAIL")
		get_tree().quit(2)
		return
	if player_kit != "baseline" and scenario != "bots3":
		_batch += "_" + player_kit
	if not homage:
		_batch += "_nohomage"
	if scenario == "botmode":
		_batch += "_%s_b%d" % [map_key, bots_n]
		GLBus.player_downed.connect(func(pid: int) -> void:
			if _live and pid == 1:
				_pb_round(RoundManager.current_round)[0] += 1)
		GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
			if _live and pid == 1 and amount > 0.0:
				_pb_round(RoundManager.current_round)[1] += 1)
	print("[soak] scenario %s, %d run(s), seed %d, max round %s, speed %.2fx, skill %s, map %s, player kit %s, local AI off" % [scenario, runs, seed_base,
		str(max_round) if max_round > 0 else "to the wipe", speed, skill, map_key, player_kit])
	GLBus.scrip_changed.connect(func(pid: int, _t: int, delta: int) -> void:
		if _live and pid == 1 and delta > 0:
			_earned += delta)
	GLBus.round_ended.connect(func(r: int) -> void:
		if _live:
			_earned_by_round[r] = _earned)
	GLBus.bonus_awarded.connect(func(pid: int, kind: StringName, amount: int, _l: String) -> void:
		if _live and pid == 1:
			_bonus_by_kind[String(kind)] = int(_bonus_by_kind.get(String(kind), 0)) + amount)
	GLBus.power_activated.connect(func() -> void:
		if _metrics != null and not _metrics.extra.has("power_round"):
			_metrics.extra["power_round"] = RoundManager.current_round)
	_start_run.call_deferred()


func _start_run() -> void:
	_run += 1
	var sd: int = seed_base + _run - 1
	seed(sd)
	if RoundManager.get("rng") is RandomNumberGenerator:
		(RoundManager.get("rng") as RandomNumberGenerator).seed = sd
	Campaign.reset()
	GameState.character_id = StringName(character)
	GameState.bot_count = bots_n if scenario == "botmode" else 3
	GameState.bot_skill = skill
	GameState.bot_ai_mode = "off"
	GameState.god_mode = god
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
	_watch_stall()
	if scenario == "botmode" and _pb != null and is_instance_valid(_pb) and RoundManager.current_round != _pb_round_seen:
		_pb_round_line()
	if orders_s > 0.0 and _map.squad != null and _map.player != null and not _map.player.spectating:
		_order_t += delta
		if _order_t >= orders_s:
			_order_t = 0.0
			var o: StringName = SOAK_ORDERS[_order_i % SOAK_ORDERS.size()]
			_order_i += 1
			_map.squad.set_command(o, _map.player.global_position if o == &"hold" else Vector3.INF)
	if trace_s > 0.0 and _map.squad != null:
		_trace_t -= delta
		if _trace_t <= 0.0:
			_trace_t = trace_s
			for b: BotBrain in _map.squad.brains:
				print("[trace] t=%.0f r%d %s | task %s" % [_game_t, RoundManager.current_round, b.status_line(), str(b.task.get("label", "-"))])
			if _pb != null and is_instance_valid(_pb) and _pb.brain != null:
				var tb: BotTrainer = _pb.trainer
				var pp: Vector3 = _map.player.global_position
				var cw: WeaponInstance = _pb.brain.aim.cur()
				print("[trace] t=%.1f r%d AGENT %s (%.1f,%.1f) v%.1f hp%.0f %s %d/%d | %s %s f%d h%.1f a%.1f(%d) n%.1f p%.2f off%.1f y%.1f | scrip %d | %s" % [_game_t, RoundManager.current_round,
					_pb.brain.action, pp.x, pp.z, _map.player.horizontal_speed(), _map.player.hp, str(cw.id) if cw != null else "-", cw.mag if cw != null else 0, cw.reserve if cw != null else 0,
					tb.route.id.trim_prefix("map00_").trim_prefix("map01_") if tb.route != null else "-", tb.phase_name(), tb.followers, minf(tb.head_d, 99.0), minf(tb.ahead_d, 99.0), tb.ahead_n,
					minf(_pb.brain.perception.nearest_d, 99.0), _pb.brain.perception.pressure, minf(tb.off_m, 99.0), pp.y, Economy.get_scrip(1), ", ".join(PackedStringArray(_pb.brain.top3.map(func(t: Variant) -> String: return "%s %.2f" % [str((t as Array)[0]), float((t as Array)[1])]))) + " | step " + str(AgentPlan.current_for(_pb.brain)) + " raw " + str(AgentPlan.last_raw) + " | buy: " + str((_pb.brain.economy.best(_pb.brain.squad.time()).get("buy", {}) as Dictionary).get("label", "-")) if trace_s >= 2.0 else ""])
	if _pd_f != null:
		_pd_t -= delta
		if _pd_t <= 0.0:
			_pd_t = 0.2
			_pd_tick()
	if scenario == "ee_full":
		_tick_ee()
	if _metrics.finished:
		_end_run(_metrics.end_reason)
	elif scenario == "ee_full" and QuestManager.is_complete(&"map00_radio"):
		_end_run("egg complete")
	elif max_round > 0 and RoundManager.current_round > max_round:
		_end_run("reached round %d" % RoundManager.current_round)
	elif scenario == "cousins" and _cousins_over():
		_end_run("cousins " + str(_metrics.extra.get("cousins", "")))
	elif _game_t > max_minutes * 60.0:
		_end_run("time cap %.0f min" % max_minutes)


func _try_go_live() -> void:
	_ready_wait += 1
	if _map.player == null or not _map.player.is_inside_tree():
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0 or _ready_wait < 30:
		return
	if scenario == "botmode" and (_pb == null or not is_instance_valid(_pb) or not _pb.is_on()):
		_pb = PlayerBot.of(get_tree())
		if _pb == null or not _pb.set_on(true, "soak"):
			return
		_pb_rounds = {}
		_pb_round_seen = 0
		_pb_earned = 0
		_pb_spent = 0
		_pb_train0 = 0.0
		_pb_t0 = _game_t
		if not GLBus.scrip_changed.is_connected(_on_scrip_changed):
			GLBus.scrip_changed.connect(_on_scrip_changed)
		if _pb.trainer != null:
			_pb.trainer.verbose_hits = trace_s > 0.0
		if OS.get_cmdline_user_args().has("--no-trainer"):
			_pb.brain.trainer = null   # (tuning only) the plain brain: fight / retreat / train, no BotTrainer
		if player_kit == "bots" and _map.squad != null:
			_map.squad.apply_kit(_map.player, true)   # --player-kit=bots (tuning only): the bots' free spawn kit for the agent
	if _map.squad == null:
		return
	_earned = Economy.get_scrip(1)   # the starting Scrip counts as earned
	_earned_by_round = {}
	_bonus_by_kind = {}
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
		"botmode":
			pass   # the agent plays the local Player (PlayerBot, switched on above)
		"cousins":
			_dummy = Dummy.new()
			_dummy.call("setup", _map.player, _map, seed_base + _run, player_kit)
			_force_cousins()
		_:
			_dummy = Dummy.new()
			_dummy.call("setup", _map.player, _map, seed_base + _run, player_kit)
	_ee_committed_t = -1.0
	_ee_events = PackedStringArray()
	if ee_mode != "" and _map.squad != null and _map.squad.ee != null:
		_map.squad.ee.set_mode(ee_mode)
	_apply_tuning()
	if posdump != "":
		_pd_open()
	if start_round > 1 and scenario != "cousins":
		for pid: int in GameState.player_ids:
			Economy.award(pid, 450 * start_round)
		RoundManager.debug_set_round(start_round)
		_map.director.kill_all(true)
	print("[soak] run %d/%d live: map %s, %d bots %s, route %s" % [_run, runs, _map.map_id, GameState.bot_ids.size(),
		str(GameState.bot_ids.map(func(p: int) -> String: return Net.display_name(p))), str(_dummy.get("route_name")) if _dummy != null else "(no human: spectator)"])


func _pd_open() -> void:
	_pd_f = FileAccess.open("%s_r%d.jsonl" % [posdump, _run], FileAccess.WRITE)
	if _run == 1:
		var polys: Array = []
		for n: Node in _map.find_children("*", "NavigationRegion3D", true, false):
			var nr: NavigationRegion3D = n as NavigationRegion3D
			if nr == null or not nr.enabled or nr.navigation_mesh == null:
				continue
			var nm: NavigationMesh = nr.navigation_mesh
			var vs: PackedVector3Array = nm.get_vertices()
			for i: int in nm.get_polygon_count():
				var poly: Array = []
				for vi: int in nm.get_polygon(i):
					var v: Vector3 = nr.global_transform * vs[vi]
					poly.append([snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)])
				polys.append(poly)
		var f: FileAccess = FileAccess.open(posdump + "_nav.json", FileAccess.WRITE)
		if f != null:
			var walls: Array = []
			for b: Node in get_tree().get_nodes_in_group(&"barricades"):
				walls.append([str(b.name), snappedf((b as Node3D).global_position.x, 0.1), snappedf((b as Node3D).global_position.y, 0.1), snappedf((b as Node3D).global_position.z, 0.1)])
			f.store_string(JSON.stringify({"polys": polys, "windows": walls}))
			f.close()


func _pd_tick() -> void:
	var p: Player = _map.player
	if p == null:
		return
	var pp: Vector3 = p.global_position
	var fw: Vector3 = -p.global_basis.z
	var row: Dictionary = {"t": snappedf(_game_t, 0.1), "r": RoundManager.current_round, "x": snappedf(pp.x, 0.01), "y": snappedf(pp.y, 0.01), "z": snappedf(pp.z, 0.01),
		"fx": snappedf(fw.x, 0.01), "fz": snappedf(fw.z, 0.01), "hp": snappedf(p.hp, 1.0), "down": p.downed}
	if _pb != null and is_instance_valid(_pb) and _pb.brain != null:
		row["a"] = _pb.brain.action
		var tb: BotTrainer = _pb.trainer
		if tb != null:
			row["ph"] = tb.phase_name()
			row["f"] = tb.followers
			row["hd"] = snappedf(minf(tb.head_d, 99.0), 0.1)
			row["ad"] = snappedf(minf(tb.ahead_d, 99.0), 0.1)
			row["rt"] = tb.route.id if tb.route != null else ""
			row["dir"] = tb.dir
			row["kd"] = [snappedf(tb._kite_dir.x, 0.01), snappedf(tb._kite_dir.z, 0.01)]
		var cw: WeaponInstance = _pb.brain.aim.cur()
		row["mag"] = cw.mag if cw != null else 0
	var zs: Array = []
	for z: Zombie in (_map.director.active_zombies() if _map.director != null else []):
		var zp: Vector3 = z.global_position
		var known: bool = _pb != null and is_instance_valid(_pb) and _pb.brain != null and _pb.brain.perception.is_known(z)
		zs.append([snappedf(zp.x, 0.01), snappedf(zp.y, 0.01), snappedf(zp.z, 0.01), Zombie.State.keys()[z.state].left(4), 1 if known else 0, snappedf(z.speed, 0.1), str(z.enemy_id).left(4)])
	row["zs"] = zs
	_pd_f.store_line(JSON.stringify(row))


## The tuning flags (--open-doors, --power, --give): a test bed for the trainer's mechanics apart from its economy.
func _apply_tuning() -> void:
	if open_doors != "":
		for n: Node in _map.find_children("*", "", true, false):
			if n is BuyDoor and (open_doors == "all" or open_doors.split(",").has(String((n as BuyDoor).door_id))):
				(n as BuyDoor).open(1)
	if power_on:
		for n2: Node in _map.find_children("*", "", true, false):
			if n2.has_method("run_sequence") and n2.get_script() != null and str((n2.get_script() as Script).resource_path).ends_with("power_switch.gd"):
				n2.call("run_sequence", 1)
	if give != "" and _map.player != null:
		for g: String in give.split(","):
			if (GLData.table("weapons")["weapons"] as Dictionary).has(g):
				_map.player.weapons.give_weapon(StringName(g))
			elif not PerkManager.perk_data(StringName(g)).is_empty():
				PerkManager.grant(_map.player.player_id, StringName(g))
			else:
				print("[soak] --give: no weapon or perk '%s'" % g)


## ee_full: once the bots have tuned the radio up to its last frequency (they never take the player's commit), the
## harness locks it as the player would.
func _tick_ee() -> void:
	var q: StringName = &"map00_radio"
	if _ee_committed_t >= 0.0 or not QuestManager.is_active(q, &"s2_tune"):
		return
	var prog: Variant = QuestManager.progress(q, &"s2_tune")
	if (int(prog) if prog != null else 0) < 2:
		return
	_ee_committed_t = _game_t
	_ee_events.append("r%d %.0fs the bots handed over the last frequency; the player locks it" % [RoundManager.current_round, _game_t])
	for n: Node in _map.find_children("*", "FieldRadio", true, false):
		(n as FieldRadio).lock_frequency("7.440")


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
		return RoundManager.state != RoundManager.State.ROUND
	if cr.phase == CousinsRound.Phase.BORED or cr.bored_count > 0:
		_metrics.extra["cousins"] = "left (bored)"
		return RoundManager.state != RoundManager.State.ROUND
	return RoundManager.current_round > 10


func _end_run(why: String) -> void:
	if scenario == "cousins":
		if not _metrics.extra.has("cousins"):
			_metrics.extra["cousins"] = "wipe" if why == "wipe" else why
		var cr: CousinsRound = _map.director.cousins if _map.director != null else null
		_metrics.extra["cousins_dead"] = cr.dead_count() if cr != null else 0
		_metrics.extra["cousins_time_s"] = snappedf(cr.t, 0.1) if cr != null else 0.0
	if _dummy != null:
		_metrics.extra["dummy_laps"] = int(_dummy.get("laps"))
		_metrics.extra["dummy_reversals"] = int(_dummy.get("reversals"))
		_metrics.extra["player_kit"] = player_kit
		_metrics.extra["dummy_power_round"] = int(_dummy.get("power_round"))
		_metrics.extra["dummy_perks_bought"] = int(_dummy.get("perks_bought"))
		_metrics.extra["dummy_scrip_end"] = Economy.get_scrip(_map.player.player_id)
		_metrics.extra["dummy_unstuck"] = int(_dummy.get("unstuck"))
	if not _metrics.extra.has("power_round"):
		_metrics.extra["power_round"] = 0   # the power never came on
	for er: int in [3, 5, 8]:   # T-078: Scrip earned by P1 by the end of rounds 3 / 5 / 8 (-1: not reached)
		_metrics.extra["earned_r%d" % er] = int(_earned_by_round.get(er, -1))
	print("[soak]   P1 Scrip earned by round end: %s (total %d)" % [str(_earned_by_round), _earned])
	print("[soak]   P1 bonus Scrip by kind: %s" % str(_bonus_by_kind))
	_metrics.extra["bonus_by_kind"] = str(_bonus_by_kind).replace(",", ";")
	if scenario == "botmode" and _pb != null and is_instance_valid(_pb):
		var ts: Dictionary = _pb.trainer.summary() if _pb.trainer != null else _pb.last_summary
		for k: Variant in ts.keys():
			_metrics.extra["pb_" + str(k)] = ts[k]
		_metrics.extra["pb_training_share"] = snappedf(float(ts.get("training_s", 0.0)) / maxf(1.0, _game_t), 0.01)
		_metrics.extra["pb_hits_per_min_training"] = snappedf(float(ts.get("hits_training", 0)) / maxf(0.01, float(ts.get("training_s", 0.0)) / 60.0), 0.01)
		_metrics.extra["pb_bots"] = bots_n
		if _pb.brain != null:
			_metrics.extra["pb_shots"] = _pb.brain.aim.shots
			_metrics.extra["pb_hit_share"] = snappedf(float(_pb.brain.aim.hits_landed) / float(maxi(1, _pb.brain.aim.shots)), 0.01)
			_metrics.extra["pb_fire_blocks"] = str(_pb.brain.aim.fire_blocks)
			_metrics.extra["pb_los"] = "self %d, crawler blockers %s" % [_pb.brain.aim.los_self_hits, str(_pb.brain.aim.los_crawler_blockers)]
		_metrics.extra["pb_handbacks"] = _pb.handbacks
		_metrics.extra["pb_scrip_end"] = Economy.get_scrip(1)
		_metrics.extra["pb_perks"] = ",".join(PackedStringArray(PerkManager.owned(1).map(func(x: Variant) -> String: return str(x))))
		var guns: PackedStringArray = []
		if _map.player != null and _map.player.weapons != null:
			for w: WeaponInstance in _map.player.weapons.slots:
				guns.append(str(w.id))
		_metrics.extra["pb_guns"] = ",".join(guns)
		var per_round: PackedStringArray = []
		for r: Variant in _pb_rounds.keys():
			per_round.append("r%d:%d/%d" % [int(r), int((_pb_rounds[r] as Array)[0]), int((_pb_rounds[r] as Array)[1])])
		_metrics.extra["pb_downs_hits_by_round"] = " ".join(per_round)
		if _pb.brain != null and _pb.brain.crawler != null:
			var cs: Dictionary = _pb.brain.crawler.stats
			_metrics.extra["pb_crawlers"] = "%d made, %d failed, %.0f s held" % [int(cs["made"]), int(cs["failed"]), float(cs["held_s"])]
		print("[soak]   agent: %s" % str(ts))
		if _pb.trainer != null:
			for hl: String in _pb.trainer.hit_log:
				print("[soak]   agent HIT ", hl)
		_pb.set_on(false, "soak end")
		_pb = null
	if _map.squad != null and _map.squad.ee != null:
		var hub: BotEEHub = _map.squad.ee
		_metrics.extra["ee_mode"] = hub.mode()
		_metrics.extra["ee_tasks"] = hub.tasks_started
		_metrics.extra["ee_steps_by_bots"] = hub.steps_by_bots
		_metrics.extra["ee_inputs_by_bots"] = hub.inputs_by_bots
		_metrics.extra["ee_egg_failures"] = hub.egg_failures
		_metrics.extra["ee_egg_failures_on_bot_steps"] = hub.egg_failures_bot
		if QuestManager.has_quest(&"map00_radio"):
			var got: Variant = QuestManager.progress(&"map00_radio", &"s1_notes")
			_metrics.extra["ee_notes"] = 3 if QuestManager.is_step_done(&"map00_radio", &"s1_notes") else ((got as Array).size() if got is Array else 0)
			var tp: Variant = QuestManager.progress(&"map00_radio", &"s2_tune")
			_metrics.extra["ee_tune_locks"] = 3 if QuestManager.is_step_done(&"map00_radio", &"s2_tune") else (int(tp) if tp != null else 0)
			_metrics.extra["ee_handoff_s"] = snappedf(_ee_committed_t, 1.0)
			_metrics.extra["ee_complete"] = QuestManager.is_complete(&"map00_radio")
		for e: String in _ee_events:
			print("[soak]   EE ", e)
	_metrics.extra["wall_s"] = snappedf(float(Time.get_ticks_msec() - _wall0) / 1000.0, 0.1)
	_metrics.extra["frame_ms"] = snappedf(_phys_us / maxf(1.0, float(_frames)) / 1000.0, 0.01)
	_metrics.extra["speed"] = speed
	if _map.squad != null:
		var ts: Dictionary = _map.squad.think_stats()
		_metrics.extra["brain_ms_per_bot_frame"] = snappedf(float(ts["ms_per_bot_frame"]), 0.001)
		_metrics.extra["brain_ms_per_think"] = snappedf(float(ts["ms_per_think"]), 0.001)
	if _map.squad != null and _map.squad.brains.size() > 0:   # U03 section 3: the locomotion layer's own cost per bot (tick incl. body movement)
		var us: Array = []
		for b: BotBrain in _map.squad.brains:
			if b.loco != null:
				us.append("%.0f/%.0f" % [b.loco.avg_tick_us(), b.loco.avg_body_us()])
		if not us.is_empty():
			_metrics.extra["loco_us_tick_body"] = ",".join(PackedStringArray(us))
	if _pd_f != null:
		_pd_f.close()
		_pd_f = null
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
	var sm2: Dictionary = _metrics.summary()
	if scenario == "botmode":
		sm2["pb_downs_per_round"] = float(sm2.get("human_downs", 0)) / float(maxi(1, int(sm2.get("round_reached", 1))))
	_results.append(sm2)
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


## (T-071 pass 3) one line per round start in botmode: what the last round earned and spent, the training
## share, Scrip in hand, guns, perks, open doors, the plan's step.
func _pb_round_line() -> void:
	var tr_s: float = float(_pb.trainer.stats.get("training_s", 0.0)) if _pb.trainer != null else 0.0
	var guns: PackedStringArray = []
	for w: WeaponInstance in _map.player.weapons.slots:
		guns.append(str(w.id))
	var doors: PackedStringArray = []
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).is_open:
			doors.append(String((n as BuyDoor).door_id).trim_prefix("door_"))
	var dt: float = maxf(1.0, _game_t - _pb_t0)
	print("[soak] R%d at %.0fs: last round %.0fs earned %d spent %d train %.0f%% | scrip %d | %s | %s | doors %s power %s | step %s" % [
		RoundManager.current_round, _game_t, dt, _pb_earned, _pb_spent, 100.0 * (tr_s - _pb_train0) / dt, Economy.get_scrip(1), ",".join(guns),
		",".join(PackedStringArray(PerkManager.owned(1).map(func(x: Variant) -> String: return str(x)))), ",".join(doors), str(GameState.power_on),
		str(AgentPlan.current_for(_pb.brain)) if _pb.brain != null else "-"])
	_pb_round_seen = RoundManager.current_round
	_pb_earned = 0
	_pb_spent = 0
	_pb_train0 = tr_s
	_pb_t0 = _game_t


func _on_scrip_changed(pid: int, _total: int, delta: int) -> void:
	if pid != 1 or not _live:
		return
	if delta > 0:
		_pb_earned += delta
	else:
		_pb_spent -= delta


func _pb_round(r: int) -> Array:
	if not _pb_rounds.has(r):
		_pb_rounds[r] = [0, 0]
	return _pb_rounds[r]


## The batch's markdown table: one row per run and the mean.
func _write_table(dir: String) -> void:
	if scenario == "botmode":
		_write_table_cols(dir, [["round", "round_reached", "%d"], ["min", "minutes", "%.1f"], ["downs", "human_downs", "%d"],
			["downs/round", "pb_downs_per_round", "%.2f"], ["training %", "pb_training_share", "pct"], ["train mean", "pb_train_mean", "%.1f"],
			["train max", "pb_train_max", "%d"], ["4+ share", "pb_big_train_share", "pct"], ["spread m", "pb_train_spread_m", "%.1f"],
			["bunched", "pb_train_bunched", "pct"], ["cut-ins", "pb_cut_ins", "%d"], ["hits", "pb_hits", "%d"], ["hits training", "pb_hits_training", "%d"],
			["hits/min training", "pb_hits_per_min_training", "%.2f"], ["stuck s", "pb_stuck_s", "%.1f"], ["kills", "pb_kills", "%d"],
			["reversals", "pb_reversals", "%d"], ["passes", "pb_passes", "%d"], ["power r", "power_round", "%d"], ["bot downs", "bot_downs", "%d"]])
		return
	var cols: Array = [["round", "round_reached", "%d"], ["min", "minutes", "%.1f"], ["bot kills", "bot_kills", "%d"],
		["bot downs", "bot_downs", "%d"], ["downs/round", "bot_downs_per_round", "%.2f"], ["human downs", "human_downs", "%d"],
		["revive %", "revive_rate", "pct"], ["revived", "revived", "%d"], ["bled", "bled", "%d"], ["ttr s", "ttr_mean", "%.1f"],
		["stuck", "stuck_events", "%d"], ["stuck s", "stuck_time", "%.1f"], ["teleports", "teleports", "%d"], ["lost s", "lost_time", "%.0f"],
		["block ev", "block_events", "%d"], ["sustained", "block_sustained", "%d"], ["spent", "scrip_spent", "%d"],
		["wasted", "scrip_wasted", "%d"], ["kar98k>r10", "kar98k_late", "%d"], ["empty-mag", "empty_mag_events", "%d"], ["empty-mag s", "empty_mag_time", "%.0f"],
		["pistol s", "pistol_time", "%.0f"]]
	_write_table_cols(dir, cols)


func _write_table_cols(dir: String, cols: Array) -> void:
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


var _stall_round: int = -1
var _stall_t0: float = 0.0
var _stall_next: float = 0.0


## A round that runs past 5 minutes gets a report once a minute (T-057): the round's counters and every live
## zombie (kind, state, where, how far above the closest navmesh point), so a round that never ends says why.
func _watch_stall() -> void:
	if RoundManager.current_round != _stall_round:
		_stall_round = RoundManager.current_round
		_stall_t0 = _game_t
		_stall_next = 300.0
	if RoundManager.state != RoundManager.State.ROUND or _game_t - _stall_t0 < _stall_next:
		return
	_stall_next += 60.0
	var zs: Array = _map.director.active_zombies() if _map.director != null else []
	print("[soak] STALL round %d at %.0f s: alive %d, to_spawn %d, holdout %s, %d active zombies" % [_stall_round,
		_game_t - _stall_t0, RoundManager.alive, RoundManager.to_spawn, str(RoundManager.is_held()), zs.size()])
	var nav: RID = _map.get_world_3d().navigation_map
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		print("[soak]   player %s at %s alive %s downed %s spectating %s" % [Net.display_name(pl.player_id), pl.global_position.snapped(Vector3.ONE * 0.1),
			pl.is_alive(), pl.get("downed"), pl.get("spectating")])
	if _pb != null and is_instance_valid(_pb) and _pb.brain != null:
		var sb: BotBrain = _pb.brain
		print("[soak]   agent: %s | %s | known %d | trainer %s f%d h%.1f | scrip %d" % [str(sb.recent[-1]) if not sb.recent.is_empty() else "-",
			str(sb.top3), sb.perception.known.size(), _pb.trainer.phase_name() if _pb.trainer != null else "-",
			_pb.trainer.followers if _pb.trainer != null else 0, minf(_pb.trainer.head_d, 99.0) if _pb.trainer != null else 99.0, Economy.get_scrip(1)])
	for z: Zombie in zs:
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, z.global_position)
		var tg: Node3D = z.target
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, z.global_position, tg.global_position, true) if tg != null else PackedVector3Array()
		print("[soak]   %s%s %s at %s (navmesh %s) -> %s, path ends %s" % [z.enemy_id, " (crawler)" if z.is_crawler else "", Zombie.State.keys()[z.state], z.global_position.snapped(Vector3.ONE * 0.1),
			c.snapped(Vector3.ONE * 0.1), Net.display_name((tg as Player).player_id) if tg is Player else str(tg),
			path[path.size() - 1].snapped(Vector3.ONE * 0.1) if not path.is_empty() else "none"])
