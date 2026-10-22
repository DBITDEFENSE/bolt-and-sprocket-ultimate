class_name JakubTalk
extends Interactable
## "Talk to Jakub" (Update 02 section 6.2): a child of Jakub's Player, like a RevivePoint. In his cage he answers;
## once he is out it opens the choice (give him a gun / not yet); once he is with you it hands him the gun in your
## hands. JakubCompanion decides every prompt. Off while he is downed (the RevivePoint takes over) or gone.

var companion: JakubCompanion


func _ready() -> void:
	interact_size = Vector3(1.1, 1.9, 1.1)
	interact_offset = Vector3(0, 0.95, 0)
	super._ready()
	area.collision_layer = 0


func _physics_process(_delta: float) -> void:
	var on: bool = companion != null and is_instance_valid(companion) and companion.talk_open()
	var want: int = LAYER_INTERACTABLE if on else 0
	if area.collision_layer != want:
		area.collision_layer = want


func get_prompt(player: Player) -> String:
	return companion.talk_prompt(player) if companion != null else ""


func can_interact(player: Player) -> bool:
	return companion != null and companion.can_talk(player)


func hold_time(_player: Player) -> float:
	return float(JakubCompanion.cfg().get("talk_hold_s", 0.35))


func interact(player: Player) -> void:
	if companion != null:
		companion.on_talk(player)
