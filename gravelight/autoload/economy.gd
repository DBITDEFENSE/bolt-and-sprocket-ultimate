extends Node
## Scrip ledger per player. Server-authoritative: only the authority calls award/spend.
## Co-op (M7): Scrip is per player and can't be transferred (GDD §5). On a client every write is a no-op;
## the totals come from the host's state snapshot and the floating numbers from relayed scrip_changed.

var _scrip: Dictionary = {}          # player_id -> int
var _repair_earned: Dictionary = {}  # player_id -> int, resets each round
var multiplier: int = 1              # Double Scrip sets this


func _ready() -> void:
	GLBus.round_started.connect(_on_round_started)


func reset(player_ids: Array[int]) -> void:
	var start: int = int(GLData.table("economy")["starting_scrip"])
	_scrip.clear()
	_repair_earned.clear()
	multiplier = 1
	for id: int in player_ids:
		_scrip[id] = start
		_repair_earned[id] = 0
		GLBus.scrip_changed.emit(id, start, 0)


func get_scrip(player: int) -> int:
	return int(_scrip.get(player, 0))


func can_afford(player: int, cost: int) -> bool:
	return get_scrip(player) >= cost


func award(player: int, amount: int) -> void:
	if amount <= 0 or not Net.is_authority():
		return
	var delta: int = amount * multiplier
	_scrip[player] = get_scrip(player) + delta
	GLBus.scrip_changed.emit(player, get_scrip(player), delta)


## Dev console / quest rewards: adds Scrip without the Double Scrip multiplier.
func grant(player: int, amount: int) -> void:
	if not Net.is_authority():
		return
	_scrip[player] = get_scrip(player) + amount
	GLBus.scrip_changed.emit(player, get_scrip(player), amount)


func spend(player: int, item_id: StringName, cost: int) -> bool:
	if not Net.is_authority():
		return false
	if not can_afford(player, cost):
		GLBus.purchase_denied.emit(player, item_id, &"no_scrip")
		return false
	_scrip[player] = get_scrip(player) - cost
	GLBus.scrip_changed.emit(player, get_scrip(player), -cost)
	GLBus.purchase_made.emit(player, item_id, cost)
	return true


## Awards a board repair, respecting the per-round cap.
func award_repair(player: int) -> void:
	if not Net.is_authority():
		return
	var cfg: Dictionary = GLData.table("economy")
	var amount: int = repair_value(int(_repair_earned.get(player, 0)), cfg)
	_repair_earned[player] = int(_repair_earned.get(player, 0)) + amount
	award(player, amount)


## Kill reward by hit zone. Pure, so it can be unit-tested.
static func kill_value(limb: StringName, is_melee: bool, cfg: Dictionary) -> int:
	var k: Dictionary = cfg["kill"]
	if is_melee:
		return int(k["melee"])
	match limb:
		&"head":
			return int(k["head"])
		&"neck":
			return int(k["neck"])
		_:
			return int(k["body"])


## Board repair reward, respecting the per-round cap. Returns the amount actually earned.
static func repair_value(already_earned_this_round: int, cfg: Dictionary) -> int:
	var cap: int = int(cfg["board_repair_cap_per_round"])
	return clampi(cap - already_earned_this_round, 0, int(cfg["board_repair"]))


func _on_round_started(_round: int, _special: bool) -> void:
	for id: Variant in _repair_earned.keys():
		_repair_earned[id] = 0
