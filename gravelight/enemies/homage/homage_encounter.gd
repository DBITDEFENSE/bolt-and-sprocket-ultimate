class_name HomageEncounter
extends Node3D
## The shared round director for a single homage boss (HB2 PAUL on Kaltenbrunn, HB3 THE SLENDER on Totenhafen;
## docs/HOMAGE_BOSSES.md sections 3.2, 5.2, 6.6; DECISIONS T-159, T-160). The Cousins keep their own CousinsRound
## (HB1); this is the same shape for one boss:
##   - the schedule: the boss's round is reserved (no Bellringer / special round and no Foreman can land on it; they
##     move +1), and if one still sits on it when the round starts (a late reservation, a debug jump) the boss
##     moves +1 instead (`pick_round`);
##   - the horde keeps spawning at `horde_fraction` during the fight; the boss holds the round open as a reserved
##     "alive" slot until it dies or leaves;
##   - bots alone (the boss block's `bots_alone`, the same switch as HB1's): while no human is on their feet the boss
##     scales down (health keeps its fraction) and the queued horde thins once;
##   - the fail-safe: `failsafe_seconds` after the spawn the boss leaves as its design says (PAUL climbs the
##     headframe and leaps away north; THE SLENDER walks off the quay into the storm), so a round never softlocks;
##   - lines: the baked VO when lines.json has the id, else the boss block's subtitle silently (`say`);
##   - the Homage Bosses setting: Off = no boss, the round plays as a normal round.
## Host / solo only (a co-op client sees the generic puppet body, as HB1).

enum Phase { IDLE, ACTIVE, CLEARED, LEFT }

var file_key: String = ""            # "bosses/map01"
var boss_id: String = ""             # "paul"
var fcfg: Dictionary = {}            # the whole file
var cfg: Dictionary = {}             # this boss's block
var director: ZombieDirector
var phase: Phase = Phase.IDLE
var event_round: int = -1
var t: float = 0.0
var visits: int = 0                  # spawns so far this match (the first visit is 0 before it starts)
var hud: BossHud = null
var boss: HomageBoss = null
var lines_said: Array[String] = []
var rewards_given: bool = false
var reward_plan_given: Dictionary = {}
var left_count: int = 0
var bots_alone: bool = false
var bots_alone_switches: int = 0
var reserved_left: int = 0
var _no_human_t: float = 0.0
var _human_t: float = 0.0
var _horde_cut: bool = false
var _sched: Array = []
var _force: bool = false


# ================================================================== pure rules (unit-tested)

## The block of `id` in a per-map boss file.
static func block(file: Dictionary, id: String) -> Dictionary:
	return (file.get("bosses", {}) as Dictionary).get(id, {})


## True when this boss lives on `map_id` (the block's "map").
static func applies(map_id: StringName, b: Dictionary) -> bool:
	return not b.is_empty() and String(map_id) == str(b.get("map", ""))


## The round the boss takes when it wants `want`: never a Foreman round, never a special (Bellringer / LUFTALARM)
## round: either moves the boss +1 (repeatedly, if the next one is taken too).
static func pick_round(want: int, foreman_round: int, special_round: int) -> int:
	var r: int = want
	var guard: int = 0
	while (r == foreman_round or r == special_round) and guard < 8:
		r += 1
		guard += 1
	return r


## HP for a visit: base x the player scaling x (1 + return_step x visit) (visit 0 = the first).
static func visit_hp(b: Dictionary, players: int, visit: int) -> float:
	var base: float = HomageBoss.scaled_hp(float(b.get("hp_base", 30000.0)), players, float(b.get("hp_player_step", 0.75)))
	return base * (1.0 + float(b.get("return_hp_step", 0.0)) * float(maxi(0, visit)))


static func horde_count(round_total: int, b: Dictionary) -> int:
	return maxi(1, int(ceil(float(round_total) * float(b.get("horde_fraction", 0.5)))))


static func should_leave(seconds: float, b: Dictionary) -> bool:
	return seconds >= float(b.get("failsafe_seconds", 360.0))


## Display name with the Likeness Sheet's defaults (never a placeholder token): Real = the real first name over the
## in-world name; In-World = the in-world name alone; a missing sheet falls back to `fallback`.
static func title_of(slot: String, real: bool, fallback: String) -> PackedStringArray:
	var tl: PackedStringArray = HomageBoss.title_for(slot, real)
	var big: String = tl[0]
	if big == "" or HomageBoss.is_placeholder(big) or big.contains("%"):
		big = fallback
	var small: String = tl[1]
	if small == big or HomageBoss.is_placeholder(small) or small.contains("%"):
		small = ""
	return PackedStringArray([big, small])


## Replaces the Likeness Sheet's text tokens (%PAUL_LASTNAME% ...) with the sheet's values or their defaults, and
## strips anything left that still looks like a token, so no placeholder ever reaches the screen.
static func fill_tokens(text: String) -> String:
	var lk: Dictionary = HomageBoss.likeness().get("bosses", {})
	var p: Dictionary = lk.get("paul", {})
	var d: Dictionary = lk.get("devin", {})
	var pairs: Dictionary = {
		"%PAUL_LASTNAME%": _sheet(p, "last_name"), "%PAUL_UNIT%": _sheet(p, "unit"),
		"%DEVIN_LASTNAME%": _sheet(d, "last_name"), "%PAUL_SIGNATURE%": _sheet(p, "quirk"),
		"%DEVIN_SIGNATURE%": _sheet(d, "quirk"), "%PAUL_LETTER_DETAILS%": _sheet(p, "letter_details")}
	var out: String = text
	for k: String in pairs.keys():
		out = out.replace(k, str(pairs[k]))
	# anything still shaped like %TOKEN% or [TOKEN] goes (and its doubled space)
	var re: RegEx = RegEx.new()
	re.compile("%[A-Z_]+%|\\[[A-Z_]+\\]")
	out = re.sub(out, "", true)
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.replace(" .", ".").replace(" ,", ",").strip_edges()


static func _sheet(b: Dictionary, key: String) -> String:
	var v: String = str(b.get(key, ""))
	if v == "" or HomageBoss.is_placeholder(v):
		v = str(b.get(key + "_default", ""))
	return v


## The encounter for a map (PAUL on Kaltenbrunn, THE SLENDER on Totenhafen), or null.
static func make_for(map_id: StringName) -> HomageEncounter:
	if applies(map_id, block(GLData.table("bosses/map01"), "paul")):
		return PaulEncounter.new()
	if applies(map_id, block(GLData.table("bosses/map02"), "the_slender")):
		return SlenderEncounter.new()
	return null


# ================================================================== life cycle

func _init_from(file: String, id: String) -> void:
	file_key = file
	boss_id = id
	fcfg = GLData.table(file)
	cfg = block(fcfg, id)


func _ready() -> void:
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	event_round = first_round()
	if HomageBoss.homage_on() and event_round > 0:
		RoundManager.reserve_round(event_round)


func _map() -> Node:
	return director.get_parent() if director != null else get_parent()


## Subclasses: the boss's first round on this map (Totenhafen: 25 standalone, 45 in the campaign).
func first_round() -> int:
	return int(cfg.get("round", 15))


## The boss may start on round `r` now (the Slender waits for the power; nobody comes during an egg holdout).
func can_start(_r: int) -> bool:
	return true


func _on_round_started(r: int, special: bool) -> void:
	if not Net.is_authority() or phase == Phase.ACTIVE or phase == Phase.CLEARED:
		return
	if r != event_round:
		return
	if not HomageBoss.homage_on() and not _force:
		return
	# a Foreman or a special round still sitting on it (a late reservation): the boss moves +1
	var foreman_now: int = r if RoundManager.boss_due() else -1
	var special_now: int = r if special else -1
	var want: int = pick_round(r, foreman_now, special_now)
	if want != r or not can_start(r):
		RoundManager.unreserve_round(event_round)
		event_round = r + 1 if want == r else want
		RoundManager.reserve_round(event_round)
		print("[%s] waits: round %d is taken (next %d)" % [boss_id, r, event_round])
		return
	_force = false
	begin(r)


func _on_round_ended(r: int) -> void:
	if not Net.is_authority():
		return
	if r == event_round and (phase == Phase.CLEARED or phase == Phase.LEFT or phase == Phase.ACTIVE):
		_round_over()


## Dev / smoke: the boss on the next round start (`round_n` < 0: the current round now).
func start_now() -> void:
	_force = true
	if RoundManager.state == RoundManager.State.ROUND:
		RoundManager.unreserve_round(event_round)
		event_round = RoundManager.current_round
		RoundManager.reserve_round(event_round)
		begin(RoundManager.current_round)
	else:
		RoundManager.unreserve_round(event_round)
		event_round = RoundManager.current_round + 1
		RoundManager.reserve_round(event_round)


## The fight starts on round `r`.
func begin(r: int) -> void:
	phase = Phase.ACTIVE
	event_round = r
	t = 0.0
	rewards_given = false
	bots_alone = false
	_horde_cut = false
	_no_human_t = 0.0
	_human_t = 0.0
	_sched.clear()
	RoundManager.reserve_round(r)
	RoundManager.round_total = horde_count(RoundManager.round_total, cfg)
	RoundManager.to_spawn = mini(RoundManager.to_spawn, RoundManager.round_total)
	RoundManager.reserve_alive(1)
	reserved_left = 1
	if director != null:
		director._screamer_at = -1.0
	if Net.is_authority():
		GameState.set_flag(&"boss_fight", true)
	if hud == null or not is_instance_valid(hud):
		hud = BossHud.new()
		_map().add_child(hud)
	_tick_bots_alone(0.0, true)
	_begin()
	print("[%s] begins on round %d (visit %d, %d players' scaling, horde %d)" % [boss_id, r, visits + 1, RoundManager.players, RoundManager.round_total])


## Subclasses: the arrival schedule.
func _begin() -> void:
	pass


func at(seconds: float, fn: Callable) -> void:
	_sched.append([seconds, fn])


func _process(delta: float) -> void:
	if phase != Phase.ACTIVE:
		return
	t += delta
	_tick_bots_alone(delta)
	for e: Array in _sched.duplicate():
		if t >= float(e[0]):
			_sched.erase(e)
			(e[1] as Callable).call()
	_tick(delta)
	if boss != null and is_instance_valid(boss) and boss.is_active() and not boss.retreating and should_leave(boss_seconds(), cfg):
		leave()


## Seconds since the boss came in (the fail-safe's clock; the arrival beat doesn't count).
func boss_seconds() -> float:
	return t - spawn_t


var spawn_t: float = 0.0


func _tick(_delta: float) -> void:
	pass


## Puts the boss in (subclasses build and position it first).
func adopt(b: HomageBoss, health: float, at_pos: Vector3) -> void:
	b.event = self
	director.add_extra(b)
	b.spawn_homage(at_pos, health)
	boss = b
	spawn_t = t
	visits += 1
	if bots_alone:
		_apply_squad_scale()
	GLBus.boss_spawned.emit(StringName(boss_id))
	GLBus.enemy_spawned.emit(b.enemy_id, b.get_instance_id())


## HomageBoss._boss_die calls this on the encounter (the same hook name as HB1's).
func on_cousin_died(b: HomageBoss) -> void:
	if b != boss:
		return
	reserved_left = 0
	phase = Phase.CLEARED
	RoundManager.unreserve_round(event_round)
	_on_boss_died()


func _on_boss_died() -> void:
	pass


## The fail-safe (or a dev command): the boss leaves as designed; no rewards.
func leave() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.LEFT
	left_count += 1
	_sched.clear()
	_on_leave()
	if boss != null and is_instance_valid(boss) and boss.is_active():
		boss.retreat()
	if hud != null and is_instance_valid(hud):
		hud.strike(boss_id, false)
	RoundManager.release_alive(reserved_left)
	reserved_left = 0
	RoundManager.unreserve_round(event_round)
	var back: int = return_round(event_round)
	event_round = back
	if back > 0:
		RoundManager.reserve_round(back)
	HomageBoss.sync_fight_flag(get_tree(), boss)
	print("[%s] left at t=%.1f (fail-safe): back on round %d" % [boss_id, t, back])


func _on_leave() -> void:
	pass


## The round the boss comes back on after leaving (-1 = never).
func return_round(_r: int) -> int:
	return -1


func _round_over() -> void:
	HomageBoss.sync_fight_flag(get_tree(), null)
	var was: Phase = phase
	if hud != null and is_instance_valid(hud):
		var h: BossHud = hud
		hud = null
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_instance_valid(h):
				h.queue_free())
	if was == Phase.CLEARED:
		event_round = -1
		phase = Phase.CLEARED
	else:
		phase = Phase.IDLE
	print("[%s] round over (%s)" % [boss_id, Phase.keys()[was]])


# ================================================================== bots alone (HB1's switch, per boss block)

func human_counts() -> Vector2i:
	var up: int = 0
	var total: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.is_bot or p.is_companion:
			continue
		total += 1
		if not p.downed and not p.spectating:
			up += 1
	return Vector2i(up, total)


func _tick_bots_alone(delta: float, now: bool = false) -> void:
	var ba: Dictionary = CousinsRound.bots_alone_cfg(cfg)
	if not bool(ba.get("enabled", true)):
		return
	var hc: Vector2i = human_counts()
	var alone: bool = CousinsRound.squad_is_bots_alone(hc.x, hc.y)
	if alone:
		_no_human_t += delta
		_human_t = 0.0
	else:
		_human_t += delta
		_no_human_t = 0.0
	if not bots_alone and alone and (now or _no_human_t >= float(ba["engage_after"])):
		_set_bots_alone(true)
	elif bots_alone and not alone and _human_t >= float(ba["release_after"]):
		_set_bots_alone(false)


func _set_bots_alone(on: bool) -> void:
	bots_alone = on
	if on:
		bots_alone_switches += 1
		if not _horde_cut:
			_horde_cut = true
			var left: int = CousinsRound.cut_horde(RoundManager.to_spawn, CousinsRound.bots_alone_cfg(cfg))
			RoundManager.round_total -= RoundManager.to_spawn - left
			RoundManager.to_spawn = left
	_apply_squad_scale()
	print("[%s] bots alone %s (t=%.1f)" % [boss_id, "on" if on else "off", t])


func _apply_squad_scale() -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_active():
		return
	var m: Array[float] = CousinsRound.squad_mults(bots_alone, CousinsRound.bots_alone_cfg(cfg))
	boss.set_squad_scale(m[0], m[1], m[2], m[3])


# ================================================================== lines

## A boss / Operator / squad line: the baked VO when lines.json has it, else the block's subtitle silently.
func say(line_id: String, _from: Node = null) -> void:
	lines_said.append(line_id)
	if GLVO.lines.has(line_id):
		GLVO.play(StringName(line_id))
		return
	var rec: Dictionary = (cfg.get("lines", {}) as Dictionary).get(line_id, {})
	if rec.is_empty():
		return
	var text: String = fill_tokens(str(rec.get("text", "")).replace("{", "").replace("}", ""))
	var spk: String = str(rec.get("speaker", "OPR"))
	GLBus.vo_line_started.emit(StringName(line_id), StringName(speaker_label(spk)), text, maxf(1.6, float(text.length()) * 0.065))


## The subtitle speaker name for a line's speaker code (the boss follows Homage Names).
func speaker_label(spk: String) -> String:
	return spk


## The squad's reaction: the nearest human player's character line (`<CHR>_<suffix>`), when it exists.
func squad_line(suffix: String) -> void:
	var codes: Dictionary = {"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN", "bolt": "BLT", "vendelin": "VEN"}
	var code: String = str(codes.get(String(GameState.character_id), "DUT"))
	say("%s_%s" % [code, suffix])


func later(seconds: float, line: String) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void: say(line))


## Grants Scrip, records unlocks (calling card, Archive card), files the intel documents.
func grant_plan(plan: Dictionary) -> void:
	for pid: Variant in (plan.get("scrip", {}) as Dictionary).keys():
		Economy.grant(int(pid), int(plan["scrip"][pid]))
	for u: Variant in plan.get("unlocks", []):
		ProfileSave._grant_unlock(str(u))
	for i: Variant in plan.get("intel", []):
		GLBus.intel_found.emit(StringName(str(i)))
	rewards_given = true
	reward_plan_given = plan


## What a kill grants: {"scrip": {pid: n}, "drops": [...], "unlocks": [...], "intel": [...]}.
static func reward_plan(b: Dictionary, pids: Array) -> Dictionary:
	var r: Dictionary = b.get("rewards", {})
	var scrip: Dictionary = {}
	for pid: Variant in pids:
		scrip[int(pid)] = int(r.get("scrip_per_player", 2000))
	return {"scrip": scrip, "drops": (r.get("drops", []) as Array).duplicate(), "unlocks": (r.get("unlocks", []) as Array).duplicate(),
		"intel": (r.get("intel", []) as Array).duplicate()}
