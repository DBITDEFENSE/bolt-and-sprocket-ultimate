class_name CraneHook
extends Node3D
## Repo-Tron's magnet crane hook (BS_ENEMIES §4.1, phase 2+). While it holds a repossessed gun it is a
## damageable weak point (groups "damageable", "enemies"; 60 HP; mallet or guns). Smashing it drops the
## gun back to Bolt and feeds the boss's BREAK meter. Otherwise it is inert (is_alive() is false).

signal smashed

var boss: Node = null
var hp: float = 60.0
var max_hp: float = 60.0
var radius: float = 0.7
var armed: bool = false
var elite: bool = false
var status: StatusEffects
var _gun: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _flash: float = 0.0
var _hook_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"damageable")
	add_to_group(&"enemies")
	status = StatusEffects.new()
	status.name = "Status"
	add_child(status)
	_hook_mat = EnemyFx.mat(Color("#39404f"))
	EnemyFx.cyl(self, 0.06, 1.6, Vector3(0, 0.8, 0), EnemyFx.mat(Color("#232323")))           # cable
	EnemyFx.torus(self, 0.18, 0.32, Vector3.ZERO, _hook_mat).rotation.x = PI / 2
	_lamp_mat = EnemyFx.mat(Color("#3ee6ff"), Color("#3ee6ff"), 0.0)
	_lamp_mat.emission_enabled = true
	EnemyFx.sphere(self, 0.14, Vector3(0, 0.3, 0), _lamp_mat)
	_gun = EnemyFx.box(self, Vector3(0.2, 0.3, 0.7), Vector3(0, -0.45, 0), EnemyFx.mat(Color("#c8a040"), Color("#ffd23e"), 0.6))
	var tag: Label3D = Label3D.new()
	tag.text = "REPOSSESSED"
	tag.modulate = Color("#ff3b3b")
	tag.font_size = 32
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = -1.0
	tag.name = "Tag"
	_gun.add_child(tag)
	disarm()


func arm(hp_: float) -> void:
	max_hp = hp_
	hp = hp_
	armed = true
	_gun.visible = true


func disarm() -> void:
	armed = false
	_gun.visible = false


func is_alive() -> bool:
	return armed and hp > 0.0


func get_center() -> Vector3:
	return global_position + Vector3(0, -0.2, 0)


func is_weak_point(_point: Vector3) -> bool:
	return armed


func take_damage(hit: Combat.Hit) -> bool:
	if not is_alive():
		return false
	hp -= hit.amount
	_flash = 0.12
	EventBus.enemy_hit.emit(self, hit, hp <= 0.0)
	if hp <= 0.0:
		disarm()
		smashed.emit()
		return true
	return false


func _process(delta: float) -> void:
	_flash -= delta
	_lamp_mat.emission_energy_multiplier = (3.0 + sin(Time.get_ticks_msec() / 80.0)) if armed else 0.3
	_hook_mat.emission_enabled = _flash > 0.0
	_hook_mat.emission = Color.WHITE
	_hook_mat.emission_energy_multiplier = 0.9
