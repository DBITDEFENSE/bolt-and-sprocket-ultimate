extends Node3D
## Map 0 lighting pass (T-061): the lit glass of the inn's electric bulbs, under its bulb light. Shown only while
## that light burns (above a third of its powered energy), so the glass goes dark when the Cousins round gutters the
## inn's lights with the power on, and stutters with the power sweep's flicker and a Bellringer round.

var _light: Light3D
var _ref: float = 1.0


func _ready() -> void:
	_light = get_parent() as Light3D
	if _light != null:
		_ref = maxf(0.001, float(_light.get_meta("energy", _light.light_energy)))


func _process(_delta: float) -> void:
	if _light != null:
		var on: bool = _light.light_energy > _ref * 0.33
		if on != visible:
			visible = on
