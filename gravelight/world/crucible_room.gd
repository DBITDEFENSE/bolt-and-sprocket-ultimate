class_name CrucibleRoom
extends Node3D
## The room round the Crucible (UPDATE 10 follow-up, DECISIONS T-175: "improve quality of pack a punch rooms on all
## maps"). One data-driven dresser for every map instead of seven generator passes: MapRoot attaches it once, it finds
## the map's Crucible and builds, in the machine's own frame (origin = floor centre, local -Z = its front), what
## data/gravelight/crucible_rooms.json lists for the map ("maps": {"map00": {...}}, the key is the map id up to its first
## underscore):
##   "pieces"  decoration kits (pipes and tanks feeding the machine, a workbench with tools and half-remade parts,
##             ledger stacks, cables, a grate dais, a Marke ring, a frame, a hood, notices) folded into one ArrayMesh
##             per material (a room is a dozen draw calls, not hundreds), plus a Label3D per notice;
##   "lights"  a key light on the machine (the one shadowed light), warm work lights and the violet Marke light;
##   "sound"   the machine's own hum loop, louder near it and up while it forges;
##   "fx"      steam and sparks fired by GLBus.crucible_started / crucible_ready / crucible_expired and the take
##             (weapon_acquired from &"crucible"); the violet inlays and lights breathe at idle, ramp with the forge
##             and flare when the weapon comes out.
## Presentation only: no collider, no navmesh, no timer, no prompt, nothing networked (every peer hears the Crucible's
## own mirrored signals and dresses its own room). Rules the data keeps (tests/unit/test_crucible_rooms.gd): every
## piece stands off the baked navmesh unless it is flat on the floor (<= FLAT_M) or hangs over head height
## (>= OVERHEAD_M), nothing but a flat piece enters the approach box in front of the machine, and the room adds at
## most one shadowed light to its zone (C4: <= 6 per zone).
##
## T-254 (UPDATE 19, the owner: "make ... the crucible more merged and immersed"; it looked dropped into its room).
## The room now BUILDS THE MACHINE INTO THE BUILDING, from the Crucible node's own transform and a probe of what
## stands round it, so it merges with whatever wall it is put against (and survives being moved):
##   the probe     rays on the world layer, two physics frames after load (probe_room): the wall behind the machine
##                 ("back", metres along local +Z), the ceiling over it ("ceil"), the walls to either side along the
##                 back wall ("left", "right"). Until then, and where no physics runs (tests, the survey), the map's
##                 "room" entry in the json gives the same four numbers. After the probe the dressing is rebuilt once.
##   "surround"    the housing (_surround): masonry, riveted plate, concrete or hull plating (the map's "style")
##                 from the machine's rear third back INTO the wall and up INTO the ceiling, a base course, quoins or
##                 seam strips, a relieving arch over the firebox, iron straps that clamp the drum to it, the flue
##                 taken on to the ceiling (a collar where it goes through) or elbowed back into the housing, a
##                 foundation slab under the plinth, ash and slag in front of the mouth, tongs against the flank,
##                 gauges whose needles move with the fire; soot on the housing, the ceiling and the floor (one
##                 alpha mesh, CrateFx.soot_mat); a wisp of steam at the flue while the fire is in.
##                 A machine that stands free of any wall (further than max_depth) gets a stack within its own
##                 plinth instead, and "cradle" (cargo) only the flue and the deck plate.
##   anchors       any coordinate in "pieces", "lights", "fx" and "sound" may be a string instead of a number:
##                 "ceil", "back", "left", "right", "top" (the housing's top), "w" (its half width), with an offset
##                 ("ceil-0.04", "back-0.3", "left+0.5"): pipes run to the real ceiling and the real wall.
## What the housing may block: it is solid (one box, the Crucible body's layers) only where it is drawn, and it is
## only as wide as stays OFF the baked navmesh (_fits_nav: narrower steps down to the machine's own plinth), so no
## path, no stand point and no use box moves. The use box, the prompt, the price and the timings are the Crucible's.

const CONFIG: String = "res://data/gravelight/crucible_rooms.json"
const VIOLET: Color = Color(0.55, 0.2, 1.0)
const FLAT_M: float = 0.06
const OVERHEAD_M: float = 2.05
## The approach in the machine's frame: the use box (interact_offset z -0.95, 2.2 wide) and the bots' stand point
## (BotBrain._front_of: 1 m further out) with a margin round both.
const APPROACH: AABB = AABB(Vector3(-1.25, 0.0, -3.4), Vector3(2.5, 2.3, 2.55))
const CrateFx: GDScript = preload("res://gravelight/world/crate_fx.gd")
## T-254: the room round the machine when nothing is probed and the json says nothing.
const ROOM_DEFAULT: Dictionary = {"back": 1.3, "ceil": 3.2, "left": 3.0, "right": 3.0}
## The housing's materials and trim per style (Mats keys). "fiction": what it is, for the next reader.
const STYLES: Dictionary = {
	"brick": {"body": "brick_cellar", "trim": "cellar_stone", "band": "iron", "arch": true, "quoins": true, "seams": false},
	"plate": {"body": "machine_grey", "trim": "iron", "band": "brass", "arch": false, "quoins": false, "seams": true},
	"concrete": {"body": "bunker_concrete", "trim": "concrete", "band": "iron", "arch": false, "quoins": false, "seams": false},
	"hull": {"body": "u_interior", "trim": "iron", "band": "iron", "arch": false, "quoins": false, "seams": true},
	"chrome": {"body": "chrome_worn", "trim": "black_paint", "band": "chrome", "arch": false, "quoins": false, "seams": true},
	"cradle": {"body": "iron", "trim": "iron", "band": "iron", "arch": false, "quoins": false, "seams": false},
}
## The machine's own model, for what is built against it (tools_src/blender/world/story_machines.py).
const FLUE_Z: float = 0.1
const FLUE_TOP: float = 3.3
const FLUE_R: float = 0.24
const PLINTH_BACK: float = 1.08
## The housing's courses stand this far proud of its mass: the navmesh fit allows for them.
const NAV_MARGIN: float = 0.08
## Where the hood starts to corbel out: over the drum's dome (2.27 m) and over head height.
const HOOD_Y: float = 2.44

static var _cfg: Dictionary = {}
static var _unit: Dictionary = {}

var crucible: Crucible = null
var map_key: String = ""
var data: Dictionary = {}
var piece_boxes: Array = []        # [AABB (local), piece dict, primitive AABBs] per piece, for the tests and the survey
var lights: Array = []             # [Light3D, base energy, role]
var marke_mat: StandardMaterial3D = null
var hum: AudioStreamPlayer3D = null
var fx: Array = []                 # [CPUParticles3D, "on" events, hide-at time]
var _marke_e: float = 2.5
var _hum_db: float = -12.0
var _t: float = 0.0
var _forge_t: float = -1.0
var _flare: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _labels: int = 0
# T-254
var probe: Dictionary = {}         # back, ceil, left, right (metres; 99 = nothing found)
var sur: Dictionary = {}           # the housing as built: w, z0, z1, top, housed, meets_ceiling
var _nav: Array = []               # the map's baked navmesh polygons (world XZ) at the machine's floor
var _geo: Node3D = null
var _notices: Array = []
var _sur_body: StaticBody3D = null
var _soot: MeshInstance3D = null
var _soot_mat: ShaderMaterial = null
var _soot_k: float = 0.8
var _needles: Array = []           # [pivot Node3D, phase]
var _wisp: CPUParticles3D = null
var _light_src: Array = []         # [Light3D, its json]
var _fx_src: Array = []            # [CPUParticles3D, its json]
var _sound_src: Dictionary = {}
var _wall_mat: Material = null     # what the wall behind the machine is drawn with (the housing is built of it)


# ================================================================== attach

## The config key of a map id: "map04a_thalbach" -> "map04a".
static func key_of(map_id: Variant) -> String:
	return str(map_id).get_slice("_", 0)


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(CONFIG) if FileAccess.file_exists(CONFIG) else {}
	return _cfg


static func config_for(key: String) -> Dictionary:
	return (config().get("maps", {}) as Dictionary).get(key, {})


## MapRoot: one room under `root` when the map has a Crucible and the json has the map. Returns it (or null).
static func attach(root: Node) -> CrucibleRoom:
	var key: String = key_of(root.get("map_id"))
	var d: Dictionary = config_for(key)
	if d.is_empty():
		return null
	var cr: Crucible = null
	for n: Node in root.get_tree().get_nodes_in_group(&"crucible"):
		if n is Crucible and root.is_ancestor_of(n):
			cr = n as Crucible
			break
	if cr == null:
		return null
	var room: CrucibleRoom = CrucibleRoom.new()
	room.name = "CrucibleRoom"
	room.crucible = cr
	room.map_key = key
	room.data = d
	root.add_child(room)
	room.global_transform = cr.global_transform
	if str(d.get("vis_group", "")) != "":
		room.set_meta("vis_group", str(d["vis_group"]))   # ViewCells hides it with the zone it stands in (collect is deferred)
		room.add_to_group(&"view_cell_member", true)
	room.build()
	return room


# ================================================================== build

func build() -> void:
	_rng.seed = hash(map_key)
	probe = room_default(data)
	marke_mat = StandardMaterial3D.new()
	marke_mat.resource_name = "crucible_room_marke"
	marke_mat.albedo_color = Color(0.08, 0.03, 0.12)
	marke_mat.roughness = 0.15
	marke_mat.emission_enabled = true
	marke_mat.emission = VIOLET
	_marke_e = float(data.get("marke_energy", 2.5))
	marke_mat.emission_energy_multiplier = _marke_e
	_build_geometry()
	for l: Dictionary in data.get("lights", []):
		_light(l)
	_sound(data.get("sound", {}))
	for f: Dictionary in data.get("fx", []):
		_fx(f)
	GLBus.crucible_started.connect(_on_started)
	GLBus.crucible_ready.connect(_on_ready)
	GLBus.crucible_expired.connect(_on_expired)
	GLBus.weapon_acquired.connect(_on_acquired)
	_reprobe()


## Everything drawn (T-254: built from the json's "room" at first, again once the real room has been probed).
func _build_geometry() -> void:
	for old: Variant in [_geo, _sur_body, _soot, _wisp] + _notices + _needles.map(func(e: Array) -> Node: return e[0]):
		if old != null and is_instance_valid(old):
			(old as Node).free()
	_geo = null
	_sur_body = null
	_soot = null
	_wisp = null
	_notices = []
	_needles = []
	piece_boxes = []
	_labels = 0
	var kit: Kit = Kit.new(marke_mat)
	var s: Dictionary = data.get("surround", {})
	if _wall_mat != null:
		kit.custom["wall"] = _wall_mat
	if not s.is_empty():
		kit.begin()
		kit.frame = Transform3D.IDENTITY
		_surround(kit, s)
		piece_boxes.append([kit.end(), {"kind": "surround"}, kit.parts])
	for p: Dictionary in data.get("pieces", []):
		kit.begin()
		_piece(kit, p)
		var ab: AABB = kit.end()
		piece_boxes.append([ab, p, kit.parts])
	_geo = Node3D.new()
	_geo.name = "Dressing"
	add_child(_geo)
	kit.commit(_geo)
	if not s.is_empty():
		_surround_extras(s)


## T-254: the room as it really is. Two physics frames after load (the map's bodies are in the space by then), the
## room moves to where the Crucible stands now, reads the navmesh and the walls round it and builds itself again.
func _reprobe() -> void:
	if crucible == null or not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or crucible == null or not is_instance_valid(crucible) or not crucible.is_inside_tree():
		return
	refit()


## Probe and rebuild now (the tests and the survey call it after stepping physics themselves).
func refit() -> void:
	global_transform = crucible.global_transform
	_nav = _collect_nav()
	probe = probe_room()
	_build_geometry()
	for e: Array in _light_src:
		_place_light(e[0], e[1])
	for e2: Array in _fx_src:
		(e2[0] as Node3D).position = _p3((e2[1] as Dictionary).get("at"), Vector3(0, 2.0, 0))
	if hum != null:
		hum.position = _p3(_sound_src.get("at"), Vector3(0, 1.2, 0))


static func room_default(d: Dictionary) -> Dictionary:
	var out: Dictionary = ROOM_DEFAULT.duplicate()
	out.merge(d.get("room", {}) as Dictionary, true)
	for k: String in out.keys():
		out[k] = float(out[k])
	return out


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, reach: float, who: Array = []) -> float:
	var a: Vector3 = global_transform * from
	var b: Vector3 = global_transform * (from + dir * reach)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1)
	if _sur_body != null and is_instance_valid(_sur_body):
		q.exclude = [_sur_body.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		who.append(hit.get("collider"))
	return -1.0 if hit.is_empty() else a.distance_to(hit["position"])


## The material a solid thing is drawn with: the generators' boxes are a body with its mesh as a child (or the
## other way round), the mesh a scaled unit box under a world-triplanar material, which lies right on anything.
static func material_of(collider: Object) -> Material:
	var n: Node = collider as Node
	if n == null:
		return null
	var cands: Array = [n] + n.get_children()
	var par: Node = n.get_parent()
	if par != null and (par is MeshInstance3D or par.get_child_count() <= 4):
		cands.append(par)
		if par.get_child_count() <= 4:
			cands.append_array(par.get_children())
	for c: Variant in cands:
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null:
			continue
		var m: Material = mi.material_override
		if m == null and mi.mesh.get_surface_count() > 0:
			m = mi.get_active_material(0)
		if m is ShaderMaterial:
			return m
		var sm: StandardMaterial3D = m as StandardMaterial3D
		if sm != null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and sm.uv1_triplanar:
			return m
	return null


## Rays from the machine on the world layer: {back, ceil, left, right}. A direction where nothing is found within
## reach keeps 99 (the machine stands free there); a number the rays cannot give falls back to the json's "room".
func probe_room() -> Dictionary:
	var out: Dictionary = room_default(data)
	if not is_inside_tree():
		return out
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# the wall behind: six rays from inside the machine's rear, the lower median (a prop or a niche does not decide it)
	# (above 1.7 m: the generators' NavBlock boxes are 1.6 m high and still solid where no machine stands on them)
	var up0: float = _ray(space, Vector3(0.0, 0.6, -0.3), Vector3.UP, 16.0)
	var head: float = (up0 + 0.6) if up0 >= 0.0 else 99.0
	var backs: Array = []
	var walls: Array = []
	for x: float in [0.0, -0.8, 0.8]:
		for y: float in [minf(1.75, head - 0.75), minf(2.3, head - 0.3)]:
			var d: float = _ray(space, Vector3(x, y, 0.3), Vector3(0, 0, 1), 7.0, walls)
			backs.append(d + 0.3 if d >= 0.0 else 99.0)
	backs.sort()
	out["back"] = float(backs[2])
	_wall_mat = null
	for wc: Variant in walls:
		_wall_mat = material_of(wc)
		if _wall_mat != null:
			break
	# the ceiling over the machine and over the housing: the highest hit (the housing may stand up into a vault, never
	# short of it); nothing overhead at all: 99
	var zc: Array = [-0.3, clampf((0.62 + minf(float(out["back"]), 2.6)) * 0.5, 0.3, 1.6)]
	var top: float = -1.0
	for x2: float in [-1.0, 0.0, 1.0]:
		for z: float in zc:
			var d2: float = _ray(space, Vector3(x2, 0.6, z), Vector3.UP, 16.0)
			if d2 >= 0.0:
				top = maxf(top, d2 + 0.6)
	out["ceil"] = top if top > 0.0 else 99.0
	# the side walls, along the back wall (where a conduit would run)
	var zs: float = clampf(minf(float(out["back"]), 2.6) - 0.35, 0.2, 2.2)
	var ys: float = minf(2.0, float(out["ceil"]) - 0.5)
	for side: Array in [["left", -1.0], ["right", 1.0]]:
		var d3: float = _ray(space, Vector3(float(side[1]) * 1.6, ys, zs), Vector3(float(side[1]), 0, 0), 12.0)
		out[side[0]] = d3 + 1.6 if d3 >= 0.0 else 99.0
	return out


## The baked navmesh polygons (world XZ) within 1.2 m of the machine's floor, straight from the regions' meshes.
func _collect_nav() -> Array:
	var out: Array = []
	var root: Node = get_parent()
	if root == null:
		return out
	var floor_y: float = global_position.y
	for r: Node in root.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var rx: Transform3D = (r as NavigationRegion3D).global_transform
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var idx: PackedInt32Array = nm.get_polygon(i)
			var pts: PackedVector2Array = []
			var ys: float = 0.0
			var near: bool = false
			for j: int in idx:
				var v: Vector3 = rx * verts[j]
				pts.append(Vector2(v.x, v.z))
				ys += v.y
				if absf(v.x - global_position.x) < 8.0 and absf(v.z - global_position.z) < 8.0:
					near = true
			if near and absf(ys / maxf(1.0, idx.size()) - floor_y) < 1.2:
				out.append(pts)
	return out


## Does a standing piece with this footprint (local XZ) stay off the baked navmesh? (No navmesh known: yes.)
func _fits_nav(r: Rect2) -> bool:
	if _nav.is_empty():
		return true
	var x: float = r.position.x + 0.04
	while x <= r.end.x - 0.04 + 0.001:
		var z: float = r.position.y + 0.04
		while z <= r.end.y - 0.04 + 0.001:
			var w: Vector3 = global_transform * Vector3(x, 0.0, z)
			for pts: PackedVector2Array in _nav:
				if Geometry2D.is_point_in_polygon(Vector2(w.x, w.z), pts):
					return false
			z += 0.15
		x += 0.15
	return true


## An anchored number: a plain number, or "ceil" / "back" / "left" / "right" / "top" / "w" with an optional offset.
func _n(v: Variant) -> float:
	if not (v is String):
		return float(v)
	var t: String = (v as String).strip_edges()
	var cut: int = -1
	for i: int in range(1, t.length()):
		if t[i] == "+" or t[i] == "-":
			cut = i
			break
	var key: String = t if cut < 0 else t.substr(0, cut)
	var off: float = 0.0 if cut < 0 else float(t.substr(cut))
	var pr: Dictionary = probe if not probe.is_empty() else room_default(data)
	var fb: Dictionary = room_default(data)
	match key:
		"ceil":
			return (float(pr["ceil"]) if float(pr["ceil"]) < 90.0 else float(fb["ceil"])) + off
		"back":
			return (float(pr["back"]) if float(pr["back"]) < 90.0 else float(fb["back"])) + off
		"left":
			return -(float(pr["left"]) if float(pr["left"]) < 90.0 else float(fb["left"])) + off
		"right":
			return (float(pr["right"]) if float(pr["right"]) < 90.0 else float(fb["right"])) + off
		"top":
			return float(sur.get("top", 3.0)) + off
		"w":
			return float(sur.get("w", 1.5)) + off
		"-w":
			return -float(sur.get("w", 1.5)) + off
	return float(t)


func _p3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(_n(a[0]), _n(a[1]), _n(a[2]))
	return fallback


## Builds the pieces only (no tree, no lights): [AABB, piece, parts] per piece, in the machine's frame (parts: the
## AABB of each primitive). The tests and the survey read the layout without loading a map.
static func layout(key: String) -> Array:
	var d: Dictionary = config_for(key)
	var r: CrucibleRoom = CrucibleRoom.new()
	r.map_key = key
	r.data = d
	r.probe = room_default(d)
	var kit: Kit = Kit.new(StandardMaterial3D.new())
	var out: Array = []
	if not (d.get("surround", {}) as Dictionary).is_empty():
		kit.begin()
		r._surround(kit, d["surround"])
		out.append([kit.end(), {"kind": "surround"}, kit.parts])
	for p: Dictionary in d.get("pieces", []):
		kit.begin()
		r._piece(kit, p)
		out.append([kit.end(), p, kit.parts])
	r.free()
	return out


## The footprints (local XZ) of the primitives that stand on the floor: neither flat nor overhead.
static func footprints_local(key: String) -> Array:
	var out: Array = []
	for e: Array in layout(key):
		for ab: AABB in e[2]:
			if is_standing(ab):
				out.append(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z))
	return out


## A piece that a body would walk into: taller than FLAT_M and reaching below OVERHEAD_M.
static func is_standing(ab: AABB) -> bool:
	return ab.end.y > FLAT_M and ab.position.y < OVERHEAD_M


static func _v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func _col(a: Variant, fallback: Color) -> Color:
	if a is String:
		return Color.from_string(str(a), fallback)
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## One piece. Positions are in the machine's frame; `yaw` (degrees) turns a kit about its own `at`.
func _piece(k: Kit, p: Dictionary) -> void:
	var at: Vector3 = _p3(p.get("at"))
	var yaw: float = deg_to_rad(float(p.get("yaw", 0.0)))
	k.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	var mat: String = str(p.get("mat", "iron"))
	var sh: int = int(p.get("shadow", -1))
	match str(p.get("kind", "")):
		"box":
			k.box(Vector3.ZERO, _p3(p.get("size"), Vector3.ONE * 0.2), mat, _p3(p.get("rot")), sh)
		"cyl":
			k.cyl(Vector3.ZERO, float(p.get("r", 0.1)), float(p.get("h", 0.5)), mat, _p3(p.get("rot")), sh)
		"pipe":
			_pipe(k, p, mat)
		"tank":
			_tank(k, p, mat)
		"bench":
			_bench(k, p, mat)
		"ledger":
			_ledger(k, p)
		"cable":
			_cable(k, p, mat)
		"grate":
			_grate(k, p)
		"ring":
			_ring(k, p)
		"frame":
			_frame(k, p, mat)
		"hood":
			_hood(k, p, mat)
		"rack":
			_rack(k, p, mat)
		"drum":
			k.cyl(Vector3(0, 0.44, 0), 0.29, 0.88, mat, Vector3.ZERO, sh)
			for by: float in [0.12, 0.44, 0.76]:
				k.cyl(Vector3(0, by, 0), 0.3, 0.035, "iron", Vector3.ZERO, 0)
			k.cyl(Vector3(0, 0.885, 0), 0.27, 0.01, "rust", Vector3.ZERO, 0)
		"crate":
			var s: Vector3 = _p3(p.get("size"), Vector3(0.6, 0.6, 0.6))
			k.box(Vector3(0, s.y * 0.5, 0), s, mat, Vector3.ZERO, sh)
			for e: float in [-1.0, 1.0]:
				k.box(Vector3(e * (s.x * 0.5 - 0.03), s.y * 0.5, 0), Vector3(0.07, s.y + 0.01, s.z + 0.01), "beam", Vector3.ZERO, 0)
		"lamp":
			_lamp_fixture(k, p)
		"notice":
			_notice(k, p)
		"chain":
			_chain(k, p, mat)


# ------------------------------------------------------------------ kits

## A run of pipe through `points` (radius r), flanged at every joint, an optional violet sight glass at the middle of
## the longest run and a hand wheel valve at `valve` (an index into the points).
func _pipe(k: Kit, p: Dictionary, mat: String) -> void:
	var pts: Array = p.get("points", [])
	var r: float = float(p.get("r", 0.06))
	var fl: String = str(p.get("flange", "iron"))
	var longest: int = -1
	var best: float = 0.0
	for i: int in range(1, pts.size()):
		var a: Vector3 = _p3(pts[i - 1])
		var b: Vector3 = _p3(pts[i])
		k.seg(a, b, r, mat)
		if a.distance_to(b) > best:
			best = a.distance_to(b)
			longest = i
	for i2: int in pts.size():
		var c: Vector3 = _p3(pts[i2])
		k.ball(c, Vector3.ONE * r * 2.3, fl, 0)
	if bool(p.get("glass", false)) and longest > 0:
		var a2: Vector3 = _p3(pts[longest - 1])
		var b2: Vector3 = _p3(pts[longest])
		var m: Vector3 = a2.lerp(b2, 0.5)
		var d: Vector3 = (b2 - a2).normalized()
		k.seg(m - d * 0.2, m + d * 0.2, r * 1.15, "marke")
		for e: float in [-1.0, 1.0]:
			k.seg(m + d * (e * 0.2 - 0.03), m + d * (e * 0.2 + 0.03), r * 1.6, fl)
	var vi: int = int(p.get("valve", -1))
	if vi >= 0 and vi < pts.size():
		var c2: Vector3 = _p3(pts[vi])
		var out: Vector3 = _p3(p.get("valve_out"), Vector3(0, 0, -1)).normalized()
		k.seg(c2, c2 + out * (r + 0.14), 0.018, "steel")
		k.cyl_axis(c2 + out * (r + 0.14), out, 0.13, 0.025, "red_paint")


## An upright tank: banded drum on a skirt, a domed cap, a gauge, a violet sight strip, a valve and a pipe stub.
func _tank(k: Kit, p: Dictionary, mat: String) -> void:
	var r: float = float(p.get("r", 0.35))
	var h: float = float(p.get("h", 1.6))
	var base: float = float(p.get("y", 0.0))
	k.cyl(Vector3(0, base + 0.09, 0), r * 0.92, 0.18, "iron")
	k.cyl(Vector3(0, base + 0.18 + h * 0.5, 0), r, h, mat)
	k.ball(Vector3(0, base + 0.18 + h, 0), Vector3(r * 2.0, r * 0.7, r * 2.0), mat)
	for i: int in 3:
		k.cyl(Vector3(0, base + 0.18 + h * (0.15 + 0.35 * i), 0), r + 0.015, 0.05, str(p.get("band", "iron")), Vector3.ZERO, 0)
	var face: Vector3 = _p3(p.get("face"), Vector3(0, 0, -1)).normalized()
	var side: Vector3 = face.cross(Vector3.UP).normalized()
	if bool(p.get("sight", true)):
		k.box(face * (r - 0.01) + Vector3(0, base + 0.18 + h * 0.55, 0) , Vector3(0.05, h * 0.55, 0.05), "marke", Vector3(0, rad_to_deg(atan2(face.x, face.z)), 0), 0)
	var gp: Vector3 = face * (r + 0.02) + side * (r * 0.5) + Vector3(0, base + 0.18 + h * 0.75, 0)
	k.cyl_axis(gp, face, 0.09, 0.05, "brass")
	k.cyl_axis(gp + face * 0.026, face, 0.075, 0.006, "gauge_face")
	var top: Vector3 = Vector3(0, base + 0.18 + h + r * 0.3, 0)
	k.seg(top, top + Vector3(0, 0.25, 0), 0.05, str(p.get("pipe_mat", "copper")))
	k.cyl(top + Vector3(0, 0.25, 0), 0.08, 0.04, "iron", Vector3.ZERO, 0)


## A workbench (top, legs, a back board) dressed as the remaking bench: tools, a vice, a gun half taken apart with a
## violet-veined part, cloth, a lamp-lit sheet of the Ledger's forms. Local -Z is the side you work from.
func _bench(k: Kit, p: Dictionary, mat: String) -> void:
	var w: float = float(p.get("w", 1.6))
	var d: float = float(p.get("d", 0.6))
	var h: float = float(p.get("h", 0.9))
	k.box(Vector3(0, h - 0.03, 0), Vector3(w, 0.06, d), mat)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 - 0.05), (h - 0.06) * 0.5, sz * (d * 0.5 - 0.05)), Vector3(0.07, h - 0.06, 0.07), "iron", Vector3.ZERO, 0)
	k.box(Vector3(0, 0.18, 0), Vector3(w - 0.1, 0.03, d - 0.1), "beam", Vector3.ZERO, 0)
	if bool(p.get("back", true)):
		k.box(Vector3(0, h + 0.35, d * 0.5 - 0.02), Vector3(w, 0.7, 0.03), "beam")
		for i: int in 5:   # hanging tools on the back board: files, tongs, a hammer
			var tx: float = -w * 0.4 + i * w * 0.2
			k.box(Vector3(tx, h + 0.45, d * 0.5 - 0.05), Vector3(0.025, 0.32 - 0.04 * (i % 2), 0.015), "steel", Vector3.ZERO, 0)
			k.box(Vector3(tx, h + 0.62, d * 0.5 - 0.05), Vector3(0.04, 0.05, 0.02), "leather", Vector3.ZERO, 0)
	var top: float = h
	# the vice at the right end
	k.box(Vector3(w * 0.5 - 0.18, top + 0.07, -d * 0.5 + 0.12), Vector3(0.16, 0.14, 0.12), "machine_grey", Vector3.ZERO, 0)
	k.box(Vector3(w * 0.5 - 0.18, top + 0.07, -d * 0.5 + 0.02), Vector3(0.16, 0.12, 0.04), "machine_grey", Vector3.ZERO, 0)
	k.seg(Vector3(w * 0.5 - 0.3, top + 0.08, -d * 0.5 + 0.0), Vector3(w * 0.5 - 0.06, top + 0.08, -d * 0.5 + 0.0), 0.008, "steel")
	# a rifle half re-taught: barrel and receiver apart, the stock, the violet-veined bolt carrier in a tray
	var gx: float = -w * 0.12
	k.seg(Vector3(gx - 0.45, top + 0.025, -0.05), Vector3(gx + 0.25, top + 0.025, -0.08), 0.014, "steel")
	k.box(Vector3(gx + 0.38, top + 0.035, -0.06), Vector3(0.22, 0.05, 0.05), "steel", Vector3(0, 6, 0), 0)
	k.box(Vector3(gx + 0.1, top + 0.03, 0.14), Vector3(0.36, 0.05, 0.08), "walnut", Vector3(0, -12, 0), 0)
	k.box(Vector3(gx - 0.2, top + 0.012, 0.12), Vector3(0.26, 0.02, 0.16), "iron", Vector3.ZERO, 0)
	k.box(Vector3(gx - 0.2, top + 0.035, 0.12), Vector3(0.12, 0.03, 0.04), "marke", Vector3(0, 20, 0), 0)
	k.box(Vector3(gx - 0.12, top + 0.03, 0.08), Vector3(0.05, 0.02, 0.02), "marke", Vector3(0, -30, 0), 0)
	# hammer, tongs, a file, a rag, an oil can
	k.box(Vector3(-w * 0.42, top + 0.02, -0.12), Vector3(0.25, 0.025, 0.025), "walnut", Vector3(0, 25, 0), 0)
	k.box(Vector3(-w * 0.42 + 0.11, top + 0.03, -0.17), Vector3(0.05, 0.04, 0.09), "steel", Vector3(0, 25, 0), 0)
	k.box(Vector3(-w * 0.3, top + 0.012, 0.15), Vector3(0.34, 0.012, 0.03), "steel", Vector3(0, -40, 0), 0)
	k.box(Vector3(-w * 0.3, top + 0.012, 0.17), Vector3(0.3, 0.012, 0.03), "steel", Vector3(0, -32, 0), 0)
	k.box(Vector3(w * 0.15, top + 0.015, 0.15), Vector3(0.2, 0.03, 0.15), "linen", Vector3(0, 14, 0), 0)
	k.cyl(Vector3(w * 0.3, top + 0.06, 0.12), 0.05, 0.12, "olive_steel", Vector3.ZERO, 0)
	k.seg(Vector3(w * 0.3, top + 0.12, 0.12), Vector3(w * 0.3 - 0.1, top + 0.2, 0.06), 0.006, "brass")
	# forms pinned under a brass weight
	k.box(Vector3(w * 0.05, top + 0.004, -0.15), Vector3(0.21, 0.004, 0.29), "paper_old", Vector3(0, -8, 0), 0)
	k.box(Vector3(w * 0.08, top + 0.008, -0.13), Vector3(0.21, 0.004, 0.29), "paper", Vector3(0, 5, 0), 0)
	k.cyl(Vector3(w * 0.08, top + 0.03, -0.2), 0.03, 0.05, "brass", Vector3.ZERO, 0)
	# crates of parts under it
	if bool(p.get("under", true)):
		k.box(Vector3(-w * 0.25, 0.2 + 0.03, 0.0), Vector3(0.42, 0.34, 0.36), "furniture", Vector3(0, 4, 0), 0)
		k.box(Vector3(w * 0.22, 0.2 + 0.02, 0.02), Vector3(0.38, 0.3, 0.34), "olive_drab", Vector3(0, -6, 0), 0)


## Stacks of the Ledger's books and forms (a crate as a desk, a lectern or a shelf: `h` is the surface).
func _ledger(k: Kit, p: Dictionary) -> void:
	var h: float = float(p.get("h", 0.0))
	var n: int = int(p.get("stacks", 3))
	for i: int in n:
		var x: float = (float(i) - (n - 1) * 0.5) * 0.3
		var books: int = 2 + (i * 7 + 3) % 4
		var y: float = h
		for b: int in books:
			var th: float = 0.035 + 0.01 * float((b + i) % 3)
			k.box(Vector3(x + 0.01 * float((b * 5) % 3 - 1), y + th * 0.5, 0.0), Vector3(0.24, th, 0.32), "leather" if b % 2 == 0 else "cloth_red",
				Vector3(0, float((b * 13 + i * 7) % 11) - 5.0, 0), 0)
			k.box(Vector3(x + 0.01 * float((b * 5) % 3 - 1) + 0.004, y + th * 0.5, 0.0), Vector3(0.23, th * 0.8, 0.315), "paper_old",
				Vector3(0, float((b * 13 + i * 7) % 11) - 5.0, 0), 0)
			y += th
	if bool(p.get("loose", true)):
		k.box(Vector3(0.05, h + 0.002, -0.3), Vector3(0.21, 0.003, 0.29), "paper", Vector3(0, 17, 0), 0)


## A sagging cable from a to b (rubber, or the map's own), `segs` straight pieces on a catenary-ish curve.
func _cable(k: Kit, p: Dictionary, mat: String) -> void:
	var a: Vector3 = _p3(p.get("a"))
	var b: Vector3 = _p3(p.get("b"))
	var sag: float = float(p.get("sag", 0.3))
	var r: float = float(p.get("r", 0.025))
	var segs: int = int(p.get("segs", 8))
	var prev: Vector3 = a
	for i: int in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var q: Vector3 = a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		k.seg(prev, q, r, mat if mat != "iron" else "rubber")
		prev = q


## A floor grate in front of the machine (the dais you stand on to feed it), a frame and cross bars, flat.
func _grate(k: Kit, p: Dictionary) -> void:
	var lo: Vector3 = _p3(p.get("lo"))
	var hi: Vector3 = _p3(p.get("hi"))
	var t: float = float(p.get("t", 0.03))
	var c: Vector3 = (lo + hi) * 0.5
	var s: Vector3 = Vector3(hi.x - lo.x, t, hi.z - lo.z)
	k.box(Vector3(c.x, lo.y + t * 0.5, c.z), s, str(p.get("mat", "steel_grate")), Vector3.ZERO, 0)
	var e: float = 0.06
	var fm: String = str(p.get("frame", "steel"))
	k.box(Vector3(c.x, lo.y + t * 0.5 + 0.004, lo.z + e * 0.5), Vector3(s.x, t + 0.008, e), fm, Vector3.ZERO, 0)
	k.box(Vector3(c.x, lo.y + t * 0.5 + 0.004, hi.z - e * 0.5), Vector3(s.x, t + 0.008, e), fm, Vector3.ZERO, 0)
	k.box(Vector3(lo.x + e * 0.5, lo.y + t * 0.5 + 0.004, c.z), Vector3(e, t + 0.008, s.z), fm, Vector3.ZERO, 0)
	k.box(Vector3(hi.x - e * 0.5, lo.y + t * 0.5 + 0.004, c.z), Vector3(e, t + 0.008, s.z), fm, Vector3.ZERO, 0)
	if bool(p.get("glow", true)):   # a violet seam under the grate's front edge, lit from below
		k.box(Vector3(c.x, lo.y + 0.004, lo.z + 0.12), Vector3(s.x - 0.2, 0.006, 0.04), "marke", Vector3.ZERO, 0)


## A flat violet ring of `segments` dashes on the floor, radius r round `at` (the Marke circle you stand in).
func _ring(k: Kit, p: Dictionary) -> void:
	var r: float = float(p.get("r", 1.6))
	var n: int = int(p.get("segments", 24))
	var w: float = float(p.get("w", 0.06))
	var from: float = deg_to_rad(float(p.get("from", 0.0)))
	var to: float = deg_to_rad(float(p.get("to", 360.0)))
	for i: int in n:
		var a: float = from + (to - from) * (float(i) + 0.5) / float(n)
		var dash: float = (to - from) * r / float(n) * 0.62
		k.box(Vector3(sin(a) * r, 0.006, cos(a) * r), Vector3(dash, 0.008, w), "marke", Vector3(0, rad_to_deg(a) + 90.0, 0), 0)


## A portal round the machine: two riveted columns at +-w/2 (at local z `z`), a lintel at `h`, a violet keystone.
func _frame(k: Kit, p: Dictionary, mat: String) -> void:
	var w: float = float(p.get("w", 3.0))
	var h: float = float(p.get("h", 3.0))
	var c: float = float(p.get("col", 0.22))
	var z: float = float(p.get("z", 0.6))
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * w * 0.5
		k.box(Vector3(x, h * 0.5, z), Vector3(c, h, c), mat)
		k.box(Vector3(x, 0.1, z), Vector3(c + 0.1, 0.2, c + 0.1), mat, Vector3.ZERO, 0)
		k.box(Vector3(x, h - 0.12, z), Vector3(c + 0.08, 0.12, c + 0.08), mat, Vector3.ZERO, 0)
		for i: int in 6:
			k.ball(Vector3(x, 0.4 + i * (h - 0.8) / 5.0, z - c * 0.5 - 0.005), Vector3(0.045, 0.045, 0.03), "steel", 0)
	k.box(Vector3(0, h + 0.14, z), Vector3(w + c + 0.2, 0.28, c + 0.1), mat)
	for i2: int in 9:
		k.ball(Vector3(-w * 0.5 + i2 * w / 8.0, h + 0.14, z - c * 0.5 - 0.055), Vector3(0.05, 0.05, 0.03), "steel", 0)
	if bool(p.get("keystone", true)):
		k.box(Vector3(0, h + 0.14, z - c * 0.5 - 0.06), Vector3(0.3, 0.2, 0.03), "marke", Vector3.ZERO, 0)
	if str(p.get("plate", "")) != "":
		k.box(Vector3(0, h + 0.14, z - c * 0.5 - 0.05), Vector3(1.2, 0.18, 0.02), str(p["plate"]), Vector3.ZERO, 0)


## A forge hood over the machine: a truncated pyramid of plate (four sloped skirts) and a flue up to `top`.
func _hood(k: Kit, p: Dictionary, mat: String) -> void:
	var w: float = float(p.get("w", 2.2))
	var d: float = float(p.get("d", 1.8))
	var y: float = float(p.get("y", 3.0))
	var hh: float = float(p.get("h", 0.6))
	var top: float = float(p.get("top", y + 1.5))
	var fr: float = float(p.get("flue_r", 0.22))
	var tilt: float = rad_to_deg(atan2(hh, (w - fr * 2.0) * 0.5))
	var tilt_d: float = rad_to_deg(atan2(hh, (d - fr * 2.0) * 0.5))
	k.box(Vector3(0, y, -d * 0.5), Vector3(w, 0.06, 0.06), "iron")
	k.box(Vector3(0, y, d * 0.5), Vector3(w, 0.06, 0.06), "iron")
	k.box(Vector3(-w * 0.5, y, 0), Vector3(0.06, 0.06, d), "iron")
	k.box(Vector3(w * 0.5, y, 0), Vector3(0.06, 0.06, d), "iron")
	var sl: float = sqrt(hh * hh + pow((w - fr * 2.0) * 0.5, 2.0))
	var sld: float = sqrt(hh * hh + pow((d - fr * 2.0) * 0.5, 2.0))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.25 + fr * 0.5), y + hh * 0.5, 0), Vector3(sl, 0.03, d * 0.85), mat, Vector3(0, 0, -sx * tilt))
		k.box(Vector3(0, y + hh * 0.5, sx * (d * 0.25 + fr * 0.5)), Vector3(w * 0.85, 0.03, sld), mat, Vector3(sx * tilt_d, 0, 0))
	k.cyl(Vector3(0, (y + hh + top) * 0.5, 0), fr, top - y - hh, mat)
	for by: float in [y + hh + 0.3, (y + hh + top) * 0.5, top - 0.2]:
		k.cyl(Vector3(0, by, 0), fr + 0.02, 0.05, "iron", Vector3.ZERO, 0)
	if bool(p.get("glow", true)):   # the hood's mouth catches the forge: a violet lip inside the skirt
		k.box(Vector3(0, y - 0.035, -d * 0.5 + 0.04), Vector3(w * 0.8, 0.02, 0.02), "marke", Vector3.ZERO, 0)


## A wall tool rack: a board with tongs, hammers and a pair of gauntlets (`w` wide, local -Z out of the wall).
func _rack(k: Kit, p: Dictionary, mat: String) -> void:
	var w: float = float(p.get("w", 1.2))
	var h: float = float(p.get("h", 0.6))
	k.box(Vector3(0, 0, -0.012), Vector3(w, h, 0.024), mat, Vector3.ZERO, 0)
	for i: int in int(w / 0.18):
		var x: float = -w * 0.5 + 0.12 + i * 0.18
		var tall: bool = i % 3 == 1
		k.box(Vector3(x, -0.05, -0.04), Vector3(0.02, h * (0.75 if tall else 0.5), 0.015), "steel", Vector3(0, 0, 4.0 * float(i % 2 * 2 - 1)), 0)
		k.box(Vector3(x, h * 0.25 - 0.02, -0.04), Vector3(0.06 if tall else 0.035, 0.05, 0.03), "iron" if tall else "walnut", Vector3.ZERO, 0)
	if bool(p.get("gloves", true)):
		k.box(Vector3(w * 0.5 - 0.12, -0.08, -0.05), Vector3(0.14, 0.3, 0.05), "leather", Vector3(0, 0, 6), 0)


## A caged work lamp fixture (the light itself is a "lights" entry): a bracket out of the wall or a drop from above.
func _lamp_fixture(k: Kit, p: Dictionary) -> void:
	var drop: float = float(p.get("drop", 0.0))
	if drop > 0.0:
		k.seg(Vector3(0, 0, 0), Vector3(0, -drop, 0), 0.008, "iron")
	else:
		k.seg(Vector3(0, 0, 0.0), Vector3(0, 0, -0.25), 0.015, "iron")
	var c: Vector3 = Vector3(0, -drop - 0.12, 0.0 if drop > 0.0 else -0.25)
	k.cyl(c + Vector3(0, 0.1, 0), 0.07, 0.06, "iron", Vector3.ZERO, 0)
	k.ball(c, Vector3(0.11, 0.15, 0.11), str(p.get("bulb", "bulb_warm")), 0)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		k.box(c + Vector3(cos(a) * 0.065, 0, sin(a) * 0.065), Vector3(0.01, 0.2, 0.01), "iron", Vector3.ZERO, 0)
	if bool(p.get("shade", false)):
		k.cyl(c + Vector3(0, 0.06, 0), 0.17, 0.05, "enamel_green", Vector3.ZERO, 0)


## A notice on a wall or a board: paper (or enamel) and its text as a Label3D (one draw call each). Local -Z out.
func _notice(k: Kit, p: Dictionary) -> void:
	var w: float = float(p.get("w", 0.42))
	var h: float = float(p.get("h", 0.56))
	var paper: String = str(p.get("paper", "paper_old"))
	k.box(Vector3(0, 0, -0.003), Vector3(w, h, 0.006), paper, Vector3.ZERO, 0)
	for sx: float in [-1.0, 1.0]:
		k.cyl_axis(Vector3(sx * (w * 0.5 - 0.03), h * 0.5 - 0.03, -0.008), Vector3(0, 0, -1), 0.008, 0.006, "brass")
	if str(p.get("stripe", "")) != "":
		k.box(Vector3(0, h * 0.5 - 0.05, -0.0065), Vector3(w * 0.9, 0.05, 0.002), str(p["stripe"]), Vector3.ZERO, 0)
	if not is_inside_tree() and get_parent() == null and crucible == null:
		return   # layout only: no labels
	var ink: Color = _col(p.get("ink"), Color(0.12, 0.1, 0.09))
	var title: String = str(p.get("title", ""))
	var body: String = str(p.get("body", ""))
	var g: Node3D = Node3D.new()
	g.name = "Notice%d" % _labels
	_labels += 1
	g.transform = k.frame
	add_child(g)
	_notices.append(g)
	if title != "":
		var t: Label3D = _label(g, title, Vector3(0, h * 0.34, -0.008), int(p.get("title_px", 40)), ink, 0.0016, w * 0.92)
		t.font_size = int(p.get("title_px", 40))
	if body != "":
		_label(g, body, Vector3(0, h * 0.34 - 0.07 - float(p.get("body_drop", 0.0)), -0.008), int(p.get("body_px", 24)), ink, 0.0012, w * 0.9, true)


func _label(parent: Node3D, text: String, pos: Vector3, px: int, ink: Color, pixel: float, width_m: float, top: bool = false) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = ink
	l.outline_size = 0
	l.double_sided = false
	l.width = width_m / pixel
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if top:
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = pos
	l.rotation.y = PI
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SurfaceText.apply(l, SurfaceText.PRINT)   # T-247
	parent.add_child(l)
	return l


## A hanging chain from `at` down `len` metres (links as small alternating boxes), an optional hook.
func _chain(k: Kit, p: Dictionary, mat: String) -> void:
	var length: float = float(p.get("len", 1.0))
	var n: int = int(length / 0.07)
	for i: int in n:
		var y: float = -0.035 - i * 0.07
		var r: float = 0.0 if i % 2 == 0 else 90.0
		k.box(Vector3(0, y, 0), Vector3(0.035, 0.08, 0.012), mat, Vector3(0, r, 0), 0)
	if bool(p.get("hook", true)):
		k.box(Vector3(0, -length - 0.06, 0), Vector3(0.02, 0.1, 0.02), mat, Vector3.ZERO, 0)
		k.box(Vector3(0.03, -length - 0.11, 0), Vector3(0.07, 0.02, 0.02), mat, Vector3.ZERO, 0)


# ------------------------------------------------------------------ T-254: the housing

## The housing round the machine (see the header). Everything is in the machine's frame and sized from `probe`.
func _surround(k: Kit, s: Dictionary) -> void:
	var style: String = str(s.get("style", "brick"))
	var st: Dictionary = STYLES.get(style, STYLES["brick"])
	var body: String = str(s.get("mat", st["body"]))
	var trim: String = str(s.get("trim", st["trim"]))
	var band: String = str(s.get("band", st["band"]))
	var z0: float = float(s.get("z0", 0.62))
	var back: float = float(probe.get("back", 1.3))
	var ceil_y: float = float(probe.get("ceil", 3.2))
	var roofed: bool = ceil_y < 90.0
	var top_max: float = float(s.get("top", 4.4))
	var housed: bool = style != "cradle" and back - z0 <= float(s.get("max_depth", 2.6)) and back - z0 > 0.12
	var w: float = float(s.get("w", 1.55))
	var w_back: float = w
	var z1: float = back + 0.05
	var zm: float = z1   # where the housing widens (behind the machine's plinth), when it does
	if housed:
		# as wide as stays off the navmesh: beside the machine first, then (where the wall is further back than the
		# plinth) the part behind it, which may be wider: a shoulder
		var wide: float = float(s.get("w_back", w))
		var z_back: float = float(s.get("z_back", PLINTH_BACK))
		var split: bool = z1 > z_back + 0.15
		var zf: float = z_back if split else z1
		var fit: float = -1.0
		for try_w: float in [w, 1.42, 1.3, 1.16, 1.02]:
			if try_w <= w + 0.001 and _fits_nav(Rect2(-try_w - NAV_MARGIN, z0 - NAV_MARGIN, (try_w + NAV_MARGIN) * 2.0, zf - z0 + NAV_MARGIN)):
				fit = try_w
				break
		if fit < 0.0:
			housed = false
		else:
			w = fit
			w_back = fit
			if split:
				var fit_b: float = -1.0
				for try_b: float in [wide, 1.9, 1.7, 1.55, 1.42, 1.3, 1.16, 1.02]:
					if try_b <= wide + 0.001 and try_b >= w - 0.001 and _fits_nav(Rect2(-try_b - NAV_MARGIN, zf - NAV_MARGIN, (try_b + NAV_MARGIN) * 2.0, z1 - zf + NAV_MARGIN)):
						fit_b = try_b
						break
				if fit_b < 0.0:
					housed = false
				else:
					w_back = fit_b
					zm = zf if fit_b > w + 0.01 else z1
	if not housed:
		w = minf(w, 1.02)
		w_back = w
		z1 = PLINTH_BACK
		zm = z1
	if housed and _wall_mat != null and bool(s.get("match_wall", true)):
		# built of what the wall is built of: the very material the wall behind is drawn with, so the two are one mass
		body = "wall"
		if Mats.get_mat(trim) == _wall_mat:
			trim = str(st["body"])
	var meets: bool = roofed and ceil_y <= top_max
	var top: float = ceil_y + 0.06 if meets else minf(top_max, 4.2)
	sur = {"w": w, "w_back": w_back, "zm": zm, "z0": z0, "z1": z1, "top": top, "housed": housed, "meets_ceiling": meets, "style": style}
	var zc: float = (z0 + zm) * 0.5
	var dz: float = zm - z0
	# the foundation the plinth is keyed into: one slab, flat, a hand wider than everything that stands on it
	var fw: float = maxf(w, 1.3) + 0.12
	k.box(Vector3(0, 0.02, (z1 - 1.22) * 0.5), Vector3(fw * 2.0, 0.04, z1 + 1.22), trim, Vector3.ZERO, 0)
	if style != "cradle":
		# the mass itself, from the machine's rear third into the wall and (where the room has one near) the ceiling
		k.box(Vector3(0, top * 0.5, zc), Vector3(w * 2.0, top, dz), body, Vector3.ZERO, 1)
		if zm < z1 - 0.01:   # the shoulder: the wider mass against the wall, with its own base and head courses
			var bc: float = (zm + z1) * 0.5
			k.box(Vector3(0, top * 0.5, bc), Vector3(w_back * 2.0, top, z1 - zm), body, Vector3.ZERO, 1)
			k.box(Vector3(0, 0.17, bc - 0.03), Vector3(w_back * 2.0 + 0.1, 0.34, z1 - zm + 0.06), trim, Vector3.ZERO, 0)
			if meets:
				k.box(Vector3(0, top - 0.13, bc - 0.04), Vector3(w_back * 2.0 + 0.14, 0.14, z1 - zm + 0.08), trim, Vector3.ZERO, 0)
		k.box(Vector3(0, 0.17, zc - 0.03), Vector3(w * 2.0 + 0.1, 0.34, dz + 0.06), trim, Vector3.ZERO, 0)
		if meets:
			k.box(Vector3(0, top - 0.13, zc - 0.04), Vector3(w * 2.0 + 0.14, 0.14, dz + 0.08), trim, Vector3.ZERO, 0)
		else:
			# a stepped cap; a chimney on to the ceiling when there is one, a pot when there is none
			k.box(Vector3(0, top + 0.05, zc - 0.03), Vector3(w * 2.0 + 0.12, 0.1, dz + 0.06), trim, Vector3.ZERO, 0)
			k.box(Vector3(0, top + 0.19, zc), Vector3(w * 2.0 - 0.36, 0.18, maxf(0.2, dz - 0.16)), body, Vector3.ZERO, 0)
			var cw: float = minf(0.95, w * 2.0 - 0.6)
			var cd: float = clampf(dz - 0.2, 0.22, 0.7)
			var cz: float = zm - cd * 0.5 - 0.02
			var stack_top: float = ceil_y + 0.05 if (roofed and ceil_y < 16.0) else top + 1.0
			if not bool(s.get("stack", true)):
				pass
			elif style == "brick":
				k.box(Vector3(0, (top + 0.28 + stack_top) * 0.5, cz), Vector3(cw, stack_top - top - 0.28, cd), body, Vector3.ZERO, 1)
				k.box(Vector3(0, stack_top - 0.12, cz), Vector3(cw + 0.1, 0.12, cd + 0.1), trim, Vector3.ZERO, 0)
			else:
				# a plate stack with flanged joints, stayed to the housing
				var sr: float = minf(0.2, cd * 0.5)
				k.seg(Vector3(0, top + 0.26, cz), Vector3(0, stack_top, cz), sr, "loco_black", 1)
				var jy: float = top + 0.5
				while jy < stack_top - 0.2:
					k.cyl(Vector3(0, jy, cz), sr + 0.025, 0.05, trim, Vector3.ZERO, 0)
					jy += 1.4
				for sx0: float in [-1.0, 1.0]:
					k.seg(Vector3(sx0 * (w - 0.1), top + 0.28, cz), Vector3(sx0 * sr * 0.7, minf(stack_top - 0.3, top + 1.5), cz), 0.012, "steel", 0)
				if not (roofed and ceil_y < 16.0):
					k.cyl(Vector3(0, stack_top + 0.16, cz), sr + 0.14, 0.03, "loco_black", Vector3.ZERO, 0)
		if bool(s.get("quoins", st["quoins"])):
			var qy: float = 0.42
			var qi: int = 0
			while qy < top - 0.42:
				var long_q: bool = qi % 2 == 0
				for sx: float in [-1.0, 1.0]:
					k.box(Vector3(sx * (w - (0.17 if long_q else 0.11)), qy + 0.1, z0 - 0.012), Vector3(0.34 if long_q else 0.22, 0.2, 0.05), trim, Vector3.ZERO, 0)
					k.box(Vector3(sx * (w + 0.012), qy + 0.1, z0 + (0.1 if long_q else 0.16)), Vector3(0.05, 0.2, 0.2 if long_q else 0.32), trim, Vector3.ZERO, 0)
				qy += 0.42
				qi += 1
		if bool(s.get("seams", st["seams"])):
			# plate: seam strips with rivets on the flanks and across the top, a kick plate
			var n_seam: int = maxi(2, int(round(w * 2.0 / 0.62)))
			for i: int in n_seam + 1:
				var x: float = -w + w * 2.0 * float(i) / float(n_seam)
				if absf(x) < 0.9 and top < 3.0:
					continue
				var y0: float = 0.34 if absf(x) >= 1.0 else 2.45
				k.box(Vector3(x, (y0 + top) * 0.5, z0 - 0.008), Vector3(0.07, top - y0, 0.016), trim, Vector3.ZERO, 0)
				var ry: float = y0 + 0.15
				while ry < top - 0.1:
					k.box(Vector3(x, ry, z0 - 0.02), Vector3(0.026, 0.026, 0.012), band, Vector3(0, 0, 45), 0)
					ry += 0.3
			for by: float in [0.42, minf(top - 0.2, 2.55)]:
				k.box(Vector3(0, by, z0 - 0.01), Vector3(w * 2.0, 0.08, 0.02), trim, Vector3.ZERO, 0)
		if bool(s.get("arch", st["arch"])):
			# a relieving arch of dressed stone over the firebox, proud of the face
			var b: float = minf(0.95, top - 0.4 - 1.9)
			if b >= 0.45:
				var a: float = minf(1.24, w - 0.2)
				for i2: int in 11:
					var th: float = PI * float(i2) / 10.0
					var key_st: bool = i2 == 5
					k.box(Vector3(cos(th) * a, 1.9 + sin(th) * b, z0 - 0.03), Vector3(0.2 if not key_st else 0.24, 0.3 if not key_st else 0.38, 0.1 if not key_st else 0.14),
						trim, Vector3(0, 0, rad_to_deg(atan2(sin(th) * a, cos(th) * b)) - 90.0), 0)
				for sx2: float in [-1.0, 1.0]:   # the imposts it springs from
					k.box(Vector3(sx2 * a, 1.72, z0 - 0.035), Vector3(0.3, 0.12, 0.11), trim, Vector3.ZERO, 0)
		if style == "concrete":
			# board-marked concrete: lift lines, a steel lintel over the firebox, a chamfered kerb
			var ly: float = 0.9
			while ly < top - 0.3:
				k.box(Vector3(0, ly, z0 - 0.006), Vector3(w * 2.0, 0.025, 0.012), trim, Vector3.ZERO, 0)
				ly += 0.62
			k.box(Vector3(0, 2.62, z0 - 0.035), Vector3(minf(2.7, w * 2.0 - 0.1), 0.18, 0.09), band, Vector3.ZERO, 0)
			for bx: float in [-1.1, -0.55, 0.0, 0.55, 1.1]:
				if absf(bx) < w - 0.1:
					k.box(Vector3(bx, 2.62, z0 - 0.085), Vector3(0.05, 0.05, 0.02), "steel", Vector3.ZERO, 0)
		# the hood: the housing corbels out over the firebox course by course and goes up into the ceiling, the flue
		# inside it (all of it over head height: nothing to walk into)
		var hood_z: float = z0
		if bool(s.get("hood", true)) and meets:
			var step_h: float = 0.14
			var n_steps: int = clampi(int(floor((top - HOOD_Y) / step_h)), 0, 5)
			if n_steps >= 2:
				var reach: float = minf(float(s.get("hood_reach", 1.3)), float(n_steps) * 0.3)
				var hw: float = minf(w - 0.06, 1.36)
				for i3: int in n_steps:
					var y_lo: float = HOOD_Y + float(i3) * step_h
					var zf2: float = z0 - reach * float(i3 + 1) / float(n_steps)
					k.box(Vector3(0, (y_lo + top) * 0.5, (zf2 + z0) * 0.5), Vector3(hw * 2.0, top - y_lo, z0 - zf2), body, Vector3.ZERO, 1 if i3 == n_steps - 1 else 0)
					# a dressed course under each step's lip
					k.box(Vector3(0, y_lo + 0.025, zf2 + 0.05), Vector3(hw * 2.0 + 0.05, 0.05, 0.12), trim, Vector3.ZERO, 0)
				hood_z = z0 - reach
				sur["hood_z"] = hood_z
				sur["hood_y"] = HOOD_Y + float(n_steps - 1) * step_h
				sur["hood_w"] = hw
		if bool(s.get("straps", true)):
			# iron straps round the drum, bolted to the housing with tie plates
			for sy: float in [1.42, 1.74]:
				k.box(Vector3(0, sy, z0 - 0.014), Vector3(w * 2.0 - 0.14, 0.07, 0.028), band, Vector3.ZERO, 0)
				for sx3: float in [-1.0, 1.0]:
					k.box(Vector3(sx3 * (w - 0.2), sy, z0 - 0.03), Vector3(0.17, 0.17, 0.03), band, Vector3(0, 0, 45), 0)
					k.box(Vector3(sx3 * (w - 0.2), sy, z0 - 0.052), Vector3(0.045, 0.045, 0.02), "steel", Vector3.ZERO, 0)
		if bool(s.get("gauges", true)) and w >= 1.28:
			for gy: float in [1.62, 1.28]:
				var gp: Vector3 = Vector3(-(w - 0.17), gy, z0 - 0.02)
				k.cyl_axis(gp, Vector3(0, 0, -1), 0.105, 0.05, "brass")
				k.cyl_axis(gp + Vector3(0, 0, -0.027), Vector3(0, 0, -1), 0.088, 0.006, "gauge_face")
			k.seg(Vector3(-(w - 0.17), 1.1, z0 - 0.02), Vector3(-(w - 0.17), 0.36, z0 - 0.02), 0.014, "copper", 0)
		# the fire irons against the flank, where the stoker left them
		var tx: float = w - 0.3
		k.seg(Vector3(tx, 0.05, z0 - 0.16), Vector3(tx + 0.06, 1.12, z0 - 0.03), 0.011, "steel", 0)
		k.seg(Vector3(tx - 0.07, 0.05, z0 - 0.18), Vector3(tx - 0.02, 1.02, z0 - 0.03), 0.011, "steel", 0)
		k.box(Vector3(tx - 0.07, 0.07, z0 - 0.19), Vector3(0.12, 0.012, 0.09), "steel", Vector3(-12, 20, 0), 0)
	# the flue: on to the ceiling (a collar where it goes through), or back into the housing when the room is tall
	var flue: String = str(s.get("flue", ""))
	if flue == "":
		if roofed and ceil_y <= FLUE_TOP + 0.04:
			flue = "collar"
		elif roofed and ceil_y <= 5.6 and (meets or style == "cradle"):
			flue = "up"
		elif style != "cradle":
			flue = "elbow"
		else:
			flue = "cap"
	match flue:
		"collar":
			k.cyl(Vector3(0, ceil_y - 0.035, FLUE_Z), 0.37, 0.07, band, Vector3.ZERO, 0)
			k.cyl(Vector3(0, ceil_y - 0.09, FLUE_Z), 0.3, 0.05, "loco_black", Vector3.ZERO, 0)
		"up":
			k.seg(Vector3(0, FLUE_TOP - 0.06, FLUE_Z), Vector3(0, ceil_y + 0.04, FLUE_Z), FLUE_R, "loco_black", 1)
			var fy: float = FLUE_TOP + 0.02
			while fy < ceil_y - 0.2:
				k.cyl(Vector3(0, fy, FLUE_Z), FLUE_R + 0.022, 0.045, band, Vector3.ZERO, 0)
				fy += 0.7
			k.cyl(Vector3(0, ceil_y - 0.035, FLUE_Z), 0.37, 0.07, band, Vector3.ZERO, 0)
		"elbow":
			var ey: float = minf(top - 0.5, FLUE_TOP + 0.62)
			k.seg(Vector3(0, FLUE_TOP - 0.06, FLUE_Z), Vector3(0, ey - 0.22, FLUE_Z), FLUE_R, "loco_black", 1)
			k.ball(Vector3(0, ey - 0.22, FLUE_Z), Vector3.ONE * FLUE_R * 2.08, "loco_black", 0)
			k.seg(Vector3(0, ey - 0.22, FLUE_Z), Vector3(0, ey, z0 + 0.06), FLUE_R, "loco_black", 1)
			k.cyl_axis(Vector3(0, ey, z0 - 0.015), Vector3(0, 0.35, 1.0), 0.36, 0.05, band)
			k.cyl(Vector3(0, FLUE_TOP + 0.02, FLUE_Z), FLUE_R + 0.022, 0.045, band, Vector3.ZERO, 0)
		"cap":
			k.cyl(Vector3(0, FLUE_TOP + 0.03, FLUE_Z), FLUE_R + 0.03, 0.05, band, Vector3.ZERO, 0)
			k.cyl(Vector3(0, FLUE_TOP + 0.2, FLUE_Z), 0.4, 0.03, "loco_black", Vector3.ZERO, 0)
			for ca: int in 3:
				var an: float = TAU * float(ca) / 3.0
				k.seg(Vector3(cos(an) * 0.2, FLUE_TOP, FLUE_Z + sin(an) * 0.2), Vector3(cos(an) * 0.3, FLUE_TOP + 0.2, FLUE_Z + sin(an) * 0.3), 0.012, band, 0)
	# what the fire leaves on the floor: ash raked out of the mouth, clinker, a few dead coals (all under 6 cm)
	if bool(s.get("ash", true)):
		k.ball(Vector3(0.46, 0.032, -1.17), Vector3(0.36, 0.05, 0.17), "coal", 0)
		for cl: Array in [[0.74, -1.33, 0.07], [0.16, -1.38, 0.05], [-0.52, -1.3, 0.06], [0.95, -1.18, 0.045], [-0.05, -1.5, 0.04]]:
			k.ball(Vector3(float(cl[0]), 0.057 - float(cl[2]) * 0.275, float(cl[1])), Vector3(float(cl[2]) * 1.5, float(cl[2]) * 0.55, float(cl[2]) * 1.2), "rust", 0)


## What the kit cannot fold into the room's meshes: the soot (its own alpha material), the gauges' needles (they
## move), the housing's collider, the wisp of steam at the flue.
func _surround_extras(s: Dictionary) -> void:
	if sur.is_empty():
		return
	var w: float = float(sur["w"])
	var z0: float = float(sur["z0"])
	var z1: float = float(sur["z1"])
	var top: float = float(sur["top"])
	var style: String = str(sur["style"])
	var ceil_y: float = float(probe.get("ceil", 99.0))
	var roofed: bool = ceil_y < 90.0
	_soot_k = float(s.get("soot", 0.62))
	if _soot_k > 0.0:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if sur.has("hood_z"):
			# up the hood's lip, where the smoke rolls out from under it
			var hz: float = float(sur["hood_z"]) - 0.006
			var hw: float = float(sur["hood_w"])
			_quad(st, Vector3(-hw, float(sur["hood_y"]) - 0.1, hz), Vector3(hw, float(sur["hood_y"]) - 0.1, hz), Vector3(hw, top - 0.02, hz), Vector3(-hw, top - 0.02, hz))
		elif style != "cradle":
			# up the face of the housing over the firebox
			var fx0: float = minf(w - 0.3, 1.1)
			_quad(st, Vector3(-fx0, 2.0, z0 - 0.005), Vector3(fx0, 2.0, z0 - 0.005), Vector3(fx0, top - 0.02, z0 - 0.005), Vector3(-fx0, top - 0.02, z0 - 0.005))
		if roofed and ceil_y < 5.2:
			# under the ceiling over the mouth and the flue
			var cy: float = ceil_y - 0.018
			_quad(st, Vector3(-1.9, cy, -1.9), Vector3(1.9, cy, -1.9), Vector3(1.9, cy, z0), Vector3(-1.9, cy, z0))
		# on the floor in front of the mouth
		_quad(st, Vector3(-1.15, 0.047, -2.05), Vector3(1.15, 0.047, -2.05), Vector3(1.15, 0.047, -0.95), Vector3(-1.15, 0.047, -0.95))
		st.generate_normals()
		_soot_mat = CrateFx.soot_mat(_soot_k, float(hash(map_key) % 97))
		_soot = MeshInstance3D.new()
		_soot.name = "Soot"
		_soot.mesh = st.commit()
		_soot.material_override = _soot_mat
		_soot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_soot)
	if style != "cradle" and bool(s.get("gauges", true)) and w >= 1.28:
		var i: int = 0
		for gy: float in [1.62, 1.28]:
			var pivot: Node3D = Node3D.new()
			pivot.name = "Needle%d" % i
			pivot.position = Vector3(-(w - 0.17), gy, z0 - 0.052)
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.008, 0.075, 0.004)
			mi.mesh = bm
			mi.position = Vector3(0, 0.03, 0)
			mi.material_override = Mats.get_mat("red_paint")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(mi)
			pivot.rotation.z = 2.0
			add_child(pivot)
			_needles.append([pivot, float(i) * 1.7])
			i += 1
	if bool(sur["housed"]) and crucible != null:
		# solid where it is drawn, on the Crucible body's own layers (a player, a shot); never part of a path: it is
		# only as wide as stays off the navmesh
		_sur_body = StaticBody3D.new()
		_sur_body.name = "SurroundBody"
		_sur_body.collision_layer = 1 | (1 << 8)
		_sur_body.collision_mask = 0
		var bh: float = minf(top, 4.3)
		var zm: float = float(sur["zm"])
		for part: Array in [[w, z0, zm], [float(sur["w_back"]), zm, z1 - 0.04]]:
			if float(part[2]) - float(part[1]) < 0.05:
				continue
			var cs: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(float(part[0]) * 2.0, bh, float(part[2]) - float(part[1]))
			cs.shape = box
			cs.position = Vector3(0, bh * 0.5, (float(part[1]) + float(part[2])) * 0.5)
			_sur_body.add_child(cs)
		add_child(_sur_body)
	if crucible != null and bool(s.get("wisp", true)):
		_wisp = CPUParticles3D.new()
		_wisp.name = "FlueWisp"
		_wisp.amount = 5
		_wisp.lifetime = 2.8
		_wisp.position = Vector3(0, minf(FLUE_TOP + 0.1, (ceil_y if roofed else 99.0) - 0.22), FLUE_Z - 0.3)
		_wisp.direction = Vector3(0, 0.6, -1.0)
		_wisp.spread = 30.0
		_wisp.initial_velocity_min = 0.08
		_wisp.initial_velocity_max = 0.2
		_wisp.gravity = Vector3(0, 0.12, 0)
		_wisp.scale_amount_min = 0.5
		_wisp.scale_amount_max = 1.0
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(0.85, 0.85, 0.88, 0.0), Color(0.85, 0.85, 0.88, 0.16), Color(0.8, 0.8, 0.84, 0.0)])
		_wisp.color_ramp = g
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = _puff_tex()
		sm.disable_receive_shadows = true
		q.material = sm
		_wisp.mesh = q
		_wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wisp.emitting = false
		add_child(_wisp)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var pts: Array = [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [c, Vector2(1, 0)], [d, Vector2(0, 0)]]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(pts[i][1])
		st.add_vertex(pts[i][0])


# ------------------------------------------------------------------ lights, sound, fx

## role "key" (the machine's key light: may cast; the room's only shadowed light), "work" (warm, flickers with the
## forge), "marke" (violet, breathes with the inlays).
func _light(l: Dictionary) -> void:
	var kind: String = str(l.get("kind", "omni"))
	var li: Light3D
	if kind == "spot":
		var s: SpotLight3D = SpotLight3D.new()
		s.spot_range = float(l.get("range", 7.0))
		s.spot_angle = float(l.get("angle", 32.0))
		s.spot_angle_attenuation = float(l.get("soft", 1.4))
		s.spot_attenuation = float(l.get("atten", 0.8))
		li = s
	else:
		var o: OmniLight3D = OmniLight3D.new()
		o.omni_range = float(l.get("range", 5.0))
		o.omni_attenuation = float(l.get("atten", 1.2))
		li = o
	var role: String = str(l.get("role", "work"))
	li.name = "CrucibleRoom_%s_%d" % [role.capitalize(), lights.size()]
	li.light_color = _col(l.get("color"), Color(1.0, 0.72, 0.45) if role != "marke" else VIOLET)
	li.light_energy = float(l.get("energy", 1.0))
	li.shadow_enabled = bool(l.get("shadow", false)) and role == "key"
	li.light_specular = float(l.get("specular", 0.5))
	li.light_volumetric_fog_energy = float(l.get("fog", 0.5))
	li.set_meta("zone", str(data.get("zone", "")))
	_place_light(li, l)
	add_child(li)
	lights.append([li, li.light_energy, role])
	_light_src.append([li, l])


func _place_light(li: Light3D, l: Dictionary) -> void:
	var pos: Vector3 = _p3(l.get("at"), Vector3(0, 2.5, -1.5))
	var bs: Basis = Basis.IDENTITY
	if l.has("aim"):   # in the room's own frame (look_at would read it as global)
		var dir: Vector3 = _p3(l["aim"]) - pos
		if dir.length() > 0.01:
			bs = Basis.looking_at(dir, Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD)
	li.transform = Transform3D(bs, pos)


func _sound(s: Dictionary) -> void:
	var key: String = str(s.get("key", "crucible_hum"))
	_sound_src = s
	if s.is_empty() or not AudioDirector.has_sound(key):
		return
	_hum_db = float(s.get("db", -6.0))
	hum = AudioDirector.make_loop_3d(key, self, _hum_db)
	if hum == null:
		return
	hum.position = _p3(s.get("at"), Vector3(0, 1.2, 0))
	hum.unit_size = float(s.get("unit_size", hum.unit_size))
	hum.max_distance = float(s.get("max_distance", hum.max_distance))
	hum.play()


func _fx(f: Dictionary) -> void:
	var kind: String = str(f.get("kind", "steam"))
	var pt: CPUParticles3D = CPUParticles3D.new()
	pt.name = "Fx_%s_%d" % [kind, fx.size()]
	pt.position = _p3(f.get("at"), Vector3(0, 2.0, 0))
	pt.emitting = false
	pt.one_shot = true
	pt.local_coords = false
	var dir: Vector3 = _p3(f.get("dir"), Vector3.UP).normalized()
	pt.direction = dir
	var k: float = 0.5 if GLSettings.is_compat() else 1.0
	if kind == "sparks":
		pt.amount = maxi(8, int(float(f.get("amount", 36)) * k))
		pt.lifetime = 0.9
		pt.explosiveness = 0.85
		pt.spread = float(f.get("spread", 50.0))
		pt.initial_velocity_min = 2.0
		pt.initial_velocity_max = 4.5
		pt.gravity = Vector3(0, -9.0, 0)
		pt.particle_flag_align_y = true
		pt.scale_amount_min = 0.6
		pt.scale_amount_max = 1.2
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.012, 0.07, 0.012)
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = _col(f.get("color"), Color(1.0, 0.72, 0.35))
		sm.emission_enabled = true
		sm.emission = sm.albedo_color
		sm.emission_energy_multiplier = 4.0
		bm.material = sm
		pt.mesh = bm
	else:
		pt.amount = maxi(6, int(float(f.get("amount", 20)) * k))
		pt.lifetime = 1.8
		pt.explosiveness = 0.55
		pt.spread = float(f.get("spread", 18.0))
		pt.initial_velocity_min = 1.2
		pt.initial_velocity_max = 2.4
		pt.gravity = Vector3(0, 0.5, 0)
		pt.damping_min = 1.0
		pt.damping_max = 2.0
		pt.scale_amount_min = 0.5
		pt.scale_amount_max = 1.0
		var c: Curve = Curve.new()
		c.add_point(Vector2(0.0, 0.3))
		c.add_point(Vector2(0.4, 1.0))
		c.add_point(Vector2(1.0, 1.4))
		pt.scale_amount_curve = c
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.9, 0.9, 0.92, 0.55))
		g.set_color(1, Color(0.8, 0.82, 0.86, 0.0))
		pt.color_ramp = g
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.45, 0.45)
		var sm2: StandardMaterial3D = StandardMaterial3D.new()
		sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm2.vertex_color_use_as_albedo = true
		sm2.albedo_texture = _puff_tex()
		sm2.disable_receive_shadows = true
		q.material = sm2
		pt.mesh = q
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.visible = false
	add_child(pt)
	_fx_src.append([pt, f])
	fx.append([pt, PackedStringArray(f.get("on", ["started"] if kind == "steam" else ["ready"])), -1.0, str(f.get("sound", "crucible_hiss" if kind == "steam" else ""))])


static func _puff_tex() -> Texture2D:
	if not _unit.has("puff"):
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.width = 32
		gt.height = 32
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = g
		_unit["puff"] = gt
	return _unit["puff"]


func fire(event: String) -> int:
	var n: int = 0
	for e: Array in fx:
		if (e[1] as PackedStringArray).has(event):
			var pt: CPUParticles3D = e[0]
			pt.visible = true
			pt.restart()
			pt.emitting = true
			e[2] = _t + pt.lifetime * 2.0 + 0.5
			n += 1
			if str(e[3]) != "" and AudioDirector.has_sound(str(e[3])):
				AudioDirector.play_3d(str(e[3]), pt.global_position, -4.0, 0.08)
	return n


func _on_started(_pid: int, _w: StringName) -> void:
	_forge_t = 0.0
	_flare = maxf(_flare, 0.5)
	fire("started")


func _on_ready(_w: StringName) -> void:
	_forge_t = -1.0
	_flare = 1.0
	fire("ready")


func _on_expired(_w: StringName) -> void:
	_forge_t = -1.0
	fire("expired")


func _on_acquired(_pid: int, _w: StringName, source: StringName) -> void:
	if source == &"crucible":
		_flare = maxf(_flare, 0.6)
		fire("taken")


## Where the room's glow and hum stand now: 0 unpowered .. 1 idle .. up to 3 at the end of a forge.
func level() -> float:
	if crucible == null or not is_instance_valid(crucible):
		return 1.0
	if not crucible.is_powered():
		return 0.12
	match crucible.phase:
		Crucible.Phase.FORGING:
			var k: float = clampf(maxf(_forge_t, 0.0) / maxf(crucible.forge_seconds, 0.1), 0.0, 1.0)
			return 1.2 + 1.8 * k
		Crucible.Phase.OFFERED:
			return 1.8
	return 1.0


func _process(delta: float) -> void:
	_t += delta
	if _forge_t >= 0.0:
		_forge_t += delta
	_flare = maxf(0.0, _flare - delta * 0.9)
	var lv: float = level()
	var forging: bool = crucible != null and is_instance_valid(crucible) and crucible.phase == Crucible.Phase.FORGING
	var breathe: float = 1.0 + 0.18 * sin(_t * 1.3) if not forging else 1.0 + 0.22 * sin(_t * 17.0)
	if marke_mat != null:
		marke_mat.emission_energy_multiplier = _marke_e * lv * breathe * (1.0 + _flare * 2.0)
	for e: Array in lights:
		var li: Light3D = e[0]
		var base: float = float(e[1])
		match str(e[2]):
			"key":
				li.light_energy = base * (0.3 if lv < 0.5 else 1.0) * (1.0 + 0.35 * (lv - 1.0) + _flare * 1.2)
			"marke":
				li.light_energy = base * lv * breathe * (1.0 + _flare * 1.5)
			_:
				var dip: float = 1.0
				if forging and _rng.randf() < 0.08:
					dip = _rng.randf_range(0.55, 0.85)
				li.light_energy = base * (0.6 if lv < 0.5 else 1.0) * dip
	# T-254: the gauges' needles lie on their pins cold, tremble at idle and climb with the forge; the steam stops
	# with the fire
	for nd: Array in _needles:
		var pivot: Node3D = nd[0]
		var want: float = 2.0 if lv < 0.5 else (0.75 - 0.95 * (lv - 1.0)) + 0.05 * sin(_t * (5.0 + float(nd[1])) + float(nd[1]) * 2.0) + (0.1 * sin(_t * 31.0) if forging else 0.0)
		pivot.rotation.z = lerp_angle(pivot.rotation.z, want, clampf(delta * 3.0, 0.0, 1.0))
	if _wisp != null and _wisp.emitting != (lv >= 0.5):
		_wisp.emitting = lv >= 0.5
	if hum != null:
		hum.volume_db = _hum_db + (-14.0 if lv < 0.5 else 4.0 * (lv - 1.0)) + _flare * 3.0
		hum.pitch_scale = 1.0 + 0.05 * maxf(0.0, lv - 1.0)
	for e2: Array in fx:
		if float(e2[2]) >= 0.0 and _t > float(e2[2]):
			(e2[0] as CPUParticles3D).visible = false
			e2[2] = -1.0


# ================================================================== the kit builder

## Folds primitives straight into one SurfaceTool per material (no intermediate nodes; the mesh casts a shadow when
## any big part in it does), and keeps the local AABB of every primitive of the piece being built.
class Kit:
	extends RefCounted
	var frame: Transform3D = Transform3D.IDENTITY
	var buckets: Dictionary = {}   # "mat|shadow" -> {st, mat, shadow}
	## Small-part materials folded into a neighbour so a room stays a dozen draw calls (they read the same at arm's length).
	const ALIAS: Dictionary = {"walnut": "furniture", "beam": "furniture", "linen": "paper", "olive_drab": "olive_steel", "rust": "iron"}
	var marke: Material
	var custom: Dictionary = {}    # key -> Material that is not a Mats key (T-254: "wall", the probed wall's own)
	var parts: Array = []          # the AABB (machine frame) of every primitive of the piece being built
	var _ab: AABB
	var _has: bool = false

	func _init(marke_mat: Material) -> void:
		marke = marke_mat

	func begin() -> void:
		_has = false
		_ab = AABB()
		parts = []

	func end() -> AABB:
		return _ab if _has else AABB(frame.origin, Vector3.ZERO)

	func _mat(key: String) -> Material:
		if custom.has(key):
			return custom[key]
		return marke if key == "marke" else Mats.get_mat(key)

	func _add(mesh: Mesh, xf: Transform3D, key: String, shadow: int) -> void:
		var full: Transform3D = frame * xf
		var ab: AABB = full * mesh.get_aabb()
		parts.append(ab)
		if _has:
			_ab = _ab.merge(ab)
		else:
			_ab = ab
			_has = true
		var k2: String = str(ALIAS.get(key, key))
		var m: Material = _mat(k2)
		if m == null:
			m = Mats.get_mat("iron")
		var cast: bool = shadow == 1 or (shadow == -1 and maxf(ab.size.x, maxf(ab.size.y, ab.size.z)) > 0.6 and key != "marke")
		var bk: String = str(m.get_instance_id())   # one mesh per material: it casts when any big part in it does
		if not buckets.has(bk):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[bk] = {"st": st, "mat": m, "shadow": false, "key": k2}
		if cast:
			buckets[bk]["shadow"] = true
		(buckets[bk]["st"] as SurfaceTool).append_from(mesh, 0, full)

	static func _rot(deg: Vector3) -> Basis:
		return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))

	func box(c: Vector3, s: Vector3, key: String, rot: Vector3 = Vector3.ZERO, shadow: int = -1) -> void:
		_add(CrucibleRoom._unit_mesh("box"), Transform3D(_rot(rot) * Basis.from_scale(s), c), key, shadow)

	func cyl(c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO, shadow: int = -1) -> void:
		_add(CrucibleRoom._unit_mesh("cyl" if r > 0.08 else "cyl_s"), Transform3D(_rot(rot) * Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), c), key, shadow)

	func ball(c: Vector3, s: Vector3, key: String, shadow: int = -1) -> void:
		_add(CrucibleRoom._unit_mesh("ball"), Transform3D(Basis.from_scale(s), c), key, shadow)

	## A cylinder of radius r from a to b.
	func seg(a: Vector3, b: Vector3, r: float, key: String, shadow: int = -1) -> void:
		var d: Vector3 = b - a
		var l: float = d.length()
		if l < 0.001:
			return
		var y: Vector3 = d / l
		var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z: Vector3 = x.cross(y).normalized()
		var bs: Basis = Basis(x * r * 2.0, y * l, z * r * 2.0)
		_add(CrucibleRoom._unit_mesh("cyl" if r > 0.08 else "cyl_s"), Transform3D(bs, (a + b) * 0.5), key, shadow if shadow != -1 else (1 if r >= 0.05 and l > 0.6 else 0))

	## A disc of radius r and thickness t at c, its axis along `axis`.
	func cyl_axis(c: Vector3, axis: Vector3, r: float, t: float, key: String) -> void:
		var ax: Vector3 = axis.normalized()
		seg(c - ax * t * 0.5, c + ax * t * 0.5, r, key, 0)

	func commit(parent: Node3D) -> int:
		var n: int = 0
		for bk: String in buckets:
			var b: Dictionary = buckets[bk]
			var st: SurfaceTool = b["st"]
			var mesh: ArrayMesh = st.commit()
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Room_%s%s" % [str(b["key"]), "_cast" if bool(b["shadow"]) else ""]
			mi.mesh = mesh
			mi.material_override = b["mat"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(b["shadow"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			n += 1
		return n


static func _unit_mesh(kind: String) -> Mesh:
	if _unit.has(kind):
		return _unit[kind]
	var m: Mesh
	match kind:
		"box":
			var b: BoxMesh = BoxMesh.new()
			b.size = Vector3.ONE
			m = b
		"cyl", "cyl_s":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 14 if kind == "cyl" else 8
			c.rings = 1
			m = c
		_:
			var s: SphereMesh = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 10
			s.rings = 6
			m = s
	_unit[kind] = m
	return m
