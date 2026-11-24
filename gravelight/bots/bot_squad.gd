class_name BotSquad
extends Node
## The AI teammates of a match (T-031; Update 03, T-055), a child of the MapRoot in a solo match that asked for
## bots. Builds a BotBrain for every bot Player, and holds what the brains share:
##   - the squad blackboard (`blackboard`, BotBlackboard): known zombies (4 s memory), claimed tasks (who
##     revives whom, who covers, who holds which window), the training route and its leader, danger zones (boss
##     keep-away rings, fire, Bell Domes), power-ups, callout pings, roles;
##   - update_shared(): revive claims (the nearest healthy bot with a safe path; the human first, then bots,
##     then companions), a second bot covering a hot revive, squad roles (Anchor / Runner / Medic / Builder from
##     the personalities), danger zones, the "sprinter behind you" and "window's open" callouts;
##   - who leads (the human; the first standing bot when the human is out), the kill-share ledger, the errand
##     node claims, per-player kill counts;
##   - the squad's voice (callout(): survivor VO lines one at a time with cooldowns, each with a world-space ping
##     marker, BotPings), the command wheel (BotCommandWheel; set_command for every order in bots.json
##     commands.orders, each a high-weight action for 60 s or until done), the nameplates (BotPlates), and the
##     dev console's `ai_debug` overlay (BotDebugOverlay).
## U02 section 5: bonus perks, the spawn kit, choke points. Companions (Jakub, U02 section 6) join through
## add_brain(player, options).
## Update 04 section 5 (T-067): the easter-egg help (`ee`, BotEEHub; the setting "Bot Easter-Egg Help") and its
## public API: ee_assign / ee_can_assign / ee_task_of / ee_cancel / ee_assign_node (the Objectives tab, map marks
## and the ping key call these).

var map: MapRoot
var brains: Array[BotBrain] = []
var blackboard: BotBlackboard = BotBlackboard.new()
var kills: Dictionary = {}          # pid -> kills (humans too, for the ledger)
var recent_kills: Array = []        # killer pids, newest last (kill share)
var _cfg: Dictionary = {}
var _claims: Dictionary = {}        # node instance id -> pid (errand nodes: machines, doors, wall-buys)
var _callout_t: float = 0.0
var _t: float = 0.0
var _round_t: float = 0.0
var _wall_buys: Array[WallBuy] = []
## Emitted for every order given from the wheel (or set_command). `at` is the pointed spot (INF when none).
signal order_given(order_id: StringName, at: Vector3)

## The legacy squad order (one of BotConfig.COMMANDS) and, for "hold", the spot.
var command: StringName = &"follow"
var hold_point: Vector3 = Vector3.INF
## The node the last open_door / fetch_part order pointed at.
var order_target: Node = null
## Choke points (world AABBs): open doorways and staircases. [{"box": AABB, "kind": "door"/"stair", "node"}]
var chokes: Array[Dictionary] = []
## Soak instrumentation: every time a bot stayed inside a choke longer than follow.choke_report_s.
var choke_events: PackedStringArray = []
## T-058: the home loop of a squad with no human leading it (refreshed with the route; null otherwise).
var home: TrainingRoute = null
## T-058: the stalled round's last zombie the squad hunts (INF: none), and since when the round stalled.
var hunt_at: Vector3 = Vector3.INF
var _stall_since: float = -1.0
## The human's smoothed flat velocity (training detection for the moving formation).
var leader_vel: Vector3 = Vector3.ZERO
## Doors the human opened this match (bots buy doors on the human's path only after one).
var human_doors_opened: int = 0
var plates: BotPlates = null
var wheel: BotCommandWheel = null
var pings: BotPings = null
var debug: BotDebugOverlay = null
## The easter-egg help (T-067): assignments, Full Partner, what the squad has discovered.
var ee: BotEEHub = null
## Map-mark orders (Update 04 section 3, T-069): the MapMarks order handler; each brain's BotMarkTask.
var mark_orders: BotMarkOrders = null
## Player bot mode (T-071): the brain playing the local human's own survivor (PlayerBot), or null. It is not in
## `brains` (no nameplate, orders, roles, bonus perk or kit); it revives teammates, claims errands and leads.
var player_bot: BotBrain = null
var _bot_cd: Dictionary = {}      # "pid:FAMILY" -> time a bark may come again
## The human's recent walking line (their training loop): ~24 s of breadcrumbs. Bots never park on it.
var human_line: PackedVector3Array = PackedVector3Array()
var _crumb_t: float = 0.0
var _shared_t: float = -1.0
var _roles_t: float = -10.0
var _call_t: float = 0.0
var _window_said: Dictionary = {}
var _tallies: Dictionary = {}
## T-237: counts the thinks of every brain in the squad (BotBrain.think_slot: one brain thinks per physics tick).
var think_seq: int = 0
## T-237: the weapon models loaded in the background from the squad's first moments (StreamWarm): the first time a
## bot (or anyone) draws a kind of gun nobody has held yet, its model file was loaded in that frame (about 50 ms).
var _model_warm: StreamWarm = null
var _ap_cache: Array[Player] = []
var _ap_key: Vector4i = Vector4i(-1, -1, -1, -1)


func setup(map_root: MapRoot) -> void:
	map = map_root
	_cfg = BotConfig.cfg()
	blackboard.memory_s = float(BotAIData.combat("perception").get("memory_s", 4.0))
	add_to_group(&"bot_squad")
	var i: int = 0
	for pid: int in GameState.bot_ids:
		var p: Player = map.players.get(pid) as Player
		if p == null:
			continue
		add_brain(p, {}, i)
		i += 1
	_assign_bonus_perks()
	_start_planner()
	_start_ee()
	_start_marks()
	_build_chokes()
	_warm_models()
	for n: Node in map.find_children("*", "WallBuy", true, false):
		_wall_buys.append(n as WallBuy)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	# DOWN / TEAM_DOWN / REVIVED / boss / door / buy / perk lines for bots come from VOManager (T-035).
	GLBus.round_started.connect(_on_round_started)
	GLBus.powerup_spawned.connect(_on_powerup_spawned)
	GLBus.powerup_collected.connect(func(id: StringName, _by: int) -> void: blackboard.remove_powerup_at(id, Vector3.INF))
	GLBus.powerup_expired.connect(func(id: StringName) -> void: blackboard.remove_powerup_at(id, Vector3.INF))
	GLBus.boss_spawned.connect(_on_boss_spawned)
	GLBus.crate_moved.connect(_on_crate_moved)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.player_downed.connect(_log_down)
	if not brains.is_empty():
		_ensure_ui()
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "ai_debug", _cmd_ai_debug, "ai_debug 1|0|heat|panel: the bot AI overlay (actions, scores, roles, targets, paths, the blackboard, a threat heatmap)")


## A brain for `p` (a bot Player, or a companion): `options` override BotBrain.options (see there).
## `i` = formation index (-1 = next).
func add_brain(p: Player, options: Dictionary = {}, i: int = -1) -> BotBrain:
	var b: BotBrain = BotBrain.new()
	b.name = "Brain"
	b.options.merge(options, true)
	p.add_child(b)
	b.setup(p, self, brains.size() if i < 0 else i)
	brains.append(b)
	if ee != null:
		ee.attach(b)
	if mark_orders != null:
		mark_orders.attach(b)
	if bool(b.options.get("kit", true)) and not Campaign.carried_player(p.player_id):
		apply_kit(p, true)   # a campaign arrival keeps the carried kit instead
	else:
		apply_r30_kit(p)   # T-186: a campaign arrival (or a companion, when the data lets it) past round 30
	if is_inside_tree():
		_ensure_ui()   # a companion joining a squad that had no bots (solo): the plates, the wheel, the pings
	return b


## Player bot mode (T-071): a brain for the local human's own Player (`options` as add_brain). Kept out of
## `brains`; the squad still sees it as the human (it leads, it is revived first) and lets it revive others.
func add_player_brain(p: Player, options: Dictionary = {}) -> BotBrain:
	remove_player_brain()
	var b: BotBrain = BotBrain.new()
	b.name = "PlayerBotBrain"
	b.is_player_bot = true
	b.options.merge(options, true)
	p.add_child(b)
	b.setup(p, self, brains.size())
	player_bot = b
	return b


## Player bot mode off: the player's brain goes (its claims with it).
func remove_player_brain() -> void:
	if player_bot == null:
		return
	blackboard.release_all(player_bot.player.player_id)
	for k: Variant in _claims.keys():
		if int(_claims[k]) == player_bot.player.player_id:
			_claims.erase(k)
	if is_instance_valid(player_bot):
		player_bot.queue_free()
	player_bot = null


## The local human is being played by the agent (bot mode, T-071).
func human_is_agent() -> bool:
	var h: Player = human()
	return h != null and is_instance_valid(h) and h.bot_driven and player_bot != null


## Takes a brain out of the squad (a companion that bled out): its claims go, the brain is freed.
func remove_brain(b: BotBrain) -> void:
	if b == null:
		return
	brains.erase(b)
	blackboard.release_all(b.player.player_id)
	if is_instance_valid(b):
		b.queue_free()


## The nameplates, the command wheel and the ping markers (once there is a brain to show or order).
func _ensure_ui() -> void:
	if plates == null:
		plates = BotPlates.new()
		plates.name = "BotPlates"
		add_child(plates)
		plates.setup(self)
	if wheel == null:
		wheel = BotCommandWheel.new()
		wheel.name = "BotCommandWheel"
		add_child(wheel)
		wheel.setup(self)
	if pings == null:
		pings = BotPings.new()
		pings.name = "BotPings"
		add_child(pings)


func _assign_bonus_perks() -> void:
	var bcfg: Dictionary = _cfg.get("bonus_perk", {})
	if not BotConfig.bonus_enabled(GLSettings.values, bcfg) or not Net.is_authority():
		return
	var takers: Array[BotBrain] = []
	for b: BotBrain in brains:
		if bool(b.options.get("perks", true)) and bool(b.options.get("bonus_perk", true)):
			var had: StringName = PerkManager.bonus_perk(b.player.player_id)
			if had != &"":
				b.bonus_perk = had   # carried over a campaign transition: the same trait, no second draw
			else:
				takers.append(b)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var kit: Array = ((_cfg.get("spawn_kit", {}) as Dictionary).get("perks", []) as Array).duplicate()
	for b: BotBrain in brains:
		if b.bonus_perk != &"":
			kit.append(String(b.bonus_perk))   # no two bots share one, carried ones included
	var picks: Array[StringName] = BotConfig.pick_bonus_perks(bcfg, map_perk_ids(), kit, takers.size(), rng)
	for k: int in takers.size():
		if picks[k] != &"":
			PerkManager.grant_bonus(takers[k].player.player_id, picks[k])
			takers[k].bonus_perk = picks[k]


func map_perk_ids() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		if pm != null and not out.has(String(pm.perk_id)):
			out.append(String(pm.perk_id))
	return out


## The spawn kit (bots.json spawn_kit): the kit guns (at the start and on a respawn) with the `hold` gun in hand,
## and the kit perks, free. A full loadout (a campaign arrival) is never overwritten.
func apply_kit(p: Player, weapons: bool) -> void:
	if p == null or not Net.is_authority():
		return
	var kit: Dictionary = _cfg.get("spawn_kit", {})
	if weapons and p.weapons != null:
		var held: Array = []
		for w: WeaponInstance in p.weapons.slots:
			held.append(String(w.base_id()))
		for wid: StringName in BotConfig.kit_weapons_missing(kit, held):
			if p.weapons.slots.size() >= p.weapons.max_slots():
				break
			if not (GLData.table("weapons")["weapons"] as Dictionary).has(String(wid)):
				push_warning("bots.json spawn_kit: no weapon '%s'" % wid)
				continue
			p.weapons.give_weapon(wid)
		var hold: String = str(kit.get("hold", ""))
		if hold != "":
			for k: int in p.weapons.slots.size():
				if String(p.weapons.slots[k].base_id()) == hold:
					p.weapons.current_index = k
					break
		if p.remote_body != null:
			var cw: WeaponInstance = p.weapons.current()
			p.remote_body.set_weapon(cw.id if cw != null else &"")
	for perk: StringName in BotConfig.kit_perks_missing(kit, PerkManager.owned(p.player_id)):
		if PerkManager.perk_data(perk).is_empty():
			push_warning("bots.json spawn_kit: no perk '%s'" % perk)
			continue
		PerkManager.grant(p.player_id, perk)
	apply_late_kit(p)
	apply_r30_kit(p, not weapons)   # T-186: on top of the late kit (a revive is `weapons` false)


# ================================================================== U08 section 3 (T-130): the late-round kit

## The late kit is due at `round` (bots.json late_kit): enabled, the round reached, the Bot Bonus Perk setting on
## and Classic Rules off. Pure.
static func late_kit_due(round_number: int, lcfg: Dictionary, settings_values: Dictionary) -> bool:
	if not bool(lcfg.get("enabled", true)) or round_number < int(lcfg.get("round", 25)):
		return false
	return bool(settings_values.get("bot_bonus_perk", true)) and not bool(settings_values.get("classic_rules", false))


## The late kit's tonic for one bot: from `map_perks`, never one in `taken` (held, its bonus, the kit, another
## bot's late perk) or `exclude`; &"" when the pool is empty. Sorted then drawn by `rng` (repeatable). Pure.
static func pick_late_perk(map_perks: Array, taken: Array, exclude: Array, rng: RandomNumberGenerator) -> StringName:
	var pool: Array[String] = []
	for pk: Variant in map_perks:
		var s: String = str(pk)
		if s == "" or pool.has(s) or taken.has(s) or taken.has(StringName(s)) or exclude.has(s):
			continue
		pool.append(s)
	if pool.is_empty():
		return &""
	pool.sort()
	return StringName(pool[rng.randi_range(0, pool.size() - 1)])


var late_perk: Dictionary = {}   # pid -> the late kit's tonic (so no two bots share one, and a respawn redraws)


## Gives a bot the late kit when it is due (spawn, respawn, revive, join, round 25's start). Idempotent: a bot that
## still holds its late tonic and a taught Thompson at the tier gets nothing more. True when it handed anything.
func apply_late_kit(p: Player) -> bool:
	if p == null or not Net.is_authority() or not p.is_bot or p.is_companion or p.downed or p.spectating:
		return false
	var lcfg: Dictionary = _cfg.get("late_kit", {})
	if not late_kit_due(RoundManager.current_round, lcfg, GLSettings.values):
		return false
	var pid: int = p.player_id
	var gave: bool = false
	var tier: int = int(lcfg.get("perk_tier", 3))
	var mine: StringName = StringName(str(late_perk.get(pid, "")))
	if mine == &"" or not PerkManager.has_perk(pid, mine):
		var taken: Array = PerkManager.owned(pid).duplicate()
		taken.append_array(((_cfg.get("spawn_kit", {}) as Dictionary).get("perks", []) as Array))
		for other: Variant in late_perk.keys():
			if int(other) != pid:
				taken.append(str(late_perk[other]))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		var pick: StringName = pick_late_perk(map_perk_ids(), taken, lcfg.get("exclude", []), rng)
		if pick != &"":
			PerkManager.grant(pid, pick)
			PerkManager.set_tier(pid, pick, tier)
			late_perk[pid] = String(pick)
			gave = true
	elif PerkManager.tier_of(pid, mine) < tier:
		PerkManager.set_tier(pid, mine, tier)
		gave = true
	if p.weapons != null:
		var wid: StringName = StringName(str(lcfg.get("weapon", "thompson_up")))
		var ct: int = int(lcfg.get("crucible_tier", 2))
		var have: WeaponInstance = p.weapons.find_weapon(wid)
		if have == null or have.tier < ct:
			if have == null and p.weapons.slots.size() >= p.weapons.max_slots():
				p.weapons.current_index = _weakest_slot(p)   # the late gun takes the weakest slot's place
			p.weapons.give_weapon(wid)
			var w: WeaponInstance = p.weapons.find_weapon(wid)
			if w != null:
				w.tier = ct
				w.refill()
				p.weapons.current_index = p.weapons.slots.find(w)
				p.weapons.call("_rebuild_gun")
				if p.remote_body != null:
					p.remote_body.set_weapon(w.id)
			gave = true
	if gave:
		GLVO.say_as(pid, "LATE_KIT", 1.0)
		GLBus.perks_changed.emit(pid)
	return gave


func _weakest_slot(p: Player) -> int:
	var eco: Dictionary = BotAIData.table("economy")
	var worst: int = 0
	var worst_t: float = INF
	for i: int in p.weapons.slots.size():
		var w: WeaponInstance = p.weapons.slots[i]
		var t: float = BotEconomy.tier_of(String(w.base_id()), w.upgraded, eco, w.tier)
		if t < worst_t:
			worst_t = t
			worst = i
	return worst


# ================================================================== T-186: the round-30 kit

## The round-30 kit is due (bots.json r30_kit): enabled, `from_round` reached, the Bot Bonus Perk setting on and
## Classic Rules off (the same "bot help" toggle as the late kit). Pure.
static func r30_kit_due(round_number: int, rcfg: Dictionary, settings_values: Dictionary) -> bool:
	if rcfg.is_empty() or not bool(rcfg.get("enabled", true)) or round_number < int(rcfg.get("from_round", 30)):
		return false
	return bool(settings_values.get("bot_bonus_perk", true)) and not bool(settings_values.get("classic_rules", false))


## The tonics the round-30 kit hands out: `perks` "all" (every id in `all_ids`, perks.json's) or a list of ids, minus
## `exclude`, never an id perks.json doesn't have. Sorted. Pure.
static func r30_perk_ids(rcfg: Dictionary, all_ids: Array) -> Array:
	var want: Variant = rcfg.get("perks", "all")
	var src: Array = all_ids if (want is String and str(want) == "all") else (want as Array if want is Array else [])
	var excl: Array = rcfg.get("exclude", [])
	var out: Array = []
	for v: Variant in src:
		var s: String = str(v)
		if s == "" or out.has(s) or excl.has(s) or not all_ids.has(s):
			continue
		out.append(s)
	out.sort()
	return out


## What the round-30 kit does for the guns in `slots` (WeaponInstances): {"do": "ok" (the main gun is taught to
## `tier` already), "teach" (teach slot `slot` to `tier`), "give" (no long gun can be taught: hand the fallback gun),
## "slot": int}. The main gun is the best long gun by economy tier (a taught gun counts its teachings); pistols and
## wonders are never it (T-163: a gun before a wonder). A best gun that can't be taught gives way to the next. Pure.
static func r30_gun_plan(slots: Array, eco: Dictionary, tier: int) -> Dictionary:
	var order: Array = []
	for i: int in slots.size():
		var w: WeaponInstance = slots[i]
		if w == null or w.weapon_class() == &"pistol" or w.weapon_class() == &"wonder":
			continue
		order.append([BotEconomy.tier_of(String(w.base_id()), w.upgraded, eco, w.tier), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	for e: Variant in order:
		var k: int = int((e as Array)[1])
		var w2: WeaponInstance = slots[k]
		if w2.upgraded and w2.tier >= tier:
			return {"do": "ok", "slot": k}
		if Crucible.action_for(w2) == &"upgrade":
			return {"do": "teach", "slot": k}
	return {"do": "give", "slot": -1}


## Does this Player take the round-30 kit? A live squad bot that came with the spawn kit (not a dropped online
## player's stand-in, whose own kit stays), a companion only with r30_kit.companions, never the bot-mode agent.
func r30_takes(p: Player) -> bool:
	if p == null or not is_instance_valid(p) or not p.is_bot or p.downed or p.spectating:
		return false
	var b: BotBrain = _brain_of(p.player_id)
	if b == null or b.is_player_bot:
		return false
	if p.is_companion:
		return bool((_cfg.get("r30_kit", {}) as Dictionary).get("companions", false))
	return bool(b.options.get("kit", true))


## Holds the whole round-30 kit: every kit tonic and a long gun taught to weapon_tier (smokes, the dev report).
func r30_kit_held(p: Player) -> bool:
	var rcfg: Dictionary = _cfg.get("r30_kit", {})
	for pk: Variant in r30_perk_ids(rcfg, (GLData.table("perks")["perks"] as Dictionary).keys()):
		if not PerkManager.has_perk(p.player_id, StringName(str(pk))):
			return false
	return p.weapons != null and str(r30_gun_plan(p.weapons.slots, BotAIData.table("economy"), int(rcfg.get("weapon_tier", 2))).get("do", "")) == "ok"


## Gives a bot the round-30 kit when it is due (spawn, a bleed-out respawn, a join or arrival, every round start;
## a revive only with on_revive): every kit tonic it lacks, quietly and outside the cap, and its main gun taught to
## weapon_tier. Idempotent. True when it handed anything.
func apply_r30_kit(p: Player, revive: bool = false) -> bool:
	if not Net.is_authority() or not r30_takes(p):
		return false
	var rcfg: Dictionary = _cfg.get("r30_kit", {})
	if not r30_kit_due(RoundManager.current_round, rcfg, GLSettings.values):
		return false
	if revive and not bool(rcfg.get("on_revive", false)):
		return false   # a down costs its tonics for the rest of the round; the next round start brings them back
	var pid: int = p.player_id
	var gave: bool = false
	for pk: Variant in r30_perk_ids(rcfg, (GLData.table("perks")["perks"] as Dictionary).keys()):
		var id: StringName = StringName(str(pk))
		if not PerkManager.has_perk(pid, id):
			PerkManager.grant(pid, id, true)
			gave = true
	if p.weapons != null:
		var tier: int = clampi(int(rcfg.get("weapon_tier", 2)), 1, WeaponInstance.max_tier())
		var plan: Dictionary = r30_gun_plan(p.weapons.slots, BotAIData.table("economy"), tier)
		match str(plan.get("do", "")):
			"teach":
				_r30_teach(p, int(plan["slot"]), tier)
				gave = true
			"give":
				var fid: StringName = StringName(str(rcfg.get("fallback_weapon", "thompson_up")))
				if (GLData.table("weapons").get("upgraded", {}) as Dictionary).has(String(fid)) \
						or (GLData.table("weapons")["weapons"] as Dictionary).has(String(fid)):
					if p.weapons.find_weapon(fid) == null and p.weapons.slots.size() >= p.weapons.max_slots():
						p.weapons.current_index = _weakest_slot(p)   # the taught gun takes the weakest slot's place
					p.weapons.give_weapon(fid)
					var k: int = p.weapons.slots.find(p.weapons.find_weapon(fid))
					if k >= 0:
						_r30_teach(p, k, tier)
					gave = true
				else:
					push_warning("bots.json r30_kit: no weapon '%s'" % fid)
	if gave:
		GLBus.perks_changed.emit(pid)
	return gave


## Teaches the gun in slot `k` to `tier` in place, the Crucible's way: an untaught gun becomes its taught form with
## its attachments and finish; the gun comes back full and goes into the hands.
func _r30_teach(p: Player, k: int, tier: int) -> void:
	var w: WeaponInstance = p.weapons.slots[k]
	if not w.upgraded:
		var up: StringName = w.upgrade_id()
		if up == &"":
			return
		var kit: Array = WeaponKit.encode(w.kit)
		var fin: String = String(w.finish)
		var nw: WeaponInstance = WeaponInstance.create(up)
		p.weapons.slots[k] = nw
		if not kit.is_empty() or fin != "":
			p.weapons.set_kit(up, kit, fin)
		w = nw
	w.tier = maxi(w.tier, tier)
	w.refill()
	p.weapons.current_index = k
	if p.weapons.has_method("_cancel_reload"):
		p.weapons.call("_cancel_reload")
	p.weapons.call("_rebuild_gun")
	if p.remote_body != null:
		p.remote_body.set_weapon(w.id)


func _start_planner() -> void:
	if GameState.bot_ai_mode == "off" or brains.is_empty():
		return
	var lc: Dictionary = _cfg.get("local_ai", {})
	var idx: int = clampi(int(lc.get("bot_index", 0)), 0, brains.size() - 1)
	var pl: BotPlanner = BotPlanner.new()
	pl.name = "Planner"
	brains[idx].add_child(pl)
	pl.setup(brains[idx], self, GameState.bot_ai_mode == "local")
	brains[idx].planner = pl


## T-237: every mapped weapon model file (models.json, 20 files, 8 MB) is asked of the loader threads once.
func _warm_models() -> void:
	if not StreamWarm.enabled:
		return
	_model_warm = StreamWarm.new()
	_model_warm.any_resource = true
	_model_warm.in_flight_max = 2
	for wid: Variant in (WeaponGLB.models().get("weapons", {}) as Dictionary).keys():
		_model_warm.add(WeaponGLB.glb_path(StringName(str(wid))))


func _start_ee() -> void:
	ee = BotEEHub.new()
	add_child(ee)
	ee.setup(self)


func _start_marks() -> void:
	mark_orders = BotMarkOrders.new()
	mark_orders.name = "MarkOrders"
	add_child(mark_orders)
	mark_orders.setup(self)


# ================================================================== the easter egg (Update 04 section 5, T-067)

## Gives an easter-egg step to a bot: {"ok": bool, "reason": String, "pid": int}. pid -1 = the best available bot
## (closest to the step, able to do it, not busy reviving). A player-only step comes back ok with the bot covering
## the player instead (reason says so). Refusals carry the reason ("Can't do that yet: we haven't heard the music
## box's melody.") and the bot says it.
func ee_assign(quest_id: StringName, step_id: StringName, pid: int = -1) -> Dictionary:
	if ee == null:
		return {"ok": false, "reason": "No bots in this match.", "pid": -1}
	return ee.assign(quest_id, step_id, pid, null, "ask")


## Could a bot be given this step right now? (the Objectives tab's "Assign to bot")
func ee_can_assign(quest_id: StringName, step_id: StringName) -> bool:
	return ee != null and ee.can_assign(quest_id, step_id)


## The bot's current egg task for status lines ({} none): {quest_id, step_id, type, label ("Collecting the radio
## notes (2/3)"), state ("use" / "input" / "hold" / "escort" / "wait" / "paused" ...), paused, source, ordered, pid}.
func ee_task_of(pid: int) -> Dictionary:
	return ee.task_of(pid) if ee != null else {}


## Cancels a bot's egg task (pid -1: every bot's).
func ee_cancel(pid: int = -1) -> void:
	if ee != null:
		ee.cancel(pid, "cancelled by the player")


## A map mark or the ping key on an egg object / part / power-up: the open step that object belongs to goes to the
## bot (pid -1 = the best one), with that object as its focus. Same return as ee_assign.
func ee_assign_node(node: Node, pid: int = -1) -> Dictionary:
	if ee == null:
		return {"ok": false, "reason": "No bots in this match.", "pid": -1}
	return ee.assign_node(node, pid, "mark")


func planner() -> BotPlanner:
	for b: BotBrain in brains:
		if b.planner != null:
			return b.planner
	return null


func _process(delta: float) -> void:
	_t += delta
	_round_t += delta
	if _model_warm != null and _model_warm.busy():
		_model_warm.tick()
	_callout_t = maxf(0.0, _callout_t - delta)
	var h: Player = human()
	if h != null and is_instance_valid(h):
		var v: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
		leader_vel = leader_vel.lerp(v, clampf(delta * 4.0, 0.0, 1.0))
		_crumb_t -= delta
		if _crumb_t <= 0.0 and not h.spectating:
			_crumb_t = 0.4
			if v.length() > 1.0 and (human_line.is_empty() or human_line[human_line.size() - 1].distance_to(h.global_position) > 0.8):
				human_line.append(h.global_position)
				if human_line.size() > 60:
					human_line.remove_at(0)


func time() -> float:
	return _t


func round_time() -> float:
	return _round_t


func director() -> ZombieDirector:
	return map.director


## The open zones' walkable layers. T-153: without the climb layers (ClimbLink): a bot can't climb a ladder, so its
## paths take the stairs.
func nav_mask() -> int:
	return (map.director.nav_mask if map.director != null else 0x7FFFFFFF) & ClimbLink.WALK_MASK


func human() -> Player:
	return map.player


func wall_buys() -> Array[WallBuy]:
	return _wall_buys


func player_by_id(pid: int) -> Player:
	var p: Player = map.players.get(pid) as Player
	if p == null:
		for b: BotBrain in brains:
			if b.player.player_id == pid:
				return b.player   # a companion (Jakub) is no match player
	return p


## T-237: the list is built once per frame (callers only read it): every bot's spacing, yielding and revive checks
## asked for it five to eight times a tick, a new array each time.
func all_players() -> Array[Player]:
	var key: Vector4i = Vector4i(Engine.get_physics_frames(), Engine.get_process_frames(), map.players.size(), brains.size())
	if key == _ap_key and BotProf.opt:
		return _ap_cache
	var out: Array[Player] = []
	for pid: Variant in map.players.keys():
		out.append(map.players[pid] as Player)
	for b: BotBrain in brains:
		if not out.has(b.player):
			out.append(b.player)   # a companion that isn't in the match's player table
	_ap_key = key
	_ap_cache = out
	return out


## Everyone on their feet (not downed, not spectating).
func standing() -> Array[Player]:
	var out: Array[Player] = []
	for p: Player in all_players():
		if is_instance_valid(p) and p.is_alive() and not p.spectating:
			out.append(p)
	return out


## The nearest standing teammate of `me` to `pos` (null when alone).
func nearest_standing(me: Player, pos: Vector3) -> Player:
	var best: Player = null
	var bd: float = INF
	for p: Player in standing():
		if p == me:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best


## Whom a bot follows: the human while they are in the match (standing or crawling), otherwise the first
## standing bot (which then leads: its leader is itself).
func leader_for(bot: BotBrain) -> Player:
	return leader_for_player(bot.player)


func leader_for_player(p: Player) -> Player:
	var h: Player = human()
	if h != null and not h.spectating:
		return h
	for b: BotBrain in brains:
		if b.player.is_alive() and not b.player.spectating and int(b.options.get("escort_pid", 0)) == 0:
			return b.player
	return p


## No human leads (benched, bled out): the bots decide doors and range themselves.
func bot_led() -> bool:
	var h: Player = human()
	return h == null or not is_instance_valid(h) or h.spectating or human_is_agent()


## T-058: no human is in the match at all (none, or one sitting the match out: out of the co-op life-cycle, like
## the bots3 soak's benched player). Then the squad is its own leader for the power too; a human who only bled
## out for the round is still in the match, and the power stays their step.
func bots_alone() -> bool:
	var h: Player = human()
	if h == null or not is_instance_valid(h):
		return true
	if human_is_agent():
		return true   # T-071: the agent playing the human leads like a squad alone (the power, the useful doors)
	return h.spectating and (Net.session == null or not Net.session.coop.players.has(h.player_id))


func kill_share_ok() -> bool:
	return BotConfig.human_share_ok(recent_kills, GameState.human_ids(), (_cfg.get("combat", {}) as Dictionary).get("kill_share", {}))


## Kept for T-031 callers: the downed player this bot holds the revive claim on.
func revive_target_for(bot: BotBrain) -> Player:
	return player_by_id(bot.revive_pid) if bot.revive_pid != 0 else null


func can_claim(node: Node, pid: int) -> bool:
	var id: int = node.get_instance_id()
	return not _claims.has(id) or int(_claims[id]) == pid


func claim(node: Node, pid: int) -> void:
	_claims[node.get_instance_id()] = pid


func release(node: Node, pid: int) -> void:
	var id: int = node.get_instance_id()
	if _claims.has(id) and int(_claims[id]) == pid:
		_claims.erase(id)


## An ordered door / part already taken by another bot (one goes; the rest follow).
func ordered_door_taken(node: Node, pid: int) -> bool:
	return not can_claim(node, pid)


# ================================================================== shared state (the brains call this at think)

## Rate-limited squad upkeep: memory, danger zones, revive and cover claims, roles, squad callouts.
func update_shared(now: float) -> void:
	if now - _shared_t < 0.15:
		return
	_shared_t = now
	blackboard.forget(now)
	blackboard.prune_danger(now)
	_update_danger(now)
	_assign_revives(now)
	if now - _roles_t >= float((BotAIData.table("actions").get("roles", {}) as Dictionary).get("roles_every_s", 2.0)):
		_roles_t = now
		_assign_roles()
		_pick_route()
	_call_t -= 0.15
	if _call_t <= 0.0:
		_call_t = 0.5
		_squad_callouts(now)
		_update_hunt(now)


## T-058: the round held up by its last one or two zombies (nothing left to spawn) for hunt_after_s: the squad
## tracks them down, the way a player follows the last zombie's groans and footsteps (a boss loose in another hall,
## a Foreman stuck in CHASE: the smoke_map02 stall). They go on the blackboard as heard (no line of sight, so no
## shooting through walls) and hunt_point() is where the idle / following bots walk (with a human too: it only
## ever starts after the round has stalled).
func _update_hunt(now: float) -> void:
	var hc: Dictionary = BotAIData.combat("hunt")
	hunt_at = Vector3.INF
	var d: ZombieDirector = director()
	if d == null or RoundManager.state != RoundManager.State.ROUND or RoundManager.to_spawn > 0 or EggMode.on():
		_stall_since = -1.0   # (T-181 Easter Egg Mode: a round ends on its own clock; nobody hunts the last crawler)
		return
	var act: Array = d.active_zombies()
	if act.is_empty() or act.size() > int(hc.get("max_left", 2)):
		_stall_since = -1.0
		return
	if player_bot != null and player_bot.crawler != null and player_bot.crawler.state != AgentCrawler.State.NONE:
		_stall_since = -1.0
		return   # T-071 pass 3: the agent's crawler break (it knows where its crawler is)
	if _stall_since < 0.0:
		_stall_since = now
	if now - _stall_since < float(hc.get("after_s", 12.0)):
		return
	var best: Zombie = null
	# U10 T-172: a round stalled this long is the squad's to finish, the "unreachable" one too: the game's recycle
	# never took a Foreman wedged by the Minehead (it kept chasing in place) and round 13 stayed open 130 game minutes
	var force: bool = now - _stall_since >= float(hc.get("force_after_s", 120.0))
	# (a reachable one first, then a boss: forced, a wedged Foreman must not win over a straggler we can get to)
	var best_rank: int = -1
	for z: Variant in act:
		var zz: Zombie = z as Zombie
		if zz == null or not is_instance_valid(zz) or not BotPerception.targetable(zz):
			continue
		var reach: bool = not is_unreachable(zz)
		if not (force or reach):
			continue
		var rank: int = hunt_rank(reach, BotPerception.is_boss(zz))
		if rank > best_rank:
			best_rank = rank
			best = zz
	if best == null:
		return
	hunt_at = best.global_position
	blackboard.sight(best, best.global_position, now, 0, best.tier, BotPerception.is_boss(best))


## The hunt's pick among the last zombies: one we can get to before one we can't, then a boss (highest wins).
static func hunt_rank(reachable: bool, boss: bool) -> int:
	return (2 if reachable else 0) + (1 if boss else 0)


## Where the squad hunts the round's last zombie (Vector3.INF: no hunt).
func hunt_point() -> Vector3:
	return hunt_at


## U10 T-172: how long the round has stalled with the squad hunting its last zombies (0 none).
func hunt_stalled_s() -> float:
	if hunt_at == Vector3.INF or _stall_since < 0.0:
		return 0.0
	return time() - _stall_since


## U10 (T-163): stragglers nobody can get to (instance id -> squad time until which they are left alone). A zombie
## wedged behind a collider the navmesh doesn't know (Kaltenbrunn's rail-yard fence line at x 41) has a path to us
## and we to it, and neither gets closer; a hunter walking up and down that fence kept resetting its no-progress
## timer (enemies.json no_progress_respawn_seconds: recycled after 40 s with nobody getting nearer), so the round
## never ended. Left alone, the game recycles it through a window.
var _unreachable: Dictionary = {}

func mark_unreachable(z: Zombie, seconds: float) -> void:
	if z != null and is_instance_valid(z):
		_unreachable[z.get_instance_id()] = time() + seconds


func is_unreachable(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and float(_unreachable.get(z.get_instance_id(), -INF)) > time()


## The training route (U03 section 3, TrainingRoute.for_map: the map's authored loops whose doors and zones are
## open): the one whose line passes nearest the leader, on their floor, within route_max_m; none (null: the
## locomotion layer's free loop round the human) otherwise. Refreshed with the roles.
func _pick_route() -> void:
	var leader: Player = leader_for_player(brains[0].player) if not brains.is_empty() else (player_bot.player if player_bot != null else null)
	if leader == null or map == null:   # (T-071 pass 3: solo, the agent's own brain: it gets its home loop too)
		blackboard.route = null
		return
	var best: TrainingRoute = null
	var best_d: float = float(BotAIData.combat("train").get("route_max_m", 12.0))
	for r: TrainingRoute in TrainingRoute.for_map(String(map.map_id)):
		var d: float = r.distance_to_line(leader.global_position)
		var c: Vector3 = r.center()
		if absf(c.y - leader.global_position.y) > 2.5:
			continue
		if d < best_d:
			best_d = d
			best = r
	home = null
	if bot_led():
		# T-058: a squad leading itself has a home loop (routes_<map>.json "home"); it trains there when the
		# leader isn't by another loop
		var home_s: float = -INF
		for r2: TrainingRoute in TrainingRoute.for_map(String(map.map_id)):
			# U10 (T-163): on the Moon a loop on the day side beats one the terminator has put in the night
			# (night zones spawn x1.5 and strain the suit)
			var hs: float = r2.home - (10.0 if BotSetPieces.night_at(get_tree() if is_inside_tree() else null, r2.center()) else 0.0)
			if r2.home > 0.0 and (home == null or hs > home_s):
				home = r2
				home_s = hs
		if player_bot != null:
			# T-071 pass 3: the agent's home is its plan's first open training ground (the yard once it is open)
			var order: Array = AgentPlan.plan_for(TrainingRoute.map_key_of(String(map.map_id))).get("train_at", [])
			var open_r: Array[TrainingRoute] = TrainingRoute.for_map(String(map.map_id), true)
			for rid: Variant in order:
				for r3: TrainingRoute in open_r:
					if r3.id == str(rid):
						home = r3
						break
				if home != null and home.id == str(rid):
					break
		if best == null:
			best = home
	blackboard.route = best
	blackboard.route_leader = leader.player_id


## T-058: where a self-led squad's leader goes when it has nothing else to do: the nearest point of the home loop
## (Vector3.INF when there is no home or a human leads).
func home_point(from: Vector3) -> Vector3:
	if home == null or not bot_led():
		return Vector3.INF
	return home.point_at(home.closest_param(from))


## Bosses' keep-away rings (ai_counters keep_distance_m), burning ground, Bell Domes (a soft zone: its edge).
func _update_danger(now: float) -> void:
	for e: Variant in blackboard.known(now):
		var z: Zombie = (e as Dictionary).get("node") as Zombie
		if z == null or not is_instance_valid(z):
			continue
		var kd: float = float(BotAIData.counter(z.enemy_id).get("keep_distance_m", 0.0))
		if kd > 0.0:
			blackboard.add_danger(z.global_position, kd, 2.0, now + 0.6, "boss:%d" % z.get_instance_id())
	var root: Node = map
	for n: Node in root.get_children():
		if n is BurningGround:
			blackboard.add_danger((n as Node3D).global_position, float((n as BurningGround).radius) + 0.4, 1.5, now + 0.6, "fire:%d" % n.get_instance_id())
		elif n is BellDome:
			blackboard.add_danger((n as Node3D).global_position, float((n as BellDome).radius), 0.4, now + 0.6, "dome:%d" % n.get_instance_id())


## Revive claims: per downed teammate (the human first, then bots, then companions) the nearest standing brain
## with a safe path claims it; when the spot is hot (combat.json revive cover_threat) another covers.
func _assign_revives(now: float) -> void:
	var s: NetMatch = Net.session
	if s == null:
		return
	var rc: Dictionary = BotAIData.combat("revive")
	var downed: Array = []
	for p: Player in all_players():
		if is_instance_valid(p) and s.coop.is_downed(p.player_id):
			downed.append(p)
	# claims on people who are up again (or gone) go
	for k: Variant in blackboard.claims.keys():
		var key: String = str(k)
		if key.begins_with("revive:") or key.begins_with("cover:"):
			var pid: int = int(key.get_slice(":", 1))
			if not s.coop.is_downed(pid):
				blackboard.claims.erase(k)
	downed.sort_custom(func(a: Player, b: Player) -> bool: return _revive_priority(a) < _revive_priority(b))
	for t: Player in downed:
		var key2: String = "revive:%d" % t.player_id
		var holder: int = blackboard.claimer(key2, now)
		var hb: BotBrain = _brain_of(holder)
		if hb != null and hb.player.is_alive() and not hb.player.spectating:
			_maybe_cover(t, holder, now, rc)
			continue
		if holder != 0:
			blackboard.claims.erase(key2)
		var best: BotBrain = null
		var best_s: float = INF
		for b: BotBrain in reviver_brains():
			if b.player == t or not b.player.is_alive() or b.player.spectating or b.player.downed:
				continue
			if not blackboard.held_by(b.player.player_id, "revive:").is_empty():
				continue
			var path: PackedVector3Array = b.open_path(b.player.global_position, b.snap(t.global_position))
			if path.is_empty():
				continue
			var plen: float = 0.0
			for i: int in range(1, path.size()):
				plen += path[i - 1].distance_to(path[i])
			if plen > float(rc.get("max_claim_path_m", 45.0)):
				continue
			var sc: float = plen
			if str(blackboard.roles.get(b.player.player_id, "")) == "medic":
				sc -= float(rc.get("medic_discount_m", 6.0))
			if not _path_safe(path, float(rc.get("path_safety_m", 1.6)), now):
				sc += 15.0
			if b.action == "revive" or b.action == "cover":
				sc -= 2.0
			if sc < best_s:
				best_s = sc
				best = b
		if best != null:
			blackboard.claim(key2, best.player.player_id, "revive", now, INF, t)
			_maybe_cover(t, best.player.player_id, now, rc)


func _revive_priority(p: Player) -> int:
	if GameState.human_ids().has(p.player_id) or p == human():
		return 0
	var b: BotBrain = _brain_of(p.player_id)
	return int(b.options.get("revive_priority", 1)) if b != null else 1


func _maybe_cover(t: Player, reviver: int, now: float, rc: Dictionary) -> void:
	var key: String = "cover:%d" % t.player_id
	if blackboard.claimer(key, now) != 0:
		return
	var rb: BotBrain = _brain_of(reviver)
	if rb == null or rb.perception.threat_near(t.global_position, 8.0) < float(rc.get("cover_threat", 0.35)):
		return
	var best: BotBrain = null
	var bd: float = INF
	for b: BotBrain in brains:
		var pid: int = b.player.player_id
		if pid == reviver or b.player == t or not b.player.is_alive() or b.player.spectating or b.player.downed:
			continue
		if not blackboard.held_by(pid, "revive:").is_empty() or not blackboard.held_by(pid, "cover:").is_empty():
			continue
		var d: float = b.player.global_position.distance_to(t.global_position)
		if d < bd and d < 30.0:
			bd = d
			best = b
	if best != null:
		blackboard.claim(key, best.player.player_id, "cover", now, INF, t)


func _path_safe(path: PackedVector3Array, r: float, now: float) -> bool:
	for e: Variant in blackboard.known(now):
		var zp: Vector3 = (e as Dictionary)["pos"]
		var z2: Vector2 = Vector2(zp.x, zp.z)
		for i: int in range(1, path.size()):
			var a: Vector2 = Vector2(path[i - 1].x, path[i - 1].z)
			var b: Vector2 = Vector2(path[i].x, path[i].z)
			if Geometry2D.get_closest_point_to_segment(z2, a, b).distance_to(z2) < r:
				return false
	return true


## Is `p` on the human's recent walking line (within `r`, same floor)? Holding spots, formation slots and idle
## bots keep off it, so a training player never runs into a bot.
func on_human_line(p: Vector3, r: float = 1.4) -> bool:
	for c: Vector3 in human_line:
		if Vector2(c.x - p.x, c.z - p.z).length() < r and absf(c.y - p.y) < 1.8:
			return true
	return false


## A revive finished: the claims on that player go.
func revive_done(pid: int) -> void:
	blackboard.claims.erase("revive:%d" % pid)
	blackboard.claims.erase("cover:%d" % pid)


## Squad roles (Update 03 section 5): the assignment of Medic / Anchor / Builder / Runner that best fits the
## standing brains' personality role_bias (every brain gets one; with fewer brains the best-fitting roles).
func _assign_roles() -> void:
	var bs: Array[BotBrain] = []
	for b: BotBrain in brains:
		if b.player.is_alive() and not b.player.spectating:
			bs.append(b)
	var roles: Array[String] = ["medic", "anchor", "builder", "runner"]
	var biases: Array = []
	for b2: BotBrain in bs:
		biases.append((b2.personality.get("role_bias", {}) as Dictionary))
	var pick: Array = BotSquad.best_roles(biases, roles)
	blackboard.roles.clear()
	for i: int in bs.size():
		if i < pick.size() and str(pick[i]) != "":
			blackboard.roles[bs[i].player.player_id] = str(pick[i])


## Pure: the role per brain (index-aligned with `biases`, each {role: weight}) maximising the summed bias, every
## role used at most once; brains beyond the roles get "". Ties go to the earlier role in `roles`.
static func best_roles(biases: Array, roles: Array[String]) -> Array:
	var st: Dictionary = {"best": [], "score": -INF}
	var used: Array[bool] = []
	used.resize(roles.size())
	used.fill(false)
	var cur: Array = []
	cur.resize(biases.size())
	cur.fill("")
	_roles_rec(biases, roles, 0, 0.0, used, cur, st)
	return st["best"]


static func _roles_rec(biases: Array, roles: Array[String], i: int, s: float, used: Array[bool], cur: Array, st: Dictionary) -> void:
	if i >= biases.size():
		if s > float(st["score"]) + 0.0001:
			st["score"] = s
			st["best"] = cur.duplicate()
		return
	var any: bool = false
	for r: int in roles.size():
		if used[r]:
			continue
		any = true
		used[r] = true
		cur[i] = roles[r]
		_roles_rec(biases, roles, i + 1, s + float((biases[i] as Dictionary).get(roles[r], 0.0)), used, cur, st)
		used[r] = false
	if not any:
		cur[i] = ""
		_roles_rec(biases, roles, i + 1, s, used, cur, st)


## "Sprinter, behind you!" (a known sprinter close behind a teammate, coming for them) and "Window's open!"
## (a window with no boards and zombies at it, nobody fixing it), each with a ping.
func _squad_callouts(now: float) -> void:
	var cc: Dictionary = BotAIData.combat("callouts")
	var behind_m: float = float(cc.get("sprinter_behind_m", 8.0))
	for p: Player in standing():
		var fwd: Vector3 = -p.global_basis.z
		fwd.y = 0.0
		for e: Variant in blackboard.known(now):
			var z: Zombie = (e as Dictionary).get("node") as Zombie
			if z == null or not is_instance_valid(z) or z.tier != &"sprint" or z.target != p:
				continue
			var to: Vector3 = z.global_position - p.global_position
			to.y = 0.0
			if to.length() > behind_m or to.length() < 1.0 or fwd.angle_to(to.normalized()) < deg_to_rad(80.0):
				continue
			var caller: BotBrain = _nearest_standing_brain(p.global_position, p)
			if caller != null:
				callout(caller, "SPRINTER_BEHIND", false, z.global_position, "SPRINTER")
			return
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or b.boards > 0:
			continue
		if float(_window_said.get(b.get_instance_id(), -INF)) > now - 25.0:
			continue
		var climbing: bool = false
		for e2: Variant in blackboard.known(now):
			var z2: Zombie = (e2 as Dictionary).get("node") as Zombie
			if z2 != null and is_instance_valid(z2) and z2.window == b and (z2.state == Zombie.State.CLIMB or z2.state == Zombie.State.WAIT_WINDOW):
				climbing = true
		if not climbing or blackboard.claimer("repair:%d" % b.get_instance_id(), now) != 0:
			continue
		var h: Player = human()
		var ref: Vector3 = h.global_position if h != null else b.global_position
		if b.global_position.distance_to(ref) > float(cc.get("window_open_m", 18.0)):
			continue
		var caller2: BotBrain = _nearest_standing_brain(b.global_position)
		if caller2 != null and callout(caller2, "WINDOW_OPEN", false, b.global_position + Vector3.UP * 1.2, "WINDOW OPEN"):
			_window_said[b.get_instance_id()] = now
			return


# ================================================================== the voice and the pings

## A survivor line from this bot's character (VO + subtitles), rolled against bots.json callouts.chance (by
## category, else its family: CMD_HOLD -> CMD) and rate-limited: one squad line at a time (cooldown_s) and a
## per-bot gap per family (per_bot_cooldown_s). force_categories skip the squad gap and the roll. With `ping_at`
## a world-space ping marker (BotPings) flashes there, labelled `ping_text`. Returns true when the line started.
func callout(bot: BotBrain, category: String, force: bool = false, ping_at: Vector3 = Vector3.INF, ping_text: String = "") -> bool:
	if bot != null and bot.is_player_bot:
		return false   # T-071: the agent playing you doesn't bark in your survivor's voice
	var cc: Dictionary = _cfg.get("callouts", {})
	var fam: String = category.get_slice("_", 0) if (category.begins_with("CMD_") or category.begins_with("BONUS_") or category.begins_with("PING_") or category.begins_with("TALLY_")) else category
	force = force or (cc.get("force_categories", []) as Array).has(fam)
	if _callout_t > 0.0 and not force:
		return false
	var key: String = "%d:%s" % [bot.player.player_id, fam]
	if _t < float(_bot_cd.get(key, -1.0)):
		return false
	var chances: Dictionary = cc.get("chance", {})
	var chance: float = float(chances.get(category, chances.get(fam, 0.0)))
	if not force and (chance <= 0.0 or randf() > chance):
		return false
	var spk: StringName = GLVO.CHARACTER_SPEAKERS.get(bot.player.character_id, &"")
	if spk == &"":
		return false   # a companion without bark lines here (Jakub's own VO comes with him)
	var ok: bool = GLVO.play_category(spk, category, 1.0, bot.player.player_id)
	if not ok and category.begins_with("PING_"):
		ok = GLVO.play_category(spk, "POWERUP_SEEN", 1.0, bot.player.player_id)
	if ok:
		_callout_t = float(cc.get("cooldown_s", 7.0))
		_bot_cd[key] = _t + float((cc.get("per_bot_cooldown_s", {}) as Dictionary).get(fam, 0.0))
		if ping_at != Vector3.INF:
			ping(ping_at, ping_text if ping_text != "" else category.replace("_", " "), bot)
		return true
	return false


## A world-space ping (and the blackboard's log of it).
func ping(at: Vector3, text: String, bot: BotBrain = null) -> void:
	blackboard.ping(at, text, text, _t, bot.player.player_id if bot != null else 0)
	if pings != null:
		pings.ping(at, text, float(BotAIData.combat("callouts").get("ping_s", 3.0)))


# ================================================================== orders (the command wheel)

## A squad order from the wheel (or the dev console / tests), any id in bots.json commands.orders: every brain
## takes it as a high-weight action for 60 s or until done (actions.json orders). "hold" holds `at` (the spot
## the human points at; their feet when INF); "open_door" / "fetch_part" act on the door, power switch or
## buildable part the human is looking at (`target`, or found along their view). The nearest bot acknowledges.
func set_command(cmd: StringName, at: Vector3 = Vector3.INF, target: Node = null) -> void:
	if cmd == &"":
		return
	order_given.emit(cmd, at)
	var h: Player = human()
	if cmd == &"hold":
		hold_point = at if at != Vector3.INF else (h.global_position if h != null else Vector3.INF)
	if BotConfig.COMMANDS.has(cmd):
		command = cmd
	order_target = null
	if cmd == &"open_door" or cmd == &"fetch_part":
		order_target = target if target != null else looked_at(cmd)
	for b: BotBrain in brains:
		b.on_order(cmd, at, order_target)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", "Squad: %s" % command_label(cmd), 1.4)
	var speaker: BotBrain = _nearest_standing_brain(h.global_position if h != null else Vector3.ZERO)
	if speaker != null:
		var moved: bool = cmd == &"follow" or cmd == &"train" or cmd == &"open_door" or cmd == &"fetch_part"
		if moved and bool((speaker.personality.get("callouts", {}) as Dictionary).get("grumble_on_move", false)) and randf() < 0.5 \
				and callout(speaker, "GRUMBLE", true):
			return
		callout(speaker, "CMD_" + String(cmd).to_upper(), true)


## What the human is looking at for open_door / fetch_part: the nearest door (or the power switch for
## open_door; a buildable part for fetch_part) inside a 14 degree cone of their view within 30 m, in sight.
func looked_at(cmd: StringName) -> Node:
	var h: Player = human()
	if h == null or h.camera == null:
		return null
	var cam: Camera3D = h.camera
	var from: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	var cands: Array[Node] = []
	if cmd == &"open_door":
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			if n is BuyDoor and not (n as BuyDoor).is_open:
				cands.append(n)
		for n2: Node in get_tree().get_nodes_in_group(&"power_switch"):
			cands.append(n2)
	else:
		for n3: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
			if n3 is Interactable and (n3 as Node3D).is_visible_in_tree() and (n3 as Interactable).can_interact(h):
				cands.append(n3)
	var best: Node = null
	var best_a: float = deg_to_rad(14.0)
	for c: Node in cands:
		var p: Vector3 = (c as Node3D).global_position + Vector3.UP * 1.0
		var to: Vector3 = p - from
		if to.length() > 30.0:
			continue
		var a: float = fwd.angle_to(to.normalized())
		if a < best_a:
			best_a = a
			best = c
	return best


static func command_label(cmd: StringName) -> String:
	return BotConfig.order_label(BotConfig.cfg(), cmd)


## Where a holding bot stands: a ring of commands.ring_radius_m around the hold point, by formation index.
func hold_spot(bot: BotBrain) -> Vector3:
	if hold_point == Vector3.INF:
		return Vector3.INF
	var r: float = float((_cfg.get("commands", {}) as Dictionary).get("ring_radius_m", 1.6))
	var a: float = TAU * float(bot.index) / float(maxi(1, brains.size())) + 0.4
	var p: Vector3 = hold_point + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var s: Vector3 = bot.snap(p)
	return s if s.distance_to(p) < 1.5 else bot.snap(hold_point)


func _nearest_standing_brain(p: Vector3, not_player: Player = null) -> BotBrain:
	var best: BotBrain = null
	var best_d: float = INF
	for b: BotBrain in brains:
		if not b.player.is_alive() or b.player.spectating or b.player == not_player:
			continue
		var d: float = b.player.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


# ================================================================== choke points (U02 section 5)

func _build_chokes() -> void:
	chokes.clear()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null:
			continue
		var half: Vector3 = Vector3(d.size.x * 0.5 + 0.1, d.size.y * 0.5 + 0.2, d.size.z * 0.5 + 0.75)
		var xf: Transform3D = Transform3D(d.global_basis, d.global_position + d.global_basis.y * d.size.y * 0.5)
		chokes.append({"box": box_aabb(xf, half), "kind": "door", "node": d})
	var re: RegEx = RegEx.create_from_string("(?i)(stair|ramp|flight|gangway)")
	for n2: Node in map.find_children("*", "StaticBody3D", true, false):
		if re.search(String(n2.name)) == null:
			continue
		for c: Node in n2.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var box: AABB = box_aabb(cs.global_transform, (cs.shape as BoxShape3D).size * 0.5)
			box.size.y += 2.0
			chokes.append({"box": box, "kind": "stair", "node": n2})


static func box_aabb(xf: Transform3D, half: Vector3) -> AABB:
	var box: AABB = AABB(xf.origin, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				box = box.expand(xf * Vector3(half.x * sx, half.y * sy, half.z * sz))
	return box


func choke_at(p: Vector3) -> Dictionary:
	var q: Vector3 = p + Vector3.UP * 0.3
	for c: Dictionary in chokes:
		if not (c["box"] as AABB).has_point(q):
			continue
		if str(c["kind"]) == "door" and is_instance_valid(c["node"]) and not (c["node"] as BuyDoor).is_open:
			continue
		return c
	return {}


## Soak instrumentation (the locomotion layer): a bot stayed in a choke longer than follow.choke_report_s.
func report_choke_for(p: Player, kind: String, pos: Vector3, seconds: float, tag: String = "") -> void:
	var b: BotBrain = _brain_of(p.player_id)
	choke_events.append("%s in a %s at (%.1f, %.1f, %.1f) for %.1fs (%s, round %d)" % [Net.display_name(p.player_id), kind,
		pos.x, pos.y, pos.z, seconds, tag if tag != "" else (b.action if b != null else "-"), RoundManager.current_round])


# ================================================================== telemetry and events

var down_log: PackedStringArray = []


func _log_down(pid: int) -> void:
	var p: Player = player_by_id(pid)
	if p == null or map == null or map.director == null:
		return
	var near3: int = 0
	var near6: int = 0
	var fast: int = 0
	for z: Zombie in map.director.active_zombies():
		var d: float = z.global_position.distance_to(p.global_position)
		if d < 3.0:
			near3 += 1
		if d < 6.0:
			near6 += 1
			if z.speed >= 4.0:
				fast += 1
	var mates: PackedStringArray = []
	for q: Player in standing():
		if q != p:
			mates.append("%s %.0fm" % [Net.display_name(q.player_id), q.global_position.distance_to(p.global_position)])
	var b: BotBrain = _brain_of(pid)
	var guns: PackedStringArray = []
	if p.weapons != null:
		for w: WeaponInstance in p.weapons.slots:
			guns.append("%s %d/%d" % [w.id, w.mag, w.reserve])
	down_log.append("r%d %s down at (%.0f,%.0f,%.0f): zombies <3m %d <6m %d (fast %d), %s, %s | standing: %s" % [RoundManager.current_round,
		Net.display_name(pid), p.global_position.x, p.global_position.y, p.global_position.z, near3, near6, fast,
		("action %s" % b.action) if b != null else "human", " ".join(guns), ", ".join(mates)])
	if b != null and not b.recent.is_empty():
		down_log.append("   before: " + " > ".join(b.recent.slice(maxi(0, b.recent.size() - 10))))


## A power-up dropped: onto the blackboard; the nearest standing bot that sees it calls it by name (our own
## power-up names only) with a ping.
func _on_powerup_spawned(id: StringName, pos: Vector3) -> void:
	var node: Node = null
	# (T-265: from the pickups' own group, not a walk over the map's every node in the frame a power-up drops)
	for n: Node in get_tree().get_nodes_in_group(&"powerups"):
		if n is PowerupPickup and map.is_ancestor_of(n) and (n as Node3D).global_position.distance_to(pos) < 1.5:
			node = n
	blackboard.add_powerup(node, id, pos, _t)
	var b: BotBrain = _nearest_standing_brain(pos)
	if b != null and b.player.global_position.distance_to(pos) < 22.0 and b.los_point(b.player.head.global_position, pos + Vector3.UP * 0.5):
		var names: Dictionary = GLData.table("powerups").get("names", {})
		var tok: String = str(GLVO.POWERUP_TOKENS.get(id, String(id).to_upper()))
		callout(b, "PING_" + tok, false, pos + Vector3.UP * 0.8, str(names.get(String(id), String(id).to_upper())))


## A boss: the squad's boss-caller (Peg) first, else the nearest bot.
func _on_boss_spawned(enemy_id: StringName) -> void:
	var caller: BotBrain = null
	for b: BotBrain in brains:
		if b.player.is_alive() and not b.player.spectating and bool((b.personality.get("callouts", {}) as Dictionary).get("boss_first", false)):
			caller = b
	if caller == null:
		var h: Player = human()
		caller = _nearest_standing_brain(h.global_position if h != null else Vector3.ZERO)
	if caller == null:
		return
	var at: Vector3 = Vector3.INF
	if map.director != null:
		for z: Zombie in map.director.active_zombies():
			if z.enemy_id == enemy_id:
				at = z.global_position + Vector3.UP * 2.2
	callout(caller, "BOSS_INCOMING", false, at, "BOSS")


func _on_crate_moved(_index: int) -> void:
	var crate: Node3D = null
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		var c: MysteryCrate = n as MysteryCrate
		if c != null and c.phase != MysteryCrate.Phase.HIDDEN:
			crate = c
	var h: Player = human()
	var b: BotBrain = _nearest_standing_brain(h.global_position if h != null else Vector3.ZERO)
	if b != null and crate != null:
		callout(b, "CRATE_MOVED", false, crate.global_position + Vector3.UP * 1.4, "CRATE")


func _on_door_opened(_door_id: StringName, by_player: int) -> void:
	if GameState.human_ids().has(by_player):
		human_doors_opened += 1
	for b: BotBrain in brains:   # T-237: what a brain remembered as out of reach may be in reach now
		if is_instance_valid(b):
			b.forget_reach()
	if player_bot != null and is_instance_valid(player_bot):
		player_bot.forget_reach()


func _brain_of(pid: int) -> BotBrain:
	for b: BotBrain in brains:
		if b.player.player_id == pid:
			return b
	if player_bot != null and is_instance_valid(player_bot) and player_bot.player.player_id == pid:
		return player_bot
	return null


## The brains that may claim a revive: the bots (and companions), plus the player bot (T-071).
func reviver_brains() -> Array[BotBrain]:
	if player_bot == null or not is_instance_valid(player_bot):
		return brains
	var out: Array[BotBrain] = brains.duplicate()
	out.append(player_bot)
	return out


func _on_enemy_killed(_enemy_id: StringName, _limb: StringName, _weapon_id: StringName, by_player: int) -> void:
	if by_player <= 0:
		return
	kills[by_player] = int(kills.get(by_player, 0)) + 1
	recent_kills.append(by_player)
	var window: int = int(((_cfg.get("combat", {}) as Dictionary).get("kill_share", {}) as Dictionary).get("window", 24))
	while recent_kills.size() > window * 2:
		recent_kills.pop_front()
	var b: BotBrain = _brain_of(by_player)
	if b != null:
		b.kills += 1
		# Wren keeps a running tally
		if bool((b.personality.get("callouts", {}) as Dictionary).get("kill_tally", false)) and [25, 50, 100, 150, 200, 300].has(b.kills):
			callout(b, "TALLY_%d" % b.kills, true)


func _on_round_started(_round: int, _special: bool) -> void:
	_round_t = 0.0
	_claims.clear()
	blackboard.clear_round_claims()
	for b: BotBrain in brains:
		b.on_round_started()
		if b.player != null and is_instance_valid(b.player) and not b.player.is_companion:
			apply_late_kit(b.player)   # U08 (T-130): bots alive when round 25 starts gear up
		if b.player != null and is_instance_valid(b.player):
			apply_r30_kit(b.player)   # T-186: and from round 30 every tonic and a taught main gun (after a revive too)
	if player_bot != null and is_instance_valid(player_bot):
		player_bot.on_round_started()


# ================================================================== dev: report, profiling, the overlay

## Average milliseconds per bot per physics frame (the 0.5 ms budget) and per think.
func think_stats() -> Dictionary:
	var ms: float = 0.0
	var think_ms: float = 0.0
	var n: int = 0
	for b: BotBrain in brains:
		ms += b.ms_per_frame()
		think_ms += b.us_think / 1000.0 / float(maxi(1, b.thinks))
		n += 1
	return {"ms_per_bot_frame": ms / float(maxi(1, n)), "ms_per_think": think_ms / float(maxi(1, n)), "bots": n}


func report() -> PackedStringArray:
	var out: PackedStringArray = []
	for b: BotBrain in brains:
		var w: WeaponInstance = b.player.weapons.current()
		out.append("%s (P%d, %s): kills %d shots %d hp %.0f scrip %d %s %s%s role %s teleports %d doors %d upgrades %d revives %d grenades %d tolls %d flanks %d high ground %d perks %s" % [
			Net.display_name(b.player.player_id), b.player.player_id, b.skill_name(), b.kills, b.shots, b.player.hp,
			Economy.get_scrip(b.player.player_id), str(w.id) if w != null else "-", b.action, " DOWN" if b.player.downed else "",
			b.role, b.teleports, b.doors_bought_total, b.upgrades, b.revives, b.aim.grenades_thrown, b.aim.great_tolls,
			b.actions.flanks, b.actions.high_ground_moves, ",".join(PackedStringArray(PerkManager.owned(b.player.player_id).map(func(x: Variant) -> String: return str(x))))])
		out.append("  hits %d of %d shots; misses hit first: %s" % [b.aim.hits_landed, b.shots, str(b.aim.miss_on)])
		if b.planner != null:
			out.append("  " + b.planner.status_line())
		if b.bonus_perk != &"":
			out.append("  bonus perk %s (announced %s)" % [b.bonus_perk, str(b.bonus_said)])
		if b.setpieces != null and b.setpieces.counts_line() != "":
			out.append("  setpieces " + b.setpieces.counts_line())   # U10 (T-163)
	var ts: Dictionary = think_stats()
	out.append("squad: order %s, revives by bots %d, choke reports %d, brain %.3f ms/bot/frame (think %.3f ms)" % [command, revives_total(), choke_events.size(),
		float(ts["ms_per_bot_frame"]), float(ts["ms_per_think"])])
	if ee != null:
		out.append_array(ee.report())
	if mark_orders != null:
		out.append_array(mark_orders.report())
	for e: String in choke_events.slice(0, 8):
		out.append("  CHOKE " + e)
	for e2: String in down_log.slice(maxi(0, down_log.size() - 24)):
		out.append("  DOWN " + e2)
	return out


func revives_total() -> int:
	var n: int = 0
	for b: BotBrain in brains:
		n += b.revives
	return n


func _cmd_ai_debug(a: PackedStringArray) -> String:
	var arg: String = a[0] if a.size() > 0 else "1"
	if debug == null:
		debug = BotDebugOverlay.new()
		debug.name = "BotDebugOverlay"
		add_child(debug)
		debug.setup(self)
	match arg:
		"0", "off":
			debug.set_enabled(false)
			return "AI debug off"
		"heat":
			debug.set_enabled(true)
			debug.heatmap = not debug.heatmap
			return "AI debug threat heatmap %s" % ("on" if debug.heatmap else "off")
		"panel":
			debug.set_enabled(true)
			debug.panel_on = not debug.panel_on
			return "AI debug blackboard panel %s" % ("on" if debug.panel_on else "off")
	debug.set_enabled(true)
	return "AI debug on (ai_debug heat: threat heatmap, ai_debug panel: blackboard, ai_debug 0: off)"
