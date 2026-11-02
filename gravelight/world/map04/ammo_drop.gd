class_name AmmoDrop
extends Node3D
## UPDATE 10 §3 (contract C6 `ammo_out`, T-156): an ammunition tin shaken out of the bay's stowage net by a
## decompression. Walk over it: the gun in your hands is refilled (one ammo box's worth, free). The host decides who
## took it (WeaponHolder.refill_weapon forwards to the owner) and mirrors the pickup; it fades after `life_s`.
## Group "ammo_drops".

@export var life_s: float = 90.0
@export var reach_m: float = 1.3

var taken: bool = false
var _t: float = 0.0
var _glow: OmniLight3D


func _ready() -> void:
	add_to_group(&"ammo_drops")
	Props.block(self, Vector3(-0.22, 0, -0.13), Vector3(0.22, 0.26, 0.13), "olive_drab")
	Props.block(self, Vector3(-0.23, 0.2, -0.14), Vector3(0.23, 0.24, 0.14), "iron")
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 0.5, 0)
	_glow.light_color = Color(0.95, 0.85, 0.5)
	_glow.light_energy = 0.6
	_glow.omni_range = 2.0
	_glow.shadow_enabled = false
	add_child(_glow)
	# it lands: a short drop from the net above
	position.y += 2.4
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:y", position.y - 2.4, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if taken:
		return
	_t += delta
	if _t >= life_s:
		queue_free()
		return
	_glow.light_energy = 0.4 + 0.25 * sin(_t * 4.0)
	if not Net.is_authority():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or p.weapons == null:
			continue
		if p.global_position.distance_to(global_position) > reach_m:
			continue
		var w: WeaponInstance = p.weapons.current()
		if w == null or w.is_full():
			continue
		p.weapons.refill_weapon(w.base_id())
		Interactable.feedback_2d(p, "reload_end", 0.0)
		_taken()
		Net.mirror(self, &"_taken")
		return


func _taken() -> void:
	taken = true
	queue_free()
