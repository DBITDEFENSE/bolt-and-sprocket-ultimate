class_name InteractPoint
extends Area3D
## Something Bolt can walk up to and press interact on (NPCs, the save beacon, the ship, the kiosk).
## Area3D on the interactables layer (5, bit 16) watching the player layer. While the player is inside it
## shows EventBus.interact_prompt(prompt) and clears it ("") on leaving. Pressing "interact" calls interact().

signal interacted(point: InteractPoint, bolt: Node)

var prompt: String = ""           # text or a line id
var radius: float = 2.2
var actions: Array = []           # data actions the director runs on interact
var enabled: bool = true
var player_inside: Node3D = null


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	monitoring = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = radius
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.0
	add_child(cs)
	add_to_group(&"interactables")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if b.is_in_group(&"player") and enabled:
		player_inside = b as Node3D
		EventBus.interact_prompt.emit(LevelKit.text(prompt_text()))
		_player_near(b)


func _on_exit(b: Node) -> void:
	if b == player_inside:
		player_inside = null
		EventBus.interact_prompt.emit("")


func _process(_delta: float) -> void:
	if player_inside == null or not enabled or BS.blocked():
		return
	if InputMap.has_action(&"interact") and Input.is_action_just_pressed(&"interact"):
		interact(player_inside)


func interact(bolt: Node) -> void:
	if not enabled:
		return
	_do_interact(bolt)
	interacted.emit(self, bolt)


# ---- overrides
func prompt_text() -> String:
	return prompt


func _do_interact(_bolt: Node) -> void:
	pass


func _player_near(_bolt: Node) -> void:
	pass
