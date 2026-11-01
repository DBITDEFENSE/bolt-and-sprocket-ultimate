extends Node
## Headless online smoke (UPDATE 09 section 2e, T-138): two desktop instances play co-op over WebRTC through a
## lobby, with the mock lobby service and the mock signaling relay standing in for Supabase (no internet).
##   host    starts the MockSignalServer (lobby table + signaling relay) on 127.0.0.1:<port>, creates a public
##           lobby (map00, 3 slots, bots fill empty slots) and starts the client process
##   client  browses (the lobby must be listed), joins by code, picks a free survivor (asking for the host's one
##           first: refused), readies up
##   both    load map00 over WebRTC; 2 rounds pass (round 3 starts) with 1 bot (pid 3) that the client sees as a
##           moving puppet with its own gun
##   drop    the client's connection dies (Net.leave): the host turns its slot into a bot; the client rejoins
##           within the grace (same session token) and gets pid 2 and its body back
##   leave   the host leaves: the client gets "The host left the match." and is back at the menu
## The host prints one RESULT line (PASS only when both sides passed); the client writes its result to a file the
## host reads (the network is gone by then). Silent: headless, dummy audio, loopback only.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_webrtc.tscn

const MAP_ID: String = "map00_crossroads"
const HOST_TIMEOUT: float = 330.0
const CLIENT_TIMEOUT: float = 310.0
const RESULT_FILE: String = "user://_qa_webrtc_client_result.json"

var _role: String = "host"
var _port: int = 0
var _code: String = ""
var _child_pid: int = -1
var _t: float = 0.0
var _step: String = "start"
var _step_t: float = 0.0
var _fails: PackedStringArray = []
var _notes: PackedStringArray = []
var _done: bool = false
var _log_path: String = ""
var _client_result: Dictionary = {}
var _host_left_msg: String = ""
var _drop_seen: bool = false
var _rejoin_seen: bool = false
var _p2_pos: Vector3 = Vector3.ZERO
var _bot_moved: float = 0.0
var _bot_last: Vector3 = Vector3.INF
var _bot_gun: String = ""
var _old_map: Node = null
var _jakub_ok: bool = false
var _bank_t: float = -1.0
var _bank_ok: bool = false
var _bank_scrip0: int = 0


func _ready() -> void:
	if get_parent() != get_tree().root or name != "WebrtcSmoke":
		var d: Node = (load("res://gravelight/tools_src/smoke_webrtc.gd") as GDScript).new() as Node
		d.name = "WebrtcSmoke"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_physics_process(false)
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))
		elif a.begins_with("--code="):
			_code = a.get_slice("=", 1)
	ProfileSave.path = "user://_qa_webrtc_%s.json" % _role
	ProfileSave.profile = ProfileSave.new_profile()
	_log_path = "user://_qa_webrtc_%s.log" % _role
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.close()
	if not RtcTransport.available():
		_fail("WebRTC is not available in this build (addons/webrtc not loaded)")
		_finish()
		return
	if _role == "host":
		_start_host()
	else:
		_start_client()


func _log(msg: String) -> void:
	var line: String = "[webrtc:%s %.1fs] %s" % [_role, _t, msg]
	print(line)
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()


func _fail(msg: String) -> void:
	_fails.append(msg)
	_log("FAIL: " + msg)


func _goto(step: String) -> void:
	_log("step -> " + step)
	_step = step
	_step_t = 0.0


# ================================================================== host

func _start_host() -> void:
	if _port <= 0:
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.randomize()
		_port = r.randi_range(28100, 28900)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_FILE))
	if Lobbies.use_mock(_port, true) != OK:
		_fail("couldn't start the mock signal server on %d" % _port)
		_finish()
		return
	GameState.character_id = &"dutch"
	Lobbies.joined.connect(func(lobby: Dictionary) -> void:
		_code = str(lobby.get("code", ""))
		_log("lobby %s open (transport %s)" % [_code, "WebRTC" if Net.is_webrtc() else "ENet"])
		_spawn_client())
	Lobbies.failed.connect(func(reason: String) -> void:
		_fail("host lobby failed: " + reason)
		_finish())
	Net.player_dropped.connect(func(pid: int, as_bot: bool) -> void:
		_log("player %d dropped (bot: %s)" % [pid, str(as_bot)])
		_drop_seen = pid == 2 and as_bot)
	Net.player_rejoined.connect(func(pid: int) -> void:
		_log("player %d rejoined" % pid)
		_rejoin_seen = pid == 2)
	Lobbies.create(MAP_ID, true, "Hosty", 3, true)
	_goto("lobby")


func _spawn_client() -> void:
	var args: PackedStringArray = ["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"),
		"res://gravelight/tools_src/smoke_webrtc.tscn", "--", "--role=client", "--port=%d" % _port, "--code=%s" % _code.to_lower()]
	_child_pid = OS.create_process(OS.get_executable_path(), args)
	if _child_pid <= 0:
		_fail("couldn't start the client process")
		_finish()
		return
	_log("client process %d" % _child_pid)


func _host_tick(delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	match _step:
		"lobby":
			if Net.human_pids().size() >= 2 and Net.all_ready():
				if Net.character_of(2) == Net.character_of(1):
					_fail("duplicate survivors in the roster")
				_log("client is %s (%s); starting" % [Net.player_name(2), Net.display_name(2)])
				if not Lobbies.start():
					_fail("Lobbies.start() refused")
					_finish()
					return
				_goto("loading")
			elif _step_t > 90.0:
				_fail("the client never joined/readied (roster %s)" % str(Net.roster.keys()))
				_finish()
		"loading":
			if map != null and map.session != null and map.session.begun:
				GameState.god_mode = true
				if GameState.bot_ids.size() != 1 or GameState.bot_ids[0] != 3:
					_fail("expected one bot as pid 3, got %s" % str(GameState.bot_ids))
				var bot: Player = map.players.get(3) as Player
				if bot == null or not bot.is_bot:
					_fail("pid 3 isn't a bot on the host")
				if map.squad == null or map.squad.brains.is_empty():
					_fail("no BotSquad brains on the host")
				_goto("rounds")
			elif _step_t > 90.0:
				_fail("the match never began on the host")
				_finish()
		"rounds":
			for z: Zombie in map.director.active_zombies():
				z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
			if RoundManager.current_round >= 3:
				_log("round %d reached (2 rounds played)" % RoundManager.current_round)
				_p2_pos = (map.players[2] as Player).global_position
				_qa_send("drop", {})
				_goto("wait_drop")
			elif _step_t > 120.0:
				_fail("2 rounds never passed (round %d)" % RoundManager.current_round)
				_goto("leave")
		"wait_drop":
			if _drop_seen:
				var p2: Player = map.players.get(2) as Player
				if p2 == null or not p2.is_bot:
					_fail("the dropped player's body didn't become a bot")
				_goto("wait_rejoin")
			elif _step_t > 30.0:
				_fail("the host never saw the client drop")
				_goto("leave")
		"wait_rejoin":
			if _rejoin_seen and map.session != null and map.session._loaded.has(2):
				var p2b: Player = map.players.get(2) as Player
				if p2b == null or p2b.is_bot:
					_fail("the rejoined player is still a bot on the host")
				if Net.peer_of(2) <= 1:
					_fail("pid 2 has no peer after the rejoin")
				_notes.append("rejoin took %.1f s" % _step_t)
				_goto("settle")
			elif _step_t > 60.0:
				_fail("the client never rejoined within the grace")
				_goto("leave")
		"settle":
			if _step_t > 4.0:
				_qa_send("host_leaving", {})
				_goto("leave")
		"leave":
			if _step_t > 1.0:
				_log("host leaves the lobby")
				Lobbies.leave()
				_goto("wait_result")
		"wait_result":
			if FileAccess.file_exists(RESULT_FILE):
				var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESULT_FILE))
				_client_result = v as Dictionary if v is Dictionary else {"pass": false, "fails": ["unreadable result"]}
				_host_report()
			elif _step_t > 40.0 or (_child_pid > 0 and not OS.is_process_running(_child_pid) and _step_t > 3.0):
				_fail("no result from the client")
				_finish()


func _host_report() -> void:
	for f: Variant in _client_result.get("fails", []):
		_fails.append("client: " + str(f))
	for n: Variant in _client_result.get("notes", []):
		_log("client: " + str(n))
	if not bool(_client_result.get("pass", false)) and (_client_result.get("fails", []) as Array).is_empty():
		_fails.append("client reported FAIL")
	_finish()


# ================================================================== client

func _start_client() -> void:
	GameState.character_id = &"dutch"   # the host's survivor: the roster must hand us another one
	Lobbies.use_mock(_port, false)
	Lobbies.set_display_name("Clienta")
	Lobbies.lobbies_changed.connect(func(list: Array) -> void:
		if _step == "browse":
			for r: Variant in list:
				if str((r as Dictionary).get("code", "")) == LobbyService.normalize_code(_code):
					_notes.append("the lobby is listed in Browse")
					_goto("join"))
	Lobbies.joined.connect(func(_lobby: Dictionary) -> void:
		_log("joined as player %d (%s)" % [Net.local_player_id(), Net.display_name(Net.local_player_id())]))
	Lobbies.failed.connect(func(reason: String) -> void:
		_fail("lobby failed in '%s': %s" % [_step, reason])
		_client_finish())
	Net.host_left.connect(func(reason: String) -> void: _host_left_msg = reason)
	Lobbies.left.connect(func(reason: String) -> void:
		if reason == Net.HOST_LEFT:
			_host_left_msg = reason)
	_goto("browse")
	Lobbies.start_browsing()


func _client_tick(delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	match _step:
		"browse":
			if _step_t > 20.0:
				_fail("lobby %s never showed up in Browse" % _code)
				_goto("join")
		"join":
			Lobbies.stop_browsing()
			Lobbies.join(_code)   # typed in lower case: normalised to the 6-letter code
			_goto("wait_joined")
		"wait_joined":
			if Lobbies.state == LobbyService.State.IN_LOBBY and Net.local_player_id() == 2:
				if Net.character_of(2) == &"dutch":
					_fail("got the host's survivor")
				Lobbies.set_character("dutch")   # taken: must be refused
				_goto("pick")
			elif _step_t > 30.0:
				_fail("never got into the lobby")
				_client_finish()
		"pick":
			if _step_t > 1.0:
				if Net.character_of(2) == &"dutch":
					_fail("the host's survivor was handed out twice")
				Lobbies.set_character("wren")
				_goto("ready")
		"ready":
			if _step_t > 1.0:
				if Net.character_of(2) != &"wren":
					_fail("couldn't pick a free survivor (have %s)" % Net.character_of(2))
				Lobbies.set_ready(true)
				_goto("wait_match")
		"wait_match":
			if map != null and map.session != null and map.session.begun and map.player != null:
				GameState.god_mode = true
				_notes.append("in the match over %s after %.1f s" % ["WebRTC" if Net.is_webrtc() else "ENet", _t])
				_goto("play")
			elif _step_t > 120.0:
				_fail("never got into the match")
				_client_finish()
		"play":
			# the bot (pid 3) is a puppet here, moving with its own gun
			var bot: Player = map.players.get(3) as Player if map != null else null
			if bot != null:
				if bot.is_bot:
					_fail("the bot is simulated on the client")
				if _bot_last != Vector3.INF:
					_bot_moved += bot.global_position.distance_to(_bot_last)
				_bot_last = bot.global_position
				var w: WeaponInstance = bot.weapons.current() if bot.weapons != null else null
				if w != null:
					_bot_gun = String(w.id)
			# Jakub (host-only, T-138): a puppet here, fed by the host's player stream
			var jak: Player = map.get_node_or_null("Jakub") as Player if map != null else null
			if jak != null and not _jakub_ok:
				if jak.is_bot:
					_fail("Jakub is simulated on the client")
					_jakub_ok = true
				elif jak.interp != null and not jak.interp.is_empty():
					_jakub_ok = true
					_notes.append("Jakub is a host-fed puppet on the client")
			# the bank online (T-138): a deposit moves our Scrip on the host and lands in our own profile
			if _step_t > 3.0 and _bank_t < 0.0 and Economy.get_scrip(2) >= 100:
				_bank_scrip0 = Economy.get_scrip(2)
				_bank_t = _step_t
				if BankAccount.deposit(2, 100) != 100:
					_fail("the bank refused a client deposit online")
			elif _bank_t > 0.0 and not _bank_ok and BankAccount.balance() >= 100 and Economy.get_scrip(2) <= _bank_scrip0 - 100:
				_bank_ok = true
				_notes.append("bank deposit round-trip %.2f s (balance %d)" % [_step_t - _bank_t, BankAccount.balance()])
			if _step_t > 200.0:
				_fail("the host never asked us to drop")
				_client_finish()
		"dropped":
			if _step_t > 1.0:
				if not Lobbies.can_rejoin():
					_fail("no rejoin offered after the drop")
					_client_finish()
					return
				_log("rejoining (%.0f s left)" % Lobbies.rejoin_seconds_left())
				Lobbies.rejoin()
				_goto("rejoin_wait")
		"rejoin_wait":
			if map != null and map != _old_map and Net.is_online() and Net.in_match and map.session != null and map.session.begun and map.player != null and not Net.rejoining:
				if Net.local_player_id() != 2:
					_fail("rejoined as pid %d, not 2" % Net.local_player_id())
				if Net.character_of(2) != &"wren":
					_fail("rejoined as %s, not wren" % Net.character_of(2))
				_notes.append("rejoined as pid %d after %.1f s" % [Net.local_player_id(), _step_t])
				_goto("after_rejoin")
			elif _step_t > 60.0:
				_fail("the rejoin never completed")
				_client_finish()
		"after_rejoin":
			if _host_left_msg != "":
				_goto("host_left")
			elif _step_t > 60.0:
				_fail("the host never left")
				_client_finish()
		"host_left":
			if _host_left_msg != Net.HOST_LEFT:
				_fail("host-left message was '%s'" % _host_left_msg)
			else:
				_notes.append("saw '%s'" % _host_left_msg)
			if Net.is_online():
				_fail("still online after the host left")
			_client_finish()


func _client_finish() -> void:
	if _done:
		return
	_done = true
	if _bot_moved < 0.5:
		_fails.append("the bot puppet never moved on the client (%.2f m)" % _bot_moved)
	if _bot_gun == "":
		_fails.append("the bot puppet never got its gun")
	else:
		_notes.append("bot puppet moved %.1f m, gun %s" % [_bot_moved, _bot_gun])
	if not _jakub_ok:
		_fails.append("never saw Jakub as a host-fed puppet")
	if not _bank_ok:
		_fails.append("the client's bank deposit never round-tripped (balance %d)" % BankAccount.balance())
	var res: Dictionary = {"pass": _fails.is_empty(), "fails": Array(_fails), "notes": Array(_notes)}
	var f: FileAccess = FileAccess.open(RESULT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(res))
		f.close()
	_log("RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	if Net.is_online():
		Net.leave("")
	get_tree().create_timer(0.5).timeout.connect(func() -> void: get_tree().quit(0 if _fails.is_empty() else 1))


# ================================================================== shared

func _qa_send(what: String, data: Dictionary) -> void:
	if Net.is_online():
		rpc("_qa", what, data)


@rpc("any_peer", "call_remote", "reliable")
func _qa(what: String, _data: Dictionary) -> void:
	_log("got '%s'" % what)
	if _role == "client":
		match what:
			"drop":
				_log("dropping the connection (simulated)")
				_old_map = get_tree().current_scene
				Net.leave.call_deferred("")   # as if the link died: LobbyService keeps the session for a rejoin
				_goto("dropped")
			"host_leaving":
				pass


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_step_t += delta
	if _role == "host":
		if _t > HOST_TIMEOUT:
			_fail("host timeout in step '%s'" % _step)
			_finish()
			return
		_host_tick(delta)
		if _child_pid > 0 and _t > 5.0 and not OS.is_process_running(_child_pid) and _step != "wait_result" and _step != "leave":
			_fail("the client process exited early (step '%s')" % _step)
			_finish()
	else:
		if _t > CLIENT_TIMEOUT:
			_fail("client timeout in step '%s'" % _step)
			_client_finish()
			return
		_client_tick(delta)


func _finish() -> void:
	if _done:
		return
	if _role != "host":
		_client_finish()
		return
	_done = true
	_kill_child()
	var ok: bool = _fails.is_empty()
	if not ok:
		var f: FileAccess = FileAccess.open("user://_qa_webrtc_client.log", FileAccess.READ)
		if f != null:
			print("[webrtc] --- client log ---")
			print(f.get_as_text())
			f.close()
	for n: String in _notes:
		print("[webrtc] " + n)
	for f2: String in _fails:
		print("[webrtc] FAIL: " + f2)
	print("[webrtc] RESULT: %s" % ("PASS" if ok else "FAIL"))
	if Net.is_online():
		Net.leave("")
	get_tree().quit(0 if ok else 1)


func _kill_child() -> void:
	if _child_pid > 0 and OS.is_process_running(_child_pid):
		OS.kill(_child_pid)
	_child_pid = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _role == "host":
			_kill_child()
