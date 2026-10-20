class_name Grenade
extends RigidBody3D
## A thrown Mk 2 frag. Bounces, then detonates when the fuse runs out.

var fuse: float = 4.0
var cfg: Dictionary = {}
var by_player: int = 1


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 | (1 << 5) | (1 << 8)
	mass = 0.6
	continuous_cd = true
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.8
	physics_material_override = pm
	linear_damp = 0.4
	angular_damp = 2.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.06
	cs.shape = sph
	add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: SphereMesh = SphereMesh.new()
	m.radius = 0.06
	m.height = 0.13
	mi.mesh = m
	mi.material_override = Interactable.greybox_mat(Color(0.25, 0.3, 0.18))
	add_child(mi)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		Explosion.detonate(self, global_position, cfg, by_player)
		queue_free()
