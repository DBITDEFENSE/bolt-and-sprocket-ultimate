class_name VerdantDressing
extends RefCounted
## Procedural swamp dressing for Verdant Sink (BS_LEVELS §6.1 verdantDress, remade): glow-mushroom groves
## (four glow colours), root arches, mushroom clusters, picket signs, the TerraFarm fence, hanging glow-vines,
## frog-bots and firefly fields. Everything is original greybox-plus (LevelKit primitives). Static pieces go
## under the director's geometry (navmesh-baked when solid); ambient life under dynamic.

const GLOWS: Array = ["#5affc8", "#ff6ad5", "#4fc3ff", "#ffd23e"]


static func glow_mushroom(parent: Node, pos: Vector3, r: float, h: float, col: Variant, solid: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	parent.add_child(root)
	LevelKit.cylinder(root, Vector3(0, h * 0.5, 0), r * 0.22, h, "#c9b89a", solid)
	LevelKit.cylinder(root, Vector3(0, h, 0), r, r * 0.45, col, solid, "y", r * 0.35, 1.1)
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0 + float(pos.x)
		LevelKit.cylinder(root, Vector3(cos(a) * r * 0.5, h + r * 0.24, sin(a) * r * 0.5), r * 0.1, 0.04, "#ffffff", false, "y", -1.0, 1.6)
	return root


## A grove: `n` glow mushrooms scattered inside a radius, four glow colours, seeded.
static func grove(parent: Node, center: Vector3, radius: float, n: int, seed_val: int, solid: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for i: int in n:
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = rng.randf_range(radius * 0.2, radius)
		var r: float = rng.randf_range(0.5, 1.4)
		var h: float = rng.randf_range(0.8, 2.6)
		glow_mushroom(parent, center + Vector3(cos(a) * d, 0, sin(a) * d), r, h, GLOWS[i % GLOWS.size()], solid)


## A root arch: two posts and a lintel (solid when under a StaticBody3D parent, else deco).
static func root_arch(parent: Node, pos: Vector3, h: float, w: float) -> void:
	var solid: bool = parent is StaticBody3D
	for sx: float in [-w * 0.5, w * 0.5]:
		var post: Node3D = LevelKit.box(parent, pos + Vector3(sx, h * 0.5, 0), Vector3(0.6, h, 0.7), "#3b2a1e", false, Vector3(0, 0, -sx * 4.0))
		var _u: Node3D = post
	LevelKit.box(parent, pos + Vector3(0, h + 0.2, 0), Vector3(w + 1.0, 0.6, 0.8), "#3b2a1e", false)
	LevelKit.box(parent, pos + Vector3(0, h + 0.55, 0), Vector3(w * 0.6, 0.12, 0.3), "#5affc8", false, Vector3.ZERO, 1, 1.2)
	if solid:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = Vector3(w + 1.0, h + 0.6, 0.9)
		cs.shape = sh
		cs.position = pos + Vector3(0, (h + 0.6) * 0.5, 0)
		parent.add_child(cs)


## A cluster of 3-4 small caps around a fat one (cover in the lagoon).
static func mushroom_cluster(parent: Node, pos: Vector3, seed_val: int, solid: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	glow_mushroom(parent, pos, 1.6, 1.4, GLOWS[seed_val % GLOWS.size()], solid)
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + rng.randf_range(0.0, 0.6)
		glow_mushroom(parent, pos + Vector3(cos(a) * 2.0, 0, sin(a) * 2.0), rng.randf_range(0.6, 1.0), rng.randf_range(0.6, 1.1), GLOWS[(seed_val + i + 1) % GLOWS.size()], solid)


## A hand-painted picket sign on a stick (the corn hold these; also planted at the picket line).
static func picket_sign(parent: Node, pos: Vector3, text: String, ry: float = 0.0, fg: Variant = "#2a1a10", bg: Variant = "#ffd23e") -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation_degrees.y = ry
	parent.add_child(root)
	LevelKit.box(root, Vector3(0, 0.9, 0), Vector3(0.08, 1.8, 0.08), "#c9b89a", false)
	LevelKit.text_sign(root, text, Vector3(0, 1.9, 0.06), Vector2(1.6, 0.6), 0.0, bg, fg)
	return root


## The rusted TerraFarm fence along a line (deco posts and two rails).
static func fence(parent: Node, a: Vector3, b: Vector3, post_every: float = 3.0) -> void:
	var d: Vector3 = b - a
	var L: float = d.length()
	if L < 0.1:
		return
	var n: int = maxi(2, int(L / post_every) + 1)
	for i: int in n:
		var p: Vector3 = a.lerp(b, float(i) / float(n - 1))
		LevelKit.box(parent, p + Vector3(0, 1.1, 0), Vector3(0.14, 2.2, 0.14), "#7a4a2a", false)
	for h: float in [0.7, 1.7]:
		NovaArt.beam(parent, a + Vector3(0, h, 0), b + Vector3(0, h, 0), Vector2(0.06, 0.06), "#8a95a8", false)


## Hanging glow-vines between two points (a sagging chain of lit beads).
static func glow_vine(parent: Node, a: Vector3, b: Vector3, sag: float, col: Variant = "#5affc8") -> void:
	var n: int = 8
	var prev: Vector3 = a
	for i: int in range(1, n + 1):
		var t: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, t) + Vector3(0, -sin(t * PI) * sag, 0)
		NovaArt.beam(parent, prev, p, Vector2(0.05, 0.05), "#2f4a2a", false)
		if i % 2 == 0:
			LevelKit.cylinder(parent, p, 0.08, 0.12, col, false, "y", -1.0, 1.4)
		prev = p


## A frog-bot: a squat body with two lamp eyes, parked on a lily pad. Ambient life (dynamic, deco).
static func frog_bot(parent: Node, pos: Vector3, ry: float = 0.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation_degrees.y = ry
	parent.add_child(root)
	LevelKit.cylinder(root, Vector3(0, 0.03, 0), 0.8, 0.06, "#2f6a3a", false)
	LevelKit.box(root, Vector3(0, 0.32, 0), Vector3(0.7, 0.4, 0.6), "#3fa04a", false)
	for sx: float in [-0.2, 0.2]:
		LevelKit.cylinder(root, Vector3(sx, 0.58, 0.18), 0.1, 0.12, "#ffd23e", false, "y", -1.0, 1.8)
	for sx: float in [-0.42, 0.42]:
		LevelKit.box(root, Vector3(sx, 0.12, -0.1), Vector3(0.18, 0.2, 0.4), "#2f6a3a", false)
	return root


## A firefly field: small lit motes that drift (an ambient node animates them).
static func fireflies(parent: Node, center: Vector3, radius: float, n: int, seed_val: int) -> Node3D:
	var root: VerdantFireflies = VerdantFireflies.new()
	root.position = center
	root.radius = radius
	root.count = n
	root.seed_val = seed_val
	parent.add_child(root)
	return root


## The harvester's dead intake and draped vines on its south face (the lake side).
static func harvester_face(parent: Node, pos: Vector3) -> void:
	LevelKit.cylinder(parent, pos + Vector3(-6, 3.5, 0.6), 1.6, 1.0, "#3b2a1e", false, "z")
	LevelKit.cylinder(parent, pos + Vector3(-6, 3.5, 0.6), 1.2, 1.1, "#0a3b2e", false, "z")
	for i: int in 5:
		var x: float = pos.x - 9.0 + 4.5 * i
		glow_vine(parent, Vector3(x, pos.y + 8.0, pos.z + 0.6), Vector3(x + 2.5, pos.y + 8.0, pos.z + 0.6), 2.4, GLOWS[i % GLOWS.size()])
	LevelKit.text_sign(parent, "HR-9", pos + Vector3(6, 6.0, 0.6), Vector2(3, 1.2), 180.0, "#6f7a3e", "#ffffff")
