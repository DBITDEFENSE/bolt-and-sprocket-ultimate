class_name Landscape
extends Node3D
## The world beyond Map 0's play space (Update 02 section 7, DECISIONS T-052): rolling snow in three depth layers
## (the near swell, the forested mid hills, two ridge bands of mountains), the night sky dome, mist cards, the road
## running on into the dark with what people left on it, the telephone line, the frozen stream and its bridge, the
## farmhouse with one lit window, the church on the far hill, the burning town, the crash site's extra wreckage,
## icicles, the inn sign and the loose hayloft door, the stable's moonlight leaks and the field's ground fog.
##
## Built at load time from code (deterministic), so map00.tscn only carries this node: nothing here collides
## (the play space's own colliders keep players in) and the navmesh never sees it. MapAmbience drives everything
## that moves or changes over the match (it finds this node with Landscape.find()).

const PINE_SHADER: String = "res://gravelight/world/landscape/shaders/pine.gdshader"
## UPDATE_05 section 5 (T-093): the scripted spruces, birches, bushes and boulders (tools_src/blender/nature/) and the
## shader their cards and bark use. Unit-sized meshes: a tree is 1.0 tall and instances scale it to its height.
const NATURE_GLB: String = "res://assets/ours/env/nature/nature.glb"
const TREE_SHADER: String = "res://gravelight/world/landscape/shaders/tree.gdshader"
const NATURE_TEX: String = "res://assets/ours/env/nature/textures/"
## Share of the forest that is birch, near and mid (the rest spruce).
const BIRCH_SHARE: float = 0.16
## Trees nearer CENTER than this use the full LOD0 model; the rest of the near ring LOD1 (they sit in the map's fog).
const DETAIL_R: float = 95.0
const SH_DIR: String = "res://gravelight/world/landscape/shaders/"
## How much brighter the custom far haze is than the environment's fog colour: the near world's distant haze is
## the fog colour plus the volumetric fog's in-scatter, which the far layers (fog_disabled) don't get.
const HAZE_GAIN: float = 0.86
const WRECK_POS: Vector3 = Vector3(46, 0, 6)
const WRECK_YAW: float = 28.0
const WRECK_ROLL: float = -8.0
const FARM_BEARING: float = 312.0
const FARM_R: float = 188.0
const CHURCH_BEARING: float = 28.0
const TOWN_BEARING: float = 64.0

@export var build_on_ready: bool = true

var sky: MeshInstance3D
var sky_mat: ShaderMaterial
var far_mats: Array[ShaderMaterial] = []
var mist_mats: Array[ShaderMaterial] = []
var farm_window: Node3D
var town_fires: Array[MeshInstance3D] = []
var church_pos: Vector3 = Vector3.ZERO
var farm_pos: Vector3 = Vector3.ZERO
var town_pos: Vector3 = Vector3.ZERO
var inn_sign: Node3D
var hayloft_door: Node3D
var parachute_load: Node3D
var cookoff_points: Array[Vector3] = []
var wreck_node: Node3D
var built: bool = false
var _env_t: float = 0.0
var _last_fog: Color = Color(-1, -1, -1)
var _last_bg: Color = Color(-1, -1, -1)
var _static: Node3D


static func find(tree: SceneTree) -> Landscape:
	return tree.get_first_node_in_group(&"landscape") as Landscape if tree != null else null


func _ready() -> void:
	add_to_group(&"landscape")
	if build_on_ready:
		build()


func build() -> void:
	if built:
		return
	built = true
	var t0: int = Time.get_ticks_msec()
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_build_sky()
	_build_terrain()
	_build_forests()
	_build_mist()
	_build_undergrowth()
	_build_road_story()
	_build_telephone_line()
	_build_stream_bridge()
	_build_farm_and_church()
	_build_town()
	_build_crash_site()
	_build_inn_details()
	_build_stable_light()
	_build_field_fog()
	var merged: int = _batch(_static)
	_sync_env(true)
	print("[landscape] built in %d ms (%d static meshes batched)" % [Time.get_ticks_msec() - t0, merged])


func _process(delta: float) -> void:
	if sky == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		sky.global_position = cam.global_position
		var r: float = cam.far * 0.97
		sky.scale = Vector3(r, r, r)
	_env_t -= delta
	if _env_t <= 0.0:
		_env_t = 0.2
		_sync_env(false)


# ================================================================== materials

func _shader(file: String) -> Shader:
	return load(SH_DIR + file) as Shader


func _far_mat(file: String, params: Dictionary = {}) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader(file)
	for k: String in params.keys():
		m.set_shader_parameter(k, params[k])
	if file == "far_land.gdshader" and MaterialLibrary.texture("rock", "albedo") != null:
		m.set_shader_parameter("rock_tex", MaterialLibrary.texture("rock", "albedo"))   # T-093
	far_mats.append(m)
	return m


## The environment's colours drive the haze and the sky (the campaign's dawn cutscene tweens them).
func _sync_env(force: bool) -> void:
	var we: WorldEnvironment = _world_env()
	if we == null or we.environment == null:
		return
	var env: Environment = we.environment
	var fog: Color = env.fog_light_color * env.fog_light_energy * HAZE_GAIN
	var fogv: Vector3 = Vector3(fog.r, fog.g, fog.b)
	if not force and fog.is_equal_approx(_last_fog) and env.background_color.is_equal_approx(_last_bg):
		return
	_last_fog = fog
	_last_bg = env.background_color
	for m: ShaderMaterial in far_mats:
		m.set_shader_parameter("fog_color", fogv)
	for mm: ShaderMaterial in mist_mats:
		mm.set_shader_parameter("color", fogv * 1.15)
	if sky_mat != null:
		var bg: Color = env.background_color
		var hz: Color = bg.lerp(fog, 0.8) * 0.95
		sky_mat.set_shader_parameter("zenith", Vector3(bg.r, bg.g, bg.b) * 0.4)
		sky_mat.set_shader_parameter("horizon", Vector3(hz.r, hz.g, hz.b))
		sky_mat.set_shader_parameter("cloud_tint", Vector3(hz.r, hz.g, hz.b) * 0.8)


func _world_env() -> WorldEnvironment:
	var p: Node = get_parent()
	return p.find_child("WorldEnvironment", false, false) as WorldEnvironment if p != null else null


# ================================================================== sky

func _build_sky() -> void:
	sky = MeshInstance3D.new()
	sky.name = "SkyDome"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 48
	sm.rings = 24
	sky.mesh = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = 16384.0
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = _shader("sky_dome.gdshader")
	sky_mat.set_shader_parameter("town_dir", LandscapeTerrain.dir_of(TOWN_BEARING))
	var moon: DirectionalLight3D = get_parent().find_child("Moon", false, false) as DirectionalLight3D if get_parent() != null else null
	if moon != null:
		sky_mat.set_shader_parameter("moon_dir", moon.global_transform.basis.z.normalized())
	var zero: PackedVector4Array = PackedVector4Array()
	zero.resize(8)
	sky_mat.set_shader_parameter("flashes", zero)
	sky_mat.set_shader_parameter("flash_cols", zero)
	var zb: PackedVector4Array = PackedVector4Array()
	zb.resize(4)
	sky_mat.set_shader_parameter("beams", zb)
	sky.material_override = sky_mat
	sky.scale = Vector3(370, 370, 370)
	add_child(sky)


# ================================================================== terrain

func _build_terrain() -> void:
	var mesh: ArrayMesh = LandscapeTerrain.build_grid()
	var near: ShaderMaterial = ShaderMaterial.new()
	near.shader = _shader("near_land.gdshader")
	_near_land_textures(near)
	mesh.surface_set_material(0, near)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _far_mat("far_land.gdshader", {"fog_max": 0.84, "fog_k": 0.022}))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for band: int in 2:
		var rm: ArrayMesh = LandscapeTerrain.build_ridge(band)
		var r: MeshInstance3D = MeshInstance3D.new()
		r.name = "RidgeBand%d" % band
		r.mesh = rm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.material_override = _far_mat("far_land.gdshader", {"ridge": 1.0, "fog_max": 0.84, "fog_k": 0.022, "fog_bias": 0.035 if band == 1 else 0.0,
			"noise_scale": 0.03})
		add_child(r)


## The near terrain's textures (T-093): the slab's own snow set and the frozen-mud set the roads blend into. The
## library materials are ShaderMaterials, so the maps come from MaterialLibrary (by the generator's key, so the
## terrain follows whatever "snow" the slab uses); the procedural StandardMaterial3D snow is the fallback.
static func _near_land_textures(near: ShaderMaterial) -> void:
	var snow_key: String = MaterialLibrary.generator_key("snow")
	if MaterialLibrary.for_generator("snow") != null and MaterialLibrary.texture(snow_key, "albedo") != null:
		var e: Dictionary = MaterialLibrary.entry(snow_key)
		near.set_shader_parameter("albedo_tex", MaterialLibrary.texture(snow_key, "albedo"))
		near.set_shader_parameter("normal_tex", MaterialLibrary.texture(snow_key, "normal"))
		near.set_shader_parameter("uv_scale", 1.0 / maxf(0.05, float(e.get("tile_m", 2.0))))
		var t: Array = e.get("tint", [1, 1, 1])
		near.set_shader_parameter("snow_tint", Vector3(float(t[0]), float(t[1]), float(t[2])))
	else:
		var snow: StandardMaterial3D = Mats.get_mat("snow") as StandardMaterial3D
		if snow != null:
			near.set_shader_parameter("albedo_tex", snow.albedo_texture)
			near.set_shader_parameter("normal_tex", snow.normal_texture)
			near.set_shader_parameter("uv_scale", snow.uv1_scale.x)
	if MaterialLibrary.has_key("frozen_mud") and MaterialLibrary.texture("frozen_mud", "albedo") != null:
		var m: Dictionary = MaterialLibrary.entry("frozen_mud")
		near.set_shader_parameter("mud_tex", MaterialLibrary.texture("frozen_mud", "albedo"))
		near.set_shader_parameter("mud_normal_tex", MaterialLibrary.texture("frozen_mud", "normal"))
		near.set_shader_parameter("mud_uv_scale", 1.0 / maxf(0.05, float(m.get("tile_m", 2.0))))
		near.set_shader_parameter("use_mud", true)


# ================================================================== forests

## A spruce: a short trunk and four stacked, drooping cones (unit height; instances scale it). Vertex colour r = foliage.
## Clockwise front faces (Godot's convention) with explicit outward normals.
static func pine_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_frustum(st, 0.0, 0.32, 0.035, 0.03, 6, Color(0, 0, 0))   # the trunk
	var tiers: Array = [[0.12, 0.5, 0.36], [0.33, 0.68, 0.29], [0.52, 0.84, 0.21], [0.7, 1.0, 0.13]]
	for t: Array in tiers:
		_frustum(st, float(t[0]), float(t[1]), float(t[2]), 0.0, 8, Color(1, 0, 0))
	return st.commit()


## A frustum (or a cone when r1 = 0) from y0 (radius r0) up to y1 (radius r1), with a flat underside.
static func _frustum(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, seg: int, col: Color) -> void:
	for i: int in seg:
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		var b0: Vector3 = Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1: Vector3 = Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var t0: Vector3 = Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var t1: Vector3 = Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var n0: Vector3 = Vector3(cos(a0) * (y1 - y0), r0 - r1, sin(a0) * (y1 - y0)).normalized()
		var n1: Vector3 = Vector3(cos(a1) * (y1 - y0), r0 - r1, sin(a1) * (y1 - y0)).normalized()
		var tri: Array = [[b0, n0], [b1, n1], [t1, n1]]
		if r1 > 0.0:
			tri.append_array([[b0, n0], [t1, n1], [t0, n0]])
		tri.append_array([[Vector3(0, y0 + 0.02, 0), Vector3.DOWN], [b1, Vector3.DOWN], [b0, Vector3.DOWN]])
		for v: Array in tri:
			st.set_color(col)
			st.set_normal(v[1])
			st.add_vertex(v[0])


# ================================================================== the scripted trees (T-093)

static var _nature_meshes: Dictionary = {}
static var _tree_mats: Dictionary = {}
static var _tree_meshes: Dictionary = {}


## A raw mesh from nature.glb by its node name (Spruce_LOD0, Birch_LOD1, Bush_A, Rock_B...), null if missing.
static func nature_mesh(node_name: String) -> Mesh:
	if _nature_meshes.has(node_name):
		return _nature_meshes[node_name]
	if not ResourceLoader.exists(NATURE_GLB):
		return null
	var root: Node = (load(NATURE_GLB) as PackedScene).instantiate()
	var found: Mesh = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		_nature_meshes[String(mi.name)] = mi.mesh
		if String(mi.name) == node_name:
			found = mi.mesh
	root.free()
	return found


## A tree material by its kind ("needles", "bark", "twigs", "birch_bark"): near ones use the map's fog, far ones
## the capped far fog (fog_disabled; the Landscape keeps their fog colour in step).
static func tree_material(kind: String, near: bool) -> ShaderMaterial:
	var key: String = kind + ("|near" if near else "|far")
	if _tree_mats.has(key):
		return _tree_mats[key]
	var sh: Shader = load(TREE_SHADER) as Shader
	if near:
		var ns: Shader = Shader.new()
		ns.code = sh.code.replace(", fog_disabled", "")
		sh = ns
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.resource_name = "tree_" + key
	if near:
		m.set_shader_parameter("fog_max", 0.0)
	match kind:
		"needles":
			m.set_shader_parameter("tex", load(NATURE_TEX + "tex_spruce_frond.png"))
			m.set_shader_parameter("tint", Color(0.95, 1.0, 0.95))
			m.set_shader_parameter("snow_amount", 0.35)
			m.set_shader_parameter("wind", 0.012)
		"twigs":
			m.set_shader_parameter("tex", load(NATURE_TEX + "tex_birch_twigs.png"))
			m.set_shader_parameter("snow_amount", 0.15)
			m.set_shader_parameter("wind", 0.02)
		"birch_bark":
			m.set_shader_parameter("tex", load(NATURE_TEX + "tex_birch_bark.png"))
			m.set_shader_parameter("tint", Color(0.92, 0.92, 0.9))
			m.set_shader_parameter("snow_amount", 0.3)
			m.set_shader_parameter("roughness", 0.8)
		_:   # "bark": the library's spruce bark when there, else a dark flat colour
			var bt: Texture2D = MaterialLibrary.texture("bark", "albedo")
			if bt != null:
				m.set_shader_parameter("tex", bt)
			m.set_shader_parameter("tint", Color(0.55, 0.5, 0.46))
			m.set_shader_parameter("uv_mul", Vector2(1.0, 0.6))
			m.set_shader_parameter("snow_amount", 0.4)
	_tree_mats[key] = m
	return m


## A nature mesh with its surfaces set to the tree materials (cached per node and fog kind). Rocks get the
## library's "rock" material (triplanar, so their unit size scales without stretching).
static func tree_mesh(node_name: String, near: bool) -> Mesh:
	var key: String = node_name + ("|near" if near else "|far")
	if _tree_meshes.has(key):
		return _tree_meshes[key]
	var src: Mesh = nature_mesh(node_name)
	if src == null:
		return null
	var m: Mesh = src.duplicate() as Mesh
	for i: int in m.get_surface_count():
		var mat: Material = m.surface_get_material(i)
		var kind: String = mat.resource_name if mat != null else ""
		if kind == "rock":
			var rm: Material = MaterialLibrary.get_mat("rock")
			m.surface_set_material(i, rm if rm != null else Mats.get_mat("stone"))
		else:
			m.surface_set_material(i, tree_material(kind if kind != "" else "bark", near))
	_tree_meshes[key] = m
	return m


## The old cone pines' transforms scale x/z to about 0.41 of the height (the cone mesh was slim); the scripted
## trees are built to their real proportions, so they want a uniform scale. Keeps the yaw and the height, and the
## old width spread as +-12%.
static func uniform_tree_xform(xf: Transform3D) -> Transform3D:
	var h: float = xf.basis.y.length()
	var xc: Vector3 = xf.basis.x
	var yaw: float = atan2(-xc.z, xc.x)
	var k: float = clampf(xc.length() / maxf(0.01, h) / 0.41, 0.85, 1.15)
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(h * k, h, h * k)), xf.origin)


## True for about BIRCH_SHARE of positions (a stable hash of the spot, so the same tree is always a birch).
static func is_birch(p: Vector3) -> bool:
	return fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0) < BIRCH_SHARE


func _multimesh(name_: String, mesh: Mesh, xf: Array[Transform3D], mat: Material, aabb_grow: float = 20.0) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i: int in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if xf.size() > 0:
		mmi.custom_aabb = mm.get_aabb().grow(aabb_grow)
	add_child(mmi)
	return mmi


## Forest chunks by compass sector, so each MultiMesh is frustum-culled on its own. Mesh pines out to 225 m,
## impostor cards beyond and along the wooded ridge; the near strays use the map's own fog.
func _build_forests() -> void:
	var tr: Dictionary = LandscapeTerrain.forest_transforms(5.5, 9)
	var pm: ArrayMesh = pine_mesh()
	var far_pine: ShaderMaterial = _far_mat("pine.gdshader")
	var near_shader: Shader = Shader.new()
	near_shader.code = (load(PINE_SHADER) as Shader).code.replace(", fog_disabled", "")
	var near_pine: ShaderMaterial = ShaderMaterial.new()
	near_pine.shader = near_shader
	near_pine.set_shader_parameter("fog_max", 0.0)
	var sectors: int = 8
	var near_by: Array = []
	var mid_by: Array = []
	var card_by: Array = []
	for s: int in sectors:
		near_by.append([] as Array[Transform3D])
		mid_by.append([] as Array[Transform3D])
		card_by.append([] as Array[Transform3D])
	for xf: Transform3D in tr["mesh"]:
		var sec: int = int(LandscapeTerrain.bearing(xf.origin.x, xf.origin.z) / (360.0 / sectors)) % sectors
		if LandscapeTerrain.radius(xf.origin.x, xf.origin.z) < LandscapeTerrain.NEAR_R:
			(near_by[sec] as Array[Transform3D]).append(xf)
		else:
			(mid_by[sec] as Array[Transform3D]).append(xf)
	var cards: Array[Transform3D] = []
	for xf2: Transform3D in tr["cards"]:
		var hgt: float = xf2.basis.get_scale().y
		cards.append(Transform3D(Basis.from_scale(Vector3(hgt * 0.42, hgt, 1.0)), xf2.origin))
	cards.append_array(LandscapeTerrain.ridge_tree_transforms(2600, 17))
	for xf3: Transform3D in cards:
		var sec3: int = int(LandscapeTerrain.bearing(xf3.origin.x, xf3.origin.z) / (360.0 / sectors)) % sectors
		(card_by[sec3] as Array[Transform3D]).append(xf3)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1, 1)
	var card_mat: ShaderMaterial = _far_mat("impostor_pine.gdshader")
	var n_mesh: int = 0
	var n_card: int = 0
	var spruce_near: Mesh = tree_mesh("Spruce_LOD0", true)
	var scripted: bool = spruce_near != null
	if scripted:
		for m: String in ["needles", "bark", "twigs", "birch_bark"]:
			far_mats.append(tree_material(m, false))
	for s2: int in sectors:
		if scripted:   # T-093: the scripted spruces and birches (LOD0 near, LOD1 in the mid ring)
			for ring: int in 2:
				var src: Array = near_by[s2] if ring == 0 else mid_by[s2]
				# [spruce, birch] x [LOD0 (inside DETAIL_R), LOD1 (the rest of the near ring, and the mid ring)]
				var lists: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
				for xf4: Transform3D in src:
					var far_lod: bool = ring == 1 or LandscapeTerrain.radius(xf4.origin.x, xf4.origin.z) > DETAIL_R
					(lists[(1 if is_birch(xf4.origin) else 0) * 2 + (1 if far_lod else 0)] as Array[Transform3D]).append(uniform_tree_xform(xf4))
				var tag: String = "Near" if ring == 0 else "Mid"
				for li: int in 4:
					if (lists[li] as Array).is_empty():
						continue
					var kind: String = "Birch" if li >= 2 else "Spruce"
					var lod: String = "LOD1" if li % 2 == 1 else "LOD0"
					_multimesh("%s%s%s_%d" % [kind, tag, lod, s2], tree_mesh(kind + "_" + lod, ring == 0), lists[li], null)
		else:
			if (near_by[s2] as Array).size() > 0:
				_multimesh("PinesNear%d" % s2, pm, near_by[s2], near_pine)
			if (mid_by[s2] as Array).size() > 0:
				_multimesh("PinesMid%d" % s2, pm, mid_by[s2], far_pine)
		if (card_by[s2] as Array).size() > 0:
			_multimesh("PineCards%d" % s2, quad, card_by[s2], card_mat, 30.0)
		n_mesh += (near_by[s2] as Array).size() + (mid_by[s2] as Array).size()
		n_card += (card_by[s2] as Array).size()
	print("[landscape] forest: %d mesh pines, %d impostor cards" % [n_mesh, n_card])


# ================================================================== mist

## Mist cards: long soft bands lying in the valley behind the near crest and in front of the ridges.
func _build_mist() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 55
	var sh: Shader = _shader("mist_card.gdshader")
	var bands: Array = [[136.0, 2.5, 0.5, 22], [205.0, 7.0, 0.45, 26], [262.0, 12.0, 0.4, 30]]
	for band: Array in bands:
		var r: float = float(band[0])
		var count: int = int(band[3])
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("opacity", float(band[2]))
		m.set_shader_parameter("near_fade", r * 0.45)
		m.set_shader_parameter("soft", 8.0 + r * 0.03)
		mist_mats.append(m)
		for i: int in count:
			var b: float = 360.0 * (float(i) + rng.randf_range(-0.3, 0.3)) / float(count)
			var rr: float = r + rng.randf_range(-12.0, 12.0)
			var p: Vector3 = LandscapeTerrain.at_bearing(b, rr)
			var y: float = LandscapeTerrain.height(p.x, p.z) + float(band[1]) * rng.randf_range(0.6, 1.2)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Mist"
			var pl: PlaneMesh = PlaneMesh.new()
			pl.size = Vector2(rr * TAU / float(count) * 1.7, 40.0 + r * 0.12)
			mi.mesh = pl
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(p.x, y, p.z)
			mi.rotation.y = -deg_to_rad(b) + PI
			mi.rotation.x = deg_to_rad(rng.randf_range(-4.0, 4.0))
			add_child(mi)


# ================================================================== undergrowth (T-093)

## Bare winter bushes and snowed boulders on the near swell: clumps where the forest noise is high, along the forest
## edges, never on a road, the stream or the slab (nothing out here collides: it is all beyond the play edge).
func _build_undergrowth() -> void:
	if tree_mesh("Bush_A", true) == null:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 931
	var bushes: Array = [[] as Array[Transform3D], [] as Array[Transform3D]]
	var rocks: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var tries: int = 0
	while tries < 5200:
		tries += 1
		var b: float = rng.randf() * 360.0
		var r: float = rng.randf_range(62.0, 150.0)
		var p: Vector3 = LandscapeTerrain.at_bearing(b, r)
		if LandscapeTerrain.slab_distance(p.x, p.z) < 6.0 or LandscapeTerrain.road_distance(p.x, p.z) < 5.0 or LandscapeTerrain.stream_distance(p.x, p.z) < 4.5:
			continue
		var dens: float = LandscapeTerrain.forest_density(p.x, p.z) + 0.25 * LandscapeTerrain._u(LandscapeTerrain._n_forest, p.x * 3.0, p.z * 3.0)
		if rng.randf() > dens * 0.9:
			continue
		p.y = LandscapeTerrain.height(p.x, p.z)
		if rng.randf() < 0.72:
			var s: float = rng.randf_range(0.9, 1.7)
			(bushes[rng.randi() % 2] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), p - Vector3(0, 0.08, 0)))
		else:
			var s2: float = rng.randf_range(0.7, 2.2)
			(rocks[rng.randi() % 3] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2 * rng.randf_range(0.6, 1.0), s2)), p - Vector3(0, 0.2 * s2, 0)))
	for i: int in 2:
		if not (bushes[i] as Array).is_empty():
			_multimesh("Bushes%d" % i, tree_mesh("Bush_" + "AB"[i], true), bushes[i], null)
	for j: int in 3:
		if not (rocks[j] as Array).is_empty():
			_multimesh("Rocks%d" % j, tree_mesh("Rock_" + "ABC"[j], true), rocks[j], null)
	print("[landscape] undergrowth: %d bushes, %d rocks" % [(bushes[0] as Array).size() + (bushes[1] as Array).size(),
		(rocks[0] as Array).size() + (rocks[1] as Array).size() + (rocks[2] as Array).size()])


# ================================================================== the road and what was left on it

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, LandscapeTerrain.height(x, z), z)


func _build_road_story() -> void:
	var g: Node3D = Props.group(_static, "RoadStory", Vector3.ZERO)
	# the north road, just short of the bridge: the burnt field car in the ditch, cases strewn behind it
	LandscapeProps.burnt_car(g, _ground(-7.6, -50.5) + Vector3(0, -0.15, 0), 18.0, 9.0)
	LandscapeProps.suitcases(g, _ground(-11.5, -45.0), 4)
	LandscapeProps.suitcases(g, _ground(-10.0, -56.0), 5, 4)
	# the west road: the tipped cart on the verge, more cases, the fallen signpost at the old track
	LandscapeProps.tipped_cart(g, _ground(-64.0, -2.8), -70.0)
	LandscapeProps.suitcases(g, _ground(-72.0, -8.5), 6, 5)
	LandscapeProps.fallen_signpost(g, _ground(-57.5, -14.0), 25.0)
	# a second wreck far down the east road, a dark hulk against the snow
	LandscapeProps.burnt_car(g, _ground(118.0, -14.5) + Vector3(0, -0.1, 0), 100.0, -12.0)


## The telephone line along the crossroads road: wires strung on the six poles by the inn, then the line running
## on both ways into the dark, one pole leaning, one snapped with its wires on the ground.
func _build_telephone_line() -> void:
	var g: Node3D = Props.group(_static, "PhoneLine", Vector3.ZERO)
	var xs: Array[float] = []
	var x: float = -30.0
	while x > -292.0:
		xs.push_front(x)
		x -= 14.0 if x > -120.0 else 32.0
	xs.pop_back()   # -30 is in the existing six
	var existing: Array[float] = [-30.0, -16.0, -2.0, 12.0, 26.0, 40.0]
	var all_x: Array[float] = xs.duplicate()
	all_x.append_array(existing)
	x = 54.0
	while x < 296.0:
		all_x.append(x)
		x += 14.0 if x < 120.0 else 32.0
	var prev_tips: Array[Vector3] = []
	var prev_x: float = -1e9
	for px: float in all_x:
		var pz: float = _road_z(px) - 7.75
		var tips: Array[Vector3] = []
		if existing.has(px):   # gen_map00's poles: same tips (crossarm at 6.4..6.5, tilt +-2 deg about Z)
			var i: int = existing.find(px)
			var tilt: float = deg_to_rad(float(i % 2) * 4.0 - 2.0)
			for tx: float in [-0.75, -0.3, 0.3, 0.75]:
				var local: Vector3 = Vector3(tx, 6.5, 0).rotated(Vector3(0, 0, 1), tilt)
				tips.append(Vector3(px, 0, -15.5) + Vector3(local.x, local.y, 0))
				Props.cyl(g, Vector3(px, 0, -15.5) + Vector3(local.x, local.y - 0.06, 0), 0.03, 0.12, "stein")
		else:
			var base: Vector3 = _ground(px, pz)
			var lean: Vector2 = Vector2(0, 0)
			if absf(px + 72.0) < 1.0:
				lean = Vector2(14.0, 6.0)
			var snapped: bool = absf(px - 82.0) < 1.0
			if snapped:
				Props.cyl(g, base + Vector3(0, 1.1, 0), 0.12, 2.2, "beam")
				var top: Node3D = Props.group(g, "SnappedTop", base + Vector3(1.0, 0.2, 2.6), 70.0)
				top.rotation.z = deg_to_rad(84.0)
				Props.cyl(top, Vector3(0, 2.4, 0), 0.12, 4.8, "beam")
				tips = []
			else:
				tips = LandscapeProps.pole(g, base, 0.0, lean)
				if lean != Vector2.ZERO:
					tips = [] as Array[Vector3]   # the leaning pole's wires have come off
					for k: int in 3:
						LandscapeProps.wire(g, base + Vector3(-0.5 + k * 0.4, 5.6, 0), base + Vector3(-3.0 + k * 0.7, 0.05, 6.0 + k), 0.6, 4)
		if prev_tips.size() == tips.size() and tips.size() > 0 and px - prev_x < 40.0:
			for k2: int in tips.size():
				var span: float = prev_tips[k2].distance_to(tips[k2])
				LandscapeProps.wire(g, prev_tips[k2], tips[k2], span * 0.035 + 0.15, 6 if span < 20.0 else 8)
		elif tips.is_empty() and prev_tips.size() > 0:
			for k3: int in mini(2, prev_tips.size()):   # wires down from the last good pole
				LandscapeProps.wire(g, prev_tips[k3], _ground(px - 3.0 + k3, pz + 2.0), 1.2, 6)
		prev_tips = tips
		prev_x = px


## The road's centre-line z for an x along the crossroads road (the E-W polylines).
func _road_z(x: float) -> float:
	for r: Array in [LandscapeTerrain.ROADS[0], LandscapeTerrain.ROADS[1]]:
		for i: int in r.size() - 1:
			var a: Vector2 = r[i]
			var b: Vector2 = r[i + 1]
			if x >= minf(a.x, b.x) and x <= maxf(a.x, b.x):
				return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return -7.75


var _bank_rocks: Array[Transform3D] = []


func _build_stream_bridge() -> void:
	var b: Vector2 = LandscapeTerrain.BRIDGE
	var deck: float = maxf(LandscapeTerrain.height(b.x, b.y - 6.0), LandscapeTerrain.height(b.x, b.y + 6.0)) - 0.25
	LandscapeProps.stone_bridge(_static, Vector3(b.x, deck, b.y), 0.0)
	# snowed boulders and reed stubble along the banks
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 64
	for i: int in 22:
		var t: float = rng.randf_range(-40.0, 40.0)
		var p: Vector2 = Vector2(b.x + t, b.y + t * 0.03)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var q: Vector3 = _ground(p.x, p.y + side * rng.randf_range(3.2, 5.0))
		if absf(t) < 5.0:
			continue
		var sz: Vector3 = Vector3(rng.randf_range(0.6, 1.6), rng.randf_range(0.35, 0.8), rng.randf_range(0.6, 1.4))
		if rng.randf() < 0.6:
			Props.ball(_static, q, sz, "snow")
		else:   # T-093: real boulders on the banks
			_bank_rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sz * 1.2), q - Vector3(0, 0.15, 0)))
	if not _bank_rocks.is_empty() and tree_mesh("Rock_A", true) != null:
		_multimesh("BankRocks", tree_mesh("Rock_A", true), _bank_rocks, null)


# ================================================================== the farmhouse, the church, the burning town

func _build_farm_and_church() -> void:
	var solid: ShaderMaterial = _far_mat("far_solid.gdshader")
	farm_pos = LandscapeTerrain.at_bearing(FARM_BEARING, FARM_R)
	farm_pos.y = LandscapeTerrain.height(farm_pos.x, farm_pos.z) - 0.5
	var farm_holder: Node3D = Node3D.new()
	farm_holder.name = "FarmHolder"
	add_child(farm_holder)
	farm_window = LandscapeProps.farmhouse(farm_holder, farm_pos, -FARM_BEARING + 180.0 - 25.0, solid)
	church_pos = LandscapeTerrain.at_bearing(CHURCH_BEARING, LandscapeTerrain.RIDGE_A.y - 2.0)
	church_pos.y = LandscapeTerrain.ridge_crest(0, CHURCH_BEARING) * 0.96 - 1.0
	LandscapeProps.church(farm_holder, church_pos, -CHURCH_BEARING + 90.0, solid)


## The town burning beyond the eastern ridge: fire glows peeking over the crest and a smoke column lit from below.
func _build_town() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 64
	town_pos = LandscapeTerrain.at_bearing(TOWN_BEARING, 330.0)
	var crest: float = LandscapeTerrain.ridge_crest(0, TOWN_BEARING)
	for i: int in 9:
		var b: float = TOWN_BEARING + rng.randf_range(-5.0, 5.0)
		var p: Vector3 = LandscapeTerrain.at_bearing(b, rng.randf_range(318.0, 338.0))
		p.y = crest * rng.randf_range(0.6, 1.05)
		var s: MeshInstance3D = LandscapeProps.glow_sprite(p, rng.randf_range(14.0, 30.0), Color(1.0, 0.42, 0.12), rng.randf_range(0.35, 0.7))
		s.name = "TownFire"
		add_child(s)
		town_fires.append(s)
	var smoke: GPUParticles3D = GPUParticles3D.new()
	smoke.name = "TownSmoke"
	smoke.amount = 16
	smoke.lifetime = 26.0
	smoke.preprocess = 26.0
	smoke.position = LandscapeTerrain.at_bearing(TOWN_BEARING, 298.0) + Vector3(0, crest * 0.7, 0)
	smoke.visibility_aabb = AABB(Vector3(-120, -20, -120), Vector3(240, 260, 240))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 4, 18)
	pm.direction = Vector3(-0.3, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 3.6
	pm.gravity = Vector3(-0.06, 0.1, 0.02)
	pm.scale_min = 1.0
	pm.scale_max = 1.6
	pm.scale_curve = Props._curve_tex([[0.0, 0.4], [1.0, 1.0]])
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.5, 0.2, 0.08, 0.0)], [0.12, Color(0.35, 0.14, 0.07, 0.4)], [0.5, Color(0.1, 0.09, 0.1, 0.32)], [1.0, Color(0.06, 0.07, 0.09, 0.0)]])
	smoke.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(34, 34)
	var m: StandardMaterial3D = Props._particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	m.disable_fog = true
	q.material = m
	smoke.draw_pass_1 = q
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)


# ================================================================== the crash site

## GRAVELIGHT ONE, burning harder: more flames along the wing root and an engine, little fires in the snow, the
## crushed cockpit where the pilot sits pinned (T-126: TrappedPilot), the hold's cargo thrown about, a parachute
## caught in a tree. The hull is hollow since T-126, so the fires and the cook-offs stay outside the cabin.
func _build_crash_site() -> void:
	var w: Node3D = Node3D.new()
	w.name = "WreckExtras"
	w.position = WRECK_POS
	w.rotation = Vector3(0, deg_to_rad(WRECK_YAW), deg_to_rad(WRECK_ROLL))
	add_child(w)
	wreck_node = w
	var ws: Node3D = Node3D.new()   # the static part (batched)
	ws.name = "WreckStatic"
	ws.transform = w.transform
	_static.add_child(ws)
	LandscapeProps.pinned_cockpit(ws)
	Props.flames(w, Vector3(3.2, 1.3, -1.0), 1.1, 1.3, 24)       # the starboard engine
	Props.flames(w, Vector3(-6.0, 0.8, 0.3), 1.6, 1.0, 22)       # along the port wing
	Props.flames(w, Vector3(-2.3, 0.7, 4.2), 1.2, 1.1, 18)       # the hold's cargo, burning in the snow off the port side
	Props.embers(w, Vector3(-4.0, 1.2, 0.0), 3.5, 30)
	Props.smoke(w, Vector3(-5.0, 2.0, 0.5), 0.8, 1.8, 18)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2341
	for i: int in 4:   # small fires in the snow among the debris
		var p: Vector3 = WRECK_POS + Vector3(rng.randf_range(-10, 10), 0.05, rng.randf_range(-9, 10))
		Props.flames(self, p, 0.5, 0.5, 8)
		Props._noshadow(Props.cyl(_static, p + Vector3(0, -0.04, 0), 0.9, 0.02, "char"))
	for lp: Vector3 in [Vector3(0, 2.95, -2.5), Vector3(-2.3, 1.0, 3.0), Vector3(-3.2, 1.0, -1.0), Vector3(3.2, 1.2, -0.8), Vector3(-2.4, 1.0, 4.6)]:
		cookoff_points.append(w.transform * lp)
	# a dark melt around the hull, the fire's warm pool on the snow
	Props._noshadow(Props.cyl(_static, WRECK_POS + Vector3(0, 0.005, 0), 9.0, 0.012, "dirt"))
	var pool: MeshInstance3D = MeshInstance3D.new()
	pool.name = "FirePool"
	var pl: PlaneMesh = PlaneMesh.new()
	pl.size = Vector2(26, 26)
	pool.mesh = pl
	var pm: StandardMaterial3D = LandscapeProps.glow_material(Color(1.0, 0.4, 0.12), 0.22)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	pm.disable_fog = false
	pool.material_override = pm
	pool.position = WRECK_POS + Vector3(-1.0, 0.03, 0.5)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	LandscapeProps.scattered_cargo(_static, WRECK_POS + Vector3(-9.0, 0, 9.0), 77)
	parachute_load = LandscapeProps.parachute_tree(self, Vector3(39.5, 0, 24.5), 4401)


# ================================================================== the inn's own details

func _build_inn_details() -> void:
	# icicles on the eaves: the inn's front and back, the porch roofs, the stable's long sides
	for e: Array in [[Vector3(-0.5, 6.93, -0.98), Vector3(24.5, 6.93, -0.98)], [Vector3(6.2, 6.93, 10.98), Vector3(24.5, 6.93, 10.98)],
			[Vector3(1.55, 3.77, -2.44), Vector3(6.45, 3.77, -2.44)], [Vector3(17.55, 3.77, -2.44), Vector3(22.45, 3.77, -2.44)],
			[Vector3(5.7, 7.12, 34.5), Vector3(24.5, 7.12, 34.5)], [Vector3(5.7, 7.12, 21.5), Vector3(24.5, 7.12, 21.5)]]:
		LandscapeProps.icicles(self, e[0], e[1], int((e[0] as Vector3).x * 10.0 + (e[0] as Vector3).z))
	# the inn sign on its bracket over the road side
	var br: Node3D = Props.group(_static, "SignBracket", Vector3(11.8, 3.15, -0.27), 0.0)
	Props.block(br, Vector3(-0.04, -0.04, -1.45), Vector3(0.04, 0.04, 0.0), "iron")
	Props.obox(br, Vector3(0, -0.32, -0.35), Vector3(0.03, 0.03, 0.85), "iron", Vector3(-40, 0, 0))
	Props.block(br, Vector3(-0.1, -0.5, -0.06), Vector3(0.1, 0.1, 0.0), "iron")
	inn_sign = Node3D.new()
	inn_sign.name = "InnSign"
	inn_sign.position = Vector3(11.8, 3.11, -1.3)
	add_child(inn_sign)
	for sx: float in [-0.32, 0.32]:
		Props.block(inn_sign, Vector3(sx - 0.01, -0.22, -0.01), Vector3(sx + 0.01, 0.0, 0.01), "iron")
	var board: MeshInstance3D = Props.block(inn_sign, Vector3(-0.45, -0.88, -0.03), Vector3(0.45, -0.22, 0.03), "planks")
	board.set_meta("keep", true)
	Props.block(inn_sign, Vector3(-0.47, -0.25, -0.04), Vector3(0.47, -0.2, 0.04), "snow", false)
	for side: float in [-1.0, 1.0]:
		var l: Label3D = Label3D.new()
		l.text = "GASTHAUS\nZUM KREUZWEG"
		l.font_size = 40
		l.pixel_size = 0.0042
		l.modulate = Color(0.78, 0.66, 0.42, 0.9)
		l.outline_size = 0
		l.position = Vector3(0, -0.47, 0.035 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		inn_sign.add_child(l)
		var cross: Label3D = Label3D.new()
		cross.text = "X"
		cross.font_size = 64
		cross.pixel_size = 0.004
		cross.modulate = Color(0.6, 0.2, 0.15, 0.85)
		cross.outline_size = 0
		cross.position = Vector3(0, -0.76, 0.036 * side)
		cross.rotation.y = 0.0 if side > 0 else PI
		inn_sign.add_child(cross)
	# the hayloft door over the stable's great doors: a dark opening, its frame, one leaf loose on its hinge
	var hl: Node3D = Props.group(_static, "HayloftOpening", Vector3(18.0, 4.9, 34.17), 0.0)
	Props.block(hl, Vector3(-0.9, 0, 0), Vector3(0.9, 1.6, 0.02), "window_dark")
	Props.block(hl, Vector3(-1.02, -0.1, 0), Vector3(-0.9, 1.72, 0.12), "beam")
	Props.block(hl, Vector3(0.9, -0.1, 0), Vector3(1.02, 1.72, 0.12), "beam")
	Props.block(hl, Vector3(-1.05, 1.6, 0), Vector3(1.05, 1.74, 0.14), "beam")
	Props.block(hl, Vector3(-1.05, -0.14, 0), Vector3(1.05, 0.0, 0.2), "beam")
	Props.block(hl, Vector3(-1.05, 0.0, 0.0), Vector3(1.05, 0.06, 0.2), "snow", false)
	Props.obox(hl, Vector3(0.45, 0.8, 0.07), Vector3(0.88, 1.56, 0.05), "planks", Vector3(0, 0, 0))   # the leaf that holds
	Props.cyl(hl, Vector3(0.0, 1.95, 0.6), 0.04, 1.2, "iron", Vector3(90, 0, 0))                      # the hay hoist beam
	Props.block(hl, Vector3(-0.08, 1.74, 0.0), Vector3(0.08, 1.9, 1.2), "beam")
	hayloft_door = Node3D.new()
	hayloft_door.name = "HayloftDoor"
	hayloft_door.position = Vector3(17.1, 4.9, 34.25)
	add_child(hayloft_door)
	var leaf: MeshInstance3D = Props.block(hayloft_door, Vector3(0.0, 0.03, -0.025), Vector3(0.88, 1.58, 0.025), "planks")
	leaf.set_meta("keep", true)
	Props.obox(hayloft_door, Vector3(0.44, 0.8, 0.035), Vector3(0.08, 1.4, 0.02), "beam", Vector3(0, 0, 40)).set_meta("keep", true)
	Props.block(hayloft_door, Vector3(0.05, 1.2, 0.03), Vector3(0.8, 1.26, 0.05), "iron").set_meta("keep", true)


# ================================================================== light

## Moonlight leaking into the stable through gaps in its south and east boards: bright slits, soft dusty shafts
## along the moon's direction, and two volumetric spots so the fog inside catches the beams.
func _build_stable_light() -> void:
	var moon: DirectionalLight3D = get_parent().find_child("Moon", false, false) as DirectionalLight3D if get_parent() != null else null
	var d: Vector3 = Vector3(-0.36, -0.64, -0.68)
	if moon != null:
		d = -moon.global_transform.basis.z.normalized()
	var slit_m: StandardMaterial3D = StandardMaterial3D.new()
	slit_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slit_m.albedo_color = Color(0.55, 0.66, 0.95)
	var beam_sh: Shader = _shader("light_beam.gdshader")
	var shaft_m: ShaderMaterial = ShaderMaterial.new()
	shaft_m.shader = beam_sh
	shaft_m.set_shader_parameter("color", Vector3(0.55, 0.65, 1.0))
	shaft_m.set_shader_parameter("intensity", 0.11)
	shaft_m.set_shader_parameter("length_falloff", 1.1)
	shaft_m.set_shader_parameter("edge_power", 2.2)
	shaft_m.set_shader_parameter("near_fade", 1.2)
	shaft_m.set_shader_parameter("flow", 0.08)
	var g: Node3D = Node3D.new()
	g.name = "StableMoonLeaks"
	add_child(g)
	# [wall point on the inner face, slit length along the wall, along-wall axis]
	var slits: Array = [[Vector3(9.2, 5.6, 33.84), 1.7, Vector3.RIGHT], [Vector3(12.9, 6.1, 33.84), 1.2, Vector3.RIGHT], [Vector3(14.6, 2.9, 33.84), 1.4, Vector3.RIGHT],
		[Vector3(23.84, 5.2, 26.0), 1.5, Vector3.BACK], [Vector3(23.84, 3.0, 30.6), 1.1, Vector3.BACK], [Vector3(23.84, 6.2, 31.8), 1.3, Vector3.BACK]]
	for s: Array in slits:
		var p: Vector3 = s[0]
		var along: Vector3 = s[2]
		var lenw: float = float(s[1])
		var slit: MeshInstance3D = MeshInstance3D.new()
		slit.mesh = Props.unit_box()
		slit.material_override = slit_m
		slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slit.position = p
		slit.scale = (along * lenw + Vector3(0.0, 0.035, 0.0) + (Vector3(0, 0, 0.012) if along == Vector3.RIGHT else Vector3(0.012, 0, 0))).abs()
		g.add_child(slit)
		# the shaft: two crossed sheets from the slit down the moon direction toward the floor
		var shaft_len: float = minf(0.82 * p.y / maxf(0.2, -d.y), 7.0)
		var mid: Vector3 = p + d * shaft_len * 0.5
		var side: Vector3 = (along - d * along.dot(d)).normalized()
		var across: Vector3 = d.cross(side).normalized()
		for sheet: Array in [[side, lenw], [across, 0.32]]:
			var q: QuadMesh = QuadMesh.new()
			q.size = Vector2(float(sheet[1]), shaft_len)
			var shaft: MeshInstance3D = MeshInstance3D.new()
			shaft.mesh = q
			shaft.material_override = shaft_m
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var xa: Vector3 = sheet[0]
			shaft.transform = Transform3D(Basis(xa, d, xa.cross(d).normalized()), mid)
			shaft.set_meta(&"clearance_ignore", true)   # light, not a thing in a doorway (DoorClearance, T-072)
			g.add_child(shaft)
			shaft.set_instance_shader_parameter("beam_len", shaft_len)
	# T-061: brighter and wider (a third over the middle of the floor); the stripes themselves are decals, below
	for sp: Array in [[Vector3(12.0, 6.0, 34.6), 3.0], [Vector3(24.6, 5.4, 28.0), 2.5], [Vector3(18.3, 5.8, 34.6), 3.0]]:
		var s2: SpotLight3D = SpotLight3D.new()
		s2.name = "MoonLeakSpot"
		s2.light_color = Color(0.55, 0.66, 1.0)
		s2.light_energy = float(sp[1])
		s2.light_volumetric_fog_energy = 1.2
		s2.spot_range = 12.0
		s2.spot_angle = 13.0
		s2.spot_attenuation = 0.6
		s2.shadow_enabled = false
		add_child(s2)
		s2.global_position = sp[0]
		s2.look_at(s2.global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	# where the slits' moonlight lands on the straw: cold stripes of board gaps (emissive decals, so they read
	# even under the lanterns and stay when the Cousins put the lamps out). T-061 pass 2.
	var stripes: ImageTexture = _board_gap_texture()
	for s3: Array in slits:
		var p3: Vector3 = s3[0]
		var land: Vector3 = p3 + d * (p3.y / maxf(0.2, -d.y))
		if land.x < 6.6 or land.x > 23.4 or land.z < 22.6 or land.z > 33.4:
			continue   # lands under a wall or outside the stable
		var dc: Decal = Decal.new()
		dc.name = "MoonStripes"
		dc.size = Vector3(float(s3[1]) * 1.1, 0.8, 1.4)
		dc.texture_emission = stripes
		dc.emission_energy = 1.0
		dc.modulate = Color(0.55, 0.66, 1.0)
		dc.cull_mask = 1
		add_child(dc)
		dc.global_position = land + Vector3(0, 0.1, 0)
		# the bars run along the slit (local X along the wall), stretched along the moon's direction across it
		dc.rotation.y = 0.0 if s3[2] == Vector3.RIGHT else PI * 0.5


## Moonlight through gaps between boards (T-061): a few bright bars of uneven width on black, for the MoonStripes decals.
func _board_gap_texture() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for bar: Array in [[6, 3], [17, 5], [29, 2], [38, 4], [51, 3]]:
		for x: int in range(int(bar[0]), int(bar[0]) + int(bar[1])):
			for y: int in 64:
				var edge: float = 1.0 - absf(float(y) - 31.5) / 32.0
				img.set_pixel(x, y, Color(1, 1, 1) * clampf(edge * 2.5, 0.0, 1.0))
	return ImageTexture.create_from_image(img)


## Ground fog over the east field (around the wreck) and a thinner skin over the yard and the road: FogVolumes,
## so the volumetric fog thickens where the fire and the flares can light it.
func _build_field_fog() -> void:
	if GLSettings.is_compat():
		return   # T-139: no volumetric fog on the Compatibility renderer (its fog shader can't even compile there)
	var noise: NoiseTexture3D = NoiseTexture3D.new()
	noise.width = 48
	noise.height = 16
	noise.depth = 48
	noise.seamless = true
	var fn: FastNoiseLite = FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.05
	fn.seed = 12
	noise.noise = fn
	for f: Array in [[Vector3(52, 1.2, 8), Vector3(44, 3.0, 64), 0.09], [Vector3(18, 0.9, 52), Vector3(52, 2.2, 16), 0.05], [Vector3(10, 1.0, -9), Vector3(90, 2.4, 16), 0.05]]:
		var fv: FogVolume = FogVolume.new()
		fv.name = "GroundFog"
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = f[1]
		fv.position = f[0]
		var fm: FogMaterial = FogMaterial.new()
		fm.density = float(f[2])
		fm.albedo = Color(0.8, 0.84, 0.92)
		fm.height_falloff = 0.6
		fm.edge_fade = 0.35
		fm.density_texture = noise
		fv.material = fm
		add_child(fv)


# ================================================================== batching

## Merges the static primitives built under `holder` into one ArrayMesh per (material, shadow mode, 48 m cell),
## like gen_map00's merge_static_meshes. Meshes with the "keep" meta stay as they are.
func _batch(holder: Node3D) -> int:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or mi.has_meta("keep"):
			continue
		var xf: Transform3D = _xform_to(mi, holder)
		var c: Vector3 = xf.origin
		var cell: Vector3i = Vector3i(floori(c.x / 48.0), 0, floori(c.z / 48.0))
		var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	var out_root: Node3D = Node3D.new()
	out_root.name = "Batches"
	add_child(out_root)
	for key: String in groups.keys():
		var gr: Dictionary = groups[key]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.mesh = (gr["st"] as SurfaceTool).commit()
		out.material_override = gr["mat"]
		out.cast_shadow = gr["shadow"]
		out_root.add_child(out)
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	return victims.size()


func _xform_to(n: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return root.transform * xf
