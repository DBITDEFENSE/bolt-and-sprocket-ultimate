class_name ShadowProxies
extends RefCounted
## Shadow-caster proxies (Update 04 performance pass, DECISIONS T-070). A map's StaticBatches (the generators merge
## static geometry per material and cell) still drew one shadow-pass call per batch for every shadowed light that
## re-renders: an omni lamp re-renders all six cube faces whenever anything in its range moves (a zombie, a bot, a
## swinging lantern), so Map 0's eleven shadowed lamps and the sun's four cascades drew ~5000 depth calls a frame,
## the CPU's biggest single cost. Depth does not care about the material, so this merges the batches' casting
## geometry once at load into one positions-and-normals mesh per cell (and per cull mode / render layers), drawn only into
## shadow maps (SHADOWS_ONLY), and turns the batches' own casting off. Same triangles, same transforms, same cull
## mode, so the shadows are identical; the lit pass is untouched.
##
## A batch is merged only when its depth pass is plain: an opaque StandardMaterial3D / ORMMaterial3D override (no
## alpha, grow, billboard or vertex-displacing shader), no visibility range. Anything else keeps its own shadow.
## Generic: any map with a StaticBatches node gets it (MapRoot calls build at load: ~0.1 s on Map 0). Measured on
## Map 0's perf_marks scene: ~5000 -> ~3600 draw calls a frame, +10% average FPS with the separate render thread;
## screenshots before / after differ no more than two plain shots do (the normals are kept for the normal bias).

const CELL: Vector3 = Vector3(12.0, 6.0, 12.0)

## Builds the proxies under `map_root`; returns {"batches": merged, "proxies": made, "kept": left casting}.
static func build(map_root: Node, batch_root_name: String = "StaticBatches") -> Dictionary:
	var out: Dictionary = {"batches": 0, "proxies": 0, "kept": 0}
	var root: Node3D = map_root.get_node_or_null(batch_root_name) as Node3D
	if root == null or root.has_meta("shadow_proxies"):
		return out
	root.set_meta("shadow_proxies", true)
	var groups: Dictionary = {}   # key -> {parts: [[Mesh, Transform3D]], cull: int, layers: int}
	var victims: Array[MeshInstance3D] = []
	var inv: Transform3D = root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	for n: Node in root.get_children():
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var cull: int = _depth_cull(mi)
		if cull < 0:
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				out["kept"] = int(out["kept"]) + 1
			continue
		var xf: Transform3D = inv * mi.global_transform if mi.is_inside_tree() else mi.transform
		if xf.basis.determinant() <= 0.0:
			out["kept"] = int(out["kept"]) + 1   # mirrored: the renderer flips its culling, a baked copy would not
			continue
		var c: Vector3 = xf * mi.mesh.get_aabb().get_center()
		var cell: Vector3i = Vector3i(floori(c.x / CELL.x), floori(c.y / CELL.y), floori(c.z / CELL.z))
		var key: String = "%d|%d|%s" % [cull, mi.layers, cell]
		if not groups.has(key):
			groups[key] = {"parts": [], "cull": cull, "layers": mi.layers}
		(groups[key]["parts"] as Array).append([mi.mesh, xf])
		victims.append(mi)
	for key: String in groups:
		var g: Dictionary = groups[key]
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any: bool = false
		for part: Array in g["parts"]:
			var m: Mesh = part[0]
			for si: int in m.get_surface_count():
				if m.surface_get_primitive_type(si) == Mesh.PRIMITIVE_TRIANGLES:
					st.append_from(m, si, part[1] as Transform3D)
					any = true
		if not any:
			continue
		# positions, normals (the shadow pass pushes vertices along them: the lights' normal bias) and indices; a
		# depth pass reads nothing else
		var full: Array = st.commit_to_arrays()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = full[Mesh.ARRAY_VERTEX]
		arrays[Mesh.ARRAY_NORMAL] = full[Mesh.ARRAY_NORMAL]
		var ind: Variant = full[Mesh.ARRAY_INDEX]
		arrays[Mesh.ARRAY_INDEX] = ind if ind is PackedInt32Array and not (ind as PackedInt32Array).is_empty() else null
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material(int(g["cull"])))
		var proxy: MeshInstance3D = MeshInstance3D.new()
		proxy.name = "ShadowProxy_%d" % int(out["proxies"])
		proxy.mesh = mesh
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		proxy.layers = int(g["layers"])
		root.add_child(proxy)
		out["proxies"] = int(out["proxies"]) + 1
	for mi: MeshInstance3D in victims:
		mi.set_meta("shadow_proxied", mi.cast_shadow)
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			mi.visible = false   # it drew nothing but its shadow, which the proxy draws now
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out["batches"] = victims.size()
	return out


## Puts the batches' own shadows back and removes the proxies (perf_marks --ab=no_shadow_proxy, a diagnosis A/B).
static func undo(map_root: Node, batch_root_name: String = "StaticBatches") -> void:
	var root: Node3D = map_root.get_node_or_null(batch_root_name) as Node3D
	if root == null or not root.has_meta("shadow_proxies"):
		return
	root.remove_meta("shadow_proxies")
	for n: Node in root.get_children():
		if n.name.begins_with("ShadowProxy_"):
			n.queue_free()
		elif n is MeshInstance3D and n.has_meta("shadow_proxied"):
			var mi: MeshInstance3D = n as MeshInstance3D
			mi.cast_shadow = int(mi.get_meta("shadow_proxied")) as GeometryInstance3D.ShadowCastingSetting
			mi.visible = true
			mi.remove_meta("shadow_proxied")


## The cull mode the batch's shadow pass uses (BaseMaterial3D.CULL_*), or -1 when its depth pass is not plain
## enough to merge (or it casts no shadow).
static func _depth_cull(mi: MeshInstance3D) -> int:
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not mi.visible:
		return -1
	if mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0 or mi.transparency > 0.0:
		return -1
	var mats: Array[Material] = []
	if mi.material_override != null:
		mats.append(mi.material_override)
	else:
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			if m == null:
				return -1
			mats.append(m)
	var cull: int = -2
	for m: Material in mats:
		var bm: BaseMaterial3D = m as BaseMaterial3D
		if bm == null or m.next_pass != null:
			return -1
		if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.grow or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
				or bm.use_point_size or bm.no_depth_test or bm.use_particle_trails:
			return -1
		var c: int = bm.cull_mode
		if cull != -2 and c != cull:
			return -1
		cull = c
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
		cull = BaseMaterial3D.CULL_DISABLED
	return cull


static var _mats: Dictionary = {}


static func _material(cull: int) -> StandardMaterial3D:
	if not _mats.has(cull):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = cull as BaseMaterial3D.CullMode
		_mats[cull] = m
	return _mats[cull]
