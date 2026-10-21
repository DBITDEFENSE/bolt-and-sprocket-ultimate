class_name MiddlemanDrone
extends Node3D
## A deployed Middleman drone (updateOneMiddleman, index.html:5714): hovers and bobs, fires at the nearest enemy
## within range (or its Reassign focus) every shot_interval, for `life` seconds. Groups: "middleman_drones",
## "player_allies", and "enemy_decoys" when it draws aggro (EnemyBase._find_target prefers a nearer decoy); every
## aggro_reroll s each non-boss enemy within aggro_radius retargets it with aggro_chance. It can be destroyed:
## take_damage / get_center / is_alive / radius, shield first (V5). Its shots go through weapon.deal (gun XP).

var weapon: BSWeapon
var life: float = 12.0
var age: float = 0.0
var shot_interval: float = 0.35
var range_m: float = 22.0
var shot_dmg: float = 8.0
var hp: float = 120.0
var max_hp: float = 120.0
var shield: float = 0.0
var dmg_taken: float = 1.0
var aggro: bool = true
var aggro_radius: float = 15.0
var aggro_chance: float = 0.7
var aggro_reroll: float = 3.0
var radius: float = 0.45
var kills: int = 0
var shots: int = 0
var idle_t: float = 0.0
var argued_late: bool = false
var clip_on: bool = false
var details: int = 0
var gold: bool = false
var ended: bool = false
var focus_target: Node3D = null
var focus_t: float = 0.0
var _fire_t: float = 0.0
var _aggro_t: float = 0.0
var _body: Node3D
var _shield_mi: MeshInstance3D
var _base_y: float = 0.0


func _ready() -> void:
	top_level = true
	add_to_group(&"middleman_drones")
	add_to_group(&"player_allies")
	if aggro:
		add_to_group(&"enemy_decoys")
	_build()


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var orange: Color = Color("#ffb02e")
	WeaponFX.block(_body, Vector3(0.62, 0.42, 0.5), Vector3.ZERO, orange.darkened(0.1))                 # hull
	WeaponFX.block(_body, Vector3(0.66, 0.05, 0.66), Vector3(0, 0.28, 0), Color("#232838"))             # rotor deck
	WeaponFX.block(_body, Vector3(0.1, 0.24, 0.1), Vector3(0, -0.3, 0), Color("#ff5d2e"))                # gun stub
	WeaponFX.block(_body, Vector3(0.36, 0.12, 0.04), Vector3(0, 0.02, -0.26), Color("#3ee6ff"))          # visor
	var tie_c: Color = Color("#ffd23e") if gold else Color("#c0392b")
	WeaponFX.block(_body, Vector3(0.08, 0.26, 0.03), Vector3(0, -0.12, -0.27), tie_c)                    # the tie (clip-on for #2)
	if clip_on:
		WeaponFX.block(_body, Vector3(0.14, 0.03, 0.04), Vector3(0, 0.02, -0.28), Color("#d8dee9"))
	if details >= 1:
		WeaponFX.block(_body, Vector3(0.12, 0.16, 0.02), Vector3(0.22, -0.1, -0.27), Color("#f2f0e0"))   # lanyard badge
	if details >= 2:
		WeaponFX.block(_body, Vector3(0.04, 0.04, 0.4), Vector3(0.36, 0, -0.1), Color("#8b95a8"))        # clipboard arm
		WeaponFX.block(_body, Vector3(0.2, 0.26, 0.02), Vector3(0.36, 0.05, -0.32), Color("#c9a26b"))
	if details >= 3:
		WeaponFX.block(_body, Vector3(0.5, 0.03, 0.08), Vector3(0, 0.36, 0), Color("#232838"))           # second rotor
	if details >= 4:
		WeaponFX.block(_body, Vector3(0.1, 0.12, 0.1), Vector3(-0.24, 0.27, 0.12), Color("#f2f0e0"))      # the mug
	_shield_mi = MeshInstance3D.new()
	_shield_mi.mesh = WeaponFX.shot_mesh("sphere", 0.62)
	_shield_mi.material_override = WeaponFX.glow_mat(Color("#3ee6ff"), 0.18)
	_shield_mi.visible = shield > 0.0
	add_child(_shield_mi)


func get_center() -> Vector3:
	return global_position


func is_alive() -> bool:
	return not ended and hp > 0.0


func take_damage(hit: Combat.Hit) -> bool:
	if not is_alive():
		return false
	var a: float = hit.amount * dmg_taken
	if shield > 0.0:
		var s: float = minf(shield, a)
		shield -= s
		a -= s
		_shield_mi.visible = shield > 0.0
	hp -= a
	if hp <= 0.0:
		WeaponFX.blast(get_parent(), global_position, 1.2, Color("#ffb02e"))
		_end(false)
		return true
	return false


func focus(e: Node3D, secs: float) -> void:
	focus_target = e
	focus_t = secs


func _physics_process(dt: float) -> void:
	if ended:
		return
	if weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	if age == 0.0:
		_base_y = global_position.y
	age += dt
	life -= dt
	idle_t += dt
	_body.rotation.y += dt * 2.0
	global_position.y = _base_y + sin(age * 2.5) * 0.12
	focus_t -= dt
	if life <= 0.0:
		_end(true)
		return
	if aggro:
		_aggro_t -= dt
		if _aggro_t <= 0.0:
			_aggro_t = aggro_reroll
			for e: Node3D in Combat.in_radius(get_tree(), global_position, aggro_radius):
				if e.is_in_group(&"bosses") or not ("target" in e):
					continue
				if weapon.mgr.rng.randf() < aggro_chance:
					e.set("target", self)
	_fire_t -= dt
	if _fire_t > 0.0:
		return
	var tgt: Node3D = focus_target if focus_t > 0.0 and BSWeapon.alive(focus_target) else _nearest()
	if tgt == null:
		return
	_fire_t = shot_interval
	var c: Vector3 = BSWeapon.center_of(tgt)
	WeaponFX.tracer(get_parent(), global_position + Vector3(0, -0.3, 0), c, Color("#ffd23e"), 0.06, 0.06)
	shots += 1
	idle_t = 0.0
	if weapon.deal(tgt, roundf(shot_dmg), c, c - global_position):
		kills += 1
		weapon.call("on_drone_kill", self)


func _nearest() -> Node3D:
	var best: Node3D = null
	var bd: float = range_m
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not BSWeapon.alive(e) or e.is_in_group(&"props"):
			continue
		var dd: float = BSWeapon.center_of(e).distance_to(global_position)
		if dd < bd and weapon.mgr.ray_world(global_position, BSWeapon.center_of(e)).is_empty():
			bd = dd
			best = e
	return best


func _end(contract_done: bool) -> void:
	if ended:
		return
	ended = true
	remove_from_group(&"enemy_decoys")
	if contract_done and weapon != null and is_instance_valid(weapon):
		weapon.call("on_drone_end", self)
	queue_free()
