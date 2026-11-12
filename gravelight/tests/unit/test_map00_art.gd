extends GutTest
## UPDATE_05 section 5 (DECISIONS T-093): Map 0's environment art. Every material key the generator uses resolves to
## the CC0 library, the art pass never moved the navmesh (both bakes fingerprint the same as the bake T-093 started
## from), the library props and the scripted nature carry no collision and sit outside the navigation region, the
## nature models keep ART_BIBLE's budgets, and the props near each fixed capture camera stay inside a triangle budget.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
## SHA-1 over the navigation mesh's vertices and polygons (var_to_bytes), from master ab098f8, the bake T-093 began
## with. A change here means gameplay geometry moved: the art pass must never do that (UPDATE_05 section 0.4).
## Re-baked by T-120: the stair-rail panel no longer reaches the taproom floor beside the bar.
## Re-baked by T-126: GRAVELIGHT ONE's hull is hollow (the cabin, its two starboard openings).
## Re-baked by T-141: Ledger Lager's footprint in the cellar's south-east corner (gen_map00 CELLAR_PERKS).
## Re-baked by T-179: the cellar's late-delivery bay (gen_map00 BAY_*) and its two machines; every navmesh vertex outside the
## bay (and the field over it) is unchanged.
## Re-baked by T-211: GRAVELIGHT ONE is a real C-47 (UPDATE 12 section 5): the starboard wing and nacelle off the hull,
## the tail, both tailplanes, the starboard wing, the port wing's outer panel and the port engine as debris boxes
## (data/gravelight/c47_colliders.json), the nose cone, the crates in the cabin; the hull's own colliders and openings
## unchanged. Only polygons in the crash field (x 22..61, z -26..36) and their neighbours in the open snow changed.
## Re-baked by T-224: the attic over the guest rooms (gen_map00 ATT_* / ASTAIR_*: the floor with its stair well, the flight
## along the upstairs hall's south wall, the two gable ledges) and the bigger bar (BAR_* / SHELF_*: the counter 1.1 m west
## and 0.6 m further north, the cask behind it). Nothing else moved: the taproom loop, the Old Cellar door walkway, the
## stable, the yard, the grounds and the cellars bake the same polygons.
## Re-baked by T-238 (the owner's final layout pass): the stable's bales against the north wall (STABLE_BALES; they were
## drawn, not solid, in the north door's lane), the loft stack's third course (LOFT_TOP_BALES), the Helvetia cellar's
## north-east corner (the bench and two crates 0.75 m deep; the 2.65 x 1.65 m heap and the crates between the Crucible
## and the lever are gone), the taproom's signals crates against the east wall (TapCrates). The polygons round those four
## places changed; the doors, stairs, loops and spawns are where they were (smoke_map00, smoke_map00_loop).
const NAV_FP: Dictionary = {
	"Navigation": "34288fbef085dcf414f4e581e7c11ed94161479c",   # 2026-11-12: the upstairs hall 5 m deep, the attic flight 2.1 m, the bar walkway 2.25 m
	"NavigationBreachOpen": "d169f3d7d34a588e1d9dc661e47825847187d8a8",
}
## Library-prop triangles within CAM_RADIUS of any capture camera (data/gravelight/capture_cams.json).
const CAM_RADIUS: float = 12.0
const CAM_TRI_BUDGET: int = 200000

var map: Node


func before_all() -> void:
	map = (load(MAP) as PackedScene).instantiate()


func after_all() -> void:
	if map != null:
		map.free()


static func nav_fingerprint(nm: NavigationMesh) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(var_to_bytes(nm.get_vertices()))
	for i: int in nm.get_polygon_count():
		ctx.update(var_to_bytes(nm.get_polygon(i)))
	return ctx.finish().hex_encode()


func test_navmesh_unchanged_by_the_art_pass() -> void:
	for rn: String in NAV_FP.keys():
		var r: NavigationRegion3D = map.get_node_or_null(rn) as NavigationRegion3D
		assert_not_null(r, rn)
		if r == null:
			continue
		assert_eq(nav_fingerprint(r.navigation_mesh), str(NAV_FP[rn]), "%s is byte-for-byte the T-136 bake (T-093 art pass; T-106 dropped furniture-top islands; T-120 the bar walkway; T-126 the wreck's cabin; T-136 the bank in the old woodshed; T-179 the cellar's late-delivery bay; T-211 the C-47; T-229 the sniper tower's deck and the cellar hatch cut; 2026-11-12 the hall, the attic flight and the bar walkway widened)" % rn)


## T-120: the walkway between the bar's west end and the stairwell wall (the way to the Old Cellar door) is open.
## The stair-rail panel used to run down to the floor to z 8.95, an invisible wall at x 3.6 that players and
## zombies stuck on. Nothing solid stands there below head height, and the navmesh covers it.
func test_bar_walkway_has_no_invisible_wall() -> void:
	# sample the walkway (x 1..4.9, z 8.95..9.7, 0.1..1.9 m up) against every box collider, oriented as placed
	var pts: Array[Vector3] = []
	for xi: int in 20:
		for zi: int in 4:
			for yi: int in 4:
				pts.append(Vector3(1.0 + xi * 0.2, 0.1 + yi * 0.6, 8.95 + zi * 0.25))
	var blockers: PackedStringArray = []
	for n: Node in map.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs.disabled or not (cs.shape is BoxShape3D) or not (cs.get_parent() is StaticBody3D):
			continue
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var inv: Transform3D = _local_xf(cs).affine_inverse()
		for pt: Vector3 in pts:
			var lp: Vector3 = inv * pt
			if absf(lp.x) < half.x and absf(lp.y) < half.y and absf(lp.z) < half.z:
				blockers.append("%s at %s" % [cs.get_parent().name, str(pt)])
				break
	assert_eq(blockers.size(), 0, "nothing solid in the bar walkway: %s" % ", ".join(blockers))
	var nm: NavigationMesh = (map.get_node("Navigation") as NavigationRegion3D).navigation_mesh
	var verts: PackedVector3Array = nm.get_vertices()
	for pt2: Vector2 in [Vector2(3.6, 9.0), Vector2(2.5, 9.0), Vector2(3.0, 8.9)]:
		var on: bool = false
		for i: int in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			if absf(verts[poly[0]].y) > 0.6:
				continue   # the cellar below, the floor above
			var flat: PackedVector2Array = PackedVector2Array()
			for vi: int in poly:
				flat.append(Vector2(verts[vi].x, verts[vi].z))
			if Geometry2D.is_point_in_polygon(pt2, flat):
				on = true
				break
		assert_true(on, "the taproom navmesh runs through the bar walkway at %s" % str(pt2))


## A node's transform relative to the map root (the map isn't in the tree here).
static func _local_xf(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p is Node3D and p.get_parent() != null:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func test_every_generator_material_key_resolves_to_the_library() -> void:
	var g: Dictionary = MaterialLibrary.data()["generator"]
	assert_true(bool(g["use_library"]))
	for k: String in g["enabled"]:
		var m: Material = MaterialLibrary.for_generator(k)
		assert_not_null(m, "Mats key %s resolves" % k)
		assert_true(m is ShaderMaterial, "%s is the shared surface shader" % k)
	# the keys gen_map00 draws its walls, floors, roofs, timber and cellars with are all on
	for k2: String in ["plaster", "plaster_upper", "floorboards", "planks", "stone", "roof", "beam", "furniture", "wainscot", "iron",
			"snow", "snow_trodden", "dirt", "hay", "straw_floor", "cellar_stone", "cellar_floor", "brick_cellar", "limewash", "wreck", "bark", "rock"]:
		assert_true((g["enabled"] as Array).has(k2), "%s is switched to the library" % k2)
	# and the procedural key the stairwell's panels derive from never reaches its StandardMaterial3D cast
	assert_true(Mats.get_mat("wainscot_matte") is ShaderMaterial)


func test_library_props_are_visual_only() -> void:
	var ps: PropScatter = map.get_node_or_null("LibraryProps") as PropScatter
	assert_not_null(ps, "the LibraryProps scatter")
	if ps == null:
		return
	assert_gt(ps.items.size(), 50, "tables, chairs, beds, casks...")
	for it: Array in ps.items:
		assert_true(PropLibrary.has_key(str(it[0])), "%s is a library prop" % it[0])
	for key: String in ["table_round", "table_rect", "chair_farmhouse", "bed_iron", "nightstand", "barrel_wine"]:
		assert_gt(ps.count(key), 0, "%s is placed" % key)
	ps.build()
	assert_gt(ps.get_child_count(), 0, "built its MultiMeshes")
	assert_eq(ps.find_children("*", "CollisionObject3D", true, false).size(), 0, "no bodies")
	assert_eq(ps.find_children("*", "CollisionShape3D", true, false).size(), 0, "no shapes")
	var nav: Node = map.get_node("Navigation")
	assert_false(nav.is_ancestor_of(ps), "outside the navigation region (never baked)")


func test_tables_keep_their_tops_at_the_story_props_height() -> void:
	var ps: PropScatter = map.get_node("LibraryProps") as PropScatter
	for it: Array in ps.items:
		if str(it[0]) != "table_round" and str(it[0]) != "table_rect":
			continue
		var xf: Transform3D = it[1]
		var top: float = 0.723 if str(it[0]) == "table_round" else 0.8
		assert_almost_eq(xf.origin.y + top * xf.basis.y.length(), 0.75, 0.005, "a table top at 0.75 m (the meals and the map lie on it)")


func test_nature_models_keep_the_budgets() -> void:
	for n: String in ["Spruce_LOD0", "Birch_LOD0"]:
		var m: Mesh = Landscape.nature_mesh(n)
		assert_not_null(m, n)
		if m != null:
			assert_lte(_tris(m), 4000, "%s within the tree LOD0 budget" % n)
	for n2: String in ["Spruce_LOD1", "Birch_LOD1"]:
		var m2: Mesh = Landscape.nature_mesh(n2)
		assert_not_null(m2, n2)
		if m2 != null:
			assert_lte(_tris(m2), 1200, "%s within the LOD1 budget" % n2)
	for n3: String in ["Bush_A", "Bush_B", "Rock_A", "Rock_B", "Rock_C"]:
		var m3: Mesh = Landscape.nature_mesh(n3)
		assert_not_null(m3, n3)
		if m3 != null:
			assert_lte(_tris(m3), 1000, n3)
	var t: Mesh = Landscape.tree_mesh("Spruce_LOD0", true)
	assert_not_null(t)
	if t != null:
		for i: int in t.get_surface_count():
			assert_true(t.surface_get_material(i) is ShaderMaterial, "spruce surface %d has a tree material" % i)


func test_edge_tree_line_is_scripted_and_collision_free() -> void:
	var rows: NatureRows = map.find_child("EdgeTrees", true, false) as NatureRows
	assert_not_null(rows, "the edge tree line")
	if rows == null:
		return
	assert_gt(rows.spruces.size() + rows.birches.size(), 100)
	rows.build()
	assert_eq(rows.find_children("*", "CollisionObject3D", true, false).size(), 0)
	assert_false(map.get_node("Navigation").is_ancestor_of(rows))


func test_prop_triangles_near_each_capture_camera() -> void:
	var cams: Dictionary = GLData.load_json("res://data/gravelight/capture_cams.json")
	var list: Array = ((cams.get("sets", {}) as Dictionary).get("u05", {}) as Dictionary).get("cams", [])
	assert_gt(list.size(), 20)
	var ps: PropScatter = map.get_node("LibraryProps") as PropScatter
	var tris_of: Dictionary = {}
	for key: String in PropLibrary.keys():
		tris_of[key] = int(PropLibrary.entry(key).get("tris", 3000))
	for c: Dictionary in list:
		var p: Array = c["pos"]
		var at: Vector3 = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var total: int = 0
		for it: Array in ps.items:
			if (it[1] as Transform3D).origin.distance_to(at) <= CAM_RADIUS:
				total += int(tris_of.get(str(it[0]), 3000))
		assert_lte(total, CAM_TRI_BUDGET, "library props near %s: %d tris" % [c["name"], total])


static func _tris(m: Mesh) -> int:
	var n: int = 0
	for s: int in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		n += ((idx as PackedInt32Array).size() if idx != null and (idx as PackedInt32Array).size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n
