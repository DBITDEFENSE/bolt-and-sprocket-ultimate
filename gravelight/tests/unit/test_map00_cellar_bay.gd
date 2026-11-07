extends GutTest
## T-179: Skyhook Sekt and Magpie Mead on Map 0, in the Helvetia cellar's late-delivery bay (gen_map00 BAY_*). The two
## machines are in the scene, in the bay, in zone CELLAR, need the cellar lever, keep their prices and the cap; no
## machine's footprint blocks another, the stair spill or the arch; the baked navmesh (both bakes) covers both
## machines' fronts and the arch; the bay's bulb is one of the lever's lights; the plates have Map 0 lore; the bots'
## spending plan lists both. The live checks (the lever, the prompts, a purchase, paths) are smoke_map00_cellar_bay.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN = preload("res://gravelight/tools_src/gen_map00.gd")
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


## A machine's footprint on the floor as a Rect2 (x, z), turned by its yaw like PerkMachine's body.
static func _footprint(m: Node3D) -> Rect2:
	var fp: Vector3 = PerkMachine._shape_footprint(str((GLData.table("perks")["perks"][str(m.get("perk_id"))] as Dictionary).get("shape", "cabinet")))
	var turned: bool = absf(absf(rad_to_deg(m.rotation.y)) - 90.0) < 1.0
	var sx: float = fp.z if turned else fp.x
	var sz: float = fp.x if turned else fp.z
	return Rect2(m.position.x - sx * 0.5, m.position.z - sz * 0.5, sx, sz)


## The floor point 1 m in front of a machine (its local -Z), like BotBrain._front_of.
static func _front(m: Node3D, d: float = 1.0) -> Vector3:
	var f: Vector3 = Basis(Vector3.UP, m.rotation.y) * Vector3(0, 0, -1)
	var fp: Vector3 = PerkMachine._shape_footprint(str((GLData.table("perks")["perks"][str(m.get("perk_id"))] as Dictionary).get("shape", "cabinet")))
	return m.position + f * (fp.z * 0.5 + d)


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


func test_both_machines_stand_in_the_bay() -> void:
	var bay: Rect2 = Rect2(GEN.BAY_X0, GEN.BAY_Z0, GEN.BAY_X1 - GEN.BAY_X0, GEN.BAY_Z1 - GEN.BAY_Z0)
	for id: String in BAY_PERKS:
		var m: Node3D = map.get_node_or_null("Gameplay/Perk_" + id) as Node3D
		assert_not_null(m, "Map 0 has a %s machine" % id)
		if m == null:
			continue
		assert_eq(str(m.get("perk_id")), id)
		assert_true(bay.grow(-0.3).encloses(_footprint(m)), "%s stands inside the bay, clear of its walls" % id)
		assert_almost_eq(m.position.y, CY, 0.01, "%s on the cellar floor" % id)
		assert_true(m.get_script() == preload("res://gravelight/world/perk_machine.gd"), "%s is a PerkMachine" % id)
	assert_eq(_machines().size(), 12, "the twelve cellar machines: the ten and the two Fernflug tonics")


func test_power_prices_and_cap_are_unchanged() -> void:
	var perks: Dictionary = GLData.table("perks")
	assert_eq(int(perks["perks"]["skyhook_sekt"]["cost"]), 2500, "Skyhook Sekt's price")
	assert_eq(int(perks["perks"]["magpie_mead"]["cost"]), 3000, "Magpie Mead's price")
	assert_eq(int(perks["cap"]), 6, "the cap stays six")
	for id: String in BAY_PERKS:
		assert_true(PerkManager.needs_power(StringName(id)), "%s runs off the cellar lever" % id)


func test_the_bay_is_zone_cellar() -> void:
	var gp: Node3D = map.get_node("Gameplay") as Node3D
	assert_eq(gp.position, Vector3.ZERO)
	for id: String in BAY_PERKS:
		var p: Vector3 = _front(map.get_node("Gameplay/Perk_" + id) as Node3D)
		var inside: bool = false
		for c: Node in gp.get_children():
			if c is ZoneVolume and (c as ZoneVolume).zone_id == &"CELLAR":
				var zv: ZoneVolume = c as ZoneVolume
				var l: Vector3 = p + Vector3.UP * 0.3 - zv.position
				inside = inside or (absf(l.x) <= zv.size.x * 0.5 and absf(l.z) <= zv.size.z * 0.5 and l.y >= -0.5 and l.y <= zv.size.y)
		assert_true(inside, "the floor in front of %s is zone CELLAR" % id)


func test_no_machine_blocks_another_the_stairs_or_the_arch() -> void:
	var ms: Array[Node3D] = _machines()
	var stair_spill: Rect2 = Rect2(24.3, 19.0, 3.55, 3.0)
	var arch_lane: Rect2 = Rect2(33.4, GEN.BAY_ARCH.x, 5.0, GEN.BAY_ARCH.y - GEN.BAY_ARCH.x)   # the aisle, the arch and the apron behind it
	assert_gt(GEN.BAY_ARCH.y - GEN.BAY_ARCH.x, 1.6, "the arch is at least a doorway wide")
	for i: int in ms.size():
		var a: Rect2 = _footprint(ms[i])
		assert_false(a.intersects(stair_spill), "%s keeps the stair foot clear" % ms[i].name)
		assert_false(a.intersects(arch_lane), "%s keeps the way to the bay clear" % ms[i].name)
		for j: int in range(i + 1, ms.size()):
			assert_false(a.grow(0.25).intersects(_footprint(ms[j])), "%s and %s stand apart" % [ms[i].name, ms[j].name])


func test_the_navmesh_reaches_both_fronts_and_the_arch() -> void:
	for rn: String in ["Navigation", "NavigationBreachOpen"]:
		var r: NavigationRegion3D = map.get_node_or_null(rn) as NavigationRegion3D
		assert_not_null(r, rn)
		if r == null:
			continue
		var nm: NavigationMesh = r.navigation_mesh
		for id: String in BAY_PERKS:
			var f: Vector3 = _front(map.get_node("Gameplay/Perk_" + id) as Node3D, 0.9)
			assert_true(_on_navmesh(nm, f), "%s: the navmesh covers %s's front (%.1f, %.1f)" % [rn, id, f.x, f.z])
		var am: float = (GEN.BAY_ARCH.x + GEN.BAY_ARCH.y) * 0.5
		for x: float in [35.0, 36.0, 37.0]:
			assert_true(_on_navmesh(nm, Vector3(x, CY, am)), "%s: the navmesh runs through the arch (x %.1f)" % [rn, x])


func test_the_bay_has_a_lever_light_and_a_lamp() -> void:
	var bulb: bool = false
	var lamp: bool = false
	for c: Node in map.get_children():
		var l: OmniLight3D = c as OmniLight3D
		if l == null or l.position.x < GEN.BAY_X0 + 0.2 or l.position.x > GEN.BAY_X1 or l.position.y > -0.2:
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
