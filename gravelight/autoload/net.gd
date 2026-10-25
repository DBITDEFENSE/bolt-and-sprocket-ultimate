extends Node
## Online co-op (M7): ENet through Godot's high-level multiplayer API, host-authoritative (D-064).
##
## Offline (the default) is the solo game, untouched: no peer, no NetMatch node, and every `is_*` check
## below is a plain enum compare, so solo play has no network overhead or behaviour change.
##
## Lobby: host_game() / join_game() / leave(). Peers map to player ids 1..4 (the host is always 1), each
## with a unique character. The host picks the map; start_match() sends everyone into it with one match seed.
##
## In a match every RPC goes through this autoload (its node path exists on every peer from boot, so nothing
## arrives "too early" for a scene that is still loading) and is handed to `session`, the map's NetMatch,
## which owns player, zombie, world and manager replication.
## Clients send inputs/requests (their own movement, shot rays and hits, interact requests); the host runs
## RoundManager, ZombieDirector, Economy, PowerupManager, PerkManager, CrateManager and QuestManager.

signal roster_changed
signal joined
signal join_failed(reason: String)
signal disconnected(reason: String)
signal console_reply(text: String)

enum Mode { OFFLINE, HOST, CLIENT }

const CHARACTERS: PackedStringArray = ["dutch", "peg", "deacon", "wren"]
const DISPLAY: Dictionary = {"dutch": "Dutch", "peg": "Peg", "deacon": "Deacon", "wren": "Wren", "jakub": "Jakub"}

var mode: Mode = Mode.OFFLINE
var local_pid: int = 1
## pid -> {"peer": int, "character": String, "ready": bool, "egg_slot": bool}
var roster: Dictionary = {}
var session: NetMatch = null
var match_seed: int = 0
var map_scene: String = ""
var in_match: bool = false
var last_error: String = ""
## True while a client applies something the host sent (a puppet call must not be forwarded back).
var applying: bool = false
var _peer_pid: Dictionary = {}    # peer id -> pid
var _connect_left: float = -1.0
var _cfg: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = GLData.table("net")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func cfg() -> Dictionary:
	return _cfg


# ================================================================== queries (cheap: called from hot paths)

func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


## The host and offline play own the simulation; a client only mirrors it.
func is_authority() -> bool:
	return mode != Mode.CLIENT


## Host with a live session: authority-side code should replicate what it does.
func replicating() -> bool:
	return mode == Mode.HOST and session != null


## Host: run `method(args)` on `node` on every client too (world presentation, D-067). No-op otherwise.
func mirror(node: Node, method: StringName, args: Array = []) -> void:
	if mode == Mode.HOST and session != null:
		session.world_call(node, method, args)


## Host: play a 3D sound for everyone (the host plays its own copy as usual).
func sfx_all(key: String, pos: Vector3, db: float = 0.0) -> void:
	if mode == Mode.HOST and session != null:
		session.sfx_all(key, pos, db)


func local_player_id() -> int:
	return local_pid


func is_local_player(pid: int) -> bool:
	return pid == local_pid


func player_ids() -> Array[int]:
	var out: Array[int] = []
	for pid: Variant in roster.keys():
		out.append(int(pid))
	out.sort()
	return out


func peer_of(pid: int) -> int:
	return int((roster.get(pid, {}) as Dictionary).get("peer", 0))


func pid_of_peer(peer: int) -> int:
	return int(_peer_pid.get(peer, 0))


func character_of(pid: int) -> StringName:
	if not is_online():
		return GameState.character_of(pid)   # solo with AI teammates: each bot plays its own survivor

	return StringName(str((roster.get(pid, {}) as Dictionary).get("character", "dutch")))


func display_name(pid: int) -> String:
	return str(DISPLAY.get(String(character_of(pid)), "Player %d" % pid))


func player_color(pid: int) -> Color:
	var cols: Array = _cfg.get("player_colors", [])
	if cols.is_empty():
		return Color.WHITE
	return Color(str(cols[clampi(pid - 1, 0, cols.size() - 1)]))


func all_ready() -> bool:
	for pid: Variant in roster.keys():
		if not bool((roster[pid] as Dictionary).get("ready", false)):
			return false
	return true


# ================================================================== lobby

## Hosts on `port`. `bind_ip` "*" listens on every interface (LAN play); tests pass "127.0.0.1".
func host_game(port: int = -1, bind_ip: String = "*") -> Error:
	leave("")
	if port <= 0:
		port = int(_cfg.get("port", 24785))
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err: Error = peer.create_server(port, maxi(1, int(_cfg.get("max_players", 4)) - 1))
	if err != OK:
		last_error = "Couldn't host on port %d (%s)." % [port, error_string(err)]
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	local_pid = 1
	_peer_pid = {1: 1}
	roster = {1: {"peer": 1, "character": String(GameState.character_id), "ready": true, "egg_slot": _egg_slot(),
		"kits": Muster.profile_kits()}}   # the Muster (T-079): every survivor's sidearm and Field Habits
	last_error = ""
	roster_changed.emit()
	return OK


func join_game(ip: String, port: int = -1) -> Error:
	leave("")
	if port <= 0:
		port = int(_cfg.get("port", 24785))
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip.strip_edges(), port)
	if err != OK:
		last_error = "Couldn't connect to %s:%d (%s)." % [ip, port, error_string(err)]
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	local_pid = 0
	roster.clear()
	last_error = ""
	_connect_left = float(_cfg.get("connect_timeout_seconds", 8.0))
	return OK


## Closes the connection and returns to offline play. `reason` is shown by the main menu.
func leave(reason: String = "") -> void:
	var was_online: bool = mode != Mode.OFFLINE
	if session != null and is_instance_valid(session):
		session.shutdown()
	session = null
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	local_pid = 1
	roster.clear()
	_peer_pid.clear()
	in_match = false
	_connect_left = -1.0
	GameState.player_ids = [1]
	GameState.characters = {}
	if reason != "":
		last_error = reason
	if was_online:
		disconnected.emit(reason)


func set_character(character: String) -> void:
	if not CHARACTERS.has(character):
		return
	if is_host():
		_apply_character(1, character)
	elif is_client():
		_rpc_req_character.rpc_id(1, character)


func set_ready(is_ready: bool) -> void:
	if is_host():
		(roster[1] as Dictionary)["ready"] = true
		_broadcast_roster()
	elif is_client():
		_rpc_req_ready.rpc_id(1, is_ready)


## Host: send everyone into `scene` (res:// path of a map scene). `campaign` starts the campaign chain (T-033).
func start_match(scene: String, campaign: bool = false) -> void:
	if not is_host() or scene == "":
		return
	match_seed = randi()
	_rpc_start.rpc(scene, match_seed, campaign)
	_begin_match(scene, match_seed, campaign)


## Host: the squad exfils to the next campaign map (T-033). `payload` is Campaign.snapshot(): every player's
## kit, the round and the schedules; each peer stores it and restores what it owns when the map loads.
func travel(scene: String, payload: Dictionary) -> void:
	if not is_host() or scene == "":
		return
	match_seed = randi()
	_rpc_travel.rpc(scene, match_seed, payload)
	Campaign.carry = payload
	_begin_match(scene, match_seed, true)


## Host: everyone back to the lobby (main menu opens it while online).
func return_to_lobby() -> void:
	if not is_host():
		return
	_rpc_to_lobby.rpc()
	_to_lobby()


func _begin_match(scene: String, seed_value: int, campaign: bool = false) -> void:
	map_scene = scene
	match_seed = seed_value
	in_match = true
	Campaign.active = campaign
	if not campaign:
		Campaign.carry = {}
	var ids: Array[int] = player_ids()
	GameState.player_ids = ids
	var chars: Dictionary = {}
	for pid: int in ids:
		chars[pid] = character_of(pid)
	GameState.characters = chars
	GameState.character_id = character_of(local_pid)
	QuestManager.pending_seed = seed_value
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func _to_lobby() -> void:
	in_match = false
	for pid: Variant in roster.keys():
		if int(pid) != 1:
			(roster[pid] as Dictionary)["ready"] = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")


func _egg_slot() -> bool:
	var eggs: Dictionary = ProfileSave.profile.get("egg_rewards", {})
	return bool(eggs.get("map01_requiem", false)) or bool(eggs.get("map01_perk_slot_5", false))


func _apply_character(pid: int, character: String) -> void:
	if not roster.has(pid):
		return
	for other: Variant in roster.keys():
		if int(other) != pid and str((roster[other] as Dictionary)["character"]) == character:
			return   # taken: each survivor once
	(roster[pid] as Dictionary)["character"] = character
	if pid == local_pid:
		GameState.character_id = StringName(character)
	_broadcast_roster()


func _free_character(wanted: String) -> String:
	var taken: Dictionary = {}
	for pid: Variant in roster.keys():
		taken[str((roster[pid] as Dictionary)["character"])] = true
	if CHARACTERS.has(wanted) and not taken.has(wanted):
		return wanted
	for c: String in CHARACTERS:
		if not taken.has(c):
			return c
	return "dutch"


func _broadcast_roster() -> void:
	if is_host():
		_rpc_roster.rpc(roster)
	roster_changed.emit()


func _process(delta: float) -> void:
	if _connect_left > 0.0:
		_connect_left -= delta
		if _connect_left <= 0.0 and is_client() and local_pid == 0:
			var msg: String = "No answer from the host (timed out)."
			leave(msg)
			join_failed.emit(msg)


func _on_peer_connected(_peer: int) -> void:
	pass   # the client introduces itself with _rpc_hello


func _on_peer_disconnected(peer: int) -> void:
	if not is_host():
		return
	var pid: int = pid_of_peer(peer)
	_peer_pid.erase(peer)
	if pid == 0:
		return
	roster.erase(pid)
	if session != null:
		session.on_player_left(pid)
	_broadcast_roster()


func _on_connected() -> void:
	_rpc_hello.rpc_id(1, String(GameState.character_id), _egg_slot())
	_rpc_kits.rpc_id(1, Muster.profile_kits())   # after the hello (same reliable channel, so in order)


## The Muster (T-079): sends this peer's loadouts (one per survivor, from the profile) to the host again after
## they were edited in the lobby. The host keeps them in the roster and shares them with everyone.
func send_kits() -> void:
	if is_host():
		if roster.has(1):
			(roster[1] as Dictionary)["kits"] = Muster.profile_kits()
			_broadcast_roster()
	elif is_client():
		_rpc_kits.rpc_id(1, Muster.profile_kits())


func _on_connection_failed() -> void:
	var msg: String = "Couldn't reach the host."
	leave(msg)
	join_failed.emit(msg)


func _on_server_disconnected() -> void:
	var in_game: bool = in_match
	leave("The host closed the game.")
	if in_game:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")


func _sender_pid() -> int:
	return pid_of_peer(multiplayer.get_remote_sender_id())


func _from_host() -> bool:
	return is_client() and multiplayer.get_remote_sender_id() == 1


# ================================================================== lobby RPCs

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(character: String, egg_slot: bool) -> void:
	if not is_host():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	if in_match:
		_rpc_reject.rpc_id(peer, "That game has already started.")
		return
	var pid: int = 0
	for cand: int in range(2, int(_cfg.get("max_players", 4)) + 1):
		if not roster.has(cand):
			pid = cand
			break
	if pid == 0:
		_rpc_reject.rpc_id(peer, "That game is full.")
		return
	_peer_pid[peer] = pid
	roster[pid] = {"peer": peer, "character": _free_character(character), "ready": false, "egg_slot": egg_slot}
	_rpc_welcome.rpc_id(peer, pid)
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	leave(reason)
	join_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(pid: int) -> void:
	local_pid = pid
	_connect_left = -1.0
	joined.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(r: Dictionary) -> void:
	roster.clear()
	for k: Variant in r.keys():
		roster[int(k)] = r[k]
	if roster.has(local_pid):
		GameState.character_id = StringName(str((roster[local_pid] as Dictionary)["character"]))
	roster_changed.emit()


## Host: a peer's Muster loadouts (T-079), checked (known sidearms and habits, at most the slot cap) and shared.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_kits(kits: Dictionary) -> void:
	if not is_host() or in_match:
		return
	var pid: int = _sender_pid()
	if roster.has(pid):
		(roster[pid] as Dictionary)["kits"] = Muster.sanitize_kits(kits)
		_broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_character(character: String) -> void:
	if is_host() and not in_match:
		_apply_character(_sender_pid(), character)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_ready(is_ready: bool) -> void:
	var pid: int = _sender_pid()
	if is_host() and roster.has(pid) and not in_match:
		(roster[pid] as Dictionary)["ready"] = is_ready
		_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func _rpc_start(scene: String, seed_value: int, campaign: bool = false) -> void:
	_begin_match(scene, seed_value, campaign)


## Campaign exfil (T-033): the host's payload for the next map, then the same scene change as a match start.
@rpc("authority", "call_remote", "reliable")
func _rpc_travel(scene: String, seed_value: int, payload: Dictionary) -> void:
	Campaign.carry = payload
	Campaign.prepare_state(payload)
	_begin_match(scene, seed_value, true)


@rpc("authority", "call_remote", "reliable")
func _rpc_to_lobby() -> void:
	_to_lobby()


# ================================================================== match RPCs (handed to the session)
# Client -> host. The host checks the sender maps to a player; the session validates the content.

@rpc("any_peer", "call_remote", "reliable")
func _rpc_loaded() -> void:
	if is_host() and session != null:
		session.on_client_loaded(_sender_pid())


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_pstate(data: PackedByteArray) -> void:
	if is_host() and session != null:
		session.on_player_state(_sender_pid(), data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_inv(inv: Dictionary) -> void:
	if is_host() and session != null:
		session.on_inventory(_sender_pid(), inv)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_fire(data: Array) -> void:
	if is_host() and session != null:
		session.on_fire(_sender_pid(), data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit(net_id: int, dmg: float, limb: StringName, weapon_id: StringName, kind: StringName, piercing: bool, origin: Vector3, dir: Vector3) -> void:
	if is_host() and session != null:
		session.on_hit(_sender_pid(), net_id, dmg, limb, weapon_id, kind, piercing, origin, dir)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_zfx(net_id: int, effect: StringName, a: float, b: float) -> void:
	if is_host() and session != null:
		session.on_zombie_effect(_sender_pid(), net_id, effect, a, b)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_shot(path: String, weapon_id: StringName, upgraded: bool) -> void:
	if is_host() and session != null:
		session.on_shootable(_sender_pid(), path, weapon_id, upgraded)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact(path: String, inv: Dictionary) -> void:
	if is_host() and session != null:
		session.on_interact(_sender_pid(), path, inv)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hold(path: String, active: bool) -> void:
	if is_host() and session != null:
		session.on_hold(_sender_pid(), path, active)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pev(ev: StringName, args: Array) -> void:
	if is_host() and session != null:
		session.on_player_event(_sender_pid(), ev, args)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_fx(kind: StringName, args: Array) -> void:
	if is_host() and session != null:
		session.on_fx(_sender_pid(), kind, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_quest(op: StringName, args: Array) -> void:
	if is_host() and session != null:
		session.on_quest_request(_sender_pid(), op, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_console(text: String) -> void:
	if not is_host():
		return
	var reply: String = GLConsole.run(text)
	_rpc_console_reply.rpc_id(multiplayer.get_remote_sender_id(), reply)


# Host -> clients.

@rpc("authority", "call_remote", "reliable")
func _rpc_begin() -> void:
	if session != null:
		session.on_begin()


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_players(data: PackedByteArray) -> void:
	if session != null:
		session.on_players(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_inv_of(pid: int, inv: Dictionary) -> void:
	if session != null:
		session.on_inventory_of(pid, inv)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_fire_of(pid: int, data: Array) -> void:
	if session != null:
		session.on_fire_of(pid, data)


@rpc("authority", "call_remote", "reliable")
func _rpc_op(op: StringName, args: Array) -> void:
	if session != null:
		session.on_op(op, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event(signal_name: StringName, args: Array) -> void:
	if session != null:
		session.on_event(signal_name, args)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _rpc_state(d: Dictionary) -> void:
	if session != null:
		session.on_state(d)


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _rpc_zsnap(data: PackedByteArray) -> void:
	if session != null:
		session.on_zombie_snapshot(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_zev(net_id: int, ev: StringName, args: Array) -> void:
	if session != null:
		session.on_zombie_event(net_id, ev, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_world(path: String, ev: StringName, args: Array) -> void:
	if session != null:
		session.on_world_event(path, ev, args)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_sfx(key: String, pos: Vector3, db: float) -> void:
	if session != null:
		AudioDirector.play_3d(key, pos, db)


@rpc("authority", "call_remote", "reliable")
func _rpc_vo(line_id: StringName) -> void:
	if session != null:
		GLVO.play_local(line_id)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_fx_of(kind: StringName, args: Array) -> void:
	if session != null:
		session.on_fx_of(kind, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(stats: Dictionary, elapsed: float) -> void:
	if session != null:
		session.on_game_over(stats, elapsed)


@rpc("authority", "call_remote", "reliable")
func _rpc_console_reply(text: String) -> void:
	console_reply.emit(text)
	GLConsole.print_line(text)
