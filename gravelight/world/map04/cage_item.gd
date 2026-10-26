class_name CageItem
extends Interactable
## Dee's cage, the side egg (UPDATE 07, docs/MAP4_FERNFLUG.md §9.2): three things the yard rule says go on the
## pile (a Nachtglas casing from the wreck's bay, the bomber's coil, the beekeeper's honey from the hangar's
## kitchen corner). Each sets `cage_<item>` and plays Dee's line; all three set `dee_cage_done` (her gantry line
## changes, the exfil cutscene reads it). Shared: one pickup counts for the squad. Co-op: the host takes it.

const ITEMS: Array[StringName] = [&"casing", &"bomber_coil", &"honey"]

@export var item_id: StringName = &"casing"
@export var line: String = ""
@export var label: String = "a casing"

var taken: bool = false


## Pure: every item flag is set.
static func all_done(flags: Dictionary) -> bool:
	for id: StringName in ITEMS:
		if not flags.has(StringName("cage_" + String(id))):
			return false
	return true


func _ready() -> void:
	interact_size = Vector3(0.7, 0.5, 0.7)
	interact_offset = Vector3(0, 0.2, 0)
	super._ready()
	add_to_group(&"cage_items")
	taken = GameState.has_flag(StringName("cage_" + String(item_id)))
	visible = not taken


func build_greybox() -> void:
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	add_child(v)
	match item_id:
		&"honey":
			add_box(v, Vector3(0.18, 0.24, 0.18), Vector3(0, 0.12, 0), greybox_mat(Color(0.9, 0.6, 0.15), 1.5))
		&"bomber_coil":
			add_box(v, Vector3(0.5, 0.3, 0.5), Vector3(0, 0.15, 0), greybox_mat(Color(0.7, 0.45, 0.2)))
		_:
			add_box(v, Vector3(0.3, 0.3, 0.9), Vector3(0, 0.15, 0), greybox_mat(Color(0.45, 0.45, 0.5)))
	var glint: OmniLight3D = OmniLight3D.new()
	glint.light_color = Color(0.95, 0.88, 0.75)
	glint.light_energy = 0.35
	glint.omni_range = 1.4
	glint.shadow_enabled = false
	glint.position = Vector3(0, 0.3, 0)
	add_child(glint)


func get_prompt(_player: Player) -> String:
	return "" if taken else "Hold [%s] to take %s for Dee's pile" % [prompt_key(&"interact"), label]


func can_interact(_player: Player) -> bool:
	return not taken


func hold_time(_player: Player) -> float:
	return 0.6


func interact(player: Player) -> void:
	if taken or not Net.is_authority():
		return
	take(player.player_id)
	Net.mirror(self, &"take", [player.player_id])


func take(by_player: int) -> void:
	if taken:
		return
	taken = true
	visible = false
	area.collision_layer = 0
	AudioDirector.play_3d("build_part", global_position, 0.0)
	if Net.is_authority():
		GameState.set_flag(StringName("cage_" + String(item_id)))
		if line != "":
			GLVO.play(StringName(line))
		if all_done(GameState.flags) and not GameState.has_flag(&"dee_cage_done"):
			GameState.set_flag(&"dee_cage_done")
			var hud: Node = get_tree().get_first_node_in_group(&"hud")
			if hud != null:
				hud.call("show_banner", "DEE'S YARD RULE: nothing on this range goes to waste", 4.0)
	print("[m4c] cage item %s taken by P%d" % [item_id, by_player])
