class_name PaulRage
extends RefCounted
## PAUL's rage meter (HB2, docs/HOMAGE_BOSSES.md section 5.3; DECISIONS T-159). Pure maths, no nodes, so the unit
## tests drive it directly. The meter runs 0..100 and shows on his boss bar as a stout bottle filling.
## Fills: damage dealt to him (+1 per 1% of his max HP), players fleeing him (+4 / s each), a player who runs out of
## his sight (+6 at once, T-232 `flee_break`), a player going down in his sight (+10 at once, then +1 / s per downed
## player he can see). Cools: no damage for `cool_after` s (-0.5 / s), a broken IV bottle (-20), the tin-cup idle (-5).
## Stages: Calm 0..33, Angry 34..66, BERSERK 67..100, with a 5-point hysteresis on the way down (he shrinks back only
## when the meter drops 5 below the stage's floor), so he never flickers between sizes on a threshold.

const CALM: int = 0
const ANGRY: int = 1
const BERSERK: int = 2
const STAGE_NAMES: PackedStringArray = ["calm", "angry", "berserk"]

var value: float = 0.0
var stage: int = CALM
var since_damage: float = 0.0
var max_stage_reached: int = CALM
var cfg: Dictionary = {}
var stage_changes: int = 0


func _init(rage_cfg: Dictionary = {}) -> void:
	cfg = defaults()
	cfg.merge(rage_cfg, true)


static func defaults() -> Dictionary:
	return {"per_pct_damage": 1.0, "flee_per_s": 4.0, "flee_break": 6.0, "flee_break_every": 3.0, "down_burst": 10.0,
		"down_per_s": 1.0, "cool_after": 8.0, "cool_per_s": 0.5, "bottle_cool": 20.0, "cup_dip": 5.0, "angry_at": 34.0,
		"berserk_at": 67.0, "hysteresis": 5.0}


## Rage from one hit of `amount` on a boss with `max_hp` (+1 per 1% of max HP).
static func rage_for_damage(amount: float, max_hp: float, per_pct: float = 1.0) -> float:
	return maxf(0.0, amount) / maxf(1.0, max_hp) * 100.0 * per_pct


## The stage for a meter value, given the current stage (the hysteresis: growing happens at the floor, shrinking
## only `hyst` points below it).
static func stage_for(v: float, current: int, angry_at: float = 34.0, berserk_at: float = 67.0, hyst: float = 5.0) -> int:
	var up: int = CALM
	if v >= berserk_at:
		up = BERSERK
	elif v >= angry_at:
		up = ANGRY
	if up >= current:
		return up
	# going down: stay until the meter is hyst below the current stage's floor, one stage at a time
	var floor_v: float = berserk_at if current == BERSERK else angry_at
	if v < floor_v - hyst:
		return stage_for(v, current - 1, angry_at, berserk_at, hyst)
	return current


func add(amount: float) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	_restage()


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	_restage()


## He took `amount` damage (resets the cooling clock).
func on_damage(amount: float, max_hp: float) -> void:
	since_damage = 0.0
	add(rage_for_damage(amount, max_hp, float(cfg["per_pct_damage"])))


## A bottle broke on his back rack.
func on_bottle() -> void:
	add(-float(cfg["bottle_cool"]))


## A player went down where he could see.
func on_player_down() -> void:
	add(float(cfg["down_burst"]))


## T-232: a player he could see sprinted out of his sight (round a corner, through a door): the spike.
func on_flee_break() -> void:
	add(float(cfg["flee_break"]))


## The tin-cup idle: he almost remembers something.
func on_cup() -> void:
	add(-float(cfg["cup_dip"]))


## One step: `fleeing` players sprinting away within 20 m, `downed_seen` downed players he can see.
func tick(delta: float, fleeing: int, downed_seen: int) -> void:
	since_damage += delta
	var d: float = float(cfg["flee_per_s"]) * float(maxi(0, fleeing)) + float(cfg["down_per_s"]) * float(maxi(0, downed_seen))
	if since_damage >= float(cfg["cool_after"]):
		d -= float(cfg["cool_per_s"])
	if d != 0.0:
		add(d * delta)


func _restage() -> void:
	var s: int = stage_for(value, stage, float(cfg["angry_at"]), float(cfg["berserk_at"]), float(cfg["hysteresis"]))
	if s != stage:
		stage = s
		stage_changes += 1
		max_stage_reached = maxi(max_stage_reached, s)


func stage_name() -> String:
	return STAGE_NAMES[stage]


## 0..1 for the bottle on the boss bar.
func fill() -> float:
	return value / 100.0
