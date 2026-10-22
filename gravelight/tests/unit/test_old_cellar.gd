extends GutTest
## Map 0's Old Cellar (Update 02 section 6.1, DECISIONS T-051): the light-well windows (Barricade.inside_drop), the
## holding cage's burst, the ice cellar's seal, and the generated map's nodes (Door 5, the breach, the
## windows, the Gewehr 43, the ammo box, Jakub's markers).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _zones: Dictionary
var _flags: Dictionary


func before_each() -> void:
	_zones = GameState.open_zones.duplicate(true)
	_flags = GameState.flags.duplicate(true)


func after_each() -> void:
	GameState.open_zones = _zones
	GameState.flags = _flags


func test_light_well_window_drops_to_the_room_floor() -> void:
	var b: Barricade = Barricade.new()
	b.width = 1.6
	b.sill_height = 0.1
	b.top_height = 0.85
	b.inside_drop = 1.9
	add_child_autofree(b)
	assert_almost_eq(b.inside_point().y, -1.9, 0.001, "zombies land on the room floor")
	assert_almost_eq(b.inside_point().z, 1.0, 0.001)
	assert_almost_eq(b.outside_point().y, 0.0, 0.001, "and start from the well's floor")
	# the repair area reaches down to 0.7 m above the room floor, just inside the wall
	var lo: float = b.interact_offset.y - b.interact_size.y * 0.5
	assert_almost_eq(lo, 0.7 - 1.9, 0.001)
	assert_gt(b.interact_offset.z, 0.15)
	# the climb counts as a high window (the drop clip)
	var high: float = float(GLData.table("anim")["climb"].get("high_window_m", 1.2))
	assert_gt(b.sill_point().y - b.inside_point().y, high)


func test_plain_window_unchanged() -> void:
	var b: Barricade = Barricade.new()
	add_child_autofree(b)
	assert_almost_eq(b.inside_point().y, 0.0, 0.001)
	assert_eq(b.interact_offset, Vector3(0, 1.3, 0.3))


func test_holding_cage_bursts_once() -> void:
	var c: HoldingCage = HoldingCage.new()
	add_child_autofree(c)
	var body: StaticBody3D = c.get_node("DoorBody") as StaticBody3D
	assert_eq(body.collision_layer, HoldingCage.LAYER_DOOR, "shut: the door blocks")
	watch_signals(c)
	assert_true(c.burst_open(null))
	assert_true(c.is_open)
	assert_eq(body.collision_layer, 0, "burst: nothing blocks the doorway")
	assert_signal_emitted(c, "burst")
	assert_false(c.burst_open(null), "only once")
	c.reset()
	assert_false(c.is_open)
	assert_eq(body.collision_layer, HoldingCage.LAYER_DOOR)


func test_seal_opens_on_the_aunts_letter_only() -> void:
	var s: SealedPassage = SealedPassage.new()
	s.passage_id = &"ice_cellar"
	s.open_on_intel = &"INT_HB_01"
	add_child_autofree(s)
	var body: StaticBody3D = s.get_node("SealBody") as StaticBody3D
	assert_eq(body.collision_layer, SealedPassage.LAYER_DOOR)
	GLBus.intel_found.emit(&"INT_M0_09")
	assert_false(s.is_open, "other intel leaves it shut")
	GLBus.intel_found.emit(&"INT_HB_01")
	assert_true(s.is_open, "the Cousins' clear opens it")
	assert_eq(body.collision_layer, 0)
	assert_true(bool(GameState.flags.get(&"passage_ice_cellar_open", false)))


func test_breach_opens_when_both_cellars_are_open() -> void:
	GameState.open_zones.erase(&"CELLAR")
	GameState.open_zones.erase(&"OLD_CELLAR")
	var s: SealedPassage = SealedPassage.new()
	s.open_when_zones = PackedStringArray(["CELLAR", "OLD_CELLAR"])
	s.nav_link_path = NodePath("Link")
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = "Link"
	link.enabled = false
	s.add_child(link)
	add_child_autofree(s)
	GameState.open_zone(&"CELLAR")
	assert_false(s.is_open, "one cellar is not enough")
	assert_false(link.enabled)
	GameState.open_zone(&"OLD_CELLAR")
	assert_true(s.is_open, "both open: the breach falls in")
	assert_true(link.enabled, "and the navmesh link across it switches on")


func test_generated_map_has_the_old_cellar() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var d5: Node = map.find_child("Door_OldCellar", true, false)
	assert_not_null(d5)
	if d5 != null:
		assert_eq(int(d5.get("cost")), 1250)
		assert_eq(StringName(d5.get("opens_zone")), &"OLD_CELLAR")
	var br: Node = map.find_child("CellarBreach", true, false)
	assert_not_null(br)
	if br != null:
		assert_eq(Array(br.get("open_when_zones")), ["CELLAR", "OLD_CELLAR"])
		var link: NavigationLink3D = br.get_node_or_null("BreachLink") as NavigationLink3D
		assert_not_null(link)
		if link != null:
			assert_false(link.enabled, "shut at the start")
	for w: String in ["W_CEL_COAL", "W_CEL_VAULT"]:
		var n: Node = map.find_child(w, true, false)
		assert_not_null(n, w)
		if n != null:
			assert_gt(float(n.get("inside_drop")), 1.5, w)
			assert_eq(StringName(n.get("zone_id")), &"OLD_CELLAR")
		assert_not_null(map.find_child("Spawn_" + w, true, false))
	var wb: Node = map.find_child("WallBuy_gewehr43", true, false)
	assert_not_null(wb)
	for m: String in ["JakubCage", "JakubSpawn", "JakubWait", "CoalShovel", "IceCellarSeal", "IceCellarLetter", "IceCellarChalk", "IceCellarHatch"]:
		assert_not_null(map.find_child(m, true, false), m)
	assert_not_null(map.find_child("AmmoBox_Cellar", true, false))
	map.free()
