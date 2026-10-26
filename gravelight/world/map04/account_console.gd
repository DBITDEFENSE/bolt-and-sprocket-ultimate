class_name AccountConsole
extends Interactable
## The console in the Account (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.8, T-113): a terminal with a slot
## shaped like a tally mark and one key marked CANCEL under a glass cover. Shielded by the Account Manager's field
## until she "escalates" (flag manager_escalated); then: lift the cover (hold 2 s; the terminal asks once, in the
## Operator's voice, OPR_M4D_SURE_01), then the vote: every living human holds CANCEL (bots never vote; solo: you);
## the player whose hold completes it turns the key, and the cancel ending runs (cancel_ending.gd) with their id.
## `cancel now` (the console verb) skips the vote. Pure rules are static for the tests.

enum C { DARK, SHIELDED, COVER, VOTE, DONE }

var state: C = C.DARK
var votes: Array[int] = []
var cover_open: bool = false
var _field: MeshInstance3D
var _cover: MeshInstance3D
var _lamp: OmniLight3D


## What the console does next: dark before the Manager, shielded while she attends, the cover once she escalated.
static func state_for(manager_present: bool, escalated: bool, cover_lifted: bool, cancelled: bool) -> C:
	if cancelled:
		return C.DONE
	if escalated:
		return C.VOTE if cover_lifted else C.COVER
	return C.SHIELDED if manager_present else C.DARK


## True when every living human has voted.
static func vote_complete(voted: Array, humans_alive: Array) -> bool:
	if humans_alive.is_empty():
		return false
	for pid: Variant in humans_alive:
		if not voted.has(int(pid)):
			return false
	return true


func _ready() -> void:
	interact_size = Vector3(2.2, 1.8, 1.6)
	interact_offset = Vector3(0, 0.9, 0.4)
	super._ready()
	add_to_group(&"account_console")
	GLBus.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: _refresh())
	_refresh()


func build_greybox() -> void:
	Props.block(self, Vector3(-0.9, 0.0, -0.5), Vector3(0.9, 1.05, 0.5), "machine_grey")
	Props.block(self, Vector3(-0.8, 1.05, -0.4), Vector3(0.8, 1.15, 0.4), "steel")
	var face: MeshInstance3D = add_box(self, Vector3(1.2, 0.5, 0.02), Vector3(0, 1.45, 0.3), Interactable.greybox_mat(Color(0.45, 0.2, 0.75), 2.5))
	face.rotation.x = deg_to_rad(-20.0)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the slot (a tally mark) and the key under its cover
	add_box(self, Vector3(0.03, 0.14, 0.01), Vector3(-0.45, 1.16, 0.2), Interactable.greybox_mat(Color(0.05, 0.03, 0.08)))
	var key: MeshInstance3D = add_box(self, Vector3(0.08, 0.12, 0.04), Vector3(0.3, 1.21, 0.15), Mats.get_mat("brass"))
	key.name = "Key"
	var kl: Label3D = add_label(self, "CANCEL", Vector3(0.3, 1.165, 0.36), 12, Color(0.9, 0.2, 0.15, 1.0))
	kl.rotation.x = deg_to_rad(-90.0)
	kl.pixel_size = 0.002
	_cover = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.3, 0.22, 0.34)
	_cover.mesh = bm
	_cover.position = Vector3(0.3, 1.26, 0.15)
	_cover.material_override = Mats.get_mat("glass")
	_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cover)
	_field = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.2
	cm.height = 2.6
	cm.radial_segments = 24
	_field.mesh = cm
	_field.position = Vector3(0, 1.3, 0)
	_field.material_override = Interactable.greybox_mat(Color(0.5, 0.2, 0.9, 0.22), 1.5)
	(_field.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.visible = false
	add_child(_field)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 1.8, 0.4)
	_lamp.light_color = Color(0.6, 0.3, 1.0)
	_lamp.light_energy = 0.6
	_lamp.omni_range = 6.0
	_lamp.shadow_enabled = false
	add_child(_lamp)


func _refresh() -> void:
	if state == C.DONE:
		return
	var s: C = state_for(GameState.has_flag(&"manager_present"), GameState.has_flag(&"manager_escalated"), cover_open, GameState.has_flag(&"cancelled"))
	if s == state:
		return
	state = s
	if _field != null:
		_field.visible = state == C.SHIELDED and not GameState.has_flag(&"manager_field_down")
	if _lamp != null:
		_lamp.light_energy = {C.DARK: 0.6, C.SHIELDED: 2.0, C.COVER: 1.2, C.VOTE: 1.6, C.DONE: 0.2}[state]
		_lamp.light_color = Color(0.9, 0.85, 0.6) if state in [C.COVER, C.VOTE] else Color(0.6, 0.3, 1.0)


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot:
		return ""
	match state:
		C.DARK:
			return "The terminal is dark"
		C.SHIELDED:
			return "The console is locked: she is still attending" if GameState.has_flag(&"manager_field_down") else "The console is shielded"
		C.COVER:
			return "Hold [%s] to lift the glass cover" % prompt_key(&"interact")
		C.VOTE:
			var need: int = humans_alive().size()
			var tail: String = "" if need <= 1 else "  (%d/%d)" % [votes.size(), need]
			if votes.has(player.player_id):
				return "CANCEL: waiting for the others%s" % tail
			return "Hold [%s] to CANCEL%s" % [prompt_key(&"interact"), tail]
	return ""


func can_interact(player: Player) -> bool:
	if player == null or player.is_bot:
		return false
	return state == C.COVER or (state == C.VOTE and not votes.has(player.player_id))


func hold_time(_player: Player) -> float:
	return 2.0 if state == C.COVER else 1.5


func humans_alive() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and not p.is_bot and not p.is_companion and p.is_alive():
			out.append(p.player_id)
	return out


func interact(player: Player) -> void:
	if state == C.COVER:
		lift_cover()
	elif state == C.VOTE and not votes.has(player.player_id):
		votes.append(player.player_id)
		AudioDirector.play_3d("buy", global_position, -6.0)
		if vote_complete(votes, humans_alive()):
			turn_key(player.player_id)


func lift_cover() -> void:
	if cover_open:
		return
	cover_open = true
	GameState.set_flag(&"cover_lifted")
	if _cover != null:
		var tw: Tween = create_tween()
		tw.tween_property(_cover, "position:y", _cover.position.y + 0.3, 0.8).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(_cover, "rotation:x", deg_to_rad(-70.0), 0.8)
	GLVO.play(&"OPR_M4D_SURE_01")
	_refresh()


## The key turns: the cancel ending, with the player who completed the vote at the key.
func turn_key(pid: int) -> void:
	if state == C.DONE:
		return
	state = C.DONE
	GameState.set_flag(&"cancelled")
	AudioDirector.play_3d("door_open", global_position + Vector3.UP, 2.0, 0.0)
	var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
	if ctl != null and ctl.has_method("start_cancel"):
		ctl.call("start_cancel", pid)
