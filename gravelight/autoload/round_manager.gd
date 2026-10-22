extends Node
## Round flow: intro -> round (spawn queue) -> break -> next round. Formulas are static so tests run without a scene.
## Authority note: only the host/server advances rounds; clients mirror the state.

enum State { IDLE, BREAK, ROUND }

const INTRO_SECONDS: float = 6.0

var state: State = State.IDLE
var current_round: int = 0
var to_spawn: int = 0          # zombies still queued this round
var alive: int = 0             # zombies currently active
var round_total: int = 0
var break_left: float = 0.0
var players: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sprint_streak: int = 0
var _cfg: Dictionary = {}
var _holds: Dictionary = {}    # key -> true: the round can't end while any hold is set (pylon holdouts)
## Special (Bellringer) rounds and the Foreman schedule.
var is_special_round: bool = false
var next_special: int = 5
var next_boss: int = 13
var _warned: bool = false
## Rounds an event owns (HB1: the Cousins Round on Map 0): no Bellringer round and no Foreman lands on one;
## either is pushed to the next free round, as the Foreman already is by a Bellringer round. Set by the map's
## event (CousinsRound) when it is created; cleared by stop() when the map is left.
var _reserved: Dictionary = {}


static func zombie_health(round_number: int, cfg: Dictionary) -> int:
	var h: Dictionary = cfg["health"]
	var until: int = int(h["linear_until_round"])
	var linear_at: float = float(h["base"]) + float(h["linear_per_round"]) * float(mini(round_number, until) - 1)
	if round_number <= until:
		return int(linear_at)
	return int(floor(linear_at * pow(float(h["exp_multiplier"]), round_number - until)))


static func zombie_count(round_number: int, player_count: int, cfg: Dictionary) -> int:
	var c: Dictionary = cfg["count"]
	var n: float = float(round_number - 1)
	var base: float = float(c["base"]) + float(c["linear"]) * n + float(c["quadratic"]) * n * n
	var mults: Array = c["player_mult"]
	var mult: float = float(mults[clampi(player_count, 1, mults.size()) - 1])
	return int(ceil(base * mult))


static func spawn_interval(round_number: int, cfg: Dictionary) -> float:
	var s: Dictionary = cfg["spawn_interval"]
	return maxf(float(s["min"]), float(s["start"]) * pow(float(s["decay"]), round_number - 1))


## Bellringer count: 6 per player + round/2, capped at 24 + 6 per player (ENEMIES.md §2.3).
static func bell_count(round_number: int, player_count: int, cfg: Dictionary) -> int:
	var b: Dictionary = cfg["special_round"]["bell_count"]
	var p: int = maxi(1, player_count)
	var n: int = int(b["per_player"]) * p + floori(float(round_number) / float(b["round_div"]))
	return mini(n, int(b["cap_base"]) + int(b["cap_per_player"]) * p)


## Next scheduled round after `prev` with a uniform gap in [gap_min, gap_max].
static func next_after(prev: int, gap_min: int, gap_max: int, r: RandomNumberGenerator) -> int:
	return prev + r.randi_range(gap_min, gap_max)


## Glasshide share of Ganger spawns at a round (0 before the gate).
static func glasshide_chance(round_number: int, e: Dictionary) -> float:
	if round_number < int(e["from_round"]):
		return 0.0
	return minf(float(e["chance_cap"]), float(e["chance_start"]) + float(e["chance_per_round"]) * float(round_number - int(e["from_round"])))


## Chance that a Screamer appears this round (0 before the gate).
static func screamer_chance(round_number: int, e: Dictionary) -> float:
	if round_number < int(e["from_round"]):
		return 0.0
	return minf(float(e["chance_cap"]), float(e["chance_start"]) + float(e["chance_per_round"]) * float(round_number - int(e["from_round"])))


## Foreman health: 2500 x round x player multiplier.
static func foreman_health(round_number: int, player_count: int, e: Dictionary) -> int:
	var mults: Array = e["player_mult"]
	var m: float = float(mults[clampi(player_count, 1, mults.size()) - 1])
	return int(float(e["health_per_round"]) * float(maxi(1, round_number)) * m)


static func speed_weights(round_number: int, cfg: Dictionary) -> Dictionary:
	for band: Dictionary in cfg["speed_tiers"]["bands"]:
		if round_number >= int(band["from"]) and round_number <= int(band["to"]):
			return band["weights"]
	return {}


## Weighted tier pick. Never more than `max_streak` sprinters in a row.
static func pick_tier(weights: Dictionary, roll: float, sprint_streak: int, max_streak: int) -> StringName:
	var pool: Dictionary = weights.duplicate()
	if sprint_streak >= max_streak and pool.size() > 1:
		pool.erase("sprint")
	var total: float = 0.0
	for w: Variant in pool.values():
		total += float(w)
	var acc: float = 0.0
	for tier: Variant in pool.keys():
		acc += float(pool[tier]) / total
		if roll <= acc:
			return StringName(str(tier))
	return StringName(str(pool.keys().back()))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()


func start_game(player_count: int) -> void:
	_cfg = GLData.table("rounds")
	_holds.clear()
	var sr: Dictionary = _cfg["special_round"]
	next_special = rng.randi_range(int(sr["first_min"]), int(sr["first_max"]))
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	next_boss = rng.randi_range(int(fm["first_round_min"]), int(fm["first_round_max"]))
	is_special_round = false
	_warned = false
	players = player_count
	current_round = 0
	to_spawn = 0
	alive = 0
	state = State.BREAK
	break_left = INTRO_SECONDS
	_skip_reserved()


func stop() -> void:
	state = State.IDLE
	_reserved.clear()


## An event owns round `r` (no special / Foreman on it; see _reserved).
func reserve_round(r: int) -> void:
	_reserved[r] = true
	_skip_reserved()


func unreserve_round(r: int) -> void:
	_reserved.erase(r)


func is_reserved(r: int) -> bool:
	return _reserved.has(r)


func _skip_reserved() -> void:
	while _reserved.has(next_special):
		next_special += 1
	while _reserved.has(next_boss):
		next_boss += 1


## Event bosses that are not out yet still hold the round open: they count as alive from now (each one's death
## calls on_zombie_died like any zombie). release_alive gives back the ones that never died (they left).
func reserve_alive(n: int) -> void:
	alive += maxi(0, n)


func release_alive(n: int) -> void:
	for i: int in maxi(0, n):
		on_zombie_died()


func _process(delta: float) -> void:
	if not Net.is_authority():
		return   # a co-op client mirrors the host's round state (NetMatch.on_state)
	if state == State.BREAK:
		break_left -= delta
		if not _warned and current_round + 1 == next_special and break_left <= float(_cfg["special_round"].get("warning_seconds", 6.0)):
			_warned = true
			GLBus.special_round_warning.emit(StringName(str(_cfg["special_round"].get("kind", "bellringer"))))
		if break_left <= 0.0:
			advance_round()


func advance_round() -> void:
	current_round += 1
	_warned = false
	is_special_round = current_round == next_special
	var sr: Dictionary = _cfg["special_round"]
	if is_special_round:
		round_total = bell_count(current_round, players, _cfg)
		next_special = next_after(current_round, int(sr["interval_min"]), int(sr["interval_max"]), rng)
	else:
		round_total = zombie_count(current_round, players, _cfg)
	# The Foreman never comes on a Bellringer round: push him back a round.
	if next_boss == current_round and is_special_round:
		next_boss += 1
	_skip_reserved()
	to_spawn = round_total
	_sprint_streak = 0
	state = State.ROUND
	GameState.stats[&"round"] = current_round
	GLBus.round_started.emit(current_round, is_special_round)


## True on the round the Foreman is scheduled for (the director consumes it).
func boss_due() -> bool:
	return current_round == next_boss and not is_special_round


func consume_boss() -> void:
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	next_boss = next_after(current_round, int(fm["interval_min"]), int(fm["interval_max"]), rng)


## Dev console: the next round is a Bellringer round.
func force_special_next() -> void:
	next_special = current_round + 1
	_warned = false


func current_health() -> int:
	return zombie_health(maxi(1, current_round), _cfg)


func current_interval() -> float:
	return spawn_interval(current_round, _cfg)


func max_active() -> int:
	return int(_cfg.get("max_active", 24))


func can_spawn() -> bool:
	if state == State.ROUND and to_spawn <= 0 and not _holds.is_empty():
		to_spawn = 1   # holdouts keep the zombies coming
	return state == State.ROUND and to_spawn > 0 and alive < max_active()


## While any hold is set the round keeps spawning and can't end (e.g. a pylon charging).
func set_hold(key: StringName, on: bool) -> void:
	if not Net.is_authority():
		return
	if on:
		_holds[key] = true
	else:
		_holds.erase(key)
		if state == State.ROUND and to_spawn <= 1 and alive <= 0 and _holds.is_empty():
			to_spawn = 0
			_end_round()


func is_held() -> bool:
	return not _holds.is_empty()


## An extra zombie that doesn't come out of the round queue (power-on burst). It still has to die.
func take_extra_spawn() -> Dictionary:
	alive += 1
	return {"tier": pick_tier(speed_weights(maxi(1, current_round), _cfg), rng.randf(), 0, 3), "health": current_health()}


## Takes one zombie off the queue and returns its spawn spec.
func take_spawn() -> Dictionary:
	to_spawn -= 1
	alive += 1
	var tiers: Dictionary = _cfg["speed_tiers"]
	var tier: StringName = pick_tier(speed_weights(maxi(1, current_round), _cfg), rng.randf(), _sprint_streak, int(tiers.get("max_sprint_streak", 3)))
	_sprint_streak = _sprint_streak + 1 if tier == &"sprint" else 0
	return {"tier": tier, "health": current_health()}


## A spawned zombie got recycled (stuck/unreachable): put it back in the queue.
func requeue() -> void:
	alive = maxi(0, alive - 1)
	to_spawn += 1


func on_zombie_died() -> void:
	alive = maxi(0, alive - 1)
	if state == State.ROUND and to_spawn <= 0 and alive <= 0 and _holds.is_empty():
		_end_round()


func remaining() -> int:
	return to_spawn + alive


func _end_round() -> void:
	state = State.BREAK
	var b: Dictionary = _cfg["break_seconds"]
	break_left = rng.randf_range(float(b["min"]), float(b["max"]))
	GLBus.round_ended.emit(current_round)


## A carried schedule entry (next special / boss round) that already passed is pushed past the arrival round
## with its usual gap, so Bellringers and the Foreman keep their rhythm across maps (T-033).
static func carried_schedule(next_round: int, arrival: int, gap_min: int, gap_max: int, r: RandomNumberGenerator) -> int:
	if next_round > arrival:
		return next_round
	return arrival + r.randi_range(gap_min, gap_max)


## Campaign arrival (T-033): the count continues from the round the squad left the last map on, so the next
## round is `left_on + 1` with that round's zombie count and health. The carried Bellringer / Foreman schedule
## is kept; an entry already behind the arrival round is pushed past it with its usual gap. The first round on
## the new map waits `grace` seconds (instead of the intro) so the squad can get its bearings.
func resume_at(left_on: int, carried_special: int, carried_boss: int, grace: float) -> void:
	current_round = maxi(0, left_on)
	var arrival: int = current_round + 1
	var sr: Dictionary = _cfg["special_round"]
	var fm: Dictionary = GLData.table("enemies")["enemies"]["foreman"]
	next_special = carried_schedule(carried_special, arrival, int(sr["interval_min"]), int(sr["interval_max"]), rng)
	next_boss = carried_schedule(carried_boss, arrival, int(fm["interval_min"]), int(fm["interval_max"]), rng)
	is_special_round = false
	_warned = false
	to_spawn = 0
	alive = 0
	state = State.BREAK
	break_left = maxf(0.5, grace)
	_skip_reserved()
	GameState.stats[&"round"] = current_round


## Dev console: jump so the NEXT round is `target`. Active zombies are cleared by the caller.
func debug_set_round(target: int) -> void:
	current_round = maxi(0, target - 1)
	if next_special < target:
		next_special = target + rng.randi_range(2, 5)
	if next_boss < target:
		next_boss = target + rng.randi_range(1, 3)
	_skip_reserved()
	is_special_round = false
	_warned = false
	to_spawn = 0
	alive = 0
	state = State.BREAK
	break_left = 1.0
