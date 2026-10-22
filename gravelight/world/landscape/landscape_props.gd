class_name LandscapeProps
extends RefCounted
## Code-built set pieces for the land beyond Map 0 (Update 02 section 7, T-052): the abandoned road, the telephone
## line, the frozen stream's bridge, the farmhouse, the church on the far hill, the crash site's extra wreckage, the
## icicles. All decorative and collision-free; built from Props primitives (Mats materials) so Landscape can batch
## them, except the far pieces, which take the custom-fog material passed in.


## The burnt-out field car (a Kübelwagen-type tub) nosed into the ditch: tub, sloped bonnet and engine deck, the
## windscreen frame without glass, two wheels burnt down to the rims, scorched snow around it.
static func burnt_car(parent: Node3D, pos: Vector3, yaw: float, tilt: float) -> Node3D:
	var g: Node3D = Props.group(parent, "BurntCar", pos, yaw)
	g.rotation.z = deg_to_rad(tilt)
	g.rotation.x = deg_to_rad(-4.0)
	Props.block(g, Vector3(-0.8, 0.35, -1.75), Vector3(0.8, 0.95, 1.75), "wreck")
	Props.obox(g, Vector3(0, 0.84, -2.05), Vector3(1.5, 0.12, 0.8), "wreck", Vector3(-24, 0, 0))     # bonnet
	Props.obox(g, Vector3(0, 0.9, 2.0), Vector3(1.5, 0.12, 0.9), "char", Vector3(30, 0, 0))         # engine deck
	Props.block(g, Vector3(-0.76, 0.4, -1.7), Vector3(0.76, 0.5, 1.7), "char")                      # gutted floor
	for sx: float in [-0.74, 0.74]:
		Props.block(g, Vector3(sx - 0.03, 0.95, -0.95), Vector3(sx + 0.03, 1.45, -0.9), "rust")      # screen posts
	Props.block(g, Vector3(-0.76, 1.42, -0.96), Vector3(0.76, 1.47, -0.89), "rust")
	Props.obox(g, Vector3(0.5, 1.2, 0.3), Vector3(0.05, 0.5, 0.45), "rust", Vector3(0, 0, -30))     # seat frame
	Props.obox(g, Vector3(-0.45, 1.15, 0.2), Vector3(0.05, 0.45, 0.42), "rust", Vector3(0, 0, 25))
	for w: Array in [[Vector3(-0.85, 0.36, -1.3), 0.36], [Vector3(0.85, 0.36, -1.3), 0.33], [Vector3(-0.85, 0.36, 1.35), 0.36],
			[Vector3(0.85, 0.28, 1.35), 0.29]]:
		var burnt: bool = float(w[1]) < 0.34
		Props.cyl(g, w[0], float(w[1]), 0.24 if not burnt else 0.1, "char" if not burnt else "rust", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(0, 1.0, -2.25), 0.3, 0.2, "char", Vector3(66, 0, 0))                       # spare on the bonnet
	Props._noshadow(Props.cyl(parent, pos + Vector3(0, 0.01, 0), 3.2, 0.02, "char"))
	Props.ball(g, Vector3(0.2, 0.95, 0.9), Vector3(1.0, 0.18, 1.2), "snow")                        # snow drifted into the tub
	return g


## A horse cart tipped onto its side with its load spilled: sacks, a crate, a wheel rolled off.
static func tipped_cart(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "TippedCart", pos, yaw)
	var c: Node3D = Props.group(g, "Cart", Vector3(0, 0.95, 0), 0.0)
	c.rotation.z = deg_to_rad(82.0)
	Props.block(c, Vector3(-0.8, -0.05, -1.3), Vector3(0.8, 0.05, 1.3), "planks")
	for s: float in [-1.0, 1.0]:
		Props.block(c, Vector3(s * 0.8 - 0.04 * s, 0.05, -1.3), Vector3(s * 0.8, 0.45, 1.3), "planks")
	Props.cyl(c, Vector3(-0.95, -0.1, 0.4), 0.5, 0.08, "furniture", Vector3(0, 0, 90))
	Props.cyl(c, Vector3(-0.95, -0.1, 0.4), 0.12, 0.12, "iron", Vector3(0, 0, 90))
	Props.obox(g, Vector3(0.3, 0.12, -2.4), Vector3(0.08, 0.08, 1.9), "beam", Vector3(4, 25, 0))   # the shafts
	Props.obox(g, Vector3(-0.3, 0.1, -2.3), Vector3(0.08, 0.08, 1.9), "beam", Vector3(-3, 18, 0))
	Props.cyl(g, Vector3(2.4, 0.06, 1.5), 0.5, 0.08, "furniture", Vector3(0, 30, 0))                # the wheel that came off
	for i: int in 5:
		Props.sack(g, Vector3(1.0 + i * 0.35, 0.0, -0.6 + float(i % 2) * 0.5), 20.0 * i, 0.8)
	Props.crate(g, Vector3(1.6, 0, 0.7), 0.5, 35.0)
	Props.ball(g, Vector3(-0.2, 0.0, 0.0), Vector3(2.4, 0.5, 3.2), "snow")


## Suitcases dropped along the verge by people on the road: closed ones, one burst open with clothes, a bundle.
static func suitcases(parent: Node3D, center: Vector3, seed_v: int, count: int = 6) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var leathers: Array = ["paint:#3d2617", "paint:#4c3020", "paint:#2a2421", "paint:#55402a", "paint:#2f3326"]
	for i: int in count:
		var p: Vector3 = center + Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-1.8, 1.8))
		var g: Node3D = Props.group(parent, "Suitcase", p, rng.randf_range(0, 360))
		var w: float = rng.randf_range(0.5, 0.75)
		var key: String = leathers[rng.randi() % leathers.size()]
		var lying: bool = rng.randf() < 0.7
		if lying:
			Props.block(g, Vector3(-w * 0.5, 0, -0.22), Vector3(w * 0.5, 0.17, 0.22), key)
			Props.block(g, Vector3(-0.08, 0.17, -0.24), Vector3(0.08, 0.2, -0.2), "brass")
			Props.block(g, Vector3(-w * 0.5 - 0.01, 0.16, -0.23), Vector3(w * 0.5 + 0.01, 0.2, 0.23), "snow", false)
		else:
			g.rotation.x = deg_to_rad(rng.randf_range(-15, 15))
			Props.block(g, Vector3(-w * 0.5, 0, -0.09), Vector3(w * 0.5, 0.42, 0.09), key)
			Props.block(g, Vector3(-0.07, 0.42, -0.02), Vector3(0.07, 0.47, 0.02), "iron")
		if i == 1:   # burst open: the lid thrown back, clothes in the snow
			var lid: Node3D = Props.group(g, "Lid", Vector3(0, 0.17, 0.22), 0.0)
			lid.rotation.x = deg_to_rad(-120)
			Props.block(lid, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0.05, 0.44), key)
			for k: int in 4:
				Props.obox(g, Vector3(rng.randf_range(-0.6, 0.9), 0.04, rng.randf_range(0.2, 1.1)), Vector3(rng.randf_range(0.3, 0.6), 0.04, rng.randf_range(0.2, 0.4)),
					["linen", "cloth_red", "cloth_green", "paint:#2b3446"][k], Vector3(0, rng.randf_range(0, 180), rng.randf_range(-8, 8)))
	Props.ball(parent, center + Vector3(2.2, 0.15, 1.4), Vector3(0.7, 0.45, 0.6), "cloth_green")   # a bundle tied in a blanket


## The signpost knocked flat at the edge of the road, its arms pointing at the sky and into the snow.
static func fallen_signpost(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "FallenSignpost", pos, yaw)
	var lay: Node3D = Props.group(g, "Post", Vector3(0, 0.12, 0), 0.0)
	lay.rotation.z = deg_to_rad(86.0)
	Props.signpost(lay, Vector3.ZERO, [["HIRSCHFELDE  4 km", 90.0], ["SANKT ANNA  3 km", 200.0], ["KALTENBRUNN  11 km", -30.0]])
	Props.cyl(g, Vector3(0.0, 0.15, 0), 0.09, 0.3, "beam")                                        # the snapped stump
	Props.ball(g, Vector3(-1.2, 0.0, 0.0), Vector3(2.6, 0.35, 0.9), "snow")


## A telephone pole: post, crossarm, four insulators. Returns the insulator tips (wire anchors).
static func pole(parent: Node3D, base: Vector3, yaw: float, lean: Vector2, h: float = 7.0) -> Array[Vector3]:
	var g: Node3D = Props.group(parent, "TelePole", base, yaw)
	g.rotation.x = deg_to_rad(lean.x)
	g.rotation.z = deg_to_rad(lean.y)
	Props.cyl(g, Vector3(0, h * 0.5, 0), 0.12, h, "beam")
	Props.block(g, Vector3(-0.85, h - 0.6, -0.06), Vector3(0.85, h - 0.48, 0.06), "beam")
	var tips: Array[Vector3] = []
	for x: float in [-0.75, -0.3, 0.3, 0.75]:
		Props.cyl(g, Vector3(x, h - 0.4, 0), 0.03, 0.12, "stein")
		tips.append(g.transform * Vector3(x, h - 0.34, 0))
	return tips


## A sagging wire between two anchors as a few thin boxes (batched later).
static func wire(parent: Node3D, a: Vector3, b: Vector3, sag: float, segs: int = 6) -> void:
	var prev: Vector3 = a
	for i: int in segs:
		var t: float = float(i + 1) / float(segs)
		var p: Vector3 = a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var d: Vector3 = p - prev
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = Props.unit_box()
		mi.material_override = Mats.get_mat("iron")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT) * Basis.from_scale(Vector3(0.02, 0.02, d.length() + 0.02)), (prev + p) * 0.5)
		parent.add_child(mi)
		prev = p


## The small stone bridge carrying the north road over the frozen stream: two abutments, a segmental arch,
## the deck and parapets with snow on them.
static func stone_bridge(parent: Node3D, pos: Vector3, yaw: float, span: float = 7.0, width: float = 4.6) -> void:
	var g: Node3D = Props.group(parent, "StoneBridge", pos, yaw)
	var hw: float = width * 0.5
	var hs: float = span * 0.5
	for s: float in [-1.0, 1.0]:
		Props.block(g, Vector3(-hw - 0.2, -1.8, s * hs - 0.6), Vector3(hw + 0.2, 0.55, s * hs + 0.6), "stone")   # abutments
	var segs: int = 9
	var prev: Vector3 = Vector3(0, -1.6, -hs)
	for i: int in segs:
		var t: float = float(i + 1) / float(segs)
		var p: Vector3 = Vector3(0, -1.6 + 1.9 * sin(t * PI), lerpf(-hs, hs, t))
		var mid: Vector3 = (prev + p) * 0.5
		var ang: float = rad_to_deg(atan2(p.y - prev.y, p.z - prev.z))
		Props.obox(g, mid, Vector3(width + 0.2, 0.55, prev.distance_to(p) + 0.06), "stone", Vector3(-ang, 0, 0))
		prev = p
	Props.block(g, Vector3(-hw, 0.3, -hs - 0.6), Vector3(hw, 0.6, hs + 0.6), "stone")                       # deck
	for s2: float in [-1.0, 1.0]:
		Props.block(g, Vector3(s2 * hw - 0.25, 0.6, -hs - 0.8), Vector3(s2 * hw + 0.25, 1.35, hs + 0.8), "stone")   # parapets
		Props.block(g, Vector3(s2 * hw - 0.3, 1.35, -hs - 0.85), Vector3(s2 * hw + 0.3, 1.5, hs + 0.85), "snow", false)
	Props.block(g, Vector3(-hw + 0.25, 0.6, -hs - 0.6), Vector3(hw - 0.25, 0.68, hs + 0.6), "snow_trodden", false)


## The farmhouse on the rise to the north-west: house and barn under snowy roofs, a chimney, dark windows and
## the one that is still lit. Returns the lit window's glow node (MapAmbience puts it out at round 8).
static func farmhouse(parent: Node3D, pos: Vector3, yaw: float, far_mat: Material) -> Node3D:
	var g: Node3D = Props.group(parent, "Farmhouse", pos, yaw)
	_far_box(g, Vector3(-5.0, -1.0, -3.5), Vector3(5.0, 4.2, 3.5), far_mat)       # house
	_far_roof(g, Vector3(-5.4, 4.2, -3.9), Vector3(5.4, 4.2, 3.9), 3.0, far_mat)
	_far_box(g, Vector3(2.4, 5.0, -1.0), Vector3(3.2, 8.2, -0.2), far_mat)        # chimney
	_far_box(g, Vector3(6.0, -1.0, -4.5), Vector3(16.0, 5.0, 4.0), far_mat)       # barn
	_far_roof(g, Vector3(5.6, 5.0, -4.9), Vector3(16.4, 5.0, 4.4), 3.6, far_mat)
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.012, 0.016)
	dark.disable_fog = true
	for wx: float in [-3.6, -1.2, 3.4]:
		var w: MeshInstance3D = Props.block(g, Vector3(wx - 0.45, 1.2, 3.5), Vector3(wx + 0.45, 2.4, 3.56), "char", false)
		w.material_override = dark
	# the lit window: warm glass, a soft halo that carries through the haze
	var lit: Node3D = Node3D.new()
	lit.name = "LitWindow"
	lit.position = Vector3(1.2, 1.8, 3.6)
	g.add_child(lit)
	var glass: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.9, 1.15)
	glass.mesh = q
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.62, 0.28)
	gm.disable_fog = true
	glass.material_override = gm
	lit.add_child(glass)
	lit.add_child(glow_sprite(Vector3(0, 0, 0.3), 7.0, Color(1.0, 0.55, 0.22), 0.55))
	for k: int in 2:   # the glazing bars
		Props.block(lit, Vector3(-0.46, -0.03 + 0.0 * k, 0.01), Vector3(0.46, 0.03, 0.03), "char", false).material_override = dark
	Props.block(lit, Vector3(-0.03, -0.6, 0.01), Vector3(0.03, 0.6, 0.03), "char", false).material_override = dark
	return lit


## The church on the far hill: nave, a tower with a Silesian onion dome and a cross, all in the far material.
static func church(parent: Node3D, pos: Vector3, yaw: float, far_mat: Material) -> Node3D:
	var g: Node3D = Props.group(parent, "Church", pos, yaw)
	_far_box(g, Vector3(-4.0, -2.0, -2.0), Vector3(14.0, 9.0, 8.0), far_mat)
	_far_roof(g, Vector3(-4.4, 9.0, -2.4), Vector3(14.4, 9.0, 8.4), 5.0, far_mat)
	_far_box(g, Vector3(-9.5, -2.0, -0.5), Vector3(-3.5, 21.0, 5.5), far_mat)       # the tower
	_far_box(g, Vector3(-9.9, 21.0, -0.9), Vector3(-3.1, 22.0, 5.9), far_mat)
	var b1: MeshInstance3D = Props.ball(g, Vector3(-6.5, 24.4, 2.5), Vector3(5.6, 5.4, 5.6), "char")   # the onion
	b1.material_override = far_mat
	var b2: MeshInstance3D = Props.cyl(g, Vector3(-6.5, 27.6, 2.5), 0.8, 2.6, "char")                  # lantern
	b2.material_override = far_mat
	var b3: MeshInstance3D = Props.ball(g, Vector3(-6.5, 29.6, 2.5), Vector3(1.9, 2.6, 1.9), "char")
	b3.material_override = far_mat
	_far_box(g, Vector3(-6.65, 30.6, 2.35), Vector3(-6.35, 34.0, 2.65), far_mat)     # the cross
	_far_box(g, Vector3(-7.6, 32.6, 2.35), Vector3(-5.4, 32.9, 2.65), far_mat)
	return g


static func _far_box(parent: Node3D, a: Vector3, b: Vector3, far_mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = Props.block(parent, a, b, "char")
	mi.material_override = far_mat
	return mi


static func _far_roof(parent: Node3D, lo: Vector3, hi: Vector3, rise: float, far_mat: Material) -> void:
	var c: Vector3 = (lo + hi) * 0.5
	var mi: MeshInstance3D = Props.prism(parent, Vector3(c.x, lo.y + rise * 0.5, c.z), Vector3(hi.z - lo.z, rise, hi.x - lo.x), "char", Vector3(0, 90, 0))
	mi.material_override = far_mat


## An additive glow billboard (the farm window's halo, the burning town's fires, flares, the crash glow).
static func glow_sprite(pos: Vector3, size: float, color: Color, energy: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Glow"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = glow_material(color, energy)
	return mi


static func glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	m.no_depth_test = false
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var gr: Gradient = Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.75, 0.75, 0.75, 1), Color(0.18, 0.18, 0.18, 1), Color(0, 0, 0, 1)])
	tex.gradient = gr
	m.albedo_texture = tex
	return m


## Icicles hanging from an eave line a -> b (a MultiMesh of thin cones; static).
static func icicles(parent: Node3D, a: Vector3, b: Vector3, seed_v: int, spacing: float = 0.22) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	var count: int = int(a.distance_to(b) / spacing)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var xf: Array[Transform3D] = []
	for i: int in count:
		if rng.randf() < 0.35:
			continue
		var l: float = rng.randf_range(0.08, 0.55) * (1.0 if rng.randf() < 0.85 else 1.8)
		var r: float = rng.randf_range(0.025, 0.05)
		var p: Vector3 = a.lerp(b, (float(i) + rng.randf_range(0.2, 0.8)) / float(count))
		xf.append(Transform3D(Basis.from_scale(Vector3(r * 2.0, l, r * 2.0)), p - Vector3(0, l * 0.5, 0)))
	mm.instance_count = xf.size()
	for i: int in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "Icicles"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.8, 0.92, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.6
	mmi.material_override = m
	parent.add_child(mmi)


## The transport's open cockpit: the pilot's seat (empty, straps hanging loose), the control yoke, the shattered
## canopy frame. In the wreck's local frame (see gen_map00 _dress_wreck).
static func empty_cockpit(w: Node3D) -> void:
	var c: Node3D = Props.group(w, "Cockpit", Vector3(-0.45, 1.85, -5.6), 0.0)
	Props.block(c, Vector3(-0.28, 0.0, -0.25), Vector3(0.28, 0.1, 0.25), "rust")            # seat pan
	Props.obox(c, Vector3(0, 0.42, 0.24), Vector3(0.56, 0.8, 0.08), "paint:#3b3a2c", Vector3(-12, 0, 0))   # seat back
	Props.obox(c, Vector3(0.0, 0.62, 0.2), Vector3(0.44, 0.38, 0.05), "paint:#4a3a26", Vector3(-12, 0, 0))   # the leather pad
	for sx: float in [-0.16, 0.16]:   # harness straps hanging open over the pan
		Props.obox(c, Vector3(sx, 0.45, 0.12), Vector3(0.06, 0.65, 0.012), "paint:#6a6250", Vector3(-30, 0, sx * 40.0))
	Props.obox(c, Vector3(0.0, 0.08, -0.3), Vector3(0.05, 0.02, 0.5), "paint:#6a6250", Vector3(0, 30, 0))
	Props.cyl(c, Vector3(0, 0.55, -0.55), 0.03, 0.7, "iron", Vector3(-20, 0, 0))            # control column
	Props.obox(c, Vector3(0, 0.88, -0.66), Vector3(0.4, 0.05, 0.05), "iron")                # the yoke
	for k: int in 3:                                                                          # canopy frame, glass gone
		Props.obox(c, Vector3(-0.5 + k * 0.5, 0.95, -0.85), Vector3(0.05, 0.9, 0.05), "rust", Vector3(28, 0, k * 6.0 - 6.0))
	Props.block(c, Vector3(-0.75, 1.3, -0.95), Vector3(0.75, 1.36, -0.85), "rust")


## Cargo thrown out of the hold: crates with stencils, a smashed one with ration boxes, a jerrycan, a canister.
static func scattered_cargo(parent: Node3D, center: Vector3, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in 7:
		var p: Vector3 = center + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-5, 6))
		var s: float = rng.randf_range(0.45, 0.8)
		Props.crate(parent, p, s, rng.randf_range(0, 360), "U.S." if i % 3 == 0 else "")
		if rng.randf() < 0.5:
			Props.block(parent, p + Vector3(-s * 0.5, s, -s * 0.5), p + Vector3(s * 0.5, s + 0.06, s * 0.5), "snow", false)
	# a smashed crate, its ration boxes in the snow
	var sm: Vector3 = center + Vector3(3.5, 0, -3.0)
	for k: int in 4:
		Props.obox(parent, sm + Vector3(rng.randf_range(-0.6, 0.6), 0.04, rng.randf_range(-0.6, 0.6)), Vector3(0.7, 0.04, 0.12), "planks",
			Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 180), rng.randf_range(-15, 15)))
	for k2: int in 6:
		Props.obox(parent, sm + Vector3(rng.randf_range(-1.2, 1.2), 0.06, rng.randf_range(-1.2, 1.2)), Vector3(0.18, 0.1, 0.12), "paint:#6b6447",
			Vector3(0, rng.randf_range(0, 180), 0))
	Props.obox(parent, center + Vector3(-4.0, 0.22, 4.2), Vector3(0.18, 0.45, 0.34), "paint:#3e4a2c", Vector3(0, 30, 75))    # jerrycan, on its side
	Props.cyl(parent, center + Vector3(5.5, 0.25, 3.5), 0.22, 1.5, "paint:#4b5333", Vector3(0, 60, 90))                   # supply canister


## A parachute caught in a dead tree: the canopy draped over the crown, torn, the shroud lines hanging down to a
## supply crate that turns slowly in the wind (returned so MapAmbience can sway it).
static func parachute_tree(parent: Node3D, pos: Vector3, seed_v: int) -> Node3D:
	Props.dead_tree(parent, pos, seed_v, 8.0)
	var g: Node3D = Props.group(parent, "Parachute", pos + Vector3(0, 6.6, 0), 30.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for k: int in 7:   # the canopy: squashed shells draped at angles, one torn panel hanging
		var a: float = TAU * float(k) / 7.0
		var b: MeshInstance3D = Props.ball(g, Vector3(cos(a) * 1.2, rng.randf_range(-0.4, 0.3), sin(a) * 1.2), Vector3(2.4, 0.5, 1.6), "linen")
		b.rotation = Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.6, 0.6))
	Props.obox(g, Vector3(1.9, -1.4, 0.4), Vector3(0.9, 2.4, 0.03), "linen", Vector3(8, 40, 12))
	var hang: Node3D = Props.group(g, "Load", Vector3(0.2, -0.6, 0.0), 0.0)
	for k2: int in 5:
		var top: Vector3 = Vector3(cos(TAU * k2 / 5.0) * 1.4, 0.0, sin(TAU * k2 / 5.0) * 1.4)
		Props.strut(hang, top, Vector3(0, -3.6, 0), 0.012, "linen")
	Props.crate(hang, Vector3(0, -4.15, 0), 0.55, 0.0, "U.S.")
	return hang
