class_name CarryCradle
extends Interactable
## Where a CarryObject is set down (UPDATE 07, docs/MAP4_FERNFLUG.md §5.6): the hangar's office hatch (Hale's;
## `choice` runs Peg's choice when the core arrives: keep it for the rocket, or hand it through) and the rocket's
## engine bay in the silo (the keep road's end; `delivered_flag`). Co-op: the host takes it, every peer mirrors.

@export var cradle_id: StringName = &"hangar_cradle"
@export var accepts: StringName = &"impeller_core"
@export var label: String = "the office hatch"
@export var choice: bool = false
@export var delivered_flag: StringName = &""

var taken: bool = false
var deciding: bool = false


func _ready() -> void:
	interact_size = Vector3(1.4, 1.6, 1.0)
	interact_offset = Vector3(0, 0.8, 0)
	super._ready()
	add_to_group(&"carry_cradles")


func build_greybox() -> void:
	var v: Node3D = Node3D.new()
	v.name = "Visual"
	add_child(v)
	add_box(v, Vector3(1.2, 0.1, 0.9), Vector3(0, 0.05, 0), greybox_mat(Color(0.3, 0.3, 0.32)))
	add_box(v, Vector3(1.2, 1.4, 0.08), Vector3(0, 0.7, 0.42), greybox_mat(Color(0.5, 0.52, 0.5)))
	add_label(v, label.to_upper(), Vector3(0, 1.5, 0.38), 18, Color(0.9, 0.85, 0.7, 0.9))


func _carried(player: Player) -> CarryObject:
	var c: CarryObject = CarryObject.carried_by(player.player_id)
	return c if c != null and c.carry_id == accepts and c.deliver_to == cradle_id else null


func get_prompt(player: Player) -> String:
	if taken or deciding:
		return ""
	var c: CarryObject = _carried(player)
	if c == null:
		return ""
	return "Hold [%s] to set %s in %s" % [prompt_key(&"interact"), c.label, label]


func can_interact(player: Player) -> bool:
	return not taken and not deciding and _carried(player) != null


func hold_time(_player: Player) -> float:
	return 1.0


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	var c: CarryObject = _carried(player)
	if choice and not GameState.has_flag(&"peg_resigned") and not GameState.has_flag(&"peg_delivered"):
		deciding = true
		c.set_down(global_position + global_basis * Vector3(0, 0, -1.2), cradle_id)
		var pc: PegsChoice = PegsChoice.start(get_tree(), func(opt: String) -> void: _decided(opt, c))
		print("[m4c] %s: the core is at the hatch, the choice is open (%s)" % [cradle_id, pc.decider_label()])
		return
	_take(c)


func _take(c: CarryObject) -> void:
	taken = true
	c.deliver()
	Net.mirror(c, &"deliver")
	AudioDirector.play_3d("buy", global_position + Vector3.UP, -4.0)
	if delivered_flag != &"":
		GameState.set_flag(delivered_flag)
	print("[m4c] %s took %s" % [cradle_id, c.carry_id])


## Peg decided: keep = the core is hers again, bound for the rocket; hand over = the hatch takes it.
func _decided(opt: String, c: CarryObject) -> void:
	deciding = false
	if opt == "keep":
		c.deliver_to = &"rocket_cradle"
		c.label = "the impeller core"
		taken = true   # the hatch never takes anything now
	else:
		_take(c)
