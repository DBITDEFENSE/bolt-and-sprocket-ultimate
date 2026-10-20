class_name EnemyShockwave
extends Node3D
## An expanding ground ring that hurts Bolt once if he's on the ground where the ring passes
## (addShockwave / updateHazards, index.html:7548-7590): r grows at `speed`, hits when
## |dist - r| < 0.9 and Bolt is less than 1.9 m above the centre. Jump it.

const MAX_R: float = 22.0

var center: Vector3 = Vector3.ZERO
var speed: float = 10.0
var dmg: float = 16.0
var rr: float = 1.0
var hit_done: bool = false
var source: Node = null
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


static func spawn(parent: Node, center_: Vector3, speed_: float, dmg_: float, source_: Node = null) -> EnemyShockwave:
	var s: EnemyShockwave = EnemyShockwave.new()
	s.center = center_
	s.speed = speed_
	s.dmg = dmg_
	s.source = source_
	parent.add_child(s)
	s.global_position = center_ + Vector3(0, 0.35, 0)
	return s


func _ready() -> void:
	_mat = EnemyFx.glow(Color(1.0, 0.54, 0.18), 0.9)
	_mesh = EnemyFx.torus(self, 0.94, 1.0, Vector3.ZERO, _mat)


func _physics_process(delta: float) -> void:
	rr += speed * delta
	_mesh.scale = Vector3(rr, 1.0, rr)
	_mat.albedo_color.a = clampf(1.0 - rr / MAX_R, 0.0, 1.0)
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not hit_done and bolt != null and bool(bolt.call("is_alive")):
		var p: Vector3 = bolt.global_position
		var d: float = Vector2(p.x - center.x, p.z - center.z).length()
		var grounded: bool = p.y - center.y < 1.9
		if absf(d - rr) < 0.9 and grounded:
			hit_done = true
			var h: Combat.Hit = Combat.Hit.make(dmg, Combat.Type.KINETIC, source)
			h.point = p
			h.dir = Vector3(p.x - center.x, 0, p.z - center.z).normalized()
			h.knock = 8.0
			EnemyBase.hurt_player(bolt, h, source)
	if rr > MAX_R:
		queue_free()
