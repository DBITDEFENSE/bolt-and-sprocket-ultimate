class_name ConveyorRun
extends Node3D
## The fulfillment store's conveyor (U09 s5, T-149): the parcels on the belt ride along local +X at `speed` and wrap
## from one end to the other, so the belt is always delivering. Purely visual (no collider); stops when the relay is
## cut (flag `cancelled`).

@export var length: float = 22.0
@export var speed: float = 0.55

var running: bool = true


## Where a parcel at `x` is after `dt` on a belt of `len` (wraps -len/2 .. len/2).
static func advance(x: float, dt: float, spd: float, len: float) -> float:
	var h: float = len * 0.5
	return wrapf(x + spd * dt, -h, h)


func _ready() -> void:
	GLBus.flag_changed.connect(func(f: StringName, _v: Variant) -> void:
		if f == &"cancelled":
			running = false)


func _process(delta: float) -> void:
	if not running:
		return
	for c: Node in get_children():
		var n: Node3D = c as Node3D
		if n != null and n.has_meta("parcel"):
			n.position.x = advance(n.position.x, delta, speed, length)
