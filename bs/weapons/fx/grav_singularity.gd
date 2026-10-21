class_name GravSingularity
extends Node3D
## The Grav Grenade's micro-singularity (spawnSingularity / updateSingularities, index.html:5648-5687). Pulls
## non-heavy, non-boss enemies in radius toward its centre at min(d, pull_cap) x pull_k m/s (apply_pull(), else
## EnemyBase.override_point, else a static target is moved directly), keeps them GRAVITY-CLUMPED, optionally crushes,
## vacuums bolt pickups, then collapses: everything in radius is launched (Hit.launch) and, at V5, damaged.
## `held` pauses its timer (alt-fire HOLD). Group "singularities".

var weapon: BSWeapon
var life: float = 3.0
var radius: float = 6.5
var pull_k: float = 1.6
var pull_cap: float = 7.0
var clump_time: float = 0.4
var crush: bool = false
var crush_amount: float = 6.0
var crush_tick: float = 0.5
var crush_from: float = 1.0
var rift_mul: float = 2.0
var launch: float = 11.0
var collapse_amount: float = 0.0
var bolt_r: float = 8.0
var bolt_rate: float = 2.0
var slow_heavies: bool = false
var slow_time: float = 0.5
var held: bool = false
var collapsed: bool = false
var age: float = 0.0
var crushed: int = 0
var _crush_t: Dictionary = {}
var _core: MeshInstance3D
var _ring: MeshInstance3D


func _ready() -> void:
	top_level = true
	add_to_group(&"singularities")
	_core = MeshInstance3D.new()
	_core.mesh = WeaponFX.shot_mesh("sphere", 0.4)
	_core.material_override = WeaponFX.glow_mat(Color("#1a0833"))
	add_child(_core)
	_ring = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.05
	_ring.mesh = t
	_ring.material_override = WeaponFX.glow_mat(Color("#c07dff"), 0.8)
	add_child(_ring)
	var halo: MeshInstance3D = WeaponFX.disc(self, radius, Color("#8a4dff"), 0.12)
	halo.position.y = -0.55


func rift_overlap() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"void_rifts"):
		var r: Node3D = n as Node3D
		if r != null and r.global_position.distance_to(global_position) < radius + float(r.get("radius")):
			return true
	return false


func _physics_process(dt: float) -> void:
	if collapsed:
		return
	if weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	age += dt
	if not held:
		life -= dt
	_core.rotation.y += dt * 8.0
	_ring.rotation.z += dt * 3.0
	_ring.scale = Vector3.ONE * (1.5 + sin(age * 8.3) * 0.5)
	var crush_now: bool = crush and age >= crush_from
	var cm: float = rift_mul if crush_now and rift_overlap() else 1.0
	for e: Node3D in Combat.in_radius(get_tree(), global_position, radius):
		if e.is_in_group(&"bosses") or e.is_in_group(&"props"):
			continue
		if WeaponData.prop_bool(e, "heavy") or WeaponData.prop_bool(e, "armored"):
			if slow_heavies and not e.is_in_group(&"bosses"):
				weapon.mgr.apply_status(e, &"slowed", slow_time)
			continue
		weapon.mgr.apply_status(e, &"gravity_clumped", clump_time)
		_pull(e, dt)
		if crush_now:
			var ct: float = float(_crush_t.get(e, 0.0)) - dt
			if ct <= 0.0:
				ct = crush_tick
				weapon.deal(e, roundf(crush_amount * cm), BSWeapon.center_of(e))
				crushed += 1
			_crush_t[e] = ct
	for n: Node in get_tree().get_nodes_in_group(&"pickups"):
		var pk: Node3D = n as Node3D
		if pk == null or pk is AmmoOrb or not ("kind" in pk) or StringName(str(pk.get("kind"))) != &"bolt":
			continue
		if pk.global_position.distance_to(global_position) < bolt_r:
			pk.global_position = pk.global_position.lerp(global_position, 1.0 - exp(-bolt_rate * dt))
	if life <= 0.0:
		collapse()


func _pull(e: Node3D, dt: float) -> void:
	var to: Vector3 = global_position - e.global_position
	to.y = 0.0
	var dd: float = to.length()
	if dd < 0.3:
		return
	var spd: float = minf(dd, pull_cap) * pull_k
	if e.has_method("apply_pull"):
		e.call("apply_pull", global_position, spd, dt)
	elif "override_point" in e:
		e.set("override_point", e.global_position + to.normalized() * minf(spd * dt, dd))
	else:
		e.global_position += to.normalized() * minf(spd * dt, dd)


## Collapse: pop everything up (and, at V5, hurt it).
func collapse() -> void:
	if collapsed:
		return
	collapsed = true
	for e: Node3D in Combat.in_radius(get_tree(), global_position, radius):
		if e.is_in_group(&"props"):
			continue
		var c: Vector3 = BSWeapon.center_of(e)
		var h: Combat.Hit = weapon.make_hit(roundf(collapse_amount), c, c - global_position)
		h.launch = launch
		weapon.mgr.deal_damage(e, h)
	WeaponFX.blast(get_parent(), global_position, radius * 0.6, Color("#c07dff"))
	weapon.popup.emit("bs.weapon.fx.collapse", global_position)
	weapon.call("shake", 0.35)
	queue_free()
