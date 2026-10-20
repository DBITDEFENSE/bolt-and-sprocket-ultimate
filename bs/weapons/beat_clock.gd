class_name BeatClock
extends RefCounted
## The music beat the B.O.O.M. Box drops on (the web build's onNextBeat, index.html:1658). If the music system
## puts a node in group "music_clock" with `time_to_next_beat() -> float`, that wins; otherwise a fallback clock
## ticks at data/bs/weapons.json beat.period (120 BPM), advanced by WeaponManager in game time.

static var t: float = 0.0


static func advance(dt: float) -> void:
	t += dt


static func period() -> float:
	return float((WeaponData.doc().get("beat", {}) as Dictionary).get("period", 0.5))


static func time_to_next_beat(tree: SceneTree) -> float:
	if tree != null:
		var n: Node = tree.get_first_node_in_group(&"music_clock")
		if n != null and n.has_method("time_to_next_beat"):
			return maxf(0.0, float(n.call("time_to_next_beat")))
	var p: float = period()
	var r: float = p - fmod(t, p)
	return r if r > 0.0001 else p
