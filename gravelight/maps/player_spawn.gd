class_name PlayerSpawn
extends Marker3D
## Where a survivor starts. Order in the scene = player order.


func _ready() -> void:
	add_to_group(&"player_spawns")
