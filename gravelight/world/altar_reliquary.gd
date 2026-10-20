class_name AltarReliquary
extends Interactable
## The Salt Chapel altar (step 5). With the Overseer's Key, open the reliquary: Liesl's music box, which plays
## the match's 4-note melody. Afterwards the box can be replayed here at any time.

const QUEST: StringName = &"map01_requiem"


func _ready() -> void:
	interact_size = Vector3(3.0, 1.2, 0.3)
	interact_offset = Vector3(0, 1.0, -0.2)
	super._ready()


func get_prompt(_player: Player) -> String:
	var key: String = prompt_key(&"interact")
	if QuestManager.interact_ready(&"altar"):
		return "Hold [%s] to open the reliquary with the Overseer's Key" % key
	if QuestManager.has_item(&"music_box"):
		return "Hold [%s] to play Liesl's music box" % key
	if QuestManager.is_active(QUEST, &"s5_reliquary"):
		return "A reliquary, locked. The key must be somewhere."
	return ""


func can_interact(_player: Player) -> bool:
	return QuestManager.interact_ready(&"altar") or QuestManager.has_item(&"music_box")


func interact(player: Player) -> void:
	if QuestManager.interact_ready(&"altar"):
		QuestManager.interact(&"altar", player.player_id)
	if QuestManager.has_item(&"music_box"):
		play_box()
		Net.mirror(self, &"play_box")


func play_box() -> void:
	var notes: Variant = QuestManager.random_value(QUEST, "melody")
	if notes is Array:
		QuestBell.play_melody(self, notes, global_position + Vector3.UP)
		GLBus.vo_line_started.emit(&"MUSIC_BOX", &"LSL", "[music box] " + " - ".join(PackedStringArray(notes as Array)), 2.6)
