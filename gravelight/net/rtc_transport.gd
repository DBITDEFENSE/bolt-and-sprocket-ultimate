class_name RtcTransport
extends Node
## The WebRTC half of Net (UPDATE 09 section 2a, DECISIONS T-138): one WebRTCMultiplayerPeer per game, one
## WebRTCPeerConnection per host<->client pair, connected through a NetSignaling channel. Net hands the finished
## MultiplayerPeer to the high-level multiplayer API, so every existing rpc (lobby and match) runs over it exactly
## as it does over ENet; nothing above Net knows which transport is in use.
##
## Handshake (the host is network peer 1 and signaling id "host"):
##   client -> host   hello {name}                     resent every 1.5 s until answered (broadcasts can be lost)
##   host -> client   hello {peer_id}                  the network id the host picked for it (2 .. 2^31-1)
##   host             add_peer + create_offer          -> offer {sdp} to the client
##   client           create_client(peer_id) + add_peer(host) on the hello, set_remote_description(offer) -> answer
##   both             ice {m, i, n} for every local candidate (trickle ICE), add_ice_candidate for the other's
## The data channels open, WebRTCMultiplayerPeer reports the peer connected, and Net's normal lobby rpcs start
## (_rpc_hello ...). Leaving sends "bye" so the other side learns at once instead of after a connection timeout.

signal client_peer_ready(peer: WebRTCMultiplayerPeer)
## The host said bye (client side) or the signaling channel failed before we were connected.
signal host_gone(reason: String)
signal setup_failed(reason: String)

const HELLO_RESEND_S: float = 1.5
## Extra channels after the default ones, in the order Net's rpcs use them (transfer_channel 1..4).
const CHANNELS: Array = [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED]

static var _probe: int = -1   # -1 unknown, 0 no, 1 yes

var peer: WebRTCMultiplayerPeer = null
var signaling: NetSignaling = null
var is_host: bool = false
var ice: Dictionary = {}
var hello_info: Dictionary = {}
var _conns: Dictionary = {}        # network peer id -> WebRTCPeerConnection
var _sid_of: Dictionary = {}       # network peer id -> signaling id
var _peer_of_sid: Dictionary = {}  # signaling id -> network peer id
var _pending: Array = []           # client: offer / ice that arrived before the connection existed
var _assigned_id: int = 0
var _hello_t: float = 99.0
var _closed: bool = false


## True when this build can make WebRTC connections: always on the web; on desktop only with the webrtc-native
## GDExtension (addons/webrtc). Probed once by initializing a throwaway connection.
static func available() -> bool:
	if _probe < 0:
		_probe = 0
		if ClassDB.class_exists("WebRTCPeerConnection") and ClassDB.class_exists("WebRTCMultiplayerPeer"):
			var c: WebRTCPeerConnection = WebRTCPeerConnection.new()
			if c.initialize({}) == OK:
				_probe = 1
			c.close()
	return _probe == 1


## The ICE configuration from online.json: the `stun` list, plus `turn` when it has urls.
static func ice_config(online: Dictionary) -> Dictionary:
	var servers: Array = []
	var stun: Array = online.get("stun", [])
	if not stun.is_empty():
		servers.append({"urls": stun.duplicate()})
	var turn: Dictionary = online.get("turn", {})
	var turls: Array = turn.get("urls", [])
	if not turls.is_empty():
		servers.append({"urls": turls.duplicate(), "username": str(turn.get("username", "")),
			"credential": str(turn.get("credential", ""))})
	return {"iceServers": servers}


func start_host(sig: NetSignaling, code: String) -> Error:
	is_host = true
	peer = WebRTCMultiplayerPeer.new()
	var err: Error = peer.create_server(CHANNELS)
	if err != OK:
		return err
	return _open_signaling(sig, code)


func start_client(sig: NetSignaling, code: String, info: Dictionary) -> Error:
	is_host = false
	hello_info = info
	peer = WebRTCMultiplayerPeer.new()
	return _open_signaling(sig, code)


func _open_signaling(sig: NetSignaling, code: String) -> Error:
	signaling = sig
	sig.name = "Signaling"
	add_child(sig)
	sig.message.connect(_on_message)
	sig.channel_closed.connect(_on_channel_closed)
	return sig.connect_lobby(code, is_host)


func signaling_id() -> String:
	return signaling.self_id if signaling != null else ""


func close() -> void:
	if _closed:
		return
	_closed = true
	if signaling != null:
		if signaling.is_ready():
			signaling.send(NetSignaling.EVERYONE, "bye", {})
		signaling.close()
	for id: Variant in _conns.keys():
		(_conns[id] as WebRTCPeerConnection).close()
	_conns.clear()
	if peer != null:
		peer.close()


## Host: a client's network peer left; forget its connection (a new hello from it starts over).
func forget_peer(peer_id: int) -> void:
	var sid: String = str(_sid_of.get(peer_id, ""))
	_sid_of.erase(peer_id)
	_conns.erase(peer_id)
	if sid != "":
		_peer_of_sid.erase(sid)


func _process(delta: float) -> void:
	if _closed or is_host or _assigned_id != 0 or signaling == null or not signaling.is_ready():
		return
	_hello_t += delta
	if _hello_t >= HELLO_RESEND_S:
		_hello_t = 0.0
		signaling.send(NetSignaling.HOST_ID, "hello", hello_info)


func _on_channel_closed(reason: String) -> void:
	if _closed:
		return
	if not is_host and _assigned_id == 0:
		setup_failed.emit(reason if reason != "" else "Couldn't reach the lobby service.")
	# Once connected, losing the signaling channel doesn't matter: the game runs on the peer connections.


func _on_message(from: String, kind: String, payload: Dictionary) -> void:
	if _closed:
		return
	if is_host:
		_host_message(from, kind, payload)
	elif from == NetSignaling.HOST_ID:
		_client_message(kind, payload)


# ---------------------------------------------------------------- host

func _host_message(from: String, kind: String, payload: Dictionary) -> void:
	match kind:
		"hello":
			var known: int = int(_peer_of_sid.get(from, 0))
			if known != 0:
				signaling.send(from, "hello", {"peer_id": known})   # the answer was lost: say it again
				return
			var id: int = _new_peer_id()
			_peer_of_sid[from] = id
			_sid_of[id] = from
			signaling.send(from, "hello", {"peer_id": id})
			var conn: WebRTCPeerConnection = _new_connection(id, from)
			if conn == null:
				return
			if peer.add_peer(conn, id) != OK:
				forget_peer(id)
				return
			conn.create_offer()
		"answer":
			var c: WebRTCPeerConnection = _conns.get(int(_peer_of_sid.get(from, 0))) as WebRTCPeerConnection
			if c != null:
				c.set_remote_description("answer", str(payload.get("sdp", "")))
		"ice":
			var c2: WebRTCPeerConnection = _conns.get(int(_peer_of_sid.get(from, 0))) as WebRTCPeerConnection
			if c2 != null:
				c2.add_ice_candidate(str(payload.get("m", "")), int(payload.get("i", 0)), str(payload.get("n", "")))
		"bye":
			var id2: int = int(_peer_of_sid.get(from, 0))
			if id2 != 0 and peer.has_peer(id2):
				var st: Dictionary = peer.get_peer(id2)
				if not bool(st.get("connected", false)):
					peer.remove_peer(id2)   # it gave up before the channels opened
			if id2 != 0 and not peer.has_peer(id2):
				forget_peer(id2)


func _new_peer_id() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var id: int = rng.randi_range(2, 2147483647)
	while _conns.has(id):
		id = rng.randi_range(2, 2147483647)
	return id


# ---------------------------------------------------------------- client

func _client_message(kind: String, payload: Dictionary) -> void:
	match kind:
		"hello":
			var id: int = int(payload.get("peer_id", 0))
			if id < 2 or _assigned_id != 0:
				return
			_assigned_id = id
			if peer.create_client(id, CHANNELS) != OK:
				setup_failed.emit("Couldn't start the connection.")
				return
			var conn: WebRTCPeerConnection = _new_connection(1, NetSignaling.HOST_ID)
			if conn == null or peer.add_peer(conn, 1) != OK:
				setup_failed.emit("Couldn't start the connection.")
				return
			client_peer_ready.emit(peer)
			for m: Array in _pending:
				_client_message(str(m[0]), m[1] as Dictionary)
			_pending.clear()
		"offer":
			var c: WebRTCPeerConnection = _conns.get(1) as WebRTCPeerConnection
			if c == null:
				_pending.append([kind, payload])
				return
			c.set_remote_description("offer", str(payload.get("sdp", "")))
		"ice":
			var c2: WebRTCPeerConnection = _conns.get(1) as WebRTCPeerConnection
			if c2 == null:
				_pending.append([kind, payload])
				return
			c2.add_ice_candidate(str(payload.get("m", "")), int(payload.get("i", 0)), str(payload.get("n", "")))
		"bye":
			host_gone.emit("The host left the match.")


# ---------------------------------------------------------------- both

func _new_connection(peer_id: int, sid: String) -> WebRTCPeerConnection:
	var conn: WebRTCPeerConnection = WebRTCPeerConnection.new()
	if conn.initialize(ice) != OK:
		setup_failed.emit("WebRTC isn't available in this build.")
		return null
	conn.session_description_created.connect(_on_sdp.bind(peer_id, sid))
	conn.ice_candidate_created.connect(_on_ice.bind(sid))
	_conns[peer_id] = conn
	_sid_of[peer_id] = sid
	return conn


func _on_sdp(type: String, sdp: String, peer_id: int, sid: String) -> void:
	var conn: WebRTCPeerConnection = _conns.get(peer_id) as WebRTCPeerConnection
	if conn == null or _closed:
		return
	conn.set_local_description(type, sdp)
	signaling.send(sid, type, {"sdp": sdp})


func _on_ice(media: String, index: int, cand: String, sid: String) -> void:
	if not _closed:
		signaling.send(sid, "ice", {"m": media, "i": index, "n": cand})
