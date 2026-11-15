extends RefCounted
## A damped spring that answers the same at every frame rate (docs/perf/movement_perf_2026-11.md).
## No class_name on purpose: its users preload it (`const TickSpring := preload(...)`), so a checkout that pulls
## this file launches from Play.bat without a re-import of the script class cache.
##
## The camera's recoil kick and landing dip and the viewmodel's kick, look sway and inertia are springs stepped
## with the frame's own time (one explicit Euler step a frame). With smooth motion they run per rendered frame, so
## the step was 1/60 s on a 60 Hz screen and 1/240 s on a 240 Hz one, and the same kick peaked 34 % higher at 240
## frames a second on a soft spring and 2.8 times higher on a stiff one (a 3 degree kick at recover 22: 0.90
## degrees at 60, 2.50 at 240); the landing dip was 2.9 cm at 60 and 4.6 cm at 240.
##
## Here the spring's state only ever advances in whole steps of 1/60 s (the game's physics tick, the rate every
## number in weapons.json and movement.json was tuned at, and what bots, tools and tests run), however the
## frames fall; what is shown between two steps is the straight line from the last step to the next one (the
## step it would take now), so the picture moves every frame and never passes a value the 60 Hz steps do not
## reach. At 60 frames a second (and at the tick rate, headless) this is the old code step for step; at 144 or
## 240 the kick has the 60 Hz size.

const H: float = 1.0 / 60.0
const MAX_STEPS: int = 8   # a frame longer than 8 steps (under 7.5 FPS) drops the rest of its time


## Advances a spring toward `target` by `dt`. `x` and `v` are its state on the 60 Hz grid (Vector2, Vector3 or
## float), `acc` the time already past the last grid step. Returns [x, v, acc, shown]: the new grid state, and
## the value to draw for this frame. `w` is the angular frequency (1/s), `z` the damping ratio.
static func advance(x: Variant, v: Variant, target: Variant, w: float, z: float, acc: float, dt: float) -> Array:
	acc += dt
	var n: int = 0
	while acc >= H - 0.000001 and n < MAX_STEPS:
		v += ((target - x) * (w * w) - v * (2.0 * z * w)) * H
		x += v * H
		acc -= H
		n += 1
	if n >= MAX_STEPS or acc < 0.0:
		acc = clampf(acc, 0.0, H)
	if acc <= 0.0:
		return [x, v, 0.0, x]
	var nv: Variant = v + ((target - x) * (w * w) - v * (2.0 * z * w)) * H   # the next step's velocity: x + nv * H is the next state
	return [x, v, acc, x + nv * acc]
