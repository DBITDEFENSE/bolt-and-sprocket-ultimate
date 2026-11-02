class_name RelayMast
extends Node3D
## The relay mast's beacon over the dish foundation (UPDATE 10 §3 Act IV, T-158; presentation): a violet lamp that
## pulses slowly all match (the ambience's `relay_mast` reads it), harder and faster once the heaters run, and
## `surge()` flares it for the heater switch's spectacle. Cut (the relay is cut by CANCEL): it goes dark.

@export var period: float = 3.2
@export var energy: float = 2.4

var heated: bool = false
var cut: bool = false
var _t: float = 0.0
var _surge: float = 0.0
var _light: OmniLight3D
var _mat: StandardMaterial3D


## The pulse 0..1 at time `t` for a period (a sharp rise, a slow fall: a beacon, not a sine).
static func pulse_at(t: float, per: float) -> float:
	var ph: float = fposmod(t, maxf(0.1, per)) / maxf(0.1, per)
	return clampf(ph / 0.12, 0.0, 1.0) if ph < 0.12 else pow(1.0 - (ph - 0.12) / 0.88, 2.0)


func _ready() -> void:
	add_to_group(&"relay_mast")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.78, 0.45, 1.0)
	_mat.disable_fog = true
	var orb: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 12
	sm.rings = 6
	orb.mesh = sm
	orb.material_override = _mat
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.72, 0.42, 1.0)
	_light.omni_range = 16.0
	_light.shadow_enabled = false
	_light.set_meta("zone", &"C_YARD")
	add_child(_light)
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == &"heaters_on" and bool(v):
			heated = true
		elif f == &"cancelled" and bool(v):
			cut = true)


func surge() -> void:
	_surge = 1.0
	heated = true


func _process(delta: float) -> void:
	_t += delta
	_surge = maxf(0.0, _surge - delta * 0.35)
	var p: float = 0.0 if cut else pulse_at(_t, period * (0.55 if heated else 1.0))
	var k: float = (0.35 + 0.65 * p) * (1.0 if heated else 0.55) + _surge * 2.5
	_light.light_energy = energy * k
	_mat.albedo_color = Color(0.78, 0.45, 1.0).lerp(Color(1, 0.9, 1), clampf(_surge, 0.0, 1.0)) * (0.25 + 0.75 * clampf(k, 0.0, 1.0))
