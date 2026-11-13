class_name CameraSway
extends RefCounted
## The comfort setting "Camera Sway / Turbulence" (T-220; GLSettings key `camera_sway`: "full" | "reduced" | "off",
## default "full"). Every camera motion that comes from der Kranich's flight reads it here:
##   the bank / tilt roll        Player._ext_roll (FlightController sets ext_roll_deg; the camera eases toward
##                               ext_roll_deg x roll_scale) - the gameplay push, the sliding cargo and the zombies'
##                               slide are untouched, only the view's roll is scaled
##   the bank's shake            FlightController (the onset jolt), FlightSky (the shake held through a bank)
##   the turbulence micro-events KranichAir's light shake
## "off" removes all of that camera motion and keeps everything else: the sky's slow bank, the swinging lamps, the
## creaks, the rattles and the flicker are visuals and audio, never the camera. Weapon / explosion shake stays on the
## separate Screen Shake slider (and a hard landing after being thrown off the wing is a hit, not sway).
## Pure: the tests drive it with explicit modes.

const KEY: String = "camera_sway"
const MODES: PackedStringArray = ["full", "reduced", "off"]
const LABELS: Dictionary = {"full": "Full", "reduced": "Reduced", "off": "Off"}
## camera roll multiplier per mode (the bank's 8 degrees become 3.2 on Reduced)
const ROLL: Dictionary = {"full": 1.0, "reduced": 0.4, "off": 0.0}
## camera shake multiplier per mode
const SHAKE: Dictionary = {"full": 1.0, "reduced": 0.35, "off": 0.0}


## A stored value made safe: anything unknown (an old settings file, a typo, a bool) reads as "full".
static func normalize(v: Variant) -> String:
	var s: String = str(v).strip_edges().to_lower()
	return s if MODES.has(s) else "full"


## The player's current mode.
static func mode() -> String:
	return normalize(GLSettings.values.get(KEY, "full"))


static func roll_scale(m: String = "") -> float:
	return float(ROLL[normalize(m if m != "" else mode())])


static func shake_scale(m: String = "") -> float:
	return float(SHAKE[normalize(m if m != "" else mode())])


## The camera roll (degrees) a flight roll of `deg` shows in mode `m`.
static func roll_deg(deg: float, m: String = "") -> float:
	return deg * roll_scale(m)


## A flight shake `amount` (Player._shake units) in mode `m`: 0 when it should not move the camera at all.
static func shake_amount(amount: float, m: String = "") -> float:
	return maxf(0.0, amount) * shake_scale(m)


## Raises a player's camera shake by a flight shake (never lowers a bigger shake already running; off does nothing).
static func shake(p: Node, amount: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	var a: float = shake_amount(amount)
	if a <= 0.0:
		return
	var cur: Variant = p.get("_shake")
	p.set("_shake", maxf(float(cur) if cur != null else 0.0, a))


## The next mode in the menu's cycle (full -> reduced -> off -> full).
static func next(m: String) -> String:
	return MODES[(MODES.find(normalize(m)) + 1) % MODES.size()]
