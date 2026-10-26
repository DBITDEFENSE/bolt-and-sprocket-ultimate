class_name AccountManager
extends HomageBoss
## THE ACCOUNT MANAGER, the finale (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.7, T-113): the Woman in Violet's
## executive machine, a tall ledger-faced unit of the Underwriter's family, her voice through it, attending remotely.
## She stands behind the console and never leaves it. Three contract phases by HP (bosses/map04.json
## "account_manager"): ONBOARDING (the welcome arms: a telegraphed 180° sweep in front of her; the console shielded),
## RENEWAL at `renewal_at` (the renewal clock starts on the MondlichtController; the trial tray appears: every perk
## for a minute, then all of them stripped; her Reinholt line when Dutch is present), COLLECTIONS at `collections_at`
## (the field drops; she prices players in range: a stamp at 90 damage and a tenth of their Scrip; the Kranich's
## crew through the pad every `crew.every` s; three shield-cells orbit her and take most of the damage until shot or
## flung into the vacuum shaft). Each phase is announced and "presented": for `present.seconds` her chest plate is
## open and the torso is the weak point (x`weak_mult`), again every `present.every` s. She never dies: at 0 % (or
## the failsafe) she ESCALATES: folds, says her line, the flag `manager_escalated` unlocks the console's cover.
## Nobody human dies in the finale; the dead are the horde's. Pure rules are static for the tests.

enum W { IDLE, ARMS_TELE, ARMS, PRICE_TELE, PRICE, RECOVER, FOLDED }

var wcfg: Dictionary = {}
var wstate: W = W.IDLE
var phase: int = 1
var station: Vector3 = Vector3.ZERO
var escalated: bool = false
var presenting: float = 0.0
var _present_t: float = 0.0
var _wt: float = 0.0
var _spawn_t: float = 0.0
var _price_target: Player = null
var _crew_t: float = 0.0
var _trial_t: float = -1.0
var _trial_cycle_t: float = 0.0
var _reinholt_t: float = -1.0
var _slots: Array[Dictionary] = []    # per cell: {cell: ShieldCell|null, regen: float (<0 idle), lost: bool}
var _title_done: bool = false
var trial: Node3D = null
var trial_takers: Array[int] = []
var arms_done: int = 0
var prices_done: int = 0
var crews_done: int = 0
var cells_lost: int = 0
var cells_shot: int = 0
var presents_done: int = 0


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("account_manager", {})


## Phase by HP fraction: 1 ONBOARDING, 2 RENEWAL, 3 COLLECTIONS.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("collections_at", 0.35)):
		return 3
	if hp_fraction <= float(phases.get("renewal_at", 0.7)):
		return 2
	return 1


## Damage taken: x weak on the torso while a contract is presented; x shielded while any cell lives (phase 3).
static func damage_mult(limb: StringName, presenting_now: bool, cells_alive: int, weak: float, shielded: float) -> float:
	var m: float = 1.0
	if presenting_now and limb == &"torso":
		m *= weak
	if cells_alive > 0:
		m *= shielded
	return m


## The Scrip a pricing stamp takes: a fraction of the account, at least 1 when there is anything.
static func price_cut(scrip: int, fraction: float) -> int:
	if scrip <= 0:
		return 0
	return maxi(1, int(round(float(scrip) * fraction)))


func _ready() -> void:
	super._ready()
	boss_key = "account_manager"
	ecfg = table()
	wcfg = boss_cfg()
	bcfg = wcfg
	station = _v3(wcfg.get("station", [28.0, 0.0, -34.0]))


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO


func modelled() -> bool:
	return false


func person_id() -> String:
	return "account_manager"


func say(line_id: String) -> void:
	if line_id != "":
		GLVO.play(StringName(line_id))


func spawn_manager(_at: Vector3, health: float) -> void:
	spawn_homage(station, health)
	enemy_id = &"account_manager"
	wstate = W.IDLE
	_wt = 2.0
	_spawn_t = 0.0
	phase = 1
	escalated = false
	presenting = 0.0
	_present_t = float((wcfg.get("present", {}) as Dictionary).get("every", 20.0)) * 0.5
	_crew_t = 6.0
	_trial_t = -1.0
	_trial_cycle_t = 0.0
	RoundManager.reserve_alive(1)
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(wcfg.get("title", "THE ACCOUNT MANAGER")), str(wcfg.get("subtitle", "attending remotely")), str(wcfg.get("date_line", "MONDLICHT  ·  RR-7")))
		hud.add_bar("account_manager", self, str(wcfg.get("title", "THE ACCOUNT MANAGER")), "the contract")
	say(str(wcfg.get("spawn_vo", "")))
	get_tree().create_timer(6.0).timeout.connect(func() -> void: _present(1))


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func _build_costume() -> void:
	var violet: Color = Color(0.4, 0.18, 0.62)
	var brass: Color = Color(0.7, 0.58, 0.3)
	# the ledger face: a tall plate over the head, two lenses; the chest plate (the contract) with a signature line
	costume("Head", [HomageBoss.boxp(Vector3(0.3, 0.42, 0.06), Vector3(0, 0.1, -0.12), violet),
		HomageBoss.sph(0.035, Vector3(-0.07, 0.16, -0.16), Color(0.9, 0.7, 1.0)), HomageBoss.sph(0.035, Vector3(0.07, 0.16, -0.16), Color(0.9, 0.7, 1.0))], 1.8)
	costume("Chest", [HomageBoss.boxp(Vector3(0.42, 0.5, 0.05), Vector3(0, 0.15, -0.16), violet),
		HomageBoss.boxp(Vector3(0.3, 0.02, 0.06), Vector3(0, 0.0, -0.17), brass)], 0.6)
	# the welcome arms: long sleeves, telescoping in the sweep
	for side: String in ["Left", "Right"]:
		costume(side + "UpperArm", [HomageBoss.cyl(0.07, 0.06, 0.34, Vector3(0, -0.15, 0), violet)], 0.3)
		costume(side + "LowerArm", [HomageBoss.cyl(0.06, 0.05, 0.36, Vector3(0, -0.16, 0), violet), HomageBoss.sph(0.06, Vector3(0, -0.36, 0), brass)], 0.3)
	# the skirt of the unit: a cabinet from the hips down
	costume("Hips", [HomageBoss.boxp(Vector3(0.5, 0.9, 0.4), Vector3(0, -0.45, 0), violet)], 0.4)


func _tick(delta: float) -> void:
	if escalated:
		global_position = station
		velocity = Vector3.ZERO
		return
	_spawn_t += delta
	_wt -= delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)):
		escalate()   # a round can never softlock on her
		return
	var new_phase: int = phase_of(hp_fraction(), wcfg.get("phases", {}))
	if new_phase != phase:
		for ph: int in range(phase + 1, new_phase + 1):
			_enter_phase(ph)
		phase = new_phase
	global_position = station   # she never leaves the console
	velocity = Vector3.ZERO
	if target != null:
		_face(Vector3(target.global_position.x, global_position.y, target.global_position.z))
	# the contract presented now and then: the open plate
	if presenting > 0.0:
		presenting -= delta
	else:
		_present_t -= delta
		if _present_t <= 0.0:
			_present(phase)
	if phase >= 2:
		_tick_trial(delta)
	if phase >= 3:
		_tick_collections(delta)
	match wstate:
		W.IDLE:
			if _wt > 0.0:
				return
			var ac: Dictionary = wcfg.get("arms", {})
			var pc: Dictionary = wcfg.get("price", {})
			if cd_ready("arms") and target != null and dist_to(target) <= float(ac.get("reach", 7.0)) + 1.0:
				wstate = W.ARMS_TELE
				_wt = tele_len(float(ac.get("telegraph", 1.2)))
				bstate = B.TELEGRAPH
				sfx("chain", -2.0, 1.4)
			elif phase >= 3 and cd_ready("price") and _pick_price_target(float(pc.get("range", 14.0))) != null:
				_price_target = _pick_price_target(float(pc.get("range", 14.0)))
				wstate = W.PRICE_TELE
				_wt = tele_len(float(pc.get("telegraph", 0.9)))
				bstate = B.TELEGRAPH
				sfx("hum", 0.0, 1.5)
				if prices_done == 0:
					say(str((pc.get("vo", []) as Array)[0]) if (pc.get("vo", []) as Array).size() > 0 else "")
			else:
				_wt = 0.4
		W.ARMS_TELE:
			if _wt <= 0.0:
				_sweep()
				wstate = W.RECOVER
				_wt = 1.0
				bstate = B.RECOVER
		W.PRICE_TELE:
			if _wt <= 0.0:
				_stamp()
				wstate = W.RECOVER
				_wt = 0.8
				bstate = B.RECOVER
		W.RECOVER:
			if _wt <= 0.0:
				wstate = W.IDLE
				bstate = B.MOVE
				_wt = 0.3
		_:
			pass


func _enter_phase(ph: int) -> void:
	match ph:
		2:
			var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
			if ctl != null and ctl.has_method("begin_renewal_clock"):
				ctl.call("begin_renewal_clock")
			_offer_trial()
			var tc: Dictionary = wcfg.get("trial", {})
			for pid: int in GameState.player_ids:
				if GameState.character_of(pid) == &"dutch" and not GameState.is_bot(pid):
					_reinholt_t = float(tc.get("reinholt_after", 10.0))
		3:
			_remove_trial()
			GameState.set_flag(&"manager_field_down")
			_spawn_cells()
			_crew_t = 4.0
	_present(ph)


## The contract presented: the phase's line, the plate open for `seconds` (the torso x weak).
func _present(ph: int) -> void:
	var pc: Dictionary = wcfg.get("present", {})
	presenting = float(pc.get("seconds", 3.0))
	_present_t = float(pc.get("every", 20.0))
	presents_done += 1
	var vo: Array = pc.get("vo", [])
	if ph - 1 < vo.size() and presents_done <= 3:
		say(str(vo[ph - 1]))
	_hit_done = false


func presenting_now() -> bool:
	return presenting > 0.0


# ---------------------------------------------------------------- ONBOARDING: the welcome arms

func _sweep() -> void:
	var ac: Dictionary = wcfg.get("arms", {})
	arms_done += 1
	moves_used["arms"] = int(moves_used.get("arms", 0)) + 1
	sfx("chain", 2.0, 1.1)
	var fwd: Vector3 = -global_basis.z
	for p: Player in alive_players():
		if Bordwart.in_arc(global_position, fwd, p.global_position, float(ac.get("reach", 7.0))):
			hit_player(p, float(ac.get("damage", 80)) * squad_damage_mult)
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			p.external_push(away.normalized() * float(ac.get("push", 7.0)) + Vector3(0, 2.5, 0), 0.35, &"push")
	set_cd("arms", cd_for(float(ac.get("cooldown", 5.0))))


# ---------------------------------------------------------------- RENEWAL: the trial

func _offer_trial() -> void:
	if trial != null and is_instance_valid(trial):
		return
	var path: String = "res://gravelight/world/map04/trial_offer.gd"
	if not ResourceLoader.exists(path):
		return
	trial = (load(path) as GDScript).new() as Node3D
	trial.name = "TrialOffer"
	trial.set("manager", self)
	_map().add_child(trial)
	trial.global_position = station + _v3(wcfg.get("trial_offset", [-3.5, 0.0, 1.5]))


func _remove_trial() -> void:
	if trial != null and is_instance_valid(trial):
		trial.queue_free()
	trial = null


## A player took the trial: every tonic, for `offer_seconds`; bots never do.
func accept_trial(pid: int) -> void:
	if GameState.is_bot(pid) or trial_takers.has(pid):
		return
	trial_takers.append(pid)
	PerkManager.grant_all(pid)
	Interactable.feedback_2d(_player_of(pid), "perk_buy" if AudioDirector.has_sound("perk_buy") else "buy", -2.0)
	if _trial_t < 0.0:
		_trial_t = float((wcfg.get("trial", {}) as Dictionary).get("offer_seconds", 60.0))


func _player_of(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


## The trial has ended: every taker's perks are stripped, all of them.
func end_trial() -> void:
	_trial_t = -1.0
	if trial_takers.is_empty():
		return
	for pid: int in trial_takers:
		for perk: Variant in PerkManager.owned(pid).duplicate():
			PerkManager.remove(pid, StringName(perk))
		GLBus.perks_lost.emit(pid)
	trial_takers.clear()
	say(str((wcfg.get("trial", {}) as Dictionary).get("vo_end", "")))
	if trial != null and is_instance_valid(trial):
		trial.set("taken", [] as Array[int])


func _tick_trial(delta: float) -> void:
	if _trial_t > 0.0:
		_trial_t -= delta
		if _trial_t <= 0.0:
			end_trial()
	if _reinholt_t > 0.0:
		_reinholt_t -= delta
		if _reinholt_t <= 0.0:
			_reinholt_t = -1.0
			say(str((wcfg.get("trial", {}) as Dictionary).get("reinholt_vo", "")))


# ---------------------------------------------------------------- COLLECTIONS: the stamp, the crew, the cells

func _pick_price_target(range_m: float) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in alive_players():
		var d: float = dist_to(p)
		if d <= range_m and d < best_d and has_los(p):
			best_d = d
			best = p
	return best


func _stamp() -> void:
	var pc: Dictionary = wcfg.get("price", {})
	set_cd("price", cd_for(float(pc.get("cooldown", 8.0))))
	var p: Player = _price_target
	_price_target = null
	if p == null or not is_instance_valid(p) or not p.is_alive() or dist_to(p) > float(pc.get("range", 14.0)) + 2.0 or not has_los(p):
		return
	prices_done += 1
	moves_used["price"] = int(moves_used.get("price", 0)) + 1
	hit_player(p, float(pc.get("damage", 90)) * squad_damage_mult)
	var cut: int = price_cut(Economy.get_scrip(p.player_id), float(pc.get("scrip_fraction", 0.1)))
	if cut > 0:
		Economy.grant(p.player_id, -cut)
	sfx("board_slam", 0.0, 1.6, p.global_position + Vector3.UP)
	Effects.static_burst(p.global_position + Vector3.UP, 1.2)
	var vo: Array = pc.get("vo", [])
	if prices_done == 2 and vo.size() > 1:
		say(str(vo[1]))


func _tick_collections(delta: float) -> void:
	_crew_t -= delta
	if _crew_t <= 0.0:
		var cc: Dictionary = wcfg.get("crew", {})
		_crew_t = float(cc.get("every", 25.0))
		_bring_crew(cc)
	var sc: Dictionary = wcfg.get("shields", {})
	for i: int in _slots.size():
		var slot: Dictionary = _slots[i]
		if bool(slot["lost"]):
			continue
		if float(slot["regen"]) > 0.0:
			slot["regen"] = float(slot["regen"]) - delta
			if float(slot["regen"]) <= 0.0:
				slot["regen"] = -1.0
				_spawn_cell(i, sc)
			continue
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c == null or not c.is_active():
			# shot to pieces (the body is recycled and freed by the director): she regrows it after regen_seconds
			cells_shot += 1
			slot["cell"] = null
			slot["regen"] = float(sc.get("regen_seconds", 40.0))


func _bring_crew(cc: Dictionary) -> void:
	var dir: ZombieDirector = director as ZombieDirector
	if dir == null:
		return
	var pad: Vector3 = _v3(wcfg.get("crew_pad", [37.0, 0.3, -37.5]))
	var made: int = 0
	for i: int in int(cc.get("count", 3)):
		var spec: Dictionary = dir._spec_for(&"ganger", RoundManager.take_extra_spawn())
		spec["variant"] = str(cc.get("kit", "soldier"))
		spec["tier"] = StringName(str(cc.get("tier", "jog")))
		var at: Vector3 = pad + Vector3(cos(TAU * float(i) / 3.0) * 1.2, 0, sin(TAU * float(i) / 3.0) * 1.2)
		if dir._activate_at(spec, dir._snap(at)) != null:
			made += 1
		else:
			RoundManager.alive = maxi(0, RoundManager.alive - 1)
	if made > 0:
		crews_done += 1
		Effects.static_burst(pad + Vector3.UP, 2.0)
		if crews_done == 1:
			say(str(cc.get("vo", "")))


func _spawn_cells() -> void:
	var sc: Dictionary = wcfg.get("shields", {})
	var n: int = int(sc.get("count", 3))
	_slots.clear()
	for i: int in n:
		_slots.append({"cell": null, "regen": -1.0, "lost": false})
		_spawn_cell(i, sc)


func _spawn_cell(i: int, sc: Dictionary) -> void:
	var dir: ZombieDirector = director as ZombieDirector
	if dir == null or escalated or i >= _slots.size():
		return
	var slot: Dictionary = _slots[i]
	var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
	if c == null:
		c = ShieldCell.new()
		c.boss = self
		dir.add_extra(c)
		slot["cell"] = c
	c.orbit_phase = TAU * float(i) / float(maxi(1, int(sc.get("count", 3))))
	c.orbit_radius = float(sc.get("orbit_radius", 2.6))
	c.orbit_height = float(sc.get("orbit_height", 1.7))
	c.orbit_rpm = float(sc.get("orbit_rpm", 6.0))
	c.shaft_pos = _v3(wcfg.get("shaft", [28.0, 7.0, -30.0]))
	c.shaft_radius = float(wcfg.get("shaft_radius", 2.5))
	RoundManager.take_extra_spawn()
	c.spawn_cell(ShieldCell.orbit_pos(station, c.orbit_phase, 0.0, c.orbit_radius, c.orbit_height, c.orbit_rpm), float(sc.get("hp", 2000)))
	GLBus.enemy_spawned.emit(c.enemy_id, c.get_instance_id())


## A cell went into the shaft: gone for good (no regrowth), her line.
func on_cell_lost(c: ShieldCell) -> void:
	cells_lost += 1
	for slot: Dictionary in _slots:
		if slot["cell"] == c:
			slot["lost"] = true
			slot["regen"] = -1.0
	say(str((wcfg.get("shields", {}) as Dictionary).get("vo_lost", "")))


func live_cells() -> Array:
	var out: Array = []
	for slot: Dictionary in _slots:
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c != null and c.is_active() and not c.gone_for_good:
			out.append(c)
	return out


# ---------------------------------------------------------------- damage and the escalation

func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if escalated:
		return false
	var sc: Dictionary = wcfg.get("shields", {})
	var m: float = damage_mult(limb, presenting_now(), live_cells().size() if phase >= 3 else 0, float((wcfg.get("present", {}) as Dictionary).get("weak_mult", 2.5)), float(sc.get("shielded_mult", 0.2)))
	return super.take_damage(amount * m, limb, weapon_id, by_player, kind, armor_piercing)


func _tele_glow() -> float:
	return 4.0 if wstate in [W.ARMS_TELE, W.PRICE_TELE] else (2.0 if presenting_now() else 0.0)


## 0 %: she never dies. She folds, the voice steps away, the console unlocks.
func _boss_die(_limb: StringName, _weapon_id: StringName, _by_player: int, _kind: StringName) -> void:
	escalate()


func escalate() -> void:
	if escalated:
		return
	escalated = true
	hp = maxf(hp, 1.0)
	wstate = W.FOLDED
	bstate = B.SPECIAL
	presenting = 0.0
	_release_all_grabs("escalated")
	_tele_light.light_energy = 0.0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_remove_trial()
	for slot: Dictionary in _slots:
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c != null and c.is_active():
			c.vanish_for_good()
	_pose.hold = true
	_tree_play("React", str(_anim["clips"]["react"]["stagger"]), 0.2)
	say(str(wcfg.get("escalate_vo", "")))
	var opr: String = str(wcfg.get("escalated_opr_vo", ""))
	if opr != "":
		get_tree().create_timer(4.5).timeout.connect(func() -> void: GLVO.play(StringName(opr)))
	var scrip: int = int(wcfg.get("escalate_scrip_per_player", 0))
	if scrip > 0:
		for pid: int in GameState.player_ids:
			Economy.grant(pid, scrip)
	for d: Variant in wcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), station + Vector3(0, 0.3, 3.0))
	if str(wcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(wcfg["flag"])))
	GLBus.boss_spawned.emit(&"account_manager_escalated")
	RoundManager.release_alive(2)   # her reserve and her extra-spawn count: the round can end around her
	print("[m4d] the Account Manager escalated after %.0f s (arms %d, prices %d, crews %d, cells shot %d / lost %d)" % [_spawn_t, arms_done, prices_done, crews_done, cells_shot, cells_lost])


func _on_retreat() -> void:
	RoundManager.release_alive(2)


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)


func is_active() -> bool:
	return super.is_active() and not escalated
