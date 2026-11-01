class_name GameOverScreen
extends CanvasLayer
## Shown when the last survivor goes down: the round reached, the time, and the ledger (T-144: one line per player:
## kills, headshots, Marke kills, Scrip earned, downs, revives) with "The account is closed." typed under it.

signal restart_requested
signal menu_requested


func _init() -> void:
	layer = 40   # T-144: over the HUD (10-15), the subtitles and the pause page
	process_mode = Node.PROCESS_MODE_ALWAYS


## The ledger's columns: [header, player_stats key, team-stats fallback key].
const LEDGER_COLS: Array = [["KILLS", &"kills", &"kills"], ["HEADSHOTS", &"headshots", &"headshots"],
	["MARKE", &"marke_kills", &"marke_kills"], ["SCRIP", &"scrip", &"scrip_earned"], ["DOWNS", &"downs", &"downs"],
	["REVIVES", &"revives", &""]]
const CLOSING_LINE: String = "The account is closed."
const LEDGER_INK: Color = Color(0.2, 0.13, 0.09)

var typed: Label = null
var ledger_rows: int = 0


## T-144: the ledger rows (one per player: kills, headshots, Marke kills, Scrip earned, downs, revives) from the
## match stats' "players" block (MapRoot adds it; the host's copy reaches every client); without one, the squad's
## totals make one row.
static func ledger(stats: Dictionary) -> Array:
	var out: Array = []
	var players: Dictionary = stats.get(&"players", stats.get("players", {})) as Dictionary
	var pids: Array = players.keys()
	pids.sort()
	for pid: Variant in pids:
		var row: Dictionary = players[pid]
		var vals: Array = []
		for c: Array in LEDGER_COLS:
			vals.append(int(row.get(c[1], row.get(String(c[1]), 0))))
		out.append([Net.display_name(int(pid)), vals])
	if out.is_empty():
		var vals2: Array = []
		for c2: Array in LEDGER_COLS:
			vals2.append(int(stats.get(c2[2], 0)) if c2[2] != &"" else 0)
		out.append(["Squad", vals2])
	return out


func show_stats(stats: Dictionary, map_name: String, seconds: float) -> void:
	var font: Font = MenuKit.type_font()
	var mono: Font = MenuKit.mono_font()
	var stamp: Font = MenuKit.stamp_font()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.apply_theme(bg)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.apply_theme(center)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(1180, 0)
	box.add_theme_constant_override("separation", 10)
	box.modulate.a = 0.0
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "THE LEDGER IS CLOSED"
	title.add_theme_font_override("font", stamp)
	title.add_theme_font_size_override("font_size", MenuKit.size("display"))
	title.add_theme_color_override("font_color", Color(0.65, 0.1, 0.09))
	MenuKit.outline(title, "stamp")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var r: int = int(stats.get(&"round", 0))
	var sub: Label = Label.new()
	sub.text = "%s  ·  %d round%s  ·  %d:%02d" % [map_name, r, "" if r == 1 else "s", int(seconds) / 60, int(seconds) % 60]
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", MenuKit.px(28))
	MenuKit.outline(sub, "menu")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	# the ledger page: cream paper, ruled, the survivors' lines in ink
	var page: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = MenuKit.paper_box(0.97)
	psb.set_content_margin_all(22)
	page.add_theme_stylebox_override("panel", psb)
	box.add_child(page)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Ledger"
	grid.columns = 1 + LEDGER_COLS.size()
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	var head_font: Font = MenuKit.spaced(font, 3)
	for i: int in grid.columns:
		var h: Label = Label.new()
		h.text = "SURVIVOR" if i == 0 else str(LEDGER_COLS[i - 1][0])
		h.add_theme_font_override("font", head_font)
		h.add_theme_font_size_override("font_size", 20)
		h.add_theme_color_override("font_color", Color(0.45, 0.12, 0.1))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(h)
	var rows: Array = ledger(stats)
	ledger_rows = rows.size()
	for row: Array in rows:
		var name_l: Label = Label.new()
		name_l.text = str(row[0])
		name_l.add_theme_font_override("font", font)
		name_l.add_theme_font_size_override("font_size", 26)
		name_l.add_theme_color_override("font_color", LEDGER_INK)
		grid.add_child(name_l)
		for v: Variant in row[1]:
			var l: Label = Label.new()
			l.text = _thousands(int(v))
			l.add_theme_font_override("font", mono)   # the numbers in the ledger's mono
			l.add_theme_font_size_override("font_size", 26)
			l.add_theme_color_override("font_color", LEDGER_INK)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)
	typed = Label.new()
	typed.name = "Closing"
	typed.text = CLOSING_LINE
	typed.visible_characters = 0
	typed.add_theme_font_override("font", font)
	typed.add_theme_font_size_override("font_size", 30)
	typed.add_theme_color_override("font_color", MenuKit.PAPER)
	MenuKit.outline(typed, "menu")
	typed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(typed)
	_add_progression(box, font)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 30)
	box.add_child(buttons)
	# Co-op: the host restarts everyone (same map) or takes the squad back to the lobby; a client can leave.
	var coop_client: bool = Net.is_client() and Net.in_match
	var again: Button = _button("Play again" if not Net.is_online() else ("Again, everyone" if Net.is_host() else "Host decides..."), font)
	again.disabled = coop_client
	again.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(again)
	var menu: Button = _button("Main menu" if not Net.is_online() else ("Back to lobby" if Net.is_host() else "Leave"), font)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(menu)
	again.focus_neighbor_right = again.get_path_to(menu)
	menu.focus_neighbor_left = menu.get_path_to(again)
	if coop_client:
		again = menu
	var tw: Tween = create_tween()
	tw.tween_property(bg, "color:a", 0.84, 1.5)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 1.5).set_delay(1.0)
	tw.tween_callback(again.grab_focus)
	# the closing line typed out, a key at a time
	for i2: int in CLOSING_LINE.length():
		tw.tween_interval(0.055)
		tw.tween_callback(func() -> void:
			typed.visible_characters = i2 + 1
			if CLOSING_LINE[i2] != " ":
				AudioDirector.play_2d("ui_tick", -4.0, 0.08))


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _button(text: String, font: Font) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", MenuKit.size("subheading"))
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(240, 54)
	return b


## XP earned, rank bar (with rank-ups), challenge completions and new unlocks (from ProfileSave.last_summary).
func _add_progression(box: VBoxContainer, font: Font) -> void:
	var sm: Dictionary = ProfileSave.last_summary
	if sm.is_empty():
		return
	var line: Label = Label.new()
	var r0: int = int(sm.get("rank_before", 1))
	var r1: int = int(sm.get("rank_after", 1))
	line.text = "+%d XP    Rank %d%s" % [int(sm.get("xp", 0)), r1, ("   (up from %d!)" % r0) if r1 > r0 else ""]
	line.add_theme_font_override("font", font)
	line.add_theme_font_size_override("font_size", 26)
	line.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var pb: ProgressBar = ProgressBar.new()
	pb.max_value = 1.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(520, 10)
	pb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.09, 0.08)
	pb.add_theme_stylebox_override("fill", fill)
	pb.value = 0.0 if r1 > r0 else float(sm.get("progress_before", 0.0))
	box.add_child(pb)
	var bar_tw: Tween = pb.create_tween()
	bar_tw.tween_property(pb, "value", float(sm.get("progress_after", 0.0)), 1.6).set_delay(1.8)
	# Cues land as the bar fills: the rank-up stamp, then the challenge seal.
	if r1 > r0:
		bar_tw.tween_callback(func() -> void: AudioDirector.play_2d("ui_rank_up", 0.0, 0.0))
	if not (sm.get("challenges", []) as Array).is_empty():
		bar_tw.tween_interval(0.5)
		bar_tw.tween_callback(func() -> void: AudioDirector.play_2d("ui_challenge", 0.0, 0.0))
	var extra: PackedStringArray = []
	if int(sm.get("dossier_after", 0)) > int(sm.get("dossier_before", 0)):
		extra.append("%s's dossier reached level %d" % [str(sm.get("character", "")).capitalize(), int(sm["dossier_after"])])
	for c: Variant in sm.get("challenges", []):
		extra.append("Challenge complete: " + str(c))
	for u: Variant in sm.get("unlocks", []):
		extra.append("Unlocked: " + str(u))
	for e: String in extra:
		var l: Label = Label.new()
		l.text = e
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.62, 0.45, 0.85))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
