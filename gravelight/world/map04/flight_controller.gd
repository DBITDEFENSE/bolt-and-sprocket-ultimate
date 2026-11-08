class_name FlightController
extends Node3D
## The Kranich's flight (UPDATE 07, docs/MAP4_FERNFLUG.md §4.5–§4.8; data map04b.json "flight" and "act.events").
## One node in the act's Gameplay group that runs what the wing does to the squad:
##   turbulence   the Bordfunk warns, then the deck banks: a lateral push on everyone, the camera rolls, zombies
##                stumble (a tool, not a punishment: Skyhook holders keep their footing)
##   strafing     Allied fighters rake a zone with three tracer lines (telegraphed by sparks); they kill zombies too
##   breaches     a panel blows on its timer or under a strafe; the BreachPanel does the suction; an open breach
##                is a climb entry
##   climbers     the Bordschützen rise at the blister rims and open breaches while the round has a queue
##   DRUCKABFALL  the act's special round: every panel in sequence, climbers instead of window spawns, a Resupply
##   the London window (act round 17), the bomb run (act round 19), the autopilot fallback (act round 20)
## The egg's steps can fire the beats earlier (start_london(), start_bomb_run()). The bomb run writes
## GameState.flags bomb_<city> = hit | saved | dud, which the endings and the Earth in the sky read.
## Pure rules are static for the tests (`strafe_line_hits`, `next_rack`, `pick_duds`, `city_flag`).

var cfg: Dictionary = {}
var events: Dictionary = {}
var director: ZombieDirector = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# turbulence
var turb_t: float = 0.0
var turb_warned: bool = false
var banking: bool = false
var bank_left: float = 0.0
var bank_side: float = 1.0
var banks_done: int = 0
var _first_turb: bool = true
var _zombie_push_t: float = 0.0
# strafing
var strafes_done: int = 0
var _last_strafe_round: int = -99
var _strafe_at: float = -1.0
var _strafe_zone: String = ""
var _strafe_lines: Array = []   # [{x, z0, z1, t_left}]
var _strafe_tick: float = 0.0
var _first_strafe: bool = true
# breaches
var breach_t: float = 0.0
var _first_breach: bool = true
# climbers
var climber_t: float = 0.0
var climbers_spawned: int = 0
# special
var _druck_on: bool = false
var _druck_next: int = 0
var _druck_t: float = 0.0
var _druck_panels: Array = []
# bomb run
var run_on: bool = false
var run_done: bool = false
var run_t: float = 0.0
var racks: Array = []     # BombRack, by rack_index
var rack_results: Dictionary = {}   # city -> "hit" | "saved" | "dud"
var _run_banks: int = 0
var _hud: CanvasLayer = null
var _hud_labels: Array = []
# the London window
var london_started: bool = false
# UPDATE 10 §3 (T-156): the tilt (turbulence_tilt), decompression and the flight clock that times them
var tilt_t: float = 0.0
var tilts_done: int = 0
var tilt_impacts: int = 0
var tilt_bomb_kills: int = 0
var tilt_times: Array[float] = []   # this round's tilt starts (seconds on the round clock), host
var round_clock: float = 0.0
var _zslide: Dictionary = {}        # zombie instance id -> {x, mps, hit}
var _push_t: float = 0.0
var decomp_queue: Array = []        # [{t, node}] this round's decompressions, host
var decomps_done: int = 0


# ---------------------------------------------------------------- pure rules

## Does a body at `p` stand in a tracer line at x = `x` between z0..z1, `width` wide?
static func strafe_line_hits(x: float, z0: float, z1: float, width: float, p: Vector3) -> bool:
	return absf(p.x - x) <= width * 0.5 and p.z >= minf(z0, z1) and p.z <= maxf(z0, z1)


## The next rack the autopilot releases: the lowest-numbered one still armed (jammed and dropped racks are decided).
static func next_rack(states: Array) -> int:
	for i: int in states.size():
		if str(states[i]) == "armed":
			return i
	return -1


## Which racks (indices 1..5 of racks 2..6) carry the chalk: `count` distinct picks from racks 2..6.
static func pick_duds(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = [1, 2, 3, 4, 5]
	var out: Array[int] = []
	while out.size() < mini(count, pool.size()):
		var i: int = rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	out.sort()
	return out


## The flag a city's fate sets (flags are booleans): bomb_<city>_<hit|saved|dud>, e.g. bomb_new_york_saved.
static func city_flag(city: String, result: String) -> StringName:
	return StringName("bomb_" + city.to_lower().replace(" ", "_") + "_" + result)


## The result a rack's end state writes: dropped → hit, jammed → saved, marked and dropped → dud.
static func result_of(state: String, marked: bool) -> String:
	if state == "jammed":
		return "saved"
	return "dud" if marked else "hit"


# ---------------------------------------------------------------- setup

func _ready() -> void:
	name = "FlightController"
	add_to_group(&"flight_controller")
	_rng.randomize()
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)


func _on_match_started(_map: StringName) -> void:
	var d: Dictionary = GLData.load_json("res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0))
	cfg = d.get("flight", {})
	events = (d.get("act", {}) as Dictionary).get("events", {})
	for n: Node in get_tree().get_nodes_in_group(&"director"):
		director = n as ZombieDirector
	(func() -> void:
		if director != null and str(RoundManager.act_block_of(GameState.map_id).get("special_kind", "")) == "druckabfall":
			director.special_handler = self
		racks.clear()
		for r: Node in get_tree().get_nodes_in_group(&"bomb_racks"):
			racks.append(r)
		racks.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("rack_index")) < int(b.get("rack_index")))
		for r2: Node in racks:
			r2.set("jam_hold", float((cfg.get("bomb_run", {}) as Dictionary).get("jam_hold", 2.5)))
		var duds: Array[int] = pick_duds(int((cfg.get("bomb_run", {}) as Dictionary).get("duds", 2)), _rng)
		for di: int in duds:
			if di < racks.size():
				racks[di].call("set_marked", true)
		turb_t = float((cfg.get("turbulence", {}) as Dictionary).get("first_after", 25.0))
		breach_t = float((cfg.get("breach", {}) as Dictionary).get("first_after", 40.0))
		climber_t = float((cfg.get("climbers", {}) as Dictionary).get("climber_interval", 9.0))).call_deferred()


func _panels() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"breach_panels"):
		out.append(n)
	return out


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			out.append(p)
	return out


func _banner(text: String, hold: float = 3.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", text, hold)


func _vo(id: String) -> void:
	if id != "" and Net.is_authority():
		GLVO.play(StringName(id))


# ---------------------------------------------------------------- rounds

func _on_round_started(_r: int, special: bool) -> void:
	if not Net.is_authority():
		return
	var ar: int = RoundManager.act_round()
	if ar >= int(events.get("london_window_round", 3)) and not GameState.has_flag(&"london_seen"):
		start_london()
	if ar >= int(events.get("bomb_run_round", 5)) and not run_on and not run_done:
		start_bomb_run()
	if ar >= int(events.get("autopilot_fallback_round", 6)) and not GameState.has_flag(&"autopilot_key"):
		GameState.set_flag(&"autopilot_key")
		_banner("The engineer's key lies on his station: the flight deck is open", 4.0)
	# strafing: scheduled into this round
	var st: Dictionary = cfg.get("strafe", {})
	_strafe_at = -1.0
	if not special and ar >= int(st.get("from_act_round", 2)):
		var gap: int = _rng.randi_range(int(st.get("every_rounds_min", 2)), int(st.get("every_rounds_max", 3)))
		if RoundManager.current_round - _last_strafe_round >= gap:
			_strafe_at = _rng.randf_range(10.0, 40.0)
	if special and director != null and director.special_handler == self:
		_druck_start()
	_schedule_flight_clock(ar)


func _on_round_ended(_r: int) -> void:
	_druck_end()


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	if cfg.is_empty() or GameState.phase != GameState.Phase.PLAYING:
		return
	if not Net.is_authority():
		_tick_tilt_presentation(delta)
		return
	_tick_turbulence(delta)
	_tick_decompression(delta)
	_tick_strafe(delta)
	_tick_breaches(delta)
	_tick_climbers(delta)
	_tick_bomb_run(delta)


func _tick_turbulence(delta: float) -> void:
	var tc: Dictionary = cfg.get("turbulence", {})
	var tilt: Dictionary = cfg.get("turbulence_tilt", {})
	round_clock += delta
	if banking:
		bank_left -= delta
		tilt_t += delta
		_zombie_push_t -= delta
		if not tilt.is_empty():
			_tick_tilt(delta, tilt)
		elif _zombie_push_t <= 0.0 and director != null:
			_zombie_push_t = 0.25
			for z: Zombie in director.active_zombies():
				if z.is_active() and not (z is HomageBoss) and not z.is_pushed():
					z.external_push(Vector3(bank_side * float(tc.get("push_mps", 2.2)), 0, 0), 0.3)
		if bank_left <= 0.0:
			_end_bank()
		return
	if not tilt.is_empty():
		# UPDATE 10 (T-156): the flight clock: 2-3 tilts a round at seeded times, each warned warn_seconds ahead
		if tilt_times.is_empty():
			return
		var warn: float = float(tilt.get("warn_seconds", tc.get("warn_seconds", 3.0)))
		if not turb_warned and round_clock >= tilt_times[0] - warn:
			turb_warned = true
			_warn_tilt()
		if round_clock >= tilt_times[0]:
			tilt_times.remove_at(0)
			bank_now()
		return
	turb_t -= delta
	if not turb_warned and turb_t <= float(tc.get("warn_seconds", 3.0)):
		turb_warned = true
		_vo("PA_M4B_TURB_01")
		AudioDirector.play_2d("round_start", -10.0, 0.0)
	if turb_t <= 0.0:
		bank_now()


## The Bordfunk's chime and the warning 3 s ahead of a tilt (every peer hears the chime; the VO replicates itself).
func _warn_tilt() -> void:
	_vo("PA_M4B_TURB_01")
	_warn_sound()
	Net.mirror(self, &"_warn_sound")
	for ww: Node in get_tree().get_nodes_in_group(&"wing_walks"):
		ww.call("on_turbulence_warning")


func _warn_sound() -> void:
	AudioDirector.play_2d("kranich_bordfunk" if AudioDirector.has_sound("kranich_bordfunk") else "round_start", -8.0, 0.0)


func _end_bank() -> void:
	var tc: Dictionary = cfg.get("turbulence", {})
	banking = false
	tilt_t = 0.0
	_zslide.clear()
	for p: Player in _players():
		p.ext_roll_deg = 0.0
	turb_t = _rng.randf_range(float(tc.get("interval_min", 45.0)), float(tc.get("interval_max", 90.0)))
	turb_warned = false


## The deck banks: everyone is pushed sideways for `seconds`; zombies stumble at the onset. With the act's
## `turbulence_tilt` block (UPDATE 10, T-156) the bank is a tilt: the floor rolls tilt_deg, loose cargo and the dead
## slide downhill (KranichTilt), the dead take impact damage at the wall, players are pushed less; the wing walk's
## unclipped are thrown off. Host-owned; `_bank_mirror` runs the presentation on every client.
func bank_now() -> void:
	var tc: Dictionary = cfg.get("turbulence", {})
	var tilt: Dictionary = cfg.get("turbulence_tilt", {})
	banking = true
	bank_left = float(tilt.get("seconds", tc.get("seconds", 6.0)))
	bank_side = -bank_side
	banks_done += 1
	tilt_t = 0.0
	_zombie_push_t = 0.0
	_push_t = 0.0
	_zslide.clear()
	if tilt.is_empty():
		var v: Vector3 = Vector3(bank_side * float(tc.get("push_mps", 2.2)), 0, 0)
		for p: Player in _players():
			p.external_push(v, bank_left, &"push")
			p.ext_roll_deg = -bank_side * float(tc.get("roll_deg", 4.0))
			CameraSway.shake(p, 0.2)   # T-220: the comfort setting scales the flight's shake
	else:
		tilts_done += 1
		for p2: Player in _players():
			CameraSway.shake(p2, 0.25)
	if director != null:
		for z: Zombie in director.active_zombies():
			if z.is_active() and not (z is HomageBoss):
				z.force_stagger()
	for ww: Node in get_tree().get_nodes_in_group(&"wing_walks"):
		ww.call("on_turbulence", bank_left)
	Net.mirror(self, &"_bank_mirror", [bank_side, bank_left])
	if _first_turb:
		_first_turb = false
		_vo("OPR_M4B_TURB_01")
		GLVO.play_category(&"DUT", "M4B_TURB", 0.6)
	print("[flight] bank %d (side %+.0f)%s" % [banks_done, bank_side, " tilt" if not tilt.is_empty() else ""])


## A client's copy of the bank/tilt: the deck rolls under the local player and the loose cargo slides (the host
## pushes the zombies, decides the impacts and the knock-offs).
func _bank_mirror(side: float, seconds: float) -> void:
	if Net.is_authority():
		return
	banking = true
	bank_side = side
	bank_left = seconds
	tilt_t = 0.0
	banks_done += 1


## The tilt angle right now (degrees, 0 when level): TiltSlider and the camera read it.
func tilt_angle_now() -> float:
	if not banking:
		return 0.0
	var tilt: Dictionary = cfg.get("turbulence_tilt", {})
	if tilt.is_empty():
		return 0.0
	return KranichTilt.angle_at(tilt_t, float(tilt.get("seconds", 6.0)), float(tilt.get("tilt_deg", 8.0)),
		float(tilt.get("ease_in", 0.8)), float(tilt.get("ease_out", 1.0)))


## One host frame of a tilt: the roll on every player, the downhill push on players (reduced; the wing walk's own
## wind and knock-offs are WingWalk's) and on the dead, with the wall impact.
func _tick_tilt(delta: float, tilt: Dictionary) -> void:
	var deg: float = float(tilt.get("tilt_deg", 8.0))
	var angle: float = tilt_angle_now()
	var down: Vector3 = KranichTilt.downhill(bank_side)
	for p: Player in _players():
		p.ext_roll_deg = KranichTilt.roll_for(bank_side, angle)
	_push_t -= delta
	if _push_t <= 0.0:
		_push_t = 0.25
		var pm: float = float(tilt.get("player_push_mps", 1.6)) * clampf(angle / maxf(0.1, deg), 0.0, 1.0)
		if pm > 0.05:
			for p2: Player in _players():
				if not WingWalk.on_wing_any(get_tree(), p2):
					p2.external_push(down * pm, 0.3, &"push")
	if director == null or _zombie_push_t > 0.0:
		return
	_zombie_push_t = 0.25
	var zm: float = KranichTilt.zombie_slide_mps(angle, deg, float(tilt.get("zombie_slide_mps", 5.0)))
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z: Zombie in director.active_zombies():
		if not z.is_active() or z is HomageBoss or z.puppet:
			continue
		var id: int = z.get_instance_id()
		var e: Dictionary = _zslide.get(id, {})
		if not e.is_empty() and not bool(e.get("hit", false)):
			var moved: float = absf(z.global_position.x - float(e["x"]))
			var expected: float = float(e["mps"]) * 0.25
			var wall: float = _wall_ahead(space, z.global_position, down, 1.2)
			if KranichTilt.is_wall_impact(float(e["mps"]), moved, expected, wall, float(tilt.get("impact_min_mps", 2.5)), float(tilt.get("impact_reach_m", 0.9))):
				e["hit"] = true
				tilt_impacts += 1
				z.take_damage(KranichTilt.impact_damage(z.max_hp, float(tilt.get("impact_damage_frac", 0.6))), &"torso", &"tilt_wall", 0, &"world")
				AudioDirector.play_3d("impact_flesh", z.global_position + Vector3.UP, 0.0, 0.15)
		var pushed: bool = false
		if zm > 0.3 and not bool(e.get("hit", false)):
			z.external_push(down * zm, 0.3)
			pushed = z.is_pushed()
		e["x"] = z.global_position.x
		e["mps"] = zm if pushed else 0.0
		_zslide[id] = e


## Distance to the first world collider `reach` m ahead of `p` along `dir`, at chest and at knee height (a rack
## base or a bunk stops a sliding body as hard as a wall); -1 when clear.
func _wall_ahead(space: PhysicsDirectSpaceState3D, p: Vector3, dir: Vector3, reach: float) -> float:
	if space == null:
		return -1.0
	var best: float = -1.0
	for h: float in [0.9, 0.35]:
		var from: Vector3 = p + Vector3(0, h, 0)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1))
		if not hit.is_empty():
			var d: float = from.distance_to(hit["position"] as Vector3)
			best = d if best < 0.0 else minf(best, d)
	return best


## A client: the mirrored tilt rolls the local camera until it ends (the host ends its own bank).
func _tick_tilt_presentation(delta: float) -> void:
	if not banking:
		return
	bank_left -= delta
	tilt_t += delta
	var lp: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player) != null and (n as Player).is_local:
			lp = n as Player
	var tilt: Dictionary = cfg.get("turbulence_tilt", {})
	if lp != null:
		lp.ext_roll_deg = KranichTilt.roll_for(bank_side, tilt_angle_now()) if not tilt.is_empty() else -bank_side * float((cfg.get("turbulence", {}) as Dictionary).get("roll_deg", 4.0))
	if bank_left <= 0.0:
		banking = false
		tilt_t = 0.0
		if lp != null:
			lp.ext_roll_deg = 0.0


## The flight clock for this act round (host): the round's 2-3 tilts and the decompressions due in it.
func _schedule_flight_clock(ar: int) -> void:
	round_clock = 0.0
	var tilt: Dictionary = cfg.get("turbulence_tilt", {})
	if not tilt.is_empty() and ar >= int(tilt.get("from_act_round", 1)):
		var pr: Array = tilt.get("per_round", [2, 3])
		var n: int = _rng.randi_range(int(pr[0]), int(pr[1]))
		tilt_times = KranichTilt.schedule(n, tilt.get("first_s", [20, 35]), tilt.get("gap_s", [35, 60]), _rng)
		turb_warned = false
	decomp_queue.clear()
	var dc: Dictionary = cfg.get("decompression", {})
	for ev: Dictionary in dc.get("events", []):
		if int(ev.get("act_round", -1)) != ar:
			continue
		var node: Node = _find_decompression(str(ev.get("breach", "")))
		if node == null:
			continue
		var at: Array = ev.get("at_s", [30, 45])
		decomp_queue.append({"t": _rng.randf_range(float(at[0]), float(at[1])), "node": node})


func _find_decompression(n: String) -> Node:
	for d: Node in get_tree().get_nodes_in_group(&"decompressions"):
		if String(d.name) == n:
			return d
	return null


## The decompressions due on the round clock (DecompressionBreach warns 3 s ahead, then pulls for 4 s).
func _tick_decompression(_delta: float) -> void:
	for e: Dictionary in decomp_queue.duplicate():
		if round_clock >= float(e["t"]):
			decomp_queue.erase(e)
			var n: Node = e["node"]
			if is_instance_valid(n):
				n.call("start")
				decomps_done += 1


func _tick_strafe(delta: float) -> void:
	var st: Dictionary = cfg.get("strafe", {})
	if not _strafe_lines.is_empty():
		_strafe_tick -= delta
		for ln: Dictionary in _strafe_lines.duplicate():
			ln["t_left"] = float(ln["t_left"]) - delta
			if float(ln["t_left"]) <= 0.0:
				_strafe_lines.erase(ln)
				if is_instance_valid(ln.get("mesh")):
					(ln["mesh"] as Node).queue_free()
		if _strafe_tick <= 0.0:
			_strafe_tick = 0.1
			var w: float = float(st.get("width", 1.5))
			for ln2: Dictionary in _strafe_lines:
				for p: Player in _players():
					if strafe_line_hits(float(ln2["x"]), float(ln2["z0"]), float(ln2["z1"]), w, p.global_position):
						p.take_hit(float(st.get("dps", 60.0)) * 0.1, self)
				if director != null:
					for z: Zombie in director.active_zombies():
						if z.is_active() and not (z is HomageBoss) and strafe_line_hits(float(ln2["x"]), float(ln2["z0"]), float(ln2["z1"]), w, z.global_position):
							z.take_damage(float(st.get("zombie_dps", 3000.0)) * 0.1, &"torso", &"strafe", 0, &"bullet")
		return
	if _strafe_at < 0.0:
		return
	_strafe_at -= delta
	if _strafe_at > 0.0:
		return
	_strafe_at = -1.0
	strafe_now()


## Fighters find the wing: three tracer lines rake the zone the first living player stands in (never B or F).
func strafe_now() -> void:
	var st: Dictionary = cfg.get("strafe", {})
	var zones: Dictionary = st.get("zones", {})
	var zone: String = ""
	for p: Player in _players():
		var z: String = String(ZoneVolume.zone_at(get_tree(), p.global_position))
		if zones.has(z):
			zone = z
			break
	if zone == "":
		var open: Array = []
		for k: String in zones.keys():
			if GameState.is_zone_open(StringName(k)):
				open.append(k)
		if open.is_empty():
			return
		zone = open[_rng.randi_range(0, open.size() - 1)]
	var rect: Array = zones[zone]
	var x0: float = float((rect[0] as Array)[0])
	var z0: float = float((rect[0] as Array)[2])
	var x1: float = float((rect[1] as Array)[0])
	var z1: float = float((rect[1] as Array)[2])
	_strafe_zone = zone
	_last_strafe_round = RoundManager.current_round
	strafes_done += 1
	AudioDirector.play_2d("grenade_explode", -16.0, 0.3)
	if _first_strafe:
		_first_strafe = false
		_vo("OPR_M4B_STRAFE_01")
		GLVO.play_category(&"DUT", "M4B_STRAFE", 0.6)
	var lead: float = float(st.get("lead_seconds", 1.5))
	for i: int in int(st.get("lines", 3)):
		var x: float = _rng.randf_range(minf(x0, x1) + 1.0, maxf(x0, x1) - 1.0)
		var mesh: MeshInstance3D = Props.block(self, Vector3(x - 0.08, 1.9, minf(z0, z1)), Vector3(x + 0.08, 2.0, maxf(z0, z1)), "lumi_paint")
		mesh.visible = false
		get_tree().create_timer(lead + 0.3 * float(i)).timeout.connect(func() -> void:
			if is_instance_valid(mesh):
				mesh.visible = true
			_strafe_lines.append({"x": x, "z0": z0, "z1": z1, "t_left": float(st.get("seconds", 2.0)), "mesh": mesh})
			for bp: Node in _panels():
				var pp: Vector3 = (bp as Node3D).global_position
				if strafe_line_hits(x, z0, z1, float(st.get("width", 1.5)) * 2.0, pp) and String(bp.get("zone_id")) == zone:
					bp.call("blow", cfg.get("breach", {})))
	print("[flight] strafe %d over %s" % [strafes_done, zone])


func _tick_breaches(delta: float) -> void:
	var bc: Dictionary = cfg.get("breach", {})
	if RoundManager.act_round() < int(bc.get("from_act_round", 1)) or _druck_on:
		return
	breach_t -= delta
	if breach_t > 0.0:
		return
	breach_t = _rng.randf_range(float(bc.get("panel_interval_min", 70.0)), float(bc.get("panel_interval_max", 120.0)))
	var closed: Array = []
	for bp: Node in _panels():
		if not bool(bp.get("is_open")) and GameState.is_zone_open(StringName(String(bp.get("zone_id")))):
			closed.append(bp)
	if closed.is_empty():
		return
	blow_panel(closed[_rng.randi_range(0, closed.size() - 1)])


func blow_panel(bp: Node) -> void:
	bp.call("blow", cfg.get("breach", {}))
	_vo("PA_M4B_BREACH_01" if String(bp.get("zone_id")).ends_with("_L") else "PA_M4B_BREACH_02")
	if _first_breach:
		_first_breach = false
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _vo("OPR_M4B_BREACH_01"))
		GLVO.play_category(&"DUT", "M4B_BREACH", 0.5)


## The climbers' entries: the blister rims when E is open, every open breach.
func climb_entries() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if GameState.is_zone_open(&"E_KANZEL"):
		for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
			if n.name.begins_with("Catwalk_E_KANZEL"):
				out.append((n as Node3D).global_position)
	for bp: Node in _panels():
		if bool(bp.get("is_open")):
			out.append((bp as Node3D).global_position + (bp as Node3D).global_basis.z * 1.2)
	return out


func _count_climbers() -> int:
	var n: int = 0
	if director != null:
		for z: Zombie in director.active_zombies():
			if z.is_active() and z.has_meta("bordschuetze"):
				n += 1
	return n


func _tick_climbers(delta: float) -> void:
	if director == null:
		return
	var cc: Dictionary = cfg.get("climbers", {})
	climber_t -= delta
	if climber_t > 0.0:
		return
	climber_t = float((cfg.get("druckabfall", {}) as Dictionary).get("climber_interval", 6.0)) if _druck_on else float(cc.get("climber_interval", 9.0))
	if not RoundManager.can_spawn() or _count_climbers() >= int(cc.get("max_active", 6)):
		return
	var entries: Array[Vector3] = climb_entries()
	if entries.is_empty():
		return
	spawn_climber(entries[_rng.randi_range(0, entries.size() - 1)])


## One Bordschütze rises at `at` (from the round's queue). Returns the zombie or null.
func spawn_climber(at: Vector3) -> Zombie:
	if director == null or not RoundManager.can_spawn():
		return null
	var cc: Dictionary = cfg.get("climbers", {})
	var spec: Dictionary = director._spec_for(&"ganger", RoundManager.take_spawn())
	spec["variant"] = str(cc.get("kit", "soldier"))
	spec["tier"] = StringName(str(cc.get("tier", "jog")))
	spec["health"] = float(spec.get("health", 150.0)) * float(cc.get("health_mult", 1.2))
	var z: Zombie = director._activate_at(spec, director._snap(at))
	if z == null:
		RoundManager.requeue()
		return null
	z.set_meta("bordschuetze", true)
	climbers_spawned += 1
	return z


# ---------------------------------------------------------------- DRUCKABFALL (the special round)

func _druck_start() -> void:
	var dc: Dictionary = cfg.get("druckabfall", {})
	_druck_on = true
	_druck_next = 0
	_druck_t = 2.0
	_druck_panels = _panels()
	_druck_panels.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	_vo(str(dc.get("pa", "")))
	get_tree().create_timer(2.0).timeout.connect(func() -> void: _vo(str(dc.get("vo_start", ""))))
	_banner(str(dc.get("banner", "DRUCKABFALL")), 3.0)


func _druck_end() -> void:
	if not _druck_on:
		return
	_druck_on = false
	_vo(str((cfg.get("druckabfall", {}) as Dictionary).get("vo_end", "")))


## Called by the director instead of its Bellringer packs while the special round runs: the panels blow one by
## one and the climbers draw from the queue (the director drops the Resupply at the last entry when it clears).
func tick_special(delta: float) -> void:
	if not _druck_on:
		return
	_druck_t -= delta
	if _druck_t <= 0.0 and _druck_next < _druck_panels.size():
		var bp: Node = _druck_panels[_druck_next]
		_druck_next += 1
		_druck_t = float((cfg.get("druckabfall", {}) as Dictionary).get("panel_gap", 18.0))
		if GameState.is_zone_open(StringName(String(bp.get("zone_id")))):
			blow_panel(bp)
	var entries: Array[Vector3] = climb_entries()
	if not entries.is_empty() and director != null:
		director._last_bell_pos = entries[0]


# ---------------------------------------------------------------- the London window

func start_london() -> void:
	if london_started or get_tree().current_scene == null:
		return
	london_started = true
	var lw: LondonWindow = LondonWindow.new()
	lw.name = "LondonWindow"
	lw.cfg = cfg.get("london", {})
	get_tree().current_scene.add_child(lw)
	Net.mirror(self, &"_london_mirror")


func _london_mirror() -> void:
	if Net.is_authority() or london_started:
		return
	london_started = true
	var lw: LondonWindow = LondonWindow.new()
	lw.cfg = cfg.get("london", {})
	get_tree().current_scene.add_child(lw)


# ---------------------------------------------------------------- the bomb run

func rack_states() -> Array:
	var out: Array = []
	for r: Node in racks:
		var st: int = int(r.get("state"))
		out.append(["armed", "dropped", "jammed", "dud"][st])
	return out


func start_bomb_run() -> void:
	if run_on or run_done or racks.is_empty():
		return
	var br: Dictionary = cfg.get("bomb_run", {})
	run_on = true
	run_t = 0.0
	_run_banks = 0
	for r: Node in racks:
		r.set("run_on", true)
	_banner(str(br.get("banner", "ZIELANFLUG")) + "\nThe bay doors are opening: jam the racks", 5.0)
	_vo(str(br.get("pa_start", "")))
	get_tree().create_timer(2.0).timeout.connect(func() -> void: _vo(str(br.get("vo_start", ""))))
	# the marks: Wren (or Jakub) reads the duds as the run starts
	var marked: Array = []
	for r2: Node in racks:
		if bool(r2.get("marked")):
			marked.append(str(int(r2.get("rack_index"))))
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		var has_wren: bool = false
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			if String(GameState.character_of((n as Player).player_id)) == "wren" and (n as Player).is_alive():
				has_wren = true
		_vo("WRN_M4B_MARKS_01" if has_wren else "JAK_M4B_MARKS_01" if get_tree().get_first_node_in_group(&"jakub") != null else "PEG_M4B_RACK_DUD_01")
		_banner("Chalk on racks %s: duds" % " and ".join(marked), 4.0)
		GLVO.play_category(&"PEG", "M4B_BOMBRUN", 0.8))
	_build_hud()
	# rack 1 is away before the doors finish opening
	get_tree().create_timer(3.0).timeout.connect(func() -> void: _drop_next())
	print("[bombrun] started; duds on racks %s" % str(marked))


func _interval() -> float:
	var br: Dictionary = cfg.get("bomb_run", {})
	return float(br.get("solo_rack_interval", 45.0)) if GameState.human_ids().size() <= 1 else float(br.get("rack_interval", 35.0))


func _tick_bomb_run(delta: float) -> void:
	if not run_on:
		return
	run_t += delta
	for r: Node in racks:
		for n: Node in get_tree().get_nodes_in_group(&"bots"):
			var p: Player = n as Player
			if p != null:
				r.call("bot_tick", p, delta)
	_refresh_hud()
	var br: Dictionary = cfg.get("bomb_run", {})
	if _run_banks < int(br.get("banks", 2)) and not banking and run_t > 20.0 * float(_run_banks + 1):
		_run_banks += 1
		bank_now()
	if run_t >= _interval():
		run_t = 0.0
		_drop_next()


## The autopilot releases the next armed rack; the flags record the city's fate.
func _drop_next() -> void:
	if not run_on:
		return
	var i: int = next_rack(rack_states())
	if i < 0:
		_finish_run()
		return
	var r: Node = racks[i]
	var marked: bool = bool(r.get("marked"))
	r.call("drop")
	Net.mirror(r, &"drop")
	var city: String = str(r.get("city"))
	var res: String = result_of("dropped", marked)
	rack_results[city] = res
	GameState.set_flag(city_flag(city, res))
	_vo("PA_M4B_RACK_%02d" % int(r.get("rack_index")))
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		_vo("OPR_M4B_RACK_DUD_01" if marked else ("OPR_M4B_RACK_DROP_01" if int(r.get("rack_index")) <= 1 else "OPR_M4B_RACK_DROP_02")))
	_banner("RACK %d · %s · %s" % [int(r.get("rack_index")), city, "A DUD (the chalk)" if marked else "DROPPED"], 3.5)
	if not marked:
		GLVO.play_category(&"WRN", "M4B_RACK_DROP", 0.7)
	if int(r.get("rack_index")) == 1:
		GLVO.play_category(&"DUT", "M4B_BOMBRUN", 1.0)
	# every rack after this one that is already jammed is decided; nothing more to do for it
	if next_rack(rack_states()) < 0:
		get_tree().create_timer(3.0).timeout.connect(_finish_run)


func rack_jammed(r: Node) -> void:
	var city: String = str(r.get("city"))
	rack_results[city] = "saved"
	GameState.set_flag(city_flag(city, "saved"))
	_vo("OPR_M4B_RACK_JAM_01")
	_banner("RACK %d · %s · JAMMED" % [int(r.get("rack_index")), city], 3.0)
	GLVO.play_category(&"DEA", "M4B_RACK_JAM", 0.7)


func _finish_run() -> void:
	if not run_on:
		return
	run_on = false
	run_done = true
	for r: Node in racks:
		r.set("run_on", false)
		var city: String = str(r.get("city"))
		if not rack_results.has(city):
			var st: String = rack_states()[int(r.get("rack_index")) - 1]
			var res: String = result_of(st, bool(r.get("marked")))
			rack_results[city] = res
			GameState.set_flag(city_flag(city, res))
	GameState.set_flag(&"bomb_run_done")
	var br: Dictionary = cfg.get("bomb_run", {})
	_vo(str(br.get("vo_end", "")))
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		_vo(str(br.get("pa_end", "")))
		GLVO.play_category(&"DEA", "M4B_HEADING", 1.0))
	_refresh_hud()
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if _hud != null:
			_hud.queue_free()
			_hud = null)
	print("[bombrun] done: %s" % str(rack_results))


func _build_hud() -> void:
	if _hud != null:
		return
	_hud = CanvasLayer.new()
	_hud.layer = 12
	add_child(_hud)
	var row: HBoxContainer = HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.position = Vector2(24, 118)
	row.add_theme_constant_override("separation", 8)
	_hud.add_child(row)
	_hud_labels.clear()
	for r: Node in racks:
		var l: Label = Label.new()
		l.add_theme_font_size_override("font_size", 18)
		row.add_child(l)
		_hud_labels.append(l)
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud == null:
		return
	var states: Array = rack_states()
	for i: int in mini(states.size(), _hud_labels.size()):
		var l: Label = _hud_labels[i]
		var st: String = str(states[i])
		var city: String = str(racks[i].get("city"))
		match st:
			"armed":
				l.text = "▣ %d %s" % [i + 1, city]
				l.modulate = Color(0.9, 0.85, 0.7)
			"jammed":
				l.text = "▣ %d %s ✓" % [i + 1, city]
				l.modulate = Color(0.5, 0.9, 0.6)
			"dud":
				l.text = "▽ %d %s (dud)" % [i + 1, city]
				l.modulate = Color(0.6, 0.6, 0.55)
			_:
				l.text = "▽ %d %s" % [i + 1, city]
				l.modulate = Color(0.85, 0.3, 0.3)
