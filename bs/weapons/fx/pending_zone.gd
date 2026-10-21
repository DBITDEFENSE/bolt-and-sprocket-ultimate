class_name PendingZone
extends Node3D
## Patent Pending V5: the detonation leaves a "PENDING" zone (r4, 4 s) that forks one lawsuit per second at the
## nearest enemy (through the weapon's fork(), so lawsuits stamp SERVED and count as the gun's damage).

var weapon: BSWeapon
var radius: float = 4.0
var life: float = 4.0
var interval: float = 1.0
var _acc: float = 0.0
var _disc: MeshInstance3D


func _ready() -> void:
	top_level = true
	add_to_group(&"pending_zones")
	_disc = WeaponFX.disc(self, radius, Color("#9dff5a"), 0.22)
	_disc.position.y = 0.05
	var stamp: Label3D = Label3D.new()
	stamp.text = "PENDING"
	stamp.modulate = Color("#ffd23e")
	stamp.font_size = 64
	stamp.outline_size = 12
	stamp.pixel_size = 0.008
	stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stamp.position.y = 1.4
	add_child(stamp)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	_disc.rotation.y += dt * 0.6
	_acc += dt
	if _acc >= interval:
		_acc -= interval
		weapon.call("fork", global_position + Vector3.UP * 0.8, [], 0)
