class_name WatchMeter
extends RefCounted
## One player's LOGGED meter for THE SLENDER's Watch system (HB3, docs/HOMAGE_BOSSES.md section 6.3; DECISIONS
## T-160). Pure state machine, no nodes: the Slender feeds it what each player's senses say every step and reads
## back the tier and whether the player is due for quarantine. It exists only while he is alive.
## Tiers: NONE 0..9, LOW 10..39 ("Noted."), MEDIUM 40..69 ("Observed."), HIGH 70..94 ("Logged."), CRITICAL 95..100
## ("Quarantined."); at 100 the player is taken in for review (the Watch Room).
## Fill (per second unless noted): in his lantern's pool +12, inside a Lantern Sweep cone +35, looking straight at
## him for more than 1.5 s +8 after the 1.5 s, standing still in the dark for 2 s or more +4, firing in the echoing
## pen hall +2 a shot (at most +10 / s), shooting a decoy +15 a hit.
## Drain: out of his sight -6, standing in real light (a lit lamp pool, the searchlight) -15, within 6 m of a
## teammate -4 (stacks).
## Limits: bots cap at HIGH (94, section 13 D8); while somebody is in the Watch Room a second player waits at
## CRITICAL (capped under 100); after an escape the meter is 0 with `immune_s` of immunity.

enum Tier { NONE, LOW, MEDIUM, HIGH, CRITICAL }
const TIER_WORDS: PackedStringArray = ["", "Noted.", "Observed.", "Logged.", "Quarantined."]
const TIER_LINES: PackedStringArray = ["", "SLN_TIER_LOW_01", "SLN_TIER_MED_01", "SLN_TIER_HIGH_01", "SLN_TIER_CRIT_01"]

var value: float = 0.0
var tier: int = Tier.NONE
var is_bot: bool = false
var immune: float = 0.0
var look_t: float = 0.0
var still_t: float = 0.0
var shot_budget: float = 0.0          # pen-hall shots logged this second
var quarantines: int = 0
var tier_events: Array[int] = []      # every tier entered on the way up (tests / the whisper)
var cfg: Dictionary = {}


func _init(watch_cfg: Dictionary = {}, bot: bool = false) -> void:
	cfg = defaults()
	cfg.merge(watch_cfg, true)
	is_bot = bot


static func defaults() -> Dictionary:
	return {"pool_per_s": 12.0, "sweep_per_s": 35.0, "look_after": 1.5, "look_per_s": 8.0, "still_after": 2.0,
		"still_per_s": 4.0, "shot": 2.0, "shot_cap_per_s": 10.0, "decoy_hit": 15.0, "unseen_per_s": -6.0,
		"light_per_s": -15.0, "teammate_per_s": -4.0, "bot_cap": 94.0, "immune_s": 10.0,
		"tiers": [10.0, 40.0, 70.0, 95.0]}


static func tier_of(v: float, tiers: Array = [10.0, 40.0, 70.0, 95.0]) -> int:
	var t: int = Tier.NONE
	for i: int in tiers.size():
		if v >= float(tiers[i]):
			t = i + 1
	return t


## The rate for one step from the player's senses (pure; the tests use it):
##   pool: in his lantern's pool; sweep: in a sweep cone; seen: he has line of sight to the player;
##   looking: the player looks straight at him; moving: the player moved this step; dark: no light on the player;
##   lit: standing in real light; teammate: a teammate within 6 m.
func rate(s: Dictionary, look_t_now: float, still_t_now: float) -> float:
	var r: float = 0.0
	if bool(s.get("pool", false)):
		r += float(cfg["pool_per_s"])
	if bool(s.get("sweep", false)):
		r += float(cfg["sweep_per_s"])
	if bool(s.get("looking", false)) and look_t_now > float(cfg["look_after"]):
		r += float(cfg["look_per_s"])
	if bool(s.get("dark", false)) and still_t_now >= float(cfg["still_after"]):
		r += float(cfg["still_per_s"])
	if not bool(s.get("seen", false)):
		r += float(cfg["unseen_per_s"])
	if bool(s.get("lit", false)):
		r += float(cfg["light_per_s"])
	if bool(s.get("teammate", false)):
		r += float(cfg["teammate_per_s"])
	return r


## One step. `room_busy`: somebody else is in the Watch Room. Returns true when the player is due for quarantine.
func tick(delta: float, s: Dictionary, room_busy: bool = false) -> bool:
	shot_budget = maxf(0.0, shot_budget - float(cfg["shot_cap_per_s"]) * delta)
	if immune > 0.0:
		immune = maxf(0.0, immune - delta)
		value = 0.0
		_retier()
		return false
	look_t = look_t + delta if bool(s.get("looking", false)) else 0.0
	still_t = still_t + delta if not bool(s.get("moving", true)) else 0.0
	value = clampf(value + rate(s, look_t, still_t) * delta, 0.0, cap(room_busy))
	_retier()
	return due()


## Instant fills (a decoy hit, a pen-hall shot).
func add(amount: float, room_busy: bool = false) -> bool:
	if immune > 0.0:
		return false
	value = clampf(value + amount, 0.0, cap(room_busy))
	_retier()
	return due()


func on_shot(room_busy: bool = false) -> bool:
	var room: float = float(cfg["shot_cap_per_s"]) - shot_budget
	if room <= 0.0:
		return false
	var a: float = minf(float(cfg["shot"]), room)
	shot_budget += a
	return add(a, room_busy)


func on_decoy_hit(room_busy: bool = false) -> bool:
	return add(float(cfg["decoy_hit"]), room_busy)


## The ceiling right now: bots stop at HIGH; a second player waits under 100 while the room is busy.
func cap(room_busy: bool) -> float:
	if is_bot:
		return float(cfg["bot_cap"])
	if room_busy:
		return 99.0
	return 100.0


func due() -> bool:
	return not is_bot and value >= 100.0


## Taken in: the meter stays full until the room lets the player go.
func on_quarantined() -> void:
	quarantines += 1


## Let go (page torn, released by lantern hits, or the room's timer ran out): 0 with immunity.
func on_released() -> void:
	value = 0.0
	immune = float(cfg["immune_s"])
	look_t = 0.0
	still_t = 0.0
	_retier()


func clear() -> void:
	value = 0.0
	immune = 0.0
	look_t = 0.0
	still_t = 0.0
	tier = Tier.NONE


func _retier() -> void:
	var t: int = tier_of(value, cfg["tiers"] as Array)
	if t > tier:
		for i: int in range(tier + 1, t + 1):
			tier_events.append(i)
	tier = t
