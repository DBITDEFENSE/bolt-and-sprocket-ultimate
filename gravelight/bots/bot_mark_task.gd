class_name BotMarkTask
extends RefCounted
## One bot's map-mark order (Update 04 section 3, DECISIONS T-069), given by the squad's BotMarkOrders. The brain
## runs it as the utility action "mark_order" (actions.json: weight 0.93 on value(), falling with pressure; a
## revive at 1.25 wins, and the order resumes after: "Back to it."). Tuning: data/gravelight/ai/marks.json.
##
## Kinds (order.kind):
##   buy       walk to the machine / wall / door / crate / Crucible / trap / Armorer's Bench and buy it with its own
##             Scrip (sub: perk, gun, ammo, ammo_box, door, crate, crucible, crucible_ammo, trap, bench, power).
##             Short of Scrip it says how much ("Need 600 more for that, boss.") and waits (queue_s, 60 s) while it
##             earns, then goes; for_pid > 0 (a wall weapon marked "for me") it buys the gun for that player: pays,
##             carries it (a WeaponParcel the player can take off it) and drops it at their feet.
##   go        walk there and wait (go_wait_s);   defend   hold within defend_radius_m, fight from there, rebuild
##   regroup   come to the spot (every bot);                windows within defend_repair_m
##   powerup   walk over a power-up;   collect (EE) runs in BotEE: this only tracks it for the map's status line.
## States: go (on the way), wait_scrip, use (at it), deliver, hold, done.

var brain: BotBrain
var player: Player
var order: Dictionary = {}
var history: PackedStringArray = []
var bought: int = 0
var gave_up: int = 0
var resumed: int = 0

var _cfg: Dictionary = {}
var _errand: Dictionary = {}
var _scrip_at_use: int = -1
var _arrived_t: float = -1.0
var _was_away: bool = false
var _parcel: WeaponParcel = null
var _hold_ring: Vector3 = Vector3.INF
var _repair: Dictionary = {}


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player
	_cfg = BotAIData.table("marks")


func cfg() -> Dictionary:
	return _cfg


func active() -> bool:
	return not order.is_empty()


func _now() -> float:
	return brain.squad.time()


# ================================================================== the pure rules (unit-tested)

## Scrip missing for `price` (0 = it can pay).
static func short_by(scrip: int, price: int, keep: int = 0) -> int:
	return maxi(0, price + keep - scrip)


## The amount a bot says it is short: the next bucket at or above `short` (marks.json lines.short_buckets), -1
## above the last ("a lot more").
static func short_bucket(short: int, buckets: Array) -> int:
	for b: Variant in buckets:
		if short <= int(b):
			return int(b)
	return -1


## The VO category for being short (MARK_SHORT_600, MARK_SHORT_LOTS).
static func short_category(short: int, buckets: Array) -> String:
	var b: int = short_bucket(short, buckets)
	return "MARK_SHORT_LOTS" if b < 0 else "MARK_SHORT_%d" % b


## Has a queued (waiting-for-Scrip) order run out? `wait_since` < 0: it isn't waiting.
static func queue_expired(wait_since: float, now: float, queue_s: float) -> bool:
	return wait_since >= 0.0 and now - wait_since >= queue_s


## The utility input for an order state: 0 while it waits for Scrip, is done, or is an easter-egg task (BotEE runs
## that one), else the kind's value (marks.json value).
static func value_for(kind: String, state: String, ee: bool, values: Dictionary) -> float:
	if kind == "" or ee or state == "wait_scrip" or state == "done":
		return 0.0
	if state == "deliver":
		return float(values.get("deliver", 0.85))
	return float(values.get(kind, 0.8))


# ================================================================== lifetime

## Starts an order (BotMarkOrders.place_order built it): says the acknowledgement and pings the spot.
func start(o: Dictionary) -> void:
	if active():
		cancel("replaced", false)
	order = o.duplicate()
	order["created"] = _now()
	order["state"] = "go"
	order["wait_since"] = -1.0
	order["interrupted"] = false
	_errand = {}
	_arrived_t = -1.0
	_hold_ring = Vector3.INF
	_repair = {}
	_was_away = false
	_scrip_at_use = -1
	brain.drop_task()
	_log("start %s %s %s" % [order.get("kind", ""), order.get("sub", ""), order.get("label", "")])
	if bool(order.get("ee", false)):
		return   # BotEE said its own acknowledgement
	var at: Vector3 = target_pos() + Vector3.UP * 1.2
	var ping: String = str(order.get("label", "")).to_upper()
	match str(order.get("kind", "")):
		"buy":
			var short: int = _short()
			if int(order.get("for_pid", 0)) > 0:
				_say(["MARK_ACK_FOR_YOU", "MARK_ACK_BUY", "MARK_ACK"], at, ping)
			else:
				_say(["MARK_ACK_BUY", "MARK_ACK"], at, ping)
			if short > 0:
				_enter_wait(short)
		"go":
			_say(["MARK_ACK_GO", "MARK_ACK"], at, "GO")
		"defend":
			_say(["MARK_ACK_DEFEND", "MARK_ACK"], at, "DEFEND")
		"regroup":
			_say(["MARK_ACK_REGROUP", "MARK_ACK"], at, "REGROUP")
		_:
			_say(["MARK_ACK"], at, ping)
	brain._think_t = 0.0


## Ends the order without finishing it (a new order, the player removed the mark, the mark expired).
func cancel(why: String = "cancelled", tell_orders: bool = true) -> void:
	if not active():
		return
	_log("cancel (%s)" % why)
	var o: Dictionary = order
	_release()
	order = {}
	if _parcel != null and is_instance_valid(_parcel) and _parcel.carried:
		_parcel.drop_at(player.global_position)   # paid for: it stays on the floor for its owner
	_parcel = null
	if tell_orders and brain.squad.mark_orders != null:
		brain.squad.mark_orders.order_ended(brain, o, false, why)


func _finish(ok: bool, code: String = "") -> void:
	if not active():
		return
	_log("%s %s" % ["done" if ok else "failed", code])
	var o: Dictionary = order
	_release()
	order = {}
	_parcel = null
	if brain.squad.mark_orders != null:
		brain.squad.mark_orders.order_ended(brain, o, ok, code)
	brain._think_t = 0.0


func _release() -> void:
	var n: Variant = order.get("node")
	if n is Node and is_instance_valid(n):
		brain.squad.release(n as Node, player.player_id)
	if not _repair.is_empty():
		brain.squad.blackboard.release(str(_repair.get("key", "")), player.player_id)
		_repair = {}
	_errand = {}


func _log(s: String) -> void:
	history.append("%.0f %s" % [_now(), s])
	if history.size() > 24:
		history.remove_at(0)


# ================================================================== the brain's hooks

## The mark_order action's input (BotBrain.context).
func value() -> float:
	if not active():
		return 0.0
	return value_for(str(order.get("kind", "")), str(order.get("state", "")), bool(order.get("ee", false)), _cfg.get("value", {}))


## A bot on an order of its own doesn't trail the leader when it fights (BotBrain.roaming).
func roaming() -> bool:
	return active() and not bool(order.get("ee", false)) and str(order.get("state", "")) != "wait_scrip"


## Each think: expiry, the Scrip check, the revive interruption, the done conditions.
func tick_think(now: float) -> void:
	if not active():
		return
	if bool(order.get("ee", false)):
		var t: Dictionary = brain.squad.ee_task_of(player.player_id)
		var en: Variant = order.get("node")
		var gone: bool = not (en is Node3D) or not is_instance_valid(en) or not (en as Node3D).is_visible_in_tree()
		if (t.is_empty() or gone) and now - float(order.get("created", now)) > 1.0:
			_finish(true, "ee task over" if t.is_empty() else "marked object done")   # the step itself may go on
		return
	var away: String = away_kind(brain.action, player.downed, player.spectating)
	if away != "":
		_was_away = true
		if away == "revive":
			order["interrupted"] = true
		if away == "down":
			return
	if now - float(order.get("created", now)) > float(_cfg.get("order_s", 120.0)) and str(order.get("kind", "")) != "defend":
		_finish(false, "timed out")
		return
	var node: Variant = order.get("node")
	var kind: String = str(order.get("kind", ""))
	if (kind == "buy" or kind == "powerup") and not (node is Node and is_instance_valid(node)):
		_finish(str(order.get("state", "")) == "deliver", "gone")
		return
	if kind == "buy":
		if _already_done():
			if str(order.get("state", "")) != "deliver":
				_finish(true, "already")
			return
		var st: String = str(order.get("state", ""))
		if st == "wait_scrip":
			var sh: int = _short()
			if sh <= 0:
				order["state"] = "go"
				order["wait_since"] = -1.0
				order["short"] = 0
				_say(["MARK_AFFORD", "MARK_ACK_BUY"], target_pos() + Vector3.UP * 1.2, str(order.get("label", "")).to_upper())
			elif queue_expired(float(order.get("wait_since", -1.0)), now, float(_cfg.get("queue_s", 60.0))):
				gave_up += 1
				_say(["MARK_EXPIRED", "MARK_CANT"])
				_finish(false, "expired")
			else:
				order["short"] = sh
		elif st == "go" and _short() > 0 and _scrip_at_use < 0:
			_enter_wait(_short())
	elif kind == "go" or kind == "regroup":
		if _arrived_t >= 0.0:
			var stay: float = float(_cfg.get("go_wait_s", 45.0)) if kind == "go" else float(_cfg.get("regroup_linger_s", 6.0))
			if now - _arrived_t >= stay:
				_finish(true, "waited")
	elif kind == "defend":
		if now - float(order.get("created", now)) > float(_cfg.get("defend_s", 90.0)):
			_finish(true, "held")


## Why a bot is off its order now: "revive" (reviving or covering a revive: the emergency that interrupts orders),
## "down" (downed or out), "" (it isn't).
static func away_kind(action: String, downed: bool, out: bool) -> String:
	if downed or out:
		return "down"
	if action == "revive" or action == "cover":
		return "revive"
	return ""


## Back on the order after being away: say "Back to it." only when a revive interrupted it.
static func resume_due(was_away: bool, interrupted: bool) -> bool:
	return was_away and interrupted


## Back from a revive (or a down): "Back to it." once.
func _on_return() -> void:
	if _was_away and active():
		var say: bool = resume_due(_was_away, bool(order.get("interrupted", false)))
		_was_away = false
		if say:
			order["interrupted"] = false
			resumed += 1
			_say(["MARK_RESUME", "EE_RESUME"])


func on_exit() -> void:
	if not _errand.is_empty() and str(_errand.get("kind", "")) != "":
		_errand["hold"] = 0.0
	brain.loco.stop()


## The executor: one physics frame of the order.
func run(delta: float) -> void:
	if not active():
		brain.loco.stop()
		return
	_on_return()
	match str(order.get("kind", "")):
		"buy":
			if str(order.get("state", "")) == "deliver":
				_deliver(delta)
			else:
				_buy(delta)
		"go", "regroup":
			_go(delta)
		"defend":
			_defend(delta)
		"powerup":
			_powerup(delta)
		_:
			brain.loco.stop()


# ================================================================== what it is and where

## Where the order points: its node's position (a machine moves with nothing, a crate does), else the mark's spot.
func target_pos() -> Vector3:
	var n: Variant = order.get("node")
	if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree():
		return (n as Node3D).global_position
	return order.get("pos", player.global_position)


## The price now (perks, wall guns, doors, the crate change; the bench's option is fixed).
func price() -> int:
	var n: Variant = order.get("node")
	var sub: String = str(order.get("sub", ""))
	if not (n is Node) or not is_instance_valid(n):
		return int(order.get("price", 0))
	match sub:
		"perk":
			return PerkManager.price((n as PerkMachine).perk_id)
		"gun":
			return (n as WallBuy).price()
		"ammo":
			return (n as WallBuy).ammo_price(player)
		"door":
			return (n as BuyDoor).cost
		"crate":
			return CrateManager.cost()
		"ammo_box":
			var w: WeaponInstance = _ammo_gun()
			return AmmoBox.price_for(w.data, w.upgraded, AmmoBox.cfg()) if w != null else int(order.get("price", 250))
		"crucible":
			var up: int = brain._upgradeable_slot()
			return Crucible.price_for(&"upgrade", GLData.table("economy"), player.weapons.slots[up].tier if up >= 0 else 0)
		"crucible_ammo":
			return Crucible.price_for(&"ammo", GLData.table("economy"))
		"trap":
			var t: Node = (n as TrapLever).trap() if n is TrapLever else null
			return int(t.call("cost")) if t != null and t.has_method("cost") else int(order.get("price", 0))
		"bench":
			var bs: String = str(order.get("slot", ""))
			var bo: String = str(order.get("option", ""))
			return WeaponKit.price(WeaponKit.gun_of(player, bs, bo), bs, bo)
	return int(order.get("price", 0))


func _short() -> int:
	return short_by(Economy.get_scrip(player.player_id), price(), int(_cfg.get("reserve_kept", 0)))


func _enter_wait(short: int) -> void:
	order["state"] = "wait_scrip"
	order["wait_since"] = _now()
	order["short"] = short
	brain.loco.stop()
	var lc: Dictionary = _cfg.get("lines", {})
	_say([short_category(short, lc.get("short_buckets", [])), "MARK_SHORT"])


## The thing is already bought / open / owned (someone else did it, or it just happened).
func _already_done() -> bool:
	var n: Variant = order.get("node")
	if not (n is Node) or not is_instance_valid(n):
		return false
	match str(order.get("sub", "")):
		"door":
			return (n as BuyDoor).is_open
		"perk":
			return PerkManager.has_perk(player.player_id, (n as PerkMachine).perk_id)
		"power":
			return GameState.power_on
		"bench":
			var hs: String = str(order.get("slot", ""))
			var ho: String = str(order.get("option", ""))
			return WeaponKit.has_option(WeaponKit.gun_of(player, hs, ho), hs, ho)
	return false


func _ammo_gun() -> WeaponInstance:
	var slot: int = int(order.get("slot", -1))
	if slot >= 0 and slot < player.weapons.slots.size():
		return player.weapons.slots[slot]
	return brain.economy._main_gun()


# ================================================================== executors

func _buy(delta: float) -> void:
	if str(order.get("state", "")) == "wait_scrip":
		brain.loco.stop()
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	var sub: String = str(order.get("sub", ""))
	var node: Node3D = order.get("node") as Node3D
	if sub == "bench":
		_bench(delta, node as ArmorersBench)
		return
	if sub == "gun" and int(order.get("for_pid", 0)) > 0:
		_buy_for(delta, node as WallBuy)
		return
	if _errand.is_empty():
		_errand = {"node": node, "kind": sub, "label": str(order.get("label", "")), "until": INF}
		if sub == "crate":
			_errand["stand"] = brain.stand_point(node)
		if sub == "ammo_box" or sub == "ammo" or sub == "crucible_ammo":
			_errand["slot"] = int(order.get("slot", -1))
		brain.squad.claim(node, player.player_id)
	var me: Vector3 = player.global_position
	var close: bool = BotTasks._flat(target_pos(), me) < 3.0
	if close and _scrip_at_use < 0:
		_scrip_at_use = Economy.get_scrip(player.player_id)
		_hold_auto_lines(sub)
	var r: String = brain.tasks.run(_errand, delta)
	if r == "running":
		return
	var paid: bool = _scrip_at_use >= 0 and Economy.get_scrip(player.player_id) < _scrip_at_use
	if sub == "gun" and node is WallBuy and player.weapons.find_weapon_base((node as WallBuy).weapon_id) != null:
		paid = true
	if r == "done" and (paid or _already_done() or sub == "power"):
		bought += 1
		_say(_bought_lines(sub), target_pos() + Vector3.UP * 1.3, "")
		_finish(true, "bought")
		return
	if r == "failed" and str(_errand.get("state", "")) == "failed":
		_say(["MARK_CANT_REACH", "MARK_CANT"])
		_finish(false, "no path")
		return
	_say(["MARK_CANT"])
	_finish(false, "could not buy (%s)" % r)


## The Armorer's Bench: walk to its stand point, buy the slot / option (the player's pick, or the bot's).
func _bench(delta: float, bench: ArmorersBench) -> void:
	if bench == null:
		_finish(false, "no bench")
		return
	var st: Vector3 = brain.snap(bench.stand_point())
	if _errand.is_empty():
		_errand = {"node": bench, "kind": "bench", "until": INF}
	if not brain.tasks.walk_to(st, 0.8, _errand, delta):
		if str(_errand.get("state", "")) == "failed":
			_say(["MARK_CANT_REACH", "MARK_CANT"])
			_finish(false, "no path")
		return
	brain.loco.look_at_dir(bench.global_position + Vector3.UP - brain.aim.eye())
	_errand["hold"] = float(_errand.get("hold", 0.0)) + delta
	brain.committed = true
	if player.remote_body != null:
		player.remote_body.hold_action(&"buy")
	if float(_errand["hold"]) < 0.8:
		return
	_hold_auto_lines("bench")
	var res: Dictionary = ArmorersBench.buy(player, str(order.get("slot", "")), str(order.get("option", "")))
	if bool(res.get("ok", false)):
		bought += 1
		_say(["MARK_BOUGHT_BENCH", "MARK_BOUGHT"], bench.global_position + Vector3.UP * 1.2, "")
		_finish(true, "bought")
	elif str(res.get("reason", "")) == "no_scrip":
		_errand["hold"] = 0.0
		_enter_wait(_short())
	else:
		_say(["MARK_CANT"])
		_finish(false, "bench: %s" % res.get("reason", ""))


## "Buy for teammate": pay at the wall with its own Scrip (the gun doesn't go in its hands), then carry it over.
func _buy_for(delta: float, wb: WallBuy) -> void:
	if wb == null:
		_finish(false, "no wall")
		return
	if _errand.is_empty():
		_errand = {"node": wb, "kind": "gun_for", "until": INF}
		brain.squad.claim(wb, player.player_id)
	var front: Vector3 = brain.snap(BotBrain._front_of(wb))
	if not brain.tasks.walk_to(front, 0.8, _errand, delta):
		if str(_errand.get("state", "")) == "failed":
			_say(["MARK_CANT_REACH", "MARK_CANT"])
			_finish(false, "no path")
		return
	brain.loco.look_at_dir(wb.global_position - brain.aim.eye())
	_errand["hold"] = float(_errand.get("hold", 0.0)) + delta
	brain.committed = true
	if player.remote_body != null:
		player.remote_body.hold_action(&"buy")
	if float(_errand["hold"]) < maxf(0.3, wb.hold_time(player)):
		return
	var cost: int = wb.price()
	if not Economy.spend(player.player_id, StringName(String(wb.weapon_id) + "_for_teammate"), cost):
		_errand["hold"] = 0.0
		_enter_wait(_short())
		return
	AudioDirector.play_3d("buy", wb.global_position, -4.0)
	bought += 1
	brain.squad.release(wb, player.player_id)
	_parcel = WeaponParcel.make(wb.weapon_id, int(order["for_pid"]), player.player_id)
	_parcel.taken.connect(_on_parcel_taken)
	player.add_child(_parcel)
	_parcel.carry_on(player)
	order["state"] = "deliver"
	order["parcel"] = _parcel
	_errand = {}
	_say(["MARK_FOR_YOU_HOLD", "MARK_BOUGHT_GUN", "MARK_BOUGHT"], player.global_position + Vector3.UP * 1.8, str(order.get("label", "")).to_upper())


func _on_parcel_taken(_by: int) -> void:
	if active() and str(order.get("state", "")) == "deliver":
		_finish(true, "taken")


## Walks the bought gun over and drops it at the player's feet; while the player is down or out it holds it.
func _deliver(delta: float) -> void:
	if _parcel == null or not is_instance_valid(_parcel):
		_finish(true, "taken")
		return
	var to: Player = brain.squad.player_by_id(int(order.get("for_pid", 0)))
	if to == null or not is_instance_valid(to) or to.spectating or to.downed:
		brain.loco.stop()
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	if _errand.is_empty():
		_errand = {"kind": "deliver", "until": INF}
	var dm: float = float(_cfg.get("deliver_m", 2.2))
	if BotTasks._flat(to.global_position, player.global_position) > dm or absf(to.global_position.y - player.global_position.y) > 1.6:
		brain.loco.move_to(to.global_position, 0.7, dm * 0.7)
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	brain.loco.stop()
	var fwd: Vector3 = -to.global_basis.z
	fwd.y = 0.0
	var feet: Vector3 = brain.snap(to.global_position + (fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD) * 0.7)
	_parcel.drop_at(feet)
	_say(["MARK_FOR_YOU_DROP", "MARK_BOUGHT"], feet + Vector3.UP * 0.6, str(order.get("label", "")).to_upper())
	_parcel = null
	_finish(true, "delivered")


func _go(delta: float) -> void:
	var p: Vector3 = order.get("pos", player.global_position)
	var r: float = 1.4 if str(order.get("kind", "")) == "go" else float(_cfg.get("regroup_radius_m", 3.0))
	if _hold_ring == Vector3.INF:
		var ring: float = 0.0 if str(order.get("kind", "")) == "go" else 1.4
		var a: float = TAU * float(brain.index) / 4.0 + 0.4
		_hold_ring = brain.snap(p + Vector3(cos(a) * ring, 0.0, sin(a) * ring))
	if BotTasks._flat(_hold_ring, player.global_position) > r or absf(_hold_ring.y - player.global_position.y) > 1.8:
		brain.loco.move_to(_hold_ring, 0.75, r * 0.6)
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	if _arrived_t < 0.0:
		_arrived_t = _now()
	brain.loco.hold(_hold_ring, Vector3.ZERO)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## Hold within defend_radius_m of the spot, fight from there; between kills rebuild the windows close by.
func _defend(delta: float) -> void:
	var p: Vector3 = order.get("pos", player.global_position)
	var rad: float = float(_cfg.get("defend_radius_m", 4.0))
	brain.committed = true
	var fighting: bool = brain.aim.target != null and brain.perception.nearest_d < 14.0
	if not fighting and _repair.is_empty():
		_repair = _window_near(p)
	if not _repair.is_empty() and not fighting:
		var r: String = brain.tasks.run(_repair, delta)
		if r != "running":
			brain.squad.blackboard.release(str(_repair.get("key", "")), player.player_id)
			_repair = {}
		return
	if _hold_ring == Vector3.INF:
		var a: float = TAU * float(brain.index) / 4.0 + 0.4
		_hold_ring = brain.snap(p + Vector3(cos(a), 0.0, sin(a)) * minf(1.5, rad * 0.4))
	if BotTasks._flat(_hold_ring, player.global_position) > rad or absf(_hold_ring.y - player.global_position.y) > 1.8:
		brain.loco.move_to(_hold_ring, 0.75, 0.8)
	else:
		if _arrived_t < 0.0:
			_arrived_t = _now()
		brain.loco.hold(_hold_ring, Vector3.ZERO)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


func _window_near(p: Vector3) -> Dictionary:
	var now: float = _now()
	var rr: float = float(_cfg.get("defend_repair_m", 7.0))
	for n: Node in brain.get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or b.boards >= b.max_boards or BotTasks._flat(b.global_position, p) > rr or absf(b.global_position.y - p.y) > 2.5:
			continue
		var key: String = "repair:%d" % b.get_instance_id()
		if not brain.squad.blackboard.claim(key, player.player_id, "repair", now, now + 20.0):
			continue
		return {"node": b, "kind": "repair", "key": key, "label": "rebuild a window", "until": now + 20.0}
	return {}


func _powerup(delta: float) -> void:
	var n: Node3D = order.get("node") as Node3D
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		_finish(true, "taken")
		return
	brain.loco.move_to(n.global_position, 0.8, 0.3)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


# ================================================================== the voice

## The first category of `cats` the bot has a line for (forced through the squad's callout, with a ping).
func _say(cats: Array, at: Vector3 = Vector3.INF, text: String = "") -> bool:
	for c: Variant in cats:
		if brain.squad.callout(brain, str(c), true, at, text):
			return true
	return false


static func bought_categories(sub: String, perk_id: StringName = &"") -> Array:
	match sub:
		"perk":
			var tok: String = str(GLVO.PERK_TOKENS.get(perk_id, ""))
			return ["MARK_BOUGHT_" + tok, "MARK_BOUGHT"] if tok != "" else ["MARK_BOUGHT"]
		"gun":
			return ["MARK_BOUGHT_GUN", "MARK_BOUGHT"]
		"ammo", "ammo_box", "crucible_ammo":
			return ["MARK_BOUGHT_AMMO", "MARK_BOUGHT"]
		"door":
			return ["MARK_BOUGHT_DOOR", "MARK_BOUGHT"]
		"crate":
			return ["MARK_BOUGHT_CRATE", "MARK_BOUGHT"]
		"crucible":
			return ["MARK_BOUGHT_CRUCIBLE", "MARK_BOUGHT"]
		"trap":
			return ["MARK_BOUGHT_TRAP", "MARK_BOUGHT"]
		"bench":
			return ["MARK_BOUGHT_BENCH", "MARK_BOUGHT"]
		"power":
			return ["MARK_DONE_POWER", "MARK_BOUGHT"]
	return ["MARK_BOUGHT"]


func _bought_lines(sub: String) -> Array:
	var n: Variant = order.get("node")
	return bought_categories(sub, (n as PerkMachine).perk_id if n is PerkMachine and is_instance_valid(n) else &"")


## The automatic line VOManager would say for this purchase (PERK_, BUY_, DOOR, GUNSMITH) is held back for a moment:
## the order's confirmation says it instead.
func _hold_auto_lines(sub: String) -> void:
	var spk: StringName = GLVO.CHARACTER_SPEAKERS.get(player.character_id, &"")
	if spk == &"" or not GLVO.has_method("hold_category"):
		return
	var s: float = float((_cfg.get("lines", {}) as Dictionary).get("hold_auto_s", 4.0))
	var n: Variant = order.get("node")
	match sub:
		"perk":
			if n is PerkMachine and GLVO.PERK_TOKENS.has((n as PerkMachine).perk_id):
				GLVO.call("hold_category", spk, "PERK_" + str(GLVO.PERK_TOKENS[(n as PerkMachine).perk_id]), s)
		"gun":
			for tok: Variant in GLVO.CLASS_TOKENS.values():
				GLVO.call("hold_category", spk, "BUY_" + str(tok), s)
		"ammo", "ammo_box":
			GLVO.call("hold_category", spk, "BUY_AMMO", s)
		"door":
			GLVO.call("hold_category", spk, "DOOR", s)
		"bench":
			GLVO.call("hold_category", spk, "GUNSMITH", s)


# ================================================================== the map's status line

## "Going to buy Ironhide Stout (1,200 short)", "Defending Rail Yard", "Bringing you a Thompson"; "" without an order.
func status() -> String:
	if not active():
		return ""
	var label: String = str(order.get("label", ""))
	var where: String = str(order.get("where", ""))
	var st: String = str(order.get("state", ""))
	match str(order.get("kind", "")):
		"buy":
			if st == "deliver":
				var to: Player = brain.squad.player_by_id(int(order.get("for_pid", 0)))
				if to != null and (to.downed or to.spectating):
					return "Holding a %s for you" % label
				return "Bringing you a %s" % label
			var verb: String = "Going to open %s" % label if str(order.get("sub", "")) == "door" else "Going to buy %s" % label
			if int(order.get("for_pid", 0)) > 0:
				verb = "Going to buy you a %s" % label
			if st == "wait_scrip":
				var left: int = maxi(0, int(float(_cfg.get("queue_s", 60.0)) - (_now() - float(order.get("wait_since", _now())))))
				return "%s (%s short, %d s)" % [verb, MarkTargets.money(int(order.get("short", 0))), left]
			return verb
		"go":
			return ("Waiting at %s" if _arrived_t >= 0.0 else "Going to %s") % (where if where != "" else "the mark")
		"defend":
			return "Defending %s" % (where if where != "" else "the mark")
		"regroup":
			return "Regrouping at %s" % (where if where != "" else "the mark")
		"powerup":
			return "Going for the %s" % label
		"collect":
			var t: Dictionary = brain.squad.ee_task_of(player.player_id)
			return "Doing: %s" % str(t.get("label", label)) if not t.is_empty() else "Doing: %s" % label
	return label
