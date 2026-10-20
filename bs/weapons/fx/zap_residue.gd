class_name ZapResidue
extends Node3D
## Electric residue patch left by the Sprocket Zap (firePatch 5077, ticking like a fire patch: `amount` every `tick`
## seconds to enemies within `radius`). Without Surge Protector, overlapping patches don't stack: an enemy is
## ticked at most once per `tick` across all Zap patches.

var weapon: BSWeapon
var radius: float = 1.4
var life: float = 1.6
var tick: float = 0.4
var amount: float = 4.0
var stacks: bool = false
var _acc: float = 0.0


func _ready() -> void:
	top_level = true
	add_to_group(&"zap_residue")
	WeaponFX.disc(self, radius, Color("#3ee6ff"), 0.45)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	_acc += dt
	if _acc < tick:
		return
	_acc -= tick
	var now: int = Engine.get_physics_frames()
	var gap: float = tick * Engine.physics_ticks_per_second * 0.9
	for e: Node3D in Combat.in_radius(get_tree(), global_position + Vector3(0, 0.5, 0), radius):
		if not stacks:
			var lastf: int = int(e.get_meta(&"zap_residue_frame", -100000))
			if float(now - lastf) < gap:
				continue
			e.set_meta(&"zap_residue_frame", now)
		weapon.deal(e, amount, e.call("get_center"))
