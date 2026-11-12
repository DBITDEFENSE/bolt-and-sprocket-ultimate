@tool
extends EditorScenePostImport
## Blender already targets ZombieRig's rest frame. Preserve those transforms; attach the shared
## Humanoid BoneMap for tooling instead of applying a second T-pose/rest normalization.
func _post_import(scene: Node) -> Object:
	var bone_map: BoneMap = load("res://assets/zombies/anims/shared_humanoid_bone_map.tres")
	for node: Node in scene.find_children("*", "Skeleton3D", true, false):
		node.set_meta("bone_map", bone_map)
	return scene
