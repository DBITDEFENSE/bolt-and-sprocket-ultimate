class_name Lift
extends Node3D
## "Der Sarg": the electric cage lift (Map 1, E_LIFT → F_CHAPEL). An AnimatableBody3D cage rides between
## top_y and bottom_y (world heights) at this node's x/z. Ride 25 s, cooldown 60 s (data/map01.json).
## Call/ride from either landing or from inside. Gates close while moving. Usable once zone_id is open.

enum State { AT_TOP, AT_BOTTOM, MOVING }

@export var top_y: float = 0.0
@export var bottom_y: float = -12.0
@export var cage_size: Vector3 = Vector3(4, 3, 4)
@export var zone_id: StringName = &"E_LIFT"
## Call buttons, local to the lift node, at each landing's height (y is added to the landing height).
@export var top_button: Vector3 = Vector3(2.6, 1.2, -2.4)
@export var top_button_yaw: float = 0.0
@export var bottom_button: Vector3 = Vector3(1.6, 1.2, 3.4)
@export var bottom_button_yaw: float = 180.0

var state: State = State.AT_TOP
var cooldown_left: float = 0.0
var _t: float = 0.0
var _from_y: float = 0.0
var _to_y: float = 0.0
var _cage: AnimatableBody3D
var _cur_y: float = 0.0
var _gate_bodies: Array[CollisionShape3D] = []
var _gate_meshes: Array[MeshInstance3D] = []
var _winch: AudioStreamPlayer3D   # looping winch, a child of the cage: plays only while MOVING


## Pure: seconds until the lift can be used again (0 when ready).
static func cooldown_remaining(elapsed_since_arrival: float, cooldown: float) -> float:
	return maxf(0.0, cooldown - elapsed_since_arrival)


static func cfg() -> Dictionary:
	return PowerSwitch.map01()["lift"]


func _ready() -> void:
	add_to_group(&"lifts")
	_cage = AnimatableBody3D.new()
	_cage.name = "Cage"
	_cage.collision_layer = 1
	_cage.collision_mask = 0
	_cage.sync_to_physics = true
	_cage.set_meta("surface", "metal")   # footsteps (Player._floor_surface)
	add_child(_cage)
	_winch = AudioDirector.make_loop_3d("lift_winch", _cage)
	if _winch != null:
		_winch.position = Vector3.UP * cage_size.y
	_cur_y = top_y
	_cage.global_position = Vector3(global_position.x, top_y, global_position.z)
	var floor_cs: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(cage_size.x, 0.2, cage_size.z)
	floor_cs.shape = floor_box
	floor_cs.position = Vector3(0, -0.1, 0)
	_cage.add_child(floor_cs)
	# Cage art (InteractableArt.lift_cage, cached): chequer floor, corner angles, sheet-and-lattice sides, crosshead
	# and hoist ropes. Solid sides are left/right; scissor gates close the -Z and +Z sides while moving.
	var cs_: Vector3 = cage_size
	InteractableArt.place(_cage, "lift_cage_%d_%d_%d" % [int(cs_.x * 10.0), int(cs_.y * 10.0), int(cs_.z * 10.0)],
		func(r: Node3D) -> void: InteractableArt.lift_cage(r, cs_))
	for side: float in [-1.0, 1.0]:
		var wall_cs: CollisionShape3D = CollisionShape3D.new()
		var wb: BoxShape3D = BoxShape3D.new()
		wb.size = Vector3(0.1, cage_size.y, cage_size.z)
		wall_cs.shape = wb
		wall_cs.position = Vector3(side * cage_size.x * 0.5, cage_size.y * 0.5, 0)
		_cage.add_child(wall_cs)
	for side: float in [-1.0, 1.0]:
		var gate_cs: CollisionShape3D = CollisionShape3D.new()
		var gb: BoxShape3D = BoxShape3D.new()
		gb.size = Vector3(cage_size.x, cage_size.y, 0.1)
		gate_cs.shape = gb
		gate_cs.position = Vector3(0, cage_size.y * 0.5, side * cage_size.z * 0.5)
		gate_cs.disabled = true
		_cage.add_child(gate_cs)
		_gate_bodies.append(gate_cs)
		var gw: float = cage_size.x - 0.16
		var gh: float = cage_size.y * 0.9
		var gm: MeshInstance3D = InteractableArt.place(_cage, "lift_gate_%d_%d" % [int(gw * 10.0), int(gh * 10.0)],
			func(r: Node3D) -> void: InteractableArt.lift_gate(r, gw, gh), Vector3(0, 0, side * (cage_size.z * 0.5 - 0.1)))
		gm.visible = false
		_gate_meshes.append(gm)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0, cage_size.y - 0.3, 0)
	lamp.omni_range = 5.0
	lamp.light_energy = 0.8
	lamp.light_color = Color(1.0, 0.8, 0.5)
	_cage.add_child(lamp)
	var bulb: MeshInstance3D = Interactable.add_box(_cage, Vector3(0.12, 0.1, 0.12), Vector3(0, cage_size.y - 0.14, 0), Mats.get_mat("bulb_warm"))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate: Label3D = Interactable.add_label(_cage, "FÖRDERKORB\nHÖCHSTLAST\n8 PERSONEN", Vector3(cage_size.x * 0.5 - 0.075, 1.65, -0.75), 14,
		Color(0.12, 0.1, 0.08, 1.0), SurfaceText.PRINT)
	plate.rotation.y = -PI * 0.5
	plate.outline_size = 0
	# Controls: one inside the cage, one at each landing.
	_add_control(_cage, Vector3(cage_size.x * 0.5 - 0.15, 1.2, 0), -90.0, &"cage")
	_add_control(self, top_button + Vector3(0, top_y - global_position.y, 0), top_button_yaw, &"top")
	_add_control(self, bottom_button + Vector3(0, bottom_y - global_position.y, 0), bottom_button_yaw, &"bottom")


func _add_control(parent: Node3D, pos: Vector3, yaw: float, where: StringName) -> void:
	var c: LiftControl = LiftControl.new()
	c.name = "Control_" + String(where)   # a stable path for co-op requests
	c.lift = self
	c.where = where
	c.position = pos
	c.rotation.y = deg_to_rad(yaw)
	parent.add_child(c)


func is_usable() -> bool:
	return GameState.is_zone_open(zone_id)


func prompt_for(where: StringName) -> String:
	if not is_usable():
		return ""
	if state == State.MOVING:
		return "The lift is moving..."
	if cooldown_left > 0.0:
		return "Lift returning... %d" % int(ceil(cooldown_left))
	var here_top: bool = state == State.AT_TOP
	if where == &"cage":
		return "Hold [%s] to ride the lift %s" % [Interactable.prompt_key(&"interact"), "down" if here_top else "up"]
	if (where == &"top" and here_top) or (where == &"bottom" and not here_top):
		return "Hold [%s] to ride the lift" % Interactable.prompt_key(&"interact")
	return "Hold [%s] to call the lift" % Interactable.prompt_key(&"interact")


func request(_where: StringName) -> bool:
	if not is_usable() or state == State.MOVING or cooldown_left > 0.0:
		AudioDirector.play_2d("deny", -4.0)
		return false
	_from_y = top_y if state == State.AT_TOP else bottom_y
	_to_y = bottom_y if state == State.AT_TOP else top_y
	_net_start(_from_y, _to_y)
	Net.mirror(self, &"_net_start", [_from_y, _to_y])
	return true


## The ride starts (host from request(), clients from the host); every peer then moves the cage itself.
func _net_start(from_y: float, to_y: float) -> void:
	_from_y = from_y
	_to_y = to_y
	state = State.MOVING
	_t = 0.0
	_set_gates(true)
	AudioDirector.play_3d("door_open", _cage.global_position + Vector3.UP, 0.0, 0.0)
	if _winch != null:
		_winch.play()


func _set_gates(closed: bool) -> void:
	for cs: CollisionShape3D in _gate_bodies:
		cs.set_deferred("disabled", not closed)
	for m: MeshInstance3D in _gate_meshes:
		m.visible = closed


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if state != State.MOVING:
		# Keep the cage synced to this node (handles the lift being placed after _ready).
		var at: Vector3 = Vector3(global_position.x, _cur_y, global_position.z)
		if not _cage.global_position.is_equal_approx(at):
			_cage.global_position = at
		return
	var ride: float = float(cfg()["ride_seconds"])
	_t += delta
	var k: float = clampf(_t / ride, 0.0, 1.0)
	var eased: float = k * k * (3.0 - 2.0 * k)
	_cur_y = lerpf(_from_y, _to_y, eased)
	_cage.global_position = Vector3(global_position.x, _cur_y, global_position.z)
	if k >= 1.0:
		state = State.AT_BOTTOM if _to_y == bottom_y else State.AT_TOP
		cooldown_left = float(cfg()["cooldown_seconds"])
		_set_gates(false)
		if _winch != null:
			_winch.stop()
		AudioDirector.play_3d("lift_arrive", _cage.global_position + Vector3.UP, 2.0, 0.0)


func cage_y() -> float:
	return _cage.global_position.y


## The buttons. Kept in this file so the Lift stays one self-contained node.
class LiftControl extends Interactable:
	var lift: Lift
	var where: StringName = &"cage"

	func _ready() -> void:
		interact_size = Vector3(0.6, 0.6, 0.3)
		super._ready()

	func build_greybox() -> void:
		InteractableArt.place(self, "lift_button", func(r: Node3D) -> void: InteractableArt.lift_button(r))
		var lamp: MeshInstance3D = add_box(self, Vector3(0.05, 0.05, 0.03), Vector3(0.07, 0.04, -0.06), Mats.get_mat("lamp_amber"))
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func get_prompt(_player: Player) -> String:
		return lift.prompt_for(where)

	func can_interact(_player: Player) -> bool:
		return lift.is_usable() and lift.state != Lift.State.MOVING and lift.cooldown_left <= 0.0

	func interact(_player: Player) -> void:
		lift.request(where)
