extends CanvasLayer
## Active timed power-ups as stencil labels with countdowns, bottom-center-right ("DOUBLE SCRIP 27").
## Added to the map by the PowerupManager when a match starts. T-096: the stamp face and the HUD outline from the
## kit; the box sits on the HUD grid (ui.json hud: powerup_x right of centre, the bottom margin).

const STENCIL: Color = Color(0.93, 0.89, 0.8)
const WARN: Color = Color(0.85, 0.25, 0.2)

var _box: VBoxContainer
var _labels: Dictionary = {}   # powerup_id -> Label
var _font: Font


func _init() -> void:
	layer = 11


func _ready() -> void:
	_font = MenuKit.stamp_font()
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	add_child(root)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var m: Vector2 = MenuKit.hud_margin(get_viewport().get_visible_rect().size)
	_box.position = Vector2(float(MenuKit.hud("powerup_x", 140.0)), -m.y - 4.0)


func _process(_delta: float) -> void:
	var timers: Dictionary = PowerupManager.active_timers()
	for id: Variant in _labels.keys():
		if not timers.has(id):
			(_labels[id] as Label).queue_free()
			_labels.erase(id)
	for id: Variant in timers.keys():
		var l: Label = _labels.get(id) as Label
		if l == null:
			l = Label.new()
			l.add_theme_font_override("font", _font)
			l.add_theme_font_size_override("font_size", MenuKit.size("hud_powerup"))
			MenuKit.outline(l, "prompt")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_box.add_child(l)
			_labels[id] = l
		var left: float = float(timers[id])
		l.text = "%s  %d" % [PowerupManager.display_name(StringName(str(id))), int(ceil(left))]
		var warn: bool = left < 5.0 and fmod(left, 0.5) < 0.25
		var col: Color = WARN if warn else STENCIL
		if not l.has_theme_color_override("font_color") or l.get_theme_color("font_color") != col:
			l.add_theme_color_override("font_color", col)
