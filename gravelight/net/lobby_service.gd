class_name LobbyService
extends Node
## Online lobbies (UPDATE 09 section 2b, docs/U09_CONTRACTS.md C3, DECISIONS T-138). The autoload `Lobbies`.
##
## A lobby is one row in Supabase (`supabase/migrations/0001_lobbies.sql`): its 6-letter join code, the map,
## public or private, the host's display name, the player list the host keeps current, the bots toggle. Players
## find a lobby (Quick Match, Browse, Join by code), then Net connects them peer to peer over WebRTC through the
## lobby's signaling channel; from there the lobby itself (survivor pick without duplicates, ready check, the
## host starting) is Net's roster, the same as the LAN lobby. The host heartbeats the row every
## `lobby_heartbeat_s` (20 s); a row without one for `lobby_expire_s` (120 s) is swept.
##
## Backends: SupabaseLobbyBackend (REST + the public anon key) or MockLobbyService (the same rules in memory or
## in a local relay; selected by online.json "backend": "mock" or the --mock-online[=port] flag; the smokes call
## use_mock()). Signaling follows the backend: SupabaseSignaling or MockSignaling.
##
## Failures: no answer within `connect_timeout_s` (15) -> failed("Couldn't connect ... (timed out ...)") and back
## to the list; the host leaving -> left("The host left the match.") for everyone; a dropped client keeps its
## session token for `rejoin_grace_s` (60) and rejoin() puts it back into the running match as the same player.

signal lobbies_changed(list: Array)
signal joined(lobby: Dictionary)
signal left(reason: String)
signal failed(reason: String)
signal match_starting(scene: String, seed_value: int)
## Any change the lobby screens should redraw for (state, roster, lobby settings).
signal changed

enum State { IDLE, CREATING, SEARCHING, JOINING, IN_LOBBY, IN_MATCH }

const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"   # no I / O (they read as 1 / 0)
const DEFAULT_MAP: String = "map00_crossroads"
const BROWSE_REFRESH_S: float = 5.0
const PUSH_DEBOUNCE_S: float = 0.5
const SWEEP_EVERY_S: float = 30.0
const LEFT_BY_USER: String = "left"

var state: State = State.IDLE
var is_host: bool = false
## The lobby we are in (host: the row we created; client: the row we joined, kept current by the host's shares).
var current: Dictionary = {}
## The last Browse list.
var lobbies: Array = []
var backend: Node = null
var backend_kind: String = "supabase"
var mock_server: MockSignalServer = null
var mock_port: int = 0
var last_reason: String = ""
var _cfg: Dictionary = {}
var _host_token: String = ""
var _hb_t: float = 0.0
var _browse_t: float = -1.0
var _push_t: float = -1.0
var _sweep_t: float = 999.0
var _leaving: bool = false
var _retry_create: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = GLData.table("online")
	var mock: bool = str(_cfg.get("backend", "supabase")) == "mock"
	var port: int = 0
	var serve: bool = false
	for a: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--mock-online":
			mock = true
		elif a.begins_with("--mock-online="):
			mock = true
			port = int(a.get_slice("=", 1))
		elif a.begins_with("--mock-online-serve="):
			mock = true
			serve = true
			port = int(a.get_slice("=", 1))
	if mock:
		use_mock(port, serve)
	else:
		use_supabase()
	Net.my_name = display_name()
	Net.joined.connect(_on_net_joined)
	Net.join_failed.connect(_on_net_failed)
	Net.disconnected.connect(_on_net_disconnected)
	Net.roster_changed.connect(_on_roster_changed)
	Net.match_started.connect(_on_match_started)


func cfg() -> Dictionary:
	return _cfg


# ================================================================== backends

func use_supabase() -> void:
	_set_backend(SupabaseLobbyBackend.new(str(_cfg.get("supabase_url", "")), str(_cfg.get("supabase_anon_key", ""))), "supabase")
	mock_port = 0
	Net.signaling_factory = func() -> NetSignaling:
		return SupabaseSignaling.new(str(_cfg.get("supabase_url", "")), str(_cfg.get("supabase_anon_key", "")))
	Net.ice_override = {}


## The mock backend. `port` 0: the lobby table in this process and no signaling (unit tests); `port` > 0: the
## table and the signaling relay of a MockSignalServer on 127.0.0.1:<port>, started here when `serve`.
## Local WebRTC needs no STUN: ICE uses the host candidates only (nothing leaves the machine).
func use_mock(port: int = 0, serve: bool = false) -> Error:
	if mock_server != null:
		mock_server.queue_free()
		mock_server = null
	var err: Error = OK
	if serve and port > 0:
		mock_server = MockSignalServer.new()
		mock_server.name = "MockSignalServer"
		add_child(mock_server)
		err = mock_server.listen(port)
	mock_port = port
	_set_backend(MockLobbyService.new(port), "mock")
	Net.signaling_factory = func() -> NetSignaling: return MockSignaling.new(mock_port)
	Net.ice_override = {"iceServers": []}
	return err


func _set_backend(b: Node, kind: String) -> void:
	if backend != null and is_instance_valid(backend):
		backend.queue_free()
	backend = b
	backend.name = "Backend"
	backend_kind = kind
	add_child(backend)


func _call(fn: String, args: Dictionary, cb: Callable) -> void:
	backend.call("request", fn, args, cb)


# ================================================================== helpers (static: the unit tests use them)

static func make_code(n: int = 6, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out: String = ""
	for i: int in n:
		out += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return out


## What a player typed, as a code: letters only, upper case ("abc-def" -> "ABCDEF"). Validity: is_valid_code.
static func normalize_code(text: String) -> String:
	var out: String = ""
	for ch: String in text.to_upper():
		if ch >= "A" and ch <= "Z":
			out += ch
	return out


static func is_valid_code(code: String) -> bool:
	return MockLobbyBackend.is_valid_code(code)


static func make_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## "" when the row is a valid lobby (the SQL constraints), else why not.
static func validate_lobby(row: Dictionary) -> String:
	return MockLobbyBackend.validate_row(row)


static func map_scene(map_id: String) -> String:
	for m: Array in MenuCharacter.MAPS:
		if str(m[0]) == map_id:
			return str(m[2])
	return ""


static func map_name(map_id: String) -> String:
	for m: Array in MenuCharacter.MAPS:
		if str(m[0]) == map_id:
			return str(m[1])
	return map_id


## A player-facing sentence for a backend error key.
static func friendly(e: String) -> String:
	match e:
		MockLobbyBackend.ERR_NOT_FOUND:
			return "No lobby with that code (it may have closed or expired)."
		MockLobbyBackend.ERR_FULL:
			return "That lobby is full."
		MockLobbyBackend.ERR_CLOSED:
			return "That match has already started."
		MockLobbyBackend.ERR_RATE:
			return "Too many lobbies in a minute. Wait a moment and try again."
		MockLobbyBackend.ERR_ONE_OPEN:
			return "You already have an open lobby."
		"server_full":
			return "The lobby service is full right now. Try again later."
		"network":
			return "Couldn't reach the lobby service. Check your connection."
		"not_configured":
			return "Online play isn't set up in this build (no lobby service)."
	return "The lobby service said no (%s)." % e


## Quick Match's pick: the open public lobby (for `map_id`, if given) with the fewest players that still has room;
## ties go to the newest. {} = none (create one instead).
static func pick_quick_match(rows: Array, map_id: String = "") -> Dictionary:
	var best: Dictionary = {}
	for v: Variant in rows:
		if not (v is Dictionary):
			continue
		var r: Dictionary = v
		if str(r.get("status", "open")) != "open" or not bool(r.get("is_public", true)):
			continue
		if map_id != "" and str(r.get("map_id", "")) != map_id:
			continue
		var n: int = (r.get("players", []) as Array).size()
		if n >= int(r.get("max_players", 4)):
			continue
		if best.is_empty() or n < (best.get("players", []) as Array).size():
			best = r
	return best


# ================================================================== display name

func display_name() -> String:
	return Net.clean_name(str(ProfileSave.profile.get("display_name", "Player")))


func has_display_name() -> bool:
	return ProfileSave.profile.has("display_name")


func set_display_name(n: String) -> void:
	ProfileSave.profile["display_name"] = Net.clean_name(n)
	ProfileSave.save_profile()
	Net.my_name = display_name()
	if Net.roster.has(Net.local_player_id()):
		(Net.roster[Net.local_player_id()] as Dictionary)["name"] = Net.my_name


# ================================================================== the API (C3)

## Host a new lobby. Returns its join code at once; `joined(lobby)` follows when the row is stored and the WebRTC
## lobby is open (or `failed(reason)`). On the rare code clash a new code is drawn: use the code in `joined`.
func create(map_id: String, is_public: bool, host_display_name: String = "", max_players: int = 0, fill: bool = false) -> String:
	if state != State.IDLE:
		leave()
	if host_display_name != "":
		set_display_name(host_display_name)
	var mp: int = clampi(max_players if max_players > 0 else int(_cfg.get("max_players", 4)), 1, 4)
	var row: Dictionary = {"code": make_code(int(_cfg.get("join_code_len", 6))), "map_id": map_id if map_id != "" else DEFAULT_MAP,
		"is_public": is_public, "host_name": display_name(), "fill_bots": fill, "max_players": mp,
		"players": [{"name": display_name(), "character": String(GameState.character_id), "ready": true, "pid": 1}]}
	_host_token = make_token()
	_set_state(State.CREATING)
	_call("create", {"row": row, "host_token": _host_token}, _on_created.bind(row))
	return str(row["code"])


func _on_created(ok: bool, _result: Variant, e: String, row: Dictionary) -> void:
	if state != State.CREATING:
		return
	if not ok:
		if e == MockLobbyBackend.ERR_DUPLICATE and _retry_create < 3:
			_retry_create += 1
			row["code"] = make_code(int(_cfg.get("join_code_len", 6)))
			_call("create", {"row": row, "host_token": _host_token}, _on_created.bind(row))
			return
		_retry_create = 0
		_fail(friendly(e))
		return
	_retry_create = 0
	Net.my_name = display_name()
	var err: Error = Net.host_online(row)
	if err != OK:
		_call("close", {"code": row["code"], "host_token": _host_token}, func(_a: bool, _b: Variant, _c: String) -> void: pass)
		_fail(Net.last_error)
		return
	current = row.duplicate(true)
	current["status"] = "open"
	is_host = true
	_hb_t = 0.0
	_set_state(State.IN_LOBBY)
	joined.emit(current)


## The Browse list (cached; refreshed in the background: `lobbies_changed` follows).
func list() -> Array[Dictionary]:
	refresh()
	var out: Array[Dictionary] = []
	for v: Variant in lobbies:
		out.append(v as Dictionary)
	return out


func refresh() -> void:
	if backend_kind == "supabase" and _sweep_t >= SWEEP_EVERY_S:
		_sweep_t = 0.0
		_call("sweep", {}, func(_a: bool, _b: Variant, _c: String) -> void: pass)
	_call("list", {}, func(ok: bool, result: Variant, _e: String) -> void:
		if ok and result is Array:
			lobbies = (result as Array).filter(func(r: Variant) -> bool: return r is Dictionary and validate_lobby(r as Dictionary) == "")
			lobbies_changed.emit(lobbies)
			changed.emit())


## Refresh the Browse list now and every 5 s until stop_browsing().
func start_browsing() -> void:
	_browse_t = 0.0
	refresh()


func stop_browsing() -> void:
	_browse_t = -1.0


## Join a lobby by its code. `joined(lobby)` once connected and welcomed, `failed(reason)` otherwise.
## A code we dropped out of within the grace rejoins the running match instead.
func join(code: String) -> void:
	var c: String = normalize_code(code)
	if not is_valid_code(c):
		_fail("A join code is %d letters." % int(_cfg.get("join_code_len", 6)), false)
		return
	if state != State.IDLE and state != State.SEARCHING:
		leave()
	if can_rejoin() and str(_session().get("code", "")) == c:
		rejoin()
		return
	_set_state(State.JOINING)
	var token: String = make_token()
	_call("join", {"code": c, "player": {"name": display_name(), "character": String(GameState.character_id)}},
		func(ok: bool, result: Variant, e: String) -> void:
			if state != State.JOINING:
				return
			if not ok or not (result is Dictionary):
				_fail(friendly(e if e != "" else MockLobbyBackend.ERR_NOT_FOUND))
				return
			_connect_client(result as Dictionary, token))


## Quick Match: the open public lobby (for `map_id`, if given) with the fewest players, else a new public one.
func quick_match(map_id: String = "") -> void:
	if state != State.IDLE:
		leave()
	_set_state(State.SEARCHING)
	_call("list", {}, func(ok: bool, result: Variant, _e: String) -> void:
		if state != State.SEARCHING:
			return
		var pick: Dictionary = pick_quick_match(result as Array if ok and result is Array else [], map_id)
		if pick.is_empty():
			_set_state(State.IDLE)
			create(map_id if map_id != "" else DEFAULT_MAP, true, "", 0, true)
		else:
			join(str(pick["code"])))


## True when a dropped session can still go back in (same code, within rejoin_grace_s of the drop).
func can_rejoin() -> bool:
	return rejoin_seconds_left() > 0.0


func rejoin_seconds_left() -> float:
	var s: Dictionary = _session()
	if s.is_empty() or float(s.get("dropped_at", 0.0)) <= 0.0:
		return 0.0
	return maxf(0.0, float(_cfg.get("rejoin_grace_s", 60)) - (Time.get_unix_time_from_system() - float(s["dropped_at"])))


func rejoin_code() -> String:
	return str(_session().get("code", ""))


## Back into the match we dropped out of (same token -> same pid and body). False when there is nothing to rejoin.
func rejoin() -> bool:
	if not can_rejoin():
		return false
	var s: Dictionary = _session()
	if state != State.IDLE:
		_leaving = true
		Net.leave("")
		_leaving = false
	_set_state(State.JOINING)
	_call("get", {"code": str(s["code"])}, func(ok: bool, result: Variant, e: String) -> void:
		if state != State.JOINING:
			return
		if not ok or not (result is Dictionary):
			_clear_session()
			_fail(friendly(e if e != "" else MockLobbyBackend.ERR_NOT_FOUND))
			return
		_connect_client(result as Dictionary, str(s["token"])))
	return true


func _connect_client(row: Dictionary, token: String) -> void:
	Net.my_name = display_name()
	var err: Error = Net.join_online(row, token)
	if err != OK:
		_fail(Net.last_error)
		return
	current = row.duplicate(true)
	is_host = false
	_save_session(str(row.get("code", "")), token, 0.0)


## Host: refresh the row (the player list, status, settings) and its heartbeat. Runs every lobby_heartbeat_s.
func heartbeat() -> void:
	if not is_host or _host_token == "" or current.is_empty():
		return
	_hb_t = 0.0
	_push_t = -1.0
	var full: bool = Net.player_ids().size() >= Net.max_slots()
	var status: String = "playing" if Net.in_match else "open"
	var patch: Dictionary = {"players": roster_rows(), "status": status if not (full and status == "open") else "starting",
		"fill_bots": Net.fill_bots, "map_id": str(current.get("map_id", DEFAULT_MAP)), "is_public": bool(current.get("is_public", true))}
	_call("update", {"code": current["code"], "host_token": _host_token, "patch": patch}, func(ok: bool, result: Variant, _e: String) -> void:
		if ok and result is Dictionary and is_host:
			current.merge(result as Dictionary, true))


## The roster as lobby-row players: [{name, character, ready, pid}] (bots included once the match has them).
func roster_rows() -> Array:
	var out: Array = []
	for pid: int in Net.player_ids():
		var r: Dictionary = Net.roster[pid]
		out.append({"name": Net.player_name(pid), "character": str(r.get("character", "")), "ready": bool(r.get("ready", false)) or bool(r.get("bot", false)), "pid": pid})
	return out


func set_ready(is_ready: bool) -> void:
	Net.set_ready(is_ready)


func set_character(character: String) -> void:
	Net.set_character(character)


## Host: bots take the empty slots at the start (and a dropped player's slot) when on.
func set_fill_bots(on: bool) -> void:
	if not is_host:
		return
	current["fill_bots"] = on
	Net.share_lobby({"fill_bots": on})
	_queue_push()


func set_map(map_id: String) -> void:
	if not is_host or map_scene(map_id) == "":
		return
	current["map_id"] = map_id
	Net.share_lobby({"map_id": map_id})
	_queue_push()


func set_public(on: bool) -> void:
	if not is_host:
		return
	current["is_public"] = on
	Net.share_lobby({"is_public": on})
	_queue_push()


## Leave the lobby (or the match). The host closes the row: everyone else gets "The host left the match.".
func leave() -> void:
	_leaving = true
	if is_host and _host_token != "" and not current.is_empty():
		_call("close", {"code": current["code"], "host_token": _host_token}, func(_a: bool, _b: Variant, _c: String) -> void: pass)
	var was: State = state
	if Net.is_online():
		Net.leave("")
	_clear_session()
	_host_token = ""
	is_host = false
	current = {}
	_leaving = false
	_set_state(State.IDLE)
	if was != State.IDLE:
		left.emit(LEFT_BY_USER)


## Host: everyone into the lobby's map (or the campaign). Needs everyone ready.
func start(campaign: bool = false) -> bool:
	if not is_host or state != State.IN_LOBBY or not Net.all_ready():
		return false
	var scene: String = Campaign.scene_for(Campaign.first_map()) if campaign else map_scene(str(current.get("map_id", DEFAULT_MAP)))
	if scene == "":
		return false
	Net.start_match(scene, campaign)
	heartbeat()   # the row says "playing": Browse and Quick Match skip it, join refuses it
	return true


# ================================================================== reacting to Net

func _on_net_joined() -> void:
	if state == State.JOINING:
		_set_state(State.IN_LOBBY)
		joined.emit(current)


func _on_net_failed(reason: String) -> void:
	if state == State.JOINING:
		_fail(reason)


func _on_net_disconnected(reason: String) -> void:
	if _leaving or state == State.IDLE or state == State.CREATING or state == State.SEARCHING:
		return
	if state == State.JOINING:
		return   # join_failed follows (Net emits it right after leave)
	var in_match: bool = state == State.IN_MATCH
	if is_host:
		_call("close", {"code": current.get("code", ""), "host_token": _host_token}, func(_a: bool, _b: Variant, _c: String) -> void: pass)
	if not is_host and in_match and reason != Net.HOST_LEFT:
		var s: Dictionary = _session()
		if not s.is_empty():
			_save_session(str(s["code"]), str(s["token"]), Time.get_unix_time_from_system())   # the grace starts now
	else:
		_clear_session()
	is_host = false
	_host_token = ""
	last_reason = reason
	_set_state(State.IDLE)
	left.emit(reason)


func _on_roster_changed() -> void:
	if is_host:
		_queue_push()
	if not is_host and not Net.lobby.is_empty() and not current.is_empty():
		current.merge(Net.lobby, true)
	changed.emit()


func _on_match_started(scene: String, seed_value: int) -> void:
	if state == State.IN_LOBBY or state == State.JOINING or state == State.IN_MATCH:
		_set_state(State.IN_MATCH)
		match_starting.emit(scene, seed_value)


func _queue_push() -> void:
	if _push_t < 0.0:
		_push_t = PUSH_DEBOUNCE_S


func _process(delta: float) -> void:
	_sweep_t += delta
	if _browse_t >= 0.0:
		_browse_t += delta
		if _browse_t >= BROWSE_REFRESH_S:
			_browse_t = 0.0
			refresh()
	if state == State.IN_MATCH and Net.is_online() and not Net.in_match:
		_set_state(State.IN_LOBBY)   # the host took everyone back to the lobby
		_queue_push()
	if not is_host:
		return
	_hb_t += delta
	if _hb_t >= float(_cfg.get("lobby_heartbeat_s", 20)):
		heartbeat()
	if _push_t >= 0.0:
		_push_t -= delta
		if _push_t < 0.0:
			heartbeat()


func _set_state(s: State) -> void:
	state = s
	changed.emit()


func _fail(reason: String, reset: bool = true) -> void:
	last_reason = reason
	if reset:
		if Net.is_online() and state != State.IN_MATCH:
			_leaving = true
			Net.leave("")
			_leaving = false
		current = {}
		is_host = false
		_set_state(State.IDLE)
	failed.emit(reason)


# ================================================================== the rejoin session (kept in the profile)

func _session() -> Dictionary:
	var s: Variant = ProfileSave.profile.get("online_session", {})
	return s as Dictionary if s is Dictionary else {}


func _save_session(code: String, token: String, dropped_at: float) -> void:
	ProfileSave.profile["online_session"] = {"code": code, "token": token, "dropped_at": dropped_at}
	ProfileSave.save_profile()


func _clear_session() -> void:
	if ProfileSave.profile.has("online_session"):
		ProfileSave.profile.erase("online_session")
		ProfileSave.save_profile()
