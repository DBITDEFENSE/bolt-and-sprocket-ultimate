extends Node
## Lost Requisition Crate logic (WEAPONS.md §10): weighted pool, exclusions, the gentle start (pity),
## dud breakers, wonder bad-luck protection, Herr Tamtam the drummer, and relocation.
## World presence lives in MysteryCrate nodes (group "crate_spots"); this autoload decides outcomes.

const DRUMMER: StringName = &"__drummer__"

var location_index: int = -1
var uses_at_location: int = 0
var uses_until_move: int = 8
var debug_next: StringName = &""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _players: Dictionary = {}   # player -> {pulls, c_streak, since_a, since_wonder}


func _ready() -> void:
	rng.randomize()
	GLBus.match_started.connect(func(_m: StringName) -> void: reset_match())


func cfg() -> Dictionary:
	return GLData.table("crate")


func reset_match() -> void:
	_players.clear()
	location_index = -1
	uses_at_location = 0
	debug_next = &""


## Picks the starting spot among spots flagged can_start. Called by the map once crate spots exist.
func choose_start(spots: Array) -> void:
	var starts: Array[int] = []
	for i: int in spots.size():
		if bool((spots[i] as Node).get("can_start")):
			starts.append(i)
	if starts.is_empty():
		starts.append(0)
	_arrive(starts[rng.randi_range(0, starts.size() - 1)])


func _arrive(index: int) -> void:
	location_index = index
	uses_at_location = 0
	uses_until_move = rng.randi_range(int(cfg()["drummer_after_uses_min"]), int(cfg()["drummer_after_uses_max"]))


func cost() -> int:
	if GameState.has_flag(&"clearance"):
		return int(GLData.table("economy")["clearance_crate_cost"])
	return int(cfg()["cost"])


func _stats(player: int) -> Dictionary:
	if not _players.has(player):
		_players[player] = {"pulls": 0, "c_streak": 0, "since_a": 0, "since_wonder": 0}
	return _players[player]


## Rolls one pull for a player. `held` = weapon ids the player holds (base or upgraded).
## Returns {"id": weapon id or DRUMMER, "tier": "A"/"B"/"C"/""}.
func roll(player: int, held: Array) -> Dictionary:
	var st: Dictionary = _stats(player)
	uses_at_location += 1
	var first_pull: bool = int(st["pulls"]) == 0
	var drummer_ok: bool = not first_pull and uses_at_location > int(cfg()["drummer_never_first_pulls_at_location"]) \
		and not GameState.has_flag(&"clearance")
	if debug_next == DRUMMER or (debug_next == &"" and drummer_ok and uses_at_location >= uses_until_move):
		debug_next = &""
		st["pulls"] = int(st["pulls"]) + 1
		return {"id": DRUMMER, "tier": ""}
	var result: Dictionary
	if debug_next != &"":
		result = {"id": debug_next, "tier": _tier_of(debug_next)}
		debug_next = &""
	else:
		result = pick(cfg()["pool"], held, allowed_tiers(st, cfg()), wonder_bonus(int(st["since_wonder"]), cfg()), rng.randf())
	_record(st, result)
	return result


func _record(st: Dictionary, result: Dictionary) -> void:
	st["pulls"] = int(st["pulls"]) + 1
	var tier: String = str(result["tier"])
	st["c_streak"] = int(st["c_streak"]) + 1 if tier == "C" else 0
	st["since_a"] = 0 if tier == "A" else int(st["since_a"]) + 1
	st["since_wonder"] = 0 if StringName(result["id"]) == &"ashlight" else int(st["since_wonder"]) + 1


func _tier_of(id: StringName) -> String:
	for e: Dictionary in cfg()["pool"]:
		if StringName(e["id"]) == id:
			return str(e["tier"])
	return "B"


## Which tiers this pull may come from (gentle start, dud breaker, A breaker). Empty = any.
static func allowed_tiers(st: Dictionary, c: Dictionary) -> PackedStringArray:
	if int(st["pulls"]) < int(c["pity_first_pulls"]):
		return PackedStringArray(c["pity_tiers"])
	if int(st["since_a"]) >= int(c["a_breaker_pulls"]):
		return PackedStringArray(["A"])
	if int(st["c_streak"]) >= int(c["dud_breaker_c_streak"]):
		return PackedStringArray(["A", "B"])
	return PackedStringArray()


## Extra Ashlight weight from bad-luck protection.
static func wonder_bonus(since_wonder: int, c: Dictionary) -> int:
	return floori(float(since_wonder) / float(c["wonder_bonus_every"]))


## Weighted pick. Pure: the caller supplies the random roll in [0, 1).
static func pick(pool: Array, held: Array, tiers: PackedStringArray, ashlight_bonus: int, roll_01: float) -> Dictionary:
	var held_bases: Dictionary = {}
	for h: Variant in held:
		held_bases[String(h).trim_suffix("_up")] = true
	var entries: Array = []
	var total: float = 0.0
	for e: Dictionary in pool:
		var id: String = str(e["id"])
		if held_bases.has(id):
			continue
		if not tiers.is_empty() and not tiers.has(str(e["tier"])):
			continue
		var w: float = float(e["weight"])
		if id == "ashlight":
			w = minf(w + float(ashlight_bonus), 9.0)
		entries.append([id, str(e["tier"]), w])
		total += w
	if entries.is_empty():
		return {"id": &"mp40", "tier": "C"}
	var r: float = roll_01 * total
	for en: Array in entries:
		r -= float(en[2])
		if r <= 0.0:
			return {"id": StringName(en[0]), "tier": en[1]}
	var last: Array = entries.back()
	return {"id": StringName(last[0]), "tier": last[1]}


## The drummer took the crate: pick a different spot.
func move(spot_count: int) -> void:
	if not Net.is_authority():
		return
	var next: int = location_index
	if spot_count > 1:
		while next == location_index:
			next = rng.randi_range(0, spot_count - 1)
	_arrive(next)
	GameState.set_flag(&"crate_has_moved", true)
	GLBus.crate_moved.emit(location_index)


func debug_move() -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group(&"crate_spots")
	if spots.is_empty():
		return
	move(spots.size())
	for n: Node in spots:
		n.call("refresh")
