extends Node
## Smoke test (and the acceptance clip) for bots on the easter egg (Update 04 section 5, T-067): Map 0, 2 bots, a
## god-mode human standing in the taproom, "Bot Easter-Egg Help" on When Asked (the default):
##   1. for 15 s no bot touches the egg on its own
##   2. asked for the radio before the notes are in, the squad refuses ("isn't open yet")
##   3. a map mark on note I (BotSquad.ee_assign_node): the best bot takes exactly that note; ee_task_of shows it
##   4. ee_assign the notes step (pid -1): the best bot takes the other two (opening doors with its own Scrip)
##   5. ee_assign the radio: the bot locks two frequencies and hands the last one (the commit) to the player; the
##      harness locks it as the player; the egg completes
##   6. ee_cancel, ee_bot_mode off: an assignment is refused; no egg step ever failed
## With a renderer it is the clip: a chase camera on the working bot, the AI debug labels show its egg task.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/smoke_ee_bots.tscn
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>.avi --fixed-fps 30
##         --quit-after 1800 --path . res://gravelight/tools_src/smoke_ee_bots.tscn -- --clip
## Prints "[eebots] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const Q: StringName = &"map00_radio"

var _map: MapRoot
var _t: float = 0.0
var _phase: int = 0
var _phase_t: float = 0.0
var _live: bool = false
var _fails: PackedStringArray = []
var _clip: bool = false
var _cam: Camera3D = null
var _focus_pid: int = -1
var _egg_fails: int = 0
var _lines: PackedStringArray = []
var _done: bool = false
var _timeout: float = 300.0
var _trace_t: float = 0.0


func _ready() -> void:
	_clip = Array(OS.get_cmdline_user_args()).has("--clip")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_ee_bots_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_ee_bots_settings.cfg"
	GLSettings.values["bot_ee_help"] = "ask"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 2
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.quest_step_failed.connect(func(q: StringName, s: StringName, r: StringName) -> void:
		_egg_fails += 1
		print("[eebots] t=%.0f egg step %s/%s FAILED (%s)" % [_t, q, s, r]))
	GLBus.quest_step_completed.connect(func(q: StringName, s: StringName) -> void: print("[eebots] t=%.0f step %s/%s done" % [_t, q, s]))
	GLBus.vo_line_started.connect(func(id: StringName, _spk: StringName, text: String, _d: float) -> void:
		if String(id).contains("_SQ4_EE_"):
			_lines.append(String(id))
			print("[eebots] t=%.1f line %s: \"%s\"" % [_t, id, text]))


func _check(cond: bool, what: String) -> void:
	print("[eebots] %-78s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	if not _live:
		_try_live()
		return
	_t += delta
	_phase_t += delta
	_drive_camera(delta)
	var sq: BotSquad = _map.squad
	_trace_t -= delta
	if _trace_t <= 0.0:
		_trace_t = 10.0
		for b: BotBrain in sq.brains:
			if b.ee != null and b.ee.active():
				var pn: Variant = b.ee._plan.get("node")
				print("[eebots] t=%.0f %s: action %s, ee value %.2f, plan %s %s, at %s, round %d (%d up, %d to spawn)" % [_t, Net.display_name(b.player.player_id), b.action,
					b.ee.value(), str(b.ee._plan.get("do", "-")), String((pn as Node).name) if pn is Node and is_instance_valid(pn) else "-",
					b.player.global_position.snapped(Vector3.ONE * 0.1), RoundManager.current_round, _map.director.active_zombies().size(), RoundManager.to_spawn])
				if OS.get_cmdline_user_args().has("--debug") and pn is Node3D and is_instance_valid(pn):
					var n3: Node3D = pn as Node3D
					var nav: RID = b.player.get_world_3d().navigation_map
					var dest: Vector3 = b.snap(n3.global_position)
					var raw: PackedVector3Array = NavigationServer3D.map_get_path(nav, b.player.global_position, dest, true, sq.nav_mask())
					var crossed: PackedStringArray = []
					for d: BuyDoor in b.loco_doors():
						if ZombieDirector.door_crossed(d, raw):
							crossed.append("%s%s" % [d.name, " (open)" if d.is_open else ""])
					print("[eebots]    node at %s, snap %s, stand %s, raw path %d pts ends %s, crosses %s, open path %d pts" % [n3.global_position, dest, b.stand_point(n3),
						raw.size(), raw[raw.size() - 1] if not raw.is_empty() else Vector3.INF, ", ".join(crossed), b.open_path(b.player.global_position, dest).size()])
					var lp: PackedVector3Array = b.loco.debug_path()
					print("[eebots]    errand %s, loco path %d pts (next %s), speed %.1f, until %.0f" % [str(b.ee._errand.get("kind", "-")), lp.size(), lp[1] if lp.size() > 1 else Vector3.INF,
						b.player.horizontal_speed(), float(b.ee._errand.get("until", -1.0)) - sq.time()])
	match _phase:
		0:
			if _phase_t < (4.0 if _clip else 15.0):
				return
			var got: Variant = QuestManager.progress(Q, &"s1_notes")
			_check(not (got is Array and not (got as Array).is_empty()), "When Asked: no bot took a note on its own (%.0f s)" % _phase_t)
			var r: Dictionary = sq.ee_assign(Q, &"s2_tune")
			_check(not bool(r["ok"]) and str(r["reason"]).contains("open"), "the radio before the notes: refused (\"%s\")" % r["reason"])
			_check(not sq.ee_can_assign(Q, &"s2_tune") and sq.ee_can_assign(Q, &"s1_notes"), "ee_can_assign: the notes yes, the radio not yet")
			var note_a: Node = _map.find_child("NoteA", true, false)
			var r2: Dictionary = sq.ee_assign_node(note_a)
			_check(bool(r2["ok"]) and int(r2["pid"]) > 0, "a map mark on note I goes to a bot (P%d)" % int(r2["pid"]))
			_focus_pid = int(r2["pid"])
			var st: Dictionary = sq.ee_task_of(_focus_pid)
			_check(str(st.get("label", "")).begins_with("Collecting the radio notes"), "ee_task_of: \"%s\"" % st.get("label", ""))
			_next()
		1:
			var got1: Variant = QuestManager.progress(Q, &"s1_notes")
			if got1 is Array and (got1 as Array).has(&"note_a"):
				_check((got1 as Array).size() == 1, "the marked note, and only that one, was taken (%s)" % str(got1))
				var r3: Dictionary = sq.ee_assign(Q, &"s1_notes")
				_check(bool(r3["ok"]), "ee_assign the notes step to the best bot (P%d)" % int(r3["pid"]))
				_focus_pid = int(r3["pid"])
				_next()
			elif _phase_t > 60.0:
				_check(false, "the marked note was taken within 60 s")
				_finish()
		2:
			if QuestManager.is_step_done(Q, &"s1_notes"):
				_check(true, "the bot took the other two notes (%.0f s)" % _phase_t)
				_check(sq.ee.knowledge.knows("frequencies"), "the squad now knows the frequencies")
				var r4: Dictionary = sq.ee_assign(Q, &"s2_tune")
				_check(bool(r4["ok"]), "ee_assign the radio (P%d)" % int(r4["pid"]))
				_focus_pid = int(r4["pid"])
				_next()
			elif _phase_t > _timeout:
				_check(false, "the notes were taken within %.0f s" % _timeout)
				_finish()
		3:
			var prog: Variant = QuestManager.progress(Q, &"s2_tune")
			var idx: int = int(prog) if prog != null else 0
			var st2: Dictionary = sq.ee_task_of(_focus_pid)
			if idx >= 2 and str(st2.get("state", "")) == "handoff":
				_check(not QuestManager.is_complete(Q), "the bot stopped before the last frequency (the player's commit)")
				_check(str(st2.get("label", "")).contains("last one's yours"), "ee_task_of: \"%s\"" % st2.get("label", ""))
				for n: Node in _map.find_children("*", "FieldRadio", true, false):
					(n as FieldRadio).lock_frequency("7.440")
				_next()
			elif _phase_t > 90.0:
				_check(false, "the bot tuned two frequencies within 90 s (at %d, %s)" % [idx, str(st2)])
				_finish()
		4:
			if _phase_t < 3.0:
				return
			_check(QuestManager.is_complete(Q), "the player's lock completes \"Glasmacher Calling\"")
			_check(sq.ee_task_of(_focus_pid).is_empty(), "the bot's task ended with the step")
			sq.ee_cancel()
			GLConsole.call("run", "ee_bot_mode off")
			var r5: Dictionary = sq.ee_assign(Q, &"s1_notes")
			_check(not bool(r5["ok"]) and str(r5["reason"]).contains("off"), "Off: refused (\"%s\")" % r5["reason"])
			_check(_egg_fails == 0, "no egg step failed (%d)" % _egg_fails)
			_check(_lines.size() >= 2, "the bots spoke their egg lines (%d: %s)" % [_lines.size(), ", ".join(_lines.slice(0, 6))])
			_finish()


func _next() -> void:
	_phase += 1
	_phase_t = 0.0
	print("[eebots] phase %d at t=%.0fs" % [_phase, _t])


func _try_live() -> void:
	if _map.player == null or not _map.player.is_inside_tree() or _map.squad == null or _map.squad.ee == null:
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0:
		return
	_live = true
	for pid: int in GameState.bot_ids:
		Economy.grant(pid, 6000)
	_check(_map.squad.ee.mode() == "ask", "Bot Easter-Egg Help: When Asked by default")
	if _clip:
		_cam = Camera3D.new()
		_cam.fov = 72.0
		_map.add_child(_cam)
		_cam.global_position = _map.player.global_position + Vector3(0, 3, 4)
		_cam.make_current()
		GLConsole.call("run", "ai_debug 1")
		GLConsole.call("run", "ai_debug panel")   # labels only (the panel toggles off)
	print("[eebots] live")


## Behind and above the bot doing the egg step (the human when none), pulled in off walls.
func _drive_camera(delta: float) -> void:
	if _cam == null:
		return
	var tgt: Player = _map.player
	if _focus_pid > 0:
		var p: Player = _map.squad.player_by_id(_focus_pid)
		if p != null:
			tgt = p
	var back: Vector3 = tgt.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var want: Vector3 = tgt.global_position + back * 3.6 + Vector3.UP * 2.3
	var from: Vector3 = tgt.global_position + Vector3.UP * 1.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, want, 1, [tgt.get_rid()])
	var r: Dictionary = tgt.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		want = from.lerp(r["position"], 0.85)
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var look: Vector3 = tgt.global_position + Vector3.UP * 1.1 - back * 1.5
	if _cam.global_position.distance_to(look) > 0.5:
		_cam.look_at(look, Vector3.UP)


func _finish() -> void:
	if _done:
		return
	_done = true
	for line: String in _map.squad.report():
		print("[eebots] ", line)
	print("[eebots] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
