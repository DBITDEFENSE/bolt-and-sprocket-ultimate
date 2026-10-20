class_name ZoneVolume
extends Node3D
## An axis-aligned box that names the zone a position is in (spawn weighting, hints, stats).

@export var zone_id: StringName = &""
@export var size: Vector3 = Vector3(10, 4, 10)


func _ready() -> void:
	add_to_group(&"zone_volumes")


func contains(p: Vector3) -> bool:
	var local: Vector3 = p - global_position
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5 and local.y >= -0.5 and local.y <= size.y


static func zone_at(tree: SceneTree, p: Vector3) -> StringName:
	for n: Node in tree.get_nodes_in_group(&"zone_volumes"):
		var zv: ZoneVolume = n as ZoneVolume
		if zv != null and zv.contains(p):
			return zv.zone_id
	return &""
