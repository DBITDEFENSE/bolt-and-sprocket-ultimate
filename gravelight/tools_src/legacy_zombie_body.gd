## LEGACY COPY (pre-MZ ZombieBody, kept only for the before/after acceptance capture, tools_src/shots_zombie_anim). Not used by the game.
extends RefCounted
## Procedural zombie bodies: shared materials (noise-textured skin with glowing Nachtglas cracks, dirty cloth,
## stripes, leather, steel) and one merged ArrayMesh per (variant, bone), cached and shared by the whole pool.
## Bones hang along -Y (limbs) or stack along +Y (spine), so poses are plain local rotations.
## Variants: soldier, miner, labstaff, laborer, bellringer, nurse.

const VARIANTS: PackedStringArray = ["soldier", "miner", "labstaff", "laborer", "bellringer", "nurse"]
const MESH_BONES: PackedStringArray = ["hips", "thigh_l", "thigh_r", "shin_l", "shin_r", "abdomen", "chest", "neck",
	"head", "jaw", "sh_l", "sh_r", "el_l", "el_r"]

## Bone layout: [name, parent, rest position (parent-local)].
const SKELETON: Array = [
	["hips", "", Vector3(0, 0.95, 0)],
	["thigh_l", "hips", Vector3(-0.1, -0.04, 0)],
	["thigh_r", "hips", Vector3(0.1, -0.04, 0)],
	["shin_l", "thigh_l", Vector3(0, -0.44, 0)],
	["shin_r", "thigh_r", Vector3(0, -0.44, 0)],
	["abdomen", "hips", Vector3(0, 0.05, 0)],
	["chest", "abdomen", Vector3(0, 0.21, 0)],
	["neck", "chest", Vector3(0, 0.3, 0)],
	["head", "neck", Vector3(0, 0.08, 0)],
	["jaw", "head", Vector3(0, 0.06, -0.025)],
	["sh_l", "chest", Vector3(-0.2, 0.25, 0)],
	["sh_r", "chest", Vector3(0.2, 0.25, 0)],
	["el_l", "sh_l", Vector3(0, -0.3, 0)],
	["el_r", "sh_r", Vector3(0, -0.3, 0)],
	["hand_l", "el_l", Vector3(0, -0.29, 0)],
	["hand_r", "el_r", Vector3(0, -0.29, 0)],
]

## Hitboxes: [bone, limb, size, center] — limb names are the gameplay contract (head/neck/torso/arms/legs).
const HITBOXES: Array = [
	["head", &"head", Vector3(0.24, 0.27, 0.25), Vector3(0, 0.11, -0.01)],
	["neck", &"neck", Vector3(0.12, 0.11, 0.12), Vector3(0, 0.05, 0)],
	["chest", &"torso", Vector3(0.44, 0.34, 0.26), Vector3(0, 0.15, 0)],
	["abdomen", &"torso", Vector3(0.36, 0.26, 0.24), Vector3(0, 0.1, 0)],
	["sh_l", &"arms", Vector3(0.13, 0.32, 0.13), Vector3(0, -0.15, 0)],
	["sh_r", &"arms", Vector3(0.13, 0.32, 0.13), Vector3(0, -0.15, 0)],
	["el_l", &"arms", Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, -0.01)],
	["el_r", &"arms", Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, -0.01)],
	["thigh_l", &"legs", Vector3(0.17, 0.46, 0.17), Vector3(0, -0.22, 0)],
	["thigh_r", &"legs", Vector3(0.17, 0.46, 0.17), Vector3(0, -0.22, 0)],
	["shin_l", &"legs", Vector3(0.14, 0.48, 0.17), Vector3(0, -0.23, -0.02)],
	["shin_r", &"legs", Vector3(0.14, 0.48, 0.17), Vector3(0, -0.23, -0.02)],
]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _crack_round: int = -999
static var _blood: StandardMaterial3D


# ================================================================== materials

static func _noise_tex(seed_v: int, freq: float, lo: Color, hi: Color, cellular: bool = false) -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	else:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g: Gradient = Gradient.new()
	g.set_color(0, lo)
	g.set_color(1, hi)
	t.color_ramp = g
	return t


## Hairline cracks: ridged noise, only the sharpest ridges glow (amber core, violet edge).
static func _crack_tex() -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 911
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 3
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.88, 0.95, 1.0])
	g.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color(0.45, 0.12, 0.8), Color(0.75, 0.3, 1.0), Color(1.0, 0.65, 0.3)])
	t.color_ramp = g
	return t


static func _stripe_tex(a: Color, b: Color) -> ImageTexture:
	var img: Image = Image.create(16, 4, false, Image.FORMAT_RGB8)
	for x: int in 16:
		for y: int in 4:
			var c: Color = a if (x / 4) % 2 == 0 else b
			img.set_pixel(x, y, c.darkened(randf_range(0.0, 0.12)))
	return ImageTexture.create_from_image(img)


static func _cloth(c: Color, seed_v: int, scale: float = 4.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(seed_v, 0.06, c.darkened(0.35), c.lightened(0.08))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.95
	return m


static func _skin(tint: Color, crack_color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(77, 0.07, tint.darkened(0.38), tint.lightened(0.1))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	m.roughness = 0.68
	m.emission_enabled = true
	m.emission = crack_color
	m.emission_texture = _crack_tex()
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # ADD would glow everywhere
	m.emission_energy_multiplier = 0.4
	return m


static func _plain(c: Color, rough: float = 0.8, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


## Material for a generic key resolved against a variant (cloth colors differ per variant).
static func material(variant: String, key: String) -> StandardMaterial3D:
	var cache_key: String = variant + ":" + key
	if _mats.has(cache_key):
		return _mats[cache_key]
	var m: StandardMaterial3D
	match key:
		"skin":
			if variant == "bellringer":
				m = material("_", "skin_bell")
			elif variant == "nurse":
				m = material("_", "skin_nurse")
			else:
				m = material("_", "skin_base")
		"skin_base":
			m = _skin(Color(0.55, 0.6, 0.62), Color(0.75, 0.4, 1.0))
		"skin_bell":
			m = _skin(Color(0.66, 0.64, 0.6), Color(1.0, 0.6, 0.3))
		"skin_nurse":
			m = _skin(Color(0.7, 0.68, 0.72), Color(0.75, 0.4, 1.0))
		"skin_glass":
			m = _skin(Color(0.42, 0.38, 0.52), Color(0.8, 0.4, 1.0))
			m.metallic = 0.25
			m.roughness = 0.35
		"dark":
			m = _plain(Color(0.05, 0.03, 0.04), 1.0)
		"eye":
			m = _plain(Color(0.7, 0.3, 1.0), 0.3, 0.0, 3.2)
		"teeth":
			m = _plain(Color(0.58, 0.54, 0.4), 0.5)
		"leather":
			m = _cloth(Color(0.2, 0.13, 0.08), 41, 5.0)
			m.roughness = 0.6
		"metal":
			m = _plain(Color(0.3, 0.3, 0.31), 0.45, 0.7)
		"helmet":
			m = _cloth(Color(0.27, 0.3, 0.25), 12, 3.0)
			m.metallic = 0.45
			m.roughness = 0.55
		"wood":
			m = _cloth(Color(0.42, 0.3, 0.18), 63, 6.0)
		"lens":
			m = _plain(Color(0.9, 0.75, 0.4), 0.2, 0.0, 0.6)
		"white":
			m = _cloth(Color(0.86, 0.84, 0.8), 88, 3.0)
		"patch":
			m = _plain(Color(0.85, 0.83, 0.75), 0.9)
		"crystal":
			m = _plain(Color(0.42, 0.18, 0.78), 0.1, 0.4, 1.3)
		"glove":
			m = _plain(Color(0.1, 0.14, 0.1), 0.35)
		"hair":
			m = _cloth(Color(0.1, 0.08, 0.07), 5, 8.0)
		"hat":
			m = _cloth(Color(0.15, 0.13, 0.11), 21, 4.0)
		"stripe":
			m = StandardMaterial3D.new()
			m.albedo_texture = _stripe_tex(Color(0.36, 0.4, 0.48), Color(0.62, 0.62, 0.6))
			m.uv1_scale = Vector3(5, 1, 1)
			m.roughness = 0.95
		"cloth", "cloth2":
			var cols: Dictionary = {
				"soldier": [Color(0.34, 0.36, 0.29), Color(0.25, 0.26, 0.23)],
				"miner": [Color(0.33, 0.27, 0.2), Color(0.19, 0.17, 0.15)],
				"labstaff": [Color(0.56, 0.56, 0.52), Color(0.21, 0.21, 0.23)],
				"laborer": [Color(0.4, 0.42, 0.48), Color(0.35, 0.37, 0.42)],
				"bellringer": [Color(0.22, 0.19, 0.16), Color(0.17, 0.15, 0.13)],
				"nurse": [Color(0.37, 0.41, 0.52), Color(0.15, 0.17, 0.28)],
			}
			var pair: Array = cols.get(variant, cols["soldier"])
			m = _cloth(pair[0] if key == "cloth" else pair[1], hash(variant + key) % 1000)
		_:
			m = _plain(Color(1, 0, 1))
	_mats[cache_key] = m
	return m


static func blood_material() -> StandardMaterial3D:
	if _blood == null:
		_blood = StandardMaterial3D.new()
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.32, 0.02, 0.03, 1.0))
		g.set_color(1, Color(0.2, 0.0, 0.01, 0.0))
		g.add_point(0.55, Color(0.25, 0.01, 0.02, 0.9))
		var t: GradientTexture2D = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_blood.albedo_texture = t
		_blood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blood.roughness = 0.25
		_blood.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _blood


## Crack glow follows the round (crack_intensity = clamp(r/30, 0.1, 1.0)). Cheap: runs once per round change.
static func update_cracks(round_number: int, max_energy: float) -> void:
	if round_number == _crack_round:
		return
	_crack_round = round_number
	var k: float = clampf(float(round_number) / 30.0, 0.1, 1.0)
	for key: String in ["_:skin_base", "_:skin_bell", "_:skin_nurse", "_:skin_glass"]:
		if _mats.has(key):
			(_mats[key] as StandardMaterial3D).emission_energy_multiplier = k * max_energy * (1.6 if key == "_:skin_glass" else 1.0)


## Builds every variant's meshes and the shared materials up front (avoids a hitch on first spawn).
static func warm_up() -> void:
	for v: String in VARIANTS:
		for b: String in MESH_BONES:
			mesh_for(v, b)
	material("_", "skin_glass")
	material("_", "crystal")
	blood_material()


# ================================================================== geometry

static func _cyl(top: float, bottom: float, h: float, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, segs: int = 9, caps: bool = true) -> Array:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return [c, Transform3D(Basis.from_euler(rot).scaled(scl), pos), mat]


static func _sph(r: float, pos: Vector3, mat: String, scl: Vector3 = Vector3.ONE, hemi: bool = false, segs: int = 10) -> Array:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.is_hemisphere = hemi
	s.radial_segments = segs
	s.rings = 5
	return [s, Transform3D(Basis.IDENTITY.scaled(scl), pos), mat]


static func _box(size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> Array:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return [b, Transform3D(Basis.from_euler(rot), pos), mat]


## Shared merged mesh for one bone of one variant (one surface per material).
static func mesh_for(variant: String, bone: String) -> ArrayMesh:
	var key: String = variant + "/" + bone
	if _meshes.has(key):
		return _meshes[key]
	var mesh: ArrayMesh = build_mesh(variant, spec(variant, bone))
	_meshes[key] = mesh
	return mesh


## Builds an ArrayMesh from [primitive, transform, material key] parts, grouped by material.
static func build_mesh(variant: String, parts: Array) -> ArrayMesh:
	var groups: Dictionary = {}
	for p: Array in parts:
		var k: String = p[2]
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(p)
	var mesh: ArrayMesh = ArrayMesh.new()
	for k: String in groups.keys():
		var st: SurfaceTool = SurfaceTool.new()
		for p: Array in groups[k]:
			st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
		st.commit(mesh)
		var idx: int = mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, material(variant, k))
		mesh.surface_set_name(idx, k)
	return mesh


static func _thin(v: String) -> bool:
	return v == "laborer" or v == "bellringer"


static func spec(v: String, bone: String) -> Array:
	var thin: bool = _thin(v)
	var w: float = 0.85 if thin else 1.0
	var leg_mat: String = "stripe" if v == "laborer" else "cloth2"
	var sleeve: String = "stripe" if v == "laborer" else ("skin" if v == "bellringer" else "cloth")
	var p: Array = []
	match bone:
		"hips":
			p.append(_cyl(0.135 * w, 0.13 * w, 0.17, Vector3.ZERO, leg_mat, Vector3.ZERO, Vector3(1.25, 1, 0.82)))
			match v:
				"soldier":
					# greatcoat skirt flaring to the knees, torn at the hem
					p.append(_cyl(0.18, 0.27, 0.56, Vector3(0, -0.27, 0.01), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.82), 11, false))
					p.append(_box(Vector3(0.09, 0.17, 0.012), Vector3(0.2, -0.6, -0.12), "cloth", Vector3(0.1, 0.3, 0.25)))
					p.append(_box(Vector3(0.07, 0.13, 0.012), Vector3(-0.15, -0.6, 0.2), "cloth", Vector3(-0.15, 0, -0.2)))
				"labstaff":
					p.append(_cyl(0.17, 0.22, 0.62, Vector3(0, -0.3, 0.01), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.82), 11, false))
					p.append(_box(Vector3(0.06, 0.3, 0.012), Vector3(0.12, -0.42, -0.19), "dark", Vector3(0.12, 0, 0.05)))
				"miner":
					p.append(_box(Vector3(0.3, 0.56, 0.02), Vector3(0, -0.2, -0.13), "leather", Vector3(0.08, 0, 0)))
				"bellringer":
					p.append(_cyl(0.15, 0.2, 0.32, Vector3(0, -0.17, 0), "cloth", Vector3.ZERO, Vector3(1.1, 1, 0.85), 7, false))
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(-0.1, -0.36, -0.15), "cloth", Vector3(0, 0, 0.35)))
				"nurse":
					p.append(_cyl(0.165, 0.31, 0.8, Vector3(0, -0.39, 0), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.9), 12, false))
					p.append(_box(Vector3(0.28, 0.62, 0.015), Vector3(0, -0.3, -0.22), "white", Vector3(0.18, 0, 0)))
		"thigh_l", "thigh_r":
			p.append(_cyl(0.075 * w, 0.058 * w, 0.44, Vector3(0, -0.22, 0), leg_mat))
			if v == "bellringer":
				p.append(_box(Vector3(0.05, 0.12, 0.012), Vector3(0.05, -0.3, -0.06), "skin", Vector3(0, 0, 0.3)))
		"shin_l", "shin_r":
			match v:
				"soldier":
					p.append(_cyl(0.056, 0.045, 0.2, Vector3(0, -0.1, 0), "cloth2"))
					p.append(_cyl(0.063, 0.055, 0.27, Vector3(0, -0.29, 0), "leather"))
					p.append(_box(Vector3(0.095, 0.07, 0.22), Vector3(0, -0.43, -0.05), "leather"))
				"laborer":
					p.append(_cyl(0.048, 0.04, 0.36, Vector3(0, -0.18, 0), "stripe"))
					p.append(_cyl(0.036, 0.034, 0.06, Vector3(0, -0.38, 0), "skin"))
					p.append(_box(Vector3(0.11, 0.08, 0.25), Vector3(0, -0.43, -0.05), "wood"))
				"bellringer":
					p.append(_cyl(0.045, 0.036, 0.22, Vector3(0, -0.11, 0), "cloth2"))
					p.append(_cyl(0.035, 0.03, 0.2, Vector3(0, -0.31, 0), "skin"))
					p.append(_box(Vector3(0.08, 0.05, 0.2), Vector3(0, -0.43, -0.05), "skin"))
				_:
					p.append(_cyl(0.055, 0.043, 0.4, Vector3(0, -0.2, 0), leg_mat))
					p.append(_box(Vector3(0.09, 0.07, 0.21), Vector3(0, -0.43, -0.05), "leather"))
		"abdomen":
			var ab_mat: String = "stripe" if v == "laborer" else ("skin" if v == "bellringer" else "cloth")
			p.append(_cyl(0.145 * w, 0.135 * w, 0.24, Vector3(0, 0.11, 0), ab_mat, Vector3.ZERO, Vector3(1.2, 1, 0.82)))
			match v:
				"soldier":
					p.append(_cyl(0.152, 0.152, 0.05, Vector3(0, 0.02, 0), "leather", Vector3.ZERO, Vector3(1.24, 1, 0.86)))
					p.append(_box(Vector3(0.07, 0.07, 0.05), Vector3(-0.09, 0.02, -0.13), "leather"))
					p.append(_box(Vector3(0.07, 0.07, 0.05), Vector3(0.09, 0.02, -0.13), "leather"))
					p.append(_box(Vector3(0.04, 0.035, 0.02), Vector3(0, 0.02, -0.13), "metal"))
				"miner":
					p.append(_box(Vector3(0.3, 0.26, 0.02), Vector3(0, 0.13, -0.12), "leather"))
				"bellringer":
					for i: int in 3:
						p.append(_box(Vector3(0.2, 0.012, 0.02), Vector3(0, 0.08 + i * 0.05, -0.108), "dark"))
					p.append(_box(Vector3(0.24, 0.1, 0.012), Vector3(0.02, 0.02, -0.11), "cloth", Vector3(0, 0, 0.2)))
				"labstaff":
					p.append(_box(Vector3(0.05, 0.08, 0.015), Vector3(0.07, 0.15, -0.12), "dark", Vector3(0, 0, 0.4)))
				"nurse":
					p.append(_box(Vector3(0.24, 0.22, 0.015), Vector3(0, 0.12, -0.12), "white"))
		"chest":
			var ch_mat: String = "stripe" if v == "laborer" else ("skin" if v == "bellringer" else "cloth")
			var cw: float = 1.05 if thin else 1.3
			p.append(_cyl(0.17, 0.145, 0.3, Vector3(0, 0.15, 0), ch_mat, Vector3.ZERO, Vector3(cw, 1, 0.78)))
			var sh_mat: String = sleeve
			p.append(_sph(0.075 * w, Vector3(-0.19 * w, 0.25, 0), sh_mat))
			p.append(_sph(0.075 * w, Vector3(0.19 * w, 0.25, 0), sh_mat))
			match v:
				"soldier":
					p.append(_cyl(0.085, 0.13, 0.08, Vector3(0, 0.31, 0), "cloth", Vector3.ZERO, Vector3(1.1, 1, 0.9)))
					p.append(_box(Vector3(0.035, 0.6, 0.014), Vector3(0.0, 0.13, -0.122), "leather", Vector3(0, 0, 0.72)))
					for i: int in 3:
						p.append(_sph(0.011, Vector3(-0.04, 0.06 + i * 0.08, -0.12), "metal"))
					p.append(_box(Vector3(0.1, 0.16, 0.012), Vector3(0.14, 0.05, -0.1), "dark", Vector3(0, 0, -0.3)))
				"labstaff":
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(-0.06, 0.18, -0.118), "cloth", Vector3(0, 0, 0.18)))
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(0.06, 0.18, -0.118), "cloth", Vector3(0, 0, -0.18)))
					p.append(_box(Vector3(0.05, 0.035, 0.01), Vector3(-0.1, 0.2, -0.125), "patch"))
				"miner":
					p.append(_box(Vector3(0.03, 0.32, 0.014), Vector3(-0.08, 0.14, -0.116), "leather"))
					p.append(_box(Vector3(0.03, 0.32, 0.014), Vector3(0.08, 0.14, -0.116), "leather"))
				"laborer":
					p.append(_box(Vector3(0.075, 0.05, 0.01), Vector3(0.07, 0.2, -0.122), "patch"))
					p.append(_box(Vector3(0.055, 0.008, 0.004), Vector3(0.07, 0.205, -0.128), "dark"))
					p.append(_box(Vector3(0.04, 0.008, 0.004), Vector3(0.065, 0.19, -0.128), "dark"))
				"bellringer":
					for i: int in 4:
						p.append(_box(Vector3(0.24, 0.014, 0.02), Vector3(0, 0.06 + i * 0.05, -0.112), "dark"))
					p.append(_cyl(0.07, 0.1, 0.07, Vector3(0, 0.31, 0), "cloth"))
				"nurse":
					p.append(_box(Vector3(0.2, 0.2, 0.014), Vector3(0, 0.13, -0.117), "white"))
					p.append(_box(Vector3(0.46, 0.55, 0.02), Vector3(0, 0.05, 0.13), "cloth2", Vector3(-0.08, 0, 0)))
					p.append(_cyl(0.085, 0.11, 0.06, Vector3(0, 0.31, 0), "white"))
		"neck":
			p.append(_cyl(0.048, 0.055, 0.11, Vector3(0, 0.05, 0), "skin"))
			p.append(_box(Vector3(0.03, 0.06, 0.012), Vector3(0.03, 0.05, -0.048), "dark", Vector3(0, 0, 0.3)))
		"head":
			p.append(_sph(0.115, Vector3(0, 0.11, 0), "skin", Vector3(0.88, 1.08, 1.0)))
			p.append(_sph(0.034, Vector3(-0.042, 0.125, -0.086), "dark", Vector3(1.25, 0.85, 0.6)))
			p.append(_sph(0.034, Vector3(0.042, 0.125, -0.086), "dark", Vector3(1.25, 0.85, 0.6)))
			p.append(_sph(0.0135, Vector3(-0.042, 0.124, -0.102), "eye"))
			p.append(_sph(0.0135, Vector3(0.042, 0.124, -0.102), "eye"))
			p.append(_box(Vector3(0.17, 0.026, 0.045), Vector3(0, 0.158, -0.088), "skin"))
			p.append(_box(Vector3(0.026, 0.05, 0.03), Vector3(0, 0.1, -0.112), "skin", Vector3(0.25, 0, 0)))
			p.append(_box(Vector3(0.07, 0.03, 0.01), Vector3(0, 0.058, -0.1), "dark"))
			p.append(_box(Vector3(0.06, 0.012, 0.01), Vector3(0, 0.066, -0.102), "teeth"))
			p.append(_box(Vector3(0.02, 0.05, 0.04), Vector3(-0.1, 0.11, 0), "skin"))
			p.append(_box(Vector3(0.02, 0.05, 0.04), Vector3(0.1, 0.11, 0), "skin"))
			p.append(_box(Vector3(0.04, 0.012, 0.004), Vector3(0.05, 0.19, -0.092), "dark", Vector3(0, 0, 0.6)))
			match v:
				"soldier":
					p.append(_sph(0.145, Vector3(0, 0.15, 0.008), "helmet", Vector3(1.0, 0.76, 1.06), true, 12))
					p.append(_cyl(0.142, 0.172, 0.055, Vector3(0, 0.13, 0.015), "helmet", Vector3(0.12, 0, 0), Vector3(1.0, 1.0, 1.04), 12, false))
					p.append(_box(Vector3(0.012, 0.11, 0.012), Vector3(-0.1, 0.06, -0.02), "leather"))
				"miner":
					p.append(_cyl(0.125, 0.13, 0.075, Vector3(0, 0.2, 0), "hat", Vector3.ZERO, Vector3(1, 1, 1.05), 10))
					p.append(_box(Vector3(0.14, 0.014, 0.09), Vector3(0, 0.17, -0.14), "hat", Vector3(-0.18, 0, 0)))
					p.append(_cyl(0.026, 0.026, 0.07, Vector3(0, 0.215, -0.14), "metal", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8))
					p.append(_cyl(0.021, 0.021, 0.012, Vector3(0, 0.215, -0.177), "lens", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8))
				"labstaff":
					p.append(_sph(0.118, Vector3(0, 0.13, 0.005), "hair", Vector3(0.9, 0.95, 1.0), true))
					p.append(_cyl(0.118, 0.118, 0.022, Vector3(0, 0.17, 0), "leather", Vector3(0.1, 0, 0), Vector3(0.9, 1, 1.01), 12, false))
					p.append(_cyl(0.03, 0.03, 0.035, Vector3(-0.042, 0.175, -0.105), "metal", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8))
					p.append(_cyl(0.03, 0.03, 0.035, Vector3(0.042, 0.175, -0.105), "metal", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8))
					p.append(_cyl(0.024, 0.024, 0.01, Vector3(-0.042, 0.181, -0.122), "lens", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8))
					p.append(_cyl(0.024, 0.024, 0.01, Vector3(0.042, 0.181, -0.122), "lens", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8))
				"bellringer":
					p.append(_box(Vector3(0.012, 0.06, 0.012), Vector3(-0.04, 0.22, 0.02), "hair", Vector3(0, 0, 0.5)))
					p.append(_box(Vector3(0.012, 0.05, 0.012), Vector3(0.05, 0.21, 0.04), "hair", Vector3(0, 0, -0.6)))
				"nurse":
					p.append(_box(Vector3(0.2, 0.07, 0.24), Vector3(0, 0.2, 0.01), "white"))
					p.append(_box(Vector3(0.28, 0.03, 0.2), Vector3(-0.16, 0.22, 0.02), "white", Vector3(0, 0, 0.5)))
					p.append(_box(Vector3(0.28, 0.03, 0.2), Vector3(0.16, 0.22, 0.02), "white", Vector3(0, 0, -0.5)))
					p.append(_box(Vector3(0.22, 0.24, 0.03), Vector3(0, 0.06, 0.1), "white"))
		"jaw":
			p.append(_box(Vector3(0.085, 0.035, 0.085), Vector3(0, -0.012, -0.045), "skin"))
			p.append(_box(Vector3(0.055, 0.011, 0.008), Vector3(0, 0.008, -0.086), "teeth"))
		"sh_l", "sh_r":
			p.append(_cyl(0.055 * w, 0.046 * w, 0.31, Vector3(0, -0.15, 0), sleeve))
			if v == "soldier" or v == "labstaff":
				p.append(_box(Vector3(0.05, 0.1, 0.012), Vector3(0.0, -0.22, 0.05), "cloth", Vector3(0.3, 0, 0)))
		"el_l", "el_r":
			var hand: String = "glove" if v == "labstaff" else "skin"
			if v == "laborer" or v == "bellringer":
				p.append(_cyl(0.042 * w, 0.033 * w, 0.27, Vector3(0, -0.135, 0), "skin"))
			else:
				p.append(_cyl(0.05, 0.047, 0.13, Vector3(0, -0.065, 0), sleeve))
				p.append(_cyl(0.04, 0.033, 0.16, Vector3(0, -0.19, 0), hand if v == "labstaff" else "skin"))
			p.append(_box(Vector3(0.06, 0.085, 0.03), Vector3(0, -0.31, -0.005), hand))
			for f: float in [-0.021, 0.0, 0.021]:
				p.append(_box(Vector3(0.013, 0.075, 0.013), Vector3(f, -0.375, -0.025), hand, Vector3(0.55, 0, 0)))
			p.append(_box(Vector3(0.014, 0.05, 0.014), Vector3(0.036, -0.31, -0.02), hand, Vector3(0.3, 0, -0.5)))
	return p
