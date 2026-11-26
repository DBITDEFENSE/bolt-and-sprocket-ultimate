class_name Explosion
extends RefCounted
## Radial damage with line-of-sight and falloff. Used by frags now, launchers and traps later.

const MASK_LOS: int = 1 | (1 << 8)


## cfg keys: damage, edge_mult, radius, stagger_radius, self_damage_near, self_near_m, self_damage_far
static func detonate(ctx: Node3D, pos: Vector3, cfg: Dictionary, by_player: int, weapon_id: StringName = &"frag") -> void:
	var tree: SceneTree = ctx.get_tree()
	var mults: Vector2 = PerkManager.explosive_mults(by_player)   # Rocket Man (T-276): the owner's blast, harder and wider
	var radius: float = float(cfg["radius"]) * mults.y
	var dmg: float = float(cfg["damage"]) * mults.x
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
			PerkManager.explosive_after(by_player, z)   # Rocket Man II / III
	if GameState.map_id == &"map01_kaltenbrunn":
		QuestBell.splash(tree, space, pos, radius, weapon_id, by_player)   # T-181: a blast rings a bell near it
	# Self damage (Blastproof Bock: immune). In co-op each peer only hurts its own player: explosions happen on
	# the thrower's machine, and there's no friendly fire between machines (D-068).
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_local or not p.is_alive():
			continue
		if p.has_explosive_immunity():
			PerkManager.blast_heal(p, pos, radius)   # Blastproof II: the blast heals instead (T-075)
			PerkManager.blast_jump(p, pos, by_player)   # Rocket Man: your own blast at your feet throws you clear (T-276)
			continue
		var pd: float = pos.distance_to(p.global_position + Vector3.UP)
		if pd <= float(cfg.get("self_near_m", 3.0)):
			p.take_hit(float(cfg.get("self_damage_near", 100)), null)
		elif pd <= radius:
			p.take_hit(float(cfg.get("self_damage_far", 50)), null)
	var look: String = fx_kind(cfg, weapon_id)   # T-280: the blast's look (presentation only)
	Effects.explosion(pos, radius, look)
	AudioDirector.play_3d(str(cfg.get("sound", "grenade_explode")), pos, float(cfg.get("sound_db", 4.0)), 0.08)
	if Net.session != null and not Net.applying:
		Net.session.local_explosion(pos, radius, str(cfg.get("sound", "grenade_explode")), float(cfg.get("sound_db", 4.0)), look)
	GLBus.explosion.emit(pos, radius)


## T-280: the look of a blast (Effects.explosion's kind): the cfg's "fx" when it names one, a hand grenade's for the
## frag, else "" (Effects picks it from the radius: a shell, a bomb, a small pop).
static func fx_kind(cfg: Dictionary, weapon_id: StringName) -> String:
	if cfg.has("fx"):
		return str(cfg["fx"])
	return "grenade" if weapon_id == &"frag" else ""
