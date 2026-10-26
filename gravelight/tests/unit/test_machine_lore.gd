extends GutTest
## Machine lore completeness (DECISIONS T-075, docs/gravelight/PERKS_LORE.md): every perk machine, Crucible and wall
## gun placed on every built map has its text in data/gravelight/machine_lore.json, and the Archive carries them.

const MAPS: Dictionary = {
	"map00_crossroads": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01_kaltenbrunn": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02_totenhafen": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a_thalbach": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b_kranich": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c_groomlake": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d_mondlicht": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}


## The Gameplay nodes a generated map scene places: Perk_<id>, WallBuy_<id>, Crucible.
func _placed(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var out: Dictionary = {"perk": [], "wall": [], "crucible": false}
	var re: RegEx = RegEx.create_from_string("\\[node name=\"(Perk|WallBuy)_([a-z0-9_]+)\" type=\"Node3D\" parent=\"Gameplay\"")
	for m: RegExMatch in re.search_all(text):
		(out["perk" if m.get_string(1) == "Perk" else "wall"] as Array).append(m.get_string(2))
	out["crucible"] = text.contains("[node name=\"Crucible\" type=\"Node3D\" parent=\"Gameplay\"")
	return out


func test_every_placed_thing_has_lore() -> void:
	for mid: String in MAPS.keys():
		var placed: Dictionary = _placed(MAPS[mid])
		assert_gt((placed["perk"] as Array).size(), 0, mid + " places perk machines")
		for pk: String in placed["perk"]:
			var e: Dictionary = MachineLore.entry(StringName(mid), "perk." + pk)
			assert_ne(str(e.get("plate", "")), "", "%s %s has a plate line" % [mid, pk])
			assert_gt(str(e.get("text", "")).length(), 200, "%s %s has an Archive text" % [mid, pk])
			assert_ne(str(e.get("title", "")), "", "%s %s has an Archive title" % [mid, pk])
		for wid: String in placed["wall"]:
			assert_ne(MachineLore.plate(StringName(mid), "chalk." + wid), "", "%s wall gun %s has a chalk line" % [mid, wid])
		assert_true(placed["crucible"], mid + " has a Crucible")
		assert_gt(str(MachineLore.entry(StringName(mid), "crucible").get("text", "")).length(), 200, mid + " Crucible text")
		assert_false(MachineLore.row(StringName(mid), "chalk").is_empty(), mid + " has its chalk entry")


func test_archive_rows_are_in_the_profile_archive() -> void:
	var ids: Array = ProfileSave.intel_rows().map(func(r: Dictionary) -> String: return str(r["id"]))
	var rows: Array = MachineLore.archive_rows()
	assert_gt(rows.size(), 25)
	for r: Dictionary in rows:
		assert_true(ids.has(str(r["id"])), str(r["id"]) + " is in the Archive")
		assert_true(["0", "1", "2", "4a", "4b", "4c", "4d"].has(str(r["map"])), "%s files under a map (%s)" % [r["id"], r["map"]])


func test_chalk_entry_lists_the_guns() -> void:
	var r: Dictionary = MachineLore.row(&"map00_crossroads", "chalk")
	assert_string_contains(str(r["text"]).to_lower(), "standing order 17")
	assert_string_contains(str(r["text"]), "Thompson")


func test_no_forbidden_words_in_world_text() -> void:
	for r: Dictionary in MachineLore.archive_rows():
		var t: String = (str(r["title"]) + " " + str(r["text"])).to_lower()
		assert_false(t.contains("subscription") or t.contains("darkmatter"), str(r["id"]) + " keeps the writer rule (LORE.md 2.4)")
