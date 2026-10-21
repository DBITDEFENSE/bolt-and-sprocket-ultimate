class_name ZombieSpawn
extends Marker3D
## A place zombies come from. Window spawns walk to their barricade; ground spawns rise out of the floor.

@export var zone_id: StringName = &""
@export var window_path: NodePath
@export var kind: StringName = &"window"   # window | ground
@export var min_round: int = 1
## Off = never chosen (Map 2's tide switches the flooded pump deck's points off and the catwalk points on).
@export var enabled: bool = true


func _ready() -> void:
	add_to_group(&"zombie_spawns")


func window() -> Barricade:
	if window_path.is_empty():
		return null
	return get_node_or_null(window_path) as Barricade


func is_active(round_number: int) -> bool:
	return enabled and round_number >= min_round and GameState.is_zone_open(zone_id)
