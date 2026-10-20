class_name LevelKit
extends RefCounted
## Greybox building blocks shared by every B&S planet: rim-lit palette materials, solid / decorative boxes,
## ramps, stepped mounds, cylinders, painted signs, and line-text lookup. Every number comes from the level
## data file; this only turns data rows into nodes.
##
## Physics: solid pieces are StaticBody3D on the world layer (1) unless a layer is given.

const WORLD_LAYER: int = 1

static var palette: Dictionary = {}          # name -> Color (from the level's "materials" table)
static var rim: Dictionary = {"rim": 0.35, "tint": 0.55, "roughness": 0.85, "metallic": 0.15}
static var _mats: Dictionary = {}
static var _extra_lines: Dictionary = {}     # level-owned lines (bs.* ids) not in the story line index


static func set_palette(materials: Dictionary, rim_cfg: Dictionary = {}) -> void:
	palette.clear()
	_mats.clear()
	for k: String in materials.keys():
		palette[k] = Color.html(str(materials[k]))
	if not rim_cfg.is_empty():
		rim = rim_cfg.duplicate()


## "#rrggbb", a palette name, or an int 0xRRGGBB.
static func color(c: Variant) -> Color:
	if c is Color:
		return c
	if c is String or c is StringName:
		var s: String = str(c)
		if palette.has(s):
			return palette[s]
		if s.begins_with("#"):
			return Color.html(s)
		return Color(1, 0, 1)
	if c is int or c is float:
		var i: int = int(c)
		return Color8((i >> 16) & 255, (i >> 8) & 255, i & 255)
	return Color(1, 0, 1)


## Rim-lit standard material, cached per colour + emission.
static func mat(c: Variant, emission: float = 0.0) -> StandardMaterial3D:
	var col: Color = color(c)
	var key: String = "%s|%.2f" % [col.to_html(), emission]
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = float(rim.get("roughness", 0.85))
	m.metallic = float(rim.get("metallic", 0.15))
	m.rim_enabled = true
	m.rim = float(rim.get("rim", 0.35))
	m.rim_tint = float(rim.get("tint", 0.55))
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


## A box centred at pos. solid = StaticBody3D with a matching collider; otherwise a mesh only.
static func box(parent: Node, pos: Vector3, size: Vector3, c: Variant, solid: bool = true, rot_deg: Vector3 = Vector3.ZERO,
		layer: int = WORLD_LAYER, emission: float = 0.0) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emission)
	if not solid:
		mi.position = pos
		mi.rotation_degrees = rot_deg
		parent.add_child(mi)
		return mi
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.add_child(mi)
	body.position = pos
	body.rotation_degrees = rot_deg
	parent.add_child(body)
	return body


## A ramp whose top surface runs from `from` to `to` (both on the walking surface), `w` wide, `t` thick.
static func ramp(parent: Node, from: Vector3, to: Vector3, w: float, c: Variant, t: float = 0.4) -> Node3D:
	var d: Vector3 = to - from
	var length: float = d.length()
	var b: Basis = Basis.looking_at(d.normalized(), Vector3.UP)
	var mid: Vector3 = (from + to) * 0.5 - b.y * (t * 0.5)
	var body: Node3D = box(parent, Vector3.ZERO, Vector3(w, t, length), c, true)
	body.transform = Transform3D(b, mid)
	return body


## Cylinder (solid or deco). axis "y" (default), "x" or "z".
static func cylinder(parent: Node, pos: Vector3, radius: float, height: float, c: Variant, solid: bool = false,
		axis: String = "y", top_radius: float = -1.0, emission: float = 0.0) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat(c, emission)
	var root: Node3D = mi
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: CylinderShape3D = CylinderShape3D.new()
		sh.radius = radius if top_radius < 0.0 else (radius + top_radius) * 0.5
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
		root = body
	root.position = pos
	if axis == "x":
		root.rotation_degrees = Vector3(0, 0, 90)
	elif axis == "z":
		root.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(root)
	return root


## A scrap mound: two stacked solid cylinders (wide base, narrower cap) so the cover is jumpable.
static func mound(parent: Node, x: float, z: float, base_y: float, r: float, h: float, c: Variant) -> void:
	cylinder(parent, Vector3(x, base_y + h * 0.25, z), r, h * 0.5, c, true, "y", r * 0.85)
	cylinder(parent, Vector3(x, base_y + h * 0.75, z), r * 0.6, h * 0.5, c, true, "y", r * 0.35)


## Painted sign: a backing plate with a Label3D. Text is a line id (resolved through text()) or literal.
static func text_sign(parent: Node, text_or_id: String, pos: Vector3, size: Vector2, ry_deg: float = 0.0,
		bg: Variant = "#2a1a10", fg: Variant = "#ffd23e") -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, ry_deg, 0)
	parent.add_child(root)
	box(root, Vector3(0, 0, -0.04), Vector3(size.x, size.y, 0.06), bg, false)
	var lbl: Label3D = Label3D.new()
	lbl.text = text(text_or_id)
	lbl.modulate = color(fg)
	lbl.pixel_size = 0.004
	lbl.font_size = int(clampf(size.y * 70.0, 24.0, 160.0))
	lbl.outline_size = 0
	lbl.width = size.x / lbl.pixel_size
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.double_sided = true
	root.add_child(lbl)
	root.set_meta("text", lbl.text)
	return root


## Registers level-owned lines (bs.* ids). They are also merged into VOManager's table so play(id) works.
static func register_lines(lines: Dictionary) -> void:
	_extra_lines.merge(lines, true)
	var vo: Node = Engine.get_main_loop().root.get_node_or_null(^"VOManager") if Engine.get_main_loop() is SceneTree else null
	if vo != null and vo.get("_lines") is Dictionary:
		(vo.get("_lines") as Dictionary).merge(lines, false)


## Text of a line id (level lines first, then the story index); anything else is returned as written.
static func text(id_or_text: String) -> String:
	if _extra_lines.has(id_or_text):
		return str((_extra_lines[id_or_text] as Dictionary).get("text", ""))
	var vo: Node = Engine.get_main_loop().root.get_node_or_null(^"VOManager") if Engine.get_main_loop() is SceneTree else null
	if vo != null and vo.call("has_line", id_or_text):
		return str((vo.call("line", id_or_text) as Dictionary).get("text", ""))
	return id_or_text


static func has_text(id: String) -> bool:
	if _extra_lines.has(id):
		return true
	var vo: Node = Engine.get_main_loop().root.get_node_or_null(^"VOManager") if Engine.get_main_loop() is SceneTree else null
	return vo != null and bool(vo.call("has_line", id))


static func v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	if a is Vector3:
		return a
	return fallback


static func v2(a: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback


## The player node, if any.
static func player(tree: SceneTree) -> Node3D:
	return tree.get_first_node_in_group(&"player") as Node3D
