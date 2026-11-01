class_name BuyDoor
extends Interactable
## A blocking door/debris that opens a zone when bought. Blocks players and zombies (physics layer "door"),
## but is not part of the navmesh bake, so paths already run through it.

const LAYER_DOOR: int = 1 << 8

@export var door_id: StringName = &"door"
@export var opens_zone: StringName = &""
@export var cost: int = 750
@export var size: Vector3 = Vector3(2.0, 2.4, 0.3)
@export var label: String = "Door"
## Extra zones this door opens (e.g. the lift door also opens the Chapel it leads to).
@export var also_opens: PackedStringArray = []
## Doors sharing a link group open together (the Barracks door bought from either side).
@export var link_group: StringName = &""
## The Lab Wing door can't be bought until the power is on.
@export var requires_power: bool = false
## A GameState flag the door also waits for (UPDATE 07: the Great Hangar opens at an act round or on the egg's files);
## `requires_text` is the prompt until then.
@export var requires_flag: StringName = &""
@export var requires_text: String = "Not yet"

var is_open: bool = false
var _body: StaticBody3D
var _visual: Node3D
var _lock_lamp: MeshInstance3D   # powered doors: red until the power is on, then green
var _cost_labels: Array[Label3D] = []


func _ready() -> void:
	interact_size = Vector3(size.x + 0.2, size.y, size.z + 0.3)
	interact_offset = Vector3(0, size.y * 0.5, 0)
	super._ready()
	add_to_group(&"doors")
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


func build_greybox() -> void:
	_visual = Node3D.new()
	_visual.name = "Greybox"
	add_child(_visual)
	# a boarded, chained doorway; a steel bulkhead with a lock lamp if it needs the power (cached per size)
	var sz: Vector3 = size
	if not requires_power:
		# a real plank door for the opening, with its hinges, planks, chain and brass price plaques (T-094)
		var planes: Array = DoorArt.buy_door(_visual, sz)
		if not planes.is_empty():
			for side: float in [-1.0, 1.0]:
				var pl: Label3D = add_label(_visual, "%s\n%d" % [label, cost], Vector3(0, size.y * 0.6, float(planes[0]) if side < 0.0 else float(planes[1])), 34,
					Color(1.0, 0.92, 0.75, 0.95))
				pl.font = MenuKit.font("stamp")
				pl.rotation.y = 0.0 if side > 0 else PI
				_cost_labels.append(pl)
			return
	var key: String = "%s_%d_%d_%d" % ["door_steel" if requires_power else "door_wood", int(sz.x * 100.0), int(sz.y * 100.0), int(sz.z * 100.0)]
	if requires_power:
		InteractableArt.place(_visual, key, func(r: Node3D) -> void: InteractableArt.door_steel(r, sz))
		_lock_lamp = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 0.05
		_lock_lamp.mesh = cm
		_lock_lamp.rotation.x = PI * 0.5
		_lock_lamp.position = Vector3(0, size.y - 0.06, -size.z * 0.4 - 0.1)
		_lock_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(_lock_lamp)
		GLBus.power_activated.connect(_refresh_lock_lamp)
		_refresh_lock_lamp()
	else:
		InteractableArt.place(_visual, key, func(r: Node3D) -> void: InteractableArt.door_wood(r, sz))
	var lz: Array = InteractableArt.door_label_z(size, requires_power)
	for side: float in [-1.0, 1.0]:
		var z: float = float(lz[0]) - 0.005 if side < 0.0 else float(lz[1]) + 0.005
		var l: Label3D = add_label(_visual, "%s\n%d" % [label, cost], Vector3(0, size.y * 0.6, z), 28, Color(1.0, 0.92, 0.75, 0.95))
		l.rotation.y = 0.0 if side > 0 else PI
		_cost_labels.append(l)


## A new price (Jakub's Kaltenbrunn shortcut, U02 section 6.2): the prompt and both painted labels follow.
func set_cost(new_cost: int) -> void:
	cost = maxi(0, new_cost)
	for l: Label3D in _cost_labels:
		if is_instance_valid(l):
			l.text = "%s\n%d" % [label, cost]


func _refresh_lock_lamp() -> void:
	if _lock_lamp != null:
		_lock_lamp.material_override = Mats.get_mat("lamp_green" if GameState.power_on else "emergency_red")


func get_prompt(player: Player) -> String:
	if is_open:
		return ""
	if requires_power and not GameState.power_on:
		return "Power must be activated"
	if requires_flag != &"" and not GameState.has_flag(requires_flag):
		return requires_text
	return "Hold [%s] to open %s [%s]" % [prompt_key(&"interact"), label, price_str(player, cost)]


func can_interact(_player: Player) -> bool:
	return not is_open and (GameState.power_on or not requires_power) and (requires_flag == &"" or GameState.has_flag(requires_flag))


func interact(player: Player) -> void:
	if is_open:
		return
	if try_purchase(player, door_id, cost):
		open(player.player_id)


func open(by_player: int = 0) -> void:
	if is_open:
		return
	is_open = true
	_open_visual()
	Net.mirror(self, &"_net_open")
	GLBus.door_opened.emit(door_id, by_player)
	if opens_zone != &"":
		GameState.open_zone(opens_zone)
	for z: String in also_opens:
		GameState.open_zone(StringName(z))
	if link_group != &"":
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			var other: BuyDoor = n as BuyDoor
			if other != self and other.link_group == link_group:
				other.open(by_player)


## Co-op client: the host opened this door (zones arrive with the host's state).
func _net_open() -> void:
	if is_open:
		return
	is_open = true
	_open_visual()


func _open_visual() -> void:
	_body.collision_layer = 0
	area.collision_layer = 0
	AudioDirector.play_3d("door_open", global_position + Vector3(0, 1, 0))
	if AudioDirector.has_sound("door_creak"):   # the old hinges give as it goes (Update 02 section 8, T-053)
		AudioDirector.play_3d("door_creak", global_position + Vector3(0, 1.6, 0), -2.0)
	var target: Node3D = get_node_or_null("Visual") as Node3D
	if target == null:
		target = _visual
	if target != null:
		var tw: Tween = create_tween()
		tw.tween_property(target, "position:y", size.y + 0.5, float(GLData.table("world")["door"]["open_seconds"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(target.hide)
