extends CanvasLayer
## Active timed power-ups as stencil labels with countdowns, bottom-center-right ("DOUBLE SCRIP 27").
## Added to the map by the PowerupManager when a match starts.

const STENCIL: Color = Color(0.93, 0.89, 0.8)
const WARN: Color = Color(0.85, 0.25, 0.2)

var _box: VBoxContainer
var _labels: Dictionary = {}   # powerup_id -> Label
var _font: SystemFont


func _init() -> void:
	layer = 11


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.position = Vector2(140, -60)
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)


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
			l.add_theme_font_size_override("font_size", 30)
			l.add_theme_constant_override("outline_size", 6)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_box.add_child(l)
			_labels[id] = l
		var left: float = float(timers[id])
		l.text = "%s  %d" % [PowerupManager.display_name(StringName(str(id))), int(ceil(left))]
		var warn: bool = left < 5.0 and fmod(left, 0.5) < 0.25
		l.add_theme_color_override("font_color", WARN if warn else STENCIL)
