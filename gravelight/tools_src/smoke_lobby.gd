extends Node
## Headless lobby smoke (UPDATE 09 section 2e, T-138): the LobbyService state machine on the mock backend (the
## MockSignalServer's lobby table + relay, in this process; no internet, no second instance; the full two-player
## flow over WebRTC is smoke_webrtc). Steps:
##   create      a public 2-slot lobby: the row is stored, the WebRTC host is up, the code is 6 letters
##   browse      the lobby shows up in the Browse list
##   join        a second player joins by code (through the table): the row lists 2; the host's heartbeat
##               rewrites the list from its own roster
##   full        a 2-slot lobby with 2 players refuses a third
##   start       ready check passes (host alone), start(): match_starting, the row says "playing", a join by
##               code is refused ("already started"), leave() closes the row
##   bad code    "abc" -> "A join code is 6 letters."
##   timeout     joining a lobby whose host never answers fails after connect_timeout_s with a clear message and
##               the service is back to IDLE
##   expiry      120 s without a heartbeat: gone from Browse, join by code says "No lobby with that code"
##   quick       Quick Match with nothing open creates a public lobby; with one open lobby it joins that one
##   rejoin      a dropped session can rejoin for rejoin_grace_s (60 s), not after
## Prints one RESULT line. Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_lobby.tscn

const TIMEOUT_S: float = 200.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _starting: Array = []
var _failed: Array = []
var _joined: Array = []
var _lists: int = 0


func _ready() -> void:
	if get_parent() != get_tree().root or name != "LobbySmoke":
		var d: Node = (load("res://gravelight/tools_src/smoke_lobby.gd") as GDScript).new() as Node
		d.name = "LobbySmoke"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		return
	ProfileSave.path = "user://_qa_lobby.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT_S:
		_fail("timed out")
		_finish()


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[lobby] FAIL: " + msg)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _wait(cond: Callable, seconds: float) -> bool:
	var left: float = seconds
	while not cond.call():
		if left <= 0.0:
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	if not RtcTransport.available():
		_fail("WebRTC isn't available (addons/webrtc)")
		_finish()
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var port: int = rng.randi_range(29100, 29900)
	_check(Lobbies.use_mock(port, true) == OK, "mock server on %d" % port)
	var table: MockLobbyBackend = Lobbies.mock_server.backend
	Lobbies.match_starting.connect(func(scene: String, _s: int) -> void: _starting.append(scene))
	Lobbies.failed.connect(func(reason: String) -> void: _failed.append(reason))
	Lobbies.joined.connect(func(l: Dictionary) -> void: _joined.append(l))
	Lobbies.lobbies_changed.connect(func(_l: Array) -> void: _lists += 1)
	Lobbies.set_display_name("Hosty")
	GameState.character_id = &"dutch"

	# ---- create
	print("[lobby] create")
	var code0: String = Lobbies.create("map00_crossroads", true, "", 2, false)
	_check(LobbyService.is_valid_code(code0), "create returned '%s'" % code0)
	_check(await _wait(func() -> bool: return not _joined.is_empty(), 10.0), "never joined our own lobby")
	var code: String = str(Lobbies.current.get("code", ""))
	_check(Lobbies.state == LobbyService.State.IN_LOBBY and Lobbies.is_host, "host state after create (%d)" % Lobbies.state)
	_check(Net.is_host() and Net.is_webrtc(), "Net is a WebRTC host")
	_check(table.rows.has(code), "the row is stored")

	# ---- browse
	print("[lobby] browse")
	var n0: int = _lists
	Lobbies.refresh()
	_check(await _wait(func() -> bool: return _lists > n0, 5.0), "Browse never refreshed")
	var listed: bool = false
	for r: Variant in Lobbies.lobbies:
		listed = listed or str((r as Dictionary).get("code", "")) == code
	_check(listed, "our lobby isn't in Browse")

	# ---- join by code (a second player, through the table), then the host's heartbeat owns the list
	print("[lobby] join by code")
	var j: Dictionary = table.join(code.to_lower(), {"name": "Clienta", "character": "peg"}, Lobbies.mock_server.now())
	_check(bool(j["ok"]), "join by code: %s" % str(j["error"]))
	_check(((table.rows[code] as Dictionary)["players"] as Array).size() == 2, "the row lists the joiner")
	Lobbies.heartbeat()
	await _sleep(0.3)
	_check(((table.rows[code] as Dictionary)["players"] as Array).size() == 1, "the heartbeat rewrites the list from the roster")

	# ---- full
	print("[lobby] full")
	table.create({"code": "FULLAA", "map_id": "map00_crossroads", "host_name": "Other", "max_players": 2,
		"players": [{"name": "a"}, {"name": "b"}]}, "f".repeat(32), Lobbies.mock_server.now())
	_check(str(table.join("FULLAA", {"name": "c"}, Lobbies.mock_server.now())["error"]) == MockLobbyBackend.ERR_FULL, "a full lobby takes a third")
	table.close_lobby("FULLAA", "f".repeat(32))

	# ---- start (ready check: the host alone is ready), row says playing, joins refused, leave closes the row
	print("[lobby] start")
	_check(Net.all_ready(), "a lone host is ready")
	_check(Lobbies.start(), "start() refused")
	_check(await _wait(func() -> bool: return not _starting.is_empty(), 5.0), "no match_starting")
	_check(Lobbies.state == LobbyService.State.IN_MATCH, "state after start (%d)" % Lobbies.state)
	await _sleep(0.3)
	_check(str((table.rows.get(code, {}) as Dictionary).get("status", "")) == "playing", "the row doesn't say playing")
	_check(str(table.join(code, {"name": "late"}, Lobbies.mock_server.now())["error"]) == MockLobbyBackend.ERR_CLOSED, "a started match took a joiner")
	await _wait(func() -> bool: return get_tree().current_scene is MapRoot, 30.0)
	Lobbies.leave()
	await _sleep(0.3)
	_check(not table.rows.has(code), "leave() didn't close the row")
	_check(Lobbies.state == LobbyService.State.IDLE and not Net.is_online(), "not idle after leave")
	var empty: PackedScene = PackedScene.new()   # off the map (the driver lives on the root)
	var blank: Node = Node.new()
	empty.pack(blank)
	blank.free()
	get_tree().change_scene_to_packed(empty)
	await _sleep(0.5)

	# ---- bad code
	print("[lobby] bad code")
	_failed.clear()
	Lobbies.join("abc")
	_check(await _wait(func() -> bool: return not _failed.is_empty(), 2.0) and str(_failed[0]).contains("6 letters"), "bad code message: %s" % str(_failed))

	# ---- timeout: a lobby whose host never answers
	print("[lobby] connect timeout (%d s)" % int(Lobbies.cfg().get("connect_timeout_s", 15)))
	table.create({"code": "GHOSTA", "map_id": "map00_crossroads", "host_name": "Ghost"}, "g".repeat(32), Lobbies.mock_server.now())
	_failed.clear()
	Lobbies.join("ghosta")
	_check(Lobbies.state == LobbyService.State.JOINING, "not joining")
	var waited: bool = await _wait(func() -> bool: return not _failed.is_empty(), float(Lobbies.cfg().get("connect_timeout_s", 15)) + 5.0)
	_check(waited and str(_failed[0]).contains("timed out"), "no timeout message: %s" % str(_failed))
	_check(Lobbies.state == LobbyService.State.IDLE and not Net.is_online(), "not back to idle after the timeout")

	# ---- expiry (the ghost lobby never heartbeats)
	print("[lobby] expiry")
	Lobbies.mock_server.time_offset = 125.0
	var n1: int = _lists
	Lobbies.refresh()
	await _wait(func() -> bool: return _lists > n1, 5.0)
	var ghost: bool = false
	for r2: Variant in Lobbies.lobbies:
		ghost = ghost or str((r2 as Dictionary).get("code", "")) == "GHOSTA"
	_check(not ghost, "an expired lobby is still listed")
	_failed.clear()
	Lobbies.join("GHOSTA")
	_check(await _wait(func() -> bool: return not _failed.is_empty(), 5.0) and str(_failed[0]).contains("No lobby"), "expired join: %s" % str(_failed))
	Lobbies.mock_server.time_offset = 0.0

	# ---- quick match: nothing open -> create; one open -> join it
	print("[lobby] quick match")
	_joined.clear()
	Lobbies.quick_match("map01_kaltenbrunn")
	_check(await _wait(func() -> bool: return not _joined.is_empty(), 10.0), "quick match with nothing open didn't create")
	_check(Lobbies.is_host and str(Lobbies.current.get("map_id", "")) == "map01_kaltenbrunn" and bool(Lobbies.current.get("is_public", false)),
		"quick match created %s" % str(Lobbies.current))
	Lobbies.leave()
	table.create({"code": "OPENAA", "map_id": "map00_crossroads", "host_name": "Open", "max_players": 4,
		"players": [{"name": "a"}]}, "o".repeat(32), Lobbies.mock_server.now())
	Lobbies.quick_match("map00_crossroads")
	_check(await _wait(func() -> bool: return str(Lobbies.current.get("code", "")) == "OPENAA", 5.0),
		"quick match joined '%s', not OPENAA" % str(Lobbies.current.get("code", "")))
	_check(Lobbies.state == LobbyService.State.JOINING, "quick match isn't connecting (%d)" % Lobbies.state)
	Lobbies.leave()

	# ---- the rejoin window
	print("[lobby] rejoin window")
	var now: float = Time.get_unix_time_from_system()
	Lobbies._save_session("OPENAA", "t".repeat(32), now - 10.0)
	_check(Lobbies.can_rejoin() and Lobbies.rejoin_seconds_left() > 45.0, "a 10 s old drop can rejoin")
	Lobbies._save_session("OPENAA", "t".repeat(32), now - 61.0)
	_check(not Lobbies.can_rejoin(), "a 61 s old drop can still rejoin")
	Lobbies._save_session("OPENAA", "t".repeat(32), 0.0)
	_check(not Lobbies.can_rejoin(), "a live session isn't a rejoin")
	Lobbies._clear_session()
	_finish()


func _finish() -> void:
	set_process(false)
	if Net.is_online():
		Net.leave("")
	print("[lobby] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
