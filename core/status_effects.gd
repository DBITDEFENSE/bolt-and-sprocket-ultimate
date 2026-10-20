class_name StatusEffects
extends Node
## Timed status effects on one damageable. Add as a child named "Status".
## Ids (brief §1): frozen, served, rooted, dancing, gravity_clumped, slowed, burning, conductive, lien, marked.
## Tuning per status (damage multipliers, slow amounts, tick damage) lives in data/bs/statuses.json.

signal applied(id: StringName, seconds: float)
signal expired(id: StringName)

var _t: Dictionary = {}   # id -> seconds left


func apply(id: StringName, seconds: float) -> void:
	var had: bool = _t.has(id)
	_t[id] = maxf(float(_t.get(id, 0.0)), seconds)
	if not had:
		applied.emit(id, seconds)


func clear(id: StringName) -> void:
	if _t.erase(id):
		expired.emit(id)


func has(id: StringName) -> bool:
	return float(_t.get(id, 0.0)) > 0.0


func time_left(id: StringName) -> float:
	return float(_t.get(id, 0.0))


func active() -> Array:
	return _t.keys()


func _process(delta: float) -> void:
	for id: Variant in _t.keys():
		_t[id] = float(_t[id]) - delta
		if float(_t[id]) <= 0.0:
			_t.erase(id)
			expired.emit(id)
