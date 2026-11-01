extends Node
## Power-up drops (GDD §11, D-010). Each player's earned Scrip counts toward a shared, growing threshold;
## once a player crosses it, their next kill drops a power-up. There's also a small base chance per kill.
## Types come from a shuffled bag so every type shows up before any repeats. Max N drops per round.
## The decision logic lives in static functions so tests can run without a scene.
##
## Public API: spawn(id, position), force_drop(id), active_timers() -> {id: seconds_left}, reset_match().
## Milestones (T-078, rounds.json "milestones"): guaranteed drops on reaching a round (round 5: a tonic bottle and a
## Resupply). They land when the round before ends, last longer, and are applied anyway if nobody takes them:
## milestone_drops(round, rounds_cfg), drop_milestone(round) (dev / tests), milestones_done().
## The tonic bottle (milestone only): gift_tonic(pid) gives one survivor a free tonic (pick_gift is the pure rule).

const PICKUP_SCRIPT: String = "res://gravelight/world/powerup_pickup.gd"
const HUD_SCRIPT: String = "res://gravelight/ui/powerup_hud.gd"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bag: Array[StringName] = []
var _drops_this_round: int = 0
var _earned: Dictionary = {}       # player_id -> Scrip earned since their last drop
var _threshold: float = 2000.0
var _drops_total: int = 0           # drops this match (drives threshold growth)
var _timers: Dictionary = {}       # powerup_id -> seconds left (timed effects only)
var _pickups: Array[Node] = []
var _hud: CanvasLayer = null
var _milestones_done: Dictionary = {}   # round -> true (this match)
var _last_kill_pos: Vector3 = Vector3.INF
var _last_killer: int = 0


func _ready() -> void:
	rng.randomize()
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.scrip_changed.connect(_on_scrip_changed)
	GLBus.round_started.connect(_on_round_started)
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_ended.connect(_on_round_ended_milestone)


# ---------------------------------------------------------------- pure logic (tested)

## Draws the next drop type. Refills and reshuffles the bag when empty.
## `extra` lets conditional drops (Clearance) join the bag once their condition is met.
static func draw_from_bag(bag: Array[StringName], source: Array, extra: Array[StringName], r: RandomNumberGenerator) -> StringName:
	if bag.is_empty():
		for id: Variant in source:
			bag.append(StringName(str(id)))
		bag.append_array(extra)
		# Fisher-Yates with the injected RNG so tests are deterministic.
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = r.randi_range(0, i)
			var tmp: StringName = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
	return bag.pop_back()


## Conditional bag entries (e.g. Clearance after the crate has moved once).
static func conditional_extras(cfg: Dictionary, flags: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var cond: Dictionary = cfg.get("conditional", {})
	for id: Variant in cond.keys():
		var rule: Dictionary = cond[id]
		if bool(flags.get(StringName(str(rule["requires"])), false)):
			for i: int in int(rule.get("bag_copies", 1)):
				out.append(StringName(str(id)))
	return out


## Whether a kill drops a power-up.
## eligible = this player's earned Scrip has reached the threshold.
static func should_drop(eligible: bool, drops_this_round: int, cfg: Dictionary, roll: float) -> bool:
	if drops_this_round >= int(cfg["max_per_round"]):
		return false
	if eligible:
		return roll < float(cfg.get("drop_chance_when_eligible", 1.0))
	return roll < float(cfg.get("base_random_chance", 0.0))


## Threshold after `drops` drops this match.
static func threshold_after(drops: int, cfg: Dictionary) -> float:
	return float(cfg["scrip_threshold_start"]) * pow(float(cfg["scrip_threshold_growth"]), drops)


static func is_timed(id: StringName, cfg: Dictionary) -> bool:
	return (cfg.get("timed", []) as Array).has(String(id))


## The guaranteed drops on reaching `round_number` (rounds.json "milestones"; [] for none).
static func milestone_drops(round_number: int, rounds_cfg: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var m: Dictionary = rounds_cfg.get("milestones", {})
	for id: Variant in m.get(str(round_number), []):
		out.append(StringName(str(id)))
	return out


## The tonic bottle's gift for one survivor (pure). `owned`: their perks; `map_perks`: the map's tonics;
## `capped` / `cap`: their perk count against the cap; `excluded`: perks they can't get (solo Second Wind gone);
## `upgradable`: carried perks whose next tier they may have. Returns {"kind": "perk", "perk"} under the cap with a
## tonic left, else {"kind": "tier", "perk"} with an upgradable one, else {"kind": "scrip", "scrip"}.
static func pick_gift(owned: Array, map_perks: Array, capped: int, cap: int, excluded: Array, upgradable: Array,
		full_cap_scrip: int, r: RandomNumberGenerator) -> Dictionary:
	if capped < cap:
		var pool: Array = []
		for p: Variant in map_perks:
			var id: StringName = StringName(str(p))
			if not owned.has(id) and not excluded.has(id) and not pool.has(id):
				pool.append(id)
		if not pool.is_empty():
			return {"kind": "perk", "perk": pool[r.randi_range(0, pool.size() - 1)]}
	if not upgradable.is_empty():
		return {"kind": "tier", "perk": StringName(str(upgradable[r.randi_range(0, upgradable.size() - 1)]))}
	return {"kind": "scrip", "scrip": full_cap_scrip}


# ---------------------------------------------------------------- match flow

func reset_match() -> void:
	for id: Variant in _timers.keys():
		_end_effect(StringName(str(id)), false)
	_timers.clear()
	for p: Node in _pickups:
		if is_instance_valid(p):
			p.queue_free()
	_pickups.clear()
	_bag.clear()
	_earned.clear()
	_drops_this_round = 0
	_drops_total = 0
	_threshold = threshold_after(0, _cfg())
	_milestones_done.clear()
	_last_kill_pos = Vector3.INF
	_last_killer = 0
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _cfg() -> Dictionary:
	return GLData.table("powerups")


func _on_match_started(_map_id: StringName) -> void:
	reset_match()
	var parent: Node = _map_node()
	if parent != null:
		_hud = (load(HUD_SCRIPT) as GDScript).new() as CanvasLayer
		parent.add_child(_hud)



func _on_round_started(_round: int, _special: bool) -> void:
	_drops_this_round = 0


func _on_scrip_changed(player: int, _total: int, delta: int) -> void:
	if delta > 0 and not Economy.moving:   # (a bank withdrawal never feeds the drops, T-136)
		_earned[player] = int(_earned.get(player, 0)) + delta


func _on_enemy_killed_at(_enemy_id: StringName, position: Vector3, by_player: int) -> void:
	_last_kill_pos = position
	_last_killer = by_player
	if by_player <= 0 or GameState.phase != GameState.Phase.PLAYING or not Net.is_authority():
		return
	var cfg: Dictionary = _cfg()
	var eligible: bool = float(_earned.get(by_player, 0)) >= _threshold
	if not should_drop(eligible, _drops_this_round, cfg, rng.randf()):
		return
	if eligible:
		_earned[by_player] = 0
	_drops_this_round += 1
	_drops_total += 1
	_threshold = threshold_after(_drops_total, cfg)
	spawn(_next_type(), position)


# ---------------------------------------------------------------- milestones (T-078)

func _on_round_ended_milestone(round_number: int) -> void:
	if not Net.is_authority() or GameState.phase != GameState.Phase.PLAYING:
		return
	drop_milestone(round_number + 1)


func milestones_done() -> Array:
	return _milestones_done.keys()


## Drops the milestone rewards of `round_number` (once per match): a step ahead of the standing survivor nearest the
## last kill, toward it, side by side on the navmesh. Returns the pickups.
func drop_milestone(round_number: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var ids: Array[StringName] = milestone_drops(round_number, GLData.table("rounds"))
	if ids.is_empty() or _milestones_done.has(round_number) or not Net.is_authority():
		return out
	var mc: Dictionary = _cfg().get("milestone", {})
	var anchor: Player = _nearest_standing(_last_kill_pos)
	var base: Vector3 = _last_kill_pos
	var side: Vector3 = Vector3.RIGHT
	if anchor != null:
		var to: Vector3 = -anchor.global_basis.z
		if _last_kill_pos != Vector3.INF:
			to = _last_kill_pos - anchor.global_position
		to.y = 0.0
		if to.length() < 0.2:
			to = -anchor.global_basis.z
			to.y = 0.0
		to = to.normalized()
		base = anchor.global_position + to * float(mc.get("ahead_m", 1.8))
		side = to.cross(Vector3.UP).normalized()
	if base == Vector3.INF:
		return out
	_milestones_done[round_number] = true
	var spacing: float = float(mc.get("spacing_m", 1.3))
	for i: int in ids.size():
		var at: Vector3 = base + side * spacing * (float(i) - float(ids.size() - 1) * 0.5)
		at = _on_navmesh(at, anchor)
		var p: Node3D = spawn(ids[i], at, float(mc.get("lifetime_seconds", 60.0)), float(mc.get("blink_from_seconds", 50.0)))
		if p != null:
			out.append(p)
	GLVO.play_category(&"OPR", "MILESTONE", 1.0)
	var names: PackedStringArray = []
	for id: StringName in ids:
		names.append(String(id))
	print("[powerups] round %d milestone: %s" % [round_number, ", ".join(names)])
	return out


func _nearest_standing(to: Vector3) -> Player:
	var best: Player = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.downed or p.spectating or p.is_companion:
			continue
		var d: float = 0.0 if to == Vector3.INF else p.global_position.distance_squared_to(to)
		if d < bd:
			bd = d
			best = p
	return best


func _on_navmesh(at: Vector3, near: Node3D) -> Vector3:
	if near == null or not near.is_inside_tree():
		return at
	var nav: RID = near.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav) == 0:
		return at
	var q: Vector3 = NavigationServer3D.map_get_closest_point(nav, at)
	return q if q.distance_to(at) < 3.0 else near.global_position


# ---------------------------------------------------------------- the tonic bottle (T-078)

## Gives survivor `pid` the tonic bottle's gift (pick_gift). Returns what they got.
func gift_tonic(pid: int) -> Dictionary:
	if not Net.is_authority():
		return {}
	var tb: Dictionary = _cfg().get("tonic_bottle", {})
	var map_perks: Array = []
	for m: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var mid: StringName = StringName(str(m.get("perk_id")))
		if not PerkManager.perk_data(mid).is_empty() and not map_perks.has(mid):
			map_perks.append(mid)
	if map_perks.is_empty():
		for id: Variant in (GLData.table("perks")["perks"] as Dictionary).keys():
			map_perks.append(StringName(str(id)))
	var excluded: Array = []
	if GameState.is_solo() and PerkManager.second_wind_gone:
		excluded.append(&"second_wind")
	var upgradable: Array = []
	for p: Variant in PerkManager.owned(pid):
		var pp: StringName = StringName(str(p))
		var t: int = PerkManager.tier_of(pid, pp)
		# T-121: the bottle's measure is a gift, so the profile's mastery lock doesn't apply (nor the round gate)
		if t >= 1 and t < PerkManager.max_tier() and not PerkManager.tier_data(pp, t + 1).is_empty():
			upgradable.append(pp)
	var g: Dictionary = pick_gift(PerkManager.owned(pid), map_perks, PerkManager.capped_count(pid), PerkManager.cap_for(pid),
		excluded, upgradable, int(tb.get("full_cap_scrip", 1500)), rng)
	var gp: StringName = StringName(str(g.get("perk", "")))
	match str(g["kind"]):
		"perk":
			PerkManager.grant(pid, gp)
			GLBus.bonus_awarded.emit(pid, &"tonic_bottle", 0, "FREE TONIC: %s" % PerkManager.display_name(gp).to_upper())
		"tier":
			var nt: int = PerkManager.tier_of(pid, gp) + 1
			PerkManager.set_tier(pid, gp, nt)
			PerkManager.seal(pid, gp)   # T-121: and it stays through a down
			g["tier"] = nt
			GLBus.bonus_awarded.emit(pid, &"tonic_bottle", 0, "FREE MEASURE: %s  ·  KEPT FOR GOOD" % PerkManager.tier_name(gp, nt).to_upper())
		_:
			Economy.grant_raw(pid, int(g["scrip"]))   # T-141: a substitute for the free tonic, no earning
			GLBus.bonus_awarded.emit(pid, &"tonic_bottle", int(g["scrip"]), "PERKS FULL: TONIC MONEY")
	print("[powerups] tonic bottle -> P%d: %s" % [pid, str(g)])
	return g


func _next_type() -> StringName:
	var cfg: Dictionary = _cfg()
	var id: StringName = draw_from_bag(_bag, cfg["bag"], conditional_extras(cfg, GameState.flags), rng)
	# A Clearance left in the bag from before the condition was lost is skipped.
	var guard: int = 0
	while not _type_allowed(id) and guard < 20:
		id = draw_from_bag(_bag, cfg["bag"], conditional_extras(cfg, GameState.flags), rng)
		guard += 1
	return id


func _type_allowed(id: StringName) -> bool:
	var cond: Dictionary = _cfg().get("conditional", {})
	if cond.has(String(id)):
		return GameState.has_flag(StringName(str(cond[String(id)]["requires"])))
	return true


func _map_node() -> Node:
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.get_parent() != null:
		return dir.get_parent()
	return get_tree().current_scene


# ---------------------------------------------------------------- spawning / collecting

## `lifetime` / `blink_from` > 0 override powerups.json's (milestone drops last longer and are applied if they expire).
func spawn(id: StringName, position: Vector3, lifetime: float = 0.0, blink_from: float = 0.0) -> Node3D:
	var parent: Node = _map_node()
	if parent == null or not Net.is_authority():
		return null
	if parent is MapRoot:
		position = (parent as MapRoot).clamp_inside(position)   # a kill beyond Map 0's edge drops inside it (T-084)
	var pickup: Node3D = (load(PICKUP_SCRIPT) as GDScript).new() as Node3D
	pickup.set("powerup_id", id)
	pickup.set("lifetime_override", lifetime)
	pickup.set("blink_override", blink_from)
	parent.add_child(pickup)
	pickup.global_position = position + Vector3.UP * 0.9
	pickup.connect(&"collected", _on_pickup_collected.bind(pickup))
	if lifetime > 0.0:
		pickup.connect(&"expired", _on_pickup_expired.bind(pickup))
	pickup.tree_exiting.connect(func() -> void: _pickups.erase(pickup))
	_pickups.append(pickup)
	if Net.replicating():
		Net.session.spawn_dynamic(pickup, PICKUP_SCRIPT, {"powerup_id": id, "lifetime_override": lifetime, "blink_override": blink_from})
	GLBus.powerup_spawned.emit(id, position)
	return pickup


## Dev console: drop `id` 2 m in front of the first player.
func force_drop(id: StringName) -> bool:
	if not (_cfg()["names"] as Dictionary).has(String(id)):
		return false
	var p: Node3D = get_tree().get_first_node_in_group(&"players") as Node3D
	if p == null:
		return false
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	spawn(id, p.global_position + fwd.normalized() * 2.0)
	return true


func _on_pickup_collected(by_player: int, pickup: Node3D) -> void:
	var id: StringName = StringName(str(pickup.get("powerup_id")))
	apply(id, by_player)


## A milestone drop nobody took: the squad gets it anyway (by_player 0).
func _on_pickup_expired(pickup: Node3D) -> void:
	if Net.is_authority() and GameState.phase == GameState.Phase.PLAYING:
		apply(StringName(str(pickup.get("powerup_id"))), 0)


## Applies a power-up as if `by_player` picked it up.
func apply(id: StringName, by_player: int) -> void:
	var cfg: Dictionary = _cfg()
	var rewards: Dictionary = cfg["rewards"]
	match id:
		&"resupply":
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				if n is Player:
					(n as Player).weapons.refill_all()
		&"deaths_door":
			GameState.set_flag(&"deaths_door", true)
		&"double_scrip":
			Economy.multiplier = 2
		&"blackout":
			var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
			if dir != null:
				dir.kill_all(true)
			_award_all(int(rewards["blackout_scrip"]))
		&"fortify":
			for n: Node in get_tree().get_nodes_in_group(&"barricades"):
				if n.has_method("fortify"):
					n.call("fortify")
			_award_all(int(rewards["fortify_scrip"]))
		&"clearance":
			GameState.set_flag(&"clearance", true)
		&"tonic_bottle":
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				var p: Player = n as Player
				if p != null and not p.spectating and not p.is_companion and Economy.has_account(p.player_id):
					gift_tonic(p.player_id)
	if is_timed(id, cfg):
		_timers[id] = float(cfg["timed_duration_seconds"])   # refreshing restarts the timer
	GLBus.powerup_collected.emit(id, by_player)


func _award_all(amount: int) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player:
			Economy.award((n as Player).player_id, amount)


func _process(delta: float) -> void:
	if _timers.is_empty():
		return
	for id: Variant in _timers.keys():
		_timers[id] = float(_timers[id]) - delta
		if float(_timers[id]) <= 0.0:
			_timers.erase(id)
			if Net.is_authority():   # a client's timers are the host's (HUD only)
				_end_effect(StringName(str(id)), true)


func _end_effect(id: StringName, announce: bool) -> void:
	match id:
		&"deaths_door":
			GameState.set_flag(&"deaths_door", false)
		&"double_scrip":
			Economy.multiplier = 1
		&"clearance":
			GameState.set_flag(&"clearance", false)
	if announce:
		GLBus.powerup_expired.emit(id)


func active_timers() -> Dictionary:
	return _timers.duplicate()


func display_name(id: StringName) -> String:
	return str((_cfg()["names"] as Dictionary).get(String(id), String(id).to_upper()))
