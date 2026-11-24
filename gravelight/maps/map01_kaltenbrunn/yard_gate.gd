extends Node3D
## T-272: Kaltenbrunn's north gate, between the brick pillars under the mine's name board. Two iron-framed plank leaves
## on hinges at the pillars' inner faces ("LeafW" / "LeafE", pivots built by gen_map01's _build_yard_gate). Shut all
## match long; the round-30 Sherman (ShermanEvent) comes up the north road and the gate is thrown open for it: while a
## Sherman on its scripted drive (ShermanTank.Mode.DRIVE) is within `open_m` of the gate, or any part of its hull is
## still in the gateway, the leaves swing out (away from the yard, over the open snow, so they never sweep a player);
## once it is through they swing shut behind it. Drawing only: the gateway's collider (Geometry/Gate) never moves, so
## nobody walks out of the yard and the navmesh is the same with the gate open or shut; the tank's scripted drive goes
## through colliders. Runs on every peer from the tank it sees (a client's tank is the host's puppet).
## The round-1 opening (InnOpening with map01_opening.json) opens it the same way for the miners who run out.

@export var swing_deg: float = 90.0
@export var open_m: float = 16.0      # a driving tank this close (flat) opens the gate
@export var gateway_m: float = 4.2    # a tank whose centre is this close is in the gateway: the gate stays open
@export var swing_s: float = 2.4      # seconds from shut to open

var opened: bool = false              # where it is going (the smoke reads it)
var opens: int = 0                    # times it has opened (the smoke counts)
var _k: float = 0.0                   # 0 shut .. 1 open
var _t: float = 0.0
var _w: Node3D = null
var _e: Node3D = null


func _ready() -> void:
	add_to_group(&"yard_gate")
	_w = get_node_or_null("LeafW") as Node3D
	_e = get_node_or_null("LeafE") as Node3D


## True when a Sherman is driving up to it or is still in the gateway, or while the round-1 opening's miners run out
## through it (map01_opening.json "gate": open_at .. close_at seconds into the opening).
func want_open() -> bool:
	for o: Node in get_tree().get_nodes_in_group(&"inn_opening"):
		var op: InnOpening = o as InnOpening
		if op != null and op.phase == InnOpening.Phase.RUNNING and op.cfg.get("gate") is Dictionary:
			var g: Dictionary = op.cfg["gate"]
			if op.t >= float(g.get("open_at", 0.0)) and op.t < float(g.get("close_at", 0.0)):
				return true
	for n: Node in get_tree().get_nodes_in_group(&"sherman"):
		var tk: ShermanTank = n as ShermanTank
		if tk == null or not is_instance_valid(tk) or tk.is_wreck():
			continue
		var d: float = Vector2(tk.global_position.x - global_position.x, tk.global_position.z - global_position.z).length()
		if d < gateway_m or (tk.mode == ShermanTank.Mode.DRIVE and d < open_m):
			return true
	return false


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.2
		var w: bool = want_open()
		if w != opened:
			opened = w
			if w:
				opens += 1
			if AudioDirector.has_sound("door_creak"):
				AudioDirector.play_3d("door_creak", global_position + Vector3(0, 1.6, 0), 3.0)
	var goal: float = 1.0 if opened else 0.0
	if is_equal_approx(_k, goal):
		return
	_k = move_toward(_k, goal, delta / maxf(0.1, swing_s))
	var a: float = deg_to_rad(swing_deg) * smoothstep(0.0, 1.0, _k)
	if _w != null:
		_w.rotation.y = a       # the west leaf's free end goes to -Z (out of the yard)
	if _e != null:
		_e.rotation.y = -a      # and the east leaf's
