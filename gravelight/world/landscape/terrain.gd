class_name LandscapeTerrain
extends RefCounted
## The land beyond Map 0's play space (Update 02 section 7, DECISIONS T-052): one height function and the mesh
## builders for its three depth layers. Everything here is pure maths and deterministic, so the Landscape node can
## rebuild the same world at load time (nothing is baked into map00.tscn) and the unit tests can probe it.
##
##   near  r < NEAR_R   : the snow slab's surroundings, a low swell that crests about 110 m out (built-in fog,
##                        the slab's own "snow" material, so the seam at the slab edge is invisible)
##   mid   NEAR_R..300  : a valley behind that crest, then rolling hills with the pine forest (custom fog)
##   far   290..345     : two ridge bands of mountain silhouettes, tallest to the south-west (custom fog)
##
## Frame as in gen_map00.gd: +X east, +Z south. Distances are measured from CENTER (the middle of the inn plot).
## The camera's far plane is 400 m, so nothing here is further than ~345 m from CENTER.

const DEFAULT_CENTER: Vector2 = Vector2(12.0, 20.0)
## Where bearings and radii are measured from. Map 0's plot by default; Kaltenbrunn's landscape (U10 section 5, T-161)
## moves it to its own yard with use_profile() and the next Landscape.build() on Map 0 puts it back (reset_profile()).
static var CENTER: Vector2 = DEFAULT_CENTER
## Optional replacements for height(x, z) and ridge_crest(band, bearing): Callables, invalid = Map 0's own.
static var height_fn: Callable = Callable()
static var crest_fn: Callable = Callable()
## The collision slab (gen_map00 build_geometry "Ground*"): the terrain starts at its edges at height 0.
const SLAB_MIN: Vector2 = Vector2(-45.0, -40.0)
const SLAB_MAX: Vector2 = Vector2(70.0, 75.0)
const CELL: float = 5.0
## Lattice origin, aligned so the slab edges fall on grid lines.
const GRID_MIN: Vector2 = Vector2(-290.0, -280.0)
const GRID_CELLS: int = 120
const NEAR_R: float = 140.0     # quads nearer than this are "near" (built-in fog), the rest "mid"
const GRID_R: float = 300.0     # quads past this are dropped (the ridge bands take over)
const RIDGE_A: Vector3 = Vector3(288.0, 312.0, 322.0)   # inner, crest, outer radius
const RIDGE_B: Vector3 = Vector3(316.0, 336.0, 346.0)

## Road centre lines beyond the slab (2D, x/z). The crossroads (E-W and N-S) and the carters' road south-east.
const ROADS: Array = [
	[Vector2(-300, -4.0), Vector2(-170, -10.0), Vector2(-45, -7.75)],
	[Vector2(70, -7.75), Vector2(160, -12.0), Vector2(300, -26.0)],
	[Vector2(-10.75, -40), Vector2(-12.0, -120.0), Vector2(-26.0, -210.0), Vector2(-20.0, -300.0)],
	[Vector2(-10.75, 75), Vector2(-6.0, 170.0), Vector2(-24.0, 320.0)],
	[Vector2(50.0, 70.0), Vector2(120.0, 98.0), Vector2(210.0, 150.0), Vector2(300.0, 190.0)],
]
## The frozen stream, west to east, under the stone bridge on the north road.
const STREAM: Array = [Vector2(-300, -84), Vector2(-160, -62), Vector2(-60, -66), Vector2(-11.5, -64.0), Vector2(60, -56),
	Vector2(150, -76), Vector2(300, -70)]
const BRIDGE: Vector2 = Vector2(-11.2, -64.0)

static var _n_hill: FastNoiseLite
static var _n_near: FastNoiseLite
static var _n_ridge: FastNoiseLite
static var _n_forest: FastNoiseLite


static func use_profile(center: Vector2, h: Callable, crest: Callable) -> void:
	CENTER = center
	height_fn = h
	crest_fn = crest


static func reset_profile() -> void:
	CENTER = DEFAULT_CENTER
	height_fn = Callable()
	crest_fn = Callable()


static func _noises() -> void:
	if _n_hill != null:
		return
	_n_hill = FastNoiseLite.new()
	_n_hill.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_hill.seed = 1944
	_n_hill.frequency = 0.0085
	_n_hill.fractal_octaves = 4
	_n_near = FastNoiseLite.new()
	_n_near.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_near.seed = 2312
	_n_near.frequency = 0.02
	_n_near.fractal_octaves = 3
	_n_ridge = FastNoiseLite.new()
	_n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_ridge.seed = 41
	_n_ridge.frequency = 1.0
	_n_ridge.fractal_octaves = 5
	_n_forest = FastNoiseLite.new()
	_n_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_forest.seed = 777
	_n_forest.frequency = 0.012
	_n_forest.fractal_octaves = 2


static func _u(n: FastNoiseLite, x: float, z: float) -> float:
	return n.get_noise_2d(x, z) * 0.5 + 0.5


## Distance from (x, z) to the slab rectangle (0 inside it).
static func slab_distance(x: float, z: float) -> float:
	var dx: float = maxf(maxf(SLAB_MIN.x - x, 0.0), x - SLAB_MAX.x)
	var dz: float = maxf(maxf(SLAB_MIN.y - z, 0.0), z - SLAB_MAX.y)
	return sqrt(dx * dx + dz * dz)


static func radius(x: float, z: float) -> float:
	return Vector2(x, z).distance_to(CENTER)


## Compass bearing from CENTER in degrees (0 = north / -Z, 90 = east / +X).
static func bearing(x: float, z: float) -> float:
	return fposmod(rad_to_deg(atan2(x - CENTER.x, -(z - CENTER.y))), 360.0)


## A unit direction (y = 0) toward a compass bearing.
static func dir_of(bearing_deg: float) -> Vector3:
	var a: float = deg_to_rad(bearing_deg)
	return Vector3(sin(a), 0.0, -cos(a))


## The point on the ground plane at bearing/radius from CENTER.
static func at_bearing(bearing_deg: float, r: float) -> Vector3:
	return Vector3(CENTER.x, 0.0, CENTER.y) + dir_of(bearing_deg) * r


static func _seg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func polyline_distance(p: Vector2, pts: Array) -> float:
	var best: float = 1e9
	for i: int in pts.size() - 1:
		best = minf(best, _seg_distance(p, pts[i], pts[i + 1]))
	return best


static func road_distance(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var best: float = 1e9
	for r: Array in ROADS:
		best = minf(best, polyline_distance(p, r))
	return best


static func stream_distance(x: float, z: float) -> float:
	return polyline_distance(Vector2(x, z), STREAM)


## How much bigger the mid hills are on a bearing: low and open to the east (the battle's horizon), rolling
## elsewhere.
static func hill_gain(bearing_deg: float) -> float:
	var east: float = cos(deg_to_rad(bearing_deg - 85.0))
	return 1.0 - 0.55 * smoothstep(0.2, 0.95, east)


## Terrain height at (x, z). 0 at the slab edge (the slab top is y = 0).
static func height(x: float, z: float) -> float:
	if height_fn.is_valid():
		return float(height_fn.call(x, z))
	_noises()
	var d: float = slab_distance(x, z)
	if d <= 0.0:
		return -0.05
	var r: float = radius(x, z)
	var b: float = bearing(x, z)
	# the near swell: rises off the slab edge, crests ~105-120 m out, then a valley
	var swell: float = smoothstep(0.0, 55.0, d) * smoothstep(60.0, 112.0, r) * (1.0 - smoothstep(124.0, 150.0, r))
	var near_h: float = swell * (2.6 + 3.8 * _u(_n_near, x, z)) + smoothstep(0.0, 30.0, d) * 1.4 * (_u(_n_near, x * 2.3, z * 2.3) - 0.35)
	# the valley floor and the mid hills beyond it
	var hills: float = smoothstep(138.0, 215.0, r) * (6.0 + 20.0 * pow(_u(_n_hill, x, z), 1.3)) * hill_gain(b)
	var valley: float = smoothstep(120.0, 150.0, r) * 1.2
	var h: float = near_h + hills + valley
	# roads run in shallow cuts, the stream in a frozen channel
	var rd: float = road_distance(x, z)
	h = lerpf(h * 0.3, h, smoothstep(3.5, 20.0, rd))
	var sd: float = stream_distance(x, z)
	h -= (1.0 - smoothstep(2.5, 8.0, sd)) * 1.4 * smoothstep(4.0, 18.0, d)
	return h


## Height of the ridge bands' crest on a bearing: band 0 = the nearer ridge (wooded), band 1 = the mountains.
static func ridge_crest(band: int, bearing_deg: float) -> float:
	if crest_fn.is_valid():
		return float(crest_fn.call(band, bearing_deg))
	_noises()
	var a: float = deg_to_rad(bearing_deg)
	var c: Vector2 = Vector2(cos(a), sin(a))
	if band == 0:
		var n: float = _n_ridge.get_noise_2d(c.x * 1.6, c.y * 1.6) * 0.5 + 0.5
		return (16.0 + 22.0 * n) * (1.0 - 0.45 * smoothstep(0.3, 0.95, cos(deg_to_rad(bearing_deg - 80.0))))
	# the mountains: tallest to the south-west (the Sudeten side), jagged, low in the east
	var sw: float = 0.5 + 0.5 * cos(deg_to_rad(bearing_deg - 215.0))
	var jag: float = _n_ridge.get_noise_2d(c.x * 5.0 + 11.0, c.y * 5.0) * 0.5 + 0.5
	var broad: float = _n_ridge.get_noise_2d(c.x * 1.3 + 5.0, c.y * 1.3) * 0.5 + 0.5
	return 18.0 + 52.0 * pow(sw, 1.6) * (0.55 + 0.45 * broad) + 14.0 * pow(jag, 2.0) * (0.4 + sw)


## Forest density 0..1 at (x, z): clumps on the mid hills, a few strays nearer, never on roads, the stream, the
## farmhouse yard or the play space's surroundings.
static func forest_density(x: float, z: float) -> float:
	_noises()
	var r: float = radius(x, z)
	var d: float = slab_distance(x, z)
	if d < 28.0 or r > GRID_R - 4.0:
		return 0.0
	var clump: float = smoothstep(0.42, 0.68, _u(_n_forest, x, z))
	var ring: float = smoothstep(150.0, 190.0, r) * 0.9 + smoothstep(60.0, 100.0, r) * (1.0 - smoothstep(110.0, 135.0, r)) * 0.18
	var dens: float = clump * ring * hill_gain(bearing(x, z))
	dens *= smoothstep(9.0, 20.0, road_distance(x, z))
	dens *= smoothstep(6.0, 14.0, stream_distance(x, z))
	return clampf(dens, 0.0, 1.0)


## Vertex colour masks: r = road (trodden), g = ice (the stream), b = forest floor (darker, needle litter).
static func masks(x: float, z: float) -> Color:
	var rd: float = road_distance(x, z)
	var sd: float = stream_distance(x, z)
	var road: float = 1.0 - smoothstep(1.5, 2.9, rd)
	var ice: float = 1.0 - smoothstep(2.6, 4.2, sd)
	return Color(road, ice, forest_density(x, z), 1.0)


static func _grid_point(i: int, j: int) -> Vector3:
	var x: float = GRID_MIN.x + float(i) * CELL
	var z: float = GRID_MIN.y + float(j) * CELL
	return Vector3(x, height(x, z), z)


## The near and mid terrain as one ArrayMesh with two surfaces (0 = near, 1 = mid). Quads inside the slab and
## past GRID_R are dropped; smooth normals from central differences.
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
				if mid.x > SLAB_MIN.x and mid.x < SLAB_MAX.x and mid.z > SLAB_MIN.y and mid.z < SLAB_MAX.y:
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


## One ridge band as a ring strip (rows from the inner radius over the crest to the outer edge). Inner edge
## heights come from height() so band 0 meets the mid hills; band 1 starts low behind band 0.
static func build_ridge(band: int, segments: int = 360) -> ArrayMesh:
	var rr: Vector3 = RIDGE_A if band == 0 else RIDGE_B
	# profile across the band: [radius, fraction of crest height]
	var prof: Array = [[rr.x, -1.0], [lerpf(rr.x, rr.y, 0.45), 0.55], [lerpf(rr.x, rr.y, 0.8), 0.92], [rr.y, 1.0],
		[lerpf(rr.y, rr.z, 0.5), 0.8], [rr.z, 0.45]]
	if band == 1:
		prof[0] = [rr.x, 0.3]
	var rows: int = prof.size()
	var pos: PackedVector3Array = PackedVector3Array()
	var col: PackedColorArray = PackedColorArray()
	for s: int in segments + 1:
		var b: float = 360.0 * float(s) / float(segments)
		var crest: float = ridge_crest(band, b)
		var d: Vector3 = dir_of(b)
		for k: int in rows:
			var rad: float = float(prof[k][0])
			var f: float = float(prof[k][1])
			var p: Vector3 = Vector3(CENTER.x, 0.0, CENTER.y) + d * rad
			var y: float = height(p.x, p.z) if f < 0.0 else crest * f
			if band == 0 and k > 0:
				y = maxf(y, height(p.x, p.z))
			# snowfields high up, rock and forest lower (r channel = snow cover, b = wooded)
			var snow: float = smoothstep(0.55, 0.95, f) if band == 1 else 0.25 + 0.5 * f
			col.append(Color(snow, 0.0, 1.0 if band == 0 else 0.0, 1.0))
			pos.append(Vector3(p.x, y, p.z))
	var idx: PackedInt32Array = PackedInt32Array()
	for s: int in segments:
		for k: int in rows - 1:
			var a: int = s * rows + k
			var bb: int = (s + 1) * rows + k
			idx.append_array([a, a + 1, bb + 1, a, bb + 1, bb])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var tmp: ArrayMesh = ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(tmp, 0)
	st.generate_normals()
	return st.commit()


## Tree placements: [Transform3D] for mesh pines (near enough to read as trees) and impostor cards (further), from
## a jittered lattice over the forest density. `step` = lattice spacing in metres.
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
				var hgt: float = rng.randf_range(9.0, 17.0) * (0.75 + 0.35 * dens)
				var s: Vector3 = Vector3(hgt * rng.randf_range(0.36, 0.46), hgt, hgt * rng.randf_range(0.36, 0.46))
				var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(s)
				var xf: Transform3D = Transform3D(basis, Vector3(px, height(px, pz) - 0.4, pz))
				if radius(px, pz) < 225.0:
					near_t.append(xf)
				else:
					far_t.append(xf)
			z += step
		x += step
	return {"mesh": near_t, "cards": far_t}


## Impostor cards along the wooded ridge (band 0): trees on its flanks up to just under the crest.
static func ridge_tree_transforms(count: int, seed_v: int) -> Array[Transform3D]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array[Transform3D] = []
	var tries: int = 0
	while out.size() < count and tries < count * 4:
		tries += 1
		var b: float = rng.randf() * 360.0
		if _u(_n_forest, b * 7.0, 3.0) < 0.38:
			continue
		var t: float = rng.randf_range(0.1, 0.92)
		var rad: float = lerpf(RIDGE_A.x + 6.0, RIDGE_A.y, t)
		var y: float = ridge_crest(0, b) * lerpf(0.2, 0.97, t)
		var p: Vector3 = at_bearing(b, rad)
		y = maxf(y, height(p.x, p.z))
		var hgt: float = rng.randf_range(11.0, 18.0)
		out.append(Transform3D(Basis.from_scale(Vector3(hgt * 0.42, hgt, 1.0)), Vector3(p.x, y - 0.6, p.z)))
	return out
