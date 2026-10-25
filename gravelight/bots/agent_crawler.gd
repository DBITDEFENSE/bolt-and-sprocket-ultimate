class_name AgentCrawler
extends RefCounted
## The player bot's crawler break (T-071 pass 3, player_bot.json "crawler"): the classic solo trick. When a round
## is down to its last zombie (nothing left to spawn) and the agent has errands worth a trip (the plan's next
## buy, a Second Wind rebuy, ammo), it shoots that zombie's legs until it crawls (the game's own leg-damage rule:
## enemies.json leg_pool_fraction / leg_sever_chance), then leaves it crawling (0.8 m/s) and does the errands
## as if the round were over: the cellar's perks, doors, wall ammo, a full reload. Then it lets it go and kills
## it, and the next round starts. Nothing here touches the game's rules: the zombie is a real crawler, the
## round really is still on, and the agent can see it the whole time (it only stops counting it as a threat
## while it is further than ignore_within_m).
##
## States: NONE -> MAKING (aiming at its legs; BotAim.aim_point) -> HOLDING (BotPerception.ignore; BotBrain
## .in_break() is true) -> NONE (released: killed like any other zombie). Solo / with no other bot brains only
## (the bots would shoot it). Never in a special round, never a boss or a zombie that can't crawl.

enum State { NONE, MAKING, HOLDING }

var brain: BotBrain
var cfg: Dictionary = {}
var state: State = State.NONE
var target: Zombie = null
var _t0: float = 0.0
var _idle_t: float = -1.0
var _round: int = -1
## Zombies already tried (instance id -> true): a failed try is never repeated on the same zombie (it was, every
## think, and an out-of-sight pair of legs held a round open for the soak's whole time cap).
var _tried: Dictionary = {}
## Counters for the soak.
var stats: Dictionary = {"made": 0, "failed": 0, "held_s": 0.0, "released": 0}


func setup(b: BotBrain) -> void:
	brain = b
	cfg = (BotAIData.table("player_bot").get("crawler", {}) as Dictionary)


func _f(k: String, d: float) -> float:
	return float(cfg.get(k, d))


func making(z: Zombie) -> bool:
	return state == State.MAKING and z != null and z == target


func holding() -> bool:
	return state == State.HOLDING and target != null and is_instance_valid(target) and not _others


## Another zombie still up besides the crawler (the round's last two): no break until it is dead.
var _others: bool = false


## Called every think (BotBrain._think, before the perception's sense).
func think(now: float) -> void:
	if not bool(cfg.get("enabled", false)):
		return
	var dirn: ZombieDirector = brain.squad.director() if brain.squad != null else null
	if state != State.NONE:
		var gone: bool = target == null or not is_instance_valid(target) or not BotPerception.targetable(target) \
				or RoundManager.state != RoundManager.State.ROUND or RoundManager.current_round != _round
		if not gone and dirn != null and dirn.active_zombies().size() > int(_f("max_left", 2.0)):
			gone = true   # (more turned up: a Jakub burst, a recycled zombie) the plain fight again
		if gone:
			_release(now)
			return
		_others = dirn != null and dirn.active_zombies().size() > 1
		if state == State.MAKING:
			if target.is_crawler:
				state = State.HOLDING
				_t0 = now
				_idle_t = -1.0
				stats["made"] = int(stats["made"]) + 1
				brain.perception.ignore = target
				brain.perception.ignore_within_m = _f("ignore_within_m", 3.0)
			elif float(target.get("_leg_damage")) == -INF or now - _t0 > _f("make_max_s", 12.0):
				stats["failed"] = int(stats["failed"]) + 1
				_release(now)   # the legs held (the sever roll failed): it dies like the rest
			return
		# HOLDING
		if now - _t0 > _f("hold_max_s", 45.0):
			_release(now)
			return
		if errands_pending() or not _home():
			_idle_t = -1.0   # (errands done: back home first, so the next round doesn't find it in the cellar)
		elif _idle_t < 0.0:
			_idle_t = now
		elif now - _idle_t > _f("done_s", 2.5) and brain.action != "buy" and brain.action != "resupply":
			_release(now)
		return
	# NONE: is this the moment?
	if dirn == null or RoundManager.state != RoundManager.State.ROUND or RoundManager.to_spawn > 0 or RoundManager.is_special_round:
		return
	if RoundManager.current_round < int(_f("from_round", 2.0)) or not brain.squad.brains.is_empty():
		return
	var act: Array = dirn.active_zombies()
	if act.is_empty() or act.size() > int(_f("max_left", 2.0)):
		return
	# the round's last one or two: the nearest one not tried yet that can crawl (the other is killed as usual)
	var z: Zombie = null
	var best_d: float = INF
	for a: Variant in act:
		var za: Zombie = a as Zombie
		if za == null or _tried.has(za.get_instance_id()) and _round == RoundManager.current_round:
			continue
		var dd: float = za.global_position.distance_to(brain.player.global_position)
		if dd < best_d:
			best_d = dd
			z = za
	if z == null or not BotPerception.targetable(z) or BotPerception.is_boss(z) or z.is_crawler:
		return
	var zc: Variant = z.get("_cfg")
	if zc is Dictionary and not bool((zc as Dictionary).get("can_crawl", true)):
		return
	if float(z.get("_leg_damage")) == -INF or z.state != Zombie.State.CHASE or _tried.has(z.get_instance_id()):
		return
	if not errands_pending():
		return
	state = State.MAKING
	target = z
	if _round != RoundManager.current_round:
		_tried.clear()
	_tried[z.get_instance_id()] = true
	_t0 = brain.squad.time()
	_round = RoundManager.current_round


func _release(_now: float) -> void:
	if state == State.HOLDING:
		stats["released"] = int(stats["released"]) + 1
		stats["held_s"] = float(stats["held_s"]) + (brain.squad.time() - _t0)
	if brain.perception.ignore == target:
		brain.perception.ignore = null
	state = State.NONE
	target = null


## Is there an errand worth holding the round open for? The plan's current step (or a step that may go ahead of
## it) affordable now; Second Wind to rebuy (solo); the main gun's ammo low with the Scrip for wall ammo.
func errands_pending() -> bool:
	var pid: int = brain.player.player_id
	var scrip: int = Economy.get_scrip(pid)
	var keep: int = int((BotAIData.table("economy").get("reserve", {}) as Dictionary).get("min_scrip", 300))
	if GameState.is_solo() and not PerkManager.has_perk(pid, &"second_wind") and not PerkManager.second_wind_gone \
			and scrip >= PerkManager.price(&"second_wind") + keep and _perk_reachable(&"second_wind"):
		return true
	var step: Dictionary = AgentPlan.current_for(brain)
	if not step.is_empty():
		var pr: int = AgentPlan.price_of(step, brain)
		if step.has("power"):
			if _power_reachable():
				return true
		elif pr >= 0 and scrip >= pr + keep and _step_reachable(step):
			return true
	var w: WeaponInstance = brain.economy._main_gun() if brain.economy != null else null
	if w != null and w.reserve_max() > 0 and float(w.mag + w.reserve) / float(maxi(1, w.mag_size() + w.reserve_max())) < _f("ammo_frac", 0.5) \
			and scrip >= keep + 250:
		return true
	return false


## Is the agent back by its home loop (BotSquad.home_point: its plan's training ground) on the same floor?
func _home() -> bool:
	var me: Vector3 = brain.player.global_position
	var hp: Vector3 = brain.squad.home_point(me)
	return hp == Vector3.INF or (Vector2(hp.x - me.x, hp.z - me.z).length() < _f("home_m", 6.0) and absf(hp.y - me.y) < 1.5)


func _perk_reachable(pid_: StringName) -> bool:
	for n: Node in brain.get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		if pm != null and pm.perk_id == pid_ and pm.is_powered() and brain.reachable(BotBrain._front_of(pm)):
			return true
	return false


func _power_reachable() -> bool:
	for n: Node in brain.get_tree().get_nodes_in_group(&"power_switch"):
		if n is PowerSwitch and (n as PowerSwitch).can_interact(brain.player) and brain.stand_point(n as Node3D) != Vector3.INF:
			return true
	return false


func _step_reachable(step: Dictionary) -> bool:
	if step.has("perk"):
		return _perk_reachable(StringName(str(step["perk"])))
	if step.has("door"):
		for n: Node in brain.get_tree().get_nodes_in_group(&"doors"):
			var d: BuyDoor = n as BuyDoor
			if d != null and not d.is_open and String(d.door_id) == str(step["door"]):
				return brain.reachable(BotBrain._door_side(d, brain.player.global_position))
		return false
	if step.has("gun"):
		for wb: WallBuy in brain.squad.wall_buys():
			if is_instance_valid(wb) and String(wb.weapon_id) == str(step["gun"]) and wb.is_visible_in_tree():
				return brain.reachable(BotBrain._front_of(wb))
		return false
	return false
