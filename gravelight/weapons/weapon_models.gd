class_name WeaponModels
extends RefCounted
## Procedural, original weapon models built from primitives with procedural materials.
##
## WeaponModels.build(id, upgraded, camo) -> Node3D
##   Frame: barrel along -Z, +Y up, origin = the firing hand's grip point (where the right hand holds).
##   Real-world scale in meters.
##   Named children for animation: "Muzzle", "LeftHand" (support-hand target), and when present
##   "Mag", "Bolt", "Slide", "Pump", "Cover", "Barrels", "Crank", "Rocket", "Valve".
##   Sights: "SightPoint" (rear notch / aperture / scope eyepiece) and "FrontSight" (front post tip / bead)
##   Marker3D nodes, placed by the sight helpers (rear_notch, rear_aperture, front_post, ...). ADS aims along
##   them (WeaponHolder); eye relief and ADS zoom are per-weapon data (weapons.json feel), not model metas.
##   Meta: "reload" (String kind for WeaponHolder animations), "length" (float).
## Upgraded weapons get the Nachtglas look; `camo` (ProfileSave.camo_for) tints the furniture.

## Finished-steel material kinds (worn-edge chamfers, Nachtglas when upgraded).
const METAL_KINDS: Array = ["blued", "park", "black", "fieldgray", "olive", "steel", "perforated", "park_slide", "park_frame"]

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

var root: Node3D
var upgraded: bool = false
var camo: StringName = &""
## Attachments and finish (WeaponKitModels.look_of): {kit, finish, sig, id}; {} for a plain gun.
var look: Dictionary = {}


static var _templates: Dictionary = {}     # "id|up|camo" -> built model; build() hands out duplicates


static func build(weapon_id: StringName, is_upgraded: bool = false, camo_id: StringName = &"", look_d: Dictionary = {}) -> Node3D:
	# T-089: a downloaded model when the intake mapped one (and the greybox escape hatch is off), else procedural
	var glb: bool = WeaponGLB.wants(weapon_id)
	var key: String = "%s|%s|%s|%s|%s" % ["glb" if glb else "gb", weapon_id, is_upgraded, camo_id, str(look_d.get("sig", ""))]
	if not _templates.has(key):
		_templates[key] = WeaponGLB.build(weapon_id, is_upgraded, camo_id, look_d) if glb else _build_new(weapon_id, is_upgraded, camo_id, look_d)
	var t: Node3D = _templates[key]
	var copy: Node3D = t.duplicate() as Node3D
	for k: StringName in t.get_meta_list():
		copy.set_meta(k, t.get_meta(k))
	return copy


## The procedural (greybox) model whatever models.json says: the GLB builder reads its metas and hands as the
## defaults, and tools A/B against it. Same contract as build().
static func build_greybox(weapon_id: StringName, is_upgraded: bool = false, camo_id: StringName = &"", look_d: Dictionary = {}) -> Node3D:
	var key: String = "gb|%s|%s|%s|%s" % [weapon_id, is_upgraded, camo_id, str(look_d.get("sig", ""))]
	if not _templates.has(key):
		_templates[key] = _build_new(weapon_id, is_upgraded, camo_id, look_d)
	var t: Node3D = _templates[key]
	var copy: Node3D = t.duplicate() as Node3D
	for k: StringName in t.get_meta_list():
		copy.set_meta(k, t.get_meta(k))
	return copy


static func _build_new(weapon_id: StringName, is_upgraded: bool, camo_id: StringName, look_d: Dictionary = {}) -> Node3D:
	var b: WeaponModels = WeaponModels.new()
	b.upgraded = is_upgraded
	b.camo = camo_id
	b.look = look_d
	b.root = Node3D.new()
	var base: String = String(weapon_id).trim_suffix("_up")
	if String(weapon_id).ends_with("_up"):
		b.upgraded = true
	b.root.name = "Model_" + base
	b.root.set_meta("reload", "mag")
	b.root.set_meta("length", 0.6)
	if b.has_method("_w_" + base):
		b.call("_w_" + base)
	else:
		b._w_generic()
	if not b.look.is_empty():
		M1911KitModels.dress(b)   # attachments and finish (UPDATE_04 section 6)
	if b.root.get_node_or_null("Muzzle") == null:
		b.marker("Muzzle", Vector3(0, 0.04, -float(b.root.get_meta("length"))))
	if not b.look.is_empty():
		WeaponKitModels.dress(b)   # every other gun's attachments (T-074)
	if b.root.has_meta("bore"):
		# dark bore at the muzzle so barrels read as barrels, not rods
		var mz: Vector3 = (b.root.get_node("Muzzle") as Node3D).position
		b.tube(float(b.root.get_meta("bore")), float(b.root.get_meta("bore")), 0.004, mz + Vector3(0, 0, 0.0015), "black")
	if b.root.get_node_or_null("LeftHand") == null:
		b.marker("LeftHand", Vector3(0, -0.02, -0.25))
	if not b.root.has_meta("grip_r"):
		b.rhand(Vector3(0, -0.04, 0.05), 20.0)
	if b.upgraded:
		b._nachtglas_glow()
	merge_static(b.root)
	if b.root.has_node("KitFlash"):
		(b.root.get_node("KitFlash") as Node3D).hide()
	return b.root


## Bakes the plain MeshInstance3D children of `n` (and, recursively, of its part groups) into one mesh
## with one surface per material, so a whole rifle draws in a handful of calls instead of ~50.
static func merge_static(n: Node3D) -> void:
	var verts: Dictionary = {}        # material -> PackedVector3Array (non-indexed triangles)
	var norms: Dictionary = {}
	var mats: Array[Material] = []
	var victims: Array[Node] = []
	for c: Node in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).get_child_count() == 0 and (c as MeshInstance3D).visible and not c.has_meta("glb"):
			# (meta "glb": a downloaded mesh, T-089; it keeps its UVs and textures, so it is never baked)
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh == null:
				continue
			var xf: Transform3D = mi.transform
			var nb: Basis = xf.basis.inverse().transposed()
			for si: int in mi.mesh.get_surface_count():
				var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(si)
				if mat == null:
					continue
				if not verts.has(mat):
					verts[mat] = PackedVector3Array()
					norms[mat] = PackedVector3Array()
					mats.append(mat)
				var arr: Array = mi.mesh.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var ov: PackedVector3Array = verts[mat]
				var on: PackedVector3Array = norms[mat]
				var count: int = idx.size() if idx.size() > 0 else v.size()
				for k: int in count:
					var j: int = idx[k] if idx.size() > 0 else k
					ov.append(xf * v[j])
					on.append((nb * nn[j]).normalized() if nn.size() > j else Vector3.UP)
				verts[mat] = ov
				norms[mat] = on
			victims.append(mi)
		elif c is Node3D and not (c is VisualInstance3D):
			merge_static(c as Node3D)
	if victims.size() < 2:
		return
	var mesh: ArrayMesh = ArrayMesh.new()
	for mat: Material in mats:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts[mat]
		arrays[Mesh.ARRAY_NORMAL] = norms[mat]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	for vv: Node in victims:
		n.remove_child(vv)
		vv.free()
	var out: MeshInstance3D = MeshInstance3D.new()
	out.name = "Merged"
	out.mesh = mesh
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(out)
	n.move_child(out, 0)


## Every id this builder knows (for tests and the crate).
static func known_ids() -> PackedStringArray:
	return PackedStringArray(["m1911", "walther_p38", "luger_p08", "webley", "kar98k", "m1_garand", "gewehr43", "m1_carbine", "mp40", "thompson", "stg44",
		"trench_gun", "bar", "ppsh41", "mg42", "m1919", "sawed_off", "type100", "ptrs41", "springfield", "panzerschreck",
		"flamethrower", "ashlight", "totenglocke", "elmsfeuer", "lodestone", "gramophone", "trench_knife", "etool", "frag"])


# ================================================================== materials

static func _gradient(stops: Array) -> Gradient:
	var g: Gradient = Gradient.new()
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for s: Array in stops:
		offs.append(float(s[0]))
		cols.append(s[1] as Color)
	g.offsets = offs
	g.colors = cols
	return g


static func _noise_tex(key: String, seed_v: int, freq: float, ramp: Gradient, as_normal: bool,
		fractal: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM,
		noise_type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> NoiseTexture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_type = fractal
	n.noise_type = noise_type
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	if as_normal:
		t.as_normal_map = true
		t.bump_strength = 4.0
	elif ramp != null:
		t.color_ramp = ramp
	_tex_cache[key] = t
	return t


## Base (untinted, non-upgraded) materials, cached.
static func base_mat(kind: String) -> StandardMaterial3D:
	if _mat_cache.has(kind):
		return _mat_cache[kind]
	if kind == "glove_vc" or kind == "buckle":
		# glove_vc: the glove leather with its colour from the mesh (hands: leather, strap and stitching in one
		# surface). buckle: blackened steel for the wrist-strap buckle.
		var v: StandardMaterial3D = base_mat("glove" if kind == "glove_vc" else "blued").duplicate() as StandardMaterial3D
		if kind == "glove_vc":
			v.albedo_color = Color.WHITE
			v.vertex_color_use_as_albedo = true
			v.vertex_color_is_srgb = true
		else:
			v.roughness = 0.55
		_mat_cache[kind] = v
		return v
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.uv1_triplanar = true
	match kind:
		"park_slide", "park_frame":
			# Parkerized steel with a mottled phosphate finish; slide and frame come from different batches, so
			# the slide is a shade greener-darker than the frame (the classic two-tone of a reworked service gun).
			var pc: Color = Color(0.165, 0.175, 0.152) if kind == "park_slide" else Color(0.2, 0.205, 0.19)
			m.albedo_color = pc
			m.albedo_texture = _noise_tex("phosphate_" + kind, 71 if kind == "park_slide" else 73, 0.09,
				_gradient([[0.0, Color(0.78, 0.8, 0.76)], [0.5, Color(0.97, 0.97, 0.95)], [1.0, Color(1.0, 1.0, 1.0)]]), false)
			m.metallic = 0.5
			m.roughness = 0.74
			m.roughness_texture = _noise_tex("metal_rough", 7, 0.05, _gradient([[0.0, Color(0.35, 0.35, 0.35)], [1.0, Color(0.85, 0.85, 0.85)]]), false)
			m.uv1_scale = Vector3(9, 9, 9)
			m.normal_enabled = true
			m.normal_texture = _noise_tex("metal_normal", 11, 0.12, null, true)
			m.normal_scale = 0.22
		"wood_check":
			# Checkered walnut grip panels: walnut grain (UV1) multiplied by a diamond-checkering pattern (UV2,
			# ~2 mm pitch) so every diamond has a lit peak and a dark groove.
			var wb: StandardMaterial3D = base_mat("wood")
			m.albedo_texture = wb.albedo_texture
			m.albedo_color = Color(0.7, 0.6, 0.55)
			m.uv1_scale = Vector3(14, 14, 3)
			m.roughness = 0.58
			m.detail_enabled = true
			m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			m.detail_albedo = _checker_tex()
			m.uv2_triplanar = true
			m.uv2_scale = Vector3(110, 110, 110)
			m.normal_enabled = true
			m.normal_texture = _noise_tex("wood_normal", 5, 0.06, null, true)
			m.normal_scale = 0.4
		"blued", "park", "black", "fieldgray", "olive", "steel":
			var col: Color = {"blued": Color(0.075, 0.08, 0.095), "park": Color(0.17, 0.18, 0.16), "black": Color(0.05, 0.05, 0.05),
				"fieldgray": Color(0.24, 0.26, 0.22), "olive": Color(0.22, 0.24, 0.14), "steel": Color(0.55, 0.56, 0.58)}[kind]
			m.albedo_color = col
			m.metallic = 0.85 if kind in ["blued", "steel"] else 0.45
			m.roughness = 0.42 if kind == "blued" else (0.3 if kind == "steel" else 0.7)
			m.roughness_texture = _noise_tex("metal_rough", 7, 0.05, _gradient([[0.0, Color(0.35, 0.35, 0.35)], [1.0, Color(0.85, 0.85, 0.85)]]), false)
			m.uv1_scale = Vector3(6, 6, 6)
			m.normal_enabled = true
			m.normal_texture = _noise_tex("metal_normal", 11, 0.12, null, true)
			m.normal_scale = 0.15
		"wood", "wood_light", "wood_red":
			var ramp: Gradient
			match kind:
				"wood":
					ramp = _gradient([[0.0, Color(0.16, 0.08, 0.04)], [0.45, Color(0.33, 0.18, 0.08)], [0.55, Color(0.27, 0.14, 0.06)], [1.0, Color(0.42, 0.24, 0.11)]])
				"wood_light":
					ramp = _gradient([[0.0, Color(0.3, 0.18, 0.08)], [0.5, Color(0.5, 0.32, 0.16)], [1.0, Color(0.6, 0.42, 0.22)]])
				_:
					ramp = _gradient([[0.0, Color(0.25, 0.08, 0.04)], [0.5, Color(0.45, 0.17, 0.08)], [1.0, Color(0.55, 0.25, 0.12)]])
			# Repeating light/dark bands over smooth noise read as growth rings once stretched along Z.
			var c0: Color = ramp.colors[0]
			var c1: Color = ramp.colors[ramp.colors.size() - 1]
			var stops: Array = []
			for k: int in 7:
				var o: float = float(k) / 7.0
				stops.append([o, c0.lerp(c1, 0.55)])
				stops.append([o + 0.06, c1])
				stops.append([o + 0.11, c0.lerp(c1, 0.75)])
			stops.append([1.0, c0.lerp(c1, 0.55)])
			m.albedo_texture = _noise_tex("grain_" + kind, 3 + kind.length(), 0.012, _gradient(stops), false)
			# Stretched along Z (the stock's length) for grain.
			m.uv1_scale = Vector3(9, 9, 0.6)
			m.roughness = 0.62
			m.normal_enabled = true
			m.normal_texture = _noise_tex("wood_normal", 5, 0.06, null, true)
			m.normal_scale = 0.25
		"bakelite":
			m.albedo_color = Color(0.2, 0.08, 0.05)
			m.roughness = 0.32
			m.albedo_texture = _noise_tex("bakelite", 21, 0.08, _gradient([[0.0, Color(0.7, 0.7, 0.7)], [1.0, Color(1, 1, 1)]]), false)
		"brass", "bronze":
			m.albedo_color = Color(0.78, 0.6, 0.25) if kind == "brass" else Color(0.55, 0.36, 0.17)
			m.metallic = 0.95
			m.roughness = 0.28
			m.roughness_texture = _noise_tex("metal_rough", 7, 0.05, _gradient([[0.0, Color(0.35, 0.35, 0.35)], [1.0, Color(0.85, 0.85, 0.85)]]), false)
			m.uv1_scale = Vector3(5, 5, 5)
		"rubber", "leather", "canvas":
			m.albedo_color = {"rubber": Color(0.06, 0.06, 0.06), "leather": Color(0.25, 0.15, 0.08), "canvas": Color(0.36, 0.34, 0.22)}[kind]
			m.roughness = 0.9
			m.albedo_texture = _noise_tex("fabric", 31, 0.4, _gradient([[0.0, Color(0.75, 0.75, 0.75)], [1.0, Color(1, 1, 1)]]), false)
			m.uv1_scale = Vector3(8, 8, 8)
		"glass":
			m.albedo_color = Color(0.7, 0.8, 0.9, 0.25)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.2
		"glow_violet", "glow_amber", "glow_red":
			var gc: Color = {"glow_violet": Color(0.65, 0.3, 1.0), "glow_amber": Color(1.0, 0.6, 0.2), "glow_red": Color(1.0, 0.25, 0.15)}[kind]
			m.albedo_color = gc
			m.emission_enabled = true
			m.emission = gc
			m.emission_energy_multiplier = 4.0
		"red_paint", "white", "cream", "navy", "gold_trim", "chalk", "skin", "sleeve", "glove":
			m.albedo_color = {"red_paint": Color(0.55, 0.06, 0.05), "white": Color(0.85, 0.84, 0.8), "cream": Color(0.82, 0.74, 0.58),
				"navy": Color(0.08, 0.1, 0.22), "gold_trim": Color(0.85, 0.66, 0.2), "chalk": Color(0.92, 0.94, 0.9),
				"skin": Color(0.62, 0.47, 0.38), "sleeve": Color(0.3, 0.31, 0.2), "glove": Color(0.19, 0.13, 0.085)}[kind]
			m.roughness = 0.75
			if kind == "gold_trim":
				m.metallic = 0.9
				m.roughness = 0.3
			if kind == "sleeve":
				m.albedo_texture = _noise_tex("wool", 41, 0.6, _gradient([[0.0, Color(0.7, 0.7, 0.7)], [1.0, Color(1, 1, 1)]]), false)
				m.uv1_scale = Vector3(14, 14, 14)
			if kind == "glove":
				# pebbled leather grain
				m.albedo_texture = _noise_tex("leather_grain", 47, 0.9, _gradient([[0.0, Color(0.72, 0.72, 0.72)], [1.0, Color(1, 1, 1)]]), false)
				m.uv1_scale = Vector3(40, 40, 40)
				m.roughness = 0.68
				m.normal_enabled = true
				m.normal_texture = _noise_tex("leather_normal", 49, 0.9, null, true)
				m.normal_scale = 0.35
			if kind == "chalk":
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.emission_enabled = true
				m.emission = Color(0.8, 0.85, 0.8)
				m.emission_energy_multiplier = 0.4
		"perforated":
			# Cooling jackets / heat shields: dark holes from cellular noise.
			m.albedo_texture = _noise_tex("holes", 51, 0.18, _gradient([[0.0, Color(0.01, 0.01, 0.01)], [0.22, Color(0.02, 0.02, 0.02)], [0.26, Color(0.1, 0.1, 0.11)], [1.0, Color(0.13, 0.13, 0.15)]]),
				false, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.TYPE_CELLULAR)
			m.uv1_scale = Vector3(14, 14, 14)
			m.metallic = 0.7
			m.roughness = 0.5
		"nachtglas", "nachtglas_wood":
			m.albedo_color = Color(0.08, 0.03, 0.13) if kind == "nachtglas" else Color(0.14, 0.05, 0.18)
			m.metallic = 0.4
			m.roughness = 0.12
			m.emission_enabled = true
			m.emission_texture = _noise_tex("veins", 61, 0.045, _gradient([[0.0, Color(0, 0, 0)], [0.78, Color(0, 0, 0)], [0.84, Color(0.55, 0.2, 1.0)],
				[0.88, Color(0.05, 0.0, 0.08)], [0.93, Color(0, 0, 0)], [0.96, Color(1.0, 0.55, 0.15)], [1.0, Color(0.1, 0.02, 0.0)]]), false, FastNoiseLite.FRACTAL_RIDGED)
			m.emission_energy_multiplier = 3.0
			m.uv1_scale = Vector3(4, 4, 4)
		_:
			m.albedo_color = Color(0.5, 0.5, 0.5)
	_mat_cache[kind] = m
	return m


## Diamond checkering (4 x 4 pyramids per tile, peaks bright, grooves dark), for multiply-detail use.
static func _checker_tex() -> ImageTexture:
	if _tex_cache.has("checker"):
		return _tex_cache["checker"]
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y: int in n:
		for x: int in n:
			var u: float = float(x) / n * 4.0
			var v: float = float(y) / n * 4.0
			var a: float = absf(fposmod(u + v, 1.0) - 0.5)
			var b: float = absf(fposmod(u - v, 1.0) - 0.5)
			var h: float = minf(0.5 - a, 0.5 - b) * 2.0          # 0 in the grooves, 1 on the diamond peaks
			var facet: float = 1.06 if fposmod(u, 1.0) < 0.5 else 0.94   # one facet of each pyramid catches more light
			var k: float = lerpf(0.36, 1.0, smoothstep(0.0, 0.45, h)) * facet
			img.set_pixel(x, y, Color(k, k, k))
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache["checker"] = t
	return t


const CAMO_TINT: Dictionary ={&"olive_drab": Color(0.45, 0.5, 0.3), &"winter": Color(1.6, 1.65, 1.7), &"bronze": Color(0.55, 0.36, 0.18),
	&"silver": Color(0.72, 0.74, 0.78), &"gold": Color(0.85, 0.66, 0.2), &"nachtglas": Color(0.2, 0.08, 0.3)}


## Worn-edge variant of a base material for chamfers: rubbed-bright steel on finished metal, polished
## high spots on wood and bakelite. Cached.
static func edge_mat(kind: String) -> Material:
	var key: String = kind + "_edge"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var src: StandardMaterial3D = base_mat(kind)
	var e: StandardMaterial3D = src.duplicate() as StandardMaterial3D
	if kind in METAL_KINDS:
		e.albedo_texture = null
		e.albedo_color = src.albedo_color.lerp(Color(0.52, 0.53, 0.55), 0.45 if kind != "steel" else 0.2)
		e.metallic = 0.92
		e.roughness = 0.26
		e.roughness_texture = null
	elif kind.begins_with("wood") or kind == "bakelite":
		e.albedo_color = Color(1.35, 1.25, 1.15) if kind != "bakelite" else Color(0.34, 0.15, 0.09)
		e.roughness = 0.4
	elif kind == "nachtglas" or kind == "nachtglas_wood":
		e = base_mat("glow_violet").duplicate() as StandardMaterial3D
		e.albedo_color = Color(0.5, 0.22, 0.85)
		e.emission_energy_multiplier = 1.5
	_mat_cache[key] = e
	return e


## Chamfer material for this model (upgraded edges glow violet: the Nachtglas veins break the surface).
func m_edge(kind: String) -> Material:
	var is_wood: bool = kind.begins_with("wood") or kind == "bakelite"
	var is_metal: bool = kind in METAL_KINDS
	if upgraded and (is_wood or is_metal):
		return edge_mat("nachtglas")
	if is_wood and camo != &"":
		return m(kind)
	if is_wood or is_metal:
		return edge_mat(kind)
	return m(kind)


## Resolves a material for this model: Nachtglas when upgraded, camo tint on wood, otherwise the base.
func m(kind: String) -> Material:
	var is_wood: bool = kind.begins_with("wood") or kind == "bakelite"
	var is_metal: bool = kind in METAL_KINDS
	if upgraded and (is_wood or is_metal):
		return base_mat("nachtglas_wood" if is_wood else "nachtglas")
	if is_metal and not look.is_empty() and str(look.get("finish", "")) != "":
		return M1911KitModels.finish_mat(kind, StringName(str(look["finish"])))
	if is_wood and camo != &"" and CAMO_TINT.has(camo):
		var key: String = "%s_camo_%s" % [kind, camo]
		if not _mat_cache.has(key):
			var c: StandardMaterial3D
			if camo == &"nachtglas":
				c = (base_mat("nachtglas_wood") as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				c = base_mat(kind).duplicate() as StandardMaterial3D
				c.albedo_color = CAMO_TINT[camo]
				if camo in [&"gold", &"silver", &"bronze"]:
					c.albedo_texture = null
					c.metallic = 0.9
					c.roughness = 0.25
			_mat_cache[key] = c
		return _mat_cache[key]
	return base_mat(kind)


# ================================================================== primitives

func group(n: String, pos: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	g.position = pos
	(parent if parent != null else root).add_child(g)
	return g


func marker(n: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	return group(n, pos, parent)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, kind: String, rot_deg: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m(kind)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else root).add_child(mi)
	return mi


func box(size: Vector3, pos: Vector3, kind: String, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, kind, rot_deg)


## Cylinder along Z (front = -Z) unless axis says otherwise. r_front at -Z end, r_back at +Z end.
func tube(r_front: float, r_back: float, length: float, pos: Vector3, kind: String, axis: String = "z", parent: Node3D = null, seg: int = 14) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.height = length
	cm.radial_segments = seg
	cm.rings = 1
	var rot: Vector3 = Vector3.ZERO
	match axis:
		"z":
			# CylinderMesh is along Y; top (+Y) -> +Z after +90 deg about X. Top radius is the back end.
			cm.top_radius = r_back
			cm.bottom_radius = r_front
			rot = Vector3(90, 0, 0)
		"x":
			cm.top_radius = r_back
			cm.bottom_radius = r_front
			rot = Vector3(0, 0, -90)
		_:
			cm.top_radius = r_back
			cm.bottom_radius = r_front
	return _mesh(parent, cm, pos, kind, rot)


func ball(r: float, pos: Vector3, kind: String, scale_v: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var mi: MeshInstance3D = _mesh(parent, sm, pos, kind, Vector3.ZERO)
	mi.scale = scale_v
	return mi


func ring(inner: float, outer: float, pos: Vector3, kind: String, axis: String = "z", parent: Node3D = null) -> MeshInstance3D:
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 16
	tm.ring_segments = 6
	var rot: Vector3 = Vector3(90, 0, 0) if axis == "z" else (Vector3(0, 0, 90) if axis == "x" else Vector3.ZERO)
	return _mesh(parent, tm, pos, kind, rot)


func wedge(size: Vector3, pos: Vector3, kind: String, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var pm: PrismMesh = PrismMesh.new()
	pm.size = size
	return _mesh(parent, pm, pos, kind, rot_deg)


## A flat shape extruded along X: `pts` are (z, y) outline points in model space (any winding).
## This is how stocks, grips, magazines and blades get real silhouettes.
func prof(pts: Array, thickness: float, kind: String, x: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Variant in pts:
		poly.append(p as Vector2)
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var h: float = thickness * 0.5
	# Chamfer: the side caps are an inset copy of the outline and a narrow slanted strip joins them to the
	# edge walls. The strip uses a worn-edge material (bright steel on blued parts, rubbed wood on stocks).
	var bb: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p2: Vector2 in poly:
		bb = bb.expand(p2)
	var bev: float = minf(0.0028, minf(thickness * 0.22, minf(bb.size.x, bb.size.y) * 0.18))
	var inner: PackedVector2Array = _inset(poly, bev) if bev > 0.0006 else poly
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(inner)
	if tris.is_empty():
		inner = poly
		bev = 0.0
		tris = Geometry2D.triangulate_polygon(poly)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# side caps (+X and -X)
	for i: int in range(0, tris.size(), 3):
		var a: Vector2 = inner[tris[i]]
		var b2: Vector2 = inner[tris[i + 1]]
		var c: Vector2 = inner[tris[i + 2]]
		# wound explicitly: triangulate_polygon's output orientation isn't guaranteed to follow the outline's
		_face_tri(st, Vector3(h, a.y, a.x), Vector3(h, b2.y, b2.x), Vector3(h, c.y, c.x), Vector3.RIGHT)
		_face_tri(st, Vector3(-h, a.y, a.x), Vector3(-h, b2.y, b2.x), Vector3(-h, c.y, c.x), Vector3.LEFT)
	# edge walls
	_strip(st, poly, h - bev, poly, -(h - bev))
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, m(kind))
	if bev > 0.0:
		var se: SurfaceTool = SurfaceTool.new()
		se.begin(Mesh.PRIMITIVE_TRIANGLES)
		se.set_smooth_group(-1)
		_strip(se, inner, h, poly, h - bev)
		_strip(se, poly, -(h - bev), inner, -h)
		se.generate_normals()
		se.commit(mesh)
		mesh.surface_set_material(1, m_edge(kind))
	var mi: MeshInstance3D = _mesh(parent, mesh, Vector3(x, 0, 0), kind, Vector3.ZERO)
	mi.material_override = null
	return mi


## A cross-section `pts` ((x, y) outline points, any winding, may be concave) extruded along Z from z0 (front)
## to z1 (back). Chamfers only on the ends that ask for one (bev_front / bev_back > 0), with the worn-edge
## material, so consecutive sections can butt together seamlessly (slides with a port cut, rounded tops).
func xsec(pts: Array, z0: float, z1: float, kind: String, parent: Node3D = null, bev_front: float = 0.0,
		bev_back: float = 0.0) -> MeshInstance3D:
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Variant in pts:
		poly.append(p as Vector2)
	var inner_f: PackedVector2Array = _inset(poly, bev_front) if bev_front > 0.0 else poly
	var inner_b: PackedVector2Array = _inset(poly, bev_back) if bev_back > 0.0 else poly
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for end: int in 2:
		var ring_pts: PackedVector2Array = inner_f if end == 0 else inner_b
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(ring_pts)
		var zc: float = z0 if end == 0 else z1
		var d: Vector3 = Vector3(0, 0, -1) if end == 0 else Vector3(0, 0, 1)
		for i: int in range(0, tris.size(), 3):
			_face_tri(st, _v2z(ring_pts[tris[i]], zc), _v2z(ring_pts[tris[i + 1]], zc), _v2z(ring_pts[tris[i + 2]], zc), d)
	_zwall(st, poly, z0 + bev_front, poly, z1 - bev_back, poly)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, m(kind))
	if bev_front > 0.0 or bev_back > 0.0:
		var se: SurfaceTool = SurfaceTool.new()
		se.begin(Mesh.PRIMITIVE_TRIANGLES)
		se.set_smooth_group(-1)
		if bev_front > 0.0:
			_zwall(se, inner_f, z0, poly, z0 + bev_front, poly)
		if bev_back > 0.0:
			_zwall(se, poly, z1 - bev_back, inner_b, z1, poly)
		se.generate_normals()
		se.commit(mesh)
		mesh.surface_set_material(1, m_edge(kind))
	var mi: MeshInstance3D = _mesh(parent, mesh, Vector3.ZERO, kind, Vector3.ZERO)
	mi.material_override = null
	return mi


static func _v2z(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## Adds a triangle wound so its front face looks along `d` (Godot: clockwise seen from the front).
static func _face_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	if (b - a).cross(c - a).dot(d) < 0.0:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
	else:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)


## Quads joining outline `a` at z = za to outline `b` at z = zb, facing outward from `ref` (the outline whose
## edge normals define "outward").
static func _zwall(st: SurfaceTool, a: PackedVector2Array, za: float, b: PackedVector2Array, zb: float, ref: PackedVector2Array) -> void:
	var n: int = ref.size()
	var area: float = 0.0
	for i: int in n:
		area += ref[i].x * ref[(i + 1) % n].y - ref[(i + 1) % n].x * ref[i].y
	var sgn: float = 1.0 if area > 0.0 else -1.0
	if absf(za - zb) < 0.00001:
		return
	for i: int in n:
		var j: int = (i + 1) % n
		var e: Vector2 = ref[j] - ref[i]
		var out: Vector2 = Vector2(e.y, -e.x) * sgn
		var a0: Vector3 = _v2z(a[i], za)
		var a1: Vector3 = _v2z(a[j], za)
		var b0: Vector3 = _v2z(b[i], zb)
		var b1: Vector3 = _v2z(b[j], zb)
		# a chamfer strip leans toward the end it closes, but its normal keeps a positive outward component
		var d: Vector3 = Vector3(out.x, out.y, 0.0)
		_face_tri(st, a0, b0, b1, d)
		_face_tri(st, a0, b1, a1, d)


## Quads joining outline `a` (at x = xa) to outline `b` (at x = xb); a and b have the same vertex count.
static func _strip(st: SurfaceTool, a: PackedVector2Array, xa: float, b: PackedVector2Array, xb: float) -> void:
	var n: int = a.size()
	var area: float = 0.0
	for i: int in n:
		area += a[i].x * a[(i + 1) % n].y - a[(i + 1) % n].x * a[i].y
	var sgn: float = 1.0 if area > 0.0 else -1.0
	for i: int in n:
		var j: int = (i + 1) % n
		var a0: Vector3 = Vector3(xa, a[i].y, a[i].x)
		var a1: Vector3 = Vector3(xa, a[j].y, a[j].x)
		var b0: Vector3 = Vector3(xb, b[i].y, b[i].x)
		var b1: Vector3 = Vector3(xb, b[j].y, b[j].x)
		# outward = the outline edge's outward normal in the (z, y) plane (chamfer strips keep a positive share)
		var e: Vector2 = a[j] - a[i]
		var d: Vector3 = Vector3(0.0, -e.x, e.y) * sgn
		_face_tri(st, a0, b1, a1, d)
		_face_tri(st, a0, b0, b1, d)


## Mitred inward offset of a counter-clockwise polygon (same vertex count, spikes clamped).
static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	var area: float = 0.0
	for i: int in n:
		area += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	var sgn: float = 1.0 if area > 0.0 else -1.0
	for i: int in n:
		var p: Vector2 = poly[i]
		var e0: Vector2 = (p - poly[(i - 1 + n) % n]).normalized()
		var e1: Vector2 = (poly[(i + 1) % n] - p).normalized()
		var n0: Vector2 = Vector2(-e0.y, e0.x) * sgn
		var n1: Vector2 = Vector2(-e1.y, e1.x) * sgn
		var mdir: Vector2 = n0 + n1
		if mdir.length_squared() < 0.0001:
			mdir = n0
		mdir = mdir.normalized()
		var k: float = d / maxf(0.35, mdir.dot(n0))
		out.append(p + mdir * minf(k, d * 2.5))
	return out


func meta(reload_kind: String, length: float) -> void:
	root.set_meta("reload", reload_kind)
	root.set_meta("length", length)


# ---- sights (T-047). Every sight helper drops a marker on the sight line: "SightPoint" at the rear notch /
# aperture (or scope eyepiece), "FrontSight" at the front post tip (or bead / objective). WeaponHolder aims by
# putting SightPoint on the camera's center ray at the weapon's data eye relief, pitched so FrontSight is on
# the same ray, so a model only has to build its sights with these helpers to aim correctly.

## Puts (or moves) a sight marker. `p` is in `parent` space (the model root when null), so a sight on a
## moving part (the pistol slide) rides with it.
func sight_mark(n: String, p: Vector3, parent: Node3D = null) -> Marker3D:
	var host: Node3D = parent if parent != null else root
	var mk: Marker3D = host.get_node_or_null(n) as Marker3D
	if mk == null:
		var old: Node = root.find_child(n, true, false)
		if old != null:
			old.get_parent().remove_child(old)
			old.free()
		mk = Marker3D.new()
		mk.name = n
		host.add_child(mk)
	mk.position = p
	return mk


## Open-notch rear sight: a base block from y_base with two ears leaving a notch; the sight line runs through
## the notch just below the ear tops. Places SightPoint there and returns it (in `parent` space).
func rear_notch(z: float, y_base: float, h: float, kind: String = "blued", width: float = 0.016, gap: float = 0.0042,
		parent: Node3D = null) -> Vector3:
	var ear: float = (width - gap) * 0.5
	var base_h: float = h * 0.55
	box(Vector3(width, base_h, 0.007), Vector3(0, y_base + base_h * 0.5, z), kind, Vector3.ZERO, parent)
	for s: float in [-1.0, 1.0]:
		box(Vector3(ear, h - base_h, 0.007), Vector3(s * (gap + ear) * 0.5, y_base + base_h + (h - base_h) * 0.5, z), kind, Vector3.ZERO, parent)
	var p: Vector3 = Vector3(0, y_base + h - 0.0012, z - 0.004)
	sight_mark("SightPoint", p, parent)
	return p


## Peep (aperture) rear sight: a ring on a short post with protective ears. SightPoint = ring center.
func rear_aperture(z: float, y_center: float, y_base: float, kind: String = "park", r_in: float = 0.0034,
		r_out: float = 0.0085, ears: bool = true) -> Vector3:
	ring(r_in, r_out, Vector3(0, y_center, z), kind)
	box(Vector3(0.008, maxf(0.002, y_center - r_out - y_base + 0.002), 0.006), Vector3(0, (y_center - r_out + y_base) * 0.5 + 0.001, z), kind)
	if ears:
		for s: float in [-1.0, 1.0]:
			box(Vector3(0.0045, y_center + 0.004 - y_base, 0.016), Vector3(s * (r_out + 0.0045), (y_center + 0.004 + y_base) * 0.5, z + 0.004), kind)
	var p: Vector3 = Vector3(0, y_center, z - 0.004)
	sight_mark("SightPoint", p)
	return p


## Shotgun-style rear "sight": the matted groove along the receiver top (two low rails). SightPoint sits
## in the groove at `y_top` (the receiver top) + `depth`.
func rear_groove(z: float, y_top: float, length: float = 0.05, kind: String = "blued", depth: float = 0.0025,
		gap: float = 0.005, parent: Node3D = null) -> Vector3:
	for s: float in [-1.0, 1.0]:
		box(Vector3(0.003, depth, length), Vector3(s * (gap + 0.003) * 0.5, y_top + depth * 0.5, z - length * 0.5), kind, Vector3.ZERO, parent)
	var p: Vector3 = Vector3(0, y_top + depth * 0.6, z)
	sight_mark("SightPoint", p, parent)
	return p


## Plain front blade from y_base up to `tip` (no hood or band). Places FrontSight at the tip.
func front_blade(z: float, y_base: float, tip: float, kind: String = "blued", width: float = 0.0028, depth: float = 0.004,
		parent: Node3D = null) -> void:
	box(Vector3(width, tip - y_base, depth), Vector3(0, (tip + y_base) * 0.5, z), kind, Vector3.ZERO, parent)
	sight_mark("FrontSight", Vector3(0, tip, z), parent)


## Front bead (shotguns, wonder weapons): a ball whose top is the aim point. Places FrontSight there.
func front_bead(pos: Vector3, r: float = 0.003, kind: String = "brass", parent: Node3D = null) -> void:
	ball(r, pos, kind, Vector3.ONE, parent)
	sight_mark("FrontSight", pos + Vector3(0, r * 0.7, 0), parent)


## Front post with an optional hood (an arch you see the post inside). Places FrontSight at the post tip.
func front_post(z: float, y_base: float, tip: float, kind: String = "blued", hood: bool = true, hood_r: float = 0.011,
		width: float = 0.0028) -> void:
	front_blade(z, y_base, tip, kind, width)
	wedge(Vector3(width, 0.002, 0.004), Vector3(0, tip - 0.0002, z), kind)
	box(Vector3(0.012, 0.005, 0.016), Vector3(0, y_base + 0.0025, z), kind)              # sight base / band
	if hood:
		var hood_c: Vector3 = Vector3(0, tip - 0.002, z)
		var t: MeshInstance3D = tube(hood_r + 0.0018, hood_r + 0.0018, 0.016, hood_c, kind, "z", null, 16)
		# open the bottom of the hood: only the upper arch remains visible from behind (cheap: a dark
		# disc would hide the post, so the hood is a thin open tube drawn double-sided)
		var cm: CylinderMesh = t.mesh as CylinderMesh
		cm.top_radius = hood_r + 0.0018
		cm.bottom_radius = hood_r + 0.0018
		cm.cap_top = false
		cm.cap_bottom = false
		t.material_override = two_sided(kind)


## Telescopic sight: SightPoint at the eyepiece center, FrontSight at the objective center (the tube axis is
## the sight line). The tube itself is built by the caller.
func scope_sight(eyepiece: Vector3, objective: Vector3) -> void:
	sight_mark("SightPoint", eyepiece)
	sight_mark("FrontSight", objective)


## Double-sided variant of a material (open tubes: hoods, scope bodies).
func two_sided(kind: String) -> Material:
	var key: String = kind + "_2s" + ("_up" if upgraded else "")
	if not _mat_cache.has(key):
		var src: BaseMaterial3D = m(kind) as BaseMaterial3D
		var d: BaseMaterial3D = src.duplicate() as BaseMaterial3D
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_cache[key] = d
	return _mat_cache[key]


## Trigger guard loop + trigger under a receiver, centered at z.
func trigger_group(z: float, y: float, kind: String = "blued", w: float = 0.012) -> void:
	box(Vector3(w, 0.006, 0.07), Vector3(0, y - 0.045, z), kind)
	box(Vector3(w, 0.04, 0.006), Vector3(0, y - 0.025, z - 0.035), kind)
	box(Vector3(w * 0.6, 0.03, 0.006), Vector3(0, y - 0.022, z + 0.005), kind, Vector3(-15, 0, 0))


## Pistol grip: a sloped, slightly flared shape hanging from (z, y). Points are (z, y).
func grip(z: float, y: float, length: float, kind: String, slope_deg: float = 18.0, width: float = 0.045, thick: float = 0.032, parent: Node3D = null) -> MeshInstance3D:
	var s: float = tan(deg_to_rad(slope_deg))
	if parent == null and not root.has_meta("grip_r"):
		var f: float = minf(0.045, length * 0.45)
		rhand(Vector3(0, y - f, z + f * s), slope_deg, (width + thick) * 0.25)
	var pts: Array = [
		Vector2(z - width * 0.5, y), Vector2(z + width * 0.5, y),
		Vector2(z + width * 0.55 + length * s, y - length * 0.85),
		Vector2(z + width * 0.45 + length * s, y - length),
		Vector2(z - width * 0.45 + length * s, y - length),
		Vector2(z - width * 0.55 + length * s * 0.9, y - length * 0.5),
	]
	return prof(pts, thick, kind, 0.0, parent)


## Firing-hand fist: center of the gripped part, grip-axis lean back from vertical (deg), part radius.
func rhand(center: Vector3, lean_deg: float, radius: float = 0.019) -> void:
	root.set_meta("grip_r", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-lean_deg)), center))
	root.set_meta("grip_r_radius", radius)


## Support-hand fist: the "LeftHand" marker is the center of the held part. axis "z" = along the barrel
## (handguard, pump, jacket), "y" = an upright grip (foregrip, magazine, or cupping a pistol hand).
func lhand(center: Vector3, axis: String = "z", radius: float = 0.024) -> void:
	marker("LeftHand", center)
	root.set_meta("lh_axis", axis)
	root.set_meta("lh_radius", radius)


## Convert an array of [z, y] pairs into Vector2 points.
static func P(a: Array) -> Array:
	var out: Array = []
	for e: Array in a:
		out.append(Vector2(float(e[0]), float(e[1])))
	return out


# ================================================================== the weapons

## The starting pistol: a 1911-pattern .45 in a parkerized service finish (unmarked except an invented
## arsenal stamp). Built at real scale; the slide is a stack of cross-sections (rounded top, open ejection
## port with the barrel hood showing, the full-height nose holding bushing and recoil-spring plug).
## Controls sit where they belong: slide stop, thumb safety, plunger tube and magazine catch on the left
## (the side the viewmodel shows), the pin ends on the right.
func _w_m1911() -> void:
	const SW: float = 0.0117           # slide half-width
	const FW: float = 0.0111           # frame half-width
	const TOP: float = 0.051           # slide top
	const SB: float = 0.0255           # slide bottom / frame rails
	const BY: float = 0.0385           # bore line
	var sl: Node3D = group("Slide")
	# one loop: up the right side, over the rounded top, down the left
	var top_l: Array = [Vector2(SW, 0.0445), Vector2(0.0097, 0.0493), Vector2(0.0066, TOP), Vector2(-0.0066, TOP),
		Vector2(-0.0097, 0.0493), Vector2(-SW, 0.0445)]
	# nose: full height, rounded spring tunnel underneath
	var nose: Array = [Vector2(-SW, 0.016), Vector2(-0.0094, 0.0098), Vector2(-0.0056, 0.0080), Vector2(0.0056, 0.0080),
		Vector2(0.0094, 0.0098), Vector2(SW, 0.016)] + top_l
	xsec(nose, -0.168, -0.1285, "park_slide", sl, 0.0011, 0.0)
	var upper: Array = [Vector2(-SW, SB), Vector2(SW, SB)] + top_l
	xsec(upper, -0.1285, -0.036, "park_slide", sl)
	# ejection port (right side): a C-section open on the right, barrel hood visible inside
	var port: Array = [Vector2(-SW, SB), Vector2(SW, SB), Vector2(SW, 0.0315), Vector2(-0.0086, 0.0315),
		Vector2(-0.0086, 0.0476), Vector2(0.0099, 0.0476), Vector2(0.0097, 0.0493), Vector2(0.0066, TOP),
		Vector2(-0.0066, TOP), Vector2(-0.0097, 0.0493), Vector2(-SW, 0.0445)]
	xsec(port, -0.036, -0.004, "park_slide", sl)
	xsec(upper, -0.004, 0.0462, "park_slide", sl, 0.0, 0.0012)
	tube(0.0086, 0.0086, 0.034, Vector3(0, BY, -0.019), "steel", "z", sl, 16)                 # barrel hood
	# rear serrations, both sides
	for i: int in 10:
		var z: float = 0.0135 + i * 0.0031
		for s: float in [-1.0, 1.0]:
			box(Vector3(0.0006, 0.0175, 0.0012), Vector3(s * (SW + 0.0001), 0.0352, z), "black", Vector3.ZERO, sl)
	# muzzle: barrel crown in the bushing, recoil-spring plug below
	tube(0.0069, 0.0069, 0.006, Vector3(0, BY, -0.1690), "steel", "z", sl, 16)
	tube(0.0091, 0.0091, 0.0035, Vector3(0, BY, -0.1690), "blued", "z", sl, 18)               # barrel bushing
	box(Vector3(0.004, 0.0035, 0.0034), Vector3(0.0082, BY - 0.0058, -0.1691), "blued", Vector3(0, 0, 40), sl)  # bushing lug
	tube(0.0056, 0.0056, 0.0032, Vector3(0, 0.0162, -0.1692), "park_frame", "z", sl, 14)      # recoil-spring plug
	tube(0.0017, 0.0017, 0.001, Vector3(0, 0.0162, -0.1709), "black", "z", sl, 8)             # plug dimple
	# sights: tapered front blade, notched rear on a dovetail (an attachment may fit its own: M1911KitModels)
	if not M1911KitModels.build_sights(self, sl, TOP):
		prof(P([[-0.1612, TOP - 0.0004], [-0.1502, TOP - 0.0004], [-0.1528, 0.0566], [-0.1585, 0.0566]]), 0.0032, "park_slide", 0.0, sl)
		sight_mark("FrontSight", Vector3(0, 0.0566, (-0.1528 - 0.1585) * 0.5), sl)                    # the blade's flat top
		rear_notch(0.0392, TOP - 0.0004, 0.0072, "park_slide", 0.0158, 0.0036, sl)
		box(Vector3(0.0215, 0.0016, 0.0085), Vector3(0, TOP - 0.0002, 0.0392), "park_slide", Vector3.ZERO, sl)  # dovetail
	box(Vector3(0.011, 0.0145, 0.0012), Vector3(0, 0.0375, 0.0465), "blued", Vector3.ZERO, sl)           # firing-pin stop
	tube(0.0021, 0.0021, 0.0012, Vector3(0, BY, 0.0472), "steel", "z", sl, 10)                         # firing pin
	# invented arsenal stamp on the left flat: two short lines of dashes and a small proof ring (no real marks)
	for d: Array in [[-0.118, 0.006], [-0.1105, 0.004], [-0.105, 0.007], [-0.0965, 0.003], [-0.0915, 0.006]]:
		box(Vector3(0.0004, 0.0018, float(d[1])), Vector3(-SW - 0.0001, 0.0368, float(d[0])), "black", Vector3.ZERO, sl)
	for d2: Array in [[-0.116, 0.008], [-0.106, 0.005], [-0.0985, 0.007]]:
		box(Vector3(0.0004, 0.0012, float(d2[1])), Vector3(-SW - 0.0001, 0.0332, float(d2[0])), "black", Vector3.ZERO, sl)
	ring(0.0012, 0.0021, Vector3(-SW - 0.0001, 0.035, -0.085), "black", "x", sl)
	box(Vector3(0.0005, 0.004, 0.006), Vector3(-SW - 0.0001, 0.0285, -0.0275), "black", Vector3.ZERO, sl)  # slide-stop notch

	# ---- frame
	var fr: String = "park_frame"
	prof(P([[0.0462, SB], [-0.1285, SB], [-0.1285, 0.0095], [-0.118, 0.0081], [-0.043, 0.0078], [-0.0365, 0.004],
		[0.014, 0.0], [0.03, 0.0], [0.0462, 0.012]]), FW * 2.0, fr)
	# grip frame (front strap ~20 deg, back strap) down to the magazine well
	prof(P([[0.0135, 0.0015], [0.016, -0.004], [0.0505, -0.0995], [0.0535, -0.1028], [0.0885, -0.1028], [0.0905, -0.099],
		[0.0555, 0.003], [0.047, 0.013], [0.03, 0.002]]), FW * 2.0, fr)
	# arched mainspring housing (fine horizontal grooves), with the lanyard loop under it
	prof(P([[0.0625, -0.03], [0.0665, -0.031], [0.0825, -0.071], [0.0925, -0.0975], [0.0935, -0.1028], [0.0855, -0.1028], [0.0705, -0.062]]),
		FW * 2.0 - 0.0014, fr)
	for i: int in 9:
		var t: float = float(i) / 8.0
		var gy: float = lerpf(-0.04, -0.096, t)
		# the housing's back face: z = 0.0665 + (-0.031 - y) * 0.391; grooves sit flush in it (half buried)
		box(Vector3(FW * 2.0 - 0.0026, 0.0007, 0.0012), Vector3(0, gy, 0.0665 + (-0.031 - gy) * 0.391 - 0.0002), "black", Vector3(-21, 0, 0))
	ring(0.0018, 0.0034, Vector3(0, -0.1055, 0.0945), "steel", "x")                              # lanyard loop
	box(Vector3(0.006, 0.004, 0.006), Vector3(0, -0.1032, 0.0905), fr)                              # its lug
	# trigger guard: a round bow (5.5 mm band) joined to the dust cover in front and the front strap behind
	var tg: Array = [[-0.0325, 0.005]]
	for i: int in 19:
		var a: float = deg_to_rad(180.0 + 10.0 * i)
		tg.append([-0.0085 + 0.024 * cos(a), -0.0065 + 0.0235 * sin(a)])
	tg.append([0.0155, 0.004])
	tg.append([0.01, 0.004])
	for i: int in 19:
		var a2: float = deg_to_rad(360.0 - 10.0 * i)
		tg.append([-0.0085 + 0.0185 * cos(a2), -0.0065 + 0.018 * sin(a2)])
	tg.append([-0.027, 0.005])
	prof(P(tg), 0.0105, fr)
	# flat-faced trigger with a few grooves
	prof(P([[-0.0112, 0.0035], [-0.0048, 0.0035], [-0.0052, -0.0125], [-0.0082, -0.0152], [-0.0118, -0.0125]]), 0.0068, "blued")
	for i: int in 3:
		box(Vector3(0.0062, 0.0006, 0.0008), Vector3(0, -0.002 - i * 0.0035, -0.0118), "black")
	# hammer, cocked: the body rises out of the frame's rear face, the spur curls back into a rounded,
	# grooved thumb pad over the tang (pivot pin through the frame at z 0.0395)
	var hz: float = 0.067      # spur lobe centre (z, y) and radius
	var hy: float = 0.0485
	var hr: float = 0.007
	var hp: Array = [[0.0445, 0.0205], [0.0548, 0.0205], [0.0608, 0.031], [0.0665, 0.0398]]
	for a: int in range(-30, 201, 20):
		hp.append([hz + hr * cos(deg_to_rad(float(a))), hy + hr * sin(deg_to_rad(float(a)))])
	hp.append_array([[0.0538, 0.0362], [0.0474, 0.028]])
	prof(P(hp), 0.0096, "blued")
	for a2: int in range(15, 121, 21):
		var ar: float = deg_to_rad(float(a2))
		box(Vector3(0.0088, 0.0006, 0.0013), Vector3(0, hy + (hr + 0.0001) * sin(ar), hz + (hr + 0.0001) * cos(ar)), "black", Vector3(-(float(a2) + 90.0), 0, 0))
	# beavertail grip safety: tang behind the hammer, a slim tail curling over the web of the hand, a raised
	# pad down the back strap
	prof(P([[0.0498, 0.006], [0.0548, 0.0182], [0.06, 0.0225], [0.066, 0.0252], [0.072, 0.0262], [0.0775, 0.0255], [0.0808, 0.0235],
		[0.081, 0.0212], [0.0785, 0.019], [0.0735, 0.017], [0.0685, 0.0146], [0.064, 0.0105], [0.0615, 0.0062], [0.0622, -0.012],
		[0.0652, -0.0255], [0.0618, -0.0335], [0.0578, -0.0145]]), 0.0138, "park_slide")
	# left side: slide stop, plunger tube, thumb safety, magazine catch
	var lx: float = -(FW + 0.0013)
	prof(P([[-0.0305, 0.0118], [-0.0175, 0.0115], [-0.0055, 0.0158], [0.0015, 0.0212], [0.0005, 0.0262], [-0.0058, 0.0262],
		[-0.0108, 0.0225], [-0.0222, 0.0216], [-0.0305, 0.0205]]), 0.0026, fr, lx)
	tube(0.0036, 0.0036, 0.0016, Vector3(lx - 0.0018, 0.0162, -0.0262), "steel", "x", null, 12)    # slide-stop pivot boss
	for i: int in 3:
		box(Vector3(0.0008, 0.0042, 0.0006), Vector3(lx - 0.0012, 0.0225, -0.0045 + i * 0.0018), "black")
	tube(0.0028, 0.0028, 0.024, Vector3(lx - 0.0012, 0.0214, 0.0175), "park_frame", "z", null, 10)  # plunger tube
	prof(P([[0.0318, 0.0145], [0.0468, 0.0145], [0.0492, 0.0228], [0.0455, 0.0262], [0.0215, 0.0258], [0.0178, 0.0222],
		[0.0232, 0.0196], [0.0318, 0.0196]]), 0.0026, fr, lx)                                         # thumb safety
	box(Vector3(0.0062, 0.0018, 0.0105), Vector3(lx - 0.0031, 0.0252, 0.0235), fr)                   # safety thumb shelf
	tube(0.0042, 0.0042, 0.0028, Vector3(-(FW + 0.0014), -0.0055, 0.0245), "park_frame", "x", null, 14)  # magazine catch
	for i: int in 3:
		box(Vector3(0.0004, 0.0062, 0.0006), Vector3(-(FW + 0.0029), -0.0055, 0.0228 + i * 0.0017), "black")
	# right side: pin ends (slide-stop pin, hammer pin, magazine-catch lock); the hammer pin shows on the left too
	tube(0.0028, 0.0028, 0.0012, Vector3(FW + 0.0005, 0.0162, -0.0262), "steel", "x", null, 10)
	tube(0.0024, 0.0024, 0.0012, Vector3(FW + 0.0005, 0.0185, 0.0395), "steel", "x", null, 10)
	tube(0.0024, 0.0024, 0.0012, Vector3(-(FW + 0.0005), 0.0185, 0.0395), "steel", "x", null, 10)
	tube(0.0032, 0.0032, 0.0012, Vector3(FW + 0.0005, -0.0055, 0.0245), "park_frame", "x", null, 12)
	# checkered walnut grip panels with two slotted screws each
	var yt: float = -0.0042
	var yb: float = -0.0965
	var ft: float = 0.016 + (0.0 - yt) * 0.363 + 0.0028
	var fb: float = 0.016 + (0.0 - yb) * 0.363 + 0.0028
	var bt: float = 0.0555 + (0.003 - yt) * 0.343 - 0.0042
	var bb: float = 0.0555 + (0.003 - yb) * 0.343 - 0.0042
	var gpts: Array = [[ft + 0.002, yt], [bt - 0.003, yt], [bt, yt - 0.003], [bb, yb + 0.003], [bb - 0.003, yb], [fb + 0.003, yb],
		[fb, yb + 0.003], [ft, yt - 0.003]]
	root.set_meta("grip_panel", gpts)   # the outline, for attachment grips (M1911KitModels)
	for s: float in [-1.0, 1.0]:
		var px: float = s * (FW + 0.0016)
		prof(P(gpts), 0.0032, "wood_check", px)
		for sy: float in [-0.0165, -0.084]:
			var cz: float = lerpf(ft, bt, 0.5) + (-sy + yt) * 0.353
			tube(0.0027, 0.0027, 0.0011, Vector3(px + s * 0.0019, sy, cz), "steel", "x", null, 12)
			box(Vector3(0.0006, 0.0006, 0.0046), Vector3(px + s * 0.0024, sy, cz), "black", Vector3(35, 0, 0))

	# ---- magazine: body inside the grip, baseplate under it, top round visible when it drops
	var mag: Node3D = group("Mag")
	prof(P([[0.0215, -0.0035], [0.0535, -0.0985], [0.0855, -0.0985], [0.0525, -0.0035]]), 0.0176, "blued", 0.0, mag)
	prof(P([[0.0498, -0.1028], [0.0905, -0.1028], [0.0918, -0.1062], [0.0882, -0.1078], [0.0512, -0.1078], [0.0488, -0.1056]]),
		0.0214, "steel", 0.0, mag)
	tube(0.0056, 0.0059, 0.021, Vector3(0, -0.0008, 0.0405), "brass", "z", mag, 12)
	ball(0.0056, Vector3(0, -0.0008, 0.0302), "bronze", Vector3(1, 1, 1.25), mag)

	marker("Muzzle", Vector3(0, BY, -0.1725))
	rhand(Vector3(0, -0.05, 0.053), 20.0, 0.017)
	lhand(Vector3(-0.006, -0.056, 0.05), "y", 0.03)
	meta("pistol", 0.216)
	root.set_meta("port", Vector3(0.0125, 0.0405, -0.02))
	root.set_meta("bore", 0.0057)


## Muster sidearm (T-079): a Walther P38 pattern 9 mm, kitbashed from the same primitives as the M1911 at real
## scale (no markings). Open-topped slide over the front of the barrel, blued steel, black ribbed grips,
## an exposed hammer. The whole slide (with the barrel and both sights) is the "Slide" part.
func _w_walther_p38() -> void:
	const SW: float = 0.0112
	const TOP: float = 0.049
	const SB: float = 0.025
	const BY: float = 0.0375
	var sl: Node3D = group("Slide")
	prof(P([[0.045, SB], [-0.066, SB], [-0.066, TOP], [0.038, TOP], [0.045, TOP - 0.005]]), SW * 2.0, "blued", 0.0, sl)   # rear slide
	prof(P([[-0.066, SB], [-0.152, SB], [-0.155, SB + 0.004], [-0.155, 0.0425], [-0.066, 0.0425]]), SW * 2.0, "blued", 0.0, sl)  # open top
	tube(0.0072, 0.0072, 0.112, Vector3(0, BY, -0.12), "steel", "z", sl, 16)       # the barrel showing through the top
	tube(0.0058, 0.0058, 0.004, Vector3(0, BY, -0.1765), "blued", "z", sl, 14)     # crown
	for i: int in 8:
		for s: float in [-1.0, 1.0]:
			box(Vector3(0.0006, 0.016, 0.0012), Vector3(s * (SW + 0.0001), 0.036, 0.012 + i * 0.0034), "black", Vector3.ZERO, sl)
	box(Vector3(0.0045, 0.006, 0.01), Vector3(-SW - 0.002, 0.04, 0.005), "blued", Vector3.ZERO, sl)   # safety lever
	front_blade(-0.149, 0.0425, 0.0545, "blued", 0.0028, 0.005, sl)
	box(Vector3(0.01, 0.003, 0.012), Vector3(0, 0.0435, -0.149), "blued", Vector3.ZERO, sl)            # sight base
	rear_notch(0.034, TOP, 0.0068, "blued", 0.015, 0.0036, sl)
	# ---- frame, trigger guard, grip
	prof(P([[0.046, SB], [-0.128, SB], [-0.128, 0.013], [-0.04, 0.009], [0.014, 0.0], [0.046, 0.012]]), 0.0212, "blued")
	prof(P([[0.012, 0.002], [0.016, -0.004], [0.046, -0.097], [0.084, -0.097], [0.057, 0.004], [0.048, 0.013], [0.03, 0.002]]), 0.0212, "blued")
	var tg: Array = [[-0.034, 0.006]]
	for i: int in 13:
		var a: float = deg_to_rad(180.0 + 15.0 * i)
		tg.append([-0.01 + 0.022 * cos(a), -0.006 + 0.021 * sin(a)])
	tg.append([0.014, 0.004])
	tg.append([0.009, 0.004])
	for i: int in 13:
		var a2: float = deg_to_rad(360.0 - 15.0 * i)
		tg.append([-0.01 + 0.017 * cos(a2), -0.006 + 0.016 * sin(a2)])
	tg.append([-0.029, 0.006])
	prof(P(tg), 0.0095, "blued")
	prof(P([[-0.013, 0.004], [-0.007, 0.004], [-0.008, -0.013], [-0.012, -0.015], [-0.014, -0.011]]), 0.0065, "blued")   # trigger
	prof(P([[0.044, 0.02], [0.054, 0.022], [0.064, 0.043], [0.058, 0.047], [0.05, 0.034]]), 0.009, "blued")              # hammer
	var gp: Array = [[0.022, -0.006], [0.051, -0.004], [0.08, -0.092], [0.05, -0.092]]
	for s2: float in [-1.0, 1.0]:
		prof(P(gp), 0.003, "black", s2 * 0.0122)
		for i: int in 9:
			var gy: float = lerpf(-0.014, -0.086, float(i) / 8.0)
			var gz: float = 0.0365 + (-0.006 - gy) * 0.33
			box(Vector3(0.0012, 0.0012, 0.026), Vector3(s2 * 0.0139, gy, gz), "black", Vector3(-18, 0, 0))
	ring(0.0016, 0.003, Vector3(0, -0.1, 0.087), "steel", "x")   # lanyard loop
	# ---- magazine in the grip, its base plate under it
	var mag: Node3D = group("Mag")
	prof(P([[0.022, -0.004], [0.05, -0.094], [0.082, -0.094], [0.053, -0.004]]), 0.017, "blued", 0.0, mag)
	prof(P([[0.047, -0.097], [0.087, -0.097], [0.088, -0.103], [0.048, -0.103]]), 0.02, "steel", 0.0, mag)
	tube(0.0045, 0.0048, 0.018, Vector3(0, -0.001, 0.04), "brass", "z", mag, 10)
	marker("Muzzle", Vector3(0, BY, -0.179))
	rhand(Vector3(0, -0.05, 0.052), 19.0, 0.017)
	lhand(Vector3(-0.006, -0.056, 0.049), "y", 0.03)
	meta("pistol", 0.215)
	root.set_meta("port", Vector3(0.0122, 0.041, -0.03))
	root.set_meta("bore", 0.0045)


## Muster sidearm (T-079): a Luger P08 pattern 9 mm. A slim exposed barrel on a receiver, the toggle on top (the
## "Slide" part: it runs back a little on each shot), a steeply raked grip with walnut panels and a wooden-based
## magazine. Rear sight notch on the toggle, front blade at the muzzle.
func _w_luger_p08() -> void:
	const BY: float = 0.034
	tube(0.0064, 0.0058, 0.102, Vector3(0, BY, -0.131), "blued", "z", null, 16)      # barrel
	tube(0.0085, 0.0085, 0.022, Vector3(0, BY, -0.072), "blued", "z", null, 16)      # barrel shank
	prof(P([[-0.082, 0.022], [-0.06, 0.022], [-0.06, 0.044], [-0.082, 0.042]]), 0.021, "blued")   # barrel extension front
	for s: float in [-1.0, 1.0]:
		box(Vector3(0.003, 0.02, 0.085), Vector3(s * 0.0105, 0.033, -0.018), "blued")             # receiver side rails
	prof(P([[0.055, 0.024], [-0.085, 0.024], [-0.085, 0.012], [-0.03, 0.01], [0.012, 0.0], [0.055, 0.012]]), 0.022, "blued")  # frame
	front_blade(-0.177, BY + 0.0058, 0.0505, "blued", 0.0026, 0.005)
	box(Vector3(0.008, 0.004, 0.012), Vector3(0, BY + 0.007, -0.176), "blued")              # sight base
	var tl: Node3D = group("Slide")
	prof(P([[-0.06, 0.03], [-0.06, 0.044], [0.0, 0.046], [0.006, 0.042], [0.006, 0.03]]), 0.017, "blued", 0.0, tl)   # breech block
	prof(P([[0.004, 0.034], [0.006, 0.046], [0.05, 0.047], [0.055, 0.04], [0.05, 0.034]]), 0.015, "blued", 0.0, tl)  # rear link
	for s3: float in [-1.0, 1.0]:
		tube(0.0072, 0.0072, 0.006, Vector3(s3 * 0.0105, 0.041, 0.048), "blued", "x", tl, 14)   # toggle knobs
		for i: int in 6:
			var an: float = TAU * float(i) / 6.0
			box(Vector3(0.0062, 0.0014, 0.0014), Vector3(s3 * 0.0105, 0.041 + 0.0068 * sin(an), 0.048 + 0.0068 * cos(an)), "black", Vector3.ZERO, tl)
	rear_notch(0.03, 0.047, 0.0045, "blued", 0.012, 0.0034, tl)
	# trigger guard, trigger, grip safety lever
	var tg: Array = [[-0.036, 0.004]]
	for i2: int in 13:
		var a: float = deg_to_rad(180.0 + 15.0 * i2)
		tg.append([-0.013 + 0.021 * cos(a), -0.006 + 0.02 * sin(a)])
	tg.append([0.01, 0.002])
	tg.append([0.005, 0.002])
	for i3: int in 13:
		var a2: float = deg_to_rad(360.0 - 15.0 * i3)
		tg.append([-0.013 + 0.016 * cos(a2), -0.006 + 0.015 * sin(a2)])
	tg.append([-0.031, 0.004])
	prof(P(tg), 0.009, "blued")
	prof(P([[-0.016, 0.003], [-0.01, 0.003], [-0.011, -0.013], [-0.015, -0.015], [-0.017, -0.011]]), 0.0065, "blued")
	box(Vector3(0.004, 0.012, 0.008), Vector3(-0.0125, 0.012, 0.03), "blued")
	# raked grip frame, checkered walnut panels
	prof(P([[0.004, 0.002], [0.008, -0.004], [0.058, -0.092], [0.096, -0.092], [0.098, -0.085], [0.06, 0.004], [0.05, 0.012]]), 0.021, "blued")
	var gp: Array = [[0.016, -0.008], [0.048, -0.006], [0.088, -0.082], [0.061, -0.084]]
	for s2: float in [-1.0, 1.0]:
		prof(P(gp), 0.003, "wood_check", s2 * 0.012)
	var mag: Node3D = group("Mag")
	prof(P([[0.012, -0.004], [0.058, -0.088], [0.088, -0.088], [0.044, -0.004]]), 0.016, "blued", 0.0, mag)
	prof(P([[0.056, -0.092], [0.096, -0.092], [0.098, -0.104], [0.058, -0.104]]), 0.021, "wood", 0.0, mag)   # wooden base knob
	tube(0.0045, 0.0048, 0.018, Vector3(0, -0.001, 0.03), "brass", "z", mag, 10)
	marker("Muzzle", Vector3(0, BY, -0.183))
	rhand(Vector3(0, -0.046, 0.05), 30.0, 0.017)
	lhand(Vector3(-0.006, -0.052, 0.049), "y", 0.03)
	meta("pistol", 0.222)
	root.set_meta("port", Vector3(0.0, 0.05, 0.0))
	root.set_meta("bore", 0.0045)


## Muster sidearm (T-079): a Webley Mk VI pattern .455 break-top revolver. The barrel, its rib and the cylinder are
## the "Barrels" part, hinged at the front of the frame (the "break" reload tips it down). Tall front blade on
## the barrel, the rear notch on the frame's latch, a bird's-head walnut grip with a lanyard ring.
func _w_webley() -> void:
	const BY: float = 0.038
	var br: Node3D = group("Barrels", Vector3(0, 0.004, -0.06))
	var ly: float = BY - 0.004   # bore height in the hinge group
	tube(0.0088, 0.0088, 0.152, Vector3(0, ly, -0.076), "blued", "z", br, 16)
	box(Vector3(0.006, 0.006, 0.15), Vector3(0, ly + 0.0098, -0.076), "blued", Vector3.ZERO, br)   # top rib
	box(Vector3(0.011, 0.012, 0.03), Vector3(0, ly - 0.012, -0.02), "blued", Vector3.ZERO, br)    # hinge lug
	tube(0.0198, 0.0198, 0.054, Vector3(0, ly, 0.03), "blued", "z", br, 18)                       # cylinder
	for i: int in 6:
		var an: float = TAU * (float(i) + 0.5) / 6.0
		box(Vector3(0.003, 0.003, 0.036), Vector3(0.0196 * cos(an), ly + 0.0196 * sin(an), 0.03), "black", Vector3(0, 0, rad_to_deg(an)), br)
		# chamber mouths on the rear face (seen when the break tips the cylinder up at the eye)
		var ca: float = TAU * float(i) / 6.0
		tube(0.0052, 0.0052, 0.002, Vector3(0.0112 * cos(ca), ly + 0.0112 * sin(ca), 0.0574), "black", "z", br, 10)
	tube(0.0042, 0.0042, 0.0016, Vector3(0, ly, 0.0576), "steel", "z", br, 6)                      # ejector star
	box(Vector3(0.012, 0.005, 0.064), Vector3(0, ly + 0.0215, 0.027), "blued", Vector3.ZERO, br)  # top strap
	front_blade(-0.142, ly + 0.0125, 0.0615, "blued", 0.003, 0.006, br)
	tube(0.0062, 0.0062, 0.004, Vector3(0, ly, -0.1535), "steel", "z", br, 14)                    # crown
	# ---- frame (stays put), latch, hammer, grip
	prof(P([[-0.062, 0.019], [-0.062, 0.006], [0.0, 0.002], [0.016, 0.0], [0.044, 0.006], [0.05, 0.028], [0.042, 0.048],
		[0.03, 0.0575], [0.006, 0.0575], [0.003, 0.052], [-0.002, 0.019]]), 0.024, "blued")
	box(Vector3(0.014, 0.006, 0.014), Vector3(0, 0.061, 0.021), "blued")                          # barrel latch
	rear_notch(0.022, 0.064, 0.005, "blued", 0.013, 0.0034)
	prof(P([[0.04, 0.034], [0.052, 0.036], [0.062, 0.054], [0.057, 0.059], [0.047, 0.047]]), 0.009, "blued")   # hammer spur
	var tg: Array = [[-0.026, 0.002]]
	for i2: int in 13:
		var a: float = deg_to_rad(180.0 + 15.0 * i2)
		tg.append([-0.004 + 0.02 * cos(a), -0.006 + 0.02 * sin(a)])
	tg.append([0.018, 0.001])
	tg.append([0.013, 0.001])
	for i3: int in 13:
		var a2: float = deg_to_rad(360.0 - 15.0 * i3)
		tg.append([-0.004 + 0.015 * cos(a2), -0.006 + 0.015 * sin(a2)])
	tg.append([-0.021, 0.002])
	prof(P(tg), 0.0095, "blued")
	prof(P([[-0.007, 0.002], [-0.001, 0.002], [-0.002, -0.014], [-0.007, -0.016], [-0.009, -0.011]]), 0.0065, "blued")
	prof(P([[0.024, 0.006], [0.046, 0.008], [0.06, -0.03], [0.086, -0.074], [0.084, -0.088], [0.062, -0.09], [0.05, -0.07], [0.036, -0.022]]), 0.02, "blued")
	var gp: Array = [[0.032, -0.006], [0.05, -0.004], [0.08, -0.07], [0.064, -0.082], [0.054, -0.064]]
	for s2: float in [-1.0, 1.0]:
		prof(P(gp), 0.004, "wood_check", s2 * 0.0115)
	ring(0.002, 0.0042, Vector3(0, -0.094, 0.075), "steel", "x")   # lanyard ring
	marker("Muzzle", Vector3(0, BY, -0.216))
	rhand(Vector3(0, -0.045, 0.06), 26.0, 0.017)
	lhand(Vector3(-0.006, -0.05, 0.058), "y", 0.03)
	meta("break", 0.27)
	root.set_meta("bore", 0.0055)
	root.set_meta("cylinder", true)   # the break reload loads six revolver rounds, not a shotgun shell


func _kar_stock(wood: String, front: float) -> void:
	prof(P([[0.38, 0.004], [0.22, 0.01], [0.09, 0.02], [0.05, 0.024], [front + 0.03, 0.022], [front, 0.005],
		[front + 0.01, -0.027], [-0.1, -0.032], [-0.02, -0.04], [0.025, -0.072], [0.072, -0.088], [0.11, -0.074],
		[0.2, -0.105], [0.38, -0.148]]), 0.043, wood)
	box(Vector3(0.045, 0.155, 0.01), Vector3(0, -0.072, 0.384), "blued", Vector3(-15, 0, 0))   # buttplate
	box(Vector3(0.01, 0.012, 0.03), Vector3(0, -0.135, 0.3), "blued")                          # sling slot
	prof(P([[-0.1, 0.019], [-0.42, 0.019], [-0.42, 0.048], [-0.1, 0.044]]), 0.03, wood)        # upper handguard


func _bolt_turned_down(handle_x: float = 0.05) -> Node3D:
	var bolt: Node3D = group("Bolt", Vector3(0, 0.032, 0.05))
	tube(0.0095, 0.0095, 0.13, Vector3(0, 0, -0.025), "steel", "z", bolt)
	var h: Node3D = group("Handle", Vector3(0.008, 0, 0.0), bolt)
	h.rotation_degrees = Vector3(0, 0, -50)
	tube(0.0045, 0.0045, 0.05, Vector3(0.025, 0, 0), "steel", "x", h)
	ball(0.0105, Vector3(handle_x, 0, 0), "steel", Vector3.ONE, h)
	prof(P([[0.04, -0.011], [0.075, -0.009], [0.078, 0.004], [0.04, 0.008]]), 0.014, "blued", 0.0, bolt)  # cocking piece
	box(Vector3(0.012, 0.004, 0.02), Vector3(0, 0.014, 0.062), "steel", Vector3.ZERO, bolt)              # safety wing
	return bolt


func _w_kar98k() -> void:
	_kar_stock("wood", -0.52)
	tube(0.0175, 0.0175, 0.2, Vector3(0, 0.032, -0.03), "blued")                                         # receiver
	box(Vector3(0.024, 0.01, 0.06), Vector3(0, 0.05, -0.05), "blued")                                     # receiver bridge/ring
	tube(0.009, 0.0135, 0.6, Vector3(0, 0.032, -0.43), "blued")                                           # stepped barrel
	tube(0.0115, 0.0115, 0.12, Vector3(0, 0.032, -0.2), "blued")
	tube(0.026, 0.026, 0.016, Vector3(0, 0.012, -0.29), "blued")                                           # barrel bands
	tube(0.026, 0.022, 0.035, Vector3(0, 0.014, -0.5), "blued")                                            # nose cap
	front_post(-0.705, 0.042, 0.06, "blued", true, 0.0105)                                              # hooded barleycorn
	prof(P([[-0.125, 0.043], [-0.21, 0.043], [-0.21, 0.049], [-0.14, 0.054], [-0.125, 0.054]]), 0.02, "blued")  # tangent leaf base
	rear_notch(-0.13, 0.052, 0.0105, "blued", 0.018, 0.0045)
	tube(0.003, 0.003, 0.36, Vector3(0, -0.012, -0.55), "steel")                                           # cleaning rod
	box(Vector3(0.024, 0.008, 0.085), Vector3(0, -0.035, -0.06), "blued")                                 # floorplate
	trigger_group(0.01, 0.0)
	_bolt_turned_down()
	marker("Mag", Vector3(0, 0.055, -0.03))
	marker("Muzzle", Vector3(0, 0.032, -0.73))
	rhand(Vector3(0, -0.03, 0.065), 38.0, 0.02)
	lhand(Vector3(0, 0.002, -0.33), "z", 0.026)
	meta("bolt", 1.11)
	root.set_meta("port", Vector3(0.012, 0.045, 0.0))
	root.set_meta("bore", 0.0045)


func _w_springfield() -> void:
	prof(P([[0.38, 0.0], [0.1, 0.015], [0.04, 0.022], [-0.46, 0.02], [-0.49, 0.003], [-0.48, -0.027], [-0.08, -0.032],
		[0.02, -0.05], [0.1, -0.07], [0.38, -0.15]]), 0.043, "wood")
	box(Vector3(0.045, 0.155, 0.01), Vector3(0, -0.075, 0.384), "park", Vector3(-15, 0, 0))
	prof(P([[-0.1, 0.019], [-0.4, 0.019], [-0.4, 0.045], [-0.1, 0.042]]), 0.03, "wood")
	tube(0.0175, 0.0175, 0.2, Vector3(0, 0.032, -0.03), "park")
	tube(0.009, 0.0135, 0.6, Vector3(0, 0.032, -0.43), "park")
	tube(0.026, 0.026, 0.016, Vector3(0, 0.012, -0.44), "park")
	# scope (M73B1-style): tube, objective bell, eyepiece, two rings on a base
	tube(0.012, 0.012, 0.25, Vector3(0, 0.09, -0.05), "black")
	tube(0.02, 0.012, 0.06, Vector3(0, 0.09, -0.205), "black")
	tube(0.0165, 0.012, 0.05, Vector3(0, 0.09, 0.1), "black")
	for z: float in [-0.12, 0.02]:
		tube(0.016, 0.016, 0.014, Vector3(0, 0.09, z), "black")
		box(Vector3(0.016, 0.04, 0.014), Vector3(0, 0.065, z), "black")
	box(Vector3(0.018, 0.012, 0.03), Vector3(0, 0.092, -0.05), "black")                                    # turret
	tube(0.0155, 0.0155, 0.002, Vector3(0, 0.09, 0.126), "glass")
	tube(0.019, 0.019, 0.002, Vector3(0, 0.09, -0.236), "glass")
	scope_sight(Vector3(0, 0.09, 0.126), Vector3(0, 0.09, -0.236))                                         # eyepiece -> objective
	trigger_group(0.03, 0.0, "park")
	var bolt: Node3D = group("Bolt", Vector3(0, 0.032, 0.05))
	tube(0.0095, 0.0095, 0.13, Vector3(0, 0, -0.025), "steel", "z", bolt)
	var h: Node3D = group("Handle", Vector3(0.008, 0, 0), bolt)
	h.rotation_degrees = Vector3(0, 0, -15)
	tube(0.0045, 0.0045, 0.05, Vector3(0.025, 0, 0), "steel", "x", h)
	ball(0.0095, Vector3(0.05, 0, 0), "steel", Vector3.ONE, h)
	marker("Mag", Vector3(0, 0.055, -0.03))
	marker("Muzzle", Vector3(0, 0.032, -0.73))
	rhand(Vector3(0, -0.022, 0.062), 38.0, 0.02)
	lhand(Vector3(0, 0.002, -0.31), "z", 0.026)
	meta("bolt", 1.1)
	root.set_meta("scope", 4.0)          # magnification hint; ADS shows the scope picture (HUD) instead of the model
	root.set_meta("port", Vector3(0.012, 0.045, 0.0))
	root.set_meta("bore", 0.0045)


func _w_m1_garand() -> void:
	prof(P([[0.38, 0.0], [0.1, 0.017], [0.05, 0.026], [-0.06, 0.026], [-0.06, 0.012], [-0.44, 0.012], [-0.46, -0.008],
		[-0.44, -0.033], [-0.14, -0.038], [-0.09, -0.055], [0.0, -0.058], [0.04, -0.068], [0.085, -0.092], [0.15, -0.098],
		[0.38, -0.162]]), 0.044, "wood")
	box(Vector3(0.046, 0.165, 0.01), Vector3(0, -0.078, 0.384), "park", Vector3(-15, 0, 0))
	prof(P([[-0.12, 0.03], [-0.3, 0.03], [-0.3, 0.058], [-0.12, 0.054]]), 0.034, "wood")                     # rear handguard
	prof(P([[-0.32, 0.03], [-0.6, 0.03], [-0.6, 0.05], [-0.32, 0.054]]), 0.032, "wood")                      # front handguard
	prof(P([[0.07, 0.022], [-0.12, 0.022], [-0.12, 0.06], [0.02, 0.062], [0.07, 0.05]]), 0.042, "park")       # receiver
	tube(0.0105, 0.0135, 0.63, Vector3(0, 0.04, -0.44), "park")
	tube(0.0135, 0.0135, 0.05, Vector3(0, 0.032, -0.73), "park")                                              # gas cylinder
	for x: float in [-0.0085, 0.0085]:
		box(Vector3(0.003, 0.022, 0.014), Vector3(x, 0.061, -0.735), "park")                                  # front sight ears
	front_blade(-0.735, 0.05, 0.069, "park")
	rear_aperture(0.05, 0.075, 0.06, "park", 0.0032, 0.008)
	var op: Node3D = group("Bolt", Vector3(0.025, 0.035, -0.07))
	tube(0.0045, 0.0045, 0.36, Vector3(0, -0.005, -0.18), "park", "z", op)
	prof(P([[0.0, -0.01], [0.03, -0.01], [0.03, 0.012], [0.0, 0.012]]), 0.016, "park", 0.006, op)
	var mag: Node3D = group("Mag", Vector3(0, 0.04, -0.02))
	box(Vector3(0.026, 0.008, 0.058), Vector3(0, 0.012, 0.0), "brass", Vector3.ZERO, mag)
	for i: int in 4:
		tube(0.0055, 0.0055, 0.052, Vector3(-0.006 + (i % 2) * 0.012, 0.02, 0.0), "brass", "z", mag)
	trigger_group(0.05, 0.0, "park")
	marker("Muzzle", Vector3(0, 0.04, -0.76))
	rhand(Vector3(0, -0.026, 0.072), 38.0, 0.02)
	lhand(Vector3(0, 0.008, -0.26), "z", 0.027)
	meta("enbloc", 1.1)
	root.set_meta("port", Vector3(0.012, 0.06, -0.03))
	root.set_meta("bore", 0.0045)


func _w_gewehr43() -> void:
	prof(P([[0.35, 0.0], [0.1, 0.015], [0.05, 0.024], [-0.36, 0.022], [-0.38, 0.003], [-0.36, -0.027], [-0.12, -0.03],
		[0.0, -0.045], [0.06, -0.086], [0.11, -0.07], [0.35, -0.142]]), 0.043, "wood_light")
	box(Vector3(0.045, 0.15, 0.01), Vector3(0, -0.072, 0.354), "blued", Vector3(-15, 0, 0))
	prof(P([[-0.15, 0.04], [-0.33, 0.04], [-0.33, 0.07], [-0.15, 0.066]]), 0.032, "wood_light")
	prof(P([[0.06, 0.02], [-0.14, 0.02], [-0.14, 0.055], [0.04, 0.055], [0.06, 0.045]]), 0.038, "blued")
	tube(0.009, 0.013, 0.5, Vector3(0, 0.034, -0.39), "blued")
	tube(0.0085, 0.0085, 0.26, Vector3(0, 0.06, -0.3), "blued")
	front_post(-0.615, 0.047, 0.068, "blued", true, 0.0105)
	prof(P([[-0.095, 0.055], [-0.15, 0.055], [-0.15, 0.06], [-0.095, 0.061]]), 0.02, "blued")
	rear_notch(-0.1, 0.058, 0.0115, "blued", 0.018, 0.0045)
	box(Vector3(0.006, 0.012, 0.1), Vector3(0.022, 0.045, -0.04), "blued")                                    # scope rail
	var bolt: Node3D = group("Bolt", Vector3(-0.024, 0.042, 0.0))
	box(Vector3(0.012, 0.012, 0.022), Vector3.ZERO, "steel", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.02, -0.07))
	prof(P([[0.035, 0.0], [-0.035, 0.0], [-0.04, -0.095], [0.032, -0.095]]), 0.026, "blued", 0.0, mag)
	trigger_group(0.05, 0.0)
	marker("Muzzle", Vector3(0, 0.034, -0.64))
	rhand(Vector3(0, -0.03, 0.05), 38.0, 0.02)
	lhand(Vector3(0, 0.01, -0.25), "z", 0.026)
	meta("mag", 1.13)
	root.set_meta("port", Vector3(0.02, 0.045, -0.03))
	root.set_meta("bore", 0.0045)


func _w_m1_carbine() -> void:
	prof(P([[0.3, 0.0], [0.1, 0.013], [0.05, 0.022], [-0.3, 0.022], [-0.32, 0.003], [-0.3, -0.025], [-0.02, -0.03],
		[0.04, -0.056], [0.1, -0.066], [0.3, -0.12]]), 0.04, "wood")
	box(Vector3(0.042, 0.125, 0.01), Vector3(0, -0.06, 0.304), "park", Vector3(-15, 0, 0))
	prof(P([[-0.1, 0.04], [-0.3, 0.04], [-0.3, 0.06], [-0.1, 0.058]]), 0.03, "wood")
	prof(P([[0.06, 0.022], [-0.1, 0.022], [-0.1, 0.055], [0.05, 0.055]]), 0.034, "park")
	tube(0.008, 0.011, 0.42, Vector3(0, 0.038, -0.33), "park")
	tube(0.024, 0.024, 0.02, Vector3(0, 0.025, -0.34), "park")
	box(Vector3(0.012, 0.016, 0.008), Vector3(0, -0.005, -0.34), "park")                                         # sling swivel
	for x: float in [-0.008, 0.008]:
		box(Vector3(0.0028, 0.02, 0.014), Vector3(x, 0.057, -0.525), "park")                                       # front ears
	front_blade(-0.525, 0.046, 0.068, "park")
	rear_aperture(0.055, 0.0705, 0.055, "park", 0.003, 0.0075)
	var bolt: Node3D = group("Bolt", Vector3(0.022, 0.038, -0.04))
	box(Vector3(0.012, 0.01, 0.02), Vector3.ZERO, "park", Vector3.ZERO, bolt)
	tube(0.004, 0.004, 0.14, Vector3(-0.006, 0, -0.07), "park", "z", bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.015, -0.03))
	prof(P([[0.026, 0.0], [-0.026, 0.0], [-0.034, -0.085], [0.018, -0.088]]), 0.02, "park", 0.0, mag)
	trigger_group(0.04, 0.0, "park")
	marker("Muzzle", Vector3(0, 0.038, -0.55))
	rhand(Vector3(0, -0.022, 0.075), 36.0, 0.019)
	lhand(Vector3(0, 0.012, -0.22), "z", 0.024)
	meta("mag", 0.9)
	root.set_meta("port", Vector3(0.017, 0.045, -0.02))
	root.set_meta("bore", 0.004)


func _w_mp40() -> void:
	tube(0.02, 0.02, 0.28, Vector3(0, 0.03, -0.06), "blued")
	for i: int in 5:
		box(Vector3(0.042, 0.004, 0.01), Vector3(0, 0.03, -0.17 + i * 0.012), "blued")                           # receiver ribs
	prof(P([[0.07, 0.012], [-0.17, 0.012], [-0.17, -0.02], [-0.08, -0.02], [0.03, -0.012], [0.07, -0.004]]), 0.03, "bakelite")
	tube(0.0105, 0.0105, 0.18, Vector3(0, 0.03, -0.29), "blued")
	prof(P([[-0.33, 0.026], [-0.36, 0.026], [-0.37, -0.012], [-0.34, -0.012]]), 0.014, "blued")              # resting bar
	front_post(-0.385, 0.04, 0.061, "blued", true, 0.0095)                                                  # hooded front sight
	prof(P([[0.02, 0.048], [0.05, 0.048], [0.05, 0.052], [0.025, 0.052]]), 0.018, "blued")                    # rear sight base
	rear_notch(0.035, 0.051, 0.011, "blued", 0.016, 0.0045)
	prof(P([[-0.105, 0.015], [-0.16, 0.015], [-0.16, -0.06], [-0.105, -0.06]]), 0.034, "blued")             # mag housing
	grip(0.035, -0.005, 0.1, "bakelite", 20.0, 0.042, 0.032)
	# folding stock, extended
	for x: float in [-0.017, 0.017]:
		tube(0.0042, 0.0042, 0.25, Vector3(x, 0.018, 0.2), "blued")
	prof(P([[0.32, 0.03], [0.335, 0.03], [0.335, -0.06], [0.32, -0.05]]), 0.04, "blued")
	trigger_group(0.0, 0.0)
	var bolt: Node3D = group("Bolt", Vector3(-0.026, 0.035, -0.04))
	tube(0.006, 0.006, 0.02, Vector3(-0.004, 0, 0), "steel", "x", bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.06, -0.132))
	prof(P([[0.017, 0.0], [-0.017, 0.0], [-0.017, -0.24], [0.017, -0.24]]), 0.022, "blued", 0.0, mag)
	box(Vector3(0.026, 0.008, 0.038), Vector3(0, -0.244, 0.0), "blued", Vector3.ZERO, mag)
	marker("Muzzle", Vector3(0, 0.03, -0.39))
	lhand(Vector3(0, -0.06, -0.132), "y", 0.02)
	meta("mag", 0.63)
	root.set_meta("port", Vector3(0.02, 0.035, -0.08))
	root.set_meta("bore", 0.0055)


func _w_thompson() -> void:
	prof(P([[0.1, 0.04], [-0.17, 0.04], [-0.17, 0.0], [0.1, 0.0]]), 0.042, "park")                            # receiver
	prof(P([[0.1, 0.052], [0.088, 0.06], [-0.1, 0.06], [-0.12, 0.04], [0.1, 0.04]]), 0.036, "park")           # top
	prof(P([[0.06, 0.0], [-0.12, 0.0], [-0.12, -0.02], [0.06, -0.02]]), 0.034, "park")                         # trigger frame
	tube(0.012, 0.012, 0.3, Vector3(0, 0.03, -0.32), "park")
	for i: int in 9:
		tube(0.019, 0.019, 0.005, Vector3(0, 0.03, -0.19 - i * 0.016), "park")                                  # cooling fins
	tube(0.016, 0.015, 0.055, Vector3(0, 0.03, -0.49), "park")                                                 # compensator
	# Sights (T-047): a broad blade on the compensator and an M1A1-style fixed peep with tall ears, set high
	# enough that the line clears the receiver top. The peep is opened up (a game sight picture: the blurry
	# ring frames the blade, the blade tip sits in its center); the cocking knob rides on the right side.
	box(Vector3(0.012, 0.006, 0.02), Vector3(0, 0.048, -0.485), "park")                                      # blade base
	front_blade(-0.485, 0.046, 0.073, "park", 0.007, 0.006)
	rear_aperture(0.075, 0.078, 0.06, "park", 0.0074, 0.0098, false)
	for s: float in [-1.0, 1.0]:                                                                               # protective ears
		prof(P([[0.083, 0.06], [0.064, 0.06], [0.07, 0.079], [0.079, 0.079]]), 0.0028, "park", s * 0.0128)
	box(Vector3(0.002, 0.004, 0.13), Vector3(0.0212, 0.048, -0.03), "black")                                  # knob slot (right)
	prof(P([[0.1, 0.035], [0.37, 0.022], [0.38, -0.115], [0.33, -0.118], [0.1, -0.03]]), 0.04, "wood")        # butt
	box(Vector3(0.042, 0.135, 0.01), Vector3(0, -0.047, 0.383), "park")
	grip(0.04, -0.015, 0.1, "wood", 18.0, 0.042, 0.032)
	tube(0.017, 0.019, 0.1, Vector3(0, -0.04, -0.26), "wood", "y")                                            # vertical foregrip
	trigger_group(0.02, 0.0, "park")
	var bolt: Node3D = group("Bolt", Vector3(0.025, 0.048, -0.02))
	tube(0.0035, 0.0035, 0.008, Vector3(-0.002, 0, 0), "park", "x", bolt)
	ball(0.0065, Vector3(0.006, 0, 0), "park", Vector3.ONE, bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.02, -0.09))
	prof(P([[0.02, 0.0], [-0.02, 0.0], [-0.02, -0.2], [0.02, -0.2]]), 0.025, "park", 0.0, mag)
	marker("Muzzle", Vector3(0, 0.03, -0.52))
	lhand(Vector3(0, -0.05, -0.26), "y", 0.019)
	meta("mag", 0.81)
	root.set_meta("port", Vector3(0.021, 0.045, -0.04))
	root.set_meta("bore", 0.0065)


func _w_stg44() -> void:
	prof(P([[0.11, 0.06], [-0.25, 0.06], [-0.26, 0.045], [-0.26, 0.0], [0.11, 0.0]]), 0.036, "fieldgray")    # receiver
	prof(P([[0.0, 0.0], [-0.11, 0.0], [-0.11, -0.03], [-0.02, -0.03]]), 0.032, "fieldgray")                    # trigger housing
	tube(0.0095, 0.012, 0.26, Vector3(0, 0.03, -0.38), "blued")
	tube(0.013, 0.013, 0.22, Vector3(0, 0.056, -0.3), "fieldgray")                                            # gas tube
	prof(P([[-0.16, 0.022], [-0.3, 0.022], [-0.3, 0.05], [-0.16, 0.05]]), 0.034, "fieldgray")                  # handguard
	front_post(-0.492, 0.045, 0.073, "blued", true, 0.0105)                                                   # hooded front sight
	prof(P([[-0.095, 0.06], [-0.15, 0.06], [-0.15, 0.064], [-0.095, 0.066]]), 0.02, "blued")                  # tangent leaf base
	rear_notch(-0.1, 0.064, 0.0105, "blued", 0.018, 0.0045)
	prof(P([[0.11, 0.04], [0.37, 0.02], [0.38, -0.115], [0.33, -0.12], [0.11, -0.01]]), 0.04, "wood_light")   # butt
	box(Vector3(0.042, 0.14, 0.01), Vector3(0, -0.05, 0.383), "blued")
	grip(0.035, -0.015, 0.1, "wood_light", 18.0, 0.042, 0.03)
	trigger_group(0.0, 0.0, "fieldgray")
	var bolt: Node3D = group("Bolt", Vector3(-0.022, 0.04, -0.05))
	tube(0.006, 0.006, 0.02, Vector3(-0.005, 0, 0), "steel", "x", bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.02, -0.12))
	prof(P([[0.018, 0.0], [-0.022, 0.0], [-0.04, -0.09], [-0.08, -0.19], [-0.04, -0.205], [-0.005, -0.1]]), 0.022, "fieldgray", 0.0, mag)
	marker("Muzzle", Vector3(0, 0.03, -0.51))
	lhand(Vector3(0, 0.034, -0.24), "z", 0.02)
	meta("mag", 0.94)
	root.set_meta("port", Vector3(0.018, 0.04, -0.05))
	root.set_meta("bore", 0.0045)


func _w_trench_gun() -> void:
	prof(P([[0.08, 0.02], [0.4, -0.01], [0.41, -0.14], [0.36, -0.145], [0.12, -0.05], [0.07, -0.03]]), 0.042, "wood")   # stock
	box(Vector3(0.044, 0.135, 0.01), Vector3(0, -0.075, 0.405), "blued", Vector3(-8, 0, 0))
	prof(P([[0.09, 0.06], [-0.13, 0.06], [-0.13, -0.005], [-0.04, -0.03], [0.09, -0.02]]), 0.044, "blued")       # receiver
	prof(P([[0.05, 0.057], [0.085, 0.062], [0.09, 0.059], [0.066, 0.053]]), 0.012, "blued")                     # exposed hammer (cocked, under the sight line)
	box(Vector3(0.002, 0.03, 0.06), Vector3(0.0225, 0.035, -0.05), "black")                                      # ejection port
	tube(0.0125, 0.0125, 0.52, Vector3(0, 0.042, -0.39), "blued")
	tube(0.011, 0.011, 0.46, Vector3(0, 0.012, -0.36), "blued")                                                   # mag tube
	tube(0.0185, 0.0185, 0.38, Vector3(0, 0.044, -0.36), "perforated")                                           # heat shield
	for z: float in [-0.17, -0.55]:
		tube(0.02, 0.02, 0.012, Vector3(0, 0.043, z), "blued")
	rear_groove(0.0, 0.06, 0.07, "blued", 0.008)                                                                  # matted groove on the receiver
	box(Vector3(0.006, 0.009, 0.012), Vector3(0, 0.0585, -0.635), "blued")                                        # bead stud
	prof(P([[-0.6, 0.03], [-0.65, 0.03], [-0.65, -0.005], [-0.6, -0.005]]), 0.016, "blued")                     # bayonet lug
	front_bead(Vector3(0, 0.0655, -0.635), 0.004, "brass")
	trigger_group(0.03, 0.0)
	var pump: Node3D = group("Pump", Vector3(0, 0.012, -0.27))
	tube(0.022, 0.022, 0.15, Vector3.ZERO, "wood", "z", pump)
	for i: int in 7:
		tube(0.0224, 0.0224, 0.003, Vector3(0, 0, -0.06 + i * 0.02), "wood_red", "z", pump)
	marker("Mag", Vector3(0, -0.01, -0.03))
	marker("Muzzle", Vector3(0, 0.042, -0.65))
	rhand(Vector3(0, -0.012, 0.1), 36.0, 0.02)
	lhand(Vector3(0, 0.012, -0.27), "z", 0.024)
	meta("shell", 1.0)
	root.set_meta("port", Vector3(0.022, 0.035, -0.05))
	root.set_meta("bore", 0.0095)


func _w_sawed_off() -> void:
	prof(P([[0.05, 0.02], [0.2, -0.02], [0.2, -0.11], [0.16, -0.115], [0.07, -0.04]]), 0.04, "wood")             # sawn stock / grip
	prof(P([[0.06, 0.05], [-0.05, 0.05], [-0.05, -0.005], [0.06, -0.015]]), 0.046, "blued")                      # action
	for x: float in [-0.008, 0.008]:
		prof(P([[0.03, 0.05], [0.045, 0.072], [0.055, 0.068], [0.045, 0.048]]), 0.006, "blued", x)               # hammers
	trigger_group(0.02, 0.0)
	var br: Node3D = group("Barrels", Vector3(0, 0.02, -0.05))
	for x: float in [-0.0115, 0.0115]:
		tube(0.0115, 0.0115, 0.32, Vector3(x, 0.012, -0.16), "blued", "z", br)
	box(Vector3(0.006, 0.006, 0.31), Vector3(0, 0.027, -0.16), "blued", Vector3.ZERO, br)
	prof(P([[0.0, 0.0], [-0.17, 0.0], [-0.18, -0.02], [0.0, -0.03]]), 0.036, "wood", 0.0, br)                   # forend
	front_bead(Vector3(0, 0.0325, -0.305), 0.0028, "brass", br)                                                    # bead on the rib
	rear_groove(0.03, 0.05, 0.05, "blued", 0.002)                                                                  # groove on the action top
	marker("Muzzle", Vector3(0, 0.032, -0.37))
	rhand(Vector3(0, -0.012, 0.085), 32.0, 0.02)
	lhand(Vector3(0, 0.016, -0.14), "z", 0.026)
	meta("break", 0.52)


func _w_bar() -> void:
	prof(P([[0.12, 0.03], [0.4, 0.0], [0.41, -0.14], [0.35, -0.145], [0.12, -0.04]]), 0.042, "wood")
	box(Vector3(0.044, 0.15, 0.01), Vector3(0, -0.07, 0.408), "park")
	grip(0.06, -0.02, 0.1, "wood", 20.0, 0.042, 0.032)
	prof(P([[0.12, 0.055], [-0.22, 0.055], [-0.22, -0.02], [0.12, -0.02]]), 0.046, "park")                       # receiver
	prof(P([[-0.22, 0.03], [-0.42, 0.03], [-0.42, -0.005], [-0.22, -0.01]]), 0.042, "wood")                       # handguard
	tube(0.0125, 0.0145, 0.42, Vector3(0, 0.04, -0.52), "park")
	tube(0.009, 0.009, 0.36, Vector3(0, 0.008, -0.5), "park")
	tube(0.02, 0.013, 0.06, Vector3(0, 0.04, -0.75), "park")
	for s: float in [-1.0, 1.0]:                                                                                   # bipod, folded
		tube(0.0045, 0.0045, 0.3, Vector3(s * 0.016, 0.016, -0.56), "park", "z")
		ball(0.0065, Vector3(s * 0.016, 0.016, -0.41), "park")
	box(Vector3(0.045, 0.014, 0.022), Vector3(0, 0.028, -0.71), "park")                                         # bipod clamp
	rear_aperture(0.0, 0.082, 0.055, "park", 0.0034, 0.0085)                                  # rear peep on its tower
	front_post(-0.755, 0.05, 0.079, "park", true, 0.011)
	trigger_group(0.06, 0.0, "park")
	var bolt: Node3D = group("Bolt", Vector3(-0.026, 0.02, -0.12))
	box(Vector3(0.014, 0.014, 0.02), Vector3.ZERO, "park", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.02, -0.06))
	prof(P([[0.035, 0.0], [-0.035, 0.0], [-0.035, -0.12], [0.035, -0.12]]), 0.032, "park", 0.0, mag)
	marker("Muzzle", Vector3(0, 0.04, -0.78))
	lhand(Vector3(0, 0.014, -0.32), "z", 0.026)
	meta("mag", 1.21)
	root.set_meta("port", Vector3(0.024, 0.03, -0.06))
	root.set_meta("bore", 0.0055)


func _w_ppsh41() -> void:
	prof(P([[0.06, 0.03], [0.4, 0.0], [0.41, -0.125], [0.35, -0.13], [0.13, -0.075], [0.08, -0.09], [0.03, -0.05], [-0.12, -0.035], [-0.12, 0.02]]), 0.044, "wood_red")
	box(Vector3(0.046, 0.13, 0.01), Vector3(0, -0.062, 0.405), "blued")
	prof(P([[0.08, 0.06], [-0.12, 0.06], [-0.12, 0.02], [0.08, 0.02]]), 0.046, "blued")                          # receiver
	tube(0.022, 0.022, 0.26, Vector3(0, 0.038, -0.25), "perforated")
	prof(P([[-0.38, 0.06], [-0.42, 0.045], [-0.42, 0.015], [-0.38, 0.015]]), 0.04, "blued")                     # slanted compensator
	front_post(-0.395, 0.058, 0.074, "blued", true, 0.0095)
	rear_notch(0.055, 0.06, 0.0115, "blued", 0.018, 0.0045)
	trigger_group(0.02, 0.01)
	var bolt: Node3D = group("Bolt", Vector3(0.026, 0.04, -0.03))
	tube(0.006, 0.006, 0.02, Vector3(0.005, 0, 0), "steel", "x", bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.075, -0.09))
	tube(0.075, 0.075, 0.05, Vector3.ZERO, "blued", "x", mag, 28)
	ring(0.07, 0.077, Vector3(0.026, 0, 0), "steel", "x", mag)
	tube(0.02, 0.02, 0.055, Vector3.ZERO, "black", "x", mag)
	box(Vector3(0.03, 0.04, 0.04), Vector3(0, 0.07, 0.0), "blued", Vector3.ZERO, mag)
	marker("Muzzle", Vector3(0, 0.038, -0.42))
	rhand(Vector3(0, -0.03, 0.08), 36.0, 0.021)
	lhand(Vector3(0, 0.02, -0.23), "z", 0.024)            # low on the jacket: the fingers stay under the sight line
	meta("drum", 0.84)
	root.set_meta("port", Vector3(0.023, 0.05, -0.04))
	root.set_meta("bore", 0.0055)


func _w_type100() -> void:
	prof(P([[0.04, 0.025], [0.38, 0.0], [0.39, -0.12], [0.33, -0.125], [0.1, -0.06], [0.04, -0.07], [-0.02, -0.035], [-0.2, -0.03], [-0.21, 0.015]]), 0.042, "wood")
	box(Vector3(0.044, 0.13, 0.01), Vector3(0, -0.06, 0.386), "blued")
	tube(0.018, 0.018, 0.2, Vector3(0, 0.032, -0.04), "blued")
	tube(0.017, 0.017, 0.2, Vector3(0, 0.032, -0.24), "perforated")
	tube(0.01, 0.01, 0.06, Vector3(0, 0.032, -0.37), "blued")
	prof(P([[-0.31, 0.012], [-0.36, 0.012], [-0.36, -0.02], [-0.31, -0.02]]), 0.012, "steel")
	front_post(-0.37, 0.045, 0.066, "blued", false)
	for x: float in [-0.0085, 0.0085]:
		box(Vector3(0.003, 0.018, 0.012), Vector3(x, 0.058, -0.37), "blued")                                        # front guards
	rear_notch(0.01, 0.05, 0.016, "blued", 0.018, 0.0045)
	trigger_group(0.03, -0.005)
	var bolt: Node3D = group("Bolt", Vector3(0.022, 0.035, 0.0))
	box(Vector3(0.012, 0.01, 0.014), Vector3.ZERO, "steel", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(-0.03, 0.03, -0.1))
	box(Vector3(0.17, 0.022, 0.035), Vector3(-0.085, -0.01, 0.0), "blued", Vector3(0, 0, -12), mag)
	marker("Muzzle", Vector3(0, 0.032, -0.4))
	rhand(Vector3(0, -0.025, 0.07), 36.0, 0.02)
	lhand(Vector3(0, 0.006, -0.19), "z", 0.025)
	meta("mag", 0.87)
	root.set_meta("port", Vector3(0.018, 0.04, -0.06))
	root.set_meta("bore", 0.005)


func _w_mg42() -> void:
	prof(P([[0.12, 0.06], [-0.27, 0.06], [-0.27, -0.01], [0.12, -0.01]]), 0.05, "fieldgray")                      # receiver
	var cover: Node3D = group("Cover", Vector3(0, 0.06, 0.08))
	prof(P([[0.0, 0.0], [-0.2, 0.0], [-0.2, 0.022], [-0.02, 0.028]]), 0.052, "fieldgray", 0.0, cover)
	prof(P([[-0.02, 0.022], [-0.07, 0.022], [-0.07, 0.03], [-0.02, 0.03]]), 0.022, "blued", 0.0, cover)     # rear sight base
	tube(0.026, 0.026, 0.38, Vector3(0, 0.038, -0.46), "perforated")
	tube(0.03, 0.022, 0.07, Vector3(0, 0.038, -0.68), "blued")
	prof(P([[-0.58, 0.064], [-0.6, 0.064], [-0.596, 0.088], [-0.586, 0.088]]), 0.012, "blued")                  # front sight standard
	front_post(-0.59, 0.086, 0.101, "blued", false)
	prof(P([[0.12, 0.05], [0.42, 0.01], [0.43, -0.075], [0.37, -0.105], [0.12, -0.03]]), 0.046, "bakelite")      # butt
	grip(0.05, -0.01, 0.1, "bakelite", 22.0, 0.04, 0.032)
	for s: float in [-1.0, 1.0]:
		var leg: MeshInstance3D = tube(0.006, 0.006, 0.3, Vector3(s * 0.03, 0.0, -0.5), "fieldgray")
		leg.rotation_degrees = Vector3(90, s * 3, 0)
		leg.name = "BipodLeg%d" % int(s + 1.0)
	trigger_group(0.02, -0.01, "fieldgray")
	var bolt: Node3D = group("Bolt", Vector3(0.03, 0.025, -0.02))
	box(Vector3(0.02, 0.014, 0.02), Vector3.ZERO, "steel", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(-0.07, -0.05, -0.08))
	tube(0.06, 0.06, 0.07, Vector3(0, -0.02, 0.0), "fieldgray", "x", mag, 20)                                    # belt drum
	for i: int in 6:
		tube(0.005, 0.005, 0.045, Vector3(0.045 + i * 0.005, 0.04 + i * 0.008, 0.0), "brass", "x", mag)
	marker("Muzzle", Vector3(0, 0.038, -0.72))
	lhand(Vector3(0, 0.03, -0.36), "z", 0.03)
	rear_notch(-0.045, 0.09, 0.0125, "blued", 0.02, 0.005)
	meta("belt", 1.22)
	root.set_meta("port", Vector3(0.0, -0.01, -0.04))
	root.set_meta("bore", 0.0065)


func _w_m1919() -> void:
	prof(P([[0.1, 0.065], [-0.22, 0.065], [-0.22, -0.015], [0.1, -0.015]]), 0.06, "park")
	var cover: Node3D = group("Cover", Vector3(0, 0.065, 0.1))
	prof(P([[0.0, 0.0], [-0.17, 0.0], [-0.17, 0.016], [0.0, 0.02]]), 0.06, "park", 0.0, cover)
	tube(0.024, 0.024, 0.4, Vector3(0, 0.035, -0.42), "perforated")
	tube(0.012, 0.016, 0.06, Vector3(0, 0.035, -0.65), "park")
	rear_aperture(0.04, 0.092, 0.065, "park", 0.0034, 0.0085)
	box(Vector3(0.016, 0.026, 0.014), Vector3(0, 0.072, -0.6), "park")                                          # front sight base
	front_post(-0.6, 0.082, 0.09, "park", false)
	prof(P([[0.1, 0.03], [0.32, -0.02], [0.33, -0.1], [0.28, -0.11], [0.1, -0.03]]), 0.04, "wood")
	grip(0.04, -0.015, 0.09, "wood", 20.0, 0.04, 0.03)
	for s: float in [-1.0, 1.0]:                                                                                   # bipod, folded
		tube(0.0045, 0.0045, 0.28, Vector3(s * 0.018, 0.004, -0.46), "park", "z").name = "BipodLeg%d" % int(s + 1.0)
	box(Vector3(0.05, 0.014, 0.022), Vector3(0, 0.012, -0.6), "park")
	trigger_group(0.0, -0.015, "park")
	var bolt: Node3D = group("Bolt", Vector3(0.035, 0.03, 0.0))
	box(Vector3(0.014, 0.014, 0.02), Vector3.ZERO, "steel", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(-0.08, -0.04, -0.06))
	prof(P([[0.09, 0.03], [-0.09, 0.03], [-0.09, -0.08], [0.09, -0.08]]), 0.07, "olive", 0.0, mag)
	box(Vector3(0.006, 0.01, 0.06), Vector3(0.0, 0.04, 0.0), "olive", Vector3.ZERO, mag)
	for i: int in 6:
		tube(0.005, 0.005, 0.045, Vector3(0.045 + i * 0.007, 0.035 + i * 0.008, 0.0), "brass", "x", mag)
	marker("Muzzle", Vector3(0, 0.035, -0.68))
	lhand(Vector3(0, 0.035, -0.3), "z", 0.026)
	meta("belt", 1.0)
	root.set_meta("port", Vector3(0.0, -0.016, -0.03))
	root.set_meta("bore", 0.0055)


func _w_ptrs41() -> void:
	prof(P([[0.1, 0.04], [0.42, 0.0], [0.43, -0.15], [0.36, -0.16], [0.12, -0.05]]), 0.05, "wood")
	box(Vector3(0.056, 0.17, 0.03), Vector3(0, -0.078, 0.44), "rubber")
	grip(0.05, -0.02, 0.1, "wood", 20.0, 0.042, 0.034)
	prof(P([[0.1, 0.06], [-0.3, 0.06], [-0.3, -0.02], [0.1, -0.02]]), 0.05, "blued")
	tube(0.0145, 0.019, 0.85, Vector3(0, 0.035, -0.72), "blued")
	prof(P([[-1.12, 0.06], [-1.2, 0.06], [-1.2, 0.01], [-1.12, 0.01]]), 0.07, "blued")
	for z: float in [-1.14, -1.165, -1.19]:
		box(Vector3(0.075, 0.03, 0.008), Vector3(0, 0.035, z), "black")
	rear_notch(-0.07, 0.06, 0.024, "blued", 0.022, 0.005)
	for s: float in [-1.0, 1.0]:                                                                                   # bipod, folded back
		tube(0.0055, 0.0055, 0.38, Vector3(s * 0.022, 0.012, -0.53), "blued", "z")
		ball(0.008, Vector3(s * 0.022, 0.012, -0.34), "blued")
	box(Vector3(0.06, 0.018, 0.03), Vector3(0, 0.03, -0.72), "blued")
	front_post(-1.0, 0.052, 0.082, "blued", true, 0.012)
	trigger_group(0.06, 0.0)
	var bolt: Node3D = group("Bolt", Vector3(0.03, 0.035, 0.05))
	box(Vector3(0.022, 0.016, 0.022), Vector3.ZERO, "steel", Vector3.ZERO, bolt)
	var mag: Node3D = group("Mag", Vector3(0, -0.02, -0.12))
	prof(P([[0.07, 0.0], [-0.07, 0.0], [-0.07, -0.09], [0.07, -0.09]]), 0.04, "blued", 0.0, mag)
	marker("Muzzle", Vector3(0, 0.035, -1.2))
	lhand(Vector3(0, 0.035, -0.36), "z", 0.022)
	meta("mag", 1.2)
	root.set_meta("port", Vector3(0.026, 0.045, -0.02))
	root.set_meta("bore", 0.0085)


func _w_panzerschreck() -> void:
	tube(0.045, 0.045, 1.5, Vector3(0, 0.07, -0.35), "olive", "z", null, 22)
	ring(0.043, 0.052, Vector3(0, 0.07, 0.4), "olive")
	ring(0.043, 0.052, Vector3(0, 0.07, -1.1), "olive")
	tube(0.05, 0.05, 0.03, Vector3(0, 0.07, -0.6), "olive")
	# Blast shield, about 36 x 46 cm like the real one, just behind the rear sight. The sighting window is
	# cut near its top right, beside the tube, so aiming through it leaves the plate in the lower left of
	# the view; right of the window the plate only rises to the top of the tube.
	var sh: Node3D = group("Shield", Vector3(0, 0, -0.16))
	box(Vector3(0.175, 0.46, 0.004), Vector3(-0.2025, -0.038, 0), "olive", Vector3.ZERO, sh)          # left plate
	box(Vector3(0.08, 0.386, 0.004), Vector3(-0.075, -0.075, 0), "olive", Vector3.ZERO, sh)           # under the window
	box(Vector3(0.09, 0.01, 0.004), Vector3(-0.07, 0.187, 0), "olive", Vector3.ZERO, sh)              # window top bar
	box(Vector3(0.01, 0.074, 0.004), Vector3(-0.03, 0.155, 0), "olive", Vector3.ZERO, sh)             # window right bar
	box(Vector3(0.105, 0.388, 0.004), Vector3(0.0175, -0.074, 0), "olive", Vector3.ZERO, sh)          # right of the window, round the tube
	box(Vector3(0.08, 0.064, 0.002), Vector3(-0.075, 0.15, 0), "glass", Vector3.ZERO, sh)             # window glass
	box(Vector3(0.006, 0.46, 0.02), Vector3(-0.29, -0.038, 0), "olive", Vector3.ZERO, sh)             # rolled edges
	box(Vector3(0.36, 0.006, 0.02), Vector3(-0.11, -0.268, 0), "olive", Vector3.ZERO, sh)
	box(Vector3(0.05, 0.06, 0.12), Vector3(0, 0.005, 0.35), "rubber")
	grip(0.0, 0.025, 0.1, "wood", 10.0, 0.04, 0.03)
	grip(-0.45, 0.025, 0.09, "wood", 0.0, 0.035, 0.03)
	# sights, left of the tube on the sighting line through the window: a notch plate on a post at the rear, a
	# post inside an open frame at the front
	var sg: Node3D = group("Sights", Vector3(-0.075, 0, 0))
	box(Vector3(0.05, 0.004, 0.004), Vector3(0, 0.168, -0.75), "olive", Vector3.ZERO, sg)                      # front sight frame
	for sx: float in [-0.023, 0.023]:
		box(Vector3(0.004, 0.05, 0.004), Vector3(sx, 0.145, -0.75), "olive", Vector3.ZERO, sg)
	box(Vector3(0.05, 0.004, 0.004), Vector3(0, 0.12, -0.75), "olive", Vector3.ZERO, sg)
	front_blade(-0.75, 0.12, 0.1528, "olive", 0.004, 0.004, sg)
	box(Vector3(0.004, 0.072, 0.004), Vector3(0, 0.106, -0.2), "olive", Vector3.ZERO, sg)                      # rear sight post (seen through the window)
	rear_notch(-0.2, 0.142, 0.012, "olive", 0.024, 0.006, sg)
	trigger_group(0.02, 0.025, "olive")
	var rocket: Node3D = group("Rocket", Vector3(0, 0.07, 0.62))
	tube(0.04, 0.04, 0.25, Vector3(0, 0, 0), "fieldgray", "z", rocket)
	tube(0.0, 0.04, 0.12, Vector3(0, 0, -0.18), "fieldgray", "z", rocket)
	rocket.hide()
	marker("Muzzle", Vector3(0, 0.07, -1.12))
	lhand(Vector3(0, -0.017, -0.45), "y", 0.017)
	meta("rocket", 1.5)


func _w_flamethrower() -> void:
	tube(0.016, 0.016, 0.6, Vector3(0, 0.03, -0.2), "olive")
	tube(0.022, 0.016, 0.06, Vector3(0, 0.03, -0.53), "black")
	box(Vector3(0.03, 0.03, 0.05), Vector3(0, 0.055, -0.5), "black")
	front_post(-0.5, 0.07, 0.0768, "black", false)                                                              # aiming post on the nozzle
	rear_notch(0.0, 0.046, 0.032, "olive", 0.018, 0.005)                                                       # notch plate over the valve
	ball(0.012, Vector3(0, 0.03, -0.565), "glow_amber")
	grip(0.02, 0.015, 0.09, "wood", 15.0, 0.04, 0.03)
	grip(-0.32, 0.015, 0.09, "wood", 0.0, 0.035, 0.03)
	var valve: Node3D = group("Valve", Vector3(0, 0.03, 0.1))
	tube(0.02, 0.02, 0.03, Vector3.ZERO, "brass", "z", valve)
	box(Vector3(0.05, 0.008, 0.008), Vector3(0, 0, 0.01), "brass", Vector3.ZERO, valve)
	tube(0.01, 0.01, 0.5, Vector3(0.03, -0.1, 0.25), "rubber").rotation_degrees = Vector3(120, 0, 0)
	marker("Mag", Vector3(0, 0.03, 0.1))
	marker("Muzzle", Vector3(0, 0.03, -0.58))
	lhand(Vector3(0, -0.027, -0.32), "y", 0.017)
	meta("fuel", 0.6)


func _w_ashlight() -> void:
	prof(P([[0.05, 0.05], [-0.13, 0.05], [-0.13, 0.012], [0.05, 0.005]]), 0.034, "brass")
	tube(0.013, 0.013, 0.16, Vector3(0, 0.035, -0.2), "brass")
	for i: int in 4:
		ring(0.012, 0.02, Vector3(0, 0.035, -0.14 - i * 0.03), "bronze")
	tube(0.019, 0.019, 0.07, Vector3(0, 0.068, -0.03), "glass")
	tube(0.032, 0.022, 0.03, Vector3(0, 0.035, -0.29), "bronze")
	front_post(-0.282, 0.062, 0.0958, "bronze", true, 0.008)                                                   # post over the emitter bell
	rear_notch(0.03, 0.05, 0.047, "brass", 0.018, 0.005)                                                       # notch leaf behind the capsule
	grip(0.035, 0.005, 0.1, "wood", 18.0, 0.042, 0.032)
	trigger_group(-0.01, 0.01, "brass")
	var mag: Node3D = group("Mag", Vector3(0, 0.068, -0.03))
	tube(0.011, 0.011, 0.05, Vector3.ZERO, "glow_violet", "z", mag)
	marker("Muzzle", Vector3(0, 0.035, -0.31))
	lhand(Vector3(-0.006, -0.042, 0.052), "y", 0.03)
	meta("capsule", 0.32)


func _w_totenglocke() -> void:
	var bell: Node3D = group("Bell", Vector3.ZERO)                                                                # vibrates after a toll (T-048)
	tube(0.135, 0.07, 0.22, Vector3(0, 0.06, -0.34), "bronze", "z", bell, 24)                                    # bell, mouth forward
	ring(0.125, 0.145, Vector3(0, 0.06, -0.45), "bronze", "z", bell)
	tube(0.03, 0.03, 0.08, Vector3(0, 0.06, -0.2), "bronze", "z", bell)
	prof(P([[0.1, 0.0], [-0.22, 0.0], [-0.22, 0.04], [0.1, 0.04]]), 0.05, "wood")
	box(Vector3(0.3, 0.03, 0.03), Vector3(0, 0.17, -0.3), "blued")
	box(Vector3(0.03, 0.12, 0.03), Vector3(-0.14, 0.11, -0.3), "blued")
	box(Vector3(0.03, 0.12, 0.03), Vector3(0.14, 0.11, -0.3), "blued")
	rear_notch(-0.29, 0.185, 0.03, "blued", 0.03, 0.008)                                                       # notch on the frame's crossbar
	front_bead(Vector3(0, 0.2095, -0.45), 0.005, "brass")                                                       # bead on the bell rim
	grip(0.04, 0.0, 0.1, "wood", 15.0, 0.042, 0.034)
	grip(-0.2, 0.0, 0.09, "wood", 0.0, 0.035, 0.03)
	var crank: Node3D = group("Crank", Vector3(0.06, 0.02, -0.05))
	box(Vector3(0.012, 0.12, 0.012), Vector3(0, 0.05, 0), "blued", Vector3.ZERO, crank)
	tube(0.01, 0.01, 0.05, Vector3(0.025, 0.11, 0), "wood", "x", crank)
	marker("Muzzle", Vector3(0, 0.06, -0.46))
	lhand(Vector3(0, -0.042, -0.2), "y", 0.017)
	meta("bell", 0.5)


## The Lodestone (T-105): a Nachtglas lens in a brass gyro cradle hung under the end of a yoke, carried two-handed
## like a lantern on a pole; the relay coil wound round the yoke behind the front grip. The sight line runs along
## the bar's top (notch at the rear, bead at the bar's tip over the lens), so the lens hangs under the picture.
## Sphere spins, Cradle opens, Coil glows (Lodestone.pose_parts).
func _w_lodestone() -> void:
	var head: Vector3 = Vector3(0, -0.11, -0.34)                                                               # the lens's centre, under the bar's end
	prof(P([[0.1, 0.0], [-0.46, 0.0], [-0.46, 0.035], [0.1, 0.035]]), 0.03, "brass")                                  # the yoke's bar, out over the lens to the bead
	for s: float in [-1.0, 1.0]:                                                                                 # the fork down to the cradle's side pivots
		box(Vector3(0.008, 0.19, 0.01), Vector3(s * 0.066, -0.045, -0.34), "brass", Vector3(0, 0, s * 35.0))
		tube(0.009, 0.009, 0.012, Vector3(s * 0.118, -0.11, -0.34), "brass", "x")
	var cradle: Node3D = group("Cradle", head)                                                                   # the gyro rings (open on a lift)
	ring(0.1, 0.112, Vector3.ZERO, "brass", "z", cradle)
	ring(0.086, 0.096, Vector3.ZERO, "brass", "x", cradle)
	ring(0.072, 0.08, Vector3.ZERO, "brass", "y", cradle)
	var sphere: Node3D = group("Sphere", head)                                                                   # the lead-glass lens
	ball(0.062, Vector3.ZERO, "glass", Vector3.ONE, sphere)
	ball(0.02, Vector3(0.02, 0.015, -0.02), "nachtglas", Vector3.ONE, sphere)
	var coil: Node3D = group("Coil", Vector3(0, 0.02, -0.16))                                                    # the relay coil round the bar (under the sight line)
	for i: int in 7:
		ring(0.022, 0.028, Vector3(0, 0, -0.03 + i * 0.012), "bronze", "z", coil)
	grip(0.04, 0.0, 0.1, "wood", 15.0, 0.042, 0.034)
	grip(-0.2, 0.0, 0.09, "wood", 0.0, 0.035, 0.03)
	var corona: Node3D = group("Corona", head)                                                                   # Escape Velocity's ring (hidden on the base)
	ring(0.066, 0.074, Vector3.ZERO, "nachtglas", "z", corona)
	corona.visible = upgraded
	marker("Muzzle", Vector3(0, -0.11, -0.41))
	rear_notch(-0.02, 0.035, 0.02, "brass", 0.03, 0.008)                                                        # SightPoint (0, 0.0538, -0.024)
	box(Vector3(0.008, 0.014, 0.008), Vector3(0, 0.04, -0.44), "brass")                                          # the bead's post on the bar's tip
	front_bead(Vector3(0, 0.05, -0.44), 0.004, "brass")                                                         # FrontSight (0, 0.0528, -0.44)
	lhand(Vector3(0, -0.042, -0.2), "y", 0.017)
	meta("lodestone", 0.56)


## Sankt-Elmsfeuer: a ship's arc projector rebuilt as a carbine. A copper induction coil in a glass sleeve over
## a brass tube, a navy-grey breech with a crank magneto, a wooden stock with a brass butt plate, twin
## porcelain insulators as "sights", and a violet discharge gap at the muzzle.
func _w_elmsfeuer() -> void:
	prof(P([[0.12, 0.0], [-0.1, 0.0], [-0.16, 0.05], [-0.4, 0.05], [-0.4, 0.015], [-0.2, 0.0], [0.12, 0.0]]), 0.034, "wood")   # stock
	box(Vector3(0.036, 0.055, 0.012), Vector3(0, 0.0, -0.405), "brass")                                                    # butt plate
	box(Vector3(0.05, 0.07, 0.2), Vector3(0, 0.05, -0.1), "navy")                                                           # breech / magneto housing
	box(Vector3(0.052, 0.012, 0.21), Vector3(0, 0.088, -0.1), "brass")
	tube(0.014, 0.014, 0.34, Vector3(0, 0.05, -0.37), "brass")                                                               # bore
	tube(0.03, 0.03, 0.2, Vector3(0, 0.05, -0.3), "glass")                                                                   # coil sleeve
	for i: int in 9:
		ring(0.015, 0.026, Vector3(0, 0.05, -0.215 - i * 0.02), "bronze")                                                     # the coil
	tube(0.034, 0.034, 0.012, Vector3(0, 0.05, -0.2), "brass")
	tube(0.034, 0.034, 0.012, Vector3(0, 0.05, -0.4), "brass")
	for i2: int in 3:
		ring(0.016, 0.022, Vector3(0, 0.05, -0.44 - i2 * 0.02), "copper")                                                     # discharge gap
	tube(0.008, 0.008, 0.08, Vector3(0, 0.05, -0.5), "glow_violet")
	for sx: float in [-0.012, 0.012]:                                                                                        # insulator "sights"
		tube(0.006, 0.006, 0.022, Vector3(sx, 0.106, -0.2), "white", "y")
		tube(0.004, 0.004, 0.01, Vector3(sx, 0.122, -0.2), "copper", "y")
	rear_notch(0.0, 0.094, 0.014, "brass", 0.018, 0.005)                                                       # notch at the breech end
	front_post(-0.4, 0.084, 0.1068, "copper", false)                                                            # post on the muzzle band
	var crank: Node3D = group("Crank", Vector3(0.03, 0.05, -0.12))
	tube(0.006, 0.006, 0.04, Vector3.ZERO, "blued", "x", crank)
	box(Vector3(0.01, 0.045, 0.01), Vector3(0.04, 0.02, 0), "blued", Vector3.ZERO, crank)
	tube(0.007, 0.007, 0.03, Vector3(0.045, 0.045, 0), "wood", "y", crank)
	var dial: Node3D = group("Dial", Vector3(-0.026, 0.07, -0.08))
	tube(0.012, 0.012, 0.004, Vector3.ZERO, "cream", "x", dial)
	trigger_group(-0.02, 0.0, "brass")
	grip(0.045, 0.0, 0.1, "wood", 16.0, 0.042, 0.032)
	marker("Muzzle", Vector3(0, 0.05, -0.54))
	lhand(Vector3(0, -0.012, -0.25), "z", 0.03)
	meta("crank", 0.54)


func _w_gramophone() -> void:
	box(Vector3(0.22, 0.12, 0.22), Vector3(0, 0.0, 0), "wood")
	tube(0.1, 0.1, 0.01, Vector3(0, 0.066, 0), "black", "y")
	tube(0.012, 0.012, 0.012, Vector3(0, 0.075, 0), "brass", "y")
	tube(0.006, 0.006, 0.15, Vector3(0.08, 0.1, 0.02), "brass", "y")
	tube(0.012, 0.12, 0.22, Vector3(0.08, 0.2, -0.08), "brass").rotation_degrees = Vector3(60, 0, 0)
	tube(0.006, 0.006, 0.05, Vector3(0.12, 0.0, 0.0), "brass", "x")
	meta("none", 0.25)


func _w_trench_knife() -> void:
	ring(0.016, 0.024, Vector3(0, -0.01, 0.03), "brass", "x")                                                   # knuckle bow
	for i: int in 4:
		ball(0.006, Vector3(0, -0.035, 0.0 + i * 0.022), "brass")                                                  # knuckle spikes
	tube(0.013, 0.013, 0.1, Vector3(0, 0.0, 0.035), "wood")
	box(Vector3(0.04, 0.012, 0.014), Vector3(0, 0.0, -0.022), "brass")
	prof(P([[-0.025, 0.012], [-0.17, 0.008], [-0.22, 0.0], [-0.17, -0.01], [-0.025, -0.013]]), 0.005, "steel")      # blade
	box(Vector3(0.0055, 0.002, 0.14), Vector3(0, 0.0, -0.1), "blued")                                              # fuller
	ball(0.01, Vector3(0, 0, 0.09), "brass")
	marker("Muzzle", Vector3(0, 0, -0.22))
	meta("none", 0.25)


func _w_etool() -> void:
	tube(0.014, 0.016, 0.46, Vector3(0, 0, -0.12), "wood")
	tube(0.018, 0.018, 0.06, Vector3(0, 0, -0.36), "olive")
	prof(P([[-0.38, 0.075], [-0.52, 0.075], [-0.57, 0.0], [-0.52, -0.075], [-0.38, -0.075]]), 0.004, "olive")     # spade
	prof(P([[-0.52, 0.075], [-0.575, 0.002], [-0.56, 0.002], [-0.51, 0.07]]), 0.0045, "steel")                     # sharpened edge
	marker("Muzzle", Vector3(0, 0, -0.57))
	meta("none", 0.55)


func _w_frag() -> void:
	ball(0.028, Vector3.ZERO, "olive", Vector3(1.0, 1.2, 1.0))
	for i: int in 4:
		ring(0.026, 0.03, Vector3(0, -0.02 + i * 0.014, 0), "olive", "y")
	for j: int in 4:
		var r: MeshInstance3D = ring(0.029, 0.031, Vector3.ZERO, "olive", "x")
		r.rotation_degrees = Vector3(0, j * 45, 90)
	tube(0.01, 0.01, 0.02, Vector3(0, 0.04, 0), "steel", "y")
	box(Vector3(0.01, 0.07, 0.004), Vector3(0.02, 0.02, 0), "steel", Vector3(0, 0, -10))
	ring(0.008, 0.011, Vector3(-0.012, 0.05, 0), "steel", "z")
	meta("none", 0.08)


func _w_generic() -> void:
	prof(P([[0.1, 0.05], [-0.2, 0.05], [-0.2, 0.0], [0.1, 0.0]]), 0.04, "blued")
	tube(0.012, 0.012, 0.4, Vector3(0, 0.03, -0.4), "blued")
	prof(P([[0.1, 0.04], [0.36, 0.01], [0.37, -0.11], [0.3, -0.12], [0.1, -0.03]]), 0.04, "wood")
	grip(0.04, -0.005, 0.09, "wood")
	rear_notch(0.0, 0.05, 0.012)
	front_post(-0.58, 0.042, 0.0608, "blued", false)
	var mag: Node3D = group("Mag", Vector3(0, 0.0, -0.08))
	box(Vector3(0.025, 0.15, 0.04), Vector3(0, -0.075, 0), "blued", Vector3.ZERO, mag)
	meta("mag", 0.6)


## Upgraded weapons: a faint violet light so the veins read in the dark.
func _nachtglas_glow() -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "Nachtglow"                 # WeaponHolder pulses it slowly
	l.light_color = Color(0.6, 0.3, 1.0)
	l.light_energy = 0.3
	l.omni_range = 0.7
	l.position = Vector3(0, 0.05, -0.1)
	l.shadow_enabled = false
	root.add_child(l)


# ================================================================== arms

const HAND_R0: float = 0.018         # default radius of the part a fist closes around
static var _hand_cache: Dictionary = {}
static var _flash_mesh_cache: ArrayMesh = null


## Point on a circle around the fist's grip axis (local Y). theta is measured from the palm side (+X for the
## right hand, -X for the left) toward +Z (back of the grip); negative angles wrap toward the front (-Z).
static func _hp(theta_deg: float, radius: float, y: float, side: float) -> Vector3:
	var t: float = deg_to_rad(theta_deg)
	return Vector3(side * radius * cos(t), y, radius * sin(t))


## Transform that maps a unit primitive along +Y onto the segment a -> b.
static func _seg_xf(a: Vector3, b: Vector3) -> Transform3D:
	var y: Vector3 = (b - a).normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


## A gloved hand closed around a cylinder of `grip_radius` (cached ArrayMesh: surface 0 = vertex-coloured
## leather glove, surface 1 = the wrist-strap buckle; two draw calls per hand).
## Frame: origin = center of the gripped part, grip axis = local +Y (index finger at the top), palm on +X
## for the right hand (-X for the left), fingers wrap around the front (-Z) to the far side, the thumb
## wraps the other way around the back. The wrist is at hand_wrist().
## Sculpt: the back of the hand is one rounded slab bent around the grip, with knuckle bumps and a hint of
## the extensor tendons displaced into it; three rows of "points" stitching and a seam across the back;
## tapered finger segments with joint swellings and rounded tips; a strap with a buckle round the wrist.
static func hand_mesh(left: bool, grip_radius: float = HAND_R0) -> ArrayMesh:
	var r: float = snappedf(clampf(grip_radius, 0.012, 0.04), 0.002)
	var key: String = "%s_%.3f_v2" % ["L" if left else "R", r]
	if _hand_cache.has(key):
		return _hand_cache[key]
	var s: float = -1.0 if left else 1.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rp: float = r + 0.011                     # palm mid-plane radius
	var palm_ang: float = 35.0
	var knuckle_ang: float = palm_ang - rad_to_deg(0.03 / rp)
	var fy: Array = [0.029, 0.0095, -0.0095, -0.028]
	# ---- back of the hand + palm: a rounded slab bent around the grip
	var sh: Dictionary = {"t0": knuckle_ang - 7.0, "t1": palm_ang + 42.0, "y0": -0.041, "y1": 0.038,
		"r0": r + 0.0018, "r1": r + 0.0215, "s": s, "fy": fy, "k_ang": knuckle_ang + 3.0}
	_hand_shell(st, sh)
	# stitching: three rows of "points" from the knuckles toward the wrist, and a seam across the back
	for row: int in 3:
		var yb: float = (float(fy[row]) + float(fy[row + 1])) * 0.5
		var a: float = -0.5
		while a <= 0.42:
			_hand_stitch(st, sh, a, _shell_b(sh, yb), true)
			a += 0.105
	var b2: float = -0.78
	while b2 <= 0.8:
		_hand_stitch(st, sh, 0.66, b2, false)
		b2 += 0.13
	# heel of the palm (under the thumb)
	_taper(st, _hp(palm_ang + 30.0, rp, 0.02, s), _hp(palm_ang + 25.0, rp, -0.03, s), 0.0125, 0.0115, GLOVE_COL)
	_ball(st, _hp(palm_ang + 30.0, rp, 0.02, s), 0.0125, GLOVE_COL)
	# ---- four fingers, three tapered segments each, wrapping around the front
	var lens: Array = [0.025, 0.018, 0.015]
	var fk: Array = [0.97, 1.05, 0.98, 0.8]
	for f: int in 4:
		var fr: float = 0.0089 if f < 3 else 0.0077
		var rad: float = r + fr + 0.001
		var ang: float = knuckle_ang
		var p0: Vector3 = _hp(ang, rad, float(fy[f]), s)
		var r_a: float = fr
		for k: int in 3:
			var l: float = float(lens[k]) * float(fk[f])
			ang -= rad_to_deg(l / rad) * (1.0 if k < 2 else 0.9)
			var p1: Vector3 = _hp(ang, rad - 0.0015 * k, float(fy[f]) - 0.002 * k, s)
			var r_b: float = fr * (0.93 - 0.06 * k)
			_ball(st, p0, r_a + 0.0004, GLOVE_COL)            # knuckle / joint swelling
			if k < 2:
				_taper(st, p0, p1, r_a, r_b, GLOVE_COL)
			else:
				# last segment: ends in a rounded, slightly elongated fingertip
				var d: Vector3 = (p1 - p0).normalized()
				_taper(st, p0, p1 - d * 0.002, r_a, r_b, GLOVE_COL, false)
				_ball(st, p1 - d * 0.002, r_b, GLOVE_COL, d, 1.3)
			p0 = p1
			r_a = r_b
	# ---- thumb: from inside the palm, around the back of the grip to the far side
	var t0: Vector3 = _hp(palm_ang + 5.0, rp - 0.004, -0.01, s)
	var t1: Vector3 = _hp(palm_ang + 55.0, r + 0.012, 0.03, s)
	_taper(st, t0, t1, 0.0118, 0.0102, GLOVE_COL)
	_ball(st, t1, 0.0104, GLOVE_COL)
	var tr: float = r + 0.0095
	var a1: float = palm_ang + 55.0 + rad_to_deg(0.028 / tr)
	var t2: Vector3 = _hp(minf(a1, 175.0), tr, 0.04, s)
	_taper(st, t1, t2, 0.0098, 0.009, GLOVE_COL)
	_ball(st, t2, 0.0093, GLOVE_COL)
	var t3: Vector3 = _hp(minf(a1 + rad_to_deg(0.022 / tr), 205.0), tr - 0.001, 0.043, s)
	var td: Vector3 = (t3 - t2).normalized()
	_taper(st, t2, t3 - td * 0.002, 0.0088, 0.008, GLOVE_COL, false)
	_ball(st, t3 - td * 0.002, 0.008, GLOVE_COL, td, 1.3)
	# ---- wrist stub joining the hand to the forearm cuff, with a strap round it
	var w0: Vector3 = _hp(palm_ang + 15.0, rp, -0.012, s)
	var w1: Vector3 = hand_wrist(left, r)
	_taper(st, w0, w1, 0.0168, 0.0165, GLOVE_COL)
	_ball(st, w0, 0.0168, GLOVE_COL)
	var ax: Vector3 = (w1 - w0).normalized()
	var band_c: Vector3 = w0.lerp(w1, 0.55)
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.0181
	band.bottom_radius = 0.0181
	band.height = 0.0085
	band.radial_segments = 16
	band.rings = 1
	_put(st, band, Transform3D(_seg_xf(w0, w1).basis, band_c), STRAP_COL)
	var out: Vector3 = Vector3(s * cos(deg_to_rad(56.0)), 0.0, sin(deg_to_rad(56.0)))
	out = (out - ax * out.dot(ax)).normalized()
	var side: Vector3 = ax.cross(out).normalized()
	var buckle_c: Vector3 = band_c + out * 0.0185
	# strap tail running on past the buckle
	_box(st, buckle_c + side * 0.009 - out * 0.0002, Vector3(0.012, 0.0014, 0.0075), side, out, STRAP_COL)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, base_mat("glove_vc"))
	# buckle: an open frame and its tongue, blackened steel (second surface)
	var sb: SurfaceTool = SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fw: float = 0.0105                         # frame width (across the strap)
	var fl: float = 0.0125                         # frame length (along the arm; wider than the 8.5 mm strap)
	var bt: float = 0.0016                         # bar thickness
	var bh: float = 0.0017                         # bar height off the strap
	for sg: float in [-1.0, 1.0]:
		_box(sb, buckle_c + ax * sg * (fl - bt) * 0.5, Vector3(fw, bh, bt), side, out, Color.WHITE)
		_box(sb, buckle_c + side * sg * (fw - bt) * 0.5, Vector3(bt, bh, fl), side, out, Color.WHITE)
	_box(sb, buckle_c + side * 0.0012 + out * 0.0004, Vector3(fw * 0.62, 0.0011, 0.0011), side, out, Color.WHITE)   # tongue
	sb.commit(mesh)
	mesh.surface_set_material(1, base_mat("buckle"))
	_hand_cache[key] = mesh
	return mesh


const GLOVE_COL: Color = Color(0.19, 0.13, 0.085)
const STRAP_COL: Color = Color(0.11, 0.072, 0.045)
const THREAD_COL: Color = Color(0.36, 0.29, 0.2)


## Shell footprint coordinate B (-1..1 along the grip) for a height y.
static func _shell_b(sh: Dictionary, y: float) -> float:
	return (y - (float(sh["y0"]) + float(sh["y1"])) * 0.5) / ((float(sh["y1"]) - float(sh["y0"])) * 0.5)


## A point on the hand shell. (a, b) in the rounded-rectangle footprint (a: across the back, -1 = knuckles,
## +1 = wrist side; b: along the grip); top = the outer face (back of the hand), else the inner (palm) face.
static func _shell_pt(sh: Dictionary, a: float, b: float, top: bool) -> Vector3:
	var n4: float = clampf(pow(pow(absf(a), 4.0) + pow(absf(b), 4.0), 0.25), 0.0, 1.0)
	var c: float = pow(maxf(0.0, 1.0 - n4 * n4 * n4), 1.0 / 3.0) * (1.0 if top else -1.0)
	var t0: float = float(sh["t0"])
	var t1: float = float(sh["t1"])
	var theta: float = (t0 + t1) * 0.5 + a * (t1 - t0) * 0.5
	var y0: float = float(sh["y0"])
	var y1: float = float(sh["y1"])
	var y: float = (y0 + y1) * 0.5 + b * (y1 - y0) * 0.5
	var r0: float = float(sh["r0"])
	var r1: float = float(sh["r1"])
	var rad: float = (r0 + r1) * 0.5 + c * (r1 - r0) * 0.5
	if top:
		var lift: float = smoothstep(0.0, 0.55, c)
		var d: float = 0.0012 * (1.0 - b * b)                      # the back of the hand arches a little
		var k_ang: float = float(sh["k_ang"])
		var a_k: float = (k_ang - (t0 + t1) * 0.5) / ((t1 - t0) * 0.5)
		var fk: Array = [0.85, 1.0, 0.95, 0.75]
		var fys: Array = sh["fy"]
		for f: int in 4:
			var fyv: float = float(fys[f])
			# knuckle (MCP joint) bump at the front edge
			var dk: float = (theta - k_ang) / 9.0
			var dy: float = (y - fyv) / 0.0068
			d += 0.0034 * float(fk[f]) * exp(-dk * dk - dy * dy)
			# extensor tendon: a faint ridge fanning in from each knuckle toward the wrist
			var along: float = clampf((a - a_k) / (0.75 - a_k), 0.0, 1.0)
			var ty: float = (y - lerpf(fyv, fyv * 0.4, along)) / 0.0027
			d += 0.0008 * exp(-ty * ty) * smoothstep(0.0, 0.15, along) * (1.0 - smoothstep(0.55, 1.0, along))
		rad += d * lift
	return _hp(theta, rad, y, float(sh["s"]))


## Outward normal of the shell at (a, b) by central differences, oriented away from the slab's middle.
static func _shell_n(sh: Dictionary, a: float, b: float, top: bool) -> Vector3:
	var e: float = 0.004
	var p: Vector3 = _shell_pt(sh, a, b, top)
	var da: Vector3 = _shell_pt(sh, a + e, b, top) - _shell_pt(sh, a - e, b, top)
	var db: Vector3 = _shell_pt(sh, a, b + e, top) - _shell_pt(sh, a, b - e, top)
	var n: Vector3 = da.cross(db)
	var mid: Vector3 = _hp((float(sh["t0"]) + float(sh["t1"])) * 0.5, (float(sh["r0"]) + float(sh["r1"])) * 0.5,
		(float(sh["y0"]) + float(sh["y1"])) * 0.5, float(sh["s"]))
	if n.length_squared() < 1e-14:
		n = p - mid
	n = n.normalized()
	if n.dot(p - mid) < 0.0:
		n = -n
	return n


static func _hand_shell(st: SurfaceTool, sh: Dictionary) -> void:
	var na: int = 19
	var nb: int = 17
	for top: bool in [true, false]:
		var pts: Array[Vector3] = []
		var nrm: Array[Vector3] = []
		for i: int in na:
			for j: int in nb:
				# square grid, denser toward the edges, pushed out onto the rounded-rectangle footprint
				var qa: float = sin((float(i) / float(na - 1) * 2.0 - 1.0) * PI * 0.5)
				var qb: float = sin((float(j) / float(nb - 1) * 2.0 - 1.0) * PI * 0.5)
				var rho: float = maxf(absf(qa), absf(qb))
				var a: float = 0.0
				var b: float = 0.0
				if rho > 1e-6:
					var dir: Vector2 = Vector2(qa, qb).normalized()
					var dn: float = pow(pow(absf(dir.x), 4.0) + pow(absf(dir.y), 4.0), 0.25)
					a = dir.x * rho / dn
					b = dir.y * rho / dn
				pts.append(_shell_pt(sh, a, b, top))
				nrm.append(_shell_n(sh, a, b, top))
		for i: int in na - 1:
			for j: int in nb - 1:
				var i00: int = i * nb + j
				var i10: int = (i + 1) * nb + j
				var i11: int = (i + 1) * nb + j + 1
				var i01: int = i * nb + j + 1
				_tri(st, pts[i00], pts[i10], pts[i11], nrm[i00], nrm[i10], nrm[i11], GLOVE_COL)
				_tri(st, pts[i00], pts[i11], pts[i01], nrm[i00], nrm[i11], nrm[i01], GLOVE_COL)


## One stitch (a short raised thread) lying on the back of the hand at (a, b). along_a: the stitch runs
## across the back (knuckles -> wrist), otherwise along the grip.
static func _hand_stitch(st: SurfaceTool, sh: Dictionary, a: float, b: float, along_a: bool) -> void:
	var p: Vector3 = _shell_pt(sh, a, b, true)
	var n: Vector3 = _shell_n(sh, a, b, true)
	var dir: Vector3 = (_shell_pt(sh, a + 0.01, b, true) - _shell_pt(sh, a - 0.01, b, true)) if along_a \
		else (_shell_pt(sh, a, b + 0.01, true) - _shell_pt(sh, a, b - 0.01, true))
	dir = (dir - n * dir.dot(n)).normalized()
	_box(st, p + n * 0.0002, Vector3(0.0012, 0.0009, 0.0034), n.cross(dir).normalized(), n, THREAD_COL)


## Emits one triangle wound so its front face is on the side the normals point to (works for mirrored
## geometry too: Godot treats clockwise as front-facing).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tv: Vector3 = b
		b = c
		c = tv
		var tn: Vector3 = nb
		nb = nc
		nc = tn
	st.set_color(col)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(nc)
	st.add_vertex(c)


## Appends a primitive mesh, transformed (normals by the inverse transpose), in one vertex colour.
static func _put(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr: Array = prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nv: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb: Basis = xf.basis.inverse().transposed()
	for i: int in range(0, idx.size(), 3):
		var i0: int = idx[i]
		var i1: int = idx[i + 1]
		var i2: int = idx[i + 2]
		_tri(st, xf * v[i0], xf * v[i1], xf * v[i2], (nb * nv[i0]).normalized(), (nb * nv[i1]).normalized(), (nb * nv[i2]).normalized(), col)


## Tapered limb segment a -> b (radius ra at a, rb at b), open-ended; `cap` puts a ball on the b end.
static func _taper(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, cap: bool = true) -> void:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.bottom_radius = ra
	cm.top_radius = rb
	cm.height = maxf(0.0005, a.distance_to(b))
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_put(st, cm, _seg_xf(a, b), col)
	if cap:
		_ball(st, b, rb, col)


## A sphere (optionally stretched by `stretch` along `axis`, for fingertips).
static func _ball(st: SurfaceTool, c: Vector3, rad: float, col: Color, axis: Vector3 = Vector3.ZERO, stretch: float = 1.0) -> void:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	var xf: Transform3D = Transform3D(Basis(), c)
	if axis != Vector3.ZERO:
		var sx: Transform3D = _seg_xf(c, c + axis)
		xf = Transform3D(sx.basis * Basis.from_scale(Vector3(1.0, stretch, 1.0)), c)
	_put(st, sm, xf, col)


## A box centered at `c`: size.x along `x_dir`, size.y along `y_dir`, size.z along their cross product.
static func _box(st: SurfaceTool, c: Vector3, size: Vector3, x_dir: Vector3, y_dir: Vector3, col: Color) -> void:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var x: Vector3 = x_dir.normalized()
	var y: Vector3 = (y_dir - x * y_dir.dot(x)).normalized()
	_put(st, bm, Transform3D(Basis(x, y, x.cross(y)), c), col)


## The wrist point in a hand's frame (see hand_mesh); the forearm leaves the hand here.
static func hand_wrist(left: bool, grip_radius: float = HAND_R0) -> Vector3:
	var s: float = -1.0 if left else 1.0
	return _hp(62.0, grip_radius + 0.02, -0.03, s) + Vector3(0, 0, 0.035)


## A hand node (one MeshInstance3D child named "Mesh"). Swap the mesh with hand_mesh() to refit the grip.
static func build_hand(left: bool, grip_radius: float = HAND_R0) -> Node3D:
	var root_n: Node3D = Node3D.new()
	root_n.name = "HandL" if left else "HandR"
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = hand_mesh(left, grip_radius)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_n.add_child(mi)
	return root_n


## A forearm/upper-arm segment: a sleeve tube from `a` to `b` (positions set each frame).
static func build_limb(radius_a: float, radius_b: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius_b
	cm.bottom_radius = radius_a
	cm.height = 1.0
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = base_mat("sleeve")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Length of the forearm piece below the sleeve (wrist -> start of the sleeve limb).
const FOREARM_BARE: float = 0.14


## Glove gauntlet cuff and the wool tunic sleeve running up the forearm (no bare skin anywhere: the
## sleeve meets the glove at the wrist). Origin = wrist, +Y runs up the forearm. Cached; two surfaces.
static func build_forearm() -> MeshInstance3D:
	var key: String = "forearm2"
	if not _hand_cache.has(key):
		var mesh: ArrayMesh = ArrayMesh.new()
		# [material, [[r_bottom, r_top, height, center_y], ...]]
		var parts: Array = [["glove", [[0.0205, 0.025, 0.05, 0.016]]],
			["sleeve", [[0.0265, 0.0372, FOREARM_BARE - 0.03, 0.03 + (FOREARM_BARE - 0.03) * 0.5]]]]
		for p: Array in parts:
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for c: Array in p[1]:
				var cm: CylinderMesh = CylinderMesh.new()
				cm.bottom_radius = float(c[0])
				cm.top_radius = float(c[1])
				cm.height = float(c[2])
				cm.radial_segments = 12
				cm.rings = 1
				st.append_from(cm, 0, Transform3D(Basis(), Vector3(0, float(c[3]), 0)))
			if str(p[0]) == "glove":
				var tm: TorusMesh = TorusMesh.new()           # turned-back gauntlet lip
				tm.inner_radius = 0.022
				tm.outer_radius = 0.0295
				tm.rings = 12
				tm.ring_segments = 6
				st.append_from(tm, 0, Transform3D(Basis(), Vector3(0, 0.038, 0)))
			else:
				var tm2: TorusMesh = TorusMesh.new()           # buttoned sleeve cuff over the gauntlet
				tm2.inner_radius = 0.024
				tm2.outer_radius = 0.0335
				tm2.rings = 14
				tm2.ring_segments = 6
				st.append_from(tm2, 0, Transform3D(Basis(), Vector3(0, 0.05, 0)))
			st.generate_normals()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, base_mat(str(p[0])))
		_hand_cache[key] = mesh
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _hand_cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Muzzle flash: a front-facing star plus two crossed side petals, additive and unshaded. Fires along -Z
## from the origin. Cached; one surface, one draw call.
static func muzzle_flash_mesh() -> ArrayMesh:
	if _flash_mesh_cache != null:
		return _flash_mesh_cache
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: Array = []
	var front: float = 0.05
	quads.append([Vector3(-front, -front, -0.012), Vector3(front, -front, -0.012), Vector3(front, front, -0.012), Vector3(-front, front, -0.012)])
	var w: float = 0.034
	var l: float = 0.17
	quads.append([Vector3(-w, 0, 0.01), Vector3(w, 0, 0.01), Vector3(w, 0, -l), Vector3(-w, 0, -l)])
	quads.append([Vector3(0, -w, 0.01), Vector3(0, w, 0.01), Vector3(0, w, -l), Vector3(0, -w, -l)])
	var uvs: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i: int in quads.size():
		var q: Array = quads[i]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var uv: Vector2 = uvs[idx]
			# side petals sample the star from its hot center (at the muzzle) out to one spike tip (forward),
			# so they taper away from the muzzle instead of making a second bright burst ahead of it
			if i > 0:
				uv = Vector2(uv.x, 1.0 - 0.5 * uv.y)
			st.set_uv(uv)
			st.add_vertex(q[idx])
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(2.0, 1.4, 0.75)       # HDR so it reads in daylight
	mat.albedo_texture = _flash_texture()
	mesh.surface_set_material(0, mat)
	_flash_mesh_cache = mesh
	return mesh


## Six-pointed star with a hot core, drawn once into a 64x64 texture.
static func _flash_texture() -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var d: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) / float(n) * 2.0 - Vector2.ONE
			var rr: float = d.length()
			var a: float = atan2(d.y, d.x)
			var spikes: float = pow(absf(cos(a * 3.0)), 6.0)
			var reach: float = 0.3 + 0.7 * spikes
			var v: float = clampf(1.0 - rr / reach, 0.0, 1.0)
			var core: float = clampf(1.0 - rr / 0.35, 0.0, 1.0)
			var k: float = clampf(v * v + core * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, lerpf(0.7, 1.0, core), lerpf(0.35, 0.9, core), k))
	return ImageTexture.create_from_image(img)


## Flattened chalk silhouette of a weapon for wall-buys (side view, along the wall's X axis).
static func build_chalk(weapon_id: StringName, max_len: float = 1.2) -> Node3D:
	var model: Node3D = build(weapon_id, false, &"")
	var chalk: Material = base_mat("chalk")
	_set_material_recursive(model, chalk)
	for c: Node in model.get_children():
		if c is Light3D:
			c.queue_free()
	var flat: Node3D = Node3D.new()
	flat.name = "Chalk"
	var length: float = float(model.get_meta("length", 0.6))
	var k: float = minf(1.0, max_len / maxf(0.1, length))
	flat.scale = Vector3(k, k, 0.06)
	model.rotation_degrees = Vector3(0, 90, 0)          # barrel (-Z) points toward +X along the wall
	model.position = Vector3(length * 0.4, 0, 0)
	flat.add_child(model)
	return flat


## Bounding box of every mesh under `n`, in n's space (for centring a model in a display).
static func model_bounds(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != n:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _set_material_recursive(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c: Node in n.get_children():
		_set_material_recursive(c, mat)
