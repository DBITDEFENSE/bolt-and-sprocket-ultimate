class_name InnFrontDoor
extends Node3D
## The Kreuzweg's front door (T-072): a plank leaf in the taproom's north wall under the east porch, barred from
## inside with a beam in two iron brackets. The doorway is filled with an invisible collider (gen_map00
## "FrontDoorBlock"), so nobody walks through it and the navmesh stays a wall: the leaf is dressing that swings.
## Only the round 1 opening uses it (InnOpening): unbarred and thrown open as the patrons run, then shut and barred
## again. Origin: the sill's centre on the wall's middle plane; local +X along the wall, local +Z into the taproom;
## the hinge is on the west jamb and the leaf swings into the room.

@export var width: float = 1.6
@export var height: float = 2.4
@export var wall: float = 0.3

var is_open: bool = false
var barred: bool = true
var angle: float = 0.0
var _hinge: Node3D
var _bar: Node3D
var _bar_rest: Transform3D
var _tween: Tween


func _ready() -> void:
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-width * 0.5 + 0.03, 0, 0.0)
	add_child(_hinge)
	var leaf: Node3D = Node3D.new()
	leaf.name = "Leaf"
	_hinge.add_child(leaf)
	var w: float = width - 0.06
	_block(leaf, Vector3(0.0, 0.01, -0.035), Vector3(w, height - 0.02, 0.035), "planks")
	for y: float in [0.3, height * 0.5, height - 0.35]:   # ledges on the inside face
		_block(leaf, Vector3(0.05, y - 0.07, 0.035), Vector3(w - 0.05, y + 0.07, 0.06), "beam")
	_block(leaf, Vector3(w - 0.2, 1.0, -0.06), Vector3(w - 0.12, 1.06, -0.035), "iron")   # the latch outside
	_block(leaf, Vector3(w - 0.2, 1.0, 0.035), Vector3(w - 0.12, 1.12, 0.07), "iron")     # the latch inside
	for hy: float in [0.35, height - 0.4]:   # strap hinges
		_block(leaf, Vector3(0.0, hy - 0.03, 0.06), Vector3(0.5, hy + 0.03, 0.07), "iron")
	# the brackets either side, on the wall's inner face, and the bar in them
	var face: float = wall * 0.5
	for bx: float in [-width * 0.5 - 0.1, width * 0.5 + 0.1]:
		_block(self, Vector3(bx - 0.05, 1.0, face), Vector3(bx + 0.05, 1.22, face + 0.12), "iron")
	_bar = Node3D.new()
	_bar.name = "Bar"
	add_child(_bar)
	_block(_bar, Vector3(-width * 0.5 - 0.22, -0.07, -0.05), Vector3(width * 0.5 + 0.22, 0.07, 0.05), "beam")
	_bar_rest = Transform3D(Basis(), Vector3(0, 1.12, face + 0.11))
	_bar.transform = _bar_rest


func _block(parent: Node3D, a: Vector3, b: Vector3, key: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_box()
	mi.scale = (b - a).abs()
	mi.position = (a + b) * 0.5
	mi.material_override = Mats.get_mat(key)
	mi.set_meta("keep", true)
	parent.add_child(mi)


## Lifts the bar off its brackets and leans it against the wall by the door.
func unbar() -> void:
	if not barred:
		return
	barred = false
	var lean: Transform3D = Transform3D(Basis(Vector3.BACK, deg_to_rad(78.0)), Vector3(width * 0.5 + 0.45, 0.62, wall * 0.5 + 0.12))
	var tw: Tween = create_tween()
	tw.tween_property(_bar, "transform", lean, 0.5).set_trans(Tween.TRANS_QUAD)


## Drops the bar back into its brackets.
func bar() -> void:
	if barred:
		return
	barred = true
	var tw: Tween = create_tween()
	tw.tween_property(_bar, "transform", _bar_rest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func open(deg: float = 105.0, seconds: float = 0.7) -> void:
	is_open = true
	_swing(-deg, seconds, Tween.EASE_OUT)
	AudioDirector.play_3d("door_creak", global_position + Vector3(0, 1.6, 0), 0.0)


func close(seconds: float = 0.45) -> void:
	is_open = false
	_swing(0.0, seconds, Tween.EASE_IN)


func _swing(to_deg: float, seconds: float, ease_: Tween.EaseType) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(a: float) -> void:
		angle = a
		_hinge.rotation.y = deg_to_rad(a), angle, to_deg, maxf(0.05, seconds)).set_trans(Tween.TRANS_QUAD).set_ease(ease_)
