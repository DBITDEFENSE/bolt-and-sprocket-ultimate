extends GutTest
## T-272: Kaltenbrunn's map detail pass (docs/u21/t272_map01_detail.md), the data and the scene file.
##   the Sherman: the full round-30 event through the yard's north gate (map01.json sherman_event, YardGate); the
##   running event is walked by smoke_map01_sherman.
##   the tower: the headframe deck, its ladder and two zip lines (gen_map01 HF_*, ZIP_LINES; map01.json ladders,
##   ziplines, climb_links); walked by smoke_map01_tower.

const SCENE: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const GATE_X0: float = 17.6
const GATE_X1: float = 22.4

static var _scene: Node = null


static func _json() -> Dictionary:
	return GLData.load_json("res://data/gravelight/map01.json")


static func _v3(a: Variant) -> Vector3:
	var v: Array = a
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func before_all() -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()


func after_all() -> void:
	if _scene != null:
		_scene.free()
		_scene = null


static func _gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Every box collider of the scene: [{name, lo, hi}] (axis-aligned; the generator builds no rotated ones).
static func _boxes(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if not (cs.shape is BoxShape3D) or not (cs.get_parent() is StaticBody3D):
			continue
		var c: Vector3 = _gxf(cs).origin
		var h: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		out.append({"name": String(cs.get_parent().name), "lo": c - h, "hi": c + h})
	return out


static func _route() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Variant in _json()["sherman_event"]["route"]:
		out.append(_v3(p))
	return out


# ================================================================== the Sherman

func test_the_full_event_is_on() -> void:
	var b: Dictionary = _json()["sherman_event"]
	assert_true(ShermanEvent.block_has_tank(b), "a tank (no more \"tank\": false)")
	assert_eq(int(b["arrive_round"]), 30)
	assert_eq(int(b["stuka_round"]), 40)
	assert_eq(Array(b["assault_zones"]), ["A_MINEHEAD"], "the dead rise in the squad's own zone: open from round 1, so the fight is always reachable")
	assert_eq(Array(b["drive_zones"]), ["A_MINEHEAD"])
	assert_true(bool(b["shelter_roof"]), "the raid's shelters are still any roof")
	assert_false(b.has("barrier"), "no crushed barrier: the gate swings (YardGate)")
	for row: Dictionary in _json()["round_bosses"]:
		if int(row["round"]) == 30:
			assert_true(row.has("arrival"), "der Fuhrmann's round-30 row has the tank's beats")


func test_the_route_comes_in_through_the_gateway() -> void:
	var r: PackedVector3Array = _route()
	assert_gte(r.size(), 3)
	assert_lt(r[0].z, -20.0, "it starts north of the yard, on the rail line's terrace")
	for p: Vector3 in r:
		assert_eq(p.y, 0.0, "on the flat shelf (the drive snaps to each point's height)")
		assert_true(p.x >= KaltenTerrain.SHELF_MIN.x and p.x <= KaltenTerrain.SHELF_MAX.x and p.z >= KaltenTerrain.SHELF_MIN.y, "inside the shelf: %s" % str(p))
	# the last leg: wherever any of the hull is between the pillars, the whole hull is
	var a: Vector3 = r[r.size() - 2]
	var e: Vector3 = r[r.size() - 1]
	assert_lt(a.z, -6.0, "the last leg is a long straight run at the gate (from z %.1f)" % a.z)
	var worst: float = 0.0
	for k: int in 101:
		var p2: Vector3 = a.lerp(e, float(k) / 100.0)
		if p2.z > -1.2 - ShermanRules.HULL_STERN and p2.z < 0.15 - ShermanRules.HULL_BOW:
			worst = maxf(worst, absf(p2.x - 20.0) + ShermanRules.HULL_HALF_W)
	assert_lt(worst, (GATE_X1 - GATE_X0) * 0.5 - 0.3, "the hull clears both pillars by 0.3 m or more (%.2f of %.2f m)" % [worst, (GATE_X1 - GATE_X0) * 0.5])


func test_where_it_parks() -> void:
	var b: Dictionary = _json()["sherman_event"]
	var r: PackedVector3Array = _route()
	var park: Vector3 = r[r.size() - 1]
	var yaw: float = ShermanEvent._leg_yaw(r, r.size() - 2)
	var hull: Transform3D = Transform3D(Basis(Vector3.UP, yaw), park)
	assert_gt((-hull.basis.z).dot(Vector3(0, 0, 1)), 0.99, "it faces the yard")
	assert_true(ShermanRules.may_stand(hull, [], b), "parked, it stands where a driver may")
	for pt: Vector3 in ShermanRules.footprint(hull):
		assert_true(pt.z > 0.4 and pt.z < 9.7 and pt.x > 15.2 and pt.x < 24.8, "the hull is in the forecourt, out of the lanes: %s" % str(pt))
	var box: Array = (b["drive_boxes"] as Array)[0]
	assert_eq(float(box[0]), 15.2, "the drive box is the hoist house's width (the lanes past the gatehouse and the winding house stay open)")
	assert_eq(float(box[2]), 24.8)
	# the campaign's exfil beacon: off the route, clear of the parked hull, kept clear of the driven one
	var ex: Vector3 = _v3(_json()["exfil"]["position"])
	for k: int in r.size() - 1:
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(ex, r[k], r[k + 1])
		assert_gt(Vector2(q.x - ex.x, q.z - ex.z).length(), ShermanRules.HULL_HALF_W + 1.0, "the beacon is clear of the tank's way in (leg %d)" % k)
	assert_gt(ShermanRules.hull_dist(hull, ex), 2.0, "and of the parked hull")
	var disc: Array = (b["drive_no_go"] as Array)[0]
	assert_lt(Vector2(float(disc[0]) - ex.x, float(disc[1]) - ex.z).length(), 0.01, "a driver cannot run it down")
	# merge review: may_stand tests the footprint's sample points, about 3 m apart along the hull; a small disc fits
	# between them. No hull a driver may leave in the forecourt covers the beacon, at any spot or heading.
	var covered: int = 0
	for xi: int in range(152, 249, 4):
		for zi: int in range(4, 98, 4):
			for ydeg: int in range(0, 180, 15):
				var h: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(ydeg)), Vector3(xi * 0.1, 0, zi * 0.1))
				if ShermanRules.may_stand(h, [], b) and ShermanRules.hull_dist(h, ex) < 0.5:
					covered += 1
	assert_eq(covered, 0, "no standing hull within 0.5 m of the exfil beacon")


func test_the_dive_bomber_never_names_a_lost_tank() -> void:
	# merge review: with both Shermans lost the dive bomber goes for the locomotive; its banner names the Rail Yard
	var b: Dictionary = _json()["sherman_event"]
	assert_true(b.has("stuka_target"), "a landmark for the dive bomber")
	var small: String = str((b.get("stuka", {}) as Dictionary).get("banner_small_no_tank", ""))
	assert_ne(small, "", "a banner for the dive with no tank left")
	assert_false(small.contains("SHERMAN"), "and it names no tank: %s" % small)


func test_the_map_rows_lie_over_the_table() -> void:
	var t: Dictionary = ShermanEvent.table()
	var m0: Dictionary = ShermanEvent.block_for(&"map00_crossroads")
	assert_true(is_same(ShermanEvent.with_map_rows(t, m0), t), "Map 0: the table itself, untouched")
	var m1: Dictionary = ShermanEvent.with_map_rows(t, _json()["sherman_event"])
	assert_eq(str(m1["arrival"]["banner"]), "ARMOUR AT THE NORTH GATE")
	assert_eq(float(m1["arrival"]["drive_at"]), float(t["arrival"]["drive_at"]), "the rest of the row is the table's")
	assert_ne(str(t["arrival"]["banner"]), "ARMOUR AT THE NORTH GATE", "the shared table is not written to")
	assert_eq(m1["assist"], t["assist"])


func test_the_gate_in_the_scene() -> void:
	var gate: Node = _scene.find_child("YardGate", true, false)
	assert_not_null(gate, "the scene has its gate")
	if gate == null:
		return
	assert_eq((gate.get_script() as Script).resource_path, "res://gravelight/maps/map01_kaltenbrunn/yard_gate.gd")
	for leaf: String in ["LeafW", "LeafE"]:
		var l: Node3D = gate.get_node_or_null(leaf) as Node3D
		assert_not_null(l, leaf)
		if l != null:
			assert_gt(l.find_children("*", "MeshInstance3D", true, false).size(), 0, "%s is drawn" % leaf)
			assert_lte(l.find_children("*", "MeshInstance3D", true, false).size(), 4, "%s is baked (a few draw calls)" % leaf)
			assert_eq(l.find_children("*", "CollisionShape3D", true, false).size(), 0, "%s has no collider (the gateway's never moves)" % leaf)
	var shut: bool = false
	for bx: Dictionary in _boxes(_scene):
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		if str(bx["name"]) == "Gate":
			shut = lo.x <= GATE_X0 and hi.x >= GATE_X1 and hi.y >= 4.0 and lo.z < 0.0
		elif str(bx["name"]).begins_with("YardN"):
			var over: bool = hi.x > GATE_X0 + 0.01 and lo.x < GATE_X1 - 0.01 and lo.y < 3.9
			assert_false(over, "no wall left in the gateway (%s)" % str(bx["name"]))
	assert_true(shut, "the gateway's collider spans it, full height: nobody walks out")


# ================================================================== the headframe deck (the tower)

static func _gen(k: String) -> Variant:
	return (load("res://gravelight/tools_src/gen_map01.gd") as GDScript).get_script_constant_map()[k]


func test_the_ladder_rows() -> void:
	var d: Dictionary = _json()
	var lad: Array = d["ladders"]
	var links: Array = d["climb_links"]
	assert_eq(lad.size(), 2, "one ladder: a foot and a head")
	assert_eq(links.size(), 1)
	var foot: Dictionary = lad[0]
	var head: Dictionary = lad[1]
	var cl: Dictionary = links[0]
	assert_false(bool(foot.get("down", false)))
	assert_true(bool(head["down"]))
	assert_eq(Array(foot["line"]), Array(cl["line"]), "the players and the dead use the same ladder line")
	assert_eq(Array(head["line"]), Array(cl["line"]))
	assert_eq(_v3(foot["to"]), _v3(cl["to"]), "they arrive at the same place on the deck")
	assert_true(bool(cl["bidirectional"]) and bool(cl["drop"]), "the dead come back down it")
	assert_eq(str(cl["zone"]), "A_MINEHEAD")
	assert_almost_eq(_v3(cl["to"]).y, float(_gen("HF_DECK")), 0.001, "the head is on the deck")
	var lx: float = (_gen("HF_LADDER") as Vector3).x - 0.115 - 0.4
	assert_almost_eq(float((cl["line"] as Array)[0]), lx, 0.01, "the line is 0.4 m off the drawn rungs")
	assert_gt(float(cl.get("perch", 0.0)), Vector2(24.5 - _v3(cl["to"]).x, 19.5 - _v3(cl["to"]).z).length(), "perch reaches the deck's far corner")


func test_the_zip_lines() -> void:
	var d: Dictionary = _json()
	var rows: Array = d["ziplines"]
	var drawn: Array = _gen("ZIP_LINES")
	assert_eq(rows.size(), drawn.size(), "a row for every drawn line")
	var deck: float = float(_gen("HF_DECK"))
	var post_h: float = float(_gen("ZIP_POST_H"))
	var spawns: Array[Vector3] = []
	for n: Node in _scene.find_children("*", "Marker3D", true, false):
		var s: Script = n.get_script() as Script
		if s != null and (s.resource_path.get_file() == "zombie_spawn.gd" or s.resource_path.get_file() == "player_spawn.gd"):
			spawns.append(_gxf(n).origin)
	assert_gt(spawns.size(), 10, "the spawn markers are read")
	var posts: Dictionary = {}
	for bx: Dictionary in _boxes(_scene):
		if str(bx["name"]).begins_with("ZipPost_"):
			posts[str(bx["name"]).substr(8)] = ((bx["lo"] as Vector3) + (bx["hi"] as Vector3)) * 0.5
	var landings: Array[Vector3] = []
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var top: Vector3 = _v3(r["pos"])
		var e: Vector3 = _v3(r["end"])
		var to: Vector3 = _v3(r["to"])
		assert_eq(str(r["name"]), str(drawn[i][0]))
		assert_eq(top, drawn[i][1], "%s: the anchor is where it is drawn" % r["name"])
		assert_almost_eq(top.y - deck, 2.0, 0.001, "%s: the bar 2 m over the deck" % r["name"])
		var outside: bool = top.x < 15.0 or top.x > 25.0 or top.z < 10.0 or top.z > 20.0
		assert_true(outside, "%s: a step outside the railing" % r["name"])
		var slope: float = rad_to_deg(asin((top.y - e.y) / top.distance_to(e)))
		assert_true(slope >= 15.0 and slope <= 30.0, "%s: %.1f degrees (inside the trolley's brake)" % [r["name"], slope])
		var foot: Vector3 = drawn[i][2]
		assert_almost_eq(e.distance_to(foot + Vector3(0, post_h, 0)), 0.0, 0.01, "%s: the cable ends on its post" % r["name"])
		assert_true(posts.has(str(r["name"])), "%s: its post is built (a collider)" % r["name"])
		var flat: Vector3 = Vector3(foot.x - top.x, 0, foot.z - top.z).normalized()
		assert_almost_eq(to.distance_to(foot - flat * 0.9), 0.0, 0.02, "%s: set down 0.9 m short of the post, on the line" % r["name"])
		assert_true(to.x > 0.5 and to.x < 39.5 and to.z > 0.5 and to.z < 31.5, "%s: it lands inside the Minehead yard (no paid door skipped)" % r["name"])
		assert_false(r.has("zone"), "%s: so it is never chained" % r["name"])
		for sp: Vector3 in spawns:
			assert_gt(Vector2(sp.x - to.x, sp.z - to.z).length(), 3.5, "%s: the landing is clear of the spawn at %s" % [r["name"], str(sp)])
		for other: Vector3 in landings:
			assert_gt(other.distance_to(to), 15.0, "%s: a different place" % r["name"])
		landings.append(to)


func test_the_deck_in_the_scene() -> void:
	var deck: float = float(_gen("HF_DECK"))
	var rails: int = 0
	var feet: int = 0
	var collar: bool = false
	for bx: Dictionary in _boxes(_scene):
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		var nm: String = str(bx["name"])
		if nm.begins_with("HFRail_"):
			rails += 1
			assert_true(lo.y >= deck - 0.01 and hi.y <= deck + 1.2, "a railing bar on the deck")
		elif nm.begins_with("Prop_A_FrameFoot_"):
			feet += 1
			assert_gte(hi.y - deck, 1.8, "a frame foot is solid over head height")
		elif nm == "Prop_A_ShaftCollar":
			collar = true
	assert_eq(rails, 12, "three bars on each of the four edges: closed all round")
	assert_eq(feet, 4)
	assert_true(collar, "the shaft collar is solid")
	assert_gte(float(_gen("HF_BRACE_Y")) - deck, 2.35, "the frame's lowest braces start over every head on the deck")
	# the dressing's railing and ladder are drawn (merged): the ZipLines and LadderClimbs are the map's at load


func test_perch_reaches_a_wide_platform_only_where_the_row_says() -> void:
	var map: Node3D = Node3D.new()
	var holder: Node3D = Node3D.new()
	holder.name = "ClimbLinks"
	map.add_child(holder)
	var l: NavigationLink3D = NavigationLink3D.new()
	l.start_position = Vector3(0, 0, 0)
	l.end_position = Vector3(1, 6, 0)
	l.set_meta(ClimbLink.LINE, Vector2(0, 0))
	holder.add_child(l)
	add_child_autofree(map)
	assert_true(ClimbLink.on_perch(map, Vector3(4, 6, 0)), "4 m from the head: on it (the default 4.5)")
	assert_false(ClimbLink.on_perch(map, Vector3(9, 6, 0)), "8 m from it: not, without a perch")
	l.set_meta(ClimbLink.PERCH_META, 10.0)
	assert_true(ClimbLink.on_perch(map, Vector3(9, 6, 0)), "with perch 10: on it")
	assert_false(ClimbLink.on_perch(map, Vector3(9, 0, 0)), "but never on the ground")


# ================================================================== the perk deal

static func _deal_rows() -> Array:
	var spots: Array = []
	for sp: Array in _gen("PERK_SPOTS"):
		var f: Dictionary = sp[4]
		spots.append({"id": str(sp[0]), "zone": str(sp[1]), "outdoor": bool(f.get("outdoor", false)), "start": bool(f.get("start", false)), "near": bool(f.get("near", false))})
	var perks: Array = []
	var table: Dictionary = GLData.table("perks")["perks"]
	for id: String in GLData.load_json(PerkShuffle.RULES_PATH)["maps"]["map01"]["perks"]:
		perks.append({"id": id, "cost": int(table[id]["cost"]), "shape": str(table[id]["shape"])})
	return [spots, perks]


static func _on_navmesh(map: Node, p: Vector3) -> bool:
	for r: Node in map.find_children("Nav_*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
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


func test_the_perk_spots_and_the_scene_agree() -> void:
	var spots: Array = _gen("PERK_SPOTS")
	var dealt: Array = _gen("PERK_DEALT")
	assert_eq(Array(GLData.load_json(PerkShuffle.RULES_PATH)["maps"]["map01"]["perks"]), dealt, "perk_layout.json's row is the generator's dealt list")
	assert_gte(spots.size(), int(ceil(dealt.size() * 1.5)), "half again as many spots as dealt machines (%d for %d)" % [spots.size(), dealt.size()])
	var per_zone: Dictionary = {}
	var gp: Node3D = _scene.get_node("Gameplay") as Node3D
	for sp: Array in spots:
		var id: String = str(sp[0])
		per_zone[str(sp[1])] = int(per_zone.get(str(sp[1]), 0)) + 1
		var n: Node3D = gp.get_node_or_null("PerkSpot_" + id) as Node3D
		assert_not_null(n, "PerkSpot_%s is in the scene" % id)
		if n == null:
			continue
		assert_almost_eq(n.position, sp[2] as Vector3, Vector3(0.01, 0.01, 0.01), "%s stands where the table says" % id)
		assert_eq(str(n.get("zone_id")), str(sp[1]))
		assert_eq(int(n.get("flush")), int((sp[4] as Dictionary).get("flush", 0)))
		# its zone, from the scene's zone volumes
		var p: Vector3 = (sp[2] as Vector3) + Vector3.UP * 0.3
		var zone: String = ""
		for c: Node in gp.get_children():
			var zv: ZoneVolume = c as ZoneVolume
			if zv == null or zone != "":
				continue
			var l: Vector3 = p - zv.position
			if absf(l.x) <= zv.size.x * 0.5 and absf(l.z) <= zv.size.z * 0.5 and l.y >= -0.5 and l.y <= zv.size.y:
				zone = String(zv.zone_id)
		assert_eq(zone, str(sp[1]), "%s stands in its zone" % id)
		# its floor is baked out, its front is on the navmesh
		var blocks: Array = _scene.find_children("NavBlock_PerkSpot_" + id, "StaticBody3D", true, false)
		assert_eq(blocks.size(), 1, "%s has its footprint box" % id)
		if not blocks.is_empty():
			assert_true((blocks[0] as Node).is_in_group(&"bake_only"), "%s's box only shapes the bake" % id)
		var b: Basis = Basis(Vector3.UP, deg_to_rad(float(sp[3])))
		assert_false(_on_navmesh(_scene, sp[2]), "no navmesh under %s" % id)
		assert_true(_on_navmesh(_scene, (sp[2] as Vector3) + b * Vector3(0, 0, -1.3)), "the navmesh covers %s's front" % id)
	for z: String in per_zone.keys():
		assert_lte(int(per_zone[z]), 3, "at most three spots in %s" % z)
	assert_gte(per_zone.size(), 7, "spread over the map's zones (%s)" % str(per_zone.keys()))


func test_the_scene_holds_the_seed_zero_deal_and_the_three_that_stay() -> void:
	var rows: Array = _deal_rows()
	var rules: Dictionary = GLData.load_json(PerkShuffle.RULES_PATH)
	var deal: Dictionary = PerkShuffle.assign(0, rows[0], rows[1], rules)
	assert_eq(deal.size(), (rows[1] as Array).size(), "every dealt tonic gets a spot")
	var gp: Node3D = _scene.get_node("Gameplay") as Node3D
	for pk: Dictionary in rows[1]:
		var m: Node3D = gp.get_node_or_null("Perk_" + str(pk["id"])) as Node3D
		var s: Node3D = gp.get_node_or_null("PerkSpot_" + str(deal.get(pk["id"], "?"))) as Node3D
		if m != null and s != null:
			var at: Vector3 = s.position + s.basis * (s as PerkSpot).stand_offset(PerkMachine._shape_footprint(str(pk["shape"])).z)
			assert_almost_eq(m.position, at, Vector3(0.01, 0.01, 0.01), "%s stands on %s in the saved scene" % [pk["id"], s.name])
	for row: Array in _gen("PERKS"):
		if (_gen("PERK_DEALT") as Array).has(str(row[0])):
			continue
		var m2: Node3D = gp.get_node_or_null("Perk_" + str(row[0])) as Node3D
		assert_not_null(m2)
		if m2 != null:
			assert_almost_eq(m2.position, row[1] as Vector3, Vector3(0.01, 0.01, 0.01), "%s stays where it belongs" % row[0])
		assert_eq(_scene.find_children("NavBlock_Perk_" + str(row[0]), "StaticBody3D", true, false).size(), 1, "%s keeps its own baked footprint" % row[0])


func test_the_deals_rules_over_many_seeds() -> void:
	var rows: Array = _deal_rows()
	var rules: Dictionary = GLData.load_json(PerkShuffle.RULES_PATH)
	var spot_by: Dictionary = {}
	for s: Dictionary in rows[0]:
		spot_by[s["id"]] = s
	var shape: Dictionary = {}
	for pk: Dictionary in rows[1]:
		shape[pk["id"]] = pk["shape"]
	var sw_spots: Dictionary = {}
	var used: Dictionary = {}
	for seed_v: int in 300:
		var deal: Dictionary = PerkShuffle.assign(seed_v, rows[0], rows[1], rules)
		assert_eq(deal.size(), 8, "seed %d deals all eight" % seed_v)
		assert_true(PerkShuffle.valid(deal, rows[0], rows[1], rules), "seed %d keeps the rules" % seed_v)
		var per_zone: Dictionary = {}
		for pid: String in deal.keys():
			var s2: Dictionary = spot_by[deal[pid]]
			used[deal[pid]] = true
			per_zone[s2["zone"]] = int(per_zone.get(s2["zone"], 0)) + 1
			if bool(s2["outdoor"]):
				assert_true((rules["outdoor_shapes"] as Array).has(shape[pid]), "seed %d: %s under the snow is weather kit" % [seed_v, pid])
			if pid == "second_wind":
				assert_true(bool(s2["near"]), "seed %d: Second Wind one door from the yard" % seed_v)
				sw_spots[deal[pid]] = true
		for z: String in per_zone.keys():
			assert_lte(int(per_zone[z]), int(rules["max_per_zone"]), "seed %d: at most two in %s" % [seed_v, z])
	assert_gte(sw_spots.size(), 2, "Second Wind has more than one place (%s)" % str(sw_spots.keys()))
	assert_eq(used.size(), (rows[0] as Array).size(), "every spot gets a machine on some seed")


# ================================================================== the round-1 opening

func test_the_opening_data() -> void:
	var c: Dictionary = InnOpening.load_cfg(InnOpening.data_path_for(&"map01_kaltenbrunn"))
	assert_false(c.is_empty(), "Kaltenbrunn has its opening file")
	assert_eq(str(c["map"]), "map01_kaltenbrunn")
	assert_eq(int(c["round"]), 1)
	assert_true(_scene.find_child("InnOpening", true, false) != null, "the scene has the opening's node (its data_path empty: it asks its map)")
	var cast: Dictionary = GLData.load_json("res://data/gravelight/vo/voice_cast.json")["cast"]
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var ids: Array = []
	for row: Dictionary in c["patrons"]:
		ids.append(str(row["id"]))
		assert_true(cast.has(str(row["speaker"])), "%s's speaker %s is in the cast" % [row["id"], row["speaker"]])
		var st: Vector3 = _v3(row["start"])
		assert_true(st.x > 4.0 and st.x < 16.0 and st.z > 26.0 and st.z < 31.85, "%s starts in the Waschkaue" % row["id"])
		var last: Vector3 = _v3((row["outside"] as Array).back())
		if str(row["fate"]) == "caught":
			assert_true(_on_navmesh(_scene, last), "%s falls (and rises) on the yard's navmesh" % row["id"])
			assert_true(last.z > 20.0 and last.z < 26.0, "%s is caught in the south lane, in front of the Kaue" % row["id"])
		else:
			assert_eq(str(row["fate"]), "escape")
			var crossed: bool = false
			var pts: Array = (row["route"] as Array) + (row["outside"] as Array)
			for k: int in pts.size() - 1:
				var a: Vector3 = _v3(pts[k])
				var b: Vector3 = _v3(pts[k + 1])
				if a.z > 0.0 and b.z <= 0.0:
					var f: float = a.z / (a.z - b.z)
					var x: float = lerpf(a.x, b.x, f)
					crossed = x > GATE_X0 + 0.3 and x < GATE_X1 - 0.3
			assert_true(crossed, "%s leaves the yard through the gateway" % row["id"])
	assert_eq(InnOpening.riser_ids(c).size(), 2, "two rise")
	for a2: Dictionary in c["attackers"]:
		assert_true(ids.has(str(a2["prey"])), "an attacker's prey is a patron")
		assert_true(_on_navmesh(_scene, _v3(a2["pos"])), "the attacker rises on the yard's navmesh at %s" % str(a2["pos"]))
	for ln: Dictionary in c["lines"]:
		assert_true(lines.has(str(ln["id"])), "line %s exists" % ln["id"])
		assert_true(ids.has(str(ln["who"])))
	assert_true(lines.has(str(c["look"]["cue_line"]["id"])), "the cue's line exists")
	var g: Dictionary = c["gate"]
	var exits: Dictionary = InnOpening.exit_times(c)
	for id: String in ["gorny", "kania"]:
		assert_true(float(exits[id]) >= float(g["open_at"]) - 0.5 and float(exits[id]) < float(g["close_at"]) - 2.0, "%s reaches the gate while it is open (%.1f s)" % [id, float(exits[id])])
	assert_false(c.has("squad_line"), "no squad line on a rise (the squad's INN_RISE lines name Map 0's people)")
