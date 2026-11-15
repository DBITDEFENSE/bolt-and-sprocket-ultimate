extends GutTest
## T-251 (UPDATE 19; the owner: "spread perks randomly around the map"): Map 0's perk spots and the per-match deal of
## the twelve tonic machines onto them. The table (gen_map00 PERK_SPOTS) and the scene agree; every spot has its
## bake-only footprint in the navmesh source and floor in front of it on both bakes; the deal (PerkShuffle.assign) is
## the same for the same seed, differs between seeds, and keeps perk_layout.json's rules over many seeds; PerkLayout
## moves the machines, shows a filler crate on the spots left over and re-reads the map's POIs.
## The live checks (a match, a purchase at a dealt machine, co-op) are smoke_map00_cellar_bay and smoke_coop.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN = preload("res://gravelight/tools_src/gen_map00.gd")

var map: Node
var rules: Dictionary
var perks: Array = []
var spots: Array = []


func before_all() -> void:
	map = (load(MAP) as PackedScene).instantiate()
	rules = GLData.load_json(PerkShuffle.RULES_PATH)
	var table: Dictionary = GLData.table("perks")["perks"]
	for id: String in rules["maps"]["map00"]["perks"]:
		perks.append({"id": id, "cost": int(table[id]["cost"]), "shape": str(table[id]["shape"])})
	for sp: Array in GEN.PERK_SPOTS:
		var f: Dictionary = sp[4]
		spots.append({"id": str(sp[0]), "zone": str(sp[1]), "outdoor": bool(f.get("outdoor", false)), "start": bool(f.get("start", false)),
			"near": bool(f.get("near", false))})


func after_all() -> void:
	if map != null:
		map.free()


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


func test_the_table_and_the_scene_agree() -> void:
	assert_gte(GEN.PERK_SPOTS.size(), 14, "at least fourteen spots")
	var per_zone: Dictionary = {}
	var seen: Dictionary = {}
	for sp: Array in GEN.PERK_SPOTS:
		var id: String = str(sp[0])
		assert_false(seen.has(id), "%s is listed once" % id)
		seen[id] = true
		per_zone[str(sp[1])] = int(per_zone.get(str(sp[1]), 0)) + 1
		var n: Node3D = map.get_node_or_null("Gameplay/PerkSpot_" + id) as Node3D
		assert_not_null(n, "PerkSpot_%s is in the scene" % id)
		if n == null:
			continue
		assert_true(n.get_script() == preload("res://gravelight/world/perk_spot.gd"), "%s is a PerkSpot" % id)
		assert_almost_eq(n.position, sp[2] as Vector3, Vector3(0.01, 0.01, 0.01), "%s stands where the table says" % id)
		assert_almost_eq(absf(angle_difference(n.rotation.y, deg_to_rad(float(sp[3])))), 0.0, 0.002, "%s faces where the table says" % id)
		assert_eq(str(n.get("zone_id")), str(sp[1]))
		assert_eq(bool(n.get("outdoor")), bool((sp[4] as Dictionary).get("outdoor", false)))
		assert_eq(bool(n.get("start")), bool((sp[4] as Dictionary).get("start", false)))
		assert_eq(bool(n.get("near")), bool((sp[4] as Dictionary).get("near", false)))
	for z: String in per_zone.keys():
		assert_lte(int(per_zone[z]), 3, "at most three spots in %s" % z)
	assert_gte(per_zone.size(), 8, "spread over the map's zones (%s)" % str(per_zone.keys()))
	for z2: String in ["TAPROOM", "UPSTAIRS", "STABLE", "YARD", "GROUNDS", "CELLAR", "OLD_CELLAR", "LAGERKELLER", "MASCHINENRAUM"]:
		assert_true(per_zone.has(z2), "a spot in %s" % z2)
	assert_eq(int(per_zone.get("TAPROOM", 0)), 1, "one spot in the start room")


func test_every_spot_is_in_its_zone() -> void:
	var gp: Node3D = map.get_node("Gameplay") as Node3D
	for sp: Array in GEN.PERK_SPOTS:
		var p: Vector3 = (sp[2] as Vector3) + Vector3.UP * 0.3
		var zone: String = ""
		for c: Node in gp.get_children():
			var zv: ZoneVolume = c as ZoneVolume
			if zv == null or zone != "":
				continue
			var l: Vector3 = p - zv.position
			if absf(l.x) <= zv.size.x * 0.5 and absf(l.z) <= zv.size.z * 0.5 and l.y >= -0.5 and l.y <= zv.size.y:
				zone = String(zv.zone_id)
		assert_eq(zone, str(sp[1]), "%s stands in zone %s" % [sp[0], sp[1]])


func test_every_spot_keeps_its_floor_out_of_the_navmesh_and_its_front_on_it() -> void:
	for sp: Array in GEN.PERK_SPOTS:
		var blocks: Array = map.find_children("NavBlock_PerkSpot_" + str(sp[0]), "StaticBody3D", true, false)
		assert_eq(blocks.size(), 1, "%s has its footprint box" % sp[0])
		if blocks.is_empty():
			continue
		assert_true((blocks[0] as Node).is_in_group(&"bake_only"), "%s's box only shapes the bake (the machine's own body stops you)" % sp[0])
		var b: Basis = Basis(Vector3.UP, deg_to_rad(float(sp[3])))
		var pos: Vector3 = sp[2]
		for rn: String in ["Navigation", "NavigationBreachOpen"]:
			var nm: NavigationMesh = (map.get_node(rn) as NavigationRegion3D).navigation_mesh
			assert_false(_on_navmesh(nm, pos), "%s: no navmesh under %s" % [rn, sp[0]])
			assert_true(_on_navmesh(nm, pos + b * Vector3(0, 0, -(GEN.PERK_SPOT_D * 0.5 + 0.7))), "%s: the navmesh covers %s's front" % [rn, sp[0]])


func test_the_scene_holds_the_seed_zero_deal() -> void:
	var deal: Dictionary = PerkShuffle.assign(0, spots, perks, rules)
	assert_eq(deal.size(), 12, "every tonic is dealt")
	for pk: Dictionary in perks:
		var m: Node3D = map.get_node_or_null("Gameplay/Perk_" + str(pk["id"])) as Node3D
		var s: Node3D = map.get_node_or_null("Gameplay/PerkSpot_" + str(deal.get(pk["id"], "?"))) as Node3D
		assert_not_null(m, "Perk_%s is in the scene" % pk["id"])
		assert_not_null(s, "its spot %s is in the scene" % str(deal.get(pk["id"], "?")))
		if m != null and s != null:
			assert_almost_eq(m.position, s.position, Vector3(0.01, 0.01, 0.01), "%s stands on %s in the saved scene" % [pk["id"], s.name])
			assert_almost_eq(m.rotation.y, s.rotation.y, 0.001)


func test_the_same_seed_deals_the_same_and_seeds_differ() -> void:
	var a: Dictionary = PerkShuffle.assign(4471, spots, perks, rules)
	var b: Dictionary = PerkShuffle.assign(4471, spots.duplicate(true), perks.duplicate(true), rules)
	assert_eq(a, b, "seed 4471 twice")
	var rev_spots: Array = spots.duplicate()
	rev_spots.reverse()
	var rev_perks: Array = perks.duplicate()
	rev_perks.reverse()
	assert_eq(PerkShuffle.assign(4471, rev_spots, rev_perks, rules), a, "the order the scene lists them in does not matter")
	var distinct: Dictionary = {}
	for s: int in 40:
		distinct[str(PerkShuffle.assign(s, spots, perks, rules))] = true
	assert_gt(distinct.size(), 35, "forty seeds give (nearly) forty layouts: %d" % distinct.size())
	assert_ne(PerkShuffle.assign(1, spots, perks, rules), PerkShuffle.assign(2, spots, perks, rules), "seeds 1 and 2 differ")
	# a seed as big as randi() gives (no overflow in the mix)
	assert_eq(PerkShuffle.assign(4294967295, spots, perks, rules).size(), 12)


func test_the_rules_hold_over_many_seeds() -> void:
	var by_id: Dictionary = {}
	for s: Dictionary in spots:
		by_id[s["id"]] = s
	var outdoor_ok: Array = rules["outdoor_shapes"]
	var where_sw: Dictionary = {}
	var used_spots: Dictionary = {}
	var bad: PackedStringArray = []
	for seed_v: int in 400:
		var deal: Dictionary = PerkShuffle.assign(seed_v * 7919 + 13, spots, perks, rules)
		if deal.size() != 12 or not PerkShuffle.valid(deal, spots, perks, rules):
			bad.append("seed %d: not a valid deal" % seed_v)
			continue
		var zone_n: Dictionary = {}
		var taken: Dictionary = {}
		for pk: Dictionary in perks:
			var sp: Dictionary = by_id[deal[pk["id"]]]
			if taken.has(sp["id"]):
				bad.append("seed %d: two machines on %s" % [seed_v, sp["id"]])
			taken[sp["id"]] = true
			used_spots[sp["id"]] = true
			zone_n[sp["zone"]] = int(zone_n.get(sp["zone"], 0)) + 1
			if bool(sp["outdoor"]) and not outdoor_ok.has(pk["shape"]):
				bad.append("seed %d: %s (%s) out in the snow" % [seed_v, pk["id"], pk["shape"]])
			if bool(sp["start"]) and (int(pk["cost"]) > int(rules["start_max_cost"]) or pk["id"] == "second_wind"):
				bad.append("seed %d: %s in the start room" % [seed_v, pk["id"]])
			if pk["id"] == "second_wind":
				where_sw[sp["id"]] = true
				if not bool(sp["near"]):
					bad.append("seed %d: Second Wind on %s, more than one door from the start" % [seed_v, sp["id"]])
		for z: String in zone_n.keys():
			if int(zone_n[z]) > int(rules["max_per_zone"]):
				bad.append("seed %d: %d machines in %s" % [seed_v, int(zone_n[z]), z])
	assert_eq(bad.size(), 0, "\n".join(bad.slice(0, 8)))
	assert_eq(used_spots.size(), spots.size(), "every spot takes a machine on some seed (unused: %s)" % str(spots.filter(func(s: Dictionary) -> bool: return not used_spots.has(s["id"])).map(func(s: Dictionary) -> String: return s["id"])))
	assert_gt(where_sw.size(), 4, "Second Wind moves about (%d spots)" % where_sw.size())


func test_the_rules_data() -> void:
	var table: Dictionary = GLData.table("perks")["perks"]
	var shapes: Dictionary = {}
	for id: String in table.keys():
		shapes[str(table[id].get("shape", "cabinet"))] = true
	for sh: String in rules["outdoor_shapes"]:
		assert_true(shapes.has(sh), "outdoor shape %s is a perks.json shape" % sh)
	for id2: String in rules["maps"]["map00"]["perks"]:
		assert_true(table.has(id2), "%s is a tonic" % id2)
		assert_not_null(map.get_node_or_null("Gameplay/Perk_" + id2), "%s has its machine on Map 0" % id2)
	assert_eq((rules["maps"]["map00"]["perks"] as Array).size(), 12)
	assert_true(bool(table["second_wind"].get("solo_no_power", false)), "Second Wind pours without the power solo: why it never stands in the start room")
	# an impossible rule set still deals every machine (the rules are dropped rather than a tonic left out)
	var tight: Dictionary = rules.duplicate(true)
	tight["max_per_zone"] = 1
	tight["outdoor_shapes"] = []
	assert_eq(PerkShuffle.assign(5, spots, perks, tight).size(), 12, "max_per_zone 1 and nothing outdoors: still twelve")


func test_the_layout_moves_the_machines_and_shows_the_fillers() -> void:
	var m2: Node3D = (load(MAP) as PackedScene).instantiate() as Node3D
	# only the gameplay nodes the layout reads, without a match: the spots and the machines, in the tree
	var holder: Node3D = Node3D.new()
	holder.set("name", "Holder")
	add_child_autofree(holder)
	var gp: Node3D = m2.get_node("Gameplay") as Node3D
	var keep: Array[Node] = []
	for c: Node in gp.get_children():
		if c is PerkSpot:
			keep.append(c)
	for c2: Node in keep:
		gp.remove_child(c2)
		c2.owner = null
		holder.add_child(c2)
	m2.free()
	await get_tree().process_frame
	var sp_nodes: Array[Node] = get_tree().get_nodes_in_group(&"perk_spots")
	assert_eq(sp_nodes.size(), GEN.PERK_SPOTS.size(), "the spots joined their group")
	for s: Node in sp_nodes:
		var ps: PerkSpot = s as PerkSpot
		assert_true(ps.is_free(), "%s starts free" % ps.name)
		var filler: Node3D = ps.get_node_or_null("Filler") as Node3D
		assert_not_null(filler, "%s shows its filler crate" % ps.name)
		assert_true(filler != null and filler.visible)
		var body: StaticBody3D = ps.get_node_or_null("FillerBody") as StaticBody3D
		assert_true(body != null and body.collision_layer == 1, "%s's crate is solid" % ps.name)
		assert_gt(filler.find_children("*", "MeshInstance3D", true, false).size(), 0, "the crate is drawn")
	var one: PerkSpot = sp_nodes[0] as PerkSpot
	var stand_in: Node3D = Node3D.new()
	holder.add_child(stand_in)
	one.set_machine(stand_in)
	assert_false((one.get_node("Filler") as Node3D).visible, "a machine on the spot hides the crate")
	assert_eq((one.get_node("FillerBody") as StaticBody3D).collision_layer, 0, "and switches its body off")
	one.set_machine(null)
	assert_true((one.get_node("Filler") as Node3D).visible, "the crate is back when the machine leaves")
	assert_eq(one.row()["id"], String(one.spot_id))


func test_bots_and_tools_do_not_know_the_old_rows() -> void:
	# nobody reads baked machine coordinates: the bots' data carries no vault row positions
	for f: String in ["res://data/gravelight/ai/economy.json", "res://data/gravelight/ai/player_bot.json", "res://data/gravelight/bots.json",
			"res://data/gravelight/companions.json"]:
		var text: String = FileAccess.get_file_as_string(f)
		for old: String in ["25.9, -3.2", "34.1, -3.2", "40.3, -3.2"]:
			assert_false(text.contains(old), "%s has no machine row coordinate %s" % [f, old])
	var plan: Array = BotAIData.table("player_bot")["plans"]["map00"]["steps"]
	var order: Array = []
	for st: Dictionary in plan:
		if st.has("door"):
			order.append(str(st["door"]))
		elif st.has("power"):
			order.append("power")
	assert_lt(order.find("door_cellar"), order.find("door_lager"))
	assert_lt(order.find("door_lager"), order.find("door_dynamo"))
	assert_lt(order.find("door_dynamo"), order.find("power"), "the agent's plan opens the three doors before the lever")
	assert_gt(float(BotAIData.table("economy").get("self_led_at_hand_m", 0.0)), 8.0, "a self-led bot standing at the lever throws it (the last door is 8 m from it)")
