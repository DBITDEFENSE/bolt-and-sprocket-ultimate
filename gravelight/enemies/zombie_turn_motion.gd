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

func reset() -> void:
	active = false
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
	if absf(requested) < deg_to_rad(float(c["minimum_degrees"])) or absf(requested) > deg_to_rad(float(c["maximum_degrees"])): return
	clip = str(c["left"] if requested > 0.0 else c["right"])
	start_yaw = before + offset
	angle = wrapf(desired - start_yaw, -PI, PI)
	clock = 0.0
	previous_clock = 0.0
	active = true

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
	else:
		offset = lerp_angle(offset, 0.0, 1.0 - exp(-dt / maxf(0.001, float(c.get("release_seconds", 0.06)))))
	return offset
