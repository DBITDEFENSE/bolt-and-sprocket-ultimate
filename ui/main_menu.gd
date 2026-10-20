extends Control
## Placeholder front-end hub (M0). The real hub (Blartz's shop at night, the ship outside, a dusty
## Helvetia machine humming in the corner) arrives in M9. Doors show their lock state from the profile.

const DOORS: Array = [
	["BOLT & SPROCKET", "bs_campaign", "M1"],
	["GRAVELIGHT", "gl_map00", "M2"],
	["THE FINE PRINT", "fp_ch1", "M7"],
	["THE ARCHIVE", "", "M9"],
	["EXTRAS", "", "M6"],
	["SETTINGS", "", "M9"],
]

var _status: Label


func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.045, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title: Label = Label.new()
	title.text = Game.GAME_TITLE
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var open: PackedStringArray = Unlocks.resolve(Data.table("unlocks"), SaveProfile.doc.get("unlocks", []))
	for d: Array in DOORS:
		var b: Button = Button.new()
		var locked: bool = str(d[1]) != "" and not (str(d[1]) in open)
		b.text = str(d[0]) + ("   [LOCKED]" if locked else "")
		b.disabled = locked
		b.custom_minimum_size = Vector2(520, 56)
		b.pressed.connect(func() -> void: _status.text = "%s arrives in %s." % [d[0], d[2]])
		box.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	(box.get_child(1) as Button).grab_focus()
