class_name GateDoor
extends BuyDoor
## A bought door that SWINGS open instead of lifting away like a boarded doorway (Map 0's way outdoors, DECISIONS
## T-080): a field gate of plank leaves on posts, or a drawn door that already swings (`swing_node`, e.g. the inn's
## front door, InnFrontDoor). Same purchase, zones, link groups and co-op mirroring as BuyDoor; only the look and the
## opening differ. Origin and size as BuyDoor (the opening's centre on the floor; local +Z is the side the leaves
## swing toward when `swing_out` is +1).

## Leaves drawn when there is no swing_node: 1 (hinged at -X) or 2 (hinged at both jambs, meeting in the middle).
@export var leaves: int = 2
## How far the leaves swing (degrees) and toward which side of the opening (+1 = local +Z, -1 = local -Z).
@export var swing_deg: float = 100.0
@export var swing_out: float = 1.0
## A node that draws and swings the door itself (needs open(deg, seconds), and unbar() / held_open if it has them).
@export var swing_node: NodePath
## Where the price is painted (local, per face): beside the opening when the leaves move through it.
@export var label_offset: Vector3 = Vector3.ZERO

var _hinges: Array[Node3D] = []


func build_greybox() -> void:
	_visual = Node3D.new()
	_visual.name = "Greybox"
	add_child(_visual)
	if swing_node.is_empty():
		_build_leaves()
	var off: Vector3 = label_offset if label_offset != Vector3.ZERO else Vector3(0, size.y * 0.6, 0)
	for side: float in [-1.0, 1.0]:
		var l: Label3D = add_label(_visual, "%s\n%d" % [label, cost], off + Vector3(0, 0, side * (size.z * 0.5 + 0.06)), 28, Color(1.0, 0.92, 0.75, 0.95))
		l.rotation.y = 0.0 if side > 0 else PI
		_cost_labels.append(l)


## Plank leaves on strap hinges: three rails, two stiles and a diagonal brace each, a chain and padlock across the
## middle (kept off the static batch: they move).
func _build_leaves() -> void:
	var n: int = clampi(leaves, 1, 2)
	var lw: float = size.x / float(n)
	var h: float = size.y * 0.78
	for i: int in n:
		var hinge: Node3D = Node3D.new()
		hinge.name = "Hinge%d" % i
		var from_left: bool = i == 0
		hinge.position = Vector3(-size.x * 0.5 if from_left else size.x * 0.5, 0, 0)
		_visual.add_child(hinge)
		_hinges.append(hinge)
		var dir: float = 1.0 if from_left else -1.0
		for ry: float in [0.35, h * 0.5 + 0.05, h - 0.15]:
			_block(hinge, Vector3(0.05 * dir, ry - 0.07, -0.06), Vector3((lw - 0.05) * dir, ry + 0.07, 0.06), "planks")
		_block(hinge, Vector3(0.05 * dir, 0.2, -0.07), Vector3(0.17 * dir, h, 0.07), "planks")
		_block(hinge, Vector3((lw - 0.17) * dir, 0.2, -0.07), Vector3((lw - 0.05) * dir, h, 0.07), "planks")
		var brace: MeshInstance3D = _block(hinge, Vector3.ZERO, Vector3(lw * 1.12, 0.12, 0.05), "planks")
		brace.position = Vector3(lw * 0.5 * dir, h * 0.5, 0.0)
		brace.rotation.z = atan2(h - 0.5, lw) * dir
		for hy: float in [0.4, h - 0.3]:
			_block(hinge, Vector3(0.0, hy - 0.03, -0.08), Vector3(0.45 * dir, hy + 0.03, -0.07), "iron")
	if n == 2:
		var chain: MeshInstance3D = _block(_hinges[0], Vector3(lw - 0.35, h * 0.5 - 0.02, -0.1), Vector3(lw + 0.35, h * 0.5 + 0.03, -0.08), "iron")
		chain.name = "Chain"
		_block(_hinges[0], Vector3(lw - 0.06, h * 0.5 - 0.2, -0.13), Vector3(lw + 0.06, h * 0.5 - 0.05, -0.09), "brass")


func _block(parent: Node3D, a: Vector3, b: Vector3, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_box()
	mi.scale = (b - a).abs().max(Vector3(0.001, 0.001, 0.001))
	mi.position = (a + b) * 0.5
	mi.material_override = Mats.get_mat(key)
	mi.set_meta("keep", true)
	parent.add_child(mi)
	return mi


func _open_visual() -> void:
	_body.collision_layer = 0
	area.collision_layer = 0
	AudioDirector.play_3d("door_creak" if AudioDirector.has_sound("door_creak") else "door_open", global_position + Vector3(0, 1.4, 0), 0.0)
	for l: Label3D in _cost_labels:
		if is_instance_valid(l):
			l.hide()
	var secs: float = float(GLData.table("world")["door"]["open_seconds"])
	var sn: Node = get_node_or_null(swing_node) if not swing_node.is_empty() else null
	if sn != null:
		if "held_open" in sn:
			sn.set("held_open", true)
		if sn.has_method("unbar"):
			sn.call("unbar")
		var tw0: Tween = create_tween()
		tw0.tween_interval(0.45)
		tw0.tween_callback(func() -> void: sn.call("open", swing_deg, secs))
		return
	var chain: Node = _visual.find_child("Chain", true, false) if _visual != null else null
	if chain != null:
		chain.get_parent().remove_child(chain)
		chain.free()
	for i: int in _hinges.size():
		var dir: float = 1.0 if i == 0 else -1.0
		var tw: Tween = create_tween()
		tw.tween_property(_hinges[i], "rotation:y", deg_to_rad(-swing_deg * dir * swing_out), secs * 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
