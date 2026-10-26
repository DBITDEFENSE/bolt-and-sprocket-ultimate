class_name StoryRadio
extends Interactable
## A radio that answers once (UPDATE 07, docs/MAP4_FERNFLUG.md §5.2, §5.8): Dee's set on the hangar cage's
## counter (her story in four lines, then she opens her side door through the GroomController), and the radar
## shack's set that reaches Fasbender once the generator runs (his four lines, and the rocket's burn numbers:
## three two-digit values seeded per match, `GameState.flags["burn"]`, flag `burn_known`). The lines are story
## speakers (priority 4), so they queue in order through the VOManager. Co-op: the host answers, every peer mirrors.

@export var radio_id: StringName = &"radio"
@export var label: String = "the radio"
@export var lines: PackedStringArray = []
@export var flag: StringName = &""
@export var requires_power: bool = false
@export var reveals_burn: bool = false

var done: bool = false
var _dial: MeshInstance3D


## Pure: the three burn numbers for a seed (10..99 each, never two alike).
static func burn_numbers(seed_v: int) -> Array[int]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("burn:%d" % seed_v)
	var out: Array[int] = []
	while out.size() < 3:
		var n: int = rng.randi_range(10, 99)
		if not out.has(n):
			out.append(n)
	return out


func _ready() -> void:
	interact_size = Vector3(0.9, 0.7, 0.7)
	interact_offset = Vector3(0, 0.35, 0)
	super._ready()
	add_to_group(&"story_radios")


func build_greybox() -> void:
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	add_child(v)
	add_box(v, Vector3(0.6, 0.4, 0.4), Vector3(0, 0.2, 0), greybox_mat(Color(0.2, 0.18, 0.15)))
	_dial = add_box(v, Vector3(0.18, 0.06, 0.02), Vector3(0.1, 0.26, -0.21), greybox_mat(Color(1.0, 0.75, 0.35), 3.0))
	add_box(v, Vector3(0.02, 0.8, 0.02), Vector3(-0.25, 0.8, 0), greybox_mat(Color(0.5, 0.5, 0.5)))


func get_prompt(_player: Player) -> String:
	if done:
		return ""
	if requires_power and not GameState.power_on:
		return "Power must be activated"
	return "Hold [%s] to answer %s" % [prompt_key(&"interact"), label]


func can_interact(_player: Player) -> bool:
	return not done and (not requires_power or GameState.power_on)


func hold_time(_player: Player) -> float:
	return 1.0


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	answer(player.player_id)
	Net.mirror(self, &"answer", [player.player_id])


## The set answers: the lines queue, the flag is set, the burn numbers are seeded and shown.
func answer(by_player: int) -> void:
	if done:
		return
	done = true
	if _dial != null:
		_dial.material_override = greybox_mat(Color(0.5, 1.0, 0.6), 4.0)
	AudioDirector.play_3d("buy", global_position + Vector3.UP * 0.5, -6.0)
	for id: String in lines:
		GLVO.play(StringName(id))
	if reveals_burn:
		var nums: Array[int] = burn_numbers(int(GameState.flags.get(&"match_seed", randi() % 100000)))
		GameState.flags[&"burn"] = nums
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "FASBENDER: burn at %d, %d, %d. Write it down." % [nums[0], nums[1], nums[2]], 6.0)
	if flag != &"" and Net.is_authority():
		GameState.set_flag(flag)
	print("[m4c] %s answered by P%d" % [radio_id, by_player])
