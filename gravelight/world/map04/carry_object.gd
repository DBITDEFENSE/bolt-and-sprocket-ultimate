class_name CarryObject
extends Interactable
## A thing one player carries (UPDATE 07, docs/MAP4_FERNFLUG.md §5.6): the Kranich's impeller core, rolled out on
## the salt by the crash, carried to the hangar's office hatch (Peg's choice) and, if she keeps it, to the rocket.
## The Totenhafen Ballast rules: the `ballast` status while carried (no sprint, slow), it rides in the carrier's
## arms, and it goes back to the ground where the carrier went down. A CarryCradle whose `accepts` matches
## `carry_id` takes it. Co-op: the host decides, every peer mirrors the lift / drop.

@export var carry_id: StringName = &"impeller_core"
@export var label: String = "the impeller core"
@export var deliver_to: StringName = &"hangar_cradle"
@export var carry_status: StringName = &"ballast"

var carrier: int = 0           # player id carrying it, 0 = on the ground
var delivered: bool = false
var trips: int = 0             # how many times it was set down at a cradle (the second carry is "heavier")
var _art: Node3D
var _carried: Node3D


func _ready() -> void:
	interact_size = Vector3(1.6, 1.2, 1.6)
	interact_offset = Vector3(0, 0.5, 0)
	super._ready()
	add_to_group(&"carry_objects")
	GLBus.player_downed.connect(_on_player_downed)


func build_greybox() -> void:
	_art = Node3D.new()
	_art.name = "Art"
	add_child(_art)
	_core_art(_art, Vector3(0, 0.45, 0))


## The core: a lead-grey drum with a violet glass window, humming.
static func _core_art(parent: Node3D, at: Vector3) -> void:
	add_box(parent, Vector3(0.9, 0.9, 0.9), at, greybox_mat(Color(0.35, 0.36, 0.4)))
	var glow: MeshInstance3D = add_box(parent, Vector3(0.5, 0.5, 0.95), at, greybox_mat(Color(0.6, 0.3, 1.0), 5.0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.62, 0.3, 1.0)
	l.light_energy = 1.2
	l.omni_range = 5.0
	l.shadow_enabled = false
	l.position = at
	parent.add_child(l)


func get_prompt(player: Player) -> String:
	if delivered or carrier != 0:
		return ""
	if someone_carrying(player.player_id):
		return "Your arms are full"
	return "Hold [%s] to lift %s%s (no sprint, slow)" % [prompt_key(&"interact"), label, " (heavier this time)" if trips > 0 else ""]


func can_interact(player: Player) -> bool:
	return not delivered and carrier == 0 and not someone_carrying(player.player_id)


func hold_time(_player: Player) -> float:
	return 1.2


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	lift(player.player_id)
	Net.mirror(self, &"lift", [player.player_id])


## The core leaves the ground for the carrier's arms.
func lift(pid: int) -> void:
	if carrier == pid:
		return
	carrier = pid
	_art.visible = false
	area.collision_layer = 0
	var p: Player = _player(pid)
	if p != null:
		_carried = Node3D.new()
		_carried.name = "CarriedCore"
		_carried.position = Vector3(0, 0.55, -0.95)
		p.add_child(_carried)
		_core_art(_carried, Vector3.ZERO)
	AudioDirector.play_3d("board_slam", global_position + Vector3.UP, -6.0, 0.0)
	if trips > 0 and GameState.has_trait(&"peg"):
		GLVO.play(&"PEG_M4C_CARRY_01")


## Back on the ground (the carrier went down, or a cradle set it down to decide).
func drop(at: Vector3 = Vector3.INF) -> void:
	if at != Vector3.INF:
		global_position = at
	carrier = 0
	if _carried != null and is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null
	if not delivered:
		_art.visible = true
		area.collision_layer = LAYER_INTERACTABLE


## A cradle took it for good.
func deliver() -> void:
	delivered = true
	drop()
	area.collision_layer = 0
	_art.visible = false


## Set down at a cradle to decide (Peg's choice): liftable again, bound for the next cradle.
func set_down(at: Vector3, next: StringName) -> void:
	trips += 1
	deliver_to = next
	drop(at)


func _process(delta: float) -> void:
	if carrier == 0 or delivered:
		return
	var p: Player = _player(carrier)
	if p == null or not p.is_alive():
		drop()
		return
	p.apply_status(carry_status, maxf(0.3, delta * 3.0))


func _on_player_downed(pid: int) -> void:
	if pid == carrier and Net.is_authority():
		drop()
		Net.mirror(self, &"drop")


func _player(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


static func someone_carrying(pid: int) -> bool:
	for n: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"carry_objects"):
		if int(n.get("carrier")) == pid:
			return true
	return false


## The object `pid` carries, or null.
static func carried_by(pid: int) -> CarryObject:
	for n: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"carry_objects"):
		if int(n.get("carrier")) == pid:
			return n as CarryObject
	return null
