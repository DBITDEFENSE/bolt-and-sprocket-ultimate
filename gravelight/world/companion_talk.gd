class_name CompanionTalk
extends Interactable
## T-135: "Talk to <name>" on a map companion's body (MapCompanion), like JakubTalk. Off while it is downed (the
## RevivePoint takes over) or out cold.

var companion: MapCompanion


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
	return float(MapCompanion.table().get("talk_hold_s", 0.35))


func interact(player: Player) -> void:
	if companion != null:
		companion.on_talk(player)
