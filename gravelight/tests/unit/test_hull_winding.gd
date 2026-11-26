extends GutTest
## T-282 (the owner: "the submarines on map 3 need work they are transparent from certain angles"): the lofted hulls
## the generators build in code are closed and wound outward, so back-face culling never shows the inside through
## them. Headless: builds each hull in a bare Node3D (no scene, no renderer) and reads its triangles.
##
## For a hull meant to be a closed solid (U-1047, the dead U-boat, both conning tower fairings):
##   - open edges: an edge with one triangle on it is a crack you can see through (0 allowed);
##   - non-manifold edges: three or more triangles on one edge (0 allowed);
##   - flipped by topology: two neighbours that run their shared edge the same way disagree; the side that disagrees
##     with the orientation giving a positive enclosed volume is flipped (0 allowed);
##   - flipped by rays: from just in front of each triangle, a ray along its normal crosses the rest of the hull an
##     odd number of times when the normal points inward (0 allowed). Independent of the topology: it needs no
##     welding and catches a flipped triangle on a crack's edge too.
## For the open shells (the patrol boat, the cutter's planking, Map 4's lofts, the V2) only the neighbour check
## applies: on an open sheet, one triangle wound against its neighbours is still a hole from the side you look from.

const WELD: float = 1000.0   # vertices within a millimetre are the same vertex


# ------------------------------------------------------------------ mesh reading

## Every triangle of the MeshInstance3D surfaces under `root` whose name passes `want`, in root's space, as a flat
## array (3 points per triangle, in the order the renderer winds them).
static func tris_under(root: Node3D, want: Callable) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not bool(want.call(mi)):
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _local_xf(root, mi)
		out.append_array(mesh_tris(mi.mesh, xf))
	return out


static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func mesh_tris(mesh: Mesh, xf: Transform3D = Transform3D.IDENTITY) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i: int in v.size():
				out.append(xf * v[i])
		else:
			for i: int in idx.size():
				out.append(xf * v[idx[i]])
	return out


# ------------------------------------------------------------------ the checks

static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * WELD), roundi(p.y * WELD), roundi(p.z * WELD))


## Topology of a triangle soup: open, non-manifold and same-direction (inconsistent) edges, and how many triangles
## are flipped against the orientation that encloses a positive volume (per connected piece).
static func topology(t: PackedVector3Array) -> Dictionary:
	var ids: Dictionary = {}
	var tv: Array[PackedInt32Array] = []
	var n_tri: int = t.size() / 3
	var live: Array[bool] = []
	for i: int in n_tri:
		var tri: PackedInt32Array = []
		for k: int in 3:
			var key: Vector3i = _key(t[i * 3 + k])
			if not ids.has(key):
				ids[key] = ids.size()
			tri.append(int(ids[key]))
		tv.append(tri)
		live.append(tri[0] != tri[1] and tri[1] != tri[2] and tri[0] != tri[2])
	var edges: Dictionary = {}   # Vector2i(lo, hi) -> [[tri, +1 if it runs lo->hi]]
	for i: int in n_tri:
		if not live[i]:
			continue
		for k: int in 3:
			var a: int = tv[i][k]
			var b: int = tv[i][(k + 1) % 3]
			var e: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(e):
				edges[e] = []
			(edges[e] as Array).append([i, 1 if a < b else -1])
	var open: int = 0
	var open_mid: PackedVector3Array = []
	var nonman: int = 0
	var incons: int = 0
	var nbr: Array = []
	nbr.resize(n_tri)
	for i: int in n_tri:
		nbr[i] = []
	for e: Vector2i in edges:
		var l: Array = edges[e]
		if l.size() == 1:
			open += 1
			var tri0: int = int(l[0][0])
			for k2: int in 3:
				var q0: int = tv[tri0][k2]
				var q1: int = tv[tri0][(k2 + 1) % 3]
				if Vector2i(mini(q0, q1), maxi(q0, q1)) == e:
					open_mid.append((t[tri0 * 3 + k2] + t[tri0 * 3 + (k2 + 1) % 3]) * 0.5)
		elif l.size() > 2:
			nonman += 1
		else:
			var same: bool = int(l[0][1]) == int(l[1][1])
			if same:
				incons += 1
			(nbr[int(l[0][0])] as Array).append([int(l[1][0]), same])
			(nbr[int(l[1][0])] as Array).append([int(l[0][0]), same])
	# orient each connected piece from a seed; the side whose unified orientation gives a positive volume is right
	var rel: PackedInt32Array = []
	rel.resize(n_tri)
	rel.fill(0)
	var flipped: int = 0
	var volume: float = 0.0
	for seed: int in n_tri:
		if not live[seed] or rel[seed] != 0:
			continue
		var comp: Array[int] = [seed]
		rel[seed] = 1
		var head: int = 0
		while head < comp.size():
			var i2: int = comp[head]
			head += 1
			for nb: Array in nbr[i2]:
				var j: int = int(nb[0])
				if rel[j] == 0:
					rel[j] = -rel[i2] if bool(nb[1]) else rel[i2]
					comp.append(j)
		var vol: float = 0.0
		for i3: int in comp:
			var p0: Vector3 = t[i3 * 3]
			vol += p0.dot(t[i3 * 3 + 2].cross(t[i3 * 3 + 1])) * float(rel[i3]) / 6.0   # Godot: front normal (c - a) x (b - a)
		var good: int = 1 if vol >= 0.0 else -1
		for i4: int in comp:
			if rel[i4] != good:
				flipped += 1
		volume += absf(vol)
	var raw_vol: float = 0.0
	for i5: int in n_tri:
		raw_vol += t[i5 * 3].dot(t[i5 * 3 + 2].cross(t[i5 * 3 + 1])) / 6.0
	return {"tris": n_tri, "open": open, "open_mid": open_mid, "nonmanifold": nonman, "inconsistent": incons, "flipped": flipped,
		"volume": volume, "signed_volume": raw_vol}


## Triangles whose normal points into the solid: a ray from just in front of the face, along its normal (nudged off
## any axis so it never runs along an edge), crosses the rest of the soup an odd number of times.
static func ray_flipped(t: PackedVector3Array) -> int:
	var n_tri: int = t.size() / 3
	var nudge: Vector3 = Vector3(0.0131, 0.0173, 0.0097)
	var bad: int = 0
	var lo: PackedVector3Array = []
	var hi: PackedVector3Array = []
	for i: int in n_tri:
		var a: Vector3 = t[i * 3]
		var b: Vector3 = t[i * 3 + 1]
		var c: Vector3 = t[i * 3 + 2]
		lo.append(Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z))))
		hi.append(Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z))))
	for i: int in n_tri:
		var a: Vector3 = t[i * 3]
		var b: Vector3 = t[i * 3 + 1]
		var c: Vector3 = t[i * 3 + 2]
		# Godot's front face is clockwise seen from the front: its outward normal is (c - a) x (b - a)
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var dir: Vector3 = (n + nudge).normalized()
		var o: Vector3 = (a + b + c) / 3.0 + n * 0.002
		var hits: int = 0
		for j: int in n_tri:
			if j == i:
				continue
			# slab test on the box first: the ray must reach it
			var l: Vector3 = lo[j]
			var h: Vector3 = hi[j]
			var tmin: float = 0.0
			var tmax: float = 1e9
			var miss: bool = false
			for ax: int in 3:
				var d: float = dir[ax]
				if absf(d) < 1e-9:
					if o[ax] < l[ax] - 1e-6 or o[ax] > h[ax] + 1e-6:
						miss = true
						break
				else:
					var t0: float = (l[ax] - o[ax]) / d
					var t1: float = (h[ax] - o[ax]) / d
					if t0 > t1:
						var sw: float = t0
						t0 = t1
						t1 = sw
					tmin = maxf(tmin, t0)
					tmax = minf(tmax, t1)
					if tmin > tmax + 1e-6:
						miss = true
						break
			if miss:
				continue
			if Geometry3D.ray_intersects_triangle(o, dir, t[j * 3], t[j * 3 + 1], t[j * 3 + 2]) != null:
				hits += 1
		if hits % 2 == 1:
			bad += 1
	return bad


## Triangles of an open sheet whose front faces against `out_of(centroid)` (the way that side should face), counting
## only faces that clearly lean one way (|cos| > 0.3) so a face edge-on to the hint is not judged.
static func facing_wrong(t: PackedVector3Array, out_of: Callable) -> Dictionary:
	var wrong: int = 0
	var judged: int = 0
	for i: int in t.size() / 3:
		var a: Vector3 = t[i * 3]
		var b: Vector3 = t[i * 3 + 1]
		var c: Vector3 = t[i * 3 + 2]
		var n: Vector3 = (c - a).cross(b - a)
		var o: Vector3 = out_of.call((a + b + c) / 3.0)
		if n.length_squared() < 1e-12 or o.length_squared() < 1e-12:
			continue
		var cs: float = n.normalized().dot(o.normalized())
		if absf(cs) < 0.3:
			continue
		judged += 1
		if cs < 0.0:
			wrong += 1
	return {"wrong": wrong, "judged": judged}


## The hull's surfaces from DetailMap02.type_vii (the lofted ones: the boot-top ribbon and the Props parts are not
## part of the shell).
static func _is_hull(mi: MeshInstance3D) -> bool:
	return mi.mesh is ArrayMesh and (String(mi.name).begins_with("Hull") or String(mi.name).begins_with("DeckCasing"))


static func _is_tower(mi: MeshInstance3D) -> bool:
	return mi.mesh is ArrayMesh and String(mi.name).begins_with("Tower")


func _build(f: Callable) -> Node3D:
	var g: Node3D = Node3D.new()
	f.call(g)
	return g


func _closed_ok(label: String, t: PackedVector3Array, min_tris: int = 50) -> void:
	var topo: Dictionary = topology(t)
	var rf: int = ray_flipped(t)
	gut.p("%s: %d tris, open %d, non-manifold %d, inconsistent %d, flipped (topology) %d, flipped (rays) %d, volume %.1f m3 (signed %.1f)" % [
		label, topo["tris"], topo["open"], topo["nonmanifold"], topo["inconsistent"], topo["flipped"], rf, topo["volume"], topo["signed_volume"]])
	assert_gt(int(topo["tris"]), min_tris, "%s: built" % label)
	assert_eq(int(topo["open"]), 0, "%s: no open edge (a crack you see through)" % label)
	assert_eq(int(topo["nonmanifold"]), 0, "%s: no edge shared by three faces" % label)
	assert_eq(int(topo["flipped"]), 0, "%s: no triangle wound against its neighbours" % label)
	assert_eq(rf, 0, "%s: every normal points out of the solid" % label)
	assert_gt(float(topo["signed_volume"]), 0.0, "%s: the shell faces outward as a whole" % label)


# ================================================================== the two U-boats

func test_u1047_hull_is_closed_and_wound_outward() -> void:
	var g: Node3D = _build(func(n: Node3D) -> void: DetailMap02.type_vii(n, 58.6, -2.6, "m2_hull", "m2_hull_red", "iron", 48.2))
	_closed_ok("U-1047 hull", tris_under(g, _is_hull))
	g.free()


func test_dead_uboat_hull_is_closed_and_wound_outward() -> void:
	var g: Node3D = _build(func(n: Node3D) -> void: DetailMap02.type_vii(n, 46.0, -2.6, "rust", "m2_hull_red"))
	_closed_ok("dead U-boat hull", tris_under(g, _is_hull))
	g.free()


func test_conning_tower_fairings_are_closed_and_wound_outward() -> void:
	var g: Node3D = _build(func(n: Node3D) -> void: DetailMap02.vii_tower(n, Vector3(-1.1, 0.0, 17.0), 1.5, 3.0, 3.4, "U 1047"))
	_closed_ok("U-1047 tower fairing", tris_under(g, _is_tower))
	g.free()
	var g2: Node3D = _build(func(n: Node3D) -> void: DetailMap02.vii_tower(n, Vector3(-1.0, 0.0, 13.0), 1.4, 2.6, 3.0, ""))
	_closed_ok("dead U-boat tower fairing", tris_under(g2, _is_tower))
	g2.free()


## The hull stays the boat it was: the same length, beam and depth (the colliders, the interior box and the deck are
## the generator's, not these meshes', but the hull must still hold the interior: T-180's hold_to).
func test_u1047_hull_keeps_its_lines() -> void:
	var g: Node3D = _build(func(n: Node3D) -> void: DetailMap02.type_vii(n, 58.6, -2.6, "m2_hull", "m2_hull_red", "iron", 48.2))
	var t: PackedVector3Array = tris_under(g, _is_hull)
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	for p: Vector3 in t:
		lo = lo.min(p)
		hi = hi.max(p)
	g.free()
	assert_almost_eq(hi.z - lo.z, 58.6, 0.05, "length")
	assert_almost_eq(hi.x, 3.4, 0.05, "half beam over the saddle tanks")
	assert_almost_eq(lo.y, -6.42, 0.05, "keel")
	assert_almost_eq(hi.y, -0.02, 0.01, "the casing's top")


# ================================================================== the other lofted shapes (step 3)

func _sheet_ok(label: String, t: PackedVector3Array, out_of: Callable = Callable()) -> Dictionary:
	var topo: Dictionary = topology(t)
	var line: String = "%s: %d tris, open %d, non-manifold %d, inconsistent %d" % [label, topo["tris"], topo["open"], topo["nonmanifold"], topo["inconsistent"]]
	assert_gt(int(topo["tris"]), 10, "%s: built" % label)
	assert_eq(int(topo["inconsistent"]), 0, "%s: no triangle wound against its neighbours" % label)
	if out_of.is_valid():
		var f: Dictionary = facing_wrong(t, out_of)
		line += ", facing the wrong way %d of %d judged" % [f["wrong"], f["judged"]]
		assert_gt(int(f["judged"]), int(topo["tris"]) / 3, "%s: most faces lean clearly one way" % label)
		assert_eq(int(f["wrong"]), 0, "%s: every face fronts the side it is seen from" % label)
	gut.p(line)
	return topo


## T-273's patrol boat (the same strip()): the outer shell away from the centre line, the bulwarks' inner face toward
## it, the decks and the bulwark cap up; the shell closed below the sheer (the stem and the transom down to the keel).
func test_patrol_boat_hull_faces_out_and_is_closed_below_the_sheer() -> void:
	var holder: Node3D = Node3D.new()
	DetailMap02.patrol_boat(holder, Vector3.ZERO, 0.0)
	var boat: Node3D = holder.get_node("PatrolBoat") as Node3D
	var named: Callable = func(names: Array) -> Callable:
		return func(mi: MeshInstance3D) -> bool: return String(mi.name) in names
	var away: Callable = func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, 0.0) if absf(p.x) > 0.3 else Vector3.ZERO
	var shell: PackedVector3Array = tris_under(boat, named.call(["HullTopsides", "HullBottom"]))
	var topo: Dictionary = _sheet_ok("patrol boat outer shell", shell, away)
	var low: int = 0
	for q: Vector3 in topo["open_mid"] as PackedVector3Array:
		if q.y < 2.0:   # the sheer is 0.9 m over the main deck (1.3) or higher: an open edge below 2 m is a hole
			low += 1
	assert_eq(low, 0, "patrol boat outer shell: open only along the sheer (%d open edges below it)" % low)
	# the stem and the transom close it fore and aft: rays out of the shell's faces never come back through it
	assert_eq(ray_flipped(shell), 0, "patrol boat outer shell: no face looks into the hull")
	var bulw: PackedVector3Array = tris_under(boat, named.call(["HullBulwarks"]))
	_sheet_ok("patrol boat bulwarks", bulw)
	var inner: PackedVector3Array = []
	var cap: PackedVector3Array = []
	for i: int in bulw.size() / 3:
		var a: Vector3 = bulw[i * 3]
		var b: Vector3 = bulw[i * 3 + 1]
		var c: Vector3 = bulw[i * 3 + 2]
		var n: Vector3 = (c - a).cross(b - a)
		(cap if absf(n.normalized().y) > 0.7 else inner).append_array([a, b, c])
	_sheet_ok("patrol boat bulwarks, inner face", inner, func(p: Vector3) -> Vector3: return Vector3(-p.x, 0.0, 0.0) if absf(p.x) > 0.3 else Vector3.ZERO)
	_sheet_ok("patrol boat bulwark cap", cap, func(_p: Vector3) -> Vector3: return Vector3.UP)
	_sheet_ok("patrol boat decks", tris_under(boat, named.call(["HullDecks"])), func(_p: Vector3) -> Vector3: return Vector3.UP)
	holder.free()


## The beached cutter's clinker planking (the same strip()): each strake and rubbing strake faces out, and has its
## inner face (seen over the gunwale from above) facing in.
func test_cutter_planking_faces_both_ways() -> void:
	var g: Node3D = _build(func(n: Node3D) -> void: DetailMap02.cutter(n, 10.0, 5.8, 2.4))
	var outs: int = 0
	var ins: int = 0
	for n: Node in g.get_children():
		if not (n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh):
			continue
		var nm: String = String(n.name)
		var inner: bool = nm.contains("In")
		var t: PackedVector3Array = mesh_tris((n as MeshInstance3D).mesh, (n as MeshInstance3D).transform)
		_sheet_ok("cutter %s" % nm, t, func(p: Vector3) -> Vector3: return Vector3(0.0, 0.0, -p.z if inner else p.z))
		if inner:
			ins += 1
		else:
			outs += 1
	assert_eq(outs, 14, "six strakes and a rubbing strake a side")
	assert_eq(ins, outs, "each with its inner face")
	g.free()


## T-276's V2 (wound by hand, not strip()): the body faces away from its axis and the fins are closed solids.
func test_v2_rocket_faces_out() -> void:
	var r: Node3D = V2Model.rocket()
	var body: PackedVector3Array = tris_under(r, func(mi: MeshInstance3D) -> bool: return String(mi.name).begins_with("Body"))
	_sheet_ok("V2 body", body, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z))
	var k: int = 0
	for fin: Node in r.get_children():
		if String(fin.name).begins_with("Fin"):
			_closed_ok("V2 %s" % fin.name, tris_under(fin as Node3D, func(mi: MeshInstance3D) -> bool: return mi.mesh is ArrayMesh), 10)
			k += 1
	assert_eq(k, 4, "four fins")
	r.free()


## Map 4's flying wing hull (GenDetail.flying_wing_mesh, wound by hand) is a closed solid facing out.
func test_flying_wing_hull_is_closed_and_wound_outward() -> void:
	var p: Dictionary = load("res://gravelight/tools_src/gen_map04a.gd").KRANICH_WING
	_closed_ok("Kranich wing (map04a)", mesh_tris(GenDetail.flying_wing_mesh(p, 18, 12)))


## Map 4 Act III's wrecked Kranich (detail_map04c.face(): Godot's rule, an outward hint per polygon): an open shell
## (the belly lies on the salt), so only its neighbours are checked: none wound against the others.
func test_kranich_wreck_shell_has_no_flipped_faces() -> void:
	var holder: Node3D = Node3D.new()
	load("res://gravelight/tools_src/detail_map04c.gd").kranich_shell(holder)
	var k: int = 0
	for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh is ArrayMesh and not ((mi.mesh as ArrayMesh).get_surface_count() == 0):
			_sheet_ok("Kranich wreck %s" % mi.name, tris_under(holder, func(x: MeshInstance3D) -> bool: return x == mi))
			k += 1
	assert_gt(k, 0, "the shell's meshes")
	holder.free()
