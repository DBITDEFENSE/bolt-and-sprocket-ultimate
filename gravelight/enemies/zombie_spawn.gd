class_name ZombieSpawn
extends Marker3D
## A place zombies come from. Window spawns walk to their barricade; ground spawns rise out of the floor.

@export var zone_id: StringName = &""
@export var window_path: NodePath
@export var kind: StringName = &"window"   # window | ground | edge (walks in and chases; no window, no rise)
@export var min_round: int = 1
## Off = never chosen (Map 2's tide switches the flooded pump deck's points off and the catwalk points on).
@export var enabled: bool = true
## T-080 (Map 0's GROUNDS): only chosen while a living player stands in this spawn's zone (the edge of the field
## feeds the loop round the inn, never the windows from 30 m away).
@export var player_zone_only: bool = false
## T-080: not chosen while a living player on open ground (ZoneVolume.roam) is within this many metres (flat), so
## nobody sees a zombie appear in the field beside them. 0 = always allowed.
@export var hide_from_m: float = 0.0


func _ready() -> void:
	add_to_group(&"zombie_spawns")


func window() -> Barricade:
	if window_path.is_empty():
		return null
	return get_node_or_null(window_path) as Barricade


func is_active(round_number: int) -> bool:
	return enabled and round_number >= min_round and GameState.is_zone_open(zone_id)
