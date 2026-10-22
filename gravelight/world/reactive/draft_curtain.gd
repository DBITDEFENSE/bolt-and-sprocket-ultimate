class_name DraftCurtain
extends Node3D
## A curtain that moves in the draught from its window (Update 02 section 8, T-053). Drawn as `panels` hanging
## strips from the rod at the node's origin (local -Y down; local -Z is the way the draught pushes it, into the
## room), each strip on its own pivot. It billows with the wind (ReactiveWind: gusts), harder when its window's
## barricade has lost boards (`window` = the Barricade's path), and flutters when shot (a DecorTarget "cloth").
## Built at load time; a few rotations a frame, and nothing at all when the camera is far away.

const FAR_M: float = 30.0

@export var height: float = 1.7
@export var panels: int = 4
@export var mat_key: String = "cloth_red"
@export var window: NodePath = NodePath("")

var _pivots: Array[Node3D] = []
var _phase: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0
var _kick: float = 0.0       # a flutter (shot) that dies away
var _kick_v: float = 0.0
var _bar: Node = null
## The largest swing this curtain has made, radians (tests).
var max_swing: float = 0.0


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(global_position.snapped(Vector3.ONE * 0.1))) if is_inside_tree() else 1
	for i: int in panels:
		var piv: Node3D = Node3D.new()
		piv.name = "Panel%d" % i
		piv.position = Vector3(-0.15 + i * 0.1, 0, -0.02 - (i % 2) * 0.03)
		add_child(piv)
		var mi: MeshInstance3D = Props.obox(piv, Vector3(0, -height * 0.5, 0), Vector3(0.11, height, 0.03), mat_key)
		mi.set_meta("keep", true)
		_pivots.append(piv)
		_phase.append(rng.randf() * TAU)
	DecorHit.make_target(self, Vector3(0, -height * 0.5, -0.03), 0.22, &"cloth")
	if not window.is_empty():
		_bar = get_node_or_null(window)
	_t = rng.randf() * 10.0


## A shot (or a blast) shakes it; `dir` is unused beyond a sign, the strength scales the kick.
func flutter(_dir: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	_kick_v += 3.5 * strength


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null and cam.global_position.distance_squared_to(global_position) > FAR_M * FAR_M:
		return
	_t += delta
	var wind: float = ReactiveWind.strength(get_tree())
	var draught: float = 1.0
	if _bar != null and is_instance_valid(_bar) and _bar.get("boards") != null:
		draught += (6.0 - clampf(float(_bar.get("boards")), 0.0, 6.0)) / 6.0 * 1.4
	_kick_v += (-30.0 * _kick - 3.0 * _kick_v) * delta
	_kick += _kick_v * delta
	var lean: float = (0.04 + wind * 0.16) * draught
	for i: int in _pivots.size():
		var ph: float = _phase[i]
		var a: float = lean * (0.55 + 0.45 * sin(_t * (1.3 + 0.25 * i) + ph) * sin(_t * 0.47 + ph * 2.0)) + _kick * (0.7 + 0.15 * i)
		var side: float = 0.05 * lean * sin(_t * 0.9 + ph)
		_pivots[i].rotation = Vector3(a, 0.0, side)
		max_swing = maxf(max_swing, absf(a))
