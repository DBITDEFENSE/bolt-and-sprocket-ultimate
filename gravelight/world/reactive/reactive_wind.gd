class_name ReactiveWind
extends RefCounted
## Where the reactive dressing gets the wind (Update 02 section 8, T-053): a node in the group "map_ambience" with a
## wind_strength() method (Map 0's MapAmbience: ~0.15 in a lull, ~1.1 in a full gust), else a steady CALM. Cached
## per frame, so a dozen curtains asking costs one lookup.

const CALM: float = 0.3

static var _frame: int = -1
static var _value: float = CALM


static func strength(tree: SceneTree) -> float:
	var f: int = Engine.get_process_frames()
	if f == _frame:
		return _value
	_frame = f
	_value = CALM
	if tree != null:
		var amb: Node = tree.get_first_node_in_group(&"map_ambience")
		if amb != null and amb.has_method("wind_strength"):
			_value = float(amb.call("wind_strength"))
	return _value
