class_name EggModeTag
extends CanvasLayer
## T-181: a small "EASTER EGG MODE" tag at the top of the screen in a practice match (EggMode), so a screenshot or
## a glance says this run earns nothing on the profile. Its own layer, not part of the HUD scripts.


static func attach(map: Node) -> void:
	if EggMode.on() and DisplayServer.get_name() != "headless":
		map.add_child(EggModeTag.new())


func _ready() -> void:
	layer = 4
	var l: Label = Label.new()
	l.text = "%s (%s)" % [EggMode.HUD_TEXT, EggMode.MODE_LABELS[maxi(0, EggMode.MODES.find(EggMode.current()))]]
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_top = 4.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
