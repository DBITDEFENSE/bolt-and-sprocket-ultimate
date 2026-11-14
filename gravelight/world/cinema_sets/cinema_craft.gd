extends RefCounted
## Close-up geometry for the replacement cutscenes. All dimensions are metres;
## seeded surface detail never changes the story markers or actor paths.

static func surface(points: PackedVector3Array, columns: int, rows: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in rows:
		for x: int in columns:
			var a: int = z * (columns + 1) + x
			for i: int in [a, a + 1, a + columns + 1, a + 1, a + columns + 2, a + columns + 1]:
				st.set_uv(Vector2(float(i % (columns + 1)) / columns, float(i / (columns + 1)) / rows))
				st.add_vertex(points[i])
	st.generate_normals()
	st.index()
	st.generate_tangents()
	return st.commit()


static func shroud() -> ArrayMesh:
	var points: PackedVector3Array = []
	for z: int in 41:
		for x: int in 81:
			var px: float = -1.04 + 2.08 * float(x) / 80.0
			var pz: float = -0.56 + 1.12 * float(z) / 40.0
			var head: float = 0.18 * exp(-pow((px + 0.73) / 0.15, 2.0) - pow(pz / 0.13, 2.0))
			var torso: float = 0.22 * exp(-pow((px + 0.27) / 0.38, 4.0) - pow(pz / 0.26, 2.0))
			var legs: float = 0.105 * exp(-pow((px - 0.45) / 0.48, 4.0) - pow(pz / 0.21, 4.0))
			var drop: float = smoothstep(0.37, 0.56, absf(pz)) * 0.33
			var folds: float = (0.008 + drop * 0.07) * sin(px * 39.0 + sin(pz * 14.0) * 1.7)
			points.append(Vector3(px, 0.81 + maxf(head, maxf(torso, legs)) - drop + folds, pz))
	return surface(points, 80, 40)


static func earth(width: float, length_m: float, height: float, seed_value: int) -> ArrayMesh:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 7.0
	var points: PackedVector3Array = []
	for z: int in 41:
		for x: int in 25:
			var u: float = -1.0 + 2.0 * float(x) / 24.0
			var v: float = -1.0 + 2.0 * float(z) / 40.0
			var rim: float = maxf(0.0, 1.0 - u * u - v * v)
			var h: float = pow(rim, 0.7) * height
			h += noise.get_noise_2d(u * 3.0, v * 5.0) * 0.04 * rim
			points.append(Vector3(u * width * 0.5, h - 0.015, v * length_m * 0.5))
	return surface(points, 24, 40)


static func vessel_shell() -> ArrayMesh:
	# Outer wall, rolled lip, inner wall: the old capped cylinder hid the liquid.
	var profile: Array[Vector2] = [Vector2(0.05, 0.0), Vector2(0.061, 0.025), Vector2(0.061, 0.26),
		Vector2(0.063, 0.282), Vector2(0.056, 0.302), Vector2(0.05, 0.302), Vector2(0.052, 0.28), Vector2(0.052, 0.02)]
	var points: PackedVector3Array = []
	for p: Vector2 in profile:
		for k: int in 65:
			var a: float = TAU * float(k) / 64.0
			points.append(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	return surface(points, 64, profile.size() - 1)


static func vault() -> ArrayMesh:
	var points: PackedVector3Array = []
	for z: int in 17:
		for x: int in 49:
			var a: float = PI * float(x) / 48.0
			points.append(Vector3(cos(a) * 2.05, -0.3 + sin(a) * 2.05, -4.65 - float(z) * 5.2 / 16.0))
	return surface(points, 48, 16)


static func mesh(parent: Node3D, geometry: Mesh, material: Material, label: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = label
	mi.mesh = geometry
	mi.material_override = material
	parent.add_child(mi)
	return mi
