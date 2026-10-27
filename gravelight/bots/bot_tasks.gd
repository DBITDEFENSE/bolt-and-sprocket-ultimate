class_name BotTasks
extends RefCounted
## Errand executors (Update 03): the hands of the Buy / Repair / Crate / Order actions and of the local-AI
## planner's objectives, moved here from the T-031 brain. A task is a Dictionary {node, kind, label, ...}; run()
## walks to it (the locomotion layer), uses it the way a person's hold does (interact, lock_frequency, plug, a real
## traced shot) and returns "running", "done" or "failed". The brain owns the claim and tells the planner.
##   shopping kinds: repair, gun, ammo, perk, ammo_box, door, crucible, crate, use_power
##   objective kinds (the planner only): use, radio, switchboard, shoot, shoot_seq, shoot_moving, hold, crate,
##   fetch (a buildable part, ordered)

const OBJECTIVE_KINDS: PackedStringArray = ["use", "radio", "switchboard", "shoot", "shoot_seq", "shoot_moving", "hold"]

var brain: BotBrain
var player: Player
var _path_check_t: float = 0.0


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player


func run(e: Dictionary, delta: float) -> String:
	var node: Node3D = e.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		return "done" if str(e.get("kind", "")) == "shoot_moving" else "failed"
	if brain.squad.time() > float(e.get("until", INF)):
		return "failed"
	var kind: String = str(e.get("kind", ""))
	if OBJECTIVE_KINDS.has(kind) or (kind == "crate" and e.has("id")):
		return _objective(e, node, delta)
	if kind == "crate":
		return _crate(delta, e, node as MysteryCrate)
	if kind == "fetch":
		return _fetch(delta, e, node)
	return _shop(e, node as Interactable, delta)


## Walk toward `p`; true once within `tol` (flat) on the same floor. Gives up on the task (e["state"] =
## "failed") after 4 s without a route.
func walk_to(p: Vector3, tol: float, e: Dictionary, delta: float) -> bool:
	var me: Vector3 = player.global_position
	if _flat(p, me) <= tol and absf(p.y - me.y) < 1.8:
		brain.loco.stop()
		e["nopath_t"] = 0.0
		return true
	brain.loco.move_to(p, 0.75 if _flat(p, me) > 9.0 and brain.aim.target == null else 0.35, tol * 0.8)
	_path_check_t -= delta
	if _path_check_t <= 0.0:
		_path_check_t = 0.5
		if brain.loco.path_length_to(p) == INF:
			e["nopath_t"] = float(e.get("nopath_t", 0.0)) + 0.5
			if float(e["nopath_t"]) > 4.0:
				e["state"] = "failed"
		else:
			e["nopath_t"] = 0.0
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)
	return false


func _look(p: Vector3) -> void:
	brain.loco.look_at_dir(p - brain.aim.eye())


# ================================================================== shopping

func _shop(e: Dictionary, node: Interactable, delta: float) -> String:
	if node == null:
		return "failed"
	var kind: String = str(e["kind"])
	var me: Vector3 = player.global_position
	var front: Vector3 = BotBrain._door_side(node as BuyDoor, me) if node is BuyDoor else (e["stand"] as Vector3 if e.get("stand", Vector3.INF) != Vector3.INF else BotBrain._front_of(node))
	if _flat(front, me) > 0.9 or absf(front.y - me.y) > 1.8:
		e["hold"] = 0.0
		walk_to(brain.snap(front), 0.8, e, delta)
		return str(e.get("state", "running"))
	brain.loco.stop()
	var aim: Vector3 = node.area.global_position if node.area != null else node.global_position + Vector3.UP
	if brain.crucible_sticky() and brain.aim.target != null:
		brain.aim.update(delta, true)   # waiting on the forge with zombies about: shoot from the alcove
	else:
		_look(aim)
	e["hold"] = float(e.get("hold", 0.0)) + delta
	if player.remote_body != null:
		player.remote_body.hold_action(&"repair" if kind == "repair" else &"buy")
	brain.committed = true
	if float(e["hold"]) < maxf(0.05, node.hold_time(player)):
		return "running"
	e["hold"] = 0.0
	var done: bool = true
	if kind == "crucible":
		done = _crucible(node as Crucible, e)
	else:
		if kind == "gun" and player.weapons.slots.size() >= player.weapons.max_slots():
			var give: int = brain._slot_to_give_up()
			if give < 0:
				return "failed"
			if give != player.weapons.current_index:
				brain.aim.select(give)
				return "running"
		if kind == "ammo_box" or kind == "ammo":
			var want_slot: int = int(e.get("slot", -1))
			if want_slot >= 0 and want_slot < player.weapons.slots.size() and want_slot != player.weapons.current_index:
				brain.aim.select(want_slot)
				return "running"
		if kind == "ammo_box" and int(brain.options.get("ammo_payer_pid", 0)) > 0:
			# a companion: refilled from the party's Scrip at its price multiplier (Jakub: half price)
			(node as AmmoBox).use_holder(player.weapons, player.player_id, int(brain.options["ammo_payer_pid"]), float(brain.options.get("ammo_price_mult", 0.5)))
		elif node.can_interact(player):
			node.interact(player)
		if kind == "repair":
			done = not (node is Barricade and (node as Barricade).boards < (node as Barricade).max_boards)
			if done:
				brain.squad.callout(brain, "BOARD")
		elif kind == "door" and (node as BuyDoor).is_open:
			brain.doors_bought_round += 1
			brain.doors_bought_total += 1
	return "done" if done else "running"


## One hold at the Crucible: feed the gun (wait out the forge in front of it, take our own result only). True when
## the task is over. (The Crucible sells no ammo, T-083: a taught gun refills at an ammo box like any other.)
func _crucible(cr: Crucible, e: Dictionary) -> bool:
	if not cr.is_powered():
		return true
	var fed: bool = bool(e.get("fed", false))
	match cr.phase:
		Crucible.Phase.IDLE:
			if fed:
				return true
			var teach: int = brain._upgradeable_slot()
			if teach < 0:
				return true
			if teach != player.weapons.current_index:
				brain.aim.select(teach)   # T-121: the gun it means to teach (its best), not just whatever is in hand
				return false
			if cr.can_interact(player):
				cr.interact(player)
			e["fed"] = cr.phase == Crucible.Phase.FORGING and cr._fed_by == player.player_id
			if bool(e["fed"]):
				e["until"] = brain.squad.time() + cr.forge_seconds + cr.offer_seconds + 10.0
			return not bool(e["fed"])
		Crucible.Phase.FORGING:
			return not fed
		Crucible.Phase.OFFERED:
			if cr._fed_by != player.player_id:
				return not fed   # never a teammate's weapon
			cr.interact(player)
			brain.aim.cancel_reload()
			brain.aim.swap_t = BotAim.SWAP_TIME
			if player.remote_body != null:
				var w: WeaponInstance = player.weapons.current()
				player.remote_body.set_weapon(w.id if w != null else &"")
			brain.upgrades += 1
			return true
	return true


## The Requisition Crate: pay, wait out the cycle, take the gun when it beats the worst held one (never trading an
## upgraded gun); never someone else's roll.
func _crate(delta: float, e: Dictionary, crate: MysteryCrate) -> String:
	if crate == null:
		return "failed"
	var paid: bool = bool(e.get("paid", false))
	match crate.phase:
		MysteryCrate.Phase.CLOSED:
			if paid:
				return "done"
			if not walk_to(e.get("stand", crate.global_position), 0.6, e, delta):
				e["hold"] = 0.0
				return str(e.get("state", "running"))
			_look(crate.global_position + Vector3.UP * 0.6)
			e["hold"] = float(e.get("hold", 0.0)) + delta
			brain.committed = true
			if float(e["hold"]) < 0.5:
				return "running"
			if Economy.get_scrip(player.player_id) < CrateManager.cost():
				return "failed"
			crate.interact(player)
			e["paid"] = crate.phase != MysteryCrate.Phase.CLOSED
			e["until"] = brain.squad.time() + 25.0
			if bool(e["paid"]):
				brain.economy.crate_pulls_this_round += 1
				if player.remote_body != null:
					player.remote_body.play_action(&"buy")
			return "running" if bool(e["paid"]) else "failed"
		MysteryCrate.Phase.CYCLING:
			if not paid:
				return "failed"   # someone else's roll
			brain.committed = true
			_look(crate.global_position + Vector3.UP * 0.8)
			return "running"
		MysteryCrate.Phase.OFFERED:
			if not paid or int(crate.get("_owner_player")) != player.player_id:
				return "failed"   # never the player's roll
			var got: StringName = StringName(str(crate.get("_result")))
			if brain.wants_crate_weapon(got):
				if player.weapons.slots.size() >= player.weapons.max_slots():
					var give: int = brain._slot_to_give_up()
					if give < 0:
						return "done"
					if give != player.weapons.current_index:
						brain.aim.select(give)
						return "running"
				crate.interact(player)
				if player.remote_body != null:
					var w: WeaponInstance = player.weapons.current()
					player.remote_body.set_weapon(w.id if w != null else &"")
			return "done"
	return "done" if paid else "failed"


## An ordered "Fetch part": walk to the buildable part the human pointed at and pick it up.
func _fetch(delta: float, e: Dictionary, node: Node3D) -> String:
	var it: Interactable = node as Interactable
	if it == null or not it.can_interact(player) or not it.is_visible_in_tree():
		return "done" if bool(e.get("touched", false)) else "failed"
	var st: Vector3 = e.get("stand", Vector3.INF)
	if st == Vector3.INF:
		st = brain.stand_point(node)
		e["stand"] = st
		if st == Vector3.INF:
			return "failed"
	if not walk_to(st, 0.7, e, delta):
		return str(e.get("state", "running"))
	_look(node.global_position)
	e["hold"] = float(e.get("hold", 0.0)) + delta
	brain.committed = true
	if float(e["hold"]) < maxf(0.3, it.hold_time(player)):
		return "running"
	it.interact(player)
	e["touched"] = true
	return "done"


# ================================================================== the planner's objectives

func _objective(e: Dictionary, node: Node3D, delta: float) -> String:
	match str(e["kind"]):
		"use":
			_obj_use(delta, e, node)
		"radio", "switchboard":
			_obj_inputs(delta, e, node)
		"shoot":
			_obj_shoot(delta, e, node)
		"shoot_seq":
			_obj_bells(delta, e)
		"shoot_moving":
			_obj_moving(delta, e, node)
		"hold":
			_obj_hold(delta, e, node)
		"crate":
			e["state"] = _crate(delta, e, node as MysteryCrate)
		_:
			e["state"] = "failed"
	return str(e.get("state", "running"))


func _obj_use(delta: float, e: Dictionary, node: Node3D) -> void:
	var it: Interactable = node as Interactable
	if it == null or not it.can_interact(player):
		e["state"] = "failed"
		return
	if not walk_to(e.get("stand", node.global_position), 0.6, e, delta):
		e["hold"] = 0.0
		return
	_look(it.area.global_position if it.area != null else node.global_position)
	e["hold"] = float(e.get("hold", 0.0)) + delta
	brain.committed = true
	if float(e["hold"]) < maxf(0.3, it.hold_time(player)):
		return
	it.interact(player)
	if it is Pylon and (it as Pylon).state == Pylon.State.CHARGING:
		e["kind"] = "hold"
		e["cond"] = "pylon"
		e["pos"] = brain.snap(it.global_position)
		e["radius"] = (it as Pylon).radius * 0.45
		e["until"] = brain.squad.time() + 120.0
		return
	e["state"] = "done"


func _obj_inputs(delta: float, e: Dictionary, node: Node3D) -> void:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	if QuestManager.is_step_done(qid, sid):
		e["state"] = "done"
		return
	if not QuestManager.is_active(qid, sid):
		e["state"] = "failed"
		return
	if not walk_to(e.get("stand", node.global_position), 0.6, e, delta):
		e["hold"] = 0.0
		return
	_look(node.global_position + Vector3.UP * 0.3)
	e["hold"] = float(e.get("hold", 0.0)) + delta
	brain.committed = true
	if float(e["hold"]) < 0.9:
		return
	e["hold"] = 0.3
	var inputs: Array = QuestManager.sequence_inputs(qid, sid)
	var prog: Variant = QuestManager.progress(qid, sid)
	var idx: int = int(prog) if prog != null else 0
	if idx >= inputs.size():
		e["state"] = "done"
		return
	var res: String = ""
	if node is FieldRadio:
		res = (node as FieldRadio).lock_frequency(str(inputs[idx]))
	elif node is Switchboard:
		res = (node as Switchboard).plug(int(str(inputs[idx])))
	if res == "done":
		e["state"] = "done"
	elif res != "ok":
		e["tries"] = int(e.get("tries", 0)) + 1
		if int(e["tries"]) > 3:
			e["state"] = "failed"


func _obj_shoot(delta: float, e: Dictionary, node: Node3D) -> void:
	if bool(e.get("need_upgraded", false)) and brain.forced_slot() < 0:
		e["state"] = "failed"
		return
	if str(e.get("cond", "")) != "" and _cond_met(e, node):
		e["state"] = "done"
		return
	if not walk_to(e.get("vantage", node.global_position), 0.8, e, delta):
		return
	var aim: Vector3 = node.global_position + (e.get("aim_offset", Vector3.ZERO) as Vector3)
	if brain.aim.shoot_at(aim, 1.2):
		e["shots"] = int(e.get("shots", 0)) + 1
		if int(e["shots"]) > 14:
			e["state"] = "failed"


func _obj_bells(delta: float, e: Dictionary) -> void:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	if QuestManager.is_step_done(qid, sid):
		e["state"] = "done"
		return
	var inputs: Array = QuestManager.sequence_inputs(qid, sid)
	var prog: Variant = QuestManager.progress(qid, sid)
	var idx: int = int(prog) if prog != null else 0
	if idx >= inputs.size():
		e["state"] = "done"
		return
	var note: String = str(inputs[idx])
	var bells: Dictionary = e.get("bells", {})
	var bell: Node3D = bells.get(note) as Node3D
	if bell == null or not is_instance_valid(bell):
		e["state"] = "failed"
		return
	var vps: Dictionary = e.get("vantages", {})
	if not vps.has(note):
		vps[note] = brain.vantage_for(bell.global_position)
		e["vantages"] = vps
	var vp: Vector3 = vps[note]
	if vp == Vector3.INF:
		e["state"] = "failed"
		return
	if not walk_to(vp, 0.8, e, delta):
		return
	if int(e.get("at_idx", -1)) != idx:
		e["at_idx"] = idx
		e["shots"] = 0
	if brain.aim.shoot_at(bell.global_position, 1.0):
		e["shots"] = int(e["shots"]) + 1
		brain.aim.fire_cd = maxf(brain.aim.fire_cd, 0.6)
		if int(e["shots"]) > 10:
			e["state"] = "failed"


func _obj_moving(_delta: float, e: Dictionary, node: Node3D) -> void:
	var aim: Vector3 = node.global_position + Vector3.UP * 0.35
	var d: float = brain.aim.eye().distance_to(aim)
	if d < 32.0 and brain.los_point(brain.aim.eye(), aim):
		brain.loco.stop()
		brain.aim.shoot_at(aim, 2.0)
		return
	brain.loco.move_to(node.global_position, 0.8, 1.0)
	_look(aim)


func _obj_hold(delta: float, e: Dictionary, node: Node3D) -> void:
	if _cond_met(e, node):
		e["state"] = "done"
		return
	var p: Vector3 = e.get("pos", node.global_position)
	var r: float = float(e.get("radius", 2.0))
	brain.committed = true
	if _flat(p, player.global_position) > r or absf(p.y - player.global_position.y) > 1.8:
		brain.loco.move_to(p, 0.4, r * 0.6)
		brain.aim.update(delta, true)
		return
	brain.loco.stop()
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


func _cond_met(e: Dictionary, node: Node3D) -> bool:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	match str(e.get("cond", "")):
		"pylon":
			return not (node is Pylon) or (node as Pylon).state != Pylon.State.CHARGING
		"bell_lit":
			return GameState.has_flag(&"chapel_bell_lit") or QuestManager.is_step_done(qid, sid)
		"chapel":
			return QuestManager.is_step_done(qid, sid) or not GameState.has_flag(&"chapel_bell_lit")
		"step":
			return QuestManager.is_step_done(qid, sid) or not QuestManager.is_active(qid, sid)
		"holdout":
			return QuestManager.is_step_done(qid, sid) or QuestManager.holdout_state(qid, sid).is_empty()
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
