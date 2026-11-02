extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Letzte Fahrt with the bots (UPDATE 10 section 2 acceptance, contract C7, DECISIONS T-153): three bots on Full
## Partner run the whole egg on map02 while the human (god mode, never shooting) stays with the squad. "--until-egg
## style forcing", declared: the game runs at TIME_SCALE; rounds are short (SHORT_ROUND zombies) so the floods and
## the round holds keep coming; when the lathe step waits for a flood it gets one; the human follows the lead bot (so
## the final steps and the floating key have a player near). Nothing completes a step for the bots. One run per
## process (PASS = the egg completed within MAX_GAME_MIN); tools run it three times and report the count.

const QUEST: StringName = &"map02_letzte_fahrt"
const TIME_SCALE: float = 2.0
const SHORT_ROUND: int = 8
const MAX_GAME_MIN: float = 55.0   # overridable: --lf-minutes=N

var _events: PackedStringArray = []
var _game_t: float = 0.0
var _max_min: float = MAX_GAME_MIN
var _skip_to: StringName = &""


func _init() -> void:
	tag = "letzte_fahrt"
	bots = 3
	stop_rounds = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--lf-minutes="):
			_max_min = float(a.get_slice("=", 1))
		elif a.begins_with("--lf-skip-to="):
			_skip_to = StringName(a.get_slice("=", 1))   # diagnostics only (a run that skips never counts)
	_timeout_s = _max_min * 60.0 + 240.0   # game seconds (the timer is scaled too)


func _body() -> void:
	Engine.time_scale = TIME_SCALE
	GLBus.purchase_denied.connect(func(pid: int, item: StringName, why: StringName) -> void:
		if String(item).begins_with("door"):
			print("[%s]   purchase denied: p%d %s (%s, has %d)" % [tag, pid, item, why, Economy.get_scrip(pid)]))
	GLBus.quest_step_completed.connect(func(q: StringName, s: StringName) -> void:
		if q == QUEST:
			_events.append("%.1f min %s" % [_game_t / 60.0, s])
			print("[%s]   step done: %s at %.1f game min (round %d)" % [tag, s, _game_t / 60.0, RoundManager.current_round]))
	GLBus.round_started.connect(func(_r: int, _sp: bool) -> void:
		RoundManager.to_spawn = mini(RoundManager.to_spawn, SHORT_ROUND)
		RoundManager.round_total = mini(RoundManager.round_total, SHORT_ROUND))
	if _map.squad != null and _map.squad.ee != null:
		_map.squad.ee.set_mode("full")
	_check(_map.squad != null and _map.squad.ee != null, "the squad's egg helper is on Full Partner")
	if _skip_to != &"":
		# diagnostics: the power thrown and the step's prerequisites done, so the bots start on the later steps
		GameState.set_flag(&"ballast_loaded", 1)
		var sw: PowerSwitch = _g("Pumpenschalter") as PowerSwitch
		if sw != null:
			sw.run_sequence(0)
		await _frames(10)
		QuestManager.debug_skipto(QUEST, _skip_to)
		var tb: Node = get_tree().get_first_node_in_group(&"totenhafen_ballast")
		if tb != null and QuestManager.is_step_done(QUEST, &"s1_ballast"):
			tb.call(&"spawn_shard")   # the skipped dumps would have left the shard
		for fl: Array in [[&"s2_cipher", &"lf_cipher_done"], [&"s6_boss", &"boat_key"], [&"s1_ballast", &"lf_ballast_done"]]:
			if QuestManager.is_step_done(QUEST, fl[0]):
				GameState.set_flag(fl[1], true)   # what the skipped steps would have set in the world
		print("[%s] SKIPPED to %s (a diagnostic run: it does not count)" % [tag, _skip_to])
	var last_step_t: float = 0.0
	var steps_done: int = 0
	while _game_t < _max_min * 60.0 and not QuestManager.is_complete(QUEST):
		await get_tree().create_timer(1.0).timeout
		_game_t += 1.0   # create_timer runs in game time (scaled)
		_follow_lead()
		if QuestManager.is_active(QUEST, &"s5a_injector") and _tide != null and not _tide.flooded and _tide.target <= -3.9:
			_tide.force_stage(&"high", 240.0)
			_events.append("%.1f min forced a flood for the lathe" % (_game_t / 60.0))
		if int(_game_t) % 30 == 0:
			_diag()
		var n: int = _done_count()
		if n != steps_done:
			steps_done = n
			last_step_t = _game_t
	var ok: bool = QuestManager.is_complete(QUEST)
	print("[%s] EGG %s at %.1f game min; steps done %d/%d" % [tag, "COMPLETE" if ok else "not complete", _game_t / 60.0, _done_count(), (QuestManager.steps_of(QUEST) as Array).size()])
	for e: String in _events:
		print("[%s]   %s" % [tag, e])
	if not ok:
		print("[%s]   stuck on: %s (no progress for %.1f game min)" % [tag, ", ".join(_active()), (_game_t - last_step_t) / 60.0])
	Engine.time_scale = 1.0
	_check(ok, "the bots finished Letzte Fahrt")


## Why the bots are (not) on each open step: the hub's gate + plan preview for every brain, and what they do.
func _diag() -> void:
	if _map.squad == null or _map.squad.ee == null:
		return
	var hub: Node = _map.squad.ee
	var parts: PackedStringArray = []
	for sd: Variant in QuestManager.steps_of(QUEST):
		var sid: StringName = StringName(str((sd as Dictionary)["id"]))
		if not QuestManager.is_active(QUEST, sid):
			continue
		var t: Dictionary = BotEECatalog.task_def(sd as Dictionary)
		for b: BotBrain in _map.squad.brains:
			var r: Dictionary = hub.call("try_brain", b, QUEST, sid, t, false, null)
			parts.append("%s/p%d:%s%s" % [sid, b.player.player_id, str(r.get("code", "?")), ("(" + str(r.get("do", "")) + ")") if r.has("do") else ""])
			break
	var busy: PackedStringArray = []
	for b2: BotBrain in _map.squad.brains:
		if b2.ee != null and b2.ee.active():
			var pl: Dictionary = b2.ee.get("_plan") as Dictionary
			var pn: Node3D = pl.get("node") as Node3D if pl.get("node") is Node3D and is_instance_valid(pl.get("node")) else null
			busy.append("p%d=%s/%s do=%s at %s%s prog=%s" % [b2.player.player_id, b2.ee.task.get("sid", ""), b2.ee.task.get("type", ""),
				str(pl.get("do", "")), str(b2.player.global_position.snapped(Vector3.ONE * 0.1)),
				(" -> %s %.1f m" % [pn.name, pn.global_position.distance_to(b2.player.global_position)]) if pn != null else "",
				str(QuestManager.progress(QUEST, StringName(str(b2.ee.task.get("sid", ""))))) + " scrip=%d" % Economy.get_scrip(b2.player.player_id)])
	print("[%s]   %.1f min r%d power=%s loaded=%s dumped=%s | %s | busy %s" % [tag, _game_t / 60.0, RoundManager.current_round,
		GameState.power_on, GameState.flags.get(&"ballast_loaded", 0), GameState.flags.get(&"ballast_dumped", 0), ", ".join(parts), ", ".join(busy) + " | squad " + _squad_state()])


## Each bot up or down, and how many zombies are alive (a wiped squad freezes the round: the human never shoots).
func _squad_state() -> String:
	var out: PackedStringArray = []
	for b: BotBrain in _map.squad.brains:
		out.append("p%d %s" % [b.player.player_id, "down" if b.player.downed else ("out" if b.player.spectating else "up")])
	return "%s, zombies %d" % [" ".join(out), _dir.active_zombies().size() if _dir != null else -1]


func _done_count() -> int:
	var n: int = 0
	for s: Variant in QuestManager.steps_of(QUEST):
		var sid: StringName = StringName(str((s as Dictionary).get("id", s) if s is Dictionary else s))
		if QuestManager.is_step_done(QUEST, sid):
			n += 1
	return n


func _active() -> PackedStringArray:
	var out: PackedStringArray = []
	for s: Variant in QuestManager.steps_of(QUEST):
		var sid: StringName = StringName(str((s as Dictionary).get("id", s) if s is Dictionary else s))
		if QuestManager.is_active(QUEST, sid):
			out.append(String(sid))
	return out


## The human keeps up with the squad: a few metres behind the nearest living bot (or aboard during the sail).
func _follow_lead() -> void:
	if _p == null or not _p.is_alive():
		return
	if GameState.has_flag(&"sailing") or QuestManager.is_active(QUEST, &"s9_sail") and GameState.has_flag(&"curtain_open"):
		var sail: Node3D = _g("UboatSail") as Node3D
		if sail != null and _p.global_position.distance_to(sail.global_position) > 4.0:
			_p.global_position = sail.global_position + sail.global_basis * Vector3(0.8, 0.2, 1.4)
		return
	var best: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		var b: Player = n as Player
		if b != null and b.is_alive() and (best == null or b.player_id < best.player_id):
			best = b
	if best != null and _p.global_position.distance_to(best.global_position) > 6.0:
		_p.global_position = best.global_position + Vector3(1.5, 0.3, 1.5)
		_p.velocity = Vector3.ZERO
