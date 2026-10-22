class_name BotBrain
extends Node
## An AI teammate's brain (T-031; rebuilt for Update 03, T-055), a child of a bot Player (`is_bot`) or a companion
## (Jakub, U02 section 6). The orchestrator of perception -> utility -> aim -> locomotion:
##   BotPerception  senses (a sight cone with budgeted rays, hearing, the squad blackboard; no wallhacks), threat
##   BotUtility     every think (~5 Hz, staggered across bots) each action in data/gravelight/ai/actions.json
##                  scores 0..1 from its considerations (the context below) through response curves, x the
##                  personality (personality_<char>.json) x the squad role + an active order's boost; the best
##                  runs, with hysteresis for the running one (+ a commit bonus while it is mid-task)
##   BotActions     the executors: what to do this frame for the chosen action (Fight, Train, Hold, Retreat,
##                  Reload, Revive, Cover, Repair, Buy, Crate, Power-up, Follow, Regroup, Escort, Trap, Chatter,
##                  the planner's Objective, an Order); task actions run through BotTasks
##   BotAim         target choice, a human-like aim (reaction, convergence with overshoot, shrinking tracking
##                  error), fire discipline, reloads, weapon choice (the pistol-trap fix), the knife, grenades,
##                  the Totenglocke
##   BotEconomy     its own Scrip by priority, a reserve kept; never easter-egg objects, traps or the power switch
##                  unless ordered or the human already did that step
##   loco           the locomotion layer (BotLocomotion, U03 section 3; the BotMoveAdapter as the "v1" fallback)
## The squad blackboard (BotSquad.blackboard) holds what they share: known zombies (4 s memory), claims (revives,
## covers, windows), the training route, danger zones, power-ups, pings, roles.
## Kept from before: the local-AI planner (its directive is the Objective action's errand, a high-weight action),
## the U02 section 5 bonus perk and its lines, the RemoteBody poses, nameplates, barks, the command wheel
## (orders are high-weight actions for 60 s or until done; BotMetrics.command_issued / command_done).
## No cheats: no free pistol refills, no hidden health buff, no perception through walls. The spawn kit (Thompson,
## Ironhide, Second Wind) and the bonus perk are its visible advantages.

## Brain options (BotSquad.add_brain merges overrides before setup). perks: drinks perks (kit, bonus, shopping);
## bonus_perk; shopping: buys guns / doors / the Crucible / the crate; kit: the spawn kit; accuracy_mult: scales
## the aim error (~1.4 = "70% of a player"); personality: a personality_<id>.json profile ("" = its character);
## escort_pid: the player it escorts (Jakub: the one who freed him); armed: carries a gun (Jakub unarmed: the coal
## shovel); ammo_payer_pid / ammo_price_mult: who pays its ammo boxes and at what share (Jakub: the party at 0.5);
## revive_priority: 0 human, 1 bot, 2 companion (lower is revived first); counts_as_bot: it is in the squad's
## bot list for leading.
var options: Dictionary = {"perks": true, "bonus_perk": true, "shopping": true, "kit": true, "accuracy_mult": 1.0,
	"personality": "", "escort_pid": 0, "armed": true, "ammo_payer_pid": 0, "ammo_price_mult": 1.0, "revive_priority": 1}

var player: Player
var squad: BotSquad
var index: int = 0
var skill: Dictionary = {}
var personality: Dictionary = {}
var think_hz: float = 5.0
var perception: BotPerception
var aim: BotAim
## The locomotion layer: BotLocomotion (U03 section 3, bots.json "locomotion": "v2"), or the BotMoveAdapter over
## the T-031 movement ("v1", the soak's --loco=v1 A/B runs). The same API either way.
var loco
var actions: BotActions
var tasks: BotTasks
var economy: BotEconomy

## The running action (an actions.json id) and the last think's scores (the debug overlay).
var action: String = "idle"
var scores: Dictionary = {}
var top3: Array = []
var role: String = ""
## The errand a task action runs ({} none).
var task: Dictionary = {}
## Set by executors while mid-task this frame (a revive hold, a buy hold): the commit bonus at the next think.
var committed: bool = false
var revive_pid: int = 0
var cover_pid: int = 0

var kills: int = 0
var revives: int = 0
var doors_bought_total: int = 0
var doors_bought_round: int = 0
var upgrades: int = 0
var objectives_done: int = 0
var planner: BotPlanner = null
var bonus_perk: StringName = &""
var bonus_said: bool = false
## The legacy squad order (BotConfig.COMMANDS) this bot follows; `order_id()` is the full one.
var command: StringName = &"follow"

## Profiling (the 0.5 ms per bot budget): microseconds spent in this brain, physics frames counted.
var us_total: float = 0.0
var us_think: float = 0.0
var frames: int = 0
var thinks: int = 0

var shots: int:
	get:
		return aim.shots if aim != null else 0
var target: Zombie:
	get:
		return aim.target if aim != null else null
var teleports: int:
	get:
		return int(loco.get("teleports")) if loco != null and loco.get("teleports") != null else 0
var choke_reports: int:
	get:
		return int(loco.get("choke_reports")) if loco != null and loco.get("choke_reports") != null else 0

var _cfg: Dictionary = {}
var _acfg: Dictionary = {}
var _curves: Dictionary = {}
var _pcfg: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _think_t: float = 0.0
var _nav_ready: bool = false
var _was_down: bool = false
var _was_out: bool = false
var _was_committed: bool = false
var _sticky: bool = false
var _action_t: float = 0.0
var _stand_cache: Dictionary = {}
var _doors: Array[BuyDoor] = []
var _traps: Array[Node] = []
var _levers: Array[Node] = []
var _bonus_due_t: float = INF
var _sprint_t: float = 0.0
var _chatter_next: float = 0.0
var _ctx: Dictionary = {}
# orders
var _order_id: StringName = &""
var _order_t: float = -INF
var _order_node: Node = null
var _order_at: Vector3 = Vector3.INF
var _order_reported: bool = true
var _order_done: bool = false
# hold / power-ups / traps / planner
var _hold: Dictionary = {}
var _hold_key: String = ""
var _hold_t: float = -10.0
var _powerup_key: Variant = null
var _powerup_v: float = 0.0
var _trap_c: Dictionary = {}
var _planner_c: Dictionary = {}
var _revive_path_m: float = INF
var _revive_path_t: float = -10.0
var _human_used_traps: Dictionary = {}
var _task_block_t: float = -1.0


func setup(bot_player: Player, bot_squad: BotSquad, i: int) -> void:
	player = bot_player
	squad = bot_squad
	index = i
	_cfg = BotConfig.cfg()
	_acfg = BotAIData.table("actions")
	_curves = BotAIData.table("curves")
	_pcfg = GLData.table("player")
	skill = BotConfig.skill(_cfg, GameState.bot_skill)
	var pid_name: String = str(options.get("personality", ""))
	personality = BotAIData.personality(pid_name if pid_name != "" else String(player.character_id))
	think_hz = float(_acfg.get("think_hz", 5.0)) * float(skill.get("think_hz_mult", 1.0))
	_rng.randomize()
	_think_t = 0.2 / maxf(1.0, float(squad.brains.size() + 1)) * float(i) + 0.05   # stagger the squad's thinking
	player.bot_damage_mult = 1.0   # no hidden health buff (Update 03 section 7)
	perception = BotPerception.new()
	perception.setup(player, squad)
	if BotLocomotion.enabled(_cfg):
		loco = BotLocomotion.new()
	else:
		loco = BotMoveAdapter.new()
		loco.index = i
	loco.setup(player, squad)
	aim = BotAim.new()
	aim.setup(self)
	actions = BotActions.new()
	actions.setup(self)
	tasks = BotTasks.new()
	tasks.setup(self)
	economy = BotEconomy.new()
	economy.setup(self)
	command = squad.command
	GLBus.explosion.connect(_on_explosion)
	GLBus.player_damaged.connect(_on_player_damaged)
	GLBus.trap_activated.connect(_on_trap_activated)
	PerkManager.overclock_triggered.connect(func(pid: int, _spent: float) -> void:
		if pid == player.player_id:
			bonus_event("overclock"))


func skill_name() -> String:
	return GameState.bot_skill


func _ready() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor:
			_doors.append(n as BuyDoor)
	for t: Node in get_tree().get_nodes_in_group(&"traps"):
		if t.has_method("danger_contains"):
			_traps.append(t)
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	for lv: Node in root.find_children("*", "TrapLever", true, false):
		_levers.append(lv)


func loco_doors() -> Array[BuyDoor]:
	return _doors


# ================================================================== orders (the command wheel)

## A squad order (BotSquad.set_command): any id from bots.json commands.orders. `node` = what the human pointed
## at for "open_door" / "fetch_part" (a door, a buildable part, the power switch).
func on_order(order_id: StringName, at: Vector3 = Vector3.INF, node: Node = null) -> void:
	_order_id = order_id
	_order_t = squad.time()
	_order_node = node
	_order_at = at
	_order_reported = false
	_order_done = false
	if BotConfig.COMMANDS.has(order_id):
		command = order_id
	_think_t = 0.0
	if not task.is_empty():
		drop_task()
	BotMetrics.command_issued(player.player_id, order_id)
	if order_id == &"save_scrip" or ((order_id == &"open_door" or order_id == &"fetch_part") and node == null):
		_report_order()


## Kept for callers of the T-031 API: a built-in order.
func on_command(cmd: StringName) -> void:
	on_order(cmd)


## The order in force ("" after it ran out or was done): orders last actions.json orders.<id>.duration_s.
func order_id() -> StringName:
	if _order_id == &"" or _order_done:
		return &""
	var o: Dictionary = (_acfg.get("orders", {}) as Dictionary).get(String(_order_id), {})
	if BotUtility.order_strength(squad.time() - _order_t, float(o.get("duration_s", 60.0))) <= 0.0:
		return &""
	return _order_id


func order_node() -> Node:
	return _order_node if _order_node != null and is_instance_valid(_order_node) else null


func _report_order() -> void:
	if not _order_reported:
		_order_reported = true
		BotMetrics.command_done(player.player_id, _order_id)


## Which actions answer an order (the response time ends when one of them runs).
static func order_response(order_id: StringName) -> PackedStringArray:
	match order_id:
		&"hold":
			return ["hold", "fight", "repair"]
		&"follow":
			return ["follow", "regroup", "fight", "train"]
		&"train":
			return ["train", "follow"]
		&"repair":
			return ["repair"]
		&"revive":
			return ["revive", "cover"]
		&"buy_perks":
			return ["buy"]
		&"open_door", &"fetch_part":
			return ["order"]
	return []


# ================================================================== the bonus perk (U02 section 5)

func bonus_event(kind: String) -> void:
	if bonus_said or bonus_perk == &"" or player.downed:
		return
	var bcfg: Dictionary = _cfg.get("bonus_perk", {})
	if kind != "fallback" and BotConfig.bonus_trigger(bcfg, bonus_perk) != kind:
		return
	if not GLVO.PERK_TOKENS.has(bonus_perk):
		bonus_said = true
		return
	bonus_said = squad.callout(self, "BONUS_" + str(GLVO.PERK_TOKENS[bonus_perk]), true)


func _on_explosion(pos: Vector3, radius: float) -> void:
	if player != null and player.is_inside_tree() and pos.distance_to(player.global_position) < radius + 3.0:
		bonus_event("explosion")


func _on_player_damaged(pid: int, amount: float) -> void:
	if pid == player.player_id and amount > 0.0 and player.hp < player.max_hp * 0.6:
		bonus_event("hurt")


func _on_trap_activated(trap_id: StringName, by_player: int) -> void:
	if GameState.human_ids().has(by_player):
		_human_used_traps[trap_id] = true


## A new round: claims, door counts and the bonus-perk fallback. (No free pistol refill: Update 03 section 7.)
func on_round_started() -> void:
	doors_bought_round = 0
	economy.crate_pulls_this_round = 0
	economy.invalidate()
	aim.on_round_started()
	_hold = {}
	_hold_key = ""
	if RoundManager.current_round >= int((_cfg.get("bonus_perk", {}) as Dictionary).get("fallback_round", 4)) and not bonus_said:
		_bonus_due_t = squad.time() + 6.0


# ================================================================== per frame

func _physics_process(delta: float) -> void:
	if player == null or not player.is_inside_tree() or GameState.phase != GameState.Phase.PLAYING:
		return
	if not _nav_ready:
		_nav_ready = NavigationServer3D.map_get_iteration_id(player.get_world_3d().navigation_map) > 0
		if not _nav_ready:
			return
	var t0: int = Time.get_ticks_usec()
	_was_committed = committed or _was_committed
	committed = false
	aim.tick_timers(delta)
	if player.spectating:
		_set_action("out")
		_was_out = true
		aim.cancel_reload()
		squad.blackboard.release_all(player.player_id)
		_pose(delta)
		_account(t0)
		return
	if player.downed:
		_was_down = true
		_think_t -= delta
		if _think_t <= 0.0:
			_think_t = 1.0 / maxf(1.0, think_hz)
			perception.sense(squad.time())
			aim.think(squad.time())
		_set_action("downed")
		_tick_downed(delta)
		_pose(delta)
		_account(t0)
		return
	if _was_down or _was_out:
		# up again (revived, or respawned after a bleed-out): the kit's perks again, its guns after a respawn
		if bool(options.get("kit", true)) and bool((_cfg.get("spawn_kit", {}) as Dictionary).get("restore_after_down", true)):
			squad.apply_kit(player, _was_out)
		_was_down = false
		_was_out = false
		action = "idle"
	player._update_health(delta)
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 1.0 / maxf(1.0, think_hz)
		var tt: int = Time.get_ticks_usec()
		_think()
		us_think += float(Time.get_ticks_usec() - tt)
		thinks += 1
	loco.clear_look()   # a look lasts one frame: the aim layer (or the executor) asks again every frame
	actions.run(action, delta)
	loco.tick(delta)
	_sprint_t = _sprint_t + delta if player.sprinting else 0.0
	if _sprint_t > 1.0:
		bonus_event("sprint")
	_pose(delta)
	_account(t0)


func _account(t0: int) -> void:
	us_total += float(Time.get_ticks_usec() - t0)
	frames += 1


## Average milliseconds per physics frame this brain has cost (perception, utility, aim, locomotion).
func ms_per_frame() -> float:
	return us_total / 1000.0 / float(maxi(1, frames))


func _set_action(id: String) -> void:
	if action == id:
		return
	if actions != null and action != "out" and action != "downed":
		actions.exit(action)
	action = id
	_action_t = squad.time()


# ================================================================== think (~5 Hz)

func _think() -> void:
	var now: float = squad.time()
	perception.sense(now)
	squad.update_shared(now)
	aim.force_slot = forced_slot()
	if action != "cover":
		aim.cover_point = Vector3.INF
	aim.think(now)
	_read_claims(now)
	if player.remote_body != null:
		var cw: WeaponInstance = aim.cur()
		player.remote_body.set_weapon(cw.id if cw != null else &"")
	if not bonus_said and now >= _bonus_due_t:
		_bonus_due_t = now + 4.0
		bonus_event("fallback")
	_ctx = context(now)
	var mods: Dictionary = {"personality": personality.get("actions", {}), "role": (_acfg.get("roles", {}) as Dictionary).get(role, {})}
	var oid: StringName = order_id()
	if oid != &"":
		mods.merge(BotUtility.order_mods(_acfg, String(oid), 1.0), true)
	scores = BotUtility.score_all(_acfg, _ctx, _curves, mods)
	var commit: float = float(_acfg.get("commit_bonus", 0.3)) if _was_committed else 0.0
	if _sticky:
		commit += 1.0
	_was_committed = false
	var pick: Array = BotUtility.choose(scores, action, float(_acfg.get("hysteresis", 0.1)), commit, float(skill.get("decision_noise", 0.0)), _rng)
	var best: String = str(pick[0]) if str(pick[0]) != "" else "idle"
	if _sticky and best != action and not (["revive", "retreat", "cover"].has(best) and float(scores.get(best, 0.0)) > 0.8):
		best = action   # a gun in the Crucible, a paid crate, a held objective: only an emergency pulls it away
	top3 = BotUtility.top(scores, 3)
	if best != action and (now - _action_t >= float(_acfg.get("min_action_s", 0.4)) or action == "idle" or best == "retreat" or best == "revive"):
		_set_action(best)
		actions.enter(best)
	if not _order_reported and order_response(_order_id).has(action):
		_report_order()


## The normalised considerations (actions.json _inputs).
func context(now: float) -> Dictionary:
	var c: Dictionary = {}
	var per: BotPerception = perception
	var w: WeaponInstance = aim.cur()
	c["hp"] = clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)
	c["mag"] = float(w.mag) / float(maxi(1, w.mag_size())) if w != null else 0.0
	c["mag_reserve"] = 1.0 if w != null and w.reserve > 0 and w.mag < w.mag_size() else 0.0
	var best_ammo: float = 0.0
	var any_ammo: bool = false
	var armed_: bool = armed()
	for sw: WeaponInstance in player.weapons.slots:
		if sw.mag > 0 or sw.reserve > 0:
			any_ammo = true
		if sw.weapon_class() != &"pistol":
			best_ammo = maxf(best_ammo, float(sw.mag + sw.reserve) / float(maxi(1, sw.mag_size() + sw.reserve_max())))
	c["ammo"] = best_ammo
	c["any_ammo"] = 1.0 if any_ammo else 0.0
	c["armed"] = 1.0 if armed_ else 0.0
	c["reloading"] = 1.0 if aim.reloading else 0.0
	c["pressure"] = per.pressure
	c["near"] = clampf(per.nearest_d / 20.0, 0.0, 1.0)
	c["n5"] = clampf(float(per.n5) / 6.0, 0.0, 1.0)
	c["n10"] = clampf(float(per.n10) / 12.0, 0.0, 1.0)
	c["known"] = clampf(float(per.known.size()) / 12.0, 0.0, 1.0)
	c["sprinter_close"] = 1.0 if per.sprinter_close else 0.0
	c["has_target"] = 1.0 if aim.target != null and (armed_ or per.nearest_d < 3.0) else 0.0
	# revives
	var rc: Dictionary = BotAIData.combat("revive")
	c["revive_mine"] = 0.0
	c["revive_bleed"] = 1.0
	c["revive_blocked"] = 0.0
	c["revive_path"] = 0.0
	c["reviving"] = 1.0 if actions.reviving() else 0.0
	c["revive_speed"] = clampf(2.0 / maxf(0.5, revive_seconds()), 0.0, 1.0)
	var rt: Player = squad.player_by_id(revive_pid) if revive_pid != 0 else null
	if rt != null and Net.session != null and Net.session.coop.is_downed(revive_pid):
		c["revive_mine"] = 1.0
		var left: float = Net.session.coop.bleed_left(revive_pid)
		var full: float = rt.bleedout_seconds if rt.bleedout_seconds > 0.0 else float(_pcfg.get("bleedout_seconds", 45.0))
		c["revive_bleed"] = clampf(left / maxf(1.0, full), 0.0, 1.0)
		var swarmed: bool = per.count_near(rt.global_position, float(rc.get("blocked_crowd_m", 3.0))) >= int(rc.get("blocked_crowd", 2))
		var blocked: bool = (per.sprinter_near(rt.global_position, float(rc.get("blocked_sprinter_m", 6.0))) and left >= float(rc.get("blocked_bleed_s", 10.0))) 			or (swarmed and left >= float(rc.get("blocked_crowd_bleed_s", 20.0)))
		if left < float(rc.get("last_chance_s", 8.0)):
			blocked = false
		c["revive_blocked"] = 1.0 if blocked else 0.0
		if now - _revive_path_t > 1.0:
			_revive_path_t = now
			_revive_path_m = loco.path_length_to(rt.global_position)
		c["revive_path"] = clampf(_revive_path_m / 30.0, 0.0, 1.0) if _revive_path_m != INF else 1.0
		if blocked and cover_pid == 0:
			cover_pid = revive_pid
	c["cover_need"] = 1.0 if cover_pid != 0 else 0.0
	# the squad
	var leader: Player = squad.leader_for(self)
	c["is_leader"] = 1.0 if leader == player or leader == null else 0.0
	c["leader_far"] = 0.0 if leader == player or leader == null else clampf(_flat(leader.global_position, player.global_position) / 20.0, 0.0, 1.0)
	var mate: Player = squad.nearest_standing(player, player.global_position)
	c["squad_far"] = clampf(_flat(mate.global_position, player.global_position) / 20.0, 0.0, 1.0) if mate != null else 0.0
	if roaming():
		c["squad_far"] = 0.0
		c["leader_far"] = 0.0
	c["break"] = 1.0 if in_break() else 0.0
	c["round"] = clampf(float(RoundManager.current_round) / 30.0, 0.0, 1.0)
	c["loop"] = 1.0 if loco.train_ok() and armed_ else 0.0
	c["hold_spot"] = 0.0 if hold_spot().is_empty() else 1.0
	# tasks
	var calm: bool = per.pressure < 0.6
	var b: Dictionary = economy.best(now) if calm and now >= _task_block_t else {}
	c["repair_task"] = float((b.get("repair", {}) as Dictionary).get("value", 0.0))
	c["buy_task"] = float((b.get("buy", {}) as Dictionary).get("value", 0.0))
	c["crate_task"] = float((b.get("crate", {}) as Dictionary).get("value", 0.0))
	var rb: Dictionary = economy.best(now) if per.pressure < 0.85 and now >= _task_block_t else {}
	c["resupply_task"] = float((rb.get("resupply", {}) as Dictionary).get("value", 0.0))
	c["powerup_task"] = _powerup_value(now)
	c["trap_task"] = _trap_value()
	c["chatter_ok"] = 1.0 if now >= _chatter_next else 0.0
	c["objective"] = 1.0 if _planner_ready() else 0.0
	c["order"] = 1.0 if not _order_task().is_empty() else 0.0
	var esc: Player = escort_target()
	c["escort"] = 1.0 if esc != null else 0.0
	c["escort_far"] = clampf(_flat(esc.global_position, player.global_position) / 15.0, 0.0, 1.0) if esc != null else 0.0
	if not task.is_empty():
		# the errand under way keeps its value (the economy no longer lists what it already paid for)
		var key: String = str({"buy": "buy_task", "repair": "repair_task", "crate": "crate_task", "trap": "trap_task", "resupply": "resupply_task",
			"objective": "objective", "order": "order"}.get(str(task.get("action", "")), ""))
		if key != "":
			c[key] = maxf(float(c.get(key, 0.0)), float(task.get("value", 0.7)) if key.ends_with("_task") else 1.0)
	_sticky = not task.is_empty() and (crucible_sticky() or str(task.get("kind", "")) == "hold" or bool(task.get("paid", false)) or str(task.get("kind", "")) == "shoot_moving")
	return c


## Revive / cover claims from the blackboard (BotSquad.update_shared hands them out).
func _read_claims(now: float) -> void:
	var bb: BotBlackboard = squad.blackboard
	var rv: Array[String] = bb.held_by(player.player_id, "revive:")
	revive_pid = int(rv[0].get_slice(":", 1)) if not rv.is_empty() else 0
	var cv: Array[String] = bb.held_by(player.player_id, "cover:")
	cover_pid = int(cv[0].get_slice(":", 1)) if not cv.is_empty() else 0
	if cover_pid != 0 and (Net.session == null or not Net.session.coop.is_downed(cover_pid)):
		bb.release("cover:%d" % cover_pid, player.player_id)
		cover_pid = 0
	role = str(bb.roles.get(player.player_id, ""))
	if revive_pid == 0:
		_revive_path_t = -10.0


# ================================================================== helpers the layers share

func facing() -> Vector3:
	var y: float = player.rotation.y
	var p: float = player.head.rotation.x
	return Vector3(-sin(y) * cos(p), sin(p), -cos(y) * cos(p))


func armed() -> bool:
	if not bool(options.get("armed", true)):
		return false
	for w: WeaponInstance in player.weapons.slots:
		if w.mag > 0 or w.reserve > 0 or w.mag_size() > 0:
			return true
	return false


func in_break() -> bool:
	return RoundManager.state != RoundManager.State.ROUND or (RoundManager.to_spawn <= 0 and perception.known.is_empty() and squad.director() != null and squad.director().active_zombies().is_empty())


func escort_target() -> Player:
	var pid: int = int(options.get("escort_pid", 0))
	if pid <= 0:
		return null
	var p: Player = squad.player_by_id(pid)
	return p if p != null and is_instance_valid(p) and not p.spectating else null


func revive_seconds() -> float:
	return CoopState.revive_seconds(float(_pcfg["revive_seconds"]), float(PerkManager.stat(player.player_id, "revive_speed_mult", 1.0)))


func personality_combat(key: String, fallback: Variant) -> Variant:
	return (personality.get("combat", {}) as Dictionary).get(key, fallback)


func personality_economy(key: String, fallback: Variant) -> Variant:
	return (personality.get("economy", {}) as Dictionary).get(key, fallback)


## Easter-egg shootables (bells, the drummer) react to this bot's shots: only the local-AI planner bot.
func may_touch_quest() -> bool:
	return planner != null


## On an objective of its own (the planner, not "follow"): it fights where it stands instead of following.
func roaming() -> bool:
	return planner != null and not planner.directive.is_empty() and str(planner.directive.get("kind", "")) != "follow"


func leader_moving(leader: Player) -> bool:
	if leader == null or leader == player or leader.downed:
		return false
	var v: Vector3 = squad.leader_vel if leader == squad.human() else Vector3(leader.velocity.x, 0.0, leader.velocity.z)
	return v.length() > float((_cfg.get("follow", {}) as Dictionary).get("moving_speed_mps", 1.6))


## A live trap or a blackboard danger zone covers `p`.
func in_danger(p: Vector3) -> bool:
	for t: Node in _traps:
		if is_instance_valid(t) and bool(t.call("danger_contains", p)):
			return true
	return squad.blackboard.danger_at(p, squad.time()) >= 1.0


## Looks around while nothing needs aiming: at the nearest known zombie, where a teammate is shooting, along the
## leader's facing.
func idle_look(_delta: float, leader: Player = null) -> void:
	var per: BotPerception = perception
	if per.nearest != null and per.nearest_d < 16.0:
		loco.look_at_dir(per.pos_of(per.nearest) + Vector3.UP * 1.2 - aim.eye())
	elif per.attention != Vector3.INF and squad.time() < per.attention_until:
		loco.look_at_dir(per.attention - aim.eye())
	elif leader != null and is_instance_valid(leader):
		loco.look_at_dir(-leader.global_basis.z)
	else:
		loco.clear_look()


func say_chatter() -> void:
	var cc: Dictionary = BotAIData.combat("chatter")
	_chatter_next = squad.time() + float(cc.get("cooldown_s", 40.0))
	if randf() < float(cc.get("chance", 0.5)):
		squad.callout(self, "CHATTER")


# ================================================================== tasks

## Starts the errand for a task action (Buy, Repair, Crate, Trap, Order, Objective), with its claim.
func start_task(kind: String) -> void:
	task = {}
	var now: float = squad.time()
	var c: Dictionary = {}
	match kind:
		"buy", "repair", "crate", "resupply":
			c = (economy.best(now).get(kind, {}) as Dictionary)
		"trap":
			c = _trap_c
		"order":
			c = _order_task()
		"objective":
			c = _planner_c
	if c.is_empty() or not is_instance_valid(c.get("node")):
		_task_unavailable(kind)
		return
	var node: Node = c["node"]
	var pid: int = player.player_id
	if c.has("key"):
		if not squad.blackboard.claim(str(c["key"]), pid, str(c.get("kind", "")), now, now + 30.0):
			_task_unavailable(kind)
			return
	elif ["gun", "ammo", "perk", "door", "crucible", "crucible_ammo", "ammo_box", "crate", "trap"].has(str(c.get("kind", ""))):
		if not squad.can_claim(node, pid):
			_task_unavailable(kind)
			return
		squad.claim(node, pid)
	task = c.duplicate()
	task["hold"] = 0.0
	task["state"] = "running"
	task["action"] = kind
	var timeout: float = float((_cfg.get("shopping", {}) as Dictionary).get("errand_timeout_s", 20.0))
	if kind == "objective":
		timeout = float((_cfg.get("local_ai", {}) as Dictionary).get("errand_timeout_s", 60.0)) + float(c.get("extra_s", 0.0))
	if node is Crucible:
		timeout += (node as Crucible).forge_seconds + (node as Crucible).offer_seconds
	task["until"] = now + timeout


## A task action won the think but its errand can't start (taken, gone): the shopping inputs go quiet for a
## moment so the next think picks something it can do.
func _task_unavailable(kind: String) -> void:
	if kind == "buy" or kind == "repair" or kind == "crate" or kind == "resupply":
		_task_block_t = squad.time() + 1.5
		economy.invalidate()
	elif kind == "objective":
		_planner_c = {}
	_think_t = minf(_think_t, 0.05)


## The task ended: claims go, the planner and the order hear of it, the next think comes now.
func finish_task(ok: bool) -> void:
	var t: Dictionary = task
	drop_task()
	economy.invalidate()
	_think_t = 0.0
	match str(t.get("action", "")):
		"objective":
			var id: String = str(t.get("id", ""))
			if ok and id != "":
				objectives_done += 1
			if planner != null and id != "":
				planner.on_errand_finished(id, ok)
			_planner_c = {}
		"order":
			_order_done = true


func drop_task() -> void:
	if task.is_empty():
		return
	var node: Variant = task.get("node")
	if task.has("key"):
		squad.blackboard.release(str(task["key"]), player.player_id)
	elif node != null and is_instance_valid(node):
		squad.release(node as Node, player.player_id)
	task = {}


func crucible_sticky() -> bool:
	return not task.is_empty() and str(task.get("kind", "")) == "crucible" and bool(task.get("fed", false))


## The order's own errand: the door / power switch / buildable part the human pointed at ({} none).
func _order_task() -> Dictionary:
	var oid: StringName = order_id()
	var n: Node = order_node()
	if n == null or (oid != &"open_door" and oid != &"fetch_part"):
		return {}
	if n is BuyDoor:
		if (n as BuyDoor).is_open:
			_order_done = true
			return {}
		if Economy.get_scrip(player.player_id) < (n as BuyDoor).cost or squad.ordered_door_taken(n, player.player_id):
			return {}
		return {"node": n, "kind": "door", "label": "open the %s (ordered)" % door_label(n as BuyDoor)}
	if n is PowerSwitch:
		if GameState.power_on or not (n as PowerSwitch).can_interact(player):
			_order_done = true
			return {}
		return {"node": n, "kind": "power", "label": "throw the power switch (ordered)"}
	if n is Interactable:
		if not (n as Interactable).can_interact(player):
			_order_done = true
			return {}
		if squad.ordered_door_taken(n, player.player_id):
			return {}
		return {"node": n, "kind": "fetch", "label": "fetch the part (ordered)"}
	return {}


## The planner's directive as an errand ({} when it has none or it can't be started).
func _planner_ready() -> bool:
	if planner == null:
		return false
	var dv: Dictionary = planner.directive
	if dv.is_empty() or str(dv.get("kind", "")) == "follow":
		_planner_c = {}
		return false
	if not task.is_empty() and str(task.get("id", "")) == str(dv.get("id", "")):
		return true
	if not _planner_c.is_empty() and str(_planner_c.get("id", "")) == str(dv.get("id", "")):
		return true
	var node: Variant = dv.get("node")
	if node == null or not is_instance_valid(node):
		planner.on_errand_finished(str(dv.get("id", "")), false)
		return false
	_planner_c = dv.duplicate()
	return true


## Power-ups by etiquette (combat.json powerups): Resupply / Fortify when it's safe; the rest only with the human
## near it too (or no human); never one the human is walking toward.
func _powerup_value(now: float) -> float:
	var pc: Dictionary = BotAIData.combat("powerups")
	var bb: BotBlackboard = squad.blackboard
	bb.prune_powerups()
	_powerup_key = null
	_powerup_v = 0.0
	var h: Player = squad.human()
	var human_in: bool = h != null and is_instance_valid(h) and not h.spectating and not h.downed
	for k: Variant in bb.powerups.keys():
		var e: Dictionary = bb.powerups[k]
		var p: Vector3 = e["pos"]
		var id: String = str(e["id"])
		var always: bool = (pc.get("always_take", []) as Array).has(id)
		if human_in:
			var hv: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
			var to: Vector3 = Vector3(p.x - h.global_position.x, 0.0, p.z - h.global_position.z)
			if hv.length() > 1.0 and to.length() < float(pc.get("toward_m", 16.0)) and hv.angle_to(to) < deg_to_rad(float(pc.get("toward_cone_deg", 30.0))):
				continue   # the human is going for it
			if not always and to.length() > float(pc.get("shared_m", 9.0)):
				continue
		var d: float = _flat(p, player.global_position)
		if d > float(pc.get("max_path_m", 22.0)) or absf(p.y - player.global_position.y) > 2.5:
			continue
		var v: float = (0.85 if always else 0.6) * (1.0 - d / 40.0)
		if v > _powerup_v and reachable(p):
			_powerup_v = v
			_powerup_key = k
	return _powerup_v


func powerup_pos() -> Vector3:
	if _powerup_key == null or not squad.blackboard.powerups.has(_powerup_key):
		return Vector3.INF
	return (squad.blackboard.powerups[_powerup_key] as Dictionary)["pos"]


func powerup_done() -> void:
	if _powerup_key != null:
		squad.blackboard.powerups.erase(_powerup_key)
	_powerup_key = null


## A trap lever it may pull (never unless ordered, the planner, or the human used that trap) with a crowd at it.
func _trap_value() -> float:
	_trap_c = {}
	if _levers.is_empty():
		return 0.0
	for lv: Node in _levers:
		var lever: Interactable = lv as Interactable
		if lever == null or not is_instance_valid(lever) or not lever.can_interact(player):
			continue
		var trap: Node = lever.call("trap") if lever.has_method("trap") else null
		var tid: StringName = StringName(str(trap.get("trap_id"))) if trap != null and trap.get("trap_id") != null else &""
		var ordered: bool = order_node() == lever
		if not BotEconomy.may_touch("trap", ordered, planner != null, _human_used_traps.has(tid)):
			continue
		var at: Vector3 = (trap as Node3D).global_position if trap is Node3D else lever.global_position
		if perception.count_near(at, 6.0) < 5 and not ordered:
			continue
		if _flat(lever.global_position, player.global_position) > 15.0 or Economy.get_scrip(player.player_id) < int(lever.call("cost") if lever.has_method("cost") else 1000):
			continue
		_trap_c = {"node": lever, "kind": "trap", "label": "pull the trap lever"}
		return 0.8
	return 0.0


## The spot it holds: the Hold order's ring, or (early rounds, mid-round) a window pair it claims on the
## blackboard: {pos, facing} or {}.
func hold_spot() -> Dictionary:
	if order_id() == &"hold" and squad.hold_point != Vector3.INF:
		return {"pos": squad.hold_spot(self), "facing": Vector3.ZERO}
	var hc: Dictionary = BotAIData.combat("hold")
	if RoundManager.current_round > int(hc.get("until_round", 7)) or in_break() or roaming():
		release_hold_claim()
		return {}
	var now: float = squad.time()
	if now - _hold_t < 2.0 and (not _hold.is_empty() or _hold_key == "none"):
		return _hold
	_hold_t = now
	var leader: Player = squad.leader_for(self)
	var anc: Vector3 = leader.global_position if leader != null else player.global_position
	var bb: BotBlackboard = squad.blackboard
	var best: Barricade = null
	var best_s: float = -INF
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or _flat(b.global_position, anc) > float(hc.get("max_from_leader_m", 12.0)) or absf(b.global_position.y - anc.y) > 2.0:
			continue
		var key: String = "hold:%d" % b.get_instance_id()
		if not bb.can_claim(key, player.player_id, now) and key != _hold_key:
			continue
		var s: float = -_flat(b.global_position, player.global_position) * 0.2 - _flat(b.global_position, anc) * 0.3
		s += 4.0 * float(perception.count_near(b.global_position, 8.0))
		if bb.holders(key, now).size() == 1 and not bb.holds(key, player.player_id, now):
			s += 3.0   # make it a pair
		if key == _hold_key:
			s += 2.0
		if s > best_s:
			best_s = s
			best = b
	if best == null:
		release_hold_claim()
		_hold_key = "none"
		_hold = {}
		return {}
	var key2: String = "hold:%d" % best.get_instance_id()
	if key2 != _hold_key:
		release_hold_claim()
		bb.claim(key2, player.player_id, "hold", now, now + 20.0, best, int(hc.get("pair_size", 2)))
		_hold_key = key2
	else:
		bb.claim(key2, player.player_id, "hold", now, now + 20.0, best, int(hc.get("pair_size", 2)))
	var front: Vector3 = _front_of(best)
	var out_dir: Vector3 = front - best.global_position
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length() > 0.01 else Vector3.FORWARD
	var slot: int = bb.holders(key2, now).find(player.player_id)
	var side: Vector3 = Vector3(-out_dir.z, 0.0, out_dir.x) * float(hc.get("stand_spread_m", 1.4)) * (0.5 if slot <= 0 else -0.5)
	var p: Vector3 = Vector3.INF
	# never on the human's training line: further back into the room, or wider, else no hold here
	for back: float in [float(hc.get("stand_back_m", 2.2)), 3.4, 4.6, 1.4]:
		for wide: float in [1.0, 2.2, -1.0]:
			var c: Vector3 = snap(front + out_dir * back + side * wide)
			if not squad.on_human_line(c) and squad.choke_at(c).is_empty():
				p = c
				break
		if p != Vector3.INF:
			break
	if p == Vector3.INF:
		release_hold_claim()
		_hold_key = "none"
		_hold = {}
		return {}
	_hold = {"pos": p, "facing": -out_dir, "window": best}
	return _hold


func release_hold_claim() -> void:
	if _hold_key != "" and _hold_key != "none":
		squad.blackboard.release(_hold_key, player.player_id)
	_hold_key = ""
	_hold = {}


# ================================================================== downed / pose

## Last stand: lies where it fell and keeps the pistol working on what comes close and is in sight.
func _tick_downed(delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.velocity.y = -0.5 if player.is_on_floor() else player.velocity.y - 14.0 * delta
	player.move_and_slide()
	player._set_crouch_shape(true)
	player._eye = move_toward(player._eye, float((_pcfg.get("downed", {}) as Dictionary).get("eye_height", 0.45)), delta * 2.0)
	player.head.position.y = player._eye
	if actions.reviving():
		actions.stop_revive()
	if not task.is_empty():
		drop_task()
	squad.blackboard.release_all(player.player_id)
	if aim.target != null and perception.nearest_d < 14.0:
		var dir: Vector3 = (aim.aim_point(aim.target) - aim.eye()).normalized()
		_turn_body(dir, delta, 0.6)
		aim.update(delta, true)
	var w: WeaponInstance = aim.cur()
	if w != null and w.mag == 0 and w.reserve > 0 and not aim.reloading:
		aim.start_reload()


## Turns the body toward `dir` at the skill's rate (only while downed; standing, the locomotion layer turns it).
func _turn_body(dir: Vector3, delta: float, mult: float) -> void:
	var step: float = float(skill.get("turn_rate", 6.0)) * mult * delta
	var want_yaw: float = atan2(-dir.x, -dir.z)
	var want_pitch: float = asin(clampf(dir.y, -1.0, 1.0))
	player.rotation.y = wrapf(player.rotation.y + clampf(wrapf(want_yaw - player.rotation.y, -PI, PI), -step, step), -PI, PI)
	player.head.rotation.x = clampf(player.head.rotation.x + clampf(want_pitch - player.head.rotation.x, -step, step), deg_to_rad(-80.0), deg_to_rad(80.0))


## The body: the third-person pose follows the state flags (the locomotion layer sets the rotation).
func _pose(delta: float) -> void:
	var flags: int = 0
	if player.spectating:
		flags |= NetMatch.PF_SPECTATE
	elif player.downed:
		flags |= NetMatch.PF_DOWNED
	if player.sprinting:
		flags |= NetMatch.PF_SPRINT
	if player.crouching:
		flags |= NetMatch.PF_CROUCH
	if player.is_on_floor():
		flags |= NetMatch.PF_FLOOR
	if aim.reloading:
		flags |= NetMatch.PF_RELOAD
	player.net_flags = flags
	if player.remote_body != null:
		player.remote_body.calm = (action == "follow" or action == "idle" or action == "chatter") and aim.target == null and perception.nearest_d > 9.0 and player.horizontal_speed() < 0.3
		player.remote_body.update_pose(delta, player.horizontal_speed(), player.head.rotation.x, flags)


# ================================================================== the T-031 / planner API (kept)

## Every errand the shopping rules allow, scored on the old scale for the planner: [{node, kind, score, label}].
func errand_candidates(anchor: Vector3, range_mult: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in economy.candidates(anchor, range_mult):
		var o: Dictionary = c.duplicate()
		o["score"] = float(c.get("value", 0.0)) * 80.0
		out.append(o)
	return out


## A powered, idle Crucible within `range_m` of `anchor` that this bot may claim and reach, or null.
func crucible_for_me(range_m: float, anchor: Vector3) -> Crucible:
	for cn: Node in get_tree().get_nodes_in_group(&"crucible"):
		var cr: Crucible = cn as Crucible
		if cr == null or not cr.is_powered() or cr.phase != Crucible.Phase.IDLE or _flat(cr.global_position, anchor) > range_m:
			continue
		if not squad.can_claim(cr, player.player_id) or not _reachable(_front_of(cr)):
			continue
		return cr
	return null


## The slot a new gun may replace: the lowest-tier non-upgraded gun, or -1 when every slot holds an upgraded gun.
func _slot_to_give_up() -> int:
	var eco: Dictionary = BotAIData.table("economy")
	var worst: int = -1
	var worst_t: float = INF
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if w.upgraded:
			continue
		var t: float = BotEconomy.tier_of(String(w.base_id()), false, eco)
		if t < worst_t:
			worst_t = t
			worst = i
	return worst


## The slot holding a gun the Crucible can upgrade: a wall gun before the start pistol, the one in hand first.
func _upgradeable_slot() -> int:
	var best: int = -1
	var best_s: int = -1
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if Crucible.action_for(w) != &"upgrade":
			continue
		var s: int = (0 if w.weapon_class() == &"pistol" else 2) + (1 if i == player.weapons.current_index else 0)
		if s > best_s:
			best_s = s
			best = i
	return best


## A crate gun worth taking: a free slot, a wonder weapon, or a higher tier than the worst held non-upgraded gun.
func wants_crate_weapon(wid: StringName) -> bool:
	if not (GLData.table("weapons")["weapons"] as Dictionary).has(String(wid)):
		return false   # a tactical: leave it
	if player.weapons.slots.size() < player.weapons.max_slots():
		return true
	var eco: Dictionary = BotAIData.table("economy")
	var give: int = _slot_to_give_up()
	if give < 0:
		return false
	return BotEconomy.tier_of(String(wid), false, eco) > BotEconomy.tier_of(String(player.weapons.slots[give].base_id()), false, eco) + 0.3


## The slot the current errand needs in hand: its `weapon`, any upgraded gun for `need_upgraded`, the Crucible
## ammo's gun; -1.
func forced_slot() -> int:
	if str(task.get("kind", "")) == "crucible_ammo":
		var cs: int = int(task.get("slot", -1))
		return cs if cs >= 0 and cs < player.weapons.slots.size() else -1
	var src: Dictionary = task if not task.is_empty() and task.has("id") else {}
	if src.is_empty():
		return -1
	var want: String = str(src.get("weapon", ""))
	var need_up: bool = bool(src.get("need_upgraded", false))
	if want == "" and not need_up:
		return -1
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if want != "" and String(w.base_id()) == want:
			return i
		if need_up and w.upgraded:
			return i
	return -1


static func weapon_name(wid: StringName) -> String:
	var row: Dictionary = (GLData.table("weapons")["weapons"] as Dictionary).get(String(wid), {})
	return str(row.get("name", wid))


## A door's name for people: its id without the "door_" prefix ("the stable door").
static func door_label(d: BuyDoor) -> String:
	return "%s door" % String(d.door_id).trim_prefix("door_").replace("_", " ")


## Where to stand to open a door: 1.1 m out from its plane on our side.
static func _door_side(door: BuyDoor, me: Vector3) -> Vector3:
	var side: Vector3 = door.global_basis.z
	side.y = 0.0
	if side.dot(me - door.global_position) < 0.0:
		side = -side
	return door.global_position + side.normalized() * 1.1


## Where to stand to use something: 1 m out from its use box on the side the box sticks out.
static func _front_of(node: Interactable) -> Vector3:
	var off: Vector3 = node.global_basis * node.interact_offset
	off.y = 0.0
	if off.length() < 0.05:
		return node.global_position
	var p: Vector3 = node.global_position + off + off.normalized() * 1.0
	p.y = node.global_position.y
	return p


func _reachable(p: Vector3) -> bool:
	var dest: Vector3 = snap(p)
	if dest.distance_to(p) > 2.0:
		return false
	var path: PackedVector3Array = open_path(player.global_position, dest)
	return not path.is_empty() and path[path.size() - 1].distance_to(dest) < 1.5


func reachable(p: Vector3) -> bool:
	return _reachable(p)


func flat_distance(p: Vector3) -> float:
	return _flat(p, player.global_position)


func los_point(from: Vector3, to: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, BotPerception.MASK_LOS, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, p)


func _snap(p: Vector3) -> Vector3:
	return snap(p)


## A nav path that doesn't cross a closed BuyDoor (doors aren't baked into the navmesh).
func open_path(from: Vector3, dest: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, from, dest, true, squad.nav_mask())
	for d: BuyDoor in _doors:
		if is_instance_valid(d) and not d.is_open and ZombieDirector.door_crossed(d, path):
			return PackedVector3Array()
	return path


## Where to stand to use `node`: its use box's front, its own spot, or a ring around it, on the navmesh and
## reachable; Vector3.INF when there is none. Cached for a few seconds.
func stand_point(node: Node3D) -> Vector3:
	var key: int = node.get_instance_id()
	var c: Variant = _stand_cache.get(key)
	if c is Array and squad.time() - float((c as Array)[0]) < 4.0:
		return (c as Array)[1]
	var base: Vector3 = node.global_position
	var cands: Array[Vector3] = []
	if node is Interactable:
		cands.append(_front_of(node as Interactable))
	cands.append(base)
	for r: float in [0.9, 1.5]:
		for k: int in 8:
			var a: float = float(k) / 8.0 * TAU
			cands.append(base + Vector3(cos(a) * r, 0.0, sin(a) * r))
	var out: Vector3 = Vector3.INF
	for cand: Vector3 in cands:
		for dy: float in [0.0, -1.5, -3.0]:
			var s: Vector3 = snap(cand + Vector3(0.0, dy, 0.0))
			if _flat(s, base) < 1.8 and base.y - s.y < 3.2 and s.y - base.y < 1.2 and _reachable(s):
				out = s
				break
		if out != Vector3.INF:
			break
	_stand_cache[key] = [squad.time(), out]
	return out


## A reachable navmesh spot that sees `target` (a bell overhead), nearest rings first; INF when none within 12 m.
func vantage_for(target_p: Vector3) -> Vector3:
	var eye_h: float = float(BotAIData.combat("perception").get("eye_height", 1.55))
	for r: float in [2.5, 4.5, 7.0, 10.0, 12.0]:
		for k: int in 12:
			var a: float = float(k) / 12.0 * TAU
			for dy: float in [-1.5, -4.0, -7.0, -11.0]:
				var want: Vector3 = target_p + Vector3(cos(a) * r, dy, sin(a) * r)
				var s: Vector3 = snap(want)
				if s.distance_to(want) > 1.6 or s.y > target_p.y:
					continue
				if not los_point(s + Vector3.UP * eye_h, target_p):
					continue
				if _reachable(s):
					return s
	return Vector3.INF


## One line for the squad report / the debug overlay.
func status_line() -> String:
	var w: WeaponInstance = aim.cur() if aim != null else null
	var tops: PackedStringArray = []
	for t: Variant in top3:
		tops.append("%s %.2f" % [str((t as Array)[0]), float((t as Array)[1])])
	return "%s [%s] %s | %s | gun %s %d/%d | hp %.0f threat %.2f known %d near %.1f" % [Net.display_name(player.player_id), role if role != "" else "-", action,
		", ".join(tops), str(w.id) if w != null else "-", w.mag if w != null else 0, w.reserve if w != null else 0, player.hp,
		perception.pressure if perception != null else 0.0, perception.known.size() if perception != null else 0, minf(perception.nearest_d, 99.0) if perception != null else 99.0]


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
