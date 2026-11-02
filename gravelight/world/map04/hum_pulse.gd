class_name HumPulse
extends OmniLight3D
## The relay's hum made visible (U09 s5, T-149): an omni light in the Retention Hall that breathes with the hum,
## a slow swell rather than a flicker (flicker_light.gd is noise). When the relay is cut (flag `cancelled`) the
## pulse dies away to a dim steady glow; when the plan renews (flag `renewed`) it holds bright.

@export var base_energy: float = 1.6
@export var amount: float = 0.35
@export var period: float = 2.6
@export var phase: float = 0.0

var _t: float = 0.0
var _mode: StringName = &"hum"   # hum | cut | renewed


## The light's energy at time `t` while humming.
static func energy_at(t: float, base: float, amt: float, per: float, ph: float) -> float:
	var s: float = 0.5 + 0.5 * sin(TAU * (t / maxf(0.1, per)) + ph)
	return base * (1.0 - amt + amt * 2.0 * s * s)


func _ready() -> void:
	_t = phase
	GLBus.flag_changed.connect(_on_flag)
	if bool(GameState.flags.get(&"cancelled", false)):
		_mode = &"cut"


func _on_flag(flag: StringName, _v: Variant) -> void:
	if flag == &"cancelled":
		_mode = &"cut"
	elif flag == &"renewed":
		_mode = &"renewed"


func _process(delta: float) -> void:
	_t += delta
	match _mode:
		&"cut":
			light_energy = move_toward(light_energy, base_energy * 0.25, delta * 0.5)
		&"renewed":
			light_energy = base_energy * 1.3
		_:
			light_energy = energy_at(_t, base_energy, amount, period, phase)
