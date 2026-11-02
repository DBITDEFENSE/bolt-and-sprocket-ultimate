class_name RetainedHand
extends Node3D
## The first retained's hand under the Account's floor glass (U09 s5, T-149; docs/MAP4_FERNFLUG.md §6.4, §6.8):
## the last impulse the relay has repeated for seven years, a slow small closing of the fingers, over and over.
## Quiet and small on purpose (a person, not a spectacle). When the relay is cut (flag `cancelled`) it stops.

@export var period: float = 5.5
@export var curl_deg: float = 24.0

var stopped: bool = false
var _t: float = 0.0


## The fingers' curl (degrees) at `t`: a slow close and a slower release, then still for a beat.
static func curl_at(t: float, per: float, deg: float) -> float:
	var u: float = fmod(t, per) / per
	if u < 0.35:
		return deg * smoothstep(0.0, 0.35, u)
	if u < 0.8:
		return deg * (1.0 - smoothstep(0.35, 0.8, u))
	return 0.0


func _ready() -> void:
	GLBus.flag_changed.connect(func(f: StringName, _v: Variant) -> void:
		if f == &"cancelled":
			stopped = true)
	if bool(GameState.flags.get(&"cancelled", false)):
		stopped = true


func _process(delta: float) -> void:
	if stopped:
		return
	_t += delta
	var c: float = deg_to_rad(curl_at(_t, period, curl_deg))
	for f: Node in get_children():
		var n: Node3D = f as Node3D
		if n != null and n.has_meta("finger"):
			n.rotation.x = -c * float(n.get_meta("finger"))
