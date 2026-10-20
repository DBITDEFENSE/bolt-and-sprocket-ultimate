class_name QuestPickup
extends Interactable
## A small quest object you take or examine. One of three behaviors (set by exports):
##  item_id:          gives a quest item (Nachtglas shard, debug keys...) via QuestManager.give_item()
##  collect_tag:      counts toward a `collect` step (phonograph cylinders) and plays `vo_line`
##  interact_target:  completes an `interact` step (Wren's brother's tag); `exchange_line` plays a scripted exchange

@export var item_id: StringName = &""
@export var collect_tag: StringName = &""
@export var interact_target: StringName = &""
@export var label: String = "it"
@export var vo_line: StringName = &""
@export var exchange_line: StringName = &""
@export var glint_for: StringName = &""       # character id that sees a glint (the tag glints for Wren)
@export var color: Color = Color(0.7, 0.4, 1.0)

var taken: bool = false
var _glint: OmniLight3D


func _ready() -> void:
	interact_size = Vector3(0.7, 0.6, 0.7)
	super._ready()


func build_greybox() -> void:
	# what it is: a phonograph cylinder, a dog tag, the Nachtglas shard, or a glowing token for anything else
	if collect_tag == &"cylinder":
		InteractableArt.place(self, "pickup_cylinder", func(r: Node3D) -> void: InteractableArt.cylinder_pickup(r))
	elif interact_target == &"kb4471":
		InteractableArt.place(self, "pickup_tag", func(r: Node3D) -> void: InteractableArt.tag_pickup(r))
	elif item_id == &"nachtglas_shard":
		InteractableArt.place(self, "pickup_shard", func(r: Node3D) -> void: InteractableArt.shard_pickup(r))
	else:
		add_box(self, Vector3(0.22, 0.14, 0.22), Vector3(0, 0.07, 0), greybox_mat(color, 1.2))
	_glint = OmniLight3D.new()
	_glint.light_color = color
	_glint.light_energy = 0.6 if glint_for == &"" or GameState.character_id == glint_for else 0.0
	_glint.omni_range = 1.6
	_glint.position = Vector3(0, 0.3, 0)
	add_child(_glint)


func get_prompt(_player: Player) -> String:
	if taken:
		return ""
	return "Hold [%s] to take %s" % [prompt_key(&"interact"), label]


func can_interact(_player: Player) -> bool:
	return not taken


func interact(player: Player) -> void:
	if taken:
		return
	taken = true
	feedback_2d(player, "item_pickup")
	Net.mirror(self, &"_net_taken")
	if item_id != &"":
		QuestManager.give_item(item_id, player.player_id)
	if collect_tag != &"":
		QuestManager.collect(collect_tag, StringName(name))
	if interact_target != &"":
		QuestManager.interact(interact_target, player.player_id)
	if vo_line != &"":
		GLVO.play(vo_line)
	if exchange_line != &"":
		play_exchange(self, exchange_line)
		Net.mirror(self, &"_net_exchange", [String(exchange_line)])
	hide()
	area.collision_layer = 0


## Co-op client: taken by someone (anyone's pickup counts for the whole squad).
func _net_taken() -> void:
	taken = true
	hide()
	area.collision_layer = 0


func _net_exchange(line_id: String) -> void:
	play_exchange(self, StringName(line_id))


## Plays a scripted multi-speaker exchange stored on a line's "exchange" field as subtitles.
## Only Wren or Dutch get the full exchange (it's theirs); anyone else hears the first line alone.
static func play_exchange(host: Node, line_id: StringName) -> void:
	var rec: Dictionary = GLVO.lines.get(String(line_id), {})
	var raw: Variant = rec.get("exchange", [])
	var ex: Array = []
	if raw is Array:
		ex = raw
	elif raw is String:
		var parsed: Variant = JSON.parse_string(str(raw).replace("'", "\""))
		ex = parsed if parsed is Array else []
	var full: bool = GameState.character_id == &"wren" or GameState.character_id == &"dutch"
	if ex.is_empty() or not full:
		GLVO.play_local(line_id)
		return
	var t: float = 0.0
	for e: Variant in ex:
		var pair: Array = e as Array
		if pair.size() < 2:
			continue
		var spk: StringName = StringName(str(pair[0]))
		var text: String = GLVO.strip_tags(str(pair[1]))
		var dur: float = maxf(1.8, float(text.length()) * 0.065)
		host.get_tree().create_timer(t).timeout.connect(func() -> void: GLBus.vo_line_started.emit(line_id, spk, text, dur))
		t += dur + 0.3
