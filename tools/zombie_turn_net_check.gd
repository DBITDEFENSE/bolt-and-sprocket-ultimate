extends Node
## Co-op check of the recorded stationary turn over real snapshot traffic. Runs as the HOST, starts a second headless
## Godot as the CLIENT (OS.create_process) on 127.0.0.1, both load Map 0. The host stops the rounds, stands one
## Ganger still in CHASE near its player and faces it to a list of headings through the real Zombie._face(); the
## client watches its puppet of that zombie through the real NetMatch snapshots and InterpBuffer and counts
##   - recorded turns its copy played (tree state "Turn"),
##   - ticks on which the OLD trigger would have fired (one tick's observed yaw change of 25 degrees or more: the
##     host-side request() the puppet used before, which sees only per-tick increments),
##   - the largest visual heading step in one tick, and whether the visual settles on the body's heading.
## PASS: the client's copy turns once for every turn the host's zombie played and never for the small / large ones.
## Usage: godot --headless --audio-driver Dummy --path . res://tools/zombie_turn_net_check.tscn [-- --out=res://.mocap_work/zombies/turn_net]
## Silent and firewall-free: headless, dummy audio, 127.0.0.1 only. The child is killed on every exit path.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 200.0
## Headings asked of the zombie, degrees relative to the one before, and whether a recorded turn is expected.
const TURNS: Array = [[45.0, true], [-45.0, true], [35.0, true], [-60.0, true], [60.0, true], [-35.0, true], [15.0, false], [120.0, false]]
const TURN_GAP_S: float = 3.0

var _role: String = "host"
var _port: int = 0
var _out: String = "res://.mocap_work/zombies/turn_net"
var _child_pid: int = -1
var _t: float = 0.0
var _step: String = "lobby"
var _step_t: float = 0.0
var _fails: PackedStringArray = []
var _done: bool = false
var _z: Zombie = null
var _yaw: float = 0.0
var _turn_i: int = -1
var _host_turns: int = 0
var _host_was_turn: bool = false
var _client_result: Dictionary = {}
# client
var _pz: Zombie = null
var _was_turn: bool = false
var _entered: int = 0
var _legacy_hits: int = 0
var _last_body: float = 0.0
var _last_visual: float = 0.0
var _max_step: float = 0.0
var _max_step_in_range: float = 0.0
var _in_range: bool = true
var _max_body_step: float = 0.0
var _ticks: int = 0
var _watch: bool = false
var _host_done: bool = false


func _ready() -> void:
	if get_parent() != get_tree().root or name != "ZombieTurnNet":
		var d: Node = (load("res://tools/zombie_turn_net_check.gd") as GDScript).new() as Node
		d.name = "ZombieTurnNet"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_physics_process(false)
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			_out = a.get_slice("=", 1)
	ProfileSave.path = "user://_qa_turn_net_%s.json" % _role
	ProfileSave.profile = ProfileSave.new_profile()
	if _role == "host":
		_start_host()
	else:
		_start_client()


func _log(msg: String) -> void:
	print("[turn-net:%s] %s" % [_role, msg])


func _fail(msg: String) -> void:
	_fails.append(msg)
	_log("FAIL: " + msg)


func _goto(step: String) -> void:
	_log("step -> " + step)
	_step = step
	_step_t = 0.0


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
		"res://tools/zombie_turn_net_check.tscn", "--", "--role=client", "--port=%d" % _port]
	_child_pid = OS.create_process(OS.get_executable_path(), args)
	if _child_pid <= 0:
		_fail("couldn't start the client process")
		_finish()
		return
	_log("hosting on 127.0.0.1:%d, client process %d" % [_port, _child_pid])


func _start_client() -> void:
	GameState.character_id = &"peg"
	Net.joined.connect(func() -> void:
		_log("joined as player %d" % Net.local_player_id())
		Net.set_ready(true))
	Net.join_failed.connect(func(reason: String) -> void:
		_fail("join failed: " + reason)
		_client_finish())
	if Net.join_game("127.0.0.1", _port) != OK:
		_fail("couldn't start connecting: " + Net.last_error)
		_client_finish()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_step_t += delta
	if _t > TIMEOUT:
		_fail("timed out in step " + _step)
		if _role == "host":
			_finish()
		else:
			_client_finish()
		return
	if _role == "host":
		_host_tick(delta)
	else:
		_client_tick(delta)


# ================================================================== host

func _host_tick(_delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	match _step:
		"lobby":
			if Net.roster.size() >= 2 and Net.all_ready():
				Net.start_match(MAP)
				_goto("load")
			elif _step_t > 60.0:
				_fail("the client never joined (roster %d)" % Net.roster.size())
				_finish()
		"load":
			if map != null and map.player != null and map.director != null and _step_t > 3.0:
				RoundManager.stop()
				for z: Zombie in map.director.active_zombies():
					z.kill_silently()
				_goto("spawn")
		"spawn":
			if _step_t > 1.0 and _z == null:
				map.director.debug_spawn(1)
				for z: Zombie in map.director.active_zombies():
					if z.state != Zombie.State.DEAD:
						_z = z
				if _z == null and _step_t > 10.0:
					_fail("no zombie spawned")
					_finish()
			elif _z != null and _step_t > 4.0:
				# out of the director's hands: it stands still in CHASE in front of the host's player
				_z.set_physics_process(false)
				_z._enter(Zombie.State.CHASE)
				_z.velocity = Vector3.ZERO
				_z.global_position = map.player.global_position + Vector3(0, 0, -4.0)
				_z.rotation.y = 0.0
				_yaw = 0.0
				GameState.god_mode = true
				_goto("settle")
		"settle":
			_hold()
			if _step_t > 2.5:
				_qa_send("watch", {})
				_goto("turns")
		"turns":
			_hold()
			var want: int = int(_step_t / TURN_GAP_S)
			if want > _turn_i and want < TURNS.size():
				_turn_i = want
				_yaw = wrapf(_yaw + deg_to_rad(float(TURNS[want][0])), -PI, PI)
				_log("turn %d: %+.0f deg" % [want, float(TURNS[want][0])])
				_qa_send("phase", {"in_range": bool(TURNS[want][1])})
			if _step_t > TURN_GAP_S * float(TURNS.size()) + 1.0:
				_qa_send("done", {"host_turns": _host_turns})
				_goto("report")
		"report":
			_hold()
			if not _client_result.is_empty():
				_host_report()
			elif _step_t > 15.0:
				_fail("no result from the client")
				_finish()


## One physics tick of the held zombie: still, facing its heading through the real _face (the animation runs itself).
func _hold() -> void:
	if _z == null or not is_instance_valid(_z) or not _z.is_active():
		_fail("the zombie went away")
		_finish()
		return
	_z.velocity = Vector3.ZERO
	if _z.state != Zombie.State.CHASE:
		_z._enter(Zombie.State.CHASE)
	_z._face(_z.global_position + Vector3(-sin(_yaw), 0, -cos(_yaw)) * 10.0)
	var is_turn: bool = _z._tree_state == "Turn"
	if is_turn and not _host_was_turn:
		_host_turns += 1
	_host_was_turn = is_turn


func _host_report() -> void:
	var expected: int = 0
	for e: Array in TURNS:
		if bool(e[1]):
			expected += 1
	var c: Dictionary = _client_result
	if _host_turns != expected:
		_fail("the host's zombie played %d recorded turns of %d asked" % [_host_turns, expected])
	if int(c.get("entered", -1)) != _host_turns:
		_fail("the client's copy played %d recorded turns, the host's %d" % [int(c.get("entered", -1)), _host_turns])
	# (a facing outside the recorded range shows the body's own fast facing on both machines: only the recorded
	# turns' phases are held to the no-pop limit)
	if float(c.get("max_visual_step_in_range_deg", 999.0)) > 6.0:
		_fail("a visual heading pop on the client during a recorded turn: %.2f deg in one tick" % float(c.get("max_visual_step_in_range_deg", 999.0)))
	if float(c.get("end_pivot_deg", 999.0)) > 0.5:
		_fail("the client's visual did not settle (%.2f deg off the body)" % float(c.get("end_pivot_deg", 999.0)))
	for f: Variant in c.get("fails", []):
		_fail("client: " + str(f))
	var report: Dictionary = {"pass": _fails.is_empty(), "asked": TURNS, "expected_turns": expected, "host_turns": _host_turns, "client": c,
		"fails": Array(_fails), "zombie_send_hz": 20, "note": "legacy_trigger_ticks = ticks on which one tick's observed yaw change reached 25 degrees (the trigger the puppet used before)"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var f: FileAccess = FileAccess.open(_out + "/turn_net.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	_log("host turns %d / client turns %d / old trigger would have fired on %d ticks / max visual step in recorded turns %.2f deg (all phases %.2f) / max body step %.2f deg / end pivot %.3f deg" % [
		_host_turns, int(c.get("entered", -1)), int(c.get("legacy_trigger_ticks", -1)), float(c.get("max_visual_step_in_range_deg", -1.0)), float(c.get("max_visual_step_deg", -1.0)),
		float(c.get("max_body_step_deg", -1.0)), float(c.get("end_pivot_deg", -1.0))])
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[turn-net] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (" + "; ".join(_fails) + ")"])
	if Net.is_online():
		Net.leave("")
	if _child_pid > 0 and OS.is_process_running(_child_pid):
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if OS.is_process_running(_child_pid):
				OS.kill(_child_pid)
			get_tree().quit(0 if _fails.is_empty() else 1))
	else:
		get_tree().quit(0 if _fails.is_empty() else 1)


# ================================================================== client

func _client_tick(_delta: float) -> void:
	var map: MapRoot = get_tree().current_scene as MapRoot
	if _step != "lobby" and not Net.is_online():
		_done = true
		get_tree().quit(1)
		return
	if _step == "lobby":
		if map != null:
			_goto("watch")
		return
	if map == null or map.director == null:
		return
	if not _watch:
		return
	if _pz == null or not is_instance_valid(_pz) or not _pz.is_active():
		_pz = null
		for z: Zombie in map.director.active_zombies():
			if z.puppet and z.state != Zombie.State.DEAD:
				_pz = z
		if _pz == null:
			return
		_last_body = _pz.rotation.y
		_last_visual = _pz.rotation.y + _pz._pivot.rotation.y
		_log("watching the puppet at %s" % str(_pz.global_position.snapped(Vector3.ONE * 0.1)))
	_ticks += 1
	var body_step: float = absf(wrapf(_pz.rotation.y - _last_body, -PI, PI))
	if body_step >= deg_to_rad(25.0):
		_legacy_hits += 1
	_max_body_step = maxf(_max_body_step, body_step)
	_last_body = _pz.rotation.y
	var visual: float = _pz.rotation.y + _pz._pivot.rotation.y
	_max_step = maxf(_max_step, absf(wrapf(visual - _last_visual, -PI, PI)))
	if _in_range:
		_max_step_in_range = maxf(_max_step_in_range, absf(wrapf(visual - _last_visual, -PI, PI)))
	_last_visual = visual
	var is_turn: bool = _pz._tree_state == "Turn"
	if is_turn and not _was_turn:
		_entered += 1
		_log("the puppet plays a recorded turn (%s, %.0f deg)" % [_pz._turn_motion.clip, rad_to_deg(_pz._turn_motion.angle)])
	_was_turn = is_turn
	if _host_done and _step != "finish":
		_goto("finish")
		_client_finish()


func _client_finish() -> void:
	var res: Dictionary = {"entered": _entered, "legacy_trigger_ticks": _legacy_hits, "ticks": _ticks,
		"max_visual_step_deg": rad_to_deg(_max_step), "max_visual_step_in_range_deg": rad_to_deg(_max_step_in_range), "max_body_step_deg": rad_to_deg(_max_body_step),
		"end_pivot_deg": rad_to_deg(absf(_pz._pivot.rotation.y)) if _pz != null and is_instance_valid(_pz) else 999.0,
		"fails": Array(_fails)}
	_qa_send("result", res)
	_log("RESULT: %s" % JSON.stringify(res))
	_done = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		Net.leave("")
		get_tree().quit(0 if _fails.is_empty() else 1))


# ================================================================== shared

func _qa_send(what: String, data: Dictionary) -> void:
	if Net.is_online():
		rpc("_qa", what, data)


@rpc("any_peer", "call_remote", "reliable")
func _qa(what: String, data: Dictionary) -> void:
	match what:
		"watch":
			_watch = true
		"done":
			_host_done = true
		"phase":
			_in_range = bool(data.get("in_range", true))
		"result":
			_client_result = data
