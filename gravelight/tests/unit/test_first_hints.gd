extends GutTest
## UPDATE 10 s6 item 7 (T-162): the first-time hints. Every hint in data/gravelight/hints.json names its map and a
## condition the watcher understands, shows once per profile (ProfileSave flag `hints_seen`), only on its own map, and
## the pure condition rules (`FirstHints.met`) behave. The nine situations of the work order are all there.

const WANTED: PackedStringArray = ["tide", "ballast", "searchlight", "wing_walk", "dust_storm", "raid", "terminator", "visor"]
const KINDS: PackedStringArray = ["prop", "near", "exists", "special_round"]

var _saved_path: String = ""
var _fh: FirstHints
var _map: MapRoot


func before_all() -> void:
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_hints_%d.json" % OS.get_process_id()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()


func before_each() -> void:
	ProfileSave.profile = ProfileSave.new_profile()
	_fh = FirstHints.new()
	_map = MapRoot.new()   # (never added to the tree: only map_id and hud are read)
	_fh.map = _map


func after_each() -> void:
	_fh.free()
	_map.free()


func test_all_the_situations_have_a_hint() -> void:
	var t: Dictionary = FirstHints.table()
	for k: String in WANTED:
		assert_true(t.has(k), "hint %s exists" % k)
	for k: String in t:
		var row: Dictionary = t[k]
		assert_true(str(row.get("map", "")).begins_with("map0"), "%s names its map" % k)
		assert_gt(str(row.get("text", "")).length(), 40, "%s has real text" % k)
		assert_lt(str(row.get("text", "")).length(), 220, "%s fits the banner" % k)
		assert_has(KINDS, str((row.get("when", {}) as Dictionary).get("kind", "")), "%s has a known condition" % k)


func test_each_hint_fires_once_on_its_map() -> void:
	var t: Dictionary = FirstHints.table()
	for k: String in t:
		var row: Dictionary = t[k]
		_map.map_id = StringName(str(row["map"]) + "_x")
		assert_false(FirstHints.seen(k), "%s is unseen on a fresh profile" % k)
		assert_true(_fh.try_show(k), "%s shows" % k)
		assert_true(FirstHints.seen(k), "%s is recorded" % k)
		assert_false(_fh.try_show(k), "%s does not show twice" % k)
	assert_eq(_fh.shown.size(), t.size(), "every hint showed exactly once")


func test_a_hint_stays_on_its_own_map() -> void:
	_map.map_id = &"map00_crossroads"
	for k: String in FirstHints.table():
		assert_false(_fh.try_show(k), "%s does not show on the inn" % k)
		assert_false(FirstHints.seen(k), "%s is not recorded off its map" % k)


func test_seen_survives_a_save_and_load() -> void:
	FirstHints.mark("tide")
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.load_profile()
	assert_true(FirstHints.seen("tide"), "the flag is in the saved profile")
	assert_false(FirstHints.seen("raid"))


func test_conditions() -> void:
	var n: Node3D = Node3D.new()
	n.set_meta("x", true)
	assert_false(FirstHints.met({"kind": "prop", "prop": "visible"}, null, INF, 0.0, false), "no node, no hint")
	assert_true(FirstHints.met({"kind": "prop", "prop": "visible"}, n, 0.0, 0.0, false), "a true bool prop")
	n.visible = false
	assert_false(FirstHints.met({"kind": "prop", "prop": "visible"}, n, 0.0, 0.0, false), "a false bool prop")
	n.rotation.y = 0.3
	assert_true(FirstHints.met({"kind": "near", "m": 4.0}, n, 3.0, 0.0, false), "near")
	assert_false(FirstHints.met({"kind": "near", "m": 4.0}, n, 5.0, 0.0, false), "far")
	assert_false(FirstHints.met({"kind": "near", "m": 4.0}, null, 1.0, 0.0, false), "no node")
	assert_false(FirstHints.met({"kind": "exists", "after_s": 20.0}, n, 0.0, 10.0, false), "too early")
	assert_true(FirstHints.met({"kind": "exists", "after_s": 20.0}, n, 0.0, 21.0, false), "exists and old enough")
	assert_true(FirstHints.met({"kind": "special_round"}, null, INF, 0.0, true), "a special round")
	assert_false(FirstHints.met({"kind": "special_round"}, null, INF, 0.0, false), "a plain round")
	n.free()


func test_a_number_prop_needs_to_pass_min() -> void:
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 3
	assert_true(FirstHints.met({"kind": "prop", "prop": "layer", "min": 2.0}, cl, 0.0, 0.0, false), "3 > 2")
	assert_false(FirstHints.met({"kind": "prop", "prop": "layer", "min": 3.0}, cl, 0.0, 0.0, false), "3 is not > 3")
	cl.free()


func test_the_searchlight_hint_waits_for_its_node() -> void:
	# guarded by the node's existence: with no searchlight in the tree nothing is found, so the condition is false
	var row: Dictionary = FirstHints.table()["searchlight"]
	assert_false(FirstHints.met(row["when"], null, INF, 99.0, false), "no searchlight node, no hint")
	assert_eq(str((row["when"] as Dictionary)["group"]), "searchlight")


func test_each_hint_files_an_archive_card() -> void:
	var ids: Array = ProfileSave.intel_rows().map(func(r: Dictionary) -> String: return str(r["id"]))
	for k: String in FirstHints.table():
		assert_has(ids, "ARC_HINT_" + k.to_upper())
		_map.map_id = StringName(str(FirstHints.table()[k]["map"]) + "_x")
		_fh.try_show(k)
		assert_true(ProfileSave.has_intel("ARC_HINT_" + k.to_upper()), "%s is filed in the Archive when shown" % k)
