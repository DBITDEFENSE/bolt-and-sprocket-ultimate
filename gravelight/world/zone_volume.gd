class_name ZoneVolume
extends Node3D
## An axis-aligned box that names the zone a position is in (spawn weighting, hints, stats).

@export var zone_id: StringName = &""
@export var size: Vector3 = Vector3(10, 4, 10)
## Open ground (T-080, Map 0's GROUNDS round the inn): zombies out here go for a player standing in it instead of
## their window, and leave a chase they can't finish for the nearest window (Zombie._roam_*).
@export var roam: bool = false
## No air (UPDATE 07 Map 4 Act IV, T-112): players in here breathe from their AIR gauge (Player.air) unless they
## stand at an AirPost; only vacuum-rated dead (enemies.json `vacuum_only`) spawn in here.
@export var vacuum: bool = false


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


## True when the first zone volume containing `p` is open ground (roam).
static func roam_at(tree: SceneTree, p: Vector3) -> bool:
	for n: Node in tree.get_nodes_in_group(&"zone_volumes"):
		var zv: ZoneVolume = n as ZoneVolume
		if zv != null and zv.contains(p):
			return zv.roam
	return false


## True when the first zone volume containing `p` has no air.
static func vacuum_at(tree: SceneTree, p: Vector3) -> bool:
	for n: Node in tree.get_nodes_in_group(&"zone_volumes"):
		var zv: ZoneVolume = n as ZoneVolume
		if zv != null and zv.contains(p):
			return zv.vacuum
	return false
