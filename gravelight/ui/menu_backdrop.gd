class_name MenuBackdrop
extends Node3D
## The main-menu scene, built in code: the Minehead Yard at night. Snow, fog, the headframe tower,
## a sodium lamp, falling snow, and one Gänger dragging itself through the drifts on a loop.

var _cam: Camera3D
var _walker: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _t: float = 0.0


func _ready() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.37, 0.52)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.16)
	env.fog_density = 0.03
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.7, 0.74, 0.86)
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	we.environment = env
	add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.92)
	moon.light_energy = 0.4
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-30), 0)
	add_child(moon)
	_cam = Camera3D.new()
	_cam.position = Vector3(-3.5, 1.7, 9.0)
	_cam.rotation = Vector3(deg_to_rad(4), deg_to_rad(-14), 0)
	_cam.fov = 62.0
	_cam.current = true
	add_child(_cam)
	_box(Vector3(0, -0.25, 0), Vector3(80, 0.5, 80), Color(0.78, 0.81, 0.86))
	# headframe tower
	for c: Vector2 in [Vector2(4, -14), Vector2(10, -14), Vector2(4, -8), Vector2(10, -8)]:
		_box(Vector3(c.x, 11, c.y), Vector3(0.6, 22, 0.6), Color(0.15, 0.15, 0.17))
	_box(Vector3(7, 22.5, -11), Vector3(7.5, 2.5, 7.5), Color(0.15, 0.15, 0.17))
	for y: float in [6.0, 12.0, 18.0]:
		_box(Vector3(7, y, -14), Vector3(6.6, 0.3, 0.3), Color(0.15, 0.15, 0.17))
		_box(Vector3(7, y, -8), Vector3(6.6, 0.3, 0.3), Color(0.15, 0.15, 0.17))
	_box(Vector3(7, 3, -11), Vector3(7, 6, 7), Color(0.35, 0.35, 0.36))
	# fence + gatehouse
	_box(Vector3(-10, 2, -6), Vector3(0.3, 4, 26), Color(0.42, 0.33, 0.28))
	_box(Vector3(-6, 1.75, -16), Vector3(6, 3.5, 5), Color(0.42, 0.33, 0.28))
	_box(Vector3(-2, 0.4, 2), Vector3(3, 0.8, 2.5), Color(0.82, 0.85, 0.9))
	# sodium lamp
	_box(Vector3(-6, 2.5, -3), Vector3(0.15, 5, 0.15), Color(0.1, 0.1, 0.1))
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(-6, 5, -3)
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 2.5
	lamp.omni_range = 12.0
	lamp.shadow_enabled = true
	add_child(lamp)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = Vector3(7, 1.0, -7.5)
	glow.light_color = Color(0.6, 0.3, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 6.0
	add_child(glow)
	# snow
	var snow: CPUParticles3D = CPUParticles3D.new()
	snow.amount = 600
	snow.lifetime = 8.0
	snow.preprocess = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18, 0.5, 18)
	snow.position = Vector3(0, 12, 0)
	snow.direction = Vector3(0.3, -1, 0)
	snow.spread = 10.0
	snow.gravity = Vector3(0.2, -1.2, 0)
	snow.initial_velocity_min = 0.5
	snow.initial_velocity_max = 1.2
	var flake: QuadMesh = QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	# T-100: round soft flakes that fade near the camera and never grow past a few pixels (square ones drifting by
	# the lens showed as big grey blocks on an ultrawide screen)
	flake.material = Snowfall.flake_material(Color(0.95, 0.96, 1.0, 0.95), 0.05, Vector2(1.0, 2.5), 0.008)
	snow.mesh = flake
	add_child(snow)
	_build_walker()


func _box(pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _build_walker() -> void:
	_walker = Node3D.new()
	add_child(_walker)
	var coat: StandardMaterial3D = StandardMaterial3D.new()
	coat.albedo_color = Color(0.3, 0.33, 0.27)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.5, 0.55, 0.55)
	var eye: StandardMaterial3D = StandardMaterial3D.new()
	eye.albedo_color = Color(0.7, 0.35, 1.0)
	eye.emission_enabled = true
	eye.emission = Color(0.7, 0.35, 1.0)
	eye.emission_energy_multiplier = 6.0
	var body: Node3D = Node3D.new()
	body.rotation.x = -0.35
	_walker.add_child(body)
	for side: float in [-1.0, 1.0]:
		var hip: Node3D = Node3D.new()
		hip.position = Vector3(0.11 * side, 0.84, 0)
		body.add_child(hip)
		_part(hip, Vector3(0.17, 0.84, 0.19), Vector3(0, -0.42, 0), coat)
		_legs.append(hip)
		var sh: Node3D = Node3D.new()
		sh.position = Vector3(0.31 * side, 1.4, 0)
		sh.rotation.x = 1.3
		body.add_child(sh)
		_part(sh, Vector3(0.12, 0.64, 0.13), Vector3(0, -0.3, 0), coat)
		_arms.append(sh)
	_part(body, Vector3(0.48, 0.62, 0.27), Vector3(0, 1.15, 0), coat)
	var head: MeshInstance3D = _part(body, Vector3(0.25, 0.28, 0.26), Vector3(0, 1.66, 0), skin)
	_part(head, Vector3(0.05, 0.035, 0.02), Vector3(-0.06, 0.03, -0.135), eye)
	_part(head, Vector3(0.05, 0.035, 0.02), Vector3(0.06, 0.03, -0.135), eye)


func _part(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	# a slow, dragging walk across the yard, then back again (a 40 s loop)
	var p: float = fmod(_t, 40.0) / 40.0
	var forward: bool = p < 0.5
	var k: float = p * 2.0 if forward else (p - 0.5) * 2.0
	var x: float = lerpf(-9.0, 7.0, k) if forward else lerpf(7.0, -9.0, k)
	_walker.position = Vector3(x, 0, -1.5 + sin(_t * 0.3) * 0.6)
	_walker.rotation.y = -PI * 0.5 if forward else PI * 0.5
	var swing: float = sin(_t * 2.6) * 0.35
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing * 0.4   # the dragging leg
		_arms[0].rotation.x = 1.3 + swing * 0.15
		_arms[1].rotation.x = 1.2 - swing * 0.1
	_walker.position.y = absf(sin(_t * 2.6)) * 0.04
	_cam.rotation.y = deg_to_rad(-14) + sin(_t * 0.07) * 0.03
