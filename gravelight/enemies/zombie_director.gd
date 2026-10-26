class_name ZombieDirector
extends Node3D
## Owns the zombie pool and turns the RoundManager queue into spawns at active spawn points.
##
## Spawn rules: a spawn point is usable when its zone is open. If the map defines zone adjacency
## (Map 1), only spawns in a zone a player is in, or one adjacent to it, are used ("active zones").
## Navigation: maps can bake one NavigationRegion3D per zone, each on its own navigation layer.
## `nav_mask` = always-on layers (outside areas) + layers of open zones, so paths never cross closed doors.
##
## M4 specials: Glasshides roll from ground spawns (Map 1, r15+); Bellringer rounds spawn packs from fog
## portals (reachable points near players); the Foreman and Screamer are created here (not pooled) and
## live in `_extras` until they die. The director also runs the special-round atmosphere (fog, bell, flicker).
##
## Co-op (M7): on a client the director is in `puppet_mode`: the pool holds puppets the host drives (NetMatch),
## nothing spawns here, and only the special-round atmosphere runs locally. Pool index = zombie net id.

var nav_mask: int = 0x7FFFFFFF
## Co-op client: zombies are puppets (set by the map before add_child).
var puppet_mode: bool = false
var zone_bits: Dictionary = {}     # zone_id -> layer bit index (1-based, like the editor)
var always_bits: int = 0           # layers that are always walkable (outside, closets)
var adjacency: Dictionary = {}     # zone_id -> Array[StringName]

var _pool: Array[Zombie] = []
var _free: Array[Zombie] = []
var _spawn_t: float = 0.0
var _last_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _boost: Dictionary = {}        # zone_id -> spawn-rate multiplier (pylon holdouts)
var _temp_spawns: Dictionary = {}  # key -> Array[ZombieSpawn]
var _extras: Array[Zombie] = []    # bosses and screamers (not pooled)
var _pack_t: float = 0.0
var _last_bell_pos: Vector3 = Vector3.INF
## A map's own special round (UPDATE 07: Map 4's Fliegeralarm): when set, it runs the special round's spawning
## instead of the Bellringer packs (`tick_special(delta)`), and leaves `_last_bell_pos` where the Resupply drops.
var special_handler: Node = null
var _boss_pending: float = -1.0    # seconds until a scheduled Foreman bursts out
var _screamer_at: float = -1.0     # fraction of the round spawned at which a Screamer appears
var _special_fx: bool = false
var _env: Environment = null
var _env_base: Dictionary = {}
var _lights: Array = []            # [OmniLight3D, base energy, uses_base_energy_prop]
var _flicker_t: float = 0.0
## The homage-boss encounter on its map (HB1: the Cousins Round on Map 0); null elsewhere and on co-op clients.
var cousins: CousinsRound = null


func _ready() -> void:
	ZombieBody.warm_up(map_kits())
	_rng.randomize()
	var n: int = int(GLData.table("enemies")["pool_size"])
	for i: int in n:
		var z: Zombie = Zombie.new()
		z.name = "Zombie%02d" % i
		z.director = self
		z.net_id = i
		add_child(z)
		if puppet_mode:
			z.make_puppet()
		_pool.append(z)
		_free.append(z)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.special_round_warning.connect(_on_special_warning)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.zone_opened.connect(func(_z: StringName) -> void: recompute_nav_mask())
	if not puppet_mode and CousinsRound.applies(GameState.map_id, HomageBoss.cfg()):
		cousins = CousinsRound.new()
		cousins.director = self
		add_child(cousins)


## Called by the map: zone -> nav layer bit, always-on bits, and the adjacency graph.
func configure_navigation(bits: Dictionary, always: Array, adj: Dictionary) -> void:
	zone_bits = bits
	always_bits = 0
	for b: Variant in always:
		always_bits |= 1 << (int(b) - 1)
	adjacency = adj
	recompute_nav_mask()


func recompute_nav_mask() -> void:
	if zone_bits.is_empty():
		nav_mask = 0x7FFFFFFF
		return
	var m: int = always_bits
	for z: Variant in zone_bits.keys():
		if GameState.is_zone_open(StringName(z)):
			m |= 1 << (int(zone_bits[z]) - 1)
	nav_mask = m


func _physics_process(delta: float) -> void:
	Zombie.repath_budget = int(GLData.table("enemies")["repath"]["budget_per_frame"])
	_update_flicker(delta)
	if puppet_mode:
		return
	if RoundManager.state != RoundManager.State.ROUND:
		return
	if _boss_pending >= 0.0:
		_boss_pending -= delta
		if _boss_pending < 0.0:
			_spawn_scheduled_boss()
	if RoundManager.is_special_round:
		_update_special(delta)
	else:
		_spawn_t -= delta
		if _spawn_t <= 0.0 and RoundManager.can_spawn() and not _free.is_empty():
			if _spawn_one():
				_spawn_t = RoundManager.current_interval() / _current_boost()
			else:
				_spawn_t = 0.5
		_update_screamer()
	_update_last_zombie(delta)
	_update_stranded(delta)


# ---------------------------------------------------------------- stranded zombies (UPDATE 07 QA, T-107)

var _stranded_t: Dictionary = {}     # zombie instance id -> seconds its path end has been far from every player
var _stranded_check_t: float = 0.0
var stranded_relocations: int = 0    # this match (the soak's STALL report and the tests read it)


## Pure rule: a zombie is stranded when nothing is left to spawn and its path end has been far for `seconds`.
static func stranded_due(far_seconds: float, to_spawn: int, cfg: Dictionary) -> bool:
	return to_spawn <= 0 and far_seconds >= float(cfg.get("seconds", 45.0))


## Pure rule: the path end `end` is far from every living player position in `players` (flat distance, or more
## than 3 m of height) beyond `far_m`.
static func far_from_all(end: Vector3, players: Array, far_m: float) -> bool:
	for q: Variant in players:
		var p: Vector3 = q
		if Vector2(end.x - p.x, end.z - p.z).length() <= far_m and absf(end.y - p.y) <= 3.0:
			return false
	return true


## A chasing zombie whose path never gets near a living player (the players went somewhere its path can't reach:
## a crawler jammed in a doorway, a stale route) is moved to an active ground spawn near the players once nothing
## is left to spawn, so the round can end. Data: rounds.json "stranded".
func _update_stranded(delta: float) -> void:
	_stranded_check_t -= delta
	if _stranded_check_t > 0.0:
		return
	var cfg: Dictionary = GLData.table("rounds").get("stranded", {})
	var every: float = float(cfg.get("check_every_s", 1.0))
	_stranded_check_t = every
	if cfg.is_empty():
		return
	var players: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			players.append(p.global_position)
	if players.is_empty():
		return
	var far_m: float = float(cfg.get("far_m", 6.0))
	var seen: Dictionary = {}
	for z: Zombie in active_zombies():
		var id: int = z.get_instance_id()
		seen[id] = true
		if z.state != Zombie.State.CHASE or z.target == null or z is Foreman or z is HomageBoss:
			_stranded_t[id] = 0.0
			continue
		var end: Vector3 = z.path_end()
		if end == Vector3.INF or not far_from_all(end, players, far_m):
			_stranded_t[id] = 0.0
			continue
		var t: float = float(_stranded_t.get(id, 0.0)) + every
		_stranded_t[id] = t
		if stranded_due(t, RoundManager.to_spawn, cfg):
			_relocate_stranded(z)
			_stranded_t[id] = 0.0
	for k: Variant in _stranded_t.keys():
		if not seen.has(k):
			_stranded_t.erase(k)


func _relocate_stranded(z: Zombie) -> void:
	var sp: ZombieSpawn = _choose_spawn(true)
	var at: Vector3 = Vector3.INF
	if sp != null:
		at = _scatter_excluding(z, sp.global_position)
	else:
		# no ground spawn near the players: the navmesh 6 m behind the nearest living player
		var best: float = INF
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive():
				continue
			var d: float = p.global_position.distance_to(z.global_position)
			if d < best:
				best = d
				at = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p.global_position - p.global_basis.z * -6.0)
	if at == Vector3.INF:
		return
	z.global_position = at + Vector3.UP * 0.05
	z.velocity = Vector3.ZERO
	z.force_repath()
	stranded_relocations += 1
	print("[director] stranded %s%s relocated to %s (round %d, nothing left to spawn)" % [z.enemy_id, " (crawler)" if z.is_crawler else "", str(at.snapped(Vector3.ONE * 0.1)), RoundManager.current_round])


func _on_round_started(round_number: int, special: bool) -> void:
	if puppet_mode:
		if special:
			_set_special_fx(true)
		return
	_spawn_t = 1.5
	_last_t = 0.0
	_pack_t = 2.0
	_last_bell_pos = Vector3.INF
	_screamer_at = -1.0
	if special:
		_set_special_fx(true)
		return
	if not _map_allows(&"foreman"):
		return
	if RoundManager.boss_due() and _count(&"foreman") < int(_ecfg(&"foreman")["max_active"]):
		RoundManager.consume_boss()
		_boss_pending = 2.0
	var sc: Dictionary = _ecfg(&"screamer")
	if _rng.randf() < RoundManager.screamer_chance(round_number, sc):
		_screamer_at = _rng.randf_range(float(sc["spawn_progress_min"]), float(sc["spawn_progress_max"]))


func _on_round_ended(_round: int) -> void:
	if puppet_mode:
		if RoundManager.is_special_round:
			_set_special_fx(false)
		return
	if RoundManager.is_special_round:
		if _last_bell_pos != Vector3.INF:
			PowerupManager.spawn(&"resupply", _last_bell_pos + Vector3.UP * 0.3)
		_set_special_fx(false)


func _on_enemy_killed_at(enemy_id: StringName, pos: Vector3, _by: int) -> void:
	if enemy_id == &"bellringer":
		_last_bell_pos = pos


func _ecfg(enemy_id: StringName) -> Dictionary:
	return GLData.table("enemies")["enemies"].get(String(enemy_id), {})


func _map_allows(enemy_id: StringName) -> bool:
	var maps: Array = _ecfg(enemy_id).get("maps", [])
	return maps.is_empty() or maps.has(String(GameState.map_id))


func _count(enemy_id: StringName) -> int:
	var n: int = 0
	for z: Zombie in active_zombies():
		if z.enemy_id == enemy_id:
			n += 1
	return n


## Ganger health/tier spec adjusted for a kind (health mult/min, kind tiers).
func _spec_for(enemy_id: StringName, spec: Dictionary) -> Dictionary:
	var e: Dictionary = _ecfg(enemy_id)
	spec["enemy_id"] = enemy_id
	if e.has("health_mult"):
		spec["health"] = maxf(float(spec.get("health", 150)) * float(e["health_mult"]), float(e.get("health_min", 0.0)))
	if e.has("tiers"):
		spec["tier"] = RoundManager.pick_tier(e["tiers"], _rng.randf(), 0, 3)
	if enemy_id == &"bellringer":
		spec["tier"] = &"run"
	return spec


# ---------------------------------------------------------------- Bellringer rounds

func _update_special(delta: float) -> void:
	if special_handler != null and is_instance_valid(special_handler):
		special_handler.call("tick_special", delta)
		return
	_pack_t -= delta
	if _pack_t > 0.0 or not RoundManager.can_spawn() or _free.is_empty():
		return
	var e: Dictionary = _ecfg(&"bellringer")
	var active: int = _count(&"bellringer")
	if active >= int(e.get("max_active", 18)):
		return
	var sr: Dictionary = GLData.table("rounds")["special_round"]
	var pack: int = int(sr["pack_small"]) if GameState.is_solo() and RoundManager.current_round <= int(sr["pack_small_until_round"]) \
		else _rng.randi_range(int(sr["pack_min"]), int(sr["pack_max"]))
	pack = mini(pack, mini(RoundManager.to_spawn, int(e.get("max_active", 18)) - active))
	pack = mini(pack, _free.size())
	var center: Vector3 = _portal_point()
	if center == Vector3.INF:
		_pack_t = 1.0
		return
	# Each member takes its own free slot round the portal (T-057): the old random offset fell back to the portal
	# point itself, so a pack could rise inside each other, stack, and shove the top one up through the ceiling onto
	# the roof; and an offset could snap through a window to the outside, where a chasing zombie can't get in.
	for i: int in pack:
		if not RoundManager.can_spawn():
			break
		var at: Vector3 = _scatter(center, i, true)
		if at == Vector3.INF:
			break   # no free, open spot left round this portal: the rest come with the next pack
		_activate_at(_spec_for(&"bellringer", RoundManager.take_spawn()), at)
	_pack_t = float(e.get("pack_gap_seconds", 3.5))


## A reachable point near a player but never within `portal_min_dist` of any player. INF if none found.
func _portal_point() -> Vector3:
	var e: Dictionary = _ecfg(&"bellringer")
	var lo: float = float(e.get("portal_min_dist", 8.0))
	var hi: float = float(e.get("portal_max_dist", 18.0))
	var players: Array[Player] = _alive_players()
	if players.is_empty():
		return Vector3.INF
	var map_rid: RID = get_world_3d().navigation_map
	for relax: float in [1.0, 0.5]:
		for attempt: int in 24:
			var p: Player = players[_rng.randi_range(0, players.size() - 1)]
			var a: float = _rng.randf() * TAU
			var r: float = _rng.randf_range(lo * relax, hi)
			var want: Vector3 = p.global_position + Vector3(cos(a), 0, sin(a)) * r
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, p.global_position, want, true, nav_mask)
			if path.is_empty():
				continue
			var pt: Vector3 = path[path.size() - 1]
			var ok: bool = absf(pt.y - p.global_position.y) < 2.5 and spawn_spot_ok(pt) and not _crosses_closed_door(path) \
				and not _crosses_window(path)
			for q: Player in players:
				if q.global_position.distance_to(pt) < lo * relax:
					ok = false
			if ok:
				return pt
	# fallback: the active ground spawn in an open zone nearest a player (never one in a shut zone or off the map)
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null or sp.kind != &"ground" or not sp.is_active(maxi(1, RoundManager.current_round)) \
				or not _in_open_zone(sp.global_position):
			continue
		for q: Player in players:
			var d: float = q.global_position.distance_to(sp.global_position)
			if d < best_d:
				best_d = d
				best = sp.global_position
	return best


## True when a zombie may rise at a navmesh point (T-057): it's in a zone the players have opened, and there's
## room for a body there: nothing solid (furniture, a wall, a beam) inside a 0.45 m column from a hand's breadth
## above the floor to head height. Fog portals and their packs only use spots that pass.
func spawn_spot_ok(pt: Vector3) -> bool:
	if not _in_open_zone(pt):
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 0.3, pt + Vector3.DOWN * 1.2, 1)
	var hit: Dictionary = space.intersect_ray(down)
	if hit.is_empty():
		return false   # nothing under it: a navmesh scrap over a hole
	var floor_y: float = (hit["position"] as Vector3).y
	var col: CylinderShape3D = CylinderShape3D.new()
	col.radius = 0.45
	col.height = 1.4
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = col
	q.transform = Transform3D(Basis.IDENTITY, Vector3(pt.x, floor_y + 0.3 + col.height * 0.5, pt.z))
	q.collision_mask = 1 | (1 << 8)
	return space.intersect_shape(q, 1).is_empty()


## True when a nav path runs through a window (zombies only come in by tearing the boards: a chasing one can't
## climb through, T-057). Windows are planes like doors: a segment that crosses one between its jambs.
func _crosses_window(path: PackedVector3Array) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b != null and window_crossed(b, path):
			return true
	return false


static func window_crossed(b: Barricade, path: PackedVector3Array) -> bool:
	var bp: Vector3 = b.global_position
	var nrm: Vector3 = b.global_basis.z
	nrm.y = 0.0
	nrm = nrm.normalized()
	var along: Vector3 = b.global_basis.x
	along.y = 0.0
	along = along.normalized()
	var half: float = b.width * 0.5 + 0.2
	for k: int in range(1, path.size()):
		var a: Vector3 = path[k - 1]
		var c: Vector3 = path[k]
		if absf(a.y - bp.y) > 2.5 and absf(c.y - bp.y) > 2.5:
			continue
		var da: float = nrm.dot(a - bp)
		var dc: float = nrm.dot(c - bp)
		if signf(da) == signf(dc) or da == dc:
			continue
		var hit: Vector3 = a.lerp(c, da / (da - dc))
		if absf(along.dot(hit - bp)) <= half:
			return true
	return false


## Fog portals only open in zones the players have bought into. Map 0 has one navmesh across closed doors
## (doors aren't baked), so a reachable-looking point can be behind a locked door: a pack spawned there
## would chase into the door and stall the round (playtest fix, T-026). Maps without zone volumes allow all.
func _in_open_zone(pt: Vector3) -> bool:
	if get_tree().get_nodes_in_group(&"zone_volumes").is_empty():
		return true
	var zone: StringName = ZoneVolume.zone_at(get_tree(), pt)
	return zone != &"" and GameState.is_zone_open(zone)


## True when a nav path runs through a door that's still shut (doors are colliders, not navmesh cuts): some
## segment crosses the door's plane between its jambs.
func _crosses_closed_door(path: PackedVector3Array) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and not d.is_open and door_crossed(d, path):
			return true
	return false


static func door_crossed(d: BuyDoor, path: PackedVector3Array) -> bool:
	var dp: Vector3 = d.global_position
	var nrm: Vector3 = d.global_basis.z
	nrm.y = 0.0
	nrm = nrm.normalized()
	var along: Vector3 = d.global_basis.x
	along.y = 0.0
	along = along.normalized()
	var half: float = d.size.x * 0.5 + 0.3
	# walk the path keeping the last point that was clearly on one side; a corner exactly in the doorway
	# (string-pulled paths love those) must not hide the crossing
	var last_side: float = 0.0
	var last_p: Vector3 = Vector3.ZERO
	for p: Vector3 in path:
		if absf(p.y - dp.y) > 2.2:
			last_side = 0.0
			continue
		var dist: float = nrm.dot(p - dp)
		if absf(dist) < 0.02:
			if absf(along.dot(p - dp)) <= half and last_side != 0.0:
				return true   # standing in the doorway, having come from one side
			continue
		var side: float = signf(dist)
		if last_side != 0.0 and side != last_side:
			var dl: float = nrm.dot(last_p - dp)
			var t: float = dl / (dl - dist)
			var hit: Vector3 = last_p.lerp(p, t)
			if absf(along.dot(hit - dp)) <= half:
				return true
		last_side = side
		last_p = p
	return false


## Ground emergences fan out around their point (ring slot i, 0.9 m apart) so two zombies never rise inside each
## other and end up one standing on the other's head (playtest fix, T-027). Snapped to the navmesh, same level.
## strict (fog-portal packs, T-057): every slot must also pass spawn_spot_ok, and when no slot is free the answer
## is Vector3.INF instead of the point itself (a pack never rises inside itself).
func _scatter(p: Vector3, i: int, strict: bool = false) -> Vector3:
	# the first free slot on a golden-angle ring: at least 0.9 m from every active zombie
	var base: Vector3 = _snap(p)   # the navmesh floats a little above the floor: compare like with like
	for k: int in (12 if strict else 8):
		var slot: int = i + k
		var q: Vector3 = p
		if slot > 0:
			var a: float = float(slot) * 2.399 + _rng.randf() * 0.4
			var r: float = 0.9 + 0.35 * float(slot / 6)
			q = _snap(p + Vector3(cos(a) * r, 0, sin(a) * r))
			if absf(q.y - base.y) > 0.4 or not _same_room(p, q):
				continue   # a different level (furniture, a step) or the far side of a wall: not here
			if strict and (not spawn_spot_ok(q) or ZoneVolume.zone_at(get_tree(), q) != ZoneVolume.zone_at(get_tree(), p)):
				continue   # in a shut zone, outside (through a window), or with no room for a body
			q.y = p.y
		var free: bool = true
		for z: Zombie in active_zombies():
			if Vector2(z.global_position.x - q.x, z.global_position.z - q.z).length() < 0.9 and absf(z.global_position.y - q.y) < 2.0:
				free = false
				break
		if free:
			return q
	return Vector3.INF if strict else p


## _scatter for a zombie that's already active (it mustn't count itself as occupying the spot).
func _scatter_excluding(z: Zombie, p: Vector3) -> Vector3:
	var keep: Vector3 = z.global_position
	z.global_position = Vector3(0, -200, 0)
	var q: Vector3 = _scatter(p, 0)
	z.global_position = keep
	return q


## True when nothing solid (wall, closed door) stands between a and b at waist height: a snapped point is in
## the same room, not through the wall on the outside (T-028).
func _same_room(a: Vector3, b: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.9, b + Vector3.UP * 0.9, 1 | (1 << 8))
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _snap(p: Vector3) -> Vector3:
	var c: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
	return c if c.distance_to(p) < 3.0 else p


func _alive_players() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			out.append(p)
	return out


## Activates a pooled zombie at a point (emerging from the ground / a fog portal).
func _activate_at(spec: Dictionary, at: Vector3) -> Zombie:
	if _free.is_empty():
		return null
	var sp: ZombieSpawn = ZombieSpawn.new()
	sp.kind = &"ground"
	add_child(sp)
	sp.global_position = at
	var z: Zombie = _free.pop_back()
	z.activate(spec, sp, _any_player())
	sp.queue_free()
	GLBus.enemy_spawned.emit(z.enemy_id, z.get_instance_id())
	return z


# ---------------------------------------------------------------- special-round atmosphere

## Fog and lighting only: the toll is AudioDirector's stinger_special (round start) plus the VO warning.
func _on_special_warning(_kind: StringName) -> void:
	_set_special_fx(true)


func _find_env() -> Environment:
	var root: Node = get_parent()
	if root == null:
		return null
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		return (n as WorldEnvironment).environment
	return null


func _set_special_fx(on: bool) -> void:
	if on == _special_fx:
		return
	_special_fx = on
	var mult: float = float(GLData.table("rounds")["special_round"].get("fog_mult", 3.0))
	if on:
		_env = _find_env()
		if _env != null:
			_env_base = {"fog": _env.fog_density, "vol": _env.volumetric_fog_density}
			var tw: Tween = create_tween()
			tw.tween_property(_env, "fog_density", _env.fog_density * mult, 4.0)
			tw.parallel().tween_property(_env, "volumetric_fog_density", maxf(0.02, _env.volumetric_fog_density * mult), 4.0)
		_lights.clear()
		var root: Node = get_parent()
		if root != null:
			for n: Node in root.find_children("*", "OmniLight3D", true, false):
				if is_ancestor_of(n) or n.get_parent() is Player or _under_player(n):
					continue
				var l: OmniLight3D = n as OmniLight3D
				var has_base: bool = l.get("base_energy") != null
				_lights.append([l, float(l.get("base_energy")) if has_base else l.light_energy, has_base])
	else:
		if _env != null and not _env_base.is_empty():
			var tw2: Tween = create_tween()
			tw2.tween_property(_env, "fog_density", float(_env_base["fog"]), 3.0)
			tw2.parallel().tween_property(_env, "volumetric_fog_density", float(_env_base["vol"]), 3.0)
		for e: Array in _lights:
			if not is_instance_valid(e[0]):
				continue   # freed during the round (a muzzle flash, a dropped prop): a typed read of it would error
			var l2: OmniLight3D = e[0]
			var base: float = float(e[1])
			if l2.has_meta("energy") and GameState.power_on:
				base = float(l2.get_meta("energy"))
			if bool(e[2]):
				l2.set("base_energy", base)
			else:
				l2.light_energy = base
		_lights.clear()


func _under_player(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is Player:
			return true
		p = p.get_parent()
	return false


## Lights dim to ~40% and stutter during a Bellringer round.
func _update_flicker(delta: float) -> void:
	if not _special_fx or _lights.is_empty():
		return
	_flicker_t -= delta
	if _flicker_t > 0.0:
		return
	_flicker_t = 0.08
	for e: Array in _lights:
		if not is_instance_valid(e[0]):
			continue
		var l: OmniLight3D = e[0] as OmniLight3D
		var base: float = float(e[1])
		if l.has_meta("energy") and GameState.power_on:
			base = float(l.get_meta("energy"))
		var k: float = 0.4 if _rng.randf() > 0.08 else _rng.randf_range(0.05, 0.25)
		if bool(e[2]):
			l.set("base_energy", base * k)
		else:
			l.light_energy = base * k


# ---------------------------------------------------------------- bosses / screamer

func _spawn_scheduled_boss() -> void:
	var at: Vector3 = _boss_point()
	if at != Vector3.INF:
		summon_boss(&"foreman", at)


## A ground spawn in a zone adjacent to (not inside) the players' zone; else any reachable point away from them.
func _boss_point() -> Vector3:
	var pz: Dictionary = _player_zones()
	var best: Array[Vector3] = []
	var ok: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null or sp.kind != &"ground" or not GameState.is_zone_open(sp.zone_id):
			continue
		if pz.has(sp.zone_id):
			ok.append(sp.global_position)
		elif _zone_allowed(sp.zone_id, pz):
			best.append(sp.global_position)
	if not best.is_empty():
		return best[_rng.randi_range(0, best.size() - 1)]
	if not ok.is_empty():
		return ok[_rng.randi_range(0, ok.size() - 1)]
	return _portal_point()


func _update_screamer() -> void:
	if _screamer_at < 0.0 or RoundManager.round_total <= 0:
		return
	var spawned: float = 1.0 - float(RoundManager.to_spawn) / float(RoundManager.round_total)
	if spawned < _screamer_at or _count(&"screamer") > 0:
		return
	_screamer_at = -1.0
	var at: Vector3 = _boss_point()
	if at != Vector3.INF:
		summon_boss(&"screamer", at)


## A boss made elsewhere (the homage bosses): joins the extras (not pooled; freed when it is returned).
func add_extra(z: Zombie) -> void:
	z.director = self
	if Net.session != null:
		z.net_id = Net.session.next_extra_id()
	add_child(z)
	_extras.append(z)


## Creates a Foreman or Screamer at `at`. Counts as alive for round-end, outside the round queue.
## Homage bosses: "cousins" starts the Cousins Round on its map; "hammer" / "reach" / "alix" (or their
## cousin_* ids) bring one cousin alone (testing; no encounter around her).
func summon_boss(enemy_id: StringName, at: Vector3) -> Node3D:
	var z: Zombie = null
	match enemy_id:
		&"cousins":
			if cousins != null:
				cousins.start_now()
			return cousins
		&"hammer", &"reach", &"alix", &"cousin_hammer", &"cousin_reach", &"cousin_alix":
			var key: String = String(enemy_id).trim_prefix("cousin_")
			var hb: HomageBoss = CousinHammer.new() if key == "hammer" else (CousinReach.new() if key == "reach" else CousinAlix.new())
			add_extra(hb)
			RoundManager.take_extra_spawn()
			hb.spawn_homage(_snap(at), CousinsRound.boss_hp(key, RoundManager.players, HomageBoss.cfg()))
			GLBus.enemy_spawned.emit(hb.enemy_id, hb.get_instance_id())
			return hb
		&"kranfuehrer":
			var kf: Kranfuehrer = Kranfuehrer.new()
			kf.director = self
			add_extra(kf)
			RoundManager.take_extra_spawn()
			kf.spawn_crane(at, HomageBoss.scaled_hp(float(kf.boss_cfg().get("hp_base", 24000)), RoundManager.players, float(kf.boss_cfg().get("hp_player_step", 0.75))))
			GLBus.boss_spawned.emit(&"kranfuehrer")
			GLBus.enemy_spawned.emit(kf.enemy_id, kf.get_instance_id())
			return kf
		&"account_manager":
			var am: AccountManager = AccountManager.new()
			am.director = self
			add_extra(am)
			RoundManager.take_extra_spawn()
			am.spawn_manager(at, HomageBoss.scaled_hp(float(am.boss_cfg().get("hp_base", 45000)), RoundManager.players, float(am.boss_cfg().get("hp_player_step", 0.75))))
			GLBus.boss_spawned.emit(&"account_manager")
			GLBus.enemy_spawned.emit(am.enemy_id, am.get_instance_id())
			return am
		&"bordwart":
			var bw: Bordwart = Bordwart.new()
			bw.director = self
			add_extra(bw)
			RoundManager.take_extra_spawn()
			bw.spawn_bordwart(at, HomageBoss.scaled_hp(float(bw.boss_cfg().get("hp_base", 30000)), RoundManager.players, float(bw.boss_cfg().get("hp_player_step", 0.75))))
			GLBus.boss_spawned.emit(&"bordwart")
			GLBus.enemy_spawned.emit(bw.enemy_id, bw.get_instance_id())
			return bw
		&"testpilot":
			var tp: TestPilot = TestPilot.new()
			tp.director = self
			add_extra(tp)
			RoundManager.take_extra_spawn()
			tp.spawn_testpilot(at, HomageBoss.scaled_hp(float(tp.boss_cfg().get("hp_base", 32000)), RoundManager.players, float(tp.boss_cfg().get("hp_player_step", 0.75))))
			GLBus.boss_spawned.emit(&"testpilot")
			GLBus.enemy_spawned.emit(tp.enemy_id, tp.get_instance_id())
			return tp
		&"foreman":
			var f: Foreman = Foreman.new()
			f.director = self
			if Net.session != null:
				f.net_id = Net.session.next_extra_id()
			add_child(f)
			RoundManager.take_extra_spawn()
			f.spawn_boss(at, float(RoundManager.foreman_health(maxi(1, RoundManager.current_round), RoundManager.players, _ecfg(&"foreman"))))

			GLBus.boss_spawned.emit(&"foreman")
			z = f
		&"screamer":
			var s: Screamer = Screamer.new()
			s.director = self
			if Net.session != null:
				s.net_id = Net.session.next_extra_id()
			add_child(s)
			RoundManager.take_extra_spawn()
			s.spawn_screamer(at, float(RoundManager.current_health()) * float(_ecfg(&"screamer")["health_mult"]))
			GLBus.boss_spawned.emit(&"screamer")
			z = s
		_:
			return null
	_extras.append(z)
	GLBus.enemy_spawned.emit(enemy_id, z.get_instance_id())
	return z


## Extra waves (Heartstorm etc.) that don't count toward the round total but must die before it ends.
## enemy_id: ganger | glasshide | bellringer | foreman | screamer. Returns how many spawned.
func spawn_special(enemy_id: StringName, count: int, points: Array) -> int:
	var made: int = 0
	for i: int in count:
		var at: Vector3 = (points[i % points.size()] as Vector3) if not points.is_empty() else _portal_point()
		if at == Vector3.INF:
			break
		if enemy_id == &"foreman" or enemy_id == &"screamer":
			if summon_boss(enemy_id, at) != null:
				made += 1
			continue
		if _free.is_empty():
			break
		var spec: Dictionary = _spec_for(enemy_id, RoundManager.take_extra_spawn())
		if _activate_at(spec, _snap(at + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))) != null:
			made += 1
		else:
			RoundManager.alive = maxi(0, RoundManager.alive - 1)
	return made


func _spawn_one() -> bool:
	var want_glass: bool = _roll_glasshide()
	var sp: ZombieSpawn = _choose_spawn(want_glass)
	if sp == null and want_glass:
		want_glass = false
		sp = _choose_spawn()
	if sp == null:
		return false
	var spec: Dictionary = RoundManager.take_spawn()
	spec["variant"] = _pick_variant()
	if ZoneVolume.vacuum_at(get_tree(), sp.global_position) and _map_allows(&"suited") and (GLData.table("enemies")["enemies"] as Dictionary).has("suited"):
		spec = _spec_for(&"suited", spec)   # no air: only the Suited rise here (T-112)
		want_glass = false
	elif want_glass:
		spec = _spec_for(&"glasshide", spec)
	var z: Zombie = _free.pop_back()
	z.activate(spec, sp, _any_player())
	if sp.kind == &"ground":
		z.global_position = _scatter_excluding(z, sp.global_position)
	GLBus.enemy_spawned.emit(z.enemy_id, z.get_instance_id())
	return true


func _player_zones() -> Dictionary:
	var out: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			out[ZoneVolume.zone_at(get_tree(), p.global_position)] = true
	return out


## T-080: where the living players standing on open ground (ZoneVolume.roam) are.
func _roaming_players() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and ZoneVolume.roam_at(get_tree(), p.global_position):
			out.append(p.global_position)
	return out


## True when one of `roamers` is within `dist` (flat) of `at` and can see it: a clear line from their eyes to a
## standing zombie's chest there (walls, the stable, the wreck hide a spawn; the night and the fog don't).
static func _seen_from(at: Vector3, dist: float, roamers: Array[Vector3], space: PhysicsDirectSpaceState3D) -> bool:
	for q: Vector3 in roamers:
		if Vector2(q.x - at.x, q.z - at.z).length() < dist and absf(q.y - at.y) < 4.0:
			if space == null:
				return true
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(q + Vector3.UP * 1.6, at + Vector3.UP * 1.2, 1)
			if space.intersect_ray(ray).is_empty():
				return true
	return false


func _zone_allowed(zone: StringName, player_zones: Dictionary) -> bool:
	if adjacency.is_empty() or player_zones.has(zone):
		return true
	for pz: Variant in player_zones.keys():
		if (adjacency.get(pz, []) as Array).has(String(zone)) or (adjacency.get(pz, []) as Array).has(zone):
			return true
	return false


## Glasshides: Map 1, round 15+, a growing share of spawns, never more than max_active at once.
func _roll_glasshide() -> bool:
	if not _map_allows(&"glasshide"):
		return false
	var e: Dictionary = _ecfg(&"glasshide")
	if _count(&"glasshide") >= int(e["max_active"]):
		return false
	return _rng.randf() < RoundManager.glasshide_chance(RoundManager.current_round, e)


func _choose_spawn(ground_only: bool = false) -> ZombieSpawn:
	var round_number: int = maxi(1, RoundManager.current_round)
	var player_zones: Dictionary = _player_zones()
	var roamers: Array[Vector3] = _roaming_players()
	var candidates: Array[ZombieSpawn] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null or not sp.is_active(round_number) or not _zone_allowed(sp.zone_id, player_zones):
			continue
		if sp.player_zone_only and not player_zones.has(sp.zone_id):
			continue
		if sp.hide_from_m > 0.0 and _seen_from(sp.global_position, sp.hide_from_m, roamers, get_world_3d().direct_space_state):
			continue
		if ground_only and sp.kind != &"ground":
			continue
		var w: float = 4.0 if player_zones.has(sp.zone_id) else 1.0
		w *= float(_boost.get(sp.zone_id, 1.0))
		var win: Barricade = sp.window()
		if win != null and win.occupant != null:
			w *= 0.5
		candidates.append(sp)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return null
	var roll: float = _rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates.back()


## The Gänger outfit kits this map spawns: enemies.json ganger.variants_by_map[map] over the default variants
## (MZ: Crossroads villagers and soldiers, Kaltenbrunn miners / lab staff / technicians, Totenhafen sailors and
## dockworkers; `laborer` is retired).
static func variant_table() -> Dictionary:
	var g: Dictionary = GLData.table("enemies")["enemies"]["ganger"]
	var by_map: Dictionary = g.get("variants_by_map", {})
	if by_map.has(String(GameState.map_id)):
		return by_map[String(GameState.map_id)]
	return g["variants"]


## Kits to build up front: the map's Gänger kits plus the specials that share the body.
static func map_kits() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in variant_table().keys():
		out.append(str(k))
	for extra: String in ["bellringer", "nurse"]:
		if not out.has(extra):
			out.append(extra)
	return out


## Free pool slots (corpses hurry their dissolve when this runs low, Zombie._update_dead).
func free_count() -> int:
	return _free.size()


func _pick_variant() -> String:
	var v: Dictionary = variant_table()
	var roll: float = _rng.randf()
	for key: Variant in v.keys():
		roll -= float(v[key])
		if roll <= 0.0:
			return str(key)
	return "soldier"


func _any_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player:
			return n as Player
	return null


## The last zombie of a round speeds up after a while so players can't stall forever (crawlers excepted).
func _update_last_zombie(delta: float) -> void:
	if RoundManager.remaining() != 1:
		_last_t = 0.0
		return
	_last_t += delta
	if _last_t >= float(GLData.table("enemies")["enemies"]["ganger"]["last_zombie_seconds"]):
		for z: Zombie in active_zombies():
			z.is_last = true


## Co-op client: a boss puppet the host announced (pooled ganger puppets are already in _pool).
func make_puppet_extra(kind_class: int) -> Zombie:
	var z: Zombie
	match kind_class:
		1:
			z = Foreman.new()
		2:
			z = Screamer.new()
		_:
			z = Zombie.new()
	z.director = self
	add_child(z)
	z.make_puppet()
	return z


func on_zombie_returned(z: Zombie) -> void:
	if puppet_mode and z.net_id >= NetMatch.EXTRA_ID_BASE:
		z.queue_free()
		return
	if _extras.has(z):
		_extras.erase(z)
		z.queue_free()
		return
	if not _free.has(z):
		_free.append(z)


func active_zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for z: Zombie in _pool:
		if z.is_active():
			out.append(z)
	for x: Zombie in _extras:
		if is_instance_valid(x) and x.is_active():
			out.append(x)
	return out


func kill_all(silent: bool = true) -> void:
	for z: Zombie in active_zombies():
		if silent:
			z.kill_silently()
		else:
			z.take_damage(z.hp + 1.0, &"torso", &"none", 1, &"explosive")


# ---------------------------------------------------------------- hooks for world events (M3)

func _current_boost() -> float:
	var best: float = 1.0
	for pz: Variant in _player_zones().keys():
		best = maxf(best, float(_boost.get(pz, 1.0)))
	return best


## Pylon holdouts: multiply the spawn rate in a zone (1.0 = normal).
func set_spawn_boost(zone: StringName, mult: float) -> void:
	if mult <= 1.0:
		_boost.erase(zone)
	else:
		_boost[zone] = mult


## Adds temporary ground spawn points (e.g. around a pylon ring). Remove them with the same key.
func add_temp_spawns(key: StringName, points: Array, zone: StringName) -> void:
	remove_temp_spawns(key)
	var list: Array = []
	for p: Variant in points:
		var sp: ZombieSpawn = ZombieSpawn.new()
		sp.zone_id = zone
		sp.kind = &"ground"
		sp.name = "Temp_%s_%d" % [key, list.size()]
		add_child(sp)
		sp.global_position = p as Vector3
		list.append(sp)
	_temp_spawns[key] = list


func remove_temp_spawns(key: StringName) -> void:
	for sp: Variant in _temp_spawns.get(key, []):
		if is_instance_valid(sp):
			(sp as Node).queue_free()
	_temp_spawns.erase(key)


## Activates a zombie whose round slot was already taken off the queue (RoundManager.take_spawn) at `at`: it
## emerges there, and the caller may change its state next (Map 0's opening: the attackers in the snow, the
## patrons rising where they fell; T-072). null when the pool is empty (the caller gives the slot back).
func activate_reserved(spec: Dictionary, at: Vector3) -> Zombie:
	if puppet_mode:
		return null
	if not spec.has("variant"):
		spec["variant"] = _pick_variant()
	return _activate_at(spec, _snap(at))


## Spawns extra zombies at given points right away. They don't count toward the round total
## (power-on burst), but they must still die before the round can end.
func spawn_burst(points: Array, count: int) -> int:
	var made: int = 0
	for i: int in count:
		if _free.is_empty() or points.is_empty():
			break
		var sp: ZombieSpawn = ZombieSpawn.new()
		sp.kind = &"ground"
		add_child(sp)
		sp.global_position = points[i % points.size()] as Vector3
		sp.global_position = _scatter(sp.global_position, i)
		var spec: Dictionary = RoundManager.take_extra_spawn()
		spec["variant"] = _pick_variant()
		_free.pop_back().activate(spec, sp, _any_player())
		sp.queue_free()
		made += 1
	return made


## Dev console: spawn `count` of a kind near the player (bosses included). Ignores the round queue.
func debug_spawn_kind(enemy_id: StringName, count: int) -> int:
	if enemy_id == &"ganger":
		debug_spawn(count)
		return count
	var pts: Array = []
	for i: int in count:
		var pt: Vector3 = _portal_point()
		if pt != Vector3.INF:
			pts.append(pt)
	return spawn_special(enemy_id, count, pts)


## Dev console: force-spawn n zombies at the nearest active spawn (ignores the round queue).
func debug_spawn(count: int) -> void:
	for i: int in count:
		var sp: ZombieSpawn = _choose_spawn()
		if sp == null or _free.is_empty():
			return
		RoundManager.to_spawn += 1
		var spec: Dictionary = RoundManager.take_spawn()
		spec["variant"] = _pick_variant()
		_free.pop_back().activate(spec, sp, _any_player())
