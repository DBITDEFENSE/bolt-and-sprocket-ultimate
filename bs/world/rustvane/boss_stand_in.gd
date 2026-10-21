class_name RustvaneBossStandIn
extends StaticBody3D
## Placeholder used only when EnemySpawner.spawn(&"rustvane_sentinel" / &"content_creator", ...) returns null
## (the bosses builder hasn't landed them yet), so Rustvane stays playable end to end. It is a damageable boss
## with no AI: the boss events fire (boss_started / boss_health / boss_defeated, enemy_killed) so the arena,
## the story beats and the exit run exactly as they will with the real boss. HP from the level data.
## Groups: enemies, damageable, bosses.

var boss_id: StringName = &""
var display_name: String = ""
var hp: float = 300.0
var max_hp: float = 300.0
var radius: float = 1.6
var body_color: Variant = "#e8e0d4"
var _dead: bool = false
var _started: bool = false


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"damageable")
	add_to_group(&"bosses")
	collision_layer = 1 << 2
	collision_mask = 0
	set_meta(&"enemy_id", String(boss_id))
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = radius
	sh.height = 4.0
	cs.shape = sh
	cs.position.y = 2.0
	add_child(cs)
	LevelKit.cylinder(self, Vector3(0, 1.4, 0), radius, 2.8, body_color)
	LevelKit.cylinder(self, Vector3(0, 3.2, 0), radius * 0.6, 0.9, "#39404f")
	LevelKit.cylinder(self, Vector3(0, 3.3, radius * 0.62), 0.42, 0.12, "#ff4d9d", false, "z", -1.0, 1.6)
	var lbl: Label3D = Label3D.new()
	lbl.text = display_name + "\n(stand-in)"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position.y = 4.8
	lbl.font_size = 48
	lbl.pixel_size = 0.01
	add_child(lbl)
	var st: StatusEffects = StatusEffects.new()
	st.name = "Status"
	add_child(st)
	start_fight()


func start_fight() -> void:
	if _started:
		return
	_started = true
	EventBus.boss_started.emit(boss_id, display_name)


func take_damage(hit: Combat.Hit) -> bool:
	if _dead:
		return false
	hp = maxf(0.0, hp - hit.amount)
	EventBus.enemy_hit.emit(self, hit, hp <= 0.0)
	EventBus.boss_health.emit(boss_id, hp / max_hp, 0.0)
	if hp <= 0.0:
		_dead = true
		EventBus.enemy_killed.emit(self, hit.weapon_id)
		EventBus.boss_defeated.emit(boss_id)
		queue_free()
		return true
	return false


func get_center() -> Vector3:
	return global_position + Vector3(0, 2.0, 0)


func is_alive() -> bool:
	return not _dead
