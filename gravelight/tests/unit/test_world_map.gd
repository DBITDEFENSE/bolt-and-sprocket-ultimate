extends GutTest
## T-270, the war map (WorldMap): the Solo page's seven maps as seven places on one route. The pure parts: the
## order, where the focus goes from each place, what a place shows for a profile, which legs are travelled, that
## the drawn shapes can be drawn and the name plates do not cover each other. And the page: the places are there,
## the first open one has the focus, a locked one can be looked at but not pressed, the rows above and below are
## reachable, pressing a place starts its map.

const IDS: PackedStringArray = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich",
	"map04c_groomlake", "map04d_mondlicht"]
const SIZES: Array = [Vector2(1300.0, 600.0), Vector2(1250.0, 600.0), Vector2(1600.0, 600.0)]

var _saved_profile: Dictionary = {}
var _saved_path: String = ""
var _saved_settings: Dictionary = {}
var _saved_settings_path: String = ""


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_world_map_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_saved_settings = GLSettings.values.duplicate(true)
	_saved_settings_path = GLSettings.path
	GLSettings.path = "user://_test_world_map_settings.cfg"
	MenuMotion.force_reduced = -1


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLSettings.path))
	ProfileSave.path = _saved_path
	ProfileSave.profile = _saved_profile
	GLSettings.values = _saved_settings
	GLSettings.path = _saved_settings_path
	MenuMotion.force_reduced = -1
	Campaign.reset()


# ================================================================== the pure parts

func test_the_places_are_the_maps_in_story_order() -> void:
	assert_eq(WorldMap.order(), IDS, "the route's order")
	assert_eq(WorldMap.order(), MapCards.ids(), "the same maps, in the same order, as the cards' table")
	var from_menu: PackedStringArray = []
	for m: Array in MenuCharacter.MAPS:
		from_menu.append(str(m[0]))
	assert_eq(WorldMap.order(), from_menu, "and as the Solo page's table")
	assert_eq(WorldMap.LEGS.size(), IDS.size() - 1, "one leg between each two places")
	for id: String in IDS:
		assert_ne(MenuCharacter.scene_of(id), "", "%s has a scene to start" % id)
		assert_eq(MenuCharacter.scene_of(id), str(MapCards.row(id)["scene"]), "%s: the scene its card started" % id)


func test_the_route_runs_west_so_left_is_onward() -> void:
	for i: int in range(1, IDS.size()):
		assert_lt(WorldMap.point(i).x, WorldMap.point(i - 1).x, "%s is left of the place before it" % IDS[i])
	for i: int in IDS.size():
		assert_eq(WorldMap.neighbour(i, Vector2i.LEFT), i + 1 if i + 1 < IDS.size() else -1, "left of %s" % IDS[i])
		assert_eq(WorldMap.neighbour(i, Vector2i.RIGHT), i - 1, "right of %s" % IDS[i])
	var at: int = 0
	var seen: Array[int] = [0]
	while WorldMap.neighbour(at, Vector2i.LEFT) >= 0:
		at = WorldMap.neighbour(at, Vector2i.LEFT)
		seen.append(at)
	assert_eq(seen, [0, 1, 2, 3, 4, 5, 6] as Array[int], "left alone walks the whole route in story order")


func test_up_and_down_follow_the_route_or_leave_the_sheet() -> void:
	# [place, up, down]; -1 = off the sheet (the row above / below)
	for row: Array in [[0, -1, 1], [1, 2, -1], [2, -1, 1], [3, 2, -1], [4, -1, -1], [5, 6, -1], [6, -1, 5]]:
		assert_eq(WorldMap.neighbour(int(row[0]), Vector2i.UP), int(row[1]), "up from %s" % IDS[int(row[0])])
		assert_eq(WorldMap.neighbour(int(row[0]), Vector2i.DOWN), int(row[2]), "down from %s" % IDS[int(row[0])])
	for i: int in IDS.size():
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			var j: int = WorldMap.neighbour(i, dir)
			if j >= 0:
				assert_eq(absi(j - i), 1, "a vertical step is still a step along the route (%s)" % IDS[i])
				assert_eq(signf(WorldMap.point(j).y - WorldMap.point(i).y), float(dir.y), "and goes the way that was pressed")
	assert_eq(WorldMap.neighbour(-1, Vector2i.LEFT), -1)
	assert_eq(WorldMap.neighbour(99, Vector2i.UP), -1)


func test_a_place_shows_what_its_card_showed() -> void:
	var open: Dictionary = WorldMap.state("map00_crossroads", true, 23, "done")
	assert_false(bool(open["locked"]))
	assert_eq(int(open["stop"]), 1)
	assert_eq(str(open["name"]), "Crossroads Inn")
	assert_eq(str(open["date"]), str(MapCards.row("map00_crossroads")["date"]))
	assert_eq(str(open["best_text"]), "BEST ROUND  23")
	assert_eq(str(open["egg_text"]), "EGG  DONE")
	var fresh: Dictionary = WorldMap.state("map01_kaltenbrunn", true, 0, "not done")
	assert_eq(str(fresh["best_text"]), "BEST ROUND  —")
	assert_eq(str(fresh["egg_text"]), "EGG  NOT DONE")
	assert_eq(str(WorldMap.state("map02_totenhafen", true, 6, "no egg")["egg_text"]), "NO EGG")
	var shut: Dictionary = WorldMap.state("map04d_mondlicht", false, 0, "not done")
	assert_true(bool(shut["locked"]))
	assert_eq(int(shut["stop"]), 7)
	assert_eq(str(shut["unlock"]), str(MapCards.row("map04d_mondlicht")["unlock"]), "the card's own unlock wording")


func test_a_place_reads_the_profile() -> void:
	assert_false(bool(WorldMap.profile_state("map00_crossroads")["locked"]), "the inn is always open")
	assert_true(bool(WorldMap.profile_state("map01_kaltenbrunn")["locked"]), "a new profile: Kaltenbrunn is locked")
	ProfileSave.profile["maps_unlocked"] = ["map00_crossroads", "map01_kaltenbrunn"]
	ProfileSave.profile["best_round"] = {"map01_kaltenbrunn": 14}
	ProfileSave.profile["egg_rewards"] = {"map01_requiem": true}
	var st: Dictionary = WorldMap.profile_state("map01_kaltenbrunn")
	assert_false(bool(st["locked"]))
	assert_eq(int(st["best"]), 14)
	assert_eq(str(st["egg"]), "done")


func test_travelled_legs_and_the_first_open_place() -> void:
	assert_eq(WorldMap.legs_travelled([true, false, false, false, false, false, false]), [false, false, false, false, false, false] as Array[bool])
	assert_eq(WorldMap.legs_travelled([true, true, true, false, false, false, false]), [true, true, false, false, false, false] as Array[bool])
	assert_eq(WorldMap.legs_travelled([true, true, false, true, true, false, false]), [true, false, false, true, false, false] as Array[bool],
		"a leg is travelled only with both its ends open")
	assert_eq(WorldMap.legs_travelled([true, true, true, true, true, true, true]), [true, true, true, true, true, true] as Array[bool])
	assert_eq(WorldMap.first_open([true, false]), 0)
	assert_eq(WorldMap.first_open([false, false, true]), 2)
	assert_eq(WorldMap.first_open([false, false]), 0)


func test_the_legs_join_the_places_and_the_kranich_is_on_the_crossing() -> void:
	for size: Vector2 in SIZES:
		for i: int in WorldMap.LEGS.size():
			var pts: PackedVector2Array = WorldMap.leg_points(i, size)
			assert_almost_eq(pts[0].distance_to(WorldMap.point(i, size)), 0.0, 0.6, "leg %d starts at %s" % [i, IDS[i]])
			assert_almost_eq(pts[pts.size() - 1].distance_to(WorldMap.point(i + 1, size)), 0.0, 0.6, "leg %d ends at %s" % [i, IDS[i + 1]])
	assert_eq(WorldMap.LEGS[3], "air")
	assert_eq(WorldMap.LEGS[4], "air", "the Kranich is reached and left by air")
	assert_eq(WorldMap.LEGS[5], "rocket", "the Moon by rocket")
	assert_eq(WorldMap.leg_words(0), "by road and rail")
	assert_eq(WorldMap.leg_words(9), "")
	assert_string_contains(WorldMap.route_text(0), "begins")
	assert_string_contains(WorldMap.route_text(4), "From Werk Thalbach, by air.")
	assert_string_contains(WorldMap.route_text(4), "Onward to Groom Lake, by air.")
	assert_string_contains(WorldMap.route_text(6), "From Groom Lake, by rocket.")


func _on_land(p: Vector2, size: Vector2) -> bool:
	for poly: PackedVector2Array in WorldMap.land_shapes(size):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func test_the_sheet_can_be_drawn_and_the_places_are_where_they_belong() -> void:
	for size: Vector2 in SIZES:
		var shapes: Array[PackedVector2Array] = WorldMap.land_shapes(size)
		assert_eq(shapes.size(), WorldMap.LAND.size())
		for k: int in shapes.size():
			assert_gt(Geometry2D.triangulate_polygon(shapes[k]).size(), 0, "coast %d is a simple outline that can be filled (%s)" % [k, size])
		for i: int in [0, 1, 3, 5]:
			assert_true(_on_land(WorldMap.point(i, size), size), "%s is on land" % IDS[i])
		assert_false(_on_land(WorldMap.point(4, size), size), "the Kranich is over the sea")
		assert_true(WorldMap.inset_rect(size).has_point(WorldMap.point(6, size)), "the Moon is in its inset")
		for i: int in 6:
			assert_false(WorldMap.inset_rect(size).has_point(WorldMap.point(i, size)), "%s is not under the inset" % IDS[i])
		# the Baltic port is on the coast: land a little to the south, sea a little to the north
		var port: Vector2 = WorldMap.point(2, size)
		assert_true(_on_land(port + Vector2(0.0, 0.05 * size.y), size) and not _on_land(port - Vector2(0.0, 0.05 * size.y), size),
			"Totenhafen is on the Baltic coast")


func test_name_plates_stay_on_the_sheet_and_off_each_other() -> void:
	for size: Vector2 in SIZES:
		var sheet: Rect2 = Rect2(Vector2.ZERO, size)
		for i: int in IDS.size():
			var r: Rect2 = WorldMap.plate_rect(i, size)
			assert_true(sheet.encloses(r), "the plate of %s is on the sheet (%s in %s)" % [IDS[i], r, size])
			assert_true(WorldMap.hit_rect(i, size).has_point(WorldMap.point(i, size)), "a click on the mark is a click on the place")
			assert_false(r.has_point(WorldMap.point(i, size)), "the plate of %s does not cover its own mark" % IDS[i])
			for j: int in IDS.size():
				if j == i:
					continue
				assert_false(r.intersects(WorldMap.plate_rect(j, size)), "the plates of %s and %s do not overlap at %s" % [IDS[i], IDS[j], size])
				assert_false(r.grow(WorldMap.NODE_R).has_point(WorldMap.point(j, size)), "the plate of %s does not cover the mark of %s at %s" % [IDS[i], IDS[j], size])


func test_dashes_cut_a_line() -> void:
	var line: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(50.0, 0.0), Vector2(100.0, 0.0)])
	var d: Array[PackedVector2Array] = WorldMap.dashes(line, 10.0, 10.0)
	assert_eq(d.size(), 5, "ten on, ten off, over a hundred")
	var inked: float = 0.0
	for seg: PackedVector2Array in d:
		for k: int in range(1, seg.size()):
			inked += seg[k - 1].distance_to(seg[k])
	assert_almost_eq(inked, 50.0, 0.01, "half of it is ink")
	assert_eq(WorldMap.smooth(PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0), Vector2(10.0, 10.0)]), 1).size(), 6)


# ================================================================== the control and the page

func _map(profile_open: Array) -> WorldMap:
	ProfileSave.profile["maps_unlocked"] = profile_open
	var w: WorldMap = WorldMap.new()
	add_child_autofree(w)
	w.size = WorldMap.REF
	return w


func test_the_places_are_buttons_and_a_press_starts_the_map() -> void:
	var w: WorldMap = _map(["map00_crossroads", "map01_kaltenbrunn"])
	var started: Array[String] = []
	var seen: Array[String] = []
	w.place_focused.connect(func(id: String) -> void: seen.append(id))
	w.build(func(id: String) -> void: started.append(id))
	await wait_physics_frames(2)
	var holder: Node = w.get_node("MapCards")
	assert_eq(holder.get_child_count(), IDS.size(), "seven places")
	for i: int in IDS.size():
		var b: Button = holder.get_child(i) as Button
		assert_eq(str(b.get_meta("map_id")), IDS[i], "in story order")
		assert_eq(b.focus_mode, Control.FOCUS_ALL, "%s takes the focus, locked or not" % IDS[i])
		assert_eq(b.disabled, i > 1, "%s: pressable only when open" % IDS[i])
		assert_true(b.get_rect().has_point(WorldMap.point(i, w.size)), "the button of %s is over its mark" % IDS[i])
	assert_eq(w.first_button(), w.buttons[0])
	assert_eq(seen, ["map00_crossroads"] as Array[String], "the first open place is shown before anything is pressed")
	w.buttons[1].pressed.emit()
	assert_eq(started, ["map01_kaltenbrunn"] as Array[String])
	w.buttons[6].grab_focus()
	await wait_physics_frames(1)
	assert_true(w.buttons[6].has_focus(), "a locked place can be looked at")
	assert_eq(w.selected, 6)
	assert_eq(seen[seen.size() - 1], "map04d_mondlicht")
	assert_eq(w.buttons[6].find_valid_focus_neighbor(SIDE_BOTTOM), w.buttons[5], "down from the Moon is Groom Lake")
	assert_eq(w.buttons[6].find_valid_focus_neighbor(SIDE_LEFT), w.buttons[6], "left of the last place: the focus stays")
	assert_eq(w.buttons[0].find_valid_focus_neighbor(SIDE_RIGHT), w.buttons[0], "right of the first place: the focus stays")
	assert_eq(w.buttons[0].find_valid_focus_neighbor(SIDE_LEFT), w.buttons[1])
	assert_eq(w.buttons[3].find_valid_focus_neighbor(SIDE_TOP), w.buttons[2])


func test_reduce_motion_stills_the_ring() -> void:
	MenuMotion.force_reduced = 1
	var w: WorldMap = _map(["map00_crossroads"])
	w.build(Callable())
	await wait_physics_frames(2)
	var ring: Control = w.get_node("Ring") as Control
	w.buttons[4].grab_focus()
	await wait_physics_frames(1)
	assert_almost_eq((ring.position + ring.size * 0.5).distance_to(WorldMap.point(4, w.size)), 0.0, 0.5, "the ring is simply there")
	assert_false(w.is_processing(), "and nothing pulses")
	MenuMotion.force_reduced = 0
	w.buttons[5].grab_focus()
	await wait_physics_frames(1)
	assert_true(w.is_processing(), "with motion on, the ring pulses under the focus")
	MenuMotion.finish(ring)
	assert_almost_eq((ring.position + ring.size * 0.5).distance_to(WorldMap.point(5, w.size)), 0.0, 0.5, "and ends on the place")


func test_the_solo_page_is_the_war_map() -> void:
	ProfileSave.profile["maps_unlocked"] = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen"]
	ProfileSave.profile["best_round"] = {"map00_crossroads": 23}
	ProfileSave.profile["eggs_done"] = {"map00_radio": true}
	var solo: MenuCharacter = MenuCharacter.new()
	add_child_autofree(solo)
	await wait_physics_frames(2)
	assert_null(solo.world, "step 1: no map yet")
	solo.call("_pick", "peg")
	await wait_physics_frames(4)
	var w: WorldMap = solo.world
	assert_not_null(w, "step 2: the war map")
	assert_eq(solo.find_child("MapCards", true, false).get_child_count(), 7)
	assert_true(w.buttons[0].has_focus(), "the first open place has the focus")
	var panel: Control = solo.find_child("PlacePanel", true, false) as Control
	assert_not_null(panel, "the place under the focus is shown beside the sheet")
	assert_eq((panel.find_child("PlaceName", true, false) as Label).text, "Crossroads Inn")
	assert_eq((panel.find_child("PlaceBest", true, false) as Label).text, "BEST ROUND  23")
	assert_eq((panel.find_child("PlaceEgg", true, false) as Label).text, "EGG  DONE")
	assert_not_null((panel.find_child("Preview", true, false) as TextureRect).texture, "with its preview")
	assert_false((panel.find_child("LockStamp", true, false) as Control).visible)
	w.buttons[4].grab_focus()
	await wait_physics_frames(1)
	assert_eq((panel.find_child("PlaceName", true, false) as Label).text, "Der Kranich")
	assert_true((panel.find_child("LockStamp", true, false) as Control).visible, "a locked place is stamped")
	assert_true((panel.find_child("PlaceLock", true, false) as Label).text.ends_with(str(MapCards.row("map04b_kranich")["unlock"])),
		"and says what unlocks it, in the words of its card")
	assert_false((panel.find_child("Progress", true, false) as Control).visible)
	# the rows round the sheet stay reachable with a controller
	var who: Button = solo.find_child("CharacterButton", true, false) as Button
	var egg: Button = solo.find_child("EggModeButton", true, false) as Button
	assert_eq(w.buttons[4].find_valid_focus_neighbor(SIDE_TOP), who, "up from a place with nothing above it: the top row")
	assert_eq(w.buttons[4].find_valid_focus_neighbor(SIDE_BOTTOM), egg, "down: the row below")
	assert_eq(who.find_valid_focus_neighbor(SIDE_BOTTOM), w.buttons[4], "and back down onto the place last looked at")
	assert_eq(egg.find_valid_focus_neighbor(SIDE_TOP), w.buttons[4])
	assert_eq((solo.find_child("LoadoutButton", true, false) as Button).find_valid_focus_neighbor(SIDE_BOTTOM), w.buttons[4])
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var page: Control = solo.get("_page_root") as Control
	assert_lte(page.size.x, screen.x + 0.5, "the page is no wider than the screen (%s)" % page.size)
	assert_lte(page.size.y, screen.y + 0.5, "nor taller (%s)" % page.size)
	assert_gte(w.size.x, 1250.0, "the sheet has its width (%s)" % w.size)
	# the campaign page keeps its card and has no sheet
	var camp: MenuCharacter = MenuCharacter.new()
	camp.campaign_only = true
	add_child_autofree(camp)
	await wait_physics_frames(2)
	camp.call("_pick", "peg")
	await wait_physics_frames(3)
	assert_null(camp.world)
	assert_null(camp.find_child("World", true, false), "the Campaign page has no war map")
	assert_not_null(camp.find_child("Card_Campaign", true, false))
