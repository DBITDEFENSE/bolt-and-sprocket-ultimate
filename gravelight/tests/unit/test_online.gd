extends GutTest
## Online play (UPDATE 09 section 2a/2b, DECISIONS T-138): join codes, lobby row validation, the mock lobby table's
## state machine (the same rules as supabase/migrations/0001_lobbies.sql), Quick Match's pick, rejoin tokens, the
## signaling wire format, the ICE config, error mapping, and the public-key-only rule for online.json.

const T0: float = 1_800_000_000.0
const TOKEN_A: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const TOKEN_B: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func _row(code: String, extra: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"code": code, "map_id": "map00_crossroads", "is_public": true, "host_name": "Hosty",
		"players": [{"name": "Hosty", "character": "dutch", "ready": true, "pid": 1}], "fill_bots": false, "max_players": 4}
	r.merge(extra, true)
	return r


# ---------------------------------------------------------------- join codes

func test_codes_are_six_unambiguous_letters() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 200:
		var c: String = LobbyService.make_code(6, rng)
		assert_eq(c.length(), 6)
		assert_true(LobbyService.is_valid_code(c), c)
		assert_false(c.contains("I") or c.contains("O"), "no I / O in %s" % c)


func test_code_generation_is_seeded() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	assert_eq(LobbyService.make_code(6, a), LobbyService.make_code(6, b))


func test_codes_rarely_repeat() -> void:
	var seen: Dictionary = {}
	for i: int in 500:
		seen[LobbyService.make_code()] = true
	assert_gt(seen.size(), 495, "24^6 codes: 500 draws almost never collide")


func test_typed_codes_are_normalised() -> void:
	assert_eq(LobbyService.normalize_code(" abc-def "), "ABCDEF")
	assert_eq(LobbyService.normalize_code("ab1c2d3ef"), "ABCDEF")
	assert_false(LobbyService.is_valid_code("ABCDE"))
	assert_false(LobbyService.is_valid_code("ABCDEFG"))
	assert_false(LobbyService.is_valid_code("abcdef"), "stored codes are upper case")
	assert_false(LobbyService.is_valid_code("ABC1EF"))


func test_tokens_are_long_and_random() -> void:
	var t: String = LobbyService.make_token()
	assert_eq(t.length(), 32)
	assert_ne(t, LobbyService.make_token())
	assert_true(MockLobbyBackend.is_valid_token(t))


# ---------------------------------------------------------------- lobby row validation (the SQL constraints)

func test_valid_row_passes() -> void:
	assert_eq(LobbyService.validate_lobby(_row("ABCDEF")), "")


func test_bad_rows_are_refused() -> void:
	assert_ne(LobbyService.validate_lobby(_row("ABC")), "", "short code")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"map_id": ""})), "", "empty map")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"host_name": ""})), "", "empty host name")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"host_name": "x".repeat(25)})), "", "host name over 24")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"max_players": 5})), "", "max players over 4")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"players": "nope"})), "", "players not a list")
	var five: Array = []
	for i: int in 5:
		five.append({"name": "p%d" % i})
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"players": five})), "", "more players than slots")
	assert_ne(LobbyService.validate_lobby(_row("ABCDEF", {"status": "party"})), "", "unknown status")


func test_display_names_are_cleaned() -> void:
	assert_eq(Net.clean_name("   "), "Player")
	assert_eq(Net.clean_name("  Dutch  "), "Dutch")
	assert_eq(Net.clean_name("x".repeat(40)).length(), 24)


# ---------------------------------------------------------------- the mock lobby table (state machine)

func test_create_list_get_join() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	var r: Dictionary = b.create(_row("AAAAAA"), TOKEN_A, T0)
	assert_true(bool(r["ok"]), str(r))
	assert_false((r["result"] as Dictionary).has("host_token"), "the token is never returned")
	assert_eq(str((r["result"] as Dictionary)["status"]), "open")
	b.create(_row("BBBBBB", {"is_public": false}), TOKEN_B, T0 + 1.0)
	var listed: Array = b.list(T0 + 2.0)
	assert_eq(listed.size(), 1, "private lobbies aren't listed")
	assert_eq(str((listed[0] as Dictionary)["code"]), "AAAAAA")
	assert_false(b.get_lobby("bbbbbb", T0 + 2.0).is_empty(), "a private lobby is found by its exact code")
	var j: Dictionary = b.join("BBBBBB", {"name": "Clienta", "character": "peg"}, T0 + 3.0)
	assert_true(bool(j["ok"]))
	var players: Array = (j["result"] as Dictionary)["players"]
	assert_eq(players.size(), 2)
	assert_eq(str((players[1] as Dictionary)["name"]), "Clienta")
	assert_false(bool((players[1] as Dictionary)["ready"]), "a joiner starts not ready")


func test_join_errors() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	assert_eq(str(b.join("ZZZZZZ", {}, T0)["error"]), MockLobbyBackend.ERR_NOT_FOUND)
	b.create(_row("AAAAAA", {"max_players": 2}), TOKEN_A, T0)
	assert_true(bool(b.join("AAAAAA", {"name": "two"}, T0)["ok"]))
	assert_eq(str(b.join("AAAAAA", {"name": "three"}, T0)["error"]), MockLobbyBackend.ERR_FULL)
	b.create(_row("CCCCCC"), TOKEN_B, T0)
	b.update("CCCCCC", TOKEN_B, {"status": "playing"}, T0)
	assert_eq(str(b.join("CCCCCC", {}, T0)["error"]), MockLobbyBackend.ERR_CLOSED, "a started match refuses joins")
	assert_false(b.get_lobby("CCCCCC", T0).is_empty(), "but a rejoin can still read it by code")


func test_rate_limit_and_one_open_lobby_per_token() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	assert_true(bool(b.create(_row("AAAAAA"), TOKEN_A, T0)["ok"]))
	assert_eq(str(b.create(_row("AAAAAB"), TOKEN_A, T0 + 1.0)["error"]), MockLobbyBackend.ERR_ONE_OPEN)
	# closing frees the "one open lobby", but the minute's creates still count
	var codes: PackedStringArray = ["AAAAAC", "AAAAAD", "AAAAAE", "AAAAAF"]
	assert_true(b.close_lobby("AAAAAA", TOKEN_A))
	for c: String in codes:
		assert_true(bool(b.create(_row(c), TOKEN_A, T0 + 2.0)["ok"]), c)
		b.close_lobby(c, TOKEN_A)
	assert_eq(str(b.create(_row("AAAAAG"), TOKEN_A, T0 + 3.0)["error"]), MockLobbyBackend.ERR_RATE, "6th create in a minute")
	assert_true(bool(b.create(_row("AAAAAG"), TOKEN_A, T0 + 61.0)["ok"]), "a minute later it's fine again")


func test_duplicate_code_and_bad_token() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	b.create(_row("AAAAAA"), TOKEN_A, T0)
	assert_eq(str(b.create(_row("AAAAAA"), TOKEN_B, T0)["error"]), MockLobbyBackend.ERR_DUPLICATE)
	assert_false(bool(b.create(_row("BBBBBB"), "short", T0)["ok"]), "tokens are 16..64 characters")


func test_update_needs_the_token_and_refreshes_the_heartbeat() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	b.create(_row("AAAAAA"), TOKEN_A, T0)
	assert_eq(str(b.update("AAAAAA", TOKEN_B, {"fill_bots": true}, T0 + 5.0)["error"]), MockLobbyBackend.ERR_NOT_FOUND)
	var u: Dictionary = b.update("AAAAAA", TOKEN_A, {"fill_bots": true, "players": [], "host_token": "evil", "code": "XXXXXX"}, T0 + 100.0)
	assert_true(bool(u["ok"]))
	var row: Dictionary = u["result"]
	assert_true(bool(row["fill_bots"]))
	assert_eq(str(row["code"]), "AAAAAA", "the code can't be patched")
	assert_eq(float(row["heartbeat_at"]), T0 + 100.0)
	assert_eq(b.sweep(T0 + 200.0), 0, "the heartbeat kept it alive")
	assert_false(b.close_lobby("AAAAAA", TOKEN_B), "only the host closes")


func test_lobbies_expire_after_120_s_without_a_heartbeat() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	b.create(_row("AAAAAA"), TOKEN_A, T0)
	assert_eq(b.list(T0 + 119.0).size(), 1)
	assert_eq(b.list(T0 + 121.0).size(), 0, "swept")
	assert_eq(str(b.join("AAAAAA", {}, T0 + 121.0)["error"]), MockLobbyBackend.ERR_NOT_FOUND)
	assert_true(bool(b.create(_row("BBBBBB"), TOKEN_A, T0 + 130.0)["ok"]), "an expired lobby frees its host's slot")


func test_call_fn_dispatch_matches_the_rpcs() -> void:
	var b: MockLobbyBackend = MockLobbyBackend.new()
	assert_true(bool(b.call_fn("create", {"row": _row("AAAAAA"), "host_token": TOKEN_A}, T0)["ok"]))
	assert_eq((b.call_fn("list", {}, T0)["result"] as Array).size(), 1)
	assert_eq(b.call_fn("get", {"code": "QQQQQQ"}, T0)["result"], null)
	assert_true(bool(b.call_fn("join", {"code": "AAAAAA", "player": {"name": "x"}}, T0)["ok"]))
	assert_true(bool(b.call_fn("update", {"code": "AAAAAA", "host_token": TOKEN_A, "patch": {}}, T0)["ok"]))
	assert_eq(int(b.call_fn("sweep", {}, T0 + 500.0)["result"]), 1)
	assert_false(bool(b.call_fn("nope", {}, T0)["ok"]))


func test_mock_service_answers_asynchronously() -> void:
	MockLobbyService.shared = MockLobbyBackend.new()
	var svc: MockLobbyService = MockLobbyService.new(0)
	add_child_autofree(svc)
	var got: Array = []
	svc.request("create", {"row": _row("AAAAAA"), "host_token": TOKEN_A}, func(ok: bool, res: Variant, _e: String) -> void: got.append([ok, res]))
	assert_eq(got.size(), 0, "answers on a later frame, like the network")
	await wait_frames(3)
	assert_eq(got.size(), 1)
	assert_true(bool(got[0][0]))
	MockLobbyService.shared = null


# ---------------------------------------------------------------- quick match

func test_quick_match_picks_the_emptiest_open_public_lobby() -> void:
	var rows: Array = [
		_row("AAAAAA", {"players": [{}, {}, {}]}),
		_row("BBBBBB", {"players": [{}]}),
		_row("CCCCCC", {"players": [], "is_public": false}),
		_row("DDDDDD", {"players": [], "status": "playing"}),
		_row("EEEEEE", {"players": [{}, {}], "max_players": 2}),
		_row("FFFFFF", {"players": [], "map_id": "map01_kaltenbrunn"}),
	]
	assert_eq(str(LobbyService.pick_quick_match(rows)["code"]), "FFFFFF")
	assert_eq(str(LobbyService.pick_quick_match(rows, "map00_crossroads")["code"]), "BBBBBB")
	assert_true(LobbyService.pick_quick_match(rows, "map02_totenhafen").is_empty(), "none: create one")
	assert_true(LobbyService.pick_quick_match([]).is_empty())


func test_map_ids_resolve_to_scenes() -> void:
	assert_eq(LobbyService.map_scene("map00_crossroads"), "res://gravelight/maps/map00_crossroads/map00.tscn")
	assert_eq(LobbyService.map_scene("nowhere"), "")
	assert_eq(LobbyService.map_name("map01_kaltenbrunn"), "Kaltenbrunn")


# ---------------------------------------------------------------- rejoin tokens (host side)

func test_rejoin_token_gets_the_dropped_pid_back_only_within_the_grace() -> void:
	var saved_tokens: Dictionary = Net._tokens.duplicate()
	var saved_dropped: Dictionary = Net._dropped.duplicate()
	Net._tokens = {"tok-2": 2, "tok-3": 3}
	Net._dropped = {2: {"token": "tok-2", "until": Time.get_ticks_msec() + 60000, "bot": true}}
	assert_eq(Net.rejoin_pid("tok-2"), 2, "dropped and inside the grace")
	assert_eq(Net.rejoin_pid("tok-3"), 0, "pid 3 never dropped: no takeover of a live slot")
	assert_eq(Net.rejoin_pid("forged"), 0)
	assert_eq(Net.rejoin_pid(""), 0)
	Net._dropped.erase(2)
	assert_eq(Net.rejoin_pid("tok-2"), 0, "after the grace the token is worthless")
	Net._tokens = saved_tokens
	Net._dropped = saved_dropped


# ---------------------------------------------------------------- signaling wire format

func test_signaling_round_trip() -> void:
	var text: String = NetSignaling.encode_text("host", "abc", "offer", {"sdp": "v=0..."})
	var d: Dictionary = NetSignaling.decode(text, "abc")
	assert_eq(str(d["from"]), "host")
	assert_eq(str(d["kind"]), "offer")
	assert_eq(str((d["payload"] as Dictionary)["sdp"]), "v=0...")
	assert_false(NetSignaling.decode(NetSignaling.encode("abc", "*", "hello", {}), "host").is_empty(), "broadcast to everyone")


func test_signaling_drops_what_isnt_ours() -> void:
	assert_true(NetSignaling.decode(NetSignaling.encode("host", "xyz", "offer", {}), "abc").is_empty(), "someone else's")
	assert_true(NetSignaling.decode(NetSignaling.encode("abc", "*", "hello", {}), "abc").is_empty(), "our own echo")
	assert_true(NetSignaling.decode(NetSignaling.encode("host", "abc", "evil", {}), "abc").is_empty(), "unknown kind")
	assert_true(NetSignaling.decode({"from": "host", "to": "abc", "kind": "ice"}, "abc").is_empty(), "no payload")
	assert_true(NetSignaling.decode("not json", "abc").is_empty())
	assert_true(NetSignaling.decode(42, "abc").is_empty())
	var huge: String = NetSignaling.encode_text("host", "abc", "offer", {"sdp": "x".repeat(40000)})
	assert_true(NetSignaling.decode(huge, "abc").is_empty(), "oversized")


func test_signaling_ids() -> void:
	var a: String = NetSignaling.random_id(12)
	assert_eq(a.length(), 12)
	assert_ne(a, NetSignaling.HOST_ID)
	assert_ne(a, NetSignaling.random_id(12))


func test_realtime_url() -> void:
	assert_eq(SupabaseSignaling.realtime_url("https://ref.supabase.co/", "k"), "wss://ref.supabase.co/realtime/v1/websocket?apikey=k&vsn=1.0.0")


# ---------------------------------------------------------------- ICE, errors, config

func test_ice_config_stun_and_optional_turn() -> void:
	var c: Dictionary = RtcTransport.ice_config({"stun": ["stun:a:1"], "turn": {"urls": [], "username": "", "credential": ""}})
	assert_eq((c["iceServers"] as Array).size(), 1, "no TURN when its urls are empty")
	var t: Dictionary = RtcTransport.ice_config({"stun": ["stun:a:1"], "turn": {"urls": ["turn:t:3478"], "username": "u", "credential": "p"}})
	assert_eq((t["iceServers"] as Array).size(), 2)
	assert_eq(str(((t["iceServers"] as Array)[1] as Dictionary)["username"]), "u")
	assert_eq((RtcTransport.ice_config({})["iceServers"] as Array).size(), 0)


func test_backend_error_keys() -> void:
	assert_eq(SupabaseLobbyBackend.error_key(400, '{"code":"P0001","message":"lobby_full"}'), MockLobbyBackend.ERR_FULL)
	assert_eq(SupabaseLobbyBackend.error_key(400, '{"code":"P0001","message":"rate_limited: at most 5 lobbies a minute"}'), MockLobbyBackend.ERR_RATE)
	assert_eq(SupabaseLobbyBackend.error_key(409, '{"code":"23505","message":"duplicate key"}'), MockLobbyBackend.ERR_DUPLICATE)
	assert_eq(SupabaseLobbyBackend.error_key(500, ""), "http_500")
	assert_string_contains(LobbyService.friendly(MockLobbyBackend.ERR_FULL), "full")
	assert_string_contains(LobbyService.friendly("network"), "connection")


func test_online_json_has_only_public_keys() -> void:
	var o: Dictionary = GLData.load_json("res://data/gravelight/online.json")
	for k: String in ["supabase_url", "supabase_anon_key", "stun", "turn", "lobby_heartbeat_s", "lobby_expire_s",
			"join_code_len", "rejoin_grace_s", "connect_timeout_s", "max_players"]:
		assert_true(o.has(k), k)
	assert_eq(int(o["lobby_expire_s"]), 120)
	assert_eq(int(o["rejoin_grace_s"]), 60)
	assert_eq(int(o["join_code_len"]), 6)
	var parts: PackedStringArray = str(o["supabase_anon_key"]).split(".")
	assert_eq(parts.size(), 3, "a JWT")
	var b64: String = parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var claims: Variant = JSON.parse_string(Marshalls.base64_to_raw(b64).get_string_from_utf8())
	assert_true(claims is Dictionary)
	assert_eq(str((claims as Dictionary).get("role", "")), "anon", "never a service-role key in the repo")
	var text: String = FileAccess.get_file_as_string("res://data/gravelight/online.json")
	assert_false(text.contains("service_role"))
	assert_false(text.contains("sb_secret_"))


func test_webrtc_is_available_on_desktop_builds() -> void:
	if not FileAccess.file_exists("res://addons/webrtc/webrtc.gdextension"):
		pending("addons/webrtc not present")
		return
	assert_true(RtcTransport.available(), "the webrtc-native GDExtension loads (headless too)")


# ---------------------------------------------------------------- the lobby screens build (C7 restyles them later)

func test_lobby_screens_build_every_page() -> void:
	var was_kind: String = Lobbies.backend_kind
	MockLobbyService.shared = MockLobbyBackend.new()
	Lobbies.use_mock(0)
	var m: MenuLobby = MenuLobby.new()
	add_child_autofree(m)
	await wait_frames(2)
	for page: String in ["name", "home", "create", "browse", "join", "lan"]:
		m._go(page)
		await wait_frames(1)
		assert_gt(m.content.get_child_count(), 0, "page %s has content" % page)
	m._go("home")
	await wait_frames(1)
	Lobbies.stop_browsing()
	MockLobbyService.shared = null
	if was_kind == "supabase":
		Lobbies.use_supabase()
