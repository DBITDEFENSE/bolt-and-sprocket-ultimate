class_name ChargedWeapon
extends ProjectileWeapon
## Hold to charge, release to fire (pressFire / releaseFire 4479, charge += dt x 1.15 in updateWeapons 5180).
## Params: charge_time (s to full), dmg_per_charge, speed_per_charge. Override release(c) for gun-specific shots.

var charging: bool = false
var charge: float = 0.0
var held_t: float = 0.0


func _can_auto_fire() -> bool:
	return false


func charge_time() -> float:
	return maxf(0.05, P("charge_time", 0.87))


func charge_cap() -> float:
	return 1.0


func _on_fire_pressed() -> void:
	if cooldown > 0.0:
		return
	charging = true
	charge = 0.0
	held_t = 0.0


func _on_fire_released() -> void:
	if not charging:
		return
	var c: float = charge
	var t: float = held_t
	charging = false
	charge = 0.0
	release(c, t)


func _on_cancel() -> void:
	charging = false
	charge = 0.0


func _tick(dt: float, is_equipped: bool) -> void:
	if charging and is_equipped:
		held_t += dt
		charge = minf(charge_cap(), charge + dt / charge_time())


func release(c: float, _held: float) -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	launch(dmg(float(d.get("damage", 0)) + P("dmg_per_charge", 0.0) * c), {"charge": c})
	recoil(float(d.get("recoil", 0.01)) + P("recoil_per_charge", 0.0) * c)
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["charge"] = charge if charging else -1.0
	return s
