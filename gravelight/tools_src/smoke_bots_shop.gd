extends Node
## T-177 headless smoke: the squad bots and a companion shop for themselves on Kaltenbrunn: tonics at the perk
## machines, the Crucible, a part at the Armorer's Bench and the bank (their own match-only accounts; the human's
## profile balance never moves). Silent, solo, a god-mode human, 3 bots + Gustl Ammer (the map companion, joined
## with a Thompson). Round 8, the power on, every door open, a long break, 30,000 Scrip each; the shopping ranges
## are widened here (the machines are spread over the map; the rules under test are what they buy, not how far).
## Phase 2: one bot with 200 Scrip in its pocket and 20,000 in the bank takes money out for what it wants next.
## Prints "[shop-smoke] ..." and "[shop-smoke] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_bots_shop.tscn

## The map (smoke_bots_shop_m0.tscn runs Map 0, whose Crucible is in the cellar: Kaltenbrunn's is in the Core
## Vault, which only the egg opens, so the Crucible is checked on Map 0 only).
@export var map_path: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
@export var need_crucible: bool = false
@export var need_deposit: bool = true   # (Map 0: after the Crucible every bot saves its pocket for the next teaching)
const PHASE1_S: float = 300.0
const PHASE1_MAX_S: float = 600.0   # (phase 1 runs on until the companion has used the bench, the Crucible or the bank)
const PHASE2_S: float = 60.0

var _map: MapRoot
var _fails: PackedStringArray = []
var _t: float = 0.0
var _stage: int = 0
var _t_stage: float = 0.0
var _who: Dictionary = {}          # pid -> name
var _comp_pid: int = 0
var _bought: Dictionary = {}       # pid -> {perk, bench, crucible, deposit, withdraw}: count
var _bank_last: Dictionary = {}    # pid -> last seen bot bank balance
var _profile_bank0: int = 0
var _p2_pid: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_shop_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shop_settings.cfg"
	GLSettings.values["classic_rules"] = false
	GLSettings.values["bot_ee_help"] = "off"
	GameState.bot_count = 3
	GameState.god_mode = true
	Campaign.reset()
	# the map's machines are 30-90 m apart: let every bot reach every one of them from where the human stands
	var eco: Dictionary = BotAIData.table("economy")
	eco["max_range_from_leader_m"] = 400.0
	eco["bot_led_range_m"] = 400.0
	((BotConfig.cfg().get("shopping", {}) as Dictionary).get("crucible", {}) as Dictionary)["max_from_leader_m"] = 400.0
	GLBus.purchase_made.connect(_on_purchase)
	_map = (load(map_path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _note(s: String) -> void:
	print("[shop-smoke] " + s)


func _fail(s: String) -> void:
	_fails.append(s)
	_note("FAIL " + s)


func _count(pid: int, k: String) -> void:
	if not _who.has(pid):
		return
	var d: Dictionary = _bought.get(pid, {})
	d[k] = int(d.get(k, 0)) + 1
	_bought[pid] = d


func _on_purchase(pid: int, item: StringName, cost: int) -> void:
	if not _who.has(pid):
		return
	var it: String = String(item)
	if (GLData.table("perks")["perks"] as Dictionary).has(it) or it.begins_with("perk_") or it.ends_with("_upgrade_perk"):
		_count(pid, "perk")
	_note("%s bought %s for %d" % [_who[pid], it, cost])


func _human() -> Player:
	return _map.player


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	_t += delta
	match _stage:
		0:
			if _t > 3.0:
				_setup()
				_stage = 1
				_t_stage = _t
				Engine.time_scale = 4.0
		1:
			_hold_break()
			_poll()
			if _t - _t_stage > PHASE1_S and (_comp_second() or _t - _t_stage > PHASE1_MAX_S):
				_phase2()
				_stage = 2
				_t_stage = _t
		2:
			_hold_break()
			_poll()
			if _t - _t_stage > PHASE2_S:
				Engine.time_scale = 1.0
				_finish()
				_stage = 3


func _hold_break() -> void:
	if RoundManager.state != RoundManager.State.BREAK:
		RoundManager.state = RoundManager.State.BREAK
	RoundManager.break_left = 999.0
	_map.director.kill_all(true)


func _setup() -> void:
	_map.director.kill_all(true)
	RoundManager.debug_set_round(8)
	RoundManager.state = RoundManager.State.BREAK
	RoundManager.break_left = 999.0
	if not GameState.power_on:
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		GLBus.power_activated.emit()
	var opened: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)
			opened += 1
	# Gustl Ammer joins with a Thompson (his talk card is smoke_map_companions' job)
	var mc: MapCompanion = null
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		mc = c
	if mc != null:
		while mc.player == null and RoundManager.current_round < 30:
			RoundManager.advance_round()
			mc._appear()
		if mc.player != null:
			mc.player.weapons.give_weapon(&"thompson")
			mc._join(1, false)
			if mc.brain != null:
				mc.brain.options["armed"] = true
			mc.player.global_position = _human().global_position + Vector3(1.5, 0.2, 0.0)
			_comp_pid = mc.player.player_id
			_who[_comp_pid] = "%s (companion)" % str(mc.cfg.get("name", mc.id))
	RoundManager.debug_set_round(8)
	if _comp_pid == 0:
		_fail("the map companion did not join")
	for b: BotBrain in _map.squad.brains:
		if b.player.is_bot and not b.player.is_companion and not b.is_player_bot:
			_who[b.player.player_id] = Net.display_name(b.player.player_id)
	for pid: Variant in _who.keys():
		Economy.grant_raw(int(pid), 30000)
		_bank_last[pid] = 0
	_profile_bank0 = BankAccount.balance()
	for b2: BotBrain in _map.squad.brains:
		b2.on_round_started()
	_note("set up: round %d, %d doors opened, shoppers %s, the bank %s" % [RoundManager.current_round, opened, str(_who.values()), "open" if BankAccount.closed_reason() == "" else "shut"])
	_note("benches %d, bank branches %d, Crucibles %d, perk machines %d" % [get_tree().get_nodes_in_group(ArmorersBench.GROUP).size(),
		get_tree().get_nodes_in_group(&"bank_branch").size(), get_tree().get_nodes_in_group(&"crucible").size(), get_tree().get_nodes_in_group(&"perk_machines").size()])


func _player_of(pid: int) -> Player:
	for b: BotBrain in _map.squad.brains:
		if b.player.player_id == pid:
			return b.player
	return null


func _brain_of(pid: int) -> BotBrain:
	for b: BotBrain in _map.squad.brains:
		if b.player.player_id == pid:
			return b
	return null


var _poll_t: float = 0.0
var _fitted: Dictionary = {}   # pid -> true
var _upgraded: Dictionary = {}

var _cdiag_t: float = 0.0

func _poll() -> void:
	if _t - _poll_t < 0.5:
		return
	_poll_t = _t
	var cb: BotBrain = _brain_of(_comp_pid)
	if cb != null and _t - _cdiag_t > 8.0:
		_cdiag_t = _t
		_note("companion t=%.0f: action %s, task '%s' (%s), %.1f m from the human, buy %.2f escort %.2f" % [_t, cb.action, str(cb.task.get("label", "")),
			str(cb.task.get("state", "")), cb.player.global_position.distance_to(_human().global_position), float(cb.scores.get("buy", 0.0)), float(cb.scores.get("escort", 0.0))])
	for pid: Variant in _who.keys():
		var p: Player = _player_of(int(pid))
		if p == null:
			continue
		var bal: int = BankAccount.bot_balance(int(pid))
		var last: int = int(_bank_last.get(pid, 0))
		if bal > last + 2:   # (more than a round's interest)
			_count(int(pid), "deposit")
			_note("%s banked %d (balance %d, pocket %d)" % [_who[pid], bal - last, bal, Economy.get_scrip(int(pid))])
		elif bal < last:
			_count(int(pid), "withdraw")
			_note("%s took %d out of the bank (balance %d, pocket %d)" % [_who[pid], last - bal, bal, Economy.get_scrip(int(pid))])
		_bank_last[pid] = bal
		for w: WeaponInstance in p.weapons.slots:
			if w.upgraded and not _upgraded.has(pid):
				_upgraded[pid] = true
				_count(int(pid), "crucible")
				_note("%s has a taught %s" % [_who[pid], w.display_name()])
			if not _fitted.has(pid) and WeaponKit.accepts(w):
				for slot: String in WeaponKit.slot_order(w):
					for o: Variant in WeaponKit.options(w, slot):
						if WeaponKit.has_option(w, slot, str(o)) and not _fitted.has(pid):
							_fitted[pid] = true
							_count(int(pid), "bench")
							_note("%s has %s/%s on its %s" % [_who[pid], slot, str(o), w.display_name()])


func _comp_second() -> bool:
	var cb: Dictionary = _bought.get(_comp_pid, {})
	return int(cb.get("bench", 0)) + int(cb.get("crucible", 0)) + int(cb.get("deposit", 0)) > 0


## Phase 2: a bot with little in its pocket and a lot in the bank wants something: it takes money out.
func _phase2() -> void:
	_report("after phase 1")
	_diag()
	for pid: Variant in _who.keys():
		if int(pid) != _comp_pid:
			_p2_pid = int(pid)
			break
	var p: Player = _player_of(_p2_pid)
	if p == null:
		_fail("no bot for phase 2")
		return
	# it wants a tonic again: its tonics go (as on a down; one alone could leave it at the cap, wanting nothing)
	var owned: Array = PerkManager.owned(_p2_pid).duplicate()
	for pk: Variant in owned:
		PerkManager.remove(_p2_pid, StringName(str(pk)))
	var pocket: int = Economy.get_scrip(_p2_pid)
	Economy.bank_move(_p2_pid, -(pocket - 200))
	BankAccount._bots[_p2_pid] = 20000
	_bank_last[_p2_pid] = 20000
	var b: BotBrain = _brain_of(_p2_pid)
	if b != null:
		if not b.task.is_empty():
			b.drop_task()   # (an errand planned on the old pocket)
		b.on_round_started()
		b.economy.invalidate()
	_note("phase 2: %s has %d in the pocket, 20000 in the bank, tonics %s" % [_who[_p2_pid], Economy.get_scrip(_p2_pid), str(PerkManager.owned(_p2_pid))])


## What each shopper could do now (its candidates) and where the Crucible stands for it.
func _diag() -> void:
	var crs: Array[Node] = get_tree().get_nodes_in_group(&"crucible")
	for pid: Variant in _who.keys():
		var b: BotBrain = _brain_of(int(pid))
		if b == null:
			continue
		b.economy.invalidate()
		var kinds: PackedStringArray = []
		for c: Dictionary in b.economy.candidates(b.economy.anchor(), 1.0):
			kinds.append("%s %.2f" % [str(c["kind"]), float(c["value"])])
		var cr_s: String = "no Crucible"
		if not crs.is_empty():
			var cr: Crucible = crs[0] as Crucible
			cr_s = "Crucible powered %s, stand %s, reachable %s, up slot %d" % [str(cr.is_powered()), str(b.stand_point(cr) != Vector3.INF),
				str(b.reachable(BotBrain._front_of(cr))), b._upgradeable_slot()]
		var sc: PackedStringArray = []
		for k: Variant in b.scores.keys():
			if float(b.scores[k]) > 0.05:
				sc.append("%s %.2f" % [str(k), float(b.scores[k])])
		var ctr: BankCounter = b.economy._bank_counter(b.economy.anchor(), 9999.0)
		var mg: WeaponInstance = b.economy._main_gun()
		var rows: Array = ArmorersBench.options_for_gun(b.player, mg) if mg != null else []
		var bench: ArmorersBench = ArmorersBench.nearest(get_tree(), b.player.global_position)
		_note("diag %s: bank counter %s (stand %s), saved %d, want %d; main gun %s accepts %s, open rows %d, bench stand %s" % [_who[pid],
			str(ctr != null), str(ctr != null and b.stand_point(ctr) != Vector3.INF), BankAccount.bot_balance(int(pid)), b.economy.next_want_cost(true, 0, {}),
			mg.display_name() if mg != null else "-", str(mg != null and WeaponKit.accepts(mg)), BotEconomy.bench_rows_open(rows).size(), str(bench != null and b.stand_point(bench) != Vector3.INF)])
		_note("diag %s: action %s, task %s, in_break %s, options shopping %s perks %s; candidates [%s]; scores [%s]; %s" % [_who[pid], b.action, str(b.task.get("label", "")),
			str(b.in_break()), str(b.options.get("shopping")), str(b.options.get("perks")), ", ".join(kinds), ", ".join(sc), cr_s])


func _report(when: String) -> void:
	for pid: Variant in _who.keys():
		var p: Player = _player_of(int(pid))
		var guns: PackedStringArray = []
		if p != null:
			for w: WeaponInstance in p.weapons.slots:
				guns.append("%s%s" % [w.display_name(), " (taught)" if w.upgraded else ""])
		_note("%s %s: %s; tonics %s; guns %s; pocket %d, bank %d" % [when, _who[pid], str(_bought.get(pid, {})), str(PerkManager.owned(int(pid))),
			", ".join(guns), Economy.get_scrip(int(pid)), BankAccount.bot_balance(int(pid))])


func _finish() -> void:
	_report("at the end")
	var any: Dictionary = {}
	for pid: Variant in _who.keys():
		for k: Variant in (_bought.get(pid, {}) as Dictionary).keys():
			if int(pid) != _comp_pid:
				any[k] = true
	var cb0: Dictionary = _bought.get(_comp_pid, {})
	for k: String in (["perk", "bench", "deposit"] if need_deposit else ["perk", "bench"]):
		if not any.has(k):
			_fail("no squad bot did '%s'" % k)
	if need_crucible and not any.has("crucible") and int(cb0.get("crucible", 0)) <= 0:
		_fail("nobody fed the Crucible")
	var cb: Dictionary = _bought.get(_comp_pid, {})
	if int(cb.get("perk", 0)) <= 0:
		_fail("the companion bought no tonic")
	if int(cb.get("bench", 0)) + int(cb.get("crucible", 0)) + int(cb.get("deposit", 0)) <= 0:
		_fail("the companion used neither the bench, the Crucible nor the bank")
	if int((_bought.get(_p2_pid, {}) as Dictionary).get("withdraw", 0)) <= 0:
		_fail("phase 2: the bot never took its savings out")
	if BankAccount.balance() != _profile_bank0:
		_fail("the human's profile savings moved (%d -> %d)" % [_profile_bank0, BankAccount.balance()])
	_note("RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (" + "; ".join(_fails) + ")"])
	get_tree().quit(0 if _fails.is_empty() else 1)
