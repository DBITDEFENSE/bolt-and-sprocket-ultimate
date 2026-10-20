class_name MenuLobby
extends MenuScreen
## Co-op lobby (M7): host a game or join one by address, pick a survivor (each survivor once), ready up; the
## host picks the map and starts. Controller-navigable like every MenuKit page (the address field takes the
## on-screen keyboard or a keyboard; the last address is remembered).

var _ip: LineEdit
var _status: String = ""
var _connecting: bool = false


func _init() -> void:
	super._init("Co-op")


func _ready() -> void:
	super._ready()
	Net.roster_changed.connect(_refresh)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_failed)
	Net.disconnected.connect(_on_disconnected)


func _exit_tree() -> void:
	for pair: Array in [[Net.roster_changed, _refresh], [Net.joined, _on_joined], [Net.join_failed, _on_failed],
			[Net.disconnected, _on_disconnected]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1] as Callable):
			sig.disconnect(pair[1] as Callable)


func build() -> void:
	if not Net.is_online():
		_build_start()
	elif Net.is_client() and Net.local_player_id() == 0:
		_build_connecting()
	else:
		_build_lobby()


func _build_start() -> void:
	content.add_child(MenuKit.para("Up to four survivors. The host runs the game; everyone else joins by address "
		+ "(same PC: 127.0.0.1, LAN: the host's address shown in their lobby). Port %d (UDP)." % _port(), 18, MenuKit.DIM))
	if _status != "":
		content.add_child(MenuKit.para(_status, 20, MenuKit.INK.lightened(0.35)))
	content.add_child(MenuKit.button("Host a game", _host, 26, "ui_confirm"))
	_ip = LineEdit.new()
	_ip.text = str(GLSettings.values.get("last_join_ip", "127.0.0.1"))
	_ip.placeholder_text = "host address, e.g. 192.168.1.20"
	_ip.add_theme_font_override("font", MenuKit.type_font())
	_ip.add_theme_font_size_override("font_size", 22)
	_ip.custom_minimum_size = Vector2(360, 44)
	_ip.focus_mode = Control.FOCUS_ALL
	_ip.text_submitted.connect(func(_t: String) -> void: _join())
	content.add_child(MenuKit.row("Join address", _ip, 220))
	content.add_child(MenuKit.button("Join", _join, 26, "ui_confirm"))


func _build_connecting() -> void:
	content.add_child(MenuKit.para("Connecting...", 24, MenuKit.GOLD))
	content.add_child(MenuKit.button("Cancel", func() -> void:
		Net.leave("")
		rebuild(), 22, "ui_back"))


func _build_lobby() -> void:
	var host: bool = Net.is_host()
	var head: String = "You're hosting." if host else "Joined. The host picks the map."
	if host:
		var addrs: PackedStringArray = _lan_addresses()
		if not addrs.is_empty():
			head += "  Others join with: %s  (port %d)" % [", ".join(addrs), _port()]
	content.add_child(MenuKit.para(head, 20, MenuKit.GOLD))
	if _status != "":
		content.add_child(MenuKit.para(_status, 18, MenuKit.INK.lightened(0.35)))
	# the squad
	for pid: int in Net.player_ids():
		var r: Dictionary = Net.roster[pid]
		var tag: String = "P%d  %-7s %s%s" % [pid, Net.display_name(pid), "(host) " if pid == 1 else "",
			"READY" if bool(r.get("ready", false)) else "not ready"]
		if pid == Net.local_player_id():
			tag += "   (you)"
		content.add_child(MenuKit.label(tag, 24, Net.player_color(pid)))
	# survivor choice (each once)
	content.add_child(MenuKit.label("Your survivor", 22, MenuKit.PAPER))
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
		var b: Button = MenuKit.button(("> " if id == mine else "") + str(Net.DISPLAY[id]), Net.set_character.bind(id), 22)
		b.disabled = taken.has(id)
		b.custom_minimum_size = Vector2(150, 44)
		row.add_child(b)
	if not host:
		var me: Dictionary = Net.roster.get(Net.local_player_id(), {})
		var ready_now: bool = bool(me.get("ready", false))
		content.add_child(MenuKit.button("Not ready" if ready_now else "Ready", Net.set_ready.bind(not ready_now), 26, "ui_confirm"))
	else:
		var all_ready: bool = Net.all_ready()
		content.add_child(MenuKit.label("Map" + ("" if all_ready else "   (waiting for everyone to be ready)"), 22, MenuKit.PAPER))
		for m: Array in MenuCharacter.MAPS:
			var id2: StringName = StringName(m[0])
			var open: bool = ProfileSave.is_map_unlocked(id2) and str(m[2]) != ""
			var b2: Button = MenuKit.button(str(m[1]) + ("" if open else "   [locked]"), Net.start_match.bind(str(m[2])), 24, "ui_confirm")
			b2.disabled = not open or not all_ready
			content.add_child(b2)
	content.add_child(MenuKit.button("Leave the lobby" if not host else "Close the lobby", _leave, 22, "ui_back"))


func _port() -> int:
	return int(Net.cfg().get("port", 24785))


static func _lan_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for a: String in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func _host() -> void:
	_status = ""
	if Net.host_game() != OK:
		_status = Net.last_error
	rebuild()


func _join() -> void:
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


func _leave() -> void:
	Net.leave("")
	_status = ""
	rebuild()


func _refresh() -> void:
	if is_inside_tree():
		rebuild()


func _on_joined() -> void:
	_status = ""
	_refresh()


func _on_failed(reason: String) -> void:
	_status = reason
	_refresh()


func _on_disconnected(reason: String) -> void:
	_status = reason
	_refresh()


## Backing out of the page leaves the lobby (nothing is left listening).
func close() -> void:
	if Net.is_online() and not Net.in_match:
		Net.leave("")
	super.close()
