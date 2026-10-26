extends Control
## Main menu over the 3D Minehead Yard backdrop: Play (survivor → map), Muster (T-079), Co-op (lobby), Archive, Dossiers,
## Service Record, Challenges, GLSettings, Credits, Test Range (dev), Quit. Fully navigable with a controller.
## While a co-op connection is open (back from a match) the lobby opens straight away.

const TEST_RANGE: String = "res://gravelight/maps/test_range/test_range.tscn"

var _menu: VBoxContainer
var _screen: MenuScreen = null


func _ready() -> void:
	GLSettings.activate()
	Game.set_mode(Game.Mode.GRAVELIGHT)
	get_tree().paused = false
	GameState.phase = GameState.Phase.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuKit.apply_theme(self)
	AudioDirector.stop_all_music()
	AudioDirector.play_music("music_menu")
	add_child(MenuBackdrop.new())
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.02, 0.85))
	grad.set_color(1, Color(0.0, 0.0, 0.02, 0.0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0.7, 0.0)
	var tr: TextureRect = TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(110, 70)
	_menu.custom_minimum_size = Vector2(640, 0)
	_menu.add_theme_constant_override("separation", 8)
	add_child(_menu)
	_build()
	var guard: Control = Control.new()   # swallow clicks for a moment (T-025)
	guard.set_anchors_preset(Control.PRESET_FULL_RECT)
	guard.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(guard)
	get_tree().create_timer(0.35).timeout.connect(guard.queue_free)


func _build() -> void:
	GameState.bot_count = 0   # only Play (MenuCharacter) sends bots into a match (T-031)
	GameState.bot_ai_mode = "off"
	for c: Node in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()

	_menu.add_child(MenuKit.text("wordmark", "GRAVELIGHT", Color(0.85, 0.82, 0.74)))
	_menu.add_child(MenuKit.text("subheading", "Silesia, winter 1944. The dead are keeping count.", MenuKit.VIOLET))
	# profile header: rank stamp + XP bar
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_menu.add_child(head)
	var p: int = ProfileSave.prestige()
	head.add_child(MenuKit.label("RANK %d" % ProfileSave.rank(), 34, MenuKit.INK.lightened(0.25), true))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_child(MenuKit.bar(ProfileSave.rank_progress(), 260))
	var card: String = str(ProfileSave.profile.get("equipped", {}).get("calling_card", ""))
	col.add_child(MenuKit.label(("Commendation %d   " % p if p > 0 else "") + (_unlock_name(card) if card != "" else ""), 16, MenuKit.DIM))
	head.add_child(col)
	_menu.add_child(Control.new())
	var play: Button = MenuKit.button("Play", _open.bind(MenuCharacter), 30)
	_menu.add_child(play)
	_menu.add_child(MenuKit.button("Muster (rank, sidearm, Field Habits)", _open.bind(MenuMuster), 26))   # T-079
	_menu.add_child(MenuKit.button("Co-op (1-4 players)", _open.bind(MenuLobby), 26))
	_menu.add_child(MenuKit.button("Intel Archive", _open.bind(MenuArchive), 26))
	_menu.add_child(MenuKit.button("Dossiers", _open.bind(MenuDossiers), 26))
	_menu.add_child(MenuKit.button("Service Record", _open.bind(MenuStats), 26))
	_menu.add_child(MenuKit.button("Challenges & Rewards", _open.bind(MenuChallenges), 26))
	_menu.add_child(MenuKit.button("Settings", _open.bind(MenuSettings), 26))
	_menu.add_child(MenuKit.button("Credits", _open.bind(MenuCredits), 26))
	_menu.add_child(MenuKit.button("Test Range (dev)", func() -> void: get_tree().change_scene_to_file(TEST_RANGE), 20))
	_menu.add_child(MenuKit.button("Back to Terms & Conditions", func() -> void: get_tree().change_scene_to_file("res://ui/main_menu.tscn"), 26))
	if Net.last_error != "":
		_menu.add_child(MenuKit.para(Net.last_error, 18, MenuKit.INK.lightened(0.35)))
		Net.last_error = ""
	play.grab_focus.call_deferred()
	if Net.is_online() and _screen == null:
		_open.call_deferred(MenuLobby)


func _unlock_name(item_id: String) -> String:
	for u: Dictionary in ProfileSave.unlock_rows():
		if str(u["id"]) == item_id:
			return str(u["name"])
	return item_id.replace("card_", "").replace("_", " ").capitalize()


func _open(screen_script: GDScript) -> void:
	if _screen != null and is_instance_valid(_screen):
		return
	_screen = screen_script.new() as MenuScreen
	_menu.visible = false
	add_child(_screen)
	_screen.closed.connect(_on_closed)


func _exit_tree() -> void:
	AudioDirector.stop_music()   # leaving for a map (or quitting): the menu theme ends with the menu


func _on_closed() -> void:
	_screen = null
	_menu.visible = true
	_build()
