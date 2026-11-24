extends Node
## T-264 (a handheld has no keyboard or mouse in game mode): the main menu driven by controller events only: real
## InputEventJoypadButton / InputEventJoypadMotion events through Input.parse_input_event (D-pad, A, B, RB, the right
## stick), never an action event, a key or a click. Checks what a pad-only player needs: the prompts switch to the
## pad, every column and screen opens with A and closes with B, a text page opens at its top and the right stick
## scrolls it, the lobby's text fields can be typed with the on-screen letter keys, a rebuild keeps the focus where
## it was, and the rebinding wait can be left without a keyboard. Prints one RESULT line.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_menus_pad.tscn

const MENU: String = "res://gravelight/ui/main_menu.tscn"

var _fails: PackedStringArray = []
var _menu: Control
var _done: bool = false
var _t0: int = 0
var _opened: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_smoke_menus_pad.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_smoke_menus_pad_settings.cfg"
	Settings.path = "user://_qa_smoke_menus_pad_core.cfg"
	Lobbies.use_mock(0)   # ONLINE opens on the in-process mock table: nothing leaves the machine
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		_fails.append("timeout")
		_finish())
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print("[menus_pad] %-78s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		e.pressure = 1.0 if down else 0.0
		Input.parse_input_event(e)
		await _frames(2 if down else 3)


func _stick(axis: JoyAxis, value: float) -> void:
	var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await _frames(1)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _focused() -> String:
	var f: Control = _focus_owner()
	return (f as Button).text if f is Button else (str(f.name) if f != null else "")


## Moves the focus down the column to `label` (wrapping), by D-pad presses only.
func _focus(label: String) -> bool:
	for i: int in 10:
		if _focused() == label.to_upper():
			return true
		await _pad(JOY_BUTTON_DPAD_DOWN)
	return _focused() == label.to_upper()


func _screen() -> MenuScreen:
	var s: Variant = _menu.get("_screen")
	return s as MenuScreen if s != null and is_instance_valid(s) else null


func _open(label: String, kind: GDScript) -> MenuScreen:
	var ok: bool = await _focus(label)
	_check(ok, "the D-pad reaches %s" % label)
	await _pad(JOY_BUTTON_A)
	await _frames(4)
	var s: MenuScreen = _screen()
	_check(s != null and s.get_script() == kind, "A on %s opens its screen" % label)
	if s != null:
		_opened.append(label)
		await _secs(0.4)
	return s


func _close(label: String) -> void:
	await _pad(JOY_BUTTON_B)
	await _secs(0.4)
	_check(_screen() == null, "B closes %s" % label)


func _open_close(label: String, kind: GDScript) -> void:
	var s: MenuScreen = await _open(label, kind)
	if s != null:
		_check(_focus_owner() != null and s.is_ancestor_of(_focus_owner()), "%s: something on the page has the focus (%s)" % [label, _focused()])
		await _close(label)


## The button whose text is `text` under `root` (first in tree order).
func _button(root: Node, text: String) -> Button:
	for n: Node in root.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n as Button
	return null


## Walks the focus with the D-pad (down, then right) until `want` has it; true when it got there.
func _walk_to(want: Control) -> bool:
	for i: int in 40:
		if _focus_owner() == want:
			return true
		await _pad(JOY_BUTTON_DPAD_DOWN if i % 2 == 0 else JOY_BUTTON_DPAD_RIGHT)
	return _focus_owner() == want


func _run() -> void:
	_t0 = Time.get_ticks_msec()
	_menu = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu
	await _secs(0.6)
	_check(_focused() == "PLAY", "PLAY has the focus at start (%s)" % _focused())
	GLSettings.using_pad = false
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(GLSettings.using_pad, "a pad press switches the prompts to the controller")
	_check(GLSettings.action_label(&"interact") == GLSettings.binding_label(&"interact", true) and GLSettings.binding_label(&"interact", true) != "-",
		"prompts name the pad's button (interact: %s)" % GLSettings.action_label(&"interact"))
	_check(_focused() == "PLAY", "D-pad down and up come back to PLAY (%s)" % _focused())

	# ---- PLAY > SOLO / CAMPAIGN, and ONLINE with its text fields
	await _pad(JOY_BUTTON_A)
	await _secs(0.3)
	_check(str(_menu.get("column")) == "play", "A on PLAY opens its column")
	await _open_close("Solo", MenuCharacter)
	var lobby: MenuLobby = await _open("Online", MenuLobby) as MenuLobby
	if lobby != null:
		# first visit: the name page. Its letter keys are there for a controller, and A on a key types
		_check(str(lobby.get("_page")) == "name", "ONLINE asks for a name first (%s)" % str(lobby.get("_page")))
		var name_field: LineEdit = lobby.get("_name_field") as LineEdit
		var key_b: Button = _button(lobby.content, "B")
		_check(key_b != null, "the name page shows letter keys to a controller")
		if key_b != null and name_field != null:
			_check(_focus_owner() == name_field, "the name field has the focus when the page opens")
			for i: int in 6:   # down from the field: the first control under it is a letter key
				if _focus_owner() is Button and _focus_owner().get_parent() is GridContainer:
					break
				await _pad(JOY_BUTTON_DPAD_DOWN)
			var on_key: Button = _focus_owner() as Button
			_check(on_key != null and on_key.get_parent() is GridContainer, "the D-pad walks from the field down to a letter key (%s)" % _focused())
			var letter: String = on_key.text if on_key != null else "?"
			await _pad(JOY_BUTTON_A)
			await _pad(JOY_BUTTON_A)
			_check(name_field.text == letter + letter, "A on a letter key types into the field (%s)" % name_field.text)
			var del: Button = _button(lobby.content, "Del")
			del.grab_focus()
			await _pad(JOY_BUTTON_A)
			_check(name_field.text == letter, "Del removes a letter (%s)" % name_field.text)
		var ok_b: Button = _button(lobby.content, "OK")
		if ok_b != null:
			ok_b.grab_focus()
			await _pad(JOY_BUTTON_A)
			await _secs(0.3)
		_check(str(lobby.get("_page")) == "home", "OK goes on to the lobby's home page (%s)" % str(lobby.get("_page")))
		# join by code: six letters with the pad
		lobby.call("_go", "join")
		await _frames(4)
		var code_field: LineEdit = lobby.get("_code_field") as LineEdit
		for ch: String in ["K", "X", "M", "R", "T", "A", "Z"]:
			var kb: Button = _button(lobby.content, ch)
			if kb == null:
				_check(false, "the join page has the key %s" % ch)
				continue
			kb.grab_focus()
			await _pad(JOY_BUTTON_A)
		_check(code_field != null and code_field.text == "KXMRTA", "a six-letter code is typed with the pad, and no seventh (%s)" % (code_field.text if code_field != null else "?"))
		_check(_button(lobby.content, "I") == null and _button(lobby.content, "O") == null, "the code keys leave out I and O, like the codes")
		# the LAN page: an address
		lobby.call("_go", "lan")
		await _frames(4)
		var ip: LineEdit = lobby.get("_ip") as LineEdit
		var clear: Button = _button(lobby.content, "Clear")
		_check(clear != null and ip != null, "the LAN page has the address keys")
		if clear != null and ip != null:
			clear.grab_focus()
			await _pad(JOY_BUTTON_A)
			for ch: String in ["1", "0", ".", "0", ".", "0", ".", "7"]:
				_button(lobby.content, ch).grab_focus()
				await _pad(JOY_BUTTON_A)
			_check(ip.text == "10.0.0.7", "an address is typed with the pad (%s)" % ip.text)
		# a rebuild (the lobby list refreshes every 5 s) leaves the focus where it was
		lobby.call("_go", "home")
		await _frames(4)
		await _pad(JOY_BUTTON_DPAD_DOWN)
		await _pad(JOY_BUTTON_DPAD_DOWN)
		var before: String = _focused()
		var at: int = MenuKit.focusables(lobby.content).find(_focus_owner())
		lobby.rebuild()
		await _frames(4)
		_check(at > 0 and MenuKit.focusables(lobby.content).find(_focus_owner()) == at and _focused() == before,
			"a rebuild keeps the focus on the same control (%s, place %d)" % [before, at])
		await _close("Online")
	await _open_close("Campaign", MenuCharacter)
	await _pad(JOY_BUTTON_B)
	await _secs(0.3)
	_check(str(_menu.get("column")) == "main", "B goes back to the main column")
	await _open_close("Muster", MenuMuster)
	await _open_close("Archive", MenuArchive)

	# ---- SETTINGS: tabs with RB, the rebinding wait left without a keyboard
	var st: MenuSettings = await _open("Settings", MenuSettings) as MenuSettings
	if st != null:
		var tab0: int = int(st.get("_tab"))
		await _pad(JOY_BUTTON_RIGHT_SHOULDER)
		await _frames(3)
		_check(int(st.get("_tab")) == tab0 + 1, "RB goes to the next settings tab (%d -> %d)" % [tab0, int(st.get("_tab"))])
		st.call("_set_tab", MenuSettings.TABS.find("Controls") if MenuSettings.TABS.has("Controls") else 1)
		await _frames(4)
		var jump_kb: String = GLSettings.binding_label(&"jump", false)
		var jump_pad: String = GLSettings.binding_label(&"jump", true)
		st.set("_waiting_action", &"jump")
		st.set("_waiting_pad", false)
		await _frames(2)
		await _pad(JOY_BUTTON_B)
		_check(StringName(st.get("_waiting_action")) == &"" and _screen() == st, "pad B leaves a keyboard-binding wait (and does not close the page)")
		st.set("_waiting_action", &"jump")
		st.set("_waiting_pad", true)
		await _secs(MenuSettings.REBIND_WAIT_S + 0.6)
		_check(StringName(st.get("_waiting_action")) == &"", "a controller-binding wait ends by itself after %d s" % int(MenuSettings.REBIND_WAIT_S))
		_check(GLSettings.binding_label(&"jump", false) == jump_kb and GLSettings.binding_label(&"jump", true) == jump_pad, "and nothing was rebound")
		# a graphics choice rebuilds the page: the focus stays on the row that was changed
		st.call("_set_tab", MenuSettings.TABS.find("Video") if MenuSettings.TABS.has("Video") else 3)
		await _frames(4)
		var rows: Array[Control] = MenuKit.focusables(st.content)
		if rows.size() > 6:
			rows[5].grab_focus()
			await _frames(1)
			st.rebuild()
			await _frames(4)
			_check(MenuKit.focusables(st.content).find(_focus_owner()) == 5, "Video: a rebuild keeps the focus on its row (place %d)" % MenuKit.focusables(st.content).find(_focus_owner()))
		_check(_button(st.content, "Handheld") != null or _has_option(st.content, "Handheld"), "the graphics preset list offers Handheld")
		await _close("Settings")

	# ---- EXTRAS: the text pages open at the top and the right stick scrolls them
	var ok: bool = await _focus("Extras")
	_check(ok, "the D-pad reaches EXTRAS")
	await _pad(JOY_BUTTON_A)
	await _secs(0.3)
	_check(str(_menu.get("column")) == "extras", "A on EXTRAS opens its column")
	await _open_close("Dossiers", MenuDossiers)
	for pair: Array in [["Service Record", MenuStats], ["Challenges", MenuChallenges], ["Credits", MenuCredits]]:
		var page: MenuScreen = await _open(str(pair[0]), pair[1] as GDScript)
		if page == null:
			continue
		if str(pair[0]) != "Challenges":
			var sc: ScrollContainer = page.get("_scroll") as ScrollContainer
			await _frames(4)
			var bar: VScrollBar = sc.get_v_scroll_bar()
			var can_scroll: bool = bar.max_value > bar.page + 4.0
			_check(sc.scroll_vertical == 0, "%s opens at its top (scroll %d)" % [pair[0], sc.scroll_vertical])
			await _stick(JOY_AXIS_RIGHT_Y, 1.0)
			await _secs(0.5)
			await _stick(JOY_AXIS_RIGHT_Y, 0.0)
			_check(sc.scroll_vertical > 0 or not can_scroll, "%s: the right stick scrolls the page (%d of %d)" % [pair[0], sc.scroll_vertical, int(bar.max_value - bar.page)])
		await _close(str(pair[0]))
	await _pad(JOY_BUTTON_B)
	await _secs(0.3)
	await _pad(JOY_BUTTON_B)
	await _secs(0.3)
	_check(str(_menu.get("column")) == "quit", "B on the main column opens QUIT's column")
	await _pad(JOY_BUTTON_B)
	await _secs(0.3)
	_check(str(_menu.get("column")) == "main", "and B comes back")
	_check(_opened.size() == 10, "every screen opened by the pad (%d: %s)" % [_opened.size(), ", ".join(_opened)])
	_finish()


func _has_option(root: Node, text: String) -> bool:
	for n: Node in root.find_children("*", "OptionButton", true, false):
		var ob: OptionButton = n as OptionButton
		for i: int in ob.item_count:
			if ob.get_item_text(i) == text:
				return true
	for n: Node in root.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false


func _finish() -> void:
	if _done:
		return
	_done = true
	var secs: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var verdict: String = "PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]
	print("[menus_pad] RESULT: %s (%.0f s, %d screens)" % [verdict, secs, _opened.size()])
	for p: String in [ProfileSave.path, GLSettings.path, Settings.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	get_tree().quit(0 if _fails.is_empty() else 1)
