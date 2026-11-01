extends GutTest
## Map 0 fixed story items (docs/gravelight/LORE.md section 13.1): the intel rows exist and are fixed-placement,
## nothing duplicates an id, every story_props.json placement points at a fixed row (and every fixed row has
## one), the text is subtitle-safe, and StoryProp.spawn_all puts them where the table says.

## INT_MARKE_POSTER (UPDATE 09 section 1, T-137): the recruiting poster on the taproom's notice wall.
const FIXED_IDS: PackedStringArray = ["INT_M0_09", "INT_M0_10", "INT_M0_11", "INT_M0_12", "INT_M0_13", "INT_M0_14", "INT_MARKE_POSTER"]
## Map 2 (LORE.md section 13.2, T-036): the same rules, map "2". INT_MARKE_MEDIC (T-137): the surgeon's notes.
const MAP2_IDS: PackedStringArray = ["INT_M2_01", "INT_M2_02", "INT_M2_03", "INT_M2_04", "INT_MARKE_MEDIC"]
## Map 4 Act IV (LORE.md section 13, the Mondlicht list, UPDATE 07 T-113): the same rules, map "4d". INT_MARKE_TERMS (T-137).
const MAP4D_IDS: PackedStringArray = ["INT_M4_RELAY", "INT_M4_CREWTAGS", "INT_M4_SMILE", "INT_M4_PILCH", "INT_MARKE_TERMS"]
## Map 4 Act III (UPDATE 07, docs/MAP4_FERNFLUG.md 13.1): the British crate's manifest and Hale's program log, in the hangar.
const MAP4C_IDS: PackedStringArray = ["INT_M4_MANIFEST", "INT_M4_PROGRAM"]
## Map 1 (LORE.md section 13.5, T-137): Jakub's refusal on the Maintenance Stairs' second landing.
const MAP1_IDS: PackedStringArray = ["INT_MARKE_JAKUB"]


func _intel() -> Array:
	return GLData.load_json(StoryProp.INTEL_PATH).get("intel", [])


func _props() -> Array:
	return GLData.load_json(StoryProp.DATA_PATH).get("props", [])


func _by_id() -> Dictionary:
	var out: Dictionary = {}
	for r: Dictionary in _intel():
		out[str(r["id"])] = r
	return out


func test_new_ids_exist_fixed_on_map_0() -> void:
	var rows: Dictionary = _by_id()
	for id: String in FIXED_IDS:
		assert_true(rows.has(id), "%s is in intel.json" % id)
		if not rows.has(id):
			continue
		var r: Dictionary = rows[id]
		assert_eq(str(r.get("placement", "")), "fixed", "%s is fixed-placement" % id)
		assert_eq(str(r.get("map", "")), "0", "%s is on Map 0" % id)
		assert_eq(str(r.get("type", "")), "DOC", "%s is a document" % id)
		assert_true(str(r.get("title", "")).length() > 3, "%s has a title" % id)
		var parts: PackedStringArray = StoryReader.split_caption(str(r.get("text", "")))
		assert_true(parts[0].length() > 20, "%s: the first paragraph describes the object (caption)" % id)
		assert_true(parts[1].length() > 40, "%s: there is text after the caption" % id)


func test_no_duplicate_intel_ids() -> void:
	var seen: Dictionary = {}
	for r: Dictionary in _intel():
		var id: String = str(r["id"])
		assert_false(seen.has(id), "duplicate intel id " + id)
		seen[id] = true
	assert_gt(seen.size(), 20, "the archive is not empty")


func test_only_these_rows_are_fixed() -> void:
	var fixed: PackedStringArray = []
	for r: Dictionary in _intel():
		if str(r.get("placement", "")) == "fixed":
			fixed.append(str(r["id"]))
	fixed.sort()
	var want: PackedStringArray = FIXED_IDS.duplicate()
	want.append_array(MAP2_IDS)
	want.append_array(MAP4D_IDS)
	want.append_array(MAP4C_IDS)
	want.append_array(MAP1_IDS)
	want.sort()
	assert_eq(fixed, want, "exactly the section 13.1, 13.2, 13.5 and Mondlicht rows are fixed")


func test_placements_point_at_fixed_rows() -> void:
	var rows: Dictionary = _by_id()
	var placed: Dictionary = {}
	for e: Dictionary in _props():
		var id: String = str(e.get("id", ""))
		assert_true(rows.has(id), "placement %s has an intel row" % id)
		if rows.has(id):
			assert_eq(str((rows[id] as Dictionary).get("placement", "")), "fixed", "placement %s points at a fixed row" % id)
			assert_eq(str((rows[id] as Dictionary).get("map", "")), str(e.get("map", "")), "placement %s is on the row's map" % id)
		assert_false(placed.has(id), "placement %s is not duplicated" % id)
		placed[id] = true
		assert_true(StoryProp.STYLES.has(str(e.get("style", ""))), "placement %s has a known prop style (%s)" % [id, e.get("style", "")])
		var pos: Array = e.get("position", [])
		assert_eq(pos.size(), 3, "placement %s has an xyz position" % id)
		assert_typeof(e.get("yaw", 0.0), TYPE_FLOAT, "placement %s yaw is a number" % id)
	for id: String in FIXED_IDS:
		assert_true(placed.has(id), "fixed row %s has a placement" % id)
	for id2: String in MAP2_IDS:
		assert_true(placed.has(id2), "fixed row %s has a placement" % id2)
		assert_eq(str((rows[id2] as Dictionary).get("map", "")), "2", "%s is on Map 2" % id2)


func test_text_is_subtitle_safe() -> void:
	var rows: Dictionary = _by_id()
	var ids: PackedStringArray = FIXED_IDS.duplicate()
	ids.append_array(MAP2_IDS)
	for id: String in ids:
		if not rows.has(id):
			continue
		var t: String = str((rows[id] as Dictionary).get("text", "")) + str((rows[id] as Dictionary).get("title", ""))
		assert_false(t.contains("<br>"), "%s: <br> converted to newlines" % id)
		assert_false(t.contains("[") or t.contains("]"), "%s: no BBCode-looking brackets" % id)
		assert_false(t.contains("*"), "%s: no markdown emphasis" % id)


func test_spawn_all_places_the_map_0_items() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	assert_eq(StoryProp.spawn_all(root, "0"), 7, "seven Map 0 items (six plus the T-137 poster)")
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	assert_eq(StoryProp.spawn_all(other, "1"), 1, "Jakub's refusal on Map 1 (T-137)")
	var none: Node3D = Node3D.new()
	add_child_autofree(none)
	assert_eq(StoryProp.spawn_all(none, "3"), 0, "none on a map without fixed props")
	var m2: Node3D = Node3D.new()
	add_child_autofree(m2)
	assert_eq(StoryProp.spawn_all(m2, "2"), 4, "four Map 2 items")
	var m4d: Node3D = Node3D.new()
	add_child_autofree(m4d)
	assert_eq(StoryProp.spawn_all(m4d, "4d"), 4, "four Mondlicht items")
	var m4c: Node3D = Node3D.new()
	add_child_autofree(m4c)
	assert_eq(StoryProp.spawn_all(m4c, "4c"), 2, "two Groom Lake items (the manifest, the program log)")
	var by_name: Dictionary = {}
	for c: Node in root.get_children():
		by_name[c.name] = c
	for c2: Node in m2.get_children():
		by_name[c2.name] = c2
	for c3: Node in m4d.get_children() + m4c.get_children():
		by_name[c3.name] = c3
	for e: Dictionary in _props():
		var n: String = "Story_" + str(e["id"])
		assert_true(by_name.has(n), n + " spawned")
		if not by_name.has(n):
			continue
		var p: StoryProp = by_name[n] as StoryProp
		var pos: Array = e["position"]
		assert_almost_eq(p.position, Vector3(float(pos[0]), float(pos[1]), float(pos[2])), Vector3(0.001, 0.001, 0.001), n + " at its position")
		assert_almost_eq(rad_to_deg(p.rotation.y), float(e.get("yaw", 0.0)), 0.01, n + " yaw")
		assert_true(p.is_in_group(&"story_props"), n + " in the story_props group")
		assert_eq(p.title, str((_by_id()[str(e["id"])] as Dictionary)["title"]), n + " knows its title")
		assert_true(p.get_prompt(null).contains(p.title), n + " prompt names the item")
		assert_true(p.net_local(), n + " reading is personal")
