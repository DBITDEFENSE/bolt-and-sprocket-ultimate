class_name TagSlot
extends Interactable
## The console's tag slot (UPDATE 10 §3 Act IV, the Bar's rows 5 and 20, T-158): a brass slot on the Account
## console's dais, stamped RETURNS. Obergefreiter Pohl (ExtraPerson "pohl", people_extra.json) asks you to carry
## his tag here and read it into the record before CANCEL, so that he is a name and not a number. Holding Use here
## with his tag ends his favour (ExtraPerson.give_item: his line, the reward). Shut once `cancelled` is set.
## Group `tag_slot` (the bots' fetch target, C7).

@export var person_id: String = "pohl"

var done: bool = false


func _ready() -> void:
	interact_size = Vector3(1.0, 1.4, 1.0)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"tag_slot")


func build_greybox() -> void:
	add_box(self, Vector3(0.5, 1.05, 0.4), Vector3(0, 0.52, 0), greybox_mat(Color(0.14, 0.13, 0.17)))
	add_box(self, Vector3(0.42, 0.05, 0.3), Vector3(0, 1.07, 0), greybox_mat(Color(0.7, 0.55, 0.25)))
	add_box(self, Vector3(0.2, 0.012, 0.03), Vector3(0, 1.1, 0), greybox_mat(Color(0.02, 0.02, 0.02)))
	var lb: Label3D = add_label(self, "RETURNS", Vector3(0, 1.3, 0), 20, Color(0.95, 0.8, 0.45, 0.9))
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func person() -> Node:
	var map: Node = get_tree().current_scene
	return map.get_node_or_null(NodePath("Person_" + person_id)) if map != null else null


func _carrying(p: Node) -> bool:
	return p != null and int(p.get("favour")) == int(ExtraPerson.Favour.HAVE)


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot:
		return ""
	if done:
		return "Pohl's tag is in the record"
	if GameState.has_flag(&"cancelled"):
		return ""
	if _carrying(person()):
		return "Hold [%s] to read Pohl's tag into the record" % prompt_key(&"interact")
	return "A slot for tags, stamped RETURNS"


func can_interact(player: Player) -> bool:
	return player != null and not done and not GameState.has_flag(&"cancelled") and _carrying(person())


func hold_time(_player: Player) -> float:
	return 2.0


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var p: Node = person()
	done = true
	if p != null and p.has_method("give_item"):
		p.call("give_item", player)
	GameState.set_flag(&"pohl_tag_read")
	AudioDirector.play_3d("m4d_tag_slot", global_position + Vector3.UP, 0.0)
	print("[m4d] Pohl's tag is read into the record")
