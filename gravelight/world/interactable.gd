class_name Interactable
extends Node3D
## Base for every buyable/usable thing. The player's interaction ray hits the child Area3D (layer
## "interactable") and asks this node for a prompt, a hold time, and whether it can be used.
##
## Visuals: if the node has a child named "Visual" (a swapped-in art subscene), the greybox visual is skipped.
##
## Co-op (M7): prompts are built locally from replicated state; completing a hold on a client sends the use to
## the host, which runs interact() with that player's puppet (Player.use_interactable). Interactables whose use
## only concerns the local player (Intel, a UI that forwards its own inputs) return true from net_local().
## World changes a client must see are mirrored with Net.mirror(self, "method", [...]) from the host.

const LAYER_INTERACTABLE: int = 1 << 4

@export var interact_size: Vector3 = Vector3(1.2, 1.6, 0.6)
@export var interact_offset: Vector3 = Vector3.ZERO

var area: Area3D


func _ready() -> void:
	area = Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = LAYER_INTERACTABLE
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = interact_size
	shape.shape = box
	shape.position = interact_offset
	area.add_child(shape)
	add_child(area)
	if not has_node("Visual"):
		build_greybox()


## Override: add greybox meshes.
func build_greybox() -> void:
	pass


## Override: prompt text for this player. Return "" to show nothing.
func get_prompt(_player: Player) -> String:
	return ""


## Override: false = the prompt is shown but holding does nothing (locked, unaffordable is still true).
func can_interact(_player: Player) -> bool:
	return true


## Override: seconds the use button must be held.
func hold_time(_player: Player) -> float:
	return float(GLData.table("player")["interact_hold_seconds"])


## Override: true = keeps firing while held (e.g. repairing boards).
func repeats() -> bool:
	return false


## Override: called when the hold completes.
func interact(_player: Player) -> void:
	pass


## Override (co-op): true = interact() runs on the user's own machine instead of the host.
func net_local() -> bool:
	return false


## Override: a hold on this started (active) or stopped. Revive points pause the bleed-out with it.
func hold_changed(_player: Player, _active: bool) -> void:
	pass


## Helper: tries to spend Scrip; plays buy/deny feedback (to the buyer's own machine in co-op).
func try_purchase(player: Player, item_id: StringName, cost: int) -> bool:
	if Economy.spend(player.player_id, item_id, cost):
		AudioDirector.play_3d("buy", global_position, -4.0)
		Net.sfx_all("buy", global_position, -4.0)
		return true
	if player.is_local:
		AudioDirector.play_2d("deny", -2.0)
	player.flash_prompt_denied()
	return false


## A 2D sound for the user of this interactable, on their own machine.
static func feedback_2d(player: Player, key: String, db: float = 0.0) -> void:
	if player.is_local:
		AudioDirector.play_2d(key, db)
	elif Net.session != null:
		Net.session.send_player_op(player.player_id, &"sfx2d", [key, db])


static func prompt_key(action: StringName) -> String:
	return GLSettings.action_label(action)


static func greybox_mat(color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


static func add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_label(parent: Node3D, text: String, pos: Vector3, size: int = 24, color: Color = Color(1, 1, 1, 0.9)) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 6
	l.position = pos
	l.rotation.y = PI   # Label3D reads from its +Z side; our interactables face the player along -Z
	parent.add_child(l)
	return l
