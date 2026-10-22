class_name BotPerception
extends RefCounted
## A bot's senses and threat assessment (Update 03 section 2). No wallhacks: a bot knows a zombie only when it
## saw it (a fov_deg cone from the eye with a line-of-sight ray, rays_per_think per think, nearest first), heard
## it (anything within groan_m, a sprinter within sprinter_m, one tearing boards within tear_m, a boss within
## boss_m), or a teammate did (the squad blackboard, which forgets after memory_s). Everything else the bot
## decides comes from that knowledge. Tuning: data/gravelight/ai/combat.json perception / threat.
##
## Threat per zombie = proximity x speed tier x type (ai_counters threat_mult) x targeting me / a downed teammate
## x behind me x still outside a window. Threat pressure = the sum / pressure_norm (0..1): it drives Retreat vs
## Fight vs Train in the utility scores.

const MASK_LOS: int = 1 | (1 << 8)   # world | doors

var player: Player
var squad: BotSquad
var cfg: Dictionary = {}
var tcfg: Dictionary = {}

## Known zombies (alive, within memory), with their remembered position: [{node: Zombie, pos, t, ...}].
var known: Array = []
## Zombies in sight at the last think (instance id -> true).
var visible: Dictionary = {}
## instance id -> threat (unnormalised).
var threat: Dictionary = {}
var pressure: float = 0.0          # 0..1
var raw_pressure: float = 0.0
var nearest: Zombie = null
var nearest_d: float = INF
var n5: int = 0
var n10: int = 0
var sprinter_close: bool = false
var boss_near: Zombie = null
## Gunfire / a boss cue heard: look that way for a moment (the idle look reads it).
var attention: Vector3 = Vector3.INF
var attention_until: float = 0.0
var rays_used: int = 0


func setup(p: Player, s: BotSquad) -> void:
	player = p
	squad = s
	cfg = BotAIData.combat("perception")
	tcfg = BotAIData.combat("threat")
	GLBus.weapon_fired.connect(_on_weapon_fired)


func eye() -> Vector3:
	return player.head.global_position if player.head != null else player.global_position + Vector3.UP * float(cfg.get("eye_height", 1.55))


func facing_flat() -> Vector3:
	var y: float = player.rotation.y
	return Vector3(-sin(y), 0.0, -cos(y))


## The think-rate update: sight and hearing into the blackboard, then the known set, threat and counts.
func sense(now: float) -> void:
	var bb: BotBlackboard = squad.blackboard
	bb.memory_s = float(cfg.get("memory_s", 4.0))
	var dir: ZombieDirector = squad.director()
	var me: Vector3 = player.global_position
	var e: Vector3 = eye()
	var fwd: Vector3 = facing_flat()
	var half_fov: float = deg_to_rad(float(cfg.get("fov_deg", 110.0)) * 0.5)
	var sight_r: float = float(cfg.get("sight_range_m", 40.0))
	visible.clear()
	rays_used = 0
	if dir != null and not player.spectating:
		var cands: Array = []
		for z: Zombie in dir.active_zombies():
			if not targetable(z):
				continue
			var zp: Vector3 = z.global_position
			var d: float = _flat(zp, me)
			if heard(z, d, cfg):
				bb.sight(z, zp, now, player.player_id, z.tier, is_boss(z))
			if d > sight_r:
				continue
			var to: Vector3 = Vector3(zp.x - me.x, 0.0, zp.z - me.z)
			if d > 0.8 and fwd.angle_to(to.normalized()) > half_fov:
				continue
			cands.append([d, z])
		cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var budget: int = int(cfg.get("rays_per_think", 6))
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		for c: Array in cands:
			if rays_used >= budget:
				break
			var z2: Zombie = c[1]
			rays_used += 1
			var to_p: Vector3 = z2.global_position + Vector3.UP * (0.5 if z2.is_crawler else 1.3)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(e, to_p, MASK_LOS, [player.get_rid()])
			if space.intersect_ray(q).is_empty():
				visible[z2.get_instance_id()] = true
				bb.sight(z2, z2.global_position, now, player.player_id, z2.tier, is_boss(z2))
	_rebuild(now)


## The known set, threat, pressure and the distance counts (from the blackboard's knowledge).
func _rebuild(now: float) -> void:
	var bb: BotBlackboard = squad.blackboard
	known.clear()
	threat.clear()
	nearest = null
	nearest_d = INF
	n5 = 0
	n10 = 0
	sprinter_close = false
	boss_near = null
	raw_pressure = 0.0
	var me: Vector3 = player.global_position
	var fwd: Vector3 = facing_flat()
	var half_fov: float = deg_to_rad(float(cfg.get("fov_deg", 110.0)) * 0.5)
	for en: Variant in bb.known(now):
		var ed: Dictionary = en
		var z: Zombie = ed.get("node") as Zombie
		if not targetable(z):
			continue
		known.append(ed)
		var zp: Vector3 = ed["pos"]
		if visible.has(z.get_instance_id()):
			zp = z.global_position
		if absf(zp.y - me.y) > 2.6:
			continue   # another floor: it isn't pressing this bot now
		var d: float = _flat(zp, me)
		if d < nearest_d:
			nearest_d = d
			nearest = z
		if d < 5.0:
			n5 += 1
		if d < 10.0:
			n10 += 1
		if z.tier == &"sprint" and d < float(BotAIData.combat("reload").get("sprinter_block_m", 4.0)):
			sprinter_close = true
		if is_boss(z) and (boss_near == null or d < _flat(boss_near.global_position, me)):
			boss_near = z
		var to: Vector3 = Vector3(zp.x - me.x, 0.0, zp.z - me.z)
		var behind: bool = d > 0.5 and fwd.angle_to(to.normalized()) > half_fov
		var t: Player = z.target
		var outside: bool = z.state == Zombie.State.TO_WINDOW or z.state == Zombie.State.WAIT_WINDOW or z.state == Zombie.State.TEAR
		var th: float = threat_score(d, z.tier, z.is_crawler, float(BotAIData.counter(z.enemy_id).get("threat_mult", 1.0)),
			t == player, t != null and t != player and t.downed, behind, outside, tcfg)
		threat[z.get_instance_id()] = th
		raw_pressure += th
	pressure = clampf(raw_pressure / maxf(0.1, float(tcfg.get("pressure_norm", 3.2))), 0.0, 1.0)


## Threat of one zombie (combat.json threat). `d` flat metres.
static func threat_score(d: float, tier: StringName, crawler: bool, type_mult: float, targeting_me: bool, targeting_downed: bool,
		behind: bool, outside_window: bool, t: Dictionary) -> float:
	var r: float = float(t.get("range_m", 16.0))
	if d >= r:
		return 0.0
	var prox: float = pow(1.0 - d / r, float(t.get("prox_exp", 1.4)))
	var s: float = prox * float((t.get("tier_mult", {}) as Dictionary).get(String(tier), 1.0)) * type_mult
	if crawler:
		s *= float(t.get("crawler_mult", 0.5))
	if targeting_me:
		s *= float(t.get("targeting_me", 1.5))
	elif targeting_downed:
		s *= float(t.get("targeting_downed", 1.4))
	if behind:
		s *= float(t.get("behind", 1.25))
	if outside_window:
		s *= float(t.get("outside_window", 0.35))
	return s


## Heard without a line of sight (combat.json perception): close groans, a sprinter's scream, board tearing,
## a boss.
static func heard(z: Zombie, d: float, c: Dictionary) -> bool:
	if d <= float(c.get("groan_m", 4.5)):
		return true
	if z.tier == &"sprint" and d <= float(c.get("sprinter_m", 13.0)):
		return true
	if z.state == Zombie.State.TEAR and d <= float(c.get("tear_m", 16.0)):
		return true
	return is_boss(z) and d <= float(c.get("boss_m", 28.0))


static func is_boss(z: Zombie) -> bool:
	return z != null and (bool(BotAIData.counter(z.enemy_id).get("boss", false)) or z is HomageBoss or z is Foreman or z is Screamer)


static func targetable(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and z.is_active() and z.state != Zombie.State.DEAD and z.state != Zombie.State.EMERGE \
		and z.state != Zombie.State.INACTIVE and not (z is HomageBoss and ((z as HomageBoss).gone or (z as HomageBoss).retreating))


## Remembered position of a known zombie (its live one while it is in sight).
func pos_of(z: Zombie) -> Vector3:
	if z == null:
		return Vector3.INF
	if visible.has(z.get_instance_id()):
		return z.global_position
	var e: Dictionary = squad.blackboard.zombies.get(z.get_instance_id(), {})
	return e.get("pos", z.global_position)


func is_known(z: Zombie) -> bool:
	return z != null and squad.blackboard.knows(z, squad.time())


func is_visible(z: Zombie) -> bool:
	return z != null and visible.has(z.get_instance_id())


## Threat near a point (a downed teammate's spot): proximity to `p` within `r`, by tier and type.
func threat_near(p: Vector3, r: float) -> float:
	var s: float = 0.0
	for en: Variant in known:
		var z: Zombie = (en as Dictionary)["node"]
		var zp: Vector3 = (en as Dictionary)["pos"]
		var d: float = _flat(zp, p)
		if d >= r or absf(zp.y - p.y) > 2.6:
			continue
		s += (1.0 - d / r) * float((tcfg.get("tier_mult", {}) as Dictionary).get(String(z.tier), 1.0)) * float(BotAIData.counter(z.enemy_id).get("threat_mult", 1.0))
	return s


## A known sprinter within `r` of `p`.
func sprinter_near(p: Vector3, r: float) -> bool:
	for en: Variant in known:
		var z: Zombie = (en as Dictionary)["node"]
		if z.tier == &"sprint" and not z.is_crawler and _flat((en as Dictionary)["pos"], p) < r:
			return true
	return false


## Known zombies within `r` of `p` (remembered positions).
func count_near(p: Vector3, r: float) -> int:
	var n: int = 0
	for en: Variant in known:
		var zp: Vector3 = (en as Dictionary)["pos"]
		if _flat(zp, p) < r and absf(zp.y - p.y) < 2.6:
			n += 1
	return n


## The known zombies as nodes.
func known_nodes() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for en: Variant in known:
		out.append((en as Dictionary)["node"] as Zombie)
	return out


## A teammate's gunfire nearby: worth a look that way (where the trouble is).
func _on_weapon_fired(pid: int, _wid: StringName, _up: bool, origin: Vector3, direction: Vector3) -> void:
	if player == null or not is_instance_valid(player) or pid == player.player_id or not player.is_inside_tree():
		return
	if origin.distance_to(player.global_position) > 25.0:
		return
	attention = origin + direction * 8.0
	attention_until = squad.time() + float(cfg.get("gunfire_look_s", 1.2))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
