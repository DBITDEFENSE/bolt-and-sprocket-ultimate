class_name EnemyBeam
extends Node3D
## A damage beam (addBeam / updateHazards, index.html:7536-7572): a straight segment from `a` to `b` that hurts
## Bolt for `dmg` every 0.3 s while he is within r + 0.8 of it, for `life` seconds. The far end is clipped by
## world geometry (cover blocks beams). Optional sweep: the beam turns `sweep_rate` rad/s around `a`.
## Optional `mult_at: Callable(pos) -> float` scales each tick (the Content Creator's boiling pool doubles it).

const TICK: float = 0.3
const WORLD_MASK: int = 1 | (1 << 5)

var a: Vector3 = Vector3.ZERO
var dir: Vector3 = Vector3.FORWARD
var length: float = 30.0
var r: float = 0.45
var dmg: float = 14.0
var life: float = 0.9
var max_life: float = 0.9
var sweep_rate: float = 0.0
var tick: float = 0.0
var source: Node = null
var color: Color = Color("#ff5d2e")
var mult_at: Callable = Callable()
var ticks_hit: int = 0
var b: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


static func fire(parent: Node, from: Vector3, dir_: Vector3, length_: float, r_: float, dmg_: float, life_: float,
		color_: Color, source_: Node = null, opts: Dictionary = {}) -> EnemyBeam:
	var bm: EnemyBeam = EnemyBeam.new()
	bm.a = from
	bm.dir = dir_.normalized() if dir_.length_squared() > 0.0 else Vector3.FORWARD
	bm.length = length_
	bm.r = r_
	bm.dmg = dmg_
	bm.life = life_
	bm.max_life = maxf(life_, 0.01)
	bm.color = color_
	bm.source = source_
	bm.sweep_rate = float(opts.get("sweep_rate", 0.0))
	bm.mult_at = opts.get("mult_at", Callable())
	parent.add_child(bm)
	bm.global_position = Vector3.ZERO
	bm._clip()
	return bm


func _ready() -> void:
	add_to_group(&"enemy_beams")
	_mat = EnemyFx.glow(color, 0.85)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 10
	_mesh = MeshInstance3D.new()
	_mesh.mesh = cm
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_place()


func _clip() -> void:
	var to: Vector3 = a + dir * length
	b = to
	if is_inside_tree():
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, to, WORLD_MASK)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			b = hit["position"]


func _place() -> void:
	if _mesh == null:
		return
	var seg: Vector3 = b - a
	var len_: float = maxf(seg.length(), 0.01)
	_mesh.global_position = a + seg * 0.5
	var up: Vector3 = seg / len_
	var side: Vector3 = up.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd: Vector3 = side.cross(up).normalized()
	_mesh.global_basis = Basis(side * r, up * len_, fwd * r)


## Distance from Bolt's chest line (feet + 0.2, as in segDistToPlayer) to the segment.
func dist_to(p: Vector3) -> float:
	var cp: Vector3 = Geometry3D.get_closest_point_to_segment(p, a, b)
	return cp.distance_to(p)


func _physics_process(delta: float) -> void:
	life -= delta
	tick -= delta
	if sweep_rate != 0.0:
		dir = dir.rotated(Vector3.UP, sweep_rate * delta)
		_clip()
		_place()
	_mat.albedo_color.a = 0.85 * clampf(life / max_life * 1.5, 0.0, 1.0)
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if bolt != null and bool(bolt.call("is_alive")) and tick <= 0.0:
		var p: Vector3 = bolt.global_position + Vector3(0, 0.2, 0)
		if dist_to(p) < r + 0.8:
			tick = TICK
			var m: float = float(mult_at.call(bolt.global_position)) if mult_at.is_valid() else 1.0
			var h: Combat.Hit = Combat.Hit.make(dmg * m, Combat.Type.ENERGY, source)
			h.point = p
			if EnemyBase.hurt_player(bolt, h, source):
				ticks_hit += 1
	if life <= 0.0:
		queue_free()
