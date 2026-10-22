extends Node
## Headless smoke test for the bots' spawn kit and the objective planner (bots.json "spawn_kit" / "local_ai").
## A solo match with 2 bots and a god-mode human standing at the spawn:
##   1. every bot spawns holding a Thompson with Ironhide Stout and Second Wind Schnapps (and 250 max health)
##   2. the planner bot runs the map's easter egg on its own: on Map 0 "Glasmacher Calling" (opening the doors to
##      the three radio notes with its own Scrip, taking them, tuning the radio); on Map 1 the first Requiem steps
##      (power, a pylon) as far as the time allows (--map=map01, report only)
##   3. a bot that goes down and is revived gets its kit perks back
## --llm uses the real local model (Ollama must be installed; the planner falls back to its scores if not);
## the default is the scripted planner, so the run is deterministic.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_bot_ai.tscn [-- --llm --map=map01 --timeout=600]
## Prints "[botai] ..." lines, the squad report, and RESULT PASS/FAIL (exit code 0/1).

const MAPS: Dictionary = {"map00": "res://gravelight/maps/map00_crossroads/map00.tscn", "map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"}

var _map: Node3D
var _t: float = 0.0
var _phase: int = 0
var _phase_t: float = 0.0
var _fails: PackedStringArray = []
var _map_key: String = "map00"
var _timeout: float = 600.0
var _done: bool = false
var _steps: PackedStringArray = []
var _report_t: float = 0.0
var _downed_bot: Player = null
var _downed_checked: bool = false


func _ready() -> void:
	GameState.bot_ai_mode = "scripted"
	for a: String in OS.get_cmdline_user_args():
		if a == "--llm":
			GameState.bot_ai_mode = "local"
		elif a.begins_with("--map="):
			_map_key = a.substr(6)
		elif a.begins_with("--timeout="):
			_timeout = float(a.substr(10))
	ProfileSave.path = "user://_qa_botai_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 2
	GameState.god_mode = true
	QuestManager.pending_seed = 4471
	_map = (load(str(MAPS.get(_map_key, MAPS["map00"]))) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.quest_step_completed.connect(func(q: StringName, s: StringName) -> void:
		_steps.append("%s/%s" % [q, s])
		print("[botai] quest step %s/%s done at t=%.0fs" % [q, s, _t]))
	GLBus.door_opened.connect(func(d: StringName, by: int) -> void:
		print("[botai] door %s opened by P%d at t=%.0fs" % [d, by, _t]))
	GLBus.power_activated.connect(func() -> void: print("[botai] power on at t=%.0fs" % _t))
	GLBus.purchase_made.connect(func(p: int, item: StringName, cost: int) -> void:
		if GameState.is_bot(p):
			print("[botai] P%d bought %s for %d at t=%.0fs" % [p, item, cost, _t]))


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[botai] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[botai] %-70s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _squad() -> BotSquad:
	return (_map as MapRoot).squad if _map is MapRoot else null


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	var sq: BotSquad = _squad()
	if sq == null or sq.brains.is_empty():
		if _t > 20.0:
			_fail("no bot squad")
			_finish()
		return
	_report_t -= delta
	if _report_t <= 0.0:
		_report_t = 30.0
		var pl: BotPlanner = sq.planner()
		print("[botai] t=%.0fs round %d | %s" % [_t, RoundManager.current_round, pl.status_line() if pl != null else "no planner"])
	match _phase:
		0:
			if _t < 2.0:
				return
			_check_kit(sq)
			_check(sq.planner() != null, "one bot has the objective planner (%s)" % GameState.bot_ai_mode)
			for pid: int in GameState.bot_ids:
				Economy.grant(pid, 6000)   # doors and the odd perk on the way: the egg needs ~3000 on Map 0
			_next()
		1:
			_tick_egg(sq)
		2:
			_tick_revive(sq)


func _next() -> void:
	_phase += 1
	_phase_t = 0.0
	print("[botai] phase %d at t=%.0fs" % [_phase, _t])


func _check_kit(sq: BotSquad) -> void:
	for b: BotBrain in sq.brains:
		var p: Player = b.player
		var w: WeaponInstance = p.weapons.current()
		var who: String = Net.display_name(p.player_id)
		_check(w != null and String(w.base_id()) == "thompson", "%s spawns holding the Thompson (%s)" % [who, str(w.id) if w != null else "-"])
		_check(PerkManager.has_perk(p.player_id, &"ironhide_stout") and PerkManager.has_perk(p.player_id, &"second_wind"),
			"%s spawns with Ironhide Stout and Second Wind (%s)" % [who, str(PerkManager.owned(p.player_id))])
		_check(p.max_hp >= 249.0, "%s has Ironhide's health (%.0f)" % [who, p.max_hp])
		_check(p.weapons.find_weapon_base(&"m1911") != null, "%s keeps the start pistol" % who)


func _main_quest() -> StringName:
	var q: Array[StringName] = QuestManager.quest_ids()
	return q[0] if not q.is_empty() else &""


func _tick_egg(sq: BotSquad) -> void:
	var qid: StringName = _main_quest()
	var done: bool = qid != &"" and QuestManager.is_complete(qid)
	if done or _phase_t > _timeout:
		var pl: BotPlanner = sq.planner()
		if _map_key == "map00":
			_check(done, "the planner bot finished \"%s\" on its own (%.0fs)" % [QuestManager.display_name_of(qid), _phase_t])
		else:
			print("[botai] (report) %s: steps done %s" % [qid, str(_steps)])
			_check(not _steps.is_empty(), "the planner bot completed at least one Requiem step")
		if pl != null:
			for h: String in pl.history:
				print("[botai]   pick ", h)
			if pl.ai != null:
				print("[botai] local AI: %s, %d requests, %d answered, %d failed" % [pl.ai.status_text(), pl.ai.requests, pl.ai.answered, pl.ai.failed])
		if _map_key != "map00":
			_finish()   # the revive check needs the compact Map 0 (on Map 1 the squad may be zones apart)
			return
		_next()


## Down a bot that isn't the planner and let the squad revive it: its kit perks come back.
func _tick_revive(sq: BotSquad) -> void:
	if _downed_bot == null:
		for b: BotBrain in sq.brains:
			if b.planner == null:
				_downed_bot = b.player
		if _downed_bot == null:
			_downed_bot = sq.brains[0].player
		_downed_bot.down()
		print("[botai] downed %s on purpose" % Net.display_name(_downed_bot.player_id))
		return
	if _phase_t < 2.0:
		return
	if _phase_t > 2.0 and not _downed_checked:
		_downed_checked = true
		# co-op rule: every perk goes, except the bot's bonus perk (U02 section 5: its trait)
		var left: Array = PerkManager.owned(_downed_bot.player_id).duplicate()
		left.erase(PerkManager.bonus_perk(_downed_bot.player_id))
		_check(_downed_bot.downed and left.is_empty(), "a downed bot loses its perks except the bonus perk (co-op rule)")
	if not _downed_bot.downed and _phase_t > 2.5:
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(PerkManager.has_perk(_downed_bot.player_id, &"ironhide_stout") and PerkManager.has_perk(_downed_bot.player_id, &"second_wind"),
			"revived, it gets Ironhide and Second Wind back (%s)" % str(PerkManager.owned(_downed_bot.player_id)))
		_finish()
	elif _phase_t > 60.0:
		_fail("the downed bot was not revived within 60 s")
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var sq: BotSquad = _squad()
	if sq != null:
		for line: String in sq.report():
			print("[botai] ", line)
	print("[botai] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
