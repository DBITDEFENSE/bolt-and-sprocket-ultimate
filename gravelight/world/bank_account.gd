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


## "" when the bank is open for business; else why not ("classic"). Online it is open (T-138): every player's
## balance is in their own profile; a client's Scrip moves on the host through Net._rpc_bank_req / _rpc_bank_state.
static func closed_reason() -> String:
	if bool(GLSettings.values.get("classic_rules", false)):
		return "classic"
	return ""


## The interest on `bal` for one round (pure): rounded down, at least `min_i` on any balance, never past `cap`.
static func interest_for(bal: int, rate: float, min_i: int, cap: int) -> int:
	if bal <= 0 or bal >= cap:
		return 0
	return mini(maxi(min_i, int(floor(float(bal) * rate + 0.000001))), cap - bal)


## T-141: the rate a round pays `pid`: the base rate plus Ledger Lager II's `bank_interest_bonus` (pid < 0: base only).
static func rate_for(pid: int) -> float:
	var base: float = float(cfg().get("interest_per_round", 0.01))
	if pid < 0:
		return base
	return base + maxf(0.0, float(PerkManager.stat(pid, "bank_interest_bonus", 0.0)))


## T-141: Ledger Lager IV's severance (pure): what a down pays out of a balance of `bal`.
static func severance_for(bal: int, pct: float, cap: int) -> int:
	if bal <= 0 or pct <= 0.0:
		return 0
	return mini(cap, maxi(1, int(floor(float(bal) * pct + 0.000001))))


## Pays `amount` (or as much as `pid` has) into the account; the amount moved.
static func deposit(pid: int, amount: int) -> int:
	if closed_reason() != "":
		return 0
	var room: int = int(cfg().get("max_balance", 1000000)) - balance()
	var n: int = mini(mini(amount, Economy.get_scrip(pid)), room)
	if n <= 0:
		return 0
	if Net.is_client():
		Net._rpc_bank_req.rpc_id(1, "deposit", n)   # the balance grows when the host confirms the Scrip left (on_host_reply)
		return n
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
	if Net.is_client():
		var rc: Dictionary = _rec()
		rc["balance"] = balance() - n   # taken out now (no double spend while the request travels); refunded if refused
		ProfileSave.save_profile()
		Net._rpc_bank_req.rpc_id(1, "withdraw", n)
		return n
	Economy.bank_move(pid, n)
	var r: Dictionary = _rec()
	r["balance"] = balance() - n
	r["withdrawn"] = int(r.get("withdrawn", 0)) + n
	ProfileSave.save_profile()
	return n


## A round's interest (BankLedger); the amount added. `pid` is the saver whose tonics raise the rate (Ledger Lager
## II adds 2%); -1 pays the base rate.
static func accrue(pid: int = -1) -> int:
	if closed_reason() != "":
		return 0
	var c: Dictionary = cfg()
	var i: int = interest_for(balance(), rate_for(pid), int(c.get("min_interest", 1)),
		int(c.get("max_balance", 1000000)))
	if i <= 0:
		return 0
	var r: Dictionary = _rec()
	r["balance"] = balance() + i
	r["interest"] = int(r.get("interest", 0)) + i
	ProfileSave.save_profile()
	return i


## Host (T-138): a client's deposit / withdrawal, the Scrip side only (its balance lives in its own profile).
## A deposit moves at most the Scrip the client has; a withdrawal can't be checked against a balance the host
## never sees, so it is capped at max_balance per request (the client already took it from its balance).
## Returns the amount moved.
static func host_move_for(pid: int, op: String, amount: int) -> int:
	if closed_reason() != "" or not Net.is_host() or GameState.phase != GameState.Phase.PLAYING:
		return 0
	var n: int = clampi(amount, 0, int(cfg().get("max_balance", 1000000)))
	match op:
		"deposit":
			n = mini(n, Economy.get_scrip(pid))
			if n > 0:
				Economy.bank_move(pid, -n)
			return maxi(0, n)
		"withdraw":
			if n > 0:
				Economy.bank_move(pid, n)
			return n
	return 0


## Client (T-138): the host's answer. A deposit lands in the balance; a refused (part of a) withdrawal goes back.
static func on_host_reply(op: String, asked: int, moved: int) -> void:
	var r: Dictionary = _rec()
	match op:
		"deposit":
			r["balance"] = balance() + maxi(0, moved)
			r["deposited"] = int(r.get("deposited", 0)) + maxi(0, moved)
		"withdraw":
			r["balance"] = balance() + maxi(0, asked - moved)
			r["withdrawn"] = int(r.get("withdrawn", 0)) + maxi(0, moved)
	ProfileSave.save_profile()


## T-141: Ledger Lager IV's severance: when `pid` goes down the bank pays `severance_pct` of the balance (capped at
## `severance_cap`) into their pocket on the spot, out of the account. Nothing is taken from the player. The amount paid.
static func pay_severance(pid: int) -> int:
	if closed_reason() != "" or not Net.is_authority():
		return 0
	var pct: float = float(PerkManager.stat(pid, "severance_pct", 0.0))
	var n: int = severance_for(balance(), pct, int(PerkManager.stat(pid, "severance_cap", 0)))
	if n <= 0:
		return 0
	var r: Dictionary = _rec()
	r["balance"] = balance() - n
	r["withdrawn"] = int(r.get("withdrawn", 0)) + n
	r["severance"] = int(r.get("severance", 0)) + n
	Economy.bank_move(pid, n)
	ProfileSave.save_profile()
	return n
