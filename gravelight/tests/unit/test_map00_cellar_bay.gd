extends GutTest
## Map 0's Helvetia cellar past the vault.
## T-179: the late-delivery bay (gen_map00 BAY_*): in zone CELLAR, the baked navmesh (both bakes) runs through its arch,
## its bulb is one of the lever's lights, its oil lamp is always lit, Skyhook Sekt and Magpie Mead have Map 0 plates
## and are on the bots' plan.
## T-251 (UPDATE 19): the cellar grew by 75 %: the Lagering Vault and the Dynamo Room (LAG_* / DYN_*), each behind
## its own door; the cellar lever and the Crucible stand in the Dynamo Room, three doors from the taproom; the vault's
## old alcove holds the wash copper; the twelve machines no longer stand in rows down here (test_perk_layout).
## The live checks (the doors, the lever's sweep, a purchase, paths) are smoke_map00_cellar_bay.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN = preload("res://gravelight/tools_src/gen_map00.gd")
const Facing: GDScript = preload("res://gravelight/tools_src/interactable_facing.gd")
const BAY_PERKS: Array[String] = ["skyhook_sekt", "magpie_mead"]
const CY: float = -3.2

var map: Node


func before_all() -> void:
	map = (load(MAP) as PackedScene).instantiate()


func after_all() -> void:
	if map != null:
		map.free()


func _machines() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c: Node in map.get_node("Gameplay").get_children():
		if c.name.begins_with("Perk_"):
			out.append(c as Node3D)
	return out


## True when (x, z) lies inside a navmesh polygon at about height y.
static func _on_navmesh(nm: NavigationMesh, p: Vector3) -> bool:
	var v: PackedVector3Array = nm.get_vertices()
	for i: int in nm.get_polygon_count():
		var poly: PackedInt32Array = nm.get_polygon(i)
		var pts: PackedVector2Array = []
		var ys: float = 0.0
		for k: int in poly:
			pts.append(Vector2(v[k].x, v[k].z))
			ys += v[k].y
		if absf(ys / float(poly.size()) - p.y) > 0.6:
			continue
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), pts):
			return true
	return false


func _zone_at(p: Vector3) -> String:
	for c: Node in map.get_node("Gameplay").get_children():
		var zv: ZoneVolume = c as ZoneVolume
		if zv == null:
			continue
		var l: Vector3 = p - zv.position
		if absf(l.x) <= zv.size.x * 0.5 and absf(l.z) <= zv.size.z * 0.5 and l.y >= -0.5 and l.y <= zv.size.y:
			return String(zv.zone_id)
	return ""


func test_the_twelve_machines_are_on_the_map() -> void:
	assert_eq(_machines().size(), 13, "the thirteen machines: the ten, the two Fernflug tonics and Rocket Man (T-276)")
	for m: Node3D in _machines():
		assert_true(m.get_script() == preload("res://gravelight/world/perk_machine.gd"), "%s is a PerkMachine" % m.name)


func test_power_prices_and_cap_are_unchanged() -> void:
	var perks: Dictionary = GLData.table("perks")
	assert_eq(int(perks["perks"]["skyhook_sekt"]["cost"]), 2500, "Skyhook Sekt's price")
	assert_eq(int(perks["perks"]["magpie_mead"]["cost"]), 3000, "Magpie Mead's price")
	assert_eq(int(perks["cap"]), 6, "the cap stays six")
	for id: String in BAY_PERKS:
		assert_true(PerkManager.needs_power(StringName(id)), "%s runs off the cellar lever" % id)


func test_the_bay_is_zone_cellar() -> void:
	assert_eq((map.get_node("Gameplay") as Node3D).position, Vector3.ZERO)
	for p: Vector3 in [Vector3(38.5, CY + 0.3, 26.0), Vector3(36.6, CY + 0.3, 23.2), Vector3(41.6, CY + 0.3, 29.0)]:
		assert_eq(_zone_at(p), "CELLAR", "the bay's floor at %s is zone CELLAR" % str(p))


func test_the_navmesh_runs_through_the_arch() -> void:
	assert_gt(GEN.BAY_ARCH.y - GEN.BAY_ARCH.x, 1.6, "the arch is at least a doorway wide")
	for rn: String in ["Navigation", "NavigationBreachOpen"]:
		var r: NavigationRegion3D = map.get_node_or_null(rn) as NavigationRegion3D
		assert_not_null(r, rn)
		if r == null:
			continue
		var am: float = (GEN.BAY_ARCH.x + GEN.BAY_ARCH.y) * 0.5
		for x: float in [35.0, 36.0, 37.0, 38.2]:
			assert_true(_on_navmesh(r.navigation_mesh, Vector3(x, CY, am)), "%s: the navmesh runs through the arch (x %.1f)" % [rn, x])


func test_the_bay_has_a_lever_light_and_a_lamp() -> void:
	var bulb: bool = false
	var lamp: bool = false
	for c: Node in map.get_children():
		var l: OmniLight3D = c as OmniLight3D
		if l == null or l.position.x < GEN.BAY_X0 + 0.2 or l.position.x > GEN.BAY_X1 or l.position.y > -0.2 or l.position.z > GEN.BAY_Z1:
			continue
		if l.is_in_group(&"power_lights") and str(l.get_meta("zone", "")) == "CELLAR" and not l.visible:
			bulb = true
		if l.name == "CellarBayLamp" and l.visible:
			lamp = true
	assert_true(bulb, "a CELLAR bulb in the bay that the lever's sweep turns on")
	assert_true(lamp, "an oil lamp by the arch, lit before the lever")


func test_the_plates_and_the_bots() -> void:
	for id: String in BAY_PERKS:
		assert_ne(MachineLore.plate(&"map00_crossroads", "perk." + id), "", "%s has a Map 0 maker's plate" % id)
		assert_false(MachineLore.row(&"map00_crossroads", "perk." + id).is_empty(), "%s has a Map 0 Archive entry" % id)
	var eco: Dictionary = BotAIData.table("economy")
	var plan: Array = eco["perk_plan"]
	for id2: String in BAY_PERKS:
		assert_true(plan.has(id2), "the bots' perk plan lists %s" % id2)
		assert_true((eco["perk_upgrades"]["plan"] as Array).has(id2), "and its tiers")
	# with the earlier plan drunk and room under the cap, a bot drinks them at the Map 0 machines
	var owned: Array = ["ironhide_stout", "second_wind", "ledger_lager", "trigger_tonic", "hawkeye_brandy", "marathon_malt", "blastproof_bock", "overclock_cordial", "packmule_porter"]
	var avail: Dictionary = {"magpie_mead": 3000, "skyhook_sekt": 2500}
	assert_eq(BotEconomy.perk_wanted(eco, plan, owned, avail, "smg", true, 2, 9000, 500), &"magpie_mead", "Magpie first")
	assert_eq(BotEconomy.perk_wanted(eco, plan, owned + ["magpie_mead"], avail, "smg", true, 1, 9000, 500), &"skyhook_sekt", "then Skyhook")


# ================================================================== T-251: the Lagering Vault and the Dynamo Room

func test_the_cellar_grew_by_three_quarters() -> void:
	var before: float = 12.0 * 12.0 + (GEN.BAY_X1 - GEN.BAY_X0) * (GEN.BAY_Z1 - GEN.BAY_Z0)
	var lager: float = (GEN.LAG_X1 - GEN.LAG_X0) * (GEN.LAG_Z1 - GEN.LAG_Z0)
	var dynamo: float = (GEN.DYN_X1 - GEN.DYN_X0) * (GEN.DYN_Z1 - GEN.DYN_Z0)
	assert_almost_eq((lager + dynamo) / before, 0.75, 0.02, "the two new rooms add 75 %% (%.1f on %.1f m2)" % [lager + dynamo, before])
	assert_gt(lager, 50.0)
	assert_gt(dynamo, 50.0)


func test_two_more_doors_in_a_chain() -> void:
	var doors: Dictionary = {}
	for c: Node in map.get_node("Gameplay").get_children():
		if c.get_script() == preload("res://gravelight/world/door.gd"):
			doors[str(c.get("door_id"))] = c
	for row: Array in [["door_cellar", "CELLAR", 1500], ["door_lager", "LAGERKELLER", 750], ["door_dynamo", "MASCHINENRAUM", 1000]]:
		assert_true(doors.has(row[0]), "%s is on the map" % row[0])
		if not doors.has(row[0]):
			continue
		var d: Node3D = doors[row[0]]
		assert_eq(str(d.get("opens_zone")), str(row[1]))
		assert_eq(int(d.get("cost")), int(row[2]), "%s costs %d" % [row[0], row[2]])
		assert_eq((d.get("also_opens") as PackedStringArray).size(), 0, "%s opens its own room only" % row[0])
	var da: Node3D = doors.get("door_lager")
	var db: Node3D = doors.get("door_dynamo")
	if da == null or db == null:
		return
	assert_almost_eq(da.position.z, GEN.LAG_Z0, 0.01, "Door_Lager is in the vault's south wall")
	assert_almost_eq(da.position.x, (GEN.LAG_DOOR.x + GEN.LAG_DOOR.y) * 0.5, 0.01)
	assert_almost_eq(db.position.x, GEN.DYN_X0, 0.01, "Door_Dynamo is in the wall between the two rooms")
	assert_almost_eq(db.position.z, (GEN.DYN_DOOR.x + GEN.DYN_DOOR.y) * 0.5, 0.01)
	assert_almost_eq(da.position.y, CY, 0.01)
	assert_almost_eq(db.position.y, CY, 0.01)
	# the only ways in: the walls round the two rooms have no other opening (the navmesh proves it: the rooms' floors
	# join the vault's only through the two doorways)
	for rn: String in ["Navigation", "NavigationBreachOpen"]:
		var nm: NavigationMesh = (map.get_node(rn) as NavigationRegion3D).navigation_mesh
		assert_true(_on_navmesh(nm, Vector3(da.position.x, CY, GEN.LAG_Z0)), "%s: the navmesh runs through Door_Lager" % rn)
		assert_true(_on_navmesh(nm, Vector3(GEN.DYN_X0, CY, db.position.z)), "%s: the navmesh runs through Door_Dynamo" % rn)
		for x: float in [28.0, 30.0, 32.0, 33.2, 35.0]:
			assert_false(_on_navmesh(nm, Vector3(x, CY, GEN.LAG_Z0)), "%s: the vault's south wall is shut at x %.1f" % [rn, x])
		for z: float in [31.8, 33.0, 33.9, 36.8]:
			assert_false(_on_navmesh(nm, Vector3(GEN.DYN_X0, CY, z)), "%s: the wall between the rooms is shut at z %.1f" % [rn, z])
		assert_false(_on_navmesh(nm, Vector3(36.0, CY, 30.2)), "%s: no way from the bay's side" % rn)


func test_the_rooms_have_floor_zones_and_a_loop() -> void:
	for rn: String in ["Navigation", "NavigationBreachOpen"]:
		var nm: NavigationMesh = (map.get_node(rn) as NavigationRegion3D).navigation_mesh
		# the Lagering Vault: all the way round the tuns
		var tz: float = (GEN.LAG_TUN_Z.x + GEN.LAG_TUN_Z.y) * 0.5
		var t0: float = float(GEN.LAG_TUNS[0]) - GEN.LAG_TUN_R
		var t1: float = float(GEN.LAG_TUNS[GEN.LAG_TUNS.size() - 1]) + GEN.LAG_TUN_R
		for p: Vector3 in [Vector3(30.0, CY, 32.2), Vector3(30.0, CY, 35.8), Vector3(t0 - 0.9, CY, tz), Vector3(t1 + 0.9, CY, tz)]:
			assert_true(_on_navmesh(nm, p), "%s: the Lagering Vault's loop at %s" % [rn, str(p)])
		assert_false(_on_navmesh(nm, Vector3(30.05, CY, tz)), "%s: the tuns are solid" % rn)
		# the Dynamo Room: all the way round the set
		var c: Vector2 = GEN.DYN_SET.get_center()
		for p2: Vector3 in [Vector3(c.x, CY, GEN.DYN_SET.position.y - 1.0), Vector3(c.x, CY, GEN.DYN_SET.end.y + 1.2), Vector3(GEN.DYN_SET.position.x - 1.2, CY, c.y),
				Vector3(GEN.DYN_SET.end.x + 0.8, CY, c.y)]:
			assert_true(_on_navmesh(nm, p2), "%s: the Dynamo Room's loop at %s" % [rn, str(p2)])
		assert_false(_on_navmesh(nm, Vector3(c.x, CY, c.y)), "%s: the generator set is solid" % rn)
	assert_eq(_zone_at(Vector3(30.0, CY + 0.3, 34.0)), "LAGERKELLER")
	assert_eq(_zone_at(Vector3(24.4, CY + 0.3, 36.6)), "LAGERKELLER")
	assert_eq(_zone_at(Vector3(39.0, CY + 0.3, 35.0)), "MASCHINENRAUM")
	assert_eq(_zone_at(Vector3(43.6, CY + 0.3, 38.6)), "MASCHINENRAUM")
	assert_false(_zone_at(Vector3(30.0, 0.3, 35.0)) in ["LAGERKELLER", "MASCHINENRAUM", "CELLAR"], "the yard over the Lagering Vault is not cellar")
	assert_false(_zone_at(Vector3(40.0, 0.3, 35.0)) in ["LAGERKELLER", "MASCHINENRAUM", "CELLAR"], "the field over the Dynamo Room is not cellar")
	var names: Dictionary = GLData.load_json("res://data/maps/bake_config.json")["maps"]["map00_crossroads"]["zone_names"]
	assert_eq(str(names.get("LAGERKELLER", "")), "The Lagering Vault")
	assert_eq(str(names.get("MASCHINENRAUM", "")), "The Dynamo Room")


func test_the_lever_and_the_crucible_are_three_doors_deep() -> void:
	var lever: Node3D = map.get_node_or_null("Gameplay/Kellerschalter") as Node3D
	var cru: Node3D = map.get_node_or_null("Gameplay/Crucible") as Node3D
	assert_not_null(lever, "the cellar lever keeps its name")
	assert_not_null(cru, "the Crucible keeps its name")
	if lever == null or cru == null:
		return
	assert_eq(_zone_at(lever.position), "MASCHINENRAUM", "the lever stands in the Dynamo Room")
	assert_eq(_zone_at(cru.position + Vector3.UP * 0.3), "MASCHINENRAUM", "the Crucible stands in the Dynamo Room")
	assert_true(bool(cru.get("needs_power")), "the Crucible still runs off the lever")
	assert_eq(str(lever.get("config_table")), "map00")
	var order: PackedStringArray = lever.get("zone_order")
	assert_eq(Array(order), ["MASCHINENRAUM", "LAGERKELLER", "CELLAR", "OLD_CELLAR", "TAPROOM", "UPSTAIRS", "STABLE"], "the sweep starts at the lever and works up to the inn")
	# the Crucible's own frame is what it was in the vault: the wall 0.8 m behind it, the lever 3 m to its left hand
	assert_almost_eq(cru.position.z - (GEN.DYN_Z0 + 0.15), 0.8, 0.01)
	assert_almost_eq(lever.position.x - cru.position.x, 3.0, 0.01)
	assert_almost_eq(absf(angle_difference(cru.rotation.y, PI)), 0.0, 0.002, "it faces south into the room")
	var blocks: Array = map.find_children("NavBlock_Crucible", "StaticBody3D", true, false)
	assert_eq(blocks.size(), 1, "one Crucible footprint in the navmesh source")
	if blocks.size() == 1:
		assert_almost_eq((blocks[0] as Node3D).position.x, cru.position.x, 0.01, "under the Crucible")
	for rn: String in ["Navigation", "NavigationBreachOpen"]:
		var nm: NavigationMesh = (map.get_node(rn) as NavigationRegion3D).navigation_mesh
		assert_true(_on_navmesh(nm, cru.position + Vector3(0, 0, 1.6)), "%s: floor in front of the Crucible" % rn)
		assert_true(_on_navmesh(nm, Vector3(lever.position.x, CY, lever.position.z + 1.1)), "%s: floor in front of the lever" % rn)
		assert_false(_on_navmesh(nm, cru.position), "%s: nothing walks through the Crucible" % rn)
	assert_eq(str(CrucibleRoom.config_for("map00").get("zone", "")), "MASCHINENRAUM", "the Crucible's room lights sweep with the Dynamo Room")
	# nothing of either is left in the vault
	for c: Node in map.get_node("Gameplay").get_children():
		if c is Node3D and (c.name == "Kellerschalter" or c.name == "Crucible"):
			assert_gt((c as Node3D).position.z, GEN.DYN_Z0, "%s is past the vault" % c.name)
	assert_eq(map.find_children("CellarCopperCol", "StaticBody3D", true, false).size(), 1, "the vault's old alcove holds the wash copper")


func test_each_room_has_lights_a_lamp_a_spawn_and_a_burst_point() -> void:
	var rooms: Dictionary = {
		"LAGERKELLER": Rect2(GEN.LAG_X0, GEN.LAG_Z0, GEN.LAG_X1 - GEN.LAG_X0, GEN.LAG_Z1 - GEN.LAG_Z0),
		"MASCHINENRAUM": Rect2(GEN.DYN_X0, GEN.DYN_Z0, GEN.DYN_X1 - GEN.DYN_X0, GEN.DYN_Z1 - GEN.DYN_Z0)}
	for zone: String in rooms.keys():
		var rect: Rect2 = rooms[zone]
		var bulbs: int = 0
		var lamps: int = 0
		for c: Node in map.get_children():
			var l: OmniLight3D = c as OmniLight3D
			if l == null or l.position.y > -0.2 or not rect.has_point(Vector2(l.position.x, l.position.z)):
				continue
			if l.is_in_group(&"power_lights"):
				assert_eq(str(l.get_meta("zone", "")), zone, "a bulb in %s sweeps with %s" % [zone, zone])
				assert_false(l.visible, "dark before the lever")
				bulbs += 1
			elif l.visible and l.light_energy > 0.3:
				lamps += 1
		assert_gte(bulbs, 2, "%s has bulbs the lever turns on" % zone)
		assert_gte(lamps, 1, "%s has a lamp that is always lit" % zone)
		var spawns: int = 0
		var bursts: int = 0
		for g: Node in map.get_node("Gameplay").get_children():
			var n3: Node3D = g as Node3D
			if n3 == null or not rect.has_point(Vector2(n3.position.x, n3.position.z)) or n3.position.y > -0.2:
				continue
			if n3.get_script() == preload("res://gravelight/enemies/zombie_spawn.gd"):
				assert_eq(str(n3.get("zone_id")), zone)
				assert_eq(str(n3.get("kind")), "ground")
				assert_lte(int(n3.get("min_round")), 6)
				for rn: String in ["Navigation", "NavigationBreachOpen"]:
					assert_true(_on_navmesh((map.get_node(rn) as NavigationRegion3D).navigation_mesh, n3.position), "%s: the %s spawn is on the navmesh" % [rn, zone])
				spawns += 1
			if n3.is_in_group(&"power_burst_points"):
				bursts += 1
		assert_gte(spawns, 1, "%s has a zombie entry of its own" % zone)
		assert_gte(bursts, 1, "%s has a power-on burst point" % zone)


## T-255 (the owner: "while the lights and powr are off the room in the cellar is too dark"): before the lever each
## of the two rooms is lit by two oil lanterns you can see hanging there, no corner is further than 8 m from one (the
## single lantern inside each door left corners 9 to 11 m away, past its reach), and the lever's bulbs still add
## about as much light again. The bay has a second lantern over its far half.
func test_the_rooms_are_readable_before_the_lever() -> void:
	var bodies: Array = map.find_children("LanternBody", "MeshInstance3D", true, false)
	var rooms: Dictionary = {
		"LAGERKELLER": Rect2(GEN.LAG_X0, GEN.LAG_Z0, GEN.LAG_X1 - GEN.LAG_X0, GEN.LAG_Z1 - GEN.LAG_Z0),
		"MASCHINENRAUM": Rect2(GEN.DYN_X0, GEN.DYN_Z0, GEN.DYN_X1 - GEN.DYN_X0, GEN.DYN_Z1 - GEN.DYN_Z0)}
	for zone: String in rooms.keys():
		var rect: Rect2 = rooms[zone]
		var lamps: Array[OmniLight3D] = []
		var lamp_sum: float = 0.0
		var bulb_sum: float = 0.0
		for c: Node in map.get_children():
			var l: OmniLight3D = c as OmniLight3D
			if l == null or l.position.y > -0.2 or not rect.has_point(Vector2(l.position.x, l.position.z)):
				continue
			if l.is_in_group(&"power_lights"):
				bulb_sum += float(l.get_meta("energy", l.light_energy))
			elif l.visible and l.light_energy > 0.3:
				lamps.append(l)
				lamp_sum += l.light_energy
				assert_gte(l.omni_range, 10.0, "%s reaches across the room (%.1f m)" % [l.name, l.omni_range])
				assert_lte(float(l.get("amount")), 0.15, "%s burns steadily (a 35 %% flicker dipped the room to black)" % l.name)
				var seen: bool = false
				for b: Node in bodies:
					if Facing.gxf(b).origin.distance_to(l.position) < 0.5:
						seen = true
				assert_true(seen, "%s has its lantern hanging there: the light has a source" % l.name)
		assert_eq(lamps.size(), 2, "%s has two lanterns that are always lit" % zone)
		assert_gte(lamp_sum, 3.0, "%s: readable before the lever (lanterns %.2f; the one lantern was 1.35)" % [zone, lamp_sum])
		assert_gte(bulb_sum, lamp_sum * 0.8, "%s: the lever's bulbs (%.2f) add about as much light again as the lanterns give (%.2f)" % [zone, bulb_sum, lamp_sum])
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var near: float = INF
			for l2: OmniLight3D in lamps:
				near = minf(near, Vector2(l2.position.x, l2.position.z).distance_to(corner))
			assert_lt(near, 8.0, "%s: the corner at %s is %.1f m from a lantern" % [zone, str(corner), near])
	var bay_lamps: int = 0
	for row: Array in GEN.BAY_LAMPS:
		var bay: OmniLight3D = map.get_node_or_null(str(row[0])) as OmniLight3D
		assert_not_null(bay, "%s is in the scene" % row[0])
		if bay == null:
			continue
		bay_lamps += 1
		assert_true(bay.visible and bay.light_energy >= 1.5, "%s is lit before the lever" % row[0])
		assert_lte(float(bay.get("amount")), 0.15, "%s burns steadily" % row[0])
		var hung: bool = false
		for b2: Node in bodies:
			if Facing.gxf(b2).origin.distance_to(bay.position) < 0.5:
				hung = true
		assert_true(hung, "%s has its lantern hanging there" % row[0])
	assert_eq(bay_lamps, 2, "the bay has a lantern at its arch and one over its far half")
	var far: OmniLight3D = map.get_node_or_null("CellarBayLamp2") as OmniLight3D
	if far != null:
		assert_lt(GEN.BAY_X1 - far.position.x, 3.0, "the second lantern hangs within 3 m of the bay's far wall (the arch's is %.1f m from it)" % (GEN.BAY_X1 - 36.75))


func test_the_data_that_lists_the_zones_follows() -> void:
	var m: Dictionary = GLData.load_json("res://data/gravelight/map00.json")
	var shelter: Array = m["sherman_event"]["shelter_zones"]
	for z: String in ["CELLAR", "OLD_CELLAR", "LAGERKELLER", "MASCHINENRAUM"]:
		assert_true(shelter.has(z), "%s shelters from the bombs" % z)
	var text: String = FileAccess.get_file_as_string("res://data/gravelight/vo_rooms.json")
	for z2: String in ["LAGERKELLER", "MASCHINENRAUM"]:
		assert_string_contains(text, '"%s": "cellar_stone"' % z2)
