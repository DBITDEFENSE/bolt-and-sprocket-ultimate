class_name ThalbachSky
extends Node3D
## Werk Thalbach's sky (UPDATE 09 §5, docs/MAPS_3_4_REBUILD.md §3 "Fernflug Act I", DECISIONS T-146): the works'
## searchlights sweeping a low cloud deck (each beam's spot glows where it hits the clouds), the dawn that never
## comes (a cold mauve band low in the east that never brightens, on the clouds and on the horizon), and the
## forest ridges round the valley as dark silhouettes. Presentation only: no gameplay reads it and every co-op
## peer runs its own. Cheap: one mesh per beam, one cloud plane, one horizon band, one ridge mesh (no lights).
## The generator (gen_map04a) places it with the beam bases; it builds itself in _ready.

const BEAM_SHADER: String = "res://gravelight/world/landscape/shaders/light_beam.gdshader"
const CLOUD_SHADER: String = "res://gravelight/world/shaders/cloud_deck.gdshader"

## Where the searchlights stand (on the works' roofs and towers).
@export var bases: PackedVector3Array = PackedVector3Array([Vector3(-66, 12, 64), Vector3(42, 10, 32), Vector3(36, 22, 212), Vector3(-72, 24, 150)])
@export var cloud_y: float = 120.0
@export var beam_len: float = 175.0
@export var intensity: float = 0.14
@export var sweep_deg: float = 38.0
## Compass direction (degrees, 0 = +Z north, 90 = +X east) of the dawn that never comes.
@export var dawn_bearing: float = 100.0
@export var ridge_radius: float = 520.0

var _beams: Array = []
var _cloud_mat: ShaderMaterial
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1945
	_build_clouds()
	_build_beams()
	_build_horizon()
	_build_ridges()
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


## Pure: the beam's direction at time t (azimuth swings `sweep` degrees round `bearing`, elevation between 48° and
## 74°), for the tests and the spot on the clouds.
static func beam_dir(bearing: float, phase: float, speed: float, t: float, sweep: float) -> Vector3:
	var ph: float = phase + t * speed
	var az: float = deg_to_rad(bearing + sweep * sin(ph))
	var el: float = deg_to_rad(lerpf(48.0, 74.0, 0.5 + 0.5 * sin(ph * 0.61 + 1.3)))
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()


func _build_beams() -> void:
	var sh: Shader = load(BEAM_SHADER) as Shader
	for i: int in bases.size():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Beam%d" % i
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 6.5
		cm.bottom_radius = 0.45
		cm.height = beam_len
		cm.radial_segments = 14
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("color", Vector3(0.78, 0.83, 0.92))
		m.set_shader_parameter("intensity", intensity)
		m.set_shader_parameter("length_falloff", 1.2)
		m.set_shader_parameter("edge_power", 2.6)
		m.set_shader_parameter("near_fade", 12.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 40.0
		add_child(mi)
		mi.set_instance_shader_parameter("beam_len", beam_len)
		# each beam sweeps away from the works' centre, at its own pace
		var c: Vector3 = Vector3(-20, 0, 110)
		var out: Vector3 = (bases[i] - c)
		var bearing: float = rad_to_deg(atan2(out.x, out.z))
		_beams.append({"mi": mi, "base": bases[i], "bearing": bearing, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.07, 0.15)})


func _build_clouds() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CloudDeck"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	mi.mesh = pm
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = load(CLOUD_SHADER) as Shader
	var dd: Vector3 = Vector3(sin(deg_to_rad(dawn_bearing)), 0, cos(deg_to_rad(dawn_bearing)))
	_cloud_mat.set_shader_parameter("dawn_dir", dd)
	mi.material_override = _cloud_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-20, cloud_y, 110)
	mi.extra_cull_margin = 200.0
	add_child(mi)


## The false dawn: a tall band low on the eastern horizon under the clouds, mauve-grey, never brighter.
func _build_horizon() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "FalseDawn"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1500, 260)
	mi.mesh = q
	var sh: Shader = Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;\n" \
		+ "uniform vec4 tint : source_color = vec4(0.2, 0.15, 0.19, 1.0);\n" \
		+ "void fragment() { float v = 1.0 - UV.y; float h = smoothstep(0.0, 0.18, v) * pow(1.0 - v, 2.2); float s = pow(sin(UV.x * 3.14159), 2.0);\n" \
		+ "ALBEDO = tint.rgb * h * s; }\n"
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dd: Vector3 = Vector3(sin(deg_to_rad(dawn_bearing)), 0, cos(deg_to_rad(dawn_bearing)))
	mi.position = Vector3(-20, 95, 110) + dd * (ridge_radius + 120.0)
	mi.look_at_from_position(mi.position, Vector3(-20, 95, 110), Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	mi.extra_cull_margin = 200.0
	add_child(mi)


## The forest ridges round the valley: one mesh of dark prisms on a ring (no lights reach them; the fog does).
func _build_ridges() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 40
	var prev: Vector3 = Vector3.ZERO
	var prev_top: Vector3 = Vector3.ZERO
	for i: int in n + 1:
		var a: float = TAU * float(i) / float(n)
		var r: float = ridge_radius * (0.92 + 0.16 * sin(a * 3.0 + 0.7))
		var h: float = 70.0 + 45.0 * (0.5 + 0.5 * sin(a * 5.0 + 1.9)) + 25.0 * sin(a * 11.0)
		var p: Vector3 = Vector3(-20, -2, 110) + Vector3(sin(a), 0, cos(a)) * r
		var top: Vector3 = p + Vector3(0, h, 0)
		if i > 0:
			# a wall of the ridge facing the works (wound to face inward)
			st.add_vertex(prev)
			st.add_vertex(top)
			st.add_vertex(p)
			st.add_vertex(prev)
			st.add_vertex(prev_top)
			st.add_vertex(top)
		prev = p
		prev_top = top
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ridges"
	mi.mesh = st.commit()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.025, 0.03)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 100.0
	add_child(mi)


func _update(_delta: float) -> void:
	var spots: Array = []
	for b: Dictionary in _beams:
		var d: Vector3 = beam_dir(float(b["bearing"]), float(b["phase"]), float(b["speed"]), _t, sweep_deg)
		var mi: MeshInstance3D = b["mi"]
		var x: Vector3 = d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
		var base: Vector3 = b["base"]
		mi.transform = Transform3D(Basis(x, d, x.cross(d)), base + d * beam_len * 0.5)
		var k: float = (cloud_y - base.y) / maxf(0.05, d.y)
		var hit: Vector3 = base + d * k
		spots.append(Vector4(hit.x, hit.y, hit.z, 0.9 if k < beam_len * 1.4 else 0.25))
	while spots.size() < 4:
		spots.append(Vector4(0, -1000, 0, 0))
	if _cloud_mat != null:
		_cloud_mat.set_shader_parameter("spots", PackedVector4Array(spots.slice(0, 4)))
