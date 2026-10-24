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
## anyway (ammo, an ammo box, upgraded ammo, the boards, the power switch). With every step done (or no plan for
## the map) the ordinary economy runs. "train_at" lists the map's loops the trainer prefers, best first
## (BotTrainer: plan_bonus on the loop score). The pure parts are unit-tested (test_player_bot.gd).

const ALWAYS: PackedStringArray = ["repair", "ammo", "ammo_box", "crucible_ammo", "power"]


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


## BotEconomy.candidates' last word for the player bot: only what the plan's current step needs (and ALWAYS).
static func filter(cands: Array[Dictionary], brain: BotBrain) -> Array[Dictionary]:
	var step: Dictionary = current_for(brain)
	if step.is_empty():
		return cands
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


## The trainer's bonus for a loop: plan_bonus for the plan's first open choice, less for the later ones.
static func loop_bonus(map_key: String, route_id: String, bonus: float) -> float:
	var order: Array = plan_for(map_key).get("train_at", [])
	var i: int = order.find(route_id)
	return 0.0 if i < 0 else bonus / float(i + 1)
