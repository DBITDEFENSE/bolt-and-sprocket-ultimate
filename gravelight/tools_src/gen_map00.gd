extends SceneTree
## Generates Map 0 "Crossroads Inn" (Gasthaus Zum Kreuzweg): collision geometry with a baked navmesh,
## a full art-dressing pass (procedural materials, props, weather, lighting, post), and gameplay nodes.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map00.gd
## THIS FILE is the source of truth for the map (DECISIONS D-024): edit here and re-run.
##
## Two layers are kept apart on purpose:
##   - build_geometry(): the collision shell. Only these StaticBodies are baked into the navmesh.
##   - build_dressing(): everything decorative. Non-colliding, so dressing never changes navigation.
##
## Frame: +X east, +Z south, +Y up. The taproom's north wall is z = 0. 1 unit = 1 m.

const OUT: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const Hay: Script = preload("res://gravelight/world/props_hay.gd")   # T-238: bales, heaps, loose straw, the pitchfork
const T: float = 0.3          # wall thickness
const TAP_H: float = 3.5      # taproom ceiling
const UP_Y: float = 3.8       # upstairs floor top
const UP_TOP: float = 6.8     # upstairs ceiling
## 2026-11-12 (the owner, screenshots: "no space in hallway"): the guest rooms' hall wall stands at z HALL_Z0 = 5 (it was 6):
## the upstairs hall is 5 m deep, so beside the attic flight along its south wall (z ASTAIR_Z0..10) 2.6 m of it stays clear;
## the three rooms are 5 m deep.
const HALL_Z0: float = 5.0
## T-224 (the owner: "add a third story to the main building"): the attic (der Dachboden) over the guest rooms, x 0..24,
## z 0..10, floor ATT_Y (the old upstairs roof slab, 0.3 m thick now), 2.8 m to the boarded ceiling under the raised
## gable. Zone UPSTAIRS (no door of its own). The way up is a straight flight along the upstairs hall's south wall
## (ASTAIR_*: foot at x 6.4 two steps east of where the main stair lands, head at x 12.4, 1.75 m wide against the wall,
## 28.8 deg), landing through a well in the attic floor (x ASTAIR_HOLE_X0..ASTAIR_X1, z ASTAIR_Z0..the south wall)
## railed on its north and west sides. Its feeds: the stair and two gable windows (W_ATT_W, W_ATT_E) whose zombies stand
## on the hoist ledges outside the gables, like the porch-roof ledges below. The BAR and a frag crate are chalked up there.
const ATT_Y: float = 7.1       # attic floor top
const ATT_TOP: float = 9.9     # attic ceiling (the boarded underside of the roof)
const ASTAIR_X0: float = 6.4   # the attic flight's foot (its first riser)
const ASTAIR_X1: float = 12.4  # its head, at the attic floor
const ASTAIR_Z0: float = 7.75  # the flight's open north edge (2026-11-12: 2.1 m wide, it was 1.75; the owner: "stair way has no space")
const ASTAIR_Z1: float = 10.0 - 0.15   # against the hall's south wall
const ASTAIR_HOLE_X0: float = 7.3   # the attic well starts where the headroom under the floor drops to 2.3 m (the bake wants more than the 1.75 m agent: 2.0 at x 8.2 left a gap in the flight)
const ASTAIR_STEP: float = 0.4     # tread depth: 15 treads over the 6 m run, the attic floor the 16th rise (0.206 m each)
const ASTAIR_STEPS: int = 15
const ATT_WIN_Z: float = 4.5   # the gable windows' centre (z) on the west and east walls
## T-229 (the owner: "include a sniper tower with a zipline in map one"): a timber Hochsitz in the Carters' Yard's
## south-west corner, its deck 6 m up behind a closed boarded rail, a ladder up its north face (LadderClimbs, map00.json
## "ladders"; the zombies' climb link up the same face), and a zip line from its roof post down to a landing post by the
## stable's south wall (ZipLine, "ziplines"). The cellar hatch behind the bar (HATCH_*) is the Old Cellar's ladder's way
## up: the taproom floor is cut there, a Trapdoor leaf fills it until the Old Cellar opens.
const TOWER_X: float = 5.4
const TOWER_Z: float = 45.0
## T-268 (the owner: "make the watchtower like more badass, make it taller ... 3 zip lines that go to 3 different spots
## on the map"): two stages. The landing (TOWER_DECK, where the old deck was) and the top platform (TOWER_TOP), both
## TOWER_HALF * 2 square behind a parapet; a ladder up the north face to the landing, a second one inside the tower
## from the landing up through a hatch in the top's floor (T-275); three zip lines from brackets on the roof posts
## 2 m over the top platform (ZIP_LINES).
const TOWER_DECK: float = 6.2       # the landing's top (the first stage)
const TOWER_TOP: float = 12.0       # the top platform's top (the second stage)
const TOWER_HALF: float = 2.4       # the decks' half width (4.8 m: room for the squad; inside the rail the walkable square is far over the 4 m2 the bake keeps, T-106)
const TOWER_LEG: float = 2.1        # the legs' offset from the centre
## T-275 (the owner: "the guard tower looks good but it needs work on the ladder placement"): the lower ladder arrives
## through an opening in the landing's north parapet (TOWER_GAP_HALF either side of the ladder's line), its stiles
## carried on as hand holds; the upper ladder stands INSIDE the tower, on the landing, and goes up through a hatch in
## the top platform's floor against its east parapet (TOWER_HATCH_*: between the joists at x 6.4 and 7.4, clear of
## the legs, the bracing, the zip mounts in the north-east, north-west and south-west corners and the searchlight).
## The upper ladder's back is on the hatch's south edge: the climber hangs over the hatch facing south and steps off
## over the ladder's head onto the platform south of it (a guard rail closes the hatch's north and west sides, the
## parapet its east side); a body shot on it is pushed north, away from the step-off, so it falls inside the tower
## onto the landing. Both heads' numbers are in map00.json "ladders" / "climb_links" (test_ladders_data).
const TOWER_GAP_HALF: float = 0.5   # the landing's north opening: 1.0 m wide, centred on the lower ladder (x = TOWER_X)
const TOWER_HATCH_X0: float = 6.45  # the top platform's hatch (x 6.45..7.3, z 44.65..45.6); its east edge is the parapet
const TOWER_HATCH_X1: float = 7.3
const TOWER_HATCH_Z0: float = 44.65
const TOWER_HATCH_Z1: float = 45.6  # the upper ladder's back (its stiles stand 0.09..0.14 north of it)
const TOWER_LADDER2_X: float = 6.875 # the upper ladder's centre (x); its line is (6.875, 45.085)
const TOWER_HOLD_H: float = 1.0     # the ladders' stiles carry on this far over the floor they arrive on (hand holds)
## The zip lines: [name, the cable's top (a bracket on an iron arm off a roof post, TOWER_TOP + 2, a step outside the
## parapet so the rider mounts half a metre back up the line, on the deck), the landing post's foot]. The cable
## ends ZIP_POST_H up its post. The same numbers are in map00.json "ziplines" (test_ladders_data holds them together).
const ZIP_POST_H: float = 2.75
const ZIP_LINES: Array = [
	["YardZip", Vector3(TOWER_X + TOWER_HALF + 0.15, TOWER_TOP + 2.0, TOWER_Z - TOWER_HALF + 0.25), Vector3(29.8, 0, 42.1)],    # across the yard to the cart and the hitching rail
	["InnZip", Vector3(TOWER_X - TOWER_HALF + 0.25, TOWER_TOP + 2.0, TOWER_Z - TOWER_HALF - 0.15), Vector3(1.6, 0, 19.6)],      # north past the stable's west wall to the passage behind the inn
	["BankZip", Vector3(TOWER_X - TOWER_HALF - 0.1, TOWER_TOP + 2.0, TOWER_Z + TOWER_HALF - 0.05), Vector3(-15.2, 0, 59.6)],   # south-west over the fence to the road by the savings bank
]
const HATCH_X0: float = 6.15
const HATCH_X1: float = 7.05
const HATCH_Z0: float = 5.15
const HATCH_Z1: float = 6.05
## T-224 (the owner: "the bar needs to be bigger with more space"): the bar is an L of counter 10.1 m long now (it was
## 9): the front x BAR_X0..BAR_X1 at z BAR_Z1..BAR_Z1+0.8, the side x BAR_X1-0.8..BAR_X1 from z BAR_Z0 to BAR_Z1, the back-bar (the
## shelving, a mirror, the till and the taps) on x SHELF_X0..SHELF_X1. The whole block moved 1.1 m west and grew
## north: the service walk behind it is 3.7 x 5.1 m (was 3.2 x 5) and the floor east of the counter gained 0.6 m to the
## taproom loop (routes_map00.json keeps its line). The walkway to the Old Cellar door (T-120) grew to 1.55 m (z 8.3..9.85).
const SHELF_X0: float = 3.5
const SHELF_X1: float = 3.9
const BAR_X0: float = 3.9
const BAR_X1: float = 8.4
const BAR_Z0: float = 2.4
const BAR_Z1: float = 6.8   # the counter's south end: its front runs z BAR_Z1..BAR_Z1+0.8; the Old Cellar walkway (T-120) is 2.25 m to the stairwell wall (2026-11-12, the owner: "area between bar no space"; it was 1.55 m)
const STABLE_H: float = 7.0
## The stable ("the barn", T-084: "about 10% bigger ... improve the staircase and the second level"): x 4.5..25.5
## by z 22..34 (21 x 12 m; it was 18 x 12, x 6..24). The hayloft (LOFT_Y..LOFT_TOP) is the west block x 4.5..LOFT_X1
## over the full depth and a gallery along the south wall from LOFT_X1 to the east wall, z GAL_Z0..34, over the great
## doors (3 m high now); the bay over the stalls, the hay pile and the north door is open to the roof. A straight
## flight up the east wall (HSTAIR_*: 2 m wide, foot z 25.5, head z 31.5, 30 deg) lands through a well in the gallery.
const STB_X0: float = 4.5
const STB_X1: float = 25.5
const STB_Z0: float = 22.0
const STB_Z1: float = 34.0
const LOFT_Y: float = 3.2
const LOFT_TOP: float = 3.5
const LOFT_X1: float = 15.5
const GAL_Z0: float = 29.0
const HSTAIR_X0: float = 23.35
const HSTAIR_X1: float = 25.35
const HSTAIR_Z0: float = 25.5
const HSTAIR_Z1: float = 31.5
const HSTAIR_STEPS: int = 16
const GREAT_DOOR_H: float = 3.0
const LOFT_DROP: Vector2 = Vector2(18.6, 20.0)   # the bale drop: the open bay in the gallery's rail (walk off; zombies don't path it)
## Physics layer 11 "edge" (T-084): the grounds' edge wall and the boundary fences on it. Bodies collide with it
## (Player.MASK_MOVE), shots, projectiles, blasts and the aim/interaction rays don't (they mask layer 1), so a
## zombie beyond the edge can be shot. The navmesh bake reads it (bake_navmesh's geometry_collision_mask).
const EDGE_LAYER: int = 1 << 10
## T-125: a blocking fence (the yard's, the roadside one) is solid on the world layer only up to its drawn rails;
## above that, to its 2.3 m top, it is on EDGE_LAYER (players can't hop it; shots pass between the tall fence's
## upper rails) and it is drawn as a tall closed corral fence, so nothing that stops you is invisible.
const FENCE_SOLID_H: float = 1.25
const WIN_SILL: float = 0.9
const WIN_TOP: float = 2.2
const DOOR_H: float = 2.4
const WAINSCOT_H: float = 1.1
## The staircase to the guest rooms (playtest 2026-10-21: the old 2.7 m flight in a 3 m well was too cramped). The well is
## x 0..STAIR_X1, z 10..16, full height: the flight runs up the west wall, open on its east side over a 2.2 m
## vestibule that Door 1 opens into, and lands a metre inside the upstairs hall; the hall overlooks the well.
const STAIR_X1: float = 6.0        # the well's east wall (Door 1 is in it)
const FLIGHT_X1: float = 3.65      # the flight's open edge; the vestibule is x FLIGHT_X1..STAIR_X1
const STAIR_Z0: float = 14.3       # the foot of the flight (its first riser)
const STAIR_Z1: float = 9.0        # its head, in the hall
## The inn's front door in the taproom's north wall, under the east porch roof (T-072).
const FRONT_DOOR_X: float = 20.0
## The taproom's added tables (playtest: "the initial room needs more tables", T-072): [centre (x, z), width (x),
## depth (z), seating: "chairs" (one each side) / "pair" (west and east) / "benches" (along both long sides)]. They
## stand inside the clockwise training loop (1.4 m+ clear of its line, routes_map00.json) or west of it.
const TAP_TABLES_NEW: Array = [
	[Vector2(19.0, 9.0), 1.2, 1.2, "chairs"],    # the carters' table (Kubiak and Rother): cards and steins
	[Vector2(16.0, 4.8), 1.2, 1.2, "chairs"],    # a table cleared in a hurry
	[Vector2(12.3, 5.4), 0.9, 0.9, "pair"],      # by the hearth: Frau Pohl's coffee, her suitcase beside it
	[Vector2(8.0, 11.8), 0.9, 2.4, "benches"],   # the long trestle by the stair wall
]

## Old greybox keys -> material library keys (world/materials.gd).
const MAT_MAP: Dictionary = {
	"wall": "plaster", "wall_upper": "plaster_upper", "stable": "planks", "floor_wood": "floorboards",
	"floor_dirt": "dirt", "snow": "snow", "roof": "roof", "furniture": "furniture", "stone": "stone",
	"stairs": "furniture", "metal": "iron", "quest": "nachtglas", "fire": "fire", "hay": "hay", "wreck": "wreck",
}

## Invisible colliders whose dressing fills them closely enough for bullet holes to stay (Effects.persists_on;
## every other invisible collider is tagged "decal_persist" false: tables, rail panels, fences, the great doors).
const PERSIST_HIDDEN: Array = ["Hearth", "BarFront", "BarSide", "Bed1", "Bed2", "Bed3", "TechTrunk", "HayBales", "YardTrough", "Well"]

var map_root: Node3D
var nav: NavigationRegion3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _bake_only: Array[Node] = []
var _frames: int = 0


func _initialize() -> void:
	# T-179: a --script run compiles this file's dependencies before the autoloads are registered, so Landscape (which
	# names GLSettings since T-139) failed to compile and the dressing pass lost the edge tree line at
	# Landscape.uniform_tree_xform. Recompiled here, once the autoload names exist.
	for dep: String in ["res://gravelight/world/landscape/landscape.gd"]:
		var dep_s: GDScript = load(dep) as GDScript
		if dep_s != null and not dep_s.can_instantiate():
			print("gen_map00: recompiling %s, err=%d" % [dep, dep_s.reload()])
	map_root = Node3D.new()
	map_root.name = "Map00Crossroads"
	get_root().add_child(map_root)
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	map_root.add_child(nav)
	geo = Node3D.new()
	geo.name = "Geometry"
	nav.add_child(geo)
	dress = Node3D.new()   # outside the NavigationRegion3D, so the bake never parses dressing
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_geometry()


## Baking needs the nodes inside the tree, which only holds once the main loop is running.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_navmesh()
	for n: Node in _bake_only:   # colliders that only shape the navmesh (T-051)
		n.get_parent().remove_child(n)
		n.free()
	_bake_breach_open()
	get_root().remove_child(map_root)
	build_dressing()
	if _audit_wall_buys() > 0:   # T-227: never save a scene with a chalk hidden behind the dressing
		push_error("gen_map00: a wall-buy is blocked; the scene was NOT saved")
		map_root.free()
		return true
	if OS.get_environment("GL_PERK_SURVEY") != "":   # T-251: where could a perk spot stand? (a design aid; nothing is saved)
		_survey_perk_spots()
		map_root.free()
		return true
	if _audit_perk_spots() > 0:   # T-251: never save a scene with a perk spot in a doorway, a wall or a walk
		push_error("gen_map00: a perk spot is blocked; the scene was NOT saved")
		map_root.free()
		return true
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_environment()
	build_landscape()
	build_gameplay()
	build_reactive()
	if map_root.get_script() == null:   # T-251: map_root.gd did not compile (a class the cache does not know yet: run the import first)
		push_error("gen_map00: the map root has no script (MapRoot failed to load); the scene was NOT saved")
		map_root.free()
		return true
	_own(map_root, map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(packed, _out())
	print("Saved %s (%d collision boxes), err=%d" % [_out(), _count, err])
	map_root.free()
	return true


## T-238: where the scene is saved. GL_GEN_OUT (e.g. "user://probe_map00.tscn") sends a probe or inventory run somewhere
## else, so a GL_PROBE_BOX run never rewrites the map while a capture or a smoke is reading it.
func _out() -> String:
	var o: String = OS.get_environment("GL_GEN_OUT")
	return o if o != "" else OUT


# ================================================================== helpers

func mat(key: String) -> Material:
	return Mats.get_mat(str(MAT_MAP.get(key, key)))


## Axis-aligned box from min/max corners. collide = a static collider on the "world" layer.
## visible = false makes a collider with no mesh (the dressing pass draws it instead).
func box(parent: Node3D, name_: String, a: Vector3, b: Vector3, mat_key: String, collide: bool = true, visible: bool = true) -> Node3D:
	var size: Vector3 = (b - a).abs()
	var center: Vector3 = (a + b) * 0.5
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	var mi: MeshInstance3D = null
	if visible:
		mi = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = mat(mat_key)
	if not collide:
		mi.name = name_
		mi.position = center
		parent.add_child(mi)
		return mi
	_count += 1
	Props.probe_geo(name_, a, b, mat_key)   # (T-230: GL_PROBE_BOX names a piece seen in a render)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	if not visible and not PERSIST_HIDDEN.has(name_):
		body.set_meta("decal_persist", false)   # an invisible collider: a hole in it would float (T-053)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if mi != null:
		body.add_child(mi)
	parent.add_child(body)
	return body


## Wainscot + chair rail on one face of a wall segment. `face` = the coordinate of that face, `out` = +1/-1
## (direction into the room). Built along X when `along_x`, else along Z.
func _wainscot(along_x: bool, face: float, out: float, a: float, b: float, y0: float, top: float) -> void:
	if b - a < 0.05:
		return
	var h: float = minf(WAINSCOT_H, top - y0)
	if h <= 0.05:
		return
	var f0: float = face
	var f1: float = face + out * 0.03
	if along_x:
		Props.block(dress, Vector3(a, y0, f0), Vector3(b, y0 + h, f1), "wainscot")
		Props.block(dress, Vector3(a, y0, f0), Vector3(b, y0 + 0.14, face + out * 0.045), "beam")
		if h >= WAINSCOT_H - 0.01:
			Props.block(dress, Vector3(a, y0 + h - 0.04, f0), Vector3(b, y0 + h + 0.03, face + out * 0.06), "beam")
	else:
		Props.block(dress, Vector3(f0, y0, a), Vector3(f1, y0 + h, b), "wainscot")
		Props.block(dress, Vector3(f0, y0, a), Vector3(face + out * 0.045, y0 + 0.14, b), "beam")
		if h >= WAINSCOT_H - 0.01:
			Props.block(dress, Vector3(f0, y0 + h - 0.04, a), Vector3(face + out * 0.06, y0 + h + 0.03, b), "beam")


## Wall along X at depth z. openings: [[x_a, x_b, y_a, y_b], ...]. trim: 0 none, +1/-1 wainscot on the
## +Z/-Z face, 2 = both faces. trim_x0/trim_x1 stop the wainscot short of the wall's ends (where the wall runs on
## into a doorway's jamb, T-072).
func wall_x(name_: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mat_key: String, trim: int = 0,
		trim_x0: float = -1e9, trim_x1: float = 1e9) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = x0
	var i: int = 0
	var spans: Array = []   # [a, b, top] segments touching the floor
	for o: Array in openings:
		var oa: float = float(o[0])
		var ob: float = float(o[1])
		box(geo, "%s_%d" % [name_, i], Vector3(cur, y0, z - T * 0.5), Vector3(oa, y1, z + T * 0.5), mat_key)
		box(geo, "%s_%db" % [name_, i], Vector3(oa, y0, z - T * 0.5), Vector3(ob, float(o[2]), z + T * 0.5), mat_key)
		box(geo, "%s_%dt" % [name_, i], Vector3(oa, float(o[3]), z - T * 0.5), Vector3(ob, y1, z + T * 0.5), mat_key)
		spans.append([cur, oa, y1])
		spans.append([oa, ob, float(o[2])])
		cur = ob
		i += 1
	box(geo, "%s_end" % name_, Vector3(cur, y0, z - T * 0.5), Vector3(x1, y1, z + T * 0.5), mat_key)
	spans.append([cur, x1, y1])
	for s: Array in spans:
		for side: int in [1, -1]:
			if trim == side or trim == 2:
				_wainscot(true, z + side * T * 0.5, float(side), maxf(float(s[0]), trim_x0), minf(float(s[1]), trim_x1), y0, float(s[2]))


## Wall along Z at x. Same conventions as wall_x (trim +1 = the +X face).
func wall_z(name_: String, x: float, z0: float, z1: float, y0: float, y1: float, openings: Array, mat_key: String, trim: int = 0) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = z0
	var i: int = 0
	var spans: Array = []
	for o: Array in openings:
		var oa: float = float(o[0])
		var ob: float = float(o[1])
		box(geo, "%s_%d" % [name_, i], Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, oa), mat_key)
		box(geo, "%s_%db" % [name_, i], Vector3(x - T * 0.5, y0, oa), Vector3(x + T * 0.5, float(o[2]), ob), mat_key)
		box(geo, "%s_%dt" % [name_, i], Vector3(x - T * 0.5, float(o[3]), oa), Vector3(x + T * 0.5, y1, ob), mat_key)
		spans.append([cur, oa, y1])
		spans.append([oa, ob, float(o[2])])
		cur = ob
		i += 1
	box(geo, "%s_end" % name_, Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, z1), mat_key)
	spans.append([cur, z1, y1])
	for s: Array in spans:
		for side: int in [1, -1]:
			if trim == side or trim == 2:
				_wainscot(false, x + side * T * 0.5, float(side), float(s[0]), float(s[1]), y0, float(s[2]))


## A straight ramp (stairs) along Z between two heights. Collision is one slab; treads/risers are dressing.
## hollow_z: steps past it (toward z_high, which must be the smaller z) are drawn as shells over a plaster soffit
## instead of solid blocks, for a flight that passes over another room. east_rail: the plain rail on the +X side.
func ramp_z(name_: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float,
		hollow_z: float = -1e9, east_rail: bool = true) -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var angle: float = atan2(rise, run)
	var dir: float = sign(z_high - z_low)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	var thick: float = 0.2
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, (y_low + y_high) * 0.5, (z_low + z_high) * 0.5)
	var basis: Basis = Basis(Vector3.RIGHT, -angle * dir)
	var up: Vector3 = basis * Vector3.UP
	body.transform = Transform3D(basis, mid - up * thick * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(absf(x1 - x0), thick, length)
	cs.shape = shape
	body.add_child(cs)
	geo.add_child(body)
	_count += 1
	_stair_dressing.append([x0, x1, z_low, z_high, y_low, y_high, hollow_z, east_rail])


var _stair_dressing: Array = []


## Height of the main staircase's tread line at z.
func _stair_y(z: float) -> float:
	return UP_Y * (STAIR_Z0 - z) / (STAIR_Z0 - STAIR_Z1)


## A collider bar from a to b (the rails and curbs of the balustrades): a box body along the segment, drawn in
## `mat_key` unless it is empty. Three thin bars stop the player and cut the navmesh at an edge while shots pass
## between them.
func bar(parent: Node3D, name_: String, a: Vector3, b: Vector3, w: float, h: float, mat_key: String = "") -> void:
	var d: Vector3 = b - a
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (a + b) * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(w, h, d.length())
	cs.shape = shape
	body.add_child(cs)
	if mat_key != "":
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = shape.size
		mi.material_override = mat(mat_key)
		body.add_child(mi)
	parent.add_child(body)
	_count += 1


func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)


# ================================================================== collision shell (navmesh source)

func build_geometry() -> void:
	# ground slab, with a hole over the cellar annex (x 24..36, z 10..31; T&C M2, DECISIONS T-027)
	# and holes over the Old Cellar under the taproom, its stair lean-to and its two light wells (T-051, OC_HOLES)
	_slab_with_holes("Ground", -45.0, 24.0, -40.0, 75.0, OC_HOLES)
	# (T-179: with a hole over the cellar's late-delivery bay, which has its own roof)
	# (T-251: and holes over the Lagering Vault and the Dynamo Room south of the vault, which have their own roofs too)
	var t2: float = T * 0.5
	_slab_with_holes("GroundE", 36.0, 70.0, -40.0, 75.0, [Rect2(BAY_X0, BAY_Z0 - t2, BAY_X1 + t2 - BAY_X0, BAY_Z1 - BAY_Z0 + T),
		Rect2(36.0, LAG_Z0 + t2, DYN_X1 + t2 - 36.0, DYN_Z1 - LAG_Z0)])
	_slab_with_holes("GroundN", 24.0, 36.0, -40.0, 10.0, OC_HOLES)
	_slab_with_holes("GroundS", 24.0, 36.0, LAG_Z0 + t2, 75.0, [Rect2(24.0, LAG_Z0 + t2, LAG_X1 - t2 - 24.0, LAG_Z1 - LAG_Z0),
		Rect2(LAG_X1 - t2, LAG_Z0 + t2, 36.0 - (LAG_X1 - t2), DYN_Z1 - LAG_Z0)])
	# T-080: the snow east of the cellar's stair hall (x 28..36, z 10..19) was a hole in the slab (nobody walked there);
	# the grounds' ring and the Wreck Loop cross it
	box(geo, "GroundAnnexN", Vector3(28.0, -0.5, 10.0), Vector3(36.0, 0.0, 19.0), "snow")

	# ---------------- TAPROOM (ground floor)
	var win: Array = [WIN_SILL, WIN_TOP]
	wall_x("TapN", 0.0, -T * 0.5, 24 + T * 0.5, 0, TAP_H, [[6.2, 7.8] + win, [16.2, 17.8] + win, [FRONT_DOOR_X - 0.8, FRONT_DOOR_X + 0.8, 0.0, DOOR_H]], "wall", 1)
	# the inn's front door under the porch (T-072): drawn and swinging (InnFrontDoor). Until T-080 its opening was
	# filled with an invisible collider; now it is a bought door (Door_Front, "Out Front", the way onto the GROUNDS):
	# like every BuyDoor it is not baked, so the navmesh runs through the doorway and the door's own collider shuts it
	wall_z("TapW", 0.0, 0, 10, 0, TAP_H, [[5.2, 6.8] + win, [8.25, 9.85, 0.0, DOOR_H]], "wall", 1)   # Door 5: the Old Cellar (T-051)
	wall_z("TapE", 24.0, 0, 16, 0, TAP_H, [[7.2, 8.8] + win, [10.7, 12.3, 0.0, DOOR_H]], "wall", -1)
	wall_x("TapS", 16.0, STAIR_X1, 24 + T * 0.5, 0, TAP_H, [[19.0, 21.0, 0.0, DOOR_H]], "wall", -1, STAIR_X1 + T * 0.5)   # trim clear of Door 1's jamb
	# stairwell (x 0..6, z 10..16), full height: the flight along the west wall (3.5 m wide, z 14.3 -> 9.0, so it
	# lands a metre inside the hall), the vestibule beside it with Door 1 in the east wall, the hall overlooking it
	wall_z("StairW", 0.0, 10, 16 + T * 0.5, 0, UP_TOP, [], "wall", 1)
	wall_x("StairS", 16.0, -T * 0.5, STAIR_X1, 0, UP_TOP, [], "wall", -1, -1e9, STAIR_X1 - T * 0.5)
	wall_z("StairE", STAIR_X1, 10, 16, 0, UP_TOP, [[14.3, 15.9, 0.0, DOOR_H]], "wall", 2)
	wall_x("StairN", 10.0, FLIGHT_X1, STAIR_X1 + T * 0.5, 0, UP_Y, [], "wall", 2)   # under the hall floor: closes the vestibule from the taproom
	wall_x("StairNu", 10.0, -T * 0.5, FLIGHT_X1, 0, _stair_y(10.15) - 0.42, [], "wall", -1)   # under the flight's soffit
	box(geo, "StairRoof", Vector3(-T * 0.5, UP_TOP, 10), Vector3(STAIR_X1 + T * 0.5, UP_TOP + 0.2, 16 + T * 0.5), "roof")
	ramp_z("Stairs", 0.15, FLIGHT_X1, STAIR_Z0, STAIR_Z1, 0.0, UP_Y, 10.0, false)
	# the under-stair is solid (the step blocks draw it): invisible boxes stepped under the soffit line keep the
	# navmesh out of it
	for seg: Array in [[10.15, 11.0], [11.0, 12.0], [12.0, 13.0]]:
		box(geo, "StairUnder", Vector3(0.15, 0, float(seg[0])), Vector3(FLIGHT_X1, _stair_y(float(seg[1])) - 0.42, float(seg[1])), "wall", true, false)
	# balustrades: a curb, a mid rail and a handrail up the flight's open side, round the stair head and along
	# the hall's edge over the well (the balusters are dressing)
	var bx: float = FLIGHT_X1 - 0.05
	var hz: float = 10.0 - 0.05
	for r: Array in [[0.06, 0.06, 0.12], [0.47, 0.035, 0.04], [0.92, 0.07, 0.07]]:   # [centre height, width, height]
		var hy: float = float(r[0])
		bar(geo, "StairRail", Vector3(bx, hy, STAIR_Z0), Vector3(bx, UP_Y + hy, STAIR_Z1), float(r[1]), float(r[2]), "furniture")
		bar(geo, "StairRail", Vector3(bx, UP_Y + hy, STAIR_Z1 - 0.03), Vector3(bx, UP_Y + hy, hz), float(r[1]), float(r[2]), "furniture")
		bar(geo, "HallRail", Vector3(bx - 0.03, UP_Y + hy, hz), Vector3(STAIR_X1 - T * 0.5, UP_Y + hy, hz), float(r[1]), float(r[2]), "furniture")
	# the balustrade for the navmesh bake: the rail bars are thinner than a navmesh cell, so the bake saw the
	# flight's open edge as walkable into the vestibule and zombies wedged on the mid rail at the foot and the
	# head (T-040 playtest). Two hidden panels along the rail lines cut it properly; the flight still meets the
	# landing at its foot and the hall at its head.
	# The stairwell is shut at z = 10 (StairN / StairNu); north of that the flight's last metre runs over the
	# taproom, so the panel there starts under the soffit, not on the floor. It used to reach the floor all the
	# way to z 8.95: an invisible wall at x 3.6 beside the bar's west end, across the way to the Old Cellar door,
	# that players and zombies stuck on.
	box(geo, "StairRailPanel", Vector3(bx - 0.08, 0.0, 10.15), Vector3(bx + 0.08, UP_Y + 1.0, STAIR_Z0), "wall", true, false)
	box(geo, "StairRailPanelHead", Vector3(bx - 0.08, _stair_y(10.15) - 0.42, STAIR_Z1 - 0.05), Vector3(bx + 0.08, UP_Y + 1.0, 10.15), "wall", true, false)
	box(geo, "HallRailPanel", Vector3(bx - 0.08, UP_Y, hz - 0.08), Vector3(STAIR_X1 - T * 0.5, UP_Y + 1.0, hz + 0.08), "wall", true, false)
	# ceiling slabs: A = upstairs floor (z 0..10; the flight lands in it west of the vestibule), B = taproom roof
	box(geo, "SlabA", Vector3(-T * 0.5, TAP_H, -T * 0.5), Vector3(FLIGHT_X1, UP_Y, STAIR_Z1), "floor_wood")
	box(geo, "SlabA2", Vector3(FLIGHT_X1, TAP_H, -T * 0.5), Vector3(24 + T * 0.5, UP_Y, 10), "floor_wood")
	box(geo, "SlabB", Vector3(STAIR_X1, TAP_H, 10), Vector3(24 + T * 0.5, UP_Y, 16 + T * 0.5), "floor_wood")
	# fireplace + chimney (north wall): collision only, drawn by the dressing pass
	box(geo, "Hearth", Vector3(10.9, 0, 0.15), Vector3(13.1, 1.5, 0.95), "stone", true, false)
	box(geo, "Chimney", Vector3(11.2, 1.5, 0.15), Vector3(12.8, TAP_H, 0.6), "stone")
	# bar (counter front + side) and back shelf: collision only (T-224: the bigger L, see BAR_* / SHELF_*)
	box(geo, "BarFront", Vector3(BAR_X0, 0, BAR_Z1), Vector3(BAR_X1, 1.1, BAR_Z1 + 0.8), "furniture", true, false)
	box(geo, "BarSide", Vector3(BAR_X1 - 0.8, 0, BAR_Z0), Vector3(BAR_X1, 1.1, BAR_Z1), "furniture", true, false)
	box(geo, "BackShelf", Vector3(SHELF_X0, 0, BAR_Z0), Vector3(SHELF_X1, 2.0, BAR_Z1), "furniture", true, false).set_meta("shot_through", true)   # open shelving: shots reach the bottles (T-053)
	# the beer cask on its cradle behind the counter's north end (T-224): the one thing in the service walk, in its corner
	box(geo, "BarCask", Vector3(SHELF_X1 + 0.05, 0, BAR_Z0 + 0.05), Vector3(SHELF_X1 + 0.95, 0.9, BAR_Z0 + 0.85), "furniture", true, false)
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		box(geo, "Table", Vector3(p.x - 0.6, 0, p.y - 0.6), Vector3(p.x + 0.6, 0.75, p.y + 0.6), "furniture", true, false)
	for t: Array in TAP_TABLES_NEW:   # the busier taproom (T-072)
		var c: Vector2 = t[0]
		var hs: Vector2 = Vector2(float(t[1]), float(t[2])) * 0.5
		box(geo, "Table", Vector3(c.x - hs.x, 0, c.y - hs.y), Vector3(c.x + hs.x, 0.75, c.y + hs.y), "furniture", true, false)
	# T-238: the signals unit's crates in the north-east corner, against the east wall (drawn by _dress_taproom)
	box(geo, "TapCrates", Vector3(23.08, 0, 0.92), Vector3(24 - T * 0.5, 0.7, 2.38), "furniture", true, false).set_meta("no_mantle", true)
	box(geo, "TapCratesTop", Vector3(23.16, 0.7, 1.72), Vector3(24 - T * 0.5, 1.25, 2.32), "furniture", true, false).set_meta("no_mantle", true)

	# ---------------- UPSTAIRS (y 3.8 .. 6.8, z 0..10)
	var up_win: Array = [UP_Y + WIN_SILL, UP_Y + WIN_TOP]
	wall_x("UpN", 0.0, -T * 0.5, 24 + T * 0.5, UP_Y, UP_TOP, [[3.2, 4.8] + up_win, [19.2, 20.8] + up_win], "wall_upper", 1)
	wall_z("UpW", 0.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", 1)
	wall_z("UpE", 24.0, 0, 10, UP_Y, UP_TOP, [], "wall_upper", -1)
	wall_x("UpS", 10.0, STAIR_X1 - T * 0.5, 24 + T * 0.5, UP_Y, UP_TOP, [], "wall_upper", -1)
	var room_door: Array = [UP_Y, UP_Y + 2.2]
	wall_x("UpHall", HALL_Z0, 0, 24, UP_Y, UP_TOP, [[5.0, 6.5] + room_door, [11.0, 12.5] + room_door, [19.5, 21.0] + room_door], "wall_upper", 2)
	wall_z("UpRoom12", 8.0, 0, HALL_Z0, UP_Y, UP_TOP, [], "wall_upper", 2)
	wall_z("UpRoom23", 16.0, 0, HALL_Z0, UP_Y, UP_TOP, [], "wall_upper", 2)
	build_attic()
	box(geo, "Bed1", Vector3(0.3, UP_Y, 0.4), Vector3(2.2, UP_Y + 0.5, 2.6), "furniture", true, false)
	box(geo, "Bed2", Vector3(13.6, UP_Y, 0.4), Vector3(15.6, UP_Y + 0.5, 2.6), "furniture", true, false)
	box(geo, "Bed3", Vector3(21.6, UP_Y, 2.3), Vector3(23.7, UP_Y + 0.5, 4.7), "furniture", true, false)
	box(geo, "TechTrunk", Vector3(10.4, UP_Y, 0.5), Vector3(11.6, UP_Y + 0.5, 1.2), "furniture", true, false)
	# porch-roof ledges outside the upstairs windows (zombies climb onto these)
	box(geo, "LedgeW", Vector3(1.5, TAP_H, -2.4), Vector3(6.5, UP_Y, -T * 0.5), "roof")
	box(geo, "LedgeE", Vector3(17.5, TAP_H, -2.4), Vector3(22.5, UP_Y, -T * 0.5), "roof")
	for x: float in [1.7, 6.3, 17.7, 22.3]:
		box(geo, "LedgePost", Vector3(x - 0.1, 0, -2.3), Vector3(x + 0.1, TAP_H, -2.1), "beam")

	# ---------------- YARD PASSAGE (x 18..22, z 16..22)
	wall_z("PassW", 18.0, 16, 22, 0, 3.0, [], "stable")
	wall_z("PassE", 22.0, 16, 22, 0, 3.0, [], "stable")
	box(geo, "PassRoof", Vector3(18 - T * 0.5, 3.0, 16), Vector3(22 + T * 0.5, 3.2, 22), "roof")

	# ---------------- STABLE (x STB_X0..STB_X1, z 22..34, ceiling 7; T-084: 21 x 12 m, the loft and its stair rebuilt)
	wall_x("StbN", STB_Z0, STB_X0 - T * 0.5, STB_X1 + T * 0.5, 0, STABLE_H, [[8.2, 9.8] + win, [13.2, 14.8] + win, [18.5, 21.5, 0.0, 2.6]], "stable")
	# the great doors' opening is drawn (the doors themselves are dressing, so the exfil cutscene can drop them)
	# but filled with an invisible collider: the navmesh and collision stay a solid wall, nobody walks out. 3 m high
	# since T-084 (the hayloft's gallery runs over them); the loft door above them is a barricaded window (W_STB_LOFT)
	var loft_win: Array = [LOFT_TOP + WIN_SILL, LOFT_TOP + WIN_TOP]
	wall_x("StbS", STB_Z1, STB_X0 - T * 0.5, STB_X1 + T * 0.5, 0, STABLE_H, [[7.0, 9.0, 0.0, DOOR_H], [11.2, 12.8] + win, [16.0, 20.0, 0.0, GREAT_DOOR_H],
		[21.2, 22.8] + loft_win], "stable")
	box(geo, "GreatDoorsBlock", Vector3(16.0, 0, STB_Z1 - T * 0.5), Vector3(20.0, GREAT_DOOR_H, STB_Z1 + T * 0.5), "stable", true, false)
	wall_z("StbW", STB_X0, STB_Z0, STB_Z1, 0, STABLE_H, [], "stable")
	wall_z("StbE", STB_X1, STB_Z0, STB_Z1, 0, STABLE_H, [], "stable")
	box(geo, "StbRoof", Vector3(STB_X0 - T * 0.5, STABLE_H, STB_Z0 - T * 0.5), Vector3(STB_X1 + T * 0.5, STABLE_H + 0.2, STB_Z1 + T * 0.5), "planks")
	for x: float in [11.0, 16.0, 17.6]:
		box(geo, "Stall", Vector3(x - 0.08, 0, 22.2), Vector3(x + 0.08, 1.3, 25.2), "planks")
	build_hayloft()

	build_yard()
	build_cellar()
	build_nav_blocks()

	# ---------------- crash site (east field): GRAVELIGHT ONE (collision for the hull only)
	var wreck: Node3D = Node3D.new()
	wreck.name = "Wreck"
	wreck.position = Vector3(46, 0, 6)
	wreck.rotation = Vector3(0, deg_to_rad(28), deg_to_rad(-8))
	geo.add_child(wreck)
	# T-080: the crash site is in the play space now (the GROUNDS): cover, never a perch (no_mantle), the engine
	# nacelles that hang out ahead of the wing are solid too, and the wing reaches the snow (no crawl space under it)
	# (the hull is rolled 8 deg: the port wing tip stands 1.25 m off the snow, so the boxes reach down into the ground)
	build_wreck_hull(wreck)
	# T-211 (UPDATE 12 section 5, the C-47 rebuilt from tools/c47/): what stays on the rolled hull: the port wing to its
	# broken joint (x -9; its outer panel lies in the snow, a debris box below), reaching the snow (the drift under it
	# is drawn); the port nacelle torn open at the firewall (the engine lies in the north field); the nose cone
	# crushed into the field ahead of the cockpit's wall (under the windscreen's sill: Selwyn's line of fire is over
	# it); the supply crates lashed by the port cargo door. The starboard wing and its nacelle are gone from the hull
	# (sheared at the root, behind the fuselage) and the tail broke away behind the aft bulkhead: their colliders are
	# build_c47_debris()'s.
	for wb: Array in WRECK_WING_BOXES:
		box(wreck, str(wb[0]), wb[1], wb[2], "wreck", true, false).set_meta("no_mantle", true)
	build_c47_debris()
	build_grounds()


## T-126 (the owner: "improve the plane wreck, make it so you can go into the plane, have a pilot trapped in there"):
## GRAVELIGHT ONE's hull is hollow. In the wreck's frame (x across, -z the nose; rolled 8 deg, the port side up): a
## cabin floor (top WRECK_FLOOR) from the cockpit to the aft bulkhead, walls WRECK_WALL thick, a roof; two ways in on
## the low starboard side, the cargo door aft and a torn hole forward of the wing; the cockpit behind a bulkhead whose
## doorway is choked waist-high with wreckage (you see and reach the pilot over it; nothing walks in); the cockpit's
## windscreen and side windows broken out from a sill nobody can jump to (WRECK_SILL), so the pinned pilot shoots out.
## Openings: [side (-1 port, 1 starboard, 0 the nose), z0, z1, y0, y1]. Drawn by _dress_wreck from the same table.
const WRECK_FLOOR: float = 0.2
const WRECK_ROOF: float = 2.35
const WRECK_TOP: float = 2.6
const WRECK_HALF: float = 1.4
const WRECK_WALL: float = 0.25
const WRECK_NOSE_Z: float = -6.9
const WRECK_BULK_Z: float = -4.9
const WRECK_AFT_Z: float = 5.3
const WRECK_SILL: float = 1.4
## The windscreen's sill: under the seated pilot's eye (TrappedPilot eye_y 1.3 over the floor), over a jump.
const WRECK_SCREEN: float = 1.1
const WRECK_OPENINGS: Array = [
	[1, 2.2, 4.0, WRECK_FLOOR, WRECK_ROOF],  # the cargo door (starboard, aft): the low side; up to the roof line (navmesh headroom)
	[1, -4.3, -2.45, WRECK_FLOOR, WRECK_ROOF], # the torn hole forward of the wing (1.85 m: the navmesh erodes 0.5 m off each jamb)
	[1, -6.5, -5.1, WRECK_SILL, 2.25],      # the cockpit's starboard window, glass gone
	[-1, -6.5, -5.1, WRECK_SILL, 2.25],     # its port window
	[0, -1.0, 1.0, WRECK_SCREEN, 2.25],     # the windscreen (x -1..1 across the nose)
]
## The pilot's seat (the cockpit floor under it), in the wreck's frame; the bulkhead doorway is x -0.5..0.5.
const WRECK_PILOT_SEAT: Vector3 = Vector3(-0.35, WRECK_FLOOR, -5.75)


## The wreck's frame (as the Wreck collider node and the WreckDress group stand).
static func wreck_xf() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(28), deg_to_rad(-8))), Vector3(46, 0, 6))


## T-211: the wreck's SITE frame: its position and yaw without the roll (y = 0 the snow). The C-47 model
## (C47Wreck) and the loose pieces' colliders (data/gravelight/c47_colliders.json) are in it.
static func wreck_site_xf() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(28), 0)), Vector3(46, 0, 6))


## T-211: the colliders on the rolled hull besides its shell, in the wreck frame: [name, min, max]. Fitted to the
## C-47's art (tools/c47/c47_airframe.py: the wing's root chord z -2.45..2.0, its dihedral outboard of x -3.9).
const WRECK_WING_BOXES: Array = [
	["Wing", Vector3(-5.0, -1.4, -2.4), Vector3(-1.4, 0.62, 2.05)],
	["Wing", Vector3(-9.0, -1.4, -1.95), Vector3(-5.0, 0.88, 2.1)],
	["Nacelle", Vector3(-4.3, -0.6, -3.0), Vector3(-2.8, 1.36, 1.0)],
	["NoseCone", Vector3(-1.2, -0.4, -8.45), Vector3(1.2, 0.95, -7.2)],
	["CargoStack", Vector3(-1.15, WRECK_FLOOR, 4.4), Vector3(-0.45, 1.25, 5.15)],
]
const C47_COLLIDERS: String = "res://data/gravelight/c47_colliders.json"


## T-211: the C-47's loose pieces (the tail behind the split, both tailplanes, the starboard wing and its nacelle
## behind the fuselage, the port wing's outer panel in the snow, the port engine in the north field): oriented boxes
## the C-47 build fitted to the art (T-188: collision matches what you see), in the site frame. Cover, no perch.
func build_c47_debris() -> void:
	var site: Node3D = Node3D.new()
	site.name = "WreckSite"
	site.transform = wreck_site_xf()
	geo.add_child(site)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(C47_COLLIDERS))
	if not d is Dictionary:
		push_error("gen_map00: %s missing" % C47_COLLIDERS)
		return
	for b: Dictionary in (d as Dictionary).get("boxes", []):
		var c: Array = b["center"]
		var s: Array = b["size"]
		var m: Array = b["basis"]   # rows of the 3x3 (columns = the box's axes)
		var basis: Basis = Basis(Vector3(float(m[0][0]), float(m[1][0]), float(m[2][0])), Vector3(float(m[0][1]), float(m[1][1]), float(m[2][1])),
			Vector3(float(m[0][2]), float(m[1][2]), float(m[2][2])))
		var body: StaticBody3D = StaticBody3D.new()
		body.name = str(b["name"])
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = Transform3D(basis.orthonormalized(), Vector3(float(c[0]), float(c[1]), float(c[2])))
		body.set_meta("no_mantle", true)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
		cs.shape = shape
		body.add_child(cs)
		site.add_child(body)
		_count += 1


## A wall of the hull along z at x0..x1 from z0 to z1, full height, cut by the openings on `side`.
func _wreck_wall(wreck: Node3D, side: int, x0: float, x1: float, z0: float, z1: float) -> void:
	var cuts: Array = []
	for o: Array in WRECK_OPENINGS:
		if int(o[0]) == side:
			cuts.append(o)
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	var z: float = z0
	for o2: Array in cuts:
		var oz0: float = float(o2[1])
		var oz1: float = float(o2[2])
		if oz0 > z:
			box(wreck, "HullWall", Vector3(x0, WRECK_FLOOR, z), Vector3(x1, WRECK_TOP, oz0), "wreck", true, false).set_meta("no_mantle", true)
		if float(o2[3]) > WRECK_FLOOR:
			box(wreck, "HullSill", Vector3(x0, WRECK_FLOOR, oz0), Vector3(x1, float(o2[3]), oz1), "wreck", true, false).set_meta("no_mantle", true)
		box(wreck, "HullLintel", Vector3(x0, float(o2[4]), oz0), Vector3(x1, WRECK_TOP, oz1), "wreck", true, false).set_meta("no_mantle", true)
		z = oz1
	if z < z1:
		box(wreck, "HullWall", Vector3(x0, WRECK_FLOOR, z), Vector3(x1, WRECK_TOP, z1), "wreck", true, false).set_meta("no_mantle", true)


func build_wreck_hull(wreck: Node3D) -> void:
	var h: float = WRECK_HALF
	var w: float = WRECK_WALL
	# the floor (reaching into the snow: the hull is rolled) and the roof
	box(wreck, "HullFloor", Vector3(-h, -0.4, WRECK_NOSE_Z), Vector3(h, WRECK_FLOOR, WRECK_AFT_Z), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullRoof", Vector3(-h, WRECK_ROOF, WRECK_NOSE_Z - 0.3), Vector3(h, WRECK_TOP, WRECK_AFT_Z), "wreck", true, false).set_meta("no_mantle", true)
	_wreck_wall(wreck, -1, -h, -h + w, WRECK_NOSE_Z, WRECK_AFT_Z)
	_wreck_wall(wreck, 1, h - w, h, WRECK_NOSE_Z, WRECK_AFT_Z)
	# the nose: a front wall with the windscreen out
	var ws: Array = WRECK_OPENINGS[4]
	var nz0: float = WRECK_NOSE_Z - 0.3
	box(wreck, "HullNose", Vector3(-h, -0.4, nz0), Vector3(h, float(ws[3]), WRECK_NOSE_Z), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullNose", Vector3(-h, float(ws[3]), nz0), Vector3(float(ws[1]), WRECK_TOP, WRECK_NOSE_Z), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullNose", Vector3(float(ws[2]), float(ws[3]), nz0), Vector3(h, WRECK_TOP, WRECK_NOSE_Z), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullNose", Vector3(float(ws[1]), float(ws[4]), nz0), Vector3(float(ws[2]), WRECK_TOP, WRECK_NOSE_Z), "wreck", true, false).set_meta("no_mantle", true)
	# the cockpit bulkhead: its doorway (x -0.5..0.5) choked with wreckage to 1.15 m; open above to 2.05
	var bz0: float = WRECK_BULK_Z
	var bz1: float = WRECK_BULK_Z + 0.25
	box(wreck, "HullBulkhead", Vector3(-h + w, WRECK_FLOOR, bz0), Vector3(-0.5, WRECK_ROOF, bz1), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullBulkhead", Vector3(0.5, WRECK_FLOOR, bz0), Vector3(h - w, WRECK_ROOF, bz1), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "HullBulkhead", Vector3(-0.5, 2.05, bz0), Vector3(0.5, WRECK_ROOF, bz1), "wreck", true, false).set_meta("no_mantle", true)
	box(wreck, "CockpitChoke", Vector3(-0.5, WRECK_FLOOR, bz0 - 0.35), Vector3(0.5, 1.15, bz1), "wreck", true, false).set_meta("no_mantle", true)
	# the aft bulkhead and the tail cone behind it
	box(wreck, "HullTail", Vector3(-h, -0.4, WRECK_AFT_Z), Vector3(h, WRECK_TOP, 6.0), "wreck", true, false).set_meta("no_mantle", true)


## The hayloft (T-084): the west block, the gallery along the south wall with the stair well in its east end, the
## straight flight up the east wall (a smooth invisible ramp on the nosing line, so the capsule never catches a
## tread; the treads are dressing), the boarded store under it, the rails round every open edge (three collider
## bars, shots pass between them; hidden panels cut the navmesh at the edges for the bake only), the bale drop (a
## bay in the gallery's rail you can walk off; zombies don't path it), the bales and crates that are cover, and
## the hoist ledge outside the loft door over the yard that the loft window's zombies stand on.
func build_hayloft() -> void:
	box(geo, "Hayloft", Vector3(STB_X0, LOFT_Y, STB_Z0), Vector3(LOFT_X1, LOFT_TOP, STB_Z1), "floor_wood")
	box(geo, "HayGallery", Vector3(LOFT_X1, LOFT_Y, GAL_Z0), Vector3(HSTAIR_X0, LOFT_TOP, STB_Z1), "floor_wood")
	box(geo, "HayLanding", Vector3(HSTAIR_X0, LOFT_Y, HSTAIR_Z1), Vector3(STB_X1, LOFT_TOP, STB_Z1), "floor_wood")
	# the flight: the collider runs on the nosing line from the floor one tread before the first riser to the landing
	ramp_z("HayStairs", HSTAIR_X0, HSTAIR_X1, HSTAIR_Z0, HSTAIR_Z1, 0.0, LOFT_TOP, -1e9, false)
	_stair_dressing.pop_back()   # drawn by _dress_hay_stairs, not the generic sawtooth
	# the boarded store under the flight: solid up to the soffit, so nothing walks or paths under it
	var run: float = HSTAIR_Z1 - HSTAIR_Z0
	var zc: float = HSTAIR_Z0 + 0.5
	while zc < HSTAIR_Z1 - 0.01:
		var zn: float = minf(zc + 0.5, HSTAIR_Z1)
		var soffit: float = LOFT_TOP * (zc - HSTAIR_Z0) / run - 0.32
		if soffit > 0.05:
			box(geo, "HayStairUnder", Vector3(HSTAIR_X0, 0, zc), Vector3(HSTAIR_X1, soffit, zn), "stable", true, false)
		zc = zn
	# rails: [from, to] along the loft's open edges at floor level (the bars sit on top of the slab); the flight's
	# own rail climbs with it. The bale drop is left open.
	var rails: Array = [
		[Vector3(LOFT_X1 - 0.05, LOFT_TOP, STB_Z0 + T * 0.5), Vector3(LOFT_X1 - 0.05, LOFT_TOP, GAL_Z0 - 0.05)],
		[Vector3(LOFT_X1 - 0.05, LOFT_TOP, GAL_Z0 + 0.05), Vector3(LOFT_DROP.x, LOFT_TOP, GAL_Z0 + 0.05)],
		[Vector3(LOFT_DROP.y, LOFT_TOP, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, GAL_Z0 + 0.05)],
		[Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1)],
		[Vector3(HSTAIR_X0 - 0.05, 0.0, HSTAIR_Z0), Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1)],
	]
	for r: Array in rails:
		for b: Array in [[0.06, 0.06, 0.12], [0.5, 0.035, 0.04], [1.0, 0.07, 0.07]]:   # [centre height, width, height]
			var hy: float = float(b[0])
			bar(geo, "LoftRail", (r[0] as Vector3) + Vector3(0, hy, 0), (r[1] as Vector3) + Vector3(0, hy, 0), float(b[1]), float(b[2]), "furniture")
	# the bake's view of the rails: hidden panels (freed after the bake) along the edges, the drop included, and
	# stepped along the flight's open side so the bake never joins the ramp to the floor beside it
	var panels: Array = [
		[Vector3(LOFT_X1 - 0.13, LOFT_TOP, STB_Z0), Vector3(LOFT_X1 + 0.03, LOFT_TOP + 1.2, GAL_Z0 + 0.08)],
		[Vector3(LOFT_X1 - 0.13, LOFT_TOP, GAL_Z0 - 0.08), Vector3(HSTAIR_X0 + 0.03, LOFT_TOP + 1.2, GAL_Z0 + 0.08)],
		[Vector3(HSTAIR_X0 - 0.13, LOFT_TOP, GAL_Z0 - 0.08), Vector3(HSTAIR_X0 + 0.03, LOFT_TOP + 1.2, HSTAIR_Z1 + 0.08)],
	]
	var zp: float = HSTAIR_Z0 - 0.4
	while zp < HSTAIR_Z1:
		var zq: float = minf(zp + 0.5, HSTAIR_Z1)
		var top: float = LOFT_TOP * (zq - HSTAIR_Z0) / run + 1.2
		panels.append([Vector3(HSTAIR_X0 - 0.13, 0.0, zp), Vector3(HSTAIR_X0 + 0.03, top, zq)])
		zp = zq
	for pn: Array in panels:
		var p: Node3D = box(geo, "LoftRailBake", pn[0], pn[1], "wall", true, false)
		if p != null:
			_bake_only.append(p)
	# cover up there: the bale stack in the south-west corner (PERSIST_HIDDEN: shots pit it), single bales along the
	# gallery's rail to crouch behind, two crates (one the carter's salt-lamp crate, MAPS.md)
	box(geo, "HayBales", Vector3(STB_X0 + 0.3, LOFT_TOP, 30.5), Vector3(STB_X0 + 3.5, LOFT_TOP + 0.9, 33.7), "hay", true, false)
	var tbi: int = 0
	for tb: Array in LOFT_TOP_BALES:   # T-238: the third course started in the corner, solid like the rest
		tbi += 1
		var tc: Vector3 = tb[0]
		var th: Vector3 = Vector3(0.53, 0, 0.265) if absf(fmod(float(tb[1]), 180.0)) < 45.0 else Vector3(0.265, 0, 0.53)
		box(geo, "LoftBaleTop%d" % tbi, tc - th, tc + th + Vector3(0, 0.45, 0), "hay", true, false).set_meta("decal_persist", true)
	# T-238: the bales downstairs, two high against the north wall between the north door and the stair's approach
	# (they stood, without a collider, in the door's lane)
	box(geo, "StableBales", STABLE_BALES.position, STABLE_BALES.end, "hay", true, false).set_meta("decal_persist", true)
	for hb: Array in LOFT_BALES:
		var c: Vector3 = hb[0]
		var yaw: float = float(hb[1])
		var hw: Vector3 = Vector3(0.5, 0, 0.3) if absf(fmod(yaw, 180.0)) < 45.0 else Vector3(0.3, 0, 0.5)
		box(geo, "LoftBale", c - hw, c + hw + Vector3(0, 0.47, 0), "hay", true, false).set_meta("decal_persist", true)
	for cr: Array in LOFT_CRATES:
		var cc: Vector3 = cr[0]
		var s: float = float(cr[1]) * 0.5
		box(geo, "LoftCrate", cc - Vector3(s, 0, s), cc + Vector3(s, 2.0 * s, s), "planks", true, false).set_meta("decal_persist", true)
	# the hoist ledge outside the loft door (the loft window's zombies stand on it, like the porch-roof ledges)
	box(geo, "LoftLedge", Vector3(20.0, LOFT_Y, STB_Z1 + T * 0.5), Vector3(25.2, LOFT_TOP, 36.6), "planks")


## Single bales on the loft that are cover (and drawn by _dress_stable): [floor position (y LOFT_TOP), yaw].
const LOFT_BALES: Array = [[Vector3(17.2, LOFT_TOP, 29.95), 0.0], [Vector3(18.1, LOFT_TOP, 29.95), 0.0], [Vector3(21.6, LOFT_TOP, 30.0), 0.0],
	[Vector3(LOFT_X1 - 0.65, LOFT_TOP, 24.4), 90.0], [Vector3(LOFT_X1 - 0.65, LOFT_TOP, 25.5), 90.0], [Vector3(LOFT_X1 - 1.1, LOFT_TOP, 27.4), 90.0]]
## T-238: the stack's third course, started in the south-west corner on top of HayBales: [foot position, yaw].
const LOFT_TOP_BALES: Array = [[Vector3(STB_X0 + 0.84, LOFT_TOP + 0.9, 33.42), 0.0], [Vector3(STB_X0 + 1.92, LOFT_TOP + 0.9, 33.42), 0.0],
	[Vector3(STB_X0 + 0.58, LOFT_TOP + 0.9, 32.6), 90.0]]
## T-238: the stable's bales on the ground floor: a 1.8 x 0.9 x 0.52 m stack against the north wall, east of the north
## door (x 18.5..21.5) and west of the stair's approach (x 23.35+), behind the hay heap and its ground spawn (22.5, 23.7).
const STABLE_BALES: AABB = AABB(Vector3(21.62, 0.0, STB_Z0 + 0.15), Vector3(1.8, 0.9, 0.52))
## Crates on the loft: [floor position, size, yaw, stencil] (the salt-lamp crate over the great doors, MAPS.md).
const LOFT_CRATES: Array = [[Vector3(16.9, LOFT_TOP, 33.1), 0.9, 12.0, ""], [Vector3(6.2, LOFT_TOP, 23.0), 0.75, -8.0, ""]]


## T-224: the attic (see ATT_* / ASTAIR_*). The old UpRoof slab is the attic floor, cut by the stair well; the walls stand
## on it (plaster faces under the eaves to the north and south, boarded gables west and east, each with a hoist window
## over a ledge outside); a boarded ceiling under the raised gable roof; the chimney breast on the north wall. The
## flight along the hall's south wall: a smooth invisible ramp on the nosing line (the treads are dressing), the
## under-stair solid, three collider bars up its open north side and round the well's north and west edges (balusters are
## dressing; hidden panels along the same lines for the bake only, so the bake never joins the ramp to the hall floor
## beside it, nor the attic floor to the flight's head over the rail).
func build_attic() -> void:
	var hx: float = ASTAIR_HOLE_X0
	box(geo, "AttFloorW", Vector3(-T * 0.5, UP_TOP, -T * 0.5), Vector3(hx, ATT_Y, 10 + T * 0.5), "floor_wood")
	box(geo, "AttFloorM", Vector3(hx, UP_TOP, -T * 0.5), Vector3(ASTAIR_X1, ATT_Y, ASTAIR_Z0), "floor_wood")
	box(geo, "AttFloorE", Vector3(ASTAIR_X1, UP_TOP, -T * 0.5), Vector3(24 + T * 0.5, ATT_Y, 10 + T * 0.5), "floor_wood")
	var att_win: Array = [ATT_Y + WIN_SILL, ATT_Y + WIN_TOP]
	wall_x("AttN", 0.0, -T * 0.5, 24 + T * 0.5, ATT_Y, ATT_TOP, [], "wall_upper")
	wall_x("AttS", 10.0, -T * 0.5, 24 + T * 0.5, ATT_Y, ATT_TOP, [], "wall_upper")
	wall_z("AttW", 0.0, 0, 10, ATT_Y, ATT_TOP, [[ATT_WIN_Z - 0.8, ATT_WIN_Z + 0.8] + att_win], "stable")
	wall_z("AttE", 24.0, 0, 10, ATT_Y, ATT_TOP, [[ATT_WIN_Z - 0.8, ATT_WIN_Z + 0.8] + att_win], "stable")
	box(geo, "AttRoof", Vector3(-T * 0.5, ATT_TOP, -T * 0.5), Vector3(24 + T * 0.5, ATT_TOP + 0.2, 10 + T * 0.5), "roof")
	box(geo, "AttChimney", Vector3(11.1, ATT_Y, 0.15), Vector3(12.9, ATT_TOP, 0.85), "stone")
	# the hoist ledges outside the gable windows (the attic windows' zombies stand on them, like the porch roofs')
	box(geo, "AttLedgeW", Vector3(-2.3, ATT_Y - 0.3, ATT_WIN_Z - 2.2), Vector3(-T * 0.5, ATT_Y, ATT_WIN_Z + 2.2), "planks")
	box(geo, "AttLedgeE", Vector3(24 + T * 0.5, ATT_Y - 0.3, ATT_WIN_Z - 2.2), Vector3(26.3, ATT_Y, ATT_WIN_Z + 2.2), "planks")
	# the flight: a smooth ramp on the nosing line (ramp_x: along X), the under-stair solid up to the soffit
	# (the ramp starts one tread before the first riser, so the nosing of every tread lies on it: 15 treads of
	# ASTAIR_STEP and the attic floor as the 16th rise, _astair_y)
	ramp_x("AttStairs", ASTAIR_Z0, ASTAIR_Z1, ASTAIR_X0 - ASTAIR_STEP, ASTAIR_X1, UP_Y, ATT_Y)
	var xa: float = ASTAIR_X0 + 0.5
	while xa < ASTAIR_X1 - 0.01:
		var xb: float = minf(xa + 0.5, ASTAIR_X1)
		var soffit: float = _astair_y(xa) - 0.42
		if soffit > UP_Y + 0.05:
			box(geo, "AttStairUnder", Vector3(xa, UP_Y, ASTAIR_Z0), Vector3(xb, soffit, ASTAIR_Z1), "wall", true, false)
		xa = xb
	# rails: up the flight's open north side, then round the well on the attic floor (north edge and west end)
	var rz: float = ASTAIR_Z0 + 0.05
	for r: Array in [[0.06, 0.06, 0.12], [0.47, 0.035, 0.04], [0.92, 0.07, 0.07]]:   # [centre height, width, height]
		var hy: float = float(r[0])
		bar(geo, "AttStairRail", Vector3(ASTAIR_X0, UP_Y + hy, rz), Vector3(ASTAIR_X1, ATT_Y + hy, rz), float(r[1]), float(r[2]), "furniture")
		bar(geo, "AttWellRail", Vector3(hx, ATT_Y + hy, rz), Vector3(ASTAIR_X1 + 0.03, ATT_Y + hy, rz), float(r[1]), float(r[2]), "furniture")
		bar(geo, "AttWellRail", Vector3(hx + 0.05, ATT_Y + hy, ASTAIR_Z0), Vector3(hx + 0.05, ATT_Y + hy, ASTAIR_Z1), float(r[1]), float(r[2]), "furniture")
	# the bake's view of the rails: hidden panels (freed after the bake) stepped along the flight's side and along the
	# well's north edge at attic level (the attic floor is only 0.2 m over the flight's last tread there: under max_climb)
	var panels: Array = [[Vector3(hx - 0.08, ATT_Y, ASTAIR_Z0 - 0.08), Vector3(ASTAIR_X1 + 0.08, ATT_Y + 1.2, ASTAIR_Z0 + 0.08)],
		[Vector3(hx - 0.03, ATT_Y, ASTAIR_Z0 - 0.08), Vector3(hx + 0.13, ATT_Y + 1.2, ASTAIR_Z1)]]
	var xp: float = ASTAIR_X0 - 0.8
	while xp < ASTAIR_X1:
		var xq: float = minf(xp + 0.5, ASTAIR_X1)
		var top: float = _astair_y(xq) + 1.2
		panels.append([Vector3(xp, UP_Y, ASTAIR_Z0 - 0.08), Vector3(xq, top, ASTAIR_Z0 + 0.08)])
		xp = xq
	for pn: Array in panels:
		var p: Node3D = box(geo, "AttRailBake", pn[0], pn[1], "wall", true, false)
		if p != null:
			_bake_only.append(p)
	# the stored things that are cover up there (drawn by _dress_attic): [name, min, max]
	for s: Array in ATT_SOLIDS:
		box(geo, str(s[0]), s[1], s[2], "furniture", true, false).set_meta("decal_persist", true)


## The attic's solid stored things (hidden colliders; _dress_attic draws them). Along the north wall and in the
## south-west corner, out of the zombies' way in from the two gable windows (x 0..3 and 21..24 at z 2.5..6.5 stay clear)
## and off the line from the stair head to the windows. [name, min corner, max corner].
const ATT_SOLIDS: Array = [
	["AttTrunk1", Vector3(4.2, ATT_Y, 0.4), Vector3(5.4, ATT_Y + 0.6, 1.2)],      # the husband's war trunk, KRAUSE 1916
	["AttTrunk2", Vector3(5.6, ATT_Y, 0.35), Vector3(6.7, ATT_Y + 0.55, 1.05)],
	["AttTrunk3", Vector3(14.2, ATT_Y, 0.4), Vector3(15.5, ATT_Y + 0.62, 1.15)],
	["AttWardrobe", Vector3(20.0, ATT_Y, 0.2), Vector3(21.4, ATT_Y + 1.9, 0.85)],   # the old wardrobe, its door off (east of the BAR's chalk)
	["AttCrates", Vector3(1.0, ATT_Y, 7.9), Vector3(2.7, ATT_Y + 0.8, 9.7)],       # the Christmas boxes in the south-west corner
	["AttBedstead", Vector3(19.5, ATT_Y, 8.6), Vector3(23.6, ATT_Y + 0.9, 9.6)],   # iron bedsteads stacked against the south wall
	["AttAppleRack", Vector3(7.0, ATT_Y, 0.3), Vector3(9.4, ATT_Y + 1.5, 0.9)],   # the apple racks under the north eaves
]


## A straight ramp (stairs) along X between two heights (T-224, the attic flight): the collider is one slab on the
## nosing line between x_low (the foot) and x_high (the head), z0..z1 wide. Treads and rails are dressing.
func ramp_x(name_: String, z0: float, z1: float, x_low: float, x_high: float, y_low: float, y_high: float) -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var angle: float = atan2(rise, run)
	var dir: float = sign(x_high - x_low)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	var thick: float = 0.2
	var mid: Vector3 = Vector3((x_low + x_high) * 0.5, (y_low + y_high) * 0.5, (z0 + z1) * 0.5)
	var basis: Basis = Basis(Vector3.BACK, angle * dir)   # about +Z: +X turns toward +Y, so the slab rises toward x_high
	var up: Vector3 = basis * Vector3.UP
	body.transform = Transform3D(basis, mid - up * thick * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(length, thick, absf(z1 - z0))
	cs.shape = shape
	body.add_child(cs)
	geo.add_child(body)
	_count += 1


## Height of the attic flight's tread line at x.
func _astair_y(x: float) -> float:
	var foot: float = ASTAIR_X0 - ASTAIR_STEP
	return UP_Y + (ATT_Y - UP_Y) * clampf((x - foot) / (ASTAIR_X1 - foot), 0.0, 1.0)


## THE CARTERS' YARD (zone YARD, "go outside"): the fenced forecourt south of the stable, x 2..34, z 34..48, out of
## the stable's new south door (Door 4, 1250). Fences are invisible 2.3 m colliders (the player can jump; the
## drawn fence is 1.2 m) with four barricaded gaps zombies vault, a barred gate on the carters' road, the well,
## a woodpile and a snowed cart to run round. The field beyond stays navmesh for the window zombies.
func build_yard() -> void:
	var fh: float = 2.3
	var win: Array = [WIN_SILL, WIN_TOP]
	# west fence (x 2) with a gap at z 40.2..41.8; east fence (x 34) with a gap at z 40.2..41.8
	for fx: float in [2.0, 34.0]:
		_fence_box(geo, "YardFence", Vector3(fx - 0.1, 0, 34.0), Vector3(fx + 0.1, fh, 40.2))
		_fence_box(geo, "YardFence", Vector3(fx - 0.1, 0, 41.8), Vector3(fx + 0.1, fh, 48.1))
		box(geo, "YardSill", Vector3(fx - 0.1, 0, 40.2), Vector3(fx + 0.1, WIN_SILL, 41.8), "snow", true, false)
		box(geo, "YardTop", Vector3(fx - 0.1, WIN_TOP, 40.2), Vector3(fx + 0.1, fh, 41.8), "snow", true, false)
	# south fence (z 48) with gaps at x 8.2..9.8 and 26.2..27.8, and the barred gate at x 16..20
	for seg: Array in [[2.0, 8.2], [9.8, 16.0], [20.0, 26.2], [27.8, 34.0]]:
		_fence_box(geo, "YardFence", Vector3(float(seg[0]), 0, 47.9), Vector3(float(seg[1]), fh, 48.1))
	for gx: float in [8.2, 26.2]:
		box(geo, "YardSill", Vector3(gx, 0, 47.9), Vector3(gx + 1.6, WIN_SILL, 48.1), "snow", true, false)
		box(geo, "YardTop", Vector3(gx, WIN_TOP, 47.9), Vector3(gx + 1.6, fh, 48.1), "snow", true, false)
	# (the barred gate at x 16..20 is a bought door since T-080, Door_Gate: not baked, its own collider shuts it)
	# the plot's north edges beside the stable (keeps the yard off the cellar's roof and the inn's east side)
	_fence_box(geo, "YardFence", Vector3(STB_X1, 0, 33.9), Vector3(34.1, fh, 34.1))
	_fence_box(geo, "YardFence", Vector3(1.9, 0, 33.9), Vector3(STB_X0, fh, 34.1))
	# the well, the woodpile against the stable, the snowed cart
	box(geo, "Well", Vector3(9.0, 0, 41.0), Vector3(11.0, 1.0, 43.0), "stone", true, false)
	box(geo, "Woodpile", Vector3(13.3, 0, 34.15), Vector3(15.9, 1.3, 35.4), "furniture", true, false)   # east of the window W_STB_S (x 11.2..12.8), which the zombies need clear (T-040)
	box(geo, "YardCart", Vector3(27.0, 0, 37.0), Vector3(29.6, 1.1, 39.2), "furniture", true, false)
	box(geo, "YardTrough", Vector3(30.5, 0, 44.0), Vector3(33.5, 0.7, 45.0), "furniture", true, false)
	# T-229 / T-268: the watchtower (TOWER_*): four legs up to the top platform, the two deck slabs, three collider bars
	# round each deck's edge (nobody walks off; T-275: the landing's is open 1 m for the lower ladder, the top's slab is
	# cut round the upper ladder's hatch), and the three zip lines' landing posts
	for lx: float in [TOWER_X - TOWER_LEG, TOWER_X + TOWER_LEG]:
		for lz: float in [TOWER_Z - TOWER_LEG, TOWER_Z + TOWER_LEG]:
			box(geo, "TowerLeg", Vector3(lx - 0.13, 0, lz - 0.13), Vector3(lx + 0.13, TOWER_TOP - 0.2, lz + 0.13), "beam")
	for deck_y: float in [TOWER_DECK, TOWER_TOP]:
		for dr: Rect2 in _tower_floor_rects(deck_y):   # (T-275: the top's slab is cut round the hatch)
			box(geo, "TowerDeck", Vector3(dr.position.x, deck_y - 0.2, dr.position.y), Vector3(dr.end.x, deck_y, dr.end.y), "planks")
		var tc: Array = [Vector3(TOWER_X - TOWER_HALF + 0.05, 0, TOWER_Z - TOWER_HALF + 0.05), Vector3(TOWER_X + TOWER_HALF - 0.05, 0, TOWER_Z - TOWER_HALF + 0.05),
			Vector3(TOWER_X + TOWER_HALF - 0.05, 0, TOWER_Z + TOWER_HALF - 0.05), Vector3(TOWER_X - TOWER_HALF + 0.05, 0, TOWER_Z + TOWER_HALF - 0.05)]
		for k: int in 4:
			var runs: Array = [[tc[k], tc[(k + 1) % 4]]]
			if deck_y == TOWER_DECK and k == 0:   # T-275: the landing's north side opens for the lower ladder
				runs = [[tc[0], Vector3(TOWER_X - TOWER_GAP_HALF, 0, tc[0].z)], [Vector3(TOWER_X + TOWER_GAP_HALF, 0, tc[0].z), tc[1]]]
			for run: Array in runs:
				for r: Array in [[0.06, 0.06, 0.12], [0.55, 0.035, 0.04], [1.05, 0.07, 0.07]]:   # [centre height over the deck, width, height]
					var hy: float = deck_y + float(r[0])
					bar(geo, "TowerRail", (run[0] as Vector3) + Vector3(0, hy, 0), (run[1] as Vector3) + Vector3(0, hy, 0), float(r[1]), float(r[2]), "beam")
	# T-275: the hatch's guard rail on the top platform (north and west sides; the parapet is its east side, the upper
	# ladder's head its open south side), the upper ladder's stiles (the landing to the hand holds over the top: two
	# poles 0.35 m apart, so nobody walks between them or past them into the hatch) and the lower ladder's hand holds
	# in the landing's opening (likewise: nobody walks off the landing through the opening)
	var hx0: float = TOWER_HATCH_X0 - 0.03
	var hz0: float = TOWER_HATCH_Z0 - 0.03
	for r2: Array in [[0.06, 0.06, 0.12], [0.55, 0.035, 0.04], [1.05, 0.07, 0.07]]:
		var hy2: float = TOWER_TOP + float(r2[0])
		bar(geo, "TowerHatchRail", Vector3(hx0, hy2, hz0), Vector3(TOWER_HATCH_X1 + 0.02, hy2, hz0), float(r2[1]), float(r2[2]), "beam")
		bar(geo, "TowerHatchRail", Vector3(hx0, hy2, hz0), Vector3(hx0, hy2, TOWER_HATCH_Z1), float(r2[1]), float(r2[2]), "beam")
	for sx: float in [-0.2, 0.2]:
		box(geo, "TowerLadderStile", Vector3(TOWER_LADDER2_X + sx - 0.025, TOWER_DECK, TOWER_HATCH_Z1 - 0.14), Vector3(TOWER_LADDER2_X + sx + 0.025, TOWER_TOP + TOWER_HOLD_H, TOWER_HATCH_Z1 - 0.09), "beam", true, false)
		var l1z: float = TOWER_Z - TOWER_HALF - 0.02
		box(geo, "TowerLadderStile", Vector3(TOWER_X + sx - 0.025, TOWER_DECK, l1z - 0.14), Vector3(TOWER_X + sx + 0.025, TOWER_DECK + TOWER_HOLD_H, l1z - 0.09), "beam", true, false)
	for zl: Array in ZIP_LINES:
		var zp: Vector3 = zl[2]
		box(geo, "ZipPost_" + str(zl[0]), zp + Vector3(-0.12, 0, -0.12), zp + Vector3(0.12, ZIP_POST_H + 0.15, 0.12), "beam")


## T-229 / T-268: the watchtower over the yard's south-west corner, a carters' Hochsitz built up into a two-stage
## timber tower. Four heavy legs on stone pads, strapped in iron; each stage cross-braced on all four faces above head
## height (nobody walks through a brace, on the ground or on the landing) with ring beams; the landing at TOWER_DECK
## and the top platform at TOWER_TOP, both boarded behind a parapet on the rail bars with a plank cap and sandbags on
## the field sides; four roof posts under a gable roof with its snow; a mast
## over the ridge with a pennant and a red lamp; the ladder up the north face to the landing through an opening in its
## parapet and a second inside the tower from the landing up through a hatch in the top's floor (T-275; the
## LadderClimbs stand at their feet and heads); lanterns at the foot, on the landing and under
## the roof; the searchlight on the roof's east gable (its light is _tower_lights'); and the three zip lines
## (ZIP_LINES): a bracket and a marker lantern on a roof post, the cable down to its landing post with a stay, a
## lantern, a snow cap, a coil of rope and the trodden snow where you land (the trolleys are the ZipLines' own).
func _dress_tower(g: Node3D) -> void:
	var cx: float = TOWER_X
	var cz: float = TOWER_Z
	var h: float = TOWER_HALF
	var lg: float = TOWER_LEG
	var d1: float = TOWER_DECK
	var d2: float = TOWER_TOP
	var legs: Array = [Vector3(cx - lg, 0, cz - lg), Vector3(cx + lg, 0, cz - lg), Vector3(cx + lg, 0, cz + lg), Vector3(cx - lg, 0, cz + lg)]
	# the feet: a stone pad, an iron strap, a snow skirt
	for leg: Vector3 in legs:
		Props.block(g, leg + Vector3(-0.3, 0, -0.3), leg + Vector3(0.3, 0.22, 0.3), "stone")
		Props._noshadow(Props.block(g, leg + Vector3(-0.15, 0.5, -0.15), leg + Vector3(0.15, 0.62, 0.15), "iron"))
		Props._noshadow(Props.block(g, leg + Vector3(-0.15, d1 + 1.3, -0.15), leg + Vector3(0.15, d1 + 1.42, 0.15), "iron"))
		Props._noshadow(Props.block(g, leg + Vector3(-0.36, 0.2, -0.36), leg + Vector3(0.36, 0.28, 0.36), "snow"))
	# the bracing: one tall cross a face per stage, a ring beam under and over it, all above head height
	for tier: Array in [[2.45, d1 - 0.55], [d1 + 2.35, d2 - 0.55]]:
		var y0: float = float(tier[0])
		var y1: float = float(tier[1])
		for k: int in 4:
			var a: Vector3 = legs[k]
			var b: Vector3 = legs[(k + 1) % 4]
			Props.strut(g, a + Vector3(0, y0, 0), b + Vector3(0, y1, 0), 0.12, "beam")
			Props.strut(g, a + Vector3(0, y1, 0), b + Vector3(0, y0, 0), 0.12, "beam")
			Props.strut(g, a + Vector3(0, y0 - 0.08, 0), b + Vector3(0, y0 - 0.08, 0), 0.15, "beam")   # the ring beams
			Props.strut(g, a + Vector3(0, y1 + 0.08, 0), b + Vector3(0, y1 + 0.08, 0), 0.15, "beam")
			var mid: Vector3 = (a + b) * 0.5 + Vector3(0, (y0 + y1) * 0.5, 0)   # the iron plate where the cross meets
			var out: Vector3 = (mid - Vector3(cx, mid.y, cz)).normalized()
			Props._noshadow(Props.obox(g, mid + out * 0.07, Vector3(0.3, 0.3, 0.03) if absf(out.z) > 0.5 else Vector3(0.03, 0.3, 0.3), "iron"))
	# knee braces from the legs out under each deck's overhang
	for dy: float in [d1, d2]:
		for k2: int in 4:
			var a2: Vector3 = legs[k2]
			var b2: Vector3 = legs[(k2 + 1) % 4]
			Props.strut(g, a2 + Vector3(0, dy - 0.3, 0), b2 + Vector3(0, dy - 0.3, 0), 0.18, "beam")   # the bearers
			var c2: Vector3 = Vector3(cx, 0, cz)
			var o2: Vector3 = (a2 - c2).normalized()
			Props.strut(g, a2 + Vector3(0, dy - 1.2, 0), a2 + o2 * 0.38 + Vector3(0, dy - 0.24, 0), 0.1, "beam")
		for j: int in 5:   # the joists' ends showing under the edge
			var jx: float = cx - h + 0.4 + j * (2.0 * h - 0.8) / 4.0
			Props._noshadow(Props.block(g, Vector3(jx - 0.05, dy - 0.3, cz - h - 0.06), Vector3(jx + 0.05, dy - 0.2, cz + h + 0.06), "beam"))
		for fr: Rect2 in _tower_floor_rects(dy):
			Props.block(g, Vector3(fr.position.x, dy, fr.position.y), Vector3(fr.end.x, dy + 0.012, fr.end.y), "floorboards")
		_tower_parapet(g, dy)
	# the top: roof posts at the corners, the plates, the gable roof, the mast with its pennant and red lamp
	for px: float in [cx - h + 0.1, cx + h - 0.1]:
		for pz: float in [cz - h + 0.1, cz + h - 0.1]:
			Props.block(g, Vector3(px - 0.09, d2, pz - 0.09), Vector3(px + 0.09, d2 + 2.3, pz + 0.09), "beam")
	for pz2: float in [cz - h + 0.1, cz + h - 0.1]:
		Props.block(g, Vector3(cx - h - 0.3, d2 + 2.14, pz2 - 0.08), Vector3(cx + h + 0.3, d2 + 2.3, pz2 + 0.08), "beam")   # the plates
	for px2: float in [cx - h + 0.1, cx + h - 0.1]:
		Props.block(g, Vector3(px2 - 0.07, d2 + 2.0, cz - h + 0.1), Vector3(px2 + 0.07, d2 + 2.14, cz + h - 0.1), "beam")
	Props.gable_roof(g, Vector3(cx - h - 0.45, d2 + 2.25, cz - h - 0.45), Vector3(cx + h + 0.45, d2 + 2.25, cz + h + 0.45), 1.05, true)
	Props.block(g, Vector3(cx - 0.07, d2 + 2.3, cz - 0.07), Vector3(cx + 0.07, d2 + 6.8, cz + 0.07), "beam")   # the mast (3.5 m over the ridge: from the yard the eaves hide anything shorter)
	Props._noshadow(Props.obox(g, Vector3(cx + 0.55, d2 + 6.1, cz + 0.05), Vector3(0.95, 0.8, 0.03), "cloth_red", Vector3(0, 8, -9)))   # the pennant, hanging frozen
	Props._noshadow(Props.block(g, Vector3(cx - 0.09, d2 + 6.8, cz - 0.09), Vector3(cx + 0.09, d2 + 6.86, cz + 0.09), "iron"))
	Props._noshadow(Props.block(g, Vector3(cx - 0.09, d2 + 6.86, cz - 0.09), Vector3(cx + 0.09, d2 + 7.1, cz + 0.09), "lamp_red_lit", false))
	Props._noshadow(Props.block(g, Vector3(cx - 0.12, d2 + 7.1, cz - 0.12), Vector3(cx + 0.12, d2 + 7.14, cz + 0.12), "iron"))
	# the ladders (T-275): the north face up to the landing, arriving in the parapet's opening; inside the tower from
	# the landing up through the top platform's hatch. Rungs up to the floor each arrives on, the stiles carried on
	# TOWER_HOLD_H over it as hand holds and bent over onto that floor.
	_tower_ladder(g, Vector3(cx, 0, cz - h - 0.02), d1)
	_tower_ladder(g, Vector3(TOWER_LADDER2_X, d1, TOWER_HATCH_Z1), d2 - d1)
	for sx2: float in [-0.2, 0.2]:   # the upper ladder's cleats to the hatch's trimmer, under the top's boards
		Props._noshadow(Props.block(g, Vector3(TOWER_LADDER2_X + sx2 - 0.035, d2 - 0.36, TOWER_HATCH_Z1 - 0.15), Vector3(TOWER_LADDER2_X + sx2 + 0.035, d2 - 0.3, TOWER_HATCH_Z1), "iron"))
	# the hatch (T-275): its trimmers under the boards (between the joists at x 6.4 and 7.4) and the guard rail's
	# posts (its rails are the colliders' own meshes, build_geometry)
	for tz: float in [TOWER_HATCH_Z0 - 0.1, TOWER_HATCH_Z1]:
		Props.block(g, Vector3(TOWER_HATCH_X0, d2 - 0.3, tz), Vector3(TOWER_HATCH_X1 + 0.05, d2 - 0.2, tz + 0.1), "beam")
	for hp: Vector3 in [Vector3(TOWER_HATCH_X0 - 0.03, 0, TOWER_HATCH_Z0 - 0.03), Vector3(TOWER_HATCH_X0 - 0.03, 0, TOWER_HATCH_Z1 - 0.05), Vector3(TOWER_HATCH_X1 - 0.12, 0, TOWER_HATCH_Z0 - 0.03)]:
		Props.block(g, Vector3(hp.x - 0.045, d2, hp.z - 0.045), Vector3(hp.x + 0.045, d2 + 1.12, hp.z + 0.045), "beam")
	# lanterns: three down the yard-side (north-east) corner, one on the field (south-west) corner, one under the roof
	for lan: Array in [[1.0, 2.3], [1.0, d1 - 0.9], [1.0, d2 - 0.9], [-1.0, d1 - 0.9]]:   # an iron arm off the corner, a lantern hung on it (_tower_lights)
		var sgn: float = float(lan[0])
		var leg_c: Vector3 = Vector3(cx + sgn * lg, float(lan[1]) + 0.32, cz - sgn * lg)
		var tip: Vector3 = Vector3(cx + sgn * (h + 0.55), float(lan[1]) + 0.32, cz - sgn * (h + 0.55))
		Props._noshadow(Props.strut(g, leg_c, tip, 0.04, "iron"))
		Props._noshadow(Props.block(g, tip + Vector3(-0.01, -0.2, -0.01), tip + Vector3(0.01, 0.0, 0.01), "iron"))
		Props._noshadow(Props.block(g, tip + Vector3(-0.08, -0.42, -0.08), tip + Vector3(0.08, -0.2, 0.08), "lantern_glass", false))
		Props._noshadow(Props.block(g, tip + Vector3(-0.1, -0.2, -0.1), tip + Vector3(0.1, -0.17, 0.1), "iron"))
	Props.lantern(g, Vector3(cx, d2 + 2.05, cz), d2 + 2.6)   # (up in the gable, over head height: at 1.6 m it hung in the squad's faces)
	# sandbags on the caps of the field sides, a crate and a bucket on each deck, a cartridge box on the top
	Props.sandbags(g, Vector3(cx - h + 0.3, d2 + 1.14, cz + h - 0.2), Vector3(cx + h - 0.3, d2 + 1.14, cz + h - 0.2), 1)
	Props.sandbags(g, Vector3(cx - h + 0.2, d2 + 1.14, cz - h + 0.5), Vector3(cx - h + 0.2, d2 + 1.14, cz + h - 0.5), 1)
	Props.sandbags(g, Vector3(cx - h + 0.6, d2 + 1.14, cz - h + 0.2), Vector3(cx + h - 1.6, d2 + 1.14, cz - h + 0.2), 1)
	Props.sandbags(g, Vector3(cx - h + 0.3, d1 + 1.14, cz + h - 0.2), Vector3(cx + h - 0.3, d1 + 1.14, cz + h - 0.2), 1)
	Props.sandbags(g, Vector3(cx - h + 0.2, d1 + 1.14, cz - h + 0.5), Vector3(cx - h + 0.2, d1 + 1.14, cz + h - 0.5), 1)
	Props.crate(g, Vector3(cx - 1.55, d2, cz + 1.55), 0.5, 12.0)
	Props.cyl(g, Vector3(cx - 1.5, d2 + 0.16, cz + 0.6), 0.15, 0.32, "zinc")
	Props.crate(g, Vector3(cx - 1.55, d1, cz + 1.5), 0.55, -8.0)
	Props.rope_coil(g, Vector3(cx + 1.3, d1, cz + 1.5), 0.2)
	# the searchlight: a drum on a yoke bracketed to the roof's east gable, over everyone's head (on the parapet's
	# corner it stood in the face of whoever took the yard's zip line), aimed over the yard at the gate
	var sl: Vector3 = TOWER_SEARCHLIGHT
	Props.block(g, Vector3(cx + h + 0.4, sl.y - 0.42, sl.z - 0.05), Vector3(sl.x + 0.05, sl.y - 0.32, sl.z + 0.05), "iron")
	Props.block(g, Vector3(sl.x - 0.04, sl.y - 0.42, sl.z - 0.04), Vector3(sl.x + 0.04, sl.y - 0.26, sl.z + 0.04), "iron")
	var drum: Node3D = Props.group(g, "SearchlightDrum", sl)
	drum.transform = Transform3D(Basis.looking_at(TOWER_SEARCH_AIM - sl, Vector3.UP), sl)
	Props.cyl(drum, Vector3(0, 0, 0.0), 0.24, 0.36, "iron", Vector3(90, 0, 0))
	Props._noshadow(Props.cyl(drum, Vector3(0, 0, -0.19), 0.26, 0.03, "steel", Vector3(90, 0, 0)))
	Props._noshadow(Props.cyl(drum, Vector3(0, 0, -0.2), 0.21, 0.02, "bulb_off", Vector3(90, 0, 0)))
	for sx: float in [-0.27, 0.27]:
		Props._noshadow(Props.block(drum, Vector3(sx - 0.015, -0.3, -0.03), Vector3(sx + 0.015, 0.04, 0.03), "iron"))
	# the zip lines
	for zl: Array in ZIP_LINES:
		var top: Vector3 = zl[1]
		var foot: Vector3 = zl[2]
		var post_top: Vector3 = foot + Vector3(0, ZIP_POST_H, 0)
		var flat: Vector3 = Vector3(foot.x - top.x, 0, foot.z - top.z).normalized()
		var side: Vector3 = Vector3(-flat.z, 0, flat.x)
		var corner: Vector3 = Vector3(cx + signf(top.x - cx) * (h - 0.1), top.y + 0.2, cz + signf(top.z - cz) * (h - 0.1))
		Props.strut(g, corner, top + Vector3(0, 0.06, 0), 0.07, "iron")   # the arm off the roof post, and its bracket
		Props.block(g, top + Vector3(-0.08, -0.1, -0.08), top + Vector3(0.08, 0.1, 0.08), "iron")
		Props._noshadow(Props.block(g, top + Vector3(-0.05, 0.1, -0.05), top + Vector3(0.05, 0.4, 0.05), "iron"))
		Props._noshadow(Props.block(g, top + Vector3(-0.06, 0.16, -0.06), top + Vector3(0.06, 0.34, 0.06), "lantern_glass", false))   # its marker lantern
		Props.cable(g, top, post_top, 0.3, 0.022, 20, "iron")
		Props.block(g, post_top + Vector3(-0.09, -0.08, -0.09), post_top + Vector3(0.09, 0.08, 0.09), "iron")
		var stay: Vector3 = foot + flat * 1.6
		Props._noshadow(Props.strut(g, post_top + Vector3(0, -0.2, 0), stay, 0.02, "iron"))   # the stay to its ground anchor, in line with the pull
		Props._noshadow(Props.block(g, stay + Vector3(-0.1, 0, -0.1), stay + Vector3(0.1, 0.25, 0.1), "iron"))
		Props._noshadow(Props.block(g, foot + Vector3(-0.14, ZIP_POST_H + 0.15, -0.14), foot + Vector3(0.14, ZIP_POST_H + 0.22, 0.14), "snow"))
		var lan: Vector3 = foot + side * 0.2 + Vector3(0, 2.1, 0)   # a lantern hung on the post, so the landing reads at night
		Props._noshadow(Props.block(g, foot + side * 0.1 + Vector3(-0.015, 2.3, -0.015), foot + side * 0.24 + Vector3(0.015, 2.33, 0.015), "iron"))
		Props._noshadow(Props.block(g, lan + Vector3(-0.07, -0.11, -0.07), lan + Vector3(0.07, 0.11, 0.07), "lantern_glass", false))
		Props._noshadow(Props.block(g, lan + Vector3(-0.08, 0.11, -0.08), lan + Vector3(0.08, 0.14, 0.08), "iron"))
		Props.rope_coil(g, foot + side * 0.45 - flat * 0.3, 0.14)
		var land: Vector3 = foot - flat * 0.9
		Props._noshadow(Props.obox(g, land + Vector3(0, 0.006, 0), Vector3(1.8, 0.012, 2.4), "snow_trodden", Vector3(0, rad_to_deg(atan2(flat.x, flat.z)), 0)))


## A deck's floor in plan (x, z rectangles): the whole square, or (T-275) the top platform's four pieces round the
## hatch. The slab colliders and the floorboards both use it.
func _tower_floor_rects(dy: float) -> Array[Rect2]:
	var x0: float = TOWER_X - TOWER_HALF
	var x1: float = TOWER_X + TOWER_HALF
	var z0: float = TOWER_Z - TOWER_HALF
	var z1: float = TOWER_Z + TOWER_HALF
	if dy != TOWER_TOP:
		return [Rect2(x0, z0, x1 - x0, z1 - z0)]
	return [Rect2(x0, z0, x1 - x0, TOWER_HATCH_Z0 - z0), Rect2(x0, TOWER_HATCH_Z1, x1 - x0, z1 - TOWER_HATCH_Z1),
		Rect2(x0, TOWER_HATCH_Z0, TOWER_HATCH_X0 - x0, TOWER_HATCH_Z1 - TOWER_HATCH_Z0),
		Rect2(TOWER_HATCH_X1, TOWER_HATCH_Z0, x1 - TOWER_HATCH_X1, TOWER_HATCH_Z1 - TOWER_HATCH_Z0)]


## One deck's boarded parapet: two boards between the rail bars each side, a plank cap on the top bar. T-275: the
## landing's north side is cut for the lower ladder's opening (TOWER_GAP_HALF either side of x = TOWER_X), a post
## closing each end.
func _tower_parapet(g: Node3D, dy: float) -> void:
	var cx: float = TOWER_X
	var cz: float = TOWER_Z
	var h: float = TOWER_HALF
	for side: int in 4:
		var n: Vector3 = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][side]   # outward
		var t: Vector3 = Vector3(n.z, 0, -n.x)
		var c: Vector3 = Vector3(cx, 0, cz) + n * (h - 0.03)
		var gap: bool = side == 0 and dy == TOWER_DECK   # (on the north side t is -X: u = cx - x)
		for by: Array in [[0.18, 0.5], [0.62, 0.95]]:
			for run: Vector2 in _parapet_runs(h - 0.06, gap):
				var a3: Vector3 = c + t * run.x + Vector3(0, dy + float(by[0]), 0) - n * 0.02
				var b3: Vector3 = c + t * run.y + Vector3(0, dy + float(by[1]), 0) + n * 0.02
				Props.block(g, Vector3(minf(a3.x, b3.x), a3.y, minf(a3.z, b3.z)), Vector3(maxf(a3.x, b3.x), b3.y, maxf(a3.z, b3.z)), "planks")
		for run2: Vector2 in _parapet_runs(h + 0.02, gap):
			var a4: Vector3 = c + t * run2.x + Vector3(0, dy + 1.09, 0) - n * 0.08
			var b4: Vector3 = c + t * run2.y + Vector3(0, dy + 1.14, 0) + n * 0.06
			Props.block(g, Vector3(minf(a4.x, b4.x), a4.y, minf(a4.z, b4.z)), Vector3(maxf(a4.x, b4.x), b4.y, maxf(a4.z, b4.z)), "beam")
		if gap:
			for px: float in [cx - TOWER_GAP_HALF, cx + TOWER_GAP_HALF]:   # a post closing each end of the opening
				var po: float = -0.045 if px < cx else 0.045
				Props.block(g, Vector3(px + po - 0.045, dy, c.z - 0.045), Vector3(px + po + 0.045, dy + 1.14, c.z + 0.045), "beam")


## T-275: one of the tower's ladders (Props.ladder's frame at yaw 0: `pos` at its back, the climber on its north side,
## the floor it arrives on to its south), `rise` from its foot to that floor: rungs up to the floor, then the stiles
## carried on TOWER_HOLD_H as hand holds and bent over onto the floor at its edge (the climber steps through between
## them). Their colliders are build_geometry's (TowerLadderStile).
func _tower_ladder(g: Node3D, pos: Vector3, rise: float) -> void:
	Props.ladder(g, pos, 0.0, rise, "beam")
	var top: float = pos.y + rise + TOWER_HOLD_H
	for sx: float in [-0.2, 0.2]:
		var x: float = pos.x + sx
		Props.block(g, Vector3(x - 0.025, pos.y + rise, pos.z - 0.14), Vector3(x + 0.025, top, pos.z - 0.09), "beam")   # the stile, on up
		Props.block(g, Vector3(x - 0.025, top - 0.05, pos.z - 0.14), Vector3(x + 0.025, top, pos.z + 0.07), "beam")    # over the edge
		Props.block(g, Vector3(x - 0.025, pos.y + rise, pos.z + 0.02), Vector3(x + 0.025, top - 0.05, pos.z + 0.07), "beam")   # down onto the floor
		Props._noshadow(Props.block(g, Vector3(x - 0.035, pos.y + rise + 0.02, pos.z - 0.15), Vector3(x + 0.035, pos.y + rise + 0.08, pos.z + 0.08), "iron"))   # its strap at the floor


## The stretches of a parapet side along its run (-half..half), cut at the lower ladder's opening when `gap`.
func _parapet_runs(half: float, gap: bool) -> Array[Vector2]:
	if not gap:
		return [Vector2(-half, half)]
	return [Vector2(-half, -TOWER_GAP_HALF), Vector2(TOWER_GAP_HALF, half)]


## T-268: the tower's lights. Oil lanterns that always burn (three down the yard-side corner, one on the field
## corner, one under the roof), the red lamp on
## the mast (the tower reads from across the map at night), a small lantern at each zip line's landing post, and the
## searchlight: electric, dark until the cellar lever's sweep reaches the stable (the last zone of the sweep; the
## yard has no turn of its own), then a beam over the yard onto the gate. Only the searchlight asks for a shadow
## (one spot view; ShadowBudget decides, T-258); the lanterns have none.
const TOWER_SEARCH_AIM: Vector3 = Vector3(18.0, 0.0, 45.5)
const TOWER_SEARCHLIGHT: Vector3 = Vector3(TOWER_X + TOWER_HALF + 0.85, TOWER_TOP + 2.75, TOWER_Z)   # on the roof's east gable end


func _tower_lights() -> void:
	var warm: Color = Color(1.0, 0.62, 0.32)
	# the lanterns hang OUTSIDE the yard-side corner, one a stage, so they wash the north and east faces' timber from
	# the ground to the roof (a lamp inside a parapet lights the deck and leaves the tower a black shape); one on the
	# field corner for the south and west faces
	var ne: Vector3 = Vector3(TOWER_X + TOWER_HALF + 0.55, 0, TOWER_Z - TOWER_HALF - 0.55)
	var sw: Vector3 = Vector3(TOWER_X - TOWER_HALF - 0.55, 0, TOWER_Z + TOWER_HALF + 0.55)
	_lamp("YardTowerFootLamp", ne + Vector3(0, 2.3, 0), warm, 6.5, 14.0, false, true, 0.2)
	_lamp("YardTowerLandingLamp", ne + Vector3(0, TOWER_DECK - 0.9, 0), warm, 8.5, 16.0, false, true, 0.2)
	_lamp("YardTowerEaveLamp", ne + Vector3(0, TOWER_TOP - 0.9, 0), warm, 8.5, 16.0, false, true, 0.2)
	_lamp("YardTowerFieldLamp", sw + Vector3(0, TOWER_DECK - 0.9, 0), warm, 7.0, 16.0, false, true, 0.2)
	_lamp("YardTowerLamp", Vector3(TOWER_X, TOWER_TOP + 1.95, TOWER_Z), warm, 3.5, 11.0, false, true, 0.2)
	_lamp("YardTowerBeacon", Vector3(TOWER_X, TOWER_TOP + 6.98, TOWER_Z), Color(1.0, 0.12, 0.08), 6.0, 12.0, false, false)
	for zl: Array in ZIP_LINES:
		var top: Vector3 = zl[1]
		var foot: Vector3 = zl[2]
		var flat: Vector3 = Vector3(foot.x - top.x, 0, foot.z - top.z).normalized()
		_lamp("YardZipLamp_" + str(zl[0]), foot + Vector3(-flat.z, 0, flat.x) * 0.2 - flat * 0.25 + Vector3(0, 2.1, 0), warm, 1.6, 6.5, false, true, 0.2)
	var sl: SpotLight3D = SpotLight3D.new()
	sl.name = "YardTowerSearchlight"
	sl.light_color = Color(0.86, 0.92, 1.0)
	sl.light_energy = 14.0
	sl.light_volumetric_fog_energy = 1.6
	sl.spot_range = 38.0
	sl.spot_angle = 17.0
	sl.spot_attenuation = 0.6
	sl.shadow_enabled = true
	sl.visible = false
	sl.set_meta("zone", &"STABLE")
	sl.set_meta("energy", 14.0)
	sl.add_to_group(&"power_lights", true)
	map_root.add_child(sl)
	var at: Vector3 = TOWER_SEARCHLIGHT
	sl.transform = Transform3D(Basis.looking_at(TOWER_SEARCH_AIM - at, Vector3.UP), at + (TOWER_SEARCH_AIM - at).normalized() * 0.24)
	var lens: MeshInstance3D = Props.cyl(sl, Vector3(0, 0, 0.02), 0.2, 0.02, "flood_glass", Vector3(90, 0, 0))   # the lit lens shows with the light
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens.set_meta("keep", true)


## T-125: a blocking fence's collider: the world layer up to FENCE_SOLID_H (zombies and shots stop at the drawn
## rails), EDGE_LAYER above it to b.y (players can't hop it; shots pass). Drawn with Props.fence(..., true).
var _fence_n: int = 0


func _fence_box(parent: Node3D, name_: String, a: Vector3, b: Vector3) -> void:
	_fence_n += 1   # unique names (a repeated name comes back as @StaticBody3D@n), so tests can find them
	box(parent, "%s%d" % [name_, _fence_n], a, Vector3(b.x, FENCE_SOLID_H, b.z), "snow", true, false)
	var top: Node3D = box(parent, "%s%dTop" % [name_, _fence_n], Vector3(a.x, FENCE_SOLID_H, a.z), b, "snow", true, false)
	(top as StaticBody3D).collision_layer = EDGE_LAYER


## THE GROUNDS (T-080; the user: "the outside area on the first map needs some work, make it bigger and make it so
## you can go around the whole building"). The snow round the inn is play space now, zone GROUNDS: out of the front
## door (Door_Front, "Out Front", 1250) or the yard's gate (Door_Gate, 750, from the yard or the road), a walkable
## ring right round the inn, the stable and the yard, the crossroads in front, the west road, the carters' road
## behind and the crash field to the east with GRAVELIGHT ONE as cover. A hard edge all round (OUT_MIN..OUT_MAX): a
## 6 m invisible wall on the line of the boundary fences and the tree line, closing the four road exits too.
const OUT_MIN: Vector2 = Vector2(-20.0, -30.0)
const OUT_MAX: Vector2 = Vector2(60.0, 64.0)
## Fences with 2.3 m colliders like the yard's (the drawn rails are 1.2 m): [from (x, z), to (x, z)], axis-aligned.
## The roadside fence north of the crossroads road has gaps at the north road, a field gate (x 8..11.5) and a fallen
## bay (x 19..22), where the round 1 opening's two escapers run through (map00_opening.json); open past x 30.
const OUT_FENCES: Array = [
	[Vector2(-20, -13), Vector2(-13.5, -13)], [Vector2(-6.5, -13), Vector2(8, -13)], [Vector2(11.5, -13), Vector2(19, -13)], [Vector2(22, -13), Vector2(30, -13)],
	[Vector2(-20, -30), Vector2(-20, -10.2)], [Vector2(-20, -5.3), Vector2(-20, 64)],
	[Vector2(60, -30), Vector2(60, -10.2)], [Vector2(60, -5.3), Vector2(60, 64)],
	[Vector2(-20, 64), Vector2(-13.2, 64)], [Vector2(-8.3, 64), Vector2(33, 64)], [Vector2(41, 64), Vector2(60, 64)],
	[Vector2(-20, -30), Vector2(-13.2, -30)], [Vector2(-8.3, -30), Vector2(60, -30)],
]
## Dead trees on the map (drawn by _dress_exterior / _dress_carters_road with these seeds); the ones inside the edge
## get a trunk collider. [position, seed, height]
const OUT_DEAD_TREES: Array = [
	[Vector3(-16, 0, -22), 100, 6.0], [Vector3(-26, 0, 8), 101, 8.0], [Vector3(-15, 0, 30), 102, 10.0], [Vector3(30, 0, -20), 103, 6.0],
	[Vector3(55, 0, 30), 104, 8.0], [Vector3(5, 0, 48), 105, 10.0], [Vector3(-30, 0, -30), 106, 6.0], [Vector3(40, 0, -25), 107, 8.0],
	[Vector3(-24, 0, 50), 108, 10.0], [Vector3(60, 0, -10), 109, 6.0],
	[Vector3(31, 0, 52), 131, 7.0], [Vector3(12, 0, 55), 132, 8.5], [Vector3(38, 0, 52), 133, 6.5], [Vector3(22, 0, 66), 134, 9.0], [Vector3(52, 0, 60), 135, 7.5],
	# T-080: a few more in the bigger field
	[Vector3(-3, 0, -24), 140, 7.5], [Vector3(47, 0, -16), 141, 6.5], [Vector3(-14, 0, 47), 142, 8.0], [Vector3(50, 0, 50), 143, 7.0],
]
## Solid things out on the grounds (cover; nobody stands on them: no_mantle): [name, centre on the snow, size, yaw].
## Drawn by _dress_grounds.
const OUT_SOLIDS: Array = [
	["HayRick", Vector3(22.0, 0, -23.5), Vector3(3.4, 2.8, 3.4), 0.0],
	["Shrine", Vector3(-15.4, 0, -11.4), Vector3(0.5, 2.4, 0.5), 0.0],
	["HayWagon", Vector3(-15.6, 0, 22.0), Vector3(1.9, 1.1, 3.0), 8.0],
	["RoadCart", Vector3(-17.0, 0, -3.0), Vector3(1.9, 1.1, 3.0), 20.0],
	["SandbagsW", Vector3(32.25, 0, -22.0), Vector3(4.5, 0.9, 0.7), 0.0],
	["SandbagsN", Vector3(34.5, 0, -20.25), Vector3(0.7, 0.9, 3.5), 0.0],
	# (T-211: GRAVELIGHT ONE's engine in the north field and its starboard wing behind the fuselage are the C-47's own
	# pieces now, with their colliders from build_c47_debris)
	["BurntCar", Vector3(49.0, 0, -14.5), Vector3(1.8, 1.5, 4.2), 100.0],
	["Drums", Vector3(47.0, 0, 44.0), Vector3(1.4, 0.95, 1.4), 0.0],
	# the road exits: a felled spruce across the north road, sawhorse barriers on the east road, the carters' road
	# and the west road south; a barrier boom on the crossroads road west (all just inside the edge)
	["FelledSpruce", Vector3(-10.75, 0, -29.0), Vector3(6.5, 0.8, 0.7), 4.0],
	["BarrierE", Vector3(59.0, 0, -7.75), Vector3(0.5, 1.0, 4.4), 0.0],
	["BarrierS", Vector3(37.0, 0, 63.0), Vector3(5.0, 1.0, 0.5), 0.0],
	["BarrierSW", Vector3(-10.75, 0, 63.0), Vector3(4.4, 1.0, 0.5), 0.0],
	["BarrierW", Vector3(-19.2, 0, -7.75), Vector3(0.5, 1.1, 4.6), 0.0],
]
## Posts that stand in the field: the telephone poles along the crossroads road, the two signposts, the parachute's
## tree, the two lamp posts. [position, half width]
const OUT_POSTS: Array = [
	[Vector3(-16, 0, -15.5), 0.16], [Vector3(-2, 0, -15.5), 0.16], [Vector3(12, 0, -15.5), 0.16], [Vector3(26, 0, -15.5), 0.16], [Vector3(40, 0, -15.5), 0.16],
	[Vector3(-8.2, 0, -10.6), 0.12], [Vector3(22.9, 0, 49.6), 0.12], [Vector3(39.5, 0, 24.5), 0.25],
	[Vector3(-7.6, 0, -4.6), 0.12], [Vector3(37.0, 0, -10.8), 0.12],
]
## Where the zombies come out of the dark at the edge (kind "edge": they walk in and chase; only while somebody is
## out on the grounds, never in sight of a player out there) and rise from the snow (kind "ground", round 4+).
## T-084: the edge spawns stand 4.5 m BEYOND the edge wall, in the tree line (a pocket of navmesh POCKET_W wide
## reaches POCKET_D m out through a gap in the baked wall and fences; the gap is filled by a collider on the edge
## layer that only bodies see, so the zombies walk in out of the trees and nobody walks out).
const OUT_EDGE_SPAWNS: Array = [
	Vector3(-15, 0, -34.5), Vector3(5, 0, -34.5), Vector3(25, 0, -34.5), Vector3(47, 0, -34.5),
	Vector3(64.5, 0, -1.0), Vector3(64.5, 0, 22.0), Vector3(64.5, 0, 46.0),
	Vector3(45, 0, 68.5), Vector3(24, 0, 68.5), Vector3(2, 0, 68.5),
	Vector3(-24.5, 0, 44.0), Vector3(-24.5, 0, 16.0), Vector3(-24.5, 0, -20.0),
]
const POCKET_W: float = 3.0
const POCKET_D: float = 7.0
const OUT_GROUND_SPAWNS: Array = [Vector3(16.5, 0, -19.0), Vector3(-14.0, 0, 36.0), Vector3(45.0, 0, 30.0), Vector3(27.0, 0, 57.0)]
## Zone GROUNDS (roam): boxes tiling the snow inside the edge round the inn, the stable, the stair hall and the yard
## [min (x, z), max (x, z)], y -0.5..3 (the porch roofs' ledges stay out); and the two light wells' pits, lower.
const OUT_ZONE_RECTS: Array = [
	[Vector2(-20, -30), Vector2(60, -0.15)], [Vector2(-20, -0.15), Vector2(-3.15, 64)], [Vector2(-3.15, -0.15), Vector2(-0.15, 7.85)],
	[Vector2(-3.15, 18.65), Vector2(STB_X0 - 0.15, 34)], [Vector2(-3.15, 34), Vector2(2, 64)], [Vector2(0, 16.15), Vector2(18, 22)],
	[Vector2(22, 16.15), Vector2(24.15, 22)], [Vector2(24.15, -0.15), Vector2(60, 9.85)], [Vector2(28.15, 9.85), Vector2(60, 34)],
	[Vector2(24.15, 19), Vector2(28.15, 22)], [Vector2(STB_X1 + 0.15, 22), Vector2(28.15, 34)], [Vector2(34, 34), Vector2(60, 64)], [Vector2(2, 48), Vector2(34, 64)],
]
const OUT_WELL_RECTS: Array = [[Vector2(1.85, -4.65), Vector2(5.05, -0.15)], [Vector2(24.0, -2.1), Vector2(26.35, 3.35)]]


## Which side of the edge an edge spawn is beyond: 0 north (z < OUT_MIN.y), 1 south, 2 west, 3 east.
static func _pocket_side(p: Vector3) -> int:
	if p.z < OUT_MIN.y:
		return 0
	if p.z > OUT_MAX.y:
		return 1
	return 2 if p.x < OUT_MIN.x else 3


## The spawn pockets beyond the edge (T-084), as rects on the snow (x, z): from the edge line POCKET_D m out, POCKET_W
## wide, one per edge spawn.
static func edge_pockets() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p: Vector3 in OUT_EDGE_SPAWNS:
		match _pocket_side(p):
			0: out.append(Rect2(p.x - POCKET_W * 0.5, OUT_MIN.y - POCKET_D, POCKET_W, POCKET_D))
			1: out.append(Rect2(p.x - POCKET_W * 0.5, OUT_MAX.y, POCKET_W, POCKET_D))
			2: out.append(Rect2(OUT_MIN.x - POCKET_D, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W))
			3: out.append(Rect2(OUT_MAX.x, p.z - POCKET_W * 0.5, POCKET_D, POCKET_W))
	return out


## True when the segment a..b lies on the edge line (an edge fence; the roadside fence at z -13 is not one).
static func _on_edge(a: Vector2, b: Vector2) -> bool:
	return (a.x == b.x and (a.x == OUT_MIN.x or a.x == OUT_MAX.x)) or (a.y == b.y and (a.y == OUT_MIN.y or a.y == OUT_MAX.y))


## `segments` ([a, b] axis-aligned, 2D) with the spans across the spawn pockets cut out of those on the edge line.
static func _cut_pockets(segments: Array) -> Array:
	var out: Array = []
	var pockets: Array[Rect2] = edge_pockets()
	for s: Array in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if not _on_edge(a, b):
			out.append([a, b])
			continue
		var along_x: bool = a.y == b.y
		var cuts: Array = []
		for r: Rect2 in pockets:
			if along_x:
				if a.y <= r.end.y + 0.01 and a.y >= r.position.y - 0.01:
					cuts.append([r.position.x, r.end.x])
			elif a.x <= r.end.x + 0.01 and a.x >= r.position.x - 0.01:
				cuts.append([r.position.y, r.end.y])
		var lo: float = minf(a.x, b.x) if along_x else minf(a.y, b.y)
		var hi: float = maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var cur: float = lo
		for c: Array in cuts:
			var c0: float = float(c[0])
			var c1: float = float(c[1])
			if c1 <= lo or c0 >= hi:
				continue
			if c0 > cur + 0.05:
				out.append([Vector2(cur, a.y) if along_x else Vector2(a.x, cur), Vector2(c0, a.y) if along_x else Vector2(a.x, c0)])
			cur = maxf(cur, c1)
		if hi > cur + 0.05:
			out.append([Vector2(cur, a.y) if along_x else Vector2(a.x, cur), Vector2(hi, a.y) if along_x else Vector2(a.x, hi)])
	return out


## The grounds' collision (navmesh source): the edge wall, the fences, tree trunks, posts and the solid props.
## T-084: the edge wall and the fences on the edge line are on EDGE_LAYER (bodies collide, shots pass) and are
## cut at the spawn pockets; the cuts are filled by colliders on the same layer kept OUT of the navigation region
## (EdgeGates under the map root), so the bake joins each pocket to the field while players stay inside. Beyond the
## edge everything but the pockets is carved out of the bake (NavigationObstacle3Ds that only live for the bake).
func build_grounds() -> void:
	var lo: Vector2 = OUT_MIN
	var hi: Vector2 = OUT_MAX
	var gates: Node3D = Node3D.new()
	gates.name = "EdgeGates"
	map_root.add_child(gates)
	var walls: Array = [[Vector2(lo.x - 0.4, lo.y), Vector2(hi.x + 0.4, lo.y)], [Vector2(lo.x - 0.4, hi.y), Vector2(hi.x + 0.4, hi.y)],
		[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y)], [Vector2(hi.x, lo.y), Vector2(hi.x, hi.y)]]
	for w: Array in _cut_pockets(walls):
		_edge_box(geo, "GroundsEdge", w[0], w[1], 6.0)
	for r: Rect2 in edge_pockets():   # the gap fillers: the wall's own run across each pocket, not baked
		var side: int = _pocket_side(Vector3(r.get_center().x, 0, r.get_center().y))
		var a: Vector2 = Vector2(r.position.x, lo.y if side == 0 else hi.y) if side < 2 else Vector2(lo.x if side == 2 else hi.x, r.position.y)
		var b: Vector2 = Vector2(r.end.x, a.y) if side < 2 else Vector2(a.x, r.end.y)
		_edge_box(gates, "EdgeGate", a, b, 6.0)
	for f: Array in _cut_pockets(OUT_FENCES):
		var a2: Vector2 = f[0]
		var b2: Vector2 = f[1]
		if _on_edge(a2, b2):
			_edge_box(geo, "GroundsFence", a2, b2, 2.3)
		else:
			_fence_box(geo, "GroundsFence", Vector3(minf(a2.x, b2.x) - 0.1, 0, minf(a2.y, b2.y) - 0.1), Vector3(maxf(a2.x, b2.x) + 0.1, 2.3, maxf(a2.y, b2.y) + 0.1))
	_carve_beyond_edge()
	for t: Array in OUT_DEAD_TREES:
		var tp: Vector3 = t[0]
		if _in_grounds(tp, -0.5):
			box(geo, "TreeTrunk", tp + Vector3(-0.26, 0, -0.26), tp + Vector3(0.26, NAV_SOLID_H, 0.26), "beam", true, false).set_meta("no_mantle", true)
	for pt: Array in OUT_POSTS:
		var pp: Vector3 = pt[0]
		var hw: float = float(pt[1])
		box(geo, "Post", pp + Vector3(-hw, 0, -hw), pp + Vector3(hw, NAV_SOLID_H, hw), "beam", true, false).set_meta("no_mantle", true)
	for sd: Array in OUT_SOLIDS:
		_solid(str(sd[0]), sd[1], sd[2], float(sd[3]))
	build_bank_shed()
	# the crash site's cargo, thrown out of the hold (Landscape scattered_cargo, seed 77, round (37, 15)): the same
	# draws, so each crate's collider sits under its drawing
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var cc: Vector3 = Landscape.WRECK_POS + Vector3(-9.0, 0, 9.0)
	for i: int in 7:
		var cp: Vector3 = cc + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-5, 6))
		var csz: float = rng.randf_range(0.45, 0.8)
		var cyaw: float = rng.randf_range(0, 360)
		rng.randf()
		_solid("CargoCrate", cp, Vector3(csz, csz, csz), cyaw)


## An invisible collider along the edge line a..b (2D), `h` high, on the edge layer (T-084): 0.4 m thick outward of
## the line for the wall, 0.2 m centred for the fences. Bodies collide with it; shots and rays don't; the bake reads it.
func _edge_box(parent: Node3D, name_: String, a: Vector2, b: Vector2, h: float) -> void:
	var fence: bool = h < 3.0
	var x0: float = minf(a.x, b.x)
	var x1: float = maxf(a.x, b.x)
	var z0: float = minf(a.y, b.y)
	var z1: float = maxf(a.y, b.y)
	if a.y == b.y:   # along x
		var out: float = -1.0 if a.y <= OUT_MIN.y + 0.01 else 1.0
		z0 = a.y + (minf(0.0, out * 0.4) if not fence else -0.1)
		z1 = a.y + (maxf(0.0, out * 0.4) if not fence else 0.1)
		x0 -= 0.1
		x1 += 0.1
	else:
		var out2: float = -1.0 if a.x <= OUT_MIN.x + 0.01 else 1.0
		x0 = a.x + (minf(0.0, out2 * 0.4) if not fence else -0.1)
		x1 = a.x + (maxf(0.0, out2 * 0.4) if not fence else 0.1)
	var bd: Node3D = box(parent, name_, Vector3(x0, -0.5 if not fence else 0.0, z0), Vector3(x1, h, z1), "snow", true, false)
	if bd == null:
		return
	bd.set_meta("no_mantle", true)
	(bd as StaticBody3D).collision_layer = EDGE_LAYER


## Bake-only obstructions (T-084) over the snow beyond the edge, leaving only the spawn pockets: the navmesh outside
## the wall is the pockets and nothing else, so a zombie never walks the far side of the trees.
func _carve_beyond_edge() -> void:
	var far: float = 40.0
	var lo: Vector2 = OUT_MIN - Vector2(0.4, 0.4)
	var hi: Vector2 = OUT_MAX + Vector2(0.4, 0.4)
	var rects: Array[Rect2] = []
	var pockets: Array[Rect2] = edge_pockets()
	# four strips round the outside, each split at its pockets; past a pocket's far end the strip carries on
	for side: int in 4:
		var strip: Rect2
		match side:
			0: strip = Rect2(lo.x - far, lo.y - far, hi.x - lo.x + 2.0 * far, far)
			1: strip = Rect2(lo.x - far, hi.y, hi.x - lo.x + 2.0 * far, far)
			2: strip = Rect2(lo.x - far, lo.y, far, hi.y - lo.y)
			_: strip = Rect2(hi.x, lo.y, far, hi.y - lo.y)
		var along_x: bool = side < 2
		var cuts: Array = []
		for r: Rect2 in pockets:
			if _pocket_side(Vector3(r.get_center().x, 0, r.get_center().y)) != side:
				continue
			cuts.append(r)
		cuts.sort_custom(func(p: Rect2, q: Rect2) -> bool: return (p.position.x < q.position.x) if along_x else (p.position.y < q.position.y))
		var cur: float = strip.position.x if along_x else strip.position.y
		var endv: float = strip.end.x if along_x else strip.end.y
		for r2: Rect2 in cuts:
			var c0: float = r2.position.x if along_x else r2.position.y
			var c1: float = r2.end.x if along_x else r2.end.y
			if along_x:
				rects.append(Rect2(cur, strip.position.y, c0 - cur, strip.size.y))
				# the strip beyond the pocket's far end
				if side == 0:
					rects.append(Rect2(c0, strip.position.y, c1 - c0, r2.position.y - strip.position.y))
				else:
					rects.append(Rect2(c0, r2.end.y, c1 - c0, strip.end.y - r2.end.y))
			else:
				rects.append(Rect2(strip.position.x, cur, strip.size.x, c0 - cur))
				if side == 2:
					rects.append(Rect2(strip.position.x, c0, r2.position.x - strip.position.x, c1 - c0))
				else:
					rects.append(Rect2(r2.end.x, c0, strip.end.x - r2.end.x, c1 - c0))
			cur = c1
		if along_x:
			rects.append(Rect2(cur, strip.position.y, endv - cur, strip.size.y))
		else:
			rects.append(Rect2(strip.position.x, cur, strip.size.x, endv - cur))
	for r3: Rect2 in rects:
		if r3.size.x < 0.05 or r3.size.y < 0.05:
			continue
		var ob: NavigationObstacle3D = NavigationObstacle3D.new()
		ob.name = "EdgeCarve"
		ob.affect_navigation_mesh = true
		ob.carve_navigation_mesh = true
		ob.avoidance_enabled = false
		ob.height = 8.0
		ob.position = Vector3(r3.position.x, -1.0, r3.position.y)
		ob.vertices = PackedVector3Array([Vector3(0, 0, 0), Vector3(r3.size.x, 0, 0), Vector3(r3.size.x, 0, r3.size.y), Vector3(0, 0, r3.size.y)])
		geo.add_child(ob)
		_bake_only.append(ob)


## True when `p` is inside the grounds' edge by at least `margin` metres.
func _in_grounds(p: Vector3, margin: float) -> bool:
	return p.x > OUT_MIN.x + margin and p.x < OUT_MAX.x - margin and p.z > OUT_MIN.y + margin and p.z < OUT_MAX.y - margin


## A hidden solid standing on the snow (centre on the ground, size, yaw deg), no_mantle, cut into slices no taller
## than NAV_SOLID_H so the bake leaves no walkable island inside it (build_nav_blocks' note).
func _solid(name_: String, c: Vector3, sz: Vector3, yaw: float) -> void:
	var y0: float = 0.0
	while y0 < sz.y - 0.01:
		var h: float = minf(NAV_SOLID_H, sz.y - y0)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = name_
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), c + Vector3(0, y0 + h * 0.5, 0))
		body.set_meta("no_mantle", true)
		body.set_meta("decal_persist", false)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(sz.x, h, sz.z)
		cs.shape = shape
		body.add_child(cs)
		geo.add_child(body)
		_count += 1
		y0 += h


## The Helvetia cellar (T&C M2; Appendix A asks for the 8 perk machines in a cellar behind a 1500 door for the
## vertical slice). Door 3 in the taproom's east wall -> stair hall (x 24..28, z 10..19) with a ramp down to the
## vaulted cellar (x 24..36, z 19..31, floor CELLAR_Y). Its roof is the yard's ground surface.
const CELLAR_Y: float = -3.2
const CELLAR_TOP: float = -0.2
## T-251 (UPDATE 19; the owner: "spread perks randomly around the map"): the twelve tonics no longer stand in the vault's
## rows. PERK_SPOTS are the places a machine may stand, all over the map; each match the host deals the twelve onto
## them from the match seed (PerkShuffle / PerkLayout, data/gravelight/perk_layout.json) and the spots left over show
## their filler, a nailed delivery crate (PerkSpot). The scene is saved with the seed-0 deal, so a tool that loads it
## without a match still finds every Perk_<id>.
## [spot id, zone, floor position, yaw (local -Z = the front, faces the room), flags]. Flags: "outdoor" (under the
## snow: only the shapes perk_layout.json calls outdoor-safe), "start" (the start room: only the cheap ones, never
## Second Wind, which pours without the power solo), "near" (one bought door from the taproom: where Second Wind may
## stand, so a solo player can always get to it). A machine stands PERK_BACK m clear of the wall behind it (the fine
## print on its back is read from there, JINGLES.md section 0.3) with PERK_FRONT m of floor in front; _audit_perk_spots
## checks every spot against everything built and drawn before the scene is saved.
const PERK_SPOTS: Array = [
	# T-255: every spot but the yard's west fence is flush: the back on the wall, the fine print on the side named (see
	# PERK_FLUSH_GAP). The taproom's stood at (2.25, 2.0), 1.25 m out from the north wall in the middle of the west walk
	# (the owner: "a bad spot"); it stands in the north-west corner itself now, its back on the north wall and its side
	# 0.1 m from the west wall, out of the walk to the Old Cellar door and 2.4 m from the Kar98k's chalk, the clock and
	# the photograph on the west wall.
	["taproom_nook", "TAPROOM", Vector3(1.1, 0, 0.85), 180.0, {"start": true, "flush": -1}],
	# the east guest room (the crate's room), on the wall it shares with the middle room, seen from its door (it stood
	# 1.85 m out in the room, 1.5 m from the swing door: the leaf's tip is 1.8 m from its walk now)
	["guest_room", "UPSTAIRS", Vector3(16.85, UP_Y, 2.8), -90.0, {"near": true, "flush": -1}],
	# the upstairs hall's east end, on its south wall east of the landscape painting
	["guest_hall", "UPSTAIRS", Vector3(20.6, UP_Y, 9.03), 0.0, {"near": true, "flush": 1}],
	# the attic, on the south wall east of the stair well
	["attic", "UPSTAIRS", Vector3(16.0, ATT_Y, 9.15), 0.0, {"near": true, "flush": 1}],
	# the stable under the hayloft, on the south wall between the window and the great doors
	["stable", "STABLE", Vector3(14.6, 0, 33.15), 0.0, {"near": true, "flush": -1}],
	# the hayloft's south wall
	["hayloft", "STABLE", Vector3(12.5, LOFT_TOP, 33.15), 0.0, {"near": true, "flush": 1}],
	# the yard's south-east corner, on the east fence between the trough and the south fence
	["yard_east", "YARD", Vector3(33.2, 0, 46.0), 90.0, {"outdoor": true, "flush": -1}],
	# the yard's west fence, north of its gap (a walk behind it: the fence's snow bank lies there)
	["yard_west", "YARD", Vector3(4.25, 0, 39.5), -90.0, {"outdoor": true}],
	# out on the grounds: on the stable's east wall, facing the field and the wreck
	["behind_stable", "GROUNDS", Vector3(26.35, 0, 31.9), -90.0, {"outdoor": true, "flush": 1}],
	# on the carters' road outside the yard, on its south fence west of the gate
	["carters_road", "GROUNDS", Vector3(15.0, 0, 48.9), 180.0, {"outdoor": true, "flush": 1}],
	# the Helvetia vault: on the east wall north of the bay's arch, beside the bench (where Twin Barrel stood), on the
	# south wall, and on the late-delivery bay's far wall, facing its arch. (T-255: on their walls too. With the rows
	# gone a cabinet or a crate a metre out from a cellar wall stood as free on the floor as the taproom's did.)
	["vault_east", "CELLAR", Vector3(35.15, CELLAR_Y, 20.9), 90.0, {"near": true, "flush": -1}],
	["vault_south", "CELLAR", Vector3(31.75, CELLAR_Y, 30.15), 0.0, {"near": true, "flush": 1}],
	["bay", "CELLAR", Vector3(41.35, CELLAR_Y, 25.95), 90.0, {"near": true, "flush": 1}],
	# the Old Cellar's barrel vault: on its north wall west of the loop, and on its east wall south of the racks (the
	# id is from T-251, when it stood out from the south wall's wine rack: a new id would move every seed's deal)
	["old_vault_north", "OLD_CELLAR", Vector3(15.0, CELLAR_Y, 0.85), 180.0, {"near": true, "flush": -1}],
	["old_vault_south", "OLD_CELLAR", Vector3(23.15, CELLAR_Y, 12.5), 90.0, {"near": true, "flush": -1}],
	# the Lagering Vault, on its south wall opposite Door_Lager; the Dynamo Room's south wall east of the set
	["lager", "LAGERKELLER", Vector3(25.95, CELLAR_Y, 36.15), 0.0, {"flush": -1}],
	["dynamo", "MASCHINENRAUM", Vector3(42.3, CELLAR_Y, 38.15), 0.0, {"flush": -1}],
]
## The guest rooms' swing doors (SwingDoor, build_reactive): [hinge x, flipped (the leaf runs along -X), room]. They
## open into the room (-Z) from the hall wall's north face; _spot_grid_build keeps the perk spots out of their swing.
const ROOM_DOORS: Array = [[6.5, true, 1], [11.0, false, 2], [19.5, false, 3]]
const ROOM_DOOR_W: float = 1.5
const ROOM_DOOR_OPEN: float = 100.0
## The floor a spot keeps: the widest machine (the Packmule wagon, 1.7 m) by the deepest (the Ironhide barrel, 1.2 m).
const PERK_SPOT_W: float = 1.7
const PERK_SPOT_D: float = 1.2
const PERK_BACK: float = 1.0
const PERK_FRONT: float = 1.2
## T-255 (the owner, on the taproom's spot: "this perk location is a bad spot": a crate standing 1.25 m out from the
## wall, in the walk): a spot flagged "flush" stands with its back on the wall (the deepest machine PERK_FLUSH_GAP off
## the wall's face; PerkSpot.stand_transform moves a shallower cabinet and the filler crate back to the same line) and
## the machine's fine print hangs on its side instead of its back: "flush": 1 on its local +X side, -1 on -X, with
## PERK_SIDE m of walk kept beside it there. Every spot is flush but the yard's west fence (the fence's snow bank
## lies where the cabinet would stand, so that one keeps T-251's walk behind it and the fine print on its back).
const PERK_FLUSH_GAP: float = 0.1
const PERK_SIDE: float = 0.9
const PerkShuffleScript: Script = preload("res://gravelight/world/perk_shuffle.gd")
## T-179 (the owner: "two perks that aren't in any of the maps ... expand the cellar area a little bit, add those
## perks"): the NACHLIEFERUNG bay, a 6.2 x 7 m vault east of the Helvetia cellar under the field (x 36..42.2,
## z 22.6..29.6; its roof is the snow, like the cellar's), reached through an arch in the cellar's east wall
## between Marathon Malt and Hawkeye Brandy (BAY_ARCH: its z span, clear of both machines' footprints and of the
## vault rib that lands on the wall at z 27). Zone CELLAR (no door of its own, no window, no spawn: zombies come
## in through the arch, like the Crucible's alcove).
const BAY_X0: float = 36.0
const BAY_X1: float = 42.2
const BAY_Z0: float = 22.6
const BAY_Z1: float = 29.6
const BAY_ARCH: Vector2 = Vector2(25.12, 26.78)
const BAY_BULB: Vector3 = Vector3(38.9, CELLAR_Y + 2.55, 25.95)
## T-251 (UPDATE 19; the owner: "expand the cellar in the first map by 75% make the crucible and power two addtional
## doors down"): two more rooms beyond the Helvetia vault, in a chain, each behind its own bought door:
##   the vault -> Door_Lager (750) in its south wall -> THE LAGERING VAULT (zone LAGERKELLER; LAG_*: x 24..34,
##   z 31..37, 60 m2): the inn's own lager cellar, older than the fit-out, brick, three tuns on their cradles down
##   its middle (the island of its loop)
##   -> Door_Dynamo (1000) in its east wall -> THE DYNAMO ROOM (zone MASCHINENRAUM; DYN_*: x 34..44, z 31..39,
##   80 m2): the installers' plant room, whitewashed: the generator set on its plinth in the middle (the island of
##   its loop), the cellar lever (Kellerschalter) and the Crucible in its alcove on the north wall.
## 140 m2 on the cellar's 187.4 (the vault 144 + the bay 43.4): +74.7 %. From the taproom the lever and the Crucible
## are three doors deep (Door_Cellar 1500, Door_Lager 750, Door_Dynamo 1000). Their roofs are the yard's east edge
## and the field's snow (build_geometry cuts the ground slabs over them). Each has a ground spawn (a drain, the sump).
const LAG_X0: float = 24.0
const LAG_X1: float = 34.0
const LAG_Z0: float = 31.0   # (the vault's south wall)
const LAG_Z1: float = 37.0
const LAG_DOOR: Vector2 = Vector2(25.0, 27.0)   # Door_Lager's x span in the vault's south wall
const LAG_TUNS: Array = [28.75, 30.05, 31.35]   # the three tuns' centres (x); they lie along z
const LAG_TUN_R: float = 0.62
const LAG_TUN_Z: Vector2 = Vector2(33.3, 34.7)
const LAG_BULBS: Array = [Vector3(25.9, CELLAR_Y + 2.55, 33.2), Vector3(30.05, CELLAR_Y + 2.55, 32.2), Vector3(32.7, CELLAR_Y + 2.55, 35.7)]
const DYN_X0: float = 34.0
const DYN_X1: float = 44.0
const DYN_Z0: float = 31.0
const DYN_Z1: float = 39.0
const DYN_DOOR: Vector2 = Vector2(34.4, 36.4)   # Door_Dynamo's z span in the wall between the two rooms (x 34)
const DYN_SET: Rect2 = Rect2(37.8, 34.7, 2.4, 1.2)   # the generator set's plinth (x, z)
## The Crucible and the lever keep the places they had on the vault's north wall, measured from the room's north-east
## corner (6.5 m and 3.5 m west of it, the bench and the two crates in the corner itself), so the Crucible's own
## room dressing (CrucibleRoom, crucible_rooms.json "map00", all in the Crucible's frame) fits as it did.
const DYN_CRUCIBLE: Vector3 = Vector3(DYN_X1 - 6.5, CELLAR_Y, DYN_Z0 + 0.95)
const DYN_LEVER: Vector3 = Vector3(DYN_X1 - 3.5, CELLAR_Y + 0.3, DYN_Z0 + 0.35)
const DYN_BULBS: Array = [Vector3(35.9, CELLAR_Y + 2.55, 37.0), Vector3(41.6, CELLAR_Y + 2.55, 33.3), Vector3(40.6, CELLAR_Y + 2.55, 37.4)]
## T-255 (the owner: "while the lights and powr are off the room in the cellar is too dark"): each room had one oil
## lantern inside its door (energy 0.9, range 6 m, flickering by 35 %) for a room 10 m long, so its far half was
## black before the lever (Forward+ frames: 87 to 98 % of the picture under 12/255; the Helvetia vault 42 to 49 %, the
## Old Cellar 47 %). Two lanterns a room now, hung where the player sees them as the source: one inside the door, one
## over the far aisle, with a steady flame (0.12). The brick Lagering Vault takes less than the bigger whitewashed
## Dynamo Room; both stay under what the lever's three bulbs add. [light name, glass position, energy, range];
## _dress_deep_cellar hangs the lanterns, build_deep_cellar_gameplay makes the lights 0.15 m under them.
const DEEP_LAMPS: Array = [
	["LagerLamp", Vector3(27.6, CELLAR_Y + 2.2, 31.75), 1.15, 9.0], ["LagerLamp2", Vector3(31.6, CELLAR_Y + 2.2, 36.05), 1.05, 9.0],
	["DynamoLamp", Vector3(34.7, CELLAR_Y + 2.2, 33.6), 1.75, 10.0], ["DynamoLamp2", Vector3(41.9, CELLAR_Y + 2.2, 35.3), 1.75, 10.0],
]
## T-255: the late-delivery bay had its one lantern at the arch (0.7 over 4.5 m): its dark stone walls took nothing
## from it and the far wall, where a perk spot is, was black before the lever (98 % of the frame under 12/255). The
## arch's lantern is 1.1 over 7 m now and a second hangs over the bay's south half. [light name, glass position,
## energy, range].
const BAY_LAMPS: Array = [
	["CellarBayLamp", Vector3(36.75, CELLAR_Y + 2.15, 24.55), 1.1, 7.0], ["CellarBayLamp2", Vector3(39.7, CELLAR_Y + 2.15, 27.9), 1.3, 7.5],
]
var _lager_lit: Node3D    # the lit bulb glass of the two new rooms (shown with their first bulb light)
var _dynamo_lit: Node3D
## Same as PerkMachine._shape_footprint (that script needs the autoloads, which a --script run doesn't have).
## Keep the two in step.
const MACHINE_FOOTPRINTS: Dictionary = {
	"barrel": Vector3(1.2, 1.9, 1.2), "cabinet": Vector3(0.8, 2.3, 0.6), "crate": Vector3(1.0, 2.0, 0.65),
	"twin": Vector3(1.2, 2.1, 0.6), "teardrop": Vector3(1.0, 2.4, 0.9), "periscope": Vector3(0.9, 1.8, 0.65),
	"wagon": Vector3(1.7, 1.7, 0.85), "safe": Vector3(1.1, 1.9, 0.95),
	"coil": Vector3(0.8, 2.3, 0.6),   # Overclock Cordial: cabinet-sized (perks.json)
	"register": Vector3(1.0, 2.2, 0.75),   # Ledger Lager (T-141): the brass cash register
	"glider": Vector3(0.8, 2.4, 0.7),   # Skyhook Sekt (T-105; on Map 0 since T-179)
	"bandit": Vector3(0.9, 2.3, 0.65),  # Magpie Mead (T-105; on Map 0 since T-179)
}
## crate spots: [name, position, yaw, can_start]
const CRATES: Array = [["Hearth", Vector3(22.9, 0, 14.0), 90.0, true], ["GuestBed", Vector3(22.0, UP_Y, 0.8), 180.0, false],
	["TackRoom", Vector3(22.9, 0, 31.5), 90.0, true], ["Well", Vector3(13.5, 0, 42.0), 90.0, false]]
## Wall-buys: [weapon, position, yaw so local -Z faces the room]. Nudged off the wall past the timber trim. Each gets a
## small warm lamp over its chalk (build_gameplay) with its bracket drawn by _dress_lighting, and _audit_wall_buys checks
## nothing drawn stands in front of any of them before the scene is saved (T-227).
const BUYS: Array = [
	[&"kar98k", Vector3(T * 0.5 + 0.04, 1.5, 3.1), -90.0],   # moved from z 8.6 for the Old Cellar door (T-051)
	[&"m1_garand", Vector3(24 - T * 0.5 - 0.04, 1.5, 4.0), 90.0],   # moved from z 12.5 for the cellar door (T-027)
	[&"mp40", Vector3(T * 0.5 + 0.04, UP_Y + 1.5, 3.4), -90.0],
	[&"trench_gun", Vector3(STB_X0 + T * 0.5 + 0.01, 1.5, 29.5), -90.0],
	[&"thompson", Vector3(22.0, 1.5, 34 + T * 0.5 + 0.04), 180.0],   # the yard: chalked on the stable's outside wall
	[&"bar", Vector3(18.0, ATT_Y + 1.5, T * 0.5 + 0.04), 180.0],   # the attic (T-224): the BAR off GRAVELIGHT ONE, on the north wall east of the chimney
	[&"frag", Vector3(24 - T * 0.5 - 0.04, ATT_Y + 1.5, 7.8), 90.0],   # the attic: the wreck's grenade box, east gable south of the hoist window
]
## Ammo boxes (Update 02 section 4, T-049): [name, floor position, yaw so local -Z faces the room]. Behind the bar
## against the back shelf at the alcove's dead end (clear of Alix's trapdoor at 6.6, 5.6 and the alcove's mouth at
## the north end), and on the stable's west wall under the hayloft between the trench-gun chalk and the yard door.
const AMMO_BOXES: Array = [["Taproom", Vector3(SHELF_X1 + 0.34, 0, BAR_Z1 - 0.5), -90.0], ["Stable", Vector3(STB_X0 + 0.48, 0, 32.0), -90.0],
	["Cellar", Vector3(14.6, -3.2, 15.5), 0.0],   # the Old Cellar's barrel vault, south wall (T-051)
	["Grounds", Vector3(38.4, 0, 26.0), 20.0]]   # T-080: the supply drop under the parachute's tree, facing the Wreck Loop
## The Armorer's Bench (UPDATE_04 section 6, T-068): [floor position against the wall, yaw so local -Z faces the room].
## The inn has no walled tack room: the bench stands in the stable's tack corner on the west wall, under the tack rail
## and saddle blanket (raised above its pegboard), between the hay-stair end and the trench-gun chalk.
const ARMORERS_BENCH: Array = [Vector3(STB_X0 + T * 0.5 + 0.01, 0, 26.5), -90.0]
## the cellar's hanging bulbs (bulb glass position; the power lights sit just under them): one pool per machine row
const CELLAR_BULBS: Array = [Vector3(27.0, CELLAR_Y + 2.55, 22.5), Vector3(33.0, CELLAR_Y + 2.55, 22.5),
	Vector3(26.5, CELLAR_Y + 2.55, 27.5), Vector3(33.5, CELLAR_Y + 2.55, 27.5), Vector3(30.35, CELLAR_Y + 2.55, 28.7)]
var _cellar_lit: Node3D   # holder for the lit bulb glass (shown with the first CellarBulb light)


## Hidden navmesh blocks stay under the agent height: the bake rasterises a box's faces, not its volume, so a block
## taller than agent_height (1.75) leaves a walkable island inside itself (T-051; one sat inside the Crucible's).
const NAV_SOLID_H: float = 1.6
## Perk machines and crates make their collision bodies at runtime, after the bake. Their footprints go into
## the navmesh here (invisible colliders) so zombies path round them instead of into them (T-027).
## T-136: the woodshed by the west road is the village's savings bank now (the Darlehenskasse's branch, its counter
## and teller set up by BankBranch at load): plank walls you can walk inside, a doorway in the north wall between the
## posts, the window lit. Its footprint is the old woodshed's (x -7..-2, z 56.75..60.25), 2.35 m walls.
const BANK_X0: float = -7.0
const BANK_X1: float = -2.0
const BANK_Z0: float = 56.75
const BANK_Z1: float = 60.25
const BANK_H: float = 2.35
const BANK_T: float = 0.14
const BANK_DOOR: Vector2 = Vector2(-5.35, -3.65)   # the doorway's x span in the north wall (1.7 m: the navmesh's 0.5 m radius needs it)
const BANK_DOOR_H: float = 2.05

func build_bank_shed() -> void:
	var t: float = BANK_T
	box(geo, "BankWall", Vector3(BANK_X0, 0, BANK_Z0), Vector3(BANK_DOOR.x, BANK_H, BANK_Z0 + t), "planks").set_meta("no_mantle", true)
	box(geo, "BankWall", Vector3(BANK_DOOR.y, 0, BANK_Z0), Vector3(BANK_X1, BANK_H, BANK_Z0 + t), "planks").set_meta("no_mantle", true)
	box(geo, "BankWall", Vector3(BANK_DOOR.x, BANK_DOOR_H, BANK_Z0), Vector3(BANK_DOOR.y, BANK_H, BANK_Z0 + t), "planks").set_meta("no_mantle", true)
	box(geo, "BankWall", Vector3(BANK_X0, 0, BANK_Z1 - t), Vector3(BANK_X1, BANK_H, BANK_Z1), "planks").set_meta("no_mantle", true)
	box(geo, "BankWall", Vector3(BANK_X0, 0, BANK_Z0 + t), Vector3(BANK_X0 + t, BANK_H, BANK_Z1 - t), "planks").set_meta("no_mantle", true)
	box(geo, "BankWall", Vector3(BANK_X1 - t, 0, BANK_Z0 + t), Vector3(BANK_X1, BANK_H, BANK_Z1 - t), "planks").set_meta("no_mantle", true)
	box(geo, "BankFloor", Vector3(BANK_X0 + t, 0.0, BANK_Z0 + t), Vector3(BANK_X1 - t, 0.03, BANK_Z1 - t), "floor_wood", false)


func build_nav_blocks() -> void:
	# T-251: every perk spot keeps the same floor out of the navmesh whichever machine (or its filler crate) the match
	# deals onto it: the widest by the deepest footprint. Only for the bake ("bake_only": the machine's and the
	# filler's own bodies are what stop you at runtime, so nothing invisible stands round a narrow cabinet).
	for sp: Array in PERK_SPOTS:
		var half: Vector3 = Vector3(PERK_SPOT_W * 0.5, 0, PERK_SPOT_D * 0.5)
		if absf(absf(float(sp[3])) - 90.0) < 1.0:
			half = Vector3(half.z, 0, half.x)
		var c: Vector3 = sp[2]
		box(geo, "NavBlock_PerkSpot_" + str(sp[0]), c - half, c + half + Vector3(0, NAV_SOLID_H, 0), "metal", true, false).add_to_group(&"bake_only", true)
	for cr: Array in CRATES:
		var chalf: Vector3 = Vector3(0.7, 0, 0.35) if absf(float(cr[2])) != 90.0 else Vector3(0.35, 0, 0.7)
		var p: Vector3 = cr[1]
		# T-125: only for the bake: the crate's own blocker (MysteryCrate) is solid where the crate stands; an empty
		# spot (the yard's well) must not keep an invisible box. MapRoot switches the "bake_only" group off.
		box(geo, "NavBlock_Crate", p - chalf, p + chalf + Vector3(0, 0.75, 0), "metal", true, false).add_to_group(&"bake_only", true)
	for ab: Array in AMMO_BOXES:
		var ah: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		var ap: Vector3 = ab[1]
		box(geo, "NavBlock_AmmoBox", ap - ah, ap + ah + Vector3(0, 0.62, 0), "metal", true, false)
	var bp: Vector3 = ARMORERS_BENCH[0]   # the bench runs 0.72 m out from the west wall, 1.5 m along it
	box(geo, "NavBlock_ArmorersBench", bp + Vector3(0, 0, -0.75), bp + Vector3(0.72, 0.9, 0.75), "metal", true, false)


func build_cellar() -> void:
	var cy: float = CELLAR_Y
	# stair hall: landing at ground level, then the ramp down (south)
	# art pass: limewashed rubble in the stair hall, coursed stone and flagstones in the vault, a brick soffit
	box(geo, "CellarLanding", Vector3(24.15, -0.5, 10.15), Vector3(28.0, 0.0, 13.0), "floor_wood")
	ramp_z("CellarStairs", 24.3, 27.85, 19.0, 13.0, cy, 0.0)
	wall_x("HallN", 10.0, 24.0, 28.0 + T * 0.5, cy, 3.0, [], "limewash")
	wall_z("HallE", 28.0, 10.0, 19.0, cy, 3.0, [], "limewash")
	wall_z("HallW", 24.0, 16.0, 19.0, cy, 3.0, [], "limewash")
	box(geo, "HallWLow", Vector3(24.0 - T * 0.5, cy, 10.0), Vector3(24.0 + T * 0.5, 0.0, 16.0), "limewash")
	box(geo, "HallS", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.0, 19.0 + T * 0.5), "limewash")
	box(geo, "HallRoof", Vector3(24.0, 3.0, 10.0 - T * 0.5), Vector3(28.0 + T * 0.5, 3.2, 19.0), "roof")
	box(geo, "HallUnder", Vector3(24.15, cy - 0.5, 13.0), Vector3(28.0, cy, 19.0), "cellar_stone")
	# the cellar
	box(geo, "CellarFloor", Vector3(24.0, cy - 0.5, 19.0), Vector3(36.0, cy, 31.0), "cellar_floor")
	box(geo, "CellarRoof", Vector3(24.0 - T * 0.5, CELLAR_TOP, 19.0), Vector3(36.0 + T * 0.5, -0.04, 31.0 + T * 0.5), "brick_cellar")
	box(geo, "CellarRoofSnow", Vector3(24.0 - T * 0.5, -0.04, 19.0), Vector3(36.0 + T * 0.5, 0.0, 31.0 + T * 0.5), "snow")
	wall_z("CelW", 24.0, 19.0, 31.0, cy, CELLAR_TOP, [[19.45, 21.05, cy, cy + DOOR_H]], "cellar_stone")   # the breach to the Old Cellar (T-051)
	wall_z("CelE", 36.0, 19.0, 31.0, cy, CELLAR_TOP, [[BAY_ARCH.x, BAY_ARCH.y, cy, cy + DOOR_H]], "cellar_stone")   # the arch to the bay (T-179)
	wall_x("CelS", 31.0, 24.0 - T * 0.5, 36.0 + T * 0.5, cy, CELLAR_TOP, [[LAG_DOOR.x, LAG_DOOR.y, cy, cy + DOOR_H]], "cellar_stone")   # Door_Lager (T-251)
	wall_x("CelN", 19.0, 28.0, 36.0 + T * 0.5, cy, CELLAR_TOP, [], "cellar_stone")
	box(geo, "CelNLintel", Vector3(24.0, cy + 2.6, 19.0 - T * 0.5), Vector3(28.0, CELLAR_TOP, 19.0 + T * 0.5), "cellar_stone")
	# vault pillars (cover, and something to run a loop around)
	for p: Vector2 in [Vector2(30.0, 23.0), Vector2(30.0, 27.0)]:
		box(geo, "CellarPillar", Vector3(p.x - 0.35, cy, p.y - 0.35), Vector3(p.x + 0.35, CELLAR_TOP, p.y + 0.35), "cellar_stone")
	# big dressing with collision (baked into the navmesh; all against walls, outside the loops and the stair spill):
	# the workbench + Helvetia crates on the north wall, the barrels in the NE corner, the kegs on the landing corner
	# T-251: the Crucible moved two doors down (the Dynamo Room, build_deep_cellar). Its alcove on the north wall holds
	# the inn's wash copper again, the brick-set boiler whose flue was there before the installers came (drawn by
	# _dress_cellar; solid, under NAV_SOLID_H)
	box(geo, "CellarCopperCol", Vector3(28.7, cy, 19.15), Vector3(30.3, cy + 1.05, 20.2), "metal", true, false).set_meta("no_mantle", true)
	# T-238 (the owner: "the cellar ... is too cluttered"): the north wall carried the installers' crates between the
	# Crucible and the lever and a 2.65 x 1.65 m heap of barrels, a sack and a crate in the north-east corner. Now the
	# wall between the Crucible and the lever is bare (the lever's approach is 3 m wide) and the corner holds the bench
	# with the two Helvetia crates stacked at its end, 0.75 m deep: the walk behind Twin Barrel is open at both ends.
	box(geo, "CellarCrateCol", Vector3(33.62, cy, 19.15), Vector3(34.3, cy + 1.1, 19.85), "metal", true, false)
	box(geo, "CellarBenchCol", Vector3(34.38, cy, 19.15), Vector3(35.95, cy + 0.9, 19.88), "metal", true, false)
	box(geo, "LandingKegCol", Vector3(27.0, 0.0, 10.15), Vector3(28.0, 0.8, 11.1), "metal", true, false)
	build_cellar_bay()
	build_deep_cellar()
	build_old_cellar()


## T-251: the shells of the Lagering Vault and the Dynamo Room (see LAG_* / DYN_*). The vault's south wall is the
## Lagering Vault's north wall (Door_Lager's opening is cut in build_cellar); the wall on x 34 between the two rooms
## carries Door_Dynamo's. Solid things: the row of tuns (one box, under NAV_SOLID_H), the generator set on its plinth,
## the Crucible's footprint, the bench and the crates in the Dynamo Room's north-east corner, two oil drums in its
## north-west corner. Everything else in them is dressing against the walls.
func build_deep_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var t2: float = T * 0.5
	# ---- the Lagering Vault (brick)
	box(geo, "LagerFloor", Vector3(LAG_X0 - t2, cy - 0.5, LAG_Z0), Vector3(LAG_X1, cy, LAG_Z1 + t2), "cellar_floor").set_meta("surface", "stone")
	box(geo, "LagerRoof", Vector3(LAG_X0, top, LAG_Z0 + t2), Vector3(LAG_X1 - t2, -0.04, LAG_Z1 + t2), "brick_cellar")
	box(geo, "LagerRoofSnow", Vector3(LAG_X0, -0.04, LAG_Z0 + t2), Vector3(LAG_X1 - t2, 0.0, LAG_Z1 + t2), "snow").set_meta("surface", "snow")
	wall_z("LagW", LAG_X0, LAG_Z0 + t2, LAG_Z1 + t2, cy, top, [], "brick_cellar")
	wall_x("LagS", LAG_Z1, LAG_X0 + t2, LAG_X1 - t2, cy, top, [], "brick_cellar")
	box(geo, "LagerTuns", Vector3(float(LAG_TUNS[0]) - LAG_TUN_R, cy, LAG_TUN_Z.x), Vector3(float(LAG_TUNS[LAG_TUNS.size() - 1]) + LAG_TUN_R, cy + 1.52, LAG_TUN_Z.y),
		"furniture", true, false).set_meta("no_mantle", true)
	# ---- the Dynamo Room (whitewash)
	box(geo, "DynFloor", Vector3(DYN_X0, cy - 0.5, DYN_Z0 + t2), Vector3(DYN_X1 + t2, cy, DYN_Z1 + t2), "cellar_floor").set_meta("surface", "stone")
	box(geo, "DynRoof", Vector3(DYN_X0 - t2, top, DYN_Z0 + t2), Vector3(DYN_X1 + t2, -0.04, DYN_Z1 + t2), "brick_cellar")
	box(geo, "DynRoofSnow", Vector3(DYN_X0 - t2, -0.04, DYN_Z0 + t2), Vector3(DYN_X1 + t2, 0.0, DYN_Z1 + t2), "snow").set_meta("surface", "snow")
	wall_x("DynN", DYN_Z0, 36.0 + t2, DYN_X1 + t2, cy, top, [], "limewash")
	wall_z("DynE", DYN_X1, DYN_Z0 + t2, DYN_Z1 - t2, cy, top, [], "limewash")
	wall_x("DynS", DYN_Z1, DYN_X0 + t2, DYN_X1 + t2, cy, top, [], "limewash")
	wall_z("DynW", DYN_X0, DYN_Z0 + t2, DYN_Z1 + t2, cy, top, [[DYN_DOOR.x, DYN_DOOR.y, cy, cy + DOOR_H]], "limewash")   # Door_Dynamo
	var zf: float = DYN_Z0 + t2   # the north wall's face
	box(geo, "NavBlock_Crucible", Vector3(DYN_CRUCIBLE.x - 1.0, cy, zf), Vector3(DYN_CRUCIBLE.x + 1.0, cy + NAV_SOLID_H, zf + 1.6), "metal", true, false)   # the Crucible's footprint (T-032)
	box(geo, "DynCrateCol", Vector3(DYN_X1 - 2.38, cy, zf), Vector3(DYN_X1 - 1.7, cy + 1.1, zf + 0.7), "metal", true, false)
	box(geo, "DynBenchCol", Vector3(DYN_X1 - 1.62, cy, zf), Vector3(DYN_X1 - 0.05, cy + 0.9, zf + 0.73), "metal", true, false)
	box(geo, "DynamoSet", Vector3(DYN_SET.position.x, cy, DYN_SET.position.y), Vector3(DYN_SET.end.x, cy + 1.5, DYN_SET.end.y), "metal", true, false).set_meta("no_mantle", true)
	box(geo, "DynDrumsCol", Vector3(DYN_X0 + t2, cy, zf), Vector3(DYN_X0 + t2 + 1.35, cy + 0.95, zf + 0.7), "metal", true, false).set_meta("no_mantle", true)


## T-179: the late-delivery bay's shell (see BAY_*): flagstones, coursed stone walls up to the vault's soffit height,
## a brick soffit under the field's snow, and the two solid things in it, the opened delivery crates in the two
## corners beside the arch (baked, under NAV_SOLID_H, no_mantle), so the floor between the arch and the machines
## stays one open 3.8 m apron and the machines' back walks stay clear.
func build_cellar_bay() -> void:
	var cy: float = CELLAR_Y
	var t2: float = T * 0.5
	box(geo, "BayFloor", Vector3(BAY_X0, cy - 0.5, BAY_Z0 - t2), Vector3(BAY_X1 + t2, cy, BAY_Z1 + t2), "cellar_floor").set_meta("surface", "stone")
	box(geo, "BayRoof", Vector3(BAY_X0 + t2, CELLAR_TOP, BAY_Z0 - t2), Vector3(BAY_X1 + t2, -0.04, BAY_Z1 + t2), "brick_cellar")
	box(geo, "BayRoofSnow", Vector3(BAY_X0 + t2, -0.04, BAY_Z0 - t2), Vector3(BAY_X1 + t2, 0.0, BAY_Z1 + t2), "snow").set_meta("surface", "snow")
	wall_x("BayN", BAY_Z0, BAY_X0 + t2, BAY_X1 + t2, cy, CELLAR_TOP, [], "cellar_stone")
	wall_x("BayS", BAY_Z1, BAY_X0 + t2, BAY_X1 + t2, cy, CELLAR_TOP, [], "cellar_stone")
	wall_z("BayE", BAY_X1, BAY_Z0 + t2, BAY_Z1 - t2, cy, CELLAR_TOP, [], "cellar_stone")
	var in0: float = BAY_X0 + t2
	box(geo, "BayCrateCol", Vector3(in0, cy, BAY_Z0 + t2), Vector3(in0 + 1.05, cy + 1.45, BAY_Z0 + t2 + 1.0), "furniture", true, false).set_meta("no_mantle", true)
	box(geo, "BayCrateCol", Vector3(in0, cy, BAY_Z1 - t2 - 0.9), Vector3(in0 + 0.95, cy + 0.95, BAY_Z1 - t2), "furniture", true, false).set_meta("no_mantle", true)


## THE OLD CELLAR (Update 02 section 6.1, DECISIONS T-051): the inn's own cellar under the taproom, older than the
## Helvetia vault. Door 5 (1250, zone OLD_CELLAR) in the taproom's west wall opens on the old cellar stairs in a
## stone lean-to (x -3..0, z 8..18.5), which come down to a landing and through the foundation into:
##   - the wine cellar (x 0..10.9, z 8..18.5): low brick arches on three piers, racks, casks, dripping water;
##   - the coal room (x 0..5, z 0..8): the coal chute window (a light well under the porch, W_CEL_COAL) and the
##     holding cell, an iron cage where the patrol locked Jakub (section 6.2: JakubCage, JakubSpawn, JakubWait);
##   - the root cellar (x 5..10.9, z 0..8): preserves, sacks, hams; the cousins' jam jars on the top shelf;
##   - the ice cellar (x 5..8.3, z 5..8), the cousins' hidden room under the bar (v3 section 4.6; Alix's trapdoor at
##     6.6, 5.6 is right overhead), bricked off from the coal room until the Cousins round is cleared (IceCellarSeal);
##   - the barrel vault (x 10.9..24, z 0..16): the training loop round the central barrel stack (corridors 4.8 m
##     each side, 3.2 m past the two pillars), the Gewehr 43, an ammo box, the vault window (a light well
##     outside the east wall, W_CEL_VAULT), and the breach the Helvetia installers knocked through to their own
##     cellar (x 20.85..24, z 16..21.3), bricked up until both Door 3 and Door 5 are bought (CellarBreach).
const OC_WELL_Y: float = -1.3          # the light wells' floor (the barricade origin); the room floor is 1.9 m below
const OC_SILL: float = 0.1             # window sill / top above the well floor: a half-height crawl-in window
const OC_WIN_H: float = 0.85
const OC_ANNEX_X: float = -3.0         # the stair lean-to's west wall
## Ground-slab holes [x, z, w, d]: under the taproom, the wine cellar's south bay, the lean-to, the Helvetia breach,
## the coal-chute light well (north) and the vault's light well (east).
const OC_HOLES: Array = [Rect2(-0.15, -0.15, 24.15, 16.15), Rect2(-0.15, 16.0, 11.2, 2.65), Rect2(-3.15, 7.85, 3.0, 10.8),
	Rect2(20.7, 16.0, 3.3, 5.45), Rect2(1.85, -4.65, 3.2, 4.5), Rect2(24.0, -2.1, 2.35, 5.45)]
## The holding cell: the cage's door gap (z) on its east face (x 2.55); 1.5 m so the navmesh runs through it.
const OC_CAGE: Rect2 = Rect2(0.15, 3.3, 2.4, 3.2)
const OC_CAGE_DOOR: Vector2 = Vector2(4.15, 5.65)
const OC_STACK: Rect2 = Rect2(15.9, 6.3, 3.1, 3.4)   # the barrel stack (training loop centre)
const OC_PILLARS: Array = [Vector2(17.45, 2.7), Vector2(17.45, 13.3)]
const OC_PIERS: Array = [Vector2(2.6, 13.2), Vector2(5.4, 13.2), Vector2(8.2, 13.2)]
## bare bulbs (glass position) that light with the cellar lever: two over the loop, one at each end of the wine cellar
const OC_BULBS: Array = [Vector3(17.45, CELLAR_Y + 2.45, 4.6), Vector3(17.45, CELLAR_Y + 2.45, 11.4),
	Vector3(2.6, CELLAR_Y + 2.2, 15.9), Vector3(8.2, CELLAR_Y + 2.2, 10.6)]
var _old_cellar_lit: Node3D   # the lit bulb glass, shown with the first OldCellarBulb light


## A ground slab over [x0, x1] x [z0, z1] (top at y 0) with rectangular holes, as a few boxes: the plane is cut
## on every hole edge and the cells outside all holes are merged into runs along X.
func _slab_with_holes(name_: String, x0: float, x1: float, z0: float, z1: float, holes: Array) -> void:
	var xs: Array[float] = [x0, x1]
	var zs: Array[float] = [z0, z1]
	for h: Rect2 in holes:
		for x: float in [h.position.x, h.end.x]:
			if x > x0 and x < x1 and not xs.has(x):
				xs.append(x)
		for z: float in [h.position.y, h.end.y]:
			if z > z0 and z < z1 and not zs.has(z):
				zs.append(z)
	xs.sort()
	zs.sort()
	for j: int in zs.size() - 1:
		var run0: float = INF
		var run1: float = INF
		for i: int in xs.size():
			var solid: bool = false
			if i < xs.size() - 1:
				solid = true
				var c: Vector2 = Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
				for h: Rect2 in holes:
					if h.has_point(c):
						solid = false
						break
			if solid:
				if run0 == INF:
					run0 = xs[i]
				run1 = xs[i + 1]
			elif run0 != INF:
				box(geo, name_, Vector3(run0, -0.5, zs[j]), Vector3(run1, 0.0, zs[j + 1]), "snow")
				run0 = INF


## The Old Cellar's collision shell (see the OC_ constants above). Floors and walls are stone, the taproom's floor
## is the vault's plank ceiling, the outdoor parts of the roof carry snow.
func build_old_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var wy: float = OC_WELL_Y
	var win: Array = [wy + OC_SILL, wy + OC_WIN_H]
	# ---- outer walls (up to the ground), the window openings at the light wells
	wall_x("OCN", 0.0, -T * 0.5, 24 + T * 0.5, cy, 0.0, [[2.65, 4.25] + win], "cellar_stone")
	wall_z("OCE", 24.0, 0.0, 10.0, cy, 0.0, [[1.0, 2.6] + win], "cellar_stone")
	wall_z("OCW", 0.0, 0.0, 18.5 + T * 0.5, cy, 0.0, [[15.8, 18.2, cy, cy + 2.4]], "cellar_stone")
	wall_x("OCWineS", 18.5, -T * 0.5, 10.9 + T * 0.5, cy, 0.0, [], "cellar_stone")
	wall_x("OCVaultS", 16.0, 10.9, 20.85 + T * 0.5, cy, 0.0, [], "cellar_stone")
	wall_z("OCTunW", 20.85, 16.0, 21.3 + T * 0.5, cy, 0.0, [], "limewash")
	# the breach is shut in the main navmesh (CellarBreach swaps in the open bake at runtime): a bake-only cut
	_bake_only.append(box(geo, "BreachNavCut", Vector3(23.85, cy, 19.45), Vector3(24.15, cy + DOOR_H, 21.05), "metal", true, false))
	wall_x("OCTunS", 21.3, 20.85, 24.0, cy, 0.0, [], "limewash")
	# ---- inner walls (up to the ceiling): the long middle wall with the root and wine arches, the coal / root / wine
	# partitions, the ice cellar's brick box (its west wall is the coal room's, with the bricked-up chute)
	wall_z("OCMid", 10.9, 0.0, 18.5, cy, top, [[1.6, 3.6, cy, cy + 2.4], [10.0, 13.2, cy, cy + 2.55]], "cellar_stone")
	wall_x("OCZ8", 8.0, 0.0, 10.9, cy, top, [[2.8, 4.6, cy, cy + 2.3], [8.7, 10.6, cy, cy + 2.3]], "cellar_stone")
	wall_z("OCX5", 5.0, 0.0, 8.0, cy, top, [[5.9, 7.5, cy, cy + 2.0]], "cellar_stone")
	wall_x("OCIceN", 5.0, 5.0, 8.3 + T * 0.5, cy, top, [], "brick_cellar")
	wall_z("OCIceE", 8.3, 5.0, 8.0, cy, top, [], "brick_cellar")
	# ---- floors and ceilings
	for f: Array in [[Vector3(-0.15, cy - 0.5, -0.15), Vector3(24.15, cy, 16.15)], [Vector3(-0.15, cy - 0.5, 16.0), Vector3(11.05, cy, 18.65)],
			[Vector3(20.7, cy - 0.5, 16.0), Vector3(24.0, cy, 21.45)]]:
		box(geo, "OCFloor", f[0], f[1], "cellar_floor").set_meta("surface", "stone")
	# the taproom's floor, cut round the cellar hatch behind the bar (T-229: HATCH_*; the Trapdoor leaf fills the hole until the Old Cellar opens)
	for seg: Array in [[Vector3(-T * 0.5, top, -T * 0.5), Vector3(HATCH_X0, 0.0, 16.0)], [Vector3(HATCH_X1, top, -T * 0.5), Vector3(24 + T * 0.5, 0.0, 16.0)],
			[Vector3(HATCH_X0, top, -T * 0.5), Vector3(HATCH_X1, 0.0, HATCH_Z0)], [Vector3(HATCH_X0, top, HATCH_Z1), Vector3(HATCH_X1, 0.0, 16.0)]]:
		box(geo, "OCRoof", seg[0], seg[1], "planks").set_meta("surface", "wood")
	for r: Array in [[Vector3(-0.15, top, 16.0), Vector3(11.05, 0.0, 18.65)], [Vector3(20.7, top, 16.0), Vector3(24.0, 0.0, 21.45)]]:
		box(geo, "OCRoofOut", r[0], Vector3((r[1] as Vector3).x, -0.04, (r[1] as Vector3).z), "brick_cellar")
		box(geo, "OCRoofSnow", Vector3((r[0] as Vector3).x, -0.04, (r[0] as Vector3).z), r[1], "snow").set_meta("surface", "snow")
	# ---- the stair lean-to: landing behind Door 5, the flight down the west wall of the inn, the foot landing
	var ax: float = OC_ANNEX_X
	wall_z("OCAnnW", ax, 7.85, 18.65, cy, 2.8, [], "cellar_stone")
	wall_x("OCAnnN", 8.0, ax - T * 0.5, 0.0, cy, 2.8, [], "cellar_stone")
	wall_x("OCAnnS", 18.5, ax - T * 0.5, 0.0, cy, 2.8, [], "cellar_stone")
	wall_z("OCAnnE", 0.0, 16.0 + T * 0.5, 18.65, 0.0, 2.8, [], "cellar_stone")
	box(geo, "OCAnnRoof", Vector3(ax - T * 0.5, 2.8, 7.85), Vector3(0.0, 3.0, 18.65), "roof")
	box(geo, "OCAnnLanding", Vector3(ax + T * 0.5, -0.5, 8.15), Vector3(-T * 0.5, 0.0, 9.95), "stone").set_meta("surface", "stone")
	ramp_z("OCStairs", ax + T * 0.5, -T * 0.5, 15.5, 9.95, cy, 0.0)
	box(geo, "OCAnnFloor", Vector3(ax, cy - 0.5, 15.5), Vector3(0.0, cy, 18.5), "cellar_floor").set_meta("surface", "stone")
	# ---- the light wells: a stone-lined pit at the window, steps up to the field (zombies come down them)
	box(geo, "WellPitN", Vector3(1.85, wy - 0.3, -2.15), Vector3(5.05, wy, -0.15), "stone").set_meta("surface", "stone")
	box(geo, "WellSideN", Vector3(1.85, wy - 0.3, -4.65), Vector3(2.0, 0.0, -0.15), "cellar_stone")
	box(geo, "WellSideN", Vector3(4.9, wy - 0.3, -4.65), Vector3(5.05, 0.0, -0.15), "cellar_stone")
	ramp_z("WellStepsN", 2.0, 4.9, -2.15, -4.65, wy, 0.0, -1e9, false)
	_stair_dressing.pop_back()   # stone steps instead (_dress_old_cellar)
	box(geo, "WellPitE", Vector3(24.0, wy - 0.3, 0.4), Vector3(26.35, wy, 3.35), "stone").set_meta("surface", "stone")
	box(geo, "WellSideE", Vector3(26.2, wy - 0.3, -2.1), Vector3(26.35, 0.0, 3.35), "cellar_stone")
	box(geo, "WellSideE", Vector3(24.0, wy - 0.3, 3.2), Vector3(26.2, 0.0, 3.35), "cellar_stone")
	box(geo, "WellSideE", Vector3(23.9, wy - 0.3, -2.1), Vector3(24.15, 0.0, 0.0), "cellar_stone")
	ramp_z("WellStepsE", 24.15, 26.2, 0.4, -2.1, wy, 0.0, -1e9, false)
	_stair_dressing.pop_back()
	# ---- solid things in the rooms (baked; all with a clear 2 m+ walk past them)
	box(geo, "OCChimneyFoot", Vector3(11.05, cy, 0.15), Vector3(13.15, top, 1.35), "brick_cellar")   # the hearth's footing
	for p: Vector2 in OC_PILLARS:
		box(geo, "OCPillar", Vector3(p.x - 0.35, cy, p.y - 0.35), Vector3(p.x + 0.35, top, p.y + 0.35), "cellar_stone")
	for p2: Vector2 in OC_PIERS:
		box(geo, "OCPier", Vector3(p2.x - 0.35, cy, p2.y - 0.35), Vector3(p2.x + 0.35, top, p2.y + 0.35), "cellar_stone")
	var st: Rect2 = OC_STACK
	box(geo, "OCBarrelStack", Vector3(st.position.x, cy, st.position.y), Vector3(st.end.x, cy + NAV_SOLID_H, st.end.y), "furniture", true, false)
	# racks, casks and shelves against the walls (drawn by _dress_old_cellar)
	for rk: Array in [[Vector3(0.15, cy, 8.15), Vector3(2.6, cy + 2.0, 8.6)], [Vector3(4.8, cy, 8.15), Vector3(8.5, cy + 2.0, 8.6)],
			[Vector3(3.0, cy, 17.95), Vector3(9.6, cy + 2.0, 18.35)], [Vector3(0.15, cy, 9.0), Vector3(0.6, cy + 2.0, 15.4)],
			[Vector3(9.85, cy, 13.9), Vector3(10.75, cy + 1.7, 17.9)],   # the big casks
			[Vector3(5.4, cy, 0.15), Vector3(10.5, cy + 2.1, 0.55)], [Vector3(5.15, cy, 0.8), Vector3(5.5, cy + 1.9, 4.5)],   # root shelves
			[Vector3(5.3, cy, 4.25), Vector3(8.1, cy + 0.8, 4.85)],   # sacks against the ice cellar's wall
			[Vector3(15.6, cy, 15.4), Vector3(19.3, cy + 2.0, 15.85)], [Vector3(23.4, cy, 4.4), Vector3(23.85, cy + 2.0, 9.6)]]:   # vault racks
		box(geo, "OCRackCol", rk[0], rk[1], "furniture", true, false).set_meta("no_mantle", true)   # (nobody camps on the sacks)
	# the holding cell: bars from floor to ceiling. Solid hidden panels along the bar lines cut the navmesh (the
	# bars are thinner than a cell); the door gap is left open, its door is a runtime collider (HoldingCage).
	var cg: Rect2 = OC_CAGE
	var ex: float = cg.end.x
	box(geo, "CagePanel", Vector3(cg.position.x, cy, cg.position.y - 0.06), Vector3(ex + 0.06, top, cg.position.y + 0.06), "metal", true, false)
	box(geo, "CagePanel", Vector3(cg.position.x, cy, cg.end.y - 0.06), Vector3(ex + 0.06, top, cg.end.y + 0.06), "metal", true, false)
	box(geo, "CagePanel", Vector3(ex - 0.06, cy, cg.position.y), Vector3(ex + 0.06, top, OC_CAGE_DOOR.x), "metal", true, false)
	box(geo, "CagePanel", Vector3(ex - 0.06, cy, OC_CAGE_DOOR.y), Vector3(ex + 0.06, top, cg.end.y), "metal", true, false)


## The second navmesh (T-051): the whole map baked again without the breach's bake-only cut, in a disabled region
## that CellarBreach swaps in for "Navigation" when it opens.
func _bake_breach_open() -> void:
	var nm: NavigationMesh = nav.navigation_mesh.duplicate() as NavigationMesh
	nm.clear_polygons()
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var r: NavigationRegion3D = NavigationRegion3D.new()
	r.name = "NavigationBreachOpen"
	r.navigation_mesh = nm
	r.enabled = false
	map_root.add_child(r)
	print("navmesh (breach open) polygons: %d" % nm.get_polygon_count())


func bake_navmesh() -> void:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	# UPDATE 07 Q-14: no walkable islands on furniture tops. The bake used to leave a 0.2 m patch of navmesh on every
	# table top (1.2 m wide, eroded by the agent radius), so a bot that climbed one was "on the navmesh" and its path
	# never left the table (the player's mantle also accepted the top as a navmesh spot). Regions under 8 cells
	# (0.5 m^2) are dropped; every real floor, closet and landing is far larger.
	nm.region_min_size = 8.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | EDGE_LAYER   # the edge wall shapes the navmesh though shots pass it (T-084)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, nav)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
	print("navmesh polygons: %d" % nm.get_polygon_count())


# ================================================================== art dressing (no collision)

func build_dressing() -> void:
	_dress_floors_and_ceilings()
	_dress_windows_and_doors()
	_dress_stairs()
	_dress_staircase()
	_dress_hearth()
	_dress_bar()
	_dress_taproom()
	_dress_upstairs()
	_dress_attic()
	_dress_stable()
	_dress_cellar()
	_dress_exterior()
	_dress_carters_road()
	_dress_yard()
	_dress_grounds()
	_dress_wreck()
	_dress_polish()
	_dress_lighting()
	_emit_library_props()


func _dress_floors_and_ceilings() -> void:
	for seg: Array in [[Vector3(0.15, 0.0, 0.15), Vector3(HATCH_X0, 0.012, 15.85)], [Vector3(HATCH_X1, 0.0, 0.15), Vector3(23.85, 0.012, 15.85)],   # (cut round the cellar hatch, T-229)
			[Vector3(HATCH_X0, 0.0, 0.15), Vector3(HATCH_X1, 0.012, HATCH_Z0)], [Vector3(HATCH_X0, 0.0, HATCH_Z1), Vector3(HATCH_X1, 0.012, 15.85)]]:
		Props.block(dress, seg[0], seg[1], "floorboards")
	Props.block(dress, Vector3(STB_X0 + 0.15, 0.0, STB_Z0 + 0.15), Vector3(STB_X1 - 0.15, 0.012, STB_Z1 - 0.15), "dirt")
	Props.block(dress, Vector3(18.15, 0.0, 16.0), Vector3(21.85, 0.012, 22.0), "dirt")
	# taproom ceiling beams (north-south) and a summer beam
	for x: float in [5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0]:
		Props.block(dress, Vector3(x - 0.14, TAP_H - 0.28, 0.15), Vector3(x + 0.14, TAP_H, 9.85 if x < STAIR_X1 else 15.85), "beam")
	# the stairwell's ceiling beams
	for z: float in [12.0, 14.0]:
		Props.block(dress, Vector3(0.15, UP_TOP - 0.24, z - 0.12), Vector3(STAIR_X1 - 0.15, UP_TOP, z + 0.12), "beam")
	Props.block(dress, Vector3(3.0, TAP_H - 0.36, 7.85), Vector3(23.85, TAP_H - 0.06, 8.15), "beam")
	for x: float in [8.0, 14.0, 20.0]:
		if x != FRONT_DOOR_X:   # the north wall's x 20 post would stand in the front door (T-072)
			Props.block(dress, Vector3(x - 0.15, 0, 0.15), Vector3(x + 0.15, TAP_H, 0.42), "beam")
		if x != 20.0:   # the south wall's x 20 post stood in the middle of the stable door (19..21): the beam lands on the lintel (T-072)
			Props.block(dress, Vector3(x - 0.15, 0, 15.58), Vector3(x + 0.15, TAP_H, 15.85), "beam")
	# upstairs beams + hall runner
	for x: float in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0]:
		var bz1: float = ASTAIR_Z0 - 0.02 if (x > ASTAIR_HOLE_X0 and x < ASTAIR_X1) else 9.85   # (T-224: the x 10 beam stops at the attic well)
		Props.block(dress, Vector3(x - 0.12, UP_TOP - 0.24, 0.15), Vector3(x + 0.12, UP_TOP, bz1), "beam")
	Props.block(dress, Vector3(1.0, UP_Y, HALL_Z0 + 0.7), Vector3(23.0, UP_Y + 0.012, ASTAIR_Z0 - 0.2), "rug")   # (the hall's runner, clear of the attic flight)
	# stable trusses: tie beams, their wall posts (pilasters, flush enough that nobody clips them on the landing), a
	# purlin each side and collar beams under the ridge (T-084: the loft looks up into a real roof now)
	for z: float in [24.5, 28.0, 31.5]:
		Props.block(dress, Vector3(STB_X0 + 0.15, STABLE_H - 0.6, z - 0.15), Vector3(STB_X1 - 0.15, STABLE_H - 0.3, z + 0.15), "beam")
		for x: float in [STB_X0 + 0.15, STB_X1 - 0.31]:
			Props.block(dress, Vector3(x, 0, z - 0.17), Vector3(x + 0.16, STABLE_H - 0.3, z + 0.17), "beam")
		Props.block(dress, Vector3(9.0, STABLE_H - 0.3, z - 0.1), Vector3(21.0, STABLE_H - 0.02, z + 0.1), "beam")   # the collar, up in the roof
		for x2: float in [9.0, 21.0]:
			Props.block(dress, Vector3(x2 - 0.12, STABLE_H - 0.6, z - 0.1), Vector3(x2 + 0.12, STABLE_H - 0.02, z + 0.1), "beam")
	for x3: float in [9.0, 21.0]:
		Props.block(dress, Vector3(x3 - 0.1, STABLE_H - 0.9, STB_Z0 + 0.15), Vector3(x3 + 0.1, STABLE_H - 0.6, STB_Z1 - 0.15), "beam")   # purlins


## Frames, sills (with snow outside), shutters and curtains for a window opening. The curtains are DraftCurtains
## (T-053): they billow in the draught, harder as `win_id`'s barricade loses boards.
func _window(pos: Vector3, yaw: float, curtains: bool, sill: float = WIN_SILL, top: float = WIN_TOP, win_id: String = "") -> void:
	var g: Node3D = Props.group(dress, "WindowDress", pos, yaw)   # local +Z = inside
	var hw: float = 0.8
	for side: float in [1.0, -1.0]:
		var face: float = side * T * 0.5
		var out: float = side
		Props.block(g, Vector3(-hw - 0.12, sill - 0.04, face), Vector3(-hw, top + 0.12, face + out * 0.06), "beam")
		Props.block(g, Vector3(hw, sill - 0.04, face), Vector3(hw + 0.12, top + 0.12, face + out * 0.06), "beam")
		Props.block(g, Vector3(-hw - 0.12, top, face), Vector3(hw + 0.12, top + 0.14, face + out * 0.07), "beam")
	# inner sill board, outer sill with a snow cap
	Props.block(g, Vector3(-hw - 0.15, sill - 0.05, -T * 0.5), Vector3(hw + 0.15, sill, T * 0.5 + 0.18), "beam")
	Props.block(g, Vector3(-hw - 0.15, sill - 0.06, -T * 0.5 - 0.22), Vector3(hw + 0.15, sill, -T * 0.5), "beam")
	Props.block(g, Vector3(-hw - 0.1, sill, -T * 0.5 - 0.2), Vector3(hw + 0.1, sill + 0.07, -T * 0.5 - 0.02), "snow", false)
	# open shutters outside, hanging askew
	for side: float in [-1.0, 1.0]:
		var sh: Node3D = Props.group(g, "Shutter", Vector3(side * (hw + 0.14), sill, -T * 0.5 - 0.04), side * 100.0)
		Props.block(sh, Vector3(-0.03, 0, 0), Vector3(0.03, top - sill + 0.1, side * -0.75), "planks")
		sh.rotation.z = deg_to_rad(side * 3.0)
	if curtains:
		for cx: float in [-hw - 0.25, hw + 0.25]:
			var dc: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/draft_curtain.gd", "DraftCurtainL" if cx < 0.0 else "DraftCurtainR", {
				"height": top - sill + 0.4, "mat_key": "cloth_red",
				"window": NodePath("../../../Gameplay/" + win_id) if win_id != "" else NodePath("")})
			dc.position = Vector3(cx, top + 0.05, T * 0.5 + 0.08)
			dc.rotation.y = PI
			g.add_child(dc)
		Props.block(g, Vector3(-hw - 0.5, top + 0.15, T * 0.5 + 0.06), Vector3(hw + 0.5, top + 0.18, T * 0.5 + 0.1), "iron")


func _door_frame(pos: Vector3, yaw: float, width: float, height: float) -> void:
	var g: Node3D = Props.group(dress, "DoorFrame", pos, yaw)
	for side: float in [1.0, -1.0]:
		var face: float = side * T * 0.5
		Props.block(g, Vector3(-width * 0.5 - 0.14, 0, face), Vector3(-width * 0.5, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(width * 0.5, 0, face), Vector3(width * 0.5 + 0.14, height + 0.14, face + side * 0.07), "beam")
		Props.block(g, Vector3(-width * 0.5 - 0.14, height, face), Vector3(width * 0.5 + 0.14, height + 0.18, face + side * 0.08), "beam")


func _dress_windows_and_doors() -> void:
	_window(Vector3(7.0, 0, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_TAP_N1")
	_window(Vector3(17.0, 0, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_TAP_N2")
	_window(Vector3(0, 0, 6.0), 90.0, true, WIN_SILL, WIN_TOP, "W_TAP_W")
	_window(Vector3(24.0, 0, 8.0), -90.0, true, WIN_SILL, WIN_TOP, "W_TAP_E")
	_window(Vector3(4.0, UP_Y, 0), 0.0, true, UP_Y + WIN_SILL - UP_Y, UP_Y + WIN_TOP - UP_Y, "W_UP_R1")
	_window(Vector3(20.0, UP_Y, 0), 0.0, true, WIN_SILL, WIN_TOP, "W_UP_R3")
	_window(Vector3(0, ATT_Y, ATT_WIN_Z), 90.0, false, WIN_SILL, WIN_TOP, "W_ATT_W")   # the attic's hoist windows (T-224), sacking, no curtains
	_window(Vector3(24.0, ATT_Y, ATT_WIN_Z), -90.0, false, WIN_SILL, WIN_TOP, "W_ATT_E")
	_window(Vector3(9.0, 0, 22.0), 0.0, false)
	_window(Vector3(14.0, 0, 22.0), 0.0, false)
	_window(Vector3(12.0, 0, 34.0), 180.0, false)
	_window(Vector3(22.0, LOFT_TOP, STB_Z1), 180.0, false)   # the loft door over the yard, its lower half boarded (T-084)
	_door_frame(Vector3(STAIR_X1, 0, 15.1), 90.0, 1.6, DOOR_H)
	_door_frame(Vector3(FRONT_DOOR_X, 0, 0.0), 0.0, 1.6, DOOR_H)   # the front door (T-072)
	_door_frame(Vector3(20.0, 0, 16.0), 0.0, 2.0, DOOR_H)
	_door_frame(Vector3(24.0, 0, 11.5), -90.0, 1.6, DOOR_H)
	_door_frame(Vector3(20.0, 0, 22.0), 0.0, 3.0, 2.6)
	for dx: float in [5.75, 11.75, 20.25]:
		_door_frame(Vector3(dx, UP_Y, HALL_Z0), 0.0, 1.5, 2.2)
	# the great doors at the stable's south end (barred)
	# (the campaign exfil cutscene tweens this group's rotation.x so the doors fall outward: its meshes stay
	# un-batched, hence the "keep" meta)
	for jx: float in [16.0, 20.0]:   # jambs and a lintel round the opening (3 m high since T-084: the gallery runs over them)
		Props.block(dress, Vector3(jx - 0.16, 0, 33.8), Vector3(jx + 0.16, GREAT_DOOR_H + 0.15, 34.2), "beam")
	Props.block(dress, Vector3(15.7, GREAT_DOOR_H - 0.05, 33.8), Vector3(20.3, GREAT_DOOR_H + 0.18, 34.2), "beam")
	var gd: Node3D = Props.group(dress, "GreatDoors", Vector3(18, 0, 33.82))
	Props.block(gd, Vector3(-2.0, 0, -0.06), Vector3(2.0, GREAT_DOOR_H, 0.0), "planks")
	Props.obox(gd, Vector3(0, GREAT_DOOR_H * 0.5, -0.12), Vector3(0.2, 3.5, 0.1), "beam", Vector3(0, 0, 54))
	Props.obox(gd, Vector3(0, GREAT_DOOR_H * 0.5, -0.12), Vector3(0.2, 3.5, 0.1), "beam", Vector3(0, 0, -54))
	Props.block(gd, Vector3(-2.2, 1.5, -0.24), Vector3(2.2, 1.7, -0.12), "iron")
	for m: Node in gd.get_children():
		m.set_meta("keep", true)


func _dress_stairs() -> void:
	for s: Array in _stair_dressing:
		var x0: float = s[0]
		var x1: float = s[1]
		var z_low: float = s[2]
		var z_high: float = s[3]
		var y_low: float = s[4]
		var y_high: float = s[5]
		var hollow_z: float = s[6]
		var rise: float = y_high - y_low
		var steps: int = int(ceil(rise / 0.22))
		var slope_ang: float = rad_to_deg(atan2(rise, absf(z_high - z_low))) * (1.0 if z_high < z_low else -1.0)
		for k: int in steps:
			var t0: float = float(k) / float(steps)
			var t1: float = float(k + 1) / float(steps)
			var za: float = lerpf(z_low, z_high, t0)
			var zb: float = lerpf(z_low, z_high, t1)
			var yb: float = lerpf(y_low, y_high, t1)
			var bottom: float = y_low
			if minf(za, zb) < hollow_z + 0.35:   # a shell over the soffit (the sawtooth hides behind it)
				bottom = lerpf(y_low, y_high, t1) - 0.3
			Props.block(dress, Vector3(x0, bottom, minf(za, zb)), Vector3(x1, yb - 0.05, maxf(za, zb)), "beam")
			Props.block(dress, Vector3(x0, yb - 0.05, minf(za, zb) - 0.02), Vector3(x1, yb, maxf(za, zb) + 0.02), "furniture")
		if hollow_z > -1e8:
			var zs: float = hollow_z + 0.4
			var mid_z: float = (z_high + zs) * 0.5
			var y_mid: float = lerpf(y_low, y_high, (z_low - mid_z) / (z_low - z_high)) - 0.35
			Props.obox(dress, Vector3((x0 + x1) * 0.5, y_mid, mid_z), Vector3(x1 - x0, 0.1, (zs - z_high) / cos(deg_to_rad(slope_ang)) + 0.1), "plaster", Vector3(slope_ang, 0, 0))
		if not bool(s[7]):
			continue
		# a handrail on the east side
		var rail_x: float = x1 - 0.05
		var mid: Vector3 = Vector3(rail_x, (y_low + y_high) * 0.5 + 0.95, (z_low + z_high) * 0.5)
		var rail_len: float = Vector2(z_high - z_low, rise).length()
		var ang: float = rad_to_deg(atan2(rise, absf(z_high - z_low))) * (1.0 if z_high < z_low else -1.0)
		Props.obox(dress, mid, Vector3(0.06, 0.06, rail_len), "furniture", Vector3(ang, 0, 0))
		var posts: int = int(rail_len / 0.6)
		for k2: int in posts + 1:
			var t: float = float(k2) / float(maxi(1, posts))
			var py: float = lerpf(y_low, y_high, t)
			var pz: float = lerpf(z_low, z_high, t)
			Props.block(dress, Vector3(rail_x - 0.02, py, pz - 0.02), Vector3(rail_x + 0.02, py + 0.95, pz + 0.02), "beam")


## The staircase to the guest rooms (see STAIR_*): a 1.5 m runner with brass stair rods, newel posts and turned
## balusters between the rail bars on the open side and round the hall's edge, a panelled string along the
## vestibule, a wall rail, wainscot following the flight, sconces, framed pictures stepping up the west wall and
## the well's tall east wall, a lantern in the well. The hall's north wall straight ahead at the top stays free.
func _dress_staircase() -> void:
	var g: Node3D = Props.group(dress, "Staircase", Vector3.ZERO)
	var x0: float = 0.15
	var x1: float = FLIGHT_X1
	var z_low: float = STAIR_Z0
	var z_high: float = STAIR_Z1
	var rise: float = UP_Y
	var steps: int = int(ceil(rise / 0.22))
	var ang: float = rad_to_deg(atan2(rise, z_low - z_high))
	var slope_len: float = Vector2(z_low - z_high, rise).length()
	var rc: float = (x0 + x1) * 0.5
	var rw: float = 0.75
	# runner over each tread and riser, with a brass rod at the back of every tread; it runs on to the hall runner
	for k: int in steps:
		var za: float = lerpf(z_low, z_high, float(k) / float(steps))
		var zb: float = lerpf(z_low, z_high, float(k + 1) / float(steps))
		var yb: float = lerpf(0.0, rise, float(k + 1) / float(steps))
		var yn: float = lerpf(0.0, rise, float(k + 2) / float(steps))
		Props.block(g, Vector3(rc - rw, yb, zb + 0.012), Vector3(rc + rw, yb + 0.012, za + 0.022), "runner", false)
		if k < steps - 1:
			Props.block(g, Vector3(rc - rw, yb, zb), Vector3(rc + rw, yn, zb + 0.012), "runner", false)
		Props.cyl(g, Vector3(rc, yb + 0.014, zb + 0.03), 0.011, rw * 2.0 + 0.04, "brass", Vector3(0, 0, 90))
	Props.block(g, Vector3(rc - rw, UP_Y + 0.012, 8.6), Vector3(rc + rw, UP_Y + 0.024, z_high), "runner", false)
	Props.block(g, Vector3(rc - rw, 0.012, z_low), Vector3(rc + rw, 0.024, 15.7), "runner", false)   # the foot
	Props.block(g, Vector3(x1 + 0.3, 0.012, 14.2), Vector3(STAIR_X1 - 0.3, 0.024, 15.7), "rug", false)   # the doormat
	# newel posts: foot, stair head, the corner of the hall rail and its end at the east wall
	var nx: float = x1 - 0.05
	Props.newel(g, Vector3(nx, 0.0, z_low + 0.02), 1.05)
	Props.newel(g, Vector3(nx, rise, z_high), 1.05)
	Props.newel(g, Vector3(nx, rise, 9.95), 1.05)
	Props.newel(g, Vector3(STAIR_X1 - 0.22, rise, 9.95), 1.05)
	# turned balusters between the curb and the handrail (the rail bars are collision geometry)
	var n: int = int(slope_len / 0.18)
	for k2: int in n:
		var t: float = (float(k2) + 0.5) / float(n)
		Props.cyl(g, Vector3(nx, lerpf(0.0, rise, t) + 0.46, lerpf(z_low, z_high, t)), 0.018, 0.9, "furniture")
	for zz: float in [9.2, 9.4, 9.6, 9.8]:
		Props.cyl(g, Vector3(nx, rise + 0.46, zz), 0.018, 0.9, "furniture")
	var hx: float = nx + 0.2
	while hx < STAIR_X1 - 0.35:
		Props.cyl(g, Vector3(hx, rise + 0.46, 9.95), 0.018, 0.9, "furniture")
		hx += 0.18
	# the string and the panelled under-stair along the vestibule (the panels' tops hide behind the string)
	var mid_z: float = (z_low + z_high) * 0.5
	var mid_y: float = rise * 0.5
	Props.obox(g, Vector3(x1 + 0.01, mid_y - 0.05, mid_z), Vector3(0.05, 0.34, slope_len + 0.2), "beam", Vector3(ang, 0, 0))
	for k3: int in steps:
		var za2: float = lerpf(z_low, z_high, float(k3) / float(steps))
		var zb2: float = lerpf(z_low, z_high, float(k3 + 1) / float(steps))
		if zb2 < 10.15:
			break
		Props.block(g, Vector3(x1, 0.0, zb2), Vector3(x1 + 0.03, _stair_y(zb2) - 0.2, za2), "wainscot")
	Props.block(g, Vector3(x1, 0.0, 10.15), Vector3(x1 + 0.045, 0.14, z_low), "beam")
	# casing over the hall floor's edge and the wall end exposed at the stair head (only the heights that show)
	Props.block(g, Vector3(nx, 3.45, z_high), Vector3(x1 + 0.03, UP_Y, 10.15), "beam")
	Props.block(g, Vector3(nx, 2.95, 9.85), Vector3(x1 + 0.03, 3.45, 10.15), "beam")
	# wall rail on the west wall with iron brackets
	Props.strut(g, Vector3(0.24, 0.98, z_low), Vector3(0.24, rise + 0.98, z_high), 0.045, "furniture", true)
	for t2: float in [0.1, 0.4, 0.7, 0.95]:
		Props.block(g, Vector3(0.15, lerpf(0.0, rise, t2) + 0.9, lerpf(z_low, z_high, t2) - 0.02), Vector3(0.24, lerpf(0.0, rise, t2) + 0.94, lerpf(z_low, z_high, t2) + 0.02), "iron")
	# wainscot following the flight up the west wall, with a chair rail and skirting
	Props.obox(g, Vector3(0.165, mid_y + 0.57, mid_z), Vector3(0.03, 0.9, slope_len - 0.1), "wainscot_matte", Vector3(ang, 0, 0))
	Props.obox(g, Vector3(0.18, mid_y + 1.14, mid_z), Vector3(0.06, 0.07, slope_len - 0.1), "beam", Vector3(ang, 0, 0))
	Props.obox(g, Vector3(0.17, mid_y + 0.09, mid_z), Vector3(0.045, 0.14, slope_len - 0.1), "beam", Vector3(ang, 0, 0))
	# sconces: mid-flight on the west wall, and over the vestibule on the east wall
	Props.wall_lamp(g, Vector3(0.16, _stair_y(12.1) + 1.75, 12.1), -90.0)
	Props.wall_lamp(g, Vector3(STAIR_X1 - 0.16, 2.3, 12.9), 90.0)
	# pictures stepping up the west wall (yaw -90) and the well's east wall (yaw 90), one over the door
	var ex: float = STAIR_X1 - 0.16
	Props.painting(g, Vector3(0.16, _stair_y(13.5) + 1.65, 13.5), -90.0, 0.42, 0.55, "portrait", 0, "frame_walnut")
	Props.painting(g, Vector3(0.16, _stair_y(12.7) + 1.65, 12.7), -90.0, 0.7, 0.5, "landscape", 1, "frame_gold")
	Props.painting(g, Vector3(0.16, _stair_y(11.5) + 1.6, 11.5), -90.0, 0.4, 0.32, "photo", 0, "frame_black", 2.0, true)
	Props.painting(g, Vector3(0.16, _stair_y(10.6) + 1.7, 10.6), -90.0, 0.6, 0.45, "hunting", 1, "frame_walnut")
	Props.painting(g, Vector3(0.16, _stair_y(9.7) + 1.65, 9.7), -90.0, 0.4, 0.5, "portrait", 1, "frame_gold", -1.5)
	Props.painting(g, Vector3(ex, 1.75, 11.3), 90.0, 0.55, 0.42, "licence", 0, "frame_black")
	Props.painting(g, Vector3(ex, 3.2, 12.0), 90.0, 0.7, 0.5, "landscape", 0, "frame_walnut")
	Props.painting(g, Vector3(ex, 4.45, 11.4), 90.0, 0.42, 0.55, "portrait", 2, "frame_gold", 1.0)
	Props.painting(g, Vector3(ex, 3.35, 13.4), 90.0, 0.4, 0.32, "photo", 1, "frame_black", 0.0, true)
	Props.painting(g, Vector3(ex, 3.3, 15.1), 90.0, 0.55, 0.4, "stilllife", 1, "frame_gold")   # over the door
	# the vestibule: a coat rack in its north-east corner, cobwebs high in the well
	Props.coat_rack(g, Vector3(STAIR_X1 - 0.45, 0, 10.5))
	Props.cobweb(g, Vector3(STAIR_X1 - 0.15, UP_TOP - 0.01, 15.85), 180.0, 0.9)
	Props.cobweb(g, Vector3(0.15, UP_TOP - 0.01, 15.85), 90.0, 0.7)


## The Helvetia cellar: stone ribs and corbels under the brick soffit, pillar plinths, puddles, a drain, the
## installers' workbench and crates with the fuse box and conduit to the lever and the bulbs, barrels, sacks,
## shelves of preserves between the machines, a wine rack, the coal chute and heap, pipes, cobwebs, lanterns.
## Nothing here blocks a machine front, the panels behind them, the stair spill or the pillar loops; the north
## face of the north pillar stays bare for a story item.
func _dress_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var g: Node3D = Props.group(dress, "Cellar", Vector3.ZERO)
	_cellar_lit = Node3D.new()
	_cellar_lit.name = "CellarLit"
	dress.add_child(_cellar_lit)
	# ---- the vault: segmental stone ribs between the walls and the pillars (two across, one along), corbels
	var spring: float = cy + 2.05
	var crown: float = top - 0.1
	for rz: float in [23.0, 27.0]:
		_arch(g, Vector3(24.15, spring, rz), Vector3(29.65, spring, rz), crown - spring)
		_arch(g, Vector3(30.35, spring, rz), Vector3(35.85, spring, rz), crown - spring)
	_arch(g, Vector3(30.0, spring, 23.35), Vector3(30.0, spring, 26.65), crown - spring)   # (none north of the pillar: the Crucible's alcove)
	_arch(g, Vector3(30.0, spring, 27.35), Vector3(30.0, spring, 30.85), crown - spring)
	for p: Vector2 in [Vector2(30.0, 23.0), Vector2(30.0, 27.0)]:
		Props.block(g, Vector3(p.x - 0.44, cy, p.y - 0.44), Vector3(p.x + 0.44, cy + 0.42, p.y + 0.44), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.4, cy + 0.42, p.y - 0.4), Vector3(p.x + 0.4, cy + 0.5, p.y + 0.4), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.46, spring - 0.3, p.y - 0.46), Vector3(p.x + 0.46, spring, p.y + 0.46), "cellar_stone")
	# ---- floor: puddles, a drain in the SW corner, flag edges
	Props.puddle(g, Vector3(26.9, cy, 30.1), 1.1, 0.7, 40.0)   # (T-238: one, at the drain; there were four, one between the pillars)
	Props.block(g, Vector3(25.3, cy + 0.002, 29.6), Vector3(25.9, cy + 0.012, 30.2), "iron")
	for i: int in 4:
		Props.block(g, Vector3(25.36 + i * 0.14, cy + 0.012, 29.66), Vector3(25.42 + i * 0.14, cy + 0.016, 30.14), "char")
	# ---- north wall: the alcove between the stair mouth and the fuse box. T-251: the Crucible and the lever are in the
	# Dynamo Room now (_dress_deep_cellar); the alcove holds the inn's wash copper under the old flue, and the fuse
	# box is the vault's sub-board: its conduit runs up to the bulbs and on along the soffit to the door in the south wall
	_wash_copper(g)
	# (T-238: the installers' two crates stand at the bench's end in the north-east corner now, see below)
	Props.fuse_box(g, Vector3(31.2, cy + 1.95, 19.15), 180.0, 0.5, 0.7)
	# (T-247: the installers' name painted over the fuse box is gone; the owner: "remove or make it more subtle")
	Props.pipe(g, Vector3(31.2, cy + 2.3, 19.25), Vector3(31.2, top - 0.08, 19.25), 0.02)
	var cl: float = top - 0.08
	Props.cable(g, Vector3(26.5, cl, 27.5), Vector3(26.0, cl, 30.85), 0.05, 0.015, 6)   # on to the Lagering Vault and the Dynamo Room
	Props.cable(g, Vector3(31.2, cl, 19.3), Vector3(31.0, cl, 22.5), 0.05, 0.015, 6)
	Props.cable(g, Vector3(31.0, cl, 22.5), Vector3(27.0, cl, 22.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(31.0, cl, 22.5), Vector3(33.0, cl, 22.5), 0.04, 0.015, 5)
	Props.cable(g, Vector3(27.0, cl, 22.5), Vector3(26.5, cl, 27.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(33.0, cl, 22.5), Vector3(33.5, cl, 27.5), 0.06, 0.015, 8)
	Props.cable(g, Vector3(33.5, cl, 27.5), Vector3(30.35, cl, 28.7), 0.05, 0.015, 7)   # to the ninth machine's bulb
	for bp: Vector3 in CELLAR_BULBS:
		Props.pendant(g, bp, top - 0.02, _cellar_lit, "tin")
	_dress_cellar_bay(g)
	_dress_deep_cellar(g)
	Props.bake(_cellar_lit)
	for lit: Node in _cellar_lit.get_children():
		lit.set_meta("keep", true)
	# ---- NE corner: the installers' workbench, a barrel and a sack; a tally chalked on the wall above
	# T-238: the bench against the north wall and the two crates the machines' glass came in, stacked at its end; the
	# two barrels, the sack and the loose crate that filled the corner out to z 20.8 are gone
	Props.workbench(g, Vector3(35.15, cy, 19.5), 180.0, 1.5, 0.7)
	Props.crate(g, Vector3(33.96, cy, 19.5), 0.6, 180.0)
	Props.crate(g, Vector3(33.98, cy + 0.6, 19.5), 0.5, 174.0)
	# (T-247: the glass crates' maker's stencil, ZERBRECHLICH and the chalk tally over the bench are gone)
	# (T-238: the three shelves of preserves that stood in the machines' back-panel walks are gone: the walls behind
	# the west and east rows are bare stone, the walk is its full 1.1 m, and the inn's stores are in the Old Cellar)
	# ---- west wall: a wine rack (bottles lying with their necks out). T-251: it stood on the south wall's west half,
	# where Door_Lager is now
	var wr: Node3D = Props.group(g, "WineRack", Vector3(24.15, cy, 26.9), -90.0)
	Props.block(wr, Vector3(-1.45, 0, -0.34), Vector3(-1.4, 1.5, 0.0), "planks")
	Props.block(wr, Vector3(1.4, 0, -0.34), Vector3(1.45, 1.5, 0.0), "planks")
	var rrng: RandomNumberGenerator = RandomNumberGenerator.new()
	rrng.seed = 31
	for row: int in 5:
		var ry: float = 0.22 + row * 0.26
		Props.block(wr, Vector3(-1.45, ry - 0.02, -0.34), Vector3(1.45, ry, 0.0), "furniture")
		for col: int in 28:
			if rrng.randf() < 0.3:
				continue
			var bx: float = -1.35 + col * 0.1
			var key: String = "bottle_green" if rrng.randf() < 0.7 else "bottle_amber"
			Props.cyl(wr, Vector3(bx, ry + 0.045, -0.2), 0.035, 0.3, key, Vector3(90, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ---- SE corner: the coal chute, the heap and a shovel
	# (T-238: the heap is the corner's now, 1.3 m across behind Ledger Lager; it was 2.2 m and ran under the machine)
	Props.ball(g, Vector3(35.42, cy, 30.42), Vector3(1.3, 0.75, 1.3), "coal")
	var crng: RandomNumberGenerator = RandomNumberGenerator.new()
	crng.seed = 44
	for i2: int in 5:
		Props.ball(g, Vector3(34.85 + crng.randf_range(0, 0.9), cy + 0.04, 29.45 + crng.randf_range(0, 0.5)), Vector3(0.16, 0.1, 0.14) * crng.randf_range(0.7, 1.4), "coal")
	Props.obox(g, Vector3(35.35, cy + 1.9, 30.1), Vector3(1.5, 0.06, 0.6), "iron", Vector3(0, 0, 52))
	for sz: float in [-0.3, 0.3]:
		Props.obox(g, Vector3(35.35, cy + 1.95, 30.1 + sz), Vector3(1.5, 0.16, 0.03), "iron", Vector3(0, 0, 52))
	Props.block(g, Vector3(35.78, cy + 2.2, 29.65), Vector3(35.86, cy + 2.95, 30.55), "beam")
	Props.block(g, Vector3(35.8, cy + 2.26, 29.72), Vector3(35.86, cy + 2.9, 30.48), "window_dark")
	Props.obox(g, Vector3(35.6, cy + 0.6, 28.75), Vector3(0.035, 1.3, 0.035), "beam", Vector3(0, 0, -14))
	Props.obox(g, Vector3(35.45, cy + 0.05, 28.75), Vector3(0.22, 0.02, 0.26), "iron", Vector3(0, 0, -14))
	# ---- pipes along the top of the long walls, and the lanterns that are always lit
	Props.pipe(g, Vector3(24.22, cy + 2.7, 19.3), Vector3(24.22, cy + 2.7, 30.8), 0.035, "iron")
	Props.pipe(g, Vector3(24.22, cy + 2.7, 25.0), Vector3(24.22, cy + 1.3, 25.0), 0.03, "iron")
	Props.cyl(g, Vector3(24.3, cy + 1.3, 25.0), 0.04, 0.1, "brass", Vector3(0, 0, 90))
	Props.pipe(g, Vector3(35.78, cy + 2.75, 19.3), Vector3(35.78, cy + 2.75, 28.6), 0.035, "rust")
	Props.lantern(g, Vector3(26.0, cy + 2.2, 19.6), top - 0.02)
	Props.wall_lamp(g, Vector3(26.0, 2.45, 10.15), 180.0)
	# ---- cobwebs in the corners
	Props.cobweb(g, Vector3(24.15, top - 0.02, 30.85), 90.0, 0.9)
	Props.cobweb(g, Vector3(35.85, top - 0.02, 30.85), 180.0, 0.8)
	Props.cobweb(g, Vector3(35.85, top - 0.02, 19.15), -90.0, 0.8)
	Props.cobweb(g, Vector3(24.15, 2.98, 10.15), 0.0, 0.7)
	# ---- the stair hall: kegs on the landing corner, a wall rail, "KELLER" over the steps
	_lib_barrel(Vector3(27.55, 0.0, 10.55), 30.0, 0.25, 0.62)
	_lib_barrel(Vector3(27.35, 0.0, 10.4), 90.0, 0.17, 0.5, true)
	Props.sack(g, Vector3(27.3, 0.0, 10.85), 10.0, 0.7)
	Props.strut(g, Vector3(24.24, 0.95, 13.0), Vector3(24.24, cy + 0.95, 19.0), 0.04, "iron", true)
	for t3: float in [0.05, 0.5, 0.95]:
		var hz: float = lerpf(13.0, 19.0, t3)
		var hy: float = lerpf(0.0, cy, t3) + 0.9
		Props.block(g, Vector3(24.15, hy - 0.02, hz - 0.02), Vector3(24.24, hy + 0.02, hz + 0.02), "iron")
	Props.stencil(g, Vector3(27.85, 2.2, 12.2), 90.0, "KELLER", 44, Color(0.2, 0.18, 0.15, 0.85), 0.004)
	_dress_old_cellar()


## T-179: the late-delivery bay (NACHLIEFERUNG). The fiction: two cabinets came down the salt road after the eight
## replacement units, on a docket nobody had ordered (Skyhook from Werk Thalbach's wind tunnel; Magpie in an
## olive crate stencilled in English from a range on the far side of the world), so the landlord had the installers
## knock an arch through to the old ice vault under the field. Dressing only (the crates' colliders are in
## build_cellar_bay): the arch's jambs and painted lintel, one stone rib down the bay's spine, the bay's bulb on a
## cable from the vault's run, an oil lantern by the arch that is always lit (the machines read before the lever),
## the delivery note between the machines, the two opened crates, straw, a puddle, cobwebs.
func _dress_cellar_bay(parent: Node3D) -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var g: Node3D = Props.group(parent, "CellarBay", Vector3.ZERO)
	var in0: float = BAY_X0 + T * 0.5
	var in1: float = BAY_X1 - T * 0.5
	var zn: float = BAY_Z0 + T * 0.5
	var zs: float = BAY_Z1 - T * 0.5
	var am: float = (BAY_ARCH.x + BAY_ARCH.y) * 0.5
	var cream: Color = Color(0.92, 0.9, 0.82, 0.8)
	# ---- the arch: dressed stone jambs proud of both faces, a timber lintel (T-247: the bay's name in big letters on
	# its outer face is gone; the way out is still painted on the inner face, small)
	for jz: Array in [[BAY_ARCH.x - 0.2, BAY_ARCH.x], [BAY_ARCH.y, BAY_ARCH.y + 0.2]]:
		Props.block(g, Vector3(BAY_X0 - T * 0.5 - 0.05, cy, float(jz[0])), Vector3(BAY_X0 + T * 0.5 + 0.05, cy + DOOR_H, float(jz[1])), "cellar_stone")
	Props.block(g, Vector3(BAY_X0 - T * 0.5 - 0.07, cy + DOOR_H, BAY_ARCH.x - 0.3), Vector3(BAY_X0 + T * 0.5 + 0.07, cy + DOOR_H + 0.24, BAY_ARCH.y + 0.3), "beam")
	Props.stencil(g, Vector3(BAY_X0 + T * 0.5 + 0.075, cy + DOOR_H + 0.12, am), -90.0, "AUSGANG · KELLER", 24, Color(cream, 0.55), 0.003)
	# a hanging enamel plate over the east aisle, in line with the arch (the east wall itself is behind the machines):
	# seen from the stair foot and from the middle of the vault
	var hp: Vector3 = Vector3(32.9, cy + 2.4, am)
	Props.block(g, hp + Vector3(-0.02, -0.15, -0.5), hp + Vector3(0.02, 0.15, 0.5), "enamel_plate")
	for cz: float in [-0.4, 0.4]:
		Props.strut(g, hp + Vector3(0, 0.15, cz), Vector3(hp.x, top - 0.02, hp.z + cz), 0.008, "iron")
	Props.stencil(g, hp + Vector3(-0.022, 0.0, 0.0), 90.0, "NACHLIEFERUNG →", 24, Color(0.12, 0.14, 0.18, 0.9), 0.0032, SurfaceText.PRINT)   # T-247: the tonic names are gone
	Props.stencil(g, hp + Vector3(0.022, 0.0, 0.0), -90.0, "KELLER · TREPPE", 24, Color(0.12, 0.14, 0.18, 0.9), 0.0032, SurfaceText.PRINT)
	# ---- the vault: one rib down the bay's spine, corbelled on the north and south walls
	var spring: float = cy + 2.05
	_arch(g, Vector3(37.9, spring, zn), Vector3(37.9, spring, zs), (top - 0.1) - spring)
	# ---- the bay's bulb on a cable through the lintel from the vault's run; a pipe along the north wall
	var cl: float = top - 0.08
	Props.cable(g, Vector3(33.25, cl, am), Vector3(BAY_X0 - T * 0.5, cl, am), 0.04, 0.015, 5)
	Props.cable(g, Vector3(in0, cl, am), Vector3(BAY_BULB.x, cl, am), 0.05, 0.015, 6)
	Props.pendant(g, BAY_BULB, top - 0.02, _cellar_lit, "tin")
	Props.pipe(g, Vector3(in0 + 0.05, cy + 2.7, zn + 0.07), Vector3(in1 - 0.05, cy + 2.7, zn + 0.07), 0.03, "iron")
	for bl: Array in BAY_LAMPS:   # lit by CellarBayLamp, CellarBayLamp2 (build_cellar_gameplay)
		Props.lantern(g, bl[1], top - 0.02)
	# ---- the far wall between the machines: the delivery note pinned to a board (T-247: the maker's name painted
	# over it and the note's typed lines are gone; the sheet reads as an old docket from across the bay)
	Props.block(g, Vector3(in1 - 0.03, cy + 0.95, am - 0.36), Vector3(in1, cy + 1.55, am + 0.36), "board_wood")
	Props.block(g, Vector3(in1 - 0.036, cy + 1.0, am - 0.27), Vector3(in1 - 0.03, cy + 1.48, am + 0.27), "paper_old", false)
	Props.cyl(g, Vector3(in1 - 0.04, cy + 1.45, am), 0.012, 0.02, "brass", Vector3(0, 0, 90))   # the drawing pin
	# ---- NW corner: Skyhook's crate (over the north BayCrateCol), a smaller one on it (T-247: the consignment
	# stencils on both are gone)
	Props.crate(g, Vector3(in0 + 0.52, cy, zn + 0.5), 0.95, -90.0)
	Props.crate(g, Vector3(in0 + 0.5, cy + 0.95, zn + 0.47), 0.5, -80.0)
	# ---- SW corner: Magpie's crate (over the south BayCrateCol), olive, open, straw in it; its lid against the wall
	Props.block(g, Vector3(in0 + 0.05, cy, zs - 0.85), Vector3(in0 + 0.9, cy + 0.9, zs - 0.05), "olive_drab")
	Props.block(g, Vector3(in0 + 0.11, cy + 0.86, zs - 0.79), Vector3(in0 + 0.84, cy + 0.92, zs - 0.11), "hay", false)
	# (T-238: battens, so it reads as a crate: it rendered as a plain green block) corner posts, a top and a foot rail
	for cp: Vector2 in [Vector2(in0 + 0.9, zs - 0.85), Vector2(in0 + 0.9, zs - 0.05), Vector2(in0 + 0.05, zs - 0.85)]:
		Props.block(g, Vector3(cp.x - 0.035, cy, cp.y - 0.035), Vector3(cp.x + 0.035, cy + 0.9, cp.y + 0.035), "beam")
	for ry: Array in [[0.0, 0.09], [0.81, 0.9]]:
		Props.block(g, Vector3(in0 + 0.9, cy + float(ry[0]), zs - 0.85), Vector3(in0 + 0.915, cy + float(ry[1]), zs - 0.05), "beam")
		Props.block(g, Vector3(in0 + 0.05, cy + float(ry[0]), zs - 0.865), Vector3(in0 + 0.9, cy + float(ry[1]), zs - 0.85), "beam")
	# (T-247: the olive crate's English stencils are gone: THIS SIDE UP, and a real place name on its lid)
	Props.obox(g, Vector3(in0 + 1.4, cy + 0.5, zs - 0.03), Vector3(0.85, 1.0, 0.05), "olive_drab")
	Props.obox(g, Vector3(in0 + 2.0, cy + 0.46, zs - 0.08), Vector3(0.028, 0.92, 0.028), "iron", Vector3(9, 0, 6))   # the crowbar that opened them
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 179
	Hay.scatter(g, Vector3(in0 + 1.5, cy, zs - 0.8), 0.8, 0.6, 22, 179 + srng.randi_range(0, 3), 0)   # (T-238: packing straw as stalks; it was nine flat blobs)
	# ---- the floor and the corners
	Props.puddle(g, Vector3(38.6, cy, 27.4), 1.0, 0.6, 25.0)
	Props.block(g, Vector3(38.6, cy + 0.002, 25.7), Vector3(39.1, cy + 0.012, 26.2), "iron")   # a drain under the bulb
	for i2: int in 3:
		Props.block(g, Vector3(38.66 + i2 * 0.15, cy + 0.012, 25.75), Vector3(38.72 + i2 * 0.15, cy + 0.016, 26.15), "char")
	Props.cobweb(g, Vector3(in1, top - 0.02, zn), -90.0, 0.8)
	Props.cobweb(g, Vector3(in1, top - 0.02, zs), 180.0, 0.9)


## A wine rack against a wall (local z 0 = the wall, the room at local -Z): uprights, slatted boards and bottles
## lying with their necks out; a gap left here and there.
func _wine_rack(parent: Node3D, pos: Vector3, yaw: float, w: float, rows: int, seed_v: int, depth: float = 0.4) -> void:
	var g: Node3D = Props.group(parent, "WineRack", pos, yaw)
	var n_up: int = maxi(2, int(w / 1.2) + 1)
	for k: int in n_up:
		var x: float = -w * 0.5 + w * float(k) / float(n_up - 1)
		Props.block(g, Vector3(x - 0.03, 0, -depth), Vector3(x + 0.03, 0.3 + rows * 0.26, 0.0), "beam")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for row: int in rows:
		var ry: float = 0.22 + row * 0.26
		Props.block(g, Vector3(-w * 0.5, ry - 0.02, -depth), Vector3(w * 0.5, ry, 0.0), "furniture")
		var cols: int = int(w / 0.1)
		for col: int in cols:
			if rng.randf() < 0.28:
				continue
			var bx: float = -w * 0.5 + 0.06 + col * 0.1
			var key: String = "bottle_green" if rng.randf() < 0.72 else "bottle_amber"
			Props.cyl(g, Vector3(bx, ry + 0.045, -depth * 0.55), 0.035, depth * 0.8, key, Vector3(90, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A child's chalk stick figure on a wall (local -Z = out of the wall): head ring, body, arms out to the sides
## (so neighbours hold hands), two legs. `h` is its height.
func _chalk_figure(parent: Node3D, base: Vector3, yaw: float, h: float) -> void:
	var g: Node3D = Props.group(parent, "Chalk", base, yaw)
	var wd: float = 0.012
	Props._noshadow(Props.cyl(g, Vector3(0, h * 0.86, -0.004), h * 0.11, 0.004, "paper", Vector3(90, 0, 0)))
	Props._noshadow(Props.cyl(g, Vector3(0, h * 0.86, -0.006), h * 0.085, 0.004, "brick_cellar", Vector3(90, 0, 0)))
	Props._noshadow(Props.obox(g, Vector3(0, h * 0.5, -0.004), Vector3(wd, h * 0.42, 0.004), "paper"))
	Props._noshadow(Props.obox(g, Vector3(0, h * 0.62, -0.004), Vector3(h * 0.62, wd, 0.004), "paper", Vector3(0, 0, -6)))
	for s: float in [-1.0, 1.0]:
		Props._noshadow(Props.obox(g, Vector3(s * h * 0.09, h * 0.15, -0.004), Vector3(wd, h * 0.32, 0.004), "paper", Vector3(0, 0, s * 18.0)))


## The Old Cellar's dressing (no collision; the colliders are in build_old_cellar): the lean-to stairs, the wine
## cellar's arches and racks, the coal room with the cage, the root cellar's stores, the cousins' ice cellar, the
## barrel vault and the breach, the light wells outside.
func _dress_old_cellar() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var wy: float = OC_WELL_Y
	var g: Node3D = Props.group(dress, "OldCellar", Vector3.ZERO)
	_old_cellar_lit = Node3D.new()
	_old_cellar_lit.name = "OldCellarLit"
	dress.add_child(_old_cellar_lit)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1251
	# ---------------- the lean-to: Door 5's frame, a snowed roof, a lantern over the flight, a lamp at the foot
	_door_frame(Vector3(0.0, 0, 9.05), 90.0, 1.6, DOOR_H)
	Props.block(g, Vector3(OC_ANNEX_X - 0.2, 3.0, 7.75), Vector3(0.05, 3.1, 18.75), "snow")
	Props.block(g, Vector3(OC_ANNEX_X - 0.25, 2.75, 7.7), Vector3(0.05, 2.82, 18.8), "beam")
	Props.snow_drift(g, Vector3(OC_ANNEX_X - 0.4, 0, 13.0), Vector3(1.2, 0.7, 9.0))
	# its outside above the ground: weatherboards over the stone, a sill beam, corner posts
	Props.block(g, Vector3(OC_ANNEX_X - 0.19, 0.0, 7.83), Vector3(OC_ANNEX_X - 0.15, 2.8, 18.67), "planks")
	for ez: Array in [[7.83, 7.85], [18.65, 18.67]]:
		Props.block(g, Vector3(OC_ANNEX_X - 0.19, 0.0, float(ez[0]) - (0.04 if ez[0] < 10.0 else 0.0)), Vector3(0.0, 2.8, float(ez[1]) + (0.04 if ez[0] > 10.0 else 0.0)), "planks")
	Props.block(g, Vector3(OC_ANNEX_X - 0.24, 0.0, 7.8), Vector3(OC_ANNEX_X - 0.15, 0.25, 18.7), "beam")
	for pz: float in [7.8, 13.25, 18.7]:
		Props.block(g, Vector3(OC_ANNEX_X - 0.26, 0.0, pz - 0.1), Vector3(OC_ANNEX_X - 0.12, 2.8, pz + 0.1), "beam")
	Props.lantern(g, Vector3(-1.5, 2.15, 12.6), 2.8)
	Props.wall_lamp(g, Vector3(OC_ANNEX_X + 0.15, cy + 2.2, 17.0), -90.0)
	# (T-247: VORSICHT STUFEN on the annex wall is gone)
	Props.crate(g, Vector3(-2.4, cy, 18.0), 0.55, 12.0)
	for i: int in 5:
		Props.cyl(g, Vector3(-2.55 + i * 0.09, cy + 0.6, 18.0), 0.035, 0.28, "bottle_green")
	Props.cobweb(g, Vector3(OC_ANNEX_X + 0.15, 2.78, 8.15), 0.0, 0.7)
	Props.cobweb(g, Vector3(-0.15, top - 0.02, 18.35), 180.0, 0.7)
	# ---------------- the wine cellar: low brick arches on three piers, racks on three walls, casks, puddles
	var spring: float = cy + 1.55
	var crown: float = top - 0.05
	for p: Vector2 in OC_PIERS:
		_arch(g, Vector3(p.x, spring, 8.15), Vector3(p.x, spring, p.y - 0.35), crown - spring)
		_arch(g, Vector3(p.x, spring, p.y + 0.35), Vector3(p.x, spring, 18.35), crown - spring)
		Props.block(g, Vector3(p.x - 0.43, cy, p.y - 0.43), Vector3(p.x + 0.43, cy + 0.38, p.y + 0.43), "cellar_stone")
		Props.block(g, Vector3(p.x - 0.45, spring - 0.28, p.y - 0.45), Vector3(p.x + 0.45, spring, p.y + 0.45), "cellar_stone")
		Props.cyl(g, Vector3(p.x + 0.38, spring + 0.04, p.y - 0.2), 0.03, 0.08, "candle")   # a stub on the capital
	for seg: Array in [[0.15, OC_PIERS[0].x - 0.35], [OC_PIERS[0].x + 0.35, OC_PIERS[1].x - 0.35], [OC_PIERS[1].x + 0.35, OC_PIERS[2].x - 0.35],
			[OC_PIERS[2].x + 0.35, 10.75]]:
		_arch(g, Vector3(float(seg[0]), spring, 13.2), Vector3(float(seg[1]), spring, 13.2), crown - spring, 6)
	Props.block(g, Vector3(0.15, top - 0.03, 8.15), Vector3(10.75, top, 18.35), "brick_cellar")   # a brick soffit
	_wine_rack(g, Vector3(1.375, cy, 8.15), 180.0, 2.4, 6, 51)
	_wine_rack(g, Vector3(6.65, cy, 8.15), 180.0, 3.6, 6, 52)
	_wine_rack(g, Vector3(6.3, cy, 18.35), 0.0, 6.5, 6, 53)
	_wine_rack(g, Vector3(0.15, cy, 10.6), -90.0, 3.1, 6, 54)
	_wine_rack(g, Vector3(0.15, cy, 13.95), -90.0, 2.8, 6, 55)
	for i: int in 3:   # the big casks on their cradles, heads to the room (T-247: the chalked vintages are gone)
		var cz: float = 14.6 + i * 1.3
		for sz: float in [-0.35, 0.35]:
			Props.block(g, Vector3(9.9, cy, cz + sz - 0.06), Vector3(10.72, cy + 0.32, cz + sz + 0.06), "beam")
		_lib_barrel(Vector3(10.3, cy + 0.12, cz), 90.0, 0.55, 0.82, true)
		Props.cyl(g, Vector3(9.84, cy + 0.32, cz), 0.03, 0.08, "brass", Vector3(0, 0, 90))   # the tap
	_lib_barrel(Vector3(9.6, cy, 17.85), 20.0, 0.25, 0.6)
	_lib_barrel(Vector3(0.55, cy, 17.9), -10.0, 0.25, 0.6)
	# (T-238: the crate that stood in the corner in front of two racks is gone)
	# (T-247: the cellar book chalked on the wall is gone)
	Props.puddle(g, Vector3(6.9, cy, 15.3), 1.2, 0.8, 15.0)
	Props.puddle(g, Vector3(1.7, cy, 11.4), 0.9, 0.7, -20.0)
	for c: Array in [[Vector3(0.15, top - 0.02, 8.15), 0.0], [Vector3(10.75, top - 0.02, 18.35), 180.0], [Vector3(0.15, top - 0.02, 18.35), 90.0]]:
		Props.cobweb(g, c[0], float(c[1]), 0.8)
	# ---------------- the coal room: the chute heap under the window, soot, the cage, the patrol's leftovers
	Props.ball(g, Vector3(3.55, cy, 0.95), Vector3(2.3, 0.75, 1.5), "coal")
	for i2: int in 12:
		Props.ball(g, Vector3(2.6 + rng.randf_range(0, 2.0), cy + 0.04, 1.6 + rng.randf_range(0, 1.3)), Vector3(0.15, 0.1, 0.13) * rng.randf_range(0.7, 1.4), "coal")
	Props.obox(g, Vector3(3.45, wy + OC_SILL - 0.63, 0.58), Vector3(1.3, 0.04, 1.55), "iron", Vector3(56, 0, 0))   # the chute plate
	Props.block(g, Vector3(0.15, cy + 0.6, 0.15), Vector3(4.85, top, 0.17), "char")   # soot up the chute wall
	Props.block(g, Vector3(4.83, cy, 0.15), Vector3(4.85, cy + 2.2, 3.2), "char")
	# the cage: round bars floor to ceiling on the three open sides, bands, corner posts (the door is HoldingCage)
	var cg: Rect2 = OC_CAGE
	var bars: Array = [[Vector2(cg.position.x + 0.05, cg.position.y), Vector2(cg.end.x, cg.position.y)],
		[Vector2(cg.position.x + 0.05, cg.end.y), Vector2(cg.end.x, cg.end.y)],
		[Vector2(cg.end.x, cg.position.y), Vector2(cg.end.x, OC_CAGE_DOOR.x)], [Vector2(cg.end.x, OC_CAGE_DOOR.y), Vector2(cg.end.x, cg.end.y)]]
	for b: Array in bars:
		var a2: Vector2 = b[0]
		var b2: Vector2 = b[1]
		var n: int = maxi(1, int(a2.distance_to(b2) / 0.13))
		for k: int in n + 1:
			var q: Vector2 = a2.lerp(b2, float(k) / float(n))
			Props.cyl(g, Vector3(q.x, (cy + top) * 0.5, q.y), 0.022, top - cy, "iron")
		for by: float in [cy + 0.12, cy + 1.05, top - 0.12]:
			Props.strut(g, Vector3(a2.x, by, a2.y), Vector3(b2.x, by, b2.y), 0.05, "iron")
	for cp: Vector2 in [Vector2(cg.end.x, cg.position.y), Vector2(cg.end.x, cg.end.y), Vector2(cg.end.x, OC_CAGE_DOOR.x), Vector2(cg.end.x, OC_CAGE_DOOR.y)]:
		Props.block(g, Vector3(cp.x - 0.04, cy, cp.y - 0.04), Vector3(cp.x + 0.04, top, cp.y + 0.04), "iron")
	# inside: straw, a folded blanket, a tin cup and a bucket, a miner's greeting and a tally chalked on the wall
	Hay.pad(g, Vector3(1.0, cy + 0.015, 5.3), Vector3(1.3, 0.03, 1.6), "straw_floor", Vector3(0, 8, 0))
	Props.block(g, Vector3(0.3, cy, 5.6), Vector3(0.95, cy + 0.12, 6.3), "tarp")
	Props.cyl(g, Vector3(1.9, cy + 0.05, 6.1), 0.045, 0.1, "tin")
	Props.cyl(g, Vector3(0.45, cy + 0.17, 3.7), 0.15, 0.34, "iron")
	Props.stencil(g, Vector3(0.16, cy + 1.45, 4.6), -90.0, "SZCZESC BOZE", 30, Color(0.92, 0.92, 0.88, 0.6), 0.0035, SurfaceText.CHALK)   # Jakub's cage: kept (story)
	Props.stencil(g, Vector3(0.16, cy + 1.1, 5.9), -90.0, "| |", 34, Color(0.92, 0.92, 0.88, 0.55), 0.0035, SurfaceText.CHALK)
	# outside: the guard's stool and crate with a mess tin and his cigarettes, the tag on the padlock, the lantern
	# (T-238: against the east wall under his lamp, facing the cage. The stool stood in the middle of the walk and
	# the crate half a metre inside the wine cellar's doorway, both without colliders)
	_lib("stool_workshop", Vector3(4.5, cy, 4.75), 80.0, Vector3.ONE, false)
	Props.crate(g, Vector3(4.5, cy, 3.8), 0.55, -84.0)
	Props.cyl(g, Vector3(4.45, cy + 0.6, 3.75), 0.09, 0.05, "steel")
	Props.block(g, Vector3(4.5, cy + 0.55, 3.92), Vector3(4.6, cy + 0.57, 3.99), "paper")
	Props.stencil(g, Vector3(2.62, cy + 0.82, 5.45), -90.0, "Häftling (Pole)\nFlucht aus K.\n22.XII.", 20, Color(0.22, 0.2, 0.18, 0.9), 0.0028, SurfaceText.PRINT)   # the tag on his cage: kept (story)
	Props.block(g, Vector3(2.61, cy + 0.68, 5.32), Vector3(2.615, cy + 0.94, 5.6), "paper")
	Props.lantern(g, Vector3(3.9, cy + 2.25, 3.9), top)
	Props.cobweb(g, Vector3(0.15, top - 0.02, 0.15), 0.0, 0.8)
	Props.cobweb(g, Vector3(4.85, top - 0.02, 7.85), 180.0, 0.6)
	# ---------------- the root cellar: preserves and the top shelf, sacks and potatoes, hams and onions overhead
	Props.shelves(g, Vector3(7.95, cy, 0.15), 180.0, 5.1, 2.1, 0.4, 4, 61)
	Props.shelves(g, Vector3(5.15, cy, 2.65), -90.0, 3.7, 1.9, 0.35, 3, 62)
	Props.block(g, Vector3(5.5, cy + 2.45, 0.15), Vector3(7.2, cy + 2.48, 0.42), "furniture")   # the top shelf
	for bk: float in [5.55, 7.15]:
		Props.block(g, Vector3(bk - 0.02, cy + 2.3, 0.15), Vector3(bk + 0.02, cy + 2.45, 0.4), "iron")
	for j: int in 3:   # the cousins' jam jars (v3 section 4.1: the youngest was always stretching for them)
		var jx: float = 5.85 + j * 0.42
		Props.cyl(g, Vector3(jx, cy + 2.6, 0.29), 0.07, 0.22, "jar_red")
		Props.cyl(g, Vector3(jx, cy + 2.72, 0.29), 0.085, 0.02, ["cloth_red", "linen", "cloth_green"][j])
		Props.block(g, Vector3(jx - 0.05, cy + 2.55, 0.215), Vector3(jx + 0.05, cy + 2.63, 0.22), "paper")
	Props.crate(g, Vector3(6.4, cy, 0.95), 0.45, 4.0)   # ...and the crate to stand on
	for sk: Array in [[Vector3(5.6, cy, 4.55), 10.0], [Vector3(6.2, cy, 4.6), -20.0], [Vector3(6.8, cy, 4.5), 35.0], [Vector3(7.45, cy, 4.6), 0.0],
			[Vector3(5.9, cy + 0.5, 4.6), 70.0], [Vector3(7.0, cy + 0.5, 4.55), -40.0]]:
		Props.sack(g, sk[0], float(sk[1]), 0.95)
	for i3: int in 10:
		Props.ball(g, Vector3(6.3 + rng.randf_range(-0.8, 1.4), cy + 0.05, 4.05 + rng.randf_range(-0.3, 0.1)), Vector3(0.09, 0.07, 0.08), "dirt")
	Props.cyl(g, Vector3(8.2, top - 0.15, 2.4), 0.035, 4.6, "beam", Vector3(0, 0, 90))   # the meat pole
	for hx: float in [6.3, 7.0, 7.9, 8.8, 9.6]:
		Props._noshadow(Props.block(g, Vector3(hx - 0.006, cy + 2.15, 2.394), Vector3(hx + 0.006, top - 0.15, 2.406), "rope"))
		Props.ball(g, Vector3(hx, cy + 1.95, 2.4), Vector3(0.24, 0.44, 0.2), "wood_red")
		Props.ball(g, Vector3(hx, cy + 2.15, 2.4), Vector3(0.1, 0.1, 0.1), "linen")
	for oz: float in [5.3, 5.6]:   # onion strings on the east wall
		for oy: int in 6:
			Props.ball(g, Vector3(10.66, cy + 1.2 + oy * 0.1, oz), Vector3(0.08, 0.07, 0.08), "paper_old")
	Props.cobweb(g, Vector3(10.75, top - 0.02, 0.15), 270.0, 0.8)
	Props.puddle(g, Vector3(9.5, cy, 3.3), 0.7, 0.5, 10.0)
	# ---------------- the ice cellar: three straw pallets, the upturned crate with the letter and the lantern burnt
	# dry, a jam jar, red-grey mittens, the ladder to the trapdoor, three chalk girls holding hands and the aunt
	for px: float in [5.6, 6.32, 7.04]:
		Props.block(g, Vector3(px - 0.32, cy, 6.2), Vector3(px + 0.32, cy + 0.1, 7.8), "hay")
		Props.block(g, Vector3(px - 0.3, cy + 0.1, 6.9), Vector3(px + 0.3, cy + 0.14, 7.75), "linen")
	Props.block(g, Vector3(5.42, cy + 0.14, 6.95), Vector3(5.55, cy + 0.17, 7.15), "cloth_red")   # the mittens
	Props.block(g, Vector3(5.58, cy + 0.14, 7.0), Vector3(5.71, cy + 0.17, 7.2), "tarp")
	var ic: Node3D = Props.group(g, "UpturnedCrate", Vector3(7.75, cy, 7.4), 6.0)
	Props.block(ic, Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.4, 0.3), "planks")
	Props.block(g, Vector3(7.5, cy + 0.4, 7.25), Vector3(7.68, cy + 0.405, 7.5), "paper")   # the letter
	Props.block(g, Vector3(7.82, cy + 0.4, 7.25), Vector3(7.98, cy + 0.42, 7.41), "iron")   # the lantern, burnt dry
	Props.block(g, Vector3(7.84, cy + 0.42, 7.27), Vector3(7.96, cy + 0.6, 7.39), "char")
	Props.cyl(g, Vector3(7.95, cy + 0.47, 7.6), 0.05, 0.12, "jar_red")
	Props.ladder(g, Vector3(6.6, cy, 5.15), 180.0, top - cy, "beam")
	var hz: Vector3 = Vector3(6.6, top - 0.005, 5.6)
	for e: Array in [[Vector3(-0.5, -0.06, -0.5), Vector3(0.5, 0, -0.42)], [Vector3(-0.5, -0.06, 0.42), Vector3(0.5, 0, 0.5)],
			[Vector3(-0.5, -0.06, -0.42), Vector3(-0.42, 0, 0.42)], [Vector3(0.42, -0.06, -0.42), Vector3(0.5, 0, 0.42)]]:
		Props.block(g, hz + (e[0] as Vector3), hz + (e[1] as Vector3), "beam")
	for k2: int in 3:
		_chalk_figure(g, Vector3(8.14, cy + 0.8, 6.0 + k2 * 0.3), 90.0, 0.5)
	_chalk_figure(g, Vector3(8.14, cy + 0.75, 7.6), 90.0, 0.75)
	# (T-247: EIS over the ice room is gone)
	Props.puddle(g, Vector3(6.4, cy, 5.9), 0.6, 0.45, 0.0)
	Props.cobweb(g, Vector3(8.15, top - 0.02, 7.85), 180.0, 0.6)
	# ---------------- the barrel vault: joists and summer beams, the pillars, the barrel stack, racks, the breach
	for x: float in [11.6, 12.8, 14.0, 15.2, 16.4, 17.6, 18.8, 20.0, 21.2, 22.4, 23.6]:
		Props.block(g, Vector3(x - 0.07, top - 0.17, 0.15), Vector3(x + 0.07, top, 15.85), "beam")
	for bz: float in [2.7, 13.3]:
		Props.block(g, Vector3(11.05, top - 0.36, bz - 0.17), Vector3(23.85, top - 0.17, bz + 0.17), "beam")
	for x2: float in [1.2, 2.4, 3.6, 4.8, 6.0, 7.2, 8.4, 9.6]:   # the root and coal rooms' joists too
		Props.block(g, Vector3(x2 - 0.06, top - 0.14, 0.15), Vector3(x2 + 0.06, top, 4.85 if x2 > 5.0 and x2 < 8.3 else 7.85), "beam")
	for p3: Vector2 in OC_PILLARS:
		Props.block(g, Vector3(p3.x - 0.44, cy, p3.y - 0.44), Vector3(p3.x + 0.44, cy + 0.4, p3.y + 0.44), "cellar_stone")
		Props.block(g, Vector3(p3.x - 0.42, top - 0.5, p3.y - 0.42), Vector3(p3.x + 0.42, top - 0.36, p3.y + 0.42), "cellar_stone")
	var st: Rect2 = OC_STACK
	var sx: float = st.get_center().x
	for row: Array in [[0.0, [6.95, 8.0, 9.05], 0.52], [0.93, [7.47, 8.52], 0.52], [1.72, [8.0], 0.48]]:   # [lift, z centres, r]
		for zc: float in row[1]:
			for side: float in [-0.78, 0.78]:
				_lib_barrel(Vector3(sx + side, cy + float(row[0]), zc), 90.0, float(row[2]), 1.45, true)
	for cz2: float in [6.5, 9.5]:   # the cradles
		Props.block(g, Vector3(st.position.x + 0.1, cy, cz2 - 0.08), Vector3(st.end.x - 0.1, cy + 0.2, cz2 + 0.08), "beam")
	# (T-247: the barrel stack's house-wine stencils are gone)
	# (T-238: the three kegs that stood loose at the stack's corners, on the training loop's turns, are gone)
	Props.lantern(g, Vector3(13.4, cy + 2.35, 8.0), top - 0.17)
	Props.lantern(g, Vector3(21.6, cy + 2.35, 8.0), top - 0.17)
	for bp: Vector3 in OC_BULBS:
		Props.pendant(g, bp, top - 0.02, _old_cellar_lit, "tin")
	Props.bake(_old_cellar_lit)
	for lit: Node in _old_cellar_lit.get_children():
		lit.set_meta("keep", true)
	_wine_rack(g, Vector3(23.85, cy, 7.0), 90.0, 5.2, 6, 56)
	_wine_rack(g, Vector3(17.45, cy, 15.85), 0.0, 3.7, 6, 57)
	Props.block(g, Vector3(11.05, cy + 0.5, 0.15), Vector3(13.15, top, 0.17), "char")   # the hearth footing's soot
	# (T-247: KAMIN on the hearth footing is gone)
	Props.puddle(g, Vector3(20.6, cy, 4.4), 1.0, 0.7, 25.0)
	# (T-238: the puddles left are the ones under a drip)
	for c2: Array in [[Vector3(23.85, top - 0.02, 15.85), 180.0], [Vector3(11.05, top - 0.02, 15.85), 90.0], [Vector3(23.85, top - 0.02, 0.15), 270.0]]:
		Props.cobweb(g, c2[0], float(c2[1]), 0.9)
	# the breach the installers knocked through: rubble at the jambs, two pit props, the cable run, a chalk arrow
	for rb: Vector3 in [Vector3(21.25, cy, 16.3), Vector3(23.6, cy, 16.4), Vector3(23.7, cy, 18.9), Vector3(21.2, cy, 20.9)]:
		Props.ball(g, rb, Vector3(0.7, 0.35, 0.6), "brick_cellar")
	Props.pit_prop(g, Vector3(22.45, cy, 16.15), 0.0, 2.9, top - cy, "pine")
	Props.pit_prop(g, Vector3(22.43, cy, 18.2), 0.0, 2.85, top - cy, "pine")
	Props.cable(g, Vector3(23.8, top - 0.1, 20.3), Vector3(21.1, top - 0.1, 18.0), 0.08, 0.02, 8)
	Props.cable(g, Vector3(21.1, top - 0.1, 18.0), Vector3(21.1, top - 0.1, 15.0), 0.08, 0.02, 6)
	Props.stencil(g, Vector3(20.86 + 0.16, cy + 1.5, 18.6), -90.0, "→ KELLER II", 24, Color(0.9, 0.9, 0.86, 0.5), 0.0032, SurfaceText.CHALK)   # T-247: chalked, small: the way to the machines
	Props.bulkhead_lamp(g, Vector3(23.83, cy + 2.1, 18.3), 90.0)
	# ---------------- the windows: timber frames in the openings, snow blown in under them, the light wells
	for wf: Array in [[Vector3(3.45, wy, 0.0), 0.0], [Vector3(24.0, wy, 1.8), -90.0]]:
		var fg: Node3D = Props.group(g, "WellWindow", wf[0], float(wf[1]))   # local +Z = into the room
		for side: float in [-1.0, 1.0]:
			Props.block(fg, Vector3(side * 0.8 - 0.07, OC_SILL - 0.03, -0.17), Vector3(side * 0.8 + 0.07, OC_WIN_H + 0.06, 0.17), "beam")
		Props.block(fg, Vector3(-0.87, OC_WIN_H, -0.17), Vector3(0.87, OC_WIN_H + 0.09, 0.17), "beam")
		Props.block(fg, Vector3(-0.87, OC_SILL - 0.05, -0.2), Vector3(0.87, OC_SILL, 0.22), "beam")
		Props.block(fg, Vector3(-0.75, OC_SILL, -0.6), Vector3(0.75, OC_SILL + 0.06, -0.17), "snow")
		Props.ball(fg, Vector3(0.1, cy - wy, 0.75), Vector3(1.2, 0.12, 0.8), "snow")   # blown in, on the room floor
	for ws: Array in [[2.0, 4.9, -2.15, -4.65], [24.15, 26.2, 0.4, -2.1]]:   # stone steps up out of each well
		var steps: int = int(ceil(-wy / 0.2))
		for k4: int in steps:
			var za: float = lerpf(float(ws[2]), float(ws[3]), float(k4) / float(steps))
			var zb: float = lerpf(float(ws[2]), float(ws[3]), float(k4 + 1) / float(steps))
			var yb: float = lerpf(wy, 0.0, float(k4 + 1) / float(steps))
			Props.block(g, Vector3(float(ws[0]), wy - 0.3, minf(za, zb)), Vector3(float(ws[1]), yb - 0.04, maxf(za, zb)), "stone")
			Props.block(g, Vector3(float(ws[0]) + 0.1, yb - 0.04, minf(za, zb)), Vector3(float(ws[1]) - 0.1, yb, maxf(za, zb)), "snow_trodden", false)
	for curb: Array in [[Vector3(1.8, 0, -4.65), Vector3(2.0, 0.18, -0.15)], [Vector3(4.9, 0, -4.65), Vector3(5.1, 0.18, -0.15)],
			[Vector3(26.2, 0, -2.1), Vector3(26.4, 0.18, 3.4)], [Vector3(24.0, 0, 3.2), Vector3(26.4, 0.18, 3.4)]]:
		Props.block(g, curb[0], curb[1], "cellar_stone")
	Props.snow_drift(g, Vector3(3.45, wy, -1.9), Vector3(2.6, 0.35, 0.6))
	Props.snow_drift(g, Vector3(25.9, wy, 2.6), Vector3(0.6, 0.35, 1.6))


## The Crucible's alcove (the Crucible itself is a gameplay node, build_deep_cellar_gameplay): brick facing between two
## iron columns under a riveted lintel, a soot halo on the soffit, a grate and a faint Nachtglas ring where you stand
## to feed it, and the conduit from the fuse box. `cx` is the Crucible's x, `zf` the face of the wall behind it (the
## room is on +z). T-251: it is on the Dynamo Room's north wall now, built to the measure it had in the vault, and its
## flue runs along the soffit to the generator's exhaust instead of up through the roof (the chimney stack in the
## snow north of the stable is the wash copper's, as it was before the installers came: _wash_copper).
func _crucible_setting(g: Node3D, cx: float, zf: float) -> void:
	var cy: float = CELLAR_Y
	Props.block(g, Vector3(cx - 1.25, cy, zf), Vector3(cx + 1.25, cy + 2.85, zf + 0.05), "brick_cellar")
	for sx: float in [-1.0, 1.0]:
		Props.block(g, Vector3(cx + sx * 1.35 - 0.11, cy, zf), Vector3(cx + sx * 1.35 + 0.11, cy + 2.9, zf + 0.27), "iron")
		Props.block(g, Vector3(cx + sx * 1.35 - 0.16, cy, zf), Vector3(cx + sx * 1.35 + 0.16, cy + 0.2, zf + 0.32), "iron")
		Props.block(g, Vector3(cx + sx * 1.35 - 0.16, cy + 2.7, zf), Vector3(cx + sx * 1.35 + 0.16, cy + 2.9, zf + 0.32), "iron")
	Props.block(g, Vector3(cx - 1.55, cy + 2.72, zf), Vector3(cx + 1.55, cy + 2.98, zf + 0.35), "iron")
	for i: int in 7:
		Props._noshadow(Props.ball(g, Vector3(cx - 1.2 + i * 0.4, cy + 2.85, zf + 0.35), Vector3(0.05, 0.05, 0.04), "steel"))
	Props._noshadow(Props.cyl(g, Vector3(cx, CELLAR_TOP - 0.008, zf + 0.6), 0.75, 0.01, "char"))
	Props._noshadow(Props.cyl(g, Vector3(cx, cy + 0.006, zf + 2.2), 0.85, 0.012, "steel_grate"))
	Props._noshadow(Props.cyl(g, Vector3(cx, cy + 0.01, zf + 2.2), 0.62, 0.012, "nachtglas_dim"))
	Props.pipe(g, Vector3(cx + 1.45, cy + 2.1, zf + 0.1), Vector3(cx + 1.0, cy + 2.1, zf + 0.1), 0.02)
	Props.pipe(g, Vector3(cx + 1.0, cy + 2.1, zf + 0.1), Vector3(cx + 1.0, cy + 1.3, zf + 0.1), 0.02)


## T-251: the vault's alcove on its north wall, where the Crucible stood until the installers moved it two rooms down:
## the inn's wash copper is back under its flue. A brick-set boiler (the collider is build_cellar's CellarCopperCol):
## the brick body with its iron fire door and ash pit, the copper's rim and its wooden lid, the stovepipe up the wall
## into the old flue (its chimney stack still stands in the snow above, with its cap of snow), soot on the soffit, the
## brick facing the installers left, a coal scuttle, the wash paddle against the wall, a zinc tub and the washboard.
func _wash_copper(g: Node3D) -> void:
	var cy: float = CELLAR_Y
	var cx: float = 29.5
	var zf: float = 19.15
	Props.block(g, Vector3(cx - 1.25, cy, zf), Vector3(cx + 1.25, cy + 2.85, zf + 0.05), "brick_cellar")   # the facing
	# the brick body, a course proud at its foot and its top
	Props.block(g, Vector3(cx - 0.8, cy, zf + 0.05), Vector3(cx + 0.8, cy + 0.92, zf + 1.05), "brick_cellar")
	Props.block(g, Vector3(cx - 0.84, cy, zf + 0.05), Vector3(cx + 0.84, cy + 0.1, zf + 1.09), "cellar_stone")
	Props.block(g, Vector3(cx - 0.84, cy + 0.92, zf + 0.05), Vector3(cx + 0.84, cy + 1.0, zf + 1.09), "cellar_stone")
	# the copper: its rim standing out of the top course, the lid of boards with a batten handle
	Props.cyl(g, Vector3(cx - 0.15, cy + 1.03, zf + 0.55), 0.4, 0.07, "copper")
	Props.cyl(g, Vector3(cx - 0.15, cy + 1.08, zf + 0.55), 0.37, 0.04, "planks")
	Props.block(g, Vector3(cx - 0.4, cy + 1.1, zf + 0.52), Vector3(cx + 0.1, cy + 1.14, zf + 0.58), "beam")
	# the fire door and the ash pit under it, on the front
	Props.block(g, Vector3(cx - 0.36, cy + 0.36, zf + 1.05), Vector3(cx + 0.06, cy + 0.68, zf + 1.08), "iron")
	Props.block(g, Vector3(cx - 0.11, cy + 0.5, zf + 1.08), Vector3(cx - 0.05, cy + 0.54, zf + 1.12), "brass")
	Props.block(g, Vector3(cx - 0.3, cy + 0.1, zf + 1.05), Vector3(cx + 0.0, cy + 0.24, zf + 1.075), "char")
	Props._noshadow(Props.block(g, Vector3(cx - 0.5, cy + 0.002, zf + 1.09), Vector3(cx + 0.25, cy + 0.01, zf + 1.6), "soot"))
	# the stovepipe: out of the body's back corner, up the facing, into the flue
	Props.cyl(g, Vector3(cx + 0.52, cy + 1.75, zf + 0.3), 0.09, 1.5, "iron")
	Props.cyl(g, Vector3(cx + 0.52, cy + 2.52, zf + 0.3), 0.105, 0.06, "iron")
	Props._noshadow(Props.cyl(g, Vector3(cx + 0.3, CELLAR_TOP - 0.008, zf + 0.6), 0.75, 0.01, "char"))
	# the chimney stack in the snow above (it was the Crucible's flue for a while)
	Props.block(g, Vector3(cx - 0.42, -0.25, zf + 0.18), Vector3(cx + 0.42, 1.15, zf + 1.02), "brick_cellar")
	Props.block(g, Vector3(cx - 0.48, 1.15, zf + 0.12), Vector3(cx + 0.48, 1.27, zf + 1.08), "cellar_stone")
	Props.block(g, Vector3(cx - 0.5, 1.27, zf + 0.1), Vector3(cx + 0.5, 1.34, zf + 1.1), "snow", false)
	# on the body: the zinc tub and the washboard leaning in it; beside it the scuttle and the paddle
	Props.cyl(g, Vector3(cx + 0.38, cy + 1.13, zf + 0.72), 0.26, 0.26, "zinc")
	Props.obox(g, Vector3(cx + 0.38, cy + 1.3, zf + 0.6), Vector3(0.3, 0.5, 0.03), "planks", Vector3(-18, 0, 0))
	Props.cyl(g, Vector3(cx - 1.02, cy + 0.17, zf + 0.3), 0.15, 0.34, "iron")
	Props.ball(g, Vector3(cx - 1.02, cy + 0.34, zf + 0.3), Vector3(0.26, 0.12, 0.26), "coal")
	Props.obox(g, Vector3(cx + 1.02, cy + 0.72, zf + 0.12), Vector3(0.05, 1.45, 0.03), "beam", Vector3(8, 0, 4))
	Props.obox(g, Vector3(cx + 1.04, cy + 1.42, zf + 0.2), Vector3(0.16, 0.2, 0.03), "beam", Vector3(8, 0, 4))


## T-251: the Lagering Vault's and the Dynamo Room's dressing (their shells and solid things are build_deep_cellar's).
## The Lagering Vault: the inn's own lager cellar, brick on every wall (a facing on the vault's and the Dynamo Room's
## sides), two stone ribs across it, three tuns on their cradles (each a tipped Props.barrel over the LagerTuns box)
## with a tap, a drip tray and the gutter to the floor drain, a rack of bungs and a mallet on the south wall, the
## installers' cable on the soffit from Door_Lager to Door_Dynamo. The Dynamo Room: whitewashed, the generator set
## on its plinth (engine, flywheel, belt, dynamo, the exhaust up to the soffit and out through the south wall), the
## Crucible's alcove and the fuse board by the lever on the north wall, the bench and the two crates in the north-east
## corner, two oil drums in the north-west one, the sump's grate in the south-west corner.
func _dress_deep_cellar(parent: Node3D) -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var t2: float = T * 0.5
	var cream: Color = Color(0.92, 0.9, 0.82, 0.8)
	var g: Node3D = Props.group(parent, "DeepCellar", Vector3.ZERO)
	_lager_lit = Node3D.new()
	_lager_lit.name = "LagerLit"
	dress.add_child(_lager_lit)
	_dynamo_lit = Node3D.new()
	_dynamo_lit.name = "DynamoLit"
	dress.add_child(_dynamo_lit)
	var spring: float = cy + 2.05
	var cl: float = top - 0.08
	# ================= the Lagering Vault
	var lx0: float = LAG_X0 + t2
	var lx1: float = LAG_X1 - t2
	var lz0: float = LAG_Z0 + t2
	var lz1: float = LAG_Z1 - t2
	# brick on the two walls it shares (the vault's stone south wall, the Dynamo Room's whitewashed west wall)
	Props.block(g, Vector3(lx0, cy, lz0), Vector3(LAG_DOOR.x - 0.14, top, lz0 + 0.02), "brick_cellar")
	Props.block(g, Vector3(LAG_DOOR.y + 0.14, cy, lz0), Vector3(lx1, top, lz0 + 0.02), "brick_cellar")
	Props.block(g, Vector3(LAG_DOOR.x - 0.14, cy + DOOR_H + 0.18, lz0), Vector3(LAG_DOOR.y + 0.14, top, lz0 + 0.02), "brick_cellar")
	Props.block(g, Vector3(lx1 - 0.02, cy, lz0), Vector3(lx1, top, DYN_DOOR.x - 0.14), "brick_cellar")
	Props.block(g, Vector3(lx1 - 0.02, cy, DYN_DOOR.y + 0.14), Vector3(lx1, top, lz1), "brick_cellar")
	Props.block(g, Vector3(lx1 - 0.02, cy + DOOR_H + 0.18, DYN_DOOR.x - 0.14), Vector3(lx1, top, DYN_DOOR.y + 0.14), "brick_cellar")
	_door_frame(Vector3((LAG_DOOR.x + LAG_DOOR.y) * 0.5, cy, LAG_Z0), 0.0, LAG_DOOR.y - LAG_DOOR.x, DOOR_H)
	_door_frame(Vector3(DYN_X0, cy, (DYN_DOOR.x + DYN_DOOR.y) * 0.5), 90.0, DYN_DOOR.y - DYN_DOOR.x, DOOR_H)
	# the rooms' names over their doors, small (the side you come from)
	Props.stencil(g, Vector3((LAG_DOOR.x + LAG_DOOR.y) * 0.5, cy + DOOR_H + 0.36, LAG_Z0 - t2), 0.0, "LAGERKELLER", 24, Color(cream, 0.55), 0.003)
	Props.stencil(g, Vector3(lx1 - 0.02, cy + DOOR_H + 0.36, (DYN_DOOR.x + DYN_DOOR.y) * 0.5), 90.0, "MASCHINENRAUM", 24, Color(cream, 0.55), 0.003)
	# the ribs (clear of the bulbs), the tuns
	for rx: float in [27.5, 32.55]:
		_arch(g, Vector3(rx, spring, lz0), Vector3(rx, spring, lz1), (top - 0.1) - spring)
	var tz: float = (LAG_TUN_Z.x + LAG_TUN_Z.y) * 0.5
	var ti: int = 0
	for tx: float in LAG_TUNS:
		for sz: float in [LAG_TUN_Z.x + 0.28, LAG_TUN_Z.y - 0.28]:   # the cradle: two sleepers with chocks
			Props.block(g, Vector3(tx - 0.56, cy, sz - 0.08), Vector3(tx + 0.56, cy + 0.2, sz + 0.08), "beam")
			for sx: float in [-1.0, 1.0]:
				Props.obox(g, Vector3(tx + sx * 0.4, cy + 0.27, sz), Vector3(0.24, 0.16, 0.14), "beam", Vector3(0, 0, sx * -32.0))
		Props.barrel(g, Vector3(tx, cy + 0.26, tz), 0.0, LAG_TUN_R, LAG_TUN_Z.y - LAG_TUN_Z.x - 0.06, true)
		# the tap low on the north head, its drip tray; a chalked gauge board on the head
		Props.cyl(g, Vector3(tx, cy + 0.5, LAG_TUN_Z.x - 0.03), 0.022, 0.12, "brass", Vector3(90, 0, 0))
		Props.block(g, Vector3(tx - 0.012, cy + 0.5, LAG_TUN_Z.x - 0.1), Vector3(tx + 0.012, cy + 0.6, LAG_TUN_Z.x - 0.07), "brass")
		Props.block(g, Vector3(tx - 0.16, cy, LAG_TUN_Z.x - 0.32), Vector3(tx + 0.16, cy + 0.07, LAG_TUN_Z.x - 0.04), "zinc")
		Props._noshadow(Props.block(g, Vector3(tx - 0.13, cy + 1.02, LAG_TUN_Z.x + 0.012), Vector3(tx + 0.13, cy + 1.2, LAG_TUN_Z.x + 0.02), "board_wood"))
		ti += 1
	# the gutter along the tuns' north side to the floor drain in the north-east corner (the ground spawn), a puddle
	Props._noshadow(Props.block(g, Vector3(float(LAG_TUNS[0]) - 0.5, cy + 0.002, LAG_TUN_Z.x - 0.5), Vector3(32.6, cy + 0.008, LAG_TUN_Z.x - 0.38), "char"))
	Props._noshadow(Props.block(g, Vector3(32.6, cy + 0.002, 32.4), Vector3(32.72, cy + 0.008, LAG_TUN_Z.x - 0.38), "char"))
	Props.block(g, Vector3(32.55, cy + 0.002, 31.75), Vector3(33.25, cy + 0.012, 32.45), "iron")
	for i: int in 4:
		Props.block(g, Vector3(32.62 + i * 0.16, cy + 0.012, 31.82), Vector3(32.68 + i * 0.16, cy + 0.016, 32.38), "char")
	Props.puddle(g, Vector3(31.6, cy, 32.5), 1.2, 0.7, 15.0)
	Props.puddle(g, Vector3(29.4, cy, 35.6), 0.9, 0.6, 70.0)
	# the south wall: a rack of bungs and taps, the cooper's mallet hung beside it; a hose on its hook
	Props.shelves(g, Vector3(30.0, cy + 1.0, lz1), 0.0, 1.8, 0.9, 0.22, 2, 251)
	Props.obox(g, Vector3(31.35, cy + 1.3, lz1 - 0.04), Vector3(0.05, 0.6, 0.05), "beam", Vector3(0, 0, 12))
	Props.obox(g, Vector3(31.42, cy + 1.6, lz1 - 0.05), Vector3(0.22, 0.14, 0.1), "beam", Vector3(0, 0, 12))
	Props.cyl(g, Vector3(28.2, cy + 1.45, lz1 - 0.06), 0.24, 0.07, "rubber", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(28.2, cy + 1.45, lz1 - 0.04), 0.035, 0.08, "iron", Vector3(90, 0, 0))
	# the installers' cable on the soffit: in over Door_Lager, across to the bulbs, out over Door_Dynamo
	Props.cable(g, Vector3(26.0, cl, lz0), Vector3((LAG_BULBS[0] as Vector3).x, cl, (LAG_BULBS[0] as Vector3).z), 0.04, 0.015, 5)
	Props.cable(g, Vector3((LAG_BULBS[0] as Vector3).x, cl, (LAG_BULBS[0] as Vector3).z), Vector3((LAG_BULBS[1] as Vector3).x, cl, (LAG_BULBS[1] as Vector3).z), 0.06, 0.015, 8)
	Props.cable(g, Vector3((LAG_BULBS[1] as Vector3).x, cl, (LAG_BULBS[1] as Vector3).z), Vector3((LAG_BULBS[2] as Vector3).x, cl, (LAG_BULBS[2] as Vector3).z), 0.06, 0.015, 8)
	Props.cable(g, Vector3((LAG_BULBS[2] as Vector3).x, cl, (LAG_BULBS[2] as Vector3).z), Vector3(lx1, cl, 35.4), 0.04, 0.015, 5)
	for bp: Vector3 in LAG_BULBS:
		Props.pendant(g, bp, top - 0.02, _lager_lit, "tin")
	for dl: Array in DEEP_LAMPS:   # lit by LagerLamp, LagerLamp2, DynamoLamp, DynamoLamp2 (build_deep_cellar_gameplay)
		Props.lantern(g, dl[1], top - 0.02)
	Props.pipe(g, Vector3(lx0 + 0.07, cy + 2.7, lz0 + 0.05), Vector3(lx0 + 0.07, cy + 2.7, lz1 - 0.05), 0.035, "iron")
	Props.cobweb(g, Vector3(lx0, top - 0.02, lz1), 90.0, 0.9)
	Props.cobweb(g, Vector3(lx1, top - 0.02, lz0), -90.0, 0.8)
	PropsStory.stain(g, Vector3(lx0 + 0.3, cy + 0.0125, lz0 + 0.1), Vector3(27.6, cy + 0.0135, 33.4), "floor_worn")
	# ================= the Dynamo Room
	var dx0: float = DYN_X0 + t2
	var dx1: float = DYN_X1 - t2
	var dz0: float = DYN_Z0 + t2
	var dz1: float = DYN_Z1 - t2
	Props.block(g, Vector3(dx0, cy, dz0), Vector3(36.0 + t2, top, dz0 + 0.02), "limewash")   # whitewash over the vault's stone
	_crucible_setting(g, DYN_CRUCIBLE.x, dz0)
	# the fuse board by the lever, its conduit to the lever and up to the soffit
	var fx: float = DYN_LEVER.x - 1.3
	Props.fuse_box(g, Vector3(fx, cy + 1.95, dz0), 180.0, 0.5, 0.7)
	Props.pipe(g, Vector3(fx, cy + 2.3, dz0 + 0.1), Vector3(fx, top - 0.08, dz0 + 0.1), 0.02)
	Props.pipe(g, Vector3(fx + 0.25, cy + 1.95, dz0 + 0.1), Vector3(DYN_LEVER.x, cy + 1.95, dz0 + 0.1), 0.02)
	Props.pipe(g, Vector3(DYN_LEVER.x, cy + 1.95, dz0 + 0.1), Vector3(DYN_LEVER.x, cy + 2.15, dz0 + 0.15), 0.02)
	# the bench and the two crates the machines' glass came in, in the north-east corner (as they stood in the vault)
	Props.workbench(g, Vector3(DYN_X1 - 0.85, cy, dz0 + 0.35), 180.0, 1.5, 0.7)
	Props.crate(g, Vector3(DYN_X1 - 2.04, cy, dz0 + 0.35), 0.6, 180.0)
	Props.crate(g, Vector3(DYN_X1 - 2.02, cy + 0.6, dz0 + 0.35), 0.5, 174.0)
	# the oil drums in the north-west corner, a funnel on one, the stain under them
	Props.oil_drum(g, Vector3(dx0 + 0.36, cy, dz0 + 0.36), "machine_grey")
	Props.oil_drum(g, Vector3(dx0 + 1.0, cy, dz0 + 0.34), "olive_drab")
	Props.cone(g, Vector3(dx0 + 1.0, cy + 0.98, dz0 + 0.34), 0.12, 0.16, "zinc", Vector3(180, 0, 0))
	PropsStory.stain(g, Vector3(dx0 + 0.05, cy + 0.0125, dz0 + 0.05), Vector3(dx0 + 1.7, cy + 0.0135, dz0 + 1.1), "water_stain")
	# ---- the generator set on its plinth: a two-cylinder engine, its flywheel, the belt to the dynamo, the exhaust
	var px0: float = DYN_SET.position.x
	var pz0: float = DYN_SET.position.y
	var pzm: float = pz0 + DYN_SET.size.y * 0.5
	Props.block(g, Vector3(px0, cy, pz0), Vector3(DYN_SET.end.x, cy + 0.22, DYN_SET.end.y), "concrete")
	Props.block(g, Vector3(px0 + 0.2, cy + 0.22, pz0 + 0.22), Vector3(px0 + 1.15, cy + 0.78, pz0 + 0.98), "machine_green")   # the crankcase
	for cxo: float in [0.42, 0.9]:
		Props.cyl(g, Vector3(px0 + cxo, cy + 1.05, pzm), 0.17, 0.55, "machine_green")
		Props.cyl(g, Vector3(px0 + cxo, cy + 1.35, pzm), 0.19, 0.07, "iron")
		for fin: int in 4:
			Props.cyl(g, Vector3(px0 + cxo, cy + 0.9 + fin * 0.1, pzm), 0.2, 0.02, "iron")
	Props.cyl(g, Vector3(px0 + 1.26, cy + 0.66, pzm), 0.4, 0.1, "iron", Vector3(0, 0, 90))   # the flywheel
	Props.cyl(g, Vector3(px0 + 1.26, cy + 0.66, pzm), 0.09, 0.2, "steel", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(px0 + 1.92, cy + 0.6, pzm), 0.3, 0.62, "machine_grey", Vector3(0, 0, 90))   # the dynamo
	Props.cyl(g, Vector3(px0 + 1.57, cy + 0.6, pzm), 0.2, 0.08, "copper", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(px0 + 2.27, cy + 0.6, pzm), 0.16, 0.08, "iron", Vector3(0, 0, 90))
	for fz: float in [pzm - 0.22, pzm + 0.22]:   # its feet
		Props.block(g, Vector3(px0 + 1.66, cy + 0.22, fz - 0.05), Vector3(px0 + 2.18, cy + 0.34, fz + 0.05), "iron")
	Props.block(g, Vector3(px0 + 1.74, cy + 0.9, pzm - 0.14), Vector3(px0 + 2.1, cy + 1.08, pzm + 0.14), "machine_grey")   # the terminal box
	Props.cable(g, Vector3(px0 + 1.92, cy + 1.08, pzm), Vector3(px0 + 1.92, cl, pzm - 0.6), 0.02, 0.02, 4)
	Props.cable(g, Vector3(px0 + 1.92, cl, pzm - 0.6), Vector3(fx, cl, dz0 + 0.12), 0.08, 0.02, 8)
	Props.block(g, Vector3(px0 + 1.2, cy + 0.22, pz0 + 0.08), Vector3(px0 + 1.62, cy + 1.12, pz0 + 0.12), "steel_grate")   # the belt guard, both sides
	Props.block(g, Vector3(px0 + 1.2, cy + 0.22, DYN_SET.end.y - 0.12), Vector3(px0 + 1.62, cy + 1.12, DYN_SET.end.y - 0.08), "steel_grate")
	Props.cyl(g, Vector3(px0 + 0.12, cy + 0.62, pzm), 0.2, 0.3, "machine_grey")   # the fuel tank on its bracket
	# the exhaust: up from the head, along the soffit, out through the south wall
	Props.pipe(g, Vector3(px0 + 0.66, cy + 1.3, pzm + 0.2), Vector3(px0 + 0.66, top - 0.16, pzm + 0.2), 0.05, "iron")
	Props.pipe(g, Vector3(px0 + 0.66, top - 0.16, pzm + 0.2), Vector3(px0 + 0.66, top - 0.16, dz1), 0.05, "iron")
	Props.cyl(g, Vector3(px0 + 0.66, top - 0.16, dz1 - 0.03), 0.09, 0.05, "iron", Vector3(90, 0, 0))
	PropsStory.stain(g, Vector3(px0 - 0.5, cy + 0.0125, pz0 - 0.4), Vector3(px0 + 1.4, cy + 0.0135, DYN_SET.end.y + 0.5), "water_stain")
	# the sump in the south-west corner (the ground spawn): its grate, the wet round it
	Props.block(g, Vector3(34.75, cy + 0.002, 37.45), Vector3(35.65, cy + 0.014, 38.35), "iron")
	for i2: int in 5:
		Props.block(g, Vector3(34.83 + i2 * 0.17, cy + 0.014, 37.52), Vector3(34.89 + i2 * 0.17, cy + 0.018, 38.28), "char")
	Props.puddle(g, Vector3(36.3, cy, 38.0), 1.1, 0.7, 10.0)
	# the east wall: a tool board, a fire bucket on its hook; pipes along the walls' tops
	Props.block(g, Vector3(dx1 - 0.03, cy + 1.1, 33.4), Vector3(dx1, cy + 1.9, 34.6), "board_wood")
	for tk: int in 4:
		Props.obox(g, Vector3(dx1 - 0.045, cy + 1.5, 33.6 + tk * 0.27), Vector3(0.02, 0.44 + (tk % 2) * 0.14, 0.05), "iron", Vector3(float(tk * 7 - 10), 0, 0))
	Props.cyl(g, Vector3(dx1 - 0.16, cy + 1.2, 35.2), 0.13, 0.26, "red_paint")
	Props.block(g, Vector3(dx1 - 0.03, cy + 1.36, 35.17), Vector3(dx1, cy + 1.42, 35.23), "iron")
	Props.pipe(g, Vector3(dx0 + 0.05, cy + 2.7, dz1 - 0.07), Vector3(px0 + 0.5, cy + 2.7, dz1 - 0.07), 0.03, "iron")
	Props.cable(g, Vector3(dx0, cl, 35.4), Vector3((DYN_BULBS[0] as Vector3).x, cl, (DYN_BULBS[0] as Vector3).z), 0.04, 0.015, 5)
	Props.cable(g, Vector3((DYN_BULBS[0] as Vector3).x, cl, (DYN_BULBS[0] as Vector3).z), Vector3((DYN_BULBS[2] as Vector3).x, cl, (DYN_BULBS[2] as Vector3).z), 0.06, 0.015, 8)
	Props.cable(g, Vector3((DYN_BULBS[2] as Vector3).x, cl, (DYN_BULBS[2] as Vector3).z), Vector3((DYN_BULBS[1] as Vector3).x, cl, (DYN_BULBS[1] as Vector3).z), 0.06, 0.015, 8)
	Props.cable(g, Vector3((DYN_BULBS[1] as Vector3).x, cl, (DYN_BULBS[1] as Vector3).z), Vector3(fx, cl, dz0 + 0.12), 0.05, 0.015, 6)
	for bp2: Vector3 in DYN_BULBS:
		Props.pendant(g, bp2, top - 0.02, _dynamo_lit, "tin")
	Props.cobweb(g, Vector3(dx1, top - 0.02, dz1), 180.0, 0.9)
	Props.cobweb(g, Vector3(dx0, top - 0.02, dz1), 90.0, 0.7)
	for holder: Node3D in [_lager_lit, _dynamo_lit]:
		Props.bake(holder)
		for lit: Node in holder.get_children():
			lit.set_meta("keep", true)


## A segmental stone arch from a to b (same height), rising `rise` at the crown, as a run of boxes.
func _arch(parent: Node3D, a: Vector3, b: Vector3, rise: float, segs: int = 8, w: float = 0.42, d: float = 0.3) -> void:
	var prev: Vector3 = a
	var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	for i: int in segs:
		var t: float = float(i + 1) / float(segs)
		var p: Vector3 = a.lerp(b, t) + Vector3(0, rise * sin(t * PI), 0)
		var mid: Vector3 = (prev + p) * 0.5
		var seg_len: float = prev.distance_to(p)
		if along_x:
			var ang: float = rad_to_deg(atan2(p.y - prev.y, p.x - prev.x))
			Props.obox(parent, mid, Vector3(seg_len + 0.04, d, w), "cellar_stone", Vector3(0, 0, ang))
		else:
			var ang2: float = rad_to_deg(atan2(p.y - prev.y, p.z - prev.z))
			Props.obox(parent, mid, Vector3(w, d, seg_len + 0.04), "cellar_stone", Vector3(-ang2, 0, 0))
		prev = p
	# corbels at the springing
	for e: Vector3 in [a, b]:
		if along_x:
			var out: float = 1.0 if e.x < (a.x + b.x) * 0.5 else -1.0
			Props.block(parent, e + Vector3(-0.05 * out, -0.42, -w * 0.5 - 0.03), e + Vector3(0.3 * out, 0.0, w * 0.5 + 0.03), "cellar_stone")
		else:
			var out2: float = 1.0 if e.z < (a.z + b.z) * 0.5 else -1.0
			Props.block(parent, e + Vector3(-w * 0.5 - 0.03, -0.42, -0.05 * out2), e + Vector3(w * 0.5 + 0.03, 0.0, 0.3 * out2), "cellar_stone")


# ================================================================== the CC0 prop library (UPDATE_05 section 5, T-093)

## Library props (PropLibrary keys) placed by the dressing passes: [key, Transform3D, casts_shadow]. They are built at
## load time by a PropScatter node ("LibraryProps", one MultiMesh per prop mesh), never collide, and sit over the
## invisible colliders the geometry pass already made (tables, beds, the barrel stack...), so the navmesh never moves.
var _lib_props: Array = []


func _lib(key: String, pos: Vector3, yaw: float, sc: Vector3 = Vector3.ONE, shadow: bool = true, extra_deg: Vector3 = Vector3.ZERO) -> void:
	_lib_props.append([key, PropScatter.place(pos, yaw, sc, extra_deg), shadow])


## A table over its collider: square ones are the round library table, long ones the plank table along their long
## side; the top lands at exactly 0.75 m, where the story props are placed.
func _lib_table(c: Vector3, w: float, d: float) -> void:
	if absf(w - d) < 0.05:
		var s: float = w / 1.007
		_lib("table_round", c, 0.0, Vector3(s, 0.75 / 0.723, s))
		return
	var length: float = maxf(w, d)
	var depth: float = minf(w, d)
	_lib("table_rect", c, 90.0 if d > w else 0.0, Vector3(length / 1.134, 0.75 / 0.8, depth / 0.706))


## A chair where Props.chair stood (its back at local +Z; the library chair's is at -Z, hence the half turn).
## Chairs cast no shadows (ART_BIBLE section 5: nothing new below chair size casts from the omni lamps).
func _lib_chair(pos: Vector3, yaw: float, tipped: bool = false) -> void:
	if tipped:
		_lib("chair_farmhouse", pos + Vector3(0, 0.27, 0), yaw + 180.0, Vector3(0.85, 0.85, 0.85), false, Vector3(-80, 0, 0))
	else:
		_lib("chair_farmhouse", pos, yaw + 180.0, Vector3(0.85, 0.85, 0.85), false)


## A cask where Props.barrel stood (same radius, height, and the same centre when tipped onto its side).
func _lib_barrel(pos: Vector3, yaw: float, r: float, h: float, tipped: bool = false) -> void:
	var sc: Vector3 = Vector3(2.0 * r / 0.742, h / 0.871, 2.0 * r / 0.756)
	if not tipped:
		_lib("barrel_wine", pos, yaw, sc)
		return
	var b: Basis = Basis.from_euler(Vector3(PI * 0.5, deg_to_rad(yaw), 0.0))
	var xf: Transform3D = Transform3D(b, pos + Vector3(0, r, 0)) * Transform3D(Basis.from_scale(sc), Vector3(0, -h * 0.5, 0))
	_lib_props.append(["barrel_wine", xf, true])


## A guest-room bed: the iron frame from the library round Props.bed_soft's mattress and blanket (head at the
## collider's -Z end, like Props.bed).
func _lib_bed(a: Vector3, b: Vector3, blanket: String, parent: Node3D) -> void:
	Props.bed_soft(parent, a, b, blanket)
	var c: Vector3 = Vector3((a.x + b.x) * 0.5, a.y, (a.z + b.z) * 0.5)
	_lib("bed_iron", c, 0.0, Vector3(absf(b.x - a.x) / 0.905, 1.0, absf(b.z - a.z) / 2.0))


func _emit_library_props() -> void:
	var ps: PropScatter = PropScatter.new()
	ps.name = "LibraryProps"
	ps.items = _lib_props
	map_root.add_child(ps)
	print("library props: %d placed" % _lib_props.size())


func _dress_hearth() -> void:
	var g: Node3D = Props.group(dress, "Hearth", Vector3.ZERO)
	Props.block(g, Vector3(10.9, 0, 0.15), Vector3(11.4, 1.42, 0.95), "stone")      # left jamb
	Props.block(g, Vector3(12.6, 0, 0.15), Vector3(13.1, 1.42, 0.95), "stone")      # right jamb
	Props.block(g, Vector3(11.4, 1.0, 0.15), Vector3(12.6, 1.42, 0.95), "stone")    # lintel
	Props.block(g, Vector3(11.4, 0, 0.15), Vector3(12.6, 1.0, 0.3), "char")         # sooty back
	Props.block(g, Vector3(10.7, 0, 0.95), Vector3(13.3, 0.12, 1.5), "stone")       # hearthstone
	Props.block(g, Vector3(10.75, 1.42, 0.15), Vector3(13.25, 1.5, 1.08), "beam")    # mantel
	Props.block(g, Vector3(11.2, 1.5, 0.15), Vector3(12.8, TAP_H, 0.6), "stone")     # chimney breast
	Props.hearth_fire(g, Vector3(12.0, 0.02, 0.6))
	# mantel clutter (keep the note's spot at x 12.5 clear)
	Props.cyl(g, Vector3(11.1, 1.62, 0.6), 0.05, 0.24, "brass")
	Props.cyl(g, Vector3(11.4, 1.58, 0.55), 0.06, 0.16, "stein")
	Props.block(g, Vector3(13.0, 1.5, 0.3), Vector3(13.2, 1.75, 0.5), "furniture")   # clock
	Props.antlers(g, Vector3(12.0, 2.75, 0.62), 180.0)
	Props.block(g, Vector3(13.4, 0, 0.6), Vector3(14.0, 0.5, 1.2), "planks")          # log box
	for i: int in 4:
		Props.cyl(g, Vector3(13.7, 0.55 + i * 0.09, 0.9), 0.06, 0.55, "beam", Vector3(90, 0, 10.0 * i))
	# the fire irons (T-230: the owner saw "a random piece of wood" by the hearth: the old poker, a bare upright block on
	# the floor a step from the jamb): a stand on the hearthstone against the left jamb, the poker, tongs and brush
	# hanging from its ring, the bellows leant on the jamb
	var irons: Node3D = Props.group(g, "FireIrons", Vector3(10.52, 0.12, 1.22))
	Props.cyl(irons, Vector3(0, 0.01, 0), 0.13, 0.02, "iron")                        # the base
	Props.cyl(irons, Vector3(0, 0.4, 0), 0.012, 0.8, "iron")                         # the upright
	Props.cyl(irons, Vector3(0, 0.8, 0), 0.07, 0.02, "iron")                         # the ring the irons hang from
	Props.ball(irons, Vector3(0, 0.83, 0), Vector3(0.05, 0.05, 0.05), "brass")       # the knob
	for a: Array in [[0.0, 0.78], [120.0, 0.7], [240.0, 0.62]]:                      # poker, tongs, brush on their hooks
		var r: float = deg_to_rad(float(a[0]))
		var off: Vector3 = Vector3(sin(r), 0, cos(r)) * 0.075
		var h: float = a[1]
		Props.cyl(irons, off + Vector3(0, 0.79 - h * 0.5, 0), 0.007, h, "iron", Vector3(2.5 * cos(r), 0, 2.5 * sin(r)))
		Props.obox(irons, off + Vector3(0, 0.8, 0), Vector3(0.03, 0.012, 0.012), "iron", Vector3(0, float(a[0]), 0))   # the hook
	Props.obox(irons, Vector3(0.0, 0.03, 0.105), Vector3(0.012, 0.012, 0.07), "iron")                                   # the poker's bent tip
	Props.obox(irons, Vector3(0.075 * sin(deg_to_rad(240.0)), 0.21, 0.075 * cos(deg_to_rad(240.0))), Vector3(0.05, 0.08, 0.03), "hay")   # the brush's head
	Props.obox(g, Vector3(10.84, 0.4, 1.05), Vector3(0.16, 0.5, 0.05), "furniture", Vector3(-12, 0, 0))                 # the bellows, leant on the jamb
	Props.cyl(g, Vector3(10.84, 0.72, 0.985), 0.012, 0.16, "brass", Vector3(-12, 0, 0))                                 # its nozzle


## Glassware that breaks when shot (T-053): collected per set here, built as ShatterSets by build_reactive().
## [base position, ShatterSet kind, height scale]
var _glass: Dictionary = {}


func _glassware(set_name: String, base: Vector3, kind: String, h: float = 1.0) -> void:
	(_glass.get_or_add(set_name, []) as Array).append([base, kind, h])


## A shelf line of bottles and steins from a to b (both on the board's top), like Props.bottles but shootable.
func _bottle_row(set_name: String, a: Vector3, b: Vector3, count: int, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds: Array = ["bottle_green", "bottle_amber", "stein"]
	for i: int in count:
		var k: String = kinds[rng.randi() % kinds.size()]
		var t: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(count)
		var p: Vector3 = a.lerp(b, t) + Vector3(rng.randf_range(-0.06, 0.06), 0, 0)   # a little in and out on the board
		var h: float = rng.randf_range(0.83, 1.15) if k != "stein" else 1.0
		_glassware(set_name, p, k, h)


## The bar (T-224, the owner: "the bar area needs to look better and the bar needs to be bigger with more space"): a
## 10 m L of counter over its colliders (BAR_*), panelled with raised fields on a plinth, an oak top with a bullnose and a
## brass foot rail on brackets, eight stools; the service side has the lift-up flap at the north end on brass straps, two
## beer taps with porcelain handles over a zinc drip tray, the brass till by the flap and the bell; the back-bar (SHELF_*)
## is a cupboard base with five doors under three bays of open shelving against a mirror, a carved cornice over it and
## two brass lamps on the cornice; the cask on its cradle in the corner behind the counter's north end (BarCask); a
## chalked price board on the north wall. The bottles and steins break when shot (ShatterSet "Bar", T-053). The 1.45 m
## board keeps the gap under the wireless for Käthe's frequency notes on the back board (build_reactive).
func _dress_bar() -> void:
	var g: Node3D = Props.group(dress, "Bar", Vector3.ZERO)
	var x0: float = BAR_X0
	var x1: float = BAR_X1
	var z0: float = BAR_Z0
	var sx: float = BAR_X1 - 0.8   # the side counter's back (service) face
	var z1: float = BAR_Z1         # the counter's south end (the front's north face)
	# counter: panelled body on a plinth, raised fields, the overhanging top with its bullnose
	Props.block(g, Vector3(x0, 0, z1 + 0.05), Vector3(x1, 1.02, z1 + 0.8), "wainscot")
	Props.block(g, Vector3(sx + 0.05, 0, z0), Vector3(x1, 1.02, z1 + 0.05), "wainscot")
	Props.block(g, Vector3(x0, 0, z1 + 0.8), Vector3(x1 + 0.04, 0.1, z1 + 0.84), "beam")
	Props.block(g, Vector3(x1, 0, z0 - 0.02), Vector3(x1 + 0.04, 0.1, z1 + 0.84), "beam")
	var px: float = x0 + 0.25
	while px < x1 - 0.55:
		Props.block(g, Vector3(px, 0.22, z1 + 0.8), Vector3(px + 0.5, 0.86, z1 + 0.83), "furniture")
		px += 0.75
	var pz: float = z0 + 0.25
	while pz < z1 + 0.05 - 0.55:
		Props.block(g, Vector3(x1, 0.22, pz), Vector3(x1 + 0.03, 0.86, pz + 0.5), "furniture")
		pz += 0.75
	Props.block(g, Vector3(x0 - 0.05, 1.02, z1 - 0.05), Vector3(x1 + 0.12, 1.1, z1 + 0.92), "furniture")
	Props.block(g, Vector3(sx - 0.05, 1.02, z0 - 0.12), Vector3(x1 + 0.12, 1.1, z1), "furniture")
	Props.block(g, Vector3(x0 - 0.06, 1.0, z1 + 0.9), Vector3(x1 + 0.14, 1.1, z1 + 0.94), "beam")
	Props.block(g, Vector3(x1 + 0.1, 1.0, z0 - 0.13), Vector3(x1 + 0.14, 1.1, z1 + 0.94), "beam")
	# the brass foot rail on its brackets
	Props.cyl(g, Vector3((x0 + x1) * 0.5, 0.18, z1 + 0.98), 0.025, x1 - x0, "brass", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(x1 + 0.18, 0.18, (z0 + z1) * 0.5), 0.025, z1 - z0, "brass", Vector3(90, 0, 0))
	for bx: float in [x0 + 0.3, (x0 + x1) * 0.5, x1 - 0.3]:
		Props.block(g, Vector3(bx - 0.02, 0.1, z1 + 0.84), Vector3(bx + 0.02, 0.2, z1 + 0.98), "brass")
	for bz: float in [z0 + 0.3, 5.0, z1 - 0.3]:
		Props.block(g, Vector3(x1 + 0.04, 0.1, bz - 0.02), Vector3(x1 + 0.18, 0.2, bz + 0.02), "brass")
	# stools: four along the front, four down the side (the regulars' end)
	for stx: float in [x0 + 0.7, x0 + 1.7, x0 + 2.7, x0 + 3.7]:
		Props.stool(g, Vector3(stx, 0, z1 + 0.85))
	for stz: float in [3.4, 4.4, 5.4, 6.4]:
		Props.stool(g, Vector3(x1 + 0.55, 0, stz))
	# the service side: the lift-up flap at the north end (brass straps and its hook), the taps and the drip tray, the
	# till and the bell, a cloth over the rail
	for hz: float in [z0 + 0.04, z0 + 0.5]:
		Props.block(g, Vector3(sx - 0.02, 1.1, hz), Vector3(x1 + 0.1, 1.115, hz + 0.04), "brass")
	Props.block(g, Vector3(sx - 0.03, 0.95, z0 + 0.56), Vector3(sx, 1.02, z0 + 0.6), "iron")
	Props.block(g, Vector3(sx + 0.1, 1.1, 4.3), Vector3(sx + 0.62, 1.12, 5.3), "zinc")
	for tz: float in [4.55, 5.05]:
		Props.cyl(g, Vector3(sx + 0.2, 1.3, tz), 0.03, 0.4, "brass")
		Props.obox(g, Vector3(sx + 0.3, 1.47, tz), Vector3(0.2, 0.04, 0.04), "brass")
		Props.cyl(g, Vector3(sx + 0.22, 1.6, tz), 0.025, 0.2, "enamel_white", Vector3(0, 0, 20))
	# the till (T-238: it was a 0.55 x 0.35 x 0.5 m brass block with a black lid, a plain box from the taproom side):
	# a drawer base, the brass body, a sloped key bank toward the landlord, the indicator housing with its rounded
	# top and price flags at the back, an embossed plate on the customers' side, the crank
	var tl0: Vector3 = Vector3(sx + 0.1, 1.1, z0 + 0.7)
	var tl1: Vector3 = Vector3(sx + 0.65, 1.1, z0 + 1.2)
	var tzc: float = (tl0.z + tl1.z) * 0.5
	Props.block(g, tl0, Vector3(tl1.x, 1.19, tl1.z), "furniture")
	Props.block(g, Vector3(tl0.x - 0.012, 1.13, tzc - 0.06), Vector3(tl0.x, 1.16, tzc + 0.06), "brass")
	Props.block(g, Vector3(tl0.x + 0.02, 1.19, tl0.z + 0.02), Vector3(tl1.x - 0.02, 1.32, tl1.z - 0.02), "brass")
	Props.obox(g, Vector3(tl0.x + 0.17, 1.365, tzc), Vector3(0.27, 0.03, 0.4), "black_paint", Vector3(0, 0, 24))
	for kk: int in 12:
		var kr: int = kk / 4
		Props.cyl(g, Vector3(tl0.x + 0.08 + kr * 0.085, 1.345 + kr * 0.038, tzc - 0.135 + (kk % 4) * 0.09), 0.018, 0.025, "enamel_white", Vector3(0, 0, 24))
	Props.block(g, Vector3(tl1.x - 0.2, 1.32, tl0.z + 0.03), Vector3(tl1.x - 0.02, 1.52, tl1.z - 0.03), "brass")
	Props.cyl(g, Vector3(tl1.x - 0.11, 1.52, tzc), 0.09, tl1.z - tl0.z - 0.06, "brass", Vector3(90, 0, 0))
	Props.block(g, Vector3(tl1.x - 0.206, 1.4, tzc - 0.15), Vector3(tl1.x - 0.2, 1.5, tzc + 0.15), "window_dark")
	for fz: float in [-0.07, 0.05]:
		Props.block(g, Vector3(tl1.x - 0.21, 1.41, tzc + fz), Vector3(tl1.x - 0.206, 1.49, tzc + fz + 0.05), "paper", false)
	Props.block(g, Vector3(tl1.x - 0.02, 1.23, tzc - 0.17), Vector3(tl1.x - 0.012, 1.47, tzc + 0.17), "black_paint")
	Props.block(g, Vector3(tl1.x - 0.012, 1.3, tzc - 0.12), Vector3(tl1.x - 0.006, 1.4, tzc + 0.12), "brass")
	Props.cyl(g, Vector3(tl1.x - 0.11, 1.3, tl0.z + 0.005), 0.014, 0.05, "iron", Vector3(90, 0, 0))
	Props.obox(g, Vector3(tl1.x - 0.135, 1.265, tl0.z - 0.025), Vector3(0.014, 0.1, 0.014), "iron", Vector3(0, 0, -35))
	Props.cyl(g, Vector3(tl1.x - 0.165, 1.225, tl0.z - 0.05), 0.016, 0.05, "enamel_white", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(sx + 0.4, 1.12, z0 + 1.5), 0.06, 0.08, "brass")
	Props.obox(g, Vector3(x1 + 0.1, 0.98, 5.9), Vector3(0.26, 0.26, 0.012), "linen", Vector3(0, 0, 90))
	# the back-bar: a cupboard base with doors and brass knobs, the top board, three bays of shelving (uprights and two
	# boards) against a back board with a mirror in its south bay, a carved cornice with a dentil strip
	var s0: float = SHELF_X0
	var s1: float = SHELF_X1
	Props.block(g, Vector3(s0 - 0.05, 0, z0), Vector3(s1 + 0.1, 0.95, z1), "wainscot")
	var dz: float = z0 + 0.12
	while dz < z1 - 0.95:
		Props.block(g, Vector3(s1 + 0.1, 0.12, dz), Vector3(s1 + 0.125, 0.85, dz + 0.92), "furniture")
		Props.cyl(g, Vector3(s1 + 0.14, 0.5, dz + 0.8), 0.015, 0.03, "brass", Vector3(0, 0, 90))
		dz += 1.1
	Props.block(g, Vector3(s0 - 0.08, 0.95, z0 - 0.05), Vector3(s1 + 0.15, 1.0, z1 + 0.05), "furniture")
	for z: float in [z0 + 0.03, 5.0, z1 - 0.03]:
		Props.block(g, Vector3(s0, 1.0, z - 0.03), Vector3(s1, 2.0, z + 0.03), "beam")
	for y: float in [1.45, 1.95]:
		Props.block(g, Vector3(s0, y, z0), Vector3(s1, y + 0.05, z1), "furniture")
	Props.block(g, Vector3(s0 - 0.05, 1.0, z0), Vector3(s0, 2.0, z1), "wainscot")
	Props.block(g, Vector3(s0, 1.05, 5.1), Vector3(s0 + 0.012, 1.9, z1 - 0.1), "mirror")
	Props.block(g, Vector3(s0 - 0.1, 2.0, z0 - 0.1), Vector3(s1 + 0.16, 2.14, z1 + 0.1), "beam")
	var tz2: float = z0 + 0.05
	while tz2 < z1:
		Props.block(g, Vector3(s1 + 0.16, 2.02, tz2), Vector3(s1 + 0.2, 2.1, tz2 + 0.08), "beam")
		tz2 += 0.2
	Props.wall_lamp(g, Vector3(s1 + 0.14, 2.45, 3.4), -90.0)
	Props.wall_lamp(g, Vector3(s1 + 0.14, 2.45, 6.6), -90.0)
	# the bottles (ShatterSet "Bar"): a row on each board; the 1.45 board leaves the gap under the wireless (z 3.9..4.95)
	_bottle_row("Bar", Vector3(3.7, 1.0, z0 + 0.15), Vector3(3.7, 1.0, z1 - 0.1), 22, 11)
	_bottle_row("Bar", Vector3(3.7, 1.5, z0 + 0.15), Vector3(3.7, 1.5, 3.9), 6, 13)
	_bottle_row("Bar", Vector3(3.7, 1.5, 4.95), Vector3(3.7, 1.5, z1 - 0.1), 10, 15)
	_bottle_row("Bar", Vector3(3.7, 2.0, 5.6), Vector3(3.7, 2.0, z1 - 0.1), 6, 14)   # left of the radio
	# steins hanging from hooks on a rack over the side counter
	Props.block(g, Vector3(sx + 0.3, 2.1, 3.2), Vector3(sx + 0.42, 2.18, z1 - 0.3), "beam")
	for hk: int in int((z1 - 0.3 - 3.45) / 0.5) + 1:   # (as many hooks as the rack is long)
		var hz2: float = 3.45 + hk * 0.5
		Props.cyl(g, Vector3(sx + 0.36, 2.04, hz2), 0.01, 0.12, "iron")
		_glassware("Bar", Vector3(sx + 0.36, 1.86, hz2), "stein", 0.94)
	# the cask on its cradle behind the counter's north end, tapped
	var ck: Node3D = Props.group(g, "Cask", Vector3(SHELF_X1 + 0.5, 0, BAR_Z0 + 0.45), 0.0)
	Props.block(ck, Vector3(-0.42, 0, -0.32), Vector3(0.42, 0.14, -0.26), "beam")
	Props.block(ck, Vector3(-0.42, 0, 0.26), Vector3(0.42, 0.14, 0.32), "beam")
	Props.cyl(ck, Vector3(0, 0.5, 0), 0.36, 0.8, "oak_stave", Vector3(0, 0, 90))
	for bb: float in [-0.3, 0.3]:
		Props.cyl(ck, Vector3(bb, 0.5, 0), 0.37, 0.05, "iron", Vector3(0, 0, 90))
	Props.cyl(ck, Vector3(0.45, 0.32, 0), 0.025, 0.14, "brass", Vector3(0, 0, 90))
	Props.cyl(ck, Vector3(0.0, 0.5, 0.02), 0.03, 0.08, "beam")   # the bung
	# the chalked price board on the north wall behind the bar, the ledger and the glasses on the counter
	Props.block(g, Vector3(6.4, 1.55, 0.15), Vector3(7.25, 2.3, 0.18), "black_paint")
	Props.block(g, Vector3(6.36, 1.52, 0.15), Vector3(7.29, 1.56, 0.2), "beam")
	Props.block(g, Vector3(6.36, 2.3, 0.15), Vector3(7.29, 2.34, 0.2), "beam")
	for li: int in 5:
		Props.block(g, Vector3(6.5, 2.17 - li * 0.13, 0.181), Vector3(6.5 + 0.35 + (li % 3) * 0.1, 2.19 - li * 0.13, 0.184), "limewash")
		Props.block(g, Vector3(7.0, 2.17 - li * 0.13, 0.181), Vector3(7.15, 2.19 - li * 0.13, 0.184), "limewash")
	Props.block(g, Vector3(6.6, 1.1, z1 + 0.2), Vector3(7.0, 1.14, z1 + 0.5), "paper")
	for x: float in [4.6, 4.8, 7.0, 8.15]:
		_glassware("Bar", Vector3(x, 1.1, z1 + 0.35), "stein", 0.94)
	# the last round poured and not drunk: schnapps glasses and the bottle on the counter
	for gp: Vector3 in [Vector3(6.2, 1.1, z1 + 0.45), Vector3(6.36, 1.1, z1 + 0.3), Vector3(7.3, 1.1, z1 + 0.55)]:
		_glassware("Bar", gp, "glass", 0.8)
	_glassware("Bar", Vector3(6.05, 1.1, z1 + 0.22), "bottle_green", 1.0)
	# a spittoon by the foot rail, a towel on the flap's hook, sawdust swept along the counter's foot
	Props.cyl(g, Vector3(x1 + 0.5, 0.08, z1 - 0.3), 0.12, 0.16, "brass")
	Props.block(g, Vector3(x0 + 0.1, 0.012, z1 + 0.84), Vector3(x1 - 0.1, 0.02, z1 + 1.3), "straw_floor")


func _dress_taproom() -> void:
	var g: Node3D = Props.group(dress, "Taproom", Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	for p: Vector2 in [Vector2(12.5, 11.5), Vector2(16.5, 11.5), Vector2(20.0, 4.5)]:
		_lib_table(Vector3(p.x, 0, p.y), 1.2, 1.2)
		for k: int in 4:
			var a: float = TAU * float(k) / 4.0 + 0.4
			var cp: Vector3 = Vector3(p.x + cos(a) * 0.95, 0, p.y + sin(a) * 0.95)
			_lib_chair(cp, rad_to_deg(atan2(-(cp.x - p.x), -(cp.z - p.y))) + 180.0 + rng.randf_range(-20, 20), rng.randf() < 0.12)
		_glassware("Taproom", Vector3(p.x - 0.2, 0.75, p.y + 0.1), "stein", 0.94)
		Props.cyl(g, Vector3(p.x + 0.25, 0.8, p.y - 0.2), 0.03, 0.1, "candle")
		Props.block(g, Vector3(p.x + 0.05, 0.751, p.y - 0.05), Vector3(p.x + 0.25, 0.755, p.y + 0.2), "paper", false)
	_dress_new_tables(g)
	# benches along the south wall, a rug in front of the hearth, coat rack by the stable door
	Props.bench(g, Vector3(9.0, 0, 15.45), 0.0, 3.0)
	Props.bench(g, Vector3(14.5, 0, 15.45), 0.0, 3.0)
	Props.block(g, Vector3(9.8, 0.012, 1.8), Vector3(14.2, 0.025, 4.8), "rug", false)
	Props.coat_rack(g, Vector3(22.6, 0, 15.3))
	# pictures and lamps (the south wall east of the benches is kept for story items)
	Props.painting(g, Vector3(3.0, 2.2, 0.16), 180.0, 0.7, 0.5, "landscape", 0, "frame_gold")
	Props.painting(g, Vector3(21.5, 2.3, 0.16), 180.0, 0.9, 0.6, "hunting", 0, "frame_walnut")
	Props.painting(g, Vector3(11.0, 2.2, 15.84), 0.0, 0.8, 0.55, "stilllife", 0, "frame_gold")
	Props.painting(g, Vector3(23.84, 2.4, 2.0), 90.0, 0.55, 0.75, "portrait", 0, "frame_walnut")   # over the signals crates
	Props.painting(g, Vector3(0.16, 2.4, 2.5), -90.0, 0.5, 0.65, "photo", 0, "frame_black", 0.0, true)
	Props.painting(g, Vector3(9.4, 2.78, 0.16), 180.0, 0.5, 0.4, "landscape", 2, "frame_black", -2.0, true)
	Props.painting(g, Vector3(23.84, 2.2, 14.0), 90.0, 0.42, 0.55, "licence", 0, "frame_black")   # the inn licence by the cellar door
	# a wall clock and a shelf of steins on the north wall west of the hearth
	var clk: Node3D = Props.group(g, "WallClock", Vector3(0.16, 2.55, 3.6), -90.0)
	Props.block(clk, Vector3(-0.17, -0.3, -0.14), Vector3(0.17, 0.3, 0.0), "furniture")
	Props.block(clk, Vector3(-0.2, 0.3, -0.17), Vector3(0.2, 0.34, 0.0), "beam")
	Props.cyl(clk, Vector3(0, 0.1, -0.145), 0.13, 0.01, "gauge_face", Vector3(90, 0, 0))
	Props.obox(clk, Vector3(0, 0.1, -0.155), Vector3(0.01, 0.09, 0.004), "black_paint", Vector3(0, 0, 0))
	Props.obox(clk, Vector3(0.03, 0.12, -0.155), Vector3(0.01, 0.07, 0.004), "black_paint", Vector3(0, 0, -60))
	Props.block(clk, Vector3(-0.12, -0.26, -0.13), Vector3(0.12, -0.02, -0.12), "window_dark")
	Props.cyl(clk, Vector3(0, -0.18, -0.125), 0.04, 0.008, "brass", Vector3(90, 0, 0))
	Props.block(g, Vector3(8.2, 2.0, 0.15), Vector3(10.6, 2.04, 0.4), "furniture")
	for i: int in 6:
		_glassware("Taproom", Vector3(8.4 + i * 0.4, 2.04, 0.28), "stein", 0.94)
	Props.block(g, Vector3(8.2, 1.9, 0.15), Vector3(8.24, 2.0, 0.38), "furniture")
	Props.block(g, Vector3(10.56, 1.9, 0.15), Vector3(10.6, 2.0, 0.38), "furniture")
	Props.lantern(g, Vector3(6.5, 2.6, 11.5), TAP_H - 0.28)
	Props.lantern(g, Vector3(17.5, 2.6, 4.0), TAP_H - 0.28)
	Props.lantern(g, Vector3(19.5, 2.6, 13.0), TAP_H - 0.28)
	Props.lantern(g, Vector3(14.0, 2.6, 8.0), TAP_H - 0.36)
	# crates of the signals unit's kit against the east wall under the portrait (T-238: they stood 0.7 m off the east
	# wall and 1.6 m off the north one, without a collider, between the front door and the Garand; TAP_CRATES is theirs)
	Props.crate(g, Vector3(23.44, 0, 2.0), 0.7, 94.0)
	Props.crate(g, Vector3(23.46, 0.7, 2.02), 0.55, 86.0)
	Props.crate(g, Vector3(23.5, 0, 1.25), 0.6, 92.0)
	# boarded-up feel: spare planks leaning on the west wall south of the window (clear of the Kar98k chalk at z 3.1 and
	# of Door 5 at z 8.25). T-238: they stood upright a metre out in the walk to the Old Cellar door, tipped along the
	# wall and touching nothing; now their feet are 0.3 m out and their heads on the plaster
	for i: int in 3:
		var lean: float = 7.0 + i * 2.0
		Props.obox(g, Vector3(T * 0.5 + 0.06 + sin(deg_to_rad(lean)) * 1.0, cos(deg_to_rad(lean)) * 1.0, 7.0 + i * 0.22), Vector3(0.04, 2.0, 0.18), "planks", Vector3(0, 0, lean))


## The added tables (TAP_TABLES_NEW, T-072) and what the round 1 patrons leave on them as they run: steins half
## drunk (shootable), a game of skat dropped mid-hand, a pipe, Frau Pohl's coffee cup and her suitcase, the
## soldier's Christmas parcel on the bar. A candle on each table (the two big ones light, following their lamps).
func _dress_new_tables(g: Node3D) -> void:
	for t: Array in TAP_TABLES_NEW:
		var c: Vector2 = t[0]
		var w: float = float(t[1])
		var d: float = float(t[2])
		_lib_table(Vector3(c.x, 0, c.y), w, d)
		match str(t[3]):
			"chairs":
				for off: Vector2 in [Vector2(-0.85, 0), Vector2(0.85, 0), Vector2(0, -0.85), Vector2(0, 0.85)]:
					var cp: Vector3 = Vector3(c.x + off.x, 0, c.y + off.y)
					_lib_chair(cp, rad_to_deg(atan2(-off.x, -off.y)) + 180.0)
			"pair":
				for off2: Vector2 in [Vector2(-0.75, 0), Vector2(0.75, 0)]:
					_lib_chair(Vector3(c.x + off2.x, 0, c.y + off2.y), rad_to_deg(atan2(-off2.x, -off2.y)) + 180.0)
			"benches":
				for sx: float in [-1.0, 1.0]:
					Props.bench(g, Vector3(c.x + sx * 0.75, 0, c.y), 90.0, d - 0.1)
		Props.cyl(g, Vector3(c.x + w * 0.2, 0.8, c.y - d * 0.15), 0.03, 0.1, "candle")
		Props.cyl(g, Vector3(c.x + w * 0.2, 0.752, c.y - d * 0.15), 0.05, 0.006, "brass")
	# the carters' table (19, 9): steins, the skat hands face down and the pot, a pipe in the ashtray
	_glassware("Taproom", Vector3(18.7, 0.75, 9.15), "stein", 0.94)
	_glassware("Taproom", Vector3(19.15, 0.75, 8.55), "stein", 0.94)
	var cr: RandomNumberGenerator = RandomNumberGenerator.new()
	cr.seed = 1223
	for k: int in 9:
		Props.obox(g, Vector3(19.0 + cr.randf_range(-0.35, 0.3), 0.753 + k * 0.001, 9.0 + cr.randf_range(-0.3, 0.35)), Vector3(0.06, 0.002, 0.09),
			"paper", Vector3(0, cr.randf_range(0, 180), 0))
	Props.cyl(g, Vector3(19.3, 0.765, 9.3), 0.06, 0.015, "iron")             # the ashtray
	Props.obox(g, Vector3(19.33, 0.785, 9.3), Vector3(0.012, 0.012, 0.14), "furniture", Vector3(0, 30, 0))   # the pipe's stem
	Props.cyl(g, Vector3(19.38, 0.79, 9.36), 0.02, 0.04, "furniture")
	for k2: int in 4:   # the pot: a few coins
		Props.cyl(g, Vector3(18.95 + k2 * 0.03, 0.756, 9.05), 0.012, 0.004, "brass")
	# the table cleared in a hurry (16, 4.8): a stein, a mug knocked onto its side
	_glassware("Taproom", Vector3(15.8, 0.75, 4.6), "stein", 0.94)
	PropsStory.mug(g, Vector3(16.25, 0.75, 5.0))
	Props.obox(g, Vector3(16.1, 0.79, 4.45), Vector3(0.08, 0.16, 0.08), "enamel_plate", Vector3(90, 40, 0))
	# Frau Pohl's table (12.3, 5.4): her cup of real coffee, a handkerchief; the suitcase on the floor beside her
	PropsStory.mug(g, Vector3(12.45, 0.75, 5.35))
	Props.obox(g, Vector3(12.15, 0.753, 5.55), Vector3(0.18, 0.004, 0.18), "linen", Vector3(0, 25, 0))
	var sc: Node3D = Props.group(g, "PohlSuitcase", Vector3(11.35, 0, 6.15), 15.0)
	Props.block(sc, Vector3(-0.3, 0.0, -0.1), Vector3(0.3, 0.42, 0.1), "leather")
	for sx2: float in [-0.15, 0.15]:
		Props.block(sc, Vector3(sx2 - 0.02, 0.0, -0.105), Vector3(sx2 + 0.02, 0.42, 0.105), "furniture")   # straps
	Props.obox(sc, Vector3(0, 0.46, 0), Vector3(0.14, 0.03, 0.03), "leather")   # the handle
	# the long trestle (8, 11.8): steins left in a row, a loaf
	for k3: int in 3:
		_glassware("Taproom", Vector3(7.85 + 0.25 * float(k3 % 2), 0.75, 11.0 + 0.7 * k3), "stein", 0.94)
	PropsStory.loaf(g, Vector3(8.05, 0.75, 12.6), 80.0)
	# Gefreiter Sobotta's Christmas parcel on the bar, brown paper and string: he was nearly home (T-072)
	var pc: Node3D = Props.group(g, "ChristmasParcel", Vector3(7.9, 1.1, BAR_Z1 + 0.45), 10.0)
	Props.block(pc, Vector3(-0.16, 0.0, -0.11), Vector3(0.16, 0.13, 0.11), "paper")
	Props.block(pc, Vector3(-0.162, 0.0, -0.01), Vector3(0.162, 0.132, 0.01), "rope")
	Props.block(pc, Vector3(-0.01, 0.0, -0.112), Vector3(0.01, 0.132, 0.112), "rope")
	_glassware("Taproom", Vector3(7.45, 1.1, BAR_Z1 + 0.5), "stein", 0.94)


func _dress_upstairs() -> void:
	var g: Node3D = Props.group(dress, "Upstairs", Vector3.ZERO)
	_lib_bed(Vector3(0.3, UP_Y, 0.4), Vector3(2.2, UP_Y + 0.5, 2.6), "cloth_red", g)
	_lib_bed(Vector3(13.6, UP_Y, 0.4), Vector3(15.6, UP_Y + 0.5, 2.6), "cloth_green", g)
	_lib_bed(Vector3(21.6, UP_Y, 2.3), Vector3(23.7, UP_Y + 0.5, 4.7), "cloth_red", g)
	Props.trunk(g, Vector3(10.4, UP_Y, 0.5), Vector3(11.6, UP_Y + 0.5, 1.2))
	Props.washstand(g, Vector3(6.9, UP_Y, 0.45), 180.0)
	Props.washstand(g, Vector3(8.6, UP_Y, 4.5), -90.0)
	Props.wardrobe(g, Vector3(15.5, UP_Y, 3.9), 90.0)
	Props.wardrobe(g, Vector3(7.5, UP_Y, 1.75), 90.0)   # (room 1's east wall since the hall wall moved to z 5: clear of the MP40 chalk)
	_lib_chair(Vector3(2.8, UP_Y, 1.2), 140.0, true)
	_lib_chair(Vector3(18.0, UP_Y, 1.3), 200.0)
	# pictures: one per room, two in the hall, and a mirror by the stair head (the hall's north wall straight ahead
	# at the top of the stairs, x < 4, stays free for a story item)
	Props.painting(g, Vector3(12.0, UP_Y + 1.7, 0.16), 180.0, 0.5, 0.65, "portrait", 1, "frame_gold")
	Props.painting(g, Vector3(18.0, UP_Y + 1.6, 9.84), 0.0, 0.7, 0.5, "landscape", 2, "frame_walnut")
	Props.painting(g, Vector3(7.85, UP_Y + 1.7, 3.0), 90.0, 0.6, 0.45, "landscape", 1, "frame_gold")
	Props.painting(g, Vector3(8.15, UP_Y + 1.7, 2.0), -90.0, 0.5, 0.4, "stilllife", 1, "frame_black", 1.5)
	Props.painting(g, Vector3(23.85, UP_Y + 1.8, 1.6), 90.0, 0.45, 0.36, "photo", 1, "frame_black", 0.0, true)
	Props.painting(g, Vector3(15.5, UP_Y + 1.75, 9.84), 0.0, 0.45, 0.55, "hunting", 1, "frame_walnut", -1.5)   # (east of the attic flight, T-224)
	Props.mirror(g, Vector3(0.15, UP_Y + 1.7, 8.0), -90.0, 0.5, 0.7)
	# rugs and nightstands with candles
	Props.block(g, Vector3(2.4, UP_Y + 0.012, 0.9), Vector3(4.2, UP_Y + 0.024, 2.6), "rug", false)
	Props.block(g, Vector3(11.4, UP_Y + 0.012, 1.4), Vector3(13.3, UP_Y + 0.024, 3.4), "rug", false)
	Props.block(g, Vector3(18.6, UP_Y + 0.012, 2.2), Vector3(21.2, UP_Y + 0.024, 4.6), "rug", false)
	for ns: Vector3 in [Vector3(2.55, UP_Y, 0.55), Vector3(13.1, UP_Y, 0.55), Vector3(21.1, UP_Y, 4.45)]:
		_lib("nightstand", ns, 0.0, Vector3(0.8, 1.0, 0.8), false)
		Props.cyl(g, ns + Vector3(0.05, 0.64, 0.02), 0.04, 0.02, "brass")
		Props.cyl(g, ns + Vector3(0.05, 0.7, 0.02), 0.012, 0.1, "candle")
	for p: Vector3 in [Vector3(4.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 3.0), Vector3(20.0, UP_Y + 2.2, 3.0), Vector3(12.0, UP_Y + 2.2, 7.0)]:
		Props.lantern(g, p, UP_TOP - 0.24)   # (the hall's lantern hangs at z 7 since T-224: the attic flight runs along the south wall)
	Props.lantern(g, Vector3(3.2, 4.6, 12.5), UP_TOP)   # in the stairwell


## T-224: the attic (der Dachboden), the Krauses' stored life under the roof: floorboards round the stair well, the
## boarded ceiling with the roof's tie beams, purlins and rafters' feet showing, a plank dado under the eaves, the
## chimney breast (the cousins chalked their girls on it too; the cat's basket beside it, split logs), the husband's war
## trunk of 1916 with his helmet on it, two more trunks, the old wardrobe with its door off, the apple racks under the
## north eaves and strings of onions from the beam, a washing line of sheets over the trunks, the cousins' rocking horse
## and cradle, skis and the sledge against the south wall, the Christmas boxes (straw stars, the tree stand) in the
## south-west corner, iron bedsteads stacked by the south wall, a dressmaker's dummy, pictures turned to the wall, the
## ladder to the roof hatch, the hoist beams through both gables with their pulleys and ropes down to the ledges (and the
## ledges' brackets outside), cobwebs, a leak, worn boards from the stair head to the windows, snow blown in. Every
## solid thing stands over its ATT_SOLIDS collider; the rest is dressing, nothing in the zombies' way in from the windows.
func _dress_attic() -> void:
	var g: Node3D = Props.group(dress, "Attic", Vector3.ZERO)
	var y: float = ATT_Y
	var hx: float = ASTAIR_HOLE_X0
	Props.block(g, Vector3(0.15, y, 0.15), Vector3(hx, y + 0.012, 9.85), "floorboards")
	Props.block(g, Vector3(hx, y, 0.15), Vector3(ASTAIR_X1, y + 0.012, ASTAIR_Z0), "floorboards")
	Props.block(g, Vector3(ASTAIR_X1, y, 0.15), Vector3(23.85, y + 0.012, 9.85), "floorboards")
	Props.block(g, Vector3(0.15, ATT_TOP - 0.012, 0.15), Vector3(23.85, ATT_TOP, 9.85), "planks")
	Props.block(g, Vector3(0.15, y, 0.15), Vector3(23.85, y + 0.9, 0.18), "planks")
	Props.block(g, Vector3(0.15, y, 9.82), Vector3(23.85, y + 0.9, 9.85), "planks")
	# the roof's timbers under the boards: tie beams across, king-post stubs, the rafters' feet, a purlin each side
	for x: float in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0]:
		Props.block(g, Vector3(x - 0.1, ATT_TOP - 0.46, 0.15), Vector3(x + 0.1, ATT_TOP - 0.2, 9.85), "beam")
		Props.block(g, Vector3(x - 0.08, ATT_TOP - 0.2, 4.9), Vector3(x + 0.08, ATT_TOP, 5.1), "beam")
		for s: float in [-1.0, 1.0]:
			Props.obox(g, Vector3(x, ATT_TOP - 0.18, 5.0 + s * 2.45), Vector3(0.14, 0.14, 5.0), "beam", Vector3(s * 9.0, 0, 0))   # (their feet clear the BAR's chalk)
	for z: float in [2.4, 7.6]:
		Props.block(g, Vector3(0.15, ATT_TOP - 0.3, z - 0.08), Vector3(23.85, ATT_TOP - 0.12, z + 0.08), "beam")
	# the chimney breast: soot, three chalk girls holding hands (the cousins were up here too), the cat's basket, logs
	PropsStory.stain(g, Vector3(11.2, y + 0.9, 0.853), Vector3(12.8, y + 2.6, 0.857), "soot")
	for cx: float in [11.45, 12.0, 12.55]:
		_chalk_figure(g, Vector3(cx, y + 0.35, 0.852), 180.0, 0.5)
	Props.cyl(g, Vector3(13.45, y + 0.08, 0.6), 0.3, 0.16, "hay")
	Props.obox(g, Vector3(13.45, y + 0.19, 0.6), Vector3(0.42, 0.06, 0.36), "cloth_cream", Vector3(0, 20, 0))
	for k: int in 6:
		Props.cyl(g, Vector3(10.25 + (k % 3) * 0.17, y + 0.08 + (k / 3) * 0.15, 0.5), 0.07, 0.5, "beam", Vector3(90, 0, 0))
	# trunks (over their colliders), the husband's with his 1916 helmet, the old wardrobe with its door leaning beside it
	Props.trunk(g, Vector3(4.2, y, 0.4), Vector3(5.4, y + 0.6, 1.2))
	Props.stencil(g, Vector3(4.8, y + 0.32, 1.205), 180.0, "KRAUSE  1916", 24)
	PropsStory.helmet(g, Vector3(4.65, y + 0.6, 0.8), 30.0)
	Props.trunk(g, Vector3(5.6, y, 0.35), Vector3(6.7, y + 0.55, 1.05))
	Props.trunk(g, Vector3(14.2, y, 0.4), Vector3(15.5, y + 0.62, 1.15))
	Props.block(g, Vector3(14.3, y + 0.62, 0.5), Vector3(15.4, y + 0.66, 1.05), "linen")   # a folded tablecloth on it
	Props.wardrobe(g, Vector3(20.7, y, 0.55), 180.0)
	Props.obox(g, Vector3(19.65, y + 0.9, 0.5), Vector3(0.04, 1.8, 0.55), "furniture", Vector3(0, 0, 8))   # the door off its hinges, leaning beside it
	# the apple racks under the north eaves (winter stores), strings of onions from the tie beam
	for sy: float in [0.35, 0.75, 1.15]:
		Props.block(g, Vector3(7.0, y + sy, 0.3), Vector3(9.4, y + sy + 0.03, 0.9), "planks")
		for k2: int in 9:
			Props.ball(g, Vector3(7.15 + k2 * 0.26, y + sy + 0.07, 0.5 + (k2 % 2) * 0.2), Vector3(0.09, 0.08, 0.09), "jar_red" if k2 % 3 != 0 else "ribbon_red")
	for ux: float in [7.0, 9.4]:
		for uz: float in [0.3, 0.84]:
			Props.block(g, Vector3(ux - 0.03, y, uz), Vector3(ux + 0.03, y + 1.5, uz + 0.06), "beam")
	for k3: int in 4:
		var oz: float = 1.3 + k3 * 0.35
		Props.cyl(g, Vector3(10.0, ATT_TOP - 0.76, oz), 0.008, 0.6, "rope")
		for k4: int in 5:
			Props.ball(g, Vector3(10.0, ATT_TOP - 1.1 - k4 * 0.11, oz), Vector3(0.09, 0.08, 0.09), "sandbag")
	# the washing line over the trunks: sheets and a nightshirt, pegs
	Props.strut(g, Vector3(0.3, y + 2.25, 1.65), Vector3(6.9, y + 2.2, 1.65), 0.012, "rope", true)
	for sx: float in [1.3, 2.9, 4.6]:
		Props.obox(g, Vector3(sx, y + 1.62, 1.65), Vector3(1.0, 1.16, 0.02), "linen", Vector3(0, 0, 1.5))
		for px: float in [sx - 0.42, sx + 0.42]:
			Props.block(g, Vector3(px - 0.01, y + 2.16, 1.63), Vector3(px + 0.01, y + 2.3, 1.67), "beam")
	Props.obox(g, Vector3(6.1, y + 1.78, 1.65), Vector3(0.5, 0.84, 0.03), "cloth_cream")
	# the cousins' rocking horse and the cradle, skis and the sledge against the south wall
	var rh: Node3D = Props.group(g, "RockingHorse", Vector3(3.9, y, 8.9), 20.0)
	Props.obox(rh, Vector3(0, 0.62, 0), Vector3(0.7, 0.3, 0.22), "furniture")
	Props.obox(rh, Vector3(0.42, 0.85, 0), Vector3(0.22, 0.38, 0.14), "furniture", Vector3(0, 0, -25))
	Props.obox(rh, Vector3(0.5, 1.02, 0), Vector3(0.2, 0.1, 0.1), "furniture", Vector3(0, 0, 10))
	for lx: float in [-0.22, 0.22]:
		for lz: float in [-0.08, 0.08]:
			Props.obox(rh, Vector3(lx, 0.3, lz), Vector3(0.05, 0.4, 0.05), "furniture", Vector3(0, 0, lx * 40.0))
		Props.obox(rh, Vector3(0, 0.06, lx * 0.6), Vector3(1.0, 0.04, 0.05), "beam")
	Props.obox(rh, Vector3(-0.38, 0.72, 0), Vector3(0.1, 0.22, 0.06), "rope", Vector3(0, 0, 30))   # the tail
	var cr: Node3D = Props.group(g, "Cradle", Vector3(6.2, y, 9.3), -10.0)
	Props.block(cr, Vector3(-0.45, 0.22, -0.26), Vector3(0.45, 0.58, 0.26), "furniture")
	Props.block(cr, Vector3(-0.42, 0.5, -0.23), Vector3(0.42, 0.52, 0.23), "linen")
	for cx2: float in [-0.4, 0.4]:
		Props.obox(cr, Vector3(cx2, 0.06, 0), Vector3(0.05, 0.05, 0.7), "beam")
	for i: int in 2:
		Props.obox(g, Vector3(7.5 + i * 0.14, y + 1.0, 9.7), Vector3(0.08, 2.0, 0.03), "pine", Vector3(-6.0, 0, 0))
	var sl: Node3D = Props.group(g, "Sledge", Vector3(8.6, y, 9.55), 0.0)
	for sx2: float in [-0.2, 0.2]:
		Props.obox(sl, Vector3(sx2, 0.55, 0), Vector3(0.04, 1.1, 0.08), "iron", Vector3(-14.0, 0, 0))
	for sy2: float in [0.3, 0.6, 0.9]:
		Props.block(sl, Vector3(-0.28, sy2, -0.1 + sy2 * 0.2), Vector3(0.28, sy2 + 0.04, 0.0 + sy2 * 0.2), "planks")
	# the Christmas boxes in the south-west corner (straw stars, the candle holders, the iron tree stand)
	Props.crate(g, Vector3(1.6, y, 8.6), 0.8, 8.0)
	Props.crate(g, Vector3(2.25, y, 9.25), 0.7, -10.0)
	Props.crate(g, Vector3(1.5, y + 0.8, 8.65), 0.45, 25.0)
	for k5: int in 5:
		Props.obox(g, Vector3(2.0 + (k5 % 3) * 0.16, y + 0.705, 9.1 + (k5 / 3) * 0.14), Vector3(0.1, 0.004, 0.1), "straw_floor", Vector3(0, k5 * 23.0, 0))
	for k6: int in 2:
		Props.block(g, Vector3(2.75, y + 0.03 * k6, 9.0 - 0.3 * k6), Vector3(3.35, y + 0.03 * (k6 + 1), 9.06 - 0.3 * k6 + 0.6 * k6), "iron")
	# iron bedsteads stacked by the south wall, a dressmaker's dummy, pictures turned to the wall, a cracked mirror
	for bi: int in 3:
		var bx: float = 19.6 + bi * 1.35
		for bz: float in [8.65, 9.55]:
			Props.block(g, Vector3(bx, y + 0.12, bz - 0.03), Vector3(bx + 1.25, y + 0.9, bz + 0.03), "iron")
		for by: float in [0.3, 0.6, 0.86]:
			Props.block(g, Vector3(bx, y + by, 8.62), Vector3(bx + 1.25, y + by + 0.04, 9.58), "iron")
	var dm: Node3D = Props.group(g, "Dummy", Vector3(21.2, y, 1.4), 30.0)
	Props.cyl(dm, Vector3(0, 0.03, 0), 0.25, 0.06, "iron")
	Props.cyl(dm, Vector3(0, 0.6, 0), 0.02, 1.1, "iron")
	Props.ball(dm, Vector3(0, 1.35, 0), Vector3(0.42, 0.62, 0.26), "linen")
	Props.cyl(dm, Vector3(0, 1.7, 0), 0.05, 0.1, "furniture")
	for pi_: int in 3:
		Props.obox(g, Vector3(23.6 - pi_ * 0.08, y + 0.45, 7.2 + pi_ * 0.2), Vector3(0.03, 0.8, 0.6), "frame_gold" if pi_ == 1 else "furniture", Vector3(0, 0, 12.0 + pi_ * 2.0))
	Props.mirror(g, Vector3(23.75, y + 0.9, 2.2), 90.0, 0.5, 0.7)
	# the ladder to the roof hatch in the north-east corner, the hatch in the boards
	Props.ladder_stowed(g, Vector3(15.5, y + 1.3, 0.18), 180.0, 2.7, "beam")   # (T-229: stowed on its hooks over the third trunk; the hatch stays shut)
	Props.block(g, Vector3(22.1, ATT_TOP - 0.03, 0.4), Vector3(23.1, ATT_TOP - 0.012, 1.3), "furniture")
	# the hoists through the gables: the beam, the pulley and the rope down to the ledge, a sack waiting out there;
	# the ledges' brackets and braces on the wall outside
	for side: Array in [[-1.0, 0.0], [1.0, 24.0]]:
		var o: float = float(side[0])     # outward sign
		var wx: float = float(side[1])    # the wall's x
		var zc: float = ATT_WIN_Z
		Props.block(g, Vector3(minf(wx + o * 1.9, wx - o * 1.5), y + 2.3, zc - 0.1), Vector3(maxf(wx + o * 1.9, wx - o * 1.5), y + 2.5, zc + 0.1), "beam")
		Props.cyl(g, Vector3(wx + o * 1.7, y + 2.2, zc), 0.12, 0.06, "iron", Vector3(90, 0, 0))
		Props.strut(g, Vector3(wx + o * 1.7, y + 2.1, zc), Vector3(wx + o * 1.7, y + 0.05, zc - 0.5), 0.02, "rope", true)
		Props.sack(g, Vector3(wx + o * 1.7, y, zc - 0.5), 20.0, 0.9)
		for zb: float in [zc - 1.9, zc + 1.9]:
			Props.block(g, Vector3(minf(wx, wx + o * 2.15), y - 0.44, zb - 0.07), Vector3(maxf(wx, wx + o * 2.15), y - 0.3, zb + 0.07), "beam")
			Props.strut(g, Vector3(wx + o * 2.0, y - 0.38, zb), Vector3(wx + o * 0.16, y - 1.7, zb), 0.12, "beam")
	# cobwebs in the corners, the leak under the ridge, worn boards from the stair head to the windows
	Props.cobweb(g, Vector3(0.15, ATT_TOP - 0.02, 0.15), 0.0, 0.9)
	Props.cobweb(g, Vector3(23.85, ATT_TOP - 0.02, 0.15), -90.0, 0.8)
	Props.cobweb(g, Vector3(23.85, ATT_TOP - 0.02, 9.85), 180.0, 0.9)
	Props.cobweb(g, Vector3(0.15, ATT_TOP - 0.02, 9.85), 90.0, 0.8)
	PropsStory.stain(g, Vector3(14.0, ATT_TOP - 0.02, 4.0), Vector3(16.4, ATT_TOP - 0.016, 6.2), "water_stain")
	PropsStory.stain(g, Vector3(14.4, y + 0.0125, 4.4), Vector3(16.0, y + 0.0135, 5.9), "water_stain")
	PropsStory.stain(g, Vector3(0.6, y + 0.0125, 3.6), Vector3(12.4, y + 0.0135, 5.4), "floor_worn")
	PropsStory.stain(g, Vector3(12.4, y + 0.0125, 3.6), Vector3(23.4, y + 0.0135, 5.4), "floor_worn")
	PropsStory.snow_blown_in(g, Vector3(0, y, ATT_WIN_Z), Vector3(1, 0, 0), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(24.0, y, ATT_WIN_Z), Vector3(-1, 0, 0), WIN_SILL)
	# lamps: an oil lantern by the west hoist and one by the east, the sconce over the stair head
	Props.lantern(g, Vector3(5.0, y + 2.0, 5.0), ATT_TOP)
	Props.lantern(g, Vector3(19.0, y + 2.05, 5.0), ATT_TOP)
	Props.wall_lamp(g, Vector3(11.5, y + 1.85, 9.84), 0.0)
	_dress_attic_stairs(g)


## T-224 (touched up after the owner's look): the attic flight (see build_attic). Fifteen solid steps, each a riser
## block with its tread board and nosing, drawn under the invisible ramp (a tread's top is never above the nosing line);
## a footboard where the ramp leaves the hall floor. The open north side is a closed string on the slope over a
## panelled under-stair (0.25 m panels whose tops tuck behind the string, so no daylight shows between them), with the
## little cupboard door; the under-stair's east end is panelled too, floor to ceiling, so the hall east of the flight
## sees a wainscoted end wall and not into the cavity. Newels and balusters between the rail bars up the flight and
## round the well, a wall rail on the south wall with a sconce mid-flight, fascia boards over the attic floor's cut
## edges round the well (the slab's raw faces otherwise), and the hall runner stops short of the flight.
func _dress_attic_stairs(g: Node3D) -> void:
	var z0: float = ASTAIR_Z0
	var z1: float = ASTAIR_Z1
	var rh: float = (ATT_Y - UP_Y) / float(ASTAIR_STEPS + 1)
	var foot: float = ASTAIR_X0 - ASTAIR_STEP
	var run: float = ASTAIR_X1 - foot
	var rise: float = ATT_Y - UP_Y
	var ang_r: float = atan2(rise, run)
	var ang: float = rad_to_deg(ang_r)
	var perp: Vector3 = Vector3(-sin(ang_r), cos(ang_r), 0)   # the slope's up-normal
	# the steps: a riser block (beam) with the tread board and its nosing (furniture) on top
	for k: int in ASTAIR_STEPS:
		var xa: float = ASTAIR_X0 + k * ASTAIR_STEP
		var xb: float = xa + ASTAIR_STEP
		var yt: float = UP_Y + (k + 1) * rh
		Props.block(g, Vector3(xa, yt - rh, z0 + 0.02), Vector3(xb + 0.02, yt - 0.045, z1), "beam")
		Props.block(g, Vector3(xa - 0.03, yt - 0.045, z0 + 0.02), Vector3(xb + 0.02, yt, z1), "furniture")
	Props.block(g, Vector3(ASTAIR_X1 - 0.03, ATT_Y - rh, z0 + 0.02), Vector3(ASTAIR_X1 + 0.005, ATT_Y, z1), "beam")   # the last riser, the attic floor's edge
	Props.block(g, Vector3(foot + 0.2, UP_Y, z0 + 0.02), Vector3(ASTAIR_X0, UP_Y + 0.1, z1), "furniture")   # the footboard (the ramp is 0.1 up here)
	# the closed string on the slope (its top on the nosing line, 0.36 deep), from where it clears the hall floor to the head
	var xs: float = foot + 0.405 / rise * run
	var s_len: float = (ASTAIR_X1 - xs) / cos(ang_r)
	var s_mid: Vector3 = Vector3((xs + ASTAIR_X1) * 0.5, _astair_y((xs + ASTAIR_X1) * 0.5), z0 - 0.015)
	Props.obox(g, s_mid - perp * 0.18, Vector3(s_len, 0.36, 0.05), "beam", Vector3(0, 0, ang))
	Props.block(g, Vector3(ASTAIR_X0 - 0.03, UP_Y, z0 - 0.04), Vector3(xs, UP_Y + 0.26, z0 + 0.02), "beam")   # the string's foot, a cheek on the first riser
	# the panelled under-stair below the string (quarter-metre panels: their tops at 0.2 under the nosing line stay
	# behind the string's lower edge), the skirting, the cupboard door
	var xp: float = ASTAIR_X0
	while xp < ASTAIR_X1 - 0.01:
		var xq: float = minf(xp + 0.25, ASTAIR_X1)
		var top: float = _astair_y(xp) - 0.2
		if top > UP_Y + 0.14:
			Props.block(g, Vector3(xp, UP_Y + 0.12, z0 - 0.03), Vector3(xq, top, z0 + 0.02), "wainscot")
		xp = xq
	Props.block(g, Vector3(ASTAIR_X0 - 0.03, UP_Y, z0 - 0.045), Vector3(ASTAIR_X1 + 0.06, UP_Y + 0.14, z0 + 0.02), "beam")   # skirting
	Props.block(g, Vector3(10.6, UP_Y + 0.14, z0 - 0.05), Vector3(11.5, UP_Y + 1.6, z0 - 0.03), "board_wood_v")   # the cupboard door
	for fy: float in [UP_Y + 0.14, UP_Y + 1.6]:
		Props.block(g, Vector3(10.55, fy - 0.02, z0 - 0.055), Vector3(11.55, fy + 0.02, z0 - 0.03), "beam")
	for fx: float in [10.55, 11.51]:
		Props.block(g, Vector3(fx, UP_Y + 0.14, z0 - 0.055), Vector3(fx + 0.04, UP_Y + 1.6, z0 - 0.03), "beam")
	Props.cyl(g, Vector3(11.38, UP_Y + 0.9, z0 - 0.07), 0.02, 0.04, "iron", Vector3(90, 0, 0))
	# the under-stair's east end: a panelled wall from the hall floor to the ceiling, skirting, chair rail, cornice
	Props.block(g, Vector3(ASTAIR_X1, UP_Y, z0 - 0.03), Vector3(ASTAIR_X1 + 0.04, UP_TOP, z1), "wainscot")
	Props.block(g, Vector3(ASTAIR_X1 - 0.01, UP_Y, z0 - 0.045), Vector3(ASTAIR_X1 + 0.06, UP_Y + 0.14, z1), "beam")
	Props.block(g, Vector3(ASTAIR_X1 - 0.01, UP_Y + 1.0, z0 - 0.045), Vector3(ASTAIR_X1 + 0.06, UP_Y + 1.06, z1), "beam")
	Props.block(g, Vector3(ASTAIR_X1 - 0.01, UP_TOP - 0.14, z0 - 0.045), Vector3(ASTAIR_X1 + 0.06, UP_TOP, z1), "beam")
	Props.block(g, Vector3(ASTAIR_X1 - 0.01, UP_Y + 0.14, z0 - 0.045), Vector3(ASTAIR_X1 + 0.06, UP_TOP - 0.14, z0 - 0.03), "beam")   # the corner post
	# fascia boards over the attic floor's cut edges round the well (the slab is 0.3 m thick), with a nosing on top
	var hx: float = ASTAIR_HOLE_X0
	Props.block(g, Vector3(hx - 0.02, UP_TOP, z0 - 0.04), Vector3(ASTAIR_X1 + 0.04, ATT_Y, z0 + 0.0), "beam")   # the north edge
	Props.block(g, Vector3(hx - 0.02, UP_TOP, z0 - 0.04), Vector3(hx + 0.02, ATT_Y, z1), "beam")   # the west end
	Props.block(g, Vector3(hx - 0.04, ATT_Y, z0 - 0.06), Vector3(ASTAIR_X1 + 0.04, ATT_Y + 0.03, z0 + 0.0), "furniture")
	Props.block(g, Vector3(hx - 0.04, ATT_Y, z0 - 0.06), Vector3(hx + 0.02, ATT_Y + 0.03, z1), "furniture")
	# newels and balusters: up the flight between the rail bars, round the well's north edge and west end
	var rz: float = z0 + 0.05
	Props.newel(g, Vector3(ASTAIR_X0, UP_Y, rz), 1.05)
	Props.newel(g, Vector3(ASTAIR_X1 + 0.03, ATT_Y, rz), 1.05)
	Props.newel(g, Vector3(hx, ATT_Y, rz), 1.05)
	Props.newel(g, Vector3(hx + 0.05, ATT_Y, z1 - 0.1), 1.05)
	var n: int = int(Vector2(ASTAIR_X1 - ASTAIR_X0, rise).length() / 0.18)
	for k2: int in n:
		var t: float = (float(k2) + 0.5) / float(n)
		var bx: float = lerpf(ASTAIR_X0, ASTAIR_X1, t)
		Props.cyl(g, Vector3(bx, lerpf(UP_Y, ATT_Y, t) + 0.46, rz), 0.018, 0.9, "furniture")
	var wx: float = hx + 0.2
	while wx < ASTAIR_X1 - 0.1:
		Props.cyl(g, Vector3(wx, ATT_Y + 0.46, rz), 0.018, 0.9, "furniture")
		wx += 0.18
	var wz: float = z0 + 0.25
	while wz < z1 - 0.2:
		Props.cyl(g, Vector3(hx + 0.05, ATT_Y + 0.46, wz), 0.018, 0.9, "furniture")
		wz += 0.18
	# a wall rail up the south wall with iron brackets, the wainscot following the flight, the sconce mid-flight
	Props.strut(g, Vector3(ASTAIR_X0, UP_Y + 0.98, z1 - 0.09), Vector3(ASTAIR_X1, ATT_Y + 0.98, z1 - 0.09), 0.045, "furniture", true)
	for t2: float in [0.1, 0.4, 0.7, 0.95]:
		var bx2: float = lerpf(ASTAIR_X0, ASTAIR_X1, t2)
		Props.block(g, Vector3(bx2 - 0.02, lerpf(UP_Y, ATT_Y, t2) + 0.9, z1 - 0.09), Vector3(bx2 + 0.02, lerpf(UP_Y, ATT_Y, t2) + 0.94, z1), "iron")
	var w_len: float = (ASTAIR_X1 - ASTAIR_X0) / cos(ang_r)
	var w_mid: Vector3 = Vector3((ASTAIR_X0 + ASTAIR_X1) * 0.5, _astair_y((ASTAIR_X0 + ASTAIR_X1) * 0.5), z1 - 0.015)
	Props.obox(g, w_mid + perp * 0.57, Vector3(w_len - 0.1, 0.9, 0.03), "wainscot_matte", Vector3(0, 0, ang))
	Props.obox(g, w_mid + perp * 1.14, Vector3(w_len - 0.1, 0.07, 0.06), "beam", Vector3(0, 0, ang))
	Props.obox(g, w_mid + perp * 0.09, Vector3(w_len - 0.1, 0.14, 0.045), "beam", Vector3(0, 0, ang))
	Props.wall_lamp(g, Vector3(9.4, _astair_y(9.4) + 1.75, z1 - 0.01), 0.0)
	# two more oil lanterns under the roof over the well and the east end: the attic was too dark to read
	Props.lantern(g, Vector3(10.0, ATT_Y + 2.1, 9.0), ATT_TOP)
	Props.lantern(g, Vector3(12.0, ATT_Y + 2.05, 2.8), ATT_TOP)


func _dress_stable() -> void:
	var g: Node3D = Props.group(dress, "Stable", Vector3.ZERO)
	# stall partitions: posts and boards over the collision slabs
	for x: float in [11.0, 16.0, 17.6]:
		Props.block(g, Vector3(x - 0.1, 0, 25.0), Vector3(x + 0.1, 2.0, 25.3), "beam")
		for y: float in [0.3, 0.75, 1.2]:
			Props.block(g, Vector3(x - 0.09, y - 0.12, 22.2), Vector3(x + 0.09, y + 0.12, 25.2), "planks")
	# straw on the floor, mangers, hay bales, tack
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 7
	for p: Vector3 in [Vector3(12.5, 0, 23.6), Vector3(14.0, 0, 24.0), Vector3(19.5, 0, 24.5), Vector3(9.0, 0, 27.0), Vector3(20.0, 0, 31.0)]:
		for k: int in 5:   # loose straw: scattered thin tufts
			Hay.pad(g, p + Vector3(srng.randf_range(-0.9, 0.9), 0.012, srng.randf_range(-0.7, 0.7)),
				Vector3(srng.randf_range(0.3, 0.8), 0.02, srng.randf_range(0.2, 0.5)), "straw_floor", Vector3(0, srng.randf_range(0, 180), 0))
	for x: float in [12.0, 16.8]:
		Props.block(g, Vector3(x - 0.6, 0.5, 22.2), Vector3(x + 0.6, 0.85, 22.6), "planks")
	# T-238 (the owner: "the haystacks feel half baked in the barn"): the pile was one 2 x 0.7 x 2.6 m hay-coloured block
	# and five plain bale boxes stood without colliders in the north door's lane. Now: four bales stacked two high
	# against the north wall (over the StableBales collider), the bale forked open in front of them as a loose heap
	# you wade through (the ground spawn rises out of it; HayPuff6 puffs it), the fork left standing in it, and
	# stalks trodden out toward the door, the stair foot and the stalls. Nothing stands in the lane any more.
	Hay.stack(g, STABLE_BALES.position, STABLE_BALES.end, 2, 21, false)
	Hay.heap(g, Vector3(22.5, 0, 23.72), Vector3(2.0, 0.5, 2.3), 5, Vector3(0.1, 0, -0.4))
	Hay.pitchfork(g, Vector3(23.05, 0.3, 23.2), 170.0, 13.0)
	Hay.scatter(g, Vector3(22.4, 0, 24.6), 1.6, 1.0, 34, 1, 2)
	Hay.scatter(g, Vector3(20.6, 0, 23.6), 1.2, 1.0, 16, 2, 0)   # dragged toward the door
	Hay.scatter(g, Vector3(12.6, 0, 23.8), 1.3, 1.2, 22, 3, 0)   # the horse's stall
	Hay.scatter(g, Vector3(16.8, 0, 23.6), 0.6, 1.2, 12, 4, 0)
	Hay.scatter(g, Vector3(19.3, 0, 28.4), 1.0, 0.8, 18, 6, 0)   # under the bale drop
	# tack rail, saddle blanket, bridle: hung above the Armorer's Bench (T-068), which stands under them
	var wx: float = STB_X0 + 0.15   # the west wall's inner face
	Props.block(g, Vector3(wx, 2.0, 25.5), Vector3(wx + 0.1, 2.1, 27.5), "beam")   # tack rail
	Props.block(g, Vector3(wx + 0.1, 1.8, 25.9), Vector3(wx + 0.45, 2.15, 26.5), "cloth_red")   # saddle blanket
	Props.block(g, Vector3(wx + 0.1, 1.78, 26.8), Vector3(wx + 0.3, 2.1, 27.2), "furniture")    # bridle/strap
	# (T-238: the crate that stood loose by the Tack Room crate spot, without a collider, is gone)
	for lp: Array in [[Vector3(19.0, 4.0, 26.0), STABLE_H - 0.6], [Vector3(19.0, 2.5, 31.5), LOFT_Y], [Vector3(10.0, 2.3, 28.0), LOFT_Y],
			[Vector3(10.0, 5.6, 28.0), STABLE_H - 0.6], [Vector3(20.0, 2.4, 19.0), 3.0]]:
		Props.lantern(g, lp[0], float(lp[1]))
	_dress_hay_stairs(g)
	_dress_loft(g)


## The hayloft stair (T-084): fifteen solid treads with a worn nosing, drawn under the invisible ramp (the ramp runs
## on the nosing line, so a tread's top is never above it), a footboard where the ramp leaves the floor, a closed
## string and boarded planks down the open west side with the store's little door, newel posts and balusters
## between the rail bars, and a wall rail up the east wall.
func _dress_hay_stairs(g: Node3D) -> void:
	var run: float = HSTAIR_Z1 - HSTAIR_Z0
	var tread: float = run / float(HSTAIR_STEPS)
	var riser: float = LOFT_TOP / float(HSTAIR_STEPS)
	for k: int in HSTAIR_STEPS - 1:
		var za: float = HSTAIR_Z0 + tread * float(k + 1)
		var zb: float = za + tread
		var top: float = riser * float(k + 1)
		Props.block(g, Vector3(HSTAIR_X0, 0.0, za), Vector3(HSTAIR_X1, top - 0.045, zb), "beam")
		Props.block(g, Vector3(HSTAIR_X0, top - 0.045, za - 0.025), Vector3(HSTAIR_X1, top, zb + 0.01), "furniture")   # the tread board and its nosing
	Props.block(g, Vector3(HSTAIR_X0, 0.0, HSTAIR_Z0 - 0.02), Vector3(HSTAIR_X1, 0.11, HSTAIR_Z0 + tread), "furniture")   # the footboard
	# the closed string along the open side, the boarding under it, the store's door
	var ang: float = rad_to_deg(atan2(LOFT_TOP, run))
	var mid: Vector3 = Vector3(HSTAIR_X0 - 0.02, LOFT_TOP * 0.5 + 0.12, (HSTAIR_Z0 + HSTAIR_Z1) * 0.5)
	Props.obox(g, mid, Vector3(0.06, 0.34, Vector2(run, LOFT_TOP).length() + 0.3), "beam", Vector3(-ang, 0, 0))
	var zc: float = HSTAIR_Z0 + 0.4
	var pk: int = 0
	while zc < HSTAIR_Z1 - 0.05:
		var zn: float = minf(zc + 0.22, HSTAIR_Z1)
		var h: float = LOFT_TOP * (zc - HSTAIR_Z0) / run - 0.2
		if h > 0.1:
			Props.block(g, Vector3(HSTAIR_X0 - 0.045, 0.0, zc + 0.01), Vector3(HSTAIR_X0 + 0.0, h, zn - 0.01), "planks" if pk % 2 == 0 else "board_wood_v")
		zc = zn
		pk += 1
	Props.block(g, Vector3(HSTAIR_X0 - 0.07, 0.02, 29.6), Vector3(HSTAIR_X0 - 0.04, 1.75, 30.5), "board_wood_v")   # the store's door
	Props.block(g, Vector3(HSTAIR_X0 - 0.09, 0.95, 29.68), Vector3(HSTAIR_X0 - 0.06, 1.02, 29.78), "iron")
	# newels at the foot and the head, balusters between the bars, a wall rail up the east wall
	Props.newel(g, Vector3(HSTAIR_X0 - 0.05, 0.0, HSTAIR_Z0 - 0.02), 1.1)
	Props.newel(g, Vector3(HSTAIR_X0 - 0.05, LOFT_TOP, HSTAIR_Z1 - 0.02), 1.1)
	var n: int = int(run / 0.45)
	for b: int in range(1, n):
		var t: float = float(b) / float(n)
		var bz: float = lerpf(HSTAIR_Z0, HSTAIR_Z1, t)
		var by: float = LOFT_TOP * t
		Props.block(g, Vector3(HSTAIR_X0 - 0.07, by + 0.1, bz - 0.02), Vector3(HSTAIR_X0 - 0.03, by + 0.98, bz + 0.02), "furniture")
	var rail_mid: Vector3 = Vector3(STB_X1 - 0.15 - 0.06, LOFT_TOP * 0.5 + 0.95, (HSTAIR_Z0 + HSTAIR_Z1) * 0.5)
	Props.obox(g, rail_mid, Vector3(0.05, 0.05, Vector2(run, LOFT_TOP).length()), "furniture", Vector3(-ang, 0, 0))
	for bk: int in 4:
		var tz: float = lerpf(HSTAIR_Z0 + 0.6, HSTAIR_Z1 - 0.6, float(bk) / 3.0)
		Props.block(g, Vector3(STB_X1 - 0.15 - 0.08, LOFT_TOP * (tz - HSTAIR_Z0) / run + 0.88, tz - 0.02), Vector3(STB_X1 - 0.15, LOFT_TOP * (tz - HSTAIR_Z0) / run + 0.95, tz + 0.02), "iron")


## The second level (T-084): balusters and newels along the rails (the bars are colliders, these are the turned
## sticks between them), the bale drop's worn boards and its hook, the bale stack and the single bales over their
## colliders, the two crates, the hay chute's trapdoor over the horse's stall with its rope and pulley, a pitchfork
## in the stack, a lantern on a hook by the stair head, tack hanging from the tie beams (a collar, harness, a
## bridle, a bucket), a coil of rope and a few sacks.
func _dress_loft(g: Node3D) -> void:
	var y: float = LOFT_TOP
	# balusters and newels along the edge rails (0.45 m apart, between the collider bars)
	var edges: Array = [[Vector3(LOFT_X1 - 0.05, y, STB_Z0 + 0.3), Vector3(LOFT_X1 - 0.05, y, GAL_Z0 - 0.05)],
		[Vector3(LOFT_X1 - 0.05, y, GAL_Z0 + 0.05), Vector3(LOFT_DROP.x, y, GAL_Z0 + 0.05)], [Vector3(LOFT_DROP.y, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0 + 0.05)],
		[Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, HSTAIR_Z1 - 0.1)]]
	for e: Array in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var cnt: int = maxi(1, int(a.distance_to(b) / 0.45))
		for k: int in range(1, cnt):
			var p: Vector3 = a.lerp(b, float(k) / float(cnt))
			Props.block(g, p + Vector3(-0.02, 0.1, -0.02), p + Vector3(0.02, 0.98, 0.02), "furniture")
	for np: Vector3 in [Vector3(LOFT_X1 - 0.05, y, GAL_Z0), Vector3(LOFT_DROP.x, y, GAL_Z0 + 0.05), Vector3(LOFT_DROP.y, y, GAL_Z0 + 0.05), Vector3(HSTAIR_X0 - 0.05, y, GAL_Z0)]:
		Props.newel(g, np, 1.1)
	# the bale drop: boards worn pale at the lip, the hook on the beam above it, a rope down to it
	Props.block(g, Vector3(LOFT_DROP.x, y + 0.004, GAL_Z0 - 1.4), Vector3(LOFT_DROP.y, y + 0.012, GAL_Z0 + 0.15), "planks", false)
	Props.block(g, Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5 - 0.02, STABLE_H - 1.0, GAL_Z0 - 0.3), Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5 + 0.02, STABLE_H - 0.6, GAL_Z0 - 0.26), "iron")
	Props.cable(g, Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5, STABLE_H - 1.0, GAL_Z0 - 0.28), Vector3((LOFT_DROP.x + LOFT_DROP.y) * 0.5, y + 1.3, GAL_Z0 - 0.2), 0.0, 0.015, 2, "rope")
	# the bale stack in the south-west corner (over the HayBales collider), the single bales (over theirs)
	# T-238: the stack fills its collider now (it drew one course of 15 bales and three on top inside a 0.9 m high
	# 3.2 x 3.2 m collider: an invisible step all round the three). Two full courses laid crosswise, a third started
	# in the corner (LOFT_TOP_BALES, each with its own collider), loose hay at its foot; the cover bales are drawn at
	# their colliders' size (they were 0.9 x 0.45 x 0.5 inside 1.0 x 0.47 x 0.6).
	Hay.stack(g, Vector3(STB_X0 + 0.3, y, 30.5), Vector3(STB_X0 + 3.5, y + 0.9, 33.7), 2, 3)
	var bi: int = 0
	for tb: Array in LOFT_TOP_BALES:
		bi += 1
		Hay.bale(g, tb[0], float(tb[1]), 40 + bi, 1.05, 0.45, 0.52)
	for hb: Array in LOFT_BALES:
		bi += 1
		Hay.bale(g, hb[0], float(hb[1]), 60 + bi, 0.99, 0.47, 0.59)
	Hay.tuft(g, Vector3(STB_X0 + 3.75, y, 31.3), 0.55, 1)
	Hay.tuft(g, Vector3(STB_X0 + 2.2, y, 30.25), 0.6, 2)
	Hay.scatter(g, Vector3(STB_X0 + 3.4, y, 30.6), 1.5, 1.0, 30, 11, 2)
	Hay.scatter(g, Vector3(17.6, y, 30.6), 1.2, 0.5, 14, 12, 0)   # round the gallery's cover bales
	Hay.scatter(g, Vector3(LOFT_X1 - 1.0, y, 25.6), 0.7, 1.8, 18, 13, 0)   # and the rail's
	for cr: Array in LOFT_CRATES:
		Props.crate(g, cr[0], float(cr[1]), float(cr[2]), str(cr[3]))
	# the hay chute: a trapdoor flush in the boards over the horse's stall, its frame, straps and ring, the rope from
	# the pulley on the tie beam, a coil beside it
	var hc: Vector3 = Vector3(13.0, y, 23.6)
	Props.block(g, hc + Vector3(-0.55, 0.0, -0.55), hc + Vector3(0.55, 0.07, 0.55), "beam")
	Props.block(g, hc + Vector3(-0.45, 0.07, -0.45), hc + Vector3(0.45, 0.1, 0.45), "board_wood_v")
	for sz: float in [-0.25, 0.25]:
		Props.block(g, hc + Vector3(-0.47, 0.1, sz - 0.03), hc + Vector3(0.47, 0.115, sz + 0.03), "iron")
	Props.cyl(g, hc + Vector3(0.3, 0.12, 0.0), 0.07, 0.02, "iron")
	Props.cyl(g, Vector3(13.0, STABLE_H - 0.72, 24.5), 0.14, 0.08, "iron", Vector3(0, 0, 90))
	Props.cable(g, Vector3(13.0, STABLE_H - 0.8, 24.5), Vector3(13.0, y + 0.3, 24.3), 0.0, 0.015, 2, "rope")
	Props.rope_coil(g, Vector3(13.9, y, 24.6), 0.3)
	# the pitchfork leaning in the stack, a bucket, sacks
	Hay.pitchfork(g, Vector3(STB_X0 + 3.74, y, 31.0), 90.0, 14.0)   # (T-238: tines on the boards, the handle against the stack; it stood on its handle)
	Props.cyl(g, Vector3(24.6, y + 0.15, 33.3), 0.15, 0.3, "tin")
	Props.sack(g, Vector3(8.6, y, 33.2), 15.0, 0.9)
	Props.sack(g, Vector3(9.3, y, 33.4), -30.0, 0.8)
	Props.sack(g, Vector3(8.9, y + 0.32, 33.3), 60.0, 0.8)
	# the lantern on its hook by the stair head (LoftHookLamp lights it), on a bracket off the tie beam's post line
	Props.block(g, Vector3(21.0, y + 1.9, 30.86), Vector3(21.3, y + 1.95, 30.94), "iron")
	Props.lantern(g, Vector3(21.2, y + 1.55, 30.9), y + 1.95)
	# tack from the tie beam at z 28 over the west block: a horse collar, harness straps, a bridle, a bucket on a rope
	var tb: Node3D = Props.group(g, "LoftTack", Vector3(0, STABLE_H - 0.6, 28.0))
	for cx: float in [7.6, 10.4]:
		Props.cable(tb, Vector3(cx, 0, 0), Vector3(cx, -0.9, 0), 0.0, 0.012, 2, "rope")
	var collar: Node3D = Props.group(tb, "Collar", Vector3(7.6, -1.25, 0))
	for k2: int in 10:
		var a0: float = TAU * float(k2) / 10.0
		var a1: float = TAU * float(k2 + 1) / 10.0
		Props.strut(collar, Vector3(cos(a0) * 0.3, sin(a0) * 0.36, 0), Vector3(cos(a1) * 0.3, sin(a1) * 0.36, 0), 0.09, "leather", true)
	Props.obox(tb, Vector3(10.4, -1.5, 0), Vector3(0.04, 1.2, 0.012), "leather", Vector3(0, 0, 6))
	Props.obox(tb, Vector3(10.55, -1.6, 0.02), Vector3(0.04, 1.0, 0.012), "leather", Vector3(0, 0, -9))
	Props.obox(tb, Vector3(10.47, -2.05, 0.01), Vector3(0.3, 0.03, 0.012), "leather")
	Props.cable(tb, Vector3(12.6, 0, 0), Vector3(12.6, -1.1, 0), 0.0, 0.012, 2, "rope")
	Props.cyl(tb, Vector3(12.6, -1.25, 0), 0.15, 0.3, "tin")
	Props.cable(tb, Vector3(9.0, 0, 0), Vector3(9.0, -0.7, 0), 0.0, 0.012, 2, "rope")
	Props.obox(tb, Vector3(9.0, -0.95, 0), Vector3(0.2, 0.5, 0.03), "leather", Vector3(0, 0, 12))


func _dress_exterior() -> void:
	var g: Node3D = Props.group(dress, "Exterior", Vector3.ZERO)
	# half-timbering on the inn's outer faces (north, west, east)
	for x: float in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0]:
		if absf(x - 7.0) < 1.0 or absf(x - 17.0) < 1.0:
			continue
		Props.block(g, Vector3(x - 0.13, 0, -0.27), Vector3(x + 0.13, ATT_TOP, -0.15), "beam")   # (up the attic storey since T-224)
	for y: float in [0.25, TAP_H, UP_TOP - 0.1, ATT_Y + 0.1, ATT_TOP - 0.1]:
		if y < 1.0:   # the front door (x 19.2..20.8) breaks the north sill beam (T-072)
			Props.block(g, Vector3(-0.27, y - 0.12, -0.27), Vector3(FRONT_DOOR_X - 0.8, y + 0.12, -0.15), "beam")
			Props.block(g, Vector3(FRONT_DOOR_X + 0.8, y - 0.12, -0.27), Vector3(24.27, y + 0.12, -0.15), "beam")
		else:
			Props.block(g, Vector3(-0.27, y - 0.12, -0.27), Vector3(24.27, y + 0.12, -0.15), "beam")
		Props.block(g, Vector3(-0.27, y - 0.12, -0.15), Vector3(-0.15, y + 0.12, 10.15 if y > 7.0 else (16.15 if y > 3.0 else 7.85)), "beam")   # (the Old Cellar's lean-to covers z 7.85+; the attic ends at z 10)
		if y < 1.0:   # the cellar door (z 10.7..12.3) breaks the sill beam
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 10.6), "beam")
			Props.block(g, Vector3(24.15, y - 0.12, 12.4), Vector3(24.27, y + 0.12, 16.15), "beam")
		else:
			Props.block(g, Vector3(24.15, y - 0.12, -0.15), Vector3(24.27, y + 0.12, 16.15 if y < 4.0 else 10.15), "beam")
	for i: int in 6:
		var x0: float = 0.2 + i * 4.0
		Props.obox(g, Vector3(x0 + 1.5, UP_Y + 1.5, -0.22), Vector3(0.18, 3.6, 0.08), "beam", Vector3(0, 0, 40 if i % 2 == 0 else -40))
		Props.obox(g, Vector3(x0 + 1.5, ATT_Y + 1.35, -0.22), Vector3(0.16, 2.9, 0.08), "beam", Vector3(0, 0, -36 if i % 2 == 0 else 36))   # the attic storey's braces (T-224)
	_half_timber_sides(g)
	# pitched roofs with snow (inn, stair tower, stable) and the chimney stack (T-224: the inn's roof sits on the attic now;
	# the stair tower's flat roof below the attic's south wall gets its snow)
	_gable(g, Vector3(-0.6, ATT_TOP + 0.2, -0.8), Vector3(24.6, ATT_TOP + 0.2, 10.8), 3.4)
	_gable(g, Vector3(STAIR_X1 + 0.1, TAP_H + 0.3, 9.8), Vector3(24.6, TAP_H + 0.3, 16.6), 1.0)
	_gable(g, Vector3(STB_X0 - 0.4, STABLE_H + 0.2, STB_Z0 - 0.4), Vector3(STB_X1 + 0.6, STABLE_H + 0.2, STB_Z1 + 0.4), 3.2)
	Props.block(g, Vector3(-0.35, UP_TOP + 0.2, 10.15), Vector3(STAIR_X1 + 0.35, UP_TOP + 0.3, 16.35), "snow", false)
	Props.block(g, Vector3(11.3, ATT_TOP, 0.0), Vector3(12.7, 14.4, 1.0), "stone")
	Props.block(g, Vector3(11.2, 14.3, -0.1), Vector3(12.8, 14.5, 1.1), "snow")
	Props.smoke(g, Vector3(12.0, 14.6, 0.5), 0.3, 1.2, 14)
	# porch posts' snow caps and drifts against the walls
	for d: Array in [[Vector3(-1.2, 0, 5.4), Vector3(2.4, 0.9, 4.4)], [Vector3(25.4, 0, 5.3), Vector3(2.0, 0.8, 3.0)], [Vector3(12, 0, -1.0), Vector3(6, 0.7, 1.8)],   # (clear of the lean-to and the light wells, T-051)
			[Vector3(4, 0, 17.5), Vector3(5, 1.0, 2.2)], [Vector3(STB_X1 + 1.3, 0.25, 27), Vector3(2.2, 0.8, 8)], [Vector3(12.2, 0, 35.4), Vector3(5.6, 1.0, 2.2)],   # kept above the cellar ceiling; clear of the yard door (T-072)
			[Vector3(STB_X0 - 1.4, 0, 28), Vector3(2.4, 1.0, 9)], [Vector3(-3, 0, -6), Vector3(5, 0.6, 4)], [Vector3(32, 0, 7), Vector3(6, 0.8, 5)]]:
		Props.snow_drift(g, d[0], d[1])
	Props.block(g, Vector3(1.5, UP_Y, -2.4), Vector3(6.5, UP_Y + 0.08, -0.15), "snow", false)
	Props.block(g, Vector3(17.5, UP_Y, -2.4), Vector3(22.5, UP_Y + 0.08, -0.15), "snow", false)
	# the crossroads: two trodden tracks, a signpost, fences, dead trees
	Props.block(g, Vector3(-45, 0.0, -9.5), Vector3(70, 0.015, -6.0), "snow_trodden", false)
	Props.block(g, Vector3(-12.5, 0.0, -40), Vector3(-9.0, 0.015, 75), "snow_trodden", false)
	Props.signpost(g, Vector3(-8.2, 0, -10.6), [["KALTENBRUNN  9 km", 90.0], ["WILCZA GÓRA  6 km", 160.0], ["BRESLAU  74 km", -90.0], ["GASTHAUS ZUM KREUZWEG", 20.0]])
	# (the field's fences are the grounds' since T-080: OUT_FENCES, real ones, drawn by _dress_grounds)
	for t: Array in OUT_DEAD_TREES:   # (the carters' road's five, seeds 131..135, are drawn with the road)
		if int(t[1]) < 131 or int(t[1]) > 135:
			Props.dead_tree(g, t[0], int(t[1]), float(t[2]))
	# a dead horse cart by the road and a field telephone pole line
	Props.cart(g, Vector3(-17, 0, -3), 20.0)
	for i: int in 6:
		var pp: Vector3 = Vector3(-30 + i * 14.0, 0, -15.5)
		Props.cyl(g, pp + Vector3(0, 3.5, 0), 0.12, 7.0, "beam", Vector3(0, 0, (i % 2) * 4.0 - 2.0))
		Props.block(g, pp + Vector3(-0.8, 6.4, -0.05), pp + Vector3(0.8, 6.5, 0.05), "beam")
	# weather: snow over the open ground, dust motes in the warm rooms
	var snow: Node3D = Node3D.new()
	snow.set_script(load("res://gravelight/world/snowfall.gd"))
	snow.name = "Snowfall"
	snow.set("areas", [AABB(Vector3(-40, 0, -40), Vector3(105, 22, 37)), AABB(Vector3(-40, 0, -3), Vector3(37, 22, 43)),
		AABB(Vector3(27, 0, -3), Vector3(38, 22, 43)), AABB(Vector3(-40, 0, 37), Vector3(105, 22, 33)),
		AABB(Vector3(0, 0, 16.6), Vector3(17.6, 14, 5.2)), AABB(Vector3(2, 0, 34), Vector3(32, 16, 14))] as Array[AABB])
	snow.set("density", 0.4)
	map_root.add_child(snow)
	var motes: Node3D = Node3D.new()
	motes.set_script(load("res://gravelight/world/snowfall.gd"))
	motes.name = "DustMotes"
	motes.set("areas", [AABB(Vector3(1, 0.3, 1), Vector3(22, 3.0, 14)), AABB(Vector3(STB_X0 + 0.5, 0.3, 23), Vector3(STB_X1 - STB_X0 - 1.0, 6, 10)),
		AABB(Vector3(0.5, ATT_Y + 0.2, 0.5), Vector3(23, 2.5, 9))] as Array[AABB])   # (the attic's dust, T-224)
	motes.set("motes", true)
	map_root.add_child(motes)


## T-093: the half-timbering on the inn's west and east faces (only the north had its posts and braces): studs between
## the sill, the storey rail and the wall plate, clear of the windows, the cellar door and the Old Cellar's lean-to,
## and K-braces in the upper storey, dark oak over the plaster (the east face south of z 10 is inside the cellar's
## stair hall, so it gets none). Dressing only (0.12 m proud of the wall, like the
## north face's).
func _half_timber_sides(g: Node3D) -> void:
	# [outer face x, outward sign, ground-floor stud z list, upper-storey stud z list, upper storey's z extent]
	for side: Array in [[-0.15, -1.0, [2.5, 4.8, 7.2], [0.0, 2.5, 5.0, 7.5, 10.0, 13.0, 16.0], 16.0],
			[24.15, 1.0, [2.5, 5.0, 6.95, 9.05], [0.0, 2.5, 5.0, 7.5, 10.0], 10.0]]:
		var fx: float = float(side[0])
		var o: float = float(side[1])
		var x0: float = fx if o > 0 else fx - 0.12
		var x1: float = fx + 0.12 if o > 0 else fx
		for z: float in side[2]:
			Props.block(g, Vector3(x0, 0.0, z - 0.12), Vector3(x1, TAP_H, z + 0.12), "beam")
		var studs: Array = side[3]
		for k: int in studs.size():
			var z2: float = float(studs[k])
			Props.block(g, Vector3(x0, TAP_H, z2 - 0.12), Vector3(x1, UP_TOP, z2 + 0.12), "beam")
			if k < studs.size() - 1 and float(studs[k + 1]) <= float(side[4]):
				var zc: float = (z2 + float(studs[k + 1])) * 0.5
				Props.obox(g, Vector3((x0 + x1) * 0.5, UP_Y + 1.4, zc), Vector3(0.08, 3.4, 0.18), "beam", Vector3(38.0 if k % 2 == 0 else -38.0, 0, 0))


## The grounds' drawing (T-080; colliders: build_grounds): the boundary fences and the spruce tree line beyond them
## (the four roads run on into the dark between the trees), the solid props, the lamp posts and lanterns, drifts.
func _dress_grounds() -> void:
	var g: Node3D = Props.group(dress, "Grounds", Vector3.ZERO)
	var segs: Array = _cut_pockets(OUT_FENCES)   # (the edge fences break at the spawn pockets, T-084)
	for i: int in segs.size():
		var f: Array = segs[i]
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		Props.fence(g, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 30 + i, not _on_edge(a, b))   # T-125: the roadside fence blocks to 2.3 m
	# a rail down in the snow at each broken bay of the edge fence
	var pr: RandomNumberGenerator = RandomNumberGenerator.new()
	pr.seed = 84
	for r: Rect2 in edge_pockets():
		var c: Vector2 = r.get_center()
		var side: int = _pocket_side(Vector3(c.x, 0, c.y))
		var on_line: Vector2 = Vector2(c.x, OUT_MIN.y if side == 0 else OUT_MAX.y) if side < 2 else Vector2(OUT_MIN.x if side == 2 else OUT_MAX.x, c.y)
		var inward: Vector2 = Vector2(0, 1) if side == 0 else (Vector2(0, -1) if side == 1 else (Vector2(1, 0) if side == 2 else Vector2(-1, 0)))
		var at: Vector2 = on_line + inward * 0.9
		Props.obox(g, Vector3(at.x, 0.12, at.y), Vector3(1.6, 0.06, 0.1) if side < 2 else Vector3(0.1, 0.06, 1.6), "beam", Vector3(0, pr.randf_range(-25, 25), pr.randf_range(-6, 6)))
	_tree_line(g)
	# the woodshed by the west road: plank walls, a lean-to roof falling to the south, a door, logs stacked on its
	# east side under the eave, snow on the roof and drifted against the north wall
	# T-136: the savings bank now (build_bank_shed: the walls; BankBranch: the counter and the teller)
	var sh: Node3D = Props.group(g, "Woodshed", Vector3(-4.5, 0, 58.5))
	for bx: float in [-2.45, -1.0, 1.0, 2.45]:
		Props.block(sh, Vector3(bx - 0.08, 0, -1.8), Vector3(bx + 0.08, 2.4, -1.72), "beam")
	Props.obox(sh, Vector3(0, 2.55, 0.0), Vector3(5.5, 0.14, 4.3), "roof", Vector3(-9, 0, 0))
	Props.obox(sh, Vector3(0, 2.66, -0.05), Vector3(5.6, 0.1, 4.1), "snow", Vector3(-9, 0, 0))
	Props.block(sh, Vector3(-2.36, 2.37, -1.61), Vector3(2.36, 2.42, 1.61), "planks")             # the ceiling boards
	Props.block(sh, Vector3(-0.93, 0, -1.82), Vector3(-0.85, 2.12, -1.72), "beam")               # the door frame
	Props.block(sh, Vector3(0.85, 0, -1.82), Vector3(0.93, 2.12, -1.72), "beam")
	Props.block(sh, Vector3(-0.93, 2.05, -1.82), Vector3(0.93, 2.13, -1.72), "beam")
	Props.block(sh, Vector3(1.3, 1.2, -1.78), Vector3(2.1, 1.75, -1.75), "bulb_warm")           # the window, lit
	Props.block(sh, Vector3(1.28, 1.18, -1.8), Vector3(2.12, 1.22, -1.76), "beam")
	Props.block(sh, Vector3(1.28, 1.73, -1.8), Vector3(2.12, 1.77, -1.76), "beam")
	Props.block(sh, Vector3(1.68, 1.2, -1.8), Vector3(1.72, 1.75, -1.77), "beam")
	Props.block(sh, Vector3(-2.2, 2.14, -1.82), Vector3(-1.1, 2.36, -1.78), "paint_green")     # the signboard
	var sign: Label3D = Label3D.new()
	sign.text = "DARLEHENSKASSE"
	sign.font_size = 34
	sign.pixel_size = 0.0035
	sign.modulate = Color(0.92, 0.84, 0.6)
	sign.position = Vector3(-1.65, 2.25, -1.84)
	sign.rotation.y = PI
	SurfaceText.apply(sign)   # T-247: painted on the board, lit by the yard
	sh.add_child(sign)
	# (T-247: the small print plate under the sign is gone; the cream panel it was on stays)
	Props.block(sh, Vector3(-2.02, 1.38, -1.8), Vector3(-1.18, 1.62, -1.76), "paint_cream")
	Props.snow_drift(sh, Vector3(1.8, 0, -2.2), Vector3(2.2, 0.6, 1.2))
	for row: int in 3:
		for k: int in 5:
			Props.cyl(sh, Vector3(2.75, 0.17 + row * 0.3, -1.2 + k * 0.6), 0.15, 0.9, "pine" if (row + k) % 2 == 0 else "beam", Vector3(0, 0, 90))
	Props.wall_lamp(sh, Vector3(1.5, 2.05, -1.75), 0.0)
	# the hay rick in the north field: a round stack, its thatched cap, snow on top
	Props.cyl(g, Vector3(22.0, 1.0, -23.5), 1.7, 2.0, "hay")
	Props.cone(g, Vector3(22.0, 2.55, -23.5), 1.85, 1.1, "hay")
	Props._noshadow(Props.ball(g, Vector3(22.0, 2.75, -23.5), Vector3(2.4, 0.7, 2.4), "snow"))
	Props.cyl(g, Vector3(22.0, 3.3, -23.5), 0.05, 1.0, "beam")
	# the wayside shrine at the crossroads: a crucifix under a little roof on a post, a wreath, snow on the roof
	var wr: Node3D = Props.group(g, "Shrine", Vector3(-15.4, 0, -11.4), 35.0)
	Props.block(wr, Vector3(-0.1, 0, -0.1), Vector3(0.1, 2.0, 0.1), "beam")
	Props.block(wr, Vector3(-0.32, 1.25, -0.22), Vector3(0.32, 2.0, 0.12), "furniture")
	Props.block(wr, Vector3(-0.025, 1.4, -0.25), Vector3(0.025, 1.85, -0.22), "beam")
	Props.block(wr, Vector3(-0.13, 1.68, -0.25), Vector3(0.13, 1.72, -0.22), "beam")
	for sx: float in [-1.0, 1.0]:
		Props.obox(wr, Vector3(sx * 0.2, 2.13, -0.05), Vector3(0.46, 0.05, 0.6), "roof", Vector3(0, 0, -32 * sx))
		Props.obox(wr, Vector3(sx * 0.2, 2.17, -0.05), Vector3(0.44, 0.04, 0.58), "snow", Vector3(0, 0, -32 * sx))
	Props.cyl(wr, Vector3(0, 1.2, -0.13), 0.13, 0.04, "pine", Vector3(90, 0, 0))
	# the hay wagon left on the west road's verge
	Props.cart(g, Vector3(-15.6, 0, 22.0), 8.0)
	Props._noshadow(Props.ball(g, Vector3(-15.6, 1.15, 22.0), Vector3(1.6, 0.4, 2.4), "snow"))
	# the abandoned machine-gun nest in the north field: an L of sandbags, an upturned helmet, ammunition tins
	Props.sandbags(g, Vector3(30.0, 0, -22.0), Vector3(34.5, 0, -22.0), 3)
	Props.sandbags(g, Vector3(34.5, 0, -22.0), Vector3(34.5, 0, -18.5), 3)
	PropsStory.helmet(g, Vector3(32.0, 0.0, -21.2), 40.0, true)
	for ap: Vector3 in [Vector3(33.4, 0.0, -21.1), Vector3(33.7, 0.0, -20.7)]:
		Props.block(g, ap + Vector3(-0.14, 0, -0.08), ap + Vector3(0.14, 0.18, 0.08), "olive_steel")
	Props._noshadow(Props.ball(g, Vector3(32.2, 0.85, -22.0), Vector3(4.0, 0.25, 0.8), "snow"))
	# GRAVELIGHT ONE's port engine, torn off its mount and thrown into the north field (T-211: the C-47's own piece,
	# C47Wreck draws it): the scorched snow round it and its smoke; a burnt-out car on the east road's verge
	Props._noshadow(Props.cyl(g, Vector3(34.5, 0.01, -13.2), 2.2, 0.02, "char"))
	var en: Node3D = Props.group(g, "EngineSmoke", Vector3(34.5, 0, -13.2), 30.0)
	Props.smoke(en, Vector3(0, 1.3, 0.2), 0.3, 1.2, 8)
	LandscapeProps.burnt_car(g, Vector3(49.0, -0.1, -14.5), 100.0, -6.0)
	for dp: Vector3 in [Vector3(46.6, 0, 44.3), Vector3(47.4, 0, 44.25), Vector3(47.0, 0, 43.6)]:
		Props.oil_drum(g, dp, "rust")
	Props.oil_drum(g, Vector3(48.3, 0, 45.0), "rust", true)
	# the road exits: a spruce felled across the north road, striped barriers (STRASSE GESPERRT) east and south, a
	# barrier boom on the west road
	var fs: Node3D = Props.group(g, "FelledSpruce", Vector3(-10.75, 0, -29.0), 4.0)
	Props.cyl(fs, Vector3(0, 0.35, 0), 0.35, 6.5, "beam", Vector3(0, 0, 90))
	Props._noshadow(Props.ball(fs, Vector3(0, 0.7, 0), Vector3(6.4, 0.25, 0.6), "snow"))
	for k2: int in 7:
		Props.obox(fs, Vector3(-2.8 + k2 * 0.9, 0.5, 0.35 * (1.0 if k2 % 2 == 0 else -1.0)), Vector3(0.06, 0.06, 1.4), "pine", Vector3(20, 25 * (k2 % 3 - 1), 0))
	Props.cyl(fs, Vector3(3.4, 0.4, 0), 0.5, 0.3, "pine", Vector3(0, 0, 90))
	for br: Array in [[Vector3(59.0, 0, -7.75), 90.0, 4.4], [Vector3(37.0, 0, 63.0), 0.0, 5.0], [Vector3(-10.75, 0, 63.0), 0.0, 4.4]]:
		_sawhorse(g, br[0], float(br[1]), float(br[2]))
	var bw: Node3D = Props.group(g, "BarrierBoom", Vector3(-19.2, 0, -7.75), 90.0)
	for sx2: float in [-2.2, 2.2]:
		Props.block(bw, Vector3(sx2 - 0.1, 0, -0.1), Vector3(sx2 + 0.1, 1.1, 0.1), "beam")
	for k3: int in 6:
		Props.block(bw, Vector3(-2.3 + k3 * 0.766, 0.92, -0.06), Vector3(-2.3 + (k3 + 1) * 0.766, 1.04, 0.06), "red_paint" if k3 % 2 == 0 else "paint_cream")
	# lamp posts: an oil lantern at the crossroads by the inn's west corner, one on the east road past the crash field
	for lp: Vector3 in [Vector3(-7.6, 0, -4.6), Vector3(37.0, 0, -10.8)]:
		Props.cyl(g, lp + Vector3(0, 1.6, 0), 0.08, 3.2, "beam")
		Props.block(g, lp + Vector3(-0.05, 3.0, -0.05), lp + Vector3(0.75, 3.1, 0.05), "beam")
		Props.lantern(g, lp + Vector3(0.65, 2.55, 0), 3.0)
	# the porch lantern over the front door (under the east porch roof)
	Props.lantern(g, Vector3(21.2, 2.75, -1.9), TAP_H)
	# drifts along the outer fences and in the field
	for d: Array in [[Vector3(-18.5, 0, 6), Vector3(2.4, 0.8, 9)], [Vector3(-18.6, 0, 40), Vector3(2.2, 0.7, 12)], [Vector3(58.6, 0, 30), Vector3(2.4, 0.8, 14)],
			[Vector3(20, 0, 62.6), Vector3(14, 0.8, 2.4)], [Vector3(30, 0, -28.6), Vector3(16, 0.7, 2.2)], [Vector3(-4, 0, -28.6), Vector3(8, 0.6, 2.0)],
			[Vector3(46, 0, 58), Vector3(6, 0.6, 3.0)], [Vector3(-10.75, 0, 63.6), Vector3(5.0, 0.9, 1.6)]]:
		Props.snow_drift(g, d[0], d[1])


## Snow-laden spruces in two ragged rows just beyond the edge (Landscape's pine mesh with the near-forest shader),
## leaving the four roads open, and a few dead trees among them. Nothing collides: the edge wall is inside them.
func _tree_line(g: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	var xf: Array[Transform3D] = []
	var gaps: Array = [Rect2(-15.0, -45.0, 8.5, 20.0), Rect2(-15.0, 60.0, 8.5, 20.0), Rect2(31.5, 60.0, 11.0, 20.0),
		Rect2(-40.0, -11.5, 25.0, 7.5), Rect2(55.0, -11.5, 25.0, 7.5)]
	for pk: Rect2 in edge_pockets():   # no trunk in a spawn pocket (T-084): the zombies walk in between the trees
		gaps.append(pk.grow(0.9))
	var edges: Array = [[Vector2(OUT_MIN.x, OUT_MIN.y), Vector2(OUT_MAX.x, OUT_MIN.y), Vector2(0, -1)], [Vector2(OUT_MIN.x, OUT_MAX.y), Vector2(OUT_MAX.x, OUT_MAX.y), Vector2(0, 1)],
		[Vector2(OUT_MIN.x, OUT_MIN.y), Vector2(OUT_MIN.x, OUT_MAX.y), Vector2(-1, 0)], [Vector2(OUT_MAX.x, OUT_MIN.y), Vector2(OUT_MAX.x, OUT_MAX.y), Vector2(1, 0)]]
	for e: Array in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var out: Vector2 = e[2]
		var length: float = a.distance_to(b)
		for row: int in 2:
			var t: float = rng.randf_range(0.0, 2.0)
			while t < length + 4.0:
				var p: Vector2 = a + (b - a).normalized() * (t - 2.0) + out * (rng.randf_range(2.2, 4.5) + row * 3.6)
				var skip: bool = false
				for r: Rect2 in gaps:
					if r.has_point(p):
						skip = true
				if not skip:
					if rng.randf() < 0.12:
						Props.dead_tree(g, Vector3(p.x, 0, p.y), 2000 + xf.size(), rng.randf_range(6.0, 9.0))
					else:
						var hgt: float = rng.randf_range(8.0, 14.0) * (1.0 if row == 0 else 1.15)
						var sc: Vector3 = Vector3(hgt * rng.randf_range(0.36, 0.46), hgt, hgt * rng.randf_range(0.36, 0.46))
						xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), Vector3(p.x, -0.3, p.y)))
				t += rng.randf_range(2.6, 4.2)
	# T-093: the scripted spruces (and a birch here and there) instead of the cone pines, built at load time by a
	# NatureRows node from these transforms; bare bushes and boulders between the rows (the same RNG draws as
	# before for the trees, so the line is where it was)
	var rows: NatureRows = NatureRows.new()
	rows.name = "EdgeTrees"
	var urng: RandomNumberGenerator = RandomNumberGenerator.new()
	urng.seed = 2084
	for x0: Transform3D in xf:
		var ux: Transform3D = Landscape.uniform_tree_xform(x0)
		if Landscape.is_birch(x0.origin):
			rows.birches.append(ux)
		else:
			rows.spruces.append(ux)
		if urng.randf() < 0.45:   # a bush or a rock beside it, on the field side
			var off: Vector3 = Vector3(urng.randf_range(-1.6, 1.6), 0.0, urng.randf_range(-1.6, 1.6))
			var bp: Vector3 = Vector3(x0.origin.x, 0.0, x0.origin.z) + off
			if _in_grounds(bp, -0.9):
				continue   # never inside the edge
			var s: float = urng.randf_range(0.8, 1.5)
			if urng.randf() < 0.7:
				rows.bushes.append(Transform3D(Basis(Vector3.UP, urng.randf() * TAU).scaled(Vector3(s, s, s)), bp - Vector3(0, 0.05, 0)))
			else:
				rows.rocks.append(Transform3D(Basis(Vector3.UP, urng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), bp - Vector3(0, 0.2, 0)))
	g.add_child(rows)
	print("grounds: %d edge spruces" % xf.size())


## A road-closed sawhorse: two splayed trestles and a striped board, "STRASSE GESPERRT" on it. yaw: the board's
## line (0 = along X).
func _sawhorse(parent: Node3D, pos: Vector3, yaw: float, width: float) -> void:
	var s: Node3D = Props.group(parent, "Sawhorse", pos, yaw)
	for sx: float in [-width * 0.5 + 0.2, width * 0.5 - 0.2]:
		for lz: float in [-1.0, 1.0]:
			Props.obox(s, Vector3(sx, 0.45, lz * 0.18), Vector3(0.07, 0.95, 0.07), "beam", Vector3(lz * 20.0, 0, 0))
	var n: int = 6
	for k: int in n:
		Props.block(s, Vector3(-width * 0.5 + k * width / n, 0.78, -0.03), Vector3(-width * 0.5 + (k + 1) * width / n, 0.98, 0.03), "red_paint" if k % 2 == 0 else "paint_cream")
	var l: Label3D = Label3D.new()
	l.text = "STRASSE GESPERRT"
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color(0.1, 0.08, 0.07)
	l.position = Vector3(0, 0.6, -0.05)
	l.rotation.y = PI
	SurfaceText.apply(l)   # T-247
	s.add_child(l)
	Props._noshadow(Props.ball(s, Vector3(0, 0.98, 0), Vector3(width, 0.08, 0.12), "snow"))


## The carters' road behind the stable's great doors (the campaign exfil, T-033: the doors fall outward at
## round 10 and the squad walks out; the Map 0 -> Map 1 cutscene looks down this road). Cutscene-only, so all of
## it is dressing: a trodden track south through a gap in the yard fence, bending east toward Kaltenbrunn, with
## gateposts and a signpost at the gap, drifts and dead trees (the land past the slab's edge at z 75 / x 70 is the
## Landscape node's terrain, T-052). Cheap: ~40 primitives.
func _dress_carters_road() -> void:
	var g: Node3D = Props.group(dress, "CartersRoad", Vector3.ZERO)
	# the track: out of the doorway, through the fence gap, then a bend to the south-east
	Props.block(g, Vector3(16.0, 0.0, 34.2), Vector3(20.2, 0.018, 41.5), "snow_trodden", false)
	Props.block(g, Vector3(16.3, 0.0, 41.0), Vector3(20.5, 0.018, 50.0), "snow_trodden", false)
	Props.obox(g, Vector3(23.5, 0.009, 54.0), Vector3(4.4, 0.018, 12.0), "snow_trodden", Vector3(0, 40, 0))
	Props.obox(g, Vector3(32.0, 0.009, 60.5), Vector3(4.6, 0.018, 16.0), "snow_trodden", Vector3(0, 55, 0))
	Props.obox(g, Vector3(45.0, 0.009, 68.0), Vector3(5.0, 0.018, 22.0), "snow_trodden", Vector3(0, 68, 0))
	# ruts and a cart's furrow where the doors land
	for dx: float in [-0.9, 0.9]:
		Props.block(g, Vector3(18.0 + dx - 0.08, 0.012, 34.3), Vector3(18.0 + dx + 0.08, 0.026, 47.7), "dirt", false)
	# gateposts at the fence gap, a signpost beside them, a lantern post that has gone out
	for gx: float in [15.8, 20.2]:
		Props.block(g, Vector3(gx - 0.16, 0, 47.84), Vector3(gx + 0.16, 2.3, 48.16), "beam")
		Props.block(g, Vector3(gx - 0.22, 2.3, 47.78), Vector3(gx + 0.22, 2.45, 48.22), "snow", false)
	Props.signpost(g, Vector3(22.9, 0, 49.6), [["KALTENBRUNN  9 km", 120.0], ["WILCZA GÓRA  6 km", -150.0], ["GASTHAUS ZUM KREUZWEG", 0.0]])
	# drifts along the stable's south wall and the fence, a broken cart wheel in the snow
	# (T-238: the wall's drift lay under the Thompson's chalk, where you stand to buy it, and the yard's lay across its
	# open south-east quarter; they are against the wall east of the chalk and against the fence now. The wheel stood
	# on its rim in the open, leaning on nothing; it leans on the woodpile.)
	Props.snow_drift(g, Vector3(24.35, 0, 35.0), Vector3(2.5, 0.8, 1.5))
	Props.snow_drift(g, Vector3(8, 0, 49.2), Vector3(10, 0.8, 2.4))
	Props.snow_drift(g, Vector3(29, 0, 49.0), Vector3(8, 0.9, 2.2))
	Props.snow_drift(g, Vector3(25.0, 0, 47.35), Vector3(4.6, 0.6, 1.5))
	Props.cyl(g, Vector3(14.7, 0.54, 35.52), 0.55, 0.08, "beam", Vector3(78, 0, 0))
	# dead trees along the road and the horizon's rises (half-buried domes of snow past the fog)
	Props.dead_tree(g, Vector3(31, 0, 52), 131, 7.0)
	Props.dead_tree(g, Vector3(12, 0, 55), 132, 8.5)
	Props.dead_tree(g, Vector3(38, 0, 52), 133, 6.5)
	Props.dead_tree(g, Vector3(22, 0, 66), 134, 9.0)
	Props.dead_tree(g, Vector3(52, 0, 60), 135, 7.5)
	# (the horizon's rises that used to hide the slab's edge here are now the Landscape's terrain, T-052)


## The Carters' Yard: the drawn fences over the colliders, the barred gate, the well with its windlass, the
## woodpile, the snowed cart and trough, a lit lantern on the gatepost, a lamp over the yard door, paths, drifts.
func _dress_yard() -> void:
	var g: Node3D = Props.group(dress, "Yard", Vector3.ZERO)
	_dress_tower(g)
	Props.fence(g, Vector3(2, 0, 34), Vector3(2, 0, 40.2), 11, true)
	Props.fence(g, Vector3(2, 0, 41.8), Vector3(2, 0, 48), 12, true)
	Props.fence(g, Vector3(34, 0, 34), Vector3(34, 0, 40.2), 13, true)
	Props.fence(g, Vector3(34, 0, 41.8), Vector3(34, 0, 48), 14, true)
	Props.fence(g, Vector3(2, 0, 48), Vector3(8.2, 0, 48), 15, true)
	Props.fence(g, Vector3(9.8, 0, 48), Vector3(15.8, 0, 48), 16, true)
	Props.fence(g, Vector3(20.2, 0, 48), Vector3(26.2, 0, 48), 17, true)
	Props.fence(g, Vector3(27.8, 0, 48), Vector3(34, 0, 48), 18, true)
	Props.fence(g, Vector3(STB_X1 + 0.2, 0, 34), Vector3(34, 0, 34), 19, true)
	Props.fence(g, Vector3(2, 0, 34), Vector3(STB_X0 - 0.2, 0, 34), 20, true)
	# the fence gaps: a post either side and a snow-capped sill rail (the barricades hang in them)
	for gp: Array in [[Vector3(2, 0, 40.2), Vector3(2, 0, 41.8)], [Vector3(34, 0, 40.2), Vector3(34, 0, 41.8)],
			[Vector3(8.2, 0, 48), Vector3(9.8, 0, 48)], [Vector3(26.2, 0, 48), Vector3(27.8, 0, 48)]]:
		for e: Vector3 in [gp[0], gp[1]]:
			Props.block(g, e + Vector3(-0.1, 0, -0.1), e + Vector3(0.1, 2.4, 0.1), "beam")
		var lo: Vector3 = gp[0]
		var hi: Vector3 = gp[1]
		Props.block(g, Vector3(minf(lo.x, hi.x) - 0.08, WIN_SILL - 0.1, minf(lo.z, hi.z) - 0.08), Vector3(maxf(lo.x, hi.x) + 0.08, WIN_SILL, maxf(lo.z, hi.z) + 0.08), "beam")
		# T-125: the lintel over the gap, where the YardTop collider is (it was invisible)
		Props.block(g, Vector3(minf(lo.x, hi.x) - 0.08, WIN_TOP, minf(lo.z, hi.z) - 0.08), Vector3(maxf(lo.x, hi.x) + 0.08, 2.3, maxf(lo.z, hi.z) + 0.08), "beam")
	# (the gate's two leaves and their chain are Door_Gate's own since T-080: GateDoor draws and swings them)
	# the well: a stone ring, two posts, a windlass and a bucket; the crate spot's lantern stake stands beside it
	Props.cyl(g, Vector3(10.0, 0.5, 42.0), 1.05, 1.0, "stone")
	Props.cyl(g, Vector3(10.0, 1.02, 42.0), 1.1, 0.06, "snow")
	Props._noshadow(Props.cyl(g, Vector3(10.0, 0.6, 42.0), 0.78, 0.9, "char"))
	for px: float in [9.1, 10.9]:
		Props.block(g, Vector3(px - 0.08, 1.0, 41.92), Vector3(px + 0.08, 2.3, 42.08), "beam")
	Props.block(g, Vector3(8.9, 2.3, 41.6), Vector3(11.1, 2.42, 42.4), "planks")
	Props.cyl(g, Vector3(10.0, 2.0, 42.0), 0.09, 1.9, "beam", Vector3(0, 0, 90))
	Props.cable(g, Vector3(10.0, 2.0, 42.0), Vector3(10.0, 1.1, 42.0), 0.0, 0.015, 2, "rope")
	Props.cyl(g, Vector3(10.0, 1.2, 42.0), 0.16, 0.24, "tin")
	# the woodpile: stacked split logs against the stable wall, an axe in the block
	var wr: RandomNumberGenerator = RandomNumberGenerator.new()
	wr.seed = 44
	for row: int in 4:
		for k: int in 6:
			Props.cyl(g, Vector3(13.55 + k * 0.42, 0.18 + row * 0.3, 34.75), 0.15, 1.1, "pine" if (row + k) % 2 == 0 else "beam", Vector3(90, 0, wr.randf_range(-6, 6)))
	# (T-238: the chopping block stands in the corner west of the yard door now, against the stable wall; it stood, with
	# no collider, on the edge of the trodden path two metres out of the door)
	_lib("stump_chopping", Vector3(5.6, 0.0, 34.85), 30.0, Vector3(0.45, 1.0, 0.42))
	_lib("axe_wood", Vector3(5.62, 0.5, 34.85), 20.0, Vector3.ONE, false, Vector3(0, 0, -28))
	# the snowed cart and the trough
	Props.cart(g, Vector3(28.3, 0, 38.1), 100.0)
	Props._noshadow(Props.ball(g, Vector3(28.3, 1.2, 38.1), Vector3(2.4, 0.5, 1.6), "snow"))
	Props.block(g, Vector3(30.5, 0, 44.0), Vector3(33.5, 0.7, 45.0), "planks")
	Props.block(g, Vector3(30.6, 0.55, 44.1), Vector3(33.4, 0.62, 44.9), "snow")
	# paths, drifts, a dropped sledge
	Props.block(g, Vector3(7.2, 0.0, 34.2), Vector3(9.0, 0.015, 48.0), "snow_trodden", false)
	Props.block(g, Vector3(7.2, 0.0, 41.3), Vector3(16.0, 0.015, 42.7), "snow_trodden", false)
	Props.snow_drift(g, Vector3(3.2, 0, 36.5), Vector3(2.4, 0.9, 4.0))
	Props.snow_drift(g, Vector3(32.6, 0, 36.0), Vector3(2.6, 0.8, 3.0))
	Props.snow_drift(g, Vector3(4.6, 0, 46.2), Vector3(3.6, 0.7, 2.6))
	# the sledge, pulled up along the south fence east of the gate (T-238: it lay across the yard's open middle, where
	# the horse rides now)
	Props.block(g, Vector3(21.6, 0.05, 46.75), Vector3(23.8, 0.12, 47.65), "planks")
	Props.block(g, Vector3(21.6, 0.0, 46.7), Vector3(23.8, 0.08, 46.8), "iron")
	Props.block(g, Vector3(21.6, 0.0, 47.6), Vector3(23.8, 0.08, 47.7), "iron")
	# lights: a lantern on the gatepost, a lamp over the yard door, the stable's south-wall lamp by the Thompson
	Props.block(g, Vector3(20.36, 1.9, 47.9), Vector3(20.72, 2.3, 48.1), "lantern_glass")
	_lamp("GateLantern", Vector3(20.5, 2.1, 47.4), Color(1.0, 0.62, 0.3), 6.0, 15.0, false, true, 0.25)
	Props.wall_lamp(g, Vector3(8.0, 2.75, 34.2), 180.0)
	_lamp("YardDoorLamp", Vector3(8.0, 2.6, 34.9), Color(1.0, 0.62, 0.32), 7.5, 16.0, true, true, 0.15)
	Props.wall_lamp(g, Vector3(19.2, 2.75, 34.2), 180.0)   # (west of the hoist ledge over the Thompson since T-084)
	_lamp("YardWallLamp", Vector3(19.2, 2.6, 34.9), Color(1.0, 0.62, 0.32), 6.5, 15.0, false, true, 0.15)
	_tower_lights()   # T-268: the watchtower's lanterns, its red masthead lamp, the zip posts' lanterns and the searchlight
	# the hoist over the loft door (T-084): the beam out of the gable, its pulley and rope down to the ledge, the
	# ledge's brackets, snow on its boards
	Props.block(g, Vector3(21.85, 5.9, 33.6), Vector3(22.15, 6.15, 36.3), "beam")
	Props.cyl(g, Vector3(22.0, 5.78, 36.0), 0.14, 0.08, "iron", Vector3(0, 0, 90))
	Props.cable(g, Vector3(22.0, 5.7, 36.0), Vector3(22.0, LOFT_TOP + 0.05, 36.0), 0.0, 0.015, 2, "rope")
	Props.cyl(g, Vector3(22.0, LOFT_TOP + 0.1, 36.0), 0.14, 0.1, "iron", Vector3(90, 0, 0))
	for bx2: float in [20.4, 23.5, 24.8]:   # (T-227: no bracket over the Thompson chalk at x 22)
		Props.obox(g, Vector3(bx2, 2.4, 35.0), Vector3(0.14, 0.14, 2.3), "beam", Vector3(-48, 0, 0))
	Props.block(g, Vector3(20.0, LOFT_TOP, 34.3), Vector3(25.2, LOFT_TOP + 0.06, 36.6), "snow", false)
	_lamp("YardMoonFill", Vector3(18.0, 6.0, 41.0), Color(0.5, 0.6, 0.85), 0.25, 22.0, false, false)


## A gable roof (ridge along X) over the rectangle a..b (a.y = eave height), with a snow layer on top.
func _gable(parent: Node3D, a: Vector3, b: Vector3, rise: float) -> void:
	var half: float = (b.z - a.z) * 0.5
	var slope_len: float = Vector2(half, rise).length() + 0.2
	var ang: float = rad_to_deg(atan2(rise, half))
	var cx: float = (a.x + b.x) * 0.5
	var w: float = b.x - a.x
	for side: float in [-1.0, 1.0]:
		var cz: float = a.z + half + side * -half * 0.5
		Props.obox(parent, Vector3(cx, a.y + rise * 0.5, cz), Vector3(w, 0.2, slope_len), "roof", Vector3(-ang * side, 0, 0))
		Props.obox(parent, Vector3(cx, a.y + rise * 0.5 + 0.14, cz), Vector3(w + 0.1, 0.1, slope_len - 0.3), "snow", Vector3(-ang * side, 0, 0))
		# T-093: the snow load's soft edge, a rounded lip along the eave (and a little overhang of snow)
		var ez: float = a.z if side > 0.0 else b.z
		var lip: MeshInstance3D = Props.cyl(parent, Vector3(cx, a.y + 0.12, ez + (0.12 if side > 0.0 else -0.12)), 0.16, w + 0.12, "snow", Vector3(0, 0, 90))
		lip.scale.x *= 0.55
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# gable end walls
	for x: float in [a.x + 0.3, b.x - 0.3]:
		for k: int in 6:
			var t: float = float(k) / 6.0
			var hz: float = half * (1.0 - (t + 1.0 / 6.0)) + 0.05
			Props.block(parent, Vector3(x - 0.12, a.y + rise * t, a.z + half - hz), Vector3(x + 0.12, a.y + rise * (t + 1.0 / 6.0), a.z + half + hz), "planks")


## T-126: the hull's cross-section (x, y) in the wreck frame, port to starboard over the top and back under: the
## walls stand on the colliders (x +-1.15..1.4), the roof over WRECK_ROOF.
const WRECK_RING: Array = [Vector2(1.3, -0.1), Vector2(1.42, 0.6), Vector2(1.44, 1.3), Vector2(1.38, 1.95), Vector2(1.12, 2.42),
	Vector2(0.6, 2.68), Vector2(0.0, 2.75), Vector2(-0.6, 2.68), Vector2(-1.12, 2.42), Vector2(-1.38, 1.95), Vector2(-1.44, 1.3),
	Vector2(-1.42, 0.6), Vector2(-1.3, -0.1), Vector2(0.0, -0.22)]


## True when a hull panel centred at (x, y, z) in the wreck frame falls in one of WRECK_OPENINGS (a side opening).
static func _wreck_open(x: float, y: float, z: float) -> bool:
	for o: Array in WRECK_OPENINGS:
		var side: int = int(o[0])
		if side == 0 or (side < 0) != (x < 0.0) or absf(x) < 0.9:
			continue
		if z > float(o[1]) - 0.05 and z < float(o[2]) + 0.05 and y > float(o[3]) - 0.05 and y < float(o[4]) + 0.05:
			return true
	return false


## T-211 (UPDATE 12 section 5): GRAVELIGHT ONE is a real C-47 now: C47Wreck (gravelight/world/c47/) draws the model
## tools/c47/build_c47.py builds (the owner's downloaded C-47 once it is built, else our stand-in) in the wreck's site
## frame, with the cabin, the cockpit Selwyn sits pinned in, the snow drifts and the gouge, and the fire, the heat
## haze, the sparks, the smoke and the creaking metal round it. It replaced the boxes T-126 drew here (_dress_wreck_hull
## and the old wings, nacelles, tail and labels); the hull's colliders above are unchanged. The cabin's dim fire glow
## stays here, and the wreckage scattered over the field.
func _dress_wreck() -> void:
	var cw: Node3D = _scripted(Node3D.new(), "res://gravelight/world/c47/c47_wreck.gd", "C47Wreck", {})
	cw.transform = wreck_site_xf()
	dress.add_child(cw)
	var ll: OmniLight3D = OmniLight3D.new()
	ll.name = "CabinGlow"
	ll.light_color = Color(1.0, 0.5, 0.2)
	ll.light_energy = 0.7
	ll.omni_range = 5.5
	ll.shadow_enabled = false
	ll.position = wreck_xf() * Vector3(0.3, 1.9, 0.5)
	dress.add_child(ll)
	# debris scattered in the snow
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23121944
	for i: int in 14:
		var p: Vector3 = Vector3(rng.randf_range(-12, 12), 0.1, rng.randf_range(-14, 12))
		Props.obox(dress, Vector3(46, 0, 6) + p, Vector3(rng.randf_range(0.3, 1.6), 0.08, rng.randf_range(0.3, 1.2)), "wreck",
			Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))


# ================================================================== Update 02 section 8: the small-detail polish (T-053)

## Room by room (docs/MAP0_POLISH.md): story props, wear (worn boards, grime and soot, water stains, scuffs,
## cobwebs, snow blown in at the broken windows). Everything here is dressing (no collision, batched). The
## reactive pieces (glass, curtains, doors, hay, footprints, sound) are build_reactive()'s. Nothing goes in front of
## a buy, a door or a window, or in a walking line.
func _dress_polish() -> void:
	var g: Node3D = Props.group(dress, "Polish", Vector3.ZERO)
	_polish_taproom(g)
	_polish_upstairs(g)
	_polish_stable(g)
	_barn_dressing(g)
	_polish_cellars(g)


func _polish_taproom(g: Node3D) -> void:
	# ---- the meal the patrol left: their table (16.5, 11.5) with the map, a helmet, a mess tin, cold soup; a chair
	# knocked over as they got up; a greatcoat on the bench; a gas-mask canister and the map case under the table
	PropsStory.soup_bowl(g, Vector3(16.15, 0.75, 11.15), 20.0, 0.45)
	PropsStory.mess_tin(g, Vector3(15.95, 0.75, 11.95), -30.0)
	PropsStory.helmet(g, Vector3(17.05, 0.75, 11.05), 35.0)
	PropsStory.loaf(g, Vector3(16.95, 0.75, 11.95), 70.0)
	_lib_chair(Vector3(17.7, 0, 12.6), 110.0, true)   # (T-238: half a metre nearer its table, off the line from Door 2)
	PropsStory.coat_drape(g, Vector3(15.6, 0.5, 15.45), 0.0)
	PropsStory.gasmask_can(g, Vector3(17.35, 0, 12.25), 40.0)
	PropsStory.map_case(g, Vector3(15.75, 0, 12.55), -20.0)
	# the table by the hearth (12.5, 11.5): two suppers half eaten, the bread
	PropsStory.plate_meal(g, Vector3(12.2, 0.75, 11.15), 15.0, 0.6)
	PropsStory.soup_bowl(g, Vector3(12.85, 0.75, 11.9), -40.0, 0.3)
	PropsStory.plate_meal(g, Vector3(12.9, 0.75, 11.05), 120.0, 0.2)
	PropsStory.loaf(g, Vector3(12.15, 0.75, 11.85), -15.0)
	# the signals table (20, 4.5): a crust, a mug of ersatz coffee beside the logbook
	PropsStory.plate_meal(g, Vector3(19.8, 0.75, 4.05), -10.0, 0.95)
	PropsStory.mug(g, Vector3(20.3, 0.75, 4.9))
	# "Soup kept warm" (the guest book, 21.XII): the pot on the hearthstone, its ladle
	Props.cyl(g, Vector3(12.75, 0.24, 1.22), 0.17, 0.24, "iron")
	Props.cyl(g, Vector3(12.75, 0.37, 1.22), 0.175, 0.02, "iron")
	Props.obox(g, Vector3(12.85, 0.5, 1.2), Vector3(0.02, 0.35, 0.02), "steel", Vector3(0, 0, -25))
	# Lene's apron on its hook by the bar end of the north wall, and a cloth on the peg beside it
	PropsStory.apron_on_hook(g, Vector3(9.05, 1.78, 0.15), 180.0)
	Props.block(g, Vector3(8.62, 1.76, 0.15), Vector3(8.66, 1.8, 0.21), "iron")
	Props.obox(g, Vector3(8.64, 1.6, 0.21), Vector3(0.2, 0.32, 0.01), "linen", Vector3(4, 0, 2))
	# ---- wear: boards scrubbed pale where people walk (the bar, the spawn, every doorway)
	for wp: Array in [[Vector3(BAR_X0 + 0.2, 0, BAR_Z1 + 0.95), Vector3(BAR_X1 + 0.4, 0, 10.1)], [Vector3(BAR_X1 + 0.25, 0, BAR_Z0 + 0.4), Vector3(BAR_X1 + 1.7, 0, 9.8)],
			[Vector3(6.15, 0, 13.9), Vector3(8.2, 0, 15.85)], [Vector3(18.8, 0, 13.6), Vector3(21.2, 0, 15.85)],
			[Vector3(22.2, 0, 10.4), Vector3(23.85, 0, 12.6)], [Vector3(0.15, 0, 8.0), Vector3(1.8, 0, 10.1)],
			[Vector3(13.0, 0, 5.2), Vector3(17.0, 0, 9.7)], [Vector3(10.6, 0, 4.9), Vector3(13.4, 0, 6.3)]]:
		var a: Vector3 = wp[0]
		var b: Vector3 = wp[1]
		PropsStory.stain(g, Vector3(a.x, 0.0125, a.z), Vector3(b.x, 0.0135, b.z), "floor_worn")
	# soot: the chimney breast, the lintel and the ceiling over the hearth, and a smudge over each lantern
	PropsStory.stain(g, Vector3(11.2, 1.5, 0.603), Vector3(12.8, 3.45, 0.607), "soot")
	PropsStory.stain(g, Vector3(11.4, 1.0, 0.953), Vector3(12.6, 1.42, 0.957), "soot")
	PropsStory.stain(g, Vector3(10.4, 3.493, 0.15), Vector3(13.6, 3.497, 1.9), "soot")
	for lp: Vector2 in [Vector2(6.5, 11.5), Vector2(17.5, 4.0), Vector2(19.5, 13.0), Vector2(14.0, 8.0)]:
		PropsStory.stain(g, Vector3(lp.x - 0.4, 3.493, lp.y - 0.4), Vector3(lp.x + 0.4, 3.497, lp.y + 0.4), "soot")
	# water stains: the ceiling in the north-west corner and over the east window, streaks under the north windows
	PropsStory.stain(g, Vector3(0.3, 3.492, 0.3), Vector3(2.8, 3.496, 2.3), "water_stain")
	PropsStory.stain(g, Vector3(22.4, 3.492, 6.6), Vector3(23.85, 3.496, 9.6), "water_stain")
	for wx: float in [6.0, 7.9, 16.05, 17.9]:
		PropsStory.stain(g, Vector3(wx - 0.08, 1.1, 0.152), Vector3(wx + 0.12, 2.2, 0.156), "water_stain")
	# scuffs: the bar front and side at boot height, the wainscot beside the doors
	PropsStory.stain(g, Vector3(BAR_X0 + 0.1, 0.04, BAR_Z1 + 0.803), Vector3(BAR_X1 - 0.05, 0.42, BAR_Z1 + 0.807), "scuff")
	PropsStory.stain(g, Vector3(BAR_X1 + 0.003, 0.04, BAR_Z0 + 0.1), Vector3(BAR_X1 + 0.007, 0.42, BAR_Z1 - 0.05), "scuff")
	for sx: Array in [[18.4, 18.92], [21.08, 21.6]]:   # either side of the stable door, not across it (T-072)
		PropsStory.stain(g, Vector3(float(sx[0]), 0.05, 15.81), Vector3(float(sx[1]), 0.6, 15.814), "scuff")
	PropsStory.stain(g, Vector3(6.186, 0.05, 13.6), Vector3(6.19, 0.6, 14.22), "scuff")
	# grime round the door frames, at hand height
	for gz: Array in [[13.85, 14.25], [15.95, 16.0]]:
		PropsStory.stain(g, Vector3(6.152, 1.1, float(gz[0])), Vector3(6.156, 2.1, float(gz[1])), "grime")
	for gx: Array in [[18.55, 18.9], [21.1, 21.45]]:
		PropsStory.stain(g, Vector3(float(gx[0]), 1.1, 15.843), Vector3(float(gx[1]), 2.2, 15.847), "grime")
	PropsStory.stain(g, Vector3(23.843, 1.1, 10.2), Vector3(23.847, 2.3, 10.58), "grime")
	PropsStory.stain(g, Vector3(23.843, 1.1, 12.42), Vector3(23.847, 2.3, 12.8), "grime")
	# cobwebs in the taproom's high corners
	Props.cobweb(g, Vector3(0.15, TAP_H - 0.02, 0.15), 0.0, 0.8)
	Props.cobweb(g, Vector3(23.85, TAP_H - 0.02, 0.15), -90.0, 0.7)
	Props.cobweb(g, Vector3(23.85, TAP_H - 0.02, 15.85), 180.0, 0.8)
	# snow blown in at the four broken windows
	PropsStory.snow_blown_in(g, Vector3(7.0, 0, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(17.0, 0, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(0, 0, 6.0), Vector3(1, 0, 0), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(24.0, 0, 8.0), Vector3(-1, 0, 0), WIN_SILL)


func _polish_upstairs(g: Node3D) -> void:
	var y: float = UP_Y
	# ---- Room 1: the cousins' room. Modest period clothes (HOMAGE_BOSSES 1.2): a Sunday dress on the wardrobe, a
	# cardigan folded at the bed's foot, a suitcase open on the bed, three pairs of shoes, a winter coat and a scarf
	# on the pegs, the red ribbon and a brush on the blanket, a straw tick rolled in the corner (three girls, one
	# bed). Their childhood drawings are pinned on the south wall (PaperDecor, build_reactive).
	PropsStory.dress_on_hanger(g, Vector3(7.15, y + 1.98, 1.5), 90.0, "cloth_navy")
	PropsStory.cardigan_folded(g, Vector3(1.25, y + 0.476, 2.3), 0.0, "cloth_cream")
	PropsStory.suitcase_open(g, Vector3(1.25, y + 0.476, 1.6), 180.0)
	PropsStory.ribbon_and_brush(g, Vector3(0.75, y + 0.476, 0.95), 30.0)
	PropsStory.shoes(g, Vector3(2.45, y, 2.2), 95.0, "leather")
	PropsStory.shoes(g, Vector3(2.5, y, 1.62), 80.0, "black_paint")
	PropsStory.shoes(g, Vector3(2.05, y, 4.75), 180.0, "leather")
	Props.block(g, Vector3(7.8, y + 1.6, 3.3), Vector3(7.85, y + 1.68, 4.7), "beam")   # a peg rail on the east wall
	for pz: float in [3.6, 4.3]:
		Props.cyl(g, Vector3(7.78, y + 1.63, pz), 0.02, 0.1, "beam", Vector3(0, 0, 90))
	var coat: Node3D = Props.group(g, "Coat", Vector3(7.73, y + 1.63, 3.6), -90.0)
	Props.obox(coat, Vector3(0, -0.12, 0), Vector3(0.4, 0.2, 0.12), "cloth_navy")
	Props.obox(coat, Vector3(0, -0.62, 0.0), Vector3(0.46, 0.85, 0.11), "cloth_navy", Vector3(-3, 0, 0))
	Props.obox(coat, Vector3(0, -0.3, -0.06), Vector3(0.05, 0.4, 0.02), "cloth_cream")   # a lining showing
	var scarf: Node3D = Props.group(g, "Scarf", Vector3(7.75, y + 1.63, 4.3), -90.0)
	Props.obox(scarf, Vector3(0.04, -0.3, 0), Vector3(0.12, 0.6, 0.03), "plaster_upper")
	Props.obox(scarf, Vector3(-0.06, -0.24, 0.01), Vector3(0.12, 0.48, 0.03), "plaster_upper")
	PropsStory.rolled_mattress(g, Vector3(7.5, y, 0.6))
	Props.cobweb(g, Vector3(0.15, UP_TOP - 0.02, 0.15), 0.0, 0.7)
	PropsStory.stain(g, Vector3(5.6, UP_TOP - 0.008, 0.3), Vector3(7.7, UP_TOP - 0.004, 2.0), "water_stain")
	PropsStory.stain(g, Vector3(2.4, y + 0.0125, 2.6), Vector3(6.4, y + 0.0135, 4.8), "floor_worn")
	# ---- Room 2: the works' gentleman's things: a briefcase by the bed, a hat on the trunk's corner
	var bc: Node3D = Props.group(g, "Briefcase", Vector3(13.25, y, 2.95), 80.0)
	Props.block(bc, Vector3(-0.2, 0, -0.05), Vector3(0.2, 0.3, 0.05), "leather")
	Props.block(bc, Vector3(-0.06, 0.3, -0.01), Vector3(0.06, 0.34, 0.01), "leather")
	Props.cyl(g, Vector3(11.45, y + 0.53, 1.0), 0.17, 0.02, "black_paint")
	Props.cyl(g, Vector3(11.45, y + 0.58, 1.0), 0.1, 0.1, "black_paint")
	Props.cobweb(g, Vector3(15.85, UP_TOP - 0.02, 0.15), -90.0, 0.7)
	PropsStory.stain(g, Vector3(8.6, UP_TOP - 0.008, 2.6), Vector3(10.6, UP_TOP - 0.004, 4.6), "water_stain")
	PropsStory.stain(g, Vector3(10.6, y + 0.0125, 2.6), Vector3(13.0, y + 0.0135, 4.8), "floor_worn")
	# ---- Room 3: Josef's overcoat on the chair; the coffee he didn't finish
	PropsStory.coat_drape(g, Vector3(17.93, y + 0.93, 1.11), 200.0, "cloth_navy")
	PropsStory.mug(g, Vector3(21.0, y + 0.622, 4.3))
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, 0.15), -90.0, 0.8)
	PropsStory.stain(g, Vector3(18.6, y + 0.0125, 2.4), Vector3(21.2, y + 0.0135, 4.8), "floor_worn")
	# ---- the hall: cobwebs at its east end, a stain where the roof leaks, the runner worn to the threads
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, HALL_Z0 + 0.15), -90.0, 0.7)
	Props.cobweb(g, Vector3(23.85, UP_TOP - 0.02, 9.85), 180.0, 0.8)
	PropsStory.stain(g, Vector3(20.6, UP_TOP - 0.008, 6.4), Vector3(23.6, UP_TOP - 0.004, 9.6), "water_stain")
	PropsStory.stain(g, Vector3(3.8, y + 0.026, 6.2), Vector3(13.0, y + 0.028, 7.4), "floor_worn")
	PropsStory.stain(g, Vector3(0.3, UP_TOP - 0.008, 11.0), Vector3(2.2, UP_TOP - 0.004, 13.2), "water_stain")   # over the stairwell
	# snow in at the two upstairs windows
	PropsStory.snow_blown_in(g, Vector3(4.0, y, 0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(20.0, y, 0), Vector3(0, 0, 1), WIN_SILL)


func _polish_stable(g: Node3D) -> void:
	# ---- the horse's stall: her name board over the manger, the halter on its peg, the water bucket, the blanket.
	# You hear her in the first rounds (AudioZone); after that the stall is just empty. Nothing shows why.
	Props.block(g, Vector3(11.55, 1.86, 22.15), Vector3(12.45, 2.1, 22.19), "planks")
	Props.stencil(g, Vector3(12.0, 1.98, 22.2), 180.0, "FANNY", 44, Color(0.62, 0.56, 0.44, 0.85), 0.0036).shaded = true   # paint, lit like the board
	var halter: Node3D = Props.group(g, "Halter", Vector3(11.0, 1.55, 25.33), 0.0)
	Props.cyl(halter, Vector3(0, 0, 0), 0.02, 0.08, "iron", Vector3(90, 0, 0))
	Props.obox(halter, Vector3(-0.06, -0.18, 0.04), Vector3(0.03, 0.36, 0.01), "leather", Vector3(0, 0, -12))
	Props.obox(halter, Vector3(0.06, -0.18, 0.04), Vector3(0.03, 0.36, 0.01), "leather", Vector3(0, 0, 12))
	Props.obox(halter, Vector3(0, -0.36, 0.04), Vector3(0.2, 0.03, 0.01), "leather")
	Props.cyl(halter, Vector3(0, -0.5, 0.04), 0.025, 0.25, "rope")
	_lib("bucket_wood", Vector3(11.6, 0.0, 22.75), 20.0, Vector3(0.8, 0.8, 0.8), false)
	Props.cyl(g, Vector3(11.6, 0.36, 22.75), 0.12, 0.01, "puddle")
	Props.block(g, Vector3(11.85, 0.85, 22.18), Vector3(12.95, 1.1, 22.24), "cloth_green")   # a horse blanket over the manger
	# hay pulled from the manger and trodden into the floor of the stall
	for hp: Vector3 in [Vector3(12.4, 0, 23.2), Vector3(11.8, 0, 24.3)]:
		Hay.pad(g, hp + Vector3(0, 0.012, 0), Vector3(0.9, 0.02, 0.6), "straw_floor", Vector3(0, 25, 0))
	# the loft: loose straw over the boards
	var lr: RandomNumberGenerator = RandomNumberGenerator.new()
	lr.seed = 3401
	for k: int in 18:
		Hay.pad(g, Vector3(lr.randf_range(STB_X0 + 0.6, LOFT_X1 - 0.6), LOFT_TOP + 0.012, lr.randf_range(22.6, 30.0)), Vector3(lr.randf_range(0.4, 1.0), 0.02, lr.randf_range(0.3, 0.6)),
			"straw_floor", Vector3(0, lr.randf_range(0, 180), 0))
	for k2: int in 8:   # and along the gallery (T-084)
		Hay.pad(g, Vector3(lr.randf_range(LOFT_X1 + 0.5, HSTAIR_X0 - 0.6), LOFT_TOP + 0.012, lr.randf_range(GAL_Z0 + 0.6, 33.4)), Vector3(lr.randf_range(0.4, 1.0), 0.02, lr.randf_range(0.3, 0.6)),
			"straw_floor", Vector3(0, lr.randf_range(0, 180), 0))
	# cobwebs in the roof corners and on the trusses
	Props.cobweb(g, Vector3(STB_X0 + 0.15, STABLE_H - 0.02, 22.15), 0.0, 1.0)
	Props.cobweb(g, Vector3(STB_X1 - 0.15, STABLE_H - 0.02, 22.15), -90.0, 0.9)
	Props.cobweb(g, Vector3(STB_X1 - 0.15, STABLE_H - 0.02, 33.85), 180.0, 1.0)
	Props.cobweb(g, Vector3(STB_X0 + 0.15, STABLE_H - 0.02, 33.85), 90.0, 0.9)
	Props.cobweb(g, Vector3(STB_X0 + 0.55, STABLE_H - 0.62, 24.65), 0.0, 0.6)
	# snow in at the stable's windows
	PropsStory.snow_blown_in(g, Vector3(9.0, 0, 22.0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(14.0, 0, 22.0), Vector3(0, 0, 1), WIN_SILL)
	PropsStory.snow_blown_in(g, Vector3(12.0, 0, 34.0), Vector3(0, 0, -1), WIN_SILL)


## T-100: the stable and hayloft dressed like a working barn (the art pass had left them nearly bare): proper stall
## partitions (posts to the beam, a capped top rail, iron bars over the boards, kick boards), slatted hay racks over
## the mangers with hay in them, the mangers on legs, a feed trough and a water trough, a tack wall with pegs (a
## collar, bridles, harness, a coiled lead rope) and a saddle on its rack, two lanterns on hooks at the stall posts
## (beside StableLamp1 / StableLamp3, which light them; no new lights), a spare ladder hung on the north wall, hay
## and straw scattered on the floor and the loft, sacks, crates, a spade and a bucket up on the loft. Visual only:
## no colliders, nothing on the walk lines (against walls, on stall planes, over existing colliders), the navmesh
## and gameplay geometry are untouched (test_map00_art fingerprints the bake).
func _barn_dressing(parent: Node3D) -> void:
	var g: Node3D = Props.group(parent, "BarnDressing", Vector3.ZERO)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1004
	var wn: float = STB_Z0 + 0.15   # the north wall's inner face
	var ww: float = STB_X0 + 0.15   # the west wall's inner face
	# ---- stall partitions: a post at the wall, a cap on the front post, a top rail, iron bars over the boards with
	# their head rail, a dark kick board at the foot
	for x: float in [11.0, 16.0, 17.6]:
		Props.block(g, Vector3(x - 0.11, 0.0, wn), Vector3(x + 0.11, 2.4, wn + 0.22), "beam")
		Props.block(g, Vector3(x - 0.12, 2.0, 24.98), Vector3(x + 0.12, 2.12, 25.32), "beam")
		Props.block(g, Vector3(x - 0.075, 1.36, wn + 0.2), Vector3(x + 0.075, 1.46, 25.0), "furniture")
		Props.block(g, Vector3(x - 0.1, 0.0, wn + 0.2), Vector3(x + 0.1, 0.16, 25.0), "beam")
		var zb: float = wn + 0.45
		while zb < 24.8:
			Props.cyl(g, Vector3(x, 1.74, zb), 0.012, 0.56, "iron")
			zb += 0.24
		Props.block(g, Vector3(x - 0.04, 2.0, wn + 0.2), Vector3(x + 0.04, 2.05, 25.0), "iron")
	# ---- hay racks over the mangers: slats leaning off the wall, hay behind them; the mangers get legs and a lip
	for rk: Array in [[12.0, 1.1, 1.78], [16.8, 1.2, 1.95]]:
		var rx: float = float(rk[0])
		var y0: float = float(rk[1])
		var y1: float = float(rk[2])
		Props.block(g, Vector3(rx - 0.6, y0 - 0.04, wn), Vector3(rx + 0.6, y0 + 0.02, wn + 0.06), "beam")
		Props.block(g, Vector3(rx - 0.6, y1 - 0.03, wn + 0.4), Vector3(rx + 0.6, y1 + 0.03, wn + 0.46), "beam")
		var sx: float = rx - 0.5
		while sx <= rx + 0.51:
			Props.strut(g, Vector3(sx, y0, wn + 0.04), Vector3(sx, y1, wn + 0.43), 0.025, "furniture", true)
			sx += 0.125
		Props.obox(g, Vector3(rx, (y0 + y1) * 0.5 - 0.02, wn + 0.17), Vector3(1.1, y1 - y0 - 0.05, 0.22), "hay", Vector3(-28, 0, 0))
		for lx: float in [-0.55, 0.55]:
			Props.block(g, Vector3(rx + lx - 0.04, 0.0, wn + 0.3), Vector3(rx + lx + 0.04, 0.5, wn + 0.38), "beam")
		Props.block(g, Vector3(rx - 0.6, 0.83, wn + 0.4), Vector3(rx + 0.6, 0.9, wn + 0.47), "furniture")
		Props.obox(g, Vector3(rx, 0.86, wn + 0.24), Vector3(1.05, 0.04, 0.3), "hay")
	# ---- a feed trough on trestles in the west stall and a water trough against the west wall
	var ft: Node3D = Props.group(g, "FeedTrough", Vector3(6.6, 0.0, wn + 0.25))
	Props.block(ft, Vector3(-0.9, 0.42, -0.2), Vector3(0.9, 0.46, 0.2), "planks")
	Props.block(ft, Vector3(-0.9, 0.46, -0.2), Vector3(0.9, 0.68, -0.16), "planks")
	Props.block(ft, Vector3(-0.9, 0.46, 0.16), Vector3(0.9, 0.68, 0.2), "planks")
	Props.block(ft, Vector3(-0.92, 0.42, -0.2), Vector3(-0.88, 0.68, 0.2), "beam")
	Props.block(ft, Vector3(0.88, 0.42, -0.2), Vector3(0.92, 0.68, 0.2), "beam")
	Props.obox(ft, Vector3(0, 0.5, 0), Vector3(1.7, 0.05, 0.3), "straw_floor")
	for tx: float in [-0.7, 0.7]:
		Props.strut(ft, Vector3(tx, 0.0, -0.18), Vector3(tx, 0.42, 0.0), 0.05, "beam")
		Props.strut(ft, Vector3(tx, 0.0, 0.18), Vector3(tx, 0.42, 0.0), 0.05, "beam")
	var wt: Node3D = Props.group(g, "WaterTrough", Vector3(ww + 0.3, 0.0, 23.9), 90.0)
	Props.block(wt, Vector3(-0.6, 0.0, -0.28), Vector3(0.6, 0.5, -0.22), "beam")
	Props.block(wt, Vector3(-0.6, 0.0, 0.22), Vector3(0.6, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(-0.66, 0.0, -0.28), Vector3(-0.6, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(0.6, 0.0, -0.28), Vector3(0.66, 0.5, 0.28), "beam")
	Props.block(wt, Vector3(-0.6, 0.38, -0.22), Vector3(0.6, 0.4, 0.22), "puddle")
	for bx: float in [-0.45, 0.45]:
		Props.block(wt, Vector3(bx - 0.03, 0.49, -0.29), Vector3(bx + 0.03, 0.52, 0.29), "iron")
	# ---- the tack wall on the west wall north of the bench: a peg board, a collar, two bridles, harness, a lead rope
	Props.block(g, Vector3(ww, 1.62, 22.55), Vector3(ww + 0.05, 1.78, 25.05), "beam")
	for pz: float in [22.85, 23.45, 24.05, 24.65]:
		Props.cyl(g, Vector3(ww + 0.12, 1.7, pz), 0.018, 0.16, "furniture", Vector3(0, 0, 90))
	var cl: Node3D = Props.group(g, "Collar", Vector3(ww + 0.17, 1.42, 22.85), 90.0)
	for k: int in 10:
		var a0: float = TAU * float(k) / 10.0
		var a1: float = TAU * float(k + 1) / 10.0
		Props.strut(cl, Vector3(cos(a0) * 0.22, sin(a0) * 0.28, 0), Vector3(cos(a1) * 0.22, sin(a1) * 0.28, 0), 0.07, "leather", true)
	Props.obox(cl, Vector3(-0.2, 0.0, 0.03), Vector3(0.04, 0.5, 0.05), "brass")
	Props.obox(cl, Vector3(0.2, 0.0, 0.03), Vector3(0.04, 0.5, 0.05), "brass")
	for bz: float in [23.45, 24.05]:   # bridles: cheek straps, a brow band, the bit rings, the reins
		var br: Node3D = Props.group(g, "Bridle", Vector3(ww + 0.16, 1.7, bz), 90.0)
		Props.obox(br, Vector3(-0.07, -0.25, 0), Vector3(0.025, 0.5, 0.008), "leather", Vector3(0, 0, -8))
		Props.obox(br, Vector3(0.07, -0.25, 0), Vector3(0.025, 0.5, 0.008), "leather", Vector3(0, 0, 8))
		Props.obox(br, Vector3(0, -0.14, 0.004), Vector3(0.18, 0.025, 0.008), "leather")
		Props.cyl(br, Vector3(-0.1, -0.52, 0), 0.035, 0.008, "iron", Vector3(90, 0, 0))
		Props.cyl(br, Vector3(0.1, -0.52, 0), 0.035, 0.008, "iron", Vector3(90, 0, 0))
		Props.obox(br, Vector3(0.0, -0.75, 0.01), Vector3(0.025, 0.55, 0.008), "leather", Vector3(0, 0, 3))
	var hn: Node3D = Props.group(g, "Harness", Vector3(ww + 0.16, 1.7, 24.65), 90.0)
	for hk: int in 5:
		Props.obox(hn, Vector3(-0.12 + hk * 0.06, -0.45 - 0.05 * absf(hk - 2.0), 0.01 * hk), Vector3(0.045, 0.9, 0.01), "leather", Vector3(0, 0, -10 + hk * 5))
	Props.cyl(hn, Vector3(0.0, -0.72, 0.03), 0.06, 0.012, "brass", Vector3(90, 0, 0))
	var rc: Node3D = Props.group(g, "LeadRope", Vector3(ww + 0.1, 1.45, 25.2), 90.0)
	for k2: int in 3:
		var r: float = 0.17 - k2 * 0.015
		for k3: int in 10:
			var b0: float = TAU * float(k3) / 10.0
			var b1: float = TAU * float(k3 + 1) / 10.0
			Props.strut(rc, Vector3(cos(b0) * r * 0.8, sin(b0) * r, 0.015 * k2), Vector3(cos(b1) * r * 0.8, sin(b1) * r, 0.015 * k2), 0.022, "rope", true)
	# the saddle on its rack below the peg board
	var sr: Node3D = Props.group(g, "SaddleRack", Vector3(ww, 1.0, 23.75), 0.0)
	Props.block(sr, Vector3(0.0, -0.05, -0.05), Vector3(0.62, 0.02, 0.05), "beam")
	Props.strut(sr, Vector3(0.02, -0.45, 0.0), Vector3(0.45, -0.03, 0.0), 0.05, "beam")
	Props.obox(sr, Vector3(0.33, 0.06, 0.0), Vector3(0.55, 0.05, 0.58), "cloth_green", Vector3(0, 0, -4))
	Props.obox(sr, Vector3(0.33, 0.12, 0.0), Vector3(0.48, 0.08, 0.36), "leather")
	Props.obox(sr, Vector3(0.1, 0.2, 0.0), Vector3(0.1, 0.12, 0.3), "leather", Vector3(0, 0, 18))
	Props.obox(sr, Vector3(0.55, 0.19, 0.0), Vector3(0.08, 0.1, 0.22), "leather", Vector3(0, 0, -20))
	for sz: float in [-0.25, 0.25]:
		Props.obox(sr, Vector3(0.33, -0.12, sz), Vector3(0.04, 0.42, 0.012), "leather")
		Props.cyl(sr, Vector3(0.33, -0.36, sz), 0.05, 0.012, "iron", Vector3(90, 0, 0))
	# ---- two lanterns on hooks at the stall posts (StableLamp3 and StableLamp1 light them; no lights of their own)
	for hl: Vector3 in [Vector3(11.0, 2.0, 25.36), Vector3(17.6, 2.0, 25.36)]:
		Props.block(g, hl + Vector3(-0.015, -0.02, -0.02), hl + Vector3(0.015, 0.02, 0.18), "iron")
		Props.block(g, hl + Vector3(-0.012, -0.12, 0.15), hl + Vector3(0.012, 0.0, 0.17), "iron")
		var lb: MeshInstance3D = MeshInstance3D.new()
		lb.name = "HookLantern"
		lb.mesh = Props.lantern_body()
		lb.position = hl + Vector3(0, -0.4, 0.16)
		lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lb.set_meta("keep", true)
		g.add_child(lb)
	# and one on a wall hook at the tack wall's south end (TackLamp, a small shadowless lamp, lights the tack)
	Props.block(g, Vector3(ww, 2.0, 25.28), Vector3(ww + 0.2, 2.04, 25.32), "iron")
	Props.block(g, Vector3(ww + 0.17, 1.88, 25.29), Vector3(ww + 0.19, 2.0, 25.31), "iron")
	var tl: MeshInstance3D = MeshInstance3D.new()
	tl.name = "HookLantern"
	tl.mesh = Props.lantern_body()
	tl.position = Vector3(ww + 0.18, 1.6, 25.3)
	tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tl.set_meta("keep", true)
	g.add_child(tl)
	# ---- the spare ladder hung flat on the north wall over the hay pile, on two iron hooks
	var ld: Node3D = Props.group(g, "SpareLadder", Vector3(23.45, 2.6, wn + 0.08))
	Props.block(ld, Vector3(-1.6, 0.18, -0.03), Vector3(1.6, 0.24, 0.03), "beam")
	Props.block(ld, Vector3(-1.6, -0.24, -0.03), Vector3(1.6, -0.18, 0.03), "beam")
	var lr: float = -1.45
	while lr <= 1.46:
		Props.cyl(ld, Vector3(lr, 0.0, 0.0), 0.018, 0.4, "furniture")
		lr += 0.32
	for hx: float in [-1.0, 1.0]:
		Props.block(ld, Vector3(hx - 0.02, -0.3, -0.05), Vector3(hx + 0.02, -0.24, 0.07), "iron")
	# ---- hay and straw scattered: stalls, the aisle edges, under the chute and the bale drop, along the loft walls
	var floor_spots: Array = [Vector3(13.6, 0, 23.0), Vector3(16.8, 0, 23.4), Vector3(7.5, 0, 23.3), Vector3(9.8, 0, 24.4),
		Vector3(13.0, 0, 24.2), Vector3(19.3, 0, 29.6), Vector3(22.4, 0, 25.6), Vector3(18.0, 0, 33.2), Vector3(5.4, 0, 28.6)]
	for fs: Vector3 in floor_spots:
		for k4: int in 4:
			Hay.pad(g, fs + Vector3(rng.randf_range(-0.6, 0.6), 0.014, rng.randf_range(-0.45, 0.45)),
				Vector3(rng.randf_range(0.25, 0.7), 0.02, rng.randf_range(0.15, 0.4)), "straw_floor", Vector3(0, rng.randf_range(0, 180), 0))
		for k5: int in 3:
			Hay.stalk(g, fs + Vector3(rng.randf_range(-0.5, 0.5), 0.022, rng.randf_range(-0.4, 0.4)),
				rng.randf_range(0.18, 0.35) + 0.1, rng.randf_range(0, 180), rng.randf_range(-4, 4), "hay", 0.012)   # (T-238: these were 5 cm square hay sticks)
	var loft_spots: Array = [Vector3(8.0, LOFT_TOP, 22.6), Vector3(11.0, LOFT_TOP, 22.5), Vector3(14.6, LOFT_TOP, 22.7), Vector3(5.0, LOFT_TOP, 26.0),
		Vector3(5.0, LOFT_TOP, 28.6), Vector3(9.0, LOFT_TOP, 33.4), Vector3(19.3, LOFT_TOP, 29.6), Vector3(16.4, LOFT_TOP, 32.4), Vector3(22.6, LOFT_TOP, 33.4)]
	for ls: Vector3 in loft_spots:
		for k6: int in 4:
			Hay.pad(g, ls + Vector3(rng.randf_range(-0.5, 0.5), 0.014, rng.randf_range(-0.3, 0.3)),
				Vector3(rng.randf_range(0.3, 0.8), 0.022, rng.randf_range(0.2, 0.4)), "straw_floor", Vector3(0, rng.randf_range(0, 180), 0))
		Hay.tuft(g, ls + Vector3(rng.randf_range(-0.3, 0.3), 0.0, 0.0), 0.5, int(ls.x * 7.0 + ls.z))   # (T-238: it was a 0.5 x 0.12 x 0.3 m hay-coloured block)
	# ---- grain sacks along the loft's north wall and by the salt crate, two feed sacks below against the stall by the north door
	for sk: Array in [[Vector3(9.6, LOFT_TOP, 22.5), 10.0, 0.95], [Vector3(10.25, LOFT_TOP, 22.5), -20.0, 0.9], [Vector3(10.9, LOFT_TOP, 22.55), 35.0, 0.95],
			[Vector3(9.95, LOFT_TOP + 0.36, 22.5), 80.0, 0.85], [Vector3(15.95, LOFT_TOP, 33.5), 15.0, 0.85], [Vector3(16.0, LOFT_TOP, 32.85), -40.0, 0.8],
			[Vector3(17.95, 0.0, 23.3), 20.0, 0.9], [Vector3(17.95, 0.0, 23.9), -15.0, 0.85]]:
		Props.sack(g, sk[0], float(sk[1]), float(sk[2]))
	# library props (PropScatter, no collision): buckets, a spade against the wall (T-238: the three crates that stood
	# beside the loft's solid crate, 0.7 m high with no collider, are gone)
	_lib("bucket_wood", Vector3(14.6, LOFT_TOP, 22.55), 40.0, Vector3(0.8, 0.8, 0.8), false)
	_lib("spade_rusted", Vector3(ww + 0.1, LOFT_TOP, 29.6), 90.0, Vector3.ONE, false, Vector3(0, 0, -12))
	_lib("bucket_wood", Vector3(STB_X1 - 0.5, 0.0, 22.6), -15.0, Vector3(0.85, 0.85, 0.85), false)


func _polish_cellars(g: Node3D) -> void:
	# the Helvetia cellar's stair hall: a stain where the yard's melt comes through, boots worn into the landing
	PropsStory.stain(g, Vector3(24.4, 2.993, 10.4), Vector3(26.6, 2.997, 12.6), "water_stain")
	PropsStory.stain(g, Vector3(24.3, 0.0125, 10.5), Vector3(27.6, 0.0135, 13.0), "floor_worn")


# ================================================================== the reactive pieces (T-053)

## The parts that react, as runtime nodes under "Reactive" (they build their art at load time, so the .tscn holds
## only their settings): the glassware ShatterSets, the swinging room doors, the hay zones, the snow footprints,
## the audio zones (hearth, wind at the windows, the stable, the horse), the paper dressing (the calendar, the
## patrol's map, Käthe's notes, the cousins' drawings), and two drips for the Helvetia cellar.
func build_reactive() -> void:
	var r: Node3D = Node3D.new()
	r.name = "Reactive"
	map_root.add_child(r)
	for set_name: String in _glass.keys():
		var ss: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/shatter_set.gd", "Glass_" + set_name, {"items": _glass[set_name]})
		r.add_child(ss)
	# the paper: [kind, position, yaw, flat, tilt]
	var pi_: int = 0
	for pd: Array in [["calendar", Vector3(5.45, 1.75, 0.16), 180.0, false, 1.5],
			["freq_notes", Vector3(SHELF_X0 + 0.005, 1.72, 4.25), -90.0, false, -4.0], ["freq_notes", Vector3(SHELF_X0 + 0.005, 1.69, 4.62), -90.0, false, 6.0],
			["map", Vector3(16.5, 0.752, 11.55), 168.0, true, 0.0],
			["drawing_inn", Vector3(2.35, UP_Y + 1.6, HALL_Z0 - 0.15), 0.0, false, -3.0],
			["drawing_horse", Vector3(3.2, UP_Y + 1.5, HALL_Z0 - 0.15), 0.0, false, 4.0],
			["drawing_jam", Vector3(4.05, UP_Y + 1.62, HALL_Z0 - 0.15), 0.0, false, -2.0]]:
		pi_ += 1
		var paper: Node3D = _scripted(Node3D.new(), "res://gravelight/world/paper_decor.gd", "Paper%d_%s" % [pi_, str(pd[0])], {
			"kind": pd[0], "flat": pd[3], "tilt_deg": pd[4]})
		paper.position = pd[1]
		paper.rotation.y = deg_to_rad(float(pd[2]))
		r.add_child(paper)
	# the guest rooms' doors, left ajar, opening into the room: Room 1's hinged on its east jamb so the leaf never
	# hides the MP40 on the west wall from the doorway; Rooms 2 and 3 on their west jambs
	for dd: Array in ROOM_DOORS:
		var sd: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/swing_door.gd", "RoomDoor%d" % int(dd[2]), {
			"width": ROOM_DOOR_W, "height": 2.15, "rest_deg": 70.0, "open_deg": ROOM_DOOR_OPEN, "flip": dd[1]})
		sd.position = Vector3(float(dd[0]), UP_Y, HALL_Z0 - T * 0.5)
		r.add_child(sd)
	# hay that puffs underfoot: the straw on the stable floor, the hay pile, the loft's boards
	var hi_: int = 0
	for hz: Array in [[Vector3(12.5, 0, 23.6), Vector3(2.2, 0.8, 1.8)], [Vector3(14.0, 0, 24.0), Vector3(2.2, 0.8, 1.8)],
			[Vector3(19.5, 0, 24.5), Vector3(2.2, 0.8, 1.8)], [Vector3(9.0, 0, 27.0), Vector3(2.2, 0.8, 1.8)],
			[Vector3(20.0, 0, 31.0), Vector3(2.2, 0.8, 1.8)], [Vector3(22.5, 0, 23.7), Vector3(2.4, 1.0, 2.8)],
			[Vector3(10.0, LOFT_TOP, 28.0), Vector3(10.6, 0.8, 11.6)], [Vector3(19.4, LOFT_TOP, 31.5), Vector3(7.6, 0.8, 4.6)]]:
		hi_ += 1
		var hp: Node3D = _scripted(Area3D.new(), "res://gravelight/world/reactive/hay_puff_zone.gd", "HayPuff%d" % hi_, {"size": hz[1]})
		hp.position = hz[0]
		r.add_child(hp)
	# footprints on the open snow (the snowfall's areas, the strip in front of the inn); not over the light wells
	var fp: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/snow_footprints.gd", "SnowFootprints", {
		"areas": [AABB(Vector3(-40, -1, -40), Vector3(105, 3, 37)), AABB(Vector3(-40, -1, -3), Vector3(37, 3, 43)),
			AABB(Vector3(27, -1, -3), Vector3(38, 3, 43)), AABB(Vector3(-40, -1, 37), Vector3(105, 3, 33)),
			AABB(Vector3(0, -1, 16.6), Vector3(17.6, 3, 5.2)), AABB(Vector3(2, -1, 34.2), Vector3(32, 3, 13.8)),
			AABB(Vector3(-3, -1, -3), Vector3(30, 3, 2.75)), AABB(Vector3(24.2, -1, -3), Vector3(2.8, 3, 13))] as Array[AABB],
		"holes": [AABB(Vector3(1.85, -2, -4.65), Vector3(3.2, 4, 4.5)), AABB(Vector3(24.0, -2, -2.1), Vector3(2.35, 4, 5.45)),
			AABB(Vector3(23.8, -2, 9.8), Vector3(4.5, 4, 9.4))] as Array[AABB]})   # the light wells, the cellar's stair hall
	map_root.add_child(fp)
	# sound: the hearth (dies with its light), wind through each broken window (louder in gusts and as the boards go),
	# the stable's old frame creaking, the horse in her stall in the first two rounds
	var hearth: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "HearthCrackle", {
		"sound": "fire_crackle", "mode": "loop", "volume_db": 0.0, "follow_light": NodePath("../../Hearthfire"), "max_distance": 20.0})
	hearth.position = Vector3(12.0, 0.6, 1.0)
	r.add_child(hearth)
	for w: Array in [["W_TAP_N1", Vector3(7.0, 1.5, 0.4)], ["W_TAP_N2", Vector3(17.0, 1.5, 0.4)], ["W_TAP_W", Vector3(0.4, 1.5, 6.0)],
			["W_TAP_E", Vector3(23.6, 1.5, 8.0)], ["W_UP_R1", Vector3(4.0, UP_Y + 1.5, 0.4)], ["W_UP_R3", Vector3(20.0, UP_Y + 1.5, 0.4)],
			["W_ATT_W", Vector3(0.4, ATT_Y + 1.5, ATT_WIN_Z)], ["W_ATT_E", Vector3(23.6, ATT_Y + 1.5, ATT_WIN_Z)],
			["W_STB_N1", Vector3(9.0, 1.5, 22.4)], ["W_STB_N2", Vector3(14.0, 1.5, 22.4)], ["W_STB_S", Vector3(12.0, 1.5, 33.6)],
			["W_STB_LOFT", Vector3(22.0, LOFT_TOP + 1.5, 33.6)]]:
		var wz: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "WindHowl_" + str(w[0]), {
			"sound": "wind_howl", "mode": "loop", "volume_db": -14.0, "wind_db": 7.0, "broken_db": 8.0,
			"window": NodePath("../../Gameplay/" + str(w[0])), "max_distance": 11.0})
		wz.position = w[1]
		r.add_child(wz)
	var creak: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "StableCreaks", {
		"sound": "stable_creak", "mode": "random", "volume_db": -2.0, "interval": Vector2(12.0, 30.0), "spread": Vector3(8.0, 2.0, 5.0)})
	creak.position = Vector3(15.0, 4.5, 28.0)
	r.add_child(creak)
	var horse: Node3D = _scripted(Node3D.new(), "res://gravelight/world/reactive/audio_zone.gd", "HorseInTheStall", {
		"sound": "horse_whinny", "mode": "random", "volume_db": -4.0, "interval": Vector2(30.0, 65.0), "spread": Vector3(1.2, 0.2, 0.8),
		"max_round": 2, "max_plays": 3})
	horse.position = Vector3(12.6, 1.4, 23.4)
	r.add_child(horse)
	# the Helvetia cellar drips too, over its puddles
	for dp: Vector3 in [Vector3(30.1, CELLAR_TOP - 0.02, 25.0), Vector3(27.4, CELLAR_TOP - 0.02, 30.0)]:
		var drip: Node3D = _scripted(Node3D.new(), "res://gravelight/world/drip_point.gd", "Drip", {"height": CELLAR_TOP - 0.02 - CELLAR_Y})
		drip.position = dp
		gameplay.add_child(drip)


# ================================================================== the wall-buy audit (T-227)

## T-227 (the owner: "make sure all wall weapon buys look good on both maps"): before the batching, every wall-buy's front
## is checked against everything drawn: nothing may stand in the 1.8 x 1.2 m window in front of the chalk out to 1 m (the
## board, the gun and its label are WallBuy's own, built at load), and the chalk must hang on a collider (a world box
## within 0.1 m behind its plane), never float. The lamps are by construction (one BuyLight per entry). One line per buy;
## returns the number of blocked or floating ones.
func _audit_wall_buys() -> int:
	var bad: int = 0
	var meshes: Array = []
	for root: Node3D in [dress, geo]:
		meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	var bodies: Array = geo.find_children("*", "StaticBody3D", true, false)
	for b: Array in BUYS:
		var pos: Vector3 = b[1]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(b[2])))
		var out: Vector3 = basis * Vector3(0, 0, -1)
		var side: Vector3 = basis * Vector3(1, 0, 0)
		var c1: Vector3 = pos + out * 0.03 - side * 0.9 + Vector3(0, -0.6, 0)
		var c2: Vector3 = pos + out * 1.0 + side * 0.9 + Vector3(0, 0.6, 0)
		var win: AABB = AABB(c1.min(c2), (c2 - c1).abs())
		var hits: PackedStringArray = []
		for n: Node in meshes:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var ab: AABB = _xform_to_root(mi) * mi.get_aabb()
			if ab.intersects(win) and ab.intersection(win).get_volume() > 0.0005:
				hits.append("%s(%s @ %s)" % [mi.name, mi.get_parent().name, str(ab.get_center().snapped(Vector3(0.01, 0.01, 0.01)))])
		var behind: Vector3 = pos - out * 0.08
		var on_wall: bool = false
		for n2: Node in bodies:
			var body: StaticBody3D = n2 as StaticBody3D
			for c: Node in body.get_children():
				var cs: CollisionShape3D = c as CollisionShape3D
				if cs == null or not (cs.shape is BoxShape3D):
					continue
				var lp: Vector3 = (_xform_to_root(body) * cs.transform).affine_inverse() * behind
				var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
				if absf(lp.x) <= half.x and absf(lp.y) <= half.y and absf(lp.z) <= half.z:
					on_wall = true
					break
			if on_wall:
				break
		var ok: bool = hits.is_empty() and on_wall
		print("WALLBUY_AUDIT %-12s %s%s%s" % [str(b[0]), "clear" if ok else "BLOCKED", "" if on_wall else " (nothing behind the chalk)", "" if hits.is_empty() else ": " + ", ".join(hits)])
		if not ok:
			bad += 1
	return bad


# ================================================================== the perk-spot audit (T-251)

## Everything a perk spot must stay clear of, as boxes in a 2 m hash: the colliders (but the spots' own bake boxes),
## every drawn mesh of the dressing, the library props. {cell (Vector2i) -> Array of [AABB, name]}.
var _spot_grid: Dictionary = {}
var _spot_keep: Array = []   # [label, position, radius, is a polyline (Array of points) or null]

func _spot_grid_add(ab: AABB, n: String) -> void:
	if ab.size.x > 30.0 and ab.size.z > 30.0:
		return   # the ground slabs: a spot never reaches below its own floor
	for gx: int in range(int(floor(ab.position.x / 2.0)), int(floor(ab.end.x / 2.0)) + 1):
		for gz: int in range(int(floor(ab.position.z / 2.0)), int(floor(ab.end.z / 2.0)) + 1):
			var k: Vector2i = Vector2i(gx, gz)
			if not _spot_grid.has(k):
				_spot_grid[k] = []
			(_spot_grid[k] as Array).append([ab, n])


func _spot_grid_build() -> void:
	_spot_grid.clear()
	for b: Node in geo.find_children("*", "StaticBody3D", true, false):
		if String(b.name).begins_with("NavBlock_PerkSpot_"):
			continue
		for c: Node in b.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			_spot_grid_add((_xform_to_root(b as Node3D) * cs.transform) * AABB(-sz * 0.5, sz), "col:" + String(b.name))
	for n: Node in dress.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		_spot_grid_add(_xform_to_root(mi) * mi.get_aabb(), "mesh:%s(%s)" % [mi.name, mi.get_parent().name])
	for lp: Array in _lib_props:
		var o: Vector3 = (lp[1] as Transform3D).origin
		_spot_grid_add(AABB(o + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.8, 0.6)), "lib:" + str(lp[0]))
	# T-255: the guest rooms' swing doors are built at load (SwingDoor), so nothing above sees them: the box each leaf
	# sweeps from shut to pushed right open (T-251's guest-room spot had the leaf's tip in the corner of its walk)
	for dd: Array in ROOM_DOORS:
		var hinge: Vector3 = Vector3(float(dd[0]), UP_Y, HALL_Z0 - T * 0.5)
		var dir: float = -1.0 if bool(dd[1]) else 1.0   # (a flipped leaf runs along -X from its hinge)
		var tip_shut: float = hinge.x + dir * ROOM_DOOR_W
		var tip_open: float = hinge.x + dir * ROOM_DOOR_W * cos(deg_to_rad(ROOM_DOOR_OPEN))
		var x0: float = minf(minf(hinge.x, tip_shut), tip_open)
		var x1: float = maxf(maxf(hinge.x, tip_shut), tip_open)
		_spot_grid_add(AABB(Vector3(x0, UP_Y + 0.05, hinge.z - ROOM_DOOR_W), Vector3(x1 - x0, 2.1, ROOM_DOOR_W)), "the swing of RoomDoor%d" % int(dd[2]))
	# what a machine must keep away from: [label, position, radius]
	_spot_keep.clear()
	for d: Array in [["Door_Upstairs", Vector3(STAIR_X1, 0, 15.1)], ["Door_Stable", Vector3(20.0, 0, 16.0)], ["Door_Yard", Vector3(8.0, 0, 34.0)],
			["Door_Front", Vector3(FRONT_DOOR_X, 0, 0)], ["Door_Gate", Vector3(18.0, 0, 48.0)], ["Door_Cellar", Vector3(24.0, 0, 11.5)],
			["Door_OldCellar", Vector3(0.0, 0, 9.05)], ["Door_Lager", Vector3(26.0, CELLAR_Y, LAG_Z0)], ["Door_Dynamo", Vector3(DYN_X0, CELLAR_Y, 35.4)],
			["StableNorthDoor", Vector3(20.0, 0, 22.0)], ["RoomDoor1", Vector3(5.75, UP_Y, HALL_Z0)], ["RoomDoor2", Vector3(11.75, UP_Y, HALL_Z0)],
			["RoomDoor3", Vector3(20.25, UP_Y, HALL_Z0)], ["BayArch", Vector3(BAY_X0, CELLAR_Y, (BAY_ARCH.x + BAY_ARCH.y) * 0.5)],
			["CellarBreach", Vector3(24.0, CELLAR_Y, 20.25)], ["CellarStairFoot", Vector3(26.1, CELLAR_Y, 19.0)], ["StairFoot", Vector3(1.9, 0, STAIR_Z0)],
			["StairHead", Vector3(1.9, UP_Y, STAIR_Z1)], ["AtticStairFoot", Vector3(ASTAIR_X0, UP_Y, 8.8)], ["AtticStairHead", Vector3(ASTAIR_X1, ATT_Y, 8.8)],
			["HayStairFoot", Vector3(24.35, 0, HSTAIR_Z0)], ["HayStairHead", Vector3(24.35, LOFT_TOP, HSTAIR_Z1)], ["BankDoor", Vector3(-4.5, 0, BANK_Z0)],
			["OldCellarStairFoot", Vector3(-1.5, CELLAR_Y, 17.5)], ["IceCellarSeal", Vector3(5.0, CELLAR_Y, 6.7)], ["JakubCage", Vector3(OC_CAGE.end.x, CELLAR_Y, 4.9)]]:
		_spot_keep.append([str(d[0]), d[1], 2.3])
	for w: Array in WINDOWS:
		_spot_keep.append([str(w[0]), w[2], 2.6])
		if float((w[2] as Vector3).y) < 1.0:   # where its zombies rise (5 m out) and the way they walk to the boards
			var outp: Vector3 = (w[2] as Vector3) - Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 5.0)
			_spot_keep.append(["the walk to " + str(w[0]), Vector3.ZERO, 2.0, [outp, w[2]]])
	for w2: Array in [["W_CEL_COAL", Vector3(3.45, CELLAR_Y, 0.0)], ["W_CEL_VAULT", Vector3(24.0, CELLAR_Y, 1.8)]]:
		_spot_keep.append([str(w2[0]), w2[1], 2.6])
	for b2: Array in BUYS:
		_spot_keep.append(["WallBuy_" + str(b2[0]), (b2[1] as Vector3) - Vector3(0, 1.5, 0), 2.0])
	_spot_keep.append(["WallBuy_gewehr43", Vector3(11.05, CELLAR_Y, 6.6), 2.0])
	for c2: Array in CRATES:
		_spot_keep.append(["Crate_" + str(c2[0]), c2[1], 2.3])
	for a: Array in AMMO_BOXES:
		_spot_keep.append(["AmmoBox_" + str(a[0]), a[1], 1.7])
	_spot_keep.append(["ArmorersBench", ARMORERS_BENCH[0], 2.2])
	for ps: Vector3 in [Vector3(14.5, 0, 13.4), Vector3(16.6, 0, 14.3), Vector3(12.4, 0, 14.3), Vector3(14.5, 0, 15.1)]:
		_spot_keep.append(["PlayerSpawn", ps, 2.0])
	for gs: Array in [["Spawn_HayPile", Vector3(22.5, 0, 23.7)], ["Spawn_YardMound", Vector3(5.0, 0, 44.5)], ["Spawn_CoalChute", Vector3(34.2, CELLAR_Y, 29.6)],
			["Spawn_LagerDrain", Vector3(32.9, CELLAR_Y, 32.1)], ["Spawn_DynamoSump", Vector3(35.2, CELLAR_Y, 37.9)], ["Kellerschalter", DYN_LEVER - Vector3(0, 0.3, 0)],
			["Crucible", DYN_CRUCIBLE], ["FieldRadio", Vector3(SHELF_X1 - 0.2, 0, 4.9)], ["ZipPost", ZIP_LINES[0][2]], ["ZipPost", ZIP_LINES[1][2]], ["ZipPost", ZIP_LINES[2][2]],
			["Tower", Vector3(TOWER_X, 0, TOWER_Z - TOWER_HALF - 0.5)]]:
		_spot_keep.append([str(gs[0]), gs[1], 2.2])
	for gp: Vector3 in OUT_GROUND_SPAWNS:
		_spot_keep.append(["Spawn_Snow", gp, 3.0])
	# the data: the bots' routes (polylines), the ladders, the zip line, the horse, the story props, the people
	var jr: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/ai/routes_map00.json"))
	for r: Dictionary in (jr as Dictionary).get("routes", []):
		var pts: Array = []
		for q: Array in r.get("points", []):
			pts.append(Vector3(float(q[0]), float(q[1]), float(q[2])))
		if pts.size() > 1:
			pts.append(pts[0])
			_spot_keep.append(["route:" + str(r.get("id", "?")), Vector3.ZERO, 1.6, pts])
	var jm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map00.json"))
	for key: String in ["ladders", "ziplines", "horses", "climb_links"]:
		for row: Dictionary in jm.get(key, []):
			for f: String in ["pos", "to", "rail", "from"]:
				if row.has(f):
					var v: Array = row[f]
					_spot_keep.append(["%s:%s" % [key, str(row.get("name", "?"))], Vector3(float(v[0]), float(v[1]), float(v[2])), 2.6])
	var ex: Array = (jm.get("exfil", {}) as Dictionary).get("position", [])
	if ex.size() == 3:
		_spot_keep.append(["exfil", Vector3(float(ex[0]), float(ex[1]), float(ex[2])), 3.0])
	var sh: Dictionary = jm.get("sherman_event", {})
	var sroute: Array = []
	for q2: Array in sh.get("route", []):
		sroute.append(Vector3(float(q2[0]), float(q2[1]), float(q2[2])))
	if sroute.size() > 1:
		_spot_keep.append(["sherman_route", Vector3.ZERO, 6.0, sroute])
	for q3: Array in sh.get("shelter_points", []):
		_spot_keep.append(["sherman_shelter", Vector3(float(q3[0]), float(q3[1]), float(q3[2])), 1.6])
	var js: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/story_props.json"))
	for sp: Dictionary in js.get("props", []):
		if str(sp.get("map", "")) == "0":
			var v2: Array = sp["position"]
			_spot_keep.append(["story:" + str(sp["id"]), Vector3(float(v2[0]), float(v2[1]), float(v2[2])), 1.3])
	var jo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map00_opening.json"))
	for pt: Dictionary in jo.get("patrons", []):
		var line: Array = []
		for f2: String in ["start"]:
			line.append(pt[f2])
		line.append_array(pt.get("route", []))
		var pl: Array = []
		for q4: Array in line:
			pl.append(Vector3(float(q4[0]), float(q4[1]), float(q4[2])))
		if pl.size() > 1:
			_spot_keep.append(["opening_patron", Vector3.ZERO, 1.2, pl])
	var jv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/map00_survivors.json"))
	for sv: Dictionary in jv.get("survivors", []):
		for f3: String in ["hide", "post"]:
			var v3: Array = sv[f3]
			_spot_keep.append(["survivor_" + f3, Vector3(float(v3[0]), float(v3[1]), float(v3[2])), 1.5])
	var jp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/people_extra.json"))
	for pk: String in (jp.get("people", {}) as Dictionary).keys():
		var person: Dictionary = jp["people"][pk]
		if not (person.get("maps", []) as Array).has("map00"):
			continue
		for bd: Dictionary in person.get("bodies", []):
			var v4: Array = bd.get("at", [])
			if v4.size() == 3:
				_spot_keep.append(["person:" + pk, Vector3(float(v4[0]), float(v4[1]), float(v4[2])), 1.8])


## The boxes a machine on a spot keeps (world AABBs; yaw is a multiple of 90): [the footprint to the tallest cabinet's
## top, the walk in front and the walk behind to head height].
func _spot_boxes(pos: Vector3, yaw: float, flush: int = 0) -> Array:
	var b: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var out: Array = []
	var rows: Array = [[Vector3(-PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5), Vector3(PERK_SPOT_W * 0.5, 2.45, PERK_SPOT_D * 0.5)],
			[Vector3(-PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5 - PERK_FRONT), Vector3(PERK_SPOT_W * 0.5, 2.0, -PERK_SPOT_D * 0.5)],
			[Vector3(-PERK_SPOT_W * 0.5, 0.08, PERK_SPOT_D * 0.5), Vector3(PERK_SPOT_W * 0.5, 2.0, PERK_SPOT_D * 0.5 + PERK_BACK)],
			[Vector3(-0.3, 0.5, PERK_SPOT_D * 0.5 + PERK_BACK), Vector3(0.3, 1.5, PERK_SPOT_D * 0.5 + PERK_BACK + 0.6)]]   # the wall behind
	if flush != 0:   # T-255: the walk beside it (the fine print's side), and the wall right behind it (within 0.3 m)
		var s: float = float(flush)
		rows[2] = [Vector3(s * PERK_SPOT_W * 0.5, 0.08, -PERK_SPOT_D * 0.5), Vector3(s * (PERK_SPOT_W * 0.5 + PERK_SIDE), 2.0, PERK_SPOT_D * 0.5 - 0.15)]
		rows[3] = [Vector3(-0.3, 0.5, PERK_SPOT_D * 0.5 + 0.02), Vector3(0.3, 1.5, PERK_SPOT_D * 0.5 + 0.3)]
	for r: Array in rows:
		var p0: Vector3 = pos + b * (r[0] as Vector3)
		var p1: Vector3 = pos + b * (r[1] as Vector3)
		out.append(AABB(p0.min(p1), (p1 - p0).abs()))
	return out


func _spot_hits(box_: AABB, colliders_only: bool = false) -> PackedStringArray:
	var out: PackedStringArray = []
	for gx: int in range(int(floor(box_.position.x / 2.0)), int(floor(box_.end.x / 2.0)) + 1):
		for gz: int in range(int(floor(box_.position.z / 2.0)), int(floor(box_.end.z / 2.0)) + 1):
			for e: Array in _spot_grid.get(Vector2i(gx, gz), []):
				var ab: AABB = e[0]
				if colliders_only and not str(e[1]).begins_with("col:"):
					continue
				if ab.intersects(box_) and ab.intersection(box_).get_volume() > 0.0005 and not out.has(str(e[1])):
					out.append(str(e[1]))
	return out


## True when `p` is over the baked navmesh (a polygon within 0.6 m of its height).
func _on_nav(p: Vector3) -> bool:
	var nm: NavigationMesh = nav.navigation_mesh
	var vs: PackedVector3Array = nm.get_vertices()
	for i: int in nm.get_polygon_count():
		var poly: PackedInt32Array = nm.get_polygon(i)
		if absf(vs[poly[0]].y - p.y) > 0.6:
			continue
		var inside: bool = true
		var sign_: float = 0.0
		for k: int in poly.size():
			var a: Vector3 = vs[poly[k]]
			var b: Vector3 = vs[poly[(k + 1) % poly.size()]]
			var cr: float = (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x)
			if absf(cr) < 1e-6:
				continue
			if sign_ == 0.0:
				sign_ = signf(cr)
			elif signf(cr) != sign_:
				inside = false
				break
		if inside:
			return true
	return false


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var ap: Vector2 = Vector2(p.x - a.x, p.z - a.z)
	var t: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (ap - ab * t).length()


## What is wrong with a machine at `pos` facing `yaw` ([] = nothing). `fast`: stop at the first problem (the survey).
func _spot_problems(pos: Vector3, yaw: float, need_wall: bool, need_nav: bool, fast: bool = false, flush: int = 0) -> PackedStringArray:
	var out: PackedStringArray = []
	var boxes: Array = _spot_boxes(pos, yaw, flush)
	var names: Array = ["the machine", "the walk in front", "the walk behind" if flush == 0 else "the walk beside it"]
	for i: int in 3:
		var hits: PackedStringArray = _spot_hits(boxes[i])
		if not hits.is_empty():
			out.append("%s is in %s" % [names[i], ", ".join(hits)])
			if fast:
				return out
	if need_wall and _spot_hits(boxes[3], true).is_empty():
		out.append("no wall behind it")
		if fast:
			return out
	for k: Array in _spot_keep:
		var d: float = INF
		if k.size() > 3:
			var pts: Array = k[3]
			if absf((pts[0] as Vector3).y - pos.y) > 2.0:
				continue
			for j: int in pts.size() - 1:
				d = minf(d, _seg_dist(pos, pts[j], pts[j + 1]))
		else:
			var kp: Vector3 = k[1]
			if absf(kp.y - pos.y) > 2.0:
				continue
			d = Vector2(kp.x - pos.x, kp.z - pos.z).length()
		if d < float(k[2]):
			out.append("%.1f m from %s (wants %.1f)" % [d, str(k[0]), float(k[2])])
			if fast:
				return out
	if need_nav:
		var front: Vector3 = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -(PERK_SPOT_D * 0.5 + 0.7))
		if not _on_nav(front):
			out.append("the floor in front of it is not on the navmesh")
	return out


## T-251: every perk spot against everything built and drawn (see PERK_SPOTS). One line per spot; returns how many are bad.
## Also the table's own rules: unique ids, at most three spots in a zone, enough spots of each kind for the deal.
func _audit_perk_spots() -> int:
	_spot_grid_build()
	var bad: int = 0
	var per_zone: Dictionary = {}
	var ids: Dictionary = {}
	for sp: Array in PERK_SPOTS:
		var flags: Dictionary = sp[4]
		var probs: PackedStringArray = _spot_problems(sp[2], float(sp[3]), not bool(flags.get("free", false)), true, false, int(flags.get("flush", 0)))
		if ids.has(str(sp[0])):
			probs.append("its id is used twice")
		ids[str(sp[0])] = true
		per_zone[str(sp[1])] = int(per_zone.get(str(sp[1]), 0)) + 1
		print("PERKSPOT_AUDIT %-14s %-13s %-6s %s%s" % [str(sp[0]), str(sp[1]), "flush" if int(flags.get("flush", 0)) != 0 else "walk", "clear" if probs.is_empty() else "BLOCKED: ", "; ".join(probs)])
		if not probs.is_empty():
			bad += 1
	for z: String in per_zone.keys():
		if int(per_zone[z]) > 3:
			print("PERKSPOT_AUDIT zone %s has %d spots (at most 3)" % [z, int(per_zone[z])])
			bad += 1
	if PERK_SPOTS.size() < 14:
		print("PERKSPOT_AUDIT only %d spots (at least 14)" % PERK_SPOTS.size())
		bad += 1
	return bad


## T-251, a design aid (GL_PERK_SURVEY=1): every place a machine could stand against a wall, per region, as
## "SURVEY <region> <x> <z> <yaw>" lines. GL_PERK_SURVEY=free also lists the ones with nothing behind them.
func _survey_perk_spots() -> void:
	_spot_grid_build()
	# T-255: GL_PERK_PROBE="x,y,z,yaw,flush;x,y,z,yaw,flush": what is wrong with a machine at exactly these places
	if OS.get_environment("GL_PERK_PROBE") != "":
		for row: String in OS.get_environment("GL_PERK_PROBE").split(";", false):
			var v: PackedFloat64Array = row.split_floats(",")
			if v.size() >= 5:
				var probs: PackedStringArray = _spot_problems(Vector3(v[0], v[1], v[2]), v[3], true, true, false, int(v[4]))
				print("PROBE %s: %s" % [row, "clear" if probs.is_empty() else "; ".join(probs)])
		return
	var free_too: bool = OS.get_environment("GL_PERK_SURVEY") == "free"
	var flush_mode: bool = OS.get_environment("GL_PERK_SURVEY") == "flush"
	var regions: Array = [
		["TAPROOM", 0.0, Rect2(0.15, 0.15, 23.7, 15.7), 0.25], ["UPSTAIRS", UP_Y, Rect2(0.15, 0.15, 23.7, 9.7), 0.25], ["ATTIC", ATT_Y, Rect2(0.15, 0.15, 23.7, 9.7), 0.25],
		["STABLE", 0.0, Rect2(STB_X0, STB_Z0, STB_X1 - STB_X0, STB_Z1 - STB_Z0), 0.25], ["LOFT", LOFT_TOP, Rect2(STB_X0, STB_Z0, STB_X1 - STB_X0, STB_Z1 - STB_Z0), 0.25],
		["PASSAGE", 0.0, Rect2(0.0, 16.0, 24.0, 6.0), 0.25],
		["YARD", 0.0, Rect2(2.0, 34.0, 32.0, 14.0), 0.25], ["GROUNDS_N", 0.0, Rect2(-8.0, -12.0, 44.0, 12.0), 0.5], ["GROUNDS_E", 0.0, Rect2(24.0, 0.0, 22.0, 34.0), 0.5],
		["GROUNDS_W", 0.0, Rect2(-12.0, 0.0, 16.5, 34.0), 0.5], ["GROUNDS_S", 0.0, Rect2(-10.0, 48.0, 50.0, 14.0), 0.5],
		["CELLAR", CELLAR_Y, Rect2(24.0, 19.0, 18.2, 12.0), 0.25], ["OLD_CELLAR", CELLAR_Y, Rect2(-3.0, 0.0, 27.0, 18.5), 0.25],
		["LAGER", CELLAR_Y, Rect2(LAG_X0, LAG_Z0, LAG_X1 - LAG_X0, LAG_Z1 - LAG_Z0), 0.25], ["DYNAMO", CELLAR_Y, Rect2(DYN_X0, DYN_Z0, DYN_X1 - DYN_X0, DYN_Z1 - DYN_Z0), 0.25],
	]
	for r: Array in regions:
		var rect: Rect2 = r[2]
		var step: float = float(r[3]) * (0.5 if flush_mode else 1.0)   # (a flush spot's wall must be within 0.3 m of its back)
		var n: int = 0
		var x: float = rect.position.x
		while x <= rect.end.x:
			var z: float = rect.position.y
			while z <= rect.end.y:
				for yaw: float in [0.0, 90.0, 180.0, -90.0]:
					var pos: Vector3 = Vector3(x, float(r[1]), z)
					if flush_mode:   # T-255: back on the wall, the fine print's walk on either side
						for side: int in [1, -1]:
							if _spot_problems(pos, yaw, true, false, true, side).is_empty() and _spot_problems(pos, yaw, true, true, false, side).is_empty():
								print("SURVEY %s %.2f %.2f %d flush %d" % [str(r[0]), x, z, int(yaw), side])
								n += 1
						continue
					if _spot_problems(pos, yaw, true, false, true).is_empty():
						if _spot_problems(pos, yaw, true, true).is_empty():
							print("SURVEY %s %.2f %.2f %d wall" % [str(r[0]), x, z, int(yaw)])
							n += 1
					elif free_too and _spot_problems(pos, yaw, false, false, true).is_empty() and _spot_problems(pos, yaw, false, true).is_empty():
						print("SURVEY %s %.2f %.2f %d free" % [str(r[0]), x, z, int(yaw)])
				z += step
			x += step
		print("SURVEY_COUNT %s %d" % [str(r[0]), n])


# ================================================================== batching

## Merges every static primitive mesh (collision visuals + dressing) into one ArrayMesh per
## (material, shadow mode, 12 m cell) so the inn draws in a few dozen calls instead of ~1000.
## Materials are world-triplanar, so baking transforms into vertices keeps texturing identical.
func merge_static_meshes() -> int:
	var groups: Dictionary = {}   # key -> {mat, shadow, st: SurfaceTool}
	var victims: Array[MeshInstance3D] = []
	for holder: Node in [geo, dress]:
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if not (mi.mesh is PrimitiveMesh or mi.has_meta("batch")) or mi.material_override == null or mi.has_meta("keep"):   # ("batch": PropsHay's soft boxes)
				continue
			var xf: Transform3D = _xform_to_root(mi)
			var c: Vector3 = xf.origin
			var cell: Vector3i = Vector3i(floori(c.x / 12.0), floori(c.y / 6.0), floori(c.z / 12.0))
			var shadow: int = mi.cast_shadow
			var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), shadow, cell]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": shadow, "st": st}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var mesh: ArrayMesh = (g["st"] as SurfaceTool).commit()
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = mesh
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batch_root.add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	return victims.size()


func _xform_to_root(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


# ================================================================== lighting & environment

# ================================================================== the lighting pass (T-061)

## The inn's electric bulbs (T-061): the cellar lever's sweep reaches the taproom, upstairs and the stable, so each
## gets a few bare bulbs under tin shades that light with it. [light name, zone, bulb position, ceiling y, energy,
## range]. The names are in cousins.json setup.lamp_groups, so the Cousins round gutters them with the oil lamps.
const INN_BULBS: Array = [
	["TapBulb1", "TAPROOM", Vector3(9.6, 2.8, 5.6), TAP_H, 1.5, 8.5], ["TapBulb2", "TAPROOM", Vector3(14.5, 2.85, 11.6), TAP_H, 1.6, 9.0],
	["TapBulb3", "TAPROOM", Vector3(21.2, 2.85, 8.2), TAP_H, 1.4, 8.5],
	["HallBulb1", "UPSTAIRS", Vector3(7.2, UP_Y + 2.35, 7.0), UP_TOP, 1.3, 8.0], ["HallBulb2", "UPSTAIRS", Vector3(17.0, UP_Y + 2.35, 8.0), UP_TOP, 1.3, 8.0],   # (bulb 1 at z 7 since T-224: the attic flight)
	["AtticBulb", "UPSTAIRS", Vector3(9.0, ATT_Y + 2.35, 5.0), ATT_TOP, 1.1, 8.5], ["AtticBulb2", "UPSTAIRS", Vector3(15.5, ATT_Y + 2.35, 5.0), ATT_TOP, 1.1, 8.5],   # the attic (T-224)
	["Room1Bulb", "UPSTAIRS", Vector3(5.6, UP_Y + 2.35, 1.6), UP_TOP, 0.9, 6.0], ["Room2Bulb", "UPSTAIRS", Vector3(9.8, UP_Y + 2.35, 4.2), UP_TOP, 0.9, 6.0],
	["Room3Bulb", "UPSTAIRS", Vector3(21.8, UP_Y + 2.35, 2.6), UP_TOP, 0.8, 6.0],
	["PassBulb", "STABLE", Vector3(20.0, 2.55, 17.1), 3.0, 1.1, 6.5],
	["StableBulb1", "STABLE", Vector3(20.6, 4.6, 26.6), STABLE_H - 0.6, 1.9, 11.0], ["StableBulb2", "STABLE", Vector3(12.6, 2.75, 31.2), LOFT_Y, 1.3, 8.0],   # (bulb 1 mid-bay, clear of the gallery's rail, T-084)
]
const BULB_COLOR: Color = Color(1.0, 0.84, 0.62)
var _bulb_lit: Dictionary = {}   # light name -> holder of its lit glass (moved under the light in build_environment)


## Dressing for the lighting pass: the inn's bulb pendants (their lit glass in a holder per bulb) and the lantern
## the Helvetia installers left hanging in the perk vault (the vault is otherwise black until the lever is thrown).
func _dress_lighting() -> void:
	var g: Node3D = Props.group(dress, "Lighting", Vector3.ZERO)
	for b: Array in INN_BULBS:
		var holder: Node3D = Node3D.new()
		holder.name = str(b[0]) + "Lit"
		holder.set_script(load("res://gravelight/maps/map00_crossroads/lit_glass.gd"))
		dress.add_child(holder)
		Props.pendant(g, b[2], float(b[3]) - 0.02, holder, "tin")
		_bulb_lit[str(b[0])] = holder
	Props.lantern(g, Vector3(28.2, CELLAR_Y + 2.2, 25.0), CELLAR_TOP - 0.1)
	# the upstairs hall's two ends (the hall lamp alone left the stair head and the east end in the dark), and a
	# lamp over the Old Cellar's ammo box
	Props.wall_lamp(g, Vector3(0.16, UP_Y + 1.85, 6.7), -90.0)
	Props.wall_lamp(g, Vector3(23.84, UP_Y + 1.85, 8.0), 90.0)
	Props.wall_lamp(g, Vector3(8.6, UP_Y + 1.85, HALL_Z0 + 0.16), 180.0)   # mid-hall, between the room doors (pass 2)
	Props.wall_lamp(g, Vector3(16.0, UP_Y + 1.85, HALL_Z0 + 0.16), 180.0)
	Props.wall_lamp(g, Vector3(13.6, CELLAR_Y + 2.0, 15.84), 0.0)
	Props.wall_lamp(g, Vector3(STB_X0 + 0.16, 5.3, 32.4), -90.0)   # the hayloft's south end, over the bales
	# T-227: a bracket lamp over every chalk outline (its light is the BuyLight build_gameplay makes)
	for b: Array in BUYS:
		var out: Vector3 = Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0, -1)
		Props.wall_lamp(g, (b[1] as Vector3) + Vector3(0, 0.95, 0) - out * 0.03, float(b[2]))


## The night (T-061 lighting pass): cold moonlight and snow outside, warm lamp pools inside, fog that catches both.
## High adds SDFGI bounce light (the lamps' warmth on ceilings and in corners, the moonlit snow's cold fill through
## the windows, the wreck's glow on the field) and SSIL; Medium keeps SSIL; Low falls back to the flat ambient below
## (GLSettings presets take effects away, never add them). The sky dome is a mesh (Landscape), so the background
## colour only feeds the dome's tint and the GI's sky light (background_energy_multiplier).
func build_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)
	env.background_energy_multiplier = 1.5
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.4)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 3.0
	env.sdfgi_bounce_feedback = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.15)
	env.fog_light_energy = 1.0
	env.fog_density = 0.016
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	env.volumetric_fog_emission = Color(0.01, 0.012, 0.02)
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_gi_inject = 0.3   # SDFGI's bounce would turn the field's ground fog milky
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.14
	env.adjustment_brightness = 1.0
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.6, 0.95)
	moon.light_energy = 0.42
	moon.light_volumetric_fog_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(28), 0)
	map_root.add_child(moon)
	var warm: Color = Color(1.0, 0.66, 0.36)
	_lamp("Hearthfire", Vector3(12, 0.8, 1.4), Color(1.0, 0.5, 0.2), 5.5, 13.0, true, true)
	_lamp("TapLamp1", Vector3(6.5, 2.45, 11.5), warm, 2.72, 11.0, true, true, 0.08)
	_lamp("TapLamp2", Vector3(17.5, 2.45, 4.0), warm, 2.38, 11.0, true, true, 0.08)
	_lamp("TapLamp3", Vector3(19.5, 2.45, 13.0), warm, 2.38, 10.0, true, true, 0.08)
	_lamp("TapLamp4", Vector3(14.0, 2.45, 8.0), warm, 2.21, 10.0, true, true, 0.08)
	_lamp("BarLamp", Vector3(5.0, 2.4, 4.5), warm, 1.70, 7.0, false, true, 0.1)
	_lamp("StairLamp", Vector3(3.2, 4.45, 12.5), warm, 1.70, 10.0, false, true, 0.08)
	_lamp("StairSconce", Vector3(0.55, _stair_y(12.1) + 1.8, 12.1), warm, 0.75, 5.0, false, true, 0.1)
	_lamp("StairSconce2", Vector3(STAIR_X1 - 0.55, 2.35, 12.9), warm, 0.75, 5.0, false, true, 0.1)
	_lamp("Room1Lamp", Vector3(4.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("Room2Lamp", Vector3(12.0, UP_Y + 2.05, 3.0), warm, 1.53, 8.0, false, true, 0.08)
	_lamp("Room3Lamp", Vector3(20.0, UP_Y + 2.05, 3.0), warm, 1.70, 8.0, false, true, 0.08)
	_lamp("HallLamp", Vector3(12.0, UP_Y + 2.05, 7.0), warm, 1.87, 11.0, true, true, 0.08)   # (z 7 since T-224: the attic flight runs along the south wall)
	_lamp("AtticLamp", Vector3(5.0, ATT_Y + 1.85, 5.0), warm, 2.4, 11.0, true, true, 0.1)   # T-224: the attic's lanterns and the sconce at its stair head
	_lamp("AtticEastLamp", Vector3(19.0, ATT_Y + 1.9, 5.0), warm, 2.2, 10.0, false, true, 0.1)
	_lamp("AtticStairLamp", Vector3(11.5, ATT_Y + 1.8, 9.3), warm, 1.4, 8.0, false, true, 0.1)
	_lamp("AtticWellLamp", Vector3(10.0, ATT_Y + 1.95, 9.0), warm, 1.8, 9.0, false, true, 0.1)   # (touch-up: the lantern over the well and the flight)
	_lamp("AtticMidLamp", Vector3(12.0, ATT_Y + 1.9, 2.8), warm, 1.8, 9.0, false, true, 0.1)
	_lamp("AtticFlightLamp", Vector3(9.4, _astair_y(9.4) + 1.7, 9.45), warm, 1.1, 6.5, false, true, 0.12)   # the sconce mid-flight
	_lamp("PassLamp", Vector3(20.0, 2.25, 19.0), warm, 2.21, 10.0, false, true)
	_lamp("StableLamp1", Vector3(19.0, 3.85, 26.0), warm, 3.82, 14.0, true, true)
	_lamp("StableLamp2", Vector3(19.0, 2.35, 31.5), warm, 3.26, 13.0, true, true)   # under the gallery since T-084
	_lamp("StableLamp3", Vector3(10.0, 2.15, 28.0), warm, 2.99, 12.0, false, true)
	_lamp("TackLamp", Vector3(STB_X0 + 0.33, 1.75, 25.3), warm, 0.9, 4.5, false, true, 0.12)   # T-100: the tack wall's hook lantern (no shadows)
	_lamp("LoftLamp", Vector3(10.0, 5.45, 28.0), warm, 2.29, 11.0, false, true)
	_lamp("LoftHookLamp", Vector3(21.2, LOFT_TOP + 1.55, 30.9), warm, 2.1, 10.0, false, true, 0.12)   # on its hook by the stair head (T-084)
	_lamp("WreckFire", Vector3(45, 3.5, 5), Color(1.0, 0.45, 0.15), 8.0, 34.0, true, true)
	_lamp("WreckFire2", Vector3(42.5, 1.6, 6.8), Color(1.0, 0.4, 0.1), 3.0, 14.0, false, true)
	_lamp("HallSconce", Vector3(0.55, UP_Y + 1.8, 6.7), warm, 0.9, 6.5, false, true, 0.1)
	_lamp("HallSconce2", Vector3(23.45, UP_Y + 1.8, 8.0), warm, 0.9, 6.5, false, true, 0.1)
	_lamp("HallSconce3", Vector3(8.6, UP_Y + 1.8, HALL_Z0 + 0.55), warm, 1.0, 7.0, false, true, 0.1)
	_lamp("HallSconce4", Vector3(16.0, UP_Y + 1.8, HALL_Z0 + 0.55), warm, 1.0, 7.0, false, true, 0.1)
	_lamp("LoftSconce", Vector3(6.55, 5.25, 32.4), warm, 1.1, 7.0, false, true, 0.1)
	_lamp("OCAmmoLamp", Vector3(13.6, CELLAR_Y + 1.9, 15.45), Color(1.0, 0.68, 0.4), 1.0, 7.0, false, true, 0.12)
	_lamp("CellarLantern", Vector3(28.2, CELLAR_Y + 2.05, 25.0), Color(1.0, 0.7, 0.4), 1.8, 9.5, false, true, 0.1)
	# cold moonlight spilling through the taproom windows (no shadows; aimed through the openings)
	for wp: Array in [[Vector3(7.0, 3.7, -3.2), Vector3(7.0, 0.0, 3.6)], [Vector3(17.0, 3.7, -3.2), Vector3(17.0, 0.0, 3.6)],
			[Vector3(-3.2, 3.7, 6.0), Vector3(3.6, 0.0, 6.0)], [Vector3(27.2, 3.7, 8.0), Vector3(20.4, 0.0, 8.0)]]:
		var sp: SpotLight3D = SpotLight3D.new()
		sp.name = "MoonSpill"
		sp.position = wp[0]
		sp.light_color = Color(0.55, 0.65, 1.0)
		sp.light_energy = 6.0
		sp.light_volumetric_fog_energy = 3.5
		sp.spot_range = 10.0
		sp.spot_angle = 22.0
		sp.spot_attenuation = 1.1
		sp.shadow_enabled = true   # the barricade boards stripe the floor (and change as they're torn off)
		map_root.add_child(sp)
		sp.look_at_from_position(wp[0], wp[1], Vector3.UP)
	# and through the two guest-room windows upstairs (their pools also give the hall a little cold bounce, so the
	# Cousins' blackout there is dark, not black)
	for wp2: Array in [[Vector3(4.0, UP_Y + 3.4, -3.0), Vector3(4.0, UP_Y, 3.4)], [Vector3(20.0, UP_Y + 3.4, -3.0), Vector3(20.0, UP_Y, 3.4)]]:
		var su: SpotLight3D = SpotLight3D.new()
		su.name = "MoonSpillUp"
		su.light_color = Color(0.55, 0.65, 1.0)
		su.light_energy = 4.0
		su.light_volumetric_fog_energy = 2.5
		su.spot_range = 9.0
		su.spot_angle = 22.0
		su.spot_attenuation = 1.1
		map_root.add_child(su)
		su.look_at_from_position(wp2[0], wp2[1], Vector3.UP)
	_inn_bulbs()
	_follow_lights()
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


## The inn's electric bulbs (INN_BULBS): dark until the cellar lever's sweep reaches their zone, their lit glass
## under them (lit_glass.gd hides it whenever the bulb is out: the Cousins round, the sweep's flicker).
func _inn_bulbs() -> void:
	for b: Array in INN_BULBS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = str(b[0])
		l.position = (b[2] as Vector3) - Vector3(0, 0.08, 0)
		l.light_color = BULB_COLOR
		l.light_energy = float(b[4])
		l.omni_range = float(b[5])
		l.omni_attenuation = 1.4
		l.visible = false
		l.set_meta("zone", StringName(str(b[1])))
		l.set_meta("energy", float(b[4]))
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		var holder: Node3D = _bulb_lit.get(str(b[0]))
		if holder != null:
			holder.get_parent().remove_child(holder)
			l.add_child(holder)
			holder.position = -l.position


## Lights that belong to a lamp and follow its level (follow_light.gd): lamplight spilling out of the windows onto
## the snow (the inn reads as a warm refuge from the yard and the field, and goes dark from outside when the Cousins
## put the lamps out), the burning wreck through the taproom's east window, the candles on the tables.
func _follow_lights() -> void:
	var spill: Color = Color(1.0, 0.6, 0.3)
	# [window centre on its outer face, outward normal, source lamp, energy]
	for w: Array in [[Vector3(7.0, 1.55, -0.35), Vector3(0, 0, -1), "Hearthfire", 1.3], [Vector3(17.0, 1.55, -0.35), Vector3(0, 0, -1), "TapLamp2", 1.4],
			[Vector3(-0.35, 1.55, 6.0), Vector3(-1, 0, 0), "BarLamp", 1.2], [Vector3(24.35, 1.55, 8.0), Vector3(1, 0, 0), "TapLamp4", 1.2],
			[Vector3(4.0, UP_Y + 1.55, -0.35), Vector3(0, 0, -1), "Room1Lamp", 1.0], [Vector3(20.0, UP_Y + 1.55, -0.35), Vector3(0, 0, -1), "Room3Lamp", 1.0],
			[Vector3(9.0, 1.55, 21.65), Vector3(0, 0, -1), "StableLamp3", 0.9], [Vector3(14.0, 1.55, 21.65), Vector3(0, 0, -1), "StableLamp1", 0.9],
			[Vector3(12.0, 1.55, 34.35), Vector3(0, 0, 1), "StableLamp2", 1.0]]:
		var at: Vector3 = w[0]
		var out: Vector3 = w[1]
		var sp: SpotLight3D = _follower(SpotLight3D.new(), "WindowSpill", at, str(w[2]), float(w[3]) * 5.0, 0.0) as SpotLight3D
		sp.light_color = spill
		sp.spot_range = 10.0 + at.y
		sp.spot_angle = 50.0
		sp.spot_attenuation = 1.1
		sp.light_volumetric_fog_energy = 0.6
		sp.look_at_from_position(at, at + out * 2.2 + Vector3(0, -at.y * 0.55 - 0.4, 0), Vector3.UP)
		# the lit window itself, seen from outside between the barricade boards (pass 2): a warm card on the wall's
		# inner face, facing out (culled from inside), out of the GI, dimming with its lamp (follow_light.gd "Glow")
		var card: MeshInstance3D = MeshInstance3D.new()
		card.name = "Glow"
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.6, 1.3)
		card.mesh = q
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = Color.BLACK
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.6, 0.3)
		gm.emission_energy_multiplier = 4.0
		card.material_override = gm
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		sp.add_child(card)
		card.transform = sp.transform.affine_inverse() * Transform3D(Basis.looking_at(-out, Vector3.UP), at - out * 0.48)
	# GRAVELIGHT ONE burning in the field, through the east window (the wreck's own light is too far off to reach in)
	var ws: SpotLight3D = _follower(SpotLight3D.new(), "WreckSpill", Vector3(26.5, 2.7, 7.4), "WreckFire", 2.6, 0.0) as SpotLight3D
	ws.light_color = Color(1.0, 0.55, 0.2)
	ws.spot_range = 12.0
	ws.spot_angle = 18.0
	ws.spot_attenuation = 1.0
	ws.light_volumetric_fog_energy = 1.2
	ws.look_at_from_position(ws.position, Vector3(19.0, 0.2, 8.6), Vector3.UP)
	# the wreck's glow on the field and in the ground fog round it
	var wg: OmniLight3D = _follower(OmniLight3D.new(), "WreckGlow", Vector3(45.0, 7.0, 6.0), "WreckFire", 3.5, 0.0) as OmniLight3D
	wg.light_color = Color(1.0, 0.58, 0.26)
	wg.omni_range = 22.0
	wg.omni_attenuation = 0.9
	wg.light_volumetric_fog_energy = 2.0
	# the candles on the taproom tables and the guest rooms' nightstands
	for c: Array in [[Vector3(12.75, 0.95, 11.3), "TapLamp1"], [Vector3(16.75, 0.95, 11.3), "TapLamp3"], [Vector3(20.25, 0.95, 4.3), "TapLamp2"],
			[Vector3(19.24, 0.95, 8.82), "TapLamp3"], [Vector3(8.18, 0.95, 11.44), "TapLamp1"],   # the added tables (T-072)
			[Vector3(2.6, UP_Y + 0.85, 0.57), "Room1Lamp"], [Vector3(13.15, UP_Y + 0.85, 0.57), "Room2Lamp"], [Vector3(21.15, UP_Y + 0.85, 4.47), "Room3Lamp"]]:
		var cl: OmniLight3D = _follower(OmniLight3D.new(), "CandleLight", c[0], str(c[1]), 0.7, 0.18) as OmniLight3D
		cl.light_color = Color(1.0, 0.6, 0.28)
		cl.omni_range = 3.2
		cl.omni_attenuation = 1.5


## A follow_light.gd light at `pos` under the map root, following the lamp `source` (by name, under the map root).
func _follower(l: Light3D, name_: String, pos: Vector3, source: String, energy: float, flicker: float) -> Light3D:
	l.set_script(load("res://gravelight/maps/map00_crossroads/follow_light.gd"))
	l.name = name_
	l.position = pos
	l.set("source", NodePath("../" + source))
	l.set("full_energy", energy)
	l.set("own_flicker", flicker)
	l.light_energy = energy
	l.shadow_enabled = false
	map_root.add_child(l)
	return l


## Update 02 section 7 (T-052): the living world beyond the play space. Two runtime nodes, so the .tscn stays small:
## Landscape builds the terrain layers, sky, forests, roadside story, crash-site extras and the inn's weather details
## at load time (world/landscape/landscape.gd); MapAmbience runs the sky events, the distant war and the ambient
## life from data/gravelight/map00_ambience.json (world/landscape/map_ambience.gd). Neither collides.
func build_landscape() -> void:
	var land: Node3D = Node3D.new()
	land.set_script(load("res://gravelight/world/landscape/landscape.gd"))
	land.name = "Landscape"
	map_root.add_child(land)
	var amb: Node3D = Node3D.new()
	amb.set_script(load("res://gravelight/world/landscape/map_ambience.gd"))
	amb.name = "MapAmbience"
	amb.set("config_path", "res://data/gravelight/map00_ambience.json")
	map_root.add_child(amb)


## The few lanterns whose light the volumetric fog catches (a soft halo in the room's haze), T-061. Kept to a
## handful: every fog-lit light costs in the froxel pass.
const INNER_GAIN: float = 1.5
const LAMP_HALOS: Dictionary = {"OutPorchLamp": 1.0, "OutCrossLamp": 1.0, "TapLamp1": 0.5, "TapLamp2": 0.5, "TapLamp3": 0.5, "TapLamp4": 0.5, "HallLamp": 0.5,
	"StableLamp1": 0.5, "StableLamp2": 0.5, "PassLamp": 0.4, "YardDoorLamp": 1.2, "YardWallLamp": 1.2, "GateLantern": 1.2,
	"OCVaultLamp": 0.5, "OCWineLamp": 0.5, "CellarLantern": 0.5}


func _lamp(name_: String, pos: Vector3, color: Color, energy: float, range_: float, shadows: bool, flicker: bool, amount: float = 0.35) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	if flicker:
		l.set_script(load("res://gravelight/world/flicker_light.gd"))
		l.set("base_energy", energy)
		l.set("amount", amount)
	l.name = name_
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.6
	# T-061 pass 2: the inn's and the cellars' lamps throw wider, stronger pools and feed the GI bounce harder (the
	# flat ambient they used to sit in is gone under SDFGI); the yard's and the wreck's are tuned where they're built
	if not (name_.begins_with("Wreck") or name_.begins_with("Yard") or name_.begins_with("Gate") or name_.begins_with("Out")):
		energy *= INNER_GAIN
		l.light_energy = energy
		if flicker:
			l.set("base_energy", energy)
		l.omni_range = range_ * 1.25
		l.omni_attenuation = 1.25
		l.light_indirect_energy = 2.0
	# Only the big fires feed the volumetric fog; lanterns light surfaces (much cheaper).
	l.light_volumetric_fog_energy = 1.4 if (name_.begins_with("Hearth") or name_.begins_with("Wreck")) else float(LAMP_HALOS.get(name_, 0.0))
	l.shadow_enabled = shadows
	map_root.add_child(l)


# ================================================================== gameplay nodes

func _scripted(type_node: Node3D, script_path: String, name_: String, props: Dictionary) -> Node3D:
	type_node.set_script(load(script_path))
	type_node.name = name_
	for k: String in props.keys():
		type_node.set(k, props[k])
	return type_node


## windows: [id, zone, floor position on the wall line, inward yaw (deg)]
const WINDOWS: Array = [
		["W_TAP_N1", &"TAPROOM", Vector3(7.0, 0, 0), 0.0],
		["W_TAP_N2", &"TAPROOM", Vector3(17.0, 0, 0), 0.0],
		["W_TAP_W", &"TAPROOM", Vector3(0, 0, 6.0), 90.0],
		["W_TAP_E", &"TAPROOM", Vector3(24.0, 0, 8.0), -90.0],
		["W_UP_R1", &"UPSTAIRS", Vector3(4.0, UP_Y, 0), 0.0],
		["W_UP_R3", &"UPSTAIRS", Vector3(20.0, UP_Y, 0), 0.0],
		["W_ATT_W", &"UPSTAIRS", Vector3(0, ATT_Y, ATT_WIN_Z), 90.0],    # the attic's gable windows (T-224): their zombies stand on the hoist ledges
		["W_ATT_E", &"UPSTAIRS", Vector3(24.0, ATT_Y, ATT_WIN_Z), -90.0],
		["W_STB_N1", &"STABLE", Vector3(9.0, 0, 22.0), 0.0],
		["W_STB_N2", &"STABLE", Vector3(14.0, 0, 22.0), 0.0],
		["W_STB_S", &"STABLE", Vector3(12.0, 0, 34.0), 180.0],
		["W_STB_LOFT", &"STABLE", Vector3(22.0, LOFT_TOP, STB_Z1), 180.0],   # the loft door over the yard (T-084): its zombies stand on the hoist ledge
		["W_YARD_W", &"YARD", Vector3(2.0, 0, 41.0), 90.0],
		["W_YARD_E", &"YARD", Vector3(34.0, 0, 41.0), -90.0],
		["W_YARD_S1", &"YARD", Vector3(9.0, 0, 48.0), 180.0],
		["W_YARD_S2", &"YARD", Vector3(27.0, 0, 48.0), 180.0],
]


func build_gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", &"map00_crossroads")
	map_root.set("display_name", "Crossroads Inn")
	map_root.set("start_zone", &"TAPROOM")
	map_root.set("quest_files", PackedStringArray(["res://data/gravelight/quests/map00_radio.json"]))
	map_root.set("intro_text", "GASTHAUS ZUM KREUZWEG\n23 December 1944 · 9 km northwest of Kaltenbrunn")
	map_root.set("drop_bounds", Rect2(OUT_MIN, OUT_MAX - OUT_MIN))   # drops from a kill beyond the edge land inside it (T-084)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	# player spawns: the taproom's south end, facing north up the room (T-076). From PlayerSpawn1 the whole round 1
	# opening is in front of you: the bar and Trudi behind it (left), Sobotta at the counter's end, Frau Pohl by the
	# hearth, the carters' table (right) and the front door they run for (22 deg right; the porch where Kubiak and
	# Rother are caught is in line with the doorway). The old spawns (14..16, 7..9) stood among the patrons with
	# four of the five beside or behind the camera. The bots' spawns are behind and to the sides of the player's.
	var i: int = 1
	for p: Vector3 in [Vector3(14.5, 0, 13.4), Vector3(16.6, 0, 14.3), Vector3(12.4, 0, 14.3), Vector3(14.5, 0, 15.1)]:
		var ps: Marker3D = _scripted(Marker3D.new(), "res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}) as Marker3D
		ps.position = p
		gameplay.add_child(ps)
		i += 1

	var windows: Array = WINDOWS
	for w: Array in windows:
		var bar: Node3D = _scripted(Node3D.new(), "res://gravelight/world/barricade.gd", str(w[0]), {
			"window_id": StringName(str(w[0])), "zone_id": w[1], "width": 1.6, "sill_height": WIN_SILL, "top_height": WIN_TOP})
		bar.position = w[2]
		bar.rotation.y = deg_to_rad(float(w[3]))
		gameplay.add_child(bar)
		# T-080: the field spawns stay hidden from a player out on the grounds (not the ledges' or the yard's)
		var hide_m: float = 0.0 if (float((w[2] as Vector3).y) > 1.0 or str(w[0]) == "W_STB_S") else OUT_WINDOW_HIDE_M
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {
			"zone_id": w[1], "window_path": NodePath("../" + str(w[0])), "kind": &"window", "hide_from_m": hide_m}) as Marker3D
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		var out_dist: float = 1.6 if float((w[2] as Vector3).y) > 1.0 else 5.0
		var spawn_pos: Vector3 = (w[2] as Vector3) - inward * out_dist
		if float((w[2] as Vector3).y) > 1.0:
			if absf(absf(float(w[3])) - 90.0) < 1.0:
				spawn_pos.z -= 1.6   # the gable ledges run along z (T-224)
			else:
				spawn_pos.x += -1.6 if (w[2] as Vector3).x < 12.0 else 1.6   # ledge ends
		sp.position = spawn_pos
		gameplay.add_child(sp)
	# ground spawn: the hay pile behind the stalls (round 6+)
	var hay: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_HayPile", {
		"zone_id": &"STABLE", "kind": &"ground", "min_round": 6}) as Marker3D
	hay.position = Vector3(22.5, 0, 23.7)   # (the pile moved 0.4 m west for the stair's foot, T-084)
	gameplay.add_child(hay)
	# ground spawn: the drift in the yard's south-west corner (round 4+)
	var mound: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_YardMound", {
		"zone_id": &"YARD", "kind": &"ground", "min_round": 7}) as Marker3D
	mound.position = Vector3(5.0, 0, 44.5)
	gameplay.add_child(mound)

	# doors
	var d1: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Upstairs", {
		"door_id": &"door_upstairs", "opens_zone": &"UPSTAIRS", "cost": 750, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Upstairs"})
	d1.position = Vector3(STAIR_X1, 0, 15.1)
	d1.rotation.y = deg_to_rad(90)
	gameplay.add_child(d1)
	var d2: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Stable", {
		"door_id": &"door_stable", "opens_zone": &"STABLE", "cost": 1000, "size": Vector3(2.0, DOOR_H, 0.25), "label": "Stable"})
	d2.position = Vector3(20.0, 0, 16.0)
	gameplay.add_child(d2)
	var d4: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Yard", {
		"door_id": &"door_yard", "opens_zone": &"YARD", "cost": 1250, "size": Vector3(2.0, DOOR_H, 0.25), "label": "The Yard",
		"also_opens": PackedStringArray(["STABLE"])})   # (bought from the yard side, T-080: you walk into the stable)
	d4.position = Vector3(8.0, 0, 34.0)
	gameplay.add_child(d4)
	# the front door, the round 1 opening's patrons and the gramophone they leave playing on the bar (T-072)
	var fd: Node3D = _scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_front_door.gd", "InnFrontDoor", {"width": 1.6, "height": DOOR_H, "wall": T})
	fd.position = Vector3(FRONT_DOOR_X, 0, 0)
	gameplay.add_child(fd)
	build_grounds_gameplay()
	gameplay.add_child(_scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_opening.gd", "InnOpening", {}))
	var gram: Node3D = _scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_gramophone.gd", "InnGramophone", {"stop_round": 3})
	gram.position = Vector3(5.75, 1.1, BAR_Z1 + 0.4)
	gram.rotation.y = deg_to_rad(200.0)
	gameplay.add_child(gram)
	# the survivors hiding in the middle guest room until the stair door is opened (T-077, map00_survivors.json)
	gameplay.add_child(_scripted(Node3D.new(), "res://gravelight/world/inn_opening/inn_survivors.gd", "InnSurvivors", {}))

	build_cellar_gameplay()

	# wall-buys (BUYS), each with its lamp
	for b: Array in BUYS:
		var wb: Node3D = _scripted(Node3D.new(), "res://gravelight/world/wall_buy.gd", "WallBuy_" + String(b[0]), {"weapon_id": b[0]})
		wb.position = b[1]
		wb.rotation.y = deg_to_rad(float(b[2]))
		gameplay.add_child(wb)
		# a small warm lamp over each chalk outline so buys read at a glance
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "BuyLight"
		lamp.light_color = Color(1.0, 0.8, 0.55)
		lamp.light_energy = 0.6
		lamp.omni_range = 1.8
		lamp.position = (b[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(float(b[2]))) * Vector3(0, 0.75, -0.5)
		gameplay.add_child(lamp)

	# zones (spawn weighting)
	var zones: Array = [
		[&"TAPROOM", Vector3(12, 0, 8), Vector3(24, 3.5, 16)],
		[&"UPSTAIRS", Vector3(12, UP_Y - 0.2, 5), Vector3(24, 6.7, 10)],   # (up through the attic since T-224)
		[&"UPSTAIRS", Vector3(STAIR_X1 * 0.5, 0, 13), Vector3(STAIR_X1, 7, 6)],
		[&"STABLE", Vector3((STB_X0 + STB_X1) * 0.5, 0, 28), Vector3(STB_X1 - STB_X0, 7, 12)],
		[&"STABLE", Vector3(20, 0, 19), Vector3(4, 3, 6)],
		[&"YARD", Vector3(18, 0, 41), Vector3(32, 4, 14)],
		[&"YARD", Vector3(TOWER_X, TOWER_DECK, TOWER_Z), Vector3(6, TOWER_TOP - TOWER_DECK + 5.0, 6)],   # the watchtower's landing and top platform (T-229, T-268; a volume holds y from its origin - 0.5 up to + size.y)
	]
	for r: Array in OUT_ZONE_RECTS:   # T-080: the grounds, open ground (roam)
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		zones.append([&"GROUNDS", Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5), Vector3(b.x - a.x, 3.0, b.y - a.y), true])
	for r2: Array in OUT_WELL_RECTS:
		var a2: Vector2 = r2[0]
		var b2: Vector2 = r2[1]
		zones.append([&"GROUNDS", Vector3((a2.x + b2.x) * 0.5, OC_WELL_Y, (a2.y + b2.y) * 0.5), Vector3(b2.x - a2.x, 1.6, b2.y - a2.y), true])
	for pk: Rect2 in edge_pockets():   # the spawn pockets beyond the edge are open ground too (T-084)
		var pc: Vector2 = pk.get_center()
		zones.append([&"GROUNDS", Vector3(pc.x, 0, pc.y), Vector3(pk.size.x, 3.0, pk.size.y), true])
	var zi: int = 0
	for z: Array in zones:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [z[0], zi], {"zone_id": z[0], "size": z[2], "roam": z.size() > 3})
		zv.position = z[1]
		gameplay.add_child(zv)
		zi += 1

	# crate spots: [name, position, yaw (local -Z faces the room), can_start]. MAPS.md: start = Taproom or Stable.
	var ci: int = 0
	for c: Array in CRATES:
		var cr: Node3D = _scripted(Node3D.new(), "res://gravelight/world/mystery_crate.gd", "Crate_" + str(c[0]), {
			"spot_index": ci, "can_start": c[3], "spot_name": c[0]})
		cr.position = c[1]
		cr.rotation.y = deg_to_rad(float(c[2]))
		gameplay.add_child(cr)
		ci += 1
	for ab2: Array in AMMO_BOXES:
		var ammo: Node3D = _scripted(Node3D.new(), "res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_lower()})
		ammo.position = ab2[1]
		ammo.rotation.y = deg_to_rad(float(ab2[2]))
		gameplay.add_child(ammo)
	# T-126: Flt Lt Selwyn, pinned in GRAVELIGHT ONE's cockpit (TrappedPilot), facing out of the nose
	var pilot: Node3D = _scripted(Node3D.new(), "res://gravelight/world/trapped_pilot.gd", "TrappedPilot", {})
	pilot.transform = wreck_xf() * Transform3D(Basis.IDENTITY, WRECK_PILOT_SEAT)
	gameplay.add_child(pilot)
	var bench: Node3D = _scripted(Node3D.new(), "res://gravelight/world/armorers_bench.gd", "ArmorersBench", {})
	bench.position = ARMORERS_BENCH[0]
	bench.rotation.y = deg_to_rad(float(ARMORERS_BENCH[1]))
	gameplay.add_child(bench)
	var radio: Node3D = _scripted(Node3D.new(), "res://gravelight/world/field_radio.gd", "FieldRadio", {})
	radio.position = Vector3(SHELF_X1 - 0.2, 2.0, 4.9)   # on the back-bar's top board (T-224: the bar moved west)
	radio.rotation.y = deg_to_rad(-90)
	gameplay.add_child(radio)
	# radio notes (fixed spots, EASTER_EGGS.md section 4)
	for n: Array in [["NoteA", "note_a", "3.120", "I", Vector3(12.5, 1.51, 0.55)],
			["NoteB", "note_b", "5.785", "II", Vector3(11.0, UP_Y + 0.51, 0.85)],
			["NoteC", "note_c", "7.440", "III", Vector3(8.0, 3.51, 29.0)]]:
		var note: Node3D = _scripted(Node3D.new(), "res://gravelight/world/quest_note.gd", str(n[0]), {
			"tag": &"radio_note", "item_id": StringName(str(n[1])), "note_text": n[2], "numeral": n[3]})
		note.position = n[4]
		gameplay.add_child(note)


## T-080: a field spawn a player out on the grounds can see from within this far is not used (ZombieSpawn.hide_from_m;
## the edge's and the snow's are closer: they are farther from the loop).
const OUT_WINDOW_HIDE_M: float = 16.0


## The grounds' gameplay (T-080): the two ways out (the front door and the yard's gate, GateDoors that swing), the
## spawns at the edge and in the snow. The zone volumes are with the others in build_gameplay (OUT_ZONE_RECTS).
func build_grounds_gameplay() -> void:
	# Door_Front, "Out Front": the front door the round 1 opening's patrons run out of; once bought it is thrown open
	# for good (InnFrontDoor.held_open). The price is painted on the wall beside it.
	var df: Node3D = _scripted(Node3D.new(), "res://gravelight/world/gate_door.gd", "Door_Front", {
		"door_id": &"door_front", "opens_zone": &"GROUNDS", "cost": 1250, "size": Vector3(1.6, DOOR_H, T), "label": "Out Front",
		"swing_node": NodePath("../InnFrontDoor"), "swing_deg": 150.0, "label_offset": Vector3(1.45, 1.55, 0.0)})
	df.position = Vector3(FRONT_DOOR_X, 0, 0)
	gameplay.add_child(df)
	# Door_Gate: the carters' gate in the yard's south fence, 750, chained from the outside the night the plane came
	# down; it swings out onto the road and opens the yard as well when bought from the road
	var dg: Node3D = _scripted(Node3D.new(), "res://gravelight/world/gate_door.gd", "Door_Gate", {
		"door_id": &"door_gate", "opens_zone": &"GROUNDS", "also_opens": PackedStringArray(["YARD"]), "cost": 750,
		"size": Vector3(4.0, 2.3, 0.25), "label": "The Gate", "leaves": 2, "swing_deg": 100.0, "swing_out": 1.0})
	dg.position = Vector3(18.0, 0, 48.0)
	gameplay.add_child(dg)
	var i: int = 0
	for p: Vector3 in OUT_EDGE_SPAWNS:
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_Edge%d" % i, {
			"zone_id": &"GROUNDS", "kind": &"edge", "player_zone_only": true, "hide_from_m": 12.0}) as Marker3D
		sp.position = p
		gameplay.add_child(sp)
		i += 1
	i = 0
	for p2: Vector3 in OUT_GROUND_SPAWNS:
		var gs: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_Snow%d" % i, {
			"zone_id": &"GROUNDS", "kind": &"ground", "min_round": 4, "player_zone_only": true, "hide_from_m": 10.0}) as Marker3D
		gs.position = p2
		gameplay.add_child(gs)
		i += 1
	# the lamps out here: the porch lantern over the front door, the two lamp posts, the woodshed's, and a cold moon
	# fill over each side of the field (like the yard's)
	var warm: Color = Color(1.0, 0.62, 0.32)
	_lamp("OutPorchLamp", Vector3(21.2, 2.55, -1.9), warm, 3.5, 12.0, false, true, 0.15)
	_lamp("OutCrossLamp", Vector3(-6.95, 2.4, -4.6), warm, 4.0, 13.0, false, true, 0.2)
	_lamp("OutRoadLamp", Vector3(37.65, 2.4, -10.8), warm, 3.5, 12.0, false, true, 0.2)
	_lamp("OutShedLamp", Vector3(-3.0, 1.95, 56.35), warm, 3.5, 11.0, false, true, 0.15)
	for mf: Vector3 in [Vector3(20, 6, -18), Vector3(-11, 6, 24), Vector3(18, 6, 57), Vector3(48, 6, 38)]:
		_lamp("OutMoonFill", mf, Color(0.5, 0.6, 0.85), 0.25, 24.0, false, false)


## Door 3 (1500) -> the Helvetia cellar, a coal chute that starts spawning at round 6. T&C M2, DECISIONS T-027.
## T-251: the machines stand on PERK_SPOTS all over the map now (build_perk_gameplay), and the cellar lever (Map 0's
## power), the Crucible and the power-on burst points are two more doors down (build_deep_cellar_gameplay).
func build_cellar_gameplay() -> void:
	var cy: float = CELLAR_Y
	var d3: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Cellar", {
		"door_id": &"door_cellar", "opens_zone": &"CELLAR", "cost": 1500, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Cellar"})
	d3.position = Vector3(24.0, 0, 11.5)
	d3.rotation.y = deg_to_rad(90)
	gameplay.add_child(d3)
	for z: Array in [[Vector3(26, cy, 14.5), Vector3(4, 6.5, 9)], [Vector3(30, cy, 25), Vector3(12, 2.7, 12)],   # top stays under the ceiling, so the yard above is not "cellar"
			[Vector3((BAY_X0 + BAY_X1) * 0.5, cy, (BAY_Z0 + BAY_Z1) * 0.5), Vector3(BAY_X1 - BAY_X0, 2.7, BAY_Z1 - BAY_Z0)]]:   # T-179: the late-delivery bay
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_CELLAR", {"zone_id": &"CELLAR", "size": z[1]})
		zv.position = z[0]
		gameplay.add_child(zv)
	build_deep_cellar_gameplay()
	# lights: one oil lamp at the foot of the stairs always lit; the vault's bulbs wait for the lever
	_lamp("CellarHallLamp", Vector3(26.0, 2.5, 10.8), Color(1.0, 0.72, 0.45), 1.0, 7.0, false, true)
	_lamp("CellarStairLamp", Vector3(26.0, cy + 2.3, 19.6), Color(1.0, 0.7, 0.4), 1.0, 6.5, false, true)
	# T-179: the late-delivery bay's oil lantern by the arch, always lit, so its two machines read before the lever
	# (T-255: two, with a steady flame: BAY_LAMPS)
	for bl: Array in BAY_LAMPS:
		_lamp(str(bl[0]), (bl[1] as Vector3) - Vector3(0, 0.2, 0), Color(1.0, 0.7, 0.42), float(bl[2]), float(bl[3]), false, true, 0.12)
	var first_bulb: OmniLight3D = null
	for lp: Vector3 in CELLAR_BULBS + [BAY_BULB]:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "CellarBulb"
		l.position = lp - Vector3(0, 0.05, 0)
		l.light_color = Color(1.0, 0.85, 0.6)
		l.light_energy = 1.5
		l.omni_range = 7.5 if lp != BAY_BULB else 5.5   # (the bay's: no reach back through the wall onto the east row)
		l.omni_attenuation = 1.4
		l.visible = false
		l.set_meta("zone", &"CELLAR")
		l.set_meta("energy", 1.5)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		if first_bulb == null:
			first_bulb = l
	# the lit bulb glass rides under the first bulb light, so it shows when the sweep turns the lights on
	if _cellar_lit != null and first_bulb != null:
		_cellar_lit.get_parent().remove_child(_cellar_lit)
		first_bulb.add_child(_cellar_lit)
		_cellar_lit.position = -first_bulb.position
	# the coal chute: a ground spawn in the far corner from round 6
	var chute: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_CoalChute", {
		"zone_id": &"CELLAR", "kind": &"ground", "min_round": 6}) as Marker3D
	chute.position = Vector3(34.2, cy, 29.6)
	gameplay.add_child(chute)
	build_perk_gameplay()
	build_old_cellar_gameplay()


## T-251: the Lagering Vault's and the Dynamo Room's gameplay: Door_Lager (750) and Door_Dynamo (1000), their zones,
## the Crucible in its alcove on the Dynamo Room's north wall (facing south into the room, running off the lever like
## the machines), the cellar lever 3 m east of it (the sweep starts in its own room and works back up to the inn), a
## ground spawn in each room from round 4 (a floor drain by the tuns, the generator's sump: with the lever three doors
## deep the dead must not have one way in only), the power-on burst points, an oil lantern inside each door that is
## always lit, and the bulbs that wait for the lever.
func build_deep_cellar_gameplay() -> void:
	var cy: float = CELLAR_Y
	var da: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Lager", {
		"door_id": &"door_lager", "opens_zone": &"LAGERKELLER", "cost": 750, "size": Vector3(LAG_DOOR.y - LAG_DOOR.x, DOOR_H, 0.25), "label": "Lagering Vault"})
	da.position = Vector3((LAG_DOOR.x + LAG_DOOR.y) * 0.5, cy, LAG_Z0)
	gameplay.add_child(da)
	var db: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_Dynamo", {
		"door_id": &"door_dynamo", "opens_zone": &"MASCHINENRAUM", "cost": 1000, "size": Vector3(DYN_DOOR.y - DYN_DOOR.x, DOOR_H, 0.25), "label": "Dynamo Room"})
	db.position = Vector3(DYN_X0, cy, (DYN_DOOR.x + DYN_DOOR.y) * 0.5)
	db.rotation.y = deg_to_rad(90)
	gameplay.add_child(db)
	for z: Array in [[&"LAGERKELLER", Vector3((LAG_X0 + LAG_X1) * 0.5, cy, (LAG_Z0 + LAG_Z1) * 0.5), Vector3(LAG_X1 - LAG_X0, 2.7, LAG_Z1 - LAG_Z0)],   # tops under the ceiling: the yard above is not "cellar"
			[&"MASCHINENRAUM", Vector3((DYN_X0 + DYN_X1) * 0.5, cy, (DYN_Z0 + DYN_Z1) * 0.5), Vector3(DYN_X1 - DYN_X0, 2.7, DYN_Z1 - DYN_Z0)]]:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_%s" % z[0], {"zone_id": z[0], "size": z[2]})
		zv.position = z[1]
		gameplay.add_child(zv)
	var cru: Node3D = _scripted(Node3D.new(), "res://gravelight/world/crucible.gd", "Crucible", {"needs_power": true})
	cru.position = DYN_CRUCIBLE
	cru.rotation.y = deg_to_rad(180.0)
	gameplay.add_child(cru)
	var sw: Node3D = _scripted(Node3D.new(), "res://gravelight/world/power_switch.gd", "Kellerschalter", {
		"config_table": "map00", "label": "the cellar lever",
		"zone_order": PackedStringArray(["MASCHINENRAUM", "LAGERKELLER", "CELLAR", "OLD_CELLAR", "TAPROOM", "UPSTAIRS", "STABLE"])})
	sw.position = DYN_LEVER
	sw.rotation.y = deg_to_rad(180)
	gameplay.add_child(sw)
	for dl: Array in DEEP_LAMPS:   # T-255: two always-lit lanterns a room (they were one of 0.9 over 6 m each)
		_lamp(str(dl[0]), (dl[1] as Vector3) - Vector3(0, 0.15, 0), Color(1.0, 0.7, 0.41), float(dl[2]), float(dl[3]), false, true, 0.12)
	for set_: Array in [[LAG_BULBS, &"LAGERKELLER", "LagerBulb", _lager_lit], [DYN_BULBS, &"MASCHINENRAUM", "DynamoBulb", _dynamo_lit]]:
		var first: OmniLight3D = null
		for lp: Vector3 in (set_[0] as Array):
			var l: OmniLight3D = OmniLight3D.new()
			l.name = str(set_[2])
			l.position = lp - Vector3(0, 0.05, 0)
			l.light_color = Color(1.0, 0.85, 0.6)
			l.light_energy = 1.5
			l.omni_range = 6.5
			l.omni_attenuation = 1.4
			l.visible = false
			l.set_meta("zone", set_[1])
			l.set_meta("energy", 1.5)
			l.add_to_group(&"power_lights", true)
			map_root.add_child(l)
			if first == null:
				first = l
		var lit: Node3D = set_[3] as Node3D
		if lit != null and first != null:   # the lit glass rides under the room's first bulb light (as the vault's)
			lit.get_parent().remove_child(lit)
			first.add_child(lit)
			lit.position = -first.position
	var spawns: Array = [["Spawn_LagerDrain", &"LAGERKELLER", Vector3(32.9, cy, 32.1)], ["Spawn_DynamoSump", &"MASCHINENRAUM", Vector3(35.2, cy, 37.9)]]
	for s: Array in spawns:
		var gs: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", str(s[0]), {
			"zone_id": s[1], "kind": &"ground", "min_round": 4}) as Marker3D
		gs.position = s[2]
		gameplay.add_child(gs)
		var mk: Marker3D = Marker3D.new()
		mk.name = "BurstPoint"
		mk.position = s[2]
		mk.add_to_group(&"power_burst_points", true)
		gameplay.add_child(mk)
	for dp: Vector3 in [Vector3(30.05, CELLAR_TOP - 0.02, 32.6), Vector3(36.1, CELLAR_TOP - 0.02, 38.0)]:
		var drip: Node3D = _scripted(Node3D.new(), "res://gravelight/world/drip_point.gd", "Drip", {"height": CELLAR_TOP - 0.02 - cy})
		drip.position = dp
		gameplay.add_child(drip)


## T-251: the perk spots (PerkSpot: its filler crate shows while no machine stands on it) and the twelve machines on
## the seed-0 deal (PerkShuffle.assign with perk_layout.json's rules, the same call PerkLayout makes each match).
func build_perk_gameplay() -> void:
	var spots: Array = []
	for sp: Array in PERK_SPOTS:
		var flags: Dictionary = sp[4]
		var ps: Node3D = _scripted(Node3D.new(), "res://gravelight/world/perk_spot.gd", "PerkSpot_" + str(sp[0]), {
			"spot_id": StringName(str(sp[0])), "zone_id": StringName(str(sp[1])), "outdoor": bool(flags.get("outdoor", false)),
			"start": bool(flags.get("start", false)), "near": bool(flags.get("near", false)), "flush": int(flags.get("flush", 0))})
		ps.position = sp[2]
		ps.rotation.y = deg_to_rad(float(sp[3]))
		gameplay.add_child(ps)
		spots.append({"id": str(sp[0]), "zone": str(sp[1]), "outdoor": bool(flags.get("outdoor", false)), "start": bool(flags.get("start", false)),
			"near": bool(flags.get("near", false))})
	var pdata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json"))["perks"]
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perk_layout.json"))
	var perks: Array = []
	for pid: String in (rules.get("maps", {}) as Dictionary).get("map00", {}).get("perks", []):
		perks.append({"id": pid, "cost": int((pdata[pid] as Dictionary).get("cost", 0)), "shape": str((pdata[pid] as Dictionary).get("shape", "cabinet"))})
	var deal: Dictionary = PerkShuffleScript.call("assign", 0, spots, perks, rules)
	for pk: Dictionary in perks:
		var sid: String = str(deal.get(pk["id"], ""))
		var at: Array = []
		for sp2: Array in PERK_SPOTS:
			if str(sp2[0]) == sid:
				at = sp2
		if at.is_empty():
			push_error("gen_map00: no spot dealt to %s" % pk["id"])
			continue
		var m: Node3D = _scripted(Node3D.new(), "res://gravelight/world/perk_machine.gd", "Perk_" + str(pk["id"]), {"perk_id": StringName(str(pk["id"]))})
		m.position = at[2]
		m.rotation.y = deg_to_rad(float(at[3]))
		if int((at[4] as Dictionary).get("flush", 0)) != 0:   # T-255: back on the wall (PerkSpot.stand_transform does the same each match)
			var fpz: float = (MACHINE_FOOTPRINTS.get(str(pk["shape"]), Vector3(1.0, 2.0, 0.7)) as Vector3).z
			var off: Vector3 = Basis(Vector3.UP, m.rotation.y) * Vector3(0, 0, maxf(0.0, (PERK_SPOT_D - fpz) * 0.5))
			# (to the millimetre, so the saved number is the decimal's own float: the minimap bake's POI signature rounds
			# to decimetres, and 0.85 - 0.3 a hair under 0.55 hashed differently from the 0.55 mapdata.json reads back)
			m.position = Vector3(snappedf(m.position.x + off.x, 0.001), m.position.y, snappedf(m.position.z + off.z, 0.001))
		gameplay.add_child(m)
	print("perk spots: %d, machines: %d (seed-0 deal: %s)" % [PERK_SPOTS.size(), perks.size(), str(deal)])


## The Old Cellar's gameplay (T-051): Door 5, the breach to the Helvetia cellar, the zone,
## the two light-well windows and their field spawns, the Gewehr 43, the holding cell's nodes
## for Jakub (section 6.2), the ice cellar's seal and markers for HB1, drips, lanterns and the power bulbs.
func build_old_cellar_gameplay() -> void:
	var cy: float = CELLAR_Y
	var top: float = CELLAR_TOP
	var d5: Node3D = _scripted(Node3D.new(), "res://gravelight/world/door.gd", "Door_OldCellar", {
		"door_id": &"door_old_cellar", "opens_zone": &"OLD_CELLAR", "cost": 1250, "size": Vector3(1.6, DOOR_H, 0.25), "label": "Old Cellar"})
	d5.position = Vector3(0.0, 0, 9.05)
	d5.rotation.y = deg_to_rad(90)
	gameplay.add_child(d5)
	# T-229: the cellar hatch behind the bar, over the aunt's ladder: its leaf is bolted until this zone opens; the climbs
	# through it are map00.json's ladders, the zombies' way its climb link
	var td: Node3D = _scripted(Node3D.new(), "res://gravelight/world/trapdoor.gd", "CellarTrapdoor",
		{"zone": &"OLD_CELLAR", "size": Vector2(HATCH_X1 - HATCH_X0, HATCH_Z1 - HATCH_Z0)})
	td.position = Vector3((HATCH_X0 + HATCH_X1) * 0.5, 0, (HATCH_Z0 + HATCH_Z1) * 0.5)
	gameplay.add_child(td)
	# the installers' breach to the Helvetia cellar: bricked up again until both cellars are open (Door 3 and Door 5),
	# then it falls in by itself. The map's navmesh ("Navigation") is baked with the breach shut; when it opens it
	# swaps to "NavigationBreachOpen" (the same bake with the breach open), so no path ever runs through the breach
	# while a door on the taproom / cellar / old cellar ring is still shut. (A NavigationLink3D across it was tried:
	# zombies re-pathing inside the cut snapped back to the near side and dithered in the doorway.)
	var br: Node3D = _scripted(Node3D.new(), "res://gravelight/world/sealed_passage.gd", "CellarBreach", {
		"passage_id": &"cellar_breach", "size": Vector3(1.6, DOOR_H, 0.3),
		"open_when_zones": PackedStringArray(["CELLAR", "OLD_CELLAR"]),
		"nav_swap_off": NodePath("../../Navigation"), "nav_swap_on": NodePath("../../NavigationBreachOpen")})
	br.position = Vector3(24.0, cy, 20.25)
	br.rotation.y = deg_to_rad(90)
	gameplay.add_child(br)
	# zone volumes: under the taproom, the wine cellar's south bay, the breach, the stair lean-to (tops kept under
	# the taproom's floor, so the taproom above is not "old cellar")
	for z: Array in [[Vector3(12.0, cy, 8.0), Vector3(24.0, 2.7, 16.0)], [Vector3(5.45, cy, 17.25), Vector3(10.9, 2.7, 2.5)],
			[Vector3(22.43, cy, 18.7), Vector3(3.15, 2.7, 5.2)], [Vector3(-1.5, cy, 13.25), Vector3(3.0, 6.0, 10.5)]]:
		var zv: Node3D = _scripted(Node3D.new(), "res://gravelight/world/zone_volume.gd", "Zone_OLD_CELLAR", {"zone_id": &"OLD_CELLAR", "size": z[1]})
		zv.position = z[0]
		gameplay.add_child(zv)
	# the light-well windows: half-height crawl-ins, the room floor 1.9 m below the sill (Barricade.inside_drop);
	# [id, origin on the well floor at the wall line, inward yaw, field spawn at the top of the well steps]
	for w: Array in [["W_CEL_COAL", Vector3(3.45, OC_WELL_Y, 0.0), 0.0, Vector3(3.45, 0, -7.5)],
			["W_CEL_VAULT", Vector3(24.0, OC_WELL_Y, 1.8), -90.0, Vector3(25.2, 0, -5.5)]]:
		var bar: Node3D = _scripted(Node3D.new(), "res://gravelight/world/barricade.gd", str(w[0]), {
			"window_id": StringName(str(w[0])), "zone_id": &"OLD_CELLAR", "width": 1.6, "sill_height": OC_SILL,
			"top_height": OC_WIN_H, "inside_drop": OC_WELL_Y - cy})
		bar.position = w[1]
		bar.rotation.y = deg_to_rad(float(w[2]))
		gameplay.add_child(bar)
		var sp: Marker3D = _scripted(Marker3D.new(), "res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {
			"zone_id": &"OLD_CELLAR", "window_path": NodePath("../" + str(w[0])), "kind": &"window"}) as Marker3D
		sp.position = w[3]
		gameplay.add_child(sp)
	# the wall-buy: the M1 Garand (taproom) and the Thompson (yard) are already on the map, so the patrol's Gewehr 43
	# hangs on the vault's west wall, facing the loop
	var wb: Node3D = _scripted(Node3D.new(), "res://gravelight/world/wall_buy.gd", "WallBuy_gewehr43", {"weapon_id": &"gewehr43"})
	wb.position = Vector3(10.9 + T * 0.5 + 0.04, cy + 1.5, 6.6)
	wb.rotation.y = deg_to_rad(-90)
	gameplay.add_child(wb)
	var bl: OmniLight3D = OmniLight3D.new()
	bl.name = "BuyLight"
	bl.light_color = Color(1.0, 0.8, 0.55)
	bl.light_energy = 0.6
	bl.omni_range = 1.8
	bl.position = wb.position + Vector3(0.5, 0.75, 0)
	gameplay.add_child(bl)
	# (the ammo box is AMMO_BOXES "Cellar", on the vault's south wall, 11 m+ from the machines and the Crucible)
	# the holding cell (section 6.2): the cage's hinged door is a HoldingCage (origin on the hinge, local +X along the
	# door, local -Z out of the cage); Jakub stands inside at JakubSpawn and waits by the cage at JakubWait
	var cage: Node3D = _scripted(Node3D.new(), "res://gravelight/world/holding_cage.gd", "JakubCage", {
		"door_width": OC_CAGE_DOOR.y - OC_CAGE_DOOR.x, "door_height": top - cy})
	cage.position = Vector3(OC_CAGE.end.x, cy, OC_CAGE_DOOR.x)
	cage.rotation.y = deg_to_rad(-90)
	gameplay.add_child(cage)
	_cage_door(cage)
	for m: Array in [["JakubSpawn", Vector3(1.25, cy, 4.9), 90.0], ["JakubWait", Vector3(3.95, cy, 6.3), -90.0]]:
		var mk: Marker3D = Marker3D.new()
		mk.name = str(m[0])
		mk.position = m[1]
		mk.rotation.y = deg_to_rad(float(m[2]))   # facing out of the cage / toward the cellar door
		gameplay.add_child(mk)
	var shovel: Node3D = Props.group(gameplay, "CoalShovel", Vector3(2.78, cy, 3.62), 0.0)
	Props.obox(shovel, Vector3(0, 0.62, 0.08), Vector3(0.035, 1.1, 0.035), "beam", Vector3(-14, 0, 0))
	Props.obox(shovel, Vector3(0, 0.08, -0.06), Vector3(0.26, 0.02, 0.3), "iron", Vector3(-14, 0, 0))
	Props.obox(shovel, Vector3(0, 1.16, 0.22), Vector3(0.14, 0.04, 0.04), "beam", Vector3(-14, 0, 0))
	# the ice cellar: bricked off from the coal room until the Cousins round is cleared (HB1 files the aunt's letter,
	# INT_HB_01, on the clear; the seal falls in on that cue). Markers for HB1's letter, chalk figures and hatch.
	var seal: Node3D = _scripted(Node3D.new(), "res://gravelight/world/sealed_passage.gd", "IceCellarSeal", {
		"passage_id": &"ice_cellar", "size": Vector3(1.6, 2.0, 0.3), "open_on_intel": &"INT_HB_01"})
	seal.position = Vector3(5.0, cy, 6.7)
	seal.rotation.y = deg_to_rad(90)
	gameplay.add_child(seal)
	for m2: Array in [["IceCellarLetter", Vector3(7.55, cy + 0.42, 7.35)], ["IceCellarChalk", Vector3(8.13, cy + 1.25, 6.3)],
			["IceCellarHatch", Vector3(6.6, top, 5.6)]]:
		var mk2: Marker3D = Marker3D.new()
		mk2.name = str(m2[0])
		mk2.position = m2[1]
		gameplay.add_child(mk2)
	# water dripping from the vault and the wine cellar's arches (sound + a falling drop)
	for dp: Vector3 in [Vector3(6.9, top - 0.02, 15.3), Vector3(1.7, top - 0.02, 11.4), Vector3(20.6, top - 0.02, 4.4), Vector3(9.5, top - 0.02, 3.3)]:
		var drip: Node3D = _scripted(Node3D.new(), "res://gravelight/world/drip_point.gd", "Drip", {"height": top - 0.02 - cy})
		drip.position = dp
		gameplay.add_child(drip)
	# lights: oil lanterns always lit (the stair, wine cellar, root cellar, the guard's lamp by the cage, the vault);
	# bare bulbs over the loop and the wine cellar wait for the cellar lever (zone OLD_CELLAR in the sweep)
	var warm: Color = Color(1.0, 0.68, 0.4)
	for l: Array in [["OCStairLamp", Vector3(-1.5, 1.85, 12.6), 1.0, 7.0], ["OCStairFootLamp", Vector3(-2.45, cy + 2.1, 17.0), 0.9, 6.5],
			["OCWineLamp", Vector3(5.4, cy + 1.95, 10.7), 1.5, 9.0], ["OCWineLamp2", Vector3(4.0, cy + 1.95, 16.0), 1.2, 8.0],
			["OCRootLamp", Vector3(7.6, cy + 1.95, 2.7), 1.2, 7.5], ["OCCageLamp", Vector3(3.9, cy + 2.0, 3.9), 1.5, 8.0],
			["OCVaultLamp", Vector3(13.4, cy + 2.05, 8.0), 1.6, 10.0], ["OCVaultLamp2", Vector3(21.6, cy + 2.05, 8.0), 1.6, 10.0],
			["OCBreachLamp", Vector3(22.4, cy + 2.1, 19.6), 0.8, 6.0]]:
		_lamp(str(l[0]), l[1], warm, float(l[2]), float(l[3]), false, true, 0.12)
	for bp: Vector3 in OC_BULBS:
		var b: OmniLight3D = OmniLight3D.new()
		b.name = "OldCellarBulb"
		b.position = bp - Vector3(0, 0.05, 0)
		b.light_color = Color(1.0, 0.85, 0.6)
		b.light_energy = 1.3
		b.omni_range = 7.0
		b.omni_attenuation = 1.4
		b.visible = false
		b.set_meta("zone", &"OLD_CELLAR")
		b.set_meta("energy", 1.3)
		b.add_to_group(&"power_lights", true)
		map_root.add_child(b)
		if _old_cellar_lit != null and _old_cellar_lit.get_parent() == dress:
			dress.remove_child(_old_cellar_lit)
			b.add_child(_old_cellar_lit)
			_old_cellar_lit.position = -b.position
	# cold moonlight down each light well, through the boards (the windows read from across the room)
	# (T-061: brighter, shadowed so the window's boards stripe it, the coal well's aimed into the cage)
	for wp: Array in [[Vector3(3.45, 0.9, -2.2), Vector3(2.3, cy, 3.9)], [Vector3(26.0, 0.9, 1.8), Vector3(21.4, cy, 1.8)]]:
		var sp2: SpotLight3D = SpotLight3D.new()
		sp2.name = "WellMoonSpill"
		sp2.light_color = Color(0.55, 0.65, 1.0)
		sp2.light_energy = 4.5
		sp2.light_volumetric_fog_energy = 2.5
		sp2.spot_range = 9.0
		sp2.spot_angle = 26.0
		sp2.spot_attenuation = 1.0
		sp2.shadow_enabled = true
		map_root.add_child(sp2)
		sp2.look_at_from_position(wp[0], wp[1], Vector3.UP)


## The holding cell's door leaf under the HoldingCage (local frame: +X from the hinge to the latch, -Z out of the
## cage): flat bars, two straps, the hinge knuckles, a hasp with a padlock. Kept off the static batch (meta "keep").
func _cage_door(cage: Node3D) -> void:
	var w: float = OC_CAGE_DOOR.y - OC_CAGE_DOOR.x
	var h: float = CELLAR_TOP - CELLAR_Y
	var hinge: Node3D = Props.group(cage, "Hinge", Vector3.ZERO)
	var n: int = int(w / 0.13)
	for k: int in n:
		var x: float = 0.08 + float(k) * (w - 0.16) / float(maxi(1, n - 1))
		Props.cyl(hinge, Vector3(x, h * 0.5, 0), 0.014, h - 0.06, "iron")
	for y: float in [0.12, 1.05, h - 0.12]:
		Props.block(hinge, Vector3(0.0, y - 0.03, -0.02), Vector3(w, y + 0.03, 0.02), "iron")
	for y2: float in [0.4, h - 0.5]:
		Props.cyl(hinge, Vector3(0.0, y2, 0), 0.03, 0.14, "iron")
	Props.block(hinge, Vector3(w - 0.12, 1.0, -0.05), Vector3(w - 0.02, 1.12, 0.0), "iron")   # the hasp
	Props.block(hinge, Vector3(w - 0.1, 0.86, -0.07), Vector3(w - 0.03, 0.98, -0.04), "brass")   # the padlock
	for m: Node in hinge.find_children("*", "MeshInstance3D", true, false):
		m.set_meta("keep", true)

