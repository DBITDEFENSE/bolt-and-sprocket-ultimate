extends RefCounted
## Recorded turn presentation only. Never writes the gameplay body's transform or velocity.
var active: bool = false
var clip: String = ""
var start_yaw: float = 0.0
var angle: float = 0.0
var offset: float = 0.0
var cooldown: float = 0.0
var clock: float = 0.0
var previous_clock: float = 0.0
# A co-op client's copy never sees the host's destination, only its interpolated yaw: a 45 degree turn arrives as a
# few small increments. observe() accumulates them from the last settled heading and holds the visual there until
# the yaw has settled, then starts the recorded turn over the whole observed angle.
var holding: bool = false
var hold_from: float = 0.0
var hold_seconds: float = 0.0
var still_seconds: float = 0.0
var hold_idle: float = 0.0
var observed_turns: int = 0
# A facing larger than the recorded range was asked: no recorded turn until that facing has settled. (The body's
# fast facing closes it in a few ticks; without this the remainder fell into range on the way and a recorded step
# played after the body had already swung most of the angle, on the host only.)
var over_range: bool = false

func reset() -> void:
	active = false
	holding = false
	over_range = false
	hold_seconds = 0.0
	still_seconds = 0.0
	hold_idle = 0.0
	clip = ""
	offset = 0.0
	cooldown = 0.0
	clock = 0.0
	previous_clock = 0.0

func cancel() -> void:
	if active: cooldown = float(ZombieClips.turn_config()["cooldown_seconds"])
	active = false

func request(before: float, desired: float, eligible: bool) -> void:
	if not eligible or not ZombieClips.recorded_turns_enabled(): return
	var c: Dictionary = ZombieClips.turn_config()
	if active:
		if absf(wrapf(desired - (start_yaw + angle), -PI, PI)) > deg_to_rad(float(c["redirect_degrees"])): cancel()
		return
	if cooldown > 0.0 or absf(offset) > deg_to_rad(float(c["settled_degrees"])): return
	var requested: float = wrapf(desired - before, -PI, PI)
	if absf(requested) > deg_to_rad(float(c["maximum_degrees"])): over_range = true
	elif absf(requested) <= deg_to_rad(float(c["settled_degrees"])): over_range = false
	if over_range or absf(requested) < deg_to_rad(float(c["minimum_degrees"])): return
	clip = str(c["left"] if requested > 0.0 else c["right"])
	start_yaw = before + offset
	angle = wrapf(desired - start_yaw, -PI, PI)
	clock = 0.0
	previous_clock = 0.0
	active = true

## Presentation trigger for a body whose facing is only observed (a client's puppet): `before` and `now` are its yaw
## on consecutive ticks. A fast yaw change from a settled heading starts a hold (the visual stays on the old
## heading); when the yaw settles, or the hold has run its length, an accumulated angle inside the recorded range
## becomes one turn, and anything else is released by advance()'s ordinary easing. Slow tracking of a moving target
## never reaches the start rate, so network jitter on a still body cannot step it.
func observe(before: float, now: float, dt: float, eligible: bool) -> void:
	if not eligible or not ZombieClips.recorded_turns_enabled():
		holding = false
		return
	var c: Dictionary = ZombieClips.turn_config()
	if active:
		if absf(wrapf(now - (start_yaw + angle), -PI, PI)) > deg_to_rad(float(c["redirect_degrees"])): cancel()
		return
	var rate: float = absf(wrapf(now - before, -PI, PI)) / maxf(dt, 0.0001)
	if not holding:
		if cooldown > 0.0 or absf(offset) > deg_to_rad(float(c["settled_degrees"])): return
		if rate < deg_to_rad(float(c.get("observe_start_dps", 180.0))): return
		holding = true
		hold_from = before
		hold_seconds = 0.0
		still_seconds = 0.0
	hold_idle = 0.0
	hold_seconds += dt
	still_seconds = still_seconds + dt if rate < deg_to_rad(float(c.get("observe_settle_dps", 40.0))) else 0.0
	var total: float = wrapf(now - hold_from, -PI, PI)
	if absf(total) > deg_to_rad(float(c["maximum_degrees"])):
		holding = false   # more than a recorded turn covers: the body's own fast facing shows
		return
	if still_seconds >= float(c.get("observe_settle_seconds", 0.05)) or hold_seconds >= float(c.get("observe_hold_seconds", 0.3)):
		holding = false
		if absf(total) >= deg_to_rad(float(c["minimum_degrees"])):
			clip = str(c["left"] if total > 0.0 else c["right"])
			start_yaw = hold_from
			angle = total
			clock = 0.0
			previous_clock = 0.0
			active = true
			observed_turns += 1

func advance(body_yaw: float, seconds: float, dt: float, eligible: bool) -> float:
	var c: Dictionary = ZombieClips.turn_config()
	cooldown = maxf(0.0, cooldown - dt)
	previous_clock = clock
	if not eligible: cancel()
	if active:
		clock = seconds
		offset = wrapf(start_yaw + angle * ZombieClips.turn_progress(clip, seconds) - body_yaw, -PI, PI)
		if absf(offset) > deg_to_rad(float(c["maximum_lag_degrees"])) or seconds >= ZombieClips.length_of(clip) - 0.0001:
			cancel()
	elif holding:
		hold_idle += dt
		if hold_idle > 0.25: holding = false   # no samples arrived: let go
		offset = wrapf(hold_from - body_yaw, -PI, PI)
	else:
		offset = lerp_angle(offset, 0.0, 1.0 - exp(-dt / maxf(0.001, float(c.get("release_seconds", 0.06)))))
	return offset
