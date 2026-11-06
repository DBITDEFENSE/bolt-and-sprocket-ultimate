class_name BankLedger
extends Node
## T-136: the savings account's interest, on every map: at each round start the balance grows by 1%
## (BankAccount.accrue). The match's last round counts once; round 1 counts too (the round you start in).

var map: MapRoot
var last_interest: int = 0
var _paid_round: int = -1


func setup(m: MapRoot) -> void:
	map = m
	GLBus.round_started.connect(_on_round)


func _on_round(r: int, _special: bool) -> void:
	if r == _paid_round or GameState.phase != GameState.Phase.PLAYING:
		return
	_paid_round = r
	var saver: int = map.player.player_id if map != null and map.player != null else -1
	last_interest = BankAccount.accrue(saver)   # (T-141: Ledger Lager II adds 2% for the saver who holds it)
	BankAccount.accrue_bots()   # T-177: the squad's and the companions' own savings
	if last_interest > 0 and map != null and map.player != null:
		# a typed slip by the Scrip (amount 0: it is not in your pocket, it is in the bank)
		GLBus.bonus_awarded.emit(map.player.player_id, &"bank_interest", 0, "SAVINGS +%d  ·  %d IN THE BANK" % [last_interest, BankAccount.balance()])
