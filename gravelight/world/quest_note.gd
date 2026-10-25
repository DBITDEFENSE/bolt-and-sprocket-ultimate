class_name QuestNote
extends Interactable
## A paper note you pick up (Map 0 radio frequencies). Reports to the QuestManager by tag.

@export var tag: StringName = &"radio_note"
@export var item_id: StringName = &"note_a"
@export var note_text: String = "3.120"
@export var numeral: String = "I"

var _taken: bool = false


func _ready() -> void:
	interact_size = Vector3(0.6, 0.5, 0.5)
	super._ready()


func build_greybox() -> void:
	InteractableArt.place(self, "note_paper", func(r: Node3D) -> void: InteractableArt.note_paper(r))
	var l: Label3D = add_label(self, "%s\n%s" % [numeral, note_text], Vector3(-0.01, 0.007, 0), 14, Color(0.15, 0.12, 0.1))
	l.rotation.x = -PI * 0.5
	l.outline_size = 0
	var glint: OmniLight3D = OmniLight3D.new()
	glint.light_color = Color(0.85, 0.75, 1.0)
	glint.light_energy = 0.25
	glint.omni_range = 1.2
	glint.position = Vector3(0, 0.2, 0)
	add_child(glint)


func get_prompt(_player: Player) -> String:
	if _taken:
		return ""
	return "Hold [%s] to take the note (%s)" % [prompt_key(&"interact"), note_text]


func can_interact(_player: Player) -> bool:
	return not _taken


func interact(player: Player) -> void:
	if _taken:
		return
	_taken = true
	QuestManager.collect(tag, item_id, player.player_id)   # (T-086: the one who took it reads it aloud)
	var text: String = "Note %s: \"%s Mc/s\"" % [numeral, note_text]
	if player.is_local:
		GLBus.intel_found.emit(item_id)
		AudioDirector.play_2d("intel_pickup", 0.0, 0.0)
		(player.get_tree().get_first_node_in_group(&"hud") as Node).call("show_banner", text, 2.5)
	elif Net.session != null:
		Net.session.notify_player(player.player_id, &"intel", [String(item_id)])
		Net.session.notify_player(player.player_id, &"sfx2d", ["intel_pickup", 0.0])
		Net.session.notify_player(player.player_id, &"banner", [text, 2.5])
	_net_taken()
	Net.mirror(self, &"_net_taken")


func _net_taken() -> void:
	_taken = true
	hide()
	area.collision_layer = 0
