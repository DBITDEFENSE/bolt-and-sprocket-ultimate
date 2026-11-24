class_name OcclusionWalls
extends Node
## T-266: rooms behind walls are not drawn (occlusion culling), on the Low and Medium Level of detail settings.
## The maps are rooms inside rooms, and the renderer only culled by the camera's frustum: standing in the Inn's vault
## the census counted 1,541 mesh instances in the frustum, at the mine's hall foot on Kaltenbrunn 1,689, nearly all
## of them behind rock and walls, each a draw call. ViewCells answers that by hand on two maps; this answers it on
## all of them from the geometry itself.
##
## The occluders are the maps' own walls: the big triangles (MIN_AREA_M2 and up) of the merged static batches that
## ShadowProxies already holds per cell (opaque, unmoving geometry; a triangle left out only occludes less). They are
## children of their proxy, so a ViewCells group hides its occluders with it. Batches with a draw distance are left
## out (a wall that is no longer drawn must not hide what stands behind it). Doors, barricades, glass and everything
## that moves are no occluders. Things drawn through walls on purpose (labels and sprites with no depth test) are
## told to ignore it. Only the player's own camera is culled this way: a cutscene or free camera draws everything.
## Culling only: nothing is hidden that a line of sight could reach, shadows and lights are untouched, no gameplay.
## High and Ultra do not use it (the map drawn exactly as before); `-- --occlusion` forces it on any setting to try.

const NAME: String = "OcclusionWalls"
const OCC_NAME: StringName = &"WallOccluder"
const MIN_AREA_M2: float = 1.0
const LEVELS: PackedStringArray = ["low", "medium"]

var map_root: Node
var want: bool = false
var built: bool = false
var stats: Dictionary = {"occluders": 0, "triangles": 0}
var _on: bool = false


static func attach(map: Node) -> OcclusionWalls:
	var ow: OcclusionWalls = OcclusionWalls.new()
	ow.name = NAME
	ow.map_root = map
	map.add_child(ow)
	ow.set_level(str(GLSettings.gfx("gfx_lod")))
	return ow


## Whether a Level of detail value culls by occlusion (pure, unit-tested).
static func wanted(lod: String) -> bool:
	if not RenderTune.on("occlusion"):
		return false
	return LEVELS.has(lod) or OS.get_cmdline_user_args().has("--occlusion")


## The current scene's map, re-read from the setting (DetailRange.refresh calls it: the same setting) or after
## RenderTune switched something.
static func refresh(map: Node, lod: String = "") -> void:
	var ow: OcclusionWalls = map.get_node_or_null(NAME) as OcclusionWalls if map != null else null
	if ow != null:
		ow.rebuild()
		ow.set_level(lod if lod != "" else str(GLSettings.gfx("gfx_lod")))


func _ready() -> void:
	process_priority = 900
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _on and get_viewport() != null:
		get_viewport().use_occlusion_culling = false


func set_level(lod: String) -> void:
	want = wanted(lod)
	if want and not built:
		build()
	_apply()


## The occluders thrown away (the proxies they hang on were rebuilt).
func rebuild() -> void:
	if map_root == null:
		return
	for n: Node in map_root.find_children(String(OCC_NAME) + "*", "OccluderInstance3D", true, false):
		n.get_parent().remove_child(n)
		n.free()
	built = false
	stats = {"occluders": 0, "triangles": 0}


func build() -> void:
	built = true
	if map_root == null:
		return
	for n: Node in map_root.find_children("ShadowProxy_*", "MeshInstance3D", true, false):
		var proxy: MeshInstance3D = n as MeshInstance3D
		if proxy.mesh == null or proxy.visibility_range_end > 0.0 or proxy.get_node_or_null(NodePath(String(OCC_NAME))) != null:
			continue
		var tris: PackedVector3Array = big_triangles(proxy.mesh.get_faces(), MIN_AREA_M2)
		if tris.is_empty():
			continue
		var idx: PackedInt32Array = PackedInt32Array()
		idx.resize(tris.size())
		for i: int in tris.size():
			idx[i] = i
		var occ: ArrayOccluder3D = ArrayOccluder3D.new()
		occ.set_arrays(tris, idx)
		var oi: OccluderInstance3D = OccluderInstance3D.new()
		oi.name = OCC_NAME
		oi.occluder = occ
		proxy.add_child(oi)
		stats["occluders"] = int(stats["occluders"]) + 1
		stats["triangles"] = int(stats["triangles"]) + tris.size() / 3
	for n: Node in map_root.find_children("*", "GeometryInstance3D", true, false):
		_see_through(n)


## The triangles of `faces` (three points each) with at least `min_area` square metres (pure, unit-tested).
static func big_triangles(faces: PackedVector3Array, min_area: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var i: int = 0
	while i + 2 < faces.size():
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		if (b - a).cross(c - a).length() * 0.5 >= min_area:
			out.append(a)
			out.append(b)
			out.append(c)
		i += 3
	return out


func _on_node_added(n: Node) -> void:
	if want and n is GeometryInstance3D:
		_see_through.call_deferred(n)


## A visual meant to be seen through walls (no depth test) is never culled by them.
func _see_through(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var through: bool = false
	if n is Label3D:
		through = (n as Label3D).no_depth_test
	elif n is SpriteBase3D:
		through = (n as SpriteBase3D).no_depth_test
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n as MeshInstance3D
		for si: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(si)
			if m is BaseMaterial3D and (m as BaseMaterial3D).no_depth_test:
				through = true
			elif m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("depth_test_disabled"):
				through = true
	if through:
		(n as GeometryInstance3D).ignore_occlusion_culling = true


func _process(_delta: float) -> void:
	_apply()


## Occlusion culling on only while it is wanted and the view is a player's own camera.
func _apply() -> void:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	var on: bool = want and cam != null and _is_player_camera(cam)
	if on != _on or vp.use_occlusion_culling != on:
		_on = on
		vp.use_occlusion_culling = on


static func _is_player_camera(cam: Camera3D) -> bool:
	var p: Node = cam.get_parent()
	while p != null:
		if p is Player:
			return true
		p = p.get_parent()
	return false
