class_name AgentPlan
extends RefCounted
## The player bot's game plan (T-071 pass 2): the order a skilled solo player spends in on a map, from
## data/gravelight/ai/player_bot.json "plans" (one list per map key, e.g. "map00"). Each step is one of
##   {"door": "<BuyDoor.door_id>"}            bought (open)
##   {"power": true}                           the map's power on
##   {"perk": "<perk id>"}                     drunk (lost on a down: it becomes the current step again)
##   {"gun": "<weapon id>", "or_tier": 3.6}    held (or any gun of that economy.json tier or better)
##   {"crucible": "<weapon id>"}               held upgraded (Crucible)
## A step may carry "from_round" (not before that round). The current step is the first one not done; the
## agent's economy (BotEconomy.candidates) then keeps only what that step needs, plus what keeps it alive
## anyway (ammo, an ammo box, the boards, the power switch). With every step done (or no plan for
## the map) the ordinary economy runs. "train_at" lists the map's loops the trainer prefers, best first
## (BotTrainer: plan_bonus on the loop score). The pure parts are unit-tested (test_player_bot.gd).

## The last unfiltered candidates' labels (the soak's --trace).
static var last_raw: PackedStringArray = PackedStringArray()

const ALWAYS: PackedStringArray = ["repair", "ammo", "ammo_box", "power"]


static func plan_for(map_key: String) -> Dictionary:
	var plans: Dictionary = (BotAIData.table("player_bot").get("plans", {}) as Dictionary)
	return plans.get(map_key, {}) as Dictionary


## Pure: is `step` done in state `st` {doors: {id: true}, power: bool, perks: [ids], guns: [{id, upgraded, tier}],
## round: int}?
static func step_done(step: Dictionary, st: Dictionary) -> bool:
	if step.has("door"):
		return (st.get("doors", {}) as Dictionary).has(str(step["door"]))
	if step.has("power"):
		return bool(st.get("power", false))
	if step.has("perk"):
		return (st.get("perks", []) as Array).has(str(step["perk"]))
	if step.has("gun"):
		for g: Variant in st.get("guns", []):
			var gd: Dictionary = g as Dictionary
			if str(gd.get("id", "")) == str(step["gun"]) or float(gd.get("tier", 0.0)) >= float(step.get("or_tier", INF)):
				return true
		return false
	if step.has("crucible"):
		for g2: Variant in st.get("guns", []):
			var gd2: Dictionary = g2 as Dictionary
			if bool(gd2.get("upgraded", false)) and (str(gd2.get("id", "")) == str(step["crucible"]) or str(step["crucible"]) == "*"):
				return true
		return false
	return true   # an unknown step never blocks the plan


## Pure: the first step not done (and due by its from_round), or {} when the plan is through.
static func current(steps: Array, st: Dictionary) -> Dictionary:
	for s: Variant in steps:
		var step: Dictionary = s as Dictionary
		if int(step.get("from_round", 0)) > int(st.get("round", 0)):
			return {}   # not yet: hold the Scrip (nothing later jumps the queue)
		if not step_done(step, st):
			return step
	return {}


## Pure: may the economy's candidate {kind, id} go ahead while `step` is the current one?
static func allows(step: Dictionary, kind: String, id: String) -> bool:
	if ALWAYS.has(kind):
		return true
	if step.is_empty():
		return true
	match kind:
		"door":
			return str(step.get("door", "")) == id
		"perk":
			return str(step.get("perk", "")) == id
		"gun":
			return str(step.get("gun", "")) == id
		"crucible":
			return step.has("crucible")
	return false


## The agent's state for the pure rules.
static func state_of(brain: BotBrain) -> Dictionary:
	var doors: Dictionary = {}
	for n: Node in brain.get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).is_open:
			doors[String((n as BuyDoor).door_id)] = true
	var perks: Array = []
	for p: Variant in PerkManager.owned(brain.player.player_id):
		perks.append(str(p))
	var guns: Array = []
	var eco: Dictionary = BotAIData.table("economy")
	for w: WeaponInstance in brain.player.weapons.slots:
		guns.append({"id": String(w.base_id()), "upgraded": w.upgraded, "tier": BotEconomy.tier_of(String(w.base_id()), w.upgraded, eco)})
	return {"doors": doors, "power": GameState.power_on, "perks": perks, "guns": guns, "round": RoundManager.current_round}


## The current step for this brain's map ({} = none / the plan is through).
static func current_for(brain: BotBrain) -> Dictionary:
	if brain.squad == null or brain.squad.map == null:
		return {}
	var plan: Dictionary = plan_for(TrainingRoute.map_key_of(String(brain.squad.map.map_id)))
	var steps: Array = plan.get("steps", [])
	if steps.is_empty():
		return {}
	return current(steps, state_of(brain))


## Pure (pass 3): the steps that may go ahead of the current one while it can't be done: of the next `n` undone
## steps after it (each due by its from_round): while the current step is unaffordable (its price over
## `spendable`), those cheaper than it; while it is affordable but has to wait (a perk in the cellar mid-round, a
## door the agent can't reach from here), any of them. `prices`: step index -> Scrip (a step with no known price
## never skips). A "firm" current step is never jumped. The current step stays first in line.
static func later_steps(steps: Array, st: Dictionary, n: int, prices: Dictionary, spendable: int = 0) -> Array:
	var out: Array = []
	var cur_i: int = -1
	var seen: int = 0
	for i: int in steps.size():
		var step: Dictionary = steps[i] as Dictionary
		if int(step.get("from_round", 0)) > int(st.get("round", 0)):
			break
		if step_done(step, st):
			continue
		if cur_i < 0:
			cur_i = i
			if bool(step.get("firm", false)):
				return out
			continue
		if seen >= n:
			break
		seen += 1
		if prices.has(i) and prices.has(cur_i) and (int(prices[i]) < int(prices[cur_i]) or int(prices[cur_i]) <= spendable):
			out.append(step)
	return out


## The price of a step on this map (-1: unknown / not on the map). Power: 0.
static func price_of(step: Dictionary, brain: BotBrain) -> int:
	if step.has("power"):
		return 0
	if step.has("perk"):
		return PerkManager.price(StringName(str(step["perk"]))) if not PerkManager.perk_data(StringName(str(step["perk"]))).is_empty() else -1
	if step.has("crucible"):
		return int(GLData.table("economy").get("crucible_upgrade", 5000))
	if step.has("door"):
		for n: Node in brain.get_tree().get_nodes_in_group(&"doors"):
			if n is BuyDoor and String((n as BuyDoor).door_id) == str(step["door"]):
				return (n as BuyDoor).cost
		return -1
	if step.has("gun") and brain.squad != null:
		for wb: WallBuy in brain.squad.wall_buys():
			if is_instance_valid(wb) and String(wb.weapon_id) == str(step["gun"]):
				return wb.price()
	return -1


## BotEconomy.candidates' last word for the player bot: only what the plan's current step needs (and ALWAYS).
## Pass 3: when the current step can't be done now (not affordable, or its errand waits for a break), the next
## few cheaper steps (plans.skip_ahead) may go ahead of it, so the agent never stands in a break holding Scrip it
## can't spend (the pass-2 traces: 1,500-3,000 Scrip in hand while the yard door it needed was filtered out behind
## a Second Wind rebuy in the cellar).
static func filter(cands: Array[Dictionary], brain: BotBrain) -> Array[Dictionary]:
	var step: Dictionary = current_for(brain)
	last_raw = PackedStringArray(cands.map(func(x: Dictionary) -> String: return str(x.get("label", ""))))
	if step.is_empty():
		return cands
	var out: Array[Dictionary] = _matching(cands, step)
	if _has_buy(out):
		return out
	# the ordinary rules didn't offer the step (a door's per-round limit, a gun its tier table skips, range): the
	# plan's own errand, when the Scrip is there
	var quiet: bool = brain.in_break() or brain.perception.nearest_d >= 14.0
	if quiet:   # (its own errands wait for the break, or for a quiet moment: no walking off through a round)
		var own: Dictionary = errand_for(step, brain)
		if not own.is_empty():
			out.append(own)
			return out
	# pass 3: the current step can't be done now: a cheaper later step may
	var steps: Array = plan_for(TrainingRoute.map_key_of(String(brain.squad.map.map_id))).get("steps", [])
	var n: int = int(plan_for(TrainingRoute.map_key_of(String(brain.squad.map.map_id))).get("skip_ahead",
			(BotAIData.table("player_bot").get("plans", {}) as Dictionary).get("skip_ahead", 0)))
	if n <= 0:
		return out
	var prices: Dictionary = {}
	for i: int in steps.size():
		var pr: int = price_of(steps[i] as Dictionary, brain)
		if pr >= 0:
			prices[i] = pr
	var keep: int = int((BotAIData.table("economy").get("reserve", {}) as Dictionary).get("min_scrip", 300))
	for later: Variant in later_steps(steps, state_of(brain), n, prices, Economy.get_scrip(brain.player.player_id) - keep):
		var ls: Dictionary = later as Dictionary
		var more: Array[Dictionary] = _matching(cands, ls)
		if _has_buy(more):
			for m: Dictionary in more:
				if not ALWAYS.has(str(m.get("kind", ""))):
					out.append(m)
			return out
		if quiet:
			var own2: Dictionary = errand_for(ls, brain)
			if not own2.is_empty():
				out.append(own2)
				return out
	return out


static func _matching(cands: Array[Dictionary], step: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cnd: Dictionary in cands:
		var node: Variant = cnd.get("node")
		var id: String = ""
		if node is BuyDoor:
			id = String((node as BuyDoor).door_id)
		elif node is PerkMachine:
			id = String((node as PerkMachine).perk_id)
		elif node is WallBuy:
			id = String((node as WallBuy).weapon_id)
		if allows(step, str(cnd.get("kind", "")), id):
			out.append(cnd)
	return out


static func _has_buy(cands: Array[Dictionary]) -> bool:
	for c: Dictionary in cands:
		if not ALWAYS.has(str(c.get("kind", ""))):
			return true
	return false


## The economy candidate for a door / perk / gun step, or {} (not affordable, not reachable, not on the map).
static func errand_for(step: Dictionary, brain: BotBrain) -> Dictionary:
	var pid: int = brain.player.player_id
	var scrip: int = Economy.get_scrip(pid)
	var keep: int = int((BotAIData.table("economy").get("reserve", {}) as Dictionary).get("min_scrip", 300))
	var me: Vector3 = brain.player.global_position
	var tree: SceneTree = brain.get_tree()
	if step.has("door"):
		for n: Node in tree.get_nodes_in_group(&"doors"):
			var d: BuyDoor = n as BuyDoor
			if d == null or d.is_open or String(d.door_id) != str(step["door"]) or not d.can_interact(brain.player):
				continue
			if scrip < d.cost + keep or not brain.squad.can_claim(d, pid) or not brain.reachable(BotBrain._door_side(d, me)):
				continue
			return {"node": d, "kind": "door", "value": 0.9, "cost": d.cost, "label": "open the %s (%d Scrip) (the plan)" % [BotBrain.door_label(d), d.cost]}
	elif step.has("perk"):
		for n2: Node in tree.get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n2 as PerkMachine
			if pm == null or String(pm.perk_id) != str(step["perk"]) or not pm.can_interact(brain.player) or not pm.is_powered():
				continue
			var price: int = PerkManager.price(pm.perk_id)
			if scrip < price + keep or not brain.squad.can_claim(pm, pid) or not brain.reachable(BotBrain._front_of(pm)):
				continue
			return {"node": pm, "kind": "perk", "value": 0.9, "cost": price, "label": "drink %s (%d Scrip) (the plan)" % [PerkManager.display_name(pm.perk_id), price]}
	elif step.has("gun"):
		for wb: WallBuy in brain.squad.wall_buys():
			if not is_instance_valid(wb) or String(wb.weapon_id) != str(step["gun"]) or not wb.is_visible_in_tree():
				continue
			if scrip < wb.price() + keep or not brain.squad.can_claim(wb, pid) or not brain.reachable(BotBrain._front_of(wb)):
				continue
			return {"node": wb, "kind": "gun", "value": 0.9, "cost": wb.price(), "label": "buy the %s wall gun (%d Scrip) (the plan)" % [BotBrain.weapon_name(wb.weapon_id), wb.price()]}
	return {}


## The trainer's bonus for a loop: plan_bonus for the plan's first open choice, less for the later ones.
static func loop_bonus(map_key: String, route_id: String, bonus: float) -> float:
	var order: Array = plan_for(map_key).get("train_at", [])
	var i: int = order.find(route_id)
	return 0.0 if i < 0 else bonus / float(i + 1)
