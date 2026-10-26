class_name BossHud
extends CanvasLayer
## Homage-boss presentation (HB1, docs/HOMAGE_BOSSES.md sections 1.7 and 3.8):
##   - the title card (T-096 art): a ledger page, cream paper with ruled lines and a torn edge, the HUD round stamp's
##     rubber-stamp face in ledger red slammed onto it with the stamp's thunk, the in-world name small beneath the
##     real one (Homage Names Real) or alone (In-World), and a date line in the Ledger's typewriter face; the same
##     timings as before (0.08 s in, 0.22 s slam, 2.2 s hold, 0.6 s out);
##   - the boss bars, top centre: a framed brass-and-ink bar per boss, stacked (the Cousins: three), the boss's name
##     as a small red stamp on the left of the frame, quarter ticks on the bar; a dead boss's bar is struck through
##     like a ledger line; a boss that left (the fail-safe) greys out.
## Created by the encounter (CousinsRound) on the host / solo machine.

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const BRASS: Color = Color(0.72, 0.55, 0.25)
const BRASS_DARK: Color = Color(0.36, 0.25, 0.1)

var cards_shown: Array[String] = []        # big names stamped so far (tests / the smoke)
var _root: Control
var _bars: VBoxContainer
var _rows: Dictionary = {}                 # key -> {"bar", "label", "strike", "boss", "box"}
var _card: Control


func _init() -> void:
	layer = 11
	name = "BossHud"


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(_root)
	add_child(_root)
	_bars = VBoxContainer.new()
	var w: float = float(MenuKit.hud("boss_width", 560.0))
	_bars.anchor_left = 0.5
	_bars.anchor_right = 0.5
	_bars.offset_left = -w * 0.5
	_bars.offset_right = w * 0.5
	_bars.offset_top = float(MenuKit.hud("boss_top", 22.0))
	_bars.add_theme_constant_override("separation", 6)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bars)


## Adds (or re-arms) a boss's bar. `big`/`small` come from HomageBoss.title_for.
func add_bar(key: String, boss: Node, big: String, small: String) -> void:
	if _rows.has(key):
		var r: Dictionary = _rows[key]
		r["boss"] = boss
		(r["strike"] as Control).hide()
		(r["box"] as Control).modulate = Color.WHITE
		return
	var box: BarFrame = BarFrame.new()
	box.custom_minimum_size = Vector2(0, 30)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the name stamp (left) and the bar (right) inside the frame
	var label: Label = Label.new()
	label.text = big
	label.add_theme_font_override("font", MenuKit.stamp_font())
	label.add_theme_font_size_override("font_size", MenuKit.size("boss_name"))
	label.add_theme_color_override("font_color", INK.lightened(0.15))
	MenuKit.outline(label, "stamp")
	label.position = Vector2(12, 4)
	label.rotation = deg_to_rad(-2.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	var sub: Label = null
	if small != "":
		sub = Label.new()
		sub.text = small
		sub.add_theme_font_override("font", MenuKit.type_font())
		sub.add_theme_font_size_override("font_size", MenuKit.size("fine"))
		sub.add_theme_color_override("font_color", PAPER)
		MenuKit.outline(sub, "hud")
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sub)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	box.name_label = label
	box.sub_label = sub
	box.holder = holder
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 1.0
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = INK.lightened(0.08)
	fill.border_color = Color(1.0, 0.55, 0.45, 0.5)
	fill.border_width_top = 1
	bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.02, 0.7)
	bar.add_theme_stylebox_override("background", bg)
	holder.add_child(bar)
	var ticks: Ticks = Ticks.new()
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ticks)
	var strike: ColorRect = ColorRect.new()
	strike.color = Color(0.82, 0.8, 0.74, 0.9)   # the pencil line through a struck ledger entry
	strike.anchor_left = 0.0
	strike.anchor_right = 1.0
	strike.anchor_top = 0.5
	strike.anchor_bottom = 0.5
	strike.offset_left = -6.0
	strike.offset_right = 6.0
	strike.offset_top = -1.5
	strike.offset_bottom = 1.5
	strike.rotation = deg_to_rad(-1.2)
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike.hide()
	holder.add_child(strike)
	_bars.add_child(box)
	box.layout_parts()
	_rows[key] = {"bar": bar, "label": label, "strike": strike, "boss": boss, "box": box}


func has_bar(key: String) -> bool:
	return _rows.has(key)


## Strikes a boss's line (dead) or greys it (left).
func strike(key: String, dead: bool) -> void:
	if not _rows.has(key):
		return
	var r: Dictionary = _rows[key]
	(r["bar"] as ProgressBar).value = 0.0 if dead else (r["bar"] as ProgressBar).value
	(r["strike"] as Control).visible = dead
	(r["box"] as Control).modulate = Color(1, 1, 1, 0.55)
	r["boss"] = null


func is_struck(key: String) -> bool:
	return _rows.has(key) and ((_rows[key] as Dictionary)["strike"] as Control).visible


func _process(_delta: float) -> void:
	for key: Variant in _rows.keys():
		var r: Dictionary = _rows[key]
		var b: Variant = r["boss"]
		if b == null or not is_instance_valid(b):
			r["boss"] = null
			continue
		if (b as Object).has_method("hp_fraction"):
			(r["bar"] as ProgressBar).value = float((b as Object).call("hp_fraction"))


## The red ledger stamp on its ledger page. date_line: the Ledger's typewriter line under it.
func title_card(big: String, small: String, date_line: String = "23.XII.1944  ·  GASTHAUS ZUM KREUZWEG") -> void:
	cards_shown.append(big)
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	var card: VBoxContainer = VBoxContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.3
	card.anchor_bottom = 0.3
	card.offset_left = -420.0
	card.offset_right = 420.0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	_card = card
	var page: LedgerPage = LedgerPage.new()
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(page)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(inner)
	var stamp: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 2
	sb.content_margin_bottom = 6
	stamp.add_theme_stylebox_override("panel", sb)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stamp.rotation = deg_to_rad(-4.0)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stamp)
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", -8)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(sv)
	var l: Label = Label.new()
	l.text = big
	l.add_theme_font_override("font", MenuKit.stamp_font())
	l.add_theme_font_size_override("font_size", MenuKit.size("boss_card"))
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(l)
	if small != "":
		var s: Label = Label.new()
		s.text = small
		s.add_theme_font_override("font", MenuKit.stamp_font())
		s.add_theme_font_size_override("font_size", MenuKit.size("boss_card_small"))
		s.add_theme_color_override("font_color", INK)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(s)
	var d: Label = Label.new()
	d.text = date_line
	d.add_theme_font_override("font", MenuKit.type_font())
	d.add_theme_font_size_override("font_size", MenuKit.size("boss_card_date"))
	d.add_theme_color_override("font_color", Color(0.18, 0.13, 0.08))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(d)
	card.pivot_offset = Vector2(420, 60)
	card.scale = Vector2(1.9, 1.9)
	card.modulate.a = 0.0
	AudioDirector.play_2d("board_slam", -4.0, 0.0)   # the stamp's thunk
	var tw: Tween = card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_interval(2.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(card, "position:y", card.position.y - 220.0, 0.6)
	tw.tween_callback(card.queue_free)


## One boss bar's frame: a dark plate with a brass rule round it, the name stamp left, the bar right.
class BarFrame extends Control:
	var name_label: Label
	var sub_label: Label
	var holder: Control
	const NAME_W: float = 150.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			layout_parts()
			queue_redraw()

	func layout_parts() -> void:
		if holder == null:
			return
		var x0: float = NAME_W
		var with_sub: bool = sub_label != null
		holder.position = Vector2(x0, 8.0 if with_sub else 10.0)
		holder.size = Vector2(maxf(40.0, size.x - x0 - 12.0), 10.0)
		if with_sub:
			sub_label.position = Vector2(x0, 20.0)   # the in-world name typed under the bar
			sub_label.size = Vector2(holder.size.x, 16.0)
			custom_minimum_size = Vector2(0, 40.0)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.03, 0.03, 0.72)
		sb.border_color = BRASS_DARK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		draw_style_box(sb, r)
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(BRASS.r, BRASS.g, BRASS.b, 0.7))   # the brass light on the top edge
		draw_line(Vector2(NAME_W - 8.0, 5.0), Vector2(NAME_W - 8.0, size.y - 5.0), Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.9), 1.0)
		for c: Vector2 in [Vector2(5, 5), Vector2(size.x - 5, 5), Vector2(5, size.y - 5), Vector2(size.x - 5, size.y - 5)]:
			draw_circle(c, 1.6, BRASS)   # rivets


## Quarter ticks over a boss bar.
class Ticks extends Control:
	func _draw() -> void:
		for i: int in [1, 2, 3]:
			var x: float = roundf(size.x * float(i) / 4.0)
			draw_rect(Rect2(x, 0, 1, size.y), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.9), false, 1.0)


## The title card's page: cream ledger paper with blue rules and a red margin line, a torn bottom edge and a shadow.
class LedgerPage extends PanelContainer:
	func _init() -> void:
		var sb: StyleBoxEmpty = StyleBoxEmpty.new()
		sb.set_content_margin_all(22)
		sb.content_margin_bottom = 30
		add_theme_stylebox_override("panel", sb)

	func _draw() -> void:
		var sz: Vector2 = size
		var paper: Color = Color(0.9, 0.86, 0.74, 0.97)
		# shadow
		draw_rect(Rect2(Vector2(4, 6), sz), Color(0, 0, 0, 0.4))
		# the page with a torn bottom edge
		var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0)])
		var n: int = 18
		for i: int in range(n, -1, -1):
			var x: float = sz.x * float(i) / float(n)
			var tear: float = 3.0 + 4.0 * absf(sin(float(i) * 2.3 + 0.7)) + (2.0 if i % 3 == 0 else 0.0)
			pts.append(Vector2(x, sz.y - tear))
		draw_colored_polygon(pts, paper)
		# rules
		var y: float = 30.0
		while y < sz.y - 14.0:
			draw_rect(Rect2(10, y, sz.x - 20, 1), Color(0.45, 0.55, 0.7, 0.4))
			y += 22.0
		draw_rect(Rect2(34, 0, 1, sz.y - 10), Color(0.75, 0.25, 0.2, 0.55))
		# a grimy top edge and a fold
		draw_rect(Rect2(0, 0, sz.x, 3), Color(0.5, 0.42, 0.3, 0.35))
		draw_line(Vector2(sz.x * 0.5, 0), Vector2(sz.x * 0.5, sz.y - 8), Color(0.4, 0.33, 0.22, 0.12), 2.0)
