class_name EnemyFx
extends RefCounted
## Greybox building blocks and transient effects for enemies and bosses: materials, primitive meshes,
## the ground telegraph ring (the original telegraphRing, index.html:3249), a lane decal, death chunks
## (chunkDeath, index.html:6338) and the floor probe used to put decals on the ground.
## Everything here is silent and works headless.

const WORLD_MASK: int = 1 | (1 << 5)


static func col(hex: String) -> Color:
	return Color.from_string(hex, Color.MAGENTA)


static func mat(c: Color, emissive: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = energy
	return m


## A glowing unshaded material for telegraphs, lamps and weak points.
static func glow(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return _add(parent, bm, pos, m)


static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, h: float = -1.0) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 if h < 0.0 else h
	sm.radial_segments = 12
	sm.rings = 6
	return _add(parent, sm, pos, m)


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, r_top: float = -1.0) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = 12
	return _add(parent, cm, pos, m)


static func torus(parent: Node3D, r_in: float, r_out: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	tm.rings = 16
	tm.ring_segments = 6
	return _add(parent, tm, pos, m)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Ground height under a point (world + solid props), or `fallback` when nothing is below.
static func floor_y(space_node: Node3D, at: Vector3, fallback: float, up: float = 1.5, down: float = 30.0) -> float:
	if space_node == null or not space_node.is_inside_tree():
		return fallback
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * up, at + Vector3.DOWN * down, WORLD_MASK)
	var r: Dictionary = space_node.get_world_3d().direct_space_state.intersect_ray(q)
	return (r["position"] as Vector3).y if not r.is_empty() else fallback


## Line of sight between two points against world geometry.
static func los_clear(space_node: Node3D, a: Vector3, b: Vector3) -> bool:
	if space_node == null or not space_node.is_inside_tree():
		return true
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1)
	return space_node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Ground telegraph decal: a pulsing ring plus an inner disc that grows to full size as the
## telegraph runs out (telegraphRing, index.html:3249). Frees itself after `dur`.
static func ring(parent: Node, center: Vector3, r: float, dur: float, c: Color) -> TelegraphDecal:
	var d: TelegraphDecal = TelegraphDecal.new()
	d.setup_ring(r, dur, c)
	if parent == null:
		return d
	parent.add_child(d)
	d.global_position = Vector3(center.x, floor_y(d, center, center.y) + 0.06, center.z)
	return d


## A lane decal (tread charge, a long rectangle from `from` along `dir`).
static func lane(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, dur: float, c: Color) -> TelegraphDecal:
	var d: TelegraphDecal = TelegraphDecal.new()
	d.setup_lane(length, width, dur, c)
	if parent == null:
		return d
	parent.add_child(d)
	var h: Vector3 = Vector3(dir.x, 0, dir.z).normalized()
	d.global_position = Vector3(from.x, floor_y(d, from, from.y) + 0.06, from.z) + h * length * 0.5
	if h.length_squared() > 0.0:
		d.rotation.y = atan2(h.x, h.z)
	return d


## 3-5 tumbling wreckage chunks in the def's chunk colour (chunkDeath, index.html:6338).
static func chunks(parent: Node, center: Vector3, c: Color, radius: float, n_min: int = 3, n_max: int = 5) -> void:
	if parent == null:
		return
	var n: int = clampi(roundi(3.0 + radius), n_min, n_max)
	var m: StandardMaterial3D = mat(c)
	for i: int in n:
		var ch: DebrisChunk = DebrisChunk.new()
		var s: float = radius * randf_range(0.25, 0.5)
		box(ch, Vector3(s, s * randf_range(0.5, 0.9), s * randf_range(0.6, 1.2)), Vector3.ZERO, m)
		ch.vel = Vector3(randf_range(-4.5, 4.5), randf_range(4.0, 9.0), randf_range(-4.5, 4.5))
		ch.spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		ch.life = randf_range(1.0, 1.5)
		parent.add_child(ch)
		ch.global_position = center + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
		ch.floor_y = floor_y(ch, center, center.y - 1.0) + 0.1


## Gravity tumble with a floor bounce and a shrink-out (debrisMotion, index.html:6360).
class DebrisChunk extends Node3D:
	var vel: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO
	var life: float = 1.2
	var floor_y: float = 0.0

	func _physics_process(delta: float) -> void:
		life -= delta
		vel.y -= 22.0 * delta
		position += vel * delta
		if global_position.y < floor_y and vel.y < 0.0:
			global_position.y = floor_y
			vel.y *= -0.35
			vel.x *= 0.7
			vel.z *= 0.7
		rotation += spin * delta
		if life < 0.3:
			scale *= maxf(0.0, 1.0 - delta * 3.5)
		if life <= 0.0:
			queue_free()
