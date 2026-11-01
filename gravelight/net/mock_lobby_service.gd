class_name MockLobbyService
extends Node
## LobbyService's test backend (T-138): the same request(fn, args, cb) as SupabaseLobbyBackend, answered by a
## MockLobbyBackend (the SQL's rules in memory). Two modes:
##   in-memory (port 0)  one shared table in this process (unit tests, smoke_lobby); answers on the next frame
##   relay (port > 0)    the table inside a MockSignalServer on 127.0.0.1:<port> (two-process smokes: the host
##                       starts the server, the client's lobby calls reach the same table)
## Selected by online.json "backend": "mock" or the --mock-online[=port] command-line flag.

static var shared: MockLobbyBackend = null
## In-memory mode: seconds added to the clock (tests step time to expire lobbies).
static var time_offset: float = 0.0

var port: int = 0
var _ws: WebSocketPeer = null
var _rid: int = 0
var _pending: Dictionary = {}   # rid -> Callable
var _queue: Array[String] = []


func _init(relay_port: int = 0) -> void:
	port = relay_port


static func table() -> MockLobbyBackend:
	if shared == null:
		shared = MockLobbyBackend.new()
	return shared


static func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func request(fn: String, args: Dictionary, cb: Callable) -> void:
	if port <= 0:
		var r: Dictionary = table().call_fn(fn, args.duplicate(true), now())
		(func() -> void: cb.call(bool(r["ok"]), r["result"], str(r["error"]))).call_deferred()
		return
	_rid += 1
	_pending[_rid] = cb
	var text: String = JSON.stringify({"op": "lobby", "rid": _rid, "fn": fn, "args": args})
	if _ws == null:
		_ws = WebSocketPeer.new()
		_ws.connect_to_url("ws://127.0.0.1:%d/" % port)
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(text)
	else:
		_queue.append(text)


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st: WebSocketPeer.State = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		for q: String in _queue:
			_ws.send_text(q)
		_queue.clear()
		while _ws.get_available_packet_count() > 0:
			var v: Variant = NetSignaling.parse_json(_ws.get_packet().get_string_from_utf8())
			if v is Dictionary and str((v as Dictionary).get("op", "")) == "lobby_reply":
				var d: Dictionary = v
				var rid: int = int(d.get("rid", 0))
				var cb: Callable = _pending.get(rid, Callable())
				_pending.erase(rid)
				if cb.is_valid():
					cb.call(bool(d.get("ok", false)), d.get("result"), str(d.get("error", "")))
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		for rid: Variant in _pending.keys():
			(_pending[rid] as Callable).call(false, null, "network")
		_pending.clear()
		_queue.clear()
