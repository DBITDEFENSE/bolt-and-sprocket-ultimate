class_name LightningFlash
extends OmniLight3D
## Lightning in the storm outside (UPDATE 09 section 5, T-145: beyond Totenhafen's pen mouth): at a random interval
## in `every_s` the light fires one to three short flashes, and the storm card(s) in `cards` brighten with it
## (their shader's `flash` uniform). Presentation only; the thunder is ZoneAmbience's one-shot.

@export var every_s: Vector2 = Vector2(9.0, 24.0)
@export var peak_energy: float = 6.0
@export var cards: Array[NodePath] = []

var _next: float = 3.0
var _seq: Array[float] = []   # remaining [start, end] pairs of the current strike, as times from now
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(2.0, every_s.y)
	light_energy = 0.0


func _process(delta: float) -> void:
	_t += delta
	var k: float = 0.0
	if _seq.is_empty():
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(every_s.x, every_s.y)
			_t = 0.0
			var at: float = 0.0
			for i: int in _rng.randi_range(1, 3):
				var d: float = _rng.randf_range(0.05, 0.16)
				_seq.append(at)
				_seq.append(at + d)
				at += d + _rng.randf_range(0.06, 0.22)
	else:
		for i: int in range(0, _seq.size(), 2):
			if _t >= _seq[i] and _t <= _seq[i + 1]:
				k = 1.0 - (_t - _seq[i]) / maxf(0.01, _seq[i + 1] - _seq[i]) * 0.5
		if _t > _seq[_seq.size() - 1]:
			_seq.clear()
	light_energy = peak_energy * k
	for p: NodePath in cards:
		var mi: GeometryInstance3D = get_node_or_null(p) as GeometryInstance3D
		if mi != null and mi.material_override is ShaderMaterial:
			(mi.material_override as ShaderMaterial).set_shader_parameter("flash", k)
