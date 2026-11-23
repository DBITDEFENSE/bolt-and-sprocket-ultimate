class_name ShermanEvent
extends Node3D
## The Sherman on the first map, rounds 30 to 40 (T-249; data/gravelight/sherman.json, the map's json
## "sherman_event"; docs/u18/t249_sherman.md). The owner (2026-11-14): "on the first map on round 30 create a boss
## battle, add a Sherman tank coming to assist the team but it gets hit with a massive horde and explosive fire zombies.
## Add the ability though for the team to fight off the horde and then the tank will assist for another 10 rounds where
## it gets hit by a Stuka bomber. On round 40 I want to make the user get back in the house for cover because there
## will be airstrikes."
##   Round 30  ARRIVING  the engine is heard, then the tank comes up the carters' road from beyond the south-east edge
##                       (it rolls over the sawhorse barrier at the road's exit) and parks outside the yard's gate,
##                       facing it; der Fuhrmann (T-240's round-30 horse, the map row's own arrival beats) comes in up the
##                       road behind it, leading the horde.
##             ASSAULT   a massive horde rises round the tank and goes for it (Zombie.prey on its attack points; a share
##                       are FireZombies that burst against the hull). The tank's health is a boss bar; a counter says how
##                       many of the dead are on it. All of them dead with the tank still running: it HOLDS (a Resupply
##                       is thrown into the yard) and starts to help at once. The tank brewed up: it is LOST; the wreck
##                       is towed off at the round's end and a second Sherman comes `retry_after` rounds later
##                       (`retries` times), the same fight.
##   31..39    ASSIST    from where it stands it covers the yard and the road: the machine gun and the 75 mm on the dead it
##                       can see (ShermanTank._assist_step), never on players; it cannot be hurt.
##   Round 40  STUKA     the drone high up, "AIRCRAFT!", the dive with the siren's wail, the bomb: the Sherman brews up
##                       and burns where it stands (the wreck stays); then RAID: the air raid (AirRaid) sends everyone
##                       into the inn.
## Host decides; a co-op client runs the same node as a puppet: the tank follows mirrored state, the dive bomber flies
## the same pass, the markers and bursts come mirrored. Rounds 30 and 40 are reserved (no Bellringer round, no Foreman
## on them). A map without the block has no event.

enum Phase { IDLE, ARRIVING, ASSAULT, ASSIST, LOST, STUKA, RAID, DONE }

var map_cfg: Dictionary = {}
var cfg: Dictionary = {}
var director: ZombieDirector = null
var puppet: bool = false
var phase: Phase = Phase.IDLE
var tank: ShermanTank = null
var raid: AirRaid = null
var plane: StukaPlane = null
var hud: ShermanHud = null
var arrive_round: int = 30
var stuka_round: int = 40
var assist_until: int = 39
var retry_round: int = -1
var retries_left: int = 1
var t: float = 0.0
var outcome: String = ""               # "held" / "lost" (the last assault)
var assaults: int = 0
var assault_total: int = 0
var assault_fire_total: int = 0
var assault_spawned: int = 0
var assault_fire_spawned: int = 0
var attackers: Array[Zombie] = []
var tank_hits: int = 0
var barrier_crushed: bool = false
var stuka_hit_at: Vector3 = Vector3.INF
var _sched: Array = []
var _pack_t: float = 0.0
var _ring: Array[Vector3] = []
var _ring_at: Vector3 = Vector3.INF     # T-261: where the hull stood when the ring was laid (a driven tank moves)
var _reserved_alive: int = 0
var _boss_hud: BossHud = null
var _own_boss_hud: bool = false
var _net_t: float = 0.0
var _danger_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The map's block ({} when it has none).
static func block_for(map_id: StringName) -> Dictionary:
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return {}
	var v: Variant = GLData.load_json(path).get("sherman_event", {})
	return v if v is Dictionary else {}


static func table() -> Dictionary:
	return GLData.load_json("res://data/gravelight/sherman.json")


## One event under `map` when its json has the block (every peer; the host decides).
static func attach(map: Node) -> ShermanEvent:
	var mid: StringName = map.get("map_id") if map.get("map_id") != null else GameState.map_id
	var b: Dictionary = block_for(mid)
	if b.is_empty():
		return null
	var e: ShermanEvent = ShermanEvent.new()
	e.name = "ShermanEvent"
	e.map_cfg = b
	e.cfg = table()
	e.director = map.get("director") as ZombieDirector
	e.puppet = Net.is_client()
	map.add_child(e)
	return e


## The assault's size: count_base + count_per_extra_player for each player past the first.
static func assault_count(players: int, a: Dictionary) -> int:
	return int(a.get("count_base", 24)) + int(a.get("count_per_extra_player", 8)) * maxi(0, players - 1)


static func fire_count(total: int, a: Dictionary) -> int:
	return int(round(float(total) * float(a.get("fire_fraction", 0.25))))


## Is spawn number `i` (0-based) of `total` a fire zombie, `fires` of them spread evenly through the wave?
static func is_fire_slot(i: int, total: int, fires: int) -> bool:
	if fires <= 0 or total <= 0:
		return false
	var step: float = float(total) / float(fires)
	return int(floor(float(i) / step)) != int(floor(float(i + 1) / step)) or (fires >= total)


static func tank_hp(players: int, t_cfg: Dictionary) -> float:
	return float(t_cfg.get("hp_base", 8000)) * (1.0 + float(t_cfg.get("hp_player_step", 0.35)) * float(maxi(0, players - 1)))


## A view shake for every local human within `radius` of `at`, by the Camera Sway setting (DreadFx.picture_k).
static func shake_players(tree: SceneTree, at: Vector3, strength: float, radius: float) -> void:
	if tree == null:
		return
	var k0: float = DreadFx.picture_k()
	if k0 <= 0.0:
		return
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_local or p.is_bot:
			continue
		var d: float = p.global_position.distance_to(at)
		if d < radius:
			p.set("_shake", maxf(float(p.get("_shake")), strength * (1.0 - d / radius) * k0))


func _init() -> void:
	_rng.randomize()


func _ready() -> void:
	add_to_group(&"sherman_event")
	arrive_round = int(map_cfg.get("arrive_round", 30))
	stuka_round = int(map_cfg.get("stuka_round", 40))
	assist_until = mini(stuka_round - 1, arrive_round + int((cfg.get("assist", {}) as Dictionary).get("rounds", 9)))
	retries_left = int((cfg.get("assault", {}) as Dictionary).get("retries", 1))
	hud = ShermanHud.new()
	add_child(hud)
	raid = AirRaid.new()
	raid.cfg = cfg.get("raid", {})
	raid.map_cfg = map_cfg
	raid.hud = hud
	raid.host = not puppet
	add_child(raid)
	raid.finished.connect(_on_raid_finished)
	if director == null:
		director = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if not puppet:
		GLBus.round_started.connect(_on_round_started)
		GLBus.round_ended.connect(_on_round_ended)
		RoundManager.reserve_round(arrive_round)
		RoundManager.reserve_round(stuka_round)
	GLConsole.register("sherman", _cmd, "sherman 30|assist|40|raid|hold|kill|drive|out|status: the Sherman event on the Inn (T-249, T-261)")


func _exit_tree() -> void:
	if GLConsole.get("_commands") is Dictionary:
		var cmds: Dictionary = GLConsole.get("_commands")
		if cmds.has("sherman") and (cmds["sherman"]["fn"] as Callable).get_object() == self:
			cmds.erase("sherman")


func _map() -> Node:
	return get_parent()


func _banner(text: String, small: String = "") -> void:
	net_banner(text, small)
	if Net.replicating():
		Net.mirror(self, &"net_banner", [text, small])


func net_banner(text: String, small: String) -> void:
	var m: Node = _map()
	var h: Variant = m.get("hud") if m != null else null
	if h != null and is_instance_valid(h) and (h as Object).has_method("show_banner"):
		(h as Object).call("show_banner", text if small == "" else "%s\n%s" % [text, small], 3.5)
	print("[sherman] banner: %s / %s" % [text, small])


func at(seconds: float, fn: Callable) -> void:
	_sched.append([t + seconds, fn])


# ================================================================== the rounds

func _on_round_started(r: int, special: bool) -> void:
	if r == arrive_round or r == retry_round:
		if special:
			retry_round = r + 1
			return
		begin_arrival()
	elif r == stuka_round:
		begin_stuka()


func _on_round_ended(r: int) -> void:
	if phase == Phase.LOST:
		# the wreck is towed off; a second Sherman comes later (once), or none
		if tank != null and is_instance_valid(tank):
			tank.queue_free()
			tank = null
			if Net.replicating():
				Net.mirror(self, &"net_tank_gone", [])
		if retries_left > 0 and r + int(cfg["assault"].get("retry_after", 2)) < stuka_round:
			retries_left -= 1
			retry_round = r + int(cfg["assault"].get("retry_after", 2))
			RoundManager.reserve_round(retry_round)
			print("[sherman] the Sherman was lost on round %d: another comes on round %d" % [r, retry_round])
		phase = Phase.IDLE
	if phase == Phase.ASSIST and r >= assist_until and tank != null:
		print("[sherman] round %d over: the Sherman has covered the yard since round %d" % [r, arrive_round])


## Round 30 (or the retry): the tank comes up the road.
func begin_arrival() -> void:
	if phase == Phase.ARRIVING or phase == Phase.ASSAULT:
		return
	var a: Dictionary = cfg.get("arrival", {})
	phase = Phase.ARRIVING
	t = 0.0
	_sched.clear()
	_hold(true)
	if tank != null and is_instance_valid(tank):
		tank.queue_free()
	var route: PackedVector3Array = route_points()
	at(float(a.get("rumble_at", 0.5)), func() -> void:
		_spawn_tank(route[0], _leg_yaw(route, 0)))
	at(float(a.get("banner_at", 2.0)), func() -> void:
		_banner(str(a.get("banner", "")), str(a.get("banner_small", ""))))
	at(float(a.get("drive_at", 2.5)), func() -> void:
		if tank != null:
			tank.drive(route))
	print("[sherman] round %d: the Sherman is coming (%d m of road)" % [RoundManager.current_round, int(route_length(route))])


func route_points() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Variant in map_cfg.get("route", []):
		var v: Array = p
		out.append(Vector3(float(v[0]), float(v[1]), float(v[2])))
	return out


static func route_length(r: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in r.size() - 1:
		l += r[i].distance_to(r[i + 1])
	return l


static func _leg_yaw(r: PackedVector3Array, i: int) -> float:
	var d: Vector3 = r[mini(i + 1, r.size() - 1)] - r[maxi(0, mini(i, r.size() - 2))]
	return atan2(-d.x, -d.z)


## Where it parks and which way it faces (the route's last point, along the last leg).
func park_point() -> Vector3:
	var r: PackedVector3Array = route_points()
	return r[r.size() - 1] if not r.is_empty() else Vector3.ZERO


func park_yaw() -> float:
	var r: PackedVector3Array = route_points()
	return _leg_yaw(r, r.size() - 2) if r.size() >= 2 else 0.0


func _spawn_tank(pos: Vector3, yaw_rad: float) -> ShermanTank:
	var players: int = maxi(1, RoundManager.players)
	tank = ShermanTank.new()
	tank.setup(cfg.get("tank", {}), cfg.get("assist", {}), tank_hp(players, cfg.get("tank", {})), cfg.get("drive", {}), map_cfg)
	tank.puppet = puppet
	tank.hud = hud
	add_child(tank)
	tank.park_at(pos, yaw_rad)
	tank.wrecked.connect(_on_tank_wrecked)
	tank.bailed.connect(_on_tank_bailed)
	if Net.replicating():
		Net.mirror(self, &"net_tank", [pos, yaw_rad, tank.max_hp])
	return tank


func net_tank(pos: Vector3, yaw_rad: float, hp_max: float) -> void:
	if not puppet:
		return
	if tank != null and is_instance_valid(tank):
		tank.queue_free()
	tank = ShermanTank.new()
	tank.setup(cfg.get("tank", {}), cfg.get("assist", {}), hp_max, cfg.get("drive", {}), map_cfg)
	tank.puppet = true
	tank.hud = hud
	add_child(tank)
	tank.park_at(pos, yaw_rad)


## T-261: a player may climb in from now (parked), or no longer (the dive bomber is coming).
func net_drivable(on: bool) -> void:
	if tank != null and is_instance_valid(tank):
		tank.drivable = on


func _set_drivable(on: bool) -> void:
	net_drivable(on)
	if Net.replicating():
		Net.mirror(self, &"net_drivable", [on])


## The dead on the hull drove the driver out (outside the assault): the crew repairs, the hatch stays shut a while.
func _on_tank_bailed() -> void:
	var d: Dictionary = cfg.get("drive", {})
	_banner(str(d.get("bail_banner", "THE DEAD ARE ALL OVER THE SHERMAN")), str(d.get("bail_small", "ITS CREW IS MAKING REPAIRS")))
	print("[sherman] the dead drove the driver out of the Sherman (%d s of repairs)" % int(tank.lock_t))


func net_tank_gone() -> void:
	if tank != null and is_instance_valid(tank):
		tank.queue_free()
	tank = null


func _process(delta: float) -> void:
	if puppet:
		return
	t += delta
	for e: Array in _sched.duplicate():
		if t >= float(e[0]):
			_sched.erase(e)
			(e[1] as Callable).call()
	match phase:
		Phase.ARRIVING:
			_tick_arriving()
		Phase.ASSAULT:
			_tick_assault(delta)
		Phase.STUKA:
			_tick_stuka()
	if tank != null and is_instance_valid(tank):
		_tick_barrier()
		_net_t -= delta
		if Net.replicating() and _net_t <= 0.0:
			_net_t = 0.16 if tank.mode == ShermanTank.Mode.DRIVE else (0.1 if tank.is_driven() else 0.5)
			Net.mirror(tank, &"net_state", tank.net_state_args())
	_danger_t -= delta
	if _danger_t <= 0.0:
		_danger_t = 0.25
		_post_dangers()


func _tick_arriving() -> void:
	if tank == null or not is_instance_valid(tank) or not tank.parked() or tank.route.is_empty():
		return
	if tank.route_i < tank.route.size():
		return
	# parked: the banner, the turret onto the road, the assault a few seconds later
	tank.route = PackedVector3Array()
	var a: Dictionary = cfg.get("arrival", {})
	_banner(str(a.get("parked_banner", "THE SHERMAN IS HERE")))
	tank.aim_world(tank.global_transform * Vector3(0, 1.5, 12.0))
	_set_drivable(true)
	at(float(a.get("assault_after_park", 7.0)), begin_assault)
	tank.set_meta(&"parked_t", t)


## The barrier at the road's exit: the tank rolls over it (the sawhorse's drawing goes flat; its collider, at the
## edge of the map, is left as it is).
func _tick_barrier() -> void:
	if barrier_crushed or tank.mode != ShermanTank.Mode.DRIVE:
		return
	var b: Dictionary = map_cfg.get("barrier", {})
	var bp: Array = b.get("pos", [])
	if bp.size() < 3:
		return
	var pos: Vector3 = Vector3(float(bp[0]), float(bp[1]), float(bp[2]))
	if Vector2(tank.global_position.x - pos.x, tank.global_position.z - pos.z).length() < 3.2:
		crush_barrier(pos, str(b.get("name", "Sawhorse")))
		if Net.replicating():
			Net.mirror(self, &"crush_barrier", [pos, str(b.get("name", "Sawhorse"))])


func crush_barrier(pos: Vector3, node_name: String) -> void:
	if barrier_crushed:
		return
	barrier_crushed = true
	var m: Node = _map()
	if m != null:
		for n: Node in m.find_children(node_name + "*", "Node3D", true, false):
			var n3: Node3D = n as Node3D
			if n3.global_position.distance_to(pos) < 1.0:
				n3.visible = false
	# what is left of it, flat in the snow
	var wreck: Node3D = Node3D.new()
	wreck.name = "CrushedBarrier"
	add_child(wreck)
	wreck.global_position = pos
	var k: ProcKit = ProcKit.new()
	for i: int in 6:
		var x: float = -2.3 + 0.85 * float(i) + _rng.randf_range(-0.2, 0.2)
		k.box("paint" if i % 2 == 0 else "cream", Vector3(x, 0.05, _rng.randf_range(-0.6, 0.6)), Vector3(0.8, 0.05, 0.18), Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, _rng.randf_range(-0.15, 0.15)))
	for j: int in 4:
		k.box("wood", Vector3(_rng.randf_range(-2.4, 2.4), 0.04, _rng.randf_range(-0.9, 0.9)), Vector3(0.07, 0.07, 0.9), Basis(Vector3.UP, _rng.randf_range(0, PI)))
	var mk: Array = k.commit()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mk[0]
	var cols: Dictionary = {"paint": Color(0.55, 0.08, 0.06), "cream": Color(0.85, 0.8, 0.68), "wood": Color(0.32, 0.22, 0.13)}
	for s: int in (mk[1] as Array).size():
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.albedo_color = cols.get(str((mk[1] as Array)[s]), Color.GRAY)
		sm.roughness = 0.9
		sm.vertex_color_use_as_albedo = true
		mi.set_surface_override_material(s, sm)
	wreck.add_child(mi)
	BossFx.burst("chips", pos + Vector3.UP * 0.6, get_tree(), 2.0, 1.4)
	Effects.dirt_burst(pos, "snow", 1.6, Vector3.UP, 20)
	AudioDirector.play_3d("horse_boss_crash", pos + Vector3.UP, 2.0)
	print("[sherman] it rolls over the barrier at the road's end")


# ================================================================== the assault

## The dead come for the tank: `assault_count` of them, fire_fraction of them burning, in packs round it.
func begin_assault() -> void:
	if tank == null or not is_instance_valid(tank) or tank.is_wreck():
		return
	var a: Dictionary = cfg.get("assault", {})
	phase = Phase.ASSAULT
	assaults += 1
	assault_total = assault_count(maxi(1, RoundManager.players), a)
	assault_fire_total = fire_count(assault_total, a)
	assault_spawned = 0
	assault_fire_spawned = 0
	attackers.clear()
	_pack_t = 0.0
	tank.attackable = true
	tank.defending = true   # T-261: it fights for itself while the dead are on it
	tank.hp = tank.max_hp
	_ring = _ring_points()
	_ring_at = tank.global_position
	_banner(str(a.get("banner", "")), str(a.get("banner_small", "")))
	_bar_on(true)
	if Net.replicating():
		Net.mirror(self, &"net_bar", [true])
	print("[sherman] the assault: %d of the dead, %d of them burning; the tank has %d health (%d spawn points)" % [assault_total, assault_fire_total, int(tank.max_hp), _ring.size()])


## Spawn points round the parked tank: rings of ring_min..ring_max m in the assault zones, on the navmesh, never
## within 6 m of a player.
func _ring_points() -> Array[Vector3]:
	var a: Dictionary = cfg.get("assault", {})
	var out: Array[Vector3] = []
	if director == null:
		return out
	var c: Vector3 = tank.global_position
	var zones: Array = map_cfg.get("assault_zones", [])
	var rid: RID = director.get_world_3d().navigation_map
	for k: int in 24:
		var ang: float = TAU * float(k) / 24.0
		for rr: float in [float(a.get("ring_min", 10.0)), (float(a.get("ring_min", 10.0)) + float(a.get("ring_max", 16.0))) * 0.5, float(a.get("ring_max", 16.0))]:
			var p: Vector3 = c + Vector3(cos(ang), 0, sin(ang)) * rr
			var q: Vector3 = NavigationServer3D.map_get_closest_point(rid, p)
			if q.distance_to(p) > 1.5 or absf(q.y - c.y) > 1.0:
				continue
			if not zones.is_empty() and not zones.has(String(ZoneVolume.zone_at(get_tree(), q + Vector3.UP * 0.6))):
				continue
			out.append(q)
	return out


func _spawn_point() -> Vector3:
	var cands: Array[Vector3] = []
	for p: Vector3 in _ring:
		var ok: bool = true
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var pl: Player = n as Player
			if pl != null and pl.is_alive() and pl.global_position.distance_to(p) < 6.0:
				ok = false
				break
		if ok:
			cands.append(p)
	if cands.is_empty():
		cands = _ring
	if cands.is_empty():
		return Vector3.INF
	return cands[_rng.randi() % cands.size()]


func _tick_assault(delta: float) -> void:
	var a: Dictionary = cfg.get("assault", {})
	# the dead that are gone (killed, burst, recycled into the queue) leave the wave
	for z: Zombie in attackers.duplicate():
		if not is_instance_valid(z) or not z.is_active() or z.state == Zombie.State.DEAD or not (z.prey is ShermanAttackPoint):
			attackers.erase(z)
	if tank == null or not is_instance_valid(tank) or tank.is_wreck():
		return
	# T-261: a driven tank moves: the dead rise round where it is now (the old ring is kept if the new place has none)
	if ShermanRules.flat(_ring_at, tank.global_position) > float(a.get("ring_relay_m", 3.0)):
		_ring_at = tank.global_position
		var again: Array[Vector3] = _ring_points()
		if not again.is_empty():
			_ring = again
	_pack_t -= delta
	if assault_spawned < assault_total and _pack_t <= 0.0:
		var room: int = int(a.get("max_at_once", 12)) - attackers.size()
		var n: int = mini(mini(int(a.get("pack_size", 4)), assault_total - assault_spawned), room)
		for i: int in n:
			if spawn_attacker(is_fire_slot(assault_spawned, assault_total, assault_fire_total)) == null:
				break
		_pack_t = float(a.get("pack_gap", 3.5))
	var left: int = (assault_total - assault_spawned) + attackers.size()
	_counter("THE DEAD ON THE SHERMAN: %d" % left)
	if assault_spawned >= assault_total:
		_hold(false)
		if attackers.is_empty():
			assault_held()


## One of the dead for the tank: a pooled zombie risen at a ring point, sent at the least-crowded attack point; a fire
## zombie when `fire`. Counted as one of the round's (an extra spawn: the round cannot end while it stands).
func spawn_attacker(fire: bool) -> Zombie:
	if director == null or director.free_count() <= 0:
		return null
	var at_pos: Vector3 = _spawn_point()
	if at_pos == Vector3.INF:
		return null
	var spec: Dictionary = RoundManager.take_extra_spawn()
	var fz: Dictionary = cfg.get("fire_zombie", {})
	if fire:
		spec["health"] = float(spec.get("health", 150)) * float(fz.get("health_mult", 0.45))
		spec["tier"] = StringName(str(fz.get("tier", "jog")))
		spec["variant"] = str(fz.get("kit", "villager"))
	var z: Zombie = director.activate_reserved(spec, at_pos)
	if z == null:
		RoundManager.alive = maxi(0, RoundManager.alive - 1)
		return null
	var best: ShermanAttackPoint = null
	var best_n: int = 1 << 20
	for ap: ShermanAttackPoint in tank.points:
		var c: int = 0
		for o: Zombie in attackers:
			if is_instance_valid(o) and o.prey == ap:
				c += 1
		var score: int = c * 100 + int(ap.global_position.distance_to(at_pos))
		if score < best_n:
			best_n = score
			best = ap
	z.prey = best
	attackers.append(z)
	assault_spawned += 1
	if fire:
		assault_fire_spawned += 1
		FireZombie.make(z, fz, tank, true)
		if Net.replicating():
			Net.mirror(self, &"net_fire_zombie", [z.net_id])
	return z


func net_fire_zombie(net_id: int) -> void:
	if not puppet or Net.session == null:
		return
	var z: Zombie = Net.session.zombie_by_net_id(net_id)
	if z != null:
		FireZombie.make(z, cfg.get("fire_zombie", {}), tank, false)


## FireZombie.burst tells the event (the effects for every client).
func on_fire_burst(pos: Vector3) -> void:
	if Net.replicating():
		Net.mirror(self, &"net_fire_burst", [pos])


func net_fire_burst(pos: Vector3) -> void:
	if not puppet:
		return
	var fz: Dictionary = cfg.get("fire_zombie", {})
	FirePatch.spawn(get_tree(), pos, fz, false)
	FireZombie.burst_fx(get_tree(), pos, float(fz.get("blast_radius", 4.0)))


func assault_held() -> void:
	var a: Dictionary = cfg.get("assault", {})
	phase = Phase.ASSIST
	outcome = "held"
	tank.attackable = false
	tank.defending = false
	tank.assisting = true
	_counter("")
	_bar_on(false)
	if Net.replicating():
		Net.mirror(self, &"net_bar", [false])
	_banner(str(a.get("held_banner", "THE SHERMAN HOLDS")), str(a.get("held_small", "")))
	# (T-261: thrown where it always was, before the gate, wherever the tank has been driven to)
	PowerupManager.spawn(&"resupply", Transform3D(Basis(Vector3.UP, park_yaw()), park_point()) * Vector3(0, 0.3, -5.0))
	print("[sherman] it holds (%d health left of %d, %d swipes, %d of the dead): it covers the yard until round %d" % [int(tank.hp), int(tank.max_hp), tank.swipes_taken, assault_total, assist_until])


func _on_tank_wrecked() -> void:
	if phase == Phase.ASSAULT or phase == Phase.ARRIVING:
		var a: Dictionary = cfg.get("assault", {})
		phase = Phase.LOST
		outcome = "lost"
		_counter("")
		_hold(false)
		if _boss_hud != null and is_instance_valid(_boss_hud):
			_boss_hud.strike("sherman", true)
		if Net.replicating():
			Net.mirror(self, &"net_bar", [false])
		_banner(str(a.get("lost_banner", "THE SHERMAN IS BURNING")))
		print("[sherman] the Sherman is lost (%d of %d of the dead were up, %d swipes)" % [assault_spawned, assault_total, tank.swipes_taken])


## The round cannot end while the tank comes and the assault is still rising (an alive slot held, as the homage
## bosses do).
func _hold(on: bool) -> void:
	if on and _reserved_alive == 0:
		RoundManager.reserve_alive(1)
		_reserved_alive = 1
	elif not on and _reserved_alive > 0:
		_reserved_alive = 0
		RoundManager.release_alive(1)


func _counter(text: String) -> void:
	if hud != null and hud.counter.text != text:
		hud.set_counter(text)
		if Net.replicating():
			Net.mirror(self, &"net_counter", [text])


func net_counter(text: String) -> void:
	if hud != null:
		hud.set_counter(text)


## The tank's health on the boss bar: the round's BossHud when one is up (der Fuhrmann's), else our own.
func _bar_on(on: bool) -> void:
	var a: Dictionary = cfg.get("assault", {})
	if on:
		if _boss_hud == null or not is_instance_valid(_boss_hud):
			_boss_hud = null
			for c: Node in _map().get_children():
				if c is BossHud and not c.is_queued_for_deletion():
					_boss_hud = c as BossHud
			if _boss_hud == null:
				_boss_hud = BossHud.new()
				_own_boss_hud = true
				add_child(_boss_hud)
		_boss_hud.add_bar("sherman", tank, str(a.get("bar_name", "THE SHERMAN")), str(a.get("bar_small", "")))
	elif _boss_hud != null and is_instance_valid(_boss_hud):
		_boss_hud.strike("sherman", tank == null or not is_instance_valid(tank) or tank.is_wreck())


func net_bar(on: bool) -> void:
	if puppet:
		_bar_on(on)


# ================================================================== round 40

func begin_stuka() -> void:
	var s: Dictionary = cfg.get("stuka", {})
	phase = Phase.STUKA
	t = 0.0
	_sched.clear()
	var target: Vector3 = park_point() + Vector3.UP * 1.0
	if tank != null and is_instance_valid(tank):
		# T-261: nobody drives it from here on: the driver is put out beside it now (the bomb is some eleven seconds
		# away), and it stays where it stands for the dive
		if not tank.is_wreck():
			if tank.is_driven():
				tank.put_out()
				_banner(str((cfg.get("drive", {}) as Dictionary).get("stuka_banner", "GET CLEAR OF THE SHERMAN")))
			_set_drivable(false)
		target = tank.global_position + Vector3.UP * 1.2
	var sf: Array = map_cfg.get("stuka_from", [-260.0, 0.0, -320.0])
	var from_dir: Vector3 = (Vector3(float(sf[0]), 0, float(sf[2])) - Vector3(target.x, 0, target.z)).normalized()
	at(float(s.get("engine_at", 1.0)), func() -> void:
		net_stuka(target, from_dir)
		if Net.replicating():
			Net.mirror(self, &"net_stuka", [target, from_dir]))
	at(float(s.get("banner_at", 3.0)), func() -> void:
		_banner(str(s.get("banner", "AIRCRAFT!")), str(s.get("banner_small", ""))))
	print("[sherman] round %d: the dive bomber (the Sherman is %s)" % [RoundManager.current_round, "there" if tank != null and is_instance_valid(tank) and not tank.is_wreck() else "gone"])


func net_stuka(target: Vector3, from_dir: Vector3) -> void:
	if plane != null and is_instance_valid(plane):
		plane.queue_free()
	plane = StukaPlane.new()
	add_child(plane)
	plane.fly(target, from_dir, cfg.get("stuka", {}))
	plane.impact.connect(_on_stuka_impact)


func _tick_stuka() -> void:
	# the crew sees it coming: the turret swings up and the machine gun fires at it as it dives
	if plane == null or not is_instance_valid(plane) or tank == null or not is_instance_valid(tank) or tank.is_wreck():
		return
	if plane.global_position.distance_to(tank.global_position) < 380.0 and not plane.released:
		tank.assisting = false
		tank.aim_world(plane.global_position)
		if Engine.get_process_frames() % 6 == 0:
			var from: Vector3 = tank.coax()
			var to: Vector3 = from + (plane.global_position - from).normalized() * 140.0 + Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-4, 8), _rng.randf_range(-8, 8))
			tank.fire_mg_fx(from, to, false)
			if Net.replicating():
				Net.mirror(tank, &"fire_mg_fx", [from, to, false])


func _on_stuka_impact(pos: Vector3) -> void:
	stuka_hit_at = pos
	var rc: Dictionary = cfg.get("raid", {})
	AirRaid.burst_fx(get_tree(), pos, float(rc.get("radius", 6.5)), 1.0, 45.0)
	if puppet:
		return
	if tank != null and is_instance_valid(tank) and not tank.is_wreck():
		tank.wreck(true)
		if Net.replicating():
			Net.mirror(tank, &"net_state", tank.net_state_args())
	raid.hurt(pos)
	print("[sherman] the dive bomber's bomb lands at %s: the Sherman brews up" % str(pos.snapped(Vector3.ONE * 0.1)))
	at(float(rc.get("warn_after_stuka", 2.5)), func() -> void:
		phase = Phase.RAID
		_banner(str(rc.get("warn_banner", "AIR RAID")), str(rc.get("warn_small", "GET INSIDE THE INN")))
		raid.start())


func _on_raid_finished() -> void:
	if not puppet:
		phase = Phase.DONE
		_banner(str((cfg.get("raid", {}) as Dictionary).get("clear_banner", "ALL CLEAR")))
		print("[sherman] the raid is over")


# ================================================================== the bots: danger discs on the squad's map

func _blackboard() -> Object:
	var m: Node = _map()
	var squad: Object = m.get("squad") if m != null else null
	if squad == null or not squad.has_method("time"):
		return null
	var bb: Object = squad.get("blackboard")
	return bb if bb != null and bb.has_method("add_danger") else null


## What the squad's bots are told (BotBlackboard.add_danger, the call the horse and the vacuum use): the tank's hull
## (a little cost, so a bot walks round it, not into it), the bombs' rings while they fall, the burning patches.
func _post_dangers() -> void:
	var bb: Object = _blackboard()
	if bb == null:
		return
	var now: float = float(_map().get("squad").call("time"))
	if tank != null and is_instance_valid(tank):
		for i: int in 3:
			bb.call("add_danger", tank.global_transform * Vector3(0, 0, -2.0 + 2.0 * float(i)), 2.0, 2.0, now + 0.6, "sherman_hull:%d" % i)
		# T-261: and the ground it is about to roll onto while a player drives it
		if tank.is_driven() and absf(tank.speed) > 0.3:
			var dd: Dictionary = cfg.get("drive", {})
			bb.call("add_danger", tank.global_transform * Vector3(0, 0, -signf(tank.speed) * float(dd.get("bot_clear_ahead_m", 5.0))), float(dd.get("bot_clear_r", 3.0)), float(dd.get("bot_clear_cost", 6.0)), now + 0.6, "sherman_path")
	if raid != null:
		var k: int = 0
		for p: Vector3 in raid.pending_points():
			bb.call("add_danger", p, float(raid.cfg.get("radius", 6.5)) + 0.5, 8.0, now + 0.6, "air_raid:%d" % k)
			k += 1
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for c: Node in scene.get_children():
		if c is FirePatch:
			bb.call("add_danger", (c as FirePatch).global_position, (c as FirePatch).radius + 0.3, 5.0, now + 0.6, "fire_patch:%d" % c.get_instance_id())


# ================================================================== the dev console / the smoke

func _cmd(a: PackedStringArray) -> String:
	var what: String = a[0] if not a.is_empty() else "status"
	match what:
		"30", "arrive":
			if RoundManager.state == RoundManager.State.ROUND:
				begin_arrival()
				return "The Sherman is coming now (round %d)." % RoundManager.current_round
			RoundManager.debug_set_round(arrive_round)
			return "Next round: %d (the Sherman)." % arrive_round
		"assist":
			force_assist()
			return "The Sherman is parked and covering the yard."
		"40", "stuka":
			if tank == null or not is_instance_valid(tank):
				force_assist()
			if RoundManager.state == RoundManager.State.ROUND:
				begin_stuka()
				return "The dive bomber now."
			RoundManager.debug_set_round(stuka_round)
			return "Next round: %d (the dive bomber, the raid)." % stuka_round
		"raid":
			phase = Phase.RAID
			raid.start()
			return "Air raid."
		"hold":
			for z: Zombie in attackers.duplicate():
				if is_instance_valid(z) and z.is_active():
					z.kill_silently()
			assault_spawned = assault_total
			return "The assault is beaten off."
		"kill":
			if tank != null and is_instance_valid(tank):
				tank.wreck(true)
			return "The Sherman brews up."
		"drive":
			if tank == null or not is_instance_valid(tank) or tank.is_wreck():
				force_assist()
			var me: Player = _map().get("player") as Player
			if me != null and tank.can_use(me):
				tank.on_use(me)
				return "You are in the Sherman."
			return "The Sherman cannot be driven now."
		"out":
			if tank != null and is_instance_valid(tank):
				tank.put_out()
			return "Out of the Sherman."
	return status()


## Dev / smoke: the tank parked at its place and covering the yard, now.
func force_assist() -> void:
	if tank == null or not is_instance_valid(tank) or tank.is_wreck():
		_spawn_tank(park_point(), park_yaw())
	tank.put_out()
	tank.park_at(park_point(), park_yaw())
	tank.attackable = false
	tank.defending = false
	tank.assisting = true
	_set_drivable(true)
	phase = Phase.ASSIST
	outcome = "held"


func status() -> String:
	var tk: String = ""
	if tank != null and is_instance_valid(tank):
		tk = "; 75 mm %d (%d the driver's, %d held), mg %d, kills %d, driven %d times, crushed %d, driver %s" % [tank.shots_main, tank.driver_shells, tank.shots_held, tank.shots_mg, tank.kills, tank.drives, tank.crushed, str(tank.driver.player_id) if tank.is_driven() else "none"]
	return "Sherman: phase %s, round %d, tank %s (hp %d/%d), assault %d/%d (%d burning) %d up, outcome '%s', retry %d, raid %s (%d bombs)" % [
		Phase.keys()[phase], RoundManager.current_round,
		"none" if tank == null or not is_instance_valid(tank) else ShermanTank.Mode.keys()[tank.mode],
		int(tank.hp) if tank != null and is_instance_valid(tank) else 0, int(tank.max_hp) if tank != null and is_instance_valid(tank) else 0,
		assault_spawned, assault_total, assault_fire_spawned, attackers.size(), outcome, retry_round,
		AirRaid.Phase.keys()[raid.phase] if raid != null else "-", raid.bombs_landed if raid != null else 0] + tk
