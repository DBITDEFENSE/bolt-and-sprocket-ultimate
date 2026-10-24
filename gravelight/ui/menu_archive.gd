class_name MenuArchive
extends MenuScreen
## Intel Archive: every document, photo, cylinder and tape found across matches.

const TYPE_NAMES: Dictionary = {"DOC": "Document", "PHOTO": "Photograph", "CYL": "Cylinder", "RADIO": "Radio", "TAPE": "Ledger tape", "PANEL": "Fine-print panel", "STENCIL": "Stencil", "PLAQUE": "Maker's plate", "FORGE": "Brass plate", "CHALK": "Chalk"}
const MAP_NAMES: Dictionary = {"0": "Crossroads Inn", "1": "Kaltenbrunn", "2": "Totenhafen", "all": "Operation Gravelight", "cabinets": "Helvetia Automaten AG"}

var _reader: Label


func _init() -> void:
	super._init("Intel Archive")


func build() -> void:
	var rows: Array = _grouped(ProfileSave.intel_rows())
	var found: int = 0
	for r: Dictionary in rows:
		if ProfileSave.has_intel(str(r["id"])):
			found += 1
	content.add_child(MenuKit.label("%d / %d recovered" % [found, rows.size()], 22, MenuKit.GOLD))
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	content.add_child(split)
	var list: VBoxContainer = VBoxContainer.new()
	list.custom_minimum_size = Vector2(620, 0)
	split.add_child(list)
	_reader = MenuKit.para("Select an entry.", 20)
	_reader.custom_minimum_size = Vector2(520, 0)
	_reader.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	split.add_child(_reader)
	var last_map: String = ""
	for r: Dictionary in rows:
		var m: String = str(r["map"])
		if m != last_map:
			last_map = m
			list.add_child(MenuKit.label(str(MAP_NAMES.get(m, m)), 24, MenuKit.VIOLET, true))
		var have: bool = ProfileSave.has_intel(str(r["id"]))
		var title: String = ("%s  (%s)" % [r["title"], TYPE_NAMES.get(str(r["type"]), r["type"])]) if have else "???  (not yet recovered)"
		var b: Button = MenuKit.button(title, _show.bind(r, have), 18)
		b.custom_minimum_size = Vector2(0, 36)
		b.focus_entered.connect(_show.bind(r, have))
		list.add_child(b)


## The rows grouped by map, each map's rows in their own order (one header per map even when a later section of the
## table adds to an earlier map, like Jakub's letter).
static func _grouped(rows: Array) -> Array:
	var order: Array = []
	for r: Variant in rows:
		var m: String = str((r as Dictionary).get("map", ""))
		if not order.has(m):
			order.append(m)
	var out: Array = []
	for m2: Variant in order:
		for r2: Variant in rows:
			if str((r2 as Dictionary).get("map", "")) == str(m2):
				out.append(r2)
	return out


func _show(r: Dictionary, have: bool) -> void:
	if have:
		_reader.text = "%s\n%s\n\n%s" % [r["title"], TYPE_NAMES.get(str(r["type"]), r["type"]), r["text"]]
	else:
		_reader.text = "Not yet recovered.\n\n" + ("Somebody in the Crossroads Inn's cellar is waiting to be let out." if str(r.get("placement", "")) == "companion" \
			else "Intel turns up at random spots during matches.")
