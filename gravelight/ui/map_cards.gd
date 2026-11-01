class_name MapCards
extends RefCounted
## The playable maps as the menus show them (UPDATE 09 section 7, DECISIONS T-144): name, act, the date line, the
## scene, the unlock rule's wording, the map's easter egg (quest id, "" = the map has none) and its 16:9 preview
## (gravelight/ui/map_previews/<id>.png, 960 x 540, rendered from capture_cams.json set u09_menu_previews through
## tools/wsl_capture.sh). The map select's cards and the loading screen read this table; the progress on a card
## (best round, egg done / not done / no egg) comes from ProfileSave.

const PREVIEW_DIR: String = "res://gravelight/ui/map_previews/"
## [id, kicker, name, date line, scene, unlock text, egg quest id]
const ROWS: Array = [
	["map00_crossroads", "MAP 0", "Crossroads Inn", "23 December 1944  ·  Silesia", "res://gravelight/maps/map00_crossroads/map00.tscn",
		"Always open.", "map00_radio"],
	["map01_kaltenbrunn", "MAP 1", "Kaltenbrunn", "Late December 1944  ·  the salt mine", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
		"Reach round 10 at the inn, or answer the radio.", "map01_requiem"],
	["map02_totenhafen", "MAP 2", "Totenhafen", "January 1945  ·  the Baltic pens", "res://gravelight/maps/map02_totenhafen/map02.tscn",
		"Complete \"Requiem for Kaltenbrunn\", or reach round 30 at Kaltenbrunn.", ""],
	["map04a_thalbach", "FERNFLUG  ·  ACT I", "Werk Thalbach", "May 1945  ·  the night shift", "res://gravelight/maps/map04_fernflug/map04a.tscn",
		"Reach round 40 at Totenhafen.", "map04_kuendigung"],
	["map04b_kranich", "FERNFLUG  ·  ACT II", "Der Kranich", "May 1945  ·  over the Atlantic", "res://gravelight/maps/map04_fernflug/map04b.tscn",
		"Board the Kranich at Werk Thalbach (act round 15).", "map04_kuendigung"],
	["map04c_groomlake", "FERNFLUG  ·  ACT III", "Groom Lake", "May 1945  ·  Nevada", "res://gravelight/maps/map04_fernflug/map04c.tscn",
		"Rip out the Kranich's autopilot (act round 20).", "map04_kuendigung"],
	["map04d_mondlicht", "FERNFLUG  ·  ACT IV", "Mondlicht", "May 1945  ·  the Moon", "res://gravelight/maps/map04_fernflug/map04d.tscn",
		"Ride the rocket from Groom Lake (act round 30).", "map04_kuendigung"],
]
const CARD_W: float = 400.0
const PREVIEW_W: float = 384.0


static func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for r: Array in ROWS:
		out.append(str(r[0]))
	return out


static func row(map_id: String) -> Dictionary:
	for r: Array in ROWS:
		if str(r[0]) == map_id:
			return {"id": r[0], "kicker": r[1], "name": r[2], "date": r[3], "scene": r[4], "unlock": r[5], "egg": r[6]}
	return {}


static func id_for_scene(scene_path: String) -> String:
	for r: Array in ROWS:
		if str(r[4]) == scene_path:
			return str(r[0])
	return ""


static func preview_path(map_id: String) -> String:
	return PREVIEW_DIR + map_id + ".png"


## The preview, or a night-blue placeholder when the PNG has not been rendered yet.
static func preview(map_id: String) -> Texture2D:
	var p: String = preview_path(map_id)
	if ResourceLoader.exists(p):
		var t: Texture2D = load(p) as Texture2D
		if t != null:
			return t
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.05, 0.06, 0.1))
	g.set_color(1, Color(0.12, 0.1, 0.16))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 160
	gt.height = 90
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	return gt


## "done" / "not done" / "no egg" for the map's easter egg on this profile.
static func egg_status(map_id: String) -> String:
	var egg: String = str(row(map_id).get("egg", ""))
	if egg == "":
		return "no egg"
	return "done" if ProfileSave.egg_done(egg) else "not done"


static func _box(border: Color, bg: Color, width: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	return sb


## One card: the preview, the kicker, the name, the date line and the progress row. A Button (focusable, pressed =
## `cb`); disabled and stamped LOCKED when `locked`.
static func card(kicker: String, title: String, date: String, preview_tex: Texture2D, progress: Array, cb: Callable,
		locked: bool = false, lock_text: String = "") -> Button:
	var b: Button = Button.new()
	b.name = "Card_" + title.replace(" ", "_")
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(CARD_W, 350)
	var normal: StyleBoxFlat = _box(MenuKit.BRASS_DARK, Color(0.04, 0.04, 0.06, 0.9), 2)
	var lit: StyleBoxFlat = _box(MenuKit.VIOLET, Color(0.08, 0.06, 0.12, 0.95), 3)
	lit.shadow_color = Color(MenuKit.VIOLET.r, MenuKit.VIOLET.g, MenuKit.VIOLET.b, 0.35)
	lit.shadow_size = 14
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("disabled", _box(Color(0.25, 0.22, 0.2), Color(0.03, 0.03, 0.04, 0.85), 2))
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.position = Vector2(8, 8)
	v.size = Vector2(PREVIEW_W, 334)
	v.add_theme_constant_override("separation", 3)
	b.add_child(v)
	var pic: TextureRect = TextureRect.new()
	pic.name = "Preview"
	pic.texture = preview_tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(PREVIEW_W, PREVIEW_W * 9.0 / 16.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		pic.modulate = Color(0.32, 0.32, 0.36)
	v.add_child(pic)
	var k: Label = MenuKit.label(kicker, 16, MenuKit.VIOLET.lightened(0.2))
	k.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 4))
	v.add_child(k)
	var n: Label = MenuKit.label(title, 28, MenuKit.PAPER if not locked else MenuKit.DIM)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(PREVIEW_W, 0)
	v.add_child(n)
	var d: Label = MenuKit.para(date, 17, MenuKit.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.custom_minimum_size = Vector2(PREVIEW_W, 0)
	v.add_child(d)
	if locked:
		var lt: Label = MenuKit.para(lock_text, 15, MenuKit.DIM)
		lt.custom_minimum_size = Vector2(PREVIEW_W, 0)
		lt.max_lines_visible = 2
		v.add_child(lt)
		var stamp: Label = MenuKit.label("LOCKED", 40, MenuKit.INK.lightened(0.15), true)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.rotation = deg_to_rad(-8.0)
		stamp.position = Vector2(PREVIEW_W * 0.5 - 70.0, PREVIEW_W * 9.0 / 32.0 - 10.0)
		b.add_child(stamp)
	else:
		var h: HBoxContainer = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 18)
		v.add_child(h)
		for p: Variant in progress:
			var pa: Array = p
			var l: Label = MenuKit.label(str(pa[0]), 17, pa[1] as Color)
			l.add_theme_font_override("font", MenuKit.spaced(MenuKit.mono_font(), 1))
			h.add_child(l)
	b.disabled = locked
	b.focus_entered.connect(func() -> void:
		if not MenuKit.is_quiet():
			AudioDirector.play_2d("ui_tick", 0.0, 0.06))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	if cb.is_valid():
		b.pressed.connect(func() -> void: AudioDirector.play_2d("ui_stamp", 0.0, 0.03))
		b.pressed.connect(cb)
	return b


## A map's card from the table and the profile (best round, egg status, locked or open).
static func map_card(map_id: String, cb: Callable) -> Button:
	var r: Dictionary = row(map_id)
	var open: bool = ProfileSave.is_map_unlocked(StringName(map_id))
	var best: int = ProfileSave.best_round(StringName(map_id))
	var egg: String = egg_status(map_id)
	var prog: Array = [["BEST  " + (str(best) if best > 0 else "—"), MenuKit.GOLD if best > 0 else MenuKit.DIM]]
	match egg:
		"done":
			prog.append(["EGG  DONE", MenuKit.VIOLET.lightened(0.25)])
		"not done":
			prog.append(["EGG  NOT DONE", MenuKit.DIM])
		_:
			prog.append(["NO EGG", MenuKit.DIM.darkened(0.2)])
	var c: Button = card(str(r.get("kicker", "")), str(r.get("name", map_id)), str(r.get("date", "")), preview(map_id), prog, cb,
		not open, "Locked: " + str(r.get("unlock", "")))
	c.set_meta("map_id", map_id)
	c.set_meta("egg", egg)
	c.set_meta("best", best)
	return c
