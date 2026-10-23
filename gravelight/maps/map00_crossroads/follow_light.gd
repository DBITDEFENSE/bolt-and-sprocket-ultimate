extends Light3D
## Map 0 lighting pass (T-061): a light that follows another light's level. The fill and spill lights the pass
## added (lamplight spilling out of the inn's windows onto the snow, the wreck's glow through the east window, the
## candles on the taproom tables) each name the lamp they belong to, so whatever dims that lamp dims them too: the
## Cousins round guttering the inn's lamps (cousins.json setup.lamp_groups), a Bellringer round's stutter, the fire
## dying, a flicker. Its own energy each frame = full_energy x (the source's energy now / its energy at load),
## times an optional flicker of its own. A source tied to the power (meta "energy") is measured against that.
## A MeshInstance3D child named "Glow" (a lit window seen from outside) has its emission scaled the same way.
## Deliberately has no "base_energy" property: LampGlow, the Cousins and the Bellringer read that name as
## "a FlickerLight's steady energy", and this light's level is not its own to keep.

@export var source: NodePath
@export var full_energy: float = 1.0
@export var own_flicker: float = 0.0

var _src: Light3D
var _ref: float = 1.0
var _t: float = 0.0
var _glow: StandardMaterial3D
var _glow_base: float = 0.0
var _glow_k: float = -1.0


func _ready() -> void:
	_src = get_node_or_null(source) as Light3D
	if _src != null:
		_ref = maxf(0.001, float(_src.get_meta("energy")) if _src.has_meta("energy") else LampGlow.energy_of(_src))
	_t = randf() * 100.0
	var g: MeshInstance3D = get_node_or_null("Glow") as MeshInstance3D
	if g != null and g.material_override is StandardMaterial3D:
		_glow = g.material_override as StandardMaterial3D
		_glow_base = _glow.emission_energy_multiplier
	_apply(0.0)


func _process(delta: float) -> void:
	_apply(delta)


## The source's level as a fraction of its level at load (0 when it is hidden or gone). Its live light_energy, so
## a flickering source's follower flickers with it.
func level() -> float:
	if _src == null or not is_instance_valid(_src) or not _src.is_visible_in_tree():
		return 0.0
	return clampf(_src.light_energy / _ref, 0.0, 1.5)


func _apply(delta: float) -> void:
	var f: float = 1.0
	if own_flicker > 0.0:
		_t += delta * 9.0
		f += (sin(_t) * 0.5 + sin(_t * 2.31) * 0.3 + sin(_t * 5.7) * 0.2) * own_flicker
	var k: float = level()
	light_energy = full_energy * k * f
	if _glow != null and absf(k - _glow_k) > 0.01:
		_glow_k = k
		_glow.emission_energy_multiplier = _glow_base * k
