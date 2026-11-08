extends Node
## T-194 headless online smoke for the LAZARUS cutscenes: host-driven, the way the campaign hops are (ExfilCutscene).
## Runs as the HOST, starts a second headless Godot as the CLIENT (OS.create_process) on 127.0.0.1 (smoke_coop's way),
## both on Map 0. The host plays GRAVELIGHT ONE at the match start (LazarusCinema forced on the host only: the client
## plays it because the host says so). Then the co-op skip vote: the host holds first (1 of 2: nothing happens, the
## tally reaches the client), the client holds second; the host's copy ends and the client's follows; both peers'
## input comes back and round 1 starts on both.
## T-209 (UPDATE 12 s3): `--cut=<id>` plays another cut (default GRAVELIGHT ONE); smoke_cinema_reels_online.tscn runs it
## with the archive reel of STAUB ("reel:staub") with a clip for every shot (the fixture, in a user:// folder both peers
## read): both peers' copies run the film treatment and play the clips on their own clock, the vote and the host's end
## work as for an in-engine cut.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_cinema_online.tscn
## Prints "[cinema_online:<role>] ..." and "RESULT: PASS" / "RESULT: FAIL" (exit 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const HOST_TIMEOUT: float = 300.0
const CLIENT_TIMEOUT: float = 280.0

var _role: String = "host"
var _port: int = 0
var _child_pid: int = -1
var _t: float = 0.0
var _step: String = "lobby"
var _step_t: float = 0.0
var _fails: PackedStringArray = []
var _done: bool = false
var _client_result: Dictionary = {}
var _log_path: String = ""
var _cut: String = ""
var _reel_root: String = ""
var _film_seen: bool = false
var _played: Dictionary = {}


func _ready() -> void:
	if get_parent() != get_tree().root or name != "CinemaOnlineDriver":
		var d: Node = (get_script() as GDScript).new() as Node
		d.name = "CinemaOnlineDriver"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_physics_process(false)
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))
		elif a.begins_with("--cut="):
			_cut = a.get_slice("=", 1)
		elif a.begins_with("--reel-root="):
			_reel_root = a.get_slice("=", 1)
	if _cut == "":
		_cut = _default_cut()
	if _role == "host" and _wants_clips() and _reel_root == "":
		_reel_root = _make_clips(CinemaArchive.base_id(_cut))
	if _reel_root != "":
		CinemaArchive.root_override = _reel_root
	ProfileSave.path = "user://_qa_cinema_online_%s.json" % _role
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_cinema_online_%s.cfg" % _role
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	Campaign.cutscene_speed = 4.0
	_log_path = "user://_qa_cinema_online_%s.log" % _role
	var f: FileAccess = FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.close()
	if _role == "host":
		LazarusCinema.force = true
		LazarusCinema.force_ids = [_cut]
		_start_host()
	else:
		_start_client()


## T-209: what a scene variant overrides (smoke_cinema_reels_online.gd).
func _default_cut() -> String:
	return "gravelight_one"


func _scene_path() -> String:
	return "res://gravelight/tools_src/smoke_cinema_online.tscn"


func _wants_clips() -> bool:
	return false


## A clip for every reel shot of `scene` (the committed fixture) in a user:// folder both peers read.
func _make_clips(scene: String) -> String:
	var root: String = "user://_qa_reels_online"
	var dir: String = root.path_join(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for s: Variant in (CinemaArchive.scenes().get(scene, {}) as Dictionary).get("shots", []):
		var n: int = int((s as Dictionary)["n"])
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://gravelight/tests/fixtures/reel_test_shot.ogv"),
			ProjectSettings.globalize_path(dir.path_join(CinemaArchive.shot_name(n) + ".ogv")))
	return root


## The reel's film and clips as this peer saw them (checked when it ends).
func _watch_reel() -> void:
	var lc: LazarusCinema = _lc()
	if lc == null or lc.reel == null or lc.reel.director == null:
		return
	if lc.reel.director.film != null:
		_film_seen = true
	if lc.reel.director.video != null:
		for p: String in lc.reel.director.video.played:
			_played[p] = true


func _check_reel_seen(who: String) -> void:
	if not CinemaArchive.plays_as_reel(_cut):
		return
	_check(_film_seen, "%s: the reel ran its film treatment" % who)
	if _wants_clips():
		_check(not _played.is_empty(), "%s: the reel played its clips (%s)" % [who, str(_played.keys())])
	_log("%s: film %s, clips played %s" % [who, str(_film_seen), str(_played.keys())])


func _log(msg: String) -> void:
	var line: String = "[cinema_online:%s] %s" % [_role, msg]
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


func _lc() -> LazarusCinema:
	var map: MapRoot = get_tree().current_scene as MapRoot
	return LazarusCinema.of(map) if map != null else null


# ================================================================== host

func _start_host() -> void:
	if _port <= 0:
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.randomize()
		_port = r.randi_range(27100, 27900)
	GameState.character_id = &"dutch"
	if Net.host_game(_port, "127.0.0.1") != OK:
		_fail("couldn't host on 127.0.0.1:%d (%s)" % [_port, Net.last_error])
		_finish()
		return
	var args: PackedStringArray = ["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"),
		_scene_path(), "--", "--role=client", "--port=%d" % _port, "--cut=" + _cut, "--reel-root=" + _reel_root]
	_child_pid = OS.create_process(OS.get_executable_path(), args)
	if _child_pid <= 0:
		_fail("couldn't start the client process")
		_finish()
		return
	_log("hosting on 127.0.0.1:%d, client process %d" % [_port, _child_pid])


func _host_tick() -> void:
	match _step:
		"lobby":
			if Net.roster.size() >= 2 and Net.all_ready():
				Net.start_match(MAP)
				_goto("playing")
			elif _step_t > 60.0:
				_fail("the client never joined")
				_finish()
		"playing":
			var lc: LazarusCinema = _lc()
			if lc != null and lc.reel != null and lc.reel.director != null and _step_t > 0.0:
				_log("the host plays %s" % str(lc.playing))
				_goto("vote")
			elif _step_t > 120.0:
				_fail("the host never played %s" % _cut)
				_finish()
		"vote":
			var lc2: LazarusCinema = _lc()
			if _step_t > 2.0 and lc2.skip_votes.is_empty():
				lc2.request_skip_local()   # the host holds [interact]: 1 of 2
				_check(lc2.reel != null and not lc2.reel.done, "one vote of two must not skip")
				_qa_send("host_voted", {})
				_goto("wait_end")
		"wait_end":
			var lc3: LazarusCinema = _lc()
			if lc3.reel == null:
				_log("the host's reel ended (%s) at %.1f s into the wait" % [str(lc3.history), _step_t])
				_check(lc3.history.has(CinemaArchive.base_id(_cut)), "the host's history")
				_check_reel_seen("the host")
				_check(not GameState.input_blocked, "the host's input is back")
				_goto("round1")
			elif _step_t > 60.0:
				_fail("the vote never ended the host's reel")
				_finish()
		"round1":
			if RoundManager.current_round >= 1:
				_log("round 1 on the host")
				_goto("wait_result")
			elif _step_t > 90.0:
				_fail("round 1 never started on the host")
				_goto("wait_result")
		"wait_result":
			if not _client_result.is_empty():
				if not bool(_client_result.get("pass", false)):
					for cf: Variant in _client_result.get("fails", ["client failed"]):
						_fails.append("client: " + str(cf))
				_finish()
			elif _step_t > 60.0:
				_fail("no result from the client")
				_finish()


func _check(c: bool, what: String) -> void:
	if not c:
		_fail(what)


# ================================================================== client

func _start_client() -> void:
	GameState.character_id = &"peg"
	Net.joined.connect(func() -> void: Net.set_ready(true))
	Net.join_failed.connect(func(reason: String) -> void:
		_fail("join failed: " + reason)
		_finish())
	if Net.join_game("127.0.0.1", _port) != OK:
		_fail("couldn't connect: " + Net.last_error)
		_finish()


var _host_voted: bool = false
var _saw_reel: bool = false
var _saw_tally: bool = false


func _client_tick() -> void:
	var lc: LazarusCinema = _lc()
	match _step:
		"lobby":
			if lc != null and lc.reel != null:
				_saw_reel = true
				_check(lc.playing == [_cut], "the client plays what the host said (%s)" % str(lc.playing))
				_check(GameState.input_blocked, "the client's input is blocked during the cutscene")
				_log("the client plays %s (the host's call)" % str(lc.playing))
				_goto("wait_vote")
			elif _step_t > 150.0:
				_fail("the client never played the host's cutscene")
				_client_finish()
		"wait_vote":
			if _host_voted and lc.skip_votes.size() == 1 and not _saw_tally:
				_saw_tally = true
				_log("the tally reached the client (1 of 2); voting")
				lc.request_skip_local()
				_goto("wait_end")
			elif _step_t > 90.0:
				_fail("the host's vote never reached the client")
				_client_finish()
		"wait_end":
			if lc.reel == null:
				_check(lc.history.has(CinemaArchive.base_id(_cut)), "the client's reel ended on the host's end")
				_check_reel_seen("the client")
				_check(not GameState.input_blocked, "the client's input is back")
				_log("the client's reel ended with the host's")
				_goto("round1")
			elif _step_t > 30.0:
				_fail("the client's reel did not end with the host's")
				_client_finish()
		"round1":
			if RoundManager.current_round >= 1:
				_log("round 1 on the client")
				_client_finish()
			elif _step_t > 90.0:
				_fail("round 1 never reached the client")
				_client_finish()


func _client_finish() -> void:
	if _done:
		return
	_done = true
	_qa_send("result", {"pass": _fails.is_empty(), "fails": Array(_fails)})
	_log("RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		Net.leave("")
		get_tree().quit(0 if _fails.is_empty() else 1))


# ================================================================== shared

func _qa_send(what: String, data: Dictionary) -> void:
	if Net.is_online():
		rpc("_qa", what, data)


@rpc("any_peer", "call_remote", "reliable")
func _qa(what: String, data: Dictionary) -> void:
	if _role == "host" and what == "result":
		_client_result = data
	elif _role == "client" and what == "host_voted":
		_host_voted = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_step_t += delta
	_watch_reel()
	if _role == "host":
		if _t > HOST_TIMEOUT:
			_fail("host timeout in '%s'" % _step)
			_finish()
			return
		_host_tick()
	else:
		if _t > CLIENT_TIMEOUT:
			_fail("client timeout in '%s'" % _step)
			_client_finish()
			return
		_client_tick()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _role != "host":
		_client_finish()
		return
	if _child_pid > 0 and OS.is_process_running(_child_pid):
		OS.kill(_child_pid)
	var ok: bool = _fails.is_empty()
	if not ok:
		var f: FileAccess = FileAccess.open("user://_qa_cinema_online_client.log", FileAccess.READ)
		if f != null:
			print(f.get_as_text())
			f.close()
	print("[cinema_online] RESULT: %s" % ("PASS" if ok else "FAIL"))
	LazarusCinema.force = false
	Net.leave("")
	get_tree().quit(0 if ok else 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _role == "host" and _child_pid > 0 and OS.is_process_running(_child_pid):
		OS.kill(_child_pid)
