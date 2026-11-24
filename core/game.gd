extends Node
## Global identity, mode switching, input registration, and global time effects (hitstop / slow-motion).
## GAME_TITLE is the single place the working title lives.

const GAME_TITLE: String = "TERMS & CONDITIONS"
## The zombies mode's player-facing name (UPDATE 09 section 6, T-140). Code folders, classes and save keys keep "gravelight".
const GAME_MODE_NAME: String = "CLAUDE ZOMBIES"
const GAME_MODE_NAME_TITLE: String = "Claude Zombies"
const VERSION: String = "0.1.0-m1"

enum Mode { MENU, BOLT_AND_SPROCKET, GRAVELIGHT, FINE_PRINT }

var mode: Mode = Mode.MENU
var hitstop_t: float = 0.0     # real seconds left of hitstop (time scale hitstop_scale)
var slowmo_t: float = 0.0      # real seconds left of slow-motion (time scale slowmo_scale)
var wheel_open: bool = false   # weapon wheel slows the world while choosing
var paused_by_ui: bool = false
var _last_us: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.apply(SaveProfile.doc.get("input_overrides", {}) if SaveProfile.doc is Dictionary else {})


func set_mode(m: Mode) -> void:
	if m == mode:
		return
	mode = m
	EventBus.mode_changed.emit(m)


## Freeze-frame on impact: the world runs at hitstop_scale (0.07 in the web build) for `t` seconds.
func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)


func slowmo(t: float) -> void:
	slowmo_t = maxf(slowmo_t, t)


## The web build scaled each frame's dt (animate(), index.html:17917): hitstop first, else slow-mo, else wheel.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real: float = clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	var scale: float = 1.0
	if hitstop_t <= 0.0 and slowmo_t <= 0.0 and not wheel_open:
		Engine.time_scale = scale
		return   # T-265: the tuning table is only asked for while an effect runs (has_table asks the file system)
	var L: Dictionary = (Data.table("bs/tuning") as Dictionary).get("loop", {}) if Data.has_table("bs/tuning") else {}
	if hitstop_t > 0.0:
		hitstop_t -= real
		scale = float(L.get("hitstop_scale", 0.07))
	elif slowmo_t > 0.0:
		slowmo_t -= real
		scale = float(L.get("slowmo_scale", 0.3))
	elif wheel_open:
		scale = float(L.get("wheel_scale", 0.15))
	Engine.time_scale = scale
