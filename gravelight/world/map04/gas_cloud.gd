class_name GasCloud
extends Node3D
## A Canary's hood gas (UPDATE 07, docs/MAP4_FERNFLUG.md §5.5): a head shot breaks the glass hood and the suit's
## bottle empties into a violet cloud of `radius` m for `seconds`: players inside take `dps` a second and the
## `gas_slow` status; the dead feel nothing. Presentation plus the host's damage tick; data map04c.json "groom.canary".

var radius: float = 3.0
var seconds: float = 6.0
var dps: float = 15.0
var status: StringName = &"gas_slow"
var _t: float = 0.0
var _mesh: MeshInstance3D
var _light: OmniLight3D


static func spawn(parent: Node, at: Vector3, cfg: Dictionary) -> GasCloud:
	var g: GasCloud = GasCloud.new()
	g.name = "GasCloud"
	g.radius = float(cfg.get("gas_radius", 3.0))
	g.seconds = float(cfg.get("gas_seconds", 6.0))
	g.dps = float(cfg.get("gas_dps", 15.0))
	g.status = StringName(str(cfg.get("gas_status", "gas_slow")))
	parent.add_child(g)
	g.global_position = at
	return g


## Pure: the damage a player standing inside takes over `delta`.
static func tick_damage(dps_v: float, delta: float) -> float:
	return maxf(0.0, dps_v * delta)


func _ready() -> void:
	add_to_group(&"gas_clouds")
	_mesh = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	_mesh.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.3, 0.9, 0.28)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.25, 0.9)
	m.emission_energy_multiplier = 1.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position = Vector3(0, radius * 0.5, 0)
	add_child(_mesh)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.62, 0.3, 1.0)
	_light.light_energy = 1.8
	_light.omni_range = radius * 2.5
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.0, 0)
	add_child(_light)
	AudioDirector.play_3d("glasshide_shatter", global_position + Vector3.UP, -4.0)


func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(1.0 - _t / seconds, 0.0, 1.0)
	_mesh.scale = Vector3.ONE * (0.6 + 0.4 * k)
	_light.light_energy = 1.8 * k
	if _t >= seconds:
		queue_free()
		return
	if not Net.is_authority():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: Vector3 = p.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 2.5:
			p.take_hit(tick_damage(dps, delta), self)
			p.apply_status(status, 0.6)
