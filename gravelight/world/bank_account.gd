class_name BankAccount
extends RefCounted
## T-136: the savings account (data/gravelight/bank.json). The balance lives in the profile (ProfileSave.profile
## "bank": {"balance", "deposited", "withdrawn", "interest"}), so it is there in every later match. Deposits and
## withdrawals move Scrip with Economy.bank_move (never counted as earnings); interest is added by BankLedger at
## each round start.


static func cfg() -> Dictionary:
	return GLData.table("bank")


static func _rec() -> Dictionary:
	var pr: Dictionary = ProfileSave.profile
	if not pr.has("bank") or not (pr["bank"] is Dictionary):
		pr["bank"] = {"balance": 0, "deposited": 0, "withdrawn": 0, "interest": 0}
	return pr["bank"]


static func balance() -> int:
	return int(_rec().get("balance", 0))


## "" when the bank is open for business; else why not ("classic", "online").
static func closed_reason() -> String:
	if bool(GLSettings.values.get("classic_rules", false)):
		return "classic"
	if Net.is_online():
		return "online"
	return ""


## The interest on `bal` for one round (pure): rounded down, at least `min_i` on any balance, never past `cap`.
static func interest_for(bal: int, rate: float, min_i: int, cap: int) -> int:
	if bal <= 0 or bal >= cap:
		return 0
	return mini(maxi(min_i, int(floor(float(bal) * rate))), cap - bal)


## Pays `amount` (or as much as `pid` has) into the account; the amount moved.
static func deposit(pid: int, amount: int) -> int:
	if closed_reason() != "":
		return 0
	var room: int = int(cfg().get("max_balance", 1000000)) - balance()
	var n: int = mini(mini(amount, Economy.get_scrip(pid)), room)
	if n <= 0:
		return 0
	Economy.bank_move(pid, -n)
	var r: Dictionary = _rec()
	r["balance"] = balance() + n
	r["deposited"] = int(r.get("deposited", 0)) + n
	ProfileSave.save_profile()
	return n


## Takes `amount` (or the whole balance if less) out to `pid`'s Scrip; the amount moved.
static func withdraw(pid: int, amount: int) -> int:
	if closed_reason() != "":
		return 0
	var n: int = mini(amount, balance())
	if n <= 0:
		return 0
	Economy.bank_move(pid, n)
	var r: Dictionary = _rec()
	r["balance"] = balance() - n
	r["withdrawn"] = int(r.get("withdrawn", 0)) + n
	ProfileSave.save_profile()
	return n


## A round's interest (BankLedger); the amount added.
static func accrue() -> int:
	if closed_reason() != "":
		return 0
	var c: Dictionary = cfg()
	var i: int = interest_for(balance(), float(c.get("interest_per_round", 0.01)), int(c.get("min_interest", 1)),
		int(c.get("max_balance", 1000000)))
	if i <= 0:
		return 0
	var r: Dictionary = _rec()
	r["balance"] = balance() + i
	r["interest"] = int(r.get("interest", 0)) + i
	ProfileSave.save_profile()
	return i
