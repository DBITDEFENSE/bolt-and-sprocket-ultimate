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

const CONFIG: String = "res://data/gravelight/crucible_rooms.json"
const VIOLET: Color = Color(0.55, 0.2, 1.0)
const FLAT_M: float = 0.06
const OVERHEAD_M: float = 2.05
## The approach in the machine's frame: the use box (interact_offset z -0.95, 2.2 wide) and the bots' stand point
## (BotBrain._front_of: 1 m further out) with a margin round both.
const APPROACH: AABB = AABB(Vector3(-1.25, 0.0, -3.4), Vector3(2.5, 2.3, 2.55))

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
	marke_mat = StandardMaterial3D.new()
	marke_mat.resource_name = "crucible_room_marke"
	marke_mat.albedo_color = Color(0.08, 0.03, 0.12)
	marke_mat.roughness = 0.15
	marke_mat.emission_enabled = true
	marke_mat.emission = VIOLET
	_marke_e = float(data.get("marke_energy", 2.5))
	marke_mat.emission_energy_multiplier = _marke_e
	var kit: Kit = Kit.new(marke_mat)
	for p: Dictionary in data.get("pieces", []):
		kit.begin()
		_piece(kit, p)
		var ab: AABB = kit.end()
		piece_boxes.append([ab, p, kit.parts])
	var geo: Node3D = Node3D.new()
	geo.name = "Dressing"
	add_child(geo)
	kit.commit(geo)
	for l: Dictionary in data.get("lights", []):
		_light(l)
	_sound(data.get("sound", {}))
	for f: Dictionary in data.get("fx", []):
		_fx(f)
	GLBus.crucible_started.connect(_on_started)
	GLBus.crucible_ready.connect(_on_ready)
	GLBus.crucible_expired.connect(_on_expired)
	GLBus.weapon_acquired.connect(_on_acquired)


## Builds the pieces only (no tree, no lights): [AABB, piece, parts] per piece, in the machine's frame (parts: the
## AABB of each primitive). The tests and the survey read the layout without loading a map.
static func layout(key: String) -> Array:
	var d: Dictionary = config_for(key)
	var r: CrucibleRoom = CrucibleRoom.new()
	r.map_key = key
	r.data = d
	var kit: Kit = Kit.new(StandardMaterial3D.new())
	var out: Array = []
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
	var at: Vector3 = _v3(p.get("at"))
	var yaw: float = deg_to_rad(float(p.get("yaw", 0.0)))
	k.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	var mat: String = str(p.get("mat", "iron"))
	var sh: int = int(p.get("shadow", -1))
	match str(p.get("kind", "")):
		"box":
			k.box(Vector3.ZERO, _v3(p.get("size"), Vector3.ONE * 0.2), mat, _v3(p.get("rot")), sh)
		"cyl":
			k.cyl(Vector3.ZERO, float(p.get("r", 0.1)), float(p.get("h", 0.5)), mat, _v3(p.get("rot")), sh)
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
			var s: Vector3 = _v3(p.get("size"), Vector3(0.6, 0.6, 0.6))
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
		var a: Vector3 = _v3(pts[i - 1])
		var b: Vector3 = _v3(pts[i])
		k.seg(a, b, r, mat)
		if a.distance_to(b) > best:
			best = a.distance_to(b)
			longest = i
	for i2: int in pts.size():
		var c: Vector3 = _v3(pts[i2])
		k.ball(c, Vector3.ONE * r * 2.3, fl, 0)
	if bool(p.get("glass", false)) and longest > 0:
		var a2: Vector3 = _v3(pts[longest - 1])
		var b2: Vector3 = _v3(pts[longest])
		var m: Vector3 = a2.lerp(b2, 0.5)
		var d: Vector3 = (b2 - a2).normalized()
		k.seg(m - d * 0.2, m + d * 0.2, r * 1.15, "marke")
		for e: float in [-1.0, 1.0]:
			k.seg(m + d * (e * 0.2 - 0.03), m + d * (e * 0.2 + 0.03), r * 1.6, fl)
	var vi: int = int(p.get("valve", -1))
	if vi >= 0 and vi < pts.size():
		var c2: Vector3 = _v3(pts[vi])
		var out: Vector3 = _v3(p.get("valve_out"), Vector3(0, 0, -1)).normalized()
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
	var face: Vector3 = _v3(p.get("face"), Vector3(0, 0, -1)).normalized()
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
	var a: Vector3 = _v3(p.get("a"))
	var b: Vector3 = _v3(p.get("b"))
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
	var lo: Vector3 = _v3(p.get("lo"))
	var hi: Vector3 = _v3(p.get("hi"))
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
	li.position = _v3(l.get("at"), Vector3(0, 2.5, -1.5))
	add_child(li)
	if l.has("aim"):
		var aim: Vector3 = _v3(l["aim"])
		if aim.distance_to(li.position) > 0.01:
			li.look_at_from_position(li.position, aim, Vector3.UP if absf((aim - li.position).normalized().y) < 0.98 else Vector3.FORWARD)
	lights.append([li, li.light_energy, role])


func _sound(s: Dictionary) -> void:
	var key: String = str(s.get("key", "crucible_hum"))
	if s.is_empty() or not AudioDirector.has_sound(key):
		return
	_hum_db = float(s.get("db", -6.0))
	hum = AudioDirector.make_loop_3d(key, self, _hum_db)
	if hum == null:
		return
	hum.position = _v3(s.get("at"), Vector3(0, 1.2, 0))
	hum.unit_size = float(s.get("unit_size", hum.unit_size))
	hum.max_distance = float(s.get("max_distance", hum.max_distance))
	hum.play()


func _fx(f: Dictionary) -> void:
	var kind: String = str(f.get("kind", "steam"))
	var pt: CPUParticles3D = CPUParticles3D.new()
	pt.name = "Fx_%s_%d" % [kind, fx.size()]
	pt.position = _v3(f.get("at"), Vector3(0, 2.0, 0))
	pt.emitting = false
	pt.one_shot = true
	pt.local_coords = false
	var dir: Vector3 = _v3(f.get("dir"), Vector3.UP).normalized()
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
