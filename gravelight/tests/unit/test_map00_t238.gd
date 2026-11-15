extends GutTest
## T-238, the Inn's final layout and dressing pass (the owner: "make sure the maps feel smooth and everything looks
## logically placed, the cellar for example is too cluttered, the haystacks feel half baked in the barn"). What a
## headless run can hold on to: every hay collider has art of its own size and nothing solid or drawn-solid stands in
## the stable's north-door lane; the Helvetia cellar's north wall and back-panel walks are clear; the taproom's crates
## are against the wall with a collider; the hay meshes are closed, bevelled boxes.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const Hay: Script = preload("res://gravelight/world/props_hay.gd")

var map: Node
var boxes: Array = []   # [name, AABB] of every box collider, in map space


func before_all() -> void:
	map = (load(MAP) as PackedScene).instantiate()
	for b: Node in map.find_children("*", "StaticBody3D", true, false):
		var body: StaticBody3D = b as StaticBody3D
		var xf: Transform3D = body.transform
		var p: Node = body.get_parent()
		while p != null and p != map:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for c: Node in body.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				var sz: Vector3 = (cs.shape as BoxShape3D).size
				boxes.append([String(body.name), (xf * cs.transform) * AABB(-sz * 0.5, sz)])


func after_all() -> void:
	map.free()


func _named(part: String) -> Array[AABB]:
	var out: Array[AABB] = []
	for b: Array in boxes:
		if str(b[0]).contains(part):
			out.append(b[1])
	return out


## Every collider a sample point is inside (a point a player's body would be at).
func _solid_at(p: Vector3) -> String:
	for b: Array in boxes:
		if (b[1] as AABB).has_point(p):
			return str(b[0])
	return ""


func test_the_stable_bales_are_solid_and_against_the_wall() -> void:
	var sb: Array[AABB] = _named("StableBales")
	assert_eq(sb.size(), 1, "the ground-floor bale stack has one collider")
	if sb.size() == 1:
		assert_almost_eq(sb[0].position.z, 22.15, 0.02, "against the north wall's inner face")
		assert_almost_eq(sb[0].size.y, 0.9, 0.01, "two courses")
		assert_gt(sb[0].position.x, 21.5, "east of the north door (x 18.5..21.5)")
		assert_lt(sb[0].end.x, 23.45, "short of the stair's line (its foot is 2.8 m further south)")
	assert_eq(_named("LoftBaleTop").size(), 3, "the loft stack's third course is solid")
	assert_eq(_named("HayBales").size(), 1, "the loft stack's collider is where it was")
	var hb: AABB = _named("HayBales")[0]
	assert_almost_eq(hb.size, Vector3(3.2, 0.9, 3.2), Vector3(0.01, 0.01, 0.01))


## The north door's lane through the stable to the great doors and the yard door: the five bale boxes that stood in it
## (drawn, not solid) are gone, and nothing solid has taken their place.
func test_the_north_door_lane_is_clear() -> void:
	for zi: int in 22:
		for xi: int in 5:
			for y: float in [0.15, 0.9, 1.6]:
				var p: Vector3 = Vector3(19.0 + xi * 0.5, y, 22.6 + zi * 0.5)
				assert_eq(_solid_at(p), "", "nothing solid at %s" % str(p))


func test_the_helvetia_cellar_is_thinned() -> void:
	assert_eq(_named("CellarBarrelCol").size(), 0, "the north-east corner's heap is gone")
	var bench: Array[AABB] = _named("CellarBenchCol")
	assert_eq(bench.size(), 1)
	if bench.size() == 1:
		assert_lt(bench[0].end.z, 19.95, "the bench stands 0.75 m off the north wall, not 1.65")
	# the lever's approach: bare floor from the Crucible's column to the crates at the bench's end
	for xi: int in 12:
		for zi: int in 5:
			var p: Vector3 = Vector3(31.2 + xi * 0.2, -3.2 + 0.4, 19.5 + zi * 0.25)
			assert_eq(_solid_at(p), "", "the lever's approach is clear at %s" % str(p))
	# the strip along the east wall south of the bench: T-238 opened it as the walk behind Twin Barrel (it ended in
	# the corner's heap). Since T-255 perk spot vault_east stands there on the wall: its own bake box is the one
	# thing that may be in the strip (the heap stays gone)
	for zi2: int in 8:
		var solid: String = _solid_at(Vector3(35.2, -2.6, 20.1 + zi2 * 0.3))
		assert_true(solid == "" or solid == "NavBlock_PerkSpot_vault_east", "the east wall's strip at z %.1f holds %s" % [20.1 + zi2 * 0.3, solid])


func test_the_taproom_crates_are_solid_in_their_corner() -> void:
	var tc: Array[AABB] = _named("TapCrates")
	assert_eq(tc.size(), 2)
	for a: AABB in tc:
		assert_gt(a.end.x, 23.8, "against the east wall")
		assert_lt(a.end.z, 3.0, "north of the Garand's chalk window (z 3.1..4.9)")
	# where they stood: open floor between the front door and the Garand
	for p: Vector3 in [Vector3(22.8, 0.4, 2.0), Vector3(21.9, 0.3, 2.2), Vector3(22.7, 1.0, 2.1)]:
		assert_eq(_solid_at(p), "")


func test_the_soft_box_is_a_closed_bevelled_box() -> void:
	var size: Vector3 = Vector3(0.9, 0.45, 0.5)
	var m: ArrayMesh = Hay.soft_box_mesh(size, Vector3(0.055, 0.055, 0.055))
	var arr: Array = m.surface_get_arrays(0)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 24)
	assert_eq(idx.size() / 3, 44, "12 face + 24 bevel + 8 corner triangles")
	assert_almost_eq(m.get_aabb().size, size, Vector3(0.001, 0.001, 0.001), "the art is the collider's size")
	# closed: every edge is shared by exactly two triangles, and every triangle faces out (clockwise front faces)
	var edges: Dictionary = {}
	for t: int in idx.size() / 3:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		assert_lt((b - a).cross(c - a).dot(a + b + c), 0.0, "triangle %d faces out" % t)
		for e: Array in [[idx[t * 3], idx[t * 3 + 1]], [idx[t * 3 + 1], idx[t * 3 + 2]], [idx[t * 3 + 2], idx[t * 3]]]:
			var k: String = "%d-%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
			edges[k] = int(edges.get(k, 0)) + 1
	for k2: String in edges.keys():
		assert_eq(int(edges[k2]), 2, "edge %s" % k2)


## The hay heap's ground spawn and the puff zone stayed where the heap is.
func test_the_hay_heap_keeps_its_spawn() -> void:
	var sp: Node3D = map.find_child("Spawn_HayPile", true, false) as Node3D
	assert_not_null(sp)
	if sp != null:
		assert_almost_eq(sp.position, Vector3(22.5, 0, 23.7), Vector3(0.01, 0.01, 0.01), "the spawn did not move")
		assert_eq(_solid_at(sp.position + Vector3(0, 0.5, 0)), "", "and stands clear of the bale stack")
