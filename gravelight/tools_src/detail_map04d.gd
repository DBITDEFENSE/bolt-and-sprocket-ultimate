extends RefCounted
## Mondlicht's dressing vocabulary (UPDATE 09 §5.5, T-149): static helpers for gen_map04d.gd, kept out of the shared
## gen_map04_lib.gd (the Act I worker owns it). Everything here is presentation: no collider, no prompt.
##
## - mat(key): the act's materials, cached so merge_static_meshes batches them. Textured keys are surface_pbr
##   ShaderMaterials on the Poly Haven sets filed under assets/third_party/polyhaven/ (world-triplanar, so the
##   batches need no UVs); flat keys are Darkmatter's palette (violet #c07dff, amber cracks, chrome, graphite).
## - blk/obx/cyl/ball/cone: Props-style primitives with those materials.
## - lathe()/paraboloid(): ArrayMesh silhouettes (the capsule, the dish) without Blender.
## - sign(): a label in Darkmatter's corporate type (IBM Plex Sans, light weight, wide tracking) on a real panel.
## - strip(): a chrome luminaire with its glowing tube; patch(): a feathered regolith detail (moon_patch.gdshader).
## - tag_lights(): `zone` meta on every light by position (contract C4 counts shadowed lights per zone).

const PBR_SHADER: String = "res://assets/materials/shaders/surface_pbr.gdshader"
const PATCH_SHADER: String = "res://gravelight/world/map04/moon_patch.gdshader"
const TEX: String = "res://assets/third_party/polyhaven/%s/textures/%s_%s.png"
const FONT_PATH: String = "res://assets/third_party/google_fonts/ibm-plex-sans/IBMPlexSans-Variable.ttf"

const VIOLET: Color = Color(0.753, 0.49, 1.0)     # #c07dff, Darkmatter's brand violet
const AMBER: Color = Color(1.0, 0.62, 0.22)
const COLD: Color = Color(0.82, 0.9, 1.0)

## key -> [set folder, file id, tile metres, tint, [rough_min, rough_max], metallic_mul, grime, normal_strength, albedo]
## albedo "" uses the set's own; "white" swaps in a neutral albedo (the set's relief and wear, the tint's colour).
const PBR: Dictionary = {
	"floor_a": ["marble-tiles", "marble_tiles", 3.2, [0.98, 0.98, 1.04], [0.12, 0.5], 0.0, 0.08, 0.8, ""],
	"floor_b": ["terrazzo-tiles", "terrazzo_tiles", 1.4, [0.62, 0.48, 0.98], [0.1, 0.45], 0.0, 0.1, 0.7, ""],
	"floor_d": ["concrete-floor-painted", "concrete_floor_painted", 2.6, [0.9, 0.97, 1.12], [0.3, 0.85], 0.0, 0.25, 1.0, ""],
	"floor_e": ["granite-tile", "granite_tile", 2.3, [0.78, 0.7, 0.98], [0.06, 0.4], 0.0, 0.05, 0.8, ""],
	"floor_f": ["marble-tiles", "marble_tiles", 1.2, [0.34, 0.27, 0.46], [0.05, 0.3], 0.0, 0.05, 0.7, ""],
	"regolith": ["moon-dusted-01", "moon_dusted_01", 2.4, [0.46, 0.46, 0.48], [0.82, 1.0], 0.0, 0.0, 1.2, ""],
	"regolith_far": ["moon-dusted-01", "moon_dusted_01", 7.0, [0.32, 0.32, 0.34], [0.85, 1.0], 0.0, 0.0, 1.0, ""],
	"rim_rock": ["moon-dusted-01", "moon_dusted_01", 3.2, [0.3, 0.3, 0.32], [0.85, 1.0], 0.0, 0.0, 1.6, ""],
	"wall_d": ["box-profile-metal-sheet", "box_profile_metal_sheet", 2.0, [0.66, 0.68, 0.72], [0.3, 0.7], 0.6, 0.1, 1.0, "white"],
	"hull": ["box-profile-metal-sheet", "box_profile_metal_sheet", 3.0, [0.74, 0.74, 0.76], [0.4, 0.8], 0.3, 0.3, 0.6, "white"],
}

## key -> [albedo, roughness, metallic, emission colour (or null), emission energy, alpha (1 = opaque)]
const FLAT: Dictionary = {
	"dm_white": [Color(0.86, 0.86, 0.88), 0.22, 0.0, null, 0.0, 1.0],
	"dm_offwhite": [Color(0.7, 0.7, 0.73), 0.3, 0.0, null, 0.0, 1.0],
	"dm_violet": [Color(0.38, 0.22, 0.6), 0.35, 0.0, null, 0.0, 1.0],
	"dm_violet_hall": [Color(0.24, 0.12, 0.4), 0.3, 0.0, null, 0.0, 1.0],
	"dm_violet_deep": [Color(0.09, 0.04, 0.16), 0.3, 0.0, null, 0.0, 1.0],
	"dm_graphite": [Color(0.06, 0.06, 0.07), 0.38, 0.2, null, 0.0, 1.0],
	"dm_f_wall": [Color(0.2, 0.14, 0.27), 0.32, 0.1, null, 0.0, 1.0],
	"dm_chrome": [Color(0.82, 0.82, 0.85), 0.22, 0.45, null, 0.0, 1.0],
	"dm_chrome_dark": [Color(0.45, 0.44, 0.48), 0.28, 0.4, null, 0.0, 1.0],
	"dm_steel_dark": [Color(0.3, 0.3, 0.32), 0.45, 0.3, null, 0.0, 1.0],
	"dm_black_glass": [Color(0.015, 0.012, 0.025), 0.05, 0.5, null, 0.0, 1.0],
	"dm_glow_violet": [Color(0.3, 0.16, 0.42), 0.4, 0.0, Color(0.753, 0.49, 1.0), 3.2, 1.0],
	"dm_glow_violet_soft": [Color(0.2, 0.1, 0.3), 0.4, 0.0, Color(0.6, 0.36, 0.95), 1.4, 1.0],
	"dm_glow_white": [Color(0.8, 0.85, 0.9), 0.4, 0.0, Color(0.82, 0.9, 1.0), 3.0, 1.0],
	"dm_glow_amber": [Color(0.4, 0.22, 0.06), 0.4, 0.0, Color(1.0, 0.62, 0.22), 3.0, 1.0],
	"dm_glow_red": [Color(0.3, 0.04, 0.03), 0.4, 0.0, Color(1.0, 0.16, 0.1), 3.0, 1.0],
	"dm_glow_screen": [Color(0.05, 0.03, 0.08), 0.2, 0.0, Color(0.55, 0.35, 0.9), 1.2, 1.0],
	"dm_glass": [Color(0.75, 0.8, 0.9), 0.02, 0.0, null, 0.0, 0.12],
	"dm_glass_violet": [Color(0.55, 0.35, 0.85), 0.04, 0.0, null, 0.0, 0.2],
	"dm_frosted": [Color(0.78, 0.8, 0.88), 0.5, 0.0, null, 0.0, 0.45],
	"suit": [Color(0.6, 0.6, 0.58), 0.85, 0.0, null, 0.0, 1.0],
	"suit_dark": [Color(0.2, 0.2, 0.22), 0.7, 0.2, null, 0.0, 1.0],
	"suit_violet": [Color(0.26, 0.13, 0.42), 0.6, 0.0, null, 0.0, 1.0],
	"visor": [Color(0.06, 0.04, 0.1), 0.08, 0.9, null, 0.0, 1.0],
	"tag": [Color(0.86, 0.83, 0.74), 0.9, 0.0, null, 0.0, 1.0],
	"capsule": [Color(0.42, 0.41, 0.4), 0.5, 0.35, null, 0.0, 1.0],
	"capsule_scorch": [Color(0.07, 0.055, 0.05), 0.9, 0.2, null, 0.0, 1.0],
	"capsule_paint": [Color(0.55, 0.52, 0.45), 0.6, 0.1, null, 0.0, 1.0],
	"dish": [Color(0.72, 0.72, 0.74), 0.45, 0.2, null, 0.0, 1.0],
	"concrete": [Color(0.38, 0.38, 0.4), 0.9, 0.0, null, 0.0, 1.0],
	"miner": [Color(0.16, 0.15, 0.14), 0.95, 0.0, null, 0.0, 1.0],
	"skin_pale": [Color(0.42, 0.38, 0.4), 0.8, 0.0, null, 0.0, 1.0],
	"rubber": [Color(0.05, 0.05, 0.05), 0.9, 0.0, null, 0.0, 1.0],
	"parcel": [Color(0.5, 0.42, 0.32), 0.85, 0.0, null, 0.0, 1.0],
	"parcel_violet": [Color(0.2, 0.1, 0.32), 0.6, 0.0, null, 0.0, 1.0],
}

static var _cache: Dictionary = {}
static var _font: FontVariation = null
static var _plane: PlaneMesh = null
static var _sph_lo: SphereMesh = null
static var _rock: SphereMesh = null


## The act's material for `key` (cached per run so the batches merge). Unknown keys fall back to Mats.
static func mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = null
	if PBR.has(key):
		m = _pbr(key, PBR[key])
	elif FLAT.has(key):
		m = _flat(FLAT[key])
	else:
		m = Mats.get_mat(key)
	_cache[key] = m
	return m


static func _pbr(key: String, e: Array) -> Material:
	var alb_path: String = TEX % [e[0], e[1], "albedo"]
	var nrm: Texture2D = load(TEX % [e[0], e[1], "normal"]) as Texture2D
	var orm: Texture2D = load(TEX % [e[0], e[1], "orm"]) as Texture2D
	var alb: Texture2D = _white() if str(e[8]) == "white" else load(alb_path) as Texture2D
	if alb == null or nrm == null or orm == null:
		push_warning("detail_map04d: %s is missing a map (%s)" % [key, alb_path])
		return Mats.get_mat("enamel_white")
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(PBR_SHADER) as Shader
	m.resource_name = "m4d_" + key
	m.set_shader_parameter("albedo_tex", alb)
	m.set_shader_parameter("normal_tex", nrm)
	m.set_shader_parameter("orm_tex", orm)
	m.set_shader_parameter("uv_scale", Vector3.ONE / maxf(0.05, float(e[2])))
	m.set_shader_parameter("triplanar", true)
	var t: Array = e[3]
	m.set_shader_parameter("albedo_tint", Color(float(t[0]), float(t[1]), float(t[2])))
	var r: Array = e[4]
	m.set_shader_parameter("rough_min", float(r[0]))
	m.set_shader_parameter("rough_max", float(r[1]))
	m.set_shader_parameter("metallic_mul", float(e[5]))
	m.set_shader_parameter("grime", float(e[6]))
	m.set_shader_parameter("normal_strength", float(e[7]))
	return m


static func _white() -> Texture2D:
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.9, 0.9, 0.9))
	return ImageTexture.create_from_image(img)


static func _flat(e: Array) -> Material:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = e[0]
	m.roughness = float(e[1])
	m.metallic = float(e[2])
	if e[3] != null:
		m.emission_enabled = true
		m.emission = e[3]
		m.emission_energy_multiplier = float(e[4])
	if float(e[5]) < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c: Color = e[0]
		c.a = float(e[5])
		m.albedo_color = c
		m.metallic_specular = 0.35
	return m


# ================================================================== primitives (Props idiom, our materials)

static func blk(parent: Node3D, a: Vector3, b: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.block(parent, a, b, "enamel_white", shadows)
	mi.material_override = mat(key)
	_glow_noshadow(mi, key)
	return mi


static func obx(parent: Node3D, c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.obox(parent, c, size, "enamel_white", rot)
	mi.material_override = mat(key)
	_glow_noshadow(mi, key)
	return mi


static func cyl(parent: Node3D, c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.cyl(parent, c, r, h, "enamel_white", rot)
	mi.material_override = mat(key)
	_glow_noshadow(mi, key)
	return mi


static func ball(parent: Node3D, c: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.ball(parent, c, size, "enamel_white")
	mi.material_override = mat(key)
	mi.mesh = rock_mesh() if key == "rim_rock" or key == "regolith_far" else lo_sphere()
	_glow_noshadow(mi, key)
	return mi


static func cone(parent: Node3D, c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.cone(parent, c, r, h, "enamel_white", rot)
	mi.material_override = mat(key)
	_glow_noshadow(mi, key)
	return mi


static func strut(parent: Node3D, a: Vector3, b: Vector3, thick: float, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.strut(parent, a, b, thick, "enamel_white")
	mi.material_override = mat(key)
	return mi


static func _glow_noshadow(mi: MeshInstance3D, key: String) -> void:
	var e: Array = FLAT.get(key, [])
	if not e.is_empty() and (e[3] != null or float(e[5]) < 1.0):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A lighter unit sphere than Props' (10 x 5: 80 triangles, not 144) for the many small balls.
static func lo_sphere() -> SphereMesh:
	if _sph_lo == null:
		_sph_lo = SphereMesh.new()
		_sph_lo.radius = 0.5
		_sph_lo.height = 1.0
		_sph_lo.radial_segments = 10
		_sph_lo.rings = 5
	return _sph_lo


## A faceted unit sphere for rocks (7 x 4: 48 triangles); the facets read as broken lunar stone.
static func rock_mesh() -> SphereMesh:
	if _rock == null:
		_rock = SphereMesh.new()
		_rock.radius = 0.5
		_rock.height = 1.0
		_rock.radial_segments = 7
		_rock.rings = 4
	return _rock


## The budget pass (C4): small, flat or ceiling-high dressing stops casting shadows (the Sun's cascades and the key
## spots drew every bolt, tag and inlay again per pass). Returns how many were switched off.
static func shadow_diet(root: Node3D, ceil_of: Callable) -> int:
	var k: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or mi.mesh == null:
			continue
		var xf: Transform3D = _xf_in(mi, root)
		var sz: Vector3 = (xf.basis.get_scale() * mi.mesh.get_aabb().size).abs()
		var top: float = xf.origin.y + sz.y * 0.5
		var c: float = float(ceil_of.call(xf.origin))
		if maxf(sz.x, maxf(sz.y, sz.z)) < 1.2 or minf(sz.x, minf(sz.y, sz.z)) < 0.05 or (c > 0.0 and xf.origin.y > c - 1.2 and top > c - 1.5):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			k += 1
	return k


static func _xf_in(n: Node3D, root: Node) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Triangles per top-level dressing group (Props.group names; loose pieces under "(loose)"), largest first: the
## generator prints it so the C4 budget has a place to start.
static func tally(root: Node3D, top: int = 12) -> String:
	var tris: Dictionary = {}
	var faces: Dictionary = {}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		if not faces.has(mi.mesh):
			faces[mi.mesh] = mi.mesh.get_faces().size() / 3
		var g: Node = mi
		while g.get_parent() != root and g.get_parent() != null:
			g = g.get_parent()
		var key: String = "(loose)" if g == mi else String(g.name).rstrip("0123456789")
		tris[key] = int(tris.get(key, 0)) + int(faces[mi.mesh])
	var keys: Array = tris.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return int(tris[x]) > int(tris[y]))
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in keys.slice(0, top):
		out.append("%s %d" % [k, tris[k]])
	return ", ".join(out)


## ViewCells (T-145's portal-lite visibility, used here for C4, T-149): merges the dressing's primitive meshes per
## (visibility group, material, shadow mode) itself, before the shared lib's merge (whose 22 m cells mix the domes),
## and tags the batches and every loose visual (labels, kept meshes, scripted pieces) with meta "vis_group" and the
## persistent node group "view_cell_member". `group_of(p)` names a point's group; a node or an ancestor with meta
## "vis" overrides it ("ALL" is never hidden: the dome caps, the shadow shells). Returns the batch count.
static func merge_by_group(dress: Node3D, map_root: Node3D, group_of: Callable) -> int:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _keep_in(mi, dress):
			continue
		var xf: Transform3D = _xf_in(mi, map_root)
		var g: String = _vis_override(mi, dress)
		if g == "":
			g = str(group_of.call(xf * mi.mesh.get_aabb().get_center()))
		var cc: Vector3 = xf * mi.mesh.get_aabb().get_center()
		var cell: Vector3i = Vector3i(floori(cc.x / 22.0), floori((cc.y + 7.0) / 9.0), floori(cc.z / 22.0))   # 22 m cells, as the lib: fine frustum culling
		var key: String = "%s|%d|%d|%s" % [g, mi.material_override.get_instance_id(), mi.cast_shadow, cell]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"g": g, "mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	var holder: Node3D = Node3D.new()
	holder.name = "ZoneBatches"
	holder.set_meta("keep", true)
	map_root.add_child(holder)
	var i: int = 0
	for key2: String in groups.keys():
		var e: Dictionary = groups[key2]
		var arrays: Array = (e["st"] as SurfaceTool).commit_to_arrays()
		arrays[Mesh.ARRAY_TEX_UV] = null
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "ZB_%s_%d" % [e["g"], i]
		out.mesh = m
		out.material_override = e["mat"]
		out.cast_shadow = e["shadow"]
		_tag_vis(out, str(e["g"]))
		holder.add_child(out)
		i += 1
	for v: MeshInstance3D in victims:
		v.get_parent().remove_child(v)
		v.free()
	# the loose visuals that stay: labels, kept meshes (patches, the conveyor, the hand, the beam), scripted pieces
	for n2: Node in dress.find_children("*", "", true, false):
		var vis: bool = n2 is Label3D or (n2 is Node3D and (n2.has_meta("keep") or n2.get_script() != null))
		if not vis or _tagged_above(n2, dress):
			continue
		var g2: String = _vis_override(n2, dress)
		if g2 == "":
			g2 = str(group_of.call(_xf_in(n2 as Node3D, map_root).origin))
		_tag_vis(n2 as Node3D, g2)
	return i


static func _tag_vis(n: Node3D, g: String) -> void:
	n.set_meta("vis_group", g)
	if g != "ALL":
		n.add_to_group(&"view_cell_member", true)


static func _keep_in(n: Node, root: Node) -> bool:
	var p: Node = n
	while p != null and p != root:
		if p.has_meta("keep"):
			return true
		p = p.get_parent()
	return false


static func _vis_override(n: Node, root: Node) -> String:
	var p: Node = n
	while p != null and p != root:
		if p.has_meta("vis"):
			return str(p.get_meta("vis"))
		p = p.get_parent()
	return ""


static func _tagged_above(n: Node, root: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p.has_meta("vis_group"):
			return true
		p = p.get_parent()
	return false


## A mesh instance kept out of the static batches (meta keep: its UVs or its own mesh must survive).
static func keep(parent: Node3D, n: String, mesh: Mesh, xf: Transform3D, key: String, shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = mat(key)
	mi.set_meta("keep", true)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ================================================================== silhouettes

## A surface of revolution about +Y from a profile of (radius, y) points, `segs` around. Smooth normals.
static func lathe(profile: PackedVector2Array, segs: int = 24) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		for j: int in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var v00: Vector3 = Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01: Vector3 = Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10: Vector3 = Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11: Vector3 = Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v11)
			st.add_vertex(v00)
			st.add_vertex(v11)
			st.add_vertex(v01)
	st.index()
	st.generate_normals()
	return st.commit()


## A dish: a paraboloid of `radius` and `depth` opening toward +Y, both faces (the back is the same surface reversed).
static func paraboloid(radius: float, depth: float, segs: int = 28, rings: int = 7) -> ArrayMesh:
	var prof: PackedVector2Array = PackedVector2Array()
	for k: int in rings + 1:
		var r: float = radius * float(k) / float(rings)
		prof.append(Vector2(r, depth * (r * r) / (radius * radius)))
	var front: ArrayMesh = lathe(prof, segs)
	var back_prof: PackedVector2Array = PackedVector2Array()
	for k2: int in range(prof.size() - 1, -1, -1):
		back_prof.append(prof[k2] + Vector2(0, -0.06))
	var st: SurfaceTool = SurfaceTool.new()
	st.append_from(front, 0, Transform3D.IDENTITY)
	st.append_from(lathe(back_prof, segs), 0, Transform3D.IDENTITY)
	return st.commit()


# ================================================================== signage in Darkmatter's type

## Darkmatter's corporate face: IBM Plex Sans (the bundled OFL family), light, tracked wide.
static func font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		var base: Font = load(FONT_PATH) as Font
		if base != null:
			_font.base_font = base
		var ts: TextServer = TextServerManager.get_primary_interface()
		_font.variation_opentype = {ts.name_to_tag("wght"): 330}
		_font.spacing_glyph = 3
	return _font


## A Label3D in the house type. `glow` > 0 makes it unshaded and bright (lit signage); 0 is a printed/engraved face.
static func text(parent: Node3D, s: String, pos: Vector3, yaw: float, size_px: int, color: Color, glow: float = 0.0,
		pixel: float = 0.004) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = s
	l.font = font()
	l.font_size = size_px
	l.pixel_size = pixel
	l.outline_size = 0
	l.position = pos
	l.rotation.y = deg_to_rad(yaw)
	if glow > 0.0:
		l.shaded = false
		l.modulate = Color(color.r * glow, color.g * glow, color.b * glow, color.a)
	else:
		l.shaded = true
		l.modulate = color
	l.double_sided = false
	parent.add_child(l)
	return l


## A real sign: a graphite panel with a chrome edge, a violet light line under the text and the lit text, facing
## `yaw` (the reader stands in front, along the panel's +Z after the yaw). w/h in metres.
static func sign(parent: Node3D, s: String, center: Vector3, yaw: float, w: float, h: float, size_px: int,
		color: Color = VIOLET, mark: bool = true) -> Node3D:
	var g: Node3D = Props.group(parent, "Sign", center, yaw)
	blk(g, Vector3(-w * 0.5, -h * 0.5, -0.04), Vector3(w * 0.5, h * 0.5, 0.0), "dm_graphite")
	blk(g, Vector3(-w * 0.5 - 0.02, h * 0.5, -0.05), Vector3(w * 0.5 + 0.02, h * 0.5 + 0.03, 0.01), "dm_chrome")
	blk(g, Vector3(-w * 0.5 - 0.02, -h * 0.5 - 0.03, -0.05), Vector3(w * 0.5 + 0.02, -h * 0.5, 0.01), "dm_chrome")
	blk(g, Vector3(-w * 0.42, -h * 0.34, 0.0), Vector3(w * 0.42, -h * 0.3, 0.012), "dm_glow_violet", false)
	var tx: float = 0.0
	if mark:
		logo(g, Vector3(-w * 0.5 + h * 0.42, 0.04 * h, 0.01), h * 0.36)
		tx = h * 0.3
	text(g, s, Vector3(tx, 0.04 * h, 0.014), 0.0, size_px, color, 1.6)
	return g


## Darkmatter's mark: a violet crystal lozenge split by an amber crack (Lacuna's glass, FINEPRINT_LORE §1.1).
static func logo(parent: Node3D, c: Vector3, s: float) -> void:
	obx(parent, c, Vector3(s * 0.62, s * 0.62, 0.02), "dm_glow_violet", Vector3(0, 0, 45))
	obx(parent, c + Vector3(-s * 0.05, s * 0.08, 0.012), Vector3(s * 0.05, s * 0.5, 0.01), "dm_glow_amber", Vector3(0, 0, 18))
	obx(parent, c + Vector3(s * 0.06, -s * 0.16, 0.012), Vector3(s * 0.04, s * 0.32, 0.01), "dm_glow_amber", Vector3(0, 0, -24))


# ================================================================== fixtures

## A ceiling luminaire along X (`along_x`) or Z: a chrome housing and its glowing tube underneath.
static func strip(parent: Node3D, c: Vector3, length: float, along_x: bool, glow: String = "dm_glow_white") -> void:
	var hx: float = length * 0.5 if along_x else 0.09
	var hz: float = 0.09 if along_x else length * 0.5
	blk(parent, c + Vector3(-hx, 0.0, -hz), c + Vector3(hx, 0.07, hz), "dm_chrome")
	var tx: float = hx - 0.04 if along_x else 0.035
	var tz: float = 0.035 if along_x else hz - 0.04
	blk(parent, c + Vector3(-tx, -0.035, -tz), c + Vector3(tx, 0.0, tz), glow, false)


## A feathered patch of regolith detail on the floor (centre on the ground, size x by z metres, yaw degrees):
## `tex` is a Poly Haven set folder/id pair ("moon-footprints-01/moon_footprints_01") or "" for a plain tint (scorch).
static func patch(parent: Node3D, center: Vector3, size: Vector2, yaw: float, tex: String, tile: Vector2, tint: Color,
		fade: float = 0.8) -> MeshInstance3D:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2(1, 1)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(PATCH_SHADER) as Shader
	if tex != "":
		var parts: PackedStringArray = tex.split("/")
		m.set_shader_parameter("albedo_tex", load(TEX % [parts[0], parts[1], "albedo"]))
		m.set_shader_parameter("normal_tex", load(TEX % [parts[0], parts[1], "normal"]))
		m.set_shader_parameter("use_tex", true)
	else:
		m.set_shader_parameter("use_tex", false)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tile_m", tile)
	m.set_shader_parameter("fade_m", fade)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Patch"
	mi.mesh = _plane
	mi.material_override = m
	mi.position = center + Vector3(0, 0.012, 0)
	mi.rotation.y = deg_to_rad(yaw)
	mi.scale = Vector3(size.x, 1.0, size.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("keep", true)
	parent.add_child(mi)
	return mi


# ================================================================== lights

## An omni light added to `root` with zone meta (no shadow unless asked).
static func omni(root: Node3D, n: String, pos: Vector3, color: Color, energy: float, range_: float, zone: String,
		shadow: bool = false, script: Script = null) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	if script != null:
		l.set_script(script)
	l.name = n
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 0.4
	l.set_meta("zone", StringName(zone))
	root.add_child(l)
	return l


## A spot light from `pos` toward `aim` with zone meta (the zones' key lights cast the shadows).
static func spot(root: Node3D, n: String, pos: Vector3, aim: Vector3, color: Color, energy: float, range_: float,
		angle: float, zone: String, shadow: bool = true) -> SpotLight3D:
	var s: SpotLight3D = SpotLight3D.new()
	s.name = n
	var dir: Vector3 = (aim - pos).normalized()
	s.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD), pos)
	s.light_color = color
	s.light_energy = energy
	s.spot_range = range_
	s.spot_angle = angle
	s.spot_attenuation = 0.8
	s.spot_angle_attenuation = 1.4
	s.shadow_enabled = shadow
	s.shadow_blur = 1.2
	s.shadow_bias = 0.08
	s.shadow_normal_bias = 1.5
	s.light_volumetric_fog_energy = 0.8
	s.set_meta("zone", StringName(zone))
	root.add_child(s)
	return s


## The zone a point belongs to: the first zone box holding it (x/z, any height), else the nearest box by x/z.
static func zone_at(p: Vector3, boxes: Array) -> String:
	var best: String = ""
	var best_d: float = INF
	for zb: Array in boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		if p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z:
			return str(zb[0])
		var dx: float = maxf(maxf(lo.x - p.x, 0.0), p.x - hi.x)
		var dz: float = maxf(maxf(lo.z - p.z, 0.0), p.z - hi.z)
		var d: float = dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best = str(zb[0])
	return best


## Puts `zone` meta on every Light3D under `root` that lacks it (directional lights get `dir_zone`). Returns
## {zone: shadowed count} for the log.
static func tag_lights(root: Node, boxes: Array, dir_zone: String) -> Dictionary:
	var shadowed: Dictionary = {}
	for n: Node in root.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		if not l.has_meta("zone"):
			var z: String = dir_zone if l is DirectionalLight3D else zone_at(l.global_position if l.is_inside_tree() else _pos_in(l, root), boxes)
			l.set_meta("zone", StringName(z))
		if l.shadow_enabled:
			var zk: String = str(l.get_meta("zone"))
			shadowed[zk] = int(shadowed.get(zk, 0)) + 1
	return shadowed


static func _pos_in(n: Node3D, root: Node) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


# ================================================================== walls

## The wall segments under `geo` whose names start with `prefix` as [lo, hi] boxes (from their collision shapes).
static func segments(geo: Node3D, prefix: String) -> Array:
	var out: Array = []
	for c: Node in geo.get_children():
		if not (c is StaticBody3D) or not String(c.name).begins_with(prefix):
			continue
		var b: StaticBody3D = c as StaticBody3D
		for cs: Node in b.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
				var sz: Vector3 = ((cs as CollisionShape3D).shape as BoxShape3D).size
				out.append([b.position - sz * 0.5, b.position + sz * 0.5])
	return out


## Sets the material of every collider mesh under `geo` whose name starts with `prefix`.
static func paint(geo: Node3D, prefix: String, key: String) -> int:
	var k: int = 0
	for c: Node in geo.get_children():
		if not String(c.name).begins_with(prefix):
			continue
		for mi: Node in c.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat(key)
			k += 1
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = mat(key)
			k += 1
	return k


## A thin skin over one face of each segment (side: the face whose outward normal is `normal`, an axis vector),
## so a wall shared by two rooms shows each room its own finish. 2 cm proud, no collider.
static func skin(parent: Node3D, segs: Array, normal: Vector3, key: String) -> void:
	for s: Array in segs:
		var lo: Vector3 = s[0]
		var hi: Vector3 = s[1]
		var a: Vector3 = lo
		var b: Vector3 = hi
		if normal.x > 0.5:
			a.x = hi.x
			b.x = hi.x + 0.02
		elif normal.x < -0.5:
			b.x = lo.x
			a.x = lo.x - 0.02
		elif normal.z > 0.5:
			a.z = hi.z
			b.z = hi.z + 0.02
		else:
			b.z = lo.z
			a.z = lo.z - 0.02
		if (b - a).x > 0.001 and (b - a).y > 0.001 and (b - a).z > 0.001:
			blk(parent, a, b, key)


## Skirting, a cornice and (optionally) a light cove along the face of each segment that looks along `normal`,
## and a pilaster every `pil` metres on the long runs. `ceil` is the room's ceiling height.
static func trim(parent: Node3D, segs: Array, normal: Vector3, ceil_y: float, skirting: String, cornice: String,
		cove: String = "", pil: float = 0.0, pil_key: String = "dm_chrome") -> void:
	for s: Array in segs:
		var lo: Vector3 = s[0]
		var hi: Vector3 = s[1]
		var along_x: bool = (hi.x - lo.x) > (hi.z - lo.z)
		var face: float = 0.0
		if absf(normal.x) > 0.5:
			face = hi.x if normal.x > 0.0 else lo.x
		else:
			face = hi.z if normal.z > 0.0 else lo.z
		var out: float = signf(normal.x + normal.z)
		var length: float = (hi.x - lo.x) if along_x else (hi.z - lo.z)
		if length < 0.2:
			continue
		var c0: float = lo.x if along_x else lo.z
		var c1: float = hi.x if along_x else hi.z
		if lo.y <= 0.01 and hi.y > 0.5:
			_run(parent, along_x, face, out, c0, c1, 0.0, 0.16, 0.025, skirting)
		if hi.y >= ceil_y - 0.01:
			_run(parent, along_x, face, out, c0, c1, ceil_y - 0.22, ceil_y, 0.09, cornice)
			if cove != "":
				_run(parent, along_x, face, out, c0, c1, ceil_y - 0.26, ceil_y - 0.22, 0.06, cove, false)
		if pil > 0.0 and length > pil * 0.9 and lo.y <= 0.01 and hi.y >= ceil_y - 0.01:
			var n: int = int(floor(length / pil))
			for i: int in range(1, n + 1):
				var c: float = c0 + length * float(i) / float(n + 1)
				_run(parent, along_x, face, out, c - 0.12, c + 0.12, 0.16, ceil_y - 0.22, 0.06, pil_key)


static func _run(parent: Node3D, along_x: bool, face: float, out: float, c0: float, c1: float, y0: float, y1: float,
		depth: float, key: String, shadows: bool = true) -> void:
	var f0: float = face
	var f1: float = face + out * depth
	if along_x:
		blk(parent, Vector3(c0, y0, minf(f0, f1)), Vector3(c1, y1, maxf(f0, f1)), key, shadows)
	else:
		blk(parent, Vector3(minf(f0, f1), y0, c0), Vector3(maxf(f0, f1), y1, c1), key, shadows)
