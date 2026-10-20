class_name GameOverScreen
extends CanvasLayer
## Shown when the last survivor goes down. Shows the round reached and match stats.

signal restart_requested
signal menu_requested


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_stats(stats: Dictionary, map_name: String, seconds: float) -> void:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas"])
	font.font_weight = 700
	var stamp: SystemFont = SystemFont.new()
	stamp.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 0)
	box.position = Vector2(-380, -300)
	box.add_theme_constant_override("separation", 10)
	box.modulate.a = 0.0
	add_child(box)
	var title: Label = Label.new()
	title.text = "THE LEDGER IS CLOSED"
	title.add_theme_font_override("font", stamp)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.65, 0.1, 0.09))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var r: int = int(stats.get(&"round", 0))
	var sub: Label = Label.new()
	sub.text = "%s  ·  You survived %d round%s" % [map_name, r, "" if r == 1 else "s"]
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	box.add_child(grid)
	var rows: Array = [
		["Kills", stats.get(&"kills", 0)],
		["Headshots", stats.get(&"headshots", 0)],
		["Knife kills", stats.get(&"melee_kills", 0)],
		["Scrip earned", stats.get(&"scrip_earned", 0)],
		["Doors opened", stats.get(&"doors", 0)],
		["Boards rebuilt", stats.get(&"boards", 0)],
		["Time", "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]],
	]
	for row: Array in rows:
		for i: int in 2:
			var l: Label = Label.new()
			l.text = str(row[i])
			l.add_theme_font_override("font", font)
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 1 else HORIZONTAL_ALIGNMENT_LEFT
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(l)
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
	if coop_client:
		again = menu
	var tw: Tween = create_tween()
	tw.tween_property(bg, "color:a", 0.82, 1.5)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 1.5).set_delay(1.0)
	tw.tween_callback(again.grab_focus)


func _button(text: String, font: Font) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 26)
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
