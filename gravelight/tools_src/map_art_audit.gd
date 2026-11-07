class_name MapArtAudit
extends RefCounted
## Art-vs-collision audit of a loaded map (T-180, the owner: "textures aren't loading", "invisible walls you can't
## see"). Works headless on the live scene (after MapRoot ran, so the runtime dressers' meshes count too):
##  1. materials: every visible GeometryInstance3D (MeshInstance3D, MultiMeshInstance3D, CSG) is checked for a mesh
##     without surfaces, a surface without a material (renders flat white), a texture whose file is gone, a shader
##     material without a shader, an invisible (alpha 0) or debug-magenta material, a textured material on a surface
##     without UVs (renders one flat texel) unless it is triplanar.
##  2. invisible walls: the visible art is copied into trimesh shapes on spare physics layers, one per ViewCells
##     group; from points on the baked navmesh (body and eye height) rays go out in every direction, and wherever a
##     ray stops on a collider (world or door layer) with no art at or before that point and none within 0.45 m of
##     it, that collider is an invisible wall there (0.45 m for railings, named Rail_*: posts and rails with gaps).
##  3. ViewCells: the same rays with only the groups the viewer's cell shows; if the nearest art is hidden by the
##     cell the player looks through the world there (void or the far side).
## Findings are dictionaries; `report()` prints them. tools_src/audit_map_art.tscn runs it on any map,
## smoke_map02_art fails on any finding on Totenhafen.

const ART_LAYER0: int = 20                 # physics layer bits 20..28 hold the art copies (unused by the game)
const GROUPS: Array = ["ALL", "A", "B", "C", "D", "DH", "E", "F", "G"]
const COLLIDE_MASK: int = 1 | (1 << 8)     # world + door
const NEAR_ART: float = 0.3                # art this close to the hit point makes the collider read (a frame, a rim)
const NEAR_RAIL: float = 0.45              # ... for railings (colliders named Rail_*): posts and rails with gaps
const SEE_THROUGH: float = 2.0             # ViewCells: the next shown art this much behind hidden art = a hole
const MIN_RAYS: int = 3                    # a finding needs this many rays (one grazing ray is not a wall)
const COVER_EPS: float = 0.3               # art this far behind the collider surface still counts as its skin
const RAY_LEN: float = 6.0                 # invisible walls: what the player can bump into
const VIEW_LEN: float = 30.0               # ViewCells: what the player can see

var root: Node3D
var findings: Array = []        # {kind, node, detail, pos, count}
var _art_owner: Dictionary = {} # art body instance id -> source node path
var _art_bodies: Array = []
var _group_of: Dictionary = {}  # node instance id -> group (ViewCells members)
var _cells: Array = []
var stats: Dictionary = {}


func _init(map_root: Node3D) -> void:
	root = map_root


## Runs every check; `doors_open` opens every BuyDoor first (a bought door must leave nothing behind).
func run(doors_open: bool = false) -> Array:
	findings.clear()
	var vc: Node = root.get_node_or_null("ViewCells")
	if vc != null:
		_cells = vc.get("cells")
		for g: Variant in vc.call("groups"):
			for n: Variant in vc.call("members", g):
				if is_instance_valid(n):
					_group_of[(n as Node).get_instance_id()] = str(g)
		vc.call("force_position", Vector3(1e6, 1e6, 1e6))   # outside every cell: everything drawn
	if doors_open:
		open_doors()
	_scan_visuals()
	return findings


## Second half (needs one physics frame after run() so the art copies are in the space).
func run_rays() -> Array:
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var points: Array = _reachable(_nav_points(1.5))
	stats["viewpoints"] = points.size()
	var dirs: Array = []
	for el: float in [-35.0, -12.0, 0.0, 15.0, 35.0]:
		for k: int in 32:
			var az: float = TAU * float(k) / 32.0
			var e: float = deg_to_rad(el)
			dirs.append(Vector3(cos(az) * cos(e), sin(e), sin(az) * cos(e)))
	var all_art: int = 0
	for i: int in GROUPS.size():
		all_art |= 1 << (ART_LAYER0 + i)
	var walls: Dictionary = {}   # collider path -> {count, pos, hits}
	var hidden: Dictionary = {}  # cell|art path -> {count, pos}
	var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rq.hit_back_faces = true
	var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = NEAR_ART
	var sph_rail: SphereShape3D = SphereShape3D.new()
	sph_rail.radius = NEAR_RAIL
	sq.collision_mask = all_art
	var rays: int = 0
	for p: Vector3 in points:
		for h: float in [1.0, 1.6]:
			var o: Vector3 = p + Vector3(0, h, 0)
			var cell: Dictionary = _cell_at(o)
			var shown_mask: int = all_art if cell.is_empty() else _mask_of(PackedStringArray(cell.get("show", [])))
			for d: Vector3 in dirs:
				rays += 1
				var hc: Dictionary = _ray(space, rq, o, o + d * RAY_LEN, COLLIDE_MASK)
				var ha: Dictionary = _ray(space, rq, o, o + d * VIEW_LEN, all_art)
				var dc: float = o.distance_to(hc["position"]) if not hc.is_empty() else INF
				var da: float = o.distance_to(ha["position"]) if not ha.is_empty() else INF
				if not hc.is_empty() and da > dc + COVER_EPS and _is_static(hc["collider"]):
					sq.shape = sph_rail if String((hc["collider"] as Node).name).begins_with("Rail_") else sph
					sq.transform = Transform3D(Basis.IDENTITY, hc["position"])
					if space.intersect_shape(sq, 1).is_empty():
						var key: String = str(root.get_path_to(hc["collider"] as Node))
						var w: Dictionary = walls.get(key, {"count": 0, "pos": hc["position"], "from": o})
						w["count"] = int(w["count"]) + 1
						walls[key] = w
				if shown_mask != all_art and not ha.is_empty():
					var hs: Dictionary = _ray(space, rq, o, o + d * VIEW_LEN, shown_mask)
					var ds: float = o.distance_to(hs["position"]) if not hs.is_empty() else INF
					if ds > da + SEE_THROUGH:
						var src: String = str(_art_owner.get((ha["collider"] as Object).get_instance_id(), "?"))
						var hk: String = "%s|%s" % [cell.get("name", "?"), src]
						var hd: Dictionary = hidden.get(hk, {"count": 0, "pos": ha["position"], "from": o})
						hd["count"] = int(hd["count"]) + 1
						hidden[hk] = hd
	stats["rays"] = rays
	for key: String in walls:
		var w2: Dictionary = walls[key]
		if int(w2["count"]) >= MIN_RAYS:
			var n: Node = root.get_node_or_null(NodePath(key))
			findings.append({"kind": "invisible_wall", "node": key, "count": w2["count"], "pos": w2["pos"], "from": w2["from"],
				"detail": _aabb_text(n)})
	for hk2: String in hidden:
		var hd2: Dictionary = hidden[hk2]
		if int(hd2["count"]) >= MIN_RAYS:
			var parts: PackedStringArray = hk2.split("|")
			findings.append({"kind": "viewcell_hides", "node": parts[1], "count": hd2["count"], "pos": hd2["pos"], "from": hd2["from"],
				"detail": "cell %s" % parts[0]})
	return findings


func cleanup() -> void:
	for b: Variant in _art_bodies:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_art_bodies.clear()


func count(kind: String) -> int:
	var c: int = 0
	for f: Dictionary in findings:
		if str(f["kind"]) == kind:
			c += 1
	return c


func report(tag: String = "AUDIT") -> void:
	var kinds: Dictionary = {}
	for f: Dictionary in findings:
		kinds[f["kind"]] = int(kinds.get(f["kind"], 0)) + 1
		var p: Vector3 = f.get("pos", Vector3.ZERO)
		var fr: Vector3 = f.get("from", p)
		print("%s %-15s %-70s n=%-4s at (%.1f, %.1f, %.1f) from (%.1f, %.1f, %.1f) %s" % [tag, f["kind"], f["node"], str(f.get("count", 1)),
			p.x, p.y, p.z, fr.x, fr.y, fr.z, f.get("detail", "")])
	print("%s_SUMMARY %s %s" % [tag, JSON.stringify(kinds), JSON.stringify(stats)])


# ------------------------------------------------------------------ visuals

func _scan_visuals() -> void:
	var nvis: int = 0
	var ntri: int = 0
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if _in_character(gi):
			continue
		var faces: PackedVector3Array = PackedVector3Array()
		if gi is MeshInstance3D:
			var mi: MeshInstance3D = gi as MeshInstance3D
			if mi.mesh == null:
				_add("no_mesh", mi, "")
				continue
			if mi.mesh.get_surface_count() == 0:
				_add("empty_mesh", mi, "")
				continue
			var any_art: bool = false
			for s: int in mi.mesh.get_surface_count():
				var m: Material = mi.material_override
				if m == null:
					m = mi.get_surface_override_material(s)
				if m == null:
					m = mi.mesh.surface_get_material(s)
				if _check_material(mi, m, mi.mesh, s):
					any_art = true
			if not any_art:
				continue
			faces = mi.mesh.get_faces()
			faces = _xform(faces, mi.global_transform)
		elif gi is MultiMeshInstance3D:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.mesh.get_surface_count() == 0:
				_add("no_mesh", gi, "multimesh")
				continue
			var mat_ok: bool = false
			for s2: int in mm.mesh.get_surface_count():
				var m2: Material = gi.material_override if gi.material_override != null else mm.mesh.surface_get_material(s2)
				if _check_material(gi, m2, mm.mesh, s2):
					mat_ok = true
			if not mat_ok or mm.visible_instance_count == 0:
				continue
			var base: PackedVector3Array = mm.mesh.get_faces()
			var cnt: int = mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
			if cnt * base.size() > 600000:
				continue   # rain, footprints: thin clouds, not walls
			for k: int in cnt:
				faces.append_array(_xform(base, gi.global_transform * mm.get_instance_transform(k)))
		elif gi is CSGShape3D:
			var csg: CSGShape3D = gi as CSGShape3D
			if not csg.is_root_shape():
				continue
			var ms: Array = csg.get_meshes()
			if ms.size() < 2 or ms[1] == null:
				continue
			var cm: Mesh = ms[1]
			for s3: int in cm.get_surface_count():
				_check_material(csg, cm.surface_get_material(s3), cm, s3)
			faces = _xform(cm.get_faces(), csg.global_transform * (ms[0] as Transform3D))
		else:
			continue
		if faces.size() < 3:
			continue
		nvis += 1
		ntri += faces.size() / 3
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1 << (ART_LAYER0 + _group_index(gi))
		body.collision_mask = 0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
		body.global_transform = Transform3D.IDENTITY
		_art_bodies.append(body)
		_art_owner[body.get_instance_id()] = str(root.get_path_to(gi))
	stats["art_meshes"] = nvis
	stats["art_tris"] = ntri


## Checks one surface's material; false when the surface draws nothing (an invisible material).
func _check_material(gi: GeometryInstance3D, m: Material, mesh: Mesh, s: int) -> bool:
	var where: String = "surface %d" % s
	if m == null:
		_add("no_material", gi, where + " (renders flat white)")
		return true
	if m is ShaderMaterial:
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm.shader == null or sm.shader.code.strip_edges() == "":
			_add("no_shader", gi, where)
		else:
			if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV == 0 \
					and _shader_reads_uv(sm.shader.code) and not _triplanar_on(sm):
				_add("no_uv", gi, where + " UV-mapped shader on a surface without UVs")
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				if int(u.get("type", 0)) == TYPE_OBJECT:
					var tv: Variant = sm.get_shader_parameter(str(u["name"]))
					if tv is Texture2D and not _tex_ok(tv as Texture2D):
						_add("missing_texture", gi, "%s %s %s" % [where, u["name"], (tv as Texture2D).resource_path])
		return true
	if m is BaseMaterial3D:
		var bm: BaseMaterial3D = m as BaseMaterial3D
		for p: int in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ORM, BaseMaterial3D.TEXTURE_ROUGHNESS,
				BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
			var t: Texture2D = bm.get_texture(p)
			if t != null and not _tex_ok(t):
				_add("missing_texture", gi, "%s slot %d %s" % [where, p, t.resource_path])
		if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.albedo_color.a < 0.03 and bm.albedo_texture == null \
				and not (bm.emission_enabled and bm.emission.v > 0.05):
			_add("invisible_material", gi, where)
			return false
		var c: Color = bm.albedo_color
		if bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and c.r > 0.9 and c.b > 0.9 and c.g < 0.2:
			_add("debug_material", gi, where + " magenta unshaded")
		if bm.albedo_texture != null and not bm.uv1_triplanar and mesh is ArrayMesh:
			var fmt: int = (mesh as ArrayMesh).surface_get_format(s)
			if fmt & Mesh.ARRAY_FORMAT_TEX_UV == 0:
				_add("no_uv", gi, where + " textured material on a surface without UVs")
	return true


static var _uv_cache: Dictionary = {}


## A shader that samples a texture with the mesh's UV (not world space / triplanar) needs UVs on the surface.
static func _shader_reads_uv(code: String) -> bool:
	var h: int = code.hash()
	if _uv_cache.has(h):
		return _uv_cache[h]
	var re: RegEx = RegEx.create_from_string("texture\\s*\\([^;]*\\bUV\\b")
	var re2: RegEx = RegEx.create_from_string("\\b\\w+\\s*=\\s*UV\\b")
	var r: bool = re.search(code) != null or re2.search(code) != null
	_uv_cache[h] = r
	return r


## surface_pbr.gdshader (the CC0 library) maps in world space unless its `triplanar` uniform is false.
static func _triplanar_on(sm: ShaderMaterial) -> bool:
	if not sm.shader.code.contains("uniform bool triplanar"):
		return false
	var v: Variant = sm.get_shader_parameter("triplanar")
	if v == null:
		return sm.shader.code.contains("uniform bool triplanar = true")
	return bool(v)


func _tex_ok(t: Texture2D) -> bool:
	var rp: String = t.resource_path
	if rp == "" or rp.contains("::"):
		return true   # built in (noise textures, gradients, sub-resources)
	return ResourceLoader.exists(rp)


func _add(kind: String, n: Node, detail: String) -> void:
	findings.append({"kind": kind, "node": str(root.get_path_to(n)), "detail": detail, "pos": (n as Node3D).global_position if n is Node3D else Vector3.ZERO})


func _in_character(n: Node) -> bool:
	var c: Node = n.get_parent()
	while c != null and c != root:
		if c is CharacterBody3D:
			return true
		c = c.get_parent()
	return false


func _group_index(n: Node) -> int:
	var c: Node = n
	while c != null and c != root:
		var g: Variant = _group_of.get(c.get_instance_id())
		if g != null:
			var i: int = GROUPS.find(str(g))
			return i if i >= 0 else 0
		c = c.get_parent()
	return 0


func _mask_of(show: PackedStringArray) -> int:
	var m: int = 1 << ART_LAYER0   # ALL
	for g: String in show:
		var i: int = GROUPS.find(g)
		if i > 0:
			m |= 1 << (ART_LAYER0 + i)
	return m


func _cell_at(p: Vector3) -> Dictionary:
	for c: Variant in _cells:
		var box: AABB = (c as Dictionary).get("aabb", AABB())
		if box.has_point(p):
			return c
	return {}


static func _xform(f: PackedVector3Array, xf: Transform3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	out.resize(f.size())
	for i: int in f.size():
		out[i] = xf * f[i]
	return out


func _ray(space: PhysicsDirectSpaceState3D, rq: PhysicsRayQueryParameters3D, a: Vector3, b: Vector3, mask: int) -> Dictionary:
	rq.from = a
	rq.to = b
	rq.collision_mask = mask
	return space.intersect_ray(rq)


func _is_static(o: Object) -> bool:
	return o is StaticBody3D or o is AnimatableBody3D or o is CSGShape3D


func _aabb_text(n: Node) -> String:
	if n == null:
		return ""
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	for c: Node in n.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs.shape is BoxShape3D:
			var e: Vector3 = (cs.shape as BoxShape3D).size * 0.5
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					for sz: float in [-1.0, 1.0]:
						var p: Vector3 = cs.global_transform * Vector3(e.x * sx, e.y * sy, e.z * sz)
						lo = lo.min(p)
						hi = hi.max(p)
	if lo == Vector3.INF:
		return ""
	return "box (%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)" % [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z]


## The points a survivor can walk to from the first player's spawn (any door bought): islands the bake left on top of
## a prop's box or a block's lid are not viewpoints.
func _reachable(points: Array) -> Array:
	var from: Node3D = root.find_child("Player1", true, false) as Node3D
	if from == null:
		return points
	var map: RID = root.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(map, from.global_position)
	var out: Array = []
	for p: Vector3 in points:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, a, p, true, 0xFFFFFFFF)
		if not path.is_empty() and path[path.size() - 1].distance_to(p) < 0.6:
			out.append(p)
	stats["unreachable_points"] = points.size() - out.size()
	return out


## Points on the baked navmesh (world space), thinned to one per `cell` metres.
func _nav_points(cell: float) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for n: Node in root.find_children("*", "NavigationRegion3D", true, false):
		var nr: NavigationRegion3D = n as NavigationRegion3D
		var nm: NavigationMesh = nr.navigation_mesh
		if nm == null:
			continue
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			if poly.size() < 3:
				continue
			# a fan of the polygon: its centroid and the midpoints toward each vertex
			var cen: Vector3 = Vector3.ZERO
			for vi: int in poly:
				cen += verts[vi]
			cen /= float(poly.size())
			var cand: Array = [cen]
			for vi2: int in poly:
				cand.append(cen.lerp(verts[vi2], 0.6))
			for c: Vector3 in cand:
				var w: Vector3 = nr.global_transform * c
				var key: Vector3i = Vector3i(floori(w.x / cell), floori(w.y / 1.0), floori(w.z / cell))
				if seen.has(key):
					continue
				seen[key] = true
				out.append(w)
	return out


## Debugging aid: every GeometryInstance3D whose world AABB comes within `r` of `p`, with why it counts or not.
func probe(p: Vector3, r: float = 0.6) -> void:
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		var bb: AABB = gi.global_transform * gi.get_aabb()
		if not bb.grow(r).has_point(p):
			continue
		var why: String = "art"
		if not gi.is_visible_in_tree():
			why = "hidden"
		elif gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			why = "shadow-only"
		elif _in_character(gi):
			why = "character"
		print("PROBE %-80s %-22s %s group=%s aabb=%s" % [str(root.get_path_to(gi)), gi.get_class(), why, GROUPS[_group_index(gi)], str(bb)])


## Debugging aid: what a ray from a to b hits on the collision layers and on the art copies (after run()).
func probe_ray(a: Vector3, b: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rq.hit_back_faces = true
	var all_art: int = 0
	for i: int in GROUPS.size():
		all_art |= 1 << (ART_LAYER0 + i)
	var hc: Dictionary = _ray(space, rq, a, b, COLLIDE_MASK)
	var ha: Dictionary = _ray(space, rq, a, b, all_art)
	print("RAY collider: %s" % ("none" if hc.is_empty() else "%s at %s" % [root.get_path_to(hc["collider"] as Node), hc["position"]]))
	print("RAY art:      %s" % ("none" if ha.is_empty() else "%s at %s" % [_art_owner.get((ha["collider"] as Object).get_instance_id(), "?"), ha["position"]]))


## Bought doors leave nothing behind: opens every BuyDoor under the map and looks for any collider (world or door
## layer) still standing in its opening (the opening shrunk 15 cm off each jamb and the lintel, from 10 cm off the
## floor). The door's own body goes off at once; call open_doors(), wait a physics frame, then door_check().
func open_doors() -> void:
	for d: Node in root.get_tree().get_nodes_in_group(&"doors"):
		if root.is_ancestor_of(d) and d.has_method("open") and not bool(d.get("is_open")):
			d.call("open", 0)


func door_check() -> int:
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var n_doors: int = 0
	for d: Node in root.get_tree().get_nodes_in_group(&"doors"):
		if not root.is_ancestor_of(d) or not (d is Node3D) or d.get("size") == null:
			continue
		n_doors += 1
		var dn: Node3D = d as Node3D
		var sz: Vector3 = d.get("size")
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(maxf(0.1, sz.x - 0.3), maxf(0.1, sz.y - 0.25), 0.2)
		q.shape = bs
		q.collision_mask = COLLIDE_MASK
		q.transform = Transform3D(dn.global_transform.basis.orthonormalized(), dn.global_transform * Vector3(0, 0.1 + bs.size.y * 0.5, 0))
		for hit: Dictionary in space.intersect_shape(q, 8):
			var c: Object = hit.get("collider")
			if c is Node and _is_static(c):
				findings.append({"kind": "door_blocked", "node": str(root.get_path_to(dn)), "count": 1, "pos": dn.global_position,
					"detail": "still blocked by %s" % root.get_path_to(c as Node)})
	stats["doors"] = n_doors
	return n_doors
