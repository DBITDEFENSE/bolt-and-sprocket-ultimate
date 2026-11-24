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

##
## T-266: since the maps took the CC0 library's textured materials (ShaderMaterials on surface_pbr.gdshader) none of
## their batches counted as "plain", so they all drew their own shadows again: on Map 0 436 of 479 batches, each a
## draw call in every shadow view in reach (the census: 5800 shadow draw calls in one frame at High, 70 % of the
## frame's). A ShaderMaterial is plain when its shader moves no vertex and writes no alpha, depth or discard
## (code_cull); its cull mode is read from its render_mode. Batches that only have a far cut-off (Der Kranich's
## 80 m, Thalbach's dressing) merge too: the proxy keeps the cut-off, a cell's reach further out, so a shadow never
## goes before its batch. Batches tagged for ViewCells (meta "vis_group") merge per group and the proxy carries the
## tag, so it is hidden with them. `build_all` covers every container the generators write (HOLDERS).

const CELL: Vector3 = Vector3(12.0, 6.0, 12.0)
## The generators' batch containers (map-root relative); a container's children tagged "vis_group" that hold batches
## of their own (Totenhafen's StaticBatches/VisGroup_<g>) are built per child.
const HOLDERS: PackedStringArray = ["StaticBatches", "DressBatches", "ZoneBatches", "Dressing/DressingBaked", "Landscape/Batches"]
## A batch with a far cut-off merges only when the cut-off is at least this far (nearer ones are small detail whose
## shadow the cut-off is there to save).
const RANGED_MIN_M: float = 35.0


## Every batch container of the map (MapRoot at load). Returns the summed counts.
static func build_all(map_root: Node) -> Dictionary:
	var out: Dictionary = {"batches": 0, "proxies": 0, "kept": 0}
	var names: PackedStringArray = HOLDERS if RenderTune.on("proxies") else PackedStringArray(["StaticBatches"])
	for h: String in names:
		var holder: Node = map_root.get_node_or_null(NodePath(h))
		if holder == null:
			continue
		_sum(out, build(map_root, h))
		for vg: Node in holder.get_children():   # T-145: batches split into ViewCells visibility groups get proxies per group (hidden with it)
			if vg.has_meta("vis_group") and not (vg is MeshInstance3D):
				_sum(out, build(map_root, h + "/" + String(vg.name)))
	return out


static func _sum(into: Dictionary, r: Dictionary) -> void:
	for k: String in r:
		into[k] = int(into.get(k, 0)) + int(r[k])


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
		var vis: String = str(mi.get_meta("vis_group", "")) if RenderTune.on("proxies") else ""
		var key: String = "%d|%d|%s|%s|%s" % [cull, mi.layers, cell, vis, "r" if mi.visibility_range_end > 0.0 else ""]
		if not groups.has(key):
			groups[key] = {"parts": [], "cull": cull, "layers": mi.layers, "vis": vis, "end": 0.0, "margin": 0.0}
		(groups[key]["parts"] as Array).append([mi.mesh, xf])
		if mi.visibility_range_end > 0.0:
			# the batch's cut-off counts from its own centre, the proxy's from its cell: as far as the farthest of them
			groups[key]["end"] = maxf(float(groups[key]["end"]), mi.visibility_range_end + CELL.length())
			groups[key]["margin"] = maxf(float(groups[key]["margin"]), mi.visibility_range_end_margin)
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
		if float(g["end"]) > 0.0:
			proxy.visibility_range_end = float(g["end"])
			proxy.visibility_range_end_margin = float(g["margin"])
		if str(g["vis"]) != "":
			proxy.set_meta("vis_group", str(g["vis"]))
			proxy.add_to_group(&"view_cell_member")
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
			root.remove_child(n)   # (gone now, not at the end of the frame: a rebuild may follow at once)
			n.free()
		elif n is MeshInstance3D and n.has_meta("shadow_proxied"):
			var mi: MeshInstance3D = n as MeshInstance3D
			mi.cast_shadow = int(mi.get_meta("shadow_proxied")) as GeometryInstance3D.ShadowCastingSetting
			if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				mi.visible = true   # (build hid it: the proxy drew its shadow)
			mi.remove_meta("shadow_proxied")


## Every container's proxies removed (RenderTune.set_enabled, a tool's A/B).
static func undo_all(map_root: Node) -> void:
	for h: String in HOLDERS:
		var holder: Node = map_root.get_node_or_null(NodePath(h))
		if holder == null:
			continue
		for vg: Node in holder.get_children():
			if vg.has_meta("vis_group") and not (vg is MeshInstance3D):
				undo(map_root, h + "/" + String(vg.name))
		undo(map_root, h)


## The cull mode the batch's shadow pass uses (BaseMaterial3D.CULL_*), or -1 when its depth pass is not plain
## enough to merge (or it casts no shadow).
static func _depth_cull(mi: MeshInstance3D) -> int:
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not mi.visible:
		return -1
	if mi.visibility_range_begin > 0.0 or mi.transparency > 0.0:
		return -1
	if mi.visibility_range_end > 0.0 and (not RenderTune.on("proxies") or mi.visibility_range_end < RANGED_MIN_M
			or mi.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED):
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
		if m.next_pass != null:
			return -1
		if bm == null:
			var sc: int = shader_cull((m as ShaderMaterial).shader) if m is ShaderMaterial and RenderTune.on("proxies") else -1
			if sc < 0 or (cull != -2 and sc != cull):
				return -1
			cull = sc
			continue
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
static var _shader_culls: Dictionary = {}   # Shader -> BaseMaterial3D.CULL_* or -1


## The cull mode a spatial shader's depth pass uses when that pass is plain (BaseMaterial3D.CULL_*), else -1.
## Cached per shader.
static func shader_cull(sh: Shader) -> int:
	if sh == null:
		return -1
	if _shader_culls.has(sh):
		return _shader_culls[sh]
	var c: int = code_cull(sh.code)
	_shader_culls[sh] = c
	return c


## The same from the shader's source: it must be opaque and move no vertex, so a merged copy of the triangles draws
## the same depth: no ALPHA / ALPHA_SCISSOR_THRESHOLD / DEPTH / discard anywhere, no write to VERTEX, POSITION or a
## matrix, no depth, blend or vertex render_mode beyond the defaults. Pure (unit-tested).
static func code_cull(code_in: String) -> int:
	var code: String = RegEx.create_from_string("/\\*[\\s\\S]*?\\*/").sub(code_in, "", true)
	code = RegEx.create_from_string("//[^\\n]*").sub(code, "", true)
	var stm: RegExMatch = RegEx.create_from_string("shader_type\\s+(\\w+)\\s*;").search(code)
	if stm == null or stm.get_string(1) != "spatial":
		return -1
	if RegEx.create_from_string("\\b(ALPHA|ALPHA_SCISSOR_THRESHOLD|ALPHA_HASH_SCALE|ALPHA_ANTIALIASING_EDGE|DEPTH|discard|POSITION)\\b").search(code) != null:
		return -1
	if RegEx.create_from_string("\\b(VERTEX|MODEL_MATRIX|MODELVIEW_MATRIX|PROJECTION_MATRIX)\\s*(\\.\\w+\\s*)?[-+*/]?=(?!=)").search(code) != null:
		return -1
	var cull: int = BaseMaterial3D.CULL_BACK
	var rm: RegExMatch = RegEx.create_from_string("render_mode\\s+([^;]*);").search(code)
	if rm != null:
		for mode_raw: String in rm.get_string(1).split(","):
			var mode: String = mode_raw.strip_edges()
			if mode == "cull_disabled":
				cull = BaseMaterial3D.CULL_DISABLED
			elif mode == "cull_front":
				cull = BaseMaterial3D.CULL_FRONT
			elif mode.begins_with("blend_") and mode != "blend_mix":
				return -1
			elif mode in ["depth_draw_never", "depth_test_disabled", "skip_vertex_transform", "world_vertex_coords", "particle_trails", "wireframe",
					"depth_prepass_alpha", "alpha_to_coverage", "alpha_to_coverage_and_one", "vertex_lighting"]:
				return -1
	return cull


static func _material(cull: int) -> StandardMaterial3D:
	if not _mats.has(cull):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = cull as BaseMaterial3D.CullMode
		_mats[cull] = m
	return _mats[cull]
