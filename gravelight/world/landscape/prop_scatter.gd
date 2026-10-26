class_name PropScatter
extends Node3D
## Library props laid out by a map generator (UPDATE_05 section 5, DECISIONS T-093). The generator records where each
## CC0 prop goes (`items`: [key, Transform3D, casts_shadow]) and this node builds them at load time as one MultiMesh
## per (prop, mesh): thirty chairs are one draw call per chair mesh, and the .tscn holds only the placements, not
## copies of the GLB meshes. Visual only (UPDATE_05 section 0.4): PropLibrary strips any collision the files carry,
## the generator's invisible colliders stay where they were, and nothing here is under the navigation region.
##
## The transform places the prop's pivot (PropLibrary: footprint centre on the floor for "base") and may scale it
## per axis to fit the collider it dresses.

## [[key: String, xf: Transform3D, shadow: bool], ...]
@export var items: Array = []
@export var build_on_ready: bool = true

var built: bool = false


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> void:
	if built:
		return
	built = true
	var by_key: Dictionary = {}
	for it: Array in items:
		(by_key.get_or_add(str(it[0]), []) as Array).append(it)
	for key: String in by_key.keys():
		var proto: Node3D = PropLibrary.instance(key)
		if proto == null:
			continue
		var list: Array = by_key[key]
		for shadow: bool in [true, false]:
			var xfs: Array[Transform3D] = []
			for it2: Array in list:
				if bool(it2[2] if it2.size() > 2 else true) == shadow:
					xfs.append(it2[1])
			if xfs.is_empty():
				continue
			for mi: MeshInstance3D in PropLibrary.meshes(proto):
				if mi.mesh == null:
					continue
				var local: Transform3D = PropLibrary._xform(mi, proto)
				var mm: MultiMesh = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mi.mesh
				mm.instance_count = xfs.size()
				for i: int in xfs.size():
					mm.set_instance_transform(i, xfs[i] * local)
				var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
				mmi.name = "%s_%s" % [key, "s" if shadow else "n"]
				mmi.multimesh = mm
				if mi.material_override != null:
					mmi.material_override = mi.material_override
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.set_meta("prop_key", key)
				add_child(mmi)
		proto.free()


## How many props of `key` are placed (tests).
func count(key: String) -> int:
	var n: int = 0
	for it: Array in items:
		if str(it[0]) == key:
			n += 1
	return n


## The transform that puts a library prop (pivot "base") at `pos` turned `yaw_deg`, scaled per axis by `sc`.
static func place(pos: Vector3, yaw_deg: float, sc: Vector3 = Vector3.ONE, euler_extra_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(euler_extra_deg.x), deg_to_rad(yaw_deg + euler_extra_deg.y), deg_to_rad(euler_extra_deg.z)))
	return Transform3D(b * Basis.from_scale(sc), pos)
