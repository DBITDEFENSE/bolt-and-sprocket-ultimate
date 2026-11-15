extends RefCounted
## Procedural art for the Lost Requisition Crate (the mystery box): an original design, built from Props /
## InteractableArt primitives and Mats keys, merged into cached meshes (one draw per material).
## (No class_name: MysteryCrate preloads it, so a fresh checkout works before the editor rebuilds its class cache.)
##
## A heavy ordnance crate on skids: horizontal planks over a dark core, iron corner brackets with rivets, two iron
## straps, rope handles, a hasp under a wax seal, stencilled requisition markings and a brass works plate from
## Helvetia Automaten AG, and a chalk sigil somebody scratched on the front. The lid is planked and strapped with
## a brass plate on top. Every spot also gets a lantern on a hooked iron stake and a chalk footprint on the floor,
## so an empty spot still reads as "the crate was here" and the lit lantern says "it's here now".
##
## Frame: origin = floor centre, local -Z faces the player, body 1.4 x 0.6 x 0.7 (the interact and collision
## footprints in MysteryCrate are unchanged).

const HW: float = 0.7      # half width (X)
const HD: float = 0.35     # half depth (Z)
const TOP: float = 0.6     # body top (lid hinge height)
const AWAY_Y: float = 0.024   # T-254: where the empty spot's marks lie (over the drawn floor)


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


## Deterministic jitter so the planks never line up perfectly.
static func _j(i: int, k: int, amp: float) -> float:
	return (fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0) - 0.5) * 2.0 * amp


# ================================================================== the body

static func body(g: Node3D) -> void:
	# skids: two timber runners the crate was dragged in on
	for sz: float in [-0.26, 0.26]:
		B(g, Vector3(-HW - 0.03, 0.0, sz - 0.05), Vector3(HW + 0.03, 0.065, sz + 0.05), "beam")
	# floor, and a dark inner shell the plank gaps show (hollow: the straw and the glow inside are seen when open)
	B(g, Vector3(-HW + 0.01, 0.06, -HD + 0.01), Vector3(HW - 0.01, 0.11, HD - 0.01), "beam")
	for sz0: float in [-1.0, 1.0]:
		B(g, Vector3(-HW + 0.02, 0.1, sz0 * (HD - 0.02)), Vector3(HW - 0.02, TOP, sz0 * (HD - 0.06)), "char")
	for sx0: float in [-1.0, 1.0]:
		B(g, Vector3(sx0 * (HW - 0.02), 0.1, -HD + 0.02), Vector3(sx0 * (HW - 0.06), TOP, HD - 0.02), "char")
	# four rows of horizontal planks on every face, each a little proud or shy of its neighbours
	for i: int in 4:
		var y0: float = 0.1 + float(i) * 0.125
		var y1: float = y0 + 0.117
		for sz2: float in [-1.0, 1.0]:
			var d: float = 0.04 + _j(i, int(sz2) + 2, 0.005)
			var e0: float = -HW + 0.02 + _j(i, 5, 0.006)
			var e1: float = HW - 0.02 + _j(i, 6, 0.006)
			B(g, Vector3(e0, y0, sz2 * (HD - d)), Vector3(e1, y1, sz2 * HD), "planks")
		for sx: float in [-1.0, 1.0]:
			var d2: float = 0.04 + _j(i, int(sx) + 7, 0.005)
			B(g, Vector3(sx * (HW - d2), y0, -HD + 0.02), Vector3(sx * HW, y1, HD - 0.02), "planks")
	# iron corner brackets with rivets
	for sx2: float in [-1.0, 1.0]:
		for sz3: float in [-1.0, 1.0]:
			B(g, Vector3(sx2 * (HW + 0.012), 0.07, sz3 * HD - sz3 * 0.09), Vector3(sx2 * (HW - 0.0), TOP + 0.005, sz3 * (HD + 0.012)), "iron")
			B(g, Vector3(sx2 * HW - sx2 * 0.09, 0.07, sz3 * (HD + 0.012)), Vector3(sx2 * (HW + 0.012), TOP + 0.005, sz3 * HD), "iron")
			for ry: float in [0.14, 0.33, 0.52]:
				dot(g, Vector3(sx2 * (HW + 0.014), ry, sz3 * (HD - 0.05)), 0.012, "steel")
				dot(g, Vector3(sx2 * (HW - 0.05), ry, sz3 * (HD + 0.014)), 0.012, "steel")
	# bottom strap round the whole body, and two vertical straps over the front and back
	B(g, Vector3(-HW - 0.012, 0.075, -HD - 0.012), Vector3(HW + 0.012, 0.125, HD + 0.012), "iron")
	for sx3: float in [-0.4, 0.4]:
		for sz4: float in [-1.0, 1.0]:
			B(g, Vector3(sx3 - 0.03, 0.06, sz4 * HD), Vector3(sx3 + 0.03, TOP + 0.005, sz4 * (HD + 0.012)), "iron")
			for ry2: float in [0.2, 0.44]:
				dot(g, Vector3(sx3, ry2, sz4 * (HD + 0.014)), 0.011, "steel")
	# rope handles through iron eyes on both ends
	for sx4: float in [-1.0, 1.0]:
		var ex: float = sx4 * (HW + 0.012)
		for ez: float in [-0.18, 0.18]:
			dot(g, Vector3(ex, 0.4, ez), 0.022, "iron")
		var pts: Array = [Vector3(ex, 0.4, -0.18), Vector3(ex + sx4 * 0.07, 0.345, -0.1), Vector3(ex + sx4 * 0.095, 0.325, 0.0),
			Vector3(ex + sx4 * 0.07, 0.345, 0.1), Vector3(ex, 0.4, 0.18)]
		for k: int in pts.size() - 1:
			S(g, pts[k], pts[k + 1], 0.034, "sandbag")
			dot(g, pts[k + 1], 0.017, "sandbag")
	# the hasp's staple on the front, with the wax seal over the join (it stays on the body: the seal breaks)
	B(g, Vector3(-0.045, 0.44, -HD - 0.018), Vector3(0.045, 0.5, -HD - 0.004), "iron")
	dot(g, Vector3(0, 0.47, -HD - 0.02), 0.014, "steel")
	OB(g, Vector3(0, 0.545, -HD - 0.028), Vector3(0.09, 0.09, 0.018), "red_paint", Vector3(90, 0, 0))
	C(g, Vector3(0, 0.545, -HD - 0.028), 0.045, 0.02, "red_paint", Vector3(90, 0, 0))
	C(g, Vector3(0, 0.545, -HD - 0.039), 0.028, 0.004, "lamp_red_off", Vector3(90, 0, 0))
	OB(g, Vector3(0.02, 0.5, -HD - 0.03), Vector3(0.03, 0.1, 0.004), "cloth_red", Vector3(0, 0, 18))
	OB(g, Vector3(-0.02, 0.5, -HD - 0.03), Vector3(0.03, 0.1, 0.004), "cloth_red", Vector3(0, 0, -18))
	# brass works plate, left of centre on the front, four screws
	B(g, Vector3(-0.62, 0.35, -HD - 0.052), Vector3(-0.2, 0.44, -HD - 0.044), "brass")
	for px: float in [-0.605, -0.215]:
		for py: float in [0.362, 0.428]:
			dot(g, Vector3(px, py, -HD - 0.053), 0.006, "steel")
	# stencil bars either side of the requisition number (painted through a card, so the ends are rough)
	for sx5: float in [-1.0, 1.0]:
		for k2: int in 3:
			OB(g, Vector3(sx5 * (0.48 + k2 * 0.05), 0.16, -HD - 0.045), Vector3(0.03, 0.1 - k2 * 0.02, 0.003), "black_paint", Vector3(0, 0, sx5 * 20.0))
	# a chalk sigil scratched on the front, right of the hasp: a ring, a crossbar, three ticks
	var chalk: Material = chalk_mat()
	var sc: Vector3 = Vector3(0.56, 0.33, -HD - 0.046)
	InteractableArt.ring(g, sc, 0.085, 0.008, "cream", Vector3(90, 0, 0)).material_override = chalk
	OB(g, sc, Vector3(0.21, 0.008, 0.004), "cream", Vector3(0, 0, -12)).material_override = chalk
	for k3: int in 3:
		OB(g, sc + Vector3(-0.05 + k3 * 0.05, 0.0, 0.0), Vector3(0.007, 0.07, 0.004), "cream", Vector3(0, 0, 8 - k3 * 8)).material_override = chalk
	dot(g, sc + Vector3(0.0, -0.11, 0.0), 0.007, "cream").material_override = chalk


# ================================================================== the lid (origin = the hinge pins: the lid's top rear edge)

## The lid is built below its origin (y in [-0.1, 0]) so that, swung up to vertical about the hinge pins, all of it
## stands in front of the hinge line: crates stand against walls.
static func lid(root: Node3D) -> void:
	var g: Node3D = Node3D.new()
	g.position = Vector3(0, -0.1, 0)
	root.add_child(g)
	var z0: float = -2.0 * HD
	# frame boards underneath, five planks along X on top
	B(g, Vector3(-HW - 0.02, 0.0, z0 - 0.02), Vector3(HW + 0.02, 0.035, 0.01), "beam")
	for i: int in 5:
		var pz: float = z0 + float(i) * 0.14
		B(g, Vector3(-HW - 0.02, 0.03, pz + 0.004), Vector3(HW + 0.02, 0.085 + _j(i, 11, 0.006), pz + 0.136), "planks")
	# iron straps across the lid, over the front edge, with rivets
	for sx: float in [-0.4, 0.4]:
		B(g, Vector3(sx - 0.03, 0.08, z0 - 0.034), Vector3(sx + 0.03, 0.1, 0.01), "iron")
		B(g, Vector3(sx - 0.03, -0.02, z0 - 0.034), Vector3(sx + 0.03, 0.1, z0 - 0.02), "iron")
		for rz: float in [-0.6, -0.35, -0.1]:
			dot(g, Vector3(sx, 0.102, rz), 0.011, "steel")
	# strap hinges along the rear edge, their pins on the top rear corner (the pivot)
	for hx: float in [-0.45, 0.45]:
		C(g, Vector3(hx, 0.1, 0.0), 0.024, 0.16, "iron", Vector3(0, 0, 90))
		B(g, Vector3(hx - 0.04, 0.085, -0.2), Vector3(hx + 0.04, 0.1, 0.0), "iron")
		dot(g, Vector3(hx, 0.102, -0.17), 0.011, "steel")
	# the hasp hanging from the front edge (it drops over the staple on the body)
	B(g, Vector3(-0.04, -0.12, z0 - 0.05), Vector3(0.04, 0.09, z0 - 0.036), "iron")
	B(g, Vector3(-0.04, 0.085, z0 - 0.05), Vector3(0.04, 0.1, z0 + 0.12), "iron")
	# a brass plate on top (the works' plate, stamped with an invented lot number)
	B(g, Vector3(-0.23, 0.095, -0.5), Vector3(0.23, 0.106, -0.26), "brass")
	for px: float in [-0.215, 0.215]:
		for pz2: float in [-0.485, -0.275]:
			dot(g, Vector3(px, 0.107, pz2), 0.006, "steel")
	# the underside the player sees when it stands open: a dark lining with violet veins grown into the grain
	B(g, Vector3(-HW + 0.06, -0.006, z0 + 0.06), Vector3(HW - 0.06, 0.0, -0.06), "char")
	# cracks, not tubes: short jittered segments that branch from a root near the hasp
	for root_v: Array in [[Vector2(-0.08, -0.6), Vector2(-0.55, -0.2), 7], [Vector2(0.05, -0.62), Vector2(0.5, -0.25), 7],
			[Vector2(-0.3, -0.42), Vector2(-0.48, -0.55), 3], [Vector2(0.28, -0.44), Vector2(0.6, -0.5), 4]]:
		var a: Vector2 = root_v[0]
		var b: Vector2 = root_v[1]
		var n: int = int(root_v[2])
		var prev: Vector2 = a
		for k: int in n:
			var t: float = float(k + 1) / float(n)
			var p: Vector2 = a.lerp(b, t) + Vector2(_j(k, n, 0.03), _j(k + 3, n, 0.03)) * (1.0 if k < n - 1 else 0.0)
			S(g, Vector3(prev.x, -0.0085, prev.y), Vector3(p.x, -0.0085, p.y), lerpf(0.012, 0.004, t), "nachtglas_vein")
			prev = p


# ================================================================== the spot (always there: lantern stake, chalk footprint)

static func spot(g: Node3D) -> void:
	var chalk: Material = chalk_mat()
	# chalk footprint on the floor, a hand's width outside the crate
	var w: float = HW + 0.06
	var d: float = HD + 0.06
	for e: Array in [[Vector3(-w, 0.004, -d), Vector3(w, 0.004, -d + 0.02)], [Vector3(-w, 0.004, d - 0.02), Vector3(w, 0.004, d)],
			[Vector3(-w, 0.004, -d), Vector3(-w + 0.02, 0.004, d)], [Vector3(w - 0.02, 0.004, -d), Vector3(w, 0.004, d)]]:
		B(g, e[0] - Vector3(0, 0.002, 0), e[1] + Vector3(0, 0.002, 0), "cream").material_override = chalk
	# a small chalk cross at the front centre, where the operator's inventory slip says it should stand
	OB(g, Vector3(0, 0.004, -d - 0.08), Vector3(0.09, 0.004, 0.012), "cream", Vector3(0, 45, 0)).material_override = chalk
	OB(g, Vector3(0, 0.004, -d - 0.08), Vector3(0.09, 0.004, 0.012), "cream", Vector3(0, -45, 0)).material_override = chalk
	# the hooked iron stake and the lantern's cage (the glass and its light are MysteryCrate's: they switch)
	var sx: float = -(HW + 0.14)
	var sz: float = -0.1
	S(g, Vector3(sx, 0.0, sz), Vector3(sx, 1.38, sz), 0.036, "iron")
	Props.cone(g, Vector3(sx, 0.04, sz), 0.07, 0.08, "iron")
	S(g, Vector3(sx, 1.38, sz), Vector3(sx + 0.07, 1.42, sz), 0.03, "iron")
	S(g, Vector3(sx + 0.07, 1.42, sz), Vector3(sx + 0.13, 1.37, sz), 0.03, "iron")
	S(g, Vector3(sx + 0.13, 1.37, sz), Vector3(sx + 0.14, 1.3, sz), 0.03, "iron")
	var lc: Vector3 = lantern_pos()
	InteractableArt.ring(g, lc + Vector3(0, 0.19, 0), 0.035, 0.008, "iron", Vector3(90, 0, 0))
	C(g, lc + Vector3(0, 0.14, 0), 0.05, 0.03, "iron")
	Props.cone(g, lc + Vector3(0, 0.12, 0), 0.07, 0.05, "iron")
	C(g, lc - Vector3(0, 0.11, 0), 0.055, 0.04, "iron")
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0
		S(g, lc + Vector3(cos(a) * 0.052, -0.09, sin(a) * 0.052), lc + Vector3(cos(a) * 0.052, 0.1, sin(a) * 0.052), 0.008, "iron")


# ================================================================== T-254: the spot while the crate is elsewhere

## What the crate left behind (shown only at a spot the crate is not at): the scrapes of its two skids, wisps of its
## packing straw, and hairline cracks in the floor where it stood, with Nachtglas still in them (dormant: MysteryCrate
## gives them a dim breathing material). All flat (under 1.5 cm): nothing to walk into, nothing baked.
static func away(g: Node3D) -> void:
	# (everything sits AWAY_Y up: the maps' drawn floors stand a centimetre or two proud of the spot's origin, and
	# the model's own chalk, at 4 mm, is under them)
	for sz: float in [-0.26, 0.26]:
		# each skid dragged a little as the crate went down: a long scrape and a shorter one beside it
		OB(g, Vector3(0.04, AWAY_Y, sz), Vector3(2.0 * HW + 0.1, 0.004, 0.09), "char", Vector3(0, 1.5 * signf(sz), 0))
		OB(g, Vector3(-0.2, AWAY_Y, sz + 0.075 * signf(sz)), Vector3(0.7, 0.004, 0.022), "char", Vector3(0, -3.0, 0))
	# straw that fell out when the lid last stood open
	for i: int in 16:
		var c: Vector3 = Vector3(_j(i, 21, 0.8), AWAY_Y + 0.004, _j(i, 22, 0.42))
		OB(g, c, Vector3(0.14 + absf(_j(i, 23, 0.09)), 0.006, 0.009), "hay", Vector3(0, _j(i, 24, 90.0), 0))
	# a splinter of plank, a bent nail, the broken half of the wax seal
	OB(g, Vector3(0.52, AWAY_Y + 0.004, -0.3), Vector3(0.18, 0.012, 0.035), "planks", Vector3(0, 28, 0))
	OB(g, Vector3(-0.44, AWAY_Y + 0.002, 0.22), Vector3(0.06, 0.006, 0.006), "steel", Vector3(0, -40, 0))
	C(g, Vector3(0.1, AWAY_Y + 0.004, -0.42), 0.04, 0.008, "red_paint")
	# the chalk the installers drew round it, redrawn where the floor shows it: corners, and the cross at the front
	var chalk: Material = chalk_mat()
	var w: float = HW + 0.07
	var d: float = HD + 0.07
	for sx: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			OB(g, Vector3(sx * (w - 0.17), AWAY_Y, sz2 * d), Vector3(0.34, 0.004, 0.022), "cream").material_override = chalk
			OB(g, Vector3(sx * w, AWAY_Y, sz2 * (d - 0.13)), Vector3(0.022, 0.004, 0.26), "cream").material_override = chalk
	OB(g, Vector3(0, AWAY_Y, -d - 0.1), Vector3(0.12, 0.004, 0.016), "cream", Vector3(0, 45, 0)).material_override = chalk
	OB(g, Vector3(0, AWAY_Y, -d - 0.1), Vector3(0.12, 0.004, 0.016), "cream", Vector3(0, -45, 0)).material_override = chalk


## Outdoors in the snow the crate leaves the bare ground it stood on: a dark rectangle inside the drift.
static func away_bare(g: Node3D) -> void:
	OB(g, Vector3(0, AWAY_Y - 0.004, 0), Vector3(2.0 * HW + 0.04, 0.006, 2.0 * HD + 0.04), "dirt")


## The cracks under the footprint: jittered hairlines from the middle outward (one mesh, MysteryCrate's material).
static func away_veins(g: Node3D) -> void:
	for root_v: Array in [[Vector2(-0.1, 0.02), Vector2(-0.68, -0.26), 5], [Vector2(0.06, -0.04), Vector2(0.66, 0.2), 5],
			[Vector2(0.0, 0.05), Vector2(0.18, 0.33), 3], [Vector2(-0.05, -0.05), Vector2(-0.3, -0.34), 3],
			[Vector2(0.3, 0.05), Vector2(0.62, -0.3), 3]]:
		var a: Vector2 = root_v[0]
		var b: Vector2 = root_v[1]
		var n: int = int(root_v[2])
		var prev: Vector2 = a
		for k: int in n:
			var t: float = float(k + 1) / float(n)
			var p: Vector2 = a.lerp(b, t) + Vector2(_j(k, n + 30, 0.035), _j(k + 3, n + 30, 0.035))
			S(g, Vector3(prev.x, AWAY_Y + 0.002, prev.y), Vector3(p.x, AWAY_Y + 0.002, p.y), lerpf(0.02, 0.008, t), "nachtglas_vein")
			prev = p


# ================================================================== T-254: a crate that stands outside

## Snow on the lid (lid frame: the origin is the hinge pins, the lid's top is y 0): three soft overlapping drifts,
## thicker toward the hinge side where the wind left it. It slides off when the lid first opens.
static func snow_lid(g: Node3D) -> void:
	# one even blanket over the whole lid, a little deeper toward the hinges, its edge rounded over the lid's rim
	Props.ball(g, Vector3(0.0, 0.0, -0.345), Vector3(1.5, 0.11, 0.76), "snow")
	Props.ball(g, Vector3(-0.1, 0.012, -0.2), Vector3(1.2, 0.12, 0.42), "snow")
	Props.ball(g, Vector3(0.3, 0.008, -0.42), Vector3(0.8, 0.1, 0.5), "snow")


## Snow drifted against the spot (spot frame; there whether or not the crate is): banked up behind it and at both
## ends, a thin lip in front. Low and soft: no collider.
static func snow_base(g: Node3D) -> void:
	# long low banks, most of each under the ground: a rise of a hand's width, never a lump
	Props.ball(g, Vector3(0.0, -0.05, HD + 0.2), Vector3(2.5, 0.3, 0.9), "snow")
	Props.ball(g, Vector3(-(HW + 0.28), -0.06, 0.05), Vector3(1.0, 0.28, 1.5), "snow")
	Props.ball(g, Vector3(HW + 0.3, -0.06, 0.02), Vector3(0.95, 0.26, 1.4), "snow")
	Props.ball(g, Vector3(0.1, -0.05, -(HD + 0.24)), Vector3(2.3, 0.17, 0.6), "snow")


## Where the lantern hangs (its glass centre), in crate space.
static func lantern_pos() -> Vector3:
	return Vector3(-(HW + 0.14) + 0.14, 1.09, -0.1)


static var _chalk: StandardMaterial3D


## Chalk that has been walked over: dustier and dimmer than the wall-buys' fresh outlines.
static func chalk_mat() -> Material:
	if _chalk == null:
		_chalk = (WeaponModels.base_mat("chalk") as StandardMaterial3D).duplicate() as StandardMaterial3D
		_chalk.albedo_color = Color(0.5, 0.52, 0.48)
		_chalk.emission_enabled = false
	return _chalk
