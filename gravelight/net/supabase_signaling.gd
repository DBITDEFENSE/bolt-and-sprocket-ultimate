class_name SupabaseSignaling
extends NetSignaling
## Signaling through Supabase Realtime broadcast (UPDATE 09 section 2a, T-138). One websocket to
## `wss://<ref>.supabase.co/realtime/v1/websocket?apikey=<anon>&vsn=1.0.0`, Phoenix channel protocol:
##   join     {"topic": "realtime:lobby:<code>", "event": "phx_join", "payload": {"config": {"broadcast": {"self":
##            false}, ...}, "access_token": <anon>}, "ref", "join_ref"}
##   send     {"topic", "event": "broadcast", "payload": {"type": "broadcast", "event": <kind>, "payload": <msg>}}
##   receive  the same "broadcast" frame from the other members (never our own: self=false)
##   keepalive {"topic": "phoenix", "event": "heartbeat"} every 25 s
## Nothing is stored server side: a broadcast reaches whoever is subscribed at that moment.

const HEARTBEAT_S: float = 25.0
const JOIN_TIMEOUT_S: float = 12.0

var url: String = ""
var anon_key: String = ""
var _ws: WebSocketPeer = null
var _topic: String = ""
var _ref: int = 0
var _join_ref: String = ""
var _joined: bool = false
var _hb_t: float = 0.0
var _join_t: float = 0.0
var _was_open: bool = false
var _closed: bool = false
var _queue: Array[String] = []


func _init(supabase_url: String = "", key: String = "") -> void:
	url = supabase_url
	anon_key = key


static func realtime_url(supabase_url: String, key: String) -> String:
	var base: String = supabase_url.strip_edges().trim_suffix("/")
	base = base.replace("https://", "wss://").replace("http://", "ws://")
	return "%s/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % [base, key.uri_encode()]


func connect_lobby(lobby_code: String, host: bool) -> Error:
	super.connect_lobby(lobby_code, host)
	if url == "" or anon_key == "":
		return ERR_UNCONFIGURED
	_topic = "realtime:lobby:%s" % lobby_code
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	_ws.outbound_buffer_size = 1 << 18
	var err: Error = _ws.connect_to_url(realtime_url(url, anon_key), TLSOptions.client())
	if err != OK:
		_ws = null
		return err
	_join_t = 0.0
	return OK


func is_ready() -> bool:
	return _joined and not _closed


func send(to_peer: String, kind: String, payload: Dictionary) -> void:
	if _closed:
		return
	var frame: Dictionary = {"topic": _topic, "event": "broadcast", "ref": _next_ref(), "join_ref": _join_ref,
		"payload": {"type": "broadcast", "event": kind, "payload": encode(self_id, to_peer, kind, payload)}}
	var text: String = JSON.stringify(frame)
	if _joined:
		_ws.send_text(text)
	else:
		_queue.append(text)


func close() -> void:
	if _closed:
		return
	_closed = true
	if _ws != null:
		if _joined:
			_ws.send_text(JSON.stringify({"topic": _topic, "event": "phx_leave", "payload": {}, "ref": _next_ref(), "join_ref": _join_ref}))
		_ws.close(1000, "bye")
	_joined = false


func _next_ref() -> String:
	_ref += 1
	return str(_ref)


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st: WebSocketPeer.State = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_join_ref = _next_ref()
			_ws.send_text(JSON.stringify({"topic": _topic, "event": "phx_join", "ref": _join_ref, "join_ref": _join_ref,
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": "", "enabled": false},
					"postgres_changes": [], "private": false}, "access_token": anon_key}}))
		while _ws.get_available_packet_count() > 0:
			_on_frame(_ws.get_packet().get_string_from_utf8())
		_hb_t += delta
		if _hb_t >= HEARTBEAT_S:
			_hb_t = 0.0
			_ws.send_text(JSON.stringify({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _next_ref()}))
		if not _joined:
			_join_t += delta
			if _join_t > JOIN_TIMEOUT_S:
				_fail("The lobby service didn't answer.")
	elif st == WebSocketPeer.STATE_CONNECTING:
		_join_t += delta
		if _join_t > JOIN_TIMEOUT_S:
			_fail("Couldn't reach the lobby service.")
	elif st == WebSocketPeer.STATE_CLOSED:
		_fail("" if _closed else "Lost the lobby service (%d)." % _ws.get_close_code())


func _fail(reason: String) -> void:
	var was_closed: bool = _closed
	_closed = true
	_joined = false
	if _ws != null:
		_ws.close()
	_ws = null
	if not was_closed or reason != "":
		channel_closed.emit(reason)


func _on_frame(text: String) -> void:
	var f: Variant = NetSignaling.parse_json(text)
	if not (f is Dictionary):
		return
	var frame: Dictionary = f
	var ev: String = str(frame.get("event", ""))
	var payload: Variant = frame.get("payload", {})
	if str(frame.get("topic", "")) != _topic:
		return
	match ev:
		"phx_reply":
			if str(frame.get("ref", "")) == _join_ref and not _joined:
				if payload is Dictionary and str((payload as Dictionary).get("status", "")) == "ok":
					_joined = true
					for q: String in _queue:
						_ws.send_text(q)
					_queue.clear()
					channel_ready.emit()
				else:
					_fail("The lobby service refused the channel.")
		"broadcast":
			if payload is Dictionary:
				_deliver(decode((payload as Dictionary).get("payload"), self_id))
		"phx_error", "phx_close":
			if not _closed:
				_fail("The lobby channel closed.")
