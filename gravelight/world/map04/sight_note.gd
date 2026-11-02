class_name SightNote
extends Node3D
## A minimap note the first time the local player sees something (UPDATE 10 Act I, DECISIONS T-155): Jette's logbook
## side egg puts one on each glider model and on her desk hatch when they come into view (within `range_m`, inside
## the view cone `cos_max`, nothing solid between), so the egg is findable without a guide. Personal: each peer
## notes what its own player saw. Notes go to MapState (kind "note"); one per target, never repeated.

@export var targets: Array = []   # NodePaths (untyped: the generator sets it from a plain Array)
@export var labels: PackedStringArray = PackedStringArray()
@export var range_m: float = 16.0
@export var cos_max: float = 0.8

var seen: Dictionary = {}       # target index -> marker id
var _t: float = 0.0


## Pure: is `p` in view of an eye at `eye` looking along `fwd` (unit), within `range_m` and the cone?
static func in_view(eye: Vector3, fwd: Vector3, p: Vector3, range_m: float, cos_max: float) -> bool:
	var d: Vector3 = p - eye
	var dist: float = d.length()
	if dist > range_m or dist < 0.05:
		return dist <= 0.05
	return fwd.dot(d / dist) >= cos_max


func _ready() -> void:
	add_to_group(&"sight_notes")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or seen.size() >= targets.size():
		return
	_t = 0.4
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z
	for i: int in targets.size():
		if seen.has(i):
			continue
		var n: Node3D = get_node_or_null(NodePath(targets[i])) as Node3D
		if n == null or not n.is_visible_in_tree():
			continue
		var p: Vector3 = n.global_position + Vector3.UP * 0.3
		if not in_view(eye, fwd, p, range_m, cos_max):
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, p, 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		note(i)


## Puts target `i`'s note on the map (also the smoke's way in).
func note(i: int) -> int:
	if seen.has(i) or i < 0 or i >= targets.size():
		return int(seen.get(i, -1))
	var n: Node3D = get_node_or_null(NodePath(targets[i])) as Node3D
	var id: int = -1
	var ms: MapState = MapState.current()
	if ms != null and n != null:
		id = ms.add_marker({"pos": n.global_position, "kind": "note", "label": labels[i] if i < labels.size() else "Something here",
			"color": Color(0.78, 0.7, 0.92), "owner": 0, "target": "me"})
	seen[i] = id
	print("[sight] noted %s" % (labels[i] if i < labels.size() else str(i)))
	return id
