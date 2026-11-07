class_name CinemaEase
extends RefCounted
## T-184: the easing curves the cutscene camera moves on (docs DECISIONS T-184). Pure: `apply(name, k)` maps 0..1 to
## 0..1 (`out_back` overshoots a little before it settles). An unknown name falls back to "smooth" (smootherstep:
## zero speed and zero acceleration at both ends, the default for a dolly or a crane), so a typo in the data still
## moves like a camera, never like a lerp.

const NAMES: PackedStringArray = [
	"linear", "smooth", "sine", "in_sine", "out_sine", "quad", "in_quad", "out_quad", "cubic", "in_cubic",
	"out_cubic", "quint", "out_quint", "in_expo", "out_expo", "out_back",
]


static func apply(name: String, k: float) -> float:
	var x: float = clampf(k, 0.0, 1.0)
	match name:
		"linear":
			return x
		"sine":
			return -(cos(PI * x) - 1.0) * 0.5
		"in_sine":
			return 1.0 - cos(x * PI * 0.5)
		"out_sine":
			return sin(x * PI * 0.5)
		"quad":
			return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) * 0.5
		"in_quad":
			return x * x
		"out_quad":
			return 1.0 - (1.0 - x) * (1.0 - x)
		"cubic":
			return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
		"in_cubic":
			return x * x * x
		"out_cubic":
			return 1.0 - pow(1.0 - x, 3.0)
		"quint":
			return 16.0 * pow(x, 5.0) if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 5.0) * 0.5
		"out_quint":
			return 1.0 - pow(1.0 - x, 5.0)
		"in_expo":
			return 0.0 if x <= 0.0 else pow(2.0, 10.0 * x - 10.0)
		"out_expo":
			return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)
		"out_back":
			var c1: float = 1.70158
			var c3: float = c1 + 1.0
			return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
		_:
			return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func known(name: String) -> bool:
	return NAMES.has(name)
