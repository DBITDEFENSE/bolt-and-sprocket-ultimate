extends Control
## The CLAUDE ZOMBIES main menu (UPDATE 09 section 7, DECISIONS T-144) over the live 3D scene (MenuScene: the
## Crossroads Inn at night, our zombies at the fence, the squad by the fire). The Terms & Conditions hub
## (ui/main_menu.tscn) stays the first screen; its CLAUDE ZOMBIES door opens this one.
##   wordmark (MenuKit.wordmark, 140 px) with TERMS & CONDITIONS under it, top left;
##   a column of large letter-spaced buttons behind a thin violet rule:
##     PLAY      > SOLO (survivor, then the map cards), ONLINE (the lobby screens, menu_lobby.gd), CAMPAIGN
##     MUSTER, ARCHIVE
##     EXTRAS    > DOSSIERS, SERVICE RECORD, CHALLENGES, CREDITS, TEST RANGE
##     SETTINGS
##     QUIT      > TERMS & CONDITIONS (the hub), QUIT TO DESKTOP (not in a browser)
## Columns change with a 0.25 s cross-fade and a 20 px slide; every page (MenuScreen) opens over the scene with a
## darker shade. Keyboard and controller: up / down wrap, accept, Esc / pad B goes back a column.
## While an online connection is open (back from a match) the lobby opens straight away.
## T-243 (the owner: "make the menu better and more scary"): MenuDread over the scene (a blood-rimmed vignette on a
## heartbeat, the dread beats' dim), the focused link lit in dried blood and throbbing with that heartbeat, a blood
## rule, and the tagline typing out a new line every TAGLINE_S seconds (the first line is the one it always had).
## The scene's Watcher and its beats (MenuScene) pause while a page is open.

const TEST_RANGE: String = "res://gravelight/maps/test_range/test_range.tscn"
const HUB: String = "res://ui/main_menu.tscn"
const COL_X: float = 112.0
const COL_Y: float = 372.0
const WORDMARK_H: float = 184.0     # T-218: was 140; the lockup now starts on the column's rule
const WORDMARK_PAD: float = 0.048   # the empty strip left of the letters in claude_zombies.png (99 of 2048 px)
const BLOOD: Color = Color(0.66, 0.07, 0.05)
const TAG_COL: Color = Color(0.8, 0.27, 0.22)
const TAGLINE_S: float = 9.0
const TYPE_CPS: float = 30.0
const TAGLINES: PackedStringArray = [
	"Silesia, winter 1944. The dead are keeping count.",
	"Every round is a signature. They are collecting.",
	"The fence will not hold. It never has.",
	"Something at the treeline has learned your name.",
	"Read the fine print. They already have.",
	"Keep the fire lit. They hate what it shows them.",
]

var scene: MenuScene = null
var column: String = "main"
var _top: VBoxContainer
var _col_holder: Control
var _col: HBoxContainer = null
var _links: VBoxContainer = null
var _foot: VBoxContainer
var _hint: Label = null          # T-218: ENTER / ESC, or A / B with a controller
var _hint_pad: int = -1
var _version: Label = null
var _screen: MenuScreen = null
var _last_focus: Dictionary = {}     # column -> link name
var dread: MenuDread = null
var _tag: Label = null
var _tag_i: int = 0
var _tag_t: float = 0.0


func _ready() -> void:
	GLSettings.activate()
	# T-203 (the owner): the menu opens straight away; the prologue plays at the first campaign start, never here
	Game.set_mode(Game.Mode.GRAVELIGHT)
	get_tree().paused = false
	GameState.phase = GameState.Phase.MENU
	GameState.bot_count = 0   # only Play (MenuCharacter) sends bots into a match (T-031)
	GameState.bot_ai_mode = "off"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuKit.apply_theme(self)
	AudioDirector.stop_all_music()
	AudioDirector.play_music("music_menu")
	get_window().title = Game.GAME_MODE_NAME + " — " + Game.GAME_TITLE
	scene = MenuScene.new()
	add_child(scene)
	dread = MenuDread.new()
	dread.scene = scene
	add_child(dread)
	_build_shade()
	_top = VBoxContainer.new()
	_top.name = "Masthead"
	_top.add_theme_constant_override("separation", 2)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var wm: TextureRect = MenuKit.wordmark(WORDMARK_H) as TextureRect   # CLAUDE ZOMBIES (T-140)
	wm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT   # T-218: left-aligned on the rule, not centred over the tagline
	_top.add_child(wm)
	var tc: Label = Label.new()
	tc.text = Game.GAME_TITLE.to_upper()
	tc.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 8))
	tc.add_theme_font_size_override("font_size", 22)
	tc.add_theme_color_override("font_color", MenuKit.PAPER.darkened(0.15))
	MenuKit.outline(tc, "menu")
	_top.add_child(tc)
	var tag: Label = MenuKit.para(TAGLINES[0], 20, TAG_COL)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.name = "Tagline"
	_top.add_child(tag)
	_tag = tag
	for l: Label in [tc, tag]:   # the lines start where the letters of the wordmark start
		var inset: StyleBoxEmpty = StyleBoxEmpty.new()
		inset.content_margin_left = WORDMARK_H * 2048.0 / 940.0 * WORDMARK_PAD
		l.add_theme_stylebox_override("normal", inset)
	_version = MenuKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 15, MenuKit.DIM.darkened(0.15))
	_version.name = "Version"
	_version.add_theme_font_override("font", MenuKit.mono_font())
	_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version)
	_col_holder = Control.new()
	_col_holder.name = "ColumnHolder"
	_col_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col_holder)
	_foot = VBoxContainer.new()
	_foot.name = "Footer"
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foot)
	_build_footer()
	resized.connect(_layout)
	_layout()
	show_column("main", false)
	var guard: Control = Control.new()   # swallow clicks for a moment (T-025)
	guard.set_anchors_preset(Control.PRESET_FULL_RECT)
	guard.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(guard)
	get_tree().create_timer(0.35).timeout.connect(guard.queue_free)
	var reopen: bool = Net.reopen_lobby   # T-138: back from an online match (host left / dropped): the lobby says why
	if MenuLobby.consume_open_request():   # T-145: the dev launcher's "Online lobby" (--open=online): Play > Online at once
		show_column("play", false)
		reopen = true
	if (Net.is_online() or reopen) and _screen == null:
		open_screen.call_deferred(MenuLobby)
	elif CinemaTheatre.open_gallery and _screen == null:   # T-194: back from a replay: the Archive's gallery again
		CinemaTheatre.open_gallery = false
		(func() -> void:
			var a: MenuArchive = MenuArchive.new()
			a.gallery = true
			_screen = a
			_show_screen(a)).call_deferred()


## The left side darkens toward the column (readable over the scene), with a soft vignette at the foot.
func _build_shade() -> void:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.02, 0.0, 0.0, 0.88))
	grad.set_color(1, Color(0.02, 0.0, 0.0, 0.0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0.62, 0.0)
	var tr: TextureRect = TextureRect.new()
	tr.name = "Shade"
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var g2: Gradient = Gradient.new()
	g2.set_color(0, Color(0.0, 0.0, 0.02, 0.0))
	g2.set_color(1, Color(0.0, 0.0, 0.02, 0.55))
	var gt2: GradientTexture2D = GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill_from = Vector2(0.0, 0.62)
	gt2.fill_to = Vector2(0.0, 1.0)
	var foot: TextureRect = TextureRect.new()
	foot.name = "FootShade"
	foot.texture = gt2
	foot.set_anchors_preset(Control.PRESET_FULL_RECT)
	foot.stretch_mode = TextureRect.STRETCH_SCALE
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)


## T-100: inside the centred 16:9 frame on ultrawide; everything is laid out for 1920 x 1080 and the canvas_items
## stretch scales it (1280 x 720 browser windows included).
func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var inset: float = MenuKit.frame_inset(vp)
	_top.position = Vector2(COL_X + inset - WORDMARK_H * 2048.0 / 940.0 * WORDMARK_PAD, 44.0)   # letters on the rule
	_col_holder.position = Vector2(COL_X + inset, COL_Y)
	_foot.position = Vector2(COL_X + inset, vp.y - 118.0)
	if _version != null:
		_version.position = Vector2(vp.x - inset - COL_X * 0.5 - _version.get_combined_minimum_size().x, vp.y - 52.0)


func _build_footer() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_foot.add_child(head)
	var p: int = ProfileSave.prestige()
	head.add_child(MenuKit.label("RANK %d" % ProfileSave.rank(), 26, MenuKit.INK.lightened(0.3), true))
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(MenuKit.bar(ProfileSave.rank_progress(), 240))
	var card: String = str(ProfileSave.profile.get("equipped", {}).get("calling_card", ""))
	var sub: String = ("Commendation %d   " % p if p > 0 else "") + (_unlock_name(card) if card != "" else "")
	if sub != "":
		col.add_child(MenuKit.label(sub, 18, MenuKit.DIM))
	head.add_child(col)
	_hint = MenuKit.label(hint_text(false), 18, MenuKit.DIM)
	_hint.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 2))
	_foot.add_child(_hint)
	if Net.last_error != "" and not Net.reopen_lobby:
		_foot.add_child(MenuKit.para(Net.last_error, 18, MenuKit.INK.lightened(0.35)))
		Net.last_error = ""


## The footer's keys for the device in hand (pure, unit-tested).
static func hint_text(pad: bool) -> String:
	return "A  select      B  back" if pad else "ENTER  select      ESC  back"


func _process(delta: float) -> void:
	var pad: int = 1 if GLSettings.using_pad else 0
	if _hint != null and pad != _hint_pad:
		_hint_pad = pad
		_hint.text = hint_text(pad == 1)
	_type_tagline(delta)
	_throb_focus()


## The tagline: holds TAGLINE_S, then the next line types in (pure timing in tagline_text, tested).
func _type_tagline(delta: float) -> void:
	if _tag == null:
		return
	_tag_t += delta
	if _tag_t >= TAGLINE_S:
		_tag_t = 0.0
		_tag_i = (_tag_i + 1) % TAGLINES.size()
	_tag.text = tagline_text(_tag_i, _tag_t)


## Line `i` as it reads `t` s after it started typing (line 0 is whole from the first frame).
static func tagline_text(i: int, t: float) -> String:
	var line: String = TAGLINES[posmod(i, TAGLINES.size())]
	if i == 0 and t < TAGLINE_S:
		return line
	return line.substr(0, clampi(int(t * TYPE_CPS), 0, line.length()))


## The focused link's dried-blood plate swells with the heartbeat.
func _throb_focus() -> void:
	if _links == null or dread == null:
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == null or not _links.is_ancestor_of(f) or not f.has_meta("link_box"):
		return
	var sb: StyleBoxFlat = f.get_meta("link_box") as StyleBoxFlat
	var k: float = DreadFx.picture_k()
	sb.bg_color.a = 0.13 + 0.07 * dread.pulse * k
	sb.shadow_color.a = 0.16 + 0.2 * dread.pulse * k


## A link's plate in dried blood instead of the Marke violet (the tween in MenuKit.menu_link moves only the alphas).
static func bleed_link(b: Button) -> void:
	var sb: StyleBoxFlat = b.get_meta("link_box") as StyleBoxFlat
	if sb == null:
		return
	sb.bg_color = Color(BLOOD.r, BLOOD.g, BLOOD.b, sb.bg_color.a)
	sb.shadow_color = Color(BLOOD.r, BLOOD.g, BLOOD.b, sb.shadow_color.a)
	sb.border_color = Color(BLOOD.r * 1.3, BLOOD.g * 1.3, BLOOD.b * 1.3, sb.border_color.a)


func _unlock_name(item_id: String) -> String:
	for u: Dictionary in ProfileSave.unlock_rows():
		if str(u["id"]) == item_id:
			return str(u["name"])
	return item_id.replace("card_", "").replace("_", " ").capitalize()


# ================================================================== columns

## T-203: Extras > Cutscenes: the Archive's cutscene gallery (every LAZARUS cutscene and campaign hop, to rewatch).
func _open_cutscenes() -> void:
	if _screen != null and is_instance_valid(_screen) and not _screen.get("_closing"):
		return
	var a: MenuArchive = MenuArchive.new()
	a.gallery = true
	_screen = a
	_show_screen(a)


## [label, Callable] rows of a column.
func column_rows(which: String) -> Array:
	match which:
		"play":
			return [["Solo", open_screen.bind(MenuCharacter)], ["Online", open_screen.bind(MenuLobby)],
				["Campaign", _open_campaign], ["Back", show_column.bind("main", true)]]
		"extras":
			return [["Cutscenes", _open_cutscenes], ["Dossiers", open_screen.bind(MenuDossiers)], ["Service Record", open_screen.bind(MenuStats)],
				["Challenges", open_screen.bind(MenuChallenges)], ["Credits", open_screen.bind(MenuCredits)],
				["Test Range", func() -> void: get_tree().change_scene_to_file(TEST_RANGE)], ["Back", show_column.bind("main", true)]]
		"quit":
			var rows: Array = [["Terms & Conditions", func() -> void: get_tree().change_scene_to_file(HUB)]]
			if not OS.has_feature("web"):
				rows.append(["Quit to Desktop", func() -> void: get_tree().quit()])
			rows.append(["Back", show_column.bind("main", true)])
			return rows
	return [["Play", show_column.bind("play", true)], ["Muster", open_screen.bind(MenuMuster)],
		["Archive", open_screen.bind(MenuArchive)], ["Extras", show_column.bind("extras", true)],
		["Settings", open_screen.bind(MenuSettings)], ["Quit", show_column.bind("quit", true)]]


func show_column(which: String, animate: bool = true) -> void:
	var old: HBoxContainer = _col
	var going_in: bool = which != "main"
	if old != null and _links != null:
		var f: Control = get_viewport().gui_get_focus_owner()
		if f != null and _links.is_ancestor_of(f):
			_last_focus[column] = str(f.name)
		old.name = "OldColumn"
		MenuKit.transition_out(old, old.queue_free, -1.0 if going_in else 1.0, 0.14)
	column = which
	_col = HBoxContainer.new()
	_col.name = "Column"
	_col.add_theme_constant_override("separation", 22)
	_col_holder.add_child(_col)
	_links = VBoxContainer.new()
	_links.name = "Links"
	_links.add_theme_constant_override("separation", 2)
	var rows: Array = column_rows(which)
	var size_px: int = 40 if which == "main" else 36
	var rule: ColorRect = MenuKit.rule(rows.size() * size_px * 1.55 + (rows.size() - 1) * 2.0, 2.0, BLOOD)
	_col.add_child(rule)
	_col.add_child(_links)
	if which != "main":
		var crumb: Label = MenuKit.label(which.to_upper(), 20, MenuKit.VIOLET.lightened(0.2))
		crumb.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 6))
		crumb.name = "Crumb"
		crumb.position = Vector2(26.0, -34.0)
		crumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col_holder.add_child(crumb)   # beside the column, not in it (the HBox would line it up)
		_col.tree_exiting.connect(crumb.queue_free)
	for r: Array in rows:
		var b: Button = MenuKit.menu_link(str(r[0]), r[1] as Callable, size_px)
		bleed_link(b)
		if str(r[0]) == "Back":
			b.add_theme_color_override("font_color", MenuKit.DIM)
		_links.add_child(b)
	_wire_focus()
	if animate:
		AudioDirector.play_2d("ui_whoosh", 0.0, 0.03)
		MenuKit.transition_in(_col, 1.0 if going_in else -1.0)
	_focus_column()


## Up / down wrap round the column (keyboard and pad).
func _wire_focus() -> void:
	var n: int = _links.get_child_count()
	for i: int in n:
		var b: Control = _links.get_child(i) as Control
		b.focus_neighbor_top = b.get_path_to(_links.get_child(posmod(i - 1, n)))
		b.focus_neighbor_bottom = b.get_path_to(_links.get_child(posmod(i + 1, n)))
		b.focus_neighbor_left = b.get_path()
		b.focus_neighbor_right = b.get_path()


func _focus_column() -> void:
	if _links == null or _links.get_child_count() == 0:
		return
	MenuKit.quiet()
	var want: String = str(_last_focus.get(column, ""))
	var target: Control = _links.get_child(0) as Control
	if want != "" and _links.has_node(want):
		target = _links.get_node(want) as Control
	target.grab_focus.call_deferred()


func link(label_text: String) -> Button:
	if _links == null:
		return null
	for c: Node in _links.get_children():
		if (c as Button).text == label_text.to_upper():
			return c as Button
	return null


# ================================================================== pages

func open_screen(screen_script: GDScript) -> MenuScreen:
	if _screen != null and is_instance_valid(_screen) and not _screen.get("_closing"):
		return null
	_screen = screen_script.new() as MenuScreen
	return _show_screen(_screen)


func _open_campaign() -> void:
	if _screen != null and is_instance_valid(_screen) and not _screen.get("_closing"):
		return
	var mc: MenuCharacter = MenuCharacter.new()
	mc.campaign_only = true
	_screen = mc
	_show_screen(mc)


func _show_screen(s: MenuScreen) -> MenuScreen:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null and _links != null and _links.is_ancestor_of(f):
		_last_focus[column] = str(f.name)
	AudioDirector.play_2d("ui_whoosh", 0.0, 0.03)
	_col_holder.visible = false
	_top.modulate.a = 0.0
	_foot.visible = false
	if scene != null:
		scene.dread_enabled = false   # no beats over a page
	add_child(s)
	s.closed.connect(_on_closed)
	return s


func _exit_tree() -> void:
	AudioDirector.stop_music()   # leaving for a map (or quitting): the menu theme ends with the menu


func _on_closed() -> void:
	_screen = null
	if scene != null:
		scene.dread_enabled = true
	_col_holder.visible = true
	_foot.visible = true
	create_tween().tween_property(_top, "modulate:a", 1.0, 0.25)
	MenuKit.transition_in(_col, -1.0)
	_focus_column()


func _unhandled_input(event: InputEvent) -> void:
	if _screen != null and is_instance_valid(_screen):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioDirector.play_2d("ui_back", 0.0, 0.0)
		show_column("quit" if column == "main" else "main", true)
