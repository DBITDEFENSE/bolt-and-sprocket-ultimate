extends RefCounted
## T-266: the render census per camera for perf_marks `--views=<capture set>` (no class_name on purpose: a tool).
## The renderer's own counts (objects, draw calls, triangles in the colour pass and in the shadow passes) come from
## RenderingServer.viewport_get_render_info and are zero headless; everything else is counted here from the scene
## tree against the camera's frustum (no occlusion: an upper bound, the same before and after a change), so the
## headless run on Windows gives the same census lines as the rendered one under WSL.

const CAMS_JSON: String = "res://data/gravelight/capture_cams.json"
const EYE: float = 1.62


## The distinct cameras of the named capture sets: [{name, pos: Vector3 (feet), yaw, pitch (degrees)}].
static func load_views(sets: PackedStringArray) -> Array:
	var out: Array = []
	var f: FileAccess = FileAccess.open(CAMS_JSON, FileAccess.READ)
	if f == null:
		return out
	var cfg: Variant = JSON.parse_string(f.get_as_text())
	if not (cfg is Dictionary):
		return out
	var seen: Dictionary = {}
	for sn: String in sets:
		var sd: Dictionary = ((cfg as Dictionary).get("sets", {}) as Dictionary).get(sn, {})
		for c: Variant in sd.get("cams", []):
			var cam: Dictionary = c
			var a: Array = cam.get("pos", [0, 0, 0])
			if a.size() < 3 or cam.has("map") or cam.has("look_at"):
				continue
			var pos: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
			var key: String = "%s|%d" % [str(pos.snapped(Vector3.ONE * 0.5)), int(round(float(cam.get("yaw", 0.0)) / 15.0))]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"name": str(cam.get("name", "cam%d" % out.size())), "pos": pos, "yaw": float(cam.get("yaw", 0.0)), "pitch": float(cam.get("pitch", 0.0))})
	return out


static func only(views: Array, names: PackedStringArray) -> Array:
	return views.filter(func(v: Dictionary) -> bool: return names.has(str(v["name"])))


## At most `n` of them, evenly spaced.
static func sample(views: Array, n: int) -> Array:
	if n <= 0 or views.size() <= n:
		return views
	var out: Array = []
	for i: int in n:
		out.append(views[int(floor(float(i) * float(views.size()) / float(n)))])
	return out


## The player at the view, the bots behind the camera, the zombies in a block 4 to 10 m in front of it.
static func stand(map: MapRoot, v: Dictionary) -> void:
	var p: Player = map.player
	var pos: Vector3 = v["pos"]
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(float(v["yaw"]))
	p.set("_pitch", deg_to_rad(float(v["pitch"])))
	var fwd: Vector3 = -p.global_basis.z
	var right: Vector3 = p.global_basis.x
	var i: int = 0
	for z: Zombie in map.director.active_zombies():
		z.global_position = pos + fwd * (4.0 + float(i / 6) * 2.0) + right * ((float(i % 6) - 2.5) * 1.1)
		z.velocity = Vector3.ZERO
		i += 1
	var b: int = 0
	for n: Node in map.get_tree().get_nodes_in_group(&"bots"):
		if n is Player and n != p:
			(n as Player).global_position = pos - fwd * 1.5 + right * (float(b) - 1.0) * 1.2
			(n as Player).velocity = Vector3.ZERO
			b += 1


static func add_render(acc: Dictionary, vp: Viewport) -> void:
	var rid: RID = vp.get_viewport_rid()
	var names: Dictionary = {"vis": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "sh": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW}
	for k: String in names:
		acc[k + "_obj"] = float(acc.get(k + "_obj", 0.0)) + float(RenderingServer.viewport_get_render_info(rid, names[k], RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
		acc[k + "_dc"] = float(acc.get(k + "_dc", 0.0)) + float(RenderingServer.viewport_get_render_info(rid, names[k], RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		acc[k + "_tri"] = float(acc.get(k + "_tri", 0.0)) + float(RenderingServer.viewport_get_render_info(rid, names[k], RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	acc["all_dc"] = float(acc.get("all_dc", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)


static func _in_frustum(planes: Array[Plane], box: AABB) -> bool:
	for pl: Plane in planes:
		if pl.distance_to(box.get_support(-pl.normal)) > 0.0:
			return false
	return true


static func _sphere_in(planes: Array[Plane], c: Vector3, r: float) -> bool:
	for pl: Plane in planes:
		if pl.distance_to(c) > r:
			return false
	return true


static func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


## What stands in `cam`'s frustum now (see the file's header). Also "top": the map's children with the most surfaces in view.
static func census(map: Node, cam: Camera3D) -> Dictionary:
	var r: Dictionary = {"inst": 0, "surf": 0, "tris_k": 0.0, "skinned": 0, "mm": 0, "lights": 0, "lights_all": 0, "lights_30": 0, "lights_50": 0, "sh_lamps": 0, "sh_views": 0, "sun_views": 0,
		"casters": 0, "caster_draws": 0, "parts": 0, "parts_all": 0, "decals": 0, "decals_all": 0, "transp": 0, "mats": 0, "shaders": 0, "no_range": 0, "fog_vols": 0}
	if cam == null:
		return r
	var planes: Array[Plane] = cam.get_frustum()
	var eye: Vector3 = cam.global_position
	var mats: Dictionary = {}
	var shaders: Dictionary = {}
	var top: Dictionary = {}
	var on_lamps: Array = []   # [pos, range, views]
	var nodes: Array[Node] = _walk(map.get_tree().root)
	for n: Node in nodes:
		if n is Light3D:
			var l: Light3D = n as Light3D
			if not l.is_visible_in_tree():
				continue
			if l is DirectionalLight3D:
				if l.shadow_enabled and l.light_energy > 0.0:
					var dl: DirectionalLight3D = l as DirectionalLight3D
					r["sun_views"] = int(r["sun_views"]) + ([1, 2, 4][int(dl.directional_shadow_mode)] as int)
				continue
			r["lights_all"] = int(r["lights_all"]) + 1
			var reach: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
			if l.shadow_enabled:
				var views: int = (6 if (l as OmniLight3D).omni_shadow_mode == OmniLight3D.SHADOW_CUBE else 2) if l is OmniLight3D else 1
				r["sh_lamps"] = int(r["sh_lamps"]) + 1
				r["sh_views"] = int(r["sh_views"]) + views
				on_lamps.append([l.global_position, reach, views])
			var ld: float = eye.distance_to(l.global_position)
			if l.distance_fade_enabled and ld > l.distance_fade_begin + l.distance_fade_length:
				continue   # faded out: the renderer drops it
			if _sphere_in(planes, l.global_position, reach):
				r["lights"] = int(r["lights"]) + 1
				if ld <= 30.0:
					r["lights_30"] = int(r["lights_30"]) + 1
				if ld <= 50.0:
					r["lights_50"] = int(r["lights_50"]) + 1
	for n: Node in nodes:
		if n is Decal:
			if (n as Decal).is_visible_in_tree():
				r["decals_all"] = int(r["decals_all"]) + 1
				if _in_frustum(planes, (n as Decal).global_transform * (n as Decal).get_aabb()):
					r["decals"] = int(r["decals"]) + 1
			continue
		if n is FogVolume:
			if (n as FogVolume).is_visible_in_tree():
				r["fog_vols"] = int(r["fog_vols"]) + 1
			continue
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		var is_parts: bool = gi is GPUParticles3D or gi is CPUParticles3D
		if is_parts:
			if bool(gi.get("emitting")):
				r["parts_all"] = int(r["parts_all"]) + 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not is_parts:
			r["casters"] = int(r["casters"]) + 1
			for lamp: Array in on_lamps:
				var c: Vector3 = lamp[0]
				var q: Vector3 = c.clamp(box.position, box.end)
				if q.distance_to(c) <= float(lamp[1]):
					r["caster_draws"] = int(r["caster_draws"]) + int(lamp[2])
		var d: float = eye.distance_to(box.get_center())
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + gi.visibility_range_end_margin:
			continue
		if gi.visibility_range_begin > 0.0 and d < gi.visibility_range_begin - gi.visibility_range_begin_margin:
			continue
		if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if not _in_frustum(planes, box):
			continue
		if is_parts:
			if bool(gi.get("emitting")):
				r["parts"] = int(r["parts"]) + 1
			continue
		var mesh: Mesh = null
		var count: int = 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
			if (gi as MeshInstance3D).skin != null or gi.get_parent() is Skeleton3D:
				r["skinned"] = int(r["skinned"]) + 1
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			count = maxi(1, (gi as MultiMeshInstance3D).multimesh.visible_instance_count if (gi as MultiMeshInstance3D).multimesh.visible_instance_count >= 0 else (gi as MultiMeshInstance3D).multimesh.instance_count)
			r["mm"] = int(r["mm"]) + 1
		if mesh == null:
			continue
		r["inst"] = int(r["inst"]) + 1
		if gi.visibility_range_end <= 0.0:
			r["no_range"] = int(r["no_range"]) + 1
		var ns: int = mesh.get_surface_count()
		r["surf"] = int(r["surf"]) + ns
		var topn: Node = gi
		while topn.get_parent() != null and topn.get_parent() != map and topn.get_parent() != map.get_tree().root:
			topn = topn.get_parent()
		var tk: String = str(topn.name)
		if gi.get_parent() != topn and gi != topn and topn.get_parent() == map:
			var sub: Node = gi
			while sub.get_parent() != topn:
				sub = sub.get_parent()
			tk += "/" + str(sub.name).rstrip("0123456789_")
		top[tk] = int(top.get(tk, 0)) + ns
		for si: int in ns:
			var m: Material = gi.material_override
			if m == null and gi is MeshInstance3D:
				m = (gi as MeshInstance3D).get_active_material(si)
			elif m == null:
				m = mesh.surface_get_material(si)
			if mesh is ArrayMesh or mesh is PrimitiveMesh:
				var tri: float = 0.0
				if mesh is ArrayMesh:
					var il: int = (mesh as ArrayMesh).surface_get_array_index_len(si)
					tri = float(il if il > 0 else (mesh as ArrayMesh).surface_get_array_len(si)) / 3.0
				r["tris_k"] = float(r["tris_k"]) + tri * float(count) / 1000.0
			if m == null:
				continue
			mats[m.get_rid()] = true
			var bm: BaseMaterial3D = m as BaseMaterial3D
			if bm != null:
				shaders[_variant(bm)] = true
				if bm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or bm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
					r["transp"] = int(r["transp"]) + 1
			elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				shaders[(m as ShaderMaterial).shader.get_rid()] = true
				var code: String = (m as ShaderMaterial).shader.code
				if code.contains("ALPHA") and not code.contains("ALPHA_SCISSOR"):
					r["transp"] = int(r["transp"]) + 1
	r["mats"] = mats.size()
	r["shaders"] = shaders.size()
	var keys: Array = top.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(top[a]) > int(top[b]))
	var parts: PackedStringArray = []
	for k: String in keys.slice(0, 8):
		parts.append("%s %d" % [k, top[k]])
	r["top"] = ", ".join(parts)
	return r


## The properties that pick a BaseMaterial3D's generated shader (an estimate of the shader variants in view).
static func _variant(bm: BaseMaterial3D) -> String:
	var k: PackedStringArray = [bm.get_class()]
	for p: String in ["transparency", "cull_mode", "shading_mode", "diffuse_mode", "specular_mode", "blend_mode", "depth_draw_mode", "billboard_mode",
			"normal_enabled", "emission_enabled", "rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "ao_enabled", "heightmap_enabled",
			"subsurf_scatter_enabled", "backlight_enabled", "refraction_enabled", "detail_enabled", "uv1_triplanar", "uv2_triplanar", "vertex_color_use_as_albedo",
			"texture_filter", "texture_repeat", "proximity_fade_enabled", "distance_fade_mode", "grow", "alpha_antialiasing_mode", "disable_receive_shadows", "no_depth_test"]:
		k.append(str(bm.get(p)))
	k.append(str(bm.albedo_texture != null))
	k.append(str(bm.roughness_texture != null))
	k.append(str(bm.metallic_texture != null))
	return ",".join(k)


static func line(r: Dictionary) -> String:
	return ("drawn: colour %d obj %d dc %.0fk tri, shadow %d obj %d dc %.0fk tri, all dc %d | frustum: inst %d (no range %d) surf %d tri %.0fk skinned %d multimesh %d | " +
		"lights %d of %d (%d within 30 m, %d within 50 m), shadowed lamps %d = %d views + sun %d, casters %d (lamp caster draws %d) | particles %d of %d, decals %d of %d, fog volumes %d, transparent %d, materials %d, shaders %d | top: %s") % [
		int(r.get("vis_obj", 0)), int(r.get("vis_dc", 0)), float(r.get("vis_tri", 0)) / 1000.0, int(r.get("sh_obj", 0)), int(r.get("sh_dc", 0)), float(r.get("sh_tri", 0)) / 1000.0,
		int(r.get("all_dc", 0)), int(r["inst"]), int(r["no_range"]), int(r["surf"]), float(r["tris_k"]), int(r["skinned"]), int(r["mm"]),
		int(r["lights"]), int(r["lights_all"]), int(r["lights_30"]), int(r["lights_50"]), int(r["sh_lamps"]), int(r["sh_views"]), int(r["sun_views"]), int(r["casters"]), int(r["caster_draws"]),
		int(r["parts"]), int(r["parts_all"]), int(r["decals"]), int(r["decals_all"]), int(r["fog_vols"]), int(r["transp"]), int(r["mats"]), int(r["shaders"]), str(r.get("top", ""))]


## The average and the worst view (by draw calls when rendered, else by surfaces in the frustum).
static func summary(rows: Array) -> void:
	if rows.is_empty():
		return
	var keys: PackedStringArray = ["all_dc", "vis_dc", "sh_dc", "vis_tri", "sh_tri", "surf", "inst", "skinned", "lights", "sh_views", "caster_draws", "parts", "decals", "transp", "mats"]
	var avg: PackedStringArray = []
	var worst: PackedStringArray = []
	for k: String in keys:
		var tot: float = 0.0
		var mx: float = -1.0
		var who: String = ""
		for r: Dictionary in rows:
			var v: float = float(r.get(k, 0.0))
			tot += v
			if v > mx:
				mx = v
				who = str(r["name"])
		avg.append("%s %.0f" % [k, tot / float(rows.size())])
		worst.append("%s %.0f (%s)" % [k, mx, who])
	print("[views] %d views, average: %s" % [rows.size(), ", ".join(avg)])
	print("[views] worst: %s" % ", ".join(worst))


## `--casters`: the visible shadow casters by where they sit and how big they are (the longest side of the box and
## its thinnest), with their surfaces: which small or flat things draw into every shadow map in reach for nothing.
static func casters(map: Node) -> void:
	var groups: Dictionary = {}
	var sizes: Dictionary = {"under 0.25 m": 0, "0.25-0.5 m": 0, "0.5-1 m": 0, "1-2 m": 0, "over 2 m": 0}
	var flat: int = 0
	var total: int = 0
	var surfs: int = 0
	for n: Node in _walk(map):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree() or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		if gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		var longest: float = box.get_longest_axis_size()
		var thin: float = box.get_shortest_axis_size()
		var ns: int = (gi as MeshInstance3D).mesh.get_surface_count() if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null else 1
		total += 1
		surfs += ns
		var sk: String = "under 0.25 m" if longest < 0.25 else ("0.25-0.5 m" if longest < 0.5 else ("0.5-1 m" if longest < 1.0 else ("1-2 m" if longest < 2.0 else "over 2 m")))
		sizes[sk] = int(sizes[sk]) + ns
		if thin < 0.03:
			flat += ns
		var top: Node = gi
		while top.get_parent() != map and top.get_parent() != null:
			top = top.get_parent()
		var sub: Node = gi
		while sub != top and sub.get_parent() != top:
			sub = sub.get_parent()
		var key: String = str(top.name) + ("/" + str(sub.name).rstrip("0123456789_") if sub != top else "")
		if not groups.has(key):
			groups[key] = [0, 0, 0, 0.0]
		var g: Array = groups[key]
		g[0] = int(g[0]) + 1
		g[1] = int(g[1]) + ns
		if longest < 0.5:
			g[2] = int(g[2]) + ns
		g[3] = maxf(float(g[3]), longest)
	print("[casters] %d casters, %d surfaces; by longest side (surfaces): %s; thinner than 3 cm: %d" % [total, surfs, str(sizes), flat])
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(groups[a][1]) > int(groups[b][1]))
	for k: String in keys.slice(0, 40):
		print("[casters]   %-44s %4d casters %4d surfaces (%d under 0.5 m), largest %.1f m" % [k, groups[k][0], groups[k][1], groups[k][2], groups[k][3]])
	# why a static batch still casts its own shadow (ShadowProxies merges only plain opaque batches)
	var why: Dictionary = {}
	for holder: Node in _walk(map):
		if not (holder.name == "StaticBatches" or holder.has_meta("vis_group") or holder.has_meta("shadow_proxies")):
			continue
		for c: Node in holder.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi == null or mi.mesh == null or not mi.is_visible_in_tree() or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or str(mi.name).begins_with("ShadowProxy"):
				continue
			var reason: String = "?"
			if mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0:
				reason = "visibility range"
			elif mi.transparency > 0.0:
				reason = "instance transparency"
			elif mi.global_transform.basis.determinant() <= 0.0:
				reason = "mirrored"
			else:
				var m: Material = mi.material_override if mi.material_override != null else mi.get_active_material(0)
				if m == null:
					reason = "no material"
				elif not (m is BaseMaterial3D):
					reason = "shader material " + ((m as ShaderMaterial).shader.resource_path.get_file() if m is ShaderMaterial and (m as ShaderMaterial).shader != null else m.get_class())
				elif m.next_pass != null:
					reason = "next pass"
				elif (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					reason = "transparent (%d)" % (m as BaseMaterial3D).transparency
				elif (m as BaseMaterial3D).grow:
					reason = "grow"
				else:
					reason = "plain (surfaces %d, override %s)" % [mi.mesh.get_surface_count(), str(mi.material_override != null)]
			why[reason] = int(why.get(reason, 0)) + 1
	print("[casters] static batches still casting, by reason: %s" % str(why))


## `--tree=<node name>`: the visual tree under the map's first node of that name (what a prop is made of).
static func tree(map: Node, name_: String) -> void:
	var n: Node = map.find_child(name_, true, false)
	if n == null:
		print("[tree] no node %s" % name_)
		return
	_tree(n, 0)


static func _tree(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n as MeshInstance3D
		var mats: PackedStringArray = []
		for si: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			mats.append((m.get_class() + ("/a" if m is BaseMaterial3D and (m as BaseMaterial3D).transparency != 0 else "") + ":" + str(m.get_instance_id() % 10000)) if m != null else "-")
		extra = " mesh %s surf %d cast %d skin %s [%s]" % [mi.mesh.get_class(), mi.mesh.get_surface_count(), mi.cast_shadow, str(mi.skin != null), ",".join(mats)]
	if n.get_script() != null:
		extra += " (" + (n.get_script() as Script).resource_path.get_file() + ")"
	if n is Node3D and not (n as Node3D).visible:
		extra += " HIDDEN"
	print("[tree] %s%s <%s>%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	for c: Node in n.get_children():
		_tree(c, depth + 1)


## `--props`: the prop meshes PropShadows gave a shadow child, the big ones first (what a new or missing shadow in a
## before / after capture may come from).
static func props(map: Node) -> void:
	var rows: Array = []
	for n: Node in _walk(map):
		if not (n is MeshInstance3D) or not n.has_meta(&"prop_shadow_base"):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		var kinds: Dictionary = {}
		for si: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			var k: String = "-"
			if m is BaseMaterial3D:
				k = "std cull %d transp %d depth %d" % [(m as BaseMaterial3D).cull_mode, (m as BaseMaterial3D).transparency, (m as BaseMaterial3D).depth_draw_mode]
			elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				k = "shader " + (m as ShaderMaterial).shader.resource_path.get_file()
			kinds[k] = int(kinds.get(k, 0)) + 1
		rows.append([(mi.global_transform * mi.get_aabb()).get_longest_axis_size(), "%s surf %d was cast %d layers %d range %.0f-%.0f vis %s | %s" % [str(map.get_path_to(mi)), mi.mesh.get_surface_count(),
			int(mi.get_meta(&"prop_shadow_base")), mi.layers, mi.visibility_range_begin, mi.visibility_range_end, str(mi.is_visible_in_tree()), str(kinds)]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("[props] %d prop meshes with a shadow child" % rows.size())
	for r: Array in rows.slice(0, 30):
		print("[props]   %.1f m %s" % [r[0], r[1]])


## `--batches`: the generators' batches by container, shadow setting and material (cull mode), with the biggest of
## each kind: what ShadowProxies has to reproduce.
static func batches(map: Node) -> void:
	var kinds: Dictionary = {}
	for h: String in ShadowProxies.HOLDERS:
		var holder: Node = map.get_node_or_null(NodePath(h))
		if holder == null:
			continue
		for c: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh == null or str(mi.name).begins_with("ShadowProxy"):
				continue
			var m: Material = mi.material_override if mi.material_override != null else mi.get_active_material(0)
			var mk: String = "-"
			if m is BaseMaterial3D:
				mk = "std cull %d transp %d depth %d blend %d dfade %d" % [(m as BaseMaterial3D).cull_mode, (m as BaseMaterial3D).transparency, (m as BaseMaterial3D).depth_draw_mode,
					(m as BaseMaterial3D).blend_mode, (m as BaseMaterial3D).distance_fade_mode]
			elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				mk = "shader %s cull %d" % [(m as ShaderMaterial).shader.resource_path.get_file(), ShadowProxies.shader_cull((m as ShaderMaterial).shader)]
			var cast: int = int(mi.get_meta("shadow_proxied", mi.cast_shadow))
			var k: String = "%s | cast %d | %s | det %s | vis %s" % [h, cast, mk, "neg" if mi.global_transform.basis.determinant() < 0.0 else "pos", str(mi.visible)]
			if not kinds.has(k):
				kinds[k] = [0, 0.0, ""]
			kinds[k][0] = int(kinds[k][0]) + 1
			var side: float = (mi.global_transform * mi.get_aabb()).get_longest_axis_size()
			if side > float(kinds[k][1]):
				kinds[k][1] = side
				kinds[k][2] = str(mi.name) + " at " + str((mi.global_transform * mi.get_aabb()).get_center().snapped(Vector3.ONE))
	var keys: Array = kinds.keys()
	keys.sort()
	for k: String in keys:
		print("[batches] %4d  %s  (largest %.0f m: %s)" % [kinds[k][0], k, kinds[k][1], kinds[k][2]])


## `--proxy-check`: per batch container, the triangles and the bounds of the batches ShadowProxies merged against
## those of the proxies it made (they must be equal: a proxy that lost or moved geometry loses or moves a shadow).
static func proxy_check(map: Node) -> void:
	for h: String in ShadowProxies.HOLDERS:
		var holder: Node3D = map.get_node_or_null(NodePath(h)) as Node3D
		if holder == null:
			continue
		var groups: Array = [holder]
		for c: Node in holder.get_children():
			if c.has_meta("vis_group") and not (c is MeshInstance3D):
				groups.append(c)
		for g: Node3D in groups:
			var vt: int = 0
			var pt: int = 0
			var vbox: AABB = AABB()
			var pbox: AABB = AABB()
			var vn: int = 0
			var pn: int = 0
			for c: Node in g.get_children():
				var mi: MeshInstance3D = c as MeshInstance3D
				if mi == null or mi.mesh == null:
					continue
				var box: AABB = mi.global_transform * mi.get_aabb()
				var tris: int = mi.mesh.get_faces().size() / 3
				if str(mi.name).begins_with("ShadowProxy"):
					pt += tris
					pbox = box if pn == 0 else pbox.merge(box)
					pn += 1
				elif mi.has_meta("shadow_proxied"):
					vt += tris
					vbox = box if vn == 0 else vbox.merge(box)
					vn += 1
			if vn > 0 or pn > 0:
				print("[proxy-check] %s: %d batches %d triangles, bounds %s size %s | %d proxies %d triangles, bounds %s size %s%s" % [str(map.get_path_to(g)), vn, vt,
					str(vbox.position.snapped(Vector3.ONE * 0.1)), str(vbox.size.snapped(Vector3.ONE * 0.1)), pn, pt, str(pbox.position.snapped(Vector3.ONE * 0.1)), str(pbox.size.snapped(Vector3.ONE * 0.1)),
					"" if vt == pt and vbox.position.is_equal_approx(pbox.position) and vbox.size.is_equal_approx(pbox.size) else "   <-- DIFFERENT"])
	var props: int = 0
	var bad: int = 0
	for n: Node in _walk(map):
		if not (n is MeshInstance3D) or not n.has_meta(&"prop_shadow_base"):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		var child: MeshInstance3D = mi.get_node_or_null("ShadowProp") as MeshInstance3D
		var want: int = 0
		for si: int in mi.mesh.get_surface_count():
			if PropShadows.surface_cull(mi.get_active_material(si)) >= 0:
				var a: Array = mi.mesh.surface_get_arrays(si)
				var ind: Variant = a[Mesh.ARRAY_INDEX]
				want += ((ind as PackedInt32Array).size() if ind is PackedInt32Array and not (ind as PackedInt32Array).is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		props += 1
		if child == null or child.mesh.get_faces().size() / 3 != want:
			bad += 1
			print("[proxy-check] prop %s: %d casting triangles, its shadow child %d   <-- DIFFERENT" % [str(map.get_path_to(mi)), want, child.mesh.get_faces().size() / 3 if child != null else -1])
	print("[proxy-check] props: %d with a shadow child, %d differ" % [props, bad])
