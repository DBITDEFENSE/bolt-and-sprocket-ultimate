extends Node
## Temporary probe: lists what crosses Map 0's doorways.
const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
var _map: Node3D
var _f: int = 0

func _ready() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)

func _physics_process(_d: float) -> void:
	if not _map.is_inside_tree():
		return
	_f += 1
	if _f < 10:
		return
	var ops: Array[Dictionary] = DoorClearance.buy_door_openings(_map)
	ops.append(DoorClearance.opening("PassageArch", Vector3(20, 0, 22), 0.0, 3.0, 2.6))
	for rd in [[5.75, 1], [11.75, 2], [20.25, 3]]:
		ops.append(DoorClearance.opening("RoomDoorway%d" % rd[1], Vector3(rd[0], 3.8, 6.0), 0.0, 1.5, 2.2, _map.find_child("RoomDoor%d" % rd[1], true, false)))
	for o in ops:
		print(o["name"], " ", (o["xf"] as Transform3D).origin, " ", o["size"])
	var t0: int = Time.get_ticks_msec()
	var hits: PackedStringArray = DoorClearance.intrusions(_map, ops)
	print("took ", Time.get_ticks_msec() - t0, " ms")
	for h in hits:
		print("HIT ", h)
		var nm: String = h.split(": ")[0]
		var pth: String = h.split(": ")[1].split(" (")[0]
		for o in ops:
			if o["name"] == nm:
				_detail(pth, o)
	get_tree().quit()

func _detail(path: String, o: Dictionary) -> void:
	var mi: MeshInstance3D = _map.get_node(path) as MeshInstance3D
	for v: AABB in DoorClearance.volumes(o):
		_detail_v(path, o, v)

func _detail_v(path: String, o: Dictionary, v: AABB) -> void:
	var mi: MeshInstance3D = _map.get_node(path) as MeshInstance3D
	var inv: Transform3D = (o["xf"] as Transform3D).affine_inverse() * mi.global_transform
	var f: PackedVector3Array = mi.mesh.get_faces()
	var c: Vector3 = v.get_center()
	var h: Vector3 = v.size * 0.5
	var bb: AABB
	var any: bool = false
	var n: int = 0
	# cluster: per hitting triangle union its world AABB; print distinct clusters coarse
	var clusters: Array[AABB] = []
	for i in range(0, f.size() - 2, 3):
		if DoorClearance.tri_box(inv * f[i] - c, inv * f[i + 1] - c, inv * f[i + 2] - c, h):
			var tb: AABB = AABB(mi.global_transform * f[i], Vector3.ZERO).expand(mi.global_transform * f[i + 1]).expand(mi.global_transform * f[i + 2])
			var merged: bool = false
			for k in clusters.size():
				if clusters[k].grow(0.02).intersects(tb):
					clusters[k] = clusters[k].merge(tb)
					merged = true
					break
			if not merged:
				clusters.append(tb)
	var mn: String = mi.material_override.resource_name if mi.material_override else "?"
	if mi.material_override and mn == "":
		mn = str(mi.material_override.get_meta("key", "")) + " " + str(mi.material_override)
	for cl in clusters:
		print("   ", o["name"], " ", path, " mat=", mn, " pos=", cl.position, " end=", cl.end)
