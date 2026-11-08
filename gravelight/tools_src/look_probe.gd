extends Node
## UPDATE 12 (T-214): what is under a pixel of a look capture. Headless: loads a map, places the capture camera
## (the u12_look / u12_post "maps" cameras: eye `pos`, `yaw`, `pitch`, vertical fov 64 on a 1280x536 frame) and, for
## each pixel asked, prints the meshes the ray passes through (nearest first: node path, mesh, every surface
## material's class, colour, texture, emission, shading, transparency) and the collider it hits. Nothing is changed.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/look_probe.tscn -- \
##     --map=res://...tscn --pos=x,y,z --yaw=deg --pitch=deg [--fov=64] [--w=1280 --h=536] --px=x,y[;x,y...] [--n=6]
##   (--cam=<set>:<name> takes pos / yaw / pitch / fov / map from data/gravelight/capture_cams.json)
## or --find=<substring> to list every node whose path holds it, with its materials.

var _args: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	if _args.has("cam"):
		var parts: PackedStringArray = str(_args["cam"]).split(":")
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/capture_cams.json"))
		for c: Dictionary in d["sets"][parts[0]]["cams"]:
			if str(c.get("name", "")) == parts[1]:
				_args["map"] = c["map"]
				_args["pos"] = ",".join(PackedStringArray((c.get("pos", [0, 0, 0]) as Array).map(func(v: Variant) -> String: return str(v))))
				_args["yaw"] = str(c.get("yaw", 0.0))
				_args["pitch"] = str(c.get("pitch", -6.0))
				_args["fov"] = str(c.get("fov", 64.0))
				if bool(c.get("player", false)):
					_args["player"] = "%s,%s,%s" % [c.get("back", 1.5), c.get("up", 0.5), c.get("turn", 0.0)]
	if _args.has("c47"):
		# a GRAVELIGHT ONE acceptance view (shots_c47.gd, T-211): eye -> target in the wreck frame or the map's
		var sc: Node = (load("res://gravelight/tools_src/shots_c47.gd") as GDScript).new()
		for v: Array in sc.call("_views"):
			if str(v[0]) == str(_args["c47"]):
				var gen: GDScript = load("res://gravelight/tools_src/gen_map00.gd")
				var xf: Transform3D = gen.call("wreck_xf") if str(v[3]) == "wreck" else Transform3D.IDENTITY
				var e3: Vector3 = xf * Vector3(v[1])
				var d3: Vector3 = (xf * Vector3(v[2]) - e3).normalized()
				_args["map"] = "res://gravelight/maps/map00_crossroads/map00.tscn"
				_args["pos"] = "%f,%f,%f" % [e3.x, e3.y, e3.z]
				_args["yaw"] = str(rad_to_deg(atan2(-d3.x, -d3.z)))
				_args["pitch"] = str(rad_to_deg(asin(d3.y)))
				_args["fov"] = str(v[4])
				_args["h"] = "535"
		sc.free()
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	GameState.bot_count = 0
	var map: Node = (load(str(_args["map"])) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(map)
	await get_tree().create_timer(4.0).timeout
	RoundManager.stop()
	if _args.has("normals"):
		# every mesh whose path holds the text: how many faces' vertex normals point against their winding
		for n2: Node in map.find_children("*", "MeshInstance3D", true, false):
			if not String(map.get_path_to(n2)).to_lower().contains(str(_args["normals"]).to_lower()) or (n2 as MeshInstance3D).mesh == null:
				continue
			var mesh: Mesh = (n2 as MeshInstance3D).mesh
			for si: int in mesh.get_surface_count():
				var arr: Array = mesh.surface_get_arrays(si)
				var vx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if nr.is_empty():
					continue
				var tri: int = ix.size() / 3 if ix.size() > 0 else vx.size() / 3
				var bad: int = 0
				for f: int in tri:
					var a: int = ix[f * 3] if ix.size() > 0 else f * 3
					var b2: int = ix[f * 3 + 1] if ix.size() > 0 else f * 3 + 1
					var c2: int = ix[f * 3 + 2] if ix.size() > 0 else f * 3 + 2
					var wn: Vector3 = (vx[c2] - vx[a]).cross(vx[b2] - vx[a])   # Godot's front face is clockwise
					if wn.dot(nr[a] + nr[b2] + nr[c2]) < 0.0:
						bad += 1
				print("[probe] %s surface %d: %d of %d faces have normals against their winding" % [map.get_path_to(n2), si, bad, tri])
		get_tree().quit()
		return
	if _args.has("find"):
		for n: Node in map.find_children("*", "", true, false):
			var path_l: String = String(map.get_path_to(n)).to_lower()
			if Array(str(_args["find"]).to_lower().split(",")).any(func(w: String) -> bool: return path_l.contains(w)):
				print("[probe] %s %s %s" % [map.get_path_to(n), n.get_class(), _mats(n)])
		get_tree().quit()
		return
	var pv: PackedFloat32Array = _vec(str(_args.get("pos", "0,0,0")))
	var eye: Vector3 = Vector3(pv[0], pv[1], pv[2])
	var yaw: float = deg_to_rad(float(_args.get("yaw", "0")))
	var pitch: float = deg_to_rad(float(_args.get("pitch", "-6")))
	if _args.has("player") and map is MapRoot and (map as MapRoot).player != null:
		# capture.gd's "player" cams: the map's own start view, pulled back and up
		var pb: PackedFloat32Array = _vec(str(_args["player"]))
		var pc: Transform3D = (map as MapRoot).player.camera.global_transform
		var fw: Vector3 = -pc.basis.z
		fw.y = 0.0
		fw = fw.normalized() if fw.length() > 0.01 else Vector3.FORWARD
		yaw = atan2(-fw.x, -fw.z) + deg_to_rad(pb[2])
		fw = Vector3(-sin(yaw), 0.0, -cos(yaw))
		eye = pc.origin - fw * pb[0] + Vector3.UP * pb[1]
		print("[probe] player cam eye %s yaw %.1f" % [eye, rad_to_deg(yaw)])
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var w: float = float(_args.get("w", "1280"))
	var h: float = float(_args.get("h", "536"))
	var t: float = tan(deg_to_rad(float(_args.get("fov", "64"))) * 0.5)
	var meshes: Array = map.find_children("*", "GeometryInstance3D", true, false)
	if _args.has("emissive"):
		# every glowing material in the frame: where it projects (pixel) and how bright it is
		for g0: GeometryInstance3D in meshes:
			if not g0.is_visible_in_tree():
				continue
			for m0: Material in LookMaterials.materials_of(g0):
				var glow: String = ""
				if m0 is BaseMaterial3D and (m0 as BaseMaterial3D).emission_enabled:
					glow = "emis %s x%.2f" % [(m0 as BaseMaterial3D).emission.to_html(false), (m0 as BaseMaterial3D).emission_energy_multiplier]
				elif m0 is BaseMaterial3D and (m0 as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					glow = "unshaded %s" % (m0 as BaseMaterial3D).albedo_color.to_html(false)
				elif m0 is ShaderMaterial:
					glow = _mat(m0)
				if glow == "":
					continue
				var c0: Vector3 = (g0.global_transform * g0.get_aabb()).get_center()
				var lv: Vector3 = basis.inverse() * (c0 - eye)
				if lv.z >= -0.1:
					continue
				var t0: float = tan(deg_to_rad(float(_args.get("fov", "64"))) * 0.5)
				var px0: float = 640.0 + lv.x / -lv.z / t0 * 268.0
				var py0: float = 268.0 - lv.y / -lv.z / t0 * 268.0
				if px0 < 0.0 or px0 > 1280.0 or py0 < 0.0 or py0 > 536.0:
					continue
				print("[probe] glow at px (%d, %d) %.1f m %s: %s" % [px0, py0, eye.distance_to(c0), map.get_path_to(g0), glow])
		for l0: Node in map.find_children("*", "Light3D", true, false):
			var lt0: Light3D = l0
			if lt0 is DirectionalLight3D or not lt0.is_visible_in_tree():
				continue
			var lv2: Vector3 = basis.inverse() * (lt0.global_position - eye)
			if lv2.z >= -0.1:
				continue
			var t2: float = tan(deg_to_rad(float(_args.get("fov", "64"))) * 0.5)
			var lx: float = 640.0 + lv2.x / -lv2.z / t2 * 268.0
			var ly: float = 268.0 - lv2.y / -lv2.z / t2 * 268.0
			if lx >= -200.0 and lx <= 1480.0 and ly >= -600.0 and ly <= 536.0:
				print("[probe] light at px (%d, %d) %.1f m %s: %s" % [lx, ly, eye.distance_to(lt0.global_position), map.get_path_to(lt0), _mats(lt0)])
		get_tree().quit()
		return
	var space: PhysicsDirectSpaceState3D = (map as Node3D).get_world_3d().direct_space_state
	for spec: String in str(_args.get("px", "640,268")).split(";"):
		var p: PackedFloat32Array = _vec(spec)
		var dl: Vector3 = Vector3((p[0] - w * 0.5) / (h * 0.5) * t, -(p[1] - h * 0.5) / (h * 0.5) * t, -1.0).normalized()
		var dir: Vector3 = basis * dl
		print("[probe] pixel %s dir %s" % [spec, dir])
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + dir * 400.0)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			print("[probe]   collider %s at %s (%.1f m)" % [map.get_path_to(hit["collider"]) if map.is_ancestor_of(hit["collider"]) else hit["collider"], hit["position"], eye.distance_to(hit["position"])])
		var hits: Array = []
		for g: GeometryInstance3D in meshes:
			if not g.is_visible_in_tree():
				continue
			var ab: AABB = g.global_transform * g.get_aabb()
			var e: float = _ray_aabb(eye, dir, ab)
			if e < 0.0:
				continue
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				# the exact triangle (the batches are one mesh over a whole block: their AABB says nothing)
				var mi: MeshInstance3D = g
				var tm: TriangleMesh = mi.mesh.generate_triangle_mesh()
				if tm == null:
					continue
				var inv: Transform3D = mi.global_transform.affine_inverse()
				var r: Dictionary = tm.intersect_ray(inv * eye, (inv.basis * dir).normalized())
				if r.is_empty():
					continue
				var wp: Vector3 = mi.global_transform * Vector3(r["position"])
				var fi: int = int(r.get("face_index", -1))
				hits.append([eye.distance_to(wp), g, _surface_of(mi.mesh, fi), wp, _face_info(mi, fi, Vector3(r.get("normal", Vector3.ZERO)))])
			else:
				hits.append([e, g, -1, Vector3.ZERO, ""])
		hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i: int in mini(int(_args.get("n", "6")), hits.size()):
			var g2: GeometryInstance3D = hits[i][1]
			var sm: String = ""
			if int(hits[i][2]) >= 0 and g2 is MeshInstance3D:
				var mi2: MeshInstance3D = g2
				var mm: Material = mi2.get_active_material(int(hits[i][2]))
				sm = " SURFACE %d: %s" % [hits[i][2], _mat(mm) if mm != null else "none"]
			print("[probe]   %.1f m %s (%s) at %s%s%s" % [hits[i][0], map.get_path_to(g2), g2.get_class(), Vector3(hits[i][3]).snapped(Vector3.ONE * 0.01), sm if sm != "" else " " + _mats(g2), hits[i][4]])
	get_tree().quit()


## The face's geometric normal (from its winding) against its vertices' normals and colours (world space; a face
## whose vertex normals point away from its winding is lit from the wrong side).
func _face_info(mi: MeshInstance3D, face: int, geo_n: Vector3) -> String:
	if face < 0 or not _args.has("faces"):
		return ""
	var acc: int = 0
	for s: int in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vn: int = idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if face < acc + vn:
			var f: int = face - acc
			var ids: Array = [idx[f * 3], idx[f * 3 + 1], idx[f * 3 + 2]] if idx.size() > 0 else [f * 3, f * 3 + 1, f * 3 + 2]
			var nn: Vector3 = Vector3.ZERO
			var col: Color = Color(0, 0, 0, 0)
			for k: int in ids:
				if arr[Mesh.ARRAY_NORMAL] != null:
					nn += (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)[k]
				if arr[Mesh.ARRAY_COLOR] != null:
					col += (arr[Mesh.ARRAY_COLOR] as PackedColorArray)[k] / 3.0
			var b: Basis = mi.global_transform.basis
			return " | face n %s vertex n %s col %s" % [(b * geo_n).normalized().snapped(Vector3.ONE * 0.01), (b * nn).normalized().snapped(Vector3.ONE * 0.01), col]
		acc += vn
	return ""


## Which surface of `mesh` holds triangle `face` (the triangle mesh numbers the surfaces' faces one after another).
func _surface_of(mesh: Mesh, face: int) -> int:
	if face < 0:
		return 0 if mesh.get_surface_count() == 1 else -1
	var acc: int = 0
	for s: int in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var n: int = (idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if face < acc + n:
			return s
		acc += n
	return -1


func _vec(s: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	for v: String in s.split(","):
		out.append(float(v))
	return out


func _ray_aabb(o: Vector3, d: Vector3, ab: AABB) -> float:
	var tmin: float = -1e9
	var tmax: float = 1e9
	for k: int in 3:
		if absf(d[k]) < 1e-6:
			if o[k] < ab.position[k] or o[k] > ab.end[k]:
				return -1.0
			continue
		var t1: float = (ab.position[k] - o[k]) / d[k]
		var t2: float = (ab.end[k] - o[k]) / d[k]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return -1.0
	return maxf(tmin, 0.0)


func _mats(n: Node) -> String:
	if not (n is GeometryInstance3D):
		if n is Light3D:
			var l: Light3D = n
			return "light %s e%.2f fog%.2f" % [l.light_color.to_html(false), l.light_energy, l.light_volumetric_fog_energy]
		return ""
	var out: PackedStringArray = []
	for m: Material in LookMaterials.materials_of(n as GeometryInstance3D):
		out.append(_mat(m))
	if n is GPUParticles3D:
		var gp: GPUParticles3D = n
		if gp.draw_pass_1 != null and gp.draw_pass_1.surface_get_material(0) != null:
			out.append("pass1 " + _mat(gp.draw_pass_1.surface_get_material(0)))
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append("mesh '%s'" % (n as MeshInstance3D).mesh.resource_name)
	return " | ".join(out)


func _mat(m: Material) -> String:
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		var s: String = "Std '%s' alb %s" % [b.resource_name, b.albedo_color.to_html(false)]
		if b.albedo_texture != null:
			s += " tex %s" % (b.albedo_texture.resource_path if b.albedo_texture.resource_path != "" else b.albedo_texture.get_class())
		if b.emission_enabled:
			s += " emis %s x%.2f" % [b.emission.to_html(false), b.emission_energy_multiplier]
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			s += " UNSHADED"
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			s += " transp%d" % b.transparency
		if b.vertex_color_use_as_albedo:
			s += " vcol"
		if b.detail_enabled:
			s += " detail"
		if b.cull_mode != BaseMaterial3D.CULL_BACK:
			s += " cull%d" % b.cull_mode
		return s
	if m is ShaderMaterial:
		var sm: ShaderMaterial = m
		var s2: String = "Shader %s" % (sm.shader.resource_path.get_file() if sm.shader != null else "?")
		for k: String in ["albedo_tint", "albedo", "emission_energy", "emission_color", "emission", "albedo_tex", "grime", "lit_color", "haze", "color"]:
			var v: Variant = sm.get_shader_parameter(k)
			if v != null:
				s2 += " %s=%s" % [k, v.to_html(false) if v is Color else (v.resource_path if v is Resource else str(v))]
		return s2
	return m.get_class()
