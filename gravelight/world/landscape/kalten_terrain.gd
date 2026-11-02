class_name KaltenTerrain
extends RefCounted
## The land around Kaltenbrunn's Minehead Yard (UPDATE 10 section 5, DECISIONS T-161): one height function and the
## mesh builders, pure maths and deterministic like LandscapeTerrain (Map 0's), so KaltenLandscape rebuilds the same
## world at load time and the unit tests can probe it. Frame as in gen_map01.gd: +X east, +Z south, yard north wall at
## z = 0.
##
##   shelf    the play space's surface (the yard, the rail yard, the lift house): flat, at y = 0, edge to edge with the
##            map's Ground slabs, so the terrain starts where the colliders end
##   valley   to the north, east and west the shelf breaks away into a snow valley ~40 m down (the cable car spans it,
##            the buried rail line runs a terrace along its flank and off into the dark)
##   mountain to the south the land climbs: the mine is dug into the hillside, so the gallery, lab and vault sit under it
##   foothills and the ridge bands beyond r ~ 150 (the forest lives on the foothills); the ridge bands are
##            LandscapeTerrain.build_ridge() with this map's crest function (Alpine: tall, jagged)

const CENTER: Vector2 = Vector2(24.0, 26.0)
## The Ground slabs' bounding rectangle (gen_map01 build_surface): the terrain's hole.
const SHELF_MIN: Vector2 = Vector2(-40.0, -25.0)
const SHELF_MAX: Vector2 = Vector2(100.0, 58.0)
const CELL: float = 6.0
const GRID_CELLS: int = 102
const GRID_MIN: Vector2 = Vector2(-282.0, -280.0)
const NEAR_R: float = 150.0
const GRID_R: float = 300.0
## The snow-buried rail line: [x, z, railbed y]. Leaves the rail yard's north end (x 44..52) and traverses the valley's
## flank to the north-east, down into the dark.
const RAIL: Array = [Vector3(48.0, 13.0, -0.05), Vector3(48.0, -30.0, -0.05), Vector3(70.0, -52.0, -4.0), Vector3(112.0, -62.0, -9.0),
	Vector3(158.0, -64.0, -14.0), Vector3(206.0, -92.0, -19.0), Vector3(252.0, -140.0, -23.0)]
## The dead cable car (towers and cables are KaltenLandscape's): A on the shelf's north-east corner, B on the far flank.
const CABLE_A: Vector3 = Vector3(86.0, 0.0, -18.0)
const CABLE_B: Vector3 = Vector3(176.0, 0.0, -176.0)
const TOWER_H: float = 15.0

static var _n_hill: FastNoiseLite
static var _n_near: FastNoiseLite
static var _n_ridge: FastNoiseLite
static var _n_forest: FastNoiseLite


static func _noises() -> void:
	if _n_hill != null:
		return
	_n_hill = FastNoiseLite.new()
	_n_hill.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_hill.seed = 1947
	_n_hill.frequency = 0.0085
	_n_hill.fractal_octaves = 4
	_n_near = FastNoiseLite.new()
	_n_near.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_near.seed = 3311
	_n_near.frequency = 0.03
	_n_near.fractal_octaves = 3
	_n_ridge = FastNoiseLite.new()
	_n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_ridge.seed = 88
	_n_ridge.frequency = 1.0
	_n_ridge.fractal_octaves = 5
	_n_forest = FastNoiseLite.new()
	_n_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_forest.seed = 4141
	_n_forest.frequency = 0.014
	_n_forest.fractal_octaves = 2


static func _u(n: FastNoiseLite, x: float, z: float) -> float:
	return n.get_noise_2d(x, z) * 0.5 + 0.5


static func shelf_distance(x: float, z: float) -> float:
	var dx: float = maxf(maxf(SHELF_MIN.x - x, 0.0), x - SHELF_MAX.x)
	var dz: float = maxf(maxf(SHELF_MIN.y - z, 0.0), z - SHELF_MAX.y)
	return sqrt(dx * dx + dz * dz)


static func radius(x: float, z: float) -> float:
	return Vector2(x, z).distance_to(CENTER)


## Nearest point on the rail polyline: x = distance, y = the railbed height there.
static func rail_info(x: float, z: float) -> Vector2:
	var p: Vector2 = Vector2(x, z)
	var best: float = 1e9
	var by: float = 0.0
	for i: int in RAIL.size() - 1:
		var a: Vector3 = RAIL[i]
		var b: Vector3 = RAIL[i + 1]
		var a2: Vector2 = Vector2(a.x, a.y)
		var b2: Vector2 = Vector2(b.x, b.y)
		var ab: Vector2 = b2 - a2
		var t: float = clampf((p - a2).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d: float = p.distance_to(a2 + ab * t)
		if d < best:
			best = d
			by = lerpf(a.z, b.z, t)
	return Vector2(best, by)


static func height(x: float, z: float) -> float:
	_noises()
	var d: float = shelf_distance(x, z)
	if d <= 0.0:
		return -0.05
	var r: float = radius(x, z)
	var sz: float = z - SHELF_MAX.y
	var n1: float = _u(_n_hill, x, z)
	var n2: float = _u(_n_near, x, z)
	# the valley: a flat lip, then the fall
	var drop: float = smoothstep(7.0, 78.0, d)
	var foot: float = smoothstep(140.0, 285.0, r) * (16.0 + 62.0 * pow(n1, 1.25))
	var vh: float = -44.0 * drop + 6.0 * (n1 - 0.4) * drop + 3.0 * (n2 - 0.4) * smoothstep(3.0, 20.0, d) + foot
	# the mountain to the south: the mine is dug into the hillside
	var side: float = maxf(SHELF_MIN.x - x, x - SHELF_MAX.x - 8.0)
	var south_w: float = smoothstep(0.0, 2.0, sz) * (1.0 - smoothstep(30.0, 120.0, side))
	var mh: float = -0.05 + 3.6 * smoothstep(0.0, 4.0, sz) + sz * 0.46 + 5.0 * (n2 - 0.3) * smoothstep(0.0, 30.0, sz) + foot * 0.6
	var h: float = lerpf(vh, mh, south_w)
	# the rail terrace
	var ri: Vector2 = rail_info(x, z)
	var cut: float = 1.0 - smoothstep(3.5, 13.0, ri.x)
	h = lerpf(h, ri.y - 0.35 + (n2 - 0.4) * 0.3, cut * smoothstep(0.0, 9.0, d))
	return h


## Height of the ridge bands' crest on a bearing: band 0 the nearer, wooded ridge, band 1 the Alpine wall behind it.
static func ridge_crest(band: int, bearing_deg: float) -> float:
	_noises()
	var a: float = deg_to_rad(bearing_deg)
	var c: Vector2 = Vector2(cos(a), sin(a))
	var jag: float = _n_ridge.get_noise_2d(c.x * 5.0 + 11.0, c.y * 5.0) * 0.5 + 0.5
	var broad: float = _n_ridge.get_noise_2d(c.x * 1.3 + 5.0, c.y * 1.3) * 0.5 + 0.5
	if band == 0:
		return 38.0 + 46.0 * broad + 18.0 * pow(jag, 2.0)
	# the main chain runs along the north and the east (the cable car's far side), lower to the south-west
	var north: float = 0.5 + 0.5 * cos(deg_to_rad(bearing_deg - 20.0))
	return 70.0 + 120.0 * pow(north, 1.2) * (0.55 + 0.45 * broad) + 55.0 * pow(jag, 2.2) * (0.5 + north)


static func forest_density(x: float, z: float) -> float:
	_noises()
	var r: float = radius(x, z)
	var d: float = shelf_distance(x, z)
	if d < 20.0 or r > GRID_R - 4.0:
		return 0.0
	var h: float = height(x, z)
	var clump: float = smoothstep(0.40, 0.66, _u(_n_forest, x, z))
	# trees on the valley flanks and the foothills, not on the bare valley floor or the high scree
	var band: float = smoothstep(-34.0, -14.0, h) * (1.0 - smoothstep(32.0, 70.0, h))
	var ring: float = 0.2 + 0.8 * smoothstep(90.0, 170.0, r)
	var dens: float = clump * band * ring
	dens *= smoothstep(10.0, 22.0, rail_info(x, z).x)
	return clampf(dens, 0.0, 1.0)


## Vertex colour masks: r = the trodden rail terrace, b = forest floor.
static func masks(x: float, z: float) -> Color:
	var road: float = (1.0 - smoothstep(1.6, 3.2, rail_info(x, z).x)) * 0.35
	return Color(road, 0.0, forest_density(x, z), 1.0)


static func _grid_point(i: int, j: int) -> Vector3:
	var x: float = GRID_MIN.x + float(i) * CELL
	var z: float = GRID_MIN.y + float(j) * CELL
	return Vector3(x, height(x, z), z)


## The near and mid terrain as one ArrayMesh with two surfaces (0 = near, 1 = mid), the shelf cut out.
static func build_grid() -> ArrayMesh:
	var n: int = GRID_CELLS + 1
	var pos: PackedVector3Array = PackedVector3Array()
	pos.resize(n * n)
	var col: PackedColorArray = PackedColorArray()
	col.resize(n * n)
	for j: int in n:
		for i: int in n:
			var p: Vector3 = _grid_point(i, j)
			pos[j * n + i] = p
			col[j * n + i] = masks(p.x, p.z)
	var nrm: PackedVector3Array = PackedVector3Array()
	nrm.resize(n * n)
	for j: int in n:
		for i: int in n:
			var hl: float = pos[j * n + maxi(i - 1, 0)].y
			var hr: float = pos[j * n + mini(i + 1, n - 1)].y
			var hd: float = pos[maxi(j - 1, 0) * n + i].y
			var hu: float = pos[mini(j + 1, n - 1) * n + i].y
			nrm[j * n + i] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
	var mesh: ArrayMesh = ArrayMesh.new()
	for surf: int in 2:
		var idx: PackedInt32Array = PackedInt32Array()
		for j: int in GRID_CELLS:
			for i: int in GRID_CELLS:
				var a: Vector3 = pos[j * n + i]
				var c: Vector3 = pos[(j + 1) * n + i + 1]
				var mid: Vector3 = (a + c) * 0.5
				if mid.x > SHELF_MIN.x and mid.x < SHELF_MAX.x and mid.z > SHELF_MIN.y and mid.z < SHELF_MAX.y:
					continue
				var r: float = radius(mid.x, mid.z)
				if r > GRID_R:
					continue
				if (surf == 0) != (r < NEAR_R):
					continue
				var k: int = j * n + i
				idx.append_array([k, k + 1, k + n + 1, k, k + n + 1, k + n])
		if idx.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Tree placements: [Transform3D] for mesh spruces (near the valley) and impostor cards (further), jittered lattice
## over the forest density.
static func forest_transforms(step: float, seed_v: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var near_t: Array[Transform3D] = []
	var far_t: Array[Transform3D] = []
	var x: float = GRID_MIN.x
	while x < GRID_MIN.x + GRID_CELLS * CELL:
		var z: float = GRID_MIN.y
		while z < GRID_MIN.y + GRID_CELLS * CELL:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			var dens: float = forest_density(px, pz)
			if dens > 0.02 and rng.randf() < dens:
				var hgt: float = rng.randf_range(10.0, 19.0) * (0.75 + 0.35 * dens)
				var s: Vector3 = Vector3(hgt * rng.randf_range(0.36, 0.46), hgt, hgt * rng.randf_range(0.36, 0.46))
				var xf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(s), Vector3(px, height(px, pz) - 0.4, pz))
				if radius(px, pz) < 170.0:
					near_t.append(xf)
				else:
					far_t.append(xf)
			z += step
		x += step
	return {"mesh": near_t, "cards": far_t}


## The point on the cable between A and B at `t` (0..1): a shallow catenary sagging `sag` metres at mid-span.
static func cable_point(a: Vector3, b: Vector3, t: float, sag: float) -> Vector3:
	var p: Vector3 = a.lerp(b, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p
