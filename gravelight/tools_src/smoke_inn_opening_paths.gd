extends Node
## Headless smoke (T-076): Map 0's round 1 opening ("the bar empties", InnOpening) plays on EVERY way a player
## starts the map, not only when a smoke drops the map scene in directly. Each case starts the map exactly the way
## its menu button does (the same functions, the same GameState / Campaign set-up), then checks: the patrons are in
## the taproom and visible before round 1 and all inside the starting camera's view (within 56 deg of its forward:
## an 80 deg FOV at 16:9), the patrons chat and the cue ("What was that?") plays before round 1, which starts no
## sooner than look.min_seconds after the map appears, the opening goes RUNNING and the caught patrons rise.
##   launcher        Play.bat's dev launcher, "GRAVELIGHT — Crossroads Inn (Map 0)", round 1, 0 bots
##   launcher_bots   the same with 3 bots (the user's settings)
##   botmode         the launcher's "Bot mode — Map 0" button (play_botmode.tscn, PlayerBot.pending_on)
##   hub             the full menu: GRAVELIGHT -> Play (MenuCharacter._start, single map)
##   campaign        the full menu's Campaign start (Campaign.begin(): a fresh start is not an "arrival")
##   restart         the pause menu / game over "restart" (reload_current_scene) after the launcher case
##   coop_host       a co-op host alone in the lobby (Net.host_game on 127.0.0.1, Net.start_match)
## The user's settings file is read (bots, skill...) but never written: GLSettings.path points at a QA copy.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_inn_opening_paths.tscn [-- --case=<name>]

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const CASES: PackedStringArray = ["launcher", "launcher_bots", "botmode", "hub", "campaign", "restart", "coop_host"]
const CASE_TIMEOUT: float = 60.0

var _cases: PackedStringArray = []
var _i: int = -1
var _t: float = 0.0
var _fails: PackedStringArray = []
var _st: Dictionary = {}
var _map_seen: Node = null
var _said: Array[String] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_paths_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_paths_settings.cfg"   # the user's values are loaded; nothing is written back
	Campaign.cutscene_speed = 1.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			_cases = a.substr(7).split(",")
	if _cases.is_empty():
		_cases = CASES
	GLBus.vo_line_started.connect(func(id: StringName, _sp: StringName, _tx: String, _d: float) -> void: _said.append(String(id)))
	print("[paths] user settings: bots %s, skill %s, local AI %s" % [str(GLSettings.values.get("bots")), str(GLSettings.values.get("bot_skill")), str(GLSettings.values.get("bot_local_ai"))])
	GLSettings.values["bot_local_ai"] = false   # no Ollama in a smoke
	# this node outlives every scene change: it is not the current scene
	(func() -> void:
		get_tree().current_scene = null
		_next()).call_deferred()


func _next() -> void:
	_i += 1
	if _i >= _cases.size():
		_end()
		return
	_t = 0.0
	_st = {"case": _cases[_i], "seen_idle": false, "visible_before": 0, "running": false, "risen": 0, "phase_log": []}
	_map_seen = null
	print("[paths] ---- case %s" % _cases[_i])
	Net.leave("")
	GameState.god_mode = false
	match _cases[_i]:
		"launcher":
			_launcher(0, 1)
		"launcher_bots":
			_launcher(3, 1)
		"botmode":
			var dl: Node = _make_launcher(int(GLSettings.values.get("bots", 3)))
			# the "Bot mode — Map 0" button's own lines
			GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), (dl.get("_bots") as OptionButton).selected)
			dl.call("_start_tool_scene", "res://gravelight/tools_src/play_botmode.tscn")
		"hub":
			_hub(false)
		"campaign":
			_hub(true)
		"restart":
			_launcher(int(GLSettings.values.get("bots", 3)), 1)
			_st["restart_pending"] = true
		"coop_host":
			var port: int = 25000 + randi() % 3000
			if Net.host_game(port, "127.0.0.1") != OK:
				_fail("coop_host: could not host")
				_next.call_deferred()
				return
			Net.start_match(MAP)


## The dev launcher scene, as Play.bat opens it, with its bot field set.
func _make_launcher(bots: int) -> Node:
	var dl: Node = (load("res://ui/dev_launcher.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(dl)
	get_tree().current_scene = dl
	(dl.get("_bots") as OptionButton).select(clampi(bots, 0, 3))
	(dl.get("_god") as CheckBox).button_pressed = true   # god mode: the case watches, nothing kills the player
	var ai: CheckBox = dl.get("_ai") as CheckBox
	if ai != null:
		ai.button_pressed = false
	return dl


func _launcher(bots: int, start_round: int) -> void:
	var dl: Node = _make_launcher(bots)
	(dl.get("_round") as SpinBox).value = start_round
	dl.call("_start_gl", MAP, int((dl.get("_round") as SpinBox).value))   # the Map 0 button's own call


func _hub(campaign: bool) -> void:
	var mc: Control = MenuCharacter.new()
	get_tree().root.add_child(mc)
	get_tree().current_scene = mc
	GameState.god_mode = true
	mc.call("_start", MAP, campaign)


func _map() -> MapRoot:
	return get_tree().current_scene as MapRoot


func _physics_process(delta: float) -> void:
	if _i < 0 or _i >= _cases.size():
		return
	_t += delta
	var map: MapRoot = _map()
	if map == null or not map.is_inside_tree():
		if _t > CASE_TIMEOUT:
			_case_fail("the map never loaded")
		return
	if _map_seen != map:
		_map_seen = map
		_t = 0.0
		_st["seen_idle"] = false
		_st["visible_before"] = 0
		_st["running"] = false
		_st["risen"] = 0
		_st["in_view"] = -1
		_said.clear()
	GameState.god_mode = true
	var op: InnOpening = map.find_child("InnOpening", true, false) as InnOpening
	if op == null:
		_case_fail("no InnOpening on the map")
		return
	var ph: String = str(InnOpening.Phase.keys()[op.phase])
	var log_: Array = _st["phase_log"]
	if log_.is_empty() or log_.back() != ph:
		log_.append(ph)
		print("[paths] %s: %.1f s phase %s (round %d)" % [_st["case"], _t, ph, RoundManager.current_round])
	if op.phase == InnOpening.Phase.IDLE and RoundManager.current_round == 0 and _t > 1.0:
		_st["seen_idle"] = true
		var vis: int = 0
		for pb: PatronBody in op.patrons.values():
			if pb.visible and pb.is_inside_tree():
				vis += 1
		_st["visible_before"] = maxi(int(_st["visible_before"]), vis)
		if int(_st["in_view"]) < 0 and map.player != null and map.player.camera != null:
			_st["in_view"] = _in_view(map.player.camera, op)
	if op.phase == InnOpening.Phase.RUNNING and not bool(_st["running"]):
		_st["running"] = true
		_st["run_at"] = _t
		_st["said_before"] = _said.duplicate()
	_st["risen"] = maxi(int(_st["risen"]), op.risen.size())
	if op.phase == InnOpening.Phase.CANCELLED:
		_case_fail("the opening was cancelled (round %d, arriving %s)" % [RoundManager.current_round, str(op.get("_arriving"))])
		return
	if bool(_st["running"]) and int(_st["risen"]) >= 1:
		_case_pass(op)
		return
	if _t > CASE_TIMEOUT:
		_case_fail("timed out: phase %s, round %d, risen %d" % [ph, RoundManager.current_round, int(_st["risen"])])


func _case_pass(op: InnOpening) -> void:
	var c: String = _st["case"]
	if not bool(_st["seen_idle"]) or int(_st["visible_before"]) < op.patrons.size():
		_fail("%s: patrons visible before round 1: %d of %d" % [c, int(_st["visible_before"]), op.patrons.size()])
	var before: Array = _st.get("said_before", [])
	if not before.has("ROT_INN_ARRIVE_01") or not before.has("KUB_INN_WINDOW_01"):
		_fail("%s: before round 1 heard %s (want Rother's welcome and the cue)" % [c, str(before)])
	var mn: float = float((op.cfg.get("look", {}) as Dictionary).get("min_seconds", 0.0))
	if float(_st.get("run_at", 0.0)) < mn:
		_fail("%s: round 1 began %.1f s in, before the %.1f s look-around" % [c, float(_st.get("run_at", 0.0)), mn])
	if c.begins_with("launcher") or c == "hub" or c == "campaign" or c.begins_with("restart") or c == "coop_host":
		if int(_st["in_view"]) != op.patrons.size():
			_fail("%s: %d of %d patrons in the starting view" % [c, int(_st["in_view"]), op.patrons.size()])
	print("[paths] %s: round 1 at %.1f s, %d patrons in the starting view, before it: %s" % [c, float(_st.get("run_at", 0.0)), int(_st["in_view"]), str(before)])
	print("[paths] %s ok: %d patrons in the taproom before round 1, the opening ran, %d risen by %.1f s" % [c, int(_st["visible_before"]), int(_st["risen"]), _t])
	if _st.get("restart_pending", false):
		_st["restart_pending"] = false
		_st["case"] = "restart (reloaded)"
		_st["phase_log"] = []
		_map().call("_restart")
		return
	_next_case()


## Patrons within 56 deg of the camera's forward (the half-width of an 80 deg vertical FOV at 16:9) and in front.
static func _in_view(cam: Camera3D, op: InnOpening) -> int:
	var n: int = 0
	for pb: PatronBody in op.patrons.values():
		if InnOpening.facing(cam.global_position, -cam.global_basis.z, pb.global_position, 56.0):
			n += 1
	return n


func _case_fail(why: String) -> void:
	_fail("%s: %s" % [_st["case"], why])
	_next_case()


func _next_case() -> void:
	set_physics_process(false)
	(func() -> void:
		var cur: Node = get_tree().current_scene
		if cur != null:
			get_tree().current_scene = null
			cur.queue_free()
		RoundManager.stop()
		Net.leave("")
		await get_tree().process_frame
		await get_tree().process_frame
		set_physics_process(true)
		_next()).call_deferred()


func _fail(s: String) -> void:
	_fails.append(s)
	print("[paths] FAIL ", s)


func _end() -> void:
	if _fails.is_empty():
		print("[paths] RESULT PASS (%d cases)" % _cases.size())
	else:
		print("[paths] RESULT FAIL (%d): %s" % [_fails.size(), "; ".join(_fails)])
	set_physics_process(false)
	get_tree().quit(0 if _fails.is_empty() else 1)
