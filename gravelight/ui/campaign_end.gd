class_name CampaignEndScreen
extends CanvasLayer
## "The campaign continues": shown after an exfil whose target map is not in this build yet (T-033, the third
## map is still being built). The squad made it out: the run's round and stats, the map that was unlocked on
## the profile, and a way back to the menu (co-op: the host takes everyone to the lobby). In the Ledger style
## of game_over.gd.

var _map: MapRoot


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_run(payload: Dictionary, next_map_name: String, map: MapRoot) -> void:
	_map = map
	var font: Font = MenuKit.type_font()
	var stamp: Font = MenuKit.stamp_font()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuKit.apply_theme(bg)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(820, 0)
	box.position = Vector2(-410, -280)
	box.add_theme_constant_override("separation", 12)
	box.modulate.a = 0.0
	MenuKit.apply_theme(box)
	add_child(box)
	var title: Label = Label.new()
	title.text = "THE CAMPAIGN CONTINUES"
	title.add_theme_font_override("font", stamp)
	title.add_theme_font_size_override("font_size", MenuKit.size("display"))
	MenuKit.outline(title, "menu")
	title.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stats: Dictionary = payload.get("stats", {})
	var r: int = int(payload.get("round", 0))
	var sub: Label = Label.new()
	sub.text = "The squad left %s on round %d.\n%s is unlocked on your record. Its shore is not on the maps yet;\nthe Ledger will keep your places warm." % [
		str(Campaign.display_name(StringName(str(payload.get("from", ""))))), r, next_map_name]
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_override("font", MenuKit.body_font())
	sub.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	sub.add_theme_color_override("font_color", Color(0.62, 0.45, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	box.add_child(grid)
	var players: Dictionary = payload.get("players", {})
	var rows: Array = [
		["Kills", stats.get(&"kills", 0)],
		["Headshots", stats.get(&"headshots", 0)],
		["Scrip earned", stats.get(&"scrip_earned", 0)],
		["Doors opened", stats.get(&"doors", 0)],
		["Boards rebuilt", stats.get(&"boards", 0)],
		["Survivors out", players.size()],
		["Time", "%d:%02d" % [int(float(payload.get("elapsed", 0.0))) / 60, int(float(payload.get("elapsed", 0.0))) % 60]],
	]
	for row: Array in rows:
		for i: int in 2:
			var l: Label = Label.new()
			l.text = str(row[i])
			l.add_theme_font_override("font", MenuKit.mono_font() if i == 1 else font)
			l.add_theme_font_size_override("font_size", MenuKit.size("button"))
			l.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 1 else HORIZONTAL_ALIGNMENT_LEFT
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(l)
	var kit: Label = Label.new()
	kit.text = _kit_summary(players)
	kit.add_theme_font_override("font", font)
	kit.add_theme_font_override("font", MenuKit.body_font())
	kit.add_theme_font_size_override("font_size", MenuKit.size("body"))
	kit.add_theme_color_override("font_color", Color(0.75, 0.72, 0.64))
	kit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kit)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var coop_client: bool = Net.is_client() and Net.in_match
	var menu: Button = Button.new()
	menu.text = "Main menu" if not Net.is_online() else ("Back to lobby" if Net.is_host() else "Leave")
	menu.add_theme_font_override("font", font)
	menu.add_theme_font_size_override("font_size", MenuKit.size("subheading"))
	menu.custom_minimum_size = Vector2(260, 54)
	menu.pressed.connect(_to_menu)
	buttons.add_child(menu)
	if coop_client:
		pass   # a client may leave on its own; the host's lobby call also brings it back
	var tw: Tween = create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 1.2).set_delay(0.4)
	tw.tween_callback(menu.grab_focus)


static func _kit_summary(players: Dictionary) -> String:
	var parts: PackedStringArray = []
	var weapons: Dictionary = GLData.table("weapons")
	for pid: Variant in players.keys():
		var p: Dictionary = players[pid]
		var guns: PackedStringArray = []
		for e: Variant in (p.get("inv", {}) as Dictionary).get("s", []):
			var wid: String = str((e as Array)[0])
			var row: Dictionary = (weapons.get("upgraded", {}) as Dictionary).get(wid, (weapons.get("weapons", {}) as Dictionary).get(wid, {}))
			guns.append(str(row.get("name", wid)))
		parts.append("%s: %s, %d Scrip, %d perks" % [str(p.get("character", "?")).capitalize(), ", ".join(guns), int(p.get("scrip", 0)), (p.get("perks", []) as Array).size()])
	return "\n".join(parts)


func _to_menu() -> void:
	if _map != null and is_instance_valid(_map):
		_map.call("_to_menu")
