class_name InteractableArt
extends RefCounted
## Procedural art for the gameplay interactables (D-063): perk dispensers, the Crucible, the lift cage, pylons,
## barricade planks, buy doors, traps, the Hauptschalter, the workbench and the quest props. Original designs,
## built from Props primitives and Mats keys.
##
## Static parts are built once per variant into a temporary node, merged into one ArrayMesh with a surface per
## material, and cached (`mesh()`), so repeated objects share meshes and cost one draw per material. Parts a
## script animates or recolours (boards, levers, gates, lamps) stay separate nodes owned by that script.
## Everything here is visual only: no collision, so nothing changes navigation or interaction volumes.

static var _meshes: Dictionary = {}
static var _sphere_hi: SphereMesh
static var _cyl_hi: CylinderMesh
static var _tori: Dictionary = {}


# ================================================================== mesh cache

## The cached multi-surface mesh for `key`, built by `builder.call(root: Node3D)` on first use.
static func mesh(key: String, builder: Callable) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var tmp: Node3D = Node3D.new()
	builder.call(tmp)
	var groups: Dictionary = {}
	var order: Array = []
	for n: Node in tmp.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or mi.material_override == null:
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != tmp:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var k: int = mi.material_override.get_instance_id()
		if not groups.has(k):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[k] = {"mat": mi.material_override, "st": st}
			order.append(k)
		for s: int in mi.mesh.get_surface_count():
			(groups[k]["st"] as SurfaceTool).append_from(mi.mesh, s, xf)
	var am: ArrayMesh = ArrayMesh.new()
	for k2: int in order:
		(groups[k2]["st"] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, groups[k2]["mat"])
	tmp.free()
	_meshes[key] = am
	return am


## Adds a MeshInstance3D showing the cached mesh `key` (built by `builder` on first use).
static func place(parent: Node3D, key: String, builder: Callable, pos: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Art"
	mi.mesh = mesh(key, builder)
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Appends a primitive to a SurfaceTool with a transform and a vertex colour (for single-material, tinted meshes).
static func add_prim(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var a: Array = prim.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb: Basis = xf.basis.inverse().transposed()
	for i: int in idx:
		st.set_color(col)
		st.set_normal((nb * nrm[i]).normalized())
		st.set_uv(uv[i])
		st.add_vertex(xf * v[i])


# ================================================================== primitives

static func _hi_sphere() -> SphereMesh:
	if _sphere_hi == null:
		_sphere_hi = SphereMesh.new()
		_sphere_hi.radius = 0.5
		_sphere_hi.height = 1.0
		_sphere_hi.radial_segments = 24
		_sphere_hi.rings = 12
	return _sphere_hi


static func _hi_cyl() -> CylinderMesh:
	if _cyl_hi == null:
		_cyl_hi = CylinderMesh.new()
		_cyl_hi.top_radius = 0.5
		_cyl_hi.bottom_radius = 0.5
		_cyl_hi.height = 1.0
		_cyl_hi.radial_segments = 24
		_cyl_hi.rings = 1
	return _cyl_hi


## Unit torus (outer radius 0.5) whose tube is `ratio` of the outer radius.
static func _torus(ratio: float) -> TorusMesh:
	var k: int = int(ratio * 100.0)
	if not _tori.has(k):
		var t: TorusMesh = TorusMesh.new()
		t.outer_radius = 0.5
		t.inner_radius = 0.5 * (1.0 - float(k) / 100.0)
		t.rings = 24
		t.ring_segments = 8
		_tori[k] = t
	return _tori[k]


static var _frusta: Dictionary = {}


## A frustum section from radius r0 (at y0) to r1 (at y1), 24-sided.
static func frustum(g: Node3D, x: float, z: float, y0: float, y1: float, r0: float, r1: float, key: String, open_top: bool = false) -> MeshInstance3D:
	var k: String = "%d_%d_%d" % [int(r0 * 1000.0), int(r1 * 1000.0), int(open_top)]
	var cm: CylinderMesh
	if _frusta.has(k):
		cm = _frusta[k]
	else:
		cm = CylinderMesh.new()
		cm.bottom_radius = r0
		cm.top_radius = r1
		cm.height = 1.0
		cm.radial_segments = 24
		cm.rings = 1
		cm.cap_top = not open_top
		_frusta[k] = cm
	return _m(g, cm, Vector3(x, (y0 + y1) * 0.5, z), Vector3(1.0, y1 - y0, 1.0), key)


static func _m(parent: Node3D, m: Mesh, center: Vector3, size: Vector3, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.rotation = rot_deg * (PI / 180.0)
	mi.scale = size
	parent.add_child(mi)
	return mi


## Smooth ellipsoid of full size `size`.
static func ell(g: Node3D, c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _m(g, _hi_sphere(), c, size, key, rot)


## Smooth (24-sided) cylinder, possibly elliptical: size = (diameter x, height, diameter z).
static func tube(g: Node3D, c: Vector3, size: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _m(g, _hi_cyl(), c, size, key, rot)


## Ring of outer radius r and tube thickness t, lying in the XZ plane unless rotated.
static func ring(g: Node3D, c: Vector3, r: float, t: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _m(g, _torus(clampf(t / r, 0.02, 0.9)), c, Vector3(r * 2.0, r * 2.0, r * 2.0), key, rot)


static func B(g: Node3D, a: Vector3, b: Vector3, key: String) -> MeshInstance3D:
	return Props.block(g, a, b, key)


static func OB(g: Node3D, c: Vector3, s: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.obox(g, c, s, key, rot)


static func C(g: Node3D, c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.cyl(g, c, r, h, key, rot)


static func S(g: Node3D, a: Vector3, b: Vector3, t: float, key: String, round_: bool = true) -> MeshInstance3D:
	return Props.strut(g, a, b, t, key, round_)


static func dot(g: Node3D, c: Vector3, r: float, key: String) -> MeshInstance3D:
	return Props.ball(g, c, Vector3(r, r, r) * 2.0, key)


## A row of rivet heads from a to b.
static func rivets(g: Node3D, a: Vector3, b: Vector3, n: int, r: float = 0.018, key: String = "steel") -> void:
	for i: int in n:
		dot(g, a.lerp(b, (float(i) + 0.5) / float(n)), r, key)


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


# ================================================================== perk dispensers (JINGLES.md machine notes)

## Where each machine's parts go: sign label, bottle window, lamp globe, price plate, hatch, Scrip slot.
static func perk_layout(shape: String, fp: Vector3) -> Dictionary:
	var fz: float = -fp.z * 0.5
	match shape:
		"barrel":
			return {"sign": Vector3(0, 2.2, -0.42), "sign_size": Vector2(1.3, 0.36), "win": Vector3(0, 1.28, -0.63), "win_size": Vector2(0.46, 0.4),
				"lamp": Vector3(0.38, 1.98, -0.05), "price": Vector3(0, 0.44, -0.62), "hatch": Vector3(0, 0.74, -0.62), "slot": Vector3(0.32, 1.02, -0.58)}
		"cabinet":
			return {"sign": Vector3(0, 2.62, -0.2), "sign_size": Vector2(1.15, 0.3), "win": Vector3(0, 1.36, fz - 0.02), "win_size": Vector2(0.5, 0.56),
				"lamp": Vector3(0, 2.36, 0.0), "price": Vector3(0, 0.42, fz - 0.02), "hatch": Vector3(0, 0.8, fz - 0.02), "slot": Vector3(0.28, 1.0, fz - 0.01)}
		"crate":
			return {"sign": Vector3(0, 2.22, fz + 0.1), "sign_size": Vector2(1.45, 0.34), "win": Vector3(0, 1.4, fz - 0.02), "win_size": Vector2(0.56, 0.5),
				"lamp": Vector3(-0.38, 2.05, 0.05), "price": Vector3(0, 0.5, fz - 0.02), "hatch": Vector3(0, 0.88, fz - 0.02), "slot": Vector3(0.36, 1.12, fz - 0.01)}
		"twin":
			return {"sign": Vector3(0, 2.36, -0.1), "sign_size": Vector2(1.35, 0.32), "win": Vector3(0, 1.3, -0.28), "win_size": Vector2(0.4, 0.46),
				"lamp": Vector3(0, 2.08, 0.05), "price": Vector3(0, 0.46, -0.3), "hatch": Vector3(0, 0.84, -0.27), "slot": Vector3(-0.14, 1.66, -0.27),
				"dial": Vector3(0.12, 1.67, -0.28)}
		"teardrop":
			return {"sign": Vector3(0, 2.66, -0.12), "sign_size": Vector2(1.45, 0.32), "win": Vector3(0, 1.42, -0.47), "win_size": Vector2(0.42, 0.5),
				"lamp": Vector3(0, 2.44, 0.0), "price": Vector3(0, 0.36, -0.44), "hatch": Vector3(0, 0.86, -0.47), "slot": Vector3(0.26, 1.06, -0.45)}
		"periscope":
			return {"sign": Vector3(0, 2.02, fz + 0.12), "sign_size": Vector2(1.05, 0.3), "win": Vector3(0, 1.24, fz - 0.03), "win_size": Vector2(0.5, 0.42),
				"lamp": Vector3(0.32, 1.9, 0.12), "price": Vector3(0, 0.42, fz - 0.03), "hatch": Vector3(0, 0.78, fz - 0.03), "slot": Vector3(0.33, 0.98, fz - 0.03)}
		"wagon":
			return {"sign": Vector3(0, 2.0, fz + 0.12), "sign_size": Vector2(1.3, 0.32), "win": Vector3(-0.3, 0.98, fz - 0.02), "win_size": Vector2(0.56, 0.4),
				"lamp": Vector3(0.75, 1.62, -0.25), "price": Vector3(0.38, 0.5, fz - 0.02), "hatch": Vector3(0.38, 0.86, fz - 0.02), "slot": Vector3(0.38, 1.1, fz - 0.01)}
		"safe":
			return {"sign": Vector3(0, 2.18, fz + 0.12), "sign_size": Vector2(1.3, 0.34), "win": Vector3(-0.05, 1.32, fz - 0.06), "win_size": Vector2(0.4, 0.4),
				"lamp": Vector3(0.4, 1.98, 0.1), "price": Vector3(0, 0.36, fz - 0.06), "hatch": Vector3(-0.05, 0.74, fz - 0.06), "slot": Vector3(0.36, 1.32, fz - 0.06),
				"round": true}
		"coil":
			# Overclock Cordial: a porthole low, the LEER/HALB/VOLL gauge above it, the sign on the roof edge, the
			# lamp globe is the brass ball on top of the induction coil.
			return {"sign": Vector3(0, 2.16, fz + 0.06), "sign_size": Vector2(1.1, 0.3), "win": Vector3(0, 1.14, fz - 0.02), "win_size": Vector2(0.44, 0.44),
				"lamp": Vector3(0, 2.46, 0.05), "price": Vector3(0, 0.38, fz - 0.02), "hatch": Vector3(0, 0.7, fz - 0.02), "slot": Vector3(0.27, 0.95, fz - 0.01),
				"dial": Vector3(-0.27, 0.98, fz - 0.03), "round": true}
		"register":
			# Ledger Lager (T-141): the paper-roll window over the key bank, the cash drawer is the hatch, the tally
			# drum sits on top between the sign and the body, the lamp globe on a bracket to the right of the drum.
			return {"sign": Vector3(0, 2.34, fz + 0.04), "sign_size": Vector2(1.0, 0.28), "win": Vector3(0, 1.42, fz - 0.02), "win_size": Vector2(0.5, 0.42),
				"lamp": Vector3(0.4, 1.9, 0.0), "price": Vector3(0, 0.36, fz - 0.02), "hatch": Vector3(0, 0.6, fz - 0.03), "slot": Vector3(0.33, 0.62, fz - 0.02)}
	return {"sign": Vector3(0, fp.y + 0.28, fz), "sign_size": Vector2(fp.x + 0.2, 0.3), "win": Vector3(0, 1.45, fz - 0.02), "win_size": Vector2(0.5, 0.45),
		"lamp": Vector3(0, fp.y + 0.1, 0), "price": Vector3(0, 0.55, fz - 0.02), "hatch": Vector3(0, 0.85, fz - 0.02), "slot": Vector3(0.3, 1.05, fz - 0.01)}


## Static body of a perk dispenser (cached per perk): cabinet, trim, sign board, window furniture, hatch, slot.
static func perk_body(g: Node3D, shape: String, fp: Vector3, brand: Color) -> void:
	var lay: Dictionary = perk_layout(shape, fp)
	var en: String = "enamel:" + hex(brand)
	var en_dark: String = "enamel:" + hex(brand.darkened(0.78))
	match shape:
		"barrel":
			_barrel(g, fp, en)
		"cabinet":
			_apothecary(g, fp, en)
		"crate":
			_ammo_crate(g, fp, en)
		"twin":
			_twin_towers(g, fp, en)
		"teardrop":
			_streamliner(g, fp, en)
		"periscope":
			_periscope(g, fp, en)
		"wagon":
			_wagon(g, fp, en)
		"safe":
			_safe(g, fp, en)
		"coil":
			_coil_tower(g, fp, en)
		"glider":
			_glider(g, fp, en)
		"bandit":
			_bandit(g, fp, en)
		"register":
			_register(g, fp, en)
		_:
			B(g, Vector3(-fp.x * 0.5, 0, -fp.z * 0.5), Vector3(fp.x * 0.5, fp.y, fp.z * 0.5), en)
	# sign board (the neon tubes and the label sit in front of it)
	var sc: Vector3 = lay["sign"]
	var ss: Vector2 = lay["sign_size"]
	B(g, Vector3(sc.x - ss.x * 0.5, sc.y - ss.y * 0.5, sc.z + 0.012), Vector3(sc.x + ss.x * 0.5, sc.y + ss.y * 0.5, sc.z + 0.05), en_dark)
	B(g, Vector3(sc.x - ss.x * 0.5 - 0.02, sc.y - ss.y * 0.5 - 0.02, sc.z + 0.04), Vector3(sc.x + ss.x * 0.5 + 0.02, sc.y + ss.y * 0.5 + 0.02, sc.z + 0.07), "chrome")
	# window furniture
	_bottle_window(g, lay["win"], lay["win_size"], brand, bool(lay.get("round", false)))
	_hatch(g, lay["hatch"], 0.34)
	_scrip_slot(g, lay["slot"])
	# the Ledger dial: a brass-rimmed counter face (lit with the tubes) and its needle
	var dc: Vector3 = _dial_pos(lay)
	C(g, dc, 0.08, 0.03, "brass", Vector3(90, 0, 0))
	OB(g, dc + Vector3(0.014, 0.012, -0.022), Vector3(0.008, 0.05, 0.004), "black_paint", Vector3(0, 0, -35))
	dot(g, dc + Vector3(0, 0, -0.022), 0.008, "black_paint")
	var pc: Vector3 = lay["price"]
	B(g, Vector3(pc.x - 0.3, pc.y - 0.07, pc.z + 0.005), Vector3(pc.x + 0.3, pc.y + 0.07, pc.z + 0.025), "nameplate")
	B(g, Vector3(pc.x - 0.31, pc.y - 0.08, pc.z + 0.02), Vector3(pc.x + 0.31, pc.y + 0.08, pc.z + 0.03), "brass")
	# lamp fitting (the globe itself is in the lit/unlit sets)
	var lp: Vector3 = lay["lamp"]
	C(g, lp + Vector3(0, -0.07, 0), 0.06, 0.06, "brass")
	ring(g, lp + Vector3(0, 0.0, 0), 0.085, 0.012, "brass")
	for a: float in [0.0, 120.0, 240.0]:
		var d: Vector3 = Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.08
		S(g, lp + Vector3(0, -0.05, 0) + d, lp + Vector3(0, 0.11, 0) + d * 0.4, 0.012, "brass")


## Skyhook Sekt (T-105): a glider fuselage stood on its tail: a slim tapering body, a canopy frame round the
## bottle window, stub wings low down as the feet, a tail fin behind the sign.
static func _glider(g: Node3D, fp: Vector3, en: String) -> void:
	var hx: float = fp.x * 0.5
	var hz: float = fp.z * 0.5
	B(g, Vector3(-hx * 0.8, 0.0, -hz * 0.8), Vector3(hx * 0.8, 0.5, hz * 0.8), en)
	B(g, Vector3(-hx, 0.5, -hz), Vector3(hx, fp.y - 0.45, hz), en)
	B(g, Vector3(-hx * 0.7, fp.y - 0.45, -hz * 0.7), Vector3(hx * 0.7, fp.y - 0.1, hz * 0.7), en)
	C(g, Vector3(0, fp.y - 0.08, 0), hx * 0.45, 0.16, en)
	for sgn: float in [-1.0, 1.0]:
		B(g, Vector3(sgn * hx, 0.08, -hz * 0.3), Vector3(sgn * (hx + 0.45), 0.16, hz * 0.3), "chrome")
	B(g, Vector3(-0.04, fp.y - 0.4, hz), Vector3(0.04, fp.y + 0.1, hz + 0.3), en)
	for y: float in [0.9, 1.5, 2.0]:
		ring(g, Vector3(0, y, 0), hx * 1.02, 0.015, "chrome", Vector3(90, 0, 0))


## Magpie Mead (T-105): the standard cabinet under olive paint, chipped to Packmule's brown at the edges, a bare
## bulb in a cage instead of neon, the lever's bracket on the right, a stencil plate on the front.
static func _bandit(g: Node3D, fp: Vector3, en: String) -> void:
	var hx: float = fp.x * 0.5
	var hz: float = fp.z * 0.5
	B(g, Vector3(-hx, 0, -hz), Vector3(hx, fp.y, hz), en)
	for corner: Vector3 in [Vector3(-hx, 0.0, -hz), Vector3(hx - 0.04, 0.0, -hz), Vector3(-hx, fp.y - 0.04, -hz), Vector3(hx - 0.04, fp.y - 0.04, -hz)]:
		B(g, corner - Vector3(0, 0, 0.004), corner + Vector3(0.04, 0.04, 0.0), "enamel:#6b5a2e")   # the chips
	B(g, Vector3(hx, 1.1, -hz * 0.5), Vector3(hx + 0.07, 1.5, hz * 0.0), "steel")
	B(g, Vector3(-hx * 0.6, 0.62, -hz - 0.012), Vector3(hx * 0.6, 0.7, -hz), "olive_drab")
	for k: int in 4:
		S(g, Vector3(-0.18 + k * 0.12, fp.y - 0.26, -hz - 0.06), Vector3(-0.18 + k * 0.12, fp.y - 0.06, -hz - 0.06), 0.006, "steel")


## Ledger Lager (T-141): a brass cash register stood up to cabinet height on a black iron base: a drawer cabinet
## (the hatch is the cash drawer, with its brass front), a strip of amber glass keys under the paper-roll window,
## a bell on the shoulder, two brass posts carrying the tally drum on top (the drum itself turns: register_drum()).
static func _register(g: Node3D, fp: Vector3, en: String) -> void:
	var hx: float = fp.x * 0.5
	var hz: float = fp.z * 0.5
	B(g, Vector3(-hx, 0.0, -hz), Vector3(hx, 0.28, hz), "iron")
	B(g, Vector3(-hx - 0.02, 0.26, -hz - 0.02), Vector3(hx + 0.02, 0.3, hz + 0.02), "brass")   # the base's brass rail
	B(g, Vector3(-hx * 0.94, 0.3, -hz * 0.94), Vector3(hx * 0.94, 1.72, hz * 0.94), en)
	# the drawer's brass front and a lip under it
	B(g, Vector3(-hx * 0.8, 0.42, -hz * 0.94 - 0.012), Vector3(hx * 0.8, 0.8, -hz * 0.94), "brass_plate")
	B(g, Vector3(-hx * 0.84, 0.38, -hz * 0.94 - 0.03), Vector3(hx * 0.84, 0.42, -hz * 0.94), "brass")
	# the key bank: three rows of amber glass keys on a dark strip, a violet tally stripe down the left edge
	B(g, Vector3(-hx * 0.88, 0.9, -hz * 0.94 - 0.01), Vector3(hx * 0.88, 1.14, -hz * 0.94), "black_paint")
	for row: int in 3:
		for col: int in 9:
			var kx: float = -0.38 + col * 0.095
			C(g, Vector3(kx, 0.94 + row * 0.07, -hz * 0.94 - 0.022), 0.026, 0.02, "enamel:#d9a441", Vector3(90, 0, 0))
	B(g, Vector3(-hx * 0.94 - 0.004, 0.3, -hz * 0.94 - 0.006), Vector3(-hx * 0.94 + 0.05, 1.72, -hz * 0.94), "enamel:#7a4fb0")
	# the shoulder: a bell on the right, the posts carrying the drum on the top
	B(g, Vector3(-hx * 0.94, 1.72, -hz * 0.94), Vector3(hx * 0.94, 1.76, hz * 0.94), "brass")
	C(g, Vector3(0.32, 1.8, -0.1), 0.06, 0.07, "brass")
	dot(g, Vector3(0.32, 1.86, -0.1), 0.012, "brass")
	for sgn: float in [-1.0, 1.0]:
		S(g, Vector3(sgn * 0.34, 1.76, 0.0), Vector3(sgn * 0.34, 2.1, 0.0), 0.022, "brass")
	# a coil of paper roll behind the window
	C(g, Vector3(0.0, 1.4, hz * 0.4), 0.11, 0.3, "paper_old", Vector3(0, 0, 90))


## The tally drum (pivot at the origin, turns about X): a cream drum with a ring of violet digit plates; it turns
## over once for every Scrip the holder earns (PerkMachine, JINGLES.md section 16). `gold` = a tier IV drum.
static func register_drum(g: Node3D, gold: bool = false) -> void:
	C(g, Vector3.ZERO, 0.17, 0.5, "cream", Vector3(0, 0, 90))
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		OB(g, Vector3(0, cos(a) * 0.172, sin(a) * 0.172), Vector3(0.4, 0.05, 0.012), "enamel:#e0b84a" if gold else "enamel:#7a4fb0", Vector3(-rad_to_deg(a) + 90.0, 0, 0))
	C(g, Vector3(0.27, 0, 0), 0.05, 0.03, "brass", Vector3(0, 0, 90))
	C(g, Vector3(-0.27, 0, 0), 0.05, 0.03, "brass", Vector3(0, 0, 90))


## Neon tubes around the sign board, the lamp globe and the Ledger dial's face, lit or dark.
static func perk_tubes(g: Node3D, shape: String, fp: Vector3, key: String) -> void:
	var lay: Dictionary = perk_layout(shape, fp)
	var dc: Vector3 = _dial_pos(lay)
	C(g, dc + Vector3(0, 0, -0.012), 0.062, 0.008, "gauge_face" if key == "neon_off" else "gauge_lit", Vector3(90, 0, 0))
	var sc: Vector3 = lay["sign"]
	var ss: Vector2 = lay["sign_size"]
	var hx: float = ss.x * 0.5 - 0.04
	var hy: float = ss.y * 0.5 - 0.04
	var z: float = sc.z + 0.0
	var corners: Array = [Vector3(-hx, -hy, z), Vector3(hx, -hy, z), Vector3(hx, hy, z), Vector3(-hx, hy, z)]
	for i: int in 4:
		S(g, sc + corners[i] - Vector3(0, 0, sc.z) + Vector3(0, 0, 0), sc + corners[(i + 1) % 4] - Vector3(0, 0, sc.z), 0.022, key)
	ell(g, lay["lamp"] + Vector3(0, 0.05, 0), Vector3(0.13, 0.15, 0.13), key)


## A recessed bottle window: shelf, three tonic bottles in the brand's glass, a chrome grille and frame.
static func _bottle_window(g: Node3D, c: Vector3, sz: Vector2, brand: Color, round_: bool) -> void:
	var glass: String = "glass:" + hex(brand.lightened(0.1))
	var w: float = sz.x
	var h: float = sz.y
	var rows: int = 2 if h > 0.45 else 1
	for r: int in rows:
		var shelf_y: float = c.y - h * 0.5 + 0.03 + r * (h / float(rows))
		B(g, Vector3(c.x - w * 0.46, shelf_y - 0.015, c.z + 0.03), Vector3(c.x + w * 0.46, shelf_y, c.z + 0.12), "chrome")
		var n: int = 3
		for i: int in n:
			var bx: float = c.x - w * 0.3 + i * (w * 0.6 / float(n - 1))
			var bh: float = minf(0.17, h / float(rows) - 0.1)
			C(g, Vector3(bx, shelf_y + bh * 0.5, c.z + 0.07), 0.034, bh, glass)
			C(g, Vector3(bx, shelf_y + bh + 0.03, c.z + 0.07), 0.013, 0.06, glass)
			C(g, Vector3(bx, shelf_y + bh + 0.065, c.z + 0.07), 0.016, 0.014, "brass")
			B(g, Vector3(bx - 0.03, shelf_y + bh * 0.3, c.z + 0.032), Vector3(bx + 0.03, shelf_y + bh * 0.7, c.z + 0.036), "cream")
	if round_:
		ring(g, Vector3(c.x, c.y, c.z - 0.01), w * 0.56, 0.05, "chrome_worn", Vector3(90, 0, 0))
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			dot(g, Vector3(c.x + cos(a) * w * 0.56, c.y + sin(a) * w * 0.56, c.z - 0.04), 0.018, "steel")
		for gx: int in 5:
			var x: float = c.x - w * 0.36 + gx * (w * 0.72 / 4.0)
			var hh: float = sqrt(maxf(0.0, pow(w * 0.5, 2.0) - pow(x - c.x, 2.0)))
			S(g, Vector3(x, c.y - hh, c.z - 0.005), Vector3(x, c.y + hh, c.z - 0.005), 0.008, "chrome")
	else:
		var t: float = 0.035
		B(g, Vector3(c.x - w * 0.5 - t, c.y - h * 0.5 - t, c.z - 0.03), Vector3(c.x + w * 0.5 + t, c.y - h * 0.5, c.z + 0.02), "chrome")
		B(g, Vector3(c.x - w * 0.5 - t, c.y + h * 0.5, c.z - 0.03), Vector3(c.x + w * 0.5 + t, c.y + h * 0.5 + t, c.z + 0.02), "chrome")
		B(g, Vector3(c.x - w * 0.5 - t, c.y - h * 0.5, c.z - 0.03), Vector3(c.x - w * 0.5, c.y + h * 0.5, c.z + 0.02), "chrome")
		B(g, Vector3(c.x + w * 0.5, c.y - h * 0.5, c.z - 0.03), Vector3(c.x + w * 0.5 + t, c.y + h * 0.5, c.z + 0.02), "chrome")
		var bars: int = int(w / 0.075)
		for i2: int in bars:
			var x2: float = c.x - w * 0.5 + (float(i2) + 0.5) * (w / float(bars))
			S(g, Vector3(x2, c.y - h * 0.5, c.z - 0.012), Vector3(x2, c.y + h * 0.5, c.z - 0.012), 0.007, "chrome")
		S(g, Vector3(c.x - w * 0.5, c.y, c.z - 0.016), Vector3(c.x + w * 0.5, c.y, c.z - 0.016), 0.009, "chrome")


static func _dial_pos(lay: Dictionary) -> Vector3:
	if lay.has("dial"):
		return lay["dial"]
	return (lay["slot"] as Vector3) + Vector3(0, 0.2, -0.005)


static func _hatch(g: Node3D, c: Vector3, w: float) -> void:
	B(g, Vector3(c.x - w * 0.5, c.y - 0.1, c.z - 0.02), Vector3(c.x + w * 0.5, c.y + 0.1, c.z + 0.03), "chrome")
	B(g, Vector3(c.x - w * 0.5 + 0.03, c.y - 0.07, c.z - 0.025), Vector3(c.x + w * 0.5 - 0.03, c.y + 0.07, c.z - 0.015), "window_dark")
	OB(g, Vector3(c.x, c.y - 0.075, c.z - 0.05), Vector3(w - 0.04, 0.02, 0.07), "chrome", Vector3(-12, 0, 0))
	OB(g, Vector3(c.x, c.y + 0.085, c.z - 0.03), Vector3(w * 0.5, 0.012, 0.02), "brass")


## Scrip slot: a chrome plate with a slot and a raised brass tally mark (ǂ).
static func _scrip_slot(g: Node3D, c: Vector3) -> void:
	B(g, Vector3(c.x - 0.055, c.y - 0.09, c.z - 0.01), Vector3(c.x + 0.055, c.y + 0.09, c.z + 0.02), "chrome")
	B(g, Vector3(c.x - 0.006, c.y + 0.02, c.z - 0.016), Vector3(c.x + 0.006, c.y + 0.07, c.z - 0.008), "window_dark")
	OB(g, Vector3(c.x, c.y - 0.035, c.z - 0.016), Vector3(0.012, 0.075, 0.01), "brass")
	OB(g, Vector3(c.x, c.y - 0.02, c.z - 0.018), Vector3(0.05, 0.01, 0.01), "brass")
	OB(g, Vector3(c.x, c.y - 0.05, c.z - 0.018), Vector3(0.05, 0.01, 0.01), "brass")


## Base plate: a brass strip (the Helvetia motto plate) on a black plinth.
static func _plinth(g: Node3D, w: float, d: float, h: float = 0.1) -> void:
	B(g, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), "black_paint")
	B(g, Vector3(-w * 0.32, h * 0.25, -d * 0.5 - 0.01), Vector3(w * 0.32, h * 0.8, -d * 0.5), "brass")


# ---- Ironhide Stout: a barrel stood on end, iron-red enamel staves, black hoops, brass rivets, steam valve.
static func _barrel(g: Node3D, fp: Vector3, en: String) -> void:
	var r: float = fp.x * 0.5
	tube(g, Vector3(0, 0.05, 0), Vector3(r * 2.0 + 0.04, 0.1, r * 2.0 + 0.04), "black_paint")
	tube(g, Vector3(0, 0.98, 0), Vector3(r * 1.8, 1.76, r * 1.8), en)
	tube(g, Vector3(0, 0.98, 0), Vector3(r * 1.96, 1.2, r * 1.96), en)
	tube(g, Vector3(0, 0.98, 0), Vector3(r * 2.0, 0.7, r * 2.0), en)
	# staves: dark seams down the sides
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		if absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.45:
			continue   # leave the front clear for the window
		OB(g, Vector3(cos(a) * r * 0.985, 0.98, sin(a) * r * 0.985), Vector3(0.012, 1.25, 0.02), "black_paint", Vector3(0, -rad_to_deg(a), 0))
	for hy: Array in [[0.2, 0.92], [0.55, 0.985], [1.41, 0.985], [1.76, 0.92]]:
		var hr: float = r * float(hy[1]) + 0.012
		tube(g, Vector3(0, float(hy[0]), 0), Vector3(hr * 2.0, 0.07, hr * 2.0), "iron")
		for k2: int in 10:
			var a2: float = PI + PI * (float(k2) + 0.5) / 10.0
			dot(g, Vector3(cos(a2) * (hr + 0.004), float(hy[0]), sin(a2) * (hr + 0.004)), 0.016, "brass")
	tube(g, Vector3(0, 1.87, 0), Vector3(r * 1.74, 0.04, r * 1.74), "furniture")
	ring(g, Vector3(0, 1.88, 0), r * 0.9, 0.035, "iron")
	tube(g, Vector3(0, 1.9, 0), Vector3(0.14, 0.05, 0.14), "brass")   # bung
	# front panel (the window, hatch and slot are mounted on it)
	B(g, Vector3(-0.32, 0.32, -0.6), Vector3(0.32, 1.56, -0.52), en)
	for side: float in [-1.0, 1.0]:
		B(g, Vector3(side * 0.32 - 0.015, 0.32, -0.615), Vector3(side * 0.32 + 0.015, 1.56, -0.52), "brass")
	# steam valve on the right side
	C(g, Vector3(0.66, 1.6, 0.0), 0.035, 0.18, "brass", Vector3(0, 0, 90))
	C(g, Vector3(0.74, 1.66, 0.0), 0.03, 0.12, "brass")
	ring(g, Vector3(0.74, 1.73, 0.0), 0.07, 0.014, "red_paint")
	S(g, Vector3(0.67, 1.73, 0), Vector3(0.81, 1.73, 0), 0.01, "red_paint")
	S(g, Vector3(0.74, 1.73, -0.07), Vector3(0.74, 1.73, 0.07), 0.01, "red_paint")
	# sign posts
	for sx: float in [-0.5, 0.5]:
		S(g, Vector3(sx, 1.86, -0.3), Vector3(sx, 2.05, -0.37), 0.04, "iron", false)
	# Fassl, the tin barrel mascot, flexing on the lid
	var m: Vector3 = Vector3(-0.3, 1.9, 0.1)
	tube(g, m + Vector3(0, 0.15, 0), Vector3(0.2, 0.26, 0.2), en)
	for my: float in [0.06, 0.24]:
		tube(g, m + Vector3(0, my, 0), Vector3(0.21, 0.025, 0.21), "iron")
	S(g, m + Vector3(0.1, 0.17, 0), m + Vector3(0.2, 0.2, 0), 0.04, "iron")
	S(g, m + Vector3(0.2, 0.2, 0), m + Vector3(0.21, 0.32, 0), 0.04, "iron")
	dot(g, m + Vector3(0.21, 0.34, 0), 0.03, "iron")
	OB(g, m + Vector3(0.0, 0.17, -0.1), Vector3(0.1, 0.03, 0.01), "cream")


# ---- Second Wind Schnapps: a slender apothecary cabinet, pale blue with white-cross panels, a glass dome on top.
static func _apothecary(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	_plinth(g, fp.x + 0.06, fp.z + 0.06, 0.12)
	B(g, Vector3(-hw, 0.12, -hd), Vector3(hw, 1.9, hd), en)
	B(g, Vector3(-hw - 0.03, 1.9, -hd - 0.03), Vector3(hw + 0.03, 1.98, hd + 0.03), "cream")
	B(g, Vector3(-hw - 0.02, 0.12, -hd - 0.02), Vector3(hw + 0.02, 0.2, hd + 0.02), "cream")
	for sx: float in [-1.0, 1.0]:
		B(g, Vector3(sx * hw - 0.02, 0.2, -hd - 0.02), Vector3(sx * hw + 0.02, 1.9, -hd + 0.03), "chrome")
		# white-cross panels on the sides
		var px: float = sx * (hw + 0.006)
		B(g, Vector3(px - 0.004, 1.1, -0.06), Vector3(px + 0.004, 1.5, 0.06), "enamel_white")
		B(g, Vector3(px - 0.004, 1.24, -0.2), Vector3(px + 0.004, 1.36, 0.2), "enamel_white")
		# a small bellows on the left side, wheezing like breath
	for i: int in 5:
		var bw: float = 0.16 - absf(float(i) - 2.0) * 0.02
		B(g, Vector3(-hw - 0.05, 0.62 + i * 0.03, -bw), Vector3(-hw, 0.64 + i * 0.03, bw), "leather")
	B(g, Vector3(-hw - 0.06, 0.58, -0.18), Vector3(-hw, 0.6, 0.18), "furniture")
	B(g, Vector3(-hw - 0.06, 0.78, -0.18), Vector3(-hw, 0.8, 0.18), "furniture")
	# the swallow, hand-painted over the factory angel (a faint outline still shows under it)
	var sw: Vector3 = Vector3(0, 1.74, -hd - 0.006)
	OB(g, sw + Vector3(0.0, 0.0, 0.002), Vector3(0.2, 0.09, 0.004), "paint:#a7b3bc")
	OB(g, sw + Vector3(-0.07, 0.02, 0), Vector3(0.15, 0.025, 0.004), "paint:#1d2740", Vector3(0, 0, -22))
	OB(g, sw + Vector3(0.07, 0.02, 0), Vector3(0.15, 0.025, 0.004), "paint:#1d2740", Vector3(0, 0, 22))
	OB(g, sw + Vector3(0.0, -0.02, 0), Vector3(0.04, 0.06, 0.004), "paint:#1d2740")
	OB(g, sw + Vector3(0.0, -0.06, 0), Vector3(0.05, 0.02, 0.004), "paint:#1d2740", Vector3(0, 0, 45))
	# frosted surround of the window
	B(g, Vector3(-0.3, 1.0, -hd - 0.012), Vector3(0.3, 1.7, -hd - 0.004), "frosted")
	# the dome
	tube(g, Vector3(0, 2.0, 0), Vector3(0.6, 0.06, 0.5), "chrome")
	ell(g, Vector3(0, 2.02, 0), Vector3(0.52, 0.56, 0.44), "glass")
	dot(g, Vector3(0, 2.32, 0), 0.03, "brass")
	# crest posts for the sign
	for sx2: float in [-0.5, 0.5]:
		S(g, Vector3(sx2 * 0.9, 1.98, -0.1), Vector3(sx2 * 0.9, 2.5, -0.16), 0.03, "chrome", false)


# ---- Trigger Tonic: an upright ammunition crate on legs, lime-gold with black chevrons and a big useless lever.
static func _ammo_crate(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			B(g, Vector3(sx * hw - (0.06 if sx > 0 else -0.0), 0, sz * hd - (0.06 if sz > 0 else 0.0)),
				Vector3(sx * hw + (0.0 if sx > 0 else 0.06), 0.34, sz * hd + (0.0 if sz > 0 else 0.06)), "iron")
	B(g, Vector3(-hw, 0.3, -hd), Vector3(hw, 2.0, hd), en)
	# battens (box-joint corners) and lid
	for sx2: float in [-1.0, 1.0]:
		B(g, Vector3(sx2 * hw - 0.04, 0.3, -hd - 0.02), Vector3(sx2 * hw + 0.04, 2.0, -hd + 0.04), "black_paint")
		B(g, Vector3(sx2 * hw - 0.04, 0.3, hd - 0.04), Vector3(sx2 * hw + 0.04, 2.0, hd + 0.02), "black_paint")
		# rope handles
		S(g, Vector3(sx2 * (hw + 0.03), 1.62, -0.16), Vector3(sx2 * (hw + 0.07), 1.56, 0.0), 0.025, "sandbag")
		S(g, Vector3(sx2 * (hw + 0.07), 1.56, 0.0), Vector3(sx2 * (hw + 0.03), 1.62, 0.16), 0.025, "sandbag")
	B(g, Vector3(-hw - 0.03, 1.94, -hd - 0.03), Vector3(hw + 0.03, 2.02, hd + 0.03), "black_paint")
	B(g, Vector3(-hw - 0.01, 0.3, -hd - 0.02), Vector3(hw + 0.01, 0.36, hd + 0.02), "black_paint")
	# black chevrons below the hatch
	for i: int in 3:
		var cy: float = 0.48 + i * 0.1
		OB(g, Vector3(-0.17, cy + 0.05, -hd - 0.006), Vector3(0.4, 0.045, 0.006), "black_paint", Vector3(0, 0, -24))
		OB(g, Vector3(0.17, cy + 0.05, -hd - 0.006), Vector3(0.4, 0.045, 0.006), "black_paint", Vector3(0, 0, 24))
	# sunburst rays around the window
	var wc: Vector3 = Vector3(0, 1.4, -hd - 0.008)
	for k: int in 12:
		var a: float = PI * float(k) / 11.0
		var d: Vector3 = Vector3(cos(a), sin(a), 0)
		OB(g, wc + d * 0.42 + Vector3(0, 0.04, 0), Vector3(0.012, 0.16, 0.004), "black_paint", Vector3(0, 0, rad_to_deg(a) - 90.0))
	# the big chrome lever on the right side (it does nothing)
	C(g, Vector3(hw + 0.05, 1.3, 0.0), 0.08, 0.08, "chrome", Vector3(0, 0, 90))
	S(g, Vector3(hw + 0.1, 1.3, 0.0), Vector3(hw + 0.12, 1.72, -0.16), 0.035, "chrome")
	dot(g, Vector3(hw + 0.12, 1.75, -0.17), 0.055, "red_paint")
	# stencil band
	B(g, Vector3(-hw + 0.08, 1.78, -hd - 0.006), Vector3(hw - 0.08, 1.88, -hd - 0.002), "black_paint")
	# sign posts on the lid
	for sx3: float in [-0.44, 0.44]:
		S(g, Vector3(sx3, 2.0, -hd + 0.14), Vector3(sx3, 2.07, -hd + 0.14), 0.04, "black_paint", false)


# ---- Twin Barrel Bitters: two amber towers like a side-by-side stood on its butt, a brass bridge with the window.
static func _twin_towers(g: Node3D, fp: Vector3, en: String) -> void:
	_plinth(g, fp.x + 0.04, fp.z + 0.04, 0.1)
	B(g, Vector3(-0.32, 0.1, -0.05), Vector3(0.32, 2.0, 0.26), "walnut")   # the walnut back between the towers
	for sx: float in [-0.32, 0.32]:
		tube(g, Vector3(sx, 1.05, 0), Vector3(0.56, 1.9, 0.56), en)
		for by: float in [0.25, 0.75, 1.55, 1.9]:
			tube(g, Vector3(sx, by, 0), Vector3(0.6, 0.05, 0.6), "brass")
		# the muzzle crown and its dark bore
		tube(g, Vector3(sx, 2.04, 0), Vector3(0.6, 0.08, 0.6), "chrome")
		tube(g, Vector3(sx, 2.06, 0), Vector3(0.4, 0.06, 0.4), "window_dark")
		# walnut panels on the outer flanks
		B(g, Vector3(sx + signf(sx) * 0.22, 0.35, -0.16), Vector3(sx + signf(sx) * 0.3, 1.75, 0.16), "walnut")
	# the brass bridge
	B(g, Vector3(-0.28, 0.98, -0.26), Vector3(0.28, 1.58, 0.1), "brass")
	B(g, Vector3(-0.26, 1.0, -0.28), Vector3(0.26, 1.56, -0.25), "enamel:#2a1608")
	B(g, Vector3(-0.22, 0.66, -0.26), Vector3(0.22, 0.98, 0.0), "enamel:#2a1608")
	B(g, Vector3(-0.14, 1.58, -0.26), Vector3(0.14, 1.78, -0.2), "chrome")
	# Feldwebel Pomp, the tin sergeant, between the muzzles
	var m: Vector3 = Vector3(0, 2.02, 0.1)
	B(g, m + Vector3(-0.05, 0.0, -0.03), m + Vector3(0.05, 0.14, 0.03), "paint:#3b4a2a")
	dot(g, m + Vector3(0, 0.19, 0), 0.045, "paint:#c9a27a")
	OB(g, m + Vector3(0, 0.17, -0.045), Vector3(0.12, 0.02, 0.01), "black_paint", Vector3(0, 0, 0))
	tube(g, m + Vector3(0, 0.25, 0), Vector3(0.09, 0.05, 0.09), "paint:#3b4a2a")
	for s: float in [-1.0, 1.0]:
		S(g, m + Vector3(s * 0.05, 0.11, 0), m + Vector3(s * 0.14, 0.15, -0.06), 0.025, "paint:#3b4a2a")
		OB(g, m + Vector3(s * 0.15, 0.16, -0.09), Vector3(0.02, 0.03, 0.08), "iron")
	for sx2: float in [-0.5, 0.5]:
		S(g, Vector3(sx2, 2.08, -0.02), Vector3(sx2, 2.2, -0.06), 0.03, "brass", false)


# ---- Marathon Malt: an Art Deco teardrop, sky blue and white, chrome speed-lines and a winged boot.
static func _streamliner(g: Node3D, fp: Vector3, en: String) -> void:
	tube(g, Vector3(0, 0.06, 0), Vector3(fp.x + 0.04, 0.12, fp.z + 0.04), "chrome")
	ell(g, Vector3(0, 1.18, 0), Vector3(fp.x, 2.3, fp.z * 0.92), en)
	ell(g, Vector3(0, 0.62, 0), Vector3(fp.x * 0.94, 1.0, fp.z * 0.88), "enamel_white")
	tube(g, Vector3(0, 0.38, 0), Vector3(fp.x * 0.82, 0.5, fp.z * 0.76), "enamel_white")
	# chrome speed-lines following the profile
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var off: float = 0.94 - k * 0.07
			var prev: Vector3 = Vector3.ZERO
			for i: int in 13:
				var t: float = -0.75 + 1.5 * float(i) / 12.0
				var y: float = 1.18 + t * 1.15
				var rx: float = fp.x * 0.5 * sqrt(maxf(0.0, 1.0 - t * t)) * off + 0.012
				var p: Vector3 = Vector3(side * rx, y, 0.06 * k - 0.06)
				if i > 0:
					S(g, prev, p, 0.016, "chrome")
				prev = p
	# a flat front panel for the window
	B(g, Vector3(-0.27, 0.66, -0.45), Vector3(0.27, 1.76, -0.38), en)
	for sx: float in [-0.27, 0.27]:
		B(g, Vector3(sx - 0.012, 0.66, -0.46), Vector3(sx + 0.012, 1.76, -0.38), "chrome")
	# the winged boot, mid-stride
	var b: Vector3 = Vector3(0, 1.92, -0.36)
	OB(g, b + Vector3(0, 0.04, 0), Vector3(0.06, 0.12, 0.05), "paint:#2e1d12", Vector3(0, 0, -10))
	OB(g, b + Vector3(0.04, -0.03, 0), Vector3(0.11, 0.04, 0.05), "paint:#2e1d12")
	for wk: int in 3:
		OB(g, b + Vector3(-0.07 - wk * 0.025, 0.08 + wk * 0.025, 0.0), Vector3(0.11, 0.02, 0.01), "enamel_white", Vector3(0, 0, 25 + wk * 12))
	# crown
	tube(g, Vector3(0, 2.33, 0), Vector3(0.18, 0.04, 0.18), "chrome")
	for sx2: float in [-0.55, 0.55]:
		S(g, Vector3(sx2 * 0.5, 2.2, -0.05), Vector3(sx2, 2.52, -0.08), 0.025, "chrome", false)


# ---- Hawkeye Brandy: forest-green cabinet, walnut front, brass; a periscope that turns to watch you.
static func _periscope(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	_plinth(g, fp.x + 0.06, fp.z + 0.06, 0.1)
	B(g, Vector3(-hw, 0.1, -hd), Vector3(hw, 1.8, hd), en)
	B(g, Vector3(-hw + 0.06, 0.18, -hd - 0.02), Vector3(hw - 0.06, 1.66, -hd + 0.01), "walnut")
	B(g, Vector3(-hw - 0.02, 1.76, -hd - 0.02), Vector3(hw + 0.02, 1.84, hd + 0.02), "brass")
	for sx: float in [-1.0, 1.0]:
		B(g, Vector3(sx * hw - 0.015, 0.1, -hd - 0.015), Vector3(sx * hw + 0.015, 1.8, -hd + 0.015), "brass")
	# brass oval medallion: the monocled hawk
	var mc: Vector3 = Vector3(0, 1.56, -hd - 0.03)
	ring(g, mc, 0.08, 0.014, "brass", Vector3(90, 0, 0))
	OB(g, mc + Vector3(0, 0, 0.005), Vector3(0.12, 0.12, 0.008), "paint:#3a2a1a", Vector3(0, 0, 45))
	ring(g, mc + Vector3(0.025, 0.02, -0.006), 0.022, 0.005, "brass", Vector3(90, 0, 0))
	OB(g, mc + Vector3(-0.02, -0.01, -0.006), Vector3(0.05, 0.02, 0.004), "yellow_paint", Vector3(0, 0, -30))
	# periscope mast (the head is a separate node that turns)
	C(g, Vector3(0, 1.84, 0.12), 0.1, 0.06, "brass")
	C(g, Vector3(0, 2.15, 0.12), 0.055, 0.62, "brass")
	ring(g, Vector3(0, 2.1, 0.12), 0.07, 0.015, "black_paint")
	# sign brackets
	for sx2: float in [-0.42, 0.42]:
		S(g, Vector3(sx2, 1.84, -hd + 0.2), Vector3(sx2, 1.92, -hd + 0.16), 0.03, "brass", false)


## The periscope head (turns on Y): a hood with the lens toward local -Z.
static func periscope_head(g: Node3D) -> void:
	B(g, Vector3(-0.09, -0.08, -0.16), Vector3(0.09, 0.09, 0.1), "enamel:#22553a")
	B(g, Vector3(-0.1, 0.08, -0.17), Vector3(0.1, 0.11, 0.11), "brass")
	C(g, Vector3(0, 0, -0.17), 0.065, 0.04, "brass", Vector3(90, 0, 0))
	C(g, Vector3(0, 0, -0.19), 0.05, 0.01, "glass", Vector3(90, 0, 0))


# ---- Packmule Porter: the widest one, a quartermaster's wagon of a cabinet with crates, straps and spare rifles.
static func _wagon(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	B(g, Vector3(-hw, 0.14, -hd), Vector3(hw, 1.3, hd), en)
	B(g, Vector3(-hw - 0.02, 0.1, -hd - 0.02), Vector3(hw + 0.02, 0.2, hd + 0.02), "paint:#3a3d24")
	B(g, Vector3(-hw - 0.02, 1.26, -hd - 0.02), Vector3(hw + 0.02, 1.32, hd + 0.02), "paint:#3a3d24")
	# olive drab panel and stencil band
	B(g, Vector3(-hw + 0.08, 0.3, -hd - 0.01), Vector3(-0.02, 1.2, -hd + 0.01), "paint:#3a3d24")
	B(g, Vector3(0.1, 1.2, -hd - 0.012), Vector3(hw - 0.1, 1.24, -hd - 0.004), "black_paint")
	# brass buckles and straps down the front
	for sx: float in [-0.68, 0.0, 0.68]:
		B(g, Vector3(sx - 0.03, 0.2, -hd - 0.012), Vector3(sx + 0.03, 1.3, -hd - 0.002), "leather")
		B(g, Vector3(sx - 0.04, 0.8, -hd - 0.02), Vector3(sx + 0.04, 0.86, -hd - 0.01), "brass")
	# cart wheels at the ends
	for s: float in [-1.0, 1.0]:
		var wc: Vector3 = Vector3(s * (hw + 0.04), 0.36, 0)
		ring(g, wc, 0.34, 0.05, "iron", Vector3(0, 0, 90))
		C(g, wc, 0.07, 0.1, "furniture", Vector3(0, 0, 90))
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			S(g, wc, wc + Vector3(0, sin(a), cos(a)) * 0.31, 0.03, "furniture", false)
	# luggage rack and its load
	for sx2: float in [-hw + 0.05, hw - 0.05]:
		for sz: float in [-hd + 0.05, hd - 0.05]:
			S(g, Vector3(sx2, 1.3, sz), Vector3(sx2, 1.5, sz), 0.03, "iron")
	for sz2: float in [-hd + 0.05, hd - 0.05]:
		S(g, Vector3(-hw + 0.05, 1.5, sz2), Vector3(hw - 0.05, 1.5, sz2), 0.025, "iron")
	B(g, Vector3(-0.78, 1.32, -0.3), Vector3(-0.2, 1.7, 0.32), "furniture")
	B(g, Vector3(-0.14, 1.32, -0.25), Vector3(0.36, 1.6, 0.3), "tarp")
	B(g, Vector3(0.4, 1.32, -0.2), Vector3(0.78, 1.52, 0.3), "furniture")
	for sx3: float in [-0.6, -0.36, 0.1]:
		B(g, Vector3(sx3 - 0.025, 1.32, -0.32), Vector3(sx3 + 0.025, 1.72, 0.34), "leather")
	# spare rifles bolted along the right flank
	for i: int in 2:
		var rz: float = -0.2 + i * 0.3
		var a2: Vector3 = Vector3(hw + 0.04, 0.3, rz)
		S(g, a2, a2 + Vector3(0, 0.45, 0.02), 0.05, "walnut", false)
		S(g, a2 + Vector3(0, 0.45, 0.02), a2 + Vector3(0, 1.15, 0.0), 0.022, "iron")
		B(g, a2 + Vector3(-0.03, 0.55, -0.05), a2 + Vector3(0.0, 0.6, 0.05), "brass")
	# sign brackets and the gallows for the swinging "Porter" tin sign
	for sx4: float in [-0.5, 0.5]:
		S(g, Vector3(sx4, 1.7, -hd + 0.2), Vector3(sx4, 1.86, -hd + 0.18), 0.03, "iron", false)
	S(g, Vector3(-hw + 0.02, 1.3, -hd + 0.02), Vector3(-hw - 0.3, 1.3, -hd + 0.02), 0.03, "iron", false)


# ---- Blastproof Bock: a riveted blast locker, orange-and-black hazard stripes, a porthole and a wheel handle.
static func _safe(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	_plinth(g, fp.x + 0.06, fp.z + 0.06, 0.08)
	B(g, Vector3(-hw, 0.08, -hd + 0.06), Vector3(hw, 1.9, hd), "black_paint")
	B(g, Vector3(-hw - 0.01, 0.08, -hd + 0.04), Vector3(hw + 0.01, 1.9, -hd + 0.1), "stripes:#e0661a")
	# the heavy door, set into the striped frame
	B(g, Vector3(-hw + 0.1, 0.18, -hd - 0.02), Vector3(hw - 0.1, 1.78, -hd + 0.06), en)
	rivets(g, Vector3(-hw + 0.14, 1.74, -hd - 0.025), Vector3(hw - 0.14, 1.74, -hd - 0.025), 9)
	rivets(g, Vector3(-hw + 0.14, 0.22, -hd - 0.025), Vector3(hw - 0.14, 0.22, -hd - 0.025), 9)
	rivets(g, Vector3(-hw + 0.14, 0.3, -hd - 0.025), Vector3(-hw + 0.14, 1.66, -hd - 0.025), 7)
	rivets(g, Vector3(hw - 0.14, 0.3, -hd - 0.025), Vector3(hw - 0.14, 1.66, -hd - 0.025), 7)
	for hy: float in [0.45, 1.5]:
		C(g, Vector3(-hw + 0.08, hy, -hd - 0.03), 0.04, 0.22, "chrome_worn")
	# scorch on the lower door, soot rising
	B(g, Vector3(-hw + 0.12, 0.2, -hd - 0.024), Vector3(hw - 0.3, 0.5, -hd - 0.021), "char")
	# the wheel hub (the wheel turns)
	C(g, Vector3(0.24, 0.98, -hd - 0.05), 0.05, 0.06, "chrome_worn", Vector3(90, 0, 0))
	# starburst behind "Bock" on the sign
	var sb: Vector3 = Vector3(0.48, 2.24, -hd + 0.18)
	for k: int in 8:
		OB(g, sb, Vector3(0.36, 0.05, 0.01), "yellow_paint", Vector3(0, 0, k * 22.5))
	for sx: float in [-0.48, 0.48]:
		S(g, Vector3(sx, 1.9, -hd + 0.2), Vector3(sx, 2.04, -hd + 0.18), 0.04, "iron", false)


## The safe's wheel handle (turns about local Z).
static func safe_wheel(g: Node3D) -> void:
	ring(g, Vector3.ZERO, 0.17, 0.025, "chrome_worn", Vector3(90, 0, 0))
	for k: int in 3:
		OB(g, Vector3.ZERO, Vector3(0.32, 0.025, 0.025), "chrome_worn", Vector3(0, 0, k * 60.0))
	for k2: int in 6:
		var a: float = TAU * float(k2) / 6.0
		dot(g, Vector3(cos(a), sin(a), 0) * 0.17, 0.025, "red_paint")


## The bottle that turns slowly inside Second Wind's dome.
static func dome_bottle(g: Node3D, brand: Color) -> void:
	var gl: String = "glass:" + hex(brand)
	C(g, Vector3(0, 0.08, 0), 0.05, 0.16, gl)
	C(g, Vector3(0, 0.19, 0), 0.018, 0.07, gl)
	C(g, Vector3(0, 0.23, 0), 0.022, 0.016, "brass")
	B(g, Vector3(-0.04, 0.05, -0.052), Vector3(0.04, 0.12, -0.048), "cream")
	C(g, Vector3(0, -0.01, 0), 0.07, 0.02, "chrome")


## Packmule's hanging tin sign (pivot at the top).
static func porter_sign(g: Node3D) -> void:
	for s: float in [-0.1, 0.1]:
		S(g, Vector3(s, 0, 0), Vector3(s, -0.12, 0), 0.008, "iron")
	B(g, Vector3(-0.16, -0.24, -0.006), Vector3(0.16, -0.12, 0.006), "enamel:#c7b37a")
	B(g, Vector3(-0.17, -0.25, -0.004), Vector3(0.17, -0.11, 0.004), "black_paint")


# ---- Overclock Cordial: a tall teal cabinet with copper bands, cable loops like suspenders, a porthole under a
# LEER / HALB / VOLL needle gauge, and an induction coil on a ceramic collar for a crown (JINGLES.md section 10).
# The Plan was never brand-edited: no Darkmatter trim, the maker's own copper and tin. The arc, the needle, the
# brass ball (lamp globe) and the labels are the script's.
static func _coil_tower(g: Node3D, fp: Vector3, en: String) -> void:
	var hw: float = fp.x * 0.5
	var hd: float = fp.z * 0.5
	_plinth(g, fp.x + 0.06, fp.z + 0.06, 0.12)
	B(g, Vector3(-hw, 0.12, -hd), Vector3(hw, 2.0, hd), en)
	# copper bands and front edge rails
	for by: float in [0.3, 0.92, 1.46, 1.94]:
		B(g, Vector3(-hw - 0.012, by - 0.02, -hd - 0.012), Vector3(hw + 0.012, by + 0.02, hd + 0.012), "copper")
	for sx: float in [-1.0, 1.0]:
		B(g, Vector3(sx * hw - 0.02, 0.2, -hd - 0.02), Vector3(sx * hw + 0.02, 1.96, -hd + 0.03), "copper")
		# cable loops down each side, clipped at the crown and at the waist
		var x: float = sx * (hw + 0.045)
		for zs: float in [-1.0, 1.0]:
			var z0: float = zs * 0.12
			var z1: float = zs * 0.22
			S(g, Vector3(x, 1.97, z0), Vector3(x + sx * 0.07, 1.55, z1), 0.018, "copper")
			S(g, Vector3(x + sx * 0.07, 1.55, z1), Vector3(x + sx * 0.05, 1.05, z0 * 0.6), 0.018, "copper")
			S(g, Vector3(x + sx * 0.05, 1.05, z0 * 0.6), Vector3(x, 0.55, 0.0), 0.018, "copper")
			dot(g, Vector3(x, 1.97, z0), 0.028, "brass")
		dot(g, Vector3(x, 0.55, 0.0), 0.03, "brass")
	# the needle gauge above the porthole: a dial face in a copper rim, three marks (LEER, HALB, VOLL), a brass hub
	var gc: Vector3 = Vector3(0, 1.62, -hd - 0.025)
	C(g, gc, 0.2, 0.03, "gauge_face", Vector3(90, 0, 0))
	ring(g, gc + Vector3(0, 0, -0.006), 0.2, 0.022, "copper", Vector3(90, 0, 0))
	B(g, Vector3(-0.24, 1.38, -hd - 0.03), Vector3(0.24, 1.44, -hd - 0.005), "copper")
	for a: float in [-60.0, 0.0, 60.0]:
		var ang: float = deg_to_rad(90.0 - a)
		OB(g, gc + Vector3(cos(ang) * 0.165, sin(ang) * 0.165, -0.022), Vector3(0.012, 0.045, 0.006), "black_paint", Vector3(0, 0, -a))
	dot(g, gc + Vector3(0, 0, -0.022), 0.022, "brass")
	# crown: roof plate, ceramic collar, the induction coil, its rod (the brass ball is the lamp globe)
	var cz: float = 0.05
	B(g, Vector3(-0.24, 2.0, cz - 0.24), Vector3(0.24, 2.02, cz + 0.24), "copper")
	C(g, Vector3(0, 2.05, cz), 0.19, 0.08, "enamel_white")
	C(g, Vector3(0, 2.11, cz), 0.14, 0.05, "copper")
	for k: int in 9:
		ring(g, Vector3(0, 2.135 + k * 0.034, cz), 0.16, 0.013, "copper")
	C(g, Vector3(0, 2.28, cz), 0.028, 0.34, "copper")
	# valves on the roof's right (they pulse in the script's imagination; here they are brass stems with red caps)
	for i: int in 3:
		C(g, Vector3(0.3, 2.05, -0.16 + i * 0.13), 0.018, 0.1, "brass")
		dot(g, Vector3(0.3, 2.11, -0.16 + i * 0.13), 0.028, "red_paint")
	# sign posts on the front roof edge
	for sx2: float in [-0.44, 0.44]:
		S(g, Vector3(sx2, 1.98, -hd + 0.16), Vector3(sx2, 2.08, -hd + 0.12), 0.03, "copper", false)
	# Funki, the tin bin-shaped mascot: hinged-lid hat, round eyes, one antenna, a lightning bolt held overhead
	var m: Vector3 = Vector3(-0.3, 2.02, 0.13)
	tube(g, m + Vector3(0, 0.1, 0), Vector3(0.14, 0.2, 0.14), "tin")
	tube(g, m + Vector3(0, 0.21, 0), Vector3(0.16, 0.025, 0.16), "chrome_worn")
	B(g, m + Vector3(-0.02, 0.22, -0.08), m + Vector3(0.02, 0.245, -0.03), "chrome_worn")
	for ex: float in [-0.035, 0.035]:
		dot(g, m + Vector3(ex, 0.14, -0.07), 0.02, "cream")
		dot(g, m + Vector3(ex, 0.14, -0.086), 0.009, "black_paint")
	S(g, m + Vector3(0, 0.23, 0), m + Vector3(0.03, 0.34, 0), 0.006, "iron")
	dot(g, m + Vector3(0.03, 0.345, 0), 0.012, "red_paint")
	S(g, m + Vector3(0.07, 0.12, 0), m + Vector3(0.12, 0.27, 0), 0.015, "iron")
	S(g, m + Vector3(-0.07, 0.12, 0), m + Vector3(-0.11, 0.05, 0), 0.015, "iron")
	OB(g, m + Vector3(0.12, 0.32, 0), Vector3(0.035, 0.09, 0.012), "yellow_paint", Vector3(0, 0, 25))
	OB(g, m + Vector3(0.135, 0.38, 0), Vector3(0.035, 0.09, 0.012), "yellow_paint", Vector3(0, 0, -25))
	OB(g, m + Vector3(0.12, 0.44, 0), Vector3(0.035, 0.08, 0.012), "yellow_paint", Vector3(0, 0, 25))
	for fx: float in [-0.04, 0.04]:
		B(g, m + Vector3(fx - 0.025, 0, -0.04), m + Vector3(fx + 0.025, 0.02, 0.04), "iron")


## The violet arc that snaps from the coil's top turn to the brass ball (origin at the coil top, +Y up).
static func coil_arc(g: Node3D) -> void:
	var pts: Array = [Vector3(0.16, -0.02, 0.0), Vector3(0.11, 0.03, 0.03), Vector3(0.13, 0.07, -0.02), Vector3(0.07, 0.1, 0.02),
		Vector3(0.09, 0.14, -0.01), Vector3(0.04, 0.17, 0.0)]
	for i: int in pts.size() - 1:
		S(g, pts[i], pts[i + 1], 0.011, "neon:#c07dff")
	var pts2: Array = [Vector3(-0.15, -0.02, 0.03), Vector3(-0.1, 0.05, -0.02), Vector3(-0.11, 0.1, 0.02), Vector3(-0.05, 0.16, 0.0)]
	for i2: int in pts2.size() - 1:
		S(g, pts2[i2], pts2[i2 + 1], 0.008, "neon:#c07dff")


## The Lodestone's parts (T-105): the relay coil (a copper winding on a ceramic former), the gyro cradle (three
## brass rings), the lead-glass lens (a violet sphere on a felt pad); and the built weapon on the bench.
static func part_coil(g: Node3D) -> void:
	C(g, Vector3(0, 0.08, 0), 0.05, 0.16, "cream")
	for i: int in 9:
		ring(g, Vector3(0, 0.02 + i * 0.015, 0), 0.058, 0.007, "copper", Vector3(90, 0, 0))
	B(g, Vector3(-0.09, 0.0, -0.09), Vector3(0.09, 0.012, 0.09), "steel")


static func part_cradle(g: Node3D) -> void:
	ring(g, Vector3(0, 0.12, 0), 0.11, 0.012, "brass", Vector3(0, 0, 0))
	ring(g, Vector3(0, 0.12, 0), 0.095, 0.01, "brass", Vector3(90, 0, 0))
	ring(g, Vector3(0, 0.12, 0), 0.08, 0.009, "brass", Vector3(0, 90, 0))
	B(g, Vector3(-0.03, 0.0, -0.03), Vector3(0.03, 0.02, 0.03), "brass")


static func part_lens(g: Node3D) -> void:
	B(g, Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 0.03, 0.1), "cream")
	ell(g, Vector3(0, 0.1, 0), Vector3(0.14, 0.14, 0.14), "glass:#b07cff")
	dot(g, Vector3(0.03, 0.12, -0.03), 0.02, "neon:#c07dff")


static func lodestone(g: Node3D) -> void:
	B(g, Vector3(-0.015, 0.0, -0.15), Vector3(0.015, 0.03, 0.25), "brass")
	ring(g, Vector3(0, 0.14, -0.2), 0.1, 0.012, "brass")
	ring(g, Vector3(0, 0.14, -0.2), 0.085, 0.01, "brass", Vector3(90, 0, 0))
	ell(g, Vector3(0, 0.14, -0.2), Vector3(0.12, 0.12, 0.12), "glass:#b07cff")
	for i: int in 6:
		ring(g, Vector3(0, 0.015, 0.0 + i * 0.015), 0.028, 0.006, "copper")


## Skyhook Sekt's propeller (T-105): a two-blade wooden prop on a brass hub, pivot at the origin, turning about Z.
static func glider_prop(g: Node3D) -> void:
	dot(g, Vector3.ZERO, 0.045, "brass")
	C(g, Vector3(0, 0, -0.03), 0.03, 0.06, "brass", Vector3(90, 0, 0))
	for sgn: float in [-1.0, 1.0]:
		OB(g, Vector3(0, sgn * 0.19, 0), Vector3(0.06, 0.34, 0.012), "oak_stave", Vector3(0, 0, 0))
		OB(g, Vector3(0, sgn * 0.33, 0), Vector3(0.045, 0.1, 0.01), "oak_stave")


## Magpie Mead's one-armed-bandit lever (T-105): a steel arm with a red ball, pivot at the origin, pulled about X.
static func bandit_lever(g: Node3D) -> void:
	dot(g, Vector3.ZERO, 0.04, "steel")
	S(g, Vector3.ZERO, Vector3(0, 0.36, 0), 0.016, "steel")
	dot(g, Vector3(0, 0.38, 0), 0.05, "red_paint")


## Magpie Mead's three reels in the bottle window (T-105): drums that spin about X, AMMO / SCRIP / GRENADE faces.
static func bandit_reels(g: Node3D) -> void:
	for i: int in 3:
		var reel: Node3D = Node3D.new()
		reel.position = Vector3(-0.14 + i * 0.14, 0, 0)
		g.add_child(reel)
		C(reel, Vector3.ZERO, 0.075, 0.1, "cream", Vector3(0, 0, 90))
		for k: int in 3:
			var a: float = TAU * float(k) / 3.0
			OB(reel, Vector3(0, cos(a) * 0.076, sin(a) * 0.076), Vector3(0.08, 0.03, 0.01), ["brass", "olive_drab", "red_paint"][k], Vector3(-rad_to_deg(a), 0, 0))


## The gauge needle (pivot at the origin, points +Y at rest; the script turns it about Z).
static func gauge_needle(g: Node3D) -> void:
	OB(g, Vector3(0, 0.075, 0), Vector3(0.012, 0.15, 0.006), "red_paint")
	OB(g, Vector3(0, -0.03, 0), Vector3(0.02, 0.05, 0.006), "brass")
	dot(g, Vector3.ZERO, 0.014, "brass")


# ================================================================== the Crucible (WEAPONS.md §11)

## The furnace (cached): a stepped plinth, a riveted black-iron body and dome, Nachtglas buttresses, a flue,
## bellows, a sight glass, and a wrought-iron arch carrying the nameplate. Front is local -Z; the glowing mouth,
## the light and the embers are the script's.
static func crucible_body(g: Node3D) -> void:
	# plinth: two dressed steps
	B(g, Vector3(-1.35, 0, -1.15), Vector3(1.35, 0.14, 1.1), "concrete")
	B(g, Vector3(-1.15, 0.14, -0.95), Vector3(1.15, 0.3, 0.92), "machine_grey")
	rivets(g, Vector3(-1.1, 0.22, -0.96), Vector3(1.1, 0.22, -0.96), 14, 0.02)
	# the body: an elliptic iron drum with a dome
	tube(g, Vector3(0, 1.05, 0.02), Vector3(1.96, 1.5, 1.54), "loco_black")
	ell(g, Vector3(0, 1.78, 0.02), Vector3(1.96, 0.96, 1.54), "loco_black")
	for by: float in [0.42, 0.92, 1.5]:
		tube(g, Vector3(0, by, 0.02), Vector3(2.02, 0.09, 1.6), "iron")
		for k: int in 14:
			var a: float = PI + PI * (float(k) + 0.5) / 14.0
			dot(g, Vector3(cos(a) * 1.015, by, 0.02 + sin(a) * 0.805), 0.022, "brass")
	# Nachtglas veins grown into the dome
	for v: Array in [[Vector3(-0.5, 1.9, -0.66), Vector3(-0.2, 2.2, -0.35)], [Vector3(0.45, 1.75, -0.7), Vector3(0.3, 2.15, -0.38)],
			[Vector3(-0.85, 1.6, -0.35), Vector3(-0.7, 2.0, -0.1)], [Vector3(0.88, 1.55, -0.3), Vector3(0.66, 2.05, 0.0)]]:
		S(g, v[0], v[1], 0.035, "nachtglas_vein")
	# the mouth: a cast surround with a voussoir arch and a grate in front of the fire
	B(g, Vector3(-0.68, 0.62, -0.86), Vector3(-0.52, 1.5, -0.7), "iron")
	B(g, Vector3(0.52, 0.62, -0.86), Vector3(0.68, 1.5, -0.7), "iron")
	B(g, Vector3(-0.68, 0.6, -0.88), Vector3(0.68, 0.74, -0.7), "iron")
	for k2: int in 7:
		var a2: float = PI * float(k2) / 6.0
		OB(g, Vector3(cos(a2) * 0.6, 1.45 + sin(a2) * 0.32, -0.8), Vector3(0.2, 0.14, 0.14), "iron", Vector3(0, 0, rad_to_deg(a2) - 90.0))
	OB(g, Vector3(0, 1.8, -0.84), Vector3(0.16, 0.2, 0.12), "brass")
	for gx: int in 6:
		S(g, Vector3(-0.42 + gx * 0.168, 0.76, -0.88), Vector3(-0.42 + gx * 0.168, 1.42, -0.88), 0.03, "iron")
	S(g, Vector3(-0.5, 1.08, -0.9), Vector3(0.5, 1.08, -0.9), 0.025, "iron")
	# Nachtglas buttresses at the four corners
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base: Vector3 = Vector3(sx * 1.08, 0.3, sz * 0.82)
			var tip: Vector3 = Vector3(sx * 0.86, 1.75, sz * 0.64)
			S(g, base, tip, 0.13, "nachtglas_dim", false)
			Props.crystal_cluster(g, Vector3(sx * 1.2, 0.14, sz * 0.98), 71 + int(sx * 3.0 + sz), 0.5, "nachtglas_crystal")
			Props.crystal_cluster(g, tip, 91 + int(sx * 3.0 + sz), 0.35, "nachtglas_crystal", (tip - base).normalized())
	# the flue: a tapering stack with bands and a cap
	tube(g, Vector3(0, 2.6, 0.2), Vector3(0.62, 0.5, 0.62), "loco_black")
	tube(g, Vector3(0, 3.3, 0.2), Vector3(0.5, 1.2, 0.5), "loco_black")
	for fy: float in [2.45, 2.9, 3.4, 3.85]:
		tube(g, Vector3(0, fy, 0.2), Vector3(0.58, 0.06, 0.58), "iron")
	Props.cone(g, Vector3(0, 4.05, 0.2), 0.42, 0.25, "iron")
	# bellows on the +X flank, piped into the drum
	var bl: Vector3 = Vector3(1.32, 0.6, 0.45)
	for i: int in 5:
		OB(g, bl + Vector3(0, 0.12 + i * 0.05, 0), Vector3(0.34 - absf(i - 2.0) * 0.04, 0.04, 0.6), "leather")
	OB(g, bl, Vector3(0.4, 0.06, 0.7), "furniture")
	OB(g, bl + Vector3(0, 0.38, 0), Vector3(0.4, 0.05, 0.7), "furniture")
	S(g, bl + Vector3(-0.1, 0.12, -0.3), Vector3(0.92, 0.8, -0.1), 0.08, "copper")
	S(g, bl + Vector3(0, 0.4, 0.0), bl + Vector3(0.0, 0.9, 0.0), 0.02, "iron")
	# sight glass: a violet suspension in a brass-caged tube on the -X front
	var sg: Vector3 = Vector3(-0.82, 1.15, -0.7)
	tube(g, sg, Vector3(0.12, 0.62, 0.12), "nachtglas_liquid")
	for cy: float in [-0.33, 0.33]:
		tube(g, sg + Vector3(0, cy, 0), Vector3(0.17, 0.05, 0.17), "brass")
	for k3: int in 3:
		var a3: float = TAU * float(k3) / 3.0
		S(g, sg + Vector3(cos(a3) * 0.075, -0.3, sin(a3) * 0.075), sg + Vector3(cos(a3) * 0.075, 0.3, sin(a3) * 0.075), 0.012, "brass")
	# pressure gauge on the +X front
	var gp: Vector3 = Vector3(0.84, 1.28, -0.66)
	C(g, gp, 0.13, 0.06, "brass", Vector3(90, -35, 0))
	C(g, gp + Vector3(-0.02, 0, -0.03), 0.11, 0.01, "gauge_face", Vector3(90, -35, 0))
	OB(g, gp + Vector3(-0.03, 0.03, -0.04), Vector3(0.012, 0.09, 0.006), "red_paint", Vector3(0, -35, -30))
	# the wrought-iron arch with the nameplate
	for sx2: float in [-1.0, 1.0]:
		S(g, Vector3(sx2 * 1.22, 0.14, -1.05), Vector3(sx2 * 1.22, 2.55, -1.05), 0.1, "iron", false)
		Props.cone(g, Vector3(sx2 * 1.22, 0.24, -1.05), 0.12, 0.2, "iron")
		dot(g, Vector3(sx2 * 1.22, 2.6, -1.05), 0.06, "brass")
	var prev: Vector3 = Vector3(-1.22, 2.55, -1.05)
	for k4: int in 9:
		var t: float = float(k4 + 1) / 9.0
		var p: Vector3 = Vector3(lerpf(-1.22, 1.22, t), 2.55 + sin(t * PI) * 0.42, -1.05)
		S(g, prev, p, 0.08, "iron", false)
		prev = p
	for sx3: float in [-0.5, 0.5]:
		S(g, Vector3(sx3, 2.9, -1.05), Vector3(sx3, 2.76, -1.05), 0.02, "iron")
	B(g, Vector3(-0.66, 2.48, -1.09), Vector3(0.66, 2.76, -1.03), "nameplate")
	B(g, Vector3(-0.69, 2.45, -1.07), Vector3(0.69, 2.79, -1.02), "brass")
	# a low quench trough and tongs at the side
	B(g, Vector3(-1.32, 0.0, -0.4), Vector3(-1.12, 0.36, 0.5), "iron")
	S(g, Vector3(-1.25, 0.3, 0.3), Vector3(-1.05, 1.4, 0.55), 0.04, "iron")
	S(g, Vector3(-1.2, 0.3, 0.1), Vector3(-1.0, 1.25, 0.35), 0.035, "iron")


# ================================================================== barricade planks

static var _nail: CylinderMesh


## One nailed plank (single surface, vertex-tinted "board_wood"): split end, nail heads, a bent nail.
static func board_mesh(length: float, variant: int) -> ArrayMesh:
	var key: String = "board_%d_%d" % [int(length * 100.0), variant]
	if _meshes.has(key):
		return _meshes[key]
	if _nail == null:
		_nail = CylinderMesh.new()
		_nail.top_radius = 0.5
		_nail.bottom_radius = 0.5
		_nail.height = 1.0
		_nail.radial_segments = 6
		_nail.rings = 1
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box: BoxMesh = Props.unit_box()
	var tones: Array = [Color(1.0, 0.97, 0.92), Color(0.78, 0.74, 0.7), Color(1.1, 1.0, 0.86)]
	var tone: Color = tones[variant % 3]
	var iron: Color = Color(0.1, 0.09, 0.085)
	var cut: float = [0.05, 0.11, 0.0][variant % 3]
	var hl: float = length * 0.5
	# the plank, a hair shorter on one end, with a splintered wedge there
	add_prim(st, box, Transform3D(Basis().scaled(Vector3(length - cut, 0.16, 0.045)), Vector3(cut * 0.5, 0, 0)), tone)
	if cut > 0.0:
		add_prim(st, box, Transform3D(Basis(Vector3.FORWARD, 0.5).scaled(Vector3(cut * 1.3, 0.07, 0.04)), Vector3(-hl + cut * 0.5, 0.03, 0)), tone * 0.85)
	# a raised grain stripe and a dark knot
	add_prim(st, box, Transform3D(Basis().scaled(Vector3(length * 0.6, 0.012, 0.05)), Vector3(0.1 - variant * 0.08, -0.035, 0)), tone * 0.8)
	add_prim(st, Props.unit_cyl(), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.035, 0.05, 0.035)), Vector3(-0.2 + variant * 0.25, 0.03, 0)), tone * 0.45)
	# nails: two near each end on the inner (+Z) face, one bent
	for e: float in [-1.0, 1.0]:
		for k: int in 2:
			var p: Vector3 = Vector3(e * (hl - 0.08 - (cut if e < 0.0 else 0.0)), -0.045 + k * 0.09, 0.024)
			add_prim(st, _nail, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.022, 0.008, 0.022)), p), iron)
	var bent: Vector3 = Vector3(hl * 0.35, 0.05, 0.03)
	add_prim(st, _nail, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.008, 0.05, 0.008)), bent + Vector3(0, 0, 0.022)), iron)
	add_prim(st, _nail, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(0.008, 0.04, 0.008)), bent + Vector3(0.02, 0, 0.047)), iron)
	var am: ArrayMesh = st.commit()
	am.surface_set_material(0, Mats.get_mat("board_wood"))
	_meshes[key] = am
	return am


# ================================================================== buy doors

## A boarded doorway (cached per size): ledged-and-braced plank leaf, crossed boards, chain and padlock, and a sign
## board each side for the label.
static func door_wood(g: Node3D, size: Vector3) -> void:
	var w: float = size.x
	var h: float = size.y
	var t: float = size.z
	var n: int = maxi(4, int(round(w / 0.24)))
	var pw: float = w / float(n)
	for i: int in n:
		var x0: float = -w * 0.5 + i * pw
		var top: float = h - 0.02 - float((i * 7) % 3) * 0.03
		B(g, Vector3(x0 + 0.006, 0.0, -t * 0.3), Vector3(x0 + pw - 0.006, top, t * 0.3), "board_wood_v" if i % 2 == 0 else "board_wood_v2")
	for s: float in [-1.0, 1.0]:
		var f: float = s * t * 0.3
		for ly: float in [0.35, h - 0.4]:
			B(g, Vector3(-w * 0.5 + 0.04, ly - 0.09, minf(f, f + s * 0.035)), Vector3(w * 0.5 - 0.04, ly + 0.09, maxf(f, f + s * 0.035)), "board_wood")
			for k: int in n:
				dot(g, Vector3(-w * 0.5 + (float(k) + 0.5) * pw, ly, f + s * 0.04), 0.012, "iron")
		# the brace
		var a: Vector3 = Vector3(-w * 0.5 + 0.12, 0.45, f + s * 0.018)
		var b: Vector3 = Vector3(w * 0.5 - 0.12, h - 0.5, f + s * 0.018)
		OB(g, (a + b) * 0.5, Vector3(0.14, a.distance_to(b), 0.035), "board_wood", Vector3(0, 0, -rad_to_deg(atan2(b.x - a.x, b.y - a.y))))
	# crossed boards nailed over the front
	var ft: float = -t * 0.3 - 0.07
	for d: float in [-1.0, 1.0]:
		var a2: Vector3 = Vector3(-w * 0.52, h * 0.12 if d > 0.0 else h * 0.9, ft - (0.0 if d > 0.0 else 0.04))
		var b2: Vector3 = Vector3(w * 0.52, h * 0.9 if d > 0.0 else h * 0.12, a2.z)
		OB(g, (a2 + b2) * 0.5, Vector3(0.17, a2.distance_to(b2), 0.04), "board_wood", Vector3(0, 0, -rad_to_deg(atan2(b2.x - a2.x, b2.y - a2.y))))
		for e: float in [0.08, 0.92]:
			dot(g, a2.lerp(b2, e) + Vector3(0, 0, -0.025), 0.014, "iron")
	# chain and padlock
	var cz: float = ft - 0.08
	var prevp: Vector3 = Vector3(-w * 0.42, 1.0, cz)
	for k2: int in 16:
		var tt: float = float(k2 + 1) / 16.0
		var p: Vector3 = Vector3(lerpf(-w * 0.42, w * 0.42, tt), 1.0 - sin(tt * PI) * 0.16, cz)
		var mid: Vector3 = (prevp + p) * 0.5
		var yaw: float = rad_to_deg(atan2(p.y - prevp.y, p.x - prevp.x))
		ring(g, mid, 0.034, 0.008, "iron", Vector3(90, 0, yaw) if k2 % 2 == 0 else Vector3(0, 0, yaw))
		prevp = p
	for sx: float in [-w * 0.42, w * 0.42]:
		C(g, Vector3(sx, 1.0, cz + 0.04), 0.02, 0.1, "iron", Vector3(90, 0, 0))
	B(g, Vector3(-0.065, 0.7, cz - 0.03), Vector3(0.065, 0.82, cz + 0.02), "brass")
	ring(g, Vector3(0, 0.84, cz), 0.045, 0.012, "steel", Vector3(90, 0, 0))
	# sign boards (front and back) under the labels
	for s2: float in [-1.0, 1.0]:
		var z0: float = s2 * (t * 0.3 + 0.045) if s2 > 0.0 else ft - 0.045
		B(g, Vector3(-0.55, h * 0.6 - 0.17, minf(z0, z0 + s2 * 0.025)), Vector3(0.55, h * 0.6 + 0.17, maxf(z0, z0 + s2 * 0.025)), "nameplate")
		B(g, Vector3(-0.58, h * 0.6 - 0.2, minf(z0 - s2 * 0.01, z0 + s2 * 0.015)), Vector3(0.58, h * 0.6 + 0.2, maxf(z0 - s2 * 0.01, z0 + s2 * 0.015)), "board_wood")


## Where door_wood's sign faces are (label planes) for a door of this size: [front z, back z].
static func door_label_z(size: Vector3, steel: bool) -> Array:
	if steel:
		return [-size.z * 0.4 - 0.055, size.z * 0.4 + 0.055]
	return [-size.z * 0.3 - 0.07 - 0.045 - 0.03, size.z * 0.3 + 0.045 + 0.03]


## A steel bulkhead door for a powered lock (cached per size). The lock lamp is the script's.
static func door_steel(g: Node3D, size: Vector3) -> void:
	var w: float = size.x
	var h: float = size.y
	var t: float = size.z
	B(g, Vector3(-w * 0.5, 0, -t * 0.4), Vector3(w * 0.5, h, t * 0.4), "machine_grey@local")
	for s: float in [-1.0, 1.0]:
		var f: float = s * t * 0.4
		B(g, Vector3(-w * 0.5, 0, minf(f, f + s * 0.02)), Vector3(w * 0.5, 0.32, maxf(f, f + s * 0.02)), "stripes:#c8a01e")
		for ry: float in [0.5, h - 0.15]:
			B(g, Vector3(-w * 0.5, ry - 0.05, minf(f, f + s * 0.03)), Vector3(w * 0.5, ry + 0.05, maxf(f, f + s * 0.03)), "iron@local")
		for rx: float in [-w * 0.5 + 0.05, w * 0.5 - 0.05]:
			B(g, Vector3(rx - 0.05, 0.32, minf(f, f + s * 0.03)), Vector3(rx + 0.05, h, maxf(f, f + s * 0.03)), "iron@local")
			rivets(g, Vector3(rx, 0.4, f + s * 0.035), Vector3(rx, h - 0.1, f + s * 0.035), 9, 0.016)
		ring(g, Vector3(0, 1.0, f + s * 0.03), 0.2, 0.04, "steel", Vector3(90, 0, 0))
		C(g, Vector3(0, 1.0, f + s * 0.02), 0.17, 0.02, "window_dark", Vector3(90, 0, 0))
		B(g, Vector3(-0.55, h * 0.6 - 0.17, minf(f + s * 0.035, f + s * 0.05)), Vector3(0.55, h * 0.6 + 0.17, maxf(f + s * 0.035, f + s * 0.05)), "nameplate")
	C(g, Vector3(0, h - 0.06, -t * 0.4 - 0.05), 0.07, 0.08, "iron", Vector3(90, 0, 0))


# ================================================================== the Hauptschalter

static func power_switch_body(g: Node3D) -> void:
	B(g, Vector3(-0.64, 0, -0.22), Vector3(0.64, 0.1, 0.24), "black_paint")
	B(g, Vector3(-0.6, 0.1, -0.2), Vector3(0.6, 1.6, 0.2), "machine_grey")
	B(g, Vector3(-0.62, 1.56, -0.22), Vector3(0.62, 1.64, 0.22), "iron")
	# front door with raised rims, hinges, louvres
	B(g, Vector3(-0.54, 0.18, -0.215), Vector3(0.54, 1.5, -0.2), "machine_green")
	for ry: float in [0.2, 1.48]:
		B(g, Vector3(-0.56, ry - 0.02, -0.23), Vector3(0.56, ry + 0.02, -0.2), "iron")
	for rx: float in [-0.56, 0.56]:
		B(g, Vector3(rx - 0.02, 0.18, -0.23), Vector3(rx + 0.02, 1.5, -0.2), "iron")
	for hy: float in [0.4, 1.25]:
		C(g, Vector3(-0.58, hy, -0.23), 0.025, 0.14, "steel")
	for lv: int in 6:
		B(g, Vector3(-0.42, 0.3 + lv * 0.05, -0.226), Vector3(-0.1, 0.32 + lv * 0.05, -0.215), "black_paint")
	# copper bus bars and porcelain fuses behind a window
	B(g, Vector3(0.0, 0.28, -0.226), Vector3(0.46, 0.62, -0.216), "window_dark")
	for fx: int in 3:
		var x: float = 0.08 + fx * 0.15
		S(g, Vector3(x, 0.3, -0.232), Vector3(x, 0.6, -0.232), 0.03, "copper")
		C(g, Vector3(x, 0.45, -0.24), 0.035, 0.12, "enamel_white")
	# two gauges
	for gx: float in [-0.32, 0.32]:
		C(g, Vector3(gx, 1.18, -0.24), 0.14, 0.05, "brass", Vector3(90, 0, 0))
		C(g, Vector3(gx, 1.18, -0.262), 0.12, 0.01, "gauge_face", Vector3(90, 0, 0))
		OB(g, Vector3(gx - 0.03, 1.2, -0.27), Vector3(0.01, 0.1, 0.004), "black_paint", Vector3(0, 0, 50))
	# lamp housings (the lamp glass is the script's)
	for lx: float in [-0.14, 0.14]:
		C(g, Vector3(lx, 0.88, -0.23), 0.07, 0.05, "iron", Vector3(90, 0, 0))
	# the name board on top
	for sx: float in [-0.5, 0.5]:
		S(g, Vector3(sx, 1.64, 0.0), Vector3(sx, 1.78, -0.12), 0.04, "iron", false)
	B(g, Vector3(-0.66, 1.66, -0.22), Vector3(0.66, 1.86, -0.17), "nameplate")
	B(g, Vector3(-0.69, 1.63, -0.2), Vector3(0.69, 1.89, -0.16), "brass")
	# cable conduits up into the dark, insulators on the crown
	for cx: float in [-0.4, -0.1, 0.2]:
		C(g, Vector3(cx, 2.4, 0.12), 0.05, 1.6, "rubber")
		C(g, Vector3(cx, 1.7, 0.12), 0.07, 0.12, "enamel_white")
	# the lever quadrant on the right flank
	var q: Vector3 = Vector3(0.66, 1.0, -0.02)
	B(g, Vector3(0.6, 0.6, -0.12), Vector3(0.66, 1.4, 0.08), "iron")
	var prevq: Vector3 = q + Vector3(0.03, 0.44 * cos(-0.5), 0.44 * sin(-0.5))
	for k: int in 8:
		var a: float = lerpf(-0.5, 1.15, float(k + 1) / 8.0)
		var p: Vector3 = q + Vector3(0.03, 0.44 * cos(a), 0.44 * sin(a))
		S(g, prevq, p, 0.03, "iron", false)
		prevq = p
	C(g, q + Vector3(0.03, 0, 0), 0.08, 0.08, "iron", Vector3(0, 0, 90))


## The throw lever (pivot at origin, pointing up and a little toward the player; turns about X).
static func power_lever(g: Node3D) -> void:
	var arm: Node3D = Node3D.new()
	arm.rotation.x = -0.5
	g.add_child(arm)
	C(arm, Vector3(0.05, 0, 0), 0.05, 0.12, "steel", Vector3(0, 0, 90))
	S(arm, Vector3(0.08, 0, 0), Vector3(0.08, 0.55, 0), 0.05, "steel", false)
	C(arm, Vector3(0.08, 0.66, 0), 0.04, 0.2, "red_paint", Vector3(0, 0, 90))
	C(arm, Vector3(0.08, 0.66, 0), 0.042, 0.02, "steel", Vector3(0, 0, 90))


# ================================================================== Resonance Pylon

static func pylon_body(g: Node3D) -> void:
	Props.hexcol(g, Vector3(0, 0.17, 0), 0.72, 0.34, "concrete")
	tube(g, Vector3(0, 0.37, 0), Vector3(1.1, 0.06, 1.1), "iron")
	# the coil: copper windings with dark spacers
	for i: int in 9:
		var r: float = 0.82 if i % 2 == 0 else 0.86
		tube(g, Vector3(0, 0.44 + i * 0.055, 0), Vector3(r, 0.05, r), "copper" if i % 2 == 0 else "rubber")
	tube(g, Vector3(0, 0.96, 0), Vector3(0.9, 0.05, 0.9), "iron")
	# lattice mast: three legs with cross bracing
	var legs: Array = []
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0 + PI * 0.5
		legs.append([Vector3(cos(a) * 0.42, 0.96, sin(a) * 0.42), Vector3(cos(a) * 0.14, 2.9, sin(a) * 0.14)])
	for k2: int in 3:
		S(g, legs[k2][0], legs[k2][1], 0.06, "iron", false)
		var nb: Array = legs[(k2 + 1) % 3]
		for j: int in 4:
			var t0: float = float(j) / 4.0
			var t1: float = float(j + 1) / 4.0
			S(g, (legs[k2][0] as Vector3).lerp(legs[k2][1], t0), (nb[0] as Vector3).lerp(nb[1], t1), 0.025, "iron", false)
	# porcelain insulator stack up the centre
	S(g, Vector3(0, 0.96, 0), Vector3(0, 2.95, 0), 0.05, "copper")
	for d: int in 11:
		tube(g, Vector3(0, 1.1 + d * 0.165, 0), Vector3(0.2, 0.05, 0.2), "enamel_white")
	# the cradle: brass claws holding the crystal
	tube(g, Vector3(0, 2.95, 0), Vector3(0.36, 0.08, 0.36), "brass")
	for k3: int in 3:
		var a3: float = TAU * float(k3) / 3.0
		var p0: Vector3 = Vector3(cos(a3) * 0.15, 2.97, sin(a3) * 0.15)
		var p1: Vector3 = Vector3(cos(a3) * 0.36, 3.2, sin(a3) * 0.36)
		S(g, p0, p1, 0.04, "brass")
		S(g, p1, Vector3(cos(a3) * 0.26, 3.5, sin(a3) * 0.26), 0.035, "brass")
	# a brass plaque on a short stand (the label sits on it)
	S(g, Vector3(0, 0.34, -0.66), Vector3(0, 0.82, -0.58), 0.05, "iron", false)
	OB(g, Vector3(0, 0.9, -0.5), Vector3(0.92, 0.16, 0.03), "nameplate", Vector3(-20, 0, 0))
	OB(g, Vector3(0, 0.9, -0.49), Vector3(0.96, 0.2, 0.02), "brass", Vector3(-20, 0, 0))


## The Nachtglas crystal in the pylon's cradle (turns; the script tints it per state).
static func pylon_crystal(g: Node3D) -> void:
	Props.hexcol(g, Vector3.ZERO, 0.16, 0.5, "nachtglas_crystal")
	Props._mesh(g, Props.unit_tip(), Vector3(0, 0.36, 0), Vector3(0.32, 0.22, 0.32), "nachtglas_crystal", Vector3.ZERO)
	Props._mesh(g, Props.unit_tip(), Vector3(0, -0.36, 0), Vector3(0.32, 0.22, 0.32), "nachtglas_crystal", Vector3(180, 0, 0))
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + 0.4
		var h: Node3D = Node3D.new()
		h.rotation = Vector3(0.7 * cos(a), a, 0.7 * sin(a))
		g.add_child(h)
		Props.hexcol(h, Vector3(0, 0.18, 0), 0.06, 0.24, "nachtglas_crystal")
		Props._mesh(h, Props.unit_tip(), Vector3(0, 0.34, 0), Vector3(0.12, 0.1, 0.12), "nachtglas_crystal", Vector3.ZERO)


# ================================================================== trap levers and traps

## The wall switch box behind a trap lever: hazard-striped housing, a stencil plate, a lamp housing.
static func lever_box(g: Node3D) -> void:
	B(g, Vector3(-0.27, 0.66, -0.06), Vector3(0.27, 1.54, 0.09), "stripes:#c8a01e")
	B(g, Vector3(-0.22, 0.72, -0.075), Vector3(0.22, 1.48, -0.05), "machine_grey")
	rivets(g, Vector3(-0.2, 1.45, -0.08), Vector3(0.2, 1.45, -0.08), 5, 0.012)
	rivets(g, Vector3(-0.2, 0.75, -0.08), Vector3(0.2, 0.75, -0.08), 5, 0.012)
	B(g, Vector3(-0.19, 1.29, -0.085), Vector3(0.19, 1.41, -0.074), "nameplate")
	C(g, Vector3(0, 1.1, -0.1), 0.06, 0.06, "iron", Vector3(90, 0, 0))
	C(g, Vector3(0.15, 0.9, -0.08), 0.045, 0.04, "iron", Vector3(90, 0, 0))
	S(g, Vector3(0, 1.54, 0.02), Vector3(0, 2.4, 0.02), 0.05, "rubber")


## The lever arm (pivot at origin, hanging down and slightly forward; swings up toward the player about X).
static func lever_arm(g: Node3D) -> void:
	C(g, Vector3(0, 0, -0.02), 0.045, 0.1, "steel", Vector3(0, 0, 90))
	S(g, Vector3(0, 0, -0.03), Vector3(0, -0.34, -0.06), 0.035, "steel", false)
	C(g, Vector3(0, -0.4, -0.065), 0.035, 0.16, "red_paint")
	C(g, Vector3(0, -0.32, -0.06), 0.04, 0.015, "steel")


## Track for the ore cart along local -Z from 0 to -length: sleepers, rails, buffer stops, warning bell posts.
static func cart_track(g: Node3D, length: float, width: float) -> void:
	var gauge: float = width * 0.6
	var n: int = int(length / 0.8) + 1
	for i: int in n:
		var z: float = -float(i) * (length / float(n - 1))
		B(g, Vector3(-gauge * 0.5 - 0.3, 0.0, z - 0.1), Vector3(gauge * 0.5 + 0.3, 0.08, z + 0.1), "beam")
	for sx: float in [-0.5, 0.5]:
		var x: float = sx * gauge
		B(g, Vector3(x - 0.035, 0.08, -length), Vector3(x + 0.035, 0.1, 0), "steel")
		B(g, Vector3(x - 0.012, 0.1, -length), Vector3(x + 0.012, 0.16, 0), "rust")
		B(g, Vector3(x - 0.03, 0.16, -length), Vector3(x + 0.03, 0.19, 0), "steel")
	for e: float in [0.0, 1.0]:
		var z2: float = -length * e + (0.6 if e == 0.0 else -0.6)
		B(g, Vector3(-gauge * 0.5 - 0.2, 0, z2 - 0.15), Vector3(gauge * 0.5 + 0.2, 0.7, z2 + 0.15), "beam")
		for bx: float in [-gauge * 0.4, gauge * 0.4]:
			C(g, Vector3(bx, 0.55, z2 - (0.2 if e == 0.0 else -0.2)), 0.1, 0.12, "red_paint", Vector3(90, 0, 0))
		# a warning bell on a post
		var bp: Vector3 = Vector3(gauge * 0.5 + 0.55, 0, z2)
		S(g, bp, bp + Vector3(0, 2.3, 0), 0.08, "iron", false)
		S(g, bp + Vector3(0, 2.25, 0), bp + Vector3(-0.3, 2.25, 0), 0.05, "iron", false)
		Props.bell(g, bp + Vector3(-0.3, 2.22, 0), 0.26, "brass")
		B(g, bp + Vector3(-0.2, 1.4, -0.06), bp + Vector3(0.2, 1.7, 0.06), "yellow_paint")


## The ore cart itself (riding in the trap's `_cart`, length along Z), with local-space materials.
static func cart_body(g: Node3D, width: float) -> void:
	var hw: float = minf(0.62, width * 0.42)
	B(g, Vector3(-hw, 0.34, -0.85), Vector3(hw, 1.1, 0.85), "rust@local")
	B(g, Vector3(-hw - 0.05, 1.05, -0.9), Vector3(hw + 0.05, 1.14, 0.9), "iron@local")
	for sz: float in [-0.6, 0.0, 0.6]:
		B(g, Vector3(-hw - 0.03, 0.4, sz - 0.04), Vector3(hw + 0.03, 1.08, sz + 0.04), "iron@local")
	for sz2: float in [-0.55, 0.55]:
		for sx: float in [-hw + 0.08, hw - 0.08]:
			C(g, Vector3(sx, 0.2, sz2), 0.2, 0.08, "iron@local", Vector3(0, 0, 90))
			C(g, Vector3(sx, 0.2, sz2), 0.07, 0.12, "steel", Vector3(0, 0, 90))
	B(g, Vector3(-0.32, 0.26, -1.0), Vector3(0.32, 0.42, 1.0), "iron@local")
	for e: float in [-1.0, 1.0]:
		C(g, Vector3(0, 0.42, e * 1.02), 0.09, 0.08, "steel", Vector3(90, 0, 0))
	B(g, Vector3(-hw + 0.04, 0.9, -0.82), Vector3(hw - 0.04, 1.12, 0.82), "ore_salt@local")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4471
	for k: int in 16:
		var p: Vector3 = Vector3(rng.randf_range(-hw * 0.7, hw * 0.7), 1.15 + rng.randf_range(0.0, 0.14), rng.randf_range(-0.7, 0.7))
		p.y += (1.0 - absf(p.z) / 0.8) * 0.12
		OB(g, p, Vector3(rng.randf_range(0.16, 0.3), rng.randf_range(0.1, 0.2), rng.randf_range(0.16, 0.3)), "ore_salt@local",
			Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 90), rng.randf_range(-30, 30)))
	# red-and-white warning chevrons on both ends
	for e2: float in [-1.0, 1.0]:
		for k2: int in 3:
			OB(g, Vector3(-0.2 + k2 * 0.2, 0.72, e2 * 0.86), Vector3(0.12, 0.3, 0.02), "red_paint" if k2 % 2 == 0 else "enamel_white", Vector3(0, 0, 30))


## A fence post for the live wire: steel post with porcelain insulators at each wire height, a danger plate.
static func wire_post(g: Node3D, height: float, wires: Array) -> void:
	B(g, Vector3(-0.08, 0, -0.08), Vector3(0.08, height, 0.08), "machine_grey")
	B(g, Vector3(-0.12, 0, -0.12), Vector3(0.12, 0.12, 0.12), "concrete")
	B(g, Vector3(-0.1, height - 0.04, -0.1), Vector3(0.1, height, 0.1), "iron")
	for y: Variant in wires:
		for k: int in 3:
			tube(g, Vector3(0, float(y) - 0.035 + k * 0.035, 0), Vector3(0.2 - k * 0.04, 0.03, 0.2 - k * 0.04), "enamel_white")
	B(g, Vector3(-0.17, 1.5, -0.1), Vector3(0.17, 1.84, -0.085), "yellow_paint")
	B(g, Vector3(-0.18, 1.49, -0.087), Vector3(0.18, 1.85, -0.082), "black_paint")
	OB(g, Vector3(0.012, 1.72, -0.104), Vector3(0.025, 0.12, 0.004), "black_paint", Vector3(0, 0, 25))
	OB(g, Vector3(-0.012, 1.6, -0.104), Vector3(0.025, 0.12, 0.004), "black_paint", Vector3(0, 0, 25))
	OB(g, Vector3(0.0, 1.66, -0.104), Vector3(0.06, 0.02, 0.004), "black_paint", Vector3(0, 0, 0))


## The junction box and feed for the live wire (beside the left post).
static func wire_feed(g: Node3D, height: float) -> void:
	B(g, Vector3(-0.2, 0.9, 0.09), Vector3(0.2, 1.3, 0.25), "machine_grey")
	B(g, Vector3(-0.21, 1.28, 0.08), Vector3(0.21, 1.32, 0.26), "iron")
	S(g, Vector3(0, 1.3, 0.17), Vector3(0, height + 1.5, 0.17), 0.05, "rubber")
	S(g, Vector3(0, 1.1, 0.09), Vector3(0, 1.1, -0.0), 0.04, "rubber")


# ================================================================== the lift cage

## Static cage art (rides on the AnimatableBody3D; local-space materials): chequer floor, corner angles,
## half-height sheet walls with an expanded-metal lattice above, a crosshead with the hoist shackle and ropes.
static func lift_cage(g: Node3D, sz: Vector3) -> void:
	var hx: float = sz.x * 0.5
	var hz: float = sz.z * 0.5
	var h: float = sz.y
	B(g, Vector3(-hx, -0.2, -hz), Vector3(hx, 0.0, hz), "steel_grate@local")
	B(g, Vector3(-hx - 0.05, -0.25, -hz - 0.05), Vector3(hx + 0.05, -0.12, hz + 0.05), "machine_green@local")
	B(g, Vector3(-hx, h - 0.05, -hz), Vector3(hx, h + 0.05, hz), "machine_green@local")
	for sx: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			var c: Vector3 = Vector3(sx * hx, 0, sz2 * hz)
			B(g, c + Vector3(-0.07, 0, -0.07), c + Vector3(0.07, h, 0.07), "iron@local")
	for side: float in [-1.0, 1.0]:
		var x: float = side * hx
		B(g, Vector3(x - 0.025, 0, -hz), Vector3(x + 0.025, 1.1, hz), "machine_green@local")
		for ry: float in [1.1, h - 0.05]:
			B(g, Vector3(x - 0.04, ry - 0.04, -hz), Vector3(x + 0.04, ry + 0.04, hz), "iron@local")
		rivets(g, Vector3(x - side * 0.03, 1.05, -hz + 0.1), Vector3(x - side * 0.03, 1.05, hz - 0.1), 12, 0.014)
		# expanded-metal lattice
		var n: int = int(sz.z / 0.32)
		for i: int in n + 1:
			var z0: float = -hz + float(i) * (sz.z / float(n))
			var rise: float = h - 1.2
			var za: float = clampf(z0 + rise * 0.5, -hz, hz)
			var zb: float = clampf(z0 - rise * 0.5, -hz, hz)
			S(g, Vector3(x, 1.12, z0), Vector3(x, 1.12 + rise * absf(za - z0) / (rise * 0.5), za), 0.018, "iron@local", false)
			S(g, Vector3(x, 1.12, z0), Vector3(x, 1.12 + rise * absf(zb - z0) / (rise * 0.5), zb), 0.018, "iron@local", false)
			S(g, Vector3(x, h - 0.08, z0), Vector3(x, h - 0.08 - rise * absf(za - z0) / (rise * 0.5), za), 0.018, "iron@local", false)
			S(g, Vector3(x, h - 0.08, z0), Vector3(x, h - 0.08 - rise * absf(zb - z0) / (rise * 0.5), zb), 0.018, "iron@local", false)
	# gate runners on the open sides
	for gz: float in [-1.0, 1.0]:
		B(g, Vector3(-hx, h - 0.16, gz * hz - 0.04), Vector3(hx, h - 0.08, gz * hz + 0.04), "iron@local")
		B(g, Vector3(-hx, 0.0, gz * hz - 0.05), Vector3(hx, 0.03, gz * hz + 0.05), "steel")
	# crosshead, shackle and the hoist ropes
	B(g, Vector3(-hx, h + 0.05, -0.15), Vector3(hx, h + 0.35, 0.15), "machine_green@local")
	B(g, Vector3(-0.2, h + 0.35, -0.2), Vector3(0.2, h + 0.55, 0.2), "iron@local")
	ring(g, Vector3(0, h + 0.68, 0), 0.16, 0.05, "steel", Vector3(90, 0, 0))
	for rx: float in [-0.06, 0.06]:
		S(g, Vector3(rx, h + 0.8, 0), Vector3(rx, h + 4.5, 0), 0.04, "iron@local")
	# lamp cage under the roof (the bulb is separate)
	for a: float in [0.0, 60.0, 120.0]:
		OB(g, Vector3(0, h - 0.18, 0), Vector3(0.3, 0.015, 0.26), "iron@local", Vector3(0, a, 90))
	B(g, Vector3(-0.12, h - 0.06, -0.12), Vector3(0.12, h - 0.03, 0.12), "iron@local")
	# load plate inside (its label is the script's)
	B(g, Vector3(hx - 0.06, 1.45, -1.25), Vector3(hx - 0.03, 1.85, -0.25), "enamel_white")


## A collapsible scissor gate (one per open side; shown while the cage moves).
static func lift_gate(g: Node3D, w: float, h: float) -> void:
	var n: int = int(w / 0.3)
	for i: int in n + 1:
		var x: float = -w * 0.5 + float(i) * (w / float(n))
		S(g, Vector3(x, 0.05, 0), Vector3(x, h, 0), 0.025, "brass", false)
		if i < n:
			var x1: float = x + w / float(n)
			for k: int in 4:
				var y0: float = 0.05 + float(k) * (h - 0.05) / 4.0
				var y1: float = y0 + (h - 0.05) / 4.0
				S(g, Vector3(x, y0, 0.01), Vector3(x1, y1, 0.01), 0.016, "iron", false)
				S(g, Vector3(x, y1, -0.01), Vector3(x1, y0, -0.01), 0.016, "iron", false)
	B(g, Vector3(-w * 0.5, h - 0.03, -0.03), Vector3(w * 0.5, h + 0.03, 0.03), "iron")


## A lift call box: cast housing, brass push buttons, a plate. Front local -Z; the lamp is separate.
static func lift_button(g: Node3D) -> void:
	B(g, Vector3(-0.16, -0.22, -0.05), Vector3(0.16, 0.22, 0.06), "machine_green")
	B(g, Vector3(-0.17, 0.2, -0.06), Vector3(0.17, 0.24, 0.07), "iron")
	B(g, Vector3(-0.12, -0.18, -0.056), Vector3(0.12, -0.1, -0.05), "brass")
	for by: float in [-0.02, 0.1]:
		C(g, Vector3(-0.06, by, -0.06), 0.035, 0.03, "brass", Vector3(90, 0, 0))
		C(g, Vector3(-0.06, by, -0.075), 0.022, 0.02, "bakelite", Vector3(90, 0, 0))
	S(g, Vector3(0, 0.24, 0.02), Vector3(0, 0.8, 0.02), 0.04, "rubber")


# ================================================================== workbench and the Totenglocke

## Tools on the generator-hall bench top (bench surface at y = top, extending toward local +Z).
static func bench_tools(g: Node3D, top: float) -> void:
	# a vise on the left end
	B(g, Vector3(-1.15, top, 0.2), Vector3(-0.85, top + 0.08, 0.45), "machine_green")
	B(g, Vector3(-1.12, top + 0.08, 0.2), Vector3(-0.88, top + 0.22, 0.3), "machine_green")
	B(g, Vector3(-1.12, top + 0.08, 0.36), Vector3(-0.88, top + 0.22, 0.46), "machine_green")
	S(g, Vector3(-1.0, top + 0.15, 0.05), Vector3(-1.0, top + 0.15, 0.48), 0.025, "steel")
	S(g, Vector3(-1.1, top + 0.15, 0.06), Vector3(-0.9, top + 0.15, 0.06), 0.02, "steel")
	# a blueprint of the Totenglocke, with a pencil
	OB(g, Vector3(0.0, top + 0.004, 0.75), Vector3(0.7, 0.004, 0.5), "paint:#2b4a73", Vector3(0, 8, 0))
	for k: int in 4:
		OB(g, Vector3(-0.15 + k * 0.1, top + 0.008, 0.75), Vector3(0.006, 0.002, 0.3), "paint:#c9d6e6", Vector3(0, 8, 0))
	ring(g, Vector3(0.12, top + 0.009, 0.77), 0.09, 0.006, "paint:#c9d6e6")
	OB(g, Vector3(0.25, top + 0.012, 0.57), Vector3(0.16, 0.012, 0.012), "yellow_paint", Vector3(0, -30, 0))
	# hammer, wrench, a coil of wire, a can of grease
	OB(g, Vector3(0.6, top + 0.02, 0.3), Vector3(0.3, 0.025, 0.025), "furniture", Vector3(0, 20, 0))
	OB(g, Vector3(0.74, top + 0.03, 0.35), Vector3(0.05, 0.04, 0.11), "iron", Vector3(0, 20, 0))
	OB(g, Vector3(0.45, top + 0.012, 0.95), Vector3(0.26, 0.012, 0.035), "steel", Vector3(0, -50, 0))
	ring(g, Vector3(0.95, top + 0.03, 0.8), 0.12, 0.03, "copper")
	C(g, Vector3(-0.55, top + 0.07, 1.1), 0.07, 0.14, "red_paint")
	# bench lamp on a gooseneck
	B(g, Vector3(1.0, top, 1.2), Vector3(1.16, top + 0.03, 1.36), "iron")
	S(g, Vector3(1.08, top + 0.03, 1.28), Vector3(1.0, top + 0.5, 1.0), 0.025, "iron")
	Props.cone(g, Vector3(0.95, top + 0.48, 0.92), 0.1, 0.12, "enamel_green")


## The three part outlines chalked on the bench (where the parts go).
static func bench_slots(g: Node3D, top: float) -> void:
	for k: int in 3:
		ring(g, Vector3(-0.55 + k * 0.55, top + 0.003, 0.22), 0.16, 0.012, "paint:#cfcab8")


static func part_bell(g: Node3D) -> void:
	Props.bell(g, Vector3(0, 0.3, 0), 0.3, "brass")
	ring(g, Vector3(0, 0.32, 0), 0.04, 0.012, "iron", Vector3(90, 0, 0))


static func part_frame(g: Node3D) -> void:
	B(g, Vector3(-0.3, 0, -0.08), Vector3(0.3, 0.05, 0.08), "iron")
	for sx: float in [-0.24, 0.24]:
		S(g, Vector3(sx, 0.05, 0), Vector3(sx * 0.6, 0.34, 0), 0.04, "iron", false)
	S(g, Vector3(-0.16, 0.34, 0), Vector3(0.16, 0.34, 0), 0.04, "iron", false)
	S(g, Vector3(-0.2, 0.1, 0.06), Vector3(0.2, 0.1, 0.06), 0.03, "walnut", false)
	rivets(g, Vector3(-0.25, 0.055, -0.06), Vector3(0.25, 0.055, -0.06), 5, 0.012, "brass")


static func part_crank(g: Node3D) -> void:
	C(g, Vector3(0, 0.05, 0), 0.08, 0.1, "brass")
	S(g, Vector3(0, 0.1, 0), Vector3(0, 0.3, 0), 0.035, "steel")
	S(g, Vector3(0, 0.3, 0), Vector3(0.2, 0.3, 0), 0.03, "steel")
	C(g, Vector3(0.2, 0.36, 0), 0.025, 0.12, "walnut")
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		OB(g, Vector3(cos(a) * 0.085, 0.05, sin(a) * 0.085), Vector3(0.03, 0.08, 0.02), "brass", Vector3(0, -rad_to_deg(a), 0))


## The assembled Totenglocke on the bench: the bell in its firing frame with the crank.
static func totenglocke(g: Node3D) -> void:
	B(g, Vector3(-0.42, 0, -0.14), Vector3(0.42, 0.06, 0.14), "iron")
	for sx: float in [-0.36, 0.36]:
		S(g, Vector3(sx, 0.06, 0), Vector3(sx * 0.7, 0.55, 0), 0.05, "iron", false)
	S(g, Vector3(-0.3, 0.55, 0), Vector3(0.3, 0.55, 0), 0.05, "iron", false)
	Props.bell(g, Vector3(0, 0.52, 0), 0.34, "brass")
	C(g, Vector3(0.4, 0.42, 0), 0.06, 0.08, "brass", Vector3(0, 0, 90))
	S(g, Vector3(0.44, 0.42, 0), Vector3(0.44, 0.24, 0.0), 0.03, "steel")
	C(g, Vector3(0.5, 0.24, 0), 0.022, 0.12, "walnut", Vector3(0, 0, 90))
	for k: int in 5:
		dot(g, Vector3(-0.15 + k * 0.075, 0.3, -0.17), 0.02, "nachtglas_crystal")


# ================================================================== quest props

## A field radio set (the Map 0 Wehrmacht set and Fasbender's radios): steel case, open lid, dials, headset, whip.
static func field_radio(g: Node3D) -> void:
	B(g, Vector3(-0.23, 0, -0.15), Vector3(0.23, 0.32, 0.15), "machine_grey")
	B(g, Vector3(-0.24, 0.0, -0.16), Vector3(0.24, 0.03, 0.16), "iron")
	OB(g, Vector3(0, 0.46, 0.2), Vector3(0.46, 0.3, 0.03), "machine_grey", Vector3(-15, 0, 0))
	B(g, Vector3(-0.21, 0.03, -0.158), Vector3(0.21, 0.3, -0.15), "black_paint")
	for d: Array in [[Vector3(0.12, 0.2, -0.16), 0.045], [Vector3(0.12, 0.08, -0.16), 0.035], [Vector3(-0.02, 0.07, -0.16), 0.03]]:
		C(g, d[0], float(d[1]), 0.03, "bakelite", Vector3(90, 0, 0))
		OB(g, (d[0] as Vector3) + Vector3(0, 0, -0.018), Vector3(0.008, float(d[1]) * 1.4, 0.006), "enamel_white")
	for k: int in 2:
		C(g, Vector3(-0.16 + k * 0.06, 0.25, -0.162), 0.012, 0.015, "steel", Vector3(90, 0, 0))
	for sx: float in [-0.25, 0.25]:
		B(g, Vector3(sx - 0.02, 0.12, -0.08), Vector3(sx + 0.02, 0.22, 0.08), "black_paint")
	ring(g, Vector3(-0.08, 0.34, 0.0), 0.09, 0.012, "black_paint", Vector3(90, 30, 0))
	for e: float in [-1.0, 1.0]:
		C(g, Vector3(-0.08 + e * 0.07, 0.34, e * 0.04), 0.035, 0.03, "bakelite")
	C(g, Vector3(0.18, 0.34, 0.1), 0.02, 0.04, "brass")
	S(g, Vector3(0.18, 0.36, 0.1), Vector3(0.18, 1.1, 0.14), 0.012, "steel")


## A phonograph on a small cabinet (front local -Z): cylinder mandrel, crank, a flaring brass horn.
static func phonograph(g: Node3D) -> void:
	B(g, Vector3(-0.28, 0.0, -0.22), Vector3(0.28, 0.6, 0.22), "walnut")
	B(g, Vector3(-0.3, 0.6, -0.24), Vector3(0.3, 0.64, 0.24), "furniture")
	B(g, Vector3(-0.26, 0.64, -0.2), Vector3(0.26, 0.86, 0.2), "walnut")
	B(g, Vector3(-0.27, 0.86, -0.21), Vector3(0.27, 0.88, 0.21), "brass")
	C(g, Vector3(0.0, 0.92, 0.0), 0.05, 0.3, "wax", Vector3(0, 0, 90))
	C(g, Vector3(0.0, 0.92, 0.0), 0.02, 0.38, "steel", Vector3(0, 0, 90))
	for sx: float in [-0.19, 0.19]:
		B(g, Vector3(sx - 0.015, 0.88, -0.02), Vector3(sx + 0.015, 0.96, 0.02), "brass")
	S(g, Vector3(0.27, 0.75, 0), Vector3(0.35, 0.75, 0), 0.02, "steel")
	S(g, Vector3(0.35, 0.75, 0), Vector3(0.35, 0.65, -0.06), 0.02, "steel")
	C(g, Vector3(0.38, 0.65, -0.06), 0.015, 0.06, "walnut", Vector3(0, 0, 90))
	var base: Vector3 = Vector3(0.0, 0.98, 0.05)
	var dir: Vector3 = Vector3(0.0, 0.6, -0.8).normalized()
	S(g, Vector3(0, 0.92, 0.02), base, 0.03, "brass")
	var horn: Node3D = Node3D.new()
	horn.position = base
	horn.basis = Basis(Vector3.RIGHT, -acos(dir.y))
	g.add_child(horn)
	frustum(horn, 0, 0, 0.0, 0.2, 0.025, 0.05, "brass")
	frustum(horn, 0, 0, 0.2, 0.36, 0.05, 0.12, "brass")
	frustum(horn, 0, 0, 0.36, 0.46, 0.12, 0.24, "brass_2s", true)
	ring(horn, Vector3(0, 0.46, 0), 0.245, 0.014, "brass")
	C(horn, Vector3(0, 0.37, 0), 0.115, 0.01, "window_dark")
	for k: int in 6:
		var a: float = TAU * float(k) / 6.0
		S(horn, Vector3(cos(a) * 0.05, 0.2, sin(a) * 0.05), Vector3(cos(a) * 0.235, 0.455, sin(a) * 0.235), 0.008, "brass")


## The Administration switchboard's front: jack field, cords and plugs, lamps, a shelf.
static func switchboard(g: Node3D) -> void:
	B(g, Vector3(-2.45, 0.85, -0.04), Vector3(2.45, 2.15, -0.01), "walnut")
	B(g, Vector3(-2.2, 1.0, -0.05), Vector3(2.2, 1.85, -0.035), "black_paint")
	for r: int in 5:
		for c: int in 24:
			var p: Vector3 = Vector3(-2.05 + c * 0.178, 1.1 + r * 0.17, -0.055)
			C(g, p, 0.018, 0.015, "brass", Vector3(90, 0, 0))
			if r == 4:
				C(g, p + Vector3(0, 0.07, 0), 0.012, 0.01, "bulb_off", Vector3(90, 0, 0))
	B(g, Vector3(-2.45, 0.78, -0.4), Vector3(2.45, 0.85, -0.01), "walnut")
	for k: int in 14:
		var x: float = -1.9 + k * 0.29
		C(g, Vector3(x, 0.88, -0.3), 0.02, 0.08, "bakelite")
		if k % 3 == 0:
			var top: Vector3 = Vector3(x + 0.2, 1.1 + float(k % 5) * 0.17, -0.07)
			Props.cable(g, Vector3(x, 0.92, -0.3), top, 0.25, 0.008, 6, "rubber")
			C(g, top + Vector3(0, 0, -0.02), 0.014, 0.05, "bakelite", Vector3(90, 0, 0))
	ring(g, Vector3(1.6, 0.9, -0.22), 0.09, 0.012, "black_paint", Vector3(90, 0, 0))
	OB(g, Vector3(-1.5, 0.87, -0.2), Vector3(0.3, 0.03, 0.22), "cloth_red", Vector3(0, 10, 0))
	B(g, Vector3(-2.3, 1.95, -0.06), Vector3(2.3, 2.05, -0.04), "nameplate")


## Phonograph cylinder by its cardboard tube.
static func cylinder_pickup(g: Node3D) -> void:
	C(g, Vector3(-0.05, 0.06, 0), 0.055, 0.12, "paint:#7a6044", Vector3(0, 0, 90))
	C(g, Vector3(0.08, 0.05, 0.02), 0.05, 0.1, "wax", Vector3(0, 30, 90))
	C(g, Vector3(0.08, 0.05, 0.02), 0.035, 0.102, "window_dark", Vector3(0, 30, 90))
	C(g, Vector3(-0.15, 0.03, -0.04), 0.058, 0.02, "paint:#7a6044")


## A dog tag on its bead chain.
static func tag_pickup(g: Node3D) -> void:
	OB(g, Vector3(0, 0.005, 0), Vector3(0.05, 0.004, 0.032), "steel", Vector3(0, 15, 0))
	ring(g, Vector3(0.0, 0.004, -0.04), 0.03, 0.003, "steel")
	for k: int in 10:
		var a: float = float(k) / 9.0 * PI * 1.6
		dot(g, Vector3(cos(a) * 0.07 - 0.04, 0.004, sin(a) * 0.05 - 0.06), 0.005, "steel")


## The Nachtglas shard.
static func shard_pickup(g: Node3D) -> void:
	Props.crystal_cluster(g, Vector3.ZERO, 7, 0.3, "nachtglas_crystal")


static func intel_doc(g: Node3D) -> void:
	OB(g, Vector3(0, 0.008, 0), Vector3(0.3, 0.012, 0.22), "paint:#8a7a52", Vector3(0, 6, 0))
	OB(g, Vector3(0.01, 0.016, 0.0), Vector3(0.26, 0.004, 0.2), "paper", Vector3(0, -4, 0))
	OB(g, Vector3(0.0, 0.019, -0.04), Vector3(0.12, 0.002, 0.03), "red_paint", Vector3(0, -4, 0))
	OB(g, Vector3(-0.08, 0.02, 0.05), Vector3(0.04, 0.003, 0.05), "paint:#4a3b28", Vector3(0, -4, 0))


static func intel_photo(g: Node3D) -> void:
	OB(g, Vector3(0, 0.004, 0), Vector3(0.18, 0.006, 0.13), "enamel_white", Vector3(0, -12, 0))
	OB(g, Vector3(0, 0.008, 0), Vector3(0.15, 0.002, 0.1), "picture", Vector3(0, -12, 0))


static func intel_audio(g: Node3D) -> void:
	C(g, Vector3(0, 0.02, 0), 0.12, 0.03, "paint:#5c4a32")
	C(g, Vector3(0, 0.036, 0), 0.1, 0.004, "wax")
	C(g, Vector3(0, 0.04, 0), 0.03, 0.006, "cream")


## A sheet of notepaper, a corner curling, held by a drawing pin.
static func note_paper(g: Node3D) -> void:
	OB(g, Vector3(-0.01, 0.002, 0), Vector3(0.2, 0.004, 0.16), "paper")
	OB(g, Vector3(0.1, 0.006, 0), Vector3(0.03, 0.003, 0.16), "paper", Vector3(0, 0, 18))
	C(g, Vector3(-0.08, 0.008, -0.055), 0.012, 0.008, "red_paint")


## Herr Tamtam, the tin drummer: a toy hussar with a drum.
static func tin_drummer(g: Node3D) -> void:
	C(g, Vector3(0, 0.02, 0), 0.09, 0.03, "paint:#2a5a3a")
	for sx: float in [-0.035, 0.035]:
		C(g, Vector3(sx, 0.1, 0), 0.025, 0.14, "paint:#e8e0cc")
		B(g, Vector3(sx - 0.03, 0.03, -0.04), Vector3(sx + 0.03, 0.06, 0.03), "black_paint")
	B(g, Vector3(-0.07, 0.17, -0.05), Vector3(0.07, 0.3, 0.05), "paint:#9b1c18")
	for k: int in 4:
		S(g, Vector3(-0.06, 0.2 + k * 0.025, -0.052), Vector3(0.06, 0.2 + k * 0.025, -0.052), 0.008, "yellow_paint")
	dot(g, Vector3(0, 0.34, 0), 0.05, "paint:#e8c8a8")
	C(g, Vector3(0, 0.42, 0), 0.05, 0.1, "black_paint")
	dot(g, Vector3(0, 0.48, -0.02), 0.02, "red_paint")
	tube(g, Vector3(0, 0.16, -0.12), Vector3(0.18, 0.1, 0.18), "paint:#e0c060")
	tube(g, Vector3(0, 0.16, -0.12), Vector3(0.185, 0.02, 0.185), "red_paint")
	S(g, Vector3(-0.06, 0.25, -0.06), Vector3(-0.03, 0.22, -0.12), 0.012, "paint:#c09060")
	S(g, Vector3(0.06, 0.25, -0.06), Vector3(0.03, 0.23, -0.12), 0.012, "paint:#c09060")


## A cast bell body for a quest bell centred at the origin (height h; mouth down). All one material.
static func quest_bell_body(g: Node3D, h: float) -> void:
	ell(g, Vector3(0, 0.37 * h, 0), Vector3(h * 0.5, h * 0.22, h * 0.5), "brass")
	frustum(g, 0, 0, 0.1 * h, 0.38 * h, 0.27 * h, 0.25 * h, "brass")
	frustum(g, 0, 0, -0.2 * h, 0.1 * h, 0.33 * h, 0.27 * h, "brass")
	frustum(g, 0, 0, -0.4 * h, -0.2 * h, 0.45 * h, 0.33 * h, "brass")
	frustum(g, 0, 0, -0.48 * h, -0.4 * h, 0.48 * h, 0.45 * h, "brass")
	tube(g, Vector3(0, 0.28 * h, 0), Vector3(h * 0.53, h * 0.025, h * 0.53), "brass")
	tube(g, Vector3(0, -0.26 * h, 0), Vector3(h * 0.8, h * 0.025, h * 0.8), "brass")
	tube(g, Vector3(0, -0.47 * h, 0), Vector3(h * 0.9, h * 0.004, h * 0.9), "brass")


## The bell's crown loop and clapper (iron).
static func quest_bell_fittings(g: Node3D, h: float) -> void:
	ring(g, Vector3(0, 0.5 * h, 0), h * 0.1, h * 0.03, "iron", Vector3(90, 0, 0))
	S(g, Vector3(0, 0.3 * h, 0), Vector3(0, -0.36 * h, 0), h * 0.04, "iron")
	dot(g, Vector3(0, -0.4 * h, 0), h * 0.07, "iron")
	C(g, Vector3(0, -0.46 * h, 0), 0.43 * h, 0.01 * h, "window_dark")


# ---- THE UNDERTOW's parts and the built gun on the bench (T-153)
static func part_ut_pump(g: Node3D) -> void:
	C(g, Vector3(0, 0.12, 0), 0.06, 0.24, "brass")
	C(g, Vector3(0, 0.27, 0), 0.012, 0.1, "steel")
	B(g, Vector3(-0.07, 0.31, -0.015), Vector3(0.07, 0.34, 0.015), "black_paint")
	ring(g, Vector3(0.0, 0.05, 0.0), 0.075, 0.012, "black_paint", Vector3(0, 0, 0))
	B(g, Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 0.015, 0.1), "steel")


static func part_ut_head(g: Node3D) -> void:
	C(g, Vector3(0, 0.03, -0.05), 0.008, 0.3, "steel", Vector3(90, 0, 0))
	ell(g, Vector3(0, 0.03, -0.22), Vector3(0.05, 0.05, 0.11), "glass:#7a3fd0")
	dot(g, Vector3(0, 0.03, -0.25), 0.015, "neon:#b070ff")
	B(g, Vector3(-0.06, 0.0, -0.06), Vector3(0.06, 0.012, 0.12), "steel")


static func part_ut_shard(g: Node3D) -> void:
	B(g, Vector3(-0.09, 0.0, -0.05), Vector3(0.09, 0.025, 0.05), "steel")
	ell(g, Vector3(0, 0.07, 0), Vector3(0.05, 0.13, 0.03), "glass:#6a2fb8", Vector3(0, 0, 18))
	dot(g, Vector3(0.0, 0.1, 0.01), 0.014, "neon:#c07dff")


static func undertow(g: Node3D) -> void:
	C(g, Vector3(0, 0.07, -0.05), 0.045, 0.36, "brass", Vector3(90, 0, 0))
	C(g, Vector3(0, 0.07, -0.35), 0.018, 0.24, "steel", Vector3(90, 0, 0))
	B(g, Vector3(-0.018, 0.04, 0.12), Vector3(0.018, 0.09, 0.36), "planks")
	ell(g, Vector3(0, 0.07, -0.5), Vector3(0.03, 0.03, 0.07), "glass:#7a3fd0")
