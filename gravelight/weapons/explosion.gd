class_name Explosion
extends RefCounted
## Radial damage with line-of-sight and falloff. Used by frags now, launchers and traps later.

const MASK_LOS: int = 1 | (1 << 8)


## cfg keys: damage, edge_mult, radius, stagger_radius, self_damage_near, self_near_m, self_damage_far
static func detonate(ctx: Node3D, pos: Vector3, cfg: Dictionary, by_player: int, weapon_id: StringName = &"frag") -> void:
	var tree: SceneTree = ctx.get_tree()
	var radius: float = float(cfg["radius"])
	var dmg: float = float(cfg["damage"])
	var edge: float = float(cfg.get("edge_mult", 0.2))
	var space: PhysicsDirectSpaceState3D = ctx.get_world_3d().direct_space_state
	var dir: ZombieDirector = tree.get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			var chest: Vector3 = z.global_position + Vector3.UP * 0.9
			var d: float = pos.distance_to(chest)
			if d > radius:
				continue
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.2, chest, MASK_LOS)
			if not space.intersect_ray(q).is_empty():
				continue
			var amount: float = dmg * lerpf(1.0, edge, d / radius)
			z.take_damage(amount, &"torso", weapon_id, by_player, &"explosive")
	# Self damage (Blastproof Bock: immune). In co-op each peer only hurts its own player: explosions happen on
	# the thrower's machine, and there's no friendly fire between machines (D-068).
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_local or not p.is_alive() or p.has_explosive_immunity():
			continue
		var pd: float = pos.distance_to(p.global_position + Vector3.UP)
		if pd <= float(cfg.get("self_near_m", 3.0)):
			p.take_hit(float(cfg.get("self_damage_near", 100)), null)
		elif pd <= radius:
			p.take_hit(float(cfg.get("self_damage_far", 50)), null)
	Effects.explosion(pos, radius)
	AudioDirector.play_3d(str(cfg.get("sound", "grenade_explode")), pos, float(cfg.get("sound_db", 4.0)), 0.08)
	if Net.session != null and not Net.applying:
		Net.session.local_explosion(pos, radius, str(cfg.get("sound", "grenade_explode")), float(cfg.get("sound_db", 4.0)))
	GLBus.explosion.emit(pos, radius)
