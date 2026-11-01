class_name MockLobbyBackend
extends RefCounted
## The lobbies table in memory, with the same rules as `supabase/migrations/0001_lobbies.sql` (T-138): the tests
## and the local smokes run the whole lobby flow against this instead of Supabase. Pure logic, the clock is passed
## in (`now`, unix seconds), so the unit tests can step time.
##
## Rules mirrored from the SQL: code is 6 letters A-Z; map_id 1..40 chars; host_name 1..24; players an array of at
## most max_players (1..4); host_token 16..64 chars and never returned; at most 5 creates a minute per token and 1
## open lobby per token; list = public and not closed; join appends {name, character, ready false, pid 0} to an
## open lobby with room; update / close need the token; sweep deletes rows whose heartbeat is older than
## `expire_s` (120) and closed rows.

const ERR_NOT_FOUND: String = "lobby_not_found"
const ERR_CLOSED: String = "lobby_closed"
const ERR_FULL: String = "lobby_full"
const ERR_RATE: String = "rate_limited"
const ERR_ONE_OPEN: String = "one_open_lobby"
const ERR_DUPLICATE: String = "duplicate"
const ERR_BAD_ROW: String = "bad_row"
const STATUSES: PackedStringArray = ["open", "starting", "playing", "closed"]
const PATCH_KEYS: PackedStringArray = ["map_id", "is_public", "host_name", "players", "fill_bots", "status"]

var rows: Dictionary = {}       # code -> public row
var _tokens: Dictionary = {}    # code -> host_token
var _log: Array = []            # [host_token, t] of every create (rows deleted later still count)
var expire_s: float = 120.0
var rate_per_minute: int = 5


## "" when the row may be stored, else why not (the SQL constraints).
static func validate_row(row: Dictionary) -> String:
	var code: String = str(row.get("code", ""))
	if not is_valid_code(code):
		return "code must be 6 letters A-Z"
	var map_id: String = str(row.get("map_id", ""))
	if map_id.length() < 1 or map_id.length() > 40:
		return "map_id must be 1..40 characters"
	var host_name: String = str(row.get("host_name", ""))
	if host_name.length() < 1 or host_name.length() > 24:
		return "host_name must be 1..24 characters"
	var mp: int = int(row.get("max_players", 4))
	if mp < 1 or mp > 4:
		return "max_players must be 1..4"
	var players: Variant = row.get("players", [])
	if not (players is Array) or (players as Array).size() > mp:
		return "players must be an array of at most max_players"
	if str(row.get("status", "open")) not in STATUSES:
		return "bad status"
	return ""


static func is_valid_code(code: String) -> bool:
	if code.length() != 6:
		return false
	for i: int in code.length():
		var c: int = code.unicode_at(i)
		if c < 65 or c > 90:
			return false
	return true


static func is_valid_token(token: String) -> bool:
	return token.length() >= 16 and token.length() <= 64


## Dispatch by name (the mock server and the in-memory client both use it). Returns {ok, error, result}.
func call_fn(fn: String, args: Dictionary, now: float) -> Dictionary:
	match fn:
		"create":
			return create(args.get("row", {}) as Dictionary, str(args.get("host_token", "")), now)
		"list":
			return {"ok": true, "error": "", "result": list(now)}
		"get":
			var l: Dictionary = get_lobby(str(args.get("code", "")), now)
			return {"ok": true, "error": "", "result": l if not l.is_empty() else null}
		"join":
			return join(str(args.get("code", "")), args.get("player", {}) as Dictionary, now)
		"update":
			return update(str(args.get("code", "")), str(args.get("host_token", "")), args.get("patch", {}) as Dictionary, now)
		"close":
			return {"ok": true, "error": "", "result": close_lobby(str(args.get("code", "")), str(args.get("host_token", "")))}
		"sweep":
			return {"ok": true, "error": "", "result": sweep(now)}
	return {"ok": false, "error": "unknown_fn", "result": null}


func create(row: Dictionary, host_token: String, now: float) -> Dictionary:
	sweep(now)
	var r: Dictionary = row.duplicate(true)
	r["status"] = "open"
	r["created_at"] = now
	r["heartbeat_at"] = now
	r.erase("host_token")
	if not r.has("players"):
		r["players"] = []
	if not r.has("max_players"):
		r["max_players"] = 4
	if not r.has("fill_bots"):
		r["fill_bots"] = false
	if not r.has("is_public"):
		r["is_public"] = true
	var why: String = validate_row(r)
	if why != "" or not is_valid_token(host_token):
		return _err(ERR_BAD_ROW if why != "" else "bad_token")
	var recent: int = 0
	for e: Array in _log:
		if str(e[0]) == host_token and now - float(e[1]) < 60.0:
			recent += 1
	if recent >= rate_per_minute:
		return _err(ERR_RATE)
	for c: Variant in _tokens.keys():
		if str(_tokens[c]) == host_token and str((rows[c] as Dictionary).get("status", "")) != "closed":
			return _err(ERR_ONE_OPEN)
	if rows.has(r["code"]):
		return _err(ERR_DUPLICATE)
	_log.append([host_token, now])
	rows[r["code"]] = r
	_tokens[r["code"]] = host_token
	return {"ok": true, "error": "", "result": r.duplicate(true)}


func list(now: float) -> Array:
	sweep(now)
	var out: Array = []
	for c: Variant in rows.keys():
		var r: Dictionary = rows[c]
		if bool(r.get("is_public", true)) and str(r.get("status", "")) != "closed":
			out.append(r.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["created_at"]) > float(b["created_at"]))
	return out


func get_lobby(code: String, now: float) -> Dictionary:
	var r: Dictionary = rows.get(code.to_upper(), {})
	if r.is_empty() or str(r.get("status", "")) == "closed" or now - float(r.get("heartbeat_at", 0.0)) > expire_s:
		return {}
	return r.duplicate(true)


func join(code: String, player: Dictionary, now: float) -> Dictionary:
	var c: String = code.to_upper()
	var r: Dictionary = rows.get(c, {})
	if r.is_empty() or now - float(r.get("heartbeat_at", 0.0)) > expire_s:
		return _err(ERR_NOT_FOUND)
	if str(r.get("status", "")) != "open":
		return _err(ERR_CLOSED)
	var players: Array = r.get("players", [])
	if players.size() >= int(r.get("max_players", 4)):
		return _err(ERR_FULL)
	players.append({"name": str(player.get("name", "Player")).left(24), "character": str(player.get("character", "")).left(16),
		"ready": false, "pid": 0})
	r["players"] = players
	return {"ok": true, "error": "", "result": r.duplicate(true)}


func update(code: String, host_token: String, patch: Dictionary, now: float) -> Dictionary:
	var c: String = code.to_upper()
	if not rows.has(c) or str(_tokens.get(c, "")) != host_token:
		return _err(ERR_NOT_FOUND)
	var r: Dictionary = rows[c]
	for k: String in PATCH_KEYS:
		if not patch.has(k):
			continue
		var v: Variant = patch[k]
		match k:
			"players":
				if v is Array and (v as Array).size() <= int(r.get("max_players", 4)):
					r["players"] = (v as Array).duplicate(true)
			"status":
				if str(v) in STATUSES:
					r["status"] = str(v)
			"map_id":
				r["map_id"] = str(v).left(40)
			"host_name":
				r["host_name"] = str(v).left(24)
			_:
				r[k] = bool(v)
	r["heartbeat_at"] = now
	return {"ok": true, "error": "", "result": r.duplicate(true)}


func close_lobby(code: String, host_token: String) -> bool:
	var c: String = code.to_upper()
	if not rows.has(c) or str(_tokens.get(c, "")) != host_token:
		return false
	rows.erase(c)
	_tokens.erase(c)
	return true


func sweep(now: float) -> int:
	var n: int = 0
	for c: Variant in rows.keys():
		var r: Dictionary = rows[c]
		if now - float(r.get("heartbeat_at", 0.0)) > expire_s or str(r.get("status", "")) == "closed":
			rows.erase(c)
			_tokens.erase(c)
			n += 1
	var keep: Array = []
	for e: Array in _log:
		if now - float(e[1]) < 600.0:
			keep.append(e)
	_log = keep
	return n


func _err(e: String) -> Dictionary:
	return {"ok": false, "error": e, "result": null}
