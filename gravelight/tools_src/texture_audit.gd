extends Node
## T-222: a headless audit of how a map's surfaces are textured (the owner: "the textures on some hallways are messed
## up"). Loads the map (its LookMaterials pass runs as in play) and lists:
##   STRETCH   a mesh whose material maps a texture by the mesh's own UVs or object-space triplanar while the node is
##             scaled unevenly (a unit box stretched to a 12 m wall: one texture tile smeared over it);
##   NO_UV     a mesh with no UV array whose material maps a texture by UVs (the static batches drop UVs: such a
##             surface renders one texel, a flat colour);
##   ZFIGHT    two surfaces of different materials on the same axis-aligned plane, facing the same way, overlapping
##             by more than 0.05 m2 (they flicker against each other);
##   FLAT      a big world surface (two sides of 3 m or more) with an untextured material (plain colour, no noise).
## Each finding prints the node path, the material and where it is (map frame). Nothing is changed.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/texture_audit.tscn -- \
##     --map=res://gravelight/maps/map04_fernflug/map04a.tscn [--box=x0,y0,z0,x1,y1,z1] [--out=<file.json>]

var _args: Dictionary = {}
var _rows: Array = []
var _box: AABB = AABB()
var _use_box: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	if _args.has("box"):
		var v: PackedFloat64Array = PackedFloat64Array(str(_args["box"]).split_floats(","))
		_box = AABB(Vector3(v[0], v[1], v[2]), Vector3(v[3] - v[0], v[4] - v[1], v[5] - v[2]))
		_use_box = true
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	GameState.bot_count = 0
	Campaign.reset()
	var map: Node = (load(str(_args["map"])) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(map)
	await get_tree().create_timer(3.0).timeout
	RoundManager.stop()
	var tris: Dictionary = {}   # plane key -> [[mat_id, rect2, path, centre], ...]
	var counts: Dictionary = {"STRETCH": 0, "NO_UV": 0, "ZFIGHT": 0, "FLAT": 0}
	for n: Node in map.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _skip(map, mi) or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var path: String = String(map.get_path_to(mi))
		var xf: Transform3D = (map as Node3D).global_transform.affine_inverse() * mi.global_transform
		var aabb: AABB = xf * mi.get_aabb()
		if _use_box and not _box.intersects(aabb):
			continue
		for si: int in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override != null else mi.get_active_material(si)
			if mat == null:
				continue
			var mode: String = _mapping(mat)
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var has_uv: bool = arr[Mesh.ARRAY_TEX_UV] != null and (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0
			var sc: Vector3 = mi.global_transform.basis.get_scale().abs()
			var lo: float = minf(sc.x, minf(sc.y, sc.z))
			var hi: float = maxf(sc.x, maxf(sc.y, sc.z))
			if (mode == "uv" or mode == "object") and lo > 0.0001 and hi / lo > 3.0 and hi > 2.5:
				_add("STRETCH", path, mat, aabb, "mapping %s, scale %s" % [mode, sc])
				counts["STRETCH"] += 1
			if mode == "uv" and not has_uv:
				_add("NO_UV", path, mat, aabb, "a UV-mapped texture on a mesh with no UVs (flat colour)")
				counts["NO_UV"] += 1
			if mode == "flat":
				var sz: Vector3 = aabb.size
				var big: int = (1 if sz.x >= 3.0 else 0) + (1 if sz.y >= 3.0 else 0) + (1 if sz.z >= 3.0 else 0)
				if big >= 2 and not path.contains("Glow") and not _transparent(mat):
					_add("FLAT", path, mat, aabb, "an untextured material over %s" % sz)
					counts["FLAT"] += 1
			if _transparent(mat):
				continue
			_collect_planes(tris, arr, xf, mat.get_instance_id(), path, _mat_name(mat))
	counts["ZFIGHT"] = _zfight(tris)
	print("[texaudit] %s: %s" % [_args["map"], counts])
	for r: Dictionary in _rows:
		print("[texaudit] %s %s | %s | at %s | %s" % [r["kind"], r["path"], r["mat"], r["at"], r["why"]])
	if _args.has("out"):
		var f: FileAccess = FileAccess.open(str(_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"map": _args["map"], "counts": counts, "rows": _rows}, " "))
		f.close()
	get_tree().quit()


func _skip(map: Node, mi: MeshInstance3D) -> bool:
	# characters, guns, the player and the HUD's 3D bits are not the map's surfaces
	var p: String = String(map.get_path_to(mi)).to_lower()
	for w: String in ["player", "zombie", "bot", "viewmodel", "squad", "person_", "pickup"]:
		if p.contains(w):
			return true
	return false


var _keys: Dictionary = {}


func _mat_name(m: Material) -> String:
	if _keys.is_empty():
		for k: Variant in Mats._cache.keys():
			if Mats._cache[k] != null:
				_keys[(Mats._cache[k] as Material).get_instance_id()] = "mats:" + str(k)
	if _keys.has(m.get_instance_id()):
		return str(_keys[m.get_instance_id()])
	if m.resource_name != "":
		return m.resource_name
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m as BaseMaterial3D
		return "std#%s%s%s" % [b.albedo_color.to_html(false), "+tex" if b.albedo_texture != null else "", "+emit" if b.emission_enabled else ""]
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		return (m as ShaderMaterial).shader.resource_path.get_file()
	return m.get_class()


func _transparent(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var code: String = (m as ShaderMaterial).shader.code
		return code.contains("ALPHA") or code.contains("unshaded")
	return false


## How a material places its texture: "world" (world-space triplanar: any size, any batch), "object" (object-space
## triplanar: stretches with the node's scale), "uv" (the mesh's UVs), "flat" (no texture, no procedural pattern),
## "shader" (another shader: not judged).
func _mapping(m: Material) -> String:
	if m is StandardMaterial3D or m is ORMMaterial3D:
		var b: BaseMaterial3D = m as BaseMaterial3D
		var textured: bool = b.albedo_texture != null or b.normal_texture != null or b.detail_enabled
		if not textured:
			return "flat"
		if b.uv1_triplanar:
			return "world" if b.uv1_world_triplanar else "object"
		return "uv"
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm.shader.resource_path.ends_with("surface_pbr.gdshader"):
			return "world" if bool(sm.get_shader_parameter("triplanar")) else "uv"
		return "shader"
	return "shader"


func _add(kind: String, path: String, mat: Material, aabb: AABB, why: String) -> void:
	var c: Vector3 = aabb.get_center()
	_rows.append({"kind": kind, "path": path, "mat": _mat_name(mat), "at": "(%.1f, %.1f, %.1f) size (%.1f, %.1f, %.1f)" % [c.x, c.y, c.z, aabb.size.x, aabb.size.y, aabb.size.z], "why": why})


## Every triangle that lies on an axis plane, bucketed by (axis, facing, plane offset to 2 mm).
func _collect_planes(tris: Dictionary, arr: Array, xf: Transform3D, mat_id: int, path: String, mat_name: String) -> void:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = ix.size() / 3 if ix.size() > 0 else vs.size() / 3
	for t: int in count:
		var a: Vector3 = xf * vs[ix[t * 3] if ix.size() > 0 else t * 3]
		var b: Vector3 = xf * vs[ix[t * 3 + 1] if ix.size() > 0 else t * 3 + 1]
		var c: Vector3 = xf * vs[ix[t * 3 + 2] if ix.size() > 0 else t * 3 + 2]
		var nrm: Vector3 = (c - a).cross(b - a)
		var area: float = nrm.length() * 0.5
		if area < 0.02:
			continue
		nrm = nrm.normalized()
		var axis: int = -1
		for k: int in 3:
			if absf(nrm[k]) > 0.999:
				axis = k
		if axis < 0:
			continue
		if axis == 1 and nrm.y < 0.0 and a.y < 0.1:
			continue   # an underside at floor level: never seen
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		var r: Rect2 = Rect2(Vector2(a[u], a[v]), Vector2.ZERO).expand(Vector2(b[u], b[v])).expand(Vector2(c[u], c[v]))
		var key: String = "%d|%d|%d" % [axis, 1 if nrm[axis] > 0.0 else -1, roundi(a[axis] * 500.0)]
		if not tris.has(key):
			tris[key] = []
		(tris[key] as Array).append([mat_id, r, path, mat_name, (a + b + c) / 3.0])


func _zfight(tris: Dictionary) -> int:
	var seen: Dictionary = {}
	var n: int = 0
	for key: String in tris.keys():
		var lst: Array = tris[key]
		if lst.size() < 2 or lst.size() > 4000:
			continue
		var mats: Dictionary = {}
		for e: Array in lst:
			mats[e[0]] = true
		if mats.size() < 2:
			continue
		for i: int in lst.size():
			for j: int in range(i + 1, lst.size()):
				var e1: Array = lst[i]
				var e2: Array = lst[j]
				if e1[0] == e2[0]:
					continue
				var ov: Rect2 = (e1[1] as Rect2).intersection(e2[1] as Rect2)
				if ov.get_area() < 0.05:
					continue
				var pk: String = "%s|%s|%s" % [key, e1[3], e2[3]] if str(e1[3]) < str(e2[3]) else "%s|%s|%s" % [key, e2[3], e1[3]]
				var cell: Vector3i = Vector3i((e1[4] as Vector3) / 4.0)
				pk += str(cell)
				if seen.has(pk):
					continue
				seen[pk] = true
				var at: Vector3 = e1[4]
				_rows.append({"kind": "ZFIGHT", "path": "%s <> %s" % [e1[2], e2[2]], "mat": "%s <> %s" % [e1[3], e2[3]],
					"at": "(%.1f, %.1f, %.1f)" % [at.x, at.y, at.z], "why": "coplanar overlap %.2f m2 on plane %s" % [ov.get_area(), key]})
				n += 1
	return n
