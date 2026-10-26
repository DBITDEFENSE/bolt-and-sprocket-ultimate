class_name BuildablePart
extends Interactable
## One buildable's part at one candidate spot (the Totenglocke's three on Map 1; the Lodestone's three on Map 4,
## T-105). Only the spot seeded for this match (the quest's random "parts") exists; the others are hidden. Parts
## are shared: picking one up counts for every player. `buildable_id` names the weapon (BUILDABLES below: its
## quest, its parts and their names, the random key); a map places each part with part_id + spot_id.

const QUEST: StringName = &"map01_requiem"   # the Totenglocke's (kept for the old callers)
const NAMES: Dictionary = {&"tg_part_bell": "the small bronze bell", &"tg_part_frame": "the firing frame",
	&"tg_part_crank": "the crank assembly",
	&"ls_part_coil": "the relay coil", &"ls_part_cradle": "the gyro cradle", &"ls_part_lens": "the lead-glass lens"}
## buildable id -> {quest, random (the quest's random key with the seeded spot per part), parts, label}
const BUILDABLES: Dictionary = {
	&"totenglocke": {"quest": &"map01_requiem", "random": "parts", "parts": [&"tg_part_bell", &"tg_part_frame", &"tg_part_crank"], "label": "Totenglocke"},
	&"lodestone": {"quest": &"map04_kuendigung", "random": "ls_parts", "parts": [&"ls_part_coil", &"ls_part_cradle", &"ls_part_lens"], "label": "Lodestone"},
}

@export var part_id: StringName = &"tg_part_bell"
@export var spot_id: StringName = &""
## Which buildable this part belongs to (derived from the part id when left empty).
@export var buildable_id: StringName = &""

var _live: bool = true


func _ready() -> void:
	interact_size = Vector3(0.8, 0.6, 0.8)
	super._ready()
	add_to_group(&"buildable_parts")
	if buildable_id == &"":
		buildable_id = buildable_of(part_id)
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	_on_quest_loaded(quest_id())
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == StringName("part_" + String(part_id)) and bool(v) and _live:
			_set_live(false))


## The buildable a part id belongs to (&"" for an unknown part).
static func buildable_of(pid: StringName) -> StringName:
	for bid: Variant in BUILDABLES.keys():
		if ((BUILDABLES[bid] as Dictionary)["parts"] as Array).has(pid):
			return StringName(bid)
	return &""


static func cfg_of(bid: StringName) -> Dictionary:
	return BUILDABLES.get(bid, BUILDABLES[&"totenglocke"])


func quest_id() -> StringName:
	return StringName(cfg_of(buildable_id).get("quest", QUEST))


func build_greybox() -> void:
	match part_id:
		&"tg_part_bell":
			InteractableArt.place(self, "tg_tg_part_bell", func(r: Node3D) -> void: InteractableArt.part_bell(r))
		&"tg_part_frame":
			InteractableArt.place(self, "tg_tg_part_frame", func(r: Node3D) -> void: InteractableArt.part_frame(r))
		&"ls_part_coil":
			InteractableArt.place(self, "ls_part_coil", func(r: Node3D) -> void: InteractableArt.part_coil(r))
		&"ls_part_cradle":
			InteractableArt.place(self, "ls_part_cradle", func(r: Node3D) -> void: InteractableArt.part_cradle(r))
		&"ls_part_lens":
			InteractableArt.place(self, "ls_part_lens", func(r: Node3D) -> void: InteractableArt.part_lens(r))
		_:
			InteractableArt.place(self, "tg_tg_part_crank", func(r: Node3D) -> void: InteractableArt.part_crank(r))
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.9, 0.6, 0.25)
	glow.light_energy = 0.5
	glow.omni_range = 1.8
	glow.position = Vector3(0, 0.4, 0)
	add_child(glow)


func _on_quest_loaded(qid: StringName) -> void:
	if qid != quest_id():
		return
	var picks: Variant = QuestManager.random_value(qid, str(cfg_of(buildable_id).get("random", "parts")))
	var mine: bool = picks is Dictionary and StringName(str((picks as Dictionary).get(String(part_id), ""))) == spot_id
	_set_live(mine and not has_part(part_id))


func _set_live(on: bool) -> void:
	_live = on
	visible = on
	if area != null:
		area.collision_layer = LAYER_INTERACTABLE if on else 0


static func has_part(id: StringName) -> bool:
	return GameState.has_flag(StringName("part_" + String(id)))


## How many of `bid`'s parts the squad holds (the Totenglocke's when no id is given).
static func parts_held(bid: StringName = &"totenglocke") -> int:
	var n: int = 0
	for id: Variant in (cfg_of(bid)["parts"] as Array):
		if has_part(StringName(id)):
			n += 1
	return n


static func parts_of(bid: StringName) -> Array:
	return (cfg_of(bid)["parts"] as Array).duplicate()


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
	_taken_fx(player.player_id, parts_held(buildable_id))
	Net.mirror(self, &"_taken_fx", [player.player_id, parts_held(buildable_id)])


## Every peer: the part goes, the banner counts it; the finder's survivor remarks on it.
func _taken_fx(by_player: int, held: int) -> void:
	AudioDirector.play_3d("build_part", global_position, 0.0)
	if by_player == Net.local_player_id():
		GLVO.say_player("BUILD_PART", 0.6)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "%s part: %s  (%d/3)" % [cfg_of(buildable_id).get("label", "Totenglocke"), NAMES.get(part_id, "part"), held], 2.5)
	_set_live(false)
