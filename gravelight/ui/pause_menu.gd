class_name PauseMenu
extends CanvasLayer
## Esc / Start pauses the match (solo). A proper in-match page (T-040): the match card (map, round, Scrip, kills,
## perks), Resume, the full tabbed Settings (the same MenuSettings as the main menu: Gameplay, Controls with
## remapping, Audio, Video, Accessibility), quick sliders for the two things people reach for mid-match
## (sensitivity, field of view), Restart, and Quit, with a controls reminder at the foot.
## Co-op: the world keeps running (only your input stops); Restart is the host's, and quitting leaves the game
## (the host leaving ends it for everyone).

signal quit_requested
signal restart_requested

const TIPS: PackedStringArray = [
	"Sprint + CROUCH slides. Crouch again to cancel, JUMP out of it to slide-jump.",
	"Hold USE at a wall gun you already own to buy ammo.",
	"The Crucible forges a gun three times: V, VV and VVV.",
	"Perk slots are capped: pick the four that fit the map.",
	"Rebuilt boards pay Scrip. Early rounds are for building.",
	"A thrown knife and a grenade both count as 'something between you and the pack'.",
]

var _root: Control
var _box: VBoxContainer
var _card: Label
var _perks: Label
var _buttons: Array[Button] = []
var _settings: MenuScreen = null
var _confirm: PanelContainer = null
var _sens: HSlider
var _fov: HSlider
var _tip: Label
var _tip_t: float = 0.0


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel: PanelContainer = MenuKit.panel(Vector2(760, 0))
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	# header: title + the match card
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	_box.add_child(head)
	var title: Label = MenuKit.label("PAUSED", 46, MenuKit.PAPER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_card = MenuKit.label("", 18, MenuKit.GOLD)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_card)
	_perks = MenuKit.label("", 16, MenuKit.DIM)
	_box.add_child(_perks)
	_box.add_child(HSeparator.new())
	# the buttons, two columns: actions left, quick settings right
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	_box.add_child(cols)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(300, 0)
	cols.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_add_button(left, "Resume", toggle)
	_add_button(left, "Settings", _open_settings)
	if not Net.is_client():
		_add_button(left, "Restart" if not Net.is_online() else "Restart (everyone)",
			_confirm_then.bind("Restart the match?", func() -> void: restart_requested.emit()))
	if Net.is_host():
		_add_button(left, "Back to lobby (everyone)", _confirm_then.bind("Send everyone back to the lobby?", func() -> void: quit_requested.emit()))
		_add_button(left, "End the game", _confirm_then.bind("End the game for everyone?", func() -> void:
			Net.leave("")
			get_tree().paused = false
			GameState.phase = GameState.Phase.MENU
			get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")))
	else:
		_add_button(left, "Quit to menu" if not Net.is_online() else "Leave the game",
			_confirm_then.bind("Quit to the menu? The match is lost.", func() -> void: quit_requested.emit()))
	right.add_child(MenuKit.label("Quick settings", 18, MenuKit.PAPER, true))
	_sens = MenuKit.slider(0.1, 4.0, 0.05, GLSettings.get_f("sensitivity"), func(v: float) -> void: GLSettings.set_value("sensitivity", v))
	right.add_child(MenuKit.row("Mouse sensitivity", _sens, 180.0))
	_fov = MenuKit.slider(65.0, 110.0, 1.0, GLSettings.get_f("fov"), func(v: float) -> void: GLSettings.set_value("fov", v))
	right.add_child(MenuKit.row("Field of view", _fov, 180.0))
	right.add_child(MenuKit.row("Screen shake", MenuKit.slider(0.0, 1.5, 0.05, float(GLSettings.values.get("screen_shake", 1.0)),
		func(v: float) -> void: GLSettings.set_value("screen_shake", v)), 180.0))
	right.add_child(MenuKit.check("Subtitles", bool(GLSettings.values.get("subtitles", true)), func(on: bool) -> void: GLSettings.set_value("subtitles", on)))
	right.add_child(MenuKit.check("Hint mode (show the next objective)", bool(GLSettings.values.get("hint_mode", false)), func(on: bool) -> void: GLSettings.set_value("hint_mode", on)))
	right.add_child(MenuKit.check("Classic Rules (no character traits)", bool(GLSettings.values.get("classic_rules", false)), func(on: bool) -> void: GLSettings.set_value("classic_rules", on)))
	_box.add_child(HSeparator.new())
	_tip = MenuKit.para("", 15, MenuKit.DIM)
	_box.add_child(_tip)
	var keys: Label = MenuKit.para(_controls_line(), 14, MenuKit.DIM)
	_box.add_child(keys)


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b: Button = MenuKit.button(text, cb, 24)
	b.custom_minimum_size = Vector2(300, 46)
	parent.add_child(b)
	_buttons.append(b)
	return b


func _controls_line() -> String:
	var parts: PackedStringArray = []
	for pair: Array in [["sprint", "Sprint"], ["crouch", "Crouch / slide"], ["interact", "Use / buy"], ["melee", "Knife"], ["lethal", "Grenade"], ["swap_weapon", "Swap"]]:
		parts.append("%s %s" % [GLSettings.binding_label(StringName(str(pair[0])), false), pair[1]])
	return "  ·  ".join(parts)


func _refresh_card() -> void:
	var map_name: String = str(GameState.get("map_display_name")) if GameState.get("map_display_name") != null else String(GameState.map_id)
	var st: Dictionary = GameState.get("stats") if GameState.get("stats") is Dictionary else {}
	var me: int = Net.local_player_id()   # 1 offline / host; a co-op client sees its own Scrip and perks
	_card.text = "%s\nRound %d  ·  %d Scrip  ·  %d kills (%d heads)  ·  %s" % [map_name, RoundManager.current_round, Economy.get_scrip(me),
		int(st.get(&"kills", 0)), int(st.get(&"headshots", 0)), _elapsed()]
	var names: PackedStringArray = []
	for p: Variant in PerkManager.owned(me):
		names.append(PerkManager.display_name(StringName(str(p))))
	_perks.text = ("Perks: " + ", ".join(names)) if not names.is_empty() else "Perks: none yet"
	if _sens != null:
		_sens.set_value_no_signal(GLSettings.get_f("sensitivity"))
	if _fov != null:
		_fov.set_value_no_signal(GLSettings.get_f("fov"))
	_tip.text = TIPS[randi() % TIPS.size()]


func _elapsed() -> String:
	var ms: int = Time.get_ticks_msec() - int(GameState.get("_start_msec")) if GameState.get("_start_msec") != null else 0
	var s: int = maxi(0, ms / 1000)
	return "%d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- settings + confirmations

func _open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		return
	_settings = MenuSettings.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings)
	_root.visible = false                      # the settings page takes the whole screen
	_settings.closed.connect(func() -> void:
		_settings = null
		_root.visible = true
		_refresh_card()
		if not _buttons.is_empty():
			_buttons[0].grab_focus())


func _confirm_then(question: String, cb: Callable) -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_confirm = MenuKit.panel(Vector2(460, 0))
	center.add_child(_confirm)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_confirm.add_child(v)
	v.add_child(MenuKit.label(question, 22, MenuKit.PAPER, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var yes: Button = MenuKit.button("Yes", func() -> void:
		center.queue_free()
		_confirm = null
		cb.call(), 22)
	yes.custom_minimum_size = Vector2(200, 44)
	row.add_child(yes)
	var no: Button = MenuKit.button("No", func() -> void:
		center.queue_free()
		_confirm = null
		if not _buttons.is_empty():
			_buttons[0].grab_focus(), 22, "ui_back")
	no.custom_minimum_size = Vector2(200, 44)
	row.add_child(no)
	no.grab_focus()


# ---------------------------------------------------------------- open / close

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and GameState.phase == GameState.Phase.PLAYING:
		if visible and _settings != null and is_instance_valid(_settings):
			return     # the settings page's own Back handles Esc
		if visible and _confirm != null and is_instance_valid(_confirm):
			_confirm.get_parent().queue_free()
			_confirm = null
			get_viewport().set_input_as_handled()
			return
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if Net.is_online():
		GameState.input_blocked = visible   # co-op never stops the world
	else:
		get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		_refresh_card()
		if not _buttons.is_empty():
			_buttons[0].grab_focus()
	else:
		if _settings != null and is_instance_valid(_settings):
			_settings.queue_free()
			_settings = null
		_root.visible = true
		if _confirm != null and is_instance_valid(_confirm):
			_confirm.get_parent().queue_free()
			_confirm = null


func _process(delta: float) -> void:
	if not visible or _tip == null:
		return
	_tip_t += delta
	if _tip_t > 9.0:
		_tip_t = 0.0
		_tip.text = TIPS[randi() % TIPS.size()]
