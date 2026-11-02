class_name ThalbachRaid
extends Node3D
## Werk Thalbach's air raid (UPDATE 10 §3 Act I, contract C6 `air_raid`, DECISIONS T-155; data map04a.json "raid").
## At act round `round` (8) the works' sirens wind up, the two flak towers on the skyline open up, the searchlights
## go frantic, and a stick of bombs walks across the town on a telegraphed line (a lit ring `telegraph` s before
## each impact: dust, shake, `player_damage` to anyone inside `radius`, zombies die). The last bombs hit Assembly
## Hall 2: the works' PA gives a `warning_seconds` (10 s) warning, the hall's roof creaks and sheds dust, `push_lead`
## s before the fall a shockwave pushes every player out of `collapse_box` (nobody is ever under it when it comes
## down: a player still inside at the fall is moved to the nearest edge), and the roof bay `Hall2Roof` falls.
## The permanent change ("the route swap", one event, replicated as one `Net.mirror`):
##   - `Door_E_south`: the route from Montage 2 into the test stands through Door_Pruefstand (-30, 110) is buried
##     under the RubbleBlock (a collider on the world layer); the navmesh swaps `Nav_E_MONTAGE_4` (the hall as
##     built) for `Nav_E_MONTAGE_raid` (baked by the generator with the rubble in it) and disables that door's link.
##   - `Breach_E_apron`: the blast holes the hall's north wall at x -55 into the test stands' west aisle (the run-up
##     to the hangar apron): the wall plug's collider goes, the breach door (a Prüfstand door, link group
##     "pruefstand": already open if the stands are, else buyable at the same 1500) shows, and the link
##     `Link_Breach_E_apron` is enabled.
## After the raid fires burn where the roof fell and where bombs landed: damage zones whose heat fades over
## `fade_rounds` act rounds (players `player_dps`, zombies `zombie_dps` at full heat), smoke drifting on the wind.
## Host-authoritative: the host runs the clock, damage and the swap; clients run the show (start_raid mirrored) and
## receive the swap as `_net_collapse`. A match that starts past the raid round (a dev skip) starts collapsed.
## Pure rules are static (tests: test_thalbach_raid.gd). Flags: a1_raid_running, a1_raid_warning, a1_hall2_down.

signal collapsed

enum Phase { IDLE, RUNNING, DONE }

var cfg: Dictionary = {}
var phase: int = Phase.IDLE
var t: float = 0.0
var raid_match_round: int = -1
var is_collapsed: bool = false
## Act round the raid happened on (fires fade from it); -1 until it has.
var raid_act_round: int = -1
var bombs_dropped: int = 0
var players_pushed: int = 0
var players_moved: int = 0
var zombies_crushed: int = 0

var _pending: Array = []        # {pos, t_at, ring, roof}
var _bomb_i: int = 0
var _warned: bool = false
var _pushed: bool = false
var _fires: Array = []          # {pos, root, light, flames, base_energy}
var _fire_tick: float = 0.0
var _last_heat: float = -1.0
var _flak_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rubble_body: StaticBody3D
var _hall2: Node3D
var _creak_t: float = 0.0
var _beacon: OmniLight3D
var _parked: Dictionary = {}    # node path -> a NavigationRegion3D taken out of the map


static func load_cfg() -> Dictionary:
	return (GLData.load_json("res://data/gravelight/map04a.json") as Dictionary).get("raid", {})


## Pure: is the raid due on this act round (and not done yet)?
static func due(act_round: int, raid_round: int, done: bool) -> bool:
	return not done and act_round == raid_round


## Pure: should a match that starts on `act_round` begin with the hall already down (skipped past the raid)?
static func starts_collapsed(act_round: int, raid_round: int) -> bool:
	return act_round > raid_round


## Pure: inside an axis-aligned box in plan (y generous: a player on a jig deck still counts).
static func in_box(p: Vector3, lo: Vector3, hi: Vector3) -> bool:
	return p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z and p.y >= lo.y - 1.0 and p.y <= hi.y + 1.0


## Pure: the way out of the collapse box for someone at `p`: across the short side to the nearer long edge
## (the box is a roof bay across the hall: out along x), never into the wall behind it.
static func push_dir(p: Vector3, lo: Vector3, hi: Vector3) -> Vector3:
	var cx: float = (lo.x + hi.x) * 0.5
	return Vector3(-1.0 if p.x < cx else 1.0, 0.0, 0.0)


## Pure: the nearest point just outside the box along x (the fail-safe move for anyone still inside at the fall).
static func safe_point(p: Vector3, lo: Vector3, hi: Vector3, margin: float = 1.2) -> Vector3:
	var d: Vector3 = push_dir(p, lo, hi)
	return Vector3(lo.x - margin if d.x < 0.0 else hi.x + margin, p.y, p.z)


## Pure: the seconds after the raid starts at which bomb `i` lands.
static func bomb_time(i: int, start: float, gap: float) -> float:
	return start + float(i) * gap


## Pure: a fire's heat (1 at the raid's round, falling linearly to 0 after `fade_rounds` more act rounds).
static func fire_heat(act_round_now: int, raid_round: int, fade_rounds: int) -> float:
	if raid_round < 0 or act_round_now < raid_round:
		return 0.0
	return clampf(1.0 - float(act_round_now - raid_round) / float(maxi(1, fade_rounds)), 0.0, 1.0)


## Pure: the navmesh nodes' enabled state for the route (before the fall / after): {node path: enabled}.
static func route_state(route: Dictionary, down: bool) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in route.get("nodes_off", []):
		out[str(p)] = not down
	for p2: Variant in route.get("nodes_on", []):
		out[str(p2)] = down
	return out


static func v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _ready() -> void:
	name = "AirRaid"
	add_to_group(&"a1_raid")
	add_to_group(&"traps")   # the bots' keep-out (danger_contains): the bay while it is coming down, the fires
	_rng.seed = 1945_08
	cfg = load_cfg()
	if cfg.is_empty():
		return
	GLBus.round_started.connect(_on_round_started)
	GLBus.flag_changed.connect(_on_flag_changed)
	_build_rubble()
	(func() -> void:
		_hall2 = _map_root().find_child(str(cfg.get("collapse", "Hall2Roof")), true, false) as Node3D
		_apply_route(false)
		_seal_breach(true)).call_deferred()


## Online (contract C8): a peer that joins after the fall gets the host's flags in its first state snapshot; the hall
## comes down for it at once (no show), the fires light at the host's heat.
func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if flag == &"a1_hall2_down" and bool(value) and not is_collapsed and not Net.is_authority():
		if raid_act_round < 0:
			raid_act_round = RoundManager.act_round() if RoundManager.has_act() else int(cfg.get("round", 8))
		phase = Phase.DONE
		_collapse(true)
		_light_fires()


func _map_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and not (n is MapRoot):
		n = n.get_parent()
	return n


func _on_round_started(_r: int, _special: bool) -> void:
	if not RoundManager.has_act():
		return
	var ar: int = RoundManager.act_round()
	var rr: int = int(cfg.get("round", 8))
	if not is_collapsed and starts_collapsed(ar, rr) and phase == Phase.IDLE:
		# a match that begins past the raid (a skip): the hall is already down, no show
		raid_act_round = rr
		phase = Phase.DONE
		_collapse(true)
		_light_fires()
		return
	if Net.is_authority() and phase == Phase.IDLE and due(ar, rr, is_collapsed):
		phase = Phase.RUNNING
		t = -float(cfg.get("start_delay", 10.0))
		raid_act_round = ar
		print("[raid] act round %d: the raid is coming in %.0f s" % [ar, -t])
	_update_fire_heat()


## Starts the show now (the host's clock reached zero; also the dev console, the launcher button and the smoke).
func start_raid() -> void:
	if phase == Phase.DONE and is_collapsed:
		return
	phase = Phase.RUNNING
	t = 0.0
	_bomb_i = 0
	_warned = false
	_pushed = false
	_flak_t = 0.0
	if raid_act_round < 0:
		raid_act_round = RoundManager.act_round() if RoundManager.has_act() else int(cfg.get("round", 8))
	GameState.set_flag(&"a1_raid_running")
	for s: Variant in cfg.get("sirens", []):
		AudioDirector.play_3d(_snd("siren"), v3(s), 6.0, 0.0)
	_sky_alarm(true)
	_banner(str(cfg.get("banner", "FLIEGERALARM")), 3.0)
	_line(str((cfg.get("lines", {}) as Dictionary).get("start", "")))
	print("[raid] sirens: the raid has begun")
	if Net.is_authority():
		Net.mirror(self, &"_net_start")


func _net_start() -> void:
	if Net.is_authority():
		return
	start_raid()


func _physics_process(delta: float) -> void:
	if phase != Phase.RUNNING:
		_tick_fires(delta)
		return
	if t < 0.0:
		t += delta
		if t >= 0.0:
			if Net.is_authority():
				start_raid()
		return
	t += delta
	_tick_flak(delta)
	var bw: Dictionary = cfg.get("bomb_walk", {})
	var pts: Array = bw.get("points", [])
	var tele: float = float(bw.get("telegraph", 1.3))
	# telegraph each bomb `tele` seconds before it lands
	while _bomb_i < pts.size() and t >= bomb_time(_bomb_i, float(bw.get("start", 4.0)), float(bw.get("gap", 1.15))) - tele:
		var at: Vector3 = v3(pts[_bomb_i])
		var land_t: float = bomb_time(_bomb_i, float(bw.get("start", 4.0)), float(bw.get("gap", 1.15)))
		_pending.append({"pos": at, "t_at": land_t, "ring": _ring(at, float(bw.get("radius", 3.2))), "roof": at.y > 2.0})
		AudioDirector.play_3d(_snd("bomb_whistle"), at + Vector3.UP * 14.0, 2.0, 0.08)
		_bomb_i += 1
	for i: int in range(_pending.size() - 1, -1, -1):
		var b: Dictionary = _pending[i]
		if t >= float(b["t_at"]):
			_pending.remove_at(i)
			_impact(b)
	var warn_at: float = float(cfg.get("warning_at", 8.0))
	var warn_s: float = float(cfg.get("warning_seconds", 10.0))
	var fall_at: float = warn_at + warn_s
	if not _warned and t >= warn_at:
		_warned = true
		_start_warning()
	if _warned and not is_collapsed:
		_tick_warning(delta, fall_at - t)
	if not _pushed and t >= fall_at - float(cfg.get("push_lead", 1.5)):
		_pushed = true
		if Net.is_authority():
			_shockwave()
	if not is_collapsed and t >= fall_at and Net.is_authority():
		_fall()
	if is_collapsed and t >= float(cfg.get("all_clear_at", 45.0)):
		phase = Phase.DONE
		GameState.set_flag(&"a1_raid_running", false)
		_sky_alarm(false)
		_line(str((cfg.get("lines", {}) as Dictionary).get("all_clear", "")))
		print("[raid] all clear")
	_tick_fires(delta)


# ------------------------------------------------------------------ the bomb walk

func _ring(at: Vector3, r: float) -> Node3D:
	var ring: Node3D = Node3D.new()
	ring.name = "BombRing"
	add_child(ring)
	ring.global_position = at
	if at.y > 2.0:
		return ring   # roof hits: no ring on the floor (the warning covers the hall)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.05
	disc.mesh = cm
	disc.position.y = 0.04
	disc.material_override = Mats.get_mat("lumi_paint")
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(disc)
	var l: OmniLight3D = OmniLight3D.new()
	l.position.y = 2.0
	l.light_color = Color(1.0, 0.55, 0.35)
	l.light_energy = 2.4
	l.omni_range = r * 2.6
	l.shadow_enabled = false
	ring.add_child(l)
	return ring


func _impact(b: Dictionary) -> void:
	var at: Vector3 = b["pos"]
	var bw: Dictionary = cfg.get("bomb_walk", {})
	var r: float = float(bw.get("radius", 3.2))
	bombs_dropped += 1
	if is_instance_valid(b["ring"]):
		(b["ring"] as Node).queue_free()
	Effects.explosion(at + Vector3.UP * 0.3, r)
	Effects.dirt_burst(at + Vector3.UP * 0.2, "earth" if not bool(b["roof"]) else "stone", 2.0, Vector3.UP, 26)
	AudioDirector.play_3d("explosion_large", at + Vector3.UP, 6.0, 0.12)
	_shake_near(at, float(bw.get("shake", 0.5)), 32.0)
	GLBus.explosion.emit(at, r)
	if bool(b["roof"]) or not Net.is_authority():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and p.global_position.distance_to(at) <= r:
			p.take_hit(float(bw.get("player_damage", 30)), self)
	for z: Zombie in _zombies():
		if z.is_active() and z.global_position.distance_to(at) <= r:
			z.take_damage(float(bw.get("zombie_damage", 2000)), &"torso", &"air_raid", 0, &"explosive")


func _zombies() -> Array:
	var out: Array = []
	for d: Node in get_tree().get_nodes_in_group(&"director"):
		var dir: ZombieDirector = d as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z != null and is_instance_valid(z):
					out.append(z)
	return out


func _shake_near(at: Vector3, amount: float, within: float) -> void:
	for pn: Node in get_tree().get_nodes_in_group(&"players"):
		var d: float = (pn as Node3D).global_position.distance_to(at)
		if d < within:
			pn.set("_shake", amount * (1.0 - d / within * 0.6))


# ------------------------------------------------------------------ the flak towers and the sky

func _tick_flak(delta: float) -> void:
	if t > float(cfg.get("flak_seconds", 40.0)):
		return
	_flak_t -= delta
	if _flak_t > 0.0:
		return
	_flak_t = _rng.randf_range(0.25, 0.7)
	var towers: Array = cfg.get("flak_towers", [])
	if towers.is_empty():
		return
	var top: Vector3 = v3(towers[_rng.randi() % towers.size()])
	# a muzzle flash on the tower and a burst high over the works a moment later
	_flash(top, Color(1.0, 0.75, 0.45), 6.0, 0.12, 30.0)
	var burst: Vector3 = Vector3(_rng.randf_range(-60.0, 50.0), _rng.randf_range(70.0, 105.0), _rng.randf_range(10.0, 190.0))
	get_tree().create_timer(_rng.randf_range(0.6, 1.1)).timeout.connect(func() -> void:
		if is_inside_tree():
			_flash(burst, Color(1.0, 0.82, 0.55), 18.0, 0.25, 70.0))
	AudioDirector.play_3d("kranich_flak", top, 0.0, 0.1)


func _flash(at: Vector3, col: Color, energy: float, life: float, rng_m: float) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	add_child(l)
	l.global_position = at
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


func _sky_alarm(on: bool) -> void:
	for s: Node in get_tree().get_nodes_in_group(&"thalbach_sky"):
		if s.has_method("set_alarm"):
			s.call("set_alarm", on)


# ------------------------------------------------------------------ hall 2: the warning, the shockwave, the fall

func _start_warning() -> void:
	GameState.set_flag(&"a1_raid_warning")
	_banner(str(cfg.get("warning_banner", "MONTAGE 2: THE ROOF IS GOING")), float(cfg.get("warning_seconds", 10.0)) * 0.5)
	_line(str((cfg.get("lines", {}) as Dictionary).get("warning", "")))
	var lo: Vector3 = v3((cfg.get("collapse_box", [[0, 0, 0], [0, 0, 0]]) as Array)[0])
	var hi: Vector3 = v3((cfg.get("collapse_box", [[0, 0, 0], [0, 0, 0]]) as Array)[1])
	_beacon = OmniLight3D.new()
	_beacon.name = "CollapseBeacon"
	_beacon.light_color = Color(1.0, 0.2, 0.1)
	_beacon.light_energy = 0.0
	_beacon.omni_range = maxf(hi.x - lo.x, hi.z - lo.z) * 0.8
	_beacon.shadow_enabled = false
	add_child(_beacon)
	_beacon.global_position = (lo + hi) * 0.5 + Vector3(0, 6.0, 0)
	AudioDirector.play_3d("kranich_creak", _beacon.global_position, 6.0, 0.0)


func _tick_warning(delta: float, left: float) -> void:
	if _beacon != null:
		_beacon.light_energy = 2.2 * (0.5 + 0.5 * sin(t * 9.0))
	_creak_t -= delta
	if _creak_t > 0.0:
		return
	_creak_t = clampf(left * 0.25, 0.35, 1.6)
	var lo: Vector3 = v3((cfg.get("collapse_box", [[0, 0, 0], [0, 0, 0]]) as Array)[0])
	var hi: Vector3 = v3((cfg.get("collapse_box", [[0, 0, 0], [0, 0, 0]]) as Array)[1])
	var p: Vector3 = Vector3(_rng.randf_range(lo.x, hi.x), 8.6, _rng.randf_range(lo.z, hi.z))
	Effects.dust_puff(p, "stone", 8)
	AudioDirector.play_3d("amb_m4c_metal_creak" if _rng.randf() < 0.5 else "kranich_creak", p, 3.0, 0.1)
	if _hall2 != null:
		_hall2.position = Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.05, 0.0), _rng.randf_range(-0.04, 0.04))


## Host: every player inside the collapse box is thrown out of it (and the bots with them).
func _shockwave() -> void:
	var box: Array = cfg.get("collapse_box", [])
	if box.size() < 2:
		return
	var lo: Vector3 = v3(box[0])
	var hi: Vector3 = v3(box[1])
	var mps: float = float(cfg.get("push_mps", 12.0))
	var secs: float = float(cfg.get("push_seconds", 0.8))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and in_box(p.global_position, lo, hi):
			p.external_push(push_dir(p.global_position, lo, hi) * mps, secs)
			p.set("_shake", 0.8)
			players_pushed += 1
	Effects.explosion((lo + hi) * 0.5 + Vector3(0, 7.0, 0), 4.0)
	AudioDirector.play_3d("explosion_large", (lo + hi) * 0.5 + Vector3(0, 7.0, 0), 8.0, 0.0)


## Host: the roof bay comes down now.
func _fall() -> void:
	var box: Array = cfg.get("collapse_box", [])
	if box.size() >= 2:
		var lo: Vector3 = v3(box[0])
		var hi: Vector3 = v3(box[1])
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and in_box(p.global_position, lo, hi):
				# fair by construction: nobody is ever under it
				p.global_position = safe_point(p.global_position, lo, hi)
				p.velocity = Vector3.ZERO
				players_moved += 1
		for z: Zombie in _zombies():
			if z.is_active() and in_box(z.global_position, lo, hi):
				z.take_damage(999999.0, &"torso", &"air_raid", 0, &"explosive")
				zombies_crushed += 1
	_collapse(false)
	_light_fires()
	Net.mirror(self, &"_net_collapse")
	print("[raid] Hall 2's roof is down: pushed %d, moved %d, crushed %d" % [players_pushed, players_moved, zombies_crushed])


func _net_collapse() -> void:
	if is_collapsed:
		return
	_collapse(false)
	_light_fires()


## The permanent change (both peers): the roof bay falls (or is simply gone when `instant`), the rubble and its
## collider, the breach, the navmesh swap.
func _collapse(instant: bool) -> void:
	if is_collapsed:
		return
	is_collapsed = true
	GameState.set_flag(&"a1_raid_warning", false)
	GameState.set_flag(&"a1_hall2_down")
	if _beacon != null:
		_beacon.queue_free()
		_beacon = null
	if _hall2 != null:
		if instant:
			_hall2.hide()
		else:
			_hall2.position = Vector3.ZERO
			var tw: Tween = _hall2.create_tween()
			tw.tween_property(_hall2, "position:y", -8.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_hall2, "rotation:z", deg_to_rad(4.0), 0.9)
			tw.tween_callback(_hall2.hide)
	_rubble_body.collision_layer = 1
	(_rubble_body.get_node("Heap") as Node3D).visible = true
	var deb: Node3D = get_node_or_null("FloorDebris") as Node3D
	if deb != null:
		deb.visible = true
	if not instant:
		var heap: Node3D = _rubble_body.get_node("Heap") as Node3D
		heap.scale = Vector3(1, 0.05, 1)
		var tw2: Tween = heap.create_tween()
		tw2.tween_interval(0.7)
		tw2.tween_property(heap, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var c: Vector3 = _rubble_body.global_position
		Effects.explosion(c + Vector3.UP, 5.0)
		for k: int in 6:
			Effects.dirt_burst(c + Vector3(_rng.randf_range(-6, 6), 0.5, _rng.randf_range(-3, 3)), "stone", 3.0, Vector3.UP, 30)
		AudioDirector.play_3d(_snd("collapse"), c + Vector3.UP * 3.0, 10.0, 0.0)
		_shake_near(c, 1.0, 45.0)
		_banner(str(cfg.get("collapse_banner", "THE ROOF IS DOWN · A WAY THROUGH TO THE APRON")), 3.0)
		_line(str((cfg.get("lines", {}) as Dictionary).get("collapse", "")))
		var cat: String = str((cfg.get("lines", {}) as Dictionary).get("squad", ""))
		if cat != "":
			get_tree().create_timer(5.5).timeout.connect(func() -> void: GLVO.squad_say(cat, 1.0))
	_seal_breach(false)
	_apply_route(true)
	_dust_cloud()
	collapsed.emit()


## Regions are taken out of the navigation map, not just disabled: a disabled region still owns its polygons for
## the map's link attachment (the door links would stay glued to the old Montage and the new one would be an
## island), so an "off" region is parked (removed from the tree, kept here) and an "on" one is put back.
func _apply_route(down: bool) -> void:
	var root: Node = _map_root()
	var st: Dictionary = route_state(cfg.get("route", {}), down)
	for path: String in st.keys():
		var n: Node = _route_node(root, path)
		var on: bool = bool(st[path])
		if n is NavigationRegion3D:
			var r: NavigationRegion3D = n as NavigationRegion3D
			if on:
				if not r.is_inside_tree():
					var holder: Node = root.get_node_or_null(NodePath(path.get_base_dir()))
					if holder != null:
						holder.add_child(r)
				r.enabled = true
			elif r.is_inside_tree():
				_parked[path] = r
				r.get_parent().remove_child(r)
		elif n is NavigationLink3D:
			(n as NavigationLink3D).enabled = on
		elif n == null and down:
			push_warning("[raid] navmesh node %s not found" % path)


func _route_node(root: Node, path: String) -> Node:
	var n: Node = root.get_node_or_null(NodePath(path))
	if n == null and _parked.has(path):
		n = _parked[path]
	return n


## True when a route node is live: a region in the map and enabled, a link enabled (the smoke and the bots worker).
func route_node_on(path: String) -> bool:
	var n: Node = _route_node(_map_root(), path)
	if n is NavigationRegion3D:
		return n.is_inside_tree() and (n as NavigationRegion3D).enabled
	if n is NavigationLink3D:
		return (n as NavigationLink3D).enabled
	return false


func _exit_tree() -> void:
	for k: Variant in _parked.keys():
		var r: Node = _parked[k]
		if is_instance_valid(r) and not r.is_inside_tree():
			r.free()
	_parked.clear()


## The breach (the wall plug and the breach door): sealed until the fall.
func _seal_breach(sealed: bool) -> void:
	var root: Node = _map_root()
	var br: Dictionary = cfg.get("breach", {})
	var plug: CollisionObject3D = root.find_child(str(br.get("plug", "BreachPlug")), true, false) as CollisionObject3D
	if plug != null:
		plug.collision_layer = 1 if sealed else 0
	var patch: Node3D = get_node_or_null("BreachPatch") as Node3D
	if patch == null and sealed:
		patch = _breach_patch(br)
	if patch != null:
		patch.visible = sealed
	var hole: Node3D = get_node_or_null("BreachHole") as Node3D
	if hole == null and not sealed:
		hole = _breach_hole(br)
	if hole != null:
		hole.visible = not sealed
	var door: Node = root.find_child(str(br.get("id", "Breach_E_apron")), true, false)
	if door != null and door.has_method("set_sealed"):
		door.call("set_sealed", sealed)


func _breach_patch(br: Dictionary) -> Node3D:
	var at: Vector3 = v3(br.get("pos", [-55, 0, 110]))
	var w: float = float(br.get("width", 3.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "BreachPatch"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(w, 2.4, 0.3)
	mi.mesh = bm
	mi.material_override = Mats.get_mat("fl_brick")
	add_child(mi)
	mi.global_position = at + Vector3(0, 1.2, 0)
	return mi


## The blown hole: a ragged brick frame, fallen bricks on both sides, a bent girder end.
func _breach_hole(br: Dictionary) -> Node3D:
	var at: Vector3 = v3(br.get("pos", [-55, 0, 110]))
	var w: float = float(br.get("width", 3.0))
	var g: Node3D = Node3D.new()
	g.name = "BreachHole"
	add_child(g)
	g.global_position = at
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 5510
	for side: float in [-1.0, 1.0]:
		for k: int in 5:
			var h: float = r.randf_range(0.3, 2.4)
			Props.obox(g, Vector3(side * (w * 0.5 + r.randf_range(-0.15, 0.25)), h * 0.5, r.randf_range(-0.1, 0.1)),
				Vector3(r.randf_range(0.3, 0.6), h, 0.34), "fl_brick", Vector3(0, r.randf_range(-12, 12), r.randf_range(-8, 8)))
	for k2: int in 14:
		var sz: float = r.randf_range(0.18, 0.5)
		Props.obox(g, Vector3(r.randf_range(-w * 0.7, w * 0.7), sz * 0.3, r.randf_range(-2.4, 2.4)), Vector3(sz * 1.4, sz * 0.6, sz),
			"fl_brick", Vector3(r.randf_range(-20, 20), r.randf_range(0, 180), r.randf_range(-20, 20)))
	Props.obox(g, Vector3(0.6, 2.6, 0.0), Vector3(w + 1.2, 0.3, 0.22), "rust", Vector3(0, 0, -9))
	# the hall's wall lamp, torn loose and still burning on its cable, swinging in the hole
	Props.cable(g, Vector3(-0.8, 2.5, 0.0), Vector3(-0.4, 1.7, 0.4), 0.05, 0.015, 3, "rubber")
	Props.cyl(g, Vector3(-0.4, 1.6, 0.4), 0.16, 0.22, "enamel_green", Vector3(30, 0, 0))
	var bl: OmniLight3D = OmniLight3D.new()
	bl.light_color = Color(1.0, 0.78, 0.5)
	bl.light_energy = 1.6
	bl.omni_range = 10.0
	bl.shadow_enabled = false
	bl.position = Vector3(-0.4, 1.45, 0.5)
	g.add_child(bl)
	# soot round the hole on both faces
	for fz: float in [-0.17, 0.17]:
		for sx: float in [-1.0, 1.0]:
			Props.obox(g, Vector3(sx * (w * 0.5 + 0.45), 1.4, fz), Vector3(0.9, 2.8, 0.01), "char")
		Props.obox(g, Vector3(0, 2.75, fz), Vector3(w + 1.8, 0.7, 0.01), "char")
	for c: Node in g.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(g)
	return g


func _build_rubble() -> void:
	var rb: Array = cfg.get("rubble_box", [])
	if rb.size() < 2:
		return
	var lo: Vector3 = v3(rb[0])
	var hi: Vector3 = v3(rb[1])
	_rubble_body = StaticBody3D.new()
	_rubble_body.name = "RubbleBlock"
	_rubble_body.collision_layer = 0
	_rubble_body.collision_mask = 0
	_rubble_body.add_to_group(&"a1_rubble")
	add_child(_rubble_body)
	_rubble_body.global_position = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = hi - lo
	cs.shape = bs
	cs.position = Vector3(0, (hi.y - lo.y) * 0.5, 0)
	_rubble_body.add_child(cs)
	# the heap: broken roof sheets, purlins and a truss, bricks, glass from the north lights, a heap of corrugated iron
	var heap: Node3D = Node3D.new()
	heap.name = "Heap"
	heap.visible = false
	_rubble_body.add_child(heap)
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 1208
	var sx: float = (hi.x - lo.x) * 0.5
	var sz2: float = (hi.z - lo.z) * 0.5
	var top: float = hi.y - lo.y
	Props.obox(heap, Vector3(0, top * 0.35, 0), Vector3(sx * 2.0 - 0.6, top * 0.7, sz2 * 2.0 - 0.6), "fl_concrete", Vector3(0, 0, 0))
	for k: int in 16:
		var p: Vector3 = Vector3(r.randf_range(-sx, sx), r.randf_range(0.4, top), r.randf_range(-sz2, sz2))
		Props.obox(heap, p, Vector3(r.randf_range(2.0, 5.0), 0.06, r.randf_range(1.2, 2.6)), "fl_corrugated",
			Vector3(r.randf_range(-35, 35), r.randf_range(0, 180), r.randf_range(-35, 35)))
	for k2: int in 5:
		var a: Vector3 = Vector3(r.randf_range(-sx, sx), r.randf_range(0.2, top + 0.6), r.randf_range(-sz2, sz2))
		Props.strut(heap, a, a + Vector3(r.randf_range(-5, 5), r.randf_range(-1.5, 2.5), r.randf_range(-2, 2)), 0.16, "steel")
	for k3: int in 20:
		var s: float = r.randf_range(0.2, 0.55)
		Props.obox(heap, Vector3(r.randf_range(-sx - 0.6, sx + 0.6), s * 0.3, r.randf_range(-sz2 - 0.8, sz2 + 0.3)), Vector3(s * 1.5, s * 0.6, s),
			"fl_brick", Vector3(r.randf_range(-25, 25), r.randf_range(0, 180), r.randf_range(-25, 25)))
	for k4: int in 8:
		Props.obox(heap, Vector3(r.randf_range(-sx, sx), r.randf_range(0.1, top * 0.8), r.randf_range(-sz2, sz2)), Vector3(r.randf_range(0.5, 1.4), 0.02, r.randf_range(0.4, 1.0)),
			"glass", Vector3(r.randf_range(-50, 50), r.randf_range(0, 180), r.randf_range(-50, 50)))
	for c: Node in heap.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(heap)
	# the rest of the fallen bay: flat sheets, purlins and glass across the hall floor (no colliders, ankle high)
	var box: Array = cfg.get("collapse_box", [])
	if box.size() < 2:
		return
	var blo: Vector3 = v3(box[0])
	var bhi: Vector3 = v3(box[1])
	var deb: Node3D = Node3D.new()
	deb.name = "FloorDebris"
	deb.visible = false
	add_child(deb)
	for k5: int in 22:
		var p2: Vector3 = Vector3(r.randf_range(blo.x + 0.5, bhi.x - 0.5), 0.0, r.randf_range(blo.z + 0.5, lo.z - 0.2))
		var key: String = ["fl_corrugated", "fl_corrugated", "steel", "glass", "fl_brick"][k5 % 5]
		var on_jig: bool = p2.x > -40.0 and p2.x < -12.0 and p2.z > 94.0 and p2.z < 102.0
		Props.obox(deb, p2 + Vector3(0, 2.55 if on_jig else 0.04, 0), Vector3(r.randf_range(1.2, 3.6), 0.05, r.randf_range(0.6, 2.0)), key,
			Vector3(r.randf_range(-6, 6), r.randf_range(0, 180), r.randf_range(-6, 6)))
	for k6: int in 4:
		var a2: Vector3 = Vector3(r.randf_range(blo.x + 1, bhi.x - 1), 0.12, r.randf_range(blo.z + 1, lo.z - 1))
		Props.strut(deb, a2, a2 + Vector3(r.randf_range(-5, 5), 0.0, r.randf_range(-1.5, 1.5)), 0.14, "steel")
	for c2: Node in deb.find_children("*", "GeometryInstance3D", true, false):
		(c2 as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(deb)


func _dust_cloud() -> void:
	var rb: Array = cfg.get("rubble_box", [])
	if rb.size() < 2 or get_node_or_null("DustCloud") != null:
		return
	var c: Vector3 = (v3(rb[0]) + v3(rb[1])) * 0.5
	var holder: Node3D = Node3D.new()
	holder.name = "DustCloud"
	add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.z)
	Props.smoke(holder, Vector3(0, 1.5, 0), 5.0, 1.4, 26)


# ------------------------------------------------------------------ the fires after

func _light_fires() -> void:
	if not _fires.is_empty():
		return
	var fc: Dictionary = cfg.get("fires", {})
	var i: int = 0
	for pv: Variant in fc.get("points", []):
		var at: Vector3 = v3(pv)
		var root: Node3D = Node3D.new()
		root.name = "RaidFire%d" % i
		root.add_to_group(&"a1_fires")
		add_child(root)
		root.global_position = at
		var fl: GPUParticles3D = Props.flames(root, Vector3.ZERO, 1.6, 1.8, 36)
		Props.embers(root, Vector3(0, 0.5, 0), 1.0, 12)
		Props.smoke(root, Vector3(0, 2.2, 0), 1.0, 1.6, 14)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.22)
		l.light_energy = 2.6
		l.omni_range = 9.0
		l.shadow_enabled = false
		l.position.y = 1.2
		l.set_meta("zone", &"")
		root.add_child(l)
		var loop: Node = AudioDirector.make_loop_3d("fire_crackle", root) if AudioDirector.has_sound("fire_crackle") else null
		_fires.append({"pos": at, "root": root, "light": l, "flames": fl, "loop": loop})
		i += 1
	_update_fire_heat()


func heat_now() -> float:
	if raid_act_round < 0:
		return 0.0
	var ar: int = RoundManager.act_round() if RoundManager.has_act() else raid_act_round
	return fire_heat(ar, raid_act_round, int((cfg.get("fires", {}) as Dictionary).get("fade_rounds", 3)))


func _update_fire_heat() -> void:
	if _fires.is_empty():
		return
	var h: float = heat_now()
	for f: Dictionary in _fires:
		var root: Node3D = f["root"]
		if not is_instance_valid(root):
			continue
		root.visible = h > 0.0
		(f["light"] as OmniLight3D).light_energy = 2.6 * h
		root.scale = Vector3.ONE * lerpf(0.45, 1.0, h)
		var loop: Node = f.get("loop")
		if loop != null and is_instance_valid(loop) and loop is AudioStreamPlayer3D:
			(loop as AudioStreamPlayer3D).volume_db = linear_to_db(maxf(0.001, h))
	if h <= 0.0:
		for f2: Dictionary in _fires:
			if is_instance_valid(f2["root"]):
				(f2["root"] as Node).queue_free()
		_fires.clear()
		print("[raid] the fires are out")


## Host: the fires' damage zones (every 0.5 s), scaled by the heat.
func _tick_fires(delta: float) -> void:
	if _fires.is_empty():
		return
	_fire_tick -= delta
	if _fire_tick > 0.0:
		return
	_fire_tick = 0.5
	var h: float = heat_now()
	if absf(h - _last_heat) > 0.01:
		_last_heat = h
		_update_fire_heat()
	if h <= 0.0 or not Net.is_authority():
		return
	var fc: Dictionary = cfg.get("fires", {})
	var r: float = float(fc.get("radius", 2.2)) * lerpf(0.6, 1.0, h)
	for f: Dictionary in _fires:
		var at: Vector3 = f["pos"]
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.is_alive() and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= r and absf(p.global_position.y - at.y) < 2.0:
				p.take_hit(float(fc.get("player_dps", 10)) * 0.5 * h, self)
		for z: Zombie in _zombies():
			if z.is_active() and Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length() <= r:
				z.take_damage(float(fc.get("zombie_dps", 80)) * 0.5 * h, &"torso", &"fire", 0, &"fire")


# ------------------------------------------------------------------ helpers

func _snd(key: String) -> String:
	var s: Dictionary = cfg.get("sounds", {})
	var k: String = str(s.get(key, key))
	return k if AudioDirector.has_sound(k) else str((cfg.get("sound_fallbacks", {}) as Dictionary).get(key, "explosion_large"))


func _banner(text: String, hold: float) -> void:
	if text == "":
		return
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", text, hold)


func _line(id: String) -> void:
	if id != "":
		GLVO.play(StringName(id))


## Bots keep out (BotBrain / BotLocomotion read every "traps" node's danger_contains): the roof bay from the
## warning until the fall, and every fire while it still burns.
func danger_contains(p: Vector3) -> bool:
	if _warned and not is_collapsed:
		var box: Array = cfg.get("collapse_box", [])
		if box.size() >= 2 and in_box(p, v3(box[0]) - Vector3(1, 0, 1), v3(box[1]) + Vector3(1, 0, 1)):
			return true
	if _fires.is_empty():
		return false
	var r: float = float((cfg.get("fires", {}) as Dictionary).get("radius", 2.2)) + 0.6
	for f: Dictionary in _fires:
		var at: Vector3 = f["pos"]
		if Vector2(p.x - at.x, p.z - at.z).length() <= r and absf(p.y - at.y) < 2.0:
			return true
	return false


## State for the smoke / dev overlay.
func status() -> Dictionary:
	return {"phase": phase, "t": t, "collapsed": is_collapsed, "bombs": bombs_dropped, "pushed": players_pushed, "moved": players_moved,
		"crushed": zombies_crushed, "fires": _fires.size(), "heat": heat_now()}
