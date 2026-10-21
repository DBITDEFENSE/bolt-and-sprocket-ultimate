extends ProjectileWeapon
## ROOT CANAL (BS_WEAPONS §8.12). fireRoot / plantAt / updatePlants (index.html:5783-5840): a seed at 22 m/s
## (life 1.6) every 0.7 s; wherever it lands a snapping bio-plant sprouts for 6 s, ROOTS the nearest non-armoured
## enemy (picked within 3, held within 3.2) and chews it for 8 every 0.5 s. Up to 3 plants; the oldest dies when a
## 4th is planted. Ammo 8 (+3 per tier). Plant damage counts as the gun's own (use-XP).
## Alt-fire UPROOT & REPLANT: the oldest garden burrows to the aim point at 12 m/s and keeps its life +2 s.
## Free, 2 s cooldown.
## V3: plants spit spore globs (6, splash 1.5) at other enemies within 12 m every 1.5-2.5 s. V5: 9 s life, r4.
## Ω ORTHODONTIST: five gardens, chewing every 0.3 s; gardens within 8 m link with vine tripwires that root anything
## crossing them for 1 s. Signatures: braces (rooted targets take +20% from guns, see WeaponRules), wisdom_teeth
## (each plant roots 2 targets at half bite damage).

var plants: Array[RootPlant] = []
var replant_cd: float = 0.0


func max_plants() -> int:
	return int(P("max_plants_omega", 5)) if omega() else int(P("max_plants", 3))


func _prune() -> void:
	var keep: Array[RootPlant] = []
	for pl: RootPlant in plants:
		if pl != null and is_instance_valid(pl) and not pl.dead:
			keep.append(pl)
	plants = keep


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	launch(0.0, {"seed": true, "shape": "seed"})
	recoil(float(d.get("recoil", 0.006)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	if bool(pr.data.get("spore", false)):
		explode(point, float(pr.data["splash"]), float(pr.data["dmg"]))
		return false
	plant_at(ground(point), target)
	return false


func on_projectile_world(pr: BSProjectile, point: Vector3, _normal: Vector3) -> bool:
	if bool(pr.data.get("spore", false)):
		explode(point, float(pr.data["splash"]), float(pr.data["dmg"]))
		return false
	plant_at(ground(point), null)
	return false


func on_projectile_expire(pr: BSProjectile) -> void:
	if bool(pr.data.get("spore", false)):
		explode(pr.global_position, float(pr.data["splash"]), float(pr.data["dmg"]))
		return
	plant_at(ground(pr.global_position), null)


## Snap a point to the ground below it (plants sprout from the floor).
func ground(p: Vector3) -> Vector3:
	var hit: Dictionary = mgr.ray_world(p + Vector3.UP * 0.4, p + Vector3.DOWN * 8.0)
	return hit["position"] if not hit.is_empty() else p


func plant_at(pos: Vector3, target: Node3D) -> RootPlant:
	_prune()
	while plants.size() >= max_plants():
		plants.pop_front().wither()
	var pl: RootPlant = RootPlant.new()
	pl.weapon = self
	pl.life = P("plant_life_v5", 9.0) if level() >= 5 else P("plant_life", 6.0)
	pl.root_r = P("root_radius_v5", 4.0) if level() >= 5 else P("root_radius", 3.2)
	pl.pick_r = maxf(P("pick_radius", 3.0), pl.root_r - 0.2)
	pl.bite = P("bite_omega", 0.3) if omega() else P("bite", 0.5)
	var wisdom: bool = sig() == &"wisdom_teeth"
	pl.bite_dmg = dmg(float(d.get("damage", 8))) * (P("wisdom_mul", 0.5) if wisdom else 1.0)
	pl.max_targets = int(P("wisdom_targets", 2)) if wisdom else 1
	pl.root_time = P("root_time", 0.3)
	pl.spores = level() >= 3
	pl.braces = sig() == &"braces"
	pl.gold = omega()
	pl.details = level() - 1
	if target != null and alive(target):
		pl.targets.append(target)
	mgr.world().add_child(pl)
	pl.global_position = pos
	plants.append(pl)
	return pl


## A spore glob from a V3 plant at `at` toward enemy `e`.
func spore(from: Vector3, e: Node3D) -> void:
	var to: Vector3 = center_of(e) - from
	to.y += P("spore_up", 3.0)
	spawn_projectile(from, to.normalized() * P("spore_speed", 12.0) + Vector3.UP * P("spore_up", 3.0), {"gravity": 10.0, "life": 2.0,
		"size": 0.18, "dmg": dmg(P("spore_dmg", 6.0)), "splash": P("spore_splash", 1.5), "spore": true, "color": Color("#bdff6a")})


func _tick(dt: float, _is_equipped: bool) -> void:
	replant_cd = maxf(0.0, replant_cd - dt)
	if omega():
		_vines()


## Ω: gardens within 8 m of each other are linked by vine tripwires that root whatever crosses them for 1 s.
func _vines() -> void:
	_prune()
	for i: int in plants.size():
		for j: int in range(i + 1, plants.size()):
			var a: RootPlant = plants[i]
			var b: RootPlant = plants[j]
			if a.moving or b.moving or a.global_position.distance_to(b.global_position) > P("vine_range", 8.0):
				continue
			var pa: Vector3 = a.global_position + Vector3.UP * 0.25
			var pb: Vector3 = b.global_position + Vector3.UP * 0.25
			WeaponFX.tracer(mgr.world(), pa, pb, Color("#3a8a2a"), 0.07, 0.05)
			for e: Node3D in enemies():
				var c: Vector3 = e.global_position + Vector3.UP * 0.25
				if Geometry3D.get_closest_point_to_segment(c, pa, pb).distance_to(c) < P("vine_width", 0.6) + float(e.get("radius")):
					mgr.apply_status(e, &"rooted", P("vine_root", 1.0))
					if sig() == &"braces":
						e.set_meta(&"bs_braces", true)


# ---- UPROOT & REPLANT

func _on_alt_pressed() -> void:
	_prune()
	if plants.is_empty():
		return
	if replant_cd > 0.0:
		WeaponText.hint("bs.weapon.hint.replant_cd", "replantcd")
		return
	var from: Vector3 = origin()
	var to: Vector3 = from + aim() * P("replant_range", 30.0)
	var hit: Dictionary = mgr.ray_world(from, to)
	var dest: Vector3 = ground(hit["position"] if not hit.is_empty() else to)
	var pl: RootPlant = plants[0]
	pl.burrow_to(dest, P("replant_speed", 12.0), P("replant_bonus", 2.0))
	plants.erase(pl)
	plants.append(pl)          # it's the newest garden now
	replant_cd = P("replant_cooldown", 2.0)
	popup.emit("bs.weapon.fx.replant", dest + Vector3.UP)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	_prune()
	s["plants"] = plants.size()
	s["plants_max"] = max_plants()
	s["alt_cd"] = replant_cd
	return s
