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
## Doors the human opened this match (BotSquad keeps the count; read here).
var crate_pulls_this_round: int = 0


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


## A weapon's tier (economy.json weapon_tiers, + upgraded_tier_bonus for a Crucible gun).
static func tier_of(base_id: String, upgraded: bool, e: Dictionary) -> float:
	var t: float = float((e.get("weapon_tiers", {}) as Dictionary).get(base_id, 2.0))
	return t + (float(e.get("upgraded_tier_bonus", 1.5)) if upgraded else 0.0)


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


## The wall gun to buy: the best tier on offer that is better than the best gun carried (by min_gain), allowed in
## this round, affordable above reserve + the buffer. `held` = [{id, tier}], `walls` = id -> price, `prefer` =
## class multipliers (personality) by gun id -> class. Returns &"" for nothing.
static func gun_wanted(e: Dictionary, held: Array, walls: Dictionary, classes: Dictionary, prefer: Dictionary, round_n: int, scrip: int, reserve: int, free_slot: bool) -> StringName:
	var best_held: float = 0.0
	var worst_held: float = INF
	for h: Variant in held:
		best_held = maxf(best_held, float((h as Dictionary)["tier"]))
		worst_held = minf(worst_held, float((h as Dictionary)["tier"]))
	var want: float = want_tier(round_n, e.get("want_tier_by_round", []))
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
		# a better main gun, or a better second gun in place of the worst (the start pistol)
		var useful: bool = t > best_held + 0.2 or (t > worst_held + 0.8 and t >= want - 0.5) or (free_slot and t >= want - 0.5)
		if not useful:
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


## The never-touch rule: easter-egg objects ("quest"), traps ("trap"), the power switch ("power") and buildable
## parts ("part") only when ordered onto that object, or (traps) when the human already used that one, or for the
## local-AI planner bot (the user-sanctioned exception) when its setting is on. Everything else is fine.
static func may_touch(kind: String, ordered: bool, planner: bool, human_did: bool) -> bool:
	match kind:
		"quest", "part":
			return ordered or planner
		"power":
			return ordered or planner
		"trap":
			return ordered or planner or human_did
	return true


## The value (0..1) of a shopping candidate: its priority, a little less the farther it is.
static func value_of(e: Dictionary, kind: String, dist: float) -> float:
	var p: float = float((e.get("priorities", {}) as Dictionary).get(kind, 0.5))
	return clampf(p * (1.0 - clampf(dist / 60.0, 0.0, 0.35)), 0.0, 1.0)


# ================================================================== on the map

## Where shopping ranges are measured from and how far: the leader (or the hold spot), economy.json ranges.
func anchor() -> Vector3:
	var leader: Player = brain.squad.leader_for(brain)
	if brain.order_id() == &"hold" and brain.squad.hold_point != Vector3.INF:
		return brain.squad.hold_point
	return leader.global_position if leader != null else player.global_position


func range_m() -> float:
	if brain.squad.bot_led():
		return float(eco.get("bot_led_range_m", 60.0))
	return float(eco.get("max_range_from_leader_m", 26.0))


## The best repair, buy and crate candidates (cached for a second): {"repair": {}, "buy": {}, "crate": {}, "all": []}.
func best(now: float) -> Dictionary:
	if now - _cache_t < 1.0 and not _cache.is_empty():
		var ok: bool = true
		for k: String in ["repair", "buy", "crate"]:
			var c: Dictionary = _cache.get(k, {})
			if not c.is_empty() and not is_instance_valid(c.get("node")):
				ok = false
		if ok:
			return _cache
	_cache_t = now
	var all: Array[Dictionary] = candidates(anchor(), 1.0)
	var out: Dictionary = {"repair": {}, "buy": {}, "crate": {}, "all": all}
	for c2: Dictionary in all:
		var slot: String = "repair" if str(c2["kind"]) == "repair" else ("crate" if str(c2["kind"]) == "crate" else "buy")
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
	for n: Node in brain.get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or b.boards >= b.max_boards:
			continue
		var d: float = _flat(b.global_position, me)
		if d > board_r or _flat(b.global_position, anc) > board_lead:
			continue
		var key: String = "repair:%d" % b.get_instance_id()
		var front: Vector3 = BotBrain._front_of(b)
		if not squad.blackboard.can_claim(key, pid, now) or brain.loco.in_danger(front) or not brain.reachable(front):
			continue
		var missing: float = float(b.max_boards - b.boards) / float(maxi(1, b.max_boards))
		var v: float = clampf(0.35 + 0.5 * missing - d / 40.0, 0.05, 1.0)
		if best_board.is_empty() or v > float(best_board["value"]):
			best_board = {"node": b, "kind": "repair", "value": v, "key": key, "label": "rebuild the boards at a window %d m away" % int(d)}
	if not best_board.is_empty():
		out.append(best_board)
	var shopping: bool = bool(brain.options.get("shopping", true))
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
	# ---- an ammo box (or wall ammo) when the main gun runs low: ammo is never held back by the reserve
	var box_c: Dictionary = _ammo_candidate(anc, rng, scrip)
	if not box_c.is_empty():
		out.append(box_c)
	if not shopping or order == &"revive":
		return out
	# ---- perks
	if bool(brain.options.get("perks", true)) and rnd >= int(eco.get("perk_min_round", 2)):
		var avail: Dictionary = {}
		var machines: Dictionary = {}
		for n3: Node in brain.get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n3 as PerkMachine
			if pm == null or not pm.can_interact(player) or not pm.is_powered() or _flat(pm.global_position, anc) > rng * 1.3:
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
		var cap_left: int = PerkManager.cap_for(pid) - PerkManager.capped_count(pid)
		var coop: bool = not GameState.is_solo()
		var perk: StringName = perk_wanted(eco, plan, PerkManager.owned(pid), avail, main_cls, coop, cap_left, scrip, 0 if perks_only else reserve)
		if perk != &"":
			var pm2: PerkMachine = machines[String(perk)]
			out.append({"node": pm2, "kind": "perk", "value": value_of(eco, "perk", _flat(pm2.global_position, me)) + (0.3 if perks_only else 0.0),
				"cost": int(avail[String(perk)]), "label": "drink %s (%d Scrip)" % [PerkManager.display_name(perk), int(avail[String(perk)])]})
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
		held.append({"id": String(w.base_id()), "tier": tier_of(String(w.base_id()), w.upgraded, eco)})
	var free_slot: bool = player.weapons.slots.size() < player.weapons.max_slots()
	var gun: StringName = gun_wanted(eco, held, walls, classes, (brain.personality.get("aim", {}) as Dictionary).get("class_pref", {}), rnd, scrip, reserve, free_slot)
	if gun != &"" and nodes.has(String(gun)):
		var wb2: WallBuy = nodes[String(gun)]
		out.append({"node": wb2, "kind": "gun", "value": value_of(eco, "gun", _flat(wb2.global_position, me)), "cost": wb2.price(),
			"label": "buy the %s wall gun (%d Scrip)" % [BotBrain.weapon_name(gun), wb2.price()]})
	# ---- doors
	var dcfg: Dictionary = (cfg.get("shopping", {}) as Dictionary).get("doors", {})
	var ordered_door: Node = brain.order_node() if order == &"open_door" else null
	if bool(dcfg.get("enabled", true)) and squad.round_time() >= float(dcfg.get("round_delay_s", 20.0)) * (0.0 if ordered_door != null else 1.0) \
			and brain.doors_bought_round < int(dcfg.get("max_per_round_per_bot", 1)):
		var human: Player = squad.human()
		for dn: BuyDoor in brain.loco_doors():
			if not is_instance_valid(dn) or dn.is_open or not dn.can_interact(player):
				continue
			var ordered: bool = ordered_door == dn
			var hd: float = _flat(dn.global_position, human.global_position) if human != null and not human.spectating else INF
			if not door_allowed(eco, ordered, squad.bot_led(), squad.human_doors_opened, hd):
				continue
			if not ordered and (_flat(dn.global_position, anc) > float(dcfg.get("max_from_leader_m", 30.0)) * range_mult * (2.0 if squad.bot_led() else 1.0)):
				continue
			if scrip < dn.cost + (0 if ordered else maxi(reserve, int(dcfg.get("reserve_scrip", 300)))):
				continue
			if not squad.can_claim(dn, pid) or not brain.reachable(BotBrain._door_side(dn, me)):
				continue
			out.append({"node": dn, "kind": "door", "value": 0.95 if ordered else value_of(eco, "door", _flat(dn.global_position, me)), "cost": dn.cost,
				"label": "open the %s (%d Scrip)" % [BotBrain.door_label(dn), dn.cost]})
	# ---- the Requisition Crate (never someone else's open crate)
	var best_tier: float = 0.0
	for h: Variant in held:
		best_tier = maxf(best_tier, float((h as Dictionary)["tier"]))
	var ccrate: Dictionary = eco.get("crate", {})
	if crate_pulls_this_round < int(ccrate.get("max_pulls_per_round", 1)) and crate_wanted(eco, scrip, CrateManager.cost(), best_tier, rnd, reserve):
		for cn: Node in brain.get_tree().get_nodes_in_group(&"crate_spots"):
			var cr: MysteryCrate = cn as MysteryCrate
			if cr == null or cr.phase != MysteryCrate.Phase.CLOSED or not cr.is_visible_in_tree() or _flat(cr.global_position, anc) > rng * 1.5:
				continue
			if not squad.can_claim(cr, pid):
				continue
			var st: Vector3 = brain.stand_point(cr)
			if st == Vector3.INF:
				continue
			out.append({"node": cr, "kind": "crate", "value": value_of(eco, "crate", _flat(cr.global_position, me)), "cost": CrateManager.cost(), "stand": st,
				"label": "pull the Requisition Crate (%d Scrip)" % CrateManager.cost()})
	# ---- the Crucible: a gun worth it, in the break, never while the human is down; upgraded ammo
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
	var ammo_slot: int = -1
	for ai: int in player.weapons.slots.size():
		var aw: WeaponInstance = player.weapons.slots[ai]
		if BotConfig.crucible_ammo_wanted(crc, aw.upgraded, aw.reserve, aw.reserve_max(), scrip, Crucible.price_for(&"ammo", econ)):
			if ammo_slot < 0 or aw == player.weapons.current():
				ammo_slot = ai
	if (want_up or ammo_slot >= 0) and not human_down and (in_break or not bool(crc.get("only_in_break", true))):
		var cr2: Crucible = brain.crucible_for_me(float(crc.get("max_from_leader_m", 30.0)) * range_mult * (2.0 if squad.bot_led() else 1.0), anc)
		if cr2 != null:
			var kind: String = "crucible_ammo" if ammo_slot >= 0 else "crucible"
			out.append({"node": cr2, "kind": kind, "slot": ammo_slot, "value": value_of(eco, kind, _flat(cr2.global_position, me)),
				"cost": Crucible.price_for(&"ammo", econ) if ammo_slot >= 0 else up_cost,
				"label": "buy upgraded ammo at the Crucible" if ammo_slot >= 0 else ("feed the %s to the Crucible (%d Scrip)" % [player.weapons.slots[up_slot].display_name(), up_cost])})
	return out


## The main gun: the best-tier gun carried that isn't the start pistol (else whatever it holds).
func _main_gun() -> WeaponInstance:
	var best: WeaponInstance = null
	var best_t: float = -1.0
	for w: WeaponInstance in player.weapons.slots:
		var t: float = tier_of(String(w.base_id()), w.upgraded, eco)
		if t > best_t:
			best_t = t
			best = w
	return best


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
	if worst < float(eco.get("ammo_box_below", 0.25)):
		var price: int = int(ceil(float(AmmoBox.price_for(sw.data, sw.upgraded, AmmoBox.cfg())) * mult))
		if pay_scrip >= price:
			var best: AmmoBox = null
			for n: Node in brain.get_tree().get_nodes_in_group(&"ammo_boxes"):
				var ab: AmmoBox = n as AmmoBox
				if ab == null or not ab.is_visible_in_tree() or _flat(ab.global_position, anc) > rng * 1.3:
					continue
				if ab.cooldown_left(player.player_id) > 0.0 or not brain.squad.can_claim(ab, player.player_id) or not brain.reachable(BotBrain._front_of(ab)):
					continue
				if best == null or _flat(ab.global_position, me) < _flat(best.global_position, me):
					best = ab
			if best != null:
				out = {"node": best, "kind": "ammo_box", "slot": slot, "value": value_of(eco, "ammo_box", _flat(best.global_position, me)) + (0.25 if worst < 0.1 else 0.0),
					"cost": price, "label": "refill the %s at an ammo box (%d Scrip)" % [sw.display_name(), price]}
	if worst < float(eco.get("wall_ammo_below", 0.35)) and bool(brain.options.get("shopping", true)):
		for wb: WallBuy in brain.squad.wall_buys():
			if not is_instance_valid(wb) or wb.weapon_id != sw.base_id() or _flat(wb.global_position, anc) > rng:
				continue
			if scrip < wb.ammo_price(player) or not brain.squad.can_claim(wb, player.player_id) or not brain.reachable(BotBrain._front_of(wb)):
				continue
			var v: float = value_of(eco, "wall_ammo", _flat(wb.global_position, me))
			if out.is_empty() or v > float(out["value"]):
				out = {"node": wb, "kind": "ammo", "slot": slot, "value": v, "cost": wb.ammo_price(player),
					"label": "buy ammo for the %s (%d Scrip)" % [sw.display_name(), wb.ammo_price(player)]}
	return out


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
