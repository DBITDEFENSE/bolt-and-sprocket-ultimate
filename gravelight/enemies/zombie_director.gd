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
var _boss_pending: float = -1.0    # seconds until a scheduled Foreman bursts out
var _screamer_at: float = -1.0     # fraction of the round spawned at which a Screamer appears
var _special_fx: bool = false
var _env: Environment = null
var _env_base: Dictionary = {}
var _lights: Array = []            # [OmniLight3D, base energy, uses_base_energy_prop]
var _flicker_t: float = 0.0


func _ready() -> void:
	ZombieBody.warm_up()
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
	for i: int in pack:
		if not RoundManager.can_spawn():
			break
		var spec: Dictionary = _spec_for(&"bellringer", RoundManager.take_spawn())
		var off: Vector3 = Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6))
		_activate_at(spec, _snap(center + off))
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
			var ok: bool = absf(pt.y - p.global_position.y) < 2.5 and _in_open_zone(pt) and not _crosses_closed_door(path)
			for q: Player in players:
				if q.global_position.distance_to(pt) < lo * relax:
					ok = false
			if ok:
				return pt
	# fallback: any active ground spawn
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp != null and sp.kind == &"ground" and sp.is_active(maxi(1, RoundManager.current_round)):
			return sp.global_position
	return Vector3.INF


## Fog portals only open in zones the players have bought into. Map 0 has one navmesh across closed doors
## (doors aren't baked), so a reachable-looking point can be behind a locked door: a pack spawned there
## would chase into the door and stall the round (playtest fix, T-026). Maps without zone volumes allow all.
func _in_open_zone(pt: Vector3) -> bool:
	if get_tree().get_nodes_in_group(&"zone_volumes").is_empty():
		return true
	var zone: StringName = ZoneVolume.zone_at(get_tree(), pt)
	return zone != &"" and GameState.is_zone_open(zone)


## True when a nav path runs through a door that's still shut (doors are colliders, not navmesh cuts).
func _crosses_closed_door(path: PackedVector3Array) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open:
			continue
		var dp: Vector2 = Vector2(d.global_position.x, d.global_position.z)
		var half: float = maxf(d.size.x, d.size.z) * 0.5 + 0.3
		for i: int in range(1, path.size()):
			var a: Vector3 = path[i - 1]
			var b: Vector3 = path[i]
			if absf((a.y + b.y) * 0.5 - d.global_position.y) > 2.0:
				continue
			if Geometry2D.get_closest_point_to_segment(dp, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(dp) < half:
				return true
	return false


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
			var l2: OmniLight3D = e[0]
			if not is_instance_valid(l2):
				continue
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
		var l: OmniLight3D = e[0]
		if not is_instance_valid(l):
			continue
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


## Creates a Foreman or Screamer at `at`. Counts as alive for round-end, outside the round queue.
func summon_boss(enemy_id: StringName, at: Vector3) -> Node3D:
	var z: Zombie = null
	match enemy_id:
		&"foreman":
			var f: Foreman = Foreman.new()
			f.director = self
			if Net.session != null:
				f.net_id = Net.session.next_extra_id()
			add_child(f)
			RoundManager.take_extra_spawn()
			f.spawn_boss(at, float(RoundManager.foreman_health(maxi(1, RoundManager.current_round), GameState.player_ids.size(), _ecfg(&"foreman"))))
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
	if want_glass:
		spec = _spec_for(&"glasshide", spec)
	var z: Zombie = _free.pop_back()
	z.activate(spec, sp, _any_player())
	GLBus.enemy_spawned.emit(z.enemy_id, z.get_instance_id())
	return true


func _player_zones() -> Dictionary:
	var out: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			out[ZoneVolume.zone_at(get_tree(), p.global_position)] = true
	return out


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
	var candidates: Array[ZombieSpawn] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp == null or not sp.is_active(round_number) or not _zone_allowed(sp.zone_id, player_zones):
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


func _pick_variant() -> String:
	var v: Dictionary = GLData.table("enemies")["enemies"]["ganger"]["variants"]
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
