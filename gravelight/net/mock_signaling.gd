class_name MockSignaling
extends NetSignaling
## Signaling through the local relay `MockSignalServer` (T-138): the same messages as SupabaseSignaling, over
## ws://127.0.0.1:<port>. Two headless desktop instances find each other this way in the smokes, no internet.

const CONNECT_TIMEOUT_S: float = 8.0

var port: int = 0
var host_ip: String = "127.0.0.1"
var _ws: WebSocketPeer = null
var _open: bool = false
var _closed: bool = false
var _t: float = 0.0
var _queue: Array[String] = []


func _init(relay_port: int = 0) -> void:
	port = relay_port


func connect_lobby(lobby_code: String, host: bool) -> Error:
	super.connect_lobby(lobby_code, host)
	if port <= 0:
		return ERR_UNCONFIGURED
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	_ws.outbound_buffer_size = 1 << 18
	return _ws.connect_to_url("ws://%s:%d/" % [host_ip, port])


func is_ready() -> bool:
	return _open and not _closed


func send(to_peer: String, kind: String, payload: Dictionary) -> void:
	if _closed:
		return
	var text: String = JSON.stringify({"op": "msg", "data": encode(self_id, to_peer, kind, payload)})
	if _open:
		_ws.send_text(text)
	else:
		_queue.append(text)


func close() -> void:
	if _closed:
		return
	_closed = true
	_open = false
	if _ws != null:
		_ws.close()


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st: WebSocketPeer.State = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _open and not _closed:
			_open = true
			_ws.send_text(JSON.stringify({"op": "join", "room": code, "id": self_id}))
			for q: String in _queue:
				_ws.send_text(q)
			_queue.clear()
			channel_ready.emit()
		while _ws.get_available_packet_count() > 0:
			var v: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if v is Dictionary and str((v as Dictionary).get("op", "")) == "msg":
				_deliver(decode((v as Dictionary).get("data"), self_id))
	elif st == WebSocketPeer.STATE_CONNECTING:
		_t += delta
		if _t > CONNECT_TIMEOUT_S:
			_closed = true
			_ws.close()
			_ws = null
			channel_closed.emit("Couldn't reach the local lobby relay.")
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		var was: bool = _closed
		_closed = true
		_open = false
		if not was:
			channel_closed.emit("Lost the local lobby relay.")
