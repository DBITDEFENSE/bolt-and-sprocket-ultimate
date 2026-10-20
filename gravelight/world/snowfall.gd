class_name Snowfall
extends Node3D
## Weather and air: falling snow over outdoor areas, or slow warm dust motes indoors. Presentation only.
## Builds its GPUParticles3D at runtime from the exported settings (keeps the map file small).

@export var areas: Array[AABB] = []          # world-space boxes; particles spawn at the top of each
@export var density: float = 1.4             # particles per square metre of area (snow)
@export var motes: bool = false              # true = indoor dust motes instead of snow


func _ready() -> void:
	for box: AABB in areas:
		var p: GPUParticles3D = GPUParticles3D.new()
		var footprint: float = box.size.x * box.size.z
		p.amount = clampi(int(footprint * (density if not motes else 0.25)), 16, 6000)
		p.lifetime = 9.0 if not motes else 12.0
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
			pm.emission_box_extents = Vector3(box.size.x * 0.5, 0.5, box.size.z * 0.5)
			pm.direction = Vector3(0.25, -1, 0.1)
			pm.spread = 8.0
			pm.initial_velocity_min = 1.2
			pm.initial_velocity_max = 2.0
			pm.gravity = Vector3(0.25, -0.6, 0.05)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_noise_scale = 6.0
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		p.process_material = pm
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.05, 0.05) if not motes else Vector2(0.015, 0.015)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.85, 0.88, 0.95, 0.85) if not motes else Color(1.0, 0.8, 0.55, 0.35)
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
		m.albedo_texture = tex
		q.material = m
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
