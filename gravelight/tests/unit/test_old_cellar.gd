extends GutTest
## Map 0's Old Cellar (Update 02 section 6.1, DECISIONS T-051): the light-well windows (Barricade.inside_drop), the
## holding cage's burst, the ice cellar's seal, and the generated map's nodes (Door 5, the linked breach door, the
## windows, the Gewehr 43, the ammo-box spot, Jakub's markers).

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


func test_linked_cellar_doors_open_together() -> void:
	var a: BuyDoor = BuyDoor.new()
	a.door_id = &"door_cellar"
	a.opens_zone = &"CELLAR"
	a.link_group = &"cellar"
	var b: BuyDoor = BuyDoor.new()
	b.door_id = &"door_cellar_link"
	b.opens_zone = &"CELLAR"
	b.link_group = &"cellar"
	add_child_autofree(a)
	add_child_autofree(b)
	b.open(1)
	assert_true(a.is_open, "buying the breach door opens Door 3 too")
	assert_true(GameState.is_zone_open(&"CELLAR"))


func test_generated_map_has_the_old_cellar() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var d5: Node = map.find_child("Door_OldCellar", true, false)
	assert_not_null(d5)
	if d5 != null:
		assert_eq(int(d5.get("cost")), 1250)
		assert_eq(StringName(d5.get("opens_zone")), &"OLD_CELLAR")
	var dl: Node = map.find_child("Door_CellarLink", true, false)
	var d3: Node = map.find_child("Door_Cellar", true, false)
	assert_not_null(dl)
	if dl != null and d3 != null:
		assert_eq(StringName(dl.get("link_group")), StringName(d3.get("link_group")))
		assert_eq(int(dl.get("cost")), int(d3.get("cost")))
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
	var spot: Node = map.find_child("AmmoBoxSpot_Cellar", true, false)
	assert_not_null(spot)
	if spot != null:
		assert_true(spot.is_in_group(&"ammo_box_spot"))
	map.free()
