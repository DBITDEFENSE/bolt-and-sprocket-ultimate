extends Node3D
## Presentation only: spins its children about a local axis. With `needs_power`, it spins up over
## `spin_up` seconds once GameState.power_on turns true (Generator Hall flywheels); otherwise it always turns.

@export var axis: Vector3 = Vector3(1, 0, 0)
@export var speed: float = 3.0
@export var spin_up: float = 6.0
@export var needs_power: bool = true

var _w: float = 0.0


func _process(delta: float) -> void:
	var target: float = speed if (GameState.power_on or not needs_power) else 0.0
	_w = move_toward(_w, target, delta * absf(speed) / maxf(0.1, spin_up))
	if _w != 0.0:
		rotate_object_local(axis.normalized(), _w * delta)
