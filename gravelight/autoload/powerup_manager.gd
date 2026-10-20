extends Node
## Power-up drops (GDD §11, D-010). Each player's earned Scrip counts toward a shared, growing threshold;
## once a player crosses it, their next kill drops a power-up. There's also a small base chance per kill.
## Types come from a shuffled bag so every type shows up before any repeats. Max N drops per round.
## The decision logic lives in static functions so tests can run without a scene.
##
## Public API: spawn(id, position), force_drop(id), active_timers() -> {id: seconds_left}, reset_match().

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


func _ready() -> void:
	rng.randomize()
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at)
	GLBus.scrip_changed.connect(_on_scrip_changed)
	GLBus.round_started.connect(_on_round_started)
	GLBus.match_started.connect(_on_match_started)


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
	if delta > 0:
		_earned[player] = int(_earned.get(player, 0)) + delta


func _on_enemy_killed_at(_enemy_id: StringName, position: Vector3, by_player: int) -> void:
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

func spawn(id: StringName, position: Vector3) -> Node3D:
	var parent: Node = _map_node()
	if parent == null or not Net.is_authority():
		return null
	var pickup: Node3D = (load(PICKUP_SCRIPT) as GDScript).new() as Node3D
	pickup.set("powerup_id", id)
	parent.add_child(pickup)
	pickup.global_position = position + Vector3.UP * 0.9
	pickup.connect(&"collected", _on_pickup_collected.bind(pickup))
	pickup.tree_exiting.connect(func() -> void: _pickups.erase(pickup))
	_pickups.append(pickup)
	if Net.replicating():
		Net.session.spawn_dynamic(pickup, PICKUP_SCRIPT, {"powerup_id": id})
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
