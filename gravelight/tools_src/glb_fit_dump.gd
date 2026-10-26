extends SceneTree
## Fit helper for the downloaded guns (T-089): builds every GLB-backed weapon through WeaponGLB and prints, in rig
## space (metres, barrel -Z, origin at the grip), its bounds, every part group's bounds and pivot, the markers it
## ended up with (Muzzle / SightPoint / FrontSight / LeftHand / grip_r), and the top profile (max y per cm of z,
## with the part), so model_fit.json can be written from the geometry. Headless:
##   godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/glb_fit_dump.gd -- [--only=a,b] [--profile]


func _init() -> void:
	var only: PackedStringArray = []
	var profile: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = PackedStringArray(a.substr(7).split(","))
		elif a == "--profile":
			profile = true
	var ids: Array = (WeaponGLB.models().get("weapons", {}) as Dictionary).keys()
	ids.sort()
	for id: String in ids:
		if WeaponGLB.glb_path(StringName(id)) == "":
			continue
		if not only.is_empty() and not only.has(id):
			continue
		var m: Node3D = WeaponModels.build(StringName(id))
		var bb: AABB = WeaponModels.model_bounds(m)
		print("== %s  bbox %s .. %s  (len %.3f)  reload=%s length=%.3f lh_axis=%s grip_r=%s" % [id, _v(bb.position), _v(bb.end), bb.size.z,
			m.get_meta("reload", ""), float(m.get_meta("length", 0.0)), m.get_meta("lh_axis", ""), _v((m.get_meta("grip_r") as Transform3D).origin)])
		for c: Node in m.get_children():
			if c is Node3D:
				var n: Node3D = c as Node3D
				var pb: AABB = WeaponKitModels._bounds(n)
				var kind: String = "group" if n.get_child_count() > 0 else ("marker" if not (n is MeshInstance3D) else "mesh")
				var extra: String = ""
				if pb.size != Vector3.ZERO:
					extra = "  bounds %s .. %s" % [_v(n.transform * pb.position), _v(n.transform * pb.end)]
				print("   %-12s %-6s at %s%s" % [n.name, kind, _v(n.position), extra])
				for g: Node in n.get_children():
					if g is Marker3D or (g is Node3D and not (g is MeshInstance3D) and g.get_child_count() == 0):
						print("      %-10s at %s (root %s)" % [g.name, _v((g as Node3D).position), _v(n.transform * (g as Node3D).position)])
		if profile:
			var rows: Array = WeaponGLB.top_profile(m)
			var line: String = ""
			for r: Array in rows:
				line += "%+.2f:%.3f%s " % [float(r[0]), float(r[1]), ("(" + str(r[2]).substr(0, 3) + ")") if str(r[2]) != "" else ""]
			print("   top: " + line)
		m.free()
	quit(0)


static func _v(p: Vector3) -> String:
	return "[%.3f, %.3f, %.3f]" % [p.x, p.y, p.z]
