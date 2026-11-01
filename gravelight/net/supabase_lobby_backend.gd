class_name SupabaseLobbyBackend
extends Node
## LobbyService's backend over Supabase REST (T-138; schema: supabase/migrations/0001_lobbies.sql). Every call is
## one HTTPRequest with the public anon key in `apikey` + `Authorization: Bearer`; the table's RLS and the
## SECURITY DEFINER RPCs decide what that key may do. No service-role key exists anywhere in the game.
##
## request(fn, args, cb): fn is "create" | "list" | "get" | "join" | "update" | "close" | "sweep" (the same names
## as MockLobbyBackend.call_fn); cb(ok: bool, result: Variant, error: String). Errors come back as the short keys
## the SQL raises (lobby_not_found, lobby_full, lobby_closed, rate_limited, one_open_lobby) or "duplicate" (code
## taken), "network" / "http_<code>" otherwise.

const TIMEOUT_S: float = 12.0
const SELECT: String = "code,map_id,is_public,host_name,players,fill_bots,status,max_players,created_at,heartbeat_at"

var url: String = ""
var anon_key: String = ""


func _init(supabase_url: String = "", key: String = "") -> void:
	url = supabase_url.strip_edges().trim_suffix("/")
	anon_key = key


func is_configured() -> bool:
	return url != "" and anon_key != ""


func request(fn: String, args: Dictionary, cb: Callable) -> void:
	match fn:
		"create":
			var row: Dictionary = (args.get("row", {}) as Dictionary).duplicate(true)
			row["host_token"] = str(args.get("host_token", ""))
			_send(HTTPClient.METHOD_POST, "/rest/v1/lobbies", row, ["Prefer: return=minimal"], func(ok: bool, _r: Variant, e: String) -> void:
				var pub: Dictionary = (args.get("row", {}) as Dictionary).duplicate(true)
				pub["status"] = "open"
				cb.call(ok, pub if ok else null, e))
		"list":
			_send(HTTPClient.METHOD_GET, "/rest/v1/lobbies?select=%s&status=eq.open&order=created_at.desc&limit=50" % SELECT, null, [], cb)
		"get":
			_rpc("lobby_get", {"code": str(args.get("code", ""))}, cb)
		"join":
			_rpc("lobby_join", {"code": str(args.get("code", "")), "player": args.get("player", {})}, cb)
		"update":
			_rpc("lobby_update", {"code": str(args.get("code", "")), "host_token": str(args.get("host_token", "")),
				"patch": args.get("patch", {})}, cb)
		"close":
			_rpc("lobby_close", {"code": str(args.get("code", "")), "host_token": str(args.get("host_token", ""))}, cb)
		"sweep":
			_rpc("lobby_sweep", {}, cb)
		_:
			cb.call(false, null, "unknown_fn")


func _rpc(name: String, body: Dictionary, cb: Callable) -> void:
	_send(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + name, body, [], cb)


## `retries`: a request that got no HTTP answer at all (a cold DNS / TLS start can time out once) is sent again;
## creates never are (an insert that did land would then fail as "one open lobby").
func _send(method: int, path: String, body: Variant, extra: Array, cb: Callable, retries: int = -1) -> void:
	if retries < 0:
		retries = 0 if path == "/rest/v1/lobbies" and method == HTTPClient.METHOD_POST else 1
	if not is_configured():
		cb.call(false, null, "not_configured")
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	var headers: PackedStringArray = ["apikey: " + anon_key, "Authorization: Bearer " + anon_key,
		"Content-Type: application/json", "Accept: application/json"]
	for h: Variant in extra:
		headers.append(str(h))
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray) -> void:
		http.queue_free()
		var text: String = data.get_string_from_utf8()
		if result != HTTPRequest.RESULT_SUCCESS:
			if retries > 0 and is_inside_tree():
				_send(method, path, body, extra, cb, retries - 1)
			else:
				cb.call(false, null, "network")
			return
		if code >= 200 and code < 300:
			var parsed: Variant = NetSignaling.parse_json(text) if text.strip_edges() != "" else null
			cb.call(true, parsed, "")
			return
		cb.call(false, null, error_key(code, text)))
	var err: Error = http.request(url + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		cb.call(false, null, "network")


## The short error key from a PostgREST error reply ({"code", "message", ...}).
static func error_key(http_code: int, text: String) -> String:
	var v: Variant = NetSignaling.parse_json(text) if text.strip_edges() != "" else null
	if v is Dictionary:
		var d: Dictionary = v
		if str(d.get("code", "")) == "23505":
			return MockLobbyBackend.ERR_DUPLICATE
		var msg: String = str(d.get("message", ""))
		for key: String in [MockLobbyBackend.ERR_NOT_FOUND, MockLobbyBackend.ERR_FULL, MockLobbyBackend.ERR_CLOSED,
				MockLobbyBackend.ERR_RATE, MockLobbyBackend.ERR_ONE_OPEN, "server_full"]:
			if msg.begins_with(key):
				return key
	if http_code == 409:
		return MockLobbyBackend.ERR_DUPLICATE
	return "http_%d" % http_code
