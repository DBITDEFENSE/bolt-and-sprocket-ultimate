class_name BotMetrics
extends Node
## The bot metrics logger (Update 03 sections 0 and 9). A plain node a test harness (tools_src/ai_soak.gd) adds
## next to a running match; nothing in the game creates one, and no autoload is needed. It watches the match from
## outside: GLBus signals (kills, downs, revives, purchases, rounds, game over), the co-op state (who is reviving
## whom, who bled out) and the Players themselves (positions, speed, magazines), so it measures any bot brain the
## same way. Three things can't be seen from outside and are reported by the brain through the static hook
## `BotMetrics.note(pid, kind, value)`, a no-op when no logger is running:
##   &"stuck_time"  (value = seconds) the bot wants to move and isn't getting anywhere, every frame it happens
##   &"stuck"       a stuck recovery fired (a repath, a hop, giving up on a goal)
##   &"teleport"    the bot was teleported (every teleport is a bug to fix)
## and, for the command wheel when it arrives: `BotMetrics.command_issued(bot_pid, cmd)` when the player gives an
## order and `BotMetrics.command_done(bot_pid, cmd)` when the bot starts acting on it (the response time).
## The rules (what counts as blocking, a revive success, wasted Scrip) are the static functions below, unit-tested
## in gravelight/tests/unit/test_bot_metrics.gd; docs/BOT_AI.md explains each metric.

## A bot inside this flat radius of a human who is moving faster than BLOCK_MOVING_MPS is in the way.
const PERSONAL_SPACE_M: float = 1.2
const BLOCK_MOVING_MPS: float = 1.0
## Each full BLOCK_CHUNK_S of continuous blocking is one blocking event; an episode longer than
## BLOCK_SUSTAINED_S is also one sustained blocking event.
const BLOCK_CHUNK_S: float = 0.5
const BLOCK_SUSTAINED_S: float = 2.0
## The stuck seconds one frame adds: `dt` of a stretch now `run` long; the first STUCK_MIN_S are credited at once
## when the stretch passes it, nothing before.
static func stuck_credit(run: float, dt: float) -> float:
	if run <= STUCK_MIN_S:
		return 0.0
	if run - dt <= STUCK_MIN_S:
		return run
	return dt


## An empty-mag moment: the gun in the bot's hands has nothing in the magazine while a zombie is this close.
const EMPTY_MAG_RADIUS_M: float = 6.0
## Wasted Scrip: these guns bought after LATE_ROUND, a wall gun no longer carried within DROP_WINDOW_ROUNDS
## rounds of buying it, or a wall gun worse (gun_quality) than the best gun already carried.
const LATE_WEAK_GUNS: PackedStringArray = ["kar98k"]
const LATE_ROUND: int = 10
const DROP_WINDOW_ROUNDS: int = 2
## A down still unresolved when the match ends counts as a failed revive once it is this old (younger ones were
## the wipe itself: nobody was left standing to try).
const PENDING_FAIL_S: float = 10.0
## "Lost": a standing bot this far (flat) from a standing human for longer than LOST_AFTER_S.
const LOST_DIST_M: float = 14.0
const LOST_AFTER_S: float = 4.0
## Stuck time counts unbroken stretches of "wants to move, isn't moving" longer than this (all of it, once past).
const STUCK_MIN_S: float = 0.5
## A stuck stretch this long is also logged as an event with the bot's position.
const STUCK_LOG_S: float = 1.5

static var _active: BotMetrics = null

var scenario: String = ""
var run_id: String = ""
var run_seed: int = 0
var map: MapRoot
var t: float = 0.0
var finished: bool = false
var end_reason: String = ""
var round_reached: int = 0

var stats: Dictionary = {}          # pid -> per-player totals (see _blank)
var rounds: Dictionary = {}         # round -> {t0, t1, downs: {pid: n}, kills: {pid: n}}
var events: Array = []              # [t, round, pid, kind, value, detail]
var episodes: Array = []            # revive episodes (see revive_summary)
var gun_buys: Array = []            # {pid, item, round, cost, held_before, dropped_round, lost}
var _open_ep: Dictionary = {}       # downed pid -> index into episodes
var _reviver: Dictionary = {}       # downed pid -> the pid holding use on them last frame
var _block: Dictionary = {}         # "bot:human" -> blocking state (block_step)
var _empty: Dictionary = {}         # pid -> true while in an empty-mag moment
var _lost_t: Dictionary = {}        # pid -> seconds far from the human
var _held: Dictionary = {}          # pid -> base ids carried last frame
var _cmd: Dictionary = {}           # bot pid -> [command, time issued]
var _wtable: Dictionary = {}
var _stuck_run: Dictionary = {}     # pid -> seconds of the current unbroken stuck stretch
var _stuck_frame: Dictionary = {}   # pid -> physics frame of the last stuck_time note
## Anything the harness wants in the run's summary (a scenario's own outcome, e.g. the Cousins round's).
var extra: Dictionary = {}


## Starts logging the match on `map_root`. One logger at a time (the static hook goes to the newest).
func setup(map_root: MapRoot, scenario_name: String, id: String, seed_value: int) -> void:
	map = map_root
	scenario = scenario_name
	run_id = id
	run_seed = seed_value
	_active = self
	_wtable = GLData.table("weapons")
	for pid: int in GameState.player_ids:
		stats[pid] = _blank(pid)
	GLBus.enemy_killed.connect(_on_killed)
	GLBus.player_downed.connect(_on_downed)
	GLBus.player_revived.connect(_on_revived)
	GLBus.purchase_made.connect(_on_purchase)
	GLBus.round_started.connect(_on_round_started)
	GLBus.game_over.connect(_on_game_over)
	PerkManager.perk_tier_changed.connect(_on_perk_tier)
	GLBus.quest_step_completed.connect(_on_step_done)
	GLBus.quest_step_failed.connect(_on_step_failed)
	_on_round_started(maxi(1, RoundManager.current_round), false)


func _exit_tree() -> void:
	if _active == self:
		_active = null
	for pair: Array in [[GLBus.enemy_killed, _on_killed], [GLBus.player_downed, _on_downed], [GLBus.player_revived, _on_revived],
			[GLBus.purchase_made, _on_purchase], [GLBus.round_started, _on_round_started], [GLBus.game_over, _on_game_over],
			[PerkManager.perk_tier_changed, _on_perk_tier], [GLBus.quest_step_completed, _on_step_done], [GLBus.quest_step_failed, _on_step_failed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


# ================================================================== the hooks (static)

## The brain's report of something the logger can't see from outside (see the class doc). No-op without a logger.
static func note(pid: int, kind: StringName, value: float = 1.0, detail: String = "") -> void:
	if _active != null and is_instance_valid(_active):
		_active._note(pid, kind, value, detail)


## Command wheel: the player gave `bot_pid` an order.
static func command_issued(bot_pid: int, command: StringName) -> void:
	if _active != null and is_instance_valid(_active):
		_active._cmd[bot_pid] = [command, _active.t]


## Command wheel: `bot_pid` started acting on its order (the response time is measured from command_issued).
static func command_done(bot_pid: int, command: StringName) -> void:
	if _active != null and is_instance_valid(_active):
		_active._command_done(bot_pid, command)


func _note(pid: int, kind: StringName, value: float, detail: String) -> void:
	var s: Dictionary = _stat(pid)
	match kind:
		&"stuck_time":
			# only continuous stretches count, past STUCK_MIN_S (a bot starting to walk, or nudged by a teammate,
			# moves less than a stuck check's step for a frame or two)
			var f: int = Engine.get_physics_frames()
			var run: float = (float(_stuck_run.get(pid, 0.0)) if int(_stuck_frame.get(pid, -10)) >= f - 1 else 0.0) + value
			_stuck_frame[pid] = f
			_stuck_run[pid] = run
			s["stuck_time"] = float(s["stuck_time"]) + stuck_credit(run, value)
			if run >= STUCK_LOG_S and run - value < STUCK_LOG_S:
				_event(pid, "stuck_stretch", run, _pos_of(pid))   # where the long stalls happen
		&"stuck":
			s["stuck_events"] = int(s["stuck_events"]) + 1
			_event(pid, "stuck", 1.0, detail if detail != "" else _pos_of(pid))
		&"teleport":
			s["teleports"] = int(s["teleports"]) + 1
			_event(pid, "teleport", 1.0, detail if detail != "" else _pos_of(pid))
		_:
			s[String(kind)] = float(s.get(String(kind), 0.0)) + value
			_event(pid, String(kind), value, detail)


func _command_done(bot_pid: int, command: StringName) -> void:
	var c: Variant = _cmd.get(bot_pid)
	if not (c is Array) or StringName((c as Array)[0]) != command:
		return
	var dt: float = t - float((c as Array)[1])
	_cmd.erase(bot_pid)
	var s: Dictionary = _stat(bot_pid)
	s["commands"] = int(s["commands"]) + 1
	s["command_time"] = float(s["command_time"]) + dt
	_event(bot_pid, "command", dt, String(command))


# ================================================================== pure rules (unit-tested)

## Is a bot at `bot_pos` in the way of a human at `human_pos` moving at `human_speed` (flat m/s)?
static func blocking(bot_pos: Vector3, human_pos: Vector3, human_speed: float) -> bool:
	if human_speed <= BLOCK_MOVING_MPS or absf(bot_pos.y - human_pos.y) > 1.5:
		return false
	return Vector2(bot_pos.x - human_pos.x, bot_pos.z - human_pos.z).length() < PERSONAL_SPACE_M


## One frame of a bot/human pair's blocking state `st` ({} to start): `cond` = blocking() this frame. Returns
## Vector2i(new blocking events, new sustained events): one event per full BLOCK_CHUNK_S of an unbroken
## episode, one sustained event when the episode passes BLOCK_SUSTAINED_S. A break ends the episode.
static func block_step(st: Dictionary, cond: bool, dt: float) -> Vector2i:
	if not cond:
		st["t"] = 0.0
		st["chunks"] = 0
		st["sus"] = false
		return Vector2i.ZERO
	st["t"] = float(st.get("t", 0.0)) + dt
	var chunks: int = int(floor(float(st["t"]) / BLOCK_CHUNK_S + 0.0001))
	var ev: int = chunks - int(st.get("chunks", 0))
	st["chunks"] = chunks
	var sus: int = 0
	if float(st["t"]) > BLOCK_SUSTAINED_S and not bool(st.get("sus", false)):
		st["sus"] = true
		sus = 1
	return Vector2i(ev, sus)


## An empty-mag moment: nothing in the magazine of the gun in hand with a zombie within EMPTY_MAG_RADIUS_M.
static func empty_mag_moment(mag: int, nearest_zombie_m: float) -> bool:
	return mag <= 0 and nearest_zombie_m < EMPTY_MAG_RADIUS_M


## A bot holding a pistol (`held_class`) while it carries another gun with `other_ammo` rounds (mag + reserve):
## the pistol-time metric.
static func pistol_while_armed(held_class: StringName, other_ammo: int) -> bool:
	return held_class == &"pistol" and other_ammo > 0


func _other_guns_ammo(b: Player, held: WeaponInstance) -> int:
	var n: int = 0
	for wi: WeaponInstance in b.weapons.slots:
		if wi != held and wi.weapon_class() != &"pistol":
			n += wi.mag + wi.reserve
	return n


## The revive numbers from a list of down episodes {pid, t_down, outcome ("revived" / "bled" / "pending"),
## t_end, attempts, attempts_ok, reach_s}, the match ending at `end_t`. A revive success is a down that ended in a
## revive; failures are bleed-outs and downs still pending at the end that are PENDING_FAIL_S old (younger pending
## ones are the wipe and don't count either way). time-to-revive is from the down to getting up.
## The fair rate (T-058, `fair_rate`): a down only counts against the bots when a bot could have come: `reach_s`
## (the seconds of that down during which a teammate bot was on its feet) is PENDING_FAIL_S or more. A down that
## bled out or was still open at the wipe while every bot was down too (the scripted player alone on its feet: it
## revives nobody) is "excused" and not judged. Episodes without reach_s count as reachable (the old rule).
static func revive_summary(eps: Array, end_t: float) -> Dictionary:
	var out: Dictionary = {"downs": eps.size(), "revived": 0, "bled": 0, "pending": 0, "pending_failed": 0,
		"attempts": 0, "attempts_ok": 0, "ttr_total": 0.0, "ttr_mean": 0.0, "success_rate": 0.0,
		"excused": 0, "fair_failed": 0, "fair_rate": 0.0}
	for e: Dictionary in eps:
		out["attempts"] = int(out["attempts"]) + int(e.get("attempts", 0))
		out["attempts_ok"] = int(out["attempts_ok"]) + int(e.get("attempts_ok", 0))
		var reachable: bool = float(e.get("reach_s", INF)) >= PENDING_FAIL_S
		match str(e.get("outcome", "pending")):
			"revived":
				out["revived"] = int(out["revived"]) + 1
				out["ttr_total"] = float(out["ttr_total"]) + maxf(0.0, float(e.get("t_end", 0.0)) - float(e.get("t_down", 0.0)))
			"bled":
				out["bled"] = int(out["bled"]) + 1
				if reachable:
					out["fair_failed"] = int(out["fair_failed"]) + 1
				else:
					out["excused"] = int(out["excused"]) + 1
			_:
				out["pending"] = int(out["pending"]) + 1
				if end_t - float(e.get("t_down", end_t)) >= PENDING_FAIL_S:
					out["pending_failed"] = int(out["pending_failed"]) + 1
					if reachable:
						out["fair_failed"] = int(out["fair_failed"]) + 1
					else:
						out["excused"] = int(out["excused"]) + 1
	var judged: int = int(out["revived"]) + int(out["bled"]) + int(out["pending_failed"])
	out["success_rate"] = float(out["revived"]) / float(judged) if judged > 0 else 0.0
	var fair_judged: int = int(out["revived"]) + int(out["fair_failed"])
	out["fair_rate"] = float(out["revived"]) / float(fair_judged) if fair_judged > 0 else 0.0
	out["ttr_mean"] = float(out["ttr_total"]) / float(out["revived"]) if int(out["revived"]) > 0 else 0.0
	return out


## What a purchase was, from its item id (Economy.spend's item): "perk", "wall_gun", "ammo" (wall-buy ammo, an
## upgraded gun's too: the Crucible sells none, T-083), "ammo_box", "crucible" (an upgrade), "crate", "door",
## "pylon", "trap" or "other".
static func category_of(item: String, perks: Dictionary, weapons: Dictionary, upgraded: Dictionary) -> String:
	if perks.has(item):
		return "perk"
	if weapons.has(item):
		return "wall_gun"
	if item.ends_with("_box_ammo") or item == "ammo_box_grenades":
		return "ammo_box"
	if item.ends_with("_ammo"):
		return "ammo"
	if item == "crate":
		return "crate"
	if item == "crucible":
		return "crucible"
	if item.begins_with("door_"):
		return "door"
	if item.begins_with("pylon_"):
		return "pylon"
	if item.begins_with("trap_") or item.ends_with("_trap"):
		return "trap"
	return "other"


## How good a gun is for the "worse than held" waste rule: its wall price; the start pistol 0; a crate-only gun
## (no wall price) 1500; an upgraded gun 5000. `row` is its weapons.json row ({} when unknown).
static func gun_quality(id: String, row: Dictionary, is_upgraded: bool) -> float:
	if is_upgraded or id.ends_with("_up"):
		return 5000.0
	if row.is_empty():
		return 0.0
	var price: float = float(row.get("wall_price", 0))
	if price <= 0.0 and str(row.get("class", "")) != "pistol":
		return 1500.0
	return price


## Why a wall-gun purchase wasted its Scrip, or "" when it didn't. `quality` maps gun id -> gun_quality;
## `held_before` = the base ids carried just before the buy; `dropped_round` = the round it stopped being carried
## (-1 = still carried, or lost to a bleed-out, which isn't a choice). First matching rule:
##   "late_weak"  a LATE_WEAK_GUNS gun bought after round LATE_ROUND
##   "worse"      a gun worse than the best one already carried
##   "dropped"    no longer carried within DROP_WINDOW_ROUNDS rounds of buying it
static func gun_waste_rule(item: String, buy_round: int, held_before: Array, dropped_round: int, quality: Dictionary) -> String:
	if LATE_WEAK_GUNS.has(item) and buy_round > LATE_ROUND:
		return "late_weak"
	var q: float = float(quality.get(item, 0.0))
	var best: float = -1.0
	for h: Variant in held_before:
		if str(h) == item:
			continue
		best = maxf(best, float(quality.get(str(h), 0.0)))
	if best > q:
		return "worse"
	if dropped_round >= 0 and dropped_round - buy_round <= DROP_WINDOW_ROUNDS:
		return "dropped"
	return ""


# ================================================================== observation

func _blank(pid: int) -> Dictionary:
	return {"pid": pid, "name": Net.display_name(pid), "bot": GameState.is_bot(pid),
		"character": str(GameState.characters.get(pid, GameState.character_id)),
		"kills": 0, "headshots": 0, "downs": 0, "revives_done": 0, "revive_attempts": 0, "bleed_outs": 0,
		"stuck_events": 0, "stuck_time": 0.0, "teleports": 0, "lost_time": 0.0,
		"block_events": 0, "block_sustained": 0, "block_time": 0.0,
		"empty_mag_events": 0, "empty_mag_time": 0.0, "pistol_time": 0.0,
		"scrip_spent": 0, "scrip_wasted": 0, "kar98k_late": 0, "spent": {}, "commands": 0, "command_time": 0.0,
		"scrip_end": 0}


func _stat(pid: int) -> Dictionary:
	if not stats.has(pid):
		stats[pid] = _blank(pid)
	return stats[pid]


func _round_row(r: int) -> Dictionary:
	if not rounds.has(r):
		rounds[r] = {"t0": t, "t1": -1.0, "downs": {}, "kills": {}}
	return rounds[r]


func _event(pid: int, kind: String, value: float, detail: String) -> void:
	events.append([t, RoundManager.current_round, pid, kind, value, detail])


func _player(pid: int) -> Player:
	return map.players.get(pid) as Player if map != null and is_instance_valid(map) else null


func _pos_of(pid: int) -> String:
	var p: Player = _player(pid)
	if p == null:
		return ""
	return "(%.1f %.1f %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z]


func _physics_process(delta: float) -> void:
	if finished or map == null or not is_instance_valid(map) or GameState.phase != GameState.Phase.PLAYING:
		return
	t += delta
	var zs: Array[Zombie] = []
	if map.director != null:
		zs = map.director.active_zombies()
	var humans: Array[Player] = []
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		if p != null and not p.is_bot and p.is_alive() and not p.spectating:
			humans.append(p)
	for pid: Variant in map.players.keys():
		var b: Player = map.players[pid] as Player
		if b == null or not b.is_bot:
			continue
		_watch_bot(b, humans, zs, delta)
	_watch_revives(delta)


func _watch_bot(b: Player, humans: Array[Player], zs: Array[Zombie], delta: float) -> void:
	var pid: int = b.player_id
	var s: Dictionary = _stat(pid)
	var up: bool = b.is_alive() and not b.spectating
	# blocking: inside a moving human's personal space
	for h: Player in humans:
		var key: String = "%d:%d" % [pid, h.player_id]
		var st: Dictionary = _block.get(key, {})
		var cond: bool = up and blocking(b.global_position, h.global_position, h.horizontal_speed())
		var r: Vector2i = block_step(st, cond, delta)
		_block[key] = st
		if cond:
			s["block_time"] = float(s["block_time"]) + delta
		s["block_events"] = int(s["block_events"]) + r.x
		if r.y > 0:
			s["block_sustained"] = int(s["block_sustained"]) + r.y
			_event(pid, "block_sustained", 1.0, "P%d at %s" % [h.player_id, _pos_of(pid)])
	# empty magazine with a zombie close
	var w: WeaponInstance = b.weapons.current() if b.weapons != null else null
	var near: float = INF
	if up:
		for z: Zombie in zs:
			if not is_instance_valid(z) or z.state == Zombie.State.DEAD:
				continue
			if absf(z.global_position.y - b.global_position.y) > 2.0:
				continue
			near = minf(near, Vector2(z.global_position.x - b.global_position.x, z.global_position.z - b.global_position.z).length())
	var empty: bool = up and w != null and empty_mag_moment(w.mag, near)
	if empty:
		s["empty_mag_time"] = float(s["empty_mag_time"]) + delta
		if not bool(_empty.get(pid, false)):
			s["empty_mag_events"] = int(s["empty_mag_events"]) + 1
			_event(pid, "empty_mag", 1.0, "%s, zombie %.1f m" % [str(w.id), near])
	_empty[pid] = empty
	# on the start pistol while carrying a better gun that still has ammo
	if up and w != null and pistol_while_armed(w.weapon_class(), _other_guns_ammo(b, w)):
		s["pistol_time"] = float(s["pistol_time"]) + delta
	# lost: far from the human for a while
	var lost: bool = false
	if up:
		for h: Player in humans:
			if Vector2(h.global_position.x - b.global_position.x, h.global_position.z - b.global_position.z).length() > LOST_DIST_M:
				lost = true
	_lost_t[pid] = float(_lost_t.get(pid, 0.0)) + delta if lost else 0.0
	if float(_lost_t[pid]) > LOST_AFTER_S:
		s["lost_time"] = float(s["lost_time"]) + delta
	# guns carried (for the "dropped" waste rule): not while bled out, that loses everything and isn't a choice
	if b.spectating:
		for g: Dictionary in gun_buys:
			if int(g["pid"]) == pid and int(g["dropped_round"]) < 0:
				g["lost"] = true
		return
	var held: Array = []
	if b.weapons != null:
		for wi: WeaponInstance in b.weapons.slots:
			held.append(String(wi.base_id()))
	for g2: Dictionary in gun_buys:
		if int(g2["pid"]) == pid and int(g2["dropped_round"]) < 0 and not bool(g2["lost"]) and not held.has(str(g2["item"])):
			g2["dropped_round"] = RoundManager.current_round
			_event(pid, "gun_dropped", 0.0, str(g2["item"]))
	_held[pid] = held


## Who is holding use on whom (co-op state): an attempt starts when a reviver appears; a bleed-out ends it.
## reach_s adds up the time a teammate bot was on its feet (one that could come; the fair revive rate).
func _watch_revives(delta: float) -> void:
	var s: NetMatch = Net.session
	if s == null:
		return
	for pid: Variant in _open_ep.keys():
		var e: Dictionary = episodes[int(_open_ep[pid])]
		for q: Variant in map.players.keys():
			var bq: Player = map.players[q] as Player
			if bq != null and bq.is_bot and int(q) != int(pid) and bq.is_alive() and not bq.spectating:
				e["reach_s"] = float(e.get("reach_s", 0.0)) + delta
				break
		var by: int = s.coop.reviver_of(int(pid))
		var was: int = int(_reviver.get(pid, 0))
		if by != 0 and by != was:
			e["attempts"] = int(e["attempts"]) + 1
			var rs: Dictionary = _stat(by)
			rs["revive_attempts"] = int(rs["revive_attempts"]) + 1
			_event(by, "revive_start", 0.0, "P%d" % int(pid))
		_reviver[pid] = by
		if s.coop.is_dead(int(pid)) or (_player(int(pid)) != null and _player(int(pid)).spectating):
			e["outcome"] = "bled"
			e["t_end"] = t
			_stat(int(pid))["bleed_outs"] = int(_stat(int(pid))["bleed_outs"]) + 1
			_event(int(pid), "bled_out", t - float(e["t_down"]), "")
			_open_ep.erase(pid)
			_reviver.erase(pid)


func _on_killed(_enemy: StringName, limb: StringName, _weapon: StringName, by: int) -> void:
	if by <= 0 or finished:
		return
	var s: Dictionary = _stat(by)
	s["kills"] = int(s["kills"]) + 1
	if limb == &"head":
		s["headshots"] = int(s["headshots"]) + 1
	var rr: Dictionary = _round_row(RoundManager.current_round)
	rr["kills"][by] = int((rr["kills"] as Dictionary).get(by, 0)) + 1


func _on_downed(pid: int) -> void:
	if finished:
		return
	var s: Dictionary = _stat(pid)
	s["downs"] = int(s["downs"]) + 1
	var rr: Dictionary = _round_row(RoundManager.current_round)
	rr["downs"][pid] = int((rr["downs"] as Dictionary).get(pid, 0)) + 1
	_event(pid, "down", 0.0, _pos_of(pid))
	if _open_ep.has(pid):
		return
	episodes.append({"pid": pid, "t_down": t, "round": RoundManager.current_round, "outcome": "pending", "t_end": -1.0,
		"attempts": 0, "attempts_ok": 0, "by": 0, "reach_s": 0.0})
	_open_ep[pid] = episodes.size() - 1
	_reviver[pid] = 0


func _on_revived(pid: int, by: int) -> void:
	if finished:
		return
	if by > 0 and by != pid:
		var s: Dictionary = _stat(by)
		s["revives_done"] = int(s["revives_done"]) + 1
	if _open_ep.has(pid):
		var e: Dictionary = episodes[int(_open_ep[pid])]
		e["outcome"] = "revived"
		e["t_end"] = t
		e["by"] = by
		if int(e["attempts"]) == 0:
			e["attempts"] = 1   # a hold shorter than a frame of polling: still an attempt
			if by > 0:
				_stat(by)["revive_attempts"] = int(_stat(by)["revive_attempts"]) + 1
		e["attempts_ok"] = int(e["attempts_ok"]) + 1
		_event(by, "revive", t - float(e["t_down"]), "P%d" % pid)
		_open_ep.erase(pid)
		_reviver.erase(pid)


func _on_purchase(pid: int, item: StringName, cost: int) -> void:
	if finished:
		return
	var it: String = String(item)
	var cat: String = category_of(it, GLData.table("perks").get("perks", {}), _wtable.get("weapons", {}), _wtable.get("upgraded", {}))
	var s: Dictionary = _stat(pid)
	s["scrip_spent"] = int(s["scrip_spent"]) + cost
	var sp: Dictionary = s["spent"]
	sp[cat] = int(sp.get(cat, 0)) + cost
	var r: int = RoundManager.current_round
	_event(pid, "buy_" + cat, float(cost), it)
	if cat == "wall_gun":
		var key: String = "wall_gun:%s@r%d" % [it, r]
		sp[key] = int(sp.get(key, 0)) + cost
		if it == "kar98k" and r > LATE_ROUND:
			s["kar98k_late"] = int(s["kar98k_late"]) + 1
		var before: Array = (_held.get(pid, []) as Array).duplicate()
		gun_buys.append({"pid": pid, "item": it, "round": r, "cost": cost, "held_before": before, "dropped_round": -1, "lost": false})


func _on_round_started(r: int, _special: bool) -> void:
	if finished:
		return
	if rounds.has(r - 1):
		(rounds[r - 1] as Dictionary)["t1"] = t
	_round_row(r)
	round_reached = maxi(round_reached, r)
	for pid: int in stats.keys():   # U08: the Scrip curve (each player's purse at every round's start)
		_event(pid, "scrip", float(Economy.get_scrip(pid)) if Economy.has_account(pid) else -1.0, "")


## U08: the perk-tier timeline (a tier bought, or kept / lost) and the egg's steps, as events.
func _on_perk_tier(pid: int, perk_id: StringName, tier: int) -> void:
	if not finished:
		_event(pid, "perk_tier", float(tier), String(perk_id))


func _on_step_done(quest_id: StringName, step_id: StringName) -> void:
	if not finished:
		_event(0, "egg_step", 1.0, "%s/%s" % [quest_id, step_id])


func _on_step_failed(quest_id: StringName, step_id: StringName, reason: StringName) -> void:
	if not finished:
		_event(0, "egg_fail", 0.0, "%s/%s:%s" % [quest_id, step_id, reason])


func _on_game_over(_stats: Dictionary) -> void:
	# deferred: the wipe is announced from inside the last player_downed, before this logger has heard that down
	finish.call_deferred("wipe")


# ================================================================== the report

func _quality() -> Dictionary:
	var q: Dictionary = {}
	var w: Dictionary = _wtable.get("weapons", {})
	for id: Variant in w.keys():
		q[str(id)] = gun_quality(str(id), w[id], false)
	for id2: Variant in (_wtable.get("upgraded", {}) as Dictionary).keys():
		q[str(id2)] = 5000.0
	return q


## Ends the run: closes the open episodes and rounds, scores the purchases. Returns the summary (summary()).
func finish(reason: String) -> Dictionary:
	if finished:
		return summary()
	finished = true
	end_reason = reason
	round_reached = maxi(round_reached, RoundManager.current_round)
	if rounds.has(RoundManager.current_round):
		(rounds[RoundManager.current_round] as Dictionary)["t1"] = t
	var q: Dictionary = _quality()
	for g: Dictionary in gun_buys:
		var rule: String = gun_waste_rule(str(g["item"]), int(g["round"]), g["held_before"], -1 if bool(g["lost"]) else int(g["dropped_round"]), q)
		g["waste"] = rule
		if rule != "":
			var s: Dictionary = _stat(int(g["pid"]))
			s["scrip_wasted"] = int(s["scrip_wasted"]) + int(g["cost"])
			events.append([t, int(g["round"]), int(g["pid"]), "wasted_" + rule, float(g["cost"]), str(g["item"])])
	for pid: Variant in stats.keys():
		(stats[pid] as Dictionary)["scrip_end"] = Economy.get_scrip(int(pid))
	return summary()


func _bots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid: Variant in stats.keys():
		if bool((stats[pid] as Dictionary)["bot"]):
			out.append(stats[pid])
	return out


func _sum(key: String) -> float:
	var n: float = 0.0
	for s: Dictionary in _bots():
		n += float(s.get(key, 0.0))
	return n


## The run's headline numbers (bots only unless named "human_").
func summary() -> Dictionary:
	var bot_eps: Array = []
	for e: Dictionary in episodes:
		bot_eps.append(e)
	var rv: Dictionary = revive_summary(bot_eps, t)
	var humans_downs: int = 0
	for pid: Variant in stats.keys():
		if not bool((stats[pid] as Dictionary)["bot"]):
			humans_downs += int((stats[pid] as Dictionary)["downs"])
	var played: int = maxi(1, round_reached)
	var cmds: float = _sum("commands")
	var out: Dictionary = {"run": run_id, "scenario": scenario, "seed": run_seed, "end": end_reason, "round_reached": round_reached,
		"minutes": t / 60.0, "bot_kills": int(_sum("kills")), "bot_headshots": int(_sum("headshots")),
		"bot_downs": int(_sum("downs")), "bot_downs_per_round": _sum("downs") / float(played), "human_downs": humans_downs,
		"revived": rv["revived"], "bled": rv["bled"], "pending": rv["pending"], "pending_failed": rv["pending_failed"],
		"revive_rate": rv["success_rate"], "revive_fair_rate": rv["fair_rate"], "revive_excused": rv["excused"], "revive_fair_failed": rv["fair_failed"],
		"ttr_mean": rv["ttr_mean"], "revive_attempts": rv["attempts"], "revive_attempts_ok": rv["attempts_ok"],
		"stuck_events": int(_sum("stuck_events")), "stuck_time": _sum("stuck_time"), "teleports": int(_sum("teleports")),
		"lost_time": _sum("lost_time"), "block_events": int(_sum("block_events")), "block_sustained": int(_sum("block_sustained")),
		"block_time": _sum("block_time"), "scrip_spent": int(_sum("scrip_spent")), "scrip_wasted": int(_sum("scrip_wasted")),
		"kar98k_late": int(_sum("kar98k_late")), "empty_mag_events": int(_sum("empty_mag_events")), "empty_mag_time": _sum("empty_mag_time"),
		"pistol_time": _sum("pistol_time"),
		"commands": int(cmds), "command_time_mean": _sum("command_time") / cmds if cmds > 0.0 else 0.0}
	for k: Variant in extra.keys():
		out[k] = extra[k]
	return out


## The one-line summary printed to stdout at the end of a run.
func summary_line() -> String:
	var s: Dictionary = summary()
	return ("[ai_metrics] SUMMARY %s run=%s end=%s round=%d time=%.1fmin | bot kills %d (heads %d) | bot downs %d (%.2f/round), human downs %d" +
		" | revives %d/%d judged (%.0f%%; fair %.0f%%, %d excused; ttr %.1fs, attempts %d ok %d, bled %d, pending %d) | stuck %d (%.1fs) teleports %d lost %.0fs" +
		" | blocking %d events, %d sustained (%.1fs) | scrip spent %d wasted %d, kar98k>r10 %d | empty-mag %d (%.1fs) | pistol with a loaded gun %.0fs | commands %d") % [
		s["scenario"], s["run"], s["end"], s["round_reached"], s["minutes"], s["bot_kills"], s["bot_headshots"], s["bot_downs"],
		s["bot_downs_per_round"], s["human_downs"], s["revived"], int(s["revived"]) + int(s["bled"]) + int(s["pending_failed"]),
		100.0 * float(s["revive_rate"]), 100.0 * float(s["revive_fair_rate"]), s["revive_excused"], s["ttr_mean"], s["revive_attempts"], s["revive_attempts_ok"], s["bled"], s["pending"],
		s["stuck_events"], s["stuck_time"], s["teleports"], s["lost_time"], s["block_events"], s["block_sustained"], s["block_time"],
		s["scrip_spent"], s["scrip_wasted"], s["kar98k_late"], s["empty_mag_events"], s["empty_mag_time"], s["pistol_time"], s["commands"]]


static func _csv(v: Variant) -> String:
	var txt: String = ("%.3f" % float(v)) if v is float else str(v)
	if txt.contains(",") or txt.contains("\"") or txt.contains("\n"):
		return "\"" + txt.replace("\"", "\"\"") + "\""
	return txt


## The res-relative log folder (logs/ai_runs/ under the project, git-ignored; a .gdignore keeps Godot from
## importing the CSVs).
static func log_dir() -> String:
	var dir: String = ProjectSettings.globalize_path("res://logs/ai_runs")
	DirAccess.make_dir_recursive_absolute(dir)
	var ign: String = ProjectSettings.globalize_path("res://logs/.gdignore")
	if not FileAccess.file_exists(ign):
		var f: FileAccess = FileAccess.open(ign, FileAccess.WRITE)
		if f != null:
			f.store_string("")
	return dir


## Writes this run's CSV (long format: section,round,pid,name,key,value,detail) to `dir` and appends the
## summary row to dir/summary_<scenario>.csv. Returns the run CSV's path.
func write_csv(dir: String) -> String:
	var path: String = dir.path_join("%s.csv" % run_id)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("BotMetrics: can't write %s" % path)
		return ""
	f.store_line("run,scenario,seed,section,round,pid,name,key,value,detail")
	var head: String = "%s,%s,%d," % [_csv(run_id), _csv(scenario), run_seed]
	var sm: Dictionary = summary()
	for k: Variant in sm.keys():
		f.store_line(head + "run,,,,%s,%s," % [_csv(k), _csv(sm[k])])
	for pid: Variant in stats.keys():
		var s: Dictionary = stats[pid]
		for k2: Variant in s.keys():
			if k2 == "spent":
				for c: Variant in (s["spent"] as Dictionary).keys():
					f.store_line(head + "player,,%d,%s,spent:%s,%s," % [int(pid), _csv(s["name"]), _csv(c), _csv(s["spent"][c])])
			elif k2 != "pid" and k2 != "name":
				f.store_line(head + "player,,%d,%s,%s,%s," % [int(pid), _csv(s["name"]), _csv(k2), _csv(s[k2])])
	var rs: Array = rounds.keys()
	rs.sort()
	for r: Variant in rs:
		var row: Dictionary = rounds[r]
		var secs: float = (float(row["t1"]) if float(row["t1"]) >= 0.0 else t) - float(row["t0"])
		f.store_line(head + "round,%d,,,seconds,%s," % [int(r), _csv(secs)])
		for pid2: Variant in stats.keys():
			f.store_line(head + "round,%d,%d,%s,downs,%d," % [int(r), int(pid2), _csv((stats[pid2] as Dictionary)["name"]), int((row["downs"] as Dictionary).get(pid2, 0))])
			f.store_line(head + "round,%d,%d,%s,kills,%d," % [int(r), int(pid2), _csv((stats[pid2] as Dictionary)["name"]), int((row["kills"] as Dictionary).get(pid2, 0))])
	for e: Array in events:
		var nm: String = str((stats.get(int(e[2]), {}) as Dictionary).get("name", ""))
		f.store_line(head + "event,%d,%d,%s,%s,%s,%s" % [int(e[1]), int(e[2]), _csv(nm), _csv(e[3]), _csv(e[4]), _csv("t=%.1f %s" % [float(e[0]), str(e[5])])])
	f.close()
	var sp: String = dir.path_join("summary_%s.csv" % scenario)
	var header: String = ",".join(PackedStringArray(sm.keys().map(func(k3: Variant) -> String: return str(k3))))
	if FileAccess.file_exists(sp):
		var old: FileAccess = FileAccess.open(sp, FileAccess.READ)
		var old_header: String = old.get_line() if old != null else ""
		if old != null:
			old.close()
		if old_header != header:   # the columns changed (a new metric): keep the old file, start a new one
			DirAccess.rename_absolute(sp, sp.get_basename() + "_until_%d.csv" % int(Time.get_unix_time_from_system()))
	var fresh: bool = not FileAccess.file_exists(sp)
	var sf: FileAccess = FileAccess.open(sp, FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
	if sf != null:
		sf.seek_end()
		if fresh:
			sf.store_line(header)
		sf.store_line(",".join(PackedStringArray(sm.values().map(func(v: Variant) -> String: return _csv(v)))))
		sf.close()
	return path
