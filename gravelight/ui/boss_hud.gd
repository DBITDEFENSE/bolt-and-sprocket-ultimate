class_name BossHud
extends CanvasLayer
## Homage-boss presentation (HB1, docs/HOMAGE_BOSSES.md sections 1.7 and 3.8):
##   - the title card: the HUD round stamp's rubber-stamp face in ledger red, slammed onto the screen with the
##     stamp's thunk, the in-world name small beneath the real one (Homage Names Real) or alone (In-World), and a
##     date line in the Ledger's typewriter face; 2.2 s, then it settles into the bars;
##   - the boss bars, top centre: one thin bar per boss, stacked (the Cousins: three), each with its name; a dead
##     boss's bar is struck through like a ledger line; a boss that left (the fail-safe) greys out.
## Created by the encounter (CousinsRound) on the host / solo machine.

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)

var cards_shown: Array[String] = []        # big names stamped so far (tests / the smoke)
var _root: Control
var _bars: VBoxContainer
var _rows: Dictionary = {}                 # key -> {"bar", "label", "strike", "boss"}
var _card: Control
var _stamp_font: SystemFont
var _type_font: SystemFont


func _init() -> void:
	layer = 11
	name = "BossHud"


func _ready() -> void:
	_stamp_font = SystemFont.new()
	_stamp_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_type_font = SystemFont.new()
	_type_font.font_names = PackedStringArray(["Courier New", "Consolas", "Monospace"])
	_type_font.font_weight = 700
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bars = VBoxContainer.new()
	_bars.anchor_left = 0.5
	_bars.anchor_right = 0.5
	_bars.offset_left = -260.0
	_bars.offset_right = 260.0
	_bars.offset_top = 18.0
	_bars.add_theme_constant_override("separation", 4)
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
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.text = big if small == "" else "%s  ·  %s" % [big, small]
	label.add_theme_font_override("font", _type_font)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(520, 8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 1.0
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = INK.lightened(0.1)
	bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(0.3, 0.27, 0.22)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	holder.add_child(bar)
	var strike: ColorRect = ColorRect.new()
	strike.color = Color(0.82, 0.8, 0.74, 0.9)   # the pencil line through a struck ledger entry
	strike.anchor_left = 0.0
	strike.anchor_right = 1.0
	strike.anchor_top = 0.5
	strike.anchor_bottom = 0.5
	strike.offset_left = -14.0
	strike.offset_right = 14.0
	strike.offset_top = -12.0
	strike.offset_bottom = -9.0
	strike.rotation = deg_to_rad(-1.2)
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike.hide()
	holder.add_child(strike)
	_bars.add_child(box)
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


## The red ledger stamp. date_line: the Ledger's typewriter line under it.
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
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = INK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(panel)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", -6)
	panel.add_child(inner)
	var l: Label = Label.new()
	l.text = big
	l.add_theme_font_override("font", _stamp_font)
	l.add_theme_font_size_override("font_size", 92)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(l)
	if small != "":
		var s: Label = Label.new()
		s.text = small
		s.add_theme_font_override("font", _stamp_font)
		s.add_theme_font_size_override("font_size", 30)
		s.add_theme_color_override("font_color", INK)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(s)
	var d: Label = Label.new()
	d.text = date_line
	d.add_theme_font_override("font", _type_font)
	d.add_theme_font_size_override("font_size", 18)
	d.add_theme_color_override("font_color", PAPER)
	d.add_theme_constant_override("outline_size", 4)
	d.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(d)
	card.rotation = deg_to_rad(-4.0)
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
