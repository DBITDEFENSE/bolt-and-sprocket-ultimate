extends SceneTree
## T-271: what stands where on a map, from its scene file (nothing's _ready runs): the zone volumes, the player
## spawns, and every scripted thing (machines, doors, wall buys, spawns, perk spots) with its place. The first look
## before a data row (a locker, a horse, a ladder, a set piece's route) is put on a map nobody can see.
##
##   godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/map_site_survey.gd
##       -- --maps=map01[,map02] [--box=x0,z0,x1,z1] [--names=Tower,Deck]
##
## --box: only things inside this floor rectangle. --names: also list every node whose name contains one of these
## (meshes and colliders too: where a tower, a deck or a gate was built), with the box of its collider or mesh.

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}


static func gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != null:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


static func v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func _initialize() -> void:
	var maps: Array = MAPS.keys()
	var box: PackedStringArray = []
	var names: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.substr(7).split(",", false))
		elif a.begins_with("--box="):
			box = a.substr(6).split(",", false)
		elif a.begins_with("--names="):
			names = a.substr(8).split(",", false)
	for key: String in maps:
		if not MAPS.has(key):
			continue
		var map: Node = (load(MAPS[key]) as PackedScene).instantiate()
		print("[site] ===== %s (%s) start_zone %s" % [key, str(map.get("map_id")), str(map.get("start_zone"))])
		for n: Node in map.find_children("*", "Node3D", true, false):
			var p: Vector3 = gxf(n).origin
			if box.size() == 4 and (p.x < float(box[0]) or p.x > float(box[2]) or p.z < float(box[1]) or p.z > float(box[3])):
				continue
			var s: Script = n.get_script() as Script
			var sname: String = s.resource_path.get_file().get_basename() if s != null else ""
			if sname == "zone_volume":
				var sz: Vector3 = n.get("size")
				print("[site] zone %-16s x %.1f..%.1f  z %.1f..%.1f  y %.1f..%.1f%s" % [str(n.get("zone_id")), p.x - sz.x * 0.5, p.x + sz.x * 0.5, p.z - sz.z * 0.5, p.z + sz.z * 0.5, p.y - 0.5, p.y + sz.y, "  roam" if bool(n.get("roam")) else ""])
			elif sname != "" and not sname in ["flicker_light", "lamp_glow", "blink_light", "drip_point", "baked_multimesh", "surface_text", "paper_decor", "lore_plaque", "lamp_sway"]:
				var extra: String = ""
				for prop: String in ["zone_id", "weapon_id", "perk_id", "cost", "target_zone", "spot_index", "min_round"]:
					var val: Variant = n.get(prop)
					if val != null and str(val) != "" and str(val) != "0":
						extra += " %s=%s" % [prop, str(val)]
				print("[site] %-22s %-28s %s yaw %.0f%s" % [sname, n.name, v(p), rad_to_deg(gxf(n).basis.get_euler().y), extra])
			else:
				for want: String in names:
					if String(n.name).containsn(want):
						var bx: String = ""
						if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
							var ab: AABB = gxf(n) * (n as MeshInstance3D).mesh.get_aabb()
							bx = " mesh %s .. %s" % [v(ab.position), v(ab.end)]
						elif n is CollisionShape3D and (n as CollisionShape3D).shape is BoxShape3D:
							var h: Vector3 = ((n as CollisionShape3D).shape as BoxShape3D).size * 0.5
							var ab2: AABB = gxf(n) * AABB(-h, h * 2.0)
							bx = " box %s .. %s" % [v(ab2.position), v(ab2.end)]
						print("[site] node %-40s %s %s%s" % [str(map.get_path_to(n)).right(40), n.get_class(), v(p), bx])
						break
		map.free()
	quit(0)
