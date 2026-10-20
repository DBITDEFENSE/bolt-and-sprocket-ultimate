class_name BoltCrate
extends EnemyBase
## Breakable bolt crate prop (the original's default 'crate': 10 HP, 5 bolts; spawnEnemy index.html:6276,
## killEnemy drop table :5322). Groups "damageable", "enemies", "props". Solid (layer 6), so Bolt stands
## on it and bumps into it. No AI; bursts into a bolt fountain and wood chunks.


func _build_visual() -> void:
	var wood: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#b07830"))))
	flash_mats.append(wood)
	var s: float = 1.0
	EnemyFx.box(visual, Vector3(s, s, s), Vector3(0, s * 0.5, 0), wood)
	var band: StandardMaterial3D = EnemyFx.mat(Color("#5a3a18"))
	for y: float in [0.1, 0.9]:
		EnemyFx.box(visual, Vector3(s + 0.04, 0.1, s + 0.04), Vector3(0, y, 0), band)
	EnemyFx.box(visual, Vector3(0.36, 0.36, 0.05), Vector3(0, 0.5, s * 0.5 + 0.02), EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 0.8))
	EnemyFx.box(visual, Vector3(0.05, 0.36, 0.36), Vector3(s * 0.5 + 0.02, 0.5, 0), EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 0.8))


func _build_body() -> void:
	super._build_body()
	add_to_group(&"props")
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 1.0)
	_shape.shape = bs
	_shape.position.y = 0.5


func _on_activate() -> void:
	collision_layer = 1 << 5        # solid prop
	gravity_on = false


func get_center() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func _ai(_dt: float) -> void:
	desired_vel = Vector3.ZERO
	if state == State.SPAWN:
		_set_state(State.IDLE)
