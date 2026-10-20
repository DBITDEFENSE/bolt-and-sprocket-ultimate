extends Control
## Placeholder front-end hub (M0). The real hub (Blartz's shop at night, the ship outside, a dusty
## Helvetia machine humming in the corner) arrives in M9. Doors show their lock state from the profile.
## M1: the BOLT & SPROCKET door loads Scrapheap Junction; a first run opens with the intro cutscene
## (The Repossession) through BSLevel.pending_cutscene.

const BS_FIRST_LEVEL: String = "res://bs/planets/scrapheap/scrapheap.tscn"
const GRAVELIGHT_MENU: String = "res://gravelight/ui/main_menu.tscn"   # Gravelight's own menu (map select, etc.)

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
		if str(d[1]) == "bs_campaign":
			b.pressed.connect(launch_bolt_and_sprocket)
		elif str(d[1]) == "gl_map00":
			b.pressed.connect(launch_gravelight)
		else:
			b.pressed.connect(func() -> void: _status.text = "%s arrives in %s." % [d[0], d[2]])
		box.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	(box.get_child(1) as Button).grab_focus()


## The Bolt & Sprocket door. Returns false (and says so) while the planet scene isn't built yet.
func launch_bolt_and_sprocket() -> bool:
	if not ResourceLoader.exists(BS_FIRST_LEVEL):
		if _status != null:
			_status.text = BSText.text("bs.ui.menu.bs_missing")
		return false
	BSLevel.pending_cutscene = "intro" if not BS.flag("cs.intro") else ""
	get_tree().change_scene_to_file.call_deferred(BS_FIRST_LEVEL)
	return true


## The GRAVELIGHT door: Gravelight's own menu (map select, characters, archive...). It activates its own
## bindings and screen overlays (GLSettings.activate()).
func launch_gravelight() -> bool:
	if not ResourceLoader.exists(GRAVELIGHT_MENU):
		return false
	get_tree().change_scene_to_file.call_deferred(GRAVELIGHT_MENU)
	return true
