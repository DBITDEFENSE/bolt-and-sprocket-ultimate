class_name QuestInteract
extends Interactable
## A plain quest switch (UPDATE 07, T-114): a thing you hold [interact] on that completes a QuestManager `interact`
## step by its target (the Kranich's bomb-bay ramp, Jette's office hatch). The step's own `requires_item` and
## `requires_flags` gate it; the prompt says what is still missing (`missing_text`, with %s for the flag's label).
## Greybox: a small panel with a lamp; `label_text` is printed above it.

@export var target: StringName = &"kranich_ramp"
@export var label_text: String = ""
@export var prompt_text: String = "board the Kranich"
@export var missing_text: String = "Locked: %s"
## flag name -> the words the prompt uses for it ("hangar_key": "the hangar key")
@export var flag_labels: Dictionary = {}
@export var size: Vector3 = Vector3(1.2, 1.6, 0.6)

var _done: bool = false


func _ready() -> void:
	interact_size = size
	interact_offset = Vector3(0, size.y * 0.5, 0)
	super._ready()
	GLBus.quest_step_completed.connect(_on_step)


func build_greybox() -> void:
	InteractableArt.place(self, "lever_box", func(r: Node3D) -> void: InteractableArt.lever_box(r))
	if label_text != "":
		add_label(self, label_text, Vector3(0, size.y + 0.3, 0), 18, Color(0.9, 0.82, 0.6))


func _on_step(_qid: StringName, _sid: StringName) -> void:
	pass


## Pure: the prompt for a target that is active, with the flags it still waits on.
static func prompt_for(active: bool, missing: PackedStringArray, labels: Dictionary, key: String, do_text: String, locked_fmt: String) -> String:
	if not active:
		return ""
	if not missing.is_empty():
		var words: PackedStringArray = []
		for f: String in missing:
			words.append(str(labels.get(f, f.replace("_", " "))))
		return locked_fmt % ", ".join(words)
	return "Hold [%s] to %s" % [key, do_text]


func get_prompt(_player: Player) -> String:
	if _done:
		return ""
	var active: bool = QuestManager.interact_ready(target) or not QuestManager.missing_flags(target).is_empty()
	return prompt_for(active, QuestManager.missing_flags(target), flag_labels, prompt_key(&"interact"), prompt_text, missing_text)


func can_interact(_player: Player) -> bool:
	return not _done and QuestManager.interact_ready(target)


func interact(player: Player) -> void:
	if _done or not Net.is_authority():
		return
	if QuestManager.interact(target, player.player_id):
		_done = true
		feedback_2d(player, "buy", -2.0)
