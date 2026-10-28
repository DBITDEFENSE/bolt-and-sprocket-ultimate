class_name BakedMultiMesh
extends MultiMeshInstance3D
## A MultiMeshInstance3D that keeps its instance transforms in the scene file (T-125). The map generators run
## headless, and the dummy renderer keeps no MultiMesh buffer, so a plain MultiMesh was saved with its instance
## count but without its transforms: every instance drew nowhere (Map 0's split-rail fences, T-093, were invisible
## over their colliders). This node stores the transforms itself and fills the MultiMesh when it is ready.

@export var transforms: Array[Transform3D] = []


func _ready() -> void:
	fill()


func fill() -> void:
	if multimesh == null:
		return
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
