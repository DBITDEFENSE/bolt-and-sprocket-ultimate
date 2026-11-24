class_name AirRaid
extends Node3D
## Round 40's air raid on the Inn (T-249; sherman.json "raid", map00.json "sherman_event": shelter_zones, inn_box,
## shelter_points, bomb_zones). The owner: "on round 40 I want to make the user get back in the house for cover
## because there will be airstrikes".
##   WARN     the air-raid siren, the banner and the Operator's line ("please proceed to the cellars"), then a
##            countdown (`countdown` s) before the first bomb, the HUD telling each player whether they are under a roof;
##   BOMBING  `duration` s of bombs on the yard and the grounds: each one's shadow and ring show `telegraph` s before
##            it lands (the whistle at whistle_before, the bomb itself in the last second), so a bomb can be read and
##            run from; outside, a bomb within `radius` does player_damage at the centre falling to player_damage_edge
##            (Blastproof halves it); inside the inn nothing reaches you; the dead are blown apart (a share of the
##            round's health); a part of the bombs is laid where a player outside stands (aim_at_player_chance), so
##            staying out is not a gamble you win;
##   CLEAR    the all-clear and its line; the round goes on as rounds do.
## Host decides (where, when, who is hurt); every peer sees the markers and the bursts from the mirrored calls.
## T-271: the raid on other maps. The map's block may say `"shelter_roof": true`: anywhere with something solid overhead
## (a ray up from head height, ROOF_RAY m, the world's colliders) is a shelter too, and no bomb is laid there: the
## Kaue in Kaltenbrunn's open yard, the roofed half of Totenhafen's cannery. Map 0's block does not say it (its
## shelters are its zones and the inn's box, as before).
## Bots: BotSetPieces asks `shelter_for(player)` (group "air_raid") and walks a bot outside to the nearest shelter point.

signal finished

enum Phase { IDLE, WARN, BOMBING, CLEAR }

const ROOF_RAY: float = 60.0           # T-271: how far up a roof is looked for (shelter_roof)

var cfg: Dictionary = {}               # sherman.json "raid"
var map_cfg: Dictionary = {}           # the map's sherman_event block
var hud: ShermanHud = null
var host: bool = true
var phase: Phase = Phase.IDLE
var t: float = 0.0
var bombs_dropped: int = 0
var bombs_landed: int = 0
var hits_outside: int = 0              # players hurt by a bomb (tests / the smoke)
var spared_inside: int = 0             # players a bomb would have reached but the roof kept safe
var zombies_hit: int = 0
var last_impacts: Array[Vector3] = []
var _next_bomb: float = 0.0
var _siren_t: float = 0.0
var _pending: Array = []               # [{pos, t_left, node, whistled, falling}]
var _drone: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "AirRaid"


func _ready() -> void:
	add_to_group(&"air_raid")
	_rng.randomize()


# ================================================================== pure rules (unit-tested)

## True when `p` is under the inn's roof: its zone is one of the shelter zones, or no zone claims it and it stands in
## the inn's box (a stair corner the volumes miss).
static func is_sheltered_at(zone: StringName, p: Vector3, shelter_zones: Array, inn_box: Array) -> bool:
	if shelter_zones.has(String(zone)):
		return true
	if String(zone) != "" or inn_box.size() < 2:
		return false
	var lo: Array = inn_box[0]
	var hi: Array = inn_box[1]
	return p.x >= float(lo[0]) and p.x <= float(hi[0]) and p.y >= float(lo[1]) and p.y <= float(hi[1]) and p.z >= float(lo[2]) and p.z <= float(hi[2])


func is_sheltered(p: Vector3) -> bool:
	var z: StringName = ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6)
	if is_sheltered_at(z, p, map_cfg.get("shelter_zones", []), map_cfg.get("inn_box", [])):
		return true
	return bool(map_cfg.get("shelter_roof", false)) and roof_over(p)


## T-271: something solid over `p` (the world's colliders, from head height up).
func roof_over(p: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.2, p + Vector3.UP * ROOF_RAY, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A bomb's damage to a player `d` metres from it (flat): the centre's player_damage down to player_damage_edge at
## the ring; 0 past it.
static func bomb_damage(d: float, c: Dictionary) -> float:
	var r: float = float(c.get("radius", 6.5))
	if d > r:
		return 0.0
	return lerpf(float(c.get("player_damage", 110)), float(c.get("player_damage_edge", 30)), clampf(d / maxf(0.01, r), 0.0, 1.0))


static func bomb_zombie_damage(d: float, c: Dictionary, round_health: float) -> float:
	var r: float = float(c.get("radius", 6.5))
	if d > r:
		return 0.0
	return round_health * lerpf(float(c.get("zombie_damage_frac", 1.2)), float(c.get("zombie_damage_edge_frac", 0.5)), clampf(d / maxf(0.01, r), 0.0, 1.0))


static func in_box_grown(p: Vector3, box: Array, m: float) -> bool:
	if box.size() < 2:
		return false
	var lo: Array = box[0]
	var hi: Array = box[1]
	return p.x >= float(lo[0]) - m and p.x <= float(hi[0]) + m and p.z >= float(lo[2]) - m and p.z <= float(hi[2]) + m


# ================================================================== the sequence (host)

func start() -> void:
	phase = Phase.WARN
	t = 0.0
	bombs_dropped = 0
	bombs_landed = 0
	_siren_t = 0.0
	if host:
		GLVO.play(StringName(str(cfg.get("vo_warn", ""))))
		if Net.replicating():
			Net.mirror(self, &"net_phase", [int(Phase.WARN), 0.0])
	_enter_fx(Phase.WARN)
	print("[air_raid] warning: bombs in %.0f s" % float(cfg.get("countdown", 20.0)))


func _enter_fx(p: Phase) -> void:
	match p:
		Phase.WARN:
			_siren()
		Phase.BOMBING:
			_drone = AudioDirector.make_loop_2d("war_bomber_drone", self, -4.0)
			if _drone != null:
				_drone.play()
		Phase.CLEAR:
			if _drone != null:
				var tw: Tween = create_tween()
				tw.tween_property(_drone, "volume_db", -40.0, 3.0)
				tw.tween_callback(_drone.stop)
			if hud != null:
				hud.set_warning(str(cfg.get("clear_banner", "ALL CLEAR")), "", "", "", true)
				get_tree().create_timer(3.5).timeout.connect(func() -> void:
					if hud != null and is_instance_valid(hud):
						hud.clear_warning())


func _siren() -> void:
	AudioDirector.play_2d("a1_siren", -5.0, 0.0)


func net_phase(p: int, _secs: float) -> void:
	if host:
		return
	phase = p as Phase
	t = 0.0
	_enter_fx(phase)


func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	t += delta
	_update_hud()
	if phase == Phase.WARN or phase == Phase.BOMBING:
		_siren_t += delta
		if _siren_t >= float(cfg.get("siren_every", 9.0)):
			_siren_t = 0.0
			_siren()
	_tick_pending(delta)
	if not host:
		return
	match phase:
		Phase.WARN:
			if t >= float(cfg.get("countdown", 20.0)):
				phase = Phase.BOMBING
				t = 0.0
				_next_bomb = 0.0
				GLVO.play(StringName(str(cfg.get("vo_during", ""))))
				if Net.replicating():
					Net.mirror(self, &"net_phase", [int(Phase.BOMBING), 0.0])
				_enter_fx(Phase.BOMBING)
				print("[air_raid] bombing for %.0f s" % float(cfg.get("duration", 60.0)))
		Phase.BOMBING:
			_next_bomb -= delta
			if _next_bomb <= 0.0 and t < float(cfg.get("duration", 60.0)):
				_next_bomb = float(cfg.get("bomb_gap", 1.6)) + _rng.randf_range(-1.0, 1.0) * float(cfg.get("bomb_gap_jitter", 0.5))
				var at: Vector3 = pick_point()
				if at != Vector3.INF:
					drop(at)
			if t >= float(cfg.get("duration", 60.0)) and _pending.is_empty():
				phase = Phase.CLEAR
				t = 0.0
				GLVO.play(StringName(str(cfg.get("vo_clear", ""))))
				if Net.replicating():
					Net.mirror(self, &"net_phase", [int(Phase.CLEAR), 0.0])
				_enter_fx(Phase.CLEAR)
				print("[air_raid] all clear: %d bombs, %d hits outside, %d spared inside, %d of the dead hit" % [bombs_landed, hits_outside, spared_inside, zombies_hit])
		Phase.CLEAR:
			if t >= 4.0:
				phase = Phase.IDLE
				finished.emit()


func _update_hud() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	var me: Player = BossFx.local_human(get_tree())
	var safe: bool = me != null and is_sheltered(me.global_position)
	match phase:
		Phase.WARN:
			var left: int = int(ceil(float(cfg.get("countdown", 20.0)) - t))
			hud.set_warning(str(cfg.get("warn_banner", "AIR RAID")), str(cfg.get("warn_small", "GET INSIDE THE INN")),
				str(cfg.get("countdown_text", "BOMBS IN %d")) % maxi(0, left),
				str(cfg.get("inside_text", "")) if safe else str(cfg.get("outside_text", "")), safe)
		Phase.BOMBING:
			hud.set_warning(str(cfg.get("warn_banner", "AIR RAID")), "", "",
				str(cfg.get("inside_text", "")) if safe else str(cfg.get("outside_text", "")), safe)


## Where the next bomb falls (host): a part of them where a player outside stands (with scatter), the rest on open
## ground in the bomb zones near the squad (so the windows show them); never on the inn or within a metre of it.
func pick_point() -> Vector3:
	var tree: SceneTree = get_tree()
	var zones: Array = map_cfg.get("bomb_zones", [])
	var box: Array = map_cfg.get("inn_box", [])
	var players: Array[Player] = []
	var outside: Array[Player] = []
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			players.append(p)
			if not is_sheltered(p.global_position):
				outside.append(p)
	var rid: RID = get_world_3d().navigation_map
	if not outside.is_empty() and _rng.randf() < float(cfg.get("aim_at_player_chance", 0.4)):
		var who: Player = outside[_rng.randi() % outside.size()]
		var sc: float = float(cfg.get("aim_scatter", 3.0))
		var a: float = _rng.randf() * TAU
		var q: Vector3 = who.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.0, sc)
		q = NavigationServer3D.map_get_closest_point(rid, q)
		if _bomb_ok(q, zones, box):
			return q
	var near_m: float = float(cfg.get("near_players_m", 35.0))
	for k: int in 40:
		var p2: Vector3 = NavigationServer3D.map_get_random_point(rid, 0x7FFFFFFF, true)
		if not _bomb_ok(p2, zones, box):
			continue
		var close: bool = players.is_empty()
		for pl: Player in players:
			if pl.global_position.distance_to(p2) <= near_m:
				close = true
				break
		if close:
			return p2
	return Vector3.INF


func _bomb_ok(p: Vector3, zones: Array, box: Array) -> bool:
	if p.y > 2.0 or p.y < -1.0:
		return false   # open ground only (not a deck, a roof or the cellar)
	if in_box_grown(p, box, 1.0):
		return false
	var z: StringName = ZoneVolume.zone_at(get_tree(), p + Vector3.UP * 0.6)
	if not zones.has(String(z)):
		return false
	return not (bool(map_cfg.get("shelter_roof", false)) and roof_over(p))   # T-271: never onto a roof that shelters


## A bomb on its way to `at` (host): the marker everywhere, the burst `telegraph` s later.
func drop(at: Vector3) -> void:
	bombs_dropped += 1
	var tl: float = float(cfg.get("telegraph", 3.0))
	net_marker(at, tl)
	if Net.replicating():
		Net.mirror(self, &"net_marker", [at, tl])


func net_marker(at: Vector3, t_left: float) -> void:
	var m: Node3D = _marker(at)
	_pending.append({"pos": at, "t_left": t_left, "total": t_left, "node": m, "whistled": false, "bomb": null})


func _marker(at: Vector3) -> Node3D:
	var r: float = float(cfg.get("radius", 6.5))
	var n: Node3D = Node3D.new()
	n.name = "BombMarker"
	add_child(n)
	n.global_position = at + Vector3.UP * 0.04
	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "Shadow"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 32
	disc.mesh = cm
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.scale = Vector3(1.0, 1.0, 1.0)
	n.add_child(disc)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = r - 0.12
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 4
	ring.mesh = tm
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.32, 0.12, 0.0)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.3, 0.1)
	rm.emission_energy_multiplier = 1.5
	ring.material_override = rm
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	return n


func _tick_pending(delta: float) -> void:
	var r: float = float(cfg.get("radius", 6.5))
	for e: Dictionary in _pending.duplicate():
		e["t_left"] = float(e["t_left"]) - delta
		var tl: float = float(e["t_left"])
		var u: float = clampf(1.0 - tl / maxf(0.1, float(e["total"])), 0.0, 1.0)
		var node: Node3D = e["node"]
		if is_instance_valid(node):
			var disc: MeshInstance3D = node.get_node("Shadow")
			var s: float = lerpf(1.0, r * 0.85, u * u)
			disc.scale = Vector3(s, 1.0, s)
			var dm: StandardMaterial3D = disc.material_override as StandardMaterial3D
			dm.albedo_color = Color(0, 0, 0, 0.15 + 0.5 * u)
			var ring: MeshInstance3D = node.get_node("Ring")
			var rm: StandardMaterial3D = ring.material_override as StandardMaterial3D
			rm.albedo_color = Color(1.0, 0.32, 0.12, 0.35 + 0.45 * (0.5 + 0.5 * sin(u * 30.0)))
		if not bool(e["whistled"]) and tl <= float(cfg.get("whistle_before", 2.2)):
			e["whistled"] = true
			AudioDirector.play_3d("a1_bomb_whistle", (e["pos"] as Vector3) + Vector3.UP * 12.0, 2.0)
		if e["bomb"] == null and tl <= 1.0:
			var b: MeshInstance3D = StukaPlane.instance("bomb_small")
			b.name = "FallingBomb"
			add_child(b)
			b.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), (e["pos"] as Vector3) + Vector3.UP * 55.0)
			e["bomb"] = b
		if e["bomb"] != null and is_instance_valid(e["bomb"]):
			(e["bomb"] as Node3D).global_position = (e["pos"] as Vector3) + Vector3.UP * (0.4 + 55.0 * clampf(tl, 0.0, 1.0))
		if tl <= 0.0:
			_pending.erase(e)
			if is_instance_valid(node):
				node.queue_free()
			if e["bomb"] != null and is_instance_valid(e["bomb"]):
				(e["bomb"] as Node3D).queue_free()
			_land(e["pos"])


func _land(at: Vector3) -> void:
	bombs_landed += 1
	last_impacts.append(at)
	if last_impacts.size() > 12:
		last_impacts.pop_front()
	burst_fx(get_tree(), at, float(cfg.get("radius", 6.5)), float(cfg.get("shake", 0.7)), float(cfg.get("shake_m", 30.0)), cfg.get("burst", []))
	if host:
		hurt(at)


## The bomb's damage (host): players outside within the radius, the dead within it. Returns players hurt.
func hurt(at: Vector3) -> int:
	var r: float = float(cfg.get("radius", 6.5))
	var n_hit: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d > r or absf(p.global_position.y - at.y) > 4.0:
			continue
		if is_sheltered(p.global_position):
			spared_inside += 1
			continue
		var dmg: float = bomb_damage(d, cfg)
		if p.has_explosive_immunity():
			dmg *= float(cfg.get("blastproof_mult", 0.5))
		p.take_hit(dmg, self)
		hits_outside += 1
		n_hit += 1
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		var rh: float = float(RoundManager.current_health())
		for z: Zombie in dir.active_zombies():
			if not z.is_active() or is_sheltered(z.global_position):
				continue
			var dz: float = Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length()
			if dz <= r and absf(z.global_position.y - at.y) <= 4.0:
				zombies_hit += 1
				z.take_damage(bomb_zombie_damage(dz, cfg, rh), &"torso", &"air_raid", 0, &"explosive")
	return n_hit


## T-273: `kinds` ([[dirt kind, strength, amount], ...], the raid table's "burst") names what a bomb throws up; empty:
## snow and earth, as on Map 0's yard (Totenhafen's concrete quay throws stone and a little snow).
static func burst_fx(tree: SceneTree, at: Vector3, r: float, shake: float, shake_m: float, kinds: Array = []) -> void:
	Effects.explosion(at + Vector3.UP * 0.3, r * 0.85)
	if kinds.is_empty():
		kinds = [["snow", 3.0, 40], ["earth", 2.4, 26]]
	for k: Variant in kinds:
		var row: Array = k
		Effects.dirt_burst(at, str(row[0]), float(row[1]), Vector3.UP, int(row[2]))
	BossFx.burst("smoke", at + Vector3.UP * 1.0, tree, 2.2, 2.6)
	BossFx.burst("sparks", at + Vector3.UP * 0.5, tree, 1.4, 1.5)
	BossFx.burst("embers", at + Vector3.UP * 0.8, tree, 1.4, 1.5)
	AudioDirector.play_3d("explosion_large", at + Vector3.UP, 6.0)
	ShermanEvent.shake_players(tree, at, shake, shake_m)


## Bots: where a bot outside should go now (the nearest shelter point), or INF when it may do as it likes.
func shelter_for(p: Player) -> Vector3:
	if phase != Phase.WARN and phase != Phase.BOMBING:
		return Vector3.INF
	if p == null or is_sheltered(p.global_position):
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for a: Variant in map_cfg.get("shelter_points", []):
		var v: Array = a
		var q: Vector3 = Vector3(float(v[0]), float(v[1]), float(v[2]))
		var d: float = q.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = q
	return best


## The live markers (bots: danger discs).
func pending_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e: Dictionary in _pending:
		out.append(e["pos"])
	return out


func active() -> bool:
	return phase == Phase.WARN or phase == Phase.BOMBING
