class_name StarMap
extends Control
## Minimal Bolt & Sprocket star map (M3). Planets in CAMPAIGN order from data/bs/planets.json, with names and
## taglines from the web build's LEVELS table, lock state (planetLocked rules: always / cleared:<id> / cores:<n>),
## "★ found / total" gold, and travel to the built ones. The full port (ship cockpit, mission tracker, travel
## sequence, flyovers; BS_LEVELS section 9) is M4. Opened from the planet summary and from the hub.

const SCENE: String = "res://ui/bs/star_map.tscn"
const MENU_SCENE: String = "res://ui/main_menu.tscn"

var planets: Array = []
var text: Dictionary = {}
var _buttons: Array[Button] = []
var _info: Label


static func open(tree: SceneTree) -> void:
	tree.paused = false
	BS.ui_block = 0
	tree.change_scene_to_file.call_deferred(SCENE)


func _ready() -> void:
	Game.set_mode(Game.Mode.BOLT_AND_SPROCKET)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var d: Dictionary = Data.table("bs/planets")
	planets = d.get("campaign", [])
	text = d.get("text", {})
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stars: Control = _Stars.new()
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stars)
	var v: VBoxContainer = VBoxContainer.new()
	v.position = Vector2(120, 80)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(BSStyle.label(BSText.text("html.starmap.001") if BSText.has("html.starmap.001") else str(text.get("title", "STAR MAP")), 60, BSStyle.YELLOW, 10))
	var levels: Array = Data.table("bs_source/LEVELS") if Data.has_table("bs_source/LEVELS") else []
	for i: int in planets.size():
		var p: Dictionary = planets[i]
		var idx: int = int(p.get("index", 0))
		var lv: Dictionary = levels[idx] if idx < levels.size() and levels[idx] is Dictionary else {}
		var name_s: String = str(lv.get("name", str(p.get("level_id", "?")).to_upper()))
		var locked: bool = is_locked(p)
		var built: bool = str(p.get("scene", "")) != "" and ResourceLoader.exists(str(p["scene"]))
		var state: String = str(text.get("locked", "LOCKED")) if locked else (str(text.get("clear", "CLEAR")) if BS.flag("cleared." + str(p["level_id"])) else str(text.get("go", "GO")))
		if not locked and not built:
			state = str(text.get("soon", "Arrives in %s")) % str(p.get("milestone", "M4"))
		var b: Button = BSStyle.button("%s   ★ %d/%d   %s" % [name_s, gold_found(str(p["level_id"])), int(p.get("gold_total", 0)), state],
			BSStyle.CYAN if not locked else BSStyle.DIM, 26)
		b.custom_minimum_size = Vector2(900, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = locked or not built
		b.pressed.connect(travel.bind(i))
		b.focus_entered.connect(_show.bind(str(lv.get("tagline", ""))))
		b.mouse_entered.connect(_show.bind(str(lv.get("tagline", ""))))
		v.add_child(b)
		_buttons.append(b)
	_info = BSStyle.label("", 22, BSStyle.DIM, 4)
	_info.custom_minimum_size = Vector2(900, 40)
	v.add_child(_info)
	var back: Button = BSStyle.button(str(text.get("back", "BACK")), BSStyle.PINK, 24)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(MENU_SCENE))
	v.add_child(back)
	for b: Button in _buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break


func _show(tagline: String) -> void:
	_info.text = tagline


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## planetLocked (BS_LEVELS section 10): always | cleared:<level_id> | cores:<n>
static func is_locked(p: Dictionary) -> bool:
	var rule: String = str(p.get("lock", "always"))
	if rule == "always":
		return false
	if rule.begins_with("cleared:"):
		return not BS.flag("cleared." + rule.substr(8))
	if rule.begins_with("cores:"):
		return cores_taken() < int(rule.substr(6))
	return true


static func cores_taken() -> int:
	var n: int = 0
	for k: Variant in BS.flags.keys():
		if str(k).begins_with("core.") and BS.flag(str(k)):
			n += 1
	return n


static func gold_found(level_id: String) -> int:
	var n: int = 0
	for k: Variant in BS.flags.keys():
		if str(k).begins_with("gold.%s." % level_id) and BS.flag(str(k)):
			n += 1
	return n


func travel(i: int) -> void:
	var p: Dictionary = planets[i]
	if is_locked(p) or str(p.get("scene", "")) == "" or not ResourceLoader.exists(str(p["scene"])):
		return
	BSLevel.pending_cutscene = ""
	get_tree().change_scene_to_file.call_deferred(str(p["scene"]))


## A slow starfield behind the list.
class _Stars extends Control:
	var _pts: PackedVector2Array = []
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		for i: int in 220:
			_pts.append(Vector2(rng.randf(), rng.randf()))

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		for i: int in _pts.size():
			var p: Vector2 = _pts[i]
			var x: float = fmod(p.x * size.x + _t * (4.0 + float(i % 5) * 3.0), size.x)
			var a: float = 0.25 + 0.5 * absf(sin(_t * 0.7 + float(i)))
			draw_circle(Vector2(x, p.y * size.y), 1.0 + float(i % 3) * 0.6, Color(0.8, 0.9, 1.0, a))
