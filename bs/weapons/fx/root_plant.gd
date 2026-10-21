class_name RootPlant
extends Node3D
## A Root Canal garden (plantAt / updatePlants, index.html:5795-5840): a snapping bio-plant that roots up to
## `max_targets` non-armoured enemies (picked within pick_r, held within root_r; status "rooted" refreshed every
## frame) and chews each for bite_dmg every `bite` seconds. V3 plants spit spore globs. burrow_to() moves it
## underground to a new spot (Uproot & Replant) without rooting on the way. Group "root_plants".

var weapon: BSWeapon
var life: float = 6.0
var root_r: float = 3.2
var pick_r: float = 3.0
var bite: float = 0.5
var bite_dmg: float = 8.0
var max_targets: int = 1
var root_time: float = 0.3
var spores: bool = false
var braces: bool = false
var gold: bool = false
var details: int = 0
var targets: Array[Node3D] = []
var dead: bool = false
var moving: bool = false
var bites: int = 0
var _dest: Vector3 = Vector3.ZERO
var _speed: float = 12.0
var _bite_t: float = 0.0
var _spit_t: float = 1.5
var _age: float = 0.0
var _jaw: Node3D
var _vis: Node3D


func _ready() -> void:
	top_level = true
	add_to_group(&"root_plants")
	_spit_t = randf_range(float(WeaponData.param(&"root_canal", "spore_min", 1.5)), float(WeaponData.param(&"root_canal", "spore_max", 2.5)))
	_vis = Node3D.new()
	add_child(_vis)
	var stem: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.16
	cm.height = 1.0
	stem.mesh = cm
	stem.position.y = 0.5
	stem.material_override = WeaponFX.glow_mat(Color("#3a8a2a"))
	_vis.add_child(stem)
	_jaw = Node3D.new()
	_jaw.position.y = 1.15
	_vis.add_child(_jaw)
	var upper: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.34
	cone.height = 0.45
	upper.mesh = cone
	upper.material_override = WeaponFX.glow_mat(Color("#bdff6a"))
	_jaw.add_child(upper)
	for i: int in 6:                                  # teeth (with braces at Ω)
		var a: float = TAU * i / 6.0
		WeaponFX.block(_jaw, Vector3(0.05, 0.1, 0.05), Vector3(cos(a) * 0.28, -0.24, sin(a) * 0.28), Color("#ffd23e") if gold else Color("#f2f0e0"))
	if details >= 1:
		WeaponFX.block(_vis, Vector3(0.5, 0.25, 0.5), Vector3(0, 0.12, 0), Color("#b5562b"))          # terracotta pot
	for k: int in 2:
		var leaf: MeshInstance3D = WeaponFX.block(_vis, Vector3(0.45, 0.04, 0.16), Vector3(0.22 * (1 - 2 * k), 0.55, 0), Color("#5acc2a"))
		leaf.rotation.z = 0.5 * (1 - 2 * k)


func wither() -> void:
	if dead:
		return
	dead = true
	if get_parent() != null:
		WeaponFX.flash(get_parent(), global_position + Vector3.UP * 0.6, Color("#5acc2a"), 0.4, 0.25)
	queue_free()


func burrow_to(dest: Vector3, speed: float, bonus: float) -> void:
	moving = true
	_dest = dest
	_speed = speed
	life += bonus
	targets.clear()


func _physics_process(dt: float) -> void:
	if dead:
		return
	if weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	life -= dt
	if _age == 0.0:
		WeaponFX.ring(get_parent(), global_position, root_r, Color("#5acc2a"), 0.4)
	_age += dt
	if life <= 0.0:
		wither()
		return
	_jaw.rotation.x = sin(_age * 11.0) * 0.4          # chomping
	if moving:
		var to: Vector3 = _dest - global_position
		var step: float = _speed * dt
		_vis.position.y = -0.9
		if to.length() <= step:
			global_position = _dest
			moving = false
			_vis.position.y = 0.0
			WeaponFX.ring(get_parent(), global_position, root_r, Color("#5acc2a"), 0.4)
		else:
			global_position += to.normalized() * step
		return
	_refresh_targets()
	for e: Node3D in targets:
		weapon.mgr.apply_status(e, &"rooted", root_time)
		if braces:
			e.set_meta(&"bs_braces", true)
	_bite_t -= dt
	if _bite_t <= 0.0 and not targets.is_empty():
		_bite_t = bite
		for e2: Node3D in targets.duplicate():
			if BSWeapon.alive(e2):
				bites += 1
				weapon.deal(e2, roundf(bite_dmg), BSWeapon.center_of(e2))
	if spores:
		_spit_t -= dt
		if _spit_t <= 0.0:
			_spit_t = randf_range(float(WeaponData.param(&"root_canal", "spore_min", 1.5)), float(WeaponData.param(&"root_canal", "spore_max", 2.5)))
			var o: Node3D = weapon.nearest_enemy(global_position, float(WeaponData.param(&"root_canal", "spore_range", 12.0)), targets)
			if o != null:
				weapon.call("spore", global_position + Vector3.UP * 1.4, o)


func _refresh_targets() -> void:
	var keep: Array[Node3D] = []
	for e: Node3D in targets:
		if BSWeapon.alive(e) and _flat_dist(e) < root_r:
			keep.append(e)
	targets = keep
	if targets.size() >= max_targets:
		return
	var cands: Array = []
	for e2: Node3D in weapon.enemies(targets):
		if WeaponData.prop_bool(e2, "armored") or e2.is_in_group(&"bosses"):
			continue
		var dd: float = _flat_dist(e2)
		if dd < pick_r:
			cands.append([dd, e2])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for c: Array in cands:
		if targets.size() >= max_targets:
			break
		targets.append(c[1])


func _flat_dist(e: Node3D) -> float:
	var d: Vector3 = e.global_position - global_position
	return Vector2(d.x, d.z).length()
