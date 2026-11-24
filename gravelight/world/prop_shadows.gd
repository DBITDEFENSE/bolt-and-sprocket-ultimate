class_name PropShadows
extends RefCounted
## T-266: one shadow draw per prop instead of one per material. A shadow pass does not care about materials, but the
## renderer draws a mesh surface by surface: a tonic machine's body is 22 surfaces, the C-47 wreck's fuselage 10, a
## barricade board 3, and every one is a draw call in every shadow view the prop stands in (the lamps' and each of the
## sun's cascades). The census after ShadowProxies' fix: Map 0's 910 loose casters still held 1,650 surfaces.
##
## For every static prop mesh with more than one shadow-casting surface this adds a child that draws only into shadow
## maps (SHADOWS_ONLY): the same triangles, positions and normals only, as one surface per cull mode, and turns the
## mesh's own casting off. The child sits under the mesh, so it moves, hides and frees with it, and it takes the
## mesh's visibility range (a LOD chain keeps its pairs). Same triangles, same cull mode: the shadows are the same.
## Left alone: skinned meshes and blend shapes, meshes on a character or a rigid body, anything with a cut-out
## (alpha-scissor / hash / pre-pass) or vertex-moving material, instance transparency, a mesh that casts no shadow.
## Surfaces that never cast (alpha-blended glass) are simply not in the proxy. MapRoot calls build once the map and
## its loaders are in (deferred); what spawns later keeps its own shadows.

const NAME: StringName = &"ShadowProp"
const BASE: StringName = &"prop_shadow_base"

static var _cache: Dictionary = {}   # "<mesh id>|<override id>" -> ArrayMesh or null


## Builds the proxies under `map_root`. Returns {"meshes": proxied, "surfaces": the surfaces they held}.
static func build(map_root: Node) -> Dictionary:
	var out: Dictionary = {"meshes": 0, "surfaces": 0}
	if map_root == null or not RenderTune.on("props"):
		return out
	for n: Node in map_root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var proxy: ArrayMesh = proxy_for(mi)
		if proxy == null:
			continue
		var p: MeshInstance3D = MeshInstance3D.new()
		p.name = NAME
		p.mesh = proxy
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		p.layers = mi.layers
		p.visibility_range_begin = mi.visibility_range_begin
		p.visibility_range_begin_margin = mi.visibility_range_begin_margin
		p.visibility_range_end = mi.visibility_range_end
		p.visibility_range_end_margin = mi.visibility_range_end_margin
		mi.set_meta(BASE, mi.cast_shadow)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(p)
		out["meshes"] = int(out["meshes"]) + 1
		out["surfaces"] = int(out["surfaces"]) + mi.mesh.get_surface_count()
	return out


## Removes the proxies and gives the meshes their own shadows back (RenderTune.set_off, a tool's A/B).
static func undo(map_root: Node) -> void:
	if map_root == null:
		return
	for n: Node in map_root.find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(n) and n.has_meta(BASE):
			(n as MeshInstance3D).cast_shadow = int(n.get_meta(BASE)) as GeometryInstance3D.ShadowCastingSetting
			n.remove_meta(BASE)
			var p: Node = n.get_node_or_null(NodePath(String(NAME)))
			if p != null:
				n.remove_child(p)
				p.free()


## The shadow mesh for `mi`, or null when it is not a prop this pass may touch (see the header). Pure enough to
## unit-test: it reads the node, its ancestors and its materials.
static func proxy_for(mi: MeshInstance3D) -> ArrayMesh:
	if mi == null or mi.mesh == null or mi.has_meta(BASE) or mi.name == NAME:
		return null
	if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
		return null
	var mesh: Mesh = mi.mesh
	if mesh.get_surface_count() < 2 or mi.skin != null or mi.get_parent() is Skeleton3D or mesh.get_blend_shape_count() > 0 or mi.transparency > 0.0:
		return null
	if mi.get_parent() != null and (str(mi.get_parent().name) == "StaticBatches" or mi.has_meta("shadow_proxied")):
		return null
	var p: Node = mi.get_parent()
	while p != null:
		if p is CharacterBody3D or p is RigidBody3D or p is Skeleton3D:
			return null
		p = p.get_parent()
	var key: String = "%d|%d|%d" % [mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override != null else 0, mi.cast_shadow]
	for si: int in mesh.get_surface_count():
		var so: Material = mi.get_surface_override_material(si)
		if so != null:
			key += "|%d:%d" % [si, so.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	var made: ArrayMesh = _make(mi)
	_cache[key] = made
	return made


static func _make(mi: MeshInstance3D) -> ArrayMesh:
	var mesh: Mesh = mi.mesh
	var by_cull: Dictionary = {}   # cull mode -> [[Mesh, surface, Transform3D], ...]
	var casting: int = 0
	for si: int in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			return null
		var cull: int = surface_cull(mi.get_active_material(si))
		if cull == -2:
			continue   # never casts (alpha-blended): not in the proxy
		if cull < 0:
			return null   # a cut-out or a vertex-moving surface: the mesh keeps its own shadows
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
			cull = BaseMaterial3D.CULL_DISABLED
		if not by_cull.has(cull):
			by_cull[cull] = []
		(by_cull[cull] as Array).append([mesh, si, Transform3D.IDENTITY])
		casting += 1
	if casting < 2:
		return null
	var out: ArrayMesh = ArrayMesh.new()
	for cull: int in by_cull:
		var arrays: Array = ShadowProxies.depth_arrays(by_cull[cull] as Array)   # (by hand: SurfaceTool drops unindexed surfaces appended after indexed ones)
		if arrays.is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, ShadowProxies._material(cull))
	return out if out.get_surface_count() > 0 else null


## How a surface with material `m` is drawn into a shadow map: its cull mode (BaseMaterial3D.CULL_*) when the depth
## pass is plain, -2 when it never casts (alpha-blended), -1 when it casts but not plainly (cut-outs, moved
## vertices, no material to read). Pure (unit-tested).
static func surface_cull(m: Material) -> int:
	if m == null or m.next_pass != null:
		return -1
	if m is ShaderMaterial:
		return ShadowProxies.shader_cull((m as ShaderMaterial).shader)
	var bm: BaseMaterial3D = m as BaseMaterial3D
	if bm == null:
		return -1
	if bm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		return -2
	if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.grow or bm.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
			or bm.use_point_size or bm.no_depth_test or bm.use_particle_trails or bm.heightmap_enabled and bm.heightmap_deep_parallax:
		return -1
	return bm.cull_mode
