extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Ballast v2 smoke (UPDATE 10 contract C2, design section 3, DECISIONS T-153): lifting a coffin limits the hands to
## melee and the pistol; the crane load pays the bonus and counts; three dumps at the sea stairs count, queue a
## Glasshide each for the next round, leave the Undertow's shard and set the egg's flag; gone coffins come back on a
## pallet; a bot carries a coffin through the `carry` task.


func _init() -> void:
	tag = "ballast2"
	bots = 1


func _carry_and(dest: Interactable, coffin: BallastCoffin) -> void:
	await _tp(coffin.global_position + Vector3(0, 0.2, 1.2))
	await _use(coffin)
	await _tp(dest.global_position + Vector3(0, 0.2, 1.0))
	await _use(dest)


func _free_coffin() -> BallastCoffin:
	for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
		var c: BallastCoffin = n as BallastCoffin
		if c != null and not c.delivered and c.carrier == 0:
			return c
	return null


func _body() -> void:
	var hook: BallastHook = _g("BallastHook") as BallastHook
	var dump: BallastDump = _g("BallastDump") as BallastDump
	_check(hook != null and dump != null, "the crane hook and the sea-stairs dump are placed")
	_p.weapons.give_weapon(&"m1_garand")
	_check(_p.weapons.pistol_slot() >= 0, "the human holds a pistol")
	# --- the carry limit
	var c0: BallastCoffin = _free_coffin()
	await _tp(c0.global_position + Vector3(0, 0.2, 1.2))
	await _use(c0)
	await _frames(30)
	_check(c0.carrier == 1 and _p.weapons.carry_limited, "lifting a coffin limits the hands")
	_check(WeaponHolder.carry_allows(_p.weapons.current()), "and switches to the pistol (%s)" % (_p.weapons.current().id if _p.weapons.current() != null else "none"))
	# --- load on the crane: the bonus and the counter
	var scrip: int = Economy.get_scrip(1)
	await _tp(hook.global_position + Vector3(0, 0.2, 1.0))
	await _use(hook)
	_check(int(GameState.flags.get(&"ballast_loaded", 0)) == 1, "the crane counts one loaded")
	_check(Economy.get_scrip(1) >= scrip + int(GLData.table("economy")["ballast_load_bonus"]), "the load paid the bonus (%d -> %d)" % [scrip, Economy.get_scrip(1)])
	_check(not _p.weapons.carry_limited, "the hands are free again")
	# --- three dumps
	for i: int in 3:
		var c: BallastCoffin = _free_coffin()
		if c == null:
			await _until(func() -> bool: return _free_coffin() != null, 30.0)
			c = _free_coffin()
		_check(c != null, "a coffin is on a pallet for dump %d" % (i + 1))
		if c == null:
			return
		await _carry_and(dump, c)
	_check(int(GameState.flags.get(&"ballast_dumped", 0)) == 3, "three dumped (%d)" % int(GameState.flags.get(&"ballast_dumped", 0)))
	_check(RoundManager.pending_extra(&"glasshide") == 3, "three Glasshides queued for the next round")
	_check(GameState.has_flag(&"lf_ballast_done"), "the egg's ballast thread is done (lf_ballast_done)")
	_check(_g("Part_undertow_shard_sea_stairs") != null, "the third dump left the Undertow's shard on the sea stairs")
	# --- respawn
	var back: bool = await _until(func() -> bool:
		var n2: int = 0
		for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
			if not (n as BallastCoffin).delivered:
				n2 += 1
		return n2 >= 2, 45.0)
	_check(back, "gone coffins come back on their pallets")
	# --- a bot carries (the carry task's plan, driven directly)
	var w: Dictionary = {"carrying": true, "deliver": dump, "deliver_ready": true, "pickups": []}
	var plan: Dictionary = BotEE.plan_carry({"pickups": {"group": "ballast_coffins"}, "deliver": {"group": "ballast_dumps"}}, w)
	_check(str(plan.get("do", "")) == "use" and plan.get("node") == dump, "a bot already carrying goes to deliver")
	var bot: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		bot = n as Player
	if bot != null:
		var cb: BallastCoffin = _free_coffin()
		bot.global_position = cb.global_position + Vector3(0, 0.2, 1.2)
		await _frames(3)
		cb.interact(bot)
		await _frames(5)
		_check(cb.carrier == bot.player_id and bot.weapons.carry_limited, "a bot lifts a coffin (and its hands are limited)")
		bot.global_position = dump.global_position + Vector3(0, 0.2, 1.0)
		await _frames(3)
		dump.interact(bot)
		await _frames(3)
		_check(int(GameState.flags.get(&"ballast_dumped", 0)) == 4, "and dumps it")
