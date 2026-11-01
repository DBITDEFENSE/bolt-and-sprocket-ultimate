extends SceneTree
## Live check of the Supabase lobbies (T-138): one round-trip against the real project in online.json with the
## public anon key only: sweep, create, list, get by code, join, heartbeat (lobby_update), a wrong-token update
## (must fail), reading host_token (must fail), insert spam (rate limit / one open lobby), close, get (gone).
## Also the same flow through SupabaseLobbyBackend (the game's own client code).
## Usage: godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/online_live_check.gd
## Leaves nothing behind (the test lobby is closed at the end). Prints one RESULT line.

var _url: String = ""
var _key: String = ""
var _fails: PackedStringArray = []


func _code() -> String:
	var out: String = ""
	for i: int in 6:
		out += "ABCDEFGHJKLMNPQRSTUVWXYZ"[randi() % 24]
	return out


func _token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _initialize() -> void:
	_run.call_deferred()


func _http(method: int, path: String, body: Variant = null, extra: PackedStringArray = []) -> Array:
	var r: Array = await _http_once(method, path, body, extra)
	if int(r[0]) == 0:
		print("[live]   (no HTTP answer: %s; retrying once)" % str(r[1]))
		r = await _http_once(method, path, body, extra)
	return r


func _http_once(method: int, path: String, body: Variant, extra: PackedStringArray) -> Array:
	var h: HTTPRequest = HTTPRequest.new()
	h.timeout = 15.0
	root.add_child(h)
	var headers: PackedStringArray = ["apikey: " + _key, "Authorization: Bearer " + _key, "Content-Type: application/json"]
	headers.append_array(extra)
	var err: Error = h.request(_url + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		h.queue_free()
		return [0, "request error %s" % error_string(err)]
	var res: Array = await h.request_completed
	h.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return [0, "result %d" % int(res[0])]
	return [int(res[1]), (res[3] as PackedByteArray).get_string_from_utf8()]


func _step(label: String, r: Array, want_ok: bool) -> Variant:
	var code: int = r[0]
	var ok: bool = code >= 200 and code < 300
	print("[live] %-34s HTTP %d  %s" % [label, code, str(r[1]).left(160)])
	if ok != want_ok:
		_fails.append("%s: HTTP %d %s" % [label, code, str(r[1]).left(120)])
	var j: JSON = JSON.new()
	return j.data if j.parse(str(r[1])) == OK else null


func _run() -> void:
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/online.json"))
	_url = str(o["supabase_url"]).trim_suffix("/")
	_key = str(o["supabase_anon_key"])
	var code: String = _code()
	var token: String = _token()
	var row: Dictionary = {"code": code, "map_id": "map00_crossroads", "is_public": true, "host_name": "LiveCheck",
		"players": [{"name": "LiveCheck", "character": "dutch", "ready": true, "pid": 1}], "fill_bots": false,
		"max_players": 2, "host_token": token}
	_step("rpc lobby_sweep", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_sweep", {}), true)
	_step("insert lobby %s" % code, await _http(HTTPClient.METHOD_POST, "/rest/v1/lobbies", row, ["Prefer: return=minimal"]), true)
	var listed: Variant = _step("list public lobbies", await _http(HTTPClient.METHOD_GET,
		"/rest/v1/lobbies?select=code,map_id,players,status,heartbeat_at&status=eq.open"), true)
	var found: bool = false
	if listed is Array:
		for r: Variant in listed:
			found = found or str((r as Dictionary).get("code", "")) == code
	if not found:
		_fails.append("the new lobby isn't in the list")
	print("[live]   listed: %s" % str(found))
	var got: Variant = _step("rpc lobby_get(code)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_get", {"code": code.to_lower()}), true)
	if not (got is Dictionary) or (got as Dictionary).has("host_token"):
		_fails.append("lobby_get returned %s" % str(got))
	var joined: Variant = _step("rpc lobby_join(code, player)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_join",
		{"code": code, "player": {"name": "LiveClient", "character": "peg"}}), true)
	if not (joined is Dictionary) or ((joined as Dictionary).get("players", []) as Array).size() != 2:
		_fails.append("join didn't append the player: %s" % str(joined))
	_step("rpc lobby_join (full lobby)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_join",
		{"code": code, "player": {"name": "Third"}}), false)
	var hb: Variant = _step("rpc lobby_update (heartbeat)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_update",
		{"code": code, "host_token": token, "patch": {"players": [row["players"][0]], "fill_bots": true}}), true)
	if not (hb is Dictionary) or not bool((hb as Dictionary).get("fill_bots", false)):
		_fails.append("the update didn't apply: %s" % str(hb))
	_step("rpc lobby_update (wrong token)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_update",
		{"code": code, "host_token": "x".repeat(32), "patch": {"status": "closed"}}), false)
	_step("select host_token (must fail)", await _http(HTTPClient.METHOD_GET, "/rest/v1/lobbies?select=host_token&code=eq." + code), false)
	_step("direct update (must fail)", await _http(HTTPClient.METHOD_PATCH, "/rest/v1/lobbies?code=eq." + code, {"host_name": "Evil"},
		["Prefer: return=representation"]), false)   # no UPDATE grant for anon: 401 permission denied
	var after: Variant = _step("rpc lobby_get (unchanged?)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_get", {"code": code}), true)
	if after is Dictionary and str((after as Dictionary).get("host_name", "")) != "LiveCheck":
		_fails.append("a direct update changed the row")
	var row2: Dictionary = row.duplicate(true)
	row2["code"] = _code()
	_step("2nd open lobby, same token", await _http(HTTPClient.METHOD_POST, "/rest/v1/lobbies", row2, ["Prefer: return=minimal"]), false)
	var closed: Variant = _step("rpc lobby_close", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_close", {"code": code, "host_token": token}), true)
	if closed != true:
		_fails.append("close returned %s" % str(closed))
	var gone: Variant = _step("rpc lobby_get (after close)", await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/lobby_get", {"code": code}), true)
	if gone != null:
		_fails.append("the closed lobby is still there")

	# the game's own client code, through SupabaseLobbyBackend
	var be: SupabaseLobbyBackend = SupabaseLobbyBackend.new(_url, _key)
	root.add_child(be)
	var code2: String = _code()
	var token2: String = _token()
	var row3: Dictionary = row.duplicate(true)
	row3.erase("host_token")
	row3["code"] = code2
	for fn: Array in [["create", {"row": row3, "host_token": token2}, true], ["list", {}, true], ["get", {"code": code2}, true],
			["join", {"code": code2, "player": {"name": "B"}}, true], ["join", {"code": code2, "player": {"name": "C"}}, false],
			["update", {"code": code2, "host_token": token2, "patch": {}}, true], ["close", {"code": code2, "host_token": token2}, true]]:
		var done: Array = []
		be.request(str(fn[0]), fn[1] as Dictionary, func(ok: bool, res: Variant, e: String) -> void: done.append([ok, res, e]))
		while done.is_empty():
			await process_frame
		print("[live] backend %-8s ok=%s error=%s" % [fn[0], str(done[0][0]), str(done[0][2])])
		if bool(done[0][0]) != bool(fn[2]):
			_fails.append("backend %s: ok=%s error=%s" % [fn[0], str(done[0][0]), str(done[0][2])])
		if str(fn[0]) == "join" and not bool(fn[2]) and str(done[0][2]) != MockLobbyBackend.ERR_FULL:
			_fails.append("backend join on a full lobby said '%s', not lobby_full" % str(done[0][2]))
	for f: String in _fails:
		print("[live] FAIL: " + f)
	print("[live] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)
