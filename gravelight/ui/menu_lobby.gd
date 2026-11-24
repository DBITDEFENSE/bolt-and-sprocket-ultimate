class_name MenuLobby
extends MenuScreen
## The co-op lobby screens (UPDATE 09 section 2b, C3/C7, T-138). Online play goes through the `Lobbies` service
## (Supabase lobbies + WebRTC, no ports opened); the old direct-IP host / join is the "LAN (direct IP)" page.
##
## Pages (each is one `_build_*` method so the menu restyle can reuse the logic):
##   name      the display name, asked once (kept in the profile)
##   home      Quick Match, Create Lobby, Browse, Join by code, Rejoin (after a drop), LAN, change name
##   create    map, public / private, players (2-4), bots fill empty slots
##   browse    the public lobbies (refreshed every 5 s), Join on each
##   join      type a 6-letter code
##   busy      creating / searching / connecting (Cancel)
##   room      the squad (each survivor once), ready check, the host's settings and Start; the join code
##   lan       direct IP host / join (ENet), then the same room
## Controller-navigable like every MenuKit page.

## UPDATE 09 section 8 (T-145), dev launcher only. `--open=online` (or `open_request = "online"`, set in-process)
## makes the main menu open this screen at once; `--auto-host` creates a public lobby as soon as the screen is up and
## `--auto-join` goes to Browse. Each fires once per process, and only when the flag is given: normal play, the smokes
## and the tests never pass them.
static var open_request: String = ""
static var _auto_done: bool = false

var _page: String = "home"
var _status: String = ""
var _code_field: LineEdit
var _name_field: LineEdit
var _ip: LineEdit
var _create_map: String = LobbyService.DEFAULT_MAP
var _create_public: bool = true
var _create_slots: int = 4
var _create_bots: bool = true
var _dirty: bool = false


## "online" when the lobby should open at once: the in-process request or `--open=online` in `args`.
static func open_mode(args: Array = []) -> String:
	if open_request != "":
		return open_request
	return "online" if args.has("--open=online") else ""


static func consume_open_request() -> bool:
	var m: String = open_mode(Array(OS.get_cmdline_user_args()) + Array(OS.get_cmdline_args()))
	open_request = ""
	return m == "online"


## "host", "join" or "" from the launch flags (`--auto-host` / `--auto-join`).
static func auto_mode(args: Array) -> String:
	if args.has("--auto-host"):
		return "host"
	if args.has("--auto-join"):
		return "join"
	return ""


func _init() -> void:
	super._init("Co-op")   # T-144: PLAY > ONLINE, T-267: reads CO-OP (LAN stays a page inside it)
	subtitle = "Up to four players. Host a game or join one: online with a code, or on your own network."


func _ready() -> void:
	if Net.last_error != "":
		_status = Net.last_error
		Net.last_error = ""
	if Lobbies.last_reason != "" and Lobbies.last_reason != LobbyService.LEFT_BY_USER:
		_status = Lobbies.last_reason
	Net.reopen_lobby = false
	super._ready()
	for pair: Array in _links():
		(pair[0] as Signal).connect(pair[1] as Callable)
	if not _auto_done:
		var auto: String = auto_mode(Array(OS.get_cmdline_user_args()) + Array(OS.get_cmdline_args()))
		if auto != "":
			_auto_done = true
			_run_auto.call_deferred(auto)


func _run_auto(auto: String) -> void:
	if not Lobbies.has_display_name():
		Lobbies.set_display_name("Host test" if auto == "host" else "Guest test")
	if auto == "host":
		_create()
	else:
		_go("browse")


func _links() -> Array:
	return [[Net.roster_changed, _queue_rebuild], [Net.join_failed, _on_failed], [Net.disconnected, _on_disconnected],
		[Lobbies.changed, _queue_rebuild], [Lobbies.lobbies_changed, _on_list], [Lobbies.joined, _on_joined],
		[Lobbies.failed, _on_failed], [Lobbies.left, _on_left], [Net.joined, _queue_rebuild]]


func _exit_tree() -> void:
	Lobbies.stop_browsing()
	for pair: Array in _links():
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1] as Callable):
			sig.disconnect(pair[1] as Callable)


func build() -> void:
	if Net.is_online() and not (Net.is_client() and Net.local_player_id() == 0):
		_page = "room"
	elif Lobbies.state in [LobbyService.State.CREATING, LobbyService.State.SEARCHING, LobbyService.State.JOINING] \
			or (Net.is_client() and Net.local_player_id() == 0):
		_page = "busy"
	elif _page == "room" or _page == "busy":
		_page = "home"
	if not Lobbies.has_display_name() and _page == "home":
		_page = "name"
	if _status != "":
		content.add_child(MenuKit.para(_status, 20, MenuKit.INK.lightened(0.35)))
	match _page:
		"name":
			_build_name()
		"create":
			_build_create()
		"browse":
			_build_browse()
		"join":
			_build_join()
		"busy":
			_build_busy()
		"room":
			_build_room()
		"lan":
			_build_lan()
		_:
			_build_home()


## T-264: MenuScreen.rebuild keeps the focus's place while the lobby page is the same (the list refreshes every 5 s).
func page_key() -> String:
	return _page


func _go(page: String) -> void:
	_page = page
	_status = ""
	if page == "browse":
		Lobbies.start_browsing()
	else:
		Lobbies.stop_browsing()
	rebuild()


# ================================================================== pages

func _build_name() -> void:
	content.add_child(MenuKit.para("What should the others call you? (No account: just a name, kept on this PC.)", 20, MenuKit.PAPER))
	_name_field = _line_edit(Lobbies.display_name() if Lobbies.has_display_name() else "", "your name", 24)
	_name_field.text_submitted.connect(func(_t: String) -> void: _save_name())
	content.add_child(MenuKit.row("Display name", _name_field, 220))
	if MenuKit.wants_pad_keys():   # T-264: a controller types the name here (or OK with it empty: "Player")
		content.add_child(MenuKit.pad_keys(_name_field, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
	content.add_child(MenuKit.button("OK", _save_name, 26, "ui_confirm"))
	if Lobbies.has_display_name():
		content.add_child(MenuKit.button("Back", _go.bind("home"), 22, "ui_back"))


func _build_home() -> void:
	content.add_child(MenuKit.para("Play with friends anywhere, nothing to set up. Host a game and share its 6-letter code, or join a public game. "
		+ "You are \"%s\"." % Lobbies.display_name(), 18, MenuKit.DIM))
	if Lobbies.can_rejoin():
		content.add_child(MenuKit.button("Rejoin the match (%s, %d s left)" % [Lobbies.rejoin_code(), int(Lobbies.rejoin_seconds_left())],
			_rejoin, 26, "ui_confirm"))
	content.add_child(MenuKit.button("Quick Match", _quick, 26, "ui_confirm"))
	content.add_child(MenuKit.button("Host a Game", _go.bind("create"), 26))
	content.add_child(MenuKit.button("Find a Game", _go.bind("browse"), 26))
	content.add_child(MenuKit.button("Join with a Code", _go.bind("join"), 26))
	content.add_child(MenuKit.button("Local Network (LAN)", _go.bind("lan"), 22))
	content.add_child(MenuKit.button("Change name", _go.bind("name"), 20))
	if Lobbies.backend_kind == "mock":
		content.add_child(MenuKit.para("(local test lobbies: the mock lobby service on port %d)" % Lobbies.mock_port, 16, MenuKit.DIM))


func _build_create() -> void:
	var names: PackedStringArray = []
	var ids: Array[String] = []
	var sel: int = 0
	for m: Array in MenuCharacter.MAPS:
		if not ProfileSave.is_map_unlocked(StringName(m[0])) or str(m[2]) == "":
			continue
		if str(m[0]) == _create_map:
			sel = ids.size()
		ids.append(str(m[0]))
		names.append(str(m[1]))
	if ids.is_empty():
		ids.append(LobbyService.DEFAULT_MAP)
		names.append(LobbyService.map_name(LobbyService.DEFAULT_MAP))
	_create_map = ids[sel]
	content.add_child(MenuKit.row("Map", MenuKit.options(names, sel, func(i: int) -> void: _create_map = ids[i]), 220))
	content.add_child(MenuKit.row("Players", MenuKit.options(PackedStringArray(["2", "3", "4"]), _create_slots - 2,
		func(i: int) -> void: _create_slots = i + 2), 220))
	content.add_child(MenuKit.check("Public (anyone can find it in Find a Game and Quick Match)", _create_public, func(on: bool) -> void: _create_public = on))
	content.add_child(MenuKit.check("Bots fill empty slots", _create_bots, func(on: bool) -> void: _create_bots = on))
	content.add_child(MenuKit.button("Host", _create, 26, "ui_confirm"))
	content.add_child(MenuKit.button("Back", _go.bind("home"), 22, "ui_back"))


func _build_browse() -> void:
	content.add_child(MenuKit.para("Public games you can join (the list refreshes every 5 s).", 18, MenuKit.DIM))
	var shown: int = 0
	for v: Variant in Lobbies.lobbies:
		var r: Dictionary = v
		if str(r.get("status", "open")) != "open":
			continue
		var n: int = (r.get("players", []) as Array).size()
		var mp: int = int(r.get("max_players", 4))
		var text: String = "%s   ·   %s   ·   %d/%d%s" % [str(r.get("host_name", "?")), LobbyService.map_name(str(r.get("map_id", ""))),
			n, mp, "   ·   bots" if bool(r.get("fill_bots", false)) else ""]
		var b: Button = MenuKit.button(text, Lobbies.join.bind(str(r.get("code", ""))), 22, "ui_confirm")
		b.disabled = n >= mp
		content.add_child(b)
		shown += 1
	if shown == 0:
		content.add_child(MenuKit.para("No open games right now. Host one, or try Quick Match.", 20, MenuKit.PAPER))
	content.add_child(MenuKit.button("Refresh", Lobbies.refresh, 20))
	content.add_child(MenuKit.button("Back", _go.bind("home"), 22, "ui_back"))


func _build_join() -> void:
	content.add_child(MenuKit.para("Type the 6-letter code the host sees on their screen.", 18, MenuKit.DIM))
	_code_field = _line_edit("", "e.g. KXMRTA", 6)
	_code_field.text_submitted.connect(func(_t: String) -> void: _join_code())
	content.add_child(MenuKit.row("Join code", _code_field, 220))
	if MenuKit.wants_pad_keys():   # T-264: the code's own letters (no I / O), typed with a controller
		content.add_child(MenuKit.pad_keys(_code_field, LobbyService.CODE_ALPHABET, 12))
	content.add_child(MenuKit.button("Join", _join_code, 26, "ui_confirm"))
	content.add_child(MenuKit.button("Back", _go.bind("home"), 22, "ui_back"))


func _build_busy() -> void:
	var what: String = "Connecting..."
	match Lobbies.state:
		LobbyService.State.CREATING:
			what = "Setting up your game..."
		LobbyService.State.SEARCHING:
			what = "Looking for a game..."
	content.add_child(MenuKit.para(what, 24, MenuKit.GOLD))
	content.add_child(MenuKit.button("Cancel", _cancel, 22, "ui_back"))


## The squad, the survivor pick (each once), the ready check; the host's settings and Start. Both transports.
func _build_room() -> void:
	var host: bool = Net.is_host()
	var online: bool = Net.is_webrtc()
	var head: String = ""
	if online:
		var code: String = str(Net.lobby.get("code", Lobbies.current.get("code", "")))
		head = "Join code: %s   ·   %s   ·   %s" % [code, LobbyService.map_name(str(Net.lobby.get("map_id", LobbyService.DEFAULT_MAP))),
			"public" if bool(Net.lobby.get("is_public", true)) else "private"]
	elif host:
		head = "You're hosting (LAN)."
		var addrs: PackedStringArray = _lan_addresses()
		if not addrs.is_empty():
			head += "  Others join with: %s  (port %d)" % [", ".join(addrs), _port()]
	else:
		head = "Joined. The host picks the map."
	content.add_child(MenuKit.para(head, 22, MenuKit.GOLD))
	_build_squad()
	_build_survivor_pick()
	if not host:
		var me: Dictionary = Net.roster.get(Net.local_player_id(), {})
		var ready_now: bool = bool(me.get("ready", false))
		content.add_child(MenuKit.button("Not ready" if ready_now else "Ready", Lobbies.set_ready.bind(not ready_now), 26, "ui_confirm"))
	else:
		_build_host_controls(online)
	content.add_child(MenuKit.button("Leave the game" if not host else "Close the game", _leave, 22, "ui_back"))


func _build_squad() -> void:
	for pid: int in range(1, Net.max_slots() + 1):
		if not Net.roster.has(pid):
			var empty: String = "P%d  (bot)" % pid if Net.fill_bots else "P%d  open slot" % pid
			content.add_child(MenuKit.label(empty, 22, MenuKit.DIM))
			continue
		var r: Dictionary = Net.roster[pid]
		var tag: String = "P%d  %-12s %-7s %s%s" % [pid, Net.player_name(pid), Net.display_name(pid), "(host) " if pid == 1 else "",
			"READY" if bool(r.get("ready", false)) else "not ready"]
		if pid == Net.local_player_id():
			tag += "   (you)"
		var pk: Dictionary = ((r.get("kits", {}) as Dictionary).get(String(Net.character_of(pid)), {}) as Dictionary)
		if not pk.is_empty():
			tag += "   " + Muster.pistol_name(str(pk.get("pistol", "m1911")))
		content.add_child(MenuKit.label(tag, 24, Net.player_color(pid)))


func _build_survivor_pick() -> void:
	content.add_child(MenuKit.label("Your character", 22, MenuKit.PAPER))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var taken: Dictionary = {}
	for pid2: int in Net.player_ids():
		if pid2 != Net.local_player_id():
			taken[str((Net.roster[pid2] as Dictionary)["character"])] = true
	var mine: String = String(Net.character_of(Net.local_player_id()))
	for c: Array in MenuCharacter.CHARACTERS:
		var id: String = c[0]
		var b: Button = MenuKit.button(("> " if id == mine else "") + str(Net.DISPLAY[id]), Lobbies.set_character.bind(id), 22)
		b.disabled = taken.has(id)
		b.custom_minimum_size = Vector2(150, 44)
		row.add_child(b)
	var mk: Dictionary = Muster.loadout_for(mine, ProfileSave.profile)
	content.add_child(MenuKit.button("Loadout: " + Muster.summary(mk), _open_muster.bind(mine), 20))   # T-079


func _build_host_controls(online: bool) -> void:
	var all_ready: bool = Net.all_ready()
	if online:
		content.add_child(MenuKit.check("Bots fill empty slots", Net.fill_bots, Lobbies.set_fill_bots))
		content.add_child(MenuKit.check("Public", bool(Net.lobby.get("is_public", true)), Lobbies.set_public))
		var start: Button = MenuKit.button("Start   ·   " + LobbyService.map_name(str(Net.lobby.get("map_id", LobbyService.DEFAULT_MAP)))
			+ ("" if all_ready else "   (waiting for everyone to be ready)"), Lobbies.start.bind(false), 26, "ui_confirm")
		start.disabled = not all_ready
		content.add_child(start)
	else:
		content.add_child(MenuKit.label("Map" + ("" if all_ready else "   (waiting for everyone to be ready)"), 22, MenuKit.PAPER))
	# The campaign chain for the whole squad (T-033): the host drives every exfil, every peer follows.
	var camp: Button = MenuKit.button("Campaign   ·   Crossroads Inn  >  Kaltenbrunn  >  Totenhafen", _start_campaign, 24, "ui_confirm")
	camp.disabled = not all_ready
	content.add_child(camp)
	if online:
		return
	for m: Array in MenuCharacter.MAPS:
		var id2: StringName = StringName(m[0])
		var open: bool = ProfileSave.is_map_unlocked(id2) and str(m[2]) != ""
		var b2: Button = MenuKit.button(str(m[1]) + ("" if open else "   [locked]"), _start_lan.bind(str(m[2])), 24, "ui_confirm")
		b2.disabled = not open or not all_ready
		content.add_child(b2)


## The direct-IP lobby (ENet): host or join by address. Port %d UDP must be reachable (LAN, or a forwarded port).
func _build_lan() -> void:
	content.add_child(MenuKit.para("Up to four players on one network. The host runs the game; everyone else joins by address "
		+ "(same PC: 127.0.0.1, LAN: the host's address shown in their lobby). Port %d (UDP)." % _port(), 18, MenuKit.DIM))
	content.add_child(MenuKit.button("Host on this network", _host_lan, 26, "ui_confirm"))
	_ip = _line_edit(str(GLSettings.values.get("last_join_ip", "127.0.0.1")), "host address, e.g. 192.168.1.20", 64)
	_ip.text_submitted.connect(func(_t: String) -> void: _join_lan())
	content.add_child(MenuKit.row("Join address", _ip, 220))
	if MenuKit.wants_pad_keys():   # T-264: an IPv4 address (and :port) typed with a controller
		content.add_child(MenuKit.pad_keys(_ip, "1234567890.:", 12))
	content.add_child(MenuKit.button("Join", _join_lan, 26, "ui_confirm"))
	content.add_child(MenuKit.button("Back", _go.bind("home"), 22, "ui_back"))


# ================================================================== actions

func _line_edit(text: String, placeholder: String, max_len: int) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.add_theme_font_override("font", MenuKit.type_font())
	e.add_theme_font_size_override("font_size", 22)
	e.custom_minimum_size = Vector2(360, 44)
	e.focus_mode = Control.FOCUS_ALL
	return e


func _save_name() -> void:
	Lobbies.set_display_name(_name_field.text if _name_field != null else "")
	_go("home")


func _quick() -> void:
	_status = ""
	Lobbies.quick_match()
	rebuild()


func _create() -> void:
	_status = ""
	Lobbies.create(_create_map, _create_public, "", _create_slots, _create_bots)
	rebuild()


func _join_code() -> void:
	_status = ""
	Lobbies.join(_code_field.text if _code_field != null else "")
	rebuild()


func _rejoin() -> void:
	_status = ""
	Lobbies.rejoin()
	rebuild()


func _cancel() -> void:
	Lobbies.leave()
	_go("home")


func _leave() -> void:
	if Net.is_webrtc() or Lobbies.state != LobbyService.State.IDLE:
		Lobbies.leave()
	else:
		Net.leave("")
	_status = ""
	_page = "home"
	rebuild()


func _start_campaign() -> void:
	if Net.is_webrtc():
		Lobbies.start(true)
	else:
		Net.start_match(Campaign.scene_for(Campaign.first_map()), true)


func _start_lan(scene: String) -> void:
	Net.start_match(scene)


func _host_lan() -> void:
	_status = ""
	if Net.host_game() != OK:
		_status = Net.last_error
	rebuild()


func _join_lan() -> void:
	var text: String = _ip.text.strip_edges() if _ip != null else "127.0.0.1"
	if text == "":
		text = "127.0.0.1"
	var port: int = -1
	if text.count(":") == 1:
		port = int(text.get_slice(":", 1))
		text = text.get_slice(":", 0)
	GLSettings.values["last_join_ip"] = _ip.text.strip_edges() if _ip != null else text
	GLSettings.save_settings()
	_status = ""
	if Net.join_game(text, port) != OK:
		_status = Net.last_error
	rebuild()


func _open_muster(c: String) -> void:
	var m: MenuMuster = MenuMuster.new(c)
	add_child(m)
	m.closed.connect(func() -> void:
		Net.send_kits()   # the host (and through it everyone) sees the new kit
		_queue_rebuild())


func _port() -> int:
	return int(Net.cfg().get("port", 24785))


static func _lan_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for a: String in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ================================================================== events

## Many signals can fire in one frame (roster + lobby + state): one rebuild at the end of it.
func _queue_rebuild(_a: Variant = null) -> void:
	if _dirty or not is_inside_tree():
		return
	_dirty = true
	(func() -> void:
		_dirty = false
		if is_inside_tree() and not (_page in ["name", "join", "lan", "create"] and not Net.is_online() and Lobbies.state == LobbyService.State.IDLE):
			rebuild()).call_deferred()


func _on_list(_list: Array) -> void:
	if _page == "browse":
		_queue_rebuild()


func _on_joined(_lobby: Dictionary) -> void:
	_status = ""
	_page = "room"
	_queue_rebuild()


func _on_failed(reason: String) -> void:
	_status = reason
	if _page == "busy" or _page == "room":
		_page = "home"
	_queue_rebuild()


func _on_left(reason: String) -> void:
	if reason != LobbyService.LEFT_BY_USER and reason != "":
		_status = reason
	_page = "home"
	_queue_rebuild()


func _on_disconnected(reason: String) -> void:
	if reason != "":
		_status = reason
	_queue_rebuild()


## Backing out of the page leaves the lobby (nothing is left listening).
func close() -> void:
	if Net.is_online() and not Net.in_match:
		if Net.is_webrtc() or Lobbies.state != LobbyService.State.IDLE:
			Lobbies.leave()
		else:
			Net.leave("")
	super.close()
