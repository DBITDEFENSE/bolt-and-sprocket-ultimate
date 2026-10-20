class_name FlickerLight
extends OmniLight3D
## Fire/lamp flicker. Presentation only.

@export var base_energy: float = 1.5
@export var amount: float = 0.35
@export var speed: float = 9.0

var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = base_energy * (1.0 + (sin(_t) * 0.5 + sin(_t * 2.31) * 0.3 + sin(_t * 5.7) * 0.2) * amount)
