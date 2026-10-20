class_name VoidRift
extends Node3D
## The Void Ripper's alt-fire tear. For `life` seconds it pulls non-heavy, non-boss enemies within `radius` toward
## its centre at `pull` m/s and keeps them GRAVITY-CLUMPED (refreshed every frame for `refresh` s). No damage.
## Enemies move themselves: the rift calls `apply_pull(center: Vector3, speed: float, dt: float)` when an enemy has
## it, else drives EnemyBase.override_point one step toward the centre. Group "void_rifts" (charged orbs detonating inside get RIFT COLLAPSE).

var weapon: BSWeapon
var life: float = 3.0
var radius: float = 5.0
var pull: float = 6.0
var refresh: float = 0.4
var _vis: MeshInstance3D


func _ready() -> void:
	top_level = true
	add_to_group(&"void_rifts")
	_vis = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	_vis.mesh = s
	_vis.material_override = WeaponFX.glow_mat(Color("#3a0a66"))
	add_child(_vis)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = radius - 0.1
	t.outer_radius = radius
	ring.mesh = t
	ring.material_override = WeaponFX.glow_mat(Color("#a64dff"), 0.35)
	add_child(ring)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	_vis.rotation.y += dt * 4.0
	for e: Node3D in Combat.in_radius(get_tree(), global_position, radius):
		if e.is_in_group(&"bosses") or WeaponData.prop_bool(e, "heavy") or e.is_in_group(&"props"):
			continue
		var st: StatusEffects = e.get_node_or_null("Status") as StatusEffects
		if st != null:
			st.apply(&"gravity_clumped", refresh)
		if e.has_method("apply_pull"):
			e.call("apply_pull", global_position, pull, dt)
		elif "override_point" in e:
			var to: Vector3 = global_position - e.global_position
			to.y = 0.0
			if to.length() > 0.4:
				e.set("override_point", e.global_position + to.normalized() * minf(pull * dt, to.length()))
