class_name TelegraphDecal
extends Node3D
## Ground decal for a telegraph (BS_ENEMIES §1.2: ground-targeted attacks draw a decal for the full
## telegraph time). Ring: a pulsing outer ring and an inner disc growing to the full radius
## (telegraphRing, index.html:3249). Lane: a rectangle whose fill grows along its length.
## Emissive and unshaded so it reads in any lighting. Frees itself when `life` runs out.

var life: float = 1.0
var max_life: float = 1.0
var radius: float = 1.0
var is_lane: bool = false
var color: Color = Color(1.0, 0.36, 0.18)
var _outer: MeshInstance3D
var _inner: MeshInstance3D
var _outer_mat: StandardMaterial3D
var _length: float = 1.0


func setup_ring(r: float, dur: float, c: Color) -> void:
	radius = r
	life = dur
	max_life = maxf(dur, 0.01)
	color = c
	_outer_mat = EnemyFx.glow(c, 0.7)
	_outer = EnemyFx.torus(self, maxf(0.0, r - 0.12), r, Vector3.ZERO, _outer_mat)
	_outer.scale = Vector3(1, 0.15, 1)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 24
	_inner = MeshInstance3D.new()
	_inner.mesh = cm
	_inner.material_override = EnemyFx.glow(c, 0.35)
	_inner.scale = Vector3(0.2, 1, 0.2)
	add_child(_inner)


func setup_lane(length: float, width: float, dur: float, c: Color) -> void:
	is_lane = true
	_length = length
	life = dur
	max_life = maxf(dur, 0.01)
	color = c
	_outer_mat = EnemyFx.glow(c, 0.45)
	_outer = EnemyFx.box(self, Vector3(width, 0.02, length), Vector3.ZERO, _outer_mat)
	_inner = EnemyFx.box(self, Vector3(width * 0.8, 0.03, 1.0), Vector3.ZERO, EnemyFx.glow(c, 0.6))


func _process(delta: float) -> void:
	life -= delta
	var k: float = clampf(1.0 - life / max_life, 0.0, 1.0)
	if _outer_mat != null:
		_outer_mat.albedo_color.a = 0.5 + sin(Time.get_ticks_msec() / 60.0) * 0.2
	if _inner != null:
		if is_lane:
			_inner.scale = Vector3(1, 1, maxf(0.01, k * _length))
			_inner.position.z = -_length * 0.5 + k * _length * 0.5
		else:
			var s: float = 0.2 + k * radius
			_inner.scale = Vector3(s, 1, s)
	if life <= 0.0:
		queue_free()
