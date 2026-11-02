class_name BlinkLight
extends OmniLight3D
## A navigation light that blinks (UPDATE 09 section 5, T-145: Totenhafen's breakwater light): `on_s` lit, then
## dark for the rest of `period_s`; the child meshes (the lamp's glass) are shown only while it is lit.
## Presentation only.

@export var period_s: float = 4.0
@export var on_s: float = 0.8
@export var energy_on: float = 2.0
@export var phase: float = 0.0

var _t: float = 0.0


func _ready() -> void:
	_t = phase
	_apply(false)


func _process(delta: float) -> void:
	_t = fmod(_t + delta, maxf(0.1, period_s))
	_apply(_t < on_s)


func _apply(lit: bool) -> void:
	light_energy = energy_on if lit else 0.0
	for c: Node in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = lit
