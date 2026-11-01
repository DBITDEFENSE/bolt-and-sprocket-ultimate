class_name MockSignalServer
extends Node
## A tiny in-process WebSocket relay (UPDATE 09 section 2a, T-138) that stands in for Supabase in tests: any
## instance can host it on 127.0.0.1:<port> (the smokes start it in the host instance). It does two jobs:
##   rooms    `{"op": "join", "room": <code>, "id": <id>}` puts a socket in a lobby's room; every later
##            `{"op": "msg", "data": <signaling message>}` goes to every other socket in that room (like a
##            Realtime broadcast with self=false).
##   lobbies  `{"op": "lobby", "rid": n, "fn": "create"|"list"|..., "args": {...}}` runs on a MockLobbyBackend
##            and answers `{"op": "lobby_reply", "rid": n, "ok", "error", "result"}` (MockLobbyService's remote mode).
## Plain ws:// on the loopback address only: nothing leaves the machine, no firewall prompt.

var backend: MockLobbyBackend = MockLobbyBackend.new()
## Seconds added to the wall clock for the backend (tests step time to expire lobbies).
var time_offset: float = 0.0
var _tcp: TCPServer = null
var _peers: Array[Dictionary] = []   # {ws, room, id}
var port: int = 0


func listen(listen_port: int, bind_ip: String = "127.0.0.1") -> Error:
	_tcp = TCPServer.new()
	var err: Error = _tcp.listen(listen_port, bind_ip)
	if err != OK:
		_tcp = null
		return err
	port = listen_port
	process_mode = Node.PROCESS_MODE_ALWAYS
	return OK


func is_listening() -> bool:
	return _tcp != null and _tcp.is_listening()


func stop() -> void:
	for p: Dictionary in _peers:
		(p["ws"] as WebSocketPeer).close()
	_peers.clear()
	if _tcp != null:
		_tcp.stop()
	_tcp = null


func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		var conn: StreamPeerTCP = _tcp.take_connection()
		var ws: WebSocketPeer = WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 18
		ws.outbound_buffer_size = 1 << 18
		if ws.accept_stream(conn) == OK:
			_peers.append({"ws": ws, "room": "", "id": ""})
	var gone: Array[Dictionary] = []
	for p: Dictionary in _peers:
		var ws2: WebSocketPeer = p["ws"]
		ws2.poll()
		var st: WebSocketPeer.State = ws2.get_ready_state()
		if st == WebSocketPeer.STATE_CLOSED:
			gone.append(p)
			continue
		if st != WebSocketPeer.STATE_OPEN:
			continue
		while ws2.get_available_packet_count() > 0:
			_on_text(p, ws2.get_packet().get_string_from_utf8())
	for g: Dictionary in gone:
		_peers.erase(g)


func _on_text(p: Dictionary, text: String) -> void:
	var v: Variant = JSON.parse_string(text)
	if not (v is Dictionary):
		return
	var m: Dictionary = v
	match str(m.get("op", "")):
		"join":
			p["room"] = str(m.get("room", ""))
			p["id"] = str(m.get("id", ""))
		"msg":
			if str(p["room"]) == "":
				return
			var out: String = JSON.stringify({"op": "msg", "data": m.get("data", {})})
			for q: Dictionary in _peers:
				if q != p and str(q["room"]) == str(p["room"]) and (q["ws"] as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN:
					(q["ws"] as WebSocketPeer).send_text(out)
		"lobby":
			var r: Dictionary = backend.call_fn(str(m.get("fn", "")), m.get("args", {}) as Dictionary, now())
			r["op"] = "lobby_reply"
			r["rid"] = m.get("rid", 0)
			(p["ws"] as WebSocketPeer).send_text(JSON.stringify(r))
