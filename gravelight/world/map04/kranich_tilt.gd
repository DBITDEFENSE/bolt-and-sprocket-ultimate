class_name KranichTilt
extends RefCounted
## UPDATE 10 §3 (contract C6 `turbulence_tilt`, DECISIONS T-156): the Kranich's floor tilts. The pure maths the
## FlightController, the loose cargo (TiltSlider) and the tests share; no node state lives here.
##
## The deck rolls about the long (Z) axis: `side` +1 tips the starboard side down (downhill = +X), -1 the port side.
## A tilt lasts `seconds`: it eases in over `ease_in` s, holds `deg` and eases out over the last `ease_out` s
## (the camera rolls with it). On the slope a loose body accelerates downhill at g·sin(θ) less its friction, if the
## slope beats its static friction; it stops at a wall, and a fast stop at a wall is an impact.

const G: float = 9.81


## The tilt angle (degrees, signed by nothing: always >= 0) `t` seconds into a tilt of `seconds`.
static func angle_at(t: float, seconds: float, deg: float, ease_in: float = 0.8, ease_out: float = 1.0) -> float:
	if t <= 0.0 or t >= seconds or seconds <= 0.0:
		return 0.0
	var k: float = 1.0
	if t < ease_in:
		k = smoothstep(0.0, ease_in, t)
	elif t > seconds - ease_out:
		k = smoothstep(0.0, ease_out, seconds - t)
	return deg * k


## The camera roll (degrees) for a tilt to `side` at `angle` (the FlightController's bank convention: roll = -side).
static func roll_for(side: float, angle: float) -> float:
	return -signf(side) * angle


## The downhill direction on the deck for a tilt to `side`.
static func downhill(side: float) -> Vector3:
	return Vector3(signf(side), 0.0, 0.0)


## Downhill acceleration (m/s², along the slope's fall line, >= 0) at `angle` degrees for a body whose static
## friction needs `stick` m/s² before it moves; once moving it loses `friction` m/s².
static func slide_accel(angle: float, stick: float, friction: float, moving: bool) -> float:
	var a: float = G * sin(deg_to_rad(angle))
	if not moving and a < stick:
		return 0.0
	return maxf(0.0, a - friction)


## One step of a loose body's speed along X (signed): pulled downhill while the deck is tilted, braked by friction,
## stops dead when it is slow and the slope cannot hold it. Returns the new signed speed.
static func slide_step(v: float, side: float, angle: float, stick: float, friction: float, dt: float, max_speed: float = 7.0) -> float:
	var g_along: float = G * sin(deg_to_rad(angle)) * signf(side)
	var moving: bool = absf(v) > 0.05
	if not moving and absf(g_along) < stick:
		return 0.0
	var nv: float = v + g_along * dt
	# kinetic friction opposes the motion; it cannot reverse it
	var brake: float = friction * dt
	if absf(nv) <= brake:
		return 0.0 if absf(g_along) < stick else nv
	nv -= signf(nv) * brake
	return clampf(nv, -max_speed, max_speed)


## The push (m/s) a sliding zombie gets right now: `mps` at the full tilt, scaled by the angle.
static func zombie_slide_mps(angle: float, deg: float, mps: float) -> float:
	return 0.0 if deg <= 0.0 else mps * clampf(angle / deg, 0.0, 1.0)


## Did a body moving downhill hit the wall? It is pushed at `pushed_mps` but covered only `moved` metres of the
## `expected` it should have in the last check, and there is a wall `wall_dist` m ahead (a ray). An impact needs
## real speed (`min_mps`) so a zombie leaning on a wall at the start of the slope is not hurt.
static func is_wall_impact(pushed_mps: float, moved: float, expected: float, wall_dist: float, min_mps: float, reach: float = 0.9) -> bool:
	if pushed_mps < min_mps or expected <= 0.01:
		return false
	return moved < expected * 0.35 and wall_dist >= 0.0 and wall_dist <= reach


## The damage a zombie takes at the wall: `frac` of its max health (the slope is a tool: a full-tilt slam takes most
## of a body's health, the next one finishes it).
static func impact_damage(max_hp: float, frac: float) -> float:
	return maxf(1.0, max_hp * clampf(frac, 0.0, 1.0))


## Does a bomb casing at `bomb` (moving at `speed` m/s) hit a body at `p`? Flat distance within `radius`, the body's
## feet within 1.6 m of the casing's height, and the casing must be moving (`min_speed`).
static func bomb_hits(bomb: Vector3, speed: float, p: Vector3, radius: float, min_speed: float = 1.0) -> bool:
	if absf(speed) < min_speed:
		return false
	return Vector2(bomb.x - p.x, bomb.z - p.z).length() <= radius and absf(p.y - bomb.y) <= 1.6


## The flight clock's tilt times for one round (seconds after the round starts): `count` tilts, the first after
## `first_s` (a [min, max] pair), each next one `gap_s` later; seeded so host and tests agree.
static func schedule(count: int, first_s: Array, gap_s: Array, rng: RandomNumberGenerator) -> Array[float]:
	var out: Array[float] = []
	if count <= 0:
		return out
	var t: float = rng.randf_range(float(first_s[0]), float(first_s[1]))
	for i: int in count:
		out.append(t)
		t += rng.randf_range(float(gap_s[0]), float(gap_s[1]))
	return out
