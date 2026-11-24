class_name FlickerLight
extends OmniLight3D
## Fire/lamp flicker. Presentation only.
## T-095: the wobble is noise, not a sum of sines (no visible period): two octaves of 1-D simplex per light with a
## private phase, plus a rare gutter (a short dip when a slow third octave crests) so a fire breathes and catches
## rather than hums. VfxAtmosphere.configure() marks the fires (hearth, wreck, candles): faster and deeper than the
## lanterns. LampGlow reads base_energy, which this never changes.

@export var base_energy: float = 1.5
@export var amount: float = 0.35
@export var speed: float = 9.0
## A fire (the hearth, the wreck, a candle) rather than an oil lantern: set by VfxAtmosphere from the name.
@export var fire: bool = false

var _t: float = 0.0
var _speed_k: float = 1.0
var _amount_k: float = 1.0
var _gutter_threshold: float = 0.74
var _gutter_depth: float = 0.55
static var _noise: FastNoiseLite = null


static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1944
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.07
	return _noise


func _ready() -> void:
	_t = randf() * 1000.0


## The kind and the gutter settings (data/gravelight/vfx.json atmosphere.flicker).
func configure(is_fire: bool, fire_speed_mult: float, fire_amount_mult: float, gutter_threshold: float, gutter_depth: float) -> void:
	fire = is_fire
	_speed_k = fire_speed_mult if is_fire else 1.0
	_amount_k = fire_amount_mult if is_fire else 1.0
	_gutter_threshold = gutter_threshold
	_gutter_depth = gutter_depth


## The energy multiplier at time `t` for `amount`: 1 +- amount, with the gutter dip.
static func wobble(t: float, amt: float, gutter_threshold: float, gutter_depth: float) -> float:
	var n: FastNoiseLite = noise()
	var w: float = 0.65 * n.get_noise_1d(t) + 0.35 * n.get_noise_1d(t * 2.7 + 311.0)
	var k: float = 1.0 + w * 1.6 * amt
	var slow: float = n.get_noise_1d(t * 0.23 + 977.0)
	if slow > gutter_threshold:
		k *= 1.0 - gutter_depth * clampf((slow - gutter_threshold) / maxf(0.01, 1.0 - gutter_threshold), 0.0, 1.0)
	return k


func _process(delta: float) -> void:
	_t += delta * speed * _speed_k
	if not is_visible_in_tree():
		return   # T-265: a lamp a room's cell has switched off flickers for nobody (its time still runs)
	light_energy = base_energy * wobble(_t, amount * _amount_k, _gutter_threshold, _gutter_depth)
