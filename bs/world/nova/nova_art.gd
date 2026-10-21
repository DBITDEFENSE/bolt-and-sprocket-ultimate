class_name NovaArt
extends RefCounted
## Procedural greybox art for Nova Plaza (night smart city): lit-window towers (a generated window texture,
## world-triplanar so one material covers any tower size), identical smart homes, smart cars, neon signs,
## translucent holograms and cones. Everything is original procedural geometry; colours come from the level
## data. Solid pieces use LevelKit (StaticBody3D on the world layer).

static var _win_mats: Dictionary = {}
static var _glow_mats: Dictionary = {}


## Unshaded, optionally translucent material (holograms, cones, light shafts, water).
static func glow(c: Variant, alpha: float = 1.0, energy: float = 1.0) -> StandardMaterial3D:
	var col: Color = LevelKit.color(c)
	var key: String = "%s|%.2f|%.2f" % [col.to_html(), alpha, energy]
	if _glow_mats.has(key):
		return _glow_mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_glow_mats[key] = m
	return m


## A window-grid texture: 8 x 8 cells of 16 px, each window lit or dark (seeded, so towers differ by seed).
static func window_texture(seed_val: int, lit_frac: float = 0.45) -> ImageTexture:
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	for r: int in 8:
		for c: int in 8:
			if rng.randf() > lit_frac:
				continue
			var v: float = rng.randf_range(0.55, 1.0)
			img.fill_rect(Rect2i(c * 16 + 3, r * 16 + 4, 10, 8), Color(v, v, v))
	return ImageTexture.create_from_image(img)


## Tower facade material: dark glass with the hue glowing through the lit windows. One cell = 1.6 m.
static func window_mat(hue: Variant, seed_val: int = 1) -> StandardMaterial3D:
	var col: Color = LevelKit.color(hue)
	var key: String = "%s|%d" % [col.to_html(), seed_val % 4]
	if _win_mats.has(key):
		return _win_mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = LevelKit.color("#0e1428")
	m.roughness = 0.4
	m.metallic = 0.3
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.8
	m.emission_texture = window_texture(1000 + (seed_val % 4) * 7919)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 12.8
	m.rim_enabled = true
	m.rim = 0.3
	_win_mats[key] = m
	return m


## A lit-window skyscraper (novaTower): solid body, a dark roof cap, and a roof aerial light in the hue.
static func tower(parent: Node, foot: Vector3, w: float, d: float, h: float, hue: Variant, seed_val: int = 1, solid: bool = true) -> Node3D:
	var body: Node3D = LevelKit.box(parent, foot + Vector3(0, h * 0.5, 0), Vector3(w, h, d), "#0e1428", solid)
	var mi: MeshInstance3D = body as MeshInstance3D if body is MeshInstance3D else body.get_child(1) as MeshInstance3D
	if mi != null:
		mi.material_override = window_mat(hue, seed_val)
	LevelKit.box(parent, foot + Vector3(0, h + 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3), "#141a30", false)
	LevelKit.box(parent, foot + Vector3(0, h + 0.7, 0), Vector3(0.3, 0.8, 0.3), hue, false, Vector3.ZERO, 1, 2.0)
	return body


## An identical HOA smart home: body, pitched roof, door with a VACANT notice, one lit window, lawn placard.
## Faces +z in local space before `ry` (degrees). Returns the root node.
static func home(parent: Node, foot: Vector3, ry: float, body_col: Variant, notice: String, placard: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = foot
	root.rotation_degrees.y = ry
	parent.add_child(root)
	LevelKit.box(root, Vector3(0, 1.8, 0), Vector3(6, 3.6, 5.4), body_col, true)
	var roof: Node3D = LevelKit.box(root, Vector3(0, 4.2, 0), Vector3(4.6, 4.6, 5.8), "#2a3150", false, Vector3(0, 0, 45))
	roof.scale = Vector3(1, 0.42, 1)
	LevelKit.box(root, Vector3(-1.2, 1.1, 2.72), Vector3(1.1, 2.2, 0.06), "#232838", false)
	LevelKit.box(root, Vector3(1.4, 2.0, 2.72), Vector3(1.4, 1.0, 0.05), "#ffd27a", false, Vector3.ZERO, 1, 1.2)
	LevelKit.text_sign(root, notice, Vector3(-1.2, 1.55, 2.78), Vector2(0.95, 0.5), 0.0, "#f2f2e8", "#c9302a")
	# lawn placard on a stake
	LevelKit.box(root, Vector3(2.0, 0.45, 4.2), Vector3(0.08, 0.9, 0.08), "#cfd6e4", false)
	LevelKit.text_sign(root, placard, Vector3(2.0, 1.0, 4.24), Vector2(1.1, 0.55), 0.0, "#ffd23e", "#141414")
	return root


## A parked smart car: body, cabin, glowing head- and tail-lights. Faces +z before ry.
static func car(parent: Node, foot: Vector3, ry: float, col: Variant) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = foot
	root.rotation_degrees.y = ry
	parent.add_child(root)
	LevelKit.box(root, Vector3(0, 0.55, 0), Vector3(2.0, 0.8, 4.2), col, true)
	LevelKit.box(root, Vector3(0, 1.2, -0.2), Vector3(1.8, 0.6, 2.2), "#1a2240", false)
	for sx: float in [-0.65, 0.65]:
		LevelKit.box(root, Vector3(sx, 0.6, 2.11), Vector3(0.4, 0.18, 0.04), "#e8f4ff", false, Vector3.ZERO, 1, 2.0)
		LevelKit.box(root, Vector3(sx, 0.6, -2.11), Vector3(0.4, 0.18, 0.04), "#ff3a4a", false, Vector3.ZERO, 1, 1.6)
	return root


## A torus ring (tether anchors, the core's halo).
static func ring(parent: Node, pos: Vector3, r: float, thick: float, c: Variant, energy: float = 1.0, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = LevelKit.mat(c, energy)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## A translucent cone (a camera's view cone, a hologram tier). Apex at the origin, opening along local +y.
static func cone(parent: Node, pos: Vector3, radius: float, height: float, c: Variant, alpha: float, energy: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = 0.02
	cm.height = height
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = glow(c, alpha, energy)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A floating neon text label (billboard off; faces +z before the parent's rotation).
static func neon_text(parent: Node, text: String, pos: Vector3, px: float, c: Variant, ry: float = 0.0, billboard: bool = false) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = LevelKit.text(text)
	l.position = pos
	l.rotation_degrees.y = ry
	l.pixel_size = px
	l.font_size = 64
	l.modulate = LevelKit.color(c)
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.outline_size = 8
	l.double_sided = true
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


## A holo-billboard: dark frame, glowing panel and a neon caption (adBoard).
static func billboard(parent: Node, pos: Vector3, size: Vector2, ry: float, text: String, c: Variant) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation_degrees.y = ry
	parent.add_child(root)
	LevelKit.box(root, Vector3(0, 0, -0.12), Vector3(size.x + 0.4, size.y + 0.4, 0.2), "#141a30", false)
	var panel: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = size
	panel.mesh = qm
	panel.material_override = glow(c, 0.35, 0.8)
	root.add_child(panel)
	var lbl: Label3D = neon_text(root, text, Vector3(0, 0, 0.03), 0.01, "#ffffff")
	lbl.width = size.x / lbl.pixel_size
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.font_size = int(clampf(size.y * 18.0, 32.0, 120.0))
	return root


## A thin box between two points (beams, rails, spans). Solid or deco.
static func beam(parent: Node, a: Vector3, b: Vector3, thick: Vector2, c: Variant, solid: bool = false, energy: float = 0.0) -> Node3D:
	var ln: float = a.distance_to(b)
	var n: Node3D = LevelKit.box(parent, (a + b) * 0.5, Vector3(thick.x, thick.y, maxf(0.05, ln)), c, solid, Vector3.ZERO, LevelKit.WORLD_LAYER, energy)
	if ln > 0.01:
		var up: Vector3 = Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD
		n.look_at_from_position((a + b) * 0.5, b, up)
	return n
