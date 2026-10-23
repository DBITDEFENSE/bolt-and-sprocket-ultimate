class_name CousinsRound
extends Node3D
## The Cousins Round (HB1; docs/HOMAGE_BOSSES.md section 4.2): Map 0's round 10 when Settings -> Gameplay ->
## Homage Bosses is On (default). Created by the ZombieDirector on its map (cousins.json "map"); host / solo only.
##
## Setup (the end of round 9): the inn's lamps gutter out group by group (taproom, upstairs, stable), the fire dies
## to embers, a child's handprint smears across the north-west window, then clapping upstairs. (A skip straight to
## round 10, e.g. the dev launcher, plays the same beat compressed at the round start.)
## Arrival: the Hammer's title card and her maul tumbling down the stairwell, the Hammer 1.5 s later at the stair
## head (Door 1 splits open if it is still shut); 30 s in, the Reach's arms through two taproom windows, then the
## Reach from the hayloft (or through the east window when the stable door is shut); Alix out of a trapdoor behind
## the bar when either cousin is under 50% HP, a cousin dies, or 3:00 at the latest.
## Trio rules: the normal horde at 40% of round 10's count; each death strikes her bar, relights one lamp group,
## takes a voice out of the humming and enrages the survivors (+20% move and attack speed, stacking, plus each
## one's new move); Alix goes to hold the fallen cousin's hand. The round ends when all three are dead and the
## horde is cleared (the three hold the round open as reserved "alive" slots).
## Fail-safe: past 6:00 they get bored and leave (no rewards) and return on round 15 with full HP (and every 5
## rounds after that if they get bored again).
## Rewards (all three dead): Death's Door + Resupply at the last body (outside the drop cap: spawned directly),
## 1500 Scrip per player, the profile unlocks (calling card, the Three Ribbons charm, the Archive card; record-only)
## and the Aunt's Letter (INT_HB_01) filed through the intel channel.
## Bots alone (cousins.json "bots_alone"): while no human is on their feet (solo with bots and the human down or
## bled out, or a bots-only squad), the three scale down: less health (the bar keeps its fraction), softer hits,
## slower moves and cooldowns. It switches on after engage_after seconds without a human up and off again
## release_after seconds after one is back up, so a quick down and revive doesn't flip it.
## Lines: cousins.json "lines" (no baked audio yet): the subtitle shows silently when lines.json lacks the line.

enum Phase { IDLE, ACTIVE, CLEARED, BORED }

const KEYS: PackedStringArray = ["hammer", "reach", "alix"]

var cfg: Dictionary = {}
var director: ZombieDirector
var phase: Phase = Phase.IDLE
var event_round: int = 10
var t: float = 0.0
var returning: bool = false
var bosses: Dictionary = {}           # key -> HomageBoss
var dead: Dictionary = {}             # key -> true
var reserved_left: int = 0
var rewards_given: bool = false
var hud: BossHud = null
var lines_said: Array[String] = []
var bored_count: int = 0
var cleared_count: int = 0
var setup_played: bool = false
var last_dead_slot: String = ""
var reward_at: Vector3 = Vector3.ZERO
var lamps_out: int = 0                # lamps currently guttered (tests / the smoke)
var _sched: Array = []                # [at_seconds, Callable] beats of the active phase
var _lamps: Dictionary = {}           # name -> [Light3D, base energy, has_base]
var _group_lit: Dictionary = {}
var _fallen: Array[Node3D] = []
var _hatch: Node3D
var _hatch_lid: Node3D
var _handprint: Node3D
var _last_spawn_t: float = 0.0
var bots_alone: bool = false          # the squad scaling is on (no human on their feet)
var bots_alone_switches: int = 0      # times it switched on (tests / the soak)
var _no_human_t: float = 0.0
var _horde_cut: bool = false          # the bots-alone horde cut is once per encounter
var _human_t: float = 0.0


# ================================================================== pure rules (unit-tested)

static func applies(map_id: StringName, c: Dictionary) -> bool:
	return String(map_id) == str(c.get("map", ""))


static func is_event_round(r: int, the_round: int, on: bool) -> bool:
	return on and r == the_round


## The bots-alone scaling block with its defaults filled in.
static func bots_alone_cfg(c: Dictionary) -> Dictionary:
	var d: Dictionary = {"enabled": true, "hp_mult": 0.5, "damage_mult": 0.6, "cooldown_mult": 1.3, "speed_mult": 0.9,
		"horde_mult": 0.6, "engage_after": 4.0, "release_after": 2.0}
	d.merge(c.get("bots_alone", {}) as Dictionary, true)
	return d


## True when the scaling should be on: no human on their feet. `humans_up` = humans standing (not downed, not
## spectating); `humans_total` = humans in the match. A match with nobody but bots counts as bots alone.
static func squad_is_bots_alone(humans_up: int, _humans_total: int) -> bool:
	return humans_up <= 0


## The horde still queued after the bots-alone cut: ceil(queued x horde_mult), never more than queued.
static func cut_horde(queued: int, ba: Dictionary) -> int:
	return clampi(ceili(float(maxi(0, queued)) * float(ba.get("horde_mult", 1.0))), 0, maxi(0, queued))


## The scaling multipliers for a state: [hp, damage, cooldown, speed] (all 1.0 when off).
static func squad_mults(on: bool, ba: Dictionary) -> Array[float]:
	if not on or not bool(ba.get("enabled", true)):
		return [1.0, 1.0, 1.0, 1.0] as Array[float]
	return [float(ba["hp_mult"]), float(ba["damage_mult"]), float(ba["cooldown_mult"]), float(ba["speed_mult"])] as Array[float]


## Humans standing / humans in the match (bots and companions like Jakub don't count).
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


## Steps the bots-alone switch (called every frame of the fight; `now` forces it on the first check).
func _tick_bots_alone(delta: float, now: bool = false) -> void:
	var ba: Dictionary = bots_alone_cfg(cfg)
	if not bool(ba.get("enabled", true)):
		return
	var hc: Vector2i = human_counts()
	var alone: bool = squad_is_bots_alone(hc.x, hc.y)
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
			# the horde still queued thins once (it is what downs the bots while they focus the three)
			_horde_cut = true
			var left: int = cut_horde(RoundManager.to_spawn, bots_alone_cfg(cfg))
			RoundManager.round_total -= RoundManager.to_spawn - left
			RoundManager.to_spawn = left
	for k: Variant in bosses.keys():
		var b: HomageBoss = boss(str(k))
		if b != null and b.is_active():
			_apply_squad_scale(b)
	print("[cousins] bots alone %s (t=%.1f)" % ["on: the cousins scale down" if on else "off: a human is back up", t])


func _apply_squad_scale(b: HomageBoss) -> void:
	var m: Array[float] = squad_mults(bots_alone, bots_alone_cfg(cfg))
	b.set_squad_scale(m[0], m[1], m[2], m[3])


## The horde during the fight: horde_fraction of the round's count (never zero).
static func horde_count(round_total: int, c: Dictionary) -> int:
	return maxi(1, int(ceil(float(round_total) * float(c.get("horde_fraction", 0.4)))))


static func boss_hp(key: String, players: int, c: Dictionary) -> float:
	var b: Dictionary = (c["bosses"] as Dictionary)[key]
	return HomageBoss.scaled_hp(float(b["hp_base"]), players, float(c.get("hp_player_step", 0.75)))


## Speed / attack-rate multiplier after `deaths` cousins have died (+20% each, stacking: 1.2, 1.4).
static func enrage_mult(deaths: int, c: Dictionary) -> float:
	return 1.0 + float(c.get("enrage_speed_step", 0.2)) * float(maxi(0, deaths))


static func should_retreat(seconds: float, c: Dictionary) -> bool:
	return seconds >= float(c.get("failsafe_seconds", 360.0))


static func return_round(r: int, c: Dictionary) -> int:
	return r + int(c.get("return_after_rounds", 5))


## Alix rises when either living cousin is under alix_hp_fraction, a cousin has died, or at alix_latest.
static func alix_due(seconds: float, hp_fractions: Array, any_dead: bool, c: Dictionary) -> bool:
	var a: Dictionary = c.get("arrival", {})
	if any_dead or seconds >= float(a.get("alix_latest", 180.0)):
		return true
	for f: Variant in hp_fractions:
		if float(f) < float(a.get("alix_hp_fraction", 0.5)):
			return true
	return false


## What clearing the round grants: {"scrip": {pid: n}, "drops": [...], "unlocks": [...], "intel": id}.
static func reward_plan(c: Dictionary, pids: Array) -> Dictionary:
	var r: Dictionary = c.get("rewards", {})
	var scrip: Dictionary = {}
	for pid: Variant in pids:
		scrip[int(pid)] = int(r.get("scrip_per_player", 1500))
	return {"scrip": scrip, "drops": (r.get("drops", []) as Array).duplicate(), "unlocks": (r.get("unlocks", []) as Array).duplicate(),
		"intel": str(r.get("intel", ""))}


## The campaign beacon (T-033): with Homage Bosses On, an exfil that would open on the Cousins Round opens the
## round after it (retries keep their gap: 14, 17 ...). Off: unchanged.
static func adjust_exfil(map_id: StringName, e: Dictionary, on: bool) -> Dictionary:
	var c: Dictionary = HomageBoss.cfg()
	if not on or e.is_empty() or not applies(map_id, c) or int(e.get("round", 0)) != int(c.get("round", 10)):
		return e
	var out: Dictionary = e.duplicate(true)
	out["round"] = int(c.get("round", 10)) + 1
	return out


# ================================================================== life cycle

func _ready() -> void:
	name = "CousinsRound"
	cfg = HomageBoss.cfg()
	event_round = int(cfg.get("round", 10))
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	if HomageBoss.homage_on():
		RoundManager.reserve_round(event_round)


func _map() -> Node:
	return director.get_parent() if director != null else get_parent()


func _on_round_ended(r: int) -> void:
	if not Net.is_authority():
		return
	if phase == Phase.IDLE and r + 1 == event_round and HomageBoss.homage_on():
		_play_setup(false)
	elif r == event_round or phase == Phase.CLEARED or phase == Phase.BORED:
		_round_over()


func _on_round_started(r: int, _special: bool) -> void:
	if not Net.is_authority():
		return
	if phase == Phase.IDLE and (is_event_round(r, event_round, HomageBoss.homage_on()) or (_force_on and r == event_round)):
		_force_on = false
		begin(r)


## Starts the encounter on round `r` (the round has just started).
func begin(r: int) -> void:
	phase = Phase.ACTIVE
	event_round = r
	t = 0.0
	dead.clear()
	bosses.clear()
	_fallen.clear()
	rewards_given = false
	bots_alone = false
	_horde_cut = false
	_no_human_t = 0.0
	_human_t = 0.0
	RoundManager.reserve_round(r)
	RoundManager.round_total = horde_count(RoundManager.round_total, cfg)
	RoundManager.to_spawn = mini(RoundManager.to_spawn, RoundManager.round_total)
	RoundManager.reserve_alive(KEYS.size())
	reserved_left = KEYS.size()
	_tick_bots_alone(0.0, true)   # after the horde is set: a bots-alone start thins it
	if director != null:
		director._screamer_at = -1.0
	if not setup_played:
		_play_setup(true)
	if hud == null or not is_instance_valid(hud):
		hud = BossHud.new()
		_map().add_child(hud)
	var a: Dictionary = cfg["arrival"]
	_sched.clear()
	if returning:
		_at(0.0, func() -> void: say("OPR_BOSS_COUSINS_RETURN_M0_01"))
		_at(1.0, func() -> void: say("CSN_RETURN_01"))
	else:
		_at(0.0, func() -> void: say("OPR_BOSS_COUSINS_M0_02"))
	_at(0.1, func() -> void:
		var tl: PackedStringArray = HomageBoss.title_for("cousin_1", HomageBoss.names_real())
		hud.title_card(tl[0], tl[1])
		_maul_tumble())
	_at(float(a["hammer_maul_lead"]), func() -> void: _spawn_hammer())
	_at(float(a["reach_after"]) - float(a["reach_arms_lead"]), func() -> void: _arms_through_windows())
	_at(float(a["reach_after"]), func() -> void: _spawn_reach())
	print("[cousins] the Cousins Round begins on round %d (%s, %d players' scaling, horde %d)" % [r, "return" if returning else "first", RoundManager.players, RoundManager.round_total])


func _at(seconds: float, fn: Callable) -> void:
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
	if not bosses.has("alix") and bosses.has("hammer"):
		var fr: Array = []
		for k: String in ["hammer", "reach"]:
			var b: HomageBoss = boss(k)
			if b != null and b.is_active():
				fr.append(b.hp_fraction())
		if alix_due(t, fr, not dead.is_empty(), cfg):
			_spawn_alix()
	if should_retreat(t, cfg):
		retreat()


func dead_count() -> int:
	return dead.size()


func alive_count() -> int:
	var n: int = 0
	for k: Variant in bosses.keys():
		var b: HomageBoss = boss(str(k))
		if b != null and b.is_active():
			n += 1
	return n


func boss(key: String) -> HomageBoss:
	var b: Variant = bosses.get(key, null)
	return b as HomageBoss if b != null and is_instance_valid(b) else null


# ================================================================== arrival

func _spawn(key: String, at: Vector3) -> HomageBoss:
	var b: HomageBoss
	match key:
		"hammer":
			b = CousinHammer.new()
		"reach":
			b = CousinReach.new()
		_:
			b = CousinAlix.new()
	b.event = self
	b.name = "Cousin_" + key
	director.add_extra(b)
	b.spawn_homage(_snap(at), boss_hp(key, RoundManager.players, cfg))
	if bots_alone:
		_apply_squad_scale(b)
	for i: int in enrage_steps_now():
		b.enrage_steps += 1   # a late arrival comes in already angry (no new-move line: she wasn't there)
	bosses[key] = b
	var slot: String = str(b.bcfg.get("slot", ""))
	var tl: PackedStringArray = HomageBoss.title_for(slot, HomageBoss.names_real())
	if hud != null:
		hud.add_bar(key, b, tl[0], tl[1])
	_last_spawn_t = t
	print("[cousins] %s arrives at %s (t=%.1f, hp %d%s; round alive %d, queued %d)" % [key, str(b.global_position.snapped(Vector3.ONE * 0.1)), t, int(b.max_hp), ", bots alone" if bots_alone else "", RoundManager.alive, RoundManager.to_spawn])
	return b


func enrage_steps_now() -> int:
	return dead.size()


func _spawn_hammer() -> void:
	var a: Dictionary = cfg["arrival"]
	_open_door(str(a["hammer_door"]))   # she splits Door 1 open on her way through; it stays open, free
	_spawn("hammer", _v(a["hammer_spawn"]))


func _spawn_reach() -> void:
	var a: Dictionary = cfg["arrival"]
	var stable_open: bool = _door_open(str(a["reach_door"]))
	var r: CousinReach
	if stable_open:
		r = _spawn("reach", _v(a["reach_loft"])) as CousinReach
		r.arrive_path = PackedVector3Array([_v(a["reach_loft"]), _snap(_v(a["reach_drop_to"]))])
		r.global_position = _v(a["reach_loft"])
	else:
		var w: Barricade = _window(str(a["reach_window"]))
		if w == null:
			r = _spawn("reach", _v(a["reach_drop_to"])) as CousinReach
		else:
			while w.boards > 0:
				w.tear_board()
			r = _spawn("reach", w.outside_point()) as CousinReach
			r.arrive_path = PackedVector3Array([w.outside_point(), w.sill_point(), w.inside_point()])
	var tl: PackedStringArray = HomageBoss.title_for("cousin_2", HomageBoss.names_real())
	if hud != null:
		hud.title_card(tl[0], tl[1])


func _spawn_alix() -> void:
	var a: Dictionary = cfg["arrival"]
	var at: Vector3 = _snap(_v(a["alix_trapdoor"]))
	_open_hatch(at)
	var al: CousinAlix = _spawn("alix", at) as CousinAlix
	al.trapdoor = at
	for body: Node3D in _fallen:
		al.on_cousin_fell(body)
	var tl: PackedStringArray = HomageBoss.title_for("cousin_3", HomageBoss.names_real())
	if hud != null:
		hud.title_card(tl[0], tl[1])
	say("OPR_BOSS_COUSINS_M0_03")
	get_tree().create_timer(1.2).timeout.connect(func() -> void: say("ALX_ARRIVE_01"))


func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _snap(p: Vector3) -> Vector3:
	var c: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
	return c if c.distance_to(p) < 2.5 else p


func _door(id: String) -> BuyDoor:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and String(d.door_id) == id:
			return d
	return null


func _door_open(id: String) -> bool:
	var d: BuyDoor = _door(id)
	return d == null or d.is_open


func _open_door(id: String) -> void:
	var d: BuyDoor = _door(id)
	if d != null and not d.is_open:
		d.open(0)
		AudioDirector.play_3d("board_break", d.global_position + Vector3.UP * 1.2, 6.0)


func _window(id: String) -> Barricade:
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var w: Barricade = n as Barricade
		if w != null and String(w.window_id) == id:
			return w
	var m: Node = _map().find_child(id, true, false)
	return m as Barricade


# ================================================================== deaths, enrage, clear

## A cousin fell (HomageBoss._boss_die).
func on_cousin_died(b: HomageBoss) -> void:
	var key: String = b.boss_key
	if dead.has(key):
		return
	dead[key] = true
	reserved_left = maxi(0, reserved_left - 1)
	last_dead_slot = str(b.bcfg.get("slot", ""))
	reward_at = b.global_position
	_fallen.append(b)
	if hud != null:
		hud.strike(key, true)
	_relight_next_group()
	for k: Variant in bosses.keys():
		var s: HomageBoss = boss(str(k))
		if s != null and s.is_active():
			s.enrage()
			if s is CousinAlix:
				(s as CousinAlix).on_cousin_fell(b)
	match dead.size():
		1:
			say("OPR_BOSS_COUSINS_DEAD_M0_01")
			_later(2.5, "CSN_WHISPER_01")
		2:
			say("OPR_BOSS_COUSINS_DEAD_M0_02")
			var last: HomageBoss = _last_standing()
			if last is CousinHammer:
				_later(2.5, "HAM_ALONE_01")
	print("[cousins] %s died (t=%.1f); %d dead (round alive %d, queued %d)" % [key, t, dead.size(), RoundManager.alive, RoundManager.to_spawn])
	if dead.size() >= KEYS.size():
		_clear()


func _later(seconds: float, line: String) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void: say(line))


func _last_standing() -> HomageBoss:
	for k: String in KEYS:
		var b: HomageBoss = boss(k)
		if b != null and b.is_active():
			return b
	return null


## The nearest other cousin (alive or fallen) for the Reach's dying reach.
func nearest_other_cousin(me: HomageBoss) -> Node3D:
	var best: Node3D = null
	var bd: float = INF
	for k: Variant in bosses.keys():
		var b: HomageBoss = boss(str(k))
		if b == null or b == me:
			continue
		var d: float = b.global_position.distance_to(me.global_position)
		if d < bd:
			bd = d
			best = b
	return best


func _clear() -> void:
	phase = Phase.CLEARED
	cleared_count += 1
	grant_rewards(reward_at, true)
	_relight_all()
	say("OPR_BOSS_COUSINS_DEAD_M0_03")
	RoundManager.unreserve_round(event_round)
	print("[cousins] cleared at t=%.1f: rewards granted" % t)


## The clear's rewards (spawn_drops false in tests: no map to drop into).
func grant_rewards(at: Vector3, spawn_drops: bool = true) -> Dictionary:
	var plan: Dictionary = reward_plan(cfg, GameState.player_ids)
	for pid: Variant in (plan["scrip"] as Dictionary).keys():
		Economy.grant(int(pid), int(plan["scrip"][pid]))
	if spawn_drops:
		var i: int = 0
		for d: Variant in plan["drops"]:
			PowerupManager.spawn(StringName(str(d)), at + Vector3(1.2 * float(i) - 0.6, 0, 0.8))
			i += 1
	for u: Variant in plan["unlocks"]:
		ProfileSave._grant_unlock(str(u))   # record-only: the card / charm / Archive card render once their slots exist
	if str(plan["intel"]) != "":
		GLBus.intel_found.emit(StringName(str(plan["intel"])))
	rewards_given = true
	return plan


# ================================================================== the fail-safe

## They get bored (6:00): everyone still out leaves laughing; those not out yet never come; no rewards; they come
## back on round 15 (then every 5 rounds) with full HP.
func retreat() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.BORED
	bored_count += 1
	_sched.clear()
	say("CSN_BORED_01")
	_later(2.0, "OPR_BOSS_COUSINS_BORED_M0_01")
	for k: Variant in bosses.keys():
		var b: HomageBoss = boss(str(k))
		if b != null and b.is_active():
			b.retreat()
			if hud != null:
				hud.strike(str(k), false)
	RoundManager.release_alive(reserved_left)
	reserved_left = 0
	RoundManager.unreserve_round(event_round)
	event_round = return_round(event_round, cfg)
	returning = true
	RoundManager.reserve_round(event_round)
	_close_hatch()
	_relight_all()
	print("[cousins] bored at t=%.1f: back on round %d" % [t, event_round])


func _round_over() -> void:
	# the bodies stay a while (their deaths play out), then go
	var bodies: Array = []
	for k: Variant in bosses.keys():
		var b: HomageBoss = boss(str(k))
		if b != null and not b.is_active():
			bodies.append(b)
	if not bodies.is_empty():
		get_tree().create_timer(12.0).timeout.connect(func() -> void:
			for b2: Variant in bodies:
				if is_instance_valid(b2):
					(b2 as HomageBoss).cleanup())
	bosses.clear()
	if hud != null and is_instance_valid(hud):
		var h: BossHud = hud
		hud = null
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(h):
				h.queue_free())
	var was: Phase = phase
	print("[cousins] round over (%s)" % Phase.keys()[was])
	phase = Phase.IDLE
	setup_played = false
	if was == Phase.CLEARED:
		event_round = -1   # done for this match
	_relight_all()


# ================================================================== lines

## Plays a Cousins line: the baked VO when lines.json has it, else its subtitle silently. Homage Names In-World
## swaps a named line for its unnamed twin.
func say(line_id: String, _from: Node = null) -> void:
	var lines: Dictionary = cfg.get("lines", {})
	var rec: Dictionary = lines.get(line_id, {})
	if not HomageBoss.names_real() and rec.has("twin"):
		line_id = str(rec["twin"])
		rec = lines.get(line_id, {})
	lines_said.append(line_id)
	if GLVO.lines.has(line_id):
		GLVO.play(StringName(line_id))
		return
	if rec.is_empty():
		return
	var text: String = str(rec.get("text", "")).replace("{", "").replace("}", "")
	text = text.replace("%DEAD_COUSIN_NAME%", HomageBoss.real_name(last_dead_slot) if last_dead_slot != "" else "")
	var spk: String = str(rec.get("speaker", "OPR"))
	var speaker: String = "OPR"
	match spk:
		"hammer":
			speaker = HomageBoss.speaker_name("cousin_1", HomageBoss.names_real())
		"reach":
			speaker = HomageBoss.speaker_name("cousin_2", HomageBoss.names_real())
		"alix":
			speaker = HomageBoss.speaker_name("cousin_3", HomageBoss.names_real())
		"cousins":
			speaker = "THE COUSINS"
	GLBus.vo_line_started.emit(StringName(line_id), StringName(speaker), text, maxf(1.6, float(text.length()) * 0.065))


# ================================================================== the setup beat and the set dressing

## The lamps gutter out (taproom -> upstairs -> stable), the fire dies, the handprint, the clapping upstairs.
## quick: the round is already starting (a skip to round 10): the same beat in about two seconds.
func _play_setup(quick: bool) -> void:
	setup_played = true
	_capture_lamps()
	var s: Dictionary = cfg["setup"]
	var gap: float = 0.08 if quick else float(s["lamp_gap"])
	var ggap: float = 0.15 if quick else float(s["group_gap"])
	var at: float = 0.0
	for g: Variant in s["group_order"]:
		_group_lit[str(g)] = false
		for lname: Variant in (s["lamp_groups"] as Dictionary)[str(g)]:
			_gutter_lamp(str(lname), at)
			at += gap
		at += ggap
	var fire: Light3D = _lamp_node(str(s["fire"]))
	if fire != null:
		_tween_energy(fire, float(s["fire_ember_energy"]), 2.5 if not quick else 1.0, 0.0)
	say("OPR_BOSS_COUSINS_M0_01")
	var hp_at: float = 0.5 if quick else float(s["handprint_at"])
	var clap_at: float = 1.0 if quick else float(s["clap_at"])
	get_tree().create_timer(hp_at).timeout.connect(_handprint_smear)
	get_tree().create_timer(clap_at).timeout.connect(_clapping)


func _capture_lamps() -> void:
	if not _lamps.is_empty():
		return
	var s: Dictionary = cfg["setup"]
	var names: Array = []
	for g: Variant in (s["lamp_groups"] as Dictionary).values():
		names.append_array(g as Array)
	names.append(str(s["fire"]))
	for n: Variant in names:
		var l: Light3D = _map().find_child(str(n), true, false) as Light3D
		if l == null:
			continue
		var has_base: bool = l.get("base_energy") != null
		# the inn's electric bulbs (T-061) relight to their powered energy, whatever they were at the setup
		var e: float = float(l.get("base_energy")) if has_base else (float(l.get_meta("energy")) if l.has_meta("energy") else l.light_energy)
		_lamps[str(n)] = [l, e, has_base]


func _lamp_node(n: String) -> Light3D:
	_capture_lamps()
	return (_lamps[n] as Array)[0] as Light3D if _lamps.has(n) else null


func _gutter_lamp(n: String, delay: float) -> void:
	var l: Light3D = _lamp_node(n)
	if l == null or not l.is_visible_in_tree():   # a bulb with the power still off has nothing to gutter
		return
	lamps_out += 1
	_tween_energy(l, 0.0, 0.6, delay)
	get_tree().create_timer(delay + 0.1).timeout.connect(func() -> void:
		if is_instance_valid(l):
			AudioDirector.play_3d("powerup_expire", l.global_position, -14.0))   # a breath-out


func _tween_energy(l: Light3D, to: float, secs: float, delay: float) -> void:
	if l == null or not is_instance_valid(l):
		return
	var prop: String = "base_energy" if l.get("base_energy") != null else "light_energy"
	var tw: Tween = l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(l, prop, to, secs)


func _relight_group(g: String) -> void:
	if bool(_group_lit.get(g, true)):
		return
	_group_lit[g] = true
	for n: Variant in (cfg["setup"]["lamp_groups"] as Dictionary).get(g, []):
		if _lamps.has(str(n)):
			var e: Array = _lamps[str(n)]
			_tween_energy(e[0] as Light3D, float(e[1]), 1.2, 0.0)
			lamps_out = maxi(0, lamps_out - 1)


func _relight_next_group() -> void:
	for g: Variant in cfg["setup"]["group_order"]:
		if not bool(_group_lit.get(str(g), true)):
			_relight_group(str(g))
			return


func _relight_all() -> void:
	for g: Variant in cfg["setup"]["group_order"]:
		_relight_group(str(g))
	var f: String = str(cfg["setup"]["fire"])
	if _lamps.has(f):
		_tween_energy((_lamps[f] as Array)[0] as Light3D, float((_lamps[f] as Array)[1]), 2.0, 0.0)


## A child-sized handprint smears across the north-west window from outside: a wet violet streak on the frost.
func _handprint_smear() -> void:
	var w: Barricade = _window(str(cfg["arrival"]["handprint_window"]))
	if w == null or (_handprint != null and is_instance_valid(_handprint)):
		return
	_handprint = Node3D.new()
	_handprint.name = "Handprint"
	_map().add_child(_handprint)
	_handprint.global_transform = w.global_transform
	var m: StandardMaterial3D = HomageBoss.mat(Color(0.62, 0.3, 0.95, 0.85), 1.6, 0.2)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var parts: Array = [[Vector2(0.11, 0.12), Vector3(0.18, 1.55, 0.05), 0.0]]
	for k: int in 4:
		parts.append([Vector2(0.025, 0.07), Vector3(0.13 + 0.03 * float(k), 1.66 + 0.01 * float(k % 2), 0.05), -0.25 + 0.15 * float(k)])
	parts.append([Vector2(0.025, 0.06), Vector3(0.25, 1.55, 0.05), 0.9])
	parts.append([Vector2(0.06, 0.22), Vector3(0.2, 1.4, 0.05), 0.05])   # the smear
	for p: Array in parts:
		var q: MeshInstance3D = MeshInstance3D.new()
		var qm: QuadMesh = QuadMesh.new()
		qm.size = p[0]
		q.mesh = qm
		q.material_override = m
		q.position = p[1]
		q.rotation.z = float(p[2])
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_handprint.add_child(q)


func _clapping() -> void:
	say("CSN_CLAP_01")
	var up: Vector3 = Vector3(12.0, 5.0, 3.0)
	for i: int in 6:
		get_tree().create_timer(0.33 * float(i)).timeout.connect(func() -> void:
			var p: AudioStreamPlayer3D = AudioDirector.play_3d("knife_hit", up + Vector3(randf_range(-2, 2), 0, 0), -6.0, 0.0)
			if p != null:
				p.pitch_scale = 1.7)
	get_tree().create_timer(2.6).timeout.connect(func() -> void: say("CSN_HUM_01"))


## The Hammer's maul is thrown down the stairwell first: it tumbles down the flight, bounces off the vestibule
## wall and spins back up out of sight.
func _maul_tumble() -> void:
	var a: Dictionary = cfg["arrival"]
	var top: Vector3 = _v(a["hammer_spawn"]) + Vector3(0, 1.0, 0.8)
	var foot: Vector3 = _v(a["hammer_stair_foot"]) + Vector3(2.4, 0.5, 0.0)
	var m: Node3D = Node3D.new()
	m.name = "MaulTumble"
	_map().add_child(m)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = CousinHammer._mesh_of([HomageBoss.cyl(0.024, 0.024, 0.78, Vector3(0, 0.25, 0), CousinHammer.HAFT),
		HomageBoss.boxp(Vector3(0.1, 0.13, 0.27), Vector3(0, -0.15, 0), CousinHammer.IRON)])
	m.add_child(mi)
	m.global_position = top
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "global_position", foot, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "rotation:x", TAU * 3.0, 0.7)
	tw.tween_callback(func() -> void: AudioDirector.play_3d("board_slam", foot, 2.0))
	tw.tween_property(m, "global_position", top + Vector3(0, 0.6, -1.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "rotation:x", TAU * 5.0, 0.6)
	tw.tween_callback(m.queue_free)
	AudioDirector.play_3d("board_break", top, 0.0, 0.0)


## Before her body, two arms snake in through two taproom windows, feel along the sills, withdraw.
func _arms_through_windows() -> void:
	for wid: Variant in cfg["arrival"]["reach_arm_windows"]:
		var w: Barricade = _window(str(wid))
		if w == null:
			continue
		var arm: HomageArm = HomageArm.new()
		arm.name = "ReachArmWindow"
		_map().add_child(arm)
		arm.setup(null, null, &"none", CousinReach.SKIN, CousinReach.SKIN, 0.045, 0.07)
		arm.follow_anchor = false
		var out: Vector3 = w.outside_point()
		out.y = w.global_position.y + 1.3
		var inside: Vector3 = w.inside_point()
		inside.y = w.global_position.y + 1.05
		arm.from_point = out
		arm.tip = out
		arm.refresh()
		var tw: Tween = arm.create_tween()
		tw.tween_property(arm, "tip", inside + (inside - out).normalized() * 0.6, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(arm, "tip", inside + w.global_basis.x * 0.6, 0.8)
		tw.tween_property(arm, "tip", out, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(arm.queue_free)
		AudioDirector.play_3d("board_break", w.global_position + Vector3.UP * 1.2, -6.0)


## The trapdoor behind the bar: a hatch the map never showed before (runtime; it stays open after the round).
func _open_hatch(at: Vector3) -> void:
	if _hatch == null or not is_instance_valid(_hatch):
		_hatch = Node3D.new()
		_hatch.name = "IceCellarTrapdoor"
		_map().add_child(_hatch)
		_hatch.global_position = at + Vector3.UP * 0.01
		var hole: MeshInstance3D = MeshInstance3D.new()
		var hb: BoxMesh = BoxMesh.new()
		hb.size = Vector3(0.9, 0.01, 0.9)
		hole.mesh = hb
		hole.material_override = HomageBoss.mat(Color(0.01, 0.01, 0.015))
		_hatch.add_child(hole)
		var hinge: Node3D = Node3D.new()
		hinge.position = Vector3(0, 0.02, 0.45)
		_hatch.add_child(hinge)
		var lid: MeshInstance3D = MeshInstance3D.new()
		var lb: BoxMesh = BoxMesh.new()
		lb.size = Vector3(0.92, 0.05, 0.92)
		lid.mesh = lb
		lid.material_override = HomageBoss.mat(Color(0.36, 0.26, 0.16))
		lid.position = Vector3(0, 0, -0.46)
		hinge.add_child(lid)
		_hatch_lid = hinge
		var dust: CPUParticles3D = CPUParticles3D.new()
		dust.one_shot = true
		dust.amount = 40
		dust.lifetime = 1.2
		dust.explosiveness = 0.7
		dust.direction = Vector3.UP
		dust.spread = 30.0
		dust.initial_velocity_min = 1.0
		dust.initial_velocity_max = 2.5
		var dm: BoxMesh = BoxMesh.new()
		dm.size = Vector3(0.03, 0.03, 0.03)
		dm.material = HomageBoss.mat(Color(0.75, 0.78, 0.85))   # dust and old ice
		dust.mesh = dm
		_hatch.add_child(dust)
		dust.emitting = true
	var tw: Tween = _hatch_lid.create_tween()
	tw.tween_property(_hatch_lid, "rotation:x", deg_to_rad(105.0), 0.5).set_trans(Tween.TRANS_BACK)
	AudioDirector.play_3d("door_open", at + Vector3.UP * 0.3, 2.0)


func _close_hatch() -> void:
	if _hatch_lid != null and is_instance_valid(_hatch_lid):
		var tw: Tween = _hatch_lid.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(_hatch_lid, "rotation:x", 0.0, 0.4)
		tw.tween_callback(func() -> void: AudioDirector.play_3d("board_slam", _hatch_lid.global_position, 0.0))


func hatch_open() -> bool:
	return _hatch_lid != null and is_instance_valid(_hatch_lid) and _hatch_lid.rotation.x > 0.5


# ================================================================== dev / tests

## Dev console `spawn_boss cousins`: starts the encounter now (during a round: this round; in a break: the next
## round, which starts in half a second). Returns a message.
func start_now() -> String:
	if phase == Phase.ACTIVE:
		return "The Cousins Round is already on (t=%.0f s)" % t
	if RoundManager.state == RoundManager.State.ROUND:
		event_round = RoundManager.current_round
		begin(RoundManager.current_round)
		return "The Cousins Round begins now (round %d)" % event_round
	event_round = RoundManager.current_round + 1
	RoundManager.reserve_round(event_round)
	RoundManager.break_left = minf(RoundManager.break_left, 0.5)
	_force_on = true
	return "The Cousins Round begins with round %d" % event_round


var _force_on: bool = false


func status() -> String:
	var parts: PackedStringArray = []
	for k: String in KEYS:
		var b: HomageBoss = boss(k)
		parts.append("%s %s" % [k, "dead" if dead.has(k) else ("-" if b == null else "%d/%d hp, enrage %d" % [int(b.hp), int(b.max_hp), b.enrage_steps])])
	return "Cousins: %s, round %d, t=%.0f s%s | %s" % [Phase.keys()[phase], event_round, t, ", bots alone" if bots_alone else "", ", ".join(parts)]
