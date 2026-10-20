class_name LobbedWeapon
extends ProjectileWeapon
## Arcing throws that act where they land (B.O.O.M. Box, Grav Grenade, deployables). Params: speed, up, gravity,
## life, radius, status + status_time / duration, damage. Override on_land(pos, direct) for the real behaviour.
## Generic fallback: "deployable" archetype drops a DeployedTurret; otherwise an area status (+ blast if damage).


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	_land(pr, point, target)
	return false


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	_land(pr, point + normal * 0.05, null)
	return false


func on_projectile_expire(pr: BSProjectile) -> void:
	_land(pr, pr.global_position, null)


func _land(pr: BSProjectile, pos: Vector3, direct: Node3D) -> void:
	if bool(pr.data.get("landed", false)):
		return
	pr.data["landed"] = true
	on_land(pos, direct, pr.data)


func on_land(pos: Vector3, _direct: Node3D, data: Dictionary) -> void:
	if str(d.get("archetype", "")) == "deployable":
		var t: DeployedTurret = DeployedTurret.new()
		t.weapon = self
		t.life = P("duration", 12.0)
		t.shot_interval = P("shot_interval", 0.35)
		t.range_m = P("range", 22.0)
		t.shot_dmg = float(data.get("dmg", 8.0))
		mgr.world().add_child(t)
		t.global_position = pos + Vector3.UP * 1.5
		return
	var r: float = P("radius", 4.0)
	if p.has("status"):
		for e: Node3D in Combat.in_radius(mgr.get_tree(), pos, r):
			if e.is_in_group(&"bosses"):
				continue
			var h: Combat.Hit = make_hit(0.0, e.call("get_center"))
			h.status = {str(p["status"]): maxf(P("status_time", 1.0), P("duration", 0.0))}
			mgr.deal_damage(e, h)
	if float(data.get("dmg", 0.0)) > 0.0:
		explode(pos, r, float(data["dmg"]))
	else:
		WeaponFX.ring(mgr.world(), pos, r, WeaponData.color(id), 0.5)
