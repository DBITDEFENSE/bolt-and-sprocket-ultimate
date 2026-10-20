class_name BeamWeapon
extends BSWeapon
## Held beams (Frostbyte, Hostile Takeover baseline): while the trigger is held, the best target in a narrow cone
## takes dps and the status; ammo drains 1 per `interval` (x rate mod). Params: range, dot, dps, status, status_time.

var target: Node3D = null


func _can_auto_fire() -> bool:
	return false


func _tick(dt: float, is_equipped: bool) -> void:
	if not is_equipped or not fire_held:
		target = null
		return
	if not drain_ammo(dt / maxf(0.01, interval())):
		target = null
		return
	target = _pick()
	var from: Vector3 = mgr.muzzle_pos()
	var end: Vector3 = from + aim() * P("range", 18.0)
	if target != null:
		end = target.call("get_center")
		var st: Dictionary = {str(p["status"]): P("status_time", 0.5)} if p.has("status") else {}
		var h: Combat.Hit = make_hit(dmg(P("dps", float(d.get("damage", 6)))) * dt, end, end - from)
		h.status = st
		mgr.deal_damage(target, h)
	WeaponFX.tracer(mgr.world(), from, end, WeaponData.color(id), 0.08, dt * 1.5)


func _pick() -> Node3D:
	var best: Node3D = null
	var bd: float = P("range", 18.0)
	var from: Vector3 = origin()
	var dir: Vector3 = aim()
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not bool(e.call("is_alive")):
			continue
		var to: Vector3 = (e.call("get_center") as Vector3) - from
		var dd: float = to.length()
		if dd < bd and to.normalized().dot(dir) > P("dot", 0.9) and mgr.ray_world(from, e.call("get_center")).is_empty():
			bd = dd
			best = e
	return best
