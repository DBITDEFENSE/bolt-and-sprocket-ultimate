class_name WeaponFX
extends RefCounted
## Greybox weapon effects (tracers, flashes, blasts, lightning, rings). Short-lived MeshInstance3Ds that fade and
## free themselves. Replaced in the art pass; gameplay never reads them.

const _FADER: GDScript = preload("res://bs/weapons/fx/fx_fader.gd")

static var _mats: Dictionary = {}


static func glow_mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var key: String = c.to_html() + str(alpha)
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
	m.emission_enabled = true
	m.emission = c
	_mats[key] = m
	return m


static func _spawn(world: Node, mesh: Mesh, c: Color, life: float, alpha: float = 0.85) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var m: StandardMaterial3D = glow_mat(c, alpha).duplicate()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f: Node = _FADER.new()
	f.set("life", life)
	f.set("max_life", life)
	mi.add_child(f)
	if world != null and world.is_inside_tree():
		world.add_child(mi)
	return mi


## A straight beam segment (tracer / lightning piece).
static func tracer(world: Node, a: Vector3, b: Vector3, c: Color, width: float = 0.05, life: float = 0.08) -> MeshInstance3D:
	var len: float = a.distance_to(b)
	if len < 0.01 or world == null:
		return null
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(width, width, len)
	var mi: MeshInstance3D = _spawn(world, bm, c, life)
	if mi == null or not mi.is_inside_tree():
		return mi
	mi.global_position = (a + b) * 0.5
	var up: Vector3 = Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT
	mi.look_at(b, up)
	return mi


## Jagged lightning between two points (lightningLine 4760): 11 segments, ±0.4 jitter.
static func lightning(world: Node, a: Vector3, b: Vector3, c: Color = Color("#3ee6ff"), rng: RandomNumberGenerator = null) -> void:
	var n: int = 11
	var prev: Vector3 = a
	for i: int in range(1, n + 1):
		var pt: Vector3 = a.lerp(b, float(i) / n)
		if i < n:
			var j: float = 0.4
			pt += Vector3((rng.randf() if rng else randf()) * 2.0 - 1.0, (rng.randf() if rng else randf()) * 2.0 - 1.0,
				(rng.randf() if rng else randf()) * 2.0 - 1.0) * j
		tracer(world, prev, pt, Color.WHITE.lerp(c, 0.4), 0.04, 0.12)
		tracer(world, prev, pt, c, 0.09, 0.3)
		prev = pt


static func flash(world: Node, pos: Vector3, c: Color, r: float = 0.25, life: float = 0.06) -> void:
	if world == null:
		return
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	var mi: MeshInstance3D = _spawn(world, s, c, life)
	if mi != null and mi.is_inside_tree():
		mi.global_position = pos


static func blast(world: Node, pos: Vector3, r: float, c: Color) -> void:
	flash(world, pos, Color(1.0, 0.96, 0.87), r * 0.35, 0.12)
	flash(world, pos, c, r * 0.8, 0.25)
	ring(world, pos, r * 1.2, c, 0.35)


static func ring(world: Node, pos: Vector3, r: float, c: Color, life: float = 0.35) -> void:
	if world == null:
		return
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = maxf(0.05, r - 0.12)
	t.outer_radius = r
	t.rings = 24
	t.ring_segments = 4
	var mi: MeshInstance3D = _spawn(world, t, c, life, 0.6)
	if mi != null and mi.is_inside_tree():
		mi.global_position = pos


## A flat disc on the ground (residue patches, dance floors, rifts). Persistent until freed by its owner.
static func disc(parent: Node3D, r: float, c: Color, alpha: float = 0.4) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.05
	cm.radial_segments = 24
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = glow_mat(c, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
