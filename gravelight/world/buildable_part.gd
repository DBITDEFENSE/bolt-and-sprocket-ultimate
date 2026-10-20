class_name BuildablePart
extends Interactable
## One Totenglocke part at one candidate spot. Only the spot seeded for this match (quest random "parts")
## exists; the others are hidden. Parts are shared: picking one up counts for every player.

const QUEST: StringName = &"map01_requiem"
const NAMES: Dictionary = {&"tg_part_bell": "the small bronze bell", &"tg_part_frame": "the firing frame",
	&"tg_part_crank": "the crank assembly"}

@export var part_id: StringName = &"tg_part_bell"
@export var spot_id: StringName = &""

var _live: bool = true


func _ready() -> void:
	interact_size = Vector3(0.8, 0.6, 0.8)
	super._ready()
	add_to_group(&"buildable_parts")
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	_on_quest_loaded(QUEST)
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == StringName("part_" + String(part_id)) and bool(v) and _live:
			_set_live(false))


func build_greybox() -> void:
	match part_id:
		&"tg_part_bell":
			InteractableArt.place(self, "tg_tg_part_bell", func(r: Node3D) -> void: InteractableArt.part_bell(r))
		&"tg_part_frame":
			InteractableArt.place(self, "tg_tg_part_frame", func(r: Node3D) -> void: InteractableArt.part_frame(r))
		_:
			InteractableArt.place(self, "tg_tg_part_crank", func(r: Node3D) -> void: InteractableArt.part_crank(r))
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.9, 0.6, 0.25)
	glow.light_energy = 0.5
	glow.omni_range = 1.8
	glow.position = Vector3(0, 0.4, 0)
	add_child(glow)


func _on_quest_loaded(qid: StringName) -> void:
	if qid != QUEST:
		return
	var picks: Variant = QuestManager.random_value(QUEST, "parts")
	var mine: bool = picks is Dictionary and StringName(str((picks as Dictionary).get(String(part_id), ""))) == spot_id
	_set_live(mine and not has_part(part_id))


func _set_live(on: bool) -> void:
	_live = on
	visible = on
	if area != null:
		area.collision_layer = LAYER_INTERACTABLE if on else 0


static func has_part(id: StringName) -> bool:
	return GameState.has_flag(StringName("part_" + String(id)))


static func parts_held() -> int:
	var n: int = 0
	for id: Variant in NAMES.keys():
		if has_part(StringName(id)):
			n += 1
	return n


func get_prompt(_player: Player) -> String:
	if not _live:
		return ""
	return "Hold [%s] to take %s" % [prompt_key(&"interact"), NAMES.get(part_id, "the part")]


func can_interact(_player: Player) -> bool:
	return _live


func interact(player: Player) -> void:
	if not _live:
		return
	GameState.set_flag(StringName("part_" + String(part_id)), true)
	GLBus.item_picked_up.emit(part_id, player.player_id)
	_taken_fx(player.player_id, parts_held())
	Net.mirror(self, &"_taken_fx", [player.player_id, parts_held()])


## Every peer: the part goes, the banner counts it; the finder's survivor remarks on it.
func _taken_fx(by_player: int, held: int) -> void:
	AudioDirector.play_3d("build_part", global_position, 0.0)
	if by_player == Net.local_player_id():
		GLVO.say_player("BUILD_PART", 0.6)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "Totenglocke part: %s  (%d/3)" % [NAMES.get(part_id, "part"), held], 2.5)
	_set_live(false)
