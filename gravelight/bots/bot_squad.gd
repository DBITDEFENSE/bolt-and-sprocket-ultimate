class_name BotSquad
extends Node
## The AI teammates of a match (T-031), a child of the MapRoot in a solo match that asked for bots. Builds a
## BotBrain for every bot Player, and holds what the brains share: who leads, who revives whom, the kill-share
## ledger (BotConfig.human_share_ok), errand claims (one bot per window or machine), per-player kill counts
## for the HUD, and the squad's voice (survivor VO lines as callouts, one at a time).
##
## Update 02 section 5 (T-050): each bot's random bonus perk (bots.json bonus_perk, PerkManager.grant_bonus), the
## squad orders from the command wheel (`command`: follow / hold / repair / revive, applied to every brain), the
## choke points bots must not park in (open doors, stairs; `chokes`), the nameplates (BotPlates) and the wheel
## (BotCommandWheel). Companions (Jakub, U02 section 6) join through add_brain(player, options) with their own
## BotBrain options (no perks, own bleed-out) and get the same orders.

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
## The current squad order (BotConfig.COMMANDS) and, for "hold", the spot.
var command: StringName = &"follow"
var hold_point: Vector3 = Vector3.INF
## Choke points (world AABBs): open doorways and staircases. [{"box": AABB, "kind": "door"/"stair", "node"}]
var chokes: Array[Dictionary] = []
## Soak instrumentation: every time a bot stayed inside a choke longer than follow.choke_report_s.
var choke_events: PackedStringArray = []
## The human's smoothed flat velocity (training detection for the moving formation).
var leader_vel: Vector3 = Vector3.ZERO
var plates: BotPlates = null
var wheel: BotCommandWheel = null
var _bot_cd: Dictionary = {}      # "pid:FAMILY" -> time a bark may come again


func setup(map_root: MapRoot) -> void:
	map = map_root
	_cfg = BotConfig.cfg()
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
	_build_chokes()
	for n: Node in map.find_children("*", "WallBuy", true, false):
		_wall_buys.append(n as WallBuy)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	# DOWN / TEAM_DOWN / REVIVED / boss / door / buy / perk lines for bots come from VOManager (T-035), which
	# handles every survivor's signal-driven categories in that survivor's voice at their body.
	GLBus.round_started.connect(_on_round_started)
	GLBus.powerup_spawned.connect(_on_powerup_spawned)
	if not brains.is_empty():
		plates = BotPlates.new()
		plates.name = "BotPlates"
		add_child(plates)
		plates.setup(self)
		wheel = BotCommandWheel.new()
		wheel.name = "BotCommandWheel"
		add_child(wheel)
		wheel.setup(self)


## A brain for `p` (a bot Player, or later a companion): `options` override BotBrain.options (perks,
## bonus_perk, shopping, kit, accuracy_mult; see there). `i` = formation index (-1 = next).
func add_brain(p: Player, options: Dictionary = {}, i: int = -1) -> BotBrain:
	var b: BotBrain = BotBrain.new()
	b.name = "Brain"
	b.options.merge(options, true)
	p.add_child(b)
	b.setup(p, self, brains.size() if i < 0 else i)
	brains.append(b)
	if bool(b.options.get("kit", true)):
		apply_kit(p, true)
	return b


## Bonus perks (bots.json bonus_perk, the "Bot Bonus Perk" setting): one random perk per bot from the perks
## this map's machines sell, outside the cap, never a kit perk, no two the same. Brains that don't drink perks
## (a companion's options.perks = false) get none.
func _assign_bonus_perks() -> void:
	var bcfg: Dictionary = _cfg.get("bonus_perk", {})
	if not BotConfig.bonus_enabled(GLSettings.values, bcfg) or not Net.is_authority():
		return
	var takers: Array[BotBrain] = []
	for b: BotBrain in brains:
		if bool(b.options.get("perks", true)) and bool(b.options.get("bonus_perk", true)):
			takers.append(b)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var kit: Array = (_cfg.get("spawn_kit", {}) as Dictionary).get("perks", [])
	var picks: Array[StringName] = BotConfig.pick_bonus_perks(bcfg, map_perk_ids(), kit, takers.size(), rng)
	for k: int in takers.size():
		if picks[k] != &"":
			PerkManager.grant_bonus(takers[k].player.player_id, picks[k])
			takers[k].bonus_perk = picks[k]


## The perks this map sells (its perk machines).
func map_perk_ids() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		if pm != null and not out.has(String(pm.perk_id)):
			out.append(String(pm.perk_id))
	return out


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
	var h: Player = human()
	if h != null and is_instance_valid(h):
		var v: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
		leader_vel = leader_vel.lerp(v, clampf(delta * 4.0, 0.0, 1.0))


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


## A survivor line from this bot's character (VO + subtitles), rolled against bots.json callouts.chance (by
## category, else its family: CMD_HOLD -> CMD) and rate-limited: one squad line at a time (cooldown_s) and a
## per-bot gap per family (per_bot_cooldown_s). force_categories (orders, the bonus perk, downs) skip the squad
## gap and the roll. Returns true when the line started or was queued.
func callout(bot: BotBrain, category: String, force: bool = false) -> bool:
	var cc: Dictionary = _cfg.get("callouts", {})
	var fam: String = category.get_slice("_", 0) if (category.begins_with("CMD_") or category.begins_with("BONUS_")) else category
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
	var spk: StringName = GLVO.CHARACTER_SPEAKERS.get(bot.player.character_id, &"DUT")
	if GLVO.play_category(spk, category, 1.0, bot.player.player_id):   # positional, at the bot's body
		_callout_t = float(cc.get("cooldown_s", 7.0))
		_bot_cd[key] = _t + float((cc.get("per_bot_cooldown_s", {}) as Dictionary).get(fam, 0.0))
		return true
	return false


## A squad order from the wheel (or the dev console / tests): every brain follows it; the nearest bot
## acknowledges it. "hold" holds `at` (the spot the human points at; the human's feet when INF).
func set_command(cmd: StringName, at: Vector3 = Vector3.INF) -> void:
	if not BotConfig.COMMANDS.has(cmd):
		return
	command = cmd
	hold_point = Vector3.INF
	var h: Player = human()
	if cmd == &"hold":
		hold_point = at if at != Vector3.INF else (h.global_position if h != null else Vector3.INF)
	for b: BotBrain in brains:
		b.on_command(cmd)
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner("Squad: %s" % command_label(cmd), 1.4)
	var speaker: BotBrain = _nearest_standing_brain(h.global_position if h != null else Vector3.ZERO)
	if speaker != null:
		callout(speaker, "CMD_" + String(cmd).to_upper(), true)


static func command_label(cmd: StringName) -> String:
	match cmd:
		&"hold": return "Hold here"
		&"repair": return "Repair barricades"
		&"revive": return "Revive priority"
	return "Follow me"


## Where a holding bot stands: a ring of commands.ring_radius_m around the hold point, by formation index.
func hold_spot(bot: BotBrain) -> Vector3:
	if hold_point == Vector3.INF:
		return Vector3.INF
	var r: float = float((_cfg.get("commands", {}) as Dictionary).get("ring_radius_m", 1.6))
	var a: float = TAU * float(bot.index) / float(maxi(1, brains.size())) + 0.4
	return hold_point + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _nearest_standing_brain(p: Vector3) -> BotBrain:
	var best: BotBrain = null
	var best_d: float = INF
	for b: BotBrain in brains:
		if not b.player.is_alive() or b.player.spectating:
			continue
		var d: float = b.player.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = b
	return best


## Choke points the bots must not park in: every buy door's doorway (both sides) and every staircase / ramp slab
## of the map (StaticBody3D named *Stair* / *Ramp* / *Flight* / *Gangway* with a box shape).
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
			box.size.y += 2.0   # the walking space above the slab
			chokes.append({"box": box, "kind": "stair", "node": n2})


## The world AABB of a box (`half` extents) placed at `xf`.
static func box_aabb(xf: Transform3D, half: Vector3) -> AABB:
	var box: AABB = AABB(xf.origin, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				box = box.expand(xf * Vector3(half.x * sx, half.y * sy, half.z * sz))
	return box


## The choke a point is in ({} for none). Closed doors don't count (nobody stands in them).
func choke_at(p: Vector3) -> Dictionary:
	var q: Vector3 = p + Vector3.UP * 0.3
	for c: Dictionary in chokes:
		if not (c["box"] as AABB).has_point(q):
			continue
		if str(c["kind"]) == "door" and is_instance_valid(c["node"]) and not (c["node"] as BuyDoor).is_open:
			continue
		return c
	return {}


## Soak instrumentation (BotBrain): a bot stayed in a choke longer than follow.choke_report_s.
func report_choke(bot: BotBrain, kind: String, pos: Vector3, seconds: float) -> void:
	choke_events.append("%s in a %s at (%.1f, %.1f, %.1f) for %.1fs (mode %s, round %d)" % [Net.display_name(bot.player.player_id), kind,
		pos.x, pos.y, pos.z, seconds, BotBrain.Mode.keys()[bot.mode], RoundManager.current_round])


## A power-up dropped: the nearest standing bot that sees it calls it out.
func _on_powerup_spawned(_id: StringName, pos: Vector3) -> void:
	var b: BotBrain = _nearest_standing_brain(pos)
	if b != null and b.player.global_position.distance_to(pos) < 22.0 and b.los_point(b.player.head.global_position, pos + Vector3.UP * 0.5):
		callout(b, "POWERUP_SEEN")


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
		if b.bonus_perk != &"":
			out.append("  bonus perk %s (announced %s)" % [b.bonus_perk, str(b.bonus_said)])
	out.append("squad: order %s, revives by bots %d, choke reports %d" % [command, revives_total(), choke_events.size()])
	for e: String in choke_events.slice(0, 8):
		out.append("  CHOKE " + e)
	return out


func revives_total() -> int:
	var n: int = 0
	for b: BotBrain in brains:
		n += b.revives
	return n
