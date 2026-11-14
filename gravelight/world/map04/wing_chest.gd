class_name WingChest
extends Interactable
## UPDATE 10 §3 (contract C6, T-156): the reward at the wingtip of the wing walk: a crew's emergency locker strapped
## to the wingtip's spar. Hold 1.5 s to open it (once per match): inside lies a perk-tier `discount_token` (the next
## tonic tier the taker brews costs discount_token_mult of its price; PerkManager) and, when the bots/wonder worker
## fills `wonder_part` (an item id, e.g. an Undertow-class part), that part too (QuestManager.give_item). Take each
## with a short hold. Host-owned, mirrored. Group "wing_chests".

## An Undertow-class wonder part for this slot (empty until the wonder worker sets it; bots read `wonder_slot`).
@export var wonder_part: StringName = &""
@export var wonder_slot: String = "undertow_class"

enum State { SHUT, OPEN, EMPTY }
var state: int = State.SHUT
var taken_by: int = -1
var _lid: Node3D
var _token: MeshInstance3D
var _glow: OmniLight3D


func _ready() -> void:
	interact_size = Vector3(1.4, 1.2, 1.0)
	interact_offset = Vector3(0, 0.6, 0)
	super._ready()
	add_to_group(&"wing_chests")


func build_greybox() -> void:
	Props.block(self, Vector3(-0.6, 0, -0.35), Vector3(0.6, 0.6, 0.35), "feldgrau")
	Props.block(self, Vector3(-0.62, 0.25, -0.37), Vector3(0.62, 0.3, 0.37), "iron")
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 0.35)
	add_child(_lid)
	Props.block(_lid, Vector3(-0.6, 0, -0.7), Vector3(0.6, 0.08, 0), "feldgrau")
	_token = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.015
	_token.mesh = cm
	_token.position = Vector3(0, 0.62, 0)
	_token.material_override = Mats.get_mat("brass")
	_token.visible = false
	add_child(_token)
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 0.9, 0)
	_glow.light_color = Color(0.95, 0.75, 0.35)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	_glow.shadow_enabled = false
	add_child(_glow)
	var l: Label3D = add_label(self, "NOTPROVIANT", Vector3(0, 0.45, -0.36), 14, Color(0.9, 0.85, 0.6))


func get_prompt(_player: Player) -> String:
	match state:
		State.SHUT:
			return "Hold [%s] to open the wingtip locker" % prompt_key(&"interact")
		State.OPEN:
			return "Hold [%s] to take the discount token%s" % [prompt_key(&"interact"), " and the part" if wonder_part != &"" else ""]
	return ""


func can_interact(player: Player) -> bool:
	return state != State.EMPTY and player != null and player.is_alive()


func hold_time(_player: Player) -> float:
	return 1.5 if state == State.SHUT else 0.4


func interact(player: Player) -> void:
	if not Net.is_authority() or not can_interact(player):
		return
	if state == State.SHUT:
		_open()
		Net.mirror(self, &"_open")
		return
	take(player)


func _open() -> void:
	state = State.OPEN
	if _lid != null:
		create_tween().tween_property(_lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK)
	if _token != null:
		_token.visible = true
	if _glow != null:
		_glow.light_energy = 1.2
	AudioDirector.play_3d("door_open", global_position + Vector3.UP * 0.5, 0.0)


## The taker gets the token (and the part, when the slot is filled).
func take(player: Player) -> void:
	if state != State.OPEN or player == null:
		return
	taken_by = player.player_id
	PerkManager.grant_discount_token(player.player_id)
	if wonder_part != &"":
		QuestManager.give_item(wonder_part, player.player_id)
	_emptied()
	Net.mirror(self, &"_emptied")
	var text: String = "DISCOUNT TOKEN\nyour next tonic tier costs half"
	if player.is_local:
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", text, 3.0)
	elif Net.session != null:
		Net.session.notify_player(player.player_id, &"banner", [text, 3.0])
	GameState.set_flag(&"wing_chest_taken")
	feedback_2d(player, "intel_pickup", 0.0)


func _emptied() -> void:
	state = State.EMPTY
	if _token != null:
		_token.visible = false
	if _glow != null:
		_glow.light_energy = 0.0
