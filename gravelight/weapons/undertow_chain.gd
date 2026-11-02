class_name UndertowChain
extends Node3D
## The Undertow's chain while it reels (presentation only, T-153): a dark violet-black line from the muzzle to the
## harpoon head; the head follows the first skewered body in as the chain reels for `seconds`, then it is gone.

var from: Vector3
var to: Vector3
var seconds: float = 1.2
var follow: Zombie = null
var _age: float = 0.0
var _mesh: MeshInstance3D
var _head: MeshInstance3D


static func draw(ctx: Node, muzzle: Vector3, head: Vector3, secs: float, col: Color, skewered: Array) -> UndertowChain:
	if ctx == null or not ctx.is_inside_tree():
		return null
	var c: UndertowChain = UndertowChain.new()
	c.from = muzzle
	c.to = head
	c.seconds = maxf(0.25, secs)
	if not skewered.is_empty() and skewered[0] is Zombie:
		c.follow = skewered[0]
	var host: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene != null else ctx.get_tree().root
	host.add_child(c)
	c._build(col)
	return c


func _build(col: Color) -> void:
	top_level = true
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.04, 0.08)
	m.metallic = 0.6
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.35
	_mesh = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.0
	cm.radial_segments = 6
	_mesh.mesh = cm
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_head = MeshInstance3D.new()
	var hm: CylinderMesh = CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = 0.035
	hm.height = 0.14
	_head.mesh = hm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.05, 0.2)
	gm.emission_enabled = true
	gm.emission = col
	gm.emission_energy_multiplier = 2.0
	_head.material_override = gm
	add_child(_head)
	_layout()


func _process(delta: float) -> void:
	_age += delta
	if follow != null and is_instance_valid(follow) and follow.is_active():
		to = follow.global_position + Vector3.UP * 1.1
	_layout()
	if _age >= seconds:
		queue_free()


func _layout() -> void:
	if _mesh == null:
		return
	var d: Vector3 = to - from
	var L: float = maxf(0.05, d.length())
	var mid: Vector3 = from + d * 0.5
	var up: Vector3 = d / L
	var side: Vector3 = up.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var fwd: Vector3 = side.cross(up).normalized()
	_mesh.global_transform = Transform3D(Basis(side, up * L, fwd), mid)
	_head.global_transform = Transform3D(Basis(side, up, fwd), to)
