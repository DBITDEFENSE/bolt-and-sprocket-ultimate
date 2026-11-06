class_name BotEconomy
extends RefCounted
## A bot's spending brain (Update 03 section 6). Each bot spends its own Scrip by priority (data/gravelight/ai/
## economy.json): perks in plan order (Ironhide first, Second Wind in co-op, then Trigger Tonic or Twin Barrel by
## the main gun's class), a wall gun good for the round (never a Kar98k after round 10), an ammo box when the
## main gun's reserve runs under a quarter, doors only when ordered / the human opened that way / no human leads,
## the Requisition Crate with Scrip to spare and a gun weak for the round, the Crucible for a gun worth it. It
## always keeps a reserve (one revive-critical perk rebuy and one ammo box, x the personality's save_bias).
## Never: easter-egg objects, traps, the power switch (unless ordered, or the human already did that step), a
## teammate's crate roll or Crucible weapon. The pure rules are static and unit-tested (test_bot_brain.gd);
## candidates() turns them into errands on the map: {node, kind, value 0..1, label, cost, slot?}.

var brain: BotBrain
var player: Player
var eco: Dictionary = {}
var _cache_t: float = -10.0
var _cache: Dictionary = {}
var _power_t: float = -10.0
var _power: Dictionary = {}
## Doors the human opened this match (BotSquad keeps the count; read here).
var crate_pulls_this_round: int = 0
var bank_visits_round: int = 0   # T-177


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player
	eco = BotAIData.table("economy")


# ================================================================== pure rules

## The want tier for a round (economy.json want_tier_by_round: [[round, tier], ...], stepwise).
static func want_tier(round_n: int, table: Array) -> float:
	var t: float = 0.0
	for row: Variant in table:
		if round_n >= int((row as Array)[0]):
			t = float((row as Array)[1])
	return t


## A weapon's tier (economy.json weapon_tiers, + upgraded_tier_bonus for a Crucible gun, + reteach_tier_bonus for
## each teaching after the first: `crucible_tier` is WeaponInstance.tier, 1..3).
static func tier_of(base_id: String, upgraded: bool, e: Dictionary, crucible_tier: int = 1) -> float:
	var t: float = float((e.get("weapon_tiers", {}) as Dictionary).get(base_id, 2.0))
	if not upgraded:
		return t
	return t + float(e.get("upgraded_tier_bonus", 1.5)) + float(e.get("reteach_tier_bonus", 0.6)) * float(maxi(0, crucible_tier - 1))


## T-121: the Scrip a bot holds back for the Crucible's next teaching of a gun it has already taught (its best one):
## the teaching's price while `taught_tier` (1 or 2) is under `max_tier`, from crucible.min_round, when a powered
## Crucible is on the map and the gun is good enough (crucible.min_tier); else 0. The crate and the wall guns
## must leave this much (plus the reserve), so the 7500 / 10000 re-teach is saved for, not spent on rolls.
static func reteach_save(e: Dictionary, base_tier: float, upgraded: bool, taught_tier: int, max_tier: int, round_n: int,
		crucible_on_map: bool, price: int) -> int:
	var c: Dictionary = e.get("crucible", {})
	if not crucible_on_map or not upgraded or taught_tier >= max_tier or not bool(c.get("save_for_reteach", true)):
		return 0
	if round_n < int(c.get("min_round", 5)) or base_tier < float(c.get("min_tier", 3.4)):
		return 0
	return price


## Allowed to buy this gun in this round? (weapon_max_round: no Kar98k after round 10.)
static func gun_allowed(base_id: String, round_n: int, e: Dictionary) -> bool:
	var mr: Dictionary = e.get("weapon_max_round", {})
	return not mr.has(base_id) or round_n <= int(mr[base_id])


## Scrip it never spends below: the reserve perk's price (one rebuy) + an ammo box, x save_bias, at least min_scrip.
static func reserve_scrip(e: Dictionary, perk_price: int, box_price: int, save_bias: float) -> int:
	var r: Dictionary = e.get("reserve", {})
	var n: float = float(perk_price) + (float(box_price) if bool(r.get("ammo_box", true)) else 0.0)
	return int(maxf(float(r.get("min_scrip", 300)), n * maxf(0.0, save_bias)))


## The next perk to drink: the first in perk_plan not owned whose machine sells to it (`available`: perk id ->
## price, powered machines only), affordable above `reserve`, with room under the cap. "@weapon" resolves to
## Trigger Tonic or Twin Barrel by the main gun's class (weapon_perk). Second Wind only in co-op.
static func perk_wanted(e: Dictionary, plan: Array, owned: Array, available: Dictionary, main_class: String, coop: bool, cap_left: int, scrip: int, reserve: int) -> StringName:
	if cap_left <= 0:
		return &""
	for p: Variant in plan:
		var pid: String = str(p)
		if pid == "@weapon":
			pid = ""
			var wp: Dictionary = e.get("weapon_perk", {})
			for k: Variant in wp.keys():
				if (wp[k] as Array).has(main_class):
					pid = str(k)
			if pid == "":
				continue
		if owned.has(pid) or owned.has(StringName(pid)):
			continue
		if pid == "second_wind" and bool(e.get("second_wind_coop_only", true)) and not coop:
			continue
		if not available.has(pid):
			continue
		if scrip - int(available[pid]) < reserve:
			return &""   # the next perk in the plan is the one it saves for: don't skip ahead to a cheaper one
		return StringName(pid)
	return &""


## The next perk upgrade to brew (T-075, economy.json "perk_upgrades"): only when `nothing_new` (no base perk left to
## buy: cap full, or the plan is drunk), from min_round (tier 3 from tier3_min_round), in the upgrade plan's order
## ("@weapon" as in perk_plan), the first carried tonic whose next tier the machine offers (`available`: perk id ->
## that tier's price; `tiers`: perk id -> current tier) and that it can pay above reserve + extra_reserve. Like
## perk_wanted, an unaffordable first choice means saving for it, not skipping to a cheaper one.
static func upgrade_wanted(e: Dictionary, tiers: Dictionary, available: Dictionary, main_class: String, round_n: int,
		scrip: int, reserve: int, nothing_new: bool) -> StringName:
	var u: Dictionary = e.get("perk_upgrades", {})
	if u.is_empty() or not nothing_new or round_n < int(u.get("min_round", 10)):
		return &""
	var plan: Array = u.get("plan", e.get("perk_plan", []))
	for p: Variant in plan:
		var pid: String = str(p)
		if pid == "@weapon":
			pid = ""
			var wp: Dictionary = e.get("weapon_perk", {})
			for k: Variant in wp.keys():
				if (wp[k] as Array).has(main_class):
					pid = str(k)
		if pid == "" or not available.has(pid):
			continue
		if int(tiers.get(pid, 1)) + 1 >= 3 and round_n < int(u.get("tier3_min_round", 18)):
			continue
		if scrip - int(available[pid]) < reserve + int(u.get("extra_reserve", 500)):
			return &""
		return StringName(pid)
	return &""


## The wall gun to buy: the best tier on offer that is better than the best gun carried (tier + 0.2, and not cheaper
## on the wall than it), allowed in this round, affordable above reserve + the buffer. `held` = [{id, tier, q (its
## wall price; 1500 crate-only, 5000 upgraded)}], `walls` = id -> price, `classes` = id -> class, `prefer` = class
## multipliers (personality). Returns &"" for nothing.
static func gun_wanted(e: Dictionary, held: Array, walls: Dictionary, classes: Dictionary, prefer: Dictionary, round_n: int, scrip: int, reserve: int, _free_slot: bool) -> StringName:
	var best_held: float = 0.0
	var best_q: int = 0
	for h: Variant in held:
		best_held = maxf(best_held, float((h as Dictionary)["tier"]))
		best_q = maxi(best_q, int((h as Dictionary).get("q", 0)))
	var pick: StringName = &""
	var pick_v: float = 0.0
	for wid: Variant in walls.keys():
		var id: String = str(wid)
		if not gun_allowed(id, round_n, e):
			continue
		var held_ids: Array = held.map(func(h: Variant) -> String: return str((h as Dictionary)["id"]))
		if held_ids.has(id):
			continue
		var t: float = tier_of(id, false, e)
		var v: float = t * float(prefer.get(str(classes.get(id, "")), 1.0))
		# only a gun better than the best one carried (by tier and by its wall price: what the soak's waste rule
		# measures), so nothing bought is dropped or left unused
		if t <= best_held + 0.2 or int(walls[wid]) < best_q:
			continue
		if scrip - int(walls[wid]) - int(e.get("gun_buffer_scrip", 150)) < reserve:
			continue
		if v > pick_v:
			pick_v = v
			pick = StringName(id)
	return pick


## Worth a Requisition Crate pull: Scrip over crate.min_scrip and the best gun carried weak for the round.
static func crate_wanted(e: Dictionary, scrip: int, cost: int, best_tier: float, round_n: int, reserve: int) -> bool:
	var c: Dictionary = e.get("crate", {})
	if scrip < int(c.get("min_scrip", 2500)) or scrip - cost < reserve:
		return false
	if scrip >= int(c.get("rich_scrip", 6000)) and best_tier < float(c.get("rich_until_tier", 5.5)):
		return true   # Scrip to burn and no wonder weapon yet: try the crate
	return best_tier < want_tier(round_n, e.get("want_tier_by_round", [])) + float(c.get("weak_margin", 0.4))


## May a bot buy this door? Ordered; or nobody human leads (bot_led); or the human opened a door already and
## stands within near_human_m of this one (they're heading that way).
static func door_allowed(e: Dictionary, ordered: bool, bot_led: bool, human_opened: int, human_dist: float) -> bool:
	if ordered:
		return true
	var d: Dictionary = e.get("doors", {})
	if bot_led:
		return bool(d.get("bot_led", true))
	if bool(d.get("human_opened_needed", true)) and human_opened <= 0:
		return false
	return human_dist <= float(d.get("near_human_m", 9.0))


## U10 review fix: a door on the way to the main egg's open steps (BotEE.route_doors, a Full Partner shopping
## break): bought without the near-the-human rule (the egg is far from the player), but never before the human opened
## a door of their own (human_opened_needed: the first pick is theirs) unless no human is in the match.
static func egg_door_allowed(e: Dictionary, bot_led: bool, human_opened: int) -> bool:
	var d: Dictionary = e.get("doors", {})
	if bot_led:
		return bool(d.get("bot_led", true))
	return not bool(d.get("human_opened_needed", true)) or human_opened > 0


## The never-touch rule: easter-egg objects ("quest"), traps ("trap"), the power switch ("power") and buildable
## parts ("part") only when ordered onto that object, or (traps) when the human already used that one, or for the
## local-AI planner bot (the user-sanctioned exception) when its setting is on. `self_led` (T-058): no human is in
## the match (BotSquad.bots_alone()), so the squad is its own leader and throws the power itself (the rule
## protects a human's choices; with no human there is nobody to take the step from). Traps too, when the caller
## passes bots_alone (U10 T-163: the Kranich's bay doors). Easter eggs and parts stay off limits even then.
static func may_touch(kind: String, ordered: bool, planner: bool, human_did: bool, self_led: bool = false) -> bool:
	match kind:
		"quest", "part":
			return ordered or planner
		"power":
			return ordered or planner or self_led
		"trap":
			# U10 (T-163, Q-19): with nobody human in the match (bots_alone) a trap is nobody's choice to protect
			return ordered or planner or human_did or self_led
	return true


## Self-led (T-058): may a squad leading itself buy this door? Only doors it has a use for: the one on the way to
## the power switch (while the power is off), or one an authored training route needs (`route_door`). While the
## power door is still to be bought (`saving_for` its price, 0 = not saving), any other door must leave that much
## (plus the reserve) in hand, so the Scrip goes to the power first.
static func self_led_door_ok(is_power_door: bool, route_door: bool, scrip: int, cost: int, saving_for: int, reserve: int) -> bool:
	if is_power_door:
		return true
	if not route_door:
		return false
	return scrip - cost - saving_for >= reserve


## value_of with the personality's economy.priority_mult for that kind (T-071: the player bot wants a real gun
## before the power's door).
func _pv(kind: String, dist: float) -> float:
	var m: Dictionary = brain.personality_economy("priority_mult", {}) as Dictionary
	return clampf(value_of(eco, kind, dist) * float(m.get(kind, 1.0)), 0.0, 1.0)


## U10 (T-163) pure: take a free wonder from a bench? Its tier must beat the worst gun held by wonder_margin (or a
## slot is free).
static func wonder_wanted(wonder_tier: float, worst_held: float, free_slot: bool, e: Dictionary) -> bool:
	if free_slot:
		return true
	return wonder_tier > worst_held + float(e.get("wonder_margin", 0.5))


## The value (0..1) of a shopping candidate: its priority, a little less the farther it is.
static func value_of(e: Dictionary, kind: String, dist: float) -> float:
	var p: float = float((e.get("priorities", {}) as Dictionary).get(kind, 0.5))
	return clampf(p * (1.0 - clampf(dist / 60.0, 0.0, 0.35)), 0.0, 1.0)


# ================================================================== on the map

## Where shopping ranges are measured from and how far: the leader (or the hold spot), economy.json ranges.
func anchor() -> Vector3:
	if ee_shopping():
		return player.global_position   # U10 T-172: an egg bot's shopping break shops where the bot is
	var leader: Player = brain.squad.leader_for(brain)
	if brain.order_id() == &"hold" and brain.squad.hold_point != Vector3.INF:
		return brain.squad.hold_point
	return leader.global_position if leader != null else player.global_position


func range_m() -> float:
	var r: float = float(eco.get("max_range_from_leader_m", 26.0))
	if brain.squad.bot_led():
		r = float(eco.get("bot_led_range_m", 60.0))
	if ee_shopping():
		r = maxf(r, float((BotEECatalog.cfg().get("shop_break", {}) as Dictionary).get("range_m", 60.0)))
	return r


## U10 T-172: on an egg shopping break (BotEE.shopping: the task paused to shop, or between two steps)?
func ee_shopping() -> bool:
	return brain.ee != null and brain.ee.shopping()


## U10 T-172 pure: the perk plan with `first` moved to the front (a shopping break drinks the armour, revive and
## speed tonics before the rest), keeping the plan's own order otherwise.
static func plan_with_first(plan: Array, first: Array) -> Array:
	if first.is_empty():
		return plan
	var out: Array = []
	for f: Variant in first:
		if plan.has(f) or plan.has(str(f)):
			out.append(str(f))
	for p: Variant in plan:
		if not out.has(str(p)):
			out.append(p)
	return out


## U10 T-172 pure (ee.json egg_gun): may the egg's designated bot feed its gun to the Crucible now? It is the
## designated one, the gun can learn, it holds the price + reserve; no min round, no min tier.
static func egg_gun_ok(is_designated: bool, can_upgrade: bool, scrip: int, cost: int, reserve: int) -> bool:
	return is_designated and can_upgrade and scrip >= cost + reserve


## The best repair, buy and crate candidates (cached for a second): {"repair": {}, "buy": {}, "crate": {}, "all": []}.
func best(now: float) -> Dictionary:
	if now - _cache_t < 1.0 and not _cache.is_empty():
		var ok: bool = true
		for k: String in ["repair", "buy", "crate", "resupply"]:
			var c: Dictionary = _cache.get(k, {})
			if not c.is_empty() and not is_instance_valid(c.get("node")):
				ok = false
		if ok:
			return _cache
	_cache_t = now
	var all: Array[Dictionary] = candidates(anchor(), 1.0)
	var out: Dictionary = {"repair": {}, "buy": {}, "crate": {}, "resupply": {}, "all": all}
	for c2: Dictionary in all:
		var k: String = str(c2["kind"])
		var slot: String = "repair" if k == "repair" else ("crate" if k == "crate" else ("resupply" if k == "ammo_box" or k == "ammo" else "buy"))
		if (out[slot] as Dictionary).is_empty() or float(c2["value"]) > float((out[slot] as Dictionary)["value"]):
			out[slot] = c2
	_cache = out
	return out


func invalidate() -> void:
	_cache_t = -10.0


## Every errand the rules allow right now, valued. `range_mult` widens the ranges (the planner bot roams).
func candidates(anc: Vector3, range_mult: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me: Vector3 = player.global_position
	var squad: BotSquad = brain.squad
	var pid: int = player.player_id
	var now: float = squad.time()
	var scrip: int = Economy.get_scrip(pid)
	var rnd: int = RoundManager.current_round
	var order: StringName = brain.order_id()
	var save: bool = order == &"save_scrip"
	var perks_only: bool = order == &"buy_perks"
	var cfg: Dictionary = BotConfig.cfg()
	var rcfg: Dictionary = cfg.get("repair", {})
	var ccmd: Dictionary = cfg.get("commands", {})
	var rng: float = range_m() * range_mult
	# ---- boards
	var board_r: float = float(rcfg.get("radius_m", 9.0)) * minf(range_mult, 2.0)
	var board_lead: float = float(rcfg.get("max_from_leader_m", 14.0)) * range_mult
	var builder: bool = str(squad.blackboard.roles.get(pid, "")) == "builder"
	if order == &"repair":
		board_r = maxf(board_r, float(ccmd.get("repair_range_m", 30.0)))
		board_lead = maxf(board_lead, float(ccmd.get("repair_range_m", 30.0)))
	elif order == &"hold":
		board_r = float(ccmd.get("hold_repair_radius_m", 8.0))
		board_lead = board_r
	elif brain.in_break():
		board_r *= float(rcfg.get("break_radius_mult", 1.6)) * (1.4 if builder else 1.0)
	var best_board: Dictionary = {}
	# While the squad hunts a stalled round's last zombie, no boards go up unless ordered: that zombie may be the
	# one tearing at a window, and rebuilding it keeps it outside forever (a bots3 soak stalled two hours on round 2).
	var hunting: bool = squad.hunt_point() != Vector3.INF and order != &"repair"
	for n: Node in ([] if hunting else brain.get_tree().get_nodes_in_group(&"barricades")):
		var b: Barricade = n as Barricade
		if b == null or b.boards >= b.max_boards:
			continue
		var d: float = _flat(b.global_position, me)
		if d > board_r or _flat(b.global_position, anc) > board_lead:
			continue
		var key: String = "repair:%d" % b.get_instance_id()
		var front: Vector3 = BotBrain._front_of(b)
		if not squad.blackboard.can_claim(key, pid, now) or brain.in_danger(front) or not brain.reachable(front):
			continue
		var missing: float = float(b.max_boards - b.boards) / float(maxi(1, b.max_boards))
		var v: float = clampf(0.35 + 0.5 * missing - d / 40.0, 0.05, 1.0)
		if best_board.is_empty() or v > float(best_board["value"]):
			best_board = {"node": b, "kind": "repair", "value": v, "key": key, "label": "rebuild the boards at a window %d m away" % int(d)}
	if not best_board.is_empty():
		out.append(best_board)
	var shopping: bool = bool(brain.options.get("shopping", true))
	if player.is_companion and not brain.in_break():
		shopping = false   # T-177: a companion shops between rounds only (mid-round it covers the one it follows)
	if save:
		return out
	var econ: Dictionary = GLData.table("economy")
	# ---- the main gun and the reserve
	var main: WeaponInstance = _main_gun()
	var main_cls: String = String(main.weapon_class()) if main != null else "pistol"
	var box_price: int = AmmoBox.price_for(main.data, main.upgraded, AmmoBox.cfg()) if main != null else 250
	var res_perk: String = str((eco.get("reserve", {}) as Dictionary).get("perk", "second_wind"))
	var reserve: int = reserve_scrip(eco, PerkManager.price(StringName(res_perk)) if not PerkManager.perk_data(StringName(res_perk)).is_empty() else 500,
		box_price, float(brain.personality_economy("save_bias", 1.0)))
	if brain.is_player_bot and (not GameState.power_on or not AgentPlan.current_for(brain).is_empty()):
		reserve = int((eco.get("reserve", {}) as Dictionary).get("min_scrip", 300))   # T-071: no perk to rebuy before the power (the gun comes first)
	if brain.ee != null:
		reserve += brain.ee.door_reserve()   # T-153: saving for the door an egg task is waiting on
	# U10 T-172 (ee.json egg_gun): the egg needs a Crucible gun and this bot is the one to teach it: once it has its
	# first two tonics, everything but ammo leaves the teaching's price in hand
	var egg_gun: bool = brain.ee != null and brain.ee.hub != null and brain.ee.hub.egg_gun_pid() == pid
	var egg_save: int = Crucible.price_for(&"upgrade", GLData.table("economy"), 0) if egg_gun else 0
	# ---- an ammo box (or wall ammo) when the main gun runs low: ammo is never held back by the reserve
	var box_c: Dictionary = _ammo_candidate(anc, rng, scrip)
	if not box_c.is_empty():
		out.append(box_c)
		# a nearly dry main gun's refill comes first: hold its price back from every other purchase (a bot with an
		# empty taught Thompson rolled the crate for 950 and could no longer afford the 2500 refill)
		if float(box_c.get("value", 0.0)) >= 1.0:
			reserve += int(box_c.get("cost", 0))
	if not shopping or order == &"revive":
		return out
	# ---- the power (T-058): bots alone (no human in the match) open the way to the power switch and throw it;
	# with a human in the match it waits for them (or an order), even while they sit out a round bled out. Other
	# doors wait for the power door. (Doors and range follow bot_led(): nobody human leading right now.)
	var pw: Dictionary = eco.get("power", {})
	var power_door: BuyDoor = null
	var saving_for: int = 0
	var self_led: bool = squad.bot_led()
	if squad.bots_alone() and not GameState.power_on and may_touch("power", false, false, false, true) and rnd >= int(pw.get("min_round", 2)):
		var plan_p: Dictionary = power_plan(now)
		if plan_p.has("switch"):
			var sw: Node3D = plan_p["switch"]
			if squad.can_claim(sw, pid) and _near_enough(sw.global_position):
				out.append({"node": sw, "kind": "power", "stand": plan_p["stand"], "value": _pv("power", _flat(sw.global_position, me)),
					"cost": 0, "label": "throw the power switch (nobody else will)"})
		elif plan_p.has("door"):
			power_door = plan_p["door"]
			saving_for = power_door.cost
	# ---- perks
	if bool(brain.options.get("perks", true)) and rnd >= int(eco.get("perk_min_round", 2)):
		var avail: Dictionary = {}
		var machines: Dictionary = {}
		for n3: Node in brain.get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n3 as PerkMachine
			if pm == null or not pm.can_interact(player) or not pm.is_powered() or _flat(pm.global_position, anc) > rng * 1.3 or not _near_enough(pm.global_position):
				continue
			if not squad.can_claim(pm, pid):
				continue   # a teammate is at that machine
			if not brain.reachable(BotBrain._front_of(pm)):
				continue
			avail[String(pm.perk_id)] = PerkManager.price(pm.perk_id)
			machines[String(pm.perk_id)] = pm
		var plan: Array = brain.personality_economy("perk_order", [])
		if plan.is_empty():
			plan = eco.get("perk_plan", [])
		if ee_shopping():
			plan = plan_with_first(plan, (BotEECatalog.cfg().get("shop_break", {}) as Dictionary).get("perk_first", []))
		var cap_left: int = PerkManager.cap_for(pid) - PerkManager.capped_count(pid)
		var coop: bool = not GameState.is_solo() or brain.is_player_bot   # T-071: the human's own Second Wind is a solo self-revive
		var perk_keep: int = reserve + (egg_save if PerkManager.owned(pid).size() >= 2 else 0)
		var perk: StringName = perk_wanted(eco, plan, PerkManager.owned(pid), avail, main_cls, coop, cap_left, scrip, 0 if perks_only else perk_keep)
		if perk != &"":
			var pm2: PerkMachine = machines[String(perk)]
			out.append({"node": pm2, "kind": "perk", "value": _pv("perk", _flat(pm2.global_position, me)) + (0.3 if perks_only else 0.0),
				"cost": int(avail[String(perk)]), "label": "drink %s (%d Scrip)" % [PerkManager.display_name(perk), int(avail[String(perk)])]})
		else:
			# ---- a perk upgrade (T-075): nothing new to drink, so the next tier of one it carries
			var ups: Dictionary = {}
			for k: Variant in machines.keys():
				if PerkManager.has_perk(pid, StringName(k)) and PerkManager.can_upgrade(pid, StringName(k)) == &"ok":
					ups[k] = PerkManager.tier_price(StringName(k), PerkManager.tier_of(pid, StringName(k)) + 1)
			var nothing_new: bool = cap_left <= 0 or perk_wanted(eco, plan, PerkManager.owned(pid), avail, main_cls, coop, cap_left, 1 << 30, 0) == &""
			var up: StringName = upgrade_wanted(eco, PerkManager.tiers(pid), ups, main_cls, rnd, scrip, 0 if perks_only else reserve + egg_save, nothing_new)
			if up != &"":
				var pm3: PerkMachine = machines[String(up)]
				var nt: int = PerkManager.tier_of(pid, up) + 1
				out.append({"node": pm3, "kind": "perk", "value": value_of(eco, "perk", _flat(pm3.global_position, me)) - 0.1,
					"cost": int(ups[String(up)]), "label": "brew %s (%d Scrip)" % [PerkManager.tier_name(up, nt), int(ups[String(up)])]})

	if perks_only:
		return out
	# ---- a wall gun good for the round
	var walls: Dictionary = {}
	var nodes: Dictionary = {}
	var classes: Dictionary = {}
	var wtable: Dictionary = GLData.table("weapons")["weapons"]
	for wb: WallBuy in squad.wall_buys():
		if not is_instance_valid(wb) or not wb.is_visible_in_tree() or _flat(wb.global_position, anc) > rng:
			continue
		if not squad.can_claim(wb, pid) or not brain.reachable(BotBrain._front_of(wb)):
			continue
		walls[String(wb.weapon_id)] = wb.price()
		nodes[String(wb.weapon_id)] = wb
		classes[String(wb.weapon_id)] = str((wtable.get(String(wb.weapon_id), {}) as Dictionary).get("class", ""))
	var held: Array = []
	for w: WeaponInstance in player.weapons.slots:
		var wrow: Dictionary = wtable.get(String(w.base_id()), {})
		var q: int = 5000 if w.upgraded else (int(wrow.get("wall_price", 0)) if int(wrow.get("wall_price", 0)) > 0 or w.weapon_class() == &"pistol" else 1500)
		held.append({"id": String(w.base_id()), "tier": tier_of(String(w.base_id()), w.upgraded, eco, w.tier), "q": q})
	var free_slot: bool = player.weapons.slots.size() < player.weapons.max_slots()
	# T-121: a gun already taught is fed again (twice, three times): hold its price back from rolls and wall guns
	var save_up: int = 0
	var rs_slot: int = brain._upgradeable_slot()
	if rs_slot >= 0:
		var rw: WeaponInstance = player.weapons.slots[rs_slot]
		save_up = reteach_save(eco, tier_of(String(rw.base_id()), false, eco), rw.upgraded, rw.tier, WeaponInstance.max_tier(), rnd,
			_powered_crucible(), Crucible.price_for(&"upgrade", econ, rw.tier))
	save_up = maxi(save_up, egg_save)
	var gun: StringName = gun_wanted(eco, held, walls, classes, (brain.personality.get("aim", {}) as Dictionary).get("class_pref", {}), rnd, scrip, reserve + save_up, free_slot)
	if gun != &"" and nodes.has(String(gun)):
		var wb2: WallBuy = nodes[String(gun)]
		out.append({"node": wb2, "kind": "gun", "value": _pv("gun", _flat(wb2.global_position, me)), "cost": wb2.price(),
			"label": "buy the %s wall gun (%d Scrip)" % [BotBrain.weapon_name(gun), wb2.price()]})
	# ---- U10 (T-163): a built wonder on a bench (Kaltenbrunn's Totenglocke, Totenhafen's Undertow) is free for each
	# player: taken when its tier beats the worst gun held (or a slot is free). Bots only ever took one for an egg
	# step (s8b's kill_with_weapon); a squad with four bells from round 8 lives longer.
	var worst_tier: float = INF
	for h2: Variant in held:
		worst_tier = minf(worst_tier, float((h2 as Dictionary)["tier"]))
	for wbn: Node in brain.get_tree().get_nodes_in_group(&"workbenches"):
		var bench: Workbench = wbn as Workbench
		if bench == null or not is_instance_valid(bench) or not bench.built or not bench.is_visible_in_tree() or not bench.can_interact(player):
			continue
		if not wonder_wanted(tier_of(String(bench.buildable_id), false, eco), worst_tier, free_slot, eco):
			continue
		if _flat(bench.global_position, anc) > rng * 1.5 or not squad.can_claim(bench, pid):
			continue
		var bst: Vector3 = brain.stand_point(bench)
		if bst == Vector3.INF:
			continue
		out.append({"node": bench, "kind": "gun", "wonder": true, "value": _pv("gun", _flat(bench.global_position, me)), "cost": 0, "stand": bst,
			"label": "take the %s from the workbench" % BotBrain.weapon_name(bench.buildable_id)})
	# ---- doors
	var dcfg: Dictionary = (cfg.get("shopping", {}) as Dictionary).get("doors", {})
	var ordered_door: Node = brain.order_node() if order == &"open_door" else null
	# (U10 T-163, Q-19: a self-led squad also buys in a break: the arrival grace of an act skip was spent idle and
	# the first round's horde met it in the spawn bay; the delay exists to leave a human the first pick)
	# U10 T-172: an egg bot's shopping break opens the way to the main egg's open steps (BotEE.route_doors)
	var egg_doors: Array = brain.ee.route_doors() if ee_shopping() else []
	# (the round's delay still holds for every other door while an egg door is on the list)
	var doors_now: bool = squad.round_time() >= float(dcfg.get("round_delay_s", 20.0)) * (0.0 if ordered_door != null else 1.0) \
			or (self_led and brain.in_break())
	if bool(dcfg.get("enabled", true)) and (doors_now or not egg_doors.is_empty()) \
			and brain.doors_bought_round < int(dcfg.get("max_per_round_per_bot", 1)):
		var human: Player = squad.human()
		var route_doors: Dictionary = _route_doors() if self_led else {}
		for dn: BuyDoor in brain.loco_doors():
			if not is_instance_valid(dn) or dn.is_open or not dn.can_interact(player):
				continue
			var ordered: bool = ordered_door == dn
			var egg: bool = not ordered and egg_doors.has(dn)
			if not ordered and not egg and not doors_now:
				continue
			var hd: float = _flat(dn.global_position, human.global_position) if human != null and not human.spectating else INF
			if egg:
				if not egg_door_allowed(eco, self_led, squad.human_doors_opened):
					continue
			elif not door_allowed(eco, ordered, self_led, squad.human_doors_opened, hd):
				continue
			var is_pd: bool = dn == power_door
			var keep: int = 0 if ordered else maxi(reserve, int(dcfg.get("reserve_scrip", 300)))   # (an egg door keeps the reserve too)
			if is_pd:
				keep = int(pw.get("door_reserve_scrip", 300))   # the way to the power is the revive-critical spend
			if self_led and not ordered and not egg and bool(pw.get("self_led_useful_doors_only", true)) \
					and not self_led_door_ok(is_pd, route_doors.has(String(dn.door_id)), scrip, dn.cost, saving_for, keep):
				continue   # a squad leading itself opens only doors it has a use for, the power's first
			if not ordered and not egg and not is_pd and (_flat(dn.global_position, anc) > float(dcfg.get("max_from_leader_m", 30.0)) * range_mult * (2.0 if self_led else 1.0)):
				continue
			if scrip < dn.cost + keep:
				continue
			if not squad.can_claim(dn, pid) or not brain.reachable(BotBrain._door_side(dn, me)):
				continue
			var dv: float = 0.95 if ordered else 0.9 if egg else _pv("power_door" if is_pd else "door", _flat(dn.global_position, me))
			out.append({"node": dn, "kind": "door", "value": dv, "cost": dn.cost,
				"label": "open the %s (%d Scrip)%s" % [BotBrain.door_label(dn), dn.cost, " on the way to the power" if is_pd else ""]})
	# ---- the Requisition Crate (never someone else's open crate)
	var best_tier: float = 0.0
	for h: Variant in held:
		best_tier = maxf(best_tier, float((h as Dictionary)["tier"]))
	var ccrate: Dictionary = eco.get("crate", {})
	if crate_pulls_this_round < int(ccrate.get("max_pulls_per_round", 1)) and crate_wanted(eco, scrip, CrateManager.cost(), best_tier, rnd, reserve + save_up):
		for cn: Node in brain.get_tree().get_nodes_in_group(&"crate_spots"):
			var cr: MysteryCrate = cn as MysteryCrate
			if cr == null or cr.phase != MysteryCrate.Phase.CLOSED or not cr.is_visible_in_tree() or _flat(cr.global_position, anc) > rng * 1.5 or not _near_enough(cr.global_position):
				continue
			if not squad.can_claim(cr, pid):
				continue
			var st: Vector3 = brain.stand_point(cr)
			if st == Vector3.INF:
				continue
			out.append({"node": cr, "kind": "crate", "value": _pv("crate", _flat(cr.global_position, me)), "cost": CrateManager.cost(), "stand": st,
				"label": "pull the Requisition Crate (%d Scrip)" % CrateManager.cost()})
	# ---- the Crucible: a gun worth it, in the break, never while the human is down. It sells no ammo (T-083):
	# a taught gun running dry is the ammo box errand above, priced by AmmoBox.price_for like any other gun.
	var crc: Dictionary = (cfg.get("shopping", {}) as Dictionary).get("crucible", {})
	var human_down: bool = Net.session != null and squad.human() != null and Net.session.coop.is_downed(squad.human().player_id)
	var in_break: bool = brain.in_break()
	var up_slot: int = brain._upgradeable_slot()
	var up_ok: bool = false
	if up_slot >= 0:
		var uw: WeaponInstance = player.weapons.slots[up_slot]
		up_ok = tier_of(String(uw.base_id()), false, eco) >= float((eco.get("crucible", {}) as Dictionary).get("min_tier", 3.4)) and rnd >= int((eco.get("crucible", {}) as Dictionary).get("min_round", 6))
	var up_tier: int = player.weapons.slots[up_slot].tier if up_slot >= 0 else 0
	var up_cost: int = Crucible.price_for(&"upgrade", econ, up_tier)
	var want_up: bool = up_ok and BotConfig.crucible_wanted(crc, true, scrip, up_cost, rnd)   # the Crucible's own reserve_scrip is the reserve here
	# U10 T-172 (ee.json egg_gun): the egg's Crucible gun: any long gun, any round, from around the bot itself
	var egg_up: bool = false
	if egg_gun and up_slot >= 0 and not player.weapons.slots[up_slot].upgraded:
		var ecls: StringName = player.weapons.slots[up_slot].weapon_class()
		egg_up = ecls != &"pistol" and ecls != &"wonder" and egg_gun_ok(true, true, scrip, up_cost, int(crc.get("reserve_scrip", 500)))
	var shop_brk: bool = ee_shopping()
	if (want_up or egg_up) and not human_down and (in_break or shop_brk or egg_up or not bool(crc.get("only_in_break", true))):
		var eg: Dictionary = BotEECatalog.cfg().get("egg_gun", {})
		var c_rng: float = float(crc.get("max_from_leader_m", 30.0)) * range_mult * (2.0 if squad.bot_led() else 1.0)
		var c_anc: Vector3 = anc
		if egg_up:
			c_rng = maxf(c_rng, float(eg.get("range_m", 90.0)))
			c_anc = me
		elif shop_brk:
			c_rng = maxf(c_rng, range_m())   # the break's own range (the Crucible's 30 m never reached it from the egg's spots)
		var cr2: Crucible = brain.crucible_for_me(c_rng, c_anc)
		if cr2 != null and (egg_up or _near_enough(cr2.global_position)):
			out.append({"node": cr2, "kind": "crucible", "slot": -1, "value": float(eg.get("value", 1.0)) if egg_up else _pv("crucible", _flat(cr2.global_position, me)), "cost": up_cost,
				"label": "feed the %s to the Crucible (%d Scrip)%s" % [player.weapons.slots[up_slot].display_name(), up_cost, " for the egg" if egg_up else ""]})
	# ---- T-177: the Armorer's Bench on its own (squad bots and companions; before, only on a mark order): a part
	# for the main gun, in a break, after the reserve and whatever the Crucible / the egg holds back
	var bcfg: Dictionary = eco.get("bench", {})
	var bench_pick: Dictionary = {}
	if bool(bcfg.get("enabled", true)) and main != null and WeaponKit.accepts(main) and rnd >= int(bcfg.get("min_round", 3)):
		var bench: ArmorersBench = ArmorersBench.nearest(brain.get_tree(), anc)
		if bench != null and bench.is_visible_in_tree() and _flat(bench.global_position, anc) <= rng * 1.3 and _near_enough(bench.global_position):
			var keep_b: int = reserve + save_up + int(bcfg.get("keep_scrip", 1500))
			bench_pick = BotMarkOrders.pick_bench_option(bench_rows_open(ArmorersBench.options_for_gun(player, main)), BotAIData.table("marks").get("bench_prefs", []), scrip - keep_b)
			if not bench_pick.is_empty() and int(bench_pick["price"]) <= scrip - keep_b and (in_break or shop_brk or not bool(bcfg.get("only_in_break", true))) \
					and squad.can_claim(bench, pid):
				var bst: Vector3 = brain.stand_point(bench)
				if bst != Vector3.INF:
					out.append({"node": bench, "kind": "bench", "slot": str(bench_pick["slot"]), "option": str(bench_pick["option"]),
						"wslot": player.weapons.slots.find(main), "value": _pv("bench", _flat(bench.global_position, me)), "cost": int(bench_pick["price"]), "stand": bst,
						"label": "fit the %s with %s at the Armorer's Bench (%d Scrip)" % [main.display_name(), str(bench_pick["name"]), int(bench_pick["price"])]})
	# ---- T-177: the bank (squad bots and companions, in an account of their own for this match; never the agent,
	# whose bank is the owner's profile): bank what it won't spend soon, take it out when that makes the next thing
	# affordable (BankAccount.bot_plan), once a round, in a break
	var bk: Dictionary = eco.get("bank", {})
	if bool(bk.get("enabled", true)) and not brain.is_player_bot and (in_break or shop_brk) and bank_visits_round < int(bk.get("visits_per_round", 1)) \
			and BankAccount.closed_reason() == "":
		var want: int = next_want_cost(up_ok and _powered_crucible(), up_cost, bench_pick)
		var mv: int = BankAccount.bot_plan(scrip, BankAccount.bot_balance(pid), want, reserve + save_up, int(bk.get("min_move", 1000)))
		if mv != 0:
			var ctr: BankCounter = _bank_counter(anc, rng * float(bk.get("range_mult", 1.5)))
			if ctr != null and squad.can_claim(ctr, pid):
				var cst: Vector3 = brain.stand_point(ctr)
				if cst != Vector3.INF:
					out.append({"node": ctr, "kind": "bank", "amount": mv, "cost": 0, "stand": cst,
						"value": float(bk.get("withdraw_value", 0.85)) if mv < 0 else _pv("bank", _flat(ctr.global_position, me)),
						"label": ("take %d Scrip out of the bank" % -mv) if mv < 0 else ("bank %d Scrip" % mv)})
	if brain.is_player_bot:
		return AgentPlan.filter(out, brain)   # T-071 pass 2: the agent spends by its map plan (player_bot.json plans)
	return out


## T-177 pure: the bench rows for slots with nothing fitted yet. One part per slot: a bot never swaps a fitted part
## for another (the first smoke run swapped radium and aperture sights back and forth, 600 and 750 Scrip a time).
static func bench_rows_open(rows: Array) -> Array:
	var filled: Dictionary = {}
	for r: Variant in rows:
		if bool((r as Dictionary).get("installed", false)):
			filled[str((r as Dictionary)["slot"])] = true
	return rows.filter(func(r: Variant) -> bool: return not filled.has(str((r as Dictionary)["slot"])))


## T-177: the price of the next thing this bot wants (0 none), for the bank: its next tonic (the plan's first it
## can buy now: owned, cap and power checked), else a Crucible teaching it is up for, else the bench's pick.
func next_want_cost(crucible_up: bool, up_cost: int, bench_pick: Dictionary) -> int:
	var pid: int = player.player_id
	if bool(brain.options.get("perks", true)):
		var plan: Array = brain.personality_economy("perk_order", [])
		if plan.is_empty():
			plan = eco.get("perk_plan", [])
		var have: Dictionary = {}
		for n: Node in brain.get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n as PerkMachine
			if pm != null and pm.is_powered() and pm.is_visible_in_tree():
				have[String(pm.perk_id)] = true
		for pv: Variant in plan:
			var pk: String = str(pv)
			if have.has(pk) and PerkManager.can_buy(pid, StringName(pk)) == &"ok":
				return PerkManager.price(StringName(pk))
	if crucible_up:
		return up_cost
	if not bench_pick.is_empty():
		return int(bench_pick.get("price", 0))
	return 0


## T-177: the nearest bank counter within `r` m of `anc` (null none).
func _bank_counter(anc: Vector3, r: float) -> BankCounter:
	var best: BankCounter = null
	var bd: float = INF
	for n: Node in brain.get_tree().get_nodes_in_group(&"bank_branch"):
		var br: BankBranch = n as BankBranch
		if br == null or br.counter == null or not is_instance_valid(br.counter) or not br.is_visible_in_tree():
			continue
		var d: float = _flat(br.counter.global_position, anc)
		if d <= r and d < bd and _near_enough(br.counter.global_position):
			bd = d
			best = br.counter
	return best


## The way to the power (T-058, cached for 3 s): {"switch": the PowerSwitch, "stand": where to stand} when it can
## be reached now; {"door": the closed BuyDoor in the way} when it can't (the navmesh runs through doors: the
## nearest closed door the path crosses whose near side this bot can reach); {} when the power is on or there is
## no switch it may throw.
func power_plan(now: float) -> Dictionary:
	if now - _power_t < 3.0:
		var ok: bool = true
		for k: String in ["switch", "door"]:
			if _power.has(k) and not is_instance_valid(_power[k]):
				ok = false
		if _power.has("door") and is_instance_valid(_power["door"]) and (_power["door"] as BuyDoor).is_open:
			ok = false
		if ok:
			return _power
	_power_t = now
	_power = {}
	if GameState.power_on:
		return _power
	var sw: PowerSwitch = null
	for n: Node in brain.get_tree().get_nodes_in_group(&"power_switch"):
		if n is PowerSwitch and (n as PowerSwitch).can_interact(player) and (n as PowerSwitch).is_visible_in_tree():
			sw = n as PowerSwitch
			break
	if sw == null:
		return _power
	var st: Vector3 = brain.stand_point(sw)
	if st != Vector3.INF:
		_power = {"switch": sw, "stand": st}
		return _power
	var me: Vector3 = player.global_position
	var nav: RID = player.get_world_3d().navigation_map
	var goal: Vector3 = brain.snap(sw.global_position)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, me, goal, true, brain.squad.nav_mask())
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > 2.0:
		# (a path that stops short is the server's partial path to the closest reachable point, not a way there)
		# UPDATE 07 QA (T-107): on a map with one navmesh region per zone (Kaltenbrunn, Totenhafen) the open
		# zones' mask never reaches a switch behind a closed door, so the squad planned nothing and bought nothing
		# for the whole match. Plan the way across every zone (minus the ones bots can't use, e.g. the lift) and
		# buy the nearest closed door that path crosses, as the single-region Map 0 always allowed.
		var zb: Dictionary = brain.squad.map.director.zone_bits if brain.squad.map != null and brain.squad.map.director != null else {}
		path = NavigationServer3D.map_get_path(nav, me, goal, true, plan_mask_of(zb, pw_avoid_zones()))
	if path.is_empty():
		return _power
	var best: BuyDoor = null
	var best_d: float = INF
	for d: BuyDoor in brain.loco_doors():
		if not is_instance_valid(d) or d.is_open or not ZombieDirector.door_crossed(d, path):
			continue
		var dd: float = _flat(d.global_position, me)
		if dd < best_d and brain.reachable(BotBrain._door_side(d, me)):
			best_d = dd
			best = d
	if best != null:
		_power = {"door": best}
	return _power


## The nav layer mask for planning a way across the whole map: every zone's bit (and the always-on layer 1)
## except the zones in `avoid` (zones a bot cannot cross on foot: the Kaltenbrunn lift). Pure, tested.
static func plan_mask_of(zone_bits: Dictionary, avoid: Array) -> int:
	if zone_bits.is_empty():
		return 0x7FFFFFFF
	var m: int = 1
	for z: Variant in zone_bits.keys():
		if avoid.has(String(z)):
			continue
		m |= 1 << (int(zone_bits[z]) - 1)
	return m


func pw_avoid_zones() -> Array:
	return (eco.get("power", {}) as Dictionary).get("plan_avoid_zones", []) as Array


## Doors an authored training route on this map still needs (door_id -> true): a squad leading itself opens them
## once the power is on (T-058).
func _route_doors() -> Dictionary:
	var out: Dictionary = {}
	if brain.squad.map == null:
		return out
	for r: TrainingRoute in TrainingRoute.all_for_map(String(brain.squad.map.map_id)):
		if r.agent_only and not brain.is_player_bot:
			continue   # T-071: the player bot's own loops
		for d: String in r.requires_doors:
			out[d] = true
	return out


## T-058: a squad leading itself does its far errands (the cellar's perks, the Crucible, the power, a crate across
## the inn) between waves: mid-round only within economy.json self_led_mid_round_m of its home (or leader), so
## nobody walks off alone into a spawn room while the round is on (the bots3 downs in the cellar).
func _near_enough(p: Vector3) -> bool:
	var squad: BotSquad = brain.squad
	if not squad.bot_led() or ee_shopping():
		return true   # (U10 T-172: an egg bot's shopping break is already off on its own, by its egg spot)
	var home: Vector3 = squad.home.center() if squad.home != null else anchor()
	var near: bool = _flat(p, home) <= float(eco.get("self_led_mid_round_m", 16.0)) and absf(p.y - home.y) < 2.5
	if brain.in_break():
		# U10 (T-163, Q-19): a far errand in a break only if the trip there and back fits in what is left of it
		# (an act skip's 14 s arrival grace sent a bot 50 m off to the Kranich's gun blisters, and the first wave
		# found it there alone)
		if near or RoundManager.state != RoundManager.State.BREAK:
			return true
		var trip: float = _flat(player.global_position, p) + _flat(p, home)
		return trip / float(eco.get("self_led_trip_mps", 4.0)) + float(eco.get("self_led_trip_margin_s", 5.0)) <= RoundManager.break_left
	return near


## The main gun: the best-tier gun carried that isn't the start pistol (else whatever it holds).
func _main_gun() -> WeaponInstance:
	var best: WeaponInstance = null
	var best_t: float = -1.0
	for w: WeaponInstance in player.weapons.slots:
		var t: float = tier_of(String(w.base_id()), w.upgraded, eco, w.tier)
		if t > best_t:
			best_t = t
			best = w
	return best


## Is a powered Crucible on the map (T-121: worth saving for its next teaching)?
func _powered_crucible() -> bool:
	for cn: Node in brain.get_tree().get_nodes_in_group(&"crucible"):
		if cn is Crucible and (cn as Crucible).is_powered():
			return true
	return false


## Ammo: the driest carried long gun under ammo_box_below (or wall_ammo_below with its own wall-buy near): the
## nearest ammo box or its wall-buy, whichever is cheaper per reach. Paid by the companion's payer at its price
## multiplier (Jakub: the party's Scrip at half price).
func _ammo_candidate(anc: Vector3, rng: float, scrip: int) -> Dictionary:
	var slot: int = -1
	var worst: float = 2.0
	var long_gun: bool = false
	for lw: WeaponInstance in player.weapons.slots:
		long_gun = long_gun or lw.weapon_class() != &"pistol"
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if (long_gun and w.weapon_class() == &"pistol") or w.reserve_max() <= 0:
			continue
		var frac: float = float(w.reserve + w.mag) / float(maxi(1, w.reserve_max() + w.mag_size()))
		if frac < worst:
			worst = frac
			slot = i
	if slot < 0:
		return {}
	var sw: WeaponInstance = player.weapons.slots[slot]
	var me: Vector3 = player.global_position
	var payer: int = int(brain.options.get("ammo_payer_pid", 0))
	var pay_scrip: int = Economy.get_scrip(payer) if payer > 0 else scrip
	var mult: float = float(brain.options.get("ammo_price_mult", 1.0))
	var out: Dictionary = {}
	var box_below: float = float(eco.get("ammo_box_below", 0.25))
	if brain.in_break() and pay_scrip >= int(eco.get("break_top_up_scrip", 3000)):
		box_below = maxf(box_below, float(eco.get("break_top_up_below", 0.6)))   # Scrip to spare: top up between waves
	elif brain.perception.known.is_empty() and pay_scrip >= int(eco.get("break_top_up_scrip", 3000)):
		box_below = maxf(box_below, float(eco.get("calm_top_up_below", 0.5)))   # a lull mid-round: half empty is worth a box
	if worst < box_below:
		var price: int = int(ceil(float(AmmoBox.price_for(sw.data, sw.upgraded, AmmoBox.cfg())) * mult))
		if pay_scrip >= price:
			var best: AmmoBox = null
			for n: Node in brain.get_tree().get_nodes_in_group(&"ammo_boxes"):
				var ab: AmmoBox = n as AmmoBox
				# nearly dry: any reachable box, however far from the anchor (a bot following the human into a room with
				# no box used to follow on with an empty main gun and Scrip in its pocket)
				var reach_m: float = INF if worst < 0.12 else rng * 1.3
				if ab == null or not ab.is_visible_in_tree() or _flat(ab.global_position, anc) > reach_m:
					continue
				if ab.cooldown_left(player.player_id) > 0.0 or not brain.squad.can_claim(ab, player.player_id) or not brain.reachable(BotBrain._front_of(ab)):
					continue
				if best == null or _flat(ab.global_position, me) < _flat(best.global_position, me):
					best = ab
			if best != null:
				out = {"node": best, "kind": "ammo_box", "slot": slot, "value": _pv("ammo_box", _flat(best.global_position, me)) + (0.25 if worst < 0.1 else 0.0),
					"cost": price, "label": "refill the %s at an ammo box (%d Scrip)" % [sw.display_name(), price]}
				if worst < 0.12:
					out["value"] = 1.0   # nearly dry: this comes before anything else
	var wall_below: float = float(eco.get("wall_ammo_below", 0.35))
	if brain.is_player_bot:
		wall_below = float(BotAIData.table("player_bot").get("wall_ammo_below", wall_below))   # T-071 pass 3: the agent tops up sooner (a train never waits for a dry gun)
	if worst < wall_below and bool(brain.options.get("shopping", true)):
		for wb: WallBuy in brain.squad.wall_buys():
			if not is_instance_valid(wb) or wb.weapon_id != sw.base_id() or _flat(wb.global_position, anc) > rng:
				continue
			if scrip < wb.ammo_price(player) or not brain.squad.can_claim(wb, player.player_id) or not brain.reachable(BotBrain._front_of(wb)):
				continue
			var v: float = _pv("wall_ammo", _flat(wb.global_position, me))
			if out.is_empty() or v > float(out["value"]):
				out = {"node": wb, "kind": "ammo", "slot": slot, "value": v, "cost": wb.ammo_price(player),
					"label": "buy ammo for the %s (%d Scrip)" % [sw.display_name(), wb.ammo_price(player)]}
	return out


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
