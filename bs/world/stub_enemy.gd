class_name StubEnemy
extends CharacterBody3D
## Stand-in enemy used only when EnemySpawner is unavailable (or returns null). Implements the damageable
## contract (M1_CONTRACTS) with a capsule, gravity and no AI, so encounters, quests and the boss flow can run
## before the enemy builder's code lands. HP per id comes from data/bs/levels/level_common.json "stub_hp".

var enemy_id: StringName = &""
var hp: float = 30.0
var max_hp: float = 30.0
var radius: float = 0.5
var _dead: bool = false


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"damageable")
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 5)
	var common: Variant = Data.table("bs/levels/level_common")
	if common is Dictionary:
		max_hp = float(((common as Dictionary).get("stub_hp", {}) as Dictionary).get(String(enemy_id), 30.0))
	hp = max_hp
	var flying: bool = enemy_id == &"vulture_drone"
	if enemy_id == &"repo_tron":
		add_to_group(&"bosses")
		radius = 2.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = radius
	sh.height = maxf(radius * 2.0, 1.6 if enemy_id != &"repo_tron" else 4.0)
	cs.shape = sh
	cs.position.y = sh.height * 0.5
	add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = sh.radius
	cm.height = sh.height
	mi.mesh = cm
	mi.position.y = sh.height * 0.5
	mi.material_override = LevelKit.mat("#c9482a")
	add_child(mi)
	var st: StatusEffects = StatusEffects.new()
	st.name = "Status"
	add_child(st)
	set_physics_process(not flying)
	if enemy_id == &"repo_tron":
		EventBus.boss_started.emit(&"repo_tron", "REPO-TRON")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	move_and_slide()


func take_damage(hit: Combat.Hit) -> bool:
	if _dead:
		return false
	hp -= hit.amount
	EventBus.enemy_hit.emit(self, hit, hp <= 0.0)
	if is_in_group(&"bosses"):
		EventBus.boss_health.emit(enemy_id, maxf(0.0, hp / max_hp), 0.0)
	if hp <= 0.0:
		_dead = true
		EventBus.enemy_killed.emit(self, hit.weapon_id)
		if is_in_group(&"bosses"):
			EventBus.boss_defeated.emit(enemy_id)
		queue_free()
		return true
	return false


func get_center() -> Vector3:
	return global_position + Vector3(0, radius + 0.4, 0)


func is_alive() -> bool:
	return not _dead
