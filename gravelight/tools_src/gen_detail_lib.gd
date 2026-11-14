class_name GenDetail
extends RefCounted
## The shared detail vocabulary for the map generators (UPDATE 09 §5, docs/MAPS_3_4_REBUILD.md §2.2, DECISIONS
## T-146). Written for Fernflug Act I (gen_map04a) and meant for every rebuilt map: corrugated iron, I-beams and
## trusses (sawtooth roofs), riveted plate strips, pipes with flanges and valves, cable trays, rails and sleepers,
## chain-link and railings, crane gantries, form-board concrete (trim + board lines), windows with mullions, broken
## panes, curtains and a lit silhouette, doors with frames and hardware, stairs with treads and stringers, catwalk
## grating, posters and enamel signs, chalk marks (Jakub's "three strokes and a hook", CANON §6.4), puddles, rust
## streaks, frost, soot, snow and sand drifts, camouflage netting, ground fog that reads in Compatibility, and the
## flying-wing shell mesh.
##
## Rules every function keeps:
##  - static and pure: it only adds nodes under the `parent` it is given (and returns the root of what it built);
##    no globals, no scene lookups. Positions are in the parent's space; `yaw` in degrees.
##  - decorative: no collision, ever (colliders are the generator's job; the navmesh never sees these).
##  - cheap: boxes, cylinders and quads share Props' unit meshes and Mats' cached materials, so the generators'
##    static batching (`merge_static_meshes`, per material and 22 m cell) folds them into a handful of draw calls;
##    small repeated pieces (rivets, sleepers, weathering cards, chain-link panels) go into one BakedMultiMesh per
##    kind under the parent (`instance()`), which the batching leaves alone. Thin trim casts no shadow.
##  - material keys are Mats keys (Mats.get_mat: the CC0 library first, then the procedural set).
## Frames: a wall item (window, door, poster, sign, chalk on a wall) has local -Z pointing OUT of the wall toward
## the viewer unless the function says otherwise; `pos` is on the wall's face.

const CARD_SHADER: String = "res://gravelight/world/shaders/detail_card.gdshader"
const CUTOUT_SHADER: String = "res://gravelight/world/shaders/cutout_mesh.gdshader"
const FOG_SHADER: String = "res://gravelight/world/shaders/fog_card.gdshader"
const CARD_KINDS: Dictionary = {"rust": 0, "frost": 1, "soot": 2, "water": 3, "chalk": 4}
const CARD_TINTS: Dictionary = {
	"rust": Color(0.36, 0.17, 0.08, 0.75), "frost": Color(0.86, 0.9, 0.96, 0.7), "soot": Color(0.04, 0.035, 0.03, 0.85),
	"water": Color(0.05, 0.06, 0.06, 0.5), "chalk": Color(0.9, 0.9, 0.86, 0.45),
}

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


# ================================================================== small helpers

## A basis whose +Z runs from a to b and whose +Y is as close to `up` as it can be.
static func frame_along(a: Vector3, b: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var fwd: Vector3 = (b - a).normalized()
	if fwd == Vector3.ZERO:
		return Basis.IDENTITY
	var u: Vector3 = up if absf(fwd.dot(up.normalized())) < 0.98 else (Vector3.RIGHT if absf(fwd.x) < 0.9 else Vector3.FORWARD)
	var side: Vector3 = u.cross(fwd).normalized()
	return Basis(side, fwd.cross(side).normalized(), fwd)


## A Node3D group positioned on a basis (the frame the pieces below build in).
static func _group(parent: Node3D, n: String, xf: Transform3D) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	g.transform = xf
	parent.add_child(g)
	return g


static func _ns(mi: GeometryInstance3D) -> GeometryInstance3D:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## One BakedMultiMesh per `id` under `parent` (created on first use), and one more instance in it. `xf` is in the
## parent's space. The batching never merges these; each id is one draw call (two with shadows).
static func instance(parent: Node3D, id: String, mesh: Mesh, mat: Material, xf: Transform3D, shadow: bool = false) -> BakedMultiMesh:
	var n: String = "MM_" + id
	var mmi: BakedMultiMesh = parent.get_node_or_null(NodePath(n)) as BakedMultiMesh
	if mmi == null:
		mmi = Props.BAKED_MM.new() as BakedMultiMesh
		mmi.name = n
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("keep", true)
		parent.add_child(mmi)
	mmi.transforms.append(xf)
	return mmi


## Fills every BakedMultiMesh under `root` from its stored transforms (they fill themselves when the scene loads;
## call this to see them in a tool run or a test).
static func fill_instances(root: Node) -> int:
	var count: int = 0
	for n: Node in root.find_children("MM_*", "MultiMeshInstance3D", true, false):
		if n is BakedMultiMesh:
			(n as BakedMultiMesh).fill()
			count += 1
	return count


static func _quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


static func _plane_mesh(cells_x: int, cells_z: int) -> PlaneMesh:
	var k: String = "plane_%d_%d" % [cells_x, cells_z]
	if not _meshes.has(k):
		var p: PlaneMesh = PlaneMesh.new()
		p.size = Vector2.ONE
		p.subdivide_width = maxi(0, cells_x - 1)
		p.subdivide_depth = maxi(0, cells_z - 1)
		_meshes[k] = p
	return _meshes[k]


## The weathering card material for a kind ("rust", "frost", "soot", "water", "chalk").
static func card_mat(kind: String) -> ShaderMaterial:
	var k: String = "card_" + kind
	if not _mats.has(k):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(CARD_SHADER) as Shader
		m.set_shader_parameter("kind", int(CARD_KINDS.get(kind, 0)))
		m.set_shader_parameter("tint", CARD_TINTS.get(kind, Color(0.3, 0.2, 0.1, 0.7)))
		m.resource_name = k
		_mats[k] = m
	return _mats[k]


## A cut-out material: "chainlink", "netting" (sag in metres between supports `step` apart) or "broken_glass".
static func cutout_mat(kind: String, sag: float = 0.0, step: float = 6.0) -> ShaderMaterial:
	var k: String = "cut_%s_%.2f_%.1f" % [kind, sag, step]
	if not _mats.has(k):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(CUTOUT_SHADER) as Shader
		match kind:
			"netting":
				m.set_shader_parameter("kind", 1)
				m.set_shader_parameter("pitch", 0.22)
				m.set_shader_parameter("wire", 0.07)
				m.set_shader_parameter("scrim", 0.5)
				m.set_shader_parameter("color_a", Color(0.2, 0.23, 0.14))
				m.set_shader_parameter("color_b", Color(0.28, 0.3, 0.17))
				m.set_shader_parameter("color_c", Color(0.27, 0.22, 0.14))
				m.set_shader_parameter("metal", 0.0)
				m.set_shader_parameter("rough", 0.95)
				m.set_shader_parameter("sag_m", sag)
				m.set_shader_parameter("post_step", step)
			"broken_glass":
				m.set_shader_parameter("kind", 2)
				m.set_shader_parameter("color_a", Color(0.16, 0.19, 0.21))
				m.set_shader_parameter("color_c", Color(0.32, 0.34, 0.3))
				m.set_shader_parameter("metal", 0.1)
				m.set_shader_parameter("rough", 0.15)
			_:
				m.set_shader_parameter("kind", 0)
				m.set_shader_parameter("pitch", 0.07)
				m.set_shader_parameter("wire", 0.09)
				m.set_shader_parameter("color_a", Color(0.45, 0.46, 0.44))
		m.resource_name = k
		_mats[k] = m
	return _mats[k]


static func fog_mat(color: Color) -> ShaderMaterial:
	var k: String = "fog_%s" % color.to_html()
	if not _mats.has(k):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(FOG_SHADER) as Shader
		m.set_shader_parameter("color", color)
		m.resource_name = "fog_card"
		_mats[k] = m
	return _mats[k]


# ================================================================== structure

## A corrugated iron sheet (or a wall / roof of them) between two corners: one thin box in the corrugated material
## (the CC0 texture carries the ribs), with a rolled edge strip along its two long sides. Returns the sheet.
static func corrugated_sheet(parent: Node3D, a: Vector3, b: Vector3, key: String = "fl_corrugated", edge_key: String = "iron") -> MeshInstance3D:
	var sheet: MeshInstance3D = Props.block(parent, a, b, key)
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var sz: Vector3 = hi - lo
	# the edge strips run along the sheet's longest axis, at its two ends across the shortest-but-one
	var thin: int = 0 if sz.x <= sz.y and sz.x <= sz.z else (1 if sz.y <= sz.z else 2)
	var long_ax: int = (thin + 1) % 3 if sz[(thin + 1) % 3] >= sz[(thin + 2) % 3] else (thin + 2) % 3
	var cross_ax: int = 3 - thin - long_ax
	for e: float in [lo[cross_ax], hi[cross_ax]]:
		var ea: Vector3 = lo
		var eb: Vector3 = hi
		ea[cross_ax] = e - 0.03
		eb[cross_ax] = e + 0.03
		ea[thin] = lo[thin] - 0.015
		eb[thin] = hi[thin] + 0.015
		_ns(Props.block(parent, ea, eb, edge_key))
	return sheet


## A rolled steel I-beam from a to b: two flanges and a web. h = depth, w = flange width. Returns its group.
static func i_beam(parent: Node3D, a: Vector3, b: Vector3, h: float = 0.4, w: float = 0.2, key: String = "steel", up: Vector3 = Vector3.UP,
		shadows: bool = true) -> Node3D:
	var length: float = a.distance_to(b)
	var g: Node3D = _group(parent, "IBeam", Transform3D(frame_along(a, b, up), a))
	var tf: float = maxf(0.015, h * 0.07)
	var tw: float = maxf(0.012, w * 0.06)
	for s: float in [-1.0, 1.0]:
		var f: MeshInstance3D = Props.obox(g, Vector3(0, s * (h * 0.5 - tf * 0.5), length * 0.5), Vector3(w, tf, length), key)
		if not shadows:
			_ns(f)
	var web: MeshInstance3D = Props.obox(g, Vector3(0, 0, length * 0.5), Vector3(tw, h - tf * 2.0, length), key)
	if not shadows:
		_ns(web)
	return g


## A flat Warren truss in the vertical plane through a and b: bottom chord a→b, top chord `depth` above it,
## verticals and alternating diagonals every `panel` metres. Returns its group.
static func truss(parent: Node3D, a: Vector3, b: Vector3, depth: float, key: String = "steel", panel: float = 2.5,
		chord: float = 0.18, web: float = 0.09, shadows: bool = false) -> Node3D:
	var length: float = a.distance_to(b)
	var g: Node3D = _group(parent, "Truss", Transform3D(frame_along(a, b), a))
	var n: int = maxi(1, int(round(length / panel)))
	var step: float = length / float(n)
	for y: float in [0.0, depth]:
		var c: MeshInstance3D = Props.obox(g, Vector3(0, y, length * 0.5), Vector3(chord * 0.8, chord, length), key)
		if not shadows:
			_ns(c)
	for i: int in n + 1:
		var z: float = float(i) * step
		var v: MeshInstance3D = Props.obox(g, Vector3(0, depth * 0.5, z), Vector3(web, depth, web), key)
		if not shadows:
			_ns(v)
		if i < n:
			var d0: Vector3 = Vector3(0, 0.0 if i % 2 == 0 else depth, z)
			var d1: Vector3 = Vector3(0, depth if i % 2 == 0 else 0.0, z + step)
			var d: MeshInstance3D = Props.strut(g, d0, d1, web, key)
			if not shadows:
				_ns(d)
	return g


## A sawtooth roof over the rectangle lo..hi (lo.y = the eaves): `teeth` teeth stepping along +Z, each a sloped
## roof panel rising `rise` toward +Z and a vertical glazed north light (mullions every 1.5 m), a truss under each
## ridge and a valley gutter. The glazing faces +Z. Returns its group.
static func sawtooth_roof(parent: Node3D, lo: Vector3, hi: Vector3, teeth: int, rise: float, roof_key: String = "fl_corrugated",
		glass_key: String = "window_dark", frame_key: String = "steel", truss_key: String = "steel") -> Node3D:
	var g: Node3D = _group(parent, "SawtoothRoof", Transform3D.IDENTITY)
	var depth: float = (hi.z - lo.z) / float(maxi(1, teeth))
	var w: float = hi.x - lo.x
	var cx: float = (lo.x + hi.x) * 0.5
	var slope_len: float = sqrt(depth * depth + rise * rise)
	var ang: float = rad_to_deg(atan2(rise, depth))
	for i: int in teeth:
		var z0: float = lo.z + float(i) * depth
		var z1: float = z0 + depth
		Props.obox(g, Vector3(cx, lo.y + rise * 0.5 + 0.05, (z0 + z1) * 0.5), Vector3(w, 0.08, slope_len), roof_key, Vector3(-ang, 0, 0))
		# the north light: glass with mullions, a sill and a head
		_ns(Props.block(g, Vector3(lo.x, lo.y + 0.25, z1 - 0.04), Vector3(hi.x, lo.y + rise - 0.1, z1 + 0.02), glass_key))
		Props.block(g, Vector3(lo.x, lo.y, z1 - 0.12), Vector3(hi.x, lo.y + 0.25, z1 + 0.12), frame_key)
		Props.block(g, Vector3(lo.x, lo.y + rise - 0.12, z1 - 0.1), Vector3(hi.x, lo.y + rise + 0.1, z1 + 0.1), frame_key)
		var m: int = maxi(1, int(w / 1.5))
		for k: int in m + 1:
			var x: float = lo.x + w * float(k) / float(m)
			_ns(Props.block(g, Vector3(x - 0.03, lo.y + 0.25, z1 - 0.06), Vector3(x + 0.03, lo.y + rise - 0.1, z1 + 0.04), frame_key))
		# the valley gutter and a truss along the tooth (in its slope) every 6 m across
		Props.block(g, Vector3(lo.x, lo.y - 0.18, z0 - 0.15), Vector3(hi.x, lo.y + 0.02, z0 + 0.15), "iron")
		var tn: int = maxi(1, int(round(w / 6.0)))
		for t: int in tn + 1:
			var tx: float = lo.x + w * float(t) / float(tn)
			_ns(Props.strut(g, Vector3(tx, lo.y, z0), Vector3(tx, lo.y + rise, z1), 0.14, truss_key))
			_ns(Props.strut(g, Vector3(tx, lo.y, z0), Vector3(tx, lo.y, z1), 0.12, truss_key))
			_ns(Props.strut(g, Vector3(tx, lo.y, z0 + depth * 0.5), Vector3(tx, lo.y + rise * 0.5, z0 + depth * 0.5), 0.08, truss_key))
			_ns(Props.strut(g, Vector3(tx, lo.y, z0 + depth * 0.5), Vector3(tx, lo.y + rise, z1), 0.07, truss_key))
	return g


## A flat steel plate strip from a to b (width `w`, laid on a face whose outward normal is `normal`) with a row of
## rivet heads every `spacing` m (rivets as one MultiMesh per material under the parent).
static func rivet_strip(parent: Node3D, a: Vector3, b: Vector3, normal: Vector3 = Vector3.BACK, w: float = 0.09, spacing: float = 0.12,
		key: String = "steel") -> MeshInstance3D:
	var length: float = a.distance_to(b)
	var bs: Basis = frame_along(a, b, normal)
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.mesh = Props.unit_box()
	plate.material_override = Mats.get_mat(key)
	plate.transform = Transform3D(bs.scaled_local(Vector3(w, 0.008, length)), (a + b) * 0.5 + normal.normalized() * 0.004)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(plate)
	var n: int = maxi(1, int(length / spacing))
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n)) + normal.normalized() * 0.012
		for s: float in [-0.28, 0.28]:
			instance(parent, "rivet_" + key, Props.unit_box(), Mats.get_mat(key), Transform3D(bs.scaled_local(Vector3(0.022, 0.016, 0.022)), p + bs.x * w * s))
	return plate


## A pipe run through `points` (radius r): straight segments, an elbow ball at every bend, a bolted flange at every
## joint and every `flange_every` metres, and a valve wheel on segment `valve_seg` (-1 = none). Returns its group.
static func pipe_run(parent: Node3D, points: PackedVector3Array, r: float = 0.06, key: String = "iron", flange_every: float = 3.0,
		valve_seg: int = -1, valve_key: String = "red_paint") -> Node3D:
	var g: Node3D = _group(parent, "PipeRun", Transform3D.IDENTITY)
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		Props.strut(g, a, b, r * 2.0, key, true)
		var d: Vector3 = (b - a).normalized()
		var length: float = a.distance_to(b)
		var nf: int = maxi(1, int(length / maxf(0.5, flange_every)))
		for k: int in nf + 1:
			var p: Vector3 = a.lerp(b, float(k) / float(nf))
			_ns(Props.strut(g, p - d * 0.025, p + d * 0.025, (r + 0.035) * 2.0, key, true))
		if i > 0:
			_ns(Props.ball(g, a, Vector3.ONE * r * 2.3, key))
		if i == valve_seg:
			var mid: Vector3 = (a + b) * 0.5
			_ns(Props.strut(g, mid - d * 0.08, mid + d * 0.08, r * 3.2, key, true))
			var up: Vector3 = Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
			var stem_top: Vector3 = mid + up * (r + 0.18)
			_ns(Props.strut(g, mid, stem_top, 0.025, "iron", true))
			# the hand wheel lies across its stem (Props.cyl's axis is Y: turn it when the stem is horizontal)
			Props.cyl(g, stem_top, 0.13, 0.02, valve_key, Vector3.ZERO if absf(up.y) > 0.5 else Vector3(0, 0, 90))
	return g


## A ladder-type cable tray from a to b, `w` wide, hung on its rungs, with `cables` black cables lying in it.
static func cable_tray(parent: Node3D, a: Vector3, b: Vector3, w: float = 0.3, key: String = "iron", cables: int = 3) -> Node3D:
	var length: float = a.distance_to(b)
	var g: Node3D = _group(parent, "CableTray", Transform3D(frame_along(a, b), a))
	for s: float in [-1.0, 1.0]:
		_ns(Props.obox(g, Vector3(s * w * 0.5, 0.04, length * 0.5), Vector3(0.02, 0.08, length), key))
	var n: int = maxi(1, int(length / 0.3))
	for i: int in n + 1:
		_ns(Props.obox(g, Vector3(0, 0.005, length * float(i) / float(n)), Vector3(w, 0.01, 0.025), key))
	for c: int in cables:
		var x: float = -w * 0.35 + w * 0.7 * float(c) / float(maxi(1, cables - 1))
		_ns(Props.cyl(g, Vector3(x, 0.03, length * 0.5), 0.018, length, "rubber", Vector3(90, 0, 0)))
	return g


## Standard-gauge track from a to b: two rails (head + foot), sleepers every `step` m as one MultiMesh, and a
## ballast bed. Returns its group (the sleepers' MultiMesh sits under the parent).
static func rails(parent: Node3D, a: Vector3, b: Vector3, gauge: float = 1.435, rail_key: String = "iron", sleeper_key: String = "beam",
		step: float = 0.65, ballast_key: String = "ballast") -> Node3D:
	var length: float = a.distance_to(b)
	var bs: Basis = frame_along(a, b)
	var g: Node3D = _group(parent, "Track", Transform3D(bs, a))
	Props.obox(g, Vector3(0, 0.06, length * 0.5), Vector3(gauge + 1.6, 0.12, length), ballast_key)
	for s: float in [-0.5, 0.5]:
		Props.obox(g, Vector3(s * gauge, 0.25, length * 0.5), Vector3(0.075, 0.05, length), rail_key)
		_ns(Props.obox(g, Vector3(s * gauge, 0.2, length * 0.5), Vector3(0.03, 0.06, length), rail_key))
		_ns(Props.obox(g, Vector3(s * gauge, 0.175, length * 0.5), Vector3(0.14, 0.012, length), rail_key))
	var n: int = maxi(1, int(length / step))
	var mat: Material = Mats.get_mat(sleeper_key)
	for i: int in n:
		var p: Vector3 = a + bs.z * ((float(i) + 0.5) * length / float(n)) + bs.y * 0.14
		instance(parent, "sleeper_" + sleeper_key, Props.unit_box(), mat, Transform3D(bs.scaled_local(Vector3(gauge + 1.1, 0.13, 0.24)), p), true)
	return g


## A chain-link fence from a to b, h high: posts every 2.5 m, a top rail, and the wire as cut-out panels (one
## MultiMesh). Returns the posts' group.
static func chain_link(parent: Node3D, a: Vector3, b: Vector3, h: float = 2.2, post_key: String = "iron", barbed: bool = false) -> Node3D:
	var length: float = a.distance_to(b)
	var bs: Basis = frame_along(a, b)
	var g: Node3D = _group(parent, "ChainLink", Transform3D(bs, a))
	var n: int = maxi(1, int(round(length / 2.5)))
	for i: int in n + 1:
		Props.obox(g, Vector3(0, h * 0.5, length * float(i) / float(n)), Vector3(0.06, h, 0.06), post_key)
	_ns(Props.cyl(g, Vector3(0, h - 0.05, length * 0.5), 0.025, length, post_key, Vector3(90, 0, 0)))
	if barbed:
		for k: int in 3:
			_ns(Props.cyl(g, Vector3(0.06 * float(k), h + 0.1 + 0.1 * float(k), length * 0.5), 0.006, length, "rust", Vector3(90, 0, 0)))
	# the panel quad faces +Z by default: turn it to face across the fence (local X)
	var pb: Basis = bs * Basis(Vector3.UP, PI * 0.5)
	instance(parent, "chainlink", _quad(), cutout_mat("chainlink"), Transform3D(pb.scaled_local(Vector3(length, h - 0.1, 1.0)), (a + b) * 0.5 + Vector3(0, (h - 0.1) * 0.5 + 0.02, 0)))
	return g


## A steel railing from a to b (posts, top rail, mid rail) with a toe board. Returns its group.
static func railing(parent: Node3D, a: Vector3, b: Vector3, h: float = 1.05, key: String = "iron", toe: bool = true) -> Node3D:
	var g: Node3D = _group(parent, "RailingD", Transform3D.IDENTITY)
	Props.railing(g, a, b, h, key)
	if toe:
		var length: float = a.distance_to(b)
		_ns(Props.obox(g, (a + b) * 0.5 + Vector3(0, 0.075, 0), Vector3(0.01, 0.15, length), key, Vector3(0, rad_to_deg(atan2((b - a).x, (b - a).z)), 0)))
	return g


## A travelling bridge crane: two box girders spanning x0..x1 at height y (the runway rails' top), end trucks,
## a trolley at `trolley_x` with its hook block hanging `hook_drop` metres, and an operator's cab under one end
## (`cab_end` -1 west / +1 east / 0 none). Returns its group (origin at the span's centre, rail height).
static func crane_gantry(parent: Node3D, x0: float, x1: float, z: float, y: float, key: String = "crane_yellow", trolley_x: float = 0.0,
		hook_drop: float = 4.0, cab_end: int = 1) -> Node3D:
	var cx: float = (x0 + x1) * 0.5
	var g: Node3D = _group(parent, "CraneGantry", Transform3D(Basis.IDENTITY, Vector3(cx, y, z)))
	var half: float = (x1 - x0) * 0.5
	for s: float in [-1.0, 1.0]:
		Props.block(g, Vector3(-half, 0.2, s * 0.9 - 0.3), Vector3(half, 1.4, s * 0.9 + 0.3), key)
		_ns(Props.block(g, Vector3(-half, 1.4, s * 0.9 - 0.35), Vector3(half, 1.45, s * 0.9 + 0.35), "steel"))
		Props.block(g, Vector3(s * half - 0.8, 0.0, -1.8), Vector3(s * half + 0.8, 0.9, 1.8), key)
		for w: float in [-1.2, 1.2]:
			_ns(Props.cyl(g, Vector3(s * half, 0.05, w), 0.25, 0.3, "iron", Vector3(0, 0, 90)))
	# diaphragm plates and the walkway rail along the south girder
	var n: int = maxi(2, int(half * 2.0 / 3.0))
	for i: int in n + 1:
		var x: float = -half + half * 2.0 * float(i) / float(n)
		_ns(Props.block(g, Vector3(x - 0.04, 0.25, -1.25), Vector3(x + 0.04, 1.35, -0.55), "steel"))
	Props.railing(g, Vector3(-half, 1.45, -1.25), Vector3(half, 1.45, -1.25), 1.0, "iron", 2.0)
	# the trolley, its drum, the hook block on two ropes
	var tx: float = clampf(trolley_x - cx, -half + 2.0, half - 2.0)
	Props.block(g, Vector3(tx - 1.4, 1.45, -1.3), Vector3(tx + 1.4, 2.3, 1.3), key)
	Props.cyl(g, Vector3(tx, 1.9, 0), 0.45, 1.6, "iron", Vector3(90, 0, 0))
	for rz: float in [-0.25, 0.25]:
		_ns(Props.strut(g, Vector3(tx, 1.5, rz), Vector3(tx, -hook_drop + 0.6, rz), 0.03, "iron", true))
	Props.block(g, Vector3(tx - 0.35, -hook_drop + 0.2, -0.3), Vector3(tx + 0.35, -hook_drop + 0.8, 0.3), key)
	_ns(Props.cyl(g, Vector3(tx, -hook_drop + 0.05, 0), 0.12, 0.4, "iron"))
	_ns(Props.cyl(g, Vector3(tx + 0.12, -hook_drop - 0.15, 0), 0.16, 0.06, "iron", Vector3(90, 0, 0)))
	if cab_end != 0:
		var ex: float = float(cab_end) * (half - 2.2)
		Props.block(g, Vector3(ex - 1.1, -2.4, -1.1), Vector3(ex + 1.1, 0.2, 1.1), key)
		_ns(Props.block(g, Vector3(ex - 1.12, -1.6, -1.12), Vector3(ex + 1.12, -0.3, 1.12), "window_dark"))
		for cxs: float in [-1.0, 1.0]:
			_ns(Props.block(g, Vector3(ex + cxs * 1.08 - 0.04, -1.6, -1.13), Vector3(ex + cxs * 1.08 + 0.04, -0.3, 1.13), key))
	return g


# ================================================================== surfaces and trim

## Form-board concrete on a wall face: the face plane is given by two corners lo..hi that differ in two axes and
## share the third (the wall's face coordinate); `out` is the outward normal (±X or ±Z). Adds proud board-joint
## lines every `board` m (thin strips) and a grid of tie-hole dots every 0.6 × 0.6 m (instanced). Returns nothing.
static func form_board(parent: Node3D, lo: Vector3, hi: Vector3, out: Vector3, board: float = 0.3, key: String = "fl_concrete",
		tie_holes: bool = true) -> void:
	var o: Vector3 = out.normalized()
	var along_x: bool = absf(o.z) > 0.5
	var face: float = lo.z if along_x else lo.x
	var a0: float = lo.x if along_x else lo.z
	var a1: float = hi.x if along_x else hi.z
	var y: float = lo.y + board
	while y < hi.y - 0.05:
		var p0: Vector3 = Vector3(a0, y - 0.012, face) if along_x else Vector3(face, y - 0.012, a0)
		var p1: Vector3 = Vector3(a1, y + 0.012, face + o.z * 0.012) if along_x else Vector3(face + o.x * 0.012, y + 0.012, a1)
		_ns(Props.block(parent, p0, p1, key))
		y += board
	if tie_holes:
		var mat: Material = Mats.get_mat("black_paint")
		var ty: float = lo.y + 0.45
		while ty < hi.y - 0.2:
			var t: float = a0 + 0.3
			while t < a1 - 0.2:
				var c: Vector3 = (Vector3(t, ty, face + o.z * 0.004) if along_x else Vector3(face + o.x * 0.004, ty, t))
				var bs: Basis = Basis.looking_at(-o, Vector3.UP)
				instance(parent, "tiehole", Props.unit_box(), mat, Transform3D(bs.scaled_local(Vector3(0.035, 0.035, 0.006)), c))
				t += 0.6
			ty += 0.6


## A trim strip (skirting, string course, cornice, coping) along a wall face from a to b (both on the face line at
## the strip's bottom), `h` tall and standing `depth` proud on the `out` side. Returns it.
static func trim(parent: Node3D, a: Vector3, b: Vector3, out: Vector3, h: float = 0.25, depth: float = 0.06, key: String = "stucco_trim",
		shadows: bool = false) -> MeshInstance3D:
	var o: Vector3 = out.normalized() * depth
	var lo: Vector3 = Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), a.y + h, maxf(a.z, b.z))
	if absf(o.x) > absf(o.z):
		hi.x = lo.x + o.x if o.x > 0.0 else hi.x
		lo.x = lo.x if o.x > 0.0 else lo.x + o.x
	else:
		hi.z = lo.z + o.z if o.z > 0.0 else hi.z
		lo.z = lo.z if o.z > 0.0 else lo.z + o.z
	var mi: MeshInstance3D = Props.block(parent, lo, hi, key)
	if not shadows:
		_ns(mi)
	return mi


## A window on a wall face, local +Z = INTO the building, -Z out toward the viewer; `pos` = the bottom centre of
## the opening on the wall's OUTER face. The opening is `w` × `h`. opts:
##   frame (Mats key, "beam"), sill_key ("stucco_trim"), mullions [cols, rows] ([2, 3]), glass ("window_dark"),
##   broken (0..1: share of panes punched out, the rest dirty glass), curtain ("" or a cloth key), lit (Color or
##   null: a warm glow card behind the glass), silhouette (bool: a dark figure on the glow, behind the curtain gap),
##   shutters (bool), snow (bool: a cap on the sill), frost (bool), seed (int), depth (reveal depth, 0.12),
##   blind (bool: a window painted onto a SOLID wall: the whole window stands proud of the face so the wall never
##   covers its reveal), open (bool: a real opening (a barricade window): frame and sill only, no glass, back or curtain).
## Returns its group.
static func window(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, opts: Dictionary = {}) -> Node3D:
	var bw: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var depth: float = float(opts.get("depth", 0.12))
	var blind: bool = bool(opts.get("blind", false))
	var is_open: bool = bool(opts.get("open", false))
	var g: Node3D = _group(parent, "Window", Transform3D(bw, pos + (bw * Vector3(0, 0, -(depth + 0.09)) if blind else Vector3.ZERO)))
	var fk: String = str(opts.get("frame", "beam"))
	var mull: Array = opts.get("mullions", [2, 3])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", int(absf(pos.x * 31.0 + pos.z * 17.0 + pos.y * 7.0))))
	var hw: float = w * 0.5
	# the reveal: the pane sits `depth` into the wall; a dark back so a solid wall reads as a window
	var lit: Variant = null if is_open else opts.get("lit", null)
	if not is_open:
		_ns(Props.block(g, Vector3(-hw, 0, depth + 0.02), Vector3(hw, h, depth + 0.04), "window_dark"))
	if lit is Color:
		var glow: StandardMaterial3D = _glow_mat(lit as Color)
		var gm: MeshInstance3D = Props.block(g, Vector3(-hw + 0.04, 0.04, depth + 0.012), Vector3(hw - 0.04, h - 0.04, depth + 0.018), "window_dark")
		gm.material_override = glow
		_ns(gm)
		if bool(opts.get("silhouette", false)):
			silhouette(g, Vector3(rng.randf_range(-hw * 0.3, hw * 0.3), maxf(0.0, h - 1.75) * 0.3 - 0.2, depth + 0.008), 180.0, minf(1.7, h * 1.05))
	# frame: jambs, head, mullions and transoms
	var fw: float = 0.07
	Props.block(g, Vector3(-hw - fw, -0.02, -0.04), Vector3(-hw, h + fw, depth), fk)
	Props.block(g, Vector3(hw, -0.02, -0.04), Vector3(hw + fw, h + fw, depth), fk)
	Props.block(g, Vector3(-hw - fw, h, -0.05), Vector3(hw + fw, h + fw + 0.04, depth), fk)
	var cols: int = 1 if is_open else maxi(1, int(mull[0]))
	var rows: int = 1 if is_open else maxi(1, int(mull[1]))
	for c: int in range(1, cols):
		var x: float = -hw + w * float(c) / float(cols)
		_ns(Props.block(g, Vector3(x - 0.025, 0, depth - 0.03), Vector3(x + 0.025, h, depth), fk))
	for r: int in range(1, rows):
		var y: float = h * float(r) / float(rows)
		_ns(Props.block(g, Vector3(-hw, y - 0.02, depth - 0.03), Vector3(hw, y + 0.02, depth), fk))
	# panes: dirty glass, some punched out (the dark back shows), some cracked (cut-out shard glass)
	var broken: float = float(opts.get("broken", 0.0))
	var gk: String = str(opts.get("glass", "glass"))
	for c2: int in (0 if is_open else cols):
		for r2: int in rows:
			var px0: float = -hw + w * float(c2) / float(cols)
			var py0: float = h * float(r2) / float(rows)
			var px1: float = px0 + w / float(cols)
			var py1: float = py0 + h / float(rows)
			var roll: float = rng.randf()
			if roll < broken * 0.6:
				continue
			var pane: MeshInstance3D = Props.block(g, Vector3(px0 + 0.02, py0 + 0.02, depth - 0.02), Vector3(px1 - 0.02, py1 - 0.02, depth - 0.012), gk)
			_ns(pane)
			if roll < broken:
				pane.material_override = cutout_mat("broken_glass")
	# sill: an outer sill board (and its snow cap), an inner one
	var sk: String = str(opts.get("sill_key", "stucco_trim"))
	_ns(Props.block(g, Vector3(-hw - 0.12, -0.06, -0.14), Vector3(hw + 0.12, 0.0, depth), sk))
	if bool(opts.get("snow", false)):
		_ns(Props.block(g, Vector3(-hw - 0.08, 0.0, -0.13), Vector3(hw + 0.08, 0.05, -0.01), "snow"))
	if bool(opts.get("frost", false)):
		instance(g, "frost_pane", _quad(), card_mat("frost"), Transform3D(Basis(Vector3.UP, PI).scaled_local(Vector3(w * 0.9, h * 0.6, 1.0)), Vector3(0, h * 0.3, depth - 0.025)))
	var ck: String = "" if is_open else str(opts.get("curtain", ""))
	if ck != "":
		var gap: float = rng.randf_range(0.15, 0.45) * w
		for s: float in [-1.0, 1.0]:
			var cw: float = (w - gap) * 0.5 + 0.1
			var cxc: float = s * (hw - cw * 0.5 + 0.06)
			Props.block(g, Vector3(cxc - cw * 0.5, -0.05, depth + 0.045), Vector3(cxc + cw * 0.5, h + 0.02, depth + 0.07), ck, false)
			for f: int in 3:
				var fx: float = cxc - cw * 0.35 + cw * 0.35 * float(f)
				_ns(Props.block(g, Vector3(fx - 0.02, -0.05, depth + 0.035), Vector3(fx + 0.02, h + 0.02, depth + 0.046), ck))
		_ns(Props.block(g, Vector3(-hw - 0.1, h + 0.02, depth + 0.04), Vector3(hw + 0.1, h + 0.05, depth + 0.075), "iron"))
	if bool(opts.get("shutters", false)):
		for s2: float in [-1.0, 1.0]:
			var sh: Node3D = Props.group(g, "Shutter", Vector3(s2 * (hw + fw + 0.02), 0, -0.06), s2 * 100.0)
			Props.block(sh, Vector3(-0.025, 0, 0), Vector3(0.025, h, -s2 * hw), str(opts.get("shutter_key", "shutter_green")))
	return g


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var k: String = "glow_%s" % c.to_html()
	if not _mats.has(k):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c * 0.4
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
		m.roughness = 1.0
		m.resource_name = k
		_mats[k] = m
	return _mats[k]


## A flat dark human silhouette (a person behind a curtain, a figure behind frosted office glass), `h` tall,
## local -Z toward the viewer. Never a face, never detail: civilians appear only like this (U09 rule).
static func silhouette(parent: Node3D, pos: Vector3, yaw: float, h: float = 1.7, key: String = "black_paint") -> Node3D:
	var g: Node3D = Props.group(parent, "Silhouette", pos, yaw)
	var s: float = h / 1.7
	_ns(Props.ball(g, Vector3(0, 1.56 * s, 0), Vector3(0.21, 0.25, 0.02) * s, key))
	_ns(Props.block(g, Vector3(-0.21 * s, 0.85 * s, -0.01), Vector3(0.21 * s, 1.42 * s, 0.01), key))
	_ns(Props.block(g, Vector3(-0.07 * s, 1.38 * s, -0.01), Vector3(0.07 * s, 1.46 * s, 0.01), key))
	for sx: float in [-1.0, 1.0]:
		_ns(Props.obox(g, Vector3(sx * 0.25 * s, 1.12 * s, 0), Vector3(0.08 * s, 0.56 * s, 0.02), key, Vector3(0, 0, sx * 8.0)))
		_ns(Props.block(g, Vector3(sx * 0.03 * s, 0.0, -0.01), Vector3(sx * 0.17 * s, 0.86 * s, 0.01), key))
	return g


## A door in a wall: frame (jambs, lintel, a step), a leaf (planks or steel) closed or swung open by `open_deg`
## about its left hinge, hinges and a handle. `pos` = the bottom centre of the opening on the wall's outer face,
## local -Z out. opts: frame ("beam"), leaf ("planks"), open_deg (0), depth (0.15), step (bool), sign (text, ""),
## steel (bool: riveted steel leaf with a kick plate), blind (bool: a door painted onto a SOLID wall, the whole piece
## stands proud of the face), leaf "" (frame only: round a gameplay door, which draws its own leaf). Returns its group.
static func door(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, opts: Dictionary = {}) -> Node3D:
	var bd: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var depth: float = float(opts.get("depth", 0.15))
	var g: Node3D = _group(parent, "DoorD", Transform3D(bd, pos + (bd * Vector3(0, 0, -(depth + 0.03)) if bool(opts.get("blind", false)) else Vector3.ZERO)))
	var fk: String = str(opts.get("frame", "beam"))
	var lk: String = str(opts.get("leaf", "planks"))
	var hw: float = w * 0.5
	Props.block(g, Vector3(-hw - 0.12, 0, -0.05), Vector3(-hw, h + 0.12, depth), fk)
	Props.block(g, Vector3(hw, 0, -0.05), Vector3(hw + 0.12, h + 0.12, depth), fk)
	Props.block(g, Vector3(-hw - 0.16, h, -0.07), Vector3(hw + 0.16, h + 0.2, depth), fk)
	if bool(opts.get("step", true)):
		_ns(Props.block(g, Vector3(-hw - 0.15, -0.02, -0.4), Vector3(hw + 0.15, 0.04, 0.0), "concrete"))
	var sign0: String = str(opts.get("sign", ""))
	if lk == "":
		if sign0 != "":
			enamel_sign(g, Vector3(0, h + 0.45, -0.06), 0.0, sign0, minf(w * 1.2, 1.6), 0.3)
		return g
	var hinge: Node3D = Props.group(g, "Leaf", Vector3(-hw + 0.02, 0, depth * 0.5), -float(opts.get("open_deg", 0.0)))
	var steel: bool = bool(opts.get("steel", false))
	Props.block(hinge, Vector3(0, 0.01, -0.025), Vector3(w - 0.04, h - 0.02, 0.025), lk)
	if steel:
		_ns(Props.block(hinge, Vector3(0.05, 0.02, -0.032), Vector3(w - 0.09, 0.3, -0.025), "iron"))
		for ry: float in [0.15, h * 0.5, h - 0.15]:
			_ns(Props.block(hinge, Vector3(0.04, ry - 0.02, -0.03), Vector3(w - 0.08, ry + 0.02, -0.025), "iron"))
	else:
		for bx: float in [0.25, 0.5, 0.75]:
			_ns(Props.block(hinge, Vector3((w - 0.04) * bx - 0.006, 0.02, -0.03), Vector3((w - 0.04) * bx + 0.006, h - 0.04, -0.025), "black_paint"))
		_ns(Props.obox(hinge, Vector3((w - 0.04) * 0.5, h * 0.5, -0.032), Vector3(0.06, h * 1.05, 0.02), lk, Vector3(0, 0, rad_to_deg(atan2(w, h)))))
	for hy: float in [0.3, h - 0.35]:
		_ns(Props.block(hinge, Vector3(-0.02, hy - 0.03, -0.035), Vector3(0.3, hy + 0.03, -0.025), "black_paint"))
	_ns(Props.cyl(hinge, Vector3(w - 0.16, 1.02, -0.06), 0.03, 0.07, "brass", Vector3(90, 0, 0)))
	_ns(Props.block(hinge, Vector3(w - 0.2, 0.95, -0.035), Vector3(w - 0.12, 1.12, -0.025), "iron"))
	var sign: String = str(opts.get("sign", ""))
	if sign != "":
		enamel_sign(g, Vector3(0, h + 0.45, -0.06), 0.0, sign, minf(w * 1.2, 1.6), 0.3)
	return g


## Steps (visual) rising from `a` (bottom front centre, floor level) to `b` (top back centre): treads with
## nosings, risers, and two stringers. `w` wide. Returns its group.
static func stairs(parent: Node3D, a: Vector3, b: Vector3, w: float = 1.2, key: String = "concrete", stringer_key: String = "steel") -> Node3D:
	var flat: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z)
	var rise: float = b.y - a.y
	var run: float = flat.length()
	var n: int = maxi(1, int(round(rise / 0.18)))
	var bs: Basis = frame_along(a, a + flat)
	var g: Node3D = _group(parent, "Stairs", Transform3D(bs, a))
	var tr: float = run / float(n)
	var rr: float = rise / float(n)
	for i: int in n:
		Props.obox(g, Vector3(0, rr * float(i + 1) - 0.03, tr * (float(i) + 0.5)), Vector3(w, 0.05, tr + 0.03), key)
		_ns(Props.obox(g, Vector3(0, rr * (float(i) + 0.5), tr * float(i) + 0.01), Vector3(w * 0.98, rr, 0.02), key))
	for s: float in [-1.0, 1.0]:
		Props.strut(g, Vector3(s * (w * 0.5 + 0.03), 0.05, -0.05), Vector3(s * (w * 0.5 + 0.03), rise + 0.05, run + 0.05), 0.18, stringer_key)
	return g


## Catwalk grating over lo..hi (lo.y = the grating's bottom): a grate slab, angle edges, and cross beams under it
## every 1.5 m along its long axis. Returns its group.
static func grating(parent: Node3D, lo: Vector3, hi: Vector3, key: String = "fl_grate", edge_key: String = "steel") -> Node3D:
	var g: Node3D = _group(parent, "Grating", Transform3D.IDENTITY)
	var t: float = maxf(0.03, hi.y - lo.y)
	Props.block(g, lo, Vector3(hi.x, lo.y + t, hi.z), key, false)
	var along_x: bool = (hi.x - lo.x) >= (hi.z - lo.z)
	for s: int in 2:
		if along_x:
			var z: float = lo.z if s == 0 else hi.z
			_ns(Props.block(g, Vector3(lo.x, lo.y - 0.08, z - 0.03), Vector3(hi.x, lo.y + t + 0.02, z + 0.03), edge_key))
		else:
			var x: float = lo.x if s == 0 else hi.x
			_ns(Props.block(g, Vector3(x - 0.03, lo.y - 0.08, lo.z), Vector3(x + 0.03, lo.y + t + 0.02, hi.z), edge_key))
	var length: float = (hi.x - lo.x) if along_x else (hi.z - lo.z)
	var n: int = maxi(1, int(length / 1.5))
	for i: int in n + 1:
		var c: float = (lo.x if along_x else lo.z) + length * float(i) / float(n)
		if along_x:
			_ns(Props.block(g, Vector3(c - 0.04, lo.y - 0.16, lo.z), Vector3(c + 0.04, lo.y, hi.z), edge_key))
		else:
			_ns(Props.block(g, Vector3(lo.x, lo.y - 0.16, c - 0.04), Vector3(hi.x, lo.y, c + 0.04), edge_key))
	return g


# ================================================================== paper, chalk, signs

## A notice or poster pinned to a wall: a paper sheet (`paper_key`) with a printed title and body (Label3D), a
## pin at each top corner, a slight tilt. All wording is the caller's and must be fictional (no real symbols, no
## real slogans). Local -Z out of the wall. Returns its group.
static func poster(parent: Node3D, pos: Vector3, yaw: float, title: String, body: String = "", w: float = 0.42, h: float = 0.6,
		paper_key: String = "paper_old", ink: Color = Color(0.12, 0.1, 0.09), tilt: float = 0.0) -> Node3D:
	var g: Node3D = Props.group(parent, "Poster", pos, yaw)
	g.rotation.z = deg_to_rad(tilt)
	_ns(Props.block(g, Vector3(-w * 0.5, -h * 0.5, -0.006), Vector3(w * 0.5, h * 0.5, 0.0), paper_key))
	for sx: float in [-1.0, 1.0]:
		_ns(Props.cyl(g, Vector3(sx * (w * 0.5 - 0.03), h * 0.5 - 0.03, -0.01), 0.008, 0.01, "brass", Vector3(90, 0, 0)))
	var t: Label3D = Props.stencil(g, Vector3(0, h * 0.32, -0.007), 0.0, title, 44, ink, 0.0016, SurfaceText.PRINT)
	t.width = w / 0.0016 * 0.92
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.double_sided = false
	if body != "":
		var b: Label3D = Props.stencil(g, Vector3(0, -h * 0.06, -0.007), 0.0, body, 26, ink, 0.0012, SurfaceText.PRINT)
		b.width = w / 0.0012 * 0.9
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.double_sided = false
	return g


## An enamel plate sign (white text on a coloured plate, a darker rim, four screws). Local -Z out.
static func enamel_sign(parent: Node3D, pos: Vector3, yaw: float, text: String, w: float = 0.8, h: float = 0.3,
		plate_key: String = "enamel_white", text_color: Color = Color(0.08, 0.12, 0.2)) -> Node3D:
	var g: Node3D = Props.group(parent, "EnamelSign", pos, yaw)
	_ns(Props.block(g, Vector3(-w * 0.5, -h * 0.5, -0.012), Vector3(w * 0.5, h * 0.5, 0.0), "black_paint"))
	_ns(Props.block(g, Vector3(-w * 0.5 + 0.015, -h * 0.5 + 0.015, -0.016), Vector3(w * 0.5 - 0.015, h * 0.5 - 0.015, -0.012), plate_key))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_ns(Props.cyl(g, Vector3(sx * (w * 0.5 - 0.03), sy * (h * 0.5 - 0.03), -0.018), 0.008, 0.006, "iron", Vector3(90, 0, 0)))
	# fit the text to the plate: its height and (at ~0.62 em a glyph) its width
	var px: float = minf(0.004, minf(h * 0.55 / 48.0, (w - 0.08) / maxf(1.0, float(text.length()) * 48.0 * 0.62)))
	var l: Label3D = Props.stencil(g, Vector3(0, 0, -0.017), 0.0, text, 48, text_color, px, SurfaceText.PRINT)
	l.double_sided = false
	return g


## Chalk on a wall or a floor. kind: "jakub" (three strokes and a hook, CANON §6.4: "weak, ours, don't trust it"),
## "jakub_backwards" (Tomasz's backwards hook), "tally" (a shift tally, 5-bar gates), "x" (a cross), "arrow",
## "hopscotch" (a child's Himmel und Hölle on the ground: lay it with `flat`). `flat` lays it on a floor (local -Y
## down, the figure's top toward local -Z). `s` = height in metres. Returns its group.
static func chalk_mark(parent: Node3D, pos: Vector3, yaw: float, kind: String = "jakub", s: float = 0.3, flat: bool = false, key: String = "paper") -> Node3D:
	var g: Node3D = Props.group(parent, "Chalk", pos, yaw)
	if flat:
		g.rotation.x = deg_to_rad(-90.0)
	var wd: float = maxf(0.008, s * 0.04)
	var d: float = 0.004
	match kind:
		"jakub", "jakub_backwards":
			for i: int in 3:
				var x: float = (float(i) - 1.0) * s * 0.22
				_ns(Props.obox(g, Vector3(x, s * 0.5, -d), Vector3(wd, s * 0.8, d), key, Vector3(0, 0, -4.0 + float(i) * 3.0)))
			var hx: float = s * 0.42 * (-1.0 if kind == "jakub_backwards" else 1.0)
			_ns(Props.obox(g, Vector3(hx, s * 0.55, -d), Vector3(wd, s * 0.7, d), key))
			_ns(Props.obox(g, Vector3(hx - signf(hx) * s * 0.1, s * 0.2, -d), Vector3(s * 0.22, wd, d), key, Vector3(0, 0, signf(hx) * 30.0)))
		"tally":
			for gate: int in 3:
				var gx: float = float(gate) * s * 0.7
				for i2: int in 4:
					_ns(Props.obox(g, Vector3(gx + float(i2) * s * 0.12, s * 0.5, -d), Vector3(wd, s * 0.8, d), key))
				_ns(Props.obox(g, Vector3(gx + s * 0.18, s * 0.5, -d), Vector3(s * 0.62, wd, d), key, Vector3(0, 0, 35.0)))
		"x":
			for a: float in [45.0, -45.0]:
				_ns(Props.obox(g, Vector3(0, s * 0.5, -d), Vector3(wd, s * 1.1, d), key, Vector3(0, 0, a)))
		"arrow":
			_ns(Props.obox(g, Vector3(0, s * 0.5, -d), Vector3(s, wd, d), key))
			for a2: float in [35.0, -35.0]:
				_ns(Props.obox(g, Vector3(s * 0.42, s * 0.5 + signf(a2) * s * 0.08, -d), Vector3(s * 0.3, wd, d), key, Vector3(0, 0, a2)))
		"hopscotch":
			# 1-2-3 single, 4|5 double, 6 single, 7|8 double, the round Himmel at the top; squares `s` m
			var rows: Array = [[0.0], [0.0], [0.0], [-0.5, 0.5], [0.0], [-0.5, 0.5]]
			for r: int in rows.size():
				for cx: float in rows[r]:
					_square(g, Vector3(cx * s, (float(r) + 0.5) * s, -d), s, wd, key)
			var top: Vector3 = Vector3(0, (float(rows.size()) + 0.45) * s, -d)
			for k: int in 10:
				var a3: float = PI * float(k) / 9.0
				_ns(Props.obox(g, top + Vector3(cos(a3) * s * 0.5, sin(a3) * s * 0.45 - s * 0.05, 0), Vector3(s * 0.18, wd, d), key, Vector3(0, 0, rad_to_deg(a3) + 90.0)))
			for n: int in 6:
				_ns(Props.obox(g, Vector3(s * 0.05 * float(n % 2), (float(n) + 0.5) * s, -d), Vector3(wd * 0.8, s * 0.22, d), key))
	return g


static func _square(g: Node3D, c: Vector3, s: float, wd: float, key: String) -> void:
	for e: Array in [[Vector3(0, s * 0.5, 0), Vector3(s, wd, 0.004)], [Vector3(0, -s * 0.5, 0), Vector3(s, wd, 0.004)],
			[Vector3(s * 0.5, 0, 0), Vector3(wd, s, 0.004)], [Vector3(-s * 0.5, 0, 0), Vector3(wd, s, 0.004)]]:
		_ns(Props.obox(g, c + (e[0] as Vector3), e[1], key))


# ================================================================== weathering and ground

## A weathering card on a wall or floor. kind: "rust", "frost", "soot", "water", "chalk". `pos` = the card's centre
## on the surface, `normal` its outward normal, `size` its width × height (on a floor: x × z). Rust and water run
## down from their top edge. One MultiMesh per kind under the parent.
static func card(parent: Node3D, kind: String, pos: Vector3, normal: Vector3, size: Vector2) -> BakedMultiMesh:
	var n: Vector3 = normal.normalized()
	var bs: Basis
	if absf(n.y) > 0.9:
		bs = Basis(Vector3.RIGHT, -PI * 0.5 * signf(n.y))
	else:
		bs = Basis.looking_at(-n, Vector3.UP)   # the quad faces +Z, looking_at points -Z at the target: face out
		bs = bs * Basis(Vector3.UP, PI)
	return instance(parent, "card_" + kind, _quad(), card_mat(kind), Transform3D(bs.scaled_local(Vector3(size.x, size.y, 1.0)), pos + n * 0.006))


## Rust running down from a fixing (a bolt, a gutter, a sign) on a wall: a card hung from `top` (its top centre).
static func rust_streak(parent: Node3D, top: Vector3, normal: Vector3, w: float = 0.5, h: float = 1.6) -> BakedMultiMesh:
	return card(parent, "rust", top - Vector3(0, h * 0.5, 0), normal, Vector2(w, h))


## A frost / rime patch (window corners, cold walls, the courtyard).
static func frost_patch(parent: Node3D, pos: Vector3, normal: Vector3, size: float = 1.2) -> BakedMultiMesh:
	return card(parent, "frost", pos, normal, Vector2(size, size * 0.8))


## A puddle on a floor (Props' glossy disc) with a darker damp ring card around it.
static func puddle(parent: Node3D, pos: Vector3, w: float, d: float, yaw: float = 0.0) -> void:
	Props.puddle(parent, pos, w, d, yaw)
	card(parent, "water", pos + Vector3(0, 0.002, 0), Vector3.UP, Vector2(w * 1.5, d * 1.5))


## A snow drift against a wall (Props' drift: a squashed wedge with a soft top).
static func snow_drift(parent: Node3D, pos: Vector3, size: Vector3, key: String = "snow") -> Node3D:
	var g: Node3D = Props.group(parent, "Drift", pos)
	_ns(Props.prism(g, Vector3(0, size.y * 0.5, 0), size, key))
	_ns(Props.ball(g, Vector3(0, size.y * 0.35, 0), Vector3(size.x * 0.9, size.y * 0.7, size.z * 0.9), key))
	return g


## A sand drift (Groom Lake's dust against a hangar wall; the same shape as a snow drift in a sand/salt key).
static func sand_drift(parent: Node3D, pos: Vector3, size: Vector3, key: String = "dirt") -> Node3D:
	return snow_drift(parent, pos, size, key)


## A bomb crater: a ring of churned earth and broken paving slabs round a dark scorched bowl. `r` = rim radius.
static func crater(parent: Node3D, c: Vector3, r: float, seed_v: int = 1, earth_key: String = "dirt", slab_key: String = "concrete") -> Node3D:
	var g: Node3D = Props.group(parent, "Crater", c)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = maxi(8, int(r * 5.0))
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.1, 0.1)
		var rr: float = r * rng.randf_range(0.82, 1.08)
		var p: Vector3 = Vector3(cos(a) * rr, 0, sin(a) * rr)
		_ns(Props.obox(g, p + Vector3(0, 0.15, 0), Vector3(rng.randf_range(0.6, 1.3), rng.randf_range(0.2, 0.5), rng.randf_range(0.5, 1.0)), earth_key,
			Vector3(rng.randf_range(-15, 15), rad_to_deg(-a), rng.randf_range(-20, 20))))
		if rng.randf() < 0.45:
			var q: Vector3 = Vector3(cos(a) * rr * 1.25, 0, sin(a) * rr * 1.25)
			_ns(Props.obox(g, q + Vector3(0, 0.08, 0), Vector3(0.6, 0.08, 0.45), slab_key, Vector3(rng.randf_range(-25, 25), rng.randf() * 180.0, rng.randf_range(-25, 25))))
	_ns(Props.cyl(g, Vector3(0, 0.02, 0), r * 0.85, 0.04, "char"))
	card(g, "soot", Vector3(0, 0.03, 0), Vector3.UP, Vector2(r * 2.6, r * 2.6))
	return g


## A washing line between two posts' tops a and b with `sheets` hung cloths (stiff with frost: boxes), keys picked
## from `keys`. Returns its group.
static func washing_line(parent: Node3D, a: Vector3, b: Vector3, sheets: int = 4, seed_v: int = 3,
		keys: Array = ["linen", "cloth_cream", "cloth_navy", "linen"]) -> Node3D:
	var g: Node3D = Props.group(parent, "WashingLine", Vector3.ZERO)
	Props.cable(g, a, b, 0.25, 0.008, 8, "rope")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in sheets:
		var t: float = (float(i) + 0.5 + rng.randf_range(-0.2, 0.2)) / float(sheets)
		var p: Vector3 = a.lerp(b, t) - Vector3(0, 0.25 * 4.0 * t * (1.0 - t), 0)
		var w: float = rng.randf_range(0.5, 1.1)
		var h: float = rng.randf_range(0.5, 1.2)
		var yaw: float = rad_to_deg(atan2((b - a).x, (b - a).z)) + 90.0
		_ns(Props.obox(g, p - Vector3(0, h * 0.5, 0), Vector3(w, h, 0.015), str(keys[i % keys.size()]), Vector3(rng.randf_range(-4, 4), yaw, rng.randf_range(-3, 3))))
		for pg: float in [-0.4, 0.4]:
			_ns(Props.obox(g, p + Vector3(0, -0.02, 0) + Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(yaw)) * w * pg, Vector3(0.02, 0.07, 0.02), "beam"))
	return g


## Camouflage netting over lo..hi (hi.y = the support line): a subdivided sheet in the cut-out netting shader that
## sags `sag` m between supports `step` m apart, with drop skirts hanging `skirt` m at the edges listed in `edges`
## ("n", "s", "e", "w"). Kept out of the batching (meta keep). Returns the sheet.
static func camo_net(parent: Node3D, lo: Vector3, hi: Vector3, sag: float = 0.8, step: float = 8.0, skirt: float = 2.0, edges: String = "nsew") -> MeshInstance3D:
	var sx: float = hi.x - lo.x
	var sz: float = hi.z - lo.z
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CamoNet"
	mi.mesh = _plane_mesh(maxi(2, int(sx / 2.0)), maxi(2, int(sz / 2.0)))
	mi.material_override = cutout_mat("netting", sag, step)
	mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(sx, 1.0, sz)), Vector3((lo.x + hi.x) * 0.5, hi.y, (lo.z + hi.z) * 0.5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("keep", true)
	parent.add_child(mi)
	var skirt_mat: ShaderMaterial = cutout_mat("netting")
	for e: String in edges.split("", false):
		var c: Vector3
		var size: Vector3
		match e:
			"n":
				c = Vector3((lo.x + hi.x) * 0.5, hi.y - skirt * 0.5, hi.z)
				size = Vector3(sx, skirt, 1.0)
			"s":
				c = Vector3((lo.x + hi.x) * 0.5, hi.y - skirt * 0.5, lo.z)
				size = Vector3(sx, skirt, 1.0)
			"e":
				c = Vector3(hi.x, hi.y - skirt * 0.5, (lo.z + hi.z) * 0.5)
				size = Vector3(sz, skirt, 1.0)
			_:
				c = Vector3(lo.x, hi.y - skirt * 0.5, (lo.z + hi.z) * 0.5)
				size = Vector3(sz, skirt, 1.0)
		var bs: Basis = Basis.IDENTITY if (e == "n" or e == "s") else Basis(Vector3.UP, PI * 0.5)
		instance(parent, "netskirt", _quad(), skirt_mat, Transform3D(bs.scaled_local(size), c))
	return mi


## Ground fog that also reads without volumetric fog (Compatibility / web): `layers` horizontal sheets of drifting
## noise stacked from 0.25 m up to `height` over the rectangle centred at `c` (c.y = the floor) of `size` (x, z).
static func fog_sheets(parent: Node3D, c: Vector3, size: Vector2, height: float = 1.6, layers: int = 3, color: Color = Color(0.62, 0.66, 0.74, 0.16)) -> Node3D:
	var g: Node3D = Props.group(parent, "FogSheets", c)
	g.set_meta("keep", true)
	for i: int in layers:
		var y: float = 0.25 + (height - 0.25) * float(i) / float(maxi(1, layers - 1))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "FogSheet%d" % i
		mi.mesh = _plane_mesh(1, 1)
		mi.material_override = fog_mat(Color(color.r, color.g, color.b, color.a * (1.0 - 0.35 * float(i) / float(maxi(1, layers)))))
		mi.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(size.x, 1.0, size.y)), Vector3(0, y, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	return g


# ================================================================== lamps (fixtures only; the generator adds the light)

## A visible light fixture body with its glowing bulb (no Light node: the generator places the light at the
## returned bulb position so every light has a source you can see). kind: "hanging" (an enamel works shade on a
## rod), "wall" (a caged bulkhead on a bracket, local -Z out of the wall), "flood" (a yard floodlight on a bracket,
## aimed down 35°), "pole" (a lamp post with a hooded head, pos = the foot). Returns the bulb's position in the
## parent's space.
static func lamp_fixture(parent: Node3D, pos: Vector3, kind: String = "hanging", yaw: float = 0.0, ceiling_y: float = 0.0,
		shade_key: String = "enamel_green", bulb_key: String = "bulb_warm") -> Vector3:
	var g: Node3D = Props.group(parent, "Fixture", pos, yaw)
	var bulb: Vector3 = pos
	match kind:
		"hanging":
			if ceiling_y > pos.y:
				_ns(Props.strut(g, Vector3(0, 0.3, 0), Vector3(0, ceiling_y - pos.y, 0), 0.025, "iron", true))
			Props.cone(g, Vector3(0, 0.12, 0), 0.32, 0.22, shade_key)
			_ns(Props.cyl(g, Vector3(0, 0.27, 0), 0.06, 0.1, "iron"))
			_ns(Props.ball(g, Vector3(0, 0.0, 0), Vector3(0.12, 0.14, 0.12), bulb_key))
			bulb = pos + Vector3(0, -0.05, 0)
		"wall":
			_ns(Props.block(g, Vector3(-0.06, -0.2, -0.04), Vector3(0.06, 0.06, 0.0), "iron"))
			_ns(Props.strut(g, Vector3(0, 0, -0.02), Vector3(0, 0.05, -0.32), 0.04, "iron"))
			Props.cone(g, Vector3(0, 0.02, -0.38), 0.18, 0.14, shade_key)
			_ns(Props.ball(g, Vector3(0, -0.06, -0.38), Vector3(0.1, 0.12, 0.1), bulb_key))
			bulb = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, -0.12, -0.38)
		"flood":
			_ns(Props.block(g, Vector3(-0.1, -0.1, -0.04), Vector3(0.1, 0.1, 0.0), "iron"))
			_ns(Props.strut(g, Vector3(0, 0, -0.02), Vector3(0, 0, -0.45), 0.05, "iron"))
			var head: MeshInstance3D = Props.obox(g, Vector3(0, -0.05, -0.55), Vector3(0.42, 0.3, 0.22), "machine_grey", Vector3(-35, 0, 0))
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_ns(Props.obox(g, Vector3(0, -0.12, -0.62), Vector3(0.36, 0.24, 0.02), "flood_glass", Vector3(-35, 0, 0)))
			bulb = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, -0.3, -0.75)
		"pole":
			Props.cyl(g, Vector3(0, 2.0, 0), 0.07, 4.0, "iron")
			_ns(Props.cyl(g, Vector3(0, 0.15, 0), 0.14, 0.3, "iron"))
			_ns(Props.strut(g, Vector3(0, 3.9, 0), Vector3(0, 4.05, -0.6), 0.05, "iron"))
			Props.cone(g, Vector3(0, 3.98, -0.65), 0.26, 0.18, shade_key)
			_ns(Props.ball(g, Vector3(0, 3.86, -0.65), Vector3(0.12, 0.14, 0.12), bulb_key))
			bulb = pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 3.8, -0.65)
	return bulb


# ================================================================== the flying wing

## The upper and lower surface heights of the flying-wing shell at (x, z) in its own frame (+X span, +Z nose, y up
## from the floor), or Vector2(-1, -1) outside the planform. Pure: the generator and the tests use it to prove the
## shell covers the act's colliders. p: span, root_chord, le_root (z of the root leading edge), le_sweep, te_sweep
## (dz per metre of span), t_root, t_tip (max thickness), base (the lower surface's height), body_half (|x| where the
## centre body's plateau ends), body_h, body_z (Vector2 tail..nose of the plateau), notch_half / notch_te (the bomb
## bay's notch in the trailing edge).
static func wing_surface(x: float, z: float, p: Dictionary) -> Vector2:
	var ax: float = absf(x)
	var half_span: float = float(p.get("span", 86.0)) * 0.5
	if ax > half_span:
		return Vector2(-1, -1)
	var le: float = float(p.get("le_root", 26.0)) - ax * float(p.get("le_sweep", 0.22))
	var te: float = -float(p.get("le_root", 26.0)) + ax * float(p.get("te_sweep", 0.2))
	var nh: float = float(p.get("notch_half", 0.0))
	if nh > 0.0:
		var nte: float = float(p.get("notch_te", te))
		te = lerpf(nte, te, smoothstep(nh, nh + 2.0, ax))
	if z > le or z < te:
		return Vector2(-1, -1)
	var xc: float = (le - z) / maxf(0.01, le - te)
	var f: float = 10.0 * (0.2969 * sqrt(xc) - 0.126 * xc - 0.3516 * xc * xc + 0.2843 * xc * xc * xc - 0.1036 * xc * xc * xc * xc)
	var t: float = lerpf(float(p.get("t_root", 7.0)), float(p.get("t_tip", 3.6)), ax / half_span)
	var tip_round: float = sqrt(maxf(0.0, 1.0 - pow(ax / half_span, float(p.get("tip_pow", 10.0)))))
	var wing: float = maxf(0.0, f * t * tip_round)
	var bz: Vector2 = p.get("body_z", Vector2(-20.5, 21.0))
	var bh: float = float(p.get("body_h", 3.3))
	var bhalf: float = float(p.get("body_half", 10.5))
	var bx: float = 1.0 - smoothstep(bhalf, bhalf + 3.5, ax)
	var bzf: float = smoothstep(bz.x - 1.6, bz.x, z) * (1.0 - smoothstep(bz.y, le, z))
	var body: float = bh * bx * bzf
	var base: float = float(p.get("base", 0.2))
	var top: float = base + maxf(wing, body)
	var bottom: float = base + minf(0.25, (top - base) * 0.06)
	return Vector2(top, bottom)


## The flying-wing shell as one ArrayMesh (a closed hull: upper and lower skins sampled along the chord at every
## span station, closed at the leading and trailing edges and the tips). `stations` across the span, `chord_n`
## points along each chord (cosine spacing: dense at the edges). Material is the caller's (material_override).
static func flying_wing_mesh(p: Dictionary, stations: int = 44, chord_n: int = 26) -> ArrayMesh:
	var half_span: float = float(p.get("span", 86.0)) * 0.5
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops: Array = []
	var bots: Array = []
	for i: int in stations + 1:
		var x: float = -half_span + 2.0 * half_span * float(i) / float(stations)
		x = clampf(x, -half_span + 0.02, half_span - 0.02)
		var ax: float = absf(x)
		var le: float = float(p.get("le_root", 26.0)) - ax * float(p.get("le_sweep", 0.22))
		var te: float = -float(p.get("le_root", 26.0)) + ax * float(p.get("te_sweep", 0.2))
		var nh: float = float(p.get("notch_half", 0.0))
		if nh > 0.0:
			te = lerpf(float(p.get("notch_te", te)), te, smoothstep(nh, nh + 2.0, ax))
		var row_t: PackedVector3Array = []
		var row_b: PackedVector3Array = []
		for j: int in chord_n + 1:
			var u: float = 0.5 - 0.5 * cos(PI * float(j) / float(chord_n))
			var z: float = lerpf(le - 0.001, te + 0.001, u)
			var h: Vector2 = wing_surface(x, z, p)
			if h.x < 0.0:
				h = Vector2(float(p.get("base", 0.2)), float(p.get("base", 0.2)))
			row_t.append(Vector3(x, h.x, z))
			row_b.append(Vector3(x, h.y, z))
		tops.append(row_t)
		bots.append(row_b)
	for i2: int in stations:
		var t0: PackedVector3Array = tops[i2]
		var t1: PackedVector3Array = tops[i2 + 1]
		var b0: PackedVector3Array = bots[i2]
		var b1: PackedVector3Array = bots[i2 + 1]
		for j2: int in chord_n:
			_quad_tri(st, t0[j2], t1[j2], t1[j2 + 1], t0[j2 + 1])
			_quad_tri(st, b0[j2], b0[j2 + 1], b1[j2 + 1], b1[j2])
		# closing strips at the leading and trailing edges (zero area where the skins meet)
		_quad_tri(st, b0[0], b1[0], t1[0], t0[0])
		_quad_tri(st, t0[chord_n], t1[chord_n], b1[chord_n], b0[chord_n])
	# tip caps
	for side: int in [0, stations]:
		var tr: PackedVector3Array = tops[side]
		var br: PackedVector3Array = bots[side]
		for j3: int in chord_n:
			if side == 0:
				_quad_tri(st, tr[j3], tr[j3 + 1], br[j3 + 1], br[j3])
			else:
				_quad_tri(st, tr[j3], br[j3], br[j3 + 1], tr[j3 + 1])
	st.generate_normals()
	return st.commit()


static func _quad_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# counter-clockwise seen from outside (Godot's front faces are clockwise in screen space: add as a, c, b)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)


## A unit wing rib (chord 1 along -Z from its leading edge at z 0, thickness `t_c` of the chord, 1 thick in X): an
## extruded symmetric airfoil outline. Scale it by (rib thickness, chord, chord). Cached per t_c.
static func rib_mesh(t_c: float = 0.12) -> ArrayMesh:
	var k: String = "rib_%.3f" % t_c
	if _meshes.has(k):
		return _meshes[k]
	var n: int = 14
	var up: PackedVector3Array = []
	var dn: PackedVector3Array = []
	for j: int in n + 1:
		var u: float = 0.5 - 0.5 * cos(PI * float(j) / float(n))
		var f: float = 5.0 * t_c * (0.2969 * sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u * u * u - 0.1036 * u * u * u * u)
		up.append(Vector3(0, f, -u))
		dn.append(Vector3(0, -f, -u))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-0.5, 0.5]:
		for j2: int in n:
			var a: Vector3 = up[j2] + Vector3(side, 0, 0)
			var b: Vector3 = up[j2 + 1] + Vector3(side, 0, 0)
			var c: Vector3 = dn[j2 + 1] + Vector3(side, 0, 0)
			var d: Vector3 = dn[j2] + Vector3(side, 0, 0)
			if side < 0.0:
				_quad_tri(st, a, b, c, d)
			else:
				_quad_tri(st, a, d, c, b)
	for j3: int in n:
		_quad_tri(st, up[j3] + Vector3(-0.5, 0, 0), up[j3] + Vector3(0.5, 0, 0), up[j3 + 1] + Vector3(0.5, 0, 0), up[j3 + 1] + Vector3(-0.5, 0, 0))
		_quad_tri(st, dn[j3] + Vector3(-0.5, 0, 0), dn[j3 + 1] + Vector3(-0.5, 0, 0), dn[j3 + 1] + Vector3(0.5, 0, 0), dn[j3] + Vector3(0.5, 0, 0))
	st.generate_normals()
	var m: ArrayMesh = st.commit()
	_meshes[k] = m
	return m


## A half-built wing in a jig: ribs every `rib_step` m across `span` (instanced), front and rear spars, and skin
## panels over the first `skin` share of the span (from the root, -X end). The wing's leading edge runs along local
## +X at z 0 (chord toward -Z), root chord `root` tapering to `tip`; `mirror` puts the root at +X (the other half of a
## flying wing). Returns its group.
static func wing_skeleton(parent: Node3D, pos: Vector3, yaw: float, span: float, root: float, tip: float, skin: float = 0.35,
		rib_step: float = 1.2, key: String = "machine_grey", skin_key: String = "chrome_worn", sweep: float = 0.25, mirror: bool = false) -> Node3D:
	var g: Node3D = Props.group(parent, "WingSkeleton", pos, yaw)
	var m: float = -1.0 if mirror else 1.0
	var n: int = maxi(2, int(span / rib_step))
	var mesh: ArrayMesh = rib_mesh(0.13)
	for i: int in n + 1:
		var u: float = float(i) / float(n)
		var x: float = (-span * 0.5 + span * u) * m
		var c: float = lerpf(root, tip, u)
		var zle: float = -u * span * sweep
		instance(g, "rib_" + key, mesh, Mats.get_mat(key), Transform3D(Basis.IDENTITY.scaled(Vector3(0.025, c, c)), Vector3(x, 0, zle)), true)
	# spars at 25% and 65% chord (straight lines root to tip)
	for f: float in [0.25, 0.65]:
		var a: Vector3 = Vector3(-span * 0.5 * m, 0, -root * f)
		var b: Vector3 = Vector3(span * 0.5 * m, 0, -span * sweep - tip * f)
		i_beam(g, a, b, lerpf(root, tip, 0.5) * 0.11, 0.12, key, Vector3.UP, true)
	# the skinned part: upper skin panels as thin boxes following the chord's top line
	var ns: int = maxi(1, int(n * skin))
	for i2: int in ns:
		var u0: float = float(i2) / float(n)
		var u1: float = float(i2 + 1) / float(n)
		var c0: float = lerpf(root, tip, (u0 + u1) * 0.5)
		var x0: float = (-span * 0.5 + span * u0) * m
		var x1: float = (-span * 0.5 + span * u1) * m
		var zm: float = -(u0 + u1) * 0.5 * span * sweep
		var th: float = c0 * 0.13 * 0.5
		Props.obox(g, Vector3((x0 + x1) * 0.5, th * 0.92, zm - c0 * 0.3), Vector3(absf(x1 - x0) + 0.02, 0.012, c0 * 0.5), skin_key, Vector3(-4, 0, 0))
		Props.obox(g, Vector3((x0 + x1) * 0.5, th * 0.62, zm - c0 * 0.72), Vector3(absf(x1 - x0) + 0.02, 0.012, c0 * 0.36), skin_key, Vector3(8, 0, 0))
		Props.obox(g, Vector3((x0 + x1) * 0.5, -th * 0.8, zm - c0 * 0.45), Vector3(absf(x1 - x0) + 0.02, 0.012, c0 * 0.8), skin_key)
	return g


## Folds every primitive-mesh MeshInstance3D under `group` into one ArrayMesh child per material and shadow mode,
## in the group's own frame (for a kept group the static batching skips: the Kranich, the crane bridge, the hangar
## doors, so an fx can still move it as one piece). UVs are dropped like the batching does (the materials are
## world-triplanar). Returns how many meshes it folded.
static func merge_children(group: Node3D) -> int:
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
	var i: int = 0
	for k2: String in buckets.keys():
		var b: Dictionary = buckets[k2]
		var arrays: Array = (b["st"] as SurfaceTool).commit_to_arrays()
		arrays[Mesh.ARRAY_TEX_UV] = null
		var m: ArrayMesh = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out: MeshInstance3D = MeshInstance3D.new()
		out.name = "Merged_%d" % i
		out.mesh = m
		out.material_override = b["mat"]
		out.cast_shadow = b["shadow"]
		group.add_child(out)
		i += 1
	for mi2: MeshInstance3D in victims:
		mi2.get_parent().remove_child(mi2)
		mi2.free()
	return victims.size()


## Drops the caches (tests).
static func reset() -> void:
	_mats = {}
	_meshes = {}
