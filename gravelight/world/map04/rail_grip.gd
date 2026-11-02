class_name RailGrip
extends Interactable
## UPDATE 10 §3 (contract C6 `decompression`, T-156): a grab rail on a frame next to a decompression breach. While a
## player holds [interact] on it they are anchored: the breach's suction does not move them (DecompressionBreach.
## anchored reads the player's hold in progress). The hold never "completes" in practice (hold_s 30 s); letting go
## ends it. Prompts only while a breach is warning or pulling. Group "rail_grips".

@export var breach_path: NodePath


func _ready() -> void:
	interact_size = Vector3(1.6, 1.8, 0.8)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"rail_grips")


func build_greybox() -> void:
	Props.cyl(self, Vector3(0, 1.1, -0.05), 0.025, 1.4, "yellow_paint", Vector3(0, 0, 90))
	for sx: float in [-0.68, 0.68]:
		Props.block(self, Vector3(sx - 0.03, 1.0, -0.12), Vector3(sx + 0.03, 1.2, -0.02), "iron")


func breach() -> DecompressionBreach:
	return get_node_or_null(breach_path) as DecompressionBreach


func _live() -> bool:
	var b: DecompressionBreach = breach()
	return b != null and (b.phase == DecompressionBreach.Phase.WARN or b.phase == DecompressionBreach.Phase.PULL)


func get_prompt(_player: Player) -> String:
	if not _live():
		return ""
	return "Hold [%s] to hold on to the rail" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return _live() and player != null and player.is_alive()


func hold_time(_player: Player) -> float:
	return 30.0


func net_local() -> bool:
	return true


## Who holds the rail now (pid -> true): the player's own hold (hold_changed on their machine) or a bot's hold().
var holders: Dictionary = {}


func hold_changed(player: Player, active: bool) -> void:
	hold(player, active)


## Grab (true) or let go (false); bots call it directly.
func hold(player: Player, on: bool) -> void:
	if player == null:
		return
	if on:
		holders[player.player_id] = true
	else:
		holders.erase(player.player_id)


func holds(pid: int) -> bool:
	return holders.has(pid)
