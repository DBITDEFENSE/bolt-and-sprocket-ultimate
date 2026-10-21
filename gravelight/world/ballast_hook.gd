class_name BallastHook
extends Interactable
## Map 2 "Ballast": the loading crane's hook over the loading square. A player carrying a BallastCoffin hooks it
## here; once `needed` coffins (map02.json "ballast") hang from the crane the flag `flag` is set and the
## Pumpenschalter will take the throw (PowerSwitch.requires_flag). The hooked coffins hang in the slings.

@export var config_table: String = "map02"
@export var flag: StringName = &"ballast_loaded"

var count: int = 0
var _slung: Node3D


func _ready() -> void:
	interact_size = Vector3(3.0, 2.6, 3.0)
	interact_offset = Vector3(0, 1.3, 0)
	super._ready()
	add_to_group(&"ballast_hooks")


func build_greybox() -> void:
	# the painted square is the generator's; here: the hook block, the sling ropes, and the slung coffins (hidden)
	var g: Node3D = Node3D.new()
	g.name = "Art"
	add_child(g)
	_slung = Node3D.new()
	_slung.name = "Slung"
	_slung.visible = false
	g.add_child(_slung)
	Props.coffin(_slung, Vector3(0, 1.0, 0), 0.0, "BLST-02", false)
	Props.cable(_slung, Vector3(0, 2.5, 0.3), Vector3(-1.0, 1.6, 0), 0.0, 0.03, 2, "rope")
	Props.cable(_slung, Vector3(0, 2.5, 0.3), Vector3(1.0, 1.6, 0), 0.0, 0.03, 2, "rope")
	_noshadow_label()


func _noshadow_label() -> void:
	var l: Label3D = add_label(self, "BALLAST", Vector3(0, 0.6, -1.6), 22, Color(0.9, 0.85, 0.6, 0.8))
	l.rotation.x = -PI * 0.5
	l.rotation.y = 0.0


func needed() -> int:
	return int(BallastCoffin.cfg(config_table).get("needed", 1))


func _carried_by(pid: int) -> BallastCoffin:
	for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
		var c: BallastCoffin = n as BallastCoffin
		if c != null and c.carrier == pid and not c.delivered:
			return c
	return null


func get_prompt(player: Player) -> String:
	if count >= needed():
		return ""
	if _carried_by(player.player_id) == null:
		return "The crane wants ballast (%d of %d)" % [count, needed()]
	return "Hold [%s] to hook the coffin (%d of %d)" % [prompt_key(&"interact"), count, needed()]


func can_interact(player: Player) -> bool:
	return count < needed() and _carried_by(player.player_id) != null


func hold_time(_player: Player) -> float:
	return float(BallastCoffin.cfg(config_table).get("hook_seconds", 1.5))


func interact(player: Player) -> void:
	var c: BallastCoffin = _carried_by(player.player_id)
	if c == null:
		return
	c.deliver()
	Net.mirror(c, &"deliver")
	hooked(count + 1)
	Net.mirror(self, &"hooked", [count])
	GLBus.item_picked_up.emit(c.coffin_id, player.player_id)


## The crane has `n` coffins; every peer runs this (the host decides).
func hooked(n: int) -> void:
	count = n
	if _slung != null:
		_slung.visible = count > 0
	AudioDirector.play_3d("lift_winch", global_position + Vector3.UP * 2.0, -4.0, 0.0)
	if count >= needed() and Net.is_authority() and not GameState.has_flag(flag):
		GameState.set_flag(flag, true)
		GLVO.play_category(&"OPR", "BALLAST_HOOKED")
