extends CanvasLayer
## Co-op HUD (M7), added by the MapRoot in online matches. Original, in the Ledger style of ui/hud.gd:
##  - the squad ledger (left): each survivor's name in their colour, Scrip, and DOWN / BLED OUT
##  - "<name> is down" markers on screen (clamped to the edges) with the distance, so a teammate can be found
##  - your own last stand: the bleed-out bar and "being revived by ..."; spectating after bleeding out
## Solo with AI teammates (T-031) uses the same ledger through the offline session: bots show their health
## (known here) and everyone's kills come from the BotSquad's count. A bot's bonus perk (U02 section 5) shows as a
## gold-ringed bottle cap at the end of its row.

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const SCRIP_COL: Color = Color(0.95, 0.86, 0.55)

var _font: Font
var _stamp: Font
var _list: VBoxContainer
var _rows: Dictionary = {}      # pid -> Label
var _caps: Dictionary = {}      # pid -> PerkCap (the bonus perk)
var _center: Label
var _bar: ProgressBar
var _markers: Markers


func _init() -> void:
	layer = 11


func _ready() -> void:
	_font = MenuKit.mono_font()   # the ledger: names and Scrip line up
	_stamp = MenuKit.stamp_font()
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	add_child(root)
	_markers = Markers.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.font = _font
	root.add_child(_markers)
	_list = VBoxContainer.new()
	_list.position = Vector2(28, 300)
	_list.add_theme_constant_override("separation", 2)
	root.add_child(_list)
	_center = Label.new()
	_center.add_theme_font_override("font", _stamp)
	_center.add_theme_font_size_override("font_size", MenuKit.size("coop_banner"))
	_center.add_theme_color_override("font_color", PAPER)
	MenuKit.outline(_center, "banner")
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.anchor_left = 0.0
	_center.anchor_right = 1.0
	_center.anchor_top = 0.62
	_center.anchor_bottom = 0.62
	_center.offset_top = 0.0
	_center.offset_bottom = 90.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.62
	_bar.anchor_bottom = 0.62
	_bar.offset_left = -170.0
	_bar.offset_right = 170.0
	_bar.offset_top = 96.0
	_bar.offset_bottom = 106.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = INK.lightened(0.15)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	_bar.add_theme_stylebox_override("background", bg)
	root.add_child(_bar)
	GLBus.player_downed.connect(_on_downed)
	GLBus.player_revived.connect(_on_revived)


func _on_downed(pid: int) -> void:
	if pid != Net.local_player_id():
		_banner("%s is down!" % Net.display_name(pid))


func _on_revived(pid: int, by: int) -> void:
	if pid != Net.local_player_id() and by != Net.local_player_id():
		_banner("%s is back up" % Net.display_name(pid))


func _banner(text: String) -> void:
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner(text, 1.6)


func _process(_delta: float) -> void:
	var s: NetMatch = Net.session
	if s == null:
		return
	visible = GameState.phase != GameState.Phase.MENU
	_list.position.x = MenuKit.hud_margin(get_viewport().get_visible_rect().size).x   # the HUD grid (T-096)
	_list.position.y = maxf(300.0, Minimap.layout_bottom + 50.0)   # clear of the minimap (Update 04, T-065)
	_update_list(s)
	_update_center(s)
	_markers.session = s
	_markers.queue_redraw()


func _update_list(s: NetMatch) -> void:
	var ids: Array[int] = []
	for pid: Variant in s.players.keys():
		ids.append(int(pid))
	ids.sort()
	var sq: BotSquad = get_tree().get_first_node_in_group(&"bot_squad") as BotSquad
	for pid: Variant in _rows.keys():
		if not ids.has(int(pid)):
			(_rows[pid] as Label).get_parent().queue_free()
			_rows.erase(pid)
			_caps.erase(pid)
	for pid2: int in ids:
		if not _rows.has(pid2):
			var l: Label = Label.new()
			l.add_theme_font_override("font", _font)
			l.add_theme_font_size_override("font_size", MenuKit.size("coop_row"))
			MenuKit.outline(l, "hud")
			var hb: HBoxContainer = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 16)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list.add_child(hb)
			hb.add_child(l)
			var cap: PerkCap = PerkCap.new()
			cap.custom_minimum_size = Vector2(22, 22)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cap.bonus = true
			cap.font = _stamp
			hb.add_child(cap)
			_rows[pid2] = l
			_caps[pid2] = cap
		var row: Label = _rows[pid2]
		var state: String = ""
		if s.coop.is_downed(pid2):
			state = "  DOWN %ds" % int(ceil(s.coop.bleed_left(pid2)))
		elif s.coop.is_dead(pid2):
			state = "  BLED OUT"
		var me: String = " (you)" if pid2 == Net.local_player_id() else ""
		var p: Player = s.players[pid2] as Player
		var extra: String = ""
		if p != null and p.is_bot and state == "":
			extra = "  %s" % _health_bar(p.health_fraction())
		if sq != null:
			extra += "  %d kills" % int(sq.kills.get(pid2, 0))
		row.text = "■ %-7s ǂ%-6d%s%s%s" % [Net.display_name(pid2), Economy.get_scrip(pid2), extra, state, me]
		var bp: StringName = PerkManager.bonus_perk(pid2)
		var cap2: PerkCap = _caps.get(pid2) as PerkCap
		if cap2 != null:
			cap2.visible = bp != &""
			var bt: int = PerkManager.tier_of(pid2, bp) if bp != &"" else 1
			if cap2.perk_id != bp or cap2.tier != bt:
				cap2.perk_id = bp
				cap2.tier = bt
				cap2.tooltip_text = "Bonus perk: %s" % PerkManager.tier_name(bp, bt)
				cap2.queue_redraw()
		var col: Color = Net.player_color(pid2) if state == "" else INK.lightened(0.35)
		if not row.has_theme_color_override("font_color") or row.get_theme_color("font_color") != col:
			row.add_theme_color_override("font_color", col)   # only on a change: each set re-themes the row (T-070)


static func _health_bar(frac: float) -> String:
	var n: int = clampi(int(ceil(frac * 5.0)), 0, 5)
	return "▮".repeat(n) + "▯".repeat(5 - n)


func _update_center(s: NetMatch) -> void:
	var me: int = Net.local_player_id()
	_bar.visible = false
	if s.coop.is_downed(me):
		var by: int = s.coop.reviver_of(me)
		if by != 0:
			_center.text = "%s is reviving you..." % Net.display_name(by)
		else:
			_center.text = "YOU'RE DOWN  ·  keep firing, crawl to cover"
		_bar.visible = true
		_bar.value = s.coop.bleed_left(me) / maxf(1.0, float(GLData.table("player")["bleedout_seconds"]))
	elif s.coop.is_dead(me):
		var who: String = s.spectate_name()
		_center.text = "BLED OUT  ·  back next round" + (("\nwatching %s   [%s] next" % [who, Interactable.prompt_key(&"fire")]) if who != "" else "")
	else:
		_center.text = ""


## Downed-teammate markers drawn over the 3D view.
class Markers extends Control:
	var session: NetMatch
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if session == null:
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var sz: Vector2 = get_viewport_rect().size
		for pid: Variant in session.players.keys():
			if int(pid) == Net.local_player_id() or not session.coop.is_downed(int(pid)):
				continue
			var p: Player = session.players[pid]
			var world: Vector3 = p.global_position + Vector3.UP * 0.8
			var behind: bool = cam.is_position_behind(world)
			var sp: Vector2 = cam.unproject_position(world)
			if behind:
				sp = sz - sp
			var margin: float = 48.0
			var clamped: Vector2 = Vector2(clampf(sp.x, margin, sz.x - margin), clampf(sp.y, margin, sz.y - margin))
			if behind:
				clamped.y = sz.y - margin
			var col: Color = Color(0.85, 0.15, 0.1, 0.9)
			var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
			draw_circle(clamped, 15.0 * pulse, Color(0, 0, 0, 0.55))
			draw_rect(Rect2(clamped - Vector2(3, 10), Vector2(6, 20)), col)
			draw_rect(Rect2(clamped - Vector2(10, 3), Vector2(20, 6)), col)
			var d: float = cam.global_position.distance_to(p.global_position)
			if font != null:
				draw_string(font, clamped + Vector2(-60, 34), "%s  %dm" % [Net.display_name(int(pid)), int(d)], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 0.85, 0.8))
