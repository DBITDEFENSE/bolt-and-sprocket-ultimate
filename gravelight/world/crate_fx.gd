extends RefCounted
## T-254 (UPDATE 19): the light the Requisition Crate and the Crucible make. Small unshaded additive meshes with
## their own shaders (no light, no shadow, no texture file; they work in Forward+ and in the Compatibility renderer):
##   beacon()   the locator: a column of pale ashlight that widens as it climbs, soft at its edges, fading in over
##              its first metres and out toward the top; fog does not eat it (it has to read from across the map)
##   spill()    the light that stands out of the open crate: four soft faces of a tapering shaft with slow streaks
##   halo()     a soft round glow that always faces the camera (the lantern from afar, the offered weapon's bed)
##   ring()     a flat ring that runs outward once (the settle's flourish): drive "progress" 0..1
##   pool()     the floor under a crate that leaves or arrives: a ring of light with turning spokes, "radius" 0..1
##   rim_mat()  an overlay for a model that hangs in that light: a violet fresnel edge over its own materials
##   soot_mat() a soft-edged, uneven dark stain (scorch on a wall, soot under a vault, ash on a floor)
## (No class_name: MysteryCrate, Crucible and CrucibleRoom preload it, so a fresh checkout works before the editor
## rebuilds its class cache.)

const ASH: Color = Color(0.72, 0.6, 1.0)        # the pale end of the Marke's violet: the locator
const MARKE: Color = Color(0.62, 0.34, 1.0)     # the crate's own light

const BEACON_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.72, 0.6, 1.0);
uniform float energy = 0.5;
uniform float height = 60.0;
uniform float foot = 3.0;
varying float h;
void vertex() {
	h = VERTEX.y + height * 0.5;
}
void fragment() {
	float rim = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = rim * rim;
	float low = smoothstep(0.0, foot, h);
	float top = 1.0 - smoothstep(height * 0.45, height, h);
	float drift = 0.84 + 0.16 * sin(TIME * 1.3 + h * 0.4);
	ALBEDO = tint * energy * core * low * top * drift;
}
"""

const SPILL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.62, 0.34, 1.0);
uniform float energy = 0.0;
uniform float height = 1.7;
varying float h;
void vertex() {
	h = VERTEX.y / height + 0.5;
}
void fragment() {
	float rim = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = rim * rim * rim;
	float up = pow(clamp(1.0 - h, 0.0, 1.0), 2.4);
	float streak = 0.8 + 0.2 * sin(UV.x * 41.0 + TIME * 0.9) * sin(UV.x * 17.0 - TIME * 0.6);
	ALBEDO = tint * energy * core * up * streak * smoothstep(0.0, 0.05, h);
}
"""

const RING_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.62, 0.34, 1.0);
uniform float energy = 1.0;
uniform float progress = 0.0;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float band = smoothstep(0.09, 0.0, abs(r - progress * 0.92));
	float inner = smoothstep(progress * 0.92, 0.0, r) * 0.12;
	ALBEDO = tint * energy * (band + inner) * (1.0 - progress) * step(r, 1.0);
}
"""

const POOL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.62, 0.34, 1.0);
uniform float energy = 0.9;
uniform float radius = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = smoothstep(0.1, 0.0, abs(r - radius)) * step(0.02, radius);
	float spokes = 0.5 + 0.5 * sin(a * 9.0 + TIME * 2.2 + r * 9.0);
	float body = smoothstep(radius, radius * 0.2, r) * (0.18 + 0.3 * spokes) * step(r, radius);
	ALBEDO = tint * energy * (edge + body);
}
"""

const RIM_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.62, 0.34, 1.0);
uniform float energy = 1.4;
void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float flick = 0.85 + 0.15 * sin(TIME * 21.0);
	ALBEDO = tint * energy * (0.22 + pow(f, 1.6)) * flick;
}
"""

## `strength` scales the whole stain (the Crucible room breathes it with the fire); `seed` shifts the pattern.
const SOOT_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;
uniform vec3 tint : source_color = vec3(0.015, 0.013, 0.012);
uniform float strength = 0.85;
uniform float seed = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - centre) * 2.0;
	float n = noise(UV * 5.0) * 0.6 + noise(UV * 13.0) * 0.3 + noise(UV * 31.0) * 0.1;
	float r = length(p) + (n - 0.5) * 0.55;
	float a = smoothstep(1.0, 0.15, r);
	float edge = smoothstep(1.0, 0.7, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * edge * strength * (0.7 + 0.5 * n), 0.0, 0.96);
}
"""

static var _shaders: Dictionary = {}
static var _meshes: Dictionary = {}
static var _halo_tex: GradientTexture2D


static func shader(code_key: String, code: String) -> Shader:
	if not _shaders.has(code_key):
		var s: Shader = Shader.new()
		s.code = code
		_shaders[code_key] = s
	return _shaders[code_key]


static func _mat(code_key: String, code: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader(code_key, code)
	return m


static func _fx(mesh: Mesh, mat: Material, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi


## The locator column, `height` tall, standing on its own origin. Drive "energy" (and "foot": the metres over which
## it fades in from its base).
static func beacon(height: float = 60.0, base_r: float = 0.24, top_r: float = 1.0) -> MeshInstance3D:
	var key: String = "beacon_%.1f" % height
	if not _meshes.has(key):
		var c: CylinderMesh = CylinderMesh.new()
		c.height = height
		c.bottom_radius = base_r
		c.top_radius = top_r
		c.radial_segments = 14
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_meshes[key] = c
	var m: ShaderMaterial = _mat("beacon", BEACON_SHADER)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("tint", ASH)
	var mi: MeshInstance3D = _fx(_meshes[key], m, "Beacon")
	mi.position.y = height * 0.5
	mi.extra_cull_margin = 4.0
	return mi


## The light that stands out of an open box: a soft oval shaft from y0 up `height` metres, `half` its half extents
## at the box, widening as it rises; no edges (it fades where its surface turns away from the eye) and gone by its top.
static func spill(half: Vector2 = Vector2(0.6, 0.27), y0: float = 0.38, height: float = 1.7) -> MeshInstance3D:
	var key: String = "spill_%.2f" % height
	if not _meshes.has(key):
		var c: CylinderMesh = CylinderMesh.new()
		c.height = height
		c.bottom_radius = 1.0
		c.top_radius = 1.45
		c.radial_segments = 20
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_meshes[key] = c
	var m: ShaderMaterial = _mat("spill", SPILL_SHADER)
	m.set_shader_parameter("tint", MARKE)
	m.set_shader_parameter("height", height)
	var mi: MeshInstance3D = _fx(_meshes[key], m, "Spill")
	mi.scale = Vector3(half.x, 1.0, half.y)
	mi.position.y = y0 + height * 0.5
	return mi


## A soft dark card behind a floating name, so it reads against a lit wall or a white-hot mouth (it faces the
## camera; the Label3D draws over it: give the label render_priority 2).
static func name_plate() -> MeshInstance3D:
	if not _meshes.has("quad"):
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	m.albedo_texture = disc_tex(0.6)
	m.albedo_color = Color(0.03, 0.015, 0.06, 0.9)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.render_priority = 1
	var mi: MeshInstance3D = _fx(_meshes["quad"], m, "NamePlate")
	mi.scale = Vector3(0.9, 0.3, 1.0)
	return mi


## Sizes a name plate for its text (Label3D metres: font px x pixel size, about 0.55 of that a letter).
static func fit_plate(plate: MeshInstance3D, label: Label3D) -> void:
	var em: float = float(label.font_size) * label.pixel_size
	plate.scale = Vector3(maxf(0.5, float(label.text.length()) * em * 0.62 + 0.5), em * 3.2, 1.0)
	plate.visible = label.text != ""


static func halo_tex() -> GradientTexture2D:
	if _halo_tex == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		_halo_tex = GradientTexture2D.new()
		_halo_tex.width = 64
		_halo_tex.height = 64
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(0.5, 0.0)
		_halo_tex.gradient = g
	return _halo_tex


## A disc that holds its strength out to `hold` of its radius and is gone at the rim (a pool of light on a floor
## whose middle is hidden under what makes it; a card behind a line of text).
static func disc_tex(hold: float = 0.45) -> GradientTexture2D:
	var key: String = "disc_%.2f" % hold
	if not _meshes.has(key):
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, hold, (hold + 1.0) * 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var t: GradientTexture2D = GradientTexture2D.new()
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.gradient = g
		_meshes[key] = t
	return _meshes[key]


## A camera-facing glow `size` metres across. Its own material: tint it through albedo_color (alpha = strength).
static func halo(size: float, color: Color, flat: bool = false) -> MeshInstance3D:
	if not _meshes.has("quad"):
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	m.disable_fog = true
	m.albedo_texture = disc_tex(0.42) if flat else halo_tex()
	m.albedo_color = color
	if not flat:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	var mi: MeshInstance3D = _fx(_meshes["quad"], m, "Halo")
	mi.scale = Vector3(size, size, size)
	if flat:
		mi.rotation.x = -PI * 0.5
	return mi


## A flat quad (facing up) `size` metres across with one of the floor shaders.
static func _floor_quad(size: float, m: ShaderMaterial, node_name: String) -> MeshInstance3D:
	if not _meshes.has("quad"):
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	var mi: MeshInstance3D = _fx(_meshes["quad"], m, node_name)
	mi.scale = Vector3(size, size, size)
	mi.rotation.x = -PI * 0.5
	return mi


static func ring(size: float = 2.6) -> MeshInstance3D:
	return _floor_quad(size, _mat("ring", RING_SHADER), "Ring")


static func pool(size: float = 3.0) -> MeshInstance3D:
	var m: ShaderMaterial = _mat("pool", POOL_SHADER)
	m.set_shader_parameter("tint", MARKE)
	return _floor_quad(size, m, "Pool")


static func rim_mat(color: Color = MARKE, energy: float = 1.4) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("rim", RIM_SHADER)
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("energy", energy)
	return m


static func soot_mat(strength: float = 0.85, seed_v: float = 0.0, tint: Color = Color(0.015, 0.013, 0.012), centre: Vector2 = Vector2(0.5, 0.5)) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("soot", SOOT_SHADER)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("centre", centre)
	return m


## Puts `overlay` (or null to clear it) over every mesh under `n`.
static func set_overlay(n: Node, overlay: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = overlay
	for c: Node in n.get_children():
		set_overlay(c, overlay)


## A one-shot puff (dust off a lid, snow sliding off): CPUParticles3D, both renderers, off until restart().
static func puff(color: Color, amount: int = 14, extents: Vector3 = Vector3(0.6, 0.02, 0.3), up: float = 0.5) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Puff"
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, 1, -0.4)
	p.spread = 60.0
	p.initial_velocity_min = up * 0.4
	p.initial_velocity_max = up
	p.gravity = Vector3(0, -0.5, 0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, color.a))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = halo_tex()
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
