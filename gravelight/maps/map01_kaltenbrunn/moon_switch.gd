extends DirectionalLight3D
## Presentation/perf only: every room below ground is roofed, so the moon contributes nothing there except
## the cost of its shadow pass. While the active camera is below `below_y`, the moon is switched off.

@export var below_y: float = -2.5

var _t: float = 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var want: bool = cam.global_position.y > below_y
	if visible != want:
		visible = want
