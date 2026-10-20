class_name BlastDoor
extends Node3D
## A heavy door that blocks players and zombies (physics layer "door") until a GameState flag turns on,
## then grinds open. Map 1 Core Vault ramps (open_flag = core_vault_open).
## Origin: floor center of the opening. Size: width (x) × height (y) × thickness (z).

const LAYER_DOOR: int = 1 << 8

@export var size: Vector3 = Vector3(4.0, 3.5, 0.6)
@export var open_flag: StringName = &"core_vault_open"

var is_open: bool = false
var _body: StaticBody3D
var _visual: Node3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = LAYER_DOOR
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0, size.y * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	_visual = get_node_or_null("Visual") as Node3D
	if _visual == null:
		_visual = Node3D.new()
		add_child(_visual)
		Interactable.add_box(_visual, size, Vector3(0, size.y * 0.5, 0), Interactable.greybox_mat(Color(0.28, 0.27, 0.3)))
		for i: int in 4:
			Interactable.add_box(_visual, Vector3(size.x * 1.02, 0.12, size.z + 0.06), Vector3(0, 0.4 + i * size.y / 4.0, 0),
				Interactable.greybox_mat(Color(0.75, 0.6, 0.1)))
		Interactable.add_box(_visual, Vector3(0.6, 0.6, size.z + 0.1), Vector3(0, size.y * 0.55, 0), Interactable.greybox_mat(Color(0.5, 0.25, 0.75), 0.8))
	GLBus.flag_changed.connect(_on_flag)
	if GameState.has_flag(open_flag):
		open(true)


func _on_flag(flag: StringName, value: Variant) -> void:
	if flag == open_flag and bool(value):
		open()


func open(instant: bool = false) -> void:
	if is_open:
		return
	is_open = true
	_body.collision_layer = 0
	if instant:
		_visual.position.y = size.y + 0.2
		_visual.hide()
		return
	AudioDirector.play_3d("door_open", global_position + Vector3.UP * 1.5, 6.0, 0.0)
	var t: float = float(PowerSwitch.map01()["blast_door"]["open_seconds"])
	var tw: Tween = create_tween()
	tw.tween_property(_visual, "position:y", size.y + 0.2, t).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_visual.hide)
