class_name BoatKey
extends Interactable
## U-1047's ignition key (UPDATE 10 contract C3/C5, design 4, DECISIONS T-153): DER KIELHOLER drops it where he dies,
## or, after his fail-safe dive, it floats up at the dock edge. A brass key on a cork float with a paper tag
## ("U-1047 · Brecht"). Picking it up (the host decides): the GameState flag `boat_key`, GLBus.item_picked_up
## (&"boat_key"), QuestManager's item, a banner; every peer removes it. One key per match.

const ITEM: StringName = &"boat_key"
## Walking within this many metres (flat) takes the key: bots never aim at interactables.
const AUTO_COLLECT_M: float = 1.6

var taken: bool = false
var floating: bool = false
var _art: Node3D
var _age: float = 0.0
var _light: OmniLight3D


## Places the key under Gameplay at `pos` (the existing one when it is already out). `floating`: it rises out of
## the water over 2 s (the fail-safe).
static func spawn_at(t: Node, pos: Vector3, float_up: bool = false) -> BoatKey:
	var parent: Node3D = null
	if t != null and t.get("gameplay") is Node3D:
		parent = t.get("gameplay")
	elif t is Node3D:
		parent = t
	if parent == null:
		return null
	var existing: BoatKey = parent.get_node_or_null("BoatKey") as BoatKey
	if existing != null:
		return existing
	if GameState.has_flag(ITEM):
		return null
	var k: BoatKey = BoatKey.new()
	k.name = "BoatKey"
	k.floating = float_up
	k.position = pos
	parent.add_child(k)
	return k


func _ready() -> void:
	interact_size = Vector3(1.4, 1.4, 1.4)
	interact_offset = Vector3(0, 0.5, 0)
	super._ready()
	add_to_group(&"boat_keys")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.45)
	_light.light_energy = 1.4
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	if floating:
		AudioDirector.play_3d("water_splash", global_position, -2.0, 0.05)


func build_greybox() -> void:
	_art = Node3D.new()
	_art.name = "Art"
	add_child(_art)
	var brass: StandardMaterial3D = greybox_mat(Color(0.75, 0.6, 0.28), 0.6)
	var cork: StandardMaterial3D = greybox_mat(Color(0.55, 0.4, 0.25))
	var paper: StandardMaterial3D = greybox_mat(Color(0.86, 0.82, 0.7))
	add_box(_art, Vector3(0.05, 0.22, 0.02), Vector3(0, 0.45, 0), brass)           # the shank
	add_box(_art, Vector3(0.12, 0.08, 0.02), Vector3(0, 0.6, 0), brass)            # the bow
	add_box(_art, Vector3(0.06, 0.04, 0.02), Vector3(0.04, 0.36, 0), brass)        # the bit
	add_box(_art, Vector3(0.16, 0.1, 0.1), Vector3(0, 0.7, 0), cork)               # the cork float
	add_box(_art, Vector3(0.14, 0.08, 0.005), Vector3(0.12, 0.55, 0), paper)       # the tag
	var l: Label3D = add_label(_art, "U-1047 · Brecht", Vector3(0, 0.95, 0), 14, Color(0.95, 0.9, 0.75))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func get_prompt(_player: Player) -> String:
	if taken:
		return ""
	return "Hold [%s] to take the ignition key (U-1047 · Brecht)" % prompt_key(&"interact")


func can_interact(_player: Player) -> bool:
	return not taken


func hold_time(_player: Player) -> float:
	return 0.6


func interact(player: Player) -> void:
	if taken or not Net.is_authority():
		return
	take(player.player_id)


## The host's pickup (tools and bots call it too).
func take(pid: int) -> void:
	if taken:
		return
	_taken_fx(pid)
	GameState.set_flag(ITEM, true)
	QuestManager.give_item(ITEM, pid)
	GLBus.item_picked_up.emit(ITEM, pid)
	Net.mirror(self, &"_taken_fx", [pid])


func _taken_fx(_pid: int) -> void:
	taken = true
	AudioDirector.play_3d("ui_click", global_position + Vector3.UP * 0.6, 0.0, 0.0)
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	if n != null and (n as MapRoot).hud != null:
		(n as MapRoot).hud.show_banner("THE IGNITION KEY  ·  U-1047", 3.0)
	queue_free()


## Bots finish Letzte Fahrt alone: any living player (bots included) who walks onto the key takes it (the host
## decides; the hold-to-interact stays for the humans who aim at it).
func _physics_process(_delta: float) -> void:
	if taken or not Net.is_authority() or not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() <= AUTO_COLLECT_M \
				and absf(p.global_position.y - global_position.y) < 2.0:
			take(p.player_id)
			return


func _process(delta: float) -> void:
	_age += delta
	if _art == null:
		return
	var rise: float = clampf(_age / 2.0, 0.0, 1.0) if floating else 1.0
	_art.position.y = lerpf(-1.2, 0.0, rise) + sin(_age * 2.0) * 0.05
	_art.rotation.y += delta * 0.8
	_light.light_energy = 1.0 + sin(_age * 3.0) * 0.4
