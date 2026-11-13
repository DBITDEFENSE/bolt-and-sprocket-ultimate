class_name Trapdoor
extends Node3D
## A trapdoor over a hole in a floor (T-229: the cellar hatch behind the Inn's bar, over the Old Cellar's ladder). A
## plank leaf on a hinge along its north edge, bolted until `zone` opens (the Old Cellar's door is bought), then thrown
## back flat on the floor north of the hole; while shut it is a world collider you stand on, open it is only drawn.
## The hole itself is the generator's (the floor slab is cut), its rim boards are drawn here. The climbs through it
## are LadderClimbs with the same `zone`; the zombies' climb link lives on the zone's climb layer, so it opens with it.

@export var zone: StringName = &"OLD_CELLAR"
@export var size: Vector2 = Vector2(0.9, 0.9)   # the hole (x, z)

var is_open: bool = false
var _body: StaticBody3D
var _shape: CollisionShape3D
var _leaf: Node3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "LeafBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x, 0.06, size.y)
	_shape.shape = box
	_shape.position = Vector3(0, -0.03, 0)
	_body.add_child(_shape)
	add_child(_body)
	# the leaf, hinged at the hole's north edge
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	_leaf.position = Vector3(0, 0, -size.y * 0.5)
	add_child(_leaf)
	Props.block(_leaf, Vector3(-size.x * 0.5 + 0.01, -0.06, 0.01), Vector3(size.x * 0.5 - 0.01, 0.0, size.y - 0.01), "board_wood_v")
	for sz: float in [0.12, size.y - 0.16]:
		Props.block(_leaf, Vector3(-size.x * 0.5 + 0.03, -0.065, sz), Vector3(size.x * 0.5 - 0.03, -0.055, sz + 0.05), "iron")   # the straps
	Props.cyl(_leaf, Vector3(0, 0.0, size.y * 0.62), 0.07, 0.012, "iron")   # the ring's plate
	for a: float in [0.0, 90.0]:
		Props.obox(_leaf, Vector3(0, 0.02, size.y * 0.62), Vector3(0.12, 0.012, 0.012), "iron", Vector3(0, a, 0))
	# the rim boards round the hole, flush with the floor
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	for e: Array in [[Vector3(-hx - 0.08, -0.01, -hz - 0.08), Vector3(hx + 0.08, 0.015, -hz)], [Vector3(-hx - 0.08, -0.01, hz), Vector3(hx + 0.08, 0.015, hz + 0.08)],
			[Vector3(-hx - 0.08, -0.01, -hz), Vector3(-hx, 0.015, hz)], [Vector3(hx, -0.01, -hz), Vector3(hx + 0.08, 0.015, hz)]]:
		Props.block(self, e[0], e[1], "beam")
	GLBus.zone_opened.connect(_on_zone_opened)
	if zone == &"" or GameState.is_zone_open(zone):
		_set_open(true, false)


func _on_zone_opened(z: StringName) -> void:
	if z == zone and not is_open:
		_set_open(true, true)


func _set_open(open: bool, animate: bool) -> void:
	is_open = open
	_shape.set_deferred("disabled", open)
	var ang: float = deg_to_rad(-180.0) if open else 0.0
	if animate:
		var tw: Tween = create_tween()
		tw.tween_property(_leaf, "rotation:x", ang, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		AudioDirector.play_3d("door_creak", global_position, 0.0)
	else:
		_leaf.rotation.x = ang
