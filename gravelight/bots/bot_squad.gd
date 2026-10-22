class_name BotSquad
extends Node
## The AI teammates of a match (T-031), a child of the MapRoot in a solo match that asked for bots. Builds a
## BotBrain for every bot Player, and holds what the brains share: who leads, who revives whom, the kill-share
## ledger (BotConfig.human_share_ok), errand claims (one bot per window or machine), per-player kill counts
## for the HUD, and the squad's voice (survivor VO lines as callouts, one at a time).

var map: MapRoot
var brains: Array[BotBrain] = []
var kills: Dictionary = {}          # pid -> kills (humans too, for the ledger)
var recent_kills: Array = []        # killer pids, newest last (kill share)
var _cfg: Dictionary = {}
var _claims: Dictionary = {}        # node instance id -> pid
var _revivers: Dictionary = {}      # downed pid -> bot pid
var _callout_t: float = 0.0
var _t: float = 0.0
var _round_t: float = 0.0
var _wall_buys: Array[WallBuy] = []


func setup(map_root: MapRoot) -> void:
	map = map_root
	_cfg = BotConfig.cfg()
	add_to_group(&"bot_squad")
	var i: int = 0
	for pid: int in GameState.bot_ids:
		var p: Player = map.players.get(pid) as Player
		if p == null:
			continue
		var b: BotBrain = BotBrain.new()
		b.name = "Brain"
		p.add_child(b)
		b.setup(p, self, i)
		brains.append(b)
		apply_kit(p, true)
		i += 1
	_start_planner()
	for n: Node in map.find_children("*", "WallBuy", true, false):
		_wall_buys.append(n as WallBuy)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	# DOWN / TEAM_DOWN / REVIVED / boss / door / buy / perk lines for bots come from VOManager (T-035), which
	# handles every survivor's signal-driven categories in that survivor's voice at their body.
	GLBus.round_started.connect(_on_round_started)


## The spawn kit (bots.json spawn_kit): the kit guns (when `weapons`: at the start and on a respawn) with the
## `hold` gun in hand, and the kit perks (Ironhide Stout, Second Wind Schnapps), free. A full loadout (a campaign
## arrival) is never overwritten. Called at the start, and by the brain when its bot gets up again.
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


## The objective planner (bots.json local_ai) on one bot, when the menu turned it on.
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


func planner() -> BotPlanner:
	for b: BotBrain in brains:
		if b.planner != null:
			return b.planner
	return null


func _process(delta: float) -> void:
	_t += delta
	_round_t += delta
	_callout_t = maxf(0.0, _callout_t - delta)


func time() -> float:
	return _t


## Seconds since the current round started (door purchases wait shopping.doors.round_delay_s).
func round_time() -> float:
	return _round_t


func director() -> ZombieDirector:
	return map.director


func nav_mask() -> int:
	return map.director.nav_mask if map.director != null else 0x7FFFFFFF


func human() -> Player:
	return map.player


func wall_buys() -> Array[WallBuy]:
	return _wall_buys


func player_by_id(pid: int) -> Player:
	return map.players.get(pid) as Player


func all_players() -> Array[Player]:
	var out: Array[Player] = []
	for pid: Variant in map.players.keys():
		out.append(map.players[pid] as Player)
	return out


## Everyone on their feet (not downed, not spectating).
func standing() -> Array[Player]:
	var out: Array[Player] = []
	for p: Player in all_players():
		if p.is_alive() and not p.spectating:
			out.append(p)
	return out


## Whom a bot follows: the human while they are in the match (standing or crawling), otherwise the first
## standing bot (which then holds its ground: its leader is itself).
func leader_for(bot: BotBrain) -> Player:
	var h: Player = human()
	if h != null and not h.spectating:
		return h
	for b: BotBrain in brains:
		if b.player.is_alive() and not b.player.spectating:
			return b.player
	return bot.player


## Kill share (bots.json combat.kill_share): false when the human has had too few of the recent kills.
func kill_share_ok() -> bool:
	return BotConfig.human_share_ok(recent_kills, GameState.human_ids(), (_cfg.get("combat", {}) as Dictionary).get("kill_share", {}))


## The downed player this bot should revive, if it is the one for the job: the human first, then bots, each
## with the nearest standing bot that isn't already busy with someone else.
func revive_target_for(bot: BotBrain) -> Player:
	var s: NetMatch = Net.session
	if s == null:
		return null
	var downed: Array[Player] = []
	var h: Player = human()
	if h != null and s.coop.is_downed(h.player_id):
		downed.append(h)
	for b: BotBrain in brains:
		if s.coop.is_downed(b.player.player_id):
			downed.append(b.player)
	for pid: Variant in _revivers.keys():
		var r: Player = player_by_id(int(_revivers[pid]))
		if not s.coop.is_downed(int(pid)) or r == null or not r.is_alive() or r.spectating:
			_revivers.erase(pid)
	for t: Player in downed:
		var pid2: int = t.player_id
		if _revivers.has(pid2):
			if int(_revivers[pid2]) == bot.player.player_id:
				return t
			continue
		var best: BotBrain = null
		var best_d: float = INF
		for b2: BotBrain in brains:
			if not b2.player.is_alive() or b2.player.spectating or b2.player == t:
				continue
			if _revivers.values().has(b2.player.player_id):
				continue
			var d: float = b2.player.global_position.distance_to(t.global_position)
			if d < best_d:
				best_d = d
				best = b2
		if best != null:
			_revivers[pid2] = best.player.player_id
			if best == bot:
				return t
	return null


func can_claim(node: Node, pid: int) -> bool:
	var id: int = node.get_instance_id()
	return not _claims.has(id) or int(_claims[id]) == pid


func claim(node: Node, pid: int) -> void:
	_claims[node.get_instance_id()] = pid


func release(node: Node, pid: int) -> void:
	var id: int = node.get_instance_id()
	if _claims.has(id) and int(_claims[id]) == pid:
		_claims.erase(id)


## A survivor line from this bot's character (VO + subtitles), rolled against bots.json callouts.chance and
## rate-limited for the whole squad so they don't talk over each other.
func callout(bot: BotBrain, category: String) -> void:
	var cc: Dictionary = _cfg.get("callouts", {})
	if _callout_t > 0.0:
		return
	var chance: float = float((cc.get("chance", {}) as Dictionary).get(category, 0.0))
	if chance <= 0.0 or randf() > chance:
		return
	var spk: StringName = GLVO.CHARACTER_SPEAKERS.get(bot.player.character_id, &"DUT")
	if GLVO.play_category(spk, category, 1.0, bot.player.player_id):   # positional, at the bot's body
		_callout_t = float(cc.get("cooldown_s", 7.0))


func _brain_of(pid: int) -> BotBrain:
	for b: BotBrain in brains:
		if b.player.player_id == pid:
			return b
	return null


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


func _on_round_started(_round: int, _special: bool) -> void:
	_round_t = 0.0
	_claims.clear()
	for b: BotBrain in brains:
		b.on_round_started()


## Dev / tests: one line per bot.
func report() -> PackedStringArray:
	var out: PackedStringArray = []
	for b: BotBrain in brains:
		var w: WeaponInstance = b.player.weapons.current()
		out.append("%s (P%d, %s): kills %d shots %d hp %.0f scrip %d %s %s%s teleports %d doors %d upgrades %d" % [Net.display_name(b.player.player_id), b.player.player_id,
			b.skill_name(), b.kills, b.shots, b.player.hp, Economy.get_scrip(b.player.player_id), str(w.id) if w != null else "-",
			BotBrain.Mode.keys()[b.mode], " DOWN" if b.player.downed else "", b.teleports, b.doors_bought_total, b.upgrades])
		if b.planner != null:
			out.append("  " + b.planner.status_line())


	return out
