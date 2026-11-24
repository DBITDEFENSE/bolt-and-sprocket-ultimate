extends GutTest
## T-274: the perk deal (T-251, T-255) on the four Fernflug acts. Every act scene has more perk spots than machines,
## spread over its zones, with Second Wind's kind (one door from the start) and the start's kind marked from the
## act's own zone graph; every spot's floor is cut out of the navmesh and the floor in front of it is on it; the scene
## holds the seed-0 deal; the deal keeps perk_layout.json's rules over many seeds and every spot takes a machine on
## some seed. The generator's audit (gen_map04_lib.gd, "perk spots") checks each spot against what is built and drawn
## before a scene is saved. The live check is the acts' own smokes (smoke_map04a..d count the machines) and
## smoke_map04_full (the campaign through all four).

const ACTS: Dictionary = {
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const START: Dictionary = {"map04a": "A_SIEDLUNG", "map04b": "A_BOMBENSCHACHT", "map04c": "A_WRECK", "map04d": "A_RECEPTION"}
const SPOT_D: float = 1.2

var maps: Dictionary = {}
var rules: Dictionary


func before_all() -> void:
	rules = GLData.load_json(PerkShuffle.RULES_PATH)
	for k: String in ACTS.keys():
		maps[k] = (load(ACTS[k]) as PackedScene).instantiate()


func after_all() -> void:
	for k: String in maps.keys():
		(maps[k] as Node).free()
	maps.clear()


func _spots(key: String) -> Array:
	var out: Array = []
	for n: Node in (maps[key] as Node).get_node("Gameplay").get_children():
		if n is PerkSpot:
			out.append(n)
	return out


func _rows(key: String) -> Array:
	return _spots(key).map(func(s: PerkSpot) -> Dictionary: return s.row())


func _perks(key: String) -> Array:
	return PerkLayout.map_perk_rows(key)


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


func _on_any(key: String, p: Vector3) -> bool:
	for r: Node in (maps[key] as Node).get_node("Navigation").get_children():
		var reg: NavigationRegion3D = r as NavigationRegion3D
		if reg != null and reg.enabled and reg.navigation_mesh != null and _on_navmesh(reg.navigation_mesh, p):
			return true
	return false


func test_every_act_has_a_row_and_more_spots_than_machines() -> void:
	for key: String in ACTS.keys():
		var perks: Array = _perks(key)
		var spots: Array = _spots(key)
		assert_between(perks.size(), 9, 10, "%s: nine or ten machines in its row" % key)
		assert_gte(spots.size(), perks.size() + 3, "%s: at least three spots more than machines (%d for %d)" % [key, spots.size(), perks.size()])
		var machines: int = 0
		for n: Node in (maps[key] as Node).get_node("Gameplay").get_children():
			if n is PerkMachine:
				machines += 1
				assert_true(perks.any(func(p: Dictionary) -> bool: return p["id"] == String(n.get("perk_id"))), "%s: %s is in the row" % [key, n.name])
		assert_eq(machines, perks.size(), "%s: every machine of the row is in the scene" % key)


func test_spots_are_spread_flagged_and_flush() -> void:
	for key: String in ACTS.keys():
		var zones: Dictionary = {}
		var near: int = 0
		var ids: Dictionary = {}
		var map: MapRoot = maps[key] as MapRoot
		var next_to_start: Array = map.zone_adjacency.get(StringName(START[key]), [])
		for s: PerkSpot in _spots(key):
			assert_false(ids.has(s.spot_id), "%s: %s is listed once" % [key, s.spot_id])
			ids[s.spot_id] = true
			zones[s.zone_id] = int(zones.get(s.zone_id, 0)) + 1
			assert_true(map.nav_zone_bits.has(s.zone_id), "%s: %s's zone %s is the act's" % [key, s.spot_id, s.zone_id])
			assert_eq(s.start, String(s.zone_id) == START[key], "%s: %s is a start spot only in the start zone" % [key, s.spot_id])
			assert_eq(s.near, next_to_start.has(s.zone_id) or next_to_start.has(String(s.zone_id)), "%s: %s is near only one door from the start" % [key, s.spot_id])
			assert_false(s.outdoor, "%s: no snow on this act (%s)" % [key, s.spot_id])
			assert_ne(s.flush, 0, "%s: %s stands on its wall" % [key, s.spot_id])
			assert_almost_eq(fmod(absf(rad_to_deg(s.rotation.y)) + 0.5, 90.0), 0.5, 0.01, "%s: %s is square to the walls" % [key, s.spot_id])
			if s.near:
				near += 1
		assert_gte(near, 1, "%s: a spot for Second Wind" % key)
		assert_gte(zones.size(), 5, "%s: spots in most zones (%s)" % [key, str(zones)])


func test_every_spot_keeps_its_floor_out_of_the_navmesh_and_its_front_on_it() -> void:
	for key: String in ACTS.keys():
		for s: PerkSpot in _spots(key):
			assert_eq((maps[key] as Node).find_children("NavBlock_PerkSpot_*", "", true, false).size(), 0, "%s: the footprints were bake-only" % key)
			assert_false(_on_any(key, s.position), "%s: no navmesh under %s" % [key, s.spot_id])
			var front: Vector3 = s.position + s.basis * Vector3(0, 0, -(SPOT_D * 0.5 + 0.7))
			assert_true(_on_any(key, front), "%s: the navmesh covers %s's front" % [key, s.spot_id])


func test_the_scenes_hold_the_seed_zero_deal() -> void:
	for key: String in ACTS.keys():
		var deal: Dictionary = PerkShuffle.assign(0, _rows(key), _perks(key), rules)
		assert_eq(deal.size(), _perks(key).size(), "%s: every machine is dealt" % key)
		for pk: Dictionary in _perks(key):
			var m: Node3D = (maps[key] as Node).get_node_or_null("Gameplay/Perk_" + str(pk["id"])) as Node3D
			var s: PerkSpot = (maps[key] as Node).get_node_or_null("Gameplay/PerkSpot_" + str(deal.get(pk["id"], "?"))) as PerkSpot
			assert_not_null(m, "%s: Perk_%s" % [key, pk["id"]])
			assert_not_null(s, "%s: its spot" % key)
			if m != null and s != null:
				var at: Vector3 = s.position + s.basis * s.stand_offset(PerkMachine._shape_footprint(str(pk["shape"])).z)
				assert_almost_eq(m.position, at, Vector3(0.01, 0.01, 0.01), "%s: %s stands on %s" % [key, pk["id"], s.name])
				assert_almost_eq(absf(angle_difference(m.rotation.y, s.rotation.y)), 0.0, 0.002)


func test_the_rules_hold_over_many_seeds() -> void:
	for key: String in ACTS.keys():
		var spots: Array = _rows(key)
		var perks: Array = _perks(key)
		var by_id: Dictionary = {}
		for s: Dictionary in spots:
			by_id[s["id"]] = s
		var used: Dictionary = {}
		var sw: Dictionary = {}
		var bad: PackedStringArray = []
		for seed_v: int in 300:
			var deal: Dictionary = PerkShuffle.assign(seed_v * 7919 + 13, spots, perks, rules)
			if deal.size() != perks.size() or not PerkShuffle.valid(deal, spots, perks, rules):
				bad.append("seed %d: not a valid deal" % seed_v)
				continue
			for pk: Dictionary in perks:
				var sp: Dictionary = by_id[deal[pk["id"]]]
				used[sp["id"]] = true
				if bool(sp["start"]) and (int(pk["cost"]) > int(rules["start_max_cost"]) or pk["id"] == "second_wind"):
					bad.append("seed %d: %s in the start zone" % [seed_v, pk["id"]])
				if pk["id"] == "second_wind":
					sw[sp["id"]] = true
					if not bool(sp["near"]):
						bad.append("seed %d: Second Wind on %s" % [seed_v, sp["id"]])
		assert_eq(bad.size(), 0, "%s: %s" % [key, "\n".join(bad.slice(0, 6))])
		assert_eq(used.size(), spots.size(), "%s: every spot takes a machine on some seed" % key)
		assert_gte(sw.size(), 2, "%s: Second Wind has more than one place (%s)" % [key, str(sw.keys())])
