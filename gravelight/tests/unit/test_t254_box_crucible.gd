extends GutTest
## T-254 (UPDATE 19): the Requisition Crate's and the Crucible's presentation pass.
## The Crucible room probes the room it stands in (rays) and builds its housing into whatever wall and ceiling it
## finds: here in a box room built for the test, with the machine against one wall, then moved to another wall with a
## different ceiling, then stood free; the housing never stands on a navmesh it is told about; anchored coordinates
## follow the probe. The crate's locator and snow follow the sky over its spot. And nothing that is gameplay moved:
## the Crucible's collider is the fit of its art alone, the timings and the use boxes are the old numbers.

var _free: Array = []


func after_each() -> void:
	for n: Variant in _free:
		if is_instance_valid(n):
			(n as Node).free()
	_free.clear()
	GameState.map_id = &""


func _wall(root: Node3D, lo: Vector3, hi: Vector3) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = hi - lo
	cs.shape = bs
	sb.position = (lo + hi) * 0.5
	sb.add_child(cs)
	root.add_child(sb)


## A room 12 x 12 m round the origin: a wall behind +Z at `north_z`, one at +X at `east_x`, a ceiling slab at
## `ceil` over the north half and at `ceil_east` over the strip along the east wall.
func _room(north_z: float, east_x: float, ceil_y: float, ceil_east: float) -> Node3D:
	var root: Node3D = Node3D.new()
	add_child(root)
	_free.append(root)
	_wall(root, Vector3(-6, 0, north_z), Vector3(6, 8, north_z + 0.5))
	_wall(root, Vector3(east_x, 0, -6), Vector3(east_x + 0.5, 8, 6))
	_wall(root, Vector3(-6, ceil_y, 0), Vector3(2.0, ceil_y + 0.4, 6))
	_wall(root, Vector3(2.0, ceil_east, -6), Vector3(6, ceil_east + 0.4, 6))
	return root


func _machine(root: Node3D, pos: Vector3, yaw_deg: float) -> Array:
	var cr: Crucible = Crucible.new()
	cr.position = pos
	cr.rotation_degrees.y = yaw_deg
	root.add_child(cr)
	var room: CrucibleRoom = CrucibleRoom.new()
	room.crucible = cr
	room.map_key = "map00"
	room.data = CrucibleRoom.config_for("map00")
	root.add_child(room)
	room.global_transform = cr.global_transform
	room.build()
	return [cr, room]


func _settle() -> void:
	for i: int in 4:
		await get_tree().physics_frame


func test_the_room_probes_its_wall_and_ceiling_and_follows_the_machine() -> void:
	# local -Z is the machine's front and +Z its back: yaw 0 stands it with its back to the wall at +Z
	var root: Node3D = _room(1.3, 4.0, 3.4, 2.9)
	var made: Array = _machine(root, Vector3(-2.0, 0, 0), 0.0)
	var cr: Crucible = made[0]
	var room: CrucibleRoom = made[1]
	assert_almost_eq(float(room.probe["back"]), 0.8, 0.001, "before the probe the json's room stands in")
	await _settle()
	room.refit()
	assert_almost_eq(float(room.probe["back"]), 1.3, 0.03, "the wall behind, by ray")
	assert_almost_eq(float(room.probe["ceil"]), 3.4, 0.03, "the ceiling, by ray")
	assert_true(bool(room.sur["housed"]), "housed against the wall")
	assert_almost_eq(float(room.sur["z1"]), 1.35, 0.04, "the housing runs into the wall")
	assert_gte(float(room.sur["top"]), 3.4, "and into the ceiling")
	var body: StaticBody3D = room.get_node_or_null("SurroundBody") as StaticBody3D
	assert_not_null(body, "solid where it is drawn")
	assert_eq(room._n("ceil-0.04"), float(room.probe["ceil"]) - 0.04, "an anchored coordinate follows the probe")
	assert_eq(room._n("back-0.3"), float(room.probe["back"]) - 0.3)
	assert_eq(room._n("-w-1.35"), -float(room.sur["w"]) - 1.35)
	assert_eq(room._n(2.5), 2.5)
	# the pipes that come down from the vault start at this room's ceiling, not Map 0's
	var top_y: float = -1.0
	for e: Array in room.piece_boxes:
		if str((e[1] as Dictionary).get("kind")) == "pipe":
			top_y = maxf(top_y, (e[0] as AABB).end.y)
	assert_almost_eq(top_y, 3.4, 0.12, "the feed pipes reach this ceiling")
	# move it: against the east wall (its back, local +Z, to +X: yaw 90), 0.9 m off it, under the lower ceiling
	cr.position = Vector3(3.1, 0, -2.0)
	cr.rotation_degrees.y = 90.0
	await _settle()
	room.refit()
	assert_almost_eq(room.global_position.x, 3.1, 0.001, "the room follows the machine")
	assert_almost_eq(float(room.probe["back"]), 0.9, 0.03, "the other wall, by ray")
	assert_almost_eq(float(room.probe["ceil"]), 2.9, 0.03, "the other ceiling")
	assert_true(bool(room.sur["housed"]))
	assert_almost_eq(float(room.sur["z1"]), 0.95, 0.04)
	assert_eq(room.find_children("SurroundBody", "StaticBody3D", true, false).size(), 1, "one housing body after the rebuild, not two")
	assert_eq(room.find_children("Dressing", "Node3D", true, false).size(), 1, "one dressing after the rebuild")
	# stood free in the middle of the floor: no wall within reach, a stack on its own plinth, nothing solid added
	cr.position = Vector3(-2.0, 0, -4.5)
	cr.rotation_degrees.y = 180.0
	await _settle()
	room.refit()
	assert_gt(float(room.probe["back"]), 3.0, "no wall behind it now")
	assert_false(bool(room.sur["housed"]))
	assert_lte(float(room.sur["w"]), 1.02, "the stack keeps to the machine's own plinth")
	assert_lte(float(room.sur["z1"]), CrucibleRoom.PLINTH_BACK)
	assert_null(room.get_node_or_null("SurroundBody"), "a stack on the plinth adds no collider")


func test_the_housing_keeps_off_the_navmesh() -> void:
	var root: Node3D = _room(1.3, 4.0, 3.4, 2.9)
	var made: Array = _machine(root, Vector3(-2.0, 0, 0), 0.0)
	var room: CrucibleRoom = made[1]
	await _settle()
	room.refit()
	var wide: float = float(room.sur["w"])
	assert_almost_eq(wide, 1.55, 0.001, "no navmesh known: as wide as the json asks")
	# a walkable strip that comes to 1.2 m from the machine's axis on its right flank
	var g: Transform3D = room.global_transform
	var a: Vector3 = g * Vector3(1.2, 0, -3.0)
	var b: Vector3 = g * Vector3(5.0, 0, 2.0)
	room._nav = [PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, a.z), Vector2(b.x, b.z), Vector2(a.x, b.z)])]
	room._build_geometry()
	assert_lt(float(room.sur["w"]), 1.2, "narrowed to what stays off it (%.2f)" % float(room.sur["w"]))
	assert_true(bool(room.sur["housed"]))
	for e: Array in room.piece_boxes:
		if str((e[1] as Dictionary).get("kind")) != "surround":
			continue
		for ab: AABB in e[2]:
			if CrucibleRoom.is_standing(ab) and ab.position.z > 0.3:
				assert_lte(ab.end.x, 1.2, "no standing part of the housing over the strip (%s)" % ab)
	# a navmesh right behind the machine: nothing may be built there at all
	var c: Vector3 = g * Vector3(-3.0, 0, 1.15)
	var d: Vector3 = g * Vector3(3.0, 0, 1.3)
	room._nav = [PackedVector2Array([Vector2(c.x, c.z), Vector2(d.x, c.z), Vector2(d.x, d.z), Vector2(c.x, d.z)])]
	room._build_geometry()
	assert_false(bool(room.sur["housed"]), "the dead walk behind it: a stack on the plinth instead")
	assert_null(room.get_node_or_null("SurroundBody"))


func test_every_map_names_its_room_and_housing() -> void:
	for key: String in ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]:
		var d: Dictionary = CrucibleRoom.config_for(key)
		assert_true(d.has("room"), "%s gives the room's fallback numbers" % key)
		assert_true(d.has("surround"), "%s has a housing" % key)
		assert_true(CrucibleRoom.STYLES.has(str((d["surround"] as Dictionary).get("style", ""))), "%s: a known style" % key)
		for m: String in ["body", "trim", "band"]:
			assert_not_null(Mats.get_mat(str(CrucibleRoom.STYLES[str(d["surround"]["style"])][m])), "%s: the %s material exists" % [key, m])


func test_the_crucible_collides_with_its_art_alone_and_keeps_its_numbers() -> void:
	var cr: Crucible = Crucible.new()
	add_child(cr)
	_free.append(cr)
	var body: StaticBody3D = null
	for c: Node in cr.get_children():
		if c is StaticBody3D:
			body = c as StaticBody3D
	assert_not_null(body)
	assert_eq(body.collision_layer, 1 << 8)
	if body.has_meta("art_fit"):
		assert_eq(body.get_child_count(), int(body.get_meta("art_fit")), "the collider is the fit of the art, nothing of T-254's")
	assert_eq(cr.interact_size, Vector3(2.2, 2.0, 0.3))
	assert_eq(cr.interact_offset, Vector3(0, 1.0, -0.95))
	assert_eq(cr.forge_seconds, 5.0)
	assert_eq(cr.offer_seconds, 15.0)
	assert_false((cr.get("_fire") as OmniLight3D).shadow_enabled, "the fire's light casts no shadow")
	# fed: the weapon's own model goes in; out: the upgraded model hangs where the violet bar did
	cr.call("_forge", 1, "kar98k_up")
	assert_not_null(cr.get("_fed"), "the fed weapon is shown")
	assert_eq(cr.phase, Crucible.Phase.FORGING)
	cr.call("_offer")
	assert_not_null(cr.get("_out"), "the upgraded weapon is shown")
	assert_true((cr.get("_float") as Node3D).visible)
	cr.call("_reset")
	assert_eq(cr.phase, Crucible.Phase.IDLE)
	assert_eq(Crucible.base_of(&"kar98k_up"), &"kar98k")
	assert_eq(Crucible.base_of(&"undertow_maelstrom"), &"undertow")
	var last: float = 0.0
	for f: float in Crucible.CLANKS:
		assert_gt(f, last, "the hammer's blows are in order")
		assert_lt(f, 1.0, "and inside the forge")
		last = f


func test_the_crates_locator_and_snow_follow_the_sky() -> void:
	GameState.map_id = &"map00_crossroads"
	CrateManager.location_index = 0
	var c: MysteryCrate = MysteryCrate.new()
	c.spot_index = 0
	add_child(c)
	_free.append(c)
	var beam: MeshInstance3D = c.get("_beam")
	c.set_sky(-1.0)
	assert_true(bool(c.get("_under_sky")))
	assert_almost_eq(beam.position.y, MysteryCrate.BEACON_H * 0.5, 0.001, "under the sky the locator starts at the crate")
	assert_not_null(c.get("_snow_lid"), "Map 0 is snowy: snow on the lid")
	assert_true((c.get("_snow_lid") as Node3D).visible)
	c.call("_open_lid")
	assert_false((c.get("_snow_lid") as Node3D).visible, "it slides off when the lid opens")
	c.call("_drop_lid", 0.01)
	c.set_sky(3.2)
	assert_false(bool(c.get("_under_sky")))
	assert_almost_eq(beam.position.y, 3.25 + MysteryCrate.BEACON_H * 0.5, 0.001, "under a roof it starts above the roof")
	assert_false((c.get("_snow_base") as Node3D).visible, "no snow indoors")
	# on where the crate is, off where it is not
	for i: int in 30:
		c._process(0.1)
	assert_true(beam.visible, "the locator is on where the crate is")
	CrateManager.location_index = 1
	c.refresh()
	for i2: int in 30:
		c._process(0.1)
	assert_false(beam.visible, "and off when the crate is elsewhere")
	assert_true((c.get("_away") as Node3D).visible, "the empty spot shows what the crate left behind")
	assert_eq(int((c.get("_blocker") as StaticBody3D).collision_layer), 0, "and blocks nothing")
	# a map with no snow
	GameState.map_id = &"map02_totenhafen"
	var c2: MysteryCrate = MysteryCrate.new()
	c2.spot_index = 0
	add_child(c2)
	_free.append(c2)
	c2.set_sky(-1.0)
	assert_null(c2.get("_snow_lid"), "no snow where the map has none")
	CrateManager.location_index = -1


func test_the_crate_keeps_its_numbers() -> void:
	var cfg: Dictionary = GLData.table("crate")
	assert_eq(int(cfg["cost"]), 950)
	assert_eq(float(cfg["cycle_seconds"]), 4.5)
	assert_eq(float(cfg["pickup_window_seconds"]), 12.0)
	assert_eq(float(cfg["move_beam_seconds"]), 20.0)
	var c: MysteryCrate = MysteryCrate.new()
	add_child(c)
	_free.append(c)
	assert_eq(c.interact_size, Vector3(1.6, 1.1, 0.3))
	assert_eq(c.interact_offset, Vector3(0, 0.55, -0.45))
	var shape: BoxShape3D = ((c.get("_blocker") as StaticBody3D).get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_eq(shape.size, Vector3(1.4, 0.75, 0.7))
	for key: String in ["crate_spill", "crate_settle", "crate_close", "crate_sink", "crate_arrive", "crate_hum", "crucible_tick", "crucible_feed", "crucible_clank", "crucible_out"]:
		assert_true(AudioDirector.has_sound(key), "the new sound %s is in the bank" % key)
