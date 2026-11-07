class_name MenuArchive
extends MenuScreen
## Intel Archive: every document, photo, cylinder and tape found across matches.

const TYPE_NAMES: Dictionary = {"DOC": "Document", "PHOTO": "Photograph", "CYL": "Cylinder", "RADIO": "Radio", "TAPE": "Ledger tape", "PANEL": "Fine-print panel", "STENCIL": "Stencil", "PLAQUE": "Maker's plate", "FORGE": "Brass plate", "CHALK": "Chalk", "CARD": "Boss card"}
const MAP_NAMES: Dictionary = {"0": "Crossroads Inn", "1": "Kaltenbrunn", "2": "Totenhafen", "all": "Operation Gravelight", "cabinets": "Helvetia Automaten AG", "lazarus": "Lazarus (Chetverodnevo)"}

var _reader: Label
## T-194: the cutscene gallery (the LAZARUS cutscenes and the campaign hops) instead of the documents.
var gallery: bool = false


func _init() -> void:
	super._init("Intel Archive")


func build() -> void:
	if gallery:
		_build_gallery()
		return
	var films: Button = MenuKit.button("Cutscenes  (the films: Lazarus Saturday, Fourth Day, Staub, Gravelight One, Moscow 1953, the campaign)", func() -> void:
		gallery = true
		rebuild(), 20)
	films.name = "CutscenesButton"
	content.add_child(films)
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


## T-194: the gallery. Every LAZARUS cutscene plays on its own scene (CinemaTheatre) and comes back here; a campaign
## hop loads its map with nobody in it and plays there (CinemaTheatre.replay_exfil). Every row is always open: the
## prologue is the first thing a player sees, the rest are the campaign's and replaying them spoils nothing new.
func _build_gallery() -> void:
	content.add_child(MenuKit.label("Cutscenes", 24, MenuKit.VIOLET, true))
	var seen: Array = ProfileSave.profile.get("cutscenes_seen", [])
	for r: Variant in CinemaLibrary.gallery():
		var row: Dictionary = r
		var id: String = str(row.get("id", ""))
		var label_text: String = "%s   %s" % [str(row.get("title", id)), str(row.get("year", ""))]
		if str(row.get("kind", "")) == "lazarus" and not seen.has(id):
			label_text += "   (not yet seen)"
		var b: Button = MenuKit.button(label_text, _play_cut.bind(row), 20)
		b.name = "Cut_" + id
		b.custom_minimum_size = Vector2(0, 38)
		content.add_child(b)
	content.add_child(MenuKit.button("Back to the documents", func() -> void:
		gallery = false
		rebuild(), 18, "ui_back"))


func _play_cut(row: Dictionary) -> void:
	var id: String = str(row.get("id", ""))
	if str(row.get("kind", "")) == "exfil":
		var m: StringName = CinemaTheatre.exfil_map(id)
		if m != &"" and Campaign.scene_exists(m):
			CinemaTheatre.replay_exfil(get_tree(), id, m)
		return
	CinemaTheatre.play_ids(get_tree(), [id], "archive")


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
			else _unfound_text(r))


## T-200: a Lazarus document is filed by finding its paper where the story left it; intel turns up at random otherwise.
static func _unfound_text(r: Dictionary) -> String:
	return "A Lazarus document. It lies where the story left it, on the map." if str(r.get("map", "")) == StoryProp.LAZARUS_MAP \
		else "Intel turns up at random spots during matches."
