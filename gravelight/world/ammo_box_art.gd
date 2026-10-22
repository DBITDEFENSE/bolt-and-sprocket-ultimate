extends RefCounted
## Procedural art for the ammo box (Update 02 section 4, T-049): an olive-drab small-arms crate on skids, built
## from Props / InteractableArt primitives and Mats keys and merged into one cached mesh (one draw per material).
## (No class_name: AmmoBox preloads it, so a fresh checkout works before the editor rebuilds its class cache.)
##
## A planked crate painted olive drab, worn pale at the edges: end cleats, rope handles through iron eyes, a
## strapped lid on rear hinges with two front hasps, a yellow lot band on the front. On the lid: an open carton of
## rounds standing nose-up, a steel ammo can, a heap of loose rounds and stripper clips somebody tipped out in a
## hurry, and a hurricane lantern (its glass and light belong to AmmoBox: the light flickers). The stencils are
## Label3Ds, also AmmoBox's.
##
## Frame: origin = floor centre, local -Z faces the player. Body 1.0 x 0.62 x 0.56 (AmmoBox's collision box).

const HW: float = 0.5       # half width (X)
const HD: float = 0.28      # half depth (Z)
const BOT: float = 0.06     # body bottom (top of the skids)
const TOP: float = 0.56     # body top
const LID: float = 0.62     # lid top: the pile sits here


static func B(g: Node3D, a: Vector3, b: Vector3, key: String) -> MeshInstance3D:
	return Props.block(g, a, b, key)


static func OB(g: Node3D, c: Vector3, s: Vector3, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.obox(g, c, s, key, rot)


static func C(g: Node3D, c: Vector3, r: float, h: float, key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Props.cyl(g, c, r, h, key, rot)


static func dot(g: Node3D, c: Vector3, r: float, key: String) -> MeshInstance3D:
	return Props.ball(g, c, Vector3(r, r, r) * 2.0, key)


## Deterministic jitter in [-amp, amp].
static func _j(i: int, k: int, amp: float) -> float:
	return (fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0) - 0.5) * 2.0 * amp


# ================================================================== the crate

static func body(g: Node3D) -> void:
	# skids
	for sz: float in [-0.17, 0.17]:
		B(g, Vector3(-HW - 0.02, 0.0, sz - 0.045), Vector3(HW + 0.02, BOT, sz + 0.045), "beam")
	# the box: a dark core, then three planks a face, each a hair proud or shy of its neighbours
	B(g, Vector3(-HW + 0.015, BOT, -HD + 0.015), Vector3(HW - 0.015, TOP, HD - 0.015), "char")
	for i: int in 3:
		var y0: float = BOT + float(i) * (TOP - BOT) / 3.0 + 0.003
		var y1: float = BOT + float(i + 1) * (TOP - BOT) / 3.0 - 0.003
		for sz2: float in [-1.0, 1.0]:
			var d: float = 0.025 + _j(i, int(sz2) + 2, 0.004)
			B(g, Vector3(-HW + 0.03, y0, sz2 * (HD - d)), Vector3(HW - 0.03, y1, sz2 * HD), "olive_drab")
		for sx: float in [-1.0, 1.0]:
			B(g, Vector3(sx * (HW - 0.03), y0, -HD + 0.01), Vector3(sx * HW, y1, HD - 0.01), "olive_drab")
	# end cleats (the frame the planks are nailed to), proud of the ends and the front/back corners
	for sx2: float in [-1.0, 1.0]:
		for sz3: float in [-1.0, 1.0]:
			B(g, Vector3(sx2 * (HW - 0.065), BOT, sz3 * (HD + 0.012)), Vector3(sx2 * (HW + 0.005), TOP, sz3 * (HD - 0.03)), "olive_drab")
		B(g, Vector3(sx2 * HW, TOP - 0.07, -HD + 0.02), Vector3(sx2 * (HW + 0.02), TOP - 0.01, HD - 0.02), "olive_drab")
		B(g, Vector3(sx2 * HW, BOT + 0.01, -HD + 0.02), Vector3(sx2 * (HW + 0.02), BOT + 0.07, HD - 0.02), "olive_drab")
		# rope handle through two iron eyes on each end
		var ex: float = sx2 * (HW + 0.022)
		for ez: float in [-0.12, 0.12]:
			dot(g, Vector3(ex, 0.36, ez), 0.018, "iron")
		var pts: Array = [Vector3(ex, 0.36, -0.12), Vector3(ex + sx2 * 0.05, 0.31, -0.06), Vector3(ex + sx2 * 0.065, 0.295, 0.0),
			Vector3(ex + sx2 * 0.05, 0.31, 0.06), Vector3(ex, 0.36, 0.12)]
		for k: int in pts.size() - 1:
			Props.strut(g, pts[k], pts[k + 1], 0.026, "rope", true)
			dot(g, pts[k + 1], 0.013, "rope")
	# the yellow lot band across the front, and nail heads along the cleats
	B(g, Vector3(-0.3, 0.115, -HD - 0.006), Vector3(0.3, 0.14, -HD + 0.004), "yellow_paint")
	for sx3: float in [-1.0, 1.0]:
		for ny: float in [0.12, 0.29, 0.46]:
			dot(g, Vector3(sx3 * (HW - 0.033), ny, -HD - 0.013), 0.006, "steel")
	# the lid: a slab with two battens, strap hinges at the back, two hasps over the front
	B(g, Vector3(-HW - 0.012, TOP, -HD - 0.012), Vector3(HW + 0.012, LID - 0.012, HD + 0.012), "olive_drab")
	for bx: float in [-0.33, 0.33]:
		B(g, Vector3(bx - 0.04, LID - 0.012, -HD - 0.008), Vector3(bx + 0.04, LID, HD + 0.008), "olive_drab")
	for hx: float in [-0.3, 0.3]:
		C(g, Vector3(hx, TOP + 0.005, HD + 0.016), 0.012, 0.09, "iron", Vector3(0, 0, 90))
		B(g, Vector3(hx - 0.025, TOP - 0.1, HD + 0.008), Vector3(hx + 0.025, TOP, HD + 0.014), "iron")
		B(g, Vector3(-hx * 1.0 - 0.022, TOP - 0.08, -HD - 0.02), Vector3(-hx * 1.0 + 0.022, LID - 0.02, -HD - 0.012), "iron")
		dot(g, Vector3(-hx, TOP - 0.065, -HD - 0.022), 0.008, "steel")
	_pile(g)
	_lantern_frame(g)


# ================================================================== on the lid

static func _pile(g: Node3D) -> void:
	# an open carton of rounds standing nose-up (front left from the player: +X), flaps folded back
	var cc: Vector3 = Vector3(0.2, LID, -0.04)
	B(g, cc + Vector3(-0.1, 0.0, -0.075), cc + Vector3(0.1, 0.085, 0.075), "cardboard")
	OB(g, cc + Vector3(0.0, 0.1, 0.09), Vector3(0.2, 0.004, 0.06), "cardboard", Vector3(-55, 0, 0))
	OB(g, cc + Vector3(0.0, 0.07, -0.1), Vector3(0.2, 0.004, 0.05), "cardboard", Vector3(70, 0, 0))
	for ix: int in 6:
		for iz: int in 4:
			var p: Vector3 = cc + Vector3(-0.075 + ix * 0.03, 0.085, -0.045 + iz * 0.03)
			if ix == 4 and iz == 1 or ix == 1 and iz == 3:
				continue   # a couple already taken
			C(g, p + Vector3(0, 0.004, 0), 0.0065, 0.008, "brass")
			Props.cone(g, p + Vector3(0, 0.016, 0), 0.0065, 0.018, "copper")
	# a steel ammo can at the back right (-X), latch and carry handle on top
	var ac: Vector3 = Vector3(-0.3, LID, 0.1)
	B(g, ac + Vector3(-0.07, 0.0, -0.13), ac + Vector3(0.07, 0.2, 0.13), "olive_steel")
	B(g, ac + Vector3(-0.075, 0.2, -0.135), ac + Vector3(0.075, 0.215, 0.135), "olive_steel")
	B(g, ac + Vector3(-0.074, 0.08, -0.134), ac + Vector3(0.074, 0.1, 0.134), "olive_steel")
	B(g, ac + Vector3(-0.01, 0.215, -0.07), ac + Vector3(0.01, 0.225, 0.07), "steel")
	B(g, ac + Vector3(0.075, 0.13, -0.03), ac + Vector3(0.085, 0.215, 0.03), "steel")
	B(g, ac + Vector3(-0.05, 0.12, -0.136), ac + Vector3(0.05, 0.16, -0.134), "yellow_paint")
	# loose rounds heaped and scattered over the front of the lid, spilling toward the player
	for i: int in 30:
		var r: float = 0.02 + absf(_j(i, 3, 0.16))
		var a: float = _j(i, 4, PI)
		var p2: Vector3 = Vector3(-0.08 + cos(a) * r * 1.4, LID + 0.007, -0.15 + sin(a) * r * 0.6)
		p2.z = clampf(p2.z, -HD + 0.01, 0.0)
		p2.x = clampf(p2.x, -HW + 0.04, 0.08)
		if i < 8:
			p2.y += 0.012   # the heap's top layer
		_round_lying(g, p2, rad_to_deg(_j(i, 5, PI)), _j(i, 6, 8.0))
	# stripper clips: five rounds held by their base in a steel strip, lying on their sides
	for c: Array in [[Vector3(-0.02, LID + 0.008, -0.2), 20.0], [Vector3(-0.2, LID + 0.008, -0.12), -65.0],
			[Vector3(0.05, LID + 0.008, -0.07), 110.0], [Vector3(-0.15, LID + 0.02, -0.17), 160.0]]:
		_clip(g, c[0], float(c[1]))
	# two rounds rolled off onto the floor in front
	_round_lying(g, Vector3(0.12, 0.007, -HD - 0.12), 35.0, 0.0)
	_round_lying(g, Vector3(-0.22, 0.007, -HD - 0.2), -80.0, 0.0)


## One cartridge lying on its side: a brass case and a copper-jacketed nose, axis yawed by `yaw` degrees.
static func _round_lying(g: Node3D, at: Vector3, yaw: float, roll: float) -> void:
	var rot: Vector3 = Vector3(roll, yaw, 90.0)
	var ax: Vector3 = Basis.from_euler(rot * (PI / 180.0)) * Vector3.UP
	C(g, at, 0.0065, 0.052, "brass", rot)
	Props.cone(g, at + ax * 0.034, 0.0065, 0.018, "copper", rot)
	C(g, at - ax * 0.027, 0.0068, 0.003, "brass", rot)   # the rim


## A stripper clip of five rounds lying flat, rotated by `yaw` degrees about the lid's up axis.
static func _clip(g: Node3D, at: Vector3, yaw: float) -> void:
	var cg: Node3D = Node3D.new()
	cg.position = at
	cg.rotation_degrees = Vector3(0, yaw, 0)
	g.add_child(cg)
	# local: rounds point along +Z, side by side along X, the strip across their bases
	for k: int in 5:
		var x: float = -0.026 + k * 0.013
		C(cg, Vector3(x, 0.0, 0.0), 0.0062, 0.052, "brass", Vector3(90, 0, 0))
		Props.cone(cg, Vector3(x, 0.0, 0.034), 0.0062, 0.018, "copper", Vector3(90, 0, 0))
	B(cg, Vector3(-0.034, -0.007, -0.03), Vector3(0.034, 0.007, -0.022), "steel")


# ================================================================== the hurricane lantern (back left from the player: +X)

## Where the lantern's glass centre is, in box space (AmmoBox puts the glass and the light here).
static func lantern_pos() -> Vector3:
	return Vector3(0.33, LID + 0.115, 0.13)


static func _lantern_frame(g: Node3D) -> void:
	var lc: Vector3 = lantern_pos()
	C(g, Vector3(lc.x, LID + 0.022, lc.z), 0.06, 0.044, "red_paint")      # the fuel fount
	C(g, Vector3(lc.x, LID + 0.047, lc.z), 0.045, 0.008, "iron")
	C(g, lc + Vector3(0, 0.085, 0), 0.048, 0.012, "iron")                  # the chimney collar
	Props.cone(g, lc + Vector3(0, 0.115, 0), 0.06, 0.05, "red_paint")      # the cap
	C(g, lc + Vector3(0, 0.15, 0), 0.016, 0.02, "iron")
	for k: int in 2:   # side tubes of the frame
		var sx: float = -0.058 if k == 0 else 0.058
		Props.strut(g, Vector3(lc.x + sx, LID + 0.04, lc.z), Vector3(lc.x + sx, lc.y + 0.11, lc.z), 0.01, "iron", true)
	for k2: int in 4:   # the glass guard wires
		var a: float = TAU * float(k2) / 4.0 + 0.4
		Props.strut(g, lc + Vector3(cos(a) * 0.05, -0.06, sin(a) * 0.05), lc + Vector3(cos(a) * 0.05, 0.075, sin(a) * 0.05), 0.004, "iron", true)
	InteractableArt.ring(g, lc + Vector3(0, 0.19, 0), 0.04, 0.005, "iron", Vector3(0, 0, 90))   # the bail, up
