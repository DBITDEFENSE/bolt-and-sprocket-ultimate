class_name QuestNote
extends Interactable
## A paper note you pick up (Map 0 radio frequencies). Reports to the QuestManager by tag.

@export var tag: StringName = &"radio_note"
@export var item_id: StringName = &"note_a"
@export var note_text: String = "3.120"
@export var numeral: String = "I"
## UPDATE 07 (T-114): "note" (Map 0's frequencies), "file" (the Fernflug files: an extension number), "tag" (a crew
## tag: a name), "model" (Jette's glider models). The banner and the prompt follow the kind; `set_flag` is raised on
## pickup (the files set file_1..3 so the hangar unlock can count them).
@export var kind: String = "note"
@export var set_flag: StringName = &""
## The text may come from a quest's seeded random instead ("quest_id:key", digits `digit_from`..+`digit_count`):
## the Fernflug files each carry two digits of the hangar's PA extension (T-114).
@export var random_key: String = ""
@export var digit_from: int = 0
@export var digit_count: int = 2

var _taken: bool = false


func _ready() -> void:
	interact_size = Vector3(0.6, 0.5, 0.5)
	super._ready()


func build_greybox() -> void:
	InteractableArt.place(self, "note_paper", func(r: Node3D) -> void: InteractableArt.note_paper(r))
	var l: Label3D = add_label(self, "%s\n%s" % [numeral, note_text], Vector3(-0.01, 0.007, 0), 14, Color(0.15, 0.12, 0.1), SurfaceText.PRINT)
	l.rotation.x = -PI * 0.5
	l.outline_size = 0
	var glint: OmniLight3D = OmniLight3D.new()
	glint.light_color = Color(0.85, 0.75, 1.0)
	glint.light_energy = 0.25
	glint.omni_range = 1.2
	glint.position = Vector3(0, 0.2, 0)
	add_child(glint)


## The seeded digits of a quest random, joined ("" when the quest is not loaded).
static func digits_text(v: Variant, from: int, count: int) -> String:
	var s: String = ""
	if v == null:
		return ""
	if v is Array:
		for d: Variant in v:
			s += str(d)
	else:
		s = str(v)
	return s.substr(from, count)


func text_now() -> String:
	if random_key != "" and random_key.contains(":"):
		var q: StringName = StringName(random_key.get_slice(":", 0))
		var k: String = random_key.get_slice(":", 1)
		if QuestManager.has_quest(q):
			var t: String = digits_text(QuestManager.random_value(q, k), digit_from, digit_count)
			if t != "":
				note_text = t
	return note_text


func get_prompt(_player: Player) -> String:
	if _taken:
		return ""
	text_now()
	match kind:
		"file":
			return "Hold [%s] to read the file (%s)" % [prompt_key(&"interact"), note_text]
		"tag":
			return "Hold [%s] to take the tag (%s)" % [prompt_key(&"interact"), note_text]
		"model":
			return "Hold [%s] to take the glider model" % prompt_key(&"interact")
	return "Hold [%s] to take the note (%s)" % [prompt_key(&"interact"), note_text]


## The pickup banner per kind.
static func banner_text(k: String, num: String, text: String) -> String:
	match k:
		"file":
			return "Fernflug file %s: extension \"%s\"" % [num, text]
		"tag":
			return "Crew tag %s: \"%s\"" % [num, text]
		"model":
			return "Glider model %s: %s" % [num, text]
	return "Note %s: \"%s Mc/s\"" % [num, text]


func can_interact(_player: Player) -> bool:
	return not _taken


func interact(player: Player) -> void:
	if _taken:
		return
	_taken = true
	if set_flag != &"":
		GameState.set_flag(set_flag)
	QuestManager.collect(tag, item_id, player.player_id)   # (T-086: the one who took it reads it aloud)
	var text: String = banner_text(kind, numeral, text_now())
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
