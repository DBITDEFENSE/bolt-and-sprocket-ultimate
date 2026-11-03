extends SceneTree
## Shared generator base for the four Map 4 "Fernflug" acts (UPDATE 07, docs/MAP4_FERNFLUG.md §14): the greybox
## helpers, the per-zone navmesh bake, static batching, lighting and the generic gameplay placement, lifted from
## gen_map02.gd so every act generator is only its tables and its rooms. An act generator `extends` this script,
## fills the tables in `_initialize()` (zone_bits, adj, zone_boxes, links, windows, buys, doors, ammo_boxes,
## grounds, catwalks, perks, crates, ...), builds its rooms into `geo`, and the base does the rest in `_process`.
## Usage: godot --headless --path . --script res://gravelight/tools_src/gen_map04a.gd
## Frame: +X east, +Z north (the hangar end), y up. Layers as gen_map02: Geometry / Dressing / StaticBatches /
## lights / Gameplay.

const T: float = 0.3
const SILL: float = 0.9
const WTOP: float = 2.2
const DOOR_H: float = 2.4
const SODIUM: Color = Color(1.0, 0.66, 0.36)
const MERCURY: Color = Color(0.72, 0.84, 1.0)
const INCAND: Color = Color(1.0, 0.78, 0.55)
const RED: Color = Color(1.0, 0.22, 0.14)
const VIOLET: Color = Color(0.62, 0.28, 1.0)
const MOONLIGHT: Color = Color(0.55, 0.66, 0.95)
const FIRE: Color = Color(1.0, 0.55, 0.22)
const POWER_GAIN: float = 2.2
const LAMP_GAIN: float = 1.7

# ---- tables the act fills in _initialize (see gen_map02.gd for the row shapes)
var out_path: String = ""
var root_name: String = "Map04"
var map_id: String = ""
var display_name: String = ""
var start_zone: String = ""
var intro_text: String = ""
var json_table: String = ""          # "map04a": the act's data/gravelight/<json_table>.json
var zone_bits: Dictionary = {}
var adj: Dictionary = {}
var zone_boxes: Array = []            # [zone, min, max]
var links: Array = []                 # [from, to, zone]
var windows: Array = []               # [id, zone, pos, inward yaw]
var buys: Array = []                  # [weapon, pos, yaw]
var doors: Array = []                 # [name, door_id, zone, also, link_group, cost, label, pos, yaw, width, needs_power]
var ammo_boxes: Array = []            # [name, pos, yaw]
var grounds: Array = []               # [zone, pos, min_round]
var catwalks: Array = []              # [zone, pos, enabled]  (named Catwalk_<zone>_<i>, kind ground)
var perks: Array = []                 # [perk, pos, yaw]
var crates: Array = []                # [name, pos, yaw, can_start, route]
var player_spawns: Array = []         # [pos, yaw]
var power_switch: Dictionary = {}     # {name, label, pos, yaw, zone_order, config_table}
var crucible: Dictionary = {}         # {pos, yaw, needs_power}
var armorers_bench: Array = []         # [pos, yaw]
var burst_points: Array = []
var traps: Array = []                 # [script, name, props, pos, yaw, lever_pos, lever_yaw, trap_id]
var mat_map: Dictionary = {}
var mat_rules: Array = []
var hide: Array = []
var stage_windows: Array = []
var sky_top: Color = Color(0.006, 0.009, 0.02)
var sky_horizon: Color = Color(0.04, 0.05, 0.075)
var ambient: Color = Color(0.22, 0.27, 0.36)
var fog_color: Color = Color(0.11, 0.13, 0.17)
var moon_rot: Vector3 = Vector3(-42, -150, 0)
var extra_root_nodes: Array = []      # Node3Ds the act adds to the root after the bake (kept out of batching)

var map_root: Node3D
var geo: Node3D
var dress: Node3D
var gameplay: Node3D
var _count: int = 0
var _frames: int = 0
var _closets: Array = []
var _stairs: Array = []
var _glow: Dictionary = {}
var _power: Array = []
var _static_lights: Array = []
var _spots: Array = []
var _fogs: Array = []


func _initialize() -> void:
	setup_tables()
	map_root = Node3D.new()
	map_root.name = root_name
	get_root().add_child(map_root)
	geo = Node3D.new()
	geo.name = "Geometry"
	map_root.add_child(geo)
	dress = Node3D.new()
	dress.name = "Dressing"
	map_root.add_child(dress)
	build_geometry()
	build_closets()
	for ab: Array in ammo_boxes:
		var ah: Vector3 = Vector3(0.52, 0, 0.3) if absf(float(ab[2])) != 90.0 else Vector3(0.3, 0, 0.52)
		box(geo, "NavBlock_Ammo_" + str(ab[0]), (ab[1] as Vector3) - ah, (ab[1] as Vector3) + ah + Vector3(0, 0.62, 0), "metal")
	for p: Array in perks:
		var pp: Vector3 = p[1]
		box(geo, "NavBlock_Perk_" + str(p[0]), pp + Vector3(-0.7, 0, -0.5), pp + Vector3(0.7, 2.0, 0.5), "metal")
	# T-141: the savings bank's counter, teller and safe (data/gravelight/bank.json "branches", nav_block): the navmesh goes round
	var bank_rows: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/bank.json")) as Dictionary).get("branches", {})
	for bk: Variant in bank_rows.keys():
		if map_id.begins_with(str(bk)) and (bank_rows[bk] as Dictionary).has("nav_block"):
			var nb: Array = bank_rows[bk]["nav_block"]
			box(geo, "NavBlock_Bank", Vector3(float(nb[0][0]), float(nb[0][1]), float(nb[0][2])), Vector3(float(nb[1][0]), float(nb[1][1]), float(nb[1][2])), "metal")
	if not armorers_bench.is_empty():
		var bp: Vector3 = armorers_bench[0]
		box(geo, "NavBlock_ArmorersBench", bp + Vector3(-0.75, 0, 0), bp + Vector3(0.75, 0.9, 0.72), "metal")
	# T-175: the Crucible's footprint (its runtime body, 2.0 x 1.6, which the bake never saw: bots planned through the
	# machine) and its bay (`crucible.bay`, a floor rectangle behind it that CrucibleRoom dresses) go round the navmesh.
	# 1.6 m high, under agent_height: Recast does not fill a closed box, so a taller one leaves a walkable island under
	# its lid (gen_map00's NAV_SOLID_H note, T-051)
	if not crucible.is_empty():
		var cp: Vector3 = crucible["pos"]
		var ch: Vector3 = Vector3(0.8, 0, 1.0) if absf(absf(float(crucible.get("yaw", 0.0))) - 90.0) < 1.0 else Vector3(1.0, 0, 0.8)
		box(geo, "NavBlock_Crucible", cp - ch, cp + ch + Vector3(0, 1.6, 0), "metal")
		if crucible.has("bay"):
			var b0: Vector3 = (crucible["bay"] as Array)[0]
			var b1: Vector3 = (crucible["bay"] as Array)[1]
			box(geo, "NavBlock_CrucibleBay", b0, Vector3(b1.x, b0.y + 1.6, b1.z), "metal")


## Override: fill the tables.
func setup_tables() -> void:
	pass


## Override: the rooms (colliders into `geo`, closets via closet()).
func build_geometry() -> void:
	pass


## Override: non-colliding art into `dress`, lights via power()/lamp()/shaft()/fog().
func build_dressing() -> void:
	pass


## Override: act-specific gameplay nodes (after the generic ones).
func build_gameplay_extra() -> void:
	pass


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	bake_regions()
	get_root().remove_child(map_root)
	build_dressing()
	var merged: int = merge_static_meshes()
	print("merged %d static meshes into batches" % merged)
	build_lights()
	build_gameplay()
	build_gameplay_extra()
	for n: Node in extra_root_nodes:
		map_root.add_child(n)
	_prune(dress)
	_prune(geo)
	_own(map_root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(map_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		err = ResourceSaver.save(packed, out_path)
	print("Saved %s (%d boxes) err=%d" % [out_path, _count, err])
	map_root.free()
	return true


# ================================================================== helpers (gen_map02 idiom)

func _mk(n: String, key: String) -> String:
	for r: Array in mat_rules:
		if n.match(str(r[0])):
			return str(r[1])
	return str(mat_map.get(key, key))


func _hidden(n: String) -> bool:
	for p: String in hide:
		if n.match(p):
			return true
	return false


## Axis-aligned box from two corners. collide = a static collider on the "world" layer (navmesh source).
func box(parent: Node3D, n: String, a: Vector3, b: Vector3, mat_key: String, collide: bool = true) -> Node3D:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var size: Vector3 = hi - lo
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return null
	_count += 1
	var mi: MeshInstance3D = null
	if not _hidden(n):
		mi = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, mat_key))
	if not collide:
		if mi == null:
			return null
		mi.name = n
		mi.position = (lo + hi) * 0.5
		parent.add_child(mi)
		return mi
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.position = (lo + hi) * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if mi != null:
		body.add_child(mi)
	parent.add_child(body)
	return body


## Wall along X at depth z from x0..x1, y0..y1. openings: [[xa, xb, ya, yb], ...] (absolute y).
func wall_x(n: String, z: float, x0: float, x1: float, y0: float, y1: float, openings: Array, mk: String) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = x0
	var i: int = 0
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(cur, y0, z - T * 0.5), Vector3(float(o[0]), y1, z + T * 0.5), mk)
		box(geo, "%s_%db" % [n, i], Vector3(float(o[0]), y0, z - T * 0.5), Vector3(float(o[1]), float(o[2]), z + T * 0.5), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(float(o[0]), float(o[3]), z - T * 0.5), Vector3(float(o[1]), y1, z + T * 0.5), mk)
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(cur, y0, z - T * 0.5), Vector3(x1, y1, z + T * 0.5), mk)


func wall_z(n: String, x: float, z0: float, z1: float, y0: float, y1: float, openings: Array, mk: String) -> void:
	openings.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur: float = z0
	var i: int = 0
	for o: Array in openings:
		box(geo, "%s_%d" % [n, i], Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, float(o[0])), mk)
		box(geo, "%s_%db" % [n, i], Vector3(x - T * 0.5, y0, float(o[0])), Vector3(x + T * 0.5, float(o[2]), float(o[1])), mk)
		box(geo, "%s_%dt" % [n, i], Vector3(x - T * 0.5, float(o[3]), float(o[0])), Vector3(x + T * 0.5, y1, float(o[1])), mk)
		cur = float(o[1])
		i += 1
	box(geo, n + "_end", Vector3(x - T * 0.5, y0, cur), Vector3(x + T * 0.5, y1, z1), mk)


func win(c: float, y: float) -> Array:
	return [c - 0.8, c + 0.8, y + SILL, y + WTOP]


func door(c: float, y: float, w: float = 2.0) -> Array:
	return [c - w * 0.5, c + w * 0.5, y, y + DOOR_H]


func gap(c: float, y: float, w: float, h: float) -> Array:
	return [c - w * 0.5, c + w * 0.5, y, y + h]


## Ramp along Z between two heights (top surface follows the line between the endpoints).
func ramp_z(n: String, x0: float, x1: float, z_low: float, z_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(z_high - z_low)
	var basis: Basis = Basis(Vector3.RIGHT, -atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x0 + x1) * 0.5, (y_low + y_high) * 0.5, (z_low + z_high) * 0.5)
	_ramp_body(n, basis, mid, Vector3(absf(x1 - x0), 0.2, length))
	if treads != "":
		_stairs.append(["z", x0, x1, z_low, z_high, y_low, y_high, treads, risers])


## Ramp along X between two heights.
func ramp_x(n: String, z0: float, z1: float, x_low: float, x_high: float, y_low: float, y_high: float,
		treads: String = "", risers: String = "") -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var length: float = sqrt(run * run + rise * rise)
	var dir: float = signf(x_high - x_low)
	var basis: Basis = Basis(Vector3.BACK, atan2(rise, run) * dir)
	var mid: Vector3 = Vector3((x_low + x_high) * 0.5, (y_low + y_high) * 0.5, (z0 + z1) * 0.5)
	_ramp_body(n, basis, mid, Vector3(length, 0.2, absf(z1 - z0)))
	if treads != "":
		_stairs.append(["x", z0, z1, x_low, x_high, y_low, y_high, treads, risers])


func _ramp_body(n: String, basis: Basis, mid: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.transform = Transform3D(basis, mid - (basis * Vector3.UP) * 0.1)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if not _hidden(n):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.scale = size
		mi.material_override = Mats.get_mat(_mk(n, "stairs"))
		body.add_child(mi)
	geo.add_child(body)
	_count += 1


## A closet behind a window so window zombies have floor to stand on (built last, in build_closets).
func closet(window_pos: Vector3, yaw_deg: float) -> void:
	_closets.append([window_pos, yaw_deg])


func build_closets() -> void:
	for c: Array in _closets:
		var p: Vector3 = c[0]
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(c[1])))
		var out_dir: Vector3 = basis * Vector3(0, 0, -1)
		var side: Vector3 = basis * Vector3(1, 0, 0)
		var center: Vector3 = p + out_dir * 1.5
		var half_side: Vector3 = side.abs() * 1.4
		var half_out: Vector3 = out_dir.abs() * 1.4
		var lo: Vector3 = center - half_side - half_out
		var hi: Vector3 = center + half_side + half_out
		box(geo, "ClosetFloor", Vector3(lo.x, p.y - 0.5, lo.z), Vector3(hi.x, p.y, hi.z), "rock")
		box(geo, "ClosetRoof", Vector3(lo.x, p.y + 3.0, lo.z), Vector3(hi.x, p.y + 3.3, hi.z), "rock")
		var back: Vector3 = p + out_dir * 2.9
		box(geo, "ClosetBack", back - half_side - out_dir.abs() * 0.15 + Vector3(0, p.y - back.y, 0),
			back + half_side + out_dir.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")
		for s: float in [-1.0, 1.0]:
			var sp: Vector3 = center + side * 1.4 * s
			box(geo, "ClosetSide", sp - half_out - side.abs() * 0.15 + Vector3(0, p.y - sp.y, 0),
				sp + half_out + side.abs() * 0.15 + Vector3(0, 3.0, 0), "rock")


## The window's closet as a zone box [zone, lo, hi] (an own nav island, gen_map02's pattern).
func closet_box(zone: String, window_pos: Vector3, yaw_deg: float) -> Array:
	var p: Vector3 = window_pos
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var out_dir: Vector3 = basis * Vector3(0, 0, -1)
	var side: Vector3 = basis * Vector3(1, 0, 0)
	var center: Vector3 = p + out_dir * 1.5
	var half_side: Vector3 = side.abs() * 1.3
	var half_out: Vector3 = out_dir.abs() * 1.3
	var lo: Vector3 = center - half_side - half_out
	var hi: Vector3 = center + half_side + half_out
	# the box stops 0.05 m short of the wall line so it never overlaps the room's box
	var wall_lo: Vector3 = p - out_dir * 0.05
	if out_dir.x > 0.5:
		lo.x = wall_lo.x + 0.1
	elif out_dir.x < -0.5:
		hi.x = wall_lo.x - 0.1
	elif out_dir.z > 0.5:
		lo.z = wall_lo.z + 0.1
	else:
		hi.z = wall_lo.z - 0.1
	return [zone, Vector3(lo.x, p.y - 0.5, lo.z), Vector3(hi.x, p.y + 3.3, hi.z)]


## A hidden railing collider from a to b, h high.
func rail(n: String, a: Vector3, b: Vector3, h: float = 1.05) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x) - 0.05, a.y, minf(a.z, b.z) - 0.05)
	var hi: Vector3 = Vector3(maxf(a.x, b.x) + 0.05, a.y + h, maxf(a.z, b.z) + 0.05)
	box(geo, n, lo, hi, "rail")


func _own(n: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = map_root
		_own(c)


func B(a: Vector3, b: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	return Props.block(dress, a, b, key, shadows)


func OB(c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.obox(dress, c, size, key, rot)


func CYL(c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.cyl(dress, c, r, h, key, rot)


func _noshadow(mi: GeometryInstance3D) -> void:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func label(text: String, pos: Vector3, yaw: float, size: int = 40, color: Color = Color(0.85, 0.82, 0.72, 0.85), parent: Node3D = null) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = deg_to_rad(yaw)
	l.shaded = true
	(parent if parent != null else dress).add_child(l)


# ================================================================== navigation

func bake_regions() -> void:
	var nav_holder: Node3D = Node3D.new()
	nav_holder.name = "Navigation"
	map_root.add_child(nav_holder)
	var base: NavigationMesh = _navmesh()
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(base, src, geo)
	var i: int = 0
	for zb: Array in zone_boxes:
		var nm: NavigationMesh = _navmesh()
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		nm.filter_baking_aabb = AABB(lo, hi - lo)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		var r: NavigationRegion3D = NavigationRegion3D.new()
		r.name = "Nav_%s_%d" % [zb[0], i]
		r.navigation_mesh = nm
		r.navigation_layers = 1 << (int(zone_bits[zb[0]]) - 1)
		nav_holder.add_child(r)
		print("  %-14s box %d: %d polys" % [zb[0], i, nm.get_polygon_count()])
		i += 1
	var li: int = 0
	for l: Array in links:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = "Link_%d_%s" % [li, l[2]]
		link.start_position = l[0]
		link.end_position = l[1]
		link.bidirectional = true
		link.navigation_layers = 1 << (int(zone_bits[l[2]]) - 1)
		nav_holder.add_child(link)
		li += 1


func _navmesh() -> NavigationMesh:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm


# ================================================================== lighting fixtures

func G(zone: String) -> Node3D:
	if not _glow.has(zone):
		var h: Node3D = Node3D.new()
		h.name = "PowerGlow_" + zone
		h.set_meta("keep", true)
		dress.add_child(h)
		_glow[zone] = h
	return _glow[zone]


func power(zone: String, pos: Vector3, range_: float, energy: float, color: Color = SODIUM, shadow: bool = false,
		spot: Dictionary = {}) -> void:
	_power.append({"zone": zone, "pos": pos, "range": range_, "energy": energy, "color": color, "shadow": shadow, "spot": spot})


func lamp(pos: Vector3, color: Color, energy: float, range_: float, flicker: float = 0.0, fog: float = 0.0, shadow: bool = false,
		speed: float = 9.0) -> void:
	_static_lights.append({"pos": pos, "color": color, "energy": energy, "range": range_, "flicker": flicker, "fog": fog,
		"shadow": shadow, "speed": speed})


func shaft(n: String, pos: Vector3, aim: Vector3, color: Color, energy: float, range_: float, angle: float,
		fog: float = 1.5, shadow: bool = true) -> void:
	_spots.append({"name": n, "pos": pos, "aim": aim, "color": color, "energy": energy, "range": range_, "angle": angle,
		"fog": fog, "shadow": shadow})


func moon_window(id: String, energy: float = 1.0) -> void:
	for w: Array in windows:
		if str(w[0]) != id:
			continue
		var p: Vector3 = w[2]
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		shaft("MoonShaft_" + id, p - inward * 2.5 + Vector3(0, 2.75, 0), p + inward * 3.6, MOONLIGHT, 10.0 * energy, 14.0, 28.0, 3.0)


func fog(n: String, c: Vector3, size: Vector3, density: float, albedo: Color, emission: Color = Color(0, 0, 0)) -> void:
	_fogs.append({"name": n, "c": c, "size": size, "density": density, "albedo": albedo, "emission": emission})


func brazier(p: Vector3) -> void:
	Props.cyl(dress, p + Vector3(0, 0.42, 0), 0.3, 0.84, "rust")
	for h: float in [0.25, 0.6]:
		Props.cyl(dress, p + Vector3(0, h, 0), 0.31, 0.03, "iron")
	_noshadow(Props.cyl(dress, p + Vector3(0, 0.8, 0), 0.27, 0.06, "ember"))
	Props.flames(dress, p + Vector3(0, 0.84, 0), 0.45, 0.7, 26)
	Props.embers(dress, p + Vector3(0, 1.0, 0), 0.2, 8)
	lamp(p + Vector3(0, 1.3, 0), FIRE, 1.4, 9.0, 0.2, 0.6)


func pendant(zone: String, p: Vector3, ceil_y: float, shade: String = "enamel_green", s: float = 1.0, glow_key: String = "bulb_warm") -> void:
	var g: Node3D = G(zone)
	Props.cable(dress, Vector3(p.x, ceil_y, p.z), Vector3(p.x, p.y + 0.35 * s, p.z), 0.0, 0.015, 2, "iron")
	Props.cone(dress, p + Vector3(0, 0.22 * s, 0), 0.36 * s, 0.28 * s, shade)
	_noshadow(Props.ball(g, p, Vector3(0.1, 0.12, 0.1) * s, glow_key))
	power(zone, p + Vector3(0, -0.1, 0), 10.0 * s, 1.0, INCAND)


# ================================================================== batching

func merge_static_meshes() -> int:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for holder: Node in [geo, dress]:
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _kept(mi):
				continue
			var xf: Transform3D = _xform_to_root(mi)
			var c: Vector3 = xf.origin
			var cell: Vector3i = Vector3i(floori(c.x / 22.0), floori((c.y + 7.0) / 9.0), floori(c.z / 22.0))
			if absf(c.x) > 140.0 or absf(c.z - 100.0) > 160.0:
				cell = Vector3i(9999, 0, 0)
			var key: String = "%d|%d|%s" % [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
			if not groups.has(key):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "st": st}
			(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
			victims.append(mi)
	var batch_root: Node3D = Node3D.new()
	batch_root.name = "StaticBatches"
	map_root.add_child(batch_root)
	var i: int = 0
	for key: String in groups.keys():
		var g: Dictionary = groups[key]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Batch_%d" % i
		out.mesh = _commit(g["st"])
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		batch_root.add_child(out)
		i += 1
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	print("  %d batches" % i)
	return victims.size()


func _commit(st: SurfaceTool) -> ArrayMesh:
	var arrays: Array = st.commit_to_arrays()
	arrays[Mesh.ARRAY_TEX_UV] = null
	var m: ArrayMesh = ArrayMesh.new()
	var flags: int = Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if arrays[Mesh.ARRAY_TANGENT] != null else 0
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return m


func _kept(n: Node) -> bool:
	var p: Node = n
	while p != null and p != map_root:
		if p.has_meta("keep"):
			return true
		p = p.get_parent()
	return false


func _xform_to_root(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _prune(n: Node) -> void:
	for c: Node in n.get_children():
		_prune(c)
		if c.get_class() == "Node3D" and c.get_script() == null and c.get_child_count() == 0 and not c.has_meta("keep"):
			n.remove_child(c)
			c.free()


# ================================================================== lighting

func build_lights() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var psm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psm.sky_top_color = sky_top
	psm.sky_horizon_color = sky_horizon
	psm.ground_bottom_color = Color(0.008, 0.01, 0.015)
	psm.ground_horizon_color = sky_horizon
	psm.sun_angle_max = 4.0
	psm.sun_curve = 0.05
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 2.8
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.009
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.88)
	env.volumetric_fog_emission = Color(0.015, 0.019, 0.028)
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_ambient_inject = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.1
	we.environment = env
	map_root.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.set_script(load("res://gravelight/maps/map01_kaltenbrunn/moon_switch.gd"))
	moon.name = "Moon"
	moon.set("below_y", -1.0)
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.75
	moon.light_volumetric_fog_energy = 1.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(moon_rot.x), deg_to_rad(moon_rot.y), deg_to_rad(moon_rot.z))
	map_root.add_child(moon)
	var first: Dictionary = {}
	var i: int = 0
	for e: Dictionary in _power:
		var l: OmniLight3D = OmniLight3D.new()
		var zone: String = str(e["zone"])
		l.name = "PowerLight_%s_%d" % [zone, i]
		l.position = e["pos"]
		l.omni_range = float(e["range"])
		l.omni_attenuation = 1.0
		l.light_color = e["color"]
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 0.0
		l.shadow_enabled = bool(e["shadow"])
		l.set_meta("zone", StringName(zone))
		l.set_meta("energy", float(e["energy"]) * POWER_GAIN)
		l.add_to_group(&"power_lights", true)
		map_root.add_child(l)
		var sp: Dictionary = e["spot"]
		if not sp.is_empty():
			var s: SpotLight3D = SpotLight3D.new()
			s.name = "Beam"
			var dir: Vector3 = sp["dir"]
			var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
			s.transform = Transform3D(Basis.looking_at(dir, up), Vector3.ZERO)
			s.light_color = sp.get("color", MERCURY)
			s.light_energy = float(sp["energy"]) * 1.8
			s.spot_range = float(sp["range"])
			s.spot_angle = float(sp["angle"])
			s.spot_attenuation = 0.6
			s.light_volumetric_fog_energy = 0.35
			s.shadow_enabled = false
			l.add_child(s)
		if not first.has(zone):
			first[zone] = l
		i += 1
	for zone2: String in _glow.keys():
		var holder: Node3D = _glow[zone2]
		var host: OmniLight3D = first.get(zone2) as OmniLight3D
		if host == null:
			push_warning("gen_map04: no power light for glow zone %s" % zone2)
			continue
		var groups: Dictionary = {}
		var victims: Array[MeshInstance3D] = []
		for n: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var k: String = "%d" % mi.material_override.get_instance_id()
			if not groups.has(k):
				var st: SurfaceTool = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[k] = {"mat": mi.material_override, "st": st}
			(groups[k]["st"] as SurfaceTool).append_from(mi.mesh, 0, _xform_to_root(mi))
			victims.append(mi)
		var j: int = 0
		for k2: String in groups.keys():
			var out: MeshInstance3D = MeshInstance3D.new()
			out.name = "Glow_%d" % j
			out.mesh = _commit(groups[k2]["st"])
			out.material_override = groups[k2]["mat"]
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out.transform = host.transform.affine_inverse()
			host.add_child(out)
			j += 1
		holder.get_parent().remove_child(holder)
		holder.free()
	var si: int = 0
	for e2: Dictionary in _static_lights:
		var l2: OmniLight3D = OmniLight3D.new()
		var en: float = float(e2["energy"]) * LAMP_GAIN
		if float(e2["flicker"]) > 0.0:
			l2.set_script(load("res://gravelight/world/flicker_light.gd"))
			l2.set("base_energy", en)
			l2.set("amount", float(e2["flicker"]))
			l2.set("speed", float(e2["speed"]))
		l2.name = "Lamp_%d" % si
		l2.position = e2["pos"]
		l2.light_color = e2["color"]
		l2.light_energy = en
		l2.omni_range = float(e2["range"]) * 1.25
		l2.omni_attenuation = 1.1
		l2.light_volumetric_fog_energy = float(e2["fog"])
		l2.shadow_enabled = bool(e2["shadow"])
		map_root.add_child(l2)
		si += 1
	var names: Dictionary = {}
	for e3: Dictionary in _spots:
		var s3: SpotLight3D = SpotLight3D.new()
		var n3: String = str(e3["name"])
		names[n3] = int(names.get(n3, -1)) + 1
		s3.name = n3 if int(names[n3]) == 0 else "%s_%d" % [n3, int(names[n3])]
		var dir3: Vector3 = ((e3["aim"] as Vector3) - (e3["pos"] as Vector3)).normalized()
		s3.transform = Transform3D(Basis.looking_at(dir3, Vector3.UP if absf(dir3.y) < 0.95 else Vector3.FORWARD), e3["pos"])
		s3.light_color = e3["color"]
		s3.light_energy = float(e3["energy"])
		s3.spot_range = float(e3["range"])
		s3.spot_angle = float(e3["angle"])
		s3.spot_attenuation = 0.8
		s3.spot_angle_attenuation = 1.6
		s3.light_volumetric_fog_energy = float(e3["fog"])
		s3.shadow_enabled = bool(e3["shadow"])
		s3.shadow_blur = 1.5
		map_root.add_child(s3)
	for f: Dictionary in _fogs:
		var fv: FogVolume = FogVolume.new()
		fv.name = str(f["name"])
		fv.position = f["c"]
		fv.size = f["size"]
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var fm: FogMaterial = FogMaterial.new()
		fm.density = float(f["density"])
		fm.albedo = f["albedo"]
		fm.emission = f["emission"]
		fm.edge_fade = 0.3
		fv.material = fm
		map_root.add_child(fv)
	var post: CanvasLayer = CanvasLayer.new()
	post.set_script(load("res://gravelight/ui/postfx.gd"))
	post.name = "PostFx"
	map_root.add_child(post)


# ================================================================== gameplay

func _node(script: String, n: String, props: Dictionary, pos: Vector3, yaw: float = 0.0, marker: bool = false) -> Node3D:
	var node: Node3D = Marker3D.new() if marker else Node3D.new()
	if not ResourceLoader.exists(script):
		push_warning("gen_map04: %s not found; placing a plain marker for %s" % [script, n])
		node.name = n
		node.position = pos
		node.rotation.y = deg_to_rad(yaw)
		gameplay.add_child(node)
		return node
	node.set_script(load(script))
	node.name = n
	for k: String in props.keys():
		node.set(k, props[k])
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	gameplay.add_child(node)
	return node


func build_gameplay() -> void:
	map_root.set_script(load("res://gravelight/maps/map_root.gd"))
	map_root.set("map_id", StringName(map_id))
	map_root.set("display_name", display_name)
	map_root.set("start_zone", StringName(start_zone))
	map_root.set("intro_text", intro_text)
	map_root.set("quest_files", PackedStringArray([]))
	var bits: Dictionary = {}
	for k: String in zone_bits.keys():
		bits[StringName(k)] = zone_bits[k]
	map_root.set("nav_zone_bits", bits)
	var adj2: Dictionary = {}
	for k: String in adj.keys():
		adj2[StringName(k)] = adj[k]
	map_root.set("zone_adjacency", adj2)
	gameplay = Node3D.new()
	gameplay.name = "Gameplay"
	map_root.add_child(gameplay)

	var i: int = 1
	for sp: Array in player_spawns:
		_node("res://gravelight/maps/player_spawn.gd", "PlayerSpawn%d" % i, {}, sp[0], float(sp[1]), true)
		i += 1
	var zi: int = 0
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		_node("res://gravelight/world/zone_volume.gd", "Zone_%s_%d" % [zb[0], zi], {"zone_id": StringName(zb[0]), "size": hi - lo},
			Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5))
		zi += 1
	for w: Array in windows:
		var wp: Vector3 = w[2]
		var bar: Node3D = _node("res://gravelight/world/barricade.gd", str(w[0]), {"window_id": StringName(str(w[0])), "zone_id": StringName(str(w[1])),
			"width": 1.6, "sill_height": SILL, "top_height": WTOP}, wp, float(w[3]))
		var inward: Vector3 = Basis(Vector3.UP, deg_to_rad(float(w[3]))) * Vector3(0, 0, 1)
		var spawn_pos: Vector3 = wp - inward * 1.7
		_node("res://gravelight/enemies/zombie_spawn.gd", "Spawn_" + str(w[0]), {"zone_id": StringName(str(w[1])),
			"window_path": NodePath("../" + str(w[0])), "kind": &"window"}, spawn_pos, 0.0, true)
		bar.name = str(w[0])
	var counts: Dictionary = {}
	for g: Array in grounds:
		var zn: String = str(g[0])
		var gi: int = int(counts.get(zn, 0))
		counts[zn] = gi + 1
		_node("res://gravelight/enemies/zombie_spawn.gd", "Ground_%s_%d" % [zn, gi], {"zone_id": StringName(zn), "kind": &"ground",
			"min_round": int(g[2])}, g[1], 0.0, true)
	var ccounts: Dictionary = {}
	for c: Array in catwalks:
		var zn2: String = str(c[0])
		var ci2: int = int(ccounts.get(zn2, 0))
		ccounts[zn2] = ci2 + 1
		_node("res://gravelight/enemies/zombie_spawn.gd", "Catwalk_%s_%d" % [zn2, ci2], {"zone_id": StringName(zn2), "kind": &"ground",
			"min_round": 1, "enabled": bool(c[2])}, c[1], 0.0, true)
	for d: Array in doors:
		_node("res://gravelight/world/door.gd", str(d[0]), {"door_id": StringName(d[1]), "opens_zone": StringName(d[2]),
			"also_opens": PackedStringArray(d[3]), "link_group": StringName(d[4]), "cost": int(d[5]), "label": d[6],
			"size": Vector3(float(d[9]), DOOR_H, 0.25), "requires_power": d[10]}, d[7], float(d[8]))
	for b: Array in buys:
		_node("res://gravelight/world/wall_buy.gd", "WallBuy_" + str(b[0]), {"weapon_id": StringName(b[0])}, b[1], float(b[2]))
	for p: Array in perks:
		_node("res://gravelight/world/perk_machine.gd", "Perk_" + str(p[0]), {"perk_id": StringName(p[0])}, p[1], float(p[2]))
	var ci: int = 0
	for c2: Array in crates:
		_node("res://gravelight/world/mystery_crate.gd", "Crate_" + str(c2[0]), {"spot_index": ci, "can_start": c2[3], "spot_name": c2[0],
			"drummer_route": PackedVector3Array(c2[4])}, c2[1], float(c2[2]))
		ci += 1
	if not power_switch.is_empty():
		var ps: Dictionary = power_switch
		_node("res://gravelight/world/power_switch.gd", str(ps.get("name", "PowerSwitch")), {"config_table": str(ps.get("config_table", json_table)),
			"label": str(ps.get("label", "the power")), "zone_order": PackedStringArray(ps.get("zone_order", []))}, ps["pos"], float(ps.get("yaw", 0.0)))
	if not crucible.is_empty():
		_node("res://gravelight/world/crucible.gd", "Crucible", {"needs_power": bool(crucible.get("needs_power", true))}, crucible["pos"], float(crucible.get("yaw", 0.0)))
	for ab2: Array in ammo_boxes:
		_node("res://gravelight/world/ammo_box.gd", "AmmoBox_" + str(ab2[0]), {"box_name": str(ab2[0]).to_snake_case()}, ab2[1], float(ab2[2]))
	if not armorers_bench.is_empty():
		_node("res://gravelight/world/armorers_bench.gd", "ArmorersBench", {}, armorers_bench[0], float(armorers_bench[1]))
	for t: Array in traps:
		var trap: Node3D = _node(str(t[0]), str(t[1]), t[2], t[3], float(t[4]))
		_node("res://gravelight/world/trap_lever.gd", "Lever_" + str(t[1]).trim_prefix("Trap_"), {"trap_path": NodePath("../" + trap.name), "trap_id": StringName(str(t[7]))}, t[5], float(t[6]))
	for bp: Vector3 in burst_points:
		var m: Marker3D = Marker3D.new()
		m.name = "BurstPoint"
		m.position = bp
		m.add_to_group(&"power_burst_points", true)
		gameplay.add_child(m)


# ================================================================== UPDATE 09 additions (T-146; additive only)
# Nothing above calls these: an act generator opts in (gen_map04a overrides build_lights() to call
# tag_light_zones after the base). Acts II-IV regenerate unchanged unless they call them too.

## The zone whose box holds `p` (generous in height: a lamp under a roof or a flood on a wall top still counts),
## else the zone whose box is nearest in plan. "" only when the act has no zone boxes.
func zone_at(p: Vector3) -> String:
	var best: String = ""
	var best_d: float = INF
	for zb: Array in zone_boxes:
		var lo: Vector3 = zb[1]
		var hi: Vector3 = zb[2]
		var inside_xz: bool = p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z
		if inside_xz and p.y >= lo.y - 2.0 and p.y <= hi.y + 12.0:
			return str(zb[0])
		var q: Vector3 = Vector3(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y), clampf(p.z, lo.z, hi.z))
		var d: float = Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 0.1
		if d < best_d:
			best_d = d
			best = str(zb[0])
	return best


## Gives every Light3D under the map root (except directional lights) a `zone` meta from its position when it has
## none, then holds the shadow budget (contract C4: at most `cap` shadow-casting lights per zone; the first ones
## built keep theirs). Returns {zone: shadowed count} after the cap.
func tag_light_zones(cap: int = 6) -> Dictionary:
	var counts: Dictionary = {}
	for n: Node in map_root.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D:
			continue
		var l: Light3D = n as Light3D
		if not l.has_meta("zone"):
			l.set_meta("zone", StringName(zone_at(_xform_to_root(l).origin)))
		if not l.shadow_enabled:
			continue
		var z: String = str(l.get_meta("zone"))
		if int(counts.get(z, 0)) >= cap:
			l.shadow_enabled = false
			push_warning("gen_map04: %s loses its shadow (zone %s is at its %d shadowed lights)" % [l.name, z, cap])
			continue
		counts[z] = int(counts.get(z, 0)) + 1
	return counts
