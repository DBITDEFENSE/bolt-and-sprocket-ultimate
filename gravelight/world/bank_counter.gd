class_name BankCounter
extends Interactable
## T-136: the teller's window (BankBranch): "Bank: N saved" opens the BankCard (deposit / withdraw).

var branch: BankBranch
var card: BankCard = null


func _ready() -> void:
	interact_size = Vector3(1.6, 1.8, 0.9)
	interact_offset = Vector3(0, 0.9, 0.3)
	super._ready()


func build_greybox() -> void:
	pass   # the counter is the branch's furniture


func get_prompt(p: Player) -> String:
	var why: String = BankAccount.closed_reason()
	if why == "classic":
		return "The bank is shut (Classic Rules)"
	return "Bank: ǂ %d saved, +1%% a round" % BankAccount.balance()


func can_interact(p: Player) -> bool:
	return p != null and not p.is_bot and not p.downed and card == null and BankAccount.closed_reason() == "" and p.is_local


## Online (T-138): the card opens on the player's own machine (their balance is in their own profile).
func net_local() -> bool:
	return true


func hold_time(_p: Player) -> float:
	return 0.25


func interact(p: Player) -> void:
	if not can_interact(p):
		if branch != null and BankAccount.closed_reason() != "":
			branch.say("BANK_CLOSED")
		return
	card = BankCard.new()
	card.player = p
	card.branch = branch
	get_tree().root.add_child(card)
	card.tree_exited.connect(func() -> void: card = null)
