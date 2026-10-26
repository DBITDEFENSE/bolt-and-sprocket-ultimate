class_name SightClearance
extends Node
## Dev check (and the core of test_sight_clearance): for every weapon built through WeaponGLB (base and Crucible),
## lists the mesh parts whose top rises above the sight line (SightPoint -> FrontSight, continued to the muzzle)
## near the bore, which is what blocks the ADS picture (e.g. the Garand's en-bloc clip sitting proud of the
## receiver). The sights' own geometry (rear ears, front post and hood) is left out; scoped models are clear by
## design (the eye looks through the tube).
## Headless: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/sight_clearance.tscn [-- --only=a,b] [--tol=0.002]
## Exit code: the number of models with a part above the sight line.

const TOL: float = 0.002         # metres a part may rise above the line before it counts
const HALF_W: float = 0.012      # metres either side of the bore line that the eye looks through
const SIGHT_SKIP: float = 0.025  # metres around each sight marker left out

var _only: PackedStringArray = []
var _tol: float = TOL


## The parts of a built model that rise above its sight line: ["Mag/Clip +7.0 mm", ...]; [] when clear,
## scoped, or without sight markers. `m` must be inside the tree.
static func blocked(m: Node3D, tol: float = TOL, half_w: float = HALF_W, sight_skip: float = SIGHT_SKIP) -> Array:
	if m.has_meta("scope"):
		return []
	var sp: Node3D = m.find_child("SightPoint", true, false) as Node3D
	var fs: Node3D = m.find_child("FrontSight", true, false) as Node3D
	if sp == null or fs == null:
		return []
	var a: Vector3 = m.to_local(sp.global_position)
	var b: Vector3 = m.to_local(fs.global_position)
	var hits: Array = []
	for node: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var xf: Transform3D = m.global_transform.affine_inverse() * mi.global_transform
		var worst: float = -INF
		for s: int in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				if p.z > a.z + 0.01 or absf(p.x - a.x) > half_w:
					continue
				if absf(p.z - a.z) < sight_skip or absf(p.z - b.z) < sight_skip:
					continue
				var t: float = 0.0 if is_equal_approx(a.z, b.z) else (p.z - a.z) / (b.z - a.z)
				worst = maxf(worst, p.y - (a.y + (b.y - a.y) * maxf(t, 0.0)))
		if worst > tol:
			hits.append("%s +%.1f mm" % [String(m.get_path_to(mi)), worst * 1000.0])
	return hits


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
		elif arg.begins_with("--tol="):
			_tol = float(arg.substr(6))
	_run.call_deferred()


func _run() -> void:
	var bad: int = 0
	for id: Variant in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		var wid: String = str(id)
		if (not _only.is_empty() and not _only.has(wid)) or not WeaponGLB.wants(StringName(wid)):
			continue
		for up: bool in [false, true]:
			var m: Node3D = WeaponModels.build(StringName(wid), up)
			add_child(m)
			var hits: Array = blocked(m, _tol)
			var tag: String = "up" if up else "  "
			if m.has_meta("scope"):
				print("%-14s %s  scoped (the eye looks through the tube)" % [wid, tag])
			elif hits.is_empty():
				print("%-14s %s  clear" % [wid, tag])
			else:
				bad += 1
				print("%-14s %s  ABOVE THE SIGHT LINE: %s" % [wid, tag, ", ".join(hits)])
			m.free()
	print("[sight_clearance] %d model(s) with parts above the sight line" % bad)
	get_tree().quit(bad)
