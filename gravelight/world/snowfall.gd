class_name Snowfall
extends Node3D
## Weather and air: falling snow over outdoor areas, or slow warm dust motes indoors. Presentation only.
## Builds its GPUParticles3D at runtime from the exported settings (keeps the map file small).
## T-095: snow falls in depth: each area gets a mid layer (the flakes you see fall past) and a far layer (smaller,
## fainter, denser-looking flakes high over the whole box that read as distance); the near layer (big flakes
## around the camera) is VfxAtmosphere's. Counts scale with GLSettings "vfx_quality" (vfx.json quality.near_snow).

@export var areas: Array[AABB] = []          # world-space boxes; particles spawn at the top of each
@export var density: float = 1.4             # particles per square metre of area (snow)
@export var motes: bool = false              # true = indoor dust motes instead of snow

static var _flake_tex: GradientTexture2D = null
const FLAKE_SHADER: String = "res://gravelight/world/vfx/snow_flake.gdshader"
var layers: int = 0
var _mid_cfg: Dictionary = {}


## T-100: a snow flake material that never fills the screen near the camera: invisible inside `fade.x` metres,
## fully drawn past `fade.y`, and never wider on screen than `max_angle` radians (gravelight/world/vfx/snow_flake.gdshader).
static func flake_material(tint: Color, quad: float, fade: Vector2, max_angle: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(FLAKE_SHADER) as Shader
	m.set_shader_parameter("flake_tex", flake_texture())
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("quad_size", quad)
	m.set_shader_parameter("fade_near", fade.x)
	m.set_shader_parameter("fade_far", maxf(fade.y, fade.x + 0.05))
	m.set_shader_parameter("max_angle", max_angle)
	return m


## vfx.json "atmosphere.<key>.fade" / ".max_angle" with defaults (T-100).
static func guard_cfg(c: Dictionary, fade_def: Vector2, angle_def: float) -> Array:
	var f: Array = c.get("fade", [fade_def.x, fade_def.y])
	return [Vector2(float(f[0]), float(f[1])), float(c.get("max_angle", angle_def))]


## A soft round flake / mote sprite, shared.
static func flake_texture() -> GradientTexture2D:
	if _flake_tex != null:
		return _flake_tex
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = g
	_flake_tex = tex
	return tex


func _ready() -> void:
	var far_cfg: Dictionary = {}
	var k: float = 1.0
	if Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("Effects"):
		far_cfg = (Effects.vfx.get("atmosphere", {}) as Dictionary).get("far_snow", {})
		_mid_cfg = (Effects.vfx.get("atmosphere", {}) as Dictionary).get("mid_snow", {})
		k = float(Effects.quality().get("near_snow", 1.0))
	for box: AABB in areas:
		_layer(box, k, false, far_cfg)
		if not motes and not far_cfg.is_empty():
			_layer(box, k, true, far_cfg)


func _layer(box: AABB, k: float, far: bool, far_cfg: Dictionary) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	var footprint: float = box.size.x * box.size.z
	var amount: int = clampi(int(footprint * (density if not motes else 0.25)), 16, 6000)
	if far:
		amount = clampi(int(float(amount) * float(far_cfg.get("amount_mult", 0.6))), 8, 3000)
	elif not motes:
		amount = maxi(16, int(float(amount) * clampf(k, 0.3, 1.0)))
	p.amount = amount
	p.lifetime = 9.0 if not motes else 12.0
	if far:
		p.lifetime = 12.0
	p.preprocess = p.lifetime
	p.position = box.get_center() + Vector3(0, box.size.y * 0.5 if not motes else 0.0, 0)
	p.visibility_aabb = AABB(-box.size * 0.5 - Vector3(2, box.size.y + 4, 2), box.size + Vector3(4, box.size.y * 2 + 8, 4))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	if motes:
		pm.emission_box_extents = box.size * 0.5
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.02
		pm.initial_velocity_max = 0.08
		pm.gravity = Vector3(0, 0.005, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.3
		pm.turbulence_noise_speed_random = 0.2
	else:
		pm.emission_box_extents = Vector3(box.size.x * 0.5, 0.5 if not far else box.size.y * 0.25, box.size.z * 0.5)
		pm.direction = Vector3(0.25, -1, 0.1)
		pm.spread = 8.0
		pm.initial_velocity_min = 1.2 if not far else 0.8
		pm.initial_velocity_max = 2.0 if not far else 1.3
		pm.gravity = Vector3(0.25, -0.6, 0.05) if not far else Vector3(0.15, -0.35, 0.03)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6 if not far else 0.35
		pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	var flake: float = 0.05 if not motes else 0.015
	if far:
		flake = float(far_cfg.get("flake", 0.028))
	q.size = Vector2(flake, flake)
	if motes:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.8, 0.55, 0.35)
		m.albedo_texture = flake_texture()
		q.material = m
	else:
		# T-100: world-fixed flakes used to have no near guard at all, so one drifting past the lens filled the frame
		var tint: Color = Color(0.85, 0.88, 0.95, 0.85)
		if far:
			tint.a = float(far_cfg.get("alpha", 0.55))
		var g: Array = guard_cfg(far_cfg, Vector2(4.0, 8.0), 0.004) if far else guard_cfg(_mid_cfg, Vector2(1.5, 3.5), 0.007)
		q.material = flake_material(tint, flake, g[0], g[1])
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.name = "Far" if far else ("Motes" if motes else "Mid")
	add_child(p)
	layers += 1
