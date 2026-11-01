extends Node
## Scrip ledger per player. Server-authoritative: only the authority calls award/spend.
## Co-op (M7): Scrip is per player and can't be transferred (GDD §5). On a client every write is a no-op;
## the totals come from the host's state snapshot and the floating numbers from relayed scrip_changed.

var _scrip: Dictionary = {}          # player_id -> int
var _repair_earned: Dictionary = {}  # player_id -> int, resets each round
var multiplier: int = 1              # Double Scrip sets this
## The in-match bonuses (T-078: round pay, clean rounds, headshot streaks, salvage), a child node.
var bonuses: ScripBonuses


func _ready() -> void:
	GLBus.round_started.connect(_on_round_started)
	bonuses = ScripBonuses.new()
	bonuses.name = "ScripBonuses"
	add_child(bonuses)


func reset(player_ids: Array[int]) -> void:
	var start: int = int(GLData.table("economy")["starting_scrip"])
	_scrip.clear()
	_repair_earned.clear()
	multiplier = 1
	for id: int in player_ids:
		_scrip[id] = start
		_repair_earned[id] = 0
		GLBus.scrip_changed.emit(id, start, 0)


## Whether `player` has a ledger this match (a player slot or a bot; not Jakub).
func has_account(player: int) -> bool:
	return _scrip.has(player)


func get_scrip(player: int) -> int:
	return int(_scrip.get(player, 0))


func can_afford(player: int, cost: int) -> bool:
	return get_scrip(player) >= cost


## T-141: Ledger Lager's earn multiplier for `player` (1.0 without the tonic; tier I pays 1.2). Read from
## PerkManager's effect key `scrip_earn_mult`, so it is per player and goes with the tonic when it is lost.
func earn_mult(player: int) -> float:
	return maxf(0.0, float(PerkManager.stat(player, "scrip_earn_mult", 1.0)))


## `amount` after the player's earn multiplier (pure for a given mult; rounded to the nearest whole Scrip, at least
## `amount` when the multiplier is 1 or more). Only positive amounts are scaled: a cut or a charge is never boosted.
static func boosted(amount: int, mult: float) -> int:
	if amount <= 0 or mult == 1.0:
		return amount
	return maxi(0, roundi(float(amount) * mult + 0.000001))


## Kill, hit, repair, revive and bonus pay: Double Scrip, then Ledger Lager's earn multiplier. Returns the amount paid.
func award(player: int, amount: int) -> int:
	if amount <= 0 or not Net.is_authority():
		return 0
	var delta: int = boosted(amount * multiplier, earn_mult(player))
	_scrip[player] = get_scrip(player) + delta
	GLBus.scrip_changed.emit(player, get_scrip(player), delta)
	return delta


## Quest, Easter-egg and bonus rewards: adds Scrip without the Double Scrip multiplier but WITH Ledger Lager's earn
## multiplier (T-141). A negative amount (a charge: the Account Manager's price cut) is taken as is. Returns the
## amount paid. Refunds and starting money use grant_raw.
func grant(player: int, amount: int) -> int:
	if not Net.is_authority():
		return 0
	var delta: int = boosted(amount, earn_mult(player)) if amount > 0 else amount
	_scrip[player] = get_scrip(player) + delta
	GLBus.scrip_changed.emit(player, get_scrip(player), delta)
	return delta


## Scrip that is moved, not earned (T-141): the crate's return when the drummer comes, the dev console, a match's
## starting kit. No Double Scrip and no earn multiplier. (Still counts as scrip_changed for the HUD.)
func grant_raw(player: int, amount: int) -> void:
	if not Net.is_authority():
		return
	_scrip[player] = get_scrip(player) + amount
	GLBus.scrip_changed.emit(player, get_scrip(player), amount)


## T-136: Scrip in or out of the savings bank (BankAccount): no earning and no purchase, so stats, challenges and
## power-up drops never count it (`moving` is true while scrip_changed is out).
var moving: bool = false

func bank_move(player: int, delta: int) -> void:
	if not Net.is_authority() or delta == 0:
		return
	_scrip[player] = maxi(0, get_scrip(player) + delta)
	moving = true
	GLBus.scrip_changed.emit(player, get_scrip(player), delta)
	moving = false


## T-141: the price `player` actually pays for something listed at `cost`: Ledger Lager III's `purchase_discount`
## takes that share off, the discount rounded down (the house keeps the odd Scrip). Every prompt shows this number.
func price_for(player: int, cost: int) -> int:
	return discounted(cost, float(PerkManager.stat(player, "purchase_discount", 0.0)))


static func discounted(cost: int, discount: float) -> int:
	if cost <= 0 or discount <= 0.0:
		return cost
	return maxi(0, cost - int(floor(float(cost) * clampf(discount, 0.0, 0.9) + 0.000001)))


## A price for a prompt: "855" or, when a discount applies, "855, was 950".
func price_text(player: int, cost: int) -> String:
	var p: int = price_for(player, cost)
	return str(p) if p == cost else "%d, was %d" % [p, cost]


func spend(player: int, item_id: StringName, list_cost: int) -> bool:
	if not Net.is_authority():
		return false
	var cost: int = price_for(player, list_cost)
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
