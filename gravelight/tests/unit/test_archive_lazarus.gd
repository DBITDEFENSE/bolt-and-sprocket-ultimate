extends GutTest
## UPDATE 11 (T-200, contract C7): the Lazarus Archive documents (data/gravelight/archive_lazarus.json) are each placed
## once as a story prop on their map (story_props.json, the same system as the fixed items: no Easter egg step), read
## their own body text, and the Archive lists every one of them on its Lazarus shelf in `order`.

const MAP_KEYS: PackedStringArray = ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]


func _entries() -> Array:
	return GLData.load_json(StoryProp.ARCHIVE_PATH).get("entries", [])


func _props() -> Array:
	return GLData.load_json(StoryProp.DATA_PATH).get("props", [])


func test_seventeen_entries_with_unique_ids_and_orders() -> void:
	var ids: Dictionary = {}
	var orders: Dictionary = {}
	for e: Dictionary in _entries():
		var id: String = str(e["id"])
		assert_false(ids.has(id), "duplicate archive id " + id)
		assert_false(orders.has(int(e["order"])), "duplicate archive order %s" % str(e["order"]))
		ids[id] = true
		orders[int(e["order"])] = true
	assert_eq(_entries().size(), 17, "the seventeen Lazarus documents")


func test_every_entry_has_one_placement_on_its_map() -> void:
	var placed: Dictionary = {}
	for p: Dictionary in _props():
		var id: String = str(p.get("id", ""))
		if not id.begins_with("ARC_LZ_"):
			continue
		assert_false(placed.has(id), "placement %s is not duplicated" % id)
		placed[id] = str(p.get("map", ""))
	for e: Dictionary in _entries():
		var id: String = str(e["id"])
		assert_true(placed.has(id), "%s has a story prop placement" % id)
		var want: String = str(StoryProp.ARCHIVE_MAP_KEYS.get(str(e["map"]), "?"))
		assert_eq(str(placed.get(id, "")), want, "%s is placed on its map (%s)" % [id, str(e["map"])])
	assert_eq(placed.size(), _entries().size(), "no placement without an archive entry")


func test_placed_items_spawn_on_their_maps() -> void:
	var seen: Dictionary = {}
	for m: String in MAP_KEYS:
		var key: String = str(StoryProp.ARCHIVE_MAP_KEYS[m])
		var root: Node3D = Node3D.new()
		add_child_autofree(root)
		StoryProp.spawn_all(root, key)
		for c: Node in root.get_children():
			var sp: StoryProp = c as StoryProp
			if sp != null and str(sp.intel_id).begins_with("ARC_LZ_"):
				seen[str(sp.intel_id)] = true
				assert_true(sp.is_in_group(&"story_props"), "%s in the story_props group" % str(sp.intel_id))
				assert_true(sp.get_prompt(null).contains(sp.title), "%s prompt names the document" % str(sp.intel_id))
	assert_eq(seen.size(), _entries().size(), "every Lazarus item spawns on its map")


func test_each_map_has_exactly_one_diary_page() -> void:
	var diaries: Dictionary = {}
	for e: Dictionary in _entries():
		if str(e["kind"]) == "diary":
			diaries[str(e["map"])] = int(diaries.get(str(e["map"]), 0)) + 1
	for m: String in MAP_KEYS:
		assert_eq(int(diaries.get(m, 0)), 1, "%s has exactly one diary page" % m)
	assert_eq(diaries.size(), MAP_KEYS.size(), "diary pages only on the seven listed maps")


func test_archive_lists_them_all_in_order() -> void:
	var want: Array = _entries().duplicate()
	want.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	var shelf: Array = []
	for r: Dictionary in ProfileSave.intel_rows():
		if str(r.get("map", "")) == StoryProp.LAZARUS_MAP:
			shelf.append(r)
	assert_eq(shelf.size(), want.size(), "the Archive's Lazarus shelf lists all seventeen")
	for i: int in mini(shelf.size(), want.size()):
		assert_eq(str(shelf[i]["id"]), str(want[i]["id"]), "shelf row %d in order" % i)
		assert_eq(str(shelf[i]["text"]), str(want[i]["body"]), "%s reads its body text" % str(want[i]["id"]))
		assert_eq(str(shelf[i]["title"]), str(want[i]["title"]), "%s has its title" % str(want[i]["id"]))


func test_reading_a_placed_document_reads_its_entry() -> void:
	for e: Dictionary in _entries():
		var row: Dictionary = StoryProp.intel_row(StringName(str(e["id"])))
		assert_eq(str(row.get("text", "")), str(e["body"]), "%s row is the archive body" % str(e["id"]))
		var parts: PackedStringArray = StoryReader.split_caption(str(row.get("text", "")))
		assert_true(parts[0].length() > 20, "%s: the first paragraph is the caption" % str(e["id"]))


func test_lazarus_documents_are_not_intel_rows() -> void:
	# they are filed by their props only: no random Archive pickup, no intel.json row to spawn
	for r: Dictionary in GLData.load_json(StoryProp.INTEL_PATH).get("intel", []):
		assert_false(str(r.get("id", "")).begins_with("ARC_LZ_"), "%s is not in intel.json" % str(r.get("id", "")))
