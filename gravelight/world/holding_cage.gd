class_name HoldingCage
extends Node3D
## The holding cell in Map 0's Old Cellar (Update 02 section 6.1, DECISIONS T-051): an iron cage in the old coal
## room where a German patrol locked Jakub Ostrowski (section 6.2). The generator bakes the bars into the navmesh
## and leaves the door gap open; the door itself is this node's runtime collider (physics layer "door", never
## baked, like a BuyDoor), so paths already run through the doorway and only the collider has to go.
## Frame: the origin is the hinge, on the floor; local +X runs along the door to the latch; local -Z faces out
## of the cage into the room. The door leaf is the child "Hinge" (bars drawn by the generator).
## burst_open() swings the door off its hinge (section 6.2: at round 5 a zombie bursts the hinge trying to reach
## him). It is the only way the cage opens; reset() closes it again (dev / tests).

signal burst(by: Node)

const LAYER_DOOR: int = 1 << 8

@export var door_width: float = 1.5
@export var door_height: float = 3.0
## How far the leaf swings out (degrees) and how long it takes.
@export var swing_deg: float = 104.0
@export var swing_seconds: float = 0.45

var is_open: bool = false
var _body: StaticBody3D


func _ready() -> void:
	add_to_group(&"holding_cages")
	_body = StaticBody3D.new()
	_body.name = "DoorBody"
	_body.collision_layer = LAYER_DOOR
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(door_width, door_height, 0.12)
	cs.shape = box
	cs.position = Vector3(door_width * 0.5, door_height * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)


## The door leaf (the generator's "Hinge" group), or null in a bare test instance.
func hinge() -> Node3D:
	return get_node_or_null("Hinge") as Node3D


## Where someone stands just outside the door (1 m out, mid-door), on the floor.
func front_point() -> Vector3:
	return to_global(Vector3(door_width * 0.5, 0, -1.0))


## Where someone stands inside the cage (1 m in, mid-door), on the floor.
func inside_point() -> Vector3:
	return to_global(Vector3(door_width * 0.5, 0, 1.0))


## Bursts the hinge: the collider goes, the leaf swings out and rattles to a stop. `by` is whoever did it (the
## zombie, or null). Returns false if it was already open.
func burst_open(by: Node = null) -> bool:
	if is_open:
		return false
	is_open = true
	_body.collision_layer = 0
	_burst_visual()
	Net.mirror(self, &"_net_burst")
	burst.emit(by)
	return true


func _burst_visual() -> void:
	var h: Node3D = hinge()
	var at: Vector3 = to_global(Vector3(door_width * 0.5, 1.2, 0))
	AudioDirector.play_3d("board_break", at, 2.0)
	AudioDirector.play_3d("board_slam", at, 0.0)
	if h == null:
		return
	var tw: Tween = h.create_tween()
	tw.tween_property(h, "rotation:y", deg_to_rad(swing_deg), swing_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "rotation:y", deg_to_rad(swing_deg - 6.0), 0.18)
	tw.tween_property(h, "rotation:y", deg_to_rad(swing_deg - 2.0), 0.22)
	tw.parallel().tween_property(h, "rotation:z", deg_to_rad(-3.0), 0.22)   # the top hinge is gone: it sags


## Co-op client: the host's cage burst.
func _net_burst() -> void:
	if is_open:
		return
	is_open = true
	_body.collision_layer = 0
	_burst_visual()


## Closes the cage again (dev console / tests).
func reset() -> void:
	is_open = false
	_body.collision_layer = LAYER_DOOR
	var h: Node3D = hinge()
	if h != null:
		h.rotation = Vector3.ZERO
