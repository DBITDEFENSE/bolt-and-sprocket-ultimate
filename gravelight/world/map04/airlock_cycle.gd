class_name AirlockCycle
extends Node3D
## An airlock's cycle on Mondlicht (U09 s5, T-149): presentation layered on the existing door logic, never in its
## way. The door (door.gd) still opens on its price and the zone volumes still decide who is in vacuum; this node
## only shows and sounds the cycle: the frame's lamps go red, a beacon turns, the pumps hiss and a burst of vapour
## (the vacuum fog) rolls out of the frame, a clunk, then green. It cycles once when its zone opens and again
## whenever a survivor steps through the frame (with a cooldown), and stands idle red until its door is bought.
## Built in code (lamps, beacon, vapour) so the generator only places it; no collider, no prompt.

@export var zone_id: StringName = &""        # the zone the door opens (GameState.is_zone_open)
@export var width: float = 2.4                # the door opening's width
@export var height: float = 2.4
@export var vacuum_side: bool = false         # the far side is vacuum: a bigger, colder burst
@export var cooldown: float = 9.0
@export var cycle_seconds: float = 3.6

const RED: Color = Color(1.0, 0.16, 0.1)
const GREEN: Color = Color(0.25, 1.0, 0.45)
const AMBER: Color = Color(1.0, 0.62, 0.2)

var state: StringName = &"locked"             # locked | cycling | open
var _t: float = 0.0
var _cool: float = 0.0
var _poll: float = 0.0
var _lamps: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _beacons: Array[Node3D] = []
var _vapour: GPUParticles3D
var _mat_red: StandardMaterial3D
var _mat_green: StandardMaterial3D
var _mat_amber: StandardMaterial3D
var _hissed: bool = false
var _clunked: bool = false


## The phase of a cycle at `t` seconds of `total`: "warn" (red, beacon), "vent" (hiss + vapour), "seal" (clunk), "done".
static func phase_at(t: float, total: float) -> StringName:
	if t < total * 0.18:
		return &"warn"
	if t < total * 0.82:
		return &"vent"
	if t < total:
		return &"seal"
	return &"done"


func _ready() -> void:
	add_to_group(&"airlock_cycles")
	_build()
	if zone_id != &"" and GameState.is_zone_open(zone_id):
		state = &"open"
	_refresh()
	GLBus.zone_opened.connect(_on_zone_opened)


func _mat(c: Color, e: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c * 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _build() -> void:
	_mat_red = _mat(RED, 3.0)
	_mat_green = _mat(GREEN, 3.0)
	_mat_amber = _mat(AMBER, 4.0)
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, 0.06)
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			var lamp: MeshInstance3D = MeshInstance3D.new()
			lamp.mesh = bm
			lamp.position = Vector3(s * (width * 0.5 + 0.12), height + 0.15, f * 0.27)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lamp)
			_lamps.append(lamp)
	for side: float in [-1.0, 1.0]:
		_beacons.append(_make_beacon(Vector3(0, height + 0.38, side * 0.3)))
	_light = OmniLight3D.new()
	_light.position = Vector3(0, height + 0.3, 0)
	_light.omni_range = 6.0
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.6
	_light.set_meta("zone", zone_id)
	add_child(_light)
	_build_vapour()


func _make_beacon(at: Vector3) -> Node3D:
	var b: Node3D = Node3D.new()
	b.position = at
	add_child(b)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.09
	cm.height = 0.16
	cm.radial_segments = 10
	var dome: MeshInstance3D = MeshInstance3D.new()
	dome.mesh = cm
	dome.material_override = _mat_amber
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(dome)
	var vane: MeshInstance3D = MeshInstance3D.new()
	var vm: BoxMesh = BoxMesh.new()
	vm.size = Vector3(0.2, 0.12, 0.02)
	vane.mesh = vm
	vane.position = Vector3(0.0, 0.0, 0.0)
	vane.material_override = _mat_amber
	vane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(vane)
	return b


func _build_vapour() -> void:
	_vapour = GPUParticles3D.new()
	_vapour.name = "Vapour"
	_vapour.emitting = false
	_vapour.one_shot = true
	_vapour.amount = 48 if vacuum_side else 28
	_vapour.lifetime = 2.6
	_vapour.explosiveness = 0.55
	_vapour.position = Vector3(0, 0.25, 0)
	_vapour.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 5, 8))
	_vapour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.45, 0.15, 0.2)
	pm.direction = Vector3(0, 0.15, 1)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8 if vacuum_side else 1.2
	pm.gravity = Vector3(0, -0.15, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.4
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 1.4))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	grad.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	grad.add_point(0.15, Color(0.88, 0.92, 1.0, 0.32))
	grad.add_point(0.6, Color(0.8, 0.84, 0.95, 0.14))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_vapour.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var qm: StandardMaterial3D = StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_texture = _puff_tex()
	quad.material = qm
	_vapour.draw_pass_1 = quad
	add_child(_vapour)


static func _puff_tex() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _on_zone_opened(z: StringName) -> void:
	if z == zone_id and state == &"locked":
		start_cycle()


## Runs one cycle (red, beacon, hiss and vapour, clunk, green). No effect on the door or the zones.
func start_cycle() -> void:
	if state == &"cycling":
		return
	state = &"cycling"
	_t = 0.0
	_hissed = false
	_clunked = false
	_refresh()


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if state == &"cycling":
		_t += delta
		var ph: StringName = phase_at(_t, cycle_seconds)
		for b: Node3D in _beacons:
			b.rotate_y(delta * 9.0)
		_light.light_energy = 1.4 + 0.9 * absf(sin(_t * 9.0))
		if ph == &"vent" and not _hissed:
			_hissed = true
			_vapour.restart()
			_vapour.emitting = true
			AudioDirector.play_3d("amb_m4d_airlock", global_position + Vector3(0, 1.5, 0), -4.0, 0.05)
		if ph == &"seal" and not _clunked:
			_clunked = true
		if ph == &"done":
			state = &"open"
			_cool = cooldown
			_refresh()
		return
	if state != &"open":
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.3
	if _cool > 0.0:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p == null or not p.is_inside_tree():
			continue
		var local: Vector3 = to_local(p.global_position)
		if absf(local.x) < width * 0.5 + 0.2 and absf(local.z) < 0.9 and local.y > -0.5 and local.y < height:
			start_cycle()
			return


func _refresh() -> void:
	var m: StandardMaterial3D = _mat_green if state == &"open" else _mat_red
	for l: MeshInstance3D in _lamps:
		l.material_override = m
	for b: Node3D in _beacons:
		b.visible = state == &"cycling"
	_light.light_color = GREEN if state == &"open" else (AMBER if state == &"cycling" else RED)
	_light.light_energy = 0.9 if state == &"open" else 0.7
