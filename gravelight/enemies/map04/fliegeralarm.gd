class_name Fliegeralarm
extends Node3D
## Map 4 Act I's special round, "FLIEGERALARM" (UPDATE 07, docs/MAP4_FERNFLUG.md §3.8): an Allied night raid in
## place of the Bellringer round. While the special round runs, every `interval_seconds` a searchlight-marked
## impact circle lights in a zone the players are in or next to (data: map04a.json "fliegeralarm"), holds for
## `telegraph_seconds`, then a bomb lands: everyone inside `radius` takes `damage` (zombies `zombie_damage`, so
## a well-read circle clears a loop), and `landers_per_circle` Fallschirm-Gänger (burnt aircrew, jog tier) rise
## on the circle's edge instead of coming through the windows. The round's zombie count is the usual one; the
## landers draw from it. The director's `special_handler` hook calls `tick_special(delta)` (ZombieDirector).
## The last circle is where the Resupply drops when the round is cleared (`director._last_bell_pos`).
## Pure rules are static for the tests (`pick_circle`, `in_blast`).

var director: ZombieDirector = null
var cfg: Dictionary = {}
var _t: float = 0.0
var _started: bool = false
var _pending: Array = []   # [{pos, t_left, ring: Node3D}]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var circles_fired: int = 0


func _ready() -> void:
	name = "Fliegeralarm"
	_rng.randomize()
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	(func() -> void:
		cfg = _load_cfg()
		for n: Node in get_tree().get_nodes_in_group(&"director"):
			director = n as ZombieDirector
		if director != null and _applies():
			director.special_handler = self).call_deferred()


func _load_cfg() -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0)
	if not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path).get("fliegeralarm", {})


func _applies() -> bool:
	return not cfg.is_empty() and str(RoundManager.act_block_of(GameState.map_id).get("special_kind", "")) == "fliegeralarm"


## The circles the raid may use: those in zones that are open and that a living player is in or next to.
static func pick_circle(circles: Dictionary, open_zones: Array, player_zones: Array, adjacency: Dictionary, roll: float) -> Vector3:
	var pool: Array[Vector3] = []
	for zone: String in circles.keys():
		if not open_zones.has(zone):
			continue
		var near: bool = player_zones.has(zone)
		if not near:
			for pz: String in player_zones:
				if (adjacency.get(pz, []) as Array).has(zone):
					near = true
		if not near:
			continue
		for c: Array in circles[zone]:
			pool.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	if pool.is_empty():
		return Vector3.INF
	return pool[clampi(int(floor(roll * pool.size())), 0, pool.size() - 1)]


## True when `p` is inside the blast of a circle at `c` (flat distance, within 2.5 m of its height).
static func in_blast(c: Vector3, p: Vector3, radius: float) -> bool:
	return Vector2(p.x - c.x, p.z - c.z).length() <= radius and absf(p.y - c.y) <= 2.5


func _on_round_started(_r: int, special: bool) -> void:
	if not special or not _applies() or director == null:
		return
	_started = true
	_t = 1.5
	circles_fired = 0
	if str(cfg.get("vo_start", "")) != "":
		GLVO.play(StringName(str(cfg["vo_start"])))
	var map: Node = get_parent()
	while map != null and not (map is MapRoot):
		map = map.get_parent()
	if map != null and (map as MapRoot).hud != null:
		(map as MapRoot).hud.show_banner(str(cfg.get("banner", "FLIEGERALARM")), 3.0)


func _on_round_ended(_r: int) -> void:
	if _started and str(cfg.get("vo_end", "")) != "":
		GLVO.play(StringName(str(cfg["vo_end"])))
	_started = false
	for e: Dictionary in _pending:
		if is_instance_valid(e["ring"]):
			(e["ring"] as Node).queue_free()
	_pending.clear()


## Called by the director instead of its Bellringer packs while the special round runs.
func tick_special(delta: float) -> void:
	if not _started:
		return
	for e: Dictionary in _pending.duplicate():
		e["t_left"] = float(e["t_left"]) - delta
		if float(e["t_left"]) <= 0.0:
			_pending.erase(e)
			_impact(e["pos"], e["ring"])
	_t -= delta
	if _t > 0.0 or not RoundManager.can_spawn():
		return
	_t = float(cfg.get("interval_seconds", 7.0))
	var open: Array = []
	for z: String in (cfg.get("circles", {}) as Dictionary).keys():
		if GameState.is_zone_open(StringName(z)):
			open.append(z)
	var pz: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			pz.append(String(ZoneVolume.zone_at(get_tree(), p.global_position)))
	var adj: Dictionary = {}
	for k: Variant in director.adjacency.keys():
		adj[String(k)] = director.adjacency[k]
	var at: Vector3 = pick_circle(cfg.get("circles", {}), open, pz, adj, _rng.randf())
	if at == Vector3.INF:
		return
	_telegraph(at)


func _telegraph(at: Vector3) -> void:
	var ring: Node3D = Node3D.new()
	ring.name = "ImpactCircle"
	add_child(ring)
	ring.global_position = at
	var r: float = float(cfg.get("radius", 3.0))
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.06
	disc.mesh = cm
	disc.position.y = 0.05
	disc.material_override = Mats.get_mat("lumi_paint")
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(disc)
	var light: OmniLight3D = OmniLight3D.new()
	light.position.y = 2.0
	light.light_color = Color(0.85, 0.9, 1.0)
	light.light_energy = 3.0
	light.omni_range = r * 3.0
	light.shadow_enabled = false
	ring.add_child(light)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.position = Vector3(0, 30, 0)
	spot.rotation.x = -PI * 0.5
	spot.light_color = Color(0.85, 0.9, 1.0)
	spot.light_energy = 6.0
	spot.spot_range = 36.0
	spot.spot_angle = 8.0
	spot.light_volumetric_fog_energy = 2.0
	spot.shadow_enabled = false
	ring.add_child(spot)
	AudioDirector.play_3d("siren" if AudioDirector.has_method("has_key") and AudioDirector.has_key("siren") else "door_open", at + Vector3.UP * 2.0, 2.0, 0.0)
	_pending.append({"pos": at, "t_left": float(cfg.get("telegraph_seconds", 4.0)), "ring": ring})


func _impact(at: Vector3, ring: Node) -> void:
	circles_fired += 1
	var r: float = float(cfg.get("radius", 3.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and in_blast(at, p.global_position, r):
			p.take_hit(float(cfg.get("damage", 60)), self)
	if director != null:
		for z: Zombie in director.active_zombies():
			if in_blast(at, z.global_position, r) and z.is_active():
				z.take_damage(float(cfg.get("zombie_damage", 2000)), &"torso", &"fliegeralarm", 0, &"explosive")
		director._last_bell_pos = at
	AudioDirector.play_3d("board_slam", at + Vector3.UP, 8.0, 0.8)
	for pn: Node in get_tree().get_nodes_in_group(&"players"):
		if (pn as Node3D).global_position.distance_to(at) < 25.0:
			pn.set("_shake", 0.6)
	if is_instance_valid(ring):
		ring.queue_free()
	# the landers rise on the circle's edge
	if director == null:
		return
	var n_land: int = int(cfg.get("landers_per_circle", 3))
	for i: int in n_land:
		if not RoundManager.can_spawn():
			break
		var a: float = TAU * float(i) / float(n_land) + _rng.randf() * 0.5
		var pos: Vector3 = at + Vector3(cos(a), 0, sin(a)) * (r + 0.8)
		var spec: Dictionary = director._spec_for(&"ganger", RoundManager.take_spawn())
		spec["variant"] = str(cfg.get("lander_kit", "soldier"))
		if not (GLData.table("anim")["kits"] as Dictionary).has(spec["variant"]):
			spec["variant"] = "soldier"
		spec["tier"] = StringName(str(cfg.get("lander_tier", "jog")))
		if director._activate_at(spec, director._snap(pos)) == null:
			RoundManager.requeue()
