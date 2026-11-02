class_name ThalbachLife
extends RefCounted
## Werk Thalbach's living-world pieces (UPDATE 10 Act I, DECISIONS T-155): static builders the map's MapAmbience
## block ("# ---- U10 Act I ----" in map_ambience.gd, data/gravelight/map04a_ambience.json "act1") uses. All
## presentation: no collider, no gameplay. Own geometry only (boxes, cylinders, procedural textures).
## The two fictional marks (docs/ART_FACTIONS.md §1 and §1b): Projekt Wiederkehr's Sunburst-and-Split-Bell (P·W·K)
## and Werk Thalbach's works mark, the crane in a cog. Nothing else is ever drawn on a poster.

static var _tex_cache: Dictionary = {}
static var _flap_shader: Shader


## A test jet (a fictional twin-jet with swept wings, plain grey, no markings) facing +X, nose at +X.
static func jet(parent: Node3D) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "TestJet"
	parent.add_child(g)
	Props.cyl(g, Vector3(0, 0, 0), 0.75, 11.0, "machine_grey", Vector3(0, 0, 90))
	Props.cone(g, Vector3(6.2, 0, 0), 0.75, 1.6, "machine_grey", Vector3(0, 0, -90))
	Props.obox(g, Vector3(1.6, 0.45, 0), Vector3(1.8, 0.5, 0.8), "glass")
	for side: float in [-1.0, 1.0]:
		Props.obox(g, Vector3(-0.6, -0.15, side * 3.6), Vector3(2.6, 0.18, 6.4), "machine_grey", Vector3(0, side * -28.0, 0))
		Props.cyl(g, Vector3(-0.2, -0.75, side * 2.6), 0.45, 3.4, "steel", Vector3(0, 0, 90))
		var glow: MeshInstance3D = Props.cyl(g, Vector3(-1.95, -0.75, side * 2.6), 0.36, 0.06, "lamp_red_lit", Vector3(0, 0, 90))
		glow.material_override = _emissive(Color(1.0, 0.55, 0.25), 6.0)
		Props.obox(g, Vector3(-4.6, 0.1, side * 1.5), Vector3(1.4, 0.12, 2.6), "machine_grey", Vector3(0, side * -30.0, 0))
	Props.obox(g, Vector3(-4.8, 1.2, 0), Vector3(1.8, 2.2, 0.14), "machine_grey", Vector3(0, 0, -35))
	_no_shadow(g)
	merge(g)
	g.scale = Vector3.ONE * 1.5
	var ex: OmniLight3D = OmniLight3D.new()
	ex.light_color = Color(1.0, 0.55, 0.25)
	ex.light_energy = 6.0
	ex.omni_range = 22.0
	ex.shadow_enabled = false
	ex.position = Vector3(-3.0, -0.6, 0)
	g.add_child(ex)
	return g


## A plain steam locomotive (no markings) and `cars` flatcars behind it, facing -X (it arrives heading west).
static func train(parent: Node3D, cars: int) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "Train"
	parent.add_child(g)
	var loco: Node3D = Node3D.new()
	loco.name = "Loco"
	g.add_child(loco)
	Props.cyl(loco, Vector3(-1.5, 2.4, 0), 1.0, 7.0, "loco_black", Vector3(0, 0, 90))
	Props.obox(loco, Vector3(3.0, 2.6, 0), Vector3(3.0, 3.0, 2.8), "loco_black")
	Props.obox(loco, Vector3(3.0, 4.2, 0), Vector3(3.2, 0.2, 3.0), "loco_black")
	Props.cyl(loco, Vector3(-4.0, 3.9, 0), 0.32, 1.4, "loco_black")
	Props.cyl(loco, Vector3(-1.0, 3.6, 0), 0.4, 0.6, "loco_black")
	Props.obox(loco, Vector3(0.5, 0.9, 0), Vector3(9.4, 0.5, 2.6), "loco_black")
	for wx: float in [-3.6, -1.8, 0.0, 1.8]:
		for side: float in [-1.0, 1.0]:
			Props.cyl(loco, Vector3(wx, 0.75, side * 1.0), 0.75, 0.14, "rust", Vector3(90, 0, 0))
	var lamp: MeshInstance3D = Props.cyl(loco, Vector3(-5.05, 2.5, 0), 0.22, 0.1, "lamp_red_lit", Vector3(0, 0, 90))
	lamp.material_override = _emissive(Color(1.0, 0.8, 0.5), 3.0)
	for i: int in cars:
		var x0: float = 7.5 + float(i) * 10.5
		Props.obox(g, Vector3(x0 + 4.5, 1.2, 0), Vector3(9.6, 0.35, 2.7), "rust")
		for wx2: float in [x0 + 1.5, x0 + 7.5]:
			for side2: float in [-1.0, 1.0]:
				Props.cyl(g, Vector3(wx2, 0.5, side2 * 1.0), 0.5, 0.12, "rust", Vector3(90, 0, 0))
		if i % 2 == 0:
			Props.obox(g, Vector3(x0 + 4.5, 1.9, 0), Vector3(6.0, 1.0, 2.2), "tarp")
	_no_shadow(g)
	merge(g)
	return g


## A straight siding from `a` to `b` (two rails on sleepers), as one merged mesh.
static func rails(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "Siding"
	parent.add_child(g)
	var d: Vector3 = b - a
	var len_: float = d.length()
	var mid: Vector3 = (a + b) * 0.5
	var yaw: float = rad_to_deg(atan2(-d.z, d.x))
	for side: float in [-0.72, 0.72]:
		Props.obox(g, mid + Vector3(0, 0.12, 0) + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, side), Vector3(len_, 0.14, 0.08), "steel", Vector3(0, yaw, 0))
	var n: int = int(len_ / 1.6)
	for i: int in n:
		var p: Vector3 = a + d * (float(i) / float(maxi(1, n)))
		Props.obox(g, p + Vector3(0, 0.04, 0), Vector3(0.24, 0.08, 2.4), "planks", Vector3(0, yaw, 0))
	_no_shadow(g)
	merge(g)
	return g


## A blackout blind drawn over a lit window (marker from the generator's LitWindows: meta out, w, h).
static func blind(parent: Node3D, m: Node3D) -> MeshInstance3D:
	var out: Vector3 = m.get_meta("out", Vector3.BACK)
	var w: float = float(m.get_meta("w", 1.2))
	var h: float = float(m.get_meta("h", 1.4))
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(w * 0.92, h * 0.92, 0.01)
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.045, 0.04)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = m.global_position
	mi.look_at(m.global_position + out, Vector3.UP)
	return mi


## The poster textures: "wiederkehr" (the P·W·K Sunburst-and-Split-Bell) and "kranich" (the crane in a cog,
## WERK THALBACH), black on old paper. Drawn once, cached.
static func poster_texture(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var W: int = 192
	var H: int = 272
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var paper: Color = Color(0.78, 0.72, 0.58)
	var ink: Color = Color(0.06, 0.05, 0.05)
	img.fill(paper)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for i: int in 900:   # foxing and wear
		img.set_pixel(rng.randi() % W, rng.randi() % H, paper.darkened(rng.randf_range(0.05, 0.25)))
	var cx: float = W * 0.5
	if kind == "wiederkehr":
		var hy: float = 150.0
		var r_long: float = 70.0
		for k: int in 11:
			var a: float = PI * (float(k) + 0.5) / 11.0
			var rr: float = r_long if k % 2 == 0 else r_long * 0.72
			for t: int in int(rr):
				var x: float = cx + cos(a) * float(t)
				var y: float = hy - sin(a) * float(t)
				for o: int in range(-3, 4):
					_px(img, x - sin(a) * o, y - cos(a) * o, ink)
		for x2: int in range(int(cx - 80), int(cx + 80)):
			for y2: int in range(int(hy), int(hy + 4)):
				_px(img, x2, y2, ink)
		# the bell, split down the middle, the halves leaning apart
		for y3: int in range(int(hy - 66), int(hy)):
			var u: float = float(y3 - (hy - 66)) / 66.0
			var half: float = 10.0 + 24.0 * pow(u, 1.6)
			var gap: float = 1.0 + 3.5 * u
			for x3: int in range(int(cx - half), int(cx + half)):
				if absf(float(x3) - cx) > gap:
					_px(img, x3, y3, paper if absf(float(x3) - cx) < half - 3.0 else ink)
			_px(img, cx - half, y3, ink)
			_px(img, cx + half, y3, ink)
		_text_bar(img, int(cx), 196, "P W K", ink)
		_text_bar(img, int(cx), 232, "WIEDERKEHR", ink)
	else:
		var c: Vector2 = Vector2(cx, 110)
		for y4: int in H:
			for x4: int in W:
				var d: Vector2 = Vector2(x4, y4) - c
				var r: float = d.length()
				var ang: float = atan2(d.y, d.x)
				var tooth: bool = fmod(ang + TAU, TAU / 12.0) < TAU / 24.0
				var outer: float = 72.0 if tooth else 62.0
				if r < outer and r > 50.0:
					img.set_pixel(x4, y4, ink)
		# the crane: a long-necked bird in flight across the cog (body, neck, beak, two wings, trailing legs)
		for t2: int in 120:
			var f: float = float(t2) / 119.0
			_disc(img, Vector2(cx - 40 + f * 70.0, 120 - f * 18.0), 3.0 + 3.0 * sin(f * PI), ink)
		for t3: int in 30:
			_disc(img, Vector2(cx + 30 + float(t3) * 0.9, 102 - float(t3) * 0.2), 1.6, ink)
		for t4: int in 60:
			var f2: float = float(t4) / 59.0
			_disc(img, Vector2(cx - 4 - f2 * 30.0, 112 - f2 * 34.0 + f2 * f2 * 10.0), 3.2 - 2.0 * f2, ink)
			_disc(img, Vector2(cx - 4 - f2 * 22.0, 116 + f2 * 26.0 - f2 * f2 * 6.0), 2.8 - 1.8 * f2, ink)
		for t5: int in 30:
			_disc(img, Vector2(cx - 40 - float(t5) * 1.0, 121 + float(t5) * 0.15), 1.0, ink)
		_text_bar(img, int(cx), 206, "WERK THALBACH", ink)
		_text_bar(img, int(cx), 238, "WIR BAUEN DEN KRANICH", ink)
	img.generate_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex


## Block lettering (a 3x5 pixel font scaled 2x) centred on x.
static func _text_bar(img: Image, x_mid: int, y: int, text: String, ink: Color) -> void:
	var font: Dictionary = {"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
		"H": "101101111101101", "I": "111010010010111", "K": "101101110101101", "L": "100100100100111", "N": "101111111111101", "P": "110101110100100",
		"R": "110101110101101", "T": "111010010010010", "U": "101101101101111", "W": "101101111111101", "Z": "111001010100111", "G": "011100101101011",
		"O": "010101101101010", "S": "011100010001110", " ": "000000000000000", "M": "101111111101101", "F": "111100110100100", "V": "101101101101010"}
	var sc: int = 2
	var wpx: int = text.length() * 4 * sc
	var x0: int = x_mid - wpx / 2
	for i: int in text.length():
		var glyph: String = font.get(text[i], font[" "])
		for row: int in 5:
			for col: int in 3:
				if glyph[row * 3 + col] == "1":
					for sy: int in sc:
						for sx: int in sc:
							_px(img, x0 + i * 4 * sc + col * sc + sx, y + row * sc + sy, ink)


static func _px(img: Image, x: float, y: float, c: Color) -> void:
	var xi: int = int(x)
	var yi: int = int(y)
	if xi >= 0 and yi >= 0 and xi < img.get_width() and yi < img.get_height():
		img.set_pixel(xi, yi, c)


static func _disc(img: Image, c: Vector2, r: float, ink: Color) -> void:
	for y: int in range(int(c.y - r), int(c.y + r) + 1):
		for x: int in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x, y).distance_to(c) <= r:
				_px(img, x, y, ink)


## A flapping poster: a subdivided quad whose free (bottom) edge ripples with `wind` (a shader uniform the block sets).
static func poster(parent: Node3D, kind: String, pos: Vector3, yaw: float, size: Vector2 = Vector2(0.9, 1.28)) -> MeshInstance3D:
	if _flap_shader == null:
		_flap_shader = Shader.new()
		_flap_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float wind = 0.3;
uniform float phase = 0.0;
void vertex() {
	float free = clamp(0.5 - VERTEX.y / %f, 0.0, 1.0);
	float w = sin(TIME * 7.0 + VERTEX.x * 6.0 + phase) * 0.5 + sin(TIME * 13.0 + VERTEX.x * 11.0 + phase) * 0.25;
	VERTEX.z += w * free * free * 0.12 * wind;
	VERTEX.y += abs(w) * free * 0.03 * wind;
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * 0.85;
	ROUGHNESS = 0.95;
}
""" % size.y
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Poster_" + kind
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	q.subdivide_width = 6
	q.subdivide_depth = 8
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _flap_shader
	m.set_shader_parameter("tex", poster_texture(kind))
	m.set_shader_parameter("phase", pos.x * 1.7 + pos.z)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation.y = deg_to_rad(yaw)
	return mi


## A fighter-scale wing section hung on two cables from `top` (the pivot is at the top: rotate it to sway).
static func hanging_section(parent: Node3D, top: Vector3, drop: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "HangingWing"
	parent.add_child(pivot)
	pivot.global_position = top
	for side: float in [-1.4, 1.4]:
		Props.cyl(pivot, Vector3(side, -drop * 0.5, 0), 0.02, drop, "iron")
	Props.obox(pivot, Vector3(0, -drop - 0.1, 0), Vector3(4.2, 0.16, 1.5), "chrome_worn", Vector3(0, 0, 4))
	for k: int in 6:
		Props.obox(pivot, Vector3(-1.8 + float(k) * 0.72, -drop - 0.1, 0), Vector3(0.05, 0.22, 1.5), "machine_grey")
	_no_shadow(pivot)
	merge(pivot)
	return pivot


## A one-shot burst of hot sparks (welding / the rails under a braking train).
static func sparks(parent: Node3D, at: Vector3, amount: int = 40, spread: float = 60.0) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.7
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = spread
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -12, 0)
	pm.color = Color(1.0, 0.8, 0.45)
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = _emissive(Color(1.0, 0.7, 0.3), 5.0, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	return p


static func _emissive(c: Color, e: float, billboard: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = true
	return m


## Folds every primitive mesh under `group` into one mesh per material (the group's own frame; contract C4: a
## heap of boxes is one draw call per material, not fifty). Only for pieces that never move apart.
static func merge(group: Node3D) -> int:
	var buckets: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in group.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != group:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var k: String = "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		if not buckets.has(k):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[k] = {"st": st, "mat": mi.material_override, "shadow": mi.cast_shadow}
		(buckets[k]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	for k2: String in buckets.keys():
		var b: Dictionary = buckets[k2]
		var out: MeshInstance3D = MeshInstance3D.new()
		out.mesh = (b["st"] as SurfaceTool).commit()
		out.material_override = b["mat"]
		out.cast_shadow = b["shadow"]
		group.add_child(out)
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	return victims.size()


static func _no_shadow(n: Node) -> void:
	for c: Node in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
