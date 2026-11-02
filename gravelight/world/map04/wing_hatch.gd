class_name WingHatch
extends Interactable
## UPDATE 10 §3 (T-156): the way out onto the wing and back (WingWalk). `direction` "out" stands at the torn panel in
## the port crawlway (shut until the wing walk opens; its prompt warns); "in" stands on the catwalk's landing. A hold
## climbs the ladder the strafing run left behind: the body moves to the other end (on the user's own machine,
## net_local, like any movement; the host sees the player arrive and runs the clip state from there).
## Group "wing_hatches"; bots use it like a player (the bots worker's `wing_walk` task: target WingHatch).

@export var direction: String = "out"
@export var to_pos: Vector3 = Vector3(-40, 3.45, 44.2)
@export var to_yaw: float = 180.0

var open: bool = false
var climbs: int = 0


func _ready() -> void:
	interact_size = Vector3(1.6, 2.0, 1.0)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"wing_hatches")
	if direction == "in":
		open = true


func build_greybox() -> void:
	# a ladder of torn spar frame: two rails and rungs, and a stencil
	for sx: float in [-0.3, 0.3]:
		Props.block(self, Vector3(sx - 0.03, 0.0, -0.05), Vector3(sx + 0.03, 2.4, 0.05), "iron")
	for i: int in 7:
		Props.cyl(self, Vector3(0, 0.3 + 0.32 * float(i), 0), 0.02, 0.6, "iron", Vector3(0, 0, 90))
	var l: Label3D = add_label(self, "NOTAUSSTIEG · FLÜGEL" if direction == "out" else "EINSTIEG", Vector3(0, 2.2, 0.08), 16, Color(0.95, 0.85, 0.55))
	l.outline_size = 4


func set_open(on: bool) -> void:
	if direction == "out":
		open = on


func get_prompt(_player: Player) -> String:
	if not open:
		return ""
	if direction == "out":
		return "Hold [%s] to climb out onto the wing\nCLIP IN at a tether post: turbulence throws the unclipped off" % prompt_key(&"interact")
	return "Hold [%s] to climb back inside" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return open and player != null and player.is_alive()


func hold_time(_player: Player) -> float:
	return 0.8


func net_local() -> bool:
	return true


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	climb(player)


## Moves the body to the other end of the ladder (the user's machine; a bot on the host).
func climb(player: Player) -> void:
	climbs += 1
	player.global_position = to_pos
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(to_yaw)
	if player.is_local:
		AudioDirector.play_2d("door_open", -6.0, 0.05)
