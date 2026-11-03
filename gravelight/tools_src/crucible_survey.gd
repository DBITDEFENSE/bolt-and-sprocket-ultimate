extends Node
## The Crucible rooms' survey (T-175): for every map, a top-down ASCII plan of the floor round the Crucible in the
## machine's own frame (local -Z is its front: the top of the page), from the scene file alone (no _ready runs):
##   '.' baked navmesh   '#' a collider box between knee and head height   '+' both   'C' the machine ('c' navmesh under it)   'U' its use point
##   'p' a crucible_rooms.json piece's footprint off the navmesh, '!' one on it (the dresser's props, when the file has the map)
## plus the zone, the lights within 12 m (type, shadow, energy, local position), the zone's shadowed lights and the
## ceiling over the approach.
## Headless:  godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/crucible_survey.tscn [-- --map=map00] [--half=7] [--boxes]

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const ROOM_SCRIPT: String = "res://gravelight/world/crucible_room.gd"


static func gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


var _boxes: bool = false
var _debug_at: Vector2 = Vector2.INF


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: String = ""
	var half: float = 7.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			only = a.substr(6)
		elif a.begins_with("--debug="):
			var dv: PackedStringArray = a.substr(8).split(",")
			_debug_at = Vector2(float(dv[0]), float(dv[1]))
		elif a == "--boxes":
			_boxes = true
		elif a.begins_with("--half="):
			half = float(a.substr(7))
	for key: String in MAPS:
		if only != "" and key != only:
			continue
		survey(key, MAPS[key], half)
	get_tree().quit()


func survey(key: String, path: String, half: float) -> void:
	var map: Node = (load(path) as PackedScene).instantiate()
	var cru: Node3D = map.find_child("Crucible", true, false) as Node3D
	if cru == null:
		print("== %s: no Crucible" % key)
		map.free()
		return
	var cx: Transform3D = gxf(cru)
	var inv: Transform3D = cx.affine_inverse()
	var fy: float = cx.origin.y
	print("== %s Crucible at %s front(world) %s" % [key, cx.origin, -cx.basis.z])
	var zone_id: String = ""
	for z: Node in map.find_children("*", "", true, false):
		if z.get_script() != null and str((z.get_script() as Script).resource_path).ends_with("zone_volume.gd"):
			var zp: Vector3 = gxf(z).origin
			var sz: Vector3 = z.get("size")
			var l: Vector3 = cx.origin + Vector3.UP * 0.5 - zp
			if absf(l.x) <= sz.x * 0.5 and absf(l.z) <= sz.z * 0.5 and l.y >= -0.5 and l.y <= sz.y:
				print("   zone %s box %s size %s" % [z.get("zone_id"), zp, sz])
				if zone_id == "":
					zone_id = str(z.get("zone_id"))
	var polys: Array = []
	for r: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var rx: Transform3D = gxf(r)
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var idx: PackedInt32Array = nm.get_polygon(i)
			var pts: PackedVector2Array = []
			var ys: float = 0.0
			for j: int in idx:
				var v: Vector3 = rx * verts[j]
				pts.append(Vector2(v.x, v.z))
				ys += v.y
			ys /= maxf(1.0, idx.size())
			if absf(ys - fy) < 1.2:
				polys.append([pts, ys])
				if _debug_at != Vector2.INF:
					var dp: Vector3 = cx * Vector3(_debug_at.x, 0.0, _debug_at.y)
					if Geometry2D.is_point_in_polygon(Vector2(dp.x, dp.z), pts):
						var vys: PackedFloat32Array = []
						for j2: int in idx:
							vys.append((rx * verts[j2]).y)
						print("   debug: %s poly %d holds local %s, vertex y %s" % [r.name, i, _debug_at, vys])
	var boxes: Array = []
	for cs: Node in map.find_children("*", "CollisionShape3D", true, false):
		var sh: Shape3D = (cs as CollisionShape3D).shape
		if sh is BoxShape3D:
			var ab: AABB = gxf(cs) * AABB(-(sh as BoxShape3D).size * 0.5, (sh as BoxShape3D).size)
			if ab.end.y > fy + 0.35 and ab.position.y < fy + 1.6:
				boxes.append(ab)
	var pieces: Array = []
	if ResourceLoader.exists(ROOM_SCRIPT):
		pieces = (load(ROOM_SCRIPT) as GDScript).call("footprints_local", key)
	var step: float = 0.25
	var lz: float = -half - 3.0
	print("   plan: x %.1f..%.1f across (local +X right), the top row is the front (-Z); 0.25 m cells" % [-half, half])
	while lz <= 3.0:
		var row: String = ""
		var lx: float = -half
		while lx <= half + 0.001:
			var wp: Vector3 = cx * Vector3(lx, 0.0, lz)
			var nav: bool = false
			for pp: Array in polys:
				if Geometry2D.is_point_in_polygon(Vector2(wp.x, wp.z), pp[0]):
					nav = true
					break
			var col: bool = false
			for ab2: AABB in boxes:
				if wp.x >= ab2.position.x and wp.x <= ab2.end.x and wp.z >= ab2.position.z and wp.z <= ab2.end.z:
					col = true
					break
			var ch: String = "+" if nav and col else ("." if nav else ("#" if col else " "))
			if absf(lx) <= 1.0 and lz >= -0.8 and lz <= 0.8:
				ch = "c" if nav else "C"
			if absf(lx) < 0.13 and absf(lz + 0.95) < 0.13:
				ch = "U"
			for fp: Rect2 in pieces:
				if fp.has_point(Vector2(lx, lz)) and not ch in ["C", "c", "U"]:
					ch = "!" if nav else "p"
			row += ch
			lx += step
		print("   %+6.2f |%s|" % [lz, row])
		lz += step
	if _boxes:
		for cs3: Node in map.find_children("*", "CollisionShape3D", true, false):
			var sh3: Shape3D = (cs3 as CollisionShape3D).shape
			if not (sh3 is BoxShape3D):
				continue
			var lab: AABB = inv * (gxf(cs3) * AABB(-(sh3 as BoxShape3D).size * 0.5, (sh3 as BoxShape3D).size))
			if lab.position.x < half and lab.end.x > -half and lab.position.z < 4.0 and lab.end.z > -half - 3.0 and lab.position.y < 4.5 and lab.end.y > -0.5:
				print("   box %-28s x %6.2f..%6.2f  y %5.2f..%5.2f  z %6.2f..%6.2f" % [str(cs3.get_parent().name).left(28), lab.position.x, lab.end.x, lab.position.y, lab.end.y, lab.position.z, lab.end.z])
	var up: Vector3 = cx * Vector3(0, 0, -2.0)
	var ceil_y: float = INF
	for cs2: Node in map.find_children("*", "CollisionShape3D", true, false):
		var sh2: Shape3D = (cs2 as CollisionShape3D).shape
		if sh2 is BoxShape3D:
			var ab3: AABB = gxf(cs2) * AABB(-(sh2 as BoxShape3D).size * 0.5, (sh2 as BoxShape3D).size)
			if up.x >= ab3.position.x and up.x <= ab3.end.x and up.z >= ab3.position.z and up.z <= ab3.end.z and ab3.position.y > fy + 2.0:
				ceil_y = minf(ceil_y, ab3.position.y)
	print("   ceiling over the approach (2 m out): %.2f m above the floor" % (ceil_y - fy))
	var n_sh: int = 0
	var zone_sh: int = 0
	for l2: Node in map.find_children("*", "Light3D", true, false):
		if l2 is DirectionalLight3D:
			continue
		var li: Light3D = l2 as Light3D
		if li.shadow_enabled and str(li.get_meta("zone", "")) == zone_id:
			zone_sh += 1
		var lp: Vector3 = gxf(l2).origin
		if lp.distance_to(cx.origin) < 12.0:
			var loc: Vector3 = inv * lp
			if li.shadow_enabled:
				n_sh += 1
			print("   light %s %s shadow=%s e=%.2f col=%s local=(%.1f,%.1f,%.1f) zone=%s vis=%s" % [li.name, li.get_class(), li.shadow_enabled, li.light_energy,
				li.light_color.to_html(false), loc.x, loc.y, loc.z, li.get_meta("zone", "-"), li.get_meta("vis_group", "-")])
	print("   shadowed lights within 12 m: %d; shadowed lights with zone meta %s in the whole scene: %d" % [n_sh, zone_id, zone_sh])
	map.free()
	if ResourceLoader.exists(ROOM_SCRIPT) and not CrucibleRoom.config_for(key).is_empty():
		var room: CrucibleRoom = CrucibleRoom.new()
		room.map_key = key
		room.data = CrucibleRoom.config_for(key)
		add_child(room)
		room.build()
		var meshes: Array = room.find_children("*", "MeshInstance3D", true, false)
		var casts: int = 0
		var tris: int = 0
		for mi: Node in meshes:
			if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casts += 1
			var m: Mesh = (mi as MeshInstance3D).mesh
			for si: int in m.get_surface_count():
				tris += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var shadowed: int = 0
		for e: Array in room.lights:
			if (e[0] as Light3D).shadow_enabled:
				shadowed += 1
		print("   ROOM %s: %d pieces, %d meshes (%d cast), %d labels, %d lights (%d shadowed), %d particle bursts, ~%d triangles" % [key,
			room.piece_boxes.size(), meshes.size(), casts, room.find_children("*", "Label3D", true, false).size(), room.lights.size(), shadowed, room.fx.size(), tris])
		room.free()
