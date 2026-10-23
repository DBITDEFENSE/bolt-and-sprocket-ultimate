extends GutTest
## Update 04 section 2 (DECISIONS T-065): the map state's rules. Buyables appear once seen in person, doors once their
## area is revealed, the crate only at its current spot (forgotten when it moves); the fog reveals per floor; shots
## reveal nearby zombies unless suppressed or the setting is Off; objectives follow the spoiler setting; marks.

class FakeRoot extends Node3D:
	var player: Node3D = null

class FakeState extends MapState:
	var fake_zombies: Array = []
	func _zombies() -> Array:
		return fake_zombies

var _saved: Dictionary
var ms: FakeState
var root: FakeRoot


func before_each() -> void:
	_saved = GLSettings.values.duplicate()
	MapData.clear_cache()
	root = FakeRoot.new()
	add_child_autofree(root)
	var body: Node3D = Node3D.new()
	root.add_child(body)
	root.player = body
	ms = FakeState.new()
	ms.setup(MapData.for_map(&"map00_crossroads"), root, "gravelight")
	root.add_child(ms)


func after_each() -> void:
	GLSettings.values = _saved
	MapState.suppressed_check = Callable()


func test_current_is_the_attached_state() -> void:
	assert_eq(MapState.current(), ms)


func test_in_view_rule() -> void:
	var eye: Vector3 = Vector3.ZERO
	assert_true(MapState.in_view(eye, Vector3.FORWARD, Vector3(0, 0, -10), 16.0, 80.0), "ahead, in range")
	assert_false(MapState.in_view(eye, Vector3.FORWARD, Vector3(0, 0, -20), 16.0, 80.0), "too far")
	assert_false(MapState.in_view(eye, Vector3.FORWARD, Vector3(0, 0, 10), 16.0, 80.0), "behind")
	assert_false(MapState.in_view(eye, Vector3.FORWARD, Vector3(10, 0, -2), 16.0, 80.0), "outside the cone")
	assert_true(MapState.in_view(eye, Vector3.FORWARD, Vector3(0, 0, 1.5), 16.0, 80.0), "standing at it counts")


func test_buyables_need_discovery_doors_need_the_area() -> void:
	var perk: Dictionary = ms.data.pois_of_type("perk")[0]
	var door: Dictionary = ms.data.pois_of_type("door")[0]
	assert_true(ms.needs_discovery(perk))
	assert_false(ms.needs_discovery(door))
	var f0: Array = ms.visible_pois(int(perk["floor"]))
	assert_false(f0.has(perk), "an unseen perk is not on the map")
	ms.discover(str(perk["id"]))
	assert_true(ms.visible_pois(int(perk["floor"])).has(perk), "seen once, it stays")
	assert_false(ms.visible_pois(int(door["floor"])).has(door), "a door in the fog is hidden")
	ms.reveal(door["pos"] as Vector3, 3.0)
	assert_true(ms.visible_pois(int(door["floor"])).has(door), "its area revealed, the door shows")
	assert_true(ms.visible_pois(int(door["floor"]), false).has(door), "fog off: every door shows")


func test_discover_signal_and_unknown_ids() -> void:
	watch_signals(ms)
	var p: Dictionary = ms.data.pois_of_type("wall_buy")[0]
	ms.discover(str(p["id"]))
	ms.discover(str(p["id"]))
	assert_signal_emit_count(ms, "poi_discovered", 1)
	ms.discover("perk:nowhere")
	assert_false(ms.is_discovered("perk:nowhere"))


func test_crate_shows_only_at_its_spot_and_is_forgotten_when_it_moves() -> void:
	var spots: Array[Dictionary] = ms.data.pois_of_type("crate_spot")
	assert_gt(spots.size(), 1)
	var a: Dictionary = spots[0]
	var b: Dictionary = spots[1]
	var old: int = CrateManager.location_index
	CrateManager.location_index = int(a["data"]["spot_index"])
	ms.discover(str(a["id"]))
	ms.discover(str(b["id"]))
	var vis: Array = ms.visible_pois()
	assert_true(vis.has(a), "the crate's current spot, seen")
	assert_false(vis.has(b), "another spot never shows")
	ms._on_crate_moved(int(b["data"]["spot_index"]))
	CrateManager.location_index = int(b["data"]["spot_index"])
	assert_false(ms.is_discovered(str(a["id"])), "moving forgets where it was")
	assert_false(ms.visible_pois().has(b), "the new spot needs seeing first")
	CrateManager.location_index = old


func test_fog_reveals_per_floor() -> void:
	var cellar: Vector3 = Vector3(30, -3.2, 25)
	var taproom: Vector3 = Vector3(30, 0.0, 25)
	assert_false(ms.is_revealed(cellar))
	ms.reveal(cellar, 4.0)
	assert_true(ms.is_revealed(cellar), "visited")
	assert_false(ms.is_revealed(taproom), "the floor above at the same spot stays hidden")
	assert_true(ms.is_revealed(cellar + Vector3(2.5, 0, 0)), "within the radius")
	assert_false(ms.is_revealed(cellar + Vector3(8, 0, 0)), "outside the radius")
	ms.discover_all()
	assert_true(ms.is_revealed(taproom))
	assert_almost_eq(ms.revealed_fraction(1), 1.0, 0.001)


func test_shots_reveal_nearby_zombies_unless_suppressed_or_off() -> void:
	var near: Node3D = Node3D.new()
	var far: Node3D = Node3D.new()
	root.add_child(near)
	root.add_child(far)
	near.global_position = Vector3(5, 0, 0)
	far.global_position = Vector3(80, 0, 0)
	ms.fake_zombies = [near, far]
	GLSettings.values["minimap_zombies"] = "firing"
	ms._on_weapon_fired(1, &"m1911", false, Vector3.ZERO, Vector3.FORWARD)
	assert_true(ms.is_zombie_revealed(near), "a shot reveals the zombies near the shooter")
	assert_false(ms.is_zombie_revealed(far), "not the far ones")
	ms._process(1.1)
	assert_false(ms.is_zombie_revealed(near), "for a second only")
	MapState.suppressed_check = func(_pid: int, _w: StringName) -> bool: return true
	ms._on_weapon_fired(1, &"m1911", false, Vector3.ZERO, Vector3.FORWARD)
	assert_false(ms.is_zombie_revealed(near), "a suppressed shot reveals nothing")
	MapState.suppressed_check = Callable()
	GLSettings.values["minimap_zombies"] = "off"
	ms._on_weapon_fired(1, &"m1911", false, Vector3.ZERO, Vector3.FORWARD)
	assert_false(ms.is_zombie_revealed(near), "setting Off: no blips at all")


func test_within_rule() -> void:
	var pts: Array = [Vector3(1, 0, 0), Vector3(30, 0, 0), Vector3(0, 0, -24.9)]
	assert_eq(MapState.within(Vector3.ZERO, pts, 25.0), [0, 2] as Array[int])


func test_objectives_follow_the_spoiler_setting() -> void:
	var seen: Node = Node.new()
	var unseen: Node = Node.new()
	add_child_autofree(seen)
	add_child_autofree(unseen)
	var all: Array[Dictionary] = [{"id": "a", "pos": Vector3.ZERO, "node": seen}, {"id": "b", "pos": Vector3.ZERO, "node": unseen},
		{"id": "c", "pos": Vector3.ZERO}]
	var seen_ids: Dictionary = {seen.get_instance_id(): true}
	assert_eq(MapState.filter_objectives(all, "hidden", seen_ids).size(), 0, "Hidden: none")
	var hints: Array[Dictionary] = MapState.filter_objectives(all, "hints", seen_ids)
	assert_eq(hints.map(func(o: Dictionary) -> String: return str(o["id"])), ["a", "c"], "Hints: the ones seen (and rows without a node)")
	assert_eq(MapState.filter_objectives(all, "full", seen_ids).size(), 3, "Full Guide: all")


func test_objective_providers() -> void:
	ms.clear_objective_providers()
	ms.add_objective_provider(func() -> Array[Dictionary]: return [{"id": "x", "pos": Vector3(1, 0, 1), "label": "Bell", "kind": "objective"}] as Array[Dictionary])
	GLSettings.values[MapState.SPOILER_KEY] = "hints"
	ms._obj_t = 0.0
	assert_eq(ms.objectives().size(), 1, "a provider's rows show")
	GLSettings.values[MapState.SPOILER_KEY] = "hidden"
	ms._obj_t = 0.0
	assert_eq(ms.objectives().size(), 0)


func test_markers() -> void:
	watch_signals(ms)
	var a: int = ms.add_marker({"pos": Vector3(30, -3.2, 25), "kind": "defend", "owner": 1})
	var b: int = ms.add_marker({"pos": Vector3(12, 0, 8), "kind": "go", "owner": 2})
	assert_ne(a, b)
	assert_eq(ms.markers().size(), 2)
	assert_eq(int(ms.markers()[0]["floor"]), 0, "the floor is filled in from the position")
	ms.update_marker(a, {"label": "Hold the cellar"})
	assert_eq(str(ms.markers()[0]["label"]), "Hold the cellar")
	ms.clear_markers(2)
	assert_eq(ms.markers().size(), 1, "one owner's marks cleared")
	ms.remove_marker(a)
	assert_eq(ms.markers().size(), 0)
	assert_signal_emit_count(ms, "markers_changed", 5)
	assert_eq(Minimap.add_marker({"pos": Vector3.ZERO, "kind": "go"}), 3, "Minimap.add_marker forwards to the current state")


func test_canvas_transforms_round_trip() -> void:
	var c: MapCanvas = MapCanvas.new()
	add_child_autofree(c)
	c.size = Vector2(250, 250)
	c.set_state(ms)
	c.center = Vector2(10, 5)
	c.zoom = 4.0
	for h: float in [0.0, 0.7, -2.1]:
		c.heading = h
		var p: Vector3 = Vector3(14, 0, -3)
		var back: Vector3 = c.canvas_to_world(c.world_to_canvas(p))
		assert_almost_eq(Vector2(back.x, back.z), Vector2(p.x, p.z), Vector2(0.001, 0.001))
	c.heading = 0.0
	assert_eq(c.world_to_canvas(Vector3(10, 0, 5)), Vector2(125, 125), "the centre is in the middle")
	assert_eq(c.world_to_canvas(Vector3(10, 0, 0)), Vector2(125, 105), "north is up")


func test_short_zone_label() -> void:
	assert_eq(Minimap.short_label("The Junction: landing yard", "X"), "landing yard")
	assert_eq(Minimap.short_label("", "Crossroads Inn"), "Crossroads Inn")
	assert_eq(Minimap.short_label("Taproom", "X"), "Taproom")
