extends Node
## Fades its parent MeshInstance3D's material alpha over `life` seconds, then frees the parent.

var life: float = 0.1
var max_life: float = 0.1


func _process(delta: float) -> void:
	life -= delta
	var mi: MeshInstance3D = get_parent() as MeshInstance3D
	if mi == null:
		queue_free()
		return
	if life <= 0.0:
		mi.queue_free()
		return
	var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
	if m != null:
		if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = clampf(life / max_life, 0.0, 1.0) * 0.9
