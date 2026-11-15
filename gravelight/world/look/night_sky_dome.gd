class_name NightSkyDome
extends MeshInstance3D
## UPDATE 19 (T-252): a night sky for a map that has no Landscape (Totenhafen): the Crossroads' sky dome shader
## (gravelight/world/landscape/shaders/sky_dome.gdshader: a cloud deck with breaks, the moon behind it, stars in the
## gaps) on a sphere that follows the camera just inside its far plane. LookGrade.attach adds one when the map's
## grade (data/look/<map_id>.json) has a `sky_dome` block; the block's keys are the shader's uniforms (a "#rrggbb"
## string or [r, g, b] for a colour or a direction), plus `moon_light`: the name of the DirectionalLight3D the moon
## stands behind (default "Moon"; no such light = the block's own `moon_dir`).
## Unshaded and outside the Environment: the map's ambient, reflections and SDFGI still read the Environment's own
## sky, so no room changes brightness. Presentation only.

const SHADER: String = "res://gravelight/world/landscape/shaders/sky_dome.gdshader"
const NODE_NAME: String = "NightSkyDome"


static func add_to(map: Node, params: Dictionary) -> NightSkyDome:
	if map == null or params.is_empty() or not ResourceLoader.exists(SHADER):
		return null
	var old: Node = map.get_node_or_null(NODE_NAME)
	if old is NightSkyDome:
		return old as NightSkyDome
	var d: NightSkyDome = NightSkyDome.new()
	d.name = NODE_NAME
	d.setup(map, params)
	map.add_child(d)
	return d


func setup(map: Node, params: Dictionary) -> void:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mesh = sm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	scale = Vector3(370, 370, 370)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SHADER) as Shader
	var zero8: PackedVector4Array = PackedVector4Array()
	zero8.resize(8)
	mat.set_shader_parameter("flashes", zero8)
	mat.set_shader_parameter("flash_cols", zero8)
	var zero4: PackedVector4Array = PackedVector4Array()
	zero4.resize(4)
	mat.set_shader_parameter("beams", zero4)
	mat.set_shader_parameter("town_strength", 0.0)
	var moon: DirectionalLight3D = map.find_child(str(params.get("moon_light", "Moon")), true, false) as DirectionalLight3D
	if moon != null:
		mat.set_shader_parameter("moon_dir", moon.transform.basis.z.normalized())
	for k: Variant in params.keys():
		if str(k) == "moon_light" or str(k).begins_with("_"):
			continue
		mat.set_shader_parameter(str(k), value_of(params[k]))
	material_override = mat


## A block value as a uniform: "#rrggbb" a colour, [x, y, z] a Vector3, [x, y] a Vector2, anything else as it is.
static func value_of(v: Variant) -> Variant:
	if v is String and (v as String).begins_with("#"):
		return LookGrade.color(v)
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return v


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		global_position = cam.global_position
		var r: float = cam.far * 0.97
		scale = Vector3(r, r, r)
